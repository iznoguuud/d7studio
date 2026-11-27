{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEditorThemes;

{ D7 Studio - the code editor's colour themes (Editor Options | Color):
  the elements a theme colours, in groups (Pascal, Editor, Highlighting,
  Debugger, Code Insight); D7 Studio's built-in themes Light, Dark and Classic; the text a theme
  is kept as - a section of the settings or of a theme file -; and Delphi 7's colours (the 28
  elements of its Color page) as a theme's: the settings of earlier versions of D7 Studio and
  migrate's import of Delphi 7.

  A colour clDefault is the element's Default: SdEditorOptions.ElementFore / ElementBack work it
  out from the theme (the plain text's colours, D7 Studio's Light or Dark for such a ground). A
  theme keeps a Pascal element's colour that is Plain text's as Default (FollowPlainText), so a
  new Plain text colour changes every element without one of its own.
  This unit needs nothing of the IDE: migrate.exe uses it as well. }

interface

uses
  SysUtils, Classes, Graphics, IniFiles;

type
  { the elements, in the order of the Color page's tree }
  TEditorElement = (
    { Pascal: the code's tokens; a name by its kind, as code insight finds it (eeType ..
      eeUnitName: the colour of the text only), else Identifier; the flow-control words (Exit,
      Break, Continue, Halt, Abort, raise, goto) and the identifiers of the user's list, each on
      an identifier's ground too }
    eePlainText, eeReservedWord, eeIdentifier, eeType, eeRoutine, eeProperty, eeField, eeVariable,
    eeLocalVar, eeParameter, eeConstant, eeUnitName, eeFlowControl, eeCustomIdent, eeSymbol, eeComment, eeDirective, eeString,
    eeCharacter, eeNumber, eeHex, eeAssembler,
    { Editor }
    eeSelection, eeSearchMatch, eeHotLink, eeCurrentLine, eeCaret, eeGutter, eeRightMargin,
    eeIndentGuide, eeBlanks, eeFolding, eeModifiedLine, eeSavedLine, eeScrollBar,
    { Highlighting }
    eeBraceMatch, eeBraceBad, eeWordMatch, eeIdentMatch, eeIdentDecl, eeOccurrence,
    eeRainbow1, eeRainbow2, eeRainbow3,
    { Debugger }
    eeExecutionPoint, eeEnabledBreak, eeDisabledBreak, eeInvalidBreak, eeErrorLine,
    { Code Insight: the completion list }
    eeCompletion, eeCompProcedure, eeCompFunction, eeCompProperty, eeCompVariable,
    eeCompConstant, eeCompType, eeCompUnit, eeCompLabel, eeCompAbstract);

  TEditorGroup = (egPascal, egEditor, egHighlighting, egDebugger, egCodeInsight);

  { what an element has: a colour of its text or mark, a ground, the font's styles }
  TElementPart = (epFore, epBack, epStyle);
  TElementParts = set of TElementPart;

  TEditorColor = record
    Fore, Back: TColor;              // clDefault: the element's Default
    Bold, Italic, Underline: Boolean;
  end;
  TEditorColors = array[TEditorElement] of TEditorColor;
  TEditorElements = set of TEditorElement;

  TEditorTheme = record
    Name: string;
    Colors: TEditorColors;
  end;
  TEditorThemes = array of TEditorTheme;

  { the elements of Delphi 7's Color page, in its order: the keys of its Editor\Highlight (and of
    D7 Studio's [Editor Highlight] before themes) }
  TDelphiElement = (deWhitespace, deComment, deReservedWord, deIdentifier, deSymbol, deString,
    deNumber, deAssembler, deHotLink, dePlainText, deMarkedBlock, deSearchMatch,
    deExecutionPoint, deEnabledBreak, deDisabledBreak, deInvalidBreak, deErrorLine,
    deRightMargin, deFloat, deOctal, deHex, deCharacter, dePreprocessor, deIllegalChar, deTags,
    deAttribNames, deAttribValues, deScripts);

  { an element's values as Delphi 7 keeps them; Present: there were values }
  TDelphiColor = record
    Fore, Back: TColor;
    Bold, Italic, Underline, DefaultFore, DefaultBack: Boolean;
    Present: Boolean;
  end;
  TDelphiColors = array[TDelphiElement] of TDelphiColor;

const
  ElementGroups: array[TEditorElement] of TEditorGroup = (
    egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal,
    egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal, egPascal,
    egPascal, egPascal, egPascal, egPascal,
    egEditor, egEditor, egEditor, egEditor, egEditor, egEditor, egEditor, egEditor, egEditor,
    egEditor, egEditor, egEditor, egEditor,
    egHighlighting, egHighlighting, egHighlighting, egHighlighting, egHighlighting,
    egHighlighting, egHighlighting, egHighlighting, egHighlighting,
    egDebugger, egDebugger, egDebugger, egDebugger, egDebugger,
    egCodeInsight, egCodeInsight, egCodeInsight, egCodeInsight, egCodeInsight, egCodeInsight,
    egCodeInsight, egCodeInsight, egCodeInsight, egCodeInsight);
  GroupCaptions: array[TEditorGroup] of string = ('Pascal', 'Editor', 'Highlighting', 'Debugger',
    'Code Insight');
  ElementCaptions: array[TEditorElement] of string = (
    'Plain text', 'Reserved word', 'Identifier', 'Type', 'Routine', 'Property', 'Field',
    'Variable', 'Local variable', 'Parameter', 'Constant', 'Unit', 'Flow control',
    'Custom identifier', 'Symbol', 'Comment',
    'Directive', 'String', 'Character', 'Number', 'Hex number', 'Assembler',
    'Selection', 'Search match', 'Hot link', 'Current line', 'Caret', 'Gutter and line numbers',
    'Right margin', 'Indentation guides', 'Visible blanks', 'Folding marks', 'Modified lines',
    'Saved lines', 'Scroll bars',
    'Matching bracket', 'Unmatched bracket', 'Matching words', 'Identifier occurrences',
    'Identifier declarations', 'Word occurrences', 'Rainbow brackets 1',
    'Rainbow brackets 2', 'Rainbow brackets 3',
    'Execution point', 'Breakpoint', 'Disabled breakpoint', 'Invalid breakpoint', 'Error line',
    'Completion list', 'Procedure', 'Function', 'Property', 'Variable', 'Constant', 'Type',
    'Unit', 'Label', 'Abstract method');
  { the keys of a theme's section }
  ElementKeys: array[TEditorElement] of string = (
    'PlainText', 'ReservedWord', 'Identifier', 'Type', 'Routine', 'Property', 'Field', 'Variable',
    'LocalVariable', 'Parameter', 'Constant', 'Unit', 'FlowControl', 'CustomIdentifier', 'Symbol',
    'Comment', 'Directive', 'String',
    'Character', 'Number', 'Hex', 'Assembler',
    'Selection', 'SearchMatch', 'HotLink', 'CurrentLine', 'Caret', 'Gutter', 'RightMargin',
    'IndentGuides', 'Blanks', 'Folding', 'ModifiedLines', 'SavedLines', 'ScrollBars',
    'BracketMatch', 'BracketUnmatched', 'WordMatch', 'Identifiers', 'Declarations',
    'Occurrences', 'Rainbow1', 'Rainbow2', 'Rainbow3',
    'ExecutionPoint', 'Breakpoint', 'DisabledBreakpoint', 'InvalidBreakpoint', 'ErrorLine',
    'CompletionList', 'CompletionProcedure', 'CompletionFunction', 'CompletionProperty',
    'CompletionVariable', 'CompletionConstant', 'CompletionType', 'CompletionUnit',
    'CompletionLabel', 'CompletionAbstract');
  { what each element has: the text's tokens all three - the names by kind and the completion
    list's kinds their colour and font styles, on the ground of an identifier or of the list -; a
    line, bar, box or guide its colour (Fore); a ground its Back }
  ElementParts: array[TEditorElement] of TElementParts = (
    [epFore, epBack, epStyle], [epFore, epBack, epStyle], [epFore, epBack, epStyle],
    [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle],
    [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle],
    [epFore, epStyle], [epFore, epStyle],
    [epFore, epBack, epStyle], [epFore, epBack, epStyle], [epFore, epBack, epStyle],
    [epFore, epBack, epStyle], [epFore, epBack, epStyle], [epFore, epBack, epStyle],
    [epFore, epBack, epStyle], [epFore, epBack, epStyle],
    [epFore, epBack], [epFore, epBack], [epFore], [epBack], [epFore], [epFore, epBack],
    [epFore], [epFore], [epFore], [epFore], [epFore], [epFore], [epFore],
    [epFore], [epFore], [epFore], [epBack], [epFore], [epBack], [epFore], [epFore], [epFore],
    [epFore, epBack], [epFore, epBack], [epFore, epBack], [epFore, epBack], [epFore, epBack],
    [epFore, epBack], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle],
    [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle], [epFore, epStyle]);

  { the elements whose Default is Identifier's: the names by kind, the flow-control words, the
    user's identifiers }
  IdentElements = [eeType..eeUnitName, eeFlowControl, eeCustomIdent];

  DelphiElementKeys: array[TDelphiElement] of string = ('Whitespace', 'Comment',
    'Reserved word', 'Identifier', 'Symbol', 'String', 'Number', 'Assembler', 'Hot Link',
    'Plain text', 'Marked block', 'Search match', 'Execution point', 'Enabled break',
    'Disabled break', 'Invalid break', 'Error line', 'Right margin', 'Float', 'Octal', 'Hex',
    'Character', 'Preprocessor', 'Illegal Char', 'Tags', 'Attribute Names', 'Attribute Values',
    'Scripts');
  { Delphi 7's Code Insight colours (its Code Insight key; D7 Studio's [Editor] before themes):
    the completion list's kinds, and its ground }
  DelphiSymbolKeys: array[eeCompProcedure..eeCompAbstract] of string = ('ProcSymbolColor',
    'FuncSymbolColor', 'PropSymbolColor', 'VarSymbolColor', 'ConstSymbolColor',
    'TypeSymbolColor', 'UnitSymbolColor', 'LabelSymbolColor', 'AbstractSymbolColor');
  DelphiInsightBackKey = 'InsightBackgroundColor';

  { the section of a theme file }
  ThemeFileSection = 'D7 Studio Editor Theme';
  ThemeFileExt = 'd7theme';
  { the key of a theme's name in its section (a theme file's, the settings') }
  ThemeNameKey = 'Name';
  DefaultThemeName = 'Light';

{ the built-in themes: Light, Dark, Classic }
function BuiltinThemeCount: Integer;
function BuiltinThemeName(Index: Integer): string;
{ the colours of the built-in theme Name (any case); False: no built-in of that name }
function BuiltinThemeColors(const Name: string; var C: TEditorColors): Boolean;
function IsBuiltinTheme(const Name: string): Boolean;
{ every element Default, no style }
procedure DefaultColors(var C: TEditorColors);
function SameColors(const A, B: TEditorColors): Boolean;
{ the built-in theme whose colours C are ('' none) }
function BuiltinThemeOf(const C: TEditorColors): string;
{ a colour that stands for the element's Default: clDefault (clNone too) }
function IsDefaultColor(C: TColor): Boolean;
{ an element's Bold, Italic and Underline as a font's styles }
function ElementFontStyles(const C: TEditorColor): TFontStyles;
{ a Pascal element's colours (ElementGroups egPascal) with its Default worked out: Plain text's
  - a name by kind's Identifier's -, Plain text's own Default the window's colours }
function PascalFore(const C: TEditorColors; E: TEditorElement): TColor;
function PascalBack(const C: TEditorColors; E: TEditorElement): TColor;
{ a Pascal element's colour that is the one its Default stands for (the same RGB: Plain text's, a
  name by kind's Identifier's) becomes Default: the element looks the same and follows Plain text
  when that changes }
procedure FollowPlainText(var C: TEditorColors);

{ a colour as #RRGGBB (a system colour as it is now); and back from #RRGGBB or RRGGBB - False
  when the text is no such colour }
function ColorHex(C: TColor): string;
function HexColor(const S: string; out C: TColor): Boolean;
{ a colour as a theme keeps it: default, #RRGGBB, or a system colour's name (clWindow); and back
  (also Delphi's $00BBGGRR and names; what is none of them is Default) }
function ThemeColorText(C: TColor): string;
function ThemeTextColor(const S: string): TColor;
{ an element as a theme keeps it: fore,back[,bold][,italic][,underline] }
function ElementText(const C: TEditorColor): string;
function TextElement(const S: string): TEditorColor;
{ a theme's colours in Section of Ini (every key written); read: the keys there, the others stay
  as C has them, then FollowPlainText - the elements that had a key }
procedure WriteThemeColors(Ini: TCustomIniFile; const Section: string; const C: TEditorColors);
function ReadThemeColors(Ini: TCustomIniFile; const Section: string; var C: TEditorColors): TEditorElements;

{ Delphi 7's factory colour of an element - what its "Use defaults for" shows }
function DelphiDefaultColor(E: TDelphiElement; Back: Boolean): TColor;
{ Delphi 7's colours into a theme's C: its Pascal elements, the marked block, search match, hot
  link, right margin and the debugger's lines ("Use defaults for": the factory colour); the
  elements Delphi 7 has none of keep what C has - the names by kind, the flow-control words and the
  user's identifiers only while Delphi's identifiers look as C's (the same RGB), else they are Default. Delphi's Pascal characters (#13)
  are its strings. Then FollowPlainText }
procedure ColorsFromDelphi(const D: TDelphiColors; var C: TEditorColors);
{ D7 Studio's text of one element before themes ([Editor Highlight]:
  fore,back,bold,italic,underline,default fore,default back - 0 / 1) }
function DelphiColorFromText(const S: string): TDelphiColor;

{ a theme name that is neither a built-in's nor one of Names (any case): Base, else Base 2,
  Base 3 ... }
function FreeThemeName(const Base: string; Names: TStrings): string;

implementation

type
  { a built-in theme: the Pascal elements' colours on the ground (SchemeColors makes those that
    are Plain text's Default); the frame and the highlights Default - worked out from the ground
    and the text as they always were }
  TThemeScheme = record
    Name: string;
    Ground, Text: TColor;                           // plain text, identifiers, symbols
    Comment, Keyword, Str, Number, Directive, AsmText, Link, Margin: TColor;
    SelFore, SelBack, FindFore, FindBack: TColor;   // selection, search match
    ExecFore, ExecBack, BreakFore, BreakBack, DisFore, DisBack, BadFore, BadBack,
      ErrFore, ErrBack: TColor;                     // execution point, breakpoints, error line
    ListText, ListGround: TColor;                   // the completion list
    Kinds: array[eeCompProcedure..eeCompAbstract] of TColor;
    Names: array[eeType..eeUnitName] of TColor;     // the names by kind (clDefault: Identifier's)
    Flow, Custom: TColor;                           // the flow-control words, the user's identifiers
    KeywordBold, CommentItalic, FlowBold: Boolean;
  end;

const
  { TColor is $00BBGGRR. Light and Dark: the light and dark palettes of today's editors (the
    names by kind as their semantic colours: types, routines, variables, constants);
    Classic: Delphi 7's own Classic -
    the bluish Borland look, every name Identifier's colour. The
    completion list of Light and Classic is Delphi 7's (its window's colours, its Code Insight
    defaults) }
  Schemes: array[0..2] of TThemeScheme = (
    (Name: 'Light'; Ground: $00FFFFFF; Text: $00000000;
     Comment: $00008000; Keyword: $00FF0000; Str: $001515A3; Number: $00588609;
     Directive: $00DB00AF; AsmText: $00265E79; Link: $00C17000; Margin: $00D0D0D0;
     SelFore: $00000000; SelBack: $00FFD6AD; FindFore: $00000000; FindBack: $0080E6FF;
     ExecFore: $00FFFFFF; ExecBack: $009C630E; BreakFore: $00FFFFFF; BreakBack: $002E2EC7;
     DisFore: $00FFFFFF; DisBack: $00327D2E; BadFore: $00FFFFFF; BadBack: $00249D9E;
     ErrFore: $00FFFFFF; ErrBack: $0000008B;
     ListText: clWindowText; ListGround: clWindow;
     Kinds: (clTeal, clBlue, clNavy, clMaroon, clGreen, clOlive, clBlack, clTeal, clRed);
     Names: ($00997F26, $00265E79, $00801000, $00801000, $00801000, $00801000, $00801000,
       $00C17000, $00997F26);
     Flow: $000000C0; Custom: $00A0008B;
     KeywordBold: True; CommentItalic: True; FlowBold: True),
    (Name: 'Dark'; Ground: $001E1E1E; Text: $00D4D4D4;
     Comment: $0055996A; Keyword: $00D69C56; Str: $007891CE; Number: $00A8CEB5;
     Directive: $00C086C5; AsmText: $007DBAD7; Link: $00FFC14F; Margin: $003C3C3C;
     SelFore: $00D4D4D4; SelBack: $00784F26; FindFore: $00D4D4D4; FindBack: $00143261;
     ExecFore: $00FFFFFF; ExecBack: $00994E1F; BreakFore: $00FFFFFF; BreakBack: $001E1E8B;
     DisFore: $00FFFFFF; DisBack: $002E5E2E; BadFore: $00FFFFFF; BadBack: $001E6B6B;
     ErrFore: $00FFFFFF; ErrBack: $001F1F7A;
     ListText: $00D4D4D4; ListGround: $00262525;
     Kinds: ($00B0C94E, $00D69C56, $00FEDC9C, $007891CE, $00A8CEB5, $007DBAD7, $00D4D4D4,
       $00B0C94E, $004747F4);
     Names: ($00B0C94E, $00AADCDC, $00FEDC9C, $00FEDC9C, $00FEDC9C, $00FEDC9C, $00FEDC9C,
       $00FFC14F, $00B0C94E);
     Flow: $007A7AF4; Custom: $00DDA0DD;
     KeywordBold: True; CommentItalic: True; FlowBold: True),
    (Name: 'Classic'; Ground: $00800000; Text: $0000FFFF;
     Comment: $00C0C0C0; Keyword: $00FFFFFF; Str: $0000FFFF; Number: $0000FFFF;
     Directive: $0000FFFF; AsmText: $0000FF00; Link: $00FFFFFF; Margin: $00C0C0C0;
     SelFore: $00800000; SelBack: $00C0C0C0; FindFore: $00FFFF00; FindBack: $00000000;
     ExecFore: $00000000; ExecBack: $00FFFF00; BreakFore: $00FFFFFF; BreakBack: $000000FF;
     DisFore: $000000FF; DisBack: $0000FF00; BadFore: $0000FF00; BadBack: $00008080;
     ErrFore: $00FFFFFF; ErrBack: $00000080;
     ListText: clWindowText; ListGround: clWindow;
     Kinds: (clTeal, clBlue, clNavy, clMaroon, clGreen, clOlive, clBlack, clTeal, clRed);
     Names: (clDefault, clDefault, clDefault, clDefault, clDefault, clDefault, clDefault,
       clDefault, clDefault);
     Flow: clDefault; Custom: clDefault;
     KeywordBold: False; CommentItalic: False; FlowBold: False));

  { Delphi 7's factory colours (its "Defaults"): text and ground of each element }
  DelphiFactory: array[TDelphiElement, Boolean] of TColor = (
    (clWindowText, clWindow), (clNavy, clWindow), (clWindowText, clWindow),
    (clWindowText, clWindow), (clWindowText, clWindow), (clNavy, clWindow), (clNavy, clWindow),
    (clWindowText, clWindow), (clBlue, clWindow), (clWindowText, clWindow),
    (clHighlightText, clHighlight), (clWindowText, clYellow), (clWhite, clNavy),
    (clWhite, clRed), (clWhite, clGreen), (clWhite, clOlive), (clWhite, clMaroon),
    (clSilver, clWindow), (clNavy, clWindow), (clNavy, clWindow), (clNavy, clWindow),
    (clNavy, clWindow), (clGreen, clWindow), (clRed, clWindow), (clNavy, clWindow),
    (clMaroon, clWindow), (clBlue, clWindow), (clWindowText, clWindow));

procedure DefaultColors(var C: TEditorColors);
var
  E: TEditorElement;
begin
  for E := Low(E) to High(E) do
  begin
    C[E].Fore := clDefault;
    C[E].Back := clDefault;
    C[E].Bold := False;
    C[E].Italic := False;
    C[E].Underline := False;
  end;
end;

{ a built-in scheme on every element, what is Plain text's colour Default }
procedure SchemeColors(const S: TThemeScheme; var C: TEditorColors);
var
  E: TEditorElement;

  procedure SetC(E: TEditorElement; Fore, Back: TColor; Bold: Boolean = False; Italic: Boolean = False);
  begin
    C[E].Fore := Fore;
    C[E].Back := Back;
    C[E].Bold := Bold;
    C[E].Italic := Italic;
  end;

begin
  DefaultColors(C);
  SetC(eePlainText, S.Text, S.Ground);
  SetC(eeIdentifier, S.Text, S.Ground);
  SetC(eeSymbol, S.Text, S.Ground);
  SetC(eeComment, S.Comment, S.Ground, False, S.CommentItalic);
  SetC(eeReservedWord, S.Keyword, S.Ground, S.KeywordBold);
  SetC(eeString, S.Str, S.Ground);
  SetC(eeCharacter, S.Str, S.Ground);
  SetC(eeNumber, S.Number, S.Ground);
  SetC(eeHex, S.Number, S.Ground);
  SetC(eeDirective, S.Directive, S.Ground);
  SetC(eeAssembler, S.AsmText, S.Ground);
  C[eeHotLink].Fore := S.Link;
  SetC(eeSelection, S.SelFore, S.SelBack);
  SetC(eeSearchMatch, S.FindFore, S.FindBack);
  C[eeRightMargin].Fore := S.Margin;
  SetC(eeExecutionPoint, S.ExecFore, S.ExecBack);
  SetC(eeEnabledBreak, S.BreakFore, S.BreakBack);
  SetC(eeDisabledBreak, S.DisFore, S.DisBack);
  SetC(eeInvalidBreak, S.BadFore, S.BadBack);
  SetC(eeErrorLine, S.ErrFore, S.ErrBack);
  SetC(eeCompletion, S.ListText, S.ListGround);
  for E := Low(S.Kinds) to High(S.Kinds) do C[E].Fore := S.Kinds[E];
  for E := Low(S.Names) to High(S.Names) do C[E].Fore := S.Names[E];
  C[eeFlowControl].Fore := S.Flow;
  C[eeFlowControl].Bold := S.FlowBold;
  C[eeCustomIdent].Fore := S.Custom;
  FollowPlainText(C);
end;

function BuiltinThemeCount: Integer;
begin
  Result := Length(Schemes);
end;

function BuiltinThemeName(Index: Integer): string;
begin
  Result := Schemes[Index].Name;
end;

function SchemeIndex(const Name: string): Integer;
begin
  Result := High(Schemes);
  while (Result >= 0) and not SameText(Schemes[Result].Name, Trim(Name)) do Dec(Result);
end;

function IsBuiltinTheme(const Name: string): Boolean;
begin
  Result := SchemeIndex(Name) >= 0;
end;

function BuiltinThemeColors(const Name: string; var C: TEditorColors): Boolean;
var
  I: Integer;
begin
  I := SchemeIndex(Name);
  Result := I >= 0;
  if Result then SchemeColors(Schemes[I], C);
end;

function SameColors(const A, B: TEditorColors): Boolean;
var
  E: TEditorElement;
begin
  Result := False;
  for E := Low(E) to High(E) do
    if (A[E].Fore <> B[E].Fore) or (A[E].Back <> B[E].Back) or (A[E].Bold <> B[E].Bold) or
      (A[E].Italic <> B[E].Italic) or (A[E].Underline <> B[E].Underline) then Exit;
  Result := True;
end;

function BuiltinThemeOf(const C: TEditorColors): string;
var
  I: Integer;
  B: TEditorColors;
begin
  for I := Low(Schemes) to High(Schemes) do
  begin
    SchemeColors(Schemes[I], B);
    if SameColors(B, C) then
    begin
      Result := Schemes[I].Name;
      Exit;
    end;
  end;
  Result := '';
end;

function IsDefaultColor(C: TColor): Boolean;
begin
  Result := (C = clDefault) or (C = clNone);
end;

function ElementFontStyles(const C: TEditorColor): TFontStyles;
begin
  Result := [];
  if C.Bold then Include(Result, fsBold);
  if C.Italic then Include(Result, fsItalic);
  if C.Underline then Include(Result, fsUnderline);
end;

function PascalFore(const C: TEditorColors; E: TEditorElement): TColor;
begin
  Result := C[E].Fore;
  if not IsDefaultColor(Result) then Exit;
  if E = eePlainText then Result := clWindowText
  else if E in IdentElements then Result := PascalFore(C, eeIdentifier)
  else Result := PascalFore(C, eePlainText);
end;

function PascalBack(const C: TEditorColors; E: TEditorElement): TColor;
begin
  Result := C[E].Back;
  if not IsDefaultColor(Result) then Exit;
  if E = eePlainText then Result := clWindow
  else if E in IdentElements then Result := PascalBack(C, eeIdentifier)
  else Result := PascalBack(C, eePlainText);
end;

procedure FollowPlainText(var C: TEditorColors);
var
  E, Source: TEditorElement;
begin
  for E := Low(E) to High(E) do
    if (ElementGroups[E] = egPascal) and (E <> eePlainText) then
    begin
      if E in IdentElements then Source := eeIdentifier else Source := eePlainText;
      { a colour made Default shows the same: Source's colours stay what they were }
      if not IsDefaultColor(C[E].Fore) and (ColorToRGB(C[E].Fore) = ColorToRGB(PascalFore(C, Source))) then
        C[E].Fore := clDefault;
      if not IsDefaultColor(C[E].Back) and (ColorToRGB(C[E].Back) = ColorToRGB(PascalBack(C, Source))) then
        C[E].Back := clDefault;
    end;
end;

{ --- the text of a theme --- }

function ColorHex(C: TColor): string;
var
  RGB: Longint;
begin
  RGB := ColorToRGB(C);
  Result := Format('#%.2X%.2X%.2X', [RGB and $FF, (RGB shr 8) and $FF, (RGB shr 16) and $FF]);
end;

function HexColor(const S: string; out C: TColor): Boolean;
var
  T: string;
  V: Integer;
begin
  T := Trim(S);
  if (T <> '') and (T[1] = '#') then Delete(T, 1, 1);
  V := StrToIntDef('$' + T, -1);
  Result := (Length(T) = 6) and (V >= 0);
  if Result then C := TColor(((V and $FF) shl 16) or (V and $FF00) or ((V shr 16) and $FF));
end;

function ThemeColorText(C: TColor): string;
begin
  if IsDefaultColor(C) then Result := 'default'
  { a system colour by its name, any other as #RRGGBB }
  else if (C >= 0) or not ColorToIdent(C, Result) then Result := ColorHex(C);
end;

function ThemeTextColor(const S: string): TColor;
var
  T: string;
  V: Longint;
begin
  Result := clDefault;
  T := Trim(S);
  if (T = '') or SameText(T, 'default') then Exit;
  if T[1] = '#' then
  begin
    if not HexColor(T, Result) then Result := clDefault;
  end
  else if IdentToColor(T, V) then Result := TColor(V)
  else Result := TColor(StrToIntDef(T, Integer(clDefault)));   // Delphi's $00BBGGRR or a number
  { clNone stands for Default as well: one value for it (the colour boxes have no None) }
  if Result = clNone then Result := clDefault;
end;

function ElementText(const C: TEditorColor): string;
begin
  Result := ThemeColorText(C.Fore) + ',' + ThemeColorText(C.Back);
  if C.Bold then Result := Result + ',bold';
  if C.Italic then Result := Result + ',italic';
  if C.Underline then Result := Result + ',underline';
end;

function TextElement(const S: string): TEditorColor;
var
  L: TStringList;
  I: Integer;
  W: string;
begin
  Result.Fore := clDefault;
  Result.Back := clDefault;
  Result.Bold := False;
  Result.Italic := False;
  Result.Underline := False;
  L := TStringList.Create;
  try
    { at ',' only: CommaText would split a name with a blank }
    L.Text := StringReplace(S, ',', #13#10, [rfReplaceAll]);
    if L.Count > 0 then Result.Fore := ThemeTextColor(L[0]);
    if L.Count > 1 then Result.Back := ThemeTextColor(L[1]);
    for I := 2 to L.Count - 1 do
    begin
      W := LowerCase(Trim(L[I]));
      if W = 'bold' then Result.Bold := True
      else if W = 'italic' then Result.Italic := True
      else if W = 'underline' then Result.Underline := True;
    end;
  finally
    L.Free;
  end;
end;

procedure WriteThemeColors(Ini: TCustomIniFile; const Section: string; const C: TEditorColors);
var
  E: TEditorElement;
begin
  for E := Low(E) to High(E) do Ini.WriteString(Section, ElementKeys[E], ElementText(C[E]));
end;

function ReadThemeColors(Ini: TCustomIniFile; const Section: string; var C: TEditorColors): TEditorElements;
var
  E: TEditorElement;
  L: TStringList;
begin
  Result := [];
  L := TStringList.Create;
  try
    Ini.ReadSectionValues(Section, L);
    for E := Low(E) to High(E) do
      if L.IndexOfName(ElementKeys[E]) >= 0 then
      begin
        C[E] := TextElement(L.Values[ElementKeys[E]]);
        Include(Result, E);
      end;
  finally
    L.Free;
  end;
  FollowPlainText(C);
end;

{ --- Delphi 7's colours --- }

function DelphiDefaultColor(E: TDelphiElement; Back: Boolean): TColor;
begin
  Result := DelphiFactory[E, Back];
end;

procedure ColorsFromDelphi(const D: TDelphiColors; var C: TEditorColors);
var
  IdentFore, IdentBack: TColor;
  E: TEditorElement;

  procedure Take(DE: TDelphiElement; E: TEditorElement);
  begin
    if not D[DE].Present then Exit;
    if D[DE].DefaultFore then C[E].Fore := DelphiFactory[DE, False] else C[E].Fore := D[DE].Fore;
    if epBack in ElementParts[E] then
      if D[DE].DefaultBack then C[E].Back := DelphiFactory[DE, True] else C[E].Back := D[DE].Back;
    if epStyle in ElementParts[E] then
    begin
      C[E].Bold := D[DE].Bold;
      C[E].Italic := D[DE].Italic;
      C[E].Underline := D[DE].Underline;
    end;
  end;

begin
  { how C shows identifiers (Default: as its plain text) }
  IdentFore := ColorToRGB(PascalFore(C, eeIdentifier));
  IdentBack := ColorToRGB(PascalBack(C, eeIdentifier));
  Take(dePlainText, eePlainText);
  Take(deReservedWord, eeReservedWord);
  Take(deIdentifier, eeIdentifier);
  { Delphi 7 colours every name as an identifier: the kinds (IdentElements) keep C's colours only while the
    identifiers look as C's (clWindow is C's white too), else they are Default - Identifier's }
  if (ColorToRGB(PascalFore(C, eeIdentifier)) <> IdentFore) or
    (ColorToRGB(PascalBack(C, eeIdentifier)) <> IdentBack) then
    for E := Low(E) to High(E) do
      if E in IdentElements then C[E].Fore := clDefault;
  Take(deSymbol, eeSymbol);
  Take(deComment, eeComment);
  Take(dePreprocessor, eeDirective);
  Take(deString, eeString);
  Take(deString, eeCharacter);
  Take(deNumber, eeNumber);
  Take(deHex, eeHex);
  Take(deAssembler, eeAssembler);
  Take(deMarkedBlock, eeSelection);
  Take(deSearchMatch, eeSearchMatch);
  Take(deHotLink, eeHotLink);
  Take(deRightMargin, eeRightMargin);
  Take(deExecutionPoint, eeExecutionPoint);
  Take(deEnabledBreak, eeEnabledBreak);
  Take(deDisabledBreak, eeDisabledBreak);
  Take(deInvalidBreak, eeInvalidBreak);
  Take(deErrorLine, eeErrorLine);
  FollowPlainText(C);
end;

function DelphiColorFromText(const S: string): TDelphiColor;
var
  L: TStringList;
begin
  FillChar(Result, SizeOf(Result), 0);
  L := TStringList.Create;
  try
    L.Text := StringReplace(S, ',', #13#10, [rfReplaceAll]);
    if L.Count < 7 then Exit;
    Result.Fore := ThemeTextColor(L[0]);
    Result.Back := ThemeTextColor(L[1]);
    Result.Bold := Trim(L[2]) = '1';
    Result.Italic := Trim(L[3]) = '1';
    Result.Underline := Trim(L[4]) = '1';
    Result.DefaultFore := Trim(L[5]) = '1';
    Result.DefaultBack := Trim(L[6]) = '1';
    Result.Present := (Result.Fore <> clDefault) and (Result.Back <> clDefault);
  finally
    L.Free;
  end;
end;

function FreeThemeName(const Base: string; Names: TStrings): string;
var
  N: Integer;

  function Taken(const S: string): Boolean;
  var
    I: Integer;
  begin
    Result := IsBuiltinTheme(S);
    if (Names <> nil) and not Result then
      for I := 0 to Names.Count - 1 do
        if SameText(Names[I], S) then Result := True;
  end;

begin
  Result := Trim(Base);
  N := 1;
  while Taken(Result) do
  begin
    Inc(N);
    Result := Trim(Base) + ' ' + IntToStr(N);
  end;
end;

end.
