{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit MigOptions;

{ migrate - Delphi 7's option values into D7Studio.ini: the library folders; Environment,
  Editor and Debugger Options, the palette's arrangement, the To-Do List's filters; the Tools
  menu; the environment variables; the history lists and the recent files.

  Where D7 Studio reads a value in Delphi 7's layout (TDelphiValues: [Editor], [Debugger],
  [Editor Source Options\<ID>], [ToDo List]) the key keeps Delphi's name and text; its own keys
  ([Environment], [Designer] ...) get the value converted - flags as 1 / 0. Delphi 7's editor
  colours become D7 Studio's colour theme in use (MigrateColors, SdEditorThemes). A value of
  Delphi 7 replaces D7 Studio's; lists (folders, tools, histories) are merged. D7 Studio reads no
  registry for its options: a value its settings lack is taken from Delphi 7.

  Each procedure migrates the parts of its group that the run takes (MigCore.Wanted); the tools
  and the environment variables are items that can be left out one by one (MigCore.ItemExcluded),
  which List* gives to MigCore.ListItems. }

interface

uses
  Classes;

procedure MigrateLibrary;
procedure MigrateEnvironment;
procedure MigrateEditor;
procedure MigrateDebugger;
procedure MigrateTools;
procedure MigrateVariables;
procedure MigrateHistory;

{ the items of the parts tools and variables (MigCore.ListItems) }
procedure ListTools(List: TStrings);
procedure ListVariables(List: TStrings);

implementation

uses
  SysUtils, Graphics, MigCore, SdEditorThemes;

type
  { how a value of Delphi 7 becomes D7 Studio's: as it is, a flag 1 / 0, a path ($(DELPHI)\...),
    a list of paths, a full file name (no macro) }
  TConv = (cvText, cvFlag, cvPath, cvPathList, cvFile);

