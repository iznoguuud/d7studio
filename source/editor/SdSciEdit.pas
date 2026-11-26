{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSciEdit;

{ D7 Studio - VCL wrapper around the Scintilla editing component (Scintilla.dll + Lexilla.dll).
  The control subclasses the "Scintilla" window class, so the VCL control handle IS the
  Scintilla window and all messages flow through the normal VCL WndProc.

  Appearance: every colour is the editor theme's (Editor Options |
  Color, SdEditorThemes). Pascal sources and form text are highlighted; other files are plain
  text, unless an expert's highlighter styles them. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, SdSciDefs, SdSciLexDefs,
  SdEncoding, SdFileNames, SdEditorThemes, SdEditorOptions, SdKeymaps, SdSciScroll, SdPasBlocks;

const
  WM_SCITRIMUNDO = WM_USER + 401;    // Editor Options | Undo limit: the history is trimmed after the edit
  { margins }
  MARGIN_NUMBERS = 0;
  MARGIN_SYMBOLS = 1;
  MARGIN_HISTORY = 2;
  MARGIN_FOLD = 3;
  { symbol markers (higher numbers are drawn on top) }
  MK_BOOKMARK0 = 0;          // 0..9
  MK_CODEDOT = 10;
  MK_BREAK_INVALID = 11;
  MK_BREAK_DISABLED = 12;
  MK_BREAK = 13;
  MK_EXEC = 15;
  MK_SYMBOL_MASK = $0000FFFF;
  { line background markers (the highest one present wins) }
  MK_BREAK_INVALID_LINE = 16;
  MK_BREAK_DISABLED_LINE = 17;
  MK_BREAK_LINE = 18;
  MK_ERROR_LINE = 19;
  MK_EXEC_LINE = 20;
  MK_LINE_MASK = (1 shl 16) or (1 shl 17) or (1 shl 18) or (1 shl 19) or (1 shl 20);
  { indicators. Of those that colour the text (INDIC_TEXTFORE) the one with the higher number wins:
    the names by kind lie below the line colours, the link and the find matches }
  IND_NAMES = 0;             // 0 .. 8: the names by kind, Type .. Unit (ShowNameKinds); Pascal's lexer uses none
  IND_LINK = 9;
  IND_FIND = 10;
  IND_ERROR = 11;
  IND_LINEFORE = 12;         // the text colour of the execution point's line (Color page)
  IND_LINKTEXT = 13;         // blue text of the Ctrl+hover link (IND_LINK is its underline)
  IND_LINEFORE_BREAK = 14;   // ... of an enabled, a disabled, an invalid breakpoint's line, the
  IND_LINEFORE_DISABLED = 15;// error line's
  IND_LINEFORE_INVALID = 16;
  IND_LINEFORE_ERROR = 17;
  IND_BLOCK = 18;            // the block kept by Persistent blocks (WordStar's Ctrl+K B / K)
  IND_IDENT = 19;            // the places of the symbol at the caret (Identifier matching)
  IND_IDENTDECL = 20;        // ... its declarations
  IND_BLOCKMATCH = 21;       // the words of the block at the caret: begin ... end (Begin/end matching)
  IND_BRACE = 22;            // the bracket at the caret and its partner
  IND_BRACEBAD = 23;         // ... a bracket without partner
  IND_RAINBOW = 24;          // 24 .. 26: the brackets by their depth (Rainbow brackets)
  IND_GUIDE = 27;            // hidden: the ends of the block whose indentation guide is highlighted
  IND_AUTOCLOSE = 28;        // hidden: a closing character put in by Auto-close pairs
  IND_FINDTEXT = 29;         // the text colour of the find matches (Search match: IND_FIND is its ground)
  IND_OCCURRENCE = 30;       // the selected word's other places (Word occurrences)
  { a comparison of two texts (DiffView, the History tab): the grounds of its lines, the first line
    of a change (no mark: where Previous / Next Change go), the changed words - numbers a comparison
    shows no bookmark, breakpoint or name by kind with }
  MK_DIFF_REMOVED = 0;
  MK_DIFF_ADDED = 1;
  MK_DIFF_FILLER = 2;        // side by side: no line here, the other side has lines
  MK_DIFF_FOLD = 3;          // unchanged lines folded away: its note at the line's end says how many
  MK_DIFF_CHANGE = 4;
  IND_DIFF_REMOVED = 0;
  IND_DIFF_ADDED = 1;
  { ... the styles of its margin text (SetDiffMargin: a style per character) and of a fold's note,
    above every lexer's }
  STYLE_DIFF_NUMBERS = 200;
  STYLE_DIFF_REMOVED = 201;  // a removed line's numbers, on its ground
  STYLE_DIFF_ADDED = 202;
  STYLE_DIFF_REMOVED_SIGN = 203;   // ... its sign
  STYLE_DIFF_ADDED_SIGN = 204;
  STYLE_DIFF_NOTE = 205;
  RainbowColours = 3;
  SampleScrollBar = -2;      // TSciSampleClickEvent's Margin of a scroll bar

type
  PSCNotification = ^TSCNotification;
  TSCNotification = record
    hwndFrom: HWND;
    idFrom: Cardinal;
    code: Cardinal;
    position: Integer;
    ch: Integer;
    modifiers: Integer;
    modificationType: Integer;
    text: PAnsiChar;
    length: Integer;
    linesAdded: Integer;
    message: Integer;
    wParam: Cardinal;
    lParam: Integer;
    line: Integer;
    foldLevelNow: Integer;
    foldLevelPrev: Integer;
    margin: Integer;
    listType: Integer;
    x: Integer;
    y: Integer;
    token: Integer;
    annotationLinesAdded: Integer;
    updated: Integer;
    listCompletionMethod: Integer;
    characterSource: Integer;
  end;

  TSciDirectFunc = function(Ptr: Pointer; Msg: Cardinal; W: Cardinal; L: Integer): Integer; cdecl;

  { slNone: plain text (a file no language claims); slExpert: the lines are styled by an
    expert's highlighter of the file's source file type (TSciTokenizer, SciTokenizerFor); the
    others a lexer of Lexilla's (SciLanguages in the implementation: the lexer, the extensions,
    the words, the line comment). Code insight, the block structure and smart indent are
    Pascal's only; the others are highlighted and folded. }
  TSciLanguage = (slNone, slPascal, slDfm, slExpert, slCpp, slCSharp, slResource, slIdl, slXml,
    slHtml, slIni, slSql, slBatch, slMake);

  { a syntax highlighter of the Open Tools API as the editor calls it (SdOtaHighlight): one line
    at a time - its bytes without the line break, at most 1024 of them -, and the class the line
    before it ended in (0 for the first line). Tokenize gives each byte a code: ToolsAPI's
    atWhiteSpace .. atScripts, the elements of the Color page; LineClass the class the line ends
    in. Neither raises. }
  TSciTokenizer = class
  public
    procedure Tokenize(StartClass: Byte; Line: PChar; Len: Word; Codes: PByte); virtual; abstract;
    function LineClass(StartClass: Byte; Line: PChar; Len: Word): Byte; virtual; abstract;
  end;

  TSciCharEvent = procedure(Sender: TObject; Ch: Integer) of object;
  TSciMarginClickEvent = procedure(Sender: TObject; Margin, Line: Integer; Shift: TShiftState) of object;
  TSciDwellEvent = procedure(Sender: TObject; Position, X, Y: Integer) of object;
  TSciModifiedEvent = procedure(Sender: TObject; ModType, Position, Len, LinesAdded: Integer) of object;
  { a command of the key mapping that is not the editor's (bookmarks, the IDE's menu commands) }
  TSciCommandEvent = procedure(Sender: TObject; Cmd: TEdCmd; Arg: Integer) of object;
  TSciUpdateUIEvent = procedure(Sender: TObject; Updated: Integer) of object;
  TSciPosEvent = procedure(Sender: TObject; Position: Integer) of object;
  { a press of the mouse on a sample (TSciEdit.Sample): Pos the character under it (-1: none),
    Line the line, Margin the margin (MARGIN_NUMBERS ...; -1 the text, SampleScrollBar a scroll
    bar) }
  TSciSampleClickEvent = procedure(Sender: TObject; Pos, Line, Margin: Integer) of object;
  { a name of the text (an identifier by the lexer's styles) and the element of its kind -
    eeType .. eeUnitName; any other element: no kind (Identifier's colour) }
  TSciName = record
    Start, Len: Integer;
    Element: TEditorElement;
  end;
  TSciNames = array of TSciName;
  { the folding commands }
  TSciFoldAction = (sfFoldAll, sfUnfoldAll, sfFold, sfUnfold, sfToggle, sfFoldMethods);

  { the kinds of the buffer's block, in the order of ToolsAPI's TOTABlockType (the Open Tools API
    converts with Ord) }
  TSciBlockMode = (sbInclusive, sbLine, sbColumn, sbNonInclusive);

  { the buffer's block as the Open Tools API sees it - Delphi 7's editor keeps one per buffer.
    sbInclusive, sbLine, sbNonInclusive: A and B are its ends (offsets, -1: none), in no order; an
    inclusive block takes the character at its larger end too, a line block the whole lines of its
    ends. sbColumn: Rows' Left / Top are its first corner, Right / Bottom its second (display
    columns and lines, 0-based, -1: none), in no order; the rectangle lies between the two
    columns, the larger one its edge (outside it, as in Scintilla's rectangular selection). }
  TSciBlock = record
    Mode: TSciBlockMode;
    A, B: Integer;
    Rows: TRect;
    Hidden: Boolean;
  end;

  { the main selection as the block calls left it: Scintilla's selection mode, the anchor and the
    caret (a rectangle's own) with their virtual space }
  TSciSelImage = record
    Mode, Anchor, Caret, AnchorV, CaretV: Integer;
  end;


  TSciWindow = class;

  { an editor's view while no window shows its document: the selections (Scintilla's serialized
    form), the first document line in view, the horizontal offset and scroll width, the folded
    lines (their fold headers) }
  TSciViewState = record
    Saved: Boolean;
    Sel: string;
    TopLine, XOffset, ScrollWidth: Integer;
    Folds: array of Integer;
  end;

  { The editor of a text: its Scintilla document, what D7 Studio keeps for it and every command on
    it. It has no window of its own: a TSciWindow shows it - its home window (a dialog's, a view's)
    or the one window of the file area, which shows the file of the page that is shown -, and
    while no window shows it, its document is worked on in a hidden window, the worker. Scintilla
    keeps the text, the undo history, the styles, the markers and the indicators per document,
    the view (the selections, the scrolling, the folded lines) per window: the view is saved when
    the document leaves a window and given back when it comes into one (TSciViewState). }
  TSciEdit = class(TComponent)
  private
    FWindow: TSciWindow;         // the window the document is in (nil: none)
    FHome: TSciWindow;           // its own window (Sci then makes that window); nil: the worker's
    FDoc: Integer;               // the Scintilla document (0: not made yet)
    FFresh: Boolean;             // ... made, Scintilla's settings of a document not applied yet
    FLexerPending: Boolean;      // the language changed while no window had the document
    FOptionsPending: Boolean;    // ... the options did (ApplyOptions)
    FView: TSciViewState;        // the view while no window has the document
    FModifiedCache: Boolean;     // Modified and ReadOnly while no window has the document (it
    FReadOnlyCache: Boolean;     // cannot change then)
    FText: string;               // the text as GetText read it last ...
    FTextValid: Boolean;         // ... and the document has not changed since
    FDirectFn: TSciDirectFunc;   // the window's
    FDirectPtr: Pointer;
    FLanguage: TSciLanguage;
    FOnCharAdded: TSciCharEvent;
    FOnMarginClick: TSciMarginClickEvent;
    FOnDwellStart: TSciDwellEvent;
    FOnDwellEnd: TNotifyEvent;
    FOnModified: TSciModifiedEvent;
    FOnUpdateUI: TSciUpdateUIEvent;
    FOnSavePointChange: TNotifyEvent;
    FOnCtrlClick: TSciPosEvent;
    FOnFocusChange: TNotifyEvent;
    FOnKeyDown, FOnKeyUp: TKeyEvent;
    FOnKeyPress: TKeyPressEvent;
    FOnMouseDown, FOnMouseUp: TMouseEvent;
    FOnDblClick: TNotifyEvent;
    FLinkStart, FLinkEnd: Integer;
    FHandCursor: Boolean;        // the last WM_SETCURSOR chose the link hand
    FLastOccurrenceWord: string;
    FEolMode: Integer;
    FHasTabs: Boolean;
    FEncoding: TSdEncoding;      // the file's encoding (SdEncoding): how the bytes are shown and written
    FLineForeDirty: Boolean;
    FLineMarks: Boolean;         // a line may carry a line marker (MK_LINE_MASK): edits repaint their text colour
    FTypeFile: string;          // the file name its source file type comes from (Source Options)
    FFileType: TEditorFileType;
    FSwallowTab: Boolean;        // a smart tab was done: the WM_CHAR of the key goes
    FByFile: Boolean;            // the language follows the file (SetLanguageFromFile), not SetLanguage
    FTrimPending: Boolean;       // WM_SCITRIMUNDO is on its way
    FKeyPrefix: TShortCut;       // the first key of a chord of the key mapping (0: none)
    FBlockA, FBlockB: Integer;   // the block (Ctrl+K B / K; Persistent blocks keeps it): -1 none
    FBlockShown: Boolean;        // ... drawn (IND_BLOCK): Persistent blocks, not hidden (Ctrl+K H)
    FBlockMode: TSciBlockMode;   // ... its kind (the Open Tools API's; the block commands make sbNonInclusive)
    FBlockRows: TRect;           // ... a column block's corners (TSciBlock.Rows)
    FBlockHidden: Boolean;       // ... hidden (IOTAEditBlock.Visible; with Persistent blocks Ctrl+K H too)
    FBlockShownLeft: Boolean;    // ... FBlockShown as the block calls left it (Ctrl+K H changes it)
    FBlockPaint: Boolean;        // ... an edit moved it while drawn: drawn again at the next update
    FBlockSel: TSciSelImage;     // the main selection as the block calls left it (Caret -1: none yet)
    { the writes of the Open Tools API's undoable writers (WriterStep): the undo history's current
      action after the last one (-1: none), the caret then, the undo steps of the writes in a row that
      end there, and Delphi 7's step after them that takes back no text, not taken yet }
    FWriterCur: Integer;
    FWriterCaret: Integer;
    FWriterSteps: Integer;
    FWriterPending: Boolean;
    FOnCommand: TSciCommandEvent;
    FBlocks: TPasBlocks;         // the Pascal text's block structure (nil: none yet, or no Pascal)
    FBlocksStale: Boolean;       // ... the text changed since it was made
    FFindText: string;           // Find matches: what the last search looked for ('' none)
    FFindCase, FFindWord, FFindRegExp, FFindStale: Boolean;
    FMarksDirty: Boolean;        // the scroll bar's markers are gathered again at its next paint
    FMarks: TSciScrollMarks;     // ... gathered: their Pos a document line
    FMarkCount: Integer;
    FSelHistory: array of TPoint; // Expand Selection: the selections before (X anchor, Y caret)
    FExpanded: TPoint;           // ... the selection it made last
    FCaretColumn: Integer;       // Add Caret Above / Below: the column of the first caret
    FAddedCaret: Integer;        // ... where it put the last one (-1 none)
    FPendingOpen, FPendingClose: Char;   // Auto-close pairs: the partner of the character being typed
    FAutoCloseLine: Integer;     // ... the line of the partners put in (-1 none): forgotten when the caret leaves it
    FSwallowBack: Boolean;       // a Backspace took a pair: its WM_CHAR goes
    FOnZoom: TNotifyEvent;
    FSample: Boolean;            // a sample of the colours (Sample)
    FOnSampleClick: TSciSampleClickEvent;
    FOnViewApplied: TNotifyEvent;
    FDiffView: Boolean;          // a comparison of two texts (DiffView)
    FDiffMarginChars: Integer;   // ... the characters of its margin text
    { the window's side (TSciWindow): the document in a window and out of it }
    function Attach: Boolean;
    procedure Attached;
    procedure Detached(KeepView: Boolean);
    procedure SaveView;
    procedure RestoreView;
    function ViewKey: string;
    procedure ApplyView;
    function Bars: TSciScrollBars;
    function SciStr(Msg: Cardinal; W: Cardinal): string;
    { ... and what the window gets: its messages for the editor shown }
    procedure IdleWork;
    procedure TrimUndo;
    function CharArrives(Ch: Word): Boolean;
    procedure KeyArrives(Key: Word);
    procedure KeyDown(var Key: Word; Shift: TShiftState);
    procedure KeyPress(var Key: Char);
    function MouseDownArrives(Keys, X, Y: Integer): Boolean;
    procedure MouseMoved(Keys, X, Y: Integer);
    function LinkCursor(HitTest: Integer): Boolean;
    procedure Notify(N: PSCNotification);
    procedure ScheduleIdle;
    procedure RebuildBlocks;
    procedure PaintRainbow;
    procedure UpdateMatching;
    procedure PaintMatches;
    procedure SampleClicked(X, Y: Integer);
    procedure GetMarks(var Marks: TSciScrollMarks; out Count, Caret: Integer);
    procedure GatherMarks;
    procedure MarkerChanged(Marker: Integer);
    function AutoCloseChar(var Ch: Char): Boolean;
    function AutoCloseBack: Boolean;
    procedure TypedLineEnd;
    procedure TypedWordEnd(EndPos: Integer);
    procedure InsertCloser(Bl: TPasBlocks; Opener, Line: Integer);
    function LineIndent(Line: Integer): Integer;
    function LineBlank(Line: Integer): Boolean;
    function PrevTextLine(Line: Integer): Integer;
    function EolText: string;
    function TextAreaLeft: Integer;
    function LinkWordAt(P: Integer; out S, E: Integer): Boolean;
    procedure PlaceCell(P, V: Integer; out Line, Col: Integer);
    function LastCodeWord(Line: Integer; out WordStart: Integer): string;
    function NextCodeWord(Pos: Integer): string;
    function NextIndicatorRun(Ind: Integer; var P, E: Integer): Boolean;
    function InCommentOrString(Pos: Integer): Boolean;
    procedure SearchFlagsForWords;
    procedure BarInfo(Bar: TSciBar; var Info: TSciScrollInfo);
    procedure BarScroll(Bar: TSciBar; Action: TSciScrollAction; Pos: Integer);
    function SmartTab: Boolean;
    procedure UndoBoundary;
    procedure PaintBlock;
    procedure SetBlock(A, B: Integer);
    procedure KeepBlock;
    procedure AdjustBlock(Pos, Len: Integer; Inserted: Boolean);
    { the buffer's block of the Open Tools API (see its section) }
    function SelImage: TSciSelImage;
    procedure AdjustBlockImage(Pos, Len: Integer; Inserted: Boolean);
    procedure SyncBlock;
    procedure AdoptSelection(const Img: TSciSelImage);
    procedure NoteUserBlock;
    procedure PublishBlock;
    procedure PaintBlockShape;
    procedure CollapseBlock;
    procedure CollapseBlockAt(P, V: Integer);
    function BlockValid: Boolean;
    function BlockIsMarked: Boolean;
    function CaretAtBlock: Boolean;
    function CaretVirt: Integer;
    procedure SetCaretAt(P, V: Integer);
    procedure PlaceCaret(P, V: Integer);
    function BlockSpan(out S, E: Integer): Boolean;
    function BlockRowRange(out First, Last: Integer): Boolean;
    function BlockRow(Line: Integer; out S, E: Integer): Boolean;
    procedure CaseRange(S, E, Kind: Integer);
    procedure RangeCase(A, B: Integer; Upper: Boolean);
    procedure IndentLines(A, B, Delta: Integer);
    function SearchPattern(const Text: string; RegExp: Boolean): string;
    function SearchSpan(const S: string; From, Bound, Skip: Integer): Integer;
    procedure UpdateOccurrences;
    procedure ClearLink;
    procedure ShowLink(S, E: Integer);
    procedure LinkAtPoint(X, Y: Integer);
    procedure RefreshCursor;
    procedure DoAutoIndent;
    function GetModified: Boolean;
    function GetReadOnly: Boolean;
    procedure SetReadOnly(Value: Boolean);
    procedure SetupLexer;
    procedure LanguageChanged;
    function FileLanguage: TSciLanguage;
    procedure StyleNeeded(EndPos: Integer);
    procedure KeyDispatched(Key: Word; Shift: TShiftState; Handled: Boolean);
    procedure ApplyCodePage;
    procedure PutText(const S: string);
    procedure LoadFile(const FileName: string; Detect: Boolean; E: TSdEncoding);
    procedure SetupMargins;
    procedure SetupLineNumbers(Force: Boolean);
    procedure SetupMarkers;
    procedure SetupDiffMargins;
    procedure DiffStyle(Style: Integer; Fore, Back: TColor; Italic: Boolean = False);
    procedure SetDiffView(Value: Boolean);
    procedure SetDiffMarginChars(Value: Integer);
    procedure StyleSet(Style: Integer; Fore, Back: TColor; Bold: Boolean = False; Italic: Boolean = False;
      Underline: Boolean = False);
    procedure SetProp(const Key, Value: string);
    procedure DefineImageMarker(Marker: Integer; const RGBA: string);
    function ValidLine(Line: Integer): Integer;
    procedure GotoLinePos(Line, P: Integer; CenterView: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function LinkRange: string;           // 'start-end' of the Ctrl+hover link, '' when none (tests)
    function ScrollPos: TPoint;           // X: the horizontal offset in pixels, Y: the first line in view (display line)
    { raw access. Ready: Scintilla can be used (its library is there); the document comes into a
      window with the first message (Sci) }
    function Ready: Boolean;
    function Sci(Msg: Cardinal; W: Cardinal = 0; L: Integer = 0): Integer;
    function SciS(Msg: Cardinal; W: Cardinal; const S: string): Integer;
    { the window that shows the editor (nil: none - the worker's does not count): its keyboard
      focus, its place on the screen }
    function Shown: Boolean;
    function Focused: Boolean;
    function CanFocus: Boolean;
    procedure SetFocus;
    function Handle: HWND;                // the window's (0: none)
    function ClientToScreen(const P: TPoint): TPoint;
    function ClientWidth: Integer;
    procedure Invalidate;
    property Window: TSciWindow read FWindow;
    { text }
    function GetText: string;
    procedure SetText(const S: string);
    function TextLength: Integer;
    function LineCount: Integer;
    function GetLineText(Line: Integer): string;
    function GetRange(StartPos, EndPos: Integer): string;
    function CharAt(Pos: Integer): Char;
    function StyleAt(Pos: Integer): Integer;
    function CaretPos: Integer;
    function CaretLine: Integer;
    function CaretCol: Integer;
    function SelStart: Integer;
    function SelEnd: Integer;
    function SelText: string;
    procedure SetSel(AnchorPos, CaretPosition: Integer);
    procedure ReplaceSel(const S: string);
    procedure InsertText(Pos: Integer; const S: string);
    procedure DeleteRange(Pos, Len: Integer);
    function PosFromLine(Line: Integer): Integer;
    function LineFromPos(Pos: Integer): Integer;
    function LineEndPos(Line: Integer): Integer;
    function PointFromPos(Pos: Integer): TPoint;
    function PosFromPoint(X, Y: Integer): Integer;       // -1 when not over text
    function TextHeight: Integer;
    function WordAt(Pos: Integer; out StartPos, EndPos: Integer): string;
    { the designator whose last name is the word at Pos, as the debugger evaluates it: the word
      with the names before it on its line, joined by '.', '^' and '[...]' (P^.Field,
      Items[I].Name). Hover - for the mouse's hint, whose evaluation makes no calls: '(...)' too
      (TFoo(Sender).Caption, but also a call), and Pos on a '^' ends the designator (P^, the
      record). '' where there is none }
    function DesignatorAt(Pos: Integer; Hover: Boolean; out StartPos, EndPos: Integer): string;
    function IsIdentChar(C: Char): Boolean;
    procedure GotoPos(Pos: Integer);
    { Col: a display column (tabs to their stops, a character one column) - what the user sees }
    procedure GotoLineCol(Line, Col: Integer; CenterView: Boolean = True);   // 0-based
    procedure GotoLineColVirtual(Line, Col: Integer);                        // 0-based, may end past the line end
    { ByteCol: the bytes of the line before the place (0-based) - the column of the code insight
      lexer and parser (SdPasLex: its column - 1), right also on lines with tabs and characters of
      several bytes }
    procedure GotoLineByte(Line, ByteCol: Integer; CenterView: Boolean = True);
    procedure BeginUndo;
    procedure EndUndo;
    { an undoable writer of the Open Tools API wrote (an undo step of its own): as in Delphi 7's editor
      the next Undo takes back no text, and writes in a row - nothing else changed the text or its
      undo history, the caret did not move (Before*: the history's current action and the caret
      before the write) - are taken back together, with Group undo }
    procedure WriterStep(BeforeCur, BeforeCaret: Integer);
    function UndoCurrent: Integer;
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure Cut;
    procedure Copy;
    procedure Paste;
    function CanPaste: Boolean;
    procedure SelectAll;
    function IsCommentOrString(Pos: Integer): Boolean;
    function Overwrite: Boolean;
    { files }
    procedure LoadFromFile(const FileName: string);                         // detects the encoding
    procedure LoadFromFileAs(const FileName: string; const AEncoding: TSdEncoding);
    { the editor's text in another encoding (it becomes modified); characters that the new
      encoding cannot hold become '?' - the caller asks before, with ConversionLoss. False:
      Windows cannot convert into that encoding; the text and its encoding stay as they are }
    function ConvertTo(const AEncoding: TSdEncoding): Boolean;
    { False: Windows cannot convert the text into that encoding at all; else Lost says whether
      characters would become '?' }
    function ConversionLoss(const AEncoding: TSdEncoding; out Lost: Boolean): Boolean;
    property Encoding: TSdEncoding read FEncoding;
    procedure LoadFromString(const S: string);
    { S as text of AEncoding (a resource's UTF-8 bytes): the editor's encoding becomes it }
    procedure LoadFromStringAs(const S: string; const AEncoding: TSdEncoding);
    function SaveToFile(const FileName: string): string;                    // the bytes written
    function FileBytes: string;     // the text as SaveToFile writes it (in the file's encoding)
    { the text as it is now counts as saved (Modified False until the next change) }
    procedure SetSavePoint;
    { markers }
    procedure MarkerAdd(Line, Marker: Integer);
    procedure MarkerDelete(Line, Marker: Integer);
    procedure MarkerDeleteAll(Marker: Integer);
    function MarkerGet(Line: Integer): Integer;
    function MarkerNext(FromLine, Mask: Integer): Integer;
    procedure RefreshLineColours;       // white text on lines that carry a coloured background
    { searching (Text: typed in the system code page) }
    function FindNext(const Text: string; MatchCase, WholeWord, RegExp, Forward, Wrap: Boolean): Boolean;
    { the next match from the selection within Lo..Hi (Hi < 0: the end), selected; Wrap: then
      from the range's other end; Skip: the place of an empty match found last (-1 none) - it
      is passed over, so that a pattern that matches empty text moves on }
    function FindInRange(const Text: string; MatchCase, WholeWord, RegExp, Forward, Wrap: Boolean;
      Lo, Hi, Skip: Integer): Boolean;
    { a match from From towards Bound (Bound < From: backward), the selection untouched: its start
      and end }
    function FindSpan(const Text: string; MatchCase, WholeWord, RegExp: Boolean; From, Bound: Integer;
      out MatchStart, MatchEnd: Integer): Boolean;
    { the selection, when it is a match (an empty one too), replaced; the caret after it }
    function ReplaceCurrent(const FindWhat, ReplaceWith: string; MatchCase, WholeWord, RegExp: Boolean): Boolean;
    { every match within Lo..Hi (Hi < 0: the end) replaced as one undo step; Hi comes back as the
      range's end after the replacements }
    function ReplaceAll(const FindWhat, ReplaceWith: string; MatchCase, WholeWord, RegExp: Boolean;
      Lo: Integer; var Hi: Integer): Integer;
    { editing commands }
    procedure IndentSelection(Outdent: Boolean);
    procedure ToggleComment;
    procedure DeleteLine;
    { Edit's line commands: the selected lines (else the caret's) once more below them, moved a
      line up or down, joined into one }
    procedure DuplicateSelection;
    procedure MoveLines(Up: Boolean);
    procedure JoinLines;
    { multiple carets: the next place of the selected text (or the word at the caret) selected as
      well, every place, a caret on the line above or below }
    procedure SelectNextOccurrence;
    procedure SelectAllOccurrences;
    procedure AddCaret(Below: Boolean);
    function CaretCount: Integer;           // the selections (carets) there are
    { the selection grown to the next larger part of the text (a Pascal text's syntax; else the
      word, the line, everything) and back }
    procedure ExpandSelection;
    procedure ShrinkSelection;
    function CanShrinkSelection: Boolean;
    procedure Fold(Action: TSciFoldAction);
    function CanFold: Boolean;
    { Editor Options | Zoom: every editor's, Ctrl+wheel or the zoom commands }
    procedure ApplyZoom;
    property OnZoom: TNotifyEvent read FOnZoom write FOnZoom;
    { Highlighting | Identifier matching: the places of the symbol at the caret (offsets, Len
      their length; those in Decls declarations); nil clears them }
    procedure ShowIdentifiers(Places, Decls: TList; Len: Integer);
    { The names by kind: the document lines a window shows, with
      Margin lines above and below, as positions - False when no window shows the editor; the
      names between two positions by the lexer's styles (not in comments, strings, directives or
      asm), in text order, their Element eeIdentifier; their kinds' text colours, the earlier ones
      of FromPos .. ToPos taken off first; all of them taken off }
    function ViewRange(Margin: Integer; out FromPos, ToPos: Integer): Boolean;
    function NamesBetween(FromPos, ToPos: Integer; var Names: TSciNames): Integer;
    procedure ShowNameKinds(FromPos, ToPos: Integer; const Names: TSciNames; Count: Integer);
    procedure ClearNameKinds;
    { Highlighting | Find matches: every place of what a search looked for, until Esc or another
      search ('' clears them) }
    procedure MarkMatches(const Text: string; MatchCase, WholeWord, RegExp: Boolean);
    { one find match: the Search match element's ground and text colour }
    procedure MarkMatch(Pos, Len: Integer);
    { the places of a whole word (Code: not in comments and strings) }
    procedure WordPlaces(const W: string; Places: TList; Code: Boolean);
    { the Pascal text's block structure, up to date (nil: no Pascal, or a text too large) }
    function Blocks: TPasBlocks;
    { the ranges of an indicator, 'start-end start-end ...' (tests) }
    function IndicatorRanges(Ind: Integer): string;
    { an indicator (IND_...) on a range of the text, and off the whole text }
    procedure FillIndicator(Ind, Pos, Len: Integer);
    procedure ClearIndicator(Ind: Integer);
    { Error Insight: the errors' places under the wavy line (IND_ERROR) and in the scroll bar's
      markers - error K's range carries the value K + 1, so that it is found under the pointer
      while the text around it changes (ErrorAt); Count 0 takes them away }
    procedure ShowErrors(const Starts, Lens: array of Integer; Count: Integer);
    { the error whose range Pos is in: its index in ShowErrors' order (-1: none) and its range }
    function ErrorAt(Pos: Integer; out S, E: Integer): Integer;
    { A sample of the colours (Editor Options | Color): none of the highlights that follow the
      caret is made - matching brackets and words, the highlighted indentation guide, the
      selected word's occurrences; the owner puts them (FillIndicator) -, and a press of a mouse
      button only tells OnSampleClick where it was (a scroll bar's scrolls as well): the caret and
      the selection stay where the owner put them. }
    property Sample: Boolean read FSample write FSample;
    property OnSampleClick: TSciSampleClickEvent read FOnSampleClick write FOnSampleClick;
    { A comparison of two texts (the History tab): one margin, of text - a line's numbers and sign
      as SetDiffMargin gives them, DiffMarginChars characters wide -, no gutter, fold margin or
      change bars, no word wrap (side by side, two windows' lines stay in line); the lines' grounds
      are the markers MK_DIFF_*, the changed words the indicators IND_DIFF_* - the removed ones in
      Error Insight's colour, the added ones in Saved lines', each a tint of the text's ground }
    property DiffView: Boolean read FDiffView write SetDiffView;
    property DiffMarginChars: Integer read FDiffMarginChars write SetDiffMarginChars;
    { line Line's margin text, a style (STYLE_DIFF_*) per character in Styles; its note at its end
      ('' none: a fold's "... n unchanged lines") }
    procedure SetDiffMargin(Line: Integer; const Text, Styles: string);
    procedure SetDiffNote(Line: Integer; const Note: string);
    { Editor Options | Key Mappings: a key the mapping names is run here (True) before the menus'
      shortcuts see it; the commands of SdKeymaps }
    function KeymapKey(Key: Word; Shift: TShiftState): Boolean;
    { a clipboard message of the editor's window ('ClipCut', 'ClipCopy' ...): an expert's procedure for
      it (SciMenuCommandHook); True: it handled the command }
    function MenuCommand(const Command: string): Boolean;
    procedure ExecCommand(Cmd: TEdCmd; Arg: Integer);
    { the block the block commands act on: the selection, else the block Persistent blocks keeps }
    function BlockRange(out A, B: Integer): Boolean;
    { the buffer's block of the Open Tools API, Delphi 7's: its kind, two ends or
      corners, hidden. Each call first takes a selection made since the last one as the block -
      and without Persistent blocks a caret moved meanwhile collapses it. Lines and columns
      0-based, columns display columns. }
    function GetBufferBlock(out Blk: TSciBlock): Boolean;    // True: a valid block
    procedure SetBufferBlock(const Blk: TSciBlock);          // kept as given and shown; the caret stays
    { valid, not hidden, and Persistent blocks or the caret at an end (a column block's corner) }
    function BlockMarked: Boolean;
    { the marked block's span, offsets - a column block's from its first row's left column to its
      last row's edge; False when no block is marked }
    function BlockMarkedSpan(out S, E: Integer): Boolean;
    function InBlock(Line, Col: Integer): Boolean;           // a place inside the marked block
    procedure BlockSetEnd(First: Boolean);                   // BeginBlock / EndBlock: at the caret
    procedure BlockReset;                                    // both ends and corners at the caret, shown
    { the kind: a marked block keeps its place (a stream block's ends become the corners and back);
      ResetUnmarked: a block that is not marked is reset first }
    procedure BlockSetMode(Mode: TSciBlockMode; ResetUnmarked: Boolean);
    procedure BlockSetHidden(Value: Boolean);
    procedure BlockCollapse;                                 // hidden, both ends (corners) at the caret
    { Delphi's Extend: the caret to Line, Col, the block from its anchor to there, ordered; True when
      the caret got there (Line within the text) }
    function BlockExtend(Line, Col: Integer): Boolean;
    { the marked block's text ('' when none), editor text; a column block's rows end with CR LF }
    function BlockText: string;
    function BlockDelete: Boolean;                           // the marked block deleted, then hidden
    procedure BlockCase(Kind: Integer);                      // 0 upper, 1 lower, 2 toggled
    procedure BlockIndent(Magnitude: Integer);
    procedure BlockToClipboard(Append: Boolean);
    { Delphi's rule before text goes in at the caret: without Persistent blocks a marked block is
      deleted (Overwrite blocks: True) or collapsed - hidden, as by a key, unless Shown (an
      expert's text written at the cursor: Delphi 7's BlockVisible is True then, measured); the
      selection is empty afterwards }
    function BlockBeforeTyping(Shown: Boolean = False): Boolean;
    { the caret moved for the Open Tools API: a move of Delphi's editor commands (Kernel: without
      Persistent blocks the block collapses) or IOTAEditView.CursorPos (the block stays); Virt: the
      columns of virtual space past the line's end. BlockMoveBegin / BlockMoveEnd bracket a move
      made by other means. }
    procedure MoveCaretKernel(P, Virt: Integer);
    procedure MoveCaretRaw(P, Virt: Integer);
    procedure BlockMoveBegin(Kernel: Boolean);
    procedure BlockMoveEnd;
    { the place of a line's display column: P its position, V the columns of virtual space past
      the line's end when the line is shorter }
    procedure ColumnPlace(Line, Col: Integer; out P, V: Integer);
    property OnCommand: TSciCommandEvent read FOnCommand write FOnCommand;
    { a keystroke macro played (Delphi's: key by key, the IDE's Shift+Ctrl+P and the Open Tools
      API's records - SdOtaServices): a key as the keyboard gives it - Shift, Ctrl and Alt in the
      thread's key state meanwhile; the key mapping, the experts' bindings and the menus'
      shortcuts first, else the editor -, a typed character; between Begin and End the edits
      are one undo step }
    procedure PlayKey(Key: Word; Shift: TShiftState);
    procedure PlayChar(Ch: Char);
    procedure BeginKeyPlayback;
    procedure EndKeyPlayback;
    { where a tip is shown for the text from Pos to EndPos (SdHints): on the screen, its line's top
      and bottom, from Pos's x to EndPos's - at least one pixel wide, Pos's alone when EndPos is
      on another line }
    function ScreenTextRect(Pos, EndPos: Integer): TRect;
    { setup }
    procedure SetLanguage(Lang: TSciLanguage);
    procedure SetLanguageFromFile(const FileName: string);   // also the file type of Source Options
    property FileType: TEditorFileType read FFileType;
    { before a save (Editor Options): trailing blanks go (unless the file type keeps them), the
      line ends become CRLF (unless Preserve line ends) }
    procedure PrepareSave;
    procedure SaveDone;                                       // ... and after it: Undo after save
    { re-reads EditorOptions and the system colours - when no window has the document, once one
      takes it }
    procedure ApplyOptions;
    { the view was made again - the document came into a window, the options were applied: the
      lines in view, the language or the colours may be others }
    property OnViewApplied: TNotifyEvent read FOnViewApplied write FOnViewApplied;
    property Language: TSciLanguage read FLanguage;
    property Modified: Boolean read GetModified;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly;
    property OnCharAdded: TSciCharEvent read FOnCharAdded write FOnCharAdded;
    property OnMarginClick: TSciMarginClickEvent read FOnMarginClick write FOnMarginClick;
    property OnDwellStart: TSciDwellEvent read FOnDwellStart write FOnDwellStart;
    property OnDwellEnd: TNotifyEvent read FOnDwellEnd write FOnDwellEnd;
    property OnModified: TSciModifiedEvent read FOnModified write FOnModified;
    property OnUpdateUI: TSciUpdateUIEvent read FOnUpdateUI write FOnUpdateUI;
    property OnSavePointChange: TNotifyEvent read FOnSavePointChange write FOnSavePointChange;
    property OnCtrlClick: TSciPosEvent read FOnCtrlClick write FOnCtrlClick;
    property OnFocusChange: TNotifyEvent read FOnFocusChange write FOnFocusChange;
    { the window's keyboard and mouse while it shows the editor }
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyPress: TKeyPressEvent read FOnKeyPress write FOnKeyPress;
    property OnKeyUp: TKeyEvent read FOnKeyUp write FOnKeyUp;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  end;

  TSciSlot = class;

  { A Scintilla window. It shows one editor at a time (Edit) and its messages go to that editor.
    Create makes a window with an editor of its own (a dialog's, a view's: Edit is that editor);
    CreateShared one that shows the editors it is given - the file area's window, which shows
    the file of the page shown and lies over that page's slot (Follow), and the hidden worker. }
  TSciWindow = class(TCustomControl)
  private
    FEdit: TSciEdit;            // the editor shown (nil: none - an empty document)
    FOwnEdit: TSciEdit;         // its own editor (Create), shown whenever the window is there
    FPending: TSciEdit;         // ... shown again once the window is made again
    FSlot: TSciSlot;            // the slot it lies over (Follow)
    FTopBar: TWinControl;       // ... with this bar over the slot's top, while the slot asks for it
    FDirectFn: TSciDirectFunc;
    FDirectPtr: Pointer;
    FBorderless: Boolean;
    FWorker: Boolean;           // the hidden window of the editors no window shows
    FBars: TSciScrollBars;      // the scroll bars, drawn by D7 Studio (SdSciScroll)
    FViewKey: string;           // the editors its view settings are for (TSciEdit.ViewKey; '' none)
    FNumberDigits: Integer;     // the digits the line numbers' margin was measured for
    FBarCaret: Integer;         // the caret's display line in the scroll bar's markers
    FWheelZoom: Integer;        // parts of wheel notches with the zoom key (UIWheelSteps)
    function GetEdit: TSciEdit;
    function WheelZoom(var Message: TWMMouseWheel): Boolean;
    procedure SetEdit(Value: TSciEdit);
    procedure SetTopBar(Value: TWinControl);
    procedure Let(E: TSciEdit; KeepView: Boolean);
    procedure BarInfo(Bar: TSciBar; var Info: TSciScrollInfo);
    procedure BarScroll(Bar: TSciBar; Action: TSciScrollAction; Pos: Integer);
    procedure BarPress(Sender: TObject);
    procedure GetMarks(var Marks: TSciScrollMarks; out Count, Caret: Integer);
    procedure CNNotify(var Message: TWMNotify); message CN_NOTIFY;
    procedure KeyCommand(var Message: TWMKeyDown);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure CMWantSpecialKey(var Message: TCMWantSpecialKey); message CM_WANTSPECIALKEY;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
    procedure WMChar(var Message: TWMChar); message WM_CHAR;
    procedure WMKeyDown(var Message: TWMKeyDown); message WM_KEYDOWN;
    procedure WMKeyUp(var Message: TWMKeyUp); message WM_KEYUP;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMTimer(var Message: TWMTimer); message WM_TIMER;
    procedure WMTrimUndo(var Message: TMessage); message WM_SCITRIMUNDO;
    procedure WMDestroy(var Message: TWMDestroy); message WM_DESTROY;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure WndProc(var Message: TMessage); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateShared(AOwner: TComponent);
    destructor Destroy; override;
    { the window's own Scintilla messages (0 without a window) }
    function Sci(Msg: Cardinal; W: Cardinal = 0; L: Integer = 0): Integer;
    { Slot's editor shown over Slot - where it lies in its view, while it is visible (nil: none,
      the window hidden) }
    procedure Follow(Slot: TSciSlot);
    { ... over the slot again: it moved, was shown or hidden }
    procedure Place;
    { Editor Options | Zoom: the window's zoom, for a file's editor }
    procedure ApplyZoom;
    { the editor shown; a window with an editor of its own gives that one also before its window
      is made. Set: that editor shown (its document leaves the window it was in) }
    property Edit: TSciEdit read GetEdit write SetEdit;
    property Slot: TSciSlot read FSlot;
    { a control of the window's parent that lies over the top of the slot, the window under it, while
      the slot shows it (TSciSlot.ShowBar); both move in one batch. The file area's window has none:
      its page has a page bar of its own above the slot (SdPageBar) }
    property TopBar: TWinControl read FTopBar write SetTopBar;
    property Worker: Boolean read FWorker;
    { no border of its own (it lies inside a view's frame): set before the window is made }
    property Borderless: Boolean read FBorderless write FBorderless;
    property PopupMenu;
    property TabStop;
    property Align;
  end;

  { The place of an editor in its view - a page of the file area: aligned there as a control, it
    shows nothing itself; the window that shows the files lies over the slot of the page shown
    (TSciWindow.Follow) and moves with it }
  TSciSlot = class(TGraphicControl)
  private
    FEdit: TSciEdit;
    FWindow: TSciWindow;        // the window that lies over it (nil: none now)
    FShowBar: Boolean;
    procedure SetEdit(Value: TSciEdit);
    procedure SetShowBar(Value: Boolean);
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    { its view moved, or was shown or hidden: the window over it follows }
    procedure Changed;
    property Edit: TSciEdit read FEdit write SetEdit;
    property Window: TSciWindow read FWindow;
    { the window's TopBar lies over the slot's top while this slot is shown }
    property ShowBar: Boolean read FShowBar write SetShowBar;
  end;

type
  { what a hook did with a key: nothing (it goes on to the key mapping, then the menus), all of it,
    or its part - the key mapping takes it as well, but no menu shortcut (an expert's krNextProc) -,
    or the key mapping does not run but the menus may take it (khMenu: an expert's krUnhandled) }
  TSciKeyHookResult = (khNone, khHandled, khPassOn, khMenu);

var
  { a key of the editor before the key mapping sees it (the Open Tools API's key bindings,
    SdOtaServices); InChord: a chord of the key mapping is pending (its first key came) }
  SciKeyHook: function(Ed: TSciEdit; Key: Word; Shift: TShiftState; InChord: Boolean): TSciKeyHookResult = nil;
  { a clipboard message of the editor's window - WM_CUT, WM_COPY, WM_PASTE, WM_CLEAR - before it runs
    (SdOtaServices: an expert's AddMenuCommand); True: handled }
  SciMenuCommandHook: function(Ed: TSciEdit; const Command: string): Boolean = nil;
  { the expert's highlighter of a source file type's highlighter ID (SdOtaHighlight); nil: none -
    the file's extension chooses the lexer. The tokenizer is asked for again at each use. }
  SciTokenizerFor: function(const HighlighterID: string): TSciTokenizer = nil;
  { the keystroke macro being recorded (SdOtaServices, Delphi's rule): MacroKeyStart - a key comes
    to the editor (True: a macro records - MacroKeyEnd follows when the key was handled, Add: it
    goes into the macro: the editor handled it - the key mapping, an expert's binding, a menu's
    shortcut - or it types no character); MacroChar - a character typed, as the window got it }
  SciMacroKeyStart: function(Ed: TSciEdit): Boolean = nil;
  SciMacroKeyEnd: procedure(Ed: TSciEdit; Key: Word; Shift: TShiftState; Add: Boolean) = nil;
  SciMacroChar: procedure(Ed: TSciEdit; Ch: Char) = nil;
  { the file area's window (made by the main window): the worker takes its size, so that what an
    editor measures on its view (lines in view, columns) is the same in both }
  SciFileWindow: TSciWindow = nil;
  { how often an editor's document came into the worker (the test mode's state dump) }
  SciWorkerAttaches: Integer = 0;

function ScintillaAvailable: Boolean;
function ScintillaLoadError: string;
function LanguageFromFileName(const FileName: string): TSciLanguage;
function IsPascalKeyword(const S: string): Boolean;
{ Editor Options | Zoom on every editor that takes the editors' zoom (OnZoom: a file's page, a text
  resource's) }
procedure SciApplyZoom;

const
  PascalKeywords =
    'absolute abstract and array as asm assembler automated begin case cdecl class const ' +
    'constructor contains default deprecated destructor dispid dispinterface div do downto ' +
    'dynamic else end except export exports external far file finalization finally for forward ' +
    'function goto if implementation implements in index inherited initialization inline interface ' +
    'is label library local message mod name near nil nodefault not object of on or out overload ' +
    'override package packed pascal platform private procedure program property protected public ' +
    'published raise read readonly record register reintroduce repeat requires resident ' +
    'resourcestring safecall set shl shr stdcall stored string then threadvar to try type unit ' +
    'until uses var varargs virtual while with write writeonly xor';
  DfmKeywords = 'object inherited inline end item true false nil';

implementation

uses
  Math, Menus, SdUI, SdIcons, SdPasLex, SdZoom;

type
  TCreateLexer = function(Name: PAnsiChar): Pointer; stdcall;

var
  SciModule: HMODULE;
  LexModule: HMODULE;
  LexCreate: TCreateLexer;
  SciLoadTried: Boolean;
  SciError: string;

procedure LoadScintilla;
var
  Dir: string;
begin
  if SciLoadTried then Exit;
  SciLoadTried := True;
  Dir := ExtractFilePath(ParamStr(0));
  SciModule := LoadLibrary(PChar(Dir + 'Scintilla.dll'));
  if SciModule = 0 then
  begin
    SciError := 'Scintilla.dll could not be loaded from ' + Dir + ' (' + SysErrorMessage(GetLastError) + ')';
    Exit;
  end;
  LexModule := LoadLibrary(PChar(Dir + 'Lexilla.dll'));
  if LexModule <> 0 then
    @LexCreate := GetProcAddress(LexModule, 'CreateLexer');
end;

function ScintillaAvailable: Boolean;
begin
  LoadScintilla;
  Result := SciModule <> 0;
end;

function ScintillaLoadError: string;
begin
  Result := SciError;
end;

function SciColor(C: TColor): Integer;
begin
  Result := Integer(ColorToRGB(C));
end;

function SciColorA(C: TColor): Integer;
begin
  Result := Integer($FF000000 or Cardinal(ColorToRGB(C)));
end;

{ a colour with its opacity (0 .. 255), for Scintilla's translucent elements }
function SciColorAlpha(C: TColor; Alpha: Byte): Integer;
begin
  Result := Integer((Cardinal(Alpha) shl 24) or Cardinal(ColorToRGB(C)));
end;

function SearchFlags(MatchCase, WholeWord, RegExp: Boolean): Integer;
begin
  Result := 0;
  if MatchCase then Result := Result or SCFIND_MATCHCASE;
  if WholeWord then Result := Result or SCFIND_WHOLEWORD;
  if RegExp then Result := Result or SCFIND_REGEXP or SCFIND_CXX11REGEX;
end;

{ the theme's colours of an element (SdEditorOptions: its own, else its Default) }
function ThemeFore(E: TEditorElement): TColor;
begin
  Result := ElementFore(EditorOptions.Colors, E);
end;

function ThemeBack(E: TEditorElement): TColor;
begin
  Result := ElementBack(EditorOptions.Colors, E);
end;

{ Rainbow brackets: the colour of a depth }
function RainbowColour(Depth: Integer): TColor;
begin
  Result := ThemeFore(TEditorElement(Ord(eeRainbow1) + Depth mod RainbowColours));
end;

{ A colour Want over the ground Ground through a translucent layer (the current line, under the
  text: the debugger's and the error lines keep their colours under it): the layer's colour and
  opacity that give Want exactly on Ground, as translucent as that allows }
function TranslucentOver(Want, Ground: TColor; out Alpha: Byte): TColor;
var
  W, G: COLORREF;
  WC, GC: array[0..2] of Integer;
  A, Need: Double;
  I, V: Integer;
begin
  W := ColorToRGB(Want);
  G := ColorToRGB(Ground);
  WC[0] := GetRValue(W);
  WC[1] := GetGValue(W);
  WC[2] := GetBValue(W);
  GC[0] := GetRValue(G);
  GC[1] := GetGValue(G);
  GC[2] := GetBValue(G);
  A := 0;
  for I := 0 to 2 do
  begin
    if WC[I] > GC[I] then Need := (WC[I] - GC[I]) / (255 - GC[I])
    else if WC[I] < GC[I] then Need := (GC[I] - WC[I]) / GC[I]
    else Need := 0;
    if Need > A then A := Need;
  end;
  V := Trunc(A * 255 + 0.999);
  if V < 1 then V := 1;
  if V > 255 then V := 255;
  Alpha := V;
  A := V / 255;
  for I := 0 to 2 do
  begin
    V := Round(GC[I] + (WC[I] - GC[I]) / A);
    if V < 0 then V := 0;
    if V > 255 then V := 255;
    WC[I] := V;
  end;
  Result := RGB(WC[0], WC[1], WC[2]);
end;

function IsPascalKeyword(const S: string): Boolean;
begin
  Result := (S <> '') and (Pos(' ' + LowerCase(S) + ' ', ' ' + PascalKeywords + ' ') > 0);
end;

type
  TSciLanguages = set of TSciLanguage;

  { a language of Lexilla's lexers: Lexer its name in Lexilla ('': none), Exts the extensions of
    its files (each with its dot, between blanks), Words the lexer's word lists (list 0, '|' list
    1 ...; lower case where NoCase), Comment the mark of a line comment (Toggle Comment; '': none),
    NoCase its words in any letter case (Select Next / All Occurrences, the identifier's places),
    Folds the lexer folds }
  TSciLexLanguage = record
    Lexer, Exts, Words, Comment: string;
    NoCase, Folds: Boolean;
  end;

  { a style of the lexer of the languages Langs and the theme's element that colours it; a
    style no row names is plain text (STYLE_DEFAULT) }
  TSciLexStyle = record
    Langs: TSciLanguages;
    Style: Byte;
    Element: TEditorElement;
  end;

const
  CppWords =
    'alignas alignof asm auto bool break case catch char char16_t char32_t class const const_cast ' +
    'constexpr continue decltype default delete do double dynamic_cast else enum explicit export ' +
    'extern false float for friend goto if inline int long mutable namespace new noexcept nullptr ' +
    'operator private protected public register reinterpret_cast return short signed sizeof static ' +
    'static_assert static_cast struct switch template this thread_local throw true try typedef ' +
    'typeid typename union unsigned using virtual void volatile wchar_t while __cdecl __closure ' +
    '__declspec __fastcall __property __published __stdcall';
  CSharpWords =
    'abstract as async await base bool break byte case catch char checked class const continue ' +
    'decimal default delegate do double else enum event explicit extern false finally fixed float ' +
    'for foreach get goto if implicit in int interface internal is lock long namespace new null ' +
    'object operator out override params partial private protected public readonly ref return ' +
    'sbyte sealed set short sizeof stackalloc static string struct switch this throw true try ' +
    'typeof uint ulong unchecked unsafe ushort using value var virtual void volatile where while yield';
  ResourceWords =
    'accelerators auto3state autocheckbox autoradiobutton begin bitmap block caption ' +
    'characteristics checkbox class combobox control ctext cursor defpushbutton dialog dialogex ' +
    'discardable dlginit edittext end exstyle fileflags fileflagsmask fileos filesubtype filetype ' +
    'fileversion fixed font groupbox html icon impure language listbox loadoncall ltext menu ' +
    'menuex menuitem messagetable moveable not popup preload productversion pure pushbutton ' +
    'radiobutton rcdata rtext scrollbar separator state3 stringtable style toolbar value version ' +
    'versioninfo';
  IdlWords =
    'aggregatable appobject bindable boolean byte char coclass const control cpp_quote default ' +
    'defaultbind dispinterface displaybind double dual enum float helpcontext helpfile helpstring ' +
    'hidden hyper id import importlib in int interface lcid library licensed long midl_pragma ' +
    'module noncreatable object odl oleautomation optional out pointer_default propget propput ' +
    'propputref ptr readonly ref requestedit restricted retval short signed source string struct ' +
    'typedef union unique unsigned uuid version void wchar_t';
  JavaScriptWords =
    'async await break case catch class const continue debugger default delete do else export ' +
    'extends false finally for function if import in instanceof let new null return super switch ' +
    'this throw true try typeof undefined var void while with yield';
  SqlWords =
    'add all alter and as asc begin between by case check column commit constraint create cross ' +
    'declare default delete desc distinct drop else end exists foreign from full function grant ' +
    'group having if in index inner insert into is join key left like not null on or order outer ' +
    'primary procedure references revoke right rollback select set table then top transaction ' +
    'trigger truncate union unique update values view when where with';
  BatchWords =
    'assoc break call cd chdir cls color copy date del dir do echo else endlocal erase errorlevel ' +
    'exist exit for ftype goto if in md mkdir move not path pause popd prompt pushd rd rem ren ' +
    'rename rmdir set setlocal shift start time title type ver verify vol';

  SciLanguages: array[TSciLanguage] of TSciLexLanguage = (
    { slNone }
    (Lexer: ''; Exts: ''; Words: ''; Comment: ''; NoCase: False; Folds: False),
    (Lexer: 'pascal'; Exts: ' .pas .dpr .dpk .inc .pp .lpr '; Words: PascalKeywords; Comment: '//';
      NoCase: True; Folds: True),
    { form text: the VCL's reader knows no comments }
    (Lexer: 'pascal'; Exts: ' .dfm .xfm .lfm '; Words: DfmKeywords; Comment: ''; NoCase: True;
      Folds: True),
    { slExpert: by the source file type's highlighter, not by an extension }
    (Lexer: ''; Exts: ''; Words: ''; Comment: ''; NoCase: False; Folds: False),
    (Lexer: 'cpp'; Exts: ' .c .cpp .cc .cxx .h .hpp .hh .hxx '; Words: CppWords; Comment: '//';
      NoCase: False; Folds: True),
    (Lexer: 'cpp'; Exts: ' .cs '; Words: CSharpWords; Comment: '//'; NoCase: False; Folds: True),
    { resource scripts: their words in any letter case, as rc and brcc32 read them }
    (Lexer: 'cppnocase'; Exts: ' .rc .rc2 .dlg '; Words: ResourceWords; Comment: '//'; NoCase: True;
      Folds: True),
    (Lexer: 'cpp'; Exts: ' .idl .odl .ridl '; Words: IdlWords; Comment: '//'; NoCase: False;
      Folds: True),
    (Lexer: 'xml'; Exts: ' .xml .xsl .xslt .xsd .dtd .manifest .config .wml '; Words: '';
      Comment: ''; NoCase: False; Folds: True),
    { HTML: its tags and attributes all as unknown ones (the same colours), scripts' words list 1 }
    (Lexer: 'hypertext'; Exts: ' .html .htm .xhtml .hta .asp .aspx '; Words: '|' + JavaScriptWords;
      Comment: ''; NoCase: True; Folds: True),
    (Lexer: 'props'; Exts: ' .ini .dof .dsk .cfg .dro .inf .reg .conf .properties .d7theme ';
      Words: ''; Comment: ';'; NoCase: True; Folds: True),
    (Lexer: 'sql'; Exts: ' .sql '; Words: SqlWords; Comment: '--'; NoCase: True; Folds: True),
    (Lexer: 'batch'; Exts: ' .bat .cmd '; Words: BatchWords; Comment: 'rem '; NoCase: True;
      Folds: False),
    { project groups are make files }
    (Lexer: 'makefile'; Exts: ' .bpg .mak .mk '; Words: ''; Comment: '#'; NoCase: False;
      Folds: False));

  SciPascal = [slPascal, slDfm];
  SciCFamily = [slCpp, slCSharp, slResource, slIdl];
  SciMarkup = [slXml, slHtml];

  SciLexStyles: array[0..104] of TSciLexStyle = (
    (Langs: SciPascal; Style: SCE_PAS_DEFAULT; Element: eePlainText),
    (Langs: SciPascal; Style: SCE_PAS_IDENTIFIER; Element: eeIdentifier),
    (Langs: SciPascal; Style: SCE_PAS_COMMENT; Element: eeComment),
    (Langs: SciPascal; Style: SCE_PAS_COMMENT2; Element: eeComment),
    (Langs: SciPascal; Style: SCE_PAS_COMMENTLINE; Element: eeComment),
    (Langs: SciPascal; Style: SCE_PAS_PREPROCESSOR; Element: eeDirective),
    (Langs: SciPascal; Style: SCE_PAS_PREPROCESSOR2; Element: eeDirective),
    (Langs: SciPascal; Style: SCE_PAS_NUMBER; Element: eeNumber),
    (Langs: SciPascal; Style: SCE_PAS_HEXNUMBER; Element: eeHex),
    (Langs: SciPascal; Style: SCE_PAS_WORD; Element: eeReservedWord),
    (Langs: SciPascal; Style: SCE_PAS_STRING; Element: eeString),
    (Langs: SciPascal; Style: SCE_PAS_STRINGEOL; Element: eeString),
    (Langs: SciPascal; Style: SCE_PAS_MULTILINESTRING; Element: eeString),
    (Langs: SciPascal; Style: SCE_PAS_CHARACTER; Element: eeCharacter),
    (Langs: SciPascal; Style: SCE_PAS_OPERATOR; Element: eeSymbol),
    (Langs: SciPascal; Style: SCE_PAS_ASM; Element: eeAssembler),
    (Langs: SciCFamily; Style: SCE_C_IDENTIFIER; Element: eeIdentifier),
    (Langs: SciCFamily; Style: SCE_C_COMMENT; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_COMMENTLINE; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_COMMENTDOC; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_COMMENTLINEDOC; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_COMMENTDOCKEYWORD; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_COMMENTDOCKEYWORDERROR; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_PREPROCESSORCOMMENT; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_PREPROCESSORCOMMENTDOC; Element: eeComment),
    (Langs: SciCFamily; Style: SCE_C_PREPROCESSOR; Element: eeDirective),
    (Langs: SciCFamily; Style: SCE_C_NUMBER; Element: eeNumber),
    (Langs: SciCFamily; Style: SCE_C_UUID; Element: eeHex),
    (Langs: SciCFamily; Style: SCE_C_WORD; Element: eeReservedWord),
    (Langs: SciCFamily; Style: SCE_C_WORD2; Element: eeReservedWord),
    (Langs: SciCFamily; Style: SCE_C_STRING; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_STRINGEOL; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_VERBATIM; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_STRINGRAW; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_TRIPLEVERBATIM; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_HASHQUOTEDSTRING; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_REGEX; Element: eeString),
    (Langs: SciCFamily; Style: SCE_C_CHARACTER; Element: eeCharacter),
    (Langs: SciCFamily; Style: SCE_C_OPERATOR; Element: eeSymbol),
    { markup: tags as reserved words, attributes' names identifiers, their values strings }
    (Langs: SciMarkup; Style: SCE_H_TAG; Element: eeReservedWord),
    (Langs: SciMarkup; Style: SCE_H_TAGUNKNOWN; Element: eeReservedWord),
    (Langs: SciMarkup; Style: SCE_H_TAGEND; Element: eeReservedWord),
    (Langs: SciMarkup; Style: SCE_H_ATTRIBUTE; Element: eeIdentifier),
    (Langs: SciMarkup; Style: SCE_H_ATTRIBUTEUNKNOWN; Element: eeIdentifier),
    (Langs: SciMarkup; Style: SCE_H_NUMBER; Element: eeNumber),
    (Langs: SciMarkup; Style: SCE_H_DOUBLESTRING; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_SINGLESTRING; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_VALUE; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_CDATA; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_SGML_DOUBLESTRING; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_SGML_SIMPLESTRING; Element: eeString),
    (Langs: SciMarkup; Style: SCE_H_OTHER; Element: eeSymbol),
    (Langs: SciMarkup; Style: SCE_H_COMMENT; Element: eeComment),
    (Langs: SciMarkup; Style: SCE_H_XCCOMMENT; Element: eeComment),
    (Langs: SciMarkup; Style: SCE_H_SGML_COMMENT; Element: eeComment),
    (Langs: SciMarkup; Style: SCE_H_SGML_1ST_PARAM_COMMENT; Element: eeComment),
    (Langs: SciMarkup; Style: SCE_H_ENTITY; Element: eeCharacter),
    (Langs: SciMarkup; Style: SCE_H_SGML_ENTITY; Element: eeCharacter),
    (Langs: SciMarkup; Style: SCE_H_XMLSTART; Element: eeDirective),
    (Langs: SciMarkup; Style: SCE_H_XMLEND; Element: eeDirective),
    (Langs: SciMarkup; Style: SCE_H_QUESTION; Element: eeDirective),
    (Langs: SciMarkup; Style: SCE_H_SGML_DEFAULT; Element: eeDirective),
    (Langs: SciMarkup; Style: SCE_H_SGML_COMMAND; Element: eeDirective),
    (Langs: SciMarkup; Style: SCE_H_SGML_1ST_PARAM; Element: eeDirective),
    { HTML's scripts }
    (Langs: [slHtml]; Style: SCE_HJ_WORD; Element: eeIdentifier),
    (Langs: [slHtml]; Style: SCE_HJ_KEYWORD; Element: eeReservedWord),
    (Langs: [slHtml]; Style: SCE_HJ_COMMENT; Element: eeComment),
    (Langs: [slHtml]; Style: SCE_HJ_COMMENTLINE; Element: eeComment),
    (Langs: [slHtml]; Style: SCE_HJ_COMMENTDOC; Element: eeComment),
    (Langs: [slHtml]; Style: SCE_HJ_NUMBER; Element: eeNumber),
    (Langs: [slHtml]; Style: SCE_HJ_DOUBLESTRING; Element: eeString),
    (Langs: [slHtml]; Style: SCE_HJ_SINGLESTRING; Element: eeString),
    (Langs: [slHtml]; Style: SCE_HJ_STRINGEOL; Element: eeString),
    (Langs: [slHtml]; Style: SCE_HJ_TEMPLATELITERAL; Element: eeString),
    (Langs: [slHtml]; Style: SCE_HJ_REGEX; Element: eeString),
    (Langs: [slHtml]; Style: SCE_HJ_SYMBOLS; Element: eeSymbol),
    (Langs: [slIni]; Style: SCE_PROPS_COMMENT; Element: eeComment),
    (Langs: [slIni]; Style: SCE_PROPS_SECTION; Element: eeReservedWord),
    (Langs: [slIni]; Style: SCE_PROPS_KEY; Element: eeIdentifier),
    (Langs: [slIni]; Style: SCE_PROPS_ASSIGNMENT; Element: eeSymbol),
    (Langs: [slIni]; Style: SCE_PROPS_DEFVAL; Element: eeDirective),
    (Langs: [slSql]; Style: SCE_SQL_IDENTIFIER; Element: eeIdentifier),
    (Langs: [slSql]; Style: SCE_SQL_QUOTEDIDENTIFIER; Element: eeIdentifier),
    (Langs: [slSql]; Style: SCE_SQL_COMMENT; Element: eeComment),
    (Langs: [slSql]; Style: SCE_SQL_COMMENTLINE; Element: eeComment),
    (Langs: [slSql]; Style: SCE_SQL_COMMENTDOC; Element: eeComment),
    (Langs: [slSql]; Style: SCE_SQL_COMMENTLINEDOC; Element: eeComment),
    (Langs: [slSql]; Style: SCE_SQL_NUMBER; Element: eeNumber),
    (Langs: [slSql]; Style: SCE_SQL_WORD; Element: eeReservedWord),
    (Langs: [slSql]; Style: SCE_SQL_WORD2; Element: eeReservedWord),
    (Langs: [slSql]; Style: SCE_SQL_STRING; Element: eeString),
    (Langs: [slSql]; Style: SCE_SQL_CHARACTER; Element: eeString),
    (Langs: [slSql]; Style: SCE_SQL_OPERATOR; Element: eeSymbol),
    { batch files: labels as directives, the text after a label is ignored as a comment is }
    (Langs: [slBatch]; Style: SCE_BAT_COMMENT; Element: eeComment),
    (Langs: [slBatch]; Style: SCE_BAT_AFTER_LABEL; Element: eeComment),
    (Langs: [slBatch]; Style: SCE_BAT_WORD; Element: eeReservedWord),
    (Langs: [slBatch]; Style: SCE_BAT_LABEL; Element: eeDirective),
    (Langs: [slBatch]; Style: SCE_BAT_IDENTIFIER; Element: eeVariable),
    (Langs: [slBatch]; Style: SCE_BAT_HIDE; Element: eeSymbol),
    (Langs: [slBatch]; Style: SCE_BAT_OPERATOR; Element: eeSymbol),
    (Langs: [slMake]; Style: SCE_MAKE_COMMENT; Element: eeComment),
    (Langs: [slMake]; Style: SCE_MAKE_PREPROCESSOR; Element: eeDirective),
    (Langs: [slMake]; Style: SCE_MAKE_IDENTIFIER; Element: eeVariable),
    (Langs: [slMake]; Style: SCE_MAKE_TARGET; Element: eeReservedWord),
    (Langs: [slMake]; Style: SCE_MAKE_OPERATOR; Element: eeSymbol));

function LanguageFromFileName(const FileName: string): TSciLanguage;
var
  Ext: string;
  L: TSciLanguage;
begin
  Result := slNone;
  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '' then Exit;
  for L := Low(TSciLanguage) to High(TSciLanguage) do
    if Pos(' ' + Ext + ' ', SciLanguages[L].Exts) > 0 then
    begin
      Result := L;
      Exit;
    end;
end;

type
  TSciStyles = set of Byte;

var
  { the styles of each language's comments, strings and characters (IsCommentOrString): made once
    from SciLexStyles - Pascal's directives among them ($I ...) -; an expert's highlighter's are
    the codes of ToolsAPI's atComment, atString, atCharacter and atPreproc }
  SciQuotedStyles: array[TSciLanguage] of TSciStyles;

procedure InitQuotedStyles;
var
  I: Integer;
  L: TSciLanguage;
begin
  SciQuotedStyles[slExpert] := [1, 5, 10, 11];
  for I := Low(SciLexStyles) to High(SciLexStyles) do
    for L := Low(TSciLanguage) to High(TSciLanguage) do
      if (L in SciLexStyles[I].Langs) and ((SciLexStyles[I].Element in [eeComment, eeString, eeCharacter]) or
        (SciLexStyles[I].Element = eeDirective) and (L in SciPascal)) then
        Include(SciQuotedStyles[L], SciLexStyles[I].Style);
end;

{ --- the worker: the hidden window an editor's document is in while no window shows it --- }

type
  { the worker's parent: a window of its own that is never shown }
  TSciWorkHost = class(TWinControl)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;

procedure TSciWorkHost.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP or WS_CLIPCHILDREN;
  Params.ExStyle := WS_EX_TOOLWINDOW;
  Params.WndParent := 0;
end;

var
  SciWorkHost: TSciWorkHost;
  SciWorker: TSciWindow;
  SciEnding: Boolean;            // the unit's finalization: no worker is made any more
  SciEdits: TList;               // every editor there is
  { goes up with each ApplyOptions: a window's view settings are made again for the next editor
    it takes (TSciEdit.ViewKey) }
  SciViewGen: Integer;

{ the worker (nil: Scintilla is not there) }
function Worker: TSciWindow;
begin
  if (SciWorker = nil) and not SciEnding and ScintillaAvailable then
  begin
    SciWorkHost := TSciWorkHost.Create(nil);
    SciWorkHost.Visible := False;
    SciWorker := TSciWindow.CreateShared(SciWorkHost);
    SciWorker.FWorker := True;
    SciWorker.FBorderless := True;    // as the file area's window: its size gives the same client
    SciWorker.Visible := False;
    SciWorker.Parent := SciWorkHost;
    SciWorker.HandleNeeded;
  end;
  Result := SciWorker;
end;

{ a new document (0: none). Scintilla makes the folding state of the window it asks anew
  (Message::CreateDocument): the worker is asked, with no editor's document in it }
function NewDocument: Integer;
var
  W: TSciWindow;
begin
  Result := 0;
  W := Worker;
  if (W = nil) or not W.HandleAllocated then Exit;
  if W.FEdit <> nil then W.Let(W.FEdit, True);
  Result := W.Sci(SCI_CREATEDOCUMENT, 0, SC_DOCUMENTOPTION_DEFAULT);
end;

{ an editor's reference to its document given up, through a window that is there (at the end of
  the program there may be none: the process ends with it) }
procedure ReleaseDocument(Doc: Integer);
begin
  if (SciWorker <> nil) and SciWorker.HandleAllocated then SciWorker.Sci(SCI_RELEASEDOCUMENT, 0, Doc)
  else if (SciFileWindow <> nil) and SciFileWindow.HandleAllocated then SciFileWindow.Sci(SCI_RELEASEDOCUMENT, 0, Doc);
end;

{ the editor is still there (a command of a key may close the page whose editor had the key) }
function EditAlive(E: TSciEdit): Boolean;
begin
  Result := (E <> nil) and (SciEdits <> nil) and (SciEdits.IndexOf(E) >= 0);
end;

procedure SciApplyZoom;
var
  I: Integer;
begin
  if SciEdits <> nil then
    for I := 0 to SciEdits.Count - 1 do TSciEdit(SciEdits[I]).ApplyZoom;
end;

{ TSciEdit }

constructor TSciEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if SciEdits = nil then SciEdits := TList.Create;
  SciEdits.Add(Self);
  FBlockA := -1;
  FBlockB := -1;
  FBlockMode := sbNonInclusive;
  FBlockRows := Rect(-1, -1, -1, -1);
  FBlockSel.Caret := -1;
  FWriterCur := -1;
  FLinkStart := -1;
  FLinkEnd := -1;
  FEolMode := SC_EOL_CRLF;
  FEncoding := SystemEncoding;
  { a unit until it is told otherwise }
  FTypeFile := 'Unit.pas';
  FFileType := EditorFileType(FTypeFile);
  FMarksDirty := True;
  FAddedCaret := -1;
  FAutoCloseLine := -1;
end;

destructor TSciEdit.Destroy;
begin
  if FWindow <> nil then FWindow.Let(Self, False);
  if FDoc <> 0 then ReleaseDocument(FDoc);
  FDoc := 0;
  if SciEdits <> nil then SciEdits.Remove(Self);
  FBlocks.Free;
  inherited Destroy;
end;

function TSciEdit.Ready: Boolean;
begin
  Result := (FDirectPtr <> nil) or (not (csDestroying in ComponentState) and ScintillaAvailable);
end;

{ the document into a window: its own window when it can be made (it has a parent), else the
  worker. True: it is in one }
function TSciEdit.Attach: Boolean;
var
  W: TSciWindow;
begin
  if (FDirectPtr = nil) and not (csDestroying in ComponentState) then
  begin
    W := FHome;
    if (W <> nil) and not W.HandleAllocated and (W.Parent = nil) and (W.ParentWindow = 0) then W := nil;
    if W = nil then
    begin
      W := Worker;
      if W <> nil then Inc(SciWorkerAttaches);
    end;
    if W <> nil then W.SetEdit(Self);
  end;
  Result := FDirectPtr <> nil;
end;

{ a window took the document: a new one gets Scintilla's settings of a document; then the
  language and the options changed meanwhile, the window's view settings when they were made for
  another kind of editor, and the view the document had }
procedure TSciEdit.Attached;
begin
  if FFresh then
  begin
    FFresh := False;
    ApplyCodePage;
    Sci(SCI_SETEOLMODE, FEolMode);
    Sci(SCI_SETTABINDENTS, 1);
    Sci(SCI_SETWORDCHARS, 0, Integer(PChar('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')));
    FLexerPending := True;
    FOptionsPending := True;
  end;
  if FLexerPending then SetupLexer;
  if FOptionsPending then ApplyOptions
  else if FWindow.FViewKey <> ViewKey then ApplyView
  else SetupLineNumbers(False);
  RestoreView;
  if FTrimPending and FWindow.HandleAllocated then PostMessage(FWindow.Handle, WM_SCITRIMUNDO, 0, 0);
  if FBlocksStale or FFindStale or FMarksDirty then ScheduleIdle;
  if Bars <> nil then Bars.Update;
  if Shown and Assigned(FOnViewApplied) then FOnViewApplied(Self);
end;

{ the document leaves its window (still in it): the link goes, the view is kept for the next
  window (KeepView), what is asked without a window is noted }
procedure TSciEdit.Detached(KeepView: Boolean);
begin
  ClearLink;
  if KeepView then SaveView;
  FModifiedCache := Sci(SCI_GETMODIFY) <> 0;
  FReadOnlyCache := Sci(SCI_GETREADONLY) <> 0;
  FWindow := nil;
  FDirectFn := nil;
  FDirectPtr := nil;
end;

procedure TSciEdit.SaveView;
var
  L, N: Integer;
begin
  FView.Saved := True;
  FView.Sel := SciStr(SCI_GETSELECTIONSERIALIZED, 0);
  FView.TopLine := Sci(SCI_DOCLINEFROMVISIBLE, Sci(SCI_GETFIRSTVISIBLELINE));
  FView.XOffset := Sci(SCI_GETXOFFSET);
  FView.ScrollWidth := Sci(SCI_GETSCROLLWIDTH);
  N := 0;
  L := Sci(SCI_CONTRACTEDFOLDNEXT, 0);
  while L >= 0 do
  begin
    if N = Length(FView.Folds) then SetLength(FView.Folds, 2 * N + 8);
    FView.Folds[N] := L;
    Inc(N);
    L := Sci(SCI_CONTRACTEDFOLDNEXT, Cardinal(L + 1));
  end;
  SetLength(FView.Folds, N);
end;

{ the view the document had: its folds (on the fold levels styled up to them), the selections,
  the scrolling }
procedure TSciEdit.RestoreView;
var
  I, Last: Integer;
begin
  if not FView.Saved then Exit;
  if Length(FView.Folds) > 0 then
  begin
    Last := FView.Folds[High(FView.Folds)] + 1;
    if Last < LineCount then Sci(SCI_COLOURISE, Sci(SCI_GETENDSTYLED), PosFromLine(Last + 1))
    else Sci(SCI_COLOURISE, Sci(SCI_GETENDSTYLED), -1);
    for I := 0 to High(FView.Folds) do
      if Sci(SCI_GETFOLDLEVEL, FView.Folds[I]) and SC_FOLDLEVELHEADERFLAG <> 0 then
        Sci(SCI_FOLDLINE, FView.Folds[I], SC_FOLDACTION_CONTRACT);
  end;
  if FView.Sel <> '' then SciS(SCI_SETSELECTIONSERIALIZED, 0, FView.Sel);
  Sci(SCI_SETSCROLLWIDTH, Max(1, FView.ScrollWidth));
  Sci(SCI_SETFIRSTVISIBLELINE, Sci(SCI_VISIBLEFROMDOCLINE, FView.TopLine));
  Sci(SCI_SETXOFFSET, FView.XOffset);
end;

{ what a window's view settings depend on (ApplyView): another key, they are made again }
function TSciEdit.ViewKey: string;
begin
  Result := Format('%d|%d|%s|%s|%d|%d|%d|%d', [SciViewGen, Ord(FLanguage), FFileType.ID, FFileType.Name,
    FEncoding.CodePage, Ord(IsUnicodeEncoding(FEncoding)), Ord(Assigned(FOnZoom)), EditorOptions.Zoom]);
end;

function TSciEdit.Bars: TSciScrollBars;
begin
  if FWindow <> nil then Result := FWindow.FBars else Result := nil;
end;

{ a string Scintilla gives (its length first, then its bytes) }
function TSciEdit.SciStr(Msg: Cardinal; W: Cardinal): string;
var
  N: Integer;
begin
  N := Sci(Msg, W, 0);
  SetLength(Result, Max(N, 0));
  if N > 0 then Sci(Msg, W, Integer(PChar(Result)));
end;

function TSciEdit.Sci(Msg: Cardinal; W: Cardinal; L: Integer): Integer;
begin
  if (FDirectPtr <> nil) or Attach then
    Result := FDirectFn(FDirectPtr, Msg, W, L)
  else
    Result := 0;
end;

function TSciEdit.SciS(Msg: Cardinal; W: Cardinal; const S: string): Integer;
begin
  Result := Sci(Msg, W, Integer(PChar(S)));
end;

{ the window that shows it: not the worker }
function TSciEdit.Shown: Boolean;
begin
  Result := (FWindow <> nil) and not FWindow.FWorker;
end;

function TSciEdit.Focused: Boolean;
begin
  Result := Shown and FWindow.Focused;
end;

function TSciEdit.CanFocus: Boolean;
begin
  Result := Shown and FWindow.CanFocus;
end;

procedure TSciEdit.SetFocus;
begin
  if CanFocus then FWindow.SetFocus;
end;

function TSciEdit.Handle: HWND;
begin
  if (FWindow <> nil) and FWindow.HandleAllocated then Result := FWindow.Handle else Result := 0;
end;

function TSciEdit.ClientToScreen(const P: TPoint): TPoint;
begin
  if FWindow <> nil then Result := FWindow.ClientToScreen(P) else Result := P;
end;

function TSciEdit.ClientWidth: Integer;
begin
  if FWindow <> nil then Result := FWindow.ClientWidth else Result := 0;
end;

procedure TSciEdit.Invalidate;
begin
  if Shown then FWindow.Invalidate;
end;

procedure TSciEdit.SetProp(const Key, Value: string);
begin
  { PChar('1') on a one-character literal would cast the ordinal: always go through strings }
  Sci(SCI_SETPROPERTY, Cardinal(PChar(Key)), Integer(PChar(Value)));
end;

{ the x where the text area starts in the window: the margins' widths and the padding after them }
function TSciEdit.TextAreaLeft: Integer;
var
  I: Integer;
begin
  Result := Sci(SCI_GETMARGINLEFT);
  for I := 0 to Sci(SCI_GETMARGINS) - 1 do Inc(Result, Sci(SCI_GETMARGINWIDTHN, I));
end;

{ --- the scroll bars (SdSciScroll) --- }

{ as Scintilla's own: the vertical bar always, its last position as Cursor beyond EOF says; the
  horizontal one while the widest line shown does not fit (no wrapping). Scintilla tracks the
  widest line only while its own horizontal bar is on: the scroll width grows here, from the
  lines in view (their ends, and room for the caret after them) }
procedure TSciEdit.BarInfo(Bar: TSciBar; var Info: TSciScrollInfo);
var
  Text, D, Line, Lines, W, Widest, X0: Integer;
begin
  if not Assigned(FDirectFn) then Exit;
  if Bar = sbVert then
  begin
    Info.Visible := True;
    Info.Page := Sci(SCI_LINESONSCREEN);
    Info.Pos := Sci(SCI_GETFIRSTVISIBLELINE);
    Info.Max := Sci(SCI_VISIBLEFROMDOCLINE, Sci(SCI_GETLINECOUNT));
    if Sci(SCI_GETENDATLASTLINE) <> 0 then Dec(Info.Max, Info.Page) else Dec(Info.Max);
    if Info.Max < 0 then Info.Max := 0;
  end
  else
  begin
    if Sci(SCI_GETWRAPMODE) = SC_WRAP_NONE then
    begin
      { unwrapped, every line starts at the same x: one line's start measures all }
      Widest := 0;
      X0 := MaxInt;
      Lines := Sci(SCI_GETLINECOUNT);
      for D := Sci(SCI_GETFIRSTVISIBLELINE) to Sci(SCI_GETFIRSTVISIBLELINE) + Sci(SCI_LINESONSCREEN) do
      begin
        Line := Sci(SCI_DOCLINEFROMVISIBLE, D);
        if Line >= Lines then Break;
        if X0 = MaxInt then X0 := Sci(SCI_POINTXFROMPOSITION, 0, Sci(SCI_POSITIONFROMLINE, Line));
        W := Sci(SCI_POINTXFROMPOSITION, 0, Sci(SCI_GETLINEENDPOSITION, Line)) - X0;
        if W > Widest then Widest := W;
      end;
      Inc(Widest, Sci(SCI_TEXTWIDTH, STYLE_DEFAULT, Integer(PChar('  '))));
      if Widest > Sci(SCI_GETSCROLLWIDTH) then Sci(SCI_SETSCROLLWIDTH, Widest);
    end;
    Text := ClientWidth - TextAreaLeft - Sci(SCI_GETMARGINRIGHT);
    if Text < 1 then Text := 1;
    Info.Page := Text;
    Info.Pos := Sci(SCI_GETXOFFSET);
    Info.Max := Sci(SCI_GETSCROLLWIDTH) - Text;
    if Info.Max < Info.Pos then Info.Max := Info.Pos;
    Info.Visible := (Info.Max > 0) and (Sci(SCI_GETWRAPMODE) = SC_WRAP_NONE);
    if Info.Max < 0 then Info.Max := 0;
  end;
end;

function TSciEdit.ScrollPos: TPoint;
begin
  Result := Point(Sci(SCI_GETXOFFSET), Sci(SCI_GETFIRSTVISIBLELINE));
end;

procedure TSciEdit.BarScroll(Bar: TSciBar; Action: TSciScrollAction; Pos: Integer);
var
  Page: Integer;
begin
  if Bar = sbVert then
  begin
    Page := Sci(SCI_LINESONSCREEN) - 1;
    if Page < 1 then Page := 1;
    case Action of
      saLineBack: Sci(SCI_LINESCROLL, 0, -1);
      saLineOn: Sci(SCI_LINESCROLL, 0, 1);
      saPageBack: Sci(SCI_LINESCROLL, 0, -Page);
      saPageOn: Sci(SCI_LINESCROLL, 0, Page);
      saTo: Sci(SCI_SETFIRSTVISIBLELINE, Pos);
    end;
  end
  else
  begin
    Page := ClientWidth div 2;
    case Action of
      saLineBack: Sci(SCI_LINESCROLL, Cardinal(-1), 0);
      saLineOn: Sci(SCI_LINESCROLL, 1, 0);
      saPageBack: Sci(SCI_SETXOFFSET, Cardinal(Max(0, Sci(SCI_GETXOFFSET) - Page)));
      saPageOn: Sci(SCI_SETXOFFSET, Cardinal(Sci(SCI_GETXOFFSET) + Page));
      saTo: Sci(SCI_SETXOFFSET, Cardinal(Pos));
    end;
  end;
end;

{ --- the window's messages for the editor it shows (TSciWindow) --- }

{ WM_CHAR: False - the character goes (a key the editor took typed it) }
function TSciEdit.CharArrives(Ch: Word): Boolean;
begin
  Result := False;
  if (FSwallowTab and (Ch = VK_TAB)) or (FSwallowBack and (Ch = VK_BACK)) then
  begin
    FSwallowTab := False;
    FSwallowBack := False;
    Exit;
  end;
  FSwallowTab := False;
  FSwallowBack := False;
  { swallow control characters produced by unassigned Ctrl+key combinations }
  if (Ch < 32) and not (Ch in [VK_TAB, VK_RETURN, 10, VK_BACK, VK_ESCAPE]) then
    Exit;
  { a keystroke macro being recorded: the character as the window got it (the key that typed it
    is not in the macro - KeyDispatched) }
  if (Ch >= 32) and Assigned(SciMacroChar) then SciMacroChar(Self, Char(Ch));
  UndoBoundary;
  Result := True;     // the window's KeyPress: OnKeyPress, then Auto-close pairs and Overwrite blocks
end;

{ after the page's key handler (its pop-ups and Incremental Search take characters first) }
procedure TSciEdit.KeyPress(var Key: Char);
var
  P: Integer;
begin
  if Assigned(FOnKeyPress) then FOnKeyPress(Self, Key);
  FPendingClose := #0;
  if (Key < ' ') or not Assigned(FDirectFn) then Exit;
  if AutoCloseChar(Key) then Exit;
  { Editor Options | Overwrite blocks off: what is typed goes in at the caret, the block stays }
  if not EditorOptions.OverwriteBlocks and (Sci(SCI_GETSELECTIONEMPTY) = 0) and (Sci(SCI_GETSELECTIONS) = 1) then
  begin
    P := Sci(SCI_GETCURRENTPOS);
    Sci(SCI_SETEMPTYSELECTION, P);
  end;
end;

{ Editor Options | Undo limit (Delphi's: the number of undo steps). Scintilla keeps everything:
  when the history has a good deal more steps than the limit, its oldest steps go - the history
  is read out (SCI_GETUNDOACTION*) and pushed again without them (SCI_PUSHUNDOACTIONTYPE), with
  the save, detach, tentative and current points moved along. A step ends at an action without
  the coalesce flag (). The message (WM_SCITRIMUNDO) goes to the window: it may show another
  editor by then, whose history has nothing to trim (FTrimPending) }
procedure TSciEdit.TrimUndo;
const
  Coalesce = $100;
type
  TAct = record
    Kind, Pos: Integer;
    Text: string;
  end;
var
  Count, Limit, Steps, I, Cut, Len, SavePt, Detach, Tentative, Current: Integer;
  Acts: array of TAct;

  function Moved(P: Integer): Integer;
  begin
    if P < 0 then Result := P
    else if P < Cut then Result := -1
    else Result := P - Cut;
  end;

begin
  if not FTrimPending then Exit;
  FTrimPending := False;
  if not Ready then Exit;
  Limit := EditorOptions.UndoLimit;
  Count := Sci(SCI_GETUNDOACTIONS);
  if (Limit <= 0) or (Count <= Limit) or (Sci(SCI_GETUNDOCURRENT) < Count) then Exit;
  { the steps, counted from the newest; trimmed only well past the limit (it is work) }
  Steps := 0;
  Cut := -1;
  for I := Count - 1 downto 0 do
    if (I = 0) or (Sci(SCI_GETUNDOACTIONTYPE, I - 1) and Coalesce = 0) then
    begin
      Inc(Steps);
      if Steps = Limit then Cut := I;
    end;
  if (Cut <= 0) or (Steps <= Limit + Max(16, Limit div 8)) then Exit;
  SetLength(Acts, Count - Cut);
  for I := Cut to Count - 1 do
    with Acts[I - Cut] do
    begin
      Kind := Sci(SCI_GETUNDOACTIONTYPE, I);
      Pos := Sci(SCI_GETUNDOACTIONPOSITION, I);
      Len := Sci(SCI_GETUNDOACTIONTEXT, I, 0);
      SetLength(Text, Len);
      if Len > 0 then Sci(SCI_GETUNDOACTIONTEXT, I, Integer(PChar(Text)));
    end;
  SavePt := Moved(Sci(SCI_GETUNDOSAVEPOINT));
  Detach := Moved(Sci(SCI_GETUNDODETACH));
  Tentative := Moved(Sci(SCI_GETUNDOTENTATIVE));
  Current := Count - Cut;
  Sci(SCI_EMPTYUNDOBUFFER);
  for I := 0 to High(Acts) do
  begin
    Sci(SCI_PUSHUNDOACTIONTYPE, Acts[I].Kind, Acts[I].Pos);
    SciS(SCI_CHANGELASTUNDOACTIONTEXT, Length(Acts[I].Text), Acts[I].Text);
  end;
  Sci(SCI_SETUNDOSAVEPOINT, Cardinal(SavePt));
  Sci(SCI_SETUNDODETACH, Cardinal(Detach));
  Sci(SCI_SETUNDOTENTATIVE, Cardinal(Tentative));
  Sci(SCI_SETUNDOCURRENT, Current);
end;

{ Editor Options | Group undo off: every keystroke is an undo step of its own (Scintilla joins
  what is typed in a row; an empty undo action between two keys ends that) }
procedure TSciEdit.UndoBoundary;
begin
  if not EditorOptions.GroupUndo and Assigned(FDirectFn) then
  begin
    Sci(SCI_BEGINUNDOACTION);
    Sci(SCI_ENDUNDOACTION);
  end;
end;

{ WM_KEYDOWN, before the window handles it }
procedure TSciEdit.KeyArrives(Key: Word);
begin
  if Key in [VK_BACK, VK_DELETE] then UndoBoundary;
  if (Key in [VK_PRIOR..VK_DOWN]) and (GetKeyState(VK_SHIFT) >= 0) and
    (Sci(SCI_GETMOVEEXTENDSSELECTION) = 0) then KeepBlock;
end;

{ Delphi's smart tab: the caret goes to the column where the next word of the nearest non-blank
  line above starts (blanks or tabs are inserted up to it); False when there is none (a plain tab
  then) or a block is selected }
function TSciEdit.SmartTab: Boolean;
var
  Line, Col, L, P, LineEnd, Target, Tab, Next: Integer;
  S: string;
begin
  Result := False;
  if not Assigned(FDirectFn) or (Sci(SCI_GETSELECTIONEMPTY) = 0) then Exit;
  P := Sci(SCI_GETCURRENTPOS);
  Line := Sci(SCI_LINEFROMPOSITION, P);
  Col := Sci(SCI_GETCOLUMN, P);           // display columns: tabs to their stops, a character one
  L := Line - 1;
  while (L >= 0) and LineBlank(L) do Dec(L);
  if L < 0 then Exit;
  { the first word of that line that starts right of the caret's column: a character that is
    no blank after a blank (blanks are single bytes in every encoding) }
  Target := -1;
  P := Sci(SCI_FINDCOLUMN, L, Col);
  LineEnd := LineEndPos(L);
  while P < LineEnd do
  begin
    Next := Sci(SCI_POSITIONAFTER, P);
    if (Next >= LineEnd) or (Next <= P) then Break;
    if (CharAt(P) in [' ', #9]) and not (CharAt(Next) in [' ', #9]) and
      (Sci(SCI_GETCOLUMN, Next) > Col) then
    begin
      Target := Sci(SCI_GETCOLUMN, Next);
      Break;
    end;
    P := Next;
  end;
  if Target <= Col then Exit;
  { blanks up to it; Optimal fill (and Use tab character) fill with tabs first }
  S := '';
  if FFileType.UseTabChar or FFileType.OptimalFill then
  begin
    Tab := Sci(SCI_GETTABWIDTH);
    if Tab > 0 then
      while (Col div Tab + 1) * Tab <= Target do
      begin
        S := S + #9;
        Col := (Col div Tab + 1) * Tab;
      end;
  end;
  SciS(SCI_REPLACESEL, 0, S + StringOfChar(' ', Target - Col));
  Result := True;
end;

{ WM_LBUTTONDOWN: True - the editor took the press (the window passes it on to Scintilla else) }
function TSciEdit.MouseDownArrives(Keys, X, Y: Integer): Boolean;
var
  P, S, E: Integer;
begin
  Result := True;
  { Typing | Ctrl+Alt+click: one more caret where the text is clicked }
  if (Keys and MK_CONTROL <> 0) and (GetKeyState(VK_MENU) < 0) and EditorOptions.CaretClick and Ready then
  begin
    if X >= TextAreaLeft then
    begin
      if not Focused and CanFocus then SetFocus;
      P := Sci(SCI_POSITIONFROMPOINT, X, Y);
      Sci(SCI_ADDSELECTION, P, P);
      Exit;
    end;
  end;
  { Persistent blocks: a click elsewhere keeps the selection as the block }
  if Keys and MK_SHIFT = 0 then KeepBlock;
  if (Keys and MK_CONTROL <> 0) and (Keys and MK_SHIFT = 0) and
    (GetKeyState(VK_MENU) >= 0) and Assigned(FOnCtrlClick) then
  begin
    P := PosFromPoint(X, Y);
    if LinkWordAt(P, S, E) then
    begin
      ClearLink;
      if not Focused and CanFocus then SetFocus;
      FOnCtrlClick(Self, P);
      Exit;
    end;
  end;
  Result := False;
end;

{ --- Ctrl+click navigation: while Ctrl is held, the identifier under the mouse is a link
      (blue underline) and the pointer is the link hand, as in the Delphi editor --- }

procedure TSciEdit.RefreshCursor;
var
  P: TPoint;
begin
  { the pointer follows the link state at once, not at the next mouse move }
  if not Shown or not FWindow.HandleAllocated then Exit;
  GetCursorPos(P);
  if WindowFromPoint(P) = FWindow.Handle then
    FWindow.Perform(WM_SETCURSOR, FWindow.Handle, MakeLong(Word(FWindow.Perform(WM_NCHITTEST, 0,
      MakeLong(P.X, P.Y))), WM_MOUSEMOVE));
end;

procedure TSciEdit.ShowLink(S, E: Integer);
begin
  { blue and underlined, like a hyperlink; S < 0 removes it }
  ClearIndicator(IND_LINK);
  if S >= 0 then FillIndicator(IND_LINK, S, E - S);
  ClearIndicator(IND_LINKTEXT);
  if S >= 0 then FillIndicator(IND_LINKTEXT, S, E - S);
  FLinkStart := S;
  FLinkEnd := E;
  RefreshCursor;
end;

procedure TSciEdit.ClearLink;
begin
  if FLinkStart >= 0 then ShowLink(-1, -1);
end;

{ a word of code at P (S..E) that Ctrl makes a link: not in a comment or a string }
function TSciEdit.LinkWordAt(P: Integer; out S, E: Integer): Boolean;
begin
  Result := (P >= 0) and (WordAt(P, S, E) <> '') and not IsCommentOrString(P);
end;

procedure TSciEdit.LinkAtPoint(X, Y: Integer);
var
  P, S, E: Integer;
begin
  P := PosFromPoint(X, Y);
  if LinkWordAt(P, S, E) then
  begin
    if (S <> FLinkStart) or (E <> FLinkEnd) then ShowLink(S, E);
  end
  else
    ClearLink;
end;

{ WM_SETCURSOR: True - over the text while a link is showing, the link hand instead of
  Scintilla's I-beam (set here) }
function TSciEdit.LinkCursor(HitTest: Integer): Boolean;
var
  Hand: HCURSOR;
begin
  FHandCursor := (FLinkStart >= 0) and (HitTest = HTCLIENT);
  Result := FHandCursor;
  if Result then
  begin
    Hand := LoadCursor(0, IDC_HAND);
    if Hand = 0 then Hand := Screen.Cursors[crHandPoint];
    Windows.SetCursor(Hand);
  end;
end;

{ a press of the left button on a sample, for OnSampleClick: its margin by the margins' widths
  (left to right in their order), else the text's character under it (none beyond a line's
  end), and its line }
procedure TSciEdit.SampleClicked(X, Y: Integer);
var
  M, Right, Margin, P, Line: Integer;
begin
  if not Assigned(FOnSampleClick) then Exit;
  Margin := -1;
  Right := 0;
  for M := MARGIN_NUMBERS to MARGIN_FOLD do
  begin
    Inc(Right, Sci(SCI_GETMARGINWIDTHN, M));
    if (Margin < 0) and (X < Right) then Margin := M;
  end;
  Line := LineFromPos(Sci(SCI_POSITIONFROMPOINT, X, Y));
  if Margin < 0 then P := Sci(SCI_POSITIONFROMPOINTCLOSE, X, Y) else P := -1;
  FOnSampleClick(Self, P, Line, Margin);
end;

{ WM_MOUSEMOVE, after the window handled it }
procedure TSciEdit.MouseMoved(Keys, X, Y: Integer);
begin
  if (Keys and MK_CONTROL <> 0) and (Keys and (MK_LBUTTON or MK_SHIFT) = 0) and
    (GetKeyState(VK_MENU) >= 0) and Assigned(FOnCtrlClick) then
    LinkAtPoint(X, Y)
  else
    ClearLink;
end;

procedure TSciEdit.KeyDown(var Key: Word; Shift: TShiftState);
var
  P: TPoint;
begin
  if Assigned(FOnKeyDown) then FOnKeyDown(Self, Key, Shift);
  { Tab with Smart tab (Source Options): to the start of the next word of the line above - after
    the key handler (OnKeyDown), which may take the key: the completion list's Tab accepts }
  if (Key = VK_TAB) and (Shift * [ssShift, ssCtrl] = []) and FFileType.SmartTab and SmartTab then
  begin
    FSwallowTab := True;              // its WM_CHAR goes
    Key := 0;                         // Scintilla does not get it
  end;
  { Auto-close pairs: Backspace between a bracket and the partner put in for it takes both }
  if (Key = VK_BACK) and (Shift * [ssCtrl, ssAlt] = []) and AutoCloseBack then
  begin
    FSwallowBack := True;
    Key := 0;
  end;
  { Esc: the find matches go (Scintilla's Esc drops the other carets) }
  if (Key = VK_ESCAPE) and (FFindText <> '') then MarkMatches('', False, False, False);
  { Ctrl pressed while the mouse rests on an identifier: the link appears without a mouse move }
  if (Key = VK_CONTROL) and (Shift * [ssShift, ssAlt, ssLeft] = []) and Assigned(FOnCtrlClick) and
    (Handle <> 0) then
  begin
    GetCursorPos(P);
    if WindowFromPoint(P) = Handle then
    begin
      Windows.ScreenToClient(Handle, P);
      LinkAtPoint(P.X, P.Y);
    end;
  end;
end;

function TSciEdit.LinkRange: string;
begin
  if FLinkStart >= 0 then Result := Format('%d-%d %s', [FLinkStart, FLinkEnd, GetRange(FLinkStart, FLinkEnd)])
  else Result := '';
  if FHandCursor then Result := Result + ' [hand]';
end;

{ a notification of the window while it shows the editor }
procedure TSciEdit.Notify(N: PSCNotification);
var
  Shift: TShiftState;
  L: Integer;
begin
  case N^.code of
    { no lexer (Scintilla's container lexing): an expert's highlighter styles the lines }
    SCN_STYLENEEDED:
      if FLanguage = slExpert then StyleNeeded(N^.position);
    SCN_CHARADDED:
      begin
        { Auto-close pairs: the partner of the bracket or quote just typed, after the caret }
        if (FPendingClose <> #0) and (N^.ch = Ord(FPendingOpen)) then
        begin
          L := CaretPos;
          InsertText(L, FPendingClose);
          FillIndicator(IND_AUTOCLOSE, L, 1);
          FAutoCloseLine := LineFromPos(L);
        end;
        FPendingClose := #0;
        if (N^.ch = 10) or ((N^.ch = 13) and (FEolMode = SC_EOL_CR)) then
        begin
          { the line just ended may end with a word to put under its block's opener }
          L := CaretLine - 1;
          if L >= 0 then
          begin
            L := LineEndPos(L);
            while (L > 0) and (CharAt(L - 1) in [' ', #9]) do Dec(L);
            TypedWordEnd(L);
          end;
          if FFileType.AutoIndent then
          begin
            DoAutoIndent;
            TypedLineEnd;
          end;
        end
        else if (N^.ch < 128) and not IdentTab[Chr(N^.ch)] then
          TypedWordEnd(CaretPos - 1);
        if Assigned(FOnCharAdded) then FOnCharAdded(Self, N^.ch);
      end;
    SCN_UPDATEUI:
      begin
        if FLineForeDirty then RefreshLineColours;
        if FBlockShown and (Sci(SCI_GETSELECTIONEMPTY) = 0) then
        begin
          FBlockShown := False;
          PaintBlock;
        end;
        { a line block drawn without Persistent blocks is marked only while the caret is at one of
          its ends; a block an edit moved is drawn again (its ends follow Delphi's rule, the
          indicator Scintilla's) }
        if FBlockShown and not EditorOptions.PersistentBlocks and (FBlockMode = sbLine) and
          not CaretAtBlock then
        begin
          FBlockShown := False;
          PaintBlock;
        end;
        if FBlockPaint then
        begin
          FBlockPaint := False;
          if FBlockShown then PaintBlock;
        end;
        { the partners Auto-close pairs put in are forgotten when the caret leaves their line }
        if (FAutoCloseLine >= 0) and (CaretLine <> FAutoCloseLine) then
        begin
          ClearIndicator(IND_AUTOCLOSE);
          FAutoCloseLine := -1;
        end;
        if N^.updated and (SC_UPDATE_SELECTION or SC_UPDATE_CONTENT) <> 0 then UpdateMatching;
        if EditorOptions.HighlightOccurrences and not FSample and (N^.updated and SC_UPDATE_SELECTION <> 0) then
          UpdateOccurrences;
        if Assigned(FOnUpdateUI) then FOnUpdateUI(Self, N^.updated);
        { (the handler may have shown another editor in the window) }
        if Bars = nil then Exit;
        Bars.Update;
        { the caret's marker in the scroll bar }
        if EditorOptions.ScrollBarMarkers and (Sci(SCI_VISIBLEFROMDOCLINE, CaretLine) <> FWindow.FBarCaret) then
          Bars.Paint;
      end;
    SCN_PAINTED:
      if Bars <> nil then Bars.Update;    // the lines, the widest line, the size: the bars follow
    SCN_MODIFIED:
      begin
        FTextValid := False;
        FText := '';
        if N^.linesAdded <> 0 then SetupLineNumbers(False);    // the other margins stay as they are
        if N^.modificationType and SC_MOD_INSERTTEXT <> 0 then AdjustBlock(N^.position, N^.length, True)
        else if N^.modificationType and SC_MOD_DELETETEXT <> 0 then AdjustBlock(N^.position, N^.length, False);
        { Editor Options | Undo limit: after a change made by typing (not in this notification) }
        if (N^.modificationType and SC_PERFORMED_USER <> 0) and (EditorOptions.UndoLimit > 0) and
          not FTrimPending and (Handle <> 0) then
        begin
          FTrimPending := True;
          PostMessage(Handle, WM_SCITRIMUNDO, 0, 0);
        end;
        { (not SCI_MARKERNEXT here: once a line had any marker it walks every line, at each
          keystroke) }
        if FLineMarks then FLineForeDirty := True;
        { the highlights that follow the text are made again after a pause }
        FBlocksStale := True;
        FMarksDirty := True;
        if FFindText <> '' then FFindStale := True;
        ScheduleIdle;
        if Assigned(FOnModified) then
          FOnModified(Self, N^.modificationType, N^.position, N^.length, N^.linesAdded);
      end;
    SCN_SAVEPOINTREACHED, SCN_SAVEPOINTLEFT:
      begin
        { an edit that leaves the save point says so after the text changed and before its
          SCN_MODIFIED: the text read last is no longer the document's }
        if N^.code = SCN_SAVEPOINTLEFT then
        begin
          FTextValid := False;
          FText := '';
        end;
        if Assigned(FOnSavePointChange) then FOnSavePointChange(Self);
      end;
    { Editor Options | Double click line: the line, not the word }
    SCN_DOUBLECLICK:
      if EditorOptions.DoubleClickLine and (N^.line >= 0) then
        Sci(SCI_SETSEL, PosFromLine(N^.line), LineEndPos(N^.line));
    SCN_MARGINCLICK:
      begin
        Shift := [];
        if N^.modifiers and SCMOD_SHIFT <> 0 then Include(Shift, ssShift);
        if N^.modifiers and SCMOD_CTRL <> 0 then Include(Shift, ssCtrl);
        if N^.modifiers and SCMOD_ALT <> 0 then Include(Shift, ssAlt);
        if Assigned(FOnMarginClick) then
          FOnMarginClick(Self, N^.margin, Sci(SCI_LINEFROMPOSITION, N^.position), Shift);
      end;
    SCN_DWELLSTART:
      if Assigned(FOnDwellStart) then FOnDwellStart(Self, N^.position, N^.x, N^.y);
    SCN_DWELLEND:
      if Assigned(FOnDwellEnd) then FOnDwellEnd(Self);
    SCN_ZOOM:
      begin
        SetupMargins;
        { Ctrl+wheel on a file's editor: every file's editor takes the zoom (not a sample's) }
        L := Sci(SCI_GETZOOM);
        if Assigned(FOnZoom) and (L <> EditorOptions.Zoom) then
        begin
          EditorOptions.Zoom := L;
          FOnZoom(Self);
        end;
      end;
  end;
end;

const
  MaxTokenLine = 1024;     // Delphi 7's editor kernel tokenizes this much of a line, the rest is plain
  CodePlainText = 14;      // ToolsAPI's SyntaxOff: the Color page's Plain text
  { the theme's element of each code of an expert's highlighter (ToolsAPI's atWhiteSpace ..
    atScripts): the Pascal element nearest to it - floats and octals are numbers, HTML's tags
    reserved words, its attributes' names identifiers and their values strings; an illegal
    character, a script, 18, 19 and 24 .. 31 plain text }
  ExpertElements: array[0..31] of TEditorElement = (eePlainText, eeComment, eeReservedWord,
    eeIdentifier, eeSymbol, eeString, eeNumber, eeNumber, eeNumber, eeHex, eeCharacter,
    eeDirective, eePlainText, eeAssembler, eePlainText, eeSelection, eeSearchMatch,
    eeHotLink, eePlainText, eePlainText, eeReservedWord, eeIdentifier, eeString, eePlainText,
    eePlainText, eePlainText, eePlainText, eePlainText, eePlainText, eePlainText, eePlainText,
    eePlainText);

{ The lines from the first one not styled yet to the one of EndPos, styled by the file type's
  highlighter as Delphi 7's editor kernel asks it: each line with the class the line before it
  ended in (Scintilla's line state), its bytes without the line break. Scintilla styles again
  from the first changed place at every change, so the lines below an edit follow it - Delphi's
  "until the class is the same again". Without a highlighter (an expert's package went) the
  text is plain. }
procedure TSciEdit.StyleNeeded(EndPos: Integer);
var
  T: TSciTokenizer;
  L, First, Last, Lines, S, E, N, Next: Integer;
  Cls: Byte;
  P: PChar;
  Nul: Char;
  Codes: array[0..MaxTokenLine - 1] of Byte;
begin
  Nul := #0;
  if Assigned(SciTokenizerFor) then T := SciTokenizerFor(FFileType.Highlighter) else T := nil;
  Lines := LineCount;
  First := LineFromPos(Sci(SCI_GETENDSTYLED));
  Last := LineFromPos(EndPos);
  for L := First to Last do
  begin
    S := PosFromLine(L);
    E := LineEndPos(L);
    if L + 1 < Lines then Next := PosFromLine(L + 1) else Next := TextLength;
    N := E - S;
    if N > MaxTokenLine then N := MaxTokenLine;
    if L = 0 then Cls := 0 else Cls := Byte(Sci(SCI_GETLINESTATE, L - 1));
    FillChar(Codes, SizeOf(Codes), CodePlainText);
    if N > 0 then P := PChar(Sci(SCI_GETRANGEPOINTER, S, N)) else P := @Nul;
    if (T <> nil) and (N > 0) then T.Tokenize(Cls, P, N, @Codes[0]);
    { the class before the styles are set: P points into the text Scintilla keeps }
    if T <> nil then Cls := T.LineClass(Cls, P, N) else Cls := 0;
    Sci(SCI_STARTSTYLING, S);
    if N > 0 then Sci(SCI_SETSTYLINGEX, N, Integer(@Codes[0]));
    if Next - S - N > 0 then Sci(SCI_SETSTYLING, Next - S - N, CodePlainText);
    Sci(SCI_SETLINESTATE, L, Cls);
  end;
end;

{ --- the key mapping (SdKeymaps) and the block --- }

{ the key types a character the editor takes as text (TranslateMessage makes a WM_CHAR of 32 or
  more): no Ctrl and no Alt, or both (AltGr), on a key of the layout that has a character }
function TypesChar(Key: Word; Shift: TShiftState): Boolean;
const
  MAPVK_VK_TO_CHAR = 2;
begin
  Result := ((Shift * [ssCtrl, ssAlt] = []) or (Shift * [ssCtrl, ssAlt] = [ssCtrl, ssAlt])) and
    (MapVirtualKey(Key, MAPVK_VK_TO_CHAR) >= 32);
end;

{ A key handled while a keystroke macro records (Delphi 7's rule): it goes into the macro when the
  editor handled it (the key mapping, an expert's binding, a menu's shortcut) or it types no
  character - a key that types one is recorded as that character (WMChar); the services add it
  only when the macro was recording before the key and still is, so the key that starts or stops
  the recording is not in it. }
procedure TSciEdit.KeyDispatched(Key: Word; Shift: TShiftState; Handled: Boolean);
begin
  if Assigned(SciMacroKeyEnd) then
    SciMacroKeyEnd(Self, Key, Shift, not (Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN, VK_CAPITAL]) and
      (Handled or not TypesChar(Key, Shift)));
end;

{ the keys and characters go to the window the document is in (the worker's too: a macro played
  on a file that is not shown) }
procedure TSciEdit.PlayKey(Key: Word; Shift: TShiftState);
var
  Old, KS: TKeyboardState;
  Data: Integer;
  W: TSciWindow;
begin
  if not Attach then Exit;
  W := FWindow;
  GetKeyboardState(Old);
  KS := Old;
  if ssShift in Shift then KS[VK_SHIFT] := $80 else KS[VK_SHIFT] := 0;
  if ssCtrl in Shift then KS[VK_CONTROL] := $80 else KS[VK_CONTROL] := 0;
  if ssAlt in Shift then KS[VK_MENU] := $80 else KS[VK_MENU] := 0;
  SetKeyboardState(KS);
  try
    Data := 1;
    if ssAlt in Shift then
    begin
      Data := Data or $20000000;
      if W.Perform(CN_SYSKEYDOWN, Key, Data) = 0 then W.Perform(WM_SYSKEYDOWN, Key, Data);
    end
    else if W.Perform(CN_KEYDOWN, Key, Data) = 0 then
    begin
      W.Perform(WM_KEYDOWN, Key, Data);
      { the control character the key types besides (TranslateMessage), as the editor gets it }
      if (Shift * [ssCtrl] = []) and ((Key = VK_RETURN) or (Key = VK_TAB) or (Key = VK_BACK) or (Key = VK_ESCAPE)) then
        W.Perform(WM_CHAR, MapVirtualKey(Key, 2), 1);
    end;
  finally
    SetKeyboardState(Old);
  end;
end;

procedure TSciEdit.PlayChar(Ch: Char);
begin
  if Attach then FWindow.Perform(WM_CHAR, Ord(Ch), 1);
end;

procedure TSciEdit.BeginKeyPlayback;
begin
  if Ready then Sci(SCI_BEGINUNDOACTION);
end;

procedure TSciEdit.EndKeyPlayback;
begin
  if Ready then Sci(SCI_ENDUNDOACTION);
end;

function TSciEdit.MenuCommand(const Command: string): Boolean;
begin
  Result := Assigned(SciMenuCommandHook) and SciMenuCommandHook(Self, Command);
end;

function TSciEdit.KeymapKey(Key: Word; Shift: TShiftState): Boolean;
var
  Cmd: TEdCmd;
  Arg: Integer;
  Hook: TSciKeyHookResult;
begin
  Result := False;
  if (Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN, VK_CAPITAL]) or not Ready then Exit;
  { the hook first - inside a chord too: an expert's sequence may begin with the chord's first key;
    a key it took ends the chord }
  Hook := khNone;
  if Assigned(SciKeyHook) then Hook := SciKeyHook(Self, Key, Shift, FKeyPrefix <> 0);
  if Hook = khHandled then
  begin
    FKeyPrefix := 0;
    Result := True;
    Exit;
  end;
  if Hook = khMenu then
  begin
    FKeyPrefix := 0;
    Exit;
  end;
  case KeymapLookup(Keymap(EditorOptions.Keymapping), FKeyPrefix, ShortCut(Key, Shift), Cmd, Arg) of
    kmPrefix: Result := True;
    kmCancel:
      begin
        MessageBeep(0);
        Result := True;
      end;
    kmCommand:
      begin
        ExecCommand(Cmd, Arg);
        Result := True;
      end;
  end;
  { handled in part: the key mapping had its turn, no menu shortcut follows }
  if Hook = khPassOn then Result := True;
end;

function TSciEdit.BlockRange(out A, B: Integer): Boolean;
begin
  A := SelStart;
  B := SelEnd;
  Result := B > A;
  if Result then Exit;
  Result := FBlockShown and (FBlockA >= 0) and (FBlockB > FBlockA);
  if Result then
  begin
    A := FBlockA;
    B := FBlockB;
  end;
end;

procedure TSciEdit.PaintBlock;
begin
  if not Ready then Exit;
  ClearIndicator(IND_BLOCK);
  if FBlockShown and (FBlockA >= 0) and (FBlockB > FBlockA) then
    FillIndicator(IND_BLOCK, FBlockA, FBlockB - FBlockA);
  PaintBlockShape;
end;

{ the block from A to B: with Persistent blocks drawn and kept, else the selection }
procedure TSciEdit.SetBlock(A, B: Integer);
begin
  NoteUserBlock;
  FBlockA := A;
  FBlockB := B;
  if (A < 0) or (B <= A) then Exit;
  if EditorOptions.PersistentBlocks then
  begin
    FBlockShown := True;
    Sci(SCI_SETEMPTYSELECTION, CaretPos);
    PaintBlock;
  end
  else
    Sci(SCI_SETSEL, A, B);
end;

{ Persistent blocks: the caret leaves a selection - it stays as the block }
procedure TSciEdit.KeepBlock;
var
  A, B: Integer;
begin
  if not EditorOptions.PersistentBlocks or not Ready or (Sci(SCI_GETSELECTIONEMPTY) <> 0) then Exit;
  A := SelStart;
  B := SelEnd;
  FBlockA := A;
  FBlockB := B;
  FBlockShown := True;
  Sci(SCI_SETEMPTYSELECTION, CaretPos);
  NoteUserBlock;
  PaintBlock;
end;

{ the block's ends follow the edits as Delphi 7's do (measured): text that goes in exactly at the
  block's start lands before it, at its end after it - an empty block's ends both go on -, a
  deletion takes an end inside it to its start. Scintilla moves the indicator by a rule of its own
  (text at the end of a range stays outside it; a line or column block covers other text): a
  drawn block is drawn again at the next update. }
procedure TSciEdit.AdjustBlock(Pos, Len: Integer; Inserted: Boolean);

  { AtEnd: the block's end - the larger of its ends }
  function Moved(P: Integer; AtEnd: Boolean): Integer;
  begin
    Result := P;
    if P < 0 then Exit;
    if Inserted then
    begin
      if (Pos < P) or ((Pos = P) and not AtEnd) then Inc(Result, Len);
    end
    else if Pos < P then
      Result := Max(Pos, P - Len);
  end;

var
  OldA, OldB: Integer;
begin
  OldA := FBlockA;
  OldB := FBlockB;
  FBlockA := Moved(OldA, OldA > OldB);
  FBlockB := Moved(OldB, OldB > OldA);
  if FBlockShown and ((FBlockMode <> sbNonInclusive) or (Inserted and (Pos = OldB))) then
    FBlockPaint := True;
  AdjustBlockImage(Pos, Len, Inserted);
end;

procedure TSciEdit.RangeCase(A, B: Integer; Upper: Boolean);
var
  S, E: Integer;
begin
  S := Sci(SCI_GETANCHOR);
  E := CaretPos;
  Sci(SCI_SETSEL, A, B);
  if Upper then Sci(SCI_UPPERCASE) else Sci(SCI_LOWERCASE);
  Sci(SCI_SETSEL, S, E);
end;

{ the lines from A to B in by Delta columns (out: negative) - the file type's Block indent }
procedure TSciEdit.IndentLines(A, B, Delta: Integer);
var
  L, L2: Integer;
begin
  L2 := LineFromPos(B);
  if (L2 > LineFromPos(A)) and (B = PosFromLine(L2)) then Dec(L2);
  BeginUndo;
  try
    for L := LineFromPos(A) to L2 do
      Sci(SCI_SETLINEINDENTATION, L, Max(0, Sci(SCI_GETLINEINDENTATION, L) + Delta));
  finally
    EndUndo;
  end;
end;

{ --- the buffer's block of the Open Tools API ---

  Delphi 7's editor keeps one block per buffer, apart from its cursor: a kind (TSciBlockMode), two
  ends - characters, which follow the edits - or a column block's two corners on the screen, which
  do not, and a hidden flag. The block Persistent blocks keeps (FBlockA / FBlockB, IND_BLOCK) is
  that block. Shown (PublishBlock): with Persistent blocks it is drawn; without them a marked
  block is the main selection - a line block is drawn (a line selection takes the caret to a
  line's end) -, one that is not marked is not shown.
  Scintilla's main selection is either the image the block calls left (FBlockSel, moved with the
  edits as Scintilla moves its selection) or newer: a selection then becomes the block (SyncBlock,
  at the next call), and without Persistent blocks a caret moved meanwhile collapses it, as
  Delphi's cursor keys do at once. }

function SameSelImage(const A, B: TSciSelImage): Boolean;
begin
  Result := (A.Mode = B.Mode) and (A.Anchor = B.Anchor) and (A.Caret = B.Caret) and
    (A.AnchorV = B.AnchorV) and (A.CaretV = B.CaretV);
end;

{ a column block's corners as its top-left and its bottom-right one }
function NormRows(const R: TRect): TRect;
begin
  Result.Left := Min(R.Left, R.Right);
  Result.Top := Min(R.Top, R.Bottom);
  Result.Right := Max(R.Left, R.Right);
  Result.Bottom := Max(R.Top, R.Bottom);
end;

function TSciEdit.SelImage: TSciSelImage;
var
  M: Integer;
begin
  Result.Mode := Sci(SCI_GETSELECTIONMODE);
  if Sci(SCI_SELECTIONISRECTANGLE) <> 0 then
  begin
    Result.Anchor := Sci(SCI_GETRECTANGULARSELECTIONANCHOR);
    Result.Caret := Sci(SCI_GETRECTANGULARSELECTIONCARET);
    Result.AnchorV := Sci(SCI_GETRECTANGULARSELECTIONANCHORVIRTUALSPACE);
    Result.CaretV := Sci(SCI_GETRECTANGULARSELECTIONCARETVIRTUALSPACE);
  end
  else
  begin
    M := Sci(SCI_GETMAINSELECTION);
    Result.Anchor := Sci(SCI_GETSELECTIONNANCHOR, M);
    Result.Caret := Sci(SCI_GETSELECTIONNCARET, M);
    Result.AnchorV := Sci(SCI_GETSELECTIONNANCHORVIRTUALSPACE, M);
    Result.CaretV := Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE, M);
  end;
end;

{ FBlockSel moved by an edit as Scintilla moves its selection (SelectionRange.MoveForInsertDelete,
  before it sends SCN_MODIFIED): what a writer, the formatter or a completion changes is no move
  of the user's }
procedure TSciEdit.AdjustBlockImage(Pos, Len: Integer; Inserted: Boolean);

  procedure MoveEnd(var P, V: Integer; ForEqual: Boolean);
  var
    R: Integer;
  begin
    if Inserted then
    begin
      if P = Pos then
      begin
        { text that goes in at the place fills its virtual space first }
        R := Min(Len, V);
        Dec(V, R);
        Inc(P, R);
        if ForEqual then Inc(P, Len - R);
      end
      else if P > Pos then
        Inc(P, Len);
    end
    else
    begin
      if P = Pos then V := 0;
      if P > Pos then
        if P > Pos + Len then
          Dec(P, Len)
        else
        begin
          P := Pos;
          V := 0;
        end;
    end;
  end;

var
  CaretFirst, AnchorFirst: Boolean;
begin
  if FBlockSel.Caret < 0 then Exit;
  CaretFirst := FBlockSel.Caret < FBlockSel.Anchor;
  AnchorFirst := FBlockSel.Anchor < FBlockSel.Caret;
  MoveEnd(FBlockSel.Caret, FBlockSel.CaretV, CaretFirst);
  MoveEnd(FBlockSel.Anchor, FBlockSel.AnchorV, AnchorFirst);
end;

function TSciEdit.CaretVirt: Integer;
begin
  Result := Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE, Sci(SCI_GETMAINSELECTION));
end;

{ the caret at P and V columns past it (virtual space at a line's end), the selection empty }
procedure TSciEdit.SetCaretAt(P, V: Integer);
begin
  Sci(SCI_SETEMPTYSELECTION, P);
  if V > 0 then
  begin
    Sci(SCI_SETSELECTIONNANCHORVIRTUALSPACE, 0, V);
    Sci(SCI_SETSELECTIONNCARETVIRTUALSPACE, 0, V);
  end;
end;

{ ... and the column it stands at chosen for the moves up and down }
procedure TSciEdit.PlaceCaret(P, V: Integer);
begin
  if P < 0 then P := 0;
  if P > TextLength then P := TextLength;
  SetCaretAt(P, V);
  Sci(SCI_CHOOSECARETX);
end;

procedure TSciEdit.ColumnPlace(Line, Col: Integer; out P, V: Integer);
var
  E: Integer;
begin
  P := Sci(SCI_FINDCOLUMN, Line, Col);
  V := 0;
  E := LineEndPos(Line);
  if P >= E then
  begin
    P := E;
    V := Max(0, Col - Sci(SCI_GETCOLUMN, E));
  end;
end;

{ Delphi's rule: a stream block needs its ends, a non-inclusive one the first before the second;
  a column block its corners (in any order: their rows and columns are sorted) }
function TSciEdit.BlockValid: Boolean;
begin
  case FBlockMode of
    sbColumn:
      Result := (FBlockRows.Left >= 0) and (FBlockRows.Top >= 0) and (FBlockRows.Right >= 0) and
        (FBlockRows.Bottom >= 0);
    sbNonInclusive:
      Result := (FBlockA >= 0) and (FBlockB > FBlockA);
  else
    Result := (FBlockA >= 0) and (FBlockB >= FBlockA);
  end;
end;

{ a column block's cell of position P with V virtual spaces after it: its line and display column }
procedure TSciEdit.PlaceCell(P, V: Integer; out Line, Col: Integer);
begin
  Line := LineFromPos(P);
  Col := Sci(SCI_GETCOLUMN, P) + V;
end;

{ the caret at one of the block's ends - a column block's: at one of its four corners (a stream
  block's end at a line's end takes a caret in the virtual space after it as well) }
function TSciEdit.CaretAtBlock: Boolean;
var
  P, L, C: Integer;
begin
  P := CaretPos;
  if FBlockMode = sbColumn then
  begin
    PlaceCell(P, CaretVirt, L, C);
    Result := ((L = FBlockRows.Top) or (L = FBlockRows.Bottom)) and
      ((C = FBlockRows.Left) or (C = FBlockRows.Right));
  end
  else
    Result := (P = FBlockA) or (P = FBlockB);
end;

{ Delphi's marked block: valid, not hidden, and Persistent blocks or the caret at the block }
function TSciEdit.BlockIsMarked: Boolean;
begin
  Result := not FBlockHidden and BlockValid and (EditorOptions.PersistentBlocks or CaretAtBlock);
end;

{ what a stream block takes (Delphi's adjustment by its kind): from the smaller end to the larger,
  an inclusive block with the character there (at a line's end its line break), a line block from
  the start of its first line to the start of the line after its last }
function TSciEdit.BlockSpan(out S, E: Integer): Boolean;
var
  L: Integer;
begin
  S := Min(FBlockA, FBlockB);
  E := Max(FBlockA, FBlockB);
  Result := S >= 0;
  if not Result then Exit;
  case FBlockMode of
    sbInclusive:
      E := Sci(SCI_POSITIONAFTER, E);
    sbLine:
      begin
        S := PosFromLine(LineFromPos(S));
        L := LineFromPos(E) + 1;
        if L < LineCount then E := PosFromLine(L) else E := TextLength;
      end;
  end;
end;

{ the lines of a column block that the text has }
function TSciEdit.BlockRowRange(out First, Last: Integer): Boolean;
var
  R: TRect;
begin
  R := NormRows(FBlockRows);
  First := R.Top;
  Last := Min(R.Bottom, LineCount - 1);
  Result := (First >= 0) and (First <= Last);
end;

{ a column block's part of a line: from its left column up to its right one (the edge, outside);
  False when the line has nothing there }
function TSciEdit.BlockRow(Line: Integer; out S, E: Integer): Boolean;
var
  R: TRect;
begin
  R := NormRows(FBlockRows);
  S := Sci(SCI_FINDCOLUMN, Line, R.Left);
  E := Sci(SCI_FINDCOLUMN, Line, R.Right);
  Result := E > S;
end;

{ Delphi's collapse: the block hidden, both its ends - a column block's corners - at P, V columns
  of virtual space past it }
procedure TSciEdit.CollapseBlockAt(P, V: Integer);
var
  L, C: Integer;
begin
  FBlockHidden := True;
  if FBlockMode = sbColumn then
  begin
    PlaceCell(P, V, L, C);
    FBlockRows := Rect(C, L, C, L);
  end
  else
  begin
    FBlockA := P;
    FBlockB := P;
  end;
  if FBlockShown then
  begin
    FBlockShown := False;
    PaintBlock;
  end;
end;

procedure TSciEdit.CollapseBlock;
begin
  CollapseBlockAt(CaretPos, CaretVirt);
end;

{ the main selection (Img) as the block: a rectangle a column block (its corners top-left and
  bottom-right), a line selection a line block, any other a non-inclusive block }
procedure TSciEdit.AdoptSelection(const Img: TSciSelImage);
var
  R: TRect;
begin
  case Img.Mode of
    SC_SEL_RECTANGLE, SC_SEL_THIN:
      begin
        R.Left := Sci(SCI_GETCOLUMN, Img.Anchor) + Img.AnchorV;
        R.Top := LineFromPos(Img.Anchor);
        if Img.Mode = SC_SEL_THIN then
          R.Right := R.Left
        else
          R.Right := Sci(SCI_GETCOLUMN, Img.Caret) + Img.CaretV;
        R.Bottom := LineFromPos(Img.Caret);
        FBlockMode := sbColumn;
        FBlockRows := NormRows(R);
        FBlockA := -1;
        FBlockB := -1;
      end;
    SC_SEL_LINES:
      begin
        FBlockMode := sbLine;
        FBlockA := Min(Img.Anchor, Img.Caret);
        FBlockB := Max(Img.Anchor, Img.Caret);
      end;
  else
    FBlockMode := sbNonInclusive;
    FBlockA := Min(Img.Anchor, Img.Caret);
    FBlockB := Max(Img.Anchor, Img.Caret);
  end;
  FBlockHidden := False;
  { the selection shows it (as at SCN_UPDATEUI) }
  if FBlockShown then
  begin
    FBlockShown := False;
    PaintBlock;
  end;
end;

{ the user's work since the last block call: a selection is the block, with its shape; without
  Persistent blocks a caret moved collapses the block at the caret the block calls left (Delphi
  collapses it at the cursor before the move); with them Ctrl+K H hides and shows it }
procedure TSciEdit.SyncBlock;
var
  Cur: TSciSelImage;
  Empty: Boolean;
begin
  Cur := SelImage;
  Empty := Sci(SCI_GETSELECTIONEMPTY) <> 0;
  if not SameSelImage(Cur, FBlockSel) then
  begin
    if not Empty then
      AdoptSelection(Cur)
    else if not EditorOptions.PersistentBlocks and not FBlockHidden and BlockValid then
    begin
      if FBlockSel.Caret >= 0 then CollapseBlockAt(FBlockSel.Caret, FBlockSel.CaretV)
      else CollapseBlock;
    end;
  end;
  if EditorOptions.PersistentBlocks and Empty and (FBlockShown <> FBlockShownLeft) then
    FBlockHidden := not FBlockShown;
  FBlockShownLeft := FBlockShown;
  FBlockSel := Cur;
end;

{ a block of the block commands (Ctrl+K, a selection Persistent blocks keeps): a stream block }
procedure TSciEdit.NoteUserBlock;
begin
  FBlockMode := sbNonInclusive;
  FBlockHidden := False;
  FBlockRows := Rect(-1, -1, -1, -1);
end;

{ the block shown as its state says, the caret where it is: with Persistent blocks drawn (unless
  hidden), the selection empty; without them a marked block is the selection - from its end
  (corner) opposite the caret -, a marked line block drawn, any other not shown }
procedure TSciEdit.PublishBlock;
var
  P, V, L, C, OL, OC, Other, OtherV: Integer;
  Shown, WasShown: Boolean;
begin
  P := CaretPos;
  V := CaretVirt;
  WasShown := FBlockShown;
  Shown := False;
  if EditorOptions.PersistentBlocks then
  begin
    Shown := not FBlockHidden;
    SetCaretAt(P, V);
  end
  else if not BlockIsMarked then
    SetCaretAt(P, V)
  else
    case FBlockMode of
      sbLine:
        begin
          Shown := True;
          SetCaretAt(P, V);
        end;
      sbColumn:
        begin
          PlaceCell(P, V, L, C);
          if L = FBlockRows.Top then OL := FBlockRows.Bottom else OL := FBlockRows.Top;
          if C = FBlockRows.Left then OC := FBlockRows.Right else OC := FBlockRows.Left;
          ColumnPlace(OL, OC, Other, OtherV);
          { a stream selection first: the rectangle takes its anchor and caret }
          Sci(SCI_SETEMPTYSELECTION, P);
          Sci(SCI_SETSELECTION, P, Other);
          Sci(SCI_CHANGESELECTIONMODE, SC_SEL_RECTANGLE);
          Sci(SCI_SETRECTANGULARSELECTIONANCHORVIRTUALSPACE, OtherV);
          Sci(SCI_SETRECTANGULARSELECTIONCARETVIRTUALSPACE, V);
        end;
    else
      if P = FBlockA then Other := FBlockB else Other := FBlockA;
      Sci(SCI_SETEMPTYSELECTION, P);
      Sci(SCI_SETSELECTION, P, Other);
      if V > 0 then Sci(SCI_SETSELECTIONNCARETVIRTUALSPACE, 0, V);
    end;
  FBlockShown := Shown;
  if Shown or WasShown then PaintBlock;
  FBlockShownLeft := FBlockShown;
  FBlockSel := SelImage;
end;

{ what a line, an inclusive or a column block adds to PaintBlock's FBlockA .. FBlockB: its lines,
  its last character, its rows (no virtual space: an indicator lies on text) }
procedure TSciEdit.PaintBlockShape;
var
  L, First, Last, S, E: Integer;
begin
  FBlockPaint := False;
  if not FBlockShown or not BlockValid then Exit;
  case FBlockMode of
    sbInclusive, sbLine:
      if BlockSpan(S, E) and (E > S) then Sci(SCI_INDICATORFILLRANGE, S, E - S);
    sbColumn:
      if BlockRowRange(First, Last) then
        for L := First to Last do
          if BlockRow(L, S, E) then Sci(SCI_INDICATORFILLRANGE, S, E - S);
  end;
end;

function TSciEdit.GetBufferBlock(out Blk: TSciBlock): Boolean;
begin
  Blk.Mode := sbNonInclusive;
  Blk.A := -1;
  Blk.B := -1;
  Blk.Rows := Rect(-1, -1, -1, -1);
  Blk.Hidden := True;
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  Blk.Mode := FBlockMode;
  Blk.A := FBlockA;
  Blk.B := FBlockB;
  Blk.Rows := FBlockRows;
  Blk.Hidden := FBlockHidden;
  Result := BlockValid;
end;

procedure TSciEdit.SetBufferBlock(const Blk: TSciBlock);
begin
  if not Ready then Exit;
  SyncBlock;
  FBlockMode := Blk.Mode;
  FBlockA := Max(-1, Blk.A);
  FBlockB := Max(-1, Blk.B);
  FBlockRows := Blk.Rows;
  FBlockHidden := Blk.Hidden;
  { a column block has no stream ends the drawing or the block commands could take }
  if (FBlockMode = sbColumn) and (FBlockA <> FBlockB) then
  begin
    FBlockA := -1;
    FBlockB := -1;
  end;
  PublishBlock;
end;

function TSciEdit.BlockMarked: Boolean;
begin
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  Result := BlockIsMarked;
end;

function TSciEdit.BlockMarkedSpan(out S, E: Integer): Boolean;
var
  R: TRect;
  First, Last: Integer;
begin
  S := 0;
  E := 0;
  Result := BlockMarked;
  if not Result then Exit;
  if FBlockMode = sbColumn then
  begin
    R := NormRows(FBlockRows);
    Result := BlockRowRange(First, Last);
    if not Result then Exit;
    S := Sci(SCI_FINDCOLUMN, First, R.Left);
    E := Sci(SCI_FINDCOLUMN, Last, R.Right);
  end
  else
    Result := BlockSpan(S, E);
  Result := Result and (E > S);
end;

function TSciEdit.InBlock(Line, Col: Integer): Boolean;
var
  S, E, P, V: Integer;
  R: TRect;
begin
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  if not BlockIsMarked then Exit;
  if FBlockMode = sbColumn then
  begin
    R := NormRows(FBlockRows);
    Result := (Line >= R.Top) and (Line <= R.Bottom) and (Col >= R.Left) and (Col < R.Right);
  end
  else if BlockSpan(S, E) then
  begin
    ColumnPlace(Line, Col, P, V);
    Result := (P >= S) and (P < E);
  end;
end;

{ Delphi's BeginBlock / EndBlock: the first or the second end (corner) at the caret, in no order;
  the block shown }
procedure TSciEdit.BlockSetEnd(First: Boolean);
var
  P, L, C: Integer;
begin
  if not Ready then Exit;
  SyncBlock;
  P := CaretPos;
  if FBlockMode = sbColumn then
  begin
    PlaceCell(P, CaretVirt, L, C);
    if First then
    begin
      FBlockRows.Left := C;
      FBlockRows.Top := L;
    end
    else
    begin
      FBlockRows.Right := C;
      FBlockRows.Bottom := L;
    end;
  end
  else if First then
    FBlockA := P
  else
    FBlockB := P;
  FBlockHidden := False;
  PublishBlock;
end;

{ Delphi's Reset: both ends of both kinds - the stream ends and the corners - at the caret, shown
  (valid when inclusive, line or column: the caret's character, line, column) }
procedure TSciEdit.BlockReset;
var
  P, L, C: Integer;
begin
  if not Ready then Exit;
  SyncBlock;
  P := CaretPos;
  PlaceCell(P, CaretVirt, L, C);
  FBlockA := P;
  FBlockB := P;
  FBlockRows := Rect(C, L, C, L);
  FBlockHidden := False;
  PublishBlock;
end;

procedure TSciEdit.BlockSetMode(Mode: TSciBlockMode; ResetUnmarked: Boolean);
var
  R: TRect;
begin
  if not Ready then Exit;
  SyncBlock;
  if Mode = FBlockMode then Exit;
  if ResetUnmarked and not BlockIsMarked then BlockReset;
  if BlockIsMarked then
    if Mode = sbColumn then
    begin
      R.Left := Sci(SCI_GETCOLUMN, FBlockA);
      R.Top := LineFromPos(FBlockA);
      R.Right := Sci(SCI_GETCOLUMN, FBlockB);
      R.Bottom := LineFromPos(FBlockB);
      FBlockRows := NormRows(R);
      FBlockA := -1;
      FBlockB := -1;
    end
    else if FBlockMode = sbColumn then
    begin
      R := NormRows(FBlockRows);
      FBlockA := Sci(SCI_FINDCOLUMN, R.Top, R.Left);
      FBlockB := Sci(SCI_FINDCOLUMN, R.Bottom, R.Right);
    end;
  FBlockMode := Mode;
  PublishBlock;
end;

procedure TSciEdit.BlockSetHidden(Value: Boolean);
begin
  if not Ready then Exit;
  SyncBlock;
  FBlockHidden := Value;
  PublishBlock;
end;

procedure TSciEdit.BlockCollapse;
begin
  if not Ready then Exit;
  SyncBlock;
  CollapseBlock;
  PublishBlock;
end;

function TSciEdit.BlockExtend(Line, Col: Integer): Boolean;
var
  P, V, L, C, AP, AL, AC: Integer;
begin
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  if Line > LineCount - 1 then Line := LineCount - 1;
  if Line < 0 then Line := 0;
  if Col < 0 then Col := 0;
  P := CaretPos;
  PlaceCell(P, CaretVirt, L, C);
  AP := P;
  AL := L;
  AC := C;
  { the anchor: the end (corner) opposite the caret when the block is marked and the caret at it,
    else the caret - the block collapses there }
  if BlockIsMarked and CaretAtBlock then
  begin
    if FBlockMode = sbColumn then
    begin
      if L = FBlockRows.Top then AL := FBlockRows.Bottom else AL := FBlockRows.Top;
      if C = FBlockRows.Left then AC := FBlockRows.Right else AC := FBlockRows.Left;
    end
    else if P = FBlockA then
      AP := FBlockB
    else
      AP := FBlockA;
  end
  else
    CollapseBlock;
  { the caret there - past a line's end through virtual space -, the block from the anchor }
  ColumnPlace(Line, Col, P, V);
  PlaceCaret(P, V);
  if FBlockMode = sbColumn then
    FBlockRows := NormRows(Rect(AC, AL, Sci(SCI_GETCOLUMN, P) + V, Line))
  else
  begin
    FBlockA := Min(AP, P);
    FBlockB := Max(AP, P);
  end;
  FBlockHidden := False;
  PublishBlock;
  Result := (CaretLine = Line) and (CaretCol + CaretVirt = Col);
end;

function TSciEdit.BlockText: string;
var
  L, First, Last, S, E, N: Integer;
  T: string;
begin
  Result := '';
  if not Ready then Exit;
  SyncBlock;
  if not BlockIsMarked then Exit;
  if FBlockMode <> sbColumn then
  begin
    if BlockSpan(S, E) then Result := GetRange(S, E);
    Exit;
  end;
  { Delphi's column text: each row's part and a line break after it, the last one's too }
  if not BlockRowRange(First, Last) then Exit;
  N := 0;
  for L := First to Last do
  begin
    if BlockRow(L, S, E) then Inc(N, E - S);
    Inc(N, 2);
  end;
  SetLength(Result, N);
  N := 0;
  for L := First to Last do
  begin
    if BlockRow(L, S, E) then
    begin
      T := GetRange(S, E);
      if T <> '' then System.Move(T[1], Result[N + 1], Length(T));
      Inc(N, Length(T));
    end;
    Result[N + 1] := #13;
    Result[N + 2] := #10;
    Inc(N, 2);
  end;
  SetLength(Result, N);
end;

function TSciEdit.BlockDelete: Boolean;
var
  L, First, Last, S, E: Integer;
begin
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  if not BlockIsMarked or ReadOnly then Exit;
  BeginUndo;
  try
    if FBlockMode = sbColumn then
    begin
      if BlockRowRange(First, Last) then
        for L := Last downto First do
          if BlockRow(L, S, E) then DeleteRange(S, E - S);
    end
    else if BlockSpan(S, E) and (E > S) then
      DeleteRange(S, E - S);
  finally
    EndUndo;
  end;
  FBlockHidden := True;
  PublishBlock;
  Result := True;
end;

{ the case of the text S..E: 0 upper, 1 lower, 2 each letter to its other case - Windows' case
  mapping of the characters in the editor's encoding (UTF-8, a code page); a character whose
  other case the code page lacks stays. One replacement, when anything changes. }
procedure TSciEdit.CaseRange(S, E, Kind: Integer);
var
  T, N: string;
  W, W0, C: WideString;
  I, CP: Integer;
  OK, Lost: Boolean;
begin
  T := GetRange(S, E);
  if T = '' then Exit;
  if IsUnicodeEncoding(FEncoding) then CP := CP_UTF8 else CP := FEncoding.CodePage;
  W := ToWide(T, CP, OK);
  if not OK or (W = '') then Exit;
  W0 := W;
  case Kind of
    0: CharUpperBuffW(PWideChar(W), Length(W));
    1: CharLowerBuffW(PWideChar(W), Length(W));
  else
    for I := 1 to Length(W) do
      if IsCharUpperW(W[I]) then CharLowerBuffW(@W[I], 1)
      else if IsCharLowerW(W[I]) then CharUpperBuffW(@W[I], 1);
  end;
  N := FromWide(W, CP, Lost);
  if Lost then
  begin
    for I := 1 to Length(W) do
      if W[I] <> W0[I] then
      begin
        C := W[I];
        FromWide(C, CP, Lost);
        if Lost then W[I] := W0[I];
      end;
    N := FromWide(W, CP, Lost);
  end;
  if N = T then Exit;
  Sci(SCI_SETTARGETRANGE, S, E);
  SciS(SCI_REPLACETARGET, Length(N), N);
end;

{ Delphi's case commands of the block: only the column block's rectangle, the stream block's span.
  The replacements pushed the block's ends along (AdjustBlock): the block and the caret go back -
  what lay after the text moved by the bytes its new case took more or less (UTF-8) }
procedure TSciEdit.BlockCase(Kind: Integer);
var
  L, First, Last, S, E, P, V, Line, Col, A, B, Len0, D, SpanEnd: Integer;
begin
  if not Ready then Exit;
  SyncBlock;
  if not BlockIsMarked or ReadOnly then Exit;
  P := CaretPos;
  V := CaretVirt;
  PlaceCell(P, V, Line, Col);
  A := FBlockA;
  B := FBlockB;
  Len0 := TextLength;
  SpanEnd := -1;
  BeginUndo;
  try
    if FBlockMode = sbColumn then
    begin
      if BlockRowRange(First, Last) then
        for L := First to Last do
          if BlockRow(L, S, E) then CaseRange(S, E, Kind);
    end
    else if BlockSpan(S, E) then
    begin
      CaseRange(S, E, Kind);
      SpanEnd := E;
    end;
  finally
    EndUndo;
  end;
  if FBlockMode = sbColumn then
  begin
    { a corner is a place on the screen: the caret back at its line and column }
    ColumnPlace(Line, Col, P, V);
    SetCaretAt(P, V);
  end
  else
  begin
    D := TextLength - Len0;
    if (SpanEnd >= 0) and (D <> 0) then
    begin
      if A >= SpanEnd then Inc(A, D);
      if B >= SpanEnd then Inc(B, D);
      if P >= SpanEnd then Inc(P, D);
    end;
    FBlockA := A;
    FBlockB := B;
    SetCaretAt(P, V);
  end;
  PublishBlock;
end;

{ Delphi's Indent of the block: a column block's rows at its left column (rows shorter than it
  are left alone) by Magnitude blanks, in or out; a stream block's lines (IndentLines) }
procedure TSciEdit.BlockIndent(Magnitude: Integer);
var
  L, First, Last, P, N, S, E: Integer;
  R: TRect;
begin
  if not Ready or (Magnitude = 0) then Exit;
  SyncBlock;
  if not BlockIsMarked or ReadOnly then Exit;
  if FBlockMode = sbColumn then
  begin
    R := NormRows(FBlockRows);
    if BlockRowRange(First, Last) then
    begin
      BeginUndo;
      try
        for L := First to Last do
        begin
          if Sci(SCI_GETCOLUMN, LineEndPos(L)) <= R.Left then Continue;
          P := Sci(SCI_FINDCOLUMN, L, R.Left);
          if Magnitude > 0 then
            InsertText(P, StringOfChar(' ', Magnitude))
          else
          begin
            N := 0;
            while (N < -Magnitude) and (P + N < LineEndPos(L)) and (CharAt(P + N) = ' ') do Inc(N);
            if N > 0 then DeleteRange(P, N);
          end;
        end;
      finally
        EndUndo;
      end;
    end;
  end
  else if BlockSpan(S, E) then
    IndentLines(S, E, Magnitude);
  PublishBlock;
end;

{ the marked block on the clipboard: its text, and - as Delphi 7's editor writes them -
  "Borland IDE Block Type" (one byte: the kind) and for a column block "MSDEVColumnSelect"
  (Delphi, Scintilla and Visual Studio paste it as a rectangle). Append: the clipboard's text with
  the block's after it, text only. }
procedure TSciEdit.BlockToClipboard(Append: Boolean);
var
  T, Old: string;
  W: WideString;
  Kind: Byte;
begin
  T := BlockText;
  if T = '' then Exit;
  W := EditorToWide(T, FEncoding);
  if not UIOpenClipboard(Handle) then Exit;
  try
    if Append and UIClipboardGet(CF_UNICODETEXT, Old) then
    begin
      { the clipboard's text ends at its first #0 character, also in a block without one }
      Old := Old + #0#0;
      W := PWideChar(Pointer(Old)) + W;
    end;
    EmptyClipboard;
    UIClipboardSet(CF_UNICODETEXT, PWideChar(W), (Length(W) + 1) * SizeOf(WideChar));
    if not Append then
    begin
      Kind := Ord(FBlockMode);
      UIClipboardSet(RegisterClipboardFormat('Borland IDE Block Type'), @Kind, 1);
      if FBlockMode = sbColumn then
      begin
        Kind := 0;
        UIClipboardSet(RegisterClipboardFormat('MSDEVColumnSelect'), @Kind, 1);
      end;
    end;
  finally
    CloseClipboard;
  end;
end;

function TSciEdit.BlockBeforeTyping(Shown: Boolean): Boolean;
begin
  Result := False;
  if not Ready then Exit;
  SyncBlock;
  if not EditorOptions.PersistentBlocks and BlockIsMarked then
    if EditorOptions.OverwriteBlocks then
      Result := BlockDelete
    else
    begin
      CollapseBlock;
      FBlockHidden := not Shown;
    end;
  PublishBlock;
end;

{ Delphi's cursor commands collapse a block that is not hidden before they move the cursor
  (without Persistent blocks) }
procedure TSciEdit.BlockMoveBegin(Kernel: Boolean);
begin
  if not Ready then Exit;
  SyncBlock;
  if Kernel and not EditorOptions.PersistentBlocks and not FBlockHidden and BlockValid then
    CollapseBlock;
end;

procedure TSciEdit.BlockMoveEnd;
begin
  if Ready then PublishBlock;
end;

procedure TSciEdit.MoveCaretKernel(P, Virt: Integer);
begin
  if not Ready then Exit;
  BlockMoveBegin(True);
  PlaceCaret(P, Virt);
  BlockMoveEnd;
end;

procedure TSciEdit.MoveCaretRaw(P, Virt: Integer);
begin
  if not Ready then Exit;
  BlockMoveBegin(False);
  PlaceCaret(P, Virt);
  BlockMoveEnd;
end;

procedure TSciEdit.ExecCommand(Cmd: TEdCmd; Arg: Integer);
var
  A, B, P, Len: Integer;
  T: string;
begin
  if not Ready then Exit;
  case Cmd of
    ecCharLeft: Sci(SCI_CHARLEFT);
    ecCharRight: Sci(SCI_CHARRIGHT);
    ecLineUp: Sci(SCI_LINEUP);
    ecLineDown: Sci(SCI_LINEDOWN);
    ecWordLeft: Sci(SCI_WORDLEFT);
    ecWordRight: Sci(SCI_WORDRIGHT);
    ecLineStart: Sci(SCI_VCHOME);
    ecLineEnd: Sci(SCI_LINEEND);
    ecPageUp: Sci(SCI_PAGEUP);
    ecPageDown: Sci(SCI_PAGEDOWN);
    ecDocStart: Sci(SCI_DOCUMENTSTART);
    ecDocEnd: Sci(SCI_DOCUMENTEND);
    ecWindowTop: Sci(SCI_STUTTEREDPAGEUP);
    ecWindowBottom: Sci(SCI_STUTTEREDPAGEDOWN);
    ecScrollUp: Sci(SCI_LINESCROLLUP);
    ecScrollDown: Sci(SCI_LINESCROLLDOWN);
    ecMatchBrace:
      begin
        P := CaretPos;
        A := Sci(SCI_BRACEMATCH, P, 0);
        if (A < 0) and (P > 0) then A := Sci(SCI_BRACEMATCH, P - 1, 0);
        { else a word of a block: from its opener to its closing word, from the others to its opener }
        if (A < 0) and (Blocks <> nil) then
        begin
          B := FBlocks.WordAt(P);
          if (B >= 0) and (FBlocks.Words[B].Opener >= 0) and (FBlocks.Words[FBlocks.Words[B].Opener].Closer >= 0) then
            if FBlocks.Words[B].Role = wrOpen then A := FBlocks.Words[FBlocks.Words[B].Closer].Start
            else A := FBlocks.Words[FBlocks.Words[B].Opener].Start;
        end;
        if A >= 0 then GotoPos(A) else MessageBeep(0);
      end;
    ecDeleteChar: Sci(SCI_CLEAR);
    ecDeleteCharLeft: Sci(SCI_DELETEBACK);
    ecDeleteWordRight: Sci(SCI_DELWORDRIGHT);
    ecDeleteWordLeft: Sci(SCI_DELWORDLEFT);
    ecDeleteLine: DeleteLine;
    ecDeleteToLineEnd: Sci(SCI_DELLINERIGHT);
    ecDeleteToLineStart: Sci(SCI_DELLINELEFT);
    ecCutLine: Sci(SCI_LINECUT);
    ecInsertLine: InsertText(CaretPos, EolText);
    ecToggleInsert: Sci(SCI_EDITTOGGLEOVERTYPE);
    ecUndo: Undo;
    ecRedo: Redo;
    ecCut: Cut;
    ecCopy:
      begin
        Copy;
        if Sci(SCI_GETMOVEEXTENDSSELECTION) <> 0 then ExecCommand(ecCancel, 0);   // Emacs' Alt+W ends the region
      end;
    ecPaste: Paste;
    ecUpperCase: Sci(SCI_UPPERCASE);
    ecLowerCase: Sci(SCI_LOWERCASE);
    ecUpperWord, ecLowerWord:
      begin
        if WordAt(CaretPos, A, B) <> '' then RangeCase(A, B, Cmd = ecUpperWord);
      end;
    ecBlockBegin:
      begin
        FBlockA := CaretPos;
        if FBlockB > FBlockA then SetBlock(FBlockA, FBlockB) else FBlockB := -1;
      end;
    ecBlockEnd:
      begin
        FBlockB := CaretPos;
        if (FBlockA >= 0) and (FBlockB > FBlockA) then SetBlock(FBlockA, FBlockB);
      end;
    ecBlockLine:
      begin
        P := LineFromPos(CaretPos);
        SetBlock(PosFromLine(P), PosFromLine(P + 1));
        if PosFromLine(P + 1) <= PosFromLine(P) then SetBlock(PosFromLine(P), TextLength);
      end;
    ecBlockWord:
      if WordAt(CaretPos, A, B) <> '' then SetBlock(A, B);
    ecBlockCopy, ecBlockMove:
      if BlockRange(A, B) then
      begin
        P := CaretPos;
        if (Cmd = ecBlockMove) and (P >= A) and (P <= B) then Exit;
        T := GetRange(A, B);
        Len := B - A;
        BeginUndo;
        try
          if Cmd = ecBlockMove then
          begin
            Sci(SCI_DELETERANGE, A, Len);
            if P > B then Dec(P, Len);
          end;
          Sci(SCI_SETEMPTYSELECTION, P);
          InsertText(P, T);
        finally
          EndUndo;
        end;
        SetBlock(P, P + Len);
      end;
    ecBlockDelete:
      if BlockRange(A, B) then
      begin
        Sci(SCI_DELETERANGE, A, B - A);
        FBlockA := -1;
        FBlockB := -1;
        FBlockShown := False;
        PaintBlock;
      end;
    ecBlockHide:
      if Sci(SCI_GETSELECTIONEMPTY) = 0 then
        Sci(SCI_SETEMPTYSELECTION, CaretPos)
      else if (FBlockA >= 0) and (FBlockB > FBlockA) and EditorOptions.PersistentBlocks then
      begin
        FBlockShown := not FBlockShown;
        PaintBlock;
      end;
    ecBlockIndent, ecBlockUnindent:
      begin
        if not BlockRange(A, B) then
        begin
          A := CaretPos;
          B := A;
        end;
        if Cmd = ecBlockIndent then IndentLines(A, B, FFileType.BlockIndent)
        else IndentLines(A, B, -FFileType.BlockIndent);
        if FBlockShown then PaintBlock;
      end;
    ecBlockUpper, ecBlockLower:
      if BlockRange(A, B) then RangeCase(A, B, Cmd = ecBlockUpper);
    ecBlockGotoBegin, ecBlockGotoEnd:
      if BlockRange(A, B) or ((FBlockA >= 0) and (FBlockB > FBlockA)) then
      begin
        if not BlockRange(A, B) then
        begin
          A := FBlockA;
          B := FBlockB;
        end;
        if Cmd = ecBlockGotoBegin then P := A else P := B;
        Sci(SCI_SETEMPTYSELECTION, P);
        Sci(SCI_SCROLLCARET);
      end;
    { BRIEF's Alt+M and Emacs' mark: the caret's moves extend the selection until it ends }
    ecMarkToggle, ecSetMark:
      if (Cmd = ecMarkToggle) and (Sci(SCI_GETMOVEEXTENDSSELECTION) <> 0) then
        Sci(SCI_SETMOVEEXTENDSSELECTION, 0)
      else
      begin
        Sci(SCI_SETEMPTYSELECTION, CaretPos);
        Sci(SCI_SETSELECTIONMODE, SC_SEL_STREAM);
      end;
    ecExchangeMark: Sci(SCI_SWAPMAINANCHORCARET);
    ecKillLine:
      begin
        P := CaretPos;
        B := LineEndPos(LineFromPos(P));
        if B = P then B := PosFromLine(LineFromPos(P) + 1);
        if B > P then
        begin
          Sci(SCI_COPYRANGE, P, B);
          Sci(SCI_DELETERANGE, P, B - P);
        end;
      end;
    ecCancel:
      begin
        Sci(SCI_SETMOVEEXTENDSSELECTION, 0);
        Sci(SCI_SETEMPTYSELECTION, CaretPos);
      end;
    ecFoldAll: Fold(sfFoldAll);
    ecUnfoldAll: Fold(sfUnfoldAll);
    ecFold: Fold(sfFold);
    ecUnfold: Fold(sfUnfold);
    ecFoldToggle: Fold(sfToggle);
    ecFoldMethods: Fold(sfFoldMethods);
  else
    { the page's (bookmarks) and the IDE's (its menu commands) }
    if Assigned(FOnCommand) then FOnCommand(Self, Cmd, Arg);
  end;
end;

procedure TSciEdit.DoAutoIndent;
var
  Line, Indent: Integer;
begin
  { Delphi 7 behaviour: a new line starts under the first non-blank of the previous text line }
  Line := CaretLine;
  if Line <= 0 then Exit;
  Indent := Sci(SCI_GETLINEINDENTATION, PrevTextLine(Line));
  if LineBlank(Line) then
  begin
    Sci(SCI_SETLINEINDENTATION, Line, Indent);
    GotoPos(Sci(SCI_GETLINEINDENTPOSITION, Line));
  end;
end;

{ --- the highlights of the text's structure --- }

const
  IdleTimerId = $5D52;             // not one of Scintilla's timers, nor SdSciScroll's
  IdleDelay = 120;                 // ms after the last change of the text
  MaxBlocksText = 8 * 1024 * 1024; // a larger text gets no block structure
  MaxMarks = 20000;                // the scroll bar's markers gathered at most

procedure TSciEdit.FillIndicator(Ind, Pos, Len: Integer);
begin
  Sci(SCI_SETINDICATORCURRENT, Ind);
  Sci(SCI_INDICATORFILLRANGE, Pos, Len);
end;

procedure TSciEdit.ClearIndicator(Ind: Integer);
begin
  Sci(SCI_SETINDICATORCURRENT, Ind);
  Sci(SCI_INDICATORCLEARRANGE, 0, TextLength);
end;

procedure TSciEdit.ShowErrors(const Starts, Lens: array of Integer; Count: Integer);
var
  K, P, L, N: Integer;
begin
  if not Ready then Exit;
  ClearIndicator(IND_ERROR);
  N := TextLength;
  for K := 0 to Count - 1 do
  begin
    P := Starts[K];
    L := Lens[K];
    if P > N then P := N;
    if P + L > N then L := N - P;
    if (P < 0) or (L <= 0) then Continue;
    Sci(SCI_SETINDICATORVALUE, K + 1);
    Sci(SCI_INDICATORFILLRANGE, P, L);
  end;
  Sci(SCI_SETINDICATORVALUE, 1);      // the value every other fill takes
  FMarksDirty := True;
  if EditorOptions.ScrollBarMarkers and (Bars <> nil) then Bars.Paint;
end;

function TSciEdit.ErrorAt(Pos: Integer; out S, E: Integer): Integer;
begin
  S := Pos;
  E := Pos;
  Result := -1;
  if not Ready or (Pos < 0) or (Pos >= TextLength) then Exit;
  Result := Sci(SCI_INDICATORVALUEAT, IND_ERROR, Pos) - 1;
  if Result < 0 then Exit;
  S := Sci(SCI_INDICATORSTART, IND_ERROR, Pos);
  E := Sci(SCI_INDICATOREND, IND_ERROR, Pos);
end;

{ the next range of an indicator from P on: P its start, E its end; False when there is none
  (SCI_INDICATOREND answers 0 for an indicator never filled) }
function TSciEdit.NextIndicatorRun(Ind: Integer; var P, E: Integer): Boolean;
var
  Len: Integer;
begin
  Result := False;
  Len := TextLength;
  if (P < 0) or (P >= Len) then Exit;
  if Sci(SCI_INDICATORVALUEAT, Ind, P) = 0 then
  begin
    E := Sci(SCI_INDICATOREND, Ind, P);
    if (E <= P) or (E >= Len) then Exit;
    P := E;
  end;
  E := Sci(SCI_INDICATOREND, Ind, P);
  Result := E > P;
end;

function TSciEdit.IndicatorRanges(Ind: Integer): string;
var
  P, E: Integer;
begin
  Result := '';
  if not Ready then Exit;
  P := 0;
  while NextIndicatorRun(Ind, P, E) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + IntToStr(P) + '-' + IntToStr(E);
    P := E;
  end;
end;

{ the highlights that follow the text are made again IdleDelay after its last change (a new
  call restarts the timer) - in a window that shows the editor; the worker's documents get them
  when a window shows them (Attached) }
procedure TSciEdit.ScheduleIdle;
begin
  if Shown and FWindow.HandleAllocated then SetTimer(FWindow.Handle, IdleTimerId, IdleDelay, nil);
end;

{ the idle timer of the window that shows the editor. A sample has none of this work: what it
  shows is made by ApplyOptions under the options it is shown with, not the editor options of
  now }
procedure TSciEdit.IdleWork;
begin
  if (FDirectPtr = nil) or FSample then Exit;
  if FBlocksStale and (FLanguage = slPascal) and
    (EditorOptions.HighlightBlocks or EditorOptions.RainbowBrackets or EditorOptions.IndentGuides) then
    RebuildBlocks;
  UpdateMatching;
  if FFindStale then PaintMatches;
  if FMarksDirty and EditorOptions.ScrollBarMarkers and (Bars <> nil) then Bars.Paint;
end;

function TSciEdit.Blocks: TPasBlocks;
begin
  Result := nil;
  if (FLanguage <> slPascal) or not Ready then Exit;
  if (FBlocks = nil) or FBlocksStale then RebuildBlocks;
  Result := FBlocks;
end;

procedure TSciEdit.RebuildBlocks;
begin
  FreeAndNil(FBlocks);
  FBlocksStale := False;
  if (FLanguage = slPascal) and (TextLength <= MaxBlocksText) then FBlocks := TPasBlocks.Create(GetText);
  PaintRainbow;
end;

{ Highlighting | Rainbow brackets: every pair in the colour of its depth }
procedure TSciEdit.PaintRainbow;
var
  I, K: Integer;
begin
  for I := 0 to RainbowColours - 1 do ClearIndicator(IND_RAINBOW + I);
  if not EditorOptions.RainbowBrackets or (FBlocks = nil) then Exit;
  for I := 0 to RainbowColours - 1 do
  begin
    Sci(SCI_SETINDICATORCURRENT, IND_RAINBOW + I);
    for K := 0 to FBlocks.BracketCount - 1 do
      with FBlocks.Brackets[K] do
        if (Partner >= 0) and (Depth mod RainbowColours = I) then Sci(SCI_INDICATORFILLRANGE, Start, 1);
  end;
end;

{ the bracket at the caret and its partner (a box; red without partner), the words of the block
  at the caret (begin ... except ... end), the indentation guide of the block around it }
procedure TSciEdit.UpdateMatching;
var
  P, M, W, O, K, Col: Integer;
  Bl: TPasBlocks;

  function IsBrace(Ch: Char): Boolean;
  begin
    Result := (Ch in ['(', ')', '[', ']']) or ((Ch in ['{', '}']) and not (FLanguage in [slPascal, slDfm]));
  end;

begin
  if not Assigned(FDirectFn) or FSample then Exit;
  ClearIndicator(IND_BRACE);
  ClearIndicator(IND_BRACEBAD);
  if EditorOptions.HighlightBraces and (Sci(SCI_GETSELECTIONS) = 1) then
  begin
    P := CaretPos;
    if (P > 0) and IsBrace(CharAt(P - 1)) and not IsCommentOrString(P - 1) then Dec(P)
    else if not IsBrace(CharAt(P)) or IsCommentOrString(P) then P := -1;
    if P >= 0 then
    begin
      M := Sci(SCI_BRACEMATCH, P, 0);
      if M >= 0 then
      begin
        FillIndicator(IND_BRACE, P, 1);
        FillIndicator(IND_BRACE, M, 1);
      end
      else
        FillIndicator(IND_BRACEBAD, P, 1);
    end;
  end;
  { the block structure is made again after a pause while the text changes: what is shown
    stays until then (Scintilla moves the indicators with the text) }
  if (FLanguage = slPascal) and FBlocksStale and
    (EditorOptions.HighlightBlocks or EditorOptions.IndentGuides) then
  begin
    ScheduleIdle;
    Exit;
  end;
  Bl := nil;
  if FLanguage = slPascal then Bl := FBlocks;
  P := CaretPos;
  ClearIndicator(IND_BLOCKMATCH);
  if (Bl <> nil) and EditorOptions.HighlightBlocks and (Sci(SCI_GETSELECTIONEMPTY) <> 0) and
    (Sci(SCI_GETSELECTIONS) = 1) then
  begin
    W := Bl.WordAt(P);
    if (W >= 0) and (Bl.Words[W].Opener >= 0) and (Bl.Words[Bl.Words[W].Opener].Closer >= 0) then
    begin
      O := Bl.Words[W].Opener;
      for K := O to Bl.Words[O].Closer do
        if Bl.Words[K].Opener = O then FillIndicator(IND_BLOCKMATCH, Bl.Words[K].Start, Bl.Words[K].Len);
    end;
  end;
  { the guide at the indentation of the block's opening line, along the lines between its
    words (Scintilla's highlighted "braces" are the two words, drawn by a hidden indicator) }
  Col := 0;
  O := -1;
  if (Bl <> nil) and EditorOptions.IndentGuides then
  begin
    O := Bl.EnclosingBlock(P);
    if (O >= 0) and (Bl.Words[Bl.Words[O].Closer].Line > Bl.Words[O].Line) then Col := LineIndent(Bl.Words[O].Line);
  end;
  if Col > 0 then
  begin
    Sci(SCI_SETHIGHLIGHTGUIDE, Col);
    Sci(SCI_BRACEHIGHLIGHT, Bl.Words[O].Start, Bl.Words[Bl.Words[O].Closer].Start);
  end
  else
  begin
    Sci(SCI_SETHIGHLIGHTGUIDE, 0);
    Sci(SCI_BRACEHIGHLIGHT, Cardinal(-1), -1);
  end;
end;

procedure TSciEdit.ShowIdentifiers(Places, Decls: TList; Len: Integer);
var
  K, P: Integer;
begin
  if not Ready then Exit;
  ClearIndicator(IND_IDENT);
  ClearIndicator(IND_IDENTDECL);
  FMarksDirty := True;
  if Places <> nil then
    for K := 0 to Places.Count - 1 do
    begin
      P := Integer(Places[K]);
      if (Decls <> nil) and (Decls.IndexOf(Places[K]) >= 0) then FillIndicator(IND_IDENTDECL, P, Len)
      else FillIndicator(IND_IDENT, P, Len);
    end;
  if EditorOptions.ScrollBarMarkers and (Bars <> nil) then Bars.Paint;
end;

function TSciEdit.ViewRange(Margin: Integer; out FromPos, ToPos: Integer): Boolean;
var
  Top, First, Last: Integer;
begin
  FromPos := 0;
  ToPos := 0;
  Result := Shown and Ready;
  if not Result then Exit;
  { display lines to document lines: folded lines are skipped, a wrapped line counts once }
  Top := Sci(SCI_GETFIRSTVISIBLELINE);
  First := Sci(SCI_DOCLINEFROMVISIBLE, Top) - Margin;
  Last := Sci(SCI_DOCLINEFROMVISIBLE, Top + Sci(SCI_LINESONSCREEN)) + Margin;
  if First < 0 then First := 0;
  if Last > LineCount - 1 then Last := LineCount - 1;
  FromPos := PosFromLine(First);
  ToPos := LineEndPos(Last);
end;

function TSciEdit.NamesBetween(FromPos, ToPos: Integer; var Names: TSciNames): Integer;
var
  P, S: Integer;
begin
  Result := 0;
  if not Ready then Exit;
  if FromPos < 0 then FromPos := 0;
  if ToPos > TextLength then ToPos := TextLength;
  { the lexer styles lazily: up to ToPos now }
  if Sci(SCI_GETENDSTYLED) < ToPos then Sci(SCI_COLOURISE, Sci(SCI_GETENDSTYLED), ToPos);
  P := FromPos;
  { a name the range begins inside is not one of its names }
  if P > 0 then
    while (P < ToPos) and (StyleAt(P - 1) = SCE_PAS_IDENTIFIER) and (StyleAt(P) = SCE_PAS_IDENTIFIER) do Inc(P);
  while P < ToPos do
    if StyleAt(P) <> SCE_PAS_IDENTIFIER then Inc(P)
    else
    begin
      S := P;
      repeat
        Inc(P);
      until (P >= ToPos) or (StyleAt(P) <> SCE_PAS_IDENTIFIER);
      if Result = Length(Names) then SetLength(Names, 2 * Result + 64);
      Names[Result].Start := S;
      Names[Result].Len := P - S;
      Names[Result].Element := eeIdentifier;
      Inc(Result);
    end;
end;

procedure TSciEdit.ShowNameKinds(FromPos, ToPos: Integer; const Names: TSciNames; Count: Integer);
var
  E: TEditorElement;
  K: Integer;
begin
  if not Ready or (ToPos <= FromPos) then Exit;
  for E := eeType to eeUnitName do
  begin
    Sci(SCI_SETINDICATORCURRENT, IND_NAMES + Ord(E) - Ord(eeType));
    Sci(SCI_INDICATORCLEARRANGE, FromPos, ToPos - FromPos);
  end;
  for K := 0 to Count - 1 do
    if Names[K].Element in [eeType..eeUnitName] then
      FillIndicator(IND_NAMES + Ord(Names[K].Element) - Ord(eeType), Names[K].Start, Names[K].Len);
end;

procedure TSciEdit.ClearNameKinds;
var
  E: TEditorElement;
begin
  if not Ready then Exit;
  for E := eeType to eeUnitName do ClearIndicator(IND_NAMES + Ord(E) - Ord(eeType));
end;

procedure TSciEdit.MarkMatches(const Text: string; MatchCase, WholeWord, RegExp: Boolean);
begin
  { Search Again with the same search: the marks are there }
  if (Text = FFindText) and (MatchCase = FFindCase) and (WholeWord = FFindWord) and (RegExp = FFindRegExp) and
    not FFindStale then Exit;
  FFindText := Text;
  FFindCase := MatchCase;
  FFindWord := WholeWord;
  FFindRegExp := RegExp;
  if Ready then PaintMatches;
end;

procedure TSciEdit.MarkMatch(Pos, Len: Integer);
begin
  FillIndicator(IND_FIND, Pos, Len);
  FillIndicator(IND_FINDTEXT, Pos, Len);
end;

{ every match of the search, in the Search match colours (Highlighting | Find matches) }
procedure TSciEdit.PaintMatches;
var
  S: string;
  P, E, Len, Count: Integer;
begin
  FFindStale := False;
  FMarksDirty := True;
  ClearIndicator(IND_FIND);
  ClearIndicator(IND_FINDTEXT);
  if (FFindText <> '') and EditorOptions.HighlightFindMatches then
  begin
    S := SearchPattern(FFindText, FFindRegExp);
    Sci(SCI_SETSEARCHFLAGS, SearchFlags(FFindCase, FFindWord, FFindRegExp));
    Len := TextLength;
    P := 0;
    Count := 0;
    while (P <= Len) and (Count < MaxMarks) do
    begin
      Sci(SCI_SETTARGETSTART, P);
      Sci(SCI_SETTARGETEND, Len);
      P := SciS(SCI_SEARCHINTARGET, Length(S), S);
      if P < 0 then Break;
      E := Sci(SCI_GETTARGETEND);
      if E > P then MarkMatch(P, E - P);
      Inc(Count);
      if E > P then P := E
      else
      begin
        E := Sci(SCI_POSITIONAFTER, P);   // an empty match: on by a character
        if E <= P then Break;
        P := E;
      end;
    end;
  end;
  if EditorOptions.ScrollBarMarkers and (Bars <> nil) then Bars.Paint;
end;

{ the scroll bar's markers (Display | Scroll bar markers): the changed lines at the left, the
  find and identifier matches in the middle, breakpoints, bookmarks, the execution point, the
  error line and Error Insight's errors at the right - gathered again only after a change (FMarksDirty), by document line }
procedure TSciEdit.GatherMarks;
const
  HistoryMask = (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN) or (1 shl SC_MARKNUM_HISTORY_SAVED) or
    (1 shl SC_MARKNUM_HISTORY_MODIFIED) or (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED);
  BookmarkMask = $3FF;
  RightMask = BookmarkMask or (1 shl MK_BREAK) or (1 shl MK_BREAK_DISABLED) or (1 shl MK_BREAK_INVALID) or
    (1 shl MK_EXEC) or (1 shl MK_ERROR_LINE);
var
  C: TEditorColors;
  P, E, L, Last: Integer;
  Modified, Saved: TColor;

  procedure Add(Line: Integer; Color: TColor; Lane: TSciMarkLane);
  begin
    if FMarkCount >= MaxMarks then Exit;
    if FMarkCount = Length(FMarks) then SetLength(FMarks, FMarkCount * 2 + 64);
    FMarks[FMarkCount].Pos := Line;
    FMarks[FMarkCount].Color := Color;
    FMarks[FMarkCount].Lane := Lane;
    Inc(FMarkCount);
  end;

  { an indicator's ranges, a marker per line }
  procedure Ranges(Ind: Integer; Color: TColor; Lane: TSciMarkLane = mlCenter);
  begin
    Last := -1;
    P := 0;
    while (FMarkCount < MaxMarks) and NextIndicatorRun(Ind, P, E) do
    begin
      L := LineFromPos(P);
      if L <> Last then Add(L, Color, Lane);
      Last := L;
      P := E;
    end;
  end;

  procedure Markers(Mask: Integer; Lane: TSciMarkLane);
  var
    M: Integer;
    Color: TColor;
    At: TSciMarkLane;
  begin
    L := MarkerNext(0, Mask);
    while (L >= 0) and (FMarkCount < MaxMarks) do
    begin
      M := MarkerGet(L) and Mask;
      At := Lane;
      if FDiffView then
      begin
        { a comparison's removed lines in Lane, its added ones on the right }
        if M and (1 shl MK_DIFF_REMOVED) <> 0 then Color := ErrorMarkColor(C)
        else
        begin
          Color := Saved;
          At := mlRight;
        end;
      end
      else if M and (1 shl MK_EXEC) <> 0 then Color := ElementBack(C, eeExecutionPoint)
      else if M and (1 shl MK_ERROR_LINE) <> 0 then Color := ElementBack(C, eeErrorLine)
      else if M and (1 shl MK_BREAK) <> 0 then Color := ElementBack(C, eeEnabledBreak)
      else if M and ((1 shl MK_BREAK_DISABLED) or (1 shl MK_BREAK_INVALID)) <> 0 then Color := ElementBack(C, eeDisabledBreak)
      else if M and BookmarkMask <> 0 then Color := ElementFore(C, eeHotLink)
      else if M and (1 shl SC_MARKNUM_HISTORY_SAVED) <> 0 then Color := Saved
      else Color := Modified;
      Add(L, Color, At);
      L := MarkerNext(L + 1, Mask);
    end;
  end;

begin
  FMarkCount := 0;
  FMarksDirty := False;
  C := EditorOptions.Colors;
  { the change bars' colours; their Defaults (the gutter's yellow and lime) are pale on the
    track: amber and green there }
  if IsDefaultColor(C[eeModifiedLine].Fore) then Modified := $0000B4F0 else Modified := C[eeModifiedLine].Fore;
  if IsDefaultColor(C[eeSavedLine].Fore) then Saved := $00009A00 else Saved := C[eeSavedLine].Fore;
  { a comparison: its removed lines on the left, its added ones on the right, the find matches }
  if FDiffView then
  begin
    Markers((1 shl MK_DIFF_REMOVED) or (1 shl MK_DIFF_ADDED), mlLeft);
    Ranges(IND_FIND, UIBlend(ElementFore(C, eePlainText), ElementBack(C, eeSearchMatch), 30));
    Exit;
  end;
  if EditorOptions.ShowChangeBars then Markers(HistoryMask, mlLeft);
  { the search match's colour a third towards the text (it is pale on the thumb), the
    identifiers in the matching bracket's colour }
  Ranges(IND_FIND, UIBlend(ElementFore(C, eePlainText), ElementBack(C, eeSearchMatch), 30));
  Ranges(IND_IDENT, ElementFore(C, eeBraceMatch));
  Ranges(IND_IDENTDECL, ElementFore(C, eeBraceMatch));
  Markers(RightMask, mlRight);
  Ranges(IND_ERROR, ErrorMarkColor(C), mlRight);
end;

{ the markers for a paint of the bar, in display lines (folds and wrapping counted), and the
  caret's line }
procedure TSciEdit.GetMarks(var Marks: TSciScrollMarks; out Count, Caret: Integer);
var
  K: Integer;
  Same: Boolean;
begin
  Count := 0;
  Caret := -1;
  if not (EditorOptions.ScrollBarMarkers or FSample) or not Ready then Exit;
  if FMarksDirty then GatherMarks;
  if Length(Marks) < FMarkCount then SetLength(Marks, FMarkCount);
  { without wrapping and folded lines a document line is its display line }
  Same := (Sci(SCI_GETWRAPMODE) = SC_WRAP_NONE) and (Sci(SCI_GETALLLINESVISIBLE) <> 0);
  for K := 0 to FMarkCount - 1 do
  begin
    Marks[K] := FMarks[K];
    if not Same then Marks[K].Pos := Sci(SCI_VISIBLEFROMDOCLINE, FMarks[K].Pos);
  end;
  Count := FMarkCount;
  Caret := Sci(SCI_VISIBLEFROMDOCLINE, CaretLine);
  if FWindow <> nil then FWindow.FBarCaret := Caret;
end;

{ --- typing aids (Typing page) --- }

function PairOf(Ch: Char; Lang: TSciLanguage): Char;
begin
  case Ch of
    '(': Result := ')';
    '[': Result := ']';
    '''': Result := '''';
    '{': if Lang in [slPascal, slDfm] then Result := #0 else Result := '}';
    '"': if Lang in [slPascal, slDfm] then Result := #0 else Result := '"';
  else
    Result := #0;
  end;
end;

function TSciEdit.LineIndent(Line: Integer): Integer;
begin
  Result := Sci(SCI_GETLINEINDENTATION, Line);
end;

{ the line has nothing but blanks and control characters (Trim leaves nothing of it); a line
  outside the text is blank. Reads the document's bytes in place, without a copy. }
function TSciEdit.LineBlank(Line: Integer): Boolean;
var
  S, L: Integer;
  P: PChar;
begin
  Result := True;
  if (Line < 0) or (Line >= LineCount) then Exit;
  S := PosFromLine(Line);
  L := LineEndPos(Line) - S;
  if L <= 0 then Exit;
  P := PChar(Sci(SCI_GETRANGEPOINTER, S, L));
  while L > 0 do
  begin
    if P^ > ' ' then
    begin
      Result := False;
      Exit;
    end;
    Inc(P);
    Dec(L);
  end;
end;

{ the nearest line above Line that is not blank; line 0 when all above are blank, -1 for line 0 }
function TSciEdit.PrevTextLine(Line: Integer): Integer;
begin
  Result := Line - 1;
  while (Result > 0) and LineBlank(Result) do Dec(Result);
end;

{ a line end in the document's mode }
function TSciEdit.EolText: string;
begin
  if FEolMode = SC_EOL_LF then Result := #10
  else if FEolMode = SC_EOL_CR then Result := #13
  else Result := #13#10;
end;

{ Pos lies in a comment or a string: the character before it and the one after it (or the line's
  end) are styled so }
function TSciEdit.InCommentOrString(Pos: Integer): Boolean;
var
  Line: Integer;
begin
  Line := LineFromPos(Pos);
  Sci(SCI_COLOURISE, PosFromLine(Line), LineEndPos(Line));
  Result := (Pos > PosFromLine(Line)) and IsCommentOrString(Pos - 1) and
    ((Pos >= LineEndPos(Line)) or IsCommentOrString(Pos));
end;

{ Auto-close pairs: an opening bracket or quote gets its partner after the caret - put in once
  Scintilla has the typed character (SCN_CHARADDED), marked as put in (IND_AUTOCLOSE) -; that
  partner typed is stepped over; a selection gets wrapped. True: the character was handled. }
function TSciEdit.AutoCloseChar(var Ch: Char): Boolean;
var
  P, A, LineEnd: Integer;
  Close, Next, Before: Char;
  S: string;
begin
  Result := False;
  { not in overwrite mode: the typed character takes the place of the next one }
  if not EditorOptions.AutoClosePairs or ReadOnly or Overwrite or (Sci(SCI_GETSELECTIONS) <> 1) then Exit;
  P := CaretPos;
  { the partner put in before, typed: over it }
  if (Sci(SCI_GETSELECTIONEMPTY) <> 0) and (CharAt(P) = Ch) and (Ch in [')', ']', '}', '''', '"']) and
    (Sci(SCI_INDICATORVALUEAT, IND_AUTOCLOSE, P) <> 0) then
  begin
    Sci(SCI_SETINDICATORCURRENT, IND_AUTOCLOSE);
    Sci(SCI_INDICATORCLEARRANGE, P, 1);
    GotoPos(P + 1);
    if Assigned(FOnCharAdded) then FOnCharAdded(Self, Ord(Ch));
    Ch := #0;
    Result := True;
    Exit;
  end;
  { (* begins a comment: the partner put in for ( goes again }
  if (Ch = '*') and (FLanguage in [slPascal, slDfm]) and (P > 0) and (CharAt(P - 1) = '(') and
    (CharAt(P) = ')') and (Sci(SCI_INDICATORVALUEAT, IND_AUTOCLOSE, P) <> 0) then
  begin
    DeleteRange(P, 1);
    Exit;
  end;
  Close := PairOf(Ch, FLanguage);
  if Close = #0 then Exit;
  { a selection: wrapped, the inside selected }
  if Sci(SCI_GETSELECTIONEMPTY) = 0 then
  begin
    if Sci(SCI_GETSELECTIONMODE) <> SC_SEL_STREAM then Exit;
    S := SelText;
    A := SelStart;
    BeginUndo;
    try
      ReplaceSel(Ch + S + Close);
    finally
      EndUndo;
    end;
    SetSel(A + 1, A + 1 + Length(S));
    Ch := #0;
    Result := True;
    Exit;
  end;
  { not in a comment or a string, only before a blank, a line's end or a closing character, a
    quote not after a word or another quote }
  if InCommentOrString(P) then Exit;
  LineEnd := LineEndPos(LineFromPos(P));
  if P < LineEnd then Next := CharAt(P) else Next := ' ';
  if not (Next in [' ', #9, ')', ']', '}', ';', ',']) then Exit;
  if Close = Ch then
  begin
    if P > PosFromLine(LineFromPos(P)) then Before := CharAt(P - 1) else Before := ' ';
    if IdentTab[Before] or (Before = Ch) then Exit;
  end;
  FPendingOpen := Ch;
  FPendingClose := Close;
end;

{ Backspace between a bracket and the partner put in for it: both go }
function TSciEdit.AutoCloseBack: Boolean;
var
  P: Integer;
begin
  Result := False;
  if not EditorOptions.AutoClosePairs or not Ready or ReadOnly or (Sci(SCI_GETSELECTIONS) <> 1) or
    (Sci(SCI_GETSELECTIONEMPTY) = 0) then Exit;
  P := CaretPos;
  if (P <= 0) or (Sci(SCI_INDICATORVALUEAT, IND_AUTOCLOSE, P) = 0) or (PairOf(CharAt(P - 1), FLanguage) <> CharAt(P)) then Exit;
  DeleteRange(P - 1, 2);
  Result := True;
end;

const
  { the Pascal lexer's styles that are no code: comments and directives }
  PasCommentStyles = [SCE_PAS_COMMENT, SCE_PAS_COMMENT2, SCE_PAS_COMMENTLINE, SCE_PAS_PREPROCESSOR,
    SCE_PAS_PREPROCESSOR2];

{ the last word of a line's code - a reserved word in lower case, 'x' for another word, else
  its last character ('' an empty line); WordStart: where it starts }
function TSciEdit.LastCodeWord(Line: Integer; out WordStart: Integer): string;
var
  S, P: Integer;
begin
  Result := '';
  S := PosFromLine(Line);
  P := LineEndPos(Line);
  WordStart := P;
  Sci(SCI_COLOURISE, S, P);
  while (P > S) and ((CharAt(P - 1) in [' ', #9]) or (StyleAt(P - 1) in PasCommentStyles)) do Dec(P);
  if P <= S then Exit;
  WordStart := P - 1;
  if not IdentTab[CharAt(P - 1)] then
  begin
    Result := CharAt(P - 1);
    Exit;
  end;
  WordStart := P;
  while (WordStart > S) and IdentTab[CharAt(WordStart - 1)] do Dec(WordStart);
  if StyleAt(WordStart) = SCE_PAS_WORD then Result := LowerCase(GetRange(WordStart, P)) else Result := 'x';
end;

{ the first word of code at Pos or after it, in lower case ('' none) }
function TSciEdit.NextCodeWord(Pos: Integer): string;
var
  Len, E: Integer;
begin
  Result := '';
  Len := TextLength;
  Sci(SCI_COLOURISE, Pos, Min(Len, Pos + 4096));
  while (Pos < Len) and ((CharAt(Pos) in [' ', #9, #13, #10]) or (StyleAt(Pos) in PasCommentStyles)) do Inc(Pos);
  E := Pos;
  while (E < Len) and IdentTab[CharAt(E)] do Inc(E);
  Result := LowerCase(GetRange(Pos, E));
end;

{ Smart indent: a closing word typed as the first word of its line (end, until, except,
  finally) goes back to the indentation of its block's opening line; begin after a line that
  ends with then, do or else goes back to that line's (Delphi's layout). EndPos: the word's end. }
procedure TSciEdit.TypedWordEnd(EndPos: Integer);
var
  S, Line, W, O, Target, Prev, WS: Integer;
  Wd, Last: string;
  Bl: TPasBlocks;
begin
  if not EditorOptions.SmartIndent or (FLanguage <> slPascal) or (EndPos <= 0) or
    (Sci(SCI_GETSELECTIONS) > 1) then Exit;
  S := EndPos;
  while (S > 0) and IdentTab[CharAt(S - 1)] do Dec(S);
  if (S = EndPos) or (EndPos - S > 7) then Exit;
  Wd := LowerCase(GetRange(S, EndPos));
  if (Wd <> 'end') and (Wd <> 'until') and (Wd <> 'except') and (Wd <> 'finally') and (Wd <> 'begin') then Exit;
  Line := LineFromPos(S);
  if S <> Sci(SCI_GETLINEINDENTPOSITION, Line) then Exit;      // not the line's first word
  Sci(SCI_COLOURISE, PosFromLine(Line), EndPos + 1);
  if StyleAt(S) <> SCE_PAS_WORD then Exit;
  Target := -1;
  if Wd = 'begin' then
  begin
    Prev := PrevTextLine(Line);
    if Prev < 0 then Exit;
    Last := LastCodeWord(Prev, WS);
    if (Last = 'then') or (Last = 'do') or (Last = 'else') then Target := LineIndent(Prev);
  end
  else
  begin
    Bl := Blocks;
    if Bl = nil then Exit;
    W := Bl.WordAt(S);
    if (W < 0) or (Bl.Words[W].Start <> S) then Exit;
    O := Bl.Words[W].Opener;
    if O < 0 then Exit;
    Target := LineIndent(Bl.Words[O].Line);
  end;
  if (Target >= 0) and (LineIndent(Line) > Target) then Sci(SCI_SETLINEINDENTATION, Line, Target);
end;

{ a new line (Enter, after Auto indent): Smart indent - one Block indent in after a line that
  opens a block or ends with then / do / else / of / a section's word, back after the one
  statement of then / do / else -; Block completion - the closing words of a block opened on
  the line before and not closed yet }
procedure TSciEdit.TypedLineEnd;
var
  Line, Prev, Prev2, Indent, NewIndent, K, WS, WS2, C: Integer;
  Last, Last2: string;
  Bl: TPasBlocks;
  Opener: Integer;
begin
  if (FLanguage <> slPascal) or not (EditorOptions.SmartIndent or EditorOptions.BlockCompletion) or
    (Sci(SCI_GETSELECTIONS) > 1) then Exit;
  Line := CaretLine;
  if not LineBlank(Line) then Exit;           // Enter inside a line: Auto indent's alone
  Prev := PrevTextLine(Line);
  if LineBlank(Prev) then Exit;               // no line above, or only blank ones
  Last := LastCodeWord(Prev, WS);
  Indent := LineIndent(Prev);
  { the block opened at the end of that line: its word last - or case ... of, class(TBase); the
    text's block structure is made only for a line that can end so }
  Bl := nil;
  if (Last = 'begin') or (Last = 'try') or (Last = 'repeat') or (Last = 'asm') or (Last = 'record') or
    (Last = 'class') or (Last = 'object') or (Last = 'interface') or (Last = 'dispinterface') or
    (Last = 'of') or (Last = ')') then
    Bl := Blocks;
  Opener := -1;
  if Bl <> nil then
  begin
    K := Bl.LastWordBefore(LineEndPos(Prev));
    while (K >= 0) and (Bl.Words[K].Line = Prev) and (Bl.Words[K].Role <> wrOpen) do Dec(K);
    if (K >= 0) and (Bl.Words[K].Line = Prev) and ((Bl.Words[K].Start = WS) or
      ((Bl.Words[K].Kind = bkCase) and (Last = 'of')) or
      ((Bl.Words[K].Kind in [bkClass, bkObject, bkInterface]) and (Last = ')'))) then Opener := K;
  end;
  if EditorOptions.SmartIndent then
  begin
    NewIndent := -1;
    if (Opener >= 0) or (Last = 'then') or (Last = 'do') or (Last = 'else') or (Last = 'of') or
      (Last = 'except') or (Last = 'finally') or (Last = 'var') or (Last = 'const') or (Last = 'type') or
      (Last = 'label') or (Last = 'resourcestring') or (Last = 'threadvar') or (Last = 'uses') or
      (Last = 'private') or (Last = 'protected') or (Last = 'public') or (Last = 'published') then
      NewIndent := Indent + FFileType.BlockIndent
    else if Last = ';' then
    begin
      { the one statement after then / do / else: the line after it goes back }
      Prev2 := PrevTextLine(Prev);
      if (Prev2 >= 0) and (LineIndent(Prev2) < Indent) then
      begin
        Last2 := LastCodeWord(Prev2, WS2);
        if (Last2 = 'then') or (Last2 = 'do') or (Last2 = 'else') then NewIndent := LineIndent(Prev2);
      end;
    end;
    if NewIndent >= 0 then
    begin
      Sci(SCI_SETLINEINDENTATION, Line, NewIndent);
      GotoPos(Sci(SCI_GETLINEINDENTPOSITION, Line));
    end;
  end;
  { Block completion: a block whose closing word is missing - none, or one that lies at another
    indentation than its opener's line (it closes an outer block) }
  if EditorOptions.BlockCompletion and (Opener >= 0) then
  begin
    C := Bl.Words[Opener].Closer;
    if (C < 0) or (LineIndent(Bl.Words[C].Line) <> Indent) then InsertCloser(Bl, Opener, Line);
  end;
end;

{ the closing lines of a block, after the caret's line at its opener's indentation: end; (end
  before else, end. after a program's last begin), try: finally and end;, repeat: until ; }
procedure TSciEdit.InsertCloser(Bl: TPasBlocks; Opener, Line: Integer);
var
  Lines: array of string;
  Indent, I, P, L: Integer;
  Next: string;
begin
  Indent := LineIndent(Bl.Words[Opener].Line);
  case Bl.Words[Opener].Kind of
    bkTry:
      begin
        SetLength(Lines, 2);
        Lines[0] := 'finally';
        Lines[1] := 'end;';
      end;
    bkRepeat:
      begin
        SetLength(Lines, 1);
        Lines[0] := 'until ;';
      end;
  else
    SetLength(Lines, 1);
    Lines[0] := 'end;';
    Next := NextCodeWord(LineEndPos(Line));
    if Bl.Words[Opener].Kind = bkBegin then
      if Next = 'else' then Lines[0] := 'end'
      else if (Next = '') and ((NextCodeWord(0) = 'program') or (NextCodeWord(0) = 'library')) then Lines[0] := 'end.';
  end;
  BeginUndo;
  try
    P := LineEndPos(Line);
    L := Line;
    for I := 0 to High(Lines) do
    begin
      InsertText(P, EolText + Lines[I]);
      Inc(L);
      Sci(SCI_SETLINEINDENTATION, L, Indent);
      P := LineEndPos(L);
    end;
  finally
    EndUndo;
  end;
end;

{ --- the commands of Edit and of the editor's menu --- }

procedure TSciEdit.DuplicateSelection;
begin
  if Ready and not ReadOnly then Sci(SCI_SELECTIONDUPLICATE);
end;

procedure TSciEdit.MoveLines(Up: Boolean);
var
  Ofs: Integer;
begin
  if not Ready or ReadOnly then Exit;
  { Scintilla selects the line it moves: a caret goes back to its place in the line }
  Ofs := -1;
  if Sci(SCI_GETSELECTIONEMPTY) <> 0 then Ofs := CaretPos - PosFromLine(CaretLine);
  if Up then Sci(SCI_MOVESELECTEDLINESUP) else Sci(SCI_MOVESELECTEDLINESDOWN);
  if Ofs >= 0 then GotoPos(PosFromLine(LineFromPos(SelStart)) + Ofs);
  Sci(SCI_SCROLLCARET);
end;

{ the selected lines (else the caret's and the next) as one: each line's end and the next one's
  indentation become one blank }
procedure TSciEdit.JoinLines;
var
  L1, L2, L, A, B: Integer;
begin
  if not Ready or ReadOnly then Exit;
  L1 := LineFromPos(SelStart);
  L2 := LineFromPos(SelEnd);
  if (L2 > L1) and (SelEnd = PosFromLine(L2)) then Dec(L2);
  if L2 = L1 then Inc(L2);
  if L2 >= LineCount then
  begin
    MessageBeep(0);
    Exit;
  end;
  BeginUndo;
  try
    for L := L2 downto L1 + 1 do
    begin
      A := LineEndPos(L - 1);
      while (A > PosFromLine(L - 1)) and (CharAt(A - 1) in [' ', #9]) do Dec(A);
      B := Sci(SCI_GETLINEINDENTPOSITION, L);
      Sci(SCI_SETTARGETRANGE, A, B);
      if (A > PosFromLine(L - 1)) and (B < LineEndPos(L)) then SciS(SCI_REPLACETARGET, 1, ' ')
      else SciS(SCI_REPLACETARGET, 0, '');
    end;
  finally
    EndUndo;
  end;
  GotoPos(LineEndPos(L1));
end;

{ the search of Select Next / All Occurrences: without letter case in a language whose words have
  none (Pascal, SQL ...) }
procedure TSciEdit.SearchFlagsForWords;
begin
  if SciLanguages[FLanguage].NoCase then Sci(SCI_SETSEARCHFLAGS, 0)
  else Sci(SCI_SETSEARCHFLAGS, SCFIND_MATCHCASE);
  Sci(SCI_TARGETWHOLEDOCUMENT);
end;

procedure TSciEdit.SelectNextOccurrence;
begin
  if not Ready then Exit;
  SearchFlagsForWords;
  Sci(SCI_MULTIPLESELECTADDNEXT);
  Sci(SCI_SCROLLCARET);
end;

procedure TSciEdit.SelectAllOccurrences;
begin
  if not Ready then Exit;
  SearchFlagsForWords;
  Sci(SCI_MULTIPLESELECTADDEACH);
end;

{ a caret on the line above or below the main one, at the column of the first caret of the row }
procedure TSciEdit.AddCaret(Below: Boolean);
var
  P, L: Integer;
begin
  if not Ready then Exit;
  P := Sci(SCI_GETSELECTIONNCARET, Sci(SCI_GETMAINSELECTION));
  if P <> FAddedCaret then FCaretColumn := Sci(SCI_GETCOLUMN, P);
  L := LineFromPos(P);
  if Below then Inc(L) else Dec(L);
  if (L < 0) or (L >= LineCount) then
  begin
    MessageBeep(0);
    Exit;
  end;
  P := Sci(SCI_FINDCOLUMN, L, FCaretColumn);
  Sci(SCI_ADDSELECTION, P, P);
  FAddedCaret := P;
  Sci(SCI_SCROLLCARET);
end;

function TSciEdit.CaretCount: Integer;
begin
  Result := Sci(SCI_GETSELECTIONS);
end;

procedure TSciEdit.ExpandSelection;
var
  A, B, S, E, L1, L2, N: Integer;
  OK: Boolean;
  Bl: TPasBlocks;
begin
  if not Ready then Exit;
  A := SelStart;
  B := SelEnd;
  { another selection than the one made last: the history begins again }
  if (A <> FExpanded.X) or (B <> FExpanded.Y) then SetLength(FSelHistory, 0);
  S := A;
  E := B;
  OK := False;
  if (FLanguage = slPascal) and (TextLength <= MaxBlocksText) then
  begin
    Bl := TPasBlocks.Create(GetText, True);
    try
      OK := Bl.ExpandRange(S, E);
    finally
      Bl.Free;
    end;
  end
  else
  begin
    { the word, the lines, the whole text }
    if (A = B) and (WordAt(A, S, E) <> '') then OK := True;
    if not OK then
    begin
      L1 := LineFromPos(A);
      L2 := LineFromPos(B);
      S := PosFromLine(L1);
      E := LineEndPos(L2);
      OK := (S < A) or (E > B);
    end;
    if not OK then
    begin
      S := 0;
      E := TextLength;
      OK := (S < A) or (E > B);
    end;
  end;
  if not OK then
  begin
    MessageBeep(0);
    Exit;
  end;
  N := Length(FSelHistory);
  SetLength(FSelHistory, N + 1);
  FSelHistory[N] := Point(Sci(SCI_GETANCHOR), CaretPos);
  SetSel(S, E);
  FExpanded := Point(S, E);
end;

function TSciEdit.CanShrinkSelection: Boolean;
begin
  Result := (Length(FSelHistory) > 0) and Ready and (SelStart = FExpanded.X) and (SelEnd = FExpanded.Y);
end;

procedure TSciEdit.ShrinkSelection;
var
  N: Integer;
begin
  if not CanShrinkSelection then
  begin
    MessageBeep(0);
    Exit;
  end;
  N := High(FSelHistory);
  SetSel(FSelHistory[N].X, FSelHistory[N].Y);
  SetLength(FSelHistory, N);
  FExpanded := Point(SelStart, SelEnd);
end;

function TSciEdit.CanFold: Boolean;
begin
  Result := EditorOptions.ShowFolding and SciLanguages[FLanguage].Folds;
end;

{ the folding commands: everything, the fold around the caret, the routines' bodies }
procedure TSciEdit.Fold(Action: TSciFoldAction);
var
  Line, K, L: Integer;
  Bl: TPasBlocks;
begin
  if not Ready then Exit;
  if not CanFold then
  begin
    MessageBeep(0);
    Exit;
  end;
  case Action of
    sfFoldAll: Sci(SCI_FOLDALL, SC_FOLDACTION_CONTRACT);
    sfUnfoldAll: Sci(SCI_FOLDALL, SC_FOLDACTION_EXPAND);
    sfFold, sfUnfold, sfToggle:
      begin
        Line := CaretLine;
        { the caret's line when it begins a fold, else the fold it lies in }
        if (Sci(SCI_GETFOLDLEVEL, Line) and SC_FOLDLEVELHEADERFLAG = 0) or
          ((Action = sfFold) and (Sci(SCI_GETFOLDEXPANDED, Line) = 0)) then
          Line := Sci(SCI_GETFOLDPARENT, Line);
        if Line < 0 then
        begin
          MessageBeep(0);
          Exit;
        end;
        case Action of
          sfFold: Sci(SCI_FOLDLINE, Line, SC_FOLDACTION_CONTRACT);
          sfUnfold: Sci(SCI_FOLDLINE, Line, SC_FOLDACTION_EXPAND);
        else
          Sci(SCI_FOLDLINE, Line, SC_FOLDACTION_TOGGLE);
        end;
      end;
    sfFoldMethods:
      begin
        Bl := Blocks;
        if Bl = nil then Exit;
        for K := 0 to Bl.RoutineCount - 1 do
        begin
          L := Bl.Words[Bl.Routines[K].Body].Line;
          if Sci(SCI_GETFOLDLEVEL, L) and SC_FOLDLEVELHEADERFLAG <> 0 then Sci(SCI_FOLDLINE, L, SC_FOLDACTION_CONTRACT);
        end;
      end;
  end;
  { a caret in what was folded goes to the first line of the outermost fold that hides it }
  Line := CaretLine;
  while (Line >= 0) and (Sci(SCI_GETLINEVISIBLE, Line) = 0) do Line := Sci(SCI_GETFOLDPARENT, Line);
  if (Line >= 0) and (Line <> CaretLine) then GotoPos(PosFromLine(Line));
  Sci(SCI_SCROLLCARET);
  FMarksDirty := True;
  if Bars <> nil then
  begin
    Bars.Update;
    Bars.Paint;
  end;
end;

{ the zoom is the window's: an editor no window has takes it when one takes it (ApplyView) }
procedure TSciEdit.ApplyZoom;
begin
  if (FWindow <> nil) and Assigned(FOnZoom) then FWindow.ApplyZoom;
end;

{ the selected word's other places (Highlight occurrences of the selected word) }
procedure TSciEdit.UpdateOccurrences;
var
  S, E, WS, WE, K: Integer;
  W: string;
  Places: TList;
begin
  S := SelStart;
  E := SelEnd;
  W := '';
  if (E > S) and (E - S < 100) and (Sci(SCI_GETSELECTIONS) = 1) then
  begin
    WS := Sci(SCI_WORDSTARTPOSITION, S, 1);
    WE := Sci(SCI_WORDENDPOSITION, S, 1);
    if (WS = S) and (WE = E) then W := GetRange(S, E);
  end;
  if W = FLastOccurrenceWord then Exit;
  FLastOccurrenceWord := W;
  ClearIndicator(IND_OCCURRENCE);
  if W = '' then Exit;
  Places := TList.Create;
  try
    WordPlaces(W, Places, False);
    Sci(SCI_SETINDICATORCURRENT, IND_OCCURRENCE);
    for K := 0 to Places.Count - 1 do
      if Integer(Places[K]) <> S then Sci(SCI_INDICATORFILLRANGE, Integer(Places[K]), Length(W));
  finally
    Places.Free;
  end;
end;

{ the places of the word W as a whole word (in any letter case where the language's words have
  none); Code: not in comments and strings. At most 5000, none in a text above 4 MB. }
procedure TSciEdit.WordPlaces(const W: string; Places: TList; Code: Boolean);
var
  Len, P, DocLen, Flags: Integer;
begin
  Places.Clear;
  DocLen := TextLength;
  if (W = '') or (DocLen > 4000000) or not Ready then Exit;
  Len := Length(W);
  Flags := SCFIND_WHOLEWORD;
  if not SciLanguages[FLanguage].NoCase then Flags := Flags or SCFIND_MATCHCASE;
  Sci(SCI_SETSEARCHFLAGS, Flags);
  { styled to the end, from the line where the styles end (where Scintilla itself would go on):
    the lines before keep theirs, so the whole text is not lexed again for each search }
  if Code then Sci(SCI_COLOURISE, PosFromLine(LineFromPos(Sci(SCI_GETENDSTYLED))), -1);
  P := 0;
  while (P < DocLen) and (Places.Count < 5000) do
  begin
    Sci(SCI_SETTARGETSTART, P);
    Sci(SCI_SETTARGETEND, DocLen);
    P := SciS(SCI_SEARCHINTARGET, Len, W);
    if P < 0 then Break;
    if not Code or not IsCommentOrString(P) then Places.Add(Pointer(P));
    Inc(P, Len);
  end;
end;

{ --- text access --- }

{ the text read last while the document has not changed since: SCN_MODIFIED drops it, and
  SCN_SAVEPOINTLEFT, which an edit sends before its SCN_MODIFIED. A document no window has cannot
  change - the pages that are not shown are read by code insight, the To-Do List, a compile -,
  one in a window is read once between two changes, not at every call. }
function TSciEdit.GetText: string;
var
  L: Integer;
begin
  if FTextValid then
  begin
    Result := FText;
    Exit;
  end;
  L := TextLength;
  SetLength(Result, L);
  if L > 0 then
    Sci(SCI_GETTEXT, L + 1, Integer(PChar(Result)));
  FText := Result;
  FTextValid := FDirectPtr <> nil;
end;

procedure TSciEdit.SetText(const S: string);
begin
  Sci(SCI_SETTEXT, 0, Integer(PChar(S)));
end;

function TSciEdit.TextLength: Integer;
begin
  if FTextValid then Result := Length(FText)
  else Result := Sci(SCI_GETLENGTH);
end;

function TSciEdit.LineCount: Integer;
begin
  Result := Sci(SCI_GETLINECOUNT);
end;

function TSciEdit.GetLineText(Line: Integer): string;
begin
  if (Line < 0) or (Line >= LineCount) then
    Result := ''
  else
    Result := GetRange(PosFromLine(Line), LineEndPos(Line));
end;

function TSciEdit.GetRange(StartPos, EndPos: Integer): string;
var
  L, DocLen: Integer;
begin
  Result := '';
  DocLen := TextLength;
  if StartPos < 0 then StartPos := 0;
  if EndPos > DocLen then EndPos := DocLen;
  L := EndPos - StartPos;
  if L <= 0 then Exit;
  SetLength(Result, L);
  Move(PChar(Sci(SCI_GETRANGEPOINTER, StartPos, L))^, Result[1], L);
end;

function TSciEdit.CharAt(Pos: Integer): Char;
begin
  if (Pos < 0) or (Pos >= TextLength) then
    Result := #0
  else
    Result := Char(Sci(SCI_GETCHARAT, Pos) and $FF);
end;

function TSciEdit.StyleAt(Pos: Integer): Integer;
begin
  Result := Sci(SCI_GETSTYLEINDEXAT, Pos);
end;

function TSciEdit.CaretPos: Integer;
begin
  Result := Sci(SCI_GETCURRENTPOS);
end;

function TSciEdit.CaretLine: Integer;
begin
  Result := Sci(SCI_LINEFROMPOSITION, CaretPos);
end;

function TSciEdit.CaretCol: Integer;
begin
  Result := Sci(SCI_GETCOLUMN, CaretPos);
end;

function TSciEdit.SelStart: Integer;
begin
  Result := Sci(SCI_GETSELECTIONSTART);
end;

function TSciEdit.SelEnd: Integer;
begin
  Result := Sci(SCI_GETSELECTIONEND);
end;

function TSciEdit.SelText: string;
begin
  Result := GetRange(SelStart, SelEnd);
end;

procedure TSciEdit.SetSel(AnchorPos, CaretPosition: Integer);
begin
  Sci(SCI_SETSEL, AnchorPos, CaretPosition);
end;

procedure TSciEdit.ReplaceSel(const S: string);
begin
  SciS(SCI_REPLACESEL, 0, S);
end;

procedure TSciEdit.InsertText(Pos: Integer; const S: string);
begin
  SciS(SCI_INSERTTEXT, Pos, S);
end;

procedure TSciEdit.DeleteRange(Pos, Len: Integer);
begin
  Sci(SCI_DELETERANGE, Pos, Len);
end;

function TSciEdit.PosFromLine(Line: Integer): Integer;
begin
  Result := Sci(SCI_POSITIONFROMLINE, Line);
end;

function TSciEdit.LineFromPos(Pos: Integer): Integer;
begin
  Result := Sci(SCI_LINEFROMPOSITION, Pos);
end;

function TSciEdit.LineEndPos(Line: Integer): Integer;
begin
  Result := Sci(SCI_GETLINEENDPOSITION, Line);
end;

function TSciEdit.PointFromPos(Pos: Integer): TPoint;
begin
  Result.X := Sci(SCI_POINTXFROMPOSITION, 0, Pos);
  Result.Y := Sci(SCI_POINTYFROMPOSITION, 0, Pos);
end;

function TSciEdit.PosFromPoint(X, Y: Integer): Integer;
begin
  Result := Sci(SCI_POSITIONFROMPOINTCLOSE, X, Y);
end;

function TSciEdit.TextHeight: Integer;
begin
  Result := Sci(SCI_TEXTHEIGHT, 0);
end;

function TSciEdit.IsIdentChar(C: Char): Boolean;
begin
  Result := IdentTab[C];   // the Pascal lexer's table
end;

function TSciEdit.WordAt(Pos: Integer; out StartPos, EndPos: Integer): string;
begin
  StartPos := Sci(SCI_WORDSTARTPOSITION, Pos, 1);
  EndPos := Sci(SCI_WORDENDPOSITION, Pos, 1);
  if EndPos > StartPos then
    Result := GetRange(StartPos, EndPos)
  else
    Result := '';
end;

function TSciEdit.DesignatorAt(Pos: Integer; Hover: Boolean; out StartPos, EndPos: Integer): string;

  { the start of the name whose qualifiers end with the character at P: back past the '^' and the
    bracket pairs to the name; -1 when there is none. A pair ends at its line: brackets in comments
    and strings do not count }
  function NameEndingAt(P: Integer): Integer;
  var
    Depth: Integer;
    C, Open, Close: Char;
  begin
    Result := -1;
    while True do
    begin
      C := CharAt(P);
      if C = '^' then
        Dec(P)
      else if ((C = ']') or Hover and (C = ')')) and not IsCommentOrString(P) then
      begin
        Close := C;
        if C = ']' then Open := '[' else Open := '(';
        Depth := 0;
        repeat
          C := CharAt(P);
          if C in [#0, #10, #13] then Exit;
          if not IsCommentOrString(P) then
            if C = Close then Inc(Depth)
            else if C = Open then Dec(Depth);
          Dec(P);
        until Depth = 0;
      end
      else
        Break;
    end;
    if not IsIdentChar(CharAt(P)) then Exit;
    while IsIdentChar(CharAt(P - 1)) do Dec(P);
    Result := P;
  end;

var
  P: Integer;
begin
  if Hover and (CharAt(Pos) = '^') then
  begin
    { the mouse on a '^' (a character, where the caret is between two): the designator it ends -
      not the word before it, which WordAt gives for a place right after a word }
    Result := '';
    StartPos := Pos;
    EndPos := Pos;
    P := NameEndingAt(Pos);
    if P < 0 then Exit;
    StartPos := P;
    EndPos := Pos + 1;
  end
  else
  begin
    Result := WordAt(Pos, StartPos, EndPos);
    if Result = '' then Exit;
  end;
  { the names before it, each with its '.' }
  while CharAt(StartPos - 1) = '.' do
  begin
    P := NameEndingAt(StartPos - 2);
    if P < 0 then Break;
    StartPos := P;
  end;
  Result := GetRange(StartPos, EndPos);
end;

function TSciEdit.IsCommentOrString(Pos: Integer): Boolean;
begin
  Result := Byte(StyleAt(Pos)) in SciQuotedStyles[FLanguage];
end;

function TSciEdit.Overwrite: Boolean;
begin
  Result := Sci(SCI_GETOVERTYPE) <> 0;
end;

procedure TSciEdit.GotoPos(Pos: Integer);
begin
  Sci(SCI_GOTOPOS, Pos);
end;

function TSciEdit.ValidLine(Line: Integer): Integer;
begin
  Result := Line;
  if Result >= LineCount then Result := LineCount - 1;
  if Result < 0 then Result := 0;
end;

procedure TSciEdit.GotoLineCol(Line, Col: Integer; CenterView: Boolean);
begin
  Line := ValidLine(Line);
  GotoLinePos(Line, Sci(SCI_FINDCOLUMN, Line, Col), CenterView);
end;

procedure TSciEdit.GotoLineByte(Line, ByteCol: Integer; CenterView: Boolean);
var
  P, E: Integer;
begin
  Line := ValidLine(Line);
  P := PosFromLine(Line);
  E := LineEndPos(Line);
  if ByteCol > 0 then Inc(P, ByteCol);
  if P > E then P := E;
  { inside a character of several bytes: its start }
  if P < E then P := Sci(SCI_POSITIONBEFORE, Sci(SCI_POSITIONAFTER, P));
  GotoLinePos(Line, P, CenterView);
end;

procedure TSciEdit.GotoLinePos(Line, P: Integer; CenterView: Boolean);
var
  Visible, First, VisLine: Integer;
begin
  Sci(SCI_ENSUREVISIBLE, Line);
  if CenterView then
  begin
    Visible := Sci(SCI_LINESONSCREEN);
    First := Sci(SCI_GETFIRSTVISIBLELINE);
    VisLine := Sci(SCI_VISIBLEFROMDOCLINE, Line);
    if (VisLine < First + 2) or (VisLine > First + Visible - 3) then
      Sci(SCI_SETFIRSTVISIBLELINE, VisLine - Visible div 3);
  end;
  Sci(SCI_GOTOPOS, P);
  Sci(SCI_CHOOSECARETX);
end;

procedure TSciEdit.GotoLineColVirtual(Line, Col: Integer);
var
  Len: Integer;
begin
  { a column past the end of the line is reached through virtual space: the blanks are only
    inserted when something is typed there }
  GotoLineCol(Line, Col, True);
  Len := Sci(SCI_GETCOLUMN, LineEndPos(Line));
  if (Col > Len) and (CaretPos = LineEndPos(Line)) then
  begin
    Sci(SCI_SETSELECTIONNANCHORVIRTUALSPACE, 0, Col - Len);
    Sci(SCI_SETSELECTIONNCARETVIRTUALSPACE, 0, Col - Len);
    Sci(SCI_CHOOSECARETX);
  end;
end;

procedure TSciEdit.BeginUndo;
begin
  Sci(SCI_BEGINUNDOACTION);
end;

procedure TSciEdit.EndUndo;
begin
  Sci(SCI_ENDUNDOACTION);
end;

function TSciEdit.UndoCurrent: Integer;
begin
  if Ready then Result := Sci(SCI_GETUNDOCURRENT) else Result := -1;
end;

procedure TSciEdit.WriterStep(BeforeCur, BeforeCaret: Integer);
begin
  if not Ready then Exit;
  if EditorOptions.GroupUndo and (FWriterCur >= 0) and (BeforeCur = FWriterCur) and (BeforeCaret = FWriterCaret) then
    Inc(FWriterSteps)
  else
    FWriterSteps := 1;
  FWriterCur := Sci(SCI_GETUNDOCURRENT);
  FWriterCaret := CaretPos;
  FWriterPending := True;
end;

{ after the writes of undoable writers (WriterStep), while nothing else changed the undo history:
  first the step that takes back no text, then the writes in a row at once }
procedure TSciEdit.Undo;
var
  I, N: Integer;
begin
  if (FWriterCur >= 0) and (Sci(SCI_GETUNDOCURRENT) = FWriterCur) then
  begin
    if FWriterPending then
    begin
      FWriterPending := False;
      Exit;
    end;
    N := FWriterSteps;
    FWriterCur := -1;
    for I := 1 to N do Sci(SCI_UNDO);
    Exit;
  end;
  FWriterCur := -1;
  Sci(SCI_UNDO);
end;

procedure TSciEdit.Redo;
begin
  Sci(SCI_REDO);
end;

function TSciEdit.CanUndo: Boolean;
begin
  Result := Sci(SCI_CANUNDO) <> 0;
end;

function TSciEdit.CanRedo: Boolean;
begin
  Result := Sci(SCI_CANREDO) <> 0;
end;

{ the selection, else the block Persistent blocks keeps }
procedure TSciEdit.Cut;
var
  A, B: Integer;
begin
  if (Sci(SCI_GETSELECTIONEMPTY) <> 0) and BlockRange(A, B) then
  begin
    Sci(SCI_COPYRANGE, A, B);
    Sci(SCI_DELETERANGE, A, B - A);
  end
  else
    Sci(SCI_CUT);
end;

procedure TSciEdit.Copy;
var
  A, B: Integer;
begin
  if (Sci(SCI_GETSELECTIONEMPTY) <> 0) and BlockRange(A, B) then Sci(SCI_COPYRANGE, A, B)
  else Sci(SCI_COPY);
end;

procedure TSciEdit.Paste;
begin
  Sci(SCI_PASTE);
end;

function TSciEdit.CanPaste: Boolean;
begin
  Result := Sci(SCI_CANPASTE) <> 0;
end;

procedure TSciEdit.SelectAll;
begin
  Sci(SCI_SELECTALL);
end;

{ asked of every page at each update of the actions: a document no window has answers from what
  was noted when it left its window (it has not changed since) }
function TSciEdit.GetModified: Boolean;
begin
  if FDirectPtr = nil then Result := FModifiedCache
  else Result := Sci(SCI_GETMODIFY) <> 0;
end;

function TSciEdit.GetReadOnly: Boolean;
begin
  if FDirectPtr = nil then Result := FReadOnlyCache
  else Result := Sci(SCI_GETREADONLY) <> 0;
end;

procedure TSciEdit.SetReadOnly(Value: Boolean);
begin
  Sci(SCI_SETREADONLY, Ord(Value));
end;

{ --- files --- }

procedure TSciEdit.LoadFromString(const S: string);
var
  I, CrLf, Lf, Cr: Integer;
  WasRO: Boolean;
begin
  { detect the line-ending style and literal tabs }
  CrLf := 0; Lf := 0; Cr := 0;
  FHasTabs := False;
  I := 1;
  while I <= Length(S) do
  begin
    case S[I] of
      #13:
        if (I < Length(S)) and (S[I + 1] = #10) then
        begin
          Inc(CrLf);
          Inc(I);
        end
        else
          Inc(Cr);
      #10: Inc(Lf);
      #9: FHasTabs := True;
    end;
    Inc(I);
    if CrLf + Lf + Cr > 2000 then Break;
  end;
  if (Lf > CrLf) and (Lf >= Cr) then FEolMode := SC_EOL_LF
  else if (Cr > CrLf) and (Cr > Lf) then FEolMode := SC_EOL_CR
  else FEolMode := SC_EOL_CRLF;
  WasRO := ReadOnly;
  ReadOnly := False;
  Sci(SCI_SETUNDOCOLLECTION, 0);
  Sci(SCI_SETCHANGEHISTORY, SC_CHANGE_HISTORY_DISABLED);
  Sci(SCI_SETEOLMODE, FEolMode);
  PutText(S);
  Sci(SCI_SETUNDOCOLLECTION, 1);
  Sci(SCI_EMPTYUNDOBUFFER);
  Sci(SCI_SETSAVEPOINT);
  Sci(SCI_GOTOPOS, 0);
  ReadOnly := WasRO;
  Sci(SCI_SETSCROLLWIDTH, 1);        // the widest line of the old text is no measure any more
  ApplyOptions;
end;


{ Scintilla's code page for the encoding: UTF-8 for the Unicode encodings, the code page for
  the double-byte ones, 0 (single bytes, shown in the character set of the code page - see
  ApplyOptions) for the others }
procedure TSciEdit.ApplyCodePage;
begin
  if not Ready then Exit;
  if IsUnicodeEncoding(FEncoding) then
    Sci(SCI_SETCODEPAGE, SC_CP_UTF8)
  else
    case FEncoding.CodePage of
      932, 936, 949, 950: Sci(SCI_SETCODEPAGE, FEncoding.CodePage);
    else
      Sci(SCI_SETCODEPAGE, 0);
    end;
end;

{ the whole text by its length: SCI_SETTEXT would end it at the first NUL byte }
procedure TSciEdit.PutText(const S: string);
begin
  Sci(SCI_CLEARALL);
  Sci(SCI_ADDTEXT, Length(S), Integer(PChar(S)));
end;

{ the file's bytes as editor text of FEncoding (Detect: FEncoding is found from the bytes);
  LoadFromString applies the options (character set) for it }
procedure TSciEdit.LoadFile(const FileName: string; Detect: Boolean; E: TSdEncoding);
var
  S: string;
begin
  { the file first: a read that fails leaves the text and its encoding as they were }
  S := DecodeFile(ReadFileU(FileName), E, Detect);
  FEncoding := E;
  ApplyCodePage;
  LoadFromString(S);
end;

procedure TSciEdit.LoadFromFile(const FileName: string);
begin
  LoadFile(FileName, True, FEncoding);
end;

procedure TSciEdit.LoadFromStringAs(const S: string; const AEncoding: TSdEncoding);
begin
  Ready;
  FEncoding := AEncoding;
  ApplyCodePage;
  LoadFromString(S);
end;

procedure TSciEdit.LoadFromFileAs(const FileName: string; const AEncoding: TSdEncoding);
begin
  LoadFile(FileName, False, AEncoding);
end;

function TSciEdit.ConversionLoss(const AEncoding: TSdEncoding; out Lost: Boolean): Boolean;
var
  S: string;
begin
  Result := ConvertText(GetText, FEncoding, AEncoding, S, Lost);
end;

function TSciEdit.ConvertTo(const AEncoding: TSdEncoding): Boolean;
var
  S: string;
  Lost, WasRO: Boolean;
  Line, L, N: Integer;
  Lines, Marks: array of Integer;
begin
  Result := ConvertText(GetText, FEncoding, AEncoding, S, Lost);
  if not Result then Exit;
  Line := CaretLine;
  { the lines stay, the document is made again (PutText) and its markers would go with it - the
    breakpoints, the bookmarks: kept line by line }
  N := 0;
  L := MarkerNext(0, -1);
  while L >= 0 do
  begin
    if N = Length(Lines) then
    begin
      SetLength(Lines, 2 * N + 16);
      SetLength(Marks, 2 * N + 16);
    end;
    Lines[N] := L;
    Marks[N] := MarkerGet(L);
    Inc(N);
    L := MarkerNext(L + 1, -1);
  end;
  FEncoding := AEncoding;
  ApplyCodePage;
  ApplyOptions;
  { a read-only document takes no text: the conversion is no edit of the user's }
  WasRO := ReadOnly;
  ReadOnly := False;
  try
    PutText(S);
  finally
    ReadOnly := WasRO;
  end;
  Sci(SCI_EMPTYUNDOBUFFER);          // the undo history holds the bytes of the old encoding
  for L := 0 to N - 1 do Sci(SCI_MARKERADDSET, Lines[L], Marks[L]);
  if N > 0 then RefreshLineColours;
  GotoLineCol(Line, 0);
end;

function TSciEdit.FileBytes: string;
var
  Lost: Boolean;
begin
  Result := EncodeFile(GetText, FEncoding, Lost);
end;

function TSciEdit.SaveToFile(const FileName: string): string;
begin
  Result := FileBytes;
  WriteFileU(FileName, Result);
  SetSavePoint;
end;

procedure TSciEdit.SetSavePoint;
begin
  Sci(SCI_SETSAVEPOINT);
end;
{ --- markers --- }

{ a marker added or deleted: the text colour of the marked lines, the scroll bar's markers }
procedure TSciEdit.MarkerChanged(Marker: Integer);
begin
  if Marker >= MK_BREAK_INVALID_LINE then RefreshLineColours;   // (it sets FLineMarks)
  if Marker <> MK_CODEDOT then
  begin
    FMarksDirty := True;
    ScheduleIdle;
  end;
end;

procedure TSciEdit.MarkerAdd(Line, Marker: Integer);
begin
  if (MarkerGet(Line) and (1 shl Marker)) = 0 then
  begin
    Sci(SCI_MARKERADD, Line, Marker);
    MarkerChanged(Marker);
  end;
end;

procedure TSciEdit.MarkerDelete(Line, Marker: Integer);
begin
  Sci(SCI_MARKERDELETE, Line, Marker);
  MarkerChanged(Marker);
end;

procedure TSciEdit.MarkerDeleteAll(Marker: Integer);
begin
  Sci(SCI_MARKERDELETEALL, Cardinal(Marker));
  MarkerChanged(Marker);
end;

function TSciEdit.MarkerGet(Line: Integer): Integer;
begin
  Result := Sci(SCI_MARKERGET, Line);
end;

function TSciEdit.MarkerNext(FromLine, Mask: Integer): Integer;
begin
  { -1 (not 0) without a window, so that marker loops end }
  if Ready then Result := Sci(SCI_MARKERNEXT, FromLine, Mask) else Result := -1;
end;

{ The text of a marked line in its kind's colour (the Color page): the execution point before
  the error line before the breakpoints, as the line's background (the last marker drawn). }
procedure TSciEdit.RefreshLineColours;
const
  Inds: array[0..4] of Integer = (IND_LINEFORE, IND_LINEFORE_ERROR, IND_LINEFORE_BREAK,
    IND_LINEFORE_DISABLED, IND_LINEFORE_INVALID);
  Marks: array[0..4] of Integer = (MK_EXEC_LINE, MK_ERROR_LINE, MK_BREAK_LINE,
    MK_BREAK_DISABLED_LINE, MK_BREAK_INVALID_LINE);
var
  L, S, E, K, M: Integer;
begin
  FLineForeDirty := False;
  for K := 0 to High(Inds) do ClearIndicator(Inds[K]);
  L := MarkerNext(0, MK_LINE_MASK);
  FLineMarks := L >= 0;      // the lines' markers as they are now (deleted lines take theirs along)
  while L >= 0 do
  begin
    M := Sci(SCI_MARKERGET, L);
    S := PosFromLine(L);
    E := LineEndPos(L);
    for K := 0 to High(Marks) do
      if M and (1 shl Marks[K]) <> 0 then
      begin
        if E > S then FillIndicator(Inds[K], S, E - S);
        Break;
      end;
    L := MarkerNext(L + 1, MK_LINE_MASK);
  end;
end;

{ --- searching --- }

{ Editor Options | BRIEF regular expressions: the pattern in BRIEF's syntax, translated for
  Scintilla's (ECMAScript): ? any character, * any characters, @ zero or more and + one or more
  of what precedes, % or < the start and > the end of a line, braces a group, [~ ] a set that
  is not, \ takes the next character as it is; . ( ) ^ are plain characters there }
function BriefToRegExp(const S: string): string;
var
  I: Integer;
  InSet: Boolean;
begin
  Result := '';
  InSet := False;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '\' then
    begin
      Result := Result + Copy(S, I, 2);
      Inc(I, 2);
      Continue;
    end;
    if InSet then
    begin
      if S[I] = ']' then InSet := False;
      Result := Result + S[I];
    end
    else
      case S[I] of
        '?': Result := Result + '.';
        '*': Result := Result + '.*';
        '@': Result := Result + '*';
        '%', '<': Result := Result + '^';
        '>': Result := Result + '$';
        '{': Result := Result + '(';
        '}': Result := Result + ')';
        '.', '(', ')', '^': Result := Result + '\' + S[I];
        '[':
          begin
            InSet := True;
            Result := Result + '[';
            if (I < Length(S)) and (S[I + 1] = '~') then
            begin
              Result := Result + '^';
              Inc(I);
            end;
          end;
      else
        Result := Result + S[I];
      end;
    Inc(I);
  end;
end;

{ what is searched for, in the editor's encoding (typed in the system code page) }
function TSciEdit.SearchPattern(const Text: string; RegExp: Boolean): string;
begin
  if RegExp and EditorOptions.BriefRegExp then Result := AnsiToEditor(BriefToRegExp(Text), FEncoding)
  else Result := AnsiToEditor(Text, FEncoding);
end;

{ the first match of the pattern S (the search flags set) from From towards Bound - backwards
  when Bound < From; an empty match at Skip is passed over by one character. Its start, -1
  none; the target holds the match }
function TSciEdit.SearchSpan(const S: string; From, Bound, Skip: Integer): Integer;
begin
  Sci(SCI_SETTARGETSTART, From);
  Sci(SCI_SETTARGETEND, Bound);
  Result := SciS(SCI_SEARCHINTARGET, Length(S), S);
  if (Result < 0) or (Result <> Skip) or (Sci(SCI_GETTARGETEND) <> Result) then Exit;
  if Bound >= From then
  begin
    if Result >= Bound then
    begin
      Result := -1;
      Exit;
    end;
    From := Sci(SCI_POSITIONAFTER, Result);
  end
  else
  begin
    if Result <= Bound then
    begin
      Result := -1;
      Exit;
    end;
    From := Sci(SCI_POSITIONBEFORE, Result);
  end;
  Sci(SCI_SETTARGETSTART, From);
  Sci(SCI_SETTARGETEND, Bound);
  Result := SciS(SCI_SEARCHINTARGET, Length(S), S);
end;

function TSciEdit.FindNext(const Text: string; MatchCase, WholeWord, RegExp, Forward, Wrap: Boolean): Boolean;
begin
  Result := FindInRange(Text, MatchCase, WholeWord, RegExp, Forward, Wrap, 0, -1, -1);
end;

function TSciEdit.FindInRange(const Text: string; MatchCase, WholeWord, RegExp, Forward, Wrap: Boolean;
  Lo, Hi, Skip: Integer): Boolean;
var
  From, P: Integer;
  S: string;
begin
  Result := False;
  { without Scintilla's window every SCI_SEARCHINTARGET answers 0: found at 0 }
  if (Text = '') or not Ready then Exit;
  S := SearchPattern(Text, RegExp);
  if (Hi < 0) or (Hi > TextLength) then Hi := TextLength;
  if Lo < 0 then Lo := 0;
  if Lo > Hi then Lo := Hi;
  { from the selection, into the range }
  if Forward then From := SelEnd else From := SelStart;
  if From < Lo then From := Lo;
  if From > Hi then From := Hi;
  Sci(SCI_SETSEARCHFLAGS, SearchFlags(MatchCase, WholeWord, RegExp));
  if Forward then P := SearchSpan(S, From, Hi, Skip) else P := SearchSpan(S, From, Lo, Skip);
  if (P < 0) and Wrap then
    if Forward then P := SearchSpan(S, Lo, Hi, Skip) else P := SearchSpan(S, Hi, Lo, Skip);
  if P >= 0 then
  begin
    Sci(SCI_ENSUREVISIBLE, LineFromPos(P));
    SetSel(Sci(SCI_GETTARGETSTART), Sci(SCI_GETTARGETEND));
    Sci(SCI_SCROLLRANGE, Sci(SCI_GETTARGETEND), Sci(SCI_GETTARGETSTART));
    Result := True;
  end;
end;

function TSciEdit.FindSpan(const Text: string; MatchCase, WholeWord, RegExp: Boolean; From, Bound: Integer;
  out MatchStart, MatchEnd: Integer): Boolean;
var
  P: Integer;
begin
  Result := False;
  MatchStart := -1;
  MatchEnd := -1;
  if (Text = '') or not Ready then Exit;
  Sci(SCI_SETSEARCHFLAGS, SearchFlags(MatchCase, WholeWord, RegExp));
  P := SearchSpan(SearchPattern(Text, RegExp), From, Bound, -1);
  if P < 0 then Exit;
  MatchStart := Sci(SCI_GETTARGETSTART);
  MatchEnd := Sci(SCI_GETTARGETEND);
  Result := True;
end;

function TSciEdit.ReplaceCurrent(const FindWhat, ReplaceWith: string; MatchCase, WholeWord, RegExp: Boolean): Boolean;
var
  S, E, P: Integer;
  FW, RW: string;
begin
  Result := False;
  if not Ready then Exit;
  FW := SearchPattern(FindWhat, RegExp);
  RW := AnsiToEditor(ReplaceWith, FEncoding);
  S := SelStart;
  E := SelEnd;
  { only a regular expression matches empty text (^, x*) }
  if (E < S) or ((E = S) and not RegExp) then Exit;
  Sci(SCI_SETSEARCHFLAGS, SearchFlags(MatchCase, WholeWord, RegExp));
  Sci(SCI_SETTARGETSTART, S);
  { an empty match is looked for in its line: the expression sees what follows it }
  if E = S then Sci(SCI_SETTARGETEND, LineEndPos(LineFromPos(S))) else Sci(SCI_SETTARGETEND, E);
  P := SciS(SCI_SEARCHINTARGET, Length(FW), FW);
  if (P = S) and (Sci(SCI_GETTARGETEND) = E) then
  begin
    if RegExp then
      SciS(SCI_REPLACETARGETRE, Length(RW), RW)
    else
      SciS(SCI_REPLACETARGET, Length(RW), RW);
    SetSel(Sci(SCI_GETTARGETEND), Sci(SCI_GETTARGETEND));
    Result := True;
  end;
end;

function TSciEdit.ReplaceAll(const FindWhat, ReplaceWith: string; MatchCase, WholeWord, RegExp: Boolean;
  Lo: Integer; var Hi: Integer): Integer;
var
  StartP, P, RLen, MLen, Next: Integer;
  FW, RW: string;
begin
  Result := 0;
  if (Hi < 0) or (Hi > TextLength) then Hi := TextLength;
  if (FindWhat = '') or not Ready then Exit;
  FW := SearchPattern(FindWhat, RegExp);
  RW := AnsiToEditor(ReplaceWith, FEncoding);
  StartP := Lo;
  if StartP < 0 then StartP := 0;
  Sci(SCI_SETSEARCHFLAGS, SearchFlags(MatchCase, WholeWord, RegExp));
  BeginUndo;
  try
    while StartP <= Hi do
    begin
      Sci(SCI_SETTARGETSTART, StartP);
      Sci(SCI_SETTARGETEND, Hi);
      P := SciS(SCI_SEARCHINTARGET, Length(FW), FW);
      if P < 0 then Break;
      MLen := Sci(SCI_GETTARGETEND) - P;
      if RegExp then
        RLen := SciS(SCI_REPLACETARGETRE, Length(RW), RW)
      else
        RLen := SciS(SCI_REPLACETARGET, Length(RW), RW);
      Inc(Hi, RLen - MLen);
      Inc(Result);
      StartP := P + RLen;
      { after an empty match the next one starts a character further (UTF-8: a whole one) }
      if MLen = 0 then
      begin
        Next := Sci(SCI_POSITIONAFTER, StartP);
        if Next <= StartP then Break;          // the end of the text
        StartP := Next;
      end;
    end;
  finally
    EndUndo;
  end;
end;

{ --- editing commands --- }

procedure TSciEdit.IndentSelection(Outdent: Boolean);
var
  L1, L2, L, Ind, S, E: Integer;
begin
  S := SelStart;
  E := SelEnd;
  L1 := LineFromPos(S);
  L2 := LineFromPos(E);
  if (L2 > L1) and (E = PosFromLine(L2)) then Dec(L2);
  BeginUndo;
  try
    for L := L1 to L2 do
    begin
      Ind := Sci(SCI_GETLINEINDENTATION, L);
      if Outdent then
      begin
        Dec(Ind, FFileType.BlockIndent);
        if Ind < 0 then Ind := 0;
      end
      else if LineEndPos(L) > PosFromLine(L) then
        Inc(Ind, FFileType.BlockIndent);
      Sci(SCI_SETLINEINDENTATION, L, Ind);
    end;
  finally
    EndUndo;
  end;
  if L2 > L1 then
    SetSel(PosFromLine(L1), LineEndPos(L2));
end;

procedure TSciEdit.ToggleComment;
var
  L1, L2, L, P, S, E: Integer;
  AllCommented: Boolean;
  T, Mark: string;
begin
  { the mark in any letter case: a batch file's REM is rem (the marks are in lower case) }
  Mark := SciLanguages[FLanguage].Comment;
  if Mark = '' then Exit;
  S := SelStart;
  E := SelEnd;
  L1 := LineFromPos(S);
  L2 := LineFromPos(E);
  if (L2 > L1) and (E = PosFromLine(L2)) then Dec(L2);
  AllCommented := True;
  for L := L1 to L2 do
  begin
    T := TrimLeft(GetLineText(L));
    if (T <> '') and not SameText(System.Copy(T, 1, Length(Mark)), Mark) then
    begin
      AllCommented := False;
      Break;
    end;
  end;
  BeginUndo;
  try
    for L := L1 to L2 do
    begin
      T := GetLineText(L);
      if Trim(T) = '' then Continue;
      if AllCommented then
      begin
        P := Pos(Mark, LowerCase(T));
        if P > 0 then DeleteRange(PosFromLine(L) + P - 1, Length(Mark));
      end
      else
        InsertText(PosFromLine(L), Mark);
    end;
  finally
    EndUndo;
  end;
  if L2 > L1 then
    SetSel(PosFromLine(L1), LineEndPos(L2))
  else if L1 + 1 < LineCount then
    GotoLineCol(L1 + 1, CaretCol, False);
end;

procedure TSciEdit.DeleteLine;
begin
  Sci(SCI_LINEDELETE);
end;

{ --- tips --- }

function TSciEdit.ScreenTextRect(Pos, EndPos: Integer): TRect;
var
  P, Q: TPoint;
begin
  P := ClientToScreen(PointFromPos(Pos));
  Q := P;
  if (EndPos > Pos) and (LineFromPos(EndPos) = LineFromPos(Pos)) then Q := ClientToScreen(PointFromPos(EndPos));
  Result := Rect(P.X, P.Y, Max(Q.X, P.X + 1), P.Y + TextHeight);
end;

{ --- setup --- }

{ the line numbers' margin as wide as the number of lines needs (3 digits at least) - measured
  again only when its number of digits changes (Force: always: the font or the zoom changed);
  each margin call of Scintilla redraws the whole view and makes its fonts again }
procedure TSciEdit.SetupLineNumbers(Force: Boolean);
var
  Digits, N: Integer;
begin
  if (FWindow = nil) or FDiffView then Exit;
  if not EditorOptions.ShowLineNumbers then
  begin
    FWindow.FNumberDigits := 0;
    Sci(SCI_SETMARGINWIDTHN, MARGIN_NUMBERS, 0);
    Exit;
  end;
  N := LineCount;
  Digits := 1;
  while N >= 10 do
  begin
    N := N div 10;
    Inc(Digits);
  end;
  if Digits < 3 then Digits := 3;
  if not Force and (Digits = FWindow.FNumberDigits) then Exit;
  FWindow.FNumberDigits := Digits;
  Sci(SCI_SETMARGINWIDTHN, MARGIN_NUMBERS, SciS(SCI_TEXTWIDTH, STYLE_LINENUMBER, '_' + StringOfChar('9', Digits)) + 2);
end;

procedure TSciEdit.SetupMargins;
begin
  if not Assigned(FDirectFn) then Exit;
  Sci(SCI_SETMARGINS, 4);
  Sci(SCI_SETMARGINLEFT, 0, 2);
  Sci(SCI_SETMARGINRIGHT, 0, 2);
  if FDiffView then
  begin
    SetupDiffMargins;
    Exit;
  end;
  { line numbers }
  Sci(SCI_SETMARGINTYPEN, MARGIN_NUMBERS, SC_MARGIN_NUMBER);
  SetupLineNumbers(True);
  { symbols: breakpoints, execution point, bookmarks }
  Sci(SCI_SETMARGINTYPEN, MARGIN_SYMBOLS, SC_MARGIN_COLOUR);
  Sci(SCI_SETMARGINBACKN, MARGIN_SYMBOLS, SciColor(ThemeBack(eeGutter)));
  { Delphi's gutter (Display: Visible gutter, Gutter width) }
  if EditorOptions.VisibleGutter then
    Sci(SCI_SETMARGINWIDTHN, MARGIN_SYMBOLS, Max(18, EditorOptions.GutterWidth))
  else
    Sci(SCI_SETMARGINWIDTHN, MARGIN_SYMBOLS, 0);
  Sci(SCI_SETMARGINMASKN, MARGIN_SYMBOLS, MK_SYMBOL_MASK);
  Sci(SCI_SETMARGINSENSITIVEN, MARGIN_SYMBOLS, 1);
  Sci(SCI_SETMARGINSENSITIVEN, MARGIN_NUMBERS, 1);
  Sci(SCI_SETMARGINCURSORN, MARGIN_SYMBOLS, SC_CURSORARROW);
  Sci(SCI_SETMARGINCURSORN, MARGIN_NUMBERS, SC_CURSORARROW);
  { change bars }
  Sci(SCI_SETMARGINTYPEN, MARGIN_HISTORY, SC_MARGIN_COLOUR);
  Sci(SCI_SETMARGINBACKN, MARGIN_HISTORY, SciColor(ThemeBack(eeGutter)));
  Sci(SCI_SETMARGINMASKN, MARGIN_HISTORY,
    (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN) or (1 shl SC_MARKNUM_HISTORY_SAVED) or
    (1 shl SC_MARKNUM_HISTORY_MODIFIED) or (1 shl SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED));
  if EditorOptions.ShowChangeBars then
    Sci(SCI_SETMARGINWIDTHN, MARGIN_HISTORY, 4)
  else
    Sci(SCI_SETMARGINWIDTHN, MARGIN_HISTORY, 0);
  { folding }
  Sci(SCI_SETMARGINTYPEN, MARGIN_FOLD, SC_MARGIN_COLOUR);
  Sci(SCI_SETMARGINBACKN, MARGIN_FOLD, SciColor(ThemeBack(eeGutter)));
  Sci(SCI_SETMARGINMASKN, MARGIN_FOLD, Integer(SC_MASK_FOLDERS));
  Sci(SCI_SETMARGINSENSITIVEN, MARGIN_FOLD, 1);
  if CanFold then
    Sci(SCI_SETMARGINWIDTHN, MARGIN_FOLD, 13)
  else
    Sci(SCI_SETMARGINWIDTHN, MARGIN_FOLD, 0);
end;

procedure TSciEdit.DefineImageMarker(Marker: Integer; const RGBA: string);
begin
  Sci(SCI_RGBAIMAGESETWIDTH, 16);
  Sci(SCI_RGBAIMAGESETHEIGHT, 16);
  Sci(SCI_MARKERDEFINERGBAIMAGE, Marker, Integer(PChar(RGBA)));
end;

procedure TSciEdit.SetupMarkers;
var
  I: Integer;
  E: TEditorElement;
  Gutter, Fold, Modified: TColor;

  { a box under the text: its ground and its frame in C, each with its opacity }
  procedure Box(Ind: Integer; C: TColor; Fill, Outline: Integer);
  begin
    Sci(SCI_INDICSETSTYLE, Ind, INDIC_STRAIGHTBOX);
    Sci(SCI_INDICSETUNDER, Ind, 1);
    Sci(SCI_INDICSETFORE, Ind, SciColor(C));
    Sci(SCI_INDICSETALPHA, Ind, Fill);
    Sci(SCI_INDICSETOUTLINEALPHA, Ind, Outline);
  end;

  procedure LineMarker(M: Integer; Back: TColor);
  begin
    Sci(SCI_MARKERDEFINE, M, SC_MARK_BACKGROUND);
    Sci(SCI_MARKERSETBACK, M, SciColor(Back));
  end;

  { the text in an element's colour: a marked line's, a name's kind's }
  procedure LineFore(Ind: Integer; E: TEditorElement);
  begin
    Sci(SCI_INDICSETSTYLE, Ind, INDIC_TEXTFORE);
    Sci(SCI_INDICSETFORE, Ind, SciColor(ElementFore(EditorOptions.Colors, E)));
  end;

  procedure FoldMarker(M, Symbol: Integer);
  begin
    Sci(SCI_MARKERDEFINE, M, Symbol);
    Sci(SCI_MARKERSETFORE, M, SciColor(Gutter));
    Sci(SCI_MARKERSETBACK, M, SciColor(Fold));
  end;

  procedure HistoryMarker(M: Integer; C: TColor);
  begin
    Sci(SCI_MARKERSETFORE, M, SciColor(C));
    Sci(SCI_MARKERSETBACK, M, SciColor(C));
  end;

  { DiffView's lines, changed words and margin styles - over the markers and indicators above (the
    same numbers) }
  procedure DiffMarkers;
  var
    Bg, GutterFg, Removed, Added: TColor;
    Step: Integer;

    { Color over Ground as far as makes the mix about Step (a word's twice) brighter or darker than
      Ground - whatever Color's own brightness (lime is far brighter than red), within bounds }
    function Tint(Color, Ground: TColor; Words: Boolean): TColor;
    var
      D, P, Lo, Hi: Integer;
    begin
      D := Abs(UILuma(Color) - UILuma(Ground));
      if D < 1 then D := 1;
      P := Step * 100 div D;
      Lo := 10;
      Hi := 25;
      if Words then
      begin
        P := 2 * P;
        Lo := 20;
        Hi := 45;
      end;
      if P < Lo then P := Lo;
      if P > Hi then P := Hi;
      Result := UIBlend(Color, Ground, P);
    end;

  begin
    Bg := ThemeBack(eePlainText);
    GutterFg := ThemeFore(eeGutter);
    Removed := ErrorMarkColor(EditorOptions.Colors);
    Added := ThemeFore(eeSavedLine);
    { a dark ground: a little more of the colour for the same contrast }
    if EditorIsDark(EditorOptions.Colors) then Step := 20 else Step := 14;
    LineMarker(MK_DIFF_REMOVED, Tint(Removed, Bg, False));
    LineMarker(MK_DIFF_ADDED, Tint(Added, Bg, False));
    LineMarker(MK_DIFF_FILLER, UIBlend(GutterFg, Bg, 7));
    LineMarker(MK_DIFF_FOLD, Gutter);
    Sci(SCI_MARKERDEFINE, MK_DIFF_CHANGE, SC_MARK_EMPTY);
    Box(IND_DIFF_REMOVED, Tint(Removed, Bg, True), 255, 0);
    Box(IND_DIFF_ADDED, Tint(Added, Bg, True), 255, 0);
    DiffStyle(STYLE_DIFF_NUMBERS, GutterFg, Gutter);
    DiffStyle(STYLE_DIFF_REMOVED, GutterFg, Tint(Removed, Gutter, False));
    DiffStyle(STYLE_DIFF_ADDED, GutterFg, Tint(Added, Gutter, False));
    DiffStyle(STYLE_DIFF_REMOVED_SIGN, Removed, Tint(Removed, Gutter, False));
    DiffStyle(STYLE_DIFF_ADDED_SIGN, Added, Tint(Added, Gutter, False));
    DiffStyle(STYLE_DIFF_NOTE, GutterFg, Gutter, True);
    Sci(SCI_EOLANNOTATIONSETVISIBLE, EOLANNOTATION_STANDARD);
  end;

begin
  Gutter := ThemeBack(eeGutter);
  Fold := ThemeFore(eeFolding);
  Modified := ThemeFore(eeModifiedLine);
  for I := 0 to 9 do
    DefineImageMarker(MK_BOOKMARK0 + I, IconRGBA(TSdIcon(Ord(iiBookmark0) + I)));
  DefineImageMarker(MK_CODEDOT, IconRGBA(iiCodeDot));
  DefineImageMarker(MK_BREAK_INVALID, IconRGBA(iiBreakInvalid));
  DefineImageMarker(MK_BREAK_DISABLED, IconRGBA(iiBreakDisabled));
  DefineImageMarker(MK_BREAK, IconRGBA(iiBreakpoint));
  DefineImageMarker(MK_EXEC, IconRGBA(iiExecArrow));
  { the line colours of the Color page }
  LineMarker(MK_BREAK_INVALID_LINE, ThemeBack(eeInvalidBreak));
  LineMarker(MK_BREAK_DISABLED_LINE, ThemeBack(eeDisabledBreak));
  LineMarker(MK_BREAK_LINE, ThemeBack(eeEnabledBreak));
  LineMarker(MK_ERROR_LINE, ThemeBack(eeErrorLine));
  LineMarker(MK_EXEC_LINE, ThemeBack(eeExecutionPoint));
  { fold column: boxed plus/minus with connecting lines }
  FoldMarker(SC_MARKNUM_FOLDEROPEN, SC_MARK_BOXMINUS);
  FoldMarker(SC_MARKNUM_FOLDER, SC_MARK_BOXPLUS);
  FoldMarker(SC_MARKNUM_FOLDERSUB, SC_MARK_VLINE);
  FoldMarker(SC_MARKNUM_FOLDERTAIL, SC_MARK_LCORNER);
  FoldMarker(SC_MARKNUM_FOLDEREND, SC_MARK_BOXPLUSCONNECTED);
  FoldMarker(SC_MARKNUM_FOLDEROPENMID, SC_MARK_BOXMINUSCONNECTED);
  FoldMarker(SC_MARKNUM_FOLDERMIDTAIL, SC_MARK_TCORNER);
  Sci(SCI_SETAUTOMATICFOLD, SC_AUTOMATICFOLD_SHOW or SC_AUTOMATICFOLD_CLICK or SC_AUTOMATICFOLD_CHANGE);
  Sci(SCI_SETFOLDFLAGS, SC_FOLDFLAG_LINEAFTER_CONTRACTED);
  { change bars: an edit reverted to the original is no bar }
  HistoryMarker(SC_MARKNUM_HISTORY_MODIFIED, Modified);
  HistoryMarker(SC_MARKNUM_HISTORY_SAVED, ThemeFore(eeSavedLine));
  HistoryMarker(SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN, Gutter);
  HistoryMarker(SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED, Modified);
  { indicators }
  Box(IND_OCCURRENCE, ThemeBack(eeOccurrence), 255, 255);
  Sci(SCI_INDICSETSTYLE, IND_LINK, INDIC_PLAIN);
  Sci(SCI_INDICSETFORE, IND_LINK, SciColor(ThemeFore(eeHotLink)));
  Sci(SCI_INDICSETHOVERSTYLE, IND_LINK, INDIC_PLAIN);
  Sci(SCI_INDICSETHOVERFORE, IND_LINK, SciColor(ThemeFore(eeHotLink)));
  Box(IND_FIND, ThemeBack(eeSearchMatch), 255, 255);
  LineFore(IND_FINDTEXT, eeSearchMatch);
  Sci(SCI_INDICSETSTYLE, IND_ERROR, INDIC_SQUIGGLE);
  Sci(SCI_INDICSETFORE, IND_ERROR, SciColor(ErrorMarkColor(EditorOptions.Colors)));
  LineFore(IND_LINEFORE, eeExecutionPoint);
  LineFore(IND_LINEFORE_BREAK, eeEnabledBreak);
  LineFore(IND_LINEFORE_DISABLED, eeDisabledBreak);
  LineFore(IND_LINEFORE_INVALID, eeInvalidBreak);
  LineFore(IND_LINEFORE_ERROR, eeErrorLine);
  Sci(SCI_INDICSETSTYLE, IND_LINKTEXT, INDIC_TEXTFORE);
  Sci(SCI_INDICSETFORE, IND_LINKTEXT, SciColor(ThemeFore(eeHotLink)));
  for E := eeType to eeUnitName do LineFore(IND_NAMES + Ord(E) - Ord(eeType), E);
  { the kept block: the selection's colour under the text }
  Sci(SCI_INDICSETSTYLE, IND_BLOCK, INDIC_FULLBOX);
  Sci(SCI_INDICSETUNDER, IND_BLOCK, 1);
  Sci(SCI_INDICSETFORE, IND_BLOCK, SciColor(ThemeBack(eeSelection)));
  Sci(SCI_INDICSETALPHA, IND_BLOCK, 110);
  Sci(SCI_INDICSETOUTLINEALPHA, IND_BLOCK, 0);
  { Highlighting: the symbol's places filled, its declarations framed; the block's words and the
    brackets in a box of their colours }
  Box(IND_IDENT, ThemeBack(eeIdentMatch), 255, 255);
  Box(IND_IDENTDECL, ThemeFore(eeIdentDecl), 60, 255);
  Box(IND_BLOCKMATCH, ThemeFore(eeWordMatch), 40, 150);
  Box(IND_BRACE, ThemeFore(eeBraceMatch), 40, 150);
  Box(IND_BRACEBAD, ThemeFore(eeBraceBad), 50, 200);
  for I := 0 to RainbowColours - 1 do
  begin
    Sci(SCI_INDICSETSTYLE, IND_RAINBOW + I, INDIC_TEXTFORE);
    Sci(SCI_INDICSETFORE, IND_RAINBOW + I, SciColor(RainbowColour(I)));
  end;
  Sci(SCI_INDICSETSTYLE, IND_GUIDE, INDIC_HIDDEN);
  Sci(SCI_INDICSETSTYLE, IND_AUTOCLOSE, INDIC_HIDDEN);
  if FDiffView then DiffMarkers;
end;

{ a style of a comparison's margin or note: the editor's font, its colours }
procedure TSciEdit.DiffStyle(Style: Integer; Fore, Back: TColor; Italic: Boolean);
begin
  SciS(SCI_STYLESETFONT, Style, EditorOptions.FontName);
  Sci(SCI_STYLESETSIZE, Style, EditorOptions.FontSize);
  Sci(SCI_STYLESETCHARACTERSET, Style, Sci(SCI_STYLEGETCHARACTERSET, STYLE_DEFAULT));
  StyleSet(Style, Fore, Back, False, Italic);
end;

{ DiffView's one margin: text, as wide as DiffMarginChars digits in its style and a little room }
procedure TSciEdit.SetupDiffMargins;
var
  M: Integer;
begin
  for M := MARGIN_NUMBERS to MARGIN_FOLD do
  begin
    Sci(SCI_SETMARGINWIDTHN, M, 0);
    Sci(SCI_SETMARGINMASKN, M, 0);
    Sci(SCI_SETMARGINSENSITIVEN, M, 0);
  end;
  Sci(SCI_SETMARGINTYPEN, MARGIN_NUMBERS, SC_MARGIN_TEXT);
  Sci(SCI_SETMARGINCURSORN, MARGIN_NUMBERS, SC_CURSORARROW);
  if FDiffMarginChars > 0 then
    Sci(SCI_SETMARGINWIDTHN, MARGIN_NUMBERS,
      SciS(SCI_TEXTWIDTH, STYLE_DIFF_NUMBERS, StringOfChar('9', FDiffMarginChars)) + 6);
end;

procedure TSciEdit.SetDiffView(Value: Boolean);
begin
  if Value = FDiffView then Exit;
  FDiffView := Value;
  if FDirectPtr <> nil then ApplyOptions else FOptionsPending := True;
end;

procedure TSciEdit.SetDiffMarginChars(Value: Integer);
begin
  if Value = FDiffMarginChars then Exit;
  FDiffMarginChars := Value;
  if FDiffView and (FDirectPtr <> nil) then SetupMargins;
end;

procedure TSciEdit.SetDiffMargin(Line: Integer; const Text, Styles: string);
begin
  SciS(SCI_MARGINSETTEXT, Line, Text);
  SciS(SCI_MARGINSETSTYLES, Line, Styles);
end;

procedure TSciEdit.SetDiffNote(Line: Integer; const Note: string);
begin
  SciS(SCI_EOLANNOTATIONSETTEXT, Line, Note);
  if Note <> '' then Sci(SCI_EOLANNOTATIONSETSTYLE, Line, STYLE_DIFF_NOTE);
end;

procedure TSciEdit.SetLanguage(Lang: TSciLanguage);
begin
  FByFile := False;
  FLanguage := Lang;
  LanguageChanged;
end;

procedure TSciEdit.SetLanguageFromFile(const FileName: string);
begin
  FTypeFile := FileName;
  FFileType := EditorFileType(FileName);
  FByFile := True;
  FLanguage := FileLanguage;
  LanguageChanged;
end;

{ the lexer and the options for the language now - when no window has the document, once one
  takes it }
procedure TSciEdit.LanguageChanged;
begin
  if FDirectPtr = nil then
  begin
    FLexerPending := True;
    FOptionsPending := True;
    Exit;
  end;
  SetupLexer;
  ApplyOptions;
end;

{ the language of the file: an expert's highlighter of its source file type (Source Options);
  else the one of its extension - also when the type names one of Delphi's own highlighters }
function TSciEdit.FileLanguage: TSciLanguage;
begin
  if Assigned(SciTokenizerFor) and (SciTokenizerFor(FFileType.Highlighter) <> nil) then Result := slExpert
  else Result := LanguageFromFileName(FTypeFile);
end;

procedure TSciEdit.SetupLexer;
var
  Lang: TSciLexLanguage;
  Words: string;
  Lex: Pointer;
  List, P: Integer;
begin
  if FDirectPtr = nil then Exit;
  FLexerPending := False;
  { the language's lexer of Lexilla; plain text has none, and an expert's highlighter none
    either: Scintilla asks for the styles (SCN_STYLENEEDED) }
  Lang := SciLanguages[FLanguage];
  Lex := nil;
  if (Lang.Lexer <> '') and Assigned(LexCreate) then
    Lex := LexCreate(PAnsiChar(Lang.Lexer));
  Sci(SCI_SETILEXER, 0, Integer(Lex));
  { the word lists, '|' between them }
  Words := Lang.Words;
  List := 0;
  while Words <> '' do
  begin
    P := Pos('|', Words);
    if P = 0 then P := Length(Words) + 1;
    SciS(SCI_SETKEYWORDS, List, System.Copy(Words, 1, P - 1));
    Delete(Words, 1, P);
    Inc(List);
  end;
  if FLanguage in SciPascal then
    SetProp('lexer.pascal.smart.highlighting', IntToStr(Ord(FLanguage = slPascal)));
  SetProp('fold', '1');
  SetProp('fold.compact', '0');
  SetProp('fold.comment', '1');
  SetProp('fold.preprocessor', '1');
  SetProp('fold.html', '1');
  { C's code that #if leaves out keeps its colours: the inactive styles (64 + style) have none }
  SetProp('lexer.cpp.track.preprocessor', '0');
  { no SCI_COLOURISE here: both callers apply the options next, which ends with it }
end;

procedure TSciEdit.StyleSet(Style: Integer; Fore, Back: TColor; Bold, Italic, Underline: Boolean);
begin
  Sci(SCI_STYLESETFORE, Style, SciColor(Fore));
  Sci(SCI_STYLESETBACK, Style, SciColor(Back));
  Sci(SCI_STYLESETBOLD, Style, Ord(Bold));
  Sci(SCI_STYLESETITALIC, Style, Ord(Italic));
  Sci(SCI_STYLESETUNDERLINE, Style, Ord(Underline));
end;

{ Every option of Tools | Editor Options that the editor shows: the font, the
  colours of the Color page per lexer style (all plain text when the file type has no syntax
  highlight), selection, caret (BRIEF cursor shapes), right margin, the file type's tabs,
  indent and visible blanks, the gutter and D7 Studio's margins, the highlights of its
  Highlighting page, word wrap, the zoom. Scintilla keeps the tabs and the indent with the
  document, the rest with the window: ApplyView. }
procedure TSciEdit.ApplyOptions;
var
  I: Integer;
begin
  FFileType := EditorFileType(FTypeFile);
  Inc(SciViewGen);
  { the file type's highlighter may be another now (Source Options, an expert's): the language
    follows it }
  if FByFile and (FileLanguage <> FLanguage) then
  begin
    FLanguage := FileLanguage;
    FLexerPending := True;
  end;
  if FDirectPtr = nil then
  begin
    FOptionsPending := True;
    Exit;
  end;
  FOptionsPending := False;
  if FLexerPending then SetupLexer;
  ApplyView;
  { the file type (Source Options): tabs, indent }
  Sci(SCI_SETUSETABS, Ord(FFileType.UseTabChar or FFileType.OptimalFill));
  Sci(SCI_SETINDENT, FFileType.BlockIndent);
  Sci(SCI_SETTABWIDTH, TabWidthOf(FFileType.TabStops));
  Sci(SCI_SETBACKSPACEUNINDENTS, Ord(FFileType.BackspaceUnindents));
  RefreshLineColours;
  Sci(SCI_COLOURISE, 0, -1);
  { the highlights of the text as the options now say: made again at once (Find matches, a
    switched-off highlight) or after the pause (the block structure) }
  if not EditorOptions.HighlightBlocks then ClearIndicator(IND_BLOCKMATCH);
  if not EditorOptions.RainbowBrackets then
    for I := 0 to RainbowColours - 1 do ClearIndicator(IND_RAINBOW + I);
  if not EditorOptions.HighlightIdentifiers then ShowIdentifiers(nil, nil, 0);
  PaintMatches;
  FBlocksStale := True;
  FMarksDirty := True;
  UpdateMatching;
  ScheduleIdle;
  { a sample makes at once what an editor makes when idle - the block structure with its rainbow,
    the scroll bar's markers -: with the options it is given now (its owner's, for a while) }
  if FSample then
  begin
    Blocks;
    GatherMarks;
  end;
  if Shown and Assigned(FOnViewApplied) then FOnViewApplied(Self);
end;

{ the window's part of the options for this editor - its language's styles, the encoding's
  character set, its file type's blanks: made again when the window takes an editor they were not
  made for (ViewKey) }
procedure TSciEdit.ApplyView;
var
  Bg, Fg, Toward: TColor;
  C: TEditorColors;
  Syntax: Boolean;
  Caret, I, Band: Integer;
  Alpha: Byte;

  procedure El(Style: Integer; E: TEditorElement);
  begin
    if Syntax then
      StyleSet(Style, ElementFore(C, E), ElementBack(C, E), C[E].Bold, C[E].Italic, C[E].Underline)
    else
      StyleSet(Style, Fg, Bg);
  end;

begin
  if FWindow = nil then Exit;
  C := EditorOptions.Colors;
  { the file type's Use syntax highlight; a file of a language no type of Delphi's names (.ini,
    .rc, .bat, .bpg ...) is Default's, whose highlight Delphi 7 ships off: its lexer colours it }
  Syntax := FFileType.UseSyntaxHighlight or
    not (FLanguage in SciPascal + [slNone, slExpert]) and SameText(FFileType.ID, DefaultTypeID);
  Bg := ElementBack(C, eePlainText);
  Fg := ElementFore(C, eePlainText);
  { base style }
  SciS(SCI_STYLESETFONT, STYLE_DEFAULT, EditorOptions.FontName);
  Sci(SCI_STYLESETSIZE, STYLE_DEFAULT, EditorOptions.FontSize);
  if IsUnicodeEncoding(FEncoding) then
    Sci(SCI_STYLESETCHARACTERSET, STYLE_DEFAULT, CharsetForCodePage(SystemEncoding.CodePage, DEFAULT_CHARSET))
  else
    Sci(SCI_STYLESETCHARACTERSET, STYLE_DEFAULT, CharsetForCodePage(FEncoding.CodePage));
  StyleSet(STYLE_DEFAULT, Fg, Bg);
  Sci(SCI_STYLECLEARALL);
  { gutter }
  StyleSet(STYLE_LINENUMBER, ElementFore(C, eeGutter), ElementBack(C, eeGutter));
  { the brackets have boxes (IND_BRACE): Scintilla's brace style colours only the highlighted
    indentation guide }
  StyleSet(STYLE_BRACELIGHT, ElementFore(C, eeBraceMatch), Bg, True);
  StyleSet(STYLE_BRACEBAD, ElementFore(C, eeBraceBad), Bg, True);
  StyleSet(STYLE_INDENTGUIDE, ElementFore(C, eeIndentGuide), Bg);
  { the elements of the Color page: the lexer's styles (SciLexStyles), an expert's highlighter's
    codes (the style is the code); plain text has none but STYLE_DEFAULT }
  if FLanguage = slExpert then
    for I := 0 to 31 do El(I, ExpertElements[I])
  else
    for I := Low(SciLexStyles) to High(SciLexStyles) do
      if FLanguage in SciLexStyles[I].Langs then El(SciLexStyles[I].Style, SciLexStyles[I].Element);
  { the selection; the caret }
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_BACK, SciColorA(ElementBack(C, eeSelection)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_TEXT, SciColorA(ElementFore(C, eeSelection)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_ADDITIONAL_BACK, SciColorA(ElementBack(C, eeSelection)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_ADDITIONAL_TEXT, SciColorA(ElementFore(C, eeSelection)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_INACTIVE_BACK, SciColorA(ElementBack(C, eeSelection)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_SELECTION_INACTIVE_TEXT, SciColorA(ElementFore(C, eeSelection)));
  Sci(SCI_SETSELECTIONLAYER, SC_LAYER_BASE);
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_CARET, SciColorA(ElementFore(C, eeCaret)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_CARET_ADDITIONAL, SciColorA(ElementFore(C, eeCaret)));
  { BRIEF cursor shapes: a block while inserting; else Delphi's bar, a block in overwrite mode }
  if EditorOptions.BriefCursors then Caret := CARETSTYLE_BLOCK or CARETSTYLE_OVERSTRIKE_BLOCK
  else Caret := CARETSTYLE_LINE or CARETSTYLE_OVERSTRIKE_BLOCK;
  Sci(SCI_SETCARETSTYLE, Caret);
  { the scroll bars: on the ground of the plain text, the thumb the theme's (Default: a shade of
    the ground) }
  if Bars <> nil then
  begin
    Bars.SetColors(SciScrollColors(Bg, ElementFore(C, eeScrollBar)));
    Bars.Update;
  end;
  { Highlighting | Current line: a band translucent under the text - the debugger's and the
    error lines keep their colours under it (an opaque one would take their place). Default: the
    text's colour, 14 / 255 opaque; a colour of the theme is that colour on the plain text's
    ground (TranslucentOver) }
  if EditorOptions.HighlightCurrentLine then
  begin
    if IsDefaultColor(C[eeCurrentLine].Back) then
    begin
      if EditorIsDark(C) then Toward := clWhite else Toward := clBlack;
      Band := SciColorAlpha(Toward, 14);
    end
    else
    begin
      Toward := TranslucentOver(ElementBack(C, eeCurrentLine), Bg, Alpha);
      Band := SciColorAlpha(Toward, Alpha);
    end;
    Sci(SCI_SETCARETLINELAYER, SC_LAYER_UNDER_TEXT);
    Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_CARET_LINE_BACK, Band);
    Sci(SCI_SETCARETLINEVISIBLEALWAYS, 1);
  end
  else
  begin
    Sci(SCI_RESETELEMENTCOLOUR, SC_ELEMENT_CARET_LINE_BACK);
    Sci(SCI_SETCARETLINEVISIBLEALWAYS, 0);
  end;
  { Highlighting | Indentation guides }
  if EditorOptions.IndentGuides then Sci(SCI_SETINDENTATIONGUIDES, SC_IV_LOOKBOTH)
  else Sci(SCI_SETINDENTATIONGUIDES, SC_IV_NONE);
  { Display | Word wrap: at the window's edge, a glyph at the line's end, the rest a level in - not in
    a comparison, whose two sides keep their lines in line }
  if EditorOptions.WordWrap and not FDiffView then
  begin
    Sci(SCI_SETWRAPMODE, SC_WRAP_WORD);
    Sci(SCI_SETWRAPVISUALFLAGS, SC_WRAPVISUALFLAG_END);
    Sci(SCI_SETWRAPINDENTMODE, SC_WRAPINDENT_INDENT);
  end
  else
    Sci(SCI_SETWRAPMODE, SC_WRAP_NONE);
  if Assigned(FOnZoom) then ApplyZoom;          // a file's editor (OnZoom), not a sample
  Sci(SCI_SETFOLDMARGINCOLOUR, 1, SciColor(ElementBack(C, eeGutter)));
  Sci(SCI_SETFOLDMARGINHICOLOUR, 1, SciColor(ElementBack(C, eeGutter)));
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_FOLD_LINE, SciColorA(ElementFore(C, eeFolding)));
  { right margin }
  if EditorOptions.ShowRightMargin and (FLanguage = slPascal) then
  begin
    Sci(SCI_SETEDGEMODE, EDGE_LINE);
    Sci(SCI_SETEDGECOLUMN, EditorOptions.RightMargin);
    Sci(SCI_SETEDGECOLOUR, SciColor(ElementFore(C, eeRightMargin)));
  end
  else
    Sci(SCI_SETEDGEMODE, EDGE_NONE);
  { the file type (Source Options): visible blanks }
  Sci(SCI_SETELEMENTCOLOUR, SC_ELEMENT_WHITE_SPACE, SciColorA(ElementFore(C, eeBlanks)));
  if FFileType.ShowTabChar or FFileType.ShowSpaceChar then
  begin
    Sci(SCI_SETVIEWWS, SCWS_VISIBLEALWAYS);
    { the dots of the blanks only with Show space character (tabs keep their arrows) }
    Sci(SCI_SETWHITESPACESIZE, Ord(FFileType.ShowSpaceChar));
  end
  else
    Sci(SCI_SETVIEWWS, SCWS_INVISIBLE);
  { Cursor beyond EOF: the text scrolls on past its last line }
  Sci(SCI_SETENDATLASTLINE, Ord(not EditorOptions.CursorBeyondEOF));
  { change bars: the window draws them while the option is on (SCI_GETCHANGEHISTORY is the
    window's). Switched on, Scintilla begins a document's history only while it has nothing to
    undo (CellBuffer::ChangeHistorySet); switched off, the history goes }
  if EditorOptions.ShowChangeBars and not FDiffView then
  begin
    if Sci(SCI_GETCHANGEHISTORY) = SC_CHANGE_HISTORY_DISABLED then
      Sci(SCI_SETCHANGEHISTORY, SC_CHANGE_HISTORY_ENABLED or SC_CHANGE_HISTORY_MARKERS);
  end
  else if Sci(SCI_GETCHANGEHISTORY) <> SC_CHANGE_HISTORY_DISABLED then
    Sci(SCI_SETCHANGEHISTORY, SC_CHANGE_HISTORY_DISABLED);
  SetupMarkers;
  SetupMargins;
  FWindow.FViewKey := ViewKey;
end;

{ Before a save: trailing blanks go unless the file type keeps them (Delphi takes them off the
  lines it edits; here the whole text, one undo step), the line ends become CRLF unless Preserve
  line ends }
procedure TSciEdit.PrepareSave;
var
  L, S, E, B: Integer;
begin
  if not Ready then Exit;
  Sci(SCI_BEGINUNDOACTION);
  try
    if not FFileType.KeepTrailingBlanks then
      for L := 0 to LineCount - 1 do
      begin
        S := PosFromLine(L);
        E := LineEndPos(L);
        B := E;
        while (B > S) and (Sci(SCI_GETCHARAT, B - 1) in [9, 32]) do Dec(B);
        if B < E then
        begin
          Sci(SCI_SETTARGETRANGE, B, E);
          SciS(SCI_REPLACETARGET, 0, '');
        end;
      end;
    if not EditorOptions.PreserveLineEnds and (FEolMode <> SC_EOL_CRLF) then
    begin
      FEolMode := SC_EOL_CRLF;
      Sci(SCI_SETEOLMODE, FEolMode);
      Sci(SCI_CONVERTEOLS, SC_EOL_CRLF);
    end;
  finally
    Sci(SCI_ENDUNDOACTION);
  end;
end;

{ ... after it: without Undo after save the history begins again }
procedure TSciEdit.SaveDone;
begin
  if Ready and not EditorOptions.UndoAfterSave then Sci(SCI_EMPTYUNDOBUFFER);
end;

{ ---------------------------------------------------------------- TSciWindow }

constructor TSciWindow.CreateShared(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks] - [csSetCaption, csAcceptsControls];
  Width := 300;
  Height := 200;
  TabStop := True;
  FBarCaret := -1;
  FBars := TSciScrollBars.Create(Self);
  FBars.OnGetInfo := BarInfo;
  FBars.OnScroll := BarScroll;
  FBars.OnGetMarks := GetMarks;
  FBars.OnPress := BarPress;
  UIRepaintOnWidth(Self);              // no CS_HREDRAW: its right margin, its lines' grounds
end;

constructor TSciWindow.Create(AOwner: TComponent);
begin
  CreateShared(AOwner);
  FOwnEdit := TSciEdit.Create(Self);
  FOwnEdit.FHome := Self;
end;

destructor TSciWindow.Destroy;
begin
  if FSlot <> nil then FSlot.FWindow := nil;
  FSlot := nil;
  FPending := nil;
  { its own editor goes while the window is there: its document is given up through it }
  FreeAndNil(FOwnEdit);
  if FEdit <> nil then Let(FEdit, False);
  if SciWorker = Self then SciWorker := nil;
  if SciFileWindow = Self then SciFileWindow := nil;
  inherited Destroy;
end;

procedure TSciWindow.CreateParams(var Params: TCreateParams);
begin
  LoadScintilla;
  inherited CreateParams(Params);
  if SciModule <> 0 then
    CreateSubClass(Params, 'Scintilla');
  { a flat 1 px border (WMNCPaint), no classic sunken edge }
  Params.Style := Params.Style or WS_CLIPCHILDREN;
  if not FBorderless then Params.Style := Params.Style or WS_BORDER;
  Params.WindowClass.style := Params.WindowClass.style and not (CS_HREDRAW or CS_VREDRAW);
end;

{ the window's own settings, the same for every editor it shows; then the editor it showed before
  it was made again, else its own }
procedure TSciWindow.CreateWnd;
var
  E: TSciEdit;
begin
  inherited CreateWnd;
  FDirectFn := nil;
  FDirectPtr := nil;
  if SciModule = 0 then Exit;
  @FDirectFn := Pointer(SendMessage(Handle, SCI_GETDIRECTFUNCTION, 0, 0));
  FDirectPtr := Pointer(SendMessage(Handle, SCI_GETDIRECTPOINTER, 0, 0));
  FViewKey := '';
  FNumberDigits := 0;
  FBarCaret := -1;
  Sci(SCI_SETBUFFEREDDRAW, 1);
  { the layouts of the lines in view are kept between paints and the scroll bars' measures
    (BarInfo, at every SCN_PAINTED): Scintilla's default keeps only the caret's line }
  Sci(SCI_SETLAYOUTCACHE, SC_CACHE_PAGE);
  { the scroll bars are D7 Studio's (SdSciScroll), not Scintilla's: Windows draws its own ones in
    the theme's light or dark look only }
  Sci(SCI_SETVSCROLLBAR, 0);
  Sci(SCI_SETHSCROLLBAR, 0);
  Sci(SCI_SETSCROLLWIDTHTRACKING, 1);
  Sci(SCI_SETSCROLLWIDTH, 1);
  { Editor Options | Insert mode: how a new editor starts (the Insert key switches it) }
  Sci(SCI_SETOVERTYPE, Ord(not EditorOptions.InsertMode));
  Sci(SCI_SETMULTIPLESELECTION, 1);
  Sci(SCI_SETADDITIONALSELECTIONTYPING, 1);
  Sci(SCI_SETMULTIPASTE, SC_MULTIPASTE_EACH);
  Sci(SCI_SETVIRTUALSPACEOPTIONS, SCVS_RECTANGULARSELECTION);
  Sci(SCI_SETMOUSEDWELLTIME, 500);
  Sci(SCI_USEPOPUP, SC_POPUP_NEVER);
  Sci(SCI_SETCARETWIDTH, 2);
  Sci(SCI_SETCARETSTYLE, CARETSTYLE_LINE or CARETSTYLE_OVERSTRIKE_BLOCK);
  Sci(SCI_SETCARETPERIOD, GetCaretBlinkTime);
  Sci(SCI_SETMODEVENTMASK, SC_MOD_INSERTTEXT or SC_MOD_DELETETEXT);
  Sci(SCI_SETXCARETPOLICY, CARET_SLOP or CARET_EVEN, 40);
  Sci(SCI_SETYCARETPOLICY, CARET_SLOP or CARET_STRICT or CARET_EVEN, 1);
  Sci(SCI_SETVISIBLEPOLICY, VISIBLE_SLOP, 3);
  { key combinations the IDE handles itself }
  Sci(SCI_CLEARCMDKEY, Ord('L') or (SCMOD_CTRL shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('T') or (SCMOD_CTRL shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('D') or (SCMOD_CTRL shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('U') or (SCMOD_CTRL shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('U') or ((SCMOD_CTRL or SCMOD_SHIFT) shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('L') or ((SCMOD_CTRL or SCMOD_SHIFT) shl 16));
  Sci(SCI_CLEARCMDKEY, Ord('T') or ((SCMOD_CTRL or SCMOD_SHIFT) shl 16));
  { the brace highlight of Scintilla only names the block whose indentation guide is drawn
    highlighted (UpdateMatching): its own indicator is a hidden one, the brackets' boxes are
    IND_BRACE / IND_BRACEBAD }
  Sci(SCI_BRACEHIGHLIGHTINDICATOR, 1, IND_GUIDE);
  Sci(SCI_BRACEBADLIGHTINDICATOR, 1, IND_GUIDE);
  E := FPending;
  FPending := nil;
  if E = nil then E := FOwnEdit;
  if E <> nil then SetEdit(E);
end;

{ the window goes - with DestroyWnd, or with its parent's window: the editor it shows keeps its
  view, and comes back when the window is made again }
procedure TSciWindow.WMDestroy(var Message: TWMDestroy);
var
  E: TSciEdit;
begin
  E := FEdit;
  if E <> nil then
  begin
    if Assigned(FDirectFn) then E.Detached(True);
    FEdit := nil;
    if not (csDestroying in ComponentState) then FPending := E;
  end;
  FDirectFn := nil;
  FDirectPtr := nil;
  inherited;
end;

function TSciWindow.Sci(Msg: Cardinal; W: Cardinal; L: Integer): Integer;
begin
  if Assigned(FDirectFn) then Result := FDirectFn(FDirectPtr, Msg, W, L) else Result := 0;
end;

function TSciWindow.GetEdit: TSciEdit;
begin
  if FEdit <> nil then Result := FEdit else Result := FOwnEdit;
end;

{ Value's document into the window, with its view (it leaves the window it was in); the editor
  shown before keeps its view for the next window that takes it. While the window has the
  keyboard, both editors hear of it as of a change of the focus. }
procedure TSciWindow.SetEdit(Value: TSciEdit);
var
  Old: TSciEdit;
  HadFocus: Boolean;
begin
  if (Value <> nil) and (csDestroying in Value.ComponentState) then Value := nil;
  if Value = FEdit then Exit;
  if not HandleAllocated then
  begin
    { the window is made first; it takes Value as it is made }
    FPending := Value;
    if Value <> nil then Value.FreeNotification(Self);
    if (Parent <> nil) or (ParentWindow <> 0) then HandleNeeded;
    Exit;
  end;
  HadFocus := Focused;
  Old := FEdit;
  if Old <> nil then
  begin
    KillTimer(Handle, IdleTimerId);
    Old.Detached(True);
    FEdit := nil;
  end;
  if Value <> nil then
  begin
    if Value.FWindow <> nil then Value.FWindow.Let(Value, True);
    if Value.FDoc = 0 then
    begin
      Value.FDoc := NewDocument;
      Value.FFresh := Value.FDoc <> 0;
    end;
    if Value.FDoc = 0 then Value := nil;
  end;
  if Value = nil then
    Sci(SCI_SETDOCPOINTER, 0, 0)
  else
  begin
    FEdit := Value;
    Value.FreeNotification(Self);
    Value.FWindow := Self;
    Value.FDirectFn := FDirectFn;
    Value.FDirectPtr := FDirectPtr;
    { the worker measures what the file area's window would (lines in view, columns) }
    if FWorker and (SciFileWindow <> nil) and ((Width <> SciFileWindow.Width) or (Height <> SciFileWindow.Height)) then
      SetBounds(0, 0, SciFileWindow.Width, SciFileWindow.Height);
    Sci(SCI_SETDOCPOINTER, 0, Value.FDoc);
    Value.Attached;
  end;
  if HadFocus then
  begin
    if EditAlive(Old) and Assigned(Old.FOnFocusChange) then Old.FOnFocusChange(Old);
    if (FEdit <> nil) and Assigned(FEdit.FOnFocusChange) then FEdit.FOnFocusChange(FEdit);
  end;
end;

{ E's document leaves the window (an empty one takes its place); E keeps its view for the next
  window (KeepView) }
procedure TSciWindow.Let(E: TSciEdit; KeepView: Boolean);
var
  HadFocus: Boolean;
begin
  if (E = nil) or (E <> FEdit) then Exit;
  HadFocus := HandleAllocated and Focused;
  if HandleAllocated then KillTimer(Handle, IdleTimerId);
  if Assigned(FDirectFn) then E.Detached(KeepView);
  FEdit := nil;
  if Assigned(FDirectFn) then Sci(SCI_SETDOCPOINTER, 0, 0);
  if HadFocus and KeepView and Assigned(E.FOnFocusChange) then E.FOnFocusChange(E);
end;

procedure TSciWindow.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FEdit then FEdit := nil;
  if AComponent = FPending then FPending := nil;
  if AComponent = FOwnEdit then FOwnEdit := nil;
  if AComponent = FSlot then FSlot := nil;
  if AComponent = FTopBar then FTopBar := nil;
end;

procedure TSciWindow.SetTopBar(Value: TWinControl);
begin
  if FTopBar = Value then Exit;
  FTopBar := Value;
  if Value <> nil then Value.FreeNotification(Self);
  Place;
end;

procedure TSciWindow.Follow(Slot: TSciSlot);
begin
  if FSlot <> Slot then
  begin
    if FSlot <> nil then FSlot.FWindow := nil;
    FSlot := Slot;
    if Slot <> nil then
    begin
      Slot.FWindow := Self;
      Slot.FreeNotification(Self);
    end;
  end;
  if (Slot <> nil) and (Slot.Edit <> nil) then SetEdit(Slot.Edit);
  Place;
  if Visible then BringToFront;
  if (FTopBar <> nil) and FTopBar.Visible then FTopBar.BringToFront;
end;

procedure TSciWindow.Place;
var
  P: TPoint;
  C: TWinControl;
  Show, Bar: Boolean;
  H: Integer;
begin
  { shown while the slot is and every control between it and the window's parent: the slot lies
    in a view of a page }
  Show := (FSlot <> nil) and FSlot.Visible and (Parent <> nil);
  if Show then
  begin
    C := FSlot.Parent;
    while Show and (C <> nil) and (C <> Parent) do
    begin
      Show := C.Visible;
      C := C.Parent;
    end;
    Show := Show and (C = Parent);
  end;
  Bar := Show and (FTopBar <> nil) and FSlot.ShowBar and (FTopBar.Parent = Parent);
  if Show then
  begin
    { the slot's place in the window's parent }
    if FSlot.Parent.HandleAllocated and Parent.HandleAllocated then
      P := Parent.ScreenToClient(FSlot.Parent.ClientToScreen(Point(FSlot.Left, FSlot.Top)))
    else
    begin
      P := Point(FSlot.Left, FSlot.Top);
      C := FSlot.Parent;
      while C <> Parent do
      begin
        Inc(P.X, C.Left);
        Inc(P.Y, C.Top);
        C := C.Parent;
      end;
    end;
    if Bar then
    begin
      H := Min(FTopBar.Height, FSlot.Height);
      UIMoveControls([FTopBar, Self], [Bounds(P.X, P.Y, FSlot.Width, H),
        Bounds(P.X, P.Y + H, FSlot.Width, FSlot.Height - H)]);
    end
    else
      SetBounds(P.X, P.Y, FSlot.Width, FSlot.Height);
  end;
  { shown again: above the views it lies over }
  if FTopBar <> nil then
  begin
    if Bar and not FTopBar.Visible then FTopBar.BringToFront;
    FTopBar.Visible := Bar;
  end;
  if Show and not Visible then BringToFront;
  Visible := Show;
end;

procedure TSciWindow.ApplyZoom;
begin
  if HandleAllocated and (Sci(SCI_GETZOOM) <> EditorOptions.Zoom) then Sci(SCI_SETZOOM, Cardinal(EditorOptions.Zoom));
end;

{ --- the window's messages: for the editor it shows --- }

procedure TSciWindow.BarInfo(Bar: TSciBar; var Info: TSciScrollInfo);
begin
  if FEdit <> nil then
    FEdit.BarInfo(Bar, Info)
  else
  begin
    Info.Visible := Bar = sbVert;
    Info.Pos := 0;
    Info.Max := 0;
    Info.Page := 1;
  end;
end;

procedure TSciWindow.BarScroll(Bar: TSciBar; Action: TSciScrollAction; Pos: Integer);
begin
  if FEdit <> nil then FEdit.BarScroll(Bar, Action, Pos);
end;

procedure TSciWindow.GetMarks(var Marks: TSciScrollMarks; out Count, Caret: Integer);
begin
  Count := 0;
  Caret := -1;
  if FEdit <> nil then FEdit.GetMarks(Marks, Count, Caret);
end;

procedure TSciWindow.CNNotify(var Message: TWMNotify);
begin
  if FEdit <> nil then FEdit.Notify(PSCNotification(Message.NMHdr));
  Message.Result := 0;
end;

{ a sample's scroll bar pressed: it says so, and the bar scrolls as well }
procedure TSciWindow.BarPress(Sender: TObject);
begin
  if (FEdit <> nil) and FEdit.FSample and Assigned(FEdit.FOnSampleClick) then
    FEdit.FOnSampleClick(FEdit, -1, -1, SampleScrollBar);
end;

procedure TSciWindow.WndProc(var Message: TMessage);
begin
  { a sample: a press of a mouse button only says where it was, the pointer is the arrow (a
    scroll bar's press: BarPress) }
  if (FEdit <> nil) and FEdit.FSample then
    case Message.Msg of
      WM_LBUTTONDOWN, WM_LBUTTONDBLCLK, WM_LBUTTONUP, WM_RBUTTONDOWN, WM_RBUTTONDBLCLK, WM_RBUTTONUP,
      WM_MBUTTONDOWN, WM_MBUTTONDBLCLK, WM_MBUTTONUP, WM_CONTEXTMENU:
        begin
          if Message.Msg = WM_LBUTTONDOWN then
            FEdit.SampleClicked(SmallInt(Message.LParamLo), SmallInt(Message.LParamHi));
          Message.Result := 0;
          Exit;
        end;
      WM_SETCURSOR:
        if Message.LParamLo = HTCLIENT then
        begin
          Windows.SetCursor(LoadCursor(0, IDC_ARROW));
          Message.Result := 1;
          Exit;
        end;
    end;
  { the window's clipboard messages are the editor's own commands: an expert's procedure first }
  if (FEdit <> nil) and ((Message.Msg = WM_CUT) or (Message.Msg = WM_COPY) or (Message.Msg = WM_PASTE) or
    (Message.Msg = WM_CLEAR)) then
    case Message.Msg of
      WM_CUT: if FEdit.MenuCommand('ClipCut') then Exit;
      WM_COPY: if FEdit.MenuCommand('ClipCopy') then Exit;
      WM_PASTE: if FEdit.MenuCommand('ClipPaste') then Exit;
    else
      if FEdit.MenuCommand('ClipClear') then Exit;
    end;
  { the wheel straight to Scintilla: TControl.WMMouseWheel writes the shift state over the message's
    keys before it passes the message on - ssLeft has MK_CONTROL's bit, so a turn with the left
    button down zoomed, and ssShift MK_LBUTTON's, so Shift did not scroll sideways }
  if Message.Msg = WM_MOUSEWHEEL then
  begin
    if not WheelZoom(TWMMouseWheel(Message)) then DefaultHandler(Message);
    Exit;
  end;
  if (Message.Msg = CN_KEYDOWN) or (Message.Msg = CN_SYSKEYDOWN) then
    KeyCommand(TWMKeyDown(Message))
  else
    inherited WndProc(Message);
end;

{ The wheel with the zoom key (SdZoom): an editor that takes the editors' zoom (OnZoom) zooms all
  of them, a point a notch (True: done); a sample keeps Scintilla's own zoom - its Ctrl+wheel. Without
  the key the wheel scrolls: Ctrl is taken off the message, for which Scintilla would zoom }
function TSciWindow.WheelZoom(var Message: TWMMouseWheel): Boolean;
begin
  Result := False;
  if not WheelZoomsKeys(Message.Keys) then
    Message.Keys := Message.Keys and not MK_CONTROL
  else if (FEdit <> nil) and Assigned(FEdit.FOnZoom) then
  begin
    ZoomByWheel(EditorZoom, FWheelZoom, True, Message.WheelDelta, Point(Message.XPos, Message.YPos));
    Message.Result := 0;
    Result := True;
  end
  else
    Message.Keys := (Message.Keys and not MK_SHIFT) or MK_CONTROL;
end;

{ CN_KEYDOWN, CN_SYSKEYDOWN: the editor's key mapping first, else the VCL (the menus' shortcuts);
  a keystroke macro that records hears of the key (the command may have closed the editor's page) }
procedure TSciWindow.KeyCommand(var Message: TWMKeyDown);
var
  E: TSciEdit;
  Shift: TShiftState;
  Rec: Boolean;
begin
  E := FEdit;
  Shift := KeyDataToShiftState(Message.KeyData);
  Rec := (E <> nil) and Assigned(SciMacroKeyStart) and SciMacroKeyStart(E);
  try
    if (E <> nil) and E.KeymapKey(Message.CharCode, Shift) then Message.Result := 1
    else inherited WndProc(TMessage(Message));
  finally
    if Rec and EditAlive(E) then E.KeyDispatched(Message.CharCode, Shift, Message.Result <> 0);
  end;
end;

procedure TSciWindow.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTALLKEYS or DLGC_WANTARROWS or DLGC_WANTTAB or DLGC_WANTCHARS or DLGC_HASSETSEL;
end;

procedure TSciWindow.CMWantSpecialKey(var Message: TCMWantSpecialKey);
begin
  Message.Result := 1;
end;

procedure TSciWindow.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

{ Scintilla paints the window (TCustomControl would paint it with its canvas) }
procedure TSciWindow.WMPaint(var Message: TWMPaint);
begin
  DefaultHandler(Message);
end;

procedure TSciWindow.WMNCPaint(var Message: TWMNCPaint);
begin
  inherited;
  if not FBorderless then UIPaintFrameBorder(Handle);
end;

procedure TSciWindow.WMChar(var Message: TWMChar);
begin
  if (FEdit <> nil) and not FEdit.CharArrives(Message.CharCode) then Exit;
  inherited;          // KeyPress: the editor's OnKeyPress, then Auto-close pairs and Overwrite blocks
end;

procedure TSciWindow.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);
  if FEdit <> nil then FEdit.KeyPress(Key);
end;

procedure TSciWindow.WMKeyDown(var Message: TWMKeyDown);
begin
  if FEdit <> nil then FEdit.KeyArrives(Message.CharCode);
  inherited;
end;

procedure TSciWindow.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FEdit <> nil then FEdit.KeyDown(Key, Shift);
end;

procedure TSciWindow.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
  if (FEdit <> nil) and Assigned(FEdit.FOnKeyUp) then FEdit.FOnKeyUp(FEdit, Key, Shift);
end;

procedure TSciWindow.WMKeyUp(var Message: TWMKeyUp);
begin
  if (Message.CharCode = VK_CONTROL) and (FEdit <> nil) then FEdit.ClearLink;
  inherited;
end;

procedure TSciWindow.WMLButtonDown(var Message: TWMLButtonDown);
begin
  if (FEdit <> nil) and FEdit.MouseDownArrives(Message.Keys, Message.XPos, Message.YPos) then Exit;
  inherited;
end;

procedure TSciWindow.WMMouseMove(var Message: TWMMouseMove);
begin
  inherited;
  if FEdit <> nil then FEdit.MouseMoved(Message.Keys, Message.XPos, Message.YPos);
end;

procedure TSciWindow.WMSetCursor(var Message: TWMSetCursor);
begin
  if (FEdit <> nil) and FEdit.LinkCursor(Message.HitTest) then Message.Result := 1
  else inherited;
end;

procedure TSciWindow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (FEdit <> nil) and Assigned(FEdit.FOnMouseDown) then FEdit.FOnMouseDown(FEdit, Button, Shift, X, Y);
end;

procedure TSciWindow.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (FEdit <> nil) and Assigned(FEdit.FOnMouseUp) then FEdit.FOnMouseUp(FEdit, Button, Shift, X, Y);
end;

procedure TSciWindow.DblClick;
begin
  inherited DblClick;
  if (FEdit <> nil) and Assigned(FEdit.FOnDblClick) then FEdit.FOnDblClick(FEdit);
end;

procedure TSciWindow.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  if (FEdit <> nil) and Assigned(FEdit.FOnFocusChange) then FEdit.FOnFocusChange(FEdit);
end;

procedure TSciWindow.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  if FEdit <> nil then
  begin
    FEdit.ClearLink;
    if Assigned(FEdit.FOnFocusChange) then FEdit.FOnFocusChange(FEdit);
  end;
end;

procedure TSciWindow.WMTimer(var Message: TWMTimer);
begin
  if Message.TimerID <> IdleTimerId then
  begin
    inherited;
    Exit;
  end;
  KillTimer(Handle, IdleTimerId);
  if FEdit <> nil then FEdit.IdleWork;
end;

procedure TSciWindow.WMTrimUndo(var Message: TMessage);
begin
  if FEdit <> nil then FEdit.TrimUndo;
end;

{ ---------------------------------------------------------------- TSciSlot }

destructor TSciSlot.Destroy;
begin
  if FWindow <> nil then FWindow.Follow(nil);
  inherited Destroy;
end;

procedure TSciSlot.SetEdit(Value: TSciEdit);
begin
  if FEdit = Value then Exit;
  FEdit := Value;
  if Value <> nil then Value.FreeNotification(Self);
  if FWindow <> nil then FWindow.Follow(Self);
end;

procedure TSciSlot.SetShowBar(Value: Boolean);
begin
  if FShowBar = Value then Exit;
  FShowBar := Value;
  Changed;
end;

procedure TSciSlot.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FEdit) then FEdit := nil;
end;

procedure TSciSlot.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
  Changed;
end;

procedure TSciSlot.CMVisibleChanged(var Message: TMessage);
begin
  inherited;
  Changed;
end;

procedure TSciSlot.Changed;
begin
  if FWindow <> nil then FWindow.Place;
end;

initialization
  InitQuotedStyles;

finalization
  SciEnding := True;
  { the worker goes with its parent; an editor it showed keeps no window }
  FreeAndNil(SciWorkHost);
  FreeAndNil(SciEdits);
end.
