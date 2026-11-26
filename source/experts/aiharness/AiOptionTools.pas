{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiOptionTools;

{ The harness's tools for the IDE's settings, through the Open Tools API (IOTAProjectOptions,
  IOTAEnvironmentOptions, IOTAEditOptions):
    reading:  get_settings - a project's options (Project | Options), the IDE's environment options
              (the library, compiling and running, the designer, code insight) and the code
              editor's options (indentation, tabs, margin, font); or the options the model names;
              or every option the IDE lists;
    changing: set_project_option - one option of a project (previewed and approved).
  Values are the IDE's: numbers (a compiler switch 1 on, 0 off), True / False, text; a list (the
  version information's keys) as its Name=Value lines. Options an IDE does not have are left out. }

interface

uses
  AiCore;

procedure AddOptionTools(List: TAiToolList);

implementation

uses
  SysUtils, Classes, TypInfo, Variants, ToolsAPI, AiJson, AiText, AiIde;

type
  TGetSettingsTool = class(TAiTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TSetProjectOptionTool = class(TAiTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function IsChange: Boolean; override;
    function Summarize(Input: TJson): string; override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

const
  { the project's options get_settings shows, by the pages of Project | Options:
    'Heading=Name,Name/X,...' (X: the compiler directive of a switch) }
  ProjectGroups: array[0..5] of string = (
    'Directories/Conditionals=OutputDir,UnitOutputDir,PkgDllDir,PkgDcpDir,UnitDir,Defines,UnitAliases,DebugSourcePath',
    'Compiler (a switch: 1 on, 0 off; $A and $Z are sizes)=Optimization/O,StackFrames/W,Align/A,MinEnumSize/Z,' +
      'RangeChecks/R,IOChecks/I,OverflowChecks/Q,Assertions/C,BoolEval/B,ExtendedSyntax/X,TypedAddress/T,' +
      'OpenStrings/P,LongStrings/H,VarStringChecks/V,WriteableConst/J,SafeDivide/U,UnitDebugInfo/D,LocalSymbols/L,' +
      'ReferenceInfo/Y,HintFlag,WarnFlag',
    'Linker=MapFile,OutputObj,DebugInfo,RemoteSymbols,ImageBase,StackSize,MaxStackSize,ExeDescription',
    'Packages=UsePackages,Packages',
    'Version information=IncludeVersionInfo,MajorVersion,MinorVersion,Release,Build,AutoIncBuildNum,Locale,CodePage,Keys',
    'Run parameters=RunParams,HostApplication');
  { the group after which the warnings turned off are listed }
  CompilerGroup = 1;

  { the environment options get_settings shows, by the pages of Environment Options }
  EnvGroups: array[0..3] of string = (
    'Library=LibraryPath,BrowsingPath,PackageDPLOutput,PackageDCPOutput,RepositoryDir',
    'Compiling and running=ShowCompilerProgress,WarnOnPackageRebuild,MinimizeOnRun,AutoSaveEditorFiles,AutoSaveDesktop',
    'Designer=DFMAsText,AutoCreateForms,DisplayGrid,SnapToGrid,GridSizeX,GridSizeY',
    'Code insight=CodeCompletion,CodeParameters,CodeCompleteDelay');

procedure AddOptionTools(List: TAiToolList);
begin
  List.Add(TGetSettingsTool.Create);
  List.Add(TSetProjectOptionTool.Create);
end;

{ ---------------------------------------------------------------- helpers }

function BoolText(B: Boolean): string;
begin
  if B then Result := 'True' else Result := 'False';
end;

{ the list a value of a list option holds (the IDE gives its TStrings as a number); nil when it
  holds none }
function ListOf(const V: Variant): TStrings;
var
  P: Integer;
begin
  Result := nil;
  try
    if VarIsEmpty(V) or VarIsNull(V) then Exit;
    P := V;
    if (P <> 0) and (TObject(P) is TStrings) then Result := TStrings(P);
  except
    Result := nil;
  end;
end;

{ V, a value of an option of the type Kind, as text }
function ValueText(const V: Variant; Kind: TTypeKind): string;
var
  L: TStrings;
  I: Integer;
begin
  if Kind = tkClass then
  begin
    L := ListOf(V);
    Result := '';
    if L <> nil then
      for I := 0 to L.Count - 1 do
      begin
        if Result <> '' then Result := Result + '; ';
        Result := Result + L[I];
      end;
    if Result = '' then Result := '(none)';
    Exit;
  end;
  case VarType(V) of
    varEmpty, varNull: Result := '(none)';
    varBoolean: Result := BoolText(V);
  else
    Result := VarToStr(V);
    if Result = '' then Result := '(empty)';
  end;
end;

{ what a number of an option means }
function NoteOf(const Name, Text: string): string;
var
  N: Integer;
begin
  Result := '';
  if SameText(Name, 'MapFile') then Result := ' (0 off, 1 segments, 2 publics, 3 detailed)'
  else if SameText(Name, 'ImageBase') and TryStrToInt(Text, N) then Result := Format(' ($%.8x)', [N]);
end;

{ the names Options lists, in L (case-insensitive), with their types (Objects) }
procedure OptionNames(const Options: IOTAOptions; L: TStringList);
var
  A: TOTAOptionNameArray;
  I: Integer;
begin
  L.Clear;
  if Options = nil then Exit;
  try
    A := Options.GetOptionNames;
  except
    Exit;
  end;
  for I := 0 to High(A) do L.AddObject(A[I].Name, TObject(Ord(A[I].Kind)));
end;

function KindOf(Names: TStringList; I: Integer): TTypeKind;
begin
  Result := TTypeKind(Integer(Names.Objects[I]));
end;

{ Names[I] of Options as text; False when the IDE has no value of it }
function ReadOption(const Options: IOTAOptions; Names: TStringList; I: Integer; out Text: string): Boolean;
var
  V: Variant;
begin
  Result := False;
  Text := '';
  try
    V := Options.Values[Names[I]];
    Text := ValueText(V, KindOf(Names, I));
    Result := True;
  except
    Text := '';
  end;
end;

{ a group 'Heading=Name,Name/X,...' of Options as lines: the names the IDE lists }
procedure AddGroup(B: TStrings; const Group: string; const Options: IOTAOptions; Names: TStringList);
var
  Items: TStringList;
  I, K: Integer;
  Name, Letter, Text, Line: string;
begin
  B.Add('  ' + Copy(Group, 1, Pos('=', Group) - 1) + ':');
  Items := TStringList.Create;
  try
    Items.CommaText := Copy(Group, Pos('=', Group) + 1, MaxInt);
    for I := 0 to Items.Count - 1 do
    begin
      Name := Items[I];
      Letter := '';
      K := Pos('/', Name);
      if K > 0 then
      begin
        Letter := Copy(Name, K + 1, MaxInt);
        Name := Copy(Name, 1, K - 1);
      end;
      K := Names.IndexOf(Name);
      if (K < 0) or not ReadOption(Options, Names, K, Text) then Continue;
      Line := '    ' + Names[K];
      if Letter <> '' then Line := Line + ' ($' + Letter + ')';
      B.Add(Line + ' = ' + Text + NoteOf(Names[K], Text));
    end;
  finally
    Items.Free;
  end;
end;

{ the warnings of the project's options that are turned off (Warn<Name> = 0) }
procedure AddWarningsOff(B: TStrings; const Options: IOTAOptions; Names: TStringList);
var
  I: Integer;
  Text, Off: string;
begin
  Off := '';
  for I := 0 to Names.Count - 1 do
    if SameText(Copy(Names[I], 1, 4), 'Warn') and not SameText(Names[I], 'WarnFlag') and
      ReadOption(Options, Names, I, Text) and (Text = '0') then
    begin
      if Off <> '' then Off := Off + ', ';
      Off := Off + Copy(Names[I], 5, MaxInt);
    end;
  if Off = '' then Off := 'none';
  B.Add('    Warnings turned off: ' + Off);
end;

{ every option Options lists, with its value }
procedure AddAll(B: TStrings; const Options: IOTAOptions; Names: TStringList);
var
  I: Integer;
  Text: string;
begin
  for I := 0 to Names.Count - 1 do
    if ReadOption(Options, Names, I, Text) then B.Add('  ' + Names[I] + ' = ' + Text + NoteOf(Names[I], Text));
end;

function EnvironmentOptions: IOTAEnvironmentOptions;
begin
  try
    Result := (BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
  except
    Result := nil;
  end;
end;

function ProjectOptionsOf(P: IOTAProject): IOTAProjectOptions;
begin
  Result := nil;
  if P = nil then Exit;
  try
    Result := P.ProjectOptions;
  except
    Result := nil;
  end;
end;

{ the options of Options: every one (ListAll), else the groups Groups - with the warnings turned off
  after the group WarningsAfter (-1: none) }
procedure AddOptions(B: TStrings; const Options: IOTAOptions; const Groups: array of string; ListAll: Boolean;
  WarningsAfter: Integer);
var
  Names: TStringList;
  I: Integer;
begin
  Names := TStringList.Create;
  try
    OptionNames(Options, Names);
    if Names.Count = 0 then B.Add('  (the IDE gives none)')
    else if ListAll then AddAll(B, Options, Names)
    else
      for I := 0 to High(Groups) do
      begin
        AddGroup(B, Groups[I], Options, Names);
        if I = WarningsAfter then AddWarningsOff(B, Options, Names);
      end;
  finally
    Names.Free;
  end;
end;

procedure AddProject(B: TStrings; P: IOTAProject; ListAll: Boolean);
begin
  if P = nil then
  begin
    B.Add('No project is open: there are no project options.');
    Exit;
  end;
  B.Add('Project options of ' + P.FileName + ' (Project | Options):');
  AddOptions(B, ProjectOptionsOf(P), ProjectGroups, ListAll, CompilerGroup);
end;

procedure AddEnvironment(B: TStrings; ListAll: Boolean);
begin
  B.Add('Environment options of ' + IdeName + ' (Tools | Environment Options):');
  try
    B.Add('  Delphi''s folder, $(DELPHI) in paths: ' +
      ExcludeTrailingPathDelimiter((BorlandIDEServices as IOTAServices).GetRootDirectory));
  except
    { an IDE without it }
  end;
  AddOptions(B, EnvironmentOptions, EnvGroups, ListAll, -1);
end;

procedure AddEditor(B: TStrings);
var
  ES: IOTAEditorServices;
  EO: IOTAEditOptions;
  BO: IOTABufferOptions;
begin
  B.Add('Editor options (Tools | Editor Options), for the file in the code editor:');
  try
    EO := nil;
    if Supports(BorlandIDEServices, IOTAEditorServices, ES) then EO := ES.EditOptions;
    if EO = nil then
    begin
      B.Add('  (the IDE gives none)');
      Exit;
    end;
    B.Add(Format('  BlockIndent = %d', [EO.BlockIndent]));
    BO := EO.BufferOptions;
    if BO <> nil then
    begin
      B.Add('  TabStops = ' + BO.TabStops);
      B.Add('  UseTabCharacter = ' + BoolText(BO.UseTabCharacter));
      B.Add('  SmartTab = ' + BoolText(BO.SmartTab));
      B.Add('  AutoIndent = ' + BoolText(BO.AutoIndent));
      B.Add('  BackspaceUnindents = ' + BoolText(BO.BackspaceUnindents));
      B.Add('  CursorThroughTabs = ' + BoolText(BO.CursorThroughTabs));
      B.Add('  KeepTrailingBlanks = ' + BoolText(BO.KeepTrailingBlanks));
      B.Add('  PreserveLineEnds = ' + BoolText(BO.PreserveLineEnds));
      B.Add(Format('  RightMargin = %d', [BO.RightMargin]));
      B.Add('  CreateBackupFile = ' + BoolText(BO.CreateBackupFile));
    end;
    B.Add(Format('  Font = %s, %d pt', [EO.FontName, EO.FontSize]));
  except
    on E: Exception do B.Add('  (not readable: ' + E.Message + ')');
  end;
end;

{ the options Wanted names: of the project P first (Project), then of the environment (Env) }
procedure AddNamed(B: TStrings; Wanted: TJson; P: IOTAProject; Project, Env: Boolean);
var
  PO: IOTAProjectOptions;
  EO: IOTAEnvironmentOptions;
  PNames, ENames: TStringList;
  I, K: Integer;
  N, Text: string;
  Found: Boolean;
begin
  PNames := TStringList.Create;
  ENames := TStringList.Create;
  try
    if Project and (P <> nil) then
    begin
      PO := ProjectOptionsOf(P);
      OptionNames(PO, PNames);
      B.Add('Project: ' + P.FileName);
    end;
    if Env then
    begin
      EO := EnvironmentOptions;
      OptionNames(EO, ENames);
    end;
    for I := 0 to Wanted.Count - 1 do
    begin
      N := Trim(Utf8ToIde(Wanted.Item(I).AsString));
      if N = '' then Continue;
      Found := False;
      K := PNames.IndexOf(N);
      if (K >= 0) and ReadOption(PO, PNames, K, Text) then
      begin
        B.Add(Format('%s = %s%s (project option)', [PNames[K], Text, NoteOf(PNames[K], Text)]));
        Found := True;
      end;
      K := ENames.IndexOf(N);
      if not Found and (K >= 0) and ReadOption(EO, ENames, K, Text) then
      begin
        B.Add(Format('%s = %s (environment option)', [ENames[K], Text]));
        Found := True;
      end;
      if not Found then B.Add(N + ': no such option (get_settings with list_all lists the names)');
    end;
  finally
    ENames.Free;
    PNames.Free;
  end;
end;

{ ---------------------------------------------------------------- get_settings }

function TGetSettingsTool.Name: string;
begin
  Result := 'get_settings';
end;

function TGetSettingsTool.Description: string;
begin
  Result := 'Returns the settings that decide how the code is built and edited: a project''s options (Project | ' +
    'Options: output and unit output folders, search path, conditional defines, unit aliases, compiler switches and ' +
    'the warnings turned off, linker, run-time packages, version information, run parameters), the IDE''s ' +
    'environment options (Delphi''s folder, library and browsing paths, package output folders, compiling and ' +
    'running, the form designer, code insight) and the code editor''s options (block indent, tab stops, tab ' +
    'character, right margin, font). Call it before you rely on a folder, a define, a switch or a package, and to ' +
    'indent new code as the editor does. With names it returns only those options; with list_all every option the ' +
    'IDE lists for the scope (project or environment).';
end;

procedure TGetSettingsTool.DefineInput(Schema: TJson);
begin
  SchemaEnum(Schema, 'scope', 'all|project|environment|editor', 'Which settings (default: all).', False);
  SchemaProp(Schema, 'project', 'string', 'A project of the group: its file or name (default: the active project).',
    False);
  SchemaArray(Schema, 'names', 'string', 'Only these options, by their names (e.g. "Defines", "UnitDir", ' +
    '"LibraryPath"): project options first, then environment options.', False);
  SchemaProp(Schema, 'list_all', 'boolean', 'Every option the IDE lists for the scope, with its value.', False);
end;

function TGetSettingsTool.Summarize(Input: TJson): string;
var
  A: TJson;
  I: Integer;
begin
  A := Input.Arr('names');
  if (A <> nil) and (A.Count > 0) then
  begin
    Result := '';
    for I := 0 to A.Count - 1 do
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + A.Item(I).AsString;
    end;
  end
  else
  begin
    Result := Input.Str('scope', 'all');
    if Input.Bool('list_all', False) then Result := Result + ', every option';
  end;
end;

procedure TGetSettingsTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  Scope: string;
  P: IOTAProject;
  B: TStringList;
  A: TJson;
  ListAll, Project, Env, Editor: Boolean;
begin
  Scope := LowerCase(Input.Str('scope', 'all'));
  Project := (Scope = 'all') or (Scope = 'project');
  Env := (Scope = 'all') or (Scope = 'environment');
  Editor := (Scope = 'all') or (Scope = 'editor');
  ListAll := Input.Bool('list_all', False);
  A := Input.Arr('names');
  P := nil;
  if Project then
  begin
    P := FindProject(ArgIde(Input, 'project'));
    if (P = nil) and (Trim(Input.Str('project')) <> '') then
    begin
      Res.Fail('There is no project ' + Input.Str('project') + ' in the IDE.');
      Exit;
    end;
  end;
  B := TStringList.Create;
  try
    if (A <> nil) and (A.Count > 0) then
      AddNamed(B, A, P, Project, Env)
    else
    begin
      if Project then AddProject(B, P, ListAll);
      if Env then AddEnvironment(B, ListAll);
      if Editor then AddEditor(B);
    end;
    Res.Ok(IdeToUtf8(TrimRight(B.Text)), Format('%d lines', [B.Count]));
  finally
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- set_project_option }

{ the project of the input, its options, the option as the IDE names it, its type and its value
  now; False with Problem (an IDE string) }
function ProjectOptionOf(Input: TJson; out P: IOTAProject; out O: IOTAProjectOptions; out Name: string;
  out Kind: TTypeKind; out Old: Variant; out Problem: string): Boolean;
var
  Names: TStringList;
  K: Integer;
begin
  Result := False;
  O := nil;
  Name := '';
  Kind := tkUnknown;
  Old := Unassigned;
  Problem := '';
  P := FindProject(ArgIde(Input, 'project'));
  if P = nil then
  begin
    if Trim(Input.Str('project')) <> '' then Problem := 'There is no project ' + ArgIde(Input, 'project') + ' in the IDE.'
    else Problem := 'No project is open.';
    Exit;
  end;
  O := ProjectOptionsOf(P);
  Names := TStringList.Create;
  try
    OptionNames(O, Names);
    K := Names.IndexOf(Trim(ArgIde(Input, 'name')));
    if K < 0 then
    begin
      Problem := 'There is no project option ' + ArgIde(Input, 'name') +
        '. get_settings with scope project and list_all lists them.';
      Exit;
    end;
    Name := Names[K];
    Kind := KindOf(Names, K);
  finally
    Names.Free;
  end;
  if not (Kind in [tkInteger, tkInt64, tkEnumeration, tkChar, tkString, tkLString, tkWString]) then
  begin
    Problem := Name + ' is a list or a set: set_project_option sets numbers, True / False and text only.';
    Exit;
  end;
  try
    Old := O.Values[Name];
  except
    on E: Exception do
    begin
      Problem := 'The IDE cannot read ' + Name + ': ' + E.Message;
      Exit;
    end;
  end;
  Result := True;
end;

function IsWord(const S: string; const Words: array of string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to High(Words) do
    if SameText(S, Words[I]) then Exit;
  Result := False;
end;

{ two values of an option as text are the same; a flag the same as a number (True 1, False 0): an
  IDE may give a value back in the other form }
function SameValueText(const A, B: string): Boolean;
begin
  Result := (A = B) or (IsWord(A, ['True', '1']) and IsWord(B, ['True', '1'])) or
    (IsWord(A, ['False', '0']) and IsWord(B, ['False', '0']));
end;

{ Text as a value of the option: text for a text option; a flag when its value now is one; else a
  whole number (decimal or $hex; on / off, True / False as 1 / 0); False with Problem }
function NewValue(const Name, Text: string; Kind: TTypeKind; const Old: Variant; out V: Variant;
  out Problem: string): Boolean;
var
  S: string;
  N: Integer;
begin
  Result := False;
  Problem := '';
  V := Unassigned;
  if Kind in [tkChar, tkString, tkLString, tkWString] then
  begin
    V := Text;
    Result := True;
    Exit;
  end;
  S := Trim(Text);
  if IsWord(S, ['True', 'On', 'Yes']) then N := 1
  else if IsWord(S, ['False', 'Off', 'No']) then N := 0
  else if not TryStrToInt(S, N) then
  begin
    if VarType(Old) = varBoolean then Problem := Name + ' takes True or False.'
    else Problem := Name + ' takes a whole number.';
    Exit;
  end;
  if VarType(Old) = varBoolean then
  begin
    if (N <> 0) and (N <> 1) then
    begin
      Problem := Name + ' takes True or False.';
      Exit;
    end;
    V := N = 1;
  end
  else
    V := N;
  Result := True;
end;

function TSetProjectOptionTool.Name: string;
begin
  Result := 'set_project_option';
end;

function TSetProjectOptionTool.Description: string;
begin
  Result := 'Sets one option of a project (Project | Options), by the name get_settings gives it: a number (a ' +
    'compiler switch is 1 on, 0 off), True or False, or text (folders and paths separated by ";", conditional ' +
    'defines separated by ";"). Read the option first and give the whole new value: to add a folder or a define, ' +
    'keep the ones it has. Lists and sets (the version information''s keys) cannot be set. The user is asked to ' +
    'approve it. The IDE writes the project''s options files (.dof, .cfg) itself - D7 Studio at once, Delphi 7 ' +
    'when the project is saved -, and compile_project uses the options from there.';
end;

procedure TSetProjectOptionTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'name', 'string', 'The option''s name, e.g. "Defines", "UnitDir", "OutputDir", "Optimization".', True);
  SchemaProp(Schema, 'value', 'string', 'The new value as text: a number, True / False, or the text.', True);
  SchemaProp(Schema, 'project', 'string', 'A project of the group: its file or name (default: the active project).',
    False);
end;

function TSetProjectOptionTool.IsChange: Boolean;
begin
  Result := True;
end;

function TSetProjectOptionTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('name') + ' := ' + TruncateUtf8(Input.Str('value'), 60);
end;

function TSetProjectOptionTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  P: IOTAProject;
  O: IOTAProjectOptions;
  N, Problem: string;
  Kind: TTypeKind;
  Old, V: Variant;
begin
  Result := False;
  if not ProjectOptionOf(Input, P, O, N, Kind, Old, Problem) or
    not NewValue(N, ArgIde(Input, 'value'), Kind, Old, V, Problem) then
  begin
    Res.Fail(IdeToUtf8(Problem));
    Exit;
  end;
  Change.FileName := P.FileName;
  Change.Title := Format('Set the project option %s of %s', [N, ExtractFileName(P.FileName)]);
  Change.Before := N + ' = ' + ValueText(Old, Kind);
  Change.After := N + ' = ' + ValueText(V, Kind);
  Result := True;
end;

procedure TSetProjectOptionTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  P: IOTAProject;
  O: IOTAProjectOptions;
  N, Problem, Was, Now: string;
  Kind: TTypeKind;
  Old, V: Variant;
begin
  if not ProjectOptionOf(Input, P, O, N, Kind, Old, Problem) or
    not NewValue(N, ArgIde(Input, 'value'), Kind, Old, V, Problem) then
  begin
    Res.Fail(IdeToUtf8(Problem));
    Exit;
  end;
  Was := ValueText(Old, Kind);
  try
    O.Values[N] := V;
    O.ModifiedState := True;
    Now := ValueText(O.Values[N], Kind);
  except
    on E: Exception do
    begin
      Res.Fail(IdeToUtf8('The IDE did not take the value: ' + E.Message));
      Exit;
    end;
  end;
  if not SameValueText(Now, ValueText(V, Kind)) then
  begin
    Res.Fail(IdeToUtf8(Format('The IDE kept %s = %s.', [N, Now])));
    Exit;
  end;
  Res.Ok(IdeToUtf8(Format('%s of %s is now %s (it was %s). D7 Studio writes the project''s options at once; ' +
    'Delphi 7 when the project is saved (File | Save All).', [N, ExtractFileName(P.FileName), Now, Was])), 'set');
end;

end.
