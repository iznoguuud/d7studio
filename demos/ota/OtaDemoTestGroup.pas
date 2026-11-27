{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestGroup;

{ The self-test's project group area (OtaDemoTest): a second project in the group of the test
  project - added with IOTAActionServices.OpenProject(NewProjGroup False), made active and back
  with IOTAProjectGroup.SetActiveProject, closed in the group (IOTAModule.CloseModule), activated
  again and removed. Every project of a group stays loaded: the module objects and their notifiers
  survive an activation, no file closes, the experts hear ofnActiveProjectChanged once per
  activation; a project that is not the active one takes AddFile / RemoveFile, a module creator's
  unit, its options (EditOptions too), a build and Save Project As (its entry in the group follows);
  a unit of both projects has two owners, and saved under another name both uses clauses follow.
  Then a package opened with File | Open (the main window's command, its dialog given the file)
  stays beside the group, as Delphi's misc packages: a module and the active project, but no
  project of the group and owned by no module; it owns its unit, SetActiveProject takes it, Save
  Project As renames it, CloseModule closes it.

  The second project is a console program, OtaGroupOther.dpr in the test's folder, with a unit of
  its own; the package is OtaGroupPkg.dpk there, with one unit. At the end the group is the test
  project's alone again, with the page that was shown. }

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Variants, Controls, Forms, ExtCtrls, ActnList, ToolsAPI, OtaDemoTest;

type
  { the file notifications heard while the area runs: "code|file" }
  TGroupIdeNotifier = class(TOtaEventNotifier)
  public
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean); override;
    function Count(const Code, FileName: string): Integer;
  end;

  TGroupModuleNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  public
    Destroys, Renames: Integer;
    NewName: string;
    Owner: IOTAModule;                 // the module it is registered with, when the owners are asked
    OwnersAtRename: Integer;           // ... its OwnerModuleCount while ModuleRenamed is told
    procedure Destroyed;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const ANewName: string);
  end;

  { a unit made by a module creator whose owner is the second project (not the active one) }
  TGroupUnitCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FOwner: IOTAModule;
    FFileName: string;
  public
    constructor Create(const AOwner: IOTAModule; const AFileName: string);
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

  TGroupTests = class(TOtaTestArea)
  private
    FIde: TGroupIdeNotifier;
    FIdeIntf: IOTAIDENotifier;
    FIdeIndex: Integer;
    FFirstNote, FOtherNote: TGroupModuleNotifier;    // on the test project's / the second project's module
    FFirstNoteIntf, FOtherNoteIntf: IOTAModuleNotifier;
    FFirstIndex, FOtherIndex: Integer;
    FFirstMod, FOtherMod: IOTAModule;                // the modules they are registered with
    FFirst: IOTAProject;                             // the test project
    FOther: IOTAProject;                             // the second project
    FOtherFile, FOtherUnit, FNewUnit, FRenamed: string;
    FPkgFile, FPkgUnit: string;                      // the package opened beside the group, its unit
    FUnitMod: IOTAModule;                            // TestUnit's module before the area
    FShown: IOTAModule;                              // the module shown before the area
    FModuleCount: Integer;
    FTimer: TTimer;
    FOptCaption: string;
    FOptEnd: Cardinal;
    FOpenName: string;                               // the file File | Open's dialog gets
    FOpenEnd: Cardinal;
    procedure OptTick(Sender: TObject);
    procedure OpenTick(Sender: TObject);
    function OpenByFileOpen(const FileName: string): Boolean;
    procedure Prepare;
    procedure AddProject;
    procedure Activate;
    procedure Owners;
    procedure Creator;
    procedure SharedRename;
    procedure Options;
    procedure Build;
    procedure SaveAs;
    procedure CloseInGroup;
    procedure Reactivate;
    procedure Remove;
    procedure Beside;
    procedure Restore;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function Modules: IOTAModuleServices;
begin
  Result := BorlandIDEServices as IOTAModuleServices;
end;

{ the module of the project group (nil: none) }
function Group: IOTAProjectGroup;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Modules.ModuleCount - 1 do
    if Supports(Modules.Modules[I], IOTAProjectGroup, Result) then Exit;
end;

{ the group's project of a file (nil: none) }
function GroupProjectOf(const FileName: string): IOTAProject;
var
  G: IOTAProjectGroup;
  I: Integer;
begin
  Result := nil;
  G := Group;
  if G = nil then Exit;
  for I := 0 to G.ProjectCount - 1 do
    if (G.Projects[I] <> nil) and SameText(G.Projects[I].FileName, FileName) then
    begin
      Result := G.Projects[I];
      Exit;
    end;
end;

procedure WriteText(const FileName, Text: string);
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.Text := Text;
    S.SaveToFile(FileName);
  finally
    S.Free;
  end;
end;

{ a file's bytes as they are }
function FileBytes(const FileName: string): string;
var
  S: TFileStream;
begin
  S := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, S.Size);
    if S.Size > 0 then S.ReadBuffer(Result[1], S.Size);
  finally
    S.Free;
  end;
end;

{ the character of byte $E9 in the system code page ('e' with an acute accent in 1252, iota in
  1253) as the IDE's text, UTF-8: a name beyond ASCII that a project source in that code page can
  hold; False when the code page has no character there alone (a double-byte one) }
function SystemCharE9(out Utf8: string): Boolean;
const
  MB_ERR_INVALID_CHARS = 8;      // not in Delphi 7's Windows unit
var
  Buf: array[0..7] of Char;
  CodePage: Integer;
  B: Char;
  W: WideChar;
begin
  Result := False;
  Utf8 := '';
  if GetLocaleInfo(LOCALE_SYSTEM_DEFAULT, LOCALE_IDEFAULTANSICODEPAGE, Buf, SizeOf(Buf)) = 0 then Exit;
  CodePage := StrToIntDef(Buf, 0);
  B := #$E9;
  if (CodePage = 0) or (MultiByteToWideChar(CodePage, MB_ERR_INVALID_CHARS, @B, 1, @W, 1) <> 1) then Exit;
  Utf8 := UTF8Encode(WideString(W));
  Result := True;
end;

{ a module of the project has that file }
function ProjectHasFile(const P: IOTAProject; const FileName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to P.GetModuleCount - 1 do
    if SameText(P.GetModule(I).FileName, FileName) then
    begin
      Result := True;
      Exit;
    end;
end;

{ ---------------------------------------------------------------- notifiers, creator }

procedure TGroupIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
const
  Codes: array[TOTAFileNotification] of string = ('opening', 'opened', 'closing', 'defdeskload',
    'defdesksave', 'deskload', 'desksave', 'installed', 'uninstalled', 'active');
begin
  Events.Add(Codes[NotifyCode] + '|' + FileName);
end;

function TGroupIdeNotifier.Count(const Code, FileName: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Events.Count - 1 do
    if SameText(Events[I], Code + '|' + FileName) then Inc(Result);
end;

procedure TGroupModuleNotifier.Destroyed;
begin
  Inc(Destroys);
  Owner := nil;
end;

function TGroupModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TGroupModuleNotifier.ModuleRenamed(const ANewName: string);
begin
  Inc(Renames);
  NewName := ANewName;
  if Owner <> nil then OwnersAtRename := Owner.OwnerModuleCount;
end;

constructor TGroupUnitCreator.Create(const AOwner: IOTAModule; const AFileName: string);
begin
  inherited Create;
  FOwner := AOwner;
  FFileName := AFileName;
end;

function TGroupUnitCreator.GetCreatorType: string;
begin
  Result := sUnit;
end;

function TGroupUnitCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TGroupUnitCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TGroupUnitCreator.GetOwner: IOTAModule;
begin
  Result := FOwner;
end;

function TGroupUnitCreator.GetUnnamed: Boolean;
begin
  Result := False;
end;

function TGroupUnitCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TGroupUnitCreator.GetImplFileName: string;
begin
  Result := FFileName;
end;

function TGroupUnitCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TGroupUnitCreator.GetFormName: string;
begin
  Result := '';
end;

function TGroupUnitCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TGroupUnitCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TGroupUnitCreator.GetShowSource: Boolean;
begin
  Result := False;
end;

function TGroupUnitCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

function TGroupUnitCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile('unit ' + ModuleIdent + ';'#13#10#13#10'interface'#13#10#13#10 +
    'implementation'#13#10#13#10'end.'#13#10);
end;

function TGroupUnitCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TGroupUnitCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
end;

{ ---------------------------------------------------------------- the area }

function TGroupTests.Name: string;
begin
  Result := 'Group';
end;

procedure TGroupTests.AddSteps;
begin
  Step('Prepare', Prepare);
  Step('AddProject', AddProject);
  Step('Activate', Activate);
  Step('Owners', Owners);
  Step('Creator', Creator);
  Step('SharedRename', SharedRename);
  Step('Options', Options);
  Step('Build', Build);
  Step('SaveAs', SaveAs);
  Step('CloseModule', CloseInGroup);
  Step('Reactivate', Reactivate);
  Step('Remove', Remove);
  Step('Beside', Beside);
  Step('Restore', Restore);
end;

procedure TGroupTests.Cleanup;
begin
  FreeAndNil(FTimer);
  if FIdeIntf <> nil then
  begin
    (BorlandIDEServices as IOTAServices).RemoveNotifier(FIdeIndex);
    FIdeIntf := nil;
  end;
  if (FFirstNoteIntf <> nil) and (FFirstMod <> nil) then FFirstMod.RemoveNotifier(FFirstIndex);
  FFirstNoteIntf := nil;
  FFirstMod := nil;
  if (FOtherNoteIntf <> nil) and (FOtherMod <> nil) and (FOtherNote.Destroys = 0) then FOtherMod.RemoveNotifier(FOtherIndex);
  FOtherNoteIntf := nil;
  FOtherMod := nil;
  FFirst := nil;
  FOther := nil;
  FUnitMod := nil;
  FShown := nil;
end;

{ the second project's files; the test project's module and TestUnit's as they are now; the
  notifiers }
procedure TGroupTests.Prepare;
begin
  FOtherFile := Dir + 'OtaGroupOther.dpr';
  FOtherUnit := Dir + 'OtaGroupUnit.pas';
  FNewUnit := Dir + 'OtaGroupNew.pas';
  FRenamed := Dir + 'OtaGroupRenamed.dpr';
  DeleteFile(FRenamed);
  DeleteFile(ChangeFileExt(FRenamed, '.dof'));
  DeleteFile(FNewUnit);
  WriteText(FOtherUnit, 'unit OtaGroupUnit;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.');
  WriteText(FOtherFile, 'program OtaGroupOther;'#13#10#13#10'{$APPTYPE CONSOLE}'#13#10#13#10'uses'#13#10 +
    '  OtaGroupUnit in ''OtaGroupUnit.pas'';'#13#10#13#10'begin'#13#10'end.');
  FPkgFile := Dir + 'OtaGroupPkg.dpk';
  FPkgUnit := Dir + 'OtaGroupPkgUnit.pas';
  WriteText(FPkgUnit, 'unit OtaGroupPkgUnit;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.');
  WriteText(FPkgFile, 'package OtaGroupPkg;'#13#10#13#10'requires'#13#10'  rtl;'#13#10#13#10'contains'#13#10 +
    '  OtaGroupPkgUnit in ''OtaGroupPkgUnit.pas'';'#13#10#13#10'end.');
  Check(Modules.SaveAll, 'saved before the group changes');
  FFirst := GetActiveProject;
  if not Check(FFirst <> nil, 'the test project is the active project') then Exit;
  FUnitMod := Modules.FindModule(Test.Values['Unit']);
  Check(FUnitMod <> nil, 'TestUnit is open');
  FShown := Modules.CurrentModule;
  FModuleCount := Modules.ModuleCount;
  ExpectInt('a group of one project', Group.ProjectCount, 1);
  FIde := TGroupIdeNotifier.Create;
  FIdeIntf := FIde;
  FIdeIndex := (BorlandIDEServices as IOTAServices).AddNotifier(FIdeIntf);
  FFirstNote := TGroupModuleNotifier.Create;
  FFirstNoteIntf := FFirstNote;
  FFirstMod := FFirst;
  FFirstIndex := FFirstMod.AddNotifier(FFirstNoteIntf);
end;

{ OpenProject(NewProjGroup False): the project joins the group and becomes the active one;
  nothing closes, the modules there stay the same objects }
procedure TGroupTests.AddProject;
var
  G: IOTAProjectGroup;
begin
  Check((BorlandIDEServices as IOTAActionServices).OpenProject(FOtherFile, False),
    'IOTAActionServices.OpenProject(NewProjGroup False)');
  G := Group;
  if not Check(G <> nil, 'the project group') then Exit;
  ExpectInt('the group has two projects', G.ProjectCount, 2);
  Check(SameModule(G.Projects[0], FFirst), 'Projects[0] is the test project''s module, the same object');
  FOther := GroupProjectOf(FOtherFile);
  if not Check(FOther <> nil, 'Projects[1] is the second project') then Exit;
  Check(SameText(GetActiveProject.FileName, FOtherFile), 'the added project is the active one', GetActiveProject.FileName);
  Check(SameModule(Modules.FindModule(Test.Values['Unit']), FUnitMod), 'TestUnit is open still, the same module');
  Check(Modules.ModuleCount > FModuleCount, 'the module list has the new project too',
    Format('%d, before %d', [Modules.ModuleCount, FModuleCount]));
  ExpectInt('ofnFileOpening of the project', FIde.Count('opening', FOtherFile), 1);
  ExpectInt('ofnFileOpened of the project', FIde.Count('opened', FOtherFile), 1);
  ExpectInt('ofnActiveProjectChanged once, with its file', FIde.Count('active', FOtherFile), 1);
  ExpectInt('the test project''s module was not told Destroyed', FFirstNote.Destroys, 0);
  FOtherNote := TGroupModuleNotifier.Create;
  FOtherNoteIntf := FOtherNote;
  FOtherMod := FOther;
  FOtherIndex := FOtherMod.AddNotifier(FOtherNoteIntf);
end;

{ SetActiveProject: a pointer switch - the same objects, one notification, no file closed; of the
  active project again, one more notification (Delphi 7) }
procedure TGroupTests.Activate;
var
  G: IOTAProjectGroup;
  N: Integer;
begin
  G := Group;
  if (G = nil) or (FOther = nil) then Exit;
  N := Modules.ModuleCount;
  G.SetActiveProject(FFirst);
  Check(SameModule(G.ActiveProject, FFirst), 'SetActiveProject: the test project is active, the same object');
  ExpectInt('ofnActiveProjectChanged once, with its file', FIde.Count('active', Test.Values['Project']), 1);
  ExpectInt('the module count stays', Modules.ModuleCount, N);
  Check(SameModule(GroupProjectOf(FOtherFile), FOther), 'the second project''s module is the same object');
  Check(SameModule(Modules.FindModule(Test.Values['Unit']), FUnitMod), 'TestUnit is open still, the same module');
  ExpectInt('neither project''s module was told Destroyed', FFirstNote.Destroys + FOtherNote.Destroys, 0);
  G.SetActiveProject(FFirst);
  ExpectInt('SetActiveProject of the active project: notified again', FIde.Count('active', Test.Values['Project']), 2);
end;

{ a unit of two projects: two owners, in the group's order; AddFile / RemoveFile on the project
  that is not active }
procedure TGroupTests.Owners;
var
  Before: Integer;
begin
  if (FOther = nil) or (FUnitMod = nil) then Exit;
  ExpectInt('TestUnit has one owner', FUnitMod.OwnerCount, 1);
  Before := FOther.GetModuleCount;
  FOther.AddFile(Test.Values['Unit'], True);
  ExpectInt('AddFile on the project that is not active adds to it', FOther.GetModuleCount, Before + 1);
  Check(Pos('TestUnit', EditorText(SourceEditorOf(FOther))) > 0, '... its source names the unit');
  Check(Pos('OtaGroup', EditorText(SourceEditorOf(FFirst))) = 0, 'the active project''s source does not change');
  ExpectInt('TestUnit has two owners', FUnitMod.OwnerCount, 2);
  if FUnitMod.OwnerCount = 2 then
  begin
    Check(SameModule(FUnitMod.Owners[0], FFirst), 'Owners[0]: the test project (the group''s order)');
    Check(SameModule(FUnitMod.Owners[1], FOther), 'Owners[1]: the second project');
  end;
  { Delphi 7 asks first, then closes the unit's module, though the test project still has the unit:
    a reference to the module held then goes bad - it is let go first, and the unit is opened again
    for the steps after }
  FUnitMod := nil;
  ExpectBox('Remove ' + Test.Values['Unit'] + '?', mrYes);
  FOther.RemoveFile(Test.Values['Unit']);
  Check(BoxSeen('Remove ' + Test.Values['Unit'] + '?'), 'RemoveFile asks first: "Remove <the file>?"');
  ExpectInt('RemoveFile takes it out of that project', FOther.GetModuleCount, Before);
  Check(Modules.FindModule(Test.Values['Unit']) = nil, '... and closes the unit''s module, of the test project too');
  if not Check((BorlandIDEServices as IOTAActionServices).OpenFile(Test.Values['Unit']), 'TestUnit opened again') then
    Exit;
  FUnitMod := Modules.FindModule(Test.Values['Unit']);
  if Check(FUnitMod <> nil, '... its module') then ExpectInt('TestUnit has one owner again', FUnitMod.OwnerCount, 1);
end;

{ a module creator owned by the project that is not active: the unit goes into its uses clause }
procedure TGroupTests.Creator;
var
  M: IOTAModule;
  Before: Integer;
begin
  if FOther = nil then Exit;
  Before := FOther.GetModuleCount;
  M := Modules.CreateModule(TGroupUnitCreator.Create(FOther, FNewUnit));
  if not Check(M <> nil, 'CreateModule with the second project as owner') then Exit;
  ExpectInt('the unit is the second project''s', FOther.GetModuleCount, Before + 1);
  Check(Pos('OtaGroupNew', EditorText(SourceEditorOf(FOther))) > 0, '... its source names it');
  Check(Pos('OtaGroupNew', EditorText(SourceEditorOf(FFirst))) = 0, 'the active project''s source does not');
  if Check(M.OwnerCount = 1, 'the new unit has one owner', IntToStr(M.OwnerCount)) then
    Check(SameModule(M.Owners[0], FOther), '... the second project');
  Check(SameModule(GetActiveProject, FFirst), 'the test project is still the active one');
end;

{ a unit of both projects saved under another name (IOTAModule.FileName, Save As): the uses
  clauses of both projects follow }
procedure TGroupTests.SharedRename;
var
  M: IOTAModule;
  NewFile: string;
begin
  if FOther = nil then Exit;
  NewFile := Dir + 'OtaGroupShared.pas';
  DeleteFile(NewFile);
  FFirst.AddFile(FOtherUnit, True);
  M := Modules.FindModule(FOtherUnit);
  if not Check(M <> nil, 'the second project''s unit is open (its project was shown)') then Exit;
  ExpectInt('... a unit of both projects now', M.OwnerCount, 2);
  M.FileName := NewFile;
  Check(SameText(M.FileName, NewFile), 'Save As of the unit of both projects', M.FileName);
  Check(Pos('OtaGroupShared in', EditorText(SourceEditorOf(FFirst))) > 0, 'the test project''s uses clause follows');
  Check(Pos('OtaGroupShared in', EditorText(SourceEditorOf(FOther))) > 0, 'the second project''s uses clause follows');
  Check(Pos('OtaGroupUnit', EditorText(SourceEditorOf(FOther))) = 0, '... the old name is gone there');
  { RemoveFile closes the unit's module (Delphi 7): it asks first, and - the unit renamed, not
    saved - whether to save it }
  M := nil;
  ExpectBox('Remove ' + NewFile + '?', mrYes);
  ExpectBox('Save changes to ' + ExtractFileName(NewFile) + '?', mrYes);
  FFirst.RemoveFile(NewFile);
  Check(BoxSeen('Remove ' + NewFile + '?'), 'RemoveFile of the unit of both projects asks first');
  Check(BoxSeen('Save changes to ' + ExtractFileName(NewFile) + '?'), '... and whether to save the renamed unit');
  Check(Modules.FindModule(NewFile) = nil, '... its module closed');
  Check(Pos('OtaGroupShared', EditorText(SourceEditorOf(FFirst))) = 0, 'the test project gives the unit back');
  Check(FFirst.Save(False, True), 'the test project saved');
  FOtherUnit := NewFile;
end;

{ the IDE's Project Options dialog - Delphi 7's or D7 Studio's, by no class name: the modal form
  shown }
procedure TGroupTests.OptTick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].Visible and (fsModal in Screen.Forms[I].FormState) then
    begin
      FOptCaption := Screen.Forms[I].Caption;
      Screen.Forms[I].ModalResult := mrCancel;
      FTimer.Enabled := False;
      Exit;
    end;
  if GetTickCount > FOptEnd then FTimer.Enabled := False;
end;

{ the options of the project that is not active: read, written, its Project Options dialog }
procedure TGroupTests.Options;
var
  O: IOTAProjectOptions;
begin
  if FOther = nil then Exit;
  O := FOther.ProjectOptions;
  if not Check(O <> nil, 'the second project''s options') then Exit;
  { run-time packages: a statically linked test program can be quarantined by a virus scanner }
  O.Values['UsePackages'] := True;
  O.Values['Packages'] := 'rtl';
  Check(O.Values['UsePackages'] = True, 'UsePackages reads back True');
  Expect('Packages reads back', VarToStr(O.Values['Packages']), 'rtl');
  Expect('the test project''s Packages stay', VarToStr(FFirst.ProjectOptions.Values['Packages']), 'rtl;vcl');
  FOptCaption := '';
  if FTimer = nil then FTimer := TTimer.Create(nil);
  FTimer.Interval := 150;
  FTimer.OnTimer := OptTick;
  FOptEnd := GetTickCount + 15000;
  FTimer.Enabled := True;
  O.EditOptions;
  FTimer.Enabled := False;
  Check(Pos('OtaGroupOther', FOptCaption) > 0, 'EditOptions shows the second project''s options', FOptCaption);
end;

function ExeOf(const ProjectFile: string): string;
begin
  Result := ChangeFileExt(ProjectFile, '.exe');
end;

{ BuildProject of the project that is not active: made, the active project unchanged }
procedure TGroupTests.Build;
begin
  if FOther = nil then Exit;
  DeleteFile(ExeOf(FOtherFile));
  Check(FOther.ProjectBuilder.BuildProject(cmOTABuild, True, True), 'BuildProject of the project that is not active');
  Check(FileExists(ExeOf(FOtherFile)), 'its program was made', ExeOf(FOtherFile));
  Check(SameModule(GetActiveProject, FFirst), 'the test project is still the active one');
end;

{ Save Project As of the project that is not active: the group's entry and the module follow. With
  a unit in a folder whose name is beyond ASCII: the project source - in the system code page -
  names it in that code page, after AddFile and after Save As (it is taken out again) }
procedure TGroupTests.SaveAs;
var
  G: IOTAProjectGroup;
  M: IOTAModule;
  Ch, CafeUnit, Raw: string;
  Before: Integer;
begin
  if FOther = nil then Exit;
  CafeUnit := '';
  Before := FOther.GetModuleCount;
  if D7StudioOnly('a unit in a folder beyond ASCII (D7 Studio''s UTF-8 mode)') and SystemCharE9(Ch) then
  begin
    ForceDirectories(Dir + 'Caf' + Ch);
    CafeUnit := Dir + 'Caf' + Ch + '\OtaGroupCafe.pas';
    WriteText(CafeUnit, 'unit OtaGroupCafe;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.');
    FOther.AddFile(CafeUnit, True);
    ExpectInt('AddFile of a unit in a folder beyond ASCII', FOther.GetModuleCount, Before + 1);
    Check(ProjectHasFile(FOther, CafeUnit), '... the project''s module names its file as it is', CafeUnit);
  end;
  FOther.FileName := FRenamed;
  G := Group;
  Check(SameText(FOther.FileName, FRenamed), 'the project''s module has the new name', FOther.FileName);
  { a new name alone writes nothing (Delphi 7); Save writes the source and its options there }
  Check(not FileExists(FRenamed), 'the new name alone writes nothing');
  Check(FOther.Save(False, True), 'the renamed project saved');
  Check(FileExists(FRenamed), '... its source written under the new name');
  Check(FileExists(ChangeFileExt(FRenamed, '.dof')), '... its options too');
  ExpectInt('the module notifier heard ModuleRenamed', FOtherNote.Renames, 1);
  Check(SameModule(GroupProjectOf(FRenamed), FOther), 'the group''s entry follows: the same module object');
  ExpectInt('the group has two projects still', G.ProjectCount, 2);
  Check(SameModule(GetActiveProject, FFirst), 'the test project is still the active one');
  Check(SameModule(Modules.FindModule(Test.Values['Unit']), FUnitMod), 'TestUnit is open still');
  if CafeUnit = '' then Exit;
  Raw := FileBytes(FRenamed);
  Check(Pos('Caf'#$E9'\OtaGroupCafe.pas', Raw) > 0, 'the renamed source names the unit in its code page');
  Check(Pos('Caf' + Ch + '\OtaGroupCafe.pas', Raw) = 0, '... not in UTF-8');
  Check(ProjectHasFile(FOther, CafeUnit), 'the renamed project''s module names the unit''s file as it is');
  ExpectBox('Remove ' + CafeUnit + '?', mrYes);
  FOther.RemoveFile(CafeUnit);
  ExpectInt('RemoveFile takes it out again', FOther.GetModuleCount, Before);
  M := Modules.FindModule(CafeUnit);
  if M <> nil then M.CloseModule(True);
  Check(FOther.Save(False, True), '... and the project is saved as it was');
end;

{ IOTAModule.CloseModule of a project: its own files close, it stays in the group closed }
procedure TGroupTests.CloseInGroup;
var
  G: IOTAProjectGroup;
begin
  if FOther = nil then Exit;
  Check(Modules.FindModule(FNewUnit) <> nil, 'its unit is open (made by the creator)');
  Check(FOther.CloseModule(True), 'CloseModule of the project that is not active');
  ExpectInt('its module was told Destroyed', FOtherNote.Destroys, 1);
  ExpectInt('ofnFileClosing of the project', FIde.Count('closing', FRenamed), 1);
  Check(Modules.FindModule(FNewUnit) = nil, 'its own unit closed with it');
  Check(Modules.FindModule(FOtherUnit) = nil, '... its other unit too');
  Check(SameModule(Modules.FindModule(Test.Values['Unit']), FUnitMod), 'TestUnit is open still');
  G := Group;
  ExpectInt('it stays in the group (closed): ProjectCount', G.ProjectCount, 2);
  { Delphi 7's Projects[] in its place gave a project without a file name at once and the group's
    first a step later (measured): no project of its own is what holds }
  Check(GroupProjectOf(FRenamed) = nil, 'Projects gives no project for it while it is closed');
  Check(SameModule(GetActiveProject, FFirst), 'the test project is still the active one');
  ExpectInt('the test project''s module was not told Destroyed', FFirstNote.Destroys, 0);
  FOther := nil;
  FOtherMod := nil;
  FOtherNoteIntf := nil;
end;

{ SetActiveProject of the closed project: it is loaded again }
{ The closed project opened again into the group (Delphi 7's Projects gives none of its own to
  activate - for it Projects[1] gave the first project): loaded and the active project }
procedure TGroupTests.Reactivate;
var
  G: IOTAProjectGroup;
begin
  G := Group;
  if not Check((BorlandIDEServices as IOTAActionServices).OpenProject(FRenamed, False),
    'OpenProject of the closed project, in the group') then Exit;
  Check(SameText(GetActiveProject.FileName, FRenamed), '... loaded again and the active project',
    GetActiveProject.FileName);
  ExpectInt('... still two projects in the group', G.ProjectCount, 2);
  ExpectInt('ofnFileOpened of the project loaded again', FIde.Count('opened', FRenamed), 1);
  ExpectInt('ofnActiveProjectChanged with its file', FIde.Count('active', FRenamed), 1);
  ExpectInt('its units: OtaGroupUnit, OtaGroupNew', GetActiveProject.GetModuleCount, 2);
  FOther := GetActiveProject;
  G.SetActiveProject(FFirst);
  Check(SameModule(G.ActiveProject, FFirst), 'the test project active again');
end;

{ IOTAProjectGroup.RemoveProject: out of the group; its module stays, a project owned by no module,
  its units closed (Delphi 7) - CloseModule closes it }
procedure TGroupTests.Remove;
var
  G: IOTAProjectGroup;
  Note: TGroupModuleNotifier;
  NoteIntf: IOTAModuleNotifier;
  M: IOTAModule;
begin
  G := Group;
  if (G = nil) or (FOther = nil) then Exit;
  Note := TGroupModuleNotifier.Create;
  NoteIntf := Note;
  FOther.AddNotifier(NoteIntf);
  G.RemoveProject(FOther);
  FOther := nil;
  ExpectInt('the group has the test project alone', G.ProjectCount, 1);
  Check(GroupProjectOf(FRenamed) = nil, 'the removed project is no project of the group');
  M := Modules.FindModule(FRenamed);
  if Check(Supports(M, IOTAProject), 'its module stays, a project') then
  begin
    ExpectInt('... owned by no module', M.OwnerModuleCount, 0);
    Check(Modules.FindModule(FNewUnit) = nil, '... its unit closed');
    ExpectInt('... not told Destroyed', Note.Destroys, 0);
    Check(M.CloseModule(True), 'CloseModule of the removed project');
    M := nil;
    ExpectInt('... now told Destroyed (Delphi 7: twice)', Note.Destroys, IdeValue(2, 1));
    Check(Modules.FindModule(FRenamed) = nil, '... no module any more');
  end;
  Check(SameModule(GetActiveProject, FFirst), 'the test project is the active one');
  Check(SameModule(Modules.FindModule(Test.Values['Unit']), FUnitMod), 'TestUnit is open still');
  ExpectInt('the test project''s module was never told Destroyed', FFirstNote.Destroys, 0);
end;

type
  { a window looked for by EnumThreadWindows / EnumChildWindows: its class (and control ID, -1 any) }
  TWindowFind = record
    WndClass: PChar;
    Id: Integer;
    Found: HWND;
  end;
  PWindowFind = ^TWindowFind;

function WindowFound(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
var
  F: PWindowFind;
  Name: array[0..63] of Char;
begin
  F := PWindowFind(Param);
  Result := True;
  if IsWindowVisible(Wnd) and (GetClassName(Wnd, Name, SizeOf(Name)) > 0) and (StrIComp(Name, F^.WndClass) = 0) and
    ((F^.Id < 0) or (GetDlgCtrlID(Wnd) = F^.Id)) then
  begin
    F^.Found := Wnd;
    Result := False;
  end;
end;

{ a window of the class (and ID) among Parent's descendants - 0: a top-level window of this thread }
function FindWindowOf(Parent: HWND; WndClass: PChar; Id: Integer): HWND;
var
  F: TWindowFind;
begin
  F.WndClass := WndClass;
  F.Id := Id;
  F.Found := 0;
  if Parent = 0 then EnumThreadWindows(GetCurrentThreadId, @WindowFound, LPARAM(@F))
  else EnumChildWindows(Parent, @WindowFound, LPARAM(@F));
  Result := F.Found;
end;

{ File | Open's dialog: the file's full name into its name box (the edit of the ComboBoxEx32 with
  ID 1148), then OK }
procedure TGroupTests.OpenTick(Sender: TObject);
var
  Dlg, Edit: HWND;
begin
  Dlg := FindWindowOf(0, '#32770', -1);
  Edit := 0;
  if Dlg <> 0 then Edit := FindWindowOf(FindWindowOf(Dlg, 'ComboBoxEx32', 1148), 'Edit', -1);
  if Edit <> 0 then
  begin
    SetWindowTextW(Edit, PWideChar(WideString(FOpenName)));
    PostMessage(Dlg, WM_COMMAND, IDOK, 0);
    FTimer.Enabled := False;
  end
  else if GetTickCount > FOpenEnd then
    FTimer.Enabled := False;
end;

{ File | Open of a file as the user does it - the main window's command, its dialog given the
  file (OpenTick): a package opens beside the group so (IOTAActionServices.OpenFile opens one in a
  group of its own, as Delphi 7's does) }
function TGroupTests.OpenByFileOpen(const FileName: string): Boolean;
var
  A: TContainedAction;
begin
  Result := False;
  A := IdeAction('FileOpenCommand');
  if not Check(A <> nil, 'the action FileOpenCommand (File | Open)') then Exit;
  if FTimer = nil then FTimer := TTimer.Create(nil);
  FTimer.Interval := 150;
  FTimer.OnTimer := OpenTick;
  FOpenName := FileName;
  FOpenEnd := GetTickCount + 15000;
  FTimer.Enabled := True;
  OwnDialogs(True);
  try
    A.Execute;
  finally
    OwnDialogs(False);
  end;
  FTimer.Enabled := False;
  Result := True;
end;

{ the module is one of IOTAModuleServices.Modules }
function Listed(const M: IOTAModule): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Modules.ModuleCount - 1 do
    if SameModule(Modules.Modules[I], M) then
    begin
      Result := True;
      Exit;
    end;
end;

{ File | Open of a package while the group is open: beside the group (Delphi's misc package) - a
  module, the active project, no project of the group, owned by no module, the owner of its unit;
  SetActiveProject switches to it and back; Save Project As renames it in place (owned by no module
  also while ModuleRenamed is told); CloseModule closes it with its unit }
procedure TGroupTests.Beside;
var
  G: IOTAProjectGroup;
  M, U: IOTAModule;
  P: IOTAProject;
  Count: Integer;
  Note: TGroupModuleNotifier;
  NoteIntf: IOTAModuleNotifier;
  NewFile: string;
  Owned: Boolean;
begin
  G := Group;
  if not Check(G <> nil, 'the project group') then Exit;
  Count := G.ProjectCount;
  if not OpenByFileOpen(FPkgFile) then Exit;
  M := Modules.FindModule(FPkgFile);
  if not Check(Supports(M, IOTAProject, P), 'the package is a module, an IOTAProject') then Exit;
  Check(Listed(M), '... in the module list');
  ExpectInt('it is no project of the group', G.ProjectCount, Count);
  Check(GroupProjectOf(FPkgFile) = nil, '... Projects does not list it');
  Check(SameModule(GetActiveProject, P), 'it is the active project (ToolsAPI''s GetActiveProject)');
  ExpectInt('ofnFileOpened of the package', FIde.Count('opened', FPkgFile), 1);
  ExpectInt('ofnActiveProjectChanged with its file', FIde.Count('active', FPkgFile), 1);
  ExpectInt('owned by no module (a package outside the open group)', M.OwnerModuleCount, 0);
  if Check(FFirst.OwnerModuleCount = 1, 'the test project''s owner module: one', IntToStr(FFirst.OwnerModuleCount)) then
  begin
    { with a package beside the group Delphi 7 raises EIntfCastError here - its bug; D7 Studio
      answers the group }
    try
      Owned := SameModule(FFirst.OwnerModules[0], G) and not IdeIsDelphi7;
    except
      on E: EIntfCastError do Owned := IdeIsDelphi7;
    end;
    Check(Owned, '... the group''s (Delphi 7: EIntfCastError, its bug)');
  end;
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(FPkgUnit), 'its unit opened');
  U := Modules.FindModule(FPkgUnit);
  if Check(U <> nil, '... a module') and Check(U.OwnerCount = 1, '... with one owner', IntToStr(U.OwnerCount)) then
    Check(SameModule(U.Owners[0], P), '... the package beside the group');
  G.SetActiveProject(FFirst);
  Check(SameModule(G.ActiveProject, FFirst), 'SetActiveProject: the test project is active again');
  Check(SameModule(Modules.FindModule(FPkgFile), M), 'the package stays open, the same module');
  G.SetActiveProject(P);
  Check(SameModule(G.ActiveProject, FFirst), 'SetActiveProject does not take the package beside the group');
  ExpectInt('... no project of the group still', G.ProjectCount, Count);
  G.SetActiveProject(FFirst);
  Note := TGroupModuleNotifier.Create;
  NoteIntf := Note;
  M.AddNotifier(NoteIntf);
  { Save Project As of the package beside the group: its entry follows before its module, so the
    module's notifiers already find it beside the group (no owner module) }
  NewFile := Dir + 'OtaGroupPkgRenamed.dpk';
  DeleteFile(NewFile);
  DeleteFile(ChangeFileExt(NewFile, '.dof'));
  DeleteFile(ChangeFileExt(NewFile, '.res'));
  Note.Owner := M;
  Note.OwnersAtRename := -1;
  M.FileName := NewFile;
  Note.Owner := nil;
  Check(SameText(M.FileName, NewFile), 'Save Project As of the package beside the group', M.FileName);
  ExpectInt('... ModuleRenamed told once', Note.Renames, 1);
  ExpectInt('... while it was told, owned by no module', Note.OwnersAtRename, 0);
  ExpectInt('... owned by no module after it', M.OwnerModuleCount, 0);
  Check(GroupProjectOf(NewFile) = nil, '... no project of the group');
  Check(Listed(M), '... in the module list under its new name');
  FPkgFile := NewFile;
  U := nil;
  P := nil;
  Check(M.CloseModule(True), 'CloseModule of the package beside the group');
  ExpectInt('its module was told Destroyed', Note.Destroys, 1);
  ExpectInt('ofnFileClosing of the package', FIde.Count('closing', FPkgFile), 1);
  Check(Modules.FindModule(FPkgFile) = nil, 'it is no module any more');
  Check(Modules.FindModule(FPkgUnit) = nil, 'its unit closed with it');
  ExpectInt('the group''s projects stay', G.ProjectCount, Count);
  Check(SameModule(GetActiveProject, FFirst), 'the test project is the active one');
end;

{ the page shown before the area again }
procedure TGroupTests.Restore;
var
  E: IOTASourceEditor;
begin
  if FShown <> nil then
  begin
    E := SourceEditorOf(FShown);
    if E <> nil then E.Show;
  end;
  ExpectInt('the module count as before the area', Modules.ModuleCount, FModuleCount);
end;

initialization
  RegisterTestArea(TGroupTests, 45);
end.
