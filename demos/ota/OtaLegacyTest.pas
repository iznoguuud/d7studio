{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaLegacyTest;

{ The self-test of D7 Studio's Delphi 1-3 expert API (OTA Legacy | Run self-test): ToolServices,
  the menu interfaces, the creators, the module, editor, view, reader and writer interfaces, the
  module and add-in notifiers, the project's resources, the file systems - used the way experts of
  Delphi 2 and 3 used them, every result checked. OTA Legacy | Check services checks what File |
  New's Service Application and Service of Borland's dclstd70 (experts of this API) made.

  It works in a folder of its own - the environment variable OTALEGACY_SELFTEST_DIR, else
  %TEMP%\OtaLegacySelfTest - and closes the project and the files first. Each check is a line
  "PASS <step>: <what>" or "FAIL <step>: <what> - <why>" in the message group "OTA Legacy" and,
  when OTALEGACY_SELFTEST_LOG names a file, in that file (a test script sets both and reads
  the file); the last line is "DONE <n> passed, <m> failed" (Check services: "SERVICES DONE ...").
  With OTALEGACY_SELFTEST_LOG set the test asks nothing. The steps run one after the other from a
  timer, so that the IDE handles its messages between them. }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

interface

{ Services False: the self-test; True: the check of the service application }
procedure RunLegacyTest(Services: Boolean);
procedure StopLegacyTest;            // the package goes: a test that runs stops
function LegacyUnattended: Boolean;  // started by a script: nothing is asked

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Menus, ExtCtrls, StdCtrls, Dialogs, ActiveX, TypInfo, ToolsAPI, VirtIntf,
  ExptIntf, ToolIntf, EditIntf, FileIntf, OtaLegacyExperts;

{$I OtaTestBoxes.inc}

type
  TStepProc = procedure of object;
  TWaitFunc = function: Boolean of object;

  { a module notifier of the test: the codes it heard }
  TTestModuleNotifier = class(TIModuleNotifier)
  public
    Codes: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Notify(NotifyCode: TNotifyCode); override;
    procedure ComponentRenamed(const AComponent: TComponent; const OldName, NewName: string); override;
  end;

  { a file system of the test (FileIntf): nothing to read, its name to find it by }
  TTestFileSystem = class(TIVirtualFileSystem)
  public
    function GetFileStream(const FileName: TFileName; Mode: Integer): IStream; override;
    function FileAge(const FileName: TFileName): Longint; override;
    function RenameFile(const OldName, NewName: TFileName): Boolean; override;
    function IsReadonly(const FileName: TFileName): Boolean; override;
    function IsFileBased: Boolean; override;
    function DeleteFile(const FileName: TFileName): Boolean; override;
    function FileExists(const FileName: TFileName): Boolean; override;
    function GetTempFileName(const FileName: TFileName): TFileName; override;
    function GetBackupFileName(const FileName: TFileName): TFileName; override;
    function GetIDString: string; override;
  end;

  { an expert of the registration checks: a name and an ID of the test's choice }
  TTestExpert = class(TIExpert)
  private
    FName, FID: string;
  public
    constructor Create(const AName, AID: string);
    function GetName: string; override;
    function GetAuthor: string; override;
    function GetComment: string; override;
    function GetPage: string; override;
    function GetGlyph: HICON; override;
    function GetStyle: TExpertStyle; override;
    function GetState: TExpertState; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

  { a menu wizard of the Open Tools API: its Help item goes below the experts' }
  TTestMenuWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  public
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    function GetMenuText: string;
  end;

  TLegacyTest = class
  private
    FSteps: array of record Name: string; Proc: TStepProc; end;
    FIndex: Integer;
    FTimer: TTimer;
    FWatchdog: TTimer;                // started by a script: the IDE's message boxes answered
    FAnswered: TStringList;           // ... their texts, 'caption: message'
    FLogFile: string;
    FDir: string;
    FPassed, FFailed: Integer;
    FCurrent: string;
    FServices: Boolean;
    FDone: Boolean;
    FGroup: IOTAMessageGroup;
    FWait: TWaitFunc;
    FWaitWhat: string;
    FWaitEnd: Cardinal;
    FProject, FUnit, FDfm, FExe: string;
    FModule: TIModuleInterface;       // the unit's, kept from Units to Close
    FNotes: TTestModuleNotifier;
    FTempClicks: Integer;
    FTempSender: TIMenuItemIntf;
    FCreator: TLegacyProjectCreator;
    procedure Step(const Name: string; Proc: TStepProc);
    function Check(OK: Boolean; const What: string; const Why: string = ''): Boolean;
    function Expect(const What, Got, Want: string): Boolean;
    function ExpectInt(const What: string; Got, Want: Integer): Boolean;
    procedure Line(const Text: string);
    procedure Tick(Sender: TObject);
    procedure WatchdogTick(Sender: TObject);
    function ExpectedBox(const Text: string; var Answer: Integer): Boolean;
    procedure BoxTold(const Text: string; Expected, Dialog: Boolean);
    function BoxAnswered(const Part: string): Boolean;
    procedure Finish;
    function Heard(const Event: string): Boolean;
    procedure TempClick(Sender: TIMenuItemIntf);
    { the self-test }
    procedure Setup;
    procedure Tools;
    procedure Strings;
    procedure MainMenu;
    procedure HelpMenu;
    procedure NewProject;
    procedure Units;
    procedure Editor;
    procedure View;
    procedure SaveModule;
    procedure Resources;
    procedure Streams;
    procedure FileSystems;
    procedure Compile;
    procedure CompileCancelled;
    procedure CloseModule;
    procedure Registration;
    procedure Teardown;
    procedure Vcs;
    procedure Orphan;
    { Check services }
    procedure ServiceProject;
    procedure ServiceUnits;
    procedure ServiceCompile;
  public
    constructor Create(AServices: Boolean);
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    property Done: Boolean read FDone;
  end;

var
  Running: TLegacyTest;

function EnvVar(const Name: string): string;
var
  Buf: array[0..2047] of Char;
  N: DWORD;
begin
  N := Windows.GetEnvironmentVariable(PChar(Name), Buf, SizeOf(Buf));
  if (N > 0) and (N < SizeOf(Buf)) then SetString(Result, Buf, N) else Result := '';
end;

function LegacyUnattended: Boolean;
begin
  Result := EnvVar('OTALEGACY_SELFTEST_LOG') <> '';
end;

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

{ the whole buffer of an old editor interface, through its reader }
function EditorText(E: TIEditorInterface): string;
var
  R: TIEditReader;
  Buf: array[0..4095] of Char;
  N, P: Integer;
  Part: string;
begin
  Result := '';
  if E = nil then Exit;
  R := E.CreateReader;
  if R = nil then Exit;
  try
    P := 0;
    repeat
      N := R.GetText(P, Buf, SizeOf(Buf));
      if N <= 0 then Break;
      SetString(Part, Buf, N);
      Result := Result + Part;
      Inc(P, N);
    until N < SizeOf(Buf);
  finally
    R.Free;
  end;
end;

function ModuleText(M: TIModuleInterface): string;
var
  E: TIEditorInterface;
begin
  Result := '';
  if M = nil then Exit;
  E := M.GetEditorInterface;
  try
    Result := EditorText(E);
  finally
    if E <> nil then E.Free;
  end;
end;

function FindItem(Items: TMenuItem; const Name: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  if Items = nil then Exit;
  for I := 0 to Items.Count - 1 do
  begin
    if SameText(Items[I].Name, Name) then Result := Items[I]
    else Result := FindItem(Items[I], Name);
    if Result <> nil then Exit;
  end;
end;

function FileText(const FileName: string): string;
var
  F: TFileStream;
begin
  Result := '';
  if not FileExists(FileName) then Exit;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

{ ---------------------------------------------------------------- helpers of the steps }

constructor TTestModuleNotifier.Create;
begin
  inherited Create;
  Codes := TStringList.Create;
end;

destructor TTestModuleNotifier.Destroy;
begin
  Codes.Free;
  inherited;
end;

const
  NotifyCodes: array[TNotifyCode] of string = ('ncModuleDeleted', 'ncModuleRenamed', 'ncEditorModified',
    'ncFormModified', 'ncEditorSelected', 'ncFormSelected', 'ncBeforeSave', 'ncAfterSave', 'ncFormSaving',
    'ncProjResModified');

procedure TTestModuleNotifier.Notify(NotifyCode: TNotifyCode);
begin
  Codes.Add(NotifyCodes[NotifyCode]);
end;

procedure TTestModuleNotifier.ComponentRenamed(const AComponent: TComponent; const OldName, NewName: string);
begin
  Codes.Add('ComponentRenamed');
end;

const
  TestFSID = 'D7Studio.OtaLegacy.TestFS';

function TTestFileSystem.GetFileStream(const FileName: TFileName; Mode: Integer): IStream;
begin
  Result := nil;
end;

function TTestFileSystem.FileAge(const FileName: TFileName): Longint;
begin
  Result := -1;
end;

function TTestFileSystem.RenameFile(const OldName, NewName: TFileName): Boolean;
begin
  Result := False;
end;

function TTestFileSystem.IsReadonly(const FileName: TFileName): Boolean;
begin
  Result := True;
end;

function TTestFileSystem.IsFileBased: Boolean;
begin
  Result := False;
end;

function TTestFileSystem.DeleteFile(const FileName: TFileName): Boolean;
begin
  Result := False;
end;

function TTestFileSystem.FileExists(const FileName: TFileName): Boolean;
begin
  Result := SameText(FileName, 'legacy:readme');
end;

function TTestFileSystem.GetTempFileName(const FileName: TFileName): TFileName;
begin
  Result := FileName + '.tmp';
end;

function TTestFileSystem.GetBackupFileName(const FileName: TFileName): TFileName;
begin
  Result := FileName + '.bak';
end;

function TTestFileSystem.GetIDString: string;
begin
  Result := TestFSID;
end;

constructor TTestExpert.Create(const AName, AID: string);
begin
  inherited Create;
  FName := AName;
  FID := AID;
end;

function TTestExpert.GetName: string;
begin
  Result := FName;
end;

function TTestExpert.GetAuthor: string;
begin
  Result := '';
end;

function TTestExpert.GetComment: string;
begin
  Result := '';
end;

function TTestExpert.GetPage: string;
begin
  Result := '';
end;

function TTestExpert.GetGlyph: HICON;
begin
  Result := 0;
end;

function TTestExpert.GetStyle: TExpertStyle;
begin
  Result := esAddIn;
end;

function TTestExpert.GetState: TExpertState;
begin
  Result := [];
end;

function TTestExpert.GetIDString: string;
begin
  Result := FID;
end;

function TTestExpert.GetMenuText: string;
begin
  Result := '';
end;

procedure TTestExpert.Execute;
begin
end;

function TTestMenuWizard.GetIDString: string;
begin
  Result := 'D7Studio.OtaLegacy.SelfTest.MenuWizard';
end;

function TTestMenuWizard.GetName: string;
begin
  Result := 'OTA Legacy self-test menu wizard';
end;

function TTestMenuWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TTestMenuWizard.Execute;
begin
end;

function TTestMenuWizard.GetMenuText: string;
begin
  Result := 'OTA Legacy self-test wizard';
end;

{ ---------------------------------------------------------------- the test }

constructor TLegacyTest.Create(AServices: Boolean);
begin
  inherited Create;
  FServices := AServices;
end;

destructor TLegacyTest.Destroy;
begin
  FTimer.Free;
  FWatchdog.Free;
  FAnswered.Free;
  if FModule <> nil then FModule.Free;
  FModule := nil;
  FNotes.Free;
  inherited;
end;

procedure TLegacyTest.Step(const Name: string; Proc: TStepProc);
var
  N: Integer;
begin
  N := Length(FSteps);
  SetLength(FSteps, N + 1);
  FSteps[N].Name := Name;
  FSteps[N].Proc := Proc;
end;

procedure TLegacyTest.Line(const Text: string);
var
  Ref: Pointer;
begin
  if FGroup <> nil then
    (BorlandIDEServices as IOTAMessageServices).AddToolMessage('', Text, 'Legacy', 0, 0, nil, Ref, FGroup);
  if FLogFile <> '' then
    try
      AppendToFile(FLogFile, Text);
    except
    end;
end;

function TLegacyTest.Check(OK: Boolean; const What: string; const Why: string): Boolean;
begin
  if OK then
  begin
    Inc(FPassed);
    Line('PASS ' + FCurrent + ': ' + What);
  end
  else
  begin
    Inc(FFailed);
    if Why <> '' then Line('FAIL ' + FCurrent + ': ' + What + ' - ' + Why) else Line('FAIL ' + FCurrent + ': ' + What);
  end;
  Result := OK;
end;

function TLegacyTest.Expect(const What, Got, Want: string): Boolean;
begin
  Result := Check(Got = Want, What, Format('got "%s", expected "%s"', [Got, Want]));
end;

function TLegacyTest.ExpectInt(const What: string; Got, Want: Integer): Boolean;
begin
  Result := Check(Got = Want, What, Format('got %d, expected %d', [Got, Want]));
end;

function TLegacyTest.Heard(const Event: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to LegacyEvents.Count - 1 do
    if Pos(Event, LegacyEvents[I]) = 1 then
    begin
      Result := True;
      Exit;
    end;
end;

function TLegacyTest.Start: Boolean;
var
  Msgs: IOTAMessageServices;
begin
  Result := False;
  FLogFile := EnvVar('OTALEGACY_SELFTEST_LOG');
  FDir := EnvVar('OTALEGACY_SELFTEST_DIR');
  if FDir = '' then FDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'OtaLegacySelfTest';
  FDir := IncludeTrailingPathDelimiter(FDir);
  if not FServices and not LegacyUnattended and (MessageDlg('The self-test closes the project and every file ' +
    '(unsaved changes are asked about), then makes a test project in'#13#10 + FDir + #13#10'and checks Delphi ' +
    '1-3''s expert API on it. Run it?', mtConfirmation, [mbOK, mbCancel], 0) <> mrOK) then Exit;
  FAnswered := TStringList.Create;
  if LegacyUnattended then FWatchdog := NewBoxWatchdog(WatchdogTick);
  FProject := FDir + 'LegacyProject.dpr';
  FUnit := FDir + 'LegacyUnit.pas';
  FDfm := FDir + 'LegacyUnit.dfm';
  FExe := FDir + 'LegacyProject.exe';
  Msgs := BorlandIDEServices as IOTAMessageServices;
  FGroup := Msgs.GetGroup('OTA Legacy');
  if FGroup = nil then FGroup := Msgs.AddMessageGroup('OTA Legacy');
  Msgs.ShowMessageView(FGroup);
  if FServices then
  begin
    Line('SERVICES START ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Step('ServiceProject', ServiceProject);
    Step('ServiceUnits', ServiceUnits);
    Step('ServiceCompile', ServiceCompile);
  end
  else
  begin
    if FLogFile <> '' then DeleteFile(FLogFile);
    Line('START ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ', folder ' + FDir);
    Step('Setup', Setup);
    Step('Tools', Tools);
    Step('Strings', Strings);
    Step('MainMenu', MainMenu);
    Step('HelpMenu', HelpMenu);
    Step('NewProject', NewProject);
    Step('Units', Units);
    Step('Editor', Editor);
    Step('View', View);
    Step('SaveModule', SaveModule);
    Step('Resources', Resources);
    Step('Streams', Streams);
    Step('FileSystems', FileSystems);
    Step('Compile', Compile);
    Step('CompileCancelled', CompileCancelled);
    Step('CloseModule', CloseModule);
    Step('Registration', Registration);
    Step('Teardown', Teardown);
    Step('Vcs', Vcs);
    Step('Orphan', Orphan);
  end;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 30;
  FTimer.OnTimer := Tick;
  FTimer.Enabled := True;
  Result := True;
end;

procedure TLegacyTest.Tick(Sender: TObject);
var
  Ready: Boolean;
begin
  FTimer.Enabled := False;
  try
    if Assigned(FWait) then
    begin
      try
        Ready := FWait;
      except
        Ready := True;
      end;
      if not Ready then
      begin
        if GetTickCount < FWaitEnd then Exit;
        Check(False, FWaitWhat, 'timed out');
      end;
      FWait := nil;
      Exit;
    end;
    if FIndex >= Length(FSteps) then
    begin
      Finish;
      Exit;
    end;
    FCurrent := FSteps[FIndex].Name;
    Inc(FIndex);
    try
      FSteps[FIndex - 1].Proc;
    except
      on E: Exception do Check(False, 'the step ran', E.ClassName + ': ' + E.Message);
    end;
  finally
    if not FDone then FTimer.Enabled := True;
  end;
end;

{ Delphi 7's "Cannot find resource file ... Recreated." of a project made without its .res is
  answered OK; every box's text is kept (BoxAnswered) }
function TLegacyTest.ExpectedBox(const Text: string; var Answer: Integer): Boolean;
const
  ResBox = 'Error: Cannot find resource file: ';
begin
  FAnswered.Add(Text);
  Result := Copy(Text, 1, Length(ResBox)) = ResBox;
  if Result then Answer := mrOk;
end;

{ a box answered as expected (a line of the log), or one no step expects (a failure) }
procedure TLegacyTest.BoxTold(const Text: string; Expected, Dialog: Boolean);
begin
  if Expected then Line('     ' + FCurrent + ': answered ' + Text)
  else if Dialog then Check(False, 'a dialog of the IDE', Text)
  else Check(False, 'a message of the IDE', Text);
end;

{ started by a script: the IDE's boxes answered (OtaTestBoxes.inc) }
procedure TLegacyTest.WatchdogTick(Sender: TObject);
begin
  AnswerBoxes(ExpectedBox, BoxTold, True);
end;
{ a box with Part in its text was answered }
function TLegacyTest.BoxAnswered(const Part: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FAnswered.Count - 1 do
    if Pos(Part, FAnswered[I]) > 0 then Result := True;
end;

procedure TLegacyTest.Finish;
begin
  FDone := True;
  if FServices then Line(Format('SERVICES DONE %d passed, %d failed', [FPassed, FFailed]))
  else Line(Format('DONE %d passed, %d failed', [FPassed, FFailed]));
end;

procedure TLegacyTest.Stop;
begin
  if FTimer <> nil then FTimer.Enabled := False;
  if FWatchdog <> nil then FWatchdog.Enabled := False;
  if not FDone then
  begin
    Line('STOPPED: the package was unloaded');
    Finish;
  end;
end;

{ ---------------------------------------------------------------- the steps }

{ the folder emptied of the test's files; no project, no file open }
procedure TLegacyTest.Setup;
const
  Masks: array[0..13] of string = ('*.dpr', '*.pas', '*.dfm', '*.res', '*.dof', '*.cfg', '*.dsk',
    '*.exe', '*.dcu', '*.~*', '*.ddp', '*.map', '*.drc', '*.txt');
var
  I: Integer;
  SR: TSearchRec;
begin
  Check(ToolServices.CloseProject, 'ToolServices.CloseProject');
  Check((BorlandIDEServices as IOTAModuleServices).CloseAll, 'every file closed');
  ForceDirectories(FDir);
  for I := Low(Masks) to High(Masks) do
    if FindFirst(FDir + Masks[I], faAnyFile and not faDirectory, SR) = 0 then
    begin
      repeat
        DeleteFile(FDir + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  Check(not FileExists(FProject), 'no project of an earlier run is left');
  Expect('GetProjectName without a project', ToolServices.GetProjectName, '');
end;

procedure TLegacyTest.Tools;
var
  R: TRect;
  I, J: Integer;
  Found: Boolean;
  U, F, C: string;
begin
  Check(ToolServices <> nil, 'ExptIntf.ToolServices is there');
  ExpectInt('its GetVersion', ToolServices.GetVersion, 3);
  { an expert's stray Free must not end it }
  ToolServices.Free;
  Check(IsWindow(ToolServices.GetParentHandle), 'GetParentHandle after a Free of ToolServices');
  Check(Pos('\Software\', ToolServices.GetBaseRegistryKey) = 1, 'GetBaseRegistryKey is a key under \Software',
    ToolServices.GetBaseRegistryKey);
  Check(Pos('Borland', ToolServices.GetBaseRegistryKey) = 0, 'GetBaseRegistryKey is not Delphi''s key',
    ToolServices.GetBaseRegistryKey);
  R := ToolServices.GetFormBounds(btCustomModule);
  ExpectInt('GetFormBounds(btCustomModule) width', R.Right - R.Left, 215);
  R := ToolServices.GetFormBounds(btForm);
  Check(R.Right - R.Left > 215, 'GetFormBounds(btForm) is wider');
  Check(ToolServices.GetModuleCount > 0, 'GetModuleCount (the design packages)');
  Check(ToolServices.GetModuleName(0) <> '', 'GetModuleName(0)');
  Found := False;
  for I := 0 to ToolServices.GetModuleCount - 1 do
    for J := 0 to ToolServices.GetComponentCount(I) - 1 do
      if SameText(ToolServices.GetComponentName(I, J), 'TButton') then Found := True;
  Check(Found, 'a package of the library registered TButton (GetComponentName)');
  Check(ToolServices.GetNewModuleName(U, F) and (U <> '') and SameText(ExtractFileName(F), U + '.pas'),
    'GetNewModuleName', U + ' ' + F);
  Check(ToolServices.GetNewModuleAndClassName('Form', U, C, F) and (Copy(C, 1, 1) = 'T'),
    'GetNewModuleAndClassName', U + ' ' + C + ' ' + F);
  Check(AboutRuns < 1000, 'the add-in expert was never executed');
end;

function StrRefCount(P: Pointer): Integer;
begin
  if P = nil then Result := 0 else Result := PInteger(Integer(P) - 8)^;
end;

procedure TLegacyTest.Strings;
var
  P, Q, D, S: Pointer;
begin
  P := ToolServices.NewPascalString('legacy');
  Expect('NewPascalString', PString(@P)^, 'legacy');
  ExpectInt('... one reference', StrRefCount(P), 1);
  Q := P;
  ToolServices.ReferencePascalString(Q);
  ExpectInt('ReferencePascalString: two', StrRefCount(Q), 2);
  ToolServices.FreePascalString(P);
  Check(P = nil, 'FreePascalString clears the variable');
  Expect('... the other reference keeps it', PString(@Q)^, 'legacy');
  ToolServices.FreePascalString(Q);
  Check(ToolServices.NewPascalString('') = nil, 'NewPascalString('''') is nil');
  D := ToolServices.NewPascalString('one');
  S := ToolServices.NewPascalString('two');
  ToolServices.AssignPascalString(D, S);
  Expect('AssignPascalString', PString(@D)^, 'two');
  ExpectInt('... the source referenced twice', StrRefCount(S), 2);
  ToolServices.FreePascalString(D);
  ToolServices.FreePascalString(S);
  try
    ToolServices.RaiseException('OTA Legacy raises');
    Check(False, 'RaiseException raises');
  except
    on E: Exception do Expect('RaiseException raises its message', E.Message, 'OTA Legacy raises');
  end;
end;

procedure TLegacyTest.TempClick(Sender: TIMenuItemIntf);
begin
  Inc(FTempClicks);
  FTempSender := Sender;
end;

{ the main menu by Delphi 7's names; an item of the IDE is read only, the expert's own is its
  interface's }
procedure TLegacyTest.MainMenu;
var
  M: TIMainMenuIntf;
  T, P, PP, L, X, Y, Temp, Dup, LineItem: TIMenuItemIntf;
  It: TMenuItem;
  N: Integer;
begin
  M := ToolServices.GetMainMenu;
  if not Check(M <> nil, 'GetMainMenu') then Exit;
  try
    T := M.FindMenuItem('ToolsMenu');
    if not Check(T <> nil, 'FindMenuItem(''ToolsMenu'')') then Exit;
    try
      Expect('its name', T.GetName, 'ToolsMenu');
      Check(not T.SetCaption('Changed'), 'an item of the IDE cannot be changed');
      Check(mfEnabled in T.GetFlags, 'its flags');
      P := T.GetParent;
      Check(P <> nil, 'GetParent of a top-level item: the menu bar');
      if P <> nil then
      begin
        PP := P.GetParent;
        Check(PP = nil, 'the menu bar has no parent');
        Check(P.GetItemCount >= 10, 'the menu bar''s items');
        P.Free;
      end;
      L := M.FindMenuItem('OtaLegacyMenu');
      if Check(L <> nil, 'the add-in''s menu (InsertItem at the menu bar)') then
      try
        ExpectInt('... right before Tools', L.GetIndex, T.GetIndex - 1);
        ExpectInt('... its two items', L.GetItemCount, 2);
        X := M.FindMenuItem('OtaLegacyRun');
        Y := M.FindMenuItem('OtaLegacyRun');
        Check((X <> nil) and (X = Y), 'an item an expert made has one interface');
        if X <> nil then X.Free;
        if Y <> nil then Y.Free;
        Temp := L.InsertItem(-1, 'Legacy temp', 'OtaLegacyTemp', 'a hint', 0, 0, 0, [mfVisible, mfEnabled], TempClick);
        if Check(Temp <> nil, 'InsertItem') then
        begin
          Check(Temp.SetCaption('Legacy temporary'), 'SetCaption of an own item');
          Expect('GetCaption', Temp.GetCaption, 'Legacy temporary');
          Check(Temp.SetFlags([mfChecked], [mfChecked]) and (mfChecked in Temp.GetFlags), 'SetFlags(mfChecked)');
          Check(Temp.SetShortCut(ShortCut(Ord('L'), [ssCtrl, ssAlt])), 'SetShortCut');
          ExpectInt('GetShortCut', Temp.GetShortCut, ShortCut(Ord('L'), [ssCtrl, ssAlt]));
          Check(Temp.SetContext(4711) and (Temp.GetContext = 4711), 'SetContext / GetContext');
          It := FindItem((BorlandIDEServices as INTAServices).MainMenu.Items, 'OtaLegacyTemp');
          if Check(It <> nil, 'the menu item is in the main menu by its name') then
          begin
            It.Click;
            ExpectInt('its click calls the OnClick event', FTempClicks, 1);
            Check(FTempSender = Temp, '... with the item''s interface');
          end;
          N := L.GetItemCount;
          Dup := L.InsertItem(-1, 'Legacy duplicate', 'OtaLegacyTemp', '', 0, 0, 0, [mfVisible], nil);
          Check(Dup = nil, 'InsertItem with a name in use gives nil (logged)');
          if Dup <> nil then Dup.Free;
          ExpectInt('... and no item', L.GetItemCount, N);
          LineItem := L.InsertItem(-1, '-', '', '', 0, 0, 0, [mfVisible], nil);
          Check(LineItem <> nil, 'InsertItem of a line');
          ExpectInt('... one item more', L.GetItemCount, N + 1);
          if LineItem <> nil then LineItem.Free;
          ExpectInt('the creator''s Free takes the item away', L.GetItemCount, N);
          Check(Temp.DestroyMenuItem, 'DestroyMenuItem');
          X := M.FindMenuItem('OtaLegacyTemp');
          Check(X = nil, '... the item is gone');
          if X <> nil then X.Free;
          Check(mfInvalid in Temp.GetFlags, 'its interface says mfInvalid');
          Temp.Free;
        end;
      finally
        L.Free;
      end;
    finally
      T.Free;
    end;
  finally
    M.Free;
  end;
end;

{ the experts' items in the Help menu after Delphi 7's HelpProgGuideSeparater - the newest
  expert on top, the menu wizards below the experts; their captions asked again at each drop-down }
procedure TLegacyTest.HelpMenu;
var
  Help, Anchor, It, DllItem: TMenuItem;
  W: IOTAWizard;
  Index, I, Calls: Integer;
begin
  Help := FindItem((BorlandIDEServices as INTAServices).MainMenu.Items, 'HelpMenu');
  if not Check(Help <> nil, 'the Help menu') then Exit;
  Anchor := FindItem(Help, 'HelpProgGuideSeparater');
  if not Check(Anchor <> nil, 'Delphi 7''s HelpProgGuideSeparater') then Exit;
  Check(Anchor.Visible, '... shown while the menu has experts'' items');
  It := FindItem(Help, 'D7Studio_OtaLegacy_About');
  if not Check(It <> nil, 'the About expert''s item, named after its ID') then Exit;
  ExpectInt('... the newest expert right after the anchor', It.MenuIndex, Anchor.MenuIndex + 1);
  ExpectInt('... Delphi 7''s help context', It.HelpContext, 4520);
  DllItem := FindItem(Help, 'D7Studio_OtaLegacyDll');
  if DllItem <> nil then
    ExpectInt('the DLL''s expert (registered before) below it', DllItem.MenuIndex, It.MenuIndex + 1)
  else
    Line('     ' + FCurrent + ': the DLL expert is not loaded (OtaLegacyDll.dll in [Experts])');
  W := TTestMenuWizard.Create;
  Index := (BorlandIDEServices as IOTAWizardServices).AddWizard(W);
  if Check(Index >= 0, 'a menu wizard of the Open Tools API') then
  begin
    It := FindItem(Help, 'D7Studio_OtaLegacy_SelfTest_MenuWizard');
    if Check(It <> nil, '... its item') then
    begin
      if DllItem <> nil then
        ExpectInt('... below the experts', It.MenuIndex, Anchor.MenuIndex + 3)
      else
        ExpectInt('... below the experts', It.MenuIndex, Anchor.MenuIndex + 2);
    end;
    (BorlandIDEServices as IOTAWizardServices).RemoveWizard(Index);
    Check(FindItem(Help, 'D7Studio_OtaLegacy_SelfTest_MenuWizard') = nil, '... gone with RemoveWizard');
  end;
  { the Help menu drops down: every item's action is updated (TMenuItem.InitiateAction) }
  It := FindItem(Help, 'D7Studio_OtaLegacy_About');
  Calls := MenuTextCalls;
  for I := 0 to Help.Count - 1 do Help[I].InitiateAction;
  Check(MenuTextCalls > Calls, 'GetMenuText asked again when the menu drops down');
  Check(Pos(Format('(%d)', [MenuTextCalls]), It.Caption) > 0, '... the caption is its text', It.Caption);
  Calls := AboutRuns;
  It.Click;
  ExpectInt('the item runs the expert''s Execute', AboutRuns, Calls + 1);
end;

{ ToolServices.ProjectCreateEx with the demo's creator: the program, its option file, its form (the
  creator's NewDefaultModule makes it with ModuleCreate) }
procedure TLegacyTest.NewProject;
var
  M: TIModuleInterface;
begin
  LegacyEvents.Clear;
  FCreator := TLegacyProjectCreator.Create(FProject, 'LegacyUnit');
  try
    M := ToolServices.ProjectCreateEx(FCreator, [cpApplication, cpCanShowSource]);
    if not Check(M <> nil, 'ProjectCreateEx gives the project''s module interface') then Exit;
    try
      Check(M.IsProjectModule, 'IsProjectModule');
    finally
      M.Free;
    end;
    ExpectInt('the creator''s NewDefaultModule was called', FCreator.DefaultModules, 1);
    ExpectInt('... and NewProjectResource', FCreator.ResourceCalls, 1);
  finally
    FCreator.Free;
    FCreator := nil;
  end;
  Check(SameText(ToolServices.GetProjectName, FProject), 'GetProjectName', ToolServices.GetProjectName);
  if LegacyUnattended then
    Check(BoxAnswered('Cannot find resource file: ' + ChangeFileExt(FProject, '.res')),
      'the project made without its .res: Delphi 7''s "Cannot find resource file ... Recreated."');
  Check(FileExists(ChangeFileExt(FProject, '.dof')), 'the Ex creator''s option file was written');
  Check(Heard('file fnProjectOpening ' + FProject), 'the add-in heard fnProjectOpening');
  Check(Heard('file fnProjectOpened ' + FProject), '... fnProjectOpened');
  Check(Heard('file fnAddedToProject ' + FUnit), '... fnAddedToProject of the form''s unit');
  Check(ToolServices.IsFileOpen(FUnit), 'IsFileOpen of the unit');
  Check(not ToolServices.IsFileOpen(FDir + 'NotThere.pas'), 'IsFileOpen of a file that is not open');
end;

function CollectUnit(Param: Pointer; const FileName, UnitName, FormName: string): Boolean stdcall;
begin
  TStrings(Param).Add(ExtractFileName(FileName) + '|' + UnitName + '|' + FormName);
  Result := True;
end;

function CollectModule(Param: Pointer; const FileName, UnitName, FormName, DesignClass: string): Boolean stdcall;
begin
  TStrings(Param).Add(ExtractFileName(FileName) + '|' + UnitName + '|' + FormName);
  Result := True;
end;

procedure TLegacyTest.Units;
var
  L: TStringList;
  M2: TIModuleInterface;
begin
  ExpectInt('GetUnitCount: the source, .res, .dof and the unit', ToolServices.GetUnitCount, 4);
  Check(SameText(ToolServices.GetUnitName(0), FProject), 'GetUnitName(0) is the project source');
  Check(SameText(ToolServices.GetUnitName(3), FUnit), 'GetUnitName(3) is the unit', ToolServices.GetUnitName(3));
  ExpectInt('GetFormCount', ToolServices.GetFormCount, 1);
  Check(SameText(ToolServices.GetFormName(0), FDfm), 'GetFormName(0) is its form file', ToolServices.GetFormName(0));
  L := TStringList.Create;
  try
    Check(ToolServices.EnumProjectUnits(CollectUnit, L), 'EnumProjectUnits');
    Expect('... the project first', L[0], 'LegacyProject.dpr|LegacyProject|');
    Expect('... the unit with its form', L[L.Count - 1], 'LegacyUnit.pas|LegacyUnit|LegacyForm');
    L.Clear;
    Check(ToolServices.EnumProjectModules(CollectModule, L) and (L.Count = 4), 'EnumProjectModules');
    L.Clear;
    ToolServices.GetVcsList(L);
    Check(L.IndexOf(FDfm) >= 0, 'GetVcsList names the form file');
    ExpectInt('GetVcsCount', ToolServices.GetVcsCount, L.Count);
  finally
    L.Free;
  end;
  FModule := ToolServices.GetModuleInterface(FUnit);
  if not Check(FModule <> nil, 'GetModuleInterface of the unit') then Exit;
  M2 := ToolServices.GetModuleInterface(FUnit);
  Check(M2 = FModule, '... the same object again (one per module)');
  if M2 <> nil then M2.Free;
  M2 := ToolServices.GetModuleInterface(FDfm);
  Check(M2 = FModule, '... and for its form file');
  if M2 <> nil then M2.Free;
  M2 := ToolServices.GetFormModuleInterface('LegacyForm');
  Check(M2 = FModule, 'GetFormModuleInterface');
  if M2 <> nil then M2.Free;
  Check(FModule.GetFormInterface = nil, 'GetFormInterface is nil, as in Delphi 7');
  Check(not FModule.IsProjectModule, 'IsProjectModule of a unit');
  FNotes := TTestModuleNotifier.Create;
  Check(FModule.AddNotifier(FNotes), 'AddNotifier');
end;

procedure TLegacyTest.Editor;
var
  E: TIEditorInterface;
  W: TIEditWriter;
  T: string;
  P: Integer;
begin
  if FModule = nil then Exit;
  E := FModule.GetEditorInterface;
  if not Check(E <> nil, 'GetEditorInterface') then Exit;
  try
    Check(SameText(E.FileName, FUnit), 'its FileName', E.FileName);
    Check(E.LinesInBuffer > 10, 'LinesInBuffer');
    T := EditorText(E);
    Check(Pos('TLegacyForm = class(TForm)', T) > 0, 'the reader reads the creator''s source');
    Check(E.BufferModified, 'a new unit: modified, written when it is saved (Delphi 7''s)');
    P := Pos('implementation', T) - 1;
    FNotes.Codes.Clear;
    W := E.CreateUndoableWriter;
    if Check(W <> nil, 'CreateUndoableWriter') then
    try
      Check(W.CopyTo(P), 'CopyTo');
      ExpectInt('Position', W.Position, P);
      Check(W.Insert('{ inserted by OTA Legacy }'#13#10), 'Insert');
    finally
      W.Free;
    end;
    Check(Pos('{ inserted by OTA Legacy }', EditorText(E)) > 0, 'the text has the insertion');
    Check(E.BufferModified, 'BufferModified');
    Check(FNotes.Codes.IndexOf('ncEditorModified') >= 0, 'the module notifier heard ncEditorModified',
      FNotes.Codes.CommaText);
    Check(E.SetSyntaxHighlighter(shQuery) = shPascal, 'SetSyntaxHighlighter(shQuery): Pascal');
    Check(E.GetViewCount >= 1, 'GetViewCount');
  finally
    E.Free;
  end;
end;

procedure TLegacyTest.View;
var
  E: TIEditorInterface;
  V: TIEditView;
  P, P2: TEditPos;
  C: TCharPos;
  Off, Element, LineFlag: Integer;
  B: TCharPos;
begin
  if FModule = nil then Exit;
  E := FModule.GetEditorInterface;
  if E = nil then Exit;
  try
    V := E.GetView(0);
    if not Check(V <> nil, 'GetView(0)') then Exit;
    try
      P.Col := 3;
      P.Line := 5;
      V.SetPos(EditIntf.CursorPos, P);
      P2 := V.GetPos(EditIntf.CursorPos);
      Check((P2.Col = 3) and (P2.Line = 5), 'SetPos / GetPos(CursorPos)', Format('%d:%d', [P2.Line, P2.Col]));
      Check(V.GetPos(ViewTopPos).Line >= 1, 'GetPos(ViewTopPos)');
      Check(V.GetViewSize.cy > 0, 'GetViewSize');
      C.CharIndex := 2;
      C.Line := 1;
      Off := V.CharPosToPos(C);
      ExpectInt('CharPosToPos of line 1', Off, 2);
      C := V.PosToCharPos(Off);
      Check((C.Line = 1) and (C.CharIndex = 2), 'PosToCharPos back');
      P.Col := 1;
      P.Line := 1;
      V.GetAttributeAtPos(P, Element, LineFlag);
      ExpectInt('GetAttributeAtPos of "unit": a reserved word', Element, atReservedWord);
      { a block shown is the selection (no persistent blocks): the cursor at its end, as Delphi's }
      P.Col := 5;
      P.Line := 1;
      V.SetPos(EditIntf.CursorPos, P);
      B.CharIndex := 0;
      B.Line := 1;
      E.SetBlockStart(B);
      B.CharIndex := 4;
      E.SetBlockAfter(B);
      E.SetBlockVisible(True);
      ExpectInt('SetBlockStart / GetBlockStart', E.GetBlockStart.CharIndex, 0);
      ExpectInt('SetBlockAfter / GetBlockAfter', E.GetBlockAfter.CharIndex, 4);
      Check(not E.GetBlockVisible, 'GetBlockVisible: False without Persistent blocks (Delphi 7''s)');
      E.SetBlockVisible(False);
    finally
      V.Free;
    end;
  finally
    E.Free;
  end;
end;

procedure TLegacyTest.SaveModule;
begin
  if FModule = nil then Exit;
  FNotes.Codes.Clear;
  Check(FModule.Save(True), 'Save');
  Check(FNotes.Codes.IndexOf('ncBeforeSave') >= 0, 'ncBeforeSave', FNotes.Codes.CommaText);
  Check(FNotes.Codes.IndexOf('ncAfterSave') >= 0, 'ncAfterSave', FNotes.Codes.CommaText);
  Check(Pos('{ inserted by OTA Legacy }', FileText(FUnit)) > 0, 'the file on the disk has the insertion');
  Check(FModule.ShowSource, 'ShowSource');
  Check(FModule.ShowForm, 'ShowForm');
  Check(ToolServices.SaveProject, 'SaveProject');
  Check(FileExists(FDfm), 'the form file is on the disk');
end;

procedure TLegacyTest.Resources;
var
  P: TIModuleInterface;
  R: TIResourceFile;
  E: TIResourceEntry;
  N: Integer;
  H: Pointer;
  Data: string;
begin
  Data := 'LGCY';
  P := ToolServices.GetModuleInterface(FProject);
  if not Check(P <> nil, 'the project''s module interface') then Exit;
  try
    Check(P.IsProjectModule, 'IsProjectModule');
    R := P.GetProjectResource;
    if not Check(R <> nil, 'GetProjectResource') then Exit;
    try
      Check(SameText(R.FileName, ChangeFileExt(FProject, '.res')), 'its FileName', R.FileName);
      N := R.GetEntryCount;
      E := R.CreateEntry(RT_RCDATA, 'OTALEGACY', $1030, 0, 0, 0, 0);
      if Check(E <> nil, 'CreateEntry') then
      try
        Check(E.SetDataSize(4), 'SetDataSize');
        ExpectInt('GetDataSize', E.GetDataSize, 4);
        Move(Data[1], E.GetData^, 4);
        H := E.GetEntryHandle;
        ExpectInt('the entry is counted', R.GetEntryCount, N + 1);
        Check(R.FindEntry(RT_RCDATA, 'OTALEGACY') <> nil, 'FindEntry');
        Check(R.DeleteEntry(H), 'DeleteEntry');
        ExpectInt('... gone again', R.GetEntryCount, N);
      finally
        E.Free;
      end;
    finally
      R.Free;
    end;
    Check(FModule.GetProjectResource = nil, 'a unit has no project resource');
  finally
    P.Free;
  end;
end;

{ CreateModule from the streams an expert gives (IStream) }
procedure TLegacyTest.Streams;
const
  Src = 'unit LegacyStream;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'{ from a stream }'#13#10#13#10'end.'#13#10;
var
  S: TStringStream;
  M: TIModuleInterface;
  Name: string;
begin
  Name := FDir + 'LegacyStream.pas';
  LegacyEvents.Clear;
  S := TStringStream.Create(Src);
  Check(ToolServices.CreateModule(Name, TStreamAdapter.Create(S, soOwned), nil, [cmShowSource]),
    'CreateModule from a source stream');
  Check(ToolServices.IsFileOpen(Name), '... the file is open');
  M := ToolServices.GetModuleInterface(Name);
  if Check(M <> nil, '... its module interface') then
  try
    Check(Pos('{ from a stream }', ModuleText(M)) > 0, '... its text is the stream''s');
    { a new module is written when it is saved (Delphi 7's) }
    Check(not FileExists(Name), '... not written yet');
    Check(M.Save(True) and FileExists(Name), '... Save writes it');
  finally
    M.Free;
  end;
  Check(ToolServices.CloseFile(Name), 'CloseFile');
  Check(not ToolServices.IsFileOpen(Name), '... closed');
  Check(Heard('file fnFileClosing ' + Name), 'the add-in heard fnFileClosing');
  Check(ToolServices.OpenFile(Name), 'OpenFile');
  Check(Heard('file fnFileOpening ' + Name) and Heard('file fnFileOpened ' + Name), '... fnFileOpening and fnFileOpened');
  Check(ToolServices.CloseFile(Name), 'CloseFile again');
end;

procedure TLegacyTest.FileSystems;
var
  FS: TTestFileSystem;
  G: TIVirtualFileSystem;
begin
  FS := TTestFileSystem.Create;
  try
    Check(ToolServices.RegisterFileSystem(FS), 'RegisterFileSystem');
    Check((BorlandIDEServices as IOTAModuleServices).FindFileSystem(TestFSID) <> nil,
      '... the Open Tools API finds it');
    G := ToolServices.GetFileSystem(TestFSID);
    if Check(G <> nil, 'GetFileSystem') then
    try
      Expect('... its GetIDString', G.GetIDString, TestFSID);
      Check(G.FileExists('legacy:readme') and not G.IsFileBased, '... its methods are the expert''s');
    finally
      G.Free;
    end;
    Check(ToolServices.UnRegisterFileSystem(TestFSID), 'UnRegisterFileSystem');
    { FindFileSystem of an ID no file system has raises Delphi 7's exception }
    try
      (BorlandIDEServices as IOTAModuleServices).FindFileSystem(TestFSID);
      Check(False, '... gone: FindFileSystem raises');
    except
      on E: Exception do
        Check(Pos('Unable to locate file system', E.Message) > 0, '... gone: FindFileSystem raises', E.Message);
    end;
    Check(ToolServices.GetFileSystem(TestFSID) = nil, '... GetFileSystem: nil');
  finally
    { the IDE let go of its own reference: the test's is the last }
    FS.Free;
  end;
end;

procedure TLegacyTest.Compile;
var
  P: IOTAProject;
begin
  P := GetActiveProject;
  if not Check(P <> nil, 'the active project (Open Tools API)') then Exit;
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved');
  LegacyEvents.Clear;
  Check(P.ProjectBuilder.BuildProject(cmOTABuild, True, True), 'BuildProject');
  Check(FileExists(FExe), 'the program was made');
  Check(Heard('event enBeforeCompile 0'), 'AddNotifierEx''s notifier heard enBeforeCompile', LegacyEvents.CommaText);
  Check(Heard('event enAfterCompile 1'), '... enAfterCompile with Cancel = succeeded', LegacyEvents.CommaText);
end;

procedure TLegacyTest.CompileCancelled;
var
  P: IOTAProject;
  Ok: Boolean;
begin
  P := GetActiveProject;
  if (P = nil) or (Notifier = nil) then Exit;
  Notifier.CancelCompile := True;
  try
    Ok := P.ProjectBuilder.BuildProject(cmOTABuild, True, True);
  finally
    Notifier.CancelCompile := False;
  end;
  Check(not Ok, 'enBeforeCompile''s Cancel stops the compile');
end;

{ the module closes: its notifiers hear ncModuleDeleted, the interface answers nothing from then on }
procedure TLegacyTest.CloseModule;
var
  E: TIEditorInterface;
begin
  if FModule = nil then Exit;
  FNotes.Codes.Clear;
  Check(FModule.Close, 'Close');
  Check(FNotes.Codes.IndexOf('ncModuleDeleted') >= 0, 'ncModuleDeleted', FNotes.Codes.CommaText);
  Check(FNotes.Codes.IndexOf('ComponentRenamed') < 0, 'ComponentRenamed is never called (Delphi 7)');
  E := FModule.GetEditorInterface;
  Check(E = nil, 'the interface of a module that went answers nil');
  if E <> nil then E.Free;
  Check(FModule.RemoveNotifier(FNotes), 'RemoveNotifier');
  FModule.Free;
  FModule := nil;
end;

{ Delphi 7's rules: a name, an ID nobody has (logged; the package's Register would stop there) }
procedure TLegacyTest.Registration;
var
  X: TTestExpert;
begin
  X := TTestExpert.Create('', 'D7Studio.OtaLegacy.SelfTest.Unnamed');
  try
    RegisterLibraryExpert(X);
    Check(False, 'an expert without a name is refused');
  except
    on E: Exception do Expect('an expert without a name is refused', E.Message, 'Cannot register an unnamed Wizard');
  end;
  X.Free;
  X := TTestExpert.Create('OTA Legacy twin', AboutID);
  try
    RegisterLibraryExpert(X);
    Check(False, 'an ID that is registered is refused');
  except
    on E: Exception do
      Expect('an ID that is registered is refused', E.Message, 'Cannot register Wizard, ' + AboutID + ', twice');
  end;
  X.Free;
end;

procedure TLegacyTest.Teardown;
begin
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'everything saved');
  Check(ToolServices.CloseProject, 'CloseProject');
  Expect('no project', ToolServices.GetProjectName, '');
  Check(Heard('file fnProjectClosing ' + FProject), 'the add-in heard fnProjectClosing');
end;

{ the version control manager (OtaVcsDemo.dll, [Version Control] VCSManager): its menu before Tools,
  its verbs' captions and states asked when the menu drops down, ProjectChange heard for the
  projects this test opened and closed, a verb run }
procedure TLegacyTest.Vcs;
var
  Bar, Menu, Tools: TMenuItem;
  I, N: Integer;
  S, Log: string;
begin
  Bar := (BorlandIDEServices as INTAServices).MainMenu.Items;
  Menu := nil;
  for I := 0 to Bar.Count - 1 do
    if StripHotkey(Bar[I].Caption) = 'OTA VCS' then Menu := Bar[I];
  if Menu = nil then
  begin
    Line('     ' + FCurrent + ': no VCS manager (OtaVcsDemo.dll in [Version Control] VCSManager)');
    Exit;
  end;
  Tools := FindItem(Bar, 'ToolsMenu');
  Check((Tools <> nil) and (Menu.MenuIndex < Tools.MenuIndex), 'the VCS manager''s menu is before Tools');
  if not ExpectInt('its verbs', Menu.Count, 3) then Exit;
  for I := 0 to Menu.Count - 1 do Menu[I].InitiateAction;
  S := Menu[0].Caption;
  N := StrToIntDef(Copy(S, Length('Project changes: ') + 1, MaxInt), 0);
  Check((Pos('Project changes: ', S) = 1) and (N >= 2), 'the first verb''s caption asked again: ProjectChange heard', S);
  Check(Menu[1].IsLine, 'an empty verb is a line');
  Expect('the third verb', Menu[2].Caption, 'Log project files');
  Check(not Menu[2].Checked, '... not checked yet (GetVerbState)');
  Log := EnvVar('OTALEGACY_VCS_LOG');
  Menu[2].Click;
  if Log <> '' then
    Check(Pos('changes=', FileText(Log)) > 0, 'its ExecuteVerb ran', FileText(Log));
  Menu[2].InitiateAction;
  Check(Menu[2].Checked, '... checked now (GetVerbState: vsChecked)');
  DeleteFile(Log);
end;

{ an item of the Help menu the package leaves behind - its interface is never freed: when the
  package goes, the item stays and its OnClick (code of the package) is cleared (a test script
  unloads the package and checks it) }
procedure TLegacyTest.Orphan;
var
  M: TIMainMenuIntf;
  H, O: TIMenuItemIntf;
begin
  M := ToolServices.GetMainMenu;
  if M = nil then Exit;
  try
    H := M.FindMenuItem('HelpMenu');
    if not Check(H <> nil, 'FindMenuItem(''HelpMenu'')') then Exit;
    try
      O := H.InsertItem(-1, 'Legacy orphan', 'OtaLegacyOrphan', '', 0, 0, 0, [mfVisible, mfEnabled], TempClick);
      Check(O <> nil, 'an item the package leaves behind');
    finally
      H.Free;
    end;
  finally
    M.Free;
  end;
end;

{ ---------------------------------------------------------------- Check services }

{ what File | New | Service Application (dclstd70) made: a service program with its service }
procedure TLegacyTest.ServiceProject;
var
  M: TIModuleInterface;
  T: string;
begin
  Check(ToolServices.GetProjectName <> '', 'there is a project', ToolServices.GetProjectName);
  M := ToolServices.GetModuleInterface(ToolServices.GetProjectName);
  if not Check(M <> nil, 'its module interface') then Exit;
  try
    T := ModuleText(M);
    Check(Pos('SvcMgr', T) > 0, 'the project is a service application (SvcMgr)', T);
    Check(Pos('Application.CreateForm(TService1, Service1)', T) > 0, 'it creates its service', T);
  finally
    M.Free;
  end;
  Check(ToolServices.GetFormCount >= 2, 'File | New | Service added a second service',
    IntToStr(ToolServices.GetFormCount));
end;

procedure TLegacyTest.ServiceUnits;
var
  I, J, K: Integer;
  F, Dfm, S, Old, Names: string;
  M: TIModuleInterface;
  OM: IOTAModule;
  FE: IOTAFormEditor;
  Root: IOTAComponent;
  Done: Integer;
begin
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved');
  Done := 0;
  for I := 0 to ToolServices.GetFormCount - 1 do
  begin
    F := ChangeFileExt(ToolServices.GetFormName(I), '.pas');
    M := ToolServices.GetModuleInterface(F);
    if M = nil then Continue;
    try
      if Pos('= class(TService)', ModuleText(M)) = 0 then Continue;
      Inc(Done);
      Dfm := FileText(ToolServices.GetFormName(I));
      Check(Pos(': TService', Dfm) > 0, ExtractFileName(F) + ': the form file of a TService', Dfm);
      Check(Pos('DisplayName', Dfm) > 0, ExtractFileName(F) + ': streamed from a new TService (DisplayName)', Dfm);
      Check(Pos('Caption', Dfm) = 0, ExtractFileName(F) + ': no form''s properties', Dfm);
      { Delphi writes a TService root's published properties, then Left, Top, Height, Width }
      Check((Pos('OldCreateOrder', Dfm) > 0) and (Pos('OldCreateOrder', Dfm) < Pos('DisplayName', Dfm)) and
        (Pos('DisplayName', Dfm) < Pos('Left = ', Dfm)) and (Pos('Top = ', Dfm) < Pos('Height = ', Dfm)) and
        (Pos('Height = ', Dfm) < Pos('Width = ', Dfm)), ExtractFileName(F) + ': in Delphi''s order', Dfm);
      Check(M.ShowForm, ExtractFileName(F) + ': it opens in the designer');
      OM := (BorlandIDEServices as IOTAModuleServices).FindModule(F);
      FE := nil;
      if OM <> nil then
        for J := 0 to OM.GetModuleFileCount - 1 do
          if Supports(OM.GetModuleFileEditor(J), IOTAFormEditor, FE) then Break;
      if Check(FE <> nil, ExtractFileName(F) + ': its form editor') then
      begin
        Root := FE.GetRootComponent;
        Check(not Root.IsTControl, ExtractFileName(F) + ': designed as a data module (no control)');
        { the root's properties are its class's, TService's, as Delphi 7's IOTAComponent gives them }
        Names := ',';
        for K := 0 to Root.GetPropCount - 1 do Names := Names + Root.GetPropName(K) + ',';
        Check((Pos(',Name,', Names) > 0) and (Pos(',DisplayName,', Names) > 0) and (Pos(',StartType,', Names) > 0) and
          (Pos(',OnStart,', Names) > 0) and (Pos(',Caption,', Names) = 0) and (Pos(',Left,', Names) = 0),
          ExtractFileName(F) + ': IOTAComponent lists TService''s properties', Names);
        Check(Root.GetPropTypeByName('StartType') = tkEnumeration, ExtractFileName(F) + ': StartType is an enumeration');
        Old := '';
        Check(Root.GetPropValueByName('DisplayName', Old) and (Old <> ''), ExtractFileName(F) + ': DisplayName read', Old);
        S := 'OTA ' + ChangeFileExt(ExtractFileName(F), '');
        Check(Root.SetPropByName('DisplayName', S), ExtractFileName(F) + ': DisplayName set');
        S := '';
        Check(Root.GetPropValueByName('DisplayName', S) and (S = 'OTA ' + ChangeFileExt(ExtractFileName(F), '')),
          ExtractFileName(F) + ': DisplayName read back', S);
        Check(FE.GetModified, ExtractFileName(F) + ': the form is modified by the change');
        { the value the test script set through the Object Inspector comes back }
        Check(Root.SetPropByName('DisplayName', Old), ExtractFileName(F) + ': DisplayName set back');
      end;
    finally
      M.Free;
    end;
  end;
  Check(Done >= 2, 'two services (TService) in the project', IntToStr(Done));
end;

procedure TLegacyTest.ServiceCompile;
var
  P: IOTAProject;
  O: IOTAProjectOptions;
begin
  P := GetActiveProject;
  if not Check(P <> nil, 'the active project') then Exit;
  O := P.ProjectOptions;
  O.Values['UsePackages'] := True;
  O.Values['Packages'] := 'rtl;vcl';
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved');
  Check(P.ProjectBuilder.BuildProject(cmOTABuild, True, True), 'the service application compiles');
  Check(FileExists(ChangeFileExt(P.FileName, '.exe')), 'the program was made');
end;

{ ---------------------------------------------------------------- entry points }

procedure RunLegacyTest(Services: Boolean);
begin
  if (Running <> nil) and not Running.Done then
  begin
    if not LegacyUnattended then MessageDlg('The OTA Legacy self-test runs already.', mtInformation, [mbOK], 0);
    Exit;
  end;
  FreeAndNil(Running);
  Running := TLegacyTest.Create(Services);
  if not Running.Start then FreeAndNil(Running);
end;

procedure StopLegacyTest;
begin
  if Running = nil then Exit;
  Running.Stop;
  FreeAndNil(Running);
end;

initialization

finalization
  StopLegacyTest;
end.
