{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEditorOptions;

{ D7 Studio - the editor's options (Tools | Editor Options): the
  values of Delphi 7's Editor Properties - General, Source Options (per source file type),
  Display, Key Mappings, Code Insight -, the colour theme of the Color page (SdEditorThemes) and
  D7 Studio's own options.

  Kept in the settings alone ([Editor], [Editor Source Options] and a section per file type,
  Delphi's value names - SdSettings.TDelphiValues; migrate.exe copies Delphi 7's into them when D7
  Studio is installed; the user's themes in [Editor Theme\<name>]). Where the settings have none
  yet, the values are Delphi 7's factory defaults and the theme is D7 Studio's Light. The colours
  of earlier versions ([Editor Highlight], the scroll bars' and the completion list's colours)
  become a theme once (ConvertOldColors). }

interface

uses
  Windows, SysUtils, Classes, Graphics, IniFiles, SdEditorThemes;

type
  { a source file type of the Source Options page }
  TEditorFileType = record
    ID: string;                     // Delphi's: Borland.EditOptions.Pascal
    Name: string;                   // Pascal
    Extensions: string;             // pas;dpr;dpk;inc
    Highlighter: string;            // Borland.Highlighter.Pascal (Borland.Highlighter.None: none)
    AutoIndent, BackspaceUnindents, KeepTrailingBlanks, OptimalFill, SmartTab, UseTabChar,
      UseSyntaxHighlight, ShowTabChar, ShowSpaceChar: Boolean;
    BlockIndent: Integer;
    TabStops: string;               // "4" or columns "9 17"
  end;
  TEditorFileTypes = array of TEditorFileType;

  TEditorOptions = record
    { General }
    InsertMode, CursorThroughTabs, GroupUndo, CursorBeyondEOF, UndoAfterSave, BriefRegExp,
      PersistentBlocks, OverwriteBlocks, DoubleClickLine, FindTextAtCursor, ForceCutCopy,
      PreserveLineEnds, FindAutoComplete: Boolean;
    UndoLimit: Integer;
    { Source Options }
    FileTypes: TEditorFileTypes;
    { Display. CreateBackup: Delphi's Create backup file, kept for the Open Tools API (an expert's file
      system makes the backup); D7 Studio writes no backup of its own - KeepHistory keeps the files'
      versions for the History tab (SdHistory), HistoryLimit of them per file }
    BriefCursors, CreateBackup, SortPagesMenu, ShowRightMargin, VisibleGutter, KeepHistory: Boolean;
    RightMargin, GutterWidth, HistoryLimit: Integer;
    FontName: string;
    FontSize: Integer;
    { Key Mappings }
    Keymapping: string;
    { Color: the theme in use (a built-in's name or one of Themes'), the user's own themes, the
      colours of the theme in use (SelectTheme keeps them in step) }
    ColorTheme: string;
    Themes: TEditorThemes;
    Colors: TEditorColors;
    { Code Insight }
    AutoComplete, AutoParameters, TooltipEval, TooltipDecl: Boolean;
    CodeDelay: Integer;             // tenths of a second, 1..15 (Delphi's slider)
    ErrorInsight: Boolean;          // D7 Studio's own: a Pascal text's errors marked after a pause (Diagnose)
    { D7 Studio's own }
    ShowLineNumbers, ShowFolding, ShowChangeBars, HighlightBraces, HighlightOccurrences: Boolean;
    FoldPreview: Boolean;           // the code a folded line hides, in a tip over its box (TSciEdit.FoldPreview)
    WordWrap, ScrollBarMarkers: Boolean;
    Minimap: Integer;               // the text in miniature beside the vertical scroll bar (SdSciMinimap): MinimapNone ...
    NavigationBar: Boolean;         // the Class and Methods/functions boxes over a Pascal file's code
    MultiLineTabs: Boolean;         // the file tabs in as many rows as they need (off: one row and its list button)
    SelectionButton: Boolean;       // a button by the selection that opens the menu of its commands (TSciEdit.SelectionButton)
    { D7 Studio's Highlighting page }
    HighlightIdentifiers, HighlightBlocks, RainbowBrackets, HighlightFindMatches,
      HighlightCurrentLine, IndentGuides: Boolean;
    HighlightFlowControl: Boolean;  // Exit, Break, Continue, Halt, Abort, raise, goto in Flow control's colour
    CustomIdentifiers: string;      // the identifiers in Custom identifier's colour, separated by blanks or commas
    { D7 Studio's Typing page }
    AutoClosePairs, BlockCompletion, SmartIndent, CaretClick: Boolean;
    Zoom: Integer;                  // Scintilla's zoom of every editor, in points (0: none)
  end;

const
  NoHighlighter = 'Borland.Highlighter.None';
  PascalHighlighter = 'Borland.Highlighter.Pascal';
  DefaultKeymapping = 'Default';
  DefaultTypeID = 'Borland.EditOptions.Default';   // Delphi 7's file type of the other files
  { TEditorOptions.Minimap: none, the map, the map with the tip of the code under the pointer }
  MinimapNone = 0;
  MinimapOn = 1;
  MinimapPreview = 2;

var
  EditorOptions: TEditorOptions;

{ the values in the settings, else Delphi 7's factory defaults }
procedure LoadEditorOptions(Ini: TCustomIniFile);
procedure SaveEditorOptions(Ini: TCustomIniFile);
{ the file type of a file name (by its extension; the Default type else) }
function EditorFileType(const FileName: string): TEditorFileType;
function EditorFileTypeIndex(const FileName: string): Integer;
{ the index of the file type whose ID (its name in Source Options) is ID; -1: none }
function EditorFileTypeOfID(const ID: string): Integer;
{ the colour an element shows: its own, else its Default - worked out from the theme's plain
  text: the text's tokens and the completion list take the plain text's colours (the names by
  kind Identifier's; SdEditorThemes.PascalFore / PascalBack), the frame
  (gutter, guides, folding marks, the highlights) shades of them, the selection, search match,
  hot link and the completion list's kinds D7 Studio's Light or Dark colours for such a ground,
  the debugger's lines Delphi 7's. The scroll bars' Default stays clDefault: SdSciScroll works the
  thumb out from the ground }
function ElementFore(const C: TEditorColors; E: TEditorElement): TColor;
function ElementBack(const C: TEditorColors; E: TEditorElement): TColor;
{ the colour of Error Insight's marks - the wavy line under an error, its scroll bar markers: the
  error line's ground, on a dark text ground as bright as it goes in its hue (a dark red mark would
  vanish there) }
function ErrorMarkColor(const C: TEditorColors): TColor;
{ the plain text's ground is dark (Dark, Classic, any dark one the user made): the editor's frame
  and the code tips follow it }
function EditorIsDark(const C: TEditorColors): Boolean;
{ the themes: the built-ins, then O's own in their order }
procedure ThemeNames(const O: TEditorOptions; List: TStrings);
{ the index of the user's theme Name in O.Themes (any case; -1: none) }
function UserThemeIndex(const O: TEditorOptions; const Name: string): Integer;
{ the colours of the theme Name - a built-in's or one of O.Themes; False: there is none }
function ThemeColors(const O: TEditorOptions; const Name: string; var C: TEditorColors): Boolean;
{ the theme Name in use: O.ColorTheme and O.Colors; False (nothing changed): there is none }
function SelectTheme(var O: TEditorOptions; const Name: string): Boolean;
{ an element of the theme in use changed: in O.Colors and in the user's theme. A built-in theme
  never changes: the first change makes a theme of the user's from it ("Dark (custom)"), which is
  in use from then on - True when it did }
function ChangeThemeElement(var O: TEditorOptions; E: TEditorElement; const Value: TEditorColor): Boolean;
{ SdEditorThemes.FollowPlainText on the colours in use and on every theme of the user's }
procedure ThemesFollowPlainText(var O: TEditorOptions);
{ Base, else the first name after it that is no theme's (a built-in's or one of O.Themes'; FreeThemeName) }
function FreeUserThemeName(const O: TEditorOptions; const Base: string): string;
{ a theme of the user's with the colours C, at the end of O.Themes: named Base, else the first
  free name after it (FreeUserThemeName); its index }
function AddUserTheme(var O: TEditorOptions; const Base: string; const C: TEditorColors): Integer;
{ the user's theme Index goes; when it was in use, Light or Dark (the one of its ground) is }
procedure DeleteUserTheme(var O: TEditorOptions; Index: Integer);
{ a theme of the user's in Section of Ini (a theme file's too): its elements' colours, the others Default -
  Flow control and Custom identifier, which themes of before them lack, Light's or Dark's by its ground (Default
  would be Identifier's: the words would not stand out) }
procedure ReadUserTheme(Ini: TCustomIniFile; const Section: string; var C: TEditorColors);
{ a theme file: the theme's name and colours (raises EInOutError when it cannot be written); and
  back - False when the file has no theme (its name: the file's when it names none) }
procedure ExportTheme(const FileName: string; const T: TEditorTheme);
function ImportTheme(const FileName: string; var T: TEditorTheme): Boolean;
{ the first tab width of a Tab stops value ("4"; columns "9 17" -> 8) }
function TabWidthOf(const TabStops: string): Integer;

implementation

uses
  Forms, SdSettings, SdUI, SdFileNames;

const
  SecEditor = 'Editor';
  SecSource = 'Editor Source Options';
  SecTheme = 'Editor Theme\';       // a theme of the user's: [Editor Theme\<name>]
  SecOldHighlight = 'Editor Highlight';   // Delphi 7's 28 elements, before themes
  OldScrollBarKey = 'ScrollBarColor';

{ --- Delphi 7's factory values --- }

{ a file type as Delphi 7 ships it: Auto indent and Backspace unindents on, no trailing blanks
  kept, no tab or space marks }
function MakeFileType(const AID, AName, AExts, AHighlighter: string; ATabs, ASmart, AOptimal,
  ASyntax: Boolean; AIndent: Integer; const AStops: string): TEditorFileType;
begin
  Result.ID := AID;
  Result.Name := AName;
  Result.Extensions := AExts;
  Result.Highlighter := AHighlighter;
  Result.AutoIndent := True;
  Result.BackspaceUnindents := True;
  Result.KeepTrailingBlanks := False;
  Result.OptimalFill := AOptimal;
  Result.SmartTab := ASmart;
  Result.UseTabChar := ATabs;
  Result.UseSyntaxHighlight := ASyntax;
  Result.ShowTabChar := False;
  Result.ShowSpaceChar := False;
  Result.BlockIndent := AIndent;
  Result.TabStops := AStops;
end;

{ Delphi 7's Default file type: the one of a file no other type claims }
function DefaultFileType: TEditorFileType;
begin
  Result := MakeFileType(DefaultTypeID, 'Default', '', NoHighlighter, False, False, False, False, 8, '8');
end;

procedure AddFileType(var O: TEditorOptions; const F: TEditorFileType);
var
  N: Integer;
begin
  N := Length(O.FileTypes);
  SetLength(O.FileTypes, N + 1);
  O.FileTypes[N] := F;
end;

{ Delphi 7's values of a fresh installation (its Source Options as it ships them). The types
  other than Pascal name no highlighter: the editor's lexer of a file's extension colours it
  (SdSciEdit.LanguageFromFileName) }
procedure FactoryOptions(var O: TEditorOptions);
begin
  O.InsertMode := True;
  O.CursorThroughTabs := True;
  O.GroupUndo := True;
  O.CursorBeyondEOF := False;
  O.UndoAfterSave := False;
  O.BriefRegExp := False;
  O.PersistentBlocks := False;
  O.OverwriteBlocks := True;
  O.DoubleClickLine := False;
  O.FindTextAtCursor := True;
  O.ForceCutCopy := False;
  O.PreserveLineEnds := True;
  O.FindAutoComplete := True;
  O.UndoLimit := 32767;
  SetLength(O.FileTypes, 0);
  AddFileType(O, MakeFileType('Borland.EditOptions.Pascal', 'Pascal', 'pas;dpr;dpk;inc;dfm;xfm;dpkw',
    PascalHighlighter, False, True, True, True, 2, '3 5'));
  AddFileType(O, MakeFileType('Borland.EditOptions.C', 'C/C++', 'cpp;c;cc;hpp;h;hh;cxx;hxx;bpkw',
    NoHighlighter, True, False, False, True, 4, '4'));
  AddFileType(O, MakeFileType('Borland.EditOptions.C#', 'C#', 'cs', NoHighlighter,
    True, False, False, True, 4, '4'));
  AddFileType(O, MakeFileType('Borland.EditOptions.HTML', 'HTML', 'html;htm;asp;aspx', NoHighlighter,
    True, False, False, True, 4, '4'));
  AddFileType(O, MakeFileType('Borland.EditOptions.IDL', 'IDL', 'idl', NoHighlighter,
    False, False, False, True, 2, '2'));
  AddFileType(O, MakeFileType('Borland.EditOptions.SQL', 'SQL', 'sql', NoHighlighter,
    False, False, False, True, 2, '2'));
  AddFileType(O, MakeFileType('Borland.EditOptions.XML', 'XML', 'xml;xsl;xsd;wml;manifest', NoHighlighter,
    True, False, False, True, 4, '4'));
  AddFileType(O, DefaultFileType);
  O.BriefCursors := False;
  O.CreateBackup := True;
  O.KeepHistory := True;
  O.HistoryLimit := 50;
  O.SortPagesMenu := True;
  O.ShowRightMargin := True;
  O.RightMargin := 80;
  O.VisibleGutter := True;
  O.GutterWidth := 30;
  O.FontName := 'Courier New';
  O.FontSize := 10;
  O.Keymapping := DefaultKeymapping;
  { the colours: Light, unless the settings have another theme }
  O.ColorTheme := DefaultThemeName;
  SetLength(O.Themes, 0);
  BuiltinThemeColors(DefaultThemeName, O.Colors);
  O.AutoComplete := True;
  O.AutoParameters := True;
  O.TooltipEval := True;
  O.TooltipDecl := True;
  O.CodeDelay := 10;
  O.ErrorInsight := True;
  O.ShowLineNumbers := True;
  O.ShowFolding := True;
  O.FoldPreview := True;
  O.ShowChangeBars := True;
  O.HighlightBraces := True;
  O.HighlightOccurrences := False;
  O.WordWrap := False;
  O.ScrollBarMarkers := True;
  O.Minimap := MinimapPreview;
  O.NavigationBar := True;
  O.MultiLineTabs := False;
  O.SelectionButton := True;
  O.HighlightIdentifiers := True;
  O.HighlightBlocks := True;
  O.RainbowBrackets := False;
  O.HighlightFindMatches := True;
  O.HighlightCurrentLine := True;
  O.IndentGuides := True;
  O.HighlightFlowControl := True;
  O.CustomIdentifiers := '';
  O.AutoClosePairs := True;
  O.BlockCompletion := True;
  O.SmartIndent := True;
  O.CaretClick := True;
  O.Zoom := 0;
end;

{ --- reading values: the settings, else what is there (SdSettings.TDelphiValues) --- }

{ a file type's values, Delphi's names: [Editor Source Options\<ID>] - each key once, for reading
  and writing }
function FileTypeTable(var F: TEditorFileType): TSdOptions;
begin
  Result := nil;
  AddOptions(Result, [
    OptStr('Source Option Name', F.Name),
    OptStr('File Extensions', F.Extensions),
    OptStr('Syntax Highlighter ID', F.Highlighter),
    OptBool('Auto Indent', F.AutoIndent),
    OptBool('Backspace Unindents', F.BackspaceUnindents),
    OptBool('Keep Trailing Blanks', F.KeepTrailingBlanks),
    OptBool('Optimal Fill', F.OptimalFill),
    OptBool('Smart Tab', F.SmartTab),
    OptBool('Tab Character', F.UseTabChar),
    OptBool('Use Syntax Highlight', F.UseSyntaxHighlight),
    OptBool('Show tab character', F.ShowTabChar),
    OptBool('Show space character', F.ShowSpaceChar),
    OptInt('Block Indent', F.BlockIndent),
    OptStr('Tab Stops', F.TabStops)]);
end;

{ Delphi's own highlighters other than Pascal colour nothing in D7 Studio: a type that names one
  has none }
procedure ReadFileType(Ini: TCustomIniFile; var F: TEditorFileType);
var
  S: TDelphiValues;
begin
  S := TDelphiValues.Create(Ini, SecSource + '\' + F.ID);
  try
    ReadOptions(FileTypeTable(F), Ini, SecSource + '\' + F.ID, [S]);
  finally
    S.Free;
  end;
  if SameText(Copy(F.Highlighter, 1, Length('Borland.Highlighter.')), 'Borland.Highlighter.') and
    not SameText(F.Highlighter, PascalHighlighter) then F.Highlighter := NoHighlighter;
end;

procedure WriteFileType(Ini: TCustomIniFile; const F: TEditorFileType);
var
  Sec: string;
  G: TEditorFileType;
begin
  Sec := SecSource + '\' + F.ID;
  Ini.EraseSection(Sec);
  G := F;
  WriteOptions(FileTypeTable(G), Ini, Sec);
end;

{ the file types: the settings' list, else the factory list }
procedure ReadFileTypes(Ini: TCustomIniFile; var O: TEditorOptions);
var
  IDs: TStringList;
  I, K: Integer;
  F: TEditorFileType;
  Found: Boolean;
begin
  IDs := TStringList.Create;
  try
    IDs.CommaText := Ini.ReadString(SecSource, 'Types', '');
    { the known types keep their places; the others follow in their order }
    for I := 0 to IDs.Count - 1 do
    begin
      Found := False;
      for K := 0 to High(O.FileTypes) do
        if SameText(O.FileTypes[K].ID, IDs[I]) then Found := True;
      if not Found then
      begin
        F := O.FileTypes[High(O.FileTypes)];       // the Default type's values to start from
        F.ID := IDs[I];
        F.Name := IDs[I];
        F.Extensions := '';
        SetLength(O.FileTypes, Length(O.FileTypes) + 1);
        O.FileTypes[High(O.FileTypes)] := F;
      end;
    end;
    { a list in the settings is the list: what it does not name was deleted }
    if Ini.ValueExists(SecSource, 'Types') then
    begin
      K := 0;
      for I := 0 to High(O.FileTypes) do
        if IDs.IndexOf(O.FileTypes[I].ID) >= 0 then
        begin
          O.FileTypes[K] := O.FileTypes[I];
          Inc(K);
        end;
      SetLength(O.FileTypes, K);
    end;
  finally
    IDs.Free;
  end;
  for I := 0 to High(O.FileTypes) do ReadFileType(Ini, O.FileTypes[I]);
end;

{ the values of [Editor]: each key once, for reading and writing (in this order). Source 0:
  Delphi's editor options, 1: its Code Insight values, 2: its debugger's (ToolTip Watches); -1:
  D7 Studio's own keys, in the settings only. Color SpeedSetting, Delphi's name of its colour
  scheme, names the theme in use }
function EditorTable(var O: TEditorOptions): TSdOptions;
begin
  Result := nil;
  AddOptions(Result, [
    OptBool('Insert', O.InsertMode),
    OptBool('Cursor Through Tabs', O.CursorThroughTabs),
    OptBool('Group Undo', O.GroupUndo),
    OptBool('Cursor Beyond EOF', O.CursorBeyondEOF),
    OptBool('Undo After Save', O.UndoAfterSave),
    OptBool('BRIEF RegEx', O.BriefRegExp),
    OptBool('Persistent Blocks', O.PersistentBlocks),
    OptBool('Overwrite Blocks', O.OverwriteBlocks),
    OptBool('Double Click Line', O.DoubleClickLine),
    OptBool('Find Text At Cursor', O.FindTextAtCursor),
    OptBool('Force Cut Copy Enabled', O.ForceCutCopy),
    OptBool('Preserve Line Ends', O.PreserveLineEnds),
    OptBool('Find AutoCompletes', O.FindAutoComplete),
    OptInt('Undo Limit', O.UndoLimit),
    OptBool('BRIEF Cursor Shapes', O.BriefCursors),
    OptBool('Create Backup File', O.CreateBackup),
    OptBool('Sort Pages Menu', O.SortPagesMenu),
    OptBool('Visible Right Margin', O.ShowRightMargin),
    OptInt('Right Margin', O.RightMargin),
    OptBool('Visible Gutter', O.VisibleGutter),
    OptInt('Gutter Width', O.GutterWidth),
    OptStr('Editor Font', O.FontName),
    OptInt('Font Size', O.FontSize),
    OptStr('Editor Keymapping', O.Keymapping, -1),      // SdKeymaps
    OptStr('Color SpeedSetting', O.ColorTheme),
    OptBool('Auto Code Completions', O.AutoComplete, 1),
    OptBool('Auto Code Parameters', O.AutoParameters, 1),
    OptBool('ToolTip Watches', O.TooltipEval, 2),
    OptBool('Declaration Information', O.TooltipDecl, 1),
    OptInt('Code Complete Delay', O.CodeDelay, 1),
    OptFlag('LineNumbers', O.ShowLineNumbers, -1),
    OptFlag('Folding', O.ShowFolding, -1),
    OptFlag('FoldPreview', O.FoldPreview, -1),
    OptFlag('ChangeBars', O.ShowChangeBars, -1),
    OptFlag('Braces', O.HighlightBraces, -1),
    OptFlag('Occurrences', O.HighlightOccurrences, -1),
    OptFlag('WordWrap', O.WordWrap, -1),
    OptFlag('ScrollBarMarkers', O.ScrollBarMarkers, -1),
    OptInt('Minimap', O.Minimap, -1),
    OptFlag('NavigationBar', O.NavigationBar, -1),
    OptFlag('MultiLineTabs', O.MultiLineTabs, -1),
    OptFlag('SelectionButton', O.SelectionButton, -1),
    OptFlag('KeepFileHistory', O.KeepHistory, -1),
    OptInt('FileHistoryLimit', O.HistoryLimit, -1),
    OptFlag('ErrorInsight', O.ErrorInsight, -1),
    OptFlag('Identifiers', O.HighlightIdentifiers, -1),
    OptFlag('Blocks', O.HighlightBlocks, -1),
    OptFlag('RainbowBrackets', O.RainbowBrackets, -1),
    OptFlag('FindMatches', O.HighlightFindMatches, -1),
    OptFlag('CurrentLine', O.HighlightCurrentLine, -1),
    OptFlag('IndentGuides', O.IndentGuides, -1),
    OptFlag('FlowControl', O.HighlightFlowControl, -1),
    OptStr('CustomIdentifiers', O.CustomIdentifiers, -1),
    OptFlag('AutoClosePairs', O.AutoClosePairs, -1),
    OptFlag('BlockCompletion', O.BlockCompletion, -1),
    OptFlag('SmartIndent', O.SmartIndent, -1),
    OptFlag('CaretClick', O.CaretClick, -1),
    OptInt('Zoom', O.Zoom, -1)]);
end;

{ --- themes --- }

function UserThemeIndex(const O: TEditorOptions; const Name: string): Integer;
begin
  Result := High(O.Themes);
  while (Result >= 0) and not SameText(O.Themes[Result].Name, Trim(Name)) do Dec(Result);
end;

procedure ThemeNames(const O: TEditorOptions; List: TStrings);
var
  I: Integer;
begin
  List.Clear;
  for I := 0 to BuiltinThemeCount - 1 do List.Add(BuiltinThemeName(I));
  for I := 0 to High(O.Themes) do List.Add(O.Themes[I].Name);
end;

function ThemeColors(const O: TEditorOptions; const Name: string; var C: TEditorColors): Boolean;
var
  I: Integer;
begin
  Result := BuiltinThemeColors(Name, C);
  if Result then Exit;
  I := UserThemeIndex(O, Name);
  Result := I >= 0;
  if Result then C := O.Themes[I].Colors;
end;

function SelectTheme(var O: TEditorOptions; const Name: string): Boolean;
var
  C: TEditorColors;
  I: Integer;
  N: string;
begin
  { a copy: Name may be O.ColorTheme itself, which changes here }
  N := Trim(Name);
  Result := ThemeColors(O, N, C);
  if not Result then Exit;
  O.Colors := C;
  { the theme's own spelling of its name }
  I := UserThemeIndex(O, N);
  if I >= 0 then O.ColorTheme := O.Themes[I].Name
  else O.ColorTheme := N;
  for I := 0 to BuiltinThemeCount - 1 do
    if SameText(BuiltinThemeName(I), N) then O.ColorTheme := BuiltinThemeName(I);
end;

function FreeUserThemeName(const O: TEditorOptions; const Base: string): string;
var
  Names: TStringList;
  I: Integer;
begin
  Names := TStringList.Create;
  try
    for I := 0 to High(O.Themes) do Names.Add(O.Themes[I].Name);
    Result := FreeThemeName(Base, Names);
  finally
    Names.Free;
  end;
end;

function AddUserTheme(var O: TEditorOptions; const Base: string; const C: TEditorColors): Integer;
var
  Name: string;
  Colors: TEditorColors;
begin
  { copies first: Base and C may lie in O.Themes, which SetLength moves }
  Name := FreeUserThemeName(O, Base);
  Colors := C;
  Result := Length(O.Themes);
  SetLength(O.Themes, Result + 1);
  O.Themes[Result].Name := Name;
  O.Themes[Result].Colors := Colors;
end;

procedure DeleteUserTheme(var O: TEditorOptions; Index: Integer);
var
  I: Integer;
  InUse, Dark: Boolean;
begin
  if (Index < 0) or (Index > High(O.Themes)) then Exit;
  InUse := SameText(O.Themes[Index].Name, O.ColorTheme);
  Dark := EditorIsDark(O.Themes[Index].Colors);
  for I := Index to High(O.Themes) - 1 do O.Themes[I] := O.Themes[I + 1];
  SetLength(O.Themes, Length(O.Themes) - 1);
  if InUse then
    if Dark then SelectTheme(O, 'Dark') else SelectTheme(O, DefaultThemeName);
end;

function ChangeThemeElement(var O: TEditorOptions; E: TEditorElement; const Value: TEditorColor): Boolean;
var
  I: Integer;
begin
  I := UserThemeIndex(O, O.ColorTheme);
  Result := I < 0;
  if Result then
  begin
    I := AddUserTheme(O, O.ColorTheme + ' (custom)', O.Colors);
    O.ColorTheme := O.Themes[I].Name;
  end;
  O.Themes[I].Colors[E] := Value;
  O.Colors[E] := Value;
end;

procedure ThemesFollowPlainText(var O: TEditorOptions);
var
  I: Integer;
begin
  FollowPlainText(O.Colors);
  for I := 0 to High(O.Themes) do FollowPlainText(O.Themes[I].Colors);
end;

{ the user's themes: the sections [Editor Theme\<name>], by name }
procedure ReadThemes(Ini: TCustomIniFile; var O: TEditorOptions);
var
  Secs: TStringList;
  I: Integer;
  Name, Key: string;
  C: TEditorColors;
begin
  SetLength(O.Themes, 0);
  Secs := TStringList.Create;
  try
    Ini.ReadSections(Secs);
    Secs.Sort;
    for I := 0 to Secs.Count - 1 do
      if SameText(Copy(Secs[I], 1, Length(SecTheme)), SecTheme) then
      begin
        Name := Trim(Copy(Secs[I], Length(SecTheme) + 1, MaxInt));
        { the name's letter case as it was written last (WriteThemes) }
        Key := Trim(Ini.ReadString(Secs[I], ThemeNameKey, ''));
        if SameText(Key, Name) then Name := Key;
        if (Name = '') or IsBuiltinTheme(Name) or (UserThemeIndex(O, Name) >= 0) then Continue;
        ReadUserTheme(Ini, Secs[I], C);
        AddUserTheme(O, Name, C);
      end;
  finally
    Secs.Free;
  end;
end;

procedure WriteThemes(Ini: TCustomIniFile; const O: TEditorOptions);
var
  Secs: TStringList;
  I: Integer;
begin
  Secs := TStringList.Create;
  try
    Ini.ReadSections(Secs);
    for I := 0 to Secs.Count - 1 do
      if SameText(Copy(Secs[I], 1, Length(SecTheme)), SecTheme) then Ini.EraseSection(Secs[I]);
  finally
    Secs.Free;
  end;
  { the name as a key as well: the settings' sections count in any case, so a name changed only
    in its letter case keeps its section's old name in the file (SaveSettings) }
  for I := 0 to High(O.Themes) do
  begin
    Ini.WriteString(SecTheme + O.Themes[I].Name, ThemeNameKey, O.Themes[I].Name);
    WriteThemeColors(Ini, SecTheme + O.Themes[I].Name, O.Themes[I].Colors);
  end;
end;

{ The colours of D7 Studio before themes - Delphi 7's 28 elements ([Editor Highlight]), the scroll
  bars' colour and the completion list's colours ([Editor], Delphi's names) -, which it always
  wrote: a built-in theme when they are its colours, else a theme of the user's made of them (a
  built-in's name gets " (custom)"), in use from then on. Only what differs from the built-in of
  Color SpeedSetting counts: the completion list's colours were Delphi 7's defaults on every
  scheme. The old keys go (SaveSettings takes them off the file as well). }
procedure ConvertOldColors(Ini: TCustomIniFile; var O: TEditorOptions);
var
  D: TDelphiColors;
  DE: TDelphiElement;
  C, B, L: TEditorColors;
  E: TEditorElement;
  Base, Builtin: string;
  V: TColor;
  I: Integer;
  Old: Boolean;
begin
  Old := Ini.SectionExists(SecOldHighlight) or Ini.ValueExists(SecEditor, OldScrollBarKey) or
    Ini.ValueExists(SecEditor, DelphiInsightBackKey);
  for E := Low(DelphiSymbolKeys) to High(DelphiSymbolKeys) do
    if Ini.ValueExists(SecEditor, DelphiSymbolKeys[E]) then Old := True;
  if not Old then Exit;
  Base := Trim(O.ColorTheme);
  if not BuiltinThemeColors(Base, B) then BuiltinThemeColors(DefaultThemeName, B);
  BuiltinThemeColors(DefaultThemeName, L);        // Delphi 7's completion colours
  C := B;
  if Ini.SectionExists(SecOldHighlight) then
  begin
    for DE := Low(DE) to High(DE) do
      D[DE] := DelphiColorFromText(Ini.ReadString(SecOldHighlight, DelphiElementKeys[DE], ''));
    ColorsFromDelphi(D, C);
  end;
  if Ini.ValueExists(SecEditor, OldScrollBarKey) then
    C[eeScrollBar].Fore := ThemeTextColor(Ini.ReadString(SecEditor, OldScrollBarKey, ''));
  for E := Low(DelphiSymbolKeys) to High(DelphiSymbolKeys) do
    if Ini.ValueExists(SecEditor, DelphiSymbolKeys[E]) then
    begin
      V := ThemeTextColor(Ini.ReadString(SecEditor, DelphiSymbolKeys[E], ''));
      if (V <> clDefault) and (V <> L[E].Fore) then C[E].Fore := V;
    end;
  if Ini.ValueExists(SecEditor, DelphiInsightBackKey) then
  begin
    V := ThemeTextColor(Ini.ReadString(SecEditor, DelphiInsightBackKey, ''));
    if (V <> clDefault) and (V <> L[eeCompletion].Back) then C[eeCompletion].Back := V;
  end;
  Ini.EraseSection(SecOldHighlight);
  Ini.DeleteKey(SecEditor, OldScrollBarKey);
  Ini.DeleteKey(SecEditor, DelphiInsightBackKey);
  for E := Low(DelphiSymbolKeys) to High(DelphiSymbolKeys) do Ini.DeleteKey(SecEditor, DelphiSymbolKeys[E]);
  Builtin := BuiltinThemeOf(C);
  if Builtin <> '' then
  begin
    O.ColorTheme := Builtin;
    Exit;
  end;
  if Base = '' then Base := 'Custom'
  else if IsBuiltinTheme(Base) or (UserThemeIndex(O, Base) >= 0) then Base := Base + ' (custom)';
  I := AddUserTheme(O, Base, C);
  O.ColorTheme := O.Themes[I].Name;
end;

procedure LoadEditorOptions(Ini: TCustomIniFile);
var
  O: TEditorOptions;
  S: TDelphiValues;
  Pas: Integer;
{ the keys of D7 Studio's first editor page (Environment Options | Editor) become Delphi's names:
  the user's choices there count before Delphi 7's }
procedure MigrateOldKeys(Ini: TCustomIniFile);

  procedure M(const Old, New: string);
  begin
    if Ini.ValueExists(SecEditor, Old) and not Ini.ValueExists(SecEditor, New) then
      Ini.WriteString(SecEditor, New, Ini.ReadString(SecEditor, Old, ''));
  end;

begin
  M('FontName', 'Editor Font');
  M('FontSize', 'Font Size');
  M('ShowRightMargin', 'Visible Right Margin');
  M('RightMargin', 'Right Margin');
  M('AutoComplete', 'Auto Code Completions');
end;

begin
  FactoryOptions(O);
  MigrateOldKeys(Ini);
  { the table's three sources (Delphi's editor options, Code Insight, the debugger's ToolTip
    Watches) are all [Editor] of the settings }
  S := TDelphiValues.Create(Ini, SecEditor);
  try
    ReadOptions(EditorTable(O), Ini, SecEditor, [S, S, S]);
  finally
    S.Free;
  end;
  if (O.CodeDelay < 1) or (O.CodeDelay > 15) then O.CodeDelay := 10;
  if (O.FontSize < 6) or (O.FontSize > 72) then O.FontSize := 10;
  if (O.Zoom < -10) or (O.Zoom > 20) then O.Zoom := 0;     // Scintilla's range
  if (Screen <> nil) and (Screen.Fonts.IndexOf(O.FontName) < 0) then O.FontName := 'Courier New';
  ReadThemes(Ini, O);
  ConvertOldColors(Ini, O);
  if not SelectTheme(O, O.ColorTheme) then SelectTheme(O, DefaultThemeName);
  ReadFileTypes(Ini, O);
  { D7 Studio's first editor page kept the Pascal type's indent and tabs }
  Pas := 0;
  if not Ini.SectionExists(SecSource + '\' + O.FileTypes[Pas].ID) and Ini.ValueExists(SecEditor, 'IndentSize') then
  begin
    O.FileTypes[Pas].BlockIndent := Ini.ReadInteger(SecEditor, 'IndentSize', O.FileTypes[Pas].BlockIndent);
    O.FileTypes[Pas].AutoIndent := Ini.ReadBool(SecEditor, 'AutoIndent', O.FileTypes[Pas].AutoIndent);
    O.FileTypes[Pas].UseTabChar := Ini.ReadBool(SecEditor, 'UseTabs', O.FileTypes[Pas].UseTabChar);
  end;
  EditorOptions := O;
end;

procedure SaveEditorOptions(Ini: TCustomIniFile);
var
  I: Integer;
  IDs: TStringList;
begin
  WriteOptions(EditorTable(EditorOptions), Ini, SecEditor);
  with EditorOptions do
  begin
    { the keys of the first editor page are replaced by Delphi's }
    Ini.DeleteKey(SecEditor, 'FontName');
    Ini.DeleteKey(SecEditor, 'FontSize');
    Ini.DeleteKey(SecEditor, 'ShowRightMargin');
    Ini.DeleteKey(SecEditor, 'RightMargin');
    Ini.DeleteKey(SecEditor, 'AutoIndent');
    Ini.DeleteKey(SecEditor, 'AutoComplete');
    Ini.DeleteKey(SecEditor, 'IndentSize');
    Ini.DeleteKey(SecEditor, 'UseTabs');
    WriteThemes(Ini, EditorOptions);
    IDs := TStringList.Create;
    try
      for I := 0 to High(FileTypes) do
      begin
        IDs.Add(FileTypes[I].ID);
        WriteFileType(Ini, FileTypes[I]);
      end;
      Ini.WriteString(SecSource, 'Types', IDs.CommaText);
    finally
      IDs.Free;
    end;
  end;
end;

procedure ExportTheme(const FileName: string; const T: TEditorTheme);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create('');
  try
    Ini.Rename(FileName, False);
    Ini.WriteString(ThemeFileSection, ThemeNameKey, T.Name);
    WriteThemeColors(Ini, ThemeFileSection, T.Colors);
    WriteIniFile(Ini);
  finally
    Ini.Free;
  end;
end;

function ImportTheme(const FileName: string; var T: TEditorTheme): Boolean;
var
  Ini: TMemIniFile;
  L: TStringList;
begin
  Ini := TMemIniFile.Create('');
  L := TStringList.Create;
  try
    { through SdFileNames: also a name outside the code page, as the file dialogs give it }
    L.Text := ReadFileU(FileName);
    Ini.SetStrings(L);
    Result := Ini.SectionExists(ThemeFileSection);
    if not Result then Exit;
    T.Name := Trim(Ini.ReadString(ThemeFileSection, ThemeNameKey, ''));
    if T.Name = '' then T.Name := ChangeFileExt(ExtractFileName(FileName), '');
    ReadUserTheme(Ini, ThemeFileSection, T.Colors);
  finally
    L.Free;
    Ini.Free;
  end;
end;

{ --- file types --- }

function EditorFileTypeIndex(const FileName: string): Integer;
var
  Ext: string;
  L: TStringList;
  I: Integer;
begin
  Result := -1;
  Ext := LowerCase(Copy(ExtractFileExt(FileName), 2, MaxInt));
  L := TStringList.Create;
  try
    L.Delimiter := ';';
    for I := 0 to High(EditorOptions.FileTypes) do
    begin
      L.DelimitedText := LowerCase(EditorOptions.FileTypes[I].Extensions);
      if (Ext <> '') and (L.IndexOf(Ext) >= 0) then
      begin
        Result := I;
        Exit;
      end;
      if SameText(EditorOptions.FileTypes[I].ID, DefaultTypeID) then Result := I;
    end;
  finally
    L.Free;
  end;
  if (Result < 0) and (Length(EditorOptions.FileTypes) > 0) then Result := High(EditorOptions.FileTypes);
end;

function EditorFileTypeOfID(const ID: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if ID <> '' then
    for I := 0 to High(EditorOptions.FileTypes) do
      if SameText(EditorOptions.FileTypes[I].ID, ID) then
      begin
        Result := I;
        Exit;
      end;
end;

function EditorFileType(const FileName: string): TEditorFileType;
var
  I: Integer;
begin
  I := EditorFileTypeIndex(FileName);
  if I >= 0 then Result := EditorOptions.FileTypes[I]
  else Result := DefaultFileType;
end;

function TabWidthOf(const TabStops: string): Integer;
var
  L: TStringList;
  A, B: Integer;
begin
  L := TStringList.Create;
  try
    L.Delimiter := ' ';
    L.DelimitedText := Trim(TabStops);
    A := 0;
    B := 0;
    if L.Count > 0 then A := StrToIntDef(L[0], 0);
    if L.Count > 1 then B := StrToIntDef(L[1], 0);
    { columns: the distance of the first two stops; one value: Delphi's first stop, a width }
    if (L.Count > 1) and (B > A) then Result := B - A
    else if A > 1 then Result := A
    else Result := 8;
  finally
    L.Free;
  end;
end;

{ --- colours --- }

var
  LightDark: array[Boolean] of TEditorColors;     // D7 Studio's Light (False) and Dark (True)

const
  { Rainbow brackets: today's editors' light and dark palettes }
  RainbowDefaults: array[Boolean, eeRainbow1..eeRainbow3] of TColor = (
    ($00FA3104, $00319331, $0014387B), ($0000D7FF, $00D670DA, $00FF9F17));

function OwnColor(const C: TEditorColor; Back: Boolean; var Value: TColor): Boolean;
begin
  if Back then Value := C.Back else Value := C.Fore;
  Result := not IsDefaultColor(Value);
end;

function ElementFore(const C: TEditorColors; E: TEditorElement): TColor;
var
  Fg, Bg: TColor;
  Dark: Boolean;
begin
  if ElementGroups[E] = egPascal then
  begin
    Result := PascalFore(C, E);
    Exit;
  end;
  if OwnColor(C[E], False, Result) then Exit;
  Fg := ElementFore(C, eePlainText);
  Bg := ElementBack(C, eePlainText);
  Dark := UIIsDark(Bg);
  case E of
    eeGutter, eeBlanks: Result := UIBlend(Fg, Bg, 50);
    eeRightMargin: Result := UIBlend(Fg, Bg, 15);
    eeIndentGuide: Result := UIBlend(Fg, Bg, 22);
    eeFolding, eeIdentDecl: Result := UIBlend(Fg, Bg, 35);
    eeModifiedLine: Result := clYellow;
    eeSavedLine: Result := clLime;
    eeScrollBar: Result := clDefault;
    eeBraceMatch: if Dark then Result := $0000D7FF else Result := clBlue;
    eeBraceBad: Result := clRed;
    eeWordMatch: Result := ElementFore(C, eeBraceMatch);
    eeRainbow1..eeRainbow3: Result := RainbowDefaults[Dark, E];
    eeHotLink, eeSelection, eeSearchMatch: Result := LightDark[Dark][E].Fore;
    eeExecutionPoint: Result := DelphiDefaultColor(deExecutionPoint, False);
    eeEnabledBreak: Result := DelphiDefaultColor(deEnabledBreak, False);
    eeDisabledBreak: Result := DelphiDefaultColor(deDisabledBreak, False);
    eeInvalidBreak: Result := DelphiDefaultColor(deInvalidBreak, False);
    eeErrorLine: Result := DelphiDefaultColor(deErrorLine, False);
    eeCompProcedure..eeCompAbstract: Result := LightDark[UIIsDark(ElementBack(C, eeCompletion))][E].Fore;
  else
    Result := Fg;          // the caret, the completion list's text
  end;
end;

function ElementBack(const C: TEditorColors; E: TEditorElement): TColor;
var
  Fg, Bg: TColor;
  Dark: Boolean;
begin
  if ElementGroups[E] = egPascal then
  begin
    Result := PascalBack(C, E);
    Exit;
  end;
  if OwnColor(C[E], True, Result) then Exit;
  Fg := ElementFore(C, eePlainText);
  Bg := ElementBack(C, eePlainText);
  Dark := UIIsDark(Bg);
  case E of
    eeGutter: Result := UIBlend(Fg, Bg, 6);
    { a band of the text's colour, 14 / 255 opaque (TSciEdit.ApplyView) }
    eeCurrentLine: if Dark then Result := UIBlend(clWhite, Bg, 5) else Result := UIBlend(clBlack, Bg, 5);
    eeIdentMatch: Result := UIBlend(Fg, Bg, 20);
    eeOccurrence: Result := ElementBack(C, eeIdentMatch);
    eeSelection, eeSearchMatch: Result := LightDark[Dark][E].Back;
    eeExecutionPoint: Result := DelphiDefaultColor(deExecutionPoint, True);
    eeEnabledBreak: Result := DelphiDefaultColor(deEnabledBreak, True);
    eeDisabledBreak: Result := DelphiDefaultColor(deDisabledBreak, True);
    eeInvalidBreak: Result := DelphiDefaultColor(deInvalidBreak, True);
    eeErrorLine: Result := DelphiDefaultColor(deErrorLine, True);
  else
    Result := Bg;          // the completion list
  end;
end;

function ErrorMarkColor(const C: TEditorColors): TColor;
var
  V: COLORREF;
  R, G, B, M: Integer;
begin
  Result := ElementBack(C, eeErrorLine);
  if not UIIsDark(ElementBack(C, eePlainText)) then Exit;
  V := ColorToRGB(Result);
  R := GetRValue(V);
  G := GetGValue(V);
  B := GetBValue(V);
  M := R;
  if G > M then M := G;
  if B > M then M := B;
  if M > 0 then Result := TColor(RGB(R * 240 div M, G * 240 div M, B * 240 div M));
end;

function EditorIsDark(const C: TEditorColors): Boolean;
begin
  Result := UIIsDark(ElementBack(C, eePlainText));
end;

procedure ReadUserTheme(Ini: TCustomIniFile; const Section: string; var C: TEditorColors);
var
  Present: TEditorElements;
  E: TEditorElement;
begin
  DefaultColors(C);
  Present := ReadThemeColors(Ini, Section, C);
  for E := eeFlowControl to eeCustomIdent do
    if not (E in Present) then C[E] := LightDark[EditorIsDark(C)][E];
end;

initialization
  BuiltinThemeColors('Light', LightDark[False]);
  BuiltinThemeColors('Dark', LightDark[True]);
  FactoryOptions(EditorOptions);

end.
