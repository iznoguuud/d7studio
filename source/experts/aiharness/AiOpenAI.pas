{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiOpenAI;

{ The backends of OpenAI's API and of the servers that speak it: TAiOpenAICompatible, the base
  class of every OpenAI-compatible provider, and TAiOpenAIBackend, OpenAI itself. AiCompat
  builds the other providers on the same class (OpenRouter, Ollama, LM Studio, a custom
  endpoint). There is no SDK for Delphi: the requests are built and the streams read here.

  Two wire protocols; a provider speaks one, or lets the settings choose (Protocol):
    * the Responses API (POST <base>/responses), OpenAI's own - its current models call tools
      only through it. Stateless: store false, every request carries the whole conversation as
      items, and the items of an answer - message (with its phase), reasoning (its summaries and
      encrypted content), function_call, compaction - are kept as they came and sent back
      unchanged, ids included (measured on 2026-11-22: accepted). Streamed as server-sent events
      with event lines and no [DONE]; the message is built from the output of the terminal event
      (response.completed / incomplete / failed), the deltas only show it while it comes;
    * Chat Completions (POST <base>/chat/completions), which most OpenAI-compatible servers
      offer. An assistant message is content plus tool_calls; reasoning arrives as
      reasoning_content, reasoning or reasoning_details, and a provider may send it back with
      its message (EchoReasoning). Streamed as data lines that end with [DONE]; the usage comes
      in a last chunk (stream_options.include_usage).
  Summaries of long chats - the core's context management:
    * a provider whose server compacts (OpenAI, Responses): context_management with
      compact_threshold = CompactAt. Once the input crosses it, the server summarizes it before
      it answers, and after the answer it summarizes the context again when that crossed it; each
      summary is a "compaction" item, encrypted, readable only by the provider (measured: the
      output [compaction, message, compaction]). Such an item is an abSummary block without text
      - the core's readable summaries are the other backends' to use - and is sent back as it
      came; the requests after it start with the last one, which the API's documentation allows
      ("drop items that came before the most recent compaction item"). The transcript reports
      it as a summary;
    * every other provider summarizes itself: once the prompt would reach CompactAt tokens (the
      last answer's context and what came after it), it first asks the model for a summary of
      the conversation (SummaryInstructions, no tool calls), then sends the summary - a user
      message of its own - in place of what it stands for. The summary is the readable abSummary
      block at the start of the answer, which every backend takes; CompactAt is kept within
      three quarters of the model's window when the window is known.
  The model's window and prices come from the provider's class (KnownModel), or from its
  server (AskWindow) - asked before a model's first request and again after its answers until
  the server says, as a local server knows a model's context only once it loaded it. }

interface

uses
  Windows, SysUtils, Classes, AiText, AiJson, AiCore, AiHttp, AiRemote;

const
  { the wire protocols, as the settings name them }
  ProtocolResponses = 'Responses';
  ProtocolChat = 'Chat Completions';

type
  TAiOpenAIProtocol = (opResponses, opChat);

  { what a provider knows of a model: its context window (the largest prompt in tokens; 0:
    unknown) and its prices in US dollars per million tokens (negative: unknown) }
  TAiModelInfo = record
    Window: Int64;
    InputPrice: Double;
    CachedPrice: Double;      // a cache read
    WritePrice: Double;       // a cache write
    OutputPrice: Double;
  end;

  TAiOpenAICompatible = class(TAiRemoteBackend)
  private
    FSse: TAiSseParser;
    FProto: TAiOpenAIProtocol;     // the protocol of the stream that is read
    FOwn: string;                  // ... and the owner of its native blocks (NativeId)
    FItems: TList;                 // Responses: the answer's items by output index; Chat: its blocks (TJson, owned; a text block's nil)
    FParts: TList;                 // TKitStringBuilder by index: what streamed into the item or block
    FKinds: TList;                 // Chat: the block's TAiBlockKind by index
    FToolMap: TList;               // Chat: a tool call's index in tool_calls -> its block's index + 1
    FFinal: TJson;                 // Responses: the output of the terminal event (owned)
    FTextBlock: Integer;           // Chat: the text block (-1: none yet)
    FReasonBlock: Integer;         // Chat: the reasoning block (-1: none yet)
    FOpenBlock: Integer;           // Chat: the block that streams now (-1: none)
    FModel: string;
    FStatus: string;               // Responses: the response's status; Chat: the finish_reason
    FDetail: string;               // Responses: incomplete_details.reason
    FRefusal: string;              // a refusal's text (UTF-8)
    FUsage: TAiUsage;
    FPromptTokens: Int64;          // the request's prompt, cache reads and writes included
    FOutputTokens: Int64;
    FToolsJson: string;            // the tool list as sent, for FToolsFrom with FToolsCount tools in FToolsProto
    FToolsFrom: TAiToolList;
    FToolsCount: Integer;
    FToolsProto: TAiOpenAIProtocol;
    FSummaryRequest: Boolean;      // the request asks for a summary of the conversation
    FPendingSummary: string;       // the request starts from this summary (UTF-8; '' none)
    FSummaryBlock: TAiBlock;       // the summary the answer starts with (owned until it is added)
    FSummaryUsage: TAiUsage;       // what the summary cost
    FInfoModel: string;            // the model FWindow describes
    FInfoAsked: Boolean;           // the server said what it knows of FInfoModel
    FWindow: Int64;
    FWarnedModel: string;          // the transcript was told that this model's context is small
    procedure Prepare;
    procedure HandleEvent(const EventName, Data: string);
    procedure RespEvent(J: TJson);
    procedure ChatEvent(J: TJson);
    procedure ChatError(Err: TJson);
    function Item(Index: Integer): TJson;
    procedure SetItem(Index: Integer; Value: TJson);
    function Part(Index: Integer; Make: Boolean): TKitStringBuilder;
    function PartText(Index: Integer): string;
    procedure StreamDelta(Index: Integer; Kind: TAiBlockKind; const Utf8: string);
    procedure ReportFinished(Index: Integer; Kind: TAiBlockKind; const Name: string);
    function ChatBlock(Kind: TAiBlockKind; Native: TJson; const Name: string): Integer;
    procedure FinishOpenBlock;
    procedure ChatReasoning(const Text: string; Details: TJson);
    procedure ChatText(const Text: string);
    procedure ChatToolCall(Call: TJson; Position: Integer);
    procedure ReadUsage(U: TJson; const InName, OutName, DetailsName: string);
    function NewAnswer: TAiMessage;
    procedure SetStop(Msg: TAiMessage; HasCall: Boolean);
    function RespMessage: TAiMessage;
    function ChatMessage: TAiMessage;
    procedure AddRespBlock(Msg: TAiMessage; Native: TJson; var HasCall: Boolean);
    procedure PatchItem(N: TJson; Index: Integer);
    function IsOwnCompaction(B: TAiBlock): Boolean;
    procedure FindStart(Conversation: TAiConversation; out First, FirstBlock: Integer; out Summary: string);
    function RespItems(Msg: TAiMessage; FromBlock: Integer): string;
    function ChatMessages(Msg: TAiMessage): string;
    function CachedForm(Msg: TAiMessage): string;
    function History(Conversation: TAiConversation; const System: string): string;
    function ToolsJson(Tools: TAiToolList): string;
    procedure AddTools(Req: TJson; Tools: TAiToolList);
    function RespRequest(Conversation: TAiConversation; const System: string; Tools: TAiToolList): string;
    function ChatRequest(Conversation: TAiConversation; const System: string; Tools: TAiToolList): string;
    function NeedsSummary(Conversation: TAiConversation): Boolean;
    function Summarize(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
      Events: TAiBackendEvents): TAiBlock;
    function Post(const Body: string; Events: TAiBackendEvents): TAiMessage;
    procedure ModelInfo(Ask: Boolean);
    procedure CheckWindow(Events: TAiBackendEvents);
  protected
    procedure ResetStream; override;
    procedure Feed(const Data: string); override;
    procedure FinishStream; override;
    function BuildMessage: TAiMessage; override;
    { what a provider's class says of the provider: }
    { the request's headers besides the content type: the key }
    procedure AddHeaders(Headers: TStrings); virtual;
    { the provider's server summarizes the conversation (Responses: context_management) }
    function ServerCompaction: Boolean; virtual;
    { Chat: the member that holds the output limit - max_completion_tokens, OpenAI's current name
      (a server that does not know it keeps its own limit) }
    function MaxTokensField: string; virtual;
    { Chat: the server takes tool_choice }
    function TakesToolChoice: Boolean; virtual;
    { Chat: adds what the provider's request takes besides the standard members }
    procedure AddChatOptions(Req: TJson); virtual;
    { Chat: puts an answer's reasoning - Native, its block's form: "reasoning" and the
      "reasoning_details" as they streamed - into the assistant message Msg that goes back; the
      base sends none }
    procedure EchoReasoning(Msg, Native: TJson); virtual;
    { what the provider knows of Model without asking }
    function KnownModel(const Model: string; out Info: TAiModelInfo): Boolean; virtual;
    { asks the server for Model's context window: the window; 0 when there was no answer yet
      (asked again after the next answer); negative when there is none to be had }
    function AskWindow(const Model: string): Int64; virtual;
    { for AskWindow: the server's JSON answer at Url, asked with the request's headers (the caller
      frees it); without one nil, and Window 0 (ask again) or -1 (it will not answer) }
    function AskServer(const Url: string; out Window: Int64): TJson;
    { what to do when the server gives the model too small a context ('': nothing to say) }
    function ContextAdvice: string; virtual;
  public
    constructor Create(ASettings: TAiSettings); override;
    destructor Destroy; override;
    class procedure ListEfforts(L: TStrings); override;
    class function DefaultEffort: string; override;
    class function DefaultMaxTokens: Integer; override;
    class function DefaultProtocol: string; override;
    class function SupportsCompaction: Boolean; override;
    class function DefaultCompactAt: Integer; override;
    class function MinCompactAt: Integer; override;
    function Ready(out Problem: string): Boolean; override;
    function ContextWindow: Int64; override;
    function CompactAt: Integer; override;
    function Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
      Events: TAiBackendEvents): TAiMessage; override;
    function EstimateCost(const Usage: TAiUsage): Double; override;
    { the protocol of the requests: the setting Protocol when the class lists protocols, else
      DefaultProtocol }
    function Protocol: TAiOpenAIProtocol; virtual;
    { the owner of this backend's native blocks: its id and its protocol }
    function NativeId: string;
    { the request's URL }
    function EndpointUrl: string;
    { the request body (UTF-8 JSON) - public for the tests }
    function BuildRequest(Conversation: TAiConversation; const System: string; Tools: TAiToolList): string;
    { a recorded stream read into a message (the tests) }
    function ParseStream(const Stream: string; Events: TAiBackendEvents): TAiMessage;
    { learns the model's window as Send does before a request (the tests) }
    procedure AskModelInfo;
  end;

  { OpenAI: the Responses API with its server compaction; the models and prices of OpenAI's
    pages on 2026-11-22 (the window is the largest prompt, 922,000 of 1,050,000 tokens) }
  TAiOpenAIBackend = class(TAiOpenAICompatible)
  protected
    function ServerCompaction: Boolean; override;
    function KnownModel(const Model: string; out Info: TAiModelInfo): Boolean; override;
  public
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
    class function DefaultCompactAt: Integer; override;
    class function MinCompactAt: Integer; override;
  end;

{ a server's root: Base without a trailing /v1 (Ollama's and LM Studio's own APIs lie there) }
function ServerRoot(const Base: string): string;
{ a model record of a provider's table }
function ModelInfoOf(Window: Int64; InputPrice, CachedPrice, WritePrice, OutputPrice: Double): TAiModelInfo;

implementation

const
  { what an encrypted summary is in the transcript's events }
  EncryptedNote = '(encrypted by the provider)';
  { the least context a server should give a model: the assistant's instructions and tools take
    some 10,000 tokens }
  MinUsefulWindow = 32768;

function ServerRoot(const Base: string): string;
begin
  Result := Base;
  while (Result <> '') and (Result[Length(Result)] = '/') do SetLength(Result, Length(Result) - 1);
  if SameText(Copy(Result, Length(Result) - 2, 3), '/v1') then SetLength(Result, Length(Result) - 3);
end;

function ModelInfoOf(Window: Int64; InputPrice, CachedPrice, WritePrice, OutputPrice: Double): TAiModelInfo;
begin
  Result.Window := Window;
  Result.InputPrice := InputPrice;
  Result.CachedPrice := CachedPrice;
  Result.WritePrice := WritePrice;
  Result.OutputPrice := OutputPrice;
end;

{ a setting's value that goes into the request: not empty, not 'default' }
function Chosen(const S: string): Boolean;
begin
  Result := (S <> '') and not SameText(S, 'default');
end;

function RespKind(const ItemType: string): TAiBlockKind;
begin
  if ItemType = 'message' then Result := abText
  else if ItemType = 'reasoning' then Result := abReasoning
  else if ItemType = 'function_call' then Result := abToolCall
  else if ItemType = 'compaction' then Result := abSummary
  else Result := abOther;
end;

{ the Field values of the objects of Arr, joined with Sep }
function JoinedTexts(Arr: TJson; const Field, Sep: string): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  if Arr = nil then Exit;
  for I := 0 to Arr.Count - 1 do
  begin
    S := Arr.Item(I).Str(Field);
    if S = '' then Continue;
    if Result <> '' then Result := Result + Sep;
    Result := Result + S;
  end;
end;

{ a tool call's input from the arguments the model sent: input that is not a JSON object is
  kept as text only, for the session's INVALID_JSON answer }
procedure SetCallInput(B: TAiBlock; const Args: string);
var
  P: TJson;
begin
  if Trim(Args) = '' then
  begin
    B.Input := TJson.NewObject;
    B.InputText := '{}';
    Exit;
  end;
  P := TJson.TryParse(Args);
  if (P <> nil) and P.IsObject then B.Input := P
  else
  begin
    P.Free;
    B.Input := nil;
  end;
  B.InputText := Args;
end;

{ a tool call's arguments as a JSON text: the input, else the text the model sent }
function CallArguments(B: TAiBlock): string;
begin
  if B.Input <> nil then Result := B.Input.ToJson
  else if Trim(B.InputText) <> '' then Result := B.InputText
  else Result := '{}';
end;

{ a user message of one text: the Responses API's item, Chat Completions' message }
function RespUserItem(const Utf8: string): string;
begin
  Result := '{"type":"message","role":"user","content":[{"type":"input_text","text":' + JsonQuote(Utf8) + '}]}';
end;

function ChatUserItem(const Utf8: string): string;
begin
  Result := '{"role":"user","content":' + JsonQuote(Utf8) + '}';
end;

{ Part - JSON text, '' none - appended to the comma-separated list in B; Any: B holds an item }
procedure AppendPart(B: TKitStringBuilder; var Any: Boolean; const Part: string);
begin
  if Part = '' then Exit;
  if Any then B.AppendChar(',');
  B.Append(Part);
  Any := True;
end;

{ a streamed piece of reasoning_details into List: a piece with the index of an item before
  continues it (its text, summary or data appended, its other members taken), any other is a new
  item }
procedure MergeDetail(List, D: TJson);
var
  I: Integer;
  E, Idx, Found: TJson;
  K: string;
begin
  Found := nil;
  Idx := D.Get('index');
  if (Idx <> nil) and not Idx.IsNull then
    for I := 0 to List.Count - 1 do
    begin
      E := List.Item(I);
      if (E.Get('index') <> nil) and (E.Get('index').AsString = Idx.AsString) and
        (E.Str('type') = D.Str('type')) then
      begin
        Found := E;
        Break;
      end;
    end;
  if Found = nil then
  begin
    List.Add(D.Clone);
    Exit;
  end;
  for I := 0 to D.Count - 1 do
  begin
    K := D.Name(I);
    if (K = 'text') or (K = 'summary') or (K = 'data') then
      Found.PutStr(K, Found.Str(K) + D.Item(I).AsString)
    else if not D.Item(I).IsNull then
      Found.Put(K, D.Item(I).Clone);
  end;
end;

{ ---------------------------------------------------------------- TAiOpenAICompatible }

constructor TAiOpenAICompatible.Create(ASettings: TAiSettings);
begin
  inherited;
  FSse := TAiSseParser.Create;
  FSse.OnEvent := HandleEvent;
  FItems := TList.Create;
  FParts := TList.Create;
  FKinds := TList.Create;
  FToolMap := TList.Create;
  FTextBlock := -1;
  FReasonBlock := -1;
  FOpenBlock := -1;
end;

destructor TAiOpenAICompatible.Destroy;
begin
  ResetStream;
  FSummaryBlock.Free;
  FItems.Free;
  FParts.Free;
  FKinds.Free;
  FToolMap.Free;
  FSse.Free;
  inherited;
end;

class procedure TAiOpenAICompatible.ListEfforts(L: TStrings);
begin
  L.Add('default');
  L.Add('none');
  L.Add('minimal');
  L.Add('low');
  L.Add('medium');
  L.Add('high');
  L.Add('xhigh');
  L.Add('max');
end;

class function TAiOpenAICompatible.DefaultEffort: string;
begin
  Result := 'default';
end;

class function TAiOpenAICompatible.DefaultMaxTokens: Integer;
begin
  Result := 32000;
end;

class function TAiOpenAICompatible.DefaultProtocol: string;
begin
  Result := ProtocolChat;
end;

class function TAiOpenAICompatible.SupportsCompaction: Boolean;
begin
  Result := True;
end;

class function TAiOpenAICompatible.DefaultCompactAt: Integer;
begin
  Result := 100000;
end;

class function TAiOpenAICompatible.MinCompactAt: Integer;
begin
  Result := 10000;
end;

procedure TAiOpenAICompatible.AddHeaders(Headers: TStrings);
begin
  if ApiKey <> '' then Headers.Add('Authorization: Bearer ' + ApiKey);
end;

function TAiOpenAICompatible.ServerCompaction: Boolean;
begin
  Result := False;
end;

function TAiOpenAICompatible.MaxTokensField: string;
begin
  Result := 'max_completion_tokens';
end;

function TAiOpenAICompatible.TakesToolChoice: Boolean;
begin
  Result := True;
end;

procedure TAiOpenAICompatible.AddChatOptions(Req: TJson);
begin
end;

procedure TAiOpenAICompatible.EchoReasoning(Msg, Native: TJson);
begin
end;

function TAiOpenAICompatible.KnownModel(const Model: string; out Info: TAiModelInfo): Boolean;
begin
  Info := ModelInfoOf(0, -1, -1, -1, -1);
  Result := False;
end;

function TAiOpenAICompatible.AskWindow(const Model: string): Int64;
begin
  Result := -1;
end;

function TAiOpenAICompatible.AskServer(const Url: string; out Window: Int64): TJson;
var
  Headers: TStringList;
  Final: Boolean;
begin
  Window := 0;
  Headers := TStringList.Create;
  try
    AddHeaders(Headers);
    Result := GetJson(Url, Headers, Final);
  finally
    Headers.Free;
  end;
  if (Result = nil) and Final then Window := -1;
end;

function TAiOpenAICompatible.ContextAdvice: string;
begin
  Result := '';
end;

function TAiOpenAICompatible.Protocol: TAiOpenAIProtocol;
var
  L: TStringList;
  S: string;
begin
  S := DefaultProtocol;
  L := TStringList.Create;
  try
    ListProtocols(L);
    if L.Count > 0 then S := Trim(Setting('Protocol', DefaultProtocol));
  finally
    L.Free;
  end;
  if SameText(S, ProtocolResponses) then Result := opResponses else Result := opChat;
end;

function TAiOpenAICompatible.NativeId: string;
begin
  if Protocol = opResponses then Result := Id + '/responses' else Result := Id + '/chat';
end;

{ the protocol and the owner of the native blocks, worked out once for a request or a stream:
  the request's helpers read FProto and FOwn (Protocol may read the settings, the registry) }
procedure TAiOpenAICompatible.Prepare;
begin
  FProto := Protocol;
  FOwn := NativeId;
end;

function TAiOpenAICompatible.EndpointUrl: string;
begin
  if Protocol = opResponses then Result := BaseUrl + '/responses' else Result := BaseUrl + '/chat/completions';
end;

function TAiOpenAICompatible.Ready(out Problem: string): Boolean;
begin
  Problem := '';
  if BaseUrl = '' then
    Problem := Format('There is no address for %s: enter its Base URL in the AI Assistant''s settings.', [DisplayName])
  else if ModelName = '' then
    Problem := Format('There is no model for %s: enter one in the AI Assistant''s settings.', [DisplayName])
  else if KeyRequired and (ApiKey = '') then
  begin
    Problem := Format('There is no API key for %s: enter one in the AI Assistant''s settings', [DisplayName]);
    if KeyVariable <> '' then Problem := Problem + ', or set the environment variable ' + KeyVariable;
    Problem := Problem + '.';
  end;
  Result := Problem = '';
end;

{ ---------------------------------------------------------------- the model }

procedure TAiOpenAICompatible.ModelInfo(Ask: Boolean);
var
  M: string;
  Info: TAiModelInfo;
  W: Int64;
begin
  M := ModelName;
  if M <> FInfoModel then
  begin
    FInfoModel := M;
    FInfoAsked := False;
    FWindow := 0;
    if KnownModel(M, Info) then FWindow := Info.Window;
  end;
  if not Ask or FInfoAsked or (M = '') then Exit;
  W := AskWindow(M);
  if W > 0 then
  begin
    FWindow := W;
    FInfoAsked := True;
  end
  else if W < 0 then FInfoAsked := True;
end;

procedure TAiOpenAICompatible.AskModelInfo;
begin
  ModelInfo(True);
end;

function TAiOpenAICompatible.ContextWindow: Int64;
begin
  ModelInfo(False);
  Result := FWindow;
end;

{ the setting, and with a summary of the backend's own at most three quarters of a known window:
  the summary's request must fit in it too }
function TAiOpenAICompatible.CompactAt: Integer;
var
  W: Int64;
begin
  Result := inherited CompactAt;
  if (Result > 0) and not ServerCompaction then
  begin
    W := ContextWindow;
    if (W > 0) and (Result > W * 3 div 4) then Result := W * 3 div 4;
  end;
end;

function TAiOpenAICompatible.EstimateCost(const Usage: TAiUsage): Double;
var
  Info: TAiModelInfo;
begin
  if KnownModel(ModelName, Info) and (Info.InputPrice >= 0) and (Info.OutputPrice >= 0) and
    (Info.CachedPrice >= 0) and (Info.WritePrice >= 0) then
    Result := UsageCost(Usage, Info.InputPrice, Info.CachedPrice, Info.WritePrice, Info.OutputPrice)
  else if Usage.Cost > 0 then
    Result := Usage.Cost
  else
    Result := -1;
end;

{ the transcript is told once per model when the server gives it too small a context, or the
  prompt filled it: what did not fit was lost }
procedure TAiOpenAICompatible.CheckWindow(Events: TAiBackendEvents);
var
  Advice: string;
begin
  if (Events = nil) or (FWindow <= 0) or (FWarnedModel = FInfoModel) then Exit;
  Advice := ContextAdvice;
  if Advice = '' then Exit;
  if (FWindow < MinUsefulWindow) or (FPromptTokens >= FWindow - 256) then
  begin
    FWarnedModel := FInfoModel;
    Events.Status(Format('The server gives %s a context of %d tokens, too little for the assistant''s ' +
      'instructions, tools and conversation: what does not fit is lost. %s', [FInfoModel, FWindow, Advice]));
  end;
end;

{ ---------------------------------------------------------------- the request }

function TAiOpenAICompatible.IsOwnCompaction(B: TAiBlock): Boolean;
begin
  Result := (B.Kind = abSummary) and (B.Native <> nil) and (B.NativeOwner = FOwn) and
    (B.Native.Str('type') = 'compaction');
end;

{ where the request's history starts: message First from its block FirstBlock - the provider's
  own last compaction item when it comes after the last readable summary -, else the message
  with the last readable summary, which goes first as a user message of its own (Summary) }
procedure TAiOpenAICompatible.FindStart(Conversation: TAiConversation; out First, FirstBlock: Integer;
  out Summary: string);
var
  L, I, J: Integer;
  M: TAiMessage;
begin
  First := 0;
  FirstBlock := 0;
  Summary := '';
  L := Conversation.LastSummary;
  if FProto = opResponses then
    for I := Conversation.Count - 1 downto 0 do
    begin
      if I < L then Break;
      M := Conversation[I];
      for J := M.Count - 1 downto 0 do
        if IsOwnCompaction(M[J]) then
        begin
          First := I;
          FirstBlock := J;
          Exit;
        end;
    end;
  if L >= 0 then
  begin
    First := L;
    Summary := Conversation[L].Summary.Text;
  end;
end;

{ a message's items in the Responses API's form from its block FromBlock, joined by commas ('':
  none). The tools' results come first: they answer the calls of the message before. The
  backend's own blocks go back as they came; another backend's text and tool calls are written
  anew, its reasoning and summaries are not this provider's to read. }
function TAiOpenAICompatible.RespItems(Msg: TAiMessage; FromBlock: Integer): string;
var
  B: TKitStringBuilder;
  Any: Boolean;
  J: Integer;
  Blk: TAiBlock;
  It, Content, P: TJson;
  S: string;
begin
  B := TKitStringBuilder.Create;
  try
    Any := False;
    if Msg.Role = arUser then
    begin
      for J := FromBlock to Msg.Count - 1 do
      begin
        Blk := Msg[J];
        if Blk.Kind <> abToolResult then Continue;
        It := TJson.NewObject;
        try
          It.PutStr('type', 'function_call_output');
          It.PutStr('call_id', Blk.Id);
          if Blk.Text <> '' then It.PutStr('output', Blk.Text) else It.PutStr('output', '(no output)');
          AppendPart(B, Any, It.ToJson);
        finally
          It.Free;
        end;
      end;
      It := TJson.NewObject;
      try
        It.PutStr('type', 'message');
        It.PutStr('role', 'user');
        Content := It.PutArray('content');
        for J := FromBlock to Msg.Count - 1 do
        begin
          Blk := Msg[J];
          if (Blk.Kind = abText) and (Trim(Blk.Text) <> '') then S := Blk.Text
          else if (Blk.Kind = abSummary) and (Trim(Blk.Text) <> '') then S := SummaryIntro + Blk.Text
          else Continue;
          P := Content.AddObject;
          P.PutStr('type', 'input_text');
          P.PutStr('text', S);
        end;
        if Content.Count > 0 then AppendPart(B, Any, It.ToJson);
      finally
        It.Free;
      end;
    end
    else
      for J := FromBlock to Msg.Count - 1 do
      begin
        Blk := Msg[J];
        if (Blk.Native <> nil) and (Blk.NativeOwner = FOwn) then
          AppendPart(B, Any, Blk.Native.ToJson)
        else if (Blk.Kind = abText) and (Trim(Blk.Text) <> '') then
        begin
          It := TJson.NewObject;
          try
            It.PutStr('type', 'message');
            It.PutStr('role', 'assistant');
            P := It.PutArray('content').AddObject;
            P.PutStr('type', 'output_text');
            P.PutStr('text', Blk.Text);
            AppendPart(B, Any, It.ToJson);
          finally
            It.Free;
          end;
        end
        else if Blk.Kind = abToolCall then
        begin
          It := TJson.NewObject;
          try
            It.PutStr('type', 'function_call');
            It.PutStr('call_id', Blk.Id);
            It.PutStr('name', Blk.Name);
            It.PutStr('arguments', CallArguments(Blk));
            AppendPart(B, Any, It.ToJson);
          finally
            It.Free;
          end;
        end;
      end;
    Result := B.Text;
  finally
    B.Free;
  end;
end;

{ a message in Chat Completions' form, joined by commas ('': none): a user message is its tools'
  results (one tool message each) and then its text; an assistant message is its text and its
  tool calls - the backend's own as they came -, and its reasoning when the provider takes it }
function TAiOpenAICompatible.ChatMessages(Msg: TAiMessage): string;
var
  B: TKitStringBuilder;
  Any, HasCalls: Boolean;
  J: Integer;
  Blk: TAiBlock;
  M, Calls, C, F, Reason: TJson;
  Text: string;

  procedure AddText(const S: string);
  begin
    if Trim(S) = '' then Exit;
    if Text <> '' then Text := Text + #10#10;
    Text := Text + S;
  end;

begin
  B := TKitStringBuilder.Create;
  try
    Any := False;
    Text := '';
    if Msg.Role = arUser then
    begin
      for J := 0 to Msg.Count - 1 do
      begin
        Blk := Msg[J];
        if Blk.Kind = abToolResult then
        begin
          M := TJson.NewObject;
          try
            M.PutStr('role', 'tool');
            M.PutStr('tool_call_id', Blk.Id);
            if Blk.Text <> '' then M.PutStr('content', Blk.Text) else M.PutStr('content', '(no output)');
            AppendPart(B, Any, M.ToJson);
          finally
            M.Free;
          end;
        end
        else if Blk.Kind = abText then AddText(Blk.Text)
        else if (Blk.Kind = abSummary) and (Trim(Blk.Text) <> '') then AddText(SummaryIntro + Blk.Text);
      end;
      if Text <> '' then AppendPart(B, Any, ChatUserItem(Text));
    end
    else
    begin
      Reason := nil;
      HasCalls := False;
      for J := 0 to Msg.Count - 1 do
      begin
        Blk := Msg[J];
        case Blk.Kind of
          abText: AddText(Blk.Text);
          abToolCall: HasCalls := True;
          abReasoning:
            if (Blk.Native <> nil) and (Blk.NativeOwner = FOwn) then Reason := Blk.Native;
        end;
      end;
      if (Text <> '') or HasCalls then
      begin
        M := TJson.NewObject;
        try
          M.PutStr('role', 'assistant');
          if Text <> '' then M.PutStr('content', Text) else M.PutNull('content');
          if HasCalls then
          begin
            Calls := M.PutArray('tool_calls');
            for J := 0 to Msg.Count - 1 do
            begin
              Blk := Msg[J];
              if Blk.Kind <> abToolCall then Continue;
              if (Blk.Native <> nil) and (Blk.NativeOwner = FOwn) then Calls.Add(Blk.Native.Clone)
              else
              begin
                C := Calls.AddObject;
                C.PutStr('id', Blk.Id);
                C.PutStr('type', 'function');
                F := C.PutObject('function');
                F.PutStr('name', Blk.Name);
                F.PutStr('arguments', CallArguments(Blk));
              end;
            end;
          end;
          if Reason <> nil then EchoReasoning(M, Reason);
          AppendPart(B, Any, M.ToJson);
        finally
          M.Free;
        end;
      end;
    end;
    Result := B.Text;
  finally
    B.Free;
  end;
end;

{ a whole message's form, serialized once: a message never changes once sent }
function TAiOpenAICompatible.CachedForm(Msg: TAiMessage): string;
begin
  if Msg.CacheOwner = FOwn then
  begin
    Result := Msg.Cache;
    Exit;
  end;
  if FProto = opResponses then Result := RespItems(Msg, 0) else Result := ChatMessages(Msg);
  Msg.Cache := Result;
  Msg.CacheOwner := FOwn;
end;

{ the history the request carries, as the protocol's array: Chat's system message first; then the
  conversation from where FindStart says - or the summary of the backend's own that this request
  starts from -; last the summary's instructions when the request asks for a summary }
function TAiOpenAICompatible.History(Conversation: TAiConversation; const System: string): string;
var
  B: TKitStringBuilder;
  Any: Boolean;
  First, FirstBlock, I: Integer;
  Summary: string;

  function UserItem(const Utf8: string): string;
  begin
    if FProto = opResponses then Result := RespUserItem(Utf8) else Result := ChatUserItem(Utf8);
  end;

begin
  B := TKitStringBuilder.Create;
  try
    Any := False;
    B.AppendChar('[');
    if (FProto = opChat) and (System <> '') then
      AppendPart(B, Any, '{"role":"system","content":' + JsonQuote(System) + '}');
    if FPendingSummary <> '' then
      AppendPart(B, Any, UserItem(SummaryIntro + FPendingSummary))
    else
    begin
      FindStart(Conversation, First, FirstBlock, Summary);
      if Summary <> '' then AppendPart(B, Any, UserItem(SummaryIntro + Summary));
      for I := First to Conversation.Count - 1 do
        if (I = First) and (FirstBlock > 0) then AppendPart(B, Any, RespItems(Conversation[I], FirstBlock))
        else AppendPart(B, Any, CachedForm(Conversation[I]));
      if FSummaryRequest then AppendPart(B, Any, UserItem(SummaryInstructions));
    end;
    B.AppendChar(']');
    Result := B.Text;
  finally
    B.Free;
  end;
end;

{ the tool list in the protocol's form (the same for every request of a session). Strict mode is
  off: the tools' schemas have optional members, which strict mode does not allow. }
function TAiOpenAICompatible.ToolsJson(Tools: TAiToolList): string;
var
  Arr, S, T, F: TJson;
  I: Integer;
  P: TAiOpenAIProtocol;
begin
  P := FProto;
  if (Tools = FToolsFrom) and (Tools.Count = FToolsCount) and (P = FToolsProto) and (FToolsJson <> '') then
  begin
    Result := FToolsJson;
    Exit;
  end;
  Arr := TJson.NewArray;
  try
    for I := 0 to Tools.Count - 1 do
    begin
      S := Tools[I].Schema;
      try
        T := Arr.AddObject;
        T.PutStr('type', 'function');
        if P = opResponses then F := T else F := T.PutObject('function');
        F.PutStr('name', S.Str('name'));
        F.PutStr('description', S.Str('description'));
        if S.Obj('input_schema') <> nil then F.Put('parameters', S.Obj('input_schema').Clone)
        else F.PutObject('parameters').PutStr('type', 'object');
        if P = opResponses then F.PutBool('strict', False);
      finally
        S.Free;
      end;
    end;
    Result := Arr.ToJson;
  finally
    Arr.Free;
  end;
  FToolsJson := Result;
  FToolsFrom := Tools;
  FToolsCount := Tools.Count;
  FToolsProto := P;
end;

{ the tools; a request for a summary calls none - tool_choice none, or no tools where the server
  takes no tool_choice }
procedure TAiOpenAICompatible.AddTools(Req: TJson; Tools: TAiToolList);
begin
  if (Tools = nil) or (Tools.Count = 0) or (FSummaryRequest and not TakesToolChoice) then Exit;
  Req.Put('tools', TJson.NewRaw(ToolsJson(Tools)));
  if FSummaryRequest then Req.PutStr('tool_choice', 'none');
end;

function TAiOpenAICompatible.RespRequest(Conversation: TAiConversation; const System: string;
  Tools: TAiToolList): string;
var
  Req, R, CM: TJson;
  Compact: Integer;
  E, RS: string;
begin
  Req := TJson.NewObject;
  try
    Req.PutStr('model', ModelName);
    if System <> '' then Req.PutStr('instructions', System);
    Req.Put('input', TJson.NewRaw(History(Conversation, System)));
    AddTools(Req, Tools);
    Req.PutInt('max_output_tokens', MaxTokens);
    E := Effort;
    RS := Reasoning;
    if SameText(RS, 'omitted') then RS := '';
    if Chosen(E) or Chosen(RS) then
    begin
      R := Req.PutObject('reasoning');
      if Chosen(E) then R.PutStr('effort', E);
      if Chosen(RS) then R.PutStr('summary', RS);
    end;
    Req.PutArray('include').AddString('reasoning.encrypted_content');
    Req.PutBool('store', False);
    Req.PutBool('stream', True);
    Compact := 0;
    if ServerCompaction then Compact := CompactAt;
    if Compact > 0 then
    begin
      CM := Req.PutArray('context_management').AddObject;
      CM.PutStr('type', 'compaction');
      CM.PutInt('compact_threshold', Compact);
    end;
    Result := Req.ToJson;
  finally
    Req.Free;
  end;
end;

function TAiOpenAICompatible.ChatRequest(Conversation: TAiConversation; const System: string;
  Tools: TAiToolList): string;
var
  Req: TJson;
  E: string;
begin
  Req := TJson.NewObject;
  try
    Req.PutStr('model', ModelName);
    Req.Put('messages', TJson.NewRaw(History(Conversation, System)));
    AddTools(Req, Tools);
    Req.PutBool('stream', True);
    Req.PutObject('stream_options').PutBool('include_usage', True);
    Req.PutInt(MaxTokensField, MaxTokens);
    E := Effort;
    if Chosen(E) then Req.PutStr('reasoning_effort', E);
    AddChatOptions(Req);
    Result := Req.ToJson;
  finally
    Req.Free;
  end;
end;

function TAiOpenAICompatible.BuildRequest(Conversation: TAiConversation; const System: string;
  Tools: TAiToolList): string;
begin
  Prepare;
  if FProto = opResponses then Result := RespRequest(Conversation, System, Tools)
  else Result := ChatRequest(Conversation, System, Tools);
end;

{ ---------------------------------------------------------------- summaries of the backend's own }

{ the next prompt would reach CompactAt tokens: the context of the last answer since the start of
  the history, and what came after it (some 3 bytes of UTF-8 a token) }
function TAiOpenAICompatible.NeedsSummary(Conversation: TAiConversation): Boolean;
var
  Limit, First, FirstBlock, I, J, Last: Integer;
  Summary: string;
  Est: Int64;
  M: TAiMessage;
begin
  Result := False;
  Limit := CompactAt;
  if Limit <= 0 then Exit;
  FindStart(Conversation, First, FirstBlock, Summary);
  Last := -1;
  for I := Conversation.Count - 1 downto First do
    if (Conversation[I].Role = arAssistant) and (Conversation[I].ContextTokens > 0) then
    begin
      Last := I;
      Break;
    end;
  if Last < 0 then Exit;     // no answer since the start: nothing to summarize
  Est := Conversation[Last].ContextTokens;
  for I := Last + 1 to Conversation.Count - 1 do
  begin
    M := Conversation[I];
    for J := 0 to M.Count - 1 do Inc(Est, (Length(M[J].Text) + Length(M[J].InputText)) div 3);
  end;
  Result := Est >= Limit;
end;

{ asks the model for a summary of the conversation (no tool calls); the summary block, nil when
  none could be written. The transcript sees it begin and end as a summary block. }
function TAiOpenAICompatible.Summarize(Conversation: TAiConversation; const System: string;
  Tools: TAiToolList; Events: TAiBackendEvents): TAiBlock;
var
  M: TAiMessage;
  Text: string;
begin
  if Events <> nil then Events.BlockStarted(0, abSummary, '');
  Text := '';
  FSummaryRequest := True;
  try
    try
      M := Post(BuildRequest(Conversation, System, Tools), nil);
      try
        Text := Trim(SummaryOfAnswer(M.Text));
        FSummaryUsage := M.Usage;
      finally
        M.Free;
      end;
    except
      on EAiCancelled do raise;
      on E: Exception do
        if Events <> nil then Events.Status('The conversation could not be summarized: ' + IdeToUtf8(E.Message));
    end;
  finally
    FSummaryRequest := False;
  end;
  Result := TAiBlock.Create(abSummary);
  Result.Text := Text;
  if Events <> nil then Events.BlockFinished(0, Result);
  if Text = '' then FreeAndNil(Result);
end;

{ ---------------------------------------------------------------- sending }

{ Body (BuildRequest's: it prepared FProto and FOwn, which the stream is read with) POSTed }
function TAiOpenAICompatible.Post(const Body: string; Events: TAiBackendEvents): TAiMessage;
var
  Headers: TStringList;
begin
  Headers := TStringList.Create;
  try
    AddHeaders(Headers);
    Headers.Add('content-type: application/json');
    Headers.Add('accept: text/event-stream');
    Result := PostStream(EndpointUrl, Headers, Body, Events);
  finally
    Headers.Free;
  end;
end;

function TAiOpenAICompatible.Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
  Events: TAiBackendEvents): TAiMessage;
var
  Problem: string;
begin
  if not Ready(Problem) then raise EAiBackendError.Create(Problem);
  Prepare;
  ModelInfo(True);
  FillChar(FSummaryUsage, SizeOf(FSummaryUsage), 0);
  FreeAndNil(FSummaryBlock);
  FPendingSummary := '';
  try
    if not ServerCompaction and NeedsSummary(Conversation) then
    begin
      FSummaryBlock := Summarize(Conversation, System, Tools, Events);
      if FSummaryBlock <> nil then FPendingSummary := FSummaryBlock.Text;
    end;
    Result := Post(BuildRequest(Conversation, System, Tools), Events);
  finally
    FPendingSummary := '';
    FreeAndNil(FSummaryBlock);    // the answer took it when it came
  end;
  { a server that loads the model with the request knows its context now }
  ModelInfo(True);
  CheckWindow(Events);
end;

{ ---------------------------------------------------------------- the stream }

procedure TAiOpenAICompatible.ResetStream;
begin
  inherited;
  ClearIndexed(FItems);
  ClearIndexed(FParts);
  FKinds.Clear;
  FToolMap.Clear;
  FreeAndNil(FFinal);
  FSse.Reset;
  FTextBlock := -1;
  FReasonBlock := -1;
  FOpenBlock := -1;
  FModel := '';
  FStatus := '';
  FDetail := '';
  FRefusal := '';
  FillChar(FUsage, SizeOf(FUsage), 0);
  FPromptTokens := 0;
  FOutputTokens := 0;
end;

procedure TAiOpenAICompatible.Feed(const Data: string);
begin
  FSse.Feed(Data);
end;

procedure TAiOpenAICompatible.FinishStream;
begin
  FSse.Finish;
  if FProto = opChat then FinishOpenBlock;
end;

procedure TAiOpenAICompatible.HandleEvent(const EventName, Data: string);
var
  J: TJson;
begin
  if (FProto = opChat) and (Trim(Data) = '[DONE]') then
  begin
    FinishOpenBlock;
    FComplete := True;
    Exit;
  end;
  J := TJson.TryParse(Data);
  if J = nil then Exit;
  try
    if J.IsObject then
      if FProto = opResponses then RespEvent(J) else ChatEvent(J);
  finally
    J.Free;
  end;
end;

function TAiOpenAICompatible.Item(Index: Integer): TJson;
begin
  Result := TJson(IndexedObject(FItems, Index));
end;

procedure TAiOpenAICompatible.SetItem(Index: Integer; Value: TJson);
begin
  SetIndexedObject(FItems, Index, Value);
end;

function TAiOpenAICompatible.Part(Index: Integer; Make: Boolean): TKitStringBuilder;
begin
  Result := IndexedBuilder(FParts, Index, Make);
end;

function TAiOpenAICompatible.PartText(Index: Integer): string;
var
  P: TKitStringBuilder;
begin
  P := Part(Index, False);
  if P = nil then Result := '' else Result := P.Text;
end;

procedure TAiOpenAICompatible.StreamDelta(Index: Integer; Kind: TAiBlockKind; const Utf8: string);
begin
  if (Index < 0) or (Utf8 = '') then Exit;
  Part(Index, True).Append(Utf8);
  if FEvents <> nil then FEvents.Delta(Index, Kind, Utf8);
end;

{ the end of block Index reported; a summary - the provider's encrypted compaction item - with a
  note for its text, as the transcript takes a summary without text for none }
procedure TAiOpenAICompatible.ReportFinished(Index: Integer; Kind: TAiBlockKind; const Name: string);
var
  Done: TAiBlock;
begin
  if FEvents = nil then Exit;
  Done := TAiBlock.Create(Kind);
  try
    Done.Name := Name;
    if Kind = abSummary then Done.Text := EncryptedNote;
    FEvents.BlockFinished(Index, Done);
  finally
    Done.Free;
  end;
end;

{ the token counts of a usage object: the prompt (InName, cache reads and writes included in it,
  in DetailsName), the answer (OutName), and what the provider charged ("cost") }
procedure TAiOpenAICompatible.ReadUsage(U: TJson; const InName, OutName, DetailsName: string);
var
  D: TJson;
  Cached, Written: Int64;
begin
  if (U = nil) or not U.IsObject then Exit;
  FPromptTokens := JsonInt64(U, InName);
  FOutputTokens := JsonInt64(U, OutName);
  D := U.Obj(DetailsName);
  Cached := JsonInt64(D, 'cached_tokens');
  Written := JsonInt64(D, 'cache_write_tokens');
  if Cached = 0 then Cached := JsonInt64(U, 'prompt_cache_hit_tokens');    // DeepSeek's name
  FUsage.CacheReadTokens := Cached;
  FUsage.CacheWriteTokens := Written;
  FUsage.InputTokens := FPromptTokens - Cached - Written;
  if FUsage.InputTokens < 0 then FUsage.InputTokens := 0;
  FUsage.OutputTokens := FOutputTokens;
  FUsage.Cost := JsonDouble(U.Get('cost'));
end;

{ Responses: the events of the stream (measured on 2026-11-22: response.created, in_progress,
  output_item.added / done, content_part.added / done, output_text.delta / done,
  reasoning_summary_part.added / done, reasoning_summary_text.delta / done,
  function_call_arguments.delta / done, completed; each with output_index) }
procedure TAiOpenAICompatible.RespEvent(J: TJson);
var
  T, Code: string;
  Index: Integer;
  It, R, D: TJson;
begin
  T := J.Str('type');
  Index := J.Int('output_index', -1);
  if (T = 'response.created') or (T = 'response.in_progress') then
  begin
    R := J.Obj('response');
    if (R <> nil) and (R.Str('model') <> '') then FModel := R.Str('model');
  end
  else if T = 'response.output_item.added' then
  begin
    It := J.Obj('item');
    if (Index >= 0) and (It <> nil) then
    begin
      FGotContent := True;
      SetItem(Index, It.Clone);
      if FEvents <> nil then FEvents.BlockStarted(Index, RespKind(It.Str('type')), It.Str('name'));
    end;
  end
  else if (T = 'response.output_text.delta') or (T = 'response.refusal.delta') then
    StreamDelta(Index, abText, J.Str('delta'))
  else if (T = 'response.reasoning_summary_text.delta') or (T = 'response.reasoning_text.delta') then
    StreamDelta(Index, abReasoning, J.Str('delta'))
  else if T = 'response.reasoning_summary_part.added' then
  begin
    if J.Int('summary_index', 0) > 0 then StreamDelta(Index, abReasoning, #10#10);
  end
  else if T = 'response.function_call_arguments.delta' then
    StreamDelta(Index, abToolCall, J.Str('delta'))
  else if T = 'response.output_item.done' then
  begin
    It := J.Obj('item');
    if (Index >= 0) and (It <> nil) then
    begin
      SetItem(Index, It.Clone);
      ReportFinished(Index, RespKind(It.Str('type')), It.Str('name'));
    end;
  end
  else if (T = 'response.completed') or (T = 'response.incomplete') or (T = 'response.failed') then
  begin
    R := J.Obj('response');
    if R <> nil then
    begin
      FStatus := R.Str('status');
      if R.Str('model') <> '' then FModel := R.Str('model');
      D := R.Obj('incomplete_details');
      if D <> nil then FDetail := D.Str('reason');
      ReadUsage(R.Obj('usage'), 'input_tokens', 'output_tokens', 'input_tokens_details');
      if R.Arr('output') <> nil then
      begin
        FreeAndNil(FFinal);
        FFinal := R.Arr('output').Clone;
      end;
      if T = 'response.failed' then
      begin
        D := R.Obj('error');
        Code := '';
        if D <> nil then Code := D.Str('code');
        if Code = '' then Code := 'failed';
        FStreamErrorType := Code;
        if D <> nil then FStreamError := D.Str('message');
        if FStreamError = '' then FStreamError := 'The response failed.';
        FStreamErrorRetry := (Code = 'server_error') or (Code = 'rate_limit_exceeded');
      end;
    end;
    FComplete := True;
  end
  else if T = 'error' then
  begin
    D := J.Obj('error');
    if D = nil then D := J;
    Code := D.Str('code');
    if Code = '' then Code := D.Str('type');
    if (Code = '') or (Code = 'error') then Code := 'error';
    FStreamErrorType := Code;
    FStreamError := D.Str('message', 'The stream reported an error.');
    FStreamErrorRetry := (Code = 'server_error') or (Code = 'rate_limit_exceeded') or
      (Code = 'server_is_overloaded');
  end;
end;

{ Chat: an error in the stream - OpenRouter sends one as a chunk with an "error" member }
procedure TAiOpenAICompatible.ChatError(Err: TJson);
var
  M, C: TJson;
  Code: string;
begin
  Code := '';
  if Err.IsObject then
  begin
    FStreamError := Err.Str('message');
    M := Err.Obj('metadata');
    if M <> nil then Code := M.Str('error_type');
    if Code = '' then Code := Err.Str('type');
    C := Err.Get('code');
    if (Code = '') and (C <> nil) and not C.IsNull then Code := C.AsString;
  end
  else FStreamError := Err.AsString;
  if FStreamError = '' then FStreamError := 'The stream reported an error.';
  if Code = '' then Code := 'error';
  FStreamErrorType := Code;
  FStreamErrorRetry := (Code = 'provider_overloaded') or (Code = 'provider_unavailable') or (Code = 'timeout') or
    (Code = 'server') or (Code = 'rate_limit_exceeded') or (Code = '429') or (Code = '500') or (Code = '502') or
    (Code = '503') or (Code = '504') or (Code = '529');
end;

{ Chat: a chunk - its choice's delta (reasoning, content, refusal, tool calls), its finish_reason,
  the usage of the last one }
procedure TAiOpenAICompatible.ChatEvent(J: TJson);
var
  Err, U, Arr, Ch, D, Det, Calls, FR: TJson;
  S: string;
  I: Integer;
begin
  Err := J.Get('error');
  if (Err <> nil) and not Err.IsNull then
  begin
    ChatError(Err);
    Exit;
  end;
  if J.Str('model') <> '' then FModel := J.Str('model');
  U := J.Get('usage');
  if (U <> nil) and U.IsObject then ReadUsage(U, 'prompt_tokens', 'completion_tokens', 'prompt_tokens_details');
  Arr := J.Arr('choices');
  if (Arr = nil) or (Arr.Count = 0) or not Arr.Item(0).IsObject then Exit;
  Ch := Arr.Item(0);
  D := Ch.Obj('delta');
  if D = nil then D := Ch.Obj('message');     // a server that answers in one piece
  if D <> nil then
  begin
    S := D.Str('reasoning_content');
    if S = '' then S := D.Str('reasoning');
    Det := D.Arr('reasoning_details');
    if (S <> '') or ((Det <> nil) and (Det.Count > 0)) then ChatReasoning(S, Det);
    S := D.Str('content');
    if S <> '' then ChatText(S);
    S := D.Str('refusal');
    if S <> '' then
    begin
      FRefusal := FRefusal + S;
      ChatText(S);
    end;
    Calls := D.Arr('tool_calls');
    if Calls <> nil then
      for I := 0 to Calls.Count - 1 do ChatToolCall(Calls.Item(I), I);
  end;
  FR := Ch.Get('finish_reason');
  if (FR <> nil) and FR.IsString and (FR.AsString <> '') then
  begin
    FStatus := FR.AsString;
    if FStatus <> 'error' then
    begin
      FinishOpenBlock;
      FComplete := True;
    end;
  end;
end;

{ Chat: a new block of the answer (the one before it ends); Native its form (nil: a text block) }
function TAiOpenAICompatible.ChatBlock(Kind: TAiBlockKind; Native: TJson; const Name: string): Integer;
begin
  FinishOpenBlock;
  Result := FItems.Count;
  FItems.Add(Native);
  while FParts.Count <= Result do FParts.Add(nil);
  FKinds.Add(Pointer(Ord(Kind)));
  FOpenBlock := Result;
  FGotContent := True;
  if FEvents <> nil then FEvents.BlockStarted(Result, Kind, Name);
end;

procedure TAiOpenAICompatible.FinishOpenBlock;
var
  N: TJson;
  Index: Integer;
  Name: string;
begin
  Index := FOpenBlock;
  if (Index < 0) or (Index >= FKinds.Count) then Exit;
  FOpenBlock := -1;
  N := Item(Index);
  Name := '';
  if (N <> nil) and (N.Obj('function') <> nil) then Name := N.Obj('function').Str('name');
  ReportFinished(Index, TAiBlockKind(Integer(FKinds[Index])), Name);
end;

procedure TAiOpenAICompatible.ChatReasoning(const Text: string; Details: TJson);
var
  N, List, D: TJson;
  I: Integer;
  Shown, T: string;
begin
  if FReasonBlock < 0 then FReasonBlock := ChatBlock(abReasoning, TJson.NewObject, '');
  N := Item(FReasonBlock);
  Shown := Text;
  if (Details <> nil) and (Details.Count > 0) then
  begin
    List := N.Arr('reasoning_details');
    if List = nil then List := N.PutArray('reasoning_details');
    for I := 0 to Details.Count - 1 do
    begin
      D := Details.Item(I);
      if not D.IsObject then Continue;
      MergeDetail(List, D);
      if Text = '' then
      begin
        T := D.Str('text');
        if T = '' then T := D.Str('summary');
        Shown := Shown + T;
      end;
    end;
  end;
  if Shown <> '' then
  begin
    Part(FReasonBlock, True).Append(Shown);
    if FEvents <> nil then FEvents.Delta(FReasonBlock, abReasoning, Shown);
  end;
end;

procedure TAiOpenAICompatible.ChatText(const Text: string);
begin
  if FTextBlock < 0 then FTextBlock := ChatBlock(abText, nil, '');
  Part(FTextBlock, True).Append(Text);
  if FEvents <> nil then FEvents.Delta(FTextBlock, abText, Text);
end;

{ Chat: a piece of a tool call - the first with its id and name, then its arguments in pieces
  (or whole, as some servers send them; an object is taken as its JSON) }
procedure TAiOpenAICompatible.ChatToolCall(Call: TJson; Position: Integer);
var
  TI, Blk: Integer;
  N, F, A: TJson;
  Name, Frag: string;
begin
  if not Call.IsObject then Exit;
  TI := Call.Int('index', Position);
  Blk := -1;
  if (TI >= 0) and (TI < FToolMap.Count) then Blk := Integer(FToolMap[TI]) - 1;
  { a piece with another id is a new call, whatever its index: a server that sends whole calls in
    chunks of their own may number each 0 }
  if (Blk >= 0) and (Call.Str('id') <> '') and (Item(Blk).Str('id') <> '') and
    (Call.Str('id') <> Item(Blk).Str('id')) then Blk := -1;
  F := Call.Obj('function');
  if Blk < 0 then
  begin
    Name := '';
    if F <> nil then Name := F.Str('name');
    N := TJson.NewObject;
    N.PutStr('id', Call.Str('id'));
    N.PutStr('type', 'function');
    N.PutObject('function').PutStr('name', Name);
    Blk := ChatBlock(abToolCall, N, Name);
    if TI >= 0 then
    begin
      while FToolMap.Count <= TI do FToolMap.Add(nil);
      FToolMap[TI] := Pointer(Blk + 1);
    end;
  end
  else
  begin
    N := Item(Blk);
    if Call.Str('id') <> '' then N.PutStr('id', Call.Str('id'));
    if (F <> nil) and (F.Str('name') <> '') and (N.Obj('function').Str('name') = '') then
      N.Obj('function').PutStr('name', F.Str('name'));
  end;
  if F = nil then Exit;
  A := F.Get('arguments');
  Frag := '';
  if A <> nil then
    if A.IsString then Frag := A.AsString
    else if A.IsObject then Frag := A.ToJson;
  if Frag <> '' then
  begin
    Part(Blk, True).Append(Frag);
    if FEvents <> nil then FEvents.Delta(Blk, abToolCall, Frag);
  end;
end;

{ the answer's message: its model, cost and context, and a summary of the backend's own first }
function TAiOpenAICompatible.NewAnswer: TAiMessage;
begin
  Result := TAiMessage.Create(arAssistant);
  Result.Model := FModel;
  Result.Usage := FUsage;
  AddUsage(Result.Usage, FSummaryUsage);
  Result.ContextTokens := FPromptTokens + FOutputTokens;
  if FSummaryBlock <> nil then
  begin
    Result.Add(FSummaryBlock);
    FSummaryBlock := nil;
  end;
end;

function TAiOpenAICompatible.BuildMessage: TAiMessage;
begin
  if FProto = opResponses then Result := RespMessage else Result := ChatMessage;
end;

{ Responses: what streamed into an item that did not end (a stream without a terminal output) }
procedure TAiOpenAICompatible.PatchItem(N: TJson; Index: Integer);
var
  S, T: string;
  Arr, P: TJson;
begin
  S := PartText(Index);
  if S = '' then Exit;
  T := N.Str('type');
  if (T = 'message') and ((N.Arr('content') = nil) or (N.Arr('content').Count = 0)) then
  begin
    P := N.PutArray('content').AddObject;
    P.PutStr('type', 'output_text');
    P.PutStr('text', S);
  end
  else if (T = 'function_call') and (N.Str('arguments') = '') then
    N.PutStr('arguments', S)
  else if (T = 'reasoning') and ((N.Arr('summary') = nil) or (N.Arr('summary').Count = 0)) then
  begin
    Arr := N.PutArray('summary');
    P := Arr.AddObject;
    P.PutStr('type', 'summary_text');
    P.PutStr('text', S);
  end;
end;

procedure TAiOpenAICompatible.AddRespBlock(Msg: TAiMessage; Native: TJson; var HasCall: Boolean);
var
  B: TAiBlock;
  T, S: string;
  Arr, P: TJson;
  I: Integer;
begin
  T := Native.Str('type');
  B := TAiBlock.Create(RespKind(T));
  if T = 'message' then
  begin
    S := '';
    Arr := Native.Arr('content');
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        P := Arr.Item(I);
        if P.Str('type') = 'output_text' then S := S + P.Str('text')
        else if P.Str('type') = 'refusal' then
        begin
          S := S + P.Str('refusal');
          FRefusal := FRefusal + P.Str('refusal');
        end;
      end;
    B.Text := S;
  end
  else if T = 'reasoning' then
  begin
    B.Text := JoinedTexts(Native.Arr('summary'), 'text', #10#10);
    if B.Text = '' then B.Text := JoinedTexts(Native.Arr('content'), 'text', '');
  end
  else if T = 'function_call' then
  begin
    B.Id := Native.Str('call_id');
    B.Name := Native.Str('name');
    SetCallInput(B, Native.Str('arguments'));
    HasCall := True;
  end
  else if T <> 'compaction' then
    B.Text := T;          // a compaction item's summary is encrypted: no text
  B.Native := Native;
  B.NativeOwner := FOwn;
  Msg.Add(B);
end;

function TAiOpenAICompatible.RespMessage: TAiMessage;
var
  I: Integer;
  HasCall: Boolean;
  N: TJson;
begin
  Result := NewAnswer;
  HasCall := False;
  if FFinal <> nil then
  begin
    for I := 0 to FFinal.Count - 1 do
      if FFinal.Item(I).IsObject then AddRespBlock(Result, FFinal.Item(I).Clone, HasCall);
  end
  else
    for I := 0 to FItems.Count - 1 do
    begin
      N := Item(I);
      if N = nil then Continue;
      FItems[I] := nil;
      PatchItem(N, I);
      AddRespBlock(Result, N, HasCall);
    end;
  SetStop(Result, HasCall);
end;

{ the answer's stop reason from the stream's end - Responses: the status and, for an incomplete
  answer, incomplete_details.reason; Chat: the finish_reason: cut at the output limit; declined (a
  filter, a refusal); tool calls (not those of an incomplete answer); the end of the turn }
procedure TAiOpenAICompatible.SetStop(Msg: TAiMessage; HasCall: Boolean);
var
  S: string;
  Incomplete: Boolean;
begin
  Incomplete := (FProto = opResponses) and (FStatus = 'incomplete');
  if Incomplete then S := FDetail
  else if (FStatus = '') or (FStatus = 'completed') then S := 'stop'
  else S := FStatus;
  if (S = 'max_output_tokens') or (S = 'length') then Msg.StopReason := asMaxTokens
  else if S = 'content_filter' then
  begin
    Msg.StopReason := asRefusal;
    Msg.StopDetail := S;
  end
  else if FRefusal <> '' then
  begin
    Msg.StopReason := asRefusal;
    Msg.StopDetail := TruncateUtf8(FRefusal, 300);
  end
  else if HasCall and not Incomplete then Msg.StopReason := asToolUse
  else if (S = 'stop') and not Incomplete then Msg.StopReason := asEndTurn
  else
  begin
    Msg.StopReason := asOther;
    Msg.StopDetail := S;
  end;
end;

function TAiOpenAICompatible.ChatMessage: TAiMessage;
var
  I: Integer;
  K: TAiBlockKind;
  B: TAiBlock;
  N, F: TJson;
  S: string;
  HasCall: Boolean;
begin
  Result := NewAnswer;
  HasCall := False;
  for I := 0 to FKinds.Count - 1 do
  begin
    K := TAiBlockKind(Integer(FKinds[I]));
    S := PartText(I);
    N := Item(I);
    FItems[I] := nil;
    B := TAiBlock.Create(K);
    if K = abToolCall then
    begin
      F := N.Obj('function');
      if N.Str('id') = '' then N.PutStr('id', Format('call_%x_%d', [GetTickCount, I]));
      F.PutStr('arguments', S);
      B.Id := N.Str('id');
      B.Name := F.Str('name');
      SetCallInput(B, S);
      HasCall := True;
    end
    else
    begin
      B.Text := S;
      if (K = abReasoning) and (N <> nil) and (S <> '') then N.PutStr('reasoning', S);
    end;
    if N <> nil then
    begin
      B.Native := N;
      B.NativeOwner := FOwn;
    end;
    Result.Add(B);
  end;
  SetStop(Result, HasCall);
end;

function TAiOpenAICompatible.ParseStream(const Stream: string; Events: TAiBackendEvents): TAiMessage;
begin
  Prepare;
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

{ ---------------------------------------------------------------- TAiOpenAIBackend }

class function TAiOpenAIBackend.Id: string;
begin
  Result := 'OpenAI';
end;

class function TAiOpenAIBackend.DisplayName: string;
begin
  Result := 'OpenAI';
end;

class procedure TAiOpenAIBackend.ListModels(L: TStrings);
begin
  L.Add('gpt-6.2-sol');
  L.Add('gpt-6.2-astra');
  L.Add('gpt-6.1-terra');
  L.Add('gpt-6-luna');
end;

{ gpt-6.2-astra and -sol refuse 'none' }
class procedure TAiOpenAIBackend.ListEfforts(L: TStrings);
begin
  L.Add('low');
  L.Add('medium');
  L.Add('high');
  L.Add('xhigh');
  L.Add('max');
end;

{ reasoning.summary; 'omitted' asks for none }
class procedure TAiOpenAIBackend.ListReasoning(L: TStrings);
begin
  L.Add('auto');
  L.Add('concise');
  L.Add('detailed');
  L.Add('omitted');
end;

class function TAiOpenAIBackend.DefaultModel: string;
begin
  Result := 'gpt-6.2-sol';
end;

class function TAiOpenAIBackend.DefaultEffort: string;
begin
  Result := 'medium';
end;

class function TAiOpenAIBackend.DefaultReasoning: string;
begin
  Result := 'auto';
end;

class function TAiOpenAIBackend.DefaultMaxTokens: Integer;
begin
  Result := 64000;
end;

class function TAiOpenAIBackend.DefaultBaseUrl: string;
begin
  Result := 'https://api.openai.com/v1';
end;

class function TAiOpenAIBackend.KeyVariable: string;
begin
  Result := 'OPENAI_API_KEY';
end;

class function TAiOpenAIBackend.DefaultProtocol: string;
begin
  Result := ProtocolResponses;
end;

{ below 272,000 input tokens, where OpenAI's prices double for the whole request }
class function TAiOpenAIBackend.DefaultCompactAt: Integer;
begin
  Result := 200000;
end;

{ the API's smallest compact_threshold }
class function TAiOpenAIBackend.MinCompactAt: Integer;
begin
  Result := 1000;
end;

function TAiOpenAIBackend.ServerCompaction: Boolean;
begin
  Result := True;
end;

{ the short-context prices (prompts up to 272,000 tokens), cache writes at the 30-minute rate }
function TAiOpenAIBackend.KnownModel(const Model: string; out Info: TAiModelInfo): Boolean;
begin
  Result := True;
  if Model = 'gpt-6.2-astra' then Info := ModelInfoOf(922000, 8, 0.40, 10, 40)
  else if Model = 'gpt-6.2-sol' then Info := ModelInfoOf(922000, 2, 0.10, 2.50, 10)
  else if Model = 'gpt-6.1-terra' then Info := ModelInfoOf(922000, 1, 0.05, 1.25, 5)
  else if Model = 'gpt-6-luna' then Info := ModelInfoOf(922000, 0.10, 0.01, 0.125, 0.50)
  else Result := inherited KnownModel(Model, Info);
end;

initialization
  RegisterAiBackend(TAiOpenAIBackend);
end.
