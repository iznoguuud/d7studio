{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiRemote;

{ What the harness's backends that talk to a model's HTTP API share (TAiRemoteBackend):
    * the HTTP client: the WinHTTP one, cancellable from any thread (a test gives its own);
    * the settings every such backend has: Model, Effort, Reasoning (what is shown of the
      model's reasoning), MaxTokens and BaseUrl;
    * Send's frame, PostStream: the request is POSTed and its answer streamed into the backend
      (Feed, FinishStream, then BuildMessage). Transport failures that may pass, rate limits,
      overloads, server errors and streams that end before their first part are tried again
      with backoff - the server's retry-after honoured -, and an error becomes a message that
      says what went wrong. Once a part of the answer came, nothing is tried again: another
      attempt would repeat it. }

interface

uses
  Windows, SysUtils, Classes, AiText, AiJson, AiCore, AiHttp;

type
  TAiRemoteBackend = class(TAiBackend)
  private
    FHttp: TAiHttpClient;
  protected
    { what the stream of the attempt that runs got (ResetStream clears it) }
    FEvents: TAiBackendEvents;    // where the stream reports; nil when nobody listens
    FGotContent: Boolean;         // a part of the answer came
    FComplete: Boolean;           // the stream ended as its protocol ends it
    FStreamError: string;         // UTF-8: an error the stream reported
    FStreamErrorType: string;     // UTF-8: its type or code
    FStreamErrorRetry: Boolean;   // it may pass: an attempt before any content is repeated
    { a new attempt's stream }
    procedure ResetStream; virtual;
    { a part of a 2xx answer's body, as it arrives }
    procedure Feed(const Data: string); virtual; abstract;
    { the body ended }
    procedure FinishStream; virtual;
    { the message the stream gave (the caller owns it) }
    function BuildMessage: TAiMessage; virtual; abstract;
    { the error of an answer that is not 2xx: its type (or code) and message, UTF-8 }
    procedure ParseError(const Body: string; out ErrType, ErrMsg: string); virtual;
    { a message for it (an IDE string) }
    function ErrorText(Status: Integer; const ErrType, ErrMsg: string): string; virtual;
    { the request may be sent again: a rate limit, an overload, a server error }
    function Retryable(Resp: TAiHttpResponse): Boolean; virtual;
    { what to check when the server could not be reached ('': nothing to say) }
    function ConnectionHint: string; virtual;
    procedure SleepCancellable(Ms: Integer);
    { the wait before another attempt, reported to Events (Why: UTF-8) }
    procedure Backoff(Events: TAiBackendEvents; const Why: string; Seconds: Integer);
    { POSTs Body to Url with Headers and returns the streamed answer's message (the caller owns
      it), tried again as the unit's head says. Raises EAiCancelled after Cancel, else
      EAiBackendError. }
    function PostStream(const Url: string; Headers: TStrings; const Body: string;
      Events: TAiBackendEvents): TAiMessage;
    { GETs Url (a small answer); False when the server did not answer. Raises EAiCancelled. }
    function GetText(const Url: string; Headers: TStrings; out Status: Integer; out Body: string): Boolean;
    { GETs Url: the JSON object of an answer 200 (the caller frees it), else nil - Final then tells
      that asking again would get no other answer (a refusal: 4xx but 408 and 429; an answer 200
      that is no JSON object) }
    function GetJson(const Url: string; Headers: TStrings; out Final: Boolean): TJson;
    property Http: TAiHttpClient read FHttp;
  public
    constructor Create(ASettings: TAiSettings); override;
    destructor Destroy; override;
    function ModelName: string; override;
    procedure Cancel; override;
    procedure ResetCancel; override;
    { the settings' values }
    function Effort: string;
    function Reasoning: string;
    function MaxTokens: Integer;
    { the setting, else the default; without a trailing slash }
    function BaseUrl: string;
    { replaces the HTTP client (the tests); the backend owns it }
    procedure SetHttp(Client: TAiHttpClient);
  end;

const
  MaxRetries = 4;

{ a transport failure that may pass: a timeout, a refused or dropped connection, a bad response }
function TransientHttp(Code: DWORD): Boolean;
{ a number of a JSON object's member (0 when it is missing or not a number) }
function JsonInt64(O: TJson; const Name: string): Int64;
{ a JSON number literal as a Double, whatever the locale's decimal separator (0 when it is none) }
function JsonDouble(V: TJson): Double;

{ a stream's parts by their index, in a TList that owns its objects (nil where none came yet) }
{ the object at Index; nil outside the list }
function IndexedObject(List: TList; Index: Integer): TObject;
{ Obj put at Index, the list grown to it, the object there before freed; an Index below 0 frees Obj }
procedure SetIndexedObject(List: TList; Index: Integer; Obj: TObject);
{ the builder at Index; made there when Make, else nil when there is none }
function IndexedBuilder(List: TList; Index: Integer; Make: Boolean): TKitStringBuilder;
{ every object of List freed, the list emptied }
procedure ClearIndexed(List: TList);

implementation

function TransientHttp(Code: DWORD): Boolean;
begin
  Result := (Code = 12002) or (Code = 12029) or (Code = 12030) or (Code = 12152);
end;

function JsonInt64(O: TJson; const Name: string): Int64;
var
  V: TJson;
begin
  Result := 0;
  if O = nil then Exit;
  V := O.Get(Name);
  if (V <> nil) and (V.Kind = jkNumber) then Result := V.AsInt64(0);
end;

function IndexedObject(List: TList; Index: Integer): TObject;
begin
  if (Index >= 0) and (Index < List.Count) then Result := TObject(List[Index]) else Result := nil;
end;

procedure SetIndexedObject(List: TList; Index: Integer; Obj: TObject);
begin
  if Index < 0 then
  begin
    Obj.Free;
    Exit;
  end;
  while List.Count <= Index do List.Add(nil);
  if TObject(List[Index]) <> Obj then TObject(List[Index]).Free;
  List[Index] := Obj;
end;

function IndexedBuilder(List: TList; Index: Integer; Make: Boolean): TKitStringBuilder;
begin
  Result := nil;
  if Index < 0 then Exit;
  if Index < List.Count then Result := TKitStringBuilder(List[Index]);
  if (Result = nil) and Make then
  begin
    while List.Count <= Index do List.Add(nil);
    Result := TKitStringBuilder.Create;
    List[Index] := Result;
  end;
end;

procedure ClearIndexed(List: TList);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do TObject(List[I]).Free;
  List.Clear;
end;

function JsonDouble(V: TJson): Double;
var
  Code: Integer;
begin
  Result := 0;
  if (V = nil) or (V.Kind <> jkNumber) then Exit;
  Val(V.AsString, Result, Code);    // Val reads '.' as the decimal point in every locale
  if Code <> 0 then Result := 0;
end;

{ ---------------------------------------------------------------- TAiRemoteBackend }

constructor TAiRemoteBackend.Create(ASettings: TAiSettings);
begin
  inherited;
  FHttp := TAiWinHttpClient.Create('D7AiHarness/1.0');
end;

destructor TAiRemoteBackend.Destroy;
begin
  FHttp.Free;
  inherited;
end;

procedure TAiRemoteBackend.SetHttp(Client: TAiHttpClient);
begin
  if Client = FHttp then Exit;
  FHttp.Free;
  FHttp := Client;
end;

function TAiRemoteBackend.ModelName: string;
begin
  Result := Trim(Setting('Model', DefaultModel));
  if Result = '' then Result := DefaultModel;
end;

function TAiRemoteBackend.Effort: string;
begin
  Result := Trim(Setting('Effort', DefaultEffort));
end;

function TAiRemoteBackend.Reasoning: string;
begin
  Result := Trim(Setting('Reasoning', DefaultReasoning));
end;

function TAiRemoteBackend.MaxTokens: Integer;
begin
  Result := SettingInt('MaxTokens', DefaultMaxTokens);
  if Result < 1024 then Result := 1024;
end;

function TAiRemoteBackend.BaseUrl: string;
begin
  Result := Trim(Setting('BaseUrl', DefaultBaseUrl));
  if Result = '' then Result := DefaultBaseUrl;
  while (Result <> '') and (Result[Length(Result)] = '/') do SetLength(Result, Length(Result) - 1);
end;

procedure TAiRemoteBackend.Cancel;
begin
  FHttp.Cancel;
end;

procedure TAiRemoteBackend.ResetCancel;
begin
  FHttp.ResetCancel;
end;

procedure TAiRemoteBackend.ResetStream;
begin
  FGotContent := False;
  FComplete := False;
  FStreamError := '';
  FStreamErrorType := '';
  FStreamErrorRetry := False;
end;

procedure TAiRemoteBackend.FinishStream;
begin
end;

function TAiRemoteBackend.ConnectionHint: string;
begin
  Result := '';
end;

procedure TAiRemoteBackend.SleepCancellable(Ms: Integer);
var
  Waited: Integer;
begin
  Waited := 0;
  while Waited < Ms do
  begin
    if FHttp.Cancelled then raise EAiCancelled.Create('Cancelled.');
    Sleep(100);
    Inc(Waited, 100);
  end;
  if FHttp.Cancelled then raise EAiCancelled.Create('Cancelled.');
end;

procedure TAiRemoteBackend.Backoff(Events: TAiBackendEvents; const Why: string; Seconds: Integer);
begin
  if Events <> nil then Events.Status(Format('%s - trying again in %d s.', [Why, Seconds]));
  SleepCancellable(Seconds * 1000);
end;

function TAiRemoteBackend.Retryable(Resp: TAiHttpResponse): Boolean;
begin
  case Resp.Status of
    408, 409, 429, 500, 502, 503, 504, 524, 529: Result := True;
  else
    Result := False;
  end;
  if Result and SameText(Resp.Header('x-should-retry'), 'false') then Result := False;
end;

(* an object with an "error" object (its "type", "code", "message", "metadata": Anthropic's,
   OpenAI's and OpenRouter's form), or with an "error" string (Ollama) *)
procedure TAiRemoteBackend.ParseError(const Body: string; out ErrType, ErrMsg: string);
var
  J, E, M, C: TJson;
begin
  ErrType := '';
  ErrMsg := '';
  J := TJson.TryParse(Body);
  if J = nil then
  begin
    ErrMsg := TruncateUtf8(SanitizeUtf8(Trim(Body)), 300);
    Exit;
  end;
  try
    E := J.Get('error');
    if E = nil then Exit;
    if E.IsString then
      ErrMsg := E.AsString
    else if E.IsObject then
    begin
      ErrType := E.Str('type');
      M := E.Obj('metadata');
      if (ErrType = '') and (M <> nil) then ErrType := M.Str('error_type');
      C := E.Get('code');
      if (ErrType = '') and (C <> nil) and C.IsString then ErrType := C.AsString;
      ErrMsg := E.Str('message');
    end;
  finally
    J.Free;
  end;
end;

function TAiRemoteBackend.ErrorText(Status: Integer; const ErrType, ErrMsg: string): string;
var
  What: string;
begin
  case Status of
    400: What := 'The API rejected the request';
    401: What := 'The API key was not accepted';
    402: What := 'The account has no credit left for this';
    403: What := 'The API key may not use this';
    404: What := 'Not found (is the model name right?)';
    413: What := 'The request is too large';
    429: What := 'Rate limit reached';
    500, 502, 503, 504, 524: What := 'The API had a server error';
    529: What := 'The API is overloaded';
  else
    What := 'The API answered with an error';
  end;
  Result := Format('%s (HTTP %d', [What, Status]);
  if ErrType <> '' then Result := Result + ', ' + Utf8ToIde(ErrType);
  Result := Result + ')';
  if ErrMsg <> '' then Result := Result + ': ' + Utf8ToIde(ErrMsg);
end;

function TAiRemoteBackend.PostStream(const Url: string; Headers: TStrings; const Body: string;
  Events: TAiBackendEvents): TAiMessage;
var
  Resp: TAiHttpResponse;
  Attempt, Wait: Integer;
  ErrType, ErrMsg, Hint: string;
begin
  Result := nil;
  Resp := TAiHttpResponse.Create;
  try
    Attempt := 0;
    repeat
      ResetStream;
      FEvents := Events;
      try
        FHttp.Post(Url, Headers, Body, Feed, Resp);
      except
        on Ex: EAiHttpError do
        begin
          if (Attempt < MaxRetries) and not FGotContent and TransientHttp(Ex.ErrorCode) then
          begin
            Backoff(Events, IdeToUtf8(Ex.Message), 1 shl Attempt);
            Inc(Attempt);
            Continue;
          end;
          Hint := '';
          if not FGotContent then Hint := ConnectionHint;
          if Hint <> '' then raise EAiBackendError.Create(Ex.Message + ' ' + Hint);
          raise EAiBackendError.Create(Ex.Message);
        end;
      end;
      if (Resp.Status >= 200) and (Resp.Status < 300) then
      begin
        FinishStream;
        if FStreamError <> '' then
        begin
          if not FGotContent and FStreamErrorRetry and (Attempt < MaxRetries) then
          begin
            Backoff(Events, FStreamErrorType + ': ' + FStreamError, 2 shl Attempt);
            Inc(Attempt);
            Continue;
          end;
          raise EAiBackendError.CreateFmt('The API stopped the answer (%s): %s',
            [Utf8ToIde(FStreamErrorType), Utf8ToIde(FStreamError)]);
        end;
        if not FComplete then
        begin
          if not FGotContent and (Attempt < MaxRetries) then
          begin
            Backoff(Events, 'The answer was cut off', 1 shl Attempt);
            Inc(Attempt);
            Continue;
          end;
          raise EAiBackendError.Create('The answer ended before it was complete (the connection was lost).');
        end;
        Result := BuildMessage;
        Exit;
      end;
      ParseError(Resp.Body, ErrType, ErrMsg);
      if Retryable(Resp) and (Attempt < MaxRetries) then
      begin
        Wait := StrToIntDef(Resp.Header('retry-after'), 0);
        if Wait <= 0 then Wait := 2 shl Attempt;
        if Wait > 60 then Wait := 60;
        Backoff(Events, IdeToUtf8(ErrorText(Resp.Status, ErrType, ErrMsg)), Wait);
        Inc(Attempt);
        Continue;
      end;
      raise EAiBackendError.Create(ErrorText(Resp.Status, ErrType, ErrMsg));
    until False;
  finally
    FEvents := nil;
    Resp.Free;
  end;
end;

function TAiRemoteBackend.GetText(const Url: string; Headers: TStrings; out Status: Integer;
  out Body: string): Boolean;
var
  Resp: TAiHttpResponse;
begin
  Status := 0;
  Body := '';
  Result := False;
  Resp := TAiHttpResponse.Create;
  try
    try
      FHttp.Get(Url, Headers, Resp);
    except
      on EAiCancelled do raise;
    else
      Exit;
    end;
    Status := Resp.Status;
    Body := Resp.Body;
    Result := True;
  finally
    Resp.Free;
  end;
end;

function TAiRemoteBackend.GetJson(const Url: string; Headers: TStrings; out Final: Boolean): TJson;
var
  Status: Integer;
  Body: string;
begin
  Result := nil;
  Final := False;
  if not GetText(Url, Headers, Status, Body) then Exit;
  if Status <> 200 then
  begin
    Final := (Status >= 400) and (Status < 500) and (Status <> 408) and (Status <> 429);
    Exit;
  end;
  Result := TJson.TryParse(Body);
  if (Result <> nil) and not Result.IsObject then FreeAndNil(Result);
  Final := Result = nil;
end;

end.
