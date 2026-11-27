{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestServices2;

(* The self-test's areas of the second batch of services (OtaDemoTest), with the experts of
   OtaDemoServices2:
   * ModuleData: IOTAAdditionalFilesModuleCreator - a form's unit whose text names a file of its own
     ({$R *.dfm} followed by the comment {*.xyz}) and a file the creator names, written when the
     module is saved; the module's IOTAAdditionalModuleFiles (their source editors, of the unit's
     module), IOTAModuleInfo.GetAdditionalFiles, IOTAModuleData.HasObjects (a unit with a form,
     the project).
   * TypeLib: stdole2.tlb opened (IOTAActionServices.OpenFile: View | Type Library) is a module
     of its own, IOTATypeLibModule; its one editor is the source editor of its unit stdole_TLB.pas
     in the library's folder, the import's text in memory, and it has no current editor (Delphi
     7's); CloseModule empties the view, the module goes.
   * ToolsFilter: BorlandIDEServices has no IOTAToolsFilter, as Delphi 7's (D7 Studio keeps the
     code: the steps check a filter registered, found by its name in any case, run over a tool's
     output by the expert, removed - told Destroyed - and added again, when the service is there).
   * Speed: IOTAEditOptions' speed settings - Delphi 7's six, one list for every IOTAEditOptions,
     an expert's added, run by its name (SetSpeedSetting) with the options it was called on, an
     unknown name raising Delphi's exception, Delphi's BRIEF record and back (only when the test
     runs unattended: it changes the key mapping), removed again. The editor options are put
     back afterwards.
   * Highlight: IOTAHighlightServices - Delphi 7's ten highlighters; an expert's set as the
     highlighter of a source file type (IOTAEditOptions.SyntaxHighlighter) colours a file of the
     type in the code editor: GetAttributeAtPos gives its codes, the class of a line ends a
     comment of the line before; removed, the file is plain text (SyntaxOff), added again it is
     coloured again.
   * FileSystem: IOTAFileSystem - creators of existing files (the creator's text, else a text
     creator's empty module, a unit creator's new unit: the file is never read), a file of a file
     system in memory opened as a module (IOTACreator.GetFileSystem) with the text its creator reads
     from it, saved through it in Delphi 7's order of calls; SetFileSystem of an unknown one raises Delphi's exception; Delphi 7's
     RemoveFileSystem and FindFileSystem (EListError, Delphi's exception).
   * Record: IOTARecord and the keyboard services' records - Delphi's stream format, a record
     played key by key in the code editor (one undo step), a pause by an expert's key binding and
     the playback going on, an expert's own record ignored; Edit | Record Macro and Play Macro
     (the IDE's record of the keyboard services).
   * CustomMessages: IOTACustomMessage50 - a message with children, closed when added (Right and
     + open it, Left and - close it), a child that draws itself (INTACustomDrawMessage), F1 on an
     expert's message (ShowHelp); a tool message's children closed too; the messages released
     with the group's. The script checks the closed message in the Messages view (EXPECT). *)

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Menus, ActnList, ActiveX, ToolsAPI,
  OtaDemoTest, OtaDemoServices2;

function Modules: IOTAModuleServices;
begin
  Result := BorlandIDEServices as IOTAModuleServices;
end;

function Editors: IOTAEditorServices;
begin
  Result := BorlandIDEServices as IOTAEditorServices;
end;

function Keyboard: IOTAKeyboardServices;
begin
  Result := BorlandIDEServices as IOTAKeyboardServices;
end;

function Actions: IOTAActionServices;
begin
  Result := BorlandIDEServices as IOTAActionServices;
end;

{ a file of the test, its bytes as given }
procedure WriteText(const FileName, Text: string);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFilePath(FileName));
  F := TFileStream.Create(FileName, fmCreate);
  try
    if Text <> '' then F.WriteBuffer(Text[1], Length(Text));
  finally
    F.Free;
  end;
end;

function BufferOf(const FileName: string): IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  M := Modules.FindModule(FileName);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

{ line N (1-based) of a file's buffer, without its line break }
function BufferLine(const FileName: string; N: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := EditorText(BufferOf(FileName));
    if (N >= 1) and (N <= L.Count) then Result := L[N - 1] else Result := '';
  finally
    L.Free;
  end;
end;

function JoinLines(L: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to L.Count - 1 do
  begin
    if I > 0 then Result := Result + '; ';
    Result := Result + L[I];
  end;
end;

procedure CloseFileModule(const FileName: string);
var
  M: IOTAModule;
begin
  M := Modules.FindModule(FileName);
  if M <> nil then M.CloseModule(True);
end;

{ ---------------------------------------------------------------- windows of the IDE }

type
  TFindWindow = record
    Cls, FirstRow: string;   // a list box (FirstRow its row 0) or a code editor (FirstRow its line 1)
    Wnd: HWND;
  end;
  PFindWindow = ^TFindWindow;

function RowText(Wnd: HWND; Row: Integer): string;
var
  N: Integer;
begin
  Result := '';
  N := SendMessage(Wnd, LB_GETTEXTLEN, Row, 0);
  if N <= 0 then Exit;
  SetLength(Result, N + 1);
  N := SendMessage(Wnd, LB_GETTEXT, Row, LPARAM(PChar(Result)));
  if N < 0 then N := 0;
  SetLength(Result, N);
end;

function FindChildProc(Wnd: HWND; Data: LPARAM): BOOL; stdcall;
var
  Cls: array[0..63] of Char;
  F: PFindWindow;
begin
  Result := True;
  F := PFindWindow(Data);
  GetClassName(Wnd, Cls, SizeOf(Cls));
  if (StrComp(Cls, PChar(F^.Cls)) <> 0) or (SendMessage(Wnd, LB_GETCOUNT, 0, 0) <= 0) then Exit;
  if RowText(Wnd, 0) = F^.FirstRow then
  begin
    F^.Wnd := Wnd;
    Result := False;
  end;
end;

function FindTopProc(Wnd: HWND; Data: LPARAM): BOOL; stdcall;
begin
  EnumChildWindows(Wnd, @FindChildProc, Data);
  Result := PFindWindow(Data)^.Wnd = 0;
end;

{ a list box of the IDE's thread: of the class, whose first row is FirstRow }
function FindIdeWindow(const Cls, FirstRow: string): HWND;
var
  F: TFindWindow;
begin
  F.Cls := Cls;
  F.FirstRow := FirstRow;
  F.Wnd := 0;
  EnumThreadWindows(GetCurrentThreadId, @FindTopProc, LPARAM(@F));
  Result := F.Wnd;
end;

{ ---------------------------------------------------------------- ModuleData }

type
  TModuleDataTests = class(TOtaTestArea)
  private
    FFolder, FUnit: string;
    procedure CreateUnit;
    procedure Saved;
    procedure Objects;
    procedure ModuleInfo;
    procedure CloseUnit;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function TModuleDataTests.Name: string;
begin
  Result := 'ModuleData';
end;

procedure TModuleDataTests.AddSteps;
begin
  Step('CreateUnit', CreateUnit);
  Step('Saved', Saved);
  Step('HasObjects', Objects);
  Step('ModuleInfo', ModuleInfo);
  Step('Close', CloseUnit);
end;

procedure DeleteFiles(const Folder: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Folder + '*.*', faAnyFile and not faDirectory, SR) = 0 then
  begin
    repeat
      DeleteFile(Folder + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ Delphi 7's (measured): a new module is written when it is saved - the unit modified, its form
  not, the additional files modified }
procedure TModuleDataTests.CreateUnit;
var
  M: IOTAModule;
  AF: IOTAAdditionalModuleFiles;
  MD: IOTAModuleData;
  S: IOTASourceEditor;
begin
  FFolder := Dir + 'DemoAF\';
  DeleteFiles(FFolder);
  ForceDirectories(FFolder);
  FUnit := FFolder + 'DemoAF.pas';
  M := Modules.CreateModule(TDemoAddCreator.Create(FUnit, GetActiveProject));
  if not Check(M <> nil, 'CreateModule with an IOTAAdditionalFilesModuleCreator') then Exit;
  Check(not FileExists(FUnit) and not FileExists(ChangeFileExt(FUnit, '.dfm')),
    'nothing written yet: a new module is written when it is saved');
  if ExpectInt('its files: the unit and its form', M.ModuleFileCount, 2) then
  begin
    Check(M.ModuleFileEditors[0].Modified, 'the unit is modified');
    Check(not M.ModuleFileEditors[1].Modified, 'its form is not');
  end;
  if not Check(Supports(M, IOTAAdditionalModuleFiles, AF), 'the module has IOTAAdditionalModuleFiles') then Exit;
  if not ExpectInt('two additional files: the one its text names, the one the creator names',
    AF.AdditionalModuleFileCount, 2) then Exit;
  Check(SameText(AF.AdditionalModuleFileEditors[0].FileName, FFolder + 'DemoAF.xyz'),
    'file 0: the unit''s name with the extension its text and the creator name', AF.AdditionalModuleFileEditors[0].FileName);
  Check(SameText(AF.AdditionalModuleFileEditors[1].FileName, FFolder + 'DemoAF.notes.txt'),
    'file 1: the name the creator gives', AF.AdditionalModuleFileEditors[1].FileName);
  Check(AF.AdditionalModuleFileEditors[0].Modified and AF.AdditionalModuleFileEditors[1].Modified,
    'both are modified');
  Check(not FileExists(FFolder + 'DemoAF.xyz') and not FileExists(FFolder + 'DemoAF.notes.txt'),
    'neither is written yet');
  if Check(Supports(AF.AdditionalModuleFileEditors[0], IOTASourceEditor, S), 'file 0 has a source editor') then
    Check(Pos('the xyz file of DemoAF', EditorText(S)) > 0, 'its reader gives the creator''s source', EditorText(S));
  Check(SameModule(AF.AdditionalModuleFileEditors[1].Module, M), 'the file belongs to the unit''s module');
  Check(Supports(M, IOTAModuleData, MD) and MD.HasObjects, 'IOTAModuleData.HasObjects: a unit with its form has them');
end;

{ IOTAModule.Save writes the unit, its form and the additional files - in Delphi 7 not the one the
  creator names }
procedure TModuleDataTests.Saved;
var
  M: IOTAModule;
begin
  M := Modules.FindModule(FUnit);
  if not Check(M <> nil, 'the unit is a module') then Exit;
  Check(M.Save(False, True), 'IOTAModule.Save');
  Check(FileExists(FUnit) and FileExists(ChangeFileExt(FUnit, '.dfm')), 'the unit and its form were written');
  Check(FileExists(FFolder + 'DemoAF.xyz'), 'the additional file its text names was written');
  Check(FileExists(FFolder + 'DemoAF.notes.txt') = not IdeIsDelphi7,
    'the one the creator names: written (Delphi 7 writes it not)');
end;
procedure TModuleDataTests.Objects;
var
  M: IOTAModule;
  MD: IOTAModuleData;
begin
  M := Modules.FindModule(Test.Values['Unit']);
  if Check(M <> nil, 'TestUnit is open') then
    Check(Supports(M, IOTAModuleData, MD) and MD.HasObjects, 'HasObjects: a unit with a form has them');
  Check(Supports(GetActiveProject, IOTAModuleData, MD) and not MD.HasObjects, 'HasObjects: the project has none');
end;

procedure TModuleDataTests.ModuleInfo;
var
  P: IOTAProject;
  Info: IOTAModuleInfo;
  L: TStringList;
  I: Integer;
  Found: Boolean;
begin
  P := GetActiveProject;
  if not Check(P <> nil, 'there is an active project') then Exit;
  Info := nil;
  for I := 0 to P.GetModuleCount - 1 do
    if SameText(P.GetModule(I).Name, 'DemoAF') then Info := P.GetModule(I);
  if not Check(Info <> nil, 'the creator''s owner, the project, has the unit') then Exit;
  L := TStringList.Create;
  try
    Info.GetAdditionalFiles(L);
    Found := False;
    for I := 0 to L.Count - 1 do
      if SameText(ExtractFileName(L[I]), 'DemoAF.xyz') then Found := True;
    Check(Found, 'IOTAModuleInfo.GetAdditionalFiles lists DemoAF.xyz', L.CommaText);
  finally
    L.Free;
  end;
end;

procedure TModuleDataTests.CloseUnit;
begin
  Cleanup;
  Check(Modules.FindModule(FFolder + 'DemoAF.pas') = nil, 'the unit is closed and out of the project');
end;

procedure TModuleDataTests.Cleanup;
var
  P: IOTAProject;
begin
  if FUnit = '' then Exit;
  P := GetActiveProject;
  { RemoveFile asks first and closes the unit's module (Delphi 7) }
  ExpectBox('Remove ' + FUnit + '?', mrYes);
  if P <> nil then P.RemoveFile(FUnit);
  CloseFileModule(FUnit);
  { D7 Studio's pages of the additional files (Delphi 7 has no modules of them) }
  CloseFileModule(FFolder + 'DemoAF.xyz');
  CloseFileModule(FFolder + 'DemoAF.notes.txt');
  DeleteFiles(FFolder);
  RemoveDir(FFolder);
  FUnit := '';
end;

{ ---------------------------------------------------------------- TypeLib }

type
  TTypeLibTests = class(TOtaTestArea)
  private
    FLib, FUnitFile: string;
    function LibModule(out Count: Integer): IOTAModule;
    function CheckUnitEditor(const M: IOTAModule): Boolean;
    procedure Open;
    procedure UnitEditor;
    procedure CloseLib;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function TTypeLibTests.Name: string;
begin
  Result := 'TypeLib';
end;

procedure TTypeLibTests.AddSteps;
begin
  Step('Open', Open);
  Step('Unit', UnitEditor);
  Step('Close', CloseLib);
end;

{ the module that is a type library (IOTATypeLibModule); Count: how many are }
function TTypeLibTests.LibModule(out Count: Integer): IOTAModule;
var
  I: Integer;
begin
  Result := nil;
  Count := 0;
  for I := 0 to Modules.ModuleCount - 1 do
    if Supports(Modules.Modules[I], IOTATypeLibModule) then
    begin
      Inc(Count);
      Result := Modules.Modules[I];
    end;
end;

{ editor 0 of the library's module: the source editor of its unit in the library's folder }
function TTypeLibTests.CheckUnitEditor(const M: IOTAModule): Boolean;
var
  S: IOTASourceEditor;
begin
  Result := False;
  if not ExpectInt('one editor: the library''s unit', M.ModuleFileCount, 1) then Exit;
  Check(SameText(M.ModuleFileEditors[0].FileName, ExtractFilePath(FLib) + 'stdole_TLB.pas'),
    'editor 0: stdole_TLB.pas in the library''s folder', M.ModuleFileEditors[0].FileName);
  if not Check(Supports(M.ModuleFileEditors[0], IOTASourceEditor, S), '... a source editor') then Exit;
  Check(Pos('unit stdole_TLB;', EditorText(S)) = 1, '... of the unit the import makes', Copy(EditorText(S), 1, 40));
  Check(not S.Modified, '... not modified');
  Check(not FileExists(S.FileName), '... in memory: the file is not written');
  Check(M.CurrentEditor = nil, 'no current editor');
  Result := True;
end;

{ Delphi 7's (measured): the library's module has one editor, the unit it would generate - in
  memory, in the library's folder, not modified -, and no current editor }
procedure TTypeLibTests.Open;
var
  Buf: array[0..MAX_PATH] of Char;
  M: IOTAModule;
  N: Integer;
begin
  SetString(FLib, Buf, GetSystemDirectory(Buf, SizeOf(Buf)));
  FLib := IncludeTrailingPathDelimiter(FLib) + 'stdole2.tlb';
  if not Check(FileExists(FLib), 'the type library ' + FLib + ' is there') then Exit;
  Check(Actions.OpenFile(FLib), 'IOTAActionServices.OpenFile opens it in View | Type Library');
  M := LibModule(N);
  ExpectInt('one module is a type library (IOTATypeLibModule)', N, 1);
  if M = nil then Exit;
  Check(SameText(M.FileName, FLib), 'its file name is the library''s', M.FileName);
  CheckUnitEditor(M);
  Check(SameModule(Modules.FindModule(FLib), M), 'FindModule finds it');
end;

{ a stdole_TLB.pas of another folder opened: the module's editor stays its own }
procedure TTypeLibTests.UnitEditor;
var
  M: IOTAModule;
  N: Integer;
begin
  FUnitFile := Dir + 'stdole_TLB.pas';
  WriteText(FUnitFile, 'unit stdole_TLB;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.'#13#10);
  Check(Actions.OpenFile(FUnitFile), 'a stdole_TLB.pas of another folder opened');
  M := LibModule(N);
  if not Check(M <> nil, 'the library is still a module') then Exit;
  CheckUnitEditor(M);
end;
procedure TTypeLibTests.CloseLib;
var
  M: IOTAModule;
  N: Integer;
begin
  M := LibModule(N);
  if not Check(M <> nil, 'the library is a module') then Exit;
  Check(M.CloseModule(True), 'CloseModule');
  M := nil;
  LibModule(N);
  ExpectInt('no module is a type library any more: the view is empty', N, 0);
  Check(Modules.FindModule(FLib) = nil, 'FindModule finds it no more');
  Cleanup;
end;

procedure TTypeLibTests.Cleanup;
begin
  if FUnitFile = '' then Exit;
  CloseFileModule(FUnitFile);
  DeleteFile(FUnitFile);
  FUnitFile := '';
end;

{ ---------------------------------------------------------------- ToolsFilter }

type
  TPlainNotifier = class(TNotifierObject, IOTANotifier);

  TToolsFilterTests = class(TOtaTestArea)
  private
    FTF: IOTAToolsFilter;
    FFilter: TDemoToolsFilter;
    FFilterIntf: IOTAToolsFilterNotifier;
    FIndex: Integer;
    procedure Register;
    procedure Find;
    procedure Run;
    procedure Remove;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

const
  TestFilterName = 'OTA Self-Test filter';

function TToolsFilterTests.Name: string;
begin
  Result := 'ToolsFilter';
end;

procedure TToolsFilterTests.AddSteps;
begin
  FIndex := -1;
  Step('Register', Register);
  Step('Find', Find);
  Step('Run', Run);
  Step('Remove', Remove);
end;

{ Delphi 7's BorlandIDEServices has no IOTAToolsFilter, nor has D7 Studio's (it keeps the code, not
  the service); the steps after it check a service that is there }
procedure TToolsFilterTests.Register;
var
  Plain: IOTANotifier;
begin
  Check(not Supports(BorlandIDEServices, IOTAToolsFilter, FTF), 'BorlandIDEServices has no IOTAToolsFilter (Delphi 7''s)');
  Check(not Supports(BorlandIDEServices, IOTAToolsFilter60), '... nor IOTAToolsFilter60');
  if FTF = nil then Exit;
  FFilter := TDemoToolsFilter.Create(TestFilterName);
  FFilterIntf := FFilter;
  FIndex := FTF.AddNotifier(FFilterIntf);
  Check(FIndex >= 0, 'AddNotifier of a filter');
  Plain := TPlainNotifier.Create;
  ExpectInt('a notifier that is no filter is not taken', FTF.AddNotifier(Plain), -1);
end;

procedure TToolsFilterTests.Find;
begin
  if FTF = nil then Exit;
  Check(SameModule(FTF.FindFilter('ota self-test FILTER'), FFilterIntf), 'FindFilter: by its name, in any case');
  Check(FTF.FindFilter('x') = nil, 'FindFilter of another name: nil');
end;

procedure TToolsFilterTests.Run;
var
  F: IOTAToolsFilterNotifier;
  O, E: TStringList;
begin
  if (FTF = nil) or not Check(Supports(FTF.FindFilter(TestFilterName), IOTAToolsFilterNotifier, F),
    'the filter found is an IOTAToolsFilterNotifier') then Exit;
  O := TStringList.Create;
  E := TStringList.Create;
  try
    O.Add('hello');
    E.Add('oops');
    F.Filter('Sample.pas', 3, O, E);
  finally
    E.Free;
    O.Free;
  end;
  Expect('the expert ran the filter over a tool''s output', FFilter.LastText, '[filter] Sample.pas code=3 out=hello err=oops');
end;

procedure TToolsFilterTests.Remove;
begin
  if FTF = nil then Exit;
  FTF.RemoveNotifier(FIndex);
  FIndex := -1;
  ExpectInt('RemoveNotifier told it Destroyed', FFilter.DestroyedCalls, 1);
  Check(FTF.FindFilter(TestFilterName) = nil, 'removed: FindFilter finds it no more');
  FIndex := FTF.AddNotifier(FFilterIntf);
  Check(SameModule(FTF.FindFilter(TestFilterName), FFilterIntf), 'added again: found again');
  Cleanup;
end;

procedure TToolsFilterTests.Cleanup;
begin
  if (FTF <> nil) and (FIndex >= 0) then FTF.RemoveNotifier(FIndex);
  FIndex := -1;
end;

{ ---------------------------------------------------------------- Speed }

type
  TOptionsCopy = record
    IDs, TabStops: TStringList;
    Indents, AutoIndents, KeepBlanks: array of Integer;
    InsertMode, ThroughTabs, GroupUndo, Persistent, Overwrite, BriefCursors, BriefRegExp, ForceCut: Boolean;
  end;

  TSpeedTests = class(TOtaTestArea)
  private
    FSpeed: TDemoSpeed;
    FSpeedIntf: IOTASpeedSetting;
    FIndex, FCount: Integer;
    FSaved: Boolean;
    FCopy: TOptionsCopy;
    function Pascal: IOTAEditOptions;
    procedure SaveOptions;
    procedure RestoreOptions;
    procedure Builtins;
    procedure Add;
    procedure Run;
    procedure Invalid;
    procedure Brief;
    procedure Remove;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

const
  TestSpeedName = 'D7Studio.OtaSelfTest.Speed';

function TSpeedTests.Name: string;
begin
  Result := 'Speed';
end;

procedure TSpeedTests.AddSteps;
begin
  FIndex := -1;
  Step('Builtins', Builtins);
  Step('Add', Add);
  Step('Run', Run);
  Step('Invalid', Invalid);
  Step('Brief', Brief);
  Step('Remove', Remove);
end;

function TSpeedTests.Pascal: IOTAEditOptions;
begin
  Result := Editors.GetEditOptionsForFile('x.pas');
end;

{ what the speed settings change, of every source file type and the general ones }
procedure TSpeedTests.SaveOptions;
var
  I, N: Integer;
  O: IOTAEditOptions;
  B: IOTABufferOptions;
begin
  N := Editors.EditOptionsCount;
  FCopy.IDs := TStringList.Create;
  FCopy.TabStops := TStringList.Create;
  SetLength(FCopy.Indents, N);
  SetLength(FCopy.AutoIndents, N);
  SetLength(FCopy.KeepBlanks, N);
  for I := 0 to N - 1 do
  begin
    O := Editors.EditorOptions[I];
    B := O.BufferOptions;
    FCopy.IDs.Add(O.IDString);
    FCopy.TabStops.Add(B.TabStops);
    FCopy.Indents[I] := O.BlockIndent;
    FCopy.AutoIndents[I] := Ord(B.AutoIndent);
    FCopy.KeepBlanks[I] := Ord(B.KeepTrailingBlanks);
  end;
  O := Pascal;
  B := O.BufferOptions;
  FCopy.InsertMode := B.InsertMode;
  FCopy.ThroughTabs := B.CursorThroughTabs;
  FCopy.GroupUndo := B.GroupUndo;
  FCopy.Persistent := B.PersistentBlocks;
  FCopy.Overwrite := B.OverwriteBlocks;
  FCopy.BriefCursors := O.UseBriefCursorShapes;
  FCopy.BriefRegExp := O.UseBriefRegularExpressions;
  FCopy.ForceCut := O.ForceCutCopyEnabled;
  FSaved := True;
end;

procedure TSpeedTests.RestoreOptions;
var
  I: Integer;
  O: IOTAEditOptions;
  B: IOTABufferOptions;
begin
  if not FSaved then Exit;
  FSaved := False;
  for I := 0 to FCopy.IDs.Count - 1 do
  begin
    O := Editors.GetEditOptions(FCopy.IDs[I]);
    if O = nil then Continue;
    B := O.BufferOptions;
    O.BlockIndent := FCopy.Indents[I];
    B.TabStops := FCopy.TabStops[I];
    B.AutoIndent := FCopy.AutoIndents[I] <> 0;
    B.KeepTrailingBlanks := FCopy.KeepBlanks[I] <> 0;
  end;
  O := Pascal;
  B := O.BufferOptions;
  B.InsertMode := FCopy.InsertMode;
  B.CursorThroughTabs := FCopy.ThroughTabs;
  B.GroupUndo := FCopy.GroupUndo;
  B.PersistentBlocks := FCopy.Persistent;
  B.OverwriteBlocks := FCopy.Overwrite;
  O.UseBriefCursorShapes := FCopy.BriefCursors;
  O.UseBriefRegularExpressions := FCopy.BriefRegExp;
  O.ForceCutCopyEnabled := FCopy.ForceCut;
  FreeAndNil(FCopy.IDs);
  FreeAndNil(FCopy.TabStops);
end;

procedure TSpeedTests.Builtins;
const
  Names: array[0..5] of string = ('Borland.Default', 'Borland.Classic', 'Borland.Brief',
    'Borland.Epsilon', 'Borland.VisualStudio', 'Borland.VisualBasic');
var
  O: IOTAEditOptions;
  I: Integer;
  S, Want: string;
begin
  SaveOptions;
  O := Pascal;
  if not Check(O <> nil, 'the Pascal options') then Exit;
  FCount := O.SpeedSettingCount;
  Check(FCount >= 6, 'SpeedSettingCount: Delphi 7''s six at least', IntToStr(FCount));
  if FCount < 6 then Exit;
  S := '';
  Want := '';
  for I := 0 to 5 do
  begin
    S := S + O.SpeedSettings[I].Name + ';';
    Want := Want + Names[I] + ';';
  end;
  Expect('Delphi 7''s speed settings in its order', S, Want);
  Expect('their display names are Delphi''s', O.SpeedSettings[4].DisplayName, 'Visual Studio (TM) emulation');
end;

procedure TSpeedTests.Add;
var
  O: IOTAEditOptions;
begin
  O := Pascal;
  FSpeed := TDemoSpeed.Create(TestSpeedName);
  FSpeedIntf := FSpeed;
  FIndex := O.AddSpeedSetting(FSpeedIntf);
  Check(FIndex >= 0, 'AddSpeedSetting');
  ExpectInt('one more', O.SpeedSettingCount, FCount + 1);
  ExpectInt('the C/C++ options see the same list', Editors.GetEditOptionsForFile('x.cpp').SpeedSettingCount, FCount + 1);
end;

procedure TSpeedTests.Run;
var
  O: IOTAEditOptions;
begin
  O := Pascal;
  O.SetSpeedSetting(LowerCase(TestSpeedName));
  ExpectInt('SetSpeedSetting found it by its name, in any case, and ran it', FSpeed.Calls, 1);
  ExpectInt('... with the options it was called on: block indent 7', O.BlockIndent, 7);
  Expect('... tab stops 3', O.BufferOptions.TabStops, '3');
end;

procedure TSpeedTests.Invalid;
begin
  try
    Pascal.SetSpeedSetting('nope');
    Check(False, 'SetSpeedSetting of an unknown name raises');
  except
    on E: Exception do Expect('an unknown name raises Delphi''s exception', E.Message, 'SpeedSetting, nope, is invalid');
  end;
end;

{ Delphi's BRIEF record and back to the Default: they change the key mapping, which no API
  gives back - only in the test's own settings (unattended) }
procedure TSpeedTests.Brief;
var
  O: IOTAEditOptions;
begin
  if not Test.Unattended then
  begin
    Note('skipped: Borland.Brief would change the key mapping of these settings');
    Exit;
  end;
  O := Pascal;
  O.SetSpeedSetting('Borland.Brief');
  Check(O.UseBriefCursorShapes and O.UseBriefRegularExpressions and O.ForceCutCopyEnabled,
    'Borland.Brief: BRIEF cursor shapes, BRIEF regular expressions, force cut and copy');
  Expect('... tab stops 3 for every source file type', Editors.GetEditOptionsForFile('x.cpp').BufferOptions.TabStops, '3');
  Check(O.BufferOptions.KeepTrailingBlanks and not O.BufferOptions.GroupUndo,
    '... trailing blanks kept, no group undo');
  O.SetSpeedSetting('Borland.Default');
  Check(not O.UseBriefCursorShapes and not O.UseBriefRegularExpressions, 'Borland.Default: no BRIEF again');
  Expect('... tab stops 8', O.BufferOptions.TabStops, '8');
end;

procedure TSpeedTests.Remove;
var
  O: IOTAEditOptions;
begin
  O := Pascal;
  O.RemoveSpeedSetting(FIndex);
  FIndex := -1;
  ExpectInt('RemoveSpeedSetting: one fewer', O.SpeedSettingCount, FCount);
  try
    O.GetSpeedSetting(O.SpeedSettingCount);
    Check(False, 'GetSpeedSetting out of range raises');
  except
    on E: EListError do Check(True, 'GetSpeedSetting out of range raises EListError');
  end;
  RestoreOptions;
end;

procedure TSpeedTests.Cleanup;
begin
  if FIndex >= 0 then Pascal.RemoveSpeedSetting(FIndex);
  FIndex := -1;
  RestoreOptions;
end;

{ ---------------------------------------------------------------- Highlight }

type
  THighlightTests = class(TOtaTestArea)
  private
    FHl: TDemoHighlighter;
    FHlIntf: IOTAHighlighter;
    FIndex, FCount: Integer;
    FFile: string;
    function Attr(Line, Col: Integer): Integer;
    procedure Builtins;
    procedure Register;
    procedure Attributes;
    procedure Remove;
    procedure Revive;
    procedure CloseFile;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

const
  TestHlID = 'D7Studio.OtaSelfTest.Highlighter';
  TestHlOptions = 'D7Studio.OtaSelfTest.EditOptions';
  TestHlExt = 'otahl';

function THighlightTests.Name: string;
begin
  Result := 'Highlight';
end;

procedure THighlightTests.AddSteps;
begin
  FIndex := -1;
  Step('Builtins', Builtins);
  Step('Register', Register);
  Step('Attributes', Attributes);
  Step('Remove', Remove);
  Step('Revive', Revive);
  Step('Close', CloseFile);
end;

function THighlightTests.Attr(Line, Col: Integer): Integer;
var
  B: IOTAEditBuffer;
  P: TOTAEditPos;
  Flag: Integer;
begin
  Result := -1;
  B := BufferOf(FFile);
  if (B = nil) or (B.EditViewCount = 0) then Exit;
  P.Line := Line;
  P.Col := Col;
  B.EditViews[0].GetAttributeAtPos(P, False, Result, Flag);
end;

procedure THighlightTests.Builtins;
const
  IDs: array[0..9] of string = ('Borland.Highlighter.None', 'Borland.Highlighter.Pascal',
    'Borland.Highlighter.Cpp', 'Borland.Highlighter.IDL', 'Borland.Highlighter.HTML',
    'Borland.Highlighter.C#', 'Borland.Highlighter.SQL', 'Borland.Highlighter.PHP',
    'Borland.Highlighter.JavaScript', 'Borland.Highlighter.INI');
var
  HS: IOTAHighlightServices;
  I: Integer;
  S, Want: string;
begin
  if not Check(Supports(BorlandIDEServices, IOTAHighlightServices, HS), 'IOTAHighlightServices') then Exit;
  if not Check(HS.HighlighterCount >= 10, 'Delphi 7''s ten highlighters at least', IntToStr(HS.HighlighterCount)) then Exit;
  S := '';
  Want := '';
  for I := 0 to 9 do
  begin
    if HS.Highlighter[I] <> nil then S := S + HS.Highlighter[I].IDString;
    S := S + ';';
    Want := Want + IDs[I] + ';';
  end;
  Expect('their IDs in Delphi 7''s order', S, Want);
end;

procedure THighlightTests.Register;
var
  HS: IOTAHighlightServices;
  O, P: IOTAEditOptions;
begin
  HS := BorlandIDEServices as IOTAHighlightServices;
  FHl := TDemoHighlighter.Create(TestHlID, 'OTA Self-Test INI');
  FHlIntf := FHl;
  FCount := HS.HighlighterCount;
  FIndex := HS.AddHighlighter(FHlIntf);
  ExpectInt('AddHighlighter: at the end of the list', FIndex, FCount);
  ExpectInt('... one more', HS.HighlighterCount, FCount + 1);
  O := Editors.AddEditOptions(TestHlOptions);
  if not Check(O <> nil, 'AddEditOptions: a source file type of the expert''s') then Exit;
  O.Extensions := TestHlExt;
  O.SyntaxHighlighter := FHlIntf;
  O.BufferOptions.SyntaxHighlight := True;
  Check((O.SyntaxHighlighter <> nil) and SameText(O.SyntaxHighlighter.IDString, TestHlID),
    'IOTAEditOptions.SyntaxHighlighter: the expert''s');
  P := Editors.GetEditOptionsForFile('x.pas');
  Check((P <> nil) and (P.SyntaxHighlighter <> nil) and SameText(P.SyntaxHighlighter.IDString, 'Borland.Highlighter.Pascal'),
    'the Pascal options: Delphi''s Pascal highlighter');
  FFile := Dir + 'HighlightTest.' + TestHlExt;
  WriteText(FFile, '[Sec]'#13#10'; note'#13#10'key=val /* a'#13#10'b */ c'#13#10);
  Check(Actions.OpenFile(FFile), 'a file of the type opened');
end;

procedure THighlightTests.Attributes;
begin
  ExpectInt('"[" of a section: atReservedWord', Attr(1, 1), atReservedWord);
  ExpectInt('";" of a comment: atComment', Attr(2, 1), atComment);
  ExpectInt('"k" of a key: atIdentifier', Attr(3, 1), atIdentifier);
  ExpectInt('"=": atSymbol', Attr(3, 4), atSymbol);
  ExpectInt('"v" of the value: atString', Attr(3, 5), atString);
  ExpectInt('line 4 "b", inside the comment of line 3 (the line class): atComment', Attr(4, 1), atComment);
  ExpectInt('line 4 "c" after "*/": atIdentifier', Attr(4, 6), atIdentifier);
end;

procedure THighlightTests.Remove;
var
  HS: IOTAHighlightServices;
  O: IOTAEditOptions;
begin
  HS := BorlandIDEServices as IOTAHighlightServices;
  HS.RemoveHighlighter(FIndex);
  FIndex := -1;
  ExpectInt('RemoveHighlighter: one fewer', HS.HighlighterCount, FCount);
  ExpectInt('... told Destroyed', FHl.DestroyedCalls, 1);
  ExpectInt('the file is plain text without it (SyntaxOff)', Attr(1, 1), SyntaxOff);
  O := Editors.GetEditOptions(TestHlOptions);
  Check((O <> nil) and (O.SyntaxHighlighter = nil), 'the type''s highlighter is none while it is away');
end;

{ added again: at the end, where it was - Delphi 7's AddHighlighter gives 0 then }
procedure THighlightTests.Revive;
var
  HS: IOTAHighlightServices;
begin
  HS := BorlandIDEServices as IOTAHighlightServices;
  FIndex := HS.AddHighlighter(FHlIntf);
  ExpectInt('added again: AddHighlighter gives its index (Delphi 7: 0)', FIndex, IdeValue(0, FCount));
  Check((HS.HighlighterCount = FCount + 1) and (HS.Highlighter[FCount] = FHlIntf), '... it is at the end, where it was');
  ExpectInt('the file is coloured again', Attr(1, 1), atReservedWord);
  ExpectInt('... the comment over two lines too', Attr(4, 1), atComment);
end;

procedure THighlightTests.CloseFile;
begin
  Cleanup;
  Check(Modules.FindModule(Dir + 'HighlightTest.' + TestHlExt) = nil, 'the file is closed');
end;

procedure THighlightTests.Cleanup;
var
  HS: IOTAHighlightServices;
  I: Integer;
begin
  if FFile <> '' then
  begin
    CloseFileModule(FFile);
    DeleteFile(FFile);
    FFile := '';
  end;
  if Editors.GetEditOptions(TestHlOptions) <> nil then Editors.DeleteEditOptions(TestHlOptions);
  if FHlIntf <> nil then
  begin
    HS := BorlandIDEServices as IOTAHighlightServices;
    for I := HS.HighlighterCount - 1 downto 0 do
      if HS.Highlighter[I] = FHlIntf then HS.RemoveHighlighter(I);
  end;
  FIndex := -1;
end;

{ ---------------------------------------------------------------- FileSystem }

type
  TFileSystemTests = class(TOtaTestArea)
  private
    FFS: TDemoMemFS;
    FFSIntf: IOTAFileSystem;
    FIndex: Integer;
    procedure Add;
    function CreatedText(const FileName, FS, Kind: string; NoSource: Boolean; out Modified: Boolean;
      out Calls: string): string;
    procedure Existing;
    procedure Open;
    procedure Save;
    procedure SetFileSystem;
    procedure Remove;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

const
  TestFSID = 'D7Studio.OtaSelfTest.MemFS';
  TestFSFile = 'OtaSelfTest.Memory.txt';

function TFileSystemTests.Name: string;
begin
  Result := 'FileSystem';
end;

procedure TFileSystemTests.AddSteps;
begin
  FIndex := -1;
  Step('Add', Add);
  Step('Existing', Existing);
  Step('Open', Open);
  Step('Save', Save);
  Step('SetFileSystem', SetFileSystem);
  Step('Remove', Remove);
end;

procedure TFileSystemTests.Add;
begin
  FFS := TDemoMemFS.Create(TestFSID);
  FFSIntf := FFS;
  FFS.SetFile(TestFSFile, 'hello');
  FIndex := Modules.AddFileSystem(FFSIntf);
  Check(FIndex >= 0, 'AddFileSystem');
  Check(SameModule(Modules.FindFileSystem(LowerCase(TestFSID)), FFSIntf), 'FindFileSystem: by its ID, in any case');
end;

{ the text of a module a creator of an existing file makes (Kind: its type, NoSource: no text of its
  own), its modified state and the file system's calls meanwhile; the module closed again }
function TFileSystemTests.CreatedText(const FileName, FS, Kind: string; NoSource: Boolean;
  out Modified: Boolean; out Calls: string): string;
var
  C: TDemoFSCreator;
  MC: IOTAModuleCreator;
  M: IOTAModule;
  S: IOTASourceEditor;
begin
  Result := '(no module)';
  Modified := False;
  FFS.Log.Clear;
  C := TDemoFSCreator.Create(FileName, FS, True);
  C.NoSource := NoSource;
  C.Kind := Kind;
  MC := C;
  M := Modules.CreateModule(MC);
  Calls := JoinLines(FFS.Log);
  S := SourceEditorOf(M);
  if S <> nil then
  begin
    Result := EditorText(S);
    Modified := S.Modified;
  end;
end;

{ Delphi 7's creators of an existing file (measured): the file is not read - the creator's text is
  the module's (not modified, a file system asked IsReadonly only), else a text creator's module is
  empty and a unit creator's has the IDE's new unit }
procedure TFileSystemTests.Existing;
var
  Text, Calls: string;
  Modified: Boolean;
begin
  FFS.SetFile('WithText.txt', 'from the fs');
  Text := CreatedText('WithText.txt', TestFSID, sText, False, Modified, Calls);
  CloseFileModule('WithText.txt');
  Expect('a text creator''s text: the module''s, not the file''s', Text, 'a new file of the demo''s file system');
  Check(not Modified, '... not modified');
  Expect('... the file not read: the file system asked IsReadonly only', Calls, 'IsReadonly(WithText.txt)');
  FFS.SetFile('NoText.txt', 'from the fs');
  Text := CreatedText('NoText.txt', TestFSID, sText, True, Modified, Calls);
  CloseFileModule('NoText.txt');
  Expect('a text creator without a text: an empty module', Text, '');
  Check(not Modified, '... not modified');
  Expect('... the file not read', Calls, 'IsReadonly(NoText.txt)');
  WriteText(Dir + 'FsDisk.txt', 'on the disk');
  Text := CreatedText(Dir + 'FsDisk.txt', '', sText, False, Modified, Calls);
  CloseFileModule(Dir + 'FsDisk.txt');
  Expect('a file of the disk, a text creator''s text: the module''s', Text, 'a new file of the demo''s file system');
  Text := CreatedText(Dir + 'FsDisk.txt', '', sText, True, Modified, Calls);
  CloseFileModule(Dir + 'FsDisk.txt');
  Expect('... without a text: empty', Text, '');
  WriteText(Dir + 'FsUnit.pas', 'unit FsUnit;'#13#10'interface'#13#10'implementation'#13#10'end.'#13#10);
  Text := CreatedText(Dir + 'FsUnit.pas', '', sUnit, True, Modified, Calls);
  CloseFileModule(Dir + 'FsUnit.pas');
  Expect('a unit creator without a text: the IDE''s new unit, not the file', Text,
    'unit FsUnit;'#13#10#13#10'interface'#13#10#13#10'implementation'#13#10#13#10'end.'#13#10);
  Check(not Modified, '... not modified');
  Text := CreatedText(Dir + 'FsUnit.pas', '', sUnit, False, Modified, Calls);
  CloseFileModule(Dir + 'FsUnit.pas');
  Expect('... with a text: the creator''s', Text, 'a new file of the demo''s file system');
  Check(not Modified, '... not modified');
end;

{ an existing file of the file system opened by a creator that gives its text, read from the file
  system by the expert (as the demo's command does: no creator's module reads its file) }
procedure TFileSystemTests.Open;
var
  C: TDemoFSCreator;
  M: IOTAModule;
begin
  FFS.Log.Clear;
  C := TDemoFSCreator.Create(TestFSFile, TestFSID, True);
  C.Source := FFS.Content(TestFSFile);
  M := Modules.CreateModule(C);
  if not Check(M <> nil, 'CreateModule of an existing file of the file system') then Exit;
  Expect('IOTAModule.FileSystem', M.FileSystem, TestFSID);
  Expect('its text: the creator''s, the file''s', EditorText(SourceEditorOf(M)), 'hello');
  Expect('... the file system asked IsReadonly only', JoinLines(FFS.Log), 'IsReadonly(' + TestFSFile + ')');
  Check(not FileExists(TestFSFile) and not FileExists(Dir + TestFSFile), 'no file of the disk');
end;

{ IsReadonly of the backup's name is asked also when no backup is kept (Delphi 7's, measured) }
procedure TFileSystemTests.Save;
var
  M: IOTAModule;
  W: IOTAEditWriter;
  Backup: Boolean;
  N, T, B, Want: string;
begin
  M := Modules.FindModule(TestFSFile);
  if not Check(M <> nil, 'the file is a module') then Exit;
  W := SourceEditorOf(M).CreateUndoableWriter;
  W.CopyTo(0);
  W.Insert('X');
  W := nil;
  Expect('the writer changed the text', EditorText(SourceEditorOf(M)), 'Xhello');
  Backup := Editors.EditOptions.BufferOptions.CreateBackupFile;
  FFS.Log.Clear;
  Check(M.Save(False, True), 'IOTAModule.Save');
  Expect('it was written through the file system', FFS.Content(TestFSFile), 'Xhello');
  N := TestFSFile;
  T := N + '.$$$';
  B := N + '.~bak';
  if Backup then
    Want := Format('GetTempFileName(%s); GetBackupFileName(%s); IsReadonly(%s); IsReadonly(%s); ' +
      'GetFileStream(%s,create); DeleteFile(%s); FileExists(%s); RenameFile(%s,%s); FileExists(%s); ' +
      'RenameFile(%s,%s); FileAge(%s)', [N, N, N, B, T, B, N, N, B, T, T, N, N])
  else
    Want := Format('GetTempFileName(%s); GetBackupFileName(%s); IsReadonly(%s); IsReadonly(%s); ' +
      'GetFileStream(%s,create); DeleteFile(%s); FileExists(%s); RenameFile(%s,%s); FileAge(%s)',
      [N, N, N, B, T, N, T, T, N, N]);
  Expect('Delphi 7''s order of calls (Editors.WriteEditorStream)', JoinLines(FFS.Log), Want);
  if Backup then Expect('the backup has the text of before', FFS.Content(B), 'hello');
end;
procedure TFileSystemTests.SetFileSystem;
var
  M: IOTAModule;
begin
  M := Modules.FindModule(TestFSFile);
  if not Check(M <> nil, 'the file is a module') then Exit;
  if D7StudioOnly('an unknown file system: Delphi 7''s module is broken afterwards (an access violation)') then
  begin
    try
      M.FileSystem := 'nope';
      Check(False, 'SetFileSystem of an unknown file system raises');
    except
      on E: Exception do Expect('an unknown file system raises Delphi''s exception', E.Message, 'Unable to locate file system, ''nope''');
    end;
    Expect('... the module keeps its own', M.FileSystem, TestFSID);
  end;
  M.FileSystem := '';
  Expect('SetFileSystem(''''): the disk''s', M.FileSystem, '');
  M.FileSystem := TestFSID;
  Expect('... and back', M.FileSystem, TestFSID);
  Check(M.CloseModule(True), 'closed');
end;

{ Delphi 7's (measured): an index out of range raises EListError, FindFileSystem of an ID no file
  system has raises Delphi's exception }
procedure TFileSystemTests.Remove;

  function Raises(Index: Integer): Boolean;
  begin
    Result := False;
    try
      Modules.RemoveFileSystem(Index);
    except
      on EListError do Result := True;
    end;
  end;

begin
  Check(Raises(1000), 'RemoveFileSystem of an index out of range raises EListError');
  Check(Raises(-1), '... of -1 too');
  Modules.RemoveFileSystem(FIndex);
  FIndex := -1;
  try
    Modules.FindFileSystem(TestFSID);
    Check(False, 'RemoveFileSystem: FindFileSystem finds it no more (raises)');
  except
    on E: Exception do
      Expect('RemoveFileSystem: FindFileSystem finds it no more, raising Delphi''s exception', E.Message,
        'Unable to locate file system, ''' + TestFSID + '''');
  end;
end;

procedure TFileSystemTests.Cleanup;
begin
  CloseFileModule(TestFSFile);
  if FIndex >= 0 then Modules.RemoveFileSystem(FIndex);
  FIndex := -1;
end;

{ ---------------------------------------------------------------- Record }

{ the items RecordItems gives for the characters of S typed: 'k<code>' each }
function CharItems(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + 'k' + IntToHex(Ord(S[I]), 8);
  end;
end;

type
  TRecordTests = class;

  { Shift+Ctrl+Alt+P pauses the playback that runs (IOTAKeyboardServices.PausePlayback) }
  TPauseBinding = class(TNotifierObject, IOTANotifier, IOTAKeyboardBinding)
  private
    FTests: TRecordTests;
  public
    constructor Create(ATests: TRecordTests);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

  TRecordTests = class(TOtaTestArea)
  private
    FFile: string;
    FRec, FRec3: IOTARecord;
    FBinding: Integer;
    FBindingIntf: IOTAKeyboardBinding;
    FPauses: Integer;
    procedure Objects;
    procedure Play;
    procedure Pause;
    procedure Ignored;
    procedure IdeRecord;
    procedure IdeCommand;
    procedure IdePlay;
    procedure CloseFile;
  public
    procedure KeyPause(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

constructor TPauseBinding.Create(ATests: TRecordTests);
begin
  inherited Create;
  FTests := ATests;
end;

function TPauseBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TPauseBinding.GetDisplayName: string;
begin
  Result := 'OTA self-test: pause the playback';
end;

function TPauseBinding.GetName: string;
begin
  Result := 'D7Studio.OtaDemo.SelfTest.Pause';
end;

procedure TPauseBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding([ShortCut(Ord('P'), [ssShift, ssCtrl, ssAlt])], FTests.KeyPause, nil);
end;

procedure TRecordTests.KeyPause(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FPauses);
  Keyboard.PausePlayback;
  BindingResult := krHandled;
end;

function TRecordTests.Name: string;
begin
  Result := 'Record';
end;

procedure TRecordTests.AddSteps;
begin
  FBinding := -1;
  Step('Object', Objects);
  Step('Play', Play);
  Step('Pause', Pause);
  Step('Ignored', Ignored);
  Step('IdeRecord', IdeRecord);
  Step('IdeCommand', IdeCommand);
  Step('IdePlay', IdePlay);
  Step('Close', CloseFile);
end;

{ a record's bytes as WriteToStream writes them }
function StreamBytes(const R: IOTARecord): string;
var
  M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    R.WriteToStream(TStreamAdapter.Create(M, soReference));
    SetString(Result, PChar(M.Memory), M.Size);
  finally
    M.Free;
  end;
end;

{ ... read into a record (it appends) }
procedure StreamInto(const R: IOTARecord; const Bytes: string);
var
  M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    if Bytes <> '' then M.WriteBuffer(Bytes[1], Length(Bytes));
    M.Position := 0;
    R.ReadFromStream(TStreamAdapter.Create(M, soReference));
  finally
    M.Free;
  end;
end;

function HexOf(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do Result := Result + IntToHex(Ord(S[I]), 2);
end;

procedure TRecordTests.Objects;
var
  K: IOTAKeyboardServices;
  R2, R3: IOTARecord;
  Bytes: string;
begin
  K := Keyboard;
  if not Check(K.NewRecordObject(FRec) and (FRec <> nil), 'NewRecordObject') then Exit;
  Check(not FRec.IsRecording and not FRec.IsPlaying and not FRec.IsPaused, 'a new record neither records, plays nor is paused');
  FRec.Append('abc');
  FRec.Append([ShortCut(VK_LEFT, [])]);
  FRec.Append([ShortCut(VK_BACK, [])]);
  Bytes := StreamBytes(FRec);
  Expect('WriteToStream: TPOR, then the keys - "a" a character', HexOf(Copy(Bytes, 1, 9)), HexOf('TPOR'#1#$61#0#0#0));
  ExpectInt('five items of five bytes and the end', Length(Bytes), 4 + 5 * 5 + 1);
  Expect('Left: a virtual, extended key ($00880025)', HexOf(Copy(Bytes, 20, 5)), HexOf(#1#$25#0#$88#0));
  Expect('Backspace: a virtual key ($00800008)', HexOf(Copy(Bytes, 25, 5)), HexOf(#1#8#0#$80#0));
  Expect('the end', HexOf(Copy(Bytes, 30, 1)), '00');
  K.NewRecordObject(R2);
  StreamInto(R2, Bytes);
  Expect('ReadFromStream and WriteToStream again: the same bytes', HexOf(StreamBytes(R2)), HexOf(Bytes));
  K.NewRecordObject(R3);
  try
    StreamInto(R3, 'XXXX');
    Check(False, 'ReadFromStream of another format raises');
  except
    on E: Exception do Expect('another format raises Delphi''s exception', E.Message, 'Invalid Key macro format');
  end;
end;

procedure TRecordTests.Play;
var
  K: IOTAKeyboardServices;
  B: IOTAEditBuffer;
  R5, R6: IOTARecord;
  L: TStringList;
begin
  K := Keyboard;
  FFile := Dir + 'RecordTest.txt';
  WriteText(FFile, 'record test'#13#10#13#10#13#10'end');
  if not Check(Actions.OpenFile(FFile), 'a file opened') then Exit;
  B := BufferOf(FFile);
  if not Check(B <> nil, 'it is a buffer') then Exit;
  B.TopView.Position.Move(2, 1);
  K.SetPlaybackObject(FRec);
  Check(SameModule(K.CurrentPlayback, FRec), 'SetPlaybackObject: the current playback');
  K.ResumePlayback;
  Pump(300);
  Expect('ResumePlayback played it key by key in the code editor: abc, Left, Backspace', BufferLine(FFile, 2), 'ac');
  Check(not FRec.IsPlaying and not FRec.IsPaused, 'it played to its end');
  { a command by its name (the key mappings' LineStart), then a character; a record appended to
    another keeps its commands as commands }
  K.NewRecordObject(R5);
  R5.Append('LineStart', False);
  R5.Append('Z');
  K.NewRecordObject(R6);
  R6.Append(R5);
  L := TStringList.Create;
  try
    RecordItems(R6, L);
    Expect('Append of a record: its command stays a command (Delphi 7: the characters of its name)',
      L.CommaText, IdeText(CharItems('LineStart') + ',k0000005A', 'cLineStart,k0000005A'));
  finally
    L.Free;
  end;
  K.SetPlaybackObject(R6);
  K.ResumePlayback;
  Pump(300);
  Expect('a command played by its name: LineStart, then Z (Delphi 7 types the name)', BufferLine(FFile, 2),
    IdeText('aLineStartZc', 'Zac'));
  B.Undo;
  Expect('one undo step takes a whole playback back', BufferLine(FFile, 2), 'ac');
  B.Undo;
  Expect('... and the one before', BufferLine(FFile, 2), '');
end;

procedure TRecordTests.Pause;
var
  K: IOTAKeyboardServices;
  B: IOTAEditBuffer;
begin
  K := Keyboard;
  FBindingIntf := TPauseBinding.Create(Self);
  FBinding := K.AddKeyboardBinding(FBindingIntf);
  K.NewRecordObject(FRec3);
  FRec3.Append('x');
  FRec3.Append([ShortCut(Ord('P'), [ssShift, ssCtrl, ssAlt])]);
  FRec3.Append('y');
  B := BufferOf(FFile);
  if not Check(B <> nil, 'the file is a buffer') then Exit;
  B.TopView.Position.Move(2, 1);
  K.SetPlaybackObject(FRec3);
  K.ResumePlayback;
  Pump(300);
  ExpectInt('the expert''s binding had its key during the playback', FPauses, 1);
  Expect('... and paused it: the keys after it wait', BufferLine(FFile, 2), 'x');
  Check(FRec3.IsPaused and FRec3.IsPlaying, 'paused, still playing');
  K.ResumePlayback;
  Pump(300);
  Expect('ResumePlayback: on from where it was paused', BufferLine(FFile, 2), 'xy');
  Check(not FRec3.IsPaused and not FRec3.IsPlaying, 'played to its end');
end;

procedure TRecordTests.Ignored;
var
  K: IOTAKeyboardServices;
  Own: IOTARecord;
begin
  K := Keyboard;
  Own := TDemoOwnRecord.Create;
  K.SetPlaybackObject(Own);
  Check(SameModule(K.CurrentPlayback, FRec3), 'an expert''s own IOTARecord is ignored (Delphi 7''s)');
end;

{ Record Macro and the keys of the code editor: the IDE's record of the keyboard services - the
  characters typed, then (next step) a menu command and a key that types none. Record and Play are
  the editor's keys Ctrl+Shift+R and Ctrl+Shift+P, Delphi 7's and D7 Studio's }
procedure TRecordTests.IdeRecord;
var
  K: IOTAKeyboardServices;
  B: IOTAEditBuffer;
  Wnd: HWND;
  P: TOTACharPos;
begin
  K := Keyboard;
  B := BufferOf(FFile);
  if not Check(B <> nil, 'the file is a buffer') then Exit;
  B.TopView.Position.Move(3, 1);
  Wnd := EditorControlOf(FFile);
  if not Check(Wnd <> 0, 'the code editor of the file') then Exit;
  PostKey(Wnd, Ord('R'), [ssCtrl, ssShift]);
  Check((K.CurrentRecord <> nil) and K.CurrentRecord.IsRecording, 'Record Macro (Ctrl+Shift+R): the current record records');
  PostKey(Wnd, Ord('H'), []);
  PostKey(Wnd, Ord('I'), []);
  Expect('typed while it records', BufferLine(FFile, 3), 'hi');
  { "i" made the block through the API (no key): Edit | Delete has a block to delete in the next
    step. Delphi's BlockStart and BlockAfter set the ends only; BlockVisible shows the block - the
    selection without Persistent blocks, the cursor being at its end }
  P.Line := 3;
  P.CharIndex := 1;
  B.BlockStart := P;
  P.CharIndex := 2;
  B.BlockAfter := P;
  B.BlockVisible := True;
end;

procedure TRecordTests.IdeCommand;
var
  K: IOTAKeyboardServices;
  A: TContainedAction;
  Wnd: HWND;
  L: TStringList;
begin
  K := Keyboard;
  Wnd := EditorControlOf(FFile);
  if not Check(Wnd <> 0, 'the code editor of the file') then Exit;
  { Edit | Delete (Delphi's menu command mcClipClear) run while the code editor has the keyboard,
    as a click on the menu item runs it }
  Windows.SetFocus(Wnd);
  A := IdeAction('EditDeleteCommand');
  if not Check(A <> nil, 'the action of Edit | Delete') then Exit;
  A.Execute;
  Expect('Edit | Delete deleted the block', BufferLine(FFile, 3), 'h');
  PostKey(Wnd, VK_LEFT, []);
  PostKey(Wnd, Ord('R'), [ssCtrl, ssShift]);
  Check((K.CurrentRecord <> nil) and not K.CurrentRecord.IsRecording, 'Record Macro again: it stopped');
  L := TStringList.Create;
  try
    Check(RecordItems(K.CurrentRecord, L), 'the record is written to a stream');
    Expect('the characters typed, the menu command as a command (Delphi 7: the characters of its name), ' +
      'the key that types none - not the commands that started and stopped it', L.CommaText,
      IdeText('k00000068,k00000069,' + CharItems(mcClipClear) + ',k00880025',
      'k00000068,k00000069,c' + mcClipClear + ',k00880025'));
  finally
    L.Free;
  end;
end;

procedure TRecordTests.IdePlay;
var
  Wnd: HWND;
begin
  Wnd := EditorControlOf(FFile);
  if not Check(Wnd <> 0, 'the code editor of the file') then Exit;
  PostKey(Wnd, Ord('P'), [ssCtrl, ssShift]);
  Pump(300);
  { h and i typed at the caret - before the "h", where the recorded Left put it -, Edit | Delete
    without a block does nothing (Delphi 7 types the command's name) }
  Expect('Play Macro typed it again at the caret', BufferLine(FFile, 3), IdeText('hi' + mcClipClear + 'h', 'hih'));
end;

procedure TRecordTests.CloseFile;
begin
  Cleanup;
  Check(Modules.FindModule(Dir + 'RecordTest.txt') = nil, 'closed');
end;

procedure TRecordTests.Cleanup;
begin
  if FBinding >= 0 then Keyboard.RemoveKeyboardBinding(FBinding);
  FBinding := -1;
  FBindingIntf := nil;
  if FFile <> '' then
  begin
    CloseFileModule(FFile);
    DeleteFile(FFile);
    FFile := '';
  end;
end;

{ ---------------------------------------------------------------- CustomMessages }

type
  TCustomMessageTests = class(TOtaTestArea)
  private
    FGroup: IOTAMessageGroup;
    FList: HWND;
    FAlive: Integer;
    function Rows: Integer;
    procedure Key(Code: Word);
    procedure Select(Row: Integer);
    procedure AddTree;
    procedure Expand;
    procedure Help;
    procedure Collapse;
    procedure ToolChildren;
    procedure Clear;
  public
    function Name: string; override;
    procedure AddSteps; override;
  end;

const
  TreeGroup = 'OTA Self-Test Tree';

function TCustomMessageTests.Name: string;
begin
  Result := 'CustomMessages';
end;

procedure TCustomMessageTests.AddSteps;
begin
  Step('Add', AddTree);
  Step('Expand', Expand);
  Step('Help', Help);
  Step('Collapse', Collapse);
  Step('ToolChildren', ToolChildren);
  Step('Clear', Clear);
end;

function TCustomMessageTests.Rows: Integer;
begin
  if FList = 0 then Result := -1 else Result := SendMessage(FList, LB_GETCOUNT, 0, 0);
end;

procedure TCustomMessageTests.Key(Code: Word);
begin
  PostKey(FList, Code, []);
end;

procedure TCustomMessageTests.Select(Row: Integer);
begin
  SendMessage(FList, LB_SETCURSEL, Row, 0);
end;

procedure TCustomMessageTests.AddTree;
var
  M: IOTAMessageServices;
  P: TDemoMessage;
begin
  M := BorlandIDEServices as IOTAMessageServices;
  FGroup := M.AddMessageGroup(TreeGroup);
  FAlive := DemoMessagesAlive;
  P := TDemoMessage.Create('SELFTEST-MS parent');
  P.AddChild(TDemoMessage.Create('SELFTEST-MS child A'));
  P.AddChild(TDemoDrawMessage.Create('SELFTEST-MS child B'));
  M.AddCustomMessage(P, FGroup);
  M.ShowMessageView(FGroup);
  ExpectInt('the view keeps the message and its children', DemoMessagesAlive - FAlive, 3);
  if not D7StudioOnly('the rows of D7 Studio''s Messages view (a list box; Delphi 7''s is a tree view)') then Exit;
  FList := FindIdeWindow('TListBox', 'SELFTEST-MS parent');
  if not Check(FList <> 0, 'the group''s list in the Messages view') then Exit;
  ExpectInt('one row: the children are closed when added (Delphi''s tree)', Rows, 1);
end;

procedure TCustomMessageTests.Expand;
begin
  if FList = 0 then Exit;
  Select(0);
  Key(VK_RIGHT);
  ExpectInt('Right opened it: three rows', Rows, 3);
  Expect('row 2: the child that draws itself, indented', RowText(FList, 2), '    SELFTEST-MS child B');
  DemoMessageDraws := 0;
  RedrawWindow(FList, nil, 0, RDW_INVALIDATE or RDW_UPDATENOW);
  Check(DemoMessageDraws > 0, 'INTACustomDrawMessage.Draw drew its row', IntToStr(DemoMessageDraws));
end;

procedure TCustomMessageTests.Help;
begin
  if FList = 0 then Exit;
  DemoMessageHelp := 0;
  Select(1);
  Key(VK_F1);
  ExpectInt('F1 on an expert''s message: its ShowHelp', DemoMessageHelp, 1);
end;

procedure TCustomMessageTests.Collapse;
begin
  if FList = 0 then Exit;
  Select(1);
  Key(VK_LEFT);
  ExpectInt('Left on a child goes to its parent', SendMessage(FList, LB_GETCURSEL, 0, 0), 0);
  Key(VK_LEFT);
  ExpectInt('Left on the open parent closed it: one row', Rows, 1);
  Key(VK_ADD);
  ExpectInt('+ opened it', Rows, 3);
  Key(VK_SUBTRACT);
  ExpectInt('- closed it', Rows, 1);
end;

procedure TCustomMessageTests.ToolChildren;
var
  M: IOTAMessageServices;
  Ref, Child: Pointer;
begin
  M := BorlandIDEServices as IOTAMessageServices;
  M.AddToolMessage('', 'SELFTEST-MS tool parent', 'Self-Test', 0, 0, nil, Ref, FGroup);
  M.AddToolMessage('', 'SELFTEST-MS tool child', 'Self-Test', 0, 0, Ref, Child, FGroup);
  if FList <> 0 then ExpectInt('a tool message''s child is closed too: one more row', Rows, 2);
end;

procedure TCustomMessageTests.Clear;
var
  M: IOTAMessageServices;
  P: TDemoMessage;
begin
  M := BorlandIDEServices as IOTAMessageServices;
  M.ClearMessageGroup(FGroup);
  ExpectInt('ClearMessageGroup released the expert''s messages', DemoMessagesAlive - FAlive, 0);
  if FList <> 0 then ExpectInt('no rows', Rows, 0);
  { the script checks the view's rows: a closed message with its child under it }
  P := TDemoMessage.Create('SELFTEST-MSP');
  P.AddChild(TDemoMessage.Create('SELFTEST-MSC'));
  M.AddCustomMessage(P, FGroup);
  Note('EXPECT messages ' + TreeGroup + ' has +SELFTEST-MSP');
  Note('EXPECT messages ' + TreeGroup + ' lacks SELFTEST-MSC');
  Check(True, 'a closed message with a child left in the group (the script checks the Messages view)');
end;

initialization
  RegisterTestArea(TModuleDataTests, 90);
  RegisterTestArea(TTypeLibTests, 91);
  RegisterTestArea(TToolsFilterTests, 92);
  RegisterTestArea(TSpeedTests, 93);
  RegisterTestArea(THighlightTests, 94);
  RegisterTestArea(TFileSystemTests, 95);
  { before TypeLib (91): once a type library has been opened in Delphi 7's IDE, its keystroke
    playback types nothing and Record Macro swallows the keys typed (measured) }
  RegisterTestArea(TRecordTests, 89);
  { after the Messages area (900): its ClearToolMessages of every group would take the message
    this area leaves for the script }
  RegisterTestArea(TCustomMessageTests, 950);
end.
