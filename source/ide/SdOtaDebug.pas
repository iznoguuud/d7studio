{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaDebug;

{ D7 Studio - the debugger of the Open Tools API: IOTADebuggerServices on the IDE's
  debugger (SdDebugUI's TDebugController and its TDebugger engine).

  * The breakpoints are the engine's (TDbgBreakpoint), each seen through one IOTABreakpoint made
    when an expert asks (IOTASourceBreakpoint / IOTAAddressBreakpoint) and kept with its notifiers
    while the breakpoint exists; the engine's Id finds the breakpoint again. Experts are told
    BreakpointAdded / BreakpointDeleted (IOTADebuggerNotifier) when the IDE's list changes; a
    breakpoint's notifiers are not told Verified, as Delphi 7 tells them none (measured).
  * A breakpoint's notifiers decide its hits first (Trigger: the engine asks the IDE before its
    own processing, the program standing - DefaultTrigger, EvaluateExpression and the threads work
    then) and may take over its properties dialog (Edit). The pass count is Delphi 7's: the passes
    since the last stop.
  * A session of the debugger is one IOTAProcess (ProcessCreated / ProcessDestroyed); its threads
    are IOTAThread - evaluate, modify, call stack, context - while the program is paused, and the
    IDE's own thread and frame are put back after an expert looked at another thread. The process's
    state goes to its current thread's notifiers as Delphi 7 sends it (Debug.TProcess.
    SetProcessState): once per change - nrRunning, nrStopped, nrException at an exception, nrFault
    and nrStopped at one the program did not handle. The process's notifiers hear the threads and
    the modules that came and went, found at each stop, and their end with the session's. An object
    of a session that ended answers empty.
  * Not done: remote debugging. }

interface

uses
  Windows, SysUtils, Classes, TlHelp32, ToolsAPI, SdOtaCore, SdDbgEngine, SdDebuggerOptions, SdDebugUI;

