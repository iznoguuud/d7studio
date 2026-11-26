{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEditorOptionsFrame;

{ D7 Studio - Tools | Editor Options: Delphi 7's Editor Properties. The pages are Delphi's, laid out
  for the UI font: General, Source Options (per source file type), Display (with D7
  Studio's word wrap, line numbers, folding, change bars and the scroll bars' markers), Key
  Mappings, Code Insight; and D7 Studio's own pages Color (the editor's colour themes), Highlighting
  and Typing. The values are SdEditorOptions'; the section edits a copy and gives it back with OK.
  A frame: the section Editor Options of the Options dialog (SdOptionsDlg), its pages without
  tabs.

  Color: the theme (a built-in one - Light, Dark, Classic - or one of the user's) and its elements
  in groups (SdEditorThemes); an element's colours and styles, Default its own colour's absence;
  a sample editor that shows every element at once (TSciEdit.Sample: a press on it chooses the
  element there), with a sample of the completion list for the Code Insight elements. A change
  to a built-in theme makes a theme of the user's from it (ChangeThemeElement). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls,
  ExtCtrls, CheckLst, ActnList, SdEditorThemes, SdEditorOptions, SdSciEdit;

type
  TEditorOptionsFrame = class(TFrame)
    PageControl: TPageControl;
    tsGeneral: TTabSheet;
    egLabel21: TLabel;
    lbUndo: TLabel;
    egGroupBox5: TGroupBox;
    eoInsert: TCheckBox;
    eoCursorInTabs: TCheckBox;
    eoGroupUndo: TCheckBox;
    eoCursorBeyondEOF: TCheckBox;
    eoUndoAfterSave: TCheckBox;
    eoBriefRegExp: TCheckBox;
    eoPersistentBlocks: TCheckBox;
    eoOverwriteBlocks: TCheckBox;
    eoDoubleClickLine: TCheckBox;
    eoFindTextAtCursor: TCheckBox;
    eoForceCutCopyEnabled: TCheckBox;
    eoPreserveLineEnds: TCheckBox;
    egPropCheckBox1: TCheckBox;
    eoUndoLimit: TComboBox;
    SpeedSetting: TComboBox;
    tsSourceOptions: TTabSheet;
    soLabel4: TLabel;
    cmbxSourceFileType: TComboBox;
    grbxOptions: TGroupBox;
    soLabel1: TLabel;
    soLabel2: TLabel;
    soLabel3: TLabel;
    lblSyntaxHigh: TLabel;
    eoAutoIndentMode: TCheckBox;
    eoBackspaceUnindents: TCheckBox;
    eoKeepTrailingBlanks: TCheckBox;
    eoOptimalFill: TCheckBox;
    eoSmartTab: TCheckBox;
    eoUseTabChar: TCheckBox;
    eoUseSyntaxHighlight: TCheckBox;
    eoBlockIndent: TComboBox;
    eoTabRack: TComboBox;
    eoHighlightExts: TComboBox;
    eoShowTabChar: TCheckBox;
    eoShowSpaceChar: TCheckBox;
    cmbxSyntaxHighlighter: TComboBox;
    btnCodeTemplates: TButton;
    btnNew: TButton;
    btnDelete: TButton;
    tsDisplay: TTabSheet;
    dpLabel4: TLabel;
    dpLabel7: TLabel;
    dpLabel16: TLabel;
    dpGroupBox11: TGroupBox;
    lbRightMargin: TLabel;
    lbGutterWidth: TLabel;
    eoLineOnMargin: TCheckBox;
    eoRightMargin: TComboBox;
    eoGutterWidth: TComboBox;
    eoVisibleGutter: TCheckBox;
    chkLineNumbers: TCheckBox;
    chkFolding: TCheckBox;
    chkChangeBars: TCheckBox;
    dpGroupBox10: TGroupBox;
    eoBriefCursors: TCheckBox;
    lbHistoryLimit: TLabel;
    chkKeepHistory: TCheckBox;
    cbSortPagesMenu: TCheckBox;
    chkWordWrap: TCheckBox;
    chkNavigationBar: TCheckBox;
    cbHistoryLimit: TComboBox;
    gbScrollBars: TGroupBox;
    chkScrollMarkers: TCheckBox;
    FontName: TComboBox;
    FontSize: TComboBox;
    FontSample: TPanel;
    shpFontSample: TShape;
    tsKeyMappings: TTabSheet;
    kmLabel1: TLabel;
    kmLabel2: TLabel;
    Emulations: TListBox;
    Enhancements: TCheckListBox;
    MoveUp: TButton;
    MoveDn: TButton;
    tsColor: TTabSheet;
    lblTheme: TLabel;
    lblElements: TLabel;
    EditControlHere: TLabel;
    lblForeground: TLabel;
    lblBackground: TLabel;
    cbTheme: TComboBox;
    btnThemeDuplicate: TButton;
    btnThemeRename: TButton;
    btnThemeDelete: TButton;
    btnThemeImport: TButton;
    btnThemeExport: TButton;
    tvElements: TTreeView;
    cbForeground: TColorBox;
    edForeground: TEdit;
    cbBackground: TColorBox;
    edBackground: TEdit;
    chkBold: TCheckBox;
    chkItalic: TCheckBox;
    chkUnderline: TCheckBox;
    lbCompletionSample: TListBox;
    tsCodeInsight: TTabSheet;
    ciGroupBox14: TGroupBox;
    ciLabel13: TLabel;
    ciLabel14: TLabel;
    ciLabel15: TLabel;
    cbCodeCompletion: TCheckBox;
    DelayAmount: TTrackBar;
    cbCodeParameters: TCheckBox;
    cbEvalHints: TCheckBox;
    cbDeclInfo: TCheckBox;
    cbErrorInsight: TCheckBox;
    lblInsightNote: TLabel;
    tsHighlighting: TTabSheet;
    lblHighlightNote: TLabel;
    gbMatching: TGroupBox;
    chkBrackets: TCheckBox;
    chkRainbow: TCheckBox;
    chkBlocks: TCheckBox;
    chkIdentifiers: TCheckBox;
    chkOccurrences: TCheckBox;
    chkFindMatches: TCheckBox;
    gbHighlightDisplay: TGroupBox;
    chkCurrentLine: TCheckBox;
    chkIndentGuides: TCheckBox;
    tsTyping: TTabSheet;
    lblTypingNote: TLabel;
    gbTyping: TGroupBox;
    chkAutoClose: TCheckBox;
    chkBlockCompletion: TCheckBox;
    chkSmartIndent: TCheckBox;
    chkCaretClick: TCheckBox;
    Actions: TActionList;
    aFileTypeNew: TAction;
    aFileTypeDelete: TAction;
    aCodeTemplates: TAction;
    aModuleUp: TAction;
    aModuleDown: TAction;
    aThemeDuplicate: TAction;
    aThemeRename: TAction;
    aThemeDelete: TAction;
    aThemeImport: TAction;
    aThemeExport: TAction;
    procedure aFileTypeNewExecute(Sender: TObject);
    procedure aFileTypeDeleteExecute(Sender: TObject);
    procedure FileTypeDeleteUpdate(Sender: TObject);
    procedure aCodeTemplatesExecute(Sender: TObject);
    procedure ModuleMoveExecute(Sender: TObject);
    procedure ModuleMoveUpdate(Sender: TObject);
    procedure SpeedSettingSelect(Sender: TObject);
    procedure SourceFileTypeSelect(Sender: TObject);
    procedure FontChanged(Sender: TObject);
    procedure ThemeSelect(Sender: TObject);
    procedure aThemeDuplicateExecute(Sender: TObject);
    procedure aThemeRenameExecute(Sender: TObject);
    procedure aThemeDeleteExecute(Sender: TObject);
    procedure aThemeImportExecute(Sender: TObject);
    procedure aThemeExportExecute(Sender: TObject);
    procedure ThemeUserUpdate(Sender: TObject);
    procedure ElementTreeChange(Sender: TObject; Node: TTreeNode);
    procedure ElementColorSelect(Sender: TObject);
    procedure ElementHexChange(Sender: TObject);
    procedure ElementStyleClick(Sender: TObject);
    procedure CompletionSampleDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
      State: TOwnerDrawState);
    procedure CompletionSampleClick(Sender: TObject);
    procedure chkKeepHistoryClick(Sender: TObject);
  private
    FOpts: TEditorOptions;            // the values being edited
    FFileType: Integer;               // the file type shown on Source Options
    FHighlighterIDs: TStringList;     // the IDs of the highlighter box's items, in its order
    FElement: TEditorElement;         // the element shown on Color
    FNodes: array[TEditorElement] of TTreeNode;
    FSample: TSciEdit;
    FSampleReady: Boolean;            // its text and its marks are there
    FSampleBold: TFont;               // the completion list sample's bold font
    FLoading: Boolean;
    procedure LoadControls;
    procedure SaveControls;
    procedure ShowFileType(Index: Integer);
    procedure KeepFileType;
    procedure FillHighlighters;
    function HighlighterItem(const ID: string): Integer;
    procedure FillThemes;
    procedure FillElements;
    procedure ShowElement(E: TEditorElement; Reveal: Boolean = False);
    procedure EnableParts(Parts: TElementParts);
    function ShownFore: TColor;
    procedure ChangeElement(const V: TEditorColor);
    procedure ColorsChanged;
    function ThemeName: string;
    function OwnTheme: Integer;
    procedure UpdateSample;
    function SampleOptions: TEditorOptions;
    procedure SetupSample;
    procedure SampleClick(Sender: TObject; Pos, Line, Margin: Integer);
    function ElementAt(Pos, Line, Margin: Integer): TEditorElement;
    procedure RevealElement(E: TEditorElement);
    procedure PlaceCompletionSample;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the lists filled and the values shown, once, when the section is first shown; the values
      given back after OK }
    procedure LoadOptions;
    procedure SaveOptions;
  end;

