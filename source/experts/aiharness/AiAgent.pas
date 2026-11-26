{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiAgent;

{ The harness's agent loop (TAiSession). A turn runs in a worker thread:
    1. the backend sends the conversation and streams the assistant's message back;
    2. the tool calls of the message are run - each one validated against its schema, a change
       first previewed and approved (TAiApprover, in the main thread), the IDE's tools executed
       in the main thread (TThread.Synchronize);
    3. the results go back as the next user message, and the loop repeats until the model ends
       its turn, the user stops it, or MaxRounds tool rounds have run.
  The conversation is only ever appended to: a message once sent is never changed, so the
  model's reasoning blocks stay valid and the prompt cache keeps its prefix. A refused, failed
  or cancelled response is not added; the conversation then ends with the user's message, and
  Retry sends it again (the next Send adds its text to that message).
  What happens is reported to OnEvent in the main thread: the worker queues TAiEvent objects
  and posts one message to a hidden window, which hands the queue to OnEvent; the deltas of a
  block that waited together are handed over as one. }

interface

uses
  Windows, Messages, SysUtils, Classes, SyncObjs, AiText, AiJson, AiCore, AiHttp;

type
  TAiEventKind = (aeTurnStarted, aeBlockStarted, aeDelta, aeBlockFinished, aeToolStarted,
    aeToolFinished, aeStatus, aeUsage, aeTurnFinished, aeError);

  TAiTurnResult = (atrNone, atrDone, atrError, atrCancelled, atrRefused, atrLimit);

  TAiEvent = class
  public
    Kind: TAiEventKind;
    BlockKind: TAiBlockKind;
    Index: Integer;
    Text: string;            // UTF-8
    Detail: string;          // UTF-8; aeBlockFinished of an abSummary block: the summary
    IsError: Boolean;        // aeBlockFinished of an abSummary block: no summary was written
    Usage: TAiUsage;
    ContextTokens: Int64;    // aeUsage: how full the context window is now
    ContextWindow: Int64;    // aeUsage: the window's size (0: unknown)
    CompactAt: Integer;      // aeUsage: the prompt's size that sets a summary off (0: never)
    CanCompact: Boolean;     // aeUsage: the model can summarize the conversation
    StopReason: TAiStopReason;
    TurnResult: TAiTurnResult;
  end;

  TAiEventHandler = procedure(Sender: TObject; Event: TAiEvent) of object;

  TAiApproval = (aaAllow, aaAllowAll, aaDeny);

  { asks the user to allow a change (main thread) }
  TAiApprover = class
  public
    { Reason: what the user wants the model to know when they deny it (UTF-8) }
    function Approve(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval; virtual; abstract;
  end;

  TAiSession = class
  private
    FBackend: TAiBackend;
    FTools: TAiToolList;
    FSystem: string;
    FConversation: TAiConversation;
    FThread: TThread;
    FWnd: HWND;
    FLock: TCriticalSection;
    FQueue: TList;
    FPosted: Boolean;
    FCancelled: Boolean;
    FOnEvent: TAiEventHandler;
    FApprover: TAiApprover;
    FAllowAll: Boolean;
    FMaxRounds: Integer;
    FTotal: TAiUsage;
    FContextTokens: Int64;
    FContextWindow: Int64;
    FCompactAt: Integer;
    FCanCompact: Boolean;
    FLastResult: TAiTurnResult;
    FDestroying: Boolean;
    { the tool call that runs in the main thread }
    FCurTool: TAiTool;
    FCurInput: TJson;
    FCurResult: TAiToolResult;
    FCurApproved: Boolean;
    FCurContext: TAiToolContext;
    procedure WndProc(var Msg: TMessage);
    procedure Post(Event: TAiEvent);
    procedure PostSimple(Kind: TAiEventKind; const Text, Detail: string; IsError: Boolean);
    procedure HandOver(E: TAiEvent);
    procedure StartThread;
    procedure JoinThread;
    procedure RunTurn(Thread: TThread);
    procedure RunTool(Thread: TThread; Context: TAiToolContext; Call: TAiBlock; Res: TAiToolResult);
    procedure DoApprove;
    procedure DoExecute;
  public
    { the session owns ABackend and ATools }
    constructor Create(ABackend: TAiBackend; ATools: TAiToolList; const ASystem: string);
    destructor Destroy; override;
    { adds the user's text (UTF-8) - after Context, the IDE's state, when it is not empty - and
      starts a turn }
    procedure Send(const UserText, Context: string);
    { sends the conversation again after a turn that failed, was stopped or hit MaxRounds }
    procedure Retry;
    function CanRetry: Boolean;
    procedure Cancel;
    function Busy: Boolean;
    { a new, empty conversation (not while busy) }
    procedure Clear;
    { another backend for the next turns (not while busy; the session owns it) }
    procedure SetBackend(ABackend: TAiBackend);
    { hands the queued events to OnEvent now (main thread) }
    procedure DrainEvents;
    property Conversation: TAiConversation read FConversation;
    property Backend: TAiBackend read FBackend;
    property Tools: TAiToolList read FTools;
    property System: string read FSystem;
    property OnEvent: TAiEventHandler read FOnEvent write FOnEvent;
    property Approver: TAiApprover read FApprover write FApprover;
    { the user allowed every change of this conversation }
    property AllowAll: Boolean read FAllowAll write FAllowAll;
    property MaxRounds: Integer read FMaxRounds write FMaxRounds;
    property TotalUsage: TAiUsage read FTotal;
    { how full the model's context window is after the last answer, and its size (0: unknown) }
    property ContextTokens: Int64 read FContextTokens;
    property ContextWindow: Int64 read FContextWindow;
    { as of the last answer: the prompt's size that sets a summary of the conversation off (0:
      never), and whether the model can summarize it }
    property CompactAt: Integer read FCompactAt;
    property CanCompact: Boolean read FCanCompact;
    property LastResult: TAiTurnResult read FLastResult;
  end;

implementation

const
  WM_AI_EVENTS = WM_APP + $3A1;

type
  TAiTurnThread = class(TThread)
  private
    FSession: TAiSession;
  protected
    procedure Execute; override;
  public
    constructor Create(ASession: TAiSession);
    procedure RunSync(Method: TThreadMethod);
  end;

  TAiSessionContext = class(TAiToolContext)
  private
    FSession: TAiSession;
    FThread: TAiTurnThread;
    FMethod: TThreadMethod;
    FSkipped: Boolean;
    procedure RunMethod;
  public
    constructor Create(ASession: TAiSession; AThread: TAiTurnThread);
    procedure RunInMainThread(Method: TThreadMethod); override;
    function Cancelled: Boolean; override;
    procedure Status(const Utf8: string); override;
  end;

  TAiSessionEvents = class(TAiBackendEvents)
  private
    FSession: TAiSession;
  public
    constructor Create(ASession: TAiSession);
    procedure BlockStarted(Index: Integer; Kind: TAiBlockKind; const Name: string); override;
    procedure Delta(Index: Integer; Kind: TAiBlockKind; const Utf8: string); override;
    procedure BlockFinished(Index: Integer; Block: TAiBlock); override;
    procedure Status(const Utf8: string); override;
  end;

{ ---------------------------------------------------------------- TAiTurnThread }

constructor TAiTurnThread.Create(ASession: TAiSession);
begin
  FSession := ASession;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TAiTurnThread.Execute;
begin
  FSession.RunTurn(Self);
end;

procedure TAiTurnThread.RunSync(Method: TThreadMethod);
begin
  Synchronize(Method);
end;

{ ---------------------------------------------------------------- TAiSessionContext }

constructor TAiSessionContext.Create(ASession: TAiSession; AThread: TAiTurnThread);
begin
  inherited Create;
  FSession := ASession;
  FThread := AThread;
end;

{ not once the session is stopped (or ends with the IDE): checked before the call and again in
  the main thread, where a pending call also runs while the session waits for its thread }
procedure TAiSessionContext.RunInMainThread(Method: TThreadMethod);
begin
  if FSession.FCancelled then raise EAiCancelled.Create('Cancelled.');
  FMethod := Method;
  FSkipped := False;
  if GetCurrentThreadId = MainThreadID then RunMethod else FThread.RunSync(RunMethod);
  if FSkipped then raise EAiCancelled.Create('Cancelled.');
end;

procedure TAiSessionContext.RunMethod;
begin
  if FSession.FCancelled then FSkipped := True else FMethod;
end;

function TAiSessionContext.Cancelled: Boolean;
begin
  Result := FSession.FCancelled;
end;

procedure TAiSessionContext.Status(const Utf8: string);
begin
  FSession.PostSimple(aeStatus, Utf8, '', False);
end;

{ ---------------------------------------------------------------- TAiSessionEvents }

constructor TAiSessionEvents.Create(ASession: TAiSession);
begin
  inherited Create;
  FSession := ASession;
end;

function BlockEvent(Kind: TAiEventKind; Index: Integer; BlockKind: TAiBlockKind; const Text: string): TAiEvent;
begin
  Result := TAiEvent.Create;
  Result.Kind := Kind;
  Result.BlockKind := BlockKind;
  Result.Index := Index;
  Result.Text := Text;
end;

procedure TAiSessionEvents.BlockStarted(Index: Integer; Kind: TAiBlockKind; const Name: string);
begin
  FSession.Post(BlockEvent(aeBlockStarted, Index, Kind, Name));
end;

procedure TAiSessionEvents.Delta(Index: Integer; Kind: TAiBlockKind; const Utf8: string);
begin
  if Utf8 <> '' then FSession.Post(BlockEvent(aeDelta, Index, Kind, Utf8));
end;

procedure TAiSessionEvents.BlockFinished(Index: Integer; Block: TAiBlock);
var
  E: TAiEvent;
begin
  E := BlockEvent(aeBlockFinished, Index, Block.Kind, Block.Name);
  if Block.Kind = abSummary then
  begin
    E.Detail := Block.Text;
    E.IsError := Block.Text = '';
  end;
  FSession.Post(E);
end;

procedure TAiSessionEvents.Status(const Utf8: string);
begin
  FSession.PostSimple(aeStatus, Utf8, '', False);
end;

{ ---------------------------------------------------------------- TAiSession }

constructor TAiSession.Create(ABackend: TAiBackend; ATools: TAiToolList; const ASystem: string);
begin
  inherited Create;
  FBackend := ABackend;
  FTools := ATools;
  if FTools = nil then FTools := TAiToolList.Create;
  FSystem := ASystem;
  FConversation := TAiConversation.Create;
  FLock := TCriticalSection.Create;
  FQueue := TList.Create;
  FMaxRounds := 60;
  FWnd := Classes.AllocateHWnd(WndProc);
end;

destructor TAiSession.Destroy;
var
  I: Integer;
begin
  FDestroying := True;
  FOnEvent := nil;
  Cancel;
  if FThread <> nil then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  if FWnd <> 0 then Classes.DeallocateHWnd(FWnd);
  for I := 0 to FQueue.Count - 1 do TObject(FQueue[I]).Free;
  FQueue.Free;
  FLock.Free;
  FConversation.Free;
  FTools.Free;
  FBackend.Free;
  inherited;
end;

procedure TAiSession.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_AI_EVENTS then DrainEvents
  else Msg.Result := DefWindowProc(FWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TAiSession.Post(Event: TAiEvent);
var
  Wake: Boolean;
begin
  FLock.Enter;
  try
    FQueue.Add(Event);
    Wake := not FPosted;
    FPosted := True;
  finally
    FLock.Leave;
  end;
  if Wake and (FWnd <> 0) then PostMessage(FWnd, WM_AI_EVENTS, 0, 0);
end;

procedure TAiSession.PostSimple(Kind: TAiEventKind; const Text, Detail: string; IsError: Boolean);
var
  E: TAiEvent;
begin
  E := TAiEvent.Create;
  E.Kind := Kind;
  E.Text := Text;
  E.Detail := Detail;
  E.IsError := IsError;
  Post(E);
end;

{ an event handed to OnEvent, after the session's own bookkeeping }
procedure TAiSession.HandOver(E: TAiEvent);
begin
  case E.Kind of
    aeUsage:
      begin
        AddUsage(FTotal, E.Usage);
        FContextTokens := E.ContextTokens;
        FContextWindow := E.ContextWindow;
        FCompactAt := E.CompactAt;
        FCanCompact := E.CanCompact;
      end;
    aeTurnFinished:
      begin
        FLastResult := E.TurnResult;
        JoinThread;
      end;
  end;
  if Assigned(FOnEvent) and not FDestroying then
    try
      FOnEvent(Self, E);
    except
      { a failing handler must not lose the events after it; the IDE reports it }
      if Assigned(Classes.ApplicationHandleException) then Classes.ApplicationHandleException(Self);
    end;
end;

procedure TAiSession.DrainEvents;
var
  L: TList;
  I, J, K: Integer;
  E: TAiEvent;
  B: TKitStringBuilder;
begin
  L := TList.Create;
  B := TKitStringBuilder.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FQueue.Count - 1 do L.Add(FQueue[I]);
      FQueue.Clear;
      FPosted := False;
    finally
      FLock.Leave;
    end;
    I := 0;
    while I < L.Count do
    begin
      { each event leaves the list before it is handed over: the list frees only the rest }
      E := TAiEvent(L[I]);
      L[I] := nil;
      J := I + 1;
      if E.Kind = aeDelta then
      begin
        { the deltas of one block that follow each other become one }
        while (J < L.Count) and (TAiEvent(L[J]).Kind = aeDelta) and (TAiEvent(L[J]).Index = E.Index) and
          (TAiEvent(L[J]).BlockKind = E.BlockKind) do Inc(J);
        if J > I + 1 then
        begin
          B.Clear;
          B.Append(E.Text);
          for K := I + 1 to J - 1 do
          begin
            B.Append(TAiEvent(L[K]).Text);
            TAiEvent(L[K]).Free;
            L[K] := nil;
          end;
          E.Text := B.Text;
        end;
      end;
      I := J;
      try
        HandOver(E);
      finally
        E.Free;
      end;
    end;
  finally
    for I := 0 to L.Count - 1 do TObject(L[I]).Free;
    L.Free;
    B.Free;
  end;
end;

procedure TAiSession.JoinThread;
begin
  if FThread = nil then Exit;
  FThread.WaitFor;
  FreeAndNil(FThread);
end;

function TAiSession.Busy: Boolean;
begin
  Result := FThread <> nil;
end;

procedure TAiSession.StartThread;
begin
  FCancelled := False;
  FBackend.ResetCancel;
  FLastResult := atrNone;
  FThread := TAiTurnThread.Create(Self);
end;

procedure TAiSession.Send(const UserText, Context: string);
var
  Msg: TAiMessage;
begin
  if Busy then raise Exception.Create('The assistant is still working on the last message.');
  Msg := FConversation.Last;
  if (Msg = nil) or (Msg.Role <> arUser) then
  begin
    Msg := TAiMessage.Create(arUser);
    FConversation.Add(Msg);
  end;
  if Context <> '' then Msg.AddText(Context);
  Msg.AddText(UserText);
  StartThread;
end;

function TAiSession.CanRetry: Boolean;
begin
  Result := not Busy and (FConversation.Last <> nil) and (FConversation.Last.Role = arUser);
end;

procedure TAiSession.Retry;
begin
  if not CanRetry then Exit;
  StartThread;
end;

procedure TAiSession.Cancel;
begin
  FCancelled := True;
  if FBackend <> nil then FBackend.Cancel;
end;

procedure TAiSession.Clear;
begin
  if Busy then raise Exception.Create('The assistant is still working.');
  FConversation.Clear;
  FAllowAll := False;
  FLastResult := atrNone;
  FillChar(FTotal, SizeOf(FTotal), 0);
  FContextTokens := 0;
end;

procedure TAiSession.SetBackend(ABackend: TAiBackend);
begin
  if Busy then raise Exception.Create('The assistant is still working.');
  if ABackend = FBackend then Exit;
  FBackend.Free;
  FBackend := ABackend;
end;

{ the turn, in the worker thread }
procedure TAiSession.RunTurn(Thread: TThread);
var
  Msg, Results: TAiMessage;
  Calls: TList;
  Rounds, I: Integer;
  Res: TAiToolResult;
  Events: TAiSessionEvents;
  Context: TAiSessionContext;
  Outcome: TAiTurnResult;
  E: TAiEvent;
begin
  Outcome := atrError;
  Events := TAiSessionEvents.Create(Self);
  Context := TAiSessionContext.Create(Self, TAiTurnThread(Thread));
  Calls := TList.Create;
  try
    try
      PostSimple(aeTurnStarted, FBackend.ModelName, '', False);
      Rounds := 0;
      repeat
        if FCancelled then raise EAiCancelled.Create('Cancelled.');
        Msg := FBackend.Send(FConversation, FSystem, FTools, Events);
        E := TAiEvent.Create;
        E.Kind := aeUsage;
        E.Usage := Msg.Usage;
        E.ContextTokens := Msg.ContextTokens;
        E.ContextWindow := FBackend.ContextWindow;
        E.CompactAt := FBackend.CompactAt;
        E.CanCompact := FBackend.ModelCompacts;
        E.Text := Msg.Model;
        E.StopReason := Msg.StopReason;
        Post(E);
        if Msg.StopReason = asRefusal then
        begin
          if Msg.StopDetail <> '' then
            PostSimple(aeError, 'The model declined to answer (' + Msg.StopDetail + ').', '', True)
          else
            PostSimple(aeError, 'The model declined to answer.', '', True);
          Msg.Free;
          Outcome := atrRefused;
          Exit;
        end;
        FConversation.Add(Msg);
        if Msg.StopReason = asPauseTurn then
        begin
          { the server paused its own tool loop: send again (a round, so that it ends) }
          Inc(Rounds);
          if Rounds >= FMaxRounds then
          begin
            Outcome := atrLimit;
            Exit;
          end;
          Continue;
        end;
        Calls.Clear;
        for I := 0 to Msg.Count - 1 do
          if Msg[I].Kind = abToolCall then Calls.Add(Msg[I]);
        if Calls.Count = 0 then
        begin
          if Msg.StopReason = asMaxTokens then
            PostSimple(aeStatus, 'The answer reached the output token limit (max_tokens).', '', True);
          Outcome := atrDone;
          Exit;
        end;
        Results := TAiMessage.Create(arUser);
        try
          for I := 0 to Calls.Count - 1 do
          begin
            Res := TAiToolResult.Create;
            try
              if FCancelled then Res.Fail('Not run: the user stopped the assistant.')
              else if Msg.StopReason = asMaxTokens then
                Res.Fail('Not run: the response reached the output token limit (max_tokens) before ' +
                  'this tool call was complete. Repeat the call; split large content into smaller edits.')
              else
                RunTool(Thread, Context, TAiBlock(Calls[I]), Res);
              Results.AddToolResult(TAiBlock(Calls[I]).Id, Res.Text, Res.IsError);
            finally
              Res.Free;
            end;
          end;
        except
          Results.Free;
          raise;
        end;
        FConversation.Add(Results);
        if FCancelled then raise EAiCancelled.Create('Cancelled.');
        Inc(Rounds);
        if Rounds >= FMaxRounds then
        begin
          PostSimple(aeStatus, Format('Paused after %d tool rounds: press Continue to let the assistant go on.',
            [Rounds]), '', True);
          Outcome := atrLimit;
          Exit;
        end;
      until False;
    except
      on Ex: EAiCancelled do
      begin
        Outcome := atrCancelled;
        PostSimple(aeStatus, 'Stopped.', '', False);
      end;
      on Ex: Exception do
      begin
        Outcome := atrError;
        PostSimple(aeError, IdeToUtf8(Ex.Message), Ex.ClassName, True);
      end;
    end;
  finally
    Calls.Free;
    Context.Free;
    Events.Free;
    E := TAiEvent.Create;
    E.Kind := aeTurnFinished;
    E.TurnResult := Outcome;
    Post(E);
  end;
end;

procedure TAiSession.RunTool(Thread: TThread; Context: TAiToolContext; Call: TAiBlock; Res: TAiToolResult);
var
  Tool: TAiTool;
  Schema, Bad: TJson;
  Problem: string;
  E: TAiEvent;
begin
  Tool := FTools.Find(Call.Name);
  E := TAiEvent.Create;
  E.Kind := aeToolStarted;
  E.Text := Call.Name;
  if (Tool <> nil) and (Call.Input <> nil) then
    try
      E.Detail := Tool.Summarize(Call.Input);
    except
      E.Detail := '';
    end;
  Post(E);
  try
    if Tool = nil then
      Res.Fail('There is no tool called "' + Call.Name + '".')
    else if Call.Input = nil then
    begin
      { the input was not valid JSON: it goes back to the model as it came }
      Bad := TJson.NewObject;
      try
        Bad.PutStr('INVALID_JSON', Call.InputText);
        Res.Fail(Bad.ToJson);
      finally
        Bad.Free;
      end;
    end
    else
    begin
      Schema := Tool.Schema;
      try
        Problem := ValidateInput(Schema.Obj('input_schema'), Call.Input);
      finally
        Schema.Free;
      end;
      if Problem <> '' then Res.Fail('Invalid input: ' + Problem)
      else
      begin
        FCurTool := Tool;
        FCurInput := Call.Input;
        FCurResult := Res;
        FCurContext := Context;
        FCurApproved := not Tool.IsChange;
        if Tool.IsChange then TAiTurnThread(Thread).RunSync(DoApprove);
        if FCurApproved then
        begin
          if Tool.RunsInMainThread then TAiTurnThread(Thread).RunSync(DoExecute)
          else Tool.Execute(Context, Call.Input, Res);
        end;
      end;
    end;
  except
    on Ex: EAiCancelled do Res.Fail('Not run: the user stopped the assistant.');
    on Ex: Exception do Res.Fail('The tool failed: ' + IdeToUtf8(Ex.Message));
  end;
  if Res.Summary = '' then
  begin
    if Res.IsError then Res.Summary := Res.Text else Res.Summary := 'done';
  end;
  E := TAiEvent.Create;
  E.Kind := aeToolFinished;
  E.Text := Res.Summary;
  E.Detail := Call.Name;
  E.IsError := Res.IsError;
  Post(E);
end;

{ main thread: the change described and approved }
procedure TAiSession.DoApprove;
var
  Change: TAiChangePreview;
  Reason: string;
begin
  FCurApproved := False;
  DrainEvents;
  if FCancelled then
  begin
    FCurResult.Fail('Not run: the user stopped the assistant.');
    Exit;
  end;
  Change := TAiChangePreview.Create;
  try
    try
      if not FCurTool.Preview(FCurInput, Change, FCurResult) then Exit;
      if FAllowAll then
      begin
        FCurApproved := True;
        Exit;
      end;
      if FApprover = nil then
      begin
        FCurResult.Fail('Not run: changes cannot be approved here.');
        Exit;
      end;
      Reason := '';
      case FApprover.Approve(FCurTool, Change, Reason) of
        aaAllowAll:
          begin
            FAllowAll := True;
            FCurApproved := True;
          end;
        aaAllow: FCurApproved := True;
      else
        if Trim(Reason) <> '' then
          FCurResult.Fail('The user denied this change and said: ' + Reason)
        else
          FCurResult.Fail('The user denied this change. Do not try it again; ask the user what to do instead.');
        FCurResult.Summary := 'denied by the user';
      end;
    except
      on Ex: Exception do FCurResult.Fail('The tool failed: ' + IdeToUtf8(Ex.Message));
    end;
  finally
    Change.Free;
  end;
end;

{ main thread: the tool runs }
procedure TAiSession.DoExecute;
begin
  if FCancelled then
  begin
    FCurResult.Fail('Not run: the user stopped the assistant.');
    Exit;
  end;
  try
    FCurTool.Execute(FCurContext, FCurInput, FCurResult);
  except
    on Ex: EAiCancelled do FCurResult.Fail('Not run: the user stopped the assistant.');
    on Ex: Exception do FCurResult.Fail('The tool failed: ' + IdeToUtf8(Ex.Message));
  end;
end;

end.
