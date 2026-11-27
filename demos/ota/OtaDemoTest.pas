{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTest;

{ The self-test of D7 Studio's Open Tools API demo (OTA Demo | Run self-test): the services of
  BorlandIDEServices used the way Delphi 7's experts use them, and every result checked.

  It works in a folder of its own - the environment variable OTADEMO_SELFTEST_DIR, else
  %TEMP%\OtaDemoSelfTest: it closes every file and project (the IDE asks about unsaved changes),
  makes a project there with the API's creators and runs its checks on that project. Each check
  is a line "PASS <area>.<step>: <what>" or "FAIL <area>.<step>: <what> - <why>" in the message
  group "OTA Self-Test" and, when OTADEMO_SELFTEST_LOG names a file, in that file
  (a test script sets both and reads the file). The last line is
  "DONE <n> passed, <m> failed". With OTADEMO_SELFTEST_LOG set the test asks nothing; with
  OTADEMO_SELFTEST_START set it starts by itself once the IDE is up (for a script that runs it in Delphi
  7, whose menus a script cannot reach).

  It runs in Delphi 7's own IDE as well as in D7 Studio, with the same checks: what Delphi 7's
  experts can see is expected to be the same in both. A check of D7 Studio's own windows and
  commands is a line "SKIP <area>.<step>: <what>" in Delphi 7 (D7StudioOnly), and the last line
  then counts them too.

  The areas (the OtaDemoTest* units) register themselves with an order; their steps run one
  after the other from a timer, so that the IDE handles its messages between them (idle-time
  updates, the debugger's events). A step that has to wait for the IDE - a compile, a stop of the
  debugged program - names a condition (WaitFor): the next step runs once it holds, or after a
  FAIL when its time is up. }

interface

uses
  Windows, SysUtils, Classes, ExtCtrls, Forms, ActnList, ToolsAPI;

type
  TOtaTest = class;
  TOtaTestStep = procedure of object;
  TOtaWaitFunc = function: Boolean of object;

  { an area of the test: its steps, and what they keep between them (notifiers, file names) }
  TOtaTestArea = class
  private
    FTest: TOtaTest;
    FPauseEnd: Cardinal;
    function PauseOver: Boolean;
  protected
    { a step of the area: the steps of all areas run in the areas' order, then in the order added }
    procedure Step(const Name: string; Proc: TOtaTestStep);
    { a check: PASS or FAIL with What (and Why when it failed); the result is OK }
    function Check(OK: Boolean; const What: string; const Why: string = ''): Boolean;
    function Expect(const What, Got, Want: string): Boolean;
    function ExpectInt(const What: string; Got, Want: Integer): Boolean;
    { the next step runs once Cond holds; after Seconds a FAIL "What - timed out" }
    procedure WaitFor(Cond: TOtaWaitFunc; const What: string; Seconds: Integer = 30);
    { the next step runs after Ms milliseconds of the IDE's messages (no check) }
    procedure Pause(Ms: Cardinal);
    procedure Note(const Text: string);        // a line that is not a check
    { a check of D7 Studio's own windows or commands: True in D7 Studio; in Delphi 7's IDE a line
      "SKIP <area>.<step>: What" and False }
    function D7StudioOnly(const What: string): Boolean;
    { the IDE's box whose message has Text is expected in this step (Delphi 7 asks so on an API
      call): answered with Answer, not a failure; BoxSeen: one came }
    procedure ExpectBox(const Text: string; Answer: Integer);
    function BoxSeen(const Text: string): Boolean;
    { the step drives a Windows dialog of the IDE itself (File | Open): the watchdog leaves those }
    procedure OwnDialogs(Value: Boolean);
    function Dir: string;                       // the test's folder, with a backslash
  public
    constructor Create(ATest: TOtaTest); virtual;
    function Name: string; virtual; abstract;
    procedure AddSteps; virtual; abstract;
    { the test ends (or the package goes): the area removes what it registered }
    procedure Cleanup; virtual;
    property Test: TOtaTest read FTest;
  end;
  TOtaTestAreaClass = class of TOtaTestArea;

  { an IDE notifier that keeps what it is told, a line each (Events); an area's descendant says what
    its FileNotification keeps }
  TOtaEventNotifier = class(TNotifierObject, IOTANotifier, IOTAIDENotifier)
  public
    Events: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean); virtual; abstract;
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
    procedure AfterCompile(Succeeded: Boolean);
  end;

  TOtaTestStepRec = record
    Area: TOtaTestArea;
    Name: string;
    Proc: TOtaTestStep;
  end;

  TOtaTest = class
  private
    FAreas: TList;
    FSteps: array of TOtaTestStepRec;
    FCount: Integer;
    FIndex: Integer;
    FTimer: TTimer;
    FGroup: IOTAMessageGroup;
    FLogFile: string;
    FDir: string;
    FValues: TStringList;
    FPassed, FFailed, FSkipped: Integer;
    FCurrent: string;
    FWait: TOtaWaitFunc;
    FWaitWhat: string;
    FWaitEnd: Cardinal;
    FDone: Boolean;
    FOldException: TExceptionEvent;
    FCatching: Boolean;
    FWatchdog: TTimer;
    FBoxes: TStringList;          // the boxes the step expects: their text, the answer (Objects); seen: in FSeen
    FSeen: TStringList;
    FOwnDialogs: Boolean;
    function ExpectedBox(const Text: string; var Answer: Integer): Boolean;
    procedure Tick(Sender: TObject);
    procedure AppException(Sender: TObject; E: Exception);
    procedure WatchdogTick(Sender: TObject);
    procedure BoxTold(const Text: string; Expected, Dialog: Boolean);
    procedure Line(const Text: string);
    procedure Report(OK: Boolean; const What, Why: string);
    procedure Skip(const What: string);
    procedure AddStep(Area: TOtaTestArea; const Name: string; Proc: TOtaTestStep);
    procedure Finish;
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    function GetUnattended: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    property Dir: string read FDir;
    property Done: Boolean read FDone;
    property Unattended: Boolean read GetUnattended;   // started by a script: asks nothing
    { values the areas share: 'Project', 'Unit', 'Form' ... (file names, names) }
    property Values[const Name: string]: string read GetValue write SetValue;
  end;

procedure RegisterTestArea(AClass: TOtaTestAreaClass; Order: Integer);
procedure RunSelfTest;
procedure StopSelfTest;              // the package goes: a test that runs stops
{ OTADEMO_SELFTEST_START set: the test starts by itself once the IDE is up }
procedure StartSelfTestWhenReady;

{ helpers the areas share }
function IdeIsDelphi7: Boolean;      // the IDE is Delphi 7's own (delphi32.exe), not D7 Studio
{ a value that differs between the IDEs on purpose: Delphi 7's, else D7
  Studio's }
function IdeValue(InDelphi7, InD7Studio: Integer): Integer;
function IdeText(const InDelphi7, InD7Studio: string): string;
function EnvVar(const Name: string): string;
function TempFolder: string;
function SameModule(const A, B: IUnknown): Boolean;   // one object behind two references
function EditorText(const E: IOTASourceEditor): string;  // the whole buffer, through a reader
function LineWith(const Text, Marker: string): Integer;  // 1-based line of Marker, 0: none
function SourceEditorOf(const M: IOTAModule): IOTASourceEditor;
function FormEditorOf(const M: IOTAModule): IOTAFormEditor;
{ the window of the code editor that shows FileName (open, the edit window's file shown): the
  control Editor of Delphi's edit window (INTAEditWindow.Form of the file's view) - a TEditControl
  in Delphi 7's IDE and in D7 Studio; 0: none }
function EditorControlOf(const FileName: string): HWND;
{ a key as the keyboard gives it: posted to the window (WM_KEYDOWN, with Alt WM_SYSKEYDOWN) and
  taken by the IDE's message loop - the VCL hands it to the control (CN_KEYDOWN), the menus'
  shortcuts, the window, TranslateMessage makes its character -; Ctrl, Shift, Alt and the key
  itself down in the thread's key state meanwhile }
procedure PostKey(Wnd: HWND; Code: Word; Shift: TShiftState);
{ the IDE's message loop runs for Ms milliseconds, once at least: it takes what was posted (a
  playback of the keyboard services goes on through it) }
procedure Pump(Ms: Cardinal = 0);
{ the IDE's action of the name (INTAServices.ActionList: Delphi's FileOpenCommand ...); nil: none }
function IdeAction(const Name: string): TContainedAction;

implementation

uses
  Messages, Dialogs, Controls, Menus, StdCtrls;

const
  GroupName = 'OTA Self-Test';

{$I OtaTestBoxes.inc}

type
  { the start by itself: once the form of the IDE's main menu is shown, and three seconds more for
    what the IDE does then (its desktop, the project it opens); after a minute all the same }
  TAutoStart = class
  private
    FTimer: TTimer;
    FTicks, FReady: Integer;
    procedure Tick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  AreaClasses: TStringList;        // the registered areas, sorted by their order
  Running: TOtaTest;
  AutoStart: TAutoStart;

function IdeIsDelphi7: Boolean;
begin
  Result := SameText(ExtractFileName(GetModuleName(0)), 'delphi32.exe');
end;

function IdeText(const InDelphi7, InD7Studio: string): string;
begin
  if IdeIsDelphi7 then Result := InDelphi7 else Result := InD7Studio;
end;

function IdeValue(InDelphi7, InD7Studio: Integer): Integer;
begin
  if IdeIsDelphi7 then Result := InDelphi7 else Result := InD7Studio;
end;

function EnvVar(const Name: string): string;
var
  Buf: array[0..2047] of Char;
  N: DWORD;
begin
  N := Windows.GetEnvironmentVariable(PChar(Name), Buf, SizeOf(Buf));
  if (N > 0) and (N < SizeOf(Buf)) then SetString(Result, Buf, N) else Result := '';
end;

function TempFolder: string;
var
  Buf: array[0..MAX_PATH] of Char;
begin
  SetString(Result, Buf, GetTempPath(SizeOf(Buf), Buf));
  Result := IncludeTrailingPathDelimiter(Result);
end;

function SameModule(const A, B: IUnknown): Boolean;
var
  UA, UB: IUnknown;
begin
  Result := False;
  if (A = nil) or (B = nil) then Exit;
  A.QueryInterface(IUnknown, UA);
  B.QueryInterface(IUnknown, UB);
  Result := Pointer(UA) = Pointer(UB);
end;

function EditorText(const E: IOTASourceEditor): string;
var
  R: IOTAEditReader;
  Buf: array[0..4095] of Char;
  N, Pos: Integer;
  Part: string;
begin
  Result := '';
  if E = nil then Exit;
  R := E.CreateReader;
  Pos := 0;
  repeat
    N := R.GetText(Pos, Buf, SizeOf(Buf));
    SetString(Part, Buf, N);
    Result := Result + Part;
    Inc(Pos, N);
  until N < SizeOf(Buf);
end;

function LineWith(const Text, Marker: string): Integer;
var
  L: TStringList;
  I: Integer;
begin
  Result := 0;
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
      if Pos(Marker, L[I]) > 0 then
      begin
        Result := I + 1;
        Exit;
      end;
  finally
    L.Free;
  end;
end;

function SourceEditorOf(const M: IOTAModule): IOTASourceEditor;
var
  I: Integer;
begin
  Result := nil;
  if M = nil then Exit;
  for I := 0 to M.ModuleFileCount - 1 do
    if Supports(M.ModuleFileEditors[I], IOTASourceEditor, Result) then Exit;
end;

function FormEditorOf(const M: IOTAModule): IOTAFormEditor;
var
  I: Integer;
begin
  Result := nil;
  if M = nil then Exit;
  for I := 0 to M.ModuleFileCount - 1 do
    if Supports(M.ModuleFileEditors[I], IOTAFormEditor, Result) then Exit;
end;

function EditorControlOf(const FileName: string): HWND;
var
  E: IOTASourceEditor;
  W: INTAEditWindow;
  C: TComponent;
begin
  Result := 0;
  E := SourceEditorOf((BorlandIDEServices as IOTAModuleServices).FindModule(FileName));
  if (E = nil) or (E.EditViewCount = 0) then Exit;
  W := E.EditViews[0].GetEditWindow;
  if (W = nil) or (W.Form = nil) then Exit;
  C := W.Form.FindComponent('Editor');
  if C is TWinControl then Result := TWinControl(C).Handle;
end;

procedure PostKey(Wnd: HWND; Code: Word; Shift: TShiftState);
var
  Old, KS: TKeyboardState;
begin
  if Wnd = 0 then Exit;
  GetKeyboardState(Old);
  KS := Old;
  if ssCtrl in Shift then KS[VK_CONTROL] := $80 else KS[VK_CONTROL] := 0;
  if ssShift in Shift then KS[VK_SHIFT] := $80 else KS[VK_SHIFT] := 0;
  if ssAlt in Shift then KS[VK_MENU] := $80 else KS[VK_MENU] := 0;
  KS[Code] := $80;
  SetKeyboardState(KS);
  try
    if ssAlt in Shift then PostMessage(Wnd, WM_SYSKEYDOWN, Code, 1 or $20000000)
    else PostMessage(Wnd, WM_KEYDOWN, Code, 1);
    Pump;
  finally
    SetKeyboardState(Old);
  end;
end;

function IdeAction(const Name: string): TContainedAction;
var
  I: Integer;
  List: TCustomActionList;
begin
  Result := nil;
  List := (BorlandIDEServices as INTAServices).ActionList;
  for I := 0 to List.ActionCount - 1 do
    if SameText(List.Actions[I].Name, Name) then
    begin
      Result := List.Actions[I];
      Exit;
    end;
end;

procedure Pump(Ms: Cardinal);
var
  T: Cardinal;
begin
  T := GetTickCount + Ms;
  repeat
    Application.ProcessMessages;
    if Ms > 0 then Sleep(10);
  until GetTickCount >= T;
end;

{ a line at the end of a file, written at once: a script reads the file while the test runs }
procedure AppendToFile(const FileName, Text: string);
var
  F: TFileStream;
  S: string;
begin
  if FileExists(FileName) then F := TFileStream.Create(FileName, fmOpenWrite or fmShareDenyNone)
  else F := TFileStream.Create(FileName, fmCreate);
  try
    F.Seek(0, soFromEnd);
    S := Text + #13#10;
    F.WriteBuffer(S[1], Length(S));
  finally
    F.Free;
  end;
end;

procedure RegisterTestArea(AClass: TOtaTestAreaClass; Order: Integer);
begin
  if AreaClasses = nil then
  begin
    AreaClasses := TStringList.Create;
    AreaClasses.Sorted := True;
    AreaClasses.Duplicates := dupAccept;
  end;
  AreaClasses.AddObject(Format('%.5d %s', [Order, AClass.ClassName]), TObject(AClass));
end;

procedure RunSelfTest;
begin
  if (Running <> nil) and not Running.Done then
  begin
    if EnvVar('OTADEMO_SELFTEST_LOG') = '' then
      MessageDlg('The OTA Demo self-test runs already.', mtInformation, [mbOK], 0);
    Exit;
  end;
  FreeAndNil(Running);
  Running := TOtaTest.Create;
  if not Running.Start then FreeAndNil(Running);
end;

procedure StartSelfTestWhenReady;
begin
  if (EnvVar('OTADEMO_SELFTEST_START') <> '') and (AutoStart = nil) then AutoStart := TAutoStart.Create;
end;

{ ---------------------------------------------------------------- TAutoStart }

constructor TAutoStart.Create;
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 1000;
  FTimer.OnTimer := Tick;
end;

destructor TAutoStart.Destroy;
begin
  FTimer.Free;
  inherited;
end;

procedure TAutoStart.Tick(Sender: TObject);
var
  Menu: TMainMenu;
begin
  Inc(FTicks);
  Menu := nil;
  try
    Menu := (BorlandIDEServices as INTAServices).MainMenu;
  except
  end;
  if (Menu <> nil) and (Menu.Owner is TCustomForm) and TCustomForm(Menu.Owner).Visible then Inc(FReady);
  if (FReady < 4) and (FTicks < 60) then Exit;
  FTimer.Enabled := False;
  RunSelfTest;
end;

procedure StopSelfTest;
begin
  if Running = nil then Exit;
  Running.Stop;
  FreeAndNil(Running);
end;

{ ---------------------------------------------------------------- TOtaTestArea }

constructor TOtaTestArea.Create(ATest: TOtaTest);
begin
  inherited Create;
  FTest := ATest;
end;

procedure TOtaTestArea.Cleanup;
begin
end;

procedure TOtaTestArea.Step(const Name: string; Proc: TOtaTestStep);
begin
  FTest.AddStep(Self, Name, Proc);
end;

function TOtaTestArea.Check(OK: Boolean; const What, Why: string): Boolean;
begin
  FTest.Report(OK, What, Why);
  Result := OK;
end;

function TOtaTestArea.Expect(const What, Got, Want: string): Boolean;
begin
  Result := Check(Got = Want, What, Format('got "%s", expected "%s"', [Got, Want]));
end;

function TOtaTestArea.ExpectInt(const What: string; Got, Want: Integer): Boolean;
begin
  Result := Check(Got = Want, What, Format('got %d, expected %d', [Got, Want]));
end;

procedure TOtaTestArea.WaitFor(Cond: TOtaWaitFunc; const What: string; Seconds: Integer);
begin
  FTest.FWait := Cond;
  FTest.FWaitWhat := What;
  FTest.FWaitEnd := GetTickCount + Cardinal(Seconds) * 1000;
end;

function TOtaTestArea.PauseOver: Boolean;
begin
  Result := GetTickCount >= FPauseEnd;
end;

procedure TOtaTestArea.Pause(Ms: Cardinal);
begin
  FPauseEnd := GetTickCount + Ms;
  WaitFor(PauseOver, 'a pause', (Ms div 1000) + 30);
end;

procedure TOtaTestArea.Note(const Text: string);
begin
  FTest.Line('     ' + FTest.FCurrent + ': ' + Text);
end;

function TOtaTestArea.D7StudioOnly(const What: string): Boolean;
begin
  Result := not IdeIsDelphi7;
  if not Result then FTest.Skip(What);
end;

procedure TOtaTestArea.ExpectBox(const Text: string; Answer: Integer);
begin
  FTest.FBoxes.AddObject(Text, TObject(Answer));
end;

function TOtaTestArea.BoxSeen(const Text: string): Boolean;
begin
  Result := FTest.FSeen.IndexOf(Text) >= 0;
end;

procedure TOtaTestArea.OwnDialogs(Value: Boolean);
begin
  FTest.FOwnDialogs := Value;
end;

{ a box the step expects: the text of one of ExpectBox's is in its message - seen now }
function TOtaTest.ExpectedBox(const Text: string; var Answer: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to FBoxes.Count - 1 do
    if Pos(FBoxes[I], Text) > 0 then
    begin
      Answer := Integer(FBoxes.Objects[I]);
      if FSeen.IndexOf(FBoxes[I]) < 0 then FSeen.Add(FBoxes[I]);
      Result := True;
      Exit;
    end;
  Result := False;
end;

function TOtaTestArea.Dir: string;
begin
  Result := FTest.Dir;
end;

{ ---------------------------------------------------------------- TOtaTest }

constructor TOtaTest.Create;
begin
  inherited Create;
  FAreas := TList.Create;
  FValues := TStringList.Create;
  FBoxes := TStringList.Create;
  FSeen := TStringList.Create;
end;

destructor TOtaTest.Destroy;
var
  I: Integer;
begin
  FWatchdog.Free;
  FTimer.Free;
  FBoxes.Free;
  FSeen.Free;
  for I := FAreas.Count - 1 downto 0 do TObject(FAreas[I]).Free;
  FAreas.Free;
  FValues.Free;
  inherited;
end;

function TOtaTest.GetUnattended: Boolean;
begin
  Result := FLogFile <> '';
end;

function TOtaTest.GetValue(const Name: string): string;
begin
  Result := FValues.Values[Name];
end;

procedure TOtaTest.SetValue(const Name, Value: string);
begin
  FValues.Values[Name] := Value;
end;

procedure TOtaTest.AddStep(Area: TOtaTestArea; const Name: string; Proc: TOtaTestStep);
begin
  if FCount = Length(FSteps) then SetLength(FSteps, FCount * 2 + 16);
  FSteps[FCount].Area := Area;
  FSteps[FCount].Name := Name;
  FSteps[FCount].Proc := Proc;
  Inc(FCount);
end;

procedure TOtaTest.Line(const Text: string);
var
  Ref: Pointer;
begin
  if FGroup <> nil then
    (BorlandIDEServices as IOTAMessageServices).AddToolMessage('', Text, 'Self-Test', 0, 0, nil,
      Ref, FGroup);
  if FLogFile <> '' then
    try
      AppendToFile(FLogFile, Text);
    except
    end;
end;

procedure TOtaTest.Report(OK: Boolean; const What, Why: string);
begin
  if OK then
  begin
    Inc(FPassed);
    Line('PASS ' + FCurrent + ': ' + What);
  end
  else
  begin
    Inc(FFailed);
    if Why <> '' then Line('FAIL ' + FCurrent + ': ' + What + ' - ' + Why)
    else Line('FAIL ' + FCurrent + ': ' + What);
  end;
end;

procedure TOtaTest.Skip(const What: string);
begin
  Inc(FSkipped);
  Line('SKIP ' + FCurrent + ': ' + What);
end;

procedure TOtaTest.AppException(Sender: TObject; E: Exception);
begin
  Report(False, 'an exception of the IDE', E.ClassName + ': ' + StringReplace(E.Message, #13#10, ' | ', [rfReplaceAll]));
end;

{ ---------------------------------------------------------------- TOtaEventNotifier }

constructor TOtaEventNotifier.Create;
begin
  inherited Create;
  Events := TStringList.Create;
end;

destructor TOtaEventNotifier.Destroy;
begin
  Events.Free;
  inherited Destroy;
end;

procedure TOtaEventNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
end;

procedure TOtaEventNotifier.AfterCompile(Succeeded: Boolean);
begin
end;

{ a box answered as the step expected (a line of the log), or one no step expects (a failure) }
procedure TOtaTest.BoxTold(const Text: string; Expected, Dialog: Boolean);
begin
  if Expected then Line('     ' + FCurrent + ': answered ' + Text)
  else if Dialog then Report(False, 'a dialog of the IDE', Text)
  else Report(False, 'a message of the IDE', Text);
end;

{ started by a script: the IDE's boxes answered (OtaTestBoxes.inc), its Windows dialogs not while
  the step drives them itself }
procedure TOtaTest.WatchdogTick(Sender: TObject);
begin
  AnswerBoxes(ExpectedBox, BoxTold, not FOwnDialogs);
end;
function TOtaTest.Start: Boolean;
var
  I: Integer;
  A: TOtaTestArea;
  Msgs: IOTAMessageServices;
  Only: TStringList;
begin
  Result := False;
  FLogFile := EnvVar('OTADEMO_SELFTEST_LOG');
  FDir := EnvVar('OTADEMO_SELFTEST_DIR');
  if FDir = '' then FDir := TempFolder + 'OtaDemoSelfTest';
  FDir := IncludeTrailingPathDelimiter(FDir);
  if not Unattended and (MessageDlg('The self-test closes every open file and project (unsaved ' +
    'changes are asked about), then makes a test project in'#13#10 + FDir + #13#10'and checks ' +
    'the Open Tools API on it. Run it?', mtConfirmation, [mbOK, mbCancel], 0) <> mrOK) then Exit;
  if FLogFile <> '' then DeleteFile(FLogFile);
  Msgs := BorlandIDEServices as IOTAMessageServices;
  FGroup := Msgs.GetGroup(GroupName);
  if FGroup = nil then FGroup := Msgs.AddMessageGroup(GroupName)
  else Msgs.ClearMessageGroup(FGroup);
  Msgs.ShowMessageView(FGroup);
  Line('START ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ', folder ' + FDir);
  { started by a script, an exception the IDE would show in a box - which waits for OK - is a
    failure of the step that runs }
  if Unattended then
  begin
    FOldException := Application.OnException;
    Application.OnException := AppException;
    FCatching := True;
    FWatchdog := NewBoxWatchdog(WatchdogTick);
  end;
  { OTADEMO_SELFTEST_ONLY: these areas alone (names, separated by commas) - and Setup, which makes
    the test project }
  Only := TStringList.Create;
  try
    Only.CommaText := EnvVar('OTADEMO_SELFTEST_ONLY');
    if AreaClasses <> nil then
      for I := 0 to AreaClasses.Count - 1 do
      begin
        A := TOtaTestAreaClass(AreaClasses.Objects[I]).Create(Self);
        if (Only.Count > 0) and (Only.IndexOf(A.Name) < 0) and not SameText(A.Name, 'Setup') then
        begin
          A.Free;
          Continue;
        end;
        FAreas.Add(A);
        FCurrent := A.Name;
        A.AddSteps;
      end;
  finally
    Only.Free;
  end;
  FCurrent := '';
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 30;
  FTimer.OnTimer := Tick;
  FTimer.Enabled := True;
  Result := True;
end;

procedure TOtaTest.Tick(Sender: TObject);
var
  S: TOtaTestStepRec;
  Ready: Boolean;
begin
  FTimer.Enabled := False;
  try
    if Assigned(FWait) then
    begin
      try
        Ready := FWait;
      except
        on E: Exception do
        begin
          Report(False, FWaitWhat, E.ClassName + ': ' + E.Message);
          FWait := nil;
          Exit;
        end;
      end;
      if not Ready then
      begin
        if GetTickCount < FWaitEnd then Exit;
        Report(False, FWaitWhat, 'timed out');
      end;
      FWait := nil;
      Exit;                       // the step after it in the next tick
    end;
    if FIndex >= FCount then
    begin
      Finish;
      Exit;
    end;
    S := FSteps[FIndex];
    Inc(FIndex);
    FCurrent := S.Area.Name + '.' + S.Name;
    FBoxes.Clear;
    FSeen.Clear;
    FOwnDialogs := False;
    try
      S.Proc;
    except
      on E: Exception do Report(False, 'the step ran', E.ClassName + ': ' + E.Message);
    end;
  finally
    if not FDone then FTimer.Enabled := True;
  end;
end;

procedure TOtaTest.Finish;
var
  I: Integer;
begin
  FDone := True;
  if FCatching then
  begin
    Application.OnException := FOldException;
    FCatching := False;
  end;
  if FWatchdog <> nil then FWatchdog.Enabled := False;
  for I := FAreas.Count - 1 downto 0 do
  begin
    FCurrent := TOtaTestArea(FAreas[I]).Name + '.cleanup';
    try
      TOtaTestArea(FAreas[I]).Cleanup;
    except
      on E: Exception do Report(False, 'the cleanup ran', E.ClassName + ': ' + E.Message);
    end;
  end;
  if FSkipped > 0 then Line(Format('DONE %d passed, %d failed, %d skipped', [FPassed, FFailed, FSkipped]))
  else Line(Format('DONE %d passed, %d failed', [FPassed, FFailed]));
end;

procedure TOtaTest.Stop;
begin
  if FTimer <> nil then FTimer.Enabled := False;
  if not FDone then
  begin
    Line('STOPPED: the package was unloaded');
    Finish;
  end;
  if FGroup <> nil then
    try
      (BorlandIDEServices as IOTAMessageServices).RemoveMessageGroup(FGroup);
    except
    end;
  FGroup := nil;
end;

initialization

finalization
  FreeAndNil(AutoStart);
  StopSelfTest;
  FreeAndNil(AreaClasses);
end.
