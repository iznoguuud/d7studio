{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiClaude;

{ The Claude backend of the AI harness: Anthropic's Messages API over HTTPS (POST /v1/messages,
  streamed as server-sent events). There is no Anthropic SDK for Delphi, so the requests are
  built and the streams read here.

  What a request holds:
    * the model (default claude-opus-5-5), max_tokens (64000: thinking counts toward it), and
      stream: true;
    * thinking (type adaptive, with a display) and output_config.effort on the models that
      take them; display "summarized" (default) returns readable summaries of the reasoning,
      "updates" (a beta) only the short progress notes, "omitted" nothing;
    * the system prompt as one text block with a cache breakpoint, and the request's automatic
      cache breakpoint (top-level cache_control) for the growing conversation;
    * the tools with eager_input_streaming: their input streams as it is generated and is not
      validated by the API - the session validates it against the schema before running a tool,
      and input that is not valid JSON goes back to the model as an INVALID_JSON error;
    * fallbacks: "default" (beta server-side-fallback-2026-07-01) on the models that offer it: a
      request a safety classifier declines is answered by the fallback model in the same call;
    * context_management with the compact_20260112 edit (beta compact-2026-01-12): the core's
      compaction (AiCore) done by the API. Once the prompt reaches CompactAt tokens (default
      150,000, the API's), the API summarizes the conversation first and returns the summary as
      a "compaction" block at the start of the answer - an abSummary block here. The block is
      echoed like the others, and the API ignores what comes before it: later requests start
      with the message that holds it, as the API's documentation shows. A summary another
      backend wrote, or one the model cannot take, goes first as a user message of its own.
      The beta goes with every request that holds a compaction block. The summarizer gets
      instructions: what to keep, and no tool calls (with tools in the request it could call
      one and return no summary).
  The model's context window and whether it summarizes come from the Models API (max_input_tokens,
  capabilities.context_management.compact_20260112), asked before a model's first request until
  it answers; until then from what this unit knows (ClaudeContextWindow, ClaudeCompaction).
  The assistant's blocks are kept as the API sent them and echoed unchanged; after a fallback
  inside a message, the thinking and tool_use blocks before the last "fallback" block are left
  out of the echo (they belong to the declined attempt), and their tool calls are not run.
  A message never changes once sent, so each is serialized once (TAiMessage.Cache), and so is
  the tool list; a block's streamed text grows in a builder and goes into its JSON when the
  block ends.
  Rate limits, overloads and server errors are retried with backoff (retry-after when given). }

interface

uses
  Windows, SysUtils, Classes, AiText, AiJson, AiCore, AiHttp, AiRemote;

