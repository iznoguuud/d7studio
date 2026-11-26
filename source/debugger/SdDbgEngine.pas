{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDbgEngine;

{ D7 Studio debugger - native Win32 debugger engine for Delphi 7 executables.

  TDebugger launches a program under the Win32 debug API on a dedicated thread,
  manages breakpoints, source-line stepping, exceptions, call stacks and
  expression evaluation.  All events are delivered in the thread that created
  the TDebugger (through a hidden message window), so the creating thread must
  pump messages.

  Symbols come from SdDbgTD32 (TD32 info embedded with dcc32 -V, or a detailed
  .map file as fallback), expressions are evaluated by SdDbgEval.

  Notes for the host (IDE):
    * Build the debuggee with  dcc32 -V  (TD32 info; add -$D+ -$L+, and -$O- -$W+ for
      reliable locals).  Without -V a .map file next to the EXE (-GD) still gives
      breakpoints, stepping and call stacks, but no variables.
    * Fill SourceDirs (project directory, search path, Delphi source directories)
      before Start: file names in the debug info are relative ('Unit1.pas',
      'sub\Unit2.pas') or stale absolute paths of the machine that built the DCUs.
      File names given to AddBreakpoint also help to locate sources.
    * Control methods are asynchronous.  Typical sequence of events:
        Start -> OnStateChange(dsRunning) ... OnStateChange + OnStop(reason, frame, msg)
        Resume/Step* -> OnStateChange(dsRunning) ... OnStop ...  -> OnStateChange + OnExit
      OnLog carries the event-log lines.  Do not free the TDebugger inside one of its
      own event handlers.
    * At a stop CurrentFrame is set to StopFrameIndex: the innermost frame that has
      source (frame 0 unless the program stopped inside code without line numbers,
      e.g. an exception raised by the RTL or a paused GUI program).
    * Exceptions: Delphi exceptions stop when StopOnDelphiExceptions is set, CPU faults
      (access violation, division by zero ...) when StopOnOSExceptions is set; both
      honour IgnoredExceptions (class names).  Resuming passes the exception on to the
      program.  A step command given at an exception stop runs to the except/finally
      block that receives it (the RTL reports that through System.DebugHook, which the
      engine switches on in every module that has one).
    * A stop on a line - breakpoint, step, run to cursor, the entry - is at the first
      instruction of its code, before any of it runs, as in Delphi 7.  A 'begin' line has
      code only when the routine has a prologue (frame, saved registers, managed locals):
      stopped there, parameters and locals that live in the frame are not set up yet, and a
      condition there reads them so too.  Without a prologue the routine's first line record
      is its first statement (Delphi 7's DebugStart then lies after that statement, so it
      does not mark the end of a prologue). }

interface

uses
  Windows, Messages, SysUtils, Classes, SdDbgTD32, SdDbgDisasm, SdDbgEval;

type
  TDbgState = (dsNone, dsRunning, dsPaused);
  TDbgStopReason = (srNone, srEntry, srBreakpoint, srStep, srPause, srException, srRunToLine);
  TDbgLogKind = (lkProcess, lkThread, lkModule, lkDebugString, lkException, lkBreakpoint);

  { how an OS exception code is treated (the IDE's Debugger Options | OS Exceptions): Stop
    (handled by the debugger) or not (the program's), and resumed as handled or unhandled }
  TDbgOSRule = record
    Low, High: Cardinal;
    Stop: Boolean;
    RunHandled: Boolean;
  end;

  TDbgFrame = record
    Address: Cardinal;       // current EIP for frame 0, return address for callers
    FrameBase: Cardinal;     // EBP of the frame (0 if unknown)
    ProcName: string;        // e.g. 'Unit1.TForm1.Button1Click'; '' if unknown
    ModuleName: string;      // exe/dll file name
    FileName: string;        // full path when resolvable through SourceDirs, else the name from the debug info
    Line: Integer;           // 0 if none
  end;
  TDbgFrameArray = array of TDbgFrame;

  TDbgVar = SdDbgEval.TDbgVar;
  TDbgVarArray = SdDbgEval.TDbgVarArray;

  TDbgThreadInfo = record
    ThreadId: Cardinal;
    Location: string;
    IsCurrent: Boolean;
  end;
  TDbgThreadArray = array of TDbgThreadInfo;

  TDbgModuleInfo = record
    Name: string;
    BaseAddr: Cardinal;
    HasDebugInfo: Boolean;
    Path: string;
    Size: Cardinal;
  end;
  TDbgModuleArray = array of TDbgModuleInfo;

  TDbgUnitFiles = record
    Name: string;
    Files: array of string;
  end;

  TDbgInspection = record
    ThreadId: Cardinal;
    Frame: Integer;
    Overridden: Boolean;
    EIP, EBP, ESP: Cardinal;
  end;

  TDbgModuleDetails = record
    EntryPoint: Cardinal;              // the address of its first instruction (0: none)
    Units: array of TDbgUnitFiles;     // its compilation units and their source files (debug information)
    Files: array of string;            // every source file of its debug information
    EntryNames: array of string;       // its routines (debug information), else its exports by name ...
    EntryAddrs: array of Cardinal;     // ... and their addresses
  end;

  TDbgRegisters = record
    EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP, EIP, EFlags: Cardinal;
    CS, DS, ES, FS, GS, SS: Cardinal;
  end;

  { an instruction of the program (DecodeAt): its address, its bytes, its text }
  TDbgInstr = record
    Addr: Cardinal;
    Len: Integer;
    Bytes: array[0..15] of Byte;
    Text: string;
  end;
  TDbgInstrArray = array of TDbgInstr;

  { the FPU of the current thread (the CPU's floating point state): ST0..ST7 in stack order }
  TDbgFPU = record
    Control, Status, Tag: Word;
    ErrorOffset, ErrorSelector, DataOffset, DataSelector: Cardinal;
    ST: array[0..7] of Extended;
  end;

  { Delphi's four kinds: a source line, a code address, a write to data (a hardware breakpoint of
    the processor; at most four are active, and they end with the process), the load of a module }
  TDbgBPKind = (bkSource, bkAddress, bkData, bkModule);

  TDbgBreakpoint = class
  public
    Kind: TDbgBPKind;
    FileName: string;        // source: full path as given by the IDE; module load: the module
    Line: Integer;           // source
    Address: Cardinal;       // address: the code; data: the data
    DataLength: Integer;     // data: 1, 2 or 4 bytes (aligned to it)
    DataRead: Boolean;       // data: a read of it traps as well (the processor watches reads only with writes)
    Enabled: Boolean;
    Condition: string;       // '' = unconditional; break when the expression is True / non-zero
    PassCount: Integer;      // 0 = break every time; N = break on every Nth pass
    { the passes since the last stop, as Delphi 7 counts them (the Open Tools API's CurPassCount):
      1 at the first hit, PassCount at the stop, 1 again at the hit after it }
    HitCount: Integer;
    Valid: Boolean;          // resolved to a code address in the running process
    Group: string;
    { what a hit does - Delphi's actions: break (else the program goes on), ignore or report the
      exceptions that follow, log a message, evaluate an expression (and log its value), enable
      or disable the breakpoints of a group }
    DoBreak: Boolean;
    IgnoreExceptions, HandleExceptions: Boolean;
    LogMessage, EvalExpr: string;
    LogResult: Boolean;
    EnableGroup, DisableGroup: string;
    { data: the expression of the watch whose Break When Changed set it (Delphi's data watch:
      the Watch List finds it by that expression) - '' for any other breakpoint }
    Watch: string;
    { this breakpoint and no other (the constructor's; Assign leaves it): one made later at the
      same address is not the one whose condition the debug thread evaluated meanwhile }
    Id: Cardinal;
    { the IDE decides its hits first (OnTrigger); not a setting - Assign leaves it; written under
      the engine's lock }
    AskTrigger: Boolean;
    constructor Create;
    procedure Assign(Src: TDbgBreakpoint);   // the settings (not the hit count, not Valid)
  end;

  TDbgNotifyEvent = procedure(Sender: TObject) of object;
  { the IDE's answer to a hit of a breakpoint that asks (AskTrigger): its default processing
    (condition, pass count, actions), a stop, or on without either }
  TDbgTrigger = (tgDefault, tgStop, tgContinue);
  TDbgTriggerEvent = procedure(Sender: TObject; BreakpointId: Cardinal; var Decision: TDbgTrigger) of object;
  TDbgStopEvent = procedure(Sender: TObject; Reason: TDbgStopReason; const Frame: TDbgFrame;
    const Msg: string) of object;
  TDbgLogEvent = procedure(Sender: TObject; Kind: TDbgLogKind; const Text: string) of object;
  TDbgExitEvent = procedure(Sender: TObject; ExitCode: Cardinal) of object;
  TDbgErrorEvent = procedure(Sender: TObject; E: Exception) of object;

  { an exception the debug thread caught to go on, reported in the host's thread (OnError): its
    message names the original's class and message }
  EDbgThreadError = class(Exception);

  { ---- internal types (not part of the public API) ---- }

  TDbgCmd = (dcNone, dcResume, dcStepOver, dcStepInto, dcStepOut, dcRunToLine, dcStepInstr,
    dcStepInstrOver, dcTraceSource, dcDetach, dcCall);

  { a process the program started (Debug spawned processes) }
  TDbgChild = class
  public
    Pid: Cardinal;
    Name: string;
    Handle: THandle;
    SeenBP: Boolean;           // its loader breakpoint went by
  end;

  TDbgThread = class
  public
    ThreadId: Cardinal;
    Handle: THandle;
    TLB: Cardinal;
    StartAddr: Cardinal;
    AtBP: Cardinal;            // stopped on our breakpoint at this address (lift it when resuming)
    SteppingOverBP: Cardinal;  // breakpoint address lifted for one single step
    ReRaise: Boolean;          // the next Delphi exception is a re-raise
    OSExcReported: Boolean;    // raw OS exception already reported
    LastExcObj: Cardinal;      // exception object of the last reported language exception
    SuspendCount: Integer;     // suspended by the engine
    HeldByCall: Boolean;       // a call on it did not return: held (one of SuspendCount) until the program goes on
  end;

  TDbgModule = class
  public
    Base, Size: Cardinal;
    Name, Path: string;
    Info: TTD32Info;           // nil when there is no debug information
    OwnsInfo: Boolean;
    ExecLo, ExecHi: array[0..7] of Cardinal;
    ExecCount: Integer;
    SrcPaths: TStringList;     // resolved source file names (index = source file index)
    ExpLoaded: Boolean;        // export table (used for names when there is no debug info)
    ExpByName: array of Cardinal;   // name RVAs in the PE's (name sorted) order
    ExpOrd: array of Word;
    ExpFuncs: array of Cardinal;    // function RVAs by ordinal index
    ExpKeys: TStringList;           // 'TClass@Method' of the Delphi exports (Objects: the name index), sorted
    ExpAddr: array of Cardinal;     // function RVAs sorted by address ...
    ExpAddrName: array of Cardinal; // ... and their name RVAs
    { ... and their names, read from the process once (ExportName): '' not read yet, a name read
      ends in #0 (also one that could not be read) }
    ExpAddrNames: array of string;
    destructor Destroy; override;
  end;

  TBPLoc = class
  public
    Addr: Cardinal;
    OrigByte: Byte;
    Installed: Boolean;
    UserBPs: TList;
    TempRefs: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TTempCheck = (tcNone, tcESP, tcEBP);
  TTempPurpose = (tpStepOverCall, tpStepReturn, tpStepOut, tpHandler, tpRunTo, tpRangeExit, tpRangeRet,
    tpEntry);
  TTempBP = record
    Addr: Cardinal;
    ThreadId: Cardinal;
    Check: TTempCheck;
    Limit: Cardinal;
    Purpose: TTempPurpose;
  end;

  TStepKind = (skNone, skOver, skInto, skOut, skInstr, skSource);
  TStepState = record
    Active: Boolean;
    Kind: TStepKind;
    ThreadId: Cardinal;
    ExpectSS: Boolean;
    RangeLo, RangeHi: Cardinal;
    StartLine, StartSrc: Integer;
    StartInfo: TTD32Info;
    StartEBP: Cardinal;
    LastWasRet: Boolean;
    InCall: Boolean;
    CallRet, CallESP: Cardinal;
    ThunkHops: Integer;
    AwaitHandler: Boolean;
    Steps: Integer;            // single steps taken inside the current line range
    RangeTried: Boolean;
    Passive: Boolean;          // only waiting to get back into code with line numbers
    PassiveTick: Cardinal;
  end;

  TFrameEx = record
    Addr: Cardinal;
    EBP: Cardinal;
    ESP: Cardinal;
    RetLoc: Cardinal;
  end;
  TFrameExArray = array of TFrameEx;

  TDebugger = class
  private
    FWnd: HWND;
    FLock: TRTLCriticalSection;
    FQueueLock: TRTLCriticalSection;
    FQueue: TList;
    FMsgPosted: Boolean;
    FWorker: TThread;
    FStartEvent: THandle;
    FCmdEvent: THandle;
    FStartResult: Boolean;
    FState: TDbgState;
    FLastError: string;
    FSourceDirs: TStringList;
    FSrcDirs: TStringList;           // snapshot used by the session
    FIgnored: TStringList;
    FIgnoreAll: Boolean;           // a breakpoint's 'Ignore subsequent exceptions'
    FDataSlots: array[0..3] of TDbgBreakpoint;   // the data breakpoints in debug registers 0-3
    FDataDirty: Boolean;           // the data breakpoints changed: the registers follow at the next event
    FAttachPid: Cardinal;          // Attach: the process (0: the session starts its program)
    FDetachRequested: Boolean;     // Detach while it ran: the pause that serves it detaches
    FDetaching: Boolean;           // the debug loop lets the process go after this event
    FDetached: Boolean;            // the session that ended was detached
    FDebugSpawned: Boolean;
    FChildren: TList;              // TDbgChild
    { function calls of the evaluator (DoCall) }
    FContPid, FContTid: Cardinal;  // the debug event that is pending (ContinueDebugEvent)
    FEventPending: Boolean;        // ... there is one (a call that did not return took it)
    FCalled: Boolean;              // a call ran: the pending event is the one that ended it
    FInCall: Boolean;
    FCallStub: Cardinal;           // two int 3 in the program: where a call returns, its exception handler
    FCallDone: THandle;
    FCallThread: TDbgThread;
    FCallAddr, FCallEAX, FCallEDX: Cardinal;
    FCallRegs, FCallStack: array of Cardinal;
    FCallST0: Extended;
    FCallOk: Boolean;
    FCallError: string;
    FStopOnDelphi: Boolean;
    FStopOnOS: Boolean;
    FOSRules: array of TDbgOSRule;
    FShowWindowCmd: Integer;
    FExeName, FParams, FWorkDir: string;
    FExeInfo: TTD32Info;
    FProcessHandle, FMainThreadHandle: THandle;
    FProcessId, FMainThreadId: Cardinal;
    FExitCode: Cardinal;
    FThreads: TList;
    FModules: TList;
    FBreakpoints: TList;
    FLocs: TList;
    FTemps: array of TTempBP;
    FStep: TStepState;
    FStepStopReason: TDbgStopReason;
    FPendingCmd: TDbgCmd;
    FRunToFile: string;
    FRunToLine: Integer;
    FTerminating: Boolean;
    FProcessGone: Boolean;
    FSeenInitialBP: Boolean;
    FPauseRequested: Boolean;
    FPauseFallback: Boolean;
    FPauseTick: Cardinal;
    FBreakInPending: Boolean;
    FBreakInThreadId: Cardinal;
    FEventThreadId: Cardinal;
    FCurThread: TDbgThread;
    FCurrentFrame: Integer;
    FStopFrameIndex: Integer;
    FMachineStep: Boolean;      // the last command stepped one instruction (the CPU view)
    FStopIsException: Boolean;
    FStopFault: Boolean;
    FStopExcThreadId: Cardinal;
    FOverrideCtx: Boolean;
    FOvEIP, FOvEBP, FOvESP: Cardinal;
    FFrames: TFrameExArray;
    FFramesValid: Boolean;
    FStopSeq: Integer;
    FStandCount: Integer;
    FPauseByBreakIn: Boolean;
    FStopAtEntry: Boolean;
    FEnvironment: string;
    FSessStopAtEntry: Boolean;       // latched by Start
    FOnStateChange: TDbgNotifyEvent;
    FOnStop: TDbgStopEvent;
    FOnLog: TDbgLogEvent;
    FOnExit: TDbgExitEvent;
    FOnBreakpointsChanged: TDbgNotifyEvent;
    FOnError: TDbgErrorEvent;
    FOnTrigger: TDbgTriggerEvent;
    FTrigger: TDbgTrigger;
    function AskTrigger(Id: Cardinal; T: TDbgThread): TDbgTrigger;
    procedure QueueBPsChanged;
    procedure QueueError(const Where: string; E: Exception);
    procedure ReportError(E: Exception);
    function GetSourceDirs: TStrings;
    function GetIgnored: TStrings;
    function GetBreakpoint(Index: Integer): TDbgBreakpoint;
    procedure SetCurrentFrame(Value: Integer);
    procedure WndProc(var Msg: TMessage);
    procedure DispatchEvents;
    procedure Enqueue(Item: TObject);
    procedure QueueState;
    procedure QueueLog(Kind: TDbgLogKind; const Text: string);
    { debug thread }
    procedure ThreadMain;
    procedure DebugLoop;
    procedure EndSession;
    procedure ReleaseHeld;
    procedure RunningAgain;
    function LaunchProcess: Boolean;
    procedure SessionCleanup;
    procedure IdleTick;
    procedure HandleEvent(var DE: TDebugEvent; var Cont: Cardinal);
    procedure HandleException(var DE: TDebugEvent; var Cont: Cardinal);
    procedure HandleBreakpointHit(T: TDbgThread; Addr: Cardinal; var Cont: Cardinal);
    procedure HandleSingleStep(T: TDbgThread; var Cont: Cardinal);
    procedure HandleDelphiException(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
    procedure HandleDelphiNotify(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
    procedure HandleOSException(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
    function ExcLogText(const Head, Cls, Msg: string): string;
    function ExcStopText(const How, Cls, Msg, Tail: string): string;
    procedure DoStop(Reason: TDbgStopReason; T: TDbgThread; const Msg: string; Fault: Boolean = False);
    function WaitForCommand: TDbgCmd;
    function WaitServingCalls: TDbgCmd;
    procedure ForgetFrames;
    procedure PostCommand(Cmd: TDbgCmd);
    procedure SyntheticPause;
    { threads / modules }
    function FindThread(Id: Cardinal): TDbgThread;
    function MainThread: TDbgThread;
    function AddModule(Base: Cardinal; const Path: string; Info: TTD32Info; OwnsInfo: Boolean): TDbgModule;
    function ModuleByAddr(Addr: Cardinal): TDbgModule;
    procedure RemoveModule(Base: Cardinal);
    function ModuleFileFromHandle(H: THandle): string;
    procedure SetDebugHook(M: TDbgModule; Value: Byte = 2);
    procedure LoadExports(M: TDbgModule);
    function FindExport(M: TDbgModule; const Name: string): Cardinal;
    procedure ExportKeys(M: TDbgModule);
    function ExportName(M: TDbgModule; I: Integer): string;
    function ExportNameAt(M: TDbgModule; Addr: Cardinal): string;
    function ReadCStrRaw(Addr: Cardinal; MaxLen: Integer): string;
    procedure SuspendOthers(T: TDbgThread);
    procedure ResumeOthers(T: TDbgThread);
    procedure ResumeAll(T: TDbgThread);
    procedure EndLift(T: TDbgThread);
    procedure HoldForCall(O: TDbgThread);
    procedure CallOtherException(var DE: TDebugEvent; var Cont: Cardinal);
    { memory / context }
    function ReadMemRaw(Addr: Cardinal; var Buf; Size: Integer): Boolean;
    function WriteMemRaw(Addr: Cardinal; const Buf; Size: Integer): Boolean;
    function WriteCodeByte(Addr: Cardinal; B: Byte): Boolean;
    function GetCtx(T: TDbgThread; var Ctx: TContext): Boolean;
    function SetCtx(T: TDbgThread; var Ctx: TContext): Boolean;
    procedure SetEIP(T: TDbgThread; EIP: Cardinal);
    procedure ClearTrapFlag(T: TDbgThread);
    function NewEvaluator(T: TDbgThread; EIP, EBP: Cardinal; Top: Boolean): TDbgEvaluator;
    function FrameEvaluator: TDbgEvaluator;
    function ReadClassNameOf(Obj: Cardinal): string;
    function ReadExceptionMessage(Obj: Cardinal): string;
    { symbols }
    function IsCodeAddr(Addr: Cardinal): Boolean;
    function IsReturnAddr(Addr: Cardinal; out CallTarget: Cardinal): Boolean;
    function ThunkTarget(Addr: Cardinal): Cardinal;
    function FindProcStart(Addr: Cardinal; out ProcStart: Cardinal; out Framed: Boolean): Boolean;
    function FindLineAbs(Addr: Cardinal; out M: TDbgModule; out L: TTDLine): Boolean;
    function HasLineAbs(Addr: Cardinal): Boolean;
    function ResolveSource(M: TDbgModule; Src: Integer): string;
    function MatchSource(M: TDbgModule; Src: Integer; const FileName, Name, CompName: string; Exact: Boolean): Boolean;
    function LineAddrs(const FileName: string; Line: Integer; out Addrs: TCardinalArray): Boolean;
    function LocationOf(Addr: Cardinal; out Frame: TDbgFrame): Boolean;
    function ExeBaseName: string;
    { stack }
    function WalkStack(T: TDbgThread; EIP, EBP, ESP: Cardinal; Max: Integer): TFrameExArray;
    function CurFrames: TFrameExArray;
    function FrameToPublic(const F: TFrameEx; Index: Integer): TDbgFrame;
    function FirstSourceFrame(const Fx: TFrameExArray): Integer;
    { breakpoints }
    function FindLoc(Addr: Cardinal): TBPLoc;
    function GetLoc(Addr: Cardinal): TBPLoc;
    procedure UpdateLoc(Loc: TBPLoc);
    procedure PlaceBP(BP: TDbgBreakpoint; Addr: Cardinal);
    procedure ResolveBP(BP: TDbgBreakpoint);
    procedure UnresolveBP(BP: TDbgBreakpoint);
    procedure ResolveAllBPs;
    procedure ResolveBPsIn(M: TDbgModule);
    procedure RemoveLocsInRange(Lo, Hi: Cardinal);
    function HasEnabledBP(Loc: TBPLoc): Boolean;
    function EnabledBPAt(Addr: Cardinal): Boolean;
    function UserBPShouldStop(Addr: Cardinal; T: TDbgThread): Boolean;
    function BPStops(BP: TDbgBreakpoint; T: TDbgThread): Boolean;
    function DefaultHit(BP: TDbgBreakpoint; Id: Cardinal; const Cond: string; T: TDbgThread): Boolean;
    procedure SetGroups(const EnableGroup, DisableGroup: string);
    function EvalText(T: TDbgThread; const Expr: string): string;
    function ReportsException(const Cls: string): Boolean;
    function HasBPKind(Kind: TDbgBPKind): Boolean;
    procedure ApplyDataBPs;
    function BeginSession(const ExeName, Params, WorkDir: string; AttachPid: Cardinal): Boolean;
    function AttachProcess: Boolean;
    procedure PrepareDetach;
    procedure DetachProcesses;
    procedure HandleChildEvent(var DE: TDebugEvent; var Cont: Cardinal);
    function FindChild(Pid: Cardinal): TDbgChild;
    function DoCall(T: TDbgThread; Addr: Cardinal; const Regs, Stack: array of Cardinal; out EAX, EDX: Cardinal;
      out ST0: Extended; out Error: string): Boolean;
    procedure ServeCall;
    function DataHit(T: TDbgThread; out BP: TDbgBreakpoint; out Traced: Boolean): Boolean;
    function DataBPStops(BP: TDbgBreakpoint; T: TDbgThread; out Msg: string): Boolean;
    function ModuleBPStops(const Path: string; T: TDbgThread): Boolean;
    procedure AddTemp(Addr, ThreadId: Cardinal; Check: TTempCheck; Limit: Cardinal; Purpose: TTempPurpose);
    procedure RemoveTemp(Index: Integer);
    procedure ClearTemps;
    procedure ClearStep;
    function FindTemp(Addr: Cardinal; T: TDbgThread; const Ctx: TContext): Integer;
    { stepping }
    procedure Arm(T: TDbgThread; WantSS: Boolean);
    function BeginStep(T: TDbgThread; Kind: TStepKind; out WantSS: Boolean): Boolean;
    procedure BeginStepOut(T: TDbgThread);
    function StepInstr(T: TDbgThread; const Ctx: TContext): Boolean;
    function StepAdvance(T: TDbgThread; out WantSS: Boolean): Boolean;
    procedure StepOn(T: TDbgThread);
    function SetupReturnToLineInfo(T: TDbgThread): Boolean;
    function IsThunkInstr(Addr: Cardinal): Boolean;
    function SetupRangeRun(T: TDbgThread; const Ctx: TContext): Boolean;
    function EvalCondition(T: TDbgThread; const Cond: string): Boolean;
  public
    constructor Create;                  // must be created in the UI thread (allocates a hidden message window)
    destructor Destroy; override;        // terminates a live debuggee and joins the thread
    // configuration
    property SourceDirs: TStrings read GetSourceDirs;
    property StopOnDelphiExceptions: Boolean read FStopOnDelphi write FStopOnDelphi;
    property StopOnOSExceptions: Boolean read FStopOnOS write FStopOnOS;
    property IgnoredExceptions: TStrings read GetIgnored;
    { the rules for OS exception codes; a code without one: StopOnOSExceptions for the faults
      the engine names, the program's for the others; set before Start }
    procedure SetOSRules(const Rules: array of TDbgOSRule);
    property LastError: string read FLastError;
    { nCmdShow passed to the debuggee (console window / main form); -1 = default }
    property ShowWindowCmd: Integer read FShowWindowCmd write FShowWindowCmd;
    { True (default): Pause injects a break-in thread (DebugBreakProcess) and falls back to
      freezing the threads if that does not get through; False: always freeze the threads }
    property PauseByBreakIn: Boolean read FPauseByBreakIn write FPauseByBreakIn;
    { True: the next Start stops with srEntry on the begin line of the program's main block
      (what F7/F8 do in the Delphi IDE when no program is running); default False }
    property StopAtEntry: Boolean read FStopAtEntry write FStopAtEntry;
    { the environment block of the next Start ("A=1"#0"B=2"#0#0), '' = the IDE's own }
    property Environment: string read FEnvironment write FEnvironment;
    // control (asynchronous: they return immediately; results arrive through the events)
    function Start(const ExeName, Params, WorkDir: string): Boolean;
    { Run | Attach to Process: a session with a running 32-bit process (its debug information from
      its executable); the program runs on }
    function Attach(ProcessId: Cardinal): Boolean;
    { Run | Detach From Program: the breakpoints out, the process runs on without the debugger
      (while it runs, a pause serves it first) }
    procedure Detach;
    property Detached: Boolean read FDetached;           // the session that ended was detached
    function Attached: Boolean;                          // the session is an attached one
    { Debugger Options | Debug spawned processes: the processes the program starts are debugged
      too - their start, exit and debug strings in the log; their exceptions are their own }
    property DebugSpawned: Boolean read FDebugSpawned write FDebugSpawned;
    { the evaluator's calls of the program's code (TEngineHost): on thread T of the stopped program,
      by the debug thread; FindCode: a method's or routine's code among the packages' exports }
    function CallCode(T: TDbgThread; Addr: Cardinal; const Regs, Stack: array of Cardinal;
      out EAX, EDX: Cardinal; out ST0: Extended; out Error: string): Boolean;
    function FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal;
    procedure Resume;
    procedure Pause;
    procedure Stop;
    procedure StepOver;
    procedure StepInto;
    procedure StepOut;
    procedure RunToLine(const FileName: string; Line: Integer);
    // breakpoints (may be changed in any state; kept across runs)
    function AddBreakpoint(const FileName: string; Line: Integer): TDbgBreakpoint;
    { a breakpoint of any kind with the settings of Settings (the caller keeps Settings) }
    function AddBreakpointAs(Settings: TDbgBreakpoint): TDbgBreakpoint;
    procedure RemoveBreakpoint(BP: TDbgBreakpoint);
    function FindBreakpoint(const FileName: string; Line: Integer): TDbgBreakpoint;
    procedure ClearBreakpoints;
    procedure BreakpointChanged(BP: TDbgBreakpoint);
    { the settings of a breakpoint, changed under the engine's lock (the debug thread reads them
      while the program runs) and applied at once - the host writes them only this way }
    procedure ChangeBreakpoint(BP: TDbgBreakpoint; ALine: Integer; AEnabled: Boolean;
      const ACondition: string; APassCount: Integer);
    procedure ChangeBreakpointTo(BP, Settings: TDbgBreakpoint);   // every setting, as ChangeBreakpoint
    { BP enabled or disabled, its other settings as they are (ChangeBreakpoint) }
    procedure SetBreakpointEnabled(BP: TDbgBreakpoint; Value: Boolean);
    { the lock of the breakpoints' state that the debug thread changes while the program runs
      (HitCount): held around reading or writing it from the IDE's thread }
    procedure Lock;
    procedure Unlock;
    function BreakpointCount: Integer;
    property Breakpoints[Index: Integer]: TDbgBreakpoint read GetBreakpoint;
    function BreakpointById(Id: Cardinal): TDbgBreakpoint;   // nil: there is none (any more)
    // debug-info queries (valid once a process is loaded)
    function HasDebugInfo: Boolean;
    // inspection (valid in dsPaused)
    function GetCallStack(out Frames: TDbgFrameArray): Boolean;
    property CurrentFrame: Integer read FCurrentFrame write SetCurrentFrame;
    { index of the frame reported in OnStop (first frame that has source); CurrentFrame is
      reset to this value at every stop }
    property StopFrameIndex: Integer read FStopFrameIndex;
    { the stop (srException) is an exception of the operating system that the program did not
      handle: the process ends when it goes on (Delphi's "faulted") }
    property StopFault: Boolean read FStopFault;
    { the times the program stood for the IDE (a stop, a breakpoint's OnTrigger): what was read of it
      while it stood (its threads, its modules) is that of the last one }
    property StandCount: Integer read FStandCount;
    function GetLocals(out Vars: TDbgVarArray): Boolean;
    { AllowCalls: methods, routines and properties read by a method are called (Evaluate/Modify,
      the Debug Inspector, a watch with Allow Function Calls - the parts of such a value too; not for
      hints, which must not run code) }
    function Evaluate(const Expr: string; out V: TDbgVar; out Error: string; AllowCalls: Boolean = False): Boolean;
    function GetChildren(const Expr: string; out Vars: TDbgVarArray; AllowCalls: Boolean = False): Boolean;
    function GetMembers(const Expr: string; Dynamic: Boolean; out Methods, Props: TDbgVarArray): Boolean;   // the Debug Inspector's
    { the value of Expr (Evaluate), the rows of its parts when it has some (GetChildren), its methods
      and properties (GetMembers) from one evaluation with calls - a method on its path runs once
      (the Debug Inspector's) }
    function Inspect(const Expr: string; Dynamic: Boolean; out V: TDbgVar; out Children, Methods,
      Props: TDbgVarArray; out Error: string): Boolean;
    { Expr's truth in the frame inspected, decided as a breakpoint's condition is (zero, False, nil:
      false); the program's code may be called }
    function EvalBoolean(const Expr: string; out Value: Boolean; out Error: string): Boolean;
    function Modify(const Expr, NewValue: string; out Error: string; AllowCalls: Boolean = False): Boolean;
    { Places False: the threads without their places (no stack walk) }
    function GetThreads(out Threads: TDbgThreadArray; Places: Boolean = True): Boolean;
    function GetModules(out Modules: TDbgModuleArray): Boolean;
    function GetRegisters(out R: TDbgRegisters): Boolean;
    function GetFPU(out F: TDbgFPU): Boolean;
    { the source line of a code address: its file, line, and whether the line begins there }
    function SourceLineAt(Addr: Cardinal; out FileName: string; out Line: Integer; out Exact: Boolean): Boolean;
    { the code of the source line that holds Addr: where it begins, how many bytes it has }
    function LineCodeAt(Addr: Cardinal; out Start, Size: Cardinal): Boolean;
    { the units, source files, entry point and routines of the module loaded at Base (dsPaused
      only): the Open Tools API's IOTAProcessModule }
    function GetModuleDetails(Base: Cardinal; out D: TDbgModuleDetails): Boolean;
    { the CPU view's F7 / F8: one machine instruction (Over: a CALL runs to its return) }
    procedure StepInstruction(Over: Boolean);
    { Run | Trace to Next Source Line (Shift+F7): on, through code without source as well, until
      an instruction that begins a source line }
    procedure TraceToSource;
    function ReadMemory(Addr: Cardinal; var Buf; Size: Integer): Boolean;
    { Size bytes at Addr page by page: Readable[I] whether byte I could be read (a page that cannot
      be read does not take the others with it); the result is the number of bytes from Addr on
      that could be read, up to the first that could not }
    function ReadMemoryPaged(Addr: Cardinal; var Buf; Size: Integer; var Readable: array of Boolean): Integer;
    function WriteMemory(Addr: Cardinal; const Buf; Size: Integer): Boolean;
    { Count instructions from Addr - fewer where the memory that can be read ends (no instruction
      is decoded from bytes that could not be read); the CPU view and Disassemble use it }
    function DecodeAt(Addr: Cardinal; Count: Integer; out Instrs: TDbgInstrArray): Boolean;
    { the first of the 16 addresses from Addr - Before on from which the instructions decoded meet
      Addr (x86 code cannot be read backwards: where the CPU view begins); Addr when none does. The
      bytes are read once and only the instructions' lengths decoded }
    function DecodeStart(Addr: Cardinal; Before: Integer): Cardinal;
    function Disassemble(Addr: Cardinal; Count: Integer; Lines: TStrings): Boolean;
    function CurrentThreadId: Cardinal;
    { makes another thread the one inspected by GetCallStack/GetLocals/Evaluate (dsPaused only) }
    function SelectThread(ThreadId: Cardinal): Boolean;
    { the thread and frame inspected (with the place an exception was raised from), to be put back
      after another thread was looked at (the Open Tools API's IOTAThread) }
    function SaveInspection: TDbgInspection;
    procedure RestoreInspection(const S: TDbgInspection);
    { the process of the session (0: none) and the handle of one of its threads (0: none) - the
      Open Tools API's IOTAProcess / IOTAThread }
    property ProcessId: Cardinal read FProcessId;
    function ThreadHandle(ThreadId: Cardinal): THandle;
    // state
    property State: TDbgState read FState;
    property ExeName: string read FExeName;
    property ExitCode: Cardinal read FExitCode;
    // events - ALWAYS fired in the thread that created the TDebugger
    property OnStateChange: TDbgNotifyEvent read FOnStateChange write FOnStateChange;
    property OnStop: TDbgStopEvent read FOnStop write FOnStop;
    property OnLog: TDbgLogEvent read FOnLog write FOnLog;
    property OnExit: TDbgExitEvent read FOnExit write FOnExit;
    { the Valid flag of breakpoints may have changed (process start/exit, module load/unload) }
    property OnBreakpointsChanged: TDbgNotifyEvent read FOnBreakpointsChanged write FOnBreakpointsChanged;
    { an exception the engine caught to go on (the IDE logs it): one of the event handlers above
      raised it, or the debug thread met it (EDbgThreadError, raised here to be reported) }
    property OnError: TDbgErrorEvent read FOnError write FOnError;
    { a hit of a breakpoint whose AskTrigger is set, before anything else is done with it: the
      program stands as at a stop - Evaluate and the other inspections work in the thread that hit
      it - but no stop is reported; Decision is the answer (the Open Tools API's
      IOTABreakpointNotifier.Trigger) }
    property OnTrigger: TDbgTriggerEvent read FOnTrigger write FOnTrigger;
    { what a hit of the breakpoint would do by default in the thread inspected (dsPaused - during
      OnTrigger the thread that hit it): its condition, its pass counted, its actions; whether it
      stops the program (the Open Tools API's DefaultTrigger) }
    function DefaultTrigger(BreakpointId: Cardinal): Boolean;
  end;

implementation

uses
  WindowsEx, SdFileNames, SdEncoding;

const
  WM_DBG_EVENT = WM_USER + $2A7;

  EXC_BREAKPOINT        = $80000003;
  EXC_SINGLE_STEP       = $80000004;
  EXC_WX86_BREAKPOINT   = $4000001F;
  EXC_WX86_SINGLE_STEP  = $4000001E;
  EXC_ACCESS_VIOLATION  = $C0000005;
  EXC_THREAD_NAME       = $406D1388;
  EXC_CONTROL_C         = $40010005;
  EXC_CONTROL_BREAK     = $40010008;
  EXC_DBG_PRINT         = $40010006;
  EXC_DBG_PRINT_WIDE    = $4001000A;
  { STATUS_INVALID_EXCEPTION_HANDLER: with DEP Windows takes no exception handler outside a module }
  EXC_INVALID_HANDLER   = $C00001A5;

  cDelphiException    = $0EEDFADE;
  cDelphiReRaise      = $0EEDFADF;
  cDelphiExcept       = $0EEDFAE0;
  cDelphiFinally      = $0EEDFAE1;
  cDelphiTerminate    = $0EEDFAE2;
  cDelphiUnhandled    = $0EEDFAE3;
  cNonDelphiException = $0EEDFAE4;
  cDelphiExitFinally  = $0EEDFAE5;

  TRAP_FLAG = $100;
  MAX_STACK_FRAMES = 256;

type
  TEventKind = (evState, evStop, evLog, evExit, evBPs, evError, evTrigger);

  TQueuedEvent = class
  public
    Kind: TEventKind;
    Reason: TDbgStopReason;
    Frame: TDbgFrame;
    Msg: string;
    LogKind: TDbgLogKind;
    ExitCode: Cardinal;
    Seq: Integer;
    BreakpointId: Cardinal;    // evTrigger
  end;

  TDbgWorker = class(TThread)
  private
    FOwner: TDebugger;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TDebugger);
  end;

  { evaluator host bound to one thread + frame }
  TEngineHost = class(TDbgEvalHost)
  private
    FDbg: TDebugger;
    FThread: TDbgThread;
    FEIP, FEBP: Cardinal;
    FTop: Boolean;
    FCtx: TContext;
    FCtxValid: Boolean;
  public
    constructor Create(ADbg: TDebugger; AThread: TDbgThread; AEIP, AEBP: Cardinal; ATop: Boolean);
    function ReadMem(Addr: Cardinal; var Buf; Size: Integer): Boolean; override;
    function WriteMem(Addr: Cardinal; const Buf; Size: Integer): Boolean; override;
    function GetReg(CVReg: Integer; out Value: Cardinal): Boolean; override;
    function SetReg(CVReg: Integer; Value: Cardinal): Boolean; override;
    function FrameEIP: Cardinal; override;
    function FrameEBP: Cardinal; override;
    function IsTopFrame: Boolean; override;
    function InfoCount: Integer; override;
    function GetInfo(Index: Integer; out Info: TTD32Info; out Base: Cardinal): Boolean; override;
    function InfoByAddr(Addr: Cardinal; out Info: TTD32Info; out Base: Cardinal): Boolean; override;
    function AddrToSymbol(Addr: Cardinal): string; override;
    function CallScratch: Cardinal; override;
    function CallCode(Addr: Cardinal; const Regs, Stack: array of Cardinal; out EAX, EDX: Cardinal;
      out ST0: Extended; out Error: string): Boolean; override;
    function FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal; override;
  end;

var
  NtdllProcsLoaded: Boolean;
  BreakpointIds: Integer;            // TDbgBreakpoint.Id
  { the debug object of a thread (ntdll; the kernel32 functions of the debugger are WindowsEx's,
    bound at run time there) }
  PDbgUiGetThreadDebugObject: function: THandle; stdcall;
  PDbgUiSetThreadDebugObject: procedure(H: THandle); stdcall;

procedure LoadNtdllProcs;
var
  K: HMODULE;
begin
  if NtdllProcsLoaded then Exit;
  K := GetModuleHandle('ntdll.dll');
  if K <> 0 then
  begin
    @PDbgUiGetThreadDebugObject := GetProcAddress(K, 'DbgUiGetThreadDebugObject');
    @PDbgUiSetThreadDebugObject := GetProcAddress(K, 'DbgUiSetThreadDebugObject');
  end;
  NtdllProcsLoaded := True;
end;

{ Every thread that debugs a process owns a debug object. It is not released when the thread
  ends, and it keeps the (dead) debuggee process objects alive - close it explicitly. }
procedure CloseThreadDebugObject;
var
  H: THandle;
begin
  if Assigned(PDbgUiGetThreadDebugObject) and Assigned(PDbgUiSetThreadDebugObject) then
  begin
    H := PDbgUiGetThreadDebugObject;
    if H <> 0 then
    begin
      PDbgUiSetThreadDebugObject(0);
      CloseHandle(H);
    end;
  end;
end;

{ the long name of a file, as a usable name: a long name outside the code page stays the short
  one (SdFileNames) }
function LongPath(const S: string): string;
begin
  Result := UsablePath(DisplayPath(S));
end;

function IsAbsPath(const S: string): Boolean;
begin
  Result := (Length(S) > 2) and ((S[2] = ':') or ((S[1] = '\') and (S[2] = '\')));
end;

{ TDbgModule }

destructor TDbgModule.Destroy;
begin
  if OwnsInfo then Info.Free;
  SrcPaths.Free;
  ExpKeys.Free;
  inherited Destroy;
end;

{ TBPLoc }

constructor TBPLoc.Create;
begin
  inherited Create;
  UserBPs := TList.Create;
end;

destructor TBPLoc.Destroy;
begin
  UserBPs.Free;
  inherited Destroy;
end;

{ TDbgWorker }

constructor TDbgWorker.Create(AOwner: TDebugger);
begin
  FOwner := AOwner;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TDbgWorker.Execute;
begin
  try
    FOwner.ThreadMain;
  except
    // never let an exception escape the debug thread (ThreadMain ended the session already)
    on E: Exception do FOwner.QueueError('session', E);
  end;
end;

{ TEngineHost }

constructor TEngineHost.Create(ADbg: TDebugger; AThread: TDbgThread; AEIP, AEBP: Cardinal; ATop: Boolean);
begin
  inherited Create;
  FDbg := ADbg;
  FThread := AThread;
  FEIP := AEIP;
  FEBP := AEBP;
  FTop := ATop;
end;

function TEngineHost.ReadMem(Addr: Cardinal; var Buf; Size: Integer): Boolean;
begin
  Result := FDbg.ReadMemory(Addr, Buf, Size);
end;

function TEngineHost.WriteMem(Addr: Cardinal; const Buf; Size: Integer): Boolean;
begin
  Result := FDbg.WriteMemory(Addr, Buf, Size);
end;

function TEngineHost.GetReg(CVReg: Integer; out Value: Cardinal): Boolean;
var
  R: Cardinal;
begin
  Value := 0;
  Result := False;
  if FThread = nil then Exit;
  if not FCtxValid then
  begin
    if not FDbg.GetCtx(FThread, FCtx) then Exit;
    FCtxValid := True;
  end;
  Result := True;
  case CVReg of
    CV_REG_AL, CV_REG_AH, CV_REG_AX, CV_REG_EAX: R := FCtx.Eax;
    CV_REG_CL, CV_REG_CH, CV_REG_CX, CV_REG_ECX: R := FCtx.Ecx;
    CV_REG_DL, CV_REG_DH, CV_REG_DX, CV_REG_EDX: R := FCtx.Edx;
    CV_REG_BL, CV_REG_BH, CV_REG_BX, CV_REG_EBX: R := FCtx.Ebx;
    CV_REG_SP, CV_REG_ESP: R := FCtx.Esp;
    CV_REG_BP, CV_REG_EBP: R := FCtx.Ebp;
    CV_REG_SI, CV_REG_ESI: R := FCtx.Esi;
    CV_REG_DI, CV_REG_EDI: R := FCtx.Edi;
    33: R := FCtx.Eip;
    34: R := FCtx.EFlags;
  else
    R := 0;
    Result := False;
  end;
  case CVReg of
    CV_REG_AL..CV_REG_BL: Value := R and $FF;
    CV_REG_AH..CV_REG_BH: Value := (R shr 8) and $FF;
    CV_REG_AX..CV_REG_DI: Value := R and $FFFF;
  else
    Value := R;
  end;
end;

function TEngineHost.SetReg(CVReg: Integer; Value: Cardinal): Boolean;
var
  Ctx: TContext;
  P: PCardinal;
begin
  Result := False;
  if (FThread = nil) or not FDbg.GetCtx(FThread, Ctx) then Exit;
  case CVReg of
    CV_REG_AL, CV_REG_AH, CV_REG_AX, CV_REG_EAX: P := @Ctx.Eax;
    CV_REG_CL, CV_REG_CH, CV_REG_CX, CV_REG_ECX: P := @Ctx.Ecx;
    CV_REG_DL, CV_REG_DH, CV_REG_DX, CV_REG_EDX: P := @Ctx.Edx;
    CV_REG_BL, CV_REG_BH, CV_REG_BX, CV_REG_EBX: P := @Ctx.Ebx;
    CV_REG_SI, CV_REG_ESI: P := @Ctx.Esi;
    CV_REG_DI, CV_REG_EDI: P := @Ctx.Edi;
  else
    Exit;     // stack/frame/instruction pointers are not writable through expressions
  end;
  case CVReg of
    CV_REG_AL..CV_REG_BL: P^ := (P^ and $FFFFFF00) or (Value and $FF);
    CV_REG_AH..CV_REG_BH: P^ := (P^ and $FFFF00FF) or ((Value and $FF) shl 8);
    CV_REG_AX..CV_REG_DI: P^ := (P^ and $FFFF0000) or (Value and $FFFF);
  else
    P^ := Value;
  end;
  Result := FDbg.SetCtx(FThread, Ctx);
  FCtxValid := False;
end;

function TEngineHost.FrameEIP: Cardinal;
begin
  Result := FEIP;
end;

function TEngineHost.FrameEBP: Cardinal;
begin
  Result := FEBP;
end;

function TEngineHost.IsTopFrame: Boolean;
begin
  Result := FTop;
end;

function TEngineHost.InfoCount: Integer;
begin
  Result := FDbg.FModules.Count;
end;

function TEngineHost.GetInfo(Index: Integer; out Info: TTD32Info; out Base: Cardinal): Boolean;
var
  M: TDbgModule;
begin
  Info := nil;
  Base := 0;
  Result := False;
  if (Index < 0) or (Index >= FDbg.FModules.Count) then Exit;
  M := TDbgModule(FDbg.FModules[Index]);
  Info := M.Info;
  Base := M.Base;
  Result := Info <> nil;
end;

function TEngineHost.InfoByAddr(Addr: Cardinal; out Info: TTD32Info; out Base: Cardinal): Boolean;
var
  M: TDbgModule;
begin
  Info := nil;
  Base := 0;
  M := FDbg.ModuleByAddr(Addr);
  Result := (M <> nil) and (M.Info <> nil);
  if Result then
  begin
    Info := M.Info;
    Base := M.Base;
  end;
end;

{ below the thread's stack pointer, far enough for what the stopped code still keeps there; the
  call's own stack starts below it (DoCall) }
function TEngineHost.CallScratch: Cardinal;
var
  Ctx: TContext;
begin
  Result := 0;
  if FDbg.GetCtx(FThread, Ctx) then Result := (Ctx.Esp - $1C00) and not 15;
end;

function TEngineHost.CallCode(Addr: Cardinal; const Regs, Stack: array of Cardinal; out EAX, EDX: Cardinal;
  out ST0: Extended; out Error: string): Boolean;
begin
  Result := FDbg.CallCode(FThread, Addr, Regs, Stack, EAX, EDX, ST0, Error);
end;

function TEngineHost.FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal;
begin
  Result := FDbg.FindCode(ClassName, Routine, ExportName);
end;

function TEngineHost.AddrToSymbol(Addr: Cardinal): string;
var
  M: TDbgModule;
  PI: Integer;
begin
  Result := '';
  M := FDbg.ModuleByAddr(Addr);
  if (M = nil) or (M.Info = nil) then Exit;
  PI := M.Info.ProcByAddr(Addr - M.Base);
  if (PI >= 0) and (M.Info.Procs[PI]^.Start = Addr - M.Base) then Result := M.Info.ProcName(PI);
end;

{ TDebugger: construction }

constructor TDebugger.Create;
begin
  inherited Create;
  LoadNtdllProcs;
  InitializeCriticalSection(FLock);
  InitializeCriticalSection(FQueueLock);
  FQueue := TList.Create;
  FSourceDirs := TStringList.Create;
  FSrcDirs := TStringList.Create;
  FIgnored := TStringList.Create;
  FChildren := TList.Create;
  FThreads := TList.Create;
  FModules := TList.Create;
  FBreakpoints := TList.Create;
  FLocs := TList.Create;
  FStopOnDelphi := True;
  FStopOnOS := True;
  FShowWindowCmd := -1;
  FPauseByBreakIn := True;
  FStartEvent := CreateEvent(nil, True, False, nil);
  FCallDone := CreateEvent(nil, True, False, nil);
  FCmdEvent := CreateEvent(nil, False, False, nil);
  FWnd := Classes.AllocateHWnd(WndProc);
end;

destructor TDebugger.Destroy;
var
  I: Integer;
begin
  FOnStateChange := nil;
  FOnStop := nil;
  FOnLog := nil;
  FOnExit := nil;
  FOnBreakpointsChanged := nil;
  FOnError := nil;
  FOnTrigger := nil;
  Stop;
  if FWorker <> nil then
  begin
    WaitForSingleObject(FWorker.Handle, 10000);
    FWorker.Free;
    FWorker := nil;
  end;
  if FWnd <> 0 then Classes.DeallocateHWnd(FWnd);
  FWnd := 0;
  SessionCleanup;
  for I := 0 to FQueue.Count - 1 do TObject(FQueue[I]).Free;
  FQueue.Free;
  for I := 0 to FBreakpoints.Count - 1 do TObject(FBreakpoints[I]).Free;
  FBreakpoints.Free;
  FLocs.Free;
  FThreads.Free;
  FModules.Free;
  FExeInfo.Free;
  FSourceDirs.Free;
  FSrcDirs.Free;
  FIgnored.Free;
  FChildren.Free;
  CloseHandle(FStartEvent);
  CloseHandle(FCallDone);
  CloseHandle(FCmdEvent);
  DeleteCriticalSection(FLock);
  DeleteCriticalSection(FQueueLock);
  inherited Destroy;
end;

procedure TDebugger.Lock;
begin
  EnterCriticalSection(FLock);
end;

procedure TDebugger.Unlock;
begin
  LeaveCriticalSection(FLock);
end;

function TDebugger.GetSourceDirs: TStrings;
begin
  Result := FSourceDirs;
end;

function TDebugger.GetIgnored: TStrings;
begin
  Result := FIgnored;
end;

{ event queue }

procedure TDebugger.Enqueue(Item: TObject);
var
  Post: Boolean;
begin
  EnterCriticalSection(FQueueLock);
  try
    FQueue.Add(Item);
    Post := not FMsgPosted;
    FMsgPosted := True;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  if Post and (FWnd <> 0) then PostMessage(FWnd, WM_DBG_EVENT, 0, 0);
end;

procedure TDebugger.QueueState;
var
  E: TQueuedEvent;
begin
  E := TQueuedEvent.Create;
  E.Kind := evState;
  Enqueue(E);
end;

procedure TDebugger.QueueBPsChanged;
var
  E: TQueuedEvent;
begin
  E := TQueuedEvent.Create;
  E.Kind := evBPs;
  Enqueue(E);
end;

procedure TDebugger.QueueLog(Kind: TDbgLogKind; const Text: string);
var
  E: TQueuedEvent;
begin
  E := TQueuedEvent.Create;
  E.Kind := evLog;
  E.LogKind := Kind;
  E.Msg := Text;
  Enqueue(E);
end;

{ an exception the debug thread caught to go on: reported in the host's thread (DispatchEvents) }
procedure TDebugger.QueueError(const Where: string; E: Exception);
var
  Q: TQueuedEvent;
begin
  Q := TQueuedEvent.Create;
  Q.Kind := evError;
  Q.Msg := Format('debug thread, %s: %s: %s', [Where, E.ClassName, E.Message]);
  Enqueue(Q);
end;

procedure TDebugger.ReportError(E: Exception);
begin
  if (E is EAbort) or not Assigned(FOnError) then Exit;
  try
    FOnError(Self, E);
  except
    // the report must not fail the delivery
  end;
end;

procedure TDebugger.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_DBG_EVENT then
  begin
    try
      DispatchEvents;
    except
      // event handlers must not break the message loop
    end;
    Msg.Result := 0;
  end
  else
    Msg.Result := DefWindowProc(FWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;

{ The queued events in their order. An event whose handler raises is reported (OnError) and the
  ones after it are still delivered - an evExit behind it must reach the IDE, or it stays in its
  debug layout. }
procedure TDebugger.DispatchEvents;
var
  Items: TList;
  I: Integer;
  E: TQueuedEvent;
  Decision: TDbgTrigger;
  Current: Boolean;
begin
  Items := TList.Create;
  try
    EnterCriticalSection(FQueueLock);
    try
      for I := 0 to FQueue.Count - 1 do Items.Add(FQueue[I]);
      FQueue.Clear;
      FMsgPosted := False;
    finally
      LeaveCriticalSection(FQueueLock);
    end;
    for I := 0 to Items.Count - 1 do
    begin
      E := TQueuedEvent(Items[I]);
      Items[I] := nil;
      try
        try
          case E.Kind of
            evState:
              if Assigned(FOnStateChange) then FOnStateChange(Self);
            evStop:
              begin
                if Assigned(FOnStateChange) then FOnStateChange(Self);
                // a stop that was already left again (resumed before the event got here) is stale
                if Assigned(FOnStop) and (FState = dsPaused) and (E.Seq = FStopSeq) then
                  FOnStop(Self, E.Reason, E.Frame, E.Msg);
              end;
            evLog:
              if Assigned(FOnLog) then FOnLog(Self, E.LogKind, E.Msg);
            evExit:
              begin
                try
                  if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
                  if Assigned(FOnStateChange) then FOnStateChange(Self);
                finally
                  if Assigned(FOnExit) then FOnExit(Self, E.ExitCode);
                end;
              end;
            evBPs:
              if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
            evTrigger:
              begin
                { the debug thread waits for the answer: it gets one whatever the handler does -
                  as long as it still stands for this trigger (a handler that runs a message loop
                  may see the program resumed and standing again: that stand is not answered) }
                Decision := tgDefault;
                try
                  if Assigned(FOnTrigger) then FOnTrigger(Self, E.BreakpointId, Decision);
                finally
                  Lock;
                  try
                    Current := FStandCount = E.Seq;
                    if Current then FTrigger := Decision;
                  finally
                    Unlock;
                  end;
                  if Current then PostCommand(dcResume);
                end;
              end;
            evError:
              raise EDbgThreadError.Create(E.Msg);   // reported below, from this thread's stack
          end;
        except
          on X: Exception do ReportError(X);
        end;
      finally
        E.Free;
      end;
    end;
  finally
    for I := 0 to Items.Count - 1 do TObject(Items[I]).Free;
    Items.Free;
  end;
end;

{ memory / context }

function TDebugger.ReadMemRaw(Addr: Cardinal; var Buf; Size: Integer): Boolean;
var
  N: DWORD;
begin
  Result := False;
  if (FProcessHandle = 0) or (Size <= 0) then Exit;
  N := 0;
  Result := ReadProcessMemory(FProcessHandle, Pointer(Addr), @Buf, Size, N) and (Integer(N) = Size);
end;

function TDebugger.WriteMemRaw(Addr: Cardinal; const Buf; Size: Integer): Boolean;
var
  N: DWORD;
begin
  Result := False;
  if (FProcessHandle = 0) or (Size <= 0) then Exit;
  N := 0;
  Result := WriteProcessMemory(FProcessHandle, Pointer(Addr), @Buf, Size, N) and (Integer(N) = Size);
end;

function TDebugger.WriteCodeByte(Addr: Cardinal; B: Byte): Boolean;
var
  Old, Dummy: DWORD;
begin
  Result := False;
  if FProcessHandle = 0 then Exit;
  Old := 0;
  if VirtualProtectEx(FProcessHandle, Pointer(Addr), 1, PAGE_EXECUTE_READWRITE, Old) then
  begin
    Result := WriteMemRaw(Addr, B, 1);
    VirtualProtectEx(FProcessHandle, Pointer(Addr), 1, Old, Dummy);
  end
  else
    Result := WriteMemRaw(Addr, B, 1);
  FlushInstructionCache(FProcessHandle, Pointer(Addr), 1);
end;

function TDebugger.ReadMemory(Addr: Cardinal; var Buf; Size: Integer): Boolean;
var
  I: Integer;
  Loc: TBPLoc;
begin
  Result := ReadMemRaw(Addr, Buf, Size);
  if not Result then Exit;
  // hide our breakpoint opcodes
  Lock;
  try
    for I := 0 to FLocs.Count - 1 do
    begin
      Loc := TBPLoc(FLocs[I]);
      if Loc.Installed and (Loc.Addr >= Addr) and (Loc.Addr - Addr < Cardinal(Size)) then
        PByteArray(@Buf)^[Loc.Addr - Addr] := Loc.OrigByte;
    end;
  finally
    Unlock;
  end;
end;

function TDebugger.WriteMemory(Addr: Cardinal; const Buf; Size: Integer): Boolean;
var
  I: Integer;
  Loc: TBPLoc;
  Tmp: array of Byte;
begin
  Result := False;
  if Size <= 0 then Exit;
  SetLength(Tmp, Size);
  Move(Buf, Tmp[0], Size);
  // keep installed breakpoints: redirect the written byte to the saved original
  Lock;
  try
    for I := 0 to FLocs.Count - 1 do
    begin
      Loc := TBPLoc(FLocs[I]);
      if Loc.Installed and (Loc.Addr >= Addr) and (Loc.Addr - Addr < Cardinal(Size)) then
      begin
        Loc.OrigByte := Tmp[Loc.Addr - Addr];
        Tmp[Loc.Addr - Addr] := $CC;
      end;
    end;
  finally
    Unlock;
  end;
  Result := WriteMemRaw(Addr, Tmp[0], Size);
  if not Result and IsCodeAddr(Addr) then
  begin
    Result := True;
    for I := 0 to Size - 1 do
      if not WriteCodeByte(Addr + Cardinal(I), Tmp[I]) then Result := False;
  end;
end;

function TDebugger.GetCtx(T: TDbgThread; var Ctx: TContext): Boolean;
begin
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.ContextFlags := CONTEXT_FULL;
  Result := (T <> nil) and GetThreadContext(T.Handle, Ctx);
end;

function TDebugger.SetCtx(T: TDbgThread; var Ctx: TContext): Boolean;
begin
  Ctx.ContextFlags := CONTEXT_FULL;
  Result := (T <> nil) and SetThreadContext(T.Handle, Ctx);
end;

procedure TDebugger.SetEIP(T: TDbgThread; EIP: Cardinal);
var
  Ctx: TContext;
begin
  if GetCtx(T, Ctx) then
  begin
    Ctx.Eip := EIP;
    SetCtx(T, Ctx);
  end;
end;

procedure TDebugger.ClearTrapFlag(T: TDbgThread);
var
  Ctx: TContext;
begin
  if GetCtx(T, Ctx) and ((Ctx.EFlags and TRAP_FLAG) <> 0) then
  begin
    Ctx.EFlags := Ctx.EFlags and not TRAP_FLAG;
    SetCtx(T, Ctx);
  end;
end;

{ an evaluator for a frame of thread T (T = nil: memory only); the caller frees it }
function TDebugger.NewEvaluator(T: TDbgThread; EIP, EBP: Cardinal; Top: Boolean): TDbgEvaluator;
begin
  Result := TDbgEvaluator.Create(TEngineHost.Create(Self, T, EIP, EBP, Top));
end;

{ an evaluator for the frame chosen in the call stack (CurrentFrame) of the inspected thread }
function TDebugger.FrameEvaluator: TDbgEvaluator;
var
  Fx: TFrameExArray;
  A, EBP: Cardinal;
  Idx: Integer;
begin
  Fx := CurFrames;
  Idx := FCurrentFrame;
  A := 0;
  EBP := 0;
  if (Idx >= 0) and (Idx <= High(Fx)) then
  begin
    A := Fx[Idx].Addr;
    if Idx > 0 then Dec(A);      // inside the call instruction: the calling line's scope
    EBP := Fx[Idx].EBP;
  end;
  Result := NewEvaluator(FCurThread, A, EBP, (Idx = 0) and not FOverrideCtx);
end;

function TDebugger.ReadClassNameOf(Obj: Cardinal): string;
var
  Ev: TDbgEvaluator;
begin
  Ev := NewEvaluator(nil, 0, 0, False);
  try
    Result := Ev.ReadClassName(Obj);
  finally
    Ev.Free;
  end;
end;

function TDebugger.ReadExceptionMessage(Obj: Cardinal): string;
var
  Ev: TDbgEvaluator;
  P: Cardinal;
begin
  Result := '';
  Ev := NewEvaluator(nil, 0, 0, False);
  try
    // Exception.FMessage is the first field
    if Ev.InheritsFromName(Obj, 'Exception') and ReadMemRaw(Obj + 4, P, 4) then
      Result := Ev.ReadAnsiString(P, 2048);
  finally
    Ev.Free;
  end;
end;

{ threads / modules }

function TDebugger.FindThread(Id: Cardinal): TDbgThread;
var
  I: Integer;
begin
  for I := 0 to FThreads.Count - 1 do
  begin
    Result := TDbgThread(FThreads[I]);
    if Result.ThreadId = Id then Exit;
  end;
  Result := nil;
end;

function TDebugger.MainThread: TDbgThread;
var
  I: Integer;
begin
  Result := FindThread(FMainThreadId);
  if Result = nil then
    for I := 0 to FThreads.Count - 1 do
      if TDbgThread(FThreads[I]).ThreadId <> FBreakInThreadId then
      begin
        Result := TDbgThread(FThreads[I]);
        Exit;
      end;
end;

function TDebugger.ModuleFileFromHandle(H: THandle): string;
var
  Buf: array[0..1023] of WideChar;
  N: DWORD;
  W: WideString;
begin
  Result := '';
  if (H = 0) or (H = INVALID_HANDLE_VALUE) then Exit;
  { the Unicode version: an ANSI name of a folder outside the code page has '?' where its 8.3 name
    would work (UsablePath makes the name) }
  N := GetFinalPathNameByHandleW(H, Buf, Length(Buf) - 1, 0);
  if (N = 0) or (N >= DWORD(Length(Buf))) then Exit;
  W := Buf;
  if Copy(W, 1, 8) = '\\?\UNC\' then
    W := '\\' + Copy(W, 9, MaxInt)
  else if Copy(W, 1, 4) = '\\?\' then
    Delete(W, 1, 4);
  Result := UsablePath(W);
end;

function TDebugger.AddModule(Base: Cardinal; const Path: string; Info: TTD32Info; OwnsInfo: Boolean): TDbgModule;
var
  Hdr: array[0..$3FF] of Byte;
  H: TPEHeaderInfo;
  I: Integer;
  VS: Cardinal;
begin
  Result := TDbgModule.Create;
  Result.Base := Base;
  Result.Path := Path;
  Result.Name := ExtractFileName(Path);
  Result.Info := Info;
  Result.OwnsInfo := OwnsInfo;
  Result.Size := $1000;
  // section table from the mapped image: its code sections
  if ReadMemRaw(Base, Hdr, SizeOf(Hdr)) and ParsePEHeader(Hdr, SizeOf(Hdr), H) then
  begin
    Result.Size := H.SizeOfImage;
    for I := 0 to High(H.Sections) do
    begin
      VS := H.Sections[I].VSize;
      if H.Sections[I].RawSize > VS then VS := H.Sections[I].RawSize;
      if ((H.Sections[I].Flags and $20000020) <> 0) and (Result.ExecCount < 8) then
      begin
        Result.ExecLo[Result.ExecCount] := Base + H.Sections[I].VA;
        Result.ExecHi[Result.ExecCount] := Base + H.Sections[I].VA + VS;
        Inc(Result.ExecCount);
      end;
    end;
  end;
  if (Result.Size = $1000) and (Info <> nil) and (Info.SizeOfImage > 0) then Result.Size := Info.SizeOfImage;
  Lock;
  try
    FModules.Add(Result);
  finally
    Unlock;
  end;
end;

{ under the lock: the debug thread adds and frees modules while the IDE asks (SourceLineAt); a
  caller in the IDE's thread holds the lock while it uses the module }
function TDebugger.ModuleByAddr(Addr: Cardinal): TDbgModule;
var
  I: Integer;
begin
  Lock;
  try
    for I := 0 to FModules.Count - 1 do
    begin
      Result := TDbgModule(FModules[I]);
      if (Addr >= Result.Base) and (Addr - Result.Base < Result.Size) then Exit;
    end;
    Result := nil;
  finally
    Unlock;
  end;
end;

procedure TDebugger.RemoveModule(Base: Cardinal);
var
  I: Integer;
  M: TDbgModule;
begin
  Lock;
  try
    for I := 0 to FModules.Count - 1 do
    begin
      M := TDbgModule(FModules[I]);
      if M.Base = Base then
      begin
        RemoveLocsInRange(M.Base, M.Base + M.Size);
        FModules.Delete(I);
        M.Free;
        Break;
      end;
    end;
  finally
    Unlock;
  end;
end;

function TDebugger.ReadCStrRaw(Addr: Cardinal; MaxLen: Integer): string;
var
  Trunc: Boolean;
begin
  // '' when unreadable: export names are looked up, not shown
  ReadCString(ReadMemRaw, Addr, MaxLen, Result, Trunc);
end;

procedure TDebugger.LoadExports(M: TDbgModule);
var
  Hdr: array[0..$3FF] of Byte;
  Dir: array[0..39] of Byte;
  H: TPEHeaderInfo;
  I, N: Integer;
  ExpRVA, ExpSize, NFuncs, NNames, AFuncs, ANames, AOrds, F: Cardinal;
begin
  if M.ExpLoaded then Exit;
  M.ExpLoaded := True;
  if not ReadMemRaw(M.Base, Hdr, SizeOf(Hdr)) or not ParsePEHeader(Hdr, SizeOf(Hdr), H) then Exit;
  ExpRVA := H.ExportRVA;
  ExpSize := H.ExportSize;
  if (ExpRVA = 0) or not ReadMemRaw(M.Base + ExpRVA, Dir, SizeOf(Dir)) then Exit;
  NFuncs := PCardinal(@Dir[20])^;
  NNames := PCardinal(@Dir[24])^;
  AFuncs := PCardinal(@Dir[28])^;
  ANames := PCardinal(@Dir[32])^;
  AOrds := PCardinal(@Dir[36])^;
  if (NFuncs = 0) or (NFuncs > 200000) or (NNames > NFuncs) then Exit;
  SetLength(M.ExpFuncs, NFuncs);
  if not ReadMemRaw(M.Base + AFuncs, M.ExpFuncs[0], NFuncs * 4) then
  begin
    M.ExpFuncs := nil;
    Exit;
  end;
  if NNames > 0 then
  begin
    SetLength(M.ExpByName, NNames);
    SetLength(M.ExpOrd, NNames);
    if not ReadMemRaw(M.Base + ANames, M.ExpByName[0], NNames * 4) or
      not ReadMemRaw(M.Base + AOrds, M.ExpOrd[0], NNames * 2) then
    begin
      M.ExpByName := nil;
      M.ExpOrd := nil;
      Exit;
    end;
  end;
  // address sorted table of the named, non-forwarded code exports
  SetLength(M.ExpAddr, NNames);
  SetLength(M.ExpAddrName, NNames);
  N := 0;
  for I := 0 to Integer(NNames) - 1 do
    if M.ExpOrd[I] < NFuncs then
    begin
      F := M.ExpFuncs[M.ExpOrd[I]];
      if (F = 0) or ((F >= ExpRVA) and (F < ExpRVA + ExpSize)) then Continue;
      M.ExpAddr[N] := F;
      M.ExpAddrName[N] := M.ExpByName[I];
      Inc(N);
    end;
  SetLength(M.ExpAddr, N);
  SetLength(M.ExpAddrName, N);
  if N > 1 then SortPairs(M.ExpAddr, M.ExpAddrName, 0, N - 1);
  SetLength(M.ExpAddrNames, N);
end;

function TDebugger.FindExport(M: TDbgModule; const Name: string): Cardinal;
var
  L, H, Mid, C: Integer;
  S: string;
begin
  Result := 0;
  Lock;
  try
    LoadExports(M);
  finally
    Unlock;
  end;
  L := 0;
  H := High(M.ExpByName);
  while L <= H do
  begin
    Mid := (L + H) shr 1;
    S := ReadCStrRaw(M.Base + M.ExpByName[Mid], 512);
    C := CompareStr(S, Name);
    if C = 0 then
    begin
      if M.ExpOrd[Mid] <= High(M.ExpFuncs) then Result := M.Base + M.ExpFuncs[M.ExpOrd[Mid]];
      Exit;
    end;
    if C < 0 then L := Mid + 1 else H := Mid - 1;
  end;
end;

{ the name of export I of the address sorted table (ExpAddr), read from the process once: the stack
  walk of every stop names its frames in the packages and system DLLs through the same ones }
function TDebugger.ExportName(M: TDbgModule; I: Integer): string;
begin
  Lock;
  try
    Result := M.ExpAddrNames[I];
    if Result = '' then
    begin
      Result := ReadCStrRaw(M.Base + M.ExpAddrName[I], 256) + #0;
      M.ExpAddrNames[I] := Result;
    end;
  finally
    Unlock;
  end;
  SetLength(Result, Length(Result) - 1);
end;

function TDebugger.ExportNameAt(M: TDbgModule; Addr: Cardinal): string;
var
  L, H, Mid, Best: Integer;
  RVA, Ofs: Cardinal;
  S: string;
begin
  Result := '';
  if (M = nil) or (Addr < M.Base) then Exit;
  Lock;
  try
    LoadExports(M);
  finally
    Unlock;
  end;
  RVA := Addr - M.Base;
  Best := -1;
  L := 0;
  H := High(M.ExpAddr);
  while L <= H do
  begin
    Mid := (L + H) shr 1;
    if M.ExpAddr[Mid] <= RVA then
    begin
      Best := Mid;
      L := Mid + 1;
    end
    else
      H := Mid - 1;
  end;
  if Best < 0 then Exit;
  S := '';
  L := 0;
  while (Best >= 0) and (L < 12) do
  begin
    S := ExportName(M, Best);
    // Delphi packages also export data that lives between the routines (RTTI '@$xp$..',
    // class tables 'Unit@TClass@', variables): only names with a parameter signature are code
    if (S = '') or (S[1] <> '@') or (Pos('$q', S) > 0) then Break;
    S := '';
    Dec(Best);
    Inc(L);
  end;
  if (S = '') or (Best < 0) then Exit;
  Ofs := RVA - M.ExpAddr[Best];
  if Ofs > $4000 then Exit;       // too far from any export to mean anything
  if S[1] = '@' then
    Result := CleanProcName(S)                          // Delphi package export: Unit.Routine
  else
    Result := ChangeFileExt(M.Name, '') + '.' + S;      // plain DLL export
  if Ofs > 0 then Result := Format('%s+$%x', [Result, Ofs]);
end;

procedure TDebugger.SetDebugHook(M: TDbgModule; Value: Byte);
var
  RVA: Cardinal;
  B: Byte;
  A: Cardinal;
begin
  // the RTL inside a runtime package exports the variable
  if (M <> nil) and (M.Info = nil) and SameText(Copy(M.Name, 1, 3), 'rtl') and
    SameText(ExtractFileExt(M.Name), '.bpl') then
  begin
    A := FindExport(M, '@System@DebugHook');
    B := Value;
    if A <> 0 then WriteMemRaw(A, B, 1);
    Exit;
  end;
  // System.DebugHook = 2 makes the Delphi RTL announce exception handling to the debugger (0:
  // not any more - Detach)
  // (every module linked with its own copy of the RTL has its own DebugHook)
  if (M = nil) or (M.Info = nil) then Exit;
  if M.Info.FindGlobalAddr('System', 'DebugHook', RVA) then
  begin
    B := Value;
    WriteMemRaw(M.Base + RVA, B, 1);
  end;
end;

{ While T steps over a lifted breakpoint the other threads must not run past it. A thread that
  is itself stepping over one is left alone: it is held by its own lift's suspension of T
  already (its breakpoint event was queued before T's step), and two threads suspending each
  other would never run again. It is the first of the two to finish; T follows. }
procedure TDebugger.SuspendOthers(T: TDbgThread);
var
  I: Integer;
  O: TDbgThread;
begin
  for I := 0 to FThreads.Count - 1 do
  begin
    O := TDbgThread(FThreads[I]);
    if (O <> T) and (O.SteppingOverBP = 0) then
      if SuspendThread(O.Handle) <> $FFFFFFFF then Inc(O.SuspendCount);
  end;
end;

procedure TDebugger.ResumeOthers(T: TDbgThread);
var
  I: Integer;
  O: TDbgThread;
begin
  for I := 0 to FThreads.Count - 1 do
  begin
    O := TDbgThread(FThreads[I]);
    if (O <> T) and (O.SuspendCount > 0) then
    begin
      ResumeThread(O.Handle);
      Dec(O.SuspendCount);
    end;
  end;
end;

{ every suspension of T by the engine taken back }
procedure TDebugger.ResumeAll(T: TDbgThread);
begin
  while T.SuspendCount > 0 do
  begin
    ResumeThread(T.Handle);
    Dec(T.SuspendCount);
  end;
end;

{ T has stepped over its lifted breakpoint (or was interrupted, or ended): the int 3 goes back -
  unless another thread still has to step over the same one - and the others run again }
procedure TDebugger.EndLift(T: TDbgThread);
var
  I: Integer;
  Loc: TBPLoc;
  Shared: Boolean;
begin
  Shared := False;
  for I := 0 to FThreads.Count - 1 do
    if (TDbgThread(FThreads[I]) <> T) and (TDbgThread(FThreads[I]).SteppingOverBP = T.SteppingOverBP) then
      Shared := True;
  if not Shared then
  begin
    Lock;
    try
      Loc := FindLoc(T.SteppingOverBP);
      if (Loc <> nil) and Loc.Installed then WriteCodeByte(Loc.Addr, $CC);
    finally
      Unlock;
    end;
  end;
  T.SteppingOverBP := 0;
  ResumeOthers(T);
end;

{ O stays where it is until the running call ends (ResumeOthers lets every held thread go then):
  a thread made while the call runs, one whose event came meanwhile }
procedure TDebugger.HoldForCall(O: TDbgThread);
begin
  if (O <> nil) and (O.SuspendCount = 0) and (SuspendThread(O.Handle) <> $FFFFFFFF) then Inc(O.SuspendCount);
end;

{ symbols }

function TDebugger.ExeBaseName: string;
begin
  Result := ExtractFileName(FExeName);
end;

function TDebugger.IsCodeAddr(Addr: Cardinal): Boolean;
var
  M: TDbgModule;
  I: Integer;
begin
  Result := False;
  M := ModuleByAddr(Addr);
  if M = nil then Exit;
  if M.ExecCount = 0 then
  begin
    Result := True;
    Exit;
  end;
  for I := 0 to M.ExecCount - 1 do
    if (Addr >= M.ExecLo[I]) and (Addr < M.ExecHi[I]) then
    begin
      Result := True;
      Exit;
    end;
end;

function TDebugger.IsReturnAddr(Addr: Cardinal; out CallTarget: Cardinal): Boolean;
var
  B: TCallBytes;
  Tgt, Slot: Cardinal;
begin
  Result := False;
  CallTarget := 0;
  if (Addr < $10008) or not IsCodeAddr(Addr) then Exit;
  if not ReadMemory(Addr - 8, B, 8) then Exit;
  // call rel32 into code
  if RelCallBefore(B, Addr, Tgt) and IsCodeAddr(Tgt) then
  begin
    CallTarget := Tgt;
    Result := True;
    Exit;
  end;
  // call r/m32; through an import slot the target can be read
  Result := IndirectCallBefore(B, Slot);
  if Result and (Slot <> 0) then
    if ReadMemRaw(Slot, Tgt, 4) and IsCodeAddr(Tgt) then CallTarget := Tgt;
end;

function TDebugger.ThunkTarget(Addr: Cardinal): Cardinal;
var
  B: array[0..5] of Byte;
  P: Cardinal;
begin
  Result := 0;
  if not ReadMemory(Addr, B, 6) then Exit;
  if (B[0] = $FF) and (B[1] = $25) then
  begin
    P := PCardinal(@B[2])^;
    if not ReadMemRaw(P, Result, 4) then Result := 0;
  end
  else if B[0] = $E9 then
    Result := Addr + 5 + Cardinal(PInteger(@B[1])^)
  else if B[0] = $EB then
    Result := Addr + 2 + Cardinal(Integer(ShortInt(B[1])));
end;

function TDebugger.FindProcStart(Addr: Cardinal; out ProcStart: Cardinal; out Framed: Boolean): Boolean;
var
  M: TDbgModule;
  PI: Integer;
  B: array[0..2] of Byte;
begin
  Result := False;
  ProcStart := 0;
  Framed := False;
  M := ModuleByAddr(Addr);
  if (M = nil) or (M.Info = nil) then Exit;
  PI := M.Info.ProcByAddr(Addr - M.Base);
  if PI < 0 then Exit;
  ProcStart := M.Base + M.Info.Procs[PI]^.Start;
  Result := True;
  if ReadMemory(ProcStart, B, 3) then
    Framed := (B[0] = $55) and (B[1] = $8B) and (B[2] = $EC);
end;

function TDebugger.FindLineAbs(Addr: Cardinal; out M: TDbgModule; out L: TTDLine): Boolean;
begin
  Result := False;
  FillChar(L, SizeOf(L), 0);
  Lock;
  try
    M := ModuleByAddr(Addr);
    if (M = nil) or (M.Info = nil) then Exit;
    Result := M.Info.AddrToLine(Addr - M.Base, L);
  finally
    Unlock;
  end;
end;

function TDebugger.HasLineAbs(Addr: Cardinal): Boolean;
var
  M: TDbgModule;
  L: TTDLine;
begin
  Result := FindLineAbs(Addr, M, L);
end;

function TDebugger.ResolveSource(M: TDbgModule; Src: Integer): string;
var
  Name, Dir, ExeDir, S: string;
  I: Integer;

  function TryFile(const F: string): Boolean;
  begin
    Result := FileExists(F);
    if Result then S := LongPath(ExpandFileName(F));
  end;

begin
  Result := '';
  if (M = nil) or (M.Info = nil) or (Src < 0) or (Src >= M.Info.SrcCount) then Exit;
  Lock;
  try
    if M.SrcPaths = nil then M.SrcPaths := TStringList.Create;
    while M.SrcPaths.Count < M.Info.SrcCount do M.SrcPaths.Add('');
    Result := M.SrcPaths[Src];
  finally
    Unlock;
  end;
  if (Result <> '') and (Result[1] = '*') then
  begin
    Delete(Result, 1, 1);
    Exit;
  end;
  if Result <> '' then Exit;
  { the compiler wrote the name in the system code page; D7 Studio's names are UTF-8 (UTF-8 mode) }
  Name := SystemToIde(M.Info.SrcName[Src]);
  S := '';
  ExeDir := ExtractFilePath(M.Path);
  if IsAbsPath(Name) then
    TryFile(Name);
  if S = '' then
  begin
    if not IsAbsPath(Name) then
    begin
      if not TryFile(ExeDir + Name) then
        for I := 0 to FSrcDirs.Count - 1 do
        begin
          Dir := IncludeTrailingPathDelimiter(FSrcDirs[I]);
          if TryFile(Dir + Name) then Break;
        end;
    end;
    if S = '' then
    begin
      // by bare file name
      if not TryFile(ExeDir + ExtractFileName(Name)) then
        for I := 0 to FSrcDirs.Count - 1 do
        begin
          Dir := IncludeTrailingPathDelimiter(FSrcDirs[I]);
          if TryFile(Dir + ExtractFileName(Name)) then Break;
        end;
    end;
  end;
  if S = '' then
  begin
    // a breakpoint set by the IDE tells us where a file of that name lives
    Lock;
    try
      for I := 0 to FBreakpoints.Count - 1 do
      begin
        Dir := TDbgBreakpoint(FBreakpoints[I]).FileName;
        if IsAbsPath(Dir) and SameText(ExtractFileName(Dir), ExtractFileName(Name)) and FileExists(Dir) then
        begin
          S := LongPath(ExpandFileName(Dir));
          Break;
        end;
      end;
    finally
      Unlock;
    end;
  end;
  Lock;
  try
    // '*' marks a failed lookup; those are retried after the next AddBreakpoint
    if S = '' then
      M.SrcPaths[Src] := '*' + Name
    else
      M.SrcPaths[Src] := S;
  finally
    Unlock;
  end;
  if S = '' then Result := Name else Result := S;
end;

{ Source file Src of M is FileName: by its name (Name, the file name of FileName) - the debug
  information's name is in the system code page (compared in the IDE's text, SystemToIde), or the
  8.3 name dcc32 was given for a name outside it (CompName, CompilerPath's) -, with Exact also by
  its resolved path }
function TDebugger.MatchSource(M: TDbgModule; Src: Integer; const FileName, Name, CompName: string;
  Exact: Boolean): Boolean;
var
  R, S: string;
begin
  Result := False;
  S := ExtractFileName(M.Info.SrcName[Src]);
  if not SameText(S, Name) and not SameText(S, CompName) and not SameText(SystemToIde(S), Name) then Exit;
  if not Exact then
  begin
    Result := True;
    Exit;
  end;
  R := ResolveSource(M, Src);
  if IsAbsPath(R) and IsAbsPath(FileName) then
    Result := SameText(R, LongPath(ExpandFileName(FileName)))
  else
    Result := False;
end;

{ The code addresses of Line in the source files of the loaded modules that are FileName: sources
  whose resolved path is FileName win; only when they give nothing does the file name alone
  count. True when something was found. }
function TDebugger.LineAddrs(const FileName: string; Line: Integer; out Addrs: TCardinalArray): Boolean;
var
  Pass, I, S, K, N: Integer;
  Mods: TList;
  M: TDbgModule;
  A: TCardinalArray;
  Name, CompName: string;
begin
  Addrs := nil;
  N := 0;
  Name := ExtractFileName(FileName);
  CompName := ExtractFileName(CompilerPath(FileName));
  Mods := TList.Create;
  try
    Lock;
    try
      Mods.Assign(FModules);
    finally
      Unlock;
    end;
    for Pass := 0 to 1 do
    begin
      for I := 0 to Mods.Count - 1 do
      begin
        M := TDbgModule(Mods[I]);
        if M.Info = nil then Continue;
        for S := 0 to M.Info.SrcCount - 1 do
          if MatchSource(M, S, FileName, Name, CompName, Pass = 0) and M.Info.LineToAddrs(S, Line, A) then
            for K := 0 to High(A) do
            begin
              if N >= Length(Addrs) then SetLength(Addrs, N * 2 + 4);
              Addrs[N] := M.Base + A[K];
              Inc(N);
            end;
      end;
      SetLength(Addrs, N);
      Result := N > 0;
      if Result then Break;
    end;
  finally
    Mods.Free;
  end;
end;

function TDebugger.LocationOf(Addr: Cardinal; out Frame: TDbgFrame): Boolean;
var
  M: TDbgModule;
  PI: Integer;
  L: TTDLine;
begin
  Frame.Address := Addr;
  Frame.FrameBase := 0;
  Frame.ProcName := '';
  Frame.ModuleName := '';
  Frame.FileName := '';
  Frame.Line := 0;
  Result := False;
  M := ModuleByAddr(Addr);
  if M = nil then Exit;
  Frame.ModuleName := M.Name;
  Result := True;
  if M.Info = nil then
  begin
    // no debug information: name the frame after the nearest exported symbol
    Frame.ProcName := ExportNameAt(M, Addr);
    Exit;
  end;
  PI := M.Info.ProcByAddr(Addr - M.Base);
  if PI >= 0 then Frame.ProcName := M.Info.ProcName(PI);
  if M.Info.AddrToLine(Addr - M.Base, L) then
  begin
    Frame.Line := L.Line;
    Frame.FileName := ResolveSource(M, L.Src);
  end;
end;

{ stack walking }

function TDebugger.WalkStack(T: TDbgThread; EIP, EBP, ESP: Cardinal; Max: Integer): TFrameExArray;
var
  N: Integer;
  StackTop, RetLoc, Ret, CallerEBP, ProcStart, Tgt, Best, A, V, LookAddr: Cardinal;
  HaveProc, Framed, Found, EbpOK, EbpExact, BestExact: Boolean;
  Info: TInstrInfo;
  Code: array[0..15] of Byte;
  Chunk: array[0..1023] of Cardinal;
  ChunkBase: Cardinal;
  ChunkValid: Boolean;
  ScanEnd: Cardinal;
  ExtraAfterBest: Integer;
  Res: TFrameExArray;

  function StackWord(Addr: Cardinal; out W: Cardinal): Boolean;
  begin
    if not ChunkValid or (Addr < ChunkBase) or (Addr + 4 > ChunkBase + SizeOf(Chunk)) then
    begin
      ChunkBase := Addr;
      ChunkValid := ReadMemRaw(ChunkBase, Chunk, SizeOf(Chunk));
      if not ChunkValid then
      begin
        Result := ReadMemRaw(Addr, W, 4);
        Exit;
      end;
    end;
    W := Chunk[(Addr - ChunkBase) shr 2];
    Result := True;
  end;

  function TargetMatches(Target: Cardinal): Boolean;
  begin
    Result := (Target = ProcStart) or (ThunkTarget(Target) = ProcStart);
  end;

  { no symbols for the code at Addr: a call is taken to be the one that entered it when its
    target (followed through jump thunks) lies shortly before Addr }
  function CalleeNear(Target, Addr: Cardinal): Boolean;
  var
    Hop: Integer;
    Next: Cardinal;
  begin
    for Hop := 1 to 3 do
    begin
      Next := ThunkTarget(Target);
      if (Next = 0) or not IsCodeAddr(Next) then Break;
      Target := Next;
    end;
    Result := (Target <= Addr) and (Addr - Target < $4000);
  end;

begin
  Res := nil;
  N := 0;
  StackTop := 0;
  if (T <> nil) and (T.TLB <> 0) then ReadMemRaw(T.TLB + 4, StackTop, 4);
  if (StackTop <= ESP) or (StackTop - ESP > $4000000) then StackTop := ESP + $100000;
  ChunkValid := False;
  ChunkBase := 0;
  while N < Max do
  begin
    SetLength(Res, N + 1);
    Res[N].Addr := EIP;
    Res[N].EBP := EBP;
    Res[N].ESP := ESP;
    Res[N].RetLoc := 0;
    if (ESP >= StackTop) or (EIP < $10000) then Break;
    if N = 0 then LookAddr := EIP else LookAddr := EIP - 1;
    HaveProc := FindProcStart(LookAddr, ProcStart, Framed);
    Found := False;
    RetLoc := 0;
    CallerEBP := EBP;
    if N = 0 then
    begin
      // exact instruction pointer: prologue / return instruction special cases
      if HaveProc and Framed then
      begin
        if EIP = ProcStart then
        begin
          RetLoc := ESP;
          CallerEBP := EBP;
          Found := True;
        end
        else if EIP = ProcStart + 1 then
        begin
          RetLoc := ESP + 4;
          if not ReadMemRaw(ESP, CallerEBP, 4) then CallerEBP := EBP;
          Found := True;
        end;
      end;
      if not Found and ReadMemory(EIP, Code, SizeOf(Code)) and DecodeInstr(@Code, SizeOf(Code), EIP, Info) and
        (Info.Kind = ikRet) then
      begin
        RetLoc := ESP;
        CallerEBP := EBP;
        Found := True;
      end;
      if Found and not (ReadMemRaw(RetLoc, Ret, 4) and IsReturnAddr(Ret, Tgt)) then Found := False;
    end;
    // candidate through the EBP chain
    EbpOK := False;
    EbpExact := False;
    if not Found and (EBP >= ESP) and (EBP + 8 <= StackTop) and ((EBP and 3) = 0) and
      ReadMemRaw(EBP + 4, Ret, 4) and IsReturnAddr(Ret, Tgt) then
    begin
      EbpOK := True;
      EbpExact := not HaveProc or (Tgt = 0) or TargetMatches(Tgt);
    end;
    if not Found and EbpOK and EbpExact and HaveProc and Framed then
    begin
      RetLoc := EBP + 4;
      if not ReadMemRaw(EBP, CallerEBP, 4) then CallerEBP := 0;
      Found := True;
    end;
    if not Found then
    begin
      // scan the stack for a plausible return address
      Best := 0;
      BestExact := False;
      ExtraAfterBest := 0;
      A := (ESP + 3) and not Cardinal(3);
      ScanEnd := A + $8000;
      if ScanEnd > StackTop then ScanEnd := StackTop;
      if EbpOK and (EBP + 8 < ScanEnd) and (Framed or not HaveProc) then ScanEnd := EBP + 8;
      while A + 4 <= ScanEnd do
      begin
        if not StackWord(A, V) then Break;
        if (V >= $10000) and IsCodeAddr(V) and IsReturnAddr(V, Tgt) then
        begin
          if not HaveProc then
          begin
            // module without symbols (system DLL, runtime package)
            if (Tgt <> 0) and CalleeNear(Tgt, LookAddr) then
            begin
              Best := A;
              BestExact := True;
              Break;
            end;
            if (Tgt = 0) and (Best = 0) and not EbpOK then Best := A;
          end
          else if (Tgt <> 0) and TargetMatches(Tgt) then
          begin
            Best := A;
            BestExact := True;
            Break;
          end;
          if HaveProc and (Tgt = 0) and (Best = 0) then Best := A;     // indirect call: possible
        end;
        if Best <> 0 then
        begin
          Inc(ExtraAfterBest);
          if ExtraAfterBest > 96 then Break;
        end;
        Inc(A, 4);
      end;
      if (Best <> 0) and EbpOK and not BestExact and (Best >= EBP) then Best := 0;
      if (Best <> 0) and EbpOK and (Best = EBP + 4) then Best := 0;    // that is the frame pointer's own slot
      if Best <> 0 then
      begin
        RetLoc := Best;
        Found := True;
        CallerEBP := EBP;
        if HaveProc and Framed and (RetLoc >= ESP + 4) and ((N > 0) or (EIP >= ProcStart + 3)) then
        begin
          // a framed routine saved the caller's EBP right below its return address, and its
          // own frame pointer is the address of that slot
          if ReadMemRaw(RetLoc - 4, V, 4) and (V > RetLoc) and (V < StackTop) and ((V and 3) = 0) then
          begin
            CallerEBP := V;
            Res[N].EBP := RetLoc - 4;
          end;
        end;
      end
      else if EbpOK then
      begin
        // nothing better: trust the frame pointer
        RetLoc := EBP + 4;
        if not ReadMemRaw(EBP, CallerEBP, 4) then CallerEBP := 0;
        Found := True;
      end;
    end;
    if not Found or not ReadMemRaw(RetLoc, Ret, 4) then Break;
    Res[N].RetLoc := RetLoc;
    // frames must move up the stack (which also keeps the walk from running in circles)
    if RetLoc + 4 <= ESP then Break;
    ESP := RetLoc + 4;
    EBP := CallerEBP;
    EIP := Ret;
    Inc(N);
  end;
  Result := Res;
end;

function TDebugger.CurFrames: TFrameExArray;
var
  Ctx: TContext;
begin
  if not FFramesValid then
  begin
    FFrames := nil;
    if FCurThread <> nil then
    begin
      if FOverrideCtx then
        FFrames := WalkStack(FCurThread, FOvEIP, FOvEBP, FOvESP, MAX_STACK_FRAMES)
      else if GetCtx(FCurThread, Ctx) then
        FFrames := WalkStack(FCurThread, Ctx.Eip, Ctx.Ebp, Ctx.Esp, MAX_STACK_FRAMES);
    end;
    FFramesValid := True;
  end;
  Result := FFrames;
end;

function TDebugger.FrameToPublic(const F: TFrameEx; Index: Integer): TDbgFrame;
var
  A: Cardinal;
begin
  A := F.Addr;
  if Index > 0 then Dec(A);      // inside the call instruction: the calling line
  LocationOf(A, Result);
  Result.Address := F.Addr;
  Result.FrameBase := F.EBP;
end;

{ the first frame of Fx at a source line (by its address as FrameToPublic takes it), -1: none -
  found without the names of the frames before it }
function TDebugger.FirstSourceFrame(const Fx: TFrameExArray): Integer;
var
  I: Integer;
  A: Cardinal;
  M: TDbgModule;
  L: TTDLine;
begin
  Result := -1;
  for I := 0 to High(Fx) do
  begin
    A := Fx[I].Addr;
    if I > 0 then Dec(A);
    if FindLineAbs(A, M, L) and (L.Line > 0) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

{ breakpoint locations }

function TDebugger.FindLoc(Addr: Cardinal): TBPLoc;
var
  I: Integer;
begin
  for I := 0 to FLocs.Count - 1 do
  begin
    Result := TBPLoc(FLocs[I]);
    if Result.Addr = Addr then Exit;
  end;
  Result := nil;
end;

function TDebugger.GetLoc(Addr: Cardinal): TBPLoc;
begin
  Result := FindLoc(Addr);
  if Result = nil then
  begin
    Result := TBPLoc.Create;
    Result.Addr := Addr;
    FLocs.Add(Result);
  end;
end;

function TDebugger.HasEnabledBP(Loc: TBPLoc): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Loc <> nil then
    for I := 0 to Loc.UserBPs.Count - 1 do
      if TDbgBreakpoint(Loc.UserBPs[I]).Enabled then
      begin
        Result := True;
        Exit;
      end;
end;

function TDebugger.EnabledBPAt(Addr: Cardinal): Boolean;
begin
  Lock;
  try
    Result := HasEnabledBP(FindLoc(Addr));
  finally
    Unlock;
  end;
end;

procedure TDebugger.UpdateLoc(Loc: TBPLoc);
var
  Want: Boolean;
  B: Byte;
begin
  Want := (Loc.TempRefs > 0) or HasEnabledBP(Loc);
  if Want and not Loc.Installed and (FProcessHandle <> 0) then
  begin
    if ReadMemRaw(Loc.Addr, B, 1) then
    begin
      Loc.OrigByte := B;
      if WriteCodeByte(Loc.Addr, $CC) then Loc.Installed := True;
    end;
  end
  else if not Want and Loc.Installed then
  begin
    if FProcessHandle <> 0 then WriteCodeByte(Loc.Addr, Loc.OrigByte);
    Loc.Installed := False;
  end;
  if (Loc.TempRefs <= 0) and (Loc.UserBPs.Count = 0) and not Loc.Installed then
  begin
    FLocs.Remove(Loc);
    Loc.Free;
  end;
end;

procedure TDebugger.UnresolveBP(BP: TDbgBreakpoint);
var
  I: Integer;
  Loc: TBPLoc;
begin
  for I := FLocs.Count - 1 downto 0 do
  begin
    Loc := TBPLoc(FLocs[I]);
    if Loc.UserBPs.Remove(BP) >= 0 then UpdateLoc(Loc);
  end;
  BP.Valid := False;
end;

{ BP at the code address Addr (its location made when there is none, its int 3 as BP wants) }
procedure TDebugger.PlaceBP(BP: TDbgBreakpoint; Addr: Cardinal);
var
  Loc: TBPLoc;
begin
  Loc := GetLoc(Addr);
  if Loc.UserBPs.IndexOf(BP) < 0 then Loc.UserBPs.Add(BP);
  UpdateLoc(Loc);
end;

procedure TDebugger.ResolveBP(BP: TDbgBreakpoint);
var
  Addrs: TCardinalArray;
  I: Integer;
  B: Byte;
begin
  UnresolveBP(BP);
  if FProcessHandle = 0 then Exit;
  case BP.Kind of
    bkAddress:
      { valid where there is memory (a module that is loaded later resolves it then) }
      if ReadMemRaw(BP.Address, B, 1) then
      begin
        PlaceBP(BP, BP.Address);
        BP.Valid := True;
      end;
    bkData:
      FDataDirty := True;             // ApplyDataBPs gives it a debug register, and decides Valid
    bkModule:
      BP.Valid := True;
  end;
  if BP.Kind <> bkSource then Exit;
  if LineAddrs(BP.FileName, BP.Line, Addrs) then
  begin
    for I := 0 to High(Addrs) do PlaceBP(BP, Addrs[I]);
    BP.Valid := True;
  end;
end;

procedure TDebugger.ResolveAllBPs;
var
  I: Integer;
begin
  for I := 0 to FBreakpoints.Count - 1 do ResolveBP(TDbgBreakpoint(FBreakpoints[I]));
end;

{ Module M was loaded: the source breakpoints that have code in it get those locations, an address
  breakpoint without memory before is resolved again. The locations there are stay as they are:
  resolving everything again rewrote every int 3 at each DLL load - also the one a thread was
  stepping over just then (lifted), which then hit twice. Under the lock. }
procedure TDebugger.ResolveBPsIn(M: TDbgModule);
var
  I, K: Integer;
  BP: TDbgBreakpoint;
  Addrs: TCardinalArray;
begin
  if FProcessHandle = 0 then Exit;
  for I := 0 to FBreakpoints.Count - 1 do
  begin
    BP := TDbgBreakpoint(FBreakpoints[I]);
    case BP.Kind of
      bkSource:
        if (M.Info <> nil) and LineAddrs(BP.FileName, BP.Line, Addrs) then
          for K := 0 to High(Addrs) do
            if (Addrs[K] >= M.Base) and (Addrs[K] - M.Base < M.Size) then
            begin
              PlaceBP(BP, Addrs[K]);
              BP.Valid := True;
            end;
      bkAddress:
        if not BP.Valid then ResolveBP(BP);
    end;
  end;
end;

{ a module went: its locations with it; a breakpoint is valid as long as it has a location left }
procedure TDebugger.RemoveLocsInRange(Lo, Hi: Cardinal);
var
  I, J: Integer;
  Loc: TBPLoc;
  Gone: TList;
  BP: TDbgBreakpoint;
begin
  Gone := TList.Create;
  try
    for I := FLocs.Count - 1 downto 0 do
    begin
      Loc := TBPLoc(FLocs[I]);
      if (Loc.Addr >= Lo) and (Loc.Addr < Hi) then
      begin
        for J := 0 to Loc.UserBPs.Count - 1 do Gone.Add(Loc.UserBPs[J]);
        FLocs.Delete(I);
        Loc.Free;
      end;
    end;
    for I := 0 to Gone.Count - 1 do
    begin
      BP := TDbgBreakpoint(Gone[I]);
      BP.Valid := False;
      for J := 0 to FLocs.Count - 1 do
        if TBPLoc(FLocs[J]).UserBPs.IndexOf(BP) >= 0 then
        begin
          BP.Valid := True;
          Break;
        end;
    end;
  finally
    Gone.Free;
  end;
end;

procedure TDebugger.AddTemp(Addr, ThreadId: Cardinal; Check: TTempCheck; Limit: Cardinal; Purpose: TTempPurpose);
var
  N: Integer;
  Loc: TBPLoc;
begin
  Lock;
  try
    N := Length(FTemps);
    SetLength(FTemps, N + 1);
    FTemps[N].Addr := Addr;
    FTemps[N].ThreadId := ThreadId;
    FTemps[N].Check := Check;
    FTemps[N].Limit := Limit;
    FTemps[N].Purpose := Purpose;
    Loc := GetLoc(Addr);
    Inc(Loc.TempRefs);
    UpdateLoc(Loc);
  finally
    Unlock;
  end;
end;

procedure TDebugger.RemoveTemp(Index: Integer);
var
  Loc: TBPLoc;
  I: Integer;
begin
  Lock;
  try
    if (Index < 0) or (Index > High(FTemps)) then Exit;
    Loc := FindLoc(FTemps[Index].Addr);
    for I := Index to High(FTemps) - 1 do FTemps[I] := FTemps[I + 1];
    SetLength(FTemps, Length(FTemps) - 1);
    if Loc <> nil then
    begin
      Dec(Loc.TempRefs);
      UpdateLoc(Loc);
    end;
  finally
    Unlock;
  end;
end;

procedure TDebugger.ClearTemps;
begin
  while Length(FTemps) > 0 do RemoveTemp(High(FTemps));
end;

procedure TDebugger.ClearStep;
begin
  FStep.Active := False;
  FStep.ExpectSS := False;
  ClearTemps;
end;

function TDebugger.FindTemp(Addr: Cardinal; T: TDbgThread; const Ctx: TContext): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FTemps) do
    if (FTemps[I].Addr = Addr) and ((FTemps[I].ThreadId = 0) or (FTemps[I].ThreadId = T.ThreadId)) then
    begin
      case FTemps[I].Check of
        tcESP: if Ctx.Esp < FTemps[I].Limit then Continue;
        tcEBP: if Ctx.Ebp < FTemps[I].Limit then Continue;
      end;
      Result := I;
      Exit;
    end;
end;

function TDebugger.EvalCondition(T: TDbgThread; const Cond: string): Boolean;
var
  Ev: TDbgEvaluator;
  Ctx: TContext;
  Err: string;
begin
  Result := True;
  if not GetCtx(T, Ctx) then Exit;
  Ev := NewEvaluator(T, Ctx.Eip, Ctx.Ebp, True);
  try
    Ev.AllowCalls := True;
    if not Ev.EvalBoolean(Cond, Result, Err) then
    begin
      // a condition that cannot be evaluated stops the program so the user notices
      Result := True;
      QueueLog(lkBreakpoint, Format('Breakpoint condition "%s" cannot be evaluated: %s', [Cond, Err]));
    end;
  finally
    Ev.Free;
  end;
end;

{ Whether the user breakpoints at Addr stop thread T (counting the pass, doing their actions). The
  IDE may remove a breakpoint - and free it and its location - at any time: a copy of the list,
  taken under the lock (BPStops checks each again). }
function TDebugger.UserBPShouldStop(Addr: Cardinal; T: TDbgThread): Boolean;
var
  I: Integer;
  Loc: TBPLoc;
  L: TList;
begin
  Result := False;
  L := TList.Create;
  try
    Lock;
    try
      Loc := FindLoc(Addr);
      if Loc <> nil then L.Assign(Loc.UserBPs);
    finally
      Unlock;
    end;
    for I := 0 to L.Count - 1 do
      if BPStops(TDbgBreakpoint(L[I]), T) then Result := True;
  finally
    L.Free;
  end;
end;

{ A hit of BP by thread T: whether it counts - BP is still there and enabled, its condition holds,
  its pass is reached (counted) - and then its actions (Delphi's: exceptions, log message, eval
  expression, the groups); whether it stops the program. A breakpoint that asks (AskTrigger) is
  decided by the IDE first. The condition and the expression to evaluate may call the program's
  code for seconds: they run without the lock (the IDE changes breakpoints meanwhile - F5, the
  gutter, the check boxes), on what was read under it, and BP is checked again by its Id
  afterwards. }
function TDebugger.BPStops(BP: TDbgBreakpoint; T: TDbgThread): Boolean;
var
  Id: Cardinal;
  Cond: string;
  Ask: Boolean;
begin
  Result := False;
  Lock;
  try
    if (FBreakpoints.IndexOf(BP) < 0) or not BP.Enabled then Exit;
    Id := BP.Id;
    Cond := BP.Condition;
    Ask := BP.AskTrigger and Assigned(FOnTrigger);
  finally
    Unlock;
  end;
  if Ask then
    case AskTrigger(Id, T) of
      tgStop:
        begin
          Result := True;
          Exit;
        end;
      tgContinue:
        Exit;
    end;
  Result := DefaultHit(BP, Id, Cond, T);
end;

function TDebugger.DefaultTrigger(BreakpointId: Cardinal): Boolean;
var
  B: TDbgBreakpoint;
  Cond: string;
begin
  Result := True;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  Lock;
  try
    B := BreakpointById(BreakpointId);
    if (B = nil) or not B.Enabled then Exit;
    Cond := B.Condition;
  finally
    Unlock;
  end;
  Result := DefaultHit(B, BreakpointId, Cond, FCurThread);
end;

{ what a hit of BP (Id, its condition Cond) by thread T does by default: whether it counts, then
  its actions; whether it stops the program }
function TDebugger.DefaultHit(BP: TDbgBreakpoint; Id: Cardinal; const Cond: string; T: TDbgThread): Boolean;
var
  LogMsg, Expr, EnGroup, DisGroup, V: string;
  LogRes, IgnoreExc, HandleExc: Boolean;
begin
  Result := False;
  if (Cond <> '') and not EvalCondition(T, Cond) then Exit;
  Lock;
  try
    if (FBreakpoints.IndexOf(BP) < 0) or (BP.Id <> Id) or not BP.Enabled then Exit;
    if BP.PassCount <= BP.HitCount then BP.HitCount := 0;
    Inc(BP.HitCount);
    if BP.PassCount > BP.HitCount then Exit;
    Result := BP.DoBreak;
    IgnoreExc := BP.IgnoreExceptions;
    HandleExc := BP.HandleExceptions;
    LogMsg := BP.LogMessage;
    Expr := BP.EvalExpr;
    LogRes := BP.LogResult;
    EnGroup := BP.EnableGroup;
    DisGroup := BP.DisableGroup;
  finally
    Unlock;
  end;
  if IgnoreExc then FIgnoreAll := True;
  if HandleExc then FIgnoreAll := False;
  if LogMsg <> '' then
    QueueLog(lkBreakpoint, Format('Breakpoint Message: %s. Process %s (%d)', [LogMsg, ExeBaseName, FProcessId]));
  if Expr <> '' then
  begin
    V := EvalText(T, Expr);
    if LogRes then
      QueueLog(lkBreakpoint, Format('Breakpoint Expression %s: %s. Process %s (%d)', [Expr, V, ExeBaseName, FProcessId]));
  end;
  if (EnGroup <> '') or (DisGroup <> '') then SetGroups(EnGroup, DisGroup);
end;

{ The hit of breakpoint Id by thread T, asked of the IDE first (OnTrigger). The program stands for
  it as at a stop, but none is reported: the IDE may inspect thread T (the calls of the program's
  code it makes are served here) and answers with a resume (DispatchEvents) - any other command,
  or the end of the session, is the default. }
function TDebugger.AskTrigger(Id: Cardinal; T: TDbgThread): TDbgTrigger;
var
  E: TQueuedEvent;
  Cmd: TDbgCmd;
begin
  E := TQueuedEvent.Create;
  E.Kind := evTrigger;
  E.BreakpointId := Id;
  Lock;
  try
    FTrigger := tgDefault;
    FCurThread := T;
    ForgetFrames;
    FCurrentFrame := 0;
    FOverrideCtx := False;
    FPendingCmd := dcNone;
    Inc(FStandCount);
    E.Seq := FStandCount;          // the answer is this stand's (DispatchEvents)
    FState := dsPaused;
  finally
    Unlock;
  end;
  Enqueue(E);
  Cmd := WaitServingCalls;
  Lock;
  try
    if FState = dsPaused then FState := dsRunning;
    if Cmd = dcResume then Result := FTrigger else Result := tgDefault;
  finally
    Unlock;
  end;
end;

{ a breakpoint's Enable group / Disable group: the breakpoints of those groups }
procedure TDebugger.SetGroups(const EnableGroup, DisableGroup: string);
var
  I: Integer;
  B: TDbgBreakpoint;
  Changed, NewState: Boolean;
begin
  Changed := False;
  Lock;
  try
    for I := 0 to FBreakpoints.Count - 1 do
    begin
      B := TDbgBreakpoint(FBreakpoints[I]);
      if B.Group = '' then Continue;
      NewState := SameText(B.Group, EnableGroup);
      if not NewState and not SameText(B.Group, DisableGroup) then Continue;
      if B.Enabled = NewState then Continue;
      B.Enabled := NewState;
      BreakpointChanged(B);
      Changed := True;
    end;
  finally
    Unlock;
  end;
  if Changed then QueueBPsChanged;
end;

{ Expr in T's frame as text: its value, or why there is none }
function TDebugger.EvalText(T: TDbgThread; const Expr: string): string;
var
  Ev: TDbgEvaluator;
  Ctx: TContext;
  V: TDbgVar;
  Err: string;
begin
  Result := '';
  if not GetCtx(T, Ctx) then Exit;
  Ev := NewEvaluator(T, Ctx.Eip, Ctx.Ebp, True);
  try
    Ev.AllowCalls := True;
    if Ev.Evaluate(Expr, V, Err) then Result := V.Value else Result := Err;
  finally
    Ev.Free;
  end;
end;

function TDebugger.HasBPKind(Kind: TDbgBPKind): Boolean;
var
  I: Integer;
begin
  Result := False;
  Lock;
  try
    for I := 0 to FBreakpoints.Count - 1 do
      if TDbgBreakpoint(FBreakpoints[I]).Kind = Kind then
      begin
        Result := True;
        Exit;
      end;
  finally
    Unlock;
  end;
end;

{ an exception of class Cls is reported: not one of the ignored classes, and no breakpoint said
  'Ignore subsequent exceptions' }
function TDebugger.ReportsException(const Cls: string): Boolean;
begin
  Result := not FIgnoreAll and (FIgnored.IndexOf(Cls) < 0);
end;

{ The data breakpoints in the processor's debug registers of every thread: the first four that
  are enabled, a write of their length to their address (aligned to it) each; the others are not
  valid. Called by the debug thread (all threads of the program stand still then). }
procedure TDebugger.ApplyDataBPs;
const
  LenBits: array[1..4] of Cardinal = (0, 1, 0, 3);
  RWBits: array[Boolean] of Cardinal = (1, 3);     // a write; a read or a write
var
  I, N: Integer;
  BP: TDbgBreakpoint;
  Dr7: Cardinal;
  Addr: array[0..3] of Cardinal;
  Ctx: TContext;
  Ok: Boolean;
begin
  Lock;
  try
    FDataDirty := False;
    FillChar(FDataSlots, SizeOf(FDataSlots), 0);
    FillChar(Addr, SizeOf(Addr), 0);
    N := 0;
    Dr7 := 0;
    for I := 0 to FBreakpoints.Count - 1 do
    begin
      BP := TDbgBreakpoint(FBreakpoints[I]);
      if BP.Kind <> bkData then Continue;
      Ok := (FProcessHandle <> 0) and (BP.DataLength in [1, 2, 4]) and (BP.Address mod Cardinal(BP.DataLength) = 0);
      BP.Valid := Ok and (not BP.Enabled or (N < 4));
      if not (Ok and BP.Enabled and (N < 4)) then Continue;
      FDataSlots[N] := BP;
      Addr[N] := BP.Address;
      Dr7 := Dr7 or (Cardinal(1) shl (N * 2)) or (RWBits[BP.DataRead] shl (16 + N * 4)) or
        (LenBits[BP.DataLength] shl (18 + N * 4));
      Inc(N);
    end;
    for I := 0 to FThreads.Count - 1 do
    begin
      FillChar(Ctx, SizeOf(Ctx), 0);
      Ctx.ContextFlags := CONTEXT_DEBUG_REGISTERS;
      if not GetThreadContext(TDbgThread(FThreads[I]).Handle, Ctx) then Continue;
      Ctx.Dr0 := Addr[0];
      Ctx.Dr1 := Addr[1];
      Ctx.Dr2 := Addr[2];
      Ctx.Dr3 := Addr[3];
      Ctx.Dr7 := Dr7;
      SetThreadContext(TDbgThread(FThreads[I]).Handle, Ctx);
    end;
  finally
    Unlock;
  end;
end;

{ whether a debug register trapped T (its status is cleared): BP its data breakpoint (nil when it
  has gone meanwhile); Traced: the trap flag's step happened as well. False: the step alone. }
function TDebugger.DataHit(T: TDbgThread; out BP: TDbgBreakpoint; out Traced: Boolean): Boolean;
var
  Ctx: TContext;
  I: Integer;
begin
  BP := nil;
  Traced := True;
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.ContextFlags := CONTEXT_DEBUG_REGISTERS;
  Result := GetThreadContext(T.Handle, Ctx) and (Ctx.Dr6 and $F <> 0);
  if not Result then Exit;
  Traced := Ctx.Dr6 and $4000 <> 0;
  Lock;
  try
    for I := 0 to 3 do
      if Ctx.Dr6 and (Cardinal(1) shl I) <> 0 then
      begin
        BP := FDataSlots[I];
        Break;
      end;
  finally
    Unlock;
  end;
  Ctx.Dr6 := 0;
  SetThreadContext(T.Handle, Ctx);
end;

function TDebugger.DataBPStops(BP: TDbgBreakpoint; T: TDbgThread; out Msg: string): Boolean;
begin
  Msg := '';
  Result := False;
  if BP = nil then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    Msg := Format('Data Breakpoint: $%.8x, length %d', [BP.Address, BP.DataLength]);
  finally
    Unlock;
  end;
  Result := BPStops(BP, T);
  if not Result then Msg := '';
end;

{ the module load breakpoints of the module at Path (by its path, its file name, or its name
  without the extension): whether one stops the program }
function TDebugger.ModuleBPStops(const Path: string; T: TDbgThread): Boolean;
var
  I: Integer;
  BP: TDbgBreakpoint;
  L: TList;
  N: string;
begin
  Result := False;
  if (T = nil) or FInCall then Exit;
  L := TList.Create;
  try
    Lock;
    try
      for I := 0 to FBreakpoints.Count - 1 do
      begin
        BP := TDbgBreakpoint(FBreakpoints[I]);
        if BP.Kind <> bkModule then Continue;
        N := ExtractFileName(BP.FileName);
        if SameText(BP.FileName, Path) or SameText(N, ExtractFileName(Path)) or
          SameText(N, ChangeFileExt(ExtractFileName(Path), '')) then L.Add(BP);
      end;
    finally
      Unlock;
    end;
    for I := 0 to L.Count - 1 do
      if BPStops(TDbgBreakpoint(L[I]), T) then Result := True;
  finally
    L.Free;
  end;
end;

{ stepping }

procedure TDebugger.Arm(T: TDbgThread; WantSS: Boolean);
var
  Ctx: TContext;
  Loc: TBPLoc;
  Lift: Boolean;
begin
  if FDetaching or (T = nil) or not GetCtx(T, Ctx) then Exit;
  Lift := False;
  if (T.AtBP <> 0) and (T.AtBP = Ctx.Eip) then
  begin
    Lock;
    try
      Loc := FindLoc(Ctx.Eip);
      if (Loc <> nil) and Loc.Installed then
      begin
        WriteCodeByte(Loc.Addr, Loc.OrigByte);
        Lift := True;
      end;
    finally
      Unlock;
    end;
  end;
  T.AtBP := 0;
  if Lift then
  begin
    T.SteppingOverBP := Ctx.Eip;
    SuspendOthers(T);
  end;
  if Lift or WantSS then
  begin
    Ctx.EFlags := Ctx.EFlags or TRAP_FLAG;
    SetCtx(T, Ctx);
  end;
end;

function TDebugger.IsThunkInstr(Addr: Cardinal): Boolean;
var
  Code: array[0..15] of Byte;
  Info: TInstrInfo;
begin
  Result := False;
  if not ReadMemory(Addr, Code, SizeOf(Code)) then Exit;
  if not DecodeInstr(@Code, SizeOf(Code), Addr, Info) then Exit;
  if Info.Kind = ikJmp then
    Result := True
  // interface method stubs: add dword ptr [esp+4],imm / add eax,imm  followed by a jmp
  else if (Code[0] = $83) and (Code[1] = $44) and (Code[2] = $24) and (Code[3] = $04) then
    Result := True
  else if (Code[0] = $81) and (Code[1] = $44) and (Code[2] = $24) and (Code[3] = $04) then
    Result := True
  else if (Code[0] = $05) or ((Code[0] = $83) and (Code[1] = $C0)) then
    Result := (Code[Info.Len] = $E9) or (Code[Info.Len] = $EB) or (Code[Info.Len] = $FF);
end;

function TDebugger.SetupRangeRun(T: TDbgThread; const Ctx: TContext): Boolean;
var
  Code: array of Byte;
  Size, P, N, I: Integer;
  Info: TInstrInfo;
  Targets: array of Cardinal;
  HasRet: Boolean;
  Frames: TFrameExArray;
  A: Cardinal;

  procedure AddTarget(Addr: Cardinal);
  var
    K: Integer;
  begin
    for K := 0 to N - 1 do
      if Targets[K] = Addr then Exit;
    SetLength(Targets, N + 1);
    Targets[N] := Addr;
    Inc(N);
  end;

begin
  Result := False;
  Size := FStep.RangeHi - FStep.RangeLo;
  if (Size <= 0) or (Size > 8192) then Exit;
  SetLength(Code, Size + 16);
  FillChar(Code[0], Size + 16, 0);
  if not ReadMemory(FStep.RangeLo, Code[0], Size) then Exit;
  N := 0;
  HasRet := False;
  P := 0;
  while P < Size do
  begin
    A := FStep.RangeLo + Cardinal(P);
    if not DecodeInstr(@Code[P], Size - P, A, Info) then Exit;
    case Info.Kind of
      ikJmp, ikJcc:
        begin
          if Info.Indirect or not Info.HasTarget then Exit;
          if (Info.Target < FStep.RangeLo) or (Info.Target >= FStep.RangeHi) then AddTarget(Info.Target);
        end;
      ikRet:
        HasRet := True;
      ikCall:
        // stepping into: calls may lead to code with source, keep single stepping
        if FStep.Kind = skInto then Exit;
      ikInt3, ikInvalid:
        Exit;
    end;
    Inc(P, Info.Len);
  end;
  if P <> Size then Exit;           // data inside the range: do not trust the decoding
  AddTarget(FStep.RangeHi);
  if HasRet then
  begin
    Frames := WalkStack(T, Ctx.Eip, Ctx.Ebp, Ctx.Esp, 4);
    if Length(Frames) < 2 then Exit;
    AddTemp(Frames[1].Addr, T.ThreadId, tcESP, Frames[0].RetLoc + 4, tpRangeRet);
  end;
  for I := 0 to N - 1 do AddTemp(Targets[I], T.ThreadId, tcEBP, Ctx.Ebp, tpRangeExit);
  FStep.ExpectSS := False;
  Result := True;
end;

function TDebugger.StepInstr(T: TDbgThread; const Ctx: TContext): Boolean;
var
  Code: array[0..15] of Byte;
  Info: TInstrInfo;
begin
  Result := True;
  FStep.LastWasRet := False;
  FStep.InCall := False;
  if ReadMemory(Ctx.Eip, Code, SizeOf(Code)) and DecodeInstr(@Code, SizeOf(Code), Ctx.Eip, Info) then
  begin
    FStep.LastWasRet := Info.Kind = ikRet;
    if Info.Kind = ikCall then
    begin
      if FStep.Kind = skOver then
      begin
        AddTemp(Ctx.Eip + Cardinal(Info.Len), T.ThreadId, tcESP, Ctx.Esp, tpStepOverCall);
        Result := False;
      end
      else
      begin
        FStep.InCall := True;
        FStep.CallRet := Ctx.Eip + Cardinal(Info.Len);
        FStep.CallESP := Ctx.Esp;
        FStep.ThunkHops := 0;
      end;
    end
    else if Info.RepPrefix and Info.IsString then
    begin
      AddTemp(Ctx.Eip + Cardinal(Info.Len), T.ThreadId, tcNone, 0, tpStepOverCall);
      Result := False;
    end;
  end;
  FStep.ExpectSS := Result;
end;

function TDebugger.SetupReturnToLineInfo(T: TDbgThread): Boolean;
var
  Ctx: TContext;
  Frames: TFrameExArray;
  I: Integer;
begin
  Result := False;
  if not GetCtx(T, Ctx) then Exit;
  Frames := WalkStack(T, Ctx.Eip, Ctx.Ebp, Ctx.Esp, MAX_STACK_FRAMES);
  for I := 1 to High(Frames) do
    if HasLineAbs(Frames[I].Addr) or HasLineAbs(Frames[I].Addr - 1) then
    begin
      AddTemp(Frames[I].Addr, T.ThreadId, tcESP, Frames[I - 1].RetLoc + 4, tpStepReturn);
      FStep.ExpectSS := False;
      FStep.Passive := True;
      FStep.PassiveTick := GetTickCount;
      Result := True;
      Exit;
    end;
end;

function TDebugger.BeginStep(T: TDbgThread; Kind: TStepKind; out WantSS: Boolean): Boolean;
var
  Ctx: TContext;
  M: TDbgModule;
  L: TTDLine;
begin
  Result := False;
  WantSS := False;
  FillChar(FStep, SizeOf(FStep), 0);
  if not GetCtx(T, Ctx) then Exit;
  FStep.Active := True;
  FStep.Kind := Kind;
  FStep.ThreadId := T.ThreadId;
  if FStopIsException and (FStopExcThreadId = T.ThreadId) then
  begin
    // stepping after an exception notification: stop at the handler that will run
    FStep.AwaitHandler := True;
    FStep.StartEBP := 0;
    Result := True;
    Exit;
  end;
  if not FindLineAbs(Ctx.Eip, M, L) then
  begin
    // no source here: run until we are back in code that has line numbers
    if SetupReturnToLineInfo(T) then
      Result := True
    else
      FStep.Active := False;
    Exit;
  end;
  FStep.RangeLo := M.Base + L.Addr;
  FStep.RangeHi := M.Base + L.EndAddr;
  FStep.StartLine := L.Line;
  FStep.StartSrc := L.Src;
  FStep.StartInfo := M.Info;
  FStep.StartEBP := Ctx.Ebp;
  WantSS := StepInstr(T, Ctx);
  Result := True;
end;

procedure TDebugger.BeginStepOut(T: TDbgThread);
var
  Ctx: TContext;
  Frames: TFrameExArray;
begin
  FillChar(FStep, SizeOf(FStep), 0);
  if not GetCtx(T, Ctx) then Exit;
  if FStopIsException and (FStopExcThreadId = T.ThreadId) then Exit;
  Frames := WalkStack(T, Ctx.Eip, Ctx.Ebp, Ctx.Esp, 8);
  if Length(Frames) < 2 then Exit;
  FStep.Active := True;
  FStep.Kind := skOut;
  FStep.ThreadId := T.ThreadId;
  FStep.StartEBP := Frames[1].EBP;
  AddTemp(Frames[1].Addr, T.ThreadId, tcESP, Frames[0].RetLoc + 4, tpStepOut);
end;

function TDebugger.StepAdvance(T: TDbgThread; out WantSS: Boolean): Boolean;
var
  Ctx: TContext;
  EIP: Cardinal;
  M: TDbgModule;
  L: TTDLine;
  Same, InRange: Boolean;
  Loc: TBPLoc;
begin
  Result := False;
  WantSS := False;
  if not GetCtx(T, Ctx) then
  begin
    FStep.Active := False;
    Exit;
  end;
  EIP := Ctx.Eip;
  if FStep.InCall then
  begin
    FStep.InCall := False;
    if not HasLineAbs(EIP) then
    begin
      // the called routine has no line numbers: follow jump thunks, otherwise run to the return
      if (FStep.ThunkHops < 4) and IsThunkInstr(EIP) then
      begin
        Inc(FStep.ThunkHops);
        FStep.InCall := True;
        FStep.LastWasRet := False;
        FStep.ExpectSS := True;
        WantSS := True;
        Exit;
      end;
      AddTemp(FStep.CallRet, T.ThreadId, tcESP, FStep.CallESP, tpStepOverCall);
      FStep.ExpectSS := False;
      Exit;
    end;
  end;
  InRange := (EIP >= FStep.RangeLo) and (EIP < FStep.RangeHi);
  if InRange and not FStep.LastWasRet then
  begin
    // still on the same line; a loop that stays inside one line is run with breakpoints on
    // its exits instead of millions of single steps
    Inc(FStep.Steps);
    if (FStep.Steps > 200) and not FStep.RangeTried then
    begin
      FStep.RangeTried := True;
      if SetupRangeRun(T, Ctx) then Exit;
    end;
    WantSS := StepInstr(T, Ctx);
    Exit;
  end;
  if FindLineAbs(EIP, M, L) then
  begin
    Same := (M.Info = FStep.StartInfo) and (L.Line = FStep.StartLine) and (L.Src = FStep.StartSrc);
    if Same and not FStep.LastWasRet then
    begin
      // another piece of code belonging to the same source line
      FStep.RangeLo := M.Base + L.Addr;
      FStep.RangeHi := M.Base + L.EndAddr;
      FStep.RangeTried := False;
      WantSS := StepInstr(T, Ctx);
      Exit;
    end;
    // the step is complete
    FStep.Active := False;
    FStep.ExpectSS := False;
    FStepStopReason := srStep;
    // the step arrived on an int 3 of ours without running it: Arm steps over it - running it
    // would report (and count) the breakpoint a second time
    Lock;
    try
      Loc := FindLoc(EIP);
      if (Loc <> nil) and Loc.Installed then T.AtBP := EIP;
    finally
      Unlock;
    end;
    if UserBPShouldStop(EIP, T) then FStepStopReason := srBreakpoint;
    Result := True;
    Exit;
  end;
  // left the code that has line numbers (e.g. returned into the RTL)
  if not SetupReturnToLineInfo(T) then
  begin
    FStep.Active := False;
    FStep.ExpectSS := False;
  end;
end;

{ command handling (debug thread) }

function TDebugger.WaitForCommand: TDbgCmd;
begin
  repeat
    if FTerminating then
    begin
      Result := dcResume;
      Exit;
    end;
    WaitForSingleObject(FCmdEvent, 100);
    Lock;
    try
      Result := FPendingCmd;
      FPendingCmd := dcNone;
    finally
      Unlock;
    end;
  until Result <> dcNone;
end;

{ The IDE's command for a stand of the program (a stop, a breakpoint's trigger). The evaluator's
  calls are served meanwhile (no stop is reported for them); the frames read while it stood are
  outdated afterwards - the calls ran its code, or it runs on now. }
function TDebugger.WaitServingCalls: TDbgCmd;
begin
  Result := WaitForCommand;
  while Result = dcCall do
  begin
    ServeCall;
    Result := WaitForCommand;
  end;
  Lock;
  try
    ForgetFrames;
  finally
    Unlock;
  end;
end;

{ the frames of the inspected thread are walked again when they are asked for next (CurFrames) }
procedure TDebugger.ForgetFrames;
begin
  FFramesValid := False;
  FFrames := nil;
end;

procedure TDebugger.PostCommand(Cmd: TDbgCmd);
begin
  Lock;
  try
    if FState <> dsPaused then Exit;
    FPendingCmd := Cmd;
    FState := dsRunning;
  finally
    Unlock;
  end;
  QueueState;
  SetEvent(FCmdEvent);
end;

procedure TDebugger.DoStop(Reason: TDbgStopReason; T: TDbgThread; const Msg: string; Fault: Boolean);
var
  Cmd: TDbgCmd;
  WantSS: Boolean;
  Ctx: TContext;
  Frames: TFrameExArray;
  I, Idx: Integer;
  E: TQueuedEvent;
  F: TDbgFrame;
  Loc: TBPLoc;
  Addrs: TCardinalArray;
  CodeBuf: array[0..15] of Byte;
  Instr: TInstrInfo;
  LMod: TDbgModule;
  LLine: TTDLine;
begin
  if T = nil then Exit;
  ClearStep;
  if FPauseRequested and (Reason <> srPause) then
  begin
    // the program stopped for another reason first: the pause request is served by it
    if not FPauseFallback then FBreakInPending := True;
    FPauseRequested := False;
    FPauseFallback := False;
  end;
  FCurThread := T;
  ForgetFrames;
  FStopIsException := Reason = srException;
  FStopFault := Fault and FStopIsException;
  if FStopIsException then FStopExcThreadId := T.ThreadId else FStopExcThreadId := 0;
  if GetCtx(T, Ctx) and (T.ThreadId = FEventThreadId) and (Reason <> srPause) and (Reason <> srException) then
  begin
    Lock;
    try
      Loc := FindLoc(Ctx.Eip);
      if (Loc <> nil) and Loc.Installed then T.AtBP := Ctx.Eip;
    finally
      Unlock;
    end;
  end;
  // location to report: the first frame that has source; after one instruction the address
  // itself (the CPU view shows it - a caller's line would be a wrong place)
  Frames := CurFrames;
  Idx := 0;
  if not (FMachineStep and (Reason = srStep)) then
  begin
    Idx := FirstSourceFrame(Frames);
    if Idx < 0 then Idx := 0;
  end;
  if Length(Frames) > 0 then
    F := FrameToPublic(Frames[Idx], Idx)
  else
    LocationOf(Ctx.Eip, F);
  FStopFrameIndex := Idx;
  if Reason = srBreakpoint then
  begin
    // a data or module load breakpoint says what it is (Msg), a code breakpoint where it is
    if Msg <> '' then
      QueueLog(lkBreakpoint, Format('%s. Process %s (%d)', [Msg, ExeBaseName, FProcessId]))
    else if F.Line > 0 then
      QueueLog(lkBreakpoint, Format('Breakpoint at $%.8x: %s, line %d. Process %s (%d)',
        [F.Address, ExtractFileName(F.FileName), F.Line, ExeBaseName, FProcessId]))
    else
      QueueLog(lkBreakpoint, Format('Breakpoint at $%.8x. Process %s (%d)', [F.Address, ExeBaseName, FProcessId]));
  end;
  if FDetachRequested then
  begin
    // Detach while it ran: this stop serves it, nobody sees it
    FDetachRequested := False;
    Cmd := dcDetach;
    ForgetFrames;
  end
  else
  begin
    E := TQueuedEvent.Create;
    E.Kind := evStop;
    E.Reason := Reason;
    E.Frame := F;
    E.Msg := Msg;
    Lock;
    try
      Inc(FStopSeq);
      Inc(FStandCount);
      E.Seq := FStopSeq;
      FState := dsPaused;
      FCurrentFrame := Idx;
      FPendingCmd := dcNone;
    finally
      Unlock;
    end;
    Enqueue(E);
    Cmd := WaitServingCalls;
  end;
  FMachineStep := Cmd in [dcStepInstr, dcStepInstrOver];
  if FDataDirty then ApplyDataBPs;     // breakpoints changed while it stood

  FOverrideCtx := False;
  if FTerminating then
  begin
    FCurThread := nil;
    Exit;
  end;
  case Cmd of
    dcResume:
      Arm(T, False);
    dcStepOver, dcStepInto:
      begin
        if Cmd = dcStepOver then
          BeginStep(T, skOver, WantSS)
        else
          BeginStep(T, skInto, WantSS);
        Arm(T, WantSS);
      end;
    dcStepOut:
      begin
        BeginStepOut(T);
        Arm(T, False);
      end;
    dcStepInstr, dcStepInstrOver:
      begin
        FillChar(FStep, SizeOf(FStep), 0);
        if (Cmd = dcStepInstrOver) and ReadMemory(Ctx.Eip, CodeBuf, SizeOf(CodeBuf)) and
          DecodeInstr(@CodeBuf, SizeOf(CodeBuf), Ctx.Eip, Instr) and (Instr.Kind = ikCall) then
        begin
          { over a call: where it returns, on this stack }
          AddTemp(Ctx.Eip + Cardinal(Instr.Len), T.ThreadId, tcESP, Ctx.Esp, tpStepReturn);
          Arm(T, False);
        end
        else
        begin
          FStep.Active := True;
          FStep.Kind := skInstr;
          FStep.ThreadId := T.ThreadId;
          FStep.ExpectSS := True;
          Arm(T, True);
        end;
      end;
    dcTraceSource:
      begin
        FillChar(FStep, SizeOf(FStep), 0);
        FStep.Active := True;
        FStep.Kind := skSource;
        FStep.ThreadId := T.ThreadId;
        FStep.ExpectSS := True;
        if FindLineAbs(Ctx.Eip, LMod, LLine) then
        begin
          FStep.RangeLo := LMod.Base + LLine.Addr;
          FStep.RangeHi := LMod.Base + LLine.EndAddr;
        end;
        Arm(T, True);
      end;
    dcDetach:
      PrepareDetach;
    dcRunToLine:
      begin
        if LineAddrs(FRunToFile, FRunToLine, Addrs) then
          for I := 0 to High(Addrs) do
            if Addrs[I] <> Ctx.Eip then AddTemp(Addrs[I], 0, tcNone, 0, tpRunTo);
        Arm(T, False);
      end;
  end;
  FCurThread := nil;
  { it runs on: the conditions of breakpoints may call its code again }
  FStopIsException := False;
  FStopFault := False;
end;

procedure TDebugger.SyntheticPause;
var
  I: Integer;
  T: TDbgThread;
begin
  // DebugBreakProcess did not get through: freeze the threads and report a pause without a
  // pending debug event
  // (a break-in thread that was requested may still show up later: swallow its int 3)
  if not FPauseFallback then FBreakInPending := True;
  FPauseRequested := False;
  FPauseFallback := False;
  for I := 0 to FThreads.Count - 1 do
  begin
    T := TDbgThread(FThreads[I]);
    if SuspendThread(T.Handle) <> $FFFFFFFF then Inc(T.SuspendCount);
  end;
  FEventThreadId := 0;
  try
    DoStop(srPause, MainThread, '');
  finally
    for I := 0 to FThreads.Count - 1 do
    begin
      T := TDbgThread(FThreads[I]);
      T.HeldByCall := False;
      ResumeAll(T);
    end;
  end;
end;

{ between the events: a pause that DebugBreakProcess did not serve - protected as an event's
  handling is (an exception is reported, the loop goes on) }
procedure TDebugger.IdleTick;
begin
  try
    if FPauseRequested and (FPauseFallback or (GetTickCount - FPauseTick > 3000)) and not FTerminating then
      SyntheticPause;
  except
    on E: Exception do
    begin
      QueueError('pause', E);
      RunningAgain;
    end;
  end;
end;

{ an exception ended a stop's handling early: the program goes on, and the IDE is told so (it
  would show a stop that is no more) }
procedure TDebugger.RunningAgain;
var
  Paused: Boolean;
begin
  Lock;
  try
    Paused := FState = dsPaused;
    if Paused then
    begin
      FState := dsRunning;
      FPendingCmd := dcNone;
    end;
  finally
    Unlock;
  end;
  if Paused then QueueState;
end;

{ the threads that calls which did not return held: they go on with the program }
procedure TDebugger.ReleaseHeld;
var
  I: Integer;
  T: TDbgThread;
begin
  for I := 0 to FThreads.Count - 1 do
  begin
    T := TDbgThread(FThreads[I]);
    if not T.HeldByCall then Continue;
    T.HeldByCall := False;
    if T.SuspendCount > 0 then
    begin
      ResumeThread(T.Handle);
      Dec(T.SuspendCount);
    end;
  end;
end;

{ debug thread }

{ Attach: the debug thread debugs the running process (a detach or the end of the thread lets it
  run on); its handle comes with its CREATE_PROCESS event }
function TDebugger.AttachProcess: Boolean;
begin
  Result := DebugActiveProcess(FAttachPid);
  if not Result then
  begin
    FLastError := Format('Cannot attach to process %d: %s', [FAttachPid, SysErrorMessage(GetLastError)]);
    Exit;
  end;
  DebugSetProcessKillOnExit(False);
  FProcessId := FAttachPid;
  FProcessHandle := 0;
  FMainThreadHandle := 0;
end;

function TDebugger.LaunchProcess: Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd, Dir: string;
  PDir: PChar;
  Flags: DWORD;
begin
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  if FShowWindowCmd >= 0 then
  begin
    SI.dwFlags := STARTF_USESHOWWINDOW;
    SI.wShowWindow := FShowWindowCmd;
  end;
  Cmd := '"' + FExeName + '"';
  if FParams <> '' then Cmd := Cmd + ' ' + FParams;
  UniqueString(Cmd);
  Dir := FWorkDir;
  if Dir = '' then Dir := ExtractFileDir(FExeName);
  if Dir = '' then PDir := nil else PDir := PChar(Dir);
  { Debug spawned processes: the processes it starts are debugged as well (and live on when it
    ends: the end of the debug thread does not take them along) }
  if FDebugSpawned then Flags := DEBUG_PROCESS else Flags := DEBUG_ONLY_THIS_PROCESS;
  { Run | Parameters | Environment Block: an environment of its own ('' = the IDE's) }
  if FEnvironment <> '' then
    Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, Flags or CREATE_NEW_CONSOLE,
      PChar(FEnvironment), PDir, SI, PI)
  else
    Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, Flags or CREATE_NEW_CONSOLE, nil, PDir, SI, PI);
  if Result and FDebugSpawned then DebugSetProcessKillOnExit(False);
  if not Result then
  begin
    FLastError := SysErrorMessage(GetLastError);
    Exit;
  end;
  FProcessHandle := PI.hProcess;
  FMainThreadHandle := PI.hThread;
  FProcessId := PI.dwProcessId;
  FMainThreadId := PI.dwThreadId;
end;

procedure TDebugger.SessionCleanup;
var
  I: Integer;
begin
  Lock;
  try
    for I := 0 to FLocs.Count - 1 do TObject(FLocs[I]).Free;
    FLocs.Clear;
    FTemps := nil;
    for I := 0 to FBreakpoints.Count - 1 do
      with TDbgBreakpoint(FBreakpoints[I]) do
      begin
        Valid := False;
        { a data breakpoint watches memory of this process: Delphi disables it with the session }
        if Kind = bkData then Enabled := False;
      end;
    FillChar(FDataSlots, SizeOf(FDataSlots), 0);
    FDataDirty := False;
    FIgnoreAll := False;
    FCallStub := 0;                    // its memory went with the process
    for I := 0 to FModules.Count - 1 do TObject(FModules[I]).Free;
    FModules.Clear;
    for I := 0 to FThreads.Count - 1 do TObject(FThreads[I]).Free;
    FThreads.Clear;
    for I := 0 to FChildren.Count - 1 do
    begin
      if TDbgChild(FChildren[I]).Handle <> 0 then CloseHandle(TDbgChild(FChildren[I]).Handle);
      TObject(FChildren[I]).Free;
    end;
    FChildren.Clear;
    FCurThread := nil;
    ForgetFrames;
    FStep.Active := False;
    if FProcessHandle <> 0 then CloseHandle(FProcessHandle);
    if FMainThreadHandle <> 0 then CloseHandle(FMainThreadHandle);
    FProcessHandle := 0;
    FMainThreadHandle := 0;
  finally
    Unlock;
  end;
end;

procedure TDebugger.ThreadMain;
var
  Ok: Boolean;
begin
  if FAttachPid <> 0 then Ok := AttachProcess else Ok := LaunchProcess;
  if not Ok then
  begin
    CloseThreadDebugObject;
    FStartResult := False;
    SetEvent(FStartEvent);
    Exit;
  end;
  Lock;
  try
    FState := dsRunning;
  finally
    Unlock;
  end;
  QueueState;
  FStartResult := True;
  SetEvent(FStartEvent);
  try
    DebugLoop;
  except
    on E: Exception do
    begin
      { what the loop's own protection did not catch: reported; the program goes on without the
        debugger (as Detach leaves it), the session ends below all the same }
      QueueError('debug loop', E);
      try
        if FEventPending then ContinueDebugEvent(FContPid, FContTid, DBG_CONTINUE);
        FEventPending := False;
        if not FProcessGone then
        begin
          PrepareDetach;
          DetachProcesses;
          FDetached := True;
        end;
      except
        // the session ends whatever happens
      end;
    end;
  end;
  EndSession;
end;

procedure TDebugger.DebugLoop;
var
  DE: TDebugEvent;
  Cont: Cardinal;
  Code: Cardinal;

  { Detach: the program and the processes it started run on without the debugger - once PrepareDetach
    asked for it, after an event or after a pause without one (SyntheticPause: no event follows) }
  function LetGo: Boolean;
  begin
    Result := FDetaching;
    if not Result then Exit;
    DetachProcesses;
    FDetached := True;
  end;

begin
  while not FProcessGone do
  begin
    if not WaitForDebugEvent(DE, 100) then
    begin
      // timeout: housekeeping; make sure the process still exists
      if WaitForSingleObject(FProcessHandle, 0) = WAIT_OBJECT_0 then
      begin
        // the process is gone but its exit event has not been delivered: drain once more
        if not WaitForDebugEvent(DE, 500) then
        begin
          Code := 0;
          GetExitCodeProcess(FProcessHandle, Code);
          FExitCode := Code;
          Break;
        end;
      end
      else
      begin
        IdleTick;
        if LetGo then Break;
        Continue;
      end;
    end;
    Cont := DBG_CONTINUE;
    FEventThreadId := DE.dwThreadId;
    FContPid := DE.dwProcessId;
    FContTid := DE.dwThreadId;
    FEventPending := True;
    FCalled := False;
    try
      HandleEvent(DE, Cont);
      if FDataDirty then ApplyDataBPs;    // changed while it ran, or a new thread
    except
      // keep the debug loop alive whatever happens in a handler: reported, the program goes on
      on E: Exception do
      begin
        QueueError('debug event', E);
        RunningAgain;
      end;
    end;
    // the threads of calls that did not return go on; the pending event - after a call the one
    // that ended it, continued as handled - is continued (a call that did not return left none)
    ReleaseHeld;
    if FEventPending then
    begin
      if FCalled then Cont := DBG_CONTINUE;
      ContinueDebugEvent(FContPid, FContTid, Cont);
    end;
    FEventPending := False;
    FCalled := False;
    if LetGo then Break;
    if (DE.dwDebugEventCode = EXIT_PROCESS_DEBUG_EVENT) and (DE.dwProcessId = FProcessId) then FProcessGone := True;
  end;
end;

{ the end of every session that started, however the loop ended: the log, the session's data
  freed, the state reset - and the IDE told (evExit), also when something of it fails }
procedure TDebugger.EndSession;
var
  E: TQueuedEvent;
begin
  try
    if FDetached then
      QueueLog(lkProcess, Format('Process Detach: Process %s (%d)', [ExeBaseName, FProcessId]))
    else
      QueueLog(lkProcess, Format('Process Exit: Process %s (%d). Exit code: %d', [ExeBaseName, FProcessId,
        Integer(FExitCode)]));
    SessionCleanup;
    CloseThreadDebugObject;
  finally
    Lock;
    try
      FState := dsNone;
    finally
      Unlock;
    end;
    E := TQueuedEvent.Create;
    E.Kind := evExit;
    E.ExitCode := FExitCode;
    Enqueue(E);
  end;
end;

{ ---------------------------------------------------------------- calls of the evaluator }

{ 'TClass@Method' of every Delphi export of M ('@Unit@TClass@Method$signature') }
procedure TDebugger.ExportKeys(M: TDbgModule);
var
  I, P: Integer;
  S, Key: string;
begin
  if M.ExpKeys <> nil then Exit;
  M.ExpKeys := TStringList.Create;
  LoadExports(M);
  for I := 0 to High(M.ExpByName) do
  begin
    S := ReadCStrRaw(M.Base + M.ExpByName[I], 256);
    if (S = '') or (S[1] <> '@') then Continue;
    P := Pos('$', S);
    if P > 0 then S := Copy(S, 1, P - 1);
    P := LastDelimiter('@', S);
    if P <= 1 then Continue;
    Key := Copy(S, P + 1, MaxInt);
    S := Copy(S, 1, P - 1);
    Key := Copy(S, LastDelimiter('@', S) + 1, MaxInt) + '@' + Key;
    if M.ExpOrd[I] <= High(M.ExpFuncs) then M.ExpKeys.AddObject(Key, TObject(I));
  end;
  M.ExpKeys.Sorted := True;
end;

function TDebugger.FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal;
var
  I, P: Integer;
  M: TDbgModule;
begin
  Result := 0;
  ExportName := '';
  if Routine = '' then Exit;
  Lock;
  try
    { the exports of the packages (the evaluator searches the debug information itself): by the
      export's own name, or by class and method }
    for I := 0 to FModules.Count - 1 do
    begin
      M := TDbgModule(FModules[I]);
      if Routine[1] = '@' then
      begin
        Result := FindExport(M, Routine);
        if Result <> 0 then ExportName := Routine;
      end
      else if ClassName <> '' then
      begin
        ExportKeys(M);
        P := M.ExpKeys.IndexOf(ClassName + '@' + Routine);
        if P >= 0 then
        begin
          P := Integer(M.ExpKeys.Objects[P]);
          Result := M.Base + M.ExpFuncs[M.ExpOrd[P]];
          ExportName := ReadCStrRaw(M.Base + M.ExpByName[P], 256);   // mangled: its parameters
        end;
      end;
      if Result <> 0 then Exit;
    end;
  finally
    Unlock;
  end;
end;

{ From the IDE's thread (Evaluate/Modify, the inspector): the debug thread runs the call while
  the program stands (dcCall, DoStop serves it); from the debug thread itself (a breakpoint's
  condition or action) it runs at once. Not while the program stands at an exception: its event
  must go back to the program as it is. }
function TDebugger.CallCode(T: TDbgThread; Addr: Cardinal; const Regs, Stack: array of Cardinal;
  out EAX, EDX: Cardinal; out ST0: Extended; out Error: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  EAX := 0;
  EDX := 0;
  ST0 := 0;
  Error := '';
  if FStopIsException then
  begin
    Error := 'the program stands at an exception: its code cannot be called now';
    Exit;
  end;
  if (FWorker <> nil) and (GetCurrentThreadId = FWorker.ThreadID) then
  begin
    Result := DoCall(T, Addr, Regs, Stack, EAX, EDX, ST0, Error);
    Exit;
  end;
  Lock;
  try
    if (FState <> dsPaused) or (FPendingCmd <> dcNone) then
    begin
      Error := 'the program does not stand';
      Exit;
    end;
    FCallThread := T;
    FCallAddr := Addr;
    SetLength(FCallRegs, Length(Regs));
    for I := 0 to High(Regs) do FCallRegs[I] := Regs[I];
    SetLength(FCallStack, Length(Stack));
    for I := 0 to High(Stack) do FCallStack[I] := Stack[I];
    ResetEvent(FCallDone);
    FPendingCmd := dcCall;
  finally
    Unlock;
  end;
  SetEvent(FCmdEvent);
  if WaitForSingleObject(FCallDone, 15000) <> WAIT_OBJECT_0 then
  begin
    Error := 'the debugger did not answer';
    Exit;
  end;
  Result := FCallOk;
  EAX := FCallEAX;
  EDX := FCallEDX;
  ST0 := FCallST0;
  Error := FCallError;
end;

procedure TDebugger.ServeCall;
begin
  try
    FCallOk := DoCall(FCallThread, FCallAddr, FCallRegs, FCallStack, FCallEAX, FCallEDX, FCallST0, FCallError);
  except
    on E: Exception do
    begin
      FCallOk := False;
      FCallError := E.Message;
    end;
  end;
  SetEvent(FCallDone);
end;

{ A call of the program's code on thread T. Its context is kept; below the evaluation's scratch
  memory the call gets an exception frame of its own (fs:[0]), the stack arguments and the return
  address; EAX, EDX, ECX get the register arguments, and only T runs (the others are held). The
  return address and the frame's handler are two int 3 in a page of the program (FCallStub): the
  call ends at one of them - returned (EAX, EDX, ST(0) are the results), or raised an exception
  that its own code did not handle (the program's handlers run first: its exceptions are passed
  to it while the call runs; in a program with DEP Windows refuses the frame's handler, which is
  outside a module, with STATUS_INVALID_EXCEPTION_HANDLER - the same end). Either way the end is
  a breakpoint event (or that exception), which becomes the pending
  event in place of the one continued for the call, and T's context and fs:[0] come back. A
  breakpoint of ours or the end of the program ends the call too; after 5 seconds T is held and
  the call given up.
  Not while T is held (another thread steps over a breakpoint of ours, a call before did not
  return, the threads are frozen) or another thread steps over a lifted breakpoint: its step and
  the int 3 that goes back belong to the debug loop. What the other threads report meanwhile (an
  event that was queued already, a thread made meanwhile - held until the call ends) is handled
  in CallOtherException. The call runs without the data breakpoints (a getter that writes a
  watched variable trapped in its own single step); they come back with T's context. }
function TDebugger.DoCall(T: TDbgThread; Addr: Cardinal; const Regs, Stack: array of Cardinal;
  out EAX, EDX: Cardinal; out ST0: Extended; out Error: string): Boolean;
const
  CallTimeout = 5000;
  Stub: array[0..1] of Byte = ($CC, $CC);
var
  Save, Ctx: TContext;
  Ret, Handler, SP, Code, Start, SEH, Frame, ExcObj: Cardinal;
  I: Integer;
  DE: TDebugEvent;
  Cont, N: Cardinal;
  Done, Ok: Boolean;
  Raised, ExcMsg: string;
begin
  Result := False;
  EAX := 0;
  EDX := 0;
  ST0 := 0;
  Error := '';
  if T = nil then
  begin
    Error := 'no thread to call on';
    Exit;
  end;
  if T.SuspendCount > 0 then
  begin
    Error := 'the thread is held by the debugger: its code cannot be called now';
    Exit;
  end;
  for I := 0 to FThreads.Count - 1 do
    if TDbgThread(FThreads[I]).SteppingOverBP <> 0 then
    begin
      Error := 'a thread steps over a breakpoint: no code can be called now';
      Exit;
    end;
  if FCallStub = 0 then
  begin
    FCallStub := Cardinal(VirtualAllocEx(FProcessHandle, nil, 4096, MEM_COMMIT, PAGE_EXECUTE_READWRITE));
    if (FCallStub = 0) or not WriteProcessMemory(FProcessHandle, Pointer(FCallStub), @Stub, SizeOf(Stub), N) then
    begin
      FCallStub := 0;
      Error := 'no memory for the call in the program';
      Exit;
    end;
    FlushInstructionCache(FProcessHandle, Pointer(FCallStub), SizeOf(Stub));
  end;
  Ret := FCallStub;
  Handler := FCallStub + 1;
  FillChar(Save, SizeOf(Save), 0);
  Save.ContextFlags := CONTEXT_FULL or CONTEXT_FLOATING_POINT or CONTEXT_DEBUG_REGISTERS;
  if not GetThreadContext(T.Handle, Save) or not ReadMemRaw(T.TLB, SEH, 4) then
  begin
    Error := SysErrorMessage(GetLastError);
    Exit;
  end;
  { the call's exception frame (the one before, the handler), the stack arguments, the return
    address - each written; fs:[0] last, only when they are there }
  SP := (Save.Esp - $2000) and not 15;
  Dec(SP, 8);
  Frame := SP;
  Ok := WriteMemRaw(Frame, SEH, 4) and WriteMemRaw(Frame + 4, Handler, 4);
  for I := 0 to High(Stack) do
  begin
    Dec(SP, 4);
    Ok := Ok and WriteMemRaw(SP, Stack[I], 4);
  end;
  Dec(SP, 4);
  Ok := Ok and WriteMemRaw(SP, Ret, 4) and WriteMemRaw(T.TLB, Frame, 4);
  if not Ok then
  begin
    Error := 'the call cannot be written to the thread''s stack';
    Exit;
  end;
  Ctx := Save;
  Ctx.Esp := SP;
  Ctx.Eip := Addr;
  Ctx.EFlags := Ctx.EFlags and not TRAP_FLAG;
  if Length(Regs) > 0 then Ctx.Eax := Regs[0];
  if Length(Regs) > 1 then Ctx.Edx := Regs[1];
  if Length(Regs) > 2 then Ctx.Ecx := Regs[2];
  Ctx.Dr6 := 0;
  Ctx.Dr7 := 0;
  Ctx.ContextFlags := CONTEXT_FULL or CONTEXT_DEBUG_REGISTERS;
  if not SetThreadContext(T.Handle, Ctx) then
  begin
    Error := SysErrorMessage(GetLastError);
    WriteMemRaw(T.TLB, SEH, 4);
    Exit;
  end;
  SuspendOthers(T);
  FInCall := True;
  Raised := '';
  try
    if FEventPending then
    begin
      if not ContinueDebugEvent(FContPid, FContTid, DBG_CONTINUE) then
      begin
        Error := 'the thread cannot run the call: ' + SysErrorMessage(GetLastError);
        Exit;
      end;
      FEventPending := False;
      FCalled := True;
    end;
    Start := GetTickCount;
    Done := False;
    repeat
      if not WaitForDebugEvent(DE, 100) then
      begin
        if GetTickCount - Start > CallTimeout then
        begin
          // it does not return: T is held where it is until the program goes on, nothing is pending
          if SuspendThread(T.Handle) <> $FFFFFFFF then
          begin
            Inc(T.SuspendCount);
            T.HeldByCall := True;
          end;
          Error := 'the call did not return within 5 seconds';
          Done := True;
        end;
        Continue;
      end;
      FContPid := DE.dwProcessId;
      FContTid := DE.dwThreadId;
      FEventPending := True;
      Cont := DBG_CONTINUE;
      if DE.dwProcessId <> FProcessId then
        HandleEvent(DE, Cont)           // a process the program started
      else if (DE.dwDebugEventCode = EXCEPTION_DEBUG_EVENT) and (DE.dwThreadId = T.ThreadId) then
      begin
        Code := DE.Exception.ExceptionRecord.ExceptionCode;
        if (Code = EXC_BREAKPOINT) and (Cardinal(DE.Exception.ExceptionRecord.ExceptionAddress) = Ret) then
        begin
          FillChar(Ctx, SizeOf(Ctx), 0);
          Ctx.ContextFlags := CONTEXT_FULL or CONTEXT_FLOATING_POINT;
          if GetThreadContext(T.Handle, Ctx) then
          begin
            EAX := Ctx.Eax;
            EDX := Ctx.Edx;
            Move(Ctx.FloatSave.RegisterArea[0], ST0, 10);
            Result := True;
          end;
          Done := True;
        end
        else if ((Code = EXC_BREAKPOINT) and (Cardinal(DE.Exception.ExceptionRecord.ExceptionAddress) = Handler)) or
          (Code = EXC_INVALID_HANDLER) then
        begin
          { the call's frame was reached: its handler ran - or, in a program with DEP (NX
            compatible: D7 Studio's modern program header), Windows refused it, a handler outside
            a module (FCallStub), and raised this instead; the exception that got there is Raised }
          if Raised = '' then Raised := 'an exception';
          Error := 'the call raised ' + Raised;
          Done := True;
        end
        else if Code = EXC_BREAKPOINT then
        begin
          Error := 'the call reached a breakpoint';
          Done := True;
        end
        else if (Code >= cDelphiReRaise) and (Code <= cDelphiExitFinally) then
          // the RTL's notifications (DebugHook): continued
        else if DE.Exception.dwFirstChance <> 0 then
        begin
          // the program's handlers decide (the call's frame catches what they leave)
          if (Code = cDelphiException) and (DE.Exception.ExceptionRecord.NumberParameters >= 2) then
          begin
            ExcObj := DE.Exception.ExceptionRecord.ExceptionInformation[1];
            Raised := ReadClassNameOf(ExcObj);
            ExcMsg := ReadExceptionMessage(ExcObj);
            if ExcMsg <> '' then Raised := Raised + ' (' + ExcMsg + ')';
          end
          else
            Raised := Format('exception $%.8x', [Code]);
          Cont := DBG_EXCEPTION_NOT_HANDLED;
        end
        else
        begin
          Error := Format('the call raised exception $%.8x', [Code]);
          Done := True;
        end;
      end
      else if DE.dwDebugEventCode = EXIT_PROCESS_DEBUG_EVENT then
      begin
        Error := 'the program ended in the call';
        FExitCode := DE.ExitProcess.dwExitCode;
        Done := True;                 // pending: the debug loop sees the exit after the stop
      end
      else if (DE.dwDebugEventCode = EXIT_THREAD_DEBUG_EVENT) and (DE.dwThreadId = T.ThreadId) then
      begin
        Error := 'the thread ended in the call';
        Done := True;                 // pending (T is the stopped thread: it is not freed here)
      end
      else if DE.dwDebugEventCode = EXCEPTION_DEBUG_EVENT then
        CallOtherException(DE, Cont)
      else
      begin
        // what the system does meanwhile: as always (no stop is reported); a new thread waits
        HandleEvent(DE, Cont);
        if DE.dwDebugEventCode = CREATE_THREAD_DEBUG_EVENT then HoldForCall(FindThread(DE.dwThreadId));
      end;
      if not Done then
      begin
        ContinueDebugEvent(DE.dwProcessId, DE.dwThreadId, Cont);
        FEventPending := False;
      end;
    until Done;
  finally
    FInCall := False;
    Save.Dr6 := 0;
    Save.ContextFlags := CONTEXT_FULL or CONTEXT_FLOATING_POINT or CONTEXT_DEBUG_REGISTERS;
    SetThreadContext(T.Handle, Save);
    WriteMemRaw(T.TLB, SEH, 4);
    ResumeOthers(T);
  end;
end;

{ An exception of another thread while a call runs (DoCall). An int 3 runs again after the call:
  the thread's instruction pointer back on it, the thread held until the call ends - a breakpoint
  of ours is then handled as always (continued as it was, the thread ran on behind the int 3 in
  the middle of the instruction it replaced). A single step is continued as handled (it went to
  the program before, which then died of it): no thread steps over a lifted breakpoint during a
  call (DoCall refuses one then), so it is a data breakpoint's - its hit is not reported - or a
  trap flag left over. The RTL's notifications are continued, the other exceptions go to the
  program. }
procedure TDebugger.CallOtherException(var DE: TDebugEvent; var Cont: Cardinal);
var
  O: TDbgThread;
  Code: Cardinal;
  BP: TDbgBreakpoint;
  Traced: Boolean;
begin
  Code := DE.Exception.ExceptionRecord.ExceptionCode;
  O := FindThread(DE.dwThreadId);
  if O = nil then
  begin
    if (Code <> EXC_BREAKPOINT) and (Code <> EXC_SINGLE_STEP) then Cont := DBG_EXCEPTION_NOT_HANDLED;
    Exit;
  end;
  case Code of
    EXC_BREAKPOINT:
      begin
        SetEIP(O, Cardinal(DE.Exception.ExceptionRecord.ExceptionAddress));
        HoldForCall(O);
      end;
    EXC_SINGLE_STEP:
      begin
        DataHit(O, BP, Traced);         // its status cleared
        HoldForCall(O);
      end;
    cDelphiReRaise..cDelphiExitFinally:
      ;
  else
    Cont := DBG_EXCEPTION_NOT_HANDLED;
  end;
end;

{ the text of an OutputDebugString of process H (ANSI or UTF-16), without its line break }
function DebugStringOf(H: THandle; const DS: TOutputDebugStringInfo): string;
var
  Buf: array of Byte;
  Len: Integer;
  Done: Cardinal;
begin
  Result := '';
  Len := DS.nDebugStringLength;
  if Len <= 0 then Exit;
  if DS.fUnicode <> 0 then Len := Len * 2;
  SetLength(Buf, Len + 4);
  FillChar(Buf[0], Length(Buf), 0);
  ReadProcessMemory(H, DS.lpDebugStringData, @Buf[0], Len, Done);
  if DS.fUnicode <> 0 then Result := WideToAnsi(PWideChar(@Buf[0])) else Result := ProgramText(PChar(@Buf[0]));
  while (Result <> '') and (Result[Length(Result)] in [#13, #10]) do SetLength(Result, Length(Result) - 1);
end;

function TDebugger.FindChild(Pid: Cardinal): TDbgChild;
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do
  begin
    Result := TDbgChild(FChildren[I]);
    if Result.Pid = Pid then Exit;
  end;
  Result := nil;
end;

{ An event of a process the program started (Debug spawned processes): the log has its start,
  its exit and its debug strings; its exceptions go back to it (its own handlers decide), its
  loader's breakpoint goes on. The program's own events are not affected. }
procedure TDebugger.HandleChildEvent(var DE: TDebugEvent; var Cont: Cardinal);
var
  C: TDbgChild;
  Code: Cardinal;
begin
  C := FindChild(DE.dwProcessId);
  case DE.dwDebugEventCode of
    CREATE_PROCESS_DEBUG_EVENT:
      begin
        C := TDbgChild.Create;
        C.Pid := DE.dwProcessId;
        DuplicateHandle(GetCurrentProcess, DE.CreateProcessInfo.hProcess, GetCurrentProcess, @C.Handle,
          0, False, DUPLICATE_SAME_ACCESS);
        C.Name := ModuleFileFromHandle(DE.CreateProcessInfo.hFile);
        if C.Name = '' then C.Name := Format('process_%d', [C.Pid]);
        if DE.CreateProcessInfo.hFile <> 0 then CloseHandle(DE.CreateProcessInfo.hFile);
        FChildren.Add(C);
        QueueLog(lkProcess, Format('Process Start: %s. Base Address: $%.8x. Process %s (%d)',
          [C.Name, Cardinal(DE.CreateProcessInfo.lpBaseOfImage), ExtractFileName(C.Name), C.Pid]));
      end;
    EXIT_PROCESS_DEBUG_EVENT:
      if C <> nil then
      begin
        QueueLog(lkProcess, Format('Process Exit: Process %s (%d). Exit code: %d',
          [ExtractFileName(C.Name), C.Pid, Integer(DE.ExitProcess.dwExitCode)]));
        FChildren.Remove(C);
        if C.Handle <> 0 then CloseHandle(C.Handle);
        C.Free;
      end;
    LOAD_DLL_DEBUG_EVENT:
      if DE.LoadDll.hFile <> 0 then CloseHandle(DE.LoadDll.hFile);
    OUTPUT_DEBUG_STRING_EVENT:
      if C <> nil then QueueLog(lkDebugString, DebugStringOf(C.Handle, DE.DebugString));
    EXCEPTION_DEBUG_EVENT:
      begin
        Code := DE.Exception.ExceptionRecord.ExceptionCode;
        if (Code = EXC_WX86_BREAKPOINT) or ((Code = EXC_BREAKPOINT) and (C <> nil) and not C.SeenBP) then
        begin
          if Code = EXC_BREAKPOINT then C.SeenBP := True;
        end
        else
          Cont := DBG_EXCEPTION_NOT_HANDLED;
      end;
  end;
end;

{ Detach: the program runs on as if it had never been debugged - every int 3 of ours out, no trap
  flag, no debug registers, the RTL's DebugHook back to 0 (it would announce its exceptions to
  nobody) }
procedure TDebugger.PrepareDetach;
var
  I: Integer;
  Loc: TBPLoc;
  Ctx: TContext;
  T: TDbgThread;
begin
  Lock;
  try
    for I := 0 to FLocs.Count - 1 do
    begin
      Loc := TBPLoc(FLocs[I]);
      if Loc.Installed then
      begin
        WriteCodeByte(Loc.Addr, Loc.OrigByte);
        Loc.Installed := False;
      end;
    end;
    FTemps := nil;
    FillChar(FDataSlots, SizeOf(FDataSlots), 0);
    FStep.Active := False;
    for I := 0 to FModules.Count - 1 do SetDebugHook(TDbgModule(FModules[I]), 0);
    for I := 0 to FThreads.Count - 1 do
    begin
      T := TDbgThread(FThreads[I]);
      T.AtBP := 0;
      T.SteppingOverBP := 0;
      T.HeldByCall := False;
      ClearTrapFlag(T);
      FillChar(Ctx, SizeOf(Ctx), 0);
      Ctx.ContextFlags := CONTEXT_DEBUG_REGISTERS;
      if GetThreadContext(T.Handle, Ctx) then
      begin
        Ctx.Dr6 := 0;
        Ctx.Dr7 := 0;
        SetThreadContext(T.Handle, Ctx);
      end;
      ResumeAll(T);
    end;
  finally
    Unlock;
  end;
  FDetaching := True;
end;

{ the program and the processes it started run on without the debugger (after PrepareDetach) }
procedure TDebugger.DetachProcesses;
var
  I: Integer;
begin
  DebugActiveProcessStop(FProcessId);
  for I := 0 to FChildren.Count - 1 do DebugActiveProcessStop(TDbgChild(FChildren[I]).Pid);
end;

procedure TDebugger.HandleEvent(var DE: TDebugEvent; var Cont: Cardinal);
var
  T: TDbgThread;
  M: TDbgModule;
  Path, S: string;
  Info: TTD32Info;
  P: Cardinal;
  Buf: array of Byte;
  Len: Integer;
begin
  if (FProcessId <> 0) and (DE.dwProcessId <> FProcessId) then
  begin
    HandleChildEvent(DE, Cont);
    Exit;
  end;
  case DE.dwDebugEventCode of
    CREATE_PROCESS_DEBUG_EVENT:
      begin
        // an attached process: a handle of our own (the event's belongs to the system)
        if FProcessHandle = 0 then
          DuplicateHandle(GetCurrentProcess, DE.CreateProcessInfo.hProcess, GetCurrentProcess, @FProcessHandle,
            0, False, DUPLICATE_SAME_ACCESS);
        T := TDbgThread.Create;
        T.ThreadId := DE.dwThreadId;
        T.Handle := DE.CreateProcessInfo.hThread;
        T.TLB := Cardinal(DE.CreateProcessInfo.lpThreadLocalBase);
        T.StartAddr := Cardinal(DE.CreateProcessInfo.lpStartAddress);
        FThreads.Add(T);
        FMainThreadId := DE.dwThreadId;
        if (FExeInfo <> nil) and (FExeInfo.HasTD32 or FExeInfo.IsMap) then
          M := AddModule(Cardinal(DE.CreateProcessInfo.lpBaseOfImage), FExeName, FExeInfo, False)
        else
          M := AddModule(Cardinal(DE.CreateProcessInfo.lpBaseOfImage), FExeName, nil, False);
        if DE.CreateProcessInfo.hFile <> 0 then CloseHandle(DE.CreateProcessInfo.hFile);
        SetDebugHook(M);
        Lock;
        try
          ResolveAllBPs;
        finally
          Unlock;
        end;
        QueueBPsChanged;
        if FSessStopAtEntry and (FExeInfo <> nil) and (FExeInfo.EntryRVA <> 0) and HasLineAbs(M.Base + FExeInfo.EntryRVA) then
          AddTemp(M.Base + FExeInfo.EntryRVA, 0, tcNone, 0, tpEntry);
        if FAttachPid <> 0 then S := 'Process Attach' else S := 'Process Start';
        QueueLog(lkProcess, Format('%s: %s. Base Address: $%.8x. Process %s (%d)',
          [S, FExeName, M.Base, ExeBaseName, FProcessId]));
      end;
    CREATE_THREAD_DEBUG_EVENT:
      begin
        T := TDbgThread.Create;
        T.ThreadId := DE.dwThreadId;
        T.Handle := DE.CreateThread.hThread;
        T.TLB := Cardinal(DE.CreateThread.lpThreadLocalBase);
        T.StartAddr := Cardinal(DE.CreateThread.lpStartAddress);
        FThreads.Add(T);
        FDataDirty := FDataDirty or HasBPKind(bkData);
        if FPauseRequested and (FBreakInThreadId = 0) then
        begin
          // most likely the thread injected by DebugBreakProcess
          M := ModuleByAddr(T.StartAddr);
          if (M <> nil) and SameText(M.Name, 'ntdll.dll') then FBreakInThreadId := T.ThreadId;
        end;
        if T.ThreadId <> FBreakInThreadId then
          QueueLog(lkThread, Format('Thread Start: Thread ID: %d. Process %s (%d)',
            [T.ThreadId, ExeBaseName, FProcessId]));
      end;
    EXIT_THREAD_DEBUG_EVENT:
      begin
        T := FindThread(DE.dwThreadId);
        if T <> nil then
        begin
          if T.SteppingOverBP <> 0 then EndLift(T);
          if FStep.Active and (FStep.ThreadId = T.ThreadId) then ClearStep;
          if T.ThreadId <> FBreakInThreadId then
            QueueLog(lkThread, Format('Thread Exit: Thread ID: %d. Exit code: %d. Process %s (%d)',
              [T.ThreadId, Integer(DE.ExitThread.dwExitCode), ExeBaseName, FProcessId]));
          if T.ThreadId = FBreakInThreadId then FBreakInThreadId := 0;
          FThreads.Remove(T);
          if FCurThread = T then FCurThread := nil;
          T.Free;
        end;
      end;
    EXIT_PROCESS_DEBUG_EVENT:
      FExitCode := DE.ExitProcess.dwExitCode;
    LOAD_DLL_DEBUG_EVENT:
      begin
        Path := ModuleFileFromHandle(DE.LoadDll.hFile);
        if Path = '' then
        begin
          // fall back to the image name pointer in the debuggee
          if (DE.LoadDll.lpImageName <> nil) and ReadMemRaw(Cardinal(DE.LoadDll.lpImageName), P, 4) and (P <> 0) then
          begin
            SetLength(Buf, 1024);
            FillChar(Buf[0], 1024, 0);
            Len := 1022;
            while (Len > 0) and not ReadMemRaw(P, Buf[0], Len) do Len := Len div 2;
            if DE.LoadDll.fUnicode <> 0 then
              Path := UsablePath(PWideChar(@Buf[0]))
            else
              Path := PChar(@Buf[0]);
          end;
        end;
        if Path = '' then Path := Format('module_%.8x', [Cardinal(DE.LoadDll.lpBaseOfDll)]);
        if DE.LoadDll.hFile <> 0 then CloseHandle(DE.LoadDll.hFile);
        Info := nil;
        if FileExists(Path) and not SameText(ExtractFileExt(Path), '.drv') then
        begin
          // DLLs / packages built with -V carry their own TD32 information (or D7 Studio keeps it)
          Info := TTD32Info.Create;
          if not Info.LoadWithSide(Path) then FreeAndNil(Info);
        end;
        M := AddModule(Cardinal(DE.LoadDll.lpBaseOfDll), Path, Info, True);
        SetDebugHook(M);
        if (Info <> nil) or HasBPKind(bkAddress) then
        begin
          Lock;
          try
            ResolveBPsIn(M);
          finally
            Unlock;
          end;
          QueueBPsChanged;
        end;
        if Info <> nil then S := 'Has Debug Info' else S := 'No Debug Info';
        QueueLog(lkModule, Format('Module Load: %s. %s. Base Address: $%.8x. Process %s (%d)',
          [M.Name, S, M.Base, ExeBaseName, FProcessId]));
        if ModuleBPStops(Path, FindThread(DE.dwThreadId)) then
          DoStop(srBreakpoint, FindThread(DE.dwThreadId), 'Module Load Breakpoint: ' + M.Name);
      end;
    UNLOAD_DLL_DEBUG_EVENT:
      begin
        P := Cardinal(DE.UnloadDll.lpBaseOfDll);
        M := ModuleByAddr(P);
        if (M <> nil) and (M.Base = P) then
        begin
          QueueLog(lkModule, Format('Module Unload: %s. Process %s (%d)', [M.Name, ExeBaseName, FProcessId]));
          if M.Info <> nil then QueueBPsChanged;
          RemoveModule(P);
        end;
      end;
    OUTPUT_DEBUG_STRING_EVENT:
      if DE.DebugString.nDebugStringLength > 0 then
        QueueLog(lkDebugString, DebugStringOf(FProcessHandle, DE.DebugString));
    EXCEPTION_DEBUG_EVENT:
      HandleException(DE, Cont);
  end;
end;

procedure TDebugger.HandleException(var DE: TDebugEvent; var Cont: Cardinal);
var
  Code, Addr: Cardinal;
  T: TDbgThread;
begin
  Code := DE.Exception.ExceptionRecord.ExceptionCode;
  Addr := Cardinal(DE.Exception.ExceptionRecord.ExceptionAddress);
  T := FindThread(DE.dwThreadId);
  if T = nil then
  begin
    // thread we never saw created: be transparent
    if (Code <> EXC_BREAKPOINT) and (Code <> EXC_SINGLE_STEP) then Cont := DBG_EXCEPTION_NOT_HANDLED;
    Exit;
  end;
  // a lifted breakpoint must be restored whatever interrupted the single step
  if (T.SteppingOverBP <> 0) and (Code <> EXC_SINGLE_STEP) then
  begin
    EndLift(T);
    ClearTrapFlag(T);
  end;
  case Code of
    EXC_BREAKPOINT:
      begin
        if not FSeenInitialBP then
        begin
          // loader breakpoint: the process is initialised, nothing has run yet
          FSeenInitialBP := True;
          Exit;
        end;
        HandleBreakpointHit(T, Addr, Cont);
      end;
    EXC_SINGLE_STEP:
      HandleSingleStep(T, Cont);
    EXC_WX86_BREAKPOINT, EXC_WX86_SINGLE_STEP:
      ;
    cDelphiException:
      HandleDelphiException(T, DE, Cont);
    cDelphiReRaise..cDelphiExitFinally:
      HandleDelphiNotify(T, DE, Cont);
    EXC_THREAD_NAME:
      ;
    EXC_DBG_PRINT, EXC_DBG_PRINT_WIDE:
      // not for us: the system falls back to the plain debug-string event for the wide print
      Cont := DBG_EXCEPTION_NOT_HANDLED;
  else
    // Control-C and Control-Break as well: the OS exception rules decide (Debugger Options)
    HandleOSException(T, DE, Cont);
  end;
end;

procedure TDebugger.HandleSingleStep(T: TDbgThread; var Cont: Cardinal);
var
  Ctx: TContext;
  LMod: TDbgModule;
  LLine: TTDLine;
  DataBP: TDbgBreakpoint;
  DataTrap, Traced: Boolean;
  Msg: string;
begin
  { a write to the data of a data breakpoint (the trap comes after the instruction) }
  DataTrap := DataHit(T, DataBP, Traced);
  if T.SteppingOverBP <> 0 then
  begin
    if GetCtx(T, Ctx) and (Ctx.Eip = T.SteppingOverBP) then
    begin
      // a repeated string instruction traps after each iteration and is not finished yet:
      // keep the breakpoint lifted until the instruction pointer moves on
      Ctx.EFlags := Ctx.EFlags or TRAP_FLAG;
      SetCtx(T, Ctx);
      Exit;
    end;
    EndLift(T);
  end;
  if DataTrap then
  begin
    if DataBPStops(DataBP, T, Msg) then
    begin
      DoStop(srBreakpoint, T, Msg);
      Exit;
    end;
    if not Traced then Exit;      // the write alone: the program goes on
  end;
  { one instruction (the CPU view); Trace to Next Source Line: on until a line begins }
  if FStep.Active and (FStep.ThreadId = T.ThreadId) and (FStep.Kind in [skInstr, skSource]) then
  begin
    if (FStep.Kind = skSource) and GetCtx(T, Ctx) and not (FindLineAbs(Ctx.Eip, LMod, LLine) and
      (Ctx.Eip = LMod.Base + LLine.Addr) and ((Ctx.Eip < FStep.RangeLo) or (Ctx.Eip >= FStep.RangeHi))) then
    begin
      Inc(FStep.Steps);
      Arm(T, True);
      Exit;
    end;
    FStep.Active := False;
    DoStop(srStep, T, '');
    Exit;
  end;
  if FStep.Active and (FStep.ThreadId = T.ThreadId) and FStep.ExpectSS then
  begin
    FStep.ExpectSS := False;
    StepOn(T);
  end;
  // otherwise: our own internal step over a breakpoint, or a stray trap - just go on
end;

procedure TDebugger.StepOn(T: TDbgThread);
var
  WantSS: Boolean;
begin
  if StepAdvance(T, WantSS) then
    DoStop(FStepStopReason, T, '')
  else
    Arm(T, WantSS);
end;

procedure TDebugger.HandleBreakpointHit(T: TDbgThread; Addr: Cardinal; var Cont: Cardinal);
var
  Loc: TBPLoc;
  Installed: Boolean;
  B: Byte;
  Ctx: TContext;
  TI: Integer;
  Purpose: TTempPurpose;
  DispThread: TDbgThread;
begin
  Lock;
  try
    Loc := FindLoc(Addr);
    Installed := (Loc <> nil) and Loc.Installed;
  finally
    Unlock;
  end;
  if not Installed then
  begin
    if ReadMemRaw(Addr, B, 1) and (B <> $CC) then
    begin
      // a breakpoint of ours that was removed after the thread already hit it: the thread
      // runs the instruction that is there again (also while a pause is requested - the
      // break-in thread serves that, and this one must not go on behind the int 3)
      SetEIP(T, Addr);
      Exit;
    end;
    if FPauseRequested then
    begin
      // break-in thread created by DebugBreakProcess
      FPauseRequested := False;
      FPauseFallback := False;
      FBreakInThreadId := T.ThreadId;
      DispThread := MainThread;
      if DispThread = nil then DispThread := T;
      DoStop(srPause, DispThread, '');
      Exit;
    end;
    if FBreakInPending then
    begin
      FBreakInPending := False;
      Exit;
    end;
    // int 3 compiled into the program
    DoStop(srBreakpoint, T, Format('Hard-coded breakpoint (int 3) at $%.8x', [Addr]));
    Exit;
  end;
  SetEIP(T, Addr);
  T.AtBP := Addr;
  if not GetCtx(T, Ctx) then Exit;
  TI := FindTemp(Addr, T, Ctx);
  if TI >= 0 then
  begin
    Purpose := FTemps[TI].Purpose;
    case Purpose of
      tpRunTo:
        begin
          ClearStep;
          DoStop(srRunToLine, T, '');
        end;
      tpEntry:
        begin
          ClearStep;
          DoStop(srEntry, T, '');
        end;
      tpStepOut, tpHandler, tpStepReturn:
        begin
          ClearStep;
          DoStop(srStep, T, '');
        end;
      tpStepOverCall:
        begin
          RemoveTemp(TI);
          StepOn(T);
        end;
      tpRangeExit, tpRangeRet:
        begin
          // left the line that was being run at full speed
          ClearTemps;
          FStep.LastWasRet := Purpose = tpRangeRet;
          FStep.Steps := 0;
          StepOn(T);
        end;
    end;
    Exit;
  end;
  if EnabledBPAt(Addr) and UserBPShouldStop(Addr, T) then
  begin
    ClearStep;
    DoStop(srBreakpoint, T, '');
    Exit;
  end;
  // not for this thread / disabled / condition false: step across transparently
  Arm(T, FStep.Active and (FStep.ThreadId = T.ThreadId) and FStep.ExpectSS);
end;

{ an exception's line of the event log (Delphi 7's): Head, its class and message, the process }
function TDebugger.ExcLogText(const Head, Cls, Msg: string): string;
begin
  Result := Format('%s class %s with message ''%s''. Process %s (%d)', [Head, Cls, Msg, ExeBaseName, FProcessId]);
end;

{ the text of an exception's stop (Delphi 7's notification): How the project met it, its class and
  message, Tail after them }
function TDebugger.ExcStopText(const How, Cls, Msg, Tail: string): string;
begin
  Result := Format('Project %s %s exception class %s with message ''%s''.%s', [ExeBaseName, How, Cls, Msg, Tail]);
end;

procedure TDebugger.HandleDelphiException(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
var
  Obj: Cardinal;
  Cls, Msg: string;
  First: Boolean;
begin
  Cont := DBG_EXCEPTION_NOT_HANDLED;
  First := DE.Exception.dwFirstChance <> 0;
  Obj := 0;
  if DE.Exception.ExceptionRecord.NumberParameters >= 2 then
    Obj := DE.Exception.ExceptionRecord.ExceptionInformation[1];
  T.OSExcReported := False;
  if First and T.ReRaise then
  begin
    T.ReRaise := False;        // "raise;" of an exception that was already reported
    Exit;
  end;
  Cls := ReadClassNameOf(Obj);
  if Cls = '' then Cls := 'TObject';
  Msg := ReadExceptionMessage(Obj);
  if First then
    QueueLog(lkException, ExcLogText(Format('First chance exception at $%.8x. Exception',
      [DE.Exception.ExceptionRecord.ExceptionInformation[0]]), Cls, Msg))
  else
    QueueLog(lkException, ExcLogText('Unhandled exception', Cls, Msg));
  if not First then
  begin
    T.LastExcObj := Obj;
    DoStop(srException, T, ExcStopText('raised an unhandled', Cls, Msg, ' The process will terminate.'));
    Exit;
  end;
  if FStopOnDelphi and ReportsException(Cls) then
  begin
    T.LastExcObj := Obj;
    DoStop(srException, T, ExcStopText('raised', Cls, Msg, ''));
  end;
end;

procedure TDebugger.HandleDelphiNotify(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
var
  Code, Arg0, Arg1, Limit: Cardinal;
  Cls, Msg: string;
  Ctx: TContext;
begin
  // notifications raised by the Delphi RTL because System.DebugHook is set: always continue
  Cont := DBG_CONTINUE;
  Code := DE.Exception.ExceptionRecord.ExceptionCode;
  Arg0 := 0;
  Arg1 := 0;
  if DE.Exception.ExceptionRecord.NumberParameters >= 1 then
    Arg0 := DE.Exception.ExceptionRecord.ExceptionInformation[0];
  if DE.Exception.ExceptionRecord.NumberParameters >= 2 then
    Arg1 := DE.Exception.ExceptionRecord.ExceptionInformation[1];
  case Code of
    cDelphiReRaise:
      T.ReRaise := True;
    cDelphiExcept, cDelphiFinally:
      // Arg0 = address of the except/finally code that is about to run
      // (a step that left the code with line numbers long ago must not catch unrelated
      //  exceptions later on; handlers without source are of no use as a stop location)
      if FStep.Active and (FStep.ThreadId = T.ThreadId) and (Arg0 <> 0) and HasLineAbs(Arg0) and
        (not FStep.Passive or (GetTickCount - FStep.PassiveTick < 1000)) then
      begin
        if FStep.AwaitHandler then Limit := 0 else Limit := FStep.StartEBP;
        AddTemp(Arg0, T.ThreadId, tcEBP, Limit, tpHandler);
      end;
    cDelphiUnhandled:
      begin
        // Arg0 = exception address, Arg1 = exception object; nothing will handle it
        Cls := ReadClassNameOf(Arg1);
        Msg := ReadExceptionMessage(Arg1);
        if (Arg1 <> 0) and (Arg1 <> T.LastExcObj) and not T.OSExcReported then
        begin
          if Cls = '' then Cls := 'TObject';
          QueueLog(lkException, ExcLogText('Unhandled exception', Cls, Msg));
          T.LastExcObj := Arg1;
          DoStop(srException, T, ExcStopText('raised an unhandled', Cls, Msg, ''));
        end;
        T.OSExcReported := False;
      end;
    cNonDelphiException:
      begin
        // Arg0 = pointer to the CONTEXT of the fault, Arg1 = exception object made by the RTL
        if T.OSExcReported then
        begin
          T.OSExcReported := False;
          T.LastExcObj := Arg1;
          Exit;
        end;
        Cls := ReadClassNameOf(Arg1);
        if Cls = '' then Cls := 'EExternalException';
        Msg := ReadExceptionMessage(Arg1);
        QueueLog(lkException, ExcLogText('First chance exception. Exception', Cls, Msg));
        if FStopOnOS and ReportsException(Cls) then
        begin
          T.LastExcObj := Arg1;
          FillChar(Ctx, SizeOf(Ctx), 0);
          if (Arg0 <> 0) and ReadMemRaw(Arg0, Ctx, SizeOf(Ctx)) and (Ctx.Eip <> 0) then
          begin
            // show the faulting location rather than the RTL's notification call
            FOverrideCtx := True;
            FOvEIP := Ctx.Eip;
            FOvEBP := Ctx.Ebp;
            FOvESP := Ctx.Esp;
          end;
          DoStop(srException, T, ExcStopText('raised', Cls, Msg, ''));
          FOverrideCtx := False;
        end;
      end;
  end;
end;

procedure TDebugger.HandleOSException(T: TDbgThread; var DE: TDebugEvent; var Cont: Cardinal);
var
  I: Integer;
  Code, Addr: Cardinal;
  Cls, Msg, ModName, Op: string;
  Mapped, First: Boolean;
  M: TDbgModule;
begin
  Cont := DBG_EXCEPTION_NOT_HANDLED;
  Code := DE.Exception.ExceptionRecord.ExceptionCode;
  Addr := Cardinal(DE.Exception.ExceptionRecord.ExceptionAddress);
  First := DE.Exception.dwFirstChance <> 0;
  Mapped := True;
  case Code of
    EXC_ACCESS_VIOLATION:
      begin
        Cls := 'EAccessViolation';
        M := ModuleByAddr(Addr);
        if M <> nil then ModName := M.Name else ModName := ExeBaseName;
        Op := 'Read';
        if DE.Exception.ExceptionRecord.NumberParameters >= 2 then
        begin
          case DE.Exception.ExceptionRecord.ExceptionInformation[0] of
            1: Op := 'Write';
            8: Op := 'Execution';
          end;
          Msg := Format('Access violation at address %.8X in module ''%s''. %s of address %.8X',
            [Addr, ModName, Op, DE.Exception.ExceptionRecord.ExceptionInformation[1]]);
        end
        else
          Msg := Format('Access violation at address %.8X in module ''%s''', [Addr, ModName]);
      end;
    $C0000094: begin Cls := 'EDivByZero'; Msg := 'Division by zero'; end;
    $C0000095: begin Cls := 'EIntOverflow'; Msg := 'Integer overflow'; end;
    $C000008C: begin Cls := 'ERangeError'; Msg := 'Range check error'; end;
    $C000008E: begin Cls := 'EZeroDivide'; Msg := 'Floating point division by zero'; end;
    $C0000090, $C000008F, $C0000092: begin Cls := 'EInvalidOp'; Msg := 'Invalid floating point operation'; end;
    $C0000091: begin Cls := 'EOverflow'; Msg := 'Floating point overflow'; end;
    $C0000093, $C000008D: begin Cls := 'EUnderflow'; Msg := 'Floating point underflow'; end;
    $C00000FD: begin Cls := 'EStackOverflow'; Msg := 'Stack overflow'; end;
    $C0000096: begin Cls := 'EPrivilege'; Msg := 'Privileged instruction'; end;
    $C000001D: begin Cls := 'EExternalException'; Msg := 'Illegal instruction'; end;
    $C000013A, EXC_CONTROL_C: begin Cls := 'EControlC'; Msg := 'Control-C hit'; Mapped := False; end;
    EXC_CONTROL_BREAK: begin Cls := 'EControlC'; Msg := 'Control-Break hit'; Mapped := False; end;
  else
    Cls := 'EExternalException';
    Msg := Format('External exception %X', [Code]);
    Mapped := False;
  end;
  if First then
    QueueLog(lkException, ExcLogText(Format('First chance exception at $%.8x. Exception', [Addr]), Cls, Msg))
  else
    QueueLog(lkException, ExcLogText(Format('Unhandled exception at $%.8x. Exception', [Addr]), Cls, Msg));
  if not First then
  begin
    DoStop(srException, T, ExcStopText('faulted with an unhandled', Cls, Msg, ' The process will terminate.'), True);
    Exit;
  end;
  T.OSExcReported := False;
  { a rule of the user's decides who handles it and, when the debugger stops, how the program
    goes on (Run handled: as handled - the instruction runs again; the program's own handlers
    get exceptions the debugger does not stop at) }
  for I := 0 to High(FOSRules) do
    if (Code >= FOSRules[I].Low) and (Code <= FOSRules[I].High) then
    begin
      if FOSRules[I].Stop and ReportsException(Cls) then
      begin
        if FOSRules[I].RunHandled then Cont := DBG_CONTINUE;
        T.OSExcReported := True;
        DoStop(srException, T, ExcStopText('raised', Cls, Msg, ''));
      end;
      Exit;
    end;
  if Mapped and FStopOnOS and ReportsException(Cls) then
  begin
    T.OSExcReported := True;
    DoStop(srException, T, ExcStopText('raised', Cls, Msg, ''));
  end;
end;

procedure TDebugger.SetOSRules(const Rules: array of TDbgOSRule);
var
  I: Integer;
begin
  SetLength(FOSRules, Length(Rules));
  for I := 0 to High(Rules) do FOSRules[I] := Rules[I];
end;

{ public: control }

function TDebugger.Start(const ExeName, Params, WorkDir: string): Boolean;
begin
  try
    Result := BeginSession(ExeName, Params, WorkDir, 0);
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

{ the image of a running process (Attach): the Unicode name, as a usable one }
function ProcessImageName(Pid: Cardinal): string;
var
  H: THandle;
  Buf: array[0..1023] of WideChar;
  Size: DWORD;
  W: WideString;
begin
  Result := '';
  H := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, Pid);
  if H = 0 then Exit;
  try
    Size := Length(Buf);
    if QueryFullProcessImageNameW(H, 0, Buf, Size) then
    begin
      SetString(W, Buf, Size);
      Result := UsablePath(W);
    end;
  finally
    CloseHandle(H);
  end;
end;

function TDebugger.Attach(ProcessId: Cardinal): Boolean;
var
  Name: string;
begin
  Result := False;
  Name := ProcessImageName(ProcessId);
  if Name = '' then
  begin
    FLastError := Format('Cannot open process %d: %s', [ProcessId, SysErrorMessage(GetLastError)]);
    Exit;
  end;
  try
    Result := BeginSession(Name, '', '', ProcessId);
  except
    on E: Exception do FLastError := E.Message;
  end;
end;

function TDebugger.Attached: Boolean;
begin
  Result := (FState <> dsNone) and (FAttachPid <> 0);
end;

procedure TDebugger.Detach;
begin
  Lock;
  try
    if FState = dsPaused then
      PostCommand(dcDetach)
    else if FState = dsRunning then
    begin
      FDetachRequested := True;
      Pause;
    end;
  finally
    Unlock;
  end;
end;

function TDebugger.BeginSession(const ExeName, Params, WorkDir: string; AttachPid: Cardinal): Boolean;
var
  I: Integer;
begin
  Result := False;
  FLastError := '';
  if (FState <> dsNone) and FTerminating and (FWorker <> nil) then
    // Stop was requested: wait for the old session to finish
    WaitForSingleObject(FWorker.Handle, 10000);
  if FState <> dsNone then
  begin
    FLastError := 'A program is already being debugged';
    Exit;
  end;
  if FWorker <> nil then
  begin
    FWorker.WaitFor;
    FreeAndNil(FWorker);
    // deliver what the finished session still has queued (its exit) before the next one starts
    try
      DispatchEvents;
    except
    end;
  end;
  FExeName := ExpandFileName(ExeName);
  if not FileExists(FExeName) then
  begin
    FLastError := 'File not found: ' + FExeName;
    Exit;
  end;
  FParams := Params;
  FWorkDir := WorkDir;
  SessionCleanup;
  // debug information of the main module
  FreeAndNil(FExeInfo);
  FExeInfo := TTD32Info.Create;
  FExeInfo.LoadAny(FExeName);
  FSrcDirs.Assign(FSourceDirs);
  for I := 0 to FBreakpoints.Count - 1 do
  begin
    TDbgBreakpoint(FBreakpoints[I]).HitCount := 0;
    TDbgBreakpoint(FBreakpoints[I]).Valid := False;
  end;
  FillChar(FStep, SizeOf(FStep), 0);
  FPendingCmd := dcNone;
  FTerminating := False;
  FProcessGone := False;
  FSeenInitialBP := False;
  FAttachPid := AttachPid;
  FDetachRequested := False;
  FDetaching := False;
  FDetached := False;
  FPauseRequested := False;
  FPauseFallback := False;
  FBreakInPending := False;
  FBreakInThreadId := 0;
  FOverrideCtx := False;
  FStopIsException := False;
  FStopFault := False;
  FExitCode := 0;
  FProcessId := 0;
  FCurrentFrame := 0;
  FStopFrameIndex := 0;
  ResetEvent(FStartEvent);
  ResetEvent(FCmdEvent);
  FStartResult := False;
  FSessStopAtEntry := FStopAtEntry;
  FWorker := TDbgWorker.Create(Self);
  WaitForSingleObject(FStartEvent, INFINITE);
  Result := FStartResult;
  if not Result then
  begin
    FWorker.WaitFor;
    FreeAndNil(FWorker);
    if FLastError = '' then FLastError := 'Cannot start the process';
  end;
end;

procedure TDebugger.Resume;
begin
  PostCommand(dcResume);
end;

procedure TDebugger.StepOver;
begin
  PostCommand(dcStepOver);
end;

procedure TDebugger.StepInto;
begin
  PostCommand(dcStepInto);
end;

procedure TDebugger.StepOut;
begin
  PostCommand(dcStepOut);
end;

procedure TDebugger.RunToLine(const FileName: string; Line: Integer);
begin
  Lock;
  try
    FRunToFile := FileName;
    FRunToLine := Line;
  finally
    Unlock;
  end;
  PostCommand(dcRunToLine);
end;

procedure TDebugger.Pause;
begin
  if (FState <> dsRunning) or (FProcessHandle = 0) or FPauseRequested then Exit;
  FPauseTick := GetTickCount;
  FBreakInThreadId := 0;
  FPauseRequested := True;
  if FPauseByBreakIn and DebugBreakProcess(FProcessHandle) then
  begin
    FPauseFallback := False;
    FBreakInPending := False;
  end
  else
    FPauseFallback := True;       // the debug thread freezes the threads instead
end;

{ The program ends; the session ends with its exit event (evExit). A stand is over at once: the
  inspections (dsPaused) must not reach the threads and modules the debug thread frees once the
  process has gone (SessionCleanup) }
procedure TDebugger.Stop;
begin
  if (FState = dsNone) and (FProcessHandle = 0) then Exit;
  Lock;
  try
    FTerminating := True;
    if FState = dsPaused then FState := dsRunning;
  finally
    Unlock;
  end;
  if FProcessHandle <> 0 then TerminateProcess(FProcessHandle, 0);
  SetEvent(FCmdEvent);
end;

{ public: breakpoints }

{ ---------------------------------------------------------------- TDbgBreakpoint }

constructor TDbgBreakpoint.Create;
begin
  inherited Create;
  Id := Cardinal(InterlockedIncrement(BreakpointIds));
  Enabled := True;
  DoBreak := True;
  DataLength := 4;
end;

procedure TDbgBreakpoint.Assign(Src: TDbgBreakpoint);
begin
  Kind := Src.Kind;
  FileName := Src.FileName;
  Line := Src.Line;
  Address := Src.Address;
  DataLength := Src.DataLength;
  DataRead := Src.DataRead;
  Enabled := Src.Enabled;
  Condition := Src.Condition;
  PassCount := Src.PassCount;
  Group := Src.Group;
  DoBreak := Src.DoBreak;
  IgnoreExceptions := Src.IgnoreExceptions;
  HandleExceptions := Src.HandleExceptions;
  LogMessage := Src.LogMessage;
  EvalExpr := Src.EvalExpr;
  LogResult := Src.LogResult;
  EnableGroup := Src.EnableGroup;
  DisableGroup := Src.DisableGroup;
  Watch := Src.Watch;
end;

function TDebugger.AddBreakpointAs(Settings: TDbgBreakpoint): TDbgBreakpoint;
begin
  if Settings.Kind = bkSource then
  begin
    Result := AddBreakpoint(Settings.FileName, Settings.Line);
    ChangeBreakpointTo(Result, Settings);
    Exit;
  end;
  Result := TDbgBreakpoint.Create;
  Result.Assign(Settings);
  Lock;
  try
    FBreakpoints.Add(Result);
    try
      if FProcessHandle <> 0 then ResolveBP(Result);
    except
      Result.Valid := False;
    end;
  finally
    Unlock;
  end;
end;

{ the passes counted so far go on unless the breakpoint moves (Delphi 7's setters of the Open Tools
  API: only a new place makes its breakpoint in the process anew) }
procedure TDebugger.ChangeBreakpointTo(BP, Settings: TDbgBreakpoint);
var
  Hits: Integer;
  SamePlace: Boolean;
begin
  if (BP = nil) or (Settings = nil) then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    Hits := BP.HitCount;
    SamePlace := (Settings.Kind = BP.Kind) and (Settings.Line = BP.Line) and (Settings.Address = BP.Address) and
      SameText(Settings.FileName, BP.FileName);
    BP.Assign(Settings);
    BreakpointChanged(BP);
    if SamePlace then BP.HitCount := Hits;
  finally
    Unlock;
  end;
end;

function TDebugger.AddBreakpoint(const FileName: string; Line: Integer): TDbgBreakpoint;
var
  I, J: Integer;
  M: TDbgModule;
begin
  Result := TDbgBreakpoint.Create;
  Result.FileName := FileName;
  Result.Line := Line;
  Result.Enabled := True;
  Lock;
  try
    FBreakpoints.Add(Result);
    try
      // the new file name may locate sources that could not be found before
      for I := 0 to FModules.Count - 1 do
      begin
        M := TDbgModule(FModules[I]);
        if M.SrcPaths <> nil then
          for J := 0 to M.SrcPaths.Count - 1 do
            if (M.SrcPaths[J] <> '') and (M.SrcPaths[J][1] = '*') then M.SrcPaths[J] := '';
      end;
      if FProcessHandle <> 0 then ResolveBP(Result);
    except
      Result.Valid := False;
    end;
  finally
    Unlock;
  end;
end;

procedure TDebugger.RemoveBreakpoint(BP: TDbgBreakpoint);
var
  I: Integer;
begin
  if BP = nil then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    UnresolveBP(BP);
    FBreakpoints.Remove(BP);
    if BP.Kind = bkData then
    begin
      for I := 0 to High(FDataSlots) do
        if FDataSlots[I] = BP then FDataSlots[I] := nil;
      FDataDirty := True;
    end;
  finally
    Unlock;
  end;
  BP.Free;
end;

function TDebugger.FindBreakpoint(const FileName: string; Line: Integer): TDbgBreakpoint;
var
  I: Integer;
begin
  Lock;
  try
    for I := 0 to FBreakpoints.Count - 1 do
    begin
      Result := TDbgBreakpoint(FBreakpoints[I]);
      if (Result.Kind = bkSource) and (Result.Line = Line) and SameText(Result.FileName, FileName) then Exit;
    end;
    Result := nil;
  finally
    Unlock;
  end;
end;

procedure TDebugger.ClearBreakpoints;
var
  I: Integer;
begin
  Lock;
  try
    for I := FBreakpoints.Count - 1 downto 0 do
    begin
      UnresolveBP(TDbgBreakpoint(FBreakpoints[I]));
      TObject(FBreakpoints[I]).Free;
    end;
    FBreakpoints.Clear;
    FillChar(FDataSlots, SizeOf(FDataSlots), 0);
    FDataDirty := True;
  finally
    Unlock;
  end;
end;

procedure TDebugger.BreakpointChanged(BP: TDbgBreakpoint);
begin
  if BP = nil then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    BP.HitCount := 0;
    try
      if FProcessHandle <> 0 then ResolveBP(BP);
    except
      BP.Valid := False;
    end;
  finally
    Unlock;
  end;
end;

procedure TDebugger.ChangeBreakpoint(BP: TDbgBreakpoint; ALine: Integer; AEnabled: Boolean;
  const ACondition: string; APassCount: Integer);
begin
  if BP = nil then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    BP.Line := ALine;
    BP.Enabled := AEnabled;
    BP.Condition := ACondition;
    BP.PassCount := APassCount;
    BreakpointChanged(BP);             // the lock is taken again there: a critical section allows it
  finally
    Unlock;
  end;
end;

{ its other settings read under the lock: the debug thread changes Enabled (a group's action) }
procedure TDebugger.SetBreakpointEnabled(BP: TDbgBreakpoint; Value: Boolean);
begin
  if BP = nil then Exit;
  Lock;
  try
    if FBreakpoints.IndexOf(BP) < 0 then Exit;
    ChangeBreakpoint(BP, BP.Line, Value, BP.Condition, BP.PassCount);
  finally
    Unlock;
  end;
end;

function TDebugger.BreakpointCount: Integer;
begin
  Result := FBreakpoints.Count;
end;

function TDebugger.GetBreakpoint(Index: Integer): TDbgBreakpoint;
begin
  Result := TDbgBreakpoint(FBreakpoints[Index]);
end;

function TDebugger.BreakpointById(Id: Cardinal): TDbgBreakpoint;
var
  I: Integer;
begin
  Lock;
  try
    for I := 0 to FBreakpoints.Count - 1 do
    begin
      Result := TDbgBreakpoint(FBreakpoints[I]);
      if Result.Id = Id then Exit;
    end;
    Result := nil;
  finally
    Unlock;
  end;
end;

{ public: debug info }

function TDebugger.HasDebugInfo: Boolean;
begin
  Result := (FExeInfo <> nil) and FExeInfo.HasLineInfo;
end;

{ public: inspection }

procedure TDebugger.SetCurrentFrame(Value: Integer);
begin
  if Value < 0 then Value := 0;
  FCurrentFrame := Value;
end;

function TDebugger.CurrentThreadId: Cardinal;
begin
  if (FState = dsPaused) and (FCurThread <> nil) then
    Result := FCurThread.ThreadId
  else
    Result := 0;
end;

function TDebugger.ThreadHandle(ThreadId: Cardinal): THandle;
var
  T: TDbgThread;
begin
  Lock;
  try
    T := FindThread(ThreadId);
    if T <> nil then Result := T.Handle else Result := 0;
  finally
    Unlock;
  end;
end;

function TDebugger.SelectThread(ThreadId: Cardinal): Boolean;
var
  T: TDbgThread;
begin
  Result := False;
  if FState <> dsPaused then Exit;
  T := FindThread(ThreadId);
  if T = nil then Exit;
  if T <> FCurThread then
  begin
    FCurThread := T;
    FOverrideCtx := False;
    ForgetFrames;
    FCurrentFrame := 0;
  end;
  Result := True;
end;

function TDebugger.SaveInspection: TDbgInspection;
begin
  if FCurThread <> nil then Result.ThreadId := FCurThread.ThreadId else Result.ThreadId := 0;
  Result.Frame := FCurrentFrame;
  Result.Overridden := FOverrideCtx;
  Result.EIP := FOvEIP;
  Result.EBP := FOvEBP;
  Result.ESP := FOvESP;
end;

procedure TDebugger.RestoreInspection(const S: TDbgInspection);
var
  T: TDbgThread;
begin
  if FState <> dsPaused then Exit;
  T := FindThread(S.ThreadId);
  if T = nil then Exit;
  FCurThread := T;
  FOverrideCtx := S.Overridden;
  FOvEIP := S.EIP;
  FOvEBP := S.EBP;
  FOvESP := S.ESP;
  ForgetFrames;
  FCurrentFrame := S.Frame;
end;

function TDebugger.GetCallStack(out Frames: TDbgFrameArray): Boolean;
var
  Fx: TFrameExArray;
  I: Integer;
begin
  Frames := nil;
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  try
    Fx := CurFrames;
    SetLength(Frames, Length(Fx));
    for I := 0 to High(Fx) do Frames[I] := FrameToPublic(Fx[I], I);
    Result := Length(Frames) > 0;
  except
    Result := False;
  end;
end;

function TDebugger.GetLocals(out Vars: TDbgVarArray): Boolean;
var
  Ev: TDbgEvaluator;
begin
  Vars := nil;
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  try
    Ev := FrameEvaluator;
    try
      Result := Ev.GetLocals(Vars);
    finally
      Ev.Free;
    end;
  except
    Result := False;
  end;
end;

{ the result of an evaluation of Expr before there is one }
procedure InitVar(out V: TDbgVar; const Expr: string);
begin
  V.Name := Expr;
  V.Expr := Expr;
  V.Value := '';
  V.TypeName := '';
  V.Expandable := False;
  V.Address := 0;
  V.Size := 0;
  V.CanModify := False;
end;

function TDebugger.Evaluate(const Expr: string; out V: TDbgVar; out Error: string; AllowCalls: Boolean): Boolean;
var
  Ev: TDbgEvaluator;
begin
  Result := False;
  InitVar(V, Expr);
  Error := '';
  if (FState <> dsPaused) or (FCurThread = nil) then
  begin
    Error := 'The program is not paused';
    Exit;
  end;
  try
    Ev := FrameEvaluator;
    try
      Ev.AllowCalls := AllowCalls;
      Result := Ev.Evaluate(Expr, V, Error);
    finally
      Ev.Free;
    end;
  except
    on E: Exception do
    begin
      Error := E.Message;
      Result := False;
    end;
  end;
end;

function TDebugger.GetChildren(const Expr: string; out Vars: TDbgVarArray; AllowCalls: Boolean): Boolean;
var
  Ev: TDbgEvaluator;
  Err: string;
begin
  Vars := nil;
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  try
    Ev := FrameEvaluator;
    try
      Ev.AllowCalls := AllowCalls;
      Result := Ev.GetChildren(Expr, Vars, Err);
    finally
      Ev.Free;
    end;
  except
    Result := False;
  end;
end;

function TDebugger.GetMembers(const Expr: string; Dynamic: Boolean; out Methods, Props: TDbgVarArray): Boolean;
var
  Ev: TDbgEvaluator;
  Err: string;
begin
  Methods := nil;
  Props := nil;
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  try
    Ev := FrameEvaluator;
    try
      Result := Ev.GetMembers(Expr, Dynamic, Methods, Props, Err);
    finally
      Ev.Free;
    end;
  except
    Result := False;
  end;
end;

function TDebugger.Inspect(const Expr: string; Dynamic: Boolean; out V: TDbgVar; out Children, Methods,
  Props: TDbgVarArray; out Error: string): Boolean;
var
  Ev: TDbgEvaluator;
begin
  Result := False;
  InitVar(V, Expr);
  Children := nil;
  Methods := nil;
  Props := nil;
  Error := '';
  if (FState <> dsPaused) or (FCurThread = nil) then
  begin
    Error := 'The program is not paused';
    Exit;
  end;
  try
    Ev := FrameEvaluator;
    try
      Ev.AllowCalls := True;
      Result := Ev.Inspect(Expr, Dynamic, V, Children, Methods, Props, Error);
    finally
      Ev.Free;
    end;
  except
    on E: Exception do
    begin
      Error := E.Message;
      Result := False;
    end;
  end;
end;

function TDebugger.EvalBoolean(const Expr: string; out Value: Boolean; out Error: string): Boolean;
var
  Ev: TDbgEvaluator;
begin
  Result := False;
  Value := False;
  Error := '';
  if (FState <> dsPaused) or (FCurThread = nil) then
  begin
    Error := 'The program is not paused';
    Exit;
  end;
  try
    Ev := FrameEvaluator;
    try
      Ev.AllowCalls := True;
      Result := Ev.EvalBoolean(Expr, Value, Error);
    finally
      Ev.Free;
    end;
  except
    on E: Exception do
    begin
      Error := E.Message;
      Result := False;
    end;
  end;
end;

function TDebugger.Modify(const Expr, NewValue: string; out Error: string; AllowCalls: Boolean): Boolean;
var
  Ev: TDbgEvaluator;
begin
  Result := False;
  Error := '';
  if (FState <> dsPaused) or (FCurThread = nil) then
  begin
    Error := 'The program is not paused';
    Exit;
  end;
  try
    Ev := FrameEvaluator;
    try
      Ev.AllowCalls := AllowCalls;
      Result := Ev.Modify(Expr, NewValue, Error);
    finally
      Ev.Free;
    end;
  except
    on E: Exception do
    begin
      Error := E.Message;
      Result := False;
    end;
  end;
end;

function TDebugger.GetThreads(out Threads: TDbgThreadArray; Places: Boolean): Boolean;
var
  I, J, N: Integer;
  T: TDbgThread;
  Ctx: TContext;
  Fx: TFrameExArray;
  F: TDbgFrame;
  S: string;
begin
  Threads := nil;
  Result := False;
  if FState <> dsPaused then Exit;
  { under the lock: the debug thread frees the threads (SessionCleanup) under it }
  Lock;
  try
    try
      N := 0;
      for I := 0 to FThreads.Count - 1 do
      begin
        T := TDbgThread(FThreads[I]);
        if (T.ThreadId = FBreakInThreadId) and (FBreakInThreadId <> 0) then Continue;
        SetLength(Threads, N + 1);
        Threads[N].ThreadId := T.ThreadId;
        Threads[N].IsCurrent := T = FCurThread;
        S := '';
        if Places and GetCtx(T, Ctx) then
        begin
          // innermost frame that has a symbol, preferably with source
          Fx := WalkStack(T, Ctx.Eip, Ctx.Ebp, Ctx.Esp, 48);
          J := FirstSourceFrame(Fx);
          if J >= 0 then
          begin
            F := FrameToPublic(Fx[J], J);
            S := Format('%s (%s:%d)', [F.ProcName, ExtractFileName(F.FileName), F.Line]);
          end
          else
            for J := 0 to High(Fx) do
            begin
              F := FrameToPublic(Fx[J], J);
              if F.ProcName <> '' then
              begin
                S := F.ProcName;
                Break;
              end;
            end;
          if S = '' then
          begin
            LocationOf(Ctx.Eip, F);
            S := Format('$%.8x %s', [Ctx.Eip, F.ModuleName]);
          end;
        end;
        Threads[N].Location := S;
        Inc(N);
      end;
      Result := N > 0;
    except
      Result := False;
    end;
  finally
    Unlock;
  end;
end;

function TDebugger.GetModules(out Modules: TDbgModuleArray): Boolean;
var
  I: Integer;
  M: TDbgModule;
begin
  Modules := nil;
  Result := False;
  if FState = dsNone then Exit;
  Lock;
  try
    SetLength(Modules, FModules.Count);
    for I := 0 to FModules.Count - 1 do
    begin
      M := TDbgModule(FModules[I]);
      Modules[I].Name := M.Name;
      Modules[I].BaseAddr := M.Base;
      Modules[I].HasDebugInfo := M.Info <> nil;
      Modules[I].Path := M.Path;
      Modules[I].Size := M.Size;
    end;
    Result := Length(Modules) > 0;
  finally
    Unlock;
  end;
end;

function TDebugger.GetRegisters(out R: TDbgRegisters): Boolean;
var
  Ctx: TContext;
begin
  FillChar(R, SizeOf(R), 0);
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  if not GetCtx(FCurThread, Ctx) then Exit;
  R.EAX := Ctx.Eax;
  R.EBX := Ctx.Ebx;
  R.ECX := Ctx.Ecx;
  R.EDX := Ctx.Edx;
  R.ESI := Ctx.Esi;
  R.EDI := Ctx.Edi;
  R.EBP := Ctx.Ebp;
  R.ESP := Ctx.Esp;
  R.EIP := Ctx.Eip;
  R.EFlags := Ctx.EFlags;
  R.CS := Ctx.SegCs;
  R.DS := Ctx.SegDs;
  R.ES := Ctx.SegEs;
  R.FS := Ctx.SegFs;
  R.GS := Ctx.SegGs;
  R.SS := Ctx.SegSs;
  Result := True;
end;

function TDebugger.GetFPU(out F: TDbgFPU): Boolean;
var
  Ctx: TContext;
  I: Integer;
begin
  FillChar(F, SizeOf(F), 0);
  Result := False;
  if (FState <> dsPaused) or (FCurThread = nil) then Exit;
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.ContextFlags := CONTEXT_FLOATING_POINT;
  if not GetThreadContext(FCurThread.Handle, Ctx) then Exit;
  F.Control := Ctx.FloatSave.ControlWord and $FFFF;
  F.Status := Ctx.FloatSave.StatusWord and $FFFF;
  F.Tag := Ctx.FloatSave.TagWord and $FFFF;
  F.ErrorOffset := Ctx.FloatSave.ErrorOffset;
  F.ErrorSelector := Ctx.FloatSave.ErrorSelector;
  F.DataOffset := Ctx.FloatSave.DataOffset;
  F.DataSelector := Ctx.FloatSave.DataSelector;
  for I := 0 to 7 do Move(Ctx.FloatSave.RegisterArea[I * 10], F.ST[I], 10);
  Result := True;
end;

function TDebugger.SourceLineAt(Addr: Cardinal; out FileName: string; out Line: Integer; out Exact: Boolean): Boolean;
var
  M: TDbgModule;
  L: TTDLine;
begin
  FileName := '';
  Line := 0;
  Exact := False;
  { the IDE asks while the program runs (the Breakpoints view): the module must not go meanwhile }
  Lock;
  try
    Result := (FState <> dsNone) and FindLineAbs(Addr, M, L);
    if not Result then Exit;
    FileName := ResolveSource(M, L.Src);
    Line := L.Line;
    Exact := Addr = M.Base + L.Addr;
  finally
    Unlock;
  end;
end;

function TDebugger.LineCodeAt(Addr: Cardinal; out Start, Size: Cardinal): Boolean;
var
  M: TDbgModule;
  L: TTDLine;
begin
  Start := 0;
  Size := 0;
  Lock;
  try
    Result := (FState <> dsNone) and FindLineAbs(Addr, M, L);
    if not Result then Exit;
    Start := M.Base + L.Addr;
    Size := L.EndAddr - L.Addr;
  finally
    Unlock;
  end;
end;

function TDebugger.GetModuleDetails(Base: Cardinal; out D: TDbgModuleDetails): Boolean;
var
  I, J, N: Integer;
  M: TDbgModule;
  Hdr: array[0..$3FF] of Byte;
  H: TPEHeaderInfo;
  Info: TTD32Info;
  S: string;
begin
  D.EntryPoint := 0;
  Result := False;
  if FState <> dsPaused then Exit;
  M := nil;
  Lock;
  try
    for I := 0 to FModules.Count - 1 do
      if TDbgModule(FModules[I]).Base = Base then M := TDbgModule(FModules[I]);
    if M <> nil then LoadExports(M);
  finally
    Unlock;
  end;
  if M = nil then Exit;
  if ReadMemRaw(M.Base, Hdr, SizeOf(Hdr)) and ParsePEHeader(Hdr, SizeOf(Hdr), H) and (H.EntryRVA <> 0) then
    D.EntryPoint := M.Base + H.EntryRVA;
  Info := M.Info;
  if Info <> nil then
  begin
    SetLength(D.Units, Info.ModuleCount);
    for I := 0 to Info.ModuleCount - 1 do D.Units[I].Name := Info.Modules[I].Name;
    SetLength(D.Files, Info.SrcCount);
    for I := 0 to Info.SrcCount - 1 do
    begin
      S := ResolveSource(M, I);
      D.Files[I] := S;
      J := Info.SrcModule[I];
      if (J >= 0) and (J < Length(D.Units)) then
      begin
        N := Length(D.Units[J].Files);
        SetLength(D.Units[J].Files, N + 1);
        D.Units[J].Files[N] := S;
      end;
    end;
    SetLength(D.EntryNames, Info.ProcCount);
    SetLength(D.EntryAddrs, Info.ProcCount);
    for I := 0 to Info.ProcCount - 1 do
    begin
      D.EntryNames[I] := Info.ProcName(I);
      D.EntryAddrs[I] := M.Base + Info.Procs[I].Start;
    end;
  end
  else
  begin
    { without debug information its exports, by name }
    N := Length(M.ExpByName);
    SetLength(D.EntryNames, N);
    SetLength(D.EntryAddrs, N);
    for I := 0 to N - 1 do
    begin
      D.EntryNames[I] := ReadCStrRaw(M.Base + M.ExpByName[I], 256);
      if M.ExpOrd[I] < Length(M.ExpFuncs) then D.EntryAddrs[I] := M.Base + M.ExpFuncs[M.ExpOrd[I]];
    end;
  end;
  Result := True;
end;

procedure TDebugger.StepInstruction(Over: Boolean);
begin
  if Over then PostCommand(dcStepInstrOver) else PostCommand(dcStepInstr);
end;

procedure TDebugger.TraceToSource;
begin
  PostCommand(dcTraceSource);
end;

function TDebugger.ReadMemoryPaged(Addr: Cardinal; var Buf; Size: Integer; var Readable: array of Boolean): Integer;
var
  P: PByteArray;
  Ofs, N: Integer;
  Ok, Gap: Boolean;
begin
  Result := 0;
  P := @Buf;
  Ofs := 0;
  Gap := False;
  while Ofs < Size do
  begin
    N := $1000 - Integer((Addr + Cardinal(Ofs)) and $FFF);
    if N > Size - Ofs then N := Size - Ofs;
    Ok := ReadMemory(Addr + Cardinal(Ofs), P^[Ofs], N);
    if not Ok then FillChar(P^[Ofs], N, 0);
    FillChar(Readable[Ofs], N, Ord(Ok));
    if Ok and not Gap then Inc(Result, N) else Gap := True;
    Inc(Ofs, N);
  end;
end;

{ the readable bytes from Addr on are read again when fewer than an instruction's longest are left }
function TDebugger.DecodeAt(Addr: Cardinal; Count: Integer; out Instrs: TDbgInstrArray): Boolean;
var
  Buf: array[0..4095] of Byte;
  Readable: array[0..4095] of Boolean;
  Avail, Ofs, Len, N: Integer;
  S: string;
begin
  Instrs := nil;
  N := 0;
  Avail := 0;
  Ofs := 0;
  try
    while N < Count do
    begin
      if Avail - Ofs < 16 then
      begin
        Addr := Addr + Cardinal(Ofs);
        Ofs := 0;
        Avail := ReadMemoryPaged(Addr, Buf, SizeOf(Buf), Readable);
        if Avail = 0 then Break;
      end;
      Len := DisasmInstr(@Buf[Ofs], Avail - Ofs, Addr + Cardinal(Ofs), S);
      if Len <= 0 then Break;
      if N >= Length(Instrs) then SetLength(Instrs, N * 2 + 16);
      Instrs[N].Addr := Addr + Cardinal(Ofs);
      Instrs[N].Len := Len;
      if Len <= SizeOf(Instrs[N].Bytes) then
        Move(Buf[Ofs], Instrs[N].Bytes, Len)
      else
        Move(Buf[Ofs], Instrs[N].Bytes, SizeOf(Instrs[N].Bytes));
      Instrs[N].Text := S;
      Inc(N);
      Inc(Ofs, Len);
    end;
  except
    // what was decoded stays
  end;
  SetLength(Instrs, N);
  Result := N > 0;
end;

function TDebugger.DecodeStart(Addr: Cardinal; Before: Integer): Cardinal;
var
  Buf: array of Byte;
  Readable: array of Boolean;
  Lo: Cardinal;
  Try_, P, Avail: Integer;
  Info: TInstrInfo;
begin
  Result := Addr;
  if Before <= 0 then Exit;
  Lo := Addr - Cardinal(Before);
  { the instructions that begin before Addr, the last of them up to 15 bytes beyond it }
  SetLength(Buf, Before + 16);
  SetLength(Readable, Length(Buf));
  Avail := ReadMemoryPaged(Lo, Buf[0], Length(Buf), Readable);
  for Try_ := 0 to 15 do
  begin
    P := Try_;
    while (P < Before) and (P < Avail) and DecodeInstr(@Buf[P], Avail - P, Lo + Cardinal(P), Info) do
      Inc(P, Info.Len);
    if P = Before then
    begin
      Result := Lo + Cardinal(Try_);
      Exit;
    end;
  end;
end;

function TDebugger.Disassemble(Addr: Cardinal; Count: Integer; Lines: TStrings): Boolean;
var
  Instrs: TDbgInstrArray;
  I: Integer;
begin
  Result := False;
  if (Lines = nil) or (FProcessHandle = 0) or (Count <= 0) then Exit;
  Result := DecodeAt(Addr, Count, Instrs);
  for I := 0 to High(Instrs) do Lines.Add(Format('%.8X  %s', [Instrs[I].Addr, Instrs[I].Text]));
end;

end.
