{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestDebug;

{ The self-test's debugger area (OtaDemoTest): IOTADebuggerServices on the test project's program
  (OtaDemoTestIde: run-time packages, its form never shown). The program is built with TD32 debug
  information here: CreateProcess runs a program file, and the debugger takes the information from
  it. The IDE's own rtl70 and vcl70 are copied beside it first (CopyIdePackages).

  * Breakpoints: a source breakpoint on the loop's line (MARK-LOOP) with a pass count of 2, one on
    MARK-END whose notifier stops the program whatever its pass count says, address breakpoints on
    code and on data - the kinds an expert tells apart with Supports, Delphi 7's pass count (the
    passes since the last stop), Edit taken over by a notifier.
  * The stop: the process, its threads and modules (units, files, entry points), the thread's place,
    call stack, Evaluate (with a format specifier; address, size, whether it can be modified),
    Modify, memory read through the process.
  * A notifier's Trigger: asked at every hit before anything else, the program standing (the
    thread can be evaluated then); trContinue lets the program run on, trStop stops it.
  * The thread's notifiers: once per change of the state, as Delphi 7 tells them - a run, a step,
    a pause. The end: the process, its threads and modules destroyed, and their objects answer
    empty. }

interface

implementation

uses
  Windows, SysUtils, Classes, Variants, Forms, ToolsAPI, OtaDemoTest;

type
  { the process's notifier. Of the modules only the program's own is kept, and only while it is
    there: Delphi 7 raises "dangling reference" when a module goes that an expert still holds }
  TProcessCounter = class(TNotifierObject, IOTANotifier, IOTAProcessNotifier)
  public
    ThreadsCreated, ThreadsDestroyed, ModulesCreated, ModulesDestroyed: Integer;
    ExeName: string;                  // the program's file
    ExeModule: IOTAProcessModule;     // its module, while it is there
    procedure ThreadCreated(Thread: IOTAThread);
    procedure ThreadDestroyed(Thread: IOTAThread);
    procedure ProcessModuleCreated(ProcessModule: IOTAProcessModule);
    procedure ProcessModuleDestroyed(ProcessModule: IOTAProcessModule);
  end;

  TDebuggerCounter = class(TNotifierObject, IOTANotifier, IOTADebuggerNotifier)
  public
    Made, Ended, Added, Deleted: Integer;
    ProcessNotifier: IOTAProcessNotifier;     // registered with each process made
    procedure ProcessCreated(Process: IOTAProcess);
    procedure ProcessDestroyed(Process: IOTAProcess);
    procedure BreakpointAdded(Breakpoint: IOTABreakpoint);
    procedure BreakpointDeleted(Breakpoint: IOTABreakpoint);
  end;

  TThreadCounter = class(TNotifierObject, IOTANotifier, IOTAThreadNotifier)
  public
    Reasons: array[TOTANotifyReason] of Integer;
    procedure ThreadNotify(Reason: TOTANotifyReason);
    procedure EvaluteComplete(const ExprStr, ResultStr: string; CanModify: Boolean;
      ResultAddress, ResultSize: LongWord; ReturnCode: Integer);
    procedure ModifyComplete(const ExprStr, ResultStr: string; ReturnCode: Integer);
  end;

  { a breakpoint's notifier: Trigger evaluates Expr in the thread that hit the breakpoint and
    answers Answer; Edit answers EditAnswer }
  TBreakpointCounter = class(TNotifierObject, IOTANotifier, IOTABreakpointNotifier)
  public
    Triggers, Edits, Verifies: Integer;
    Answer: TOTATriggerResult;
    EditAnswer, KeyChanges: Boolean;
    Expr: string;
    Values: TStringList;          // Expr's value at each trigger
    constructor Create(const AExpr: string);
    destructor Destroy; override;
    function Edit(AllowKeyChanges: Boolean): Boolean;
    function Trigger: TOTATriggerResult;
    procedure Verified(Enabled, Valid: Boolean);
  end;

  TDebugTests = class(TOtaTestArea)
  private
    FDebugger: TDebuggerCounter;
    FDebuggerIntf: IOTADebuggerNotifier;
    FDebuggerIndex: Integer;
    FProcesses: TProcessCounter;
    FThreads: TThreadCounter;
    FThreadsIntf: IOTAThreadNotifier;
    FThreadsIndex: Integer;
    FThread: IOTAThread;              // the thread that stopped, with FThreads
    FLoop, FEnd: IOTABreakpoint;
    FLoopCounter, FEndCounter: TBreakpointCounter;
    FLoopNotifier, FEndNotifier: IOTABreakpointNotifier;
    FLoopIndex, FEndIndex: Integer;
    FLoopLine, FEndLine: Integer;
    FBkptsBefore: Integer;
    FStops: Integer;                  // the thread's nrStopped before the last command
    FOldProcess: IOTAProcess;
    FOldThread: IOTAThread;
    FEnding: Boolean;                 // Terminate ended the program
    function Debugger: IOTADebuggerServices;
    function Process: IOTAProcess;
    function Stopped: Boolean;
    function StoppedAgain: Boolean;
    function RunsOn: Boolean;
    function Ended: Boolean;
    function ExeModule: IOTAProcessModule;
    procedure Command(Mode: TOTARunMode);
    procedure Build;
    procedure ToggleAt(Line: Integer);
    function SourceBkptAt(Line: Integer): IOTABreakpoint;
    function HasSourceBkptAt(Line: Integer): Boolean;
    function NewSourceBkpt(Line: Integer): IOTABreakpoint;
    procedure DropBkpt(var B: IOTABreakpoint; Line: Integer);
    procedure Breakpoints;
    function AtMain: Boolean;
    procedure Run;
    procedure FromMain;
    procedure Stop;
    procedure AddressBreakpoints;
    procedure RunOn;
    procedure AtEnd;
    procedure StepOver;
    procedure Stepped;
    procedure Resume;
    procedure Pause;
    procedure Paused;
    procedure ReleaseThread;
    procedure Terminate;
    procedure AfterEnd;
    procedure EditBreakpoint;
    procedure Remove;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