implementation

{$R *.dfm}

uses
  Messages, Math, ToolsAPI, SdUI, SdSciDefs, SdSciLexDefs, SdSciScroll, SdDialogs, SdKeymaps, SdCompletion;

const
  { the syntax highlighters of the Source Options page: Delphi's IDs and names (experts'
    highlighters follow); the other languages' lexers go by the files' extensions }
  Highlighters: array[0..1] of record ID, Name: string end = (
    (ID: NoHighlighter; Name: 'None'),
    (ID: PascalHighlighter; Name: 'Pascal'));
  { the factory file types cannot be deleted (Delphi's rule) }
  FactoryTypes = ',Borland.EditOptions.Pascal,Borland.EditOptions.C,Borland.EditOptions.C#,' +
    'Borland.EditOptions.HTML,Borland.EditOptions.IDL,Borland.EditOptions.SQL,' +
    'Borland.EditOptions.XML,Borland.EditOptions.Default,';
  { The Color page's sample, after Delphi 7's: each element somewhere - the debugger's lines, a
    line saved since it changed and one changed since, a word selected (the caret after it, its
    occurrences), the identifier I's places, the brackets of a call matched, a stray one, the
    words of a block, rainbow brackets, a search match, a hot link, a tab shown, a name of each
    kind and one code insight would not know (Offset) }
  SampleText =
    '{ Syntax Highlighting }'#13#10 +
    'procedure TForm1.Button1Click(Sender: TObject);'#13#10 +
    'const'#13#10 +
    '  Limit = $FF;'#13#10 +
    'var'#13#10 +
    '  Number, I, X: Integer;'#13#10 +
    '  A: array[0..9] of Integer;'#9'// tab'#13#10 +
    '  S: string;'#13#10 +
    'begin'#13#10 +
    '  Number := 123456;'#13#10 +
    '  Caption := ''The Number is '' + IntToStr(Number);'#13#10 +
    '  S := SysUtils.Trim(S) + #13#10;'#13#10 +
    '  for I := 0 to Number do'#13#10 +
    '  begin'#13#10 +
    '    Inc(X);'#13#10 +
    '    Dec(X);'#13#10 +
    '    X := X + 1.0;'#13#10 +
    '    X := X - 5);'#13#10 +
    '    X := Trunc((X + FCount) * (A[I] - 2));'#13#10 +
    '  end;'#13#10 +
    '  Tag := Limit + Offset;'#13#10 +
    '  Application.Title := S;'#13#10 +
    '  {$R+}'#13#10 +
    '  asm'#13#10 +
    '    MOV AX,1234H'#13#10 +
    '    MOV Number,AX'#13#10 +
    '  end;'#13#10 +
    '  {$R-}'#13#10 +
    'end;';
  SampleHeadLine = 1;        // procedure ...(Sender: TObject): the hot link
  SampleDeclLine = 5;        // Number, I, X: the identifier's declaration
  SampleSelLine = 9;         // Number := 123456: the selection, the current line
  SampleCallLine = 10;       // IntToStr(...): search match, matching brackets
  SampleSavedLine = 11;
  SampleForLine = 12;        // for I: the identifier
  SampleBeginLine = 13;      // begin ... end: matching words
  SampleBreakLine = 14;
  SampleDisabledLine = 15;
  SampleExecLine = 16;
  SampleErrorLine = 17;      // ... its stray bracket
  SampleRainbowLine = 18;
  SampleEndLine = 19;
  SampleInvalidLine = 22;
  SampleModifiedLine = 24;
  SampleAsmLine = 25;        // MOV Number,AX
  SampleMargin = 40;         // the right margin's column in the sample: in view
  { the sample's names by kind, as code insight finds them in a unit (the editor page's) }
  SampleNames: array[0..21] of record Name: string; E: TEditorElement end = (
    (Name: 'TForm1'; E: eeType), (Name: 'TObject'; E: eeType), (Name: 'Integer'; E: eeType),
    (Name: 'Button1Click'; E: eeRoutine), (Name: 'IntToStr'; E: eeRoutine), (Name: 'Trim'; E: eeRoutine),
    (Name: 'Inc'; E: eeRoutine), (Name: 'Dec'; E: eeRoutine), (Name: 'Trunc'; E: eeRoutine),
    (Name: 'Caption'; E: eeProperty), (Name: 'Tag'; E: eeProperty), (Name: 'Title'; E: eeProperty),
    (Name: 'FCount'; E: eeField), (Name: 'Application'; E: eeVariable),
    (Name: 'Number'; E: eeLocalVar), (Name: 'I'; E: eeLocalVar), (Name: 'X'; E: eeLocalVar),
    (Name: 'A'; E: eeLocalVar), (Name: 'S'; E: eeLocalVar), (Name: 'Sender'; E: eeParameter),
    (Name: 'Limit'; E: eeConstant), (Name: 'SysUtils'; E: eeUnitName));
  { the rows of the completion list's sample: the kind's word, the name, the rest, the element }
  CompletionRows: array[0..8] of record Kind, Name, Rest: string; E: TEditorElement end = (
    (Kind: 'procedure'; Name: 'Button1Click'; Rest: '(Sender: TObject);'; E: eeCompProcedure),
    (Kind: 'function'; Name: 'IntToStr'; Rest: '(Value: Integer): string;'; E: eeCompFunction),
    (Kind: 'property'; Name: 'Caption'; Rest: ': TCaption'; E: eeCompProperty),
    (Kind: 'var'; Name: 'Number'; Rest: ': Integer'; E: eeCompVariable),
    (Kind: 'const'; Name: 'MaxCount'; Rest: ' = 10'; E: eeCompConstant),
    (Kind: 'type'; Name: 'TForm1'; Rest: ' = class(TForm)'; E: eeCompType),
    (Kind: 'unit'; Name: 'SysUtils'; Rest: ''; E: eeCompUnit),
    (Kind: 'label'; Name: 'Again'; Rest: ''; E: eeCompLabel),
    (Kind: 'procedure'; Name: 'Paint'; Rest: '; virtual; abstract;'; E: eeCompAbstract));

var
  { Rename / Duplicate: the options whose theme names a new name may not take (ThemeNameCheck),
    and the name being renamed (it may change its letter case) }
  CheckOpts: ^TEditorOptions;
  CheckOldName: string;

{ the name a theme may have: not empty, no square brackets (a section's name), not another
  theme's - '' when it may }
function ThemeNameCheck(const Value: string): string;
var
  N: string;
begin
  Result := '';
  N := Trim(Value);
  if N = '' then Result := 'The theme needs a name.'
  else if (Pos('[', N) > 0) or (Pos(']', N) > 0) then Result := 'A theme''s name cannot have square brackets.'
  else if IsBuiltinTheme(N) then Result := Format('%s is a built-in theme.', [N])
  else if (CheckOpts <> nil) and (UserThemeIndex(CheckOpts^, N) >= 0) and not SameText(N, CheckOldName) then
    Result := Format('There is a theme named %s already.', [N]);
end;

procedure TEditorOptionsFrame.SaveOptions;
begin
  SaveControls;
  { a Pascal element's colour chosen that is Plain text's follows Plain text from now on. Not
    while the page is open: the colour boxes' arrow keys pass colours on their way, and a token's
    own colour passed by Plain text's would be Default for good }
  ThemesFollowPlainText(FOpts);
  EditorOptions := FOpts;
end;

{ the fixed-pitch fonts (Delphi offers only those for the editor) }
function FixedFontProc(var LF: TEnumLogFontEx; TM: Pointer; FontType: Integer; Data: LPARAM): Integer; stdcall;
var
  L: TStrings;
  N: string;
begin
  L := TStrings(Data);
  N := LF.elfLogFont.lfFaceName;
  if (LF.elfLogFont.lfPitchAndFamily and 3 = FIXED_PITCH) and (N <> '') and (N[1] <> '@') and
    (L.IndexOf(N) < 0) then
    L.Add(N);
  Result := 1;
end;

procedure FixedFonts(L: TStrings);
var
  DC: HDC;
  LF: TLogFont;
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.Sorted := True;
    FillChar(LF, SizeOf(LF), 0);
    LF.lfCharSet := DEFAULT_CHARSET;
    DC := GetDC(0);
    try
      EnumFontFamiliesEx(DC, LF, @FixedFontProc, LPARAM(S), 0);
    finally
      ReleaseDC(0, DC);
    end;
    L.Assign(S);
  finally
    S.Free;
  end;
end;

{ laid out for the UI font only: LoadOptions fills it when the section is first shown. The
  completion list's sample fits its rows itself (no list tracking) }
constructor TEditorOptionsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  UIPrepareFrame(Self);
  UINoListTracking(lbCompletionSample);
end;

destructor TEditorOptionsFrame.Destroy;
begin
  FHighlighterIDs.Free;
  FSampleBold.Free;
  inherited;
end;

procedure TEditorOptionsFrame.LoadOptions;
var
  I: Integer;
  W: TSciWindow;
begin
  FOpts := EditorOptions;
  FOpts.FileTypes := Copy(EditorOptions.FileTypes, 0, Length(EditorOptions.FileTypes));
  FOpts.Themes := Copy(EditorOptions.Themes, 0, Length(EditorOptions.Themes));
  { lists that come from data: the keymapping modules (Key Mappings), the highlighters, fonts,
    the elements of the themes }
  Emulations.Items.Clear;
  for I := 0 to High(KeymapNames) do Emulations.Items.Add(KeymapNames[I]);
  FillHighlighters;
  FixedFonts(FontName.Items);
  FillElements;
  { the Color page's sample: an editor where Delphi's placeholder lies, showing the colours of
    the section; the completion list's sample over it }
  W := TSciWindow.Create(Self);
  W.Parent := EditControlHere.Parent;
  W.BoundsRect := EditControlHere.BoundsRect;
  W.TabStop := False;
  FSample := W.Edit;
  lbCompletionSample.BringToFront;
  FSampleBold := TFont.Create;
  for I := 0 to High(CompletionRows) do lbCompletionSample.Items.Add(CompletionRows[I].Name);
  { what changes the shown values }
  LoadControls;
end;

procedure SetCombo(C: TComboBox; const Value: string);
var
  I: Integer;
begin
  I := C.Items.IndexOf(Value);
  if C.Style = csDropDownList then C.ItemIndex := I
  else C.Text := Value;
end;

procedure TEditorOptionsFrame.LoadControls;
var
  I: Integer;
begin
  FLoading := True;
  try
    { General }
    eoInsert.Checked := FOpts.InsertMode;
    eoCursorInTabs.Checked := FOpts.CursorThroughTabs;
    eoGroupUndo.Checked := FOpts.GroupUndo;
    eoCursorBeyondEOF.Checked := FOpts.CursorBeyondEOF;
    eoUndoAfterSave.Checked := FOpts.UndoAfterSave;
    eoBriefRegExp.Checked := FOpts.BriefRegExp;
    eoPersistentBlocks.Checked := FOpts.PersistentBlocks;
    eoOverwriteBlocks.Checked := FOpts.OverwriteBlocks;
    eoDoubleClickLine.Checked := FOpts.DoubleClickLine;
    eoFindTextAtCursor.Checked := FOpts.FindTextAtCursor;
    eoForceCutCopyEnabled.Checked := FOpts.ForceCutCopy;
    eoPreserveLineEnds.Checked := FOpts.PreserveLineEnds;
    egPropCheckBox1.Checked := FOpts.FindAutoComplete;
    eoUndoLimit.Text := IntToStr(FOpts.UndoLimit);
    SpeedSetting.ItemIndex := Emulations.Items.IndexOf(FOpts.Keymapping);
    { Source Options }
    cmbxSourceFileType.Items.Clear;
    for I := 0 to High(FOpts.FileTypes) do cmbxSourceFileType.Items.Add(FOpts.FileTypes[I].Name);
    FFileType := -1;
    ShowFileType(0);
    { Display }
    eoBriefCursors.Checked := FOpts.BriefCursors;
    chkKeepHistory.Checked := FOpts.KeepHistory;
    cbHistoryLimit.Text := IntToStr(FOpts.HistoryLimit);
    chkKeepHistoryClick(nil);
    cbSortPagesMenu.Checked := FOpts.SortPagesMenu;
    eoLineOnMargin.Checked := FOpts.ShowRightMargin;
    eoRightMargin.Text := IntToStr(FOpts.RightMargin);
    eoVisibleGutter.Checked := FOpts.VisibleGutter;
    eoGutterWidth.Text := IntToStr(FOpts.GutterWidth);
    chkWordWrap.Checked := FOpts.WordWrap;
    chkNavigationBar.Checked := FOpts.NavigationBar;
    chkLineNumbers.Checked := FOpts.ShowLineNumbers;
    chkFolding.Checked := FOpts.ShowFolding;
    chkChangeBars.Checked := FOpts.ShowChangeBars;
    chkScrollMarkers.Checked := FOpts.ScrollBarMarkers;
    SetCombo(FontName, FOpts.FontName);
    SetCombo(FontSize, IntToStr(FOpts.FontSize));
    { Key Mappings }
    Emulations.ItemIndex := Emulations.Items.IndexOf(FOpts.Keymapping);
    { Color }
    FillThemes;
    { Code Insight }
    cbCodeCompletion.Checked := FOpts.AutoComplete;
    cbCodeParameters.Checked := FOpts.AutoParameters;
    cbEvalHints.Checked := FOpts.TooltipEval;
    cbDeclInfo.Checked := FOpts.TooltipDecl;
    cbErrorInsight.Checked := FOpts.ErrorInsight;
    DelayAmount.Position := FOpts.CodeDelay;
    { Highlighting }
    chkBrackets.Checked := FOpts.HighlightBraces;
    chkRainbow.Checked := FOpts.RainbowBrackets;
    chkBlocks.Checked := FOpts.HighlightBlocks;
    chkIdentifiers.Checked := FOpts.HighlightIdentifiers;
    chkOccurrences.Checked := FOpts.HighlightOccurrences;
    chkFindMatches.Checked := FOpts.HighlightFindMatches;
    chkCurrentLine.Checked := FOpts.HighlightCurrentLine;
    chkIndentGuides.Checked := FOpts.IndentGuides;
    { Typing }
    chkAutoClose.Checked := FOpts.AutoClosePairs;
    chkBlockCompletion.Checked := FOpts.BlockCompletion;
    chkSmartIndent.Checked := FOpts.SmartIndent;
    chkCaretClick.Checked := FOpts.CaretClick;
  finally
    FLoading := False;
  end;
  FElement := eePlainText;
  ColorsChanged;
  FontChanged(nil);
end;

procedure TEditorOptionsFrame.SaveControls;
begin
  FOpts.InsertMode := eoInsert.Checked;
  FOpts.CursorThroughTabs := eoCursorInTabs.Checked;
  FOpts.GroupUndo := eoGroupUndo.Checked;
  FOpts.CursorBeyondEOF := eoCursorBeyondEOF.Checked;
  FOpts.UndoAfterSave := eoUndoAfterSave.Checked;
  FOpts.BriefRegExp := eoBriefRegExp.Checked;
  FOpts.PersistentBlocks := eoPersistentBlocks.Checked;
  FOpts.OverwriteBlocks := eoOverwriteBlocks.Checked;
  FOpts.DoubleClickLine := eoDoubleClickLine.Checked;
  FOpts.FindTextAtCursor := eoFindTextAtCursor.Checked;
  FOpts.ForceCutCopy := eoForceCutCopyEnabled.Checked;
  FOpts.PreserveLineEnds := eoPreserveLineEnds.Checked;
  FOpts.FindAutoComplete := egPropCheckBox1.Checked;
  FOpts.UndoLimit := StrToIntDef(eoUndoLimit.Text, FOpts.UndoLimit);
  KeepFileType;
  FOpts.BriefCursors := eoBriefCursors.Checked;
  FOpts.KeepHistory := chkKeepHistory.Checked;
  FOpts.HistoryLimit := Max(1, Min(StrToIntDef(cbHistoryLimit.Text, FOpts.HistoryLimit), 9999));
  FOpts.SortPagesMenu := cbSortPagesMenu.Checked;
  FOpts.ShowRightMargin := eoLineOnMargin.Checked;
  FOpts.RightMargin := StrToIntDef(eoRightMargin.Text, FOpts.RightMargin);
  FOpts.VisibleGutter := eoVisibleGutter.Checked;
  FOpts.GutterWidth := StrToIntDef(eoGutterWidth.Text, FOpts.GutterWidth);
  FOpts.WordWrap := chkWordWrap.Checked;
  FOpts.NavigationBar := chkNavigationBar.Checked;
  FOpts.ShowLineNumbers := chkLineNumbers.Checked;
  FOpts.ShowFolding := chkFolding.Checked;
  FOpts.ShowChangeBars := chkChangeBars.Checked;
  FOpts.ScrollBarMarkers := chkScrollMarkers.Checked;
  if FontName.Text <> '' then FOpts.FontName := FontName.Text;
  FOpts.FontSize := StrToIntDef(FontSize.Text, FOpts.FontSize);
  if (FOpts.FontSize < 6) or (FOpts.FontSize > 72) then FOpts.FontSize := 10;
  if Emulations.ItemIndex >= 0 then FOpts.Keymapping := Emulations.Items[Emulations.ItemIndex];
  FOpts.AutoComplete := cbCodeCompletion.Checked;
  FOpts.AutoParameters := cbCodeParameters.Checked;
  FOpts.TooltipEval := cbEvalHints.Checked;
  FOpts.TooltipDecl := cbDeclInfo.Checked;
  FOpts.ErrorInsight := cbErrorInsight.Checked;
  FOpts.CodeDelay := DelayAmount.Position;
  FOpts.HighlightBraces := chkBrackets.Checked;
  FOpts.RainbowBrackets := chkRainbow.Checked;
  FOpts.HighlightBlocks := chkBlocks.Checked;
  FOpts.HighlightIdentifiers := chkIdentifiers.Checked;
  FOpts.HighlightOccurrences := chkOccurrences.Checked;
  FOpts.HighlightFindMatches := chkFindMatches.Checked;
  FOpts.HighlightCurrentLine := chkCurrentLine.Checked;
  FOpts.IndentGuides := chkIndentGuides.Checked;
  FOpts.AutoClosePairs := chkAutoClose.Checked;
  FOpts.BlockCompletion := chkBlockCompletion.Checked;
  FOpts.SmartIndent := chkSmartIndent.Checked;
  FOpts.CaretClick := chkCaretClick.Checked;
  if FOpts.RightMargin < 1 then FOpts.RightMargin := 80;
  if FOpts.GutterWidth < 0 then FOpts.GutterWidth := 30;
end;

{ --- Source Options: one file type at a time --- }

procedure TEditorOptionsFrame.KeepFileType;
var
  I: Integer;
begin
  if (FFileType < 0) or (FFileType > High(FOpts.FileTypes)) then Exit;
  with FOpts.FileTypes[FFileType] do
  begin
    AutoIndent := eoAutoIndentMode.Checked;
    BackspaceUnindents := eoBackspaceUnindents.Checked;
    KeepTrailingBlanks := eoKeepTrailingBlanks.Checked;
    OptimalFill := eoOptimalFill.Checked;
    SmartTab := eoSmartTab.Checked;
    UseTabChar := eoUseTabChar.Checked;
    UseSyntaxHighlight := eoUseSyntaxHighlight.Checked;
    ShowTabChar := eoShowTabChar.Checked;
    ShowSpaceChar := eoShowSpaceChar.Checked;
    BlockIndent := StrToIntDef(eoBlockIndent.Text, BlockIndent);
    if BlockIndent < 1 then BlockIndent := 1;
    TabStops := Trim(eoTabRack.Text);
    Extensions := Trim(eoHighlightExts.Text);
    I := cmbxSyntaxHighlighter.ItemIndex;
    if (I >= 0) and (I < FHighlighterIDs.Count) then Highlighter := FHighlighterIDs[I];
  end;
end;

{ the highlighter box: D7 Studio's highlighters, then those experts registered (IOTAHighlightServices).
  The service lists Delphi's built-in highlighters too; only those whose lines an expert's code
  styles (SciTokenizerFor) are added - the built-ins beyond D7 Studio's own colour nothing }
procedure TEditorOptionsFrame.FillHighlighters;
var
  I: Integer;
  HS: IOTAHighlightServices;
  H: IOTAHighlighter;
  ID, Name: string;
begin
  if FHighlighterIDs = nil then FHighlighterIDs := TStringList.Create;
  FHighlighterIDs.Clear;
  cmbxSyntaxHighlighter.Items.Clear;
  for I := 0 to High(Highlighters) do
  begin
    cmbxSyntaxHighlighter.Items.Add(Highlighters[I].Name);
    FHighlighterIDs.Add(Highlighters[I].ID);
  end;
  if not Supports(BorlandIDEServices, IOTAHighlightServices, HS) then Exit;
  for I := 0 to HS.GetHighlighterCount - 1 do
    try
      H := HS.GetHighlighter(I);
      if H = nil then Continue;
      ID := H.GetIDString;
      Name := H.GetName;
      if (ID <> '') and (FHighlighterIDs.IndexOf(ID) < 0) and Assigned(SciTokenizerFor) and
        (SciTokenizerFor(ID) <> nil) then
      begin
        cmbxSyntaxHighlighter.Items.Add(Name);
        FHighlighterIDs.Add(ID);
      end;
    except
      { an expert's highlighter that cannot answer is not offered }
    end;
end;

{ the item of highlighter ID; an ID the box does not have (an expert's highlighter not loaded now) is
  added under its ID, so that OK keeps it }
function TEditorOptionsFrame.HighlighterItem(const ID: string): Integer;
begin
  Result := FHighlighterIDs.IndexOf(ID);
  if (Result < 0) and (ID <> '') then
  begin
    cmbxSyntaxHighlighter.Items.Add(ID);
    Result := FHighlighterIDs.Add(ID);
  end;
  if Result < 0 then Result := 0;
end;

procedure TEditorOptionsFrame.ShowFileType(Index: Integer);
begin
  KeepFileType;
  FFileType := Index;
  cmbxSourceFileType.ItemIndex := Index;
  if (Index < 0) or (Index > High(FOpts.FileTypes)) then Exit;
  with FOpts.FileTypes[Index] do
  begin
    eoAutoIndentMode.Checked := AutoIndent;
    eoBackspaceUnindents.Checked := BackspaceUnindents;
    eoKeepTrailingBlanks.Checked := KeepTrailingBlanks;
    eoOptimalFill.Checked := OptimalFill;
    eoSmartTab.Checked := SmartTab;
    eoUseTabChar.Checked := UseTabChar;
    eoUseSyntaxHighlight.Checked := UseSyntaxHighlight;
    eoShowTabChar.Checked := ShowTabChar;
    eoShowSpaceChar.Checked := ShowSpaceChar;
    eoBlockIndent.Text := IntToStr(BlockIndent);
    eoTabRack.Text := TabStops;
    eoHighlightExts.Text := Extensions;
    cmbxSyntaxHighlighter.ItemIndex := HighlighterItem(Highlighter);
  end;
end;

procedure TEditorOptionsFrame.SourceFileTypeSelect(Sender: TObject);
begin
  ShowFileType(cmbxSourceFileType.ItemIndex);
end;

{ New: a file type of the user's, with the Default type's values }
procedure TEditorOptionsFrame.aFileTypeNewExecute(Sender: TObject);
var
  Name: string;
  N, I: Integer;
begin
  Name := '';
  if not InputDialog(Self, 'New Source File Type', 'Source file type name:', Name) then Exit;
  Name := Trim(Name);
  if Name = '' then Exit;
  for I := 0 to High(FOpts.FileTypes) do
    if SameText(FOpts.FileTypes[I].Name, Name) then
    begin
      ShowFileType(I);
      Exit;
    end;
  KeepFileType;
  N := Length(FOpts.FileTypes);
  SetLength(FOpts.FileTypes, N + 1);
  FOpts.FileTypes[N] := EditorFileType('');
  FOpts.FileTypes[N].ID := 'User.EditOptions.' + Name;
  FOpts.FileTypes[N].Name := Name;
  FOpts.FileTypes[N].Extensions := '';
  cmbxSourceFileType.Items.Add(Name);
  FFileType := -1;
  ShowFileType(N);
end;

procedure TEditorOptionsFrame.aFileTypeDeleteExecute(Sender: TObject);
var
  I: Integer;
begin
  if (FFileType < 0) or (Pos(',' + FOpts.FileTypes[FFileType].ID + ',', FactoryTypes) > 0) then Exit;
  for I := FFileType to High(FOpts.FileTypes) - 1 do FOpts.FileTypes[I] := FOpts.FileTypes[I + 1];
  SetLength(FOpts.FileTypes, Length(FOpts.FileTypes) - 1);
  cmbxSourceFileType.Items.Delete(FFileType);
  FFileType := -1;
  ShowFileType(0);
end;

procedure TEditorOptionsFrame.FileTypeDeleteUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (FFileType >= 0) and (FFileType <= High(FOpts.FileTypes)) and
    (Pos(',' + FOpts.FileTypes[FFileType].ID + ',', FactoryTypes) = 0);
end;

procedure TEditorOptionsFrame.aCodeTemplatesExecute(Sender: TObject);
begin
  CodeTemplatesDialog(Self);
end;

{ Key Mappings: the enhancement modules' order (D7 Studio has none installed) }
procedure TEditorOptionsFrame.ModuleMoveExecute(Sender: TObject);
begin
  MoveListRow(Enhancements, Sender = aModuleUp);
end;

procedure TEditorOptionsFrame.ModuleMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CanMoveListRow(Enhancements, Sender = aModuleUp);
end;

{ --- Display: the font sample --- }

procedure TEditorOptionsFrame.FontChanged(Sender: TObject);
begin
  if FontName.Text <> '' then FontSample.Font.Name := FontName.Text;
  FontSample.Font.Size := StrToIntDef(FontSize.Text, 10);
  if (Sender <> nil) and not FLoading then UpdateSample;
end;

{ General | Editor SpeedSetting: a preset of Delphi's - the keymapping, and BRIEF's cursor shapes
  and regular expressions for BRIEF }
procedure TEditorOptionsFrame.SpeedSettingSelect(Sender: TObject);
var
  Brief: Boolean;
begin
  if SpeedSetting.ItemIndex < 0 then Exit;
  Emulations.ItemIndex := SpeedSetting.ItemIndex;
  Brief := SpeedSetting.ItemIndex = 2;
  eoBriefRegExp.Checked := Brief;
  eoBriefCursors.Checked := Brief;
end;

{ --- Color: the themes --- }

function TEditorOptionsFrame.ThemeName: string;
begin
  Result := FOpts.ColorTheme;
end;

{ the user's theme shown (-1: a built-in one) }
function TEditorOptionsFrame.OwnTheme: Integer;
begin
  Result := UserThemeIndex(FOpts, FOpts.ColorTheme);
end;

{ the themes in the box, the one in use chosen }
procedure TEditorOptionsFrame.FillThemes;
begin
  cbTheme.Items.BeginUpdate;
  try
    ThemeNames(FOpts, cbTheme.Items);
  finally
    cbTheme.Items.EndUpdate;
  end;
  cbTheme.ItemIndex := cbTheme.Items.IndexOf(FOpts.ColorTheme);
end;

procedure TEditorOptionsFrame.ThemeSelect(Sender: TObject);
begin
  if cbTheme.ItemIndex < 0 then Exit;
  SelectTheme(FOpts, cbTheme.Items[cbTheme.ItemIndex]);
  FillThemes;
  ColorsChanged;
end;

{ the colours shown changed (another theme, an element): the element's controls, the sample }
procedure TEditorOptionsFrame.ColorsChanged;
begin
  ShowElement(FElement);
  UpdateSample;
end;

procedure TEditorOptionsFrame.ThemeUserUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := OwnTheme >= 0;
end;

{ Duplicate: the theme shown under a new name, in use from then on }
procedure TEditorOptionsFrame.aThemeDuplicateExecute(Sender: TObject);
var
  Name: string;
  I: Integer;
begin
  Name := FreeUserThemeName(FOpts, ThemeName + ' (copy)');
  CheckOpts := @FOpts;
  CheckOldName := '';
  try
    if not InputDialog(Self, 'Duplicate Theme', 'Name of the new theme:', Name, ThemeNameCheck) then Exit;
  finally
    CheckOpts := nil;
  end;
  { the same colours under another name: the sample stays as it is }
  I := AddUserTheme(FOpts, Trim(Name), FOpts.Colors);
  SelectTheme(FOpts, FOpts.Themes[I].Name);
  FillThemes;
end;

procedure TEditorOptionsFrame.aThemeRenameExecute(Sender: TObject);
var
  I: Integer;
  Name: string;
begin
  I := OwnTheme;
  if I < 0 then Exit;
  Name := FOpts.Themes[I].Name;
  CheckOpts := @FOpts;
  CheckOldName := Name;
  try
    if not InputDialog(Self, 'Rename Theme', 'New name of the theme:', Name, ThemeNameCheck) then Exit;
  finally
    CheckOpts := nil;
  end;
  FOpts.Themes[I].Name := Trim(Name);
  FOpts.ColorTheme := FOpts.Themes[I].Name;
  FillThemes;
end;

procedure TEditorOptionsFrame.aThemeDeleteExecute(Sender: TObject);
var
  I: Integer;
begin
  I := OwnTheme;
  if I < 0 then Exit;
  if MessageBox(GetParentForm(Self).Handle, PChar(Format('Delete the theme ''%s''?', [FOpts.Themes[I].Name])),
    'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  DeleteUserTheme(FOpts, I);
  FillThemes;
  ColorsChanged;
end;

{ Import: a theme file's theme among the user's, in use from then on. A name of a built-in theme
  gets a number; one of the user's themes is replaced (Yes) or the new one numbered (No) }
procedure TEditorOptionsFrame.aThemeImportExecute(Sender: TObject);
var
  FileName: string;
  T: TEditorTheme;
  I: Integer;
begin
  FileName := '';
  if not BrowseFile('Import Theme', 'D7 Studio editor themes (*.' + ThemeFileExt + ')|*.' + ThemeFileExt +
    '|All files (*.*)|*.*', FileName, bfOpen) then Exit;
  try
    if not ImportTheme(FileName, T) then
    begin
      MessageBox(GetParentForm(Self).Handle, PChar(Format('%s has no editor theme.', [FileName])), 'Import Theme',
        MB_OK or MB_ICONERROR);
      Exit;
    end;
  except
    on E: Exception do
    begin
      MessageBox(GetParentForm(Self).Handle, PChar(E.Message), 'Import Theme', MB_OK or MB_ICONERROR);
      Exit;
    end;
  end;
  { a name a theme may have (ThemeNameCheck): square brackets as round ones, none: Imported }
  T.Name := Trim(StringReplace(StringReplace(T.Name, '[', '(', [rfReplaceAll]), ']', ')', [rfReplaceAll]));
  if T.Name = '' then T.Name := 'Imported';
  I := UserThemeIndex(FOpts, T.Name);
  if I >= 0 then
    case MessageBox(GetParentForm(Self).Handle, PChar(Format('There is a theme named %s already. Replace it?' +
      #13#10#13#10'No: the imported theme is added under another name.', [T.Name])), 'Import Theme',
      MB_YESNOCANCEL or MB_ICONQUESTION) of
      IDYES: FOpts.Themes[I].Colors := T.Colors;
      IDNO: I := -1;
    else
      Exit;
    end;
  if I < 0 then I := AddUserTheme(FOpts, T.Name, T.Colors);     // a free name (FreeUserThemeName)
  SelectTheme(FOpts, FOpts.Themes[I].Name);
  FillThemes;
  ColorsChanged;
end;

{ Export: the theme shown (a built-in one too) as a theme file; the name proposed is the theme's,
  what a file name cannot have as '_' }
procedure TEditorOptionsFrame.aThemeExportExecute(Sender: TObject);
var
  FileName: string;
  T: TEditorTheme;
  I: Integer;
begin
  T.Name := ThemeName;
  T.Colors := FOpts.Colors;
  FileName := T.Name;
  for I := 1 to Length(FileName) do
    if FileName[I] in ['\', '/', ':', '*', '?', '"', '<', '>', '|'] then FileName[I] := '_';
  FileName := FileName + '.' + ThemeFileExt;
  if not BrowseFile('Export Theme', 'D7 Studio editor themes (*.' + ThemeFileExt + ')|*.' + ThemeFileExt,
    FileName, bfSave, ThemeFileExt) then Exit;
  try
    ExportTheme(FileName, T);
  except
    on E: Exception do
      MessageBox(GetParentForm(Self).Handle, PChar(E.Message), 'Export Theme', MB_OK or MB_ICONERROR);
  end;
end;

{ --- Color: the elements --- }

{ the tree: a node for each group with its elements; Pascal open }
procedure TEditorOptionsFrame.FillElements;
var
  G: TEditorGroup;
  E: TEditorElement;
  N: TTreeNode;
begin
  tvElements.Items.BeginUpdate;
  try
    tvElements.Items.Clear;
    for G := Low(G) to High(G) do
    begin
      N := tvElements.Items.AddChild(nil, GroupCaptions[G]);
      for E := Low(E) to High(E) do
        if ElementGroups[E] = G then
          FNodes[E] := tvElements.Items.AddChildObject(N, ElementCaptions[E], Pointer(Ord(E) + 1));
      if G = egPascal then N.Expand(False);
    end;
  finally
    tvElements.Items.EndUpdate;
  end;
end;

{ the element E's values in the controls (the parts it has enabled; Default shows the colour it
  stands for); its node chosen, its group open; the completion list's sample with the list's
  elements; Reveal: the sample scrolled to a place of it when none is in view }
procedure TEditorOptionsFrame.ShowElement(E: TEditorElement; Reveal: Boolean);

  function BoxColor(C: TColor): TColor;
  begin
    if IsDefaultColor(C) then Result := clDefault else Result := C;
  end;

var
  C: TEditorColors;
  Parts: TElementParts;
begin
  FElement := E;
  Parts := ElementParts[E];
  FLoading := True;
  try
    if tvElements.Selected <> FNodes[E] then
    begin
      FNodes[E].Parent.Expand(False);
      tvElements.Selected := FNodes[E];
    end;
    { what Default stands for: the element without its own colours }
    C := FOpts.Colors;
    C[E].Fore := clDefault;
    C[E].Back := clDefault;
    if E = eeScrollBar then
      cbForeground.DefaultColorColor := SciScrollColors(ElementBack(FOpts.Colors, eePlainText), clDefault).Thumb
    else
      cbForeground.DefaultColorColor := ElementFore(C, E);
    cbBackground.DefaultColorColor := ElementBack(C, E);
    cbForeground.Selected := BoxColor(FOpts.Colors[E].Fore);
    cbBackground.Selected := BoxColor(FOpts.Colors[E].Back);
    edForeground.Text := ColorHex(ShownFore);
    edBackground.Text := ColorHex(ElementBack(FOpts.Colors, E));
    chkBold.Checked := FOpts.Colors[E].Bold;
    chkItalic.Checked := FOpts.Colors[E].Italic;
    chkUnderline.Checked := FOpts.Colors[E].Underline;
    EnableParts(Parts);
  finally
    FLoading := False;
  end;
  cbForeground.Invalidate;
  cbBackground.Invalidate;
  { the completion list's sample: while one of the list's elements is shown }
  lbCompletionSample.Visible := ElementGroups[E] = egCodeInsight;
  if lbCompletionSample.Visible then
  begin
    PlaceCompletionSample;
    lbCompletionSample.Invalidate;
  end;
  if Reveal then RevealElement(E);
end;

{ the controls of the parts an element has enabled, the others off (a group: none) }
procedure TEditorOptionsFrame.EnableParts(Parts: TElementParts);
var
  Was: Boolean;
begin
  Was := FLoading;
  FLoading := True;
  try
    cbForeground.Enabled := epFore in Parts;
    edForeground.Enabled := epFore in Parts;
    lblForeground.Enabled := epFore in Parts;
    cbBackground.Enabled := epBack in Parts;
    edBackground.Enabled := epBack in Parts;
    lblBackground.Enabled := epBack in Parts;
    chkBold.Enabled := epStyle in Parts;
    chkItalic.Enabled := epStyle in Parts;
    chkUnderline.Enabled := epStyle in Parts;
    if not (epFore in Parts) then edForeground.Text := '';
    if not (epBack in Parts) then edBackground.Text := '';
  finally
    FLoading := Was;
  end;
end;

{ the colour the element shown has as its text, line or mark: the scroll bars' Default as the
  thumb it makes }
function TEditorOptionsFrame.ShownFore: TColor;
begin
  if (FElement = eeScrollBar) and IsDefaultColor(FOpts.Colors[FElement].Fore) then
    Result := cbForeground.DefaultColorColor
  else
    Result := ElementFore(FOpts.Colors, FElement);
end;

{ an element changed: the theme in use (a built-in one: the user's copy made of it), the
  controls and the sample }
procedure TEditorOptionsFrame.ChangeElement(const V: TEditorColor);
begin
  if ChangeThemeElement(FOpts, FElement, V) then FillThemes;
  ColorsChanged;
end;

{ an element chosen in the tree: its values, the sample scrolled to it; a group has none to edit
  (the keyboard moves on over it, a group closed over the element shown keeps the choice) }
procedure TEditorOptionsFrame.ElementTreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FLoading or (Node = nil) then Exit;
  if Node.Data = nil then EnableParts([])
  else ShowElement(TEditorElement(Integer(Node.Data) - 1), True);
end;

procedure TEditorOptionsFrame.ElementColorSelect(Sender: TObject);
var
  V: TEditorColor;
begin
  if FLoading then Exit;
  V := FOpts.Colors[FElement];
  if Sender = cbForeground then V.Fore := cbForeground.Selected
  else V.Back := cbBackground.Selected;
  ChangeElement(V);
end;

{ a colour typed as #RRGGBB: taken once it is a whole one }
procedure TEditorOptionsFrame.ElementHexChange(Sender: TObject);
var
  V: TEditorColor;
  C: TColor;
begin
  if FLoading or not HexColor(TEdit(Sender).Text, C) then Exit;
  V := FOpts.Colors[FElement];
  { the colour shown already (a system colour as its RGB) changes nothing }
  if Sender = edForeground then
  begin
    if C = ColorToRGB(ShownFore) then Exit;
    V.Fore := C;
  end
  else
  begin
    if C = ColorToRGB(ElementBack(FOpts.Colors, FElement)) then Exit;
    V.Back := C;
  end;
  ChangeElement(V);
  { the caret stays at the end of what is typed }
  TEdit(Sender).SelStart := Length(TEdit(Sender).Text);
end;

procedure TEditorOptionsFrame.ElementStyleClick(Sender: TObject);
var
  V: TEditorColor;
begin
  if FLoading then Exit;
  V := FOpts.Colors[FElement];
  V.Bold := chkBold.Checked;
  V.Italic := chkItalic.Checked;
  V.Underline := chkUnderline.Checked;
  ChangeElement(V);
end;

{ --- Color: the sample --- }

{ the options the sample shows the theme with: the section's, and everything a colour of the
  theme is for in view - every margin, the highlights, the right margin in reach, the tabs }
function TEditorOptionsFrame.SampleOptions: TEditorOptions;
var
  I: Integer;
begin
  Result := FOpts;
  if FontName.Text <> '' then Result.FontName := FontName.Text;
  Result.FontSize := StrToIntDef(FontSize.Text, FOpts.FontSize);
  if (Result.FontSize < 6) or (Result.FontSize > 72) then Result.FontSize := FOpts.FontSize;
  Result.ShowLineNumbers := True;
  Result.VisibleGutter := True;
  Result.ShowFolding := True;
  Result.ShowChangeBars := True;
  Result.ScrollBarMarkers := True;
  Result.ShowRightMargin := True;
  Result.RightMargin := SampleMargin;
  Result.WordWrap := False;
  Result.CursorBeyondEOF := False;
  Result.HighlightCurrentLine := True;
  Result.IndentGuides := True;
  Result.RainbowBrackets := True;
  Result.HighlightBlocks := True;
  Result.HighlightBraces := True;
  Result.HighlightFindMatches := True;
  Result.HighlightIdentifiers := True;
  Result.HighlightOccurrences := True;
  Result.FileTypes := Copy(FOpts.FileTypes, 0, Length(FOpts.FileTypes));
  for I := 0 to High(Result.FileTypes) do
  begin
    Result.FileTypes[I].Highlighter := PascalHighlighter;
    Result.FileTypes[I].UseSyntaxHighlight := True;
    Result.FileTypes[I].ShowTabChar := True;
    Result.FileTypes[I].ShowSpaceChar := False;
  end;
end;

{ The sample's text and its marks, once (EditorOptions are the sample's meanwhile): the change
  bars by an edit before a save point and one after it, the debugger's lines, the highlights that
  follow the caret where they would be, the selection with the caret after it - drawn as while
  the editor has the keyboard }
procedure TEditorOptionsFrame.SetupSample;
var
  Places, Decls: TList;
  Names: TSciNames;
  P, E, N, K, J: Integer;
  W: string;

  { the place of the Nth S on a line (-1: none) }
  function LinePos(Line: Integer; const S: string; Nth: Integer = 1): Integer;
  var
    T: string;
    K, Q, F: Integer;
  begin
    T := FSample.GetLineText(Line);
    Result := -1;
    Q := 0;
    for K := 1 to Nth do
    begin
      F := Pos(S, Copy(T, Q + 1, MaxInt));
      if F = 0 then Exit;
      Q := Q + F;
    end;
    Result := FSample.PosFromLine(Line) + Q - 1;
  end;

  { a line changed: its first character typed again }
  procedure Touch(Line: Integer);
  var
    Q: Integer;
    Ch: Char;
  begin
    Q := FSample.PosFromLine(Line) + FSample.Sci(SCI_GETLINEINDENTATION, Line);
    Ch := FSample.CharAt(Q);
    FSample.DeleteRange(Q, 1);
    FSample.InsertText(Q, Ch);
  end;

begin
  FSample.Sample := True;
  FSample.OnSampleClick := SampleClick;
  FSample.SetLanguageFromFile('Sample.pas');
  FSample.LoadFromString(SampleText);
  Touch(SampleSavedLine);
  FSample.SetSavePoint;
  Touch(SampleModifiedLine);
  FSample.MarkerAdd(SampleBreakLine, MK_BREAK_LINE);
  FSample.MarkerAdd(SampleBreakLine, MK_BREAK);
  FSample.MarkerAdd(SampleDisabledLine, MK_BREAK_DISABLED_LINE);
  FSample.MarkerAdd(SampleDisabledLine, MK_BREAK_DISABLED);
  FSample.MarkerAdd(SampleExecLine, MK_EXEC_LINE);
  FSample.MarkerAdd(SampleExecLine, MK_EXEC);
  FSample.MarkerAdd(SampleErrorLine, MK_ERROR_LINE);
  FSample.MarkerAdd(SampleInvalidLine, MK_BREAK_INVALID_LINE);
  FSample.MarkerAdd(SampleInvalidLine, MK_BREAK_INVALID);
  FSample.ReadOnly := True;
  FSample.MarkMatches('IntToStr', False, True, False);
  { the call's brackets matched, the stray one of the error line }
  P := LinePos(SampleCallLine, '(');
  FSample.FillIndicator(IND_BRACE, P, 1);
  FSample.FillIndicator(IND_BRACE, LinePos(SampleCallLine, ')'), 1);
  FSample.FillIndicator(IND_BRACEBAD, LinePos(SampleErrorLine, ')'), 1);
  { the for loop's begin and end, the guide of its block }
  P := LinePos(SampleBeginLine, 'begin');
  E := LinePos(SampleEndLine, 'end');
  FSample.FillIndicator(IND_BLOCKMATCH, P, 5);
  FSample.FillIndicator(IND_BLOCKMATCH, E, 3);
  FSample.Sci(SCI_SETHIGHLIGHTGUIDE, FSample.Sci(SCI_GETLINEINDENTATION, SampleBeginLine));
  FSample.Sci(SCI_BRACEHIGHLIGHT, P, E);
  { the identifier I: its declaration and its places }
  Places := TList.Create;
  Decls := TList.Create;
  try
    P := LinePos(SampleDeclLine, ' I,') + 1;
    Places.Add(Pointer(P));
    Decls.Add(Pointer(P));
    Places.Add(Pointer(LinePos(SampleForLine, ' I ') + 1));
    Places.Add(Pointer(LinePos(SampleRainbowLine, '[I]') + 1));
    FSample.ShowIdentifiers(Places, Decls, 1);
  finally
    Decls.Free;
    Places.Free;
  end;
  { a hot link }
  P := LinePos(SampleHeadLine, 'TObject');
  FSample.FillIndicator(IND_LINK, P, 7);
  FSample.FillIndicator(IND_LINKTEXT, P, 7);
  { the selected word Number and its other places }
  FSample.FillIndicator(IND_OCCURRENCE, LinePos(SampleDeclLine, 'Number'), 6);
  FSample.FillIndicator(IND_OCCURRENCE, LinePos(SampleCallLine, 'Number', 2), 6);
  FSample.FillIndicator(IND_OCCURRENCE, LinePos(SampleForLine, 'Number'), 6);
  FSample.FillIndicator(IND_OCCURRENCE, LinePos(SampleAsmLine, 'Number'), 6);
  { the names by kind (SampleNames; the others Identifier's) }
  N := FSample.NamesBetween(0, FSample.TextLength, Names);
  for K := 0 to N - 1 do
  begin
    W := FSample.GetRange(Names[K].Start, Names[K].Start + Names[K].Len);
    for J := 0 to High(SampleNames) do
      if SameText(SampleNames[J].Name, W) then Names[K].Element := SampleNames[J].E;
  end;
  FSample.ShowNameKinds(0, FSample.TextLength, Names, N);
  P := LinePos(SampleSelLine, 'Number');
  FSample.SetSel(P, P + 6);
  FSample.Sci(SCI_SETCARETPERIOD, 0);
  FSample.Sci(SCI_SETFOCUS, 1);
  { what an editor makes when idle - the block structure with its rainbow, the scroll bar's
    markers - under the sample's options: a sample gets none of it when idle }
  FSample.ApplyOptions;
  FSampleReady := True;
end;

{ The sample shows the section's values: they are the editor options while it applies them }
procedure TEditorOptionsFrame.UpdateSample;
var
  Saved: TEditorOptions;
begin
  if FSample = nil then Exit;
  Saved := EditorOptions;
  try
    EditorOptions := SampleOptions;
    if FSampleReady then FSample.ApplyOptions else SetupSample;
  finally
    EditorOptions := Saved;
  end;
end;

{ the completion list's sample in the sample's lower right corner, in the UI font as the list,
  its rows' height the list's }
procedure TEditorOptionsFrame.PlaceCompletionSample;
var
  R: TRect;
  H, W: Integer;
begin
  UIApplyFont(lbCompletionSample.Font);
  FSampleBold.Assign(lbCompletionSample.Font);
  FSampleBold.Style := [fsBold];
  lbCompletionSample.Canvas.Font := lbCompletionSample.Font;
  lbCompletionSample.ItemHeight := lbCompletionSample.Canvas.TextHeight('Wg') + 3;
  { every row in view, with the list's frame: no scroll bar }
  lbCompletionSample.HandleNeeded;
  H := lbCompletionSample.ItemHeight * lbCompletionSample.Items.Count +
    lbCompletionSample.Height - lbCompletionSample.ClientHeight;
  R := FSample.Window.BoundsRect;
  W := (R.Right - R.Left) * 3 div 4;
  lbCompletionSample.SetBounds(R.Right - W - 24, R.Bottom - H - 12, W, H);
end;

procedure TEditorOptionsFrame.CompletionSampleDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TEditorColors;
begin
  if (Index < 0) or (Index > High(CompletionRows)) then Exit;
  C := FOpts.Colors;
  with CompletionRows[Index] do
    DrawCompletionRow(lbCompletionSample.Canvas.Handle, Rect, Kind, Name, Rest, ElementFore(C, E),
      ElementFore(C, eeCompletion), ElementBack(C, eeCompletion), lbCompletionSample.Font.Handle,
      FSampleBold.Handle, KindColWidth);
end;

{ Display: the versions kept per file count only while the files' history is kept }
procedure TEditorOptionsFrame.chkKeepHistoryClick(Sender: TObject);
begin
  lbHistoryLimit.Enabled := chkKeepHistory.Checked;
  cbHistoryLimit.Enabled := chkKeepHistory.Checked;
end;

{ a row of the list's sample chooses its kind's element (the list's ground: Completion list,
  chosen in the tree, which keeps the keyboard); the list keeps no row chosen, so that a click on
  the same row chooses it again }
procedure TEditorOptionsFrame.CompletionSampleClick(Sender: TObject);
var
  I: Integer;
begin
  I := lbCompletionSample.ItemIndex;
  lbCompletionSample.ItemIndex := -1;
  if (I < 0) or (I > High(CompletionRows)) then Exit;
  ShowElement(CompletionRows[I].E);
  if tvElements.CanFocus then tvElements.SetFocus;
end;

{ a press on the sample chooses the element there (Delphi's); the sample stays where it is }
procedure TEditorOptionsFrame.SampleClick(Sender: TObject; Pos, Line, Margin: Integer);
begin
  ShowElement(ElementAt(Pos, Line, Margin));
  if tvElements.CanFocus then tvElements.SetFocus;
end;

{ the sample scrolled to the first place of E when none of its places is in view: the place
  ElementAt finds it at - the change bars by the history margin, the caret's line, the guide of
  the block -; the margins, the right margin, the scroll bars and the completion list are always
  in view }
procedure TEditorOptionsFrame.RevealElement(E: TEditorElement);
var
  Top, Bottom, Found, L, P: Integer;

  { a place of E on line L: in view - nothing to do -, else the first one is kept }
  function Place(Line, Pos: Integer): Boolean;
  begin
    Result := (Line >= Top) and (Line < Bottom);
    if not Result and (Found < 0) then Found := Pos;
  end;

begin
  if (FSample = nil) or not FSampleReady then Exit;
  Top := FSample.Sci(SCI_GETFIRSTVISIBLELINE);
  Bottom := Top + FSample.Sci(SCI_LINESONSCREEN);
  Found := -1;
  case E of
    eeModifiedLine, eeSavedLine:
      for L := 0 to FSample.LineCount - 1 do
        if (ElementAt(-1, L, MARGIN_HISTORY) = E) and Place(L, FSample.PosFromLine(L)) then Exit;
    eeCurrentLine, eeCaret:
      if Place(FSample.CaretLine, FSample.CaretPos) then Exit;
    eeIndentGuide:
      if Place(SampleBeginLine + 1, FSample.PosFromLine(SampleBeginLine + 1)) then Exit;
    eeGutter, eeRightMargin, eeFolding, eeScrollBar, eeCompletion..eeCompAbstract:
      Exit;
  else
    for P := 0 to FSample.TextLength - 1 do
    begin
      L := FSample.LineFromPos(P);
      if (ElementAt(P, L, -1) = E) and Place(L, P) then Exit;
    end;
  end;
  if Found >= 0 then FSample.Sci(SCI_SCROLLRANGE, Found, Found);
end;

{ the element at a place of the sample: a margin's, a line's colour, a highlight's, the
  selection's, else the token's }
function TEditorOptionsFrame.ElementAt(Pos, Line, Margin: Integer): TEditorElement;
const
  HistoryMask = (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN) or (1 shl SC_MARKNUM_HISTORY_SAVED) or
    (1 shl SC_MARKNUM_HISTORY_MODIFIED) or (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED);
var
  M, K: Integer;
  E: TEditorElement;

  function Ind(I: Integer): Boolean;
  begin
    Result := (Pos >= 0) and (FSample.Sci(SCI_INDICATORVALUEAT, I, Pos) <> 0);
  end;

begin
  case Margin of
    SampleScrollBar: begin Result := eeScrollBar; Exit; end;
    MARGIN_NUMBERS, MARGIN_SYMBOLS: begin Result := eeGutter; Exit; end;
    MARGIN_FOLD: begin Result := eeFolding; Exit; end;
    MARGIN_HISTORY:
      begin
        M := FSample.MarkerGet(Line) and HistoryMask;
        if M and (1 shl SC_MARKNUM_HISTORY_SAVED) <> 0 then Result := eeSavedLine
        else if M <> 0 then Result := eeModifiedLine
        else Result := eeGutter;
        Exit;
      end;
  end;
  M := FSample.MarkerGet(Line);
  if M and (1 shl MK_EXEC_LINE) <> 0 then Result := eeExecutionPoint
  else if M and (1 shl MK_ERROR_LINE) <> 0 then
  begin
    if Ind(IND_BRACEBAD) then Result := eeBraceBad else Result := eeErrorLine;
  end
  else if M and (1 shl MK_BREAK_LINE) <> 0 then Result := eeEnabledBreak
  else if M and (1 shl MK_BREAK_DISABLED_LINE) <> 0 then Result := eeDisabledBreak
  else if M and (1 shl MK_BREAK_INVALID_LINE) <> 0 then Result := eeInvalidBreak
  else if Pos < 0 then
  begin
    { beyond a line's end: its ground }
    if Line = FSample.CaretLine then Result := eeCurrentLine else Result := eePlainText;
  end
  else if (Pos >= FSample.SelStart) and (Pos < FSample.SelEnd) then Result := eeSelection
  else if Ind(IND_FIND) then Result := eeSearchMatch
  else if Ind(IND_BRACEBAD) then Result := eeBraceBad
  else if Ind(IND_BRACE) then Result := eeBraceMatch
  else if Ind(IND_BLOCKMATCH) then Result := eeWordMatch
  else if Ind(IND_IDENTDECL) then Result := eeIdentDecl
  else if Ind(IND_IDENT) then Result := eeIdentMatch
  else if Ind(IND_OCCURRENCE) then Result := eeOccurrence
  else if Ind(IND_LINK) then Result := eeHotLink
  else if FSample.CharAt(Pos) = #9 then Result := eeBlanks
  else
  begin
    Result := eePlainText;
    for K := 0 to RainbowColours - 1 do
      if Ind(IND_RAINBOW + K) then
      begin
        Result := TEditorElement(Ord(eeRainbow1) + K);
        Exit;
      end;
    for E := eeType to eeUnitName do
      if Ind(IND_NAMES + Ord(E) - Ord(eeType)) then
      begin
        Result := E;
        Exit;
      end;
    case FSample.StyleAt(Pos) of
      SCE_PAS_COMMENT, SCE_PAS_COMMENT2, SCE_PAS_COMMENTLINE: Result := eeComment;
      SCE_PAS_PREPROCESSOR, SCE_PAS_PREPROCESSOR2: Result := eeDirective;
      SCE_PAS_NUMBER: Result := eeNumber;
      SCE_PAS_HEXNUMBER: Result := eeHex;
      SCE_PAS_WORD: Result := eeReservedWord;
      SCE_PAS_STRING, SCE_PAS_STRINGEOL, SCE_PAS_MULTILINESTRING: Result := eeString;
      SCE_PAS_CHARACTER: Result := eeCharacter;
      SCE_PAS_OPERATOR: Result := eeSymbol;
      SCE_PAS_ASM: Result := eeAssembler;
      SCE_PAS_IDENTIFIER: Result := eeIdentifier;
    end;
  end;
end;

end.
