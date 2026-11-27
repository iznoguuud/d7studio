{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestIde;

{ The self-test's IDE areas (OtaDemoTest): the test project made with the API's creators (Setup),
  the IDE's services, the modules and their notifiers, the project, and the message groups.

  Setup closes everything and makes OtaSelfTest.dpr in the test's folder with an
  IOTAProjectCreator; its default module, TestUnit with the form TestForm, comes from an
  IOTAModuleCreator. The program never shows a window (Application.ShowMainForm is False, the
  form lies off the screen): the debugger's checks run it. Lines of TestUnit carry markers
  (MARK-...) that the other areas look up instead of counting lines. }

interface

uses
  OtaDemoTest;

const
  TestProjectName = 'OtaSelfTest';
  TestUnitName = 'TestUnit';
  TestFormName = 'TestForm';

implementation

uses
  Windows, SysUtils, Classes, Variants, Graphics, Controls, Forms, Menus, ActnList, ComCtrls,
  ImgList, ToolsAPI;

{ ---------------------------------------------------------------- the test project's creators }

var
  FormCreatedCalls: Integer;      // TTestFormCreator.FormCreated
  DefaultModuleCalls: Integer;    // TTestProjectCreator.NewDefaultProjectModule

type
  TTestProjectCreator = class(TInterfacedObject, IOTACreator, IOTAProjectCreator, IOTAProjectCreator50)
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    { IOTACreator }
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    { IOTAProjectCreator }
    function GetFileName: string;
    function GetOptionFileName: string;
    function GetShowSource: Boolean;
    procedure NewDefaultModule;
    function NewOptionSource(const ProjectName: string): IOTAFile;
    procedure NewProjectResource(const Project: IOTAProject);
    function NewProjectSource(const ProjectName: string): IOTAFile;
    { IOTAProjectCreator50 }
    procedure NewDefaultProjectModule(const Project: IOTAProject);
  end;

  TTestFormCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FOwner: IOTAModule;
    FFileName: string;
  public
    constructor Create(const AOwner: IOTAModule; const AFileName: string);
    { IOTACreator }
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    { IOTAModuleCreator }
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

  { a text module (sText): Notes.txt of the Modules area }
  TTestTextCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FFileName, FText: string;
  public
    constructor Create(const AFileName, AText: string);
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

constructor TTestProjectCreator.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TTestProjectCreator.GetCreatorType: string;
begin
  Result := sApplication;
end;

function TTestProjectCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TTestProjectCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TTestProjectCreator.GetOwner: IOTAModule;
begin
  Result := nil;                  // a group of its own
end;

function TTestProjectCreator.GetUnnamed: Boolean;
begin
  Result := False;
end;

function TTestProjectCreator.GetFileName: string;
begin
  Result := FFileName;
end;

function TTestProjectCreator.GetOptionFileName: string;
begin
  Result := '';
end;

function TTestProjectCreator.GetShowSource: Boolean;
begin
  Result := False;
end;

procedure TTestProjectCreator.NewDefaultModule;
begin
end;

function TTestProjectCreator.NewOptionSource(const ProjectName: string): IOTAFile;
begin
  Result := nil;
end;

procedure TTestProjectCreator.NewProjectResource(const Project: IOTAProject);
begin
end;

function TTestProjectCreator.NewProjectSource(const ProjectName: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'program ' + ProjectName + ';'#13#10 +
    #13#10 +
    '{ made by the OTA demo''s self-test (IOTAProjectCreator) }'#13#10 +
    #13#10 +
    'uses'#13#10 +
    '  Forms;'#13#10 +
    #13#10 +
    '{$R *.res}'#13#10 +
    #13#10 +
    'begin'#13#10 +
    '  Application.Initialize;'#13#10 +
    '  Application.ShowMainForm := False;'#13#10 +
    '  Application.Run;'#13#10 +
    'end.'#13#10);
end;

procedure TTestProjectCreator.NewDefaultProjectModule(const Project: IOTAProject);
begin
  Inc(DefaultModuleCalls);
  (BorlandIDEServices as IOTAModuleServices).CreateModule(TTestFormCreator.Create(Project,
    ExtractFilePath(FFileName) + TestUnitName + '.pas'));
end;

constructor TTestFormCreator.Create(const AOwner: IOTAModule; const AFileName: string);
begin
  inherited Create;
  FOwner := AOwner;
  FFileName := AFileName;
end;

function TTestFormCreator.GetCreatorType: string;
begin
  Result := sForm;
end;

function TTestFormCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TTestFormCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TTestFormCreator.GetOwner: IOTAModule;
begin
  Result := FOwner;
end;

function TTestFormCreator.GetUnnamed: Boolean;
begin
  Result := False;
end;

function TTestFormCreator.GetAncestorName: string;
begin
  Result := 'Form';
end;

function TTestFormCreator.GetImplFileName: string;
begin
  Result := FFileName;
end;

function TTestFormCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TTestFormCreator.GetFormName: string;
begin
  Result := TestFormName;
end;

function TTestFormCreator.GetMainForm: Boolean;
begin
  Result := True;
end;

function TTestFormCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TTestFormCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

{ off the screen: the debugger runs the program, and its form must not appear on the desktop }
function TTestFormCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'object ' + FormIdent + ': T' + FormIdent + #13#10 +
    '  Left = 3100'#13#10 +
    '  Top = 100'#13#10 +
    '  Width = 320'#13#10 +
    '  Height = 200'#13#10 +
    '  Caption = ''OTA self-test'''#13#10 +
    '  Color = clBtnFace'#13#10 +
    '  Font.Charset = DEFAULT_CHARSET'#13#10 +
    '  Font.Color = clWindowText'#13#10 +
    '  Font.Height = -11'#13#10 +
    '  Font.Name = ''MS Sans Serif'''#13#10 +
    '  Font.Style = []'#13#10 +
    '  OldCreateOrder = False'#13#10 +
    '  OnCreate = FormCreate'#13#10 +
    '  PixelsPerInch = 96'#13#10 +
    '  TextHeight = 13'#13#10 +
    'end'#13#10);
end;

function TTestFormCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'unit ' + ModuleIdent + ';'#13#10 +
    #13#10 +
    '{ made by the OTA demo''s self-test (IOTAModuleCreator) }'#13#10 +
    #13#10 +
    'interface'#13#10 +
    #13#10 +
    'uses'#13#10 +
    '  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;'#13#10 +
    #13#10 +
    'type'#13#10 +
    '  T' + FormIdent + ' = class(T' + AncestorIdent + ')'#13#10 +
    '    procedure FormCreate(Sender: TObject);'#13#10 +
    '  private'#13#10 +
    '    FCounter: Integer;'#13#10 +
    '  public'#13#10 +
    '    function Twice(N: Integer): Integer;'#13#10 +
    '  end;'#13#10 +
    #13#10 +
    'var'#13#10 +
    '  ' + FormIdent + ': T' + FormIdent + ';'#13#10 +
    #13#10 +
    'implementation'#13#10 +
    #13#10 +
    '{$R *.dfm}'#13#10 +
    #13#10 +
    'function T' + FormIdent + '.Twice(N: Integer): Integer;'#13#10 +
    'begin'#13#10 +
    '  Result := N * 2;                         // MARK-TWICE'#13#10 +
    'end;'#13#10 +
    #13#10 +
    'procedure T' + FormIdent + '.FormCreate(Sender: TObject);'#13#10 +
    'var'#13#10 +
    '  I: Integer;'#13#10 +
    'begin'#13#10 +
    '  FCounter := 0;                           // MARK-START'#13#10 +
    '  for I := 1 to 3 do'#13#10 +
    '    FCounter := FCounter + Twice(I);       // MARK-LOOP'#13#10 +
    '  Tag := FCounter;                         // MARK-END'#13#10 +
    'end;'#13#10 +
    #13#10 +
    'end.'#13#10);
end;

function TTestFormCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TTestFormCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
  Inc(FormCreatedCalls);
end;

constructor TTestTextCreator.Create(const AFileName, AText: string);
begin
  inherited Create;
  FFileName := AFileName;
  FText := AText;
end;

function TTestTextCreator.GetCreatorType: string;
begin
  Result := sText;
end;

function TTestTextCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TTestTextCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TTestTextCreator.GetOwner: IOTAModule;
begin
  Result := nil;
end;

function TTestTextCreator.GetUnnamed: Boolean;
begin
  Result := False;
end;

function TTestTextCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TTestTextCreator.GetImplFileName: string;
begin
  Result := FFileName;
end;

function TTestTextCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TTestTextCreator.GetFormName: string;
begin
  Result := '';
end;

function TTestTextCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TTestTextCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TTestTextCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TTestTextCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

function TTestTextCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(FText);
end;

function TTestTextCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TTestTextCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
end;

{ ---------------------------------------------------------------- notifiers the areas count }

type
  TCountingModuleNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  public
    BeforeSaves, AfterSaves, Modifies, Destroys, Renames: Integer;
    NewName: string;
    procedure BeforeSave;
    procedure AfterSave;
    procedure Destroyed;
    procedure Modified;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const ANewName: string);
  end;

  TCountingWizard = class(TNotifierObject, IOTANotifier, IOTAWizard)
  public
    Destroys: Integer;
    procedure Destroyed;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

  TCountingMessageNotifier = class(TNotifierObject, IOTANotifier, IOTAMessageNotifier)
  public
    Added, Deleted: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure MessageGroupAdded(const Group: IOTAMessageGroup);
    procedure MessageGroupDeleted(const Group: IOTAMessageGroup);
  end;

procedure TCountingModuleNotifier.BeforeSave;
begin
  Inc(BeforeSaves);
end;

procedure TCountingModuleNotifier.AfterSave;
begin
  Inc(AfterSaves);
end;

procedure TCountingModuleNotifier.Destroyed;
begin
  Inc(Destroys);
end;

procedure TCountingModuleNotifier.Modified;
begin
  Inc(Modifies);
end;

function TCountingModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TCountingModuleNotifier.ModuleRenamed(const ANewName: string);
begin
  Inc(Renames);
  NewName := ANewName;
end;

procedure TCountingWizard.Destroyed;
begin
  Inc(Destroys);
end;

function TCountingWizard.GetIDString: string;
begin
  Result := 'D7Studio.OtaDemo.SelfTest.Wizard';
end;

function TCountingWizard.GetName: string;
begin
  Result := 'OTA self-test wizard';
end;

function TCountingWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TCountingWizard.Execute;
begin
end;

constructor TCountingMessageNotifier.Create;
begin
  inherited Create;
  Added := TStringList.Create;
  Deleted := TStringList.Create;
end;

destructor TCountingMessageNotifier.Destroy;
begin
  Added.Free;
  Deleted.Free;
  inherited;
end;

procedure TCountingMessageNotifier.MessageGroupAdded(const Group: IOTAMessageGroup);
begin
  Added.Add(Group.GetGroupName);
end;

procedure TCountingMessageNotifier.MessageGroupDeleted(const Group: IOTAMessageGroup);
begin
  Deleted.Add(Group.GetGroupName);
end;

function Modules: IOTAModuleServices;
begin
  Result := BorlandIDEServices as IOTAModuleServices;
end;

{ the test unit's module; nil (and a FAIL) when it is not open }
function TestUnitModule(Area: TOtaTestArea): IOTAModule;
begin
  Result := Modules.FindModule(Area.Test.Values['Unit']);
end;

{ ---------------------------------------------------------------- Setup }

type
  TSetupTests = class(TOtaTestArea)
  private
    procedure CloseAll;
    procedure Folder;
    procedure OpenPackages;
    procedure NewProject;
    procedure Options;
    procedure SaveAll;
  public
    function Name: string; override;
    procedure AddSteps; override;
  end;

function TSetupTests.Name: string;
begin
  Result := 'Setup';
end;

procedure TSetupTests.AddSteps;
begin
  Step('CloseAll', CloseAll);
  Step('Folder', Folder);
  Step('OpenPackages', OpenPackages);
  Step('NewProject', NewProject);
  Step('Options', Options);
  Step('SaveAll', SaveAll);
end;

{ Close All: no project and no file open - no module at all, not even the project group (measured
  in Delphi 7's IDE) }
procedure TSetupTests.CloseAll;
begin
  Check(Modules.CloseAll, 'IOTAModuleServices.CloseAll closed everything');
  ExpectInt('no module is open, not even the project group', Modules.ModuleCount, 0);
  Check(GetActiveProject = nil, 'ToolsAPI''s GetActiveProject: none');
end;

{ the test's own files of an earlier run go; nothing else in the folder is touched }
procedure TSetupTests.Folder;
const
  Masks: array[0..14] of string = ('*.dpr', '*.pas', '*.dfm', '*.res', '*.dof', '*.cfg', '*.dsk',
    '*.exe', '*.dcu', '*.bpg', '*.txt', '*.~*', '*.ddp', '*.map', '*.drc');
var
  I: Integer;
  SR: TSearchRec;
begin
  ForceDirectories(Dir);
  for I := Low(Masks) to High(Masks) do
    if FindFirst(Dir + Masks[I], faAnyFile and not faDirectory, SR) = 0 then
    begin
      repeat
        DeleteFile(Dir + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  Check(DirectoryExists(Dir), 'the test folder ' + Dir + ' exists');
  Check(not FileExists(Dir + TestProjectName + '.dpr'), 'no project of an earlier run is left');
end;

{ the project of the project group and the active one is FileName (the group has no other) }
function GroupHasOnly(const FileName: string): Boolean;
var
  I: Integer;
  G: IOTAProjectGroup;
begin
  G := nil;
  for I := 0 to Modules.ModuleCount - 1 do
    if G = nil then Supports(Modules.Modules[I], IOTAProjectGroup, G);
  Result := (G <> nil) and (G.ProjectCount = 1) and SameText(G.Projects[0].FileName, FileName) and
    (G.ActiveProject <> nil) and SameText(G.ActiveProject.FileName, FileName);
end;

{ IOTAActionServices.OpenFile of a package opens it as Delphi 7's does (measured in its IDE): in a
  group of its own, the group before closed - not beside the group, as its File | Open command
  opens one }
procedure TSetupTests.OpenPackages;
var
  A, B: string;
  S: TStringList;
begin
  A := Dir + 'OtaSetupPkgA.dpk';
  B := Dir + 'OtaSetupPkgB.dpk';
  S := TStringList.Create;
  try
    S.Text := 'package OtaSetupPkgA;'#13#10#13#10'requires'#13#10'  rtl;'#13#10#13#10'end.';
    S.SaveToFile(A);
    S.Text := 'package OtaSetupPkgB;'#13#10#13#10'requires'#13#10'  rtl;'#13#10#13#10'end.';
    S.SaveToFile(B);
  finally
    S.Free;
  end;
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(A), 'OpenFile of a package, nothing open');
  Check(GroupHasOnly(A), '... the project of the group, the active one');
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(B), 'OpenFile of another package');
  Check(GroupHasOnly(B), '... in a group of its own: the first package closed');
  Check(Modules.FindModule(A) = nil, '... the first package is no module any more');
  Check(Modules.CloseAll, 'closed again');
  DeleteFile(A);
  DeleteFile(B);
end;

procedure TSetupTests.NewProject;
var
  M: IOTAModule;
  P: IOTAProject;
  Info: IOTAModuleInfo;
  I: Integer;
  Found: Boolean;
  Src: string;
begin
  FormCreatedCalls := 0;
  DefaultModuleCalls := 0;
  Test.Values['Project'] := Dir + TestProjectName + '.dpr';
  Test.Values['Unit'] := Dir + TestUnitName + '.pas';
  Test.Values['Dfm'] := Dir + TestUnitName + '.dfm';
  Test.Values['Exe'] := Dir + TestProjectName + '.exe';
  { the project source names its .res ($R *.res), which is not there yet: Delphi 7 says it made it }
  ExpectBox('Cannot find resource file: ' + Dir + TestProjectName + '.res.  Recreated.', mrOk);
  M := Modules.CreateModule(TTestProjectCreator.Create(Test.Values['Project']));
  Check(BoxSeen('Cannot find resource file: ' + Dir + TestProjectName + '.res.  Recreated.'),
    'the project''s .res was missing: "Cannot find resource file: <the .res>.  Recreated."');
  if not Check(Supports(M, IOTAProject, P), 'CreateModule with an IOTAProjectCreator gives an IOTAProject') then
    Exit;
  Check(SameText(P.FileName, Test.Values['Project']), 'the project has the creator''s file name', P.FileName);
  Check(SameModule(GetActiveProject, P), 'the new project is the active project');
  ExpectInt('NewDefaultProjectModule was called once', DefaultModuleCalls, 1);
  ExpectInt('the form creator''s FormCreated was called once', FormCreatedCalls, 1);
  Found := False;
  for I := 0 to P.GetModuleCount - 1 do
  begin
    Info := P.GetModule(I);
    if SameText(Info.Name, TestUnitName) then
    begin
      Found := True;
      Expect('the project''s TestUnit has the form TestForm', Info.FormName, TestFormName);
      Check(SameText(Info.FileName, Test.Values['Unit']), 'the project''s TestUnit has its file name', Info.FileName);
    end;
  end;
  Check(Found, 'the project lists TestUnit (IOTAProject.GetModule)');
  Src := EditorText(SourceEditorOf(P));
  Check(Pos(TestUnitName + ' in ''' + TestUnitName + '.pas'' {' + TestFormName + '}', Src) > 0,
    'the project''s uses clause got TestUnit with its form', Src);
  Check(Pos('Application.CreateForm(T' + TestFormName + ', ' + TestFormName + ')', Src) > 0,
    'the project creates the form (GetMainForm)', Src);
  M := Modules.FindModule(Test.Values['Unit']);
  Check(M <> nil, 'TestUnit is open (FindModule)');
  Check(FormEditorOf(M) <> nil, 'TestUnit has a form editor');
  Check(SourceEditorOf(M) <> nil, 'TestUnit has a source editor');
end;

{ run-time packages: a statically linked test program can be quarantined by a virus scanner }
procedure TSetupTests.Options;
var
  O: IOTAProjectOptions;
begin
  if GetActiveProject = nil then
  begin
    Check(False, 'there is an active project');
    Exit;
  end;
  O := GetActiveProject.ProjectOptions;
  O.Values['UsePackages'] := True;
  O.Values['Packages'] := 'rtl;vcl';
  Check(O.Values['UsePackages'] = True, 'UsePackages reads back True');
  Expect('Packages reads back', VarToStr(O.Values['Packages']), 'rtl;vcl');
end;

procedure TSetupTests.SaveAll;
begin
  Check(Modules.SaveAll, 'IOTAModuleServices.SaveAll');
  Check(FileExists(Test.Values['Project']), 'the project file is on the disk');
  Check(FileExists(Test.Values['Unit']), 'TestUnit.pas is on the disk');
  Check(FileExists(Test.Values['Dfm']), 'TestUnit.dfm is on the disk');
end;

{ ---------------------------------------------------------------- Services }

type
  TServiceTests = class(TOtaTestArea)
  private
    procedure General;
    procedure Environment;
    procedure MainWindow;
    procedure Images;
    procedure Wizards;
    procedure Packages;
  public
    function Name: string; override;
    procedure AddSteps; override;
  end;

function TServiceTests.Name: string;
begin
  Result := 'Services';
end;

procedure TServiceTests.AddSteps;
begin
  Step('General', General);
  Step('Environment', Environment);
  Step('MainWindow', MainWindow);
  Step('Images', Images);
  Step('Wizards', Wizards);
  Step('Packages', Packages);
end;

procedure TServiceTests.General;
var
  S: IOTAServices;
begin
  S := BorlandIDEServices as IOTAServices;
  Expect('GetProductIdentifier', S.GetProductIdentifier, 'Delphi');
  Expect('GetActiveDesignerType', S.GetActiveDesignerType, 'dfm');
  Check(Pos('\Software\', S.GetBaseRegistryKey) = 1, 'GetBaseRegistryKey is a key under \Software, a backslash first (Delphi 7''s)',
    S.GetBaseRegistryKey);
  Check(DirectoryExists(S.GetRootDirectory), 'GetRootDirectory exists', S.GetRootDirectory);
  Check(DirectoryExists(S.GetBinDirectory), 'GetBinDirectory exists', S.GetBinDirectory);
  Check(DirectoryExists(S.GetTemplateDirectory), 'GetTemplateDirectory exists', S.GetTemplateDirectory);
  Check(IsWindow(S.GetParentHandle), 'GetParentHandle is a window');
end;

function Named(const Names: TOTAOptionNameArray; const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Names) - 1 do
    if SameText(Names[I].Name, Name) then Result := True;
end;

{ Delphi 7's list of the environment options and the forms of their values (measured) }
procedure TServiceTests.Environment;
var
  E: IOTAEnvironmentOptions;
  Names: TOTAOptionNameArray;
  V, Old: Variant;
  I: Integer;
  HasLib: Boolean;
begin
  E := (BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
  if not Check(E <> nil, 'GetEnvironmentOptions') then Exit;
  Names := E.GetOptionNames;
  HasLib := False;
  for I := 0 to Length(Names) - 1 do
    if SameText(Names[I].Name, 'LibraryPath') then HasLib := True;
  Check(HasLib, 'the option names hold LibraryPath');
  ExpectInt('Delphi 7''s environment option names', Length(Names), 198);
  Check(Named(Names, 'SourceOptionIDString') and Named(Names, 'BoldFont') and not Named(Names, 'ObjInspBackgroundColor'),
    'its Source Options and the Color page''s element are among them, later Delphis'' colours not');
  Check(VarToStr(E.Values['LibraryPath']) <> '', 'LibraryPath has a value');
  V := E.Values['DisplayGrid'];
  Check((VarType(V) = varString) and ((V = '-1') or (V = '0')), 'DisplayGrid (a Boolean) is the string ''-1'' or ''0''',
    VarToStr(V));
  Old := V;
  E.Values['DisplayGrid'] := '0';
  Expect('... set to ''0''', VarToStr(E.Values['DisplayGrid']), '0');
  E.Values['DisplayGrid'] := True;
  Expect('... set to True: ''-1''', VarToStr(E.Values['DisplayGrid']), '-1');
  E.Values['DisplayGrid'] := Old;
  V := E.Values['ModuleExplorerSorting'];
  Check(VarType(V) = varString, 'an enumeration (ModuleExplorerSorting) is the string of its number', VarToStr(V));
  V := E.Values['UseDefaultBackground'];
  Check((VarType(V) = varInteger) and ((V = -1) or (V = 0)), 'a flag of the Color page''s element is -1 or 0 as a number',
    VarToStr(V));
  V := E.Values['GridSizeX'];
  Check((VarType(V) = varInteger) and (Integer(V) > 0), 'GridSizeX is a number', VarToStr(V));
  V := E.Values['CodeCompleteDelay'];
  Check((VarType(V) = varInteger) and (Integer(V) >= 1) and (Integer(V) <= 15),
    'CodeCompleteDelay in tenths of a second (Delphi 7''s slider)', VarToStr(V));
  Expect('SourceOptionIDString', VarToStr(E.Values['SourceOptionIDString']), 'Borland.EditOptions.Pascal');  V := E.Values['NoSuchOption.SelfTest'];
  Check(VarIsEmpty(V) or (VarToStr(V) = ''), 'an unknown option has no value');
end;

{ the main window as experts find it: Delphi 7's menu names, its actions, its tool bar }
procedure TServiceTests.MainWindow;
const
  MenuNames: array[0..9] of string = ('FileMenu', 'EditMenu', 'SearchMenu', 'ViewsMenu', 'ProjectMenu',
    'RunMenu', 'ComponentMenu', 'ToolsMenu', 'WindowsMenu', 'HelpMenu');
var
  N: INTAServices;
  I, K: Integer;
  Found: Boolean;
begin
  N := BorlandIDEServices as INTAServices;
  for I := Low(MenuNames) to High(MenuNames) do
  begin
    Found := False;
    for K := 0 to N.MainMenu.Items.Count - 1 do
      if SameText(N.MainMenu.Items[K].Name, MenuNames[I]) then Found := True;
    Check(Found, 'the main menu has ' + MenuNames[I]);
  end;
  Found := False;
  for I := 0 to N.ActionList.ActionCount - 1 do
    if SameText(N.ActionList.Actions[I].Name, 'FileOpenCommand') then Found := True;
  Check(Found, 'the action list has FileOpenCommand');
  Check(N.ToolBar[sStandardToolBar] <> nil, 'ToolBar[sStandardToolBar]');
  Check(Application.FindComponent('AppBuilder') <> nil, 'the main form is AppBuilder');
end;

procedure TServiceTests.Images;
var
  N: INTAServices;
  B: TBitmap;
  Before, I1, I2, I3: Integer;
begin
  N := BorlandIDEServices as INTAServices;
  B := TBitmap.Create;
  try
    B.Width := 16;
    B.Height := 16;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, 16, 16));
    B.Canvas.Brush.Color := clGreen;
    B.Canvas.FillRect(Rect(4, 4, 12, 12));
    Before := N.ImageList.Count;
    I1 := N.AddMasked(B, clFuchsia, 'D7Studio.OtaDemo.SelfTest.Image');
    I2 := N.AddMasked(B, clFuchsia, 'D7Studio.OtaDemo.SelfTest.Image');
    ExpectInt('AddMasked gives the next index', I1, Before);
    ExpectInt('AddMasked with the same Ident gives the same index', I2, I1);
    I3 := N.AddMasked(B, clFuchsia, 'D7Studio.OtaDemo.SelfTest.Image2');
    ExpectInt('AddMasked with another Ident gives a new index', I3, I1 + 1);
    ExpectInt('the image list grew by two', N.ImageList.Count, Before + 2);
  finally
    B.Free;
  end;
end;

procedure TServiceTests.Wizards;
var
  W: IOTAWizardServices;
  Wiz: TCountingWizard;
  Keep: IOTAWizard;
  Index: Integer;
begin
  W := BorlandIDEServices as IOTAWizardServices;
  Wiz := TCountingWizard.Create;
  Keep := Wiz;
  Index := W.AddWizard(Keep);
  Check(Index >= 0, 'AddWizard gives an index');
  W.RemoveWizard(Index);
  ExpectInt('RemoveWizard does not tell the wizard Destroyed (Delphi 7''s)', Wiz.Destroys, 0);
end;

procedure TServiceTests.Packages;
var
  P: IOTAPackageServices;
  I, Demo: Integer;
begin
  P := BorlandIDEServices as IOTAPackageServices;
  Check(P.PackageCount > 0, 'PackageCount');
  Demo := -1;
  for I := 0 to P.PackageCount - 1 do
    if Pos('OTADEMO', UpperCase(P.PackageNames[I])) > 0 then Demo := I;
  Check(Demo >= 0, 'the demo package is listed');
  for I := 0 to P.PackageCount - 1 do
    if P.ComponentCount[I] > 0 then
    begin
      Check(P.ComponentNames[I, 0] <> '', 'a package''s first component has a name', P.PackageNames[I]);
      Break;
    end;
end;

{ ---------------------------------------------------------------- Modules }

type
  TModuleTests = class(TOtaTestArea)
  private
    FNotifier: TCountingModuleNotifier;
    FNotifierIntf: IOTAModuleNotifier;
    FIndex: Integer;
    FNotes: string;
    procedure FindModules;
    procedure Owners;
    procedure WatchText;
    procedure SaveText;
    procedure MarkModified;
    procedure Dates;
    procedure RenameText;
    procedure CloseText;
    procedure CloseWays;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function TModuleTests.Name: string;
begin
  Result := 'Modules';
end;

{ every way a file's module closes tells its notifiers Destroyed - Delphi 7 twice, D7 Studio once:
  CloseFile, CloseModule(False) of an unmodified file, a unit with its form }
procedure TModuleTests.CloseWays;

  function Watch(const F, Text: string; out N: TCountingModuleNotifier): IOTAModuleNotifier;
  var
    S: TStringList;
    M: IOTAModule;
  begin
    S := TStringList.Create;
    try
      S.Text := Text;
      S.SaveToFile(F);
    finally
      S.Free;
    end;
    (BorlandIDEServices as IOTAActionServices).OpenFile(F);
    M := Modules.FindModule(F);
    N := TCountingModuleNotifier.Create;
    Result := N;
    if M <> nil then M.AddNotifier(Result);
  end;

var
  NA, NB, NC: TCountingModuleNotifier;
  IA, IB, IC: IOTAModuleNotifier;
  M: IOTAModule;
  S: TStringList;
begin
  IA := Watch(Dir + 'CloseA.txt', 'a', NA);
  Check((BorlandIDEServices as IOTAActionServices).CloseFile(Dir + 'CloseA.txt'), 'CloseFile of a text file');
  ExpectInt('... its module notifier told Destroyed (Delphi 7: twice)', NA.Destroys, IdeValue(2, 1));
  IB := Watch(Dir + 'CloseB.txt', 'b', NB);
  M := Modules.FindModule(Dir + 'CloseB.txt');
  Check((M <> nil) and M.CloseModule(False), 'CloseModule(False) of an unmodified text file');
  M := nil;
  ExpectInt('... its module notifier told Destroyed (Delphi 7: twice)', NB.Destroys, IdeValue(2, 1));
  S := TStringList.Create;
  try
    S.Text := 'object FormC: TFormC'#13#10'  Left = 3100'#13#10'  Top = 100'#13#10'  Width = 200'#13#10 +
      '  Height = 100'#13#10'  Caption = ''FormC'''#13#10'end';
    S.SaveToFile(Dir + 'CloseC.dfm');
  finally
    S.Free;
  end;
  IC := Watch(Dir + 'CloseC.pas', 'unit CloseC;'#13#10#13#10'interface'#13#10#13#10'uses Forms;'#13#10#13#10 +
    'type'#13#10'  TFormC = class(TForm)'#13#10'  end;'#13#10#13#10'implementation'#13#10#13#10'{$R *.dfm}'#13#10#13#10'end.', NC);
  M := Modules.FindModule(Dir + 'CloseC.pas');
  Check((M <> nil) and M.CloseModule(True), 'CloseModule(True) of a unit with a form');
  M := nil;
  { Delphi 7 told it once in one run, twice in another (measured) }
  Check((NC.Destroys = 1) or (IdeIsDelphi7 and (NC.Destroys = 2)),
    '... its module notifier told Destroyed (Delphi 7: once or twice)', IntToStr(NC.Destroys));
  DeleteFile(Dir + 'CloseA.txt');
  DeleteFile(Dir + 'CloseB.txt');
  DeleteFile(Dir + 'CloseC.pas');
  DeleteFile(Dir + 'CloseC.dfm');
end;

procedure TModuleTests.AddSteps;
begin
  Step('FindModule', FindModules);
  Step('Owners', Owners);
  Step('Notifier', WatchText);
  Step('Save', SaveText);
  Step('MarkModified', MarkModified);
  Step('Dates', Dates);
  Step('Rename', RenameText);
  Step('Close', CloseText);
  Step('CloseWays', CloseWays);
end;

procedure TModuleTests.Cleanup;
var
  M: IOTAModule;
begin
  if FNotifierIntf <> nil then
  begin
    M := Modules.FindModule(FNotes);
    if M <> nil then M.RemoveNotifier(FIndex);
    FNotifierIntf := nil;
  end;
end;

{ one module for one file, however the file name is written }
procedure TModuleTests.FindModules;
var
  F, Short: string;
  M, M2: IOTAModule;
  Buf: array[0..MAX_PATH] of Char;
begin
  F := Test.Values['Unit'];
  M := Modules.FindModule(F);
  if not Check(M <> nil, 'FindModule finds TestUnit') then Exit;
  M2 := Modules.FindModule(AnsiLowerCase(F));
  Check(SameModule(M, M2), 'FindModule in lower case gives the same module');
  { the name as the module has it, in any case: none for another spelling of it (Delphi 7) }
  M2 := Modules.FindModule(StringReplace(F, '\', '/', [rfReplaceAll]));
  Check(M2 = nil, 'FindModule with forward slashes gives none');
  if (GetShortPathName(PChar(F), Buf, SizeOf(Buf)) > 0) and not SameText(Buf, F) then
  begin
    Short := Buf;
    M2 := Modules.FindModule(Short);
    Check(M2 = nil, 'FindModule with the 8.3 name gives none', Short);
  end;
  Check(Modules.FindModule(Dir + 'NoSuchUnit.pas') = nil, 'FindModule of a file that is not open gives nil');
  Check(Modules.FindFormModule(TestFormName) <> nil, 'FindFormModule finds TestForm');
end;

procedure TModuleTests.Owners;
var
  M: IOTAModule;
begin
  M := TestUnitModule(Self);
  if not Check(M <> nil, 'TestUnit is open') then Exit;
  Check(M.OwnerModuleCount >= 1, 'TestUnit has an owner module');
  if M.OwnerModuleCount >= 1 then
    Check(SameModule(M.OwnerModules[0], GetActiveProject), 'its owner is the project');
end;

{ a text module of its own (sText creator), watched by a module notifier }
procedure TModuleTests.WatchText;
var
  M: IOTAModule;
  W: IOTAEditWriter;
begin
  FNotes := Dir + 'Notes.txt';
  M := Modules.CreateModule(TTestTextCreator.Create(FNotes, 'first line'#13#10'second line'#13#10));
  if not Check(M <> nil, 'CreateModule with a text creator') then Exit;
  Check(SameText(M.FileName, FNotes), 'the text module has the creator''s file name', M.FileName);
  FNotifier := TCountingModuleNotifier.Create;
  FNotifierIntf := FNotifier;
  FIndex := M.AddNotifier(FNotifierIntf);
  Check(FIndex >= 0, 'AddNotifier gives an index');
  W := SourceEditorOf(M).CreateWriter;
  W.CopyTo(0);
  W.Insert('inserted ');
  W := nil;
  Check(FNotifier.Modifies > 0, 'an edit tells the module notifier Modified');
end;

procedure TModuleTests.SaveText;
var
  M: IOTAModule;
begin
  M := Modules.FindModule(FNotes);
  if not Check(M <> nil, 'Notes.txt is open') then Exit;
  Check(M.Save(False, True), 'IOTAModule.Save');
  ExpectInt('BeforeSave', FNotifier.BeforeSaves, 1);
  ExpectInt('AfterSave', FNotifier.AfterSaves, 1);
  Check(FileExists(FNotes), 'Notes.txt is on the disk');
  Check(not SourceEditorOf(M).Modified, 'after the save the source editor is not modified');
end;

procedure TModuleTests.MarkModified;
var
  M: IOTAModule;
  E: IOTASourceEditor;
begin
  M := Modules.FindModule(FNotes);
  if not Check(M <> nil, 'Notes.txt is open') then Exit;
  E := SourceEditorOf(M);
  Check(not E.Modified, 'not modified before MarkModified');
  E.MarkModified;
  Check(E.Modified, 'IOTAEditor.Modified after MarkModified');
  Check(M.Save(False, True), 'saved again');
end;

{ IOTAEditBuffer's dates: the time of the last change, not the time of the question }
procedure TModuleTests.Dates;
var
  M: IOTAModule;
  B: IOTAEditBuffer;
  W: IOTAEditWriter;
  D1, D2: TDateTime;
begin
  M := Modules.FindModule(FNotes);
  if not Check(Supports(SourceEditorOf(M), IOTAEditBuffer, B), 'Notes.txt has an IOTAEditBuffer') then Exit;
  W := B.CreateWriter;
  W.CopyTo(0);
  W.Insert('x');
  W := nil;
  Check(B.IsModified, 'the buffer is modified after a write (CreateWriter: undo history emptied, the change kept)');
  D1 := B.GetCurrentDate;
  Sleep(50);
  D2 := B.GetCurrentDate;
  Check(D1 = D2, 'GetCurrentDate of a modified buffer stays the time of its last change',
    Format('%s, then %s', [FormatDateTime('hh:nn:ss.zzz', D1), FormatDateTime('hh:nn:ss.zzz', D2)]));
  Check(B.GetInitialDate <= D1, 'GetInitialDate is not after GetCurrentDate');
end;

procedure TModuleTests.RenameText;
var
  M: IOTAModule;
  NewName: string;
begin
  M := Modules.FindModule(FNotes);
  if not Check(M <> nil, 'Notes.txt is open') then Exit;
  NewName := Dir + 'Notes2.txt';
  M.FileName := NewName;
  ExpectInt('ModuleRenamed', FNotifier.Renames, 1);
  Check(SameText(FNotifier.NewName, NewName), 'ModuleRenamed gets the new name', FNotifier.NewName);
  Check(SameText(M.FileName, NewName), 'the module has the new name', M.FileName);
  Check(Modules.FindModule(NewName) <> nil, 'FindModule finds the new name');
  FNotes := NewName;
end;

procedure TModuleTests.CloseText;
var
  M: IOTAModule;
begin
  M := Modules.FindModule(FNotes);
  if not Check(M <> nil, 'Notes2.txt is open') then Exit;
  Check(M.CloseModule(True), 'CloseModule(True)');
  M := nil;
  { Delphi 7 tells a file's module notifiers twice; D7 Studio once }
  ExpectInt('the module notifier was told Destroyed (Delphi 7: twice)', FNotifier.Destroys, IdeValue(2, 1));
  Check(Modules.FindModule(FNotes) = nil, 'the closed file is no module any more');
  FNotifierIntf := nil;           // the module took its notifier along
end;

{ ---------------------------------------------------------------- Project }

type
  TProjectTests = class(TOtaTestArea)
  private
    FCompiled: Boolean;
    procedure Options;
    procedure VersionKeys;
    procedure AddRemoveFile;
    procedure Compile;
    function ExeMade: Boolean;
  public
    function Name: string; override;
    procedure AddSteps; override;
  end;

function TProjectTests.Name: string;
begin
  Result := 'Project';
end;

procedure TProjectTests.AddSteps;
begin
  Step('Options', Options);
  Step('VersionKeys', VersionKeys);
  Step('AddRemoveFile', AddRemoveFile);
  Step('Compile', Compile);
end;

procedure TProjectTests.Options;
var
  O: IOTAProjectOptions;
  Names: TOTAOptionNameArray;
begin
  O := GetActiveProject.ProjectOptions;
  Names := O.GetOptionNames;
  ExpectInt('GetOptionNames: Delphi 7''s 243', Length(Names), 243);
  Check(O.Values['HintFlag'] = True, 'HintFlag (Show hints) reads True');
  ExpectInt('StackSize: the minimum stack size', O.Values['StackSize'], 16384);
  Check(O.Values['DebugInfo'] = False, 'DebugInfo (TD32 information in the program) reads False');
  ExpectInt('UnitDebugInfo ($D) reads 1', O.Values['UnitDebugInfo'], 1);
  O.Values['Defines'] := 'SELFTEST';
  Expect('Defines reads back', VarToStr(O.Values['Defines']), 'SELFTEST');
  O.Values['Defines'] := '';
  O.Values['RangeChecks'] := 1;
  ExpectInt('RangeChecks reads back', O.Values['RangeChecks'], 1);
  O.Values['RangeChecks'] := 0;
end;

{ the version information keys, edited in place as version-info experts do }
procedure TProjectTests.VersionKeys;
var
  O: IOTAProjectOptions;
  L: TStrings;
begin
  O := GetActiveProject.ProjectOptions;
  L := TStrings(Integer(O.Values['Keys']));
  if not Check(L <> nil, 'Values[''Keys''] is a TStrings') then Exit;
  L.Values['Comments'] := 'OTA self-test';
  L := TStrings(Integer(O.Values['Keys']));
  Expect('a key changed in place is kept', L.Values['Comments'], 'OTA self-test');
end;

procedure TProjectTests.AddRemoveFile;
var
  P: IOTAProject;
  F: string;
  S: TStringList;
  Before, I: Integer;
  Found: Boolean;
begin
  P := GetActiveProject;
  F := Dir + 'Extra.pas';
  S := TStringList.Create;
  try
    S.Text := 'unit Extra;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.';
    S.SaveToFile(F);
  finally
    S.Free;
  end;
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved before AddFile');
  Before := P.GetModuleCount;
  P.AddFile(F, True);
  ExpectInt('AddFile adds a module', P.GetModuleCount, Before + 1);
  Found := False;
  for I := 0 to P.GetModuleCount - 1 do
    if SameText(P.GetModule(I).Name, 'Extra') then Found := True;
  Check(Found, 'the added unit is listed');
  { Delphi 7's: the project source is changed in the IDE, not on the disk, until it is saved }
  S := TStringList.Create;
  try
    S.LoadFromFile(Test.Values['Project']);
    Check(Pos('Extra', S.Text) = 0, 'the project file on the disk is not changed yet');
  finally
    S.Free;
  end;
  Check(Pos('Extra', EditorText(SourceEditorOf(P))) > 0, 'the project source in the IDE names the unit');
  Check(SourceEditorOf(P).Modified, 'the project source is modified (unsaved)');
  ExpectBox('Remove ' + F + '?', mrYes);
  P.RemoveFile(F);
  Check(BoxSeen('Remove ' + F + '?'), 'RemoveFile asks first: "Remove <the file>?"');
  ExpectInt('RemoveFile removes it', P.GetModuleCount, Before);
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved after RemoveFile');
end;

function TProjectTests.ExeMade: Boolean;
begin
  Result := FileExists(Test.Values['Exe']);
end;

procedure TProjectTests.Compile;
var
  P: IOTAProject;
begin
  P := GetActiveProject;
  Check(Modules.SaveAll, 'saved before the compile');
  FCompiled := P.ProjectBuilder.BuildProject(cmOTABuild, True, True);
  Check(FCompiled, 'BuildProject(cmOTABuild)');
  Check(ExeMade, 'the program was made', Test.Values['Exe']);
end;

{ ---------------------------------------------------------------- Messages }

type
  TMessageTests = class(TOtaTestArea)
  private
    procedure Groups;
    procedure Compiler;
  public
    function Name: string; override;
    procedure AddSteps; override;
  end;

function TMessageTests.Name: string;
begin
  Result := 'Messages';
end;

procedure TMessageTests.AddSteps;
begin
  Step('Groups', Groups);
  Step('Compiler', Compiler);
end;

procedure TMessageTests.Groups;
var
  Msgs: IOTAMessageServices;
  N: TCountingMessageNotifier;
  NI: IOTAMessageNotifier;
  Index, Before: Integer;
  G: IOTAMessageGroup;
  Ref, Child: Pointer;
begin
  Msgs := BorlandIDEServices as IOTAMessageServices;
  N := TCountingMessageNotifier.Create;
  NI := N;
  Index := Msgs.AddNotifier(NI);
  try
    Before := Msgs.GetMessageGroupCount;
    G := Msgs.AddMessageGroup('OTA Self-Test Group');
    ExpectInt('AddMessageGroup adds a group', Msgs.GetMessageGroupCount, Before + 1);
    Check(N.Added.IndexOf('OTA Self-Test Group') >= 0, 'MessageGroupAdded');
    Check(SameModule(Msgs.GetGroup('OTA Self-Test Group'), G), 'GetGroup finds it');
    Expect('GetGroupName', G.GetGroupName, 'OTA Self-Test Group');
    Msgs.AddToolMessage('', 'SELFTEST parent', 'Self-Test', 0, 0, nil, Ref, G);
    Msgs.AddToolMessage('', 'SELFTEST child', 'Self-Test', 0, 0, Ref, Child, G);
    Msgs.AddTitleMessage('SELFTEST title', G);
    Msgs.RemoveMessageGroup(G);
    ExpectInt('RemoveMessageGroup removes it', Msgs.GetMessageGroupCount, Before);
    Check(N.Deleted.IndexOf('OTA Self-Test Group') >= 0, 'MessageGroupDeleted');
  finally
    Msgs.RemoveNotifier(Index);
  end;
end;

{ compiler messages of the Build group: ClearCompilerMessages takes them, ClearToolMessages
  leaves them - checked by a test script in the IDE's state (EXPECT lines) }
procedure TMessageTests.Compiler;
var
  Msgs: IOTAMessageServices;
  Ref: Pointer;
begin
  Msgs := BorlandIDEServices as IOTAMessageServices;
  Msgs.AddCompilerMessage(Test.Values['Unit'], 'SELFTEST-CM1 cleared', 'SelfTestTool', otamkWarn, 1, 1, nil, Ref);
  Msgs.ClearCompilerMessages;
  Msgs.AddCompilerMessage(Test.Values['Unit'], 'SELFTEST-CM2 kept', 'SelfTestTool', otamkHint, 1, 1, nil, Ref);
  Msgs.AddToolMessage('', 'SELFTEST-TM1 cleared', 'Self-Test', 0, 0, nil, Ref, nil);
  Msgs.ClearToolMessages;
  Note('EXPECT messages lacks SELFTEST-CM1');
  Note('EXPECT messages has SELFTEST-CM2');
  Note('EXPECT messages lacks SELFTEST-TM1');
  Check(True, 'compiler and tool messages added and cleared (the script checks the Messages view)');
end;

initialization
  RegisterTestArea(TSetupTests, 0);
  RegisterTestArea(TServiceTests, 10);
  RegisterTestArea(TModuleTests, 30);
  RegisterTestArea(TProjectTests, 40);
  RegisterTestArea(TMessageTests, 900);
end.