{ Expr in thread T, with the evaluator's format specifier Fmt: the result, the text in Value }
function EvalIn(const T: IOTAThread; const Expr: string; out Value: string; out Addr, Size, Val: LongWord;
  out CanModify: Boolean; const Fmt: string = ''): TOTAEvaluateResult;
var
  Buf: array[0..1023] of Char;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  Result := T.Evaluate(Expr, Buf, SizeOf(Buf), CanModify, False, PChar(Fmt), Addr, Size, Val);
  Value := Buf;
end;

{ ---------------------------------------------------------------- notifiers }

procedure TProcessCounter.ThreadCreated(Thread: IOTAThread);
begin
  Inc(ThreadsCreated);
end;

procedure TProcessCounter.ThreadDestroyed(Thread: IOTAThread);
begin
  Inc(ThreadsDestroyed);
end;

procedure TProcessCounter.ProcessModuleCreated(ProcessModule: IOTAProcessModule);
begin
  Inc(ModulesCreated);
  if SameText(ExtractFileName(ProcessModule.GetModuleFileName), ExtractFileName(ExeName)) then
    ExeModule := ProcessModule;
end;

procedure TProcessCounter.ProcessModuleDestroyed(ProcessModule: IOTAProcessModule);
begin
  Inc(ModulesDestroyed);
  if SameModule(ExeModule, ProcessModule) then ExeModule := nil;
end;

procedure TDebuggerCounter.ProcessCreated(Process: IOTAProcess);
begin
  Inc(Made);
  if ProcessNotifier <> nil then Process.AddNotifier(ProcessNotifier);
end;

procedure TDebuggerCounter.ProcessDestroyed(Process: IOTAProcess);
begin
  Inc(Ended);
end;

procedure TDebuggerCounter.BreakpointAdded(Breakpoint: IOTABreakpoint);
begin
  Inc(Added);
end;

procedure TDebuggerCounter.BreakpointDeleted(Breakpoint: IOTABreakpoint);
begin
  Inc(Deleted);
end;

procedure TThreadCounter.ThreadNotify(Reason: TOTANotifyReason);
begin
  Inc(Reasons[Reason]);
end;

procedure TThreadCounter.EvaluteComplete(const ExprStr, ResultStr: string; CanModify: Boolean;
  ResultAddress, ResultSize: LongWord; ReturnCode: Integer);
begin
end;

procedure TThreadCounter.ModifyComplete(const ExprStr, ResultStr: string; ReturnCode: Integer);
begin
end;

constructor TBreakpointCounter.Create(const AExpr: string);
begin
  inherited Create;
  Expr := AExpr;
  Answer := trDefault;
  Values := TStringList.Create;
end;

destructor TBreakpointCounter.Destroy;
begin
  Values.Free;
  inherited;
end;

function TBreakpointCounter.Edit(AllowKeyChanges: Boolean): Boolean;
begin
  Inc(Edits);
  KeyChanges := AllowKeyChanges;
  Result := EditAnswer;
end;

function TBreakpointCounter.Trigger: TOTATriggerResult;
var
  P: IOTAProcess;
  T: IOTAThread;
  S: string;
  A, Sz, V: LongWord;
  CM: Boolean;
begin
  Inc(Triggers);
  S := '(no thread)';
  P := (BorlandIDEServices as IOTADebuggerServices).CurrentProcess;
  if P <> nil then T := P.CurrentThread;
  if (T <> nil) and (EvalIn(T, Expr, S, A, Sz, V, CM) <> erOK) then S := 'error: ' + S;
  Values.Add(S);
  Result := Answer;
end;

procedure TBreakpointCounter.Verified(Enabled, Valid: Boolean);
begin
  Inc(Verifies);
end;

{ ---------------------------------------------------------------- the area }

function TDebugTests.Name: string;
begin
  Result := 'Debugger';
end;

procedure TDebugTests.AddSteps;
begin
  Step('Build', Build);
  Step('Breakpoints', Breakpoints);
  Step('Run', Run);
  Step('FromMain', FromMain);
  Step('Stop', Stop);
  Step('AddressBreakpoints', AddressBreakpoints);
  Step('RunOn', RunOn);
  Step('AtEnd', AtEnd);
  Step('StepOver', StepOver);
  Step('Stepped', Stepped);
  Step('Resume', Resume);
  Step('Pause', Pause);
  Step('Paused', Paused);
  Step('Terminate', Terminate);
  Step('AfterEnd', AfterEnd);
  Step('Edit', EditBreakpoint);
  Step('Remove', Remove);
end;

function TDebugTests.Debugger: IOTADebuggerServices;
begin
  Result := BorlandIDEServices as IOTADebuggerServices;
end;

function TDebugTests.Process: IOTAProcess;
begin
  Result := Debugger.CurrentProcess;
end;

{ the program stands at the first stop: the second pass of MARK-LOOP }
function TDebugTests.Stopped: Boolean;
var
  T: IOTAThread;
begin
  Result := False;
  if (Process = nil) or (FLoopCounter.Triggers < 2) then Exit;
  T := Process.CurrentThread;
  Result := (T <> nil) and (T.GetState = tsStopped);
end;

{ the thread was told one more stop than before the last command }
function TDebugTests.StoppedAgain: Boolean;
begin
  Result := FThreads.Reasons[nrStopped] + FThreads.Reasons[nrException] > FStops;
end;

function TDebugTests.RunsOn: Boolean;
begin
  Result := (FThreads.Reasons[nrRunning] >= 3) and (FThread.GetState = tsRunnable);
end;

function TDebugTests.Ended: Boolean;
begin
  Result := FDebugger.Ended > 0;
end;

{ the program's own module, as the process notifier was told of it }
function TDebugTests.ExeModule: IOTAProcessModule;
begin
  Result := FProcesses.ExeModule;
end;

procedure TDebugTests.Command(Mode: TOTARunMode);
begin
  FStops := FThreads.Reasons[nrStopped] + FThreads.Reasons[nrException];
  Process.Run(Mode);
end;

procedure TDebugTests.Build;
var
  P: IOTAProject;
  O: IOTAProjectOptions;
begin
  P := GetActiveProject;
  if not Check(P <> nil, 'the test project is the active one') then Exit;
  O := P.ProjectOptions;
  O.Values['DebugInfo'] := True;
  Check(O.Values['DebugInfo'] = True, 'DebugInfo (TD32 debug information in the program) reads back True');
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved before the build');
  Check(P.ProjectBuilder.BuildProject(cmOTABuild, True, True), 'BuildProject(cmOTABuild)');
  Check(FileExists(Test.Values['Exe']), 'the program was made', Test.Values['Exe']);
end;

{ the editor's F5 (Toggle Breakpoint) on Line of TestUnit, as the keyboard gives it }
procedure TDebugTests.ToggleAt(Line: Integer);
var
  E: IOTASourceEditor;
  P: TOTAEditPos;
begin
  E := SourceEditorOf((BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit']));
  if (E = nil) or (E.EditViewCount = 0) then Exit;
  E.Show;
  Application.ProcessMessages;
  P.Col := 1;
  P.Line := Line;
  E.EditViews[0].CursorPos := P;
  PostKey(EditorControlOf(Test.Values['Unit']), VK_F5, []);
end;

{ the source breakpoint on Line of TestUnit; nil: none }
function TDebugTests.SourceBkptAt(Line: Integer): IOTABreakpoint;
var
  I: Integer;
  B: IOTASourceBreakpoint;
begin
  Result := nil;
  for I := 0 to Debugger.GetSourceBkptCount - 1 do
  begin
    B := Debugger.SourceBkpts[I];
    if SameText(B.FileName, Test.Values['Unit']) and (B.LineNumber = Line) then Result := B;
  end;
end;

function TDebugTests.HasSourceBkptAt(Line: Integer): Boolean;
begin
  Result := SourceBkptAt(Line) <> nil;
end;

{ a source breakpoint on Line: NewSourceBreakpoint - Delphi 7's raises EListError while no process
  runs, so there the editor's F5 sets it }
function TDebugTests.NewSourceBkpt(Line: Integer): IOTABreakpoint;
var
  Raised: Boolean;
begin
  if not IdeIsDelphi7 then
  begin
    Result := Debugger.NewSourceBreakpoint(Test.Values['Unit'], Line, nil);
    Exit;
  end;
  Raised := False;
  try
    Debugger.NewSourceBreakpoint(Test.Values['Unit'], Line, nil);
  except
    on EListError do Raised := True;
  end;
  Check(Raised, 'NewSourceBreakpoint while no process runs raises EListError (Delphi 7''s)');
  ToggleAt(Line);
  Result := SourceBkptAt(Line);
end;

{ a breakpoint taken out: Destruct - Delphi 7's raises "dangling reference count" while the expert
  holds the breakpoint and leaves it: there a source breakpoint goes by the editor's F5
  (Line), an address breakpoint is disabled }
procedure TDebugTests.DropBkpt(var B: IOTABreakpoint; Line: Integer);
begin
  if B = nil then Exit;
  if not IdeIsDelphi7 then
  begin
    B.Destruct;
    B := nil;
    Exit;
  end;
  if Line > 0 then
  begin
    B := nil;
    if HasSourceBkptAt(Line) then ToggleAt(Line);
  end
  else
  begin
    B.Enabled := False;
    B := nil;
  end;
end;
procedure TDebugTests.Breakpoints;
var
  M: IOTAModule;
  Text: string;
  SB: IOTASourceBreakpoint;
  AB: IOTAAddressBreakpoint;
begin
  FDebugger := TDebuggerCounter.Create;
  FProcesses := TProcessCounter.Create;
  FProcesses.ExeName := Test.Values['Exe'];
  FDebugger.ProcessNotifier := FProcesses;
  FDebuggerIntf := FDebugger;
  FDebuggerIndex := Debugger.AddNotifier(FDebuggerIntf);
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit']);
  if not Check(M <> nil, 'TestUnit is open') then Exit;
  Text := EditorText(SourceEditorOf(M));
  FLoopLine := LineWith(Text, 'MARK-LOOP');
  FEndLine := LineWith(Text, 'MARK-END');
  if not Check((FLoopLine > 0) and (FEndLine > FLoopLine), 'the markers are found') then Exit;
  FBkptsBefore := Debugger.GetSourceBkptCount;
  FLoop := NewSourceBkpt(FLoopLine);
  if not Check(FLoop <> nil, 'NewSourceBreakpoint on MARK-LOOP') then Exit;
  ExpectInt('BreakpointAdded', FDebugger.Added, 1);
  ExpectInt('GetSourceBkptCount', Debugger.GetSourceBkptCount, FBkptsBefore + 1);
  Check(Supports(FLoop, IOTASourceBreakpoint, SB), 'a source breakpoint is an IOTASourceBreakpoint');
  Check(not Supports(FLoop, IOTAAddressBreakpoint, AB), '... and no IOTAAddressBreakpoint');
  Check(SameText(FLoop.GetFileName, Test.Values['Unit']), 'its FileName', FLoop.GetFileName);
  ExpectInt('its LineNumber', FLoop.GetLineNumber, FLoopLine);
  FLoop.SetPassCount(2);
  ExpectInt('PassCount', FLoop.GetPassCount, 2);
  ExpectInt('CurPassCount before a hit', FLoop.GetCurPassCount, 0);
  FLoopCounter := TBreakpointCounter.Create('FCounter');
  FLoopNotifier := FLoopCounter;
  FLoopIndex := FLoop.AddNotifier(FLoopNotifier);
  FEnd := NewSourceBkpt(FEndLine);
  if not Check(FEnd <> nil, 'NewSourceBreakpoint on MARK-END') then Exit;
  { by itself it would not stop at the one pass the program makes }
  FEnd.SetPassCount(5);
  FEndCounter := TBreakpointCounter.Create('FCounter');
  FEndCounter.Answer := trStop;
  FEndNotifier := FEndCounter;
  FEndIndex := FEnd.AddNotifier(FEndNotifier);
  ExpectInt('BreakpointAdded for both', FDebugger.Added, 2);
end;

{ the IDE's own run-time packages beside the program, which is built with them (OtaDemoTestIde: rtl;
  vcl): Windows looks for them in the program's folder first, then in the system folder - where an
  installed Delphi 7 put Borland's originals, which lack the modernized RTL's exports (Utf8Mode, of a
  program built for UTF-8): the program would not start there (C0000139) }
procedure CopyIdePackages(const ExeFile: string);
const
  Names: array[0..1] of string = ('rtl70.bpl', 'vcl70.bpl');
var
  I: Integer;
  M: HMODULE;
  Buf: array[0..MAX_PATH] of Char;
begin
  for I := 0 to High(Names) do
  begin
    M := GetModuleHandle(PChar(Names[I]));
    if (M <> 0) and (GetModuleFileName(M, Buf, SizeOf(Buf)) > 0) then
      CopyFile(Buf, PChar(ExtractFilePath(ExeFile) + Names[I]), False);
  end;
end;

{ CreateProcess loads the program and stops at its main block's begin (Delphi 7's, measured) }
function TDebugTests.AtMain: Boolean;
var
  T: IOTAThread;
begin
  Result := False;
  if Process = nil then Exit;
  T := Process.CurrentThread;
  Result := (T <> nil) and (T.GetState = tsStopped);
end;

procedure TDebugTests.Run;
begin
  if FLoopCounter = nil then Exit;
  CopyIdePackages(Test.Values['Exe']);
  Debugger.CreateProcess(Test.Values['Exe'], '', '');
  WaitFor(AtMain, 'CreateProcess: the program stops at its main block', 90);
end;

{ the program stands at the project's begin; Run takes it on to the breakpoints }
procedure TDebugTests.FromMain;
var
  T: IOTAThread;
  M: IOTAModule;
begin
  if (FLoopCounter = nil) or (Process = nil) then Exit;
  T := Process.CurrentThread;
  if Check(T <> nil, 'the program''s thread') then
  begin
    Check(SameText(T.GetCurrentFile, Test.Values['Project']), 'it stands in the project''s source', T.GetCurrentFile);
    M := (BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Project']);
    if M <> nil then
      ExpectInt('... at its main block''s begin', T.GetCurrentLine, LineWith(EditorText(SourceEditorOf(M)), 'begin'));
  end;
  T := nil;
  ExpectInt('no breakpoint was hit on the way', FLoopCounter.Triggers, 0);
  Process.Run(ormRun);
  WaitFor(Stopped, 'the program stops at MARK-LOOP, its second pass', 90);
end;

procedure TDebugTests.Stop;
var
  P: IOTAProcess;
  S, Hdr, F: string;
  A, Sz, V, N: LongWord;
  CM: Boolean;
  R: Integer;
  Line: Integer;
begin
  P := Process;
  if not Check(P <> nil, 'CurrentProcess') then Exit;
  ExpectInt('ProcessCreated', FDebugger.Made, 1);
  ExpectInt('GetProcessCount', Debugger.GetProcessCount, 1);
  Check(P.GetProcessId <> 0, 'its ProcessId');
  Check(P.GetThreadCount >= 1, 'its threads', IntToStr(P.GetThreadCount));
  Check(FProcesses.ThreadsCreated >= 1, 'ThreadCreated for them', IntToStr(FProcesses.ThreadsCreated));
  Check(FProcesses.ModulesCreated >= 3, 'ProcessModuleCreated for the program and its packages',
    IntToStr(FProcesses.ModulesCreated));
  ExpectInt('Verified is not told (Delphi 7''s)', FLoopCounter.Verifies, 0);
  { the breakpoint's trigger at both passes, the program standing }
  ExpectInt('Trigger at each hit', FLoopCounter.Triggers, 2);
  if FLoopCounter.Values.Count = 2 then
  begin
    Expect('FCounter evaluated in Trigger, first pass', FLoopCounter.Values[0], '0');
    Expect('FCounter evaluated in Trigger, second pass', FLoopCounter.Values[1], '2');
  end;
  ExpectInt('CurPassCount at the stop: the passes since the last one', FLoop.GetCurPassCount, 2);
  { the thread }
  FThread := P.CurrentThread;
  if not Check(FThread <> nil, 'CurrentThread') then Exit;
  Check(FThread.GetState = tsStopped, 'its State: tsStopped');
  Check(SameText(FThread.GetCurrentFile, Test.Values['Unit']), 'its CurrentFile', FThread.GetCurrentFile);
  ExpectInt('its CurrentLine', FThread.GetCurrentLine, FLoopLine);
  Check(FThread.GetCallCount >= 2, 'its call stack', IntToStr(FThread.GetCallCount));
  Hdr := FThread.GetCallHeader(1);
  Check(Pos('FormCreate', Hdr) > 0, 'GetCallHeader(1): FormCreate', Hdr);
  FThread.GetCallPos(1, F, Line);
  Check(SameText(F, Test.Values['Unit']) and (Line = FLoopLine), 'GetCallPos(1): MARK-LOOP',
    Format('%s, %d', [F, Line]));
  Check(FThread.GetHandle <> 0, 'its Handle');
  { evaluate and modify }
  Check(EvalIn(FThread, 'FCounter', S, A, Sz, V, CM) = erOK, 'Evaluate(FCounter)', S);
  Expect('its value', S, '2');
  ExpectInt('ResultVal: 0 (Delphi 7''s)', V, 0);
  ExpectInt('ResultSize', Sz, 4);
  Check(A <> 0, 'ResultAddr: the field''s address');
  Check(CM, 'CanModify: a field');
  N := 0;
  ExpectInt('ReadProcessMemory at ResultAddr', P.ReadProcessMemory(A, 4, N), 4);
  ExpectInt('... reads the value', N, 2);
  Check(EvalIn(FThread, 'FCounter', S, A, Sz, V, CM, 'h') = erOK, 'Evaluate(FCounter) with the format "h"', S);
  Check((S <> '') and (S[1] = '$') and (StrToIntDef(S, -1) = 2), 'its value in hexadecimal', S);
  Check(EvalIn(FThread, 'FCounter + 1', S, A, Sz, V, CM) = erOK, 'Evaluate(FCounter + 1)', S);
  Check(not CM, 'CanModify: an expression is no variable');
  Check(EvalIn(FThread, 'FCounter', S, A, Sz, V, CM) = erOK, 'Evaluate(FCounter) before Modify', S);
  Check(FThread.Modify('10', PChar(StringOfChar(#0, 256)), 256, R) = erOK, 'Modify(10)');
  ExpectInt('Modify''s ResultVal: 0 (Delphi 7''s)', R, 0);
  Check(EvalIn(FThread, 'FCounter', S, A, Sz, V, CM) = erOK, 'Evaluate(FCounter) after Modify', S);
  Expect('the new value', S, '10');
  { the pass count: Delphi 7's DecPassCount and ResetPassCount }
  Check(not FLoop.DecPassCount, 'DecPassCount: a pass left - False');
  ExpectInt('CurPassCount after DecPassCount', FLoop.GetCurPassCount, 1);
  FLoop.ResetPassCount;
  ExpectInt('CurPassCount after ResetPassCount', FLoop.GetCurPassCount, 0);
  { from here on the thread's notifiers are counted }
  FThreads := TThreadCounter.Create;
  FThreadsIntf := FThreads;
  FThreadsIndex := FThread.AddNotifier(FThreadsIntf);
end;

procedure TDebugTests.AddressBreakpoints;
var
  M: IOTAProcessModule;
  I, Units: Integer;
  Found: Boolean;
  Twice, A, Sz, V: LongWord;
  TwiceLine: Integer;
  Raised: Boolean;
  S, Names: string;
  CM: Boolean;
  B: IOTABreakpoint;
  AB: IOTAAddressBreakpoint;
  SB: IOTASourceBreakpoint;
begin
  if FThread = nil then Exit;
  { the program's module: its units, files and routines }
  M := ExeModule;
  if not Check(M <> nil, 'the program''s module was announced') then Exit;
  Check(M.GetBaseAddress <> 0, 'its BaseAddress');
  Check((M.GetEntryPoint > M.GetBaseAddress) and (M.GetEntryPoint - M.GetBaseAddress < $1000000),
    'its EntryPoint lies in it', Format('$%.8x', [M.GetEntryPoint]));
  Units := M.GetCompUnitCount;
  Found := False;
  Names := '';
  for I := 0 to Units - 1 do
  begin
    if Names <> '' then Names := Names + ' ';
    Names := Names + M.GetCompUnit(I);
    if SameText(ChangeFileExt(M.GetCompUnit(I), ''), 'TestUnit') then
      Found := (M.GetCompUnitFileCount(I) >= 1) and
        SameText(ExtractFileName(M.GetCompUnitFileName(I, 0)), 'TestUnit.pas');
  end;
  Check(Found, 'its compilation units: TestUnit with TestUnit.pas', Names);
  Check(M.GetFileCount >= 2, 'its source files', IntToStr(M.GetFileCount));
  Twice := 0;
  for I := 0 to M.GetModuleEntryPointCount - 1 do
    if SameText(Copy(M.GetModuleEntryPoint(I), Length(M.GetModuleEntryPoint(I)) - 5, 6), '.Twice') then
      Twice := M.GetModuleEntryPointAddress(I);
  if not Check(Twice <> 0, 'its entry points: TTestForm.Twice') then Exit;
  { a code breakpoint on Twice. Delphi 7's NewAddressBreakpoint on the code of a source line makes a
    source breakpoint on that line instead and raises EAbort (measured): there it is taken
    away by the editor's F5 }
  if IdeIsDelphi7 then
  begin
    Raised := False;
    try
      Debugger.NewAddressBreakpoint(Twice, 0, atExecute, Process);
    except
      on EAbort do Raised := True;
    end;
    Check(Raised, 'NewAddressBreakpoint on the code of a line raises EAbort (Delphi 7''s)');
    TwiceLine := LineWith(EditorText(SourceEditorOf((BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit']))),
      'MARK-TWICE');
    Check(HasSourceBkptAt(TwiceLine), '... and makes a source breakpoint on the line (MARK-TWICE)');
    if HasSourceBkptAt(TwiceLine) then ToggleAt(TwiceLine);
    Check(not HasSourceBkptAt(TwiceLine), '... which F5 takes away');
  end
  else
  begin
    B := Debugger.NewAddressBreakpoint(Twice, 0, atExecute, Process);
    if Check(Supports(B, IOTAAddressBreakpoint, AB), 'an address breakpoint is an IOTAAddressBreakpoint') then
    begin
      Check(not Supports(B, IOTASourceBreakpoint, SB), '... and no IOTASourceBreakpoint');
      ExpectInt('its Address', AB.Address, Twice);
      Check(AB.GetAccessType = atExecute, 'its AccessType: atExecute');
      Check(AB.GetLineSize > 0, 'LineSize: the code of its line', IntToStr(AB.GetLineSize));
      Check((AB.GetLineOffset >= 0) and (AB.GetLineOffset < AB.GetLineSize), 'LineOffset: inside the line',
        IntToStr(AB.GetLineOffset));
      Check(SameText(ChangeFileExt(AB.GetModuleName, ''), 'OtaSelfTest'), 'ModuleName: the program', AB.GetModuleName);
    end;
    AB := nil;
    DropBkpt(B, 0);
  end;  { a data breakpoint on FCounter's reads }
  if not Check(EvalIn(FThread, 'FCounter', S, A, Sz, V, CM) = erOK, 'Evaluate(FCounter) for its address', S) then Exit;
  B := Debugger.NewAddressBreakpoint(A, 4, atRead, Process);
  if Check(Supports(B, IOTAAddressBreakpoint, AB), 'a data breakpoint is an IOTAAddressBreakpoint') then
    Check(AB.GetAccessType = atRead, 'its AccessType: atRead');
  AB := nil;
  DropBkpt(B, 0);
  { Delphi 7: the source breakpoint F5 took away; the data breakpoint disabled (DropBkpt) }
  ExpectInt('BreakpointDeleted for both', FDebugger.Deleted, IdeValue(1, 2));
end;

{ the loop's breakpoint lets the program go on (trContinue), MARK-END's stops it (trStop) }
procedure TDebugTests.RunOn;
begin
  if FThreads = nil then Exit;
  FLoopCounter.Answer := trContinue;
  Command(ormRun);
  WaitFor(StoppedAgain, 'the program stops at MARK-END (its notifier: trStop)', 60);
end;

procedure TDebugTests.AtEnd;
begin
  if FThreads = nil then Exit;
  ExpectInt('the loop''s Trigger at its third pass', FLoopCounter.Triggers, 3);
  if FLoopCounter.Values.Count = 3 then
    Expect('FCounter in that Trigger (10 + Twice(2))', FLoopCounter.Values[2], '14');
  ExpectInt('trContinue: no pass counted', FLoop.GetCurPassCount, 0);
  ExpectInt('MARK-END''s Trigger', FEndCounter.Triggers, 1);
  if FEndCounter.Values.Count = 1 then
    Expect('FCounter in that Trigger (14 + Twice(3))', FEndCounter.Values[0], '20');
  ExpectInt('trStop: no pass counted', FEnd.GetCurPassCount, 0);
  ExpectInt('the stop''s line', FThread.GetCurrentLine, FEndLine);
  ExpectInt('nrRunning once', FThreads.Reasons[nrRunning], 1);
  ExpectInt('nrStopped once', FThreads.Reasons[nrStopped], 1);
  ExpectInt('no other reason', FThreads.Reasons[nrOther] + FThreads.Reasons[nrException] +
    FThreads.Reasons[nrFault], 0);
end;

procedure TDebugTests.StepOver;
begin
  if FThreads = nil then Exit;
  Command(ormStmtStepOver);
  WaitFor(StoppedAgain, 'the step over MARK-END stops', 30);
end;

procedure TDebugTests.Stepped;
begin
  if FThreads = nil then Exit;
  ExpectInt('the step: nrRunning once more', FThreads.Reasons[nrRunning], 2);
  ExpectInt('the step: nrStopped once more', FThreads.Reasons[nrStopped], 2);
  ExpectInt('the line after MARK-END', FThread.GetCurrentLine, FEndLine + 1);
end;

procedure TDebugTests.Resume;
begin
  if FThreads = nil then Exit;
  Command(ormRun);
  WaitFor(RunsOn, 'the program runs on: nrRunning, tsRunnable', 30);
end;

procedure TDebugTests.Pause;
begin
  if FThreads = nil then Exit;
  FStops := FThreads.Reasons[nrStopped] + FThreads.Reasons[nrException];
  Process.Pause;
  WaitFor(StoppedAgain, 'Pause stops the program', 30);
end;

procedure TDebugTests.Paused;
begin
  if FThreads = nil then Exit;
  ExpectInt('nrRunning: three runs', FThreads.Reasons[nrRunning], 3);
  ExpectInt('nrStopped: three stops', FThreads.Reasons[nrStopped], 3);
  Check(Process.CurrentThread.GetState = tsStopped, 'the thread stands');
end;

{ D7 Studio's objects of an ended session answer empty, so the old ones are kept to be asked; Delphi
  7 raises "dangling reference" when a thread or process goes that an expert still holds: there the
  thread's notifier and the references go first }
procedure TDebugTests.Terminate;
var
  P: IOTAProcess;
begin
  P := Process;
  if P = nil then Exit;
  FEnding := True;
  if IdeIsDelphi7 then ReleaseThread
  else
  begin
    FOldProcess := P;
    FOldThread := FThread;
  end;
  P.Terminate;
  WaitFor(Ended, 'Terminate ends the process: ProcessDestroyed', 30);
end;

procedure TDebugTests.AfterEnd;
var
  S: string;
  A, Sz, V: LongWord;
  CM: Boolean;
begin
  if not FEnding then Exit;
  ExpectInt('ProcessDestroyed once', FDebugger.Ended, 1);
  ExpectInt('GetProcessCount', Debugger.GetProcessCount, 0);
  Check(Debugger.CurrentProcess = nil, 'no CurrentProcess');
  ExpectInt('ThreadDestroyed for every thread', FProcesses.ThreadsDestroyed, FProcesses.ThreadsCreated);
  ExpectInt('ProcessModuleDestroyed for every module', FProcesses.ModulesDestroyed, FProcesses.ModulesCreated);
  Check(FProcesses.ExeModule = nil, 'the program''s module is gone with its ProcessModuleDestroyed');
  if (FOldProcess <> nil) and
    D7StudioOnly('the objects of an ended session answer empty (Delphi 7''s may not be held then)') then
  begin
    ExpectInt('the ended process has no threads', FOldProcess.GetThreadCount, 0);
    if FOldThread <> nil then
    begin
      Check(FOldThread.GetState = tsNone, 'an ended thread''s State: tsNone');
      Check(EvalIn(FOldThread, 'FCounter', S, A, Sz, V, CM) = erError, 'an ended thread evaluates nothing', S);
    end;
  end;
  { the ended thread is FThread still (Terminate kept it as FOldThread too) }
  ReleaseThread;
end;
{ IOTABreakpoint.Edit: a notifier that answers True takes it over - no dialog }
procedure TDebugTests.EditBreakpoint;
begin
  if FLoop = nil then Exit;
  FLoopCounter.EditAnswer := True;
  FLoop.Edit(False);
  ExpectInt('the notifier''s Edit', FLoopCounter.Edits, 1);
  Check(not FLoopCounter.KeyChanges, 'AllowKeyChanges as given: False');
end;

procedure TDebugTests.Remove;
begin
  if FLoop = nil then Exit;
  FLoop.RemoveNotifier(FLoopIndex);
  FEnd.RemoveNotifier(FEndIndex);
  DropBkpt(FLoop, FLoopLine);
  DropBkpt(FEnd, FEndLine);
  ExpectInt('BreakpointDeleted for the source breakpoints', FDebugger.Deleted, IdeValue(3, 4));
  ExpectInt('GetSourceBkptCount as before', Debugger.GetSourceBkptCount, FBkptsBefore);
end;

{ the thread's notifier taken off and the thread and the ended session's objects let go - before the
  process ends (Delphi 7 raises "dangling reference" for a thread or process an expert still holds) }
procedure TDebugTests.ReleaseThread;
begin
  if (FThread <> nil) and (FThreadsIndex >= 0) then FThread.RemoveNotifier(FThreadsIndex);
  FThreadsIndex := -1;
  FThread := nil;
  FOldThread := nil;
  FOldProcess := nil;
end;

procedure TDebugTests.Cleanup;
var
  P: IOTAProject;
begin
  ReleaseThread;
  if Debugger.CurrentProcess <> nil then Debugger.CurrentProcess.Terminate;
  DropBkpt(FLoop, FLoopLine);
  DropBkpt(FEnd, FEndLine);
  if FDebuggerIntf <> nil then Debugger.RemoveNotifier(FDebuggerIndex);
  FLoop := nil;
  FEnd := nil;
  FDebuggerIntf := nil;
  P := GetActiveProject;
  if P <> nil then P.ProjectOptions.Values['DebugInfo'] := False;
end;

initialization
  RegisterTestArea(TDebugTests, 80);
end.