type
  TSdOtaDebuggerServices = class(TAggregatedObject, IOTADebuggerServices60, IOTADebuggerServices)
  private
    FNotifiers: TSdNotifierList;
    FBPIds: TList;                    // the breakpoints seen last (Ids) ...
    FBPValid: TList;                  // ... and whether they were valid
    FBPWraps: TStringList;            // Id -> IOTABreakpoint object (Objects) ...
    FBPRefs: TInterfaceList;          // ... and their references, in the same order
    FProcess: IOTAProcess;
    FProcessObj: TObject;             // the TSdOtaProcess behind it
    FWasActive: Boolean;
    function Dbg: TDebugger;
    function Wrap(BP: TDbgBreakpoint): IOTABreakpoint;
    procedure ForgetBP(Id: Cardinal);
    function BPOfKind(Address: Boolean; Index: Integer): TDbgBreakpoint;
    function NewBP(Settings: TDbgBreakpoint): IOTABreakpoint;
    procedure EachNotifier(Kind: Integer; const Process: IOTAProcess; const BP: IOTABreakpoint);
    function WrapObj(Id: Cardinal): TObject;
    procedure Trigger(Sender: TObject; BreakpointId: Cardinal; var Decision: TDbgTrigger);
    function EditBreakpoint(BP: TDbgBreakpoint; KeyChanges: Boolean): Boolean;
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    { the IDE's events (the main window's debugger handlers) }
    procedure StateChanged;
    procedure BreakpointsChanged;
    procedure DropModule(Module: HMODULE);
    { the engine's and the IDE's hooks: a breakpoint's notifiers decide its hits and its edits }
    procedure Hook;
    { the IDE ends: the notifiers still registered are told Destroyed }
    procedure Shutdown;
    { IOTADebuggerServices60 }
    function AddNotifier(const Notifier: IOTADebuggerNotifier): Integer;
    procedure AttachProcess(Pid: Integer; const RemoteHost: string = '');
    procedure CreateProcess(const ExeName, Args: string; const RemoteHost: string = '');
    procedure EnumerateRunningProcesses(Callback: TEnumerateProcessesCallback; Param: Pointer;
      const HostName: string = '');
    function GetAddressBkptCount: Integer;
    function GetAddressBkpt(Index: Integer): IOTAAddressBreakpoint;
    function GetCurrentProcess: IOTAProcess;
    function GetProcessCount: Integer;
    function GetProcess(Index: Integer): IOTAProcess;
    function GetSourceBkptCount: Integer;
    function GetSourceBkpt(Index: Integer): IOTASourceBreakpoint;
    procedure LogString(const LogStr: string); overload;
    function NewAddressBreakpoint(Address, Length: LongWord; AccessType: TOTAAccessType;
      AProcess: IOTAProcess = nil): IOTABreakpoint;
    function NewModuleBreakpoint(const ModuleName: string; AProcess: IOTAProcess): IOTABreakpoint;
    function NewSourceBreakpoint(const FileName: string; LineNumber: Integer;
      AProcess: IOTAProcess): IOTABreakpoint;
    procedure RemoveNotifier(Index: Integer);
    procedure SetCurrentProcess(Process: IOTAProcess);
    { IOTADebuggerServices }
    procedure LogString(const LogStr: string; LogItemType: TLogItemType); overload;
  end;

implementation

type
  { the settings of a breakpoint that the setters of IOTABreakpoint change (TSdOtaBreakpoint.Change) }
  TBPSetting = (bsFileName, bsLine, bsEnabled, bsCondition, bsPassCount, bsGroup, bsDoBreak, bsLogMessage,
    bsEvalExpr, bsLogResult, bsEnableGroup, bsDisableGroup);

  TSdOtaBreakpoint = class(TInterfacedObject, IOTABreakpoint40, IOTABreakpoint, IOTASourceBreakpoint,
    IOTAAddressBreakpoint)
  private
    FId: Cardinal;
    FNotifiers: TSdNotifierList;
    function BP: TDbgBreakpoint;
    function Dbg: TDebugger;
    procedure ChangeTo(Settings: TDbgBreakpoint);
    procedure Change(Setting: TBPSetting; const S: string; N: Integer);
  public
    constructor Create(AId: Cardinal);
    destructor Destroy; override;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    { the engine asks the IDE about its hits while it has notifiers }
    procedure NotifiersChanged;
    property Notifiers: TSdNotifierList read FNotifiers;
    { IOTABreakpoint40 }
    function AddNotifier(const Notifier: IOTABreakpointNotifier): Integer;
    procedure Destruct;
    function DefaultTrigger: Boolean;
    function DecPassCount: Boolean;
    procedure Edit(AllowKeyChanges: Boolean);
    function EvaluateExpression: Boolean;
    function GetEnabled: Boolean;
    function GetExpression: string;
    function GetFileName: string;
    function GetLineNumber: Integer;
    function GetCurPassCount: Integer;
    function GetPassCount: Integer;
    procedure RemoveNotifier(Index: Integer);
    procedure ResetPassCount;
    procedure SetFileName(const Value: string);
    procedure SetLineNumber(Value: Integer);
    procedure SetEnabled(Value: Boolean);
    procedure SetExpression(const Value: string);
    procedure SetPassCount(Value: Integer);
    function ValidInCurrentProcess: Boolean;
    function ValidInProcess(Process: IOTAProcess): Boolean;
    { IOTABreakpoint }
    function GetGroupName: string;
    function GetDoBreak: Boolean;
    function GetLogMessage: string;
    function GetEvalExpression: string;
    function GetLogResult: Boolean;
    function GetEnableGroup: string;
    function GetDisableGroup: string;
    procedure SetGroupName(const Value: string);
    procedure SetDoBreak(const Value: Boolean);
    procedure SetLogMessage(const Value: string);
    procedure SetEvalExpression(const Value: string);
    procedure SetLogResult(const Value: Boolean);
    procedure SetEnableGroup(const Value: string);
    procedure SetDisableGroup(const Value: string);
    { IOTAAddressBreakpoint }
    function Address: LongWord;
    function AddressInProcess(Process: IOTAProcess): LongWord;
    function GetAccessType: TOTAAccessType;
    function GetDataExpr: string;
    function GetLineSize: Integer;
    function GetLineOffset: Integer;
    function GetModuleName: string;
  end;

  TSdOtaThread = class(TInterfacedObject, IOTAThread50, IOTAThread60, IOTAThread)
  private
    FId: Cardinal;
    FSession: Integer;
    FNotifiers: TSdNotifierList;
    FLastExpr: string;
    FLastCalls: Boolean;               // ... evaluated with calls: Modify reads it so too
    FFrames: TDbgFrameArray;           // the call stack of the stand FFramesStand (Frames)
    FFramesStand: Integer;
    function Dbg: TDebugger;
    function Paused: Boolean;
    function Select(out Old: TDbgInspection): Boolean;
    procedure Unselect(const Old: TDbgInspection);
    function Frames(out F: TDbgFrameArray): Boolean;
    {$HINTS OFF}
    function ValueOf(const V: TDbgVar): LongWord;
    {$HINTS ON}
  public
    constructor Create(AId: Cardinal; ASession: Integer);
    destructor Destroy; override;
    property Notifiers: TSdNotifierList read FNotifiers;
    property Id: Cardinal read FId;
    { IOTAThread50 }
    function AddNotifier(const Notifier: IOTAThreadNotifier): Integer;
    function Evaluate(const ExprStr: string; ResultStr: PChar; ResultStrSize: LongWord;
      out CanModify: Boolean; AllowSideEffects: Boolean; FormatSpecifiers: PChar;
      out ResultAddr: LongWord; out ResultSize, ResultVal: LongWord): TOTAEvaluateResult;
    function Modify(const ValueStr: string; ResultStr: PChar; ResultSize: LongWord;
      out ResultVal: Integer): TOTAEvaluateResult;
    function GetCallCount: Integer;
    function GetCallHeader(Index: Integer): string;
    procedure GetCallPos(Index: Integer; out FileName: string; out LineNum: Integer);
    function GetCurrentFile: string;
    function GetCurrentLine: LongWord;
    function GetContext: TContext;
    function GetHandle: THandle;
    function GetOSThreadID: LongWord;
    function GetState: TOTAThreadState;
    procedure RemoveNotifier(Index: Integer);
    { IOTAThread60 }
    function GetOTAThreadContext: TOTAThreadContext;
    { IOTAThread }
    function GetOTAXMMRegisters(var OTAXMMRegs: TOTAXMMRegs): Boolean;
    procedure SetOTAXMMRegisters(NewOTAXMMRegs: TOTAXMMRegs);
  end;

  TSdOtaProcessModule = class(TInterfacedObject, IOTAProcessModule)
  private
    FInfo: TDbgModuleInfo;
    FSession: Integer;
    FNotifiers: TSdNotifierList;
    FDetails: TDbgModuleDetails;
    FHaveDetails: Boolean;
    function Details: Boolean;
  public
    constructor Create(const AInfo: TDbgModuleInfo; ASession: Integer);
    destructor Destroy; override;
    property Notifiers: TSdNotifierList read FNotifiers;
    function AddNotifier(const Notifier: IOTAProcessModNotifier): Integer;
    function GetCompUnitCount: Integer;
    function GetCompUnit(Index: Integer): string;
    function GetCompUnitFileCount(Index: Integer): Integer;
    function GetCompUnitFileName(CompIndex, FileIndex: Integer): string;
    function GetEntryPoint: LongWord;
    function GetBaseAddress: LongWord;
    function GetFileCount: Integer;
    function GetFileName(Index: Integer): string;
    function GetModuleEntryPointCount: Integer;
    function GetModuleEntryPoint(Index: Integer): string;
    function GetModuleEntryPointAddress(Index: Integer): LongWord;
    function GetModuleFileName: string;
    function GetModuleName: string;
    procedure RemoveNotifier(Index: Integer);
  end;

  TSdOtaProcess = class(TInterfacedObject, IOTAProcess60, IOTAProcess)
  private
    FSession: Integer;
    FPid: Cardinal;
    FNotifiers: TSdNotifierList;
    FThreadIds: TStringList;          // the threads seen (Objects: TSdOtaThread) ...
    FThreadRefs: TInterfaceList;      // ... their references, in the same order
    FModules: TStringList;            // the modules seen (their paths; Objects: TSdOtaProcessModule) ...
    FModuleRefs: TInterfaceList;      // ... as IOTAProcessModule, in the same order
    FSynced: Integer;                 // the time it stood (the engine's StandCount) whose threads and modules were taken
    FStops: Integer;                  // the stop told to the current thread last ...
    FRunning: Boolean;                // ... and whether nrRunning was told since
    FCurrent: Cardinal;               // the current thread: the one that stopped last, or was chosen
    function Dbg: TDebugger;
    function ThreadObj(Id: Cardinal): TSdOtaThread;
    procedure Sync;
    procedure NotifyCurrent(Reason: TOTANotifyReason);
  public
    constructor Create(ASession: Integer);
    destructor Destroy; override;
    { a change of the debugger's state: the current thread's notifiers told, at a stop the threads
      and modules compared with those seen }
    procedure StateChanged;
    { the session ended: its threads and modules are gone }
    procedure Ended;
    procedure DropModule(Module: HMODULE);
    { IOTAProcess60 }
    function AddNotifier(const Notifier: IOTAProcessNotifier): Integer;
    function GetCurrentThread: IOTAThread;
    function GetThreadCount: Integer;
    function GetThread(Index: Integer): IOTAThread;
    function GetProcessId: LongWord;
    procedure Pause;
    function ReadProcessMemory(Address: LongWord; Count: Integer; var Buffer): Integer;
    procedure RemoveNotifier(Index: Integer);
    procedure Run(RunMode: TOTARunMode);
    procedure SetCurrentThread(Value: IOTAThread);
    procedure Terminate;
    function WriteProcessMemory(Address: LongWord; Count: Integer; var Buffer): Integer;
    { IOTAProcess }
    function GetOSProcessId: LongWord;
  end;

function HostDbg: TDebugger;
begin
  if (OtaHost <> nil) and (OtaHost.Debug <> nil) then Result := OtaHost.Debug.Debugger else Result := nil;
end;

function HostCtl: TDebugController;
begin
  if OtaHost <> nil then Result := OtaHost.Debug else Result := nil;
end;

function SessionActive: Boolean;
begin
  Result := (HostCtl <> nil) and HostCtl.Active;
end;

var
  OtaSession: Integer;                  // the debugger's sessions so far
  Services: TSdOtaDebuggerServices;     // the one instance (SdOtaServices makes it)

{ the engine while session Session goes on; nil once it ended (its objects answer empty) }
function SessionDbg(Session: Integer): TDebugger;
begin
  if (Session = OtaSession) and SessionActive then Result := HostDbg else Result := nil;
end;

{ ---------------------------------------------------------------- TSdOtaBreakpoint }

constructor TSdOtaBreakpoint.Create(AId: Cardinal);
begin
  inherited Create;
  FId := AId;
  FNotifiers := TSdNotifierList.Create;
end;

destructor TSdOtaBreakpoint.Destroy;
begin
  FNotifiers.Free;
  inherited;
end;

{ a source breakpoint is no address breakpoint, and an address, data or module load breakpoint is
  no source breakpoint: experts tell the kinds apart with Supports }
function TSdOtaBreakpoint.QueryInterface(const IID: TGUID; out Obj): HResult;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B <> nil) and ((IsEqualGUID(IID, IOTASourceBreakpoint) and (B.Kind <> bkSource)) or
    (IsEqualGUID(IID, IOTAAddressBreakpoint) and (B.Kind = bkSource))) then
  begin
    Pointer(Obj) := nil;
    Result := E_NOINTERFACE;
  end
  else
    Result := inherited QueryInterface(IID, Obj);
end;

function TSdOtaBreakpoint.Dbg: TDebugger;
begin
  Result := HostDbg;
end;

function TSdOtaBreakpoint.BP: TDbgBreakpoint;
var
  D: TDebugger;
begin
  D := Dbg;
  if D = nil then Result := nil else Result := D.BreakpointById(FId);
end;

