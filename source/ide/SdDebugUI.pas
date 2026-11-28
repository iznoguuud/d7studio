{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDebugUI;

{ D7 Studio - debugger front end: owns the TDebugger engine and drives the docked debug views
  (call stack, local variables, watches, breakpoints, event log). The views are controls of
  the main form (SdMain.dfm). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, SdUI, SdDialogs, SdDbgEngine,
  SdDebuggerOptions, SdDebugViews, SdCpuView, SdDebugInspector, SdWatchViewFrame, SdSourceBPDlg, SdWatchEditDlg;

type
  TDebugLocationEvent = procedure(const FileName: string; Line: Integer) of object;
  { a breakpoint is to be edited (KeyChanges False: where it is stays): True - handled, the IDE
    shows no dialog }
  TEditBreakpointEvent = function(BP: TDbgBreakpoint; KeyChanges: Boolean): Boolean of object;

  { the expressions and values behind the rows of one tree (Node.Data = index + 1): Local
    Variables and the Watch List have one each, emptied when their tree is filled again (one list
    for both grew at every refresh of the watches during a stop) }
  TNodeTexts = class
  private
    FExprs, FValues: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(const Expr, Value: string): Pointer;   // the row's Data
    function Expr(Node: TTreeNode): string;
    function Value(Node: TTreeNode; out S: string): Boolean;
  end;

  TDebugController = class
  private
    FOwner: TForm;
    FDbg: TDebugger;
    FCallStack: TListBox;
    FLocals: TTreeView;
    FWatchView: TSdWatchView;       // the Watch List: its rows are FWatches
    FWatches: TTreeView;
    FBreaks: TListView;
    FLog: TListBox;
    FThreads, FModules: TListView;  // View | Debug Windows (SdDebugViews)
    FCpu: TSdCpuView;
    FFpu: TListBox;
    FInspector: TSdInspectorView;   // Run | Inspect
    FStopStatus: string;            // the Thread Status of the stopped thread: Breakpoint, Stepped ...
    { the watches in their groups (Delphi's WatchItemsList: the names, Objects the TList of each
      group's TWatchItem), the group shown }
    FGroups: TStringList;
    FGroup: Integer;
    FLocalTexts: TNodeTexts;        // the rows of Local Variables ...
    FWatchTexts: TNodeTexts;        // ... and of the Watch List (its second column)
    FLocated: TList;                // the watches whose address and size were read since the watches were filled
    FFillingWatches: Integer;       // the Watch List's rows are being made (its selection changes meanwhile)
    FWatchesList: TList;            // the group (its list) the Watch List's rows show (nil: none yet)
    { the views of the machine (Threads, Modules, CPU, FPU, Debug Inspector) a stop found hidden:
      filled when they are shown (MachineViewShown) }
    FMachineStale: array[0..4] of Boolean;
    FFrames: TDbgFrameArray;
    FExecFile: string;
    FExecLine: Integer;
    FUpdatingBreaks: Boolean;
    FOnLocation: TDebugLocationEvent;
    FOnStateChange: TNotifyEvent;
    FOnBreakpointsChanged: TNotifyEvent;
    FAddressFunc: TAddressFunc;
    FClearTimer: TTimer;            // the views empty only when the program keeps running (no blink at a step)
    FOnRunning: TNotifyEvent;
    FStopCount: Integer;
    FStopReason: TDbgStopReason;
    FOnEditBreakpoint: TEditBreakpointEvent;
    procedure DbgStateChange(Sender: TObject);
    procedure PrepareSession(SourceDirs: TStrings);
    procedure ClearTimerTick(Sender: TObject);
    procedure DbgStop(Sender: TObject; Reason: TDbgStopReason; const Frame: TDbgFrame; const Msg: string);
    procedure DbgLog(Sender: TObject; Kind: TDbgLogKind; const Text: string);
    procedure DbgExit(Sender: TObject; ExitCode: Cardinal);
    procedure ForgetWatchPlaces;
    procedure DbgBreakpointsChanged(Sender: TObject);
    procedure DbgError(Sender: TObject; E: Exception);
    procedure ThreadsDblClick(Sender: TObject);
    procedure TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
    procedure BreaksChange(Sender: TObject; Item: TListItem; Change: TItemChange);
    procedure BreaksKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure WatchesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure WatchesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure WatchesChange(Sender: TObject; Node: TTreeNode);
    procedure WatchCell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
    procedure WatchGroupChange(Sender: TObject);
    function GroupList(Index: Integer): TList;
    function GroupOf(const Name: string): Integer;      // the group's index; a new group when there is none
    procedure FreeWatches;                               // no watch, no group
    procedure ClearWatchGroups;                          // no watch, the group Watches alone
    procedure ShowGroups;                                // the tabs of the groups, the one shown
    function WatchOfNode(N: TTreeNode): TWatchItem;      // the watch of a row (or of a row inside it)
    procedure SelectedWatchNodes(L: TList);              // the selected watches' rows, each once
    procedure SelectedWatches(L: TList);                 // ... their watches, in the group's order
    procedure FillWatchNode(N: TTreeNode; W: TWatchItem);
    procedure SetWatchEnabled(N: TTreeNode; Value: Boolean);
    procedure LocateWatch(W: TWatchItem);
    function TextsOf(Tree: TObject): TNodeTexts;
    function WatchEvalText(W: TWatchItem): string;
    function DataWatch(const Expr: string): TDbgBreakpoint;
    function RemoveDataWatches(const Expr: string): Boolean;
    procedure AddVarNode(Tree: TTreeView; Parent: TTreeNode; const V: TDbgVar);
    procedure FillLocals;
    procedure RefreshViews;
    function MachineView(I: Integer): TWinControl;
    procedure RefreshMachine(I: Integer);
    procedure FillBreaks;
    function HasBreakpointAt(Settings: TDbgBreakpoint): Boolean;
    procedure ReadBreakpoints(Ini: TStrings);
    procedure WatchesBreakpointsChanged;
    function BreakpointDialog(BP: TDbgBreakpoint; const ACaption: string; KeyChanges: Boolean = True): Boolean;
    procedure EvalModified(Sender: TObject);
    procedure AddLogKind(const S: string; Kind: TEventKind);
    procedure LogDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  public
    constructor Create(AOwner: TForm);
    destructor Destroy; override;
    { the views are controls of the main form: the controller fills them and handles their
      events (the commands of the watch view's menu are actions of the main form) }
    procedure AttachViews(ACallStack: TListBox; ALocals: TTreeView; AWatches: TSdWatchView; ABreaks: TListView;
      ALog: TListBox);
    procedure ClearViews;               // the call stack and the local variables empty, the watches without values
    { Thread Status, Modules, CPU, FPU: filled at every stop; a double click on a thread makes
      it the one inspected }
    procedure AttachMachineViews(AThreads, AModules: TListView; ACpu: TSdCpuView; AFpu: TListBox;
      AInspector: TSdInspectorView);
    procedure StepInstruction(Over: Boolean);   // the CPU view's F7 / F8
    procedure TraceToSource;                    // Run | Trace to Next Source Line
    { the thread inspected from now on, its place shown (a double click in Thread Status) }
    function ShowThread(ThreadId: Cardinal): Boolean;
    { session }
    { Env: the program's environment block ('' = the IDE's; Run | Parameters | Environment Block) }
    function Run(const Exe, Params, WorkDir: string; SourceDirs: TStrings; StopAtEntry: Boolean;
      const Env: string = ''): Boolean;
    { Run | Attach to Process: a session with the running process Pid; Detach From Program ends
      a session and lets the program run on }
    function Attach(Pid: Cardinal; SourceDirs: TStrings): Boolean;
    procedure Detach;
    { not "Continue": inside this class that name would hide System.Continue in every loop }
    procedure Resume;
    procedure Pause;
    procedure Stop;
    procedure StepOver;
    procedure StepInto;
    procedure StepOut;
    procedure RunToLine(const FileName: string; Line: Integer);
    function Active: Boolean;
    function Paused: Boolean;
    { What the IDE shows (No flicker): the last stop stays on the screen for the first
      quarter second of a run - a step is over by then, and nothing blinks (views, tool buttons,
      caption, status bar, the execution point). The commands act on Paused itself. }
    function ShownPaused: Boolean;
    function ShownRunning: Boolean;
    { breakpoints }
    procedure ToggleBreakpoint(const FileName: string; Line: Integer);
    { Run | Add Breakpoint and the Breakpoints view's Add: the dialog of Kind (a source breakpoint
      at FileName, Line), then the breakpoint - the source breakpoint of that line takes the
      settings when there is one; False: cancelled }
    function AddBreakpointDialog(Kind: TDbgBPKind; const FileName: string; Line: Integer): Boolean;
    { the CPU view's F5: an address breakpoint at Addr, or none any more }
    procedure ToggleAddressBreakpoint(Addr: Cardinal);
    function AddressBreakpointAt(Addr: Cardinal): TDbgBreakpoint;
    procedure GetGroups(L: TStrings);                         // the names of the groups, sorted
    function HasGroups: Boolean;
    procedure EnableGroup(const Group: string; Value: Boolean);   // Enable / Disable Group
    procedure SetFileBreakpoints(const FileName: string; Lines: TList);
    { a file saved under another name: its source breakpoints go with it }
    procedure RenameFileBreakpoints(const OldName, NewName: string);
    function BreakpointCount: Integer;
    function Breakpoint(Index: Integer): TDbgBreakpoint;
    { the engine's breakpoints changed outside the views (the Open Tools API): the Breakpoints
      view filled again, OnBreakpointsChanged }
    procedure BreakpointsChanged;
    { the commands of the Breakpoints view's menu (Delphi 7's) }
    function SelectedBreakpoint: TDbgBreakpoint;
    procedure DeleteSelectedBreakpoint;
    procedure EditSelectedBreakpoint;       // its dialog (Properties, Enter)
    { BP's properties: OnEditBreakpoint first, then its dialog (KeyChanges False: where it is cannot
      be changed); True when the dialog changed it }
    function EditBreakpoint(BP: TDbgBreakpoint; KeyChanges: Boolean): Boolean;
    procedure ToggleSelectedBreakpoint;
    procedure EnableAllBreakpoints(Value: Boolean);
    procedure DeleteAllBreakpoints;
    procedure ShowBreakpointSource;         // View / Edit Source (a double click)
    procedure ShowStackSource;              // the Call Stack's View / Edit Source
    procedure LoadBreakpoints(Ini: TStrings);
    procedure SaveBreakpoints(Ini: TStrings);
    { the breakpoints of Ini (SaveBreakpoints' lines) beside those there are - another project's
      section: a place that has one already is not given a second }
    procedure AddBreakpoints(Ini: TStrings);
    { evaluation }
    { the text of Expr's value in the frame shown, without calls (the address of Goto Address and
      of the address and data breakpoints, TMainForm.ParseAddress) }
    function EvalValue(const Expr: string; var Value: string): Boolean;
    { the editor's value tip (SdHints.TSdValueTip), in the frame shown, without calls: Expr's value,
      the rows of an item of it that is opened (its members, its elements, what it points to) }
    function TipValue(const Expr: string; out V: TDbgVar): Boolean;
    function TipChildren(const Expr: string; out Vars: TDbgVarArray): Boolean;
    { the Watch List (Delphi 7's): Add Watch and Edit Watch open Watch Properties; the commands
      of its menu act on the selected watches (Enable / Disable Watch, Move Watch To Group), the
      group shown (Enable / Disable / Delete All Watches, Delete Group) or the selected one (Edit
      Watch, Break When Changed) }
    procedure AddWatch(const Expr: string);
    procedure EditSelectedWatch;                          // no watch selected: Add Watch
    procedure DeleteSelectedWatch;
    procedure DeleteAllWatches;                           // of the group shown
    procedure EnableSelectedWatches(Value: Boolean);
    procedure EnableAllWatches(Value: Boolean);
    procedure AddWatchGroup(const Name: string);          // a new group, shown (a name there is: nothing)
    procedure DeleteWatchGroup;                           // the group shown (its watches asked for)
    procedure MoveSelectedWatches(Group: Integer);
    procedure BreakWhenChanged;                           // a data breakpoint of the watch, or none any more
    function SelectedWatch: TWatchItem;
    function WatchBreaks(W: TWatchItem): Boolean;         // its data breakpoint is set (enabled)
    function WatchCount: Integer;                         // in the group shown
    procedure GetWatchGroups(L: TStrings);
    function WatchGroupCount: Integer;
    property WatchGroup: Integer read FGroup;
    function SelectedWatchText(Value: Boolean): string;   // Copy Watch Value / Name
    function WatchNodeText(N: TTreeNode): string;         // "name: value" (the state dump)
    function WatchDebugText: string;                      // the state dump's watchlist=
    procedure RefreshWatches;
    function TakeWatch(L: TList; Index: Integer): Boolean;
    { a view of the machine came into view: it catches up with the stop it missed; Fresh: it is
      being filled by its caller (Run | Inspect) - no catching up }
    procedure MachineViewShown(View: TControl);
    procedure MachineViewFresh(View: TControl);
    { the Event Log (its menu: Clear Events, Add Comment) }
    procedure AddLog(const S: string);       // a comment (Add Comment)
    { a message of Kind: shown when Debugger Options | Event Log shows that kind (a comment always) }
    procedure AddLogAs(const S: string; Kind: TEventKind);
    { the Event Log's rows as high as its font needs (it draws them: Debugger Options' colours) }
    procedure LogFontChanged;
    { the watches as the values of the desktop's [Watches] (Environment Options | Preferences |
      Desktop and symbols): Delphi 7's 'expression',format,repeat count,digits,enabled,allow
      calls,'group' - a value of an expression alone is read as well }
    procedure GetWatches(List: TStrings);
    procedure SetWatches(List: TStrings);
    procedure EvaluateDialog(const InitialExpr: string);
    { a new value for Expr (the Debug Inspector's Change); the views show it }
    function ModifyValue(const Expr, Value: string; out Error: string): Boolean;
    property Debugger: TDebugger read FDbg;
    property CallStackView: TListBox read FCallStack;
    property LocalsView: TTreeView read FLocals;
    property WatchView: TTreeView read FWatches;
    property LogView: TListBox read FLog;
    property ExecFile: string read FExecFile;
    property ExecLine: Integer read FExecLine;
    { the stops the IDE has shown (a stop left again before it got here is none) and why the last
      one stopped: the Open Tools API's thread notifications }
    property StopCount: Integer read FStopCount;
    property StopReason: TDbgStopReason read FStopReason;
    property OnEditBreakpoint: TEditBreakpointEvent read FOnEditBreakpoint write FOnEditBreakpoint;
    property OnLocation: TDebugLocationEvent read FOnLocation write FOnLocation;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
    property OnBreakpointsChanged: TNotifyEvent read FOnBreakpointsChanged write FOnBreakpointsChanged;
    { the program has been running for a moment (a step is over before): what shows the last stop
      goes now - the views here, the execution point in the editor (the main form) }
    property OnRunning: TNotifyEvent read FOnRunning write FOnRunning;
    { the address an address text names (the breakpoint dialogs): the main form's }
    property AddressFunc: TAddressFunc read FAddressFunc write FAddressFunc;
  end;

function BlockedExeHint(const Exe, ErrorText: string): string;
{ a frame of the call stack as the Call Stack view names it: its routine, else its module and
  address }
function FrameHeader(const F: TDbgFrame): string;

implementation

uses
  SdFileNames, SdEvalDlg, SdSettings, SdCrashLog;

function FrameHeader(const F: TDbgFrame): string;
begin
  if F.ProcName <> '' then Result := F.ProcName
  else Result := Format('%s.$%.8x', [ChangeFileExt(F.ModuleName, ''), F.Address]);
end;

{ ---------------------------------------------------------------- TNodeTexts }

constructor TNodeTexts.Create;
begin
  inherited Create;
  FExprs := TStringList.Create;
  FValues := TStringList.Create;
end;

destructor TNodeTexts.Destroy;
begin
  FExprs.Free;
  FValues.Free;
  inherited Destroy;
end;

procedure TNodeTexts.Clear;
begin
  FExprs.Clear;
  FValues.Clear;
end;

function TNodeTexts.Add(const Expr, Value: string): Pointer;
begin
  FExprs.Add(Expr);
  FValues.Add(Value);
  Result := Pointer(FExprs.Count);
end;

function TNodeTexts.Expr(Node: TTreeNode): string;
var
  I: Integer;
begin
  I := Integer(Node.Data) - 1;
  if (I >= 0) and (I < FExprs.Count) then Result := FExprs[I] else Result := '';
end;

function TNodeTexts.Value(Node: TTreeNode; out S: string): Boolean;
var
  I: Integer;
begin
  I := Integer(Node.Data) - 1;
  Result := (I >= 0) and (I < FValues.Count);
  if Result then S := FValues[I] else S := '';
end;

{ Text appended to a "cannot start" message when an antivirus product took the program away:
  freshly compiled Delphi 7 executables are a frequent false positive. }
function BlockedExeHint(const Exe, ErrorText: string): string;
var
  Code: Cardinal;
begin
  Result := '';
  Code := GetLastError;
  if (Code = 225) or (Code = 226) or (Pos('virus', LowerCase(ErrorText)) > 0) or
    ((Exe <> '') and not FileExists(Exe)) then
    Result := #13#10#13#10'The executable was blocked or removed, most likely by Windows Security or ' +
      'another antivirus product. Newly compiled Delphi 7 programs are a common false positive: ' +
      'add the project''s output folder to the antivirus exclusions and compile again.';
end;

{ ---------------------------------------------------------------- TDebugController }

constructor TDebugController.Create(AOwner: TForm);
begin
  inherited Create;
  FOwner := AOwner;
  FGroups := TStringList.Create;
  ClearWatchGroups;
  FLocalTexts := TNodeTexts.Create;
  FWatchTexts := TNodeTexts.Create;
  FLocated := TList.Create;
  FDbg := TDebugger.Create;
  FDbg.OnStateChange := DbgStateChange;
  FDbg.OnStop := DbgStop;
  FDbg.OnLog := DbgLog;
  FDbg.OnExit := DbgExit;
  FDbg.OnBreakpointsChanged := DbgBreakpointsChanged;
  FDbg.OnError := DbgError;
  FClearTimer := TTimer.Create(nil);
  FClearTimer.Enabled := False;
  FClearTimer.Interval := 250;
  FClearTimer.OnTimer := ClearTimerTick;
end;

destructor TDebugController.Destroy;
begin
  FClearTimer.Free;
  FDbg.OnStateChange := nil;
  FDbg.OnStop := nil;
  FDbg.OnLog := nil;
  FDbg.OnExit := nil;
  FDbg.OnBreakpointsChanged := nil;
  FDbg.OnError := nil;
  FDbg.Free;
  FLocalTexts.Free;
  FWatchTexts.Free;
  FLocated.Free;
  FreeWatches;
  FGroups.Free;
  inherited;
end;

procedure TDebugController.AttachViews(ACallStack: TListBox; ALocals: TTreeView; AWatches: TSdWatchView;
  ABreaks: TListView; ALog: TListBox);
begin
  FCallStack := ACallStack;
  FLocals := ALocals;
  FLocals.OnExpanding := TreeExpanding;
  FWatchView := AWatches;
  FWatchView.OnCell := WatchCell;
  FWatchView.OnGroupChange := WatchGroupChange;
  FWatches := AWatches.Tree;
  FWatches.OnExpanding := TreeExpanding;
  FWatches.OnKeyDown := WatchesKeyDown;
  FWatches.OnMouseDown := WatchesMouseDown;
  FWatches.OnChange := WatchesChange;
  ShowGroups;
  FBreaks := ABreaks;
  FBreaks.OnChange := BreaksChange;
  FBreaks.OnKeyDown := BreaksKeyDown;
  FLog := ALog;
  FLog.Style := lbOwnerDrawFixed;
  FLog.OnDrawItem := LogDrawItem;
  LogFontChanged;
end;

procedure TDebugController.AttachMachineViews(AThreads, AModules: TListView; ACpu: TSdCpuView; AFpu: TListBox;
  AInspector: TSdInspectorView);
begin
  FThreads := AThreads;
  FThreads.OnDblClick := ThreadsDblClick;
  FModules := AModules;
  FCpu := ACpu;
  FFpu := AFpu;
  FInspector := AInspector;
end;

{ a thread of Thread Status becomes the one inspected: its call stack, locals, CPU, location }
procedure TDebugController.ThreadsDblClick(Sender: TObject);
begin
  if FThreads.Selected <> nil then ShowThread(Cardinal(FThreads.Selected.Data));
end;

function TDebugController.ShowThread(ThreadId: Cardinal): Boolean;
begin
  Result := Paused and FDbg.SelectThread(ThreadId);
  if not Result then Exit;
  RefreshViews;          // FFrames: the call stack of the thread
  if (Length(FFrames) > 0) and (FFrames[0].Line > 0) and Assigned(FOnLocation) then
  begin
    FExecFile := FFrames[0].FileName;
    FExecLine := FFrames[0].Line;
    FOnLocation(FExecFile, FExecLine);
  end;
end;

procedure TDebugController.StepInstruction(Over: Boolean);
begin
  if Paused then FDbg.StepInstruction(Over);
end;

procedure TDebugController.TraceToSource;
begin
  if Paused then FDbg.TraceToSource;
end;

{ the rows as high as the log's font + 2 - measured without the list's window: at start the
  list has none yet, and its rows kept the .dfm's height (the text ran into the next row) }
procedure TDebugController.LogFontChanged;
begin
  if FLog = nil then Exit;
  FLog.ItemHeight := UIFontHeight(FLog.Font) + 2;
end;

procedure TDebugController.AddLog(const S: string);
begin
  AddLogKind(S, ekComment);
end;

procedure TDebugController.AddLogAs(const S: string; Kind: TEventKind);
begin
  if (Kind = ekComment) or DebuggerOptions.LogKinds[Kind] then AddLogKind(S, Kind);
end;

{ a message of the Event Log: its kind with it (the colours), at most Length of them (Debugger
  Options | Event Log) }
procedure TDebugController.AddLogKind(const S: string; Kind: TEventKind);
begin
  if FLog = nil then Exit;
  if not DebuggerOptions.LogUnlimited then
    while (FLog.Items.Count > 0) and (FLog.Items.Count >= DebuggerOptions.LogLength) do FLog.Items.Delete(0);
  FLog.Items.AddObject(S, TObject(Ord(Kind)));
  FLog.TopIndex := FLog.Items.Count - 1;
end;

procedure TDebugController.LogDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  K: TEventKind;
begin
  C := FLog.Canvas;
  K := TEventKind(Integer(FLog.Items.Objects[Index]));
  if odSelected in State then
  begin
    C.Brush.Color := clHighlight;
    C.Font.Color := clHighlightText;
  end
  else if DebuggerOptions.LogUseColors then
  begin
    C.Brush.Color := DebuggerOptions.LogColors[K].Back;
    C.Font.Color := DebuggerOptions.LogColors[K].Fore;
  end
  else
  begin
    C.Brush.Color := FLog.Color;
    C.Font.Color := FLog.Font.Color;
  end;
  { the text clipped to its row: an opaque text cell never reaches the next one }
  C.TextRect(Rect, Rect.Left + 2, UIListTextTop(C.Handle, Rect), FLog.Items[Index]);
end;

{ --- session --- }

function TDebugController.Active: Boolean;
begin
  Result := FDbg.State <> dsNone;
end;

function TDebugController.Paused: Boolean;
begin
  Result := FDbg.State = dsPaused;
end;

{ what every session takes from the IDE: where the sources are, Debugger Options (the log,
  spawned processes, the exceptions) }
procedure TDebugController.PrepareSession(SourceDirs: TStrings);
var
  Rules: array of TDbgOSRule;
  I: Integer;
begin
  FDbg.SourceDirs.Assign(SourceDirs);
  if (FLog <> nil) and DebuggerOptions.LogClearOnRun then FLog.Items.Clear;
  FDbg.DebugSpawned := DebuggerOptions.DebugSpawned;
  { Debugger Options: Language Exceptions, OS Exceptions }
  FDbg.StopOnDelphiExceptions := DebuggerOptions.StopOnDelphi;
  IgnoredExceptionNames(FDbg.IgnoredExceptions);
  SetLength(Rules, Length(DebuggerOptions.OSExceptions));
  for I := 0 to High(Rules) do
  begin
    Rules[I].Low := DebuggerOptions.OSExceptions[I].Low;
    Rules[I].High := DebuggerOptions.OSExceptions[I].High;
    Rules[I].Stop := not DebuggerOptions.OSExceptions[I].UserHandles;
    Rules[I].RunHandled := DebuggerOptions.OSExceptions[I].RunHandled;
  end;
  FDbg.SetOSRules(Rules);
end;

function TDebugController.Run(const Exe, Params, WorkDir: string; SourceDirs: TStrings; StopAtEntry: Boolean;
  const Env: string): Boolean;
begin
  PrepareSession(SourceDirs);
  FDbg.StopAtEntry := StopAtEntry;
  FDbg.Environment := Env;
  Result := FDbg.Start(Exe, Params, WorkDir);
  if not Result then
    MessageBox(FOwner.Handle, PChar('Unable to start the program:'#13#10 + FDbg.LastError +
      BlockedExeHint(Exe, FDbg.LastError)), 'Error', MB_OK or MB_ICONERROR);
end;

function TDebugController.Attach(Pid: Cardinal; SourceDirs: TStrings): Boolean;
begin
  PrepareSession(SourceDirs);
  FDbg.StopAtEntry := False;
  Result := FDbg.Attach(Pid);
  if not Result then
    MessageBox(FOwner.Handle, PChar('Unable to attach to the process:'#13#10 + FDbg.LastError), 'Error',
      MB_OK or MB_ICONERROR);
end;

procedure TDebugController.Detach;
begin
  if Active then FDbg.Detach;
end;

procedure TDebugController.Resume;
begin
  if Paused then
  begin
    FExecFile := '';
    FExecLine := 0;
    FDbg.Resume;
  end;
end;

procedure TDebugController.Pause;
begin
  if FDbg.State = dsRunning then FDbg.Pause;
end;

procedure TDebugController.Stop;
begin
  if Active then FDbg.Stop;
end;

procedure TDebugController.StepOver;
begin
  if Paused then FDbg.StepOver;
end;

procedure TDebugController.StepInto;
begin
  if Paused then FDbg.StepInto;
end;

procedure TDebugController.StepOut;
begin
  if Paused then FDbg.StepOut;
end;

procedure TDebugController.RunToLine(const FileName: string; Line: Integer);
begin
  if Paused then FDbg.RunToLine(FileName, Line);
end;

{ No flicker: a step runs the program for a few milliseconds - emptying the views at
  its start and filling them at its end showed them blank for a moment at every F7 / F8. They go
  when the program is still running a quarter of a second later (a run, not a step). }
procedure TDebugController.DbgStateChange(Sender: TObject);
begin
  { a stop tells the IDE itself once its views and its place are new (DbgStop) - told here as well,
    the IDE did all of its work twice at every stop; a breakpoint's trigger is no stop }
  if FDbg.State = dsPaused then Exit;
  FExecFile := '';
  FExecLine := 0;
  if FDbg.State = dsRunning then
  begin
    FClearTimer.Enabled := False;
    FClearTimer.Enabled := True;
  end;
  if Assigned(FOnStateChange) then FOnStateChange(Self);
end;

function TDebugController.ShownPaused: Boolean;
begin
  Result := Paused or ((FDbg.State = dsRunning) and FClearTimer.Enabled);
end;

function TDebugController.ShownRunning: Boolean;
begin
  Result := (FDbg.State = dsRunning) and not FClearTimer.Enabled;
end;

procedure TDebugController.ClearTimerTick(Sender: TObject);
begin
  FClearTimer.Enabled := False;
  if FDbg.State <> dsRunning then Exit;
  ClearViews;
  if Assigned(FOnRunning) then FOnRunning(Self);
end;

procedure TDebugController.DbgStop(Sender: TObject; Reason: TDbgStopReason; const Frame: TDbgFrame; const Msg: string);
const
  StatusOf: array[TDbgStopReason] of string = ('Unknown', 'Entry', 'Breakpoint', 'Stepped', 'Paused',
    'Faulted', 'Run to cursor');
begin
  FClearTimer.Enabled := False;
  FStopStatus := StatusOf[Reason];
  Inc(FStopCount);
  FStopReason := Reason;
  FExecFile := Frame.FileName;
  FExecLine := Frame.Line;
  try
    RefreshViews;
    if (FExecFile <> '') and (FExecLine > 0) and Assigned(FOnLocation) then
      FOnLocation(FExecFile, FExecLine);
  finally
    if Assigned(FOnStateChange) then FOnStateChange(Self);   // the IDE learns of the stop here only
  end;
  { bring the IDE to the front - but never the cloaked test instance }
  if not UITestMode then
  begin
    if IsIconic(Application.Handle) then Application.Restore;
    SetForegroundWindow(FOwner.Handle);
  end;
  if (Reason = srException) and (Msg <> '') then
    MessageBox(FOwner.Handle, PChar(Msg + ' Process stopped. Use Step or Run to continue.'),
      'Debugger Exception Notification', MB_OK or MB_ICONERROR);
end;

{ "...  Process Project1.exe (1234)" without its process (Display process info with event off) }
function WithoutProcessInfo(const S: string): string;
var
  P: Integer;
begin
  Result := S;
  P := Length(S);
  while (P > 1) and not ((S[P] = 'P') and (Copy(S, P - 2, 2) = '. ') and (Copy(S, P, 8) = 'Process ')) do Dec(P);
  if (P > 1) and (S[Length(S)] = ')') then Result := Copy(S, 1, P - 2);
end;

procedure TDebugController.DbgLog(Sender: TObject; Kind: TDbgLogKind; const Text: string);
const
  { the engine's texts follow the Delphi 7 event log; only debug strings arrive bare }
  Prefix: array[TDbgLogKind] of string = ('', '', '', 'ODS: ', '', '');
  { the Messages kinds of Debugger Options (exceptions are process messages, always shown) }
  Kinds: array[TDbgLogKind] of TEventKind = (ekProcess, ekThread, ekModule, ekOutput, ekProcess,
    ekBreakpoint);
var
  S: string;
begin
  if (Kind <> lkException) and not DebuggerOptions.LogKinds[Kinds[Kind]] then Exit;
  S := Prefix[Kind] + Text;
  { a debug string is the program's text: it has no process info to take away ("Done. Process
    list (3)" lost its end) }
  if not DebuggerOptions.LogProcessInfo and (Kind <> lkDebugString) then S := WithoutProcessInfo(S);
  AddLogKind(S, Kinds[Kind]);
end;

{ the program ended: the places its watches had in memory are no one's any more - of every group,
  not only the one shown (Break When Changed would take the old address in the next session) }
procedure TDebugController.ForgetWatchPlaces;
var
  G, I: Integer;
  L: TList;
begin
  for G := 0 to FGroups.Count - 1 do
  begin
    L := GroupList(G);
    for I := 0 to L.Count - 1 do
    begin
      TWatchItem(L[I]).Address := 0;
      TWatchItem(L[I]).Size := 0;
    end;
  end;
end;

procedure TDebugController.DbgExit(Sender: TObject; ExitCode: Cardinal);
begin
  FExecFile := '';
  FExecLine := 0;
  ForgetWatchPlaces;
  ClearViews;
  { a detached program runs on (the engine logged the detach) }
  if DebuggerOptions.LogKinds[ekProcess] and not FDbg.Detached then
    AddLogKind(Format('Process terminated with exit code %d', [ExitCode]), ekProcess);
  if Assigned(FOnStateChange) then FOnStateChange(Self);
end;

procedure TDebugController.DbgBreakpointsChanged(Sender: TObject);
begin
  FillBreaks;
  if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
end;

{ an exception the engine caught to go on (one of the handlers above, or its debug thread): into
  the error log with the IDE's others }
procedure TDebugController.DbgError(Sender: TObject; E: Exception);
begin
  LogException(E, 'debugger', SettingsDir + 'error.log');
end;

{ --- views --- }

procedure TDebugController.ClearViews;
begin
  if FCallStack = nil then Exit;
  FCallStack.Items.Clear;
  FLocals.Items.Clear;
  FLocalTexts.Clear;
  RefreshWatches;
  if FThreads <> nil then
  begin
    FillChar(FMachineStale, SizeOf(FMachineStale), 0);     // cleared: nothing to catch up with
    FThreads.Items.Clear;
    FCpu.Clear;
    FFpu.Items.Clear;
    FInspector.Clear;
    { the modules stay while the process exists (Modules shows the loaded ones) }
    if FDbg.State = dsNone then FModules.Items.Clear;
  end;
end;

{ the texts behind the rows of Local Variables or the Watch List }
function TDebugController.TextsOf(Tree: TObject): TNodeTexts;
begin
  if Tree = FWatches then Result := FWatchTexts else Result := FLocalTexts;
end;

{ a row "name: value" - in the Watch List the name, its value is the second column }
procedure TDebugController.AddVarNode(Tree: TTreeView; Parent: TTreeNode; const V: TDbgVar);
var
  N: TTreeNode;
begin
  if Tree = FWatches then N := Tree.Items.AddChild(Parent, V.Name)
  else N := Tree.Items.AddChild(Parent, V.Name + ': ' + V.Value);
  N.Data := TextsOf(Tree).Add(V.Expr, V.Value);
  if V.Expandable and (V.Expr <> '') then
    Tree.Items.AddChild(N, '');      // placeholder, filled when the node expands
end;

procedure TDebugController.TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
var
  Vars: TDbgVarArray;
  I: Integer;
  Tree: TTreeView;
  W: TWatchItem;
  Calls: Boolean;
begin
  AllowExpansion := True;
  if (Node.Count = 1) and (Node.Item[0].Text = '') and (Node.Item[0].Data = nil) then
  begin
    Tree := TTreeView(Sender);
    { the parts of a watch with Allow Function Calls are read as its value was: with calls }
    Calls := False;
    if Tree = FWatches then
    begin
      W := WatchOfNode(Node);
      Calls := (W <> nil) and W.AllowCalls;
    end;
    Tree.Items.BeginUpdate;
    try
      Node.DeleteChildren;
      if Paused and FDbg.GetChildren(TextsOf(Tree).Expr(Node), Vars, Calls) then
        for I := 0 to High(Vars) do AddVarNode(Tree, Node, Vars[I]);
    finally
      Tree.Items.EndUpdate;
    end;
    AllowExpansion := Node.Count > 0;
  end;
end;

procedure TDebugController.GetWatches(List: TStrings);
var
  G, I: Integer;
begin
  List.Clear;
  for G := 0 to FGroups.Count - 1 do
    for I := 0 to GroupList(G).Count - 1 do List.Add(TWatchItem(GroupList(G)[I]).DesktopText);
end;

{ the watches of a desktop: their groups in the order they come, the first group shown }
procedure TDebugController.SetWatches(List: TStrings);
var
  I: Integer;
  W: TWatchItem;
begin
  ClearWatchGroups;
  for I := 0 to List.Count - 1 do
  begin
    W := TWatchItem.Create;
    if W.ReadDesktop(List[I], FGroups[0]) then GroupList(GroupOf(W.Group)).Add(W) else W.Free;
  end;
  FGroup := 0;
  ShowGroups;
  RefreshWatches;
end;

{ --- the Watch List's groups (Delphi's tabs below the list) --- }

function TDebugController.GroupList(Index: Integer): TList;
begin
  Result := TList(FGroups.Objects[Index]);
end;

function TDebugController.GroupOf(const Name: string): Integer;
begin
  Result := FGroups.IndexOf(Name);
  if Result < 0 then Result := FGroups.AddObject(Name, TList.Create);
end;

procedure TDebugController.FreeWatches;
var
  G, I: Integer;
begin
  for G := 0 to FGroups.Count - 1 do
  begin
    for I := 0 to GroupList(G).Count - 1 do TWatchItem(GroupList(G)[I]).Free;
    GroupList(G).Free;
  end;
  FGroups.Clear;
  FGroup := 0;
end;

{ Delphi's first group is "Watches" }
procedure TDebugController.ClearWatchGroups;
begin
  FreeWatches;
  FGroups.AddObject('Watches', TList.Create);
end;

procedure TDebugController.ShowGroups;
begin
  if FWatchView <> nil then FWatchView.SetGroups(FGroups, FGroup);
end;

procedure TDebugController.GetWatchGroups(L: TStrings);
begin
  L.Assign(FGroups);
end;

function TDebugController.WatchGroupCount: Integer;
begin
  Result := FGroups.Count;
end;

function TDebugController.WatchCount: Integer;
begin
  Result := GroupList(FGroup).Count;
end;

{ a tab chosen: its watches, evaluated }
procedure TDebugController.WatchGroupChange(Sender: TObject);
begin
  if (FWatchView.GroupIndex < 0) or (FWatchView.GroupIndex >= FGroups.Count) then Exit;
  FGroup := FWatchView.GroupIndex;
  RefreshWatches;
end;

{ --- the Watch List's rows --- }

{ the watch's expression with the format specifier of its display format, for the formats the
  evaluator has (Watch Properties: Character, String, Decimal, Hexadecimal, Pointer) }
function TDebugController.WatchEvalText(W: TWatchItem): string;
begin
  Result := W.Expr;
  case W.Format of
    wfCharacter: Result := Result + ',c';
    wfString: Result := Result + ',s';
    wfDecimal: Result := Result + ',d';
    wfHexadecimal: Result := Result + ',h';
    wfPointer: Result := Result + ',p';
  end;
end;

{ where the watch's value lies and how long it is (Break When Changed): the stopped program's
  Addr() and SizeOf() of it - nothing for an expression that is no variable. Two evaluations more
  for every watch at every stop were too many: only a watch that needs it is located - one whose
  data breakpoint is set (it is red while it has an address), the one selected (Break When
  Changed acts on it) - once after the watches were filled; the others have no address then. }
procedure TDebugController.LocateWatch(W: TWatchItem);
var
  A: Cardinal;
  V: TDbgVar;
  Err: string;
begin
  if FLocated.IndexOf(W) >= 0 then Exit;
  FLocated.Add(W);
  W.Address := 0;
  W.Size := 0;
  if Assigned(FAddressFunc) and FAddressFunc('Addr(' + W.Expr + ')', A) then W.Address := A;
  if (W.Address <> 0) and FDbg.Evaluate('SizeOf(' + W.Expr + ')', V, Err) then
    W.Size := Cardinal(StrToIntDef(Trim(V.Value), 0));
end;

{ a watch's row: its expression, its value - <disabled>, the program's value or why there is
  none - and its check box; a value with members can be opened }
procedure TDebugController.FillWatchNode(N: TTreeNode; W: TWatchItem);
var
  V: TDbgVar;
  Err, Value, E: string;
  Expandable: Boolean;
begin
  Inc(FFillingWatches);
  try
    N.DeleteChildren;          // a member selected: the selection moves (WatchesChange waits)
  finally
    Dec(FFillingWatches);
  end;
  N.Text := W.Expr;
  E := '';
  Expandable := False;
  if not Active then
  begin
    W.Address := 0;
    W.Size := 0;
  end;
  if not W.Enabled then Value := '<disabled>'
  else if not Paused then Value := '[process not accessible]'
  else if FDbg.Evaluate(WatchEvalText(W), V, Err, W.AllowCalls) then
  begin
    Value := V.Value;
    E := V.Expr;
    if E = '' then E := W.Expr;
    Expandable := V.Expandable;
    if (W = SelectedWatch) or (DataWatch(W.Expr) <> nil) then
      LocateWatch(W)
    else if FLocated.IndexOf(W) < 0 then
    begin
      W.Address := 0;
      W.Size := 0;
    end;
  end
  else
  begin
    Value := Err;
    W.Address := 0;
    W.Size := 0;
  end;
  N.Data := FWatchTexts.Add(E, Value);
  if Expandable and (E <> '') then FWatches.Items.AddChild(N, '');   // placeholder, filled when it opens
  FWatchView.SetChecked(N, W.Enabled);
end;

{ the watches of the group shown (their texts new, their places read again where needed) }
procedure TDebugController.RefreshWatches;
var
  I: Integer;
  L: TList;
  N, Next: TTreeNode;
  Open: Boolean;
begin
  if FWatches = nil then Exit;
  L := GroupList(FGroup);
  Inc(FFillingWatches);
  FWatches.Items.BeginUpdate;
  try
    { the rows of the group shown are filled again in place: the chosen watch, the open rows (their
      members read again) and the place in the list stay at each step; another group: made anew }
    if FWatchesList <> L then FWatches.Items.Clear;
    FWatchesList := L;
    FWatchTexts.Clear;
    FLocated.Clear;
    N := FWatches.Items.GetFirstNode;
    for I := 0 to L.Count - 1 do
    begin
      if N = nil then N := FWatches.Items.Add(nil, '');
      Open := N.Expanded;
      FillWatchNode(N, TWatchItem(L[I]));
      if Open and N.HasChildren then N.Expand(False);
      N := N.GetNextSibling;
    end;
    while N <> nil do
    begin
      Next := N.GetNextSibling;
      N.Delete;
      N := Next;
    end;
  finally
    FWatches.Items.EndUpdate;
    Dec(FFillingWatches);
  end;
end;

{ a watch selected: its place, for Break When Changed (while the program stands; not while the
  rows are made again - the tree reports its selection then too) }
procedure TDebugController.WatchesChange(Sender: TObject; Node: TTreeNode);
var
  W: TWatchItem;
begin
  if (FFillingWatches > 0) or (Node = nil) or not Paused then Exit;
  W := WatchOfNode(Node);
  if (W <> nil) and W.Enabled then LocateWatch(W);
end;

{ the second column and the colour of a row: a disabled watch grey, one whose data breakpoint is
  set red (Delphi's) }
procedure TDebugController.WatchCell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
var
  W: TWatchItem;
  S: string;
begin
  if FWatchTexts.Value(Node, S) then Value := S;
  if Node.Parent <> nil then Exit;
  W := WatchOfNode(Node);
  if W = nil then Exit;
  if not W.Enabled then Color := clGrayText
  else if WatchBreaks(W) then Color := clRed;
end;

function TDebugController.WatchOfNode(N: TTreeNode): TWatchItem;
var
  L: TList;
begin
  Result := nil;
  if N = nil then Exit;
  while N.Parent <> nil do N := N.Parent;
  L := GroupList(FGroup);
  if N.Index < L.Count then Result := TWatchItem(L[N.Index]);
end;

function TDebugController.SelectedWatch: TWatchItem;
begin
  Result := nil;
  if FWatches <> nil then Result := WatchOfNode(FWatches.Selected);
end;

{ the watches of the selected rows, in the order of the group (the rows' positions are those of
  the group's list until it changes: taken before) }
procedure TDebugController.SelectedWatches(L: TList);
var
  Rows, G: TList;
  I: Integer;
  Sel: array of Boolean;
begin
  L.Clear;
  G := GroupList(FGroup);
  Rows := TList.Create;
  try
    SelectedWatchNodes(Rows);
    SetLength(Sel, G.Count);
    for I := 0 to Rows.Count - 1 do
      if TTreeNode(Rows[I]).Index < G.Count then Sel[TTreeNode(Rows[I]).Index] := True;
    for I := 0 to G.Count - 1 do
      if Sel[I] then L.Add(G[I]);
  finally
    Rows.Free;
  end;
end;

{ the rows of the selected watches (a member chosen: its watch), each once }
procedure TDebugController.SelectedWatchNodes(L: TList);
var
  I: Integer;
  N: TTreeNode;
begin
  L.Clear;
  if FWatches = nil then Exit;
  for I := 0 to Integer(FWatches.SelectionCount) - 1 do
  begin
    N := FWatches.Selections[I];
    while N.Parent <> nil do N := N.Parent;
    if L.IndexOf(N) < 0 then L.Add(N);
  end;
  N := FWatches.Selected;
  if (L.Count = 0) and (N <> nil) then
  begin
    while N.Parent <> nil do N := N.Parent;
    L.Add(N);
  end;
end;

procedure TDebugController.RefreshViews;
var
  I: Integer;
  S: string;
begin
  if FCallStack = nil then Exit;
  FCallStack.Items.BeginUpdate;
  try
    FCallStack.Items.Clear;
    if Paused and FDbg.GetCallStack(FFrames) then
      for I := 0 to High(FFrames) do
      begin
        S := FrameHeader(FFrames[I]);
        if FFrames[I].Line > 0 then
          S := S + Format(' (%s, line %d)', [ExtractFileName(FFrames[I].FileName), FFrames[I].Line]);
        FCallStack.Items.Add(S);
      end;
    if (FDbg.CurrentFrame >= 0) and (FDbg.CurrentFrame < FCallStack.Items.Count) then
      FCallStack.ItemIndex := FDbg.CurrentFrame;
  finally
    FCallStack.Items.EndUpdate;
  end;
  FillLocals;
  { the views of the machine that can be seen; a hidden one catches up when it is shown - the
    Debug Inspector's evaluation calls property getters in the program, and the CPU view decodes
    and looks up a hundred lines: nothing of that for a view nobody sees }
  if FThreads <> nil then
    for I := 0 to High(FMachineStale) do
      if MachineView(I).Showing then RefreshMachine(I) else FMachineStale[I] := True;
end;

function TDebugController.MachineView(I: Integer): TWinControl;
begin
  case I of
    0: Result := FThreads;
    1: Result := FModules;
    2: Result := FCpu;
    3: Result := FFpu;
  else
    Result := FInspector;
  end;
end;

procedure TDebugController.RefreshMachine(I: Integer);
begin
  FMachineStale[I] := False;
  case I of
    0: FillThreads(FDbg, FThreads, FStopStatus);
    1: FillModules(FDbg, FModules);
    2: FCpu.Refresh(FDbg);
    3: FillFpu(FDbg, FFpu);
  else
    FInspector.Refresh(FDbg);
  end;
end;

procedure TDebugController.MachineViewShown(View: TControl);
var
  I: Integer;
begin
  if (FThreads = nil) or not Paused then Exit;
  for I := 0 to High(FMachineStale) do
    if (MachineView(I) = View) and FMachineStale[I] then RefreshMachine(I);
end;

procedure TDebugController.MachineViewFresh(View: TControl);
var
  I: Integer;
begin
  if FThreads = nil then Exit;
  for I := 0 to High(FMachineStale) do
    if MachineView(I) = View then FMachineStale[I] := False;
end;

{ Local Variables and Watches for the current frame }
procedure TDebugController.FillLocals;
var
  I: Integer;
  Vars: TDbgVarArray;
  Open: TStringList;
  Sel: string;
  N: TTreeNode;

  { a row's variable: its text up to the value ("name: value") }
  function NameOf(Node: TTreeNode): string;
  begin
    Result := Node.Text;
    if Pos(': ', Result) > 0 then Result := Copy(Result, 1, Pos(': ', Result) - 1);
  end;

begin
  { the variables open and the one chosen, by name: so again after the refill of the next step }
  Open := TStringList.Create;
  try
    Sel := '';
    if (FLocals.Selected <> nil) and (FLocals.Selected.Level = 0) then Sel := NameOf(FLocals.Selected);
    N := FLocals.Items.GetFirstNode;
    while N <> nil do
    begin
      if N.Expanded then Open.Add(NameOf(N));
      N := N.GetNextSibling;
    end;
    FLocals.Items.BeginUpdate;
    try
      FLocals.Items.Clear;
      FLocalTexts.Clear;
      if Paused and FDbg.GetLocals(Vars) then
        for I := 0 to High(Vars) do AddVarNode(FLocals, nil, Vars[I]);
      N := FLocals.Items.GetFirstNode;
      while N <> nil do
      begin
        if (Open.IndexOf(NameOf(N)) >= 0) and N.HasChildren then N.Expand(False);
        if (Sel <> '') and (NameOf(N) = Sel) then N.Selected := True;
        N := N.GetNextSibling;
      end;
    finally
      FLocals.Items.EndUpdate;
    end;
  finally
    Open.Free;
  end;
  RefreshWatches;
end;

{ the Call Stack's View / Edit Source: the chosen frame becomes the current one (its locals),
  its line is shown }
procedure TDebugController.ShowStackSource;
var
  I: Integer;
begin
  I := FCallStack.ItemIndex;
  if (I < 0) or (I > High(FFrames)) or not Paused then Exit;
  FDbg.CurrentFrame := I;
  FillLocals;
  if (FFrames[I].FileName <> '') and (FFrames[I].Line > 0) and Assigned(FOnLocation) then
    FOnLocation(FFrames[I].FileName, FFrames[I].Line);
end;

{ --- watches (Delphi 7's Watch List) --- }

{ Add Watch: Watch Properties for a new watch of the group shown (Allow Function Calls as Debugger
  Options say for new watches); it joins the group named there - a new name makes the group -,
  which is shown. An expression the group has already is not added again. }
procedure TDebugController.AddWatch(const Expr: string);
var
  W: TWatchItem;
  L: TList;
  I: Integer;
begin
  W := TWatchItem.Create;
  try
    W.Expr := Trim(Expr);
    W.Group := FGroups[FGroup];
    W.AllowCalls := DebuggerOptions.SideEffects;
    if not WatchDialog(FOwner, W) then Exit;
    FGroup := GroupOf(W.Group);
    L := GroupList(FGroup);
    I := L.Count - 1;
    while (I >= 0) and not SameText(TWatchItem(L[I]).Expr, W.Expr) do Dec(I);
    if I < 0 then
    begin
      L.Add(W);
      W := nil;
    end;
  finally
    W.Free;
  end;
  ShowGroups;
  RefreshWatches;
end;

{ Edit Watch (Delphi's EditWatch): Watch Properties of the selected watch - without one, Add
  Watch. Another group moves the watch there and shows that group; another expression takes the
  data breakpoint of the old one away (Break When Changed). }
procedure TDebugController.EditSelectedWatch;
var
  W, S: TWatchItem;
  Old: string;
begin
  W := SelectedWatch;
  if W = nil then
  begin
    AddWatch('');
    Exit;
  end;
  S := TWatchItem.Create;
  try
    S.Assign(W);
    if not WatchDialog(FOwner, S) then Exit;
    Old := W.Expr;
    if not SameText(S.Group, W.Group) then
    begin
      GroupList(FGroup).Remove(W);
      GroupList(GroupOf(S.Group)).Add(W);
    end;
    W.Assign(S);
    FGroup := GroupOf(W.Group);
  finally
    S.Free;
  end;
  if not SameText(W.Expr, Old) and RemoveDataWatches(Old) then BreakpointsChanged;
  ShowGroups;
  RefreshWatches;
end;

{ Delete Watch: the selected watches; a data breakpoint of a watch goes with it (Delphi's
  RemoveWatch) }
procedure TDebugController.DeleteSelectedWatch;
var
  L: TList;
  I: Integer;
  W: TWatchItem;
  Changed: Boolean;
begin
  L := TList.Create;
  try
    SelectedWatches(L);
    if L.Count = 0 then Exit;
    Changed := False;
    for I := 0 to L.Count - 1 do
    begin
      W := TWatchItem(L[I]);
      Changed := TakeWatch(GroupList(FGroup), GroupList(FGroup).IndexOf(W)) or Changed;
    end;
  finally
    L.Free;
  end;
  RefreshWatches;
  if Changed then BreakpointsChanged;
end;

{ watch Index of L goes, and with it its data breakpoint (Break When Changed) - unless another
  watch of any group has its expression; also while no program runs (its breakpoint is disabled
  then, and would stay in the list and the project). True: a breakpoint went }
function TDebugController.TakeWatch(L: TList; Index: Integer): Boolean;
var
  W: TWatchItem;
  G, I: Integer;
  Other: TList;
begin
  Result := False;
  if (Index < 0) or (Index >= L.Count) then Exit;
  W := TWatchItem(L[Index]);
  L.Delete(Index);
  try
    for G := 0 to FGroups.Count - 1 do
    begin
      Other := GroupList(G);
      for I := 0 to Other.Count - 1 do
        if SameText(TWatchItem(Other[I]).Expr, W.Expr) then Exit;
    end;
    Result := RemoveDataWatches(W.Expr);
  finally
    W.Free;
  end;
end;

{ Delete All Watches: those of the group shown }
procedure TDebugController.DeleteAllWatches;
var
  L: TList;
  Changed: Boolean;
begin
  L := GroupList(FGroup);
  Changed := False;
  while L.Count > 0 do Changed := TakeWatch(L, L.Count - 1) or Changed;
  RefreshWatches;
  if Changed then BreakpointsChanged;
end;

{ a watch enabled (evaluated again) or disabled (<disabled>, not evaluated) - its row in place }
procedure TDebugController.SetWatchEnabled(N: TTreeNode; Value: Boolean);
var
  W: TWatchItem;
begin
  W := WatchOfNode(N);
  if (W = nil) or (W.Enabled = Value) then Exit;
  W.Enabled := Value;
  FillWatchNode(N, W);
end;

{ Enable Watch / Disable Watch: the selected watches }
procedure TDebugController.EnableSelectedWatches(Value: Boolean);
var
  L: TList;
  I: Integer;
begin
  L := TList.Create;
  try
    SelectedWatchNodes(L);
    for I := 0 to L.Count - 1 do SetWatchEnabled(TTreeNode(L[I]), Value);
  finally
    L.Free;
  end;
end;

{ Enable All Watches / Disable All Watches: those of the group shown }
procedure TDebugController.EnableAllWatches(Value: Boolean);
var
  N: TTreeNode;
begin
  if FWatches = nil then Exit;
  N := FWatches.Items.GetFirstNode;
  while N <> nil do
  begin
    SetWatchEnabled(N, Value);
    N := N.GetNextSibling;
  end;
end;

{ Add Group (Delphi's AddWatchGroup): a group of that name joins the tabs and is shown }
procedure TDebugController.AddWatchGroup(const Name: string);
begin
  if FGroups.IndexOf(Name) >= 0 then Exit;
  FGroup := GroupOf(Name);
  ShowGroups;
  RefreshWatches;
end;

{ Delete Group: the group shown, when there is another one; its watches go with it - Delphi asks
  first, as for Delete All Watches }
procedure TDebugController.DeleteWatchGroup;
var
  L: TList;
  Changed: Boolean;
begin
  if FGroups.Count < 2 then Exit;
  L := GroupList(FGroup);
  if (L.Count > 0) and (MessageBox(FOwner.Handle, 'Delete all watches?', 'Confirm',
    MB_YESNO or MB_ICONQUESTION) <> IDYES) then Exit;
  Changed := False;
  while L.Count > 0 do Changed := TakeWatch(L, L.Count - 1) or Changed;
  L.Free;
  FGroups.Delete(FGroup);
  if FGroup >= FGroups.Count then FGroup := FGroups.Count - 1;
  ShowGroups;
  RefreshWatches;
  if Changed then BreakpointsChanged;
end;

{ Move Watch To Group: the selected watches join the group (Delphi takes them from the last to the
  first); the group shown stays }
procedure TDebugController.MoveSelectedWatches(Group: Integer);
var
  L: TList;
  I: Integer;
  W: TWatchItem;
begin
  if (Group < 0) or (Group >= FGroups.Count) or (Group = FGroup) then Exit;
  L := TList.Create;
  try
    SelectedWatches(L);
    for I := L.Count - 1 downto 0 do
    begin
      W := TWatchItem(L[I]);
      GroupList(FGroup).Remove(W);
      GroupList(Group).Add(W);
      W.Group := FGroups[Group];
    end;
  finally
    L.Free;
  end;
  RefreshWatches;
end;

{ the data breakpoint Break When Changed set for the watch of Expr (Delphi's FindDataWatch) }
function TDebugController.DataWatch(const Expr: string): TDbgBreakpoint;
var
  I: Integer;
begin
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    Result := FDbg.Breakpoints[I];
    if (Result.Kind = bkData) and (Result.Watch <> '') and SameText(Result.Watch, Expr) then Exit;
  end;
  Result := nil;
end;

function TDebugController.RemoveDataWatches(const Expr: string): Boolean;
var
  BP: TDbgBreakpoint;
begin
  Result := False;
  repeat
    BP := DataWatch(Expr);
    if BP <> nil then
    begin
      FDbg.RemoveBreakpoint(BP);
      Result := True;
    end;
  until BP = nil;
end;

{ Delphi's: the watch has a place and its data breakpoint is there and enabled }
function TDebugController.WatchBreaks(W: TWatchItem): Boolean;
var
  BP: TDbgBreakpoint;
begin
  BP := DataWatch(W.Expr);
  Result := (W.Address <> 0) and (BP <> nil) and BP.Enabled;
end;

{ Break When Changed: a data breakpoint at the selected watch's value (its address and size at the
  last stop; Delphi's messages when it has none), or - when it is set - none any more. The
  breakpoint is one of the Breakpoints view's (a data breakpoint of 1, 2 or 4 bytes, as the
  processor's). }
procedure TDebugController.BreakWhenChanged;
var
  W: TWatchItem;
  BP: TDbgBreakpoint;
  Err: string;
begin
  W := SelectedWatch;
  if W = nil then Exit;
  if WatchBreaks(W) then
    RemoveDataWatches(W.Expr)
  else
  begin
    if (W.Address = 0) or (W.Address = $FFFFFFFF) then Err := Format('Unable to get address of ''%s''', [W.Expr])
    else if W.Size = 0 then Err := Format('Unable to determine size of ''%s''', [W.Expr])
    else Err := DataBreakpointError(W.Address, W.Size);
    if Err <> '' then
    begin
      MessageBox(FOwner.Handle, PChar(Err), 'Error', MB_OK or MB_ICONERROR);
      Exit;
    end;
    RemoveDataWatches(W.Expr);
    BP := TDbgBreakpoint.Create;
    try
      BP.Kind := bkData;
      BP.Address := W.Address;
      BP.DataLength := W.Size;
      BP.Watch := W.Expr;
      FDbg.AddBreakpointAs(BP);
    finally
      BP.Free;
    end;
  end;
  BreakpointsChanged;
end;

{ "name: value" of a row }
function TDebugController.WatchNodeText(N: TTreeNode): string;
var
  S: string;
begin
  Result := N.Text;
  if FWatchTexts.Value(N, S) then Result := Result + ': ' + S;
end;

{ the selected watch (or a member of it): its value (the second column) or its name }
function TDebugController.SelectedWatchText(Value: Boolean): string;
begin
  Result := '';
  if (FWatches = nil) or (FWatches.Selected = nil) then Exit;
  if Value then
    FWatchTexts.Value(FWatches.Selected, Result)
  else
    Result := FWatches.Selected.Text;
end;

{ every watch: group|expression|enabled|data breakpoint set|address:size; - the group shown first }
function TDebugController.WatchDebugText: string;
var
  G, I: Integer;
  W: TWatchItem;
begin
  Result := IntToStr(FGroup) + '|';
  for G := 0 to FGroups.Count - 1 do
    for I := 0 to GroupList(G).Count - 1 do
    begin
      W := TWatchItem(GroupList(G)[I]);
      Result := Result + Format('%s|%s|%d|%d|$%x:%d;', [FGroups[G], W.Expr, Ord(W.Enabled), Ord(WatchBreaks(W)),
        W.Address, W.Size]);
    end;
end;

{ Delete and Insert as in Delphi's list; Space turns the watch's check box (enabled) }
procedure TDebugController.WatchesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  W: TWatchItem;
  N: TTreeNode;
begin
  if Key = VK_DELETE then
  begin
    DeleteSelectedWatch;
    Key := 0;
  end
  else if Key = VK_INSERT then
  begin
    AddWatch('');
    Key := 0;
  end
  else if (Key = VK_SPACE) and (FWatches.Selected <> nil) and (FWatches.Selected.Parent = nil) then
  begin
    N := FWatches.Selected;
    W := WatchOfNode(N);
    if W <> nil then SetWatchEnabled(N, not W.Enabled);
    Key := 0;
  end;
end;

{ a click on a watch's check box turns it on or off (the list view's check boxes of Delphi's); the
  right button selects the row under it first, as Delphi's list does - the menu's commands act on
  it (the VCL's RightClickSelect only pretends while the menu is open, and the command comes
  after) }
procedure TDebugController.WatchesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  N: TTreeNode;
  W: TWatchItem;
begin
  if Button = mbRight then
  begin
    N := FWatches.GetNodeAt(X, Y);
    if (N <> nil) and not N.Selected then FWatches.Select(N);
    Exit;
  end;
  if (Button <> mbLeft) or not FWatchView.IsCheckBox(X, Y) then Exit;
  N := FWatches.GetNodeAt(X, Y);
  if (N = nil) or (N.Parent <> nil) then Exit;
  W := WatchOfNode(N);
  if W <> nil then SetWatchEnabled(N, not W.Enabled);
end;

{ --- breakpoints --- }

function TDebugController.BreakpointCount: Integer;
begin
  Result := FDbg.BreakpointCount;
end;

function TDebugController.Breakpoint(Index: Integer): TDbgBreakpoint;
begin
  Result := FDbg.Breakpoints[Index];
end;

procedure TDebugController.ToggleBreakpoint(const FileName: string; Line: Integer);
var
  BP: TDbgBreakpoint;
begin
  BP := FDbg.FindBreakpoint(FileName, Line);
  if BP <> nil then
    FDbg.RemoveBreakpoint(BP)
  else
    FDbg.AddBreakpoint(FileName, Line);
  FillBreaks;
  if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
end;

const
  KindNames: array[TDbgBPKind] of string = ('Source', 'Address', 'Data', 'Module Load');

{ BP's dialog (Delphi's of its kind; Add Module for a module load breakpoint); KeyChanges False:
  where it is cannot be changed (the module of a module load breakpoint: nothing else to change) }
function TDebugController.BreakpointDialog(BP: TDbgBreakpoint; const ACaption: string; KeyChanges: Boolean): Boolean;
var
  Groups: TStringList;
  S: string;
begin
  if BP.Kind = bkModule then
  begin
    Result := False;
    if not KeyChanges then Exit;
    S := BP.FileName;
    Result := ModuleBreakpointDialog(FOwner, ACaption, S);
    if Result then BP.FileName := S;
    Exit;
  end;
  Groups := TStringList.Create;
  try
    GetGroups(Groups);
    Result := SdDialogs.BreakpointDialog(FOwner, ACaption, BP, Groups, FAddressFunc, KeyChanges);
  finally
    Groups.Free;
  end;
end;

function TDebugController.AddBreakpointDialog(Kind: TDbgBPKind; const FileName: string; Line: Integer): Boolean;
var
  S, Old: TDbgBreakpoint;
  Caption: string;
begin
  S := TDbgBreakpoint.Create;
  try
    S.Kind := Kind;
    if Kind = bkSource then
    begin
      S.FileName := FileName;
      S.Line := Line;
    end;
    if Kind = bkModule then Caption := '' else Caption := 'Add ' + KindNames[Kind] + ' Breakpoint';
    Result := BreakpointDialog(S, Caption);
    if not Result then Exit;
    Old := nil;
    if Kind = bkSource then Old := FDbg.FindBreakpoint(S.FileName, S.Line);
    // an existing breakpoint takes the settings (a disabled one gets its int 3 again)
    if Old <> nil then FDbg.ChangeBreakpointTo(Old, S) else FDbg.AddBreakpointAs(S);
    BreakpointsChanged;
  finally
    S.Free;
  end;
end;

function TDebugController.AddressBreakpointAt(Addr: Cardinal): TDbgBreakpoint;
var
  I: Integer;
begin
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    Result := FDbg.Breakpoints[I];
    if (Result.Kind = bkAddress) and (Result.Address = Addr) then Exit;
  end;
  Result := nil;
end;

procedure TDebugController.ToggleAddressBreakpoint(Addr: Cardinal);
var
  BP: TDbgBreakpoint;
begin
  if Addr = 0 then Exit;
  BP := AddressBreakpointAt(Addr);
  if BP <> nil then
    FDbg.RemoveBreakpoint(BP)
  else
  begin
    BP := TDbgBreakpoint.Create;
    try
      BP.Kind := bkAddress;
      BP.Address := Addr;
      FDbg.AddBreakpointAs(BP);
    finally
      BP.Free;
    end;
  end;
  BreakpointsChanged;
end;

function TDebugController.HasGroups: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FDbg.BreakpointCount - 1 do
    if FDbg.Breakpoints[I].Group <> '' then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TDebugController.GetGroups(L: TStrings);
var
  I: Integer;
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.Sorted := True;
    S.Duplicates := dupIgnore;
    for I := 0 to FDbg.BreakpointCount - 1 do
      if FDbg.Breakpoints[I].Group <> '' then S.Add(FDbg.Breakpoints[I].Group);
    L.Assign(S);
  finally
    S.Free;
  end;
end;

procedure TDebugController.EnableGroup(const Group: string; Value: Boolean);
var
  I: Integer;
  BP: TDbgBreakpoint;
begin
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    BP := FDbg.Breakpoints[I];
    if SameText(BP.Group, Group) and (BP.Enabled <> Value) then FDbg.SetBreakpointEnabled(BP, Value);
  end;
  BreakpointsChanged;
end;

function CompareBPLines(Item1, Item2: Pointer): Integer;
begin
  Result := TDbgBreakpoint(Item1).Line - TDbgBreakpoint(Item2).Line;
end;

{ Re-reads the breakpoint lines of one file from the editor markers (lines move while editing).
  Markers keep their order, the breakpoints are listed in the order they were set: each marker
  gets the breakpoint of the old line it belongs to - in line order, with the least total
  distance (where markers merged because lines between them were deleted, the breakpoint that
  was farther away goes). }
procedure TDebugController.RenameFileBreakpoints(const OldName, NewName: string);
var
  I: Integer;
  BP, S: TDbgBreakpoint;
begin
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    BP := FDbg.Breakpoints[I];
    if (BP.Kind <> bkSource) or not SameText(BP.FileName, OldName) then Continue;
    S := TDbgBreakpoint.Create;
    try
      S.Assign(BP);
      S.FileName := NewName;
      FDbg.ChangeBreakpointTo(BP, S);
    finally
      S.Free;
    end;
  end;
  FillBreaks;
end;

procedure TDebugController.SetFileBreakpoints(const FileName: string; Lines: TList);
const
  Inf = MaxInt div 2;
var
  Old: TList;
  A, B, Pair, D: array of Integer;
  NA, NB, W, I, J, K: Integer;
  OldShort: Boolean;

  procedure MoveTo(BP: TDbgBreakpoint; Line: Integer);
  begin
    if BP.Line = Line then Exit;
    FDbg.ChangeBreakpoint(BP, Line, BP.Enabled, BP.Condition, BP.PassCount);
  end;

begin
  Old := TList.Create;
  try
    for I := 0 to FDbg.BreakpointCount - 1 do
      if SameText(FDbg.Breakpoints[I].FileName, FileName) then Old.Add(FDbg.Breakpoints[I]);
    Old.Sort(CompareBPLines);
    // A: the shorter of the old lines and the marker lines - all of it is paired; B: the longer
    OldShort := Old.Count <= Lines.Count;
    if OldShort then NA := Old.Count else NA := Lines.Count;
    NB := Old.Count + Lines.Count - NA;
    SetLength(A, NA);
    SetLength(B, NB);
    for I := 0 to Old.Count - 1 do
      if OldShort then A[I] := TDbgBreakpoint(Old[I]).Line else B[I] := TDbgBreakpoint(Old[I]).Line;
    for I := 0 to Lines.Count - 1 do
      if OldShort then B[I] := Integer(Lines[I]) else A[I] := Integer(Lines[I]);
    // D[I * W + J]: least total distance pairing all of A[0..I-1] with some of B[0..J-1], in order
    W := NB + 1;
    SetLength(D, (NA + 1) * W);
    for J := 0 to NB do D[J] := 0;
    for I := 1 to NA do
    begin
      D[I * W] := Inf;
      for J := 1 to NB do
      begin
        D[I * W + J] := D[I * W + J - 1];        // B[J - 1] stays unpaired
        if D[(I - 1) * W + J - 1] < Inf then
        begin
          K := D[(I - 1) * W + J - 1] + Abs(A[I - 1] - B[J - 1]);
          if K < D[I * W + J] then D[I * W + J] := K;
        end;
      end;
    end;
    // back from the end: Pair[J] = the A that B[J] got, -1 = none
    SetLength(Pair, NB);
    for J := 0 to NB - 1 do Pair[J] := -1;
    I := NA;
    J := NB;
    while I > 0 do
    begin
      if (D[(I - 1) * W + J - 1] < Inf) and
        (D[I * W + J] = D[(I - 1) * W + J - 1] + Abs(A[I - 1] - B[J - 1])) then
      begin
        Pair[J - 1] := I - 1;
        Dec(I);
      end;
      Dec(J);
    end;
    for J := 0 to NB - 1 do
      if OldShort then
      begin
        // B are the markers: one without a breakpoint gets a new one
        if Pair[J] >= 0 then MoveTo(TDbgBreakpoint(Old[Pair[J]]), B[J])
        else FDbg.AddBreakpoint(FileName, B[J]);
      end
      else if Pair[J] >= 0 then
        MoveTo(TDbgBreakpoint(Old[J]), A[Pair[J]])
      else
        FDbg.RemoveBreakpoint(TDbgBreakpoint(Old[J]));    // its marker merged into another
  finally
    Old.Free;
  end;
  FillBreaks;
end;

{ the Action column: what a hit does }
function ActionText(BP: TDbgBreakpoint): string;

  procedure Add(const S: string);
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + S;
  end;

begin
  Result := '';
  if BP.DoBreak then Add('Break');
  if BP.IgnoreExceptions then Add('Ignore subsequent exceptions');
  if BP.HandleExceptions then Add('Handle subsequent exceptions');
  if BP.LogMessage <> '' then Add('Log message');
  if BP.EvalExpr <> '' then Add('Eval expression');
  if BP.EnableGroup <> '' then Add('Enable group ' + BP.EnableGroup);
  if BP.DisableGroup <> '' then Add('Disable group ' + BP.DisableGroup);
end;

{ Delphi's columns: Filename/Address, Line/Length, Condition, Action, Pass Count, Group }
procedure TDebugController.FillBreaks;
var
  I, Top: Integer;
  BP: TDbgBreakpoint;
  It: TListItem;
  S: string;
  Sel: Pointer;
begin
  if FBreaks = nil then Exit;
  { the chosen breakpoint and the first row in view, kept through the refill }
  Sel := nil;
  if FBreaks.Selected <> nil then Sel := FBreaks.Selected.Data;
  Top := -1;
  if FBreaks.TopItem <> nil then Top := FBreaks.TopItem.Index;
  FUpdatingBreaks := True;
  FBreaks.Items.BeginUpdate;
  try
    FBreaks.Items.Clear;
    for I := 0 to FDbg.BreakpointCount - 1 do
    begin
      BP := FDbg.Breakpoints[I];
      It := FBreaks.Items.Add;
      S := '';
      case BP.Kind of
        bkSource:
          begin
            It.Caption := ExtractFileName(BP.FileName);
            S := IntToStr(BP.Line);
          end;
        bkAddress: It.Caption := Format('$%.8x', [BP.Address]);
        bkData:
          begin
            It.Caption := Format('$%.8x', [BP.Address]);
            S := IntToStr(BP.DataLength);
          end;
      else
        It.Caption := BP.FileName;
      end;
      It.SubItems.Add(S);
      It.SubItems.Add(BP.Condition);
      It.SubItems.Add(ActionText(BP));
      It.SubItems.Add(IntToStr(BP.PassCount));
      It.SubItems.Add(BP.Group);
      It.Checked := BP.Enabled;
      It.Data := BP;
      if (Sel <> nil) and (BP = Sel) then UIChooseItem(It, False);
    end;
  finally
    FBreaks.Items.EndUpdate;
    { the list where it was: the last row in view first, then the first one at the top }
    if (Top > 0) and (Top < FBreaks.Items.Count) then
    begin
      FBreaks.Items[FBreaks.Items.Count - 1].MakeVisible(False);
      FBreaks.Items[Top].MakeVisible(False);
    end;
    FUpdatingBreaks := False;
  end;
  WatchesBreakpointsChanged;
end;

{ a watch whose data breakpoint is set is red (Break When Changed): the Watch List again, without
  an erase }
procedure TDebugController.WatchesBreakpointsChanged;
begin
  if (FWatches <> nil) and FWatches.HandleAllocated then InvalidateRect(FWatches.Handle, nil, False);
end;

{ the Breakpoint List's View / Edit Source: the line of a source breakpoint, of an address
  breakpoint the line its address belongs to }
procedure TDebugController.ShowBreakpointSource;
var
  BP: TDbgBreakpoint;
  F: string;
  L: Integer;
  Exact: Boolean;
begin
  if FBreaks.Selected = nil then Exit;
  BP := TDbgBreakpoint(FBreaks.Selected.Data);
  if not Assigned(FOnLocation) then Exit;
  if BP.Kind = bkSource then FOnLocation(BP.FileName, BP.Line)
  else if (BP.Kind = bkAddress) and FDbg.SourceLineAt(BP.Address, F, L, Exact) then FOnLocation(F, L);
end;

procedure TDebugController.BreaksChange(Sender: TObject; Item: TListItem; Change: TItemChange);
var
  BP: TDbgBreakpoint;
begin
  if FUpdatingBreaks or (Item = nil) or (Item.Data = nil) or (Change <> ctState) then Exit;
  BP := TDbgBreakpoint(Item.Data);
  if BP.Enabled <> Item.Checked then
  begin
    FDbg.SetBreakpointEnabled(BP, Item.Checked);
    WatchesBreakpointsChanged;
    if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
  end;
end;

procedure TDebugController.BreaksKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if SelectedBreakpoint = nil then Exit;
  if Key = VK_DELETE then
  begin
    DeleteSelectedBreakpoint;
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    EditSelectedBreakpoint;
    Key := 0;
  end;
end;

procedure TDebugController.BreakpointsChanged;
begin
  FillBreaks;
  if Assigned(FOnBreakpointsChanged) then FOnBreakpointsChanged(Self);
end;

function TDebugController.SelectedBreakpoint: TDbgBreakpoint;
begin
  Result := nil;
  if (FBreaks <> nil) and (FBreaks.Selected <> nil) then Result := TDbgBreakpoint(FBreaks.Selected.Data);
end;

procedure TDebugController.DeleteSelectedBreakpoint;
begin
  if SelectedBreakpoint = nil then Exit;
  FDbg.RemoveBreakpoint(SelectedBreakpoint);
  BreakpointsChanged;
end;

procedure TDebugController.EditSelectedBreakpoint;
begin
  if SelectedBreakpoint <> nil then EditBreakpoint(SelectedBreakpoint, True);
end;

function TDebugController.EditBreakpoint(BP: TDbgBreakpoint; KeyChanges: Boolean): Boolean;
var
  S: TDbgBreakpoint;
begin
  Result := False;
  if BP = nil then Exit;
  if Assigned(FOnEditBreakpoint) and FOnEditBreakpoint(BP, KeyChanges) then Exit;
  S := TDbgBreakpoint.Create;
  try
    S.Assign(BP);
    Result := BreakpointDialog(S, KindNames[BP.Kind] + ' Breakpoint Properties', KeyChanges);
    if Result then
    begin
      FDbg.ChangeBreakpointTo(BP, S);
      BreakpointsChanged;
    end;
  finally
    S.Free;
  end;
end;

procedure TDebugController.ToggleSelectedBreakpoint;
var
  BP: TDbgBreakpoint;
begin
  BP := SelectedBreakpoint;
  if BP = nil then Exit;
  FDbg.SetBreakpointEnabled(BP, not BP.Enabled);
  BreakpointsChanged;
end;

procedure TDebugController.EnableAllBreakpoints(Value: Boolean);
var
  I: Integer;
  BP: TDbgBreakpoint;
begin
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    BP := FDbg.Breakpoints[I];
    if BP.Enabled <> Value then FDbg.SetBreakpointEnabled(BP, Value);
  end;
  BreakpointsChanged;
end;

procedure TDebugController.DeleteAllBreakpoints;
begin
  while FDbg.BreakpointCount > 0 do FDbg.RemoveBreakpoint(FDbg.Breakpoints[0]);
  BreakpointsChanged;
end;

{ One line per breakpoint: "#2," and its settings as comma text - kind, file or module, line,
  address, length, enabled, pass count, condition, group, break, ignore and handle exceptions, log
  message, eval expression, log result, enable and disable group, the watch of a data breakpoint
  that Break When Changed set (a line without it is read as well). Earlier versions wrote source
  breakpoints as "file|line|enabled|pass count|condition" (or without the pass count): still read. }
const
  BPFormat = '#2';
  BPFields = 18;

procedure TDebugController.SaveBreakpoints(Ini: TStrings);
var
  I: Integer;
  BP: TDbgBreakpoint;
  F: TStringList;
begin
  Ini.Clear;
  F := TStringList.Create;
  try
    for I := 0 to FDbg.BreakpointCount - 1 do
    begin
      BP := FDbg.Breakpoints[I];
      F.Clear;
      F.Add(BPFormat);
      F.Add(IntToStr(Ord(BP.Kind)));
      F.Add(BP.FileName);
      F.Add(IntToStr(BP.Line));
      F.Add(IntToStr(BP.Address));
      F.Add(IntToStr(BP.DataLength));
      F.Add(IntToStr(Ord(BP.Enabled)));
      F.Add(IntToStr(BP.PassCount));
      F.Add(BP.Condition);
      F.Add(BP.Group);
      F.Add(IntToStr(Ord(BP.DoBreak)));
      F.Add(IntToStr(Ord(BP.IgnoreExceptions)));
      F.Add(IntToStr(Ord(BP.HandleExceptions)));
      F.Add(BP.LogMessage);
      F.Add(BP.EvalExpr);
      F.Add(IntToStr(Ord(BP.LogResult)));
      F.Add(BP.EnableGroup);
      F.Add(BP.DisableGroup);
      F.Add(BP.Watch);
      Ini.Add(F.CommaText);
    end;
  finally
    F.Free;
  end;
end;

{ a line of the current format into Settings; False: not one, or a breakpoint that is gone (the
  file of a source breakpoint no longer exists) }
function ReadBreakpoint(const S: string; Settings: TDbgBreakpoint): Boolean;
var
  F: TStringList;
  K: Integer;
begin
  Result := False;
  if Copy(S, 1, Length(BPFormat) + 1) <> BPFormat + ',' then Exit;
  F := TStringList.Create;
  try
    F.CommaText := S;
    if F.Count < BPFields then Exit;
    K := StrToIntDef(F[1], -1);
    if (K < Ord(Low(TDbgBPKind))) or (K > Ord(High(TDbgBPKind))) then Exit;
    Settings.Kind := TDbgBPKind(K);
    Settings.FileName := F[2];
    Settings.Line := StrToIntDef(F[3], 0);
    Settings.Address := Cardinal(StrToInt64Def(F[4], 0));
    Settings.DataLength := StrToIntDef(F[5], 4);
    Settings.Enabled := F[6] <> '0';
    Settings.PassCount := StrToIntDef(F[7], 0);
    Settings.Condition := F[8];
    Settings.Group := F[9];
    Settings.DoBreak := F[10] <> '0';
    Settings.IgnoreExceptions := F[11] = '1';
    Settings.HandleExceptions := F[12] = '1';
    Settings.LogMessage := F[13];
    Settings.EvalExpr := F[14];
    Settings.LogResult := F[15] = '1';
    Settings.EnableGroup := F[16];
    Settings.DisableGroup := F[17];
    if F.Count > BPFields then Settings.Watch := F[BPFields] else Settings.Watch := '';
    Result := (Settings.Kind <> bkSource) or ((Settings.Line > 0) and FileExistsU(Settings.FileName));
  finally
    F.Free;
  end;
end;

procedure TDebugController.LoadBreakpoints(Ini: TStrings);
begin
  FDbg.ClearBreakpoints;
  ReadBreakpoints(Ini);
end;

procedure TDebugController.AddBreakpoints(Ini: TStrings);
begin
  ReadBreakpoints(Ini);
end;

{ a breakpoint of the place of Settings is there already: the same kind and file and line (a
  source breakpoint), module (a module load breakpoint) or address }
function TDebugController.HasBreakpointAt(Settings: TDbgBreakpoint): Boolean;
var
  I: Integer;
  BP: TDbgBreakpoint;
begin
  Result := True;
  for I := 0 to FDbg.BreakpointCount - 1 do
  begin
    BP := FDbg.Breakpoints[I];
    if BP.Kind <> Settings.Kind then Continue;
    case BP.Kind of
      bkSource: if (BP.Line = Settings.Line) and SameText(BP.FileName, Settings.FileName) then Exit;
      bkModule: if SameText(BP.FileName, Settings.FileName) then Exit;
    else
      if BP.Address = Settings.Address then Exit;
    end;
  end;
  Result := False;
end;

{ the breakpoints of Ini added to the engine's; a place that has one already is skipped }
procedure TDebugController.ReadBreakpoints(Ini: TStrings);
var
  I, P, L, N: Integer;
  S, F, Rest: string;
  BP, Tmpl: TDbgBreakpoint;
  En: Boolean;
begin
  Tmpl := TDbgBreakpoint.Create;
  try
  for I := 0 to Ini.Count - 1 do
  begin
    S := Ini[I];
    if Copy(S, 1, Length(BPFormat) + 1) = BPFormat + ',' then
    begin
      if ReadBreakpoint(S, Tmpl) and not HasBreakpointAt(Tmpl) then FDbg.AddBreakpointAs(Tmpl);
      Continue;
    end;
    P := Pos('|', S);
    if P = 0 then Continue;
    F := Copy(S, 1, P - 1);
    Rest := Copy(S, P + 1, MaxInt);
    P := Pos('|', Rest);
    if P = 0 then Continue;
    L := StrToIntDef(Copy(Rest, 1, P - 1), 0);
    Rest := Copy(Rest, P + 1, MaxInt);
    // the breakpoints of files that are gone are dropped
    if (L <= 0) or not FileExistsU(F) or (FDbg.FindBreakpoint(F, L) <> nil) then Continue;
    BP := FDbg.AddBreakpoint(F, L);
    P := Pos('|', Rest);
    if P > 0 then
    begin
      En := Copy(Rest, 1, P - 1) <> '0';
      Rest := Copy(Rest, P + 1, MaxInt);
      P := Pos('|', Rest);
      N := -1;
      if P > 0 then N := StrToIntDef(Copy(Rest, 1, P - 1), -1);
      if N >= 0 then Rest := Copy(Rest, P + 1, MaxInt) else N := BP.PassCount;
      FDbg.ChangeBreakpoint(BP, BP.Line, En, Rest, N);
    end;
  end;
  finally
    Tmpl.Free;
  end;
  FillBreaks;
end;

{ --- evaluation --- }

function TDebugController.EvalValue(const Expr: string; var Value: string): Boolean;
var
  V: TDbgVar;
  Err: string;
begin
  Result := False;
  if not Paused or (Trim(Expr) = '') then Exit;
  Result := FDbg.Evaluate(Expr, V, Err);
  if Result then Value := V.Value;
end;

function TDebugController.TipValue(const Expr: string; out V: TDbgVar): Boolean;
var
  Err: string;
begin
  Result := Paused and (Trim(Expr) <> '') and FDbg.Evaluate(Expr, V, Err, False);
end;

function TDebugController.TipChildren(const Expr: string; out Vars: TDbgVarArray): Boolean;
begin
  Vars := nil;
  Result := Paused and FDbg.GetChildren(Expr, Vars);
end;

procedure TDebugController.EvalModified(Sender: TObject);
begin
  RefreshViews;
end;

function TDebugController.ModifyValue(const Expr, Value: string; out Error: string): Boolean;
begin
  { the Debug Inspector's rows: read with calls (TDebugger.Inspect) }
  Result := Paused and FDbg.Modify(Expr, Value, Error, True);
  if Result then RefreshViews;
end;

procedure TDebugController.EvaluateDialog(const InitialExpr: string);
begin
  TEvalDlg.Execute(FOwner, FDbg, InitialExpr, EvalModified);
end;

end.
