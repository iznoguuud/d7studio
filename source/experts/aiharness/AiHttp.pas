{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiHttp;

{ HTTPS for the AI harness: an abstract client (TAiHttpClient) and its WinHTTP implementation
  (TAiWinHttpClient), plus a parser of server-sent events (TAiSseParser) for streamed
  responses.

  WinHTTP is declared here (Delphi 7 has no unit for it). It uses the system's TLS (TLS 1.2 and
  1.3 on Windows 10 and 11) and its automatic proxy settings. A request runs synchronously in
  the calling thread - the harness calls it from its worker thread - and Cancel, from any
  thread, closes the request handle, which makes the blocked WinHTTP call return. }

interface

uses
  Windows, SysUtils, Classes, SyncObjs, AiText;

type
  EAiHttpError = class(Exception)
  public
    ErrorCode: DWORD;
  end;

  { the request was cancelled (Cancel, or the session's Stop) }
  EAiCancelled = class(Exception);

  { a part of the response body, as it arrives }
  TAiHttpDataEvent = procedure(const Data: string) of object;

  TAiHttpResponse = class
  public
    Status: Integer;
    RawHeaders: string;    // the response's header lines, CR LF separated
    Body: string;          // the body, unless it went to OnData
    procedure Clear;
    { the value of the header Name ('' when absent) }
    function Header(const Name: string): string;
  end;

  TAiHttpClient = class
  public
    { POSTs Body (bytes) to Url with the headers 'Name: value' of Headers. A 2xx body goes to
      OnData in parts when OnData is set; any other body is collected in Response.Body.
      Raises EAiHttpError for transport failures and EAiCancelled after Cancel. }
    procedure Post(const Url: string; Headers: TStrings; const Body: string; OnData: TAiHttpDataEvent;
      Response: TAiHttpResponse); virtual; abstract;
    { GETs Url; the body goes to Response.Body. A client that cannot raises EAiHttpError. }
    procedure Get(const Url: string; Headers: TStrings; Response: TAiHttpResponse); virtual;
    { from any thread: ends the request that runs }
    procedure Cancel; virtual; abstract;
    { the next Post may run (after a Cancel) }
    procedure ResetCancel; virtual; abstract;
    function Cancelled: Boolean; virtual; abstract;
  end;

  TAiWinHttpClient = class(TAiHttpClient)
  private
    FLock: TCriticalSection;
    FSession: Pointer;
    FRequest: Pointer;
    FCancelled: Boolean;
    FUserAgent: WideString;
    procedure CloseRequest;
    procedure Request(const Verb, Url: string; Headers: TStrings; const Body: string; OnData: TAiHttpDataEvent;
      Response: TAiHttpResponse; Timeout: Integer);
  public
    GetTimeout: Integer;    // the longest wait of a GET in ms (30000)
    constructor Create(const UserAgent: string);
    destructor Destroy; override;
    procedure Post(const Url: string; Headers: TStrings; const Body: string; OnData: TAiHttpDataEvent;
      Response: TAiHttpResponse); override;
    { a small answer: waited for GetTimeout ms at most }
    procedure Get(const Url: string; Headers: TStrings; Response: TAiHttpResponse); override;
    procedure Cancel; override;
    procedure ResetCancel; override;
    function Cancelled: Boolean; override;
  end;

  { server-sent events: feed the bytes as they come, get each event (its name and its data
    lines joined with LF) }
  TAiSseEvent = procedure(const EventName, Data: string) of object;

  TAiSseParser = class
  private
    FBuffer: string;
    FEventName: string;
    FData: string;
    FHasData: Boolean;
    FOnEvent: TAiSseEvent;
    procedure Line(const S: string);
  public
    procedure Feed(const Bytes: string);
    { the event that a missing final blank line left open }
    procedure Finish;
    procedure Reset;
    property OnEvent: TAiSseEvent read FOnEvent write FOnEvent;
  end;

{ the parts of an http(s) URL; False when it is not one }
function SplitUrl(const Url: string; out Secure: Boolean; out Host: string; out Port: Integer;
  out Path: string): Boolean;

implementation

const
  winhttp = 'winhttp.dll';

  WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = 0;
  WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY = 4;
  WINHTTP_FLAG_SECURE = $00800000;
  WINHTTP_QUERY_STATUS_CODE = 19;
  WINHTTP_QUERY_RAW_HEADERS_CRLF = 22;
  WINHTTP_QUERY_FLAG_NUMBER = $20000000;
  WINHTTP_OPTION_SECURE_PROTOCOLS = 84;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 = $00000800;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3 = $00002000;
  WINHTTP_ADDREQ_FLAG_ADD = $20000000;
  WINHTTP_ADDREQ_FLAG_REPLACE = $80000000;
  ERROR_WINHTTP_OPERATION_CANCELLED = 12017;
  ERROR_INVALID_HANDLE_ = 6;

function WinHttpOpen(pwszUserAgent: PWideChar; dwAccessType: DWORD; pwszProxyName,
  pwszProxyBypass: PWideChar; dwFlags: DWORD): Pointer; stdcall; external winhttp;
function WinHttpConnect(hSession: Pointer; pswzServerName: PWideChar; nServerPort: Word;
  dwReserved: DWORD): Pointer; stdcall; external winhttp;
function WinHttpOpenRequest(hConnect: Pointer; pwszVerb, pwszObjectName, pwszVersion,
  pwszReferrer: PWideChar; ppwszAcceptTypes: Pointer; dwFlags: DWORD): Pointer; stdcall; external winhttp;
function WinHttpAddRequestHeaders(hRequest: Pointer; pwszHeaders: PWideChar; dwHeadersLength: DWORD;
  dwModifiers: DWORD): BOOL; stdcall; external winhttp;
function WinHttpSendRequest(hRequest: Pointer; pwszHeaders: PWideChar; dwHeadersLength: DWORD;
  lpOptional: Pointer; dwOptionalLength, dwTotalLength: DWORD; dwContext: DWORD): BOOL; stdcall; external winhttp;
function WinHttpReceiveResponse(hRequest: Pointer; lpReserved: Pointer): BOOL; stdcall; external winhttp;
function WinHttpQueryHeaders(hRequest: Pointer; dwInfoLevel: DWORD; pwszName: PWideChar;
  lpBuffer: Pointer; var lpdwBufferLength: DWORD; lpdwIndex: Pointer): BOOL; stdcall; external winhttp;
function WinHttpQueryDataAvailable(hRequest: Pointer; var lpdwNumberOfBytesAvailable: DWORD): BOOL; stdcall;
  external winhttp;
function WinHttpReadData(hRequest: Pointer; lpBuffer: Pointer; dwNumberOfBytesToRead: DWORD;
  var lpdwNumberOfBytesRead: DWORD): BOOL; stdcall; external winhttp;
function WinHttpCloseHandle(hInternet: Pointer): BOOL; stdcall; external winhttp;
function WinHttpSetTimeouts(hInternet: Pointer; nResolveTimeout, nConnectTimeout, nSendTimeout,
  nReceiveTimeout: Integer): BOOL; stdcall; external winhttp;
function WinHttpSetOption(hInternet: Pointer; dwOption: DWORD; lpBuffer: Pointer;
  dwBufferLength: DWORD): BOOL; stdcall; external winhttp;

function SplitUrl(const Url: string; out Secure: Boolean; out Host: string; out Port: Integer;
  out Path: string): Boolean;
var
  Rest: string;
  P: Integer;
begin
  Result := False;
  Secure := False;
  Host := '';
  Path := '/';
  Port := 0;
  if SameText(Copy(Url, 1, 8), 'https://') then
  begin
    Secure := True;
    Rest := Copy(Url, 9, MaxInt);
    Port := 443;
  end
  else if SameText(Copy(Url, 1, 7), 'http://') then
  begin
    Rest := Copy(Url, 8, MaxInt);
    Port := 80;
  end
  else Exit;
  P := Pos('/', Rest);
  if P > 0 then
  begin
    Path := Copy(Rest, P, MaxInt);
    Rest := Copy(Rest, 1, P - 1);
  end;
  P := Pos(':', Rest);
  if P > 0 then
  begin
    Port := StrToIntDef(Copy(Rest, P + 1, MaxInt), 0);
    Rest := Copy(Rest, 1, P - 1);
    if (Port <= 0) or (Port > 65535) then Exit;
  end;
  Host := Rest;
  Result := Host <> '';
end;

procedure RaiseHttp(const What: string; Code: DWORD);
var
  E: EAiHttpError;
  Msg: string;
begin
  case Code of
    12002: Msg := 'the connection timed out';
    12007: Msg := 'the server name could not be resolved';
    12029: Msg := 'the connection to the server failed';
    12030: Msg := 'the connection with the server was ended';
    12152: Msg := 'the server returned an invalid response';
    12175: Msg := 'a security (TLS) error occurred';
  else
    Msg := SysErrorMessage(Code);
    if Msg = '' then Msg := 'error ' + IntToStr(Code);
  end;
  E := EAiHttpError.CreateFmt('%s: %s (WinHTTP %d)', [What, Msg, Code]);
  E.ErrorCode := Code;
  raise E;
end;

{ ---------------------------------------------------------------- TAiHttpResponse }

procedure TAiHttpResponse.Clear;
begin
  Status := 0;
  RawHeaders := '';
  Body := '';
end;

function TAiHttpResponse.Header(const Name: string): string;
var
  L: TStringList;
  I, P: Integer;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Text := RawHeaders;
    for I := 0 to L.Count - 1 do
    begin
      P := Pos(':', L[I]);
      if (P > 0) and SameText(Trim(Copy(L[I], 1, P - 1)), Name) then
      begin
        Result := Trim(Copy(L[I], P + 1, MaxInt));
        Exit;
      end;
    end;
  finally
    L.Free;
  end;
end;

procedure TAiHttpClient.Get(const Url: string; Headers: TStrings; Response: TAiHttpResponse);
begin
  raise EAiHttpError.Create('This HTTP client cannot GET.');
end;

{ ---------------------------------------------------------------- TAiWinHttpClient }

constructor TAiWinHttpClient.Create(const UserAgent: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FUserAgent := UserAgent;
  GetTimeout := 30000;
end;

destructor TAiWinHttpClient.Destroy;
begin
  Cancel;
  if FSession <> nil then WinHttpCloseHandle(FSession);
  FLock.Free;
  inherited;
end;

procedure TAiWinHttpClient.CloseRequest;
var
  H: Pointer;
begin
  FLock.Enter;
  try
    H := FRequest;
    FRequest := nil;
  finally
    FLock.Leave;
  end;
  if H <> nil then WinHttpCloseHandle(H);
end;

procedure TAiWinHttpClient.Cancel;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
  CloseRequest;
end;

procedure TAiWinHttpClient.ResetCancel;
begin
  FLock.Enter;
  try
    FCancelled := False;
  finally
    FLock.Leave;
  end;
end;

function TAiWinHttpClient.Cancelled: Boolean;
begin
  FLock.Enter;
  try
    Result := FCancelled;
  finally
    FLock.Leave;
  end;
end;

procedure TAiWinHttpClient.Post(const Url: string; Headers: TStrings; const Body: string;
  OnData: TAiHttpDataEvent; Response: TAiHttpResponse);
begin
  Request('POST', Url, Headers, Body, OnData, Response, 0);
end;

procedure TAiWinHttpClient.Get(const Url: string; Headers: TStrings; Response: TAiHttpResponse);
begin
  Request('GET', Url, Headers, '', nil, Response, GetTimeout);
end;

{ Timeout: the longest wait in ms to connect, send and receive; 0: the session's }
procedure TAiWinHttpClient.Request(const Verb, Url: string; Headers: TStrings; const Body: string;
  OnData: TAiHttpDataEvent; Response: TAiHttpResponse; Timeout: Integer);
var
  Secure: Boolean;
  Host, Path, Chunk, Hdrs: string;
  Port, I: Integer;
  Connect, Req: Pointer;
  Flags, Protocols, Size, Read, Status, Avail: DWORD;
  W, WVerb: WideString;
  Buf: array[0..16383] of Char;
  Streaming: Boolean;
  Collected: TKitStringBuilder;

  procedure Check(OK: Boolean; const What: string);
  var
    Code: DWORD;
  begin
    if OK then Exit;
    Code := GetLastError;
    if Cancelled or (Code = ERROR_WINHTTP_OPERATION_CANCELLED) or (Code = ERROR_INVALID_HANDLE_) then
      raise EAiCancelled.Create('Cancelled.');
    RaiseHttp(What, Code);
  end;

  { the request handle, nil once Cancel closed it }
  function CurRequest: Pointer;
  begin
    FLock.Enter;
    try
      Result := FRequest;
    finally
      FLock.Leave;
    end;
    if Result = nil then raise EAiCancelled.Create('Cancelled.');
  end;

begin
  Response.Clear;
  if Cancelled then raise EAiCancelled.Create('Cancelled.');
  if not SplitUrl(Url, Secure, Host, Port, Path) then
    raise EAiHttpError.CreateFmt('Not an http(s) URL: %s', [Url]);
  if FSession = nil then
  begin
    FSession := WinHttpOpen(PWideChar(FUserAgent), WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, nil, nil, 0);
    if FSession = nil then   // before Windows 8.1
      FSession := WinHttpOpen(PWideChar(FUserAgent), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nil, nil, 0);
    if FSession = nil then RaiseHttp('WinHttpOpen', GetLastError);
    Protocols := WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 or WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3;
    if not WinHttpSetOption(FSession, WINHTTP_OPTION_SECURE_PROTOCOLS, @Protocols, SizeOf(Protocols)) then
    begin
      Protocols := WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
      WinHttpSetOption(FSession, WINHTTP_OPTION_SECURE_PROTOCOLS, @Protocols, SizeOf(Protocols));
    end;
    { resolve, connect, send; receive: the longest wait between two parts of a stream }
    WinHttpSetTimeouts(FSession, 30000, 30000, 120000, 600000);
  end;
  W := Host;
  Connect := WinHttpConnect(FSession, PWideChar(W), Port, 0);
  if Connect = nil then RaiseHttp('WinHttpConnect', GetLastError);
  try
    if Secure then Flags := WINHTTP_FLAG_SECURE else Flags := 0;
    W := Path;
    WVerb := Verb;
    Req := WinHttpOpenRequest(Connect, PWideChar(WVerb), PWideChar(W), nil, nil, nil, Flags);
    if Req = nil then RaiseHttp('WinHttpOpenRequest', GetLastError);
    if Timeout > 0 then WinHttpSetTimeouts(Req, Timeout, Timeout, Timeout, Timeout);
    FLock.Enter;
    try
      FRequest := Req;
      if FCancelled then
      begin
        FRequest := nil;
        WinHttpCloseHandle(Req);
        raise EAiCancelled.Create('Cancelled.');
      end;
    finally
      FLock.Leave;
    end;
    try
      Hdrs := '';
      if Headers <> nil then
        for I := 0 to Headers.Count - 1 do
          if Trim(Headers[I]) <> '' then Hdrs := Hdrs + Headers[I] + #13#10;
      if Hdrs <> '' then
      begin
        W := Hdrs;
        Check(WinHttpAddRequestHeaders(CurRequest, PWideChar(W), Length(W),
          WINHTTP_ADDREQ_FLAG_ADD or WINHTTP_ADDREQ_FLAG_REPLACE), 'Request headers');
      end;
      if Body <> '' then
        Check(WinHttpSendRequest(CurRequest, nil, 0, PChar(Body), Length(Body), Length(Body), 0), 'Sending the request')
      else
        Check(WinHttpSendRequest(CurRequest, nil, 0, nil, 0, 0, 0), 'Sending the request');
      Check(WinHttpReceiveResponse(CurRequest, nil), 'Receiving the response');
      Status := 0;
      Size := SizeOf(Status);
      Check(WinHttpQueryHeaders(CurRequest, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER, nil,
        @Status, Size, nil), 'Reading the status');
      Response.Status := Status;
      Size := 0;
      WinHttpQueryHeaders(CurRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, nil, nil, Size, nil);
      if Size > 0 then
      begin
        SetLength(W, Size div 2);
        if WinHttpQueryHeaders(CurRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, nil, PWideChar(W), Size, nil) then
          Response.RawHeaders := WideCharLenToString(PWideChar(W), Size div 2);
      end;
      Streaming := Assigned(OnData) and (Status >= 200) and (Status < 300);
      Collected := TKitStringBuilder.Create;
      try
        { a synchronous WinHttpReadData waits until its buffer is full: it reads what has arrived,
          so that a stream's parts are handed on as they come }
        repeat
          Avail := 0;
          Check(WinHttpQueryDataAvailable(CurRequest, Avail), 'Reading the response');
          if Avail = 0 then Break;
          if Avail > SizeOf(Buf) then Avail := SizeOf(Buf);
          Read := 0;
          Check(WinHttpReadData(CurRequest, @Buf, Avail, Read), 'Reading the response');
          if Read = 0 then Break;
          if Streaming then
          begin
            SetString(Chunk, Buf, Read);
            OnData(Chunk);
          end
          else Collected.Append(Buf, Read);
        until False;
        Response.Body := Collected.Text;
      finally
        Collected.Free;
      end;
      if Cancelled then raise EAiCancelled.Create('Cancelled.');
    finally
      CloseRequest;
    end;
  finally
    WinHttpCloseHandle(Connect);
  end;
end;

{ ---------------------------------------------------------------- TAiSseParser }

procedure TAiSseParser.Reset;
begin
  FBuffer := '';
  FEventName := '';
  FData := '';
  FHasData := False;
end;

procedure TAiSseParser.Line(const S: string);
var
  P: Integer;
  Field, Value: string;
begin
  if S = '' then
  begin
    { a blank line dispatches the event }
    if FHasData and Assigned(FOnEvent) then FOnEvent(FEventName, FData);
    FEventName := '';
    FData := '';
    FHasData := False;
    Exit;
  end;
  if S[1] = ':' then Exit;    // a comment
  P := Pos(':', S);
  if P > 0 then
  begin
    Field := Copy(S, 1, P - 1);
    Value := Copy(S, P + 1, MaxInt);
    if (Value <> '') and (Value[1] = ' ') then Delete(Value, 1, 1);
  end
  else
  begin
    Field := S;
    Value := '';
  end;
  if Field = 'event' then FEventName := Value
  else if Field = 'data' then
  begin
    if FHasData then FData := FData + #10 + Value else FData := Value;
    FHasData := True;
  end;
end;

procedure TAiSseParser.Feed(const Bytes: string);
var
  I, Start, L, N: Integer;
begin
  FBuffer := FBuffer + Bytes;
  { every complete line, then the rest kept for the next part (one deletion per part) }
  Start := 1;
  L := Length(FBuffer);
  for I := 1 to L do
    if FBuffer[I] = #10 then
    begin
      N := I - Start;
      if (N > 0) and (FBuffer[Start + N - 1] = #13) then Dec(N);
      Line(Copy(FBuffer, Start, N));
      Start := I + 1;
    end;
  if Start > 1 then Delete(FBuffer, 1, Start - 1);
end;

procedure TAiSseParser.Finish;
begin
  if FBuffer <> '' then
  begin
    Line(FBuffer);
    FBuffer := '';
  end;
  Line('');
end;

end.