{ every setting through the engine (its lock), the IDE's markers and view after it }
procedure TSdOtaBreakpoint.ChangeTo(Settings: TDbgBreakpoint);
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Exit;
  Dbg.ChangeBreakpointTo(B, Settings);
  if OtaHost <> nil then OtaHost.BreakpointsChanged;
end;

{ a copy of the breakpoint's settings to change (nil: it is gone) }
function CopyOf(B: TDbgBreakpoint): TDbgBreakpoint;
begin
  if B = nil then
  begin
    Result := nil;
    Exit;
  end;
  Result := TDbgBreakpoint.Create;
  Result.Assign(B);
end;

{ one setting of the breakpoint, given to the engine with the others as they are (ChangeTo): S the
  text of a text setting, N the number of a number - of a flag 0 or 1 }
procedure TSdOtaBreakpoint.Change(Setting: TBPSetting; const S: string; N: Integer);
var
  B: TDbgBreakpoint;
begin
  B := CopyOf(BP);
  if B = nil then Exit;
  try
    case Setting of
      bsFileName: B.FileName := S;
      bsLine: B.Line := N;
      bsEnabled: B.Enabled := N <> 0;
      bsCondition: B.Condition := S;
      bsPassCount: B.PassCount := N;
      bsGroup: B.Group := S;
      bsDoBreak: B.DoBreak := N <> 0;
      bsLogMessage: B.LogMessage := S;
      bsEvalExpr: B.EvalExpr := S;
      bsLogResult: B.LogResult := N <> 0;
      bsEnableGroup: B.EnableGroup := S;
      bsDisableGroup: B.DisableGroup := S;
    end;
    ChangeTo(B);
  finally
    B.Free;
  end;
end;

function TSdOtaBreakpoint.AddNotifier(const Notifier: IOTABreakpointNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
  NotifiersChanged;
end;

procedure TSdOtaBreakpoint.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
  NotifiersChanged;
end;

procedure TSdOtaBreakpoint.NotifiersChanged;
var
  B: TDbgBreakpoint;
begin
  if Dbg = nil then Exit;
  if Services <> nil then Services.Hook;
  Dbg.Lock;
  try
    B := BP;
    if B <> nil then B.AskTrigger := FNotifiers.Active > 0;
  finally
    Dbg.Unlock;
  end;
end;

procedure TSdOtaBreakpoint.Destruct;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Exit;
  Dbg.RemoveBreakpoint(B);
  if OtaHost <> nil then OtaHost.BreakpointsChanged;
end;

{ what the hit would do without the notifiers: the condition, a pass, the actions (Delphi's
  TDbkBreakpoint.Trigger) - whether the program stops }
function TSdOtaBreakpoint.DefaultTrigger: Boolean;
begin
  Result := (Dbg = nil) or Dbg.DefaultTrigger(FId);
end;

{ The pass count is Delphi 7's (Debug.TBaseBreakpoint): CurPassCount the passes since the last stop
  (the engine's HitCount, counted by its debug thread - read and written under its lock);
  DecPassCount takes one off, True when none is left; ResetPassCount makes it 0. }
function TSdOtaBreakpoint.DecPassCount: Boolean;
var
  B: TDbgBreakpoint;
begin
  Result := False;
  if Dbg = nil then Exit;
  Dbg.Lock;
  try
    B := BP;
    if B = nil then Exit;
    Dec(B.HitCount);
    Result := B.HitCount = 0;
  finally
    Dbg.Unlock;
  end;
end;

{ its notifiers first (Edit: True - they did it), then the IDE's dialog of its kind }
procedure TSdOtaBreakpoint.Edit(AllowKeyChanges: Boolean);
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B <> nil) and (HostCtl <> nil) then HostCtl.EditBreakpoint(B, AllowKeyChanges);
end;

{ its condition in the thread inspected (during Trigger the one that hit it); none, or one that
  cannot be evaluated, holds - the engine stops at such a breakpoint too }
function TSdOtaBreakpoint.EvaluateExpression: Boolean;
var
  B: TDbgBreakpoint;
  Value: Boolean;
  Err: string;
begin
  B := BP;
  Result := True;
  if (B = nil) or (B.Condition = '') or (Dbg = nil) or (Dbg.State <> dsPaused) then Exit;
  { decided as the engine decides a condition (zero, False, nil: false) }
  if Dbg.EvalBoolean(B.Condition, Value, Err) then Result := Value;
end;

function TSdOtaBreakpoint.GetEnabled: Boolean;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  Result := (B <> nil) and B.Enabled;
end;

function TSdOtaBreakpoint.GetExpression: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.Condition;
end;

function TSdOtaBreakpoint.GetFileName: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B = nil) or (B.Kind <> bkSource) then Result := '' else Result := B.FileName;
end;

function TSdOtaBreakpoint.GetLineNumber: Integer;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B = nil) or (B.Kind <> bkSource) then Result := 0 else Result := B.Line;
end;

function TSdOtaBreakpoint.GetCurPassCount: Integer;
var
  B: TDbgBreakpoint;
begin
  Result := 0;
  if Dbg = nil then Exit;
  Dbg.Lock;
  try
    B := BP;
    if B <> nil then Result := B.HitCount;
  finally
    Dbg.Unlock;
  end;
end;

function TSdOtaBreakpoint.GetPassCount: Integer;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := 0 else Result := B.PassCount;
end;

procedure TSdOtaBreakpoint.ResetPassCount;
var
  B: TDbgBreakpoint;
begin
  if Dbg = nil then Exit;
  Dbg.Lock;
  try
    B := BP;
    if B <> nil then B.HitCount := 0;
  finally
    Dbg.Unlock;
  end;
end;

procedure TSdOtaBreakpoint.SetFileName(const Value: string);
begin
  Change(bsFileName, Value, 0);
end;

procedure TSdOtaBreakpoint.SetLineNumber(Value: Integer);
begin
  Change(bsLine, '', Value);
end;

procedure TSdOtaBreakpoint.SetEnabled(Value: Boolean);
begin
  Change(bsEnabled, '', Ord(Value));
end;

procedure TSdOtaBreakpoint.SetExpression(const Value: string);
begin
  Change(bsCondition, Value, 0);
end;

procedure TSdOtaBreakpoint.SetPassCount(Value: Integer);
begin
  Change(bsPassCount, '', Value);
end;

function TSdOtaBreakpoint.ValidInCurrentProcess: Boolean;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  Result := (B <> nil) and B.Valid;
end;

function TSdOtaBreakpoint.ValidInProcess(Process: IOTAProcess): Boolean;
begin
  Result := ValidInCurrentProcess;
end;

function TSdOtaBreakpoint.GetGroupName: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.Group;
end;

function TSdOtaBreakpoint.GetDoBreak: Boolean;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  Result := (B <> nil) and B.DoBreak;
end;

function TSdOtaBreakpoint.GetLogMessage: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.LogMessage;
end;

function TSdOtaBreakpoint.GetEvalExpression: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.EvalExpr;
end;

function TSdOtaBreakpoint.GetLogResult: Boolean;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  Result := (B <> nil) and B.LogResult;
end;

function TSdOtaBreakpoint.GetEnableGroup: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.EnableGroup;
end;

function TSdOtaBreakpoint.GetDisableGroup: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if B = nil then Result := '' else Result := B.DisableGroup;
end;

procedure TSdOtaBreakpoint.SetGroupName(const Value: string);
begin
  Change(bsGroup, Value, 0);
end;

procedure TSdOtaBreakpoint.SetDoBreak(const Value: Boolean);
begin
  Change(bsDoBreak, '', Ord(Value));
end;

procedure TSdOtaBreakpoint.SetLogMessage(const Value: string);
begin
  Change(bsLogMessage, Value, 0);
end;

procedure TSdOtaBreakpoint.SetEvalExpression(const Value: string);
begin
  Change(bsEvalExpr, Value, 0);
end;

procedure TSdOtaBreakpoint.SetLogResult(const Value: Boolean);
begin
  Change(bsLogResult, '', Ord(Value));
end;

procedure TSdOtaBreakpoint.SetEnableGroup(const Value: string);
begin
  Change(bsEnableGroup, Value, 0);
end;

procedure TSdOtaBreakpoint.SetDisableGroup(const Value: string);
begin
  Change(bsDisableGroup, Value, 0);
end;

function TSdOtaBreakpoint.Address: LongWord;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B = nil) or not B.Valid or not (B.Kind in [bkAddress, bkData]) then Result := 0 else Result := B.Address;
end;

function TSdOtaBreakpoint.AddressInProcess(Process: IOTAProcess): LongWord;
begin
  Result := Address;
end;

function TSdOtaBreakpoint.GetAccessType: TOTAAccessType;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B = nil) or (B.Kind <> bkData) then Result := atExecute
  else if B.DataRead then Result := atRead
  else Result := atWrite;
end;