type
  TAiClaudeBackend = class(TAiRemoteBackend)
  private
    FSse: TAiSseParser;
    FBlocks: TList;            // native blocks (TJson, owned) by stream index
    FParts: TList;             // TKitStringBuilder by index: the streamed text, thinking or input JSON
    FSigs: TList;              // TKitStringBuilder by index: a thinking block's signature
    FModel: string;
    FStopReason: string;
    FStopDetail: string;
    FUsage: TAiUsage;
    FCompacted: TAiUsage;      // what a summarization of the context cost (usage.iterations)
    FStarted: Boolean;
    FInfoModel: string;        // the model that FWindow and FCompaction describe
    FInfoAsked: Boolean;       // the Models API was asked about FInfoModel
    FWindow: Int64;            // its context window (0: unknown)
    FCompaction: Boolean;      // it summarizes a long conversation (compact_20260112)
    FBetas: string;            // the anthropic-beta header of the last BuildRequest
    FToolsJson: string;        // the tool list as sent, for FToolsFrom with FToolsCount tools
    FToolsFrom: TAiToolList;
    FToolsCount: Integer;
    procedure HandleEvent(const EventName, Data: string);
    procedure ReadUsage(U: TJson);
    function NativeBlock(Index: Integer): TJson;
    procedure SetNativeBlock(Index: Integer; Block: TJson);
    procedure FinishBlock(Index: Integer);
    function MessageJson(Msg: TAiMessage; Compaction: Boolean): string;
    function ToolsJson(Tools: TAiToolList): string;
    procedure ModelInfo(Ask: Boolean);
  protected
    procedure ResetStream; override;
    procedure Feed(const Data: string); override;
    procedure FinishStream; override;
    function BuildMessage: TAiMessage; override;
  public
    constructor Create(ASettings: TAiSettings); override;
    destructor Destroy; override;
    class function Id: string; override;
    class function DisplayName: string; override;
    class procedure ListModels(L: TStrings); override;
    class procedure ListEfforts(L: TStrings); override;
    class procedure ListReasoning(L: TStrings); override;
    class function DefaultModel: string; override;
    class function DefaultEffort: string; override;
    class function DefaultReasoning: string; override;
    class function DefaultMaxTokens: Integer; override;
    class function DefaultBaseUrl: string; override;
    class function KeyVariable: string; override;
    class function DefaultProtocol: string; override;
    class function SupportsCompaction: Boolean; override;
    class function DefaultCompactAt: Integer; override;
    class function MinCompactAt: Integer; override;
    function Ready(out Problem: string): Boolean; override;
    function ContextWindow: Int64; override;
    function ModelCompacts: Boolean; override;
    function Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
      Events: TAiBackendEvents): TAiMessage; override;
    function EstimateCost(const Usage: TAiUsage): Double; override;
    { the request body (UTF-8 JSON), and Betas for it - public for the tests }
    function BuildRequest(Conversation: TAiConversation; const System: string; Tools: TAiToolList): string;
    { the beta features the last BuildRequest's request uses (the anthropic-beta header) }
    property Betas: string read FBetas;
    { asks the Models API about the model of the settings, as Send does before a model's first
      request - public for the tests }
    procedure AskModelInfo;
    { a recorded stream read into a message (the tests) }
    function ParseStream(const Stream: string; Events: TAiBackendEvents): TAiMessage;
  end;

const
  AnthropicVersion = '2026-10-21';
  FallbackBeta = 'server-side-fallback-2026-07-01';
  UpdatesBeta = 'thinking-display-updates-2026-08-18';
  CompactBeta = 'compact-2026-01-12';

{ capabilities by model id }
function ClaudeAdaptiveThinking(const Model: string): Boolean;
function ClaudeCompaction(const Model: string): Boolean;
function ClaudeContextWindow(const Model: string): Int64;
function ClaudeServerFallback(const Model: string): Boolean;
function ClaudeUpdatesDisplay(const Model: string): Boolean;

implementation

function ClaudeAdaptiveThinking(const Model: string): Boolean;
begin
  Result := KitStartsWith(Model, 'claude-opus-5') or KitStartsWith(Model, 'claude-sonnet-5') or
    KitStartsWith(Model, 'claude-haiku-5') or KitStartsWith(Model, 'claude-fable-5') or
    KitStartsWith(Model, 'claude-mythos-5') or KitStartsWith(Model, 'claude-opus-4-6') or
    KitStartsWith(Model, 'claude-opus-4-7') or KitStartsWith(Model, 'claude-opus-4-8') or
    KitStartsWith(Model, 'claude-sonnet-4-6');
end;

{ the models that summarize a long conversation (compact_20260112), when the Models API does not say }
function ClaudeCompaction(const Model: string): Boolean;
begin
  Result := ClaudeAdaptiveThinking(Model);
end;

{ the context window of the models this unit knows (when the Models API does not answer) }
function ClaudeContextWindow(const Model: string): Int64;
begin
  if KitStartsWith(Model, 'claude-haiku-4-5') then Result := 200000
  else if ClaudeAdaptiveThinking(Model) then Result := 1000000
  else Result := 0;
end;

const
  { the summarizer's instructions: AiCore's, which the other backends' own summaries use too }
  CompactionInstructions = SummaryInstructions;

function ClaudeServerFallback(const Model: string): Boolean;
begin
  Result := (Model = 'claude-opus-5-5') or (Model = 'claude-opus-5') or (Model = 'claude-sonnet-5-5') or
    (Model = 'claude-fable-5-2') or (Model = 'claude-fable-5-1') or (Model = 'claude-mythos-5-2') or
    (Model = 'claude-mythos-5-1');
end;

function ClaudeUpdatesDisplay(const Model: string): Boolean;
begin
  Result := KitStartsWith(Model, 'claude-fable-5') or (Model = 'claude-mythos-5-2') or
    (Model = 'claude-mythos-5-1') or (Model = 'claude-opus-5-5') or (Model = 'claude-sonnet-5-5');
end;

function StopReasonOf(const S: string): TAiStopReason;
begin
  if S = 'end_turn' then Result := asEndTurn
  else if S = 'tool_use' then Result := asToolUse
  else if S = 'max_tokens' then Result := asMaxTokens
  else if S = 'refusal' then Result := asRefusal
  else if S = 'pause_turn' then Result := asPauseTurn
  else if S = 'stop_sequence' then Result := asStopSequence
  else if S = 'model_context_window_exceeded' then Result := asMaxTokens
  else Result := asOther;
end;

{ the "model" of the member object Name of a fallback block }
function MemberModel(Block: TJson; const Name, Default: string): string;
var
  O: TJson;
begin
  O := Block.Obj(Name);
  if O = nil then Result := Default else Result := O.Str('model', Default);
end;

function BlockKindOf(const NativeType: string): TAiBlockKind;
begin
  if NativeType = 'text' then Result := abText
  else if (NativeType = 'thinking') or (NativeType = 'redacted_thinking') then Result := abReasoning
  else if NativeType = 'tool_use' then Result := abToolCall
  else if NativeType = 'compaction' then Result := abSummary
  else Result := abOther;
end;

{ ---------------------------------------------------------------- TAiClaudeBackend }

constructor TAiClaudeBackend.Create(ASettings: TAiSettings);
begin
  inherited;
  FSse := TAiSseParser.Create;
  FSse.OnEvent := HandleEvent;
  FBlocks := TList.Create;
  FParts := TList.Create;
  FSigs := TList.Create;
end;

destructor TAiClaudeBackend.Destroy;
begin
  ResetStream;
  FBlocks.Free;
  FParts.Free;
  FSigs.Free;
  FSse.Free;
  inherited;
end;

class function TAiClaudeBackend.Id: string;
begin
  Result := 'Claude';
end;

class function TAiClaudeBackend.DisplayName: string;
begin
  Result := 'Claude (Anthropic API)';
end;

class procedure TAiClaudeBackend.ListModels(L: TStrings);
begin
  L.Add('claude-opus-5-5');
  L.Add('claude-sonnet-5-5');
  L.Add('claude-haiku-5-5');
  L.Add('claude-fable-5-2');
end;

class procedure TAiClaudeBackend.ListEfforts(L: TStrings);
begin
  L.Add('low');
  L.Add('medium');
  L.Add('high');
  L.Add('xhigh');
  L.Add('max');
end;

class procedure TAiClaudeBackend.ListReasoning(L: TStrings);
begin
  L.Add('summarized');
  L.Add('updates');
  L.Add('omitted');
end;

class function TAiClaudeBackend.DefaultModel: string;
begin
  Result := 'claude-opus-5-5';
end;

class function TAiClaudeBackend.DefaultEffort: string;
begin
  Result := 'medium';
end;

class function TAiClaudeBackend.DefaultReasoning: string;
begin
  Result := 'summarized';
end;

class function TAiClaudeBackend.DefaultMaxTokens: Integer;
begin
  Result := 64000;
end;

class function TAiClaudeBackend.DefaultBaseUrl: string;
begin
  Result := 'https://api.anthropic.com';
end;

class function TAiClaudeBackend.KeyVariable: string;
begin
  Result := 'ANTHROPIC_API_KEY';
end;

class function TAiClaudeBackend.DefaultProtocol: string;
begin
  Result := 'Messages API';
end;

class function TAiClaudeBackend.SupportsCompaction: Boolean;
begin
  Result := True;
end;

class function TAiClaudeBackend.DefaultCompactAt: Integer;
begin
  Result := 150000;
end;

{ the API's smallest trigger }
class function TAiClaudeBackend.MinCompactAt: Integer;
begin
  Result := 50000;
end;

{ what the Models API said about the model, else the unit's table (no request here) }
function TAiClaudeBackend.ModelCompacts: Boolean;
begin
  ModelInfo(False);
  Result := FCompaction;
end;

{ what the model of the settings offers: from the Models API when Ask (GET /v1/models/<id>, once
  per model), else - and when the API does not answer - from what this unit knows }
procedure TAiClaudeBackend.ModelInfo(Ask: Boolean);
var
  M: string;
  Headers: TStringList;
  J, V: TJson;
begin
  M := ModelName;
  if M <> FInfoModel then
  begin
    FInfoModel := M;
    FInfoAsked := False;
    FWindow := ClaudeContextWindow(M);
    FCompaction := ClaudeCompaction(M);
  end;
  if not Ask or FInfoAsked or (ApiKey = '') then Exit;
  Headers := TStringList.Create;
  try
    Headers.Add('x-api-key: ' + ApiKey);
    Headers.Add('anthropic-version: ' + AnthropicVersion);
    { an answer - the record, or a refusal that asking again would not change - is asked for once;
      no answer, again before the next request }
    J := GetJson(BaseUrl + '/v1/models/' + M, Headers, FInfoAsked);
  finally
    Headers.Free;
  end;
  if J = nil then Exit;
  FInfoAsked := True;
  try
    V := J.Get('max_input_tokens');
    if (V <> nil) and (V.AsInt64(0) > 0) then FWindow := V.AsInt64(0);
    V := J.Obj('capabilities');
    if V <> nil then V := V.Obj('context_management');
    if V <> nil then V := V.Obj('compact_20260112');
    if V <> nil then FCompaction := V.Bool('supported', FCompaction);
  finally
    J.Free;
  end;
end;

procedure TAiClaudeBackend.AskModelInfo;
begin
  ModelInfo(True);
end;

{ what Send learned of the model (no request here) }
function TAiClaudeBackend.ContextWindow: Int64;
begin
  ModelInfo(False);
  Result := FWindow;
end;

function TAiClaudeBackend.Ready(out Problem: string): Boolean;
begin
  Problem := '';
  if ApiKey = '' then
    Problem := 'There is no API key for Claude: enter one in the AI Assistant''s settings, or set the ' +
      'environment variable ANTHROPIC_API_KEY.';
  Result := Problem = '';
end;

function TAiClaudeBackend.EstimateCost(const Usage: TAiUsage): Double;
var
  M: string;
  InP, OutP, ReadP, WriteP: Double;
begin
  Result := -1;
  M := ModelName;
  if M = 'claude-opus-5-5' then begin InP := 4; OutP := 20; ReadP := 0.20; WriteP := 5; end
  else if M = 'claude-sonnet-5-5' then begin InP := 2; OutP := 10; ReadP := 0.10; WriteP := 2.5; end
  else if M = 'claude-fable-5-2' then begin InP := 8; OutP := 40; ReadP := 0.20; WriteP := 10; end
  else if M = 'claude-haiku-5-5' then begin InP := 0.10; OutP := 0.50; ReadP := 0.01; WriteP := 0.125; end
  else Exit;
  Result := UsageCost(Usage, InP, ReadP, WriteP, OutP);
end;

{ ---------------------------------------------------------------- the request }

{ the block is a compaction block of the API's (the backend Owner's) }
function IsCompaction(Blk: TAiBlock; const Owner: string): Boolean;
begin
  Result := (Blk <> nil) and (Blk.Native <> nil) and (Blk.NativeOwner = Owner) and
    (Blk.Native.Str('type') = 'compaction');
end;

function HasCompaction(Msg: TAiMessage; const Owner: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Msg.Count - 1 do
    if IsCompaction(Msg[I], Owner) then
    begin
      Result := True;
      Exit;
    end;
end;

{ a summary as a user message of its own }
function SummaryMessageJson(const Summary: string): string;
begin
  Result := '{"role":"user","content":[{"type":"text","text":' + JsonQuote(SummaryIntro + Summary) + '}]}';
end;

{ a message in the API's form (serialized once: a message never changes once sent). Compaction:
  the model takes compaction blocks; without, its summary is left out (BuildRequest sends it as
  a message of its own) and the form is not kept. }
function TAiClaudeBackend.MessageJson(Msg: TAiMessage; Compaction: Boolean): string;
var
  M, Content, B: TJson;
  J, LastFallback: Integer;
  Blk: TAiBlock;
  NativeType: string;
  Keep: Boolean;
begin
  if Compaction and (Msg.CacheOwner = Id) then
  begin
    Result := Msg.Cache;
    Exit;
  end;
  M := TJson.NewObject;
  try
    if Msg.Role = arUser then M.PutStr('role', 'user') else M.PutStr('role', 'assistant');
    Content := M.PutArray('content');
    LastFallback := -1;
    if Msg.Role = arAssistant then
      for J := 0 to Msg.Count - 1 do
        if (Msg[J].Native <> nil) and (Msg[J].NativeOwner = Id) and
          (Msg[J].Native.Str('type') = 'fallback') then LastFallback := J;
    for J := 0 to Msg.Count - 1 do
    begin
      Blk := Msg[J];
      if (Blk.Native <> nil) and (Blk.NativeOwner = Id) then
      begin
        NativeType := Blk.Native.Str('type');
        Keep := True;
        { before the last fallback block the declined attempt's reasoning and tool calls stay out:
          text, the fallback blocks and a summary go back }
        if J < LastFallback then
          Keep := (NativeType = 'text') or (NativeType = 'fallback') or (NativeType = 'compaction');
        { the API rejects an empty text block (a cut-off answer can end with one) }
        if (NativeType = 'text') and (Trim(Blk.Native.Str('text')) = '') then Keep := False;
        if (NativeType = 'compaction') and not Compaction then Keep := False;
        if Keep then Content.Add(Blk.Native.Clone);
      end
      else
        case Blk.Kind of
          abText:
            if Trim(Blk.Text) <> '' then
            begin
              B := Content.AddObject;
              B.PutStr('type', 'text');
              B.PutStr('text', Blk.Text);
            end;
          abToolCall:
            begin
              B := Content.AddObject;
              B.PutStr('type', 'tool_use');
              B.PutStr('id', Blk.Id);
              B.PutStr('name', Blk.Name);
              if Blk.Input <> nil then B.Put('input', Blk.Input.Clone) else B.PutObject('input');
            end;
          abToolResult:
            begin
              B := Content.AddObject;
              B.PutStr('type', 'tool_result');
              B.PutStr('tool_use_id', Blk.Id);
              if Blk.Text <> '' then B.PutStr('content', Blk.Text) else B.PutStr('content', '(no output)');
              if Blk.IsError then B.PutBool('is_error', True);
            end;
          abSummary:
            { another backend's: in a user message as text; an assistant message's goes as a
              message of its own (BuildRequest) }
            if (Msg.Role = arUser) and (Trim(Blk.Text) <> '') then
            begin
              B := Content.AddObject;
              B.PutStr('type', 'text');
              B.PutStr('text', SummaryIntro + Blk.Text);
            end;
        end;
    end;
    if Content.Count = 0 then
    begin
      B := Content.AddObject;
      B.PutStr('type', 'text');
      B.PutStr('text', '(empty)');
    end;
    Result := M.ToJson;
  finally
    M.Free;
  end;
  if Compaction then
  begin
    Msg.Cache := Result;
    Msg.CacheOwner := Id;
  end;
end;

{ the tool list in the API's form (the same for every request of a session) }
function TAiClaudeBackend.ToolsJson(Tools: TAiToolList): string;
var
  Arr, T: TJson;
  I: Integer;
begin
  if (Tools = FToolsFrom) and (Tools.Count = FToolsCount) and (FToolsJson <> '') then
  begin
    Result := FToolsJson;
    Exit;
  end;
  Arr := TJson.NewArray;
  try
    for I := 0 to Tools.Count - 1 do
    begin
      T := Tools[I].Schema;
      T.PutBool('eager_input_streaming', True);
      Arr.Add(T);
    end;
    Result := Arr.ToJson;
  finally
    Arr.Free;
  end;
  FToolsJson := Result;
  FToolsFrom := Tools;
  FToolsCount := Tools.Count;
end;

function TAiClaudeBackend.BuildRequest(Conversation: TAiConversation; const System: string;
  Tools: TAiToolList): string;
var
  Req, Arr, B, Th, Edit, Trig: TJson;
  I, First, Compact: Integer;
  Model, R, E: string;
  Compaction, Echoed: Boolean;
  Summary: TAiBlock;

  procedure AddBeta(const Name: string);
  begin
    if FBetas <> '' then FBetas := FBetas + ',';
    FBetas := FBetas + Name;
  end;

begin
  FBetas := '';
  Model := ModelName;
  Compaction := ModelCompacts;
  Req := TJson.NewObject;
  try
    Req.PutStr('model', Model);
    Req.PutInt('max_tokens', MaxTokens);
    Req.PutBool('stream', True);
    if System <> '' then
    begin
      Arr := Req.PutArray('system');
      B := Arr.AddObject;
      B.PutStr('type', 'text');
      B.PutStr('text', System);
      B.PutObject('cache_control').PutStr('type', 'ephemeral');
    end;
    if (Tools <> nil) and (Tools.Count > 0) then Req.Put('tools', TJson.NewRaw(ToolsJson(Tools)));
    { after a summary of the conversation: from the message that holds it - the API's own
      compaction block first; any other summary first as a user message of its own }
    Arr := Req.PutArray('messages');
    First := Conversation.LastSummary;
    if First < 0 then First := 0
    else
    begin
      Summary := Conversation[First].Summary;
      if (Conversation[First].Role = arAssistant) and not (Compaction and IsCompaction(Summary, Id)) then
        Arr.Add(TJson.NewRaw(SummaryMessageJson(Summary.Text)));
    end;
    Echoed := False;
    for I := First to Conversation.Count - 1 do
    begin
      Arr.Add(TJson.NewRaw(MessageJson(Conversation[I], Compaction)));
      if Compaction and not Echoed then Echoed := HasCompaction(Conversation[I], Id);
    end;
    if ClaudeServerFallback(Model) then AddBeta(FallbackBeta);
    if ClaudeAdaptiveThinking(Model) then
    begin
      Th := Req.PutObject('thinking');
      Th.PutStr('type', 'adaptive');
      R := Reasoning;
      if (R = 'updates') and not ClaudeUpdatesDisplay(Model) then R := 'summarized';
      if (R = 'summarized') or (R = 'updates') then Th.PutStr('display', R);
      if R = 'updates' then AddBeta(UpdatesBeta);
      E := Effort;
      if E <> '' then Req.PutObject('output_config').PutStr('effort', E);
    end;
    Req.PutObject('cache_control').PutStr('type', 'ephemeral');
    if ClaudeServerFallback(Model) then Req.PutStr('fallbacks', 'default');
    Compact := CompactAt;
    if (Compact > 0) or Echoed then AddBeta(CompactBeta);
    if Compact > 0 then
    begin
      Edit := Req.PutObject('context_management').PutArray('edits').AddObject;
      Edit.PutStr('type', 'compact_20260112');
      Trig := Edit.PutObject('trigger');
      Trig.PutStr('type', 'input_tokens');
      Trig.PutInt('value', Compact);
      Edit.PutStr('instructions', CompactionInstructions);
    end;
    Result := Req.ToJson;
  finally
    Req.Free;
  end;
end;

{ ---------------------------------------------------------------- the stream }

procedure TAiClaudeBackend.ResetStream;
begin
  inherited;
  ClearIndexed(FBlocks);
  ClearIndexed(FParts);
  ClearIndexed(FSigs);
  FSse.Reset;
  FModel := '';
  FStopReason := '';
  FStopDetail := '';
  FillChar(FUsage, SizeOf(FUsage), 0);
  FillChar(FCompacted, SizeOf(FCompacted), 0);
  FStarted := False;
end;

function TAiClaudeBackend.NativeBlock(Index: Integer): TJson;
begin
  Result := TJson(IndexedObject(FBlocks, Index));
end;

procedure TAiClaudeBackend.SetNativeBlock(Index: Integer; Block: TJson);
begin
  SetIndexedObject(FBlocks, Index, Block);
end;

{ the streamed parts of block Index into its JSON: text, thinking and signature, or the tool
  call's input (parsed; input that is not valid JSON is kept aside for the session) }
procedure TAiClaudeBackend.FinishBlock(Index: Integer);
var
  Blk, Parsed: TJson;
  Part, Sig: TKitStringBuilder;
  T, S: string;
begin
  Blk := NativeBlock(Index);
  Part := IndexedBuilder(FParts, Index, False);
  Sig := IndexedBuilder(FSigs, Index, False);
  if (Blk = nil) or ((Part = nil) and (Sig = nil)) then Exit;
  T := Blk.Str('type');
  if Part <> nil then
  begin
    S := Part.Text;
    if T = 'text' then Blk.PutStr('text', S)
    else if T = 'thinking' then Blk.PutStr('thinking', S)
    else if T = 'compaction' then
    begin
      if S <> '' then Blk.PutStr('content', S);   // else as it came (null: no summary)
    end
    else if T = 'tool_use' then
    begin
      if Trim(S) = '' then Blk.PutObject('input')
      else
      begin
        Parsed := TJson.TryParse(S);
        if (Parsed <> nil) and Parsed.IsObject then Blk.Put('input', Parsed)
        else
        begin
          Parsed.Free;
          Blk.PutObject('input');
          Blk.PutStr('x-harness-invalid-input', S);   // removed again by BuildMessage
        end;
      end;
    end;
  end;
  if Sig <> nil then Blk.PutStr('signature', Sig.Text);
  { finished: the builders go }
  Part.Free;
  Sig.Free;
  if Index < FParts.Count then FParts[Index] := nil;
  if Index < FSigs.Count then FSigs[Index] := nil;
end;

procedure TAiClaudeBackend.Feed(const Data: string);
begin
  FSse.Feed(Data);
end;

procedure TAiClaudeBackend.FinishStream;
begin
  FSse.Finish;
end;

{ the token counts of a usage object into Usage; a count it lacks stays as it is }
procedure TakeUsage(U: TJson; var Usage: TAiUsage);

  procedure Take(const Name: string; var Value: Int64);
  var
    V: TJson;
  begin
    V := U.Get(Name);
    if (V <> nil) and (V.Kind = jkNumber) then Value := V.AsInt64(Value);
  end;

begin
  Take('input_tokens', Usage.InputTokens);
  Take('output_tokens', Usage.OutputTokens);
  Take('cache_read_input_tokens', Usage.CacheReadTokens);
  Take('cache_creation_input_tokens', Usage.CacheWriteTokens);
end;

procedure TAiClaudeBackend.ReadUsage(U: TJson);
var
  It, E: TJson;
  One: TAiUsage;
  I: Integer;
begin
  if U = nil then Exit;
  TakeUsage(U, FUsage);
  { the top-level figures leave out a summarization of the context: usage.iterations has it }
  It := U.Arr('iterations');
  if It = nil then Exit;
  FillChar(FCompacted, SizeOf(FCompacted), 0);
  for I := 0 to It.Count - 1 do
  begin
    E := It.Item(I);
    if (E <> nil) and E.IsObject and (E.Str('type') = 'compaction') then
    begin
      FillChar(One, SizeOf(One), 0);
      TakeUsage(E, One);
      AddUsage(FCompacted, One);
    end;
  end;
end;

procedure TAiClaudeBackend.HandleEvent(const EventName, Data: string);
var
  J, M, CB, D, Blk, SD, Arr, Err: TJson;
  T, DT, BT, S: string;
  Index: Integer;
  Done: TAiBlock;
begin
  J := TJson.TryParse(Data);
  if J = nil then Exit;
  try
    T := J.Str('type');
    if T = 'message_start' then
    begin
      FStarted := True;
      M := J.Obj('message');
      if M <> nil then
      begin
        FModel := M.Str('model');
        ReadUsage(M.Obj('usage'));
      end;
    end
    else if T = 'content_block_start' then
    begin
      Index := J.Int('index', -1);
      CB := J.Obj('content_block');
      if (Index >= 0) and (CB <> nil) then
      begin
        FGotContent := True;
        SetNativeBlock(Index, CB.Clone);
        BT := CB.Str('type');
        { what streams into the block starts with what the start event holds }
        if BT = 'text' then IndexedBuilder(FParts, Index, True).Append(CB.Str('text'))
        else if BT = 'thinking' then
        begin
          IndexedBuilder(FParts, Index, True).Append(CB.Str('thinking'));
          IndexedBuilder(FSigs, Index, True).Append(CB.Str('signature'));
        end
        else if BT = 'tool_use' then IndexedBuilder(FParts, Index, True)
        else if BT = 'compaction' then IndexedBuilder(FParts, Index, True).Append(CB.Str('content'));
        if FEvents <> nil then
        begin
          FEvents.BlockStarted(Index, BlockKindOf(BT), CB.Str('name'));
          if (BT = 'text') and (CB.Str('text') <> '') then FEvents.Delta(Index, abText, CB.Str('text'));
          if BT = 'fallback' then
            FEvents.Status(Format('%s declined the request; %s continues.',
              [MemberModel(CB, 'from', 'The model'), MemberModel(CB, 'to', 'the fallback model')]));
        end;
      end;
    end
    else if T = 'content_block_delta' then
    begin
      Index := J.Int('index', -1);
      D := J.Obj('delta');
      Blk := NativeBlock(Index);
      if (D <> nil) and (Blk <> nil) then
      begin
        DT := D.Str('type');
        if (DT = 'text_delta') or (DT = 'thinking_delta') or (DT = 'input_json_delta') then
        begin
          if DT = 'text_delta' then S := D.Str('text')
          else if DT = 'thinking_delta' then S := D.Str('thinking')
          else S := D.Str('partial_json');
          IndexedBuilder(FParts, Index, True).Append(S);
          if FEvents <> nil then
          begin
            if DT = 'text_delta' then FEvents.Delta(Index, abText, S)
            else if DT = 'thinking_delta' then FEvents.Delta(Index, abReasoning, S)
            else FEvents.Delta(Index, abToolCall, S);
          end;
        end
        else if DT = 'signature_delta' then
          IndexedBuilder(FSigs, Index, True).Append(D.Str('signature'))
        else if DT = 'compaction_delta' then
          IndexedBuilder(FParts, Index, True).Append(D.Str('content'))
        else if DT = 'citations_delta' then
        begin
          Arr := Blk.Arr('citations');
          if Arr = nil then Arr := Blk.PutArray('citations');
          if D.Obj('citation') <> nil then Arr.Add(D.Obj('citation').Clone);
        end;
      end;
    end
    else if T = 'content_block_stop' then
    begin
      Index := J.Int('index', -1);
      FinishBlock(Index);
      Blk := NativeBlock(Index);
      if (FEvents <> nil) and (Blk <> nil) then
      begin
        Done := TAiBlock.Create(BlockKindOf(Blk.Str('type')));
        try
          Done.Name := Blk.Str('name');
          if Done.Kind = abSummary then Done.Text := Blk.Str('content');
          FEvents.BlockFinished(Index, Done);
        finally
          Done.Free;
        end;
      end;
    end
    else if T = 'message_delta' then
    begin
      D := J.Obj('delta');
      if D <> nil then
      begin
        if (D.Get('stop_reason') <> nil) and not D.Get('stop_reason').IsNull then
          FStopReason := D.Str('stop_reason');
        SD := D.Obj('stop_details');
        if SD <> nil then
        begin
          FStopDetail := SD.Str('category');
          if SD.Str('explanation') <> '' then
          begin
            if FStopDetail <> '' then FStopDetail := FStopDetail + ': ';
            FStopDetail := FStopDetail + SD.Str('explanation');
          end;
        end;
      end;
      ReadUsage(J.Obj('usage'));
    end
    else if T = 'message_stop' then
      FComplete := True
    else if T = 'error' then
    begin
      Err := J.Obj('error');
      if Err <> nil then
      begin
        FStreamErrorType := Err.Str('type', 'error');
        FStreamError := Err.Str('message', 'The stream reported an error.');
      end
      else
      begin
        FStreamErrorType := 'error';
        FStreamError := 'The stream reported an error.';
      end;
      FStreamErrorRetry := (FStreamErrorType = 'overloaded_error') or (FStreamErrorType = 'api_error') or
        (FStreamErrorType = 'rate_limit_error');
    end;
  finally
    J.Free;
  end;
end;

function TAiClaudeBackend.BuildMessage: TAiMessage;
var
  I, LastFallback: Integer;
  N, Input: TJson;
  B: TAiBlock;
  T, Bad: string;
begin
  { blocks the stream did not finish (cut off) get what they streamed }
  for I := 0 to FBlocks.Count - 1 do FinishBlock(I);
  Result := TAiMessage.Create(arAssistant);
  Result.Model := FModel;
  { the context after this answer: its prompt (as the API counted it, after any summary) and the
    answer; the cost: that and the summarization }
  Result.ContextTokens := FUsage.InputTokens + FUsage.CacheReadTokens + FUsage.CacheWriteTokens + FUsage.OutputTokens;
  Result.Usage := FUsage;
  AddUsage(Result.Usage, FCompacted);
  Result.StopReason := StopReasonOf(FStopReason);
  Result.StopDetail := FStopDetail;
  LastFallback := -1;
  for I := 0 to FBlocks.Count - 1 do
    if (FBlocks[I] <> nil) and (TJson(FBlocks[I]).Str('type') = 'fallback') then LastFallback := I;
  for I := 0 to FBlocks.Count - 1 do
  begin
    N := TJson(FBlocks[I]);
    if N = nil then Continue;
    FBlocks[I] := nil;
    T := N.Str('type');
    B := TAiBlock.Create(BlockKindOf(T));
    if T = 'text' then B.Text := N.Str('text')
    else if T = 'thinking' then B.Text := N.Str('thinking')
    else if T = 'tool_use' then
    begin
      B.Id := N.Str('id');
      B.Name := N.Str('name');
      Bad := N.Str('x-harness-invalid-input');
      N.Remove('x-harness-invalid-input');
      Input := N.Obj('input');
      if Bad <> '' then
      begin
        B.Input := nil;
        B.InputText := Bad;
      end
      else
      begin
        if Input <> nil then B.Input := Input.Clone else B.Input := TJson.NewObject;
        B.InputText := B.Input.ToJson;
      end;
      if I < LastFallback then
      begin
        { a call of the declined attempt: not run, not echoed }
        B.Kind := abOther;
        B.Text := 'tool call of the declined attempt';
      end;
    end
    else if T = 'fallback' then
      B.Text := Format('%s declined; %s continued', [MemberModel(N, 'from', '?'), MemberModel(N, 'to', '?')])
    else if T = 'compaction' then
      B.Text := N.Str('content')     // '' when no summary was written (content null)
    else if T <> 'redacted_thinking' then
      B.Text := T;
    B.Native := N;
    B.NativeOwner := Id;
    Result.Add(B);
  end;
end;

function TAiClaudeBackend.ParseStream(const Stream: string; Events: TAiBackendEvents): TAiMessage;
begin
  ResetStream;
  FEvents := Events;
  try
    Feed(Stream);
    FinishStream;
    Result := BuildMessage;
  finally
    FEvents := nil;
  end;
end;

{ ---------------------------------------------------------------- sending }

function TAiClaudeBackend.Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
  Events: TAiBackendEvents): TAiMessage;
var
  Body, Problem: string;
  Headers: TStringList;
begin
  if not Ready(Problem) then raise EAiBackendError.Create(Problem);
  ModelInfo(True);
  Body := BuildRequest(Conversation, System, Tools);
  Headers := TStringList.Create;
  try
    Headers.Add('x-api-key: ' + ApiKey);
    Headers.Add('anthropic-version: ' + AnthropicVersion);
    Headers.Add('content-type: application/json');
    Headers.Add('accept: text/event-stream');
    if FBetas <> '' then Headers.Add('anthropic-beta: ' + FBetas);
    Result := PostStream(BaseUrl + '/v1/messages', Headers, Body, Events);
  finally
    Headers.Free;
  end;
end;

initialization
  RegisterAiBackend(TAiClaudeBackend);
end.
