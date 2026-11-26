{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaModules;

{ D7 Studio - the modules of the Open Tools API: the open files, the project and
  the project group as Delphi 7's IOTAModule, with their editors.

  * A module is a file the IDE has open: a page (a unit with its form, a text file), a project of
    the group, the group itself. TSdOtaModuleManager (OtaModules) makes one object per file when
    an expert asks, and keeps it while the file is open: the notifiers an expert registers stay
    with it, and are told Destroyed when the file closes. A page that shows a form as text is no
    module of its own (its unit is).
  * Editors and views are made when asked for and hold their module (the module holds none of
    them: no reference cycle); what has to last - the notifiers of an editor, the saved
    positions and the marked block, a line tracker - lives in the module.
  * The source editor works on the page's Scintilla editor; a file that is not open is read
    from the IDE's text of it (OtaHost.SourceOf) and opened, hidden, for writing. Readers and
    writers see the buffer's bytes (SdOtaCore); the string methods of IOTAEditPosition and
    IOTAEditBlock take and give the IDE's strings and convert.
  * The form editor works on the page's TFormDesigner (made when needed), its components through
    IOTAComponent - published properties by TypInfo.
  * A project's resource file is IOTAProjectResource: the 32-bit .res read into entries, written
    back when it changed (each change through the API, and before a compile). }

interface

uses
  { ActiveX before TypInfo: both declare TTypeKind, the API means TypInfo's }
  Windows, ActiveX, SysUtils, Classes, Controls, Forms, TypInfo, ComCtrls, Variants, ToolsAPI,
  DesignIntf, SdOtaCore, SdSciEdit, SdEditorPage, SdProject, SdProjectGroup, SdFormDesigner, SdFileNames;

type
  TSdOtaModule = class;

  { our editors and views tell their file: SameView, buffers compared }
  ISdOtaFile = interface
    ['{5A0C7B21-6D3E-4F8A-9B2C-1E4D7F6A8B31}']
    function OtaFileName: string;
  end;

  { the saved state of a file's editing: what lives longer than one IOTAEditPosition / Block (the
    block itself is the editor's: TSciEdit's buffer block) }
  TSdOtaEditState = class
  public
    Positions: TList;            // Save / Restore of IOTAEditPosition: row and column, two items each
    Blocks: TList;               // Save / Restore of IOTAEditBlock: the blocks saved (TSdOtaSavedBlock)
    LastEdit: TOTAEditPos;       // where the last change of the text was
    ChangedAt: TDateTime;        // when (0: not since the module was made or saved)
    constructor Create;
    destructor Destroy; override;
  end;

  TSdOtaModule = class(TInterfacedObject, IOTAModule40, IOTAModule50, IOTAModule, IOTAModuleData,
    IOTAAdditionalModuleFiles)
  private
    FFileName: string;
    FNotifiers: TSdNotifierList;        // IOTAModuleNotifier / IOTANotifier
    FSourceNotifiers: TSdNotifierList;  // its source editor's: IOTANotifier / IOTAEditorNotifier
    FFormNotifiers: TSdNotifierList;    // its form editor's: IOTANotifier / IOTAFormNotifier
    FTracker: IOTAEditLineTracker;      // made when asked for
    FTrackerObj: TObject;               // ... the object behind it (TSdOtaLineTracker)
    FState: TSdOtaEditState;
    FAdditional: TStringList;           // its additional files (IOTAAdditionalModuleFiles)
    FEditorNames: TStringList;          // the files of its source editors (Objects: TSdOtaSourceEditor) ...
    FEditorRefs: TInterfaceList;        // ... and their references, in the same order
    FFormEditorRef: IOTAFormEditor;     // its form editor, made when first asked for
    FForgotten: Boolean;                // the module was forgotten: no editor is kept any more
    FRealKey: string;                   // the manager's name of its file that FRealName is of ...
    FRealName: WideString;              // ... its real name (TSdOtaModuleManager.KnownName)
    function EditorObject(const AFileName: string; out Ref: IOTASourceEditor): TObject;
  protected
    { the projects that own the file (TSdProject) in the group's order: every loaded project whose
      unit it is (Delphi's TDocModule owner list, shared by the projects) }
    procedure GetOwners(L: TList); virtual;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function Page: TEditorPage;
    function HasForm: Boolean;
    function FormFileName: string;
    function SourceEditor: IOTASourceEditor; virtual;
    function FormEditor: IOTAFormEditor;
    { The source editor of one of its files - the same object each time while the module is
      known, as Delphi's buffers live as long as their file is open: experts keep them without
      counting references (GExperts). EditorsGone lets them go when the module is forgotten
      (editor and module refer to each other); EditorsRenamed follows a rename. }
    function EditorOf(const AFileName: string): IOTASourceEditor;
    function ViewOf(const AFileName: string): IOTAEditView;
    procedure EditorsGone;
    procedure EditorsRenamed(const OldFileName, NewFileName: string);
    function Tracker: IOTAEditLineTracker;
    procedure DropModule(Module: HMODULE);
    (* the additional files of a unit, Delphi's: those its creator made (AddAdditionalFile) and
       those its text names - after the directive {$R *.dfm} (or *.xfm) each comment {*.ext}
       names the file of the unit's name with that extension. Scanned when the module is made. *)
    procedure ScanAdditionalFiles;
    procedure AddAdditionalFile(const AFileName: string);
    { the page of a file of the module for its source editor, opened (shown: Activate) when it is not }
    function OpenEditorPage(const AFileName: string; Activate: Boolean): TEditorPage; virtual;
    { the text of a file of the module that is not open (its source editor's reader); raises when it
      cannot be read }
    function ClosedFileText(const AFileName: string): string; virtual;
    { IOTAModuleData: a unit with a form - its page has one, or a form file is next to it }
    function HasObjects: Boolean; virtual;
    { IOTAAdditionalModuleFiles: their source editors, of the unit's module }
    function GetAdditionalModuleFileCount: Integer; virtual;
    function GetAdditionalModuleFileEditor(Index: Integer): IOTAEditor; virtual;
    property FileName: string read FFileName write FFileName;
    property Notifiers: TSdNotifierList read FNotifiers;
    property SourceNotifiers: TSdNotifierList read FSourceNotifiers;
    property FormNotifiers: TSdNotifierList read FFormNotifiers;
    property State: TSdOtaEditState read FState;
    { IOTAModule40 }
    function AddNotifier(const ANotifier: IOTAModuleNotifier): Integer;
    procedure AddToInterface;
    function Close: Boolean; virtual;
    function GetFileName: string;
    function GetFileSystem: string;
    function GetModuleFileCount: Integer; virtual;
    function GetModuleFileEditor(Index: Integer): IOTAEditor; virtual;
    function GetOwnerCount: Integer;
    function GetOwner(Index: Integer): IOTAProject;
    function HasCoClasses: Boolean;
    procedure RemoveNotifier(Index: Integer);
    function Save(ChangeName, ForceSave: Boolean): Boolean; virtual;
    procedure SetFileName(const AFileName: string); virtual;
    procedure SetFileSystem(const AFileSystem: string);
    { IOTAModule50 }
    function CloseModule(ForceClosed: Boolean): Boolean; virtual;
    { IOTAModule }
    function GetCurrentEditor: IOTAEditor; virtual;
    function GetOwnerModuleCount: Integer; virtual;
    function GetOwnerModule(Index: Integer): IOTAModule; virtual;
    procedure MarkModified; virtual;
  end;

  TSdOtaProject = class(TSdOtaModule, IOTAProject40, IOTAProject, IOTAProjectBuilder40, IOTAProjectBuilder)
  private
    { one for the project, made when first asked for: an expert's Keys list and the modified
      state stay what they were at the next ProjectOptions }
    FOptions: IOTAProjectOptions;
    FOptionsObj: TObject;           // ... the object behind it (TSdOtaProjectOptions: it follows a rename)
    FShouldBuild: Boolean;          // an expert changed its options since the last build
  protected
    procedure GetOwners(L: TList); override;
  public
    function Project: TSdProject;
    function IsActive: Boolean;
    function CloseModule(ForceClosed: Boolean): Boolean; override;
    function GetModuleFileCount: Integer; override;
    function GetModuleFileEditor(Index: Integer): IOTAEditor; override;
    function GetOwnerModuleCount: Integer; override;
    function GetOwnerModule(Index: Integer): IOTAModule; override;
    function Save(ChangeName, ForceSave: Boolean): Boolean; override;
    procedure SetFileName(const AFileName: string); override;
    { IOTAProject40 }
    function GetModuleCount: Integer;
    function GetModule(Index: Integer): IOTAModuleInfo;
    function GetProjectOptions: IOTAProjectOptions;
    function GetProjectBuilder: IOTAProjectBuilder;
    { IOTAProject }
    procedure AddFile(const AFileName: string; IsUnitOrForm: Boolean);
    procedure RemoveFile(const AFileName: string);
    { IOTAProjectBuilder40 / IOTAProjectBuilder }
    function GetShouldBuild: Boolean;
    function BuildProject(CompileMode: TOTACompileMode; Wait: Boolean): Boolean; overload;
    function BuildProject(CompileMode: TOTACompileMode; Wait, ClearMessages: Boolean): Boolean; overload;
  end;

  TSdOtaProjectGroup = class(TSdOtaModule, IOTAProjectGroup)
  public
    function CloseModule(ForceClosed: Boolean): Boolean; override;
    function GetOwnerModuleCount: Integer; override;
    function Save(ChangeName, ForceSave: Boolean): Boolean; override;
    { IOTAProjectGroup }
    procedure AddNewProject;
    procedure AddExistingProject;
    function GetActiveProject: IOTAProject;
    function GetProjectCount: Integer;
    function GetProject(Index: Integer): IOTAProject;
    procedure RemoveProject(const AProject: IOTAProject);
    procedure SetActiveProject(const AProject: IOTAProject);
  end;

  { the library of the Type Library view: as Delphi 7's
    (measured), one editor, the source editor of the library's unit in the library's folder
    (Library_TLB.pas) - its "buffer of the generated unit": the importer's text, not modified, made
    a page when an expert reads or shows it (a page of that file open already is the editor's) -,
    and no current editor; nothing to save (the view shows the library only); CloseModule empties
    the view. Its owners are the loaded projects whose library it is (<project>.tlb). }
  TSdOtaTypeLibModule = class(TSdOtaModule, IOTATypeLibModule)
  private
    function UnitFile: string;
    function IsUnit(const AFileName: string): Boolean;
  protected
    procedure GetOwners(L: TList); override;
  public
    function OpenEditorPage(const AFileName: string; Activate: Boolean): TEditorPage; override;
    function ClosedFileText(const AFileName: string): string; override;
    function CloseModule(ForceClosed: Boolean): Boolean; override;
    function GetModuleFileCount: Integer; override;
    function GetModuleFileEditor(Index: Integer): IOTAEditor; override;
    function GetCurrentEditor: IOTAEditor; override;
    function Save(ChangeName, ForceSave: Boolean): Boolean; override;
    procedure SetFileName(const AFileName: string); override;
    procedure MarkModified; override;
    function GetAdditionalModuleFileCount: Integer; override;
  end;

  { the .res file a project resource holds, as it would be written (also a copy's, which is never
    written: ProjectResourceCopy) }
  ISdResFile = interface
    ['{8E3B5C17-2A4F-4D69-B0E8-6F1C9A2D7E43}']
    function ResFileBytes: string;
    { the changes between them (several entries of one command) are written once, at the last
      EndUpdate - not at each entry }
    procedure BeginUpdate;
    procedure EndUpdate;
  end;

  { the IDE's modules (OtaModules) and the events of the pages for their notifiers }
  TSdOtaModuleManager = class
  private
    FNames: TStringList;            // the modules' files; Objects: the TSdOtaModule
    FRefs: TInterfaceList;          // ... their references, in the same order
    FResNames: TStringList;         // the project resources' files
    FResRefs: TInterfaceList;
    FSearch: IOTAReplaceOptions;    // the search and replace options of every edit position
    FDesignPage: TEditorPage;       // the page whose designer was activated last (compared only)
    FDesignNotes: IDesignNotification;   // the designers' insertions, deletions and changes
    function KindOf(const FileName: string): TClass;
    function KnownName(const FileName: string; ModulesOnly: Boolean): string;
    function ModuleOfDesigner(const D: IDesigner): TSdOtaModule;
    procedure DesignShown(Page: TEditorPage);
    procedure ComponentCameOrWent(const D: IDesigner; Item: TPersistent; Came: Boolean);
    procedure FlushResource(Index: Integer);
    procedure DropResource(const ProjectFile: string);
  public
    constructor Create;
    destructor Destroy; override;
    { the module of a file (Make: made when the file is open in the IDE); nil: none }
    function Find(const FileName: string; Make: Boolean = True): TSdOtaModule;
    function ModuleIntf(const FileName: string): IOTAModule;
    { the project group's module name: its file, or its name when it has none yet }
    function GroupKey: string;
    { the project group's module: a module while the IDE runs, with projects or none (Delphi's
      workspace, ProjectGroup1 when empty) }
    function GroupModule: IOTAModule;
    { the open modules in Delphi's order: the group, its projects, the packages beside it, the open
      files }
    procedure List(L: TInterfaceList);
    function CurrentModule: IOTAModule;
    function FindFormModule(const FormName: string): IOTAModule;
    function ProjectResource(const ProjectFile: string): IOTAProjectResource;
    { a copy of the entries of a project's resource that is never written - the file's own
      entries are not touched by its changes; ISdResFile gives the .res it holds (a compile takes
      the unsaved resource pages through it, SdResPage) }
    function ProjectResourceCopy(const ProjectFile: string): IOTAProjectResource;
    { the resources of a project written when they changed (before a compile, when it closes) }
    procedure FlushResources;
    function SearchOptions: IOTAReplaceOptions;
    { a file closes: its module's notifiers are told, the module forgotten }
    procedure Forget(const FileName: string);
    { the group closes or empties: every project's module and the group's go (their resources
      written) - not those of the packages open beside the group, which stay open; the next group
      module is made when it is asked for (GroupModule) }
    procedure ForgetProjects;
    { a project leaves the group or is closed in it, a package beside the group closes: its
      resource written and dropped, its module forgotten (its notifiers told Destroyed) - the other
      projects' modules stay }
    procedure ForgetProject(const ProjectFile: string);
    procedure DropModule(Module: HMODULE);
    { the events of the pages }
    procedure PageOpened(Page: TEditorPage);
    procedure PageClosing(Page: TEditorPage);
    procedure ModuleClosed(const FileName: string);
    procedure PageActivated(Page: TEditorPage);
    procedure PageEdited(Page: TEditorPage; Position, LinesAdded: Integer);
    procedure PageSaving(Page: TEditorPage);
    procedure PageSaved(Page: TEditorPage);
    procedure PageRenamed(Page: TEditorPage; const OldFileName: string);
    { a file under another name (a project's: Save Project As), open or not: its module follows,
      its notifiers hear ModuleRenamed }
    procedure Renamed(const OldFileName, NewFileName: string);
    procedure ComponentRenamed(Page: TEditorPage; const OldName, NewName: string);
    { the active page shows another view (F12: its designer, IOTAFormNotifier.FormActivated) }
    procedure PageViewChanged(Page: TEditorPage);
    { a compile streams the forms out: IOTAFormNotifier.FormSaving (no BeforeSave) }
    procedure FormsStreamed;
    { the designers report to the forms' notifiers from the first notifier on }
    procedure NeedDesignNotes;
    { the events of the designers (IDesignNotification) }
    procedure ItemInserted(const D: IDesigner; Item: TPersistent);
    procedure ItemDeleted(const D: IDesigner; Item: TPersistent);
    procedure ItemsModified(const D: IDesigner);
  end;

var
  OtaModules: TSdOtaModuleManager;

{ the source editor of a page (its view: GetEditView(0)); nil without a page }
function OtaPageBuffer(Page: TEditorPage): IOTAEditBuffer;
{ Delphi's syntax element of the text at an editor's offset (atComment, atIdentifier, atString
  ...; atWhiteSpace for blanks and the line's end) }
function OtaAttributeAt(Ed: TSciEdit; P: Integer): Integer;
{ the editor options of a file type (Borland.EditOptions.Pascal ...) / of a file }
function OtaEditOptionsIndex(Index: Integer): IOTAEditOptions;
function OtaEditOptionsCount: Integer;
function OtaEditOptionsOf(const FileName: string): IOTAEditOptions;
{ Delphi's names of the project options (IOTAProjectOptions) }
function OtaProjectOptionNames: TOTAOptionNameArray;

implementation

uses
  SdSciDefs, SdSciLexDefs, SdEditorOptions, SdEncoding, SdDesignHost, SdFormSrc,
  SdPasLex, SdPageFileSystem, SdOtaHighlight, SdOtaSpeedSettings, SdKeymaps, SdOtaEditWindow, SdResImage,
  SdOtaServices, Dialogs;

var
  { the last search or replace of an edit position was a replace (RepeatLastSearchOrReplace) -
    for every position object: each View.Position is a new one }
  LastWasReplace: Boolean;

type
  { a block IOTAEditBlock.Save kept: values - a stream block's ends as character positions (Line 0:
    none), a column block's corners -, as Delphi's TBlockPreserver: later edits do not move them }
  TSdOtaSavedBlock = class
  public
    Mode: TSciBlockMode;
    A, B: TOTACharPos;
    Rows: TRect;
  end;

  { the source editor of a module's source file }
  TSdOtaSourceEditor = class(TInterfacedObject, IOTAEditor, IOTASourceEditor, IOTAEditBuffer60,
    IOTAEditBuffer, ISdOtaFile)
  private
    FModule: TSdOtaModule;
    FModuleRef: IOTAModule;
    FFileName: string;
    FViewRef: IOTAEditView;              // its view, made when first asked for (kept with the editor)
    function BlockEnd(First: Boolean): TOTACharPos;
    procedure SetBlockEnd(First: Boolean; const Value: TOTACharPos);
  public
    constructor Create(AModule: TSdOtaModule; const AFileName: string);
    { the edit view of the buffer: the same object each time, as Delphi's view lives while its
      window does (experts keep it without counting references); ViewGone lets it go with the
      module (view and buffer refer to each other) }
    function View: IOTAEditView;
    procedure ViewGone;
    function Page: TEditorPage;
    function Ed: TSciEdit;               // nil: the file is not open
    function NeedEd: TSciEdit;           // opened (hidden) when it is not
    property Module: TSdOtaModule read FModule;
    { ISdOtaFile }
    function OtaFileName: string;
    { IOTAEditor }
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    function GetFileName: string;
    function GetModified: Boolean;
    function GetModule: IOTAModule;
    function MarkModified: Boolean;
    procedure RemoveNotifier(Index: Integer);
    procedure Show;
    { IOTASourceEditor }
    function CreateReader: IOTAEditReader;
    function CreateWriter: IOTAEditWriter;
    function CreateUndoableWriter: IOTAEditWriter;
    function GetEditViewCount: Integer;
    function GetEditView(Index: Integer): IOTAEditView;
    function GetLinesInBuffer: Longint;
    function SetSyntaxHighlighter(SyntaxHighlighter: TOTASyntaxHighlighter): TOTASyntaxHighlighter;
    function GetBlockAfter: TOTACharPos;
    function GetBlockStart: TOTACharPos;
    function GetBlockType: TOTABlockType;
    function GetBlockVisible: Boolean;
    procedure SetBlockAfter(const Value: TOTACharPos);
    procedure SetBlockStart(const Value: TOTACharPos);
    procedure SetBlockType(Value: TOTABlockType);
    procedure SetBlockVisible(Value: Boolean);
    { IOTAEditBuffer60 }
    procedure ClearUndo;
    function GetBufferOptions: IOTABufferOptions;
    function GetCurrentDate: TDateTime;
    function GetEditBlock: IOTAEditBlock;
    function GetEditLineTracker: IOTAEditLineTracker;
    function GetEditPosition: IOTAEditPosition;
    function GetInitialDate: TDateTime;
    function GetIsModified: Boolean;
    function GetIsReadOnly: Boolean;
    function GetTopView: IOTAEditView;
    function Print: Boolean;
    function Redo: Boolean;
    procedure SetIsReadOnly(Value: Boolean);
    function Undo: Boolean;
    { IOTAEditBuffer }
    function GetEditOptions: IOTAEditOptions;
  end;

  TSdOtaEditWindow = class(TInterfacedObject, INTAEditWindow)
  public
    function GetForm: TCustomForm;
    function GetStatusBar: TStatusBar;
  end;

  TSdOtaEditView = class(TInterfacedObject, IOTAEditView40, IOTAEditView, IOTAEditActions60,
    IOTAEditActions, ISdOtaFile)
  private
    FBuffer: TSdOtaSourceEditor;
    FBufferRef: IOTAEditBuffer;
    function Ed: TSciEdit;
    function Page: TEditorPage;
    function CharWidth: Integer;
    procedure Act(const Name: string);
    procedure OtherPage(Delta: Integer);
    procedure CursorCommand(Msg: Cardinal);
  public
    constructor Create(ABuffer: TSdOtaSourceEditor);
    property Buffer: TSdOtaSourceEditor read FBuffer;
    function OtaFileName: string;
    { IOTAEditView40 }
    function GetCursorPos: TOTAEditPos;
    procedure SetCursorPos(const Value: TOTAEditPos);
    function GetTopPos: TOTAEditPos;
    procedure SetTopPos(const Value: TOTAEditPos);
    function GetViewSize: TSize;
    function PosToCharPos(Pos: Longint): TOTACharPos;
    function CharPosToPos(CharPos: TOTACharPos): Longint;
    procedure ConvertPos(EdPosToCharPos: Boolean; var EditPos: TOTAEditPos; var CharPos: TOTACharPos);
    procedure GetAttributeAtPos(const EdPos: TOTAEditPos; IncludeMargin: Boolean;
      var Element, LineFlag: Integer);
    function SameView(EditView: IOTAEditView): Boolean;
    { IOTAEditView }
    function BookmarkGoto(BookmarkID: Integer): Boolean;
    function BookmarkRecord(BookmarkID: Integer): Boolean;
    function BookmarkToggle(BookmarkID: Integer): Boolean;
    procedure Center(Row, Col: Integer);
    function GetBlock: IOTAEditBlock;
    function GetBookmarkPos(BookmarkID: Integer): TOTACharPos;
    function GetBottomRow: Integer;
    function GetBuffer: IOTAEditBuffer;
    function GetEditWindow: INTAEditWindow;
    function GetLastEditColumn: Integer;
    function GetLastEditRow: Integer;
    function GetLeftColumn: Integer;
    function GetPosition: IOTAEditPosition;
    function GetRightColumn: Integer;
    function GetTopRow: Integer;
    procedure MoveCursorToView;
    procedure MoveViewToCursor;
    procedure PageDown;
    procedure PageUp;
    procedure Paint;
    function Scroll(DeltaRow: Integer; DeltaCol: Integer): Integer;
    procedure SetTopLeft(TopRow, LeftCol: Integer);
    procedure SetTempMsg(const Msg: string);
    { IOTAEditActions60 }
    procedure AddWatch;
    procedure AddWatchAtCursor;
    procedure BrowseSymbolAtCursor;
    procedure ClassComplete;
    procedure ClassNavigate(Reserved: TClassNavigateStyle);
    procedure ClosePage;
    procedure CodeTemplate;
    procedure CodeCompletion(Style: TCodeCompleteStyle);
    procedure EvaluateModify;
    procedure HelpKeyword;
    procedure IncrementalSearch;
    procedure InsertCompilerOptions;
    procedure InsertNewGUID;
    procedure InspectAtCursor;
    procedure CompileProject;
    procedure NextError;
    procedure NextPage;
    procedure OpenFile;
    procedure OpenFileAtCursor;
    procedure PriorError;
    procedure PriorPage;
    procedure ProgramReset;
    procedure RunProgram;
    procedure RunToCursor;
    procedure SaveAll;
    procedure Save;
    procedure SaveAs;
    procedure StepOver;
    procedure SwapSourceFormView;
    procedure SwapCPPHeader;
    procedure ToggleFormUnit;
    procedure TraceInto;
    procedure TraceToSource;
    procedure ViewExplorer;
    procedure ViewForms;
    procedure ViewObjectInspector;
    procedure ViewUnits;
    procedure WindowList;
    procedure ZoomWindow;
    { IOTAEditActions }
    procedure NextBufferView;
    procedure PreviousBufferView;
  end;

  TSdOtaEditPosition = class(TInterfacedObject, IOTAEditPosition)
  private
    FView: TSdOtaEditView;
    FViewRef: IOTAEditView;
    function Ed: TSciEdit;
    function Page: TEditorPage;
    function Caret: Integer;
    procedure CaretTo(E: TSciEdit; P: Integer);
    function CharacterOf(E: TSciEdit): Char;
    function ColumnOf(E: TSciEdit): Integer;
    function KernelMove(P: Integer): Boolean;
    function CharClass(C: Char): Integer;
    function SearchRange(E: TSciEdit; const Pattern: string; Selected: Boolean; var ErrorCode, Lo,
      Hi: Integer): Boolean;
    function FindMatch(const Pattern: string; CaseSensitive, RegExp, Selected, FromCursor, Forward: Boolean;
      var ErrorCode, MatchStart, MatchEnd: Integer): Boolean;
    function SearchWithOptions(FromCursor: Boolean): Boolean;
    function ReplaceWithOptions(FromCursor: Boolean): Integer;
    function SetSearchOptions(const Pattern: string; CaseSensitive, RegularExpression, WholeFile: Boolean;
      Direction: TSearchDirection): IOTAReplaceOptions;
    function Find(const Pattern: string; CaseSensitive, RegExp, Selected, FromCursor, Forward: Boolean;
      var ErrorCode: Integer): Boolean;
    function DoReplace(const Pattern, ReplaceText: string; CaseSensitive, RegExp, Selected, FromCursor: Boolean;
      Direction: TSearchDirection; All: Boolean; var ErrorCode: Integer): Integer;
    function Rip(const Valid: TSysCharSet; RipFlags: Integer): string;
    function InsertEditorText(const S: string): Integer;
    procedure MarkInserted(P: Integer);
  public
    constructor Create(AView: TSdOtaEditView);
    procedure Align(Magnitude: Integer);
    function BackspaceDelete(HowMany: Integer): Boolean;
    function DeleteChars(HowMany: Integer): Boolean;
    function IOTAEditPosition.Delete = DeleteChars;
    function DistanceToTab(Direction: TSearchDirection): Integer;
    function GetCharacter: Char;
    function GetColumn: Integer;
    function GetIsSpecialCharacter: Boolean;
    function GetIsWhitespace: Boolean;
    function GetIsWordCharacter: Boolean;
    function GetLastRow: Integer;
    function GetReplaceOptions: IOTAReplaceOptions;
    function GetRow: Integer;
    function GetSearchErrorString(ErrorCode: Integer): string;
    function GetSearchOptions: IOTASearchOptions;
    function GotoLine(LineNumber: Integer): Boolean;
    procedure InsertBlock(const Block: IOTAEditBlock);
    procedure InsertCharacter(Character: Char);
    procedure InsertFile(const FileName: string);
    procedure InsertText(const Text: string);
    function MoveTo(Row, Col: Integer): Boolean;
    function IOTAEditPosition.Move = MoveTo;
    function MoveBOL: Boolean;
    function MoveCursor(MoveMask: TMoveCursorMasks): Boolean;
    function MoveEOF: Boolean;
    function MoveEOL: Boolean;
    function MoveReal(Row, Col: Integer): Boolean;
    function MoveRelative(Row, Col: Integer): Boolean;
    procedure Paste;
    function ReadChars(NumberOfCharacters: Integer): string;
    function IOTAEditPosition.Read = ReadChars;
    function RepeatLastSearchOrReplace: Boolean;
    function Replace(const Pattern, ReplaceText: string; CaseSensitive, RegularExpression,
      WholeFile: Boolean; Direction: TSearchDirection; var ErrorCode: Integer): Integer; overload;
    function Replace: Integer; overload;
    function ReplaceAgain: Integer;
    procedure Restore;
    function RipText(const ValidChars: TSysCharSet; RipFlags: Integer): string; overload;
    function RipText(const ValidChars: string; RipFlags: Integer): string; overload;
    procedure Save;
    function Search(const Pattern: string; CaseSensitive, RegularExpression, WholeFile: Boolean;
      Direction: TSearchDirection; var ErrorCode: Integer): Boolean; overload;
    function Search: Boolean; overload;
    function SearchAgain: Boolean;
    procedure Tab(Magnitude: Integer);
  end;

  TSdOtaEditBlock = class(TInterfacedObject, IOTAEditBlock)
  private
    FView: TSdOtaEditView;
    FViewRef: IOTAEditView;
    function Ed: TSciEdit;
    function State: TSdOtaEditState;
    function Corner(Last: Boolean): TOTACharPos;
    function ExtendPage(Down: Boolean): Boolean;
  public
    constructor Create(AView: TSdOtaEditView);
    procedure BeginBlock;
    procedure BlockCopy(Append: Boolean);
    procedure IOTAEditBlock.Copy = BlockCopy;
    procedure Cut(Append: Boolean);
    function BlockDelete: Boolean;
    function IOTAEditBlock.Delete = BlockDelete;
    procedure EndBlock;
    function Extend(NewRow, NewCol: Integer): Boolean;
    function ExtendPageUp: Boolean;
    function ExtendPageDown: Boolean;
    function ExtendReal(NewRow, NewCol: Integer): Boolean;
    function ExtendRelative(DeltaRow, DeltaCol: Integer): Boolean;
    function GetEndingColumn: Integer;
    function GetEndingRow: Integer;
    function GetIsValid: Boolean;
    function GetSize: Integer;
    function GetStartingColumn: Integer;
    function GetStartingRow: Integer;
    function GetStyle: TOTABlockType;
    function GetText: string;
    function GetVisible: Boolean;
    procedure Indent(Magnitude: Integer);
    procedure BlockLowerCase;
    procedure IOTAEditBlock.LowerCase = BlockLowerCase;
    function Print: Boolean;
    procedure Reset;
    procedure Restore;
    procedure Save;
    function SaveToFile(const FileName: string): Boolean;
    procedure SetStyle(Value: TOTABlockType);
    procedure SetVisible(Value: Boolean);
    procedure ToggleCase;
    procedure BlockUpperCase;
    procedure IOTAEditBlock.UpperCase = BlockUpperCase;
  end;

  TSdOtaReader = class(TInterfacedObject, IOTAEditReader)
  private
    FText: string;
  public
    constructor Create(const AText: string);
    function GetText(Position: Longint; Buffer: PChar; Count: Longint): Longint;
  end;

  TSdOtaWriter = class(TInterfacedObject, IOTAEditWriter)
  private
    FBufferRef: IOTAEditBuffer;
    FBuffer: TSdOtaSourceEditor;
    FEd: TSciEdit;                   // the page's editor when the writer was made
    FOrig, FDelta, FOrigLen: Integer;
    FUndoable, FChanged: Boolean;
    FUndoBefore, FCaretBefore: Integer;  // the undo history's current action and the caret before the write
    function Ed: TSciEdit;
  public
    constructor Create(ABuffer: TSdOtaSourceEditor; Undoable: Boolean);
    destructor Destroy; override;
    procedure CopyTo(Pos: Longint);
    procedure DeleteTo(Pos: Longint);
    procedure InsertText(Text: PChar);
    procedure IOTAEditWriter.Insert = InsertText;
    function Position: Longint;
    function GetCurrentPos: TOTACharPos;
  end;

  TSdOtaSearchOptions = class(TInterfacedObject, IOTASearchOptions, IOTAReplaceOptions)
  private
    FCase, FFromCursor, FRegExp, FWholeFile, FWord, FPrompt, FAll: Boolean;
    FDirection: TSearchDirection;
    FText, FReplace: string;
  public
    function GetCaseSensitive: Boolean;
    function GetDirection: TSearchDirection;
    function GetFromCursor: Boolean;
    function GetRegularExpression: Boolean;
    function GetSearchText: string;
    function GetWholeFile: Boolean;
    function GetWordBoundary: Boolean;
    procedure SetCaseSensitive(Value: Boolean);
    procedure SetDirection(Value: TSearchDirection);
    procedure SetFromCursor(Value: Boolean);
    procedure SetRegularExpression(Value: Boolean);
    procedure SetSearchText(const Value: string);
    procedure SetWholeFile(Value: Boolean);
    procedure SetWordBoundary(Value: Boolean);
    function GetPromptOnReplace: Boolean;
    function GetReplaceAll: Boolean;
    function GetReplaceText: string;
    procedure SetPromptOnReplace(Value: Boolean);
    procedure SetReplaceAll(Value: Boolean);
    procedure SetReplaceText(const Value: string);
  end;

  { the options of a file type of Tools | Editor Options, kept by its ID }
  TSdOtaFileTypeOptions = class(TInterfacedObject)
  private
    FID: string;                       // the file type's ID: its index changes when a type goes
  protected
    function FT: Integer;
  public
    constructor Create(AIndex: Integer);
  end;

  { the options of a source file type (Tools | Editor Options | Source Options) and the general ones }
  TSdOtaBufferOptions = class(TSdOtaFileTypeOptions, IOTABufferOptions60, IOTABufferOptions)
  private
    procedure Changed;
  public
    function GetAutoIndent: Boolean;
    function GetBackspaceUnindents: Boolean;
    function GetCreateBackupFile: Boolean;
    function GetCursorThroughTabs: Boolean;
    function GetInsertMode: Boolean;
    function GetGroupUndo: Boolean;
    function GetKeepTrailingBlanks: Boolean;
    function GetLeftGutterWidth: Integer;
    function GetRightMargin: Integer;
    function GetOverwriteBlocks: Boolean;
    function GetPersistentBlocks: Boolean;
    function GetPreserveLineEnds: Boolean;
    function GetSmartTab: Boolean;
    function GetSyntaxHighlight: Boolean;
    function GetTabStops: string;
    function GetUndoAfterSave: Boolean;
    function GetUndoLimit: Integer;
    function GetUseTabCharacter: Boolean;
    procedure SetAutoIndent(Value: Boolean);
    procedure SetBackspaceUnindents(Value: Boolean);
    procedure SetCreateBackupFile(Value: Boolean);
    procedure SetCursorThroughTabs(Value: Boolean);
    procedure SetInsertMode(Value: Boolean);
    procedure SetGroupUndo(Value: Boolean);
    procedure SetKeepTrailingBlanks(Value: Boolean);
    procedure SetLeftGutterWidth(Value: Integer);
    procedure SetRightMargin(Value: Integer);
    procedure SetOverwriteBlocks(Value: Boolean);
    procedure SetPersistentBlocks(Value: Boolean);
    procedure SetPreserveLineEnds(Value: Boolean);
    procedure SetSmartTab(Value: Boolean);
    procedure SetSyntaxHighlight(Value: Boolean);
    procedure SetTabStops(const Value: string);
    procedure SetUndoAfterSave(Value: Boolean);
    procedure SetUndoLimit(Value: Integer);
    procedure SetUseTabCharacter(Value: Boolean);
    function GetShowSpace: Boolean;
    function GetShowTab: Boolean;
    procedure SetShowSpace(Value: Boolean);
    procedure SetShowTab(Value: Boolean);
  end;

  TSdOtaEditOptions = class(TSdOtaFileTypeOptions, IOTAEditOptions60, IOTAEditOptions)
  private
    FUpdating: Integer;
    procedure Changed;
  public
    function AddSpeedSetting(const SpeedSetting: IOTASpeedSetting): Integer;
    procedure BeginUpdate;
    procedure EndUpdate;
    function GetBlockIndent: Integer;
    function GetBufferOptions: IOTABufferOptions;
    function GetFontName: string;
    function GetFontSize: Integer;
    function GetForceCutCopyEnabled: Boolean;
    function GetSpeedSettingCount: Integer;
    function GetSpeedSetting(Index: Integer): IOTASpeedSetting;
    function GetSyntaxHighlightTypes(Index: TOTASyntaxHighlighter): string;
    function GetUseBriefCursorShapes: Boolean;
    function GetUseBriefRegularExpressions: Boolean;
    procedure RemoveSpeedSetting(Index: Integer);
    procedure SetBlockIndent(Value: Integer);
    procedure SetFontName(const Value: string);
    procedure SetFontSize(Value: Integer);
    procedure SetForceCutCopyEnabled(Value: Boolean);
    procedure SetSpeedSetting(const Name: string);
    procedure SetSyntaxHighlightTypes(Index: TOTASyntaxHighlighter; const Value: string);
    procedure SetUseBriefCursorShapes(Value: Boolean);
    procedure SetUseBriefRegularExpressions(Value: Boolean);
    function GetExtensions: string;
    function GetOptionsName: string;
    function GetOptionsIDString: string;
    function GetSyntaxHighlighter: IOTAHighlighter;
    function GetOptionsIndex: Integer;
    procedure SetExtensions(const Value: string);
    procedure SetOptionsName(const Value: string);
    procedure SetSyntaxHighlighter(const Value: IOTAHighlighter);
  end;

  { the lines an expert follows through the edits of a buffer }
  { the designers' insertions, deletions and changes for the forms' notifiers (the module manager,
    from its first form or module notifier on) }
  TSdOtaDesignNotes = class(TInterfacedObject, IDesignNotification)
  public
    procedure ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemsModified(const ADesigner: IDesigner);
    procedure SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
    procedure DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
    procedure DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
  end;

  TSdOtaLineTracker = class(TInterfacedObject, IOTAEditLineTracker)
  private
    FModule: TSdOtaModule;               // the module owns the tracker: no reference back
    FLines, FData: TList;
    FNotifiers: TSdNotifierList;
  public
    constructor Create(AModule: TSdOtaModule);
    destructor Destroy; override;
    procedure Edited(Line0, LinesAdded: Integer);
    function AddNotifier(const Notifier: IOTAEditLineNotifier): Integer;
    procedure AddLine(Line: Integer; Data: Integer);
    procedure DeleteLine(Index: Integer);
    procedure IOTAEditLineTracker.Delete = DeleteLine;
    function GetCount: Integer;
    function GetData(Index: Integer): Integer;
    function GetEditBuffer: IOTAEditBuffer;
    function GetLineNum(Index: Integer): Integer;
    function IndexOfLine(Line: Integer): Integer;
    function IndexOfData(Data: Integer): Integer;
    procedure RemoveNotifier(Index: Integer);
    procedure SetData(Index: Integer; Value: Integer);
    procedure SetLineNum(Index: Integer; Value: Integer);
  end;

  TSdOtaFormEditor = class(TInterfacedObject, IOTAEditor, IOTAFormEditor, INTAFormEditor, ISdOtaFile)
  private
    FModule: TSdOtaModule;
    FModuleRef: IOTAModule;
    function Designer: TFormDesigner;
    function Wrap(P: TPersistent): IOTAComponent;
  public
    constructor Create(AModule: TSdOtaModule);
    function OtaFileName: string;
    { IOTAEditor }
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    function GetFileName: string;
    function GetModified: Boolean;
    function GetModule: IOTAModule;
    function MarkModified: Boolean;
    procedure RemoveNotifier(Index: Integer);
    procedure Show;
    { IOTAFormEditor }
    function GetRootComponent: IOTAComponent;
    function FindComponent(const Name: string): IOTAComponent;
    function GetComponentFromHandle(ComponentHandle: TOTAHandle): IOTAComponent;
    function GetSelCount: Integer;
    function GetSelComponent(Index: Integer): IOTAComponent;
    function GetCreateParent: IOTAComponent;
    function CreateComponent(const Container: IOTAComponent; const TypeName: string;
      X, Y, W, H: Integer): IOTAComponent;
    procedure GetFormResource(const Stream: IStream);
    { INTAFormEditor }
    function GetFormDesigner: IDesigner;
    procedure NtaGetFormResource(Stream: TStream);
    procedure INTAFormEditor.GetFormResource = NtaGetFormResource;
  end;

  TSdOtaComponent = class(TInterfacedObject, IOTAComponent, INTAComponent)
  private
    FInstance: TPersistent;
    FDesigner: TFormDesigner;
    FProps: PPropList;                  // the properties Props lists (made once: nil not yet) ...
    FPropCount: Integer;                // ... and how many
    function HostOnly(const PropName: string): Boolean;
    function ModuleOfRoot: TComponent;
    function Target(P: PPropInfo): TObject;
    function Props: Integer;
    procedure FreeProps;
    function PropNamed(const Name: string): PPropInfo;
    function PropByIndex(Index: Integer): PPropInfo;
    function ReadProp(P: PPropInfo; var Value): Boolean;
    function WriteProp(P: PPropInfo; const Value): Boolean;
    function Wrap(P: TPersistent): IOTAComponent;
  public
    constructor Create(AInstance: TPersistent; ADesigner: TFormDesigner);
    destructor Destroy; override;
    function GetComponentType: string;
    function GetComponentHandle: TOTAHandle;
    function GetParent: IOTAComponent;
    function IsTControl: Boolean;
    function GetPropCount: Integer;
    function GetPropName(Index: Integer): string;
    function GetPropType(Index: Integer): TTypeKind;
    function GetPropTypeByName(const Name: string): TTypeKind;
    function GetPropValue(Index: Integer; var Value): Boolean;
    function GetPropValueByName(const Name: string; var Value): Boolean;
    function SetProp(Index: Integer; const Value): Boolean;
    function SetPropByName(const Name: string; const Value): Boolean;
    function GetChildren(Param: Pointer; Proc: TOTAGetChildCallback): Boolean;
    function GetControlCount: Integer;
    function GetControl(Index: Integer): IOTAComponent;
    function GetComponentCount: Integer;
    function GetComponent(Index: Integer): IOTAComponent;
    function Select(AddToSelection: Boolean): Boolean;
    function Focus(AddToSelection: Boolean): Boolean;
    function Delete: Boolean;
    { INTAComponent }
    function GetPersistent: TPersistent;
    function NtaGetComponent: TComponent;
    function INTAComponent.GetComponent = NtaGetComponent;
  end;

  TSdOtaModuleInfo = class(TInterfacedObject, IOTAModuleInfo50, IOTAModuleInfo)
  private
    FType: TOTAModuleType;
    FName, FFileName, FFormName, FDesignClass: string;
    FFormFile: string;                 // a form unit's .dfm, its class not looked at yet ('' done)
    procedure NeedFormClass;
  public
    constructor Create(AType: TOTAModuleType; const AName, AFileName, AFormName, ADesignClass: string);
    function GetModuleType: TOTAModuleType;
    function GetName: string;
    function GetFileName: string;
    function GetFormName: string;
    function GetDesignClass: string;
    procedure GetCoClasses(CoClasses: TStrings);
    function OpenModule: IOTAModule;
    function GetCustomId: string;
    procedure GetAdditionalFiles(Files: TStrings);
  end;

  TSdOtaProjectOptions = class(TInterfacedObject, IOTAOptions, IOTAProjectOptions40, IOTAProjectOptions)
  private
    FFileName: string;
    FKeys: TStringList;
    FModified: Boolean;
    function Project: TSdProject;
    procedure WriteKeys(P: TSdProject; L: TStrings);
    procedure KeysChanged(Sender: TObject);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    procedure EditOptions;
    function GetOptionValue(const ValueName: string): Variant;
    procedure SetOptionValue(const ValueName: string; const Value: Variant);
    function GetOptionNames: TOTAOptionNameArray;
    procedure SetModifiedState(State: Boolean);
    function GetModifiedState: Boolean;
  end;

  TSdOtaProjectResource = class;

  TSdOtaResEntry = class(TInterfacedObject, IOTAResourceEntry)
  private
    FOwner: TSdOtaProjectResource;     // the resource file keeps its entries: no reference back
    FTypeOrd, FNameOrd: Integer;       // -1: by name
    FTypeName, FNameName: string;
    FDataVersion, FVersion, FCharacteristics: Cardinal;
    FFlags, FLanguage: Word;
    FData: string;
  public
    { the entry of the same resource: its type, name and language }
    function SameResource(E: TSdOtaResEntry): Boolean;
    { E's header values and data (the file read again) }
    procedure TakeValues(E: TSdOtaResEntry);
    function GetResourceType: PChar;
    function GetResourceName: PChar;
    function Change(NewType, NewName: PChar): Boolean;
    function GetHeaderValue(HeaderValue: TOTAResHeaderValue; var Value: Integer): Boolean;
    function SetHeaderValue(HeaderValue: TOTAResHeaderValue; Value: Integer): Boolean;
    function GetData: Pointer;
    function GetDataSize: Integer;
    procedure SetDataSize(NewSize: Integer);
    function GetEntryHandle: TOTAHandle;
  end;

  TSdOtaProjectResource = class(TInterfacedObject, IOTAEditor, IOTAProjectResource, ISdResFile)
  private
    FProjectFile: string;
    FItems: TList;                     // the entries (TSdOtaResEntry) ...
    FEntries: TInterfaceList;          // ... and their references, in the same order
    FDiskBytes: string;                // the file as last read or written
    FStamp: TSdFileStamp;              // ... its time and size then: Sync reads it only when they change
    FBase: string;                     // the entries then, serialized (Dirty: they changed since)
    FCopy: Boolean;                    // a copy (CreateCopy): never read again, never written
    FUpdating: Integer;                // BeginUpdate's depth: Flush waits for the last EndUpdate
    function ResFile: string;
    function Dirty: Boolean;
    function WriteChanges: Boolean;
    function Serialize: string;
    procedure Parse(const Bytes: string);
    procedure Reparse(const Bytes: string);
    procedure ParseEntries(const Bytes: string; L: TList);
    procedure Sync;
    function Entry(Index: Integer): TSdOtaResEntry;
    { the first entry of the type and name - of the language, or of any (-1) }
    function IndexOfEntry(ResType, Name: PChar; Language: Integer): Integer;
    procedure AddEntry(E: TSdOtaResEntry);
    procedure ClearEntries;
  public
    constructor Create(const AProjectFile: string);
    { Source's entries as they are now (read again first when its file changed) }
    constructor CreateCopy(Source: TSdOtaProjectResource);
    destructor Destroy; override;
    procedure Flush;
    procedure Changed;
    { ISdResFile }
    function ResFileBytes: string;
    procedure BeginUpdate;
    procedure EndUpdate;
    { IOTAEditor }
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    function GetFileName: string;
    function GetModified: Boolean;
    function GetModule: IOTAModule;
    function MarkModified: Boolean;
    procedure RemoveNotifier(Index: Integer);
    procedure Show;
    { IOTAProjectResource }
    function GetEntryCount: Integer;
    function GetEntry(Index: Integer): IOTAResourceEntry;
    function GetEntryFromHandle(EntryHandle: TOTAHandle): IOTAResourceEntry;
    function FindEntry(ResType, Name: PChar): IOTAResourceEntry;
    procedure DeleteEntry(EntryHandle: TOTAHandle);
    function CreateEntry(ResType, Name: PChar; Flags, LanguageId: Word;
      DataVersion, Version, Characteristics: Integer): IOTAResourceEntry;
  end;

{ ---------------------------------------------------------------- helpers }

function SameFile(const A, B: string): Boolean;
begin
  Result := (A <> '') and SameText(A, B);
end;

{ the calls of the notifiers (TSdNotifierList.Each: Data their arguments) }
type
  TNotifyKind = (nkBeforeSave, nkAfterSave, nkDestroyed, nkModified);

procedure NotifyOne(const N: IInterface; Data: Pointer);
begin
  case TNotifyKind(Integer(Data)) of
    nkBeforeSave: IOTANotifier(N).BeforeSave;
    nkAfterSave: IOTANotifier(N).AfterSave;
    nkDestroyed: IOTANotifier(N).Destroyed;
    nkModified: IOTANotifier(N).Modified;
  end;
end;

{ every notifier of a list (a snapshot: one may remove itself), each in its own try }
procedure CallNotifiers(L: TSdNotifierList; Kind: TNotifyKind);
begin
  if L <> nil then L.Each(IOTANotifier, NotifyOne, Pointer(Ord(Kind)), 'notifier');
end;

procedure LineChangedOne(const N: IInterface; Data: Pointer);
begin
  { Data: the old line, the new line, the line's data }
  IOTAEditLineNotifier(N).LineChanged(PIntegerArray(Data)^[0], PIntegerArray(Data)^[1], PIntegerArray(Data)^[2]);
end;

type
  PViewCall = ^TViewCall;
  TViewCall = record
    View: IOTAEditView;
    Activated: Boolean;
    Op: TOperation;
  end;

procedure ViewNotifyOne(const N: IInterface; Data: Pointer);
begin
  with PViewCall(Data)^ do
    if Activated then IOTAEditorNotifier(N).ViewActivated(View)
    else IOTAEditorNotifier(N).ViewNotification(View, Op);
end;

procedure FormActivatedOne(const N: IInterface; Data: Pointer);
begin
  IOTAFormNotifier(N).FormActivated;
end;

procedure FormSavingOne(const N: IInterface; Data: Pointer);
begin
  IOTAFormNotifier(N).FormSaving;
end;

procedure ModuleRenamedOne(const N: IInterface; Data: Pointer);
begin
  IOTAModuleNotifier(N).ModuleRenamed(PString(Data)^);
end;

type
  PRenameCall = ^TRenameCall;
  TRenameCall = record
    Component: Pointer;
    OldName, NewName: string;
  end;

procedure ComponentRenamedOne(const N: IInterface; Data: Pointer);
begin
  with PRenameCall(Data)^ do IOTAFormNotifier(N).ComponentRenamed(Component, OldName, NewName);
end;

function PageOf(const FileName: string): TEditorPage;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.FindPage(FileName);
end;

{ the buffer of a page. A form shown as text (View as Text) is a module of its own, as in Delphi 7
  (measured), and its unit has none while it is: Delphi closes the unit's module then }
function OtaPageBuffer(Page: TEditorPage): IOTAEditBuffer;
var
  M: TSdOtaModule;
begin
  Result := nil;
  if (Page = nil) or (OtaModules = nil) or (Page.FormTextPage <> nil) then Exit;
  M := OtaModules.Find(Page.FileName);
  if M <> nil then Supports(M.SourceEditor, IOTAEditBuffer, Result);
end;

function FileTypeIndexOf(const FileName: string): Integer;
begin
  Result := EditorFileTypeIndex(FileName);
  if (Result < 0) and (Length(EditorOptions.FileTypes) > 0) then Result := 0;
end;

function OtaEditOptionsIndex(Index: Integer): IOTAEditOptions;
begin
  if (Index < 0) or (Index > High(EditorOptions.FileTypes)) then Result := nil
  else Result := TSdOtaEditOptions.Create(Index);
end;

function OtaEditOptionsCount: Integer;
begin
  Result := Length(EditorOptions.FileTypes);
end;

function OtaEditOptionsOf(const FileName: string): IOTAEditOptions;
begin
  Result := OtaEditOptionsIndex(FileTypeIndexOf(FileName));
end;

{ ---------------------------------------------------------------- TSdOtaEditState }

constructor TSdOtaEditState.Create;
begin
  inherited Create;
  Positions := TList.Create;
  Blocks := TList.Create;
  LastEdit := OtaEditPos(1, 1);
end;

destructor TSdOtaEditState.Destroy;
var
  I: Integer;
begin
  Positions.Free;
  for I := 0 to Blocks.Count - 1 do TObject(Blocks[I]).Free;
  Blocks.Free;
  inherited;
end;

{ ---------------------------------------------------------------- TSdOtaModule }

constructor TSdOtaModule.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FNotifiers := TSdNotifierList.Create;
  FSourceNotifiers := TSdNotifierList.Create;
  FFormNotifiers := TSdNotifierList.Create;
  FState := TSdOtaEditState.Create;
  FAdditional := TStringList.Create;
  FEditorNames := TStringList.Create;
  FEditorRefs := TInterfaceList.Create;
end;

destructor TSdOtaModule.Destroy;
begin
  if FTrackerObj <> nil then TSdOtaLineTracker(FTrackerObj).FModule := nil;
  FTracker := nil;
  EditorsGone;
  FEditorRefs.Free;
  FEditorNames.Free;
  FAdditional.Free;
  FState.Free;
  FFormNotifiers.Free;
  FSourceNotifiers.Free;
  FNotifiers.Free;
  inherited;
end;

function TSdOtaModule.Page: TEditorPage;
begin
  Result := PageOf(FFileName);
end;

function TSdOtaModule.HasForm: Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (P <> nil) and P.HasForm;
end;

function TSdOtaModule.FormFileName: string;
begin
  Result := ChangeFileExt(FFileName, '.dfm');
end;

function TSdOtaModule.SourceEditor: IOTASourceEditor;
begin
  Result := EditorOf(FFileName);
end;

function TSdOtaModule.FormEditor: IOTAFormEditor;
begin
  Result := nil;
  if not HasForm then Exit;
  if FForgotten then
  begin
    Result := TSdOtaFormEditor.Create(Self);
    Exit;
  end;
  if FFormEditorRef = nil then FFormEditorRef := TSdOtaFormEditor.Create(Self);
  Result := FFormEditorRef;
end;

{ the source editor object of a file of the module (Ref holds it while the caller uses it) }
function TSdOtaModule.EditorObject(const AFileName: string; out Ref: IOTASourceEditor): TObject;
var
  I: Integer;
  E: TSdOtaSourceEditor;
begin
  for I := 0 to FEditorNames.Count - 1 do
    if SameFileName(FEditorNames[I], AFileName) then
    begin
      Result := FEditorNames.Objects[I];
      Ref := TSdOtaSourceEditor(Result);
      Exit;
    end;
  E := TSdOtaSourceEditor.Create(Self, AFileName);
  Result := E;
  Ref := E;
  if FForgotten then Exit;
  FEditorNames.AddObject(AFileName, E);
  FEditorRefs.Add(Ref);
end;

function TSdOtaModule.EditorOf(const AFileName: string): IOTASourceEditor;
begin
  EditorObject(AFileName, Result);
end;

function TSdOtaModule.ViewOf(const AFileName: string): IOTAEditView;
var
  Ref: IOTASourceEditor;
begin
  Result := TSdOtaSourceEditor(EditorObject(AFileName, Ref)).View;
end;

procedure TSdOtaModule.EditorsGone;
var
  I: Integer;
begin
  FForgotten := True;
  for I := 0 to FEditorNames.Count - 1 do TSdOtaSourceEditor(FEditorNames.Objects[I]).ViewGone;
  FEditorNames.Clear;
  FEditorRefs.Clear;
  FFormEditorRef := nil;
end;

{ the unit's file and its form's text (View as Text) follow a rename of the unit }
procedure TSdOtaModule.EditorsRenamed(const OldFileName, NewFileName: string);
var
  I: Integer;
  E: TSdOtaSourceEditor;
  N: string;
begin
  for I := 0 to FEditorNames.Count - 1 do
  begin
    E := TSdOtaSourceEditor(FEditorNames.Objects[I]);
    if SameFileName(FEditorNames[I], OldFileName) then N := NewFileName
    else if SameFileName(FEditorNames[I], ChangeFileExt(OldFileName, '.dfm')) then N := ChangeFileExt(NewFileName, '.dfm')
    else Continue;
    FEditorNames[I] := N;
    E.FFileName := N;
  end;
end;

function TSdOtaModule.Tracker: IOTAEditLineTracker;
var
  T: TSdOtaLineTracker;
begin
  if FTracker = nil then
  begin
    T := TSdOtaLineTracker.Create(Self);
    FTrackerObj := T;
    FTracker := T;
  end;
  Result := FTracker;
end;

procedure TSdOtaModule.DropModule(Module: HMODULE);
begin
  FNotifiers.DropModule(Module);
  FSourceNotifiers.DropModule(Module);
  FFormNotifiers.DropModule(Module);
  { the line tracker's IOTAEditLineNotifiers too: they would be called at the next edit }
  if FTrackerObj <> nil then TSdOtaLineTracker(FTrackerObj).FNotifiers.DropModule(Module);
end;

procedure TSdOtaModule.GetOwners(L: TList);
var
  G: TSdProjectGroup;
  I: Integer;
begin
  L.Clear;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if G = nil then Exit;
  G.OwnersOf(FFileName, L);
  { a unit's owners: not the project whose source the file is }
  for I := L.Count - 1 downto 0 do
    if SameFile(TSdProject(L[I]).FileName, FFileName) then L.Delete(I);
end;

function TSdOtaModule.AddNotifier(const ANotifier: IOTAModuleNotifier): Integer;
begin
  Result := FNotifiers.Add(ANotifier);
  OtaModules.NeedDesignNotes;          // the form's changes are the module's too
end;

procedure TSdOtaModule.AddToInterface;
begin
end;

function TSdOtaModule.Close: Boolean;
begin
  Result := CloseModule(False);
end;

function TSdOtaModule.CloseModule(ForceClosed: Boolean): Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (P = nil) or OtaHost.ClosePage(P, not ForceClosed);
end;

function TSdOtaModule.GetFileName: string;
begin
  Result := FFileName;
end;

{ the expert's file system the page reads and writes through ('' the disk) }
function TSdOtaModule.GetFileSystem: string;
var
  P: TEditorPage;
begin
  P := Page;
  if P <> nil then Result := P.FileSystem else Result := '';
end;

(* the text of a unit as Delphi 7's code manager reads it (Pasmgr.TPascalCodeManager.
   GetAdditionalFileExt): after the directive {$R *.dfm} or {$R *.xfm} each comment {*.ext} names an
   extension (with its dot; each once) - comments and strings elsewhere are no such comment *)
procedure AdditionalFileExts(const Source: string; Exts: TStrings);
var
  R: TRawToks;
  I, K: Integer;
  T, E: string;
  After, Ok: Boolean;
begin
  Exts.Clear;
  R := TRawToks.Create(Source, True);
  try
    After := False;
    for I := 0 to R.N - 1 do
    begin
      if R.T[I].Kind <> tkComment then Continue;
      T := R.Txt(I);
      if not After then
        After := SameText(T, '{$R *.dfm}') or SameText(T, '{$R *.xfm}')
      else if (Length(T) > 4) and (Copy(T, 1, 3) = '{*.') and (T[Length(T)] = '}') then
      begin
        E := Copy(T, 3, Length(T) - 3);
        Ok := True;
        for K := 2 to Length(E) do
          if not (E[K] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Ok := False;
        if Ok and (Exts.IndexOf(E) < 0) then Exts.Add(E);
      end;
    end;
  finally
    R.Free;
  end;
end;

procedure TSdOtaModule.ScanAdditionalFiles;
var
  Exts: TStringList;
  Src: string;
  I: Integer;
begin
  if (OtaHost = nil) or not SameText(ExtractFileExt(FFileName), '.pas') then Exit;
  try
    Src := OtaHost.SourceOf(FFileName);
  except
    Exit;
  end;
  Exts := TStringList.Create;
  try
    AdditionalFileExts(Src, Exts);
    for I := 0 to Exts.Count - 1 do AddAdditionalFile(ChangeFileExt(FFileName, Exts[I]));
  finally
    Exts.Free;
  end;
end;

function TSdOtaModule.OpenEditorPage(const AFileName: string; Activate: Boolean): TEditorPage;
begin
  Result := OtaHost.OpenFile(AFileName, Activate);
end;

function TSdOtaModule.ClosedFileText(const AFileName: string): string;
begin
  Result := OtaHost.SourceOf(AFileName);
end;

procedure TSdOtaModule.AddAdditionalFile(const AFileName: string);
var
  I: Integer;
begin
  if AFileName = '' then Exit;
  for I := 0 to FAdditional.Count - 1 do
    if SameText(FAdditional[I], AFileName) then Exit;
  FAdditional.Add(AFileName);
end;

{ Delphi's TUnitModule.HasForm: the form loaded, or a form file of the unit (.dfm, .xfm, .nfm);
  other files have no objects (TDocModule) }
function TSdOtaModule.HasObjects: Boolean;
var
  P: TEditorPage;
  Base: string;
begin
  Result := False;
  if not SameText(ExtractFileExt(FFileName), '.pas') then Exit;
  P := Page;
  if (P <> nil) and P.HasForm then
  begin
    Result := True;
    Exit;
  end;
  Base := ChangeFileExt(FFileName, '');
  Result := FileExistsU(Base + '.dfm') or FileExistsU(Base + '.xfm') or FileExistsU(Base + '.nfm');
end;

function TSdOtaModule.GetAdditionalModuleFileCount: Integer;
begin
  Result := FAdditional.Count;
end;

{ the file's source editor: its page when it is open, else the file's text (opened hidden to be
  written) - of this module, as Delphi's buffer belongs to the unit's module }
function TSdOtaModule.GetAdditionalModuleFileEditor(Index: Integer): IOTAEditor;
begin
  if (Index >= 0) and (Index < FAdditional.Count) then
    Result := EditorOf(FAdditional[Index])
  else
    Result := nil;
end;

function TSdOtaModule.GetModuleFileCount: Integer;
begin
  if HasForm then Result := 2 else Result := 1;
end;

{ 0 the unit's source, 1 its form. A form shown as text is a module of its own: its text is its
  source }
function TSdOtaModule.GetModuleFileEditor(Index: Integer): IOTAEditor;
begin
  case Index of
    0: Result := SourceEditor;
    1: Result := FormEditor;
  else
    Result := nil;
  end;
end;

function TSdOtaModule.GetOwnerCount: Integer;
var
  L: TList;
begin
  L := TList.Create;
  try
    GetOwners(L);
    Result := L.Count;
  finally
    L.Free;
  end;
end;

function TSdOtaModule.GetOwner(Index: Integer): IOTAProject;
var
  L: TList;
begin
  Result := nil;
  L := TList.Create;
  try
    GetOwners(L);
    if (Index >= 0) and (Index < L.Count) then
      Supports(OtaModules.ModuleIntf(TSdProject(L[Index]).FileName), IOTAProject, Result);
  finally
    L.Free;
  end;
end;

function TSdOtaModule.HasCoClasses: Boolean;
begin
  Result := False;
end;

procedure TSdOtaModule.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

{ ForceSave: written even when nothing changed. The pages of its additional files that are
  modified are written with it, as Delphi 7's module writes its files (a creator's new ones) }
function TSdOtaModule.Save(ChangeName, ForceSave: Boolean): Boolean;
var
  P, A: TEditorPage;
  I: Integer;
begin
  P := Page;
  if (P <> nil) and ForceSave and not P.Modified then P.MarkModified;
  Result := (P <> nil) and OtaHost.SavePage(P, ChangeName);
  if not Result or ChangeName then Exit;
  for I := 0 to FAdditional.Count - 1 do
  begin
    A := PageOf(FAdditional[I]);
    if (A <> nil) and A.Modified then OtaHost.SavePage(A, False);
  end;
end;

{ Delphi 7's (measured): renamed, nothing written - the module is modified, Save writes it there }
procedure TSdOtaModule.SetFileName(const AFileName: string);
var
  P: TEditorPage;
begin
  P := Page;
  if P <> nil then OtaHost.RenamePage(P, AFileName);
end;

{ Delphi's TEditBuffer.SetFileSystem: '' the disk again, an unknown one raises Delphi's
  exception; the next save writes through it }
procedure TSdOtaModule.SetFileSystem(const AFileSystem: string);
var
  P: TEditorPage;
begin
  if AFileSystem <> '' then NeedPageFileSystem(AFileSystem).Free;
  P := Page;
  if P <> nil then P.FileSystem := AFileSystem;
end;

{ the editor the user works in: the form or the source }
function TSdOtaModule.GetCurrentEditor: IOTAEditor;
var
  P: TEditorPage;
begin
  P := Page;
  if (P <> nil) and P.DesignView and P.HasForm then Result := FormEditor
  else Result := SourceEditor;
end;

function TSdOtaModule.GetOwnerModuleCount: Integer;
begin
  Result := GetOwnerCount;
end;

function TSdOtaModule.GetOwnerModule(Index: Integer): IOTAModule;
begin
  Result := GetOwner(Index);
end;

procedure TSdOtaModule.MarkModified;
var
  P: TEditorPage;
begin
  P := Page;
  if P <> nil then P.MarkModified;
end;

{ ---------------------------------------------------------------- TSdOtaProject }

function TSdOtaProject.Project: TSdProject;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.GroupProject(FFileName);
end;

function TSdOtaProject.IsActive: Boolean;
begin
  Result := (OtaHost <> nil) and (OtaHost.Project <> nil) and SameFile(OtaHost.Project.FileName, FFileName);
end;

{ a project is owned by no project (its owner module is the group's: GetOwnerModule) }
procedure TSdOtaProject.GetOwners(L: TList);
begin
  L.Clear;
end;

{ Delphi's TWorkspace.CloseProject / HideOrClose: the project's own files close (asked about), it
  stays in the group closed - active or not; the user is asked about unsaved files also when an
  expert forces the close }
function TSdOtaProject.CloseModule(ForceClosed: Boolean): Boolean;
begin
  Result := (OtaHost = nil) or OtaHost.CloseGroupProject(FFileName, ForceClosed);
end;

{ the project source, then its resource file (Delphi's order) }
function TSdOtaProject.GetModuleFileCount: Integer;
begin
  Result := 2;
end;

function TSdOtaProject.GetModuleFileEditor(Index: Integer): IOTAEditor;
begin
  case Index of
    0: Result := SourceEditor;
    1: Result := OtaModules.ProjectResource(FFileName);
  else
    Result := nil;
  end;
end;

{ the group; none for a package open beside it, which is no project of the group (Delphi's
  ToolsAPI: a package project outside the open project group may have no owner) }
function TSdOtaProject.GetOwnerModuleCount: Integer;
var
  G: TSdProjectGroup;
begin
  Result := 0;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if (G <> nil) and (G.IndexOfBeside(FFileName) < 0) then Result := 1;
end;

function TSdOtaProject.GetOwnerModule(Index: Integer): IOTAModule;
begin
  if (Index = 0) and (GetOwnerModuleCount > 0) then Result := OtaModules.GroupModule else Result := nil;
end;

{ ChangeName: the IDE's Save Project As (the group's entry follows the new name) }
function TSdOtaProject.Save(ChangeName, ForceSave: Boolean): Boolean;
var
  P: TEditorPage;
  Prj: TSdProject;
begin
  Prj := Project;
  if ChangeName and (Prj <> nil) then
  begin
    Result := OtaHost.SaveProjectAs(Prj, '');
    Exit;
  end;
  Result := True;
  P := Page;
  if P <> nil then Result := OtaHost.SavePage(P, ChangeName);
  if Prj <> nil then
    try
      Prj.SaveOptions;
    except
      on E: Exception do
      begin
        OtaError(E, 'IOTAProject.Save');
        Result := False;
      end;
    end;
  OtaModules.FlushResources;
end;

{ a project of the group or beside it: renamed, nothing written (Delphi 7's: measured) - its entry,
  its source's page and its module follow; Save writes the source, its options and its .res there }
procedure TSdOtaProject.SetFileName(const AFileName: string);
var
  Prj: TSdProject;
begin
  Prj := Project;
  if AFileName = '' then Exit;
  if Prj <> nil then OtaHost.RenameProject(Prj, AFileName)
  else inherited;
end;

function TSdOtaProject.GetModuleCount: Integer;
var
  P: TSdProject;
begin
  P := Project;
  if P = nil then Result := 0
  else if P.IsPackage then Result := P.UnitCount + P.Requires.Count
  else Result := P.UnitCount;
end;

{ the class a unit's form descends from (TForm, TDataModule, TFrame, a form of the project ...; ''
  unknown): its .dfm names the form's class (its header: nothing converted), the unit's source its
  ancestor }
function FormAncestor(const UnitFile, FormFile: string): string;
var
  N, C: string;
begin
  Result := '';
  try
    if DfmHeader(ReadFileU(FormFile), N, C) and (C <> '') then
      Result := FSGetAncestorName(OtaHost.SourceOf(UnitFile), C);
  except
    Result := '';
  end;
end;

{ a data module is Delphi's omtDataModule; a module that is no plain form names its design class -
  both found when they are asked for (TSdOtaModuleInfo.NeedFormClass): a loop over the modules for
  their names and files reads no form file and no unit }
function TSdOtaProject.GetModule(Index: Integer): IOTAModuleInfo;
var
  P: TSdProject;
  U: TProjectUnit;
  Info: TSdOtaModuleInfo;
begin
  Result := nil;
  P := Project;
  if (P = nil) or (Index < 0) then Exit;
  if Index < P.UnitCount then
  begin
    U := P.Units[Index];
    if U.HasForm then
    begin
      Info := TSdOtaModuleInfo.Create(omtForm, U.Name, U.FileName, U.FormName, '');
      Info.FFormFile := U.FormFileName;
    end
    else
      Info := TSdOtaModuleInfo.Create(omtUnit, U.Name, U.FileName, U.FormName, '');
    Result := Info;
  end
  else if P.IsPackage and (Index - P.UnitCount < P.Requires.Count) then
    Result := TSdOtaModuleInfo.Create(omtPackageImport, P.Requires[Index - P.UnitCount],
      P.Requires[Index - P.UnitCount] + '.dcp', '', '');
end;

function TSdOtaProject.GetProjectOptions: IOTAProjectOptions;
begin
  if FOptions = nil then
  begin
    FOptionsObj := TSdOtaProjectOptions.Create(FFileName);
    FOptions := TSdOtaProjectOptions(FOptionsObj);
  end;
  Result := FOptions;
end;

function TSdOtaProject.GetProjectBuilder: IOTAProjectBuilder;
begin
  Result := Self;
end;

{ into / out of this project, active or not (Delphi's TProject.AddFile: the project's own) }
procedure TSdOtaProject.AddFile(const AFileName: string; IsUnitOrForm: Boolean);
var
  P: TSdProject;
begin
  P := Project;
  if P <> nil then OtaHost.ProjectAddFileTo(P, AFileName);
end;

{ Delphi 7's RemoveFile (measured): it asks first, then closes the unit's module - also one another
  project has; a modified one asks whether to save it }
procedure TSdOtaProject.RemoveFile(const AFileName: string);
var
  P: TSdProject;
  M: IOTAModule;
begin
  P := Project;
  if (P = nil) or (DelphiMessageDlg(Format('Remove %s?', [AFileName]), mtConfirmation, [mbYes, mbNo]) <> mrYes) then
    Exit;
  OtaHost.ProjectRemoveFileFrom(P, AFileName);
  M := OtaModules.ModuleIntf(AFileName);
  if M <> nil then M.CloseModule(False);
end;

{ Delphi's flag: the options were changed through the API since the last build }
function TSdOtaProject.GetShouldBuild: Boolean;
begin
  Result := FShouldBuild;
end;

function TSdOtaProject.BuildProject(CompileMode: TOTACompileMode; Wait: Boolean): Boolean;
begin
  Result := BuildProject(CompileMode, Wait, True);
end;

function TSdOtaProject.BuildProject(CompileMode: TOTACompileMode; Wait, ClearMessages: Boolean): Boolean;
var
  P: TSdProject;
begin
  P := Project;
  Result := (P <> nil) and OtaHost.CompileProject(P, CompileMode, ClearMessages);
  if Result and (CompileMode = cmOTABuild) then FShouldBuild := False;
end;

{ ---------------------------------------------------------------- TSdOtaProjectGroup }

function TSdOtaProjectGroup.CloseModule(ForceClosed: Boolean): Boolean;
begin
  Result := OtaHost.CloseProject(ForceClosed);
end;

function TSdOtaProjectGroup.GetOwnerModuleCount: Integer;
begin
  Result := 0;
end;

function TSdOtaProjectGroup.Save(ChangeName, ForceSave: Boolean): Boolean;
begin
  Result := OtaHost.ExecuteAction('aSaveGroup');
end;

procedure TSdOtaProjectGroup.AddNewProject;
begin
  OtaHost.AddNewProject;
end;

procedure TSdOtaProjectGroup.AddExistingProject;
begin
  OtaHost.AddExistingProject;
end;

function TSdOtaProjectGroup.GetActiveProject: IOTAProject;
begin
  Result := nil;
  if (OtaHost <> nil) and (OtaHost.Project <> nil) then
    Supports(OtaModules.ModuleIntf(OtaHost.Project.FileName), IOTAProject, Result);
end;

{ the group's projects, closed ones too; the packages open beside the group are none of them, also
  while one is the active project }
function TSdOtaProjectGroup.GetProjectCount: Integer;
var
  G: TSdProjectGroup;
begin
  Result := 0;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if G <> nil then Result := G.Projects.Count;
end;

{ a closed project's place gives the group's first project, as Delphi 7's does (measured: its
  ProjectCount counts the closed one, its Projects gives none of its own) }
function TSdOtaProjectGroup.GetProject(Index: Integer): IOTAProject;
var
  G: TSdProjectGroup;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if (G <> nil) and (Index >= 0) and (Index < G.Projects.Count) then
  begin
    if (Index > 0) and (G.LoadedProjectOf(G.Projects[Index]) = nil) then Index := 0;
    Supports(OtaModules.ModuleIntf(G.Projects[Index]), IOTAProject, Result);
  end;
end;

procedure TSdOtaProjectGroup.RemoveProject(const AProject: IOTAProject);
begin
  if AProject <> nil then OtaHost.RemoveGroupProject(AProject.FileName);
end;

{ Delphi 7's SetActiveProject (measured): a project of the group - the active one again, the IDE
  notifiers are told once more; a package beside the group it does not take (the Project Manager's
  Activate does) }
procedure TSdOtaProjectGroup.SetActiveProject(const AProject: IOTAProject);
var
  G: TSdProjectGroup;
begin
  if (AProject = nil) or (OtaHost = nil) then Exit;
  G := OtaHost.ProjectGroup;
  if (G = nil) or (G.Projects.IndexOf(AProject.FileName) < 0) then Exit;
  if (OtaHost.Project <> nil) and SameText(OtaHost.Project.FileName, AProject.FileName) then
    OtaFileNotification(ofnActiveProjectChanged, AProject.FileName)
  else
    OtaHost.ActivateProject(AProject.FileName);
end;

{ ---------------------------------------------------------------- TSdOtaTypeLibModule }

{ the library's unit in the library's folder (the name the importer gives it); '' while the module
  is not the view's library }
function TSdOtaTypeLibModule.UnitFile: string;
var
  U: string;
begin
  Result := '';
  if (OtaHost = nil) or not SameFile(OtaHost.TypeLibraryFile, FFileName) then Exit;
  U := OtaHost.TypeLibraryUnit;
  if U <> '' then Result := ExtractFilePath(FFileName) + U + '.pas';
end;

{ AFileName is the library's unit (UnitFile) }
function TSdOtaTypeLibModule.IsUnit(const AFileName: string): Boolean;
var
  U: string;
begin
  U := UnitFile;
  Result := (U <> '') and SameFile(AFileName, U);
end;

{ the unit's text, the importer's, while no page of it is open }
function TSdOtaTypeLibModule.ClosedFileText(const AFileName: string): string;
begin
  if IsUnit(AFileName) then Result := OtaHost.TypeLibraryUnitText
  else Result := inherited ClosedFileText(AFileName);
end;

{ the unit's page: in memory with the importer's text (written only when saved) }
function TSdOtaTypeLibModule.OpenEditorPage(const AFileName: string; Activate: Boolean): TEditorPage;
begin
  if IsUnit(AFileName) then
    Result := OtaHost.OpenWithText(AFileName, '', OtaHost.TypeLibraryUnitText, Activate)
  else
    Result := inherited OpenEditorPage(AFileName, Activate);
end;

{ the loaded projects whose type library it is (<project>.tlb): the group's, the packages beside it }
procedure TSdOtaTypeLibModule.GetOwners(L: TList);
var
  G: TSdProjectGroup;
  I: Integer;
begin
  L.Clear;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if G = nil then Exit;
  for I := 0 to G.AllCount - 1 do
    if (G.AllProject(I) <> nil) and SameFile(ChangeFileExt(G.AllFile(I), '.tlb'), FFileName) then
      L.Add(G.AllProject(I));
end;

{ the view emptied; the page of its unit, when one was made for an expert, goes with it }
function TSdOtaTypeLibModule.CloseModule(ForceClosed: Boolean): Boolean;
var
  U: string;
  P: TEditorPage;
begin
  U := UnitFile;
  Result := (OtaHost = nil) or not SameFile(OtaHost.TypeLibraryFile, FFileName) or OtaHost.CloseTypeLibrary;
  if not Result or (U = '') then Exit;
  P := PageOf(U);
  if P <> nil then Result := OtaHost.ClosePage(P, not ForceClosed);
end;

function TSdOtaTypeLibModule.GetModuleFileCount: Integer;
begin
  if UnitFile <> '' then Result := 1 else Result := 0;
end;

function TSdOtaTypeLibModule.GetModuleFileEditor(Index: Integer): IOTAEditor;
var
  U: string;
begin
  Result := nil;
  U := UnitFile;
  if (Index = 0) and (U <> '') then Result := EditorOf(U);
end;

{ Delphi 7's: none (the library's editor is not the source editor) }
function TSdOtaTypeLibModule.GetCurrentEditor: IOTAEditor;
begin
  Result := nil;
end;

function TSdOtaTypeLibModule.Save(ChangeName, ForceSave: Boolean): Boolean;
begin
  Result := True;
end;

procedure TSdOtaTypeLibModule.SetFileName(const AFileName: string);
begin
end;

procedure TSdOtaTypeLibModule.MarkModified;
begin
end;

function TSdOtaTypeLibModule.GetAdditionalModuleFileCount: Integer;
begin
  Result := 0;
end;

{ ---------------------------------------------------------------- TSdOtaSourceEditor }

constructor TSdOtaSourceEditor.Create(AModule: TSdOtaModule; const AFileName: string);
begin
  inherited Create;
  FModule := AModule;
  FModuleRef := AModule;
  FFileName := AFileName;
end;

function TSdOtaSourceEditor.Page: TEditorPage;
begin
  Result := PageOf(FFileName);
end;

function TSdOtaSourceEditor.Ed: TSciEdit;
var
  P: TEditorPage;
begin
  P := Page;
  if (P <> nil) and P.Editor.Ready then Result := P.Editor else Result := nil;
end;

function TSdOtaSourceEditor.NeedEd: TSciEdit;
var
  P: TEditorPage;
begin
  Result := Ed;
  if (Result <> nil) or (OtaHost = nil) then Exit;
  P := FModule.OpenEditorPage(FFileName, False);
  if (P <> nil) and P.Editor.Ready then Result := P.Editor;
end;

function TSdOtaSourceEditor.OtaFileName: string;
begin
  Result := FFileName;
end;

function TSdOtaSourceEditor.AddNotifier(const ANotifier: IOTANotifier): Integer;
begin
  Result := FModule.SourceNotifiers.Add(ANotifier);
end;

function TSdOtaSourceEditor.GetFileName: string;
begin
  Result := FFileName;
end;

{ the text changed since it was saved, or never saved (an untitled page) }
{ the text's own state: its changes, an expert's MarkModified, a new encoding, no file yet }
function TSdOtaSourceEditor.GetModified: Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (Ed <> nil) and (P <> nil) and P.SourceModified;
end;

function TSdOtaSourceEditor.GetModule: IOTAModule;
begin
  Result := FModuleRef;
end;

function TSdOtaSourceEditor.MarkModified: Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := P <> nil;
  if not Result then Exit;
  P.MarkModified;
  FModule.State.ChangedAt := Now;
end;

procedure TSdOtaSourceEditor.RemoveNotifier(Index: Integer);
begin
  FModule.SourceNotifiers.Remove(Index);
end;

procedure TSdOtaSourceEditor.Show;
var
  P: TEditorPage;
begin
  if OtaHost = nil then Exit;
  P := FModule.OpenEditorPage(FFileName, True);
  if P <> nil then P.ShowDesign(False);
end;

function TSdOtaSourceEditor.CreateReader: IOTAEditReader;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then Result := TSdOtaReader.Create(E.GetText)
  else if OtaHost <> nil then
    try
      Result := TSdOtaReader.Create(FModule.ClosedFileText(FFileName));
    except
      Result := TSdOtaReader.Create('');
    end
  else
    Result := TSdOtaReader.Create('');
end;

function TSdOtaSourceEditor.CreateWriter: IOTAEditWriter;
begin
  Result := TSdOtaWriter.Create(Self, False);
end;

function TSdOtaSourceEditor.CreateUndoableWriter: IOTAEditWriter;
begin
  Result := TSdOtaWriter.Create(Self, True);
end;

function TSdOtaSourceEditor.GetEditViewCount: Integer;
begin
  if Ed <> nil then Result := 1 else Result := 0;
end;

function TSdOtaSourceEditor.GetEditView(Index: Integer): IOTAEditView;
begin
  if (Index = 0) and (Ed <> nil) then Result := View else Result := nil;
end;

function TSdOtaSourceEditor.View: IOTAEditView;
begin
  if FModule.FForgotten then
  begin
    Result := TSdOtaEditView.Create(Self);
    Exit;
  end;
  if FViewRef = nil then FViewRef := TSdOtaEditView.Create(Self);
  Result := FViewRef;
end;

procedure TSdOtaSourceEditor.ViewGone;
begin
  FViewRef := nil;
end;

{ a file that is not open: the lines of the IDE's text of it }
function TSdOtaSourceEditor.GetLinesInBuffer: Longint;
var
  E: TSciEdit;
  S: string;
  I: Integer;
begin
  E := Ed;
  if E <> nil then
  begin
    Result := E.LineCount;
    Exit;
  end;
  Result := 0;
  if OtaHost = nil then Exit;
  try
    S := FModule.ClosedFileText(FFileName);
  except
    Exit;
  end;
  Result := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Result);
end;

{ Delphi's TEditSource.SetSyntaxHighlighter: shQuery tells the buffer's highlighter, the others
  give the buffer that one (until the file is read again) - the one before is the result }
function TSdOtaSourceEditor.SetSyntaxHighlighter(SyntaxHighlighter: TOTASyntaxHighlighter): TOTASyntaxHighlighter;
const
  { Delphi's highlighters and the editor's languages (the editor's others answer shNone) }
  Highlighters: array[0..4] of record Sh: TOTASyntaxHighlighter; Lang: TSciLanguage end = (
    (Sh: shNone; Lang: slNone), (Sh: shPascal; Lang: slPascal), (Sh: shC; Lang: slCpp),
    (Sh: shSQL; Lang: slSql), (Sh: shIDL; Lang: slIdl));
var
  E: TSciEdit;
  I, Target: Integer;
begin
  Result := shNone;
  E := Ed;
  if E = nil then Exit;
  Target := -1;
  for I := Low(Highlighters) to High(Highlighters) do
  begin
    if Highlighters[I].Lang = E.Language then Result := Highlighters[I].Sh;
    if Highlighters[I].Sh = SyntaxHighlighter then Target := I;
  end;
  if Target >= 0 then E.SetLanguage(Highlighters[Target].Lang);
end;

{ The block is the editor's buffer block (TSciEdit.GetBufferBlock, Delphi 7's).
  BlockStart / BlockAfter are its ends as they were set - in no order, also while it is hidden -:
  a stream block's character positions, a column block's corners as edit positions in a
  TOTACharPos (CharIndex the 1-based column, as EditIntf documents); (0, 0) for none. Setting
  them moves neither the cursor nor the other end and leaves the block hidden or shown. }
function TSdOtaSourceEditor.BlockEnd(First: Boolean): TOTACharPos;
var
  E: TSciEdit;
  Blk: TSciBlock;
  P: Integer;
begin
  Result := OtaCharPos(0, 0);
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  if Blk.Mode = sbColumn then
  begin
    if First then Result := OtaCharPos(Blk.Rows.Top + 1, Blk.Rows.Left + 1)
    else Result := OtaCharPos(Blk.Rows.Bottom + 1, Blk.Rows.Right + 1);
    if (Result.Line <= 0) or (Result.CharIndex <= 0) then Result := OtaCharPos(0, 0);
  end
  else
  begin
    if First then P := Blk.A else P := Blk.B;
    if P >= 0 then Result := OffsetToCharPos(E, P);
  end;
end;

procedure TSdOtaSourceEditor.SetBlockEnd(First: Boolean; const Value: TOTACharPos);
var
  E: TSciEdit;
  Blk: TSciBlock;
  P: Integer;
begin
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  if Blk.Mode = sbColumn then
  begin
    if First then
    begin
      Blk.Rows.Left := Value.CharIndex - 1;
      Blk.Rows.Top := Value.Line - 1;
    end
    else
    begin
      Blk.Rows.Right := Value.CharIndex - 1;
      Blk.Rows.Bottom := Value.Line - 1;
    end;
  end
  else
  begin
    if Value.Line < 1 then P := -1 else P := CharPosToOffset(E, Value);
    if First then Blk.A := P else Blk.B := P;
  end;
  E.SetBufferBlock(Blk);
end;

function TSdOtaSourceEditor.GetBlockAfter: TOTACharPos;
begin
  Result := BlockEnd(False);
end;

function TSdOtaSourceEditor.GetBlockStart: TOTACharPos;
begin
  Result := BlockEnd(True);
end;

{ the kind: ToolsAPI's TOTABlockType is the order of TSciBlockMode (a rectangle the user selected
  is btColumn) }
function TSdOtaSourceEditor.GetBlockType: TOTABlockType;
var
  E: TSciEdit;
  Blk: TSciBlock;
begin
  Result := btUnknown;
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  Result := TOTABlockType(Ord(Blk.Mode));
end;

{ Delphi's: not hidden, and marked - or an empty non-inclusive block that has its ends }
function TSdOtaSourceEditor.GetBlockVisible: Boolean;
var
  E: TSciEdit;
  Blk: TSciBlock;
begin
  Result := False;
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  { Delphi 7's (measured): a marked block only with Persistent blocks - without them its block is the
    selection's and BlockVisible False -, or an empty block that is not hidden }
  Result := not Blk.Hidden and ((EditorOptions.PersistentBlocks and E.BlockMarked) or
    ((Blk.Mode = sbNonInclusive) and (Blk.A = Blk.B) and (Blk.A >= 0)));
end;

procedure TSdOtaSourceEditor.SetBlockAfter(const Value: TOTACharPos);
begin
  SetBlockEnd(False, Value);
end;

procedure TSdOtaSourceEditor.SetBlockStart(const Value: TOTACharPos);
begin
  SetBlockEnd(True, Value);
end;

{ Delphi's TEditSource.SetBlockType: the kind changes; a marked block keeps its place (a stream
  block's ends become the corners and back), another is not reset }
procedure TSdOtaSourceEditor.SetBlockType(Value: TOTABlockType);
var
  E: TSciEdit;
begin
  E := Ed;
  if (E <> nil) and (Value < btUnknown) then E.BlockSetMode(TSciBlockMode(Ord(Value)), False);
end;

procedure TSdOtaSourceEditor.SetBlockVisible(Value: Boolean);
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockSetHidden(not Value);
end;

procedure TSdOtaSourceEditor.ClearUndo;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.Sci(SCI_EMPTYUNDOBUFFER);
end;

function TSdOtaSourceEditor.GetBufferOptions: IOTABufferOptions;
begin
  Result := TSdOtaBufferOptions.Create(FileTypeIndexOf(FFileName));
end;

function FileTime(const FileName: string): TDateTime;
var
  A: Integer;
begin
  A := FileAgeU(FileName);                 // marked Unicode names too
  if A = -1 then Result := Now else Result := FileDateToDateTime(A);
end;

{ while the text is modified: the time of its last change - experts compare it with the time of
  their last look, so it stays put between changes (one modified without a known change gets the
  time of the first question); else the file's time }
function TSdOtaSourceEditor.GetCurrentDate: TDateTime;
begin
  if GetModified then
  begin
    if FModule.State.ChangedAt = 0 then FModule.State.ChangedAt := Now;
    Result := FModule.State.ChangedAt;
  end
  else
    Result := FileTime(FFileName);
end;

{ the file's time when the IDE read it or last wrote it - not a change made outside since }
function TSdOtaSourceEditor.GetInitialDate: TDateTime;
var
  P: TEditorPage;
  Local: TFileTime;
  ST: TSystemTime;
begin
  P := Page;
  if (P <> nil) and P.FileStamp.Exists and FileTimeToLocalFileTime(P.FileStamp.Time, Local) and
    FileTimeToSystemTime(Local, ST) then
    Result := SystemTimeToDateTime(ST)
  else
    Result := FileTime(FFileName);
end;

function TSdOtaSourceEditor.GetEditBlock: IOTAEditBlock;
var
  V: IOTAEditView;
begin
  V := GetTopView;
  if V <> nil then Result := V.Block else Result := nil;
end;

function TSdOtaSourceEditor.GetEditLineTracker: IOTAEditLineTracker;
begin
  Result := FModule.Tracker;
end;

function TSdOtaSourceEditor.GetEditPosition: IOTAEditPosition;
var
  V: IOTAEditView;
begin
  V := GetTopView;
  if V <> nil then Result := V.Position else Result := nil;
end;

function TSdOtaSourceEditor.GetIsModified: Boolean;
begin
  Result := GetModified;
end;

function TSdOtaSourceEditor.GetIsReadOnly: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.ReadOnly;
end;

function TSdOtaSourceEditor.GetTopView: IOTAEditView;
begin
  Result := GetEditView(0);
end;

function TSdOtaSourceEditor.Print: Boolean;
begin
  Show;
  Result := OtaHost.ExecuteAction('FilePrintCommand');
end;

function TSdOtaSourceEditor.Redo: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.CanRedo;
  if Result then E.Redo;
end;

procedure TSdOtaSourceEditor.SetIsReadOnly(Value: Boolean);
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.ReadOnly := Value;
end;

function TSdOtaSourceEditor.Undo: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.CanUndo;
  if Result then E.Undo;
end;

function TSdOtaSourceEditor.GetEditOptions: IOTAEditOptions;
begin
  Result := OtaEditOptionsOf(FFileName);
end;

{ ---------------------------------------------------------------- TSdOtaEditWindow }

{ Delphi's edit window is a form of its own: here the stand-in that SdOtaEditWindow makes (class
  TEditWindow, named EditWindow_0), with what experts look up on it by name - the stand-in editor
  control Editor, the popup menus EditorLocalMenu, BackMenu and ForwardMenu, TabControl. Without
  it (no IDE around the services, or coreide70's routines could not be answered) the main
  window, which holds the menus otherwise. The status bar is the main window's. }
function TSdOtaEditWindow.GetForm: TCustomForm;
begin
  Result := EditWindowForm;
  if (Result = nil) and (OtaHost <> nil) then Result := OtaHost.MainForm;
end;

function TSdOtaEditWindow.GetStatusBar: TStatusBar;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.StatusBar;
end;

{ ---------------------------------------------------------------- TSdOtaEditView }

constructor TSdOtaEditView.Create(ABuffer: TSdOtaSourceEditor);
begin
  inherited Create;
  FBuffer := ABuffer;
  FBufferRef := ABuffer;
end;

function TSdOtaEditView.Ed: TSciEdit;
begin
  Result := FBuffer.Ed;
end;

function TSdOtaEditView.Page: TEditorPage;
begin
  Result := FBuffer.Page;
end;

function TSdOtaEditView.OtaFileName: string;
begin
  Result := FBuffer.OtaFileName;
end;

{ the width of a column in pixels (the editor's font is fixed-pitch) }
function TSdOtaEditView.CharWidth: Integer;
var
  E: TSciEdit;
begin
  Result := 8;
  E := Ed;
  if E <> nil then Result := E.SciS(SCI_TEXTWIDTH, STYLE_DEFAULT, 'M');
  if Result <= 0 then Result := 8;
end;

function TSdOtaEditView.GetCursorPos: TOTAEditPos;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then
  begin
    Result := OtaEditPos(1, 1);
    Exit;
  end;
  Result := OffsetToEditPos(E, E.CaretPos);
  Inc(Result.Col, E.Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE, 0));
end;

{ an edit position's place on the editor: the offset of its column (a line beyond the text: the
  last line) and the columns of virtual space past the line's end - Delphi's cursor goes there }
procedure EditPosPlace(E: TSciEdit; const Pos: TOTAEditPos; out P, V: Integer);
var
  L, C: Integer;
begin
  L := Pos.Line - 1;
  if L > E.LineCount - 1 then L := E.LineCount - 1;
  if L < 0 then L := 0;
  C := Pos.Col - 1;
  if C < 0 then C := 0;
  E.ColumnPlace(L, C, P, V);
end;

{ Delphi's TOTAEditView.SetCursorPos writes the view's cursor: no editor command - the block stays
  (without Persistent blocks it is the selection again when the cursor comes to one of its ends) }
procedure TSdOtaEditView.SetCursorPos(const Value: TOTAEditPos);
var
  E: TSciEdit;
  P, V: Integer;
begin
  E := Ed;
  if E = nil then Exit;
  EditPosPlace(E, Value, P, V);
  E.MoveCaretRaw(P, V);
end;

function TSdOtaEditView.GetTopPos: TOTAEditPos;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then
  begin
    Result := OtaEditPos(1, 1);
    Exit;
  end;
  Result.Line := E.Sci(SCI_DOCLINEFROMVISIBLE, E.Sci(SCI_GETFIRSTVISIBLELINE)) + 1;
  Result.Col := E.Sci(SCI_GETXOFFSET) div CharWidth + 1;
end;

procedure TSdOtaEditView.SetTopPos(const Value: TOTAEditPos);
var
  E: TSciEdit;
  L, C: Integer;
begin
  E := Ed;
  if E = nil then Exit;
  L := Value.Line - 1;
  if L < 0 then L := 0;
  E.Sci(SCI_SETFIRSTVISIBLELINE, E.Sci(SCI_VISIBLEFROMDOCLINE, L));
  C := Value.Col - 1;
  if C < 0 then C := 0;
  E.Sci(SCI_SETXOFFSET, C * CharWidth);
end;

function TSdOtaEditView.GetViewSize: TSize;
var
  E: TSciEdit;
begin
  Result.cx := 0;
  Result.cy := 0;
  E := Ed;
  if E = nil then Exit;
  Result.cx := E.ClientWidth div CharWidth;
  Result.cy := E.Sci(SCI_LINESONSCREEN);
end;

function TSdOtaEditView.PosToCharPos(Pos: Longint): TOTACharPos;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := OtaCharPos(1, 0) else Result := OffsetToCharPos(E, Pos);
end;

function TSdOtaEditView.CharPosToPos(CharPos: TOTACharPos): Longint;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := 0 else Result := CharPosToOffset(E, CharPos);
end;

procedure TSdOtaEditView.ConvertPos(EdPosToCharPos: Boolean; var EditPos: TOTAEditPos;
  var CharPos: TOTACharPos);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  if EdPosToCharPos then CharPos := OffsetToCharPos(E, EditPosToOffset(E, EditPos))
  else EditPos := OffsetToEditPos(E, CharPosToOffset(E, CharPos));
end;

{ Delphi's attribute of the text at a place (atComment, atReservedWord ...) and the line's marks }
procedure TSdOtaEditView.GetAttributeAtPos(const EdPos: TOTAEditPos; IncludeMargin: Boolean;
  var Element, LineFlag: Integer);
var
  E: TSciEdit;
  P, L, M: Integer;
begin
  Element := atWhiteSpace;
  LineFlag := 0;
  E := Ed;
  if E = nil then Exit;
  P := EditPosToOffset(E, EdPos);
  L := E.LineFromPos(P);
  M := E.MarkerGet(L);
  if M and (1 shl MK_EXEC) <> 0 then LineFlag := LineFlag or lfCurrentEIP;
  if M and (1 shl MK_BREAK) <> 0 then LineFlag := LineFlag or lfBreakpointEnabled;
  if M and (1 shl MK_BREAK_DISABLED) <> 0 then LineFlag := LineFlag or lfBreakpointDisabled;
  if M and (1 shl MK_BREAK_INVALID) <> 0 then LineFlag := LineFlag or lfBreakpointInvalid;
  if M and (1 shl MK_ERROR_LINE) <> 0 then LineFlag := LineFlag or lfErrorLine;
  if IncludeMargin and EditorOptions.ShowRightMargin and (EdPos.Col = EditorOptions.RightMargin + 1) then
  begin
    Element := RightMargin;
    Exit;
  end;
  { the token's attribute - Delphi 7's gives no MarkedBlock inside the block (measured) }
  Element := OtaAttributeAt(E, P);
end;

function OtaAttributeAt(Ed: TSciEdit; P: Integer): Integer;
var
  C: Char;
begin
  Result := atWhiteSpace;
  if (Ed = nil) or not Ed.Ready then Exit;
  { a file without highlighting: SyntaxOff everywhere, as Delphi 7's (measured) }
  if Ed.Language = slNone then
  begin
    Result := SyntaxOff;
    Exit;
  end;
  if (P < 0) or (P >= Ed.TextLength) then Exit;
  if P >= Ed.LineEndPos(Ed.LineFromPos(P)) then Exit;
  { an expert's highlighter: the code it gave the byte - styled first when it is not yet (the
    lines are styled as they are shown) }
  if Ed.Language = slExpert then
  begin
    if P >= Ed.Sci(SCI_GETENDSTYLED) then Ed.Sci(SCI_COLOURISE, Ed.Sci(SCI_GETENDSTYLED), P + 1);
    Result := Ed.StyleAt(P);
    Exit;
  end;
  C := Ed.CharAt(P);
  if C in [' ', #9, #13, #10, #0] then Exit;
  if Ed.Language = slPascal then
    case Ed.StyleAt(P) of
      SCE_PAS_IDENTIFIER: Result := atIdentifier;
      SCE_PAS_COMMENT, SCE_PAS_COMMENT2, SCE_PAS_COMMENTLINE: Result := atComment;
      SCE_PAS_PREPROCESSOR, SCE_PAS_PREPROCESSOR2: Result := atPreproc;
      SCE_PAS_NUMBER: Result := atNumber;
      SCE_PAS_HEXNUMBER: Result := atHex;
      SCE_PAS_WORD: Result := atReservedWord;
      SCE_PAS_STRING, SCE_PAS_STRINGEOL, SCE_PAS_CHARACTER, SCE_PAS_MULTILINESTRING: Result := atString;
      SCE_PAS_OPERATOR: Result := atSymbol;
      SCE_PAS_ASM: Result := atAssembler;
    else
      Result := atIdentifier;
    end
  else if Ed.IsIdentChar(C) then Result := atIdentifier
  else Result := atSymbol;
end;

function TSdOtaEditView.SameView(EditView: IOTAEditView): Boolean;
var
  F: ISdOtaFile;
begin
  Result := Supports(EditView, ISdOtaFile, F) and SameText(F.OtaFileName, OtaFileName);
end;

{ a cursor command of Delphi's editor (BlockMoveBegin) }
function TSdOtaEditView.BookmarkGoto(BookmarkID: Integer): Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (P <> nil) and (BookmarkID in [0..9]) and
    (P.Editor.MarkerNext(0, 1 shl (MK_BOOKMARK0 + BookmarkID)) >= 0);
  if not Result then Exit;
  P.Editor.BlockMoveBegin(True);
  P.GotoBookmark(BookmarkID);
  P.Editor.BlockMoveEnd;
end;

function TSdOtaEditView.BookmarkRecord(BookmarkID: Integer): Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (P <> nil) and (Ed <> nil) and (BookmarkID in [0..9]);
  if Result then P.SetBookmark(BookmarkID);
end;

function TSdOtaEditView.BookmarkToggle(BookmarkID: Integer): Boolean;
var
  P: TEditorPage;
begin
  P := Page;
  Result := (P <> nil) and (BookmarkID in [0..9]);
  if Result then P.ToggleBookmark(BookmarkID);
end;

procedure TSdOtaEditView.Center(Row, Col: Integer);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  E.BlockMoveBegin(True);
  E.GotoLineCol(Row - 1, Col - 1, True);
  E.BlockMoveEnd;
end;

function TSdOtaEditView.GetBlock: IOTAEditBlock;
begin
  Result := TSdOtaEditBlock.Create(Self);
end;

function TSdOtaEditView.GetBookmarkPos(BookmarkID: Integer): TOTACharPos;
var
  E: TSciEdit;
  L: Integer;
begin
  Result := OtaCharPos(0, 0);
  E := Ed;
  if (E = nil) or not (BookmarkID in [0..9]) then Exit;
  L := E.MarkerNext(0, 1 shl (MK_BOOKMARK0 + BookmarkID));
  if L >= 0 then Result := OtaCharPos(L + 1, Page.BookmarkCol(BookmarkID));
end;

function TSdOtaEditView.GetBottomRow: Integer;
begin
  Result := GetTopRow + GetViewSize.cy;
end;

function TSdOtaEditView.GetBuffer: IOTAEditBuffer;
begin
  Result := FBufferRef;
end;

function TSdOtaEditView.GetEditWindow: INTAEditWindow;
begin
  Result := TSdOtaEditWindow.Create;
end;

function TSdOtaEditView.GetLastEditColumn: Integer;
begin
  Result := FBuffer.Module.State.LastEdit.Col;
end;

function TSdOtaEditView.GetLastEditRow: Integer;
begin
  Result := FBuffer.Module.State.LastEdit.Line;
end;

function TSdOtaEditView.GetLeftColumn: Integer;
begin
  Result := GetTopPos.Col;
end;

function TSdOtaEditView.GetPosition: IOTAEditPosition;
begin
  Result := TSdOtaEditPosition.Create(Self);
end;

function TSdOtaEditView.GetRightColumn: Integer;
begin
  Result := GetLeftColumn + GetViewSize.cx - 1;
end;

function TSdOtaEditView.GetTopRow: Integer;
begin
  Result := GetTopPos.Line;
end;

procedure TSdOtaEditView.MoveCursorToView;
var
  E: TSciEdit;
  Top, Bottom, L: Integer;
begin
  E := Ed;
  if E = nil then Exit;
  Top := GetTopRow - 1;
  Bottom := Top + E.Sci(SCI_LINESONSCREEN) - 1;
  L := E.CaretLine;
  if L < Top then E.MoveCaretKernel(E.PosFromLine(Top), 0)
  else if L > Bottom then E.MoveCaretKernel(E.PosFromLine(Bottom), 0);
end;

procedure TSdOtaEditView.MoveViewToCursor;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.Sci(SCI_SCROLLCARET);
end;

{ an editor command that moves the cursor: a cursor command of Delphi's editor (the block first) }
procedure TSdOtaEditView.CursorCommand(Msg: Cardinal);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  E.BlockMoveBegin(True);
  E.Sci(Msg);
  E.BlockMoveEnd;
end;

procedure TSdOtaEditView.PageDown;
begin
  CursorCommand(SCI_PAGEDOWN);
end;

procedure TSdOtaEditView.PageUp;
begin
  CursorCommand(SCI_PAGEUP);
end;

procedure TSdOtaEditView.Paint;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.Invalidate;
end;

function TSdOtaEditView.Scroll(DeltaRow: Integer; DeltaCol: Integer): Integer;
var
  E: TSciEdit;
  Before: Integer;
begin
  Result := 0;
  E := Ed;
  if E = nil then Exit;
  Before := E.Sci(SCI_GETFIRSTVISIBLELINE);
  E.Sci(SCI_LINESCROLL, DeltaCol, DeltaRow);
  Result := E.Sci(SCI_GETFIRSTVISIBLELINE) - Before;
end;

procedure TSdOtaEditView.SetTopLeft(TopRow, LeftCol: Integer);
var
  P: TOTAEditPos;
begin
  P := GetTopPos;
  if TopRow > 0 then P.Line := TopRow;
  if LeftCol > 0 then P.Col := LeftCol;
  SetTopPos(P);
end;

procedure TSdOtaEditView.SetTempMsg(const Msg: string);
begin
  if IDE <> nil then IDE.ShowStatus(Msg);
end;

{ the edit actions: the main window's commands, run on this view's file }
procedure TSdOtaEditView.Act(const Name: string);
begin
  if OtaHost = nil then Exit;
  if Page <> nil then OtaHost.ShowPage(Page);
  OtaHost.ExecuteAction(Name);
end;

procedure TSdOtaEditView.OtherPage(Delta: Integer);
var
  I, N: Integer;
begin
  if OtaHost = nil then Exit;
  N := OtaHost.PageCount;
  if N = 0 then Exit;
  for I := 0 to N - 1 do
    if OtaHost.Pages(I) = OtaHost.ActivePage then
    begin
      OtaHost.ShowPage(OtaHost.Pages((I + Delta + N) mod N));
      Exit;
    end;
end;

procedure TSdOtaEditView.AddWatch; begin Act('RunAddWatchCommand'); end;
procedure TSdOtaEditView.AddWatchAtCursor; begin Act('RunAddWatchCommand'); end;
procedure TSdOtaEditView.BrowseSymbolAtCursor; begin Act('aBrowseSymbolAtCursor'); end;
procedure TSdOtaEditView.ClassComplete; begin Act('ecCompleteClass'); end;

procedure TSdOtaEditView.ClassNavigate(Reserved: TClassNavigateStyle);
var
  P: TEditorPage;
begin
  P := Page;
  if P <> nil then P.SimulateKey(VK_UP, [ssCtrl, ssShift]);
end;

procedure TSdOtaEditView.ClosePage; begin Act('FileCloseCommand'); end;
procedure TSdOtaEditView.CodeTemplate; begin Act('aTemplates'); end;

{ Delphi's: a message to the editor with the key code completion takes - the list (#0 with
  csManual, '.' without: its delay), the parameters (#1 with csManual, '(' without) -, handled
  when the expert's call is over }
procedure TSdOtaEditView.CodeCompletion(Style: TCodeCompleteStyle);
var
  P: TEditorPage;
  Key: Char;
begin
  P := Page;
  if (P = nil) or not P.HandleAllocated then Exit;
  if Style and csParamList <> 0 then
  begin
    if Style and csManual <> 0 then Key := #1 else Key := '(';
  end
  else if Style and csManual <> 0 then
    Key := #0
  else
    Key := '.';
  PostMessage(P.Handle, CM_SD_CODEINSIGHT, Ord(Key), 0);
end;

procedure TSdOtaEditView.EvaluateModify; begin Act('RunEvalModCommand'); end;
procedure TSdOtaEditView.HelpKeyword; begin Act('aTopicSearch'); end;
procedure TSdOtaEditView.IncrementalSearch; begin Act('SearchIncrementalCommand'); end;
{ Delphi's Ctrl+O O: the project's compiler options as directives at the caret - the switches,
  the stack sizes and image base, the application type, the warnings }
procedure TSdOtaEditView.InsertCompilerOptions;
const
  Letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  OnOff: array[Boolean] of string = ('OFF', 'ON');
var
  E: TSciEdit;
  P: TSdProject;
  S: string;
  C: Char;
  I, V: Integer;
begin
  E := Ed;
  if (E = nil) or (OtaHost = nil) or (OtaHost.Project = nil) then Exit;
  P := OtaHost.Project;
  S := '{$';
  for I := 1 to Length(Letters) do
  begin
    C := Letters[I];
    V := P.OptInt('Compiler', C, CompilerSwitchDefault(C));
    if I > 1 then S := S + ',';
    case C of
      'A', 'Z': S := S + C + IntToStr(V);
      'Y':
        case V of
          0: S := S + 'Y-';
          1: S := S + 'YD';
        else
          S := S + 'Y+';
        end;
    else
      if V <> 0 then S := S + C + '+' else S := S + C + '-';
    end;
  end;
  S := S + '}'#13#10 + Format('{$MINSTACKSIZE $%.8x}'#13#10'{$MAXSTACKSIZE $%.8x}'#13#10'{$IMAGEBASE $%.8x}'#13#10,
    [P.OptInt('Linker', 'MinStackSize', 16384), P.OptInt('Linker', 'MaxStackSize', 1048576),
     P.OptInt('Linker', 'ImageBase', $400000)]);
  if not P.IsPackage then
    if P.OptInt('Linker', 'ConsoleApp', 1) = 0 then S := S + '{$APPTYPE CONSOLE}'#13#10
    else S := S + '{$APPTYPE GUI}'#13#10;
  for I := Low(CompilerWarnings) to High(CompilerWarnings) do
    S := S + Format('{$WARN %s %s}'#13#10, [CompilerWarnings[I].Ident,
      OnOff[P.OptInt('Compiler', CompilerWarnings[I].Key, Ord(WarningOnByDefault(CompilerWarnings[I]))) <> 0]]);
  E.ReplaceSel(OtaToEditor(Page, S));
end;

{ Delphi's Shift+Ctrl+G: a new GUID in brackets and quotes at the caret }
procedure TSdOtaEditView.InsertNewGUID;
var
  G: TGUID;
  E: TSciEdit;
  S: string;
begin
  E := Ed;
  if (E = nil) or (CreateGUID(G) <> S_OK) then Exit;
  S := '[''' + GUIDToString(G) + ''']';
  E.ReplaceSel(S);
end;

procedure TSdOtaEditView.InspectAtCursor; begin Act('RunInspectCommand'); end;
procedure TSdOtaEditView.CompileProject; begin Act('ProjectCompileCommand'); end;
procedure TSdOtaEditView.NextError; begin if OtaHost <> nil then OtaHost.StepMessage(1); end;
procedure TSdOtaEditView.NextPage; begin OtherPage(1); end;
procedure TSdOtaEditView.OpenFile; begin Act('FileOpenCommand'); end;
procedure TSdOtaEditView.OpenFileAtCursor; begin Act('aOpenFileAtCursor'); end;
procedure TSdOtaEditView.PriorError; begin if OtaHost <> nil then OtaHost.StepMessage(-1); end;
procedure TSdOtaEditView.PriorPage; begin OtherPage(-1); end;
procedure TSdOtaEditView.ProgramReset; begin Act('RunResetCommand'); end;
procedure TSdOtaEditView.RunProgram; begin Act('RunRunCommand'); end;
procedure TSdOtaEditView.RunToCursor; begin Act('RunGotoCursorCommand'); end;
procedure TSdOtaEditView.SaveAll; begin Act('FileSaveAllCommand'); end;
procedure TSdOtaEditView.Save; begin Act('FileSaveCommand'); end;
procedure TSdOtaEditView.SaveAs; begin Act('FileSaveAsCommand'); end;
procedure TSdOtaEditView.StepOver; begin Act('RunStepOverCommand'); end;
{ Delphi 7 swaps later (measured): the request is posted - by the time it runs, an expert has let go
  of the editors it replaces (Delphi 7 raises an exception for one still held) }
procedure TSdOtaEditView.SwapSourceFormView;
begin
  if OtaHost <> nil then OtaHost.SwapSourceFormLater(Page);
end;
procedure TSdOtaEditView.SwapCPPHeader; begin end;
procedure TSdOtaEditView.ToggleFormUnit; begin Act('ViewToggleFormCommand'); end;
procedure TSdOtaEditView.TraceInto; begin Act('RunTraceIntoCommand'); end;
procedure TSdOtaEditView.TraceToSource; begin Act('RunTraceToSourceCommand'); end;
procedure TSdOtaEditView.ViewExplorer; begin Act('ViewCodeExplorerCommand'); end;
procedure TSdOtaEditView.ViewForms; begin Act('ViewFormCommand'); end;
procedure TSdOtaEditView.ViewObjectInspector; begin Act('ViewObjInspCommand'); end;
procedure TSdOtaEditView.ViewUnits; begin Act('ViewUnitCommand'); end;
procedure TSdOtaEditView.WindowList; begin Act('ViewWindowListCommand'); end;
procedure TSdOtaEditView.ZoomWindow; begin end;
procedure TSdOtaEditView.NextBufferView; begin OtherPage(1); end;
procedure TSdOtaEditView.PreviousBufferView; begin OtherPage(-1); end;

{ ---------------------------------------------------------------- TSdOtaEditPosition }

constructor TSdOtaEditPosition.Create(AView: TSdOtaEditView);
begin
  inherited Create;
  FView := AView;
  FViewRef := AView;
end;

function TSdOtaEditPosition.Ed: TSciEdit;
begin
  Result := FView.Ed;
end;

function TSdOtaEditPosition.Page: TEditorPage;
begin
  Result := FView.Page;
end;

function TSdOtaEditPosition.Caret: Integer;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := 0 else Result := E.CaretPos;
end;

{ CaretTo, CharacterOf and ColumnOf work on the editor E (not nil) the caller has found already:
  a loop of MoveCursor asks them for every character (GetCharacter and GetColumn find it first).
  CaretTo: the caret put at P, nothing else - inside a cursor command bracketed by the block's
  BlockMoveBegin / BlockMoveEnd }
procedure TSdOtaEditPosition.CaretTo(E: TSciEdit; P: Integer);
begin
  if P < 0 then P := 0;
  if P > E.TextLength then P := E.TextLength;
  E.Sci(SCI_SETEMPTYSELECTION, P);
  E.Sci(SCI_CHOOSECARETX);
end;

function TSdOtaEditPosition.CharacterOf(E: TSciEdit): Char;
var
  P: Integer;
begin
  P := E.CaretPos;
  if P >= E.TextLength then Result := #0
  else if P >= E.LineEndPos(E.LineFromPos(P)) then Result := #13
  else Result := E.CharAt(P);
end;

function TSdOtaEditPosition.ColumnOf(E: TSciEdit): Integer;
begin
  Result := OffsetColumn(E, E.CaretPos) + E.Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE, 0);
end;

{ a cursor command of Delphi's editor: without Persistent blocks it collapses the block first (the
  user's moves alike: their block calls see it) }
function TSdOtaEditPosition.KernelMove(P: Integer): Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := E <> nil;
  if Result then E.MoveCaretKernel(P, 0);
end;

{ Delphi 7's classes of its editor (the callbacks coreide70 gives its kernel: EkIsWordChar,
  EkIsWhiteSpace, EkIsSpecialChar): 0 a word character - a letter, a digit, '_', a byte of a
  character beyond ASCII -, 1 white space - a tab or a space only -, 2 anything else (special),
  the line end (#13) and the file's end (#0) too }
function TSdOtaEditPosition.CharClass(C: Char): Integer;
begin
  if C in ['A'..'Z', 'a'..'z', '0'..'9', '_', #128..#255] then Result := 0
  else if C in [' ', #9] then Result := 1
  else Result := 2;
end;

procedure TSdOtaEditPosition.Align(Magnitude: Integer);
var
  E: TSciEdit;
  Col: Integer;
begin
  E := Ed;
  if (E = nil) or (Magnitude < 1) then Exit;
  Col := GetColumn;
  if Col < Magnitude then InsertEditorText(StringOfChar(' ', Magnitude - Col));
end;

{ Delphi's Backspace and Delete: before the first character the typing rule of the block
  (BlockBeforeTyping) - a marked block it deletes counts as that character }
function TSdOtaEditPosition.BackspaceDelete(HowMany: Integer): Boolean;
var
  E: TSciEdit;
  P, A: Integer;
begin
  E := Ed;
  Result := (E <> nil) and (HowMany > 0);
  if not Result then Exit;
  if E.BlockBeforeTyping then Dec(HowMany);
  P := Caret;
  A := P;
  while (HowMany > 0) and (A > 0) do
  begin
    A := E.Sci(SCI_POSITIONBEFORE, A);
    Dec(HowMany);
  end;
  if A < P then E.DeleteRange(A, P - A);
  E.MoveCaretRaw(A, 0);
end;

function TSdOtaEditPosition.DeleteChars(HowMany: Integer): Boolean;
var
  E: TSciEdit;
  P, B: Integer;
begin
  E := Ed;
  Result := (E <> nil) and (HowMany > 0);
  if not Result then Exit;
  if E.BlockBeforeTyping then Dec(HowMany);
  P := Caret;
  B := P;
  while (HowMany > 0) and (B < E.TextLength) do
  begin
    B := E.Sci(SCI_POSITIONAFTER, B);
    Dec(HowMany);
  end;
  if B > P then E.DeleteRange(P, B - P);
end;

function TSdOtaEditPosition.DistanceToTab(Direction: TSearchDirection): Integer;
var
  E: TSciEdit;
  W, Col: Integer;
begin
  Result := 0;
  E := Ed;
  if E = nil then Exit;
  W := E.Sci(SCI_GETTABWIDTH);
  if W <= 0 then W := 8;
  Col := GetColumn - 1;
  if Direction = sdForward then Result := W - Col mod W
  else
  begin
    Result := Col mod W;
    if (Result = 0) and (Col > 0) then Result := W;
  end;
end;

{ the byte at the cursor, as Delphi's buffer has it: #13 at a line's end (Delphi keeps CR LF,
  whatever the file has), #0 at the file's end }
function TSdOtaEditPosition.GetCharacter: Char;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := #0 else Result := CharacterOf(E);
end;

function TSdOtaEditPosition.GetColumn: Integer;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := 1 else Result := ColumnOf(E);
end;

function TSdOtaEditPosition.GetIsSpecialCharacter: Boolean;
begin
  Result := CharClass(GetCharacter) = 2;
end;

function TSdOtaEditPosition.GetIsWhitespace: Boolean;
begin
  Result := CharClass(GetCharacter) = 1;
end;

function TSdOtaEditPosition.GetIsWordCharacter: Boolean;
begin
  Result := CharClass(GetCharacter) = 0;
end;

function TSdOtaEditPosition.GetLastRow: Integer;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := 0 else Result := E.LineCount;
end;

function TSdOtaEditPosition.GetReplaceOptions: IOTAReplaceOptions;
begin
  Result := OtaModules.SearchOptions;
end;

function TSdOtaEditPosition.GetRow: Integer;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := 1 else Result := E.CaretLine + 1;
end;

{ Delphi 7's texts of the search's error codes (measured) - 0 is none: a pattern not found is no
  error }
function TSdOtaEditPosition.GetSearchErrorString(ErrorCode: Integer): string;
const
  Texts: array[0..14] of string = ('',
    'Tried to search selected text from cursor but cursor is outside selected text',
    'Tried to search selected text but no text is selected',
    'Tried to search selected text but no text is selected',
    'The search string cannot be blank.',
    'Search pattern too big',
    'Too many {}s',
    'Unmatched ()s',
    'Unmatched {}s',
    'A * or + operand could be empty',
    'Cannot nest the a *, +, or ? operator',
    'Invalid [] range',
    'Unmatched []s',
    'A ?, +, or * should follow a character',
    'Trailing ''\''');
begin
  if (ErrorCode >= Low(Texts)) and (ErrorCode <= High(Texts)) then Result := Texts[ErrorCode]
  else Result := 'Internal error';
end;

function TSdOtaEditPosition.GetSearchOptions: IOTASearchOptions;
begin
  Result := OtaModules.SearchOptions;
end;

{ Delphi's GotoLine: a line of 0 or less opens the Go to Line Number dialog }
function TSdOtaEditPosition.GotoLine(LineNumber: Integer): Boolean;
var
  E: TSciEdit;
begin
  Result := False;
  E := Ed;
  if E = nil then Exit;
  if LineNumber <= 0 then
  begin
    if OtaHost = nil then Exit;
    if Page <> nil then OtaHost.ShowPage(Page);
    Result := OtaHost.ExecuteAction('SearchGoToCommand');
    Exit;
  end;
  Result := LineNumber <= E.LineCount;
  if Result then KernelMove(E.PosFromLine(LineNumber - 1));
end;

procedure TSdOtaEditPosition.InsertBlock(const Block: IOTAEditBlock);
begin
  if Block <> nil then InsertText(Block.Text);
end;

{ Delphi's InsertCharacter is a key press (the edit control's HandleKeyPress): after the block's
  typing rule the character is typed - the page's handlers, Auto-close pairs and the insert mode
  see it -, a line break and a tab as their keys, a backspace as BackspaceDelete. A byte beyond
  ASCII goes in as text: in UTF-8 mode, the IDE's code page, it is no character of its own. }
procedure TSdOtaEditPosition.InsertCharacter(Character: Char);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  if Character = #8 then
  begin
    BackspaceDelete(1);
    Exit;
  end;
  E.BlockBeforeTyping;
  case Character of
    #13, #10: E.PlayKey(VK_RETURN, []);
    #9: E.PlayKey(VK_TAB, []);
    #32..#126: E.PlayChar(Character);
  else
    InsertEditorText(OtaToEditor(Page, Character));
  end;
end;

{ Delphi's InsertFile: the file in its own encoding (as Read Block from File; no name: that
  command's dialog), after the block's typing rule; with Persistent blocks the text read becomes
  the block, without them the block is collapsed (hidden) at the cursor after it }
procedure TSdOtaEditPosition.InsertFile(const FileName: string);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  if FileName = '' then
  begin
    E.ExecCommand(ecBlockRead, 0);
    Exit;
  end;
  if not FileExistsU(FileName) then Exit;
  E.BlockBeforeTyping;
  MarkInserted(InsertEditorText(ReadSourceFileAs(FileName, E.Encoding)));
end;

{ Delphi's InsertText: after the block's typing rule, the text at the cursor (virtual space
  filled with blanks first), the cursor after it; with Persistent blocks the block follows }
procedure TSdOtaEditPosition.InsertText(const Text: string);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  E.BlockBeforeTyping(True);
  InsertEditorText(OtaToEditor(Page, Text));
end;

{ editor text at the caret, after the virtual space there (filled with blanks); the caret after
  it. The result: where the text starts }
function TSdOtaEditPosition.InsertEditorText(const S: string): Integer;
var
  E: TSciEdit;
  P, V: Integer;
  T: string;
begin
  Result := 0;
  E := Ed;
  if E = nil then Exit;
  P := Caret;
  V := E.Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE, 0);
  T := S;
  if V > 0 then T := StringOfChar(' ', V) + T;
  E.InsertText(P, T);
  E.MoveCaretRaw(P + Length(T), 0);
  Result := P + V;
end;

{ Delphi's Move: a row or a column of 0 or less is the cursor's, the column at most 1024, the row
  at most the last; a cursor command of the editor (KernelMove). True when the cursor moved. }
function TSdOtaEditPosition.MoveTo(Row, Col: Integer): Boolean;
var
  E: TSciEdit;
  Before, After: TOTAEditPos;
  P, V: Integer;
begin
  Result := False;
  E := Ed;
  if E = nil then Exit;
  Before := FView.GetCursorPos;
  if Row <= 0 then Row := Before.Line;
  if Col <= 0 then Col := Before.Col;
  if Col > 1024 then Col := 1024;
  if Row > E.LineCount then Row := E.LineCount;
  EditPosPlace(E, OtaEditPos(Row, Col), P, V);
  E.MoveCaretKernel(P, V);
  After := FView.GetCursorPos;
  Result := (After.Line <> Before.Line) or (After.Col <> Before.Col);
end;

function TSdOtaEditPosition.MoveBOL: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and KernelMove(E.PosFromLine(E.CaretLine));
end;

function TSdOtaEditPosition.MoveEOL: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and KernelMove(E.LineEndPos(E.CaretLine));
end;

function TSdOtaEditPosition.MoveEOF: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and KernelMove(E.TextLength);
end;

{ IOTAEditPosition.MoveCursor as Delphi 7 does it (TOTAEditView.MoveCursor and its editor
  kernel's cursor skip, dfwedit.dll): the class of the mask - word, non-word, white, non-white,
  special, non-special characters - is skipped OVER, the cursor moving while the character in its
  direction is of the class, inside its line; ToolsAPI's comment ("skip to the next ...") says it
  otherwise. Across line ends, with mmSkipStream only (without it a skip stays in its line, measured
  in Delphi 7): a word skip to the left that cannot move at a line's start goes to the end of the
  line above, a word or white skip to the right at a line's end goes to the start of the next line,
  a white skip to the left at a line's start goes on from the end of the line above, and a white
  skip goes on over the white space and line ends around it (TOTAEditView's loop over GetCharacter
  in tab, CR and space). }
function TSdOtaEditPosition.MoveCursor(MoveMask: TMoveCursorMasks): Boolean;
var
  E: TSciEdit;
  Kind: Integer;
  Right, Stream: Boolean;
  C, Prev: Char;

  function InClass(Ch: Char): Boolean;
  var
    K: Integer;
  begin
    K := CharClass(Ch);
    case Kind of
      mmSkipWord: Result := K = 0;
      mmSkipNonWord: Result := K <> 0;
      mmSkipWhite: Result := K = 1;
      mmSkipNonWhite: Result := K <> 1;
      mmSkipSpecial: Result := K = 2;
      mmSkipNonSpecial: Result := K <> 2;
    else
      Result := False;
    end;
  end;

  { one skip of the kernel }
  procedure Skip;
  var
    P, Start, Line, LineStart, LineEnd: Integer;
  begin
    P := E.CaretPos;
    Line := E.LineFromPos(P);
    LineStart := E.PosFromLine(Line);
    LineEnd := E.LineEndPos(Line);
    if P > LineEnd then P := LineEnd;
    if Right then
    begin
      if Stream and ((Kind = mmSkipWord) or (Kind = mmSkipWhite)) and (P >= LineEnd) then
      begin
        if Line + 1 < E.LineCount then CaretTo(E, E.PosFromLine(Line + 1));
        Exit;
      end;
      while (P < LineEnd) and InClass(E.CharAt(P)) do Inc(P);
    end
    else
    begin
      if Stream and (Kind = mmSkipWhite) and (P <= LineStart) and (Line > 0) then
      begin
        Dec(Line);
        LineStart := E.PosFromLine(Line);
        P := E.LineEndPos(Line);
      end;
      Start := P;
      while (P > LineStart) and InClass(E.CharAt(P - 1)) do Dec(P);
      if Stream and (Kind = mmSkipWord) and (P = Start) and (P = LineStart) and (Line > 0) then
        P := E.LineEndPos(Line - 1);
    end;
    CaretTo(E, P);
  end;

  function White(Ch: Char): Boolean;
  begin
    Result := Ch in [#9, #13, ' '];
  end;

  { the cursor's row (GetRow) }
  function Row: Integer;
  begin
    Result := E.CaretLine + 1;
  end;

  { one more skip of the white loop: False when it could not move (the file's end) }
  function SkipOn: Boolean;
  var
    Before: Integer;
  begin
    Before := E.CaretPos;
    Prev := C;
    Skip;
    C := CharacterOf(E);
    Result := E.CaretPos <> Before;
  end;

begin
  E := Ed;
  Result := (E <> nil) and (Row <= E.LineCount);
  if not Result then Exit;
  Kind := MoveMask and $0F;
  Right := MoveMask and mmSkipRight <> 0;
  Stream := MoveMask and mmSkipStream <> 0;
  { a cursor command of the editor (the skip): the block first, as KernelMove }
  E.BlockMoveBegin(True);
  try
    Skip;
    if Stream and (MoveMask and $07 = mmSkipWhite) then
    begin
      C := CharacterOf(E);
      Prev := C;
      repeat
        while (Row < E.LineCount) and (Row <> 1) and (ColumnOf(E) = 1) and White(C) do
          if not SkipOn then Break;
        if not (Right and (ColumnOf(E) <> 1) and White(Prev) and White(C)) then Break;
      until not SkipOn;
    end;
    E.Sci(SCI_SCROLLCARET);
  finally
    E.BlockMoveEnd;
  end;
end;

{ Delphi's MoveReal is Move on the line number frozen by the edits (D7 Studio has none of them:
  the line now), the column a screen column }
function TSdOtaEditPosition.MoveReal(Row, Col: Integer): Boolean;
begin
  Result := MoveTo(Row, Col);
end;

{ Delphi 7's MoveRelative (measured): a Move by the distances - past a line's end into virtual
  space, never across a line's end, the row and the column 1 at least }
function TSdOtaEditPosition.MoveRelative(Row, Col: Integer): Boolean;
var
  R, C: Integer;
begin
  R := GetRow + Row;
  if R < 1 then R := 1;
  C := GetColumn + Col;
  if C < 1 then C := 1;
  Result := MoveTo(R, C);
end;

{ Delphi's Paste (Edkrnl.ClipPaste): without Persistent blocks a marked block is deleted first
  (Overwrite blocks) and the block is collapsed at the cursor afterwards; with them the text
  pasted becomes the block }
procedure TSdOtaEditPosition.Paste;
var
  E: TSciEdit;
  P: Integer;
begin
  E := Ed;
  if E = nil then Exit;
  E.BlockBeforeTyping;
  P := Caret;
  E.Paste;
  MarkInserted(P);
end;

{ Delphi's insertion from a callback (InsertFile, Paste): the text from P to the cursor becomes the
  block - of the kind the block has - with Persistent blocks; without them the block is collapsed
  (hidden) at the cursor }
procedure TSdOtaEditPosition.MarkInserted(P: Integer);
var
  E: TSciEdit;
  Blk: TSciBlock;
  M: TSciBlockMode;
begin
  E := Ed;
  if E = nil then Exit;
  if not EditorOptions.PersistentBlocks then
  begin
    E.BlockCollapse;
    Exit;
  end;
  E.GetBufferBlock(Blk);
  M := Blk.Mode;
  Blk.Mode := sbNonInclusive;
  Blk.A := P;
  Blk.B := Caret;
  Blk.Hidden := False;
  E.SetBufferBlock(Blk);
  if M <> sbNonInclusive then E.BlockSetMode(M, False);
end;

function TSdOtaEditPosition.ReadChars(NumberOfCharacters: Integer): string;
var
  E: TSciEdit;
  P, B, Len: Integer;
begin
  Result := '';
  E := Ed;
  if (E = nil) or (NumberOfCharacters <= 0) then Exit;
  P := E.CaretPos;
  B := P;
  Len := E.TextLength;
  while (NumberOfCharacters > 0) and (B < Len) do
  begin
    B := E.Sci(SCI_POSITIONAFTER, B);
    Dec(NumberOfCharacters);
  end;
  Result := OtaFromEditor(Page, E.GetRange(P, B));
end;

{ the range of a search or a replacement as Delphi 7's editor has it (measured): Selected, the
  marked block (none: error 2), else the whole text; an empty pattern: error 4 }
function TSdOtaEditPosition.SearchRange(E: TSciEdit; const Pattern: string; Selected: Boolean;
  var ErrorCode, Lo, Hi: Integer): Boolean;
begin
  Result := False;
  if Pattern = '' then
  begin
    ErrorCode := 4;
    Exit;
  end;
  Lo := 0;
  Hi := E.TextLength;
  if Selected and not E.BlockMarkedSpan(Lo, Hi) then
  begin
    ErrorCode := 2;
    Exit;
  end;
  Result := True;
end;

{ the search's range (SearchRange); FromCursor, from the cursor (error 1 when it lies outside the
  block), else from the range's start - its end backward }
function TSdOtaEditPosition.FindMatch(const Pattern: string; CaseSensitive, RegExp, Selected, FromCursor,
  Forward: Boolean; var ErrorCode, MatchStart, MatchEnd: Integer): Boolean;
var
  E: TSciEdit;
  Lo, Hi, From: Integer;
begin
  Result := False;
  ErrorCode := 0;
  E := Ed;
  if (E = nil) or not SearchRange(E, Pattern, Selected, ErrorCode, Lo, Hi) then Exit;
  if FromCursor then
  begin
    From := E.CaretPos;
    if (From < Lo) or (From > Hi) then
    begin
      ErrorCode := 1;
      Exit;
    end;
  end
  else if Forward then From := Lo
  else From := Hi;
  if Forward then
    Result := E.FindSpan(Pattern, CaseSensitive, OtaModules.SearchOptions.WordBoundary, RegExp, From, Hi,
      MatchStart, MatchEnd)
  else
    Result := E.FindSpan(Pattern, CaseSensitive, OtaModules.SearchOptions.WordBoundary, RegExp, From, Lo,
      MatchStart, MatchEnd);
end;

{ a match: the cursor after it - backward before it, so that the next search goes on from there -,
  no block left (Delphi 7's editor moves its cursor so, measured); not found: the cursor stays }
function TSdOtaEditPosition.Find(const Pattern: string; CaseSensitive, RegExp, Selected, FromCursor,
  Forward: Boolean; var ErrorCode: Integer): Boolean;
var
  S, F: Integer;
begin
  Result := FindMatch(Pattern, CaseSensitive, RegExp, Selected, FromCursor, Forward, ErrorCode, S, F);
  if not Result then Exit;
  if Forward then Ed.MoveCaretKernel(F, 0) else Ed.MoveCaretKernel(S, 0);
  Ed.Sci(SCI_SCROLLCARET);
end;

{ All: every match of the range at once; else the next match, the cursor after the replacement.
  The error codes are Find's }
function TSdOtaEditPosition.DoReplace(const Pattern, ReplaceText: string; CaseSensitive, RegExp, Selected,
  FromCursor: Boolean; Direction: TSearchDirection; All: Boolean; var ErrorCode: Integer): Integer;
var
  E: TSciEdit;
  Lo, Hi, S, F: Integer;
  O: IOTAReplaceOptions;
begin
  Result := 0;
  ErrorCode := 0;
  LastWasReplace := True;
  E := Ed;
  if E = nil then Exit;
  O := OtaModules.SearchOptions;
  if All then
  begin
    if not SearchRange(E, Pattern, Selected, ErrorCode, Lo, Hi) then Exit;
    { the whole text: to its end as the replacements change it }
    if not Selected then Hi := -1;
    if FromCursor then
      if Direction = sdForward then Lo := E.CaretPos else Hi := E.CaretPos;
    { the editor's search takes the IDE's strings (TSciEdit converts them) }
    Result := E.ReplaceAll(Pattern, ReplaceText, CaseSensitive, O.WordBoundary, RegExp, Lo, Hi);
  end
  else if FindMatch(Pattern, CaseSensitive, RegExp, Selected, FromCursor, Direction = sdForward, ErrorCode, S, F) then
  begin
    E.SetSel(S, F);
    if E.ReplaceCurrent(Pattern, ReplaceText, CaseSensitive, O.WordBoundary, RegExp) then Result := 1;
    E.MoveCaretKernel(E.CaretPos, 0);
  end;
end;

function TSdOtaEditPosition.RepeatLastSearchOrReplace: Boolean;
begin
  if LastWasReplace then Result := ReplaceAgain > 0 else Result := SearchAgain;
end;

{ as Search: the options are these alone - one match replaced (Delphi 7's, measured); WholeFile False,
  in the marked block }
function TSdOtaEditPosition.Replace(const Pattern, ReplaceText: string; CaseSensitive,
  RegularExpression, WholeFile: Boolean; Direction: TSearchDirection; var ErrorCode: Integer): Integer;
var
  O: IOTAReplaceOptions;
begin
  O := SetSearchOptions(Pattern, CaseSensitive, RegularExpression, WholeFile, Direction);
  O.ReplaceText := ReplaceText;
  O.ReplaceAll := False;
  Result := DoReplace(Pattern, ReplaceText, CaseSensitive, RegularExpression, not WholeFile, False, Direction,
    False, ErrorCode);
end;

{ the replacement the options say; FromCursor, the options' own or from the cursor }
function TSdOtaEditPosition.ReplaceWithOptions(FromCursor: Boolean): Integer;
var
  O: IOTAReplaceOptions;
  Err: Integer;
begin
  O := OtaModules.SearchOptions;
  Result := DoReplace(O.SearchText, O.ReplaceText, O.CaseSensitive, O.RegularExpression, not O.WholeFile,
    FromCursor, O.Direction, O.ReplaceAll, Err);
end;

function TSdOtaEditPosition.Replace: Integer;
begin
  Result := ReplaceWithOptions(OtaModules.SearchOptions.FromCursor);
end;

{ the next match from the cursor (Delphi 7's, measured) }
function TSdOtaEditPosition.ReplaceAgain: Integer;
begin
  Result := ReplaceWithOptions(True);
end;

{ Delphi's TCursorPreserver: the row and the column (values - later edits do not move them);
  Restore is a Move there }
procedure TSdOtaEditPosition.Save;
var
  P: TOTAEditPos;
begin
  if Ed = nil then Exit;
  P := FView.GetCursorPos;
  FView.Buffer.Module.State.Positions.Add(Pointer(P.Line));
  FView.Buffer.Module.State.Positions.Add(Pointer(P.Col));
end;

procedure TSdOtaEditPosition.Restore;
var
  L: TList;
  Row, Col: Integer;
begin
  L := FView.Buffer.Module.State.Positions;
  if L.Count < 2 then Exit;
  Row := Integer(L[L.Count - 2]);
  Col := Integer(L[L.Count - 1]);
  L.Count := L.Count - 2;
  MoveTo(Row, Col);
end;

{ the characters from the cursor on (rfBackward: before it) that belong to Valid }
function TSdOtaEditPosition.Rip(const Valid: TSysCharSet; RipFlags: Integer): string;
var
  E: TSciEdit;
  S: TSysCharSet;
  P: Integer;
  C: Char;
  Ok: Boolean;
begin
  Result := '';
  E := Ed;
  if E = nil then Exit;
  S := Valid;
  if RipFlags and rfIncludeUpperAlphaChars <> 0 then S := S + ['A'..'Z'];
  if RipFlags and rfIncludeLowerAlphaChars <> 0 then S := S + ['a'..'z'];
  if RipFlags and rfIncludeNumericChars <> 0 then S := S + ['0'..'9'];
  if RipFlags and rfIncludeSpecialChars <> 0 then
    S := S + ['!'..'/', ':'..'@', '['..'`', '{'..'~'];
  C := #0;
  P := Caret;
  repeat
    if RipFlags and rfBackward <> 0 then
    begin
      if P <= 0 then Break;
      C := E.CharAt(P - 1);
    end
    else
    begin
      if P >= E.TextLength then Break;
      C := E.CharAt(P);
    end;
    if C in [#13, #10] then Break;
    Ok := C in S;
    if RipFlags and rfInvertLegalChars <> 0 then Ok := not Ok;
    if not Ok then Break;
    if RipFlags and rfBackward <> 0 then
    begin
      Result := C + Result;
      Dec(P);
    end
    else
    begin
      Result := Result + C;
      Inc(P);
    end;
  until False;
  Result := OtaFromEditor(Page, Result);
end;

function TSdOtaEditPosition.RipText(const ValidChars: TSysCharSet; RipFlags: Integer): string;
begin
  Result := Rip(ValidChars, RipFlags);
end;

function TSdOtaEditPosition.RipText(const ValidChars: string; RipFlags: Integer): string;
var
  S: TSysCharSet;
  I: Integer;
begin
  S := [];
  for I := 1 to Length(ValidChars) do Include(S, ValidChars[I]);
  Result := Rip(S, RipFlags);
end;

{ the options are these alone (Delphi's TOTAEditView.Search makes its search record anew: no whole
  words, not from the cursor); SearchAgain goes on with them. As Delphi 7's (measured): WholeFile
  False searches the marked block (none: error 2), True the whole file - from its start, the end
  backward; a pattern not found is no error (0). Delphi 7's finds nothing backward; D7 Studio's
  does. }
function TSdOtaEditPosition.Search(const Pattern: string; CaseSensitive, RegularExpression,
  WholeFile: Boolean; Direction: TSearchDirection; var ErrorCode: Integer): Boolean;
begin
  SetSearchOptions(Pattern, CaseSensitive, RegularExpression, WholeFile, Direction);
  LastWasReplace := False;
  Result := Find(Pattern, CaseSensitive, RegularExpression, not WholeFile, False, Direction = sdForward, ErrorCode);
end;

{ the explicit Search's and Replace's options: these alone, from the range's start, no whole words }
function TSdOtaEditPosition.SetSearchOptions(const Pattern: string; CaseSensitive, RegularExpression,
  WholeFile: Boolean; Direction: TSearchDirection): IOTAReplaceOptions;
begin
  Result := OtaModules.SearchOptions;
  Result.SearchText := Pattern;
  Result.CaseSensitive := CaseSensitive;
  Result.RegularExpression := RegularExpression;
  Result.WholeFile := WholeFile;
  Result.Direction := Direction;
  Result.WordBoundary := False;
  Result.FromCursor := False;
end;

{ the search the options say; FromCursor, the options' own or from the cursor }
function TSdOtaEditPosition.SearchWithOptions(FromCursor: Boolean): Boolean;
var
  O: IOTAReplaceOptions;
  Err: Integer;
begin
  O := OtaModules.SearchOptions;
  LastWasReplace := False;
  Result := Find(O.SearchText, O.CaseSensitive, O.RegularExpression, not O.WholeFile, FromCursor,
    O.Direction = sdForward, Err);
end;

function TSdOtaEditPosition.Search: Boolean;
begin
  Result := SearchWithOptions(OtaModules.SearchOptions.FromCursor);
end;

{ the next match from the cursor (Delphi 7's, measured) }
function TSdOtaEditPosition.SearchAgain: Boolean;
begin
  Result := SearchWithOptions(True);
end;

{ Delphi's Tab moves the cursor by Magnitude tab stops - back for a negative one -, its column kept
  between 1 and 1024; nothing is inserted, the block stays (a write of the cursor) }
procedure TSdOtaEditPosition.Tab(Magnitude: Integer);
var
  I, Col: Integer;
  P: TOTAEditPos;
begin
  if Ed = nil then Exit;
  for I := 1 to Abs(Magnitude) do
  begin
    P := FView.GetCursorPos;
    if Magnitude > 0 then Col := P.Col + DistanceToTab(sdForward)
    else Col := P.Col - DistanceToTab(sdBackward);
    if Col < 1 then Col := 1;
    if Col > 1024 then Col := 1024;
    FView.SetCursorPos(OtaEditPos(P.Line, Col));
  end;
end;

{ ---------------------------------------------------------------- TSdOtaEditBlock }

constructor TSdOtaEditBlock.Create(AView: TSdOtaEditView);
begin
  inherited Create;
  FView := AView;
  FViewRef := AView;
end;

function TSdOtaEditBlock.Ed: TSciEdit;
begin
  Result := FView.Ed;
end;

function TSdOtaEditBlock.State: TSdOtaEditState;
begin
  Result := FView.Buffer.Module.State;
end;

{ an end of the block as Delphi's Starting / Ending Row and Column give it: a stream block's first
  or second end as it is (row, character index + 1 - in no order), a column block's top-left or
  bottom-right corner (row, column) whichever way it was made; (0, 0) without one }
function TSdOtaEditBlock.Corner(Last: Boolean): TOTACharPos;
var
  E: TSciEdit;
  Blk: TSciBlock;
  P, Row, Col: Integer;
begin
  Result := OtaCharPos(0, 0);
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  if Blk.Mode = sbColumn then
  begin
    if (Blk.Rows.Left < 0) or (Blk.Rows.Top < 0) or (Blk.Rows.Right < 0) or (Blk.Rows.Bottom < 0) then Exit;
    Row := Blk.Rows.Top;
    Col := Blk.Rows.Left;
    if Last = (Blk.Rows.Bottom > Row) then Row := Blk.Rows.Bottom;
    if Last = (Blk.Rows.Right > Col) then Col := Blk.Rows.Right;
    Result := OtaCharPos(Row + 1, Col + 1);
  end
  else
  begin
    if Last then P := Blk.B else P := Blk.A;
    if P < 0 then Exit;
    Result := OffsetToCharPos(E, P);
    Inc(Result.CharIndex);
  end;
end;

{ Delphi's BeginBlock / EndBlock: an end of the block (a column block's corner) at the cursor, in
  no order; the block shown, the cursor where it is }
procedure TSdOtaEditBlock.BeginBlock;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockSetEnd(True);
end;

procedure TSdOtaEditBlock.EndBlock;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockSetEnd(False);
end;

{ Delphi's Copy: the marked block's text with its kind ("Borland IDE Block Type"); Append: after the
  clipboard's text, as text only }
procedure TSdOtaEditBlock.BlockCopy(Append: Boolean);
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockToClipboard(Append);
end;

procedure TSdOtaEditBlock.Cut(Append: Boolean);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  E.BlockToClipboard(Append);
  E.BlockDelete;
end;

function TSdOtaEditBlock.BlockDelete: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.BlockDelete;
end;

{ Delphi's Extend: the cursor to the row and column (the row within the text), the block from its
  anchor - the end opposite the cursor when the block is marked and the cursor at it - to there,
  ordered; True when the cursor got there }
function TSdOtaEditBlock.Extend(NewRow, NewCol: Integer): Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.BlockExtend(NewRow - 1, NewCol - 1);
end;

{ ... a screen up or down: the rows on the screen but two, within the text }
function TSdOtaEditBlock.ExtendPage(Down: Boolean): Boolean;
var
  E: TSciEdit;
  P: TOTAEditPos;
  N, Row: Integer;
begin
  Result := False;
  E := Ed;
  if E = nil then Exit;
  P := FView.GetCursorPos;
  N := E.Sci(SCI_LINESONSCREEN) - 2;
  if N < 1 then N := 1;
  if Down then
  begin
    Row := P.Line + N;
    if Row > E.LineCount then Row := E.LineCount;
  end
  else
  begin
    Row := P.Line - N;
    if Row < 1 then Row := 1;
  end;
  Result := Extend(Row, P.Col);
end;

function TSdOtaEditBlock.ExtendPageUp: Boolean;
begin
  Result := ExtendPage(False);
end;

function TSdOtaEditBlock.ExtendPageDown: Boolean;
begin
  Result := ExtendPage(True);
end;

{ Delphi's ExtendReal is Extend on the line number frozen by the edits (D7 Studio has none: the
  line now) }
function TSdOtaEditBlock.ExtendReal(NewRow, NewCol: Integer): Boolean;
begin
  Result := Extend(NewRow, NewCol);
end;

function TSdOtaEditBlock.ExtendRelative(DeltaRow, DeltaCol: Integer): Boolean;
var
  P: TOTAEditPos;
begin
  Result := False;
  if Ed = nil then Exit;
  P := FView.GetCursorPos;
  Result := Extend(P.Line + DeltaRow, P.Col + DeltaCol);
end;

function TSdOtaEditBlock.GetEndingColumn: Integer;
begin
  Result := Corner(True).CharIndex;
end;

function TSdOtaEditBlock.GetEndingRow: Integer;
begin
  Result := Corner(True).Line;
end;

{ Delphi's: the block is marked - valid, not hidden, and Persistent blocks or the cursor at one of
  its ends }
function TSdOtaEditBlock.GetIsValid: Boolean;
var
  E: TSciEdit;
begin
  E := Ed;
  Result := (E <> nil) and E.BlockMarked;
end;

function TSdOtaEditBlock.GetSize: Integer;
begin
  Result := Length(GetText);
end;

function TSdOtaEditBlock.GetStartingColumn: Integer;
begin
  Result := Corner(False).CharIndex;
end;

function TSdOtaEditBlock.GetStartingRow: Integer;
begin
  Result := Corner(False).Line;
end;

function TSdOtaEditBlock.GetStyle: TOTABlockType;
begin
  Result := FView.Buffer.GetBlockType;
end;

{ the marked block's text ('' when none): a column block's rows each with CR LF after it }
function TSdOtaEditBlock.GetText: string;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Result := '' else Result := OtaFromEditor(FView.Page, E.BlockText);
end;

function TSdOtaEditBlock.GetVisible: Boolean;
begin
  Result := GetIsValid;
end;

{ Delphi's Indent: a stream block's lines, a column block's rows at its left column, by Magnitude
  blanks (negative: out) }
procedure TSdOtaEditBlock.Indent(Magnitude: Integer);
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockIndent(Magnitude);
end;

{ Delphi's case commands: the marked block only - a column block's rectangle -, toggled by
  Windows' case mapping of the characters }
procedure TSdOtaEditBlock.BlockLowerCase;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockCase(1);
end;

procedure TSdOtaEditBlock.BlockUpperCase;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockCase(0);
end;

procedure TSdOtaEditBlock.ToggleCase;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockCase(2);
end;

function TSdOtaEditBlock.Print: Boolean;
begin
  Result := False;
end;

{ Delphi's Reset: both ends and both corners at the cursor, shown }
procedure TSdOtaEditBlock.Reset;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then E.BlockReset;
end;

{ Delphi's TBlockPreserver: the block as values (kind, ends, corners) on the module's stack;
  Restore takes the last one back and shows it - an empty stack does nothing }
procedure TSdOtaEditBlock.Save;
var
  E: TSciEdit;
  Blk: TSciBlock;
  S: TSdOtaSavedBlock;
begin
  E := Ed;
  if E = nil then Exit;
  E.GetBufferBlock(Blk);
  S := TSdOtaSavedBlock.Create;
  S.Mode := Blk.Mode;
  if Blk.A >= 0 then S.A := OffsetToCharPos(E, Blk.A) else S.A := OtaCharPos(0, 0);
  if Blk.B >= 0 then S.B := OffsetToCharPos(E, Blk.B) else S.B := OtaCharPos(0, 0);
  S.Rows := Blk.Rows;
  State.Blocks.Add(S);
end;

procedure TSdOtaEditBlock.Restore;
var
  E: TSciEdit;
  L: TList;
  S: TSdOtaSavedBlock;
  Blk: TSciBlock;
begin
  E := Ed;
  L := State.Blocks;
  if (E = nil) or (L.Count = 0) then Exit;
  S := TSdOtaSavedBlock(L[L.Count - 1]);
  L.Delete(L.Count - 1);
  try
    Blk.Mode := S.Mode;
    if S.A.Line > 0 then Blk.A := CharPosToOffset(E, S.A) else Blk.A := -1;
    if S.B.Line > 0 then Blk.B := CharPosToOffset(E, S.B) else Blk.B := -1;
    Blk.Rows := S.Rows;
    Blk.Hidden := False;
    E.SetBufferBlock(Blk);
  finally
    S.Free;
  end;
end;

{ Delphi's SaveToFile: the marked block in the page's encoding (as Write Block to File; no name:
  that command's dialog); False when no block is marked }
function TSdOtaEditBlock.SaveToFile(const FileName: string): Boolean;
var
  E: TSciEdit;
begin
  Result := False;
  E := Ed;
  if (E = nil) or not E.BlockMarked then Exit;
  if FileName = '' then
  begin
    E.ExecCommand(ecBlockWrite, 0);
    Result := True;
    Exit;
  end;
  try
    WriteSourceFile(FileName, E.BlockText, E.Encoding);
    Result := True;
  except
    Result := False;
  end;
end;

{ Delphi's SetStyle: a block that is not marked is reset to the cursor first, then the kind changes
  (a marked block keeps its place) }
procedure TSdOtaEditBlock.SetStyle(Value: TOTABlockType);
var
  E: TSciEdit;
begin
  E := Ed;
  if (E <> nil) and (Value < btUnknown) then E.BlockSetMode(TSciBlockMode(Ord(Value)), True);
end;

{ Delphi's SetVisible: the block hidden or shown again (its ends stay) when it is not as asked }
procedure TSdOtaEditBlock.SetVisible(Value: Boolean);
var
  E: TSciEdit;
begin
  E := Ed;
  if (E <> nil) and (Value <> E.BlockMarked) then E.BlockSetHidden(not Value);
end;

{ ---------------------------------------------------------------- reader and writer }

constructor TSdOtaReader.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
end;

function TSdOtaReader.GetText(Position: Longint; Buffer: PChar; Count: Longint): Longint;
begin
  Result := 0;
  if (Buffer = nil) or (Count <= 0) or (Position < 0) or (Position >= Length(FText)) then Exit;
  Result := Length(FText) - Position;
  if Result > Count then Result := Count;
  System.Move(FText[Position + 1], Buffer^, Result);
end;

{ ABuffer's editor (nil: the file could not be opened - the writer then writes nothing, as an
  expert never gets nil from Delphi) }
constructor TSdOtaWriter.Create(ABuffer: TSdOtaSourceEditor; Undoable: Boolean);
begin
  inherited Create;
  FBufferRef := ABuffer;
  FBuffer := ABuffer;
  FEd := ABuffer.NeedEd;
  FUndoable := Undoable;
  if FEd = nil then Exit;
  FOrigLen := FEd.TextLength;
  FUndoBefore := FEd.UndoCurrent;
  FCaretBefore := FEd.CaretPos;
  FEd.BeginUndo;
end;

{ the editor the writer works in while its page still has it: a page closed meanwhile takes it
  along (its pointer is compared, never used) }
function TSdOtaWriter.Ed: TSciEdit;
begin
  if (FEd <> nil) and (FBuffer.Ed = FEd) then Result := FEd else Result := nil;
end;

{ released: one undo step, after which Delphi 7's editor has one that takes back no text (TSciEdit.
  WriterStep); a writer that was not asked to be undoable empties the undo buffer, as Delphi's does -
  and the file stays modified: Scintilla's EmptyUndoBuffer would take its save point along (the
  page's mark keeps it until the file is saved) }
destructor TSdOtaWriter.Destroy;
var
  E: TSciEdit;
begin
  E := Ed;
  if E <> nil then
    try
      E.EndUndo;
      if not FUndoable then
      begin
        E.Sci(SCI_EMPTYUNDOBUFFER);
        if FChanged and (FBuffer.Page <> nil) then FBuffer.Page.MarkModified;
      end
      else if FChanged then
        E.WriterStep(FUndoBefore, FCaretBefore);
    except
    end;
  inherited;
end;

procedure TSdOtaWriter.CopyTo(Pos: Longint);
begin
  if Pos > FOrigLen then Pos := FOrigLen;
  if Pos > FOrig then FOrig := Pos;
end;

procedure TSdOtaWriter.DeleteTo(Pos: Longint);
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  if Pos > FOrigLen then Pos := FOrigLen;
  if Pos <= FOrig then Exit;
  E.DeleteRange(FOrig + FDelta, Pos - FOrig);
  Dec(FDelta, Pos - FOrig);
  FOrig := Pos;
  FChanged := True;
end;

procedure TSdOtaWriter.InsertText(Text: PChar);
var
  S: string;
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then Exit;
  S := StrPas(Text);
  if S = '' then Exit;
  E.InsertText(FOrig + FDelta, S);
  Inc(FDelta, Length(S));
  FChanged := True;
end;

function TSdOtaWriter.Position: Longint;
begin
  Result := FOrig;
end;

function TSdOtaWriter.GetCurrentPos: TOTACharPos;
var
  E: TSciEdit;
begin
  E := Ed;
  if E = nil then
  begin
    Result.CharIndex := 0;
    Result.Line := 0;
  end
  else
    Result := OffsetToCharPos(E, FOrig + FDelta);
end;

{ ---------------------------------------------------------------- TSdOtaSearchOptions }

function TSdOtaSearchOptions.GetCaseSensitive: Boolean; begin Result := FCase; end;
function TSdOtaSearchOptions.GetDirection: TSearchDirection; begin Result := FDirection; end;
function TSdOtaSearchOptions.GetFromCursor: Boolean; begin Result := FFromCursor; end;
function TSdOtaSearchOptions.GetRegularExpression: Boolean; begin Result := FRegExp; end;
function TSdOtaSearchOptions.GetSearchText: string; begin Result := FText; end;
function TSdOtaSearchOptions.GetWholeFile: Boolean; begin Result := FWholeFile; end;
function TSdOtaSearchOptions.GetWordBoundary: Boolean; begin Result := FWord; end;
procedure TSdOtaSearchOptions.SetCaseSensitive(Value: Boolean); begin FCase := Value; end;
procedure TSdOtaSearchOptions.SetDirection(Value: TSearchDirection); begin FDirection := Value; end;
procedure TSdOtaSearchOptions.SetFromCursor(Value: Boolean); begin FFromCursor := Value; end;
procedure TSdOtaSearchOptions.SetRegularExpression(Value: Boolean); begin FRegExp := Value; end;
procedure TSdOtaSearchOptions.SetSearchText(const Value: string); begin FText := Value; end;
procedure TSdOtaSearchOptions.SetWholeFile(Value: Boolean); begin FWholeFile := Value; end;
procedure TSdOtaSearchOptions.SetWordBoundary(Value: Boolean); begin FWord := Value; end;
function TSdOtaSearchOptions.GetPromptOnReplace: Boolean; begin Result := FPrompt; end;
function TSdOtaSearchOptions.GetReplaceAll: Boolean; begin Result := FAll; end;
function TSdOtaSearchOptions.GetReplaceText: string; begin Result := FReplace; end;
procedure TSdOtaSearchOptions.SetPromptOnReplace(Value: Boolean); begin FPrompt := Value; end;
procedure TSdOtaSearchOptions.SetReplaceAll(Value: Boolean); begin FAll := Value; end;
procedure TSdOtaSearchOptions.SetReplaceText(const Value: string); begin FReplace := Value; end;

{ ---------------------------------------------------------------- options }

{ the ID of file type Index ('': none) and the index of a file type's ID now (-1: none, or gone
  from Tools | Editor Options since) }
function FileTypeID(Index: Integer): string;
begin
  if (Index >= 0) and (Index <= High(EditorOptions.FileTypes)) then Result := EditorOptions.FileTypes[Index].ID
  else Result := '';
end;

constructor TSdOtaFileTypeOptions.Create(AIndex: Integer);
begin
  inherited Create;
  FID := FileTypeID(AIndex);
end;

{ the file type, or -1 (none: the general options only) }
function TSdOtaFileTypeOptions.FT: Integer;
begin
  Result := EditorFileTypeOfID(FID);
end;

procedure TSdOtaBufferOptions.Changed;
begin
  if OtaHost <> nil then OtaHost.EditorOptionsChanged;
end;

function TSdOtaBufferOptions.GetAutoIndent: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].AutoIndent;
end;

function TSdOtaBufferOptions.GetBackspaceUnindents: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].BackspaceUnindents;
end;

function TSdOtaBufferOptions.GetCreateBackupFile: Boolean;
begin
  Result := EditorOptions.CreateBackup;
end;

function TSdOtaBufferOptions.GetCursorThroughTabs: Boolean;
begin
  Result := EditorOptions.CursorThroughTabs;
end;

function TSdOtaBufferOptions.GetInsertMode: Boolean;
begin
  Result := EditorOptions.InsertMode;
end;

function TSdOtaBufferOptions.GetGroupUndo: Boolean;
begin
  Result := EditorOptions.GroupUndo;
end;

function TSdOtaBufferOptions.GetKeepTrailingBlanks: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].KeepTrailingBlanks;
end;

function TSdOtaBufferOptions.GetLeftGutterWidth: Integer;
begin
  Result := EditorOptions.GutterWidth;
end;

function TSdOtaBufferOptions.GetRightMargin: Integer;
begin
  Result := EditorOptions.RightMargin;
end;

function TSdOtaBufferOptions.GetOverwriteBlocks: Boolean;
begin
  Result := EditorOptions.OverwriteBlocks;
end;

function TSdOtaBufferOptions.GetPersistentBlocks: Boolean;
begin
  Result := EditorOptions.PersistentBlocks;
end;

function TSdOtaBufferOptions.GetPreserveLineEnds: Boolean;
begin
  Result := EditorOptions.PreserveLineEnds;
end;

function TSdOtaBufferOptions.GetSmartTab: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].SmartTab;
end;

function TSdOtaBufferOptions.GetSyntaxHighlight: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].UseSyntaxHighlight;
end;

function TSdOtaBufferOptions.GetTabStops: string;
begin
  if FT >= 0 then Result := EditorOptions.FileTypes[FT].TabStops else Result := '8';
end;

function TSdOtaBufferOptions.GetUndoAfterSave: Boolean;
begin
  Result := EditorOptions.UndoAfterSave;
end;

function TSdOtaBufferOptions.GetUndoLimit: Integer;
begin
  Result := EditorOptions.UndoLimit;
end;

function TSdOtaBufferOptions.GetUseTabCharacter: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].UseTabChar;
end;

function TSdOtaBufferOptions.GetShowSpace: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].ShowSpaceChar;
end;

function TSdOtaBufferOptions.GetShowTab: Boolean;
begin
  Result := (FT >= 0) and EditorOptions.FileTypes[FT].ShowTabChar;
end;

procedure TSdOtaBufferOptions.SetAutoIndent(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].AutoIndent := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetBackspaceUnindents(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].BackspaceUnindents := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetCreateBackupFile(Value: Boolean);
begin
  EditorOptions.CreateBackup := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetCursorThroughTabs(Value: Boolean);
begin
  EditorOptions.CursorThroughTabs := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetInsertMode(Value: Boolean);
begin
  EditorOptions.InsertMode := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetGroupUndo(Value: Boolean);
begin
  EditorOptions.GroupUndo := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetKeepTrailingBlanks(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].KeepTrailingBlanks := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetLeftGutterWidth(Value: Integer);
begin
  EditorOptions.GutterWidth := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetRightMargin(Value: Integer);
begin
  EditorOptions.RightMargin := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetOverwriteBlocks(Value: Boolean);
begin
  EditorOptions.OverwriteBlocks := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetPersistentBlocks(Value: Boolean);
begin
  EditorOptions.PersistentBlocks := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetPreserveLineEnds(Value: Boolean);
begin
  EditorOptions.PreserveLineEnds := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetSmartTab(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].SmartTab := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetSyntaxHighlight(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].UseSyntaxHighlight := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetTabStops(const Value: string);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].TabStops := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetUndoAfterSave(Value: Boolean);
begin
  EditorOptions.UndoAfterSave := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetUndoLimit(Value: Integer);
begin
  EditorOptions.UndoLimit := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetUseTabCharacter(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].UseTabChar := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetShowSpace(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].ShowSpaceChar := Value;
  Changed;
end;

procedure TSdOtaBufferOptions.SetShowTab(Value: Boolean);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].ShowTabChar := Value;
  Changed;
end;

procedure TSdOtaEditOptions.Changed;
begin
  if (FUpdating = 0) and (OtaHost <> nil) then OtaHost.EditorOptionsChanged;
end;

{ the speed settings: one list of the editor services, whichever options are asked (SdOtaSpeedSettings) }
function TSdOtaEditOptions.AddSpeedSetting(const SpeedSetting: IOTASpeedSetting): Integer;
begin
  Result := SpeedSettings.Add(SpeedSetting);
end;

procedure TSdOtaEditOptions.BeginUpdate;
begin
  Inc(FUpdating);
end;

procedure TSdOtaEditOptions.EndUpdate;
begin
  if FUpdating > 0 then Dec(FUpdating);
  Changed;
end;

function TSdOtaEditOptions.GetBlockIndent: Integer;
begin
  if FT >= 0 then Result := EditorOptions.FileTypes[FT].BlockIndent else Result := 2;
end;

function TSdOtaEditOptions.GetBufferOptions: IOTABufferOptions;
begin
  Result := TSdOtaBufferOptions.Create(FT);
end;

function TSdOtaEditOptions.GetFontName: string;
begin
  Result := EditorOptions.FontName;
end;

function TSdOtaEditOptions.GetFontSize: Integer;
begin
  Result := EditorOptions.FontSize;
end;

function TSdOtaEditOptions.GetForceCutCopyEnabled: Boolean;
begin
  Result := EditorOptions.ForceCutCopy;
end;

function TSdOtaEditOptions.GetSpeedSettingCount: Integer;
begin
  Result := SpeedSettings.Count;
end;

function TSdOtaEditOptions.GetSpeedSetting(Index: Integer): IOTASpeedSetting;
begin
  Result := SpeedSettings.Get(Index);
end;

function TSdOtaEditOptions.GetSyntaxHighlightTypes(Index: TOTASyntaxHighlighter): string;
begin
  Result := '';
end;

function TSdOtaEditOptions.GetUseBriefCursorShapes: Boolean;
begin
  Result := EditorOptions.BriefCursors;
end;

function TSdOtaEditOptions.GetUseBriefRegularExpressions: Boolean;
begin
  Result := EditorOptions.BriefRegExp;
end;

procedure TSdOtaEditOptions.RemoveSpeedSetting(Index: Integer);
begin
  SpeedSettings.Remove(Index);
end;

procedure TSdOtaEditOptions.SetBlockIndent(Value: Integer);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].BlockIndent := Value;
  Changed;
end;

procedure TSdOtaEditOptions.SetFontName(const Value: string);
begin
  EditorOptions.FontName := Value;
  Changed;
end;

procedure TSdOtaEditOptions.SetFontSize(Value: Integer);
begin
  EditorOptions.FontSize := Value;
  Changed;
end;

procedure TSdOtaEditOptions.SetForceCutCopyEnabled(Value: Boolean);
begin
  EditorOptions.ForceCutCopy := Value;
  Changed;
end;

{ Delphi's: the setting of the name (none raises), run with these options }
procedure TSdOtaEditOptions.SetSpeedSetting(const Name: string);
begin
  SpeedSettings.Execute(Name, Self);
end;

procedure TSdOtaEditOptions.SetSyntaxHighlightTypes(Index: TOTASyntaxHighlighter; const Value: string);
begin
end;

procedure TSdOtaEditOptions.SetUseBriefCursorShapes(Value: Boolean);
begin
  EditorOptions.BriefCursors := Value;
  Changed;
end;

procedure TSdOtaEditOptions.SetUseBriefRegularExpressions(Value: Boolean);
begin
  EditorOptions.BriefRegExp := Value;
  Changed;
end;

function TSdOtaEditOptions.GetExtensions: string;
begin
  if FT >= 0 then Result := EditorOptions.FileTypes[FT].Extensions else Result := '';
end;

function TSdOtaEditOptions.GetOptionsName: string;
begin
  if FT >= 0 then Result := EditorOptions.FileTypes[FT].Name else Result := '';
end;

function TSdOtaEditOptions.GetOptionsIDString: string;
begin
  Result := FID;
end;

{ the highlighter of the file type's ID (Delphi's LookupHighlighter); nil: none of that ID }
function TSdOtaEditOptions.GetSyntaxHighlighter: IOTAHighlighter;
begin
  if FT >= 0 then Result := OtaHighlighterOfID(EditorOptions.FileTypes[FT].Highlighter) else Result := nil;
end;

function TSdOtaEditOptions.GetOptionsIndex: Integer;
begin
  Result := FT;
end;

procedure TSdOtaEditOptions.SetExtensions(const Value: string);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].Extensions := Value;
  Changed;
end;

procedure TSdOtaEditOptions.SetOptionsName(const Value: string);
begin
  if FT < 0 then Exit;
  EditorOptions.FileTypes[FT].Name := Value;
  Changed;
end;

{ Delphi's: the highlighter's ID kept (nil: none) - an expert adds it to the highlight services
  first; the editors of the type take it (EditorOptionsChanged) }
procedure TSdOtaEditOptions.SetSyntaxHighlighter(const Value: IOTAHighlighter);
begin
  if FT < 0 then Exit;
  if Value = nil then EditorOptions.FileTypes[FT].Highlighter := NoHighlighter
  else EditorOptions.FileTypes[FT].Highlighter := Value.GetIDString;
  Changed;
end;

{ ---------------------------------------------------------------- TSdOtaLineTracker }

constructor TSdOtaLineTracker.Create(AModule: TSdOtaModule);
begin
  inherited Create;
  FModule := AModule;
  FLines := TList.Create;
  FData := TList.Create;
  FNotifiers := TSdNotifierList.Create;
end;

destructor TSdOtaLineTracker.Destroy;
begin
  FNotifiers.Free;
  FData.Free;
  FLines.Free;
  inherited;
end;

{ lines were inserted (LinesAdded > 0) or deleted after line Line0 (1-based): the tracked lines
  below follow; a deleted line goes to the line of the change }
procedure TSdOtaLineTracker.Edited(Line0, LinesAdded: Integer);
var
  I, K, Old, New: Integer;
  Moved: array of Integer;             // per moved line: its old line, its new line, its data
begin
  if LinesAdded = 0 then Exit;
  { every line first, then the notifiers: a notifier may change the tracker (Delete) }
  SetLength(Moved, 3 * FLines.Count);
  K := 0;
  for I := 0 to FLines.Count - 1 do
  begin
    Old := Integer(FLines[I]);
    if Old <= Line0 then Continue;
    New := Old + LinesAdded;
    if New < Line0 then New := Line0;
    if New = Old then Continue;
    FLines[I] := Pointer(New);
    Moved[K] := Old;
    Moved[K + 1] := New;
    Moved[K + 2] := Integer(FData[I]);
    Inc(K, 3);
  end;
  I := 0;
  while I < K do
  begin
    FNotifiers.Each(IOTAEditLineNotifier, LineChangedOne, @Moved[I], 'IOTAEditLineNotifier.LineChanged');
    Inc(I, 3);
  end;
end;

function TSdOtaLineTracker.AddNotifier(const Notifier: IOTAEditLineNotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaLineTracker.AddLine(Line: Integer; Data: Integer);
begin
  FLines.Add(Pointer(Line));
  FData.Add(Pointer(Data));
end;

procedure TSdOtaLineTracker.DeleteLine(Index: Integer);
begin
  if (Index < 0) or (Index >= FLines.Count) then Exit;
  FLines.Delete(Index);
  FData.Delete(Index);
end;

function TSdOtaLineTracker.GetCount: Integer;
begin
  Result := FLines.Count;
end;

function TSdOtaLineTracker.GetData(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= FData.Count) then Result := 0 else Result := Integer(FData[Index]);
end;

function TSdOtaLineTracker.GetEditBuffer: IOTAEditBuffer;
begin
  Result := nil;
  if FModule <> nil then Supports(FModule.SourceEditor, IOTAEditBuffer, Result);
end;

function TSdOtaLineTracker.GetLineNum(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= FLines.Count) then Result := 0 else Result := Integer(FLines[Index]);
end;

function TSdOtaLineTracker.IndexOfLine(Line: Integer): Integer;
begin
  Result := FLines.IndexOf(Pointer(Line));
end;

function TSdOtaLineTracker.IndexOfData(Data: Integer): Integer;
begin
  Result := FData.IndexOf(Pointer(Data));
end;

procedure TSdOtaLineTracker.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

procedure TSdOtaLineTracker.SetData(Index: Integer; Value: Integer);
begin
  if (Index >= 0) and (Index < FData.Count) then FData[Index] := Pointer(Value);
end;

procedure TSdOtaLineTracker.SetLineNum(Index: Integer; Value: Integer);
begin
  if (Index >= 0) and (Index < FLines.Count) then FLines[Index] := Pointer(Value);
end;

{ ---------------------------------------------------------------- TSdOtaFormEditor }

constructor TSdOtaFormEditor.Create(AModule: TSdOtaModule);
begin
  inherited Create;
  FModule := AModule;
  FModuleRef := AModule;
end;

function TSdOtaFormEditor.Designer: TFormDesigner;
var
  P: TEditorPage;
begin
  Result := nil;
  P := FModule.Page;
  if (P <> nil) and P.HasForm and P.EnsureDesigner then Result := P.Designer;
end;

function TSdOtaFormEditor.Wrap(P: TPersistent): IOTAComponent;
begin
  if P = nil then Result := nil else Result := TSdOtaComponent.Create(P, Designer);
end;

function TSdOtaFormEditor.OtaFileName: string;
begin
  Result := FModule.FormFileName;
end;

function TSdOtaFormEditor.AddNotifier(const ANotifier: IOTANotifier): Integer;
begin
  Result := FModule.FormNotifiers.Add(ANotifier);
  OtaModules.NeedDesignNotes;
end;

function TSdOtaFormEditor.GetFileName: string;
begin
  Result := FModule.FormFileName;
end;

function TSdOtaFormEditor.GetModified: Boolean;
var
  P: TEditorPage;
begin
  P := FModule.Page;
  Result := (P <> nil) and (P.FormModified or ((P.Designer <> nil) and P.Designer.IsModified));
end;

function TSdOtaFormEditor.GetModule: IOTAModule;
begin
  Result := FModuleRef;
end;

function TSdOtaFormEditor.MarkModified: Boolean;
var
  D: TFormDesigner;
begin
  D := Designer;
  Result := D <> nil;
  if Result then D.Modified;
end;

procedure TSdOtaFormEditor.RemoveNotifier(Index: Integer);
begin
  FModule.FormNotifiers.Remove(Index);
end;

procedure TSdOtaFormEditor.Show;
var
  P: TEditorPage;
begin
  P := FModule.Page;
  if P = nil then Exit;
  OtaHost.ShowPage(P);
  P.ShowDesign(True);
end;

function TSdOtaFormEditor.GetRootComponent: IOTAComponent;
var
  D: TFormDesigner;
begin
  D := Designer;
  if D = nil then Result := nil else Result := Wrap(D.Root);
end;

function TSdOtaFormEditor.FindComponent(const Name: string): IOTAComponent;
var
  D: TFormDesigner;
begin
  Result := nil;
  D := Designer;
  if (D = nil) or (D.Root = nil) then Exit;
  if SameText(D.Root.Name, Name) then Result := Wrap(D.Root)
  else Result := Wrap(D.Root.FindComponent(Name));
end;

function TSdOtaFormEditor.GetComponentFromHandle(ComponentHandle: TOTAHandle): IOTAComponent;
var
  D: TFormDesigner;
  I: Integer;
begin
  Result := nil;
  D := Designer;
  if (D = nil) or (D.Root = nil) or (ComponentHandle = nil) then Exit;
  if ComponentHandle = Pointer(D.Root) then
  begin
    Result := Wrap(D.Root);
    Exit;
  end;
  for I := 0 to D.Root.ComponentCount - 1 do
    if Pointer(D.Root.Components[I]) = ComponentHandle then
    begin
      Result := Wrap(D.Root.Components[I]);
      Exit;
    end;
end;

function TSdOtaFormEditor.GetSelCount: Integer;
var
  D: TFormDesigner;
begin
  D := Designer;
  if D = nil then Result := 0 else Result := D.SelectionCount;
end;

function TSdOtaFormEditor.GetSelComponent(Index: Integer): IOTAComponent;
var
  D: TFormDesigner;
begin
  D := Designer;
  if (D = nil) or (Index < 0) or (Index >= D.SelectionCount) then Result := nil
  else Result := Wrap(D.Selections[Index]);
end;

function TSdOtaFormEditor.GetCreateParent: IOTAComponent;
var
  D: TFormDesigner;
  I: Integer;
  P: TPersistent;
begin
  Result := nil;
  D := Designer;
  if D = nil then Exit;
  for I := 0 to D.SelectionCount - 1 do
  begin
    P := D.Selections[I];
    if (P is TWinControl) and (csAcceptsControls in TWinControl(P).ControlStyle) then
    begin
      Result := Wrap(P);
      Exit;
    end;
  end;
  Result := Wrap(D.Root);
end;

function TSdOtaFormEditor.CreateComponent(const Container: IOTAComponent; const TypeName: string;
  X, Y, W, H: Integer): IOTAComponent;
var
  D: TFormDesigner;
  Cls: TComponentClass;
  Parent: TComponent;
  N: INTAComponent;
  P: TPersistentClass;
begin
  Result := nil;
  D := Designer;
  if D = nil then Exit;
  Cls := nil;
  if DesignHost <> nil then Cls := DesignHost.FindComponentClass(TypeName);
  if Cls = nil then
  begin
    P := GetClass(TypeName);
    if (P <> nil) and P.InheritsFrom(TComponent) then Cls := TComponentClass(P);
  end;
  if Cls = nil then Exit;
  Parent := nil;
  if Supports(Container, INTAComponent, N) then Parent := N.GetComponent;
  if Parent = nil then Parent := D.Root;
  Result := Wrap(D.AddComponent(Cls, Parent, X, Y, W, H));
end;

{ the form as Delphi 7's form editor gives it (GetFormResource): in its file's format - its text for
  a text form file (measured in Delphi 7's IDE), else the binary form file (the resource header
  before the TPF0 stream) }
function FormResource(Page: TEditorPage): string;
begin
  Result := '';
  if (Page = nil) or not Page.HasForm then Exit;
  Result := Page.CurrentDfm;
  if Result = '' then Exit;
  if Page.DfmText then
  begin
    if DfmIsBinary(Result) then Result := DfmBinaryToText(Result);
  end
  else if not DfmIsBinary(Result) then
    Result := DfmTextToBinary(Result);
end;

procedure TSdOtaFormEditor.GetFormResource(const Stream: IStream);
var
  S: string;
  Written: Longint;
begin
  S := FormResource(FModule.Page);
  if (Stream <> nil) and (S <> '') then Stream.Write(PChar(S), Length(S), @Written);
end;

function TSdOtaFormEditor.GetFormDesigner: IDesigner;
var
  D: TFormDesigner;
begin
  D := Designer;
  if D = nil then Result := nil else Result := D;
end;

procedure TSdOtaFormEditor.NtaGetFormResource(Stream: TStream);
var
  S: string;
begin
  S := FormResource(FModule.Page);
  if (Stream <> nil) and (S <> '') then Stream.WriteBuffer(S[1], Length(S));
end;

{ ---------------------------------------------------------------- TSdOtaComponent }

constructor TSdOtaComponent.Create(AInstance: TPersistent; ADesigner: TFormDesigner);
begin
  inherited Create;
  FInstance := AInstance;
  FDesigner := ADesigner;
end;

destructor TSdOtaComponent.Destroy;
begin
  FreeProps;
  inherited;
end;

function TSdOtaComponent.Wrap(P: TPersistent): IOTAComponent;
begin
  if P = nil then Result := nil else Result := TSdOtaComponent.Create(P, FDesigner);
end;

{ The root of a data module or a frame is designed on a form (the designer's host): of its
  properties only those of a TDataModule / TFrame are the root's, as the Object Inspector shows. }
function TSdOtaComponent.HostOnly(const PropName: string): Boolean;
begin
  Result := (FDesigner <> nil) and (FInstance = FDesigner.Root) and (FDesigner.HostKind <> hkForm) and
    not FDesigner.RootPropVisible(PropName);
end;

{ the root of a custom module (RegisterCustomModule: TService ...): its designer's instance of the
  module's class, which holds the root's own properties (nil: none) }
function TSdOtaComponent.ModuleOfRoot: TComponent;
begin
  Result := nil;
  if (FDesigner <> nil) and (FInstance = FDesigner.Root) then Result := FDesigner.Module;
end;

{ the object a property is read from and written to: a custom module's own properties are its
  module instance's, the rest the instance's (the properties the host form represents - Name,
  Tag, OldCreateOrder, OnCreate, OnDestroy - keep their host's information) }
function TSdOtaComponent.Target(P: PPropInfo): TObject;
var
  Module: TComponent;
begin
  Result := FInstance;
  Module := ModuleOfRoot;
  if (P <> nil) and (Module <> nil) and (GetPropInfo(FInstance, P^.Name) <> P) then Result := Module;
end;

{ The properties as Delphi 7 lists them: the class's published ones in its order. A custom module's
  root lists its module class's, those the host form represents taken from the host. Made once for
  the component (FProps): an expert's loop over the properties by index asks for each one. }
function TSdOtaComponent.Props: Integer;
var
  I, N: Integer;
  Module: TComponent;
  HP: PPropInfo;
begin
  if FProps <> nil then
  begin
    Result := FPropCount;
    Exit;
  end;
  Result := 0;
  if (FInstance = nil) or (FInstance.ClassInfo = nil) then Exit;
  Module := ModuleOfRoot;
  if Module <> nil then
  begin
    N := GetTypeData(Module.ClassInfo)^.PropCount;
    if N = 0 then Exit;
    GetMem(FProps, N * SizeOf(Pointer));
    GetPropInfos(Module.ClassInfo, FProps);
    for I := 0 to N - 1 do
    begin
      HP := GetPropInfo(FInstance, FProps^[I]^.Name);
      if (HP <> nil) and not HostOnly(HP^.Name) then FProps^[I] := HP;
    end;
    Result := N;
  end
  else
  begin
    N := GetTypeData(FInstance.ClassInfo)^.PropCount;
    if N = 0 then Exit;
    GetMem(FProps, N * SizeOf(Pointer));
    GetPropInfos(FInstance.ClassInfo, FProps);
    for I := 0 to N - 1 do
      if not HostOnly(FProps^[I]^.Name) then
      begin
        FProps^[Result] := FProps^[I];
        Inc(Result);
      end;
  end;
  FPropCount := Result;
end;

procedure TSdOtaComponent.FreeProps;
begin
  if FProps <> nil then FreeMem(FProps);
  FProps := nil;
  FPropCount := 0;
end;

function TSdOtaComponent.PropNamed(const Name: string): PPropInfo;
var
  Module: TComponent;
begin
  Result := GetPropInfo(FInstance, Name);
  if (Result <> nil) and HostOnly(Name) then Result := nil;
  Module := ModuleOfRoot;
  if (Result = nil) and (Module <> nil) then Result := GetPropInfo(Module, Name);
end;

function TSdOtaComponent.PropByIndex(Index: Integer): PPropInfo;
begin
  if (Index >= 0) and (Index < Props) then Result := FProps^[Index] else Result := nil;
end;

function TSdOtaComponent.GetComponentType: string;
begin
  Result := FInstance.ClassName;
end;

function TSdOtaComponent.GetComponentHandle: TOTAHandle;
begin
  Result := Pointer(FInstance);
end;

function TSdOtaComponent.GetParent: IOTAComponent;
var
  Root: TComponent;
begin
  Result := nil;
  if FDesigner = nil then Exit;
  Root := FDesigner.Root;
  if (FInstance = Root) or (FInstance = FDesigner.Form) then Exit;
  if (FInstance is TControl) and (TControl(FInstance).Parent <> nil) then
  begin
    if TControl(FInstance).Parent = FDesigner.Form then Result := Wrap(Root)
    else Result := Wrap(TControl(FInstance).Parent);
  end
  else if FInstance is TComponent then
    Result := Wrap(TComponent(FInstance).Owner);
end;

{ a data module's root is no control, though its designer's host is one }
function TSdOtaComponent.IsTControl: Boolean;
begin
  Result := (FInstance is TControl) and not ((FDesigner <> nil) and (FInstance = FDesigner.Root) and
    (FDesigner.HostKind = hkDataModule));
end;

function TSdOtaComponent.GetPropCount: Integer;
begin
  Result := Props;
end;

function TSdOtaComponent.GetPropName(Index: Integer): string;
var
  P: PPropInfo;
begin
  P := PropByIndex(Index);
  if P = nil then Result := '' else Result := P^.Name;
end;

function TSdOtaComponent.GetPropType(Index: Integer): TTypeKind;
var
  P: PPropInfo;
begin
  P := PropByIndex(Index);
  if P = nil then Result := tkUnknown else Result := P^.PropType^^.Kind;
end;

function TSdOtaComponent.GetPropTypeByName(const Name: string): TTypeKind;
var
  P: PPropInfo;
begin
  P := PropNamed(Name);
  if P = nil then Result := tkUnknown else Result := P^.PropType^^.Kind;
end;

{ a property's value into the caller's variable of the property's type - a short string's into a
  string (AnsiString), as Delphi 7 gives it (measured) }
function TSdOtaComponent.ReadProp(P: PPropInfo; var Value): Boolean;
var
  Obj: TObject;
  O: TObject;
begin
  Result := P <> nil;
  if not Result then Exit;
  Obj := Target(P);
  try
    case P^.PropType^^.Kind of
      tkInteger, tkChar, tkWChar, tkEnumeration, tkSet:
        case GetTypeData(P^.PropType^)^.OrdType of
          otSByte, otUByte: Byte(Value) := GetOrdProp(Obj, P);
          otSWord, otUWord: Word(Value) := GetOrdProp(Obj, P);
        else
          Integer(Value) := GetOrdProp(Obj, P);
        end;
      tkFloat:
        case GetTypeData(P^.PropType^)^.FloatType of
          ftSingle: Single(Value) := GetFloatProp(Obj, P);
          ftDouble: Double(Value) := GetFloatProp(Obj, P);
          ftComp: Comp(Value) := GetFloatProp(Obj, P);
          ftCurr: Currency(Value) := GetFloatProp(Obj, P);
        else
          Extended(Value) := GetFloatProp(Obj, P);
        end;
      TypInfo.tkString, tkLString: string(Value) := GetStrProp(Obj, P);
      tkWString: WideString(Value) := GetWideStrProp(Obj, P);
      tkVariant: Variant(Value) := GetVariantProp(Obj, P);
      tkInt64: Int64(Value) := GetInt64Prop(Obj, P);
      tkMethod: TMethod(Value) := GetMethodProp(Obj, P);
      tkInterface: IInterface(Value) := GetInterfaceProp(Obj, P);
      tkClass:
        begin
          O := GetObjectProp(Obj, P);
          if O is TPersistent then IOTAComponent(Value) := Wrap(TPersistent(O))
          else Pointer(Value) := nil;
        end;
    else
      Result := False;
    end;
  except
    Result := False;
  end;
end;

function TSdOtaComponent.WriteProp(P: PPropInfo; const Value): Boolean;
var
  Obj: TObject;
  N: INTAComponent;
begin
  Result := (P <> nil) and (P^.SetProc <> nil);
  if not Result then Exit;
  Obj := Target(P);
  try
    case P^.PropType^^.Kind of
      tkInteger, tkChar, tkWChar, tkEnumeration, tkSet:
        case GetTypeData(P^.PropType^)^.OrdType of
          otSByte, otUByte: SetOrdProp(Obj, P, Byte(Value));
          otSWord, otUWord: SetOrdProp(Obj, P, Word(Value));
        else
          SetOrdProp(Obj, P, Integer(Value));
        end;
      tkFloat:
        case GetTypeData(P^.PropType^)^.FloatType of
          ftSingle: SetFloatProp(Obj, P, Single(Value));
          ftDouble: SetFloatProp(Obj, P, Double(Value));
          ftComp: SetFloatProp(Obj, P, Comp(Value));
          ftCurr: SetFloatProp(Obj, P, Currency(Value));
        else
          SetFloatProp(Obj, P, Extended(Value));
        end;
      { a short string's from a string (AnsiString), as Delphi 7 takes it (measured); SetStrProp
        keeps its first n characters }
      TypInfo.tkString, tkLString: SetStrProp(Obj, P, string(Value));
      tkWString: SetWideStrProp(Obj, P, WideString(Value));
      tkVariant: SetVariantProp(Obj, P, Variant(Value));
      tkInt64: SetInt64Prop(Obj, P, Int64(Value));
      tkMethod: SetMethodProp(Obj, P, TMethod(Value));
      tkInterface: SetInterfaceProp(Obj, P, IInterface(Value));
      tkClass:
        if Supports(IOTAComponent(Value), INTAComponent, N) then SetObjectProp(Obj, P, N.GetPersistent)
        else SetObjectProp(Obj, P, nil);
    else
      Result := False;
    end;
  except
    Result := False;
  end;
  if Result and (FDesigner <> nil) then FDesigner.Modified;
end;

function TSdOtaComponent.GetPropValue(Index: Integer; var Value): Boolean;
begin
  Result := ReadProp(PropByIndex(Index), Value);
end;

function TSdOtaComponent.GetPropValueByName(const Name: string; var Value): Boolean;
begin
  Result := ReadProp(PropNamed(Name), Value);
end;

function TSdOtaComponent.SetProp(Index: Integer; const Value): Boolean;
begin
  Result := WriteProp(PropByIndex(Index), Value);
end;

function TSdOtaComponent.SetPropByName(const Name: string; const Value): Boolean;
begin
  Result := WriteProp(PropNamed(Name), Value);
end;

{ as TComponent.GetChildren: the root's components (of the root), a container's controls }
function TSdOtaComponent.GetChildren(Param: Pointer; Proc: TOTAGetChildCallback): Boolean;
var
  I: Integer;
  Go: Boolean;
  C: TPersistent;
begin
  Result := True;
  if not Assigned(Proc) then Exit;
  Go := True;
  if (FDesigner <> nil) and (FInstance = FDesigner.Root) then
  begin
    for I := 0 to FDesigner.Root.ComponentCount - 1 do
    begin
      C := FDesigner.Root.Components[I];
      if (C is TControl) and (TControl(C).Parent <> FDesigner.Form) and (TControl(C).Parent <> nil) then Continue;
      Proc(Param, Wrap(C), Go);
      if not Go then Break;
    end;
  end
  else if FInstance is TWinControl then
    for I := 0 to TWinControl(FInstance).ControlCount - 1 do
    begin
      Proc(Param, Wrap(TWinControl(FInstance).Controls[I]), Go);
      if not Go then Break;
    end;
end;

function TSdOtaComponent.GetControlCount: Integer;
begin
  if (FDesigner <> nil) and (FInstance = FDesigner.Root) and (FDesigner.Form <> nil) then
    Result := FDesigner.Form.ControlCount
  else if FInstance is TWinControl then Result := TWinControl(FInstance).ControlCount
  else Result := 0;
end;

function TSdOtaComponent.GetControl(Index: Integer): IOTAComponent;
var
  W: TWinControl;
begin
  Result := nil;
  if (FDesigner <> nil) and (FInstance = FDesigner.Root) and (FDesigner.Form <> nil) then W := FDesigner.Form
  else if FInstance is TWinControl then W := TWinControl(FInstance)
  else Exit;
  if (Index >= 0) and (Index < W.ControlCount) then Result := Wrap(W.Controls[Index]);
end;

function TSdOtaComponent.GetComponentCount: Integer;
begin
  if FInstance is TComponent then Result := TComponent(FInstance).ComponentCount else Result := 0;
end;

function TSdOtaComponent.GetComponent(Index: Integer): IOTAComponent;
begin
  if (FInstance is TComponent) and (Index >= 0) and (Index < TComponent(FInstance).ComponentCount) then
    Result := Wrap(TComponent(FInstance).Components[Index])
  else
    Result := nil;
end;

function TSdOtaComponent.Select(AddToSelection: Boolean): Boolean;
begin
  Result := FDesigner <> nil;
  if Result then FDesigner.Select(FInstance, AddToSelection);
end;

function TSdOtaComponent.Focus(AddToSelection: Boolean): Boolean;
var
  I: Integer;
  P: TEditorPage;
begin
  Result := Select(AddToSelection);
  if not Result or (OtaHost = nil) then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    P := OtaHost.Pages(I);
    if P.Designer = FDesigner then
    begin
      OtaHost.ShowPage(P);
      P.ShowDesign(True);
      Exit;
    end;
  end;
end;

{ the designer may refuse (a component of the ancestor form): then it is still there and the
  result is False }
function TSdOtaComponent.Delete: Boolean;
var
  Name: string;
begin
  Result := (FDesigner <> nil) and (FInstance <> FDesigner.Root);
  if not Result then Exit;
  if FInstance is TComponent then Name := TComponent(FInstance).Name else Name := '';
  FDesigner.Select(FInstance, False);
  FDesigner.DeleteSelected;
  Result := (Name = '') or (FDesigner.Root.FindComponent(Name) = nil);
  if Result then
  begin
    FInstance := nil;
    FreeProps;                       // the properties of the component that went
  end;
end;

function TSdOtaComponent.GetPersistent: TPersistent;
begin
  Result := FInstance;
end;

function TSdOtaComponent.NtaGetComponent: TComponent;
begin
  if FInstance is TComponent then Result := TComponent(FInstance) else Result := nil;
end;

{ ---------------------------------------------------------------- TSdOtaModuleInfo }

constructor TSdOtaModuleInfo.Create(AType: TOTAModuleType; const AName, AFileName, AFormName,
  ADesignClass: string);
begin
  inherited Create;
  FType := AType;
  FName := AName;
  FFileName := AFileName;
  FFormName := AFormName;
  FDesignClass := ADesignClass;
end;

{ a form unit's kind (a data module) and design class, from its form file and its unit, once }
procedure TSdOtaModuleInfo.NeedFormClass;
var
  Anc: string;
begin
  if FFormFile = '' then Exit;
  Anc := FormAncestor(FFileName, FFormFile);
  FFormFile := '';
  if SameText(Anc, 'TDataModule') then FType := omtDataModule;
  if (Anc <> '') and not SameText(Anc, 'TForm') then FDesignClass := Anc;
end;

function TSdOtaModuleInfo.GetModuleType: TOTAModuleType;
begin
  NeedFormClass;
  Result := FType;
end;

function TSdOtaModuleInfo.GetName: string; begin Result := FName; end;
function TSdOtaModuleInfo.GetFileName: string; begin Result := FFileName; end;
function TSdOtaModuleInfo.GetFormName: string; begin Result := FFormName; end;

function TSdOtaModuleInfo.GetDesignClass: string;
begin
  NeedFormClass;
  Result := FDesignClass;
end;

procedure TSdOtaModuleInfo.GetCoClasses(CoClasses: TStrings); begin end;
function TSdOtaModuleInfo.GetCustomId: string; begin Result := ''; end;
{ the unit's additional files: its module's, when it is open (a creator's files too), else the
  ones its text names }
procedure TSdOtaModuleInfo.GetAdditionalFiles(Files: TStrings);
var
  M: TSdOtaModule;
  I: Integer;
begin
  if (Files = nil) or (OtaModules = nil) then Exit;
  M := OtaModules.Find(FFileName, False);
  if M <> nil then
  begin
    for I := 0 to M.FAdditional.Count - 1 do Files.Add(M.FAdditional[I]);
    Exit;
  end;
  M := TSdOtaModule.Create(FFileName);
  try
    M.ScanAdditionalFiles;
    for I := 0 to M.FAdditional.Count - 1 do Files.Add(M.FAdditional[I]);
  finally
    M.Free;
  end;
end;

function TSdOtaModuleInfo.OpenModule: IOTAModule;
begin
  Result := nil;
  if (OtaHost = nil) or (FFileName = '') then Exit;
  if OtaHost.OpenFile(FFileName, False) <> nil then Result := OtaModules.ModuleIntf(FFileName);
end;

{ ---------------------------------------------------------------- TSdOtaProjectOptions }

type
  { where an option is kept: a compiler switch (its letter), a number, a string, a flag (0 / 1),
    the version keys; or nowhere - an option of Delphi's C++, Kylix and assembler pages, read as
    its type's default, set to nothing }
  TOptKind = (okSwitch, okInt, okStr, okBool, okKeys, okNone);
  TOptDef = record
    Name, Section, Key: string;
    Kind: TOptKind;
    TypeKind: TTypeKind;          // what GetOptionNames says (Delphi's property type)
    Default: Integer;             // a number's when the .dof has none
    Listed: Boolean;              // in GetOptionNames (else a name of D7 Studio's before)
    NoneType: Char;               // okNone: its type's letter (b, f, i, t, e, l, z)
  end;

const
  { Delphi 7's option names, as its IOTAProjectOptions.GetOptionNames gives them - the published
    properties of coreide70's OptIntf.TCompilerOptions, VerInf.TVersionInfo and delphide70's
    PasProjOpts.TProjOptsManager, in that order -, and where the .dof keeps them:
    "Name=kind|section|key|default". Kinds: s switch (Byte), w warning (Byte), i number, t string,
    f flag (Boolean), e enumeration (a number), k the version keys (TStringList); n + b/f/i/t/e/l/z:
    not kept (Byte, Boolean, Integer, string, enumeration, TStringList, set). A name with "-" first
    is not listed (D7 Studio's name before Delphi's was found). }
  OptTable: array[0..246] of string = (
    'Align=s|Compiler|A', 'BoolEval=s|Compiler|B', 'Assertions=s|Compiler|C', 'UnitDebugInfo=s|Compiler|D',
    'ImportedData=s|Compiler|G', 'LongStrings=s|Compiler|H', 'IOChecks=s|Compiler|I', 'WriteableConst=s|Compiler|J',
    'LocalSymbols=s|Compiler|L', 'TypeInfo=s|Compiler|M', 'Optimization=s|Compiler|O', 'OpenStrings=s|Compiler|P',
    'OverflowChecks=s|Compiler|Q', 'RangeChecks=s|Compiler|R', 'StackChecks=s|Compiler|S', 'TypedAddress=s|Compiler|T',
    'SafeDivide=s|Compiler|U', 'VarStringChecks=s|Compiler|V', 'StackFrames=s|Compiler|W', 'ExtendedSyntax=s|Compiler|X',
    'ReferenceInfo=s|Compiler|Y', 'MinEnumSize=s|Compiler|Z',
    'DebugInfo=f|Linker|DebugInfo', 'RemoteSymbols=f|Linker|RemoteSymbols', 'OutputObj=e|Linker|OutputObjs',
    'HintFlag=f|Compiler|ShowHints|1', 'WarnFlag=f|Compiler|ShowWarnings|1', 'StackSize=i|Linker|MinStackSize|16384',
    'MaxStackSize=i|Linker|MaxStackSize|1048576', 'ResourceReserve=ni', 'ImageBase=i|Linker|ImageBase|4194304',
    'Target=ne', 'MapFile=e|Linker|MapFile', 'GenDRC=nf', 'GenDUI=nf', 'CompileName=nt',
    'Defines=t|Directories|Conditionals', 'SysDefines=nt', 'OutputDir=t|Directories|OutputDir',
    'UnitOutputDir=t|Directories|UnitOutputDir', 'UnitDir=t|Directories|SearchPath', 'ObjDir=t|Directories|SearchPath',
    'SrcDir=t|Directories|SearchPath', 'ResDir=t|Directories|SearchPath', 'NamespacePrefix=t|Compiler|NamespacePrefix',
    'PkgDllDir=t|Directories|PackageDLLOutputDir', 'OptionsString=nt', 'SOName=nt', 'SOPrefix=nt', 'SOPrefixDefined=nf',
    'SOSuffix=nt', 'SOVersion=nt', 'DynamicLoader=nt',
    'WarnSymbolDeprecated=w|Compiler|SymbolDeprecated|1', 'WarnSymbolLibrary=w|Compiler|SymbolLibrary|1',
    'WarnSymbolPlatform=w|Compiler|SymbolPlatform|1', 'WarnUnitLibrary=w|Compiler|UnitLibrary|1',
    'WarnUnitPlatform=w|Compiler|UnitPlatform|1', 'WarnUnitDeprecated=w|Compiler|UnitDeprecated|1',
    'WarnHresultCompat=w|Compiler|HResultCompat|1', 'WarnHidingMember=w|Compiler|HidingMember|1',
    'WarnHiddenVirtual=w|Compiler|HiddenVirtual|1', 'WarnGarbage=w|Compiler|Garbage|1',
    'WarnBoundsError=w|Compiler|BoundsError|1', 'WarnZeroNilCompat=w|Compiler|ZeroNilCompat|1',
    'WarnStringConstTrunced=w|Compiler|StringConstTruncated|1', 'WarnForLoopVarVarpar=w|Compiler|ForLoopVarVarPar|1',
    'WarnTypedConstVarpar=w|Compiler|TypedConstVarPar|1', 'WarnAsgToTypedConst=w|Compiler|AsgToTypedConst|1',
    'WarnCaseLabelRange=w|Compiler|CaseLabelRange|1', 'WarnForVariable=w|Compiler|ForVariable|1',
    'WarnConstructingAbstract=w|Compiler|ConstructingAbstract|1', 'WarnComparisonFalse=w|Compiler|ComparisonFalse|1',
    'WarnComparisonTrue=w|Compiler|ComparisonTrue|1', 'WarnComparingSignedUnsigned=w|Compiler|ComparingSignedUnsigned|1',
    'WarnCombiningSignedUnsigned=w|Compiler|CombiningSignedUnsigned|1',
    'WarnUnsupportedConstruct=w|Compiler|UnsupportedConstruct|1', 'WarnFileOpen=w|Compiler|FileOpen|1',
    'WarnFileOpenUnitsrc=w|Compiler|FileOpenUnitSrc|1', 'WarnBadGlobalSymbol=w|Compiler|BadGlobalSymbol|1',
    'WarnDuplicateCtorDtor=w|Compiler|DuplicateConstructorDestructor|1',
    'WarnInvalidDirective=w|Compiler|InvalidDirective|1', 'WarnPackageNoLink=w|Compiler|PackageNoLink|1',
    'WarnPackagedThreadvar=w|Compiler|PackageThreadVar|1', 'WarnImplicitImport=w|Compiler|ImplicitImport|1',
    'WarnHppemitIgnored=w|Compiler|HPPEMITIgnored|1', 'WarnNoRetval=w|Compiler|NoRetVal|1',
    'WarnUseBeforeDef=w|Compiler|UseBeforeDef|1', 'WarnForLoopVarUndef=w|Compiler|ForLoopVarUndef|1',
    'WarnUnitNameMismatch=w|Compiler|UnitNameMismatch|1', 'WarnNoCfgFileFound=w|Compiler|NoCFGFileFound|1',
    'WarnMessageDirective=w|Compiler|MessageDirective|1', 'WarnImplicitVariants=w|Compiler|ImplicitVariants|1',
    'WarnUnicodeToLocale=w|Compiler|UnicodeToLocale|1', 'WarnLocaleToUnicode=w|Compiler|LocaleToUnicode|1',
    'WarnImagebaseMultiple=w|Compiler|ImagebaseMultiple|1', 'WarnSuspiciousTypecast=w|Compiler|SuspiciousTypecast|1',
    'WarnPrivatePropaccessor=w|Compiler|PrivatePropAccessor|1', 'WarnUnsafeType=w|Compiler|UnsafeType',
    'WarnUnsafeCode=w|Compiler|UnsafeCode', 'WarnUnsafeCast=w|Compiler|UnsafeCast',
    'PkgDcpDir=t|Directories|PackageDCPOutputDir', 'UsePackages=f|Directories|UsePackages',
    'Packages=t|Directories|Packages', 'UnitAliases=t|Compiler|UnitAliases', 'ExeDescription=t|Linker|ExeDescription',
    'ImplicitBuild=nf', 'RuntimeOnly=nf', 'DesigntimeOnly=nf', 'DebugSourcePath=t|Directories|DebugSourceDirs',
    'ImageDebugInfo=nf', 'HeapSize=ni', 'MaxHeapSize=ni', 'LinkMaxErrors=ni', 'LinkShowMangle=nf', 'LinkGenImportLib=nf',
    'LinkGenLib=nf', 'LinkNoStateFiles=nf', 'LinkSubsysMajor=ni', 'LinkSubsysMinor=ni', 'LinkCaseSensitiveLink=nf',
    'LinkCalculateChecksum=nf', 'LinkFastTLS=nf', 'LinkReplaceResources=nf', 'LinkUserMajor=ni', 'LinkUserMinor=ni',
    'LinkImageComment=nt', 'LinkDelayLoad=nt', 'CppDebugInfo=nf', 'LineNumbers=nf', 'AutoRegVars=nf',
    'MergeDupStrs=nf', 'EnableInLines=nf', 'ShowWarnings=ne', 'StdStackFrame=nf', 'TreatEnumsAsInts=nf', 'PCH=ne',
    'ShowInfoMsgs=nf', 'ShowExtendedMsgs=nf', 'GenDll=nf', 'GenConsoleApp=nf', 'GenPackage=nf', 'GenStaticLibrary=nf',
    'ShowLinkerWarnings=nf', 'LinkDebugVcl=nf', 'InstructionSet=ne', 'Alignment=ne', 'CallingConvention=ne',
    'RegisterVars=ne', 'Ansi=ne', 'AutoDep=nf', 'Underscore=nf', 'PICCodeGen=nf', 'FastFloat=nf', 'PentiumFloat=nf',
    'NestedComments=nf', 'MFCCompat=nf', 'IdentLen=ni', 'MemberPrecision=nf', 'ForLoops=nf', 'TwoChar=nf',
    'CodeModifiers=nf', 'EnableRTTI=nf', 'EnableExceptions=nf', 'EHLocalInfo=nf', 'EHDtor=nf', 'EHPrologs=nf',
    'ZeroBaseClass=nf', 'ZeroClassFunction=nf', 'ForceCppCompile=nf', 'MemberPointer=ne', 'VTables=ne', 'Templates=ne',
    'PchPath=nt', 'PchStopAfter=nt', 'UseDynamicRtl=nf', 'MultiThreaded=nf', 'ATLMultiUse=nf', 'ATLDebugQI=nf',
    'ATLCoinitMultiThreaded=nf', 'ATLAutoRegisterInproc=nf', 'ATLDebugRefCount=nf', 'ATLDebug=nf', 'ATLThreading=ne',
    'CodeOpt=ne', 'FloatSupport=ne', 'IncludePath=nt', 'LibPath=nt', 'DebugPath=nt', 'ReleasePath=nt', 'LibraryList=nt',
    'TasmViaCppOpts=nt', 'ClearPackageCache=nf', 'ClearUnitCache=nf', 'MarkModified=nf', 'CaseSensitive=nf',
    'ExtendedDictionary=nf', 'PurgeComment=nf', 'PageSize=ni', 'ListFile=nt', 'TasmCrossReference=nf',
    'TasmSymbolTables=nf', 'TasmGenerateListing=nf', 'TasmIncludeConditionals=nf', 'TasmIncludeErrors=nf',
    'TasmExpanded=nf', 'TasmCaseCheckingOn=nf', 'TasmAllCase=nf', 'TasmDebugOn=nf', 'TasmFullDebug=nf',
    'TasmWarningsOn=nf', 'TasmWarningsLevel1=nf', 'TasmHashTable=ni', 'TasmPasses=ni', 'TasmSymbolLength=ni',
    'TasmDirective=nt', 'NoAskLibs=nf', 'CGGlobalStackAccesses=nf', 'CGThisPointer=nf', 'CGInlinePointer=nf',
    'CGLinkCGLib=nf',
    'AutoIncBuildNum=f|Version Info|AutoIncBuild', 'Build=i|Version Info|Build', 'CodePage=i|Version Info|CodePage|1252',
    'IncludeVersionInfo=f|Version Info|IncludeVerInfo', 'Keys=k|Version Info Keys', 'Locale=i|Version Info|Locale|1033',
    'MajorVersion=i|Version Info|MajorVer|1', 'MinorVersion=i|Version Info|MinorVer', 'ModuleAttribs=nz',
    'Release=i|Version Info|Release',
    'HostApplication=t|Parameters|HostApplication', 'RunParams=t|Parameters|RunParams', 'EnvVars=nl', 'SysVars=nl',
    'Launcher=t|Parameters|Launcher', 'UseLauncher=f|Parameters|UseLauncher', 'DebugCWD=t|Parameters|DebugCWD',
    'RemoteHost=t|Parameters|RemoteHost', 'RemotePath=t|Parameters|RemotePath',
    'RemoteLauncher=t|Parameters|RemoteLauncher', 'RemoteCWD=t|Parameters|RemoteCWD',
    'RemoteDebug=f|Parameters|RemoteDebug',
    '-ShowHints=f|Compiler|ShowHints|1', '-ConsoleApp=i|Linker|ConsoleApp|1', '-MinStackSize=i|Linker|MinStackSize|16384',
    '-OutputObjs=i|Linker|OutputObjs');
  KeysSection = 'Version Info Keys';

{ OptTable's entry I }
function OptDef(I: Integer): TOptDef;
var
  S, K: string;
  P: Integer;

  function Part: string;
  begin
    P := Pos('|', S);
    if P = 0 then P := Length(S) + 1;
    Result := Copy(S, 1, P - 1);
    Delete(S, 1, P);
  end;

begin
  S := OptTable[I];
  Result.Listed := S[1] <> '-';
  if not Result.Listed then Delete(S, 1, 1);
  P := Pos('=', S);
  Result.Name := Copy(S, 1, P - 1);
  Delete(S, 1, P);
  K := Part;
  Result.Section := Part;
  Result.Key := Part;
  Result.Default := StrToIntDef(Part, 0);
  case K[1] of
    's', 'w':
      begin
        Result.Kind := okSwitch;
        if K[1] = 'w' then Result.Kind := okInt;
        Result.TypeKind := tkInteger;
      end;
    'i':
      begin
        Result.Kind := okInt;
        Result.TypeKind := tkInteger;
      end;
    'e':
      begin
        Result.Kind := okInt;
        Result.TypeKind := tkEnumeration;
      end;
    't':
      begin
        Result.Kind := okStr;
        Result.TypeKind := tkLString;
      end;
    'f':
      begin
        Result.Kind := okBool;
        Result.TypeKind := tkEnumeration;
      end;
    'k':
      begin
        Result.Kind := okKeys;
        Result.TypeKind := tkClass;
      end;
  else
    begin
      Result.Kind := okNone;
      Result.NoneType := K[2];
      case K[2] of
        'f', 'e': Result.TypeKind := tkEnumeration;
        't': Result.TypeKind := tkLString;
        'l': Result.TypeKind := tkClass;
        'z': Result.TypeKind := tkSet;
      else
        Result.TypeKind := tkInteger;
      end;
    end;
  end;
end;

function OptIndex(const Name: string): Integer;
var
  I, P, Q: Integer;
begin
  for I := Low(OptTable) to High(OptTable) do
  begin
    P := Pos('=', OptTable[I]);
    if OptTable[I][1] = '-' then Q := 2 else Q := 1;
    if (P - Q = Length(Name)) and (StrLIComp(PChar(OptTable[I]) + Q - 1, PChar(Name), Length(Name)) = 0) then
    begin
      Result := I;
      Exit;
    end;
  end;
  Result := -1;
end;

function OtaProjectOptionNames: TOTAOptionNameArray;
var
  I, N: Integer;
  D: TOptDef;
begin
  SetLength(Result, Length(OptTable));
  N := 0;
  for I := Low(OptTable) to High(OptTable) do
  begin
    D := OptDef(I);
    if not D.Listed then Continue;
    Result[N].Name := D.Name;
    Result[N].Kind := D.TypeKind;
    Inc(N);
  end;
  SetLength(Result, N);
end;

constructor TSdOtaProjectOptions.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FKeys := TStringList.Create;
end;

destructor TSdOtaProjectOptions.Destroy;
begin
  FKeys.Free;
  inherited;
end;

function TSdOtaProjectOptions.Project: TSdProject;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.GroupProject(FFileName);
end;

{ Project | Options of this project, active or not (Delphi's TProjectOptions.EditOptions) }
procedure TSdOtaProjectOptions.EditOptions;
var
  P: TSdProject;
begin
  P := Project;
  if P <> nil then OtaHost.EditProjectOptions(P);
end;

function TSdOtaProjectOptions.GetOptionValue(const ValueName: string): Variant;
var
  P: TSdProject;
  I: Integer;
  D: TOptDef;
begin
  Result := Unassigned;
  P := Project;
  if P = nil then Exit;
  I := OptIndex(ValueName);
  if I < 0 then Exit;
  D := OptDef(I);
  case D.Kind of
    { the project's version keys: the list experts change in place - each change is written back
      (KeysChanged), and the list is read again, a change made in Project | Options too }
    okKeys:
      begin
        FKeys.OnChange := nil;
        FKeys.Clear;
        P.Dof.ReadSectionValues(KeysSection, FKeys);
        FKeys.OnChange := KeysChanged;
        Result := Integer(FKeys);
      end;
    okStr: Result := P.OptStr(D.Section, D.Key, '');
    okBool: Result := P.OptInt(D.Section, D.Key, D.Default) <> 0;
    okSwitch: Result := P.OptInt(D.Section, D.Key, CompilerSwitchDefault(D.Key[1]));
    okInt: Result := P.OptInt(D.Section, D.Key, D.Default);
  else
    { an option no page of D7 Studio has: its type's default }
    case D.NoneType of
      't': Result := '';
      'f': Result := False;
    else
      Result := 0;
    end;
  end;
end;

procedure TSdOtaProjectOptions.SetOptionValue(const ValueName: string; const Value: Variant);
var
  P: TSdProject;
  I: Integer;
  D: TOptDef;
  L: TStrings;
  M: TSdOtaModule;
begin
  P := Project;
  if P = nil then Exit;
  I := OptIndex(ValueName);
  if I < 0 then Exit;
  D := OptDef(I);
  case D.Kind of
    okKeys:
      begin
        L := TStrings(Integer(Value));
        if L = nil then Exit;
        WriteKeys(P, L);
      end;
    okStr: P.SetOptStr(D.Section, D.Key, VarToStr(Value));
    okBool: P.SetOptInt(D.Section, D.Key, Ord(Boolean(Value)));
    okSwitch, okInt: P.SetOptInt(D.Section, D.Key, Integer(Value));
  else
    Exit;
  end;
  FModified := True;
  { what the compiler is told: the next compile should build everything }
  if SameText(D.Section, 'Compiler') or SameText(D.Section, 'Linker') or SameText(D.Section, 'Directories') then
  begin
    M := OtaModules.Find(FFileName, False);
    if M is TSdOtaProject then TSdOtaProject(M).FShouldBuild := True;
  end;
  OtaHost.ProjectOptionsChanged(P);
end;

procedure TSdOtaProjectOptions.WriteKeys(P: TSdProject; L: TStrings);
var
  I: Integer;
begin
  P.Dof.EraseSection(KeysSection);
  for I := 0 to L.Count - 1 do P.SetOptStr(KeysSection, L.Names[I], L.ValueFromIndex[I]);
end;

{ an expert changed the list of Values['Keys'] in place }
procedure TSdOtaProjectOptions.KeysChanged(Sender: TObject);
var
  P: TSdProject;
begin
  P := Project;
  if P = nil then Exit;
  WriteKeys(P, FKeys);
  FModified := True;
  OtaHost.ProjectOptionsChanged(P);
end;

function TSdOtaProjectOptions.GetOptionNames: TOTAOptionNameArray;
begin
  Result := OtaProjectOptionNames;
end;

procedure TSdOtaProjectOptions.SetModifiedState(State: Boolean);
begin
  FModified := State;
end;

function TSdOtaProjectOptions.GetModifiedState: Boolean;
begin
  Result := FModified;
end;

{ ---------------------------------------------------------------- resources }

function TSdOtaResEntry.SameResource(E: TSdOtaResEntry): Boolean;
begin
  Result := (E.FTypeOrd = FTypeOrd) and (E.FNameOrd = FNameOrd) and SameText(E.FTypeName, FTypeName) and
    SameText(E.FNameName, FNameName) and (E.FLanguage = FLanguage);
end;

procedure TSdOtaResEntry.TakeValues(E: TSdOtaResEntry);
begin
  FDataVersion := E.FDataVersion;
  FVersion := E.FVersion;
  FCharacteristics := E.FCharacteristics;
  FFlags := E.FFlags;
  FData := E.FData;
end;

function TSdOtaResEntry.GetResourceType: PChar;
begin
  Result := ResIdPtr(FTypeOrd, FTypeName);
end;

function TSdOtaResEntry.GetResourceName: PChar;
begin
  Result := ResIdPtr(FNameOrd, FNameName);
end;

{ a type or name of the API: an ordinal (high word 0) or a string, which resource compilers
  keep in capitals }
procedure SetResId(P: PChar; var Ord: Integer; var Name: string);
begin
  SplitResId(P, Ord, Name);
  Name := UpperCase(Name);
end;

function SameResId(P: PChar; Ord: Integer; const Name: string): Boolean;
begin
  if Cardinal(P) shr 16 = 0 then Result := (Ord >= 0) and (Cardinal(P) = Cardinal(Ord))
  else Result := (Ord < 0) and SameText(StrPas(P), Name);
end;

function TSdOtaResEntry.Change(NewType, NewName: PChar): Boolean;
begin
  SetResId(NewType, FTypeOrd, FTypeName);
  SetResId(NewName, FNameOrd, FNameName);
  if FOwner <> nil then FOwner.Changed;
  Result := True;
end;

function TSdOtaResEntry.GetHeaderValue(HeaderValue: TOTAResHeaderValue; var Value: Integer): Boolean;
begin
  Result := True;
  case HeaderValue of
    hvFlags: Value := FFlags;
    hvLanguage: Value := FLanguage;
    hvDataVersion: Value := FDataVersion;
    hvVersion: Value := FVersion;
    hvCharacteristics: Value := FCharacteristics;
  else
    Result := False;
  end;
end;

function TSdOtaResEntry.SetHeaderValue(HeaderValue: TOTAResHeaderValue; Value: Integer): Boolean;
begin
  Result := True;
  case HeaderValue of
    hvFlags: FFlags := Value;
    hvLanguage: FLanguage := Value;
    hvDataVersion: FDataVersion := Value;
    hvVersion: FVersion := Value;
    hvCharacteristics: FCharacteristics := Value;
  else
    Result := False;
  end;
  if Result and (FOwner <> nil) then FOwner.Changed;
end;

function TSdOtaResEntry.GetData: Pointer;
begin
  if FData = '' then
  begin
    Result := nil;
    Exit;
  end;
  UniqueString(FData);
  Result := Pointer(FData);
end;

function TSdOtaResEntry.GetDataSize: Integer;
begin
  Result := Length(FData);
end;

procedure TSdOtaResEntry.SetDataSize(NewSize: Integer);
var
  Old: Integer;
begin
  if NewSize < 0 then NewSize := 0;
  Old := Length(FData);
  SetLength(FData, NewSize);
  if NewSize > Old then FillChar(FData[Old + 1], NewSize - Old, 0);
  if FOwner <> nil then FOwner.Changed;
end;

function TSdOtaResEntry.GetEntryHandle: TOTAHandle;
begin
  Result := Pointer(Self);
end;

constructor TSdOtaProjectResource.Create(const AProjectFile: string);
begin
  inherited Create;
  FProjectFile := AProjectFile;
  FItems := TList.Create;
  FEntries := TInterfaceList.Create;
  FDiskBytes := '';
  FStamp := FileStampU(ResFile);
  if FStamp.Exists then
    try
      FDiskBytes := ReadFileU(ResFile);
      Parse(FDiskBytes);
    except
      on E: Exception do OtaError(E, 'reading ' + ResFile);
    end;
  FBase := Serialize;
end;

constructor TSdOtaProjectResource.CreateCopy(Source: TSdOtaProjectResource);
begin
  inherited Create;
  FProjectFile := Source.FProjectFile;
  FItems := TList.Create;
  FEntries := TInterfaceList.Create;
  FCopy := True;
  Source.Sync;
  Parse(Source.Serialize);
  FBase := Serialize;
end;

destructor TSdOtaProjectResource.Destroy;
begin
  ClearEntries;
  FEntries.Free;
  FItems.Free;
  inherited;
end;

function TSdOtaProjectResource.ResFile: string;
begin
  Result := ChangeFileExt(FProjectFile, '.res');
end;

function TSdOtaProjectResource.Entry(Index: Integer): TSdOtaResEntry;
begin
  Result := TSdOtaResEntry(FItems[Index]);
end;

procedure TSdOtaProjectResource.AddEntry(E: TSdOtaResEntry);
begin
  E.FOwner := Self;
  FItems.Add(E);
  FEntries.Add(IOTAResourceEntry(E));
end;

{ the entries an expert still holds answer on their own (no owner to write to) }
procedure TSdOtaProjectResource.ClearEntries;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do Entry(I).FOwner := nil;
  FItems.Clear;
  FEntries.Clear;
end;

procedure TSdOtaProjectResource.Parse(const Bytes: string);
var
  L: TList;
  I: Integer;
begin
  ClearEntries;
  L := TList.Create;
  try
    ParseEntries(Bytes, L);
    for I := 0 to L.Count - 1 do AddEntry(TSdOtaResEntry(L[I]));
  finally
    L.Free;
  end;
end;

{ The file read again (Sync): an entry an expert holds stays the entry of its resource - the one of
  the same type, name and language takes the file's values -, the others are made, the ones the
  file has no more let go (they answer on their own). }
procedure TSdOtaProjectResource.Reparse(const Bytes: string);
var
  L: TList;
  I, J: Integer;
  N, O: TSdOtaResEntry;
  Old: TList;
  Hold: TInterfaceList;
begin
  L := TList.Create;
  Old := TList.Create;
  { the old entries' references, until the new list has the ones that stay }
  Hold := TInterfaceList.Create;
  try
    ParseEntries(Bytes, L);
    Old.Assign(FItems);
    for I := 0 to FEntries.Count - 1 do Hold.Add(FEntries[I]);
    FItems.Clear;
    FEntries.Clear;
    for I := 0 to L.Count - 1 do
    begin
      N := TSdOtaResEntry(L[I]);
      O := nil;
      for J := 0 to Old.Count - 1 do
        if (Old[J] <> nil) and TSdOtaResEntry(Old[J]).SameResource(N) then
        begin
          O := TSdOtaResEntry(Old[J]);
          Old[J] := nil;
          Break;
        end;
      if O <> nil then
      begin
        O.TakeValues(N);
        L[I] := O;
        N.Free;
      end;
      AddEntry(TSdOtaResEntry(L[I]));
    end;
    for J := 0 to Old.Count - 1 do
      if Old[J] <> nil then TSdOtaResEntry(Old[J]).FOwner := nil;
  finally
    Hold.Free;
    Old.Free;
    L.Free;
  end;
end;

{ the entries of a .res file's bytes into L (made, not added) }
procedure TSdOtaProjectResource.ParseEntries(const Bytes: string; L: TList);
var
  P, Start, Q: Integer;
  DataSize, HeaderSize, Rest: Cardinal;
  E: TSdOtaResEntry;
  TOrd, NOrd: Integer;
  TName, NName: string;
begin
  P := 1;
  while P + 8 <= Length(Bytes) do
  begin
    Start := P;
    DataSize := GetD(Bytes, P);
    HeaderSize := GetD(Bytes, P + 4);
    { the sizes as they are (unsigned): a damaged file stops the reading, it never runs backwards;
      a last entry cut short keeps what is there }
    Rest := Cardinal(Length(Bytes) - Start + 1);
    if (HeaderSize < 16) or (HeaderSize > Rest) then Break;
    if DataSize > Rest - HeaderSize then DataSize := Rest - HeaderSize;
    Q := P + 8;
    ReadResId(Bytes, Q, TOrd, TName);
    ReadResId(Bytes, Q, NOrd, NName);
    { the empty entry that starts a 32-bit resource file }
    if not ((DataSize = 0) and (TOrd = 0) and (NOrd = 0)) then
    begin
      E := TSdOtaResEntry.Create;
      E.FTypeOrd := TOrd;
      E.FTypeName := TName;
      E.FNameOrd := NOrd;
      E.FNameName := NName;
      Q := Start + Integer(HeaderSize) - 16;
      E.FDataVersion := GetD(Bytes, Q);
      E.FFlags := GetW(Bytes, Q + 4);
      E.FLanguage := GetW(Bytes, Q + 6);
      E.FVersion := GetD(Bytes, Q + 8);
      E.FCharacteristics := GetD(Bytes, Q + 12);
      E.FData := Copy(Bytes, Start + Integer(HeaderSize), DataSize);
      L.Add(E);
    end;
    P := Start + Integer(HeaderSize) + Integer(DataSize);
    P := Start + (((P - Start) + 3) and not 3);
  end;
end;

function TSdOtaProjectResource.Serialize: string;
var
  I: Integer;
  E: TSdOtaResEntry;
  Ids, H: string;
begin
  { the empty entry first }
  Result := DWordStr(0) + DWordStr(32) + WordStr($FFFF) + WordStr(0) + WordStr($FFFF) +
    WordStr(0) + StringOfChar(#0, 16);
  for I := 0 to FItems.Count - 1 do
  begin
    E := Entry(I);
    Ids := ResIdBytes(E.FTypeOrd, E.FTypeName) + ResIdBytes(E.FNameOrd, E.FNameName);
    while (8 + Length(Ids)) mod 4 <> 0 do Ids := Ids + #0;
    H := Ids + DWordStr(E.FDataVersion) + WordStr(E.FFlags) + WordStr(E.FLanguage) +
      DWordStr(E.FVersion) + DWordStr(E.FCharacteristics);
    Result := Result + DWordStr(Length(E.FData)) + DWordStr(8 + Length(H)) + H + E.FData;
    while Length(Result) mod 4 <> 0 do Result := Result + #0;
  end;
end;

{ the file changed on the disk (the compiler's .res, the IDE's manifest) and nothing was changed
  here: read again. Every entry the API gives asks first - the file is read only when its time
  or size is not what it was }
procedure TSdOtaProjectResource.Sync;
var
  Disk: string;
  Stamp: TSdFileStamp;
begin
  { in an update the entries are being changed: the file is not looked at for each of them }
  if FCopy or (FUpdating > 0) then Exit;
  Stamp := FileStampU(ResFile);
  if not Stamp.Exists or SameFileStamp(Stamp, FStamp) then Exit;
  try
    Disk := ReadFileU(ResFile);
  except
    Exit;
  end;
  FStamp := Stamp;
  if Disk = FDiskBytes then Exit;
  FDiskBytes := Disk;
  { changes made here and not written yet (an entry's data changed through GetData) win: the next
    Flush writes them over the new file }
  if Dirty then Exit;
  Reparse(Disk);
  FBase := Serialize;
end;

function TSdOtaProjectResource.Dirty: Boolean;
begin
  Result := Serialize <> FBase;
end;

{ the entries into the file when they changed (True: the file was written) }
function TSdOtaProjectResource.WriteChanges: Boolean;
var
  S: string;
begin
  Result := False;
  if FUpdating > 0 then Exit;
  S := Serialize;
  if S = FBase then Exit;                // not Dirty: that would serialize the entries twice
  { a copy's changes count as written: they are its own }
  if FCopy then
  begin
    FBase := S;
    Exit;
  end;
  try
    WriteFileU(ResFile, S);
    FDiskBytes := S;
    FBase := S;
    FStamp := FileStampU(ResFile);
    Result := True;
  except
    on E: Exception do OtaError(E, 'writing ' + ResFile);
  end;
end;

{ the changes written (a save of the project, a compile, its close): the IDE's views of the file
  follow. The IDE's own commands change the entries between BeginUpdate and EndUpdate, which
  writes them without this - the command shows its result itself. }
procedure TSdOtaProjectResource.Flush;
begin
  if WriteChanges and (OtaHost <> nil) then OtaHost.ResourcesWritten(ResFile);
end;

{ a change made through the interfaces: kept until the project is saved or compiled (Delphi's);
  the IDE's views show the entries as they are now }
procedure TSdOtaProjectResource.Changed;
begin
  if (FUpdating = 0) and (OtaHost <> nil) then OtaHost.ResourcesWritten(ResFile);
end;

function TSdOtaProjectResource.ResFileBytes: string;
begin
  Result := Serialize;
end;

procedure TSdOtaProjectResource.BeginUpdate;
begin
  if FUpdating = 0 then Sync;            // the file as it is now, before the changes
  Inc(FUpdating);
end;

procedure TSdOtaProjectResource.EndUpdate;
begin
  if FUpdating > 0 then Dec(FUpdating);
  if FUpdating = 0 then WriteChanges;
end;

function TSdOtaProjectResource.AddNotifier(const ANotifier: IOTANotifier): Integer;
begin
  Result := -1;
end;

function TSdOtaProjectResource.GetFileName: string;
begin
  Result := ResFile;
end;

function TSdOtaProjectResource.GetModified: Boolean;
begin
  Result := Dirty;
end;

function TSdOtaProjectResource.GetModule: IOTAModule;
begin
  Result := OtaModules.ModuleIntf(FProjectFile);
end;

function TSdOtaProjectResource.MarkModified: Boolean;
begin
  Changed;
  Result := True;
end;

procedure TSdOtaProjectResource.RemoveNotifier(Index: Integer);
begin
end;

procedure TSdOtaProjectResource.Show;
begin
end;

function TSdOtaProjectResource.GetEntryCount: Integer;
begin
  Sync;
  Result := FEntries.Count;
end;

function TSdOtaProjectResource.GetEntry(Index: Integer): IOTAResourceEntry;
begin
  Sync;
  if (Index < 0) or (Index >= FEntries.Count) then Result := nil
  else Result := IOTAResourceEntry(FEntries[Index]);
end;

function TSdOtaProjectResource.GetEntryFromHandle(EntryHandle: TOTAHandle): IOTAResourceEntry;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FItems.Count - 1 do
    if Pointer(Entry(I)) = EntryHandle then
    begin
      Result := IOTAResourceEntry(FEntries[I]);
      Exit;
    end;
end;

function TSdOtaProjectResource.IndexOfEntry(ResType, Name: PChar; Language: Integer): Integer;
var
  I: Integer;
  E: TSdOtaResEntry;
begin
  Sync;
  Result := -1;
  for I := 0 to FItems.Count - 1 do
  begin
    E := Entry(I);
    if ((Language < 0) or (E.FLanguage = Language)) and SameResId(ResType, E.FTypeOrd, E.FTypeName) and
      SameResId(Name, E.FNameOrd, E.FNameName) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function TSdOtaProjectResource.FindEntry(ResType, Name: PChar): IOTAResourceEntry;
var
  I: Integer;
begin
  I := IndexOfEntry(ResType, Name, -1);
  if I >= 0 then Result := IOTAResourceEntry(FEntries[I]) else Result := nil;
end;

procedure TSdOtaProjectResource.DeleteEntry(EntryHandle: TOTAHandle);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Pointer(Entry(I)) = EntryHandle then
    begin
      Entry(I).FOwner := nil;
      FItems.Delete(I);
      FEntries.Delete(I);
      Changed;
      Exit;
    end;
end;

function TSdOtaProjectResource.CreateEntry(ResType, Name: PChar; Flags, LanguageId: Word;
  DataVersion, Version, Characteristics: Integer): IOTAResourceEntry;
var
  E: TSdOtaResEntry;
begin
  Result := nil;
  { a file holds a type and name once per language (a string table in two languages) }
  if IndexOfEntry(ResType, Name, LanguageId) >= 0 then Exit;
  E := TSdOtaResEntry.Create;
  SetResId(ResType, E.FTypeOrd, E.FTypeName);
  SetResId(Name, E.FNameOrd, E.FNameName);
  E.FFlags := Flags;
  E.FLanguage := LanguageId;
  E.FDataVersion := DataVersion;
  E.FVersion := Version;
  E.FCharacteristics := Characteristics;
  AddEntry(E);
  Result := E;
  Changed;
end;

{ ---------------------------------------------------------------- TSdOtaModuleManager }

constructor TSdOtaModuleManager.Create;
begin
  inherited Create;
  FNames := TStringList.Create;
  FRefs := TInterfaceList.Create;
  FResNames := TStringList.Create;
  FResRefs := TInterfaceList.Create;
  FSearch := TSdOtaSearchOptions.Create;
end;

destructor TSdOtaModuleManager.Destroy;
begin
  FSearch := nil;
  FResRefs.Free;
  FResNames.Free;
  FRefs.Free;
  FNames.Free;
  inherited;
end;

{ the project group's module: its file, or its name when it has none yet; none for the empty group
  Close All leaves - no project, no file -, as Delphi 7 lists no module then (measured) }
function TSdOtaModuleManager.GroupKey: string;
var
  G: TSdProjectGroup;
begin
  Result := '';
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if (G = nil) or ((G.FileName = '') and (G.Count = 0)) then Exit;
  if G.FileName <> '' then Result := G.FileName else Result := G.Name + '.bpg';
end;

{ a group module of another name is one of a group before (closed, another one opened, or none
  now): it goes first - its notifiers told Destroyed, as of Delphi's workspace before -; a Save
  Project Group As renames the module instead (Renamed) }
function TSdOtaModuleManager.GroupModule: IOTAModule;
var
  I: Integer;
  Key, Stale: string;
begin
  Result := nil;
  Key := GroupKey;
  repeat
    Stale := '';
    for I := 0 to FNames.Count - 1 do
      if (FNames.Objects[I] is TSdOtaProjectGroup) and not SameText(FNames[I], Key) then Stale := FNames[I];
    { a notifier told may change the modules: looked for again }
    if Stale <> '' then Forget(Stale);
  until Stale = '';
  if Key <> '' then Result := ModuleIntf(Key);
end;

function TSdOtaModuleManager.KindOf(const FileName: string): TClass;
var
  G: TSdProjectGroup;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  if (G <> nil) and SameFile(FileName, GroupKey) then
  begin
    Result := TSdOtaProjectGroup;
    Exit;
  end;
  if (OtaHost.Project <> nil) and SameFile(FileName, OtaHost.Project.FileName) then
  begin
    Result := TSdOtaProject;
    Exit;
  end;
  { a project of the group - loaded, or closed in it (IOTAProjectGroup.Projects lists it) -, or a
    package open beside the group (a module, in no project group: Delphi's misc projects) }
  if (G <> nil) and ((G.IndexOf(FileName) >= 0) or (G.IndexOfBeside(FileName) >= 0)) then
  begin
    Result := TSdOtaProject;
    Exit;
  end;
  if SameFile(FileName, OtaHost.TypeLibraryFile) then
  begin
    Result := TSdOtaTypeLibModule;
    Exit;
  end;
  if PageOf(FileName) <> nil then Result := TSdOtaModule;
end;

{ a name that names its file whatever the current folder is: with a drive and its root, a network
  name, a marked Unicode name }
function FullPath(const Name: string): Boolean;
begin
  Result := IsUnicodePath(Name) or
    ((Length(Name) >= 3) and (Name[1] in ['A'..'Z', 'a'..'z']) and (Name[2] = ':') and (Name[3] in ['\', '/'])) or
    ((Length(Name) >= 2) and (Name[1] in ['\', '/']) and (Name[2] in ['\', '/']));
end;

{ the name the IDE knows a file by - a module's, a page's, the project's, a project of the
  group's, the group's -, also when an expert writes it otherwise: relative, with forward
  slashes, its 8.3 name (one module per file). The name itself when the IDE does not know the
  file; a bare name (an untitled file's) only as it is written. ModulesOnly: a module's name or
  the name itself - all a look for an existing module needs: a module named as a page or a
  project is found by that name's real name as well. The real name of a file looks at the disk
  (its long name): a module keeps the one of its full name. }
function TSdOtaModuleManager.KnownName(const FileName: string; ModulesOnly: Boolean): string;
var
  Wanted: WideString;
  Found: string;
  I: Integer;
  G: TSdProjectGroup;

  function RealName(const Name: string): WideString;
  begin
    Result := DisplayPath(ExpandPathU(StringReplace(Name, '/', '\', [rfReplaceAll])));
  end;

  function Known(const Name: string): Boolean;
  begin
    Result := (Name <> '') and (SameText(Name, FileName) or WideSameText(RealName(Name), Wanted));
    if Result then Found := Name;
  end;

  { Known for module I, with the real name the module keeps }
  function KnownModule(I: Integer): Boolean;
  var
    M: TSdOtaModule;
    Name: string;
  begin
    Name := FNames[I];
    if (Name = '') or SameText(Name, FileName) or not FullPath(Name) then
    begin
      Result := Known(Name);
      Exit;
    end;
    M := TSdOtaModule(FNames.Objects[I]);
    if M.FRealKey <> Name then
    begin
      M.FRealName := RealName(Name);
      M.FRealKey := Name;
    end;
    Result := WideSameText(M.FRealName, Wanted);
    if Result then Found := Name;
  end;

begin
  Result := FileName;
  if (OtaHost = nil) or (FileName = '') then Exit;
  if (Pos('\', FileName) = 0) and (Pos('/', FileName) = 0) and (Pos(':', FileName) = 0) then Exit;
  Wanted := RealName(FileName);
  Found := '';
  for I := 0 to FNames.Count - 1 do
    if KnownModule(I) then Break;
  if not ModulesOnly then
  begin
    if Found = '' then
      for I := 0 to OtaHost.PageCount - 1 do
        if Known(OtaHost.Pages(I).FileName) then Break;
    if (Found = '') and (OtaHost.Project <> nil) then Known(OtaHost.Project.FileName);
    G := OtaHost.ProjectGroup;
    if (Found = '') and (G <> nil) then
      for I := 0 to G.AllCount - 1 do
        if Known(G.AllFile(I)) then Break;
    if Found = '' then Known(GroupKey);
    if Found = '' then Known(OtaHost.TypeLibraryFile);
  end;
  if Found <> '' then Result := Found;
end;

function TSdOtaModuleManager.Find(const FileName: string; Make: Boolean): TSdOtaModule;
var
  I: Integer;
  K: TClass;
  Name: string;
begin
  Result := nil;
  if FileName = '' then Exit;
  Name := FileName;
  I := FNames.IndexOf(Name);
  { the module of another name of the file; a look that makes none needs only the modules' names
    - none at all without modules (a page's edits ask at each change) }
  if (I < 0) and (Make or (FNames.Count > 0)) then
  begin
    Name := KnownName(FileName, not Make);
    if Name <> FileName then I := FNames.IndexOf(Name);
  end;
  if I >= 0 then
  begin
    Result := TSdOtaModule(FNames.Objects[I]);
    { a project or group file opened as text before it was one (a module creator of the file):
      its file's module is the project's or the group's now - one module per file }
    if not Make or (Result.ClassType <> TSdOtaModule) or
      not (IsProjectFile(Name) or IsProjectGroupFile(Name)) or (KindOf(Name) = TSdOtaModule) then Exit;
    Forget(Name);
    Result := nil;
  end;
  if not Make then Exit;
  K := KindOf(Name);
  if K = TSdOtaProjectGroup then Result := TSdOtaProjectGroup.Create(Name)
  else if K = TSdOtaProject then Result := TSdOtaProject.Create(Name)
  else if K = TSdOtaTypeLibModule then Result := TSdOtaTypeLibModule.Create(Name)
  else if K = TSdOtaModule then Result := TSdOtaModule.Create(Name)
  else Exit;
  FNames.AddObject(Name, Result);
  FRefs.Add(IOTAModule(Result));
  if K = TSdOtaModule then Result.ScanAdditionalFiles;
end;

function TSdOtaModuleManager.ModuleIntf(const FileName: string): IOTAModule;
var
  M: TSdOtaModule;
begin
  M := Find(FileName);
  if M = nil then Result := nil else Result := M;
end;

procedure TSdOtaModuleManager.List(L: TInterfaceList);
var
  G: TSdProjectGroup;
  I: Integer;
  P: TEditorPage;
  F: string;

  procedure AddModule(const M: IOTAModule);
  begin
    if (M <> nil) and (L.IndexOf(M) < 0) then L.Add(M);
  end;

begin
  L.Clear;
  if OtaHost = nil then Exit;
  G := OtaHost.ProjectGroup;
  { the group - also without projects, as Delphi's workspace -, its loaded projects (every one, the
    active one or not), then the packages open beside the group }
  if G <> nil then
  begin
    AddModule(GroupModule);
    for I := 0 to G.AllCount - 1 do
      if G.AllProject(I) <> nil then AddModule(ModuleIntf(G.AllFile(I)));
  end;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    P := OtaHost.Pages(I);
    if P.FormTextPage <> nil then Continue;      // its form's text is the module (View as Text)
    F := P.FileName;
    if (OtaHost.Project <> nil) and SameFile(F, OtaHost.Project.FileName) then Continue;
    if (G <> nil) and (G.IndexOf(F) >= 0) then Continue;
    AddModule(ModuleIntf(F));
  end;
  { the Type Library view's library: a file's module, after the pages }
  if OtaHost.TypeLibraryFile <> '' then AddModule(ModuleIntf(OtaHost.TypeLibraryFile));
end;

function TSdOtaModuleManager.CurrentModule: IOTAModule;
var
  P: TEditorPage;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  P := OtaHost.ActivePage;
  if P <> nil then
  begin
    if P.FormTextPage <> nil then P := P.FormTextPage;
    Result := ModuleIntf(P.FileName);
  end
  else if OtaHost.Project <> nil then
    Result := ModuleIntf(OtaHost.Project.FileName);
end;

function TSdOtaModuleManager.FindFormModule(const FormName: string): IOTAModule;
var
  I, K: Integer;
  Page: TEditorPage;
  U: TProjectUnit;
  G: TSdProjectGroup;
  P: TSdProject;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    Page := OtaHost.Pages(I);
    if Page.HasForm and (Page.FormOwner = nil) and (Page.Designer <> nil) and (Page.Designer.Root <> nil) and
      SameText(Page.Designer.Root.Name, FormName) then
    begin
      Result := ModuleIntf(Page.FileName);
      Exit;
    end;
  end;
  { an open unit of a project by the form its project source names: the active project's first,
    then the other loaded projects' - the group's, the packages beside it }
  G := OtaHost.ProjectGroup;
  if G = nil then Exit;
  for K := -1 to G.AllCount - 1 do
  begin
    if K < 0 then P := OtaHost.Project else P := G.AllProject(K);
    if (P = nil) or ((K >= 0) and (P = OtaHost.Project)) then Continue;
    for I := 0 to P.UnitCount - 1 do
    begin
      U := P.Units[I];
      if SameText(U.FormName, FormName) and (PageOf(U.FileName) <> nil) and
        (PageOf(U.FileName).FormTextPage = nil) then
      begin
        Result := ModuleIntf(U.FileName);
        Exit;
      end;
    end;
  end;
end;

function TSdOtaModuleManager.ProjectResource(const ProjectFile: string): IOTAProjectResource;
var
  I: Integer;
  R: TSdOtaProjectResource;
begin
  Result := nil;
  if ProjectFile = '' then Exit;
  I := FResNames.IndexOf(ProjectFile);
  if I < 0 then
  begin
    R := TSdOtaProjectResource.Create(ProjectFile);
    FResNames.AddObject(ProjectFile, R);
    I := FResRefs.Add(IOTAProjectResource(R));
  end;
  Result := IOTAProjectResource(FResRefs[I]);
end;

function TSdOtaModuleManager.ProjectResourceCopy(const ProjectFile: string): IOTAProjectResource;
var
  I: Integer;
begin
  Result := nil;
  if ProjectResource(ProjectFile) = nil then Exit;
  I := FResNames.IndexOf(ProjectFile);
  Result := TSdOtaProjectResource.CreateCopy(TSdOtaProjectResource(FResNames.Objects[I]));
end;

procedure TSdOtaModuleManager.FlushResources;
var
  I: Integer;
begin
  for I := 0 to FResNames.Count - 1 do FlushResource(I);
end;

{ the resource object Index written when it changed; a failure is reported (OtaError) }
procedure TSdOtaModuleManager.FlushResource(Index: Integer);
begin
  try
    TSdOtaProjectResource(FResNames.Objects[Index]).Flush;
  except
    on E: Exception do OtaError(E, 'project resource');
  end;
end;

{ the resource object of a project written and let go (an expert's reference keeps it alive) }
procedure TSdOtaModuleManager.DropResource(const ProjectFile: string);
var
  I: Integer;
begin
  I := FResNames.IndexOf(ProjectFile);
  if I < 0 then Exit;
  FlushResource(I);
  FResNames.Delete(I);
  FResRefs.Delete(I);
end;

function TSdOtaModuleManager.SearchOptions: IOTAReplaceOptions;
begin
  Result := FSearch;
end;

procedure TSdOtaModuleManager.Forget(const FileName: string);
var
  I: Integer;
  M: TSdOtaModule;
  Keep: IOTAModule;
begin
  I := FNames.IndexOf(FileName);
  if I < 0 then Exit;
  M := TSdOtaModule(FNames.Objects[I]);
  Keep := M;
  FNames.Delete(I);
  FRefs.Delete(I);
  { as a module goes in Delphi: its own notifiers first, while its editors are still there - an
    expert's module notifier takes its editor notifiers off then (GExperts asserts that they are
    still registered) -, then its editors' notifiers and its line tracker's }
  CallNotifiers(M.Notifiers, nkDestroyed);
  CallNotifiers(M.SourceNotifiers, nkDestroyed);
  CallNotifiers(M.FormNotifiers, nkDestroyed);
  if M.FTrackerObj <> nil then
    CallNotifiers(TSdOtaLineTracker(M.FTrackerObj).FNotifiers, nkDestroyed);
  M.EditorsGone;
end;

procedure TSdOtaModuleManager.ForgetProjects;
var
  I: Integer;
  G: TSdProjectGroup;

  { a package open beside the group: its module stays (the group's going leaves it open) }
  function Beside(const FileName: string): Boolean;
  begin
    Result := (G <> nil) and (G.IndexOfBeside(FileName) >= 0);
  end;

begin
  if OtaHost <> nil then G := OtaHost.ProjectGroup else G := nil;
  FlushResources;
  for I := FNames.Count - 1 downto 0 do
    if ((FNames.Objects[I] is TSdOtaProject) and not Beside(FNames[I])) or (FNames.Objects[I] is TSdOtaProjectGroup) then
      Forget(FNames[I]);
  for I := FResNames.Count - 1 downto 0 do
    if not Beside(FResNames[I]) then
    begin
      FResRefs.Delete(I);
      FResNames.Delete(I);
    end;
end;

procedure TSdOtaModuleManager.ForgetProject(const ProjectFile: string);
var
  I: Integer;
begin
  DropResource(ProjectFile);
  I := FNames.IndexOf(ProjectFile);
  if (I >= 0) and (FNames.Objects[I] is TSdOtaProject) then Forget(FNames[I]);
end;

procedure TSdOtaModuleManager.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  for I := 0 to FNames.Count - 1 do TSdOtaModule(FNames.Objects[I]).DropModule(Module);
end;

{ a page's module: none for a unit whose form is shown as text, whose text is a module of its own }
function ModuleOfPage(Page: TEditorPage; Make: Boolean): TSdOtaModule;
begin
  Result := nil;
  if (Page = nil) or (OtaModules = nil) or (Page.FormTextPage <> nil) then Exit;
  Result := OtaModules.Find(Page.FileName, Make);
end;

{ the editor notifiers of a module that are IOTAEditorNotifier: told of a view }
procedure CallViewNotifiers(M: TSdOtaModule; Activated: Boolean; Op: TOperation);
var
  C: TViewCall;
begin
  if (M = nil) or (M.SourceNotifiers.Active = 0) then Exit;
  C.View := M.ViewOf(M.FileName);
  C.Activated := Activated;
  C.Op := Op;
  M.SourceNotifiers.Each(IOTAEditorNotifier, ViewNotifyOne, @C, 'IOTAEditorNotifier');
end;

procedure TSdOtaModuleManager.PageOpened(Page: TEditorPage);
begin
  CallViewNotifiers(ModuleOfPage(Page, False), False, opInsert);
end;

procedure TSdOtaModuleManager.PageClosing(Page: TEditorPage);
begin
  if FDesignPage = Page then FDesignPage := nil;
  if (Page <> nil) and (Page.FormTextPage = nil) then ModuleClosed(Page.FileName);
end;

{ a module's page closes, or a unit's module goes while its page stays - its form shown as text,
  which Delphi 7 opens as a module of its own as it closes the unit's (measured): the editor
  notifiers are told the view goes, the module goes; a project's source page closes, the project
  stays }
procedure TSdOtaModuleManager.ModuleClosed(const FileName: string);
var
  M: TSdOtaModule;
begin
  M := Find(FileName, False);
  if M = nil then Exit;
  CallViewNotifiers(M, False, opRemove);
  if (M is TSdOtaProject) or (M is TSdOtaProjectGroup) then Exit;
  Forget(M.FileName);
end;

procedure TSdOtaModuleManager.PageActivated(Page: TEditorPage);
var
  M: TSdOtaModule;
begin
  M := ModuleOfPage(Page, False);
  if M = nil then Exit;
  CallViewNotifiers(M, True, opInsert);
  DesignShown(Page);
end;

procedure TSdOtaModuleManager.PageEdited(Page: TEditorPage; Position, LinesAdded: Integer);
var
  M: TSdOtaModule;
  L: Integer;
begin
  M := ModuleOfPage(Page, False);
  if M = nil then Exit;
  M.State.LastEdit := OffsetToEditPos(Page.Editor, Position);
  M.State.ChangedAt := Now;
  if (LinesAdded <> 0) and (M.FTrackerObj <> nil) then
  begin
    L := Page.Editor.LineFromPos(Position) + 1;
    { lines inserted at a line's start push that line down too: its text moves }
    if (LinesAdded > 0) and (Position = Page.Editor.PosFromLine(L - 1)) then Dec(L);
    TSdOtaLineTracker(M.FTrackerObj).Edited(L, LinesAdded);
  end;
  CallNotifiers(M.SourceNotifiers, nkModified);
  CallNotifiers(M.Notifiers, nkModified);
end;

procedure TSdOtaModuleManager.PageSaving(Page: TEditorPage);
var
  M: TSdOtaModule;
begin
  M := ModuleOfPage(Page, False);
  if M = nil then Exit;
  CallNotifiers(M.Notifiers, nkBeforeSave);
  CallNotifiers(M.SourceNotifiers, nkBeforeSave);
  M.FormNotifiers.Each(IOTAFormNotifier, FormSavingOne, nil, 'IOTAFormNotifier.FormSaving');
  CallNotifiers(M.FormNotifiers, nkBeforeSave);
end;

procedure TSdOtaModuleManager.PageSaved(Page: TEditorPage);
var
  M: TSdOtaModule;
begin
  M := ModuleOfPage(Page, False);
  if M = nil then Exit;
  M.State.ChangedAt := 0;
  CallNotifiers(M.SourceNotifiers, nkAfterSave);
  CallNotifiers(M.FormNotifiers, nkAfterSave);
  CallNotifiers(M.Notifiers, nkAfterSave);
end;

procedure TSdOtaModuleManager.PageRenamed(Page: TEditorPage; const OldFileName: string);
begin
  Renamed(OldFileName, Page.FileName);
end;

procedure TSdOtaModuleManager.Renamed(const OldFileName, NewFileName: string);
var
  I: Integer;
  M: TSdOtaModule;
  NewName: string;
begin
  { a project's resource object follows its project: made again for the new name when asked for }
  DropResource(OldFileName);
  { one module per file: one the new name has already (the file open as a page of its own) goes }
  if not SameText(OldFileName, NewFileName) then Forget(NewFileName);
  I := FNames.IndexOf(OldFileName);
  if I < 0 then Exit;
  M := TSdOtaModule(FNames.Objects[I]);
  NewName := NewFileName;
  M.FileName := NewName;
  M.EditorsRenamed(OldFileName, NewName);
  FNames[I] := NewName;
  if (M is TSdOtaProject) and (TSdOtaProject(M).FOptionsObj <> nil) then
    TSdOtaProjectOptions(TSdOtaProject(M).FOptionsObj).FFileName := NewName;
  M.Notifiers.Each(IOTAModuleNotifier, ModuleRenamedOne, @NewName, 'IOTAModuleNotifier.ModuleRenamed');
end;

{ a component of a page's form renamed - the designer tells it before the name changes, so it is
  found by either name; the form itself too }
procedure TSdOtaModuleManager.ComponentRenamed(Page: TEditorPage; const OldName, NewName: string);
var
  M: TSdOtaModule;
  C: TRenameCall;
  Root: TComponent;
begin
  M := ModuleOfPage(Page, False);
  if (M = nil) or (M.FormNotifiers.Active = 0) then Exit;
  C.Component := nil;
  if (Page.Designer <> nil) and (Page.Designer.Root <> nil) then
  begin
    Root := Page.Designer.Root;
    if NewName <> '' then C.Component := Pointer(Root.FindComponent(NewName));
    if (C.Component = nil) and (OldName <> '') then C.Component := Pointer(Root.FindComponent(OldName));
    if (C.Component = nil) and (SameText(Root.Name, OldName) or SameText(Root.Name, NewName)) then
      C.Component := Pointer(Root);
  end;
  C.OldName := OldName;
  C.NewName := NewName;
  M.FormNotifiers.Each(IOTAFormNotifier, ComponentRenamedOne, @C, 'IOTAFormNotifier.ComponentRenamed');
end;

{ the module of the page a designer works on }
function TSdOtaModuleManager.ModuleOfDesigner(const D: IDesigner): TSdOtaModule;
var
  I: Integer;
  P: TEditorPage;
  Root: TComponent;
begin
  Result := nil;
  if (D = nil) or (OtaHost = nil) then Exit;
  Root := D.Root;
  if Root = nil then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    P := OtaHost.Pages(I);
    if (P.Designer <> nil) and (P.Designer.Root = Root) then
    begin
      Result := ModuleOfPage(P, False);
      Exit;
    end;
  end;
end;

{ a component placed or pasted on a form (Came), or deleted from it: ComponentRenamed with no old
  name, or with no new name - Delphi's form notifiers learn of new and deleted components so }
procedure TSdOtaModuleManager.ComponentCameOrWent(const D: IDesigner; Item: TPersistent; Came: Boolean);
var
  M: TSdOtaModule;
  C: TRenameCall;
begin
  if not (Item is TComponent) or (TComponent(Item).Name = '') then Exit;
  M := ModuleOfDesigner(D);
  if (M = nil) or (M.FormNotifiers.Active = 0) then Exit;
  C.Component := Pointer(Item);
  if Came then C.NewName := TComponent(Item).Name else C.OldName := TComponent(Item).Name;
  M.FormNotifiers.Each(IOTAFormNotifier, ComponentRenamedOne, @C, 'IOTAFormNotifier.ComponentRenamed');
end;

procedure TSdOtaModuleManager.ItemInserted(const D: IDesigner; Item: TPersistent);
begin
  ComponentCameOrWent(D, Item, True);
end;

procedure TSdOtaModuleManager.ItemDeleted(const D: IDesigner; Item: TPersistent);
begin
  ComponentCameOrWent(D, Item, False);
end;

{ the form changed in its designer: the form editor's notifiers and the module's are told
  Modified, as an edit of the text tells the source editor's }
procedure TSdOtaModuleManager.ItemsModified(const D: IDesigner);
var
  M: TSdOtaModule;
begin
  M := ModuleOfDesigner(D);
  if M = nil then Exit;
  CallNotifiers(M.FormNotifiers, nkModified);
  CallNotifiers(M.Notifiers, nkModified);
end;

procedure TSdOtaModuleManager.NeedDesignNotes;
begin
  if (FDesignNotes <> nil) or (DesignHost = nil) then Exit;
  FDesignNotes := TSdOtaDesignNotes.Create;
  DesignHost.AddNotification(FDesignNotes);
end;

procedure TSdOtaModuleManager.PageViewChanged(Page: TEditorPage);
begin
  DesignShown(Page);
end;

{ the forms of the open pages streamed out by a compile }
procedure TSdOtaModuleManager.FormsStreamed;
var
  L: TList;
  Keep: TInterfaceList;
  I: Integer;
  M: TSdOtaModule;
begin
  L := TList.Create;
  Keep := TInterfaceList.Create;
  try
    for I := 0 to FNames.Count - 1 do
    begin
      M := TSdOtaModule(FNames.Objects[I]);
      if (M.FormNotifiers.Active > 0) and M.HasForm then
      begin
        L.Add(M);
        Keep.Add(IOTAModule(M));
      end;
    end;
    for I := 0 to L.Count - 1 do
      TSdOtaModule(L[I]).FormNotifiers.Each(IOTAFormNotifier, FormSavingOne, nil, 'IOTAFormNotifier.FormSaving');
  finally
    Keep.Free;
    L.Free;
  end;
end;

{ the designer of a page became the one the user works in - its page activated, or F12 on the
  active page: IOTAFormNotifier.FormActivated, once until another page or view comes }
procedure TSdOtaModuleManager.DesignShown(Page: TEditorPage);
var
  M: TSdOtaModule;
begin
  if (Page = nil) or not Page.DesignView then
  begin
    FDesignPage := nil;
    Exit;
  end;
  if FDesignPage = Page then Exit;
  FDesignPage := Page;
  M := ModuleOfPage(Page, False);
  if M <> nil then
    M.FormNotifiers.Each(IOTAFormNotifier, FormActivatedOne, nil, 'IOTAFormNotifier.FormActivated');
end;

{ ---------------------------------------------------------------- TSdOtaDesignNotes }

procedure TSdOtaDesignNotes.ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  if OtaModules <> nil then OtaModules.ItemDeleted(ADesigner, AItem);
end;

procedure TSdOtaDesignNotes.ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  if OtaModules <> nil then OtaModules.ItemInserted(ADesigner, AItem);
end;

procedure TSdOtaDesignNotes.ItemsModified(const ADesigner: IDesigner);
begin
  if OtaModules <> nil then OtaModules.ItemsModified(ADesigner);
end;

procedure TSdOtaDesignNotes.SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
begin
end;

procedure TSdOtaDesignNotes.DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
begin
end;

procedure TSdOtaDesignNotes.DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
begin
end;

initialization
  OtaModules := TSdOtaModuleManager.Create;
end.