const
  { the values of [Editor] in Delphi's names: Editor\Options, Code Insight (its colours are the
    theme's: MigrateColors) }
  EditorNames = 'Insert|Cursor Through Tabs|Group Undo|Cursor Beyond EOF|Undo After Save|' +
    'BRIEF RegEx|Persistent Blocks|Overwrite Blocks|Double Click Line|Find Text At Cursor|' +
    'Force Cut Copy Enabled|Preserve Line Ends|Find AutoCompletes|Undo Limit|BRIEF Cursor Shapes|' +
    'Create Backup File|Sort Pages Menu|Visible Right Margin|Right Margin|Visible Gutter|' +
    'Gutter Width|Editor Font|Font Size';
  InsightNames = 'Auto Code Completions|Auto Code Parameters|Declaration Information|' +
    'Code Complete Delay';
  { the keymappings of D7 Studio (SdKeymaps), Delphi 7's names }
  KeymapNames = 'Default|IDE Classic|BRIEF Emulation|Epsilon|Visual Studio Emulation|' +
    'Visual Basic Emulation|New IDE Emacs';
  { the theme Delphi 7's colours make when they are no built-in theme's }
  Delphi7ThemeName = 'Delphi 7';
  { D7 Studio's colours before themes: [Editor Highlight] and these keys of [Editor] }
  OldHighlightSection = 'Editor Highlight';
  OldScrollBarKey = 'ScrollBarColor';
  { a file type's values ([Editor Source Options\<ID>], Editor\Source Options\<ID>) }
  FileTypeNames = 'Source Option Name|File Extensions|Syntax Highlighter ID|Auto Indent|' +
    'Backspace Unindents|Keep Trailing Blanks|Optimal Fill|Smart Tab|Tab Character|' +
    'Use Syntax Highlight|Show tab character|Show space character|Block Indent|Tab Stops';
  { the values of [Debugger] in Delphi's names (Debugging), without the event log's }
  DebuggerNames = 'Integrated Debugging|Map TD32 Keystrokes|Rearrange Editor Local Menu|' +
    'Mark Buffers Read Only|Allow Side Effects|Disable Multiple Evaluators|Debug Spawned Processes|' +
    'COM Cross Process|Inspector Show Inherited|Inspector Qualified Names|Inspector Sort By Name|' +
    'Stop On Delphi Exceptions|Stop On C++ Exceptions';
  { ... the event log's (Debugger Options | Event Log), without its kinds' }
  EventLogNames = 'Clear Log On Run|Unlimited Log|Log Process Info|Use Log Colors|Log Length';
  { the kinds of the event log: Log <kind>, <kind> Foreground, <kind> Background }
  LogKinds = 'Breakpoint Message|Process Message|Thread Message|Module Message|Output Message|' +
    'Window Message|Comment';
  { the Object Inspector's colours of Delphi 7 (D7 Studio's OIColor0, 2 .. 7: Gutter has none) }
  OIColorValues: array[0..6] of string = ('Background Color', 'Category Color', 'Column Name Color',
    'Column Value Color', 'Non Default Color', 'Reference Color', 'Readonly Property Color');
  OIColorKeys: array[0..6] of string = ('OIColor0', 'OIColor2', 'OIColor3', 'OIColor4', 'OIColor5',
    'OIColor6', 'OIColor7');
  { ... their defaults (Environment Options | Object Inspector | Default colors and settings) }
  OIColorDefaults: array[0..6] of string = ('clBtnFace', 'clMaroon', 'clBtnText', 'clNavy', 'clNavy',
    'clMaroon', 'clGrayText');

procedure Split(const S: string; List: TStrings);
begin
  List.Text := StringReplace(S, '|', #13#10, [rfReplaceAll]);
end;

function InList(const S, Names: string): Boolean;
begin
  Result := Pos('|' + LowerCase(S) + '|', '|' + LowerCase(Names) + '|') > 0;
end;

function FlagText(const V: string): string;
begin
  if SameText(V, 'True') or SameText(V, 'Yes') or (StrToIntDef(V, 0) <> 0) then Result := '1'
  else Result := '0';
end;

function Convert(const V: string; Conv: TConv): string;
begin
  case Conv of
    cvFlag: Result := FlagText(V);
    cvPath: Result := StudioPath(V);
    cvPathList: Result := StudioPathList(V);
    cvFile: Result := ExpandDelphi(V);
  else
    Result := V;
  end;
end;

{ the values Names ('|' separated) of Delphi's key SubKey into Section, under the same names }
procedure CopySame(const SubKey, Section, Names: string);
var
  L: TStringList;
  I: Integer;
  V: string;
begin
  L := TStringList.Create;
  try
    Split(Names, L);
    for I := 0 to L.Count - 1 do
      if DelphiValue(SubKey, L[I], V) then SetSetting(Section, L[I], V);
  finally
    L.Free;
  end;
end;

{ Pairs: Delphi's name, D7 Studio's key, ... }
procedure CopyMapped(const SubKey, Section: string; const Pairs: array of string; Conv: TConv);
var
  I: Integer;
  V: string;
begin
  I := 0;
  while I < High(Pairs) do
  begin
    if DelphiValue(SubKey, Pairs[I], V) then SetSetting(Section, Pairs[I + 1], Convert(V, Conv));
    Inc(I, 2);
  end;
end;

{ a choice of Delphi's as text: the index of the first of Choices the text contains }
procedure CopyChoice(const SubKey, Name, Section, Key: string; const Choices: array of string);
var
  I: Integer;
  V: string;
begin
  if not DelphiValue(SubKey, Name, V) then Exit;
  for I := 0 to High(Choices) do
    if Pos(UpperCase(Choices[I]), UpperCase(V)) > 0 then
    begin
      SetSetting(Section, Key, IntToStr(I));
      Exit;
    end;
end;

{ --- the library --- }

{ Current with the folders of Delphi's list added that it lacks }
function MergeFolders(const Current, Delphi: string): string;
var
  Cur, Add: TStringList;
  I, K: Integer;
  P: string;
  Found: Boolean;
begin
  Cur := TStringList.Create;
  Add := TStringList.Create;
  try
    SplitList(Current, Cur);
    SplitList(Delphi, Add);
    for I := 0 to Add.Count - 1 do
    begin
      P := StudioPath(Add[I]);
      Found := False;
      for K := 0 to Cur.Count - 1 do
        if SamePath(Cur[K], P) then Found := True;
      if not Found then Cur.Add(P);
    end;
    Result := JoinList(Cur);
  finally
    Add.Free;
    Cur.Free;
  end;
end;

{ a value of Delphi 7's library: a folder list merged into D7 Studio's (Delphi 7's alone when the
  settings have none), a folder replaced }
procedure MigrateLibraryValue(const Name, Key: string; List: Boolean);
var
  V: string;
begin
  if not DelphiValue('Library', Name, V) then Exit;
  if List then
    SetSetting('Environment', Key, MergeFolders(Settings.ReadString('Environment', Key, ''), V))
  else
    SetSetting('Environment', Key, StudioPath(V));
end;

procedure MigrateLibrary;
begin
  Part('Library (Environment Options | Library)');
  if not DelphiKeyExists('Library') then
  begin
    Say('Delphi 7 has no library settings');
    Exit;
  end;
  if Wanted('library.search') then MigrateLibraryValue('Search Path', 'LibraryPath', True);
  if Wanted('library.browsing') then MigrateLibraryValue('Browsing Path', 'BrowsingPath', True);
  if Wanted('library.output') then
  begin
    MigrateLibraryValue('Package DPL Output', 'BplOutputDir', False);
    MigrateLibraryValue('Package DCP Output', 'DcpOutputDir', False);
  end;
end;

{ --- Environment, Editor and Debugger Options --- }

{ a flag of Delphi 7's key (True, Yes, 1); False when it is not there }
function DelphiFlag(const SubKey, Name: string): Boolean;
var
  V: string;
begin
  Result := DelphiValue(SubKey, Name, V) and (FlagText(V) = '1');
end;

{ D7 Studio's colours of before themes go: Delphi 7's take their place }
procedure DropOldColors;
var
  E: TEditorElement;

  procedure Drop(const Key: string);
  begin
    if not Settings.ValueExists('Editor', Key) then Exit;
    Settings.DeleteKey('Editor', Key);
    Inc(SettingsChanged);
    Say(Format('[Editor] %s removed (a colour of before themes)', [Key]));
  end;

begin
  if Settings.SectionExists(OldHighlightSection) then
  begin
    Settings.EraseSection(OldHighlightSection);
    Inc(SettingsChanged);
    Say(Format('[%s] removed (the colours of before themes)', [OldHighlightSection]));
  end;
  Drop(OldScrollBarKey);
  Drop(DelphiInsightBackKey);
  for E := Low(DelphiSymbolKeys) to High(DelphiSymbolKeys) do Drop(DelphiSymbolKeys[E]);
end;

{ Delphi 7's editor colours - its Color page's elements (Editor\Highlight: a colour's text,
  "Use defaults for" as Delphi 7's factory colour) and its completion list's (Code Insight) - as D7
  Studio's colour theme in use: the built-in theme that has the same colours (Delphi 7's Classic is
  D7 Studio's), else the user's theme "Delphi 7", made anew. What Delphi 7 has no element for - the
  frame, the highlights - is the theme's Default. }
procedure MigrateColors;
var
  D: TDelphiColors;
  DE: TDelphiElement;
  C, B: TEditorColors;
  E: TEditorElement;
  K, Fore, Back, V, Name: string;
  Lines: TStringList;
begin
  if not DelphiKeyExists('Editor\Highlight') then
  begin
    Say('Delphi 7 has no editor colours');
    Exit;
  end;
  for DE := Low(DE) to High(DE) do
  begin
    FillChar(D[DE], SizeOf(D[DE]), 0);
    K := 'Editor\Highlight\' + DelphiElementKeys[DE];
    if not DelphiValue(K, 'Foreground Color New', Fore) or not DelphiValue(K, 'Background Color New', Back) then
      Continue;
    D[DE].Fore := ThemeTextColor(Fore);
    D[DE].Back := ThemeTextColor(Back);
    D[DE].Bold := DelphiFlag(K, 'Bold');
    D[DE].Italic := DelphiFlag(K, 'Italic');
    D[DE].Underline := DelphiFlag(K, 'Underline');
    D[DE].DefaultFore := DelphiFlag(K, 'Default Foreground');
    D[DE].DefaultBack := DelphiFlag(K, 'Default Background');
    D[DE].Present := (D[DE].Fore <> clDefault) and (D[DE].Back <> clDefault);
  end;
  { the completion list starts as Delphi 7's defaults (Light's): its own colours, where it has them }
  BuiltinThemeColors(DefaultThemeName, B);
  DefaultColors(C);
  for E := eeCompletion to eeCompAbstract do C[E] := B[E];
  ColorsFromDelphi(D, C);
  for E := Low(DelphiSymbolKeys) to High(DelphiSymbolKeys) do
    if DelphiValue('Code Insight', DelphiSymbolKeys[E], V) and (ThemeTextColor(V) <> clDefault) then
      C[E].Fore := ThemeTextColor(V);
  if DelphiValue('Code Insight', DelphiInsightBackKey, V) and (ThemeTextColor(V) <> clDefault) then
    C[eeCompletion].Back := ThemeTextColor(V);
  DropOldColors;
  Name := BuiltinThemeOf(C);
  if Name <> '' then
    Say(Format('Delphi 7''s colours are D7 Studio''s theme %s', [Name]))
  else
  begin
    Name := Delphi7ThemeName;
    Lines := TStringList.Create;
    try
      Lines.Add(ThemeNameKey + '=' + Name);
      for E := Low(E) to High(E) do Lines.Add(ElementKeys[E] + '=' + ElementText(C[E]));
      if ReplaceSection('Editor Theme\' + Name, Lines) then
        Say(Format('[Editor Theme\%s]: Delphi 7''s colours as a theme', [Name]))
      else
        Say(Format('the theme %s has Delphi 7''s colours already', [Name]));
    finally
      Lines.Free;
    end;
  end;
  SetSetting('Editor', 'Color SpeedSetting', Name);
end;

procedure MigrateFileTypes;
var
  IDs, Types: TStringList;
  I: Integer;
begin
  IDs := TStringList.Create;
  Types := TStringList.Create;
  try
    DelphiSubKeys('Editor\Source Options', IDs);
    { a list in the settings is the whole list (D7 Studio drops what it does not name) }
    if Settings.ValueExists('Editor Source Options', 'Types') then
    begin
      Types.CommaText := Settings.ReadString('Editor Source Options', 'Types', '');
      for I := 0 to IDs.Count - 1 do
        if Types.IndexOf(IDs[I]) < 0 then Types.Add(IDs[I]);
      SetSetting('Editor Source Options', 'Types', Types.CommaText);
    end;
    for I := 0 to IDs.Count - 1 do
      CopySame('Editor\Source Options\' + IDs[I], 'Editor Source Options\' + IDs[I], FileTypeNames);
  finally
    Types.Free;
    IDs.Free;
  end;
end;

procedure MigrateEditor;
var
  V: string;
begin
  Part('Editor Options');
  if Wanted('editor.settings') then
  begin
    CopySame('Editor\Options', 'Editor', EditorNames);
    CopySame('Code Insight', 'Editor', InsightNames);
    CopySame('Debugging', 'Editor', 'ToolTip Watches');
  end;
  if Wanted('editor.keymapping') and DelphiValue('Editor\Options', 'Editor Keymapping', V) then
    if InList(V, KeymapNames) then SetSetting('Editor', 'Editor Keymapping', V)
    else Warn(Format('the keymapping "%s" is not one of D7 Studio''s: not migrated', [V]));
  if Wanted('editor.colors') then MigrateColors;
  if Wanted('editor.filetypes') then MigrateFileTypes;
end;

procedure MigrateDebugger;
var
  L: TStringList;
  I: Integer;
  Names: string;
begin
  Part('Debugger Options');
  if Wanted('debugger.settings') then
  begin
    CopySame('Debugging', 'Debugger', DebuggerNames);
    CopyMapped('Debugging', 'Debugger', ['Debug DCUs Path', 'Debug DCUs Path',
      'Debug Symbols Search Path', 'Debug Symbols Search Path'], cvPathList);
  end;
  if Wanted('debugger.eventlog') then
  begin
    Names := EventLogNames;
    L := TStringList.Create;
    try
      Split(LogKinds, L);
      for I := 0 to L.Count - 1 do
        Names := Names + '|Log ' + L[I] + '|' + L[I] + ' Foreground|' + L[I] + ' Background';
    finally
      L.Free;
    end;
    CopySame('Debugging', 'Debugger', Names);
  end;
end;

procedure MigrateObjectInspector;
var
  I: Integer;
  V: string;
  Custom, Any: Boolean;
begin
  CopyMapped('Object Inspector', 'Environment', ['Show Instance List', 'OIShowInstanceList',
    'Show Classname in Instance List', 'OIShowClassNames', 'Show Status Bar', 'OIShowStatusBar',
    'Show Grid Lines', 'OIRenderGrid', 'Integral Height', 'OIIntegralHeight',
    'Show Read Only Properties', 'OIShowReadOnly', 'Bold Non Default Values', 'OIBoldNonDefault',
    'Reference Expandable', 'OIRefExpand', 'Reference On Events Page', 'OIRefOnEvents'], cvFlag);
  Custom := False;
  Any := False;
  for I := 0 to High(OIColorValues) do
    if DelphiValue('Object Inspector', OIColorValues[I], V) then
    begin
      Any := True;
      SetSetting('Environment', OIColorKeys[I], V);
      if not SameText(V, OIColorDefaults[I]) then Custom := True;
    end;
  { the Colors box: Custom colors and settings (0), else Default colors and settings (1) }
  if Any then
    if Custom then SetSetting('Environment', 'OISpeedSetting', '0')
    else SetSetting('Environment', 'OISpeedSetting', '1');
end;

procedure MigrateTypeLibrary;
var
  V, U: string;
begin
  CopyMapped('Type Library', 'Environment', ['IgnoreSpecialFlags', 'TLIgnoreFlags',
    'IgnorePreDeclId', 'TLFlag0', 'IgnoreReserved', 'TLFlag1', 'IgnoreHidden', 'TLFlag2',
    'IgnoreCanCreate', 'TLFlag3'], cvFlag);
  { Safecall function mapping: All v-table interfaces (0), Only dual interfaces (1), Do not map (2) }
  if DelphiValue('Type Library', 'SafeCallMapping', V) then
  begin
    U := UpperCase(V);
    if Pos('DUAL', U) > 0 then SetSetting('Environment', 'TLSafeCall', '1')
    else if (Pos('NOT ', U) > 0) or (Pos('N''T', U) > 0) then SetSetting('Environment', 'TLSafeCall', '2')
    else if (Pos('V-TABLE', U) > 0) or (Pos('ALL ', U) > 0) then SetSetting('Environment', 'TLSafeCall', '0')
    else Warn(Format('Type Library | SafeCallMapping "%s" is not known: not migrated', [V]));
  end;
  { the folder of imported units: set unless it is D7 Studio's default (<settings>\Imports) }
  if DelphiValue('ActiveX Controls', 'UnitDirName', V) and (V <> '') then
  begin
    V := ExpandDelphi(V);
    if Settings.ValueExists('Import Type Library', 'UnitDir') or not SamePath(V, SettingsDir + '\Imports') then
      SetSetting('Import Type Library', 'UnitDir', V);
  end;
end;

{ Delphi's palette (Palette: <page>=Unit.TClass;...) in D7 Studio's layout ([Palette]: .Order,
  <page>=TClass;..., the Frames tool as Frames, <page>.Hidden=...); pages without components
  are left out }
procedure MigratePalette;
var
  Vals, Items, Lines: TStringList;
  I, K, D: Integer;
  Name, Classes, Order, C: string;
begin
  Vals := TStringList.Create;
  Items := TStringList.Create;
  Lines := TStringList.Create;
  try
    DelphiValueList('Palette', Vals);
    if Vals.Count = 0 then Exit;
    Order := '';
    for I := 0 to Vals.Count - 1 do
    begin
      Name := Vals.Names[I];
      SplitList(Vals.ValueFromIndex[I], Items);
      Classes := '';
      for K := 0 to Items.Count - 1 do
      begin
        C := Items[K];
        if C[1] = '.' then Delete(C, 1, 1)
        else
        begin
          D := LastDelimiter('.', C);
          if D > 0 then Delete(C, 1, D);
        end;
        if C <> '' then Classes := Classes + C + ';';
      end;
      if Classes = '' then Continue;
      if not SameText(Copy(Name, Length(Name) - 6, 7), '.Hidden') then Order := Order + Name + ';';
      Lines.Add(Name + '=' + Classes);
    end;
    Lines.Insert(0, '.Order=' + Order);
    if ReplaceSection('Palette', Lines) then
      Say(Format('[Palette]: Delphi 7''s arrangement of the components (%d pages)', [Lines.Count - 1]));
  finally
    Lines.Free;
    Items.Free;
    Vals.Free;
  end;
end;

{ Environment Options | Explorer, and Class Completion's "Finish incomplete properties" }
procedure MigrateExplorer;
const
  { the Code Explorer's categories: Delphi's keys (SdEnvOptions' ExpCategoryKeys) }
  ExplorerKeys: array[0..16] of string = ('Private', 'Protected', 'Public', 'Published', 'Fields',
    'Properties', 'Methods', 'Classes', 'Interfaces', 'Procedures', 'Types', 'Variables', 'Uses',
    'Virtuals', 'Statics', 'Inherited', 'Introduced');
var
  I: Integer;
begin
  CopyMapped('Code Explorer', 'Environment', ['Show Mod Exp', 'ExAutoShow',
    'Highlight incomplete', 'ExHighlightIncomplete', 'DeclarationSyntax', 'ExShowSyntax'], cvFlag);
  CopyChoice('Code Explorer', 'Sorting', 'Environment', 'ExSortAlpha', ['Source', 'Alpha']);
  CopyChoice('Code Explorer', 'Initial View', 'Environment', 'ExBrowserView', ['Classes', 'Units', 'Globals']);
  CopyChoice('Code Explorer', 'Symbol Scope', 'Environment', 'ExBrowserScope', ['Project', 'All']);
  { the categories: their order, folders and open folders (SdEnvOptions' ExCategorySort, ExVisible,
    ExExpand - Delphi's keys) }
  CopyMapped('Code Explorer', 'Environment', ['CategorySort', 'ExCategorySort'], cvText);
  for I := Low(ExplorerKeys) to High(ExplorerKeys) do
    CopyMapped('Code Explorer', 'Environment', [ExplorerKeys[I] + 'Visible', 'Ex' + ExplorerKeys[I] + 'Visible',
      ExplorerKeys[I] + 'Expand', 'Ex' + ExplorerKeys[I] + 'Expand'], cvFlag);
  CopyMapped('Class Completion', 'Environment', ['Finish properties', 'ExFinishProperties'], cvFlag);
end;

procedure MigrateEnvironment;
begin
  Part('Environment Options');
  if Wanted('environment.preferences') then
  begin
    CopyMapped('Auto Save', 'Environment', ['Editor Files', 'AutosaveEditor', 'Desktop', 'AutosaveDesktop',
      'Symbols', 'DesktopSymbols'], cvFlag);
    CopyMapped('Main Window', 'Environment', ['Auto Drag Docking', 'AutoDragDocking'], cvFlag);
    CopyMapped('Compiling', 'Environment', ['Show Compiler Progress', 'ShowCompilerProgress',
      'Warn on Package Rebuild', 'WarnPackageRebuild'], cvFlag);
    CopyMapped('Debugging', 'Environment', ['Minimize On Run', 'MinimizeOnRun'], cvFlag);
    CopyMapped('Repository', 'Environment', ['Repository Dir', 'RepositoryDir'], cvFile);
  end;
  if Wanted('environment.designer') then
  begin
    CopyMapped('Form Design', 'Environment', ['Show Designer Hints', 'ShowDesignerHints',
      'Show Extended Control Hints', 'ShowExtendedHints', 'DFM As Text', 'NewFormsAsText',
      'Auto Create Forms', 'AutoCreateForms'], cvFlag);
    CopyMapped('Form Design', 'Designer', ['Display Grid', 'ShowGrid', 'Snap to Grid', 'SnapToGrid',
      'Show Component Captions', 'ShowCaptions'], cvFlag);
    CopyMapped('Form Design', 'Designer', ['Grid Size X', 'GridX', 'Grid Size Y', 'GridY'], cvText);
  end;
  if Wanted('environment.inspector') then MigrateObjectInspector;
  if Wanted('environment.explorer') then MigrateExplorer;
  if Wanted('environment.typelibrary') then MigrateTypeLibrary;
  if Wanted('environment.palette') then MigratePalette;
  if Wanted('environment.todo') then CopySame('ToDo List', 'ToDo List', 'HiddenCategories|HiddenOwners|HiddenItems');
end;

{ --- the Tools menu --- }

{ a menu item's caption without its accelerator: "&&" is "&", a single "&" goes }
function MenuText(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '&' then Inc(I);
    if I <= Length(S) then Result := Result + S[I];
    Inc(I);
  end;
end;

procedure ListTools(List: TStrings);
var
  S, T: string;
  I: Integer;
begin
  if not DelphiValue('Transfer', 'Count', S) then Exit;
  for I := 0 to StrToIntDef(S, 0) - 1 do
    if DelphiValue('Transfer', 'Title' + IntToStr(I), T) then AddItem(List, 'tools', T, MenuText(T));
end;

procedure MigrateTools;
var
  Cur: TStringList;
  Lines: TStringList;
  I, K, N, M: Integer;
  T, P, W, A, S: string;
begin
  Part('Tools menu (Tools | Configure Tools)');
  if not DelphiValue('Transfer', 'Count', S) then
  begin
    Say('Delphi 7 has no tools');
    Exit;
  end;
  N := StrToIntDef(S, 0);
  { D7 Studio's list as Title|Path|WorkingDir|Params lines }
  Cur := TStringList.Create;
  Lines := TStringList.Create;
  try
    M := Settings.ReadInteger('Transfer', 'Count', 0);
    for I := 0 to M - 1 do
    begin
      S := IntToStr(I);
      Cur.Add(Settings.ReadString('Transfer', 'Title' + S, '') + #9 + Settings.ReadString('Transfer', 'Path' + S, '') +
        #9 + Settings.ReadString('Transfer', 'WorkingDir' + S, '') + #9 + Settings.ReadString('Transfer', 'Params' + S, ''));
    end;
    for I := 0 to N - 1 do
    begin
      S := IntToStr(I);
      if not DelphiValue('Transfer', 'Title' + S, T) then Continue;
      if ItemExcluded('tools', T) then
      begin
        Say(Format('left out: the tool "%s"', [T]));
        Continue;
      end;
      if not DelphiValue('Transfer', 'Path' + S, P) then P := '';
      if not DelphiValue('Transfer', 'WorkingDir' + S, W) then W := '';
      if not DelphiValue('Transfer', 'Params' + S, A) then A := '';
      { D7 Studio does not expand $(DELPHI) in a tool's program and folder: full names }
      P := ExpandDelphi(P);
      W := ExpandDelphi(W);
      { the same title: Delphi 7's tool takes its place }
      M := -1;
      for K := 0 to Cur.Count - 1 do
        if SameText(Copy(Cur[K], 1, Pos(#9, Cur[K]) - 1), T) then M := K;
      if M >= 0 then Cur[M] := T + #9 + P + #9 + W + #9 + A
      else
      begin
        Cur.Add(T + #9 + P + #9 + W + #9 + A);
        Say(Format('+ the tool "%s" (%s)', [T, P]));
      end;
    end;
    if Cur.Count = 0 then Exit;
    Lines.Add('Count=' + IntToStr(Cur.Count));
    for I := 0 to Cur.Count - 1 do
    begin
      S := Cur[I];
      for K := 0 to 3 do
      begin
        M := Pos(#9, S);
        if M = 0 then M := Length(S) + 1;
        case K of
          0: Lines.Add('Title' + IntToStr(I) + '=' + Copy(S, 1, M - 1));
          1: Lines.Add('Path' + IntToStr(I) + '=' + Copy(S, 1, M - 1));
          2: Lines.Add('WorkingDir' + IntToStr(I) + '=' + Copy(S, 1, M - 1));
          3: Lines.Add('Params' + IntToStr(I) + '=' + Copy(S, 1, M - 1));
        end;
        Delete(S, 1, M);
      end;
    end;
    if ReplaceSection('Transfer', Lines) then Say(Format('[Transfer]: %d tools', [Cur.Count]))
    else Say('the tools are in D7 Studio already');
  finally
    Lines.Free;
    Cur.Free;
  end;
end;

{ --- environment variables --- }

procedure ListVariables(List: TStrings);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    DelphiValueList('Environment Variables', L);
    for I := 0 to L.Count - 1 do
      AddItem(List, 'variables', L.Names[I], L.Names[I] + ' = ' + L.ValueFromIndex[I]);
  finally
    L.Free;
  end;
end;

procedure MigrateVariables;
var
  L: TStringList;
  I: Integer;
begin
  Part('Environment variables (Environment Options | Environment Variables)');
  L := TStringList.Create;
  try
    DelphiValueList('Environment Variables', L);
    if L.Count = 0 then Say('Delphi 7 overrides none');
    for I := 0 to L.Count - 1 do
      if ItemExcluded('variables', L.Names[I]) then Say(Format('left out: the variable %s', [L.Names[I]]))
      else SetSetting('Environment Variables', L.Names[I], L.ValueFromIndex[I]);
  finally
    L.Free;
  end;
end;

{ --- history lists and recent files --- }

const
  { Delphi's history lists D7 Studio keeps: Delphi's name=D7 Studio's }
  HistoryNames: array[0..12] of string = ('hlSearchText=hlFindText', 'hlReplaceText=hlReplaceText',
    'hlLibraryPath=hlLibraryPath', 'hlDPLOutput=hlDPLOutput', 'hlDCPOutput=hlDCPOutput',
    'hIBrowsingPath=hIBrowsingPath', 'hlAddModule=hlAddModule', 'hlBreakFileName=hlBreakFileName',
    'hlBreakCondition=hlBreakCondition', 'hlWatchExpression=hlWatchExpression',
    'hlWatchGroup=hlWatchGroup', 'hlErrorAddress=hlErrorAddress', 'hlBrowseSymbol=hlBrowseSymbol');
  HistoryMax = 20;
  RecentMax = 10;

{ S added to Items unless it is empty, there already (any case) or Items holds Max entries }
procedure AddDistinct(Items: TStrings; const S: string; Max: Integer);
var
  K: Integer;
begin
  if S = '' then Exit;
  for K := 0 to Items.Count - 1 do
    if SameText(Items[K], S) then Exit;
  if Items.Count < Max then Items.Add(S);
end;

{ a history list: D7 Studio's entries, then Delphi's it lacks (any case), at most HistoryMax }
procedure MigrateHistoryList(const DelphiName, StudioName: string; Paths: Boolean);
var
  Sec, V: string;
  Items, Lines: TStringList;
  I, N: Integer;

begin
  if not DelphiValue('History Lists\' + DelphiName, 'Count', V) then Exit;
  Sec := 'HistoryLists\' + StudioName;
  Items := TStringList.Create;
  Lines := TStringList.Create;
  try
    N := Settings.ReadInteger(Sec, 'Count', 0);
    for I := 0 to N - 1 do AddDistinct(Items, Settings.ReadString(Sec, 'Item' + IntToStr(I), ''), HistoryMax);
    N := StrToIntDef(V, 0);
    for I := 0 to N - 1 do
      if DelphiValue('History Lists\' + DelphiName, 'Item' + IntToStr(I), V) then
        if Paths then AddDistinct(Items, MergeFolders('', V), HistoryMax) else AddDistinct(Items, V, HistoryMax);
    Lines.Add('Count=' + IntToStr(Items.Count));
    for I := 0 to Items.Count - 1 do Lines.Add('Item' + IntToStr(I) + '=' + Items[I]);
    if ReplaceSection(Sec, Lines) then Say(Format('[%s]: %d entries', [Sec, Items.Count]));
  finally
    Lines.Free;
    Items.Free;
  end;
end;

{ Closed Files / Closed Projects (File_0=SourceModule,'<file>',...): the files that exist, after
  D7 Studio's own ([RecentFiles] / [RecentProjects] File0.., newest first) }
procedure MigrateRecent(const SubKey, Section: string);
var
  Vals, Items, Lines: TStringList;
  I, A, B: Integer;
  S, F: string;

begin
  Vals := TStringList.Create;
  Items := TStringList.Create;
  Lines := TStringList.Create;
  try
    DelphiValueList(SubKey, Vals);
    if Vals.Count = 0 then Exit;
    for I := 0 to RecentMax - 1 do AddDistinct(Items, Settings.ReadString(Section, 'File' + IntToStr(I), ''), RecentMax);
    for I := 0 to RecentMax - 1 do
    begin
      S := Vals.Values['File_' + IntToStr(I)];
      A := Pos(',''', S);
      if A = 0 then Continue;
      F := Copy(S, A + 2, MaxInt);
      B := Pos(''',', F);
      if B = 0 then B := Length(F) + 1;
      F := Copy(F, 1, B - 1);
      if FileExists(F) then AddDistinct(Items, F, RecentMax);
    end;
    for I := 0 to Items.Count - 1 do Lines.Add('File' + IntToStr(I) + '=' + Items[I]);
    if ReplaceSection(Section, Lines) then Say(Format('[%s]: %d files', [Section, Items.Count]));
  finally
    Lines.Free;
    Items.Free;
    Vals.Free;
  end;
end;

procedure MigrateHistory;
var
  I, E: Integer;
  D: string;
begin
  Part('History lists and recent files');
  if Wanted('history.lists') then
    for I := 0 to High(HistoryNames) do
    begin
      E := Pos('=', HistoryNames[I]);
      D := Copy(HistoryNames[I], 1, E - 1);
      MigrateHistoryList(D, Copy(HistoryNames[I], E + 1, MaxInt),
        InList(D, 'hlLibraryPath|hlDPLOutput|hlDCPOutput|hIBrowsingPath'));
    end;
  if Wanted('history.projects') then MigrateRecent('Closed Projects', 'RecentProjects');
  if Wanted('history.files') then MigrateRecent('Closed Files', 'RecentFiles');
end;

end.
