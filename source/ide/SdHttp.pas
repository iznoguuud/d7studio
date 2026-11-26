{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdHttp;

{ D7 Studio - a small HTTPS client on WinHTTP: a GET of a short answer and the download of a file,
  for the check for updates (SdUpdate).

  WinHTTP is declared here (Delphi 7 has no unit for it). It uses the system's TLS (1.2 and 1.3)
  and its automatic proxy settings, and follows redirections (a release asset's URL redirects to
  its storage). A request runs synchronously in the calling thread - a worker thread -; Cancel,
  from any thread, closes the request handle, which makes the blocked WinHTTP call return. }

interface

uses
  Windows, SysUtils, Classes, SyncObjs;

type
  ESdHttpError = class(Exception)
  public
    Status: Integer;    // the HTTP status of an answer that is not 2xx; 0 for a transport failure
  end;

  { the request was cancelled (Cancel) }
  ESdHttpCancelled = class(Exception);

  { Done of Total bytes received (Total 0: unknown); called in the requesting thread }
  TSdHttpProgress = procedure(Done, Total: Integer) of object;

  TSdHttp = class
  private
    FLock: TCriticalSection;
    FSession: Pointer;
    FConnect: Pointer;     // the request's connection, closed with it
    FRequest: Pointer;
    FCancelled: Boolean;
    FUserAgent: WideString;
    procedure CloseRequest;
    function CurRequest: Pointer;
    procedure Check(OK: Boolean; const What: string);
    { sends a GET of Url and receives its headers: the status; the request stays open for the body }
    function Open(const Url: string; Headers: TStrings): Integer;
    function ContentLength: Integer;
    { the body, part by part, to Stream }
    procedure ReadBody(Stream: TStream; OnProgress: TSdHttpProgress; Total: Integer);
  public
    constructor Create(const UserAgent: string);
    destructor Destroy; override;
    { the body of a 2xx answer to a GET of Url, with the header lines 'Name: value' of Headers
      (nil: none); ESdHttpError for another status or a transport failure }
    function Get(const Url: string; Headers: TStrings = nil): string;
    { the body of a GET of Url into the file FileName (made anew); OnProgress as it arrives }
    procedure Download(const Url, FileName: string; OnProgress: TSdHttpProgress);
    { from any thread: ends the request that runs; every later one raises ESdHttpCancelled }
    procedure Cancel;
    function Cancelled: Boolean;
  end;

implementation

const
  winhttp = 'winhttp.dll';

  WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = 0;
  WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY = 4;
  WINHTTP_FLAG_SECURE = $00800000;
  WINHTTP_QUERY_CONTENT_LENGTH = 5;
  WINHTTP_QUERY_STATUS_CODE = 19;
  WINHTTP_QUERY_FLAG_NUMBER = $20000000;
  WINHTTP_OPTION_SECURE_PROTOCOLS = 84;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 = $00000800;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3 = $00002000;
  WINHTTP_ADDREQ_FLAG_ADD = $20000000;
  WINHTTP_ADDREQ_FLAG_REPLACE = $80000000;
  ERROR_WINHTTP_OPERATION_CANCELLED = 12017;

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

procedure RaiseHttp(const What: string; Code: DWORD);
var
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
  raise ESdHttpError.CreateFmt('%s: %s (WinHTTP %d)', [What, Msg, Code]);
end;

constructor TSdHttp.Create(const UserAgent: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FUserAgent := UserAgent;
end;

destructor TSdHttp.Destroy;
begin
  CloseRequest;
  if FSession <> nil then WinHttpCloseHandle(FSession);
  FLock.Free;
  inherited Destroy;
end;

procedure TSdHttp.CloseRequest;
var
  H, C: Pointer;
begin
  FLock.Enter;
  try
    H := FRequest;
    FRequest := nil;
    C := FConnect;
    FConnect := nil;
  finally
    FLock.Leave;
  end;
  if H <> nil then WinHttpCloseHandle(H);
  if C <> nil then WinHttpCloseHandle(C);
end;

procedure TSdHttp.Cancel;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
  CloseRequest;
end;

function TSdHttp.Cancelled: Boolean;
begin
  FLock.Enter;
  try
    Result := FCancelled;
  finally
    FLock.Leave;
  end;
end;

{ the request handle, ESdHttpCancelled once Cancel closed it }
function TSdHttp.CurRequest: Pointer;
begin
  FLock.Enter;
  try
    Result := FRequest;
  finally
    FLock.Leave;
  end;
  if Result = nil then raise ESdHttpCancelled.Create('Cancelled.');
end;

procedure TSdHttp.Check(OK: Boolean; const What: string);
var
  Code: DWORD;
begin
  if OK then Exit;
  Code := GetLastError;
  if Cancelled or (Code = ERROR_WINHTTP_OPERATION_CANCELLED) or (Code = ERROR_INVALID_HANDLE) then
    raise ESdHttpCancelled.Create('Cancelled.');
  RaiseHttp(What, Code);
end;

function TSdHttp.Open(const Url: string; Headers: TStrings): Integer;
var
  Secure: Boolean;
  Rest, Host, Path, Hdrs: string;
  Port, P, I: Integer;
  Connect, Req: Pointer;
  Flags, Protocols, Size, Status: DWORD;
  W: WideString;
begin
  if Cancelled then raise ESdHttpCancelled.Create('Cancelled.');
  { https://host[:port]/path }
  Secure := SameText(Copy(Url, 1, 8), 'https://');
  if Secure then
  begin
    Rest := Copy(Url, 9, MaxInt);
    Port := 443;
  end
  else if SameText(Copy(Url, 1, 7), 'http://') then
  begin
    Rest := Copy(Url, 8, MaxInt);
    Port := 80;
  end
  else raise ESdHttpError.CreateFmt('Not an http(s) URL: %s', [Url]);
  P := Pos('/', Rest);
  if P > 0 then
  begin
    Path := Copy(Rest, P, MaxInt);
    Host := Copy(Rest, 1, P - 1);
  end
  else
  begin
    Path := '/';
    Host := Rest;
  end;
  P := Pos(':', Host);
  if P > 0 then
  begin
    Port := StrToIntDef(Copy(Host, P + 1, MaxInt), 0);
    Host := Copy(Host, 1, P - 1);
  end;
  if (Host = '') or (Port <= 0) or (Port > 65535) then
    raise ESdHttpError.CreateFmt('Not an http(s) URL: %s', [Url]);

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
    { resolve, connect, send; receive: the longest wait for the next part of the body }
    WinHttpSetTimeouts(FSession, 30000, 30000, 30000, 60000);
  end;
  W := Host;
  Connect := WinHttpConnect(FSession, PWideChar(W), Port, 0);
  if Connect = nil then RaiseHttp('WinHttpConnect', GetLastError);
  if Secure then Flags := WINHTTP_FLAG_SECURE else Flags := 0;
  W := Path;
  Req := WinHttpOpenRequest(Connect, 'GET', PWideChar(W), nil, nil, nil, Flags);
  if Req = nil then
  begin
    Status := GetLastError;
    WinHttpCloseHandle(Connect);
    RaiseHttp('WinHttpOpenRequest', Status);
  end;
  FLock.Enter;
  try
    FRequest := Req;
    FConnect := Connect;
    if FCancelled then
    begin
      CloseRequest;    // the lock is re-entrant
      raise ESdHttpCancelled.Create('Cancelled.');
    end;
  finally
    FLock.Leave;
  end;
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
  Check(WinHttpSendRequest(CurRequest, nil, 0, nil, 0, 0, 0), 'Sending the request');
  Check(WinHttpReceiveResponse(CurRequest, nil), 'Receiving the response');
  Status := 0;
  Size := SizeOf(Status);
  Check(WinHttpQueryHeaders(CurRequest, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER, nil,
    @Status, Size, nil), 'Reading the status');
  Result := Status;
end;

{ the answer's Content-Length; 0 when it has none }
function TSdHttp.ContentLength: Integer;
var
  Value, Size: DWORD;
begin
  Value := 0;
  Size := SizeOf(Value);
  if WinHttpQueryHeaders(CurRequest, WINHTTP_QUERY_CONTENT_LENGTH or WINHTTP_QUERY_FLAG_NUMBER, nil,
    @Value, Size, nil) and (Value <= DWORD(MaxInt)) then
    Result := Value
  else
    Result := 0;
end;

procedure TSdHttp.ReadBody(Stream: TStream; OnProgress: TSdHttpProgress; Total: Integer);
var
  Avail, Read: DWORD;
  Done: Integer;
  Buf: array[0..65535] of Byte;
begin
  Done := 0;
  if Assigned(OnProgress) then OnProgress(0, Total);
  repeat
    Avail := 0;
    Check(WinHttpQueryDataAvailable(CurRequest, Avail), 'Reading the response');
    if Avail = 0 then Break;
    if Avail > SizeOf(Buf) then Avail := SizeOf(Buf);
    Read := 0;
    Check(WinHttpReadData(CurRequest, @Buf, Avail, Read), 'Reading the response');
    if Read = 0 then Break;
    Stream.WriteBuffer(Buf, Read);
    Inc(Done, Read);
    if Assigned(OnProgress) then OnProgress(Done, Total);
  until False;
  if Cancelled then raise ESdHttpCancelled.Create('Cancelled.');
end;

procedure RaiseStatus(Status: Integer; const Url: string);
var
  E: ESdHttpError;
begin
  E := ESdHttpError.CreateFmt('The server answered HTTP %d for %s', [Status, Url]);
  E.Status := Status;
  raise E;
end;

function TSdHttp.Get(const Url: string; Headers: TStrings): string;
var
  Status: Integer;
  S: TStringStream;
begin
  try
    Status := Open(Url, Headers);
    if (Status < 200) or (Status >= 300) then RaiseStatus(Status, Url);
    S := TStringStream.Create('');
    try
      ReadBody(S, nil, 0);
      Result := S.DataString;
    finally
      S.Free;
    end;
  finally
    CloseRequest;
  end;
end;

procedure TSdHttp.Download(const Url, FileName: string; OnProgress: TSdHttpProgress);
var
  Status: Integer;
  F: TFileStream;
  OK: Boolean;
begin
  try
    Status := Open(Url, nil);
    if (Status < 200) or (Status >= 300) then RaiseStatus(Status, Url);
    OK := False;
    F := TFileStream.Create(FileName, fmCreate);
    try
      ReadBody(F, OnProgress, ContentLength);
      OK := True;
    finally
      F.Free;
      if not OK then DeleteFile(FileName);
    end;
  finally
    CloseRequest;
  end;
end;

end.