function TSdOtaBreakpoint.GetDataExpr: string;
var
  B: TDbgBreakpoint;
begin
  B := BP;
  if (B = nil) or (B.Kind <> bkData) then Result := '' else Result := B.Watch;
end;

{ the code of the source line an address breakpoint lies in: its size, and where in it the
  breakpoint is }
function TSdOtaBreakpoint.GetLineSize: Integer;
var
  B: TDbgBreakpoint;
  Start, Size: Cardinal;
begin
  Result := 0;
  B := BP;
  if (B <> nil) and (B.Kind = bkAddress) and B.Valid and Dbg.LineCodeAt(B.Address, Start, Size) then
    Result := Size;
end;

function TSdOtaBreakpoint.GetLineOffset: Integer;
var
  B: TDbgBreakpoint;
  Start, Size: Cardinal;
begin
  Result := 0;
  B := BP;
  if (B <> nil) and (B.Kind = bkAddress) and B.Valid and Dbg.LineCodeAt(B.Address, Start, Size) then
    Result := B.Address - Start;
end;

{ a module load breakpoint's module; the module an address or data breakpoint lies in }
function TSdOtaBreakpoint.GetModuleName: string;
var
  B: TDbgBreakpoint;
  Mods: TDbgModuleArray;
  I: Integer;
begin
  Result := '';
  B := BP;
  if B = nil then Exit;
  if B.Kind = bkModule then
    Result := B.FileName
  else if (B.Kind in [bkAddress, bkData]) and Dbg.GetModules(Mods) then
    for I := 0 to High(Mods) do
      if (B.Address >= Mods[I].BaseAddr) and (B.Address - Mods[I].BaseAddr < Mods[I].Size) then
      begin
        Result := Mods[I].Name;
        Exit;
      end;
end;

{ ---------------------------------------------------------------- TSdOtaThread }

constructor TSdOtaThread.Create(AId: Cardinal; ASession: Integer);
begin
  inherited Create;
  FId := AId;
  FSession := ASession;
  FNotifiers := TSdNotifierList.Create;
  FFramesStand := -1;
end;

destructor TSdOtaThread.Destroy;
begin
  FNotifiers.Free;
  inherited;
end;

function TSdOtaThread.Dbg: TDebugger;
begin
  Result := SessionDbg(FSession);
end;

function TSdOtaThread.Paused: Boolean;
begin
  Result := (Dbg <> nil) and (Dbg.State = dsPaused);
end;

{ this thread the one the engine inspects for a moment; Old: what the IDE inspected - its thread,
  frame and exception context -, which Unselect puts back }
function TSdOtaThread.Select(out Old: TDbgInspection): Boolean;
begin
  FillChar(Old, SizeOf(Old), 0);
  Result := Paused;
  if not Result then Exit;
  Old := Dbg.SaveInspection;
  if Old.ThreadId <> FId then Result := Dbg.SelectThread(FId);
end;

procedure TSdOtaThread.Unselect(const Old: TDbgInspection);
begin
  if (Old.ThreadId <> 0) and (Old.ThreadId <> FId) and Paused then Dbg.RestoreInspection(Old);
end;

{ the thread's call stack, walked once each time the program stands: an expert reads it frame by
  frame (GetCallHeader, GetCallPos), and a walk of another thread than the IDE's also costs the
  IDE's own frames (RestoreInspection) }
function TSdOtaThread.Frames(out F: TDbgFrameArray): Boolean;
var
  Old: TDbgInspection;
  D: TDebugger;
begin
  F := nil;
  D := Dbg;
  if (D <> nil) and (D.State = dsPaused) and (D.StandCount = FFramesStand) then
  begin
    F := FFrames;
    Result := Length(F) > 0;
    Exit;
  end;
  Result := Select(Old);
  if not Result then Exit;
  try
    Result := D.GetCallStack(F);
  finally
    Unselect(Old);
  end;
  FFrames := F;
  FFramesStand := D.StandCount;
end;

{ a value as a number: the variable's bytes when it has four at most, else its text read as a
  number (True: 1) - not given as ResultVal, which Delphi 7 leaves 0 }
function TSdOtaThread.ValueOf(const V: TDbgVar): LongWord;
begin
  Result := 0;
  if (V.Address <> 0) and (V.Size in [1, 2, 4]) and Dbg.ReadMemory(V.Address, Result, V.Size) then Exit;
  Result := 0;
  if SameText(V.Value, 'True') then Result := 1
  else Result := LongWord(StrToIntDef(V.Value, 0));
end;

function TSdOtaThread.AddNotifier(const Notifier: IOTAThreadNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaThread.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

{ in this thread, with the evaluator's format specifiers ('h', 'd', 'c', 'p', 's': Delphi's of
  the Watch List); ResultVal 0, as Delphi 7's (measured: an Integer field's too) }
function TSdOtaThread.Evaluate(const ExprStr: string; ResultStr: PChar; ResultStrSize: LongWord;
  out CanModify: Boolean; AllowSideEffects: Boolean; FormatSpecifiers: PChar;
  out ResultAddr: LongWord; out ResultSize, ResultVal: LongWord): TOTAEvaluateResult;
var
  Old: TDbgInspection;
  V: TDbgVar;
  Err, S, Expr: string;
  Ok: Boolean;
begin
  CanModify := False;
  ResultAddr := 0;
  ResultSize := 0;
  ResultVal := 0;
  Result := erError;
  if not Select(Old) then
  begin
    S := 'The process is not stopped';
    if (ResultStr <> nil) and (ResultStrSize > 0) then StrPLCopy(ResultStr, S, ResultStrSize - 1);
    Exit;
  end;
  Expr := ExprStr;
  if (FormatSpecifiers <> nil) and (FormatSpecifiers^ <> #0) then Expr := Expr + ',' + FormatSpecifiers;
  try
    Ok := Dbg.Evaluate(Expr, V, Err, AllowSideEffects);
  finally
    Unselect(Old);
  end;
  if Ok then
  begin
    S := V.Value;
    Result := erOK;
    CanModify := V.CanModify;
    ResultAddr := V.Address;
    ResultSize := V.Size;
    FLastExpr := ExprStr;
    FLastCalls := AllowSideEffects;
  end
  else
    S := Err;
  if (ResultStr <> nil) and (ResultStrSize > 0) then StrPLCopy(ResultStr, S, ResultStrSize - 1);
end;

{ the expression Evaluate evaluated last gets ValueStr - with calls when it was evaluated so;
  ResultVal 0, as Delphi 7's (measured) }
function TSdOtaThread.Modify(const ValueStr: string; ResultStr: PChar; ResultSize: LongWord;
  out ResultVal: Integer): TOTAEvaluateResult;
var
  Old: TDbgInspection;
  Err, S: string;
  V: TDbgVar;
begin
  ResultVal := 0;
  Result := erError;
  if (FLastExpr = '') or not Select(Old) then Exit;
  try
    if Dbg.Modify(FLastExpr, ValueStr, Err, FLastCalls) then
    begin
      Result := erOK;
      if Dbg.Evaluate(FLastExpr, V, Err, FLastCalls) then S := V.Value
      else S := ValueStr;
    end
    else
      S := Err;
  finally
    Unselect(Old);
  end;
  if (ResultStr <> nil) and (ResultSize > 0) then StrPLCopy(ResultStr, S, ResultSize - 1);
  if HostCtl <> nil then HostCtl.RefreshWatches;
end;

function TSdOtaThread.GetCallCount: Integer;
var
  F: TDbgFrameArray;
begin
  if Frames(F) then Result := Length(F) else Result := 0;
end;

{ 1-based, as Delphi's; named as the Call Stack view names it }
function TSdOtaThread.GetCallHeader(Index: Integer): string;
var
  F: TDbgFrameArray;
begin
  Result := '';
  if Frames(F) and (Index >= 1) and (Index <= Length(F)) then Result := FrameHeader(F[Index - 1]);
end;

procedure TSdOtaThread.GetCallPos(Index: Integer; out FileName: string; out LineNum: Integer);
var
  F: TDbgFrameArray;
begin
  FileName := '';
  LineNum := 0;
  if not Frames(F) or (Index < 1) or (Index > Length(F)) then Exit;
  FileName := F[Index - 1].FileName;
  LineNum := F[Index - 1].Line;
end;

{ where the thread stands: '' (and line 0) when that place has no debug information }
function TSdOtaThread.GetCurrentFile: string;
var
  F: TDbgFrameArray;
begin
  Result := '';
  if Frames(F) and (F[0].Line > 0) then Result := F[0].FileName;
end;

function TSdOtaThread.GetCurrentLine: LongWord;
var
  F: TDbgFrameArray;
begin
  Result := 0;
  if Frames(F) then Result := F[0].Line;
end;

function TSdOtaThread.GetContext: TContext;
var
  H: THandle;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ContextFlags := CONTEXT_FULL or CONTEXT_FLOATING_POINT or CONTEXT_DEBUG_REGISTERS;
  H := GetHandle;
  if (H = 0) or not Paused or not GetThreadContext(H, Result) then
    FillChar(Result, SizeOf(Result), 0);
end;

function TSdOtaThread.GetHandle: THandle;
begin
  if Dbg = nil then Result := 0 else Result := Dbg.ThreadHandle(FId);
end;

function TSdOtaThread.GetOSThreadID: LongWord;
begin
  Result := FId;
end;

function TSdOtaThread.GetState: TOTAThreadState;
begin
  if Dbg = nil then Result := tsNone
  else
    case Dbg.State of
      dsPaused: Result := tsStopped;
      dsRunning: Result := tsRunnable;
    else
      Result := tsNone;
    end;
end;

function TSdOtaThread.GetOTAThreadContext: TOTAThreadContext;
begin
  Result := GetContext;
end;

{ Delphi 7 has no XMM registers to give either (False) }
function TSdOtaThread.GetOTAXMMRegisters(var OTAXMMRegs: TOTAXMMRegs): Boolean;
begin
  FillChar(OTAXMMRegs, SizeOf(OTAXMMRegs), 0);
  Result := False;
end;

procedure TSdOtaThread.SetOTAXMMRegisters(NewOTAXMMRegs: TOTAXMMRegs);
begin
end;

{ ---------------------------------------------------------------- TSdOtaProcessModule }

constructor TSdOtaProcessModule.Create(const AInfo: TDbgModuleInfo; ASession: Integer);
begin
  inherited Create;
  FInfo := AInfo;
  FSession := ASession;
  FNotifiers := TSdNotifierList.Create;
end;

destructor TSdOtaProcessModule.Destroy;
begin
  FNotifiers.Free;
  inherited;
end;

{ its units, files and routines: read once, the first time they are asked for while the program
  stands }
function TSdOtaProcessModule.Details: Boolean;
var
  D: TDebugger;
begin
  if not FHaveDetails then
  begin
    D := SessionDbg(FSession);
    FHaveDetails := (D <> nil) and D.GetModuleDetails(FInfo.BaseAddr, FDetails);
  end;
  Result := FHaveDetails;
end;

function TSdOtaProcessModule.AddNotifier(const Notifier: IOTAProcessModNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaProcessModule.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

function TSdOtaProcessModule.GetCompUnitCount: Integer;
begin
  if Details then Result := Length(FDetails.Units) else Result := 0;
end;

function TSdOtaProcessModule.GetCompUnit(Index: Integer): string;
begin
  Result := '';
  if Details and (Index >= 0) and (Index <= High(FDetails.Units)) then Result := FDetails.Units[Index].Name;
end;

function TSdOtaProcessModule.GetCompUnitFileCount(Index: Integer): Integer;
begin
  Result := 0;
  if Details and (Index >= 0) and (Index <= High(FDetails.Units)) then Result := Length(FDetails.Units[Index].Files);
end;

function TSdOtaProcessModule.GetCompUnitFileName(CompIndex, FileIndex: Integer): string;
begin
  Result := '';
  if Details and (CompIndex >= 0) and (CompIndex <= High(FDetails.Units)) and (FileIndex >= 0) and
    (FileIndex <= High(FDetails.Units[CompIndex].Files)) then
    Result := FDetails.Units[CompIndex].Files[FileIndex];
end;

function TSdOtaProcessModule.GetEntryPoint: LongWord;
begin
  if Details then Result := FDetails.EntryPoint else Result := 0;
end;

function TSdOtaProcessModule.GetBaseAddress: LongWord;
begin
  Result := FInfo.BaseAddr;
end;

function TSdOtaProcessModule.GetFileCount: Integer;
begin
  if Details then Result := Length(FDetails.Files) else Result := 0;
end;

function TSdOtaProcessModule.GetFileName(Index: Integer): string;
begin
  Result := '';
  if Details and (Index >= 0) and (Index <= High(FDetails.Files)) then Result := FDetails.Files[Index];
end;

function TSdOtaProcessModule.GetModuleEntryPointCount: Integer;
begin
  if Details then Result := Length(FDetails.EntryNames) else Result := 0;
end;

function TSdOtaProcessModule.GetModuleEntryPoint(Index: Integer): string;
begin
  Result := '';
  if Details and (Index >= 0) and (Index <= High(FDetails.EntryNames)) then Result := FDetails.EntryNames[Index];
end;

function TSdOtaProcessModule.GetModuleEntryPointAddress(Index: Integer): LongWord;
begin
  Result := 0;
  if Details and (Index >= 0) and (Index <= High(FDetails.EntryAddrs)) then Result := FDetails.EntryAddrs[Index];
end;

function TSdOtaProcessModule.GetModuleFileName: string;
begin
  Result := FInfo.Path;
end;

function TSdOtaProcessModule.GetModuleName: string;
begin
  Result := FInfo.Name;
end;

{ ---------------------------------------------------------------- TSdOtaProcess }

constructor TSdOtaProcess.Create(ASession: Integer);
begin
  inherited Create;
  FSession := ASession;
  FNotifiers := TSdNotifierList.Create;
  FThreadIds := TStringList.Create;
  FThreadRefs := TInterfaceList.Create;
  FModules := TStringList.Create;
  FModuleRefs := TInterfaceList.Create;
  if HostCtl <> nil then FStops := HostCtl.StopCount;
  FSynced := -1;
end;

destructor TSdOtaProcess.Destroy;
begin
  FModuleRefs.Free;
  FModules.Free;
  FThreadRefs.Free;
  FThreadIds.Free;
  FNotifiers.Free;
  inherited;
end;

function TSdOtaProcess.Dbg: TDebugger;
begin
  Result := SessionDbg(FSession);
end;

{ a thread seen (nil: not, or not yet) }
function TSdOtaProcess.ThreadObj(Id: Cardinal): TSdOtaThread;
var
  I: Integer;
begin
  Result := nil;
  if Id = 0 then Exit;
  I := FThreadIds.IndexOf(IntToStr(Id));
  if I >= 0 then Result := TSdOtaThread(FThreadIds.Objects[I]);
end;

{ the calls of the process's and the threads' notifiers (TSdNotifierList.Each: Data their
  argument) }

procedure ThreadNotifyOne(const N: IInterface; Data: Pointer);
begin
  IOTAThreadNotifier(N).ThreadNotify(TOTANotifyReason(Integer(Data)));
end;

procedure ThreadCreatedOne(const N: IInterface; Data: Pointer);
begin
  IOTAProcessNotifier(N).ThreadCreated(IOTAThread(Data));
end;

procedure ThreadDestroyedOne(const N: IInterface; Data: Pointer);
begin
  IOTAProcessNotifier(N).ThreadDestroyed(IOTAThread(Data));
end;

procedure ModuleCreatedOne(const N: IInterface; Data: Pointer);
begin
  IOTAProcessNotifier(N).ProcessModuleCreated(IOTAProcessModule(Data));
end;

procedure ModuleDestroyedOne(const N: IInterface; Data: Pointer);
begin
  IOTAProcessNotifier(N).ProcessModuleDestroyed(IOTAProcessModule(Data));
end;

{ the threads and modules of the program while it stands (a stop, a breakpoint's trigger), compared
  with those seen - once each time it stands; the threads are listed without their stacks }
procedure TSdOtaProcess.Sync;
var
  D: TDebugger;
  Threads: TDbgThreadArray;
  Mods: TDbgModuleArray;
  Now: TStringList;
  I: Integer;
  T: IOTAThread;
  TObj: TSdOtaThread;
  M: IOTAProcessModule;
  MO: TSdOtaProcessModule;
begin
  D := Dbg;
  if (D = nil) or (D.State <> dsPaused) or (FSynced = D.StandCount) then Exit;
  FSynced := D.StandCount;
  Now := TStringList.Create;
  try
    { threads }
    if D.GetThreads(Threads, False) then
    begin
      for I := 0 to High(Threads) do Now.Add(IntToStr(Threads[I].ThreadId));
      for I := FThreadIds.Count - 1 downto 0 do
        if Now.IndexOf(FThreadIds[I]) < 0 then
        begin
          T := IOTAThread(FThreadRefs[I]);
          FThreadIds.Delete(I);
          FThreadRefs.Delete(I);
          FNotifiers.Each(IOTAProcessNotifier, ThreadDestroyedOne, Pointer(T), 'IOTAProcessNotifier.ThreadDestroyed');
          T := nil;
        end;
      for I := 0 to High(Threads) do
        if FThreadIds.IndexOf(Now[I]) < 0 then
        begin
          TObj := TSdOtaThread.Create(Threads[I].ThreadId, FSession);
          T := TObj;
          FThreadIds.AddObject(Now[I], TObj);
          FThreadRefs.Add(T);
          FNotifiers.Each(IOTAProcessNotifier, ThreadCreatedOne, Pointer(T), 'IOTAProcessNotifier.ThreadCreated');
          T := nil;
        end;
    end;
    { modules }
    if D.GetModules(Mods) then
    begin
      Now.Clear;
      for I := 0 to High(Mods) do Now.Add(Mods[I].Path);
      for I := FModules.Count - 1 downto 0 do
        if Now.IndexOf(FModules[I]) < 0 then
        begin
          M := IOTAProcessModule(FModuleRefs[I]);
          FModules.Delete(I);
          FModuleRefs.Delete(I);
          FNotifiers.Each(IOTAProcessNotifier, ModuleDestroyedOne, Pointer(M),
            'IOTAProcessNotifier.ProcessModuleDestroyed');
          M := nil;
        end;
      for I := 0 to High(Mods) do
        if FModules.IndexOf(Mods[I].Path) < 0 then
        begin
          MO := TSdOtaProcessModule.Create(Mods[I], FSession);
          M := MO;
          FModules.AddObject(Mods[I].Path, MO);
          FModuleRefs.Add(M);
          FNotifiers.Each(IOTAProcessNotifier, ModuleCreatedOne, Pointer(M), 'IOTAProcessNotifier.ProcessModuleCreated');
          M := nil;
        end;
    end;
  finally
    Now.Free;
  end;
end;

procedure TSdOtaProcess.NotifyCurrent(Reason: TOTANotifyReason);
var
  T: TSdOtaThread;
begin
  T := ThreadObj(FCurrent);
  if T <> nil then
    T.Notifiers.Each(IOTAThreadNotifier, ThreadNotifyOne, Pointer(Ord(Reason)), 'IOTAThreadNotifier.ThreadNotify');
end;

{ Delphi 7's thread notifications (Debug.TProcess.SetProcessState, TThread.DoNotifyThreadState):
  once per change of the process's state, to its current thread only. A stop is told when the IDE
  shows it; a step is over before its run is seen, so its nrRunning comes with the stop. }
procedure TSdOtaProcess.StateChanged;
var
  C: TDebugController;
  D: TDebugger;
begin
  D := Dbg;
  C := HostCtl;
  if (D = nil) or (C = nil) then Exit;
  if FPid = 0 then FPid := D.ProcessId;
  if (C.StopCount <> FStops) and (D.State = dsPaused) then
  begin
    FStops := C.StopCount;
    if not FRunning then NotifyCurrent(nrRunning);
    FRunning := False;
    Sync;
    if D.CurrentThreadId <> 0 then FCurrent := D.CurrentThreadId;
    if C.StopReason <> srException then
      NotifyCurrent(nrStopped)
    else if D.StopFault then
    begin
      NotifyCurrent(nrFault);
      NotifyCurrent(nrStopped);
    end
    else
      NotifyCurrent(nrException);
  end
  else if (D.State = dsRunning) and not FRunning then
  begin
    FRunning := True;
    NotifyCurrent(nrRunning);
  end;
end;

procedure TSdOtaProcess.Ended;
var
  T: IOTAThread;
  M: IOTAProcessModule;
begin
  while FThreadRefs.Count > 0 do
  begin
    T := IOTAThread(FThreadRefs[FThreadRefs.Count - 1]);
    FThreadIds.Delete(FThreadIds.Count - 1);
    FThreadRefs.Delete(FThreadRefs.Count - 1);
    FNotifiers.Each(IOTAProcessNotifier, ThreadDestroyedOne, Pointer(T), 'IOTAProcessNotifier.ThreadDestroyed');
    T := nil;
  end;
  while FModuleRefs.Count > 0 do
  begin
    M := IOTAProcessModule(FModuleRefs[FModuleRefs.Count - 1]);
    FModules.Delete(FModules.Count - 1);
    FModuleRefs.Delete(FModuleRefs.Count - 1);
    FNotifiers.Each(IOTAProcessNotifier, ModuleDestroyedOne, Pointer(M), 'IOTAProcessNotifier.ProcessModuleDestroyed');
    M := nil;
  end;
end;

procedure TSdOtaProcess.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  FNotifiers.DropModule(Module);
  for I := 0 to FThreadIds.Count - 1 do TSdOtaThread(FThreadIds.Objects[I]).Notifiers.DropModule(Module);
  for I := 0 to FModules.Count - 1 do TSdOtaProcessModule(FModules.Objects[I]).Notifiers.DropModule(Module);
end;

function TSdOtaProcess.AddNotifier(const Notifier: IOTAProcessNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaProcess.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

{ the thread that stopped last, or the one chosen since (SetCurrentThread, Thread Status) }
function TSdOtaProcess.GetCurrentThread: IOTAThread;
var
  D: TDebugger;
begin
  Sync;
  D := Dbg;
  if (D <> nil) and (D.State = dsPaused) and (D.CurrentThreadId <> 0) then FCurrent := D.CurrentThreadId;
  Result := ThreadObj(FCurrent);
end;

{ the threads of the last stop (also while the program runs on) }
function TSdOtaProcess.GetThreadCount: Integer;
begin
  Sync;
  Result := FThreadRefs.Count;
end;

function TSdOtaProcess.GetThread(Index: Integer): IOTAThread;
begin
  Sync;
  if (Index >= 0) and (Index < FThreadRefs.Count) then Result := IOTAThread(FThreadRefs[Index])
  else Result := nil;
end;

function TSdOtaProcess.GetProcessId: LongWord;
begin
  if (FPid = 0) and (Dbg <> nil) then FPid := Dbg.ProcessId;
  Result := FPid;
end;

function TSdOtaProcess.GetOSProcessId: LongWord;
begin
  Result := GetProcessId;
end;

procedure TSdOtaProcess.Pause;
begin
  if Dbg <> nil then HostCtl.Pause;
end;

{ the bytes from Address on that can be read, up to the first that cannot }
function TSdOtaProcess.ReadProcessMemory(Address: LongWord; Count: Integer; var Buffer): Integer;
var
  D: TDebugger;
  Readable: array of Boolean;
begin
  Result := 0;
  D := Dbg;
  if (D = nil) or (Count <= 0) then Exit;
  SetLength(Readable, Count);
  Result := D.ReadMemoryPaged(Address, Buffer, Count, Readable);
end;

{ page by page, up to the first page that cannot be written }
function TSdOtaProcess.WriteProcessMemory(Address: LongWord; Count: Integer; var Buffer): Integer;
var
  D: TDebugger;
  N: Integer;
begin
  Result := 0;
  D := Dbg;
  if D = nil then Exit;
  while Result < Count do
  begin
    N := $1000 - Integer((Address + Cardinal(Result)) and $FFF);
    if N > Count - Result then N := Count - Result;
    if not D.WriteMemory(Address + Cardinal(Result), PByteArray(@Buffer)^[Result], N) then Break;
    Inc(Result, N);
  end;
end;

{ ormRunToEntry and ormRunToMain are where a program begins: a session that runs already goes on }
procedure TSdOtaProcess.Run(RunMode: TOTARunMode);
var
  C: TDebugController;
begin
  C := HostCtl;
  if (Dbg = nil) or (C = nil) then Exit;
  case RunMode of
    ormRun, ormRunToEntry, ormRunToMain: C.Resume;
    ormStmtStepInto: C.StepInto;
    ormStmtStepOver: C.StepOver;
    ormInstStepInto: C.StepInstruction(False);
    ormInstStepOver: C.StepInstruction(True);
    ormStmtStepToSource: C.TraceToSource;
    ormRunToCursor: OtaHost.ExecuteAction('RunGotoCursorCommand');
  end;
end;

{ the thread the IDE inspects and shows from now on (Thread Status' double click) }
procedure TSdOtaProcess.SetCurrentThread(Value: IOTAThread);
begin
  if (Value = nil) or (Dbg = nil) then Exit;
  if HostCtl.ShowThread(Value.GetOSThreadID) then FCurrent := Value.GetOSThreadID;
end;

procedure TSdOtaProcess.Terminate;
begin
  if Dbg <> nil then HostCtl.Stop;
end;

{ ---------------------------------------------------------------- TSdOtaDebuggerServices }

const
  dnProcessCreated = 0;
  dnProcessDestroyed = 1;
  dnBreakpointAdded = 2;
  dnBreakpointDeleted = 3;

type
  PDebuggerCall = ^TDebuggerCall;
  TDebuggerCall = record
    Kind: Integer;
    Process: IOTAProcess;
    BP: IOTABreakpoint;
  end;

{ the calls of the debugger's and the breakpoints' notifiers (TSdNotifierList.Each) }

procedure DebuggerNotifyOne(const N: IInterface; Data: Pointer);
begin
  with PDebuggerCall(Data)^ do
    case Kind of
      dnProcessCreated: IOTADebuggerNotifier(N).ProcessCreated(Process);
      dnProcessDestroyed: IOTADebuggerNotifier(N).ProcessDestroyed(Process);
      dnBreakpointAdded: IOTADebuggerNotifier(N).BreakpointAdded(BP);
      dnBreakpointDeleted: IOTADebuggerNotifier(N).BreakpointDeleted(BP);
    end;
end;

procedure VerifiedOne(const N: IInterface; Data: Pointer);
begin
  with TDbgBreakpoint(Data) do IOTABreakpointNotifier(N).Verified(Enabled, Valid);
end;

constructor TSdOtaDebuggerServices.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FNotifiers := TSdNotifierList.Create;
  FBPIds := TList.Create;
  FBPValid := TList.Create;
  FBPWraps := TStringList.Create;
  FBPRefs := TInterfaceList.Create;
  Services := Self;
end;

destructor TSdOtaDebuggerServices.Destroy;
var
  T: TDbgTriggerEvent;
  E: TEditBreakpointEvent;
begin
  if Services = Self then Services := nil;
  if HostDbg <> nil then
  begin
    T := HostDbg.OnTrigger;
    if TMethod(T).Data = Self then HostDbg.OnTrigger := nil;
  end;
  if HostCtl <> nil then
  begin
    E := HostCtl.OnEditBreakpoint;
    if TMethod(E).Data = Self then HostCtl.OnEditBreakpoint := nil;
  end;
  FProcess := nil;
  FBPRefs.Free;
  FBPWraps.Free;
  FBPValid.Free;
  FBPIds.Free;
  FNotifiers.Free;
  inherited;
end;

procedure TSdOtaDebuggerServices.Shutdown;
begin
  FNotifiers.DestroyAll('IOTADebuggerNotifier');
end;

procedure TSdOtaDebuggerServices.Hook;
begin
  if HostDbg <> nil then HostDbg.OnTrigger := Trigger;
  if HostCtl <> nil then HostCtl.OnEditBreakpoint := EditBreakpoint;
end;

function TSdOtaDebuggerServices.WrapObj(Id: Cardinal): TObject;
var
  I: Integer;
begin
  I := FBPWraps.IndexOf(IntToStr(Id));
  if I >= 0 then Result := FBPWraps.Objects[I] else Result := nil;
end;

type
  PTriggerResult = ^TOTATriggerResult;
  PEditCall = ^TEditCall;
  TEditCall = record
    KeyChanges, Handled: Boolean;
  end;

{ Delphi's TBaseBreakpoint.NotifyTrigger / NotifyEdit: the first notifier that decides decides,
  the ones after it are not asked }

procedure TriggerOne(const N: IInterface; Data: Pointer);
begin
  if PTriggerResult(Data)^ = trDefault then PTriggerResult(Data)^ := IOTABreakpointNotifier(N).Trigger;
end;

procedure EditOne(const N: IInterface; Data: Pointer);
begin
  with PEditCall(Data)^ do
    if not Handled then Handled := IOTABreakpointNotifier(N).Edit(KeyChanges);
end;

procedure TSdOtaDebuggerServices.Trigger(Sender: TObject; BreakpointId: Cardinal; var Decision: TDbgTrigger);
var
  W: TObject;
  R: TOTATriggerResult;
begin
  W := WrapObj(BreakpointId);
  if W = nil then Exit;
  R := trDefault;
  TSdOtaBreakpoint(W).Notifiers.Each(IOTABreakpointNotifier, TriggerOne, @R, 'IOTABreakpointNotifier.Trigger');
  case R of
    trStop: Decision := tgStop;
    trContinue: Decision := tgContinue;
  end;
end;

function TSdOtaDebuggerServices.EditBreakpoint(BP: TDbgBreakpoint; KeyChanges: Boolean): Boolean;
var
  W: TObject;
  C: TEditCall;
begin
  Result := False;
  W := WrapObj(BP.Id);
  if W = nil then Exit;
  C.KeyChanges := KeyChanges;
  C.Handled := False;
  TSdOtaBreakpoint(W).Notifiers.Each(IOTABreakpointNotifier, EditOne, @C, 'IOTABreakpointNotifier.Edit');
  Result := C.Handled;
end;

function TSdOtaDebuggerServices.Dbg: TDebugger;
begin
  Result := HostDbg;
end;

function TSdOtaDebuggerServices.Wrap(BP: TDbgBreakpoint): IOTABreakpoint;
var
  I: Integer;
  W: TSdOtaBreakpoint;
begin
  Result := nil;
  if BP = nil then Exit;
  I := FBPWraps.IndexOf(IntToStr(BP.Id));
  if I < 0 then
  begin
    W := TSdOtaBreakpoint.Create(BP.Id);
    FBPWraps.AddObject(IntToStr(BP.Id), W);
    I := FBPRefs.Add(IOTABreakpoint(W));
  end;
  Result := IOTABreakpoint(FBPRefs[I]);
end;

procedure TSdOtaDebuggerServices.ForgetBP(Id: Cardinal);
var
  I: Integer;
begin
  I := FBPWraps.IndexOf(IntToStr(Id));
  if I < 0 then Exit;
  FBPWraps.Delete(I);
  FBPRefs.Delete(I);
end;

{ the Index-th source breakpoint, or address one (address, data and module load breakpoints) }
function TSdOtaDebuggerServices.BPOfKind(Address: Boolean; Index: Integer): TDbgBreakpoint;
var
  I, N: Integer;
begin
  Result := nil;
  if Dbg = nil then Exit;
  N := 0;
  for I := 0 to Dbg.BreakpointCount - 1 do
    if (Dbg.Breakpoints[I].Kind <> bkSource) = Address then
    begin
      if N = Index then
      begin
        Result := Dbg.Breakpoints[I];
        Exit;
      end;
      Inc(N);
    end;
end;

procedure TSdOtaDebuggerServices.EachNotifier(Kind: Integer; const Process: IOTAProcess;
  const BP: IOTABreakpoint);
var
  C: TDebuggerCall;
begin
  if FNotifiers.Active = 0 then Exit;
  C.Kind := Kind;
  C.Process := Process;
  C.BP := BP;
  FNotifiers.Each(IOTADebuggerNotifier, DebuggerNotifyOne, @C, 'IOTADebuggerNotifier');
end;

{ a session that begins is a new process, one that ends takes its threads and modules with it;
  the process hears every change of the state (its current thread's notifiers) }
procedure TSdOtaDebuggerServices.StateChanged;
var
  Active: Boolean;
  P: IOTAProcess;
  PO: TSdOtaProcess;
begin
  Active := SessionActive;
  if Active and not FWasActive then
  begin
    FWasActive := True;
    Inc(OtaSession);
    FProcessObj := TSdOtaProcess.Create(OtaSession);
    FProcess := TSdOtaProcess(FProcessObj);
    EachNotifier(dnProcessCreated, FProcess, nil);
  end
  else if not Active and FWasActive then
  begin
    FWasActive := False;
    P := FProcess;
    PO := TSdOtaProcess(FProcessObj);
    FProcess := nil;
    FProcessObj := nil;
    PO.Ended;
    EachNotifier(dnProcessDestroyed, P, nil);
    Inc(OtaSession);
  end;
  if FProcessObj <> nil then TSdOtaProcess(FProcessObj).StateChanged;
end;

procedure TSdOtaDebuggerServices.BreakpointsChanged;
var
  D: TDebugger;
  I, K: Integer;
  B: TDbgBreakpoint;
  Now: TList;
  W: IOTABreakpoint;
begin
  D := Dbg;
  if D = nil then Exit;
  Now := TList.Create;
  try
    for I := 0 to D.BreakpointCount - 1 do Now.Add(Pointer(D.Breakpoints[I].Id));
    { new ones }
    for I := 0 to D.BreakpointCount - 1 do
    begin
      B := D.Breakpoints[I];
      K := FBPIds.IndexOf(Pointer(B.Id));
      { verified in the process, or no longer: IOTABreakpointNotifier.Verified is not told (VerifiedOne),
        as Delphi 7 tells it no expert's notifier (measured) }
      if K < 0 then EachNotifier(dnBreakpointAdded, nil, Wrap(B));
    end;
    { deleted ones: told with the wrapper an expert may hold, which answers empty from now on }
    for I := 0 to FBPIds.Count - 1 do
      if Now.IndexOf(FBPIds[I]) < 0 then
      begin
        K := FBPWraps.IndexOf(IntToStr(Cardinal(FBPIds[I])));
        if K >= 0 then W := IOTABreakpoint(FBPRefs[K])
        else W := TSdOtaBreakpoint.Create(Cardinal(FBPIds[I]));
        EachNotifier(dnBreakpointDeleted, nil, W);
        ForgetBP(Cardinal(FBPIds[I]));
      end;
    FBPIds.Assign(Now);
    FBPValid.Clear;
    for I := 0 to D.BreakpointCount - 1 do FBPValid.Add(Pointer(Ord(D.Breakpoints[I].Valid)));
  finally
    Now.Free;
  end;
end;

procedure TSdOtaDebuggerServices.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  FNotifiers.DropModule(Module);
  for I := 0 to FBPWraps.Count - 1 do
  begin
    TSdOtaBreakpoint(FBPWraps.Objects[I]).Notifiers.DropModule(Module);
    TSdOtaBreakpoint(FBPWraps.Objects[I]).NotifiersChanged;
  end;
  if FProcessObj <> nil then TSdOtaProcess(FProcessObj).DropModule(Module);
end;

function TSdOtaDebuggerServices.AddNotifier(const Notifier: IOTADebuggerNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaDebuggerServices.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

procedure TSdOtaDebuggerServices.AttachProcess(Pid: Integer; const RemoteHost: string);
begin
  if (OtaHost <> nil) and (RemoteHost = '') then OtaHost.DebugAttach(Pid);
end;

{ Delphi 7's (measured): the program stops at its main block's begin; the expert runs it on }
procedure TSdOtaDebuggerServices.CreateProcess(const ExeName, Args: string; const RemoteHost: string);
begin
  if (OtaHost <> nil) and (RemoteHost = '') then OtaHost.DebugRun(ExeName, Args);
end;

procedure TSdOtaDebuggerServices.EnumerateRunningProcesses(Callback: TEnumerateProcessesCallback;
  Param: Pointer; const HostName: string);
var
  Snap: THandle;
  PE: TProcessEntry32;
begin
  if not Assigned(Callback) or (HostName <> '') then Exit;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then Exit;
  try
    PE.dwSize := SizeOf(PE);
    if Process32First(Snap, PE) then
      repeat
        Callback(PE.th32ProcessID, PE.szExeFile, Param);
      until not Process32Next(Snap, PE);
  finally
    CloseHandle(Snap);
  end;
end;

function TSdOtaDebuggerServices.GetAddressBkptCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  if Dbg = nil then Exit;
  for I := 0 to Dbg.BreakpointCount - 1 do
    if Dbg.Breakpoints[I].Kind <> bkSource then Inc(Result);
end;

function TSdOtaDebuggerServices.GetAddressBkpt(Index: Integer): IOTAAddressBreakpoint;
begin
  Supports(Wrap(BPOfKind(True, Index)), IOTAAddressBreakpoint, Result);
end;

function TSdOtaDebuggerServices.GetSourceBkptCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  if Dbg = nil then Exit;
  for I := 0 to Dbg.BreakpointCount - 1 do
    if Dbg.Breakpoints[I].Kind = bkSource then Inc(Result);
end;

function TSdOtaDebuggerServices.GetSourceBkpt(Index: Integer): IOTASourceBreakpoint;
begin
  Supports(Wrap(BPOfKind(False, Index)), IOTASourceBreakpoint, Result);
end;

function TSdOtaDebuggerServices.GetCurrentProcess: IOTAProcess;
begin
  Result := FProcess;
end;

function TSdOtaDebuggerServices.GetProcessCount: Integer;
begin
  if FProcess <> nil then Result := 1 else Result := 0;
end;

function TSdOtaDebuggerServices.GetProcess(Index: Integer): IOTAProcess;
begin
  if Index = 0 then Result := FProcess else Result := nil;
end;

procedure TSdOtaDebuggerServices.LogString(const LogStr: string);
begin
  if HostCtl <> nil then HostCtl.AddLog(LogStr);
end;

{ in the colours of the Event Log's kind of message (Debugger Options | Event Log), shown when it
  shows that kind }
procedure TSdOtaDebuggerServices.LogString(const LogStr: string; LogItemType: TLogItemType);
const
  Kinds: array[TLogItemType] of TEventKind = (ekComment, ekOutput, ekWindow, ekWindow, ekProcess, ekProcess,
    ekProcess, ekBreakpoint, ekBreakpoint, ekBreakpoint, ekProcess, ekProcess, ekThread, ekThread, ekModule,
    ekModule, ekProcess);
begin
  if HostCtl <> nil then HostCtl.AddLogAs(LogStr, Kinds[LogItemType]);
end;

function TSdOtaDebuggerServices.NewBP(Settings: TDbgBreakpoint): IOTABreakpoint;
var
  B: TDbgBreakpoint;
begin
  Result := nil;
  if Dbg = nil then Exit;
  B := Dbg.AddBreakpointAs(Settings);
  if OtaHost <> nil then OtaHost.BreakpointsChanged;
  Result := Wrap(B);
end;

function TSdOtaDebuggerServices.NewAddressBreakpoint(Address, Length: LongWord;
  AccessType: TOTAAccessType; AProcess: IOTAProcess): IOTABreakpoint;
var
  S: TDbgBreakpoint;
begin
  S := TDbgBreakpoint.Create;
  try
    if AccessType = atExecute then S.Kind := bkAddress else S.Kind := bkData;
    S.DataRead := AccessType = atRead;
    S.Address := Address;
    if Length in [1, 2, 4] then S.DataLength := Length else S.DataLength := 4;
    S.Enabled := True;
    S.DoBreak := True;
    Result := NewBP(S);
  finally
    S.Free;
  end;
end;

function TSdOtaDebuggerServices.NewModuleBreakpoint(const ModuleName: string;
  AProcess: IOTAProcess): IOTABreakpoint;
var
  S: TDbgBreakpoint;
begin
  S := TDbgBreakpoint.Create;
  try
    S.Kind := bkModule;
    S.FileName := ModuleName;
    S.Enabled := True;
    S.DoBreak := True;
    Result := NewBP(S);
  finally
    S.Free;
  end;
end;

function TSdOtaDebuggerServices.NewSourceBreakpoint(const FileName: string; LineNumber: Integer;
  AProcess: IOTAProcess): IOTABreakpoint;
var
  B: TDbgBreakpoint;
begin
  Result := nil;
  if Dbg = nil then Exit;
  B := Dbg.FindBreakpoint(FileName, LineNumber);
  if B = nil then
  begin
    B := Dbg.AddBreakpoint(FileName, LineNumber);
    if OtaHost <> nil then OtaHost.BreakpointsChanged;
  end;
  Result := Wrap(B);
end;

procedure TSdOtaDebuggerServices.SetCurrentProcess(Process: IOTAProcess);
begin
end;

end.
