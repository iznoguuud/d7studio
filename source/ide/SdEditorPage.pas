{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEditorPage;

{ D7 Studio - one open file: code editor, and for form units the embedded form designer.
  Also implements the source bridge that keeps the Pascal unit in step with the designer
  (component fields, uses clause, event handlers, renames). }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ExtCtrls, SdTabStrip,
  TypInfo, SdSciDefs, SdSciEdit, SdEncoding, SdCodeInsight, SdFormSrc, SdCompletion, SdDesignHost, SdKeymaps,
  SdFormDesigner, SdDesignUndo, SdDiagram, SdFileNames, SdHints, SdDbgEval, SdPageBar, SdZoom, SdHistory,
  SdHistoryFrame;

const
  CM_SD_DESIGNSTEP = WM_APP + 120;    // a change of the designer is over: one undo step
  CM_SD_CODEINSIGHT = WM_APP + 121;   // code insight asked for (the Open Tools API): WParam the key (InvokeCodeInsight)
  ModifiedMark = '*';                 // after the title of a modified page's tab (Visual Studio's)

type
  TEditorPage = class;

  { Services the main form provides to its pages }
  TIDEServices = class
  public
    function CodeInsight: TCodeInsight; virtual; abstract;
    function ProjectExeBase: string; virtual; abstract;
    procedure OpenFileAt(const FileName: string; Line, Col: Integer); virtual; abstract;
    procedure PageChanged(Page: TEditorPage); virtual; abstract;
    procedure FormRenamed(Page: TEditorPage; const OldName, NewName, OldClass, NewClass: string); virtual; abstract;
    { the debugger's value tip (SdHints.TSdValueTip; nothing is called): the value of Expr (ANSI) -
      False when it has none -, and the rows of an item of it that is opened }
    function EvaluateForTip(const Expr: string; out V: TDbgVar): Boolean; virtual; abstract;
    function ChildrenForTip(const Expr: string; out Vars: TDbgVarArray): Boolean; virtual; abstract;
    procedure ToggleBreakpoint(Page: TEditorPage; Line: Integer); virtual; abstract;
    procedure ShowMessage(const Text: string); virtual; abstract;
    procedure ShowStatus(const Text: string); virtual; abstract;     // the status bar's text
    procedure EditorContextMenu(Page: TEditorPage; const ScreenPt: TPoint); virtual; abstract;
    procedure ShowPage(Page: TEditorPage); virtual; abstract;      // its file tab, without the focus
    { a command of the key mapping that is a menu command of the IDE (SdKeymaps: Find, Save ...) }
    procedure EditorCommand(Page: TEditorPage; Cmd: TEdCmd; Arg: Integer); virtual; abstract;
    { visual form inheritance: the .dfm texts of form class ClassName and of its ancestors, the
      first ancestor first (False: one of them is not to be found) - Page's project's forms first }
    function AncestorDfms(Page: TEditorPage; const ClassName: string; Dfms: TStrings): Boolean; virtual; abstract;
    { the class at the base of form class ClassName's chain of project forms - the one the first of
      them derives from (TForm, TFrame, TDataModule, a custom module's class) - with the chain's
      .dfm texts in Dfms as AncestorDfms has them; '' when one of them is not to be found }
    function FormBase(Page: TEditorPage; const ClassName: string; Dfms: TStrings): string; virtual;
    { the unit that declares form class ClassName of Page's project (as AncestorDfms finds its
      form); '' when there is none }
    function FormUnitName(Page: TEditorPage; const ClassName: string): string; virtual;
    { the Diagram tab's tool bar: one for every page, on the bar of the page whose diagram is shown }
    function DiagramBar: TWinControl; virtual; abstract;
    { the main form's other bars lent to the bar of the page shown (SdPageBar): the navigation boxes
      over the code, the zoom bar, the History tab's tool bar, the designer's tool bar - nil: none }
    function NavigationBar: TWinControl; virtual;
    function ZoomBar: TWinControl; virtual;
    function HistoryBar: TWinControl; virtual;
    function DesignerBar: TWinControl; virtual;
    { a page's History tab is made: its menus (the main form's) }
    procedure HistoryViewMade(View: TSdHistoryView); virtual;
    { what Page's bar holds changed (Editor Options | Navigation bar, another kind of file): the
      bar of the page shown is arranged again }
    procedure PageBarChanged(Page: TEditorPage); virtual;
    { the text of a page changed at Position (LinesAdded lines more or fewer) / a component of its
      form was renamed: the Open Tools API's notifiers hear it }
    procedure PageEdited(Page: TEditorPage; Position, LinesAdded: Integer); virtual;
    { Error Insight's errors of a page are new (TEditorPage.Errors): the status bar and the list of the
      page shown follow them }
    procedure ErrorsChanged(Page: TEditorPage); virtual;
    procedure ComponentRenamed(Page: TEditorPage; const OldName, NewName: string); virtual;
    { the zoom of a page's editor changed (Ctrl+wheel; EditorOptions.Zoom): every editor takes it }
    procedure EditorZoomed(Page: TEditorPage); virtual;
    { code insight of the Open Tools API (SdOtaCodeInsight): an expert's IOTACodeInsightManager
      for the page's file takes Key - #0 the list, #1 the parameters, #2 browse at Pos, #3 the
      hint at Pos, '.' and '(' typed. True: taken (or no code insight for the file now), D7
      Studio's own code insight does nothing. The defaults: nothing taken, all allowed. }
    function CIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean; virtual;
    { D7 Studio's own code insight may run on the page: its built-in manager is the file's }
    function CIOwnAllowed(Page: TEditorPage): Boolean; virtual;
    { while an expert's list or parameter hint shows on the page: its keys first (True: taken),
      the text or the caret changed, the session ended without Done (focus lost, scrolled, the
      page goes) }
    function CIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean; virtual;
    function CIKeyPress(Page: TEditorPage; var Key: Char): Boolean; virtual;
    procedure CIChanged(Page: TEditorPage); virtual;
    procedure CICancel(Page: TEditorPage); virtual;
  end;

  TPageBridge = class(TSdSourceBridge)
  private
    FPage: TEditorPage;
  public
    function GetUnitName: string; override;
    function GetUnitFileName: string; override;
    function GetFormFileName: string; override;
    function GetProjectExeBase: string; override;
    procedure DesignerModified; override;
    procedure ComponentAdded(C: TComponent); override;
    procedure ComponentRemoved(const AName: string); override;
    procedure ComponentRenamed(const OldName, NewName: string); override;
    procedure RootRenamed(const OldName, NewName, OldClass, NewClass: string); override;
    function MethodExists(const AName: string): Boolean; override;
    procedure GetCompatibleMethods(TypeData: PTypeData; Proc: TGetStrProc); override;
    function CreateMethod(const AName: string; TypeData: PTypeData): Boolean; override;
    procedure RenameMethod(const OldName, NewName: string); override;
    procedure ShowMethod(const AName: string); override;
    procedure ActivateDesigner; override;
    procedure SelectionChanged; override;
    function FrameDfms(const AClassName: string; Dfms: TStrings): Boolean; override;
    procedure ChainCall(const MethodName, InstancePath, InstanceMethod: string; TypeData: PTypeData); override;
  end;

  { the page's file and its form for the History tab (SdHistoryFrame) }
  TPageHistoryHost = class(THistoryHost)
  private
    FPage: TEditorPage;
  public
    function FileName(Form: Boolean): string; override;
    function HasForm: Boolean; override;
    function CurrentText(Form: Boolean): string; override;
    function CurrentBytes(Form: Boolean): string; override;
    function TextEncoding(Form: Boolean): TSdEncoding; override;
    function Modified(Form: Boolean): Boolean; override;
    function CanEdit(Form: Boolean): Boolean; override;
    procedure Restore(Form: Boolean; const Text: string); override;
    procedure GotoLine(Line: Integer); override;
  end;

  { the page of a file: a frame, reused - one per open file (SdEditorPage.dfm: the design panel,
    the timers and their events); the editor, the Code / Design / Diagram tabs and the diagram,
    D7 Studio's own controls, are made in code. The editor is the file's text without a window of
    its own: the file area's one window shows the editor of the page shown, over the page's slot
    (TSciWindow.Follow). Pages are unnamed (SetName): many share an owner }
  TEditorPage = class(TFrame)
    DesignPanel: TPanel;
    AutoTimer: TTimer;
    HintTimer: TTimer;           // the parameter hint follows a caret that stopped moving (100 ms)
    IdentTimer: TTimer;          // Identifier matching after the caret stopped in a word (250 ms)
    NameTimer: TTimer;           // names by kind after a pause of the text and the scrolling (250 ms)
    ErrorTimer: TTimer;          // Error Insight after a pause of the text (1 s)
    procedure HintTimerTick(Sender: TObject);
    procedure IdentTimerTick(Sender: TObject);
    procedure NameTimerTick(Sender: TObject);
    procedure ErrorTimerTick(Sender: TObject);
    procedure AutoTimerTick(Sender: TObject);
  private
    FFileName: string;
    FUntitled: Boolean;
    FEditor: TSciEdit;
    FViewFrame: TWinControl;         // the views' flat frame: the page bar on top, the view shown under it
    FPageBar: TSdPageBar;            // the page's tool bar (SdPageBar)
    FCodeArea: TWinControl;          // the code view: the slot
    FSlot: TSciSlot;                 // where the editor is shown
    FViewTabs: TSdTabStrip;          // Code / Design / Diagram (themed tabs, as the dock's)
    FDiagram: TSdDiagramView;        // the Diagram tab (made when it is first shown)
    FDiagramView: Boolean;
    FDiagramShown: Boolean;          // ... it was shown before: its selection and place stay
    FHistory: TSdHistoryView;        // the History tab (made when it is first shown)
    FHistoryView: Boolean;
    FHistoryHost: TPageHistoryHost;
    FKeptVersion: Integer;           // the text's TextVersion its last Unsaved version was taken of
    FDesigner: TFormDesigner;
    FBridge: TPageBridge;
    FHasForm: Boolean;
    FDfmText: string;
    FDfmBinary: Boolean;          // the form file is binary: it is saved binary again
    FFormClass: string;
    FFormModified: Boolean;
    FFormNew: Boolean;               // a new page's form: written at the first save, not modified (Delphi 7's form editor)
    { the units of the components placed on the form, Name=Unit: Delphi 7's designer puts them into the
      uses clause when the module is saved or compiled (AddPlacedUnits), not as they are placed }
    FPlacedUnits: TStringList;
    FEncodingChanged: Boolean;    // converted to another encoding, not saved yet
    FDesignView: Boolean;
    FDesignFailed: Boolean;
    FFormTextPage: TEditorPage;  // View as Text: the page that shows this unit's form as text
    FFormOwner: TEditorPage;     // ... this page is it: the unit whose form it shows
    FSwallowChar: Boolean;
    FIncSearch: Boolean;           // Search | Incremental Search is on
    FIncPending: string;           // the bytes of a character typed so far (TypedIdeChar)
    FIncText: string;
    FIncStart: Integer;
    FRootKind: THostKind;
    FRootModule: TComponentClass;  // a custom module's class (DetectRootKind), nil: none
    FRootExtra: TStringList;
    FHadColor: Boolean;
    FAutoDismissed: Integer;     // start of the word whose automatic list was closed with Esc
    FIdentAt, FIdentVersion: Integer;  // ... the word and the text they were found for (-1 none)
    FNames: TSciNames;                 // names by kind: the names of the last pass (NameTimerTick)
    FNamesVersion: Integer;            // ... the text they were coloured for (-1: none coloured)
    FNamesFrom, FNamesTo: Integer;     // ... the part of that text coloured
    FErrors: TCIErrors;                // Error Insight: the errors of the last check (ErrorTimerTick)
    FErrorCount: Integer;
    FErrorsVersion: Integer;           // ... the text they were found in (-1: none)
    FErrorsGen: Integer;               // ... the texts of every page then (ErrorInsightGen)
    FErrorsStamp: Integer;             // a new number for every new list of errors (ErrorsStampGen)
    { the text's changes are counted (SCN_MODIFIED): the completion list and the parameter hint
      are refreshed once for each change of the text or the caret, not again for the same state }
    FTextVersion: Integer;
    FListVersion, FListCaret: Integer;     // ... what the completion list saw last
    FHintVersion, FHintCaret: Integer;     // ... what the parameter hint saw last
    FFileStamp: TSdFileStamp;    // the file as it was read or written (an outside change)
    FUndo: TDesignUndo;          // the designer's undo and redo
    FUndoBusy: Boolean;          // ... a step is being taken back or made again
    FStepPosted: Boolean;        // ... CM_SD_DESIGNSTEP is on its way
    FTabMarked: Boolean;         // its file tab shows the modified mark
    FMarked: Boolean;            // modified without a change (MarkModified) until it is saved
    FFileSystem: string;         // an expert's file system the file is read and written through ('' the disk)
    FFsAge: Integer;             // ... the file's age there when it was read or written
    FFsBinary: Boolean;          // ... a binary form file, shown as text: written binary again
    FBookmarkCols: array[0..9] of Integer;   // the column of each bookmark (bytes into its line)
    procedure ViewTabsChange(Sender: TObject);
    procedure UpdateViewTabs;
    procedure ShowView(TakeFocus: Boolean);
    { the form has changes not saved (its text, the designer's) }
    function FormChanged: Boolean;
    { a form's text as its file holds it: binary when the file is }
    function FormBytesOf(const Dfm: string): string;
    procedure DiagramGoto(Sender: TObject; Line, Col: Integer);
    procedure EditorCharAdded(Sender: TObject; Ch: Integer);
    procedure EditorUpdateUI(Sender: TObject; Updated: Integer);
    procedure EditorViewApplied(Sender: TObject);
    procedure NamesChanged;
    function NamesWanted: Boolean;
    procedure ErrorsChanged;
    function ErrorsWanted: Boolean;
    procedure TakeErrors(const Source: string);
    procedure ColourNames(FromPos, ToPos: Integer);
    procedure EditorModified(Sender: TObject; ModType, Position, Len, LinesAdded: Integer);
    procedure EditorSavePoint(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    function IncSearchFind(FromPos: Integer): Boolean;
    procedure EndIncSearch;
    procedure EditorMarginClick(Sender: TObject; Margin, Line: Integer; Shift: TShiftState);
    procedure EditorCommand(Sender: TObject; Cmd: TEdCmd; Arg: Integer);
    procedure EditorCtrlClick(Sender: TObject; Position: Integer);
    procedure EditorDwellStart(Sender: TObject; Position, X, Y: Integer);
    procedure EditorDwellEnd(Sender: TObject);
    { the hover tips shown for this page's editor go: the code tip, and with Value the value tip }
    procedure HideTips(Value: Boolean);
    procedure EditorFocusChange(Sender: TObject);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure UpdateParamHint(Force: Boolean);
    procedure IdentCaretMoved;
    procedure EditorZoom(Sender: TObject);
    procedure CompletionTextChanged;
    procedure ToggleDeclImpl;
    procedure OpenCompletion(Auto: Boolean);
    function AutoPrefixAtCaret(var StartPos: Integer): string;
    function ChosenEncoding(var E: TSdEncoding): Boolean;
    procedure SetFileSystem(const Value: string);
    procedure SaveToFileSystem;
    procedure TakeText(const AFileName, AFileSystem, Text: string; E: TSdEncoding; RO: Boolean;
      Age: Integer; Binary: Boolean);
    procedure DetectRootKind;
    procedure FormMessage(const Text: string);      // "Unit1.dfm: Text" in Messages
    function DfmToHost(const Dfm: string; Own: Boolean = True): string;
    function DfmFromHost(const Dfm: string): string;
    { Src in place of the source (Old: the source as it was); one undo step of the editor. The
      designer's own edits (ForDesigner) are part of the designer's undo step as well. }
    function SourceEdit(var Src: string; const Old: string; ForDesigner: Boolean = False): Boolean;
    function ReplaceSource(const NewSource: string; var Pos: Integer; var OldText, Removed, Inserted: string): Boolean;
    function LoadAncestors(const Dfm: string; Anc: TStrings): Boolean;
    function ReadAncestors(Anc: TStrings): Boolean;
    procedure ReadFormAgain(const Before, Text: string);
    procedure DesignChanged;
    procedure DesignSelectionChanged;
    procedure PostDesignStep;
    procedure CommitDesignStep;
    procedure TakeDesignStep(Back: Boolean);
    procedure CMDesignStep(var Message: TMessage); message CM_SD_DESIGNSTEP;
    procedure CMCodeInsight(var Message: TMessage); message CM_SD_CODEINSIGHT;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure WMWindowPosChanged(var Message: TWMWindowPosChanged); message WM_WINDOWPOSCHANGED;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure SetName(const NewName: TComponentName); override;
  public
    { Delphi's bookmarks 0..9 (Toggle / Goto Bookmarks: the main form's actions, Shift+Ctrl+0..9 and Ctrl+0..9) }
    procedure ToggleBookmark(N: Integer);
    procedure SetBookmark(N: Integer);
    function BookmarkCol(N: Integer): Integer;
    procedure GotoBookmark(N: Integer);
    { Complete Class at Cursor (Shift+Ctrl+C): SdFormSrc.FSCompleteClass, one undo step, the caret
      in the first new body; False: nothing to complete }
    function CompleteClass(FinishProperties: Boolean): Boolean;
    { View as Text (Alt+F12, Delphi's): this page shows Owner's form as .dfm text - Owner's
      designer goes then (DropDesigner); View as Form: the text back into the form (False: it
      cannot be read, the page stays). Saving either page saves the unit and its form
      (TakeFormText) }
    procedure ShowFormText(Owner: TEditorPage);
    procedure DropDesigner;
    function ApplyFormText: Boolean;
    procedure TakeFormText;
    { the units of the components placed since the last save that are on the form still, into the
      uses clause (one undo step): before the module is saved or compiled }
    procedure AddPlacedUnits;
    { ... those units, added to Units (code insight counts them in the unit's scope already) }
    procedure PlacedUnitNames(Units: TStrings);
    procedure DetachFormText;
    function FormFileName: string;                  // the unit's form file
    property FormOwner: TEditorPage read FFormOwner;
    property FormTextPage: TEditorPage read FFormTextPage;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: string);
    { the file of an expert's file system (IOTAFileSystem): AFileName as the expert gives it (no
      path of the disk), read through it in the encoding its bytes tell - a binary form file of a
      file system of files as text -, read-only when the file system says so. Saved, the page
      writes through it; Save As writes to the disk and leaves it. An error raises. }
    procedure LoadFromFileSystem(const AFileName, AFileSystem: string);
    { an existing file shown with Text, not read: a creator's of an existing file (IOTACreator)
      gives it - not modified }
    procedure LoadWithText(const AFileName, AFileSystem, Text: string);
    { the file read again from the disk, written by another program meanwhile (the main form
      asks Delphi's question first): the text in its encoding and the form from its .dfm - the
      designer of the old form goes (the caller lets the Object Inspector and the Object TreeView
      go of it first) and is made again when the page shows the form }
    procedure Reload;
    { File | Reopen with Encoding: the file's bytes read again in AEncoding, remembered at once;
      Convert to Encoding: the text kept, written in AEncoding from now on - remembered when the
      file is saved (under the name it is saved as) and its bytes would not tell it
      (EncodingWritten), so that unsaved bytes are never read in it }
    procedure ReopenWithEncoding(const AEncoding: TSdEncoding);
    function ConvertToEncoding(const AEncoding: TSdEncoding): Boolean;
    function Encoding: TSdEncoding;
    procedure RememberEncoding(const AEncoding: TSdEncoding);
    { a new file in memory: untitled (Save asks for its name), or Named - AFileName, written
      when the page is saved }
    procedure NewFile(const AFileName, Source, DfmText: string; Named: Boolean = False);
    function Save: Boolean;
    function SaveAs(const NewFileName: string): Boolean;
    { under another name, nothing written - the page modified (Delphi 7's IOTAModule.FileName) }
    procedure Rename(const NewFileName: string);
    { Delphi drops event handlers that were never filled in when a unit is saved or compiled }
    procedure RemoveEmptyHandlers;
    { the form as Save writes it ('' without a form); the unit's bytes are Editor.FileBytes }
    function CurrentDfm: string;
    function Modified: Boolean;
    { the text needs saving - its changes, an expert's mark, a new encoding, no file yet: Modified
      without the form's changes (the Open Tools API's source editor) }
    function SourceModified: Boolean;
    { modified although nothing changed (the Open Tools API's MarkModified): Save asks for it, until
      it is saved }
    procedure MarkModified;
    function GetSource: string;
    function GetDfmText: Boolean;
    procedure SetDfmText(Value: Boolean);
    procedure SetSource(const NewSource: string);
    { ... as one undo step of the editor (the IDE's edits of a unit: Use Unit, To-Do comments ...) }
    procedure SetSourceUndoable(const NewSource: string);
    function IsPascal: Boolean;
    function UnitName: string;
    { the title of its file tab; a modified file's ends in '*' }
    function TabCaption: string;
    function TabCaptionW: WideString;
    { the mark its tab shows (the main form sets the tab's title and this together) }
    property TabMarked: Boolean read FTabMarked write FTabMarked;
    function IsUnitFile: Boolean;
    { 1-based; Col is the column of code insight and the parser (the bytes of the line before
      the place + 1: tabs and characters of several bytes as they count there). A column as the
      user sees it (tabs to their stops) is Editor.GotoLineCol's. }
    procedure GotoLine(Line, Col: Integer);
    { Delphi's TCustomEditControl.ShowText (the Code Explorer's Enter): TopLine the window's top line
      (0: the text's first), then the caret at Line, Col (code insight's columns), scrolled into view
      as little as needed }
    procedure ShowText(TopLine, Line, Col: Integer);
    function EnsureDesigner: Boolean;
    { Edit | Undo and Redo in the design view: every change of the designer is one step, the
      unit's source goes back with the form (SdDesignUndo) }
    function CanDesignUndo: Boolean;
    function CanDesignRedo: Boolean;
    procedure DesignUndo;
    procedure DesignRedo;
    function DesignUndoState: string;        // test mode: undo steps/redo steps
    { the designer is shown: a frame placed on its form or an ancestor of its form that changed
      since the form was read (its open page's changes too) - the form is read again, its own
      changes and the selection kept }
    procedure FollowAncestors;
    { the form's text NewText (as CurrentDfm gives it) in place of the current one - a component
      renamed in a frame or an ancestor the form is built from renames its "inherited" entries:
      the designer reads it, or (none made yet) it is the form's text from now on }
    procedure TakeChangedForm(const NewText: string);
    { Value: the design view; else the code (also from the Diagram tab) }
    procedure ShowDesign(Value: Boolean; TakeFocus: Boolean = True);
    { the Diagram tab: Value - the unit's classes, made again from its text; else
      the code }
    procedure ShowDiagram(Value: Boolean; TakeFocus: Boolean = True);
    function CanDiagram: Boolean;          // a Pascal unit, program or package
    { the History tab: Value - the file's versions against its text now; else the code }
    procedure ShowHistory(Value: Boolean; TakeFocus: Boolean = True);
    { the file has a History tab: a file of the disk while Editor Options keep the files' history }
    function CanHistory: Boolean;
    { the versions of the page's file or its form file changed (SdHistory.OnHistoryChanged) }
    procedure HistoryChanged;
    { Editor Options changed: the History tab comes or goes, its windows take the options }
    procedure HistoryOptionsChanged;
    { the text in the editor kept as a version of Kind (hkUnsaved, hkClosed, hkReloaded) - the
      unit's and its form's, each when it has changes not saved; hkUnsaved only when the text
      changed since the last one }
    procedure KeepVersion(Kind: THistoryKind);
    { the unit and its form as the disk has them: a version of each that another program changed
      since its newest (SdHistory.HistoryCheckDisk) }
    procedure CheckHistoryDisk;
    function CodeView: Boolean;            // the editor is shown (neither design, diagram nor history)
    { the tab of the view shown: Code, Design, Diagram or History }
    function ViewTab: string;
    { the navigation boxes over the code: on a Pascal file while Editor Options shows them }
    function NavigationWanted: Boolean;
    procedure ApplyNavigationBar;          // ... the bar of the page shown follows a change
    { the page bar holds the zoom bar first, then what the view shown puts there - the navigation
      boxes over a Pascal file's code, the Diagram tab's buttons, the History tab's bar: the main
      form's bars, lent to the page shown (TMainForm.ArrangePageBar, while nothing of the centre
      reaches the screen) }
    procedure ArrangePageBar;
    property PageBar: TSdPageBar read FPageBar;
    { the zoom of the view shown: the editors' (one for every editor), the designer's (each form's
      own), the diagram's (each page's own) }
    function ZoomView: ISdZoomView;
    procedure ToggleView;
    { code insight as Delphi's key mapping asks for it - Key #0 the list (Ctrl+Space), #1 the
      parameters (Shift+Ctrl+Space), '.' and '(' typed: an expert's manager for the file (the
      Open Tools API), else D7 Studio's own }
    procedure InvokeCodeInsight(Key: Char);
    procedure ShowCompletion;
    procedure ShowParamHint;
    function TemplateAccepted(const Item: TCIItem; PrefixStart: Integer): Boolean;
    { Ctrl+J: the code templates of the file type for the word at the caret - one that matches it
      exactly goes in at once, else the list (SdCodeTemplates) }
    procedure ShowCodeTemplates;
    { Edit | Format Source: the lines of the selection (Selection, with
      one), else the whole text, by the formatter options - one undo step; the caret, the
      selection and the lines in view stay with their text. '' or why it could not be done }
    function FormatSource(Selection: Boolean): string;
    { the formatter can format the text of this page (a Pascal source or a form file) }
    function CanFormat: Boolean;
    { Search | Incremental Search (Ctrl+E): typed characters search from the caret; Ctrl+E again
      finds the next match }
    procedure IncrementalSearch;
    procedure FindDeclarationAtCaret;
    procedure CloseCodePopups;
    function WordAtCaret: string;       // in the system code page (the IDE's strings)
    { the designator the word at the caret ends (P^.Field, Items[I].Name; no parentheses: the
      debugger's dialogs may call what they evaluate), in the system code page }
    function DesignatorAtCaret: string;
    function CheckFileChanged: Boolean;
    procedure SimulateKey(Key: Word; Shift: TShiftState);    // automated tests
    property FileName: string read FFileName;
    { the ID of the expert's file system the file is read and written through ('' the disk):
      set, the next Save writes through it ('' the disk again) }
    property FileSystem: string read FFileSystem write SetFileSystem;
    property FileStamp: TSdFileStamp read FFileStamp;  // the file as it was read or last written
    property TextVersion: Integer read FTextVersion;   // goes up with every change of the text
    { Error Insight: the errors of the text as last checked (code insight's Diagnose, in the text's
      order; their places then - the editor's marks move with the text: Editor.ErrorAt), their number,
      a number no other list of any page has had (0: none yet) }
    property Errors: TCIErrors read FErrors;
    property ErrorCount: Integer read FErrorCount;
    property ErrorsStamp: Integer read FErrorsStamp;
    property Untitled: Boolean read FUntitled;
    property Editor: TSciEdit read FEditor;
    property Slot: TSciSlot read FSlot;
    property Designer: TFormDesigner read FDesigner;
    property HasForm: Boolean read FHasForm;
    property DesignView: Boolean read FDesignView;
    property DiagramView: Boolean read FDiagramView;
    property Diagram: TSdDiagramView read FDiagram;      // nil until the tab was first shown
    property HistoryView: Boolean read FHistoryView;
    property History: TSdHistoryView read FHistory;      // nil until the tab was first shown
    property FormClass: string read FFormClass;
    property FormModified: Boolean read FFormModified;
    { the form file is text, else binary (the designer's Text DFM): a change is saved with the form }
    property DfmText: Boolean read GetDfmText write SetDfmText;
  end;

var
  IDE: TIDEServices;
  CompletionPopup: TCompletionPopup;
  ParamHint: TParamHintWindow;
  { the editors' hover tips: code - a declaration, an expert's hint -, the debugger's
    value }
  CodeTip: TSdCodeTip;
  ValueTip: TSdValueTip;

{ an event type's parameters as a declaration writes them ("Sender: TObject"); Names (nil: not
  wanted) gets their names }
function MethodParamsFromTypeData(TypeData: PTypeData; var ResultType: string; Names: TStrings = nil): string;

{ an inherited form's .dfm: "inherited Form2: TForm2" (visual form inheritance) }
function IsInheritedDfm(const Dfm: string): Boolean;

{ Text below is editor text (the encoding of a file that is not open: SdSettings.FileEncoding).
  A file has been written as Bytes in E: E is remembered when the bytes alone would read as
  another encoding (ASCII text in UTF-8), or when another one was remembered }
procedure EncodingWritten(const FileName, Bytes: string; const E: TSdEncoding);
{ a file read as the editor opens it; E: its encoding }
function ReadSourceFile(const FileName: string; out E: TSdEncoding): string;
{ ... as editor text of E, to be put into a page of that encoding (converted when it can be) }
function ReadSourceFileAs(const FileName: string; const E: TSdEncoding): string;
{ Text written into a file in E (EncodingWritten); the bytes written }
function WriteSourceFile(const FileName, Text: string; const E: TSdEncoding): string;
{ ... a file the IDE rewrites without its editor (Format Project): its history's versions before and
  after the write (SdHistory), Writer named in it }
procedure RewriteSourceFile(const FileName, Text: string; const E: TSdEncoding; const Writer: string);
{ a form file's bytes as the IDE's text of it - a binary one converted, a text one's characters of
  the system code page as D7 Studio's }
function FormTextOfBytes(const Bytes: string): string;

implementation

{$R *.dfm}

uses
  Proxies, Graphics, SdUI, SdProject, SdSettings, SdPasParser, SdEditorThemes, SdEditorOptions, SdCodeTemplates,
  SdFormatter, SdFormatterOptions, SdPageFileSystem;

const
  MaxIdentText = 1024 * 1024;      // a larger text: the word's places by text, not by code insight
  { a larger text: no names by kind. A pass after an edit costs the parse - measured 10 .. 17 ms a
    MB on Delphi 7's largest units -, so up to ~150 ms here; the block structure's limit }
  MaxNamesText = 8 * 1024 * 1024;
  NameViewMargin = 40;             // the lines above and below the view whose names are coloured too
  { a name's kind (code insight's) as the element of the editor's colours }
  KindElements: array[TCIKind] of TEditorElement = (
    eeIdentifier, eeIdentifier,                       // ckUnknown, ckKeyword
    eeUnitName, eeConstant, eeVariable,               // ckUnit, ckConst, ckVar
    eeType, eeType, eeType, eeType, eeType,           // ckType, ckClass, ckInterface, ckRecord, ckEnum
    eeConstant,                                       // ckEnumValue
    eeRoutine, eeRoutine, eeRoutine, eeRoutine,       // ckProcedure, ckFunction, ckConstructor, ckDestructor
    eeProperty, eeField, eeParameter, eeLocalVar,     // ckProperty, ckField, ckParam, ckLocalVar
    eeIdentifier, eeConstant, eeIdentifier);          // ckLabel, ckResourceString, ckTemplate
  { the tabs below a Pascal page }
  CodeTab = 'Code';
  DesignTab = 'Design';
  DiagramTab = 'Diagram';
  HistoryTab = 'History';

type
  { the views of a page inside the views' flat 1 px frame: the page bar at the top, under it the
    view shown - the code view (the editor window lies over its slot), the design view, the
    diagram. They cover it but for the frame; the frame is in the client area, so that the slot's
    place adds up from the controls' bounds before there are windows (TSciWindow.Place) }
  TViewFrame = class(TSdControl)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure Paint; override;
  end;

  { the code view of a page: its slot, which the editor window lies over }
  TCodeArea = class(TSdControl)
  private
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
  end;

procedure TViewFrame.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TViewFrame.AdjustClientRect(var Rect: TRect);
begin
  inherited AdjustClientRect(Rect);
  InflateRect(Rect, -1, -1);
end;

procedure TViewFrame.Paint;
var
  R: TRect;
begin
  R := ClientRect;
  UIDrawBorder(Canvas.Handle, R);
  InflateRect(R, -1, -1);
  UIFill(Canvas.Handle, R, clWindow);
end;

procedure TCodeArea.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TCodeArea.Paint;
begin
  UIFill(Canvas.Handle, ClientRect, clWindow);
end;

{ shown or hidden with the code view: the window over the slot follows }
procedure TCodeArea.CMVisibleChanged(var Message: TMessage);
var
  I: Integer;
begin
  inherited;
  for I := 0 to ControlCount - 1 do
    if Controls[I] is TSciSlot then TSciSlot(Controls[I]).Changed;
end;

function MethodParamsFromTypeData(TypeData: PTypeData; var ResultType: string; Names: TStrings): string;
var
  P: PChar;
  I: Integer;
  Flags: TParamFlags;
  PName, PType, S: string;
begin
  Result := '';
  ResultType := '';
  P := @TypeData^.ParamList;
  for I := 1 to TypeData^.ParamCount do
  begin
    Flags := TParamFlags(Pointer(P)^);
    Inc(P, SizeOf(TParamFlags));
    PName := PShortString(P)^;
    if Names <> nil then Names.Add(PName);
    Inc(P, Length(PName) + 1);
    PType := PShortString(P)^;
    Inc(P, Length(PType) + 1);
    S := '';
    if pfVar in Flags then S := 'var '
    else if pfConst in Flags then S := 'const '
    else if pfOut in Flags then S := 'out ';
    S := S + PName;
    if PType <> '' then
    begin
      S := S + ': ';
      if pfArray in Flags then S := S + 'array of ';
      S := S + PType;
    end;
    if Result <> '' then Result := Result + '; ';
    Result := Result + S;
  end;
  if TypeData^.MethodKind = mkFunction then ResultType := PShortString(P)^;
end;

{ ---------------------------------------------------------------- TIDEServices }

function TIDEServices.FormBase(Page: TEditorPage; const ClassName: string; Dfms: TStrings): string;
begin
  Result := '';
end;

function TIDEServices.FormUnitName(Page: TEditorPage; const ClassName: string): string;
begin
  Result := '';
end;

function TIDEServices.NavigationBar: TWinControl;
begin
  Result := nil;
end;

function TIDEServices.ZoomBar: TWinControl;
begin
  Result := nil;
end;

function TIDEServices.HistoryBar: TWinControl;
begin
  Result := nil;
end;

function TIDEServices.DesignerBar: TWinControl;
begin
  Result := nil;
end;

procedure TIDEServices.HistoryViewMade(View: TSdHistoryView);
begin
end;

procedure TIDEServices.PageBarChanged(Page: TEditorPage);
begin
end;

var
  { goes up with every change of a page's text: Error Insight checks a page again when it is shown
    after another page's text changed (code insight reads the open files' texts) }
  ErrorInsightGen: Integer = 0;
  { the last number given to a page's list of errors (ErrorsStamp): unique over every page, so that a
    page made where a closed one was is never taken for it }
  ErrorsStampGen: Integer = 0;

procedure TIDEServices.PageEdited(Page: TEditorPage; Position, LinesAdded: Integer);
begin
end;

procedure TIDEServices.ErrorsChanged(Page: TEditorPage);
begin
end;

procedure TIDEServices.ComponentRenamed(Page: TEditorPage; const OldName, NewName: string);
begin
end;

procedure TIDEServices.EditorZoomed(Page: TEditorPage);
begin
end;

function TIDEServices.CIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
begin
  Result := False;
end;

function TIDEServices.CIOwnAllowed(Page: TEditorPage): Boolean;
begin
  Result := True;
end;

function TIDEServices.CIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
end;

function TIDEServices.CIKeyPress(Page: TEditorPage; var Key: Char): Boolean;
begin
  Result := False;
end;

procedure TIDEServices.CIChanged(Page: TEditorPage);
begin
end;

procedure TIDEServices.CICancel(Page: TEditorPage);
begin
end;

{ ---------------------------------------------------------------- TPageBridge }

function TPageBridge.GetUnitName: string;
begin
  Result := FPage.UnitName;
end;

function TPageBridge.GetUnitFileName: string;
begin
  Result := FPage.FFileName;
end;

function TPageBridge.GetFormFileName: string;
begin
  Result := FPage.FormFileName;
end;

function TPageBridge.GetProjectExeBase: string;
begin
  if IDE <> nil then Result := IDE.ProjectExeBase else Result := '';
end;

procedure TPageBridge.DesignerModified;
begin
  FPage.FFormModified := True;
  FPage.DesignChanged;
  if IDE <> nil then IDE.PageChanged(FPage);
end;

procedure TPageBridge.SelectionChanged;
begin
  FPage.DesignSelectionChanged;
end;

procedure TPageBridge.ComponentAdded(C: TComponent);
var
  Src, Old, U: string;
begin
  Src := FPage.GetSource;
  Old := Src;
  FSAddField(Src, FPage.FFormClass, C.Name, C.ClassName);
  { a placed frame: the designer made its class (no unit of its own) - the unit is the project's
    that declares it }
  if csInline in C.ComponentState then
  begin
    if IDE <> nil then U := IDE.FormUnitName(FPage, C.ClassName) else U := '';
  end
  else
    U := ClassUnitName(C.ClassType);
  if U <> '' then
  begin
    if FPage.FPlacedUnits = nil then FPage.FPlacedUnits := TStringList.Create;
    FPage.FPlacedUnits.Values[C.Name] := U;
  end;
  FPage.SourceEdit(Src, Old, True);
end;

procedure TPageBridge.ComponentRemoved(const AName: string);
var
  Src, Old: string;
begin
  Src := FPage.GetSource;
  Old := Src;
  FSRemoveField(Src, FPage.FFormClass, AName);
  FPage.SourceEdit(Src, Old, True);
end;

procedure TPageBridge.ComponentRenamed(const OldName, NewName: string);
var
  Src, Old: string;
  I: Integer;
begin
  Src := FPage.GetSource;
  Old := Src;
  FSRenameField(Src, FPage.FFormClass, OldName, NewName);
  FPage.SourceEdit(Src, Old, True);
  if FPage.FPlacedUnits <> nil then
  begin
    I := FPage.FPlacedUnits.IndexOfName(OldName);
    if I >= 0 then FPage.FPlacedUnits[I] := NewName + '=' + FPage.FPlacedUnits.ValueFromIndex[I];
  end;
  if IDE <> nil then IDE.ComponentRenamed(FPage, OldName, NewName);
end;

procedure TPageBridge.RootRenamed(const OldName, NewName, OldClass, NewClass: string);
var
  Src, Old: string;
begin
  Src := FPage.GetSource;
  Old := Src;
  FSRenameClass(Src, OldClass, NewClass);
  FSRenameFormVar(Src, NewClass, OldName, NewName);
  FPage.FFormClass := NewClass;
  FPage.SourceEdit(Src, Old, True);
  if IDE <> nil then IDE.FormRenamed(FPage, OldName, NewName, OldClass, NewClass);
end;

{ a frame of the project: its chain of form files ends at TFrame }
function TPageBridge.FrameDfms(const AClassName: string; Dfms: TStrings): Boolean;
begin
  Result := (IDE <> nil) and SameText(IDE.FormBase(FPage, AClassName, Dfms), 'TFrame');
end;

function TPageBridge.MethodExists(const AName: string): Boolean;
begin
  Result := FSMethodExists(FPage.GetSource, FPage.FFormClass, AName);
end;

procedure TPageBridge.GetCompatibleMethods(TypeData: PTypeData; Proc: TGetStrProc);
var
  Names, Sigs: TStringList;
  Params, ResType, Want: string;
  I: Integer;
begin
  Names := TStringList.Create;
  Sigs := TStringList.Create;
  try
    Params := MethodParamsFromTypeData(TypeData, ResType);
    Want := FSNormalizeSignature(TypeData^.MethodKind = mkFunction, Params, ResType);
    FSGetMethods(FPage.GetSource, FPage.FFormClass, Names, Sigs);
    for I := 0 to Names.Count - 1 do
      if (I < Sigs.Count) and SameText(Sigs[I], Want) then Proc(Names[I]);
  finally
    Names.Free;
    Sigs.Free;
  end;
end;

function TPageBridge.CreateMethod(const AName: string; TypeData: PTypeData): Boolean;
var
  Src, Old, Params, ResType: string;
  L, C: Integer;
begin
  Src := FPage.GetSource;
  Old := Src;
  Params := MethodParamsFromTypeData(TypeData, ResType);
  Result := FSAddMethod(Src, FPage.FFormClass, AName, Params, ResType, L, C);
  if Result then FPage.SourceEdit(Src, Old, True);
end;

{ the first statement of the new handler MethodName: the call of the placed frame's handler with
  the same parameters - Frame21.Button1Click(Sender); -, a line of its own at the body's indent }
procedure TPageBridge.ChainCall(const MethodName, InstancePath, InstanceMethod: string; TypeData: PTypeData);
var
  Src, Old, ResType, Call, EOL: string;
  Names: TStringList;
  L, C, I, P, Line: Integer;
begin
  Src := FPage.GetSource;
  Old := Src;
  if not FSFindMethodBody(Src, FPage.FFormClass, MethodName, L, C) then Exit;
  Names := TStringList.Create;
  try
    MethodParamsFromTypeData(TypeData, ResType, Names);
    Call := InstancePath + '.' + InstanceMethod;
    if Names.Count > 0 then
    begin
      Call := Call + '(';
      for I := 0 to Names.Count - 1 do
      begin
        if I > 0 then Call := Call + ', ';
        Call := Call + Names[I];
      end;
      Call := Call + ')';
    end;
  finally
    Names.Free;
  end;
  if ResType <> '' then Call := 'Result := ' + Call;
  if Pos(#13#10, Src) > 0 then EOL := #13#10 else EOL := #10;
  { the start of the body's line L }
  P := 1;
  Line := 1;
  while (Line < L) and (P <= Length(Src)) do
  begin
    if Src[P] = #10 then Inc(Line);
    Inc(P);
  end;
  if Line <> L then Exit;
  Insert(StringOfChar(' ', C - 1) + Call + ';' + EOL, Src, P);
  FPage.SourceEdit(Src, Old, True);
end;

procedure TPageBridge.RenameMethod(const OldName, NewName: string);
var
  Src, Old: string;
begin
  Src := FPage.GetSource;
  Old := Src;
  if FSRenameMethod(Src, FPage.FFormClass, OldName, NewName) then FPage.SourceEdit(Src, Old, True);
end;

procedure TPageBridge.ShowMethod(const AName: string);
var
  L, C: Integer;
begin
  if FSFindMethodBody(FPage.GetSource, FPage.FFormClass, AName, L, C) then
  begin
    FPage.ShowDesign(False);
    { like Delphi: in an empty body the caret waits at the statement indentation }
    FPage.FEditor.GotoLineColVirtual(L - 1, C - 1);
    if FPage.FEditor.CanFocus then FPage.FEditor.SetFocus;
  end;
end;

{ IDesigner.Activate. Borland's design windows (action list editor, menu designer ...) call it
  every time they become the active window: "my form is the current one". The form's page and
  its design view come up - but never the keyboard focus. Taking it deactivates the window that
  called: it lost the focus with every click and could not be closed, because the click on its
  close button activates it first. }
procedure TPageBridge.ActivateDesigner;
begin
  if IDE <> nil then IDE.ShowPage(FPage);
  if not FPage.DesignView then FPage.ShowDesign(True, False);
end;

{ ---------------------------------------------------------------- TPageHistoryHost }

function TPageHistoryHost.FileName(Form: Boolean): string;
begin
  if Form then Result := FPage.FormFileName else Result := FPage.FFileName;
end;

function TPageHistoryHost.HasForm: Boolean;
begin
  Result := FPage.FHasForm;
end;

function TPageHistoryHost.CurrentText(Form: Boolean): string;
begin
  if not Form then Result := FPage.GetSource
  else if FPage.FFormTextPage <> nil then Result := FPage.FFormTextPage.GetSource
  else Result := FPage.CurrentDfm;
end;

function TPageHistoryHost.CurrentBytes(Form: Boolean): string;
begin
  if Form then Result := FPage.FormBytesOf(CurrentText(True)) else Result := FPage.FEditor.FileBytes;
end;

function TPageHistoryHost.TextEncoding(Form: Boolean): TSdEncoding;
begin
  if Form then Result := IdeEncoding else Result := FPage.Encoding;
end;

function TPageHistoryHost.Modified(Form: Boolean): Boolean;
begin
  if Form then Result := FPage.FormChanged else Result := FPage.SourceModified;
end;

{ a form shown as text is changed in its page, not here }
function TPageHistoryHost.CanEdit(Form: Boolean): Boolean;
begin
  if Form then Result := FPage.FHasForm and (FPage.FFormTextPage = nil)
  else Result := not FPage.FEditor.ReadOnly;
end;

procedure TPageHistoryHost.Restore(Form: Boolean; const Text: string);
begin
  if Form then FPage.TakeChangedForm(Text) else FPage.SetSourceUndoable(Text);
  if IDE <> nil then IDE.PageChanged(FPage);
end;

procedure TPageHistoryHost.GotoLine(Line: Integer);
begin
  FPage.ShowDesign(False);
  FPage.GotoLine(Line + 1, 1);
  if FPage.FEditor.CanFocus then FPage.FEditor.SetFocus;
end;

{ ---------------------------------------------------------------- TEditorPage }

constructor TEditorPage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FBridge := TPageBridge.Create;
  FBridge.FPage := Self;
  FUndo := TDesignUndo.Create;
  FRootExtra := TStringList.Create;
  FAutoDismissed := -1;
  FIdentAt := -1;
  FNamesVersion := -1;
  FErrorsVersion := -1;
  FViewTabs := TSdTabStrip.Create(Self);
  FViewTabs.Parent := Self;
  FViewTabs.Align := alBottom;
  FViewTabs.Tabs.Add(CodeTab);
  FViewTabs.TabIndex := 0;
  FViewTabs.OnChange := ViewTabsChange;
  FViewTabs.Visible := False;
  FViewTabs.TabOrder := 0;            // before the design panel, as when both were made here
  FEditor := TSciEdit.Create(Self);
  { the views in one frame under the page bar; the design panel of the .dfm goes into it }
  FViewFrame := TViewFrame.Create(Self);
  FViewFrame.Parent := Self;
  FViewFrame.Align := alClient;
  FPageBar := TSdPageBar.Create(Self);
  FPageBar.Visible := False;
  FPageBar.Parent := FViewFrame;
  FPageBar.Align := alTop;
  DesignPanel.Parent := FViewFrame;
  FCodeArea := TCodeArea.Create(Self);
  FCodeArea.Parent := FViewFrame;
  FCodeArea.Align := alClient;
  FSlot := TSciSlot.Create(Self);
  FSlot.Parent := FCodeArea;
  FSlot.Align := alClient;
  FSlot.Edit := FEditor;
  FEditor.OnCharAdded := EditorCharAdded;
  FEditor.OnUpdateUI := EditorUpdateUI;
  FEditor.OnViewApplied := EditorViewApplied;
  FEditor.OnModified := EditorModified;
  FEditor.OnSavePointChange := EditorSavePoint;
  FEditor.OnKeyDown := EditorKeyDown;
  FEditor.OnKeyPress := EditorKeyPress;
  FEditor.OnMarginClick := EditorMarginClick;
  FEditor.OnCommand := EditorCommand;
  FEditor.OnCtrlClick := EditorCtrlClick;
  FEditor.OnDwellStart := EditorDwellStart;
  FEditor.OnDwellEnd := EditorDwellEnd;
  FEditor.OnFocusChange := EditorFocusChange;
  FEditor.OnMouseUp := EditorMouseUp;
  FEditor.OnZoom := EditorZoom;
end;

destructor TEditorPage.Destroy;
begin
  DetachFormText;
  CloseCodePopups;
  { the field is nil before the designer goes: what it notifies while it is freed must not
    reach it through the page (as in DropDesigner) }
  FreeAndNil(FDesigner);
  FBridge.Free;
  FUndo.Free;
  FRootExtra.Free;
  FPlacedUnits.Free;
  { the History tab goes with the page's components (inherited): it asks its host nothing then }
  FreeAndNil(FHistory);
  FHistoryHost.Free;
  inherited;
end;

{ The page paints around its children (the editor or the design view and the Code/Design
  tabs), never over them, and a resize repaints only what it uncovers: without that, every
  change of the page's size erased the page over the form being designed (flicker). }
{ the .dfm's root name is not taken while it is read: a page per open file, all owned by the main
  form, would clash (the reader makes the name unique among the global forms only) }
procedure TEditorPage.SetName(const NewName: TComponentName);
begin
  if csReading in ComponentState then inherited SetName('') else inherited SetName(NewName);
end;

procedure TEditorPage.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

{ the window that shows the editor lies over the slot of the page shown: it follows the page }
procedure TEditorPage.CMVisibleChanged(var Message: TMessage);
begin
  inherited;
  if FSlot <> nil then FSlot.Changed;
end;

procedure TEditorPage.WMWindowPosChanged(var Message: TWMWindowPosChanged);
begin
  inherited;
  if (FSlot <> nil) and (Message.WindowPos^.flags and SWP_NOMOVE = 0) then FSlot.Changed;
end;

function TEditorPage.IsPascal: Boolean;
begin
  Result := FEditor.Language = slPascal;
end;

function TEditorPage.UnitName: string;
begin
  Result := ChangeFileExt(ExtractFileName(FFileName), '');
end;

{ the caption of the file's tab: a unit or program by its name, any other file by its file name }
function TEditorPage.TabCaption: string;
begin
  if IsUnitFile then Result := UnitName else Result := ExtractFileName(FFileName);
  if Modified then Result := Result + ModifiedMark;
end;

{ ... with the real file name, also outside the code page (SdFileNames) }
function TEditorPage.TabCaptionW: WideString;
begin
  if IsUnitFile then Result := UnitName else Result := WideFileName(DisplayPath(FFileName));
  if Modified then Result := Result + ModifiedMark;
end;

function TEditorPage.IsUnitFile: Boolean;
begin
  Result := SameText(ExtractFileExt(FFileName), '.pas') or IsProjectFile(FFileName);
end;

function TEditorPage.FormFileName: string;
begin
  Result := ChangeFileExt(FFileName, '.dfm');
end;

procedure TEditorPage.FormMessage(const Text: string);
begin
  if IDE <> nil then IDE.ShowMessage(ExtractFileName(FormFileName) + ': ' + Text);
end;

function TEditorPage.GetSource: string;
begin
  Result := FEditor.GetText;
end;

{ Replaces only the changed middle part so that markers, folds and the caret survive: at Pos
  (0-based) Removed makes way for Inserted; OldText is the source before. False: no change. }
function TEditorPage.ReplaceSource(const NewSource: string; var Pos: Integer;
  var OldText, Removed, Inserted: string): Boolean;
var
  S, OL, NL: Integer;
begin
  OldText := FEditor.GetText;
  Result := OldText <> NewSource;
  if not Result then Exit;
  OL := Length(OldText);
  NL := Length(NewSource);
  Pos := 0;
  while (Pos < OL) and (Pos < NL) and (OldText[Pos + 1] = NewSource[Pos + 1]) do Inc(Pos);
  S := 0;
  while (S < OL - Pos) and (S < NL - Pos) and (OldText[OL - S] = NewSource[NL - S]) do Inc(S);
  Removed := Copy(OldText, Pos + 1, OL - Pos - S);
  Inserted := Copy(NewSource, Pos + 1, NL - Pos - S);
  FEditor.Sci(SCI_SETTARGETSTART, Pos);
  FEditor.Sci(SCI_SETTARGETEND, OL - S);
  FEditor.SciS(SCI_REPLACETARGET, Length(Inserted), Inserted);
end;

procedure TEditorPage.SetSource(const NewSource: string);
var
  P: Integer;
  OldText, Removed, Inserted: string;
begin
  ReplaceSource(NewSource, P, OldText, Removed, Inserted);
end;

procedure TEditorPage.SetSourceUndoable(const NewSource: string);
begin
  FEditor.BeginUndo;
  try
    SetSource(NewSource);
  finally
    FEditor.EndUndo;
  end;
end;

function TEditorPage.SourceEdit(var Src: string; const Old: string; ForDesigner: Boolean): Boolean;
var
  P: Integer;
  OldText, Removed, Inserted: string;
begin
  Result := Src <> Old;
  if not Result then Exit;
  FEditor.BeginUndo;
  try
    Result := ReplaceSource(Src, P, OldText, Removed, Inserted);
  finally
    FEditor.EndUndo;
  end;
  if Result and ForDesigner and not FUndoBusy then
  begin
    FUndo.SourceEdited(OldText, P, Removed, Inserted);
    PostDesignStep;
  end;
end;

{ ---------------------------------------------------------------- the designer's undo and redo }

{ an inherited form: the .dfm texts of its ancestors into Anc (False: one is not found) - of a
  frame or a data module as its design form reads them }
function TEditorPage.LoadAncestors(const Dfm: string; Anc: TStrings): Boolean;
begin
  Result := True;
  if IsInheritedDfm(Dfm) then Result := ReadAncestors(Anc);
end;

{ the forms of the form's ancestors as they are now (their open pages' with what is not saved),
  as the design form reads them }
function TEditorPage.ReadAncestors(Anc: TStrings): Boolean;
var
  I: Integer;
begin
  Result := (IDE <> nil) and IDE.AncestorDfms(Self, FSGetAncestorName(GetSource, FFormClass), Anc);
  if Result then
    for I := 0 to Anc.Count - 1 do Anc[I] := DfmToHost(Anc[I], False);
end;

{ the designer reads its form again from Text (its own form text) with the form files of its
  frames and ancestors as they are now: what they changed comes in, the form's own changes and
  the selection stay. Before: the form's text until now - when the form's text differs after it
  (a change of the form's that the frame now has itself, a rename taken over), that is a change
  of the form: modified, one undo step; else the form is as modified as it was }
procedure TEditorPage.ReadFormAgain(const Before, Text: string);
var
  Anc, Errs: TStringList;
  WasModified: Boolean;
  I: Integer;
begin
  if FDesigner = nil then Exit;
  Anc := TStringList.Create;
  Errs := TStringList.Create;
  try
    if not LoadAncestors(Text, Anc) then Exit;
    WasModified := FDesigner.IsModified;
    FUndoBusy := True;
    try
      try
        FDesigner.Reload(Text, Anc, FDesigner.SelectionNames, Errs);
      except
        { a frame's or an ancestor's form that cannot be read (being edited as text): the form
          stays as it was (Reload keeps it), Messages says why - not a box at every showing }
        on E: Exception do
        begin
          FormMessage(E.Message);
          Exit;
        end;
      end;
    finally
      FUndoBusy := False;
    end;
    if FDesigner.SaveToText <> Before then
    begin
      FFormModified := True;
      FUndo.Changed;
      CommitDesignStep;
      if IDE <> nil then IDE.PageChanged(Self);
    end
    else
      FDesigner.IsModified := WasModified;
    { what the reader skipped - a component the frame or the ancestor no longer has: in Messages }
    for I := 0 to Errs.Count - 1 do FormMessage(Errs[I]);
  finally
    Errs.Free;
    Anc.Free;
  end;
end;

procedure TEditorPage.FollowAncestors;
var
  Anc: TStringList;
  Changed: Boolean;
  Text: string;
begin
  if (FDesigner = nil) or FUndoBusy or (FDesigner.Root = nil) then Exit;
  Changed := FDesigner.FramesChanged;
  if not Changed and (FDesigner.AncestorTexts.Count > 0) then
  begin
    Anc := TStringList.Create;
    try
      Changed := ReadAncestors(Anc) and (Anc.Text <> FDesigner.AncestorTexts.Text);
    finally
      Anc.Free;
    end;
  end;
  if not Changed then Exit;
  CommitDesignStep;             // a change still under way is a step of its own
  Text := FDesigner.SaveToText;
  ReadFormAgain(Text, Text);
end;

procedure TEditorPage.TakeChangedForm(const NewText: string);
begin
  if FDesigner <> nil then
  begin
    CommitDesignStep;
    ReadFormAgain(FDesigner.SaveToText, DfmToHost(NewText));
  end
  else
  begin
    FDfmText := NewText;
    FFormModified := True;
    if IDE <> nil then IDE.PageChanged(Self);
  end;
end;

{ the designer changed something: a step begins; it ends when the messages of the change are
  done (CM_SD_DESIGNSTEP) - the changes of one command are one step }
procedure TEditorPage.DesignChanged;
begin
  if FUndoBusy or (FDesigner = nil) then Exit;
  FUndo.Changed;
  PostDesignStep;
end;

procedure TEditorPage.DesignSelectionChanged;
begin
  if not FUndoBusy and (FDesigner <> nil) then FUndo.SelectionChanged(FDesigner.SelectionNames);
end;

procedure TEditorPage.PostDesignStep;
begin
  if FStepPosted or not HandleAllocated then Exit;
  FStepPosted := True;
  PostMessage(Handle, CM_SD_DESIGNSTEP, 0, 0);
end;

procedure TEditorPage.CMDesignStep(var Message: TMessage);
begin
  FStepPosted := False;
  CommitDesignStep;
end;

procedure TEditorPage.CommitDesignStep;
begin
  if (FDesigner <> nil) and FUndo.Pending then FUndo.Commit(FDesigner.SaveToText, FDesigner.SelectionNames);
end;

function TEditorPage.CanDesignUndo: Boolean;
begin
  Result := (FDesigner <> nil) and FUndo.CanUndo;
end;

function TEditorPage.CanDesignRedo: Boolean;
begin
  Result := (FDesigner <> nil) and FUndo.CanRedo;
end;

procedure TEditorPage.DesignUndo;
begin
  TakeDesignStep(True);
end;

procedure TEditorPage.DesignRedo;
begin
  TakeDesignStep(False);
end;

function TEditorPage.DesignUndoState: string;
begin
  Result := Format('%d/%d', [FUndo.UndoCount, FUndo.RedoCount]);
end;

{ Back: the latest step taken back - its source edits first (an event's method is there again
  before the form names it), then the form as it was; else the step taken back last made again }
procedure TEditorPage.TakeDesignStep(Back: Boolean);
var
  Step: TDesignStep;
  Src, What: string;
  Anc, Errs: TStringList;
  I: Integer;
begin
  if FDesigner = nil then Exit;
  CommitDesignStep;             // a change still under way is a step of its own
  if Back then Step := FUndo.NextUndo else Step := FUndo.NextRedo;
  if Step = nil then Exit;
  Src := GetSource;
  Errs := nil;
  Anc := TStringList.Create;
  try
    Errs := TStringList.Create;
    if not ApplyStep(Src, Step, Back) then
    begin
      if Back then What := 'undone' else What := 'redone';
      MessageBox(GetParentForm(Self).Handle, PChar('The unit was edited where the designer changed it: the ' +
        'change of the form cannot be ' + What + '.'), 'D7 Studio', MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    if Back then LoadAncestors(Step.FormBefore, Anc) else LoadAncestors(Step.FormAfter, Anc);
    FUndoBusy := True;
    try
      SetSourceUndoable(Src);
      if Back then
      begin
        FDesigner.Reload(Step.FormBefore, Anc, Step.SelBefore, Errs);
        FUndo.Undone;
      end
      else
      begin
        FDesigner.Reload(Step.FormAfter, Anc, Step.SelAfter, Errs);
        FUndo.Redone;
      end;
    finally
      FUndoBusy := False;
    end;
    { what the reader skipped while reading the step's form back: in Messages (and error.log) }
    for I := 0 to Errs.Count - 1 do FormMessage(Errs[I]);
  finally
    Errs.Free;
    Anc.Free;
  end;
  FFormModified := True;
  if IDE <> nil then IDE.PageChanged(Self);
end;

procedure TEditorPage.LoadFromFile(const AFileName: string);
var
  Dfm, N, C: string;
  E: TSdEncoding;
begin
  FFileName := ExpandPathU(AFileName);
  FUntitled := False;
  FFileSystem := '';
  FEditor.SetLanguageFromFile(FFileName);
  { an encoding the user chose for this file wins over the detection }
  if ChosenEncoding(E) then
    FEditor.LoadFromFileAs(FFileName, E)
  else
    FEditor.LoadFromFile(FFileName);
  FEncodingChanged := False;      // a conversion not saved is gone with the text
  FMarked := False;               // ... and an expert's mark (MarkModified)
  FFileStamp := FileStampU(FFileName);
  FHasForm := False;
  FDfmText := '';
  FDfmBinary := False;
  FFormClass := '';
  if SameText(ExtractFileExt(FFileName), '.pas') then
  begin
    Dfm := FormFileName;
    if FileExistsU(Dfm) then
      try
        FDfmText := ReadFileU(Dfm);
        FDfmBinary := DfmIsBinary(FDfmText);
        { a text form of Delphi 7 holds the characters of the system code page as their bytes:
          the form's text is D7 Studio's (UTF-8), as programs read such forms (DfmCodePage) }
        FDfmText := FormTextOfBytes(FDfmText);
        if DfmObjectHeader(FDfmText, N, C) then
        begin
          FHasForm := True;
          FFormClass := C;
        end;
      except
        FHasForm := False;
      end;
  end;
  CheckHistoryDisk;
  FKeptVersion := FTextVersion;
  UpdateViewTabs;
  FFormModified := False;
  if FDiagramView then ShowDiagram(CanDiagram, False);    // the file was read again
  if FHistoryView then
    if CanHistory then FHistory.HistoryChanged else ShowDesign(False, False);
end;

{ a form file is text in the editor: a file system of files gives it as it is on the disk,
  binary perhaps (Delphi 7 converts only for such a file system) }
function IsFormFileName(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.dfm') or (Ext = '.xfm') or (Ext = '.nfm');
end;

{ the text of a version (SdHistory.HistoryTextOf): a form file's as the page reads it; any other
  file's bytes are decoded }
function HistoryText(const FileName, Bytes: string; out Text: string): Boolean;
begin
  Result := IsFormFileName(FileName);
  if Result then Text := FormTextOfBytes(Bytes);
end;

procedure TEditorPage.LoadFromFileSystem(const AFileName, AFileSystem: string);
var
  FS: TSdPageFileSystem;
  Bytes, Text: string;
  Age: Integer;
  Binary, RO: Boolean;
  E: TSdEncoding;
begin
  FS := NeedPageFileSystem(AFileSystem);
  try
    FS.Read(AFileName, Bytes, Age);
    Binary := FS.IsFileBased and IsFormFileName(AFileName) and DfmIsBinary(Bytes);
    RO := FS.IsReadOnly(AFileName);
  finally
    FS.Free;
  end;
  if Binary then Bytes := DfmBinaryToText(Bytes);
  E := SystemEncoding;
  Text := DecodeFile(Bytes, E, True);
  TakeText(AFileName, AFileSystem, Text, E, RO, Age, Binary);
end;

{ the page of a file - of a file system, or of the disk (AFileSystem '') -: Text (IDE text, E the
  file's encoding) as the file's, not modified }
procedure TEditorPage.TakeText(const AFileName, AFileSystem, Text: string; E: TSdEncoding;
  RO: Boolean; Age: Integer; Binary: Boolean);
begin
  FFileName := AFileName;
  FUntitled := False;
  FFileSystem := AFileSystem;
  FFsAge := Age;
  FFsBinary := Binary;
  FEditor.SetLanguageFromFile(FFileName);
  FEditor.LoadFromStringAs(Text, E);
  FEditor.ReadOnly := RO;
  FEncodingChanged := False;
  FMarked := False;
  FHasForm := False;
  FDfmText := '';
  FDfmBinary := False;
  FFormClass := '';
  UpdateViewTabs;
  FFormModified := False;
  if FDiagramView then ShowDiagram(CanDiagram, False);
  if FHistoryView and not CanHistory then ShowDesign(False, False);
end;

{ an existing file shown with a text that is not read from it - a creator's of an existing file
  (Delphi 7's, measured: the creator's text, else an empty one), not modified. A disk file is
  opened as it is (its encoding, its form) and its text replaced; a file system's file is not
  read: its IsReadonly is asked }
procedure TEditorPage.LoadWithText(const AFileName, AFileSystem, Text: string);
var
  FS: TSdPageFileSystem;
  RO: Boolean;
begin
  if AFileSystem <> '' then
  begin
    FS := NeedPageFileSystem(AFileSystem);
    try
      RO := FS.IsReadOnly(AFileName);
    finally
      FS.Free;
    end;
    TakeText(AFileName, AFileSystem, Text, SystemEncoding, RO, 0, False);
  end
  else if FileExistsU(AFileName) then
  begin
    LoadFromFile(AFileName);
    FEditor.LoadFromStringAs(Text, FEditor.Encoding);
  end
  else
  begin
    { a file that is not there yet (a type library's unit): written when it is saved }
    TakeText(ExpandPathU(AFileName), '', Text, SystemEncoding, False, 0, False);
    FFileStamp := FileStampU(FFileName);
  end;
end;

{ the text written through the page's file system (TSdPageFileSystem.Write: Delphi's order of
  calls), a form file that was binary binary again; its age there remembered }
procedure TEditorPage.SaveToFileSystem;
var
  FS: TSdPageFileSystem;
  Bytes: string;
begin
  Bytes := FEditor.FileBytes;
  if FFsBinary then Bytes := DfmTextToBinary(Bytes);
  FS := NeedPageFileSystem(FFileSystem);
  try
    FS.Write(FFileName, Bytes, EditorOptions.CreateBackup);
    FFsAge := FS.FileAge(FFileName);
  finally
    FS.Free;
  end;
  FEditor.SetSavePoint;
end;

procedure TEditorPage.SetFileSystem(const Value: string);
var
  FS: TSdPageFileSystem;
begin
  if Value = FFileSystem then Exit;
  FFsBinary := False;
  FFsAge := 0;
  if Value <> '' then
  begin
    FS := NeedPageFileSystem(Value);
    try
      if FS.FileExists(FFileName) then FFsAge := FS.FileAge(FFileName);
    finally
      FS.Free;
    end;
  end;
  FFileSystem := Value;
end;

procedure TEditorPage.Reload;
var
  D: TFormDesigner;
  Design: Boolean;
begin
  if FUntitled then Exit;
  { the changes the reload lets go are kept as a version }
  if Modified then KeepVersion(hkReloaded);
  Design := FDesignView;
  if FDesigner <> nil then
  begin
    { the field is nil before the view changes: the page change ShowDesign reports must not
      hand the old designer out again (as in DropDesigner) }
    D := FDesigner;
    FDesigner := nil;
    if Design then ShowDesign(False, False);
    D.Free;
    FUndo.Clear;
  end;
  FDesignFailed := False;
  if FFileSystem <> '' then LoadFromFileSystem(FFileName, FFileSystem) else LoadFromFile(FFileName);
  if Design and FHasForm then ShowDesign(True, False);
  if IDE <> nil then IDE.PageChanged(Self);
end;

function TEditorPage.Encoding: TSdEncoding;
begin
  Result := FEditor.Encoding;
end;

procedure EncodingWritten(const FileName, Bytes: string; const E: TSdEncoding);
var
  Old: TSdEncoding;
begin
  if RememberedEncoding(FileName, Old) then
  begin
    if not SameEncoding(Old, E) then RememberFileEncoding(FileName, E);
  end
  else if not SameEncoding(DetectEncoding(Bytes), E) then
    RememberFileEncoding(FileName, E);
end;

function ReadSourceFile(const FileName: string; out E: TSdEncoding): string;
var
  Bytes: string;
begin
  Bytes := ReadFileU(FileName);
  E := FileEncoding(FileName, Bytes);
  Result := DecodeFile(Bytes, E, False);
end;

function ReadSourceFileAs(const FileName: string; const E: TSdEncoding): string;
var
  FE: TSdEncoding;
  Res: string;
  Lost: Boolean;
begin
  Result := ReadSourceFile(FileName, FE);
  if ConvertText(Result, FE, E, Res, Lost) then Result := Res;
end;

function WriteSourceFile(const FileName, Text: string; const E: TSdEncoding): string;
var
  Lost: Boolean;
begin
  Result := EncodeFile(Text, E, Lost);
  WriteFileU(FileName, Result);
  EncodingWritten(FileName, Result, E);
end;

procedure RewriteSourceFile(const FileName, Text: string; const E: TSdEncoding; const Writer: string);
begin
  HistoryBeforeWrite(FileName, E);
  HistoryWritten(FileName, WriteSourceFile(FileName, Text, E), E, hkWritten, Writer);
end;

function FormTextOfBytes(const Bytes: string): string;
begin
  if DfmIsBinary(Bytes) then Result := DfmBinaryToText(Bytes) else Result := SystemFileToIde(Bytes);
end;

{ the encoding the user chose for this file (False: none, the file's bytes tell) }
function TEditorPage.ChosenEncoding(var E: TSdEncoding): Boolean;
begin
  Result := not FUntitled and RememberedEncoding(FFileName, E);
end;

{ the encoding the user chose for this file is used the next time it is opened }
procedure TEditorPage.RememberEncoding(const AEncoding: TSdEncoding);
begin
  if not FUntitled and (FFileSystem = '') then RememberFileEncoding(FFileName, AEncoding);
end;

procedure TEditorPage.ReopenWithEncoding(const AEncoding: TSdEncoding);
begin
  if FUntitled or (FFileSystem <> '') then Exit;
  FEditor.LoadFromFileAs(FFileName, AEncoding);     // a read that fails changes nothing
  RememberEncoding(AEncoding);       // the bytes on the disk are read in it from now on
  FEncodingChanged := False;
  FMarked := False;                  // read again: an expert's mark went with the text
  FFileStamp := FileStampU(FFileName);
  if IDE <> nil then IDE.PageChanged(Self);
end;

{ False when Windows cannot convert into that code page: text and encoding stay as they are.
  The file on the disk is still in the old encoding: Save remembers the new one when it has
  written it (FEncodingChanged) }
function TEditorPage.ConvertToEncoding(const AEncoding: TSdEncoding): Boolean;
begin
  Result := FEditor.ConvertTo(AEncoding);
  if not Result then Exit;
  FEncodingChanged := True;
  if IDE <> nil then IDE.PageChanged(Self);
end;

procedure TEditorPage.NewFile(const AFileName, Source, DfmText: string; Named: Boolean);
var
  N, C: string;
begin
  FFileName := AFileName;
  FUntitled := not Named;
  if Named then
  begin
    { a file of that name stays as it is until the page is saved }
    FFileStamp := FileStampU(FFileName);
    FMarked := True;
  end;
  FEditor.SetLanguageFromFile(FFileName);
  FEditor.LoadFromString(Source);
  FDfmText := DfmText;
  FHasForm := (DfmText <> '') and DfmObjectHeader(DfmText, N, C);
  if FHasForm then FFormClass := C;
  UpdateViewTabs;
  FFormNew := FHasForm;
end;

function TEditorPage.GetDfmText: Boolean;
begin
  Result := not FDfmBinary;
end;

procedure TEditorPage.SetDfmText(Value: Boolean);
begin
  if Value <> FDfmBinary then Exit;
  FDfmBinary := not Value;
  if FHasForm then FFormModified := True;
end;

function TEditorPage.Modified: Boolean;
begin
  Result := SourceModified or FFormModified;
end;

function TEditorPage.SourceModified: Boolean;
begin
  Result := FEditor.Modified or FEncodingChanged or FUntitled or FMarked;
end;

procedure TEditorPage.MarkModified;
begin
  FMarked := True;
  if IDE <> nil then IDE.PageChanged(Self);
end;

{ ---------------------------------------------------------------- data modules and frames

  The designer works on a form. A data module or a frame is therefore hosted in the design form:
  on the way in, the root properties of the .dfm that a form does not have are set aside
  (FRootExtra); on the way out, the properties that only the host form has are dropped again.
  A custom module's own properties go to its designer, which holds them in an instance of its
  class and writes the root's properties as Delphi does (TFormDesigner.Module). }

function IsInheritedDfm(const Dfm: string): Boolean;
begin
  Result := SameText(Copy(TrimLeft(Dfm), 1, 10), 'inherited ');
end;

function DfmValue(const Entry: string): string;
var
  P: Integer;
begin
  P := Pos('=', Entry);
  Result := Trim(Copy(Entry, P + 1, MaxInt));
end;

procedure TEditorPage.DetectRootKind;
var
  Anc, Base: string;
  Cls: TComponentClass;
  Chain: TStringList;
begin
  FRootKind := hkForm;
  FRootModule := nil;
  if not FHasForm or (FFormClass = '') then Exit;
  Anc := FSGetAncestorName(GetSource, FFormClass);
  { an inherited form or frame: the kind of the class its project ancestors derive from }
  if not SameText(Anc, 'TForm') and not SameText(Anc, 'TFrame') and not SameText(Anc, 'TDataModule') and
    (IDE <> nil) then
  begin
    Chain := TStringList.Create;
    try
      Base := IDE.FormBase(Self, Anc, Chain);
    finally
      Chain.Free;
    end;
    if Base <> '' then Anc := Base;
  end;
  if SameText(Anc, 'TDataModule') then FRootKind := hkDataModule
  else if SameText(Anc, 'TFrame') then FRootKind := hkFrame
  else if DesignHost <> nil then
  begin
    { a custom module of a package (RegisterCustomModule: TService ...) that is a data module is
      designed as one; its own properties are its designer's, in an instance of its class
      (TFormDesigner.Module) }
    Cls := DesignHost.CustomModuleClass(Anc);
    if (Cls <> nil) and Cls.InheritsFrom(TDataModule) then
    begin
      FRootKind := hkDataModule;
      FRootModule := Cls;
    end;
  end;
end;

{ a frame's or data module's form text as its design form reads it - Own: the page's own (what the
  design form cannot hold is kept for DfmFromHost); else an ancestor's, whose such properties go:
  the ancestor alone is read the same way, so the differences written stay right }
function TEditorPage.DfmToHost(const Dfm: string; Own: Boolean): string;
var
  Header, Rest, N, C: string;
  Names, Texts: TStringList;
  I: Integer;
  HasParentFont: Boolean;
begin
  Result := Dfm;
  if Own then
  begin
    FRootExtra.Clear;
    FHadColor := False;
  end;
  if FRootKind = hkForm then Exit;
  Names := TStringList.Create;
  Texts := TStringList.Create;
  try
    SplitDfmRoot(Dfm, Header, Names, Texts, Rest);
    DfmObjectHeader(Dfm, N, C);
    Result := Header + #13#10;
    HasParentFont := False;
    for I := 0 to Names.Count - 1 do
    begin
      if SameText(Names[I], 'Color') and Own then FHadColor := True;
      if SameText(Names[I], 'ParentFont') or (Pos('font.', LowerCase(Names[I])) = 1) then HasParentFont := True;
      if (FRootKind = hkFrame) and SameText(Names[I], 'Width') then
        Result := Result + '  ClientWidth = ' + DfmValue(Texts[I]) + #13#10
      else if (FRootKind = hkFrame) and SameText(Names[I], 'Height') then
        Result := Result + '  ClientHeight = ' + DfmValue(Texts[I]) + #13#10
      { a custom module's own properties too: its designer takes them into its instance }
      else if HostRootProp(FRootKind, Names[I]) or (FRootModule <> nil) then
        Result := Result + Texts[I] + #13#10
      else if Own then
        FRootExtra.Add(Texts[I]);
    end;
    { the look of the host: the guest's name as caption; a data module is a white sheet;
      a frame takes its font from its parent unless the file says otherwise }
    Result := Result + '  Caption = ' + QuotedStr(N) + #13#10;
    if FRootKind = hkDataModule then Result := Result + '  Color = clWindow'#13#10;
    if (FRootKind = hkFrame) and not HasParentFont then Result := Result + '  ParentFont = True'#13#10;
    Result := Result + Rest + #13#10;
  finally
    Names.Free;
    Texts.Free;
  end;
end;

function TEditorPage.DfmFromHost(const Dfm: string): string;
var
  Header, Rest, V: string;
  Names, Texts: TStringList;
  I: Integer;
begin
  Result := Dfm;
  if (FRootKind = hkForm) or (FDesigner = nil) then Exit;
  Names := TStringList.Create;
  Texts := TStringList.Create;
  try
    SplitDfmRoot(Dfm, Header, Names, Texts, Rest);
    { a custom module: the root's properties as Delphi writes a root of its class }
    if FDesigner.Module <> nil then
    begin
      Result := Header + #13#10 + FDesigner.ModuleRootText + Rest + #13#10;
      Exit;
    end;
    Result := Header + #13#10;
    for I := 0 to Names.Count - 1 do
    begin
      V := DfmValue(Texts[I]);
      if SameText(Names[I], 'Caption') then Continue;
      if FRootKind = hkDataModule then
      begin
        if SameText(Names[I], 'Color') then Continue;
      end
      else
      begin
        { the frame's size is the client area of its host; defaults of a frame are not stored }
        if SameText(Names[I], 'Width') or SameText(Names[I], 'Height') or
          SameText(Names[I], 'ClientWidth') or SameText(Names[I], 'ClientHeight') then Continue;
        if SameText(Names[I], 'ParentFont') and SameText(V, 'True') then Continue;
        if SameText(Names[I], 'Color') and SameText(V, 'clBtnFace') and not FHadColor then Continue;
      end;
      if HostRootProp(FRootKind, Names[I]) then Result := Result + Texts[I] + #13#10;
    end;
    if FRootKind = hkFrame then
      Result := Result + Format('  Width = %d'#13#10'  Height = %d'#13#10,
        [FDesigner.Form.ClientWidth, FDesigner.Form.ClientHeight]);
    for I := 0 to FRootExtra.Count - 1 do Result := Result + FRootExtra[I] + #13#10;
    Result := Result + Rest + #13#10;
  finally
    Names.Free;
    Texts.Free;
  end;
end;

procedure TEditorPage.RemoveEmptyHandlers;
var
  Src, Old: string;
  Removed: TStringList;
  All: TList;
  I, J, K, Count: Integer;
  Code: Pointer;
  C: TComponent;
  Props: PPropList;
  M: TMethod;
begin
  { Delphi behaviour: event handlers that were never filled in disappear on save }
  if (FDesigner = nil) or (FDesigner.Root = nil) or (FFormClass = '') then Exit;
  Src := GetSource;
  Old := Src;
  Removed := TStringList.Create;
  All := TList.Create;
  try
    if FSRemoveEmptyMethods(Src, FFormClass, Removed) = 0 then Exit;
    { the root, the instance of a custom module's class (the root's own events), the components -
      a placed frame's too: the form's handler of one of them goes with the others }
    if FDesigner.Module <> nil then All.Add(FDesigner.Module);
    All.Add(FDesigner.Root);
    FDesigner.GetDesignedComponents(All);
    for I := 0 to Removed.Count - 1 do
    begin
      Code := FDesigner.Root.MethodAddress(Removed[I]);
      if Code = nil then Continue;
      for J := 0 to All.Count - 1 do
      begin
        C := TComponent(All[J]);
        Count := GetPropList(C.ClassInfo, [tkMethod], nil);
        if Count = 0 then Continue;
        GetMem(Props, Count * SizeOf(PPropInfo));
        try
          GetPropList(C.ClassInfo, [tkMethod], Props);
          for K := 0 to Count - 1 do
          begin
            M := GetMethodProp(C, Props^[K]);
            if M.Code = Code then
            begin
              M.Code := nil;
              M.Data := nil;
              SetMethodProp(C, Props^[K], M);
            end;
          end;
        finally
          FreeMem(Props);
        end;
      end;
      DestroySubClassMethod(FDesigner.Root, Code);
    end;
    SourceEdit(Src, Old);
  finally
    All.Free;
    Removed.Free;
  end;
end;

{ --- View as Text / View as Form --- }

{ the form of Owner as its text in this page; Owner's designer goes afterwards (DropDesigner),
  when this page covers it }
procedure TEditorPage.ShowFormText(Owner: TEditorPage);
var
  Dfm: string;
begin
  Dfm := Owner.CurrentDfm;
  FFileName := Owner.FormFileName;
  FUntitled := False;
  FEditor.SetLanguageFromFile(FFileName);
  FEditor.SetText(Dfm);
  FEditor.Sci(SCI_EMPTYUNDOBUFFER);
  FEditor.Sci(SCI_SETSAVEPOINT);
  FFormOwner := Owner;
  Owner.FFormTextPage := Self;
  Owner.FDfmText := Dfm;
end;

{ the form is shown as text: the designer goes, the page shows its code }
procedure TEditorPage.DropDesigner;
var
  D: TFormDesigner;
begin
  if FDesigner = nil then Exit;
  if FDesigner.IsModified then FFormModified := True;
  { the designer leaves the page before the view changes: the page change that ShowDesign
    reports (IDE.PageChanged) would hand it to the Object Inspector and the Object TreeView
    again, and they would keep it after it is freed }
  D := FDesigner;
  FDesigner := nil;
  ShowDesign(False, False);
  D.Free;
  FUndo.Clear;
end;

procedure TEditorPage.TakeFormText;
begin
  if FFormTextPage = nil then Exit;
  FDfmText := FFormTextPage.GetSource;
  if FFormTextPage.FEditor.Modified then FFormModified := True;
end;

procedure TEditorPage.PlacedUnitNames(Units: TStrings);
var
  I: Integer;
  Root: TComponent;
begin
  if FPlacedUnits = nil then Exit;
  if FDesigner <> nil then Root := FDesigner.Root else Root := nil;
  for I := 0 to FPlacedUnits.Count - 1 do
    if (Root = nil) or (Root.FindComponent(FPlacedUnits.Names[I]) <> nil) then
      Units.Add(FPlacedUnits.ValueFromIndex[I]);
end;

procedure TEditorPage.AddPlacedUnits;
var
  Src, Old: string;
  I: Integer;
  Units: TStringList;
begin
  if (FPlacedUnits = nil) or (FPlacedUnits.Count = 0) then Exit;
  Units := TStringList.Create;
  try
    PlacedUnitNames(Units);
    Src := GetSource;
    Old := Src;
    for I := 0 to Units.Count - 1 do FSAddUses(Src, Units[I], True);
  finally
    Units.Free;
  end;
  FPlacedUnits.Clear;
  if Src <> Old then SourceEdit(Src, Old);
end;
function TEditorPage.ApplyFormText: Boolean;
var
  O: TEditorPage;
begin
  Result := True;
  O := FFormOwner;
  if O = nil then Exit;
  O.TakeFormText;
  DetachFormText;
  O.FDesignFailed := False;
  Result := O.EnsureDesigner;
  if not Result then
  begin
    FFormOwner := O;
    O.FFormTextPage := Self;
  end;
end;

procedure TEditorPage.DetachFormText;
begin
  if FFormOwner <> nil then FFormOwner.FFormTextPage := nil;
  FFormOwner := nil;
  if FFormTextPage <> nil then FFormTextPage.FFormOwner := nil;
  FFormTextPage := nil;
end;

function TEditorPage.CurrentDfm: string;
begin
  Result := '';
  if not FHasForm then Exit;
  if FDesigner <> nil then
  begin
    Result := FDesigner.SaveToText;
    if Result <> '' then Result := DfmFromHost(Result);
  end;
  if Result = '' then Result := FDfmText;
end;

function TEditorPage.Save: Boolean;
var
  Dfm, Bytes, FormBytes: string;
begin
  Result := False;
  if FFormOwner <> nil then
  begin
    { the form's text: its unit is saved, the form from this text }
    Result := FFormOwner.Save;
    Exit;
  end;
  if FUntitled then Exit;      // the caller runs Save As for untitled files
  AddPlacedUnits;
  { Formatter Options | Format on save: the unit (and the form's text when it is shown as text) }
  if FormatterOptions.FormatOnSave then
  begin
    if IsPascal then FormatSource(False);
    if FFormTextPage <> nil then FFormTextPage.FormatSource(False);
  end;
  TakeFormText;
  { the versions of the unit and its form one moment of the history }
  HistoryBeginMoment;
  try
    if FHasForm then
    begin
      RemoveEmptyHandlers;
      if (FDesigner <> nil) or FFormModified or FFormNew then
      begin
        Dfm := CurrentDfm;
        if Dfm <> '' then
        begin
          FDfmText := Dfm;
          { a binary .dfm stays binary (Delphi: Text DFM off, or New forms as text off); the form's
            versions: the disk's before, the text written }
          FormBytes := FormBytesOf(Dfm);
          HistoryBeforeWrite(FormFileName, IdeEncoding);
          WriteFileU(FormFileName, FormBytes);
          HistoryWritten(FormFileName, FormBytes, IdeEncoding, hkSaved);
        end;
      end;
      if FDesigner <> nil then FDesigner.IsModified := False;
    end;
    FEditor.PrepareSave;
    if FFileSystem <> '' then
      SaveToFileSystem
    else
    begin
      HistoryBeforeWrite(FFileName, Encoding);
      Bytes := FEditor.SaveToFile(FFileName);
      HistoryWritten(FFileName, Bytes, Encoding, hkSaved);
      FKeptVersion := FTextVersion;
    end;
    FEditor.SaveDone;
    if FFileSystem = '' then FFileStamp := FileStampU(FFileName);
    FFormModified := False;
    FFormNew := False;
    FMarked := False;
    if FFormTextPage <> nil then FFormTextPage.FEditor.Sci(SCI_SETSAVEPOINT);
    { the file is read in its encoding from now on (a converted one, UTF-8 text in ASCII) }
    if FFileSystem = '' then EncodingWritten(FFileName, Bytes, Encoding);
    FEncodingChanged := False;
    if (IDE <> nil) and (IDE.CodeInsight <> nil) then IDE.CodeInsight.InvalidateFile(FFileName);
    Result := True;
  except
    on E: Exception do
      MessageBox(GetParentForm(Self).Handle, PChar('Cannot save ' + FFileName + #13#10 + E.Message),
        'Error', MB_OK or MB_ICONERROR);
  end;
  HistoryEndMoment;
  if IDE <> nil then IDE.PageChanged(Self);
end;

{ The page under another name, nothing written (Delphi 7's IOTAModule.FileName): the unit's name in
  its text follows - in the file's encoding -, the form shown as text names the new .dfm, the page is
  modified, Save writes it there. A file of an expert's file system goes to the disk (Delphi's: a
  renamed module leaves the file system). Not the form's text of a unit (it is saved with its unit) }
procedure TEditorPage.Rename(const NewFileName: string);
var
  Src, Old, NewName: string;
begin
  if FFormOwner <> nil then Exit;
  NewName := ChangeFileExt(ExtractFileName(NewFileName), '');
  if IsPascal and not SameText(UnitName, NewName) then
  begin
    Src := GetSource;
    Old := Src;
    if IsProjectFile(NewFileName) then
      DprSetProgramName(Src, AnsiToEditor(NewName, Encoding))
    else
      FSRenameUnit(Src, AnsiToEditor(NewName, Encoding));
    SourceEdit(Src, Old);
  end;
  FFileSystem := '';
  FFileName := ExpandPathU(NewFileName);
  FUntitled := False;
  if FFormTextPage <> nil then FFormTextPage.FFileName := FormFileName;
  if FHasForm then FFormModified := True;
  FEditor.SetLanguageFromFile(FFileName);
  if FDiagramView and not CanDiagram then ShowDesign(False);
  if FHistoryView then FHistory.HistoryChanged;        // the versions of the file of the new name
  UpdateViewTabs;
  MarkModified;
end;

function TEditorPage.SaveAs(const NewFileName: string): Boolean;
var
  OldFile, OldFileSystem: string;
  OldUntitled, OldFormModified, OldMarked: Boolean;
begin
  Result := False;
  { View as Text: the page is saved with its unit and names the unit's form - a name of its own
    would save the unit and the form under the old names and leave the tab naming no file }
  if FFormOwner <> nil then
  begin
    MessageBox(GetParentForm(Self).Handle, PChar('The form of ' + ExtractFileName(FFormOwner.FFileName) +
      ' is shown as text and is saved with its unit: use Save As on the page of the unit.'), 'Save As',
      MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  { the page's encoding goes with it to the new name: Save remembers it there when needed }
  OldFile := FFileName;
  OldUntitled := FUntitled;
  OldFormModified := FFormModified;
  OldFileSystem := FFileSystem;
  OldMarked := FMarked;
  Rename(NewFileName);
  Result := Save;
  if not Result then
  begin
    { nothing was written: the page keeps its file (the unit's new name stays: an edit to undo) }
    FFileName := OldFile;
    FUntitled := OldUntitled;
    FFormModified := OldFormModified;
    FFileSystem := OldFileSystem;
    FMarked := OldMarked;
    if FFormTextPage <> nil then FFormTextPage.FFileName := FormFileName;
    FEditor.SetLanguageFromFile(FFileName);
    UpdateViewTabs;
  end;
end;

{ the file was written by someone else since it was read or saved: its last write time (to
  100 ns, not DOS's 2 seconds) or its size differ }
function TEditorPage.CheckFileChanged: Boolean;
var
  S: TSdFileStamp;
  FS: TSdPageFileSystem;
  Age: Integer;
begin
  Result := False;
  if FUntitled then Exit;
  { a file of an expert's file system: its age there (Delphi's rule) }
  if FFileSystem <> '' then
  begin
    if not Assigned(PageFileSystemOf) then Exit;
    try
      FS := PageFileSystemOf(FFileSystem);
      if FS = nil then Exit;
      try
        if not FS.FileExists(FFileName) then Exit;
        Age := FS.FileAge(FFileName);
        Result := Age <> FFsAge;
        if Result then FFsAge := Age;
      finally
        FS.Free;
      end;
    except
      Result := False;
    end;
    Exit;
  end;
  S := FileStampU(FFileName);
  Result := S.Exists and not SameFileStamp(S, FFileStamp);
  if Result then FFileStamp := S;
end;

procedure TEditorPage.GotoLine(Line, Col: Integer);
begin
  if Line < 1 then Line := 1;
  if Col < 1 then Col := 1;
  FEditor.GotoLineByte(Line - 1, Col - 1, True);
end;

procedure TEditorPage.ShowText(TopLine, Line, Col: Integer);
begin
  if TopLine < 1 then TopLine := 1;
  if Line < 1 then Line := 1;
  if Col < 1 then Col := 1;
  FEditor.Sci(SCI_ENSUREVISIBLE, TopLine - 1);
  FEditor.Sci(SCI_SETFIRSTVISIBLELINE, FEditor.Sci(SCI_VISIBLEFROMDOCLINE, TopLine - 1));
  FEditor.GotoLineByte(Line - 1, Col - 1, False);
  FEditor.Sci(SCI_SCROLLCARET);
end;

function TEditorPage.EnsureDesigner: Boolean;
var
  Errs, Anc: TStringList;
  D: TFormDesigner;
  S, DfmName: string;
  I: Integer;
begin
  Result := FDesigner <> nil;
  if Result or not FHasForm or FDesignFailed then Exit;
  Errs := TStringList.Create;
  D := TFormDesigner.Create(DesignPanel, FBridge, False);     // the page's frame is around it
  try
    try
      DetectRootKind;
      D.HostKind := FRootKind;
      D.ModuleClass := FRootModule;
      { an inherited form: its ancestors' forms first }
      Anc := TStringList.Create;
      try
        if not LoadAncestors(FDfmText, Anc) then
          raise Exception.CreateFmt('the form of its ancestor %s is not found (it must be a form of the project)',
            [FSGetAncestorName(GetSource, FFormClass)]);
        D.LoadFromText(DfmToHost(FDfmText), Errs, Anc);
      finally
        Anc.Free;
      end;
      if Errs.Count > 0 then
      begin
        { Delphi's question: a class that is not installed or an unknown property means that
          saving the form would drop those parts of the .dfm - never do that silently }
        DfmName := ExtractFileName(FormFileName);
        S := Errs[0];
        if Errs.Count > 1 then S := S + Format(' (and %d more of this kind)', [Errs.Count - 1]);
        for I := 0 to Errs.Count - 1 do FormMessage(Errs[I]);
        if MessageBox(GetParentForm(Self).Handle, PChar('Error reading ' + DfmName + ': ' + S + '.'#13#10#13#10 +
          'Ignore the error and continue?'#13#10 +
          'NOTE: Ignoring the error may cause components to be deleted or property values to be lost.'),
          'Error', MB_YESNO or MB_ICONERROR or MB_DEFBUTTON2) <> IDYES then
          Exit;               // stay in the code view; the form file is left untouched
      end;
      FDesigner := D;
      D := nil;
      FUndo.Reset(FDesigner.SaveToText, FDesigner.SelectionNames);
      Result := True;
    except
      on E: Exception do
      begin
        FDesignFailed := True;
        if IDE <> nil then
          IDE.ShowMessage('Form ' + ExtractFileName(FormFileName) + ' cannot be opened in the designer: ' +
            E.Message);
      end;
    end;
  finally
    D.Free;
    Errs.Free;
  end;
end;

procedure TEditorPage.ShowDesign(Value: Boolean; TakeFocus: Boolean);
begin
  if Value and not FHasForm then Exit;
  if Value and (FFormTextPage <> nil) then
  begin
    if IDE <> nil then IDE.ShowPage(FFormTextPage);
    Exit;
  end;
  if Value and not EnsureDesigner then Value := False;
  if Value then FollowAncestors;
  CloseCodePopups;
  FDesignView := Value;
  FDiagramView := False;
  FHistoryView := False;
  ShowView(TakeFocus);
end;

function TEditorPage.CanDiagram: Boolean;
begin
  Result := IsPascal and IsUnitFile;
end;

function TEditorPage.CodeView: Boolean;
begin
  Result := not FDesignView and not FDiagramView and not FHistoryView;
end;

procedure TEditorPage.ShowDiagram(Value: Boolean; TakeFocus: Boolean);
var
  Root: TCIStructNode;
begin
  if Value and not CanDiagram then Exit;
  if not Value then
  begin
    if FDiagramView then ShowDesign(False, TakeFocus);
    Exit;
  end;
  CloseCodePopups;
  if FDiagram = nil then
  begin
    FDiagram := TSdDiagramView.Create(Self);
    FDiagram.Visible := False;
    FDiagram.Parent := FViewFrame;
    FDiagram.Align := alClient;
    FDiagram.OnGoto := DiagramGoto;
  end;
  { the classes of the text as it is now - it may have changed since the tab was last shown }
  Root := nil;
  if (IDE <> nil) and (IDE.CodeInsight <> nil) then Root := IDE.CodeInsight.GetStructure(FFileName, GetSource);
  try
    FDiagram.ShowStructure(Root, UnitName, FDiagramShown);
  finally
    Root.Free;
  end;
  FDiagramShown := True;
  FDesignView := False;
  FHistoryView := False;
  FDiagramView := True;
  ShowView(TakeFocus);
end;

function TEditorPage.CanHistory: Boolean;
begin
  Result := HistoryEnabled and not FUntitled and (FFileSystem = '');
end;

procedure TEditorPage.ShowHistory(Value: Boolean; TakeFocus: Boolean);
begin
  if Value and not CanHistory then Exit;
  if not Value then
  begin
    if FHistoryView then ShowDesign(False, TakeFocus);
    Exit;
  end;
  CloseCodePopups;
  if FHistory = nil then
  begin
    FHistoryHost := TPageHistoryHost.Create;
    FHistoryHost.FPage := Self;
    FHistory := TSdHistoryView.Create(Self);
    FHistory.Visible := False;
    FHistory.Host := FHistoryHost;
    FHistory.Parent := FViewFrame;
    FHistory.Align := alClient;
    if IDE <> nil then IDE.HistoryViewMade(FHistory);
  end;
  FDesignView := False;
  FDiagramView := False;
  FHistoryView := True;
  ShowView(TakeFocus);
  { the versions and the text now as they are (both may have changed since it was last shown) }
  FHistory.Shown;
end;

procedure TEditorPage.HistoryChanged;
begin
  if FHistory <> nil then FHistory.HistoryChanged;
end;

procedure TEditorPage.HistoryOptionsChanged;
begin
  if FHistory <> nil then FHistory.OptionsChanged;
  if FHistoryView and not CanHistory then ShowDesign(False, False);
  UpdateViewTabs;
end;

procedure TEditorPage.KeepVersion(Kind: THistoryKind);
var
  Dfm: string;
begin
  if not CanHistory or (FFormOwner <> nil) then Exit;
  HistoryBeginMoment;
  try
    if SourceModified and ((Kind <> hkUnsaved) or (FTextVersion <> FKeptVersion)) then
    begin
      HistoryKeep(FFileName, FEditor.FileBytes, Encoding, Kind);
      FKeptVersion := FTextVersion;
    end;
    if FHasForm and FormChanged then
    begin
      TakeFormText;
      Dfm := CurrentDfm;
      if Dfm <> '' then HistoryKeep(FormFileName, FormBytesOf(Dfm), IdeEncoding, Kind);
    end;
  finally
    HistoryEndMoment;
  end;
end;

procedure TEditorPage.CheckHistoryDisk;
begin
  HistoryCheckDisk(FFileName, Encoding);
  if FHasForm then HistoryCheckDisk(FormFileName, IdeEncoding);
end;

function TEditorPage.FormChanged: Boolean;
begin
  Result := FFormModified or (FDesigner <> nil) and FDesigner.IsModified;
end;

function TEditorPage.FormBytesOf(const Dfm: string): string;
begin
  if FDfmBinary then Result := DfmTextToBinary(Dfm) else Result := Dfm;
end;

{ the controls of the view chosen (FDesignView, FDiagramView, FHistoryView, else the code): the new
  one is shown before the old ones go, so that the page's ground never shows between them }
procedure TEditorPage.ShowView(TakeFocus: Boolean);
var
  Views: array[0..3] of TControl;
  Shown: TControl;
  Focus: TWinControl;
  I: Integer;
  Active: Boolean;
begin
  { the view's control and what takes the keyboard when TakeFocus: the diagram, the timeline - the
    code's editor at any rate, the designer's surface through the designer }
  Focus := nil;
  if FDesignView then Shown := DesignPanel
  else if FDiagramView then
  begin
    Shown := FDiagram;
    Focus := FDiagram;
  end
  else if FHistoryView then
  begin
    Shown := FHistory;
    Focus := FHistory.Timeline;
  end
  else Shown := FCodeArea;
  Views[0] := FCodeArea;
  Views[1] := DesignPanel;
  Views[2] := FDiagram;
  Views[3] := FHistory;
  Shown.Visible := True;
  for I := 0 to High(Views) do
    if (Views[I] <> nil) and (Views[I] <> Shown) then Views[I].Visible := False;
  Active := (GetParentForm(Self) <> nil) and GetParentForm(Self).Active;
  if Shown = FCodeArea then
  begin
    if FEditor.CanFocus and Active then FEditor.SetFocus;
  end
  else if FDesignView then
  begin
    if FDesigner <> nil then
    begin
      FDesigner.UpdateHelpers;
      if TakeFocus then FDesigner.FocusSurface;
    end;
  end
  else if TakeFocus and Focus.CanFocus and Active then
    Focus.SetFocus;
  FViewTabs.TabIndex := FViewTabs.Tabs.IndexOf(ViewTab);
  if IDE <> nil then IDE.PageChanged(Self);
end;

function TEditorPage.ViewTab: string;
begin
  if FDesignView then Result := DesignTab
  else if FDiagramView then Result := DiagramTab
  else if FHistoryView then Result := HistoryTab
  else Result := CodeTab;
end;

function TEditorPage.NavigationWanted: Boolean;
begin
  Result := IsPascal and EditorOptions.NavigationBar;
end;

function TEditorPage.ZoomView: ISdZoomView;
begin
  if FDesignView then Result := FDesigner
  else if FDiagramView then Result := FDiagram
  else Result := SdZoom.EditorZoom;          // the code, and the History tab's diff
end;

procedure TEditorPage.ArrangePageBar;
var
  Nav: TWinControl;
begin
  if IDE = nil then Exit;
  if FDesignView then
    FPageBar.Arrange([IDE.ZoomBar, IDE.DesignerBar], nil)
  else if FDiagramView then
    FPageBar.Arrange([IDE.ZoomBar, IDE.DiagramBar], nil)
  else if FHistoryView then
    FPageBar.Arrange([IDE.ZoomBar, IDE.HistoryBar, FHistory.FilterBar], FHistory.FilterBar)
  else
  begin
    if NavigationWanted then Nav := IDE.NavigationBar else Nav := nil;
    FPageBar.Arrange([IDE.ZoomBar, Nav], Nav);
  end;
end;

{ the tabs below the page: Code, Design for a unit with a form, Diagram for a Pascal unit,
  program or package, History for a file of the disk while the files' history is kept; none for
  one view alone. The navigation bar follows the file's kind too }
procedure TEditorPage.UpdateViewTabs;
var
  Tabs: TStringList;
begin
  Tabs := TStringList.Create;
  try
    Tabs.Add(CodeTab);
    if FHasForm then Tabs.Add(DesignTab);
    if CanDiagram then Tabs.Add(DiagramTab);
    if CanHistory then Tabs.Add(HistoryTab);
    if not Tabs.Equals(FViewTabs.Tabs) then
    begin
      FViewTabs.Tabs.Assign(Tabs);
      FViewTabs.TabIndex := FViewTabs.Tabs.IndexOf(ViewTab);
      if FViewTabs.TabIndex < 0 then FViewTabs.TabIndex := 0;
    end;
    FViewTabs.Visible := Tabs.Count > 1;
  finally
    Tabs.Free;
  end;
  ApplyNavigationBar;
end;

procedure TEditorPage.ApplyNavigationBar;
begin
  if IDE <> nil then IDE.PageBarChanged(Self);
end;

procedure TEditorPage.DiagramGoto(Sender: TObject; Line, Col: Integer);
begin
  ShowDesign(False);
  GotoLine(Line, Col);
  if FEditor.CanFocus then FEditor.SetFocus;
end;

{ F12: from the code to the design view and back; from the diagram or the history to the code }
procedure TEditorPage.ToggleView;
begin
  if FDiagramView or FHistoryView then ShowDesign(False)
  else if FHasForm then ShowDesign(not FDesignView);
end;

{ a click on a tab (ShowDesign chooses the tab of the view it could show) }
procedure TEditorPage.ViewTabsChange(Sender: TObject);
var
  Tab: string;
begin
  if FViewTabs.TabIndex < 0 then Exit;
  Tab := FViewTabs.Tabs[FViewTabs.TabIndex];
  if Tab = DiagramTab then
  begin
    if not FDiagramView then ShowDiagram(True);
  end
  else if Tab = HistoryTab then
  begin
    if not FHistoryView then ShowHistory(True);
  end
  else if Tab = DesignTab then
  begin
    if not FDesignView then ShowDesign(True);
  end
  else if not CodeView then ShowDesign(False);
end;
{ --- code insight --- }

procedure TEditorPage.CloseCodePopups;
begin
  { an expert's list or hint of this page ends (no Done); it never touches the page again }
  if IDE <> nil then IDE.CICancel(Self);
  if AutoTimer <> nil then AutoTimer.Enabled := False;
  if HintTimer <> nil then HintTimer.Enabled := False;
  if (CompletionPopup <> nil) and CompletionPopup.Active and (CompletionPopup.Editor = FEditor) then
    CompletionPopup.CloseUp;
  if (ParamHint <> nil) and ParamHint.Showing then ParamHint.HideHints;
  HideTips(True);
end;

function TEditorPage.WordAtCaret: string;
var
  S, E: Integer;
begin
  Result := EditorToAnsi(FEditor.WordAt(FEditor.CaretPos, S, E), Encoding);
end;

function TEditorPage.DesignatorAtCaret: string;
var
  S, E: Integer;
begin
  Result := EditorToAnsi(FEditor.DesignatorAt(FEditor.CaretPos, False, S, E), Encoding);
end;

procedure TEditorPage.InvokeCodeInsight(Key: Char);
begin
  if (IDE <> nil) and IDE.CIInvoke(Self, Key, -1) then Exit;
  case Key of
    #0, '.': OpenCompletion(False);
    #1, '(': UpdateParamHint(True);
  end;
end;

procedure TEditorPage.CMCodeInsight(var Message: TMessage);
begin
  InvokeCodeInsight(Chr(Message.WParam));
end;

procedure TEditorPage.ShowCompletion;
begin
  InvokeCodeInsight(#0);
end;

{ the code of a template in place of the word it was chosen for: its lines after the first with
  the indentation of the caret's line, the line ends of the file, the caret where its '|' is.
  The .dci's code is ANSI: it goes in in the file's encoding (UTF-8 for a Unicode file) }
procedure InsertTemplate(Ed: TSciEdit; const Code: string; FromPos: Integer);
var
  L: TStringList;
  Indent, Eol, Text: string;
  I, Bar, P, ToPos: Integer;
  Line: string;
begin
  Line := Ed.GetLineText(Ed.LineFromPos(FromPos));
  I := 1;
  while (I <= Length(Line)) and (Line[I] in [' ', #9]) do Inc(I);
  Indent := Copy(Line, 1, I - 1);
  case Ed.Sci(SCI_GETEOLMODE) of
    SC_EOL_LF: Eol := #10;
    SC_EOL_CR: Eol := #13;
  else
    Eol := #13#10;
  end;
  L := TStringList.Create;
  try
    L.Text := AnsiToEditor(Code, Ed.Encoding);
    Text := '';
    for I := 0 to L.Count - 1 do
    begin
      if I > 0 then Text := Text + Eol + Indent;
      Text := Text + L[I];
    end;
  finally
    L.Free;
  end;
  Bar := Pos('|', Text);
  if Bar > 0 then Delete(Text, Bar, 1);
  ToPos := Ed.CaretPos;
  while Ed.IsIdentChar(Ed.CharAt(ToPos)) do Inc(ToPos);
  Ed.Sci(SCI_BEGINUNDOACTION);
  try
    Ed.Sci(SCI_SETTARGETSTART, FromPos);
    Ed.Sci(SCI_SETTARGETEND, ToPos);
    Ed.SciS(SCI_REPLACETARGET, Length(Text), Text);
  finally
    Ed.Sci(SCI_ENDUNDOACTION);
  end;
  if Bar > 0 then P := FromPos + Bar - 1 else P := FromPos + Length(Text);
  Ed.GotoPos(P);
end;

function TEditorPage.CanFormat: Boolean;
begin
  Result := IsPascal or (FEditor.Language = slDfm);
end;

function TEditorPage.FormatSource(Selection: Boolean): string;
var
  Src: string;
  R: TFmtResult;
  Kind: TFmtFileKind;
  SS, SE, K, Caret, Anchor, FirstPos, P: Integer;
begin
  Result := '';
  if not CanFormat then
  begin
    Result := 'The formatter formats Pascal sources and form files.';
    Exit;
  end;
  if FEditor.ReadOnly then
  begin
    Result := ExtractFileName(FFileName) + ' is read-only.';
    Exit;
  end;
  Src := FEditor.GetText;
  if IsPascal then Kind := ffPascal else Kind := ffForm;
  { a form file is ANSI text: one held as UTF-8 with other characters would be misread }
  if (Kind = ffForm) and IsUnicodeEncoding(FEditor.Encoding) then
    for P := 1 to Length(Src) do
      if Ord(Src[P]) > 127 then
      begin
        Result := ExtractFileName(FFileName) + ' holds characters outside ASCII in a Unicode file: ' +
          'it is not formatted.';
        Exit;
      end;
  SS := -1;
  SE := -1;
  if Selection and (FEditor.SelEnd > FEditor.SelStart) then
  begin
    SS := FEditor.SelStart;
    SE := FEditor.SelEnd;
  end;
  if not FormatText(Kind, Src, SS, SE, R, Result) then Exit;
  if Length(R.Edits) = 0 then Exit;
  Caret := FEditor.CaretPos;
  Anchor := FEditor.Sci(SCI_GETANCHOR);
  FirstPos := FEditor.PosFromLine(FEditor.Sci(SCI_DOCLINEFROMVISIBLE, FEditor.Sci(SCI_GETFIRSTVISIBLELINE)));
  FEditor.BeginUndo;
  try
    { the last first, so that the positions of the others stay; each part only where it differs
      (the lines that only changed inside keep their markers) }
    for K := High(R.Edits) downto 0 do
    begin
      FEditor.Sci(SCI_SETTARGETRANGE, R.Edits[K].Start, R.Edits[K].Start + R.Edits[K].Len);
      FEditor.SciS(SCI_REPLACETARGETMINIMAL, Length(R.Edits[K].Text), R.Edits[K].Text);
    end;
  finally
    FEditor.EndUndo;
  end;
  FEditor.SetSel(FmtMapPos(R, Anchor), FmtMapPos(R, Caret));
  FEditor.Sci(SCI_SETFIRSTVISIBLELINE, FEditor.Sci(SCI_VISIBLEFROMDOCLINE,
    FEditor.LineFromPos(FmtMapPos(R, FirstPos))));
  if IDE <> nil then IDE.PageChanged(Self);
end;

function TEditorPage.TemplateAccepted(const Item: TCIItem; PrefixStart: Integer): Boolean;
begin
  InsertTemplate(FEditor, Item.Decl, PrefixStart);
  Result := True;
end;

procedure TEditorPage.ShowCodeTemplates;
var
  List: TCIItemList;
  It: PCIItem;
  S, I, Exact, N: Integer;
  Word, ID: string;
begin
  if FDesignView or (CompletionPopup = nil) then Exit;
  S := FEditor.CaretPos;
  while (S > 0) and FEditor.IsIdentChar(FEditor.CharAt(S - 1)) do Dec(S);
  Word := FEditor.GetRange(S, FEditor.CaretPos);
  ID := FEditor.FileType.ID;
  List := TCIItemList.Create;
  try
    Exact := -1;
    N := 0;
    for I := 0 to High(CodeTemplates) do
      if ((CodeTemplates[I].FileTypeID = '') or SameText(CodeTemplates[I].FileTypeID, ID)) and
        SameText(Copy(CodeTemplates[I].Name, 1, Length(Word)), Word) then
      begin
        It := List.Add;
        It^.Name := CodeTemplates[I].Name;
        It^.Kind := ckTemplate;
        It^.TypeName := CodeTemplates[I].Description;
        It^.Decl := CodeTemplates[I].Code;
        if SameText(CodeTemplates[I].Name, Word) then Exact := I;
        Inc(N);
      end;
    if N = 0 then
    begin
      MessageBeep(0);
      Exit;
    end;
    { the one whose name is the word: at once (Delphi's) }
    if (Exact >= 0) and (Word <> '') then
    begin
      InsertTemplate(FEditor, CodeTemplates[Exact].Code, S);
      Exit;
    end;
    List.Sort;
    CompletionPopup.Open(FEditor, List, S);
    CompletionPopup.OnAcceptItem := TemplateAccepted;
    List := nil;          // owned by the popup now
  finally
    List.Free;
  end;
end;

procedure TEditorPage.OpenCompletion(Auto: Boolean);
var
  List: TCIItemList;
  Start: Integer;
begin
  AutoTimer.Enabled := False;
  if not IsPascal or (IDE = nil) or (IDE.CodeInsight = nil) or (CompletionPopup = nil) then Exit;
  { completion while typing: only while D7 Studio's own code insight is the file's (the other
    ways here asked IDE.CIInvoke first) }
  if Auto and not IDE.CIOwnAllowed(Self) then Exit;
  List := TCIItemList.Create;
  try
    if IDE.CodeInsight.GetCompletions(FFileName, GetSource, FEditor.CaretPos, List, Start) and (List.Count > 0) then
    begin
      CompletionPopup.Open(FEditor, List, Start, Auto);
      List := nil;      // owned by the popup now
    end;
  finally
    List.Free;
  end;
end;

{ Completion while typing: once an identifier is two characters long the list is requested after
  a short pause, so that fast typing never waits for it. }
function TEditorPage.AutoPrefixAtCaret(var StartPos: Integer): string;
var
  P, S: Integer;
begin
  Result := '';
  P := FEditor.CaretPos;
  S := P;
  while (S > 0) and FEditor.IsIdentChar(FEditor.CharAt(S - 1)) do Dec(S);
  StartPos := S;
  if (S = P) or (FEditor.CharAt(S) in ['0'..'9']) then Exit;                 // nothing, or a number
  if (S > 0) and (FEditor.CharAt(S - 1) in ['$', '#', '&']) then Exit;       // $FF, #13
  if FEditor.IsIdentChar(FEditor.CharAt(P)) then Exit;                       // inside a word
  if FEditor.IsCommentOrString(P - 1) then Exit;
  Result := FEditor.GetRange(S, P);
end;

procedure TEditorPage.AutoTimerTick(Sender: TObject);
var
  W, Before: string;
  S, P, LineStart: Integer;
begin
  AutoTimer.Enabled := False;
  if not EditorOptions.AutoComplete or FDesignView or not Visible or not IsPascal then Exit;
  if (CompletionPopup = nil) or CompletionPopup.Active then Exit;
  W := AutoPrefixAtCaret(S);
  if (Length(W) < 2) or IsPascalKeyword(W) or (S = FAutoDismissed) then Exit;
  { a name that is being invented (procedure Foo, unit Bar, property Baz) needs no list }
  LineStart := FEditor.PosFromLine(FEditor.LineFromPos(S));
  Before := LowerCase(TrimRight(FEditor.GetRange(LineStart, S)));
  P := Length(Before);
  while (P > 0) and (Before[P] in ['a'..'z']) do Dec(P);
  Before := Copy(Before, P + 1, MaxInt);
  if (Before = 'procedure') or (Before = 'function') or (Before = 'constructor') or
    (Before = 'destructor') or (Before = 'unit') or (Before = 'program') or (Before = 'library') or
    (Before = 'property') or (Before = 'label') then Exit;
  OpenCompletion(True);
end;

{ Force: shown (after '(', Ctrl+Shift+Space), else refreshed while it shows - once for a state of
  the text and the caret: asking code insight copies the whole text and parses it again when it
  changed }
procedure TEditorPage.UpdateParamHint(Force: Boolean);
var
  Hints: TCIParamHintArray;
  Active: Integer;
  P: TPoint;
begin
  HintTimer.Enabled := False;
  if ParamHint = nil then Exit;
  if not Force and not ParamHint.Showing then Exit;
  if not IsPascal or (IDE = nil) or (IDE.CodeInsight = nil) then Exit;
  { a hint shown is followed only while D7 Studio's own code insight is the file's (an expert's
    hint is its own; Force came through IDE.CIInvoke) }
  if not Force and not IDE.CIOwnAllowed(Self) then Exit;
  if not Force and (FHintVersion = FTextVersion) and (FHintCaret = FEditor.CaretPos) then Exit;
  FHintVersion := FTextVersion;
  FHintCaret := FEditor.CaretPos;
  if IDE.CodeInsight.GetParamHints(FFileName, GetSource, FEditor.CaretPos, Hints, Active) and (Length(Hints) > 0) then
  begin
    P := FEditor.PointFromPos(FEditor.CaretPos);
    P := FEditor.ClientToScreen(Point(P.X, P.Y + FEditor.TextHeight + 2));
    ParamHint.ShowHints(P, Hints, Active, FEditor.TextHeight + 4);
  end
  else
    ParamHint.HideHints;
end;

procedure TEditorPage.ShowParamHint;
begin
  InvokeCodeInsight(#1);
end;

procedure TEditorPage.HintTimerTick(Sender: TObject);
begin
  UpdateParamHint(False);
end;

{ the completion list follows the text and the caret - once for each change: typing reports it
  twice (SCN_CHARADDED at once, SCN_UPDATEUI when the editor paints) }
procedure TEditorPage.CompletionTextChanged;
begin
  if (CompletionPopup = nil) or not CompletionPopup.Active or (CompletionPopup.Editor <> FEditor) then Exit;
  if (FListVersion = FTextVersion) and (FListCaret = FEditor.CaretPos) then Exit;
  FListVersion := FTextVersion;
  FListCaret := FEditor.CaretPos;
  CompletionPopup.TextChanged;
end;

procedure TEditorPage.FindDeclarationAtCaret;
begin
  EditorCtrlClick(FEditor, FEditor.CaretPos);
end;

procedure TEditorPage.EditorCtrlClick(Sender: TObject; Position: Integer);
var
  Item: TCIItem;
begin
  { an expert's code insight manager for the file browses itself (the Open Tools API) }
  if (IDE <> nil) and IDE.CIInvoke(Self, #2, Position) then Exit;
  if not IsPascal or (IDE = nil) or (IDE.CodeInsight = nil) then Exit;
  if IDE.CodeInsight.FindDeclaration(FFileName, GetSource, Position, Item) and (Item.Line > 0) then
  begin
    if Item.FileName = '' then Item.FileName := FFileName;
    IDE.OpenFileAt(Item.FileName, Item.Line, Item.Col);
  end
  else
    MessageBeep(MB_ICONASTERISK);
end;

procedure TEditorPage.EditorCharAdded(Sender: TObject; Ch: Integer);
var
  S: Integer;
begin
  { the Open Tools API: an expert's list follows the text at once; '.' and '(' go to the file's
    code insight manager first, as Delphi's key mapping binds them to code completion }
  if IDE <> nil then
  begin
    IDE.CIChanged(Self);
    if ((Ch = Ord('.')) or (Ch = Ord('('))) and IDE.CIInvoke(Self, Chr(Ch), -1) then Exit;
  end;
  if not IsPascal then Exit;
  AutoTimer.Enabled := False;
  { an open list is filtered at once, not when the editor paints: a key typed ahead (Enter)
    must find it filtered for every character before it }
  if (CompletionPopup <> nil) and CompletionPopup.Active then
    CompletionTextChanged
  else if (Ch = Ord('.')) and not FEditor.IsCommentOrString(FEditor.CaretPos - 2) then
    OpenCompletion(False)
  else if EditorOptions.AutoComplete and (Ch < 256) and FEditor.IsIdentChar(Chr(Ch)) then
  begin
    { completion while typing: asked for after a short pause, from the second character on,
      unless the list was dismissed with Esc for this very word }
    if (Length(AutoPrefixAtCaret(S)) >= 2) and (S <> FAutoDismissed) then
    begin
      AutoTimer.Interval := EditorOptions.CodeDelay * 100;   // Code Insight | Delay
      AutoTimer.Enabled := True;
    end;
  end
  else
    FAutoDismissed := -1;
  if (Ch = Ord('(')) and EditorOptions.AutoParameters and not FEditor.IsCommentOrString(FEditor.CaretPos - 2) then
    UpdateParamHint(True)
  else if Ch in [Ord('('), Ord(','), Ord(')')] then
    UpdateParamHint(False);
end;

procedure TEditorPage.EditorUpdateUI(Sender: TObject; Updated: Integer);
begin
  if (Updated and (SC_UPDATE_SELECTION or SC_UPDATE_CONTENT)) <> 0 then
  begin
    { the value under the mouse was the text's before: a click, a moved caret, an edit end it }
    HideTips(True);
    CompletionTextChanged;
    if IDE <> nil then IDE.CIChanged(Self);
    IdentCaretMoved;
    { the parameter hint: a changed text at once (it stays under the caret while typing), a
      caret that only moved after a pause (a key held down moves it many times) }
    if (ParamHint <> nil) and ParamHint.Showing then
      if FHintVersion <> FTextVersion then
        UpdateParamHint(False)
      else if FHintCaret <> FEditor.CaretPos then
      begin
        HintTimer.Enabled := False;
        HintTimer.Enabled := True;
      end;
  end;
  if (Updated and (SC_UPDATE_V_SCROLL or SC_UPDATE_H_SCROLL)) <> 0 then CloseCodePopups;
  if (Updated and SC_UPDATE_V_SCROLL) <> 0 then NamesChanged;
  if IDE <> nil then IDE.PageChanged(Self);
end;

{ the editor came into a window or took new options: other lines in view, another language or
  other colours }
procedure TEditorPage.EditorViewApplied(Sender: TObject);
begin
  NamesChanged;
  ErrorsChanged;
end;

{ Names by kind: coloured again after a pause of the text and the scrolling }
procedure TEditorPage.NamesChanged;
begin
  NameTimer.Enabled := False;
  NameTimer.Enabled := True;
end;

{ a Pascal text code insight reads, in a theme with a kind's colour or font style not Identifier's }
function TEditorPage.NamesWanted: Boolean;
var
  E: TEditorElement;
  Ident: TColor;
  C: TEditorColors;
begin
  Result := IsPascal and (FEditor.TextLength <= MaxNamesText) and (IDE <> nil) and (IDE.CodeInsight <> nil);
  if not Result then Exit;
  C := EditorOptions.Colors;
  Ident := ElementFore(C, eeIdentifier);
  for E := eeType to eeUnitName do
    if (ElementFore(C, E) <> Ident) or (ElementFontStyles(C[E]) <> ElementFontStyles(C[eeIdentifier])) then Exit;
  Result := False;
end;

{ the names of FromPos .. ToPos in their kinds' colours, as code insight resolves them (one pass
  for all of them); a name it does not know keeps Identifier's }
procedure TEditorPage.ColourNames(FromPos, ToPos: Integer);
var
  N, I: Integer;
  Ends: array of Integer;
  Kinds: array of TCIKind;
begin
  N := FEditor.NamesBetween(FromPos, ToPos, FNames);
  if N > 0 then
  begin
    SetLength(Ends, N);
    SetLength(Kinds, N);
    for I := 0 to N - 1 do Ends[I] := FNames[I].Start + FNames[I].Len;
    if IDE.CodeInsight.NameKinds(FFileName, GetSource, Ends, Kinds) then
      for I := 0 to N - 1 do FNames[I].Element := KindElements[Kinds[I]];
  end;
  FEditor.ShowNameKinds(FromPos, ToPos, FNames, N);
end;

{ the lines in view and NameViewMargin lines around them; of the same text only the lines not
  coloured yet }
procedure TEditorPage.NameTimerTick(Sender: TObject);
var
  A, B: Integer;
begin
  NameTimer.Enabled := False;
  if not FEditor.Shown then Exit;
  if not NamesWanted then
  begin
    if FNamesVersion >= 0 then FEditor.ClearNameKinds;
    FNamesVersion := -1;
    Exit;
  end;
  if not FEditor.ViewRange(NameViewMargin, A, B) then Exit;
  if (FNamesVersion <> FTextVersion) or (B < FNamesFrom) or (A > FNamesTo) then
  begin
    { another text, or far from what was coloured: this part alone }
    ColourNames(A, B);
    FNamesFrom := A;
    FNamesTo := B;
    FNamesVersion := FTextVersion;
  end
  else
  begin
    { next to it: the lines it adds }
    if A < FNamesFrom then
    begin
      ColourNames(A, FNamesFrom);
      FNamesFrom := A;
    end;
    if B > FNamesTo then
    begin
      ColourNames(FNamesTo, B);
      FNamesTo := B;
    end;
  end;
end;

{ Error Insight: checked again after a pause of the text (the text, the page shown, the options) }
procedure TEditorPage.ErrorsChanged;
begin
  ErrorTimer.Enabled := False;
  ErrorTimer.Enabled := True;
end;

{ a unit, program, library or package code insight reads (an include file is a piece of one: not
  checked alone), while Error Insight is on }
function TEditorPage.ErrorsWanted: Boolean;
begin
  Result := EditorOptions.ErrorInsight and IsPascal and IsUnitFile and (FEditor.TextLength <= MaxNamesText) and
    (IDE <> nil) and (IDE.CodeInsight <> nil);
end;

{ the page shown: its errors, when its text or another page's changed since its last check - every
  page's text counts, as code insight reads the open files' texts (ErrorInsightGen) }
procedure TEditorPage.ErrorTimerTick(Sender: TObject);
var
  Source: string;
begin
  ErrorTimer.Enabled := False;
  if ErrorsWanted then
  begin
    if not FEditor.Shown or (FErrorsVersion = FTextVersion) and (FErrorsGen = ErrorInsightGen) then Exit;
    Source := GetSource;
    IDE.CodeInsight.Diagnose(FFileName, Source, FErrors, FErrorCount);   // none when it cannot check
    FErrorsVersion := FTextVersion;
    FErrorsGen := ErrorInsightGen;
  end
  else
  begin
    if FErrorsVersion < 0 then Exit;     // none marked
    FErrors := nil;
    FErrorCount := 0;
    FErrorsVersion := -1;
  end;
  TakeErrors(Source);
  Inc(ErrorsStampGen);
  FErrorsStamp := ErrorsStampGen;
  if IDE <> nil then IDE.ErrorsChanged(Self);
end;

{ the errors marked in the editor: an error without a token of its own (the end of the text, an
  include directive) under the last character before it that is not blank, the directive's text }
procedure TEditorPage.TakeErrors(const Source: string);
var
  Starts, Lens: array of Integer;
  I, S, E: Integer;
begin
  SetLength(Starts, FErrorCount);
  SetLength(Lens, FErrorCount);
  for I := 0 to FErrorCount - 1 do
  begin
    S := FErrors[I].Start;
    E := S + FErrors[I].Len;
    if E <= S then
      if (S < Length(Source)) and (Source[S + 1] = '{') then
      begin
        { a directive: to its closing brace on its line }
        E := S + 1;
        while (E < Length(Source)) and not (Source[E + 1] in ['}', #13, #10]) do Inc(E);
        if (E < Length(Source)) and (Source[E + 1] = '}') then Inc(E);
      end
      else
      begin
        if S > Length(Source) then S := Length(Source);
        while (S > 0) and (Source[S] in [#0..' ']) do Dec(S);
        if S > 0 then Dec(S);
        E := S + 1;
      end;
    Starts[I] := S;
    Lens[I] := E - S;
  end;
  FEditor.ShowErrors(Starts, Lens, FErrorCount);
end;

{ Identifier matching: the places of the symbol at the caret, found after a pause of the caret
  in a word; they stay while it is in the same word of the same text, and go when it leaves the
  words or text is selected }
procedure TEditorPage.IdentCaretMoved;
var
  S, E: Integer;
begin
  if not EditorOptions.HighlightIdentifiers then Exit;
  IdentTimer.Enabled := False;
  if (FEditor.SelEnd > FEditor.SelStart) or (FEditor.WordAt(FEditor.CaretPos, S, E) = '') then
  begin
    if FIdentAt >= 0 then FEditor.ShowIdentifiers(nil, nil, 0);
    FIdentAt := -1;
    Exit;
  end;
  if (S <> FIdentAt) or (FIdentVersion <> FTextVersion) then IdentTimer.Enabled := True;
end;

{ by code insight in a Pascal unit (the symbol, not the name: a local I of one routine is not
  another's), else - another file, a name it does not know - the word's places in the code;
  shown only when there are at least two }
procedure TEditorPage.IdentTimerTick(Sender: TObject);
var
  Places, Decls: TList;
  S, E: Integer;
  W: string;
begin
  IdentTimer.Enabled := False;
  if not EditorOptions.HighlightIdentifiers or (FEditor.SelEnd > FEditor.SelStart) then Exit;
  W := FEditor.WordAt(FEditor.CaretPos, S, E);
  FIdentAt := S;
  FIdentVersion := FTextVersion;
  if (W = '') or (W[1] in ['0'..'9']) or FEditor.IsCommentOrString(S) or (IsPascal and IsPascalKeyword(W)) then
  begin
    FEditor.ShowIdentifiers(nil, nil, 0);
    Exit;
  end;
  Places := TList.Create;
  Decls := TList.Create;
  try
    if not (IsPascal and (FEditor.TextLength <= MaxIdentText) and (IDE <> nil) and (IDE.CodeInsight <> nil) and
      IDE.CodeInsight.SymbolOccurrences(FFileName, GetSource, FEditor.CaretPos, Places, Decls)) then
      FEditor.WordPlaces(W, Places, True);
    { a name in one place only has nothing to match: no box }
    if Places.Count < 2 then FEditor.ShowIdentifiers(nil, nil, 0)
    else FEditor.ShowIdentifiers(Places, Decls, E - S);
  finally
    Decls.Free;
    Places.Free;
  end;
end;

procedure TEditorPage.EditorZoom(Sender: TObject);
begin
  if IDE <> nil then IDE.EditorZoomed(Self);
end;

procedure TEditorPage.EditorModified(Sender: TObject; ModType, Position, Len, LinesAdded: Integer);
begin
  Inc(FTextVersion);
  Inc(ErrorInsightGen);
  NamesChanged;
  ErrorsChanged;
  if IDE <> nil then IDE.PageEdited(Self, Position, LinesAdded);
end;

procedure TEditorPage.EditorSavePoint(Sender: TObject);
begin
  if IDE <> nil then IDE.PageChanged(Self);
end;

procedure TEditorPage.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  K: Word;
  S: Integer;
  WasAuto: Boolean;
begin
  { a key ends the hover tips - not Shift, Ctrl or Alt alone (Ctrl makes the word under the
    pointer a link) }
  if not (Key in [VK_SHIFT, VK_CONTROL, VK_MENU]) then HideTips(True);
  { a key the popups consume still produces a WM_CHAR (Enter, Tab, Esc): swallow that too }
  FSwallowChar := False;
  if FIncSearch then
  begin
    if Key in [VK_SHIFT, VK_CONTROL, VK_MENU] then Exit;
    if Key = VK_BACK then
    begin
      if FIncText <> '' then
      begin
        DeleteLastIdeChar(FIncText);
        if FIncText = '' then FEditor.GotoPos(FIncStart) else IncSearchFind(FIncStart);
        if IDE <> nil then IDE.ShowStatus('Searching for: ' + FIncText);
      end;
      Key := 0;
      FSwallowChar := True;
      Exit;
    end;
    { a character goes to EditorKeyPress; Enter and Esc end the search, any other key ends it
      and does its work }
    if (Key in [VK_RETURN, VK_ESCAPE]) then
    begin
      EndIncSearch;
      Key := 0;
      FSwallowChar := True;
      Exit;
    end;
    { Ctrl and Alt together are AltGr: a character of the keyboard ('@', the euro sign), which
      goes on searching }
    if (Key in [VK_TAB, VK_PRIOR..VK_DOWN, VK_INSERT, VK_DELETE, VK_F1..VK_F24]) or
      ((ssCtrl in Shift) <> (ssAlt in Shift)) then
      EndIncSearch;
  end;
  K := Key;
  { an expert's list or parameter hint (the Open Tools API): its keys first - a key it took
    produces no character either (Enter, Tab, Esc, Space) }
  if (IDE <> nil) and IDE.CIKeyDown(Self, Key, Shift) then
  begin
    FSwallowChar := K in [VK_RETURN, VK_TAB, VK_ESCAPE, VK_SPACE];
    Exit;
  end;
  WasAuto := (CompletionPopup <> nil) and CompletionPopup.Active and CompletionPopup.AutoInvoked;
  if (CompletionPopup <> nil) and CompletionPopup.Active and CompletionPopup.HandleKey(Key, Shift) then
  begin
    FSwallowChar := K in [VK_RETURN, VK_TAB, VK_ESCAPE];
    { Esc on a list that opened by itself: leave this word alone from now on }
    if (K = VK_ESCAPE) and WasAuto then
    begin
      AutoPrefixAtCaret(S);
      FAutoDismissed := S;
    end;
    Exit;
  end;
  if (Key = VK_ESCAPE) and (ParamHint <> nil) and ParamHint.Showing then
  begin
    ParamHint.HideHints;
    Key := 0;
    FSwallowChar := True;
    Exit;
  end;
  if (Key = VK_SPACE) and (ssCtrl in Shift) then
  begin
    if ssShift in Shift then
      ShowParamHint
    else
    begin
      ShowCompletion;
      { as in Delphi 7: a single candidate is completed at once (D7 Studio's own list) }
      if (CompletionPopup <> nil) and (CompletionPopup.FilteredCount = 1) and
        (AutoPrefixAtCaret(S) <> '') and not CompletionPopup.SelectionIsTyped then CompletionPopup.Accept;
    end;
    Key := 0;
    FSwallowChar := True;            // Ctrl+Space also produces a space character
  end
  else if (ssCtrl in Shift) and not (ssAlt in Shift) then
  begin
    { the Delphi 7 editor keys that Scintilla does not provide (the bookmarks are actions, Ctrl+Y
      and the block chords the key mapping's) }
    if (Key in [VK_UP, VK_DOWN]) and (ssShift in Shift) and IsPascal then
    begin
      ToggleDeclImpl;
      Key := 0;
    end;
    if Key = 0 then FSwallowChar := True;
  end;
end;

procedure TEditorPage.SimulateKey(Key: Word; Shift: TShiftState);
begin
  { as a real key: the key mapping first (CN_KEYDOWN), then the editor's handler }
  if not FEditor.KeymapKey(Key, Shift) then EditorKeyDown(FEditor, Key, Shift);
end;

{ the key mapping's commands that are not the editor's own: the bookmarks here, the menu
  commands in the IDE }
procedure TEditorPage.EditorCommand(Sender: TObject; Cmd: TEdCmd; Arg: Integer);
begin
  if Cmd = ecSetBookmark then ToggleBookmark(Arg)
  else if Cmd = ecGotoBookmark then GotoBookmark(Arg)
  else if IDE <> nil then IDE.EditorCommand(Self, Cmd, Arg);
end;

procedure TEditorPage.ToggleBookmark(N: Integer);
var
  Line, Old: Integer;
begin
  { one line per bookmark: setting it elsewhere moves it, setting it again removes it }
  Line := FEditor.CaretLine;
  Old := FEditor.MarkerNext(0, 1 shl (MK_BOOKMARK0 + N));
  FEditor.MarkerDeleteAll(MK_BOOKMARK0 + N);
  if Old <> Line then SetBookmark(N);
end;

{ bookmark N at the cursor - its line (the marker) and its column, which Delphi's bookmarks keep
  too (Go to Bookmark returns to it) }
procedure TEditorPage.SetBookmark(N: Integer);
var
  Line: Integer;
begin
  Line := FEditor.CaretLine;
  FEditor.MarkerDeleteAll(MK_BOOKMARK0 + N);
  FEditor.MarkerAdd(Line, MK_BOOKMARK0 + N);
  FBookmarkCols[N] := FEditor.CaretPos - FEditor.PosFromLine(Line);
end;

{ the column of bookmark N: bytes into its line, no further than the line's end }
function TEditorPage.BookmarkCol(N: Integer): Integer;
var
  Line: Integer;
begin
  Result := 0;
  Line := FEditor.MarkerNext(0, 1 shl (MK_BOOKMARK0 + N));
  if Line < 0 then Exit;
  Result := FBookmarkCols[N];
  if Result > FEditor.LineEndPos(Line) - FEditor.PosFromLine(Line) then
    Result := FEditor.LineEndPos(Line) - FEditor.PosFromLine(Line);
end;

function TEditorPage.CompleteClass(FinishProperties: Boolean): Boolean;
var
  Src, Old: string;
  L, C: Integer;
begin
  Src := GetSource;
  Old := Src;
  Result := FSCompleteClass(Src, FEditor.CaretPos, FinishProperties, L, C) and SourceEdit(Src, Old);
  { like Delphi: in an empty body the caret waits at the statement indentation }
  if Result and (L > 0) then FEditor.GotoLineColVirtual(L - 1, C - 1);
end;

procedure TEditorPage.GotoBookmark(N: Integer);
var
  Line: Integer;
begin
  Line := FEditor.MarkerNext(0, 1 shl (MK_BOOKMARK0 + N));
  if Line >= 0 then FEditor.GotoLineByte(Line, BookmarkCol(N), True);
end;

{ Ctrl+Shift+Up/Down: between a method's declaration in its class and its implementation - the
  parser's answer (TUnitInfo.FindCounterpart: comments, strings, headings over several lines,
  nested routines and overloads as the compiler sees them) }
procedure TEditorPage.ToggleDeclImpl;
var
  U: TUnitInfo;
  Line, Col: Integer;
begin
  U := TUnitInfo.Create;
  try
    ParseSource(U, GetSource, False, nil, nil);
    if U.FindCounterpart(FEditor.CaretLine + 1, Line, Col) then GotoLine(Line, Col);    // the parser's column
  finally
    U.Free;
  end;
end;

procedure TEditorPage.EditorKeyPress(Sender: TObject; var Key: Char);
var
  S: string;
begin
  { the character that belongs to a key the IDE has consumed (Enter, Tab, Esc on a popup;
    Ctrl+Space, which arrives as a space; Ctrl+Y ...) must not reach the popup or the text }
  if FSwallowChar or ((Key = ' ') and (GetKeyState(VK_CONTROL) < 0) and (GetKeyState(VK_MENU) >= 0)) then
  begin
    FSwallowChar := False;
    Key := #0;
    Exit;
  end;
  if FIncSearch then
  begin
    if Key >= ' ' then
    begin
      S := TypedIdeChar(Key, FIncPending);
      if S <> '' then
      begin
        FIncText := FIncText + S;
        if not IncSearchFind(FIncStart) then
        begin
          SetLength(FIncText, Length(FIncText) - Length(S));
          MessageBeep(MB_ICONASTERISK);
        end;
        if IDE <> nil then IDE.ShowStatus('Searching for: ' + FIncText);
      end;
    end;
    Key := #0;
    Exit;
  end;
  { an expert's list: the key to its manager first (OnEditorKey) }
  if (IDE <> nil) and IDE.CIKeyPress(Self, Key) then
  begin
    Key := #0;
    Exit;
  end;
  if (CompletionPopup <> nil) and CompletionPopup.Active then
    CompletionPopup.HandleChar(Key);
end;

procedure TEditorPage.IncrementalSearch;
begin
  if FIncSearch and (FIncText <> '') then
  begin
    { Ctrl+E again: the next match }
    if not IncSearchFind(FEditor.SelEnd) then MessageBeep(MB_ICONASTERISK);
    Exit;
  end;
  FIncSearch := True;
  FIncText := '';
  FIncPending := '';
  FIncStart := FEditor.SelStart;
  if IDE <> nil then IDE.ShowStatus('Searching for: ');
end;

{ the text searched for from FromPos on; the match is selected }
function TEditorPage.IncSearchFind(FromPos: Integer): Boolean;
var
  OldA, OldC: Integer;
begin
  OldA := FEditor.SelStart;
  OldC := FEditor.SelEnd;
  FEditor.GotoPos(FromPos);
  Result := FEditor.FindNext(FIncText, False, False, False, True, False);
  if not Result then FEditor.SetSel(OldA, OldC)
  else FEditor.MarkMatches(FIncText, False, False, False);
end;

procedure TEditorPage.EndIncSearch;
begin
  FIncSearch := False;
  FIncText := '';
  if IDE <> nil then IDE.ShowStatus('');
end;

procedure TEditorPage.EditorMarginClick(Sender: TObject; Margin, Line: Integer; Shift: TShiftState);
begin
  if (Margin in [MARGIN_NUMBERS, MARGIN_SYMBOLS]) and (IDE <> nil) then
    IDE.ToggleBreakpoint(Self, Line + 1);
end;

procedure TEditorPage.EditorDwellStart(Sender: TObject; Position, X, Y: Integer);
var
  S, E, K, ES, EE: Integer;
  W, Expr, Hint: string;
  V: TDbgVar;
  Lines: TTipLines;
begin
  if (Position < 0) or (IDE = nil) or not FEditor.Shown then Exit;
  if (CompletionPopup <> nil) and CompletionPopup.Active then Exit;
  if (ParamHint <> nil) and ParamHint.Showing then Exit;
  W := '';
  S := Position;
  E := Position;
  { while debugging: value of the expression under the mouse - the selection, else the designator
    the word or the '^' under it ends (P^.Field, Items[I].Name, P^; TFoo(Sender).Caption: the
    tip's evaluation makes no calls, so parentheses are taken too) }
  if IsPascal and not FEditor.IsCommentOrString(Position) then W := FEditor.DesignatorAt(Position, True, S, E);
  if W <> '' then
  begin
    if (FEditor.SelEnd > FEditor.SelStart) and (Position >= FEditor.SelStart) and (Position <= FEditor.SelEnd) then
      W := FEditor.SelText;
    { Code Insight: Tooltip expression evaluation. The debugger reads and writes ANSI (the IDE's
      text); the tip shows the IDE's text too }
    Expr := EditorToAnsi(W, Encoding);
    { the value shown for this text already stays, with the items opened in it }
    if (ValueTip <> nil) and ValueTip.TipShown and (ValueTip.Source = FEditor) and (ValueTip.Expr = Expr) then Exit;
    if EditorOptions.TooltipEval and (ValueTip <> nil) and IDE.EvaluateForTip(Expr, V) then
    begin
      HideTips(False);
      ValueTip.ShowValue(V, FEditor.ScreenTextRect(S, E), FEditor.ScreenTextRect(S, S), FEditor,
        IDE.ChildrenForTip);
      Exit;
    end;
  end;
  { a value shown stays while the pointer is on it or on its text, also when it rests on the way
    between them - it goes by itself once the pointer has left them (TSdValueTip) }
  if (ValueTip <> nil) and ValueTip.TipShown and (ValueTip.Source = FEditor) then Exit;
  HideTips(False);
  if CodeTip = nil then Exit;
  { Tooltip symbol insight: an expert's code insight manager for the file (the Open Tools API)
    shows its own hint }
  if EditorOptions.TooltipDecl and IDE.CIInvoke(Self, #3, Position) then Exit;
  { Error Insight: the message of the error under the pointer, at the error }
  Lines := nil;
  K := -1;
  if EditorOptions.ErrorInsight then K := FEditor.ErrorAt(Position, ES, EE);
  if (K >= 0) and (K < FErrorCount) then
  begin
    Lines := ErrorTipLines([EditorToAnsi(FErrors[K].Msg, Encoding)]);
    S := ES;
  end;
  { ... and D7 Studio's own symbol insight: the declaration and its place (below the error's) }
  if EditorOptions.TooltipDecl and (W <> '') and (IDE.CodeInsight <> nil) and
    IDE.CodeInsight.GetHint(FFileName, GetSource, Position, Hint) and (Hint <> '') then
    AppendTipLines(Lines, DeclTipLines(EditorToAnsi(Hint, Encoding)));
  if Lines <> nil then CodeTip.ShowLines(Lines, FEditor.ScreenTextRect(S, S), FEditor);
end;

{ the mouse moved, or a key was pressed: the code tip goes. The value tip stays while the pointer is
  on it or on its text (it watches that itself) and goes with a key (EditorKeyDown) }
procedure TEditorPage.EditorDwellEnd(Sender: TObject);
begin
  HideTips(False);
end;

procedure TEditorPage.HideTips(Value: Boolean);
begin
  if (CodeTip <> nil) and CodeTip.TipShown and (CodeTip.Source = FEditor) then CodeTip.HideTip;
  if Value and (ValueTip <> nil) and ValueTip.TipShown and (ValueTip.Source = FEditor) then ValueTip.HideTip;
end;

procedure TEditorPage.EditorFocusChange(Sender: TObject);
begin
  if not FEditor.Focused then CloseCodePopups;
end;

procedure TEditorPage.EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) and (IDE <> nil) then
    IDE.EditorContextMenu(Self, FEditor.ClientToScreen(Point(X, Y)));
end;

initialization
  HistoryTextOf := HistoryText;
end.
