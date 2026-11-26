{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiCore;

{ The provider-neutral core of the AI harness:
    * the conversation (TAiConversation of TAiMessage of TAiBlock): text, reasoning, tool calls
      and tool results. A block keeps its provider's native form (TAiBlock.Native) so that the
      provider gets it back byte for byte - reasoning blocks carry signatures that must not
      change;
    * TAiBackend, the abstract model backend: it sends the conversation with the tools and
      returns the next assistant message, streaming its parts to TAiBackendEvents. Backends
      register their class (RegisterAiBackend) and are made from the settings;
    * context management, which every backend offers the same way: how full the model's
      context window is after a message (TAiMessage.ContextTokens, TAiBackend.ContextWindow),
      and the summary of a long conversation (compaction): once a request's prompt reaches
      TAiBackend.CompactAt tokens, the backend summarizes what came before - its provider's
      server, or the backend itself - and returns the summary as an abSummary block at the
      start of the message; the requests after it start there (TAiConversation.LastSummary).
      A provider may keep a summary encrypted - an abSummary block without text, its Native
      form readable only by that provider: the provider's backend starts its requests there
      itself, and the others send the conversation before it as it is;
    * TAiTool, the abstract tool: name, description, input schema, whether it changes something
      (then the session asks for approval first, with the preview the tool gives), and Execute;
    * TAiSettings, where backends and the harness keep their values.
  Text in the core is UTF-8. Nothing here knows the IDE. }

interface

uses
  Windows, SysUtils, Classes, Contnrs, AiJson;

type
  TAiRole = (arUser, arAssistant);

  { abSummary: a summary of the conversation before it, which it stands for in the requests
    after it }
  TAiBlockKind = (abText, abReasoning, abToolCall, abToolResult, abSummary, abOther);

  TAiStopReason = (asNone, asEndTurn, asToolUse, asMaxTokens, asRefusal, asPauseTurn,
    asStopSequence, asOther);

  TAiUsage = record
    InputTokens: Int64;
    OutputTokens: Int64;
    CacheReadTokens: Int64;
    CacheWriteTokens: Int64;
    Cost: Double;             // what the provider charged, in US dollars, when it says (0: it does not)
  end;

  TAiBlock = class
  private
    FKind: TAiBlockKind;
    FText: string;
    FId: string;
    FName: string;
    FInput: TJson;
    FInputText: string;
    FIsError: Boolean;
    FNative: TJson;
    FNativeOwner: string;
    procedure SetInput(Value: TJson);
    procedure SetNative(Value: TJson);
  public
    constructor Create(AKind: TAiBlockKind);
    destructor Destroy; override;
    function Clone: TAiBlock;
    property Kind: TAiBlockKind read FKind write FKind;
    { abText: the text; abReasoning: what is shown of it (may be empty); abToolResult: the
      result; abSummary: the summary (empty: none could be written, or its provider keeps it
      encrypted in Native); abOther: a description }
    property Text: string read FText write FText;
    { abToolCall / abToolResult: the call's id }
    property Id: string read FId write FId;
    { abToolCall: the tool's name }
    property Name: string read FName write FName;
    { abToolCall: the input object (owned); nil when the model's input was not valid JSON }
    property Input: TJson read FInput write SetInput;
    { abToolCall: the input as the model sent it }
    property InputText: string read FInputText write FInputText;
    { abToolResult: the tool failed or was not run }
    property IsError: Boolean read FIsError write FIsError;
    { the block in its provider's format (owned), echoed unchanged to that provider }
    property Native: TJson read FNative write SetNative;
    { the id of the backend whose format Native is }
    property NativeOwner: string read FNativeOwner write FNativeOwner;
  end;

  TAiMessage = class
  private
    FRole: TAiRole;
    FBlocks: TObjectList;
    function GetBlock(Index: Integer): TAiBlock;
  public
    StopReason: TAiStopReason;
    StopDetail: string;       // e.g. the category of a refusal
    Model: string;            // the model that wrote it
    Usage: TAiUsage;          // what it cost, a summarization of the context included
    { how full the context window is after this answer: the request's prompt and the answer, in
      tokens (0: unknown) }
    ContextTokens: Int64;
    { the message as a backend serialized it (Cache, the JSON text; CacheOwner, the backend's
      id): a message sent never changes, and adding a block clears it }
    Cache: string;
    CacheOwner: string;
    constructor Create(ARole: TAiRole);
    destructor Destroy; override;
    function Add(Block: TAiBlock): TAiBlock;
    function AddText(const Utf8: string): TAiBlock;
    function AddToolResult(const CallId, Utf8: string; IsError: Boolean): TAiBlock;
    function Count: Integer;
    { the text blocks joined }
    function Text: string;
    { its summary of the conversation before it: an abSummary block with text (nil: none) }
    function Summary: TAiBlock;
    function HasSummary: Boolean;
    property Role: TAiRole read FRole;
    property Blocks[Index: Integer]: TAiBlock read GetBlock; default;
  end;

  TAiConversation = class
  private
    FMessages: TObjectList;
    function GetMessage(Index: Integer): TAiMessage;
  public
    constructor Create;
    destructor Destroy; override;
    { appends Msg (owned from now on) }
    procedure Add(Msg: TAiMessage);
    procedure Clear;
    function Count: Integer;
    function Last: TAiMessage;
    { the last message with a summary of the conversation before it (HasSummary); -1: none.
      A request leaves out what the summary stands for: a backend starts it with that message,
      in the form its API takes }
    function LastSummary: Integer;
    property Messages[Index: Integer]: TAiMessage read GetMessage; default;
  end;

  { values of the harness and its backends; strings are IDE strings }
  TAiSettings = class
  public
    function ReadString(const Name, Default: string): string; virtual; abstract;
    procedure WriteString(const Name, Value: string); virtual; abstract;
    function ReadInteger(const Name: string; Default: Integer): Integer;
    procedure WriteInteger(const Name: string; Value: Integer);
    function ReadBool(const Name: string; Default: Boolean): Boolean;
    procedure WriteBool(const Name: string; Value: Boolean);
    { kept encrypted for the Windows user (DPAPI) }
    function ReadSecret(const Name: string): string;
    procedure WriteSecret(const Name, Value: string);
  end;

  TAiMemorySettings = class(TAiSettings)
  private
    FValues: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadString(const Name, Default: string): string; override;
    procedure WriteString(const Name, Value: string); override;
  end;

  TAiTool = class;
  TAiToolList = class;

  { what a backend reports while a message streams in (called in the worker thread). A summary
    of the conversation is an abSummary block too: BlockStarted when the summarizing begins,
    BlockFinished with the block (its Text, the summary) when it ends }
  TAiBackendEvents = class
  public
    procedure BlockStarted(Index: Integer; Kind: TAiBlockKind; const Name: string); virtual;
    procedure Delta(Index: Integer; Kind: TAiBlockKind; const Utf8: string); virtual;
    procedure BlockFinished(Index: Integer; Block: TAiBlock); virtual;
    procedure Status(const Utf8: string); virtual;
  end;

  EAiBackendError = class(Exception);

  { A model backend. Its settings are '<Id>.<Name>': Model, Effort, MaxTokens, Reasoning (what
    is shown of the model's reasoning), ApiKey (a secret) and BaseUrl; the settings dialog
    offers the choices the class lists. }
  TAiBackend = class
  private
    FSettings: TAiSettings;
  protected
    { the backend's value Name (stored as '<Id>.<Name>') }
    function Setting(const Name, Default: string): string;
    function SettingInt(const Name: string; Default: Integer): Integer;
    function Secret(const Name: string): string;
  public
    constructor Create(ASettings: TAiSettings); virtual;
    { a short id: the prefix of its settings, the owner of its native blocks }
    class function Id: string; virtual; abstract;
    class function DisplayName: string; virtual; abstract;
    { the choices of the settings dialog and the defaults }
    class procedure ListModels(L: TStrings); virtual;
    class procedure ListEfforts(L: TStrings); virtual;
    class procedure ListReasoning(L: TStrings); virtual;
    class function DefaultModel: string; virtual;
    class function DefaultEffort: string; virtual;
    class function DefaultReasoning: string; virtual;
    class function DefaultMaxTokens: Integer; virtual;
    class function DefaultBaseUrl: string; virtual;
    { context management (see the unit's head). The backend summarizes a long conversation
      (with some of its models at least): the settings dialog offers CompactAt, the prompt's
      size in tokens that sets a summary off - 0 never, else at least MinCompactAt }
    class function SupportsCompaction: Boolean; virtual;
    class function DefaultCompactAt: Integer; virtual;
    class function MinCompactAt: Integer; virtual;
    { the environment variable that holds the API key when the settings have none }
    class function KeyVariable: string; virtual;
    { the backend cannot send without a key (a local server needs none) }
    class function KeyRequired: Boolean; virtual;
    { the wire protocols the settings dialog offers (the setting Protocol); none: the backend
      speaks one, DefaultProtocol, which the dialog shows }
    class procedure ListProtocols(L: TStrings); virtual;
    class function DefaultProtocol: string; virtual;
    { the API key: the settings', else the environment variable's }
    function ApiKey: string;
    { False with a reason when it cannot send (a missing key ...) }
    function Ready(out Problem: string): Boolean; virtual;
    { the model a request uses }
    function ModelName: string; virtual;
    { the model's context window in tokens, as far as the backend knows it (0: unknown). Cheap:
      no request - a backend learns it in Send }
    function ContextWindow: Int64; virtual;
    { the model of the settings can summarize the conversation (the base: SupportsCompaction) }
    function ModelCompacts: Boolean; virtual;
    { the prompt's size in tokens at which Send summarizes the conversation first: the setting
      CompactAt (at least MinCompactAt); 0 when never, or when the model cannot }
    function CompactAt: Integer; virtual;
    { sends the conversation and returns the next assistant message (the caller owns it).
      Runs in the worker thread. Raises EAiCancelled after Cancel, EAiBackendError otherwise. }
    function Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
      Events: TAiBackendEvents): TAiMessage; virtual; abstract;
    { from any thread }
    procedure Cancel; virtual; abstract;
    procedure ResetCancel; virtual; abstract;
    { a cost estimate of Usage in US dollars; negative when unknown }
    function EstimateCost(const Usage: TAiUsage): Double; virtual;
    property Settings: TAiSettings read FSettings;
  end;

  TAiBackendClass = class of TAiBackend;

  { what a change will do, for the approval }
  TAiChangePreview = class
  public
    Title: string;       // one line: 'Edit Unit1.pas, lines 40-42'
    FileName: string;
    Before: string;      // the text that goes (may be empty)
    After: string;       // the text that comes (may be empty)
    Notes: string;
    procedure Clear;
  end;

  TAiToolResult = class
  public
    Text: string;        // what the model gets
    IsError: Boolean;
    Summary: string;     // a short line for the transcript
    procedure Ok(const AText, ASummary: string);
    procedure Fail(const AText: string);
  end;

  { runs a method in the IDE's main thread, from the worker thread }
  TAiToolContext = class
  public
    procedure RunInMainThread(Method: TThreadMethod); virtual; abstract;
    function Cancelled: Boolean; virtual; abstract;
    procedure Status(const Utf8: string); virtual; abstract;
  end;

  TAiTool = class
  public
    function Name: string; virtual; abstract;
    function Description: string; virtual; abstract;
    { fills the schema's "properties" and "required" (it is an object schema already) }
    procedure DefineInput(Schema: TJson); virtual; abstract;
    { True: changes code or files - the session asks for approval with Preview first }
    function IsChange: Boolean; virtual;
    { True: Execute is called in the main thread (the IDE's tools); False: in the worker thread }
    function RunsInMainThread: Boolean; virtual;
    { a short description of a call for the transcript ('Unit1.pas, lines 1-200') }
    function Summarize(Input: TJson): string; virtual;
    { describes the change for the approval; False with Res filled when the call cannot be done
      (then nobody is asked). Called in the main thread. }
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; virtual;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); virtual; abstract;
    { the tool's definition: name, description, input_schema }
    function Schema: TJson;
  end;

  TAiToolList = class
  private
    FTools: TObjectList;
    function GetTool(Index: Integer): TAiTool;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Tool: TAiTool);
    function Count: Integer;
    function Find(const Name: string): TAiTool;
    property Tools[Index: Integer]: TAiTool read GetTool; default;
  end;

const
  { what a summary of the conversation keeps: the instructions of a request that summarizes it }
  SummaryInstructions =
    'Summarize the conversation so far, so that the work can go on from the summary alone. Do not call ' +
    'any tools. Keep: what the user asked for and decided; the project and the files involved, with their ' +
    'full paths; what was read, found and changed in them, with line numbers where they matter; the results ' +
    'of the last compiles that are still open; code that will be needed again; and the plan with its next ' +
    'steps. Write the summary inside <summary></summary> tags.';
  { what goes before a summary that a model gets as a message of its own }
  SummaryIntro = 'The conversation before this point, summarized:'#10#10;

{ the summary in a model's answer to SummaryInstructions: the text inside <summary></summary>,
  else the whole answer }
function SummaryOfAnswer(const Utf8: string): string;

procedure RegisterAiBackend(C: TAiBackendClass);
function AiBackendCount: Integer;
function AiBackendClass(Index: Integer): TAiBackendClass;
function FindAiBackend(const Id: string): TAiBackendClass;

{ the input checked against the tool's schema: required members present, members of the
  declared types (string, integer, number, boolean, array, object) and enum values; '' when it
  is valid, else the problems }
function ValidateInput(Schema, Input: TJson): string;

{ schema helpers for DefineInput }
procedure SchemaProp(Schema: TJson; const Name, JsonType, Description: string; Required: Boolean);
procedure SchemaEnum(Schema: TJson; const Name, Values, Description: string; Required: Boolean);
procedure SchemaArray(Schema: TJson; const Name, ItemType, Description: string; Required: Boolean);

procedure AddUsage(var Total: TAiUsage; const U: TAiUsage);
{ what Usage costs in US dollars at prices per million tokens: input, cache reads, cache writes,
  output }
function UsageCost(const Usage: TAiUsage; InputPrice, CachedPrice, WritePrice, OutputPrice: Double): Double;
function StopReasonText(R: TAiStopReason): string;
{ 'a|b|c' as lines }
procedure SplitBars(const S: string; L: TStrings);

implementation

uses
  AiText;

var
  Backends: TList;

procedure RegisterAiBackend(C: TAiBackendClass);
begin
  if Backends = nil then Backends := TList.Create;
  if Backends.IndexOf(C) < 0 then Backends.Add(C);
end;

function AiBackendCount: Integer;
begin
  if Backends = nil then Result := 0 else Result := Backends.Count;
end;

function AiBackendClass(Index: Integer): TAiBackendClass;
begin
  Result := TAiBackendClass(Backends[Index]);
end;

function FindAiBackend(const Id: string): TAiBackendClass;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AiBackendCount - 1 do
    if SameText(AiBackendClass(I).Id, Id) then
    begin
      Result := AiBackendClass(I);
      Exit;
    end;
end;

procedure AddUsage(var Total: TAiUsage; const U: TAiUsage);
begin
  Inc(Total.InputTokens, U.InputTokens);
  Inc(Total.OutputTokens, U.OutputTokens);
  Inc(Total.CacheReadTokens, U.CacheReadTokens);
  Inc(Total.CacheWriteTokens, U.CacheWriteTokens);
  Total.Cost := Total.Cost + U.Cost;
end;

function UsageCost(const Usage: TAiUsage; InputPrice, CachedPrice, WritePrice, OutputPrice: Double): Double;
begin
  Result := (Usage.InputTokens * InputPrice + Usage.CacheReadTokens * CachedPrice +
    Usage.CacheWriteTokens * WritePrice + Usage.OutputTokens * OutputPrice) / 1000000;
end;

function SummaryOfAnswer(const Utf8: string): string;
var
  P, Q: Integer;
begin
  Result := Utf8;
  P := Pos('<summary>', Result);
  if P = 0 then Exit;
  Delete(Result, 1, P + Length('<summary>') - 1);
  Q := Pos('</summary>', Result);
  if Q > 0 then SetLength(Result, Q - 1);
end;

function StopReasonText(R: TAiStopReason): string;
const
  Names: array[TAiStopReason] of string = ('none', 'end_turn', 'tool_use', 'max_tokens',
    'refusal', 'pause_turn', 'stop_sequence', 'other');
begin
  Result := Names[R];
end;

{ ---------------------------------------------------------------- TAiBlock }

constructor TAiBlock.Create(AKind: TAiBlockKind);
begin
  inherited Create;
  FKind := AKind;
end;

destructor TAiBlock.Destroy;
begin
  FInput.Free;
  FNative.Free;
  inherited;
end;

procedure TAiBlock.SetInput(Value: TJson);
begin
  if Value = FInput then Exit;
  FInput.Free;
  FInput := Value;
end;

procedure TAiBlock.SetNative(Value: TJson);
begin
  if Value = FNative then Exit;
  FNative.Free;
  FNative := Value;
end;

function TAiBlock.Clone: TAiBlock;
begin
  Result := TAiBlock.Create(FKind);
  Result.FText := FText;
  Result.FId := FId;
  Result.FName := FName;
  if FInput <> nil then Result.FInput := FInput.Clone;
  Result.FInputText := FInputText;
  Result.FIsError := FIsError;
  if FNative <> nil then Result.FNative := FNative.Clone;
  Result.FNativeOwner := FNativeOwner;
end;

{ ---------------------------------------------------------------- TAiMessage }

constructor TAiMessage.Create(ARole: TAiRole);
begin
  inherited Create;
  FRole := ARole;
  FBlocks := TObjectList.Create(True);
end;

destructor TAiMessage.Destroy;
begin
  FBlocks.Free;
  inherited;
end;

function TAiMessage.Add(Block: TAiBlock): TAiBlock;
begin
  FBlocks.Add(Block);
  Cache := '';
  CacheOwner := '';
  Result := Block;
end;

{ the text of the user and of the tools is made valid UTF-8 as it enters the conversation: a
  request with one invalid byte is refused, and the conversation is sent again every turn }
function TAiMessage.AddText(const Utf8: string): TAiBlock;
begin
  Result := Add(TAiBlock.Create(abText));
  Result.Text := SanitizeUtf8(Utf8);
end;

function TAiMessage.AddToolResult(const CallId, Utf8: string; IsError: Boolean): TAiBlock;
begin
  Result := Add(TAiBlock.Create(abToolResult));
  Result.Id := CallId;
  Result.Text := SanitizeUtf8(Utf8);
  Result.IsError := IsError;
end;

function TAiMessage.Count: Integer;
begin
  Result := FBlocks.Count;
end;

function TAiMessage.GetBlock(Index: Integer): TAiBlock;
begin
  Result := TAiBlock(FBlocks[Index]);
end;

function TAiMessage.Text: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Count - 1 do
    if Blocks[I].Kind = abText then Result := Result + Blocks[I].Text;
end;

function TAiMessage.Summary: TAiBlock;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Result := Blocks[I];
    if (Result.Kind = abSummary) and (Trim(Result.Text) <> '') then Exit;
  end;
  Result := nil;
end;

function TAiMessage.HasSummary: Boolean;
begin
  Result := Summary <> nil;
end;

{ ---------------------------------------------------------------- TAiConversation }

constructor TAiConversation.Create;
begin
  inherited Create;
  FMessages := TObjectList.Create(True);
end;

destructor TAiConversation.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TAiConversation.Add(Msg: TAiMessage);
begin
  FMessages.Add(Msg);
end;

procedure TAiConversation.Clear;
begin
  FMessages.Clear;
end;

function TAiConversation.Count: Integer;
begin
  Result := FMessages.Count;
end;

function TAiConversation.Last: TAiMessage;
begin
  if Count = 0 then Result := nil else Result := Messages[Count - 1];
end;

function TAiConversation.LastSummary: Integer;
begin
  Result := Count - 1;
  while (Result >= 0) and not Messages[Result].HasSummary do Dec(Result);
end;

function TAiConversation.GetMessage(Index: Integer): TAiMessage;
begin
  Result := TAiMessage(FMessages[Index]);
end;

{ ---------------------------------------------------------------- TAiSettings }

function TAiSettings.ReadInteger(const Name: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(ReadString(Name, IntToStr(Default)), Default);
end;

procedure TAiSettings.WriteInteger(const Name: string; Value: Integer);
begin
  WriteString(Name, IntToStr(Value));
end;

function TAiSettings.ReadBool(const Name: string; Default: Boolean): Boolean;
begin
  Result := ReadInteger(Name, Ord(Default)) <> 0;
end;

procedure TAiSettings.WriteBool(const Name: string; Value: Boolean);
begin
  WriteInteger(Name, Ord(Value));
end;

function TAiSettings.ReadSecret(const Name: string): string;
var
  S: string;
begin
  S := ReadString(Name, '');
  if S = '' then Result := '' else Result := UnprotectSecret(S);
end;

procedure TAiSettings.WriteSecret(const Name, Value: string);
begin
  if Value = '' then WriteString(Name, '') else WriteString(Name, ProtectSecret(Value));
end;

constructor TAiMemorySettings.Create;
begin
  inherited Create;
  FValues := TStringList.Create;
end;

destructor TAiMemorySettings.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TAiMemorySettings.ReadString(const Name, Default: string): string;
var
  I: Integer;
begin
  I := FValues.IndexOfName(Name);
  if I < 0 then Result := Default else Result := Copy(FValues[I], Length(Name) + 2, MaxInt);
end;

procedure TAiMemorySettings.WriteString(const Name, Value: string);
var
  I: Integer;
begin
  I := FValues.IndexOfName(Name);
  if I >= 0 then FValues[I] := Name + '=' + Value else FValues.Add(Name + '=' + Value);
end;

{ ---------------------------------------------------------------- TAiBackendEvents }

procedure TAiBackendEvents.BlockStarted(Index: Integer; Kind: TAiBlockKind; const Name: string);
begin
end;

procedure TAiBackendEvents.Delta(Index: Integer; Kind: TAiBlockKind; const Utf8: string);
begin
end;

procedure TAiBackendEvents.BlockFinished(Index: Integer; Block: TAiBlock);
begin
end;

procedure TAiBackendEvents.Status(const Utf8: string);
begin
end;

{ ---------------------------------------------------------------- TAiBackend }

constructor TAiBackend.Create(ASettings: TAiSettings);
begin
  inherited Create;
  FSettings := ASettings;
end;

class procedure TAiBackend.ListModels(L: TStrings);
begin
end;

class procedure TAiBackend.ListEfforts(L: TStrings);
begin
end;

class procedure TAiBackend.ListReasoning(L: TStrings);
begin
end;

class function TAiBackend.DefaultModel: string;
begin
  Result := '';
end;

class function TAiBackend.DefaultEffort: string;
begin
  Result := '';
end;

class function TAiBackend.DefaultReasoning: string;
begin
  Result := '';
end;

class function TAiBackend.DefaultMaxTokens: Integer;
begin
  Result := 16000;
end;

class function TAiBackend.DefaultBaseUrl: string;
begin
  Result := '';
end;

class function TAiBackend.SupportsCompaction: Boolean;
begin
  Result := False;
end;

class function TAiBackend.DefaultCompactAt: Integer;
begin
  Result := 0;
end;

class function TAiBackend.MinCompactAt: Integer;
begin
  Result := 0;
end;

function TAiBackend.ModelCompacts: Boolean;
begin
  Result := SupportsCompaction;
end;

function TAiBackend.CompactAt: Integer;
begin
  Result := 0;
  if not SupportsCompaction then Exit;
  Result := SettingInt('CompactAt', DefaultCompactAt);
  if Result <= 0 then Result := 0
  else if not ModelCompacts then Result := 0
  else if Result < MinCompactAt then Result := MinCompactAt;
end;

class function TAiBackend.KeyVariable: string;
begin
  Result := '';
end;

class function TAiBackend.KeyRequired: Boolean;
begin
  Result := True;
end;

class procedure TAiBackend.ListProtocols(L: TStrings);
begin
end;

class function TAiBackend.DefaultProtocol: string;
begin
  Result := '';
end;

function TAiBackend.ContextWindow: Int64;
begin
  Result := 0;
end;

function TAiBackend.ApiKey: string;
begin
  Result := Trim(Secret('ApiKey'));
  if (Result = '') and (KeyVariable <> '') then Result := Trim(GetEnvironmentVariable(KeyVariable));
end;

function TAiBackend.Setting(const Name, Default: string): string;
begin
  if FSettings = nil then Result := Default
  else Result := FSettings.ReadString(Id + '.' + Name, Default);
end;

function TAiBackend.SettingInt(const Name: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(Setting(Name, IntToStr(Default)), Default);
end;

function TAiBackend.Secret(const Name: string): string;
begin
  if FSettings = nil then Result := '' else Result := FSettings.ReadSecret(Id + '.' + Name);
end;

function TAiBackend.Ready(out Problem: string): Boolean;
begin
  Problem := '';
  Result := True;
end;

function TAiBackend.ModelName: string;
begin
  Result := '';
end;

function TAiBackend.EstimateCost(const Usage: TAiUsage): Double;
begin
  Result := -1;
end;

{ ---------------------------------------------------------------- previews, results }

procedure TAiChangePreview.Clear;
begin
  Title := '';
  FileName := '';
  Before := '';
  After := '';
  Notes := '';
end;

procedure TAiToolResult.Ok(const AText, ASummary: string);
begin
  Text := AText;
  Summary := ASummary;
  IsError := False;
end;

procedure TAiToolResult.Fail(const AText: string);
begin
  Text := AText;
  Summary := AText;
  IsError := True;
end;

{ ---------------------------------------------------------------- TAiTool }

function TAiTool.IsChange: Boolean;
begin
  Result := False;
end;

function TAiTool.RunsInMainThread: Boolean;
begin
  Result := True;
end;

function TAiTool.Summarize(Input: TJson): string;
begin
  Result := '';
end;

function TAiTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
begin
  Change.Title := Name;
  Result := True;
end;

function TAiTool.Schema: TJson;
var
  S: TJson;
begin
  Result := TJson.NewObject;
  Result.PutStr('name', Name);
  Result.PutStr('description', Description);
  S := Result.PutObject('input_schema');
  S.PutStr('type', 'object');
  S.PutObject('properties');
  DefineInput(S);
end;

{ ---------------------------------------------------------------- schema helpers }

procedure SplitBars(const S: string; L: TStrings);
var
  P: Integer;
  Rest: string;
begin
  L.Clear;
  Rest := S;
  while Rest <> '' do
  begin
    P := Pos('|', Rest);
    if P = 0 then P := Length(Rest) + 1;
    L.Add(Copy(Rest, 1, P - 1));
    Delete(Rest, 1, P);
  end;
end;

{ the schema's property Name of JsonType (with its description; listed as required when it is) }
function NewProperty(Schema: TJson; const Name, JsonType, Description: string; Required: Boolean): TJson;
var
  Props, R: TJson;
begin
  Props := Schema.Obj('properties');
  if Props = nil then Props := Schema.PutObject('properties');
  Result := Props.PutObject(Name);
  Result.PutStr('type', JsonType);
  if Description <> '' then Result.PutStr('description', Description);
  if Required then
  begin
    R := Schema.Arr('required');
    if R = nil then R := Schema.PutArray('required');
    R.AddString(Name);
  end;
end;

procedure SchemaProp(Schema: TJson; const Name, JsonType, Description: string; Required: Boolean);
begin
  NewProperty(Schema, Name, JsonType, Description, Required);
end;

procedure SchemaEnum(Schema: TJson; const Name, Values, Description: string; Required: Boolean);
var
  E: TJson;
  L: TStringList;
  I: Integer;
begin
  E := NewProperty(Schema, Name, 'string', Description, Required).PutArray('enum');
  L := TStringList.Create;
  try
    SplitBars(Values, L);
    for I := 0 to L.Count - 1 do E.AddString(L[I]);
  finally
    L.Free;
  end;
end;

procedure SchemaArray(Schema: TJson; const Name, ItemType, Description: string; Required: Boolean);
begin
  NewProperty(Schema, Name, 'array', Description, Required).PutObject('items').PutStr('type', ItemType);
end;

function KindMatches(V: TJson; const JsonType: string): Boolean;
var
  S: string;
begin
  if JsonType = 'string' then Result := V.Kind = jkString
  else if JsonType = 'integer' then
  begin
    S := V.AsString;
    Result := ((V.Kind = jkNumber) and (Pos('.', S) = 0) and (Pos('e', LowerCase(S)) = 0)) or
      ((V.Kind = jkString) and (StrToIntDef(Trim(S), MaxInt) <> MaxInt));
  end
  else if JsonType = 'number' then Result := V.Kind = jkNumber
  else if JsonType = 'boolean' then
    Result := (V.Kind in [jkTrue, jkFalse]) or
      ((V.Kind = jkString) and (SameText(V.AsString, 'true') or SameText(V.AsString, 'false')))
  else if JsonType = 'array' then Result := V.Kind = jkArray
  else if JsonType = 'object' then Result := V.Kind = jkObject
  else Result := True;
end;

function ValidateInput(Schema, Input: TJson): string;
var
  Props, Req, P, V, E: TJson;
  I, J: Integer;
  Name, T: string;
  Found: Boolean;
begin
  Result := '';
  if (Input = nil) or not Input.IsObject then
  begin
    Result := 'The input must be a JSON object.';
    Exit;
  end;
  Req := Schema.Arr('required');
  if Req <> nil then
    for I := 0 to Req.Count - 1 do
    begin
      Name := Req.Item(I).AsString;
      V := Input.Get(Name);
      if (V = nil) or V.IsNull then Result := Result + Format('"%s" is required. ', [Name]);
    end;
  Props := Schema.Obj('properties');
  if Props <> nil then
    for I := 0 to Input.Count - 1 do
    begin
      Name := Input.Name(I);
      V := Input.Item(I);
      P := Props.Obj(Name);
      if P = nil then
      begin
        Result := Result + Format('"%s" is not a parameter of this tool. ', [Name]);
        Continue;
      end;
      if V.IsNull then Continue;
      T := P.Str('type');
      if (T <> '') and not KindMatches(V, T) then
        Result := Result + Format('"%s" must be of type %s. ', [Name, T]);
      E := P.Arr('enum');
      if (E <> nil) and (V.Kind = jkString) then
      begin
        Found := False;
        for J := 0 to E.Count - 1 do
          if E.Item(J).AsString = V.AsString then Found := True;
        if not Found then Result := Result + Format('"%s" must be one of %s. ', [Name, E.ToJson]);
      end;
    end;
  Result := TrimRightText(Result);
end;

{ ---------------------------------------------------------------- TAiToolList }

constructor TAiToolList.Create;
begin
  inherited Create;
  FTools := TObjectList.Create(True);
end;

destructor TAiToolList.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TAiToolList.Add(Tool: TAiTool);
begin
  FTools.Add(Tool);
end;

function TAiToolList.Count: Integer;
begin
  Result := FTools.Count;
end;

function TAiToolList.Find(const Name: string): TAiTool;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Tools[I].Name = Name then
    begin
      Result := Tools[I];
      Exit;
    end;
end;

function TAiToolList.GetTool(Index: Integer): TAiTool;
begin
  Result := TAiTool(FTools[Index]);
end;

initialization
finalization
  Backends.Free;
end.
