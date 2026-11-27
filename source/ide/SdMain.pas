{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMain;

{ D7 Studio - main window: the menu bar and tool bars on the control bar,
  the dock with the tool views (Code Explorer, Project Manager, Object TreeView, Object Inspector, Components,
  Messages and the debugger views), the file pages with their code and design views and the
  status bar. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  Menus, ActnList, AppEvnts, ShellAPI, IniFiles, Clipbrd, SdDock, SdFileNames,
  SdUI, SdIcons, SdSettings, SdCrashLog, SdCompBar, SdTabStrip, SdSciEdit, SdEncoding, SdCodeInsight, SdFormSrc,
  SdCompletion, SdDesignHost, SdDelphiDir, SdDesignEnv, SdFormDesigner, SdObjInsp, SdCodeExplorer, SdObjTreeView, SdExplorerEdit,
  SdProject, SdProjectManager, SdTodoView, SdSearchResults, SdBreakpointsView,
  SdEditorPage, SdDialogs, SdDebugUI, SdDbgEngine, SdDesignWin, ComponentDesigner, SdEnvOptions,
  SdRepository, SdAddRepositoryDlg, SdProjectGroup, SdMsgInfo, SdBrowserFrame, SdTypeLib, SdImportTypeLibDlg, SdTypeLibViewFrame, ActiveX,
  SdRunParamsDlg, SdProjOptionsFrame, ImgList, SdEditorOptions, SdDebuggerOptions, SdCodeTemplates,
  SdCustomizeDlg, SdKeymaps, SdCpuView, SdDebugInspector, SdWatchViewFrame, SdTodo, SdAddTodoDlg, SdNewCompDlg, SdPackageViewFrame,
  SdPackageAddDlg, SdNavHistory, SdOptionsDlg, SdOtaCore, SdMessageView, SdResourceViewFrame, SdResources,
  SdResImage, SdResPage, SdOtaPalette, SdOtaViews, SdOtaToDo, SdNavBar, SdPageBar, SdZoom, SdHistory,
  SdHistoryFrame, SdUpdate;

const
  WM_SDTESTKEY = WM_APP + 76;          // test mode: the postkey command's key, from the message loop (CMTestKey)
  WM_SDNAVRECORD = WM_APP + 79;        // a jump is over: the browse history records it (NavMark)
  WM_SDTODOREFRESH = WM_APP + 87;      // the To-Do List made anew after a call of the view to an expert (TodoRefreshLater)
  WM_SDTODOPROJECT = WM_APP + 88;      // the active project changed: the experts' To-Do managers are told (TodoProjectLater)
  WM_SDINHERITRENAME = WM_APP + 89;    // a component of a form or frame was renamed: the forms built from it follow (WMInheritRename)
  WM_SDCLOSEBESIDE = WM_APP + 90;      // the editor of a package open beside the group was closed: the package closes (WMCloseBeside)
  WM_SDSWAPFORM = WM_APP + 91;         // an expert's View as Text / View as Form of a page, posted (WMSwapForm)
  WM_SDBROWSERREBUILD = WM_APP + 92;   // a unit of the active project was saved: the Browser made again (WMBrowserRebuild)
  WM_SDSHOWUPDATE = WM_APP + 93;       // a check for updates found a newer release: its dialog, out of the idle handler (WMShowUpdate)

type
  TMainForm = class;

  { the projects of one file that New makes (TMainForm.NewProjectOfKind) }
  TNewProjectKind = (npConsole, npPackage, npDll);

  { how a project opens (TMainForm.OpenProject): a group of its own - the group before is closed
    (an expert's OpenProject with NewProjGroup True) -, into the open group, which keeps its
    projects and files (Add Existing / New Project, an expert's OpenProject with NewProjGroup
    False, a project creator owned by the group, Install Component), or as Delphi's File | Open,
    Open Project, File | New, Reopen and Install Packages' Edit open it (Delphi's package create
    mode 1): a package beside the open group, which stays as it is, anything else in a group of
    its own }
  TOpenMode = (omNewGroup, omAddToGroup, omOpen);

  { an action of a menu that shows a command under Delphi's other name there (the designer's
    "Align To Grid", the editor's "Close Page"), and the command: it does what the command does
    and takes its state }
  TTwinActions = array[0..1] of TAction;

  { What Borland's design-time windows (action list editor, collection editor, menu designer
    ...) get from the shell; see SdDesignEnv. }
  TDesignWindowHost = class(TInterfacedObject, ISdDesignHost)
  private
    FMain: TMainForm;
  public
    function MainWindowRect: TRect;
    function WorkspaceOrigin: TPoint;
    procedure FocusInspector(Key: Char; const PropName: string);
    procedure SelectionChanged;
    procedure ComponentsChanged;
    function FindGlobalComponent(const Name: string): TComponent;
    procedure OpenRootByName(const RootName: string; Show: Boolean);
    procedure DesignDialog(Dialog: TDesignDialog);
  end;

  TMainServices = class(TIDEServices)
  private
    FMain: TMainForm;
  public
    function CodeInsight: TCodeInsight; override;
    function ProjectExeBase: string; override;
    procedure OpenFileAt(const FileName: string; Line, Col: Integer); override;
    procedure PageChanged(Page: TEditorPage); override;
    procedure FormRenamed(Page: TEditorPage; const OldName, NewName, OldClass, NewClass: string); override;
    function EvaluateForTip(const Expr: string; out V: TDbgVar): Boolean; override;
    function ChildrenForTip(const Expr: string; out Vars: TDbgVarArray): Boolean; override;
    procedure ToggleBreakpoint(Page: TEditorPage; Line: Integer); override;
    procedure ShowMessage(const Text: string); override;
    procedure ShowStatus(const Text: string); override;
    procedure EditorContextMenu(Page: TEditorPage; const ScreenPt: TPoint); override;
    procedure ShowPage(Page: TEditorPage); override;
    procedure EditorCommand(Page: TEditorPage; Cmd: TEdCmd; Arg: Integer); override;
    function AncestorDfms(Page: TEditorPage; const ClassName: string; Dfms: TStrings): Boolean; override;
    function FormBase(Page: TEditorPage; const ClassName: string; Dfms: TStrings): string; override;
    function FormUnitName(Page: TEditorPage; const ClassName: string): string; override;
    function DiagramBar: TWinControl; override;
    function NavigationBar: TWinControl; override;
    function ZoomBar: TWinControl; override;
    function HistoryBar: TWinControl; override;
    function DesignerBar: TWinControl; override;
    procedure HistoryViewMade(View: TSdHistoryView); override;
    procedure PageBarChanged(Page: TEditorPage); override;
    procedure PageEdited(Page: TEditorPage; Position, LinesAdded: Integer); override;
    procedure ErrorsChanged(Page: TEditorPage); override;
    procedure ComponentRenamed(Page: TEditorPage; const OldName, NewName: string); override;
    procedure EditorZoomed(Page: TEditorPage); override;
    function CIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean; override;
    function CIOwnAllowed(Page: TEditorPage): Boolean; override;
    function CIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean; override;
    function CIKeyPress(Page: TEditorPage; var Key: Char): Boolean; override;
    procedure CIChanged(Page: TEditorPage); override;
    procedure CICancel(Page: TEditorPage); override;
  end;

  TMainForm = class(TForm)
    ToolRow: TPanel;
    MainBar: TToolBar;
    tbNewOther: TToolButton;
    tbOpen: TToolButton;
    tbSave: TToolButton;
    tbSep1: TToolButton;
    tbSaveAll: TToolButton;
    tbOpenProject: TToolButton;
    tbSep2: TToolButton;
    tbAddToProject: TToolButton;
    tbRemoveFromProject: TToolButton;
    tbViewUnits: TToolButton;
    tbViewForms: TToolButton;
    tbToggleForm: TToolButton;
    tbNewForm: TToolButton;
    tbRun: TToolButton;
    tbPause: TToolButton;
    tbSep3: TToolButton;
    tbTraceInto: TToolButton;
    tbStepOver: TToolButton;
    tbProjOptions: TToolButton;
    tbSep4: TToolButton;
    tbSep5: TToolButton;
    tbSep6: TToolButton;
    tbSep7: TToolButton;
    tbBuild: TToolButton;
    tbCompile: TToolButton;
    tbReset: TToolButton;
    tbDesktops: TToolButton;
    DockSite: TPanel;
    CenterPanel: TPanel;
    MessageList: TListBox;
    CallStackList: TListBox;
    LocalsTree: TTreeView;
    FpuList: TListBox;
    MsgHintsList: TListBox;
    ErrorList: TListBox;
    DiagramBar: TToolBar;
    tbDiagExpandAll: TToolButton;
    tbDiagCollapseAll: TToolButton;
    tbDiagReset: TToolButton;
    ZoomBar: TToolBar;
    tbZoomOut: TToolButton;
    tbZoomIn: TToolButton;
    tbZoomSep: TToolButton;
    tbZoomReset: TToolButton;
    tbZoomFit: TToolButton;
    FileHistoryBar: TToolBar;
    tbHistPrevChange: TToolButton;
    tbHistNextChange: TToolButton;
    tbHistSep1: TToolButton;
    tbHistSideBySide: TToolButton;
    tbHistIgnoreBlanks: TToolButton;
    tbHistComparePrev: TToolButton;
    tbHistSep2: TToolButton;
    tbHistRestore: TToolButton;
    tbHistRestoreChange: TToolButton;
    tbHistSep3: TToolButton;
    tbHistLabel: TToolButton;
    HistoryBar: TToolBar;
    tbBrowseBack: TToolButton;
    tbBrowseForward: TToolButton;
    FilesBar: TToolBar;
    tbFileList: TToolButton;
    EventLogList: TListBox;
    StatusBar: TStatusBar;
    Icons: TImageList;
    ActionList: TActionList;
    FileNewVclApplicationCommand: TAction;
    aNewConsole: TAction;
    aNewPackage: TAction;
    FileNewUnitCommand: TAction;
    FileNewVclFormCommand: TAction;
    FileNewVclDataModuleCommand: TAction;
    FileNewVclFrameCommand: TAction;
    FileOpenCommand: TAction;
    FileOpenProjectCommand: TAction;
    FileSaveCommand: TAction;
    FileSaveAsCommand: TAction;
    FileSaveAllCommand: TAction;
    aReopenEncoding: TAction;
    aConvertEncoding: TAction;
    FileCloseCommand: TAction;
    FileCloseAllCommand: TAction;
    FileExitCommand: TAction;
    EditUndoCommand: TAction;
    EditRedoCommand: TAction;
    EditCutCommand: TAction;
    EditCopyCommand: TAction;
    EditPasteCommand: TAction;
    EditDeleteCommand: TAction;
    EditSelectAllCommand: TAction;
    aToggleComment: TAction;
    aIndent: TAction;
    aUnindent: TAction;
    aDuplicateLine: TAction;
    aMoveLinesUp: TAction;
    aMoveLinesDown: TAction;
    aJoinLines: TAction;
    aSelectNextOccurrence: TAction;
    aSelectAllOccurrences: TAction;
    aAddCaretAbove: TAction;
    aAddCaretBelow: TAction;
    aExpandSelection: TAction;
    aShrinkSelection: TAction;
    aFoldAll: TAction;
    aUnfoldAll: TAction;
    aFold: TAction;
    aUnfold: TAction;
    aFoldToggle: TAction;
    aFoldMethods: TAction;
    aFoldClasses: TAction;
    aFoldSections: TAction;
    aFoldUnit: TAction;
    aFoldNested: TAction;
    aFoldRegions: TAction;
    aCodeFolding: TAction;
    aZoomIn: TAction;
    aZoomOut: TAction;
    aZoomReset: TAction;
    aZoomFit: TAction;
    EditAlignGridCommand: TAction;
    EditFrontCommand: TAction;
    EditBackCommand: TAction;
    EditLockControlsCommand: TAction;
    SearchFindCommand: TAction;
    SearchFileFindCommand: TAction;
    SearchReplaceCommand: TAction;
    SearchAgainCommand: TAction;
    SearchGoToCommand: TAction;
    aFindDecl: TAction;
    aComplete: TAction;
    aTemplates: TAction;
    aParams: TAction;
    ViewPrjMgrCommand: TAction;
    aViewPackage: TAction;
    ViewObjInspCommand: TAction;
    ViewObjTreeViewCommand: TAction;
    aViewMessages: TAction;
    aViewErrorList: TAction;
    ViewToggleFormCommand: TAction;
    aViewDiagram: TAction;
    aDiagExpandAll: TAction;
    aDiagCollapseAll: TAction;
    aDiagReset: TAction;
    aViewHistory: TAction;
    aHistPrevChange: TAction;
    aHistNextChange: TAction;
    aHistSideBySide: TAction;
    aHistIgnoreBlanks: TAction;
    aHistComparePrev: TAction;
    aHistRestore: TAction;
    aHistRestoreChange: TAction;
    aHistLabel: TAction;
    aHistRemoveLabel: TAction;
    aHistGotoCode: TAction;
    aHistCopy: TAction;
    aHistRoutine: TAction;
    aBrowseBack: TAction;
    aBrowseForward: TAction;
    aFileList: TAction;
    ViewUnitCommand: TAction;
    ViewFormCommand: TAction;
    DebugBreakPointsCommand: TAction;
    DebugCallStackCommand: TAction;
    DebugWatchesCommand: TAction;
    DebugLocalVariablesCommand: TAction;
    DebugEventLogCommand: TAction;
    ProjectAddCommand: TAction;
    ProjectRemoveCommand: TAction;
    ProjectViewSourceCommand: TAction;
    ProjectCompileCommand: TAction;
    ProjectBuildCommand: TAction;
    ProjectSyntaxCommand: TAction;
    aInstallPackage: TAction;
    aUninstallPackage: TAction;
    aViewResources: TAction;
    aResAdd: TAction;
    ProjectOptionsCommand: TAction;
    RunRunCommand: TAction;
    RunRunNoDebugCommand: TAction;
    RunParametersCommand: TAction;
    RunStepOverCommand: TAction;
    RunTraceIntoCommand: TAction;
    RunGotoCursorCommand: TAction;
    RunUntilReturnCommand: TAction;
    RunPauseCommand: TAction;
    RunResetCommand: TAction;
    RunEvalModCommand: TAction;
    RunAddWatchCommand: TAction;
    aToggleBreak: TAction;
    ComponentAddtoPackageCommand: TAction;
    ComponentInstallPackagesCommand: TAction;
    ToolsOptionsCommand: TAction;
    HelpAboutCommand: TAction;
    aCheckUpdates: TAction;
    aPaneLeft: TAction;
    aPaneFloat: TAction;
    aPaneRight: TAction;
    aPaneBottom: TAction;
    aPaneBottomFull: TAction;
    aTabsTop: TAction;
    aTabsBottom: TAction;
    aTabsLeft: TAction;
    aTabsRight: TAction;
    aAutoHide: TAction;
    aPaneClose: TAction;
    aDsnRevert: TAction;
    aDsnAddToRepository: TAction;
    ViewSwapSourceFormCommand: TAction;
    aDsnTextDFM: TAction;
    aPaneHide: TAction;
    aViewHelp: TAction;
    aMsgViewSource: TAction;
    aMsgEditSource: TAction;
    aMsgClear: TAction;
    aMsgSave: TAction;
    aMsgCloseTab: TAction;
    aMsgClearAll: TAction;
    aMsgSaveAll: TAction;
    aMsgViewEditor: TAction;
    aStackViewSource: TAction;
    aStackEditSource: TAction;
    aMhClear: TAction;
    aMhCopy: TAction;
    aMhCopyAll: TAction;
    aMhEdit: TAction;
    aLogClear: TAction;
    aLogSave: TAction;
    aLogComment: TAction;
    aLogProperties: TAction;
    FileNewCommand: TAction;
    FileSaveProjectAsCommand: TAction;
    FileUseUnitCommand: TAction;
    FilePrintCommand: TAction;
    EditAlignCommand: TAction;
    EditSizeCommand: TAction;
    EditScaleCommand: TAction;
    EditTabOrderCommand: TAction;
    EditCreationOrderCommand: TAction;
    EditFlipChildrenAllCommand: TAction;
    EditFlipChildrenSelectedCommand: TAction;
    SearchIncrementalCommand: TAction;
    SearchFindErrCommand: TAction;
    SearchSymbolCommand: TAction;
    ViewToDoListCommand: TAction;
    ViewBrowserCommand: TAction;
    ViewCodeExplorerCommand: TAction;
    ecViewExplorer: TAction;
    ViewCompListCommand: TAction;
    aViewComponents: TAction;
    ViewWindowListCommand: TAction;
    ViewAddlMsgInfoCommand: TAction;
    DebugThreadsCommand: TAction;
    DebugModulesCommand: TAction;
    DebugCPUCommand: TAction;
    DebugFPUCommand: TAction;
    aDesktops: TAction;
    ViewSaveDesktopCommand: TAction;
    ViewDeleteDesktopCommand: TAction;
    ViewRuntimeDesktopCommand: TAction;
    ViewTypeLibraryCommand: TAction;
    ViewCustomizeCommand: TAction;
    aTbReset: TAction;
    ViewNextWindow: TAction;
    ProjectImportTypeLibraryCommand: TAction;
    ProjectAddRepositoryCommand: TAction;
    ProjectAddNewProjectCommand: TAction;
    ProjectAddExistingProjectCommand: TAction;
    ProjectInformationCommand: TAction;
    ProjectCompileAllCommand: TAction;
    ProjectBuildAllCommand: TAction;
    RunAttachCommand: TAction;
    RunRegisterComCommand: TAction;
    RunUnregisterComCommand: TAction;
    RunTraceToSourceCommand: TAction;
    RunShowCSIPCommand: TAction;
    RunDetachCommand: TAction;
    RunInspectCommand: TAction;
    RunAddSourceBreakpointCommand: TAction;
    RunAddAddressBreakpointCommand: TAction;
    RunAddDataBreakpointCommand: TAction;
    RunAddModuleLoadBreakpointCommand: TAction;
    ComponentNewCommand: TAction;
    ComponentImportAXCCommand: TAction;
    ComponentInstallCompositeCommand: TAction;
    ComponentPaletteCommand: TAction;
    ToolsEditorOptionsCommand: TAction;
    ToolsDebuggerOptionsCommand: TAction;
    aFormatterOptions: TAction;
    aFormatSource: TAction;
    aFormatProject: TAction;
    ToolsGalleryCommand: TAction;
    ToolsToolsCommand: TAction;
    HelpContentsCommand: TAction;
    HelpVclRefCommand: TAction;
    HelpDelphiToolsCommand: TAction;
    HelpWinSDKCommand: TAction;
    aProcess: TAction;
    AppEvents: TApplicationEvents;
    ReopenActions: TActionList;
    VerbActions: TActionList;
    WindowActions: TActionList;
    ToolActions: TActionList;
    WatchGroupActions: TActionList;
    InspCategoryActions: TActionList;
    HistoryActions: TActionList;
    DesktopActions: TActionList;
    WizardActions: TActionList;
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    New1: TMenuItem;
    FileNewVCLApplicationItem: TMenuItem;
    FileNewVclDataModule: TMenuItem;
    FileNewVclFormItem: TMenuItem;
    FileNewVclFrameItem: TMenuItem;
    FileNewUnitItem: TMenuItem;
    N3: TMenuItem;
    FileNewItem: TMenuItem;
    FileOpenItem: TMenuItem;
    FileOpenProjectItem: TMenuItem;
    FileClosedFilesItem: TMenuItem;
    FileSaveSeparater: TMenuItem;
    FileSaveItem: TMenuItem;
    FileSaveAsItem: TMenuItem;
    FileSaveProjectAs: TMenuItem;
    FileSaveAllItem: TMenuItem;
    FileCloseItem: TMenuItem;
    FileCloseAllItem: TMenuItem;
    FileMenuSeparator: TMenuItem;
    FileUseUnitItem: TMenuItem;
    N4: TMenuItem;
    miReopenEncoding: TMenuItem;
    miConvertEncoding: TMenuItem;
    N5: TMenuItem;
    FilePrintItem: TMenuItem;
    N6: TMenuItem;
    FileExitItem: TMenuItem;
    EditMenu: TMenuItem;
    EditUndoItem: TMenuItem;
    EditRedoItem: TMenuItem;
    N7: TMenuItem;
    EditCutItem: TMenuItem;
    EditCopyItem: TMenuItem;
    EditPasteItem: TMenuItem;
    EditDeleteItem: TMenuItem;
    EditSelectAll: TMenuItem;
    N8: TMenuItem;
    EditAlignGridItem: TMenuItem;
    EditFrontItem: TMenuItem;
    EditBackItem: TMenuItem;
    EditAlignItem: TMenuItem;
    EditSizeItem: TMenuItem;
    EditScaleItem: TMenuItem;
    EditTabOrderItem: TMenuItem;
    EditCreationOrderItem: TMenuItem;
    EditFlipChildrenItem: TMenuItem;
    EditFlipChildrenAllItem: TMenuItem;
    EditFlipChildrenSelectedItem: TMenuItem;
    EditLockControlsItem: TMenuItem;
    N9: TMenuItem;
    miToggleComment: TMenuItem;
    miIndent: TMenuItem;
    miUnindent: TMenuItem;
    miFormatSource: TMenuItem;
    miEditLineSep: TMenuItem;
    miLineMenu: TMenuItem;
    miDuplicateLine: TMenuItem;
    miMoveLinesUp: TMenuItem;
    miMoveLinesDown: TMenuItem;
    miJoinLines: TMenuItem;
    miCaretsMenu: TMenuItem;
    miSelectNextOccurrence: TMenuItem;
    miSelectAllOccurrences: TMenuItem;
    miAddCaretAbove: TMenuItem;
    miAddCaretBelow: TMenuItem;
    miExpandSelection: TMenuItem;
    miShrinkSelection: TMenuItem;
    miFoldMenu: TMenuItem;
    miFoldAll: TMenuItem;
    miUnfoldAll: TMenuItem;
    miFold: TMenuItem;
    miUnfold: TMenuItem;
    miFoldToggle: TMenuItem;
    miFoldMethods: TMenuItem;
    miFoldClasses: TMenuItem;
    miFoldSections: TMenuItem;
    miFoldUnit: TMenuItem;
    miFoldNested: TMenuItem;
    miFoldRegions: TMenuItem;
    miFoldSep: TMenuItem;
    miCodeFolding: TMenuItem;
    SearchMenu: TMenuItem;
    SearchFindItem: TMenuItem;
    SearchFileFindItem: TMenuItem;
    SearchReplaceItem: TMenuItem;
    SearchAgainItem: TMenuItem;
    SearchIncrementalItem: TMenuItem;
    N11: TMenuItem;
    SearchGoToItem: TMenuItem;
    N12: TMenuItem;
    SearchFindErrItem: TMenuItem;
    SearchSymbolItem: TMenuItem;
    N13: TMenuItem;
    miFindDecl: TMenuItem;
    miComplete: TMenuItem;
    miTemplates: TMenuItem;
    miParams: TMenuItem;
    ViewsMenu: TMenuItem;
    ViewPrjMgrItem: TMenuItem;
    miViewPackage: TMenuItem;
    miViewResources: TMenuItem;
    ViewObjInspItem: TMenuItem;
    ViewObjTreeViewItem: TMenuItem;
    ViewToDoListItem: TMenuItem;
    ViewBrowserItem: TMenuItem;
    CodeExplorer: TMenuItem;
    ViewCompListItem: TMenuItem;
    miViewComponents: TMenuItem;
    ViewWindowListItem: TMenuItem;
    ViewAddlMsgInfoItem: TMenuItem;
    miViewMessages: TMenuItem;
    miViewErrorList: TMenuItem;
    ViewDebugItem: TMenuItem;
    ViewBreakpointsItem: TMenuItem;
    ViewCallStackItem: TMenuItem;
    ViewWatchesItem: TMenuItem;
    ViewLocalVariablesItem: TMenuItem;
    ViewThreadsItem: TMenuItem;
    ViewModulesItem: TMenuItem;
    ViewEventLogItem: TMenuItem;
    N14: TMenuItem;
    ViewCPUItem: TMenuItem;
    ViewFPUItem: TMenuItem;
    ViewDesktopsMenu: TMenuItem;
    miDesktops: TMenuItem;
    miDesktopsSep: TMenuItem;
    SaveDesktop1: TMenuItem;
    DeleteDesktop: TMenuItem;
    SetDebugDesktop1: TMenuItem;
    N15: TMenuItem;
    ViewToggleFormItem: TMenuItem;
    miViewDiagram: TMenuItem;
    miViewHistory: TMenuItem;
    ViewUnitItem: TMenuItem;
    ViewFormItem: TMenuItem;
    ViewTypeLibraryItem: TMenuItem;
    N16: TMenuItem;
    ViewToolbarsItem: TMenuItem;
    miTbCustomize: TMenuItem;
    miZoomMenu: TMenuItem;
    miZoomIn: TMenuItem;
    miZoomOut: TMenuItem;
    miZoomReset: TMenuItem;
    miZoomFit: TMenuItem;
    ProjectMenu: TMenuItem;
    ProjectAddItem: TMenuItem;
    ProjectRemoveItem: TMenuItem;
    ProjectImportTypeLibraryItem: TMenuItem;
    ProjectAddRepositoryItem: TMenuItem;
    ViewPrjSourceItem: TMenuItem;
    miFormatProject: TMenuItem;
    N2: TMenuItem;
    ProjectAddNewProjectItem: TMenuItem;
    ProjectAddExistingProjectItem: TMenuItem;
    ProjectCompileSeparator: TMenuItem;
    ProjectCompileItem: TMenuItem;
    ProjectBuildItem: TMenuItem;
    ProjectSyntaxItem: TMenuItem;
    ProjectInformationItem: TMenuItem;
    N1: TMenuItem;
    ProjectCompileAllItem: TMenuItem;
    ProjectBuildAllItem: TMenuItem;
    N22: TMenuItem;
    miInstallPackage: TMenuItem;
    miUninstallPackage: TMenuItem;
    ProjectSeparator2: TMenuItem;
    ProjectOptionsItem: TMenuItem;
    RunMenu: TMenuItem;
    RunRunItem: TMenuItem;
    RunRunNoDebugItem: TMenuItem;
    RunAttachtoProcessItem: TMenuItem;
    RunParametersItem: TMenuItem;
    RunRegisterComItem: TMenuItem;
    RunUnregisterComItem: TMenuItem;
    RunParametersSeparator: TMenuItem;
    RunStepOverItem: TMenuItem;
    RunTraceIntoItem: TMenuItem;
    RunTraceToSourceItem: TMenuItem;
    RunGotoCursorItem: TMenuItem;
    RunUntilReturnItem: TMenuItem;
    RunShowCSIPItem: TMenuItem;
    RunPauseItem: TMenuItem;
    RunResetItem: TMenuItem;
    RunDetachItem: TMenuItem;
    RunInspectSeparator: TMenuItem;
    RunInspectItem: TMenuItem;
    RunEvalModItem: TMenuItem;
    RunAddWatchItem: TMenuItem;
    RunAddBreakItem: TMenuItem;
    RunAddSourceBreakpointItem: TMenuItem;
    RunAddAddressBreakpointItem: TMenuItem;
    RunAddDataBreakpointItem: TMenuItem;
    RunAddModuleLoadBreakpointItem: TMenuItem;
    miToggleBreak: TMenuItem;
    ComponentMenu: TMenuItem;
    ComponentNewItem: TMenuItem;
    ComponentAddtoPackage: TMenuItem;
    ComponentImportAXCItem: TMenuItem;
    ComponentInstallCompositeItem: TMenuItem;
    ComponentInstallPackagesItem: TMenuItem;
    ComponentPaletteItem: TMenuItem;
    ToolsMenu: TMenuItem;
    ToolsOptionsItem: TMenuItem;
    ToolsEditorOptionsItem: TMenuItem;
    ToolsDebuggerOptionsItem: TMenuItem;
    miFormatterOptions: TMenuItem;
    ToolsGalleryItem: TMenuItem;
    N27: TMenuItem;
    ToolsToolsItem: TMenuItem;
    WindowsMenu: TMenuItem;
    ViewNextWindowItem: TMenuItem;
    HelpMenu: TMenuItem;
    HelpContentsItem: TMenuItem;
    HelpDelphiToolsItem: TMenuItem;
    HelpWinSDKItem: TMenuItem;
    HelpProgGuideSeparater: TMenuItem;
    HelpAboutSeparator: TMenuItem;
    HelpAboutItem: TMenuItem;
    miCheckUpdates: TMenuItem;
    ClosedFilesPopup: TPopupMenu;
    ProcessMenu: TPopupMenu;
    DesktopsMenu: TPopupMenu;
    FlipChildrenPopup: TPopupMenu;
    FlipChildrenAllItem: TMenuItem;
    FlipChildrenSelectedItem: TMenuItem;
    miProcess: TMenuItem;
    ToolbarsPopup: TPopupMenu;
    miPopTbCustomize: TMenuItem;
    miPopTbSep: TMenuItem;
    miPopTbReset: TMenuItem;
    EditorLocalMenu: TPopupMenu;
    pmEdHistRoutine: TMenuItem;
    HistoryMenu: TPopupMenu;
    pmHistRestore: TMenuItem;
    pmHistRestoreChange: TMenuItem;
    pmHistGotoCode: TMenuItem;
    pmHistCopy: TMenuItem;
    pmHistLabel: TMenuItem;
    pmHistRemoveLabel: TMenuItem;
    pmHistSep1: TMenuItem;
    pmHistPrevChange: TMenuItem;
    pmHistNextChange: TMenuItem;
    pmHistSep2: TMenuItem;
    pmHistComparePrev: TMenuItem;
    pmHistSideBySide: TMenuItem;
    pmHistIgnoreBlanks: TMenuItem;
    HistoryTimer: TTimer;
    aAlignLeftEdges: TAction;
    aAlignHCenters: TAction;
    aAlignHWinCenter: TAction;
    aAlignHSpace: TAction;
    aAlignRightEdges: TAction;
    aAlignTops: TAction;
    aAlignVCenters: TAction;
    aAlignVWinCenter: TAction;
    aAlignVSpace: TAction;
    aAlignBottoms: TAction;
    DesignerBar: TToolBar;
    ThreadList: TListView;
    ModuleList: TListView;
    tbAlGrid: TToolButton;
    tbAlSep0: TToolButton;
    tbAl0: TToolButton;
    tbAl1: TToolButton;
    tbAl2: TToolButton;
    tbAl3: TToolButton;
    tbAl4: TToolButton;
    tbAlSep1: TToolButton;
    tbAl5: TToolButton;
    tbAl6: TToolButton;
    tbAl7: TToolButton;
    tbAl8: TToolButton;
    tbAl9: TToolButton;
    tbDsnSep0: TToolButton;
    tbDsnFront: TToolButton;
    tbDsnBack: TToolButton;
    tbDsnSep1: TToolButton;
    tbDsnAlign: TToolButton;
    tbDsnSize: TToolButton;
    tbDsnScale: TToolButton;
    tbDsnSep2: TToolButton;
    tbDsnTabOrder: TToolButton;
    tbDsnCreationOrder: TToolButton;
    tbDsnSep3: TToolButton;
    tbDsnFlip: TToolButton;
    tbDsnSep4: TToolButton;
    tbDsnLock: TToolButton;
    tbDsnSep5: TToolButton;
    aRecordMacro: TAction;
    aPlayMacro: TAction;
    aOpenFileAtCursor: TAction;
    aBrowseSymbolAtCursor: TAction;
    aTopicSearch: TAction;
    ecCompleteClass: TAction;
    EditAddToDoItemCommand: TAction;
    aGotoAddress: TAction;
    aViewAsForm: TAction;
    aReadOnly: TAction;
    aMessageView: TAction;
    aToggleBookmark0: TAction;
    aToggleBookmark1: TAction;
    aToggleBookmark2: TAction;
    aToggleBookmark3: TAction;
    aToggleBookmark4: TAction;
    aToggleBookmark5: TAction;
    aToggleBookmark6: TAction;
    aToggleBookmark7: TAction;
    aToggleBookmark8: TAction;
    aToggleBookmark9: TAction;
    aGotoBookmark0: TAction;
    aGotoBookmark1: TAction;
    aGotoBookmark2: TAction;
    aGotoBookmark3: TAction;
    aGotoBookmark4: TAction;
    aGotoBookmark5: TAction;
    aGotoBookmark6: TAction;
    aGotoBookmark7: TAction;
    aGotoBookmark8: TAction;
    aGotoBookmark9: TAction;
    aEdClosePage: TAction;
    aEdCut: TAction;
    aEdCopy: TAction;
    aEdPaste: TAction;
    aEdToggleBreak: TAction;
    aEdRunToCursor: TAction;
    aEdEvaluate: TAction;
    aEdInspect: TAction;
    aEdAddWatch: TAction;
    aEdViewCPU: TAction;
    aEdProperties: TAction;
    pmEdDbgToggleBreak: TMenuItem;
    pmEdDbgRunToCursor: TMenuItem;
    pmEdDbgGotoAddress: TMenuItem;
    pmEdDbgInspect: TMenuItem;
    pmEdDbgEvaluate: TMenuItem;
    pmEdDbgAddWatch: TMenuItem;
    pmEdDbgViewCPU: TMenuItem;
    pmEdDbgSep: TMenuItem;
    pmEdFindDecl: TMenuItem;
    pmEdSep1: TMenuItem;
    ecClosePage: TMenuItem;
    ecOpenFileAtCursor: TMenuItem;
    pmEdBrowse: TMenuItem;
    pmEdTopic: TMenuItem;
    pmEdComplete: TMenuItem;
    pmEdTodo: TMenuItem;
    pmEdFormatSource: TMenuItem;
    pmEdFold: TMenuItem;
    pmEdFoldAll: TMenuItem;
    pmEdUnfoldAll: TMenuItem;
    pmEdFoldBlock: TMenuItem;
    pmEdUnfoldBlock: TMenuItem;
    pmEdFoldToggle: TMenuItem;
    pmEdFoldMethods: TMenuItem;
    pmEdFoldClasses: TMenuItem;
    pmEdFoldSections: TMenuItem;
    pmEdFoldUnit: TMenuItem;
    pmEdFoldNested: TMenuItem;
    pmEdFoldRegions: TMenuItem;
    pmEdFoldSep: TMenuItem;
    pmEdCodeFolding: TMenuItem;
    pmEdSep2: TMenuItem;
    pmEdCut: TMenuItem;
    pmEdCopy: TMenuItem;
    pmEdPaste: TMenuItem;
    pmEdSep3: TMenuItem;
    pmEdToggleBM: TMenuItem;
    pmEdToggleBM0: TMenuItem;
    pmEdToggleBM1: TMenuItem;
    pmEdToggleBM2: TMenuItem;
    pmEdToggleBM3: TMenuItem;
    pmEdToggleBM4: TMenuItem;
    pmEdToggleBM5: TMenuItem;
    pmEdToggleBM6: TMenuItem;
    pmEdToggleBM7: TMenuItem;
    pmEdToggleBM8: TMenuItem;
    pmEdToggleBM9: TMenuItem;
    pmEdGotoBM: TMenuItem;
    pmEdGotoBM0: TMenuItem;
    pmEdGotoBM1: TMenuItem;
    pmEdGotoBM2: TMenuItem;
    pmEdGotoBM3: TMenuItem;
    pmEdGotoBM4: TMenuItem;
    pmEdGotoBM5: TMenuItem;
    pmEdGotoBM6: TMenuItem;
    pmEdGotoBM7: TMenuItem;
    pmEdGotoBM8: TMenuItem;
    pmEdGotoBM9: TMenuItem;
    pmEdSep4: TMenuItem;
    pmEdDebug: TMenuItem;
    pmEdDebugToggleBreak: TMenuItem;
    pmEdDebugRunToCursor: TMenuItem;
    pmEdDebugGotoAddress: TMenuItem;
    pmEdDebugInspect: TMenuItem;
    pmEdDebugEvaluate: TMenuItem;
    pmEdDebugAddWatch: TMenuItem;
    pmEdDebugViewCPU: TMenuItem;
    pmEdSep5: TMenuItem;
    pmEdViewAsForm: TMenuItem;
    pmEdReadOnly: TMenuItem;
    pmEdMessageView: TMenuItem;
    pmEdViewExplorer: TMenuItem;
    pmEdView: TMenuItem;
    pmEdViewViewAsForm: TMenuItem;
    pmEdViewReadOnly: TMenuItem;
    pmEdViewMessageView: TMenuItem;
    pmEdViewViewExplorer: TMenuItem;
    pmEdSep6: TMenuItem;
    pmEdProperties: TMenuItem;
    TabPopup: TPopupMenu;
    ecClosePageII: TMenuItem;
    pmTabCloseAll: TMenuItem;
    pmTabSep1: TMenuItem;
    pmTabPages: TMenuItem;
    BackMenu: TPopupMenu;
    ForwardMenu: TPopupMenu;
    FilesMenu: TPopupMenu;
    DesignPopup: TPopupMenu;
    pmDesignVerbSep: TMenuItem;
    pmDesignEdit: TMenuItem;
    pmDesignUndo: TMenuItem;
    pmDesignEditSep0: TMenuItem;
    pmDesignCut: TMenuItem;
    pmDesignCopy: TMenuItem;
    pmDesignPaste: TMenuItem;
    pmDesignDelete: TMenuItem;
    pmDesignEditSep1: TMenuItem;
    pmDesignSelectAll: TMenuItem;
    pmDesignControl: TMenuItem;
    pmDesignBringFront: TMenuItem;
    pmDesignSendBack: TMenuItem;
    pmDesignSelSep: TMenuItem;
    pmDesignPosition: TMenuItem;
    pmDesignAlignGrid: TMenuItem;
    pmDesignAlign: TMenuItem;
    pmDesignSize: TMenuItem;
    pmDesignScale: TMenuItem;
    pmDesignFlip: TMenuItem;
    pmDesignFlipAll: TMenuItem;
    pmDesignFlipSelected: TMenuItem;
    pmDesignTabOrder: TMenuItem;
    pmDesignCreationOrder: TMenuItem;
    pmDesignRevert: TMenuItem;
    pmDesignRepository: TMenuItem;
    pmDesignViewAsText: TMenuItem;
    pmDesignTextDFM: TMenuItem;
    MsgPopup: TPopupMenu;
    pmMsg1: TMenuItem;
    pmMsg2: TMenuItem;
    pmMsg3: TMenuItem;
    pmMsg4: TMenuItem;
    pmMsg5: TMenuItem;
    pmMsg6: TMenuItem;
    pmMsg7: TMenuItem;
    pmMsg8: TMenuItem;
    pmMsg9: TMenuItem;
    pmMsg10: TMenuItem;
    pmMsg11: TMenuItem;
    StackPopup: TPopupMenu;
    pmStack1: TMenuItem;
    pmStack2: TMenuItem;
    LocalsPopup: TPopupMenu;
    pmLocals1: TMenuItem;
    MsgHintsPopup: TPopupMenu;
    pmMh1: TMenuItem;
    pmMh2: TMenuItem;
    pmMh3: TMenuItem;
    pmMh4: TMenuItem;
    { the dock's commands alone: the menu of the captions and tabs of the views without a menu of
      their own (the experts' views, the debugger's Threads ... FPU) }
    DockPopup: TPopupMenu;
    pmMsgInfo: TMenuItem;
    LogPopup: TPopupMenu;
    pmLog1: TMenuItem;
    pmLog2: TMenuItem;
    pmLog3: TMenuItem;
    pmLog4: TMenuItem;
    pmLog5: TMenuItem;
    StructTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure TabsChange(Sender: TObject);
    procedure TabsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TabsClose(Sender: TObject; Index: Integer);
    procedure TabsMove(Sender: TObject; FromIndex, ToIndex: Integer);
    procedure ProjViewOpen(Sender: TObject; Node: TTreeNode);
    procedure PkgTreeChange(Sender: TObject; Node: TTreeNode);
    procedure PkgTreeDblClick(Sender: TObject);
    procedure PkgTreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PkgTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ResTreeChange(Sender: TObject; Node: TTreeNode);
    procedure ResTreeDblClick(Sender: TObject);
    procedure ResTreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MessagesDblClick(Sender: TObject);
    procedure MessagesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ErrorListDblClick(Sender: TObject);
    procedure StatusBarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ViewDblClick(Sender: TObject);
    procedure PaneMenuPopup(Sender: TObject);
    procedure ActPane(Sender: TObject);
    procedure ActViewMenu(Sender: TObject);
    procedure ActTwin(Sender: TObject);
    procedure ActEditorMenu(Sender: TObject);
    procedure ActBookmark(Sender: TObject);
    procedure ActAlign(Sender: TObject);
    procedure ActFormText(Sender: TObject);
    procedure StructTimerTick(Sender: TObject);
    { the actions }
    procedure ActNewApp(Sender: TObject);
    procedure ActNewConsole(Sender: TObject);
    procedure ActNewPackage(Sender: TObject);
    procedure ActNewUnit(Sender: TObject);
    procedure ActNewForm(Sender: TObject);
    procedure ActOpen(Sender: TObject);
    procedure ActOpenProject(Sender: TObject);
    procedure ActSave(Sender: TObject);
    procedure ActSaveAs(Sender: TObject);
    procedure ActSaveAll(Sender: TObject);
    procedure ActClose(Sender: TObject);
    procedure ActCloseAll(Sender: TObject);
    procedure ActExit(Sender: TObject);
    procedure ActEdit(Sender: TObject);
    procedure ActEditor(Sender: TObject);
    procedure ActCodeFolding(Sender: TObject);
    procedure ActZoom(Sender: TObject);
    procedure ActDesign(Sender: TObject);
    procedure ActSearch(Sender: TObject);
    procedure ActView(Sender: TObject);
    procedure ActHistory(Sender: TObject);
    procedure HistoryMenuPopup(Sender: TObject);
    procedure HistoryTimerTick(Sender: TObject);
    procedure ActProject(Sender: TObject);
    procedure ActPackage(Sender: TObject);
    procedure ActResources(Sender: TObject);
    procedure ActRun(Sender: TObject);
    procedure ActDebugInsp(Sender: TObject);
    procedure ActRevert(Sender: TObject);
    procedure ActInspView(Sender: TObject);
    procedure ActRepository(Sender: TObject);
    procedure ActGroup(Sender: TObject);
    procedure ActMsgHints(Sender: TObject);
    procedure ActBrowser(Sender: TObject);
    procedure ActImport(Sender: TObject);
    procedure ActTypeLib(Sender: TObject);
    procedure ActTools(Sender: TObject);
    procedure ActFormat(Sender: TObject);
    procedure ActEncoding(Sender: TObject);
    procedure ActFile(Sender: TObject);
    procedure ActToolbar(Sender: TObject);
    procedure ActHelp(Sender: TObject);
    procedure ProcessMenuPopup(Sender: TObject);
    procedure DesktopsMenuPopup(Sender: TObject);
    procedure ToolbarsPopupPopup(Sender: TObject);
    procedure TabPopupPopup(Sender: TObject);
    procedure ActBrowse(Sender: TObject);
    procedure BrowseMenuPopup(Sender: TObject);
    procedure ActFileList(Sender: TObject);
    procedure FilesMenuPopup(Sender: TObject);
    procedure EditorLocalMenuPopup(Sender: TObject);
    procedure FormShortCut(var Msg: TWMKey; var Handled: Boolean);
    procedure AppIdle(Sender: TObject; var Done: Boolean);
    procedure AppActivate(Sender: TObject);
    procedure AppHint(Sender: TObject);
    procedure AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
    procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure AppException(Sender: TObject; E: Exception);
    procedure DesignPopupPopup(Sender: TObject);
  private
    FServices: TMainServices;
    FOtaHost: TSdOtaHost;            // what the Open Tools API asks of the IDE (TOtaMainHost)
    FMsgView: TSdMessageView;        // Messages: Build (MessageList) and the experts' message groups
    FErrorListPage: TEditorPage;     // the page whose errors ErrorList lists (compared, never used: it may be gone)
    FErrorListStamp: Integer;        // ... their ErrorsStamp
    FErrorListHad: Boolean;          // ... the page shown had errors: the Error List came to the front then
    FToolsLine: TMenuItem;           // the line UpdateToolsMenu put above the transfer tools
    FVerbDesigner: TFormDesigner;    // the designer a right click opens DesignPopup for (DesignPopupPopup)
    { what is not in the .dfm: the controls of D7 Studio's own }
    FCompBar: TSdComponentBar;       // the Components view (it replaced the component palette)
    FIdePalette: TSdIdePalette;      // Delphi's palette for experts: hidden (SdOtaPalette)
    FExpertViews: TSdExpertViews;    // the experts' dockable windows as views (SdOtaViews)
    FExpertsLoaded: Boolean;         // the experts of the start have loaded (ExpertsLoaded)
    FCompPanel: TSdDockPanel;
    FCodeExp: TCodeExplorerView;
    FObjTree: TObjTreeView;
    FObjTreeDirty: Boolean;          // its designer's form changed since it was made: made again at StructTimer
    FNavBar: TNavigationBar;         // the code's Class / Methods boxes: on the shown page's bar (SdNavBar)
    FEncodingWidth: Integer;         // the status bar's encoding panel as the form file has it (0: not taken yet)
    FProjView: TProjectManagerView;
    FInspector: TObjectInspector;
    FDesignWindows: TDesignWindows;  // the floating design-time windows of the packages
    FPages: TList;                   // the files' pages (TEditorPage), in the order of their tabs
    FDocs: TList;                    // every page of the file area in its tabs' order: the files' and the resources' (TSdResPage)
    FDesignWinHost: ISdDesignHost;
    FProject: TSdProject;            // the active project: one of FGroup's (the group owns it)
    FGroup: TSdProjectGroup;         // the project group: its projects loaded, FProject the active one; the packages beside it
    FNewProjectMode: TOpenMode;      // Add New Project: the project New Items makes joins the group
    FDebugProject: TSdProject;       // the project whose program the debug session runs (nil: none, an attach)
    FCIProject: TSdProject;          // the project code insight is configured for (the page shown's)
    FCompiler: TSdCompiler;
    FScratch: TSdScratchBuild;        // the unsaved files of a compile
    FRunHidden, FRunMinimized: Boolean;   // Minimize on run: the session ran / it minimized the IDE
    FLockedPages: TList;             // the pages Mark buffers read-only on run locked
    FSearchView: TSearchResultsView; // Search Results (SdSearchResults)
    FBreakView: TBreakpointsView;    // Breakpoints (SdBreakpointsView)
    FTodoView: TTodoListView;        // the To-Do List (SdTodoView) ...
    FTodoHost: TTodoHost;            // ... and what it asks of the IDE (TTodoMainHost)
    FTodoLock: Integer;              // > 0: the view is in a call to an expert, a dialog has an item: no refresh now
    FTodoPending: Boolean;           // ... a refresh was asked for meanwhile
    FTodoPendingFull: Boolean;       // ... with the files read again
    FTodoPosted: Boolean;            // WM_SDTODOREFRESH is on its way
    FTodoShown: Boolean;             // the To-Do List view was shown: the experts' items are collected from then on
    FTodoEdits, FTodoEditsSeen: Integer;   // the pages' text changes; ... when the list was made
    FTodoTexts: TStringList;         // the closed files' texts the list read last, with their stamps (TTodoText)
    FTodoProject: string;            // the active project at the last change (IOTAToDoManager.ProjectChanged's, not called)
    FTodoProjectPosted: Boolean;     // WM_SDTODOPROJECT is on its way
    FRunLocked: Boolean;             // ... while the session lasts: a page opened then is locked too
    FDebugDesktop: Boolean;          // the debug desktop is shown (View | Desktops)
    FCodeInsight: TCodeInsight;
    FDebug: TDebugController;
    FFind: TFindOptionsRec;
    FFindFiles: TFindInFilesRec;
    FExpPage: TEditorPage;      // the page whose unit the Code Explorer shows (nil: none)
    FExpVersion: Integer;       // ... the TextVersion of the text it shows (-1: none)
    FExpFilled: Boolean;        // it shows a Pascal unit: the next one keeps its nodes' state
    FClosing: Boolean;
    FRestart: Boolean;          // closing to start again (a new UI font): D7Studio.dpr starts the EXE
    FUpdateCheck: TSdUpdateCheck; // the check for updates that runs, nil when none
    FUpdateFound: Boolean;      // it found a newer release: its dialog shows once the window is idle and enabled
    FUpdateRelease: TSdRelease; // ... that release
    FUpdateShowing: Boolean;    // its dialog is open: a second WM_SDSHOWUPDATE is dropped
    FUpdateSetup: string;       // closing to run this release's setup: D7Studio.dpr starts it
    FClosingAll: Boolean;       // every page closes (project closed): none is activated on the way
    FCheckingFiles: Boolean;    // AppActivate asks about files changed on the disk (its boxes activate again)
    FErrorPage: TEditorPage;
    FExecPage: TEditorPage;     // the page with the execution point's markers (nil: none)
    FErrorText: string;
    FInPageChanged: Boolean;
    FInheritRenames: TStringList;    // renames the forms built from a form or frame follow: 'class|old|new' (WMInheritRename)
    FDock: TSdDock;                  // the docked tool views (SdDock)
    FCustomize: TCustomizeDlg;       // View | Toolbars | Customize while it is open
    FCpuView: TSdCpuView;            // View | Debug Windows | CPU (SdCpuView)
    FCpuStepping: Boolean;           // the last run command came from the CPU view's disassembly
    FMachinePanels: array[0..4] of TSdDockPanel;   // Thread Status, Modules, CPU, FPU, Debug Inspector
    FDebugInsp: TSdInspectorView;    // Run | Inspect (SdDebugInspector)
    FWatchView: TSdWatchView;        // the Watch List: WatchTree, its columns and groups (SdWatchViewFrame)
    FTodo: TSdTodoList;              // the To-Do List's items, sort and filters (SdTodo)
    FLastTodo: TTodoValues;          // the values of Add To-Do Item's last OK (the List's Add offers them)
    FTestHint: string;               // test command todohint
    FTestTip: THintWindow;           // test command tooltip: a tool button's hint, shown as the VCL shows it
    FTestTipText: string;            // ... its text
    FMsgHints: TSdMessageHints;      // View | Additional Message Info (SdMsgInfo)
    FBrowser: TSdBrowser;            // View | Browser (SdBrowserFrame)
    FBrowserPanel: TSdDockPanel;
    FBrowserFresh: Boolean;          // just built (Browse Symbol): showing it builds nothing
    FBrowserStale: Boolean;          // a unit of the active project was saved since the Browser was built
    FBrowserPosted: Boolean;         // WM_SDBROWSERREBUILD is on its way
    FTypeLibView: TSdTypeLibView;    // View | Type Library (SdTypeLibViewFrame)
    FTypeLibPanel: TSdDockPanel;
    FPkgViews: TList;                // the package editors made (TSdPackageView): one for each open package, the free ones hidden
    FPkgStatus: Boolean;             // ... their status lines ([Layout] PackageStatusBar)
    FResView: TSdResourceView;       // View | Resources: the active project's .res (SdResourceViewFrame)
    FResPanel: TSdDockPanel;
    FResNote: string;                // what its status line says without a chosen resource
    FResWritten: Boolean;            // an expert wrote the view's .res: filled again at the next idle
    { an expert changed the editor options / the active project's options: written and applied at
      the next idle (FlushOtaOptions) }
    FOtaEditorOptions, FOtaProjectOptions, FOtaEnvOptions: Boolean;
    FResPropsKey: string;            // the resource of the open Properties dialog (ResPropsCheck)
    FMsgHintsPanel: TSdDockPanel;
    FSourceCache: TStringList;       // the lines of the file the CPU view read last
    FSourceCacheName: string;
    FSourceCacheStamp: TSdFileStamp; // ... and that file's stamp then (a changed file is read again)
    FDefaultButtons: string;         // the tool bar's buttons as the .dfm has them (Reset)
    FBarTooltips, FBarShortcuts: Boolean;    // Customize | Options
    FPageTabs: TSdFileTabs;          // the file tabs (SdTabStrip): tab I is FDocs[I]
    FTabRow: TSdDockHost;            // the row above the pages: HistoryBar, the file tabs, FilesBar
    FEditWindow: TSciWindow;         // the window of the files' text, over the page shown (SciFileWindow)
    FHistory: TSdNavHistory;         // Back / Forward (SdNavHistory)
    FNavPage: TEditorPage;           // the page shown last: a jump starts at its caret
    FNavFrom: TSdNavPlace;           // where the jump under way started ...
    FNavPending: Boolean;            // ... recorded when it is over (WM_SDNAVRECORD)
    FNavLock: Integer;               // > 0: what is shown now is no jump (Back itself, a desktop, the debugger)
    FLeftArea, FRightArea, FBottomArea: TSdDockArea;
    FBottomFullArea: TSdDockArea;    // along the window's bottom edge, under the left and right areas
    FProjPanel, FCodeExpPanel, FObjTreePanel, FInspPanel: TSdDockPanel;
    FBottomPanels: array[0..8] of TSdDockPanel;   // Messages .. Error List, indexed BT_MESSAGES .. BT_ERRORS
    FMenuPanel: TSdDockPanel;        // the panel whose caption or tab menu is open
    FMenuGroup: Boolean;             // ... opened on the caption: its whole group
    FTwins: array of TTwinActions;   // the menus' actions with Delphi's names there, and their commands
    FFlickerDone: Boolean;           // UIReduceFlicker ran again on the first idle (for what was made since FormCreate)
    FReopenBatch: Boolean;           // files open in a batch (LoadDesktop): the Reopen menus are made once, after it
    FReopenStale: Boolean;           // ... and a file was added to the recent files meanwhile
    FStartMaximized: Boolean;        // [Layout] Maximized, read by LoadState, given to the window by ApplyStartState
    FFilledMenus: TList;             // the submenus filled by their OnClick when their menu opened (FillSubmenus)
    FFindLo, FFindHi: Integer;       // Find / Replace with Selected text: the range taken from the selection
    FFindRangeEd: TSciEdit;          // ... in this editor (nil: no range)
    FFindSkip: Integer;              // where the last empty match (^, x*) was: the next search passes it
    FFindSkipEd: TSciEdit;           // ... in this editor (nil: none)
    FBookmarkActions: array[0..9, Boolean] of TAction;   // aToggleBookmarkN (False), aGotoBookmarkN (True)
    FTestItem: TMenuItem;            // test mode: the menu item a "menu" command clicks
    FTestResult: Integer;            // test mode: 1 done, 3 no such menu item (panel, area), 4 item disabled
    procedure CreatePanes;
    procedure AddDockItems(const Menus: array of TPopupMenu);
    procedure WireViewMenu(Menu: TPopupMenu; Actions: TActionList; Handler: TNotifyEvent);
    procedure DisableUnbuilt;
    procedure LoadBands;
    procedure FreezeToolRow(Freeze: Boolean);
    function NewToolButton(Bar: TToolBar; const Item: string; X: Integer): TToolButton;
    procedure FillToolbar(Bar: TToolBar; const Buttons: string);
    function ToolbarButtons(Bar: TToolBar): TList;
    function ToolbarButtonsText(Bar: TToolBar): string;
    procedure StoreToolbarButtons(Bar: TToolBar);
    function BarAt(const ScreenPt: TPoint; out Index: Integer): TToolBar;
    procedure ApplyBarHints;
    procedure ShowCustomize;
    procedure CustomizeDrop(Sender: TObject; Action: TBasicAction; Source: TToolButton;
      const ScreenPt: TPoint; Drop: Boolean; var Accept: Boolean);
    procedure ResetToolbar;
    procedure CustomizeOptions(Sender: TObject);
    procedure CustomizeClosed(Sender: TObject);
    function AskNewProject(const Kind, Ext: string; var FileName, ProjName: string): Boolean;
    function AskSaveName(const Title, Filter, DefaultExt: string; var FileName: string): Boolean;
    function AskProjectFile(Groups: Boolean; out FileName: string): Boolean;
    procedure NewApplication(const FileName: string);
    procedure NewProjectOfKind(Kind: TNewProjectKind);
    function RunTarget(var Exe: string): Boolean;
    function InstalledPackage(P: TSdProject): TPackageEntry;
    function InstallPackageProject(P: TSdProject): Boolean;
    procedure UninstallPackageOf(P: TSdProject);
    procedure InstallComponent(const UnitFile: string = '');
    function AddUnitToPackage(P: TSdProject; const UnitFile, SearchPath: string): Boolean;
    procedure SetPackageSearchPath(P: TSdProject; const SearchPath, Dir: string);
    procedure RemoveProjectUnit(U: TProjectUnit);
    procedure RemoveProjectUnitOf(P: TSdProject; U: TProjectUnit);
    procedure OpenProjectUnit(U: TProjectUnit);
    { the package editors: one view of the dock for each open package (Delphi 7's window of a
      package), made when a package first needs one, kept hidden for the next when it goes }
    procedure PlaceView(View: TFrame; Popup: TPopupMenu);
    function NewPackageView(const AName: string): TSdPackageView;
    procedure ReservePackageViews(Names: TStrings);
    function PackageViewOf(P: TSdProject; Make: Boolean; const AName: string = ''): TSdPackageView;
    function SenderPackageView(Sender: TObject): TSdPackageView;
    procedure ShowPackageEditor(P: TSdProject; Focus: Boolean = False);
    procedure ReleasePackageView(P: TSdProject);
    procedure RefreshPackageView(V: TSdPackageView);
    procedure RefreshPackageViews;
    procedure DockPanelHide(Sender: TObject; Panel: TSdDockPanel);
    procedure WMCloseBeside(var Message: TMessage); message WM_SDCLOSEBESIDE;
    procedure WMSwapForm(var Message: TMessage); message WM_SDSWAPFORM;
    procedure RebuildBrowser;
    procedure BrowserFileSaved(const FileName: string);
    procedure WMBrowserRebuild(var Message: TMessage); message WM_SDBROWSERREBUILD;
    procedure UpdateCheckEnded(Sender: TObject);
    procedure UpdateCheckFailed(const Error: string);   // Help | Check for Updates could not check
    procedure WMShowUpdate(var Message: TMessage); message WM_SDSHOWUPDATE;
    procedure RefreshResourceView(const Key: string = '');
    procedure UpdateResourceActions;
    procedure ResourceDone(const Key: string);
    procedure AddResource(Kind: TSdResKind);
    procedure ImportResource;
    procedure EditResource(Hex: Boolean);
    { the pages of the resources in the file area (SdResPage) }
    function ResourcesOf(const ProjectFile: string; out Own: Boolean): TSdResources;
    function FindResPage(const ProjectFile, Key: string): TSdResPage;
    function OpenResPage(R: TSdResources; It: TSdResItem; Hex: Boolean): TSdResPage;
    function OpenNewStringTable(R: TSdResources; Language: Integer): TSdResPage;
    function MakeResPage(R: TSdResources; It: TSdResItem; Hex: Boolean; Language: Integer): TSdResPage;
    function SaveResPage(P: TSdResPage): Boolean;
    function ActiveResPage: TSdResPage;
    function UnsavedResources(const ProjectFile: string; Warnings: TStrings): string;
    procedure DeleteResource;
    procedure RenameResource;
    procedure ExportResource;
    function ResPropsCheck(const AType, AName: string; Language: Integer; var Bad: Integer): string;
    procedure AddToPackage(P: TSdProject);
    procedure RemoveFromPackage(V: TSdPackageView);
    procedure GetComponentClasses(Classes, Pages: TStrings);
    procedure WriteNewComponent(const Info: TNewCompInfo);
    procedure LoadImportInfo(ActiveX: Boolean; var Info: TImportTLBInfo; Pages, Added: TStrings);
    procedure SaveImportInfo(ActiveX: Boolean; const Info: TImportTLBInfo; Added: TStrings; Chosen: Boolean);
    function ImportTypeLibUnit(ActiveX: Boolean; const Info: TImportTLBInfo): string;
    procedure ImportTypeLibrary(ActiveX: Boolean);
    function WriteTypeLibUnits(TL: ITypeLib; const Options: TTLBOptions; const UnitDir: string): string;
    function OpenTypeLibrary(const FileName: string): Boolean;
    function NewAction(List: TActionList; const ACaption, AHint: string; ATag: Integer;
      AOnExecute: TNotifyEvent): TAction;
    function NewActionItem(Menu: TMenuItem; A: TAction; Index: Integer = -1): TMenuItem;
    procedure ClearActions(List: TActionList);
    { File | Close All (an expert's too): the project with its group, else every page }
    function CloseAllFiles: Boolean;
    { P under FileName, saved (Write) or not: its tab follows, and the project's uses clause when P
      is a unit of it }
    function RenamePage(P: TEditorPage; const FileName: string; Write: Boolean): Boolean;
    { P under another name, nothing written (Delphi 7's IOTAModule.FileName of a project) }
    function RenameProjectOnly(P: TSdProject; const AName: string): Boolean;
    { a project of the group or beside it has a new name: the To-Do List's caption, the window's, the
      Project Manager and code insight follow }
    procedure ProjectNameShown(P: TSdProject);
    { P's source as it is to be under NewName: the program's name, its units' and resource
      scripts' paths from the new folder, in the source's encoding E; False when that encoding
      cannot name one of them }
    function ProjectSourceFor(P: TSdProject; const NewName: string; out Src: string; out E: TSdEncoding): Boolean;
    { File | Save As: P under a name the user gives (RenamePage) }
    function SaveDocAs(P: TEditorPage): Boolean;
    { before the debugger runs or attaches: the breakpoints of the open pages into the engine, the
      folders of the sources into Dirs, the event log shown }
    procedure PrepareDebug(Dirs: TStrings);
    procedure AttachTo(Pid: Cardinal);
    function StartArrangement: string;
    procedure ClearSearchResults;
    procedure InitialFindText(var FindText: string);
    procedure LockForRun(P: TEditorPage);
    function RevertableRow(R: Integer): Boolean;
    procedure AddFormUnit(Src: string; const UnitName, RootName, Code, Dfm, Comment: string;
      CanCreate: Boolean);
    procedure FlushOtaOptions;
    function StepMessage(Delta: Integer): Boolean;
    procedure ReloadPage(P: TEditorPage);
    { the text of Page is its file's (saved, read again): a project source's units follow }
    procedure ProjectTextChanged(Page: TEditorPage);
    { a unit (a .pas) into the active project: the .dpr's uses clause (a form's comment), or the
      package's contains clause; False: no project, or the package refused it }
    function ProjectAddUnit(const FileName: string): Boolean;
    { the same into P, a project of the group, with the form's name given (the unit's .dfm may not
      be on the disk yet) }
    function ProjectAddUnitTo(P: TSdProject; const FileName, FormName: string): Boolean;
    { a resource script (a .rc) into P: its $R with the .res of the same name beside it (Delphi
      7's Add to Project of a .rc); one that is there already is True and changes nothing }
    function ProjectAddResScriptTo(P: TSdProject; const FileName: string): Boolean;
    procedure UpdateActionStates;
    procedure UpdateStatus;
    procedure UpdateErrorInsight;
    procedure UpdateCaption;
    procedure UpdateReopenMenu;
    procedure ReopenExecute(Sender: TObject);
    { the main menu: the lists that come from data are made again when their menu opens }
    procedure WMInitMenuPopup(var Message: TWMInitMenuPopup); message WM_INITMENUPOPUP;
    procedure WMExitMenuLoop(var Message: TMessage); message WM_EXITMENULOOP;
    procedure FillSubmenus(Item: TMenuItem);
    procedure WMEndSession(var Message: TWMEndSession); message WM_ENDSESSION;
    procedure WMShowWindow(var Message: TWMShowWindow); message WM_SHOWWINDOW;
    procedure UpdatePageItems(Menu: TMenuItem; Sorted: Boolean);
    procedure ActiveControlChange(Sender: TObject);
    procedure AddTwins(const Pairs: array of TAction);
    procedure ApplyCompBarOptions;
    function SourceLineText(const FileName: string; Line: Integer): string;
    procedure CpuGotoAddress(Sender: TObject);
    function ParseAddress(const Text: string; out Addr: Cardinal): Boolean;
    function CpuBreakpointAt(Addr: Cardinal): Integer;
    function CursorExpression(P: TEditorPage): string;
    procedure InspectExpression(const Expr: string);
    procedure DebugInspDescend(Sender: TObject);
    procedure BrowserFiles(Sender: TObject; Files: TStrings);
    procedure BrowserGoto(Sender: TObject; const FileName: string; Line, Col: Integer);
    function AlignActionKind(A: TObject; out Kind: TAlignKind; out Need: Integer): Boolean;
    procedure OpenFileAtCursor;
    procedure AddTodoItem;
    function TodoDialog(Mode: TTodoDlgMode; var V: TTodoValues): Boolean;
    procedure AddProjectTodo;
    function TodoCanEdit(Item: TSdTodoItem): Boolean;
    procedure ChangeTodoComment(Item: TSdTodoItem; const NewComment: string);
    function TodoSource(const FileName: string; out E: TSdEncoding; out Ansi: Boolean): string;
    procedure SetTodoSource(const FileName, Text: string; const E: TSdEncoding; Ansi, Save: Boolean);
    procedure EditTodo(Item: TSdTodoItem);
    procedure WindowExecute(Sender: TObject);
    procedure WatchGroupMenu;
    procedure WatchMoveExecute(Sender: TObject);
    procedure InspViewMenu;
    procedure InspCategoryExecute(Sender: TObject);
    procedure UpdateToolsMenu;
    procedure ToolExecute(Sender: TObject);
    procedure UseUnit;
    procedure SaveProjectAs;
    function SaveProjectAsName(P: TSdProject; const AName: string): Boolean;
    procedure RegisterServer(Unregister: Boolean);
    procedure FlipDesignChildren(D: TFormDesigner; All: Boolean);
    procedure AlignSelection(D: TFormDesigner);
    procedure SizeSelection(D: TFormDesigner);
    procedure ScaleRoot(D: TFormDesigner);
    procedure EditTabOrder(D: TFormDesigner);
    procedure EditCreationOrder(D: TFormDesigner);
    procedure NewComponent;
    procedure PlaceComponent(Cls: TComponentClass);
    procedure ShowComponentList;
    procedure NewItems;
    procedure RefreshTodoList;
    { the experts' To-Do items (IOTAToDoServices, SdOtaToDo): collected again and shown (UpdateList),
      those of a package taken out at once (0: all); a refresh asked for while the view calls an
      expert or a dialog has an item comes after it (TodoUnlock, WM_SDTODOREFRESH) }
    procedure TodoExpertsChanged;
    procedure TodoDropModule(Module: HMODULE);
    procedure TodoUnlock;
    procedure TodoRefreshLater;
    { the closed files' texts the To-Do List read (RefreshTodoList): one goes, all go }
    procedure TodoForget(const FileName: string);
    procedure ClearTodoTexts;
    procedure WMTodoRefresh(var Message: TMessage); message WM_SDTODOREFRESH;
    procedure TodoProjectLater;
    procedure WMTodoProject(var Message: TMessage); message WM_SDTODOPROJECT;
    procedure TodoTypingPause;
    { an action of the list on an expert's item, the list collected again after it }
    procedure TodoExpertCommand(Item: TSdTodoItem; Action: TSdTodoAction);
    { Named: Name is the file the page is saved to (TEditorPage.NewFile) }
    procedure NewUntitledPage(const Name, Text: string; const Dfm: string = ''; Named: Boolean = False);
    procedure NewProjectUnit(const Name, Source: string);
    procedure AddFormTemplate(const Path: string; Use: Boolean);
    procedure CopyProjectTemplate(const Path: string);
    procedure FindErrorAddress;
    procedure BrowseSymbol;
    procedure ShowProjectInfo;
    procedure SaveNamedDesktop(const Name: string);
    procedure LoadNamedDesktop(const Name: string);
    function ShowNamedDesktop(const Name: string): Boolean;
    procedure DesktopNames(L: TStringList);
    procedure DeleteNamedDesktop(const Name: string);
    procedure SetDebugDesktop(const Name: string);
    procedure ShowDesktops;
    procedure DesktopExecute(Sender: TObject);
    function ExpandTransferMacros(const S: string): string;
    procedure OpenHelpFile(const FileName: string; const Keyword: string = '');
    procedure CloseHelp;
    { pages: the file area's - the files' (TEditorPage: FPages, Pages[]) and the resources'
      (TSdResPage); FDocs holds both in the order of their tabs, a "page" below is either }
    function GetPage(Index: Integer): TEditorPage;
    function PageCount: Integer;
    function ActivePage: TEditorPage;            // the file shown; nil: none, or a resource is
    function ActiveDoc: TWinControl;             // the page shown, of either kind
    procedure AddPageTab(Page: TWinControl);
    procedure AddDoc(Doc: TWinControl);
    { Doc's tab to place ToIndex (a dragged tab's place, the desktop's order); FDocs and FPages follow }
    procedure MoveDoc(Doc: TWinControl; ToIndex: Integer);
    procedure UpdatePageTab(Page: TWinControl);
    procedure ForgetDesigner(Page: TEditorPage);
    procedure FreePage(Page: TWinControl);
    function DocModified(Doc: TWinControl): Boolean;
    function DocTitle(Doc: TWinControl): string;       // its file's name, a resource's title
    function ActiveEditor: TSciEdit;
    function FoldAction(FA: TSciFoldAction): TAction;
    { Editor Options | Zoom on every editor - the files' pages and the text resources' -, in the
      status bar }
    procedure ApplyZoom;
    { the zoom of a page of the file area: its view shown's (SdZoom), nil when it does not zoom }
    function DocZoomView(Doc: TWinControl): ISdZoomView;
    { the zoom bar's Fit button only while the view ZV can fit (never the code, text and hex
      editors); True when it came or went. Not while the zoom bar has no parent (no page shows it) }
    function ShowZoomFit(const ZV: ISdZoomView): Boolean;
    { the page bar of Doc, the page shown: the zoom bar first, what its view puts there after it - lent
      while nothing of the centre reaches the screen (SwapPage) or Doc's view changed }
    procedure ArrangePageBar(Doc: TWinControl);
    { a view's zoom changed (SdZoom.OnZoomChanged): the status bar shows it }
    procedure ZoomViewChanged(Sender: TObject);
    procedure EditorZoomChanged(Sender: TObject);
    procedure HistoryFileChanged(const FileName: string);
    procedure ApplyHistoryOptions;
    procedure HostPaletteChanged(Sender: TObject);
    procedure HostPackageUnloading(Sender: TObject);
    procedure HostPackageUnloaded(Sender: TObject);
    procedure HostDesignWindow(Form: TCustomForm; Appearing: Boolean);
    procedure HostSyncDesignWindows(Sender: TObject);
    function DesignWindowOrigin: TPoint;
    function DesignWindowShown(Root: TComponent): Boolean;
    function ActiveDesigner: TFormDesigner;
    function FindPage(const FileName: string): TEditorPage;
    function FileOfGroup(const FileName: string): Boolean;
    function OpenFile(const FileName: string; Activate: Boolean): TEditorPage;
    procedure AdoptPage(Page: TEditorPage; const FileName: string; Activate: Boolean);
    function OpenFileView(const FileName: string; Design, Activate: Boolean): TEditorPage;
    procedure SwapPage(Page, Old: TWinControl);
    function FollowingPage(Page, Skip: TWinControl): TWinControl;
    function FollowingPageOf(Page: TWinControl; Going: TList; Skip: TWinControl): TWinControl;
    procedure ActivatePage(Page: TWinControl);
    function ShowFileLine(const FileName: string; Line, Col: Integer): TEditorPage;
    procedure ShowPageLine(P: TEditorPage; Line, Col: Integer);
    procedure SearchOpen(Sender: TObject; const FileName: string; Line: Integer);
    { the browse history (Back, Forward) }
    function PagePlace(Page: TEditorPage): TSdNavPlace;
    procedure NavMark;
    procedure WMNavRecord(var Message: TMessage); message WM_SDNAVRECORD;
    function ShowPlace(Index: Integer): Boolean;
    procedure HistoryExecute(Sender: TObject);
    function ConfirmSave(Page: TWinControl): Boolean;
    function ClosePage(Page: TEditorPage; Prompt: Boolean): Boolean;
    function CloseDoc(Doc: TWinControl; Prompt: Boolean): Boolean;
    function CloseAllDocs(Prompt: Boolean): Boolean;
    procedure LeavePage(Page: TWinControl; Swap: Boolean);
    function SavePage(Page: TEditorPage): Boolean;
    function SaveDoc(Doc: TWinControl): Boolean;
    function SavePageAs(Page: TEditorPage; const FileName: string): Boolean;
    procedure RenamePageOnly(Page: TEditorPage; const FileName: string);
    procedure PageMoved(Page: TEditorPage; const Old: string);
    function SaveAllPages: Boolean;
    function SaveAllFiles: Boolean;
    procedure PageViewChanged(Page: TEditorPage);
    procedure ApplyEditorOptions;
    procedure ApplyFixedFont;
    { project }
    procedure OpenProject(const FileName: string; Mode: TOpenMode = omOpen);
    { a project or package loaded - of the group or beside it -, or the group's file }
    function ProjectIsOpen(const FileName: string): Boolean;
    function OpenBeside(const FileName, ViewName: string; Show, Activate: Boolean): TSdProject;
    function LoadProjectFile(const FileName: string; out Why: string): TSdProject;
    function LoadProjectOrSay(const FileName: string): TSdProject;
    procedure ProjectJoined(const FileName: string; P: TSdProject);
    function CloseGroup: Boolean;
    function OpensBeside(const FileName: string; Mode: TOpenMode): Boolean;
    function CloseForProject(const FileName: string; Mode: TOpenMode): Boolean;
    procedure SetActiveProject(P: TSdProject);
    procedure DisplayProject(P: TSdProject);
    { project groups }
    procedure OpenProjectGroup(const FileName: string);
    function ConfirmSaveGroup: Boolean;
    function SaveGroup(AskName: Boolean): Boolean;
    procedure ActivateProject(const FileName: string);
    procedure AddExistingProject;
    procedure AddNewProject;
    procedure RemoveGroupProject(const FileName: string; Ask: Boolean; Keep: Boolean = False);
    function CloseGroupProject(const FileName: string; Force: Boolean = False): Boolean;
    function ProjectLeaves(const FileName: string; Remove, Ask: Boolean; Force: Boolean = False;
      Activate: Boolean = False): Boolean;
    procedure ProjectUnbinds(const FileName: string);
    procedure ProjectGoes(const FileName: string; Remove, Activate: Boolean);
    procedure ProjectOwnDocs(P: TSdProject; const ProjectFile: string; Docs: TList);
    function CloseProjectDocs(Docs: TList): Boolean;
    procedure GroupEmptied;
    function CompileAllProjects(Build: Boolean): Boolean;
    { breakpoints are kept per project (the settings' Breakpoints:<project file>): a breakpoint
      belongs to the first loaded project whose file it is in, else to the active project }
    function BreakpointProject(BP: TDbgBreakpoint): TSdProject;
    procedure SaveProjectBreakpoints(Only: TSdProject);
    procedure LoadProjectBreakpoints(P: TSdProject);
    procedure DropProjectBreakpoints(P: TSdProject);
    procedure ClearMessageViews;
    procedure ClearBuildMessages;
    procedure ResetViews(KeepDebug: Boolean = False);
    procedure RefreshProjectTree;
    procedure ProjectDirsOf(P: TSdProject; Dirs: TStrings);
    procedure SearchDirsOf(P: TSdProject; Dirs: TStrings);
    function CodeInsightProject: TSdProject;
    procedure ConfigureCodeInsight;
    function ProjectSource: string;
    function SourceAndEncoding(const FileName: string; out E: TSdEncoding): string;
    function SourceOf(const FileName: string): string;
    { the encoding of a file as the IDE has it, without its text: its page's, else the one chosen
      for it, else the detected one (the system code page for a file that is not there) }
    function SourceEncoding(const FileName: string): TSdEncoding;
    procedure SetSourceOf(const FileName, Source: string);
    procedure SetProjectSourceOf(P: TSdProject; const Source: string);
    procedure ProjectSourceChanged(const Source: string);
    procedure ProjectSourceChangedOf(P: TSdProject; const Source: string);
    function UniqueUnitName(const Base: string; const Dir: string = ''; const Ext: string = '.pas'): string;
    function RootNameUsed(const Name: string): Boolean;
    function UniqueRootName(const Base: string): string;
    procedure ShowProjectOptions(Page: Integer);
    procedure ShowProjectOptionsOf(P: TSdProject; Page: Integer);
    function SaveProject(P: TSdProject): Boolean;
    procedure ViewProjectSource(P: TSdProject);
    function CIGetSource(const FileName: string; var Source: string): Boolean;
    procedure CIGetPendingUses(const FileName: string; Units: TStrings);
    { Name - a file's name in D7 Studio's text - as text of the project source SourceFile, whose
      encoding is E (a code page's text is its bytes). False, after a message, when E has no
      character for one of Name's: the source cannot name the file (nor could Delphi 7) }
    function NameForSource(const SourceFile, Name: string; const E: TSdEncoding; out Text: string): Boolean;
    { ... FileName relative to P's folder, for P's project source }
    function ProjectSourceName(P: TSdProject; const FileName: string; out Rel: string): Boolean;
    { build / run }
    function CompilerReads(P: TSdProject; const FileName: string): Boolean;
    function CompileTarget(P: TSdProject; Warnings: TStrings; Utf8, Utf8Compiler: Boolean;
      out HighText: Boolean): string;
    { the bytes of FileName as Save would write them when its page has unsaved changes - the
      resource scripts compiled as the editor has them (SdProject.CompileResScripts) }
    function UnsavedFileBytes(const FileName: string; out Bytes: string): Boolean;
    function CompileBusy: Boolean;
    function DoCompile(Build, ForDebug, SyntaxOnly: Boolean; ForRun: Boolean = False): Boolean;
    { the experts hear of a compile (IOTAIDENotifier: they can cancel it) around CompileNow }
    function CompileProject(P: TSdProject; Build, ForDebug, SyntaxOnly: Boolean; ForRun: Boolean = False): Boolean;
    function CompileNow(P: TSdProject; Build, ForDebug, SyntaxOnly, ForRun: Boolean;
      out Cancelled: Boolean): Boolean;
    procedure AddMessage(const Text: string; Obj: TObject);
    procedure ShowBottom(Index: Integer; Slide: Boolean = True);
    procedure ClearErrorLine;
    procedure MarkErrorLine(P: TEditorPage; Line: Integer);
    procedure CheckErrorLine;
    function StartDebug(StopAtEntry: Boolean): Boolean;
    procedure DebugSourceDirs(Dirs: TStrings);
    procedure AttachToProcess;
    function FindFormClass(const ClassName: string; P: TSdProject; out Pas, Dfm: string; var Forms: TStringList): Boolean;
    function AncestorDfms(const ClassName: string; Dfms: TStrings; P: TSdProject; Base: PString = nil): Boolean;
    function AncestorChain(const ClassName: string; Dfms, Classes: TStrings; P: TSdProject; Base: PString;
      var Forms: TStringList): Boolean;
    function FrameRefersTo(const Cls, Target: string; P: TSdProject; var Forms: TStringList; Depth: Integer): Boolean;
    procedure ProjectFrames(P: TSdProject; const Designed: string; Names, Classes: TStrings);
    function InsertFrame(D: TFormDesigner; Drop: Boolean; const ScreenPt: TPoint): Boolean;
    procedure AddInheritedForm(const AncestorFile, AncestorClass: string);
    procedure AddToRepository(Project: Boolean);
    function RepositoryDefault(const Key: string): string;
    procedure EditRepository;
    procedure LoadCompTemplates;
    procedure CreateCompTemplate;
    function RunWithoutDebugging: Boolean;
    { debugger callbacks }
    procedure DebugLocation(const FileName: string; Line: Integer);
    procedure DebugRunning(Sender: TObject);
    procedure DebugStateChange(Sender: TObject);
    procedure StopDebugNow;
    procedure RunStateChanged(Running, Active: Boolean);
    function DesktopFile: string;
    function DesktopActiveProject: TSdProject;
    procedure SaveDesktop;
    function LoadDesktop: Boolean;
    procedure DebugBreakpointsChanged(Sender: TObject);
    procedure RefreshBreakMarkers(Page: TEditorPage);
    procedure SyncBreakpoints(Page: TEditorPage);
    procedure SyncAllBreakpoints;
    procedure ClearExecMarkers;
    { designer environment }
    procedure DesSelectionChanged(D: TFormDesigner);
    procedure DesModified(D: TFormDesigner);
    procedure DesStructureChanged(D: TFormDesigner);
    procedure DesFocusInspector(Key: Char; const PropName: string);
    procedure DesContextMenu(D: TFormDesigner; const ScreenPt: TPoint);
    procedure DropVerbs;
    procedure DesVerbExecute(Sender: TObject);
    procedure CompBarAdd(Sender: TObject; Cls: TComponentClass; var Done: Boolean);
    procedure CompBarCanDrop(Sender: TObject; const ScreenPt: TPoint; var Accept: Boolean);
    procedure CompBarDrop(Sender: TObject; Cls: TComponentClass; const ScreenPt: TPoint; var Done: Boolean);
    function PaletteToolClick(Designer: TFormDesigner; const ScreenPt: TPoint; Shift: TShiftState): Boolean;
    procedure StructGotoLine(Sender: TObject; Line, Col: Integer);
    procedure StructAddItem;
    procedure StructDeleteItem;
    procedure WMInheritRename(var Message: TMessage); message WM_SDINHERITRENAME;
    procedure QueueInheritRename(Page: TEditorPage; const OldName, NewName: string);
    function RenameInheritedEntries(const Text, X, OldName, NewName: string; P: TSdProject;
      var Forms: TStringList): string;
    procedure ObjTreeCommand(Sender: TObject);
    procedure RefreshObjTree(Force: Boolean);
    procedure RefreshExplorer;
    procedure ExpForget;
    function ExpPageOf(Edit: Boolean): TEditorPage;
    procedure ExpFollowCaret(Page: TEditorPage);
    procedure UpdateExplorerTitle;
    procedure ExpParse(Sender: TObject);
    procedure ExpShowSource(Sender: TObject; TopLine, Line, Col: Integer; TakeFocus: Boolean);
    function ExpNew(Sender: TObject; const Place: TExpNewPlace; const Text: string): Boolean;
    function ExpRename(Sender: TObject; Node: TCIExpNode; const ClassName, NewName: string): Boolean;
    procedure ExpViewEditor(Sender: TObject);
    procedure ExpProperties(Sender: TObject);
    function ExpApply(P: TEditorPage; OK: Boolean; const NewSource, Error: string): Boolean;
    procedure ShowDockPanel(P: TSdDockPanel; Slide: Boolean = True);
    procedure ViewDockPanel(P: TSdDockPanel);
    procedure ArrangementNames(const Section: string; Names: TStrings);
    procedure LoadArrangement(const Section: string);
    procedure ShowOptions(Section: TOptionsSection; Page: Integer = 0);
    function DoCloseQuery: Boolean;   // CloseQuery's checks and saving
    { Project | Format Project Sources: the project file, its units and (Formatter Options) their
      text form files - open files in their editors, the others on the disk }
    procedure FormatProjectSources;
    procedure ShowBrowsedSymbol(const Item: TCIItem);
    procedure BrowseSymbolAtCursor;
    procedure ViewHelp;
    procedure SaveLinesAs(const Title: string; Lines: TStrings);
    procedure DockPanelShow(Sender: TObject; Panel: TSdDockPanel);
    procedure LoadPackageEditors(D: TCustomIniFile);
    procedure SavePackageEditors(D: TCustomIniFile);
    { search }
    procedure BeginSearch(Ed: TSciEdit);
    procedure SearchRange(Ed: TSciEdit; out Lo, Hi: Integer);
    function FindNextMatch(ShowNotFound: Boolean): Boolean;
    procedure DoReplace;
    procedure AddProjectFiles(Files: TStrings);
    function MenuList: TListBox;
    procedure DoFindInFiles;
    procedure LoadState;
    procedure SaveState(Quiet: Boolean = False);
    procedure WMDropFiles(var Message: TWMDropFiles); message WM_DROPFILES;
    procedure WMCopyData(var Message: TWMCopyData); message WM_COPYDATA;
    procedure TestCommand(const Cmd: string);
    procedure TestToolTip(Index: Integer);
    function FindNamed(const Name: string): TComponent;
    function FindMenuItem(const Path: string): TMenuItem;
    procedure DumpMenu(const FileName, Path: string);
    procedure CMTestClick(var Message: TMessage); message WM_APP + 77;
    procedure CMTestPopup(var Message: TMessage); message WM_APP + 78;
    procedure CMTestKey(var Message: TMessage); message WM_SDTESTKEY;
    procedure DumpState(const FileName: string);
  private
    { the trees of the views that are frames of their own (inline in the .dfm), by the names the
      code has always used }
    function GetWatchTree: TTreeView;
    function GetResTree: TTreeView;
    property WatchTree: TTreeView read GetWatchTree;
    property ResTree: TTreeView read GetResTree;
  protected
    procedure CreateWnd; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    function CloseQuery: Boolean; override;
    { File | Open of a file - also the command line's, files dropped, an expert's
      IOTAActionServices.OpenFile (ProjectMode omNewGroup); True: it is open then }
    function OpenAny(const FileName: string; ProjectMode: TOpenMode = omOpen): Boolean;
    procedure ShowFloatingViews;    // once the window is on the screen: the floating views' windows
    procedure ExpertsLoaded;        // the experts loaded at the start: their views placed as saved
    procedure ApplyStartState;      // just before the window is first shown: the state it was closed in
    property Pages[Index: Integer]: TEditorPage read GetPage;
    { the IDE closed to start again (Restart now after a new UI font): D7Studio.dpr starts its EXE
      once the experts are shut down }
    property RestartWanted: Boolean read FRestart;
    { the check for updates in the background: Manual (Help | Check for Updates) reports every result,
      else it runs only when it is due (SdUpdate.UpdateCheckDue) and reports only a newer release }
    procedure CheckForUpdates(Manual: Boolean);
    { the IDE closed to update: D7Studio.dpr starts this setup once the experts are shut down }
    property UpdateSetup: string read FUpdateSetup;
  end;

var
  MainForm: TMainForm;

implementation

uses
  ShlObj, SdDbgTD32, SdCompInfoDlg, SdCompListDlg, SdNewItemsDlg, SdNewThreadDlg,
  SdPrintDlg, SdPasLex, SdWatchEditDlg, TypInfo, FileCtrl, CommCtrl, PropertyCategories,
  SdFormatter, SdFormatterOptions, SdDiagram, SdPEHeader, ToolsAPI, SdOtaModules, SdOtaServices,
  SdOtaDesktop, SdOtaCodeInsight, SdOtaEditWindow, SdDesignMenus, SdHints, Dialogs, SdUpdateDlg;

{$R *.dfm}

const
  AppTitle = 'D7 Studio';
  BT_MESSAGES = 0;
  BT_SEARCH = 1;
  BT_BREAKS = 2;
  BT_STACK = 3;
  BT_WATCHES = 4;
  BT_LOCALS = 5;
  BT_LOG = 6;
  BT_TODO = 7;
  BT_ERRORS = 8;
  { the status bar's panels }
  spPosition = 0;               // the caret's line and column
  spModified = 1;               // Modified, Recording
  spMode = 2;                   // Insert, Overwrite
  spErrors = 3;                 // Error Insight's errors of the file shown
  spEncoding = 4;               // the encoding, the zoom
  spMessage = 5;                // hints, the compiler's and the debugger's state
  PaneSection = 'Panes';        // TSdDock.Save / Load
  CompSection = 'Components';   // the Components view: its look, the components added from it
  ToolbarSection = 'Toolbars';  // Customize | Options: ShowTooltips, ShowShortcuts
  InspSection = 'PropertyInspector';   // the Object Inspector's ArrangeBy, HiddenCategories (Delphi's)
  UnitFilter = 'Delphi unit (*.pas)|*.pas|Any file (*.*)|*.*';     // Save / Save As of a page

{ the file dialog filter of a project file: a package (.dpk) or a program/library (.dpr) }
function ProjectFilter(Package: Boolean): string;
begin
  if Package then Result := 'Delphi package (*.dpk)|*.dpk' else Result := 'Delphi project (*.dpr)|*.dpr';
end;

{ ---------------------------------------------------------------- the Open Tools API's host }

function FormFileText(const Dfm: string): string; forward;
function UnitFormName(const PasFile: string): string; forward;

type
  { how TOtaMainHost.OpenPage makes a page: the file read, a new file of a text (written when
    saved), the existing file shown with a text that is not read from it }
  TPageLoad = (plRead, plNew, plText);

  { what the Open Tools API (SdOta*) asks of the main window: the main form's own
    parts and routines }
  TOtaMainHost = class(TSdOtaHost)
  private
    FMain: TMainForm;
  public
    function MainForm: TCustomForm; override;
    function MainMenu: TMainMenu; override;
    function ActionList: TCustomActionList; override;
    function ImageList: TCustomImageList; override;
    function ToolBar(const Name: string): TToolBar; override;
    function StatusBar: TStatusBar; override;
    function WizardMenu: TMenuItem; override;
    function WizardActions: TActionList; override;
    function ExecuteAction(const Name: string): Boolean; override;
    procedure SwapSourceFormLater(Page: TEditorPage); override;
    function MenuShortCut(SC: TShortCut): Boolean; override;
    function PageCount: Integer; override;
    function Pages(Index: Integer): TEditorPage; override;
    function ActivePage: TEditorPage; override;
    function FindPage(const FileName: string): TEditorPage; override;
    function OpenFile(const FileName: string; Activate: Boolean): TEditorPage; override;
    function OpenAny(const FileName: string): Boolean; override;
    procedure ShowPage(Page: TEditorPage); override;
    procedure ShowFileLine(const FileName: string; Line, Col: Integer); override;
    function ClosePage(Page: TEditorPage; Prompt: Boolean): Boolean; override;
    function SavePage(Page: TEditorPage; AskName: Boolean): Boolean; override;
    function RenamePage(Page: TEditorPage; const FileName: string): Boolean; override;
    function RenameProject(P: TSdProject; const FileName: string): Boolean; override;
    function SaveProjectAs(P: TSdProject; const FileName: string): Boolean; override;
    function SaveAll: Boolean; override;
    function CloseAll: Boolean; override;
    function ReloadPage(Page: TEditorPage): Boolean; override;
    function NewItemsDialog: Boolean; override;
    function NewModule(const FileName, Source, Dfm: string; Unnamed, AddToProject, ShowForm,
      ShowSource: Boolean): TEditorPage; override;
    function NewModuleOf(Owner: TSdProject; const FileName, Source, Dfm: string; Unnamed, ShowForm,
      ShowSource: Boolean): TEditorPage; override;
    function UniqueUnitName(const Prefix: string): string; override;
    function UniqueRootName(const Prefix: string): string; override;
    function DefaultDir: string; override;
    function Project: TSdProject; override;
    function ProjectGroup: TSdProjectGroup; override;
    function GroupProject(const FileName: string): TSdProject; override;
    function OpenProject(const FileName: string; NewGroup: Boolean): Boolean; override;
    procedure ActivateProject(const FileName: string); override;
    procedure AddNewProject; override;
    procedure AddExistingProject; override;
    procedure RemoveGroupProject(const FileName: string); override;
    function CloseGroupProject(const FileName: string; Force: Boolean): Boolean; override;
    function CloseProject(Force: Boolean): Boolean; override;
    function CompileProject(P: TSdProject; Mode: TOTACompileMode; ClearMessages: Boolean): Boolean; override;
    procedure EditProjectOptions(P: TSdProject); override;
    procedure ProjectOptionsChanged(P: TSdProject); override;
    function ProjectAddFile(const FileName: string): Boolean; override;
    function ProjectRemoveFile(const FileName: string): Boolean; override;
    function ProjectAddFileTo(P: TSdProject; const FileName: string): Boolean; override;
    function ProjectRemoveFileFrom(P: TSdProject; const FileName: string): Boolean; override;
    function SourceOf(const FileName: string): string; override;
    procedure ShowMessages; override;
    procedure ClearSearchResults; override;
    function Debug: TDebugController; override;
    procedure DebugSourceDirs(Dirs: TStrings); override;
    procedure DebugRun(const Exe, Params: string); override;
    procedure DebugAttach(Pid: Cardinal); override;
    procedure BreakpointsChanged; override;
    procedure ResourcesWritten(const ResFile: string); override;
    procedure EditorOptionsChanged; override;
    procedure EnvironmentOptionsChanged; override;
    function StepMessage(Delta: Integer): Boolean; override;
    function TodoList: TSdTodoList; override;
    procedure TodoExpertsChanged; override;
    procedure TodoDropModule(Module: HMODULE); override;
    function TodoCanEdit(Item: TSdTodoItem): Boolean; override;
    procedure TodoChange(Item: TSdTodoItem; const NewComment: string); override;
    procedure TodoEdit(Item: TSdTodoItem); override;
    function TypeLibraryFile: string; override;
    function TypeLibraryUnit: string; override;
    function TypeLibraryUnitText: string; override;
    function OpenTypeLibrary(const FileName: string): Boolean; override;
    function CloseTypeLibrary: Boolean; override;
    function OpenVirtualFile(const FileName, FileSystem, Source: string; New, Activate: Boolean): TEditorPage; override;
    function OpenWithText(const FileName, FileSystem, Text: string; Activate: Boolean): TEditorPage; override;
    function OpenPage(const FileName, FileSystem, Source: string; Load: TPageLoad; Activate: Boolean): TEditorPage;
  end;

function TOtaMainHost.MainForm: TCustomForm;
begin
  Result := FMain;
end;

function TOtaMainHost.MainMenu: TMainMenu;
begin
  Result := FMain.MainMenu;
end;

function TOtaMainHost.ActionList: TCustomActionList;
begin
  Result := FMain.ActionList;
end;

function TOtaMainHost.ImageList: TCustomImageList;
begin
  Result := FMain.Icons;
end;

{ Delphi 7's tool bars are one bar here (MainBar): each of their names finds it }
function TOtaMainHost.ToolBar(const Name: string): TToolBar;
var
  C: TComponent;
begin
  if SameText(Name, sCustomToolBar) or SameText(Name, sStandardToolBar) or SameText(Name, sDebugToolBar) or
    SameText(Name, sViewToolBar) or SameText(Name, sDesktopToolBar) or SameText(Name, sInternetToolBar) or
    SameText(Name, sCORBAToolBar) then
    Result := FMain.MainBar
  else
  begin
    C := FMain.FindComponent(Name);
    if C is TToolBar then Result := TToolBar(C) else Result := nil;
  end;
end;

function TOtaMainHost.StatusBar: TStatusBar;
begin
  Result := FMain.StatusBar;
end;

function TOtaMainHost.WizardMenu: TMenuItem;
begin
  Result := FMain.HelpMenu;
end;

function TOtaMainHost.WizardActions: TActionList;
begin
  Result := FMain.WizardActions;
end;

function TOtaMainHost.ExecuteAction(const Name: string): Boolean;
var
  C: TComponent;
begin
  Result := False;
  C := FMain.FindNamed(Name);
  if not (C is TCustomAction) then Exit;
  { the enabled states as they are now: an expert may have changed the page (its view, its
    file) in the same call - the main window sets them at idle time (UpdateActionStates) }
  FMain.UpdateActionStates;
  TCustomAction(C).Update;
  if TCustomAction(C).Enabled then Result := TCustomAction(C).Execute;
end;

{ as the VCL finds a shortcut (TActionList.IsShortCut, TMenu.IsShortCut): an action of the main
  window with the shortcut, enabled after its update, or a menu item of it without an action }
function TOtaMainHost.MenuShortCut(SC: TShortCut): Boolean;
var
  I: Integer;
  C: TComponent;
begin
  Result := False;
  if SC = 0 then Exit;
  for I := 0 to FMain.ComponentCount - 1 do
  begin
    C := FMain.Components[I];
    if C is TCustomAction then
    begin
      if (TCustomAction(C).ShortCut <> SC) and (TCustomAction(C).SecondaryShortCuts.IndexOfShortCut(SC) < 0) then
        Continue;
      TCustomAction(C).Update;
      Result := TCustomAction(C).Enabled;
    end
    else if (C is TMenuItem) and (TMenuItem(C).Action = nil) and (TMenuItem(C).ShortCut = SC) then
      Result := TMenuItem(C).Enabled;
    if Result then Exit;
  end;
end;
procedure TOtaMainHost.SwapSourceFormLater(Page: TEditorPage);
begin
  if FMain.HandleAllocated then PostMessage(FMain.Handle, WM_SDSWAPFORM, 0, LPARAM(Page));
end;

function TOtaMainHost.PageCount: Integer;
begin
  Result := FMain.PageCount;
end;

function TOtaMainHost.Pages(Index: Integer): TEditorPage;
begin
  Result := FMain.Pages[Index];
end;

function TOtaMainHost.ActivePage: TEditorPage;
begin
  Result := FMain.ActivePage;
end;

function TOtaMainHost.FindPage(const FileName: string): TEditorPage;
begin
  Result := FMain.FindPage(FileName);
  if (Result = nil) and (FileName <> '') then Result := FMain.FindPage(ExpandPathU(FileName));
end;

function TOtaMainHost.OpenFile(const FileName: string; Activate: Boolean): TEditorPage;
begin
  Result := FMain.OpenFile(FileName, Activate);
end;

{ a project, package or group in a group of its own: Delphi's default open procedure leaves the
  package create mode at 0 (only its File | Open command sets 1, a package beside the group) }
function TOtaMainHost.OpenAny(const FileName: string): Boolean;
begin
  Result := (FileName <> '') and FMain.OpenAny(ExpandPathU(FileName), omNewGroup);
end;

procedure TOtaMainHost.ShowPage(Page: TEditorPage);
begin
  FMain.ActivatePage(Page);
end;

procedure TOtaMainHost.ShowFileLine(const FileName: string; Line, Col: Integer);
begin
  FMain.ShowFileLine(FileName, Line, Col);
end;

function TOtaMainHost.ClosePage(Page: TEditorPage; Prompt: Boolean): Boolean;
begin
  Result := FMain.ClosePage(Page, Prompt);
end;

function TOtaMainHost.SavePage(Page: TEditorPage; AskName: Boolean): Boolean;
begin
  if AskName then Result := FMain.SaveDocAs(Page) else Result := FMain.SavePage(Page);
end;

function TOtaMainHost.RenamePage(Page: TEditorPage; const FileName: string): Boolean;
begin
  Result := FMain.RenamePage(Page, FileName, False);
end;

function TOtaMainHost.RenameProject(P: TSdProject; const FileName: string): Boolean;
begin
  Result := (P <> nil) and FMain.RenameProjectOnly(P, FileName);
end;

function TOtaMainHost.SaveProjectAs(P: TSdProject; const FileName: string): Boolean;
begin
  Result := (P <> nil) and FMain.SaveProjectAsName(P, FileName);
end;

{ File | Save All: the options an expert changed are written too (else at the next idle), the
  group of several projects when it changed }
function TOtaMainHost.SaveAll: Boolean;
begin
  Result := FMain.SaveAllFiles;
end;

{ Delphi's Close All: the project group and every file }
function TOtaMainHost.CloseAll: Boolean;
begin
  Result := FMain.CloseAllFiles;
end;

function TOtaMainHost.ReloadPage(Page: TEditorPage): Boolean;
begin
  FMain.ReloadPage(Page);
  Result := True;
end;

function TOtaMainHost.NewItemsDialog: Boolean;
begin
  FMain.NewItems;
  Result := True;
end;

{ an expert's new module (IOTAModuleServices.CreateModule): into its files and the project as the
  IDE's New Form puts a form there, or an untitled page }
{ An expert's new module: made in memory - a page under its name, an untitled page when unnamed -,
  its files written when it is saved, as Delphi 7 writes a new module's (a file of its name that is
  there already stays as it is until then). }
function TOtaMainHost.NewModule(const FileName, Source, Dfm: string; Unnamed, AddToProject, ShowForm,
  ShowSource: Boolean): TEditorPage;
var
  Owner: TSdProject;
begin
  if AddToProject then Owner := FMain.FProject else Owner := nil;
  Result := NewModuleOf(Owner, FileName, Source, Dfm, Unnamed, ShowForm, ShowSource);
end;

{ ... into Owner's uses clause (a project of the group, active or not), with its form's
  CreateForm as the IDE's New Form puts it there }
function TOtaMainHost.NewModuleOf(Owner: TSdProject; const FileName, Source, Dfm: string; Unnamed, ShowForm,
  ShowSource: Boolean): TEditorPage;
var
  Src, N, C: string;
begin
  { nothing is written before the page is saved (Delphi 7's, measured): a named module is a page in
    memory under its name, modified, an unnamed one an untitled page }
  if Unnamed then FMain.NewUntitledPage(ExtractFileName(FileName), Source, Dfm)
  else FMain.NewUntitledPage(FileName, Source, Dfm, True);
  Result := FMain.ActivePage;
  if not Unnamed and (Owner <> nil) then
  begin
    if not DfmObjectHeader(Dfm, N, C) then N := '';
    if FMain.ProjectAddUnitTo(Owner, FileName, N) and (N <> '') and not Owner.IsPackage and
      EnvOptions.AutoCreateForms and (Pos('CLASS(TFRAME)', UpperCase(StringReplace(Source, ' ', '', [rfReplaceAll]))) = 0) then
    begin
      Src := FMain.SourceOf(Owner.FileName);
      DprAddCreateForm(Src, C, N);
      FMain.ProjectSourceChangedOf(Owner, Src);
    end;
  end;
  if (Result <> nil) and ShowForm and Result.HasForm then Result.ShowDesign(True);
end;

function TOtaMainHost.UniqueUnitName(const Prefix: string): string;
begin
  Result := FMain.UniqueUnitName(Prefix);
end;

function TOtaMainHost.UniqueRootName(const Prefix: string): string;
begin
  Result := FMain.UniqueRootName(Prefix);
end;

function TOtaMainHost.DefaultDir: string;
begin
  if FMain.FProject <> nil then Result := FMain.FProject.Dir
  else Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

function TOtaMainHost.Project: TSdProject;
begin
  Result := FMain.FProject;
end;

function TOtaMainHost.ProjectGroup: TSdProjectGroup;
begin
  Result := FMain.FGroup;
end;

function TOtaMainHost.GroupProject(const FileName: string): TSdProject;
begin
  Result := FMain.FGroup.LoadedProjectOf(FileName);
end;

{ True when it is open then - also when its desktop made a package beside the group the active
  project }
function TOtaMainHost.OpenProject(const FileName: string; NewGroup: Boolean): Boolean;
begin
  if NewGroup then FMain.OpenProject(FileName, omNewGroup) else FMain.OpenProject(FileName, omAddToGroup);
  Result := FMain.ProjectIsOpen(FileName);
end;

procedure TOtaMainHost.ActivateProject(const FileName: string);
begin
  FMain.ActivateProject(FileName);
end;

procedure TOtaMainHost.AddNewProject;
begin
  FMain.AddNewProject;
end;

procedure TOtaMainHost.AddExistingProject;
begin
  FMain.AddExistingProject;
end;

{ IOTAProjectGroup.RemoveProject: Remove Project without the Project Manager's question, the project
  kept beside the group (Delphi 7's) }
procedure TOtaMainHost.RemoveGroupProject(const FileName: string);
begin
  FMain.RemoveGroupProject(FileName, False, True);
end;

{ the project group with every project and file (Delphi's IOTAModule.Close of the group); the
  user is asked about unsaved files also when an expert forces the close: nothing is lost without
  the user's answer }
function TOtaMainHost.CloseProject(Force: Boolean): Boolean;
begin
  Result := FMain.CloseGroup;
end;

function TOtaMainHost.CompileProject(P: TSdProject; Mode: TOTACompileMode; ClearMessages: Boolean): Boolean;
begin
  case Mode of
    cmOTABuild: Result := FMain.CompileProject(P, True, False, False);
    cmOTACheck: Result := FMain.CompileProject(P, False, False, True);
  else
    Result := FMain.CompileProject(P, False, False, False);
  end;
end;

procedure TOtaMainHost.EditProjectOptions(P: TSdProject);
begin
  FMain.ShowProjectOptionsOf(P, 0);
end;

{ IOTAModule.CloseModule of a project: Delphi's closed project - it stays in the group }
function TOtaMainHost.CloseGroupProject(const FileName: string; Force: Boolean): Boolean;
begin
  Result := FMain.CloseGroupProject(FileName, Force);
end;

{ the active project's: written and applied once, at the next idle (an expert sets many in a row);
  another project's at once - code insight follows when it works for that project }
procedure TOtaMainHost.ProjectOptionsChanged(P: TSdProject);
begin
  if P = FMain.FProject then
  begin
    FMain.FOtaProjectOptions := True;
    Exit;
  end;
  try
    P.SaveOptions;
  except
    on E: Exception do OtaError(E, 'project options');
  end;
  if P = FMain.FCIProject then FMain.ConfigureCodeInsight;
end;

function TOtaMainHost.ProjectAddFile(const FileName: string): Boolean;
begin
  Result := ProjectAddFileTo(FMain.FProject, FileName);
end;

function TOtaMainHost.ProjectRemoveFile(const FileName: string): Boolean;
begin
  Result := ProjectRemoveFileFrom(FMain.FProject, FileName);
end;

{ a unit, or a resource script (its $R, as Delphi's AddFile of a .rc) }
function TOtaMainHost.ProjectAddFileTo(P: TSdProject; const FileName: string): Boolean;
begin
  if SameText(ExtractFileExt(FileName), '.rc') then
    Result := (P <> nil) and FMain.ProjectAddResScriptTo(P, FileName)
  else
    Result := (P <> nil) and SameText(ExtractFileExt(FileName), '.pas') and
      FMain.ProjectAddUnitTo(P, FileName, UnitFormName(FileName));
end;

function TOtaMainHost.ProjectRemoveFileFrom(P: TSdProject; const FileName: string): Boolean;
var
  U: TProjectUnit;
begin
  Result := False;
  if P = nil then Exit;
  U := P.FindUnit(FileName);
  if U = nil then U := P.FindResScript(FileName);
  Result := U <> nil;
  if Result then FMain.RemoveProjectUnitOf(P, U);
end;

function TOtaMainHost.SourceOf(const FileName: string): string;
begin
  Result := FMain.SourceOf(FileName);
end;

procedure TOtaMainHost.ShowMessages;
begin
  FMain.ShowBottom(BT_MESSAGES);
end;

procedure TOtaMainHost.ClearSearchResults;
begin
  FMain.ClearSearchResults;
end;

function TOtaMainHost.Debug: TDebugController;
begin
  Result := FMain.FDebug;
end;

procedure TOtaMainHost.DebugSourceDirs(Dirs: TStrings);
begin
  FMain.DebugSourceDirs(Dirs);
end;

{ Delphi 7's IOTADebuggerServices.CreateProcess (measured): the program loaded and stopped at its main
  block's begin - the entry, when its line has debug information }
procedure TOtaMainHost.DebugRun(const Exe, Params: string);
var
  Dirs: TStringList;
begin
  if FMain.FDebug.Active then Exit;
  Dirs := TStringList.Create;
  try
    FMain.PrepareDebug(Dirs);
    FMain.FDebug.Run(Exe, Params, ExtractFilePath(Exe), Dirs, True);
  finally
    Dirs.Free;
  end;
end;

procedure TOtaMainHost.DebugAttach(Pid: Cardinal);
begin
  FMain.AttachTo(Pid);
end;

procedure TOtaMainHost.BreakpointsChanged;
begin
  FMain.FDebug.BreakpointsChanged;
end;

{ the Resources view shows the file again once the expert's command is over: several entries
  written by one command fill it once }
procedure TOtaMainHost.ResourcesWritten(const ResFile: string);
var
  R: TSdResources;
begin
  R := FMain.FResView.Resources;
  if (R <> nil) and SameText(R.ResFile, ResFile) then FMain.FResWritten := True;
end;

{ into the settings at once; the file written and the editors changed once, at the next idle }
procedure TOtaMainHost.EditorOptionsChanged;
begin
  SaveEditorOptions(Settings);
  FMain.FOtaEditorOptions := True;
end;

procedure TOtaMainHost.EnvironmentOptionsChanged;
begin
  FMain.FOtaEnvOptions := True;
end;

function TOtaMainHost.StepMessage(Delta: Integer): Boolean;
begin
  Result := FMain.StepMessage(Delta);
end;

function TOtaMainHost.TodoList: TSdTodoList;
begin
  Result := FMain.FTodo;
end;

procedure TOtaMainHost.TodoExpertsChanged;
begin
  FMain.TodoExpertsChanged;
end;

procedure TOtaMainHost.TodoDropModule(Module: HMODULE);
begin
  FMain.TodoDropModule(Module);
end;

function TOtaMainHost.TodoCanEdit(Item: TSdTodoItem): Boolean;
begin
  Result := FMain.TodoCanEdit(Item);
end;

procedure TOtaMainHost.TodoChange(Item: TSdTodoItem; const NewComment: string);
begin
  FMain.ChangeTodoComment(Item, NewComment);
end;

procedure TOtaMainHost.TodoEdit(Item: TSdTodoItem);
begin
  FMain.EditTodo(Item);
end;

function TOtaMainHost.TypeLibraryFile: string;
begin
  Result := FMain.FTypeLibView.FileName;
end;

function TOtaMainHost.TypeLibraryUnit: string;
begin
  Result := '';
  if FMain.FTypeLibView.TypeLib = nil then Exit;
  try
    Result := TypeLibUnitName(FMain.FTypeLibView.TypeLib);
  except
    Result := '';
  end;
end;

function TOtaMainHost.TypeLibraryUnitText: string;
var
  Imp: TTLBImport;
  Main: string;
  I: Integer;
begin
  Result := '';
  if FMain.FTypeLibView.TypeLib = nil then Exit;
  Imp := TypeLibTextImport;
  try
    try
      Main := Imp.Import(FMain.FTypeLibView.TypeLib);
      for I := 0 to Imp.Count - 1 do
        if SameText(Imp.UnitName(I), Main) then Result := SystemToIde(Imp.Source(I));
    except
      Result := '';
    end;
  finally
    Imp.Free;
  end;
end;

function TOtaMainHost.OpenTypeLibrary(const FileName: string): Boolean;
begin
  Result := FMain.OpenTypeLibrary(FileName);
end;

{ the library's module goes (its notifiers told Destroyed), the view is emptied and hidden }
function TOtaMainHost.CloseTypeLibrary: Boolean;
var
  F: string;
begin
  Result := True;
  F := FMain.FTypeLibView.FileName;
  if F = '' then Exit;
  OtaFileNotification(ofnFileClosing, F);
  OtaModules.Forget(F);
  FMain.FTypeLibView.Clear;
  FMain.FDock.HidePanel(FMain.FTypeLibPanel);
end;

{ a page of a file of an expert's file system (IOTACreator.GetFileSystem): read through it, or a
  new one of Source written through it when it is saved - no file of the disk: not among the
  recent files, not in a desktop. An error of the file system reaches the expert. }
function TOtaMainHost.OpenVirtualFile(const FileName, FileSystem, Source: string; New, Activate: Boolean): TEditorPage;
begin
  if New then Result := OpenPage(FileName, FileSystem, Source, plNew, Activate)
  else Result := OpenPage(FileName, FileSystem, '', plRead, Activate);
end;

function TOtaMainHost.OpenWithText(const FileName, FileSystem, Text: string; Activate: Boolean): TEditorPage;
begin
  Result := OpenPage(FileName, FileSystem, Text, plText, Activate);
end;

{ a page of a file of FileSystem made as Load says (plText: a file of the disk too, FileSystem ''),
  unless one is open }
function TOtaMainHost.OpenPage(const FileName, FileSystem, Source: string; Load: TPageLoad;
  Activate: Boolean): TEditorPage;
var
  Name: string;
begin
  if FileSystem = '' then Name := ExpandPathU(FileName) else Name := FileName;
  Result := FMain.FindPage(Name);
  if Result = nil then
  begin
    if not OtaFileNotification(ofnFileOpening, Name) then Exit;
    Result := TEditorPage.Create(FMain);
    FMain.AddPageTab(Result);
    try
      case Load of
        plNew:
          begin
            Result.NewFile(Name, Source, '', True);
            Result.FileSystem := FileSystem;
          end;
        plText: Result.LoadWithText(Name, FileSystem, Source);
      else
        Result.LoadFromFileSystem(Name, FileSystem);
      end;
    except
      FMain.FreePage(Result);
      raise;
    end;
    FMain.AdoptPage(Result, Name, Activate);
  end;
  if Activate then FMain.ActivatePage(Result);
end;

{ ---------------------------------------------------------------- the To-Do List's host }

type
  { what the To-Do List (SdTodoView) asks of the IDE: the items' files, the project, and the
    experts' To-Do managers, called while the list is locked (FTodoLock: no refresh meanwhile) }
  TTodoMainHost = class(TTodoHost)
  private
    FMain: TMainForm;
  public
    function CanEdit(Item: TSdTodoItem): Boolean; override;
    function HasProject: Boolean; override;
    procedure Add; override;
    procedure Edit(Item: TSdTodoItem); override;
    procedure ChangeComment(Item: TSdTodoItem; const NewComment: string); override;
    procedure OpenSource(Item: TSdTodoItem); override;
    function ExpertQuery(Item: TSdTodoItem; Action: TSdTodoAction): Boolean; override;
    procedure ExpertCommand(Item: TSdTodoItem; Action: TSdTodoAction); override;
    function ExpertDrawImage(Item: TSdTodoItem; Canvas: TCanvas; const R: TRect): Boolean; override;
    procedure ExpertsChanged; override;
  end;

function TTodoMainHost.CanEdit(Item: TSdTodoItem): Boolean;
begin
  Result := FMain.TodoCanEdit(Item);
end;

function TTodoMainHost.HasProject: Boolean;
begin
  Result := FMain.FProject <> nil;
end;

procedure TTodoMainHost.Add;
begin
  FMain.AddProjectTodo;
end;

procedure TTodoMainHost.Edit(Item: TSdTodoItem);
begin
  FMain.EditTodo(Item);
end;

procedure TTodoMainHost.ChangeComment(Item: TSdTodoItem; const NewComment: string);
begin
  FMain.ChangeTodoComment(Item, NewComment);
end;

procedure TTodoMainHost.OpenSource(Item: TSdTodoItem);
begin
  FMain.FServices.OpenFileAt(Item.FileName, Item.Line, 1);
end;

function TTodoMainHost.ExpertQuery(Item: TSdTodoItem; Action: TSdTodoAction): Boolean;
begin
  Inc(FMain.FTodoLock);
  try
    Result := OtaTodoAction(Item, Action);
  finally
    FMain.TodoUnlock;
  end;
end;

procedure TTodoMainHost.ExpertCommand(Item: TSdTodoItem; Action: TSdTodoAction);
begin
  FMain.TodoExpertCommand(Item, Action);
end;

function TTodoMainHost.ExpertDrawImage(Item: TSdTodoItem; Canvas: TCanvas; const R: TRect): Boolean;
begin
  Inc(FMain.FTodoLock);
  try
    Result := OtaTodoDrawImage(Item, Canvas, R);
  finally
    FMain.TodoUnlock;
  end;
end;

procedure TTodoMainHost.ExpertsChanged;
begin
  FMain.TodoExpertsChanged;
end;

{ ---------------------------------------------------------------- TMainServices }

function TMainServices.CodeInsight: TCodeInsight;
begin
  Result := FMain.FCodeInsight;
end;

function TMainServices.ProjectExeBase: string;
begin
  if FMain.FProject <> nil then
    Result := ChangeFileExt(FMain.FProject.ExeName, '')
  else
    Result := '';
end;

procedure TMainServices.OpenFileAt(const FileName: string; Line, Col: Integer);
begin
  FMain.ShowFileLine(FileName, Line, Col);
end;

procedure TMainServices.PageChanged(Page: TEditorPage);
begin
  if FMain.FClosing or FMain.FInPageChanged then Exit;
  FMain.FInPageChanged := True;
  try
    if Page = FMain.ActivePage then
    begin
      FMain.UpdateStatus;
      FMain.PageViewChanged(Page);
      OtaModules.PageViewChanged(Page);
    end;
    if Page = FMain.FErrorPage then FMain.CheckErrorLine;
    FMain.StructTimer.Enabled := False;
    FMain.StructTimer.Enabled := True;
  finally
    FMain.FInPageChanged := False;
  end;
end;

{ a form renamed in its designer: every project of the group whose unit it is follows - its
  CreateForm line and the form's comment in its uses clause (a unit of two projects: both) }
procedure TMainServices.FormRenamed(Page: TEditorPage; const OldName, NewName, OldClass, NewClass: string);
var
  Src, Rel: string;
  U: TProjectUnit;
  P: TSdProject;
  Owners: TList;
  I: Integer;
  Changed: Boolean;
begin
  if not FMain.FClosing then OtaModules.ComponentRenamed(Page, OldName, NewName);
  Changed := False;
  Owners := TList.Create;
  try
    FMain.FGroup.OwnersOf(Page.FileName, Owners);
    for I := 0 to Owners.Count - 1 do
    begin
      P := TSdProject(Owners[I]);
      U := P.FindUnit(Page.FileName);
      if U = nil then Continue;
      Src := FMain.SourceOf(P.FileName);
      DprRenameCreateForm(Src, OldClass, OldName, NewClass, NewName);
      if FMain.ProjectSourceName(P, U.FileName, Rel) then DprAddUnit(Src, U.Name, Rel, NewName);
      FMain.SetProjectSourceOf(P, Src);
      Changed := True;
    end;
  finally
    Owners.Free;
  end;
  if Changed then FMain.RefreshProjectTree;
end;

function TMainServices.EvaluateForTip(const Expr: string; out V: TDbgVar): Boolean;
begin
  Result := FMain.FDebug.TipValue(Expr, V);
end;

function TMainServices.ChildrenForTip(const Expr: string; out Vars: TDbgVarArray): Boolean;
begin
  Result := FMain.FDebug.TipChildren(Expr, Vars);
end;

procedure TMainServices.ToggleBreakpoint(Page: TEditorPage; Line: Integer);
begin
  FMain.SyncBreakpoints(Page);
  FMain.FDebug.ToggleBreakpoint(Page.FileName, Line);
  FMain.RefreshBreakMarkers(Page);
end;

procedure TMainServices.ShowMessage(const Text: string);
begin
  FMain.AddMessage(Text, nil);
  FMain.ShowBottom(BT_MESSAGES);
end;

procedure TMainServices.ShowStatus(const Text: string);
begin
  FMain.StatusBar.Panels[spMessage].Text := Text;
end;

{ the menu's PopupComponent is the editor control, as when the VCL pops up a control's menu
  (experts look at it) }
procedure TMainServices.EditorContextMenu(Page: TEditorPage; const ScreenPt: TPoint);
begin
  FMain.EditorLocalMenu.PopupComponent := FMain.FEditWindow;
  FMain.EditorLocalMenu.Popup(ScreenPt.X, ScreenPt.Y);
end;

{ the page of a form becomes the visible one because a design window of that form was
  activated; the keyboard stays where it is }
{ the key mapping's commands that are the IDE's: its menu commands; Read / Write Block (Delphi's
  Ctrl+K R / W) a file into the text at the caret, the block into a file }
function TMainServices.AncestorDfms(Page: TEditorPage; const ClassName: string; Dfms: TStrings): Boolean;
var
  P: TSdProject;
begin
  if Page <> nil then P := FMain.FGroup.ProjectForFile(Page.FileName) else P := FMain.FProject;
  Result := FMain.AncestorDfms(ClassName, Dfms, P);
end;

function TMainServices.FormBase(Page: TEditorPage; const ClassName: string; Dfms: TStrings): string;
var
  P: TSdProject;
begin
  if Page <> nil then P := FMain.FGroup.ProjectForFile(Page.FileName) else P := FMain.FProject;
  if not FMain.AncestorDfms(ClassName, Dfms, P, @Result) then Result := '';
end;

function TMainServices.FormUnitName(Page: TEditorPage; const ClassName: string): string;
var
  P: TSdProject;
  Pas, Dfm: string;
  Forms: TStringList;
begin
  Result := '';
  if Page <> nil then P := FMain.FGroup.ProjectForFile(Page.FileName) else P := FMain.FProject;
  Forms := nil;
  try
    if FMain.FindFormClass(ClassName, P, Pas, Dfm, Forms) then Result := FSGetUnitName(Pas);
  finally
    Forms.Free;
  end;
end;

function TMainServices.DiagramBar: TWinControl;
begin
  Result := FMain.DiagramBar;
end;

function TMainServices.HistoryBar: TWinControl;
begin
  Result := FMain.FileHistoryBar;
end;

function TMainServices.DesignerBar: TWinControl;
begin
  Result := FMain.DesignerBar;
end;

{ the History tab's menu: the timeline's commands on its list, the diff's on its windows (HistoryMenuPopup) }
procedure TMainServices.HistoryViewMade(View: TSdHistoryView);
begin
  View.Timeline.PopupMenu := FMain.HistoryMenu;
  View.DiffWindow.PopupMenu := FMain.HistoryMenu;
  View.SideWindow.PopupMenu := FMain.HistoryMenu;
end;

function TMainServices.NavigationBar: TWinControl;
begin
  Result := FMain.FNavBar;
end;

function TMainServices.ZoomBar: TWinControl;
begin
  Result := FMain.ZoomBar;
end;

procedure TMainServices.PageBarChanged(Page: TEditorPage);
begin
  if not FMain.FClosing and (Page = FMain.ActivePage) then
  begin
    FMain.ArrangePageBar(Page);
    FMain.FNavBar.Follow(Page, False);
  end;
end;

procedure TMainServices.ErrorsChanged(Page: TEditorPage);
begin
  if not FMain.FClosing and (Page = FMain.ActivePage) then FMain.UpdateStatus;
end;

procedure TMainServices.PageEdited(Page: TEditorPage; Position, LinesAdded: Integer);
begin
  Inc(FMain.FTodoEdits);
  if not FMain.FClosing then OtaModules.PageEdited(Page, Position, LinesAdded);
end;

procedure TMainServices.ComponentRenamed(Page: TEditorPage; const OldName, NewName: string);
begin
  if FMain.FClosing then Exit;
  OtaModules.ComponentRenamed(Page, OldName, NewName);
  FMain.QueueInheritRename(Page, OldName, NewName);
end;

procedure TMainServices.EditorZoomed(Page: TEditorPage);
begin
  FMain.ApplyZoom;
end;

function TMainServices.CIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
begin
  Result := OtaCIInvoke(Page, Key, Pos);
end;

function TMainServices.CIOwnAllowed(Page: TEditorPage): Boolean;
begin
  Result := OtaCIOwnAllowed(Page);
end;

function TMainServices.CIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := OtaCIKeyDown(Page, Key, Shift);
end;

function TMainServices.CIKeyPress(Page: TEditorPage; var Key: Char): Boolean;
begin
  Result := OtaCIKeyPress(Page, Key);
end;

procedure TMainServices.CIChanged(Page: TEditorPage);
begin
  OtaCIChanged(Page);
end;

procedure TMainServices.CICancel(Page: TEditorPage);
begin
  OtaCICancel(Page);
end;

procedure TMainServices.EditorCommand(Page: TEditorPage; Cmd: TEdCmd; Arg: Integer);

  procedure Run(A: TAction);
  begin
    A.Update;
    if A.Enabled then A.Execute else MessageBeep(0);
  end;

const
  BlockFilter = 'Pascal files (*.pas)|*.pas|Text files (*.txt)|*.txt|All files (*.*)|*.*';
var
  S, E: Integer;
  BlockFile: string;
begin
  with FMain do
    case Cmd of
      ecFind: Run(SearchFindCommand);
      ecReplace: Run(SearchReplaceCommand);
      ecSearchAgain: Run(SearchAgainCommand);
      ecIncSearch: Run(SearchIncrementalCommand);
      ecGotoLine: Run(SearchGoToCommand);
      ecSave: Run(FileSaveCommand);
      ecSaveAll: Run(FileSaveAllCommand);
      ecOpen: Run(FileOpenCommand);
      ecClose: Run(FileCloseCommand);
      ecWindowList: Run(ViewWindowListCommand);
      ecNextWindow: Run(ViewNextWindow);
      ecExit: Run(FileExitCommand);
      ecFindDecl: Run(aFindDecl);
      ecCompletion: Run(aComplete);
      ecFoldingOnOff: Run(aCodeFolding);
      ecBlockPrint: Run(FilePrintCommand);
      ecBlockRead, ecBlockWrite:
        begin
          if (Cmd = ecBlockWrite) and not Page.Editor.BlockRange(S, E) then
          begin
            MessageBeep(0);
            Exit;
          end;
          BlockFile := '';
          if Cmd = ecBlockRead then
          begin
            { the file in its own encoding, put into the page's }
            if BrowseFile('Read Block from File', BlockFilter, BlockFile) then
              Page.Editor.InsertText(Page.Editor.CaretPos, ReadSourceFileAs(BlockFile, Page.Editor.Encoding));
          end
          else
          begin
            { the block in the page's encoding (remembered for the file, as a page's save does) }
            if AskSaveName('Write Block to File', BlockFilter, '', BlockFile) then
              WriteSourceFile(BlockFile, Page.Editor.GetRange(S, E), Page.Editor.Encoding);
          end;
        end;
    end;
end;

procedure TMainServices.ShowPage(Page: TEditorPage);
begin
  if not FMain.FClosing and (FMain.ActivePage <> Page) then FMain.ActivatePage(Page);
end;

{ ---------------------------------------------------------------- TMainForm: construction

  The form and everything on it that is a standard component - the action lists, the menus,
  the control bar with the tool bars, the dock site with the centre and the lists and trees
  of the tool views, the status bar - is SdMain.dfm. Every command is an action; menu, tool
  bar and popup items only link to one. What the form designer does not know is created in
  OnCreate: the dock (SdDock) with its captions and tab strips, the Components view, the
  Code Explorer, the Object TreeView and the Object Inspector (the editor pages come and go with the files). }
procedure CopyInspectorOptions; forward;
function MenuTextW(Item: TMenuItem): WideString; forward;

procedure TMainForm.FormCreate(Sender: TObject);
var
  X, Y, I: Integer;
  WinHost: TDesignWindowHost;
begin
  UIApplyFont(Self);
  FPages := TList.Create;
  FDocs := TList.Create;
  FLockedPages := TList.Create;
  FHistory := TSdNavHistory.Create;
  LoadSettings;
  { Environment Options (SdEnvOptions): its values, and the variables it overrides }
  EnvOptions.Load;
  EnvOptions.ApplyVariables;
  CopyInspectorOptions;
  { the icons: Icons, the image list of the .dfm that the actions, menus and tool bars use with
    the ImageIndex values stored there, with their images of disabled commands (SdUI) }
  InitIcons(Icons);
  UIDisabledImages(Icons, DisabledIcons);
  { the debugger finds Run's debug information where MoveDebugInfo keeps it }
  TD32SideFile := DebugInfoFile;
  { the menus in D7 Studio's flat style (SdUI); a Reopen entry outside the code page with its
    real name }
  UIMenuTextW := MenuTextW;
  UIModernMenus(Self);
  FServices := TMainServices.Create;
  FServices.FMain := Self;
  IDE := FServices;
  FCompiler := TSdCompiler.Create;
  FScratch := TSdScratchBuild.Create;
  FCodeInsight := TCodeInsight.Create;
  FGroup := TSdProjectGroup.Create;
  FNewProjectMode := omOpen;
  FCodeInsight.OnGetSource := CIGetSource;
  FCodeInsight.OnGetPendingUses := CIGetPendingUses;
  { code insight reads units and include files through the IDE's file access: also names
    outside the code page (SdFileNames) }
  FCodeInsight.ReadFileFunc := ReadFileU;
  FCodeInsight.FileAgeFunc := FileAgeU;
  { without Scintilla every editor would stay blank: say why once }
  if not ScintillaAvailable then
    MessageBox(Handle, PChar(ScintillaLoadError), AppTitle, MB_OK or MB_ICONERROR);
  FDebug := TDebugController.Create(Self);
  FDebug.OnLocation := DebugLocation;
  FDebug.OnStateChange := DebugStateChange;
  FDebug.OnBreakpointsChanged := DebugBreakpointsChanged;
  FDebug.AddressFunc := ParseAddress;
  FDebug.OnRunning := DebugRunning;
  CompletionPopup := TCompletionPopup.Create(Self);
  ParamHint := TParamHintWindow.Create(Self);
  CodeTip := TSdCodeTip.Create(Self);
  ValueTip := TSdValueTip.Create(Self);
  FFind.PromptOnReplace := True;
  FFindFiles.Mask := '*.pas;*.dpr;*.inc';
  FFindFiles.Recurse := True;
  { the bookmark commands of the .dfm, for their states at every idle }
  for I := 0 to 9 do
  begin
    FBookmarkActions[I, False] := FindComponent('aToggleBookmark' + IntToStr(I)) as TAction;
    FBookmarkActions[I, True] := FindComponent('aGotoBookmark' + IntToStr(I)) as TAction;
  end;
  LoadState;
  if UITestOrigin(X, Y) then
  begin
    FStartMaximized := False;
    SetBounds(X, Y, 1366, 738);
  end;
  CreatePanes;
  DesignEnv.Options := Settings;
  DesignEnv.OnSelectionChanged := DesSelectionChanged;
  DesignEnv.OnModified := DesModified;
  DesignEnv.OnStructureChanged := DesStructureChanged;
  DesignEnv.OnFocusInspector := DesFocusInspector;
  DesignEnv.OnContextMenu := DesContextMenu;
  WinHost := TDesignWindowHost.Create;
  WinHost.FMain := Self;
  FDesignWinHost := WinHost;
  if DesignEnvironment <> nil then DesignEnvironment.Host := FDesignWinHost;
  DesignHost.OnPaletteChanged := HostPaletteChanged;
  DesignHost.OnPackageUnloading := HostPackageUnloading;
  DesignHost.OnPackageUnloaded := HostPackageUnloaded;
  FDesignWindows := TDesignWindows.Create(Self);
  FDesignWindows.OnGetOrigin := DesignWindowOrigin;
  FDesignWindows.OnShown := DesignWindowShown;
  DesignHost.OnDesignWindow := HostDesignWindow;
  DesignHost.OnSyncDesignWindows := HostSyncDesignWindows;
  LoadCompTemplates;
  { Application's OnIdle, OnActivate, OnHint, OnShowHint and OnException come through AppEvents
    (SdMain.dfm): AppEvnts' dispatcher owns Application's events, and every TApplicationEvents of
    the design packages and experts gets them too }
  Application.HintHidePause := 6000;
  { a command's shortcut key is added by AppShowHint, after a tab (grey in the hint window), as
    Customize's option says: not by the VCL as well (" (F9)", Application.HintShortCuts) }
  Application.HintShortCuts := False;
  { units opened without a project still complete against the RTL and VCL sources }
  ConfigureCodeInsight;
  UpdateReopenMenu;
  UpdateToolsMenu;
  UpdateCaption;
  DisableUnbuilt;
  { the Open Tools API: the IDE behind BorlandIDEServices - the menu wizards of the
    packages loaded so far get their items, the DLL experts load; the expert packages follow
    (D7Studio.dpr: TDesignHost.LoadDeferredPackages) }
  FOtaHost := TOtaMainHost.Create;
  TOtaMainHost(FOtaHost).FMain := Self;
  OtaHost := FOtaHost;
  OtaHostReady(FMsgView);
  { the look of the controls (the tool bar's: its disabled images of Visual Studio's set) and
    the commands' states now, not at the first idle: the window is shown and the start-up
    project opened before the message loop runs (D7Studio.dpr) - every command showed enabled
    until then. The first idle does it again for what was made meanwhile. }
  UIReduceFlicker(Self);
  UpdateActionStates;
end;

{ the commands of Delphi's menus that are not built (no OnExecute) are disabled: the VCL's
  DisableIfNoHandler reaches only the actions of the form's controls and main menu - those of
  the views' menus stayed enabled and did nothing }
procedure TMainForm.DisableUnbuilt;
var
  I: Integer;
begin
  for I := 0 to ActionList.ActionCount - 1 do
    if (ActionList.Actions[I] is TCustomAction) and not Assigned(ActionList.Actions[I].OnExecute) then
      TCustomAction(ActionList.Actions[I]).Enabled := False;
end;

function TMainForm.GetWatchTree: TTreeView;
begin
  Result := FWatchView.Tree;
end;

function TMainForm.GetResTree: TTreeView;
begin
  Result := FResView.Tree;
end;

{ a view made of one of the reused frames (its own .dfm): hidden until the dock shows it, the main
  form's popup menu on it }
procedure TMainForm.PlaceView(View: TFrame; Popup: TPopupMenu);
begin
  View.Visible := False;
  View.Parent := DockSite;
  View.PopupMenu := Popup;
end;

{ the parts of the window that are not in the .dfm, and the arrangement the user left behind }
procedure TMainForm.CreatePanes;
var
  I: Integer;
  S: string;

begin
  { the dock: the editor in the centre, areas at the left, the right and under the editor (the
    bottom area docks with the editor only). Without a saved arrangement: the Components view at
    the left, Project Manager / Structure above the Object Inspector at
    the right, Messages and the debugger's views under the editor }
  FDock := TSdDock.Create(Self);
  Screen.OnActiveControlChange := ActiveControlChange;
  FDock.Parent := DockSite;
  FDock.Align := alClient;
  FDock.Images := Icons;               // the views' tab icons, of the icon set shown

  FDock.AutoDragDocking := EnvOptions.AutoDragDocking;
  FDock.Center := CenterPanel;
  UIEmptyPicture(CenterPanel, 'BACKDROP', 420, 30);
  { the row of the file tabs above the pages, shown with the first page: before the tabs the tool
    bar of Back and Forward, the file history (Delphi 7 has them at the end of the row, where they
    stood next to the tabs' scroll arrows), after them the drop-down of the open files (FilesBar). A host without CS_HREDRAW /
    CS_VREDRAW: a resize repaints what it uncovers only }
  FTabRow := TSdDockHost.Create(Self);
  FTabRow.Visible := False;
  FTabRow.Parent := CenterPanel;
  FTabRow.Align := alTop;
  FPageTabs := TSdFileTabs.Create(Self);
  FPageTabs.Parent := FTabRow;
  FPageTabs.Align := alClient;
  HistoryBar.Parent := FTabRow;
  HistoryBar.Align := alLeft;
  HistoryBar.Visible := True;
  FilesBar.Parent := FTabRow;
  FilesBar.Align := alRight;
  FilesBar.Visible := True;
  FPageTabs.TabStop := False;
  FPageTabs.OnChange := TabsChange;
  FPageTabs.OnMouseDown := TabsMouseDown;
  FPageTabs.OnClose := TabsClose;
  FPageTabs.OnMove := TabsMove;
  { the window of the files' text: one for every page, lying over the slot of the page shown
    (TSciWindow.Follow, SwapPage); hidden while the page shown has no code view up. Delphi's
    editor control as experts find it (SdOtaEditWindow: the edit window's Editor) }
  FEditWindow := TEditControl.CreateShared(Self);
  FEditWindow.Borderless := True;       // the page's views have the frame, around the page bar too
  FEditWindow.Visible := False;
  FEditWindow.Parent := CenterPanel;
  SciFileWindow := FEditWindow;
  { the navigation bar: one for every page as well, lent to the bar of the page shown
    (ArrangePageBar) over a Pascal file's code, as the zoom bar (ZoomBar of SdMain.dfm: the View |
    Zoom commands) after what the view shown puts there }
  FNavBar := TNavigationBar.Create(Self);
  FNavBar.Visible := False;
  FNavBar.Parent := CenterPanel;
  FNavBar.OnGoto := StructGotoLine;
  SdZoom.OnZoomChanged := ZoomViewChanged;
  SdZoom.OnEditorZoom := EditorZoomChanged;
  SdHistory.OnHistoryChanged := HistoryFileChanged;
  LoadWheelZoomKey;
  { the outer bottom area first: it spans the whole width, under the left and right areas; the
    bottom area last: under the editor only }
  FBottomFullArea := FDock.AddArea('BottomFull', deBottom, 150, True);
  FLeftArea := FDock.AddArea('Left', deLeft, 232);
  FRightArea := FDock.AddArea('Right', deRight, 232);
  FBottomArea := FDock.AddArea('Bottom', deBottom, 150);
  { the Code Explorer (Delphi 7's) and the Object TreeView: views made once, the IDE carries out
    what reaches beyond them }
  FCodeExp := TCodeExplorerView.Create(Self);
  FCodeExp.OnParse := ExpParse;
  FCodeExp.OnShowSource := ExpShowSource;
  FCodeExp.OnNew := ExpNew;
  FCodeExp.OnRename := ExpRename;
  FCodeExp.OnViewEditor := ExpViewEditor;
  FCodeExp.OnProperties := ExpProperties;
  FCodeExp.ExpPopup.OnPopup := PaneMenuPopup;
  FCodeExp.Tree.OnMouseDown := PkgTreeMouseDown;
  FExpVersion := -1;
  FObjTree := TObjTreeView.Create(Self);
  FObjTree.OnCommand := ObjTreeCommand;
  FObjTree.OnMenuPopup := PaneMenuPopup;
  FObjTree.Tree.OnMouseDown := PkgTreeMouseDown;
  { its menu's Hide and Help are this form's actions (not linked in its .dfm) }
  FObjTree.pmObjTreeHide.Action := aPaneHide;
  FObjTree.pmObjTreeHelp.Action := aViewHelp;
  FInspector := TObjectInspector.Create(Self);
  WireViewMenu(FInspector.InspPopup, FInspector.MenuActions, ActViewMenu);
  FInspector.aOIViewAll.OnExecute := ActInspView;
  FInspector.aOIViewToggle.OnExecute := ActInspView;
  FInspector.aOIViewNone.OnExecute := ActInspView;
  FInspector.aOIArrangeCategory.OnExecute := ActInspView;
  FInspector.aOIArrangeName.OnExecute := ActInspView;
  FInspector.aOIRevert.OnExecute := ActRevert;
  FInspector.pmInsp13.Action := aPaneHide;
  FInspector.pmInsp14.Action := aViewHelp;
  FProjView := TProjectManagerView.Create(Self);
  FProjView.Group := FGroup;
  FProjView.OnCommand := ActGroup;
  FProjView.OnOpen := ProjViewOpen;
  FProjView.OnMenuPopup := PaneMenuPopup;
  FProjView.Tree.OnMouseDown := PkgTreeMouseDown;
  { its menu's group commands and its tool bar's New are this form's actions (not linked in its
    .dfm: a designer binds "AppBuilder.<action>" to the running IDE's own main form); New keeps
    the caption of Delphi's button }
  FProjView.pmProjG1.Action := ProjectAddNewProjectCommand;
  FProjView.tbPMNew.Action := ProjectAddNewProjectCommand;
  FProjView.tbPMNew.Caption := 'New';
  FProjView.pmProjG2.Action := ProjectAddExistingProjectCommand;
  FProjView.pmProjG10.Action := ProjectCompileAllCommand;
  FProjView.pmProjG11.Action := ProjectBuildAllCommand;
  FProjPanel := FDock.AddPanel(FProjView, 'ProjectManager', 'Project Manager', FRightArea, 200);
  FProjPanel.ToolBar := FProjView.Bar;
  FProjPanel.TabText := 'Project';
  FProjPanel.FocusControl := FProjView.Tree;
  FProjView.Panel := FProjPanel;
  FObjTreePanel := FDock.AddTab(FObjTree, 'ObjectTreeView', 'Object TreeView', FProjPanel);
  FObjTreePanel.FocusControl := FObjTree.Tree;
  { an arrangement saved with the Structure view of before: the Object TreeView in its place }
  FObjTreePanel.FormerName := 'Structure';
  FInspPanel := FDock.AddPanel(FInspector, 'ObjectInspector', 'Object Inspector', FRightArea);
  { the Components view (after Component Bar) in place of Delphi's component palette }
  FCompBar := TSdComponentBar.Create(Self);
  WireViewMenu(FCompBar.CompPopup, FCompBar.MenuActions, ActViewMenu);
  FCompBar.pmComp5.Action := ComponentPaletteCommand;
  FCompBar.OnAdd := CompBarAdd;
  FCompBar.OnChoose := ViewDblClick;
  FCompBar.OnCanDrop := CompBarCanDrop;
  FCompBar.OnDrop := CompBarDrop;
  { Delphi's palette as experts reach it (AppBuilder's TabControl and Palette): hidden, filled
    with the palette the Components view shows; a tool an expert chooses there is placed by the
    next click on the designed form }
  FIdePalette := TSdIdePalette.Create(Self);
  { the experts' dockable windows (designide's TDockableForm) become views of the dock: floating
    when first shown, docked as the user docks them; an expert that shows its window or brings it
    to the front gives its view the keyboard, as a View command does }
  FExpertViews := TSdExpertViews.Create(Self, FDock, FRightArea, ViewDockPanel);
  ExpertFormHook := FExpertViews.Adopt;
  ExpertDropHook := FExpertViews.DropModule;
  PaletteToolHook := PaletteToolClick;
  { the Code Explorer above the Components view: left of the editor, where Delphi 7 docks it }
  FCodeExpPanel := FDock.AddPanel(FCodeExp, 'CodeExplorer', 'Code Explorer', FLeftArea);
  FCodeExpPanel.FocusControl := FCodeExp.Tree;
  FCodeExpPanel.TabText := 'Code Explorer';
  FCompPanel := FDock.AddPanel(FCompBar, 'Components', 'Components', FLeftArea);
  { a click on their captions focuses the grid and the list (not the first box of the view) }
  FInspPanel.FocusControl := FInspector.Grid;
  FCompPanel.FocusControl := FCompBar.List;
  FCompBar.List.PopupMenu := FCompBar.CompPopup;
  FCompPanel.PopupMenu := FCompBar.CompPopup;
  ApplyCompBarOptions;
  FCompBar.Used.CommaText := Settings.ReadString(CompSection, 'Used', '');
  FInspector.Grid.Split := Settings.ReadInteger('Layout', 'InspectorSplit', FInspector.Grid.SplitWanted);
  { its View and Arrange, under the names of Delphi's desktop }
  FInspector.Grid.HiddenCategories := Settings.ReadString(InspSection, 'HiddenCategories', '');
  FInspector.Grid.ByCategory := SameText(Settings.ReadString(InspSection, 'ArrangeBy', ArrangeNames[False]),
    ArrangeNames[True]);
  { the Project Manager's status line: the chosen item's file (Delphi 7's Status Bar, on at first) }
  FProjPanel.ShowStatus := Settings.ReadBool('Layout', 'ProjectStatusBar', True);
  { Messages: Build and the experts' message groups, their tabs below (SdMessageView) }
  FMsgView := TSdMessageView.Create(Self);
  FMsgView.Parent := DockSite;
  FMsgView.Attach(MessageList);
  FBottomPanels[BT_MESSAGES] := FDock.AddPanel(FMsgView, 'Messages', 'Messages', FBottomArea);
  FBottomPanels[BT_MESSAGES].FocusControl := MessageList;
  { the Error List: Error Insight's errors of the file shown, the tab beside Messages, with its menu }
  FBottomPanels[BT_ERRORS] := FDock.AddTab(ErrorList, 'ErrorList', 'Error List', FBottomPanels[BT_MESSAGES]);
  { Search Results: a form of its own with the Messages view's menu (its commands act on either view) }
  FSearchView := TSearchResultsView.Create(Self);
  FSearchView.OnOpen := SearchOpen;
  FSearchView.SearchList.PopupMenu := MsgPopup;
  FBottomPanels[BT_SEARCH] := FDock.AddTab(FSearchView, 'SearchResults', 'Search Results', FBottomPanels[BT_MESSAGES]);
  { Breakpoints: a form of its own; its menus' Add items are Run | Add Breakpoint's commands }
  FBreakView := TBreakpointsView.Create(Self);
  FBreakView.Debug := FDebug;
  FBreakView.OnMenuPopup := PaneMenuPopup;
  FBreakView.pmBreak2.Action := RunAddSourceBreakpointCommand;
  FBreakView.pmBreak3.Action := RunAddAddressBreakpointCommand;
  FBreakView.pmBreak4.Action := RunAddDataBreakpointCommand;
  FBreakView.pmBreakItem11.Action := RunAddSourceBreakpointCommand;
  FBreakView.pmBreakItem12.Action := RunAddAddressBreakpointCommand;
  FBreakView.pmBreakItem13.Action := RunAddDataBreakpointCommand;
  FBottomPanels[BT_BREAKS] := FDock.AddTab(FBreakView, 'Breakpoints', 'Breakpoints', FBottomPanels[BT_MESSAGES]);
  FBottomPanels[BT_STACK] := FDock.AddTab(CallStackList, 'CallStack', 'Call Stack', FBottomPanels[BT_MESSAGES]);
  { Delphi's Watch List: WatchTree in two columns with a header, the groups as tabs below it;
    Show Column Headers and the first column's width are kept in [Layout] }
  FWatchView := TSdWatchView.Create(Self);
  WireViewMenu(FWatchView.WatchPopup, FWatchView.MenuActions, ActViewMenu);
  FWatchView.aWatchNew.OnExecute := ActRun;
  FWatchView.aWatchDelete.OnExecute := ActRun;
  PlaceView(FWatchView, FWatchView.WatchPopup);
  FWatchView.Tree.PopupMenu := FWatchView.WatchPopup;
  FWatchView.Tree.OnDblClick := ViewDblClick;
  FWatchView.ShowHeaders := Settings.ReadBool('Layout', 'WatchShowColumnHeaders', True);
  FWatchView.ColumnWidth := Settings.ReadInteger('Layout', 'WatchColumnWidth', 100);
  FBottomPanels[BT_WATCHES] := FDock.AddTab(FWatchView, 'Watches', 'Watches', FBottomPanels[BT_MESSAGES]);
  FBottomPanels[BT_WATCHES].FocusControl := WatchTree;
  FBottomPanels[BT_LOCALS] := FDock.AddTab(LocalsTree, 'LocalVariables', 'Local Variables', FBottomPanels[BT_MESSAGES]);
  FBottomPanels[BT_LOG] := FDock.AddTab(EventLogList, 'EventLog', 'Event Log', FBottomPanels[BT_MESSAGES]);
  { the To-Do List: its sort order, filters and options (Delphi's, kept in [ToDo List]) }
  FTodo := TSdTodoList.Create;
  FTodo.Load(Settings);
  FTodoHost := TTodoMainHost.Create;
  TTodoMainHost(FTodoHost).FMain := Self;
  FTodoView := TTodoListView.Create(Self);
  FTodoView.Todo := FTodo;
  FTodoView.Host := FTodoHost;
  FTodoView.OnMenuPopup := PaneMenuPopup;
  FBottomPanels[BT_TODO] := FDock.AddTab(FTodoView, 'ToDoList', 'To-Do List', FBottomPanels[BT_MESSAGES]);
  { View | Debug Windows: Delphi's Thread Status, Modules, CPU and FPU, tabs of the bottom group
    hidden until shown }
  FCpuView := TSdCpuView.Create(Self);
  FCpuView.Parent := DockSite;
  FCpuView.OnSourceText := SourceLineText;
  FCpuView.OnGotoAddress := CpuGotoAddress;
  FCpuView.OnBreakpointAt := CpuBreakpointAt;
  FpuList.DoubleBuffered := True;                 // refilled at every stop
  FDebugInsp := TSdInspectorView.Create(Self);
  WireViewMenu(FDebugInsp.DebugInspPopup, FDebugInsp.MenuActions, ActDebugInsp);
  FDebugInsp.Parent := DockSite;
  FDebugInsp.OnDescend := ViewDblClick;
  ApplyFixedFont;                      // the debugger's views exist now (their lists of the .dfm too)
  FMachinePanels[0] := FDock.AddTab(ThreadList, 'Threads', 'Thread Status', FBottomPanels[BT_MESSAGES]);
  FMachinePanels[1] := FDock.AddTab(ModuleList, 'Modules', 'Modules', FBottomPanels[BT_MESSAGES]);
  FMachinePanels[2] := FDock.AddTab(FCpuView, 'CPU', 'CPU', FBottomPanels[BT_MESSAGES]);
  FMachinePanels[3] := FDock.AddTab(FpuList, 'FPU', 'FPU', FBottomPanels[BT_MESSAGES]);
  { Delphi's inspector is a tall, narrow window: a tab of the Components view's group }
  FMachinePanels[4] := FDock.AddTab(FDebugInsp, 'DebugInspector', 'Debug Inspector', FCompPanel);
  FDebugInsp.PopupMenu := FDebugInsp.DebugInspPopup;
  FMachinePanels[4].PopupMenu := FDebugInsp.DebugInspPopup;
  { View | Additional Message Info: Delphi's Message Hints, a tab of the bottom group }
  FMsgHints := TSdMessageHints.Create(MsgHintsList);
  FMsgHints.FontChanged;
  FMsgHintsPanel := FDock.AddTab(MsgHintsList, 'MessageHints', 'Message Hints', FBottomPanels[BT_MESSAGES]);
  FMsgHintsPanel.PopupMenu := MsgHintsPopup;
  FDock.HidePanel(FMsgHintsPanel);
  { View | Browser: Delphi's project browser, a tab of the bottom group (wide: its two sides
    lie side by side) }
  FBrowser := TSdBrowser.Create(Self);
  WireViewMenu(FBrowser.BrowserPopup, FBrowser.MenuActions, ActBrowser);
  PlaceView(FBrowser, FBrowser.BrowserPopup);
  FBrowser.SymList.SmallImages := Icons;
  FBrowser.ClassTree.Images := Icons;
  FBrowser.DetailTree.Images := Icons;
  FBrowser.DetailList.SmallImages := Icons;
  FBrowser.CodeInsight := FCodeInsight;
  FBrowser.AllUnits := EnvOptions.ExBrowserScope = 1;
  FBrowser.View := BrowserViewOf(EnvOptions.ExBrowserView);
  FBrowser.OnGetFiles := BrowserFiles;
  FBrowser.OnGoto := BrowserGoto;
  FBrowser.OnChoose := ViewDblClick;
  FBrowserPanel := FDock.AddTab(FBrowser, 'Browser', 'Browser', FBottomPanels[BT_MESSAGES]);
  FBrowserPanel.PopupMenu := FBrowser.BrowserPopup;
  FDock.HidePanel(FBrowserPanel);
  { View | Type Library: a type library to read, a tab of the bottom group as well }
  FTypeLibView := TSdTypeLibView.Create(Self);
  WireViewMenu(FTypeLibView.TypeLibPopup, FTypeLibView.MenuActions, ActTypeLib);
  PlaceView(FTypeLibView, FTypeLibView.TypeLibPopup);
  FTypeLibView.LibTree.Images := Icons;
  FTypeLibPanel := FDock.AddTab(FTypeLibView, 'TypeLibrary', 'Type Library', FBottomPanels[BT_MESSAGES]);
  FTypeLibPanel.PopupMenu := FTypeLibView.TypeLibPopup;
  FDock.HidePanel(FTypeLibPanel);
  { Delphi's package editors: one view for each open package (NewPackageView), the first made now
    for the arrangement to place }
  FPkgViews := TList.Create;
  FPkgStatus := Settings.ReadBool('Layout', 'PackageStatusBar', True);
  NewPackageView('PackageEditor');
  { the Resources view: a tab of Project Manager's group, hidden until
    View | Resources; its status line shows the chosen resource or the file }
  FResView := TSdResourceView.Create(Self);
  WireViewMenu(FResView.ResPopup, FResView.MenuActions, ActResources);
  FResView.ResAddMenu.Images := Icons;           // the Add button's drop-down (ActResources)
  PlaceView(FResView, FResView.ResPopup);
  FResView.Tree.Images := Icons;
  FResView.Tree.PopupMenu := FResView.ResPopup;
  FResView.Tree.OnChange := ResTreeChange;
  FResView.Tree.OnDblClick := ResTreeDblClick;
  FResView.Tree.OnKeyDown := ResTreeKeyDown;
  FResView.Tree.OnMouseDown := PkgTreeMouseDown;
  FResView.Bar.Images := Icons;
  FResView.tbResAdd.Action := aResAdd;
  FResView.tbResEdit.Action := FResView.aResEdit;
  FResView.tbResDelete.Action := FResView.aResDelete;
  FResView.tbResExport.Action := FResView.aResExport;
  FResView.ColumnWidth := Settings.ReadInteger('Layout', 'ResourceColumnWidth', FResView.ColumnWidth);
  FResPanel := FDock.AddTab(FResView, 'Resources', 'Resources', FProjPanel);
  FResPanel.ToolBar := FResView.Bar;
  FResPanel.PopupMenu := FResView.ResPopup;
  FResPanel.FocusControl := ResTree;
  FResPanel.ShowStatus := Settings.ReadBool('Layout', 'ResourceStatusBar', True);
  FDock.HidePanel(FResPanel);
  for I := 0 to High(FMachinePanels) do FDock.HidePanel(FMachinePanels[I]);
  FDock.OnPanelShow := DockPanelShow;
  FDock.OnPanelHide := DockPanelHide;
  { Delphi 7's code editor menu names some commands of the main menu its own way: an action of its
    own each, which does the command and takes its state }
  AddTwins([aEdClosePage, FileCloseCommand, aEdCut, EditCutCommand, aEdCopy, EditCopyCommand,
    aEdPaste, EditPasteCommand, aEdToggleBreak, aToggleBreak, aEdRunToCursor, RunGotoCursorCommand,
    aEdEvaluate, RunEvalModCommand, aEdAddWatch, RunAddWatchCommand, aEdViewCPU, DebugCPUCommand, aEdProperties, ToolsEditorOptionsCommand, aViewAsForm, ViewSwapSourceFormCommand]);
  { every view has the local menu of Delphi 7's window, also on its caption and its tab }
  FProjPanel.PopupMenu := FProjView.ProjPopup;
  FCodeExpPanel.PopupMenu := FCodeExp.ExpPopup;
  FObjTreePanel.PopupMenu := FObjTree.ObjTreePopup;
  FInspPanel.PopupMenu := FInspector.InspPopup;
  FInspector.PopupMenu := FInspector.InspPopup;
  FBottomPanels[BT_MESSAGES].PopupMenu := MsgPopup;
  FBottomPanels[BT_ERRORS].PopupMenu := MsgPopup;
  FBottomPanels[BT_SEARCH].PopupMenu := MsgPopup;
  FBottomPanels[BT_BREAKS].PopupMenu := FBreakView.BreakPopup;
  FBottomPanels[BT_STACK].PopupMenu := StackPopup;
  FBottomPanels[BT_WATCHES].PopupMenu := FWatchView.WatchPopup;
  FBottomPanels[BT_LOCALS].PopupMenu := LocalsPopup;
  FBottomPanels[BT_LOG].PopupMenu := LogPopup;
  FBottomPanels[BT_TODO].PopupMenu := FTodoView.TodoPopup;
  AddDockItems([FProjView.ProjPopup, FCodeExp.ExpPopup, FObjTree.ObjTreePopup, FInspector.InspPopup, FCompBar.CompPopup, FWatchView.WatchPopup, FDebugInsp.DebugInspPopup,
    MsgHintsPopup, FBrowser.BrowserPopup, FTypeLibView.TypeLibPopup, FResView.ResPopup, MsgPopup, FBreakView.BreakPopup,
    FBreakView.BreakItemPopup, StackPopup, LocalsPopup, LogPopup, FTodoView.TodoPopup, DockPopup]);
  { a view without a menu of its own - an expert's, made later too - has the dock's commands alone
    on its caption, its tab and its auto-hide tab (TSdDock.CaptionMenu) }
  FDock.CaptionMenu := DockPopup;
  { messages, search results and the views of the debugger }
  FDebug.AttachViews(CallStackList, LocalsTree, FWatchView, FBreakView.BreakList, EventLogList);
  FDebug.AttachMachineViews(ThreadList, ModuleList, FCpuView, FpuList, FDebugInsp);
  { Automatically show Explorer: the Code Explorer of an arrangement that does not name it (the
    first start, one saved before it was there) }
  if not EnvOptions.ExAutoShow then FDock.HidePanel(FCodeExpPanel);
  LoadArrangement(StartArrangement);
  LoadBands;
  { the tool bars' host: a flat line under its bands and 2 px of padding below the line }
  { the tool row on the menu bar's ground (UIBarColor), under Windows' line below the bar }
  ToolRow.Color := UIBarColor;
  MainBar.Color := UIBarColor;
  UIBottomBorder(ToolRow, 2, 2);
end;

{ The menu is the form's (MainMenu). Under it one row, ToolRow: the tool bar MainBar with the
  buttons of Delphi's Standard, View, Debug and Custom bars, a separator where one bar ended,
  last the Desktops button (it opens the Desktops dialog); nothing moves, it is always shown.
  [ToolbarButtons] keeps its actions (Customize). Without them the .dfm's buttons are the first
  ones. }

{ the windows of the floating views appear after the main window (UIShowPainted), not before it }
procedure TMainForm.ShowFloatingViews;
begin
  FDock.FloatsShown := True;
end;

{ the views a dock arrangement names (Group<i>=area,size,active,view,-hidden view,...) }
procedure TMainForm.ArrangementNames(const Section: string; Names: TStrings);
var
  F: TStringList;
  I, K: Integer;
  S: string;
begin
  Names.Clear;
  F := TStringList.Create;
  try
    for I := 1 to Settings.ReadInteger(Section, 'Groups', 0) do
    begin
      F.CommaText := Settings.ReadString(Section, 'Group' + IntToStr(I), '');
      for K := 3 to F.Count - 1 do
      begin
        S := F[K];
        if Copy(S, 1, 1) = '-' then Delete(S, 1, 1);
        Names.Add(S);
      end;
    end;
  finally
    F.Free;
  end;
end;

{ An arrangement of the dock applied (Section of Settings: [Panes], a desktop). The experts' views it
  names keep their places in it also while their experts have not made their forms: a view without
  a form for each (TSdExpertViews.Reserve), which the dock places and saves again. Once the experts
  of the start have loaded, the forms of the experts' views it shows are made as Delphi's desktop
  makes them (TSdExpertViews.MakeForms). The package editors it names are made for it too
  (ReservePackageViews). }
procedure TMainForm.LoadArrangement(const Section: string);
var
  Names: TStringList;
begin
  Names := TStringList.Create;
  try
    ArrangementNames(Section, Names);
    FExpertViews.Reserve(Names);
    ReservePackageViews(Names);
    FDock.Load(Settings, Section);
    FExpertViews.Placed(Names);
    if FExpertsLoaded then FExpertViews.MakeForms;
  finally
    Names.Free;
  end;
end;

{ The arrangement at start: with Autosave Desktop the one the IDE closed with ([Panes]); without
  it the chosen desktop - the one saved or loaded last -, else [Panes] as it was saved last }
function TMainForm.StartArrangement: string;
var
  S: string;
begin
  S := Settings.ReadString('Desktops', '.Current', '');
  if not EnvOptions.AutosaveDesktop and (S <> '') and Settings.ValueExists('Desktops', S) then
    Result := 'Desktop:' + S
  else
    Result := PaneSection;
end;

{ The experts loaded while D7 Studio starts (D7Studio.dpr, after LoadDeferredPackages) made their
  windows after the arrangement was applied (FormCreate): it is applied again for their views, and
  the ones it names keep their places; the others float when they are first shown. The windows it
  shows that their experts have not made are made now }
procedure TMainForm.ExpertsLoaded;
begin
  FExpertsLoaded := True;
  if FExpertViews.Count > 0 then LoadArrangement(StartArrangement);
end;

{ The names the main form's actions had before they took Delphi 7's (experts find the IDE's
  commands by Delphi's names): a tool bar kept with them
  ([ToolbarButtons]) is read with today's }
const
  RenamedActions: array[0..130] of array[0..1] of string = (
    ('aNewApp', 'FileNewVclApplicationCommand'), ('aNewDataModule', 'FileNewVclDataModuleCommand'),
    ('aNewForm', 'FileNewVclFormCommand'), ('aNewFrame', 'FileNewVclFrameCommand'),
    ('aNewUnit', 'FileNewUnitCommand'), ('aNewOther', 'FileNewCommand'),
    ('aOpen', 'FileOpenCommand'), ('aOpenProject', 'FileOpenProjectCommand'),
    ('aSave', 'FileSaveCommand'), ('aSaveAs', 'FileSaveAsCommand'),
    ('aSaveProjectAs', 'FileSaveProjectAsCommand'), ('aSaveAll', 'FileSaveAllCommand'),
    ('aClose', 'FileCloseCommand'), ('aCloseAll', 'FileCloseAllCommand'),
    ('aUseUnit', 'FileUseUnitCommand'), ('aPrint', 'FilePrintCommand'),
    ('aExit', 'FileExitCommand'), ('aUndo', 'EditUndoCommand'), ('aRedo', 'EditRedoCommand'),
    ('aCut', 'EditCutCommand'), ('aCopy', 'EditCopyCommand'), ('aPaste', 'EditPasteCommand'),
    ('aDelete', 'EditDeleteCommand'), ('aSelectAll', 'EditSelectAllCommand'),
    ('aAlignGrid', 'EditAlignGridCommand'), ('aBringFront', 'EditFrontCommand'),
    ('aSendBack', 'EditBackCommand'), ('aAlignDlg', 'EditAlignCommand'),
    ('aSizeDlg', 'EditSizeCommand'), ('aScaleDlg', 'EditScaleCommand'),
    ('aTabOrder', 'EditTabOrderCommand'), ('aCreationOrder', 'EditCreationOrderCommand'),
    ('aFlipAll', 'EditFlipChildrenAllCommand'),
    ('aFlipSelected', 'EditFlipChildrenSelectedCommand'), ('aLock', 'EditLockControlsCommand'),
    ('aFind', 'SearchFindCommand'), ('aFindInFiles', 'SearchFileFindCommand'),
    ('aReplace', 'SearchReplaceCommand'), ('aSearchAgain', 'SearchAgainCommand'),
    ('aIncSearch', 'SearchIncrementalCommand'), ('aGotoLine', 'SearchGoToCommand'),
    ('aFindError', 'SearchFindErrCommand'), ('aBrowseSymbol', 'SearchSymbolCommand'),
    ('aViewProject', 'ViewPrjMgrCommand'), ('aViewInspector', 'ViewObjInspCommand'),
    ('aViewStructure', 'ViewObjTreeViewCommand'), ('aViewTodo', 'ViewToDoListCommand'),
    ('aViewBrowser', 'ViewBrowserCommand'),
    ('aViewCodeExplorer', 'ViewCodeExplorerCommand'), ('aViewCompList', 'ViewCompListCommand'),
    ('aViewWindowList', 'ViewWindowListCommand'), ('aViewMsgInfo', 'ViewAddlMsgInfoCommand'),
    ('aViewBreaks', 'DebugBreakPointsCommand'), ('aViewStack', 'DebugCallStackCommand'),
    ('aViewWatches', 'DebugWatchesCommand'), ('aViewLocals', 'DebugLocalVariablesCommand'),
    ('aViewThreads', 'DebugThreadsCommand'), ('aViewModules', 'DebugModulesCommand'),
    ('aViewLog', 'DebugEventLogCommand'), ('aViewCPU', 'DebugCPUCommand'),
    ('aViewFPU', 'DebugFPUCommand'), ('aSaveDesktop', 'ViewSaveDesktopCommand'),
    ('aDeleteDesktop', 'ViewDeleteDesktopCommand'), ('aDebugDesktop', 'ViewRuntimeDesktopCommand'),
    ('aToggleForm', 'ViewToggleFormCommand'), ('aViewUnits', 'ViewUnitCommand'),
    ('aViewForms', 'ViewFormCommand'), ('aViewTypeLib', 'ViewTypeLibraryCommand'),
    ('aNextWindow', 'ViewNextWindow'), ('aAddToProject', 'ProjectAddCommand'),
    ('aRemoveFromProject', 'ProjectRemoveCommand'),
    ('aImportTypeLib', 'ProjectImportTypeLibraryCommand'),
    ('aAddToRepository', 'ProjectAddRepositoryCommand'),
    ('aViewSource', 'ProjectViewSourceCommand'), ('aAddNewProject', 'ProjectAddNewProjectCommand'),
    ('aAddExistingProject', 'ProjectAddExistingProjectCommand'),
    ('aCompile', 'ProjectCompileCommand'), ('aBuild', 'ProjectBuildCommand'),
    ('aSyntax', 'ProjectSyntaxCommand'), ('aProjInfo', 'ProjectInformationCommand'),
    ('aCompileAll', 'ProjectCompileAllCommand'), ('aBuildAll', 'ProjectBuildAllCommand'),
    ('aProjOptions', 'ProjectOptionsCommand'), ('aRun', 'RunRunCommand'),
    ('aRunNoDebug', 'RunRunNoDebugCommand'), ('aAttach', 'RunAttachCommand'),
    ('aParamsDlg', 'RunParametersCommand'), ('aRegisterCom', 'RunRegisterComCommand'),
    ('aUnregisterCom', 'RunUnregisterComCommand'), ('aStepOver', 'RunStepOverCommand'),
    ('aTraceInto', 'RunTraceIntoCommand'), ('aTraceToSource', 'RunTraceToSourceCommand'),
    ('aRunToCursor', 'RunGotoCursorCommand'), ('aStepOut', 'RunUntilReturnCommand'),
    ('aShowExecPoint', 'RunShowCSIPCommand'), ('aPause', 'RunPauseCommand'),
    ('aReset', 'RunResetCommand'), ('aDetach', 'RunDetachCommand'),
    ('aInspect', 'RunInspectCommand'), ('aEvaluate', 'RunEvalModCommand'),
    ('aAddWatch', 'RunAddWatchCommand'), ('aSourceBP', 'RunAddSourceBreakpointCommand'),
    ('aAddressBP', 'RunAddAddressBreakpointCommand'), ('aDataBP', 'RunAddDataBreakpointCommand'),
    ('aModuleBP', 'RunAddModuleLoadBreakpointCommand'), ('aNewComponent', 'ComponentNewCommand'),
    ('aInstallComponent', 'ComponentAddtoPackageCommand'),
    ('aImportAX', 'ComponentImportAXCCommand'),
    ('aCompTemplate', 'ComponentInstallCompositeCommand'),
    ('aPackages', 'ComponentInstallPackagesCommand'), ('aConfigPalette', 'ComponentPaletteCommand'),
    ('aEnvOptions', 'ToolsOptionsCommand'), ('aEditorOptions', 'ToolsEditorOptionsCommand'),
    ('aDebuggerOptions', 'ToolsDebuggerOptionsCommand'), ('aRepository', 'ToolsGalleryCommand'),
    ('aConfigTools', 'ToolsToolsCommand'), ('aHelpContents', 'HelpContentsCommand'),
    ('aHelpTools', 'HelpDelphiToolsCommand'), ('aHelpWinSDK', 'HelpWinSDKCommand'),
    ('aAbout', 'HelpAboutCommand'), ('aDsnViewAsText', 'ViewSwapSourceFormCommand'),
    ('aTbCustomize', 'ViewCustomizeCommand'), ('aHelpVclRef', 'HelpVclRefCommand'),
    ('aAddTodo', 'EditAddToDoItemCommand'), ('aCompleteClass', 'ecCompleteClass'),
    ('aDsnAlignGrid', 'EditAlignGridCommand'), ('aDsnBringFront', 'EditFrontCommand'),
    ('aDsnSendBack', 'EditBackCommand'), ('aDsnCreationOrder', 'EditCreationOrderCommand'),
    ('aDiagZoomIn', 'aZoomIn'), ('aDiagZoomOut', 'aZoomOut'));

function CurrentActionNames(const Buttons: string): string;
var
  L: TStringList;
  I, K: Integer;
begin
  L := TStringList.Create;
  try
    L.CommaText := Buttons;
    for I := 0 to L.Count - 1 do
      for K := Low(RenamedActions) to High(RenamedActions) do
        if L[I] = RenamedActions[K, 0] then
        begin
          L[I] := RenamedActions[K, 1];
          Break;
        end;
    Result := L.CommaText;
  finally
    L.Free;
  end;
end;
procedure TMainForm.LoadBands;
var
  S: string;
begin
  { Customize | Reset: the bar as the .dfm has it }
  if FDefaultButtons = '' then FDefaultButtons := ToolbarButtonsText(MainBar);
  S := Settings.ReadString('ToolbarButtons', MainBar.Name, '');
  S := CurrentActionNames(S);
  { a list as the .dfm has it is no customization: the bar follows the .dfm, also its changes }
  if (S <> '') and (S = FDefaultButtons) then
  begin
    Settings.DeleteKey('ToolbarButtons', MainBar.Name);
    S := '';
  end;
  if S <> '' then
  begin
    FreezeToolRow(True);
    try
      FillToolbar(MainBar, S);
    finally
      FreezeToolRow(False);
    end;
    { stored again as the bar shows it (the desktop combo box was once stored as a '-'): a list
      that is the .dfm's after all goes }
    StoreToolbarButtons(MainBar);
  end;
  FBarTooltips := Settings.ReadBool(ToolbarSection, 'ShowTooltips', True);
  FBarShortcuts := Settings.ReadBool(ToolbarSection, 'ShowShortcuts', True);
  ApplyBarHints;
end;

{ The tool row while its bars change (Freeze True ... False): nothing is drawn meanwhile - the
  VCL makes every button of a bar again for each one it gets or loses -, then the row is drawn
  once }
procedure TMainForm.FreezeToolRow(Freeze: Boolean);
begin
  UIFreezeRedraw(ToolRow, Freeze);
end;

{ where a button goes at the end of a bar }
function BarEnd(Bar: TToolBar): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Bar.ControlCount - 1 do
    if Bar.Controls[I].BoundsRect.Right > Result then Result := Bar.Controls[I].BoundsRect.Right;
end;

{ one button of a bar before the button at X (at BarEnd: the last): Item an action's name or '-'
  (a separator); Open and Run get their drop-down menus as in Delphi, Desktops the list of the
  saved desktops. nil: no such action }
function TMainForm.NewToolButton(Bar: TToolBar; const Item: string; X: Integer): TToolButton;
var
  A: TComponent;
begin
  Result := nil;
  A := nil;
  if Item <> '-' then
  begin
    A := FindComponent(Item);
    if not (A is TAction) then Exit;
  end;
  Result := TToolButton.Create(Self);
  if A = nil then
  begin
    Result.Style := tbsSeparator;
    Result.Width := 8;
  end
  else
  begin
    Result.Action := TAction(A);
    if A = FileOpenCommand then Result.DropdownMenu := ClosedFilesPopup
    else if A = RunRunCommand then Result.DropdownMenu := ProcessMenu
    else if A = aDesktops then Result.DropdownMenu := DesktopsMenu;
    if Result.DropdownMenu <> nil then Result.Style := tbsDropDown;
  end;
  Result.Left := X;
  Result.Parent := Bar;
end;

{ the buttons of a tool bar from a list of action names ('-' a separator) }
procedure TMainForm.FillToolbar(Bar: TToolBar; const Buttons: string);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.CommaText := Buttons;
    for I := Bar.ControlCount - 1 downto 0 do
      if Bar.Controls[I] is TToolButton then Bar.Controls[I].Free;
    for I := 0 to L.Count - 1 do NewToolButton(Bar, L[I], BarEnd(Bar));
  finally
    L.Free;
  end;
end;

{ --- View | Toolbars | Customize --- }

{ the buttons of a bar from left to right (separators too; not other controls on it). From
  Controls: Buttons lists every control, and as Buttons[I] is declared a TToolButton, the
  compiler makes "Buttons[I] is TToolButton" a test for nil - the Desktop bar's combo box passed,
  counted as a button by the drops and stored as a separator }
function TMainForm.ToolbarButtons(Bar: TToolBar): TList;
var
  I, K: Integer;
  C: TControl;
begin
  Result := TList.Create;
  for I := 0 to Bar.ControlCount - 1 do
  begin
    C := Bar.Controls[I];
    if not (C is TToolButton) then Continue;
    K := 0;
    while (K < Result.Count) and (TToolButton(Result[K]).Left <= C.Left) do Inc(K);
    Result.Insert(K, C);
  end;
end;

{ ... as [ToolbarButtons] keeps them: the actions' names, '-' a separator }
function TMainForm.ToolbarButtonsText(Bar: TToolBar): string;
var
  L: TList;
  S: TStringList;
  I: Integer;
  B: TToolButton;
begin
  L := ToolbarButtons(Bar);
  S := TStringList.Create;
  try
    for I := 0 to L.Count - 1 do
    begin
      B := TToolButton(L[I]);
      if (B.Style = tbsSeparator) or (B.Action = nil) then S.Add('-') else S.Add(B.Action.Name);
    end;
    Result := S.CommaText;
  finally
    S.Free;
    L.Free;
  end;
end;

{ a bar keeps the buttons it has now; the .dfm's are not stored: the bar keeps following the
  .dfm (Reset) }
procedure TMainForm.StoreToolbarButtons(Bar: TToolBar);
var
  S: string;
begin
  S := ToolbarButtonsText(Bar);
  if S = FDefaultButtons then Settings.DeleteKey('ToolbarButtons', Bar.Name)
  else Settings.WriteString('ToolbarButtons', Bar.Name, S);
end;

{ the tool bar when a point of the screen is over it (a little beyond its ends as well: there a
  drop goes first or last), and the place among its buttons there }
function TMainForm.BarAt(const ScreenPt: TPoint; out Index: Integer): TToolBar;
var
  R: TRect;
  P: TPoint;
  L: TList;
begin
  Result := nil;
  Index := 0;
  R := MainBar.BoundsRect;
  InflateRect(R, 6, 0);
  OffsetRect(R, ToolRow.ClientOrigin.X, ToolRow.ClientOrigin.Y);
  if not PtInRect(R, ScreenPt) then Exit;
  Result := MainBar;
  P := Result.ScreenToClient(ScreenPt);
  L := ToolbarButtons(Result);
  try
    while (Index < L.Count) and (TToolButton(L[Index]).Left + TToolButton(L[Index]).Width div 2 < P.X) do
      Inc(Index);
  finally
    L.Free;
  end;
end;

{ A command of the Commands page or a button of a bar dropped at a point: onto a bar it goes
  there, a button dropped off the bars is gone (Delphi's way of removing one) }
procedure TMainForm.CustomizeDrop(Sender: TObject; Action: TBasicAction; Source: TToolButton;
  const ScreenPt: TPoint; Drop: Boolean; var Accept: Boolean);
var
  Target, From: TToolBar;
  Index, X: Integer;
  Item: string;
  Btns: TList;
  Before: TToolButton;
begin
  Target := BarAt(ScreenPt, Index);
  if Action = nil then Item := '-' else Item := Action.Name;
  Accept := (Target <> nil) and (Item <> '');
  if not Drop or (Item = '') then Exit;
  if not Accept then Target := nil;          // as off the bars: a button goes, a command not
  if (Source = nil) and (Target = nil) then Exit;
  { the button the new one goes before (nil: the last) }
  Before := nil;
  if Target <> nil then
  begin
    Btns := ToolbarButtons(Target);
    try
      if Index < Btns.Count then Before := TToolButton(Btns[Index]);
      { where it was }
      if (Source <> nil) and ((Before = Source) or ((Index > 0) and (Btns[Index - 1] = Source))) then Exit;
    finally
      Btns.Free;
    end;
  end;
  From := nil;
  if Source <> nil then From := Source.Parent as TToolBar;
  { one button goes, one comes - the rest of the bar stays }
  FreezeToolRow(True);
  try
    Source.Free;
    if Target <> nil then
    begin
      if Before <> nil then X := Before.Left else X := BarEnd(Target);
      NewToolButton(Target, Item, X);
      StoreToolbarButtons(Target);
    end;
    if (From <> nil) and (From <> Target) then StoreToolbarButtons(From);
  finally
    FreezeToolRow(False);
  end;
end;

{ Reset... of the tool bar's menu: its buttons as the .dfm has them, after Delphi's question }
procedure TMainForm.ResetToolbar;
begin
  if MessageBox(Handle, PChar(Format('Reset changes made to the ''%s'' toolbar?', [MainBar.Caption])),
    'Confirm', MB_OKCANCEL or MB_ICONQUESTION) <> IDOK then Exit;
  FreezeToolRow(True);
  try
    FillToolbar(MainBar, FDefaultButtons);
    StoreToolbarButtons(MainBar);
  finally
    FreezeToolRow(False);
  end;
end;

procedure TMainForm.CustomizeOptions(Sender: TObject);
begin
  FBarTooltips := FCustomize.ShowTooltips;
  FBarShortcuts := FCustomize.ShowShortcuts;
  Settings.WriteBool(ToolbarSection, 'ShowTooltips', FBarTooltips);
  Settings.WriteBool(ToolbarSection, 'ShowShortcuts', FBarShortcuts);
  ApplyBarHints;
end;

procedure TMainForm.CustomizeClosed(Sender: TObject);
begin
  FCustomize := nil;
end;

{ Customize | Options: tooltips on the tool bar or none }
procedure TMainForm.ApplyBarHints;
begin
  MainBar.ShowHint := FBarTooltips;
end;

type
  TControlAccess = class(TControl);    // a control's Action (protected in TControl)

{ ... with the shortcut key of a command's control (Customize | Options | Show shortcut keys on
  tooltips) after a tab: the hint window shows it in grey at the right end (SdHints.TSdHintWindow;
  the VCL's own " (F9)" is off, FormCreate) }
{ an Alt that made the wheel zoom (SdZoom: Alt as the zoom key) opens no menu when it is released }
procedure TMainForm.AppMessage(var Msg: TMsg; var Handled: Boolean);
begin
  if (Msg.message = WM_SYSKEYUP) and (Msg.wParam = VK_MENU) and TakeZoomAlt then Handled := True;
end;

procedure TMainForm.AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
var
  C: TControl;
  A: TBasicAction;
  R: TRect;
  S: string;
begin
  C := HintInfo.HintControl;
  { the To-Do List: the whole text of a cell that is cut (Show ToolTips when Clipped) - again
    when the pointer goes to another cell }
  if C = FTodoView.TodoList then
  begin
    CanShow := FTodoView.CellHint(HintInfo.CursorPos, S, R);
    if CanShow then
    begin
      HintStr := S;
      HintInfo.CursorRect := R;
      HintInfo.HintMaxWidth := FTodoView.TodoList.ClientWidth;
    end;
    Exit;
  end;
  if not FBarShortcuts or (C = nil) or (HintStr = '') then Exit;
  A := TControlAccess(C).Action;
  if (A is TCustomAction) and (TCustomAction(A).ShortCut <> 0) then
    HintStr := HintStr + #9 + ShortCutToText(TCustomAction(A).ShortCut);
end;

{ Delphi's Customize stays open beside the IDE. Every command with an icon can go on a bar: by
  the menu of
  the main menu that has it (its items and submenus), the others - the local menus' commands, the
  designer's alignments - by their category }
procedure TMainForm.ShowCustomize;

  function Listed(A: TBasicAction): Boolean;
  begin
    Result := (A is TCustomAction) and (A.Name <> '') and
      (TCustomAction(A).ActionList = ActionList) and (TCustomAction(A).ImageIndex >= 0);
  end;

  procedure AddItems(const Category: string; M: TMenuItem);
  var
    I: Integer;
  begin
    for I := 0 to M.Count - 1 do
    begin
      if Listed(M[I].Action) then FCustomize.AddCommand(Category, TContainedAction(M[I].Action));
      AddItems(Category, M[I]);
    end;
  end;

var
  I: Integer;
  A: TContainedAction;
begin
  if FCustomize = nil then
  begin
    FCustomize := TCustomizeDlg.Create(Self);
    FCustomize.OnClosed := CustomizeClosed;
    FCustomize.Images := Icons;
    FCustomize.AddBar(MainBar);
    for I := 0 to MainMenu.Items.Count - 1 do
      AddItems(CommandCaption(MainMenu.Items[I].Caption), MainMenu.Items[I]);
    for I := 0 to ActionList.ActionCount - 1 do
    begin
      A := ActionList.Actions[I];
      if Listed(A) then
        if A.Category <> '' then FCustomize.AddCommand(A.Category, A) else FCustomize.AddCommand('Other', A);
    end;
    FCustomize.ShowTooltips := FBarTooltips;
    FCustomize.ShowShortcuts := FBarShortcuts;
    FCustomize.OnDrop := CustomizeDrop;
    FCustomize.OnOptions := CustomizeOptions;
    FCustomize.Start;
  end;
  FCustomize.Show;
end;


{ the list of the Messages / Search Results view whose menu is open (Messages by default) - of
  Messages the group shown, Build or an expert's }
function TMainForm.MenuList: TListBox;
begin
  if (FMenuPanel <> nil) and (FMenuPanel.Control = FSearchView) then Result := FSearchView.SearchList
  else if (FMenuPanel <> nil) and (FMenuPanel.Control is TListBox) then Result := TListBox(FMenuPanel.Control)
  else if (FMenuPanel <> nil) and (FMenuPanel.Control = FMsgView) and (FMsgView.ShownList <> nil) then
    Result := FMsgView.ShownList
  else Result := MessageList;
end;

{ the dock's commands at the end of each view's menu, the same in every one (made here, not in
  the menus' .dfm): Dock Left ... Floating, Tabs, Auto Hide, and Close where Delphi's items of the
  menu have no Hide (PaneMenuPopup sets their states); the separator only after items of the view }
procedure TMainForm.AddDockItems(const Menus: array of TPopupMenu);
var
  I, K: Integer;
  M: TPopupMenu;
  Tabs: TMenuItem;
  HasHide: Boolean;

  function NewItem(Parent: TMenuItem; Action: TBasicAction; const ACaption: string; Group: Byte;
    Radio: Boolean): TMenuItem;
  begin
    Result := TMenuItem.Create(M.Owner);
    if Action <> nil then Result.Action := Action else Result.Caption := ACaption;
    Result.GroupIndex := Group;
    Result.RadioItem := Radio;
    Parent.Add(Result);
  end;

begin
  for I := Low(Menus) to High(Menus) do
  begin
    M := Menus[I];
    HasHide := False;
    for K := 0 to M.Items.Count - 1 do
      if M.Items[K].Action = aPaneHide then HasHide := True;
    if M.Items.Count > 0 then NewItem(M.Items, nil, cLineCaption, 0, False);
    NewItem(M.Items, aPaneLeft, '', 0, True);
    NewItem(M.Items, aPaneRight, '', 0, True);
    NewItem(M.Items, aPaneBottom, '', 0, True);
    NewItem(M.Items, aPaneBottomFull, '', 0, True);
    NewItem(M.Items, aPaneFloat, '', 0, True);
    Tabs := NewItem(M.Items, nil, '&Tabs', 0, False);
    NewItem(Tabs, aTabsTop, '', 7, True);
    NewItem(Tabs, aTabsBottom, '', 7, True);
    NewItem(Tabs, aTabsLeft, '', 7, True);
    NewItem(Tabs, aTabsRight, '', 7, True);
    NewItem(M.Items, aAutoHide, '', 0, False);
    if not HasHide then NewItem(M.Items, aPaneClose, '', 0, False);
  end;
end;

{ a view's menu and the actions only it has, in the view's unit (its .dfm): carried out here -
  Handler for every action (a few have another one, set after the call) -, with the IDE's icons,
  the views' OnPopup (PaneMenuPopup) and drawn as every menu (the .dfm links nothing of this form:
  a designer would bind "AppBuilder.<x>" to the running IDE's own main form) }
procedure TMainForm.WireViewMenu(Menu: TPopupMenu; Actions: TActionList; Handler: TNotifyEvent);
var
  I: Integer;
begin
  Menu.Images := Icons;
  Menu.OnPopup := PaneMenuPopup;
  Actions.Images := Icons;
  for I := 0 to Actions.ActionCount - 1 do Actions.Actions[I].OnExecute := Handler;
  UIOwnerDrawMenus(Menu.Owner);
end;

{ The local menu of a view (Delphi 7's for that window), shown on the view, its caption or its
  tab: on the caption the dock commands are about the whole group, elsewhere about the view.
  The states of the view's commands are set here. }
procedure TMainForm.PaneMenuPopup(Sender: TObject);
var
  C: TComponent;
  L: TListBox;
  W: TWatchItem;
  Dockable: Boolean;
begin
  C := TPopupMenu(Sender).PopupComponent;
  FMenuPanel := FDock.PanelOf(C);
  FMenuGroup := C is TSdDockCaption;
  { by the edge: a column beside an area (side by side) is docked at that edge too }
  aPaneLeft.Checked := (FMenuPanel <> nil) and not FMenuPanel.Group.Floating and
    (FMenuPanel.Group.Area.Edge = FLeftArea.Edge);
  aPaneRight.Checked := (FMenuPanel <> nil) and not FMenuPanel.Group.Floating and
    (FMenuPanel.Group.Area.Edge = FRightArea.Edge);
  aPaneBottom.Checked := (FMenuPanel <> nil) and not FMenuPanel.Group.Floating and
    (FMenuPanel.Group.Area.Edge = FBottomArea.Edge) and not FMenuPanel.Group.Area.Outer;
  aPaneBottomFull.Checked := (FMenuPanel <> nil) and FMenuPanel.Group.Area.Outer and
    (FMenuPanel.Group.Area.Edge = FBottomFullArea.Edge);
  aPaneFloat.Checked := (FMenuPanel <> nil) and FMenuPanel.Group.Floating;
  { a float-only view (TSdDock.SetFloatOnly) stays where it is }
  Dockable := (FMenuPanel = nil) or not FMenuPanel.Group.FloatOnly;
  aPaneLeft.Enabled := Dockable;
  aPaneRight.Enabled := Dockable;
  aPaneBottom.Enabled := Dockable;
  aPaneBottomFull.Enabled := Dockable;
  aPaneFloat.Enabled := Dockable;
  aAutoHide.Enabled := (FMenuPanel <> nil) and not FMenuPanel.Group.Floating;   // no edge to hide at
  aTabsTop.Checked := (FMenuPanel <> nil) and (FMenuPanel.Group.TabSide = tsTop);
  aTabsBottom.Checked := (FMenuPanel <> nil) and (FMenuPanel.Group.TabSide = tsBottom);
  aTabsLeft.Checked := (FMenuPanel <> nil) and (FMenuPanel.Group.TabSide = tsLeft);
  aTabsRight.Checked := (FMenuPanel <> nil) and (FMenuPanel.Group.TabSide = tsRight);
  aAutoHide.Checked := (FMenuPanel <> nil) and FMenuPanel.Group.AutoHide;
  L := MenuList;
  aMsgViewSource.Enabled := L.ItemIndex >= 0;
  aMsgEditSource.Enabled := L.ItemIndex >= 0;
  aMsgClear.Enabled := L.Items.Count > 0;
  aMsgSave.Enabled := L.Items.Count > 0;
  aMsgClearAll.Enabled := (MessageList.Items.Count > 0) or (FSearchView.SearchList.Items.Count > 0);
  aMsgSaveAll.Enabled := aMsgClearAll.Enabled;
  aMsgViewEditor.Enabled := ActivePage <> nil;
  aStackViewSource.Enabled := FDebug.ShownPaused and (CallStackList.ItemIndex >= 0);
  aStackEditSource.Enabled := aStackViewSource.Enabled;
  FWatchView.aWatchCopyValue.Enabled := WatchTree.Selected <> nil;
  FWatchView.aWatchCopyName.Enabled := WatchTree.Selected <> nil;
  FWatchView.aWatchDeleteAll.Enabled := WatchTree.Items.Count > 0;
  { Delphi's Watch List (WatchMenuPopup) }
  W := FDebug.SelectedWatch;
  FWatchView.aWatchEnable.Enabled := (W <> nil) and not W.Enabled;
  FWatchView.aWatchDisable.Enabled := (W <> nil) and W.Enabled;
  FWatchView.aWatchEnableAll.Enabled := FDebug.WatchCount > 0;
  FWatchView.aWatchDisableAll.Enabled := FWatchView.aWatchEnableAll.Enabled;
  FWatchView.aWatchDeleteGroup.Enabled := FDebug.WatchGroupCount > 1;
  FWatchView.aWatchMoveGroup.Enabled := (W <> nil) and (FDebug.WatchGroupCount > 1);
  FWatchView.aWatchBreakChanged.Checked := (W <> nil) and FDebug.WatchBreaks(W);
  FWatchView.aWatchBreakChanged.Enabled := (W <> nil) and (FWatchView.aWatchBreakChanged.Checked or
    (FDebug.Active and (W.Address <> 0) and (W.Size <> 0)));
  FWatchView.aWatchHeaders.Checked := FWatchView.ShowHeaders;
  if TComponent(Sender).Owner is TSdPackageView then SenderPackageView(Sender).aPkgStatusBar.Checked := FPkgStatus;
  FResView.aResStatusBar.Checked := FResPanel.ShowStatus;
  if Sender = FWatchView.WatchPopup then WatchGroupMenu;
  aLogClear.Enabled := EventLogList.Items.Count > 0;
  aLogSave.Enabled := EventLogList.Items.Count > 0;
  FInspector.aOIExpand.Enabled := FInspector.Grid.SelectedRow >= 0;
  FInspector.aOICollapse.Enabled := FInspector.Grid.SelectedRow >= 0;
  if Sender = FInspector.InspPopup then InspViewMenu;
  FCompBar.aCompAdd.Enabled := (FCompBar.SelectedClass <> nil) and (ActiveDesigner <> nil);
  FCompBar.aCompShowCategory.Enabled := FCompBar.SelectedClass <> nil;
  FCompBar.aCompSortName.Checked := FCompBar.SortMode = csName;
  FCompBar.aCompSortRecent.Checked := FCompBar.SortMode = csRecentlyUsed;
  FCompBar.aCompSortMost.Checked := FCompBar.SortMode = csMostUsed;
  FCompBar.aCompSortPalette.Checked := FCompBar.SortMode = csPaletteOrder;
end;


{ the commands of the views' menus that D7 Studio can do (the others are disabled) }
procedure TMainForm.ActViewMenu(Sender: TObject);
var
  L: TListBox;
  All: TStringList;
  S: string;
begin
  L := MenuList;
  if (Sender = aMsgViewSource) or (Sender = aMsgEditSource) then
  begin
    { the list's own double click: a compiler message, a search result, an expert's message }
    if Assigned(L.OnDblClick) then L.OnDblClick(L);
    if (Sender = aMsgViewSource) and L.CanFocus then L.SetFocus;
  end
  else if Sender = aMsgClear then
  begin
    if L = FSearchView.SearchList then ClearSearchResults
    else
    begin
      L.Items.Clear;
      OtaMessageGroupCleared(FMsgView.ListGroup(L));
    end;
  end
  else if Sender = aMsgClearAll then
    ClearMessageViews
  else if Sender = aMsgSave then
    SaveLinesAs('Save Messages', L.Items)
  else if Sender = aMsgSaveAll then
  begin
    All := TStringList.Create;
    try
      All.AddStrings(MessageList.Items);
      All.AddStrings(FSearchView.SearchList.Items);
      SaveLinesAs('Save All Messages', All);
    finally
      All.Free;
    end;
  end
  else if Sender = aMsgViewEditor then
  begin
    if (ActivePage <> nil) and ActivePage.CodeView and ActivePage.Editor.CanFocus then ActivePage.Editor.SetFocus;
  end

  else if (Sender = aStackViewSource) or (Sender = aStackEditSource) then
  begin
    FDebug.ShowStackSource;
    if (Sender = aStackViewSource) and CallStackList.CanFocus then CallStackList.SetFocus;
  end
  else if Sender = FWatchView.aWatchCopyValue then Clipboard.AsText := FDebug.SelectedWatchText(True)
  else if Sender = FWatchView.aWatchCopyName then Clipboard.AsText := FDebug.SelectedWatchText(False)
  else if Sender = FWatchView.aWatchDeleteAll then FDebug.DeleteAllWatches
  { Delphi's Watch List }
  else if Sender = FWatchView.aWatchEdit then FDebug.EditSelectedWatch
  else if (Sender = FWatchView.aWatchEnable) or (Sender = FWatchView.aWatchDisable) then FDebug.EnableSelectedWatches(Sender = FWatchView.aWatchEnable)
  else if (Sender = FWatchView.aWatchEnableAll) or (Sender = FWatchView.aWatchDisableAll) then FDebug.EnableAllWatches(Sender = FWatchView.aWatchEnableAll)
  else if Sender = FWatchView.aWatchAddGroup then
  begin
    { Delphi's Add Watch Group asks again for an empty name }
    S := '';
    repeat
      if not InputDialog(Self, 'Add Watch Group', '&Group Name:', S) then Exit;
      S := Trim(S);
      if S = '' then MessageBox(Handle, 'No group name entered.', 'Error', MB_OK or MB_ICONERROR);
    until S <> '';
    FDebug.AddWatchGroup(S);
  end
  else if Sender = FWatchView.aWatchDeleteGroup then FDebug.DeleteWatchGroup
  else if Sender = FWatchView.aWatchBreakChanged then FDebug.BreakWhenChanged
  else if Sender = FWatchView.aWatchHeaders then FWatchView.ShowHeaders := not FWatchView.ShowHeaders
  { aWatchMoveGroup is the submenu of the groups (WatchGroupMenu) }
  else if Sender = aDsnTextDFM then
  begin
    { the designer's Text DFM: the format the form file is saved in }
    if (ActivePage <> nil) and ActivePage.HasForm then ActivePage.DfmText := not ActivePage.DfmText;
  end
  else if Sender = aMsgCloseTab then
  begin
    { Delphi's Messages window closes the tab of a list; here the list is a view of its own }
    if FMenuPanel <> nil then FDock.HidePanel(FMenuPanel);
  end
  else if Sender = aLogClear then EventLogList.Items.Clear
  else if Sender = aLogProperties then ShowOptions(osDebugger, DebuggerOptionsEventLogPage)
  else if Sender = aViewHelp then ViewHelp
  else if Sender = aBrowseSymbolAtCursor then BrowseSymbolAtCursor
  else if Sender = aLogSave then SaveLinesAs('Save Events to File', EventLogList.Items)
  else if Sender = aLogComment then
  begin
    S := '';
    if InputDialog(Self, 'Add Comment', '&Comment:', S) and (Trim(S) <> '') then FDebug.AddLog(S);
  end
  else if Sender = FInspector.aOIExpand then FInspector.Grid.ExpandSelected(True)
  else if Sender = FInspector.aOICollapse then FInspector.Grid.ExpandSelected(False)
  else if Sender = FInspector.aOIProperties then ShowOptions(osEnvironment, EnvOptionsInspectorPage)
  else if Sender = FCompBar.aCompAdd then FCompBar.AddSelected
  else if Sender = FCompBar.aCompProperties then ShowOptions(osEnvironment, EnvOptionsComponentsPage)
  else if (Sender = FCompBar.aCompSortName) or (Sender = FCompBar.aCompSortRecent) or (Sender = FCompBar.aCompSortMost) or (Sender = FCompBar.aCompSortPalette) then
  begin
    { Component Bar's sort buttons: the view's order, kept with the options }
    EnvOptions.CompSort := TAction(Sender).Tag;
    EnvOptions.Save;
    FCompBar.SortMode := TSdCompSort(EnvOptions.CompSort);
  end
  else if Sender = FCompBar.aCompShowCategory then FCompBar.ShowCategory(FCompBar.SelectedCategory)
  else if Sender = FCompBar.aCompAll then FCompBar.ShowCategory('');
end;

{ lines of a view into a text file (Save Messages, Save Events to File) }
procedure TMainForm.SaveLinesAs(const Title: string; Lines: TStrings);
var
  FileName: string;
begin
  FileName := '';
  if AskSaveName(Title, 'Text files (*.txt)|*.txt|All files (*.*)|*.*', 'txt', FileName) then
    WriteFileU(FileName, Lines.Text);
end;

{ Search Results emptied (a new search, Clear, an expert's ClearSearchResults) }
procedure TMainForm.ClearSearchResults;
begin
  FSearchView.Clear;
end;

procedure TMainForm.ActPane(Sender: TObject);
var
  A: TSdDockArea;
begin
  if FMenuPanel = nil then Exit;
  if (Sender = aPaneClose) or (Sender = aPaneHide) then
  begin
    if FMenuGroup then FDock.HideGroup(FMenuPanel.Group) else FDock.HidePanel(FMenuPanel);
    Exit;
  end;
  { Tabs: the side of the view where the group's tabs lie (top, bottom, left or right) }
  if Sender = aTabsTop then FDock.SetTabSide(FMenuPanel.Group, tsTop)
  else if Sender = aTabsBottom then FDock.SetTabSide(FMenuPanel.Group, tsBottom)
  else if Sender = aTabsLeft then FDock.SetTabSide(FMenuPanel.Group, tsLeft)
  else if Sender = aTabsRight then FDock.SetTabSide(FMenuPanel.Group, tsRight);
  if (Sender = aTabsTop) or (Sender = aTabsBottom) or (Sender = aTabsLeft) or (Sender = aTabsRight) then Exit;
  { Auto Hide: the pin of the group's caption }
  if Sender = aAutoHide then
  begin
    FDock.SetAutoHide(FMenuPanel.Group, not FMenuPanel.Group.AutoHide);
    Exit;
  end;
  { Floating: the group (on its caption)
    or the view in a window of its own; when it floats already, back where it was docked }
  if Sender = aPaneFloat then
  begin
    if FMenuPanel.Group.Floating then
    begin
      if FMenuGroup or (FMenuPanel.Group.PanelCount = 1) then FDock.DockBack(FMenuPanel.Group)
      else if FMenuPanel.Group.HomeArea <> nil then FDock.MovePanel(FMenuPanel, FMenuPanel.Group.HomeArea)
      else FDock.MovePanel(FMenuPanel, FLeftArea);
    end
    else if FMenuGroup then FDock.FloatGroup(FMenuPanel.Group, Rect(0, 0, 0, 0))
    else FDock.FloatPanel(FMenuPanel, Rect(0, 0, 0, 0));
    Exit;
  end;
  if Sender = aPaneLeft then A := FLeftArea
  else if Sender = aPaneRight then A := FRightArea
  else if Sender = aPaneBottomFull then A := FBottomFullArea
  else A := FBottomArea;
  if FMenuGroup then FDock.MoveGroup(FMenuPanel.Group, A) else FDock.MovePanel(FMenuPanel, A);
end;
{ An action of its own for every entry of a list that comes from data (Reopen, the verbs of a
  component editor): the entries are commands like all others. }
function TMainForm.NewAction(List: TActionList; const ACaption, AHint: string; ATag: Integer;
  AOnExecute: TNotifyEvent): TAction;
begin
  Result := TAction.Create(Self);
  Result.Caption := ACaption;
  Result.Hint := AHint;
  Result.Tag := ATag;
  Result.OnExecute := AOnExecute;
  Result.ActionList := List;
end;

{ ... and its menu item: into Menu at Index, at the end for -1 }
function TMainForm.NewActionItem(Menu: TMenuItem; A: TAction; Index: Integer): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Action := A;
  if Index < 0 then Menu.Add(Result) else Menu.Insert(Index, Result);
end;

procedure TMainForm.ClearActions(List: TActionList);
begin
  while List.ActionCount > 0 do List.Actions[List.ActionCount - 1].Free;
end;

{ the Options dialog at a page of a section: Tools | Environment / Editor / Debugger / Formatter
  Options, Configure Palette, the views' Properties; the editors, designers and views take what
  changed }
procedure TMainForm.ShowOptions(Section: TOptionsSection; Page: Integer);
var
  OldName, NewName: string;
  OldSize, NewSize: Integer;
begin
  OldName := Settings.ReadString('UI', 'FontName', '');
  OldSize := Settings.ReadInteger('UI', 'FontSize', 0);
  if OptionsDialog(Self, Section, Page) then
  begin
    { the dialogs opened from now on take the body colour chosen }
    UISetDialogBackground(Settings.ReadInteger('UI', 'DialogBackground', 0));
    ApplyEditorOptions;
    FDebug.LogFontChanged;
    EventLogList.Invalidate;
    SaveState;
    { the UI font is set as D7 Studio starts (D7Studio.dpr): one changed here, other than the font
      it runs with, is offered a restart. Closing asks what closing always asks (a debug session,
      modified files); a Cancel there cancels the restart (CloseQuery) }
    NewName := Settings.ReadString('UI', 'FontName', '');
    NewSize := Settings.ReadInteger('UI', 'FontSize', 0);
    if (not SameText(NewName, OldName) or (NewSize <> OldSize)) and
      (not SameText(NewName, UIFontOverride) or (NewSize <> UIFontSizeOverride)) and
      (MessageBox(Handle, 'The user interface font takes effect when D7 Studio starts again. Restart now?',
        AppTitle, MB_YESNO or MB_ICONQUESTION) = IDYES) then
    begin
      FRestart := True;
      PostMessage(Handle, WM_CLOSE, 0, 0);
    end;
  end;
end;

{ a View command: the panel visible and chosen in its group; its content is brought up to
  date also when it was shown already }
procedure TMainForm.ShowDockPanel(P: TSdDockPanel; Slide: Boolean);
begin
  if P.Showing then DockPanelShow(FDock, P)
  else if Slide or not P.Group.AutoHide then FDock.ShowPanel(P);
end;

{ a View command, a package that opens for its package editor, an expert showing its window: the
  panel shown, and the keyboard to its view - a floating group's window is activated by that. What the IDE shows by
  itself (Messages after a compile, the views of a stop, Search Results) leaves the keyboard where
  it is: ShowDockPanel }
procedure TMainForm.ViewDockPanel(P: TSdDockPanel);
begin
  ShowDockPanel(P);
  FDock.FocusPanel(P);
end;

{ a tool view has just become visible: views that are filled only while seen catch up }
procedure TMainForm.DockPanelShow(Sender: TObject; Panel: TSdDockPanel);
begin
  if FClosing then Exit;
  if Panel = FCodeExpPanel then RefreshExplorer
  { a new window of the tree (its group floated or docked) keeps the nodes, not the active
    project's bold }
  else if Panel = FProjPanel then FProjView.MarkActive
  else if Panel = FObjTreePanel then RefreshObjTree(True)
  else if Panel = FBottomPanels[BT_TODO] then
  begin
    FTodoShown := True;
    RefreshTodoList;
  end
  else if Panel.Control is TSdPackageView then RefreshPackageView(TSdPackageView(Panel.Control))
  else if Panel = FResPanel then RefreshResourceView
  else if Panel = FBrowserPanel then
  begin
    if FBrowserFresh then FBrowserFresh := False else RebuildBrowser;
  end
  { a view of the machine a stop found hidden catches up }
  else if FDebug <> nil then FDebug.MachineViewShown(Panel.Control);
end;
destructor TMainForm.Destroy;
var
  I: Integer;
begin
  FClosing := True;
  SdHistory.OnHistoryChanged := nil;
  { the experts first, while everything they hold on to is there: their wizards are told
    Destroyed, the DLL experts terminated }
  OtaShutdown;
  OtaHost := nil;
  FCustomize.Free;                           // it holds the bars' window procedures
  Screen.OnActiveControlChange := nil;
  AppEvents.OnShowHint := nil;
  AppEvents.OnIdle := nil;
  AppEvents.OnActivate := nil;
  AppEvents.OnHint := nil;
  AppEvents.OnException := nil;             // AppException uses the form
  DesignEnv.OnSelectionChanged := nil;
  DesignEnv.OnModified := nil;
  DesignEnv.OnStructureChanged := nil;
  DesignEnv.OnFocusInspector := nil;
  DesignEnv.OnContextMenu := nil;
  DesignHost.OnPaletteChanged := nil;
  DesignHost.OnPackageUnloading := nil;
  DesignHost.OnPackageUnloaded := nil;
  DesignHost.OnDesignWindow := nil;
  DesignHost.OnSyncDesignWindows := nil;
  PaletteToolHook := nil;
  { the experts' forms given back before the views (their parents) go: the experts free them }
  ExpertFormHook := nil;
  ExpertDropHook := nil;
  if FExpertViews <> nil then FExpertViews.ReleaseAll;
  FreeAndNil(FExpertViews);
  FreeAndNil(FIdePalette);
  if DesignEnvironment <> nil then DesignEnvironment.Host := nil;
  FDesignWinHost := nil;
  if FInspector <> nil then FInspector.SetDesigner(nil);
  if FCodeExp <> nil then FCodeExp.Clear;
  if FObjTree <> nil then FObjTree.Clear;
  if FDocs <> nil then
    for I := FDocs.Count - 1 downto 0 do TObject(FDocs[I]).Free;
  FreeAndNil(FDocs);
  FreeAndNil(FPages);
  FLockedPages.Free;
  FreeAndNil(FInheritRenames);
  FreeAndNil(FFilledMenus);
  FHistory.Free;
  FDebug.Free;
  FTodo.Free;
  FTodoHost.Free;
  ClearTodoTexts;
  FTodoTexts.Free;
  FMsgHints.Free;
  FSourceCache.Free;
  IDE := nil;
  FCodeInsight.Free;
  FCompiler.Free;
  FScratch.Free;
  FProject := nil;                   // the group's
  FServices.Free;
  FOtaHost.Free;
  MainForm := nil;
  FGroup.Free;
  FPkgViews.Free;                      // the views themselves are the form's
  inherited;
end;

procedure TMainForm.CreateWnd;
begin
  inherited CreateWnd;
  DragAcceptFiles(Handle, True);
  { a jump's WM_SDNAVRECORD went with the old window: the history records the next one }
  FNavPending := False;
end;

procedure TMainForm.WMDropFiles(var Message: TWMDropFiles);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    DroppedFiles(Message.Drop, L);       // usable names (SdFileNames)
    DragFinish(Message.Drop);
    for I := 0 to L.Count - 1 do OpenAny(L[I]);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- automated UI tests }

const
  TestCopyDataId = $D7C0DE;

procedure TMainForm.WMCopyData(var Message: TWMCopyData);
var
  S: string;
  X, Y: Integer;
begin
  { only the off-screen test instance (D7S_POS) accepts commands }
  Message.Result := 0;
  if (Message.CopyDataStruct = nil) or (Message.CopyDataStruct^.dwData <> TestCopyDataId) or
    not UITestOrigin(X, Y) then Exit;
  SetString(S, PChar(Message.CopyDataStruct^.lpData), Message.CopyDataStruct^.cbData);
  S := Trim(PChar(S));
  try
    FTestResult := 1;
    TestCommand(S);
    Message.Result := FTestResult;
  except
    on E: Exception do
    begin
      LogException(E, 'test: ' + S, SettingsDir + 'error.log');
      Message.Result := 2;
    end;
  end;
end;

{ test command tooltip: the hint of MainBar's button Index as the VCL shows a hint (its control's
  CM_HINTSHOW, then OnShowHint) in the hint window class, below the button; the real pointer of the
  test instance is the user's, so the VCL's own timer never shows one. -1 hides it }
procedure TMainForm.TestToolTip(Index: Integer);
var
  Info: THintInfo;
  CanShow: Boolean;
  Btn: TToolButton;
  R: TRect;
  P: TPoint;
begin
  FTestTipText := '';
  if (Index < 0) or (Index >= MainBar.ButtonCount) then
  begin
    if (FTestTip <> nil) and FTestTip.HandleAllocated then ShowWindow(FTestTip.Handle, SW_HIDE);
    Exit;
  end;
  Btn := MainBar.Buttons[Index];
  Info.HintControl := Btn;
  Info.HintWindowClass := HintWindowClass;
  P := Btn.ClientToScreen(Point(0, Btn.Height));
  Info.HintPos := P;
  Info.HintMaxWidth := Screen.Width;
  Info.HintColor := Application.HintColor;
  Info.CursorRect := Btn.ClientRect;
  Info.CursorPos := Point(Btn.Width div 2, Btn.Height div 2);
  Info.ReshowTimeout := 0;
  Info.HideTimeout := Application.HintHidePause;
  Info.HintData := nil;
  Info.HintStr := GetShortHint(Btn.Hint);
  CanShow := Btn.Perform(CM_HINTSHOW, 0, Integer(@Info)) = 0;
  if CanShow then AppShowHint(Info.HintStr, CanShow, Info);
  if not CanShow or (Info.HintStr = '') then Exit;
  FTestTipText := Info.HintStr;
  if (FTestTip = nil) or (FTestTip.ClassType <> Info.HintWindowClass) then
  begin
    FTestTip.Free;
    FTestTip := Info.HintWindowClass.Create(Self);
  end;
  R := FTestTip.CalcHintRect(Info.HintMaxWidth, Info.HintStr, Info.HintData);
  OffsetRect(R, Info.HintPos.X, Info.HintPos.Y);
  FTestTip.Color := Info.HintColor;
  FTestTip.ActivateHintData(R, Info.HintStr, Info.HintData);
end;

procedure TMainForm.TestCommand(const Cmd: string);
var
  Verb, Arg, A1, A2: string;
  P: Integer;
  Page: TEditorPage;
  D: TFormDesigner;
  C: TComponent;
  L: TList;
  Names, Warn: TStringList;
  I: Integer;
  Sh: TShiftState;
  Dp: TSdDockPanel;
  Da: TSdDockArea;
  WN: TTreeNode;
  K: Integer;
  S: string;
  R: TRect;
  Pkg: TPackageEntry;

  { the modifiers of an argument: c = Ctrl, s = Shift, a = Alt }
  function ShiftOf(const Mods: string): TShiftState;
  begin
    Result := [];
    if Pos('c', LowerCase(Mods)) > 0 then Include(Result, ssCtrl);
    if Pos('s', LowerCase(Mods)) > 0 then Include(Result, ssShift);
    if Pos('a', LowerCase(Mods)) > 0 then Include(Result, ssAlt);
  end;

  { the menu item of Path is to be clicked (FTestItem); False: there is none (3) or it is
    disabled (4) }
  function ItemReady(const Path: string): Boolean;
  begin
    FTestItem := FindMenuItem(Path);
    Result := (FTestItem <> nil) and FTestItem.Enabled;
    if FTestItem = nil then FTestResult := 3
    else if not Result then FTestResult := 4;
  end;

begin
  P := Pos(' ', Cmd);
  if P = 0 then P := Length(Cmd) + 1;
  Verb := LowerCase(Copy(Cmd, 1, P - 1));
  Arg := Trim(Copy(Cmd, P + 1, MaxInt));
  P := Pos(' ', Arg);
  if P = 0 then P := Length(Arg) + 1;
  A1 := Copy(Arg, 1, P - 1);
  A2 := Trim(Copy(Arg, P + 1, MaxInt));
  Page := ActivePage;
  D := ActiveDesigner;
  if Verb = 'state' then
    DumpState(Arg)
  else if Verb = 'open' then
    OpenAny(Arg)
  else if Verb = 'goto' then
  begin
    if Page <> nil then
    begin
      Page.ShowDesign(False);
      Page.GotoLine(StrToIntDef(A1, 1), StrToIntDef(A2, 1));
    end;
  end
  else if Verb = 'text' then
  begin
    if (Page <> nil) and Page.CodeView then Page.Editor.ReplaceSel(Arg);
  end
  else if Verb = 'sel' then                  // sel <anchor> <caret>: the editor's selection (byte positions)
  begin
    if (Page <> nil) and Page.CodeView then Page.Editor.SetSel(StrToIntDef(A1, 0), StrToIntDef(A2, 0));
  end
  else if Verb = 'select' then
  begin
    if D <> nil then
    begin
      L := TList.Create;
      Names := TStringList.Create;
      try
        Names.CommaText := Arg;
        for I := 0 to Names.Count - 1 do
        begin
          C := D.GetComponent(Names[I]);           // a placed frame's by its path, Frame21.Button1
          if C <> nil then L.Add(C);
        end;
        D.SelectList(L);
      finally
        Names.Free;
        L.Free;
      end;
    end;
  end
  else if Verb = 'prop' then
    FInspector.FocusProperty(#0, Arg)
  else if Verb = 'row' then                  // select a row of the current inspector page
    FInspector.Grid.SelectByName(Arg)
  else if Verb = 'oicategory' then           // oicategory -|c|cs <category>: a click on it in View
    FInspector.Grid.ClickCategory(A2, ShiftOf(A1))   // (with Ctrl, Ctrl+Shift: a posted click has neither)
  else if Verb = 'key' then                  // key <virtual key> [c][s][a]: an editor key with modifiers
  begin
    if (Page <> nil) and Page.CodeView then
    begin
      Page.SimulateKey(StrToIntDef(A1, 0), ShiftOf(A2));
    end;
  end
  else if Verb = 'postkey' then              // postkey <virtual key> [c][s][a]: as key, from the message loop
    PostMessage(Handle, WM_SDTESTKEY, StrToIntDef(A1, 0), Byte(ShiftOf(A2)))
  else if Verb = 'edit' then                 // edit <component>: its component editor (a double click)
  begin
    { selected first, as a double click selects it; a placed frame's by its path, Frame21.Button1 }
    D := ActiveDesigner;
    if (D <> nil) and (D.Root <> nil) and (D.GetComponent(Arg) <> nil) then
    begin
      D.Select(D.GetComponent(Arg));
      D.EditComponent(D.GetComponent(Arg));
    end;
  end
  else if Verb = 'events' then
    FInspector.ShowEvents(not SameText(Arg, '0'))
  else if Verb = 'bottom' then
    ShowBottom(StrToIntDef(Arg, 0))
  else if Verb = 'watchselect' then          // watchselect 0,2: those watches selected, as Ctrl+clicks
  begin
    Names := TStringList.Create;
    try
      Names.CommaText := Arg;
      for I := 0 to Names.Count - 1 do
      begin
        WN := WatchTree.Items.GetFirstNode;
        K := StrToIntDef(Names[I], -1);
        while (WN <> nil) and (K > 0) do
        begin
          WN := WN.GetNextSibling;
          Dec(K);
        end;
        if (WN = nil) or (K < 0) then Continue;
        if I = 0 then Sh := [] else Sh := [ssCtrl];
        WatchTree.Select(WN, Sh);
      end;
    finally
      Names.Free;
    end;
  end
  else if (Verb = 'menu') or (Verb = 'menuwait') then   // menu File|New|Application: click it
  begin
    UpdateActionStates;
    { an item of a popup menu: the menu opens first (its OnPopup sets the states, and makes the
      items that come from data anew - Move Watch To Group), then the item is looked for }
    C := FindNamed(Copy(Arg, 1, Pos('|', Arg + '|') - 1));
    if (C is TPopupMenu) and Assigned(TPopupMenu(C).OnPopup) then TPopupMenu(C).OnPopup(C);
    if ItemReady(Arg) then
      if Verb = 'menuwait' then
      begin
        FTestItem.Click;
        FTestItem := nil;
      end
      else
        PostMessage(Handle, WM_APP + 77, 0, 0);   // a dialog it opens must not block the sender
  end
  else if Verb = 'close' then                // close <panel>: as Close on its tab
    FDock.HidePanel(FDock.FindPanel(Arg))
  else if Verb = 'closegroup' then           // closegroup <panel>: its group, as the close box
  begin
    if FDock.FindPanel(Arg) <> nil then FDock.HideGroup(FDock.FindPanel(Arg).Group);
  end
  else if Verb = 'autohide' then             // autohide <panel>: its group's pin, as a click on it
  begin
    if FDock.FindPanel(Arg) <> nil then
      FDock.SetAutoHide(FDock.FindPanel(Arg).Group, not FDock.FindPanel(Arg).Group.AutoHide);
  end
  else if Verb = 'dockback' then             // dockback <panel>: its floating group, as a double click
  begin
    if FDock.FindPanel(Arg) <> nil then FDock.DockBack(FDock.FindPanel(Arg).Group);
  end
  else if (Verb = 'dock') or (Verb = 'dockgroup') then
  begin
    { dock <panel> <area> [index]: as a drag of its tab (a group of its own); dockgroup: as a
      drag of its caption (the whole group); index = before that visible group of the area }
    Dp := FDock.FindPanel(A1);
    Da := FDock.FindArea(Copy(A2 + ' ', 1, Pos(' ', A2 + ' ') - 1));
    I := StrToIntDef(Trim(Copy(A2, Pos(' ', A2 + ' ') + 1, MaxInt)), -1);
    if (Dp = nil) or (Da = nil) then FTestResult := 3
    else if Verb = 'dock' then FDock.MovePanel(Dp, Da, I)
    else FDock.MoveGroup(Dp.Group, Da, I);
  end
  else if Verb = 'tab' then                  // tab <panel> <panel2>: as a drop on panel2's group
  begin
    Dp := FDock.FindPanel(A1);
    if (Dp = nil) or (FDock.FindPanel(A2) = nil) then FTestResult := 3
    else FDock.TabPanel(Dp, FDock.FindPanel(A2).Group);
  end

  else if Verb = 'edtext' then               // edtext <file>: the active editor's text into a file
  begin
    if ActiveEditor <> nil then WriteFileU(Arg, ActiveEditor.GetText) else FTestResult := 3;
  end
  else if Verb = 'popup' then                // popup <popup menu>: shows it (find it with Get-Dialogs)
  begin
    if FindNamed(Arg) is TPopupMenu then
      PostMessage(Handle, WM_APP + 78, Integer(FindNamed(Arg)), 0);
  end
  else if Verb = 'erasereset' then           // start counting erases per window class again
    UITestEraseText(True)
  else if Verb = 'minimaphover' then         // minimaphover <x> <y>: the pointer over the minimap, window coordinates
  begin
    if FEditWindow.Map <> nil then FEditWindow.Map.TestHover(StrToIntDef(A1, 0), StrToIntDef(A2, 0))
    else FTestResult := 3;
  end
  else if Verb = 'package' then              // package <0|1> <file>: unloaded / loaded, as Install Packages does
  begin
    Pkg := DesignHost.FindPackage(A2);
    if Pkg <> nil then DesignHost.EnablePackage(Pkg, A1 = '1', S);
  end
  else if Verb = 'menus' then                // menus <file> [path]: the items with their states
    DumpMenu(A1, A2)
  else if Verb = 'writedlg' then             // writedlg <dialog> <file>: the dialog as laid out, as .dfm text
    WriteDialogText(A1, A2)
  else if Verb = 'paste' then                // paste <file>: form text into the designer, as Paste
  begin                                      // (without the system clipboard - the user's)
    if D <> nil then D.PasteText(ReadFileU(Arg));
  end
  else if Verb = 'action' then               // action <name>: runs an action, as its key would
  begin                                      // (one without a menu item: Record Macro ...)
    if (FindNamed(Arg) is TBasicAction) and TBasicAction(FindNamed(Arg)).Update then ;
    if (FindNamed(Arg) is TCustomAction) and TCustomAction(FindNamed(Arg)).Enabled then
      TCustomAction(FindNamed(Arg)).Execute;
  end
  else if Verb = 'newapp' then               // newapp <file.dpr>: File | New | Application without
    NewApplication(Arg)                      // its Save dialog
  else if Verb = 'addnewapp' then            // addnewapp <file.dpr>: Project | Add New Project's
  begin                                      // Application without New Items and its Save dialog
    FNewProjectMode := omAddToGroup;
    try
      NewApplication(Arg);
    finally
      FNewProjectMode := omOpen;
    end;
  end
  else if Verb = 'newitem' then              // newitem <name>: File | New | Other's item of an
  begin                                      // expert's wizard run without the dialog (3: none)
    if not OtaRunRepositoryWizard(Arg) then FTestResult := 3;
  end
  else if Verb = 'todohtml' then             // todohtml <file>: Copy As | HTML Table's text into a
    WriteFileU(Arg, FTodo.Table.Html(FTodo)) // file (never the user's clipboard)
  else if Verb = 'todohint' then             // todohint <x> <y>: Show ToolTips when Clipped there
  begin                                      // (todohint= in the state: shown|text|cell|text width)
    if FTodoView.CellHint(Point(StrToIntDef(A1, 0), StrToIntDef(A2, 0)), S, R) then
      FTestHint := Format('1|%s|%d,%d,%d,%d|%d', [S, R.Left, R.Top, R.Right, R.Bottom, FTodoView.TodoList.Canvas.TextWidth(S)])
    else
      FTestHint := '0';
  end
  else if Verb = 'resselect' then            // resselect <n>: the Resources view's row n chosen (folders count)
  begin
    I := StrToIntDef(Arg, -1);
    if (I >= 0) and (I < ResTree.Items.Count) then ResTree.Items[I].Selected := True;
  end
  else if Verb = 'unsavedres' then           // unsavedres <file>: the .res a compile of the project takes now
  begin
    S := '';
    if FProject <> nil then
    begin
      Warn := TStringList.Create;
      try
        S := UnsavedResources(FProject.FileName, Warn);
      finally
        Warn.Free;
      end;
    end;
    if S = '' then FTestResult := 3 else WriteFileU(Arg, S);
  end
  else if (Verb = 'histselect') or (Verb = 'histroutine') or (Verb = 'histfind') or (Verb = 'histfile') then
  begin
    { the History tab of the page: histselect <a> [<b>] its row a chosen (and b, as with Ctrl), histroutine
      [<name>] its routine filter, histfind [<text>] its find box (as typed, then the pause), histfile 0|1
      the versions of the unit, of its form }
    if (Page <> nil) and (Page.History <> nil) then
      if Verb = 'histselect' then Page.History.SelectRows(StrToIntDef(A1, -1), StrToIntDef(A2, -1))
      else if Verb = 'histroutine' then Page.History.ShowRoutine(Arg)
      else if Verb = 'histfind' then Page.History.FindText(Arg)
      else Page.History.ShowFile(Arg = '1');
  end
  else if Verb = 'histkeep' then             // histkeep: the pages' unsaved versions taken now (HistoryTimer's work)
    HistoryTimerTick(nil)
  else if Verb = 'todoselect' then           // todoselect <n>: the To-Do List's row n chosen
  begin
    I := StrToIntDef(Arg, -1);
    if (I >= 0) and (I < FTodoView.TodoList.Items.Count) then
    begin
      FTodoView.TodoList.Selected := FTodoView.TodoList.Items[I];
      FTodoView.TodoList.ItemFocused := FTodoView.TodoList.Selected;
    end;
  end
  else if Verb = 'dwell' then                // dwell <offset> [<x> <y>]: the mouse rests there (the debugger's
  begin                                      // value, the hint of code insight - an expert's or D7 Studio's own;
                                             // x y: at that client point, a folded line's box with -1 as offset)
    if (Page <> nil) and Assigned(Page.Editor.OnDwellStart) then
      Page.Editor.OnDwellStart(Page.Editor, StrToIntDef(A1, 0), StrToIntDef(Copy(A2, 1, Pos(' ', A2 + ' ') - 1), 0),
        StrToIntDef(Copy(A2, Pos(' ', A2 + ' ') + 1, MaxInt), 0));
  end
  else if Verb = 'dwellend' then             // dwellend: the mouse moved on (the code tip goes)
  begin
    if (Page <> nil) and Assigned(Page.Editor.OnDwellEnd) then Page.Editor.OnDwellEnd(Page.Editor);
  end
  else if Verb = 'tooltip' then              // tooltip <i>: the hint of the main tool bar's button i as
    TestToolTip(StrToIntDef(Arg, -1))        // the VCL shows it, below the button (-1: hidden)
  else if Verb = 'ctrlclick' then            // ctrlclick <offset>: a Ctrl+click there (Find Declaration, an
  begin                                      // expert's GotoDefinition)
    if (Page <> nil) and Assigned(Page.Editor.OnCtrlClick) then Page.Editor.OnCtrlClick(Page.Editor, StrToIntDef(Arg, 0));
  end
  else if Verb = 'closeproject' then         // closeproject <n>: the group's project n closed in the
  begin                                      // group, as an expert's IOTAModule.CloseModule
    I := StrToIntDef(Arg, -1);
    if (I < 0) or (I >= FGroup.Count) then FTestResult := 3
    else if not CloseGroupProject(FGroup.Projects[I]) then FTestResult := 4;
  end
  else if (Verb = 'projectnode') or (Verb = 'activate') or (Verb = 'removeproject') then
  begin
    { the Project Manager's node of project n (0: the group's first; after the group's projects the
      packages beside it) chosen; activate: then Activate, removeproject: Remove Project from a
      posted message (its question does not block the sender) }
    WN := FProjView.ProjectNode(StrToIntDef(Arg, -1));
    if WN = nil then FTestResult := 3
    else
    begin
      WN.Selected := True;
      if Verb = 'activate' then ActivateProject(FProjView.SelectedProject)
      else if Verb = 'removeproject' then
      begin
        UpdateActionStates;
        if ItemReady('ProjPopup|Remove Project') then PostMessage(Handle, WM_APP + 77, 0, 0);
      end;
    end;
  end;
end;

{ test mode: a popup menu shown from a posted message (TrackPopupMenu runs its own loop) }
procedure TMainForm.CMTestPopup(var Message: TMessage);
begin
  TPopupMenu(Message.WParam).Popup(Left + 500, Top + 300);
end;

{ test mode: the key command's key from the message loop - what it runs may open a menu (an
  expert's), which TrackPopupMenu does not while the sender of a command waits for its answer }
procedure TMainForm.CMTestKey(var Message: TMessage);
var
  Page: TEditorPage;
begin
  Page := ActivePage;
  if (Page <> nil) and Page.CodeView then
    Page.SimulateKey(Message.WParam, TShiftState(Byte(Message.LParam)));
end;

procedure TMainForm.CMTestClick(var Message: TMessage);
var
  It: TMenuItem;
begin
  It := FTestItem;
  FTestItem := nil;
  if It <> nil then It.Click;
end;

function MenuCaption(It: TMenuItem): string;
begin
  Result := StripHotkey(It.Caption);
end;

{ a component by its name - one of this form's, of a view form or frame it owns (the Project
  Manager's, the To-Do List's ... menus and actions) or the edit window's (SdOtaEditWindow: the
  editor's menus); nil: none }
function TMainForm.FindNamed(const Name: string): TComponent;
var
  I: Integer;
  Dp: TSdDockPanel;
begin
  { <view>.<name>: a component of a view of the dock - several views are made of one frame (the
    package editors: PackageEditor2.PkgPopup) }
  I := Pos('.', Name);
  if I > 0 then
  begin
    Result := nil;
    Dp := FDock.FindPanel(Copy(Name, 1, I - 1));
    if (Dp <> nil) and (Dp.Control <> nil) then Result := Dp.Control.FindComponent(Copy(Name, I + 1, MaxInt));
    Exit;
  end;
  Result := FindComponent(Name);
  for I := 0 to ComponentCount - 1 do
    if (Result = nil) and ((Components[I] is TCustomForm) or (Components[I] is TCustomFrame)) then
      Result := Components[I].FindComponent(Name);
  if (Result = nil) and (EditWindowForm <> nil) then Result := EditWindowForm.FindComponent(Name);
end;

{ test mode: an item of the main menu by its captions, "File|New|Application", or of a popup
  menu, "WatchPopup|Delete Watch"; '' is the main menu, a popup's name alone the popup }
function TMainForm.FindMenuItem(const Path: string): TMenuItem;
var
  Rest, Part: string;
  P, I: Integer;
  Parent: TMenuItem;
  Popup: TComponent;
begin
  Parent := MainMenu.Items;
  Rest := Path;
  P := Pos('|', Rest + '|');
  Popup := FindNamed(Copy(Rest, 1, P - 1));
  if Popup is TPopupMenu then
  begin
    Parent := TPopupMenu(Popup).Items;
    Delete(Rest, 1, P);
  end;
  Result := Parent;
  while Rest <> '' do
  begin
    P := Pos('|', Rest);
    if P = 0 then P := Length(Rest) + 1;
    Part := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    Result := nil;
    for I := 0 to Parent.Count - 1 do
      if not Parent[I].IsLine and SameText(MenuCaption(Parent[I]), Part) then
      begin
        Result := Parent[I];
        Break;
      end;
    { a caption that names the project, "Compile Project1", is found as "Compile" }
    if Result = nil then
      for I := 0 to Parent.Count - 1 do
        if not Parent[I].IsLine and SameText(Copy(MenuCaption(Parent[I]), 1, Length(Part) + 1), Part + ' ') then
        begin
          Result := Parent[I];
          Break;
        end;
    if Result = nil then Exit;
    Parent := Result;
  end;
end;

{ test mode: one line per item - caption | shortcut | states }
procedure TMainForm.DumpMenu(const FileName, Path: string);
var
  L: TStringList;
  Parent, It: TMenuItem;
  I: Integer;
  S: string;
begin
  UpdateActionStates;
  Parent := FindMenuItem(Path);
  { a popup menu: as it opens (its OnPopup makes and orders items, sets the states) }
  if (Parent <> nil) and (Parent.GetParentMenu is TPopupMenu) and
    Assigned(TPopupMenu(Parent.GetParentMenu).OnPopup) then
  begin
    TPopupMenu(Parent.GetParentMenu).OnPopup(Parent.GetParentMenu);
    Parent := FindMenuItem(Path);
  end;
  L := TStringList.Create;
  try
    if Parent <> nil then
      for I := 0 to Parent.Count - 1 do
      begin
        It := Parent[I];
        if It.IsLine then S := '-'
        else
        begin
          S := MenuCaption(It) + ' | ' + ShortCutToText(It.ShortCut) + ' |';
          if not It.Enabled then S := S + ' disabled';
          if It.Checked then S := S + ' checked';
          if It.Count > 0 then S := S + ' submenu';
          if It.ImageIndex >= 0 then S := S + ' image';
        end;
        if not It.Visible then S := S + ' hidden';
        L.Add(S);
      end;
    L.SaveToFile(FileName);
  finally
    L.Free;
  end;
end;

procedure TMainForm.DumpState(const FileName: string);
const
  ResEditorNames: array[TSdResEditorKind] of string = ('imageedit', 'stringtable', 'restext', 'hexedit');
var
  TI: TSdTodoItem;
  L: TStringList;
  I: Integer;
  P: TEditorPage;
  RP: TSdResPage;
  K: TSdResEditorKind;
  D: TFormDesigner;
  S, Pn: string;
  N: TTreeNode;
  Owners: TList;
  R: TRect;
  PkV, Pv: TSdPackageView;

  procedure Tree(T: TTreeView; const Title: string);
  var
    N: TTreeNode;
  begin
    L.Add('[' + Title + ']');
    N := T.Items.GetFirstNode;
    while N <> nil do
    begin
      L.Add(StringOfChar(' ', N.Level * 2) + N.Text);
      N := N.GetNext;
    end;
  end;

  procedure List(Items: TStrings; const Title: string);
  var
    K: Integer;
  begin
    L.Add('[' + Title + ']');
    for K := 0 to Items.Count - 1 do L.Add(Items[K]);
  end;

  { the group's projects and the packages beside it, entries From .. Upto - 1 of AllProject:
    file|units|* active (a closed one: -) }
  function ProjectsText(From, Upto: Integer): string;
  var
    K: Integer;
    Prj: TSdProject;
  begin
    Result := '';
    for K := From to Upto - 1 do
    begin
      Prj := FGroup.AllProject(K);
      if Prj = nil then Result := Result + ExtractFileName(FGroup.AllFile(K)) + '|-|;'
      else Result := Result + Format('%s|%d|%s;', [ExtractFileName(FGroup.AllFile(K)), Prj.UnitCount,
        Copy('*', 1, Ord(Prj = FProject))]);
    end;
  end;

  { a tool bar's controls by position: bar:item@left-right,...; (item: the action, '-', a class) }
  function BarButtons(Bar: TToolBar): string;
  var
    K: Integer;
    C: TControl;
  begin
    Result := Bar.Name + ':';
    for K := 0 to Bar.ControlCount - 1 do
    begin
      C := Bar.Controls[K];
      if (C is TToolButton) and (TToolButton(C).Style = tbsSeparator) then Result := Result + '-'
      else if (C is TToolButton) and (TToolButton(C).Action <> nil) then Result := Result + TToolButton(C).Action.Name
      else Result := Result + C.ClassName;
      Result := Result + Format('@%d-%d,', [C.Left, C.Left + C.Width]);
    end;
    Result := Result + ';';
  end;

begin
  L := TStringList.Create;
  try
    L.Add('caption=' + Caption);
    L.Add('status=' + StatusBar.Panels[spPosition].Text + '|' + StatusBar.Panels[spModified].Text + '|' +
      StatusBar.Panels[spMode].Text + '|' + StatusBar.Panels[spErrors].Text + '|' + StatusBar.Panels[spEncoding].Text + '|' +
      StatusBar.Panels[spMessage].Text);
    { Error Insight: the page shown's errors (line:col message; ...), its list's rows }
    S := '';
    if ActivePage <> nil then
      for I := 0 to ActivePage.ErrorCount - 1 do
        S := S + Format('%d:%d %s;', [ActivePage.Errors[I].Line, ActivePage.Errors[I].Col, ActivePage.Errors[I].Msg]);
    L.Add('errors=' + S);
    L.Add('errorlist=' + IntToStr(ErrorList.Items.Count));
    S := '';
    for I := 0 to FDocs.Count - 1 do S := S + FPageTabs.Tabs[I] + ';';
    L.Add('pages=' + S);
    L.Add('filetabs=' + FPageTabs.DebugTabs);
    L.Add('history=' + FHistory.DebugText);
    P := ActivePage;
    if P <> nil then
    begin
      L.Add('page=' + P.FileName);
      L.Add('view=' + LowerCase(P.ViewTab));       // code, design, diagram, history
      { the Diagram tab: boxes|selected|scroll x,y|size; the boxes in [diagram] }
      if P.Diagram <> nil then L.Add('diagram=' + P.Diagram.StateText);
      { the History tab: SdHistoryFrame.StateText; its rows in [filehistory], its diff's lines in
        [filehistorydiff] }
      if P.History <> nil then L.Add('filehistory=' + P.History.StateText) else L.Add('filehistory=-');
      L.Add('designundo=' + P.DesignUndoState);
      L.Add(Format('caret=%d:%d', [P.Editor.CaretLine + 1, P.Editor.CaretCol + 1]));
      L.Add('modified=' + IntToStr(Ord(P.Modified)));
      L.Add('lines=' + IntToStr(P.Editor.LineCount));
      L.Add('line=' + P.Editor.GetLineText(P.Editor.CaretLine));
      { the first line in view (display line) and the horizontal offset in pixels: the scroll bars }
      L.Add(Format('scroll=%d,%d', [P.Editor.ScrollPos.Y, P.Editor.ScrollPos.X]));
      { the minimap of the file area's window (TSciMinimap.StateText) }
      if FEditWindow.Map <> nil then L.Add('minimap=' + FEditWindow.Map.StateText) else L.Add('minimap=-');
      L.Add(Format('errorline=%d', [P.Editor.MarkerNext(0, 1 shl MK_ERROR_LINE) + 1]));
      L.Add('link=' + P.Editor.LinkRange);
      L.Add('seltext=' + P.Editor.SelText);
      { the highlights of the Highlighting page as offset ranges; the carets; the zoom }
      L.Add('hl.ident=' + P.Editor.IndicatorRanges(IND_IDENT));
      L.Add('hl.decl=' + P.Editor.IndicatorRanges(IND_IDENTDECL));
      L.Add('hl.block=' + P.Editor.IndicatorRanges(IND_BLOCKMATCH));
      L.Add('hl.brace=' + P.Editor.IndicatorRanges(IND_BRACE));
      L.Add('hl.bracebad=' + P.Editor.IndicatorRanges(IND_BRACEBAD));
      L.Add('hl.find=' + P.Editor.IndicatorRanges(IND_FIND));
      L.Add('hl.rainbow=' + P.Editor.IndicatorRanges(IND_RAINBOW) + '|' + P.Editor.IndicatorRanges(IND_RAINBOW + 1) +
        '|' + P.Editor.IndicatorRanges(IND_RAINBOW + 2));
      L.Add('hl.autoclose=' + P.Editor.IndicatorRanges(IND_AUTOCLOSE));
      L.Add(Format('carets=%d', [P.Editor.CaretCount]));
      L.Add(Format('zoom=%d', [EditorOptions.Zoom]));
    end;
    { the window of the files' text: shown or not, where, the file it shows; how often a document
      came into the hidden worker }
    S := '-';
    if (FEditWindow.Edit <> nil) and (FEditWindow.Edit.Owner is TEditorPage) then
      S := ExtractFileName(TEditorPage(FEditWindow.Edit.Owner).FileName);
    L.Add(Format('editwin=%d|%d,%d %dx%d|%s|%d', [Ord(FEditWindow.Visible), FEditWindow.Left, FEditWindow.Top,
      FEditWindow.Width, FEditWindow.Height, S, SciWorkerAttaches]));
    L.Add('navbar=' + FNavBar.TestText);
    { the page bar of the page shown (its items in its client coordinates); the zoom bar shown and
      the zoom of the view shown (- none) }
    if ActiveDoc is TEditorPage then L.Add('pagebar=' + TEditorPage(ActiveDoc).PageBar.TestText)
    else if ActiveDoc is TSdResPage then L.Add('pagebar=' + TSdResPage(ActiveDoc).PageBar.TestText)
    else L.Add('pagebar=-');
    if DocZoomView(ActiveDoc) <> nil then S := IntToStr(DocZoomView(ActiveDoc).ZoomPercent) else S := '-';
    L.Add(Format('zoombar=%d|%s', [Ord(ZoomBar.Visible), S]));
    if ActiveDesigner <> nil then L.Add('designzoom=' + ActiveDesigner.ZoomState) else L.Add('designzoom=-');
    D := ActiveDesigner;
    if D <> nil then
    begin
      S := '';
      { a placed frame's component by its path (Frame21.Button1) }
      for I := 0 to D.SelectionCount - 1 do
        if D.Selections[I] is TComponent then S := S + D.GetComponentName(TComponent(D.Selections[I])) + ';'
        else S := S + D.Selections[I].ClassName + ';';
      L.Add('selection=' + S);
      S := '';
      for I := 0 to D.Root.ComponentCount - 1 do
        S := S + D.Root.Components[I].Name + ':' + D.Root.Components[I].ClassName + ';';
      L.Add('components=' + S);
      L.Add('positioner=' + D.PositionerText);
    end;
    L.Add(Format('shown=%d%d', [Ord(FDebug.ShownPaused), Ord(FDebug.ShownRunning)]));
    if FDebug.Paused then L.Add('debug=paused')
    else if FDebug.Active then L.Add('debug=running')
    else L.Add('debug=none');
    L.Add(Format('exec=%s:%d', [ExtractFileName(FDebug.ExecFile), FDebug.ExecLine]));
    L.Add(Format('erases=%d', [UITestErases]));
    L.Add('erasesby=' + UITestEraseText(False));
    L.Add(Format('bars=%s@%d,%d %dx%d;', [MainBar.Name, MainBar.Left, MainBar.Top, MainBar.Width, MainBar.Height]));
    { the tool bars' controls by position: the main one, Back / Forward before the file tabs, the
      open files' drop-down after them }
    L.Add('toolbuttons=' + BarButtons(MainBar) + BarButtons(HistoryBar) + BarButtons(FilesBar));
    L.Add('panes=' + FDock.DebugText);
    { the focused control and the group whose caption shows it }
    if Screen.ActiveControl <> nil then S := Screen.ActiveControl.ClassName + ':' + Screen.ActiveControl.Name
    else S := '';
    if (FDock.FocusGroup <> nil) and (FDock.FocusGroup.Active <> nil) then S := S + '|' + FDock.FocusGroup.Active.Name;
    L.Add('focus=' + S);
    L.Add('docktabs=' + FDock.DebugTabs);
    L.Add('compbar=' + FCompBar.DebugText);
    { the hidden palette experts drive (SdOtaPalette): its pages, the page shown, its tools, the
      tool chosen }
    L.Add('palette=' + FIdePalette.DebugText);
    { the experts' windows as views: name:form class,shown,floating }
    L.Add('expertviews=' + FExpertViews.DebugText);
    { the Open Tools API: wizards, menu items, DLL experts, key bindings, IDE notifiers, the
      message groups (name:messages) and the Messages view's tabs (* shown) }
    L.Add('ota=' + OtaDebugText + ' view=' + FMsgView.DebugText);
    { designide's desktop hooks: the experts' registered window variables, the handlers of the
      main window's created / shown events, which were sent }
    L.Add('desk=' + DeskDebugText);
    L.Add('dinsp=' + FDebugInsp.DebugText);
    L.Add('browser=' + FBrowser.DebugText);
    L.Add('browsertree=' + FBrowser.DebugTree);
    L.Add('typelib=' + FTypeLibView.DebugText);
    S := FGroup.Name + '|' + FGroup.FileName + '|';
    for I := 0 to FGroup.Projects.Count - 1 do
    begin
      S := S + ExtractFileName(FGroup.Projects[I]);
      if (FProject <> nil) and SameText(FGroup.Projects[I], FProject.FileName) then S := S + '*';
      S := S + ';';
    end;
    L.Add('group=' + S);
    { the group's projects as loaded, then the packages open beside the group }
    L.Add('projects=' + ProjectsText(0, FGroup.Count));
    L.Add('beside=' + ProjectsText(FGroup.Count, FGroup.AllCount));
    { the projects the page shown belongs to, * the one its services use (Delphi's rule) }
    S := '';
    if ActivePage <> nil then
    begin
      Owners := TList.Create;
      try
        FGroup.OwnersOf(ActivePage.FileName, Owners);
        for I := 0 to Owners.Count - 1 do
          S := S + ExtractFileName(TSdProject(Owners[I]).FileName) +
            Copy('*', 1, Ord(Owners[I] = FGroup.ProjectForFile(ActivePage.FileName))) + ';';
      finally
        Owners.Free;
      end;
    end;
    L.Add('owners=' + S);
    if FDebugProject <> nil then L.Add('debugproject=' + ExtractFileName(FDebugProject.FileName))
    else L.Add('debugproject=');
    if FCIProject <> nil then L.Add('ciproject=' + ExtractFileName(FCIProject.FileName))
    else L.Add('ciproject=');
    L.Add('completion=' + CompletionPopup.DebugText);
    L.Add('paramhint=' + IntToStr(Ord(ParamHint.Showing)) + '|' + ParamHint.DebugText);
    { the hover tips (SdHints): the code tip's lines, the value tip's layout and rows; the test
      command tooltip's text (a tab as \t) and bounds }
    L.Add('codetip=' + CodeTip.DebugText);
    L.Add('valuetip=' + ValueTip.DebugText);
    if (FTestTip <> nil) and FTestTip.HandleAllocated and IsWindowVisible(FTestTip.Handle) then
    begin
      GetWindowRect(FTestTip.Handle, R);
      L.Add(Format('tooltip=%s|%d,%d,%d,%d', [StringReplace(FTestTipText, #9, '\t', [rfReplaceAll]),
        R.Left, R.Top, R.Right, R.Bottom]));
    end
    else
      L.Add('tooltip=');
    S := '';
    for I := 0 to FDebug.BreakpointCount - 1 do
      with FDebug.Breakpoint(I) do
        if Kind = bkSource then
          S := S + Format('%s:%d:%d:%d;', [ExtractFileName(FileName), Line, Ord(Enabled), Ord(Valid)])
        else if Kind = bkModule then
          S := S + Format('%s:0:%d:%d;', [FileName, Ord(Enabled), Ord(Valid)])
        else
          S := S + Format('$%.8x:%d:%d:%d;', [Address, DataLength * Ord(Kind = bkData), Ord(Enabled), Ord(Valid)]);
    L.Add('breakpoints=' + S);
    L.Add('watchlist=' + FDebug.WatchDebugText);
    L.Add('watchview=' + FWatchView.DebugText);
    { the package editors: view:package (- free):1 visible; pkgview= the active project's, else the
      first one with a package }
    S := '';
    Pv := nil;
    for I := 0 to FPkgViews.Count - 1 do
    begin
      PkV := TSdPackageView(FPkgViews[I]);
      if PkV.Project = nil then Pn := '-' else Pn := ExtractFileName(PkV.Project.FileName);
      S := S + Format('%s:%s:%d;', [FDock.PanelOf(PkV).Name, Pn, Ord(FDock.PanelOf(PkV).Visible)]);
      if (PkV.Project <> nil) and ((Pv = nil) or (PkV.Project = FProject)) then Pv := PkV;
    end;
    L.Add('pkgviews=' + S);
    if Pv <> nil then L.Add('pkgview=' + Pv.DebugText) else L.Add('pkgview=|');
    L.Add('resview=' + FResView.DebugText);
    { the resource page shown: kind of editor|title|modified|key, and its editor's state }
    RP := ActiveResPage;
    S := '';
    if RP <> nil then
      S := Format('%s|%s|%d|%s', [ResEditorNames[RP.EditorKind], RP.Title, Ord(RP.Modified), RP.Key]);
    L.Add('respage=' + S);
    for K := Low(TSdResEditorKind) to High(TSdResEditorKind) do
      if (RP <> nil) and (RP.EditorKind = K) then L.Add(ResEditorNames[K] + '=' + RP.EditorText)
      else L.Add(ResEditorNames[K] + '=');
    { the To-Do List: sort order, ascending, completed shown, tooltips, hidden, pending; its rows
      (text|priority|module|owner|category|done|kind|file:line) and the header's arrow }
    L.Add(Format('todolist=%d|%d|%d|%d|%d|%d', [Ord(FTodo.SortOrder), Ord(FTodo.Ascending), Ord(FTodo.ShowCompleted),
      Ord(FTodo.ShowHints), FTodo.HiddenCount, FTodo.Pending]));
    L.Add('todohint=' + FTestHint);
    { the Open Tools API's To-Do List (managers|experts' items|notifiers) and code insight
      (managers|current manager|state|typed text|exact row|close key) }
    L.Add('todoexp=' + OtaTodoDebugText);
    L.Add('ci=' + OtaCIDebugText);
    { Delphi 1-3's experts: legacy= and the [legacy] section (SdOtaLegacy) }
    OtaLegacyState(L);
    L.Add('[diagram]');
    if (ActivePage <> nil) and (ActivePage.Diagram <> nil) then ActivePage.Diagram.BoxesText(L);
    L.Add('[filehistory]');
    if (ActivePage <> nil) and (ActivePage.History <> nil) then ActivePage.History.RowsText(L);
    L.Add('[filehistorydiff]');
    if (ActivePage <> nil) and (ActivePage.History <> nil) then ActivePage.History.DiffText(L);
    L.Add('[todo]');
    for I := 0 to FTodoView.TodoList.Items.Count - 1 do
    begin
      TI := TSdTodoItem(FTodoView.TodoList.Items[I].Data);
      { an expert's item: its module, line 0 }
      if TI.Ext <> nil then S := TI.ExtModule + ':0'
      else S := Format('%s:%d', [ExtractFileName(TI.FileName), TI.Line]);
      L.Add(Format('%s|%d|%s|%s|%s|%d|%s|%s', [TI.Text, TI.Priority, TI.ModuleCaption, TI.Owner, TI.Category,
        Ord(TI.Done), TI.Kind, S]) + Copy('|selected', 1, 9 * Ord(FTodoView.TodoList.Items[I].Selected)));
    end;
    { Build and the experts' message groups (IOTAMessageServices); a message with children has
      '+' (closed) or '-' (open) before its row }
    L.Add('[messages]');
    OtaMessageRows(MessageList, L);
    for I := 1 to FMsgView.GroupCount - 1 do
    begin
      L.Add('[messages ' + FMsgView.GroupName(I) + ']');
      OtaMessageRows(FMsgView.Lists[I], L);
    end;
    List(FSearchView.SearchList.Items, 'search');
    List(FDebug.CallStackView.Items, 'callstack');
    Tree(FDebug.LocalsView, 'locals');
    { the Watch List: name: value per row (as before), the watches, the view }
    L.Add('[watches]');
    N := FDebug.WatchView.Items.GetFirstNode;
    while N <> nil do
    begin
      L.Add(StringOfChar(' ', N.Level * 2) + FDebug.WatchNodeText(N));
      N := N.GetNext;
    end;
    List(FDebug.LogView.Items, 'log');
    Tree(FProjView.Tree, 'project');
    Tree(FCodeExp.Tree, 'codeexplorer');
    Tree(FObjTree.Tree, 'objtree');
    L.Add('[inspector]');
    L.Add(FInspector.DebugText);
    L.SaveToFile(FileName);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- state }

const
  DesignerSection = 'Designer';

{ the form designer's options (Environment Options | Designer) in [Designer]: each key once, for
  reading and for writing; a key that is not there keeps the value DesignEnv has - its default
  (TDesignEnvironment.Create) when the settings are read at the start }
function DesignerOptionTable: TSdOptions;
begin
  Result := nil;
  with DesignEnv do
    AddOptions(Result, [
      OptFlag('ShowGrid', ShowGrid),
      OptFlag('SnapToGrid', SnapToGrid),
      OptFlag('ShowCaptions', ShowCaptions),
      OptFlag('ShowPositioner', ShowPositioner),
      OptFlag('PositionerSnap', PositionerSnap),
      OptInt('GridX', GridX),
      OptInt('GridY', GridY),
      OptFlag('SnapLines', SnapLines),
      OptInt('SnapDistance', SnapDistance),
      OptInt('SnapSpacing', SnapSpacing),
      OptInt('SnapMargin', SnapMargin)]);
end;

{ the switches of the History tabs (SdHistoryFrame) in [Layout], for reading and for writing }
function HistorySwitchTable: TSdOptions;
begin
  Result := nil;
  AddOptions(Result, [
    OptFlag('HistorySideBySide', HistorySideBySide, -1),
    OptFlag('HistoryIgnoreBlanks', HistoryIgnoreBlanks, -1),
    OptFlag('HistoryComparePrevious', HistoryComparePrevious, -1)]);
end;

procedure TMainForm.LoadState;
var
  R: TRect;
  HL: TStringList;
begin
  { where the window was closed - also across monitors -, unless no monitor shows its caption
    any more (one was unplugged since): then whole on the nearest one (as a floating view's
    window, TSdDock.EnsureFloat); maximized there when it was - that state is given to the
    window just before it is shown (ApplyStartState) }
  R := MainWindowRect;
  if not UICaptionOnScreen(R, GetSystemMetrics(SM_CYCAPTION)) then UIFitWorkArea(R);
  BoundsRect := R;
  FStartMaximized := Settings.ReadBool('Layout', 'Maximized', True);
  { Tools | Editor Options, Debugger Options; the code templates (Ctrl+J) }
  LoadEditorOptions(Settings);
  ApplyHistoryOptions;
  ReadOptions(HistorySwitchTable, Settings, 'Layout', []);
  LoadDebuggerOptions(Settings);
  LoadFormatterOptions(Settings);
  LoadCodeTemplates;
  ReadOptions(DesignerOptionTable, Settings, DesignerSection, []);
  { the Find and Replace boxes' lists, one entry per key (Delphi's history lists: a text with a
    "|", a regular expression, stays whole) }
  HL := TStringList.Create;
  try
    LoadHistory(Settings, 'hlFindText', HL);
    FFind.History := HL.Text;
    LoadHistory(Settings, 'hlReplaceText', HL);
    FFind.ReplaceHistory := HL.Text;
  finally
    HL.Free;
  end;
end;

{ The form's window exists from its creation on, so WindowState set while it is hidden is only
  the VCL's field, without WS_MAXIMIZE: a WM_SIZE that comes before the window is shown says
  SIZE_RESTORED, and TCustomForm.Resizing sets the field back to wsNormal. One comes whenever
  the menu bar changes its rows - the main menu is rebuilt for each item that the experts and
  the packages add (CM_MENUCHANGED -> TCustomForm.SetMenu), and a narrow window wraps the bar
  onto another row. The state is therefore set last, after the experts and packages loaded:
  Show then maximizes the window (SW_SHOWMAXIMIZED). }
procedure TMainForm.ApplyStartState;
begin
  if FStartMaximized then WindowState := wsMaximized;
end;

procedure TMainForm.SaveState(Quiet: Boolean);
var
  WP: TWindowPlacement;
  R, Work: TRect;
  HL: TStringList;
  V: TSdPackageView;
  S: string;
begin
  if Settings = nil then Exit;
  { the window's place and state at every close (it started maximized whenever Autosave Desktop
    was off); not the test instance's, which D7S_POS places }
  WP.length := SizeOf(WP);
  if not UITestMode and HandleAllocated and GetWindowPlacement(Handle, @WP) then
  begin
    { rcNormalPosition counts from the primary monitor's work area (workspace coordinates; they
      differ from the screen's while a task bar is on the left or at the top) }
    SystemParametersInfo(SPI_GETWORKAREA, 0, @Work, 0);
    R := WP.rcNormalPosition;
    OffsetRect(R, Work.Left, Work.Top);
    Settings.WriteInteger('Layout', 'Left', R.Left);
    Settings.WriteInteger('Layout', 'Top', R.Top);
    Settings.WriteInteger('Layout', 'Width', R.Right - R.Left);
    Settings.WriteInteger('Layout', 'Height', R.Bottom - R.Top);
    { closed minimized: the state it comes back in (the VCL minimizes the application's window
      and the form keeps its state; a form minimized itself says it in the flags) }
    Settings.WriteBool('Layout', 'Maximized', (WindowState = wsMaximized) or
      (IsIconic(Handle) and (WP.flags and WPF_RESTORETOMAXIMIZED <> 0)));
  end;
  { the desktop - the arrangement of the views, floating ones included - only with Preferences |
    Autosave options | Desktop, as Delphi 7; a named desktop (View | Desktops) is saved when
    the user saves it }
  if EnvOptions.AutosaveDesktop then FDock.Save(Settings, PaneSection);
  Settings.WriteInteger('Layout', 'InspectorSplit', FInspector.Grid.SplitWanted);
  Settings.WriteString(InspSection, 'ArrangeBy', ArrangeNames[FInspector.Grid.ByCategory]);
  Settings.WriteString(InspSection, 'HiddenCategories', FInspector.Grid.HiddenCategories);
  Settings.WriteBool('Layout', 'ProjectStatusBar', FProjPanel.ShowStatus);
  Settings.WriteBool('Layout', 'WatchShowColumnHeaders', FWatchView.ShowHeaders);
  Settings.WriteInteger('Layout', 'WatchColumnWidth', FWatchView.ColumnWidth);
  Settings.WriteBool('Layout', 'PackageStatusBar', FPkgStatus);
  { the package editors' first column: the active package's, else the first editor's }
  V := PackageViewOf(FProject, False);
  if V = nil then V := TSdPackageView(FPkgViews[0]);
  Settings.WriteInteger('Layout', 'PackageColumnWidth', V.ColumnWidth);
  Settings.WriteBool('Layout', 'ResourceStatusBar', FResPanel.ShowStatus);
  Settings.WriteInteger('Layout', 'ResourceColumnWidth', FResView.ColumnWidth);
  WriteOptions(HistorySwitchTable, Settings, 'Layout');
  if FTodo <> nil then FTodo.Save(Settings);
  Settings.WriteString(CompSection, 'Used', FCompBar.Used.CommaText);
  SaveEditorOptions(Settings);
  SaveDebuggerOptions(Settings);
  SaveFormatterOptions(Settings);
  WriteOptions(DesignerOptionTable, Settings, DesignerSection);
  HL := TStringList.Create;
  try
    HL.Text := FFind.History;
    SaveHistory(Settings, 'hlFindText', HL);
    HL.Text := FFind.ReplaceHistory;
    SaveHistory(Settings, 'hlReplaceText', HL);
  finally
    HL.Free;
  end;
  { the project the next start opens - the group when it has a file (all its projects open again),
    else the active project: the group's first one (also a closed one) while a package beside the
    group is active, a package beside it only when the group has no project; none when the IDE
    closes without a project }
  if FGroup.FileName <> '' then S := FGroup.FileName
  else if FGroup.IsBeside(FProject) and (FGroup.Count > 0) then S := FGroup.Projects[0]
  else if FProject <> nil then S := FProject.FileName
  else S := '';
  if S <> '' then Settings.WriteString('Project', 'Last', S) else Settings.DeleteKey('Project', 'Last');
  { a settings file that cannot be written is reported after the user's OK, not at exit (it is
    in error.log then) }
  if not SaveSettings and not Quiet then
    MessageBox(Handle, PChar('The settings could not be saved: ' + SettingsSaveError), AppTitle,
      MB_OK or MB_ICONWARNING);
end;

function TMainForm.CloseQuery: Boolean;
begin
  Result := False;
  try
    Result := DoCloseQuery;
  finally
    { a close that does not happen does not start D7 Studio again later }
    if not Result then
    begin
      FRestart := False;
      FUpdateSetup := '';
    end;
  end;
end;

function TMainForm.DoCloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
  if not Result then Exit;
  { the compile (its messages are pumped) still uses the project }
  if CompileBusy then
  begin
    Result := False;
    Exit;
  end;
  if FDebug.Active then
  begin
    if MessageBox(Handle, 'A debug session is in progress. Terminate?', AppTitle, MB_YESNO or MB_ICONQUESTION) <> IDYES then
    begin
      Result := False;
      Exit;
    end;
    StopDebugNow;
  end;
  SaveState(True);
  Result := ConfirmSaveGroup and CloseGroup;
  if Result then
  begin
    { CloseGroup kept the projects' breakpoints in the settings: into the file with them }
    SaveSettings;
    FClosing := True;
    if not CloseAllDocs(True) then
    begin
      Result := False;
      FClosing := False;
      Exit;
    end;
    { the help windows close with the IDE (Delphi 7 closed its help too) - here, because D7
      Studio ends its process and its main form is never destroyed }
    CloseHelp;
  end;
end;

{ ---------------------------------------------------------------- application events }

{ a page's file read again from the disk (its breakpoints stay): the Object Inspector and the
  Object TreeView let go of its designer first; the project file parsed again }
procedure TMainForm.ReloadPage(P: TEditorPage);
begin
  SyncBreakpoints(P);
  ForgetDesigner(P);
  P.Reload;
  RefreshBreakMarkers(P);
  UpdatePageTab(P);
  ProjectTextChanged(P);
end;

{ the source of a project of the group or of a package beside it as saved or read again: its units
  are the ones it lists now (new objects: the tree is made again), code insight with them }
procedure TMainForm.ProjectTextChanged(Page: TEditorPage);
var
  P: TSdProject;
begin
  P := FGroup.LoadedProjectOf(Page.FileName);
  if P = nil then Exit;
  P.ParseSource(Page.GetSource, Page.Encoding);
  RefreshProjectTree;
  ConfigureCodeInsight;
end;

{ Files another program wrote since they were read or saved (TEditorPage.CheckFileChanged: the
  last write time to 100 ns and the size): asked about when D7 Studio becomes the active program
  again, in Delphi 7's words - Yes reads the file again (its breakpoints stay),
  No keeps the text and asks again only after the next change on the disk. A form shown as text
  (View as Text) and its unit are left alone: their text goes back into each other. }
procedure TMainForm.AppActivate(Sender: TObject);
var
  I: Integer;
  P: TEditorPage;
  Name, Msg: string;
  Lost: Boolean;
begin
  if FCheckingFiles or FClosing then Exit;
  FCheckingFiles := True;
  try
    I := 0;
    while I < PageCount do
    begin
      P := Pages[I];
      Inc(I);
      if (P.FormOwner <> nil) or (P.FormTextPage <> nil) or not P.CheckFileChanged then Continue;
      P.CheckHistoryDisk;
      Name := FromWide(DisplayPath(P.FileName), CP_ACP, Lost);
      if P.Modified then
        Msg := Format('Module %s''s time/date on disk has changed.  In-memory changes to this module ' +
          'have been detected as well.  Reloading the module from disk will overwrite these changes. ' +
          'Reload?', [Name])
      else
        Msg := Format('Module %s''s time/date changed. Reload?', [Name]);
      if MessageBox(Handle, PChar(Msg), AppTitle, MB_YESNO or MB_ICONQUESTION) <> IDYES then Continue;
      ReloadPage(P);
    end;
  finally
    FCheckingFiles := False;
  end;
  { the project's .res may have been changed by another program }
  if FResPanel.Showing then RefreshResourceView;
  UpdateStatus;
end;

{ what experts changed through the Open Tools API since the last idle: the environment and the
  editor options written, then taken by the editors, the designers, the Object Inspector, the dock
  and code insight (its library and browsing paths) - once for both; the active project's options
  written, code insight and the tree with them }
procedure TMainForm.FlushOtaOptions;
var
  Apply: Boolean;
begin
  Apply := FOtaEnvOptions or FOtaEditorOptions;
  if FOtaEnvOptions then
  begin
    FOtaEnvOptions := False;
    EnvOptions.Save;
  end;
  if FOtaEditorOptions then
  begin
    FOtaEditorOptions := False;
    SaveSettings;
  end;
  if Apply then ApplyEditorOptions;
  if FOtaProjectOptions then
  begin
    FOtaProjectOptions := False;
    if FProject = nil then Exit;
    try
      FProject.SaveOptions;
    except
      on E: Exception do OtaError(E, 'project options');
    end;
    ConfigureCodeInsight;
    RefreshProjectTree;
  end;
end;

procedure TMainForm.AppIdle(Sender: TObject; var Done: Boolean);
begin
  if not FFlickerDone and Showing then
  begin
    FFlickerDone := True;
    UIReduceFlicker(Self);
  end;
  if FResWritten and not FClosing then
  begin
    FResWritten := False;
    if FResPanel.Showing then RefreshResourceView;
  end;
  if not FClosing then FlushOtaOptions;
  UpdateActionStates;
  if (FDesignWindows <> nil) and not FClosing then FDesignWindows.Sync;
  { a newer release found in the background: its dialog once D7 Studio is the active program and no
    dialog of its own is open }
  if FUpdateFound and not FClosing and Application.Active and IsWindowEnabled(Handle) then
  begin
    FUpdateFound := False;
    PostMessage(Handle, WM_SDSHOWUPDATE, 0, 0);
  end;
  Done := True;
end;

procedure TMainForm.AppHint(Sender: TObject);
begin
  if StatusBar <> nil then StatusBar.Panels[spMessage].Text := GetLongHint(Application.Hint);
end;

procedure TMainForm.AppException(Sender: TObject; E: Exception);
begin
  if E is EAbort then Exit;
  LogException(E, 'ui', SettingsDir + 'error.log');
  MessageBox(Handle, PChar(E.Message), AppTitle, MB_OK or MB_ICONERROR);
end;

{ the number of the designer's selected controls (not the form itself) }
function SelectedControlCount(D: TFormDesigner): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to D.SelectionCount - 1 do
    if (D.Selections[I] is TControl) and (D.Selections[I] <> D.Root) then Inc(Result);
end;

procedure TMainForm.UpdateActionStates;
var
  P: TEditorPage;
  R: TSdResPage;
  Doc: TWinControl;
  Marked: Boolean;
  Ed: TSciEdit;
  D: TFormDesigner;
  Dgm: TSdDiagramView;
  Hv: TSdHistoryView;
  V: TSdPackageView;
  ZV: ISdZoomView;
  HasProj, Code, Dbg, Paused, Pas: Boolean;
  I, N, Need: Integer;
  AK: TAlignKind;
  FA: TSciFoldAction;
  S: string;
begin
  if FClosing then Exit;
  P := ActivePage;
  D := ActiveDesigner;
  Code := (P <> nil) and P.CodeView;
  if Code then Ed := P.Editor else Ed := nil;
  HasProj := FProject <> nil;
  Dbg := FDebug.Active;
  Paused := FDebug.ShownPaused;                // the states of the last stop during a step
  Pas := Code and P.IsPascal;
  R := ActiveResPage;
  { a file tab marks its page modified ('*'): whatever changed or saved it, also in the background }
  for I := 0 to FDocs.Count - 1 do
  begin
    Doc := TWinControl(FDocs[I]);
    if Doc is TEditorPage then Marked := TEditorPage(Doc).TabMarked else Marked := TSdResPage(Doc).TabMarked;
    if (I < FPageTabs.Tabs.Count) and (DocModified(Doc) <> Marked) then UpdatePageTab(Doc);
  end;
  FileSaveCommand.Enabled := (ActiveDoc <> nil) and DocModified(ActiveDoc);
  aBrowseBack.Enabled := FHistory.CanBack;
  aBrowseForward.Enabled := FHistory.CanForward;
  aFileList.Enabled := FDocs.Count > 0;
  { a form's text (View as Text) is saved with its unit, under the unit's names }
  FileSaveAsCommand.Enabled := (P <> nil) and (P.FormOwner = nil);
  { Save All and Close All also act on the projects (their options, the group, the packages beside
    it): a package opens without a page, a project's pages may all be closed }
  FileSaveAllCommand.Enabled := (FDocs.Count > 0) or (FGroup.AllCount > 0);
  FileCloseCommand.Enabled := ActiveDoc <> nil;
  { a compile whose messages are pumped still uses the project: nothing replaces it meanwhile
    (CloseGroup refuses it as well) }
  FileCloseAllCommand.Enabled := ((FDocs.Count > 0) or (FGroup.AllCount > 0)) and not FCompiler.Running;
  FileOpenProjectCommand.Enabled := not FCompiler.Running;
  FileNewVclFormCommand.Enabled := HasProj;
  FileNewVclDataModuleCommand.Enabled := HasProj;
  FileNewVclFrameCommand.Enabled := HasProj;
  { in the design view the designer's own steps (SdDesignUndo) }
  EditUndoCommand.Enabled := ((Ed <> nil) and Ed.CanUndo) or ((D <> nil) and P.CanDesignUndo);
  EditRedoCommand.Enabled := ((Ed <> nil) and Ed.CanRedo) or ((D <> nil) and P.CanDesignRedo);
  EditCutCommand.Enabled := ((Ed <> nil) and (Ed.SelEnd > Ed.SelStart)) or ((D <> nil) and (D.SelectionCount > 0) and (D.Selections[0] <> D.Root));
  EditDeleteCommand.Enabled := EditCutCommand.Enabled;
  { Editor Options | Force cut and copy enabled: also without a block }
  if (Ed <> nil) and EditorOptions.ForceCutCopy then EditCutCommand.Enabled := True;
  EditCopyCommand.Enabled := EditCutCommand.Enabled;
  EditPasteCommand.Enabled := ((Ed <> nil) and Ed.CanPaste) or ((D <> nil) and D.CanPasteNow);
  EditSelectAllCommand.Enabled := P <> nil;
  { a resource's page: its editor's commands (an edit box with the keyboard takes them itself) }
  if R <> nil then
  begin
    EditUndoCommand.Enabled := R.EditEnabled('EditUndoCommand');
    EditRedoCommand.Enabled := R.EditEnabled('EditRedoCommand');
    EditCutCommand.Enabled := R.EditEnabled('EditCutCommand');
    EditCopyCommand.Enabled := R.EditEnabled('EditCopyCommand');
    EditPasteCommand.Enabled := R.EditEnabled('EditPasteCommand');
    EditDeleteCommand.Enabled := R.EditEnabled('EditDeleteCommand');
    EditSelectAllCommand.Enabled := R.EditEnabled('EditSelectAllCommand');
  end;
  aToggleComment.Enabled := Ed <> nil;
  aIndent.Enabled := Ed <> nil;
  aUnindent.Enabled := Ed <> nil;
  aDuplicateLine.Enabled := (Ed <> nil) and not Ed.ReadOnly;
  aMoveLinesUp.Enabled := aDuplicateLine.Enabled;
  aMoveLinesDown.Enabled := aDuplicateLine.Enabled;
  aJoinLines.Enabled := aDuplicateLine.Enabled;
  aSelectNextOccurrence.Enabled := Ed <> nil;
  aSelectAllOccurrences.Enabled := Ed <> nil;
  aAddCaretAbove.Enabled := Ed <> nil;
  aAddCaretBelow.Enabled := Ed <> nil;
  aExpandSelection.Enabled := Ed <> nil;
  aShrinkSelection.Enabled := (Ed <> nil) and Ed.CanShrinkSelection;
  for FA := Low(TSciFoldAction) to High(TSciFoldAction) do
    FoldAction(FA).Enabled := (Ed <> nil) and Ed.CanFold(FA);
  aCodeFolding.Checked := EditorOptions.ShowFolding;
  { the zoom of the view shown (SdZoom) }
  ZV := DocZoomView(ActiveDoc);
  aZoomIn.Enabled := (ZV <> nil) and ZV.CanZoom(1);
  aZoomOut.Enabled := (ZV <> nil) and ZV.CanZoom(-1);
  aZoomReset.Enabled := (ZV <> nil) and (ZV.ZoomPercent <> 100);
  aZoomFit.Enabled := (ZV <> nil) and ZV.CanZoomFit;
  if ShowZoomFit(ZV) then ArrangePageBar(ActiveDoc);
  aFormatSource.Enabled :=(Ed <> nil) and not Ed.ReadOnly and P.CanFormat;
  EditLockControlsCommand.Enabled := D <> nil;
  EditLockControlsCommand.Checked := (D <> nil) and D.Locked;
  SearchFindCommand.Enabled := Ed <> nil;
  SearchReplaceCommand.Enabled := Ed <> nil;
  SearchAgainCommand.Enabled := (Ed <> nil) and (FFind.FindText <> '');
  SearchGoToCommand.Enabled := Ed <> nil;
  SearchIncrementalCommand.Enabled := Ed <> nil;
  aFindDecl.Enabled := Pas;
  aComplete.Enabled := Pas;
  aTemplates.Enabled := (Ed <> nil);
  aParams.Enabled := Pas;
  ViewToggleFormCommand.Enabled := (P <> nil) and P.HasForm;
  aViewDiagram.Enabled := (P <> nil) and P.CanDiagram;
  aViewDiagram.Checked := aViewDiagram.Enabled and P.DiagramView;
  { the Diagram tab's tool bar }
  if (P <> nil) and P.DiagramView and (P.Diagram <> nil) then Dgm := P.Diagram else Dgm := nil;
  aDiagExpandAll.Enabled := (Dgm <> nil) and Dgm.CanExpand;
  aDiagCollapseAll.Enabled := (Dgm <> nil) and Dgm.CanCollapse;
  aDiagReset.Enabled := Dgm <> nil;
  { the History tab: its tool bar and menu act on the page shown's }
  aViewHistory.Enabled := (P <> nil) and P.CanHistory;
  aViewHistory.Checked := aViewHistory.Enabled and P.HistoryView;
  if (P <> nil) and P.HistoryView and (P.History <> nil) then Hv := P.History else Hv := nil;
  aHistPrevChange.Enabled := (Hv <> nil) and Hv.CanGotoChange(False);
  aHistNextChange.Enabled := (Hv <> nil) and Hv.CanGotoChange(True);
  aHistSideBySide.Enabled := Hv <> nil;
  aHistSideBySide.Checked := HistorySideBySide;
  aHistIgnoreBlanks.Enabled := Hv <> nil;
  aHistIgnoreBlanks.Checked := HistoryIgnoreBlanks;
  aHistComparePrev.Enabled := Hv <> nil;
  aHistComparePrev.Checked := HistoryComparePrevious;
  aHistRestore.Enabled := (Hv <> nil) and Hv.CanRestore;
  aHistRestoreChange.Enabled := (Hv <> nil) and Hv.CanRestoreChange;
  aHistLabel.Enabled := (Hv <> nil) and Hv.CanLabel;
  aHistRemoveLabel.Enabled := (Hv <> nil) and Hv.CanRemoveLabel;
  aHistGotoCode.Enabled := (Hv <> nil) and Hv.CanGotoCode;
  aHistCopy.Enabled := (Hv <> nil) and Hv.CanCopy;
  aHistRoutine.Enabled := Pas and P.CanHistory;
  ViewUnitCommand.Enabled := HasProj;
  ViewFormCommand.Enabled := HasProj;
  ProjectAddCommand.Enabled := HasProj;
  ProjectRemoveCommand.Enabled := HasProj;
  ProjectViewSourceCommand.Enabled := HasProj;
  aFormatProject.Enabled := HasProj and not FCompiler.Running;
  ProjectCompileCommand.Enabled := HasProj and not Dbg and not FCompiler.Running;
  ProjectBuildCommand.Enabled := ProjectCompileCommand.Enabled;
  ProjectSyntaxCommand.Enabled := ProjectCompileCommand.Enabled;
  aInstallPackage.Enabled := ProjectCompileCommand.Enabled and FProject.IsPackage and (FProject.Platform = spWin32);
  aUninstallPackage.Enabled := aInstallPackage.Enabled and (InstalledPackage(FProject) <> nil);
  { the package editors that are seen, each for its own package: Install is Uninstall while the
    package is installed }
  for I := 0 to FPkgViews.Count - 1 do
  begin
    V := TSdPackageView(FPkgViews[I]);
    if not FDock.PanelOf(V).Visible then Continue;
    V.aPkgAdd.Enabled := (V.Project <> nil) and not Dbg and not FCompiler.Running;
    V.aPkgCompile.Enabled := V.aPkgAdd.Enabled;
    V.aPkgBuild.Enabled := V.aPkgAdd.Enabled;
    V.aPkgRemove.Enabled := V.aPkgAdd.Enabled and ((V.SelectedUnit <> nil) or (V.SelectedPackage <> ''));
    V.aPkgInstall.Enabled := V.aPkgAdd.Enabled and (V.Project.Platform = spWin32);
    if V.aPkgInstall.Enabled and (InstalledPackage(V.Project) <> nil) then S := 'Uninstall' else S := 'Install';
    if V.aPkgInstall.Caption <> S then
    begin
      V.aPkgInstall.Caption := S;
      V.aPkgInstall.Hint := S + ' package';
    end;
    V.aPkgOptions.Enabled := V.Project <> nil;
    V.aPkgViewSource.Enabled := V.Project <> nil;
    V.aPkgOpen.Enabled := V.SelectedUnit <> nil;
  end;
  aViewPackage.Enabled := HasProj and FProject.IsPackage;
  UpdateResourceActions;
  ComponentAddtoPackageCommand.Enabled := not Dbg and not FCompiler.Running;
  ProjectOptionsCommand.Enabled := HasProj;
  { paused: also a program attached to without a project (Run | Attach to Process) }
  RunRunCommand.Enabled := (Paused or (HasProj and not Dbg)) and not FCompiler.Running;
  RunRunNoDebugCommand.Enabled := HasProj and not Dbg and not FCompiler.Running;
  RunParametersCommand.Enabled := HasProj;
  { the debugger is 32-bit: a Win64 program can be run, not stepped }
  RunStepOverCommand.Enabled := RunRunCommand.Enabled and not (HasProj and (FProject.Platform = spWin64) and not Dbg);
  RunTraceIntoCommand.Enabled := RunStepOverCommand.Enabled;
  RunGotoCursorCommand.Enabled := Paused and Code;
  RunUntilReturnCommand.Enabled := Paused;
  RunPauseCommand.Enabled := Dbg and not Paused;
  RunResetCommand.Enabled := Dbg;
  RunEvalModCommand.Enabled := Paused;
  RunInspectCommand.Enabled := Paused;
  aDsnRevert.Enabled := (D <> nil) and D.CanRevert;
  aDsnAddToRepository.Enabled := (D <> nil) and HasProj;
  ProjectAddRepositoryCommand.Enabled := HasProj;
  ToolsGalleryCommand.Enabled := True;
  ViewAddlMsgInfoCommand.Enabled := True;
  ViewBrowserCommand.Enabled := FProject <> nil;
  FBrowser.aBrGoto.Enabled := FBrowser.CanGoto;
  FBrowser.aBrBrowse.Enabled := FBrowser.CanBrowse;
  FBrowser.aBrBack.Enabled := FBrowser.CanBack;
  FBrowser.aBrRefresh.Enabled := FProject <> nil;
  FBrowser.aBrDetails.Checked := FBrowser.Details;
  FTypeLibView.aTlExport.Enabled := FTypeLibView.TypeLib <> nil;
  FTypeLibView.aTlRefresh.Enabled := FTypeLibView.FileName <> '';
  aMhCopy.Enabled := MsgHintsList.ItemIndex >= 0;
  aMhCopyAll.Enabled := MsgHintsList.Items.Count > 0;
  aMhClear.Enabled := aMhCopyAll.Enabled;
  ComponentInstallCompositeCommand.Enabled := (D <> nil) and (D.SelectionCount > 0) and (D.Selections[0] <> D.Root);
  ProjectAddNewProjectCommand.Enabled := HasProj and not FCompiler.Running;
  ProjectAddExistingProjectCommand.Enabled := ProjectAddNewProjectCommand.Enabled;
  FProjView.UpdateCommands(FCompiler.Running, Dbg, FProject);
  FInspector.aOIRevert.Enabled := aDsnRevert.Enabled and RevertableRow(FInspector.Grid.SelectedRow);
  { address and data breakpoints name memory of the program: while it is being debugged }
  RunAddAddressBreakpointCommand.Enabled := Dbg;
  RunAddDataBreakpointCommand.Enabled := Dbg;
  RunAddModuleLoadBreakpointCommand.Enabled := True;
  RunAttachCommand.Enabled := not Dbg;
  RunDetachCommand.Enabled := Dbg;
  FDebugInsp.aDiChange.Enabled := Paused and (FDebugInsp.SelectedExpr <> '');
  FDebugInsp.aDiInspect.Enabled := FDebugInsp.aDiChange.Enabled;
  FDebugInsp.aDiDescend.Enabled := FDebugInsp.aDiChange.Enabled;
  FDebugInsp.aDiNewExpr.Enabled := Paused;
  FDebugInsp.aDiTypeCast.Enabled := Paused and (FDebugInsp.Expression <> '');
  FDebugInsp.aDiSortDecl.Checked := not FDebugInsp.SortByName;
  FDebugInsp.aDiSortName.Checked := FDebugInsp.SortByName;
  FDebugInsp.aDiDynamic.Checked := FDebugInsp.Dynamic;
  FWatchView.aWatchDelete.Enabled := (FDebug.WatchView <> nil) and (FDebug.WatchView.Selected <> nil);
  { not on a form's text (View as Text): its bytes are the form's, kept by the unit's page }
  aReopenEncoding.Enabled := (P <> nil) and not P.Untitled and (P.FormOwner = nil);
  aConvertEncoding.Enabled := (P <> nil) and (P.FormOwner = nil);
  { in the CPU view's disassembly: an address breakpoint (ActRun) }
  aToggleBreak.Enabled := Pas or (Paused and FCpuView.DisasmFocused);
  { Delphi 7's commands }
  if HasProj then
  begin
    ProjectCompileCommand.Caption := '&Compile ' + FProject.Name;
    ProjectBuildCommand.Caption := '&Build ' + FProject.Name;
    ProjectSyntaxCommand.Caption := '&Syntax Check ' + FProject.Name;
    ProjectInformationCommand.Caption := '&Information for ' + FProject.Name;
  end
  else
  begin
    ProjectCompileCommand.Caption := '&Compile';
    ProjectBuildCommand.Caption := '&Build';
    ProjectSyntaxCommand.Caption := '&Syntax Check';
    ProjectInformationCommand.Caption := '&Information...';
  end;
  FileSaveProjectAsCommand.Enabled := HasProj and not FCompiler.Running;
  FileUseUnitCommand.Enabled := Pas and HasProj;
  FilePrintCommand.Enabled := Code;
  ViewWindowListCommand.Enabled := FDocs.Count > 0;
  { Delphi 7: while there is an edit window }
  ViewCodeExplorerCommand.Enabled := FDocs.Count > 0;
  ecViewExplorer.Enabled := ViewCodeExplorerCommand.Enabled;
  ViewNextWindow.Enabled := FDocs.Count > 1;
  ProjectCompileAllCommand.Enabled := ProjectCompileCommand.Enabled;
  ProjectBuildAllCommand.Enabled := ProjectCompileCommand.Enabled;
  RunRegisterComCommand.Enabled := ProjectCompileCommand.Enabled and FProject.IsLibrary and (FProject.Platform = spWin32);
  RunUnregisterComCommand.Enabled := RunRegisterComCommand.Enabled;
  RunShowCSIPCommand.Enabled := Paused;
  EditAlignCommand.Enabled := (D <> nil) and (D.SelectionCount > 0) and (D.Selections[0] <> D.Root);
  EditSizeCommand.Enabled := EditAlignCommand.Enabled;
  EditScaleCommand.Enabled := D <> nil;
  EditTabOrderCommand.Enabled := D <> nil;
  ViewCompListCommand.Enabled := D <> nil;
  EditCreationOrderCommand.Enabled := D <> nil;
  SearchFindErrCommand.Enabled := HasProj and not FCompiler.Running;
  SearchSymbolCommand.Enabled := HasProj or Pas;
  ProjectInformationCommand.Enabled := HasProj;
  { Align to Grid, Bring to Front, Send to Back and Flip Children | Selected act on the selected
    controls, never on the form: enabled while one is selected; Flip Children | All mirrors the
    form's controls: enabled while it has one }
  if D <> nil then N := SelectedControlCount(D) else N := 0;
  EditAlignGridCommand.Enabled := N > 0;
  EditFrontCommand.Enabled := N > 0;
  EditBackCommand.Enabled := N > 0;
  EditFlipChildrenSelectedCommand.Enabled := N > 0;
  EditFlipChildrenAllCommand.Enabled := (D <> nil) and (D.Root is TWinControl) and
    (TWinControl(D.Root).ControlCount > 0);
  { the menus' own names of commands: their states }
  for I := 0 to High(FTwins) do
  begin
    FTwins[I, 0].Enabled := FTwins[I, 1].Enabled;
    FTwins[I, 0].Checked := FTwins[I, 1].Checked;
  end;
  { the ten alignments of the designer's tool bar by the selected controls N (its other buttons'
    commands have their states above) }
  for I := 0 to DesignerBar.ButtonCount - 1 do
    if (DesignerBar.Buttons[I].Action is TAction) and
      AlignActionKind(DesignerBar.Buttons[I].Action, AK, Need) then
      TAction(DesignerBar.Buttons[I].Action).Enabled := N >= Need;
  RunTraceToSourceCommand.Enabled := FDebug.ShownPaused or RunTraceIntoCommand.Enabled;
  aGotoAddress.Enabled := FDebug.ShownPaused;
  { View as Text / View as Form (Alt+F12) }
  ViewSwapSourceFormCommand.Enabled := (P <> nil) and ((P.DesignView and P.HasForm) or (P.FormOwner <> nil));
  aDsnTextDFM.Enabled := (P <> nil) and P.DesignView and P.HasForm;
  aDsnTextDFM.Checked := aDsnTextDFM.Enabled and P.DfmText;
  { the editor's menu }
  aOpenFileAtCursor.Enabled := (Ed <> nil);
  aRecordMacro.Enabled := (Ed <> nil) and not OtaMacroPlaying;
  aPlayMacro.Enabled := (Ed <> nil) and not OtaMacroRecording and (OtaMacroLength > 0);
  aTopicSearch.Enabled := (Ed <> nil);
  EditAddToDoItemCommand.Enabled := (Ed <> nil) and not Ed.ReadOnly;
  ecCompleteClass.Enabled := Pas and not Ed.ReadOnly;
  aReadOnly.Enabled := (Ed <> nil);
  aReadOnly.Checked := (Ed <> nil) and Ed.ReadOnly;
  aMessageView.Checked := FBottomPanels[BT_MESSAGES].Showing;
  for I := 0 to 9 do
  begin
    FBookmarkActions[I, False].Enabled := Ed <> nil;
    FBookmarkActions[I, True].Enabled := Ed <> nil;
  end;
end;

procedure TMainForm.UpdateStatus;
var
  P: TEditorPage;
  ZV: ISdZoomView;
  W: Integer;
begin
  if StatusBar = nil then Exit;
  P := ActivePage;
  if (P = nil) or not P.CodeView then
  begin
    StatusBar.Panels[spPosition].Text := '';
    StatusBar.Panels[spMode].Text := '';
  end
  else
  begin
    StatusBar.Panels[spPosition].Text := Format('%d: %d', [P.Editor.CaretLine + 1, P.Editor.CaretCol + 1]);
    if P.Editor.Overwrite then StatusBar.Panels[spMode].Text := 'Overwrite' else StatusBar.Panels[spMode].Text := 'Insert';
  end;
  { a keystroke macro being recorded shows there, as in Delphi }
  if (P <> nil) and P.CodeView and OtaMacroRecording then StatusBar.Panels[spModified].Text := 'Recording'
  else if (ActiveDoc <> nil) and DocModified(ActiveDoc) then StatusBar.Panels[spModified].Text := 'Modified'
  else StatusBar.Panels[spModified].Text := '';
  if P <> nil then StatusBar.Panels[spEncoding].Text := EncodingShortName(P.Encoding) else StatusBar.Panels[spEncoding].Text := '';
  { the zoom of the view shown beside the encoding while it is not 100 % (SdZoom: the editors' - the
    font's size in points and Scintilla's points added to it -, the designer's, the diagram's, a
    resource editor's) }
  ZV := DocZoomView(ActiveDoc);
  if (ZV <> nil) and (ZV.ZoomPercent <> 100) then
  begin
    if StatusBar.Panels[spEncoding].Text <> '' then
      StatusBar.Panels[spEncoding].Text := StatusBar.Panels[spEncoding].Text + '  ';
    StatusBar.Panels[spEncoding].Text := StatusBar.Panels[spEncoding].Text + ZoomText(ZV.ZoomPercent);
  end;
  { the panel as wide as its text, at least as wide as the form file has it }
  if FEncodingWidth = 0 then FEncodingWidth := StatusBar.Panels[spEncoding].Width;
  if StatusBar.HandleAllocated then
  begin
    StatusBar.Canvas.Font := StatusBar.Font;
    W := StatusBar.Canvas.TextWidth(StatusBar.Panels[spEncoding].Text) + 16;
    if W < FEncodingWidth then W := FEncodingWidth;
    if StatusBar.Panels[spEncoding].Width <> W then StatusBar.Panels[spEncoding].Width := W;
  end;
  UpdateErrorInsight;
end;

{ Error Insight's errors of the page shown: their number in the status bar, their list in the
  Error List (made again only for another page or another list of errors), which comes to the
  front of its group when the page shown gets errors - it does not slide out of a hidden edge -
  and its tab's title is red while there are any }
procedure TMainForm.UpdateErrorInsight;
var
  P: TEditorPage;
  I: Integer;
  E: TCIError;
  Has: Boolean;
begin
  P := ActivePage;
  Has := (P <> nil) and (P.ErrorCount > 0);
  if not Has then StatusBar.Panels[spErrors].Text := ''
  else if P.ErrorCount = 1 then StatusBar.Panels[spErrors].Text := '1 error'
  else StatusBar.Panels[spErrors].Text := Format('%d errors', [P.ErrorCount]);
  if (FBottomPanels[BT_ERRORS] <> nil) and not FClosing then
  begin
    if Has then FBottomPanels[BT_ERRORS].TabTextColor := UIErrorTabText
    else FBottomPanels[BT_ERRORS].TabTextColor := clNone;
    if Has and not FErrorListHad then ShowBottom(BT_ERRORS, False);
  end;
  FErrorListHad := Has;
  if (P = FErrorListPage) and ((P = nil) or (P.ErrorsStamp = FErrorListStamp)) then Exit;
  FErrorListPage := P;
  if P <> nil then FErrorListStamp := P.ErrorsStamp;
  ErrorList.Items.BeginUpdate;
  try
    ErrorList.Items.Clear;
    if P <> nil then
      for I := 0 to P.ErrorCount - 1 do
      begin
        E := P.Errors[I];
        ErrorList.Items.AddObject(Format('[Error] %s(%d): %s', [ExtractFileName(P.FileName), E.Line,
          EditorToAnsi(E.Msg, P.Encoding)]), TObject(I));
      end;
  finally
    ErrorList.Items.EndUpdate;
  end;
end;

{ a click on the status bar's count of errors shows the Error List }
procedure TMainForm.StatusBarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I, Right: Integer;
begin
  if (Button <> mbLeft) or (StatusBar.Panels[spErrors].Text = '') then Exit;
  Right := 0;
  for I := 0 to spErrors do Inc(Right, StatusBar.Panels[I].Width);
  if (X >= Right - StatusBar.Panels[spErrors].Width) and (X < Right) then ShowBottom(BT_ERRORS);
end;

{ an error of the list: its place in the page shown (the list is the page's) }
procedure TMainForm.ErrorListDblClick(Sender: TObject);
var
  P: TEditorPage;
  I: Integer;
begin
  P := ActivePage;
  I := ErrorList.ItemIndex;
  if (P = nil) or (P <> FErrorListPage) or (I < 0) then Exit;
  I := Integer(ErrorList.Items.Objects[I]);
  if I >= P.ErrorCount then Exit;
  NavMark;
  ShowPageLine(P, P.Errors[I].Line, P.Errors[I].Col);
end;

procedure TMainForm.UpdateCaption;
var
  S: string;
begin
  S := AppTitle;
  if FProject <> nil then S := S + ' - ' + FProject.Name;
  if FDebug <> nil then
    if FDebug.ShownPaused then S := S + ' [Stopped]'
    else if FDebug.Active then S := S + ' [Running]';
  Caption := S;
  Application.Title := S;
  if (FProject <> nil) and NeedsUnicode(FProject.FileName) then
    SetWindowTextUnicode(Handle, AppTitle + ' - ' +
      WideChangeFileExt(WideFileName(DisplayPath(FProject.FileName)), '') + Copy(S, Length(AppTitle + ' - ' + FProject.Name) + 1, MaxInt));
end;

{ a file name as a menu caption: its "&" is no access key }
function NoAccel(const S: string): string;
begin
  Result := StringReplace(S, '&', '&&', [rfReplaceAll]);
end;

{ the Watch List's Move Watch To Group: the other groups, an action each (WatchGroupActions; Tag
  the group), made when its menu opens - as Delphi's WatchMenuPopup does }
procedure TMainForm.WatchGroupMenu;
var
  L: TStringList;
  I: Integer;
begin
  FWatchView.pmWatch16.Clear;
  ClearActions(WatchGroupActions);
  L := TStringList.Create;
  try
    FDebug.GetWatchGroups(L);
    for I := 0 to L.Count - 1 do
      if I <> FDebug.WatchGroup then
        NewActionItem(FWatchView.pmWatch16, NewAction(WatchGroupActions, NoAccel(L[I]), L[I], I, WatchMoveExecute));
  finally
    L.Free;
  end;
end;

procedure TMainForm.WatchMoveExecute(Sender: TObject);
begin
  FDebug.MoveSelectedWatches(TAction(Sender).Tag);
end;

{ the Object Inspector's View (Delphi's ViewWhatClick): a check item per category of the
  properties shown, sorted, an action each (InspCategoryActions; the action's Category is the
  property category), before All - while one is hidden -, Toggle and None - while one is shown;
  Arrange's choice }
procedure TMainForm.InspViewMenu;
var
  L: TStringList;
  I: Integer;
  A: TAction;
  AnyShown, AnyHidden: Boolean;
begin
  while FInspector.pmInsp1.Items[0] <> FInspector.pmInspViewBar do FInspector.pmInsp1.Items[0].Free;
  ClearActions(InspCategoryActions);
  AnyShown := False;
  AnyHidden := False;
  L := TStringList.Create;
  try
    FInspector.Grid.ViewCategories(L);
    for I := 0 to L.Count - 1 do
    begin
      A := NewAction(InspCategoryActions, NoAccel(L[I]),
        'Show or hide the properties of the category (Ctrl: only these, Ctrl+Shift: all others)', 0,
        InspCategoryExecute);
      A.Category := L[I];
      A.Checked := TPropertyCategory(L.Objects[I]).Visible;
      if A.Checked then AnyShown := True else AnyHidden := True;
      NewActionItem(FInspector.pmInsp1, A, I);
    end;
  finally
    L.Free;
  end;
  FInspector.aOIViewAll.Enabled := AnyHidden;
  FInspector.aOIViewNone.Enabled := AnyShown;
  FInspector.aOIArrangeCategory.Checked := FInspector.Grid.ByCategory;
  FInspector.aOIArrangeName.Checked := not FInspector.Grid.ByCategory;
end;

procedure TMainForm.InspCategoryExecute(Sender: TObject);
begin
  FInspector.Grid.ClickCategory(TAction(Sender).Category, KeyboardStateToShiftState);
end;

{ the Object Inspector's View | All, Toggle, None and Arrange | by Category, by Name }
procedure TMainForm.ActInspView(Sender: TObject);
begin
  if Sender = FInspector.aOIViewAll then FInspector.Grid.ShowCategories(pcvAll)
  else if Sender = FInspector.aOIViewToggle then FInspector.Grid.ShowCategories(pcvToggle)
  else if Sender = FInspector.aOIViewNone then FInspector.Grid.ShowCategories(pcvNone)
  else FInspector.Grid.ByCategory := Sender = FInspector.aOIArrangeCategory;
end;

{ File | Reopen and the drop-down of Open on the tool bar: one action per recent project and
  file (ReopenActions), the same entries in both; a name outside the code page is drawn by D7
  Studio, in Unicode (the VCL draws ANSI captions) }
procedure TMainForm.UpdateReopenMenu;
var
  L: TStringList;
  I: Integer;

  procedure AddTo(Menu: TMenuItem; A: TAction);
  begin
    if A = nil then Menu.Add(NewLine) else NewActionItem(Menu, A);
  end;

  procedure Add(A: TAction);
  begin
    AddTo(FileClosedFilesItem, A);
    AddTo(ClosedFilesPopup.Items, A);
  end;

begin
  FReopenStale := False;
  FileClosedFilesItem.Clear;
  ClosedFilesPopup.Items.Clear;
  ClearActions(ReopenActions);
  L := TStringList.Create;
  try
    GetRecent('RecentProjects', L);
    for I := 0 to L.Count - 1 do
      Add(NewAction(ReopenActions, Format('&%d %s', [I, NoAccel(L[I])]), L[I], 0, ReopenExecute));
    if L.Count > 0 then Add(nil);
    GetRecent('RecentFiles', L);
    for I := 0 to L.Count - 1 do
      Add(NewAction(ReopenActions, Format('&%s %s', [Chr(Ord('A') + I), NoAccel(L[I])]), L[I], 0, ReopenExecute));
  finally
    L.Free;
  end;
  FileClosedFilesItem.Enabled := ReopenActions.ActionCount > 0;
end;
procedure TMainForm.ReopenExecute(Sender: TObject);
var
  F: string;
begin
  { a reference of its own: opening remakes the Reopen list, which frees this action and the
    Hint that held the name }
  F := TAction(Sender).Hint;
  OpenAny(F);
end;

{ --- the main menu ---------------------------------------------------------------------------

  The form's TMainMenu MainMenu, drawn by the VCL with the icons of Icons (the IDE uses only
  TMainMenu, TToolBar and TPopupMenu; it was Delphi's TActionMainMenuBar).
  Window (the open files) and Tools (the programs of Configure Tools) are made again from their
  data when they open; File's Reopen list is kept up to date (UpdateReopenMenu). }
procedure TMainForm.WMInitMenuPopup(var Message: TWMInitMenuPopup);
var
  Item: TMenuItem;
begin
  if Message.SystemMenu then
  begin
    inherited;
    Exit;
  end;
  if Message.MenuPopup = WindowsMenu.Handle then UpdatePageItems(WindowsMenu, False)
  else if Message.MenuPopup = ToolsMenu.Handle then UpdateToolsMenu;
  Item := Menu.FindItem(Message.MenuPopup, fkHandle);
  { a submenu filled when its menu opened is not clicked again: its OnClick would make its items
    anew while Windows opens it - and the VCL then makes its parent menu anew too, which takes the
    item being opened away (the submenu does not open) }
  if (Item = nil) or (FFilledMenus = nil) or (FFilledMenus.IndexOf(Item) < 0) then inherited;
  if Item <> nil then FillSubmenus(Item);
end;

{ The submenus of a menu that opens whose items their OnClick makes - an expert's, as GExperts'
  File | GExperts Favorites (D7 Studio's own commands are actions): clicked now, while their
  parent's items may still change, and not again while the menus stay open (WMInitMenuPopup).
  Delphi's VCL clicks a submenu's item when the submenu opens, and a submenu that is filled then
  first loses its items and gets new ones: its parent menu is made again under the submenu. }
procedure TMainForm.FillSubmenus(Item: TMenuItem);
var
  I: Integer;
  Sub: TMenuItem;
begin
  I := 0;
  while I < Item.Count do
  begin
    Sub := Item[I];
    if (Sub.Count > 0) and Sub.Visible and Sub.Enabled and Assigned(Sub.OnClick) and (Sub.Action = nil) then
    begin
      if FFilledMenus = nil then FFilledMenus := TList.Create;
      if FFilledMenus.IndexOf(Sub) < 0 then
      begin
        try
          Sub.Click;
        except
          on E: Exception do LogException(E, 'menu', SettingsDir + 'error.log');
        end;
        { the click may have made the menu's items anew: the item is looked for again }
        if (I < Item.Count) and (Item[I] = Sub) then
        begin
          FFilledMenus.Add(Sub);
          Sub.FreeNotification(Self);
        end;
      end;
    end;
    Inc(I);
  end;
end;

{ the menus closed: the next time a submenu opens it is filled again }
procedure TMainForm.WMExitMenuLoop(var Message: TMessage);
begin
  if FFilledMenus <> nil then FFilledMenus.Clear;
  inherited;
end;

{ a filled submenu's item that an expert frees (its menu made anew) leaves the list }
procedure TMainForm.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (FFilledMenus <> nil) then FFilledMenus.Remove(AComponent);
end;

{ Windows asks before it ends the session (WM_QUERYENDSESSION -> CloseQuery: the project and the
  files close, FClosing is set); when another program refuses, the session goes on and the IDE
  must work again - without what CloseQuery closed }
procedure TMainForm.WMEndSession(var Message: TWMEndSession);
begin
  if not Message.EndSession then FClosing := False;
  inherited;
end;

{ Minimizing the IDE minimizes the application's window, and Windows hides only the windows that
  window owns: this one. The windows this one owns - the floating dock groups, Borland's
  design-time windows, the Customize dialog - would stay on the screen, so they are hidden with
  it and shown again with it. ShowOwnedPopups(True) shows only those that ShowOwnedPopups(False)
  hid. }
procedure TMainForm.WMShowWindow(var Message: TWMShowWindow);
begin
  inherited;
  case Message.Status of
    SW_PARENTCLOSING: ShowOwnedPopups(Handle, False);
    SW_PARENTOPENING: ShowOwnedPopups(Handle, True);
  end;
end;

{ the open pages - files and resources -, one entry each, the active one checked: the Window menu (then Next Window),
  the Pages menu of the file tabs and the drop-down at the end of their row (these two in
  alphabetical order with Editor Options | Sort pages menu, as Delphi 7 sorts it). One action list
  for all: only one of them is open at a time }
{ a menu item of a list that comes from data: its action belongs to List (or it is Line) }
function ListItem(Item: TMenuItem; List: TActionList; Line: TMenuItem): Boolean;
begin
  Result := (Item = Line) or ((Item.Action is TContainedAction) and (TContainedAction(Item.Action).ActionList = List));
end;

procedure TMainForm.UpdatePageItems(Menu: TMenuItem; Sorted: Boolean);
const
  PageLineTag = 7901;              // the Window menu's line below the files
var
  I, K: Integer;
  A: TAction;
  L: TStringList;
  Line: TMenuItem;
  Doc: TWinControl;
  Hint: string;

  procedure ClearPageItems(M: TMenuItem);
  var
    I: Integer;
  begin
    for I := M.Count - 1 downto 0 do
      if (M[I].Tag = PageLineTag) or ListItem(M[I], WindowActions, nil) then M[I].Free;
  end;

begin
  { the pages' entries (at the top) and their line go; Next Window and what an expert added stay.
    The three menus share the action list freed below: an entry left in one of the others would
    stay there without its action, and would no longer be known as an entry }
  ClearPageItems(WindowsMenu);
  ClearPageItems(pmTabPages);
  ClearPageItems(FilesMenu.Items);
  ClearActions(WindowActions);
  L := TStringList.Create;
  try
    for I := 0 to FDocs.Count - 1 do L.AddObject(NoAccel(DocTitle(TWinControl(FDocs[I]))), TObject(I));
    if Sorted then L.Sort;
    for I := 0 to L.Count - 1 do
    begin
      K := Integer(L.Objects[I]);
      Doc := TWinControl(FDocs[K]);
      if Doc is TEditorPage then Hint := TEditorPage(Doc).FileName
      else Hint := TSdResPage(Doc).Title + ' - ' + TSdResPage(Doc).ResFile;
      A := NewAction(WindowActions, L[I], Hint, K, WindowExecute);
      A.Checked := Doc = ActiveDoc;
      NewActionItem(Menu, A, I);
    end;
  finally
    L.Free;
  end;
  if (Menu = WindowsMenu) and (FDocs.Count > 0) then
  begin
    Line := NewLine;
    Line.Tag := PageLineTag;
    Menu.Insert(FDocs.Count, Line);
  end;
end;

{ Debugger Options | Map TD32 keystrokes on run: while a program is debugged, Turbo Debugger's
  keys as well - F2 toggles a breakpoint, Alt+F2 adds one, Ctrl+F4 evaluates, Ctrl+F7 adds a
  watch, Alt+F8 runs until return (the keys both have, F4 F7 F8 F9 Ctrl+F2, are the same) }
procedure TMainForm.FormShortCut(var Msg: TWMKey; var Handled: Boolean);
var
  A: TAction;
  R: TSdResPage;
begin
  { a resource page's editor has its own keys (Visual Studio's image editor's ...) while the
    keyboard is in it, before the menus' and the actions' (SdResPage) }
  R := ActiveResPage;
  if (R <> nil) and R.HasFocus and R.IsShortCut(Msg) then
  begin
    Handled := True;
    Exit;
  end;
  if not (DebuggerOptions.TD32Keys and FDebug.Active) then Exit;
  case ShortCut(Msg.CharCode, KeyDataToShiftState(Msg.KeyData)) of
    VK_F2: A := aToggleBreak;
    VK_F2 or scAlt: A := RunAddSourceBreakpointCommand;
    VK_F4 or scCtrl: A := RunEvalModCommand;
    VK_F7 or scCtrl: A := RunAddWatchCommand;
    VK_F8 or scAlt: A := RunUntilReturnCommand;
  else
    Exit;
  end;
  A.Update;
  if A.Enabled then A.Execute;
  Handled := True;
end;
{ a source line for the CPU view's disassembly (IDE text, as its list shows it): from the open
  page, else from the file as the editor would open it - its lines kept while the file stays as
  it was (its stamp), and while it is not open (its encoding may change in a page) }
function TMainForm.SourceLineText(const FileName: string; Line: Integer): string;
var
  P: TEditorPage;
  E: TSdEncoding;
  Stamp: TSdFileStamp;
begin
  Result := '';
  P := FindPage(FileName);
  if P <> nil then
  begin
    if SameText(FSourceCacheName, FileName) then FSourceCacheName := '';
    Result := EditorToAnsi(P.Editor.GetLineText(Line - 1), P.Encoding);
    Exit;
  end;
  if FSourceCache = nil then FSourceCache := TStringList.Create;
  Stamp := FileStampU(FileName);
  if not SameText(FSourceCacheName, FileName) or not SameFileStamp(Stamp, FSourceCacheStamp) then
  begin
    FSourceCache.Clear;
    FSourceCacheName := FileName;
    FSourceCacheStamp := Stamp;
    if Stamp.Exists then
      try
        FSourceCache.Text := EditorToAnsi(ReadSourceFile(FileName, E), E);
      except
      end;
  end;
  if (Line >= 1) and (Line <= FSourceCache.Count) then Result := FSourceCache[Line - 1];
end;

{ Goto Address (the CPU view's Ctrl+G, the editor's Debug menu): an address in hexadecimal or
  an expression of the program (a pointer) - the disassembly, or the dump when it has the focus }
{ the expression at the caret for the debugger's commands: the selection, else the word there }
function TMainForm.CursorExpression(P: TEditorPage): string;
begin
  Result := '';
  if (P = nil) or not P.CodeView then Exit;
  { the debugger's dialogs take text of the system code page: the selection converted from the
    file's encoding (DesignatorAtCaret is ANSI already) }
  if P.Editor.SelEnd > P.Editor.SelStart then Result := EditorToAnsi(P.Editor.SelText, P.Editor.Encoding)
  else Result := P.DesignatorAtCaret;
end;

{ Run | Inspect, and the Debug Inspector's own Inspect / Descend / New Expression / Type Cast:
  Expr in the inspector, which is shown. Delphi opens a window for each Inspect; the view keeps
  the expressions inspected before in its list instead. }
procedure TMainForm.InspectExpression(const Expr: string);
begin
  if not FDebug.Paused then Exit;
  FDebug.MachineViewFresh(FDebugInsp);     // Inspect fills it: no catching up when it is shown
  ShowDockPanel(FMachinePanels[4]);
  FDebugInsp.Inspect(FDebug.Debugger, Expr);
end;

procedure TMainForm.DebugInspDescend(Sender: TObject);
begin
  if FDebugInsp.SelectedExpr <> '' then InspectExpression(FDebugInsp.SelectedExpr);
end;

{ a double click (and Enter, where a view has it) on a view whose local menu has the command:
  the command's action, so that both take the same path and the action's state (made current
  first: the click may have changed the selection since the last idle) }
procedure TMainForm.ViewDblClick(Sender: TObject);
begin
  UpdateActionStates;
  if Sender = CallStackList then aStackViewSource.Execute
  else if Sender = WatchTree then
  begin
    if WatchTree.Selected = nil then FWatchView.aWatchNew.Execute;
  end
  else if Sender = FCompBar then FCompBar.aCompAdd.Execute
  else if Sender = FBrowser then FBrowser.aBrGoto.Execute
  else if Sender = FDebugInsp then FDebugInsp.aDiDescend.Execute;
end;

{ View | Additional Message Info and the commands of its view: Delphi's Message Hints }
procedure TMainForm.ActMsgHints(Sender: TObject);
begin
  if Sender = ViewAddlMsgInfoCommand then ViewDockPanel(FMsgHintsPanel)
  else if Sender = aMhClear then FMsgHints.ShowMessages(nil)
  else if Sender = aMhCopy then Clipboard.AsText := FMsgHints.SelectedText
  else if Sender = aMhCopyAll then Clipboard.AsText := FMsgHints.AllText
  else if Sender = aMhEdit then
    { the explanations are D7 Studio's own copy of Delphi's file from now on (read again at
      the next compile when it has changed) }
    OpenFile(EditableMsgInfoFile, True);
end;

{ View | Browser and the Browser's menu }
procedure TMainForm.ActBrowser(Sender: TObject);
begin
  if Sender = ViewBrowserCommand then ViewDockPanel(FBrowserPanel)
  else if Sender = FBrowser.aBrGoto then FBrowser.GotoSelected
  else if Sender = FBrowser.aBrBrowse then FBrowser.BrowseSelected
  else if Sender = FBrowser.aBrBack then FBrowser.Back
  else if Sender = FBrowser.aBrRefresh then RebuildBrowser
  else if Sender = FBrowser.aBrDetails then FBrowser.Details := not FBrowser.Details
  else if Sender = FBrowser.aBrProperties then ShowOptions(osEnvironment, EnvOptionsExplorerPage);
end;

{ what the Browser browses: the active project's file and its units }
procedure TMainForm.BrowserFiles(Sender: TObject; Files: TStrings);
var
  I: Integer;
begin
  if FProject = nil then Exit;
  Files.Add(FProject.FileName);
  for I := 0 to FProject.UnitCount - 1 do
    if FileExistsU(FProject.Units[I].FileName) or (FindPage(FProject.Units[I].FileName) <> nil) then
      Files.Add(FProject.Units[I].FileName);
end;

procedure TMainForm.RebuildBrowser;
begin
  FBrowserStale := False;
  FBrowser.Rebuild;
end;

{ a file saved: the Browser shown is made again once the saves of this command are over (Save All:
  once), when the file is one of the active project's; a compile that rebuilds it first makes that
  rebuild needless }
procedure TMainForm.BrowserFileSaved(const FileName: string);
var
  Files: TStringList;
begin
  if FClosing or (FBrowserPanel = nil) or not FBrowserPanel.Showing then Exit;
  Files := TStringList.Create;
  try
    BrowserFiles(Self, Files);
    if Files.IndexOf(FileName) < 0 then Exit;
  finally
    Files.Free;
  end;
  FBrowserStale := True;
  if FBrowserPosted or not HandleAllocated then Exit;
  FBrowserPosted := True;
  PostMessage(Handle, WM_SDBROWSERREBUILD, 0, 0);
end;

procedure TMainForm.WMBrowserRebuild(var Message: TMessage);
begin
  FBrowserPosted := False;
  if FClosing or not FBrowserStale or not FBrowserPanel.Showing then Exit;
  RebuildBrowser;
end;

{ ---------------------------------------------------------------- updates }

procedure TMainForm.CheckForUpdates(Manual: Boolean);
begin
  if FUpdateCheck <> nil then Exit;
  if not Manual then
  begin
    if not UpdateCheckDue then Exit;
    { a setup that a former update downloaded has run by now }
    RemoveUpdateFolder;
  end
  else if StatusBar <> nil then
    StatusBar.Panels[spMessage].Text := 'Checking for updates...';
  aCheckUpdates.Enabled := False;
  try
    FUpdateCheck := TSdUpdateCheck.Create(Manual, UpdateCheckEnded);
  except
    { no thread: the command reports it, the check at start-up says nothing (as when it fails) }
    on E: Exception do
    begin
      aCheckUpdates.Enabled := True;
      if not Manual then Exit;
      if StatusBar <> nil then StatusBar.Panels[spMessage].Text := '';
      UpdateCheckFailed(E.Message);
    end;
  end;
end;

procedure TMainForm.UpdateCheckFailed(const Error: string);
begin
  MessageBox(Handle, PChar('D7 Studio could not check for updates.'#13#10#13#10 + Error), AppTitle,
    MB_OK or MB_ICONERROR);
end;

{ the check's OnTerminate, in the main thread. An automatic check that failed says nothing and runs
  again at the next start }
procedure TMainForm.UpdateCheckEnded(Sender: TObject);
var
  C: TSdUpdateCheck;
  Latest: string;
begin
  C := Sender as TSdUpdateCheck;
  FUpdateCheck := nil;
  aCheckUpdates.Enabled := True;
  if C.Manual and (StatusBar <> nil) then StatusBar.Panels[spMessage].Text := '';
  if FClosing then Exit;
  if C.Error <> '' then
  begin
    if C.Manual then UpdateCheckFailed(C.Error);
    Exit;
  end;
  if not C.Manual then UpdateCheckDone;
  if C.HasRelease and IsNewerRelease(C.Release) then
  begin
    FUpdateRelease := C.Release;
    { Help | Check for Updates answers at once; the automatic check waits until AppIdle finds D7 Studio
      active and free }
    if C.Manual then PostMessage(Handle, WM_SDSHOWUPDATE, 0, 0)
    else FUpdateFound := True;
  end
  else if C.Manual then
  begin
    if C.HasRelease then Latest := 'the latest release is ' + C.Release.Version
    else Latest := 'there is no release with a setup';
    MessageBox(Handle, PChar(Format('D7 Studio %s is up to date: %s.', [CurrentVersion, Latest])), AppTitle,
      MB_OK or MB_ICONINFORMATION);
  end;
end;

{ the newer release's dialog; with its setup downloaded and checked, D7 Studio closes as File | Exit
  does (modified files are asked about) and D7Studio.dpr starts the setup. The dialog shows once for
  both checks: a release the automatic check still holds is dropped with it }
procedure TMainForm.WMShowUpdate(var Message: TMessage);
var
  Setup: string;
  OK: Boolean;
begin
  FUpdateFound := False;
  if FClosing or FUpdateShowing then Exit;
  FUpdateShowing := True;
  try
    OK := TUpdateDlg.Execute(Self, FUpdateRelease, Setup);
  finally
    FUpdateShowing := False;
  end;
  if OK then
  begin
    FUpdateSetup := Setup;
    PostMessage(Handle, WM_CLOSE, 0, 0);
  end;
end;

procedure TMainForm.BrowserGoto(Sender: TObject; const FileName: string; Line, Col: Integer);
begin
  FServices.OpenFileAt(FileName, Line, Col);
end;

{ project groups: Project | Add New / Existing Project, the Project Manager's Save Project Group
  (As), Activate, Remove Project, and the commands of the chosen project node - Save, Options,
  Compile, Build, View Source act on that project, active or not (Delphi's TStdProjectContainer) }
procedure TMainForm.ActGroup(Sender: TObject);
var
  P: TSdProject;
begin
  if Sender = ProjectAddNewProjectCommand then AddNewProject
  else if Sender = ProjectAddExistingProjectCommand then AddExistingProject
  else if Sender = FProjView.aSaveGroup then SaveGroup(False)
  else if Sender = FProjView.aSaveGroupAs then SaveGroup(True)
  else if Sender = FProjView.aActivateProject then ActivateProject(FProjView.SelectedProject)
  else if Sender = FProjView.aRemoveProject then RemoveGroupProject(FProjView.SelectedProject, True)
  else
  begin
    P := FGroup.LoadedProjectOf(FProjView.SelectedProject);
    if P = nil then Exit;
    if Sender = FProjView.aPMSave then SaveProject(P)
    else if Sender = FProjView.aPMOptions then ShowProjectOptionsOf(P, 0)
    else if Sender = FProjView.aPMCompile then CompileProject(P, False, False, False)
    else if Sender = FProjView.aPMBuild then CompileProject(P, True, False, False)
    else if Sender = FProjView.aPMViewSource then ViewProjectSource(P);
  end;
end;

{ the Object Repository and the component templates: the designer's Add to Repository (a form),
  Project | Add to Repository, Tools | Repository, Component | Create Component Template }
procedure TMainForm.ActRepository(Sender: TObject);
begin
  if Sender = aDsnAddToRepository then AddToRepository(False)
  else if Sender = ProjectAddRepositoryCommand then AddToRepository(True)
  else if Sender = ToolsGalleryCommand then EditRepository
  else if Sender = ComponentInstallCompositeCommand then CreateCompTemplate;
end;

{ Revert to Inherited: the designer's for the selection, the inspector's for its property }
{ an inspector row whose property Revert to Inherited can take back: a property of the selected
  components themselves (the designer reverts a property by its name: a sub-property's name - the
  Color of Font.Color - would name another one) }
function TMainForm.RevertableRow(R: Integer): Boolean;
begin
  Result := (R >= 0) and (R < FInspector.Grid.RowCount) and not FInspector.Grid.IsCategoryRow(R) and
    FInspector.Grid.Rows[R].Top;
end;

procedure TMainForm.ActRevert(Sender: TObject);
var
  D: TFormDesigner;
  R: Integer;
begin
  D := ActiveDesigner;
  if D = nil then Exit;
  if Sender = FInspector.aOIRevert then
  begin
    R := FInspector.Grid.SelectedRow;
    if RevertableRow(R) then D.RevertToInherited(FInspector.Grid.Rows[R].Name);
  end
  else
    D.RevertToInherited;
end;

procedure TMainForm.ActDebugInsp(Sender: TObject);
var
  V: TDbgVar;
  S, Err: string;
begin
  if Sender = FDebugInsp.aDiSortDecl then FDebugInsp.SortByName := False
  else if Sender = FDebugInsp.aDiSortName then FDebugInsp.SortByName := True
  else if Sender = FDebugInsp.aDiDynamic then FDebugInsp.Dynamic := not FDebugInsp.Dynamic
  else if not FDebug.Paused then Exit
  else if (Sender = FDebugInsp.aDiInspect) or (Sender = FDebugInsp.aDiDescend) then DebugInspDescend(nil)
  else if Sender = FDebugInsp.aDiNewExpr then
  begin
    S := FDebugInsp.Expression;
    if InputDialog(Self, 'Inspect', '&Expression:', S) and (Trim(S) <> '') then InspectExpression(Trim(S));
  end
  else if Sender = FDebugInsp.aDiTypeCast then
  begin
    S := '';
    if InputDialog(Self, 'Type Cast', '&Type:', S) and (Trim(S) <> '') then
      InspectExpression(Trim(S) + '(' + FDebugInsp.Expression + ')');
  end
  else if (Sender = FDebugInsp.aDiChange) and FDebugInsp.Selected(V) and (V.Expr <> '') then
  begin
    S := V.Value;
    if InputDialog(Self, 'Change', Format('&New value for %s:', [V.Name]), S) and
      not FDebug.ModifyValue(V.Expr, S, Err) then
      MessageBox(Handle, PChar(Err), 'Change', MB_OK or MB_ICONERROR);
  end;
end;

{ the address an address text names, as Delphi takes it (Goto Address, the address and data
  breakpoints): a hexadecimal number with or without $, else an expression of the stopped program
  whose value is an address ('@X', a pointer, an integer) }
function TMainForm.ParseAddress(const Text: string; out Addr: Cardinal): Boolean;
var
  S, V: string;
  A: Int64;
begin
  Result := False;
  Addr := 0;
  S := Trim(Text);
  if S = '' then Exit;
  if S[1] <> '$' then
    if TryStrToInt64('$' + S, A) then
      S := '$' + S
    else
    begin
      if not FDebug.EvalValue(S, V) then Exit;
      S := Trim(V);
      if Pos(' ', S) > 0 then S := Copy(S, 1, Pos(' ', S) - 1);
      if Copy(S, 1, 1) = '@' then Delete(S, 1, 1);
    end;
  Result := TryStrToInt64(S, A);
  if Result then Addr := Cardinal(A);
end;

procedure TMainForm.CpuGotoAddress(Sender: TObject);
var
  S: string;
  A: Cardinal;
begin
  if not FDebug.Paused then Exit;
  S := '';
  if not InputDialog(Self, 'Enter Address to Position to', 'Address to position to:', S) or (Trim(S) = '') then Exit;
  if not ParseAddress(S, A) then
  begin
    MessageBox(Handle, PChar('Invalid address: ' + Trim(S)), AppTitle, MB_OK or MB_ICONERROR);
    Exit;
  end;
  ShowDockPanel(FMachinePanels[2]);
  FCpuView.GotoAddress(A);
end;

{ the CPU view's disassembly: 1 an enabled address breakpoint at Addr, 2 a disabled one, 0 none }
function TMainForm.CpuBreakpointAt(Addr: Cardinal): Integer;
var
  BP: TDbgBreakpoint;
begin
  BP := FDebug.AddressBreakpointAt(Addr);
  if BP = nil then Result := 0 else Result := 2 - Ord(BP.Enabled);
end;

{ the focus moved: the dock's captions show where it is }
{ Environment Options | Components: the view's look, Component Bar's sort order, filter reset,
  list colour and the shortcut of View | Components }
procedure TMainForm.ApplyCompBarOptions;
begin
  FCompBar.Classic := EnvOptions.CompClassic;
  FCompBar.HideCategory := EnvOptions.CompHideCategory;
  if (EnvOptions.CompSort >= Ord(Low(TSdCompSort))) and (EnvOptions.CompSort <= Ord(High(TSdCompSort))) then
    FCompBar.SortMode := TSdCompSort(EnvOptions.CompSort);
  FCompBar.ResetDelay := EnvOptions.CompResetDelay;
  FCompBar.ListColor := EnvOptions.CompColor;
  aViewComponents.ShortCut := EnvOptions.CompHotkey;
end;

procedure TMainForm.ActiveControlChange(Sender: TObject);
begin
  if not FClosing and (FDock <> nil) then FDock.FocusChanged;
end;

procedure TMainForm.TabPopupPopup(Sender: TObject);
begin
  UpdatePageItems(pmTabPages, EditorOptions.SortPagesMenu);
  pmTabPages.Enabled := FDocs.Count > 0;      // files and resources
end;

{ The editor's menu, Delphi 7's (its actions and twins in the .dfm), with the name of Delphi's
  edit window's: experts find EditorLocalMenu on INTAEditWindow.Form - this form - and add their
  items, often from an OnPopup of their own that calls this one. Debugger Options |
  Rearrange editor local menu on run: while a program is debugged Delphi's Debug commands come
  first and View as Form, Read Only and Message View go into a View submenu - items with Tag 1
  are shown only then, those with Tag 2 only otherwise; an expert's items (Tag 0) stay as they
  are. }
procedure TMainForm.EditorLocalMenuPopup(Sender: TObject);
var
  I: Integer;
  Lift: Boolean;
begin
  Lift := DebuggerOptions.RearrangeMenu and FDebug.Active;
  for I := 0 to EditorLocalMenu.Items.Count - 1 do
    with EditorLocalMenu.Items[I] do
      if Tag = 1 then Visible := Lift
      else if Tag = 2 then Visible := not Lift;
end;

procedure TMainForm.WindowExecute(Sender: TObject);
var
  I: Integer;
begin
  I := TAction(Sender).Tag;
  if (I >= 0) and (I < FDocs.Count) then ActivatePage(TWinControl(FDocs[I]));
end;

{ Tools: the programs of Configure Tools (Delphi's "Transfer" list) after Configure Tools }
{ the transfer tools after Configure Tools, a line above them; what an expert put into the menu
  stays where it is }
procedure TMainForm.UpdateToolsMenu;
var
  I: Integer;
  L: TStringList;
begin
  for I := ToolsMenu.Count - 1 downto 0 do
    if ListItem(ToolsMenu[I], ToolActions, FToolsLine) then ToolsMenu[I].Free;
  FToolsLine := nil;
  ClearActions(ToolActions);
  L := TStringList.Create;
  try
    GetTransferTools(L);
    if L.Count > 0 then
    begin
      FToolsLine := NewLine;
      ToolsMenu.Insert(ToolsToolsItem.MenuIndex + 1, FToolsLine);
    end;
    for I := 0 to L.Count - 1 do
      NewActionItem(ToolsMenu, NewAction(ToolActions, L.Names[I], L.Names[I], I, ToolExecute),
        FToolsLine.MenuIndex + 1 + I);
  finally
    L.Free;
  end;
end;

procedure TMainForm.ToolExecute(Sender: TObject);
var
  T: TTransferTool;
  Exe, Params, Dir: string;
begin
  if not ReadTransferTool(TAction(Sender).Tag, T) then Exit;
  Exe := ExpandTransferMacros(T.Path);
  Params := ExpandTransferMacros(T.Params);
  Dir := ExpandTransferMacros(T.WorkingDir);
  { $SAVEALL saves every file, $SAVE the current one }
  if Pos('$SAVEALL', UpperCase(T.Params)) > 0 then SaveAllPages
  else if (Pos('$SAVE', UpperCase(T.Params)) > 0) and (ActiveDoc <> nil) and DocModified(ActiveDoc) then
    SaveDoc(ActiveDoc);
  if Pos('$PROMPT', UpperCase(T.Params)) > 0 then
    if not InputDialog(Self, T.Title, 'Parameters:', Params) then Exit;
  if ShellExecute(Handle, nil, PChar(Exe), PChar(Params), PChar(Dir), SW_SHOWNORMAL) <= 32 then
    MessageBox(Handle, PChar('Cannot run ' + Exe + '.'#13#10#13#10 + SysErrorMessage(GetLastError)), AppTitle,
      MB_OK or MB_ICONERROR);
end;

{ Delphi's macros of Configure Tools: $EXENAME, $EDNAME, $PARAMS, $ROW, $COL, $CURTOKEN,
  $PATH(), $DIR(), $NAME(), $NAMEONLY(), $EXT(); $SAVE, $SAVEALL and $PROMPT are actions and
  vanish from the text }
function TMainForm.ExpandTransferMacros(const S: string): string;
const
  FileMacros: array[0..4] of string = ('$PATH(', '$DIR(', '$NAME(', '$NAMEONLY(', '$EXT(');
var
  P: TEditorPage;
  I, A, B: Integer;
  Arg, V: string;

  procedure Put(const Macro, Value: string);
  begin
    Result := StringReplace(Result, Macro, Value, [rfReplaceAll, rfIgnoreCase]);
  end;

begin
  Result := S;
  P := ActivePage;
  if FProject <> nil then
  begin
    Put('$EXENAME', FProject.ExeName);
    Put('$PARAMS', FProject.OptStr('Parameters', 'RunParams', ''));
  end
  else
  begin
    Put('$EXENAME', '');
    Put('$PARAMS', '');
  end;
  if P <> nil then
  begin
    Put('$EDNAME', P.FileName);
    if P.CodeView then
    begin
      Put('$ROW', IntToStr(P.Editor.CaretLine + 1));
      Put('$COL', IntToStr(P.Editor.CaretCol + 1));
      Put('$CURTOKEN', P.WordAtCaret);
    end;
  end;
  Put('$EDNAME', '');
  Put('$ROW', '');
  Put('$COL', '');
  Put('$CURTOKEN', '');
  Put('$SAVEALL', '');
  Put('$SAVE', '');
  Put('$PROMPT', '');
  for I := Low(FileMacros) to High(FileMacros) do
    repeat
      A := Pos(FileMacros[I], UpperCase(Result));
      if A = 0 then Break;
      B := A + Length(FileMacros[I]);
      while (B <= Length(Result)) and (Result[B] <> ')') do Inc(B);
      Arg := Copy(Result, A + Length(FileMacros[I]), B - A - Length(FileMacros[I]));
      case I of
        0, 1: V := ExtractFilePath(Arg);
        2: V := ExtractFileName(Arg);
        3: V := ChangeFileExt(ExtractFileName(Arg), '');
      else
        V := ExtractFileExt(Arg);
      end;
      Result := Copy(Result, 1, A - 1) + V + Copy(Result, B + 1, MaxInt);
    until False;
  Result := Trim(Result);
end;

{ File | New | Other, Save Project As, Use Unit, Print }
procedure TMainForm.ActFile(Sender: TObject);
var
  PO: TPrintOptions;
  P: TEditorPage;
begin
  P := ActivePage;
  if Sender = FilePrintCommand then
  begin
    if (P <> nil) and P.CodeView and
      TPrintDlg.Execute(Self, P.FileName, P.Editor.SelEnd > P.Editor.SelStart, PO) then
      PrintEditor(P.Editor, ExtractFileName(P.FileName), PO);
  end
  else if Sender = FileNewCommand then NewItems
  else if Sender = FileSaveProjectAsCommand then SaveProjectAs
  else if Sender = FileUseUnitCommand then UseUnit;
end;

{ Help: Delphi 7's WinHelp files in its Help\, and the Win32 SDK's in Borland Shared\MSHelp, shown
  by Windows' WinHelp viewer (winhlp32.exe). Windows 10 and later have only a stub of it, which says
  that the feature is missing; D7 Studio's Setup puts Microsoft's viewer in its place. }

const
  { d7.hlp merges Delphi 7's other help files: d7.cnt includes Delphi's OpenHelp lists (d7.ohc,
    d7.ohi, d7.ohl), so its contents and index hold all the files Delphi 7 has }
  HelpMainFile = 'Help\d7.hlp';
  HelpVclFile = 'Help\d7vcl.hlp';
  { Microsoft's Win32 Programmer's Reference, below the Common Files of 32-bit programs, where
    Delphi 7's installer puts it }
  HelpWinSdkFile = 'Borland Shared\MSHelp\win32.hlp';
  CSIDL_PROGRAM_FILES_COMMON = $002B;

var
  { the help file of the last request, which HELP_QUIT names when D7 Studio closes }
  LastHelpFile: WideString;

{ the Common Files folder of 32-bit programs, D7 Studio's (on 64-bit Windows: Program Files
  (x86)\Common Files), with a trailing backslash }
function CommonFilesDir: string;
var
  Path: array[0..MAX_PATH] of WideChar;
begin
  Result := '';
  if SHGetSpecialFolderPathW(0, Path, CSIDL_PROGRAM_FILES_COMMON, False) then
    Result := IncludeTrailingPathDelimiter(WideToIde(Path));
end;

{ a help file of Delphi's in WinHelp's window: its Help Topics, or with a Keyword the topic its
  index has for it - WinHelp's list when there are several, the index at the word when there is
  none (HELP_PARTIALKEY, as Delphi 7 asks). Not in the cloaked test instance: the viewer is a
  process of its own, whose windows the test guard cannot cloak. }
procedure TMainForm.OpenHelpFile(const FileName: string; const Keyword: string);
var
  K: WideString;
begin
  if not FileExists(FileName) then
  begin
    MessageBox(Handle, PChar('Help file not found: ' + FileName), AppTitle, MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  if UITestMode then Exit;
  LastHelpFile := IdeTextToWide(FileName);
  if Keyword = '' then
    WinHelpW(Handle, PWideChar(LastHelpFile), HELP_FINDER, 0)
  else
  begin
    K := IdeTextToWide(Keyword);
    WinHelpW(Handle, PWideChar(LastHelpFile), HELP_PARTIALKEY, DWORD(PWideChar(K)));
  end;
end;

{ WinHelp closes once no program needs it any more }
procedure TMainForm.CloseHelp;
begin
  if LastHelpFile <> '' then WinHelpW(Handle, PWideChar(LastHelpFile), HELP_QUIT, 0);
end;

procedure TMainForm.ActHelp(Sender: TObject);
begin
  if (Sender = HelpContentsCommand) or (Sender = HelpDelphiToolsCommand) then
    OpenHelpFile(DelphiRoot + HelpMainFile)
  else if Sender = HelpVclRefCommand then
    OpenHelpFile(DelphiRoot + HelpVclFile)
  else if Sender = HelpWinSDKCommand then
    OpenHelpFile(CommonFilesDir + HelpWinSdkFile);
end;

{ --- the editor's menu (Delphi 7's) --- }

procedure TMainForm.ActEditorMenu(Sender: TObject);
var
  Ed: TSciEdit;
  S, E: Integer;
  Word: string;
begin
  Ed := ActiveEditor;
  if Sender = aMessageView then
  begin
    if FBottomPanels[BT_MESSAGES].Showing then FDock.HidePanel(FBottomPanels[BT_MESSAGES])
    else ShowBottom(BT_MESSAGES);
    Exit;
  end;
  if Ed = nil then Exit;
  { Delphi's keystroke macro: the keyboard services' record of the IDE (SdOtaServices) - recorded
    and played key by key }
  if Sender = aRecordMacro then
  begin
    OtaRecordMacro;
    UpdateStatus;
  end
  else if Sender = aPlayMacro then OtaPlayMacro
  else if Sender = aOpenFileAtCursor then OpenFileAtCursor
  else if Sender = EditAddToDoItemCommand then AddTodoItem
  else if Sender = ecCompleteClass then
  begin
    if not ActivePage.CompleteClass(EnvOptions.ExFinishProperties) then MessageBeep(0);
  end
  else if Sender = aReadOnly then Ed.ReadOnly := not Ed.ReadOnly
  else if Sender = aTopicSearch then
  begin
    { F1: Delphi's help on the word at the caret (its index), else its contents }
    Word := Ed.WordAt(Ed.CaretPos, S, E);
    OpenHelpFile(DelphiRoot + HelpMainFile, Word);
  end;
end;

{ Toggle Bookmarks (Shift+Ctrl+0..9) and Goto Bookmarks (Ctrl+0..9): Tag 10.. and 20.. }
procedure TMainForm.ActBookmark(Sender: TObject);
var
  P: TEditorPage;
  N: Integer;
begin
  P := ActivePage;
  if (P = nil) or not P.CodeView then Exit;
  N := TAction(Sender).Tag;
  if N < 20 then P.ToggleBookmark(N - 10) else P.GotoBookmark(N - 20);
end;

{ Open File at Cursor (Ctrl+Enter): the name at the caret - a unit of a uses clause, the file of
  an include or resource directive, any name of a file - from the unit's folder, the project's,
  the search and library paths }
procedure TMainForm.OpenFileAtCursor;
const
  FileChars = ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '\', '/', ':', '-', '$', '~'];
var
  Ed: TSciEdit;
  S, E, I: Integer;
  Name, F: string;
  Dirs: TStringList;
begin
  Ed := ActiveEditor;
  if Ed = nil then Exit;
  S := Ed.CaretPos;
  while (S > 0) and (Ed.CharAt(S - 1) in FileChars) do Dec(S);
  E := Ed.CaretPos;
  while Ed.CharAt(E) in FileChars do Inc(E);
  Name := Ed.GetRange(S, E);
  while (Name <> '') and (Name[Length(Name)] = '.') do Delete(Name, Length(Name), 1);
  if Name = '' then Exit;
  F := '';
  if ExtractFileExt(Name) = '' then F := FCodeInsight.FindUnitFile(Name, ActivePage.FileName)
  else if IsAbsolutePath(Name) then
  begin
    if FileExistsU(Name) then F := Name;
  end
  else
  begin
    Dirs := TStringList.Create;
    try
      Dirs.Add(ExtractFileDir(ActivePage.FileName));
      if FProject <> nil then Dirs.Add(ExcludeTrailingPathDelimiter(FProject.Dir));
      Dirs.AddStrings(FCodeInsight.SearchPath);
      for I := 0 to Dirs.Count - 1 do
        if (F = '') and FileExistsU(IncludeTrailingPathDelimiter(Dirs[I]) + Name) then
          F := ExpandFileName(IncludeTrailingPathDelimiter(Dirs[I]) + Name);
    finally
      Dirs.Free;
    end;
  end;
  if F <> '' then OpenFile(F, True)
  else MessageBox(Handle, PChar(Format('Unable to locate file ''%s''.', [Name])), AppTitle, MB_OK or MB_ICONERROR);
end;

{ Delphi's Add To-Do Item for Mode with V; the owners and categories offered are those of the
  items the To-Do List shows }
function TMainForm.TodoDialog(Mode: TTodoDlgMode; var V: TTodoValues): Boolean;
var
  Owners, Cats: TStringList;
begin
  Owners := TStringList.Create;
  Cats := TStringList.Create;
  try
    FTodo.ShownValues(tfOwner, Owners);
    FTodo.ShownValues(tfCategory, Cats);
    Result := AddTodoDialog(Self, Mode, Owners, Cats, V);
  finally
    Cats.Free;
    Owners.Free;
  end;
end;

{ Add To-Do Item (Shift+Ctrl+T): Delphi's dialog; the comment ("TODO ..." in braces) goes in at the caret
  (Delphi's format, TodoText) - its text on one line, a closing brace in it as ")" }
procedure TMainForm.AddTodoItem;
var
  V: TTodoValues;
  S, Comment: string;
  Ed: TSciEdit;
begin
  Ed := ActiveEditor;
  if Ed = nil then Exit;
  V.Text := '';
  V.Owner := '';
  V.Category := '';
  V.Priority := 0;
  V.Done := False;
  if not TodoDialog(tmEditorAdd, V) then Exit;
  S := Trim(StringReplace(StringReplace(V.Text, #13#10, ' ', [rfReplaceAll]), '}', ')', [rfReplaceAll]));
  if S = '' then Exit;
  Comment := '{ ' + TodoText(V.Done, V.Priority, Trim(V.Owner), Trim(V.Category), S) + ' }';
  { at the caret, apart from code that follows it; the dialog's text in the file's encoding }
  if not (Ed.CharAt(Ed.CaretPos) in [#0, #9, #10, #13, ' ']) then Comment := Comment + ' ';
  Ed.InsertText(Ed.CaretPos, AnsiToEditor(Comment, Ed.Encoding));
  if FBottomPanels[BT_TODO].Showing then RefreshTodoList;
end;

{ the To-Do List's Add... (Delphi's): the item goes first into the project's To-Do file
  (<project>.todo, "TODO ..." in braces and a line break) - made and named in the project source
  ("%ToDo" entry) the first time; the dialog offers the values of its last OK again }
procedure TMainForm.AddProjectTodo;
var
  F, Src, Item: string;
  E: TSdEncoding;
  Ansi: Boolean;
begin
  if FProject = nil then Exit;
  if not TodoDialog(tmAdd, FLastTodo) then Exit;
  F := TodoFileOf(ProjectSource, FProject.Dir);
  if F = '' then
  begin
    F := ChangeFileExt(FProject.FileName, TodoExt);
    Src := ProjectSource;
    DprAddTodoFile(Src, ExtractRelativePath(IncludeTrailingPathDelimiter(FProject.Dir), F));
    ProjectSourceChanged(Src);
  end;
  if FileExistsU(F) or (FindPage(F) <> nil) then Src := TodoSource(F, E, Ansi)
  else
  begin
    Src := '';
    E := SystemEncoding;
    Ansi := True;
  end;
  { with the file's line ends, in the form TodoSource gave: the item (IDE text) in the file's
    encoding when the text stays in it }
  Item := '{' + TodoText(False, FLastTodo.Priority, FLastTodo.Owner, FLastTodo.Category, FLastTodo.Text) + '}';
  if not Ansi then Item := AnsiToEditor(Item, E);
  Src := Item + DetectEOL(Src) + Src;
  SetTodoSource(F, Src, E, Ansi, True);
  RefreshTodoList;
end;

{ the text of a file as the To-Do List reads and changes it: the editor's when the file is
  open, else the file's decoded (E: the encoding); in the system code page, the list's and its
  dialogs', when the way back loses nothing (Ansi), else in its encoding as it is }
function TMainForm.TodoSource(const FileName: string; out E: TSdEncoding; out Ansi: Boolean): string;
var
  A: string;
begin
  Result := SourceAndEncoding(FileName, E);
  A := EditorToAnsi(Result, E);
  Ansi := AnsiToEditor(A, E) = Result;
  if Ansi then Result := A;
end;

{ ... and the text changed in that form back: into the editor (one undo step; saved with Save),
  else into the file in its encoding }
procedure TMainForm.SetTodoSource(const FileName, Text: string; const E: TSdEncoding; Ansi, Save: Boolean);
var
  P: TEditorPage;
  S: string;
begin
  if Ansi then S := AnsiToEditor(Text, E) else S := Text;
  P := FindPage(FileName);
  if P = nil then
    WriteSourceFile(FileName, S, E)
  else
  begin
    P.SetSourceUndoable(S);
    if Save then P.Save;
  end;
end;

{ Edit and Delete may change an item: one of the To-Do file, or one of a file open in the editor
  (Delphi's CanEdit: the file has an edit view) that is not read-only }
function TMainForm.TodoCanEdit(Item: TSdTodoItem): Boolean;
var
  P: TEditorPage;
begin
  Result := False;
  if Item = nil then Exit;
  if Item.InTodoFile then
    Result := True
  else
  begin
    P := FindPage(Item.FileName);
    Result := (P <> nil) and not P.Editor.ReadOnly;
  end;
end;

{ Edit (Delphi's SetText, SetOwner ...) and Delete: the item's comment becomes NewComment ('':
  taken out) - in the editor (one undo step, not saved, as Delphi changes the buffer), in the
  project's To-Do file (written) }
procedure TMainForm.ChangeTodoComment(Item: TSdTodoItem; const NewComment: string);
var
  Src: string;
  At: Integer;
  E: TSdEncoding;
  Ansi: Boolean;
begin
  if not Item.InTodoFile and (FindPage(Item.FileName) = nil) then Exit;
  { the form the list read it in (TodoSource) }
  Src := TodoSource(Item.FileName, E, Ansi);
  { the list is not kept up to date while the text changes: the comment where it is now }
  At := TodoFindComment(Src, Item);
  if At >= 0 then
    SetTodoSource(Item.FileName, Copy(Src, 1, At) + NewComment + Copy(Src, At + Length(Item.Comment) + 1, MaxInt),
      E, Ansi, Item.InTodoFile)
  else
    MessageBeep(MB_ICONWARNING);
  RefreshTodoList;
end;

{ Edit... (Delphi's): Edit To-Do Item with the item's values; what changed is changed in its
  comment (TodoEditComment) }
procedure TMainForm.EditTodo(Item: TSdTodoItem);
var
  V: TTodoValues;
  S: string;
  E: TSdEncoding;
  Ansi: Boolean;

  { a value typed in the dialog (system code page) in the form of the item's text: an unchanged
    one as it is }
  function Taken(const Typed, Old: string): string;
  begin
    if Ansi or (Typed = Old) then Result := Typed else Result := AnsiToEditor(Typed, E);
  end;

begin
  if not TodoCanEdit(Item) then Exit;
  V.Text := Item.RawText;
  V.Owner := Item.Owner;
  V.Category := Item.Category;
  V.Priority := Item.Priority;
  V.Done := Item.Done;
  { no refresh of the list frees the item while its dialog is open }
  Inc(FTodoLock);
  try
    if not TodoDialog(tmEdit, V) then Exit;
  finally
    TodoUnlock;
  end;
  FLastTodo := V;                    // Delphi's Add offers the values of the last OK
  TodoSource(Item.FileName, E, Ansi);
  S := TodoEditComment(Item, V.Done, V.Priority, Taken(V.Owner, Item.Owner), Taken(V.Category, Item.Category),
    Taken(V.Text, Item.RawText));
  if S <> Item.Comment then ChangeTodoComment(Item, S);
end;
{ --- desktops: the arrangement of the panes under a name (View | Desktops, the Desktops button
  of the tool bar); the debug desktop is the one shown while the debugger runs --- }

procedure TMainForm.SaveNamedDesktop(const Name: string);
begin
  FDock.Save(Settings, 'Desktop:' + Name);
  Settings.WriteString('Desktops', Name, '1');
  if Copy(Name, 1, 1) = '.' then Exit;      // D7 Studio's own: the layout before debugging
  Settings.WriteString('Desktops', '.Current', Name);
end;

{ the user's choice (the Desktops dialog): the desktop shown and the current one from now on }
procedure TMainForm.LoadNamedDesktop(const Name: string);
begin
  if not ShowNamedDesktop(Name) or (Copy(Name, 1, 1) = '.') then Exit;
  Settings.WriteString('Desktops', '.Current', Name);
end;

{ a saved desktop shown - the debug desktop and the way back from it: the current one stays
  what the user chose (False: no such desktop) }
function TMainForm.ShowNamedDesktop(const Name: string): Boolean;
begin
  Result := (Name <> '') and Settings.ValueExists('Desktops', Name);
  if Result then LoadArrangement('Desktop:' + Name);
end;

{ a saved desktop goes; it is no longer the current one, nor the debug desktop }
procedure TMainForm.DeleteNamedDesktop(const Name: string);
begin
  Settings.DeleteKey('Desktops', Name);
  Settings.EraseSection('Desktop:' + Name);
  if SameText(Settings.ReadString('Desktops', '.Current', ''), Name) then Settings.DeleteKey('Desktops', '.Current');
  if SameText(Settings.ReadString('Desktops', '.Debug', ''), Name) then Settings.DeleteKey('Desktops', '.Debug');
end;

{ the desktop shown while the debugger runs ('': none) }
procedure TMainForm.SetDebugDesktop(const Name: string);
begin
  if Name = '' then Settings.DeleteKey('Desktops', '.Debug')
  else Settings.WriteString('Desktops', '.Debug', Name);
end;

{ the Desktops button: the dialog that saves the current desktop or chooses a saved one and the
  debug desktop }
procedure TMainForm.ShowDesktops;
begin
  DesktopsDialog(Self, DesktopNames, Settings.ReadString('Desktops', '.Current', ''),
    Settings.ReadString('Desktops', '.Debug', ''), SaveNamedDesktop, LoadNamedDesktop,
    DeleteNamedDesktop, SetDebugDesktop);
end;

{ the drop-down of the Desktops button: the saved desktops, the current one
  checked; choosing one is the dialog's Load - shown, and the current desktop from now on }
procedure TMainForm.DesktopsMenuPopup(Sender: TObject);
var
  L: TStringList;
  I: Integer;
  A: TAction;
  Current: string;
begin
  DesktopsMenu.Items.Clear;
  ClearActions(DesktopActions);
  Current := Settings.ReadString('Desktops', '.Current', '');
  L := TStringList.Create;
  try
    DesktopNames(L);
    for I := 0 to L.Count - 1 do
    begin
      A := NewAction(DesktopActions, NoAccel(L[I]), L[I], I, DesktopExecute);
      A.Checked := SameText(L[I], Current);
      NewActionItem(DesktopsMenu.Items, A);
    end;
    if L.Count = 0 then
    begin
      { as Run's drop-down says it: nothing to choose }
      A := NewAction(DesktopActions, '(none)', '', -1, DesktopExecute);
      A.Enabled := False;
      NewActionItem(DesktopsMenu.Items, A);
    end;
  finally
    L.Free;
  end;
end;

procedure TMainForm.DesktopExecute(Sender: TObject);
begin
  LoadNamedDesktop(TAction(Sender).Hint);
end;

{ the saved desktops, sorted ([Desktops]; .Current and .Debug are not desktops) }
procedure TMainForm.DesktopNames(L: TStringList);
var
  I: Integer;
begin
  Settings.ReadSection('Desktops', L);
  for I := L.Count - 1 downto 0 do
    if Copy(L[I], 1, 1) = '.' then L.Delete(I);
  L.Sort;
end;

{ the drop-down of Run on the Debug tool bar: the process being debugged }
procedure TMainForm.ProcessMenuPopup(Sender: TObject);
var
  P: TSdProject;
begin
  { the session's program: its project's, another may be active meanwhile }
  P := FDebugProject;
  if P = nil then P := FProject;
  if FDebug.Active and (P <> nil) then
  begin
    aProcess.Caption := ExtractFileName(P.ExeName);
    aProcess.Checked := True;
    aProcess.Enabled := True;
  end
  else
  begin
    aProcess.Caption := '(none)';
    aProcess.Checked := False;
    aProcess.Enabled := False;
  end;
end;

{ View | Toolbars | Customize, and the tool bar's menu: Customize, Reset }
procedure TMainForm.ActToolbar(Sender: TObject);
begin
  if Sender = ViewCustomizeCommand then ShowCustomize
  else if Sender = aTbReset then ResetToolbar;
end;

{ Reset while the tool bar has other buttons than the .dfm's }
procedure TMainForm.ToolbarsPopupPopup(Sender: TObject);
begin
  aTbReset.Enabled := ToolbarButtonsText(MainBar) <> FDefaultButtons;
end;

{ File | Use Unit: a unit of the project goes into the uses clause of the implementation }
procedure TMainForm.UseUnit;
var
  P: TEditorPage;
  L, Used: TStringList;
  I, Idx: Integer;
  Src: string;
begin
  P := ActivePage;
  if (P = nil) or (FProject = nil) then Exit;
  Src := P.GetSource;
  L := TStringList.Create;
  Used := TStringList.Create;
  try
    FSGetUses(Src, True, Used);
    FSGetUses(Src, False, Used);
    Used.Add(FSGetUnitName(Src));
    for I := 0 to FProject.UnitCount - 1 do
      if Used.IndexOf(FProject.Units[I].Name) < 0 then L.Add(FProject.Units[I].Name);
    if L.Count = 0 then
    begin
      MessageBox(Handle, 'All units of the project are used by this unit already.', 'Use Unit',
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    L.Sort;
    Idx := 0;
    if not ListDialog(Self, 'Use Unit', L, Idx) then Exit;
    if not FSAddUses(Src, L[Idx], False) then Exit;
    P.SetSourceUndoable(Src);
  finally
    Used.Free;
    L.Free;
  end;
end;

{ File | Save Project As: the active project's file under a new name (with its .dof, .res and
  .cfg), the paths of its units relative to the new folder }
procedure TMainForm.SaveProjectAs;
begin
  SaveProjectAsName(FProject, '');
end;

{ P, a project of the group or a package beside it, under another name: AName, or the one asked
  for ('') - its source written under the new name (the program's name and its units' paths
  changed), its options and resources copied. Its entry follows (Delphi's TWorkspace.RenameProject):
  every file stays open, the page of its source shows the new file, its Open Tools API module takes
  the new name, the group is modified (a project of it). True when the project has the name now. }
function TMainForm.ProjectSourceFor(P: TSdProject; const NewName: string; out Src: string;
  out E: TSdEncoding): Boolean;
var
  NewDir, Rel, Rc, Res: string;
  I: Integer;
begin
  Result := False;
  Src := SourceAndEncoding(P.FileName, E);     // the new file keeps the encoding
  DprSetProgramName(Src, ChangeFileExt(ExtractFileName(NewName), ''));
  { the units' names from the new folder, in the source's encoding (the project's file names are
    D7 Studio's text) }
  NewDir := ExtractFilePath(NewName);
  for I := 0 to P.UnitCount - 1 do
  begin
    if not NameForSource(P.FileName, ExtractRelativePath(NewDir, P.Units[I].FileName), E, Rel) then Exit;
    DprRenameUnit(Src, P.Units[I].Name, P.Units[I].Name, Rel);
  end;
  { ... and the resource scripts' }
  for I := 0 to P.ResScriptCount - 1 do
    with P.ResScripts[I] do
    begin
      if not NameForSource(P.FileName, ExtractRelativePath(NewDir, FileName), E, Rc) or
        not NameForSource(P.FileName, ExtractRelativePath(NewDir, ResFileName), E, Res) then Exit;
      if not SameText(Rc, RelRc) or not SameText(Res, RelRes) then DprRenameResScript(Src, RelRc, Res, Rc);
    end;
  Result := True;
end;

{ Delphi 7's IOTAModule.FileName of a project (measured): its entry - of the group or beside it - and
  the page of its source follow the new name, the program's name and its units' paths change in
  that source unsaved; nothing is written - the source, its options and its .res go there when the
  project is saved }
function TMainForm.RenameProjectOnly(P: TSdProject; const AName: string): Boolean;
var
  Src, NewName, OldName: string;
  E: TSdEncoding;
  Page: TEditorPage;
begin
  Result := False;
  if (FGroup.IndexOfProject(P) < 0) and not FGroup.IsBeside(P) then Exit;
  OldName := P.FileName;
  NewName := ChangeFileExt(ExpandPathU(AName), ExtractFileExt(OldName));
  Result := SameText(NewName, OldName);
  if Result or (FGroup.IndexOf(NewName) >= 0) or (FGroup.IndexOfBeside(NewName) >= 0) then Exit;
  if not ProjectSourceFor(P, NewName, Src, E) then Exit;
  { the unsaved source needs its page }
  Page := FindPage(OldName);
  if Page = nil then Page := OpenFile(OldName, False);
  if Page = nil then Exit;
  Page.SetSourceUndoable(Src);
  { the entry first, so that the module's notifiers (ModuleRenamed) find the project under its new name }
  FGroup.RenameProject(P, NewName);
  P.Rename(NewName);
  RenamePageOnly(Page, NewName);
  UpdatePageTab(Page);
  ProjectNameShown(P);
  Result := True;
end;

procedure TMainForm.ProjectNameShown(P: TSdProject);
begin
  if P = FProject then FTodo.Table.Caption := ExtractFileName(P.FileName);
  UpdateCaption;
  RefreshProjectTree;
  ConfigureCodeInsight;
end;

function TMainForm.SaveProjectAsName(P: TSdProject; const AName: string): Boolean;
var
  Src, NewName, OldName, OldBase, NewBase, Ext: string;
  I: Integer;
  E: TSdEncoding;
  Page: TEditorPage;
  WasModified, Saved: Boolean;
const
  Companions: array[0..2] of string = ('.dof', '.res', '.cfg');
begin
  Result := False;
  if (FGroup.IndexOfProject(P) < 0) and not FGroup.IsBeside(P) then Exit;
  if not SaveAllPages then Exit;
  OldName := P.FileName;
  Ext := ExtractFileExt(OldName);
  NewName := AName;
  if NewName = '' then
  begin
    NewName := OldName;
    if not AskSaveName('Save ' + P.Name + ' As', ProjectFilter(P.IsPackage), Copy(Ext, 2, MaxInt), NewName) then Exit;
  end;
  NewName := ChangeFileExt(ExpandPathU(NewName), Ext);
  Result := SameText(NewName, OldName);
  if Result then Exit;
  if (FGroup.IndexOf(NewName) >= 0) or (FGroup.IndexOfBeside(NewName) >= 0) then
  begin
    MessageBox(Handle, PChar(Format('The project group has a project %s already.', [ExtractFileName(NewName)])),
      AppTitle, MB_OK or MB_ICONERROR);
    Exit;
  end;
  { the options first, whose files go along: when they cannot be written (it raises), nothing
    of the new project is written yet }
  P.SaveOptions;
  if not ProjectSourceFor(P, NewName, Src, E) then Exit;
  OldBase := ChangeFileExt(OldName, '');
  NewBase := ChangeFileExt(NewName, '');
  for I := Low(Companions) to High(Companions) do
    if FileExistsU(OldBase + Companions[I]) then
      CopyFileW(PWideChar(WidePath(OldBase + Companions[I])), PWideChar(WidePath(NewBase + Companions[I])), False);
  { the page of the source under the new name (its module follows: SavePageAs); without a page
    the file is written and the module renamed. Its entry - of the group or beside it - is renamed
    first, so that the module's notifiers (ModuleRenamed) find the project under its new name; it
    is put back when the page cannot be saved }
  Page := FindPage(OldName);
  if Page <> nil then
  begin
    Page.SetSourceUndoable(Src);
    WasModified := FGroup.Modified;
    FGroup.RenameProject(P, NewName);
    Saved := False;
    try
      Saved := SavePageAs(Page, NewName);
    finally
      if not Saved then
      begin
        FGroup.RenameProject(P, OldName);
        FGroup.Modified := WasModified;
      end;
    end;
    if not Saved then Exit;
    UpdatePageTab(Page);
  end
  else
  begin
    WriteSourceFile(NewName, Src, E);
    FGroup.RenameProject(P, NewName);
    OtaModules.Renamed(OldName, NewName);
  end;
  { the project: read from the new file }
  P.Load(NewName);
  AddRecent('RecentProjects', NewName);
  UpdateReopenMenu;
  if P = FProject then SetCurrentDir(P.Dir);
  ProjectNameShown(P);
  Result := True;
end;

{ Run | Register / Unregister ActiveX Server: a library's DllRegisterServer, a program's
  /regserver }
procedure TMainForm.RegisterServer(Unregister: Boolean);
type
  TRegProc = function: HResult; stdcall;
const
  Procs: array[Boolean] of PChar = ('DllRegisterServer', 'DllUnregisterServer');
  Switch: array[Boolean] of string = ('/regserver', '/unregserver');
  Done: array[Boolean] of string = ('registered', 'unregistered');
  Verb: array[Boolean] of string = ('register', 'unregister');
var
  Lib: HMODULE;
  Proc: TRegProc;
  Exe, Err: string;
  HR: HResult;

  { a program's /regserver: started and waited for - the IDE keeps painting meanwhile, as the
    server may show a message box - and judged by its exit code ('' done, else why not) }
  function RunServer(const Cmd, Dir: string): string;
  var
    SI: TStartupInfo;
    PI: TProcessInformation;
    Code: DWORD;
  begin
    Result := '';
    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESHOWWINDOW;
    SI.wShowWindow := SW_HIDE;
    if not CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil, PChar(Dir), SI, PI) then
    begin
      Result := SysErrorMessage(GetLastError);
      Exit;
    end;
    { no command of the IDE runs meanwhile: the main window takes no input, as under a dialog }
    EnableWindow(Handle, False);
    Screen.Cursor := crHourGlass;
    try
      while MsgWaitForMultipleObjects(1, PI.hProcess, False, INFINITE, QS_ALLINPUT) = WAIT_OBJECT_0 + 1 do
        Application.ProcessMessages;
      if not GetExitCodeProcess(PI.hProcess, Code) then Result := SysErrorMessage(GetLastError)
      else if Code <> 0 then Result := Format('%s ended with exit code %d.', [ExtractFileName(Exe), Code]);
    finally
      Screen.Cursor := crDefault;
      EnableWindow(Handle, True);
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  end;

begin
  if (FProject = nil) or not DoCompile(False, False, False, True) then Exit;
  Exe := FProject.ExeName;
  Err := '';
  if FProject.IsLibrary then
  begin
    Lib := LoadLibrary(PChar(Exe));
    if Lib = 0 then
      Err := SysErrorMessage(GetLastError)
    else
      try
        @Proc := GetProcAddress(Lib, Procs[Unregister]);
        if @Proc = nil then
          Err := Format('%s does not export %s: it is not an ActiveX server.', [ExtractFileName(Exe), Procs[Unregister]])
        else
        begin
          HR := Proc();
          if Failed(HR) then Err := SysErrorMessage(HR);
        end;
      finally
        FreeLibrary(Lib);
      end;
  end
  else
    Err := RunServer('"' + Exe + '" ' + Switch[Unregister], FolderArg(ExtractFilePath(Exe)));
  if Err = '' then
    MessageBox(Handle, PChar(Format('Successfully %s ActiveX Server ''%s''.', [Done[Unregister], Exe])),
      AppTitle, MB_OK or MB_ICONINFORMATION)
  else
    MessageBox(Handle, PChar(Format('Cannot %s ActiveX Server ''%s''.'#13#10#13#10'%s',
      [Verb[Unregister], Exe, Err])), AppTitle, MB_OK or MB_ICONERROR);
end;

{ a Reopen entry with the real file name: "&0 " (ASCII) and the name from DisplayPath, its "&"
  doubled (NoAccel) }
function ReopenCaptionW(A: TBasicAction): WideString;
var
  W: WideString;
  I: Integer;
begin
  Result := WideString(Copy(TCustomAction(A).Caption, 1, 3));
  W := DisplayPath(TCustomAction(A).Hint);
  for I := 1 to Length(W) do
  begin
    if W[I] = '&' then Result := Result + '&';
    Result := Result + W[I];
  end;
end;

{ the text of a menu item for SdUI's menus: a Reopen entry whose name is outside the code page
  (its ANSI caption cannot hold it), '' for the others }
function MenuTextW(Item: TMenuItem): WideString;
begin
  Result := '';
  if (Item.Action is TCustomAction) and (TCustomAction(Item.Action).ActionList = MainForm.ReopenActions) and
    NeedsUnicode(TCustomAction(Item.Action).Hint) then
    Result := ReopenCaptionW(Item.Action);
end;

{ ---------------------------------------------------------------- pages }

function TMainForm.GetPage(Index: Integer): TEditorPage;
begin
  Result := TEditorPage(FPages[Index]);
end;

function TMainForm.PageCount: Integer;
begin
  Result := FPages.Count;
end;

{ The file tabs (FPageTabs, Windows' tab control with close boxes): tab I is FDocs[I]; the pages
  lie on the centre below their row (FTabRow). }
function TMainForm.ActiveDoc: TWinControl;
begin
  if (FPageTabs <> nil) and (FDocs <> nil) and (FPageTabs.TabIndex >= 0) and (FPageTabs.TabIndex < FDocs.Count) then
    Result := TWinControl(FDocs[FPageTabs.TabIndex])
  else
    Result := nil;
end;

function TMainForm.ActivePage: TEditorPage;
var
  D: TWinControl;
begin
  D := ActiveDoc;
  if D is TEditorPage then Result := TEditorPage(D) else Result := nil;
end;

function TMainForm.ActiveResPage: TSdResPage;
var
  D: TWinControl;
begin
  D := ActiveDoc;
  if D is TSdResPage then Result := TSdResPage(D) else Result := nil;
end;

{ a new page lies on the centre; its tab comes with AddDoc. A hidden control is not aligned: the
  page gets its size here, and what is made in it is laid out for that - a resource page's editor
  laid out in a page of 0 x 0 kept the controls anchored at its right collapsed (the VCL dropped
  their anchors) }
procedure TMainForm.AddPageTab(Page: TWinControl);
begin
  Page.Visible := False;
  Page.Parent := CenterPanel;
  Page.Align := alClient;
  Page.BoundsRect := CenterPanel.ClientRect;
end;

{ ... it is one of the file area's, its tab the last }
procedure TMainForm.AddDoc(Doc: TWinControl);
begin
  if Doc is TEditorPage then FPages.Add(Doc);
  FDocs.Add(Doc);
  UpdatePageTab(Doc);
end;

{ a tab dragged along the row moved (SdTabStrip has moved it): FDocs keeps the tabs' order, FPages
  the files' in it - the Window menu, the Pages menu, the open files' drop-down, Next Window, the
  desktop and the experts' modules have the new order }
procedure TMainForm.TabsMove(Sender: TObject; FromIndex, ToIndex: Integer);
var
  D: TWinControl;
  I, K: Integer;
begin
  if (FromIndex < 0) or (FromIndex >= FDocs.Count) or (ToIndex < 0) or (ToIndex >= FDocs.Count) then Exit;
  D := TWinControl(FDocs[FromIndex]);
  FDocs.Move(FromIndex, ToIndex);
  if not (D is TEditorPage) then Exit;
  FPages.Remove(D);
  K := 0;
  for I := 0 to ToIndex - 1 do
    if TObject(FDocs[I]) is TEditorPage then Inc(K);
  FPages.Insert(K, D);
end;

procedure TMainForm.MoveDoc(Doc: TWinControl; ToIndex: Integer);
var
  From: Integer;
begin
  From := FDocs.IndexOf(Doc);
  if ToIndex >= FDocs.Count then ToIndex := FDocs.Count - 1;
  if (From < 0) or (ToIndex < 0) or (From = ToIndex) then Exit;
  FPageTabs.MoveTab(From, ToIndex);
  TabsMove(FPageTabs, From, ToIndex);
end;

function TMainForm.DocModified(Doc: TWinControl): Boolean;
begin
  if Doc is TEditorPage then Result := TEditorPage(Doc).Modified
  else Result := TSdResPage(Doc).Modified;
end;

function TMainForm.DocTitle(Doc: TWinControl): string;
begin
  if Doc is TEditorPage then Result := ExtractFileName(TEditorPage(Doc).FileName)
  else Result := TSdResPage(Doc).Title;
end;

procedure TMainForm.UpdatePageTab(Page: TWinControl);
var
  Idx: Integer;
  P: TEditorPage;
  Caption: string;

  { the row as high as the tabs are, the buttons of its bars as well }
  procedure FitRow;
  begin
    FTabRow.Height := FPageTabs.RowHeight;
    HistoryBar.ButtonHeight := FTabRow.Height;
    FilesBar.ButtonHeight := FTabRow.Height;
  end;

begin
  Idx := FDocs.IndexOf(Page);
  if Idx < 0 then Exit;
  if Page is TEditorPage then
  begin
    P := TEditorPage(Page);
    P.TabMarked := P.Modified;
    Caption := P.TabCaption;
  end
  else
  begin
    P := nil;
    TSdResPage(Page).TabMarked := TSdResPage(Page).Modified;
    Caption := TSdResPage(Page).TabCaption;
  end;
  if Idx >= FPageTabs.Tabs.Count then
  begin
    FPageTabs.Tabs.Add(Caption);
    if not FTabRow.Visible then
    begin
      { as high as the tab control makes its tabs (it has one now); the buttons fill it. A tool
        button is never lower than its image and frame: when the tabs are lower (a small UI
        font), they are raised to the buttons (FitRowHeight) - else the row cut the buttons off }
      FitRow;
      FPageTabs.FitRowHeight(HiWord(SendMessage(HistoryBar.Handle, TB_GETBUTTONSIZE, 0, 0)));
      if FTabRow.Height <> FPageTabs.RowHeight then FitRow;
      FTabRow.Visible := True;
    end;
  end
  else
    FPageTabs.Tabs[Idx] := Caption;
  if P = nil then Exit;
  { a name outside the code page: the tab gets the real one }
  if NeedsUnicode(P.FileName) then FPageTabs.SetTabTextW(Idx, P.TabCaptionW);
  { its form shown as text (View as Text) is named after it (Save As) }
  if P.FormTextPage <> nil then UpdatePageTab(P.FormTextPage);
end;

function TMainForm.ActiveEditor: TSciEdit;
var
  P: TEditorPage;
begin
  P := ActivePage;
  if (P <> nil) and P.CodeView then Result := P.Editor else Result := nil;
end;

function TMainForm.ActiveDesigner: TFormDesigner;
var
  P: TEditorPage;
begin
  P := ActivePage;
  if (P <> nil) and P.DesignView then Result := P.Designer else Result := nil;
end;

{ a package goes: the Object Inspector's rows may hold property editors of its classes - they go
  while the package's code is there, and come again (the designer's selection) after it }
procedure TMainForm.HostPackageUnloading(Sender: TObject);
begin
  if FInspector <> nil then FInspector.SetDesigner(nil);
  DropVerbs;
end;

{ the designer menu's verbs, their actions and the editors behind them go: an unloading package
  may have made them (an editor's handlers are its code). The component editor's verbs are the
  items above pmDesignVerbSep, the selection editors' those between pmDesignControl and
  pmDesignSelSep. }
procedure TMainForm.DropVerbs;
var
  I: Integer;
begin
  while DesignPopup.Items[0] <> pmDesignVerbSep do DesignPopup.Items[0].Free;
  while DesignPopup.Items[pmDesignControl.MenuIndex + 1] <> pmDesignSelSep do
    DesignPopup.Items[pmDesignControl.MenuIndex + 1].Free;
  ClearActions(VerbActions);
  for I := 0 to PageCount - 1 do
    if Pages[I].Designer <> nil then Pages[I].Designer.ReleaseVerbs;
end;

procedure TMainForm.HostPackageUnloaded(Sender: TObject);
begin
  { as PageViewChanged: the active page's designer }
  if not FClosing and (FInspector <> nil) and (ActivePage <> nil) then FInspector.SetDesigner(ActivePage.Designer);
end;

{ a package was installed or removed, or the palette arranged again (Environment Options) }
procedure TMainForm.HostPaletteChanged(Sender: TObject);
begin
  if FClosing or (FCompBar = nil) then Exit;
  FCompBar.Reload;
  if FIdePalette <> nil then FIdePalette.Reload;
end;

{ A design-time window of a package (action list editor, menu designer, collection editor ...)
  is being created or destroyed. These windows float as in Delphi; see SdDesignWin. }
procedure TMainForm.HostDesignWindow(Form: TCustomForm; Appearing: Boolean);
begin
  if FClosing or (FDesignWindows = nil) then Exit;
  if Appearing then FDesignWindows.Add(Form) else FDesignWindows.Remove(Form);
end;

{ an editor has just returned: the window it may have opened gets its owner and place now,
  before it is painted for the first time }
procedure TMainForm.HostSyncDesignWindows(Sender: TObject);
begin
  if not FClosing and (FDesignWindows <> nil) then FDesignWindows.Sync;
end;

{ a design window's form is shown: the active page shows this designer's form (the same root) }
function TMainForm.DesignWindowShown(Root: TComponent): Boolean;
var
  D: TFormDesigner;
begin
  D := ActiveDesigner;
  Result := (D <> nil) and (D.Root <> nil) and (Root = D.Root);
end;

{ where a new design window opens: beside the left column, just inside the page area }
function TMainForm.DesignWindowOrigin: TPoint;
begin
  if (CenterPanel <> nil) and CenterPanel.HandleAllocated then
    Result := CenterPanel.ClientToScreen(Point(8, 8))
  else
    Result := ClientToScreen(Point(240, 90));
end;

{ ---------------------------------------------------------------- TDesignWindowHost }

{ A new design window opens 2 px below the bottom of this rectangle: the top of the page area. }
function TDesignWindowHost.MainWindowRect: TRect;
var
  P: TPoint;
begin
  P := FMain.ClientToScreen(Point(0, 0));
  Result := Rect(P.X, P.Y, P.X + FMain.ClientWidth, P.Y + 86);
end;

function TDesignWindowHost.WorkspaceOrigin: TPoint;
begin
  Result := FMain.ClientToScreen(Point(0, 0));
end;

procedure TDesignWindowHost.FocusInspector(Key: Char; const PropName: string);
begin
  if not FMain.FClosing then FMain.DesFocusInspector(Key, PropName);
end;

procedure TDesignWindowHost.SelectionChanged;
var
  D: TFormDesigner;
begin
  if FMain.FClosing then Exit;
  D := FMain.ActiveDesigner;
  if D <> nil then FMain.DesSelectionChanged(D);
end;

procedure TDesignWindowHost.ComponentsChanged;
var
  D: TFormDesigner;
begin
  if FMain.FClosing then Exit;
  D := FMain.ActiveDesigner;
  if D <> nil then
  begin
    FMain.DesStructureChanged(D);
    FMain.DesModified(D);
  end;
end;

{ "Form1.Button1" or "Form1" among the forms that are open }
{ a root (form, data module) by its name among the open designers - those of the designed page's
  project first: two projects of the group may each have a Form1 }
function TDesignWindowHost.FindGlobalComponent(const Name: string): TComponent;
var
  I, P, Pass: Integer;
  RootName, Rest: string;
  Page: TEditorPage;
  Prj: TSdProject;
begin
  Result := nil;
  P := Pos('.', Name);
  if P > 0 then
  begin
    RootName := Copy(Name, 1, P - 1);
    Rest := Copy(Name, P + 1, MaxInt);
  end
  else
  begin
    RootName := Name;
    Rest := '';
  end;
  Prj := FMain.CodeInsightProject;
  for Pass := 0 to 1 do
    for I := 0 to FMain.FPages.Count - 1 do
    begin
      Page := TEditorPage(FMain.FPages[I]);
      if (Page.Designer <> nil) and (Page.Designer.Root <> nil) and
        SameText(Page.Designer.Root.Name, RootName) and
        ((Pass = 1) or ((Prj <> nil) and (Prj.FindUnit(Page.FileName) <> nil))) then
      begin
        if Rest = '' then Result := Page.Designer.Root
        else Result := Page.Designer.Root.FindComponent(Rest);
        Exit;
      end;
    end;
end;

procedure TDesignWindowHost.OpenRootByName(const RootName: string; Show: Boolean);
begin
end;

procedure TDesignWindowHost.DesignDialog(Dialog: TDesignDialog);
begin
end;

function TMainForm.FindPage(const FileName: string): TEditorPage;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FPages.Count - 1 do
    if SameText(Pages[I].FileName, FileName) then
    begin
      Result := Pages[I];
      Exit;
    end;
end;

{ FileName is a loaded project's of the group: its project file or one of its units }
function TMainForm.FileOfGroup(const FileName: string): Boolean;
begin
  Result := FGroup.FirstOwnerOf(FileName) <> nil;
end;

{ a page locked while a debug session lasts (Mark buffers read-only on run); one read-only
  before stays so after it }
procedure TMainForm.LockForRun(P: TEditorPage);
begin
  if P.Editor.ReadOnly then Exit;
  P.Editor.ReadOnly := True;
  FLockedPages.Add(P);
end;

function TMainForm.OpenFile(const FileName: string; Activate: Boolean): TEditorPage;
var
  Full: string;
begin
  Full := ExpandPathU(FileName);
  Result := FindPage(Full);
  if Result = nil then
  begin
    if not FileExistsU(Full) then
    begin
      MessageBox(Handle, PChar('File not found: ' + Full), AppTitle, MB_OK or MB_ICONERROR);
      Exit;
    end;
    { an expert may refuse it (IOTAIDENotifier.FileNotification) }
    if not OtaFileNotification(ofnFileOpening, Full) then Exit;
    Result := TEditorPage.Create(Self);
    AddPageTab(Result);
    try
      Result.LoadFromFile(Full);
    except
      on E: Exception do
      begin
        FreePage(Result);
        Result := nil;
        MessageBox(Handle, PChar('Cannot open ' + Full + #13#10 + E.Message), AppTitle, MB_OK or MB_ICONERROR);
        Exit;
      end;
    end;
    RefreshBreakMarkers(Result);
    { Reopen's files: the ones no project of the group has }
    if not IsProjectFile(Full) and not FileOfGroup(Full) then
    begin
      AddRecent('RecentFiles', Full);
      if FReopenBatch then FReopenStale := True else UpdateReopenMenu;
    end;
    AdoptPage(Result, Full, Activate);
  end;
  if Activate then ActivatePage(Result);
end;

{ a page whose text has been read (a file's, a file of an expert's file system) joins the file
  area: its tab, locked while a debug session lasts (Mark buffers read-only on run), hidden unless
  it is shown now; the To-Do List takes its text from its editor from now on; the experts are told
  (ofnFileOpened, the view notifiers of its module) }
procedure TMainForm.AdoptPage(Page: TEditorPage; const FileName: string; Activate: Boolean);
begin
  TodoForget(FileName);
  AddDoc(Page);
  if FRunLocked then LockForRun(Page);
  if not Activate then Page.Visible := False;
  OtaFileNotification(ofnFileOpened, FileName);
  OtaModules.PageOpened(Page);
end;

{ a file opened in the view it is to show: a new page goes to its design view while it is still
  hidden - opened in the code view and switched afterwards, the editor showed before the designer
  (the project's main form at start-up) }
function TMainForm.OpenFileView(const FileName: string; Design, Activate: Boolean): TEditorPage;
begin
  Result := OpenFile(FileName, False);
  if Result = nil then Exit;
  if Design and Result.HasForm then Result.ShowDesign(True, False);
  if Activate then
  begin
    ActivatePage(Result);
    if Result.DesignView then Result.ShowDesign(True);    // the designer takes the focus
  end;
end;

{ Page comes up on top of the page shown, which goes only afterwards: Old is freed (a file closed,
  a form's text back into the form), nil hides every other page. Hidden or freed first, the old
  page uncovered the centre's ground (the design view's colour) until the new one had
  painted - every switch of the file tabs showed an empty design view turning into the code.
  Nothing of the centre reaches the screen meanwhile, and the new page comes
  at the next paint in one piece (UIBeginSwap): a page that is shown is erased and framed at
  once, its contents later, window by window - the design view's stage first, then the form,
  then each control, with the old page showing through for up to 35 ms. The main form's bars go
  onto the page's bar while it covers the old one (ArrangePageBar). A page shown already is no
  swap. }
procedure TMainForm.SwapPage(Page, Old: TWinControl);
var
  I: Integer;
  Swap: Boolean;
  D: TWinControl;
begin
  Swap := not Page.Visible;
  if Swap then UIBeginSwap(CenterPanel);
  try
    if Swap then
    begin
      Page.BringToFront;
      Page.Visible := True;
      ArrangePageBar(Page);
    end;
    { the window of the files' text: the page's file, over its slot (above the page); the
      navigation bar's lists of the page while nothing reaches the screen - filled afterwards, a
      box's refresh painted the centre at once through its composited buffer, the editor black in it }
    if Page is TEditorPage then
    begin
      FEditWindow.Follow(TEditorPage(Page).Slot);
      if not FClosing then FNavBar.Follow(TEditorPage(Page), False);
    end
    else
    begin
      FEditWindow.Follow(nil);
      if not FClosing then FNavBar.Follow(nil, False);
    end;
    if Old <> nil then
      FreePage(Old)
    else
      for I := 0 to FDocs.Count - 1 do
      begin
        D := TWinControl(FDocs[I]);
        if D = Page then Continue;
        if D is TEditorPage then TEditorPage(D).CloseCodePopups;
        D.Visible := False;
      end;
  finally
    if Swap then UIEndSwap(CenterPanel);
  end;
end;

{ a page comes up with its tab. A resource is no place of the browse history, and the Object
  Inspector and the Object TreeView have nothing of it }
procedure TMainForm.ActivatePage(Page: TWinControl);
var
  Idx: Integer;
  P: TEditorPage;
begin
  Idx := FDocs.IndexOf(Page);
  if Idx < 0 then Exit;
  if Page is TSdResPage then
  begin
    if FPageTabs.TabIndex <> Idx then FPageTabs.TabIndex := Idx;
    SwapPage(Page, nil);
    if not FClosing then
    begin
      if FInspector.Designer <> nil then FInspector.SetDesigner(nil);
      RefreshObjTree(False);
      UpdateExplorerTitle;
      FCodeExp.Modified;
    end;
    UpdateStatus;
    if Active then TSdResPage(Page).FocusEditor;
    Exit;
  end;
  P := TEditorPage(Page);
  { another file shown: a jump of the browse history, from the page shown before }
  if P <> FNavPage then
  begin
    NavMark;
    FNavPage := P;
  end;
  if FPageTabs.TabIndex <> Idx then FPageTabs.TabIndex := Idx;
  { its form with what its frames and ancestors changed meanwhile, before it shows }
  if P.DesignView and not FClosing then P.FollowAncestors;
  SwapPage(P, nil);
  PageViewChanged(P);
  UpdateStatus;
  { a file of another project of the group: code insight with that project's units and paths }
  if not FClosing and not FClosingAll and (CodeInsightProject <> FCIProject) then ConfigureCodeInsight;
  if P.CodeView and P.Editor.CanFocus and Active then P.Editor.SetFocus;
  OtaModules.PageActivated(P);
end;

procedure TMainForm.TabsChange(Sender: TObject);
begin
  if FClosing then Exit;
  if ActiveDoc <> nil then ActivatePage(ActiveDoc);
end;

{ a click on a file tab's close box closes the page, as the middle button does }
procedure TMainForm.TabsClose(Sender: TObject; Index: Integer);
begin
  if (Index >= 0) and (Index < FDocs.Count) then CloseDoc(TWinControl(FDocs[Index]), True);
end;

{ middle button on a file tab closes the file; the right button activates its tab and shows
  the tab menu }
procedure TMainForm.TabsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  P: TPoint;
begin
  I := FPageTabs.IndexOfTabAt(X, Y);
  if (I < 0) or (I >= FDocs.Count) then Exit;
  if Button = mbMiddle then
    TabsClose(Sender, I)
  else if Button = mbRight then
  begin
    ActivatePage(TWinControl(FDocs[I]));
    P := FPageTabs.ClientToScreen(Point(X, Y));
    TabPopup.Popup(P.X, P.Y);
  end;
end;

procedure TMainForm.PageViewChanged(Page: TEditorPage);
begin
  if FClosing then Exit;
  { the inspector follows the active page's designer }
  if Page.Designer <> FInspector.Designer then FInspector.SetDesigner(Page.Designer);
  RefreshObjTree(False);
  { the Code Explorer: its caption at once, the unit's tree 500 ms later (Delphi's parse), the
    caret's node with Synchronize with the editor }
  UpdateExplorerTitle;
  FCodeExp.Modified;
  ExpFollowCaret(Page);
  ArrangePageBar(Page);                  // the view's bars on the page bar
  FNavBar.Follow(Page, False);           // the caret's class and routine; a changed text waits for StructTimer
end;

function TMainForm.DocZoomView(Doc: TWinControl): ISdZoomView;
begin
  Result := nil;
  if Doc is TEditorPage then Result := TEditorPage(Doc).ZoomView
  else if Doc is TSdResPage then Result := TSdResPage(Doc).ZoomView;
end;

{ only while the zoom bar lies on a page bar: a tool button shown or hidden asks its bar's window
  (TB_HIDEBUTTON), which a bar with no parent cannot make - the zoom bar has none between pages }
function TMainForm.ShowZoomFit(const ZV: ISdZoomView): Boolean;
var
  Fits: Boolean;
begin
  Fits := (ZV <> nil) and ZV.CanZoomFit;
  Result := (ZoomBar.Parent <> nil) and (tbZoomFit.Visible <> Fits);
  if Result then tbZoomFit.Visible := Fits;
end;

{ the page's bars on its page bar, then the zoom bar's Fit button for its view - arranged again when
  that button came or went, for the zoom bar's new width }
procedure TMainForm.ArrangePageBar(Doc: TWinControl);
var
  Pass: Integer;
begin
  if FClosing then Exit;
  for Pass := 1 to 2 do
  begin
    if Doc is TEditorPage then TEditorPage(Doc).ArrangePageBar
    else if Doc is TSdResPage then TSdResPage(Doc).ArrangePageBar;
    if not ShowZoomFit(DocZoomView(Doc)) then Break;
  end;
end;

procedure TMainForm.ZoomViewChanged(Sender: TObject);
begin
  if not FClosing then UpdateStatus;
end;

procedure TMainForm.EditorZoomChanged(Sender: TObject);
begin
  ApplyZoom;
end;

{ the Save dialog of the IDE (SdDialogs.BrowseFile: Unicode names, an existing file asked
  about); FileName goes in as the proposal and comes back as the choice }
function TMainForm.AskSaveName(const Title, Filter, DefaultExt: string; var FileName: string): Boolean;
begin
  Result := BrowseFile(Title, Filter, FileName, bfSave, DefaultExt);
end;

{ Delphi's Open Project: a project or a package (Groups: a project group too) }
function TMainForm.AskProjectFile(Groups: Boolean; out FileName: string): Boolean;
begin
  FileName := '';
  if Groups then
    Result := BrowseFile('Open Project', 'Delphi projects, packages and groups (*.dpr;*.dpk;*.bpg)|' +
      '*.dpr;*.dpk;*.bpg|Delphi project (*.dpr)|*.dpr|Delphi package (*.dpk)|*.dpk|Project group (*.bpg)|*.bpg',
      FileName)
  else
    Result := BrowseFile('Open Project', 'Delphi projects and packages (*.dpr;*.dpk)|*.dpr;*.dpk', FileName);
end;

{ Page under another name; the browse history's places follow it }
function TMainForm.SavePageAs(Page: TEditorPage; const FileName: string): Boolean;
var
  Old: string;
begin
  Old := Page.FileName;
  SyncBreakpoints(Page);                 // its breakpoints' lines as the markers have them
  OtaModules.PageSaving(Page);
  Result := Page.SaveAs(FileName);
  if Result then
  begin
    PageMoved(Page, Old);
    OtaModules.PageSaved(Page);
    { the project may still list the unit under its old name }
    BrowserFileSaved(Old);
    BrowserFileSaved(Page.FileName);
  end;
end;

{ ... nothing written (Delphi 7's IOTAModule.FileName): the page modified, Save writes it there }
procedure TMainForm.RenamePageOnly(Page: TEditorPage; const FileName: string);
var
  Old: string;
begin
  Old := Page.FileName;
  SyncBreakpoints(Page);
  Page.Rename(FileName);
  PageMoved(Page, Old);
end;

{ Page has the name now that was Old: the breakpoints go with the file (else the markers would go at
  the next refresh: the engine has none for that name), the browse history and its module follow }
procedure TMainForm.PageMoved(Page: TEditorPage; const Old: string);
begin
  if not SameText(Old, Page.FileName) then FDebug.RenameFileBreakpoints(Old, Page.FileName);
  FHistory.Renamed(Old, Page.FileName);
  OtaModules.PageRenamed(Page, Old);
end;

function TMainForm.SavePage(Page: TEditorPage): Boolean;
begin
  if Page.Untitled then
    Result := SaveDocAs(Page)
  else
  begin
    SyncBreakpoints(Page);
    OtaModules.PageSaving(Page);
    Result := Page.Save;
    if Result then
    begin
      OtaModules.PageSaved(Page);
      BrowserFileSaved(Page.FileName);
    end;
  end;
  if Result then
  begin
    UpdatePageTab(Page);
    ProjectTextChanged(Page);          // a project's source (any project of the group): its units as saved
  end;
  UpdateStatus;
end;

function TMainForm.SaveDoc(Doc: TWinControl): Boolean;
begin
  if Doc is TEditorPage then Result := SavePage(TEditorPage(Doc))
  else Result := SaveResPage(TSdResPage(Doc));
end;

function TMainForm.SaveAllPages: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FDocs.Count - 1 do
    if DocModified(TWinControl(FDocs[I])) then
      if not SaveDoc(TWinControl(FDocs[I])) then Result := False;
end;

{ "Save changes to X?" for a modified page: False when the user cancels or the save fails }
function TMainForm.ConfirmSave(Page: TWinControl): Boolean;
begin
  Result := True;
  if not DocModified(Page) then Exit;
  case MessageBox(Handle, PChar('Save changes to ' + DocTitle(Page) + '?'), 'Confirm',
    MB_YESNOCANCEL or MB_ICONQUESTION) of
    IDYES: Result := SaveDoc(Page);
    IDCANCEL: Result := False;
  end;
end;

{ the page that comes up when Page closes: the next tab, else the one before - not Skip, which
  closes with it; nil when none is left }
function TMainForm.FollowingPage(Page, Skip: TWinControl): TWinControl;
begin
  Result := FollowingPageOf(Page, nil, Skip);
end;

{ D goes with the pages of Docs: it is one of them, or the text of a form (View as Text) whose unit
  is one of them }
function DocGoes(D: TWinControl; Docs: TList): Boolean;
begin
  Result := (Docs.IndexOf(D) >= 0) or ((D is TEditorPage) and (TEditorPage(D).FormOwner <> nil) and
    (Docs.IndexOf(TEditorPage(D).FormOwner) >= 0));
end;

{ the page that comes up when Page goes: the next tab, else the one before, passing over the ones
  that go as well - Skip, and those that go with the pages of Going (nil: none, DocGoes); nil when
  none stays }
function TMainForm.FollowingPageOf(Page: TWinControl; Going: TList; Skip: TWinControl): TWinControl;
var
  I, Idx: Integer;

  function Stays(D: TWinControl): Boolean;
  begin
    Result := (D <> Skip) and ((Going = nil) or not DocGoes(D, Going));
  end;

begin
  Result := nil;
  Idx := FDocs.IndexOf(Page);
  for I := Idx + 1 to FDocs.Count - 1 do
    if Stays(TWinControl(FDocs[I])) then
    begin
      Result := TWinControl(FDocs[I]);
      Exit;
    end;
  for I := Idx - 1 downto 0 do
    if Stays(TWinControl(FDocs[I])) then
    begin
      Result := TWinControl(FDocs[I]);
      Exit;
    end;
end;

{ the page goes: the one that comes up comes over it before it goes (SwapPage); Swap: one comes
  up (not while the project or the IDE closes) }
procedure TMainForm.LeavePage(Page: TWinControl; Swap: Boolean);
var
  Follower, Active: TWinControl;
  Shown: Boolean;
begin
  Follower := FollowingPage(Page, nil);
  Shown := Page.Visible;
  Active := ActiveDoc;
  if Swap and (Follower <> nil) and Shown then SwapPage(Follower, Page) else FreePage(Page);
  if Follower = nil then
  begin
    FTabRow.Visible := False;
    UpdateStatus;
  end
  else if Swap then
    { the follower comes up when the page went from view (or ClosePage showed it already in
      place of a form's text); a page closed in the background leaves the page shown and its tab }
    if Shown or Follower.Visible or (Active = Page) or (Active = nil) then ActivatePage(Follower)
    else FPageTabs.TabIndex := FDocs.IndexOf(Active);
end;

function TMainForm.CloseDoc(Doc: TWinControl; Prompt: Boolean): Boolean;
begin
  if Doc is TEditorPage then
  begin
    Result := ClosePage(TEditorPage(Doc), Prompt);
    Exit;
  end;
  Result := not Prompt or ConfirmSave(Doc);
  if Result then LeavePage(Doc, not (FClosing or FClosingAll));
end;

{ every page closes, the last first; False: one did not (Prompt: its changes were not let go) }
function TMainForm.CloseAllDocs(Prompt: Boolean): Boolean;
begin
  Result := True;
  while FDocs.Count > 0 do
    if not CloseDoc(TWinControl(FDocs[FDocs.Count - 1]), Prompt) then
    begin
      Result := False;
      Exit;
    end;
end;

{ a page closes; the one that comes up comes over it before it goes (SwapPage) }
function TMainForm.ClosePage(Page: TEditorPage; Prompt: Boolean): Boolean;
var
  T: TEditorPage;
  Follower: TWinControl;
  Swap, FormText: Boolean;
begin
  Result := True;
  if FPages.IndexOf(Page) < 0 then Exit;
  FormText := Page.FormOwner <> nil;
  { an expert may keep the file open (IOTAIDENotifier.FileNotification) - not when D7 Studio ends:
    it is told then as well, its answer does not count. A project's source that closes with its
    project (FClosingAll: the group, a project leaving it - of the group or beside it) was told with
    the project: once. }
  if (Page.FormOwner = nil) and
    not (FClosingAll and ((FGroup.IndexOf(Page.FileName) >= 0) or (FGroup.IndexOfBeside(Page.FileName) >= 0))) and
    not OtaFileNotification(ofnFileClosing, Page.FileName) and not FClosing then
  begin
    Result := False;
    Exit;
  end;
  { the form's text (View as Text): closed, it goes back into the form - not when its form
    closes as well (the project or the IDE closes: what is to be saved was asked) }
  if (Page.FormOwner <> nil) and not FClosing and not FClosingAll then
  begin
    Result := Page.ApplyFormText;
    if not Result then Exit;
    Prompt := False;                     // its text is the form's now
  end;
  Swap := not (FClosing or FClosingAll);
  { a unit whose form is text: the text first. Shown, the text is replaced by the unit when the
    unit is asked about (it stays when that is cancelled), else by the page that comes up when
    both have gone }
  T := Page.FormTextPage;
  if T <> nil then
  begin
    Page.TakeFormText;
    Page.DetachFormText;
    if not Swap or not T.Visible then
      FreePage(T)
    else if Prompt and Page.Modified then
    begin
      SwapPage(Page, T);
      ActivatePage(Page);
    end
    else
    begin
      Follower := FollowingPage(Page, T);
      if Follower <> nil then SwapPage(Follower, T) else FreePage(T);
    end;
  end;
  if Prompt and not ConfirmSave(Page) then
  begin
    Result := False;
    Exit;
  end;
  { changes that are let go (No, or a close that asks nothing): kept as a version of the file }
  if not FormText and Page.Modified then Page.KeepVersion(hkClosed);
  SyncBreakpoints(Page);
  LeavePage(Page, Swap);
end;

{ the designer of Page goes (the page closes, or its form becomes text): the Object Inspector
  and the Object TreeView let go of it }
procedure TMainForm.ForgetDesigner(Page: TEditorPage);
begin
  if (Page.Designer <> nil) and (FObjTree.Designer = Page.Designer) then FObjTree.Clear;
  if (Page.Designer <> nil) and (FInspector.Designer = Page.Designer) then FInspector.SetDesigner(nil);
end;

{ a page goes with its tab; nothing keeps pointing at it or at its designer }
procedure TMainForm.FreePage(Page: TWinControl);
var
  Idx: Integer;
  P: TEditorPage;
begin
  if Page is TEditorPage then
  begin
    P := TEditorPage(Page);
    if P = FErrorPage then FErrorPage := nil;
    if P = FExecPage then FExecPage := nil;
    if P = FNavPage then FNavPage := nil;
    if P.Editor = FFindRangeEd then FFindRangeEd := nil;
    if P.Editor = FFindSkipEd then FFindSkipEd := nil;
    { the Code Explorer showed its unit }
    if P = FExpPage then ExpForget;
    ForgetDesigner(P);
    { its module's notifiers are told Destroyed while the page is there - when D7 Studio ends too,
      as Delphi closes its modules before its experts end (GExperts' module notifiers take
      themselves off then; dropped only with their DLL, they read their freed owner). Not once the
      experts have ended: OtaShutdown, then OtaHost is nil }
    if OtaHost <> nil then OtaModules.PageClosing(P);
    FPages.Remove(P);
    FLockedPages.Remove(P);
  end;
  Idx := FDocs.IndexOf(Page);
  if Idx >= 0 then
  begin
    FDocs.Delete(Idx);
    FPageTabs.Tabs.Delete(Idx);
  end;
  Page.Free;
end;

{ Environment Options | Object Inspector, for the inspector (SdObjInsp keeps its own copy: the
  designer units do not use the IDE's) }
procedure CopyInspectorOptions;
begin
  with OIOptions do
  begin
    ShowInstanceList := EnvOptions.OIShowInstanceList;
    ShowClassNames := EnvOptions.OIShowClassNames;
    ShowStatusBar := EnvOptions.OIShowStatusBar;
    RenderGrid := EnvOptions.OIRenderGrid;
    ShowReadOnly := EnvOptions.OIShowReadOnly;
    BoldNonDefault := EnvOptions.OIBoldNonDefault;
    RefExpand := EnvOptions.OIRefExpand;
    RefOnEvents := EnvOptions.OIRefOnEvents;
    Background := EnvOptions.OIColors[ocBackground];
    Gutter := EnvOptions.OIColors[ocGutter];
    Category := EnvOptions.OIColors[ocCategory];
    NameColor := EnvOptions.OIColors[ocName];
    ValueColor := EnvOptions.OIColors[ocValue];
    NonDefault := EnvOptions.OIColors[ocNonDefault];
    Reference := EnvOptions.OIColors[ocReference];
    ReadOnlyName := EnvOptions.OIColors[ocReadOnly];
  end;
  { Environment Options | Designer: the hints of the form designer }
  DesignEnv.ShowHints := EnvOptions.ShowDesignerHints;
  DesignEnv.ExtendedHints := EnvOptions.ShowExtendedHints;
end;

{ after Environment Options: the editors, the designers, the inspector and the Code Explorer
  take the new options }
{ Environment Options | Preferences | User interface | Fixed-size font (SdUI.UIAssignFixedFont). Only the
  debugger's views (the Event Log, the watches ...): the Messages view keeps the UI font. }
procedure TMainForm.ApplyFixedFont;
begin
  UIAssignFixedFont(FBreakView.BreakList.Font);
  UIAssignFixedFont(CallStackList.Font);
  UIAssignFixedFont(LocalsTree.Font);
  UIAssignFixedFont(EventLogList.Font);
  UIAssignFixedFont(ThreadList.Font);
  UIAssignFixedFont(ModuleList.Font);
  UIAssignFixedFont(FpuList.Font);
  FCpuView.FontChanged(CallStackList.Font);
  FDebugInsp.FontChanged(CallStackList.Font);
  UIAssignFixedFont(FWatchView.Tree.Font);
  FWatchView.FontChanged;
end;

procedure TMainForm.ApplyEditorOptions;
var
  I: Integer;
begin
  LoadWheelZoomKey;                           // Preferences | Zoom key
  ApplyFixedFont;
  EditWindowFontChanged;                      // the editor control's font, as experts measure it (SdOtaEditWindow)
  CopyInspectorOptions;
  if FInspector <> nil then FInspector.OptionsChanged;
  if FDock <> nil then FDock.AutoDragDocking := EnvOptions.AutoDragDocking;
  if FCompBar <> nil then ApplyCompBarOptions;
  ConfigureCodeInsight;                       // the library and browsing paths
  if FBrowser <> nil then
  begin
    { Explorer | Initial browser view, Browser scope }
    FBrowser.View := BrowserViewOf(EnvOptions.ExBrowserView);
    if FBrowser.AllUnits <> (EnvOptions.ExBrowserScope = 1) then
    begin
      FBrowser.AllUnits := EnvOptions.ExBrowserScope = 1;
      if FBrowserPanel.Showing then RebuildBrowser;
    end;
  end;
  { the Code Explorer made again with the Explorer options }
  FExpVersion := -1;
  RefreshExplorer;
  StructTimer.Enabled := False;
  StructTimer.Enabled := True;
  ApplyHistoryOptions;
  for I := 0 to FPages.Count - 1 do
  begin
    Pages[I].Editor.ApplyOptions;
    Pages[I].HistoryOptionsChanged;          // Display | Keep file history: the tab, its windows
    Pages[I].ApplyNavigationBar;             // Display | Navigation bar, a file type's language
    if Pages[I].Designer <> nil then
    begin
      Pages[I].Designer.RefreshGrid;
      Pages[I].Designer.UpdateHelpers;       // component captions, the form positioner on or off
    end;
  end;
  { the experts read the options again (their windows show the editor's font) }
  NotifyEditorOptionsChanged;
end;

{ a project, package or group as OpenProject opens it with ProjectMode - omOpen: a package beside
  an open group -, a type library in its view, any other file as a page }
function TMainForm.OpenAny(const FileName: string; ProjectMode: TOpenMode): Boolean;
begin
  { a project the compiler cannot open (its name is outside the code page and has no short
    name) is shown as a file }
  if (IsProjectFile(FileName) or IsProjectGroupFile(FileName)) and not IsUnicodePath(FileName) then
  begin
    OpenProject(FileName, ProjectMode);
    Result := ProjectIsOpen(FileName);
  end
  else if IsTypeLibFile(FileName) then
    Result := OpenTypeLibrary(FileName)
  else
    Result := OpenFile(FileName, True) <> nil;
end;

{ ---------------------------------------------------------------- project }

{ the text of a file as the IDE has it (editor text of E, its encoding): the editor's when it is
  open, else the file's as the editor would open it }
function TMainForm.SourceAndEncoding(const FileName: string; out E: TSdEncoding): string;
var
  P: TEditorPage;
begin
  P := FindPage(FileName);
  if P <> nil then
  begin
    Result := P.GetSource;
    E := P.Encoding;
  end
  else
    Result := ReadSourceFile(FileName, E);
end;

function TMainForm.SourceOf(const FileName: string): string;
var
  E: TSdEncoding;
begin
  Result := SourceAndEncoding(FileName, E);
end;

function TMainForm.SourceEncoding(const FileName: string): TSdEncoding;
var
  P: TEditorPage;
begin
  P := FindPage(FileName);
  if P <> nil then Result := P.Encoding
  else if not RememberedEncoding(FileName, Result) then
    if FileExistsU(FileName) then Result := DetectEncoding(ReadFileU(FileName))
    else Result := SystemEncoding;
end;

{ Changes the text of a project source as one undo step of its page, not saved - as Delphi 7
  keeps the project source of an added or removed unit until the project is saved (a project
  source not open is opened in the background). Only when no page can be opened (an expert
  refused it) is the file written, in its encoding. }
procedure TMainForm.SetSourceOf(const FileName, Source: string);
var
  P: TEditorPage;
begin
  P := FindPage(FileName);
  if (P = nil) and FileExistsU(FileName) then P := OpenFile(FileName, False);
  if P <> nil then P.SetSourceUndoable(Source)
  else WriteSourceFile(FileName, Source, SourceEncoding(FileName));
end;

function TMainForm.ProjectSource: string;
begin
  if FProject = nil then Result := '' else Result := SourceOf(FProject.FileName);
end;

{ the source of P, a project of the group (the active one or another): as SetSourceOf, then
  parsed (its units are new objects: RefreshProjectTree must follow) }
procedure TMainForm.SetProjectSourceOf(P: TSdProject; const Source: string);
begin
  if P = nil then Exit;
  SetSourceOf(P.FileName, Source);
  { Source is the editor's text of the page's encoding (the file's, when no page could be opened) }
  P.ParseSource(Source, SourceEncoding(P.FileName));
end;

function TMainForm.NameForSource(const SourceFile, Name: string; const E: TSdEncoding; out Text: string): Boolean;
var
  Lost: Boolean;
begin
  Result := ConvertText(Name, IdeEncoding, E, Text, Lost) and not Lost;
  if not Result then
    MessageBox(Handle, PChar(Format('%s cannot name %s: it is in %s, which has no character for some of ' +
      'that name - Delphi 7 could not read it there either. Move the file, or convert %0:s to UTF-8 ' +
      '(File | Convert to Encoding): only the UTF-8 compiler builds the project then.',
      [ExtractFileName(SourceFile), Name, EncodingName(E)])), AppTitle, MB_OK or MB_ICONERROR);
end;

function TMainForm.ProjectSourceName(P: TSdProject; const FileName: string; out Rel: string): Boolean;
begin
  Result := NameForSource(P.FileName, ExtractRelativePath(P.Dir, FileName), SourceEncoding(P.FileName), Rel);
end;

{ the project source after a change of its units (new unit, form, add/remove, options): the
  tree and the paths of code insight follow }
procedure TMainForm.ProjectSourceChanged(const Source: string);
begin
  ProjectSourceChangedOf(FProject, Source);
end;

procedure TMainForm.ProjectSourceChangedOf(P: TSdProject; const Source: string);
begin
  SetProjectSourceOf(P, Source);
  RefreshProjectTree;
  ConfigureCodeInsight;
end;

{ a project file loaded; nil when it cannot be read (Why: the reason) }
function TMainForm.LoadProjectFile(const FileName: string; out Why: string): TSdProject;
begin
  Why := '';
  Result := TSdProject.Create;
  try
    Result.Load(FileName);
  except
    on E: Exception do
    begin
      FreeAndNil(Result);
      Why := E.Message;
    end;
  end;
end;

{ ... nil when it cannot be read, and the user is told why (Open Project's message) }
function TMainForm.LoadProjectOrSay(const FileName: string): TSdProject;
var
  Why: string;
begin
  Result := LoadProjectFile(FileName, Why);
  if Result = nil then
    MessageBox(Handle, PChar('Cannot open project: ' + Why), AppTitle, MB_OK or MB_ICONERROR);
end;

{ P, loaded from FileName, is in the group now: the experts hear it opened, and its breakpoints
  (its section of the settings) join the engine's }
procedure TMainForm.ProjectJoined(const FileName: string; P: TSdProject);
begin
  { the project's .res ($R *.res) missing: Delphi 7's message (the next compile writes the file) }
  if LinksProjectRes(SourceOf(FileName)) and not FileExistsU(ChangeFileExt(FileName, '.res')) then
    DelphiMessageDlg(Format('Cannot find resource file: %s.  Recreated.', [ChangeFileExt(FileName, '.res')]),
      mtError, [mbOK]);
  OtaFileNotification(ofnFileOpened, FileName);
  LoadProjectBreakpoints(P);
end;

{ The project group closes with every project and every file, and with the packages open beside
  it (Close All, Open Project, New Application, the IDE ends, an expert closes the group - Delphi's
  CloseMiscProjects): the experts are asked about each project first - one that refuses keeps the
  whole group, except when D7 Studio ends -, the desktop is saved, every unsaved page asked about
  (a Cancel keeps everything), the breakpoints written into their projects' sections; then the
  pages close, the Open Tools API's modules of the projects and the group go and the views start
  empty. }
function TMainForm.CloseGroup: Boolean;
var
  I: Integer;
  F: string;
begin
  Result := True;
  if FGroup.AllCount = 0 then
  begin
    { the empty group's module goes too: after Delphi 7's Close All no module is left }
    OtaModules.Forget(OtaModules.GroupKey);
    FGroup.Clear;                      // a group file without projects
    Exit;
  end;
  FlushOtaOptions;
  if CompileBusy then
  begin
    Result := False;
    Exit;
  end;
  for I := 0 to FGroup.AllCount - 1 do
    if (FGroup.AllProject(I) <> nil) and not OtaFileNotification(ofnFileClosing, FGroup.AllFile(I)) and not FClosing then
    begin
      Result := False;
      Exit;
    end;
  StopDebugNow;
  SaveDesktop;
  for I := 0 to FDocs.Count - 1 do
    if not ConfirmSave(TWinControl(FDocs[I])) then
    begin
      Result := False;
      Exit;
    end;
  { remember the breakpoints of the projects }
  SaveProjectBreakpoints(nil);
  { no page is activated on the way: each one would be parsed and shown only to go (a form's
    text goes without being taken into its form, which goes as well: ClosePage); a page that
    cannot close keeps the project open }
  FClosingAll := True;
  try
    if not CloseAllDocs(False) then
    begin
      Result := False;
      Exit;
    end;
  finally
    FClosingAll := False;
  end;
  { the browse history was the projects' files }
  FHistory.Clear;
  FNavPending := False;
  { the active project goes with the rest: no other one is activated on the way }
  FProject := nil;
  FGroup.Active := nil;
  while FGroup.BesideCount > 0 do
  begin
    F := FGroup.Beside(0).FileName;    // a copy: the package is freed as it goes
    ProjectGoes(F, True, False);
  end;
  GroupEmptied;
end;

{ OpenProject's omOpen (Delphi's package create mode 1): a package opens beside an open group }
function TMainForm.OpensBeside(const FileName: string; Mode: TOpenMode): Boolean;
begin
  Result := (Mode = omOpen) and IsPackageFile(FileName) and (FGroup.Count > 0);
end;

{ Before FileName opens with Mode in a group of its own (OpenProject; a new project, before its
  files are written): the open group goes - Close All's questions -, and the views start empty.
  The packages beside the group go with it, as Delphi's new workspace closes its misc projects -
  not when the group is empty and a project joins it (the group and its Open Tools API module
  stay, as Delphi's workspace takes it), nor when packages are beside the empty group and another
  package opens as File | Open opens it: Delphi makes no new workspace for these. }
function TMainForm.CloseForProject(const FileName: string; Mode: TOpenMode): Boolean;
begin
  if (FGroup.Count = 0) and ((Mode = omAddToGroup) or
    ((FGroup.BesideCount > 0) and (Mode = omOpen) and IsPackageFile(FileName))) then
  begin
    FGroup.Clear;                      // a group file without projects
    Result := True;
    Exit;
  end;
  Result := ConfirmSaveGroup and CloseGroup;
  if Result then ResetViews;           // also after loose files without a project
end;

{ P is the active project now (Delphi's TWorkspace.ActivateProject: a pointer switch). Every file
  stays open where it is, no desktop is read, no main form opened; the Open Tools API's objects,
  the breakpoints, the watches, Messages and the debugger's views stay - a debug session goes on
  (Run, Step and Reset drive its program), and so do the package editors, each with its package.
  What shows the active project follows: the caption, the Project Manager (bold), the Resources
  view, the To-Do List, the Browser (emptied), code insight; the experts hear
  ofnActiveProjectChanged. Refused while a compile runs. }
procedure TMainForm.SetActiveProject(P: TSdProject);
begin
  if P = FProject then Exit;
  if CompileBusy then Exit;
  { an expert's options of the project before are written for that project }
  FlushOtaOptions;
  FProject := P;
  FGroup.Active := P;
  if P <> nil then
  begin
    FTodo.Table.Caption := ExtractFileName(P.FileName);   // Copy As | HTML Table's caption
    SetCurrentDir(P.Dir);
  end
  else
    FTodo.Table.Caption := '';
  UpdateCaption;
  RefreshProjectTree;                      // with the package editors and the Resources view
  FBrowser.Clear;
  ConfigureCodeInsight;
  if FBottomPanels[BT_TODO].Showing then RefreshTodoList;
  TodoProjectLater;
  if P <> nil then OtaFileNotification(ofnActiveProjectChanged, P.FileName);
end;

{ Messages and Search Results empty (Clear All Messages, a project that goes) }
procedure TMainForm.ClearMessageViews;
begin
  ClearBuildMessages;
  ClearSearchResults;
end;

{ Messages' Build group empty (the experts' message services are told) }
procedure TMainForm.ClearBuildMessages;
begin
  MessageList.Items.Clear;
  OtaBuildMessagesCleared;
end;

{ The views start empty for the next project: the project tree, the Code Explorer and the Object TreeView, Messages and
  Search Results, the debugger's views - its breakpoints and watches are the project's, kept
  with it (the breakpoints in the settings, the watches in its desktop) - the Event Log and the
  To-Do List. KeepDebug: the debugger's part stays - breakpoints, watches, its views, the Event
  Log (a package open beside the group stays). The arrangement of the views stays the user's. }
procedure TMainForm.ResetViews(KeepDebug: Boolean);
var
  None: TStringList;
begin
  FProjView.Clear;
  ExpForget;
  FObjTree.Clear;
  ClearMessageViews;
  FTodoView.Clear;
  FTodo.Clear;
  ClearTodoTexts;
  FBrowser.Clear;
  if KeepDebug then Exit;
  EventLogList.Items.Clear;
  None := TStringList.Create;
  try
    FDebug.LoadBreakpoints(None);
    FDebug.SetWatches(None);
  finally
    None.Free;
  end;
  FDebug.ClearViews;
end;

{ A project opens. Mode omNewGroup - in a group of its own, the group before closed (saved first if
  the user wants it) with the packages beside it; its desktop (Autosave options | Project desktop)
  or its main form. omAddToGroup - into the open group, which keeps its projects and files; it
  becomes the active project and shows its main form (a package: its package editor), never its
  desktop (Delphi's DisplayProject); a package open beside the group joins it as it is. omOpen -
  Delphi's File | Open: a package beside the open group (OpenBeside), anything else as omNewGroup.
  Into an empty group a project opens as into a group of its own (CloseForProject). Open already:
  a project of the group is activated (omAddToGroup), a package shows its package editor (omOpen).
  A .bpg opens as a group. }
procedure TMainForm.OpenProject(const FileName: string; Mode: TOpenMode);
var
  P: TSdProject;
  NewGroup: Boolean;
begin
  if IsProjectGroupFile(FileName) then
  begin
    OpenProjectGroup(FileName);
    Exit;
  end;
  P := FGroup.LoadedProjectOf(FileName);
  if (Mode = omAddToGroup) and (FGroup.IndexOf(FileName) >= 0) then
  begin
    ActivateProject(FileName);
    Exit;
  end;
  if (Mode = omOpen) and IsPackageFile(FileName) and ((P <> nil) or (FGroup.IndexOf(FileName) >= 0)) then
  begin
    { a closed one of the group is loaded again first }
    if P = nil then
    begin
      ActivateProject(FileName);
      P := FGroup.ProjectOf(FileName);
    end;
    ShowPackageEditor(P, True);
    Exit;
  end;
  if not FileExists(FileName) then
  begin
    MessageBox(Handle, PChar('Project not found: ' + FileName), AppTitle, MB_OK or MB_ICONERROR);
    Exit;
  end;
  { a compile uses the group's projects: none joins it or goes meanwhile }
  if CompileBusy then Exit;
  if (Mode = omAddToGroup) and (P <> nil) then
  begin
    { a package beside the group joins it (active already: its node moves into the group) }
    FGroup.AddLoaded(FGroup.ExtractBeside(FGroup.IndexOfBeside(FileName)));
    if P = FProject then RefreshProjectTree else SetActiveProject(P);
    DisplayProject(P);
    Exit;
  end;
  if OpensBeside(FileName, Mode) then
  begin
    { its editor shown once it is the active project, with the keyboard }
    P := OpenBeside(FileName, '', False, True);
    if P = nil then Exit;
    ShowPackageEditor(P, True);
  end
  else
  begin
    NewGroup := (Mode <> omAddToGroup) or (FGroup.Count = 0);
    if not OtaFileNotification(ofnFileOpening, FileName) then Exit;
    { a project opened on its own starts a group of its own (Delphi's ProjectGroup1) }
    if NewGroup and not CloseForProject(FileName, Mode) then Exit;
    P := LoadProjectOrSay(FileName);
    if P = nil then Exit;
    FGroup.AddLoaded(P);
    if NewGroup then FGroup.Modified := False;
    ProjectJoined(FileName, P);
    SetActiveProject(P);
    { the files of the last session of a project opened on its own (Autosave options | Project
      desktop); a project added to the group shows its main form; a package always its editor }
    if not (NewGroup and LoadDesktop) or P.IsPackage then DisplayProject(P);
  end;
  AddRecent('RecentProjects', P.FileName);
  UpdateReopenMenu;
end;

function TMainForm.ProjectIsOpen(const FileName: string): Boolean;
begin
  Result := (FGroup.LoadedProjectOf(FileName) <> nil) or SameText(FGroup.FileName, FileName);
end;

{ A package opens beside the open group (Delphi's misc project; OpenProject's omOpen, a desktop):
  the group, its projects and files stay as they are; the package is in none of them - the Project
  Manager shows it after the group -, has its package editor (ViewName: the one a desktop gives
  it; Show: shown) and is told to the experts as every project opened. Activate: it becomes the
  active project, as Delphi's THiddenRoot.AddUnboundPackage makes it. nil: not opened (an expert
  refused it, the file cannot be read) }
function TMainForm.OpenBeside(const FileName, ViewName: string; Show, Activate: Boolean): TSdProject;
begin
  Result := nil;
  if not OtaFileNotification(ofnFileOpening, FileName) then Exit;
  Result := LoadProjectOrSay(FileName);
  if Result = nil then Exit;
  FGroup.AddBeside(Result);
  ProjectJoined(FileName, Result);
  PackageViewOf(Result, True, ViewName);
  if Show then ShowPackageEditor(Result);
  if Activate then
    SetActiveProject(Result)
  else
  begin
    RefreshProjectTree;
    { the page shown may be one of its units: code insight works for it then }
    if CodeInsightProject <> FCIProject then ConfigureCodeInsight;
  end;
end;

{ Delphi's DisplayProject: the project's main form in the designer (its first unit with a form,
  else its first unit, else its source); a package opens in its package editor, as in Delphi 7 -
  no unit with it -, which takes the keyboard }
procedure TMainForm.DisplayProject(P: TSdProject);
var
  I: Integer;
  First: string;
begin
  if P.IsPackage then
  begin
    ShowPackageEditor(P, True);
    Exit;
  end;
  First := '';
  for I := 0 to P.UnitCount - 1 do
    if P.Units[I].HasForm and FileExists(P.Units[I].FileName) then
    begin
      First := P.Units[I].FileName;
      Break;
    end;
  if (First = '') and (P.UnitCount > 0) and FileExists(P.Units[0].FileName) then
    First := P.Units[0].FileName;
  if First = '' then First := P.FileName;
  OpenFileView(First, True, True);
end;

{ the project of a breakpoint: the first loaded project whose project file or unit its file is
  (a source breakpoint; a package beside the group too), else the active project - else the first
  loaded one }
function TMainForm.BreakpointProject(BP: TDbgBreakpoint): TSdProject;
begin
  Result := nil;
  if BP.Kind = bkSource then Result := FGroup.FirstOwnerOf(BP.FileName);
  if Result = nil then Result := FProject;
  if Result = nil then Result := FGroup.FirstLoaded;
end;

{ the breakpoints into the settings, each into its project's section (BreakpointProject): the
  sections of the loaded projects written anew - Only: that project's alone }
procedure TMainForm.SaveProjectBreakpoints(Only: TSdProject);
var
  L, Lines: TStringList;
  I, K: Integer;
  P: TSdProject;
  Section: string;
  Owners: array of TSdProject;       // the project of each breakpoint (BreakpointProject), found once
begin
  SyncAllBreakpoints;
  L := TStringList.Create;
  Lines := TStringList.Create;
  try
    FDebug.SaveBreakpoints(L);
    SetLength(Owners, FDebug.BreakpointCount);
    for I := 0 to High(Owners) do Owners[I] := BreakpointProject(FDebug.Breakpoint(I));
    for K := 0 to FGroup.AllCount - 1 do
    begin
      P := FGroup.AllProject(K);
      if (P = nil) or ((Only <> nil) and (P <> Only)) then Continue;
      Lines.Clear;
      for I := 0 to L.Count - 1 do
        if (I < Length(Owners)) and (Owners[I] = P) then Lines.Add(L[I]);
      Section := 'Breakpoints:' + P.FileName;
      Settings.EraseSection(Section);
      for I := 0 to Lines.Count - 1 do Settings.WriteString(Section, IntToStr(I), Lines[I]);
    end;
  finally
    Lines.Free;
    L.Free;
  end;
end;

{ P's breakpoints (its section of the settings) join the engine's: a place that has one already
  keeps it (a unit of two projects) }
procedure TMainForm.LoadProjectBreakpoints(P: TSdProject);
var
  I: Integer;
  L, Keys: TStringList;
  Section: string;
begin
  if P = nil then Exit;
  Section := 'Breakpoints:' + P.FileName;
  L := TStringList.Create;
  Keys := TStringList.Create;
  try
    Settings.ReadSection(Section, Keys);
    for I := 0 to Keys.Count - 1 do L.Add(Settings.ReadString(Section, Keys[I], ''));
    if L.Count = 0 then Exit;
    SyncAllBreakpoints;
    FDebug.AddBreakpoints(L);
    FDebug.BreakpointsChanged;
  finally
    Keys.Free;
    L.Free;
  end;
end;

{ P leaves: its breakpoints leave the engine - not those whose file another loaded project has
  (they belong to it from now on) }
procedure TMainForm.DropProjectBreakpoints(P: TSdProject);
var
  I: Integer;
  BP: TDbgBreakpoint;
  L: TList;
  Changed: Boolean;
begin
  if P = nil then Exit;
  Changed := False;
  L := TList.Create;
  try
    for I := FDebug.BreakpointCount - 1 downto 0 do
    begin
      BP := FDebug.Breakpoint(I);
      if BreakpointProject(BP) <> P then Continue;
      if BP.Kind = bkSource then
      begin
        FGroup.OwnersOf(BP.FileName, L);
        L.Remove(P);
        if L.Count > 0 then Continue;
      end;
      FDebug.Debugger.RemoveBreakpoint(BP);
      Changed := True;
    end;
  finally
    L.Free;
  end;
  if Changed then FDebug.BreakpointsChanged;
end;

{ the pages that go with a project that leaves the group: its project file's, its units' that no
  other loaded project has (a form's text goes with its unit), its resources' pages }
procedure TMainForm.ProjectOwnDocs(P: TSdProject; const ProjectFile: string; Docs: TList);
var
  I: Integer;
  D: TWinControl;
  F: string;
  L: TList;
begin
  Docs.Clear;
  L := TList.Create;
  try
    for I := 0 to FDocs.Count - 1 do
    begin
      D := TWinControl(FDocs[I]);
      if D is TSdResPage then
      begin
        if SameText(TSdResPage(D).ProjectFile, ProjectFile) then Docs.Add(D);
        Continue;
      end;
      if TEditorPage(D).FormOwner <> nil then Continue;
      F := TEditorPage(D).FileName;
      if SameText(F, ProjectFile) then
      begin
        Docs.Add(D);
        Continue;
      end;
      if (P = nil) or (P.FindUnit(F) = nil) then Continue;
      FGroup.OwnersOf(F, L);
      L.Remove(P);
      if L.Count = 0 then Docs.Add(D);
    end;
  finally
    L.Free;
  end;
end;

{ Docs close without a question (it was asked); the page shown, when it goes, makes room for
  the one next to it. False: one stayed (an expert kept its file open) }
function TMainForm.CloseProjectDocs(Docs: TList): Boolean;
var
  I: Integer;
  Old, Follower: TWinControl;
begin
  Result := True;
  Old := ActiveDoc;
  Follower := nil;
  if (Old <> nil) and DocGoes(Old, Docs) then Follower := FollowingPageOf(Old, Docs, nil);
  { no page comes up on the way: each would be shown only to go }
  FClosingAll := True;
  try
    for I := Docs.Count - 1 downto 0 do
      if (FDocs.IndexOf(Docs[I]) >= 0) and not CloseDoc(TWinControl(Docs[I]), False) then Result := False;
  finally
    FClosingAll := False;
  end;
  if (Old <> nil) and (FDocs.IndexOf(Old) >= 0) then
    { the page shown stays: its tab, after the ones that went }
    FPageTabs.TabIndex := FDocs.IndexOf(Old)
  else if (Follower <> nil) and (FDocs.IndexOf(Follower) >= 0) then
    ActivatePage(Follower)
  else if FDocs.Count > 0 then
    ActivatePage(TWinControl(FDocs[0]));
end;

{ the last project left the group, or the group closed (CloseGroup): no project of the group, the
  views start empty; files that are no project's stay open, and so do the packages beside the
  group - one of them stays the active project }
procedure TMainForm.GroupEmptied;
var
  I: Integer;
begin
  { Delphi's package editors go with their packages (their rows point into the projects) }
  for I := 0 to FGroup.Count - 1 do ReleasePackageView(FGroup.Project(I));
  { the projects' and the group's modules go (their resources written, notifiers told) }
  FResView.Fill(nil);
  OtaModules.ForgetProjects;
  if not FGroup.IsBeside(FProject) then FProject := nil;
  if not FGroup.IsBeside(FDebugProject) then FDebugProject := nil;
  FCIProject := nil;
  FGroup.Clear;
  OtaProjectClosed;
  RefreshResourceView;
  if FProject = nil then FTodo.Table.Caption := '';
  { the packages beside the group stay, and the debugger's state with them: their breakpoints, the
    watches, a session of one of them going on (the group's projects took their breakpoints with
    them as they went: ProjectLeaves) }
  ResetViews(FGroup.BesideCount > 0);
  ConfigureCodeInsight;
  UpdateCaption;
  TodoProjectLater;
end;

const
  ResDeskSection = 'D7 Studio Resources';    // the .dsk's section of the resources' pages
  PkgDeskSection = 'D7 Studio Package Editors';   // ... of the package editors and the packages beside the group

{ the package editors in the desktop - as Delphi keeps each package's window there
  (TPackageFormHandler.SaveModuleForms) -, in a section of D7 Studio's own: per editor view|shown|
  beside|package file, beside 1 for a package open beside the group, which the desktop opens
  again; the view's name keeps its place in the arrangement. Active: such a package when it is the
  active project ([ActiveProject] names the group's) }
procedure TMainForm.SavePackageEditors(D: TCustomIniFile);
var
  I, N: Integer;
  V: TSdPackageView;
begin
  N := 0;
  for I := 0 to FPkgViews.Count - 1 do
  begin
    V := TSdPackageView(FPkgViews[I]);
    if V.Project = nil then Continue;
    D.WriteString(PkgDeskSection, 'Editor' + IntToStr(N), Format('%s|%d|%d|%s', [FDock.PanelOf(V).Name,
      Ord(FDock.PanelOf(V).Visible), Ord(FGroup.IsBeside(V.Project)), V.Project.FileName]));
    Inc(N);
  end;
  if N > 0 then D.WriteInteger(PkgDeskSection, 'Count', N);
  if FGroup.IsBeside(FProject) then D.WriteString(PkgDeskSection, 'Active', FProject.FileName);
end;

{ ... read back: a package of the group gets its editor (shown as it was), a package beside the
  group opens again - the active one as the active project, so that its node opens as a project's
  new in the tree that is active; one whose file is gone is left out }
procedure TMainForm.LoadPackageEditors(D: TCustomIniFile);
var
  I: Integer;
  F: TStringList;
  P: TSdProject;
  Active: string;
begin
  Active := D.ReadString(PkgDeskSection, 'Active', '');
  F := TStringList.Create;
  try
    for I := 0 to D.ReadInteger(PkgDeskSection, 'Count', 0) - 1 do
    begin
      F.Text := StringReplace(D.ReadString(PkgDeskSection, 'Editor' + IntToStr(I), ''), '|', #13#10, [rfReplaceAll]);
      if (F.Count < 4) or not FileExistsU(F[3]) then Continue;
      P := FGroup.LoadedProjectOf(F[3]);
      if (P = nil) and (F[2] = '1') and (FGroup.IndexOf(F[3]) < 0) then
        OpenBeside(F[3], F[0], F[1] = '1', SameText(F[3], Active))
      else if P <> nil then
      begin
        PackageViewOf(P, True, F[0]);
        if F[1] = '1' then ShowPackageEditor(P);
      end;
    end;
  finally
    F.Free;
  end;
  { one open beside the group already }
  P := FGroup.Beside(FGroup.IndexOfBeside(Active));
  if P <> nil then SetActiveProject(P);
end;

{ the desktop file of the open group (Delphi's): <group>.dsk when the group has a file or more than
  one project - a group without a file is ProjectGroup1.dsk in its first project's folder -, else
  the lone project's <project>.dsk; '' without a project }
function TMainForm.DesktopFile: string;
begin
  Result := '';
  if FGroup.FileName <> '' then Result := ChangeFileExt(FGroup.FileName, '.dsk')
  else if FGroup.Count > 1 then Result := ExtractFilePath(FGroup.Projects[0]) + FGroup.Name + '.dsk'
  else if FGroup.Count = 1 then Result := ChangeFileExt(FGroup.Projects[0], '.dsk');
end;

{ the project the group's desktop makes the active one (Delphi's [ActiveProject] ActiveProject,
  1-based: 0 none); nil: no desktop, no such project }
function TMainForm.DesktopActiveProject: TSdProject;
var
  D: TMemIniFile;
  F: string;
begin
  Result := nil;
  F := DesktopFile;
  if (F = '') or not EnvOptions.AutosaveDesktop or not FileExists(F) then Exit;
  try
    D := TMemIniFile.Create(F);
  except
    Exit;
  end;
  try
    Result := FGroup.Project(D.ReadInteger('ActiveProject', 'ActiveProject', 0) - 1);
  finally
    D.Free;
  end;
end;

{ Environment Options | Preferences | Autosave options | Project desktop: the open files - of every
  project of the group -, the active one, the caret and the view of each, the active project, in
  the group's desktop file (DesktopFile; Delphi's sections), and the resources' pages; Desktop and
  symbols adds the watches }
procedure TMainForm.SaveDesktop;
var
  D: TMemIniFile;
  I, N, Place: Integer;
  P: TEditorPage;
  RP: TSdResPage;
  L: TStringList;
  V: string;

  { an untitled file and a file of an expert's file system cannot be opened again }
  function Reopens(Page: TEditorPage): Boolean;
  begin
    Result := not Page.Untitled and (Page.FileSystem = '');
  end;

begin
  if (FGroup.Count = 0) or not EnvOptions.AutosaveDesktop or (DesktopFile = '') then Exit;
  { a desktop file another program has locked: not saved (the project still closes) }
  try
    D := TMemIniFile.Create(DesktopFile);
  except
    Exit;
  end;
  L := TStringList.Create;
  try
    D.Clear;
    { the Project Manager's active project, 1-based (Delphi's SaveProjectManagerStates) }
    D.WriteInteger('ActiveProject', 'ActiveProject', FGroup.IndexOfProject(FProject) + 1);
    N := 0;
    { the files in the order of their tabs (FPages follows them), which Delphi's tabs take too }
    for I := 0 to FPages.Count - 1 do
    begin
      P := Pages[I];
      if not Reopens(P) then Continue;
      V := 'View' + IntToStr(N);
      D.WriteString('Modules', 'Module' + IntToStr(N), P.FileName);
      D.WriteString(V, 'Module', P.FileName);
      D.WriteInteger(V, 'CursorX', P.Editor.CaretCol + 1);
      D.WriteInteger(V, 'CursorY', P.Editor.CaretLine + 1);
      D.WriteBool(V, 'DesignView', P.DesignView);
      D.WriteInteger('EditWindow0', 'View' + IntToStr(N), N);
      if P = ActivePage then D.WriteInteger('EditWindow0', 'CurrentView', N);
      Inc(N);
    end;
    D.WriteInteger('Modules', 'Count', N);
    D.WriteInteger('EditWindow0', 'ViewCount', N);
    { the resources' pages: a section of D7 Studio's own (Delphi reads none of it) - per page
      hex|project file|key, and its place among the pages saved (Tab<n>: the files and these in
      the order of the tabs), so that it comes back between the files }
    N := 0;
    Place := 0;
    for I := 0 to FDocs.Count - 1 do
      if TObject(FDocs[I]) is TSdResPage then
      begin
        RP := TSdResPage(FDocs[I]);
        D.WriteString(ResDeskSection, 'Page' + IntToStr(N), Format('%d|%s|%s', [Ord(RP.EditorKind = reHex),
          RP.ProjectFile, RP.Key]));
        D.WriteInteger(ResDeskSection, 'Tab' + IntToStr(N), Place);
        if RP = ActiveDoc then D.WriteInteger(ResDeskSection, 'Current', N);
        Inc(N);
        Inc(Place);
      end
      else if Reopens(TEditorPage(FDocs[I])) then
        Inc(Place);
    if N > 0 then D.WriteInteger(ResDeskSection, 'Count', N);
    SavePackageEditors(D);
    if EnvOptions.DesktopSymbols then
    begin
      FDebug.GetWatches(L);
      D.WriteInteger('Watches', 'Count', L.Count);
      for I := 0 to L.Count - 1 do D.WriteString('Watches', 'Watch' + IntToStr(I), L[I]);
    end;
    try
      D.UpdateFile;
      OtaFileNotification(ofnProjectDesktopSave, D.FileName);
    except
    end;
  finally
    L.Free;
    D.Free;
  end;
end;

function TMainForm.LoadDesktop: Boolean;
var
  D: TMemIniFile;
  I, N, Cur, K, Base, Place: Integer;
  P: TEditorPage;
  RP: TSdResPage;
  Active: TWinControl;
  R: TSdResources;
  It: TSdResItem;
  Own, Hex: Boolean;
  L: TStringList;
  V, F: string;
begin
  Result := False;
  if (FGroup.Count = 0) or not EnvOptions.AutosaveDesktop or (DesktopFile = '') or
    not FileExists(DesktopFile) then Exit;
  { a desktop file that cannot be read (another program has it locked): the project opens as
    without one }
  try
    D := TMemIniFile.Create(DesktopFile);
  except
    Exit;
  end;
  OtaFileNotification(ofnProjectDesktopLoad, D.FileName);
  L := TStringList.Create;
  FReopenBatch := True;             // the files' Reopen entries: the menus once, at the end
  Inc(FNavLock);                    // the files of the last session are no jumps
  try
    N := D.ReadInteger('Modules', 'Count', 0);
    Cur := D.ReadInteger('EditWindow0', 'CurrentView', -1);
    Active := nil;
    Base := FDocs.Count;            // the desktop's pages come after these, in the order saved
    for I := 0 to N - 1 do
    begin
      V := 'View' + IntToStr(I);
      F := D.ReadString(V, 'Module', D.ReadString('Modules', 'Module' + IntToStr(I), ''));
      if (F = '') or not FileExistsU(F) then Continue;
      P := OpenFileView(F, D.ReadBool(V, 'DesignView', False), True);
      if P = nil then Continue;
      Result := True;
      { CursorX is the editor's column (SaveDesktop: CaretCol, tabs expanded), not a byte's }
      if P.CodeView then P.Editor.GotoLineCol(D.ReadInteger(V, 'CursorY', 1) - 1, D.ReadInteger(V, 'CursorX', 1) - 1);
      if I = Cur then Active := P;
    end;
    { the resources' pages (SaveDesktop): one whose resource is not there any more is not opened }
    N := D.ReadInteger(ResDeskSection, 'Count', 0);
    Cur := D.ReadInteger(ResDeskSection, 'Current', -1);
    for I := 0 to N - 1 do
    begin
      V := D.ReadString(ResDeskSection, 'Page' + IntToStr(I), '');
      K := Pos('|', V);
      Hex := Copy(V, 1, K - 1) = '1';
      V := Copy(V, K + 1, MaxInt);
      K := Pos('|', V);
      F := Copy(V, 1, K - 1);
      V := Copy(V, K + 1, MaxInt);
      if (K = 0) or not FileExistsU(F) then Continue;
      RP := nil;
      R := ResourcesOf(F, Own);
      try
        It := R.FindKey(V);
        if It <> nil then RP := OpenResPage(R, It, Hex);
      except
        RP := nil;
      end;
      if Own then R.Free;
      if RP = nil then Continue;
      Result := True;
      { back to its place between the files (a desktop of before has none: the page comes last) }
      Place := D.ReadInteger(ResDeskSection, 'Tab' + IntToStr(I), -1);
      if Place >= 0 then MoveDoc(RP, Base + Place);
      if I = Cur then Active := RP;
    end;
    if Active <> nil then ActivatePage(Active);
    LoadPackageEditors(D);
    if EnvOptions.DesktopSymbols and D.SectionExists('Watches') then
    begin
      for I := 0 to D.ReadInteger('Watches', 'Count', 0) - 1 do L.Add(D.ReadString('Watches', 'Watch' + IntToStr(I), ''));
      FDebug.SetWatches(L);
    end;
  finally
    Dec(FNavLock);
    L.Free;
    D.Free;
    FReopenBatch := False;
    if FReopenStale then UpdateReopenMenu;
  end;
end;

{ Delphi's Project Manager (SdProjectManager): the group (ProjectGroup1 until it has a file), its
  projects in their order and the packages beside it - the active one in bold - with their units
  (the other projects are read from their files for that); the package editors and the Resources
  view with it }
procedure TMainForm.RefreshProjectTree;
begin
  try
    FProjView.ShowGroup(FProject);
  finally
    RefreshPackageViews;
    if FResPanel.Showing then RefreshResourceView;
  end;
end;

{ File | Open Project with a .bpg: every project of it loaded (Delphi's TWorkspace) - one that is
  not there or cannot be read leaves the group with Delphi's message (the group is modified
  then), one an expert refuses stays in it closed. The experts are told of the group's file and
  of each project as of every file opened (they may refuse them). The group's desktop (<group>.dsk)
  opens its files and names the active project; without one no file opens and the last project
  loaded is the active one (Delphi's). }
procedure TMainForm.OpenProjectGroup(const FileName: string);
var
  I: Integer;
  P, Last: TSdProject;
  F, Why: string;
begin
  if not FileExistsU(FileName) or not OtaFileNotification(ofnFileOpening, FileName) or not ConfirmSaveGroup or
    not CloseGroup then
    Exit;
  ResetViews;
  FGroup.Load(FileName);
  AddRecent('RecentProjects', FileName);
  UpdateReopenMenu;
  OtaFileNotification(ofnFileOpened, FileName);
  Last := nil;
  I := 0;
  while I < FGroup.Count do
  begin
    F := FGroup.Projects[I];
    if not FileExistsU(F) then
    begin
      MessageBox(Handle, PChar(Format('Unable to locate project %s.  The project reference has been removed ' +
        'from the project group.', [F])), AppTitle, MB_OK or MB_ICONERROR);
      FGroup.Delete(I);
      Continue;
    end;
    if OtaFileNotification(ofnFileOpening, F) then
    begin
      P := LoadProjectFile(F, Why);
      if P = nil then
      begin
        MessageBox(Handle, PChar(Format('%s'#13#10#13#10'Unable to create project %s. This project will be ' +
          'removed from the project group.', [Why, F])), AppTitle, MB_OK or MB_ICONERROR);
        FGroup.Delete(I);
        Continue;
      end;
      FGroup.SetProject(I, P);
      ProjectJoined(F, P);
      Last := P;
    end;
    Inc(I);
  end;
  if Last = nil then
  begin
    RefreshProjectTree;
    Exit;
  end;
  { the active project: the group desktop's (Delphi's [ActiveProject]), else the last one loaded -
    Delphi activates each project as it joins the group; the files and the package editors: the
    desktop's only, and the active package's editor }
  P := DesktopActiveProject;
  if P = nil then P := Last;
  SetActiveProject(P);
  LoadDesktop;
  if P.IsPackage then ShowPackageEditor(P);
end;

{ a group of more than one project, or one saved before, that has changed: Delphi's question }
function TMainForm.ConfirmSaveGroup: Boolean;
begin
  Result := True;
  if not FGroup.Modified or ((FGroup.Projects.Count < 2) and (FGroup.FileName = '')) then Exit;
  case MessageBox(Handle, PChar(Format('Save changes to project group %s?', [FGroup.Name])), AppTitle,
    MB_YESNOCANCEL or MB_ICONQUESTION) of
    IDYES: Result := SaveGroup(FGroup.FileName = '');
    IDNO: FGroup.Modified := False;
  else
    Result := False;
  end;
end;

{ Save Project Group (As): the .bpg (asked for when AskName or when it has no file yet) }
function TMainForm.SaveGroup(AskName: Boolean): Boolean;
var
  F, OldKey: string;
begin
  F := FGroup.FileName;
  if AskName or (F = '') then
  begin
    if F = '' then
    begin
      F := 'ProjectGroup1.bpg';
      if FProject <> nil then F := FProject.Dir + F;
    end;
    Result := AskSaveName('Save Project Group As', 'Project groups (*.bpg)|*.bpg', 'bpg', F);
    if not Result then Exit;
  end;
  OldKey := OtaModules.GroupKey;
  FGroup.Save(F);
  { the group's Open Tools API module follows the new name, as Delphi's workspace (ModuleRenamed) }
  if not SameText(OldKey, OtaModules.GroupKey) then OtaModules.Renamed(OldKey, OtaModules.GroupKey);
  AddRecent('RecentProjects', F);
  UpdateReopenMenu;
  RefreshProjectTree;
  Result := True;
end;

{ another project of the group or a package beside it becomes the active one (Delphi's Activate, a
  double click on its node, IOTAProjectGroup.SetActiveProject): SetActiveProject - the files stay.
  A closed project is loaded again first (the experts are told of it as of a project opened). }
procedure TMainForm.ActivateProject(const FileName: string);
var
  P: TSdProject;
  Idx: Integer;
begin
  if (FProject <> nil) and SameText(FProject.FileName, FileName) then Exit;
  Idx := FGroup.IndexOf(FileName);
  if Idx < 0 then
  begin
    { a package beside the group }
    P := FGroup.Beside(FGroup.IndexOfBeside(FileName));
    if P <> nil then SetActiveProject(P);
    Exit;
  end;
  P := FGroup.Project(Idx);
  if P = nil then
  begin
    if CompileBusy then Exit;
    if not FileExistsU(FileName) then
    begin
      MessageBox(Handle, PChar('Project not found: ' + FileName), AppTitle, MB_OK or MB_ICONERROR);
      Exit;
    end;
    if not OtaFileNotification(ofnFileOpening, FileName) then Exit;
    P := LoadProjectOrSay(FileName);
    if P = nil then Exit;
    FGroup.SetProject(Idx, P);
    ProjectJoined(FileName, P);
  end;
  SetActiveProject(P);
end;

{ Project | Add Existing Project: a .dpr or .dpk into the group, active }
procedure TMainForm.AddExistingProject;
var
  F: string;
begin
  if AskProjectFile(False, F) then OpenProject(F, omAddToGroup);
end;

{ Project | Add New Project: Delphi's New Items, the project it makes joins the group }
procedure TMainForm.AddNewProject;
begin
  FNewProjectMode := omAddToGroup;
  try
    FileNewCommand.Execute;
  finally
    FNewProjectMode := omOpen;
  end;
end;

{ Remove Project (Delphi's TProjectManager.RemoveTarget, TWorkspace.RemoveTarget): the project
  leaves the group, its files stay on the disk. Ask: Delphi's question first (the Project
  Manager's; an expert's IOTAProjectGroup.RemoveProject is not asked). Refused while a compile
  runs and while its program is debugged. Its own pages close (ProjectOwnDocs) - unsaved ones are
  asked about once, as Delphi asks "Save changes to project X?" (No lets their changes go, Cancel
  keeps everything) -, the experts may keep it (ofnFileClosing); its breakpoints go into its
  section and leave the engine unless another project has their file, its Open Tools API module
  goes. The active project leaves: the group's first project becomes the active one (Delphi's
  ActivateNextTarget). }
{ Keep: the project stays loaded beside the group (ProjectUnbinds) }
procedure TMainForm.RemoveGroupProject(const FileName: string; Ask: Boolean; Keep: Boolean);
begin
  if Keep then ProjectUnbinds(FileName) else ProjectLeaves(FileName, True, Ask);
end;

{ Delphi 7's IOTAProjectGroup.RemoveProject (measured): out of the group, the project stays a module -
  owned by no module, as a project beside the group is -, its units' pages closed (each unsaved one
  asked about); its own source and its Open Tools API module stay (an expert's reference too), its
  CloseModule closes it. A closed project of the group just goes }
procedure TMainForm.ProjectUnbinds(const FileName: string);
var
  Idx, I: Integer;
  P, Next: TSdProject;
  Docs: TList;
  WasActive: Boolean;
begin
  Idx := FGroup.IndexOf(FileName);
  if Idx < 0 then Exit;
  P := FGroup.Project(Idx);
  if P = nil then
  begin
    ProjectLeaves(FileName, True, False);
    Exit;
  end;
  if CompileBusy then Exit;
  Docs := TList.Create;
  try
    ProjectOwnDocs(P, FileName, Docs);
    for I := Docs.Count - 1 downto 0 do
      if (TObject(Docs[I]) is TEditorPage) and SameText(TEditorPage(Docs[I]).FileName, FileName) then Docs.Delete(I);
    for I := 0 to Docs.Count - 1 do
      if not ConfirmSave(TWinControl(Docs[I])) then Exit;
    CloseProjectDocs(Docs);
  finally
    Docs.Free;
  end;
  WasActive := P = FProject;
  FGroup.ExtractProject(Idx);
  FGroup.AddBeside(P);
  if FGroup.Count = 0 then GroupEmptied;
  if WasActive then
  begin
    Next := FGroup.FirstLoaded;
    if Next <> nil then SetActiveProject(Next);
  end;
  RefreshProjectTree;
end;

{ IOTAModule.CloseModule of a project (Delphi's TCustomProject.HideOrClose): refused while its
  program is debugged; its own pages close (ProjectOwnDocs), each unsaved one asked about - a
  Cancel keeps everything -, the experts may keep it (ofnFileClosing); its breakpoints go into its
  section and leave the engine unless another project has their file, its Open Tools API module
  goes. It stays in the group closed (its node grey); Activate loads it again. A package beside the
  group goes (its package editor closed too). }
function TMainForm.CloseGroupProject(const FileName: string; Force: Boolean): Boolean;
begin
  Result := ProjectLeaves(FileName, False, False, Force);
end;

{ the two ways a project leaves (RemoveGroupProject, CloseGroupProject): Remove - out of the group,
  Delphi's question first when Ask, its unsaved pages asked about once; else closed in the group,
  each unsaved page asked about - a package beside the group closes so (Delphi's HideOrClose of a
  misc project) and goes; Force: no page asked about (Delphi 7's CloseModule(True): measured). Then
  the experts, its breakpoints, its pages (CloseProjectDocs) and ProjectGoes. Activate (always with
  Remove): the active project leaving, the group's first loaded one becomes active - the Project
  Manager's Remove and a closed package editor do so in Delphi 7, an expert's CloseModule does not.
  True: it went - closed: also when it was closed already }
function TMainForm.ProjectLeaves(const FileName: string; Remove, Ask, Force, Activate: Boolean): Boolean;
var
  Idx, I: Integer;
  P: TSdProject;
  Docs: TList;
  Unsaved: Boolean;
begin
  Result := False;
  if FileName = '' then Exit;
  Activate := Activate or Remove;
  Idx := FGroup.IndexOf(FileName);
  if Idx >= 0 then
    P := FGroup.Project(Idx)
  else
  begin
    P := FGroup.Beside(FGroup.IndexOfBeside(FileName));
    if P = nil then Exit;
    Remove := False;
  end;
  if not Remove and (P = nil) then
  begin
    Result := True;
    Exit;
  end;
  if CompileBusy then Exit;
  if (P <> nil) and (P = FDebugProject) and FDebug.Active then
  begin
    MessageBox(Handle, PChar(Format('Cannot close %s while it is running', [ExtractFileName(FileName)])), AppTitle,
      MB_OK or MB_ICONERROR);
    Exit;
  end;
  if Remove and Ask and (MessageBox(Handle, PChar(Format('Are you sure you want to remove %s from the project group?',
    [FGroup.Target(Idx)])), 'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES) then
    Exit;
  Docs := TList.Create;
  try
    ProjectOwnDocs(P, FileName, Docs);
    if Remove and not Force then
    begin
      Unsaved := False;
      for I := 0 to Docs.Count - 1 do
        if DocModified(TWinControl(Docs[I])) then Unsaved := True;
      if Unsaved then
        case MessageBox(Handle, PChar(Format('Save changes to project %s?', [ChangeFileExt(ExtractFileName(FileName), '')])),
          'Confirm', MB_YESNOCANCEL or MB_ICONQUESTION) of
          IDYES:
            for I := 0 to Docs.Count - 1 do
              if DocModified(TWinControl(Docs[I])) and not SaveDoc(TWinControl(Docs[I])) then Exit;
          IDNO: ;
        else
          Exit;
        end;
    end
    else if not Force then
      for I := 0 to Docs.Count - 1 do
        if not ConfirmSave(TWinControl(Docs[I])) then Exit;
    if not OtaFileNotification(ofnFileClosing, FileName) then Exit;
    if P <> nil then
    begin
      SaveProjectBreakpoints(P);
      DropProjectBreakpoints(P);
    end;
    CloseProjectDocs(Docs);
  finally
    Docs.Free;
  end;
  ProjectGoes(FileName, Remove, Activate);
  Result := True;
end;

{ a project goes (its pages and breakpoints taken care of): the views that show it let go, its Open
  Tools API module goes; a project of the group: Remove - out of the group, else it stays in it
  closed; a package beside the group: out of that list. The last project of the group went: as
  when the group closes, the files that were no project's stay open and so do the packages beside
  it. The active project gone with Activate: the group's first loaded project becomes the active
  one (Delphi's ActivateNextTarget), else the first package beside the group; without it none is
  active, as after Delphi 7's TCustomProject.HideOrClose of an expert's CloseModule }
procedure TMainForm.ProjectGoes(const FileName: string; Remove, Activate: Boolean);
var
  Idx, BesideIdx: Integer;
  P, Next: TSdProject;
  WasActive, WasCI: Boolean;
begin
  Idx := FGroup.IndexOf(FileName);
  BesideIdx := FGroup.IndexOfBeside(FileName);
  if Idx >= 0 then P := FGroup.Project(Idx)
  else if BesideIdx >= 0 then P := FGroup.Beside(BesideIdx)
  else Exit;
  ReleasePackageView(P);
  if (P <> nil) and (FResView.Project = P) then FResView.Fill(nil);
  OtaModules.ForgetProject(FileName);
  WasCI := (P <> nil) and (FCIProject = P);
  if WasCI then FCIProject := nil;
  WasActive := (P <> nil) and (P = FProject);
  if WasActive then
  begin
    FProject := nil;
    FGroup.Active := nil;
  end;
  { FileName may go with its entry }
  if Idx < 0 then FGroup.DeleteBeside(BesideIdx)
  else if Remove then FGroup.Delete(Idx)
  else FGroup.SetProject(Idx, nil);
  if (Idx >= 0) and (FGroup.Count = 0) then GroupEmptied
  { code insight worked for the project that went: for the page shown's now }
  else if WasCI then ConfigureCodeInsight;
  if WasActive and Activate then Next := FGroup.FirstLoaded else Next := nil;
  if Next <> nil then
    SetActiveProject(Next)
  else
  begin
    { none is active: the active project was closed, or no project is loaded any more }
    if WasActive then
    begin
      UpdateCaption;
      TodoProjectLater;
    end;
    RefreshProjectTree;
  end;
end;

{ Project | Compile / Build All Projects: each project of the group in its order (as the editor
  has its files); the first that fails ends it. A closed project is read for its compile. }
function TMainForm.CompileAllProjects(Build: Boolean): Boolean;
var
  I: Integer;
  P: TSdProject;
begin
  Result := True;
  for I := 0 to FGroup.Count - 1 do
  begin
    P := FGroup.Project(I);
    if P <> nil then
      Result := CompileProject(P, Build, False, False, False)
    else
    begin
      P := LoadProjectOrSay(FGroup.Projects[I]);
      if P = nil then
        Result := False
      else
        try
          Result := CompileProject(P, Build, False, False, False);
        finally
          P.Free;
        end;
    end;
    if not Result then Exit;
  end;
end;

{ a double click in the Project Manager }
procedure TMainForm.ProjViewOpen(Sender: TObject; Node: TTreeNode);
begin
  if FProjView.IsProjectNode(Node) then
  begin
    { a project - of the group or a package beside it: the active one's source, another one is
      activated (Delphi's): the view's Activate, its state made current first (the click may have
      changed the selection since the last idle) }
    if (FProject <> nil) and SameText(FProjView.SelectedProject, FProject.FileName) then OpenFile(FProject.FileName, True)
    else
    begin
      UpdateActionStates;
      FProjView.aActivateProject.Execute;
    end;
  end
  else if Node.Data <> nil then
    OpenProjectUnit(TProjectUnit(Node.Data));     // the group's node, Requires: nothing
end;

{ adds P's folder and the folders of its search path }
procedure TMainForm.ProjectDirsOf(P: TSdProject; Dirs: TStrings);
begin
  Dirs.Add(ExcludeTrailingPathDelimiter(P.Dir));
  AddPathList(Dirs, P.SearchPathList, P.Dir);
end;

{ where the sources of P's units are looked for (code insight, the debugger): P's folders
  (nil: none), Delphi's sources, Environment Options | Library's browsing path (sources) and
  library path }
procedure TMainForm.SearchDirsOf(P: TSdProject; Dirs: TStrings);
var
  Src: string;
begin
  if P <> nil then ProjectDirsOf(P, Dirs);
  Src := DelphiRoot + 'Source\';
  Dirs.Add(Src + 'Rtl\Sys');
  Dirs.Add(Src + 'Rtl\Win');
  Dirs.Add(Src + 'Rtl\Common');
  Dirs.Add(Src + 'Vcl');
  Dirs.Add(Src + 'Internet');
  Dirs.Add(Src + 'Xml');
  Dirs.Add(Src + 'Samples');
  Dirs.Add(Src + 'ToolsAPI');
  Dirs.Add(Src + 'Property Editors');
  Dirs.Add(Src + 'Extras\Jpeg');
  Dirs.Add(Src + 'Extras\ShellControls');
  AddPathList(Dirs, EnvOptions.BrowsingPath);
  AddPathList(Dirs, EnvOptions.LibraryPath);
end;

{ the project code insight works for (Delphi's kibitz compile, Pascodcmplt.DoKibitzCompile): the
  page shown's - the active project when the file is one of its, else the first project of the
  group whose file it is -, else the active project }
function TMainForm.CodeInsightProject: TSdProject;
var
  P: TEditorPage;
begin
  Result := FProject;
  P := ActivePage;
  if P = nil then Exit;
  if P.FormOwner <> nil then P := P.FormOwner;
  Result := FGroup.ProjectForFile(P.FileName);
end;

{ code insight's search path and unit list: those of CodeInsightProject (FCIProject) }
procedure TMainForm.ConfigureCodeInsight;
var
  I: Integer;
  P: TSdProject;
  Defines: string;
begin
  P := CodeInsightProject;
  FCIProject := P;
  { the project's conditional defines (Project | Options | Directories/Conditionals), as dcc32 gets
    them: the code they make active is the code that is read and checked (Error Insight). Set
    only when they change - a change makes code insight read every unit again }
  if P <> nil then Defines := P.Conditionals else Defines := '';
  if FCodeInsight.Defines.Text <> Defines then FCodeInsight.Defines.Text := Defines;
  { both lists tell code insight of each change (OnChange): once, at the end }
  FCodeInsight.SearchPath.BeginUpdate;
  FCodeInsight.UnitFiles.BeginUpdate;
  try
    FCodeInsight.SearchPath.Clear;
    FCodeInsight.UnitFiles.Clear;
    SearchDirsOf(P, FCodeInsight.SearchPath);
    if P <> nil then
      for I := 0 to P.UnitCount - 1 do
        FCodeInsight.UnitFiles.Add(P.Units[I].Name + '=' + P.Units[I].FileName);
  finally
    FCodeInsight.UnitFiles.EndUpdate;
    FCodeInsight.SearchPath.EndUpdate;
  end;
end;

function TMainForm.CIGetSource(const FileName: string; var Source: string): Boolean;
var
  P: TEditorPage;
begin
  { called on the UI thread only: the engine is never used from a worker here }
  P := FindPage(FileName);
  Result := P <> nil;
  if Result then Source := P.GetSource;
end;

{ the units of the components placed on an open page's form since its last save, which the save
  or a compile puts into its uses clause (TEditorPage.AddPlacedUnits): code insight counts them in
  its scope already - no Error Insight error for a placed component's class before the save }
procedure TMainForm.CIGetPendingUses(const FileName: string; Units: TStrings);
var
  P: TEditorPage;
begin
  P := FindPage(FileName);
  if P <> nil then P.PlacedUnitNames(Units);
end;

{ the first BaseN that is no unit of the project, no open page and no file in the project's
  folder - or in Dir, the folder of a project that does not exist yet (New Application, also
  while another project of the group is the active one) }
function TMainForm.UniqueUnitName(const Base: string; const Dir: string = ''; const Ext: string = '.pas'): string;
var
  I: Integer;
  D: string;
begin
  D := Dir;
  if (D = '') and (FProject <> nil) then D := FProject.Dir;
  I := 1;
  repeat
    Result := Base + IntToStr(I);
    Inc(I);
  until ((FProject = nil) or (FProject.FindUnitByName(Result) = nil)) and
    ((D = '') or not (FileExists(D + Result + Ext) or FileExists(D + Result + '.dfm'))) and
    (FindPage(Result + Ext) = nil);
end;

{ a form, data module or frame of the project has this name }
function TMainForm.RootNameUsed(const Name: string): Boolean;
var
  K: Integer;
begin
  Result := True;
  if FProject <> nil then
    for K := 0 to FProject.UnitCount - 1 do
      if SameText(FProject.Units[K].FormName, Name) then Exit;
  Result := False;
end;

function TMainForm.UniqueRootName(const Base: string): string;
var
  I: Integer;
begin
  I := 1;
  repeat
    Result := Base + IntToStr(I);
    Inc(I);
  until not RootNameUsed(Result);
end;

{ ---------------------------------------------------------------- build / run }

procedure TMainForm.AddMessage(const Text: string; Obj: TObject);
begin
  MessageList.Items.AddObject(Text, Obj);
  MessageList.TopIndex := MessageList.Items.Count - 1;
end;

{ Messages, Search Results and the debugger's views (BT_MESSAGES .. BT_TODO), wherever the
  user docked them; a view hidden at the dock's edge slides out unless Slide is False }
procedure TMainForm.ShowBottom(Index: Integer; Slide: Boolean);
begin
  if (Index >= Low(FBottomPanels)) and (Index <= High(FBottomPanels)) then ShowDockPanel(FBottomPanels[Index], Slide);
end;

procedure TMainForm.ClearErrorLine;
begin
  if FErrorPage <> nil then
  begin
    FErrorPage.Editor.MarkerDeleteAll(MK_ERROR_LINE);
    FErrorPage := nil;
  end;
end;

{ The line of the selected compiler message is shown in the "error line" colours. As in Delphi
  the mark lasts until the caret leaves the line or the line is edited. }
procedure TMainForm.MarkErrorLine(P: TEditorPage; Line: Integer);
begin
  ClearErrorLine;
  if Line < 1 then Exit;
  { "end of file found" is reported one line past the last one }
  if Line > P.Editor.LineCount then Line := P.Editor.LineCount;
  P.Editor.MarkerAdd(Line - 1, MK_ERROR_LINE);
  FErrorPage := P;
  FErrorText := P.Editor.GetLineText(Line - 1);
end;

procedure TMainForm.CheckErrorLine;
var
  L: Integer;
begin
  { called for every caret/text notification of the page - including the one caused by the
    jump to the line itself, which must not remove the mark }
  if FErrorPage = nil then Exit;
  L := FErrorPage.Editor.MarkerNext(0, 1 shl MK_ERROR_LINE);
  if (L < 0) or (FErrorPage.Editor.CaretLine <> L) or (FErrorPage.Editor.GetLineText(L) <> FErrorText) then
    ClearErrorLine;
end;

procedure TMainForm.MessagesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { Enter on a message goes to its line, like a double-click (of an expert's group: its own) }
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    if (Sender is TListBox) and Assigned(TListBox(Sender).OnDblClick) then TListBox(Sender).OnDblClick(Sender);
    Key := 0;
  end;
end;

{ a file at a line in the code view, the editor focused (messages, search results, code insight
  jumps, the debugger); nil when the file cannot be opened }
function TMainForm.ShowFileLine(const FileName: string; Line, Col: Integer): TEditorPage;
begin
  NavMark;
  Result := OpenFile(FileName, True);
  if Result <> nil then ShowPageLine(Result, Line, Col);
end;

{ ... a page's line in its code view, the editor focused }
procedure TMainForm.ShowPageLine(P: TEditorPage; Line, Col: Integer);
begin
  P.ShowDesign(False);
  P.GotoLine(Line, Col);
  if P.Editor.CanFocus then P.Editor.SetFocus;
end;

{ --- the browse history: Back and Forward at the end of the file tabs (SdNavHistory). A jump is another
  file shown, or a line gone to for the user (code
  browsing, Messages, Search Results, the Code Explorer, Go to Line Number ...); Back returns to
  where it started. }

{ where Page's caret is, in the view the page shows }
function TMainForm.PagePlace(Page: TEditorPage): TSdNavPlace;
begin
  Result.FileName := Page.FileName;
  Result.Line := Page.Editor.CaretLine + 1;
  Result.Col := Page.Editor.CaretCol + 1;
  Result.Design := Page.DesignView;
end;

{ a jump begins: the caret of the page shown last is the place it starts from. It is recorded
  when it is over - the commands it is made of (open a file, show it, go to a line) have run -
  with where the caret is then (WM_SDNAVRECORD) }
procedure TMainForm.NavMark;
begin
  if (FNavLock > 0) or FNavPending or FClosing or (FNavPage = nil) then Exit;
  FNavFrom := PagePlace(FNavPage);
  FNavPending := True;
  PostMessage(Handle, WM_SDNAVRECORD, 0, 0);
end;

procedure TMainForm.WMNavRecord(var Message: TMessage);
begin
  if not FNavPending then Exit;
  FNavPending := False;
  if not FClosing and (ActivePage <> nil) then FHistory.Jumped(FNavFrom, PagePlace(ActivePage));
end;

{ place Index of the history, shown as it was left: the form, or the code at its caret. A file
  that is neither open nor on the disk any more loses its place. }
function TMainForm.ShowPlace(Index: Integer): Boolean;
var
  Place: TSdNavPlace;
  P: TEditorPage;
  Design: Boolean;
begin
  Result := False;
  if (Index < 0) or (Index >= FHistory.Count) then Exit;
  Place := FHistory[Index];
  Inc(FNavLock);
  try
    P := FindPage(Place.FileName);
    if (P = nil) and FileExistsU(Place.FileName) then P := OpenFile(Place.FileName, False);
    if P = nil then
    begin
      FHistory.Delete(Index);
      MessageBeep(MB_ICONASTERISK);
      Exit;
    end;
    { the view while the page may still be hidden (shown in the other one first, it would
      flash), as OpenFileView does }
    Design := Place.Design and P.HasForm;
    if Design <> P.DesignView then P.ShowDesign(Design, False)
    else if not Design and not P.CodeView then P.ShowDesign(False, False);   // the Diagram tab
    ActivatePage(P);
    if Design then
      P.ShowDesign(True)                          // the designer takes the focus
    else
    begin
      P.Editor.GotoLineCol(Place.Line - 1, Place.Col - 1);
      if P.Editor.CanFocus then P.Editor.SetFocus;
    end;
    FHistory.Index := Index;
    Result := True;
  finally
    Dec(FNavLock);
  end;
end;

{ Back, Forward (Delphi 7's Alt+Left, Alt+Right). A place where the caret is already would show
  nothing (its file was closed and the page before it shown instead): the one after it. }
procedure TMainForm.ActBrowse(Sender: TObject);
var
  I, Step: Integer;
  Here: TSdNavPlace;
begin
  if Sender = aBrowseBack then Step := -1 else Step := 1;
  I := FHistory.Index + Step;
  if ActivePage <> nil then
  begin
    Here := PagePlace(ActivePage);
    while (I >= 0) and (I < FHistory.Count) and SamePlace(FHistory[I], Here) do Inc(I, Step);
  end;
  ShowPlace(I);
end;

{ the drop-down menus of Back and Forward: the places before the one shown, the nearest first,
  and those after it - an action each (HistoryActions: one menu is open at a time), named as
  Delphi names them (the file and the line) }
procedure TMainForm.BrowseMenuPopup(Sender: TObject);
var
  Menu: TPopupMenu;
  I: Integer;

  procedure Add(Index: Integer);
  begin
    NewActionItem(Menu.Items, NewAction(HistoryActions, NoAccel(FHistory.Caption(Index)),
      FHistory[Index].FileName, Index, HistoryExecute));
  end;

begin
  Menu := Sender as TPopupMenu;
  Menu.Items.Clear;
  ClearActions(HistoryActions);
  if Menu = BackMenu then
    for I := FHistory.Index - 1 downto 0 do Add(I)
  else
    for I := FHistory.Index + 1 to FHistory.Count - 1 do Add(I);
end;

procedure TMainForm.HistoryExecute(Sender: TObject);
begin
  ShowPlace(TAction(Sender).Tag);
end;

type
  TToolBarAccess = class(TToolBar);     // CheckMenuDropdown

{ the drop-down at the end of the file tabs' row, the open files as a list to choose from: the
  button drops the list as its arrow
  does - the VCL's own drop-down, the button pressed while the list is open }
procedure TMainForm.ActFileList(Sender: TObject);
begin
  TToolBarAccess(FilesBar).CheckMenuDropdown(tbFileList);
end;

procedure TMainForm.FilesMenuPopup(Sender: TObject);
begin
  UpdatePageItems(FilesMenu.Items, EditorOptions.SortPagesMenu);
end;

{ a message's place: its line (and an expert's message's column); an expert's message with a file
  but no line opens the file }
procedure TMainForm.MessagesDblClick(Sender: TObject);
var
  M: TCompilerMessage;
  P: TEditorPage;
begin
  if MessageList.ItemIndex < 0 then Exit;
  M := TCompilerMessage(MessageList.Items.Objects[MessageList.ItemIndex]);
  if (M = nil) or (M.FileName = '') then Exit;
  if M.Line <= 0 then
  begin
    if FileExistsU(M.FileName) then ShowFileLine(M.FileName, 1, 1);
    Exit;
  end;
  if M.Column > 0 then P := ShowFileLine(M.FileName, M.Line, M.Column) else P := ShowFileLine(M.FileName, M.Line, 1);
  if P <> nil then MarkErrorLine(P, M.Line);
end;

{ the compiler's next (Delta 1) or previous (-1) message that names a place, from the one selected:
  selected and shown in its file (the Open Tools API's NextError / PriorError); False: none }
function TMainForm.StepMessage(Delta: Integer): Boolean;
var
  I: Integer;
  O: TObject;
begin
  Result := False;
  I := MessageList.ItemIndex;
  repeat
    Inc(I, Delta);
    if (I < 0) or (I >= MessageList.Items.Count) then Exit;
    O := MessageList.Items.Objects[I];
  until (O is TCompilerMessage) and (TCompilerMessage(O).FileName <> '') and (TCompilerMessage(O).Line > 0);
  MessageList.ItemIndex := I;
  MessagesDblClick(MessageList);
  Result := True;
end;

{ a file that dcc32 reads when it compiles the project: the project source, its units and the
  units in the folders where it looks for them }
function TMainForm.CompilerReads(P: TSdProject; const FileName: string): Boolean;
var
  Dirs: TStringList;
begin
  Result := False;
  if not IsAbsolutePath(FileName) then Exit;      // untitled, marked name (SdFileNames)
  if SameText(FileName, P.FileName) or (P.FindUnit(FileName) <> nil) then
  begin
    Result := True;
    Exit;
  end;
  if not SameText(ExtractFileExt(FileName), '.pas') then Exit;
  Dirs := TStringList.Create;
  try
    ProjectDirsOf(P, Dirs);
    Result := Dirs.IndexOf(ExcludeTrailingPathDelimiter(ExtractFilePath(FileName))) >= 0;
  finally
    Dirs.Free;
  end;
end;

{ the form the UTF-8 compiler is given for a unit (Dfm: its text from the designer, '' = the .dfm
  file beside the unit): a text form with text beyond ASCII as a binary one whose strings beyond
  ASCII are WideStrings (DfmTextToBinary) - the UTF-8 compiler would make a byte of a code page
  U+FFFD, and write the strings as UTF-8 bytes, which only a program in UTF-8 reads right. A form
  text that is not UTF-8 is in the system code page (SystemFileToIde). '' = nothing to give: no
  form, a binary one, one of ASCII only, or one that cannot be read (the compiler reports it) }
function Utf8CompilerForm(const UnitFile, Dfm: string): string;
var
  S, F: string;
begin
  Result := '';
  try
    S := Dfm;
    if S = '' then
    begin
      F := ChangeFileExt(UnitFile, '.dfm');
      if not FileExistsU(F) then Exit;
      S := ReadFileU(F);
    end;
    if not DfmIsBinary(S) and DfmBeyondAscii(S) then Result := DfmTextToBinary(SystemFileToIde(S));
  except
    Result := '';
  end;
end;

{ Delphi compiles the text of the editor and saves nothing: unsaved files go to the scratch
  build (TSdScratchBuild) - of any project, the active one or another of the group, or a package
  Install Component fills (a page of a unit of two projects goes into each one's compile); the
  project's .res with its unsaved resource pages; so do the sources of the project in a Unicode
  encoding, in the system code page (CodePageSource: Delphi 7 compiles code-page text only; a
  file with a character the code page lacks stays UTF-8, and its line is a line of Warnings).
  Linker | EXE Description is a directive of the compiled copy of the project source, too. Utf8:
  the program runs with UTF-8 as its code page - every source goes to dcc32 in UTF-8.
  Utf8Compiler: the UTF-8 compiler compiles it (Dcc32Utf8Exe) - a unit whose text form has text
  beyond ASCII goes to the scratch build with its form as a binary copy (Utf8CompilerForm), and
  so do the units of the search path in a code page, as UTF-8 copies (OtherSourceUnits).
  The include files of these sources go as they are: one in another encoding is a line of
  Warnings (TSdIncludeCheck). HighText: a Win32 program in UTF-8 that dcc32 compiles has a string
  literal beyond ASCII, in a source or an include file (dcc32 turns such text into UTF-16 wrong).
  The result is the project file to compile. }
function TMainForm.CompileTarget(P: TSdProject; Warnings: TStrings; Utf8, Utf8Compiler: Boolean;
  out HighText: Boolean): string;
var
  I: Integer;
  Page: TEditorPage;
  Copied, Check: Boolean;
  Src, Desc, Bytes, Res: string;
  E: TSdEncoding;
  Done, Others: TStringList;
  Includes: TSdIncludeCheck;

  { a unit into the scratch build when its text is not as the compiler must read it
    (CodePageSource), when its page is modified, or when it has a form the UTF-8 compiler must get
    as a copy. Page: the unit's page - its text, and its form as the designer has it when it is
    modified -, else nil: the files }
  procedure AddUnit(const FileName: string; Page: TEditorPage);
  var
    Code, Dfm, Form, Bytes: string;
    E: TSdEncoding;
    Modified: Boolean;
  begin
    Dfm := '';                       // the form on the disk
    Modified := (Page <> nil) and Page.Modified;
    if Page = nil then
      Code := ReadSourceFile(FileName, E)
    else
    begin
      Code := Page.GetSource;
      E := Page.Encoding;
      if Modified then Dfm := Page.CurrentDfm;
    end;
    if Check and not HighText then HighText := HasHighLiteral(Code);
    Includes.Check(FileName, Code, E);
    Form := '';
    if Utf8Compiler then Form := Utf8CompilerForm(FileName, Dfm);
    if Form <> '' then Dfm := Form;
    if not CodePageSource(FileName, Code, E, Warnings, Bytes, Utf8) then
      if not Modified and (Form = '') then Exit
      else if Page <> nil then Bytes := Page.Editor.FileBytes
      else Bytes := ReadFileU(FileName);
    FScratch.AddUnit(FileName, Bytes, Dfm);
    Copied := True;
  end;

begin
  HighText := False;
  Check := Utf8 and not Utf8Compiler and (P.Platform = spWin32);
  FScratch.Utf8Compiler := Utf8Compiler;
  { a name dcc32 takes (it reads the system code page): the short name when needed }
  Result := ExtractFileName(CompilerPath(P.FileName));
  Copied := False;
  Includes := TSdIncludeCheck.Create(P, Utf8, Warnings);
  Done := TStringList.Create;      // the units taken from the editor
  try
    Includes.FindHighLiterals := Check;
    Done.Sorted := True;
    for I := 0 to FPages.Count - 1 do Pages[I].RemoveEmptyHandlers;
    for I := 0 to FPages.Count - 1 do
    begin
      Page := Pages[I];
      if not CompilerReads(P, Page.FileName) then Continue;
      if SameText(Page.FileName, P.FileName) then
        Copied := Copied or Page.Modified
      else
      begin
        Done.Add(Page.FileName);
        AddUnit(Page.FileName, Page);
      end;
    end;
    for I := 0 to P.UnitCount - 1 do
      if (Done.IndexOf(P.Units[I].FileName) < 0) and FileExistsU(P.Units[I].FileName) then
        AddUnit(P.Units[I].FileName, nil);
    { the UTF-8 compiler reads every source as UTF-8: the units the program takes from its folder
      and the search path go to it as UTF-8 copies too, when they are in a code page (dcc32 read
      their text in the system code page) }
    if Utf8Compiler then
    begin
      Others := TStringList.Create;
      try
        P.OtherSourceUnits(SourceOf, Others);
        for I := 0 to Others.Count - 1 do
          if Done.IndexOf(Others[I]) < 0 then AddUnit(Others[I], nil);
      finally
        Others.Free;
      end;
    end;
    Src := SourceAndEncoding(P.FileName, E);
    if Check and not HighText then HighText := HasHighLiteral(Src);
    Includes.Check(P.FileName, Src, E);
    HighText := HighText or Includes.HighLiterals;
  finally
    Done.Free;
    Includes.Free;
  end;
  if CodePageSource(P.FileName, Src, E, Warnings, Bytes, Utf8) then
  begin
    Src := Bytes;
    Copied := True;
  end;
  Desc := P.OptStr('Linker', 'ExeDescription', '');
  if (Desc <> '') and not P.IsPackage then
  begin
    DprAddDirective(Src, '{$DESCRIPTION ''' + StringReplace(Desc, '''', '''''', [rfReplaceAll]) + '''}');
    Copied := True;
  end;
  { the project's resources with their unsaved pages (SdResPage): its .res beside the copy of the
    project source, where dcc32 looks for its $R *.res first }
  Res := UnsavedResources(P.FileName, Warnings);
  if Res <> '' then
  begin
    FScratch.AddFile(ChangeFileExt(P.FileName, '.res'), Res);
    Copied := True;
  end;
  if Copied then Result := CompilerPath(FScratch.Prepare(P, Src));
end;

function TMainForm.UnsavedFileBytes(const FileName: string; out Bytes: string): Boolean;
var
  Page: TEditorPage;
begin
  Page := FindPage(FileName);
  Result := (Page <> nil) and Page.Modified;
  if Result then Bytes := Page.Editor.FileBytes else Bytes := '';
end;

{ a compile is running (without the "Compiling" dialog its messages are pumped, and commands
  can arrive meanwhile): what would free or replace the project it uses is refused - the
  user is told why }
function TMainForm.CompileBusy: Boolean;
begin
  Result := FCompiler.Running;
  if Result then
    MessageBox(Handle, 'The project is being compiled: wait until the compile has ended.', AppTitle,
      MB_OK or MB_ICONINFORMATION);
end;

{ Compile, Build, Syntax Check of the open project }
function TMainForm.DoCompile(Build, ForDebug, SyntaxOnly: Boolean; ForRun: Boolean): Boolean;
begin
  Result := CompileProject(FProject, Build, ForDebug, SyntaxOnly, ForRun);
end;

function TMainForm.CompileProject(P: TSdProject; Build, ForDebug, SyntaxOnly: Boolean; ForRun: Boolean): Boolean;
var
  Cancelled: Boolean;
begin
  Result := False;
  if (P = nil) or FCompiler.Running then Exit;
  Result := CompileNow(P, Build, ForDebug, SyntaxOnly, ForRun, Cancelled);
  if not Cancelled then OtaAfterCompile(Result);
end;

{ compiles a project of the group as the editor has its files (CompileTarget). Cancelled: the
  experts were not told of a compile - it could not start, or an expert's BeforeCompile stopped
  it - and get no AfterCompile }
function TMainForm.CompileNow(P: TSdProject; Build, ForDebug, SyntaxOnly, ForRun: Boolean;
  out Cancelled: Boolean): Boolean;
const
  { the units that link a manifest of their own (the first one found counts), and what it declares
    besides as invoker }
  ManifestUnits: array[0..2] of string = ('ModernManUtf8', 'ModernMan', 'XPMan');
  ManifestUnitDpi: array[0..2] of TSdDpiAwareness = (daPerMonitorV2, daPerMonitorV2, daUnaware);
  ManifestUnitUtf8: array[0..2] of Boolean = (True, False, False);
var
  Args, ResNote, DpiNote, TargetNote, CfgNote, VerNote, UnitDir, Dcc, Utf8Exe, Dir, Err: string;
  I, FirstErr: Integer;
  Hinted: TList;
  M: TCompilerMessage;
  Utf8, Utf8Dcc, HighText: Boolean;
  Missing, ProjSrc, Data, Whose: string;
  Dpi, OwnDpi: TSdDpiAwareness;
  Level, OwnLevel: TSdExecutionLevel;
  Themes, OwnUtf8, HasOwn: Boolean;
  Win64: Boolean;
  Reload: TPackageEntry;
  Notes: TStringList;
  ResOk: Boolean;
  U: TProjectUnit;

  { the compile cannot start: why, in Messages and the status bar }
  procedure Refuse(const Why, Status: string);
  begin
    ClearBuildMessages;
    AddMessage('[Fatal Error] ' + Why, nil);
    ShowBottom(BT_MESSAGES);
    StatusBar.Panels[spMessage].Text := 'Compile failed: ' + Status;
  end;

begin
  Result := False;
  Cancelled := True;
  if (P = nil) or FCompiler.Running then Exit;
  { an edit of the Code Explorer's New or Rename ends unchanged (Delphi's BeforeCompile) }
  FCodeExp.CancelEdit;
  ClearErrorLine;
  { the units of the components placed on the forms go into their uses clauses, as Delphi's designer
    puts them there for a compile }
  for I := 0 to FPages.Count - 1 do Pages[I].AddPlacedUnits;
  { Win64: the dcc64 of RAD Studio }
  Win64 := P.Platform = spWin64;
  if Win64 then Dcc := Dcc64Exe else Dcc := DelphiBin + 'dcc32.exe';
  if Dcc = '' then
  begin
    Refuse('The target platform is Win64, and no RAD Studio with dcc64.exe (Delphi XE2 or later) is ' +
      'installed (Project | Options | Compiler | Target platform).', 'no 64-bit compiler.');
    Exit;
  end;
  { an installed package is loaded in D7 Studio, and Windows keeps a loaded .bpl from being
    written: it is taken out for the compile and loaded again afterwards }
  Reload := nil;
  if not SyntaxOnly then Reload := InstalledPackage(P);
  if (Reload <> nil) and not Reload.Loaded then Reload := nil;
  { Environment Options | Preferences | Warn on package rebuild }
  if (Reload <> nil) and EnvOptions.WarnPackageRebuild and
    (MessageBox(Handle, PChar(Format('The installed package %s will be rebuilt. Continue?',
      [ExtractFileName(Reload.FileName)])), 'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES) then Exit;
  { Preferences | Autosave options | Editor files: the modified files are saved first (whichever
    project of the group is compiled) }
  if EnvOptions.AutosaveEditor and not SyntaxOnly then SaveAllPages;
  if (Reload <> nil) and not DesignHost.EnablePackage(Reload, False, Err) then
  begin
    Refuse(Err, 'the package is in use.');
    Exit;
  end;
  { from here on the package is loaded again whatever happens (a .res that cannot be written) }
  UnitDir := '';
  Notes := TStringList.Create;
  try
    P.MakeOutputDirs;
    { the resources changed through the Open Tools API are written before D7 Studio changes the
      .res below: its model of the file reads it again afterwards, with nothing of its own lost }
    OtaFlushResources;
    { the icon and the manifest: the visual styles, the DPI awareness, the UTF-8 code page and the
      execution level of a program. A program has one manifest: its own - the manifest of the
      ModernManUtf8, ModernMan or XPMan it uses (in the editor's text, saved or not), else one D7
      Studio did not write in a .res its source links - or D7 Studio's, in the .res of $R *.res. With
      its own, D7 Studio writes none (it takes its own out): what the options ask for that the own
      one does not declare is said. Utf8: the program runs in UTF-8 - its manifest says so -, and its
      sources go to dcc32 in UTF-8 (CompileTarget); else in the system code page it runs in. }
    P.ManifestOptions(Themes, Dpi, Utf8, Level);
    ProjSrc := SourceOf(P.FileName);
    HasOwn := False;
    if not P.IsLibrary and not P.IsPackage then
    begin
      I := P.FirstUsedUnit(ManifestUnits, SourceOf);
      if I >= 0 then
      begin
        HasOwn := True;
        OwnDpi := ManifestUnitDpi[I];
        OwnUtf8 := ManifestUnitUtf8[I];
        OwnLevel := elAsInvoker;
        Whose := Format('the program uses %s, whose manifest', [ManifestUnits[I]]);
      end
      else if P.LinkedManifest(ProjSrc, SourceEncoding(P.FileName), Data) then
      begin
        HasOwn := True;
        ManifestDeclares(Data, OwnDpi, OwnUtf8, OwnLevel);
        Whose := 'the program''s own manifest';
      end;
    end;
    DpiNote := '';
    TargetNote := '';
    if HasOwn then
    begin
      Missing := ManifestMisses(Dpi, Utf8, Level, OwnDpi, OwnUtf8, OwnLevel);
      if Missing <> '' then
        DpiNote := Format('[Warning] %s: %s is linked - %s is not applied', [ExtractFileName(P.FileName), Whose,
          Missing]);
      { a manifest of UTF-8 whatever Target Windows says: the sources go to dcc32 in UTF-8, and Windows
        before 10 1903 ignores the manifest's code page and shows the program's literals beyond ASCII
        garbled }
      if OwnUtf8 and (P.Platform = spWin32) and (P.TargetWindows <> twWindows10Utf8) then
        TargetNote := Format('[Warning] %s: %s asks for UTF-8 whatever Target Windows (%s) says - on Windows ' +
          'before 10 1903 its text beyond ASCII in code shows garbled', [ExtractFileName(P.FileName), Whose,
          TargetWindowsTexts[P.TargetWindows]]);
      Utf8 := OwnUtf8;
      Dpi := daUnaware;
      Level := elAsInvoker;
    end
    else if not LinksProjectRes(ProjSrc) then
    begin
      { no $R *.res, no manifest of its own: the program has none, and runs in the system code page }
      if ManifestAsked(Themes, Dpi, Utf8, Level) then
      begin
        if Utf8 then Missing := ManifestUnits[0] else Missing := ManifestUnits[1];
        DpiNote := Format('[Warning] %s: the project source does not link its resource file with {$R *.res}, ' +
          'so the program gets no manifest - %s is not applied: add {$R *.res} to the project source, or %s ' +
          'to its uses clause', [ExtractFileName(P.FileName), ManifestSummary(Themes, Dpi, Utf8, Level), Missing]);
      end;
      Utf8 := False;
    end;
    EnsureProjectRes(P.FileName, ProjSrc, Themes and not HasOwn, Dpi, Utf8 and not HasOwn, Level, ResNote);
    { a Win32 program in UTF-8 goes to the UTF-8 compiler when Delphi 7's Bin has it: dcc32 would
      turn its UTF-8 text into UTF-16 (resource strings, WideString literals) with the system code
      page }
    if Utf8 and not Win64 then Utf8Exe := Dcc32Utf8Exe else Utf8Exe := '';
    Utf8Dcc := Utf8Exe <> '';
    if Utf8Dcc then Dcc := Utf8Exe;
    { a .cfg that cannot be written (read-only, locked): the compile goes on with the one there,
      and Messages says so. It is in the code page of the compiler that reads it }
    CfgNote := '';
    try
      P.WriteCfg('', '', Utf8Dcc);
    except
      on E: Exception do
        CfgNote := Format('[Warning] %s: the compiler reads the options it had before (%s)',
          [ExtractFileName(ChangeFileExt(P.FileName, '.cfg')), E.Message]);
    end;
    { Version Info: the version resource of the .res (the build number first goes up) - after
      the .res exists, also the one the first compile creates }
    if not SyntaxOnly then UpdateVersionInfo(P, True);
    { the experts' IOTAIDENotifier.BeforeCompile, as in Delphi: they see the resources as they
      are compiled, and what they change there (the version information) is written before the
      compiler runs. One that cancels ends the compile; the package taken out is loaded again
      (finally). The Build messages of the last compile go first: what the experts write there stays }
    ClearBuildMessages;
    if not OtaBeforeCompile(P.FileName) then
    begin
      StatusBar.Panels[spMessage].Text := 'Compile cancelled.';
      Exit;
    end;
    Cancelled := False;
    { the version resource as the experts left it is what Project Options' Version Info shows }
    VerNote := '';
    if not SyntaxOnly then
      try
        VersionInfoFromRes(P);
      except
        on E: Exception do
          VerNote := Format('[Warning] %s: the version information of the .res is not in the options (%s)',
            [ExtractFileName(ChangeFileExt(P.FileName, '.dof')), E.Message]);
      end;
    if FResPanel.Showing then RefreshResourceView;
    if CfgNote <> '' then AddMessage(CfgNote, nil);
    if ResNote <> '' then AddMessage(ResNote, nil);
    if DpiNote <> '' then AddMessage(DpiNote, nil);
    if TargetNote <> '' then AddMessage(TargetNote, nil);
    if VerNote <> '' then AddMessage(VerNote, nil);
    { quiet unless the "Compiling" dialog wants the position reports }
    if EnvOptions.ShowCompilerProgress then Args := '' else Args := '-Q';
    if Build then Args := Args + ' -B';
    if ForDebug then Args := Args + ' -V -$D+ -$L+';
    if SyntaxOnly then
    begin
      { no program: the units become C++ objects in the settings folder (no backslash before the
        closing quote: dcc64 reads \" as a quote that belongs to the argument) }
      UnitDir := SettingsDir;
      if Win64 then
      begin
        UnitDir := UnitDir + PlatformNames[spWin64] + '\';     // the units of the two compilers apart
        ForceDirectories(UnitDir);
      end;
      Dir := '"' + CompilerPath(ExcludeTrailingPathDelimiter(UnitDir)) + '"';
      if Win64 then
        Args := Args + ' -JPHNE -NU' + Dir + ' -NO' + Dir + ' -NH' + Dir
      else
        Args := Args + ' -JPHNE -N' + Dir;
    end
    else
      UnitDir := P.UnitOutputDir;
    StatusBar.Panels[spMessage].Text := 'Compiling ' + ExtractFileName(P.FileName) + '...';
    StatusBar.Update;
    { the project's resource scripts ($R 'x.res' 'x.rc'): Delphi 7's brcc32 compiles the ones whose
      .res is out of date - every one for a Build - before the compiler links them.
      Their messages come first; an error stops the compile, with them in Messages }
    ResOk := True;
    if not SyntaxOnly and (P.ResScriptCount > 0) then
    begin
      Screen.Cursor := crHourGlass;
      try
        ResOk := CompileResScripts(P, DelphiBin + 'brcc32.exe', Build, Notes, UnsavedFileBytes);
      finally
        Screen.Cursor := crDefault;
      end;
    end;
    if not ResOk then
      Result := FCompiler.Fail(Notes, FolderArg(P.Dir))
    else
    begin
      Args := Trim(Args + ' "' + CompileTarget(P, Notes, Utf8, Utf8Dcc, HighText) + '"');
      if HighText then
        AddMessage(Format('[Warning] %s: Delphi 7''s Bin has no dcc32u8.exe, the UTF-8 compiler D7 Studio''s ' +
          'Setup puts there - text beyond ASCII in resource strings and WideString literals comes out garbled',
          [ExtractFileName(P.FileName)]), nil);
      { what the sources dcc32 is given hold that it cannot take: its first messages }
      FCompiler.Note(Notes);
      if EnvOptions.ShowCompilerProgress then
        { Delphi's "Compiling" dialog; before a run, and after any compile with Auto close on
          successful compile, it closes by itself when all went well }
        Result := CompileWithProgress(Self, FCompiler, P.FileName, Dcc, Args,
          FolderArg(P.Dir), P.SearchPathList, ForDebug or ForRun or EnvOptions.AutoCloseCompilerProgress)
      else
      begin
        Screen.Cursor := crHourGlass;
        try
          Result := FCompiler.Run(Dcc, Args, FolderArg(P.Dir), P.SearchPathList);
        finally
          Screen.Cursor := crDefault;
        end;
      end;
    end;
    for I := 0 to FCompiler.MessageCount - 1 do
    begin
      M := FCompiler.Messages[I];
      M.FileName := FScratch.RealNames(M.FileName);
      M.Text := FScratch.RealNames(M.Text);
      { a path beyond ASCII comes back in another code page - dcc32 writes the OEM one, the UTF-8
        compiler a best-fit ASCII one: the project's unit of that file name }
      if (M.FileName <> '') and not FileExistsU(M.FileName) then
      begin
        U := P.FindUnitByName(ChangeFileExt(ExtractFileName(M.FileName), ''));
        if (U <> nil) and SameText(ExtractFileName(U.FileName), ExtractFileName(M.FileName)) then
          M.FileName := U.FileName;
      end;
    end;
  finally
    Notes.Free;
    FScratch.Finish(UnitDir);
    if (Reload <> nil) and not DesignHost.EnablePackage(Reload, True, Err) then
      AddMessage(Format('[Error] %s could not be loaded again: %s', [ExtractFileName(Reload.FileName), Err]), nil);
  end;
  { the program's header as for Windows Vista and later (Project | Options | Linker | Modern
    program header), or with version 5.1 for one whose Target Windows is Windows XP (Project |
    Options | Application) - before MoveDebugInfo, which names the debug information after the
    program's final bytes }
  if Result and not SyntaxOnly and P.ModernHeader then
    if P.WindowsXP then ModernizeProgramHeader(P.ExeName, 5, 1)
    else ModernizeProgramHeader(P.ExeName);
  { Run's TD32 information goes into D7 Studio's Debug folder, not into the program, unless the
    project asks for it there (Linker | Include TD32 debug info) }
  if Result and ForDebug and not SyntaxOnly and (P.OptInt('Linker', 'DebugInfo', 0) = 0) then
    MoveDebugInfo(P.ExeName);
  if FCompiler.Cancelled then
  begin
    StatusBar.Panels[spMessage].Text := 'Compile cancelled.';
    Exit;
  end;
  FirstErr := -1;
  Hinted := TList.Create;
  try
    MessageList.Items.BeginUpdate;
    try
      for I := 0 to FCompiler.MessageCount - 1 do
      begin
        Hinted.Add(FCompiler.Messages[I]);
        if FCompiler.Messages[I].Kind <> mkInfo then
        begin
          MessageList.Items.AddObject(FCompiler.Messages[I].Text, FCompiler.Messages[I]);
          if (FirstErr < 0) and (FCompiler.Messages[I].Kind in [mkError, mkFatal]) then
            FirstErr := MessageList.Items.Count - 1;
        end;
      end;
    finally
      MessageList.Items.EndUpdate;
    end;
    { Additional Message Info: the explanations of these messages }
    FMsgHints.ShowMessages(Hinted);
  finally
    Hinted.Free;
  end;
  if Result then
  begin
    if FCompiler.Summary <> '' then
      StatusBar.Panels[spMessage].Text := Format('Done: %s  (%d hints, %d warnings)', [FCompiler.Summary, FCompiler.Hints, FCompiler.Warnings])
    else
      StatusBar.Panels[spMessage].Text := 'Done.';
    { hints and warnings: Messages shown, but a view hidden at the edge stays there - an error
      slides it out }
    if MessageList.Items.Count > 0 then ShowBottom(BT_MESSAGES, False);
  end
  else
  begin
    if FCompiler.Errors = 1 then StatusBar.Panels[spMessage].Text := 'Compile failed: 1 error'
    else StatusBar.Panels[spMessage].Text := Format('Compile failed: %d errors', [FCompiler.Errors]);
    ShowBottom(BT_MESSAGES);
    if FirstErr >= 0 then
    begin
      MessageList.ItemIndex := FirstErr;
      MessagesDblClick(MessageList);
    end
    else if MessageList.Items.Count = 0 then
    begin
      MessageList.Items.BeginUpdate;
      try
        for I := 0 to FCompiler.MessageCount - 1 do
          MessageList.Items.AddObject(FCompiler.Messages[I].Text, nil);
      finally
        MessageList.Items.EndUpdate;
      end;
    end;
  end;
  { the Browser shows what was compiled (as Delphi's) }
  if Result and FBrowserPanel.Showing then RebuildBrowser;
end;

{ where the debugger looks for sources: the project's folders and search path, the folders of
  its units, its Debug source path, Library | Browsing path, Debugger Options | Debug Symbols
  Search Path (without a project: the last two) }
procedure TMainForm.DebugSourceDirs(Dirs: TStrings);
var
  I: Integer;
  P: TSdProject;
begin
  Dirs.Clear;
  { the debug session's project (another one may have become active since it started) }
  P := FDebugProject;
  if P = nil then P := FProject;
  if P <> nil then
  begin
    SearchDirsOf(P, Dirs);             // the project's folder first
    { units compiled from unsaved text name scratch files that are gone: the debugger finds
      them by name (TSdScratchBuild) }
    for I := 0 to P.UnitCount - 1 do
      if Dirs.IndexOf(ExcludeTrailingPathDelimiter(ExtractFilePath(P.Units[I].FileName))) < 0 then
        Dirs.Add(ExcludeTrailingPathDelimiter(ExtractFilePath(P.Units[I].FileName)));
    AddPathList(Dirs, P.OptStr('Directories', 'DebugSourceDirs', ''));
  end;
  AddPathList(Dirs, EnvOptions.BrowsingPath);
  AddPathList(Dirs, DebuggerOptions.SymbolPath);
end;

{ the unit (its source) and the form (its .dfm text) of form class ClassName - P's first (two
  projects of the group may have forms of one name): an open page of P's (with what is not
  saved), another open page, a unit of P whose .dfm declares that class, a unit of another
  project of the group. Forms: the classes of the projects' forms on the disk in that order
  (Objects: the unit), read the first time one is looked for there - the caller frees it }
function TMainForm.FindFormClass(const ClassName: string; P: TSdProject; out Pas, Dfm: string;
  var Forms: TStringList): Boolean;
var
  I, K, Pass: Integer;
  N, C: string;
  E: TSdEncoding;
  U: TProjectUnit;

  procedure AddForms(Prj: TSdProject);
  var
    J: Integer;
    T, FN, FC: string;
  begin
    for J := 0 to Prj.UnitCount - 1 do
      if ReadFormHeader(ChangeFileExt(Prj.Units[J].FileName, '.dfm'), T, FN, FC) then
        Forms.AddObject(FC, Prj.Units[J]);
  end;

begin
  Result := True;
  for Pass := 0 to 1 do
    for I := 0 to FPages.Count - 1 do
      if Pages[I].HasForm and SameText(Pages[I].FormClass, ClassName) and
        ((Pass = 1) or ((P <> nil) and (P.FindUnit(Pages[I].FileName) <> nil))) then
      begin
        Pas := Pages[I].GetSource;
        Dfm := Pages[I].CurrentDfm;
        Exit;
      end;
  Pas := '';
  Dfm := '';
  Result := False;
  if Forms = nil then
  begin
    { unsorted: the first of a name is P's (class names are case-insensitive, as IndexOf is) }
    Forms := TStringList.Create;
    if P <> nil then AddForms(P);
    for K := 0 to FGroup.Count - 1 do
      if (FGroup.Project(K) <> nil) and (FGroup.Project(K) <> P) then AddForms(FGroup.Project(K));
  end;
  I := Forms.IndexOf(ClassName);
  if I < 0 then Exit;
  U := TProjectUnit(Forms.Objects[I]);
  Result := ReadFormHeader(ChangeFileExt(U.FileName, '.dfm'), Dfm, N, C);
  if Result then Pas := ReadSourceFile(U.FileName, E);    // as the editor has it
end;

{ visual form inheritance: the forms of ClassName and its ancestors, the first ancestor first -
  P's forms first; Base: the class the first of them derives from (TForm, TFrame, TDataModule ...) }
function TMainForm.AncestorDfms(const ClassName: string; Dfms: TStrings; P: TSdProject; Base: PString): Boolean;
var
  Forms: TStringList;
begin
  Forms := nil;
  try
    Result := AncestorChain(ClassName, Dfms, nil, P, Base, Forms);
  finally
    Forms.Free;
  end;
end;

{ AncestorDfms with the classes of the forms too, in the same order (Classes nil: not wanted), and
  FindFormClass's list of the projects' forms kept by the caller across calls (nil at first, the
  caller frees it) }
function TMainForm.AncestorChain(const ClassName: string; Dfms, Classes: TStrings; P: TSdProject;
  Base: PString; var Forms: TStringList): Boolean;
var
  Cls, Pas, Dfm: string;
  Guard: Integer;
begin
  Result := False;
  Dfms.Clear;
  if Classes <> nil then Classes.Clear;
  Cls := ClassName;
  for Guard := 1 to 16 do
  begin
    if not FindFormClass(Cls, P, Pas, Dfm, Forms) then Exit;
    Dfms.Insert(0, Dfm);
    if Classes <> nil then Classes.Insert(0, Cls);
    if not IsInheritedDfm(Dfm) then
    begin
      if Base <> nil then Base^ := FSGetAncestorName(Pas, Cls);
      Result := True;
      Exit;
    end;
    Cls := FSGetAncestorName(Pas, Cls);
  end;
end;

{ frame class Cls is Target, derives from it or holds it - itself or in a frame it holds, at any
  depth: such a frame placed in Target would hold itself }
function TMainForm.FrameRefersTo(const Cls, Target: string; P: TSdProject; var Forms: TStringList;
  Depth: Integer): Boolean;
var
  Dfms, Classes, Lines: TStringList;
  I, K: Integer;
  N, C: string;
begin
  Result := (Target <> '') and SameText(Cls, Target);
  if Result or (Target = '') or (Depth > 8) then Exit;
  Dfms := TStringList.Create;
  Classes := TStringList.Create;
  Lines := TStringList.Create;
  try
    if not AncestorChain(Cls, Dfms, Classes, P, nil, Forms) then Exit;
    Result := Classes.IndexOf(Target) >= 0;
    I := 0;
    while not Result and (I < Dfms.Count) do
    begin
      Lines.Text := Dfms[I];
      for K := 1 to Lines.Count - 1 do           // the first line is the frame's own
        if SameText(Copy(TrimLeft(Lines[K]), 1, 7), 'inline ') and DfmObjectHeader(Lines[K], N, C) and
          FrameRefersTo(C, Target, P, Forms, Depth + 1) then
        begin
          Result := True;
          Break;
        end;
      Inc(I);
    end;
  finally
    Lines.Free;
    Classes.Free;
    Dfms.Free;
  end;
end;

{ "Select frame to insert": the frames of project P - form name and class of each unit whose chain
  of project forms ends at TFrame (an open page's form as it is now), in the project's order; not
  the class designed (Designed), nor a frame that derives from it or holds it }
procedure TMainForm.ProjectFrames(P: TSdProject; const Designed: string; Names, Classes: TStrings);
var
  I: Integer;
  Pg: TEditorPage;
  T, FN, FC, Base: string;
  Dfms, Forms: TStringList;
begin
  Dfms := TStringList.Create;
  Forms := nil;
  try
    for I := 0 to P.UnitCount - 1 do
    begin
      Pg := FindPage(P.Units[I].FileName);
      if (Pg <> nil) and Pg.HasForm then FC := Pg.FormClass
      else if not ReadFormHeader(ChangeFileExt(P.Units[I].FileName, '.dfm'), T, FN, FC) then Continue;
      if (FC = '') or (Classes.IndexOf(FC) >= 0) then Continue;
      Base := '';
      if not AncestorChain(FC, Dfms, nil, P, @Base, Forms) or not SameText(Base, 'TFrame') or
        FrameRefersTo(FC, Designed, P, Forms, 0) or not DfmObjectHeader(Dfms[Dfms.Count - 1], FN, T) then
        Continue;
      Names.Add(FN);
      Classes.Add(FC);
    end;
  finally
    Forms.Free;
    Dfms.Free;
  end;
end;

{ Delphi 7's Frames tool placed on designer D: "Select frame to insert" with the frames of the
  designed unit's project (else the active one), then the chosen frame at ScreenPt (Drop) or in
  the selected container (TFormDesigner.PlaceFrame); Delphi's messages without a project or a
  frame. True: a frame was placed }
function TMainForm.InsertFrame(D: TFormDesigner; Drop: Boolean; const ScreenPt: TPoint): Boolean;
var
  I, Idx: Integer;
  Pg: TEditorPage;
  P: TSdProject;
  Designed: string;
  Names, Classes: TStringList;
begin
  Result := False;
  { a data module, a placed frame there: refused before a frame is asked for }
  if (D = nil) or not D.FramePlaceable(Drop, ScreenPt) then Exit;
  Pg := nil;
  for I := 0 to FPages.Count - 1 do
    if Pages[I].Designer = D then Pg := Pages[I];
  P := nil;
  if Pg <> nil then
  begin
    P := FGroup.ProjectForFile(Pg.FileName);
    Designed := Pg.FormClass;
  end
  else
    Designed := D.GetRootClassName;
  if P = nil then P := FProject;
  if P = nil then
  begin
    MessageBox(Handle, 'No project open. To insert a frame a project must be open', AppTitle,
      MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  Names := TStringList.Create;
  Classes := TStringList.Create;
  try
    ProjectFrames(P, Designed, Names, Classes);
    if Names.Count = 0 then
    begin
      MessageBox(Handle, 'No frames in project. To create a frame select File|New|Frame', AppTitle,
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    Idx := 0;
    if ListDialog(Self, 'Select frame to insert', Names, Idx) and (Idx >= 0) and (Idx < Classes.Count) then
      Result := D.PlaceFrame(Classes[Idx], Drop, ScreenPt);
  finally
    Classes.Free;
    Names.Free;
  end;
end;

{ a component of Page's form or frame was renamed - its designer asks before the name changes:
  once the rename is done (WMInheritRename), the open forms built from that form or frame rename
  their "inherited" entries for it, so that their changes to it stay }
procedure TMainForm.QueueInheritRename(Page: TEditorPage; const OldName, NewName: string);
begin
  if (Page = nil) or not Page.HasForm or (Page.FormClass = '') then Exit;
  if FInheritRenames = nil then FInheritRenames := TStringList.Create;
  if FInheritRenames.Count = 0 then PostMessage(Handle, WM_SDINHERITRENAME, 0, 0);
  FInheritRenames.Add(Page.FormClass + '|' + OldName + '|' + NewName);
end;

{ the renames queued: every other open page with a form whose text has entries for the renamed
  component takes its text with them renamed - its designer reads it again with the form or frame
  as it is now (the new name), a page without a designer keeps the text; files not open are not
  touched }
procedure TMainForm.WMInheritRename(var Message: TMessage);
var
  Q, Forms: TStringList;
  I, K, P1, P2: Integer;
  X, OldName, NewName, Text, NewText: string;
  Pg: TEditorPage;
  Prj, FormsPrj: TSdProject;
begin
  if (FInheritRenames = nil) or FClosing then Exit;
  Q := FInheritRenames;
  FInheritRenames := nil;
  { FindFormClass's list of the projects' forms on the disk (it begins with the forms of the
    project it was made for, and points to that project's units): read once for the pages of one
    project, made again for another project and after a page took a changed form }
  Forms := nil;
  FormsPrj := nil;
  try
    for I := 0 to Q.Count - 1 do
    begin
      P1 := Pos('|', Q[I]);
      P2 := P1 + Pos('|', Copy(Q[I], P1 + 1, MaxInt));
      X := Copy(Q[I], 1, P1 - 1);
      OldName := Copy(Q[I], P1 + 1, P2 - P1 - 1);
      NewName := Copy(Q[I], P2 + 1, MaxInt);
      for K := 0 to FPages.Count - 1 do
      begin
        Pg := Pages[K];
        if not Pg.HasForm or SameText(Pg.FormClass, X) then Continue;
        Prj := FGroup.ProjectForFile(Pg.FileName);
        if Prj = nil then Prj := FProject;
        if Prj <> FormsPrj then
        begin
          FreeAndNil(Forms);
          FormsPrj := Prj;
        end;
        Text := Pg.CurrentDfm;
        NewText := RenameInheritedEntries(Text, X, OldName, NewName, Prj, Forms);
        if NewText <> Text then
        begin
          FreeAndNil(Forms);
          Pg.TakeChangedForm(NewText);
        end;
      end;
    end;
  finally
    Forms.Free;
    Q.Free;
  end;
end;

{ form text Text with its "inherited" entries for component OldName of form or frame class X
  renamed NewName: those in the blocks whose names are X's - the root of a form built on X, a
  placed frame of X or of a frame built on it, the containers in them -, not those of another
  frame placed in such a block, which has names of its own. A block of a form or frame of the
  project (P's first) has X's names when its chain of project forms holds X; any other class's
  block has its parent's }
function TMainForm.RenameInheritedEntries(const Text, X, OldName, NewName: string; P: TSdProject;
  var Forms: TStringList): string;
var
  L, Known, Dfms, Classes: TStringList;
  Own: array of Boolean;           // per open block: its names are X's
  Depth, I, Q, C: Integer;
  T, Kw, N, Cls, Indent: string;
  Parent, Changed: Boolean;

  procedure Push(Value: Boolean);
  begin
    if Depth >= Length(Own) then SetLength(Own, Depth + 16);
    Own[Depth] := Value;
    Inc(Depth);
  end;

  { the names of a block of class ACls: X's or not for a form or frame of the project, the
    parent's for a component of a package (Known: '1', '0', '-' per class, asked once) }
  function NamesOf(const ACls: string; InParent: Boolean): Boolean;
  var
    K: Integer;
    V: string;
  begin
    K := Known.IndexOfName(ACls);
    if K >= 0 then
      V := Known.ValueFromIndex[K]
    else
    begin
      if DesignHost.FindComponentClass(ACls) <> nil then V := '-'
      else if AncestorChain(ACls, Dfms, Classes, P, nil, Forms) then
      begin
        if Classes.IndexOf(X) >= 0 then V := '1' else V := '0';
      end
      else
        V := '-';
      Known.Add(ACls + '=' + V);
    end;
    if V = '-' then Result := InParent else Result := V = '1';
  end;

begin
  Result := Text;
  if (X = '') or (OldName = '') or SameText(OldName, NewName) then Exit;
  L := TStringList.Create;
  Known := TStringList.Create;
  Dfms := TStringList.Create;
  Classes := TStringList.Create;
  try
    L.Text := Text;
    Depth := 0;
    Changed := False;
    for I := 0 to L.Count - 1 do
    begin
      T := Trim(L[I]);
      if (T = 'end') or (Copy(T, 1, 4) = 'end>') then
      begin
        if Depth > 0 then Dec(Depth);
        Continue;
      end;
      if Depth = 0 then Parent := False else Parent := Own[Depth - 1];
      { a collection's item: an "end" closes it as well }
      if T = 'item' then
      begin
        Push(Parent);
        Continue;
      end;
      Q := Pos(' ', T);
      C := Pos(':', T);
      if (Q = 0) or (C < Q) then Continue;
      Kw := LowerCase(Copy(T, 1, Q - 1));
      if (Kw <> 'object') and (Kw <> 'inherited') and (Kw <> 'inline') then Continue;
      N := Trim(Copy(T, Q + 1, C - Q - 1));
      Cls := Trim(Copy(T, C + 1, MaxInt));
      if Pos(' ', Cls) > 0 then Cls := Copy(Cls, 1, Pos(' ', Cls) - 1);
      if (Depth > 0) and Parent and (Kw = 'inherited') and SameText(N, OldName) then
      begin
        Indent := Copy(L[I], 1, Length(L[I]) - Length(TrimLeft(L[I])));
        L[I] := Indent + Copy(T, 1, Q) + NewName + Copy(T, C, MaxInt);
        Changed := True;
      end;
      Push(NamesOf(Cls, Parent));
    end;
    if Changed then Result := L.Text;
  finally
    Classes.Free;
    Dfms.Free;
    Known.Free;
    L.Free;
  end;
end;

{ Run | Attach to Process: a running program (Delphi's dialog); its breakpoints are the open
  project's }
procedure TMainForm.PrepareDebug(Dirs: TStrings);
begin
  SyncAllBreakpoints;
  DebugSourceDirs(Dirs);
  ShowBottom(BT_LOG);
end;

{ the debugger attached to process Pid (Run | Attach to Process, an expert's AttachProcess) }
procedure TMainForm.AttachTo(Pid: Cardinal);
var
  Dirs: TStringList;
begin
  if FDebug.Active then Exit;
  Dirs := TStringList.Create;
  try
    PrepareDebug(Dirs);
    FDebug.Attach(Pid, Dirs);
  finally
    Dirs.Free;
  end;
end;

procedure TMainForm.AttachToProcess;
var
  Pid: Cardinal;
begin
  if not FDebug.Active and AttachDialog(Self, Pid) then AttachTo(Pid);
end;

function TMainForm.StartDebug(StopAtEntry: Boolean): Boolean;
var
  Dirs: TStringList;
  Host, WorkDir: string;
  P: TSdProject;
begin
  Result := False;
  if (FProject = nil) or not RunTarget(Host) then Exit;
  { Debugger Options | Integrated debugging off: the program runs on its own }
  if not DebuggerOptions.Integrated then
  begin
    Result := RunWithoutDebugging;
    Exit;
  end;
  P := FProject;
  if not DoCompile(False, True, False) or (FProject <> P) then Exit;
  { the session's project: its folders are the debugger's, another project may become active
    while it runs }
  FDebugProject := P;
  Dirs := TStringList.Create;
  try
    PrepareDebug(Dirs);
    WorkDir := FProject.OptStr('Parameters', 'DebugCWD', '');
    if WorkDir = '' then WorkDir := FolderArg(FProject.OutputDir);
    Result := FDebug.Run(Host, FProject.OptStr('Parameters', 'RunParams', ''), WorkDir, Dirs, StopAtEntry,
      ProjectEnvironment(FProject));
  finally
    Dirs.Free;
    if Result and FDebug.Active then FDebugProject := P else FDebugProject := nil;
  end;
end;

{ ---------------------------------------------------------------- debugger callbacks }

{ the execution point is on one page at most, the one DebugLocation marked: the others' documents
  stay where they are (a page that is not shown has its text in the hidden worker window while it
  is worked on) }
procedure TMainForm.ClearExecMarkers;
begin
  if (FExecPage <> nil) and (FPages.IndexOf(FExecPage) >= 0) then
  begin
    FExecPage.Editor.MarkerDeleteAll(MK_EXEC);
    FExecPage.Editor.MarkerDeleteAll(MK_EXEC_LINE);
  end;
  FExecPage := nil;
end;

procedure TMainForm.DebugLocation(const FileName: string; Line: Integer);
var
  P: TEditorPage;
begin
  ClearExecMarkers;
  if not FileExists(FileName) then Exit;
  { where the program stopped is no jump of the user's (Delphi 7 records none) }
  Inc(FNavLock);
  try
    P := ShowFileLine(FileName, Line, 1);
  finally
    Dec(FNavLock);
  end;
  if (P <> nil) and FDebug.Paused and SameText(FDebug.ExecFile, FileName) and (FDebug.ExecLine = Line) then
  begin
    P.Editor.MarkerAdd(Line - 1, MK_EXEC);
    P.Editor.MarkerAdd(Line - 1, MK_EXEC_LINE);
    FExecPage := P;
  end;
end;

{ the program runs for longer than a step: what showed the last stop goes now }
procedure TMainForm.DebugRunning(Sender: TObject);
begin
  if FClosing then Exit;
  ClearExecMarkers;
  DebugStateChange(Sender);
end;

procedure TMainForm.DebugStateChange(Sender: TObject);
var
  I: Integer;
begin
  if FClosing then Exit;
  { the value tip showed the program as it was stopped }
  if ValueTip <> nil then ValueTip.HideTip;
  if not FDebug.Active then FDebugProject := nil;
  { the experts' debugger notifiers (process created / destroyed, threads stopped / running) }
  OtaDebugStateChanged;
  { ended, or stopped where there is no source (the CPU view shows the place): no arrow; while it
    runs the arrow goes with DebugRunning (a step keeps it until the next one is set: no blink) }
  if not FDebug.Active or (FDebug.Paused and (FDebug.ExecLine = 0)) then ClearExecMarkers;
  for I := 0 to FPages.Count - 1 do RefreshBreakMarkers(Pages[I]);
  UpdateCaption;
  if FDebug.ShownPaused then
  begin
    if not FDebug.Paused then Exit;     // a step: the stop before stays shown
    StatusBar.Panels[spMessage].Text := 'Process stopped.';
    if FCpuStepping then FCpuView.FocusDisasm;
    { the local variables, where Messages or the Event Log were shown }
    if (FBottomPanels[BT_LOCALS].Group.Active = FBottomPanels[BT_MESSAGES]) or
      (FBottomPanels[BT_LOCALS].Group.Active = FBottomPanels[BT_LOG]) then
      ShowBottom(BT_LOCALS);
  end
  else if FDebug.Active then
    StatusBar.Panels[spMessage].Text := 'Running.'
  else if FDebug.Debugger.Detached then
    StatusBar.Panels[spMessage].Text := 'Process detached.'
  else
    StatusBar.Panels[spMessage].Text := 'Process terminated.';
  RunStateChanged(FDebug.ShownRunning, FDebug.Active);
end;

{ Environment Options | Preferences | Minimize on run: while the program runs the IDE is
  minimized; a stop (breakpoint, exception) brings the IDE back - once a session }
{ a debug session ends because the IDE or the project closes: FDebug.Stop only terminates the
  program and its state change arrives later, so the arrangement of the run (debug desktop)
  goes back now - before the layout and the desktop are saved }
procedure TMainForm.StopDebugNow;
begin
  if not FDebug.Active then Exit;
  FDebug.Stop;
  RunStateChanged(False, False);
end;

procedure TMainForm.RunStateChanged(Running, Active: Boolean);
var
  D: string;
  I: Integer;
begin
  { View | Desktops | Set Debug Desktop: that arrangement while the debugger runs, then the
    one before }
  if Active and not FDebugDesktop then
  begin
    D := Settings.ReadString('Desktops', '.Debug', '');
    if (D <> '') and Settings.ValueExists('Desktops', D) then
    begin
      SaveNamedDesktop('.Saved');
      ShowNamedDesktop(D);        // the current desktop stays the user's ([Desktops] .Current)
      FDebugDesktop := True;
    end;
  end
  else if not Active and FDebugDesktop then
  begin
    ShowNamedDesktop('.Saved');
    FDebugDesktop := False;
  end;
  { Debugger Options | Mark buffers read-only on run: the files can be read, not changed, while
    the debug session lasts; the ones it locked are unlocked after it }
  if Active and not FRunLocked and DebuggerOptions.MarkReadOnly then
  begin
    FRunLocked := True;
    for I := 0 to FPages.Count - 1 do LockForRun(Pages[I]);
  end
  else if not Active and FRunLocked then
  begin
    FRunLocked := False;
    for I := 0 to FLockedPages.Count - 1 do
      if FPages.IndexOf(FLockedPages[I]) >= 0 then TEditorPage(FLockedPages[I]).Editor.ReadOnly := False;
    FLockedPages.Clear;
  end;
  if Running and not FRunHidden then
  begin
    FRunHidden := True;
    FRunMinimized := False;
    if EnvOptions.MinimizeOnRun and not IsIconic(Application.Handle) then
    begin
      Application.Minimize;
      FRunMinimized := True;
    end;
  end
  else if not Running and FRunHidden then
  begin
    if FRunMinimized then Application.Restore;
    FRunMinimized := False;
    if not Active then FRunHidden := False;
  end;
end;

procedure TMainForm.DebugBreakpointsChanged(Sender: TObject);
var
  I: Integer;
begin
  if FClosing then Exit;
  for I := 0 to FPages.Count - 1 do RefreshBreakMarkers(Pages[I]);
  FCpuView.BreakpointsChanged;
  OtaBreakpointsChanged;
end;

procedure TMainForm.RefreshBreakMarkers(Page: TEditorPage);
var
  I: Integer;
  BP: TDbgBreakpoint;
  Ed: TSciEdit;
begin
  Ed := Page.Editor;
  Ed.MarkerDeleteAll(MK_BREAK);
  Ed.MarkerDeleteAll(MK_BREAK_DISABLED);
  Ed.MarkerDeleteAll(MK_BREAK_INVALID);
  Ed.MarkerDeleteAll(MK_BREAK_LINE);
  Ed.MarkerDeleteAll(MK_BREAK_DISABLED_LINE);
  Ed.MarkerDeleteAll(MK_BREAK_INVALID_LINE);
  for I := 0 to FDebug.BreakpointCount - 1 do
  begin
    BP := FDebug.Breakpoint(I);
    if not SameText(BP.FileName, Page.FileName) or (BP.Line < 1) or (BP.Line > Ed.LineCount) then Continue;
    if not BP.Enabled then
    begin
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK_DISABLED);
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK_DISABLED_LINE);
    end
    else if FDebug.Active and not BP.Valid then
    begin
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK_INVALID);
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK_INVALID_LINE);
    end
    else
    begin
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK);
      Ed.MarkerAdd(BP.Line - 1, MK_BREAK_LINE);
    end;
  end;
end;

procedure TMainForm.SyncBreakpoints(Page: TEditorPage);
const
  Mask = (1 shl MK_BREAK) or (1 shl MK_BREAK_DISABLED) or (1 shl MK_BREAK_INVALID);
var
  Lines: TList;
  L: Integer;
begin
  { marker lines move while the text is edited: write them back to the engine }
  if (Page = nil) or not Page.IsPascal then Exit;
  Lines := TList.Create;
  try
    L := Page.Editor.MarkerNext(0, Mask);
    while L >= 0 do
    begin
      Lines.Add(Pointer(L + 1));
      L := Page.Editor.MarkerNext(L + 1, Mask);
    end;
    FDebug.SetFileBreakpoints(Page.FileName, Lines);
  finally
    Lines.Free;
  end;
end;

{ the breakpoints of every open page into the engine (before a run, an attach, a close) }
procedure TMainForm.SyncAllBreakpoints;
var
  I: Integer;
begin
  for I := 0 to FPages.Count - 1 do SyncBreakpoints(Pages[I]);
end;

{ ---------------------------------------------------------------- designer environment }

procedure TMainForm.DesSelectionChanged(D: TFormDesigner);
begin
  if FClosing then Exit;
  if (ActivePage <> nil) and (ActivePage.Designer = D) then
  begin
    FInspector.SetDesigner(D);
    if FObjTree.Designer = D then FObjTree.SyncSelection;
  end;
end;

procedure TMainForm.DesModified(D: TFormDesigner);
begin
  if FClosing then Exit;
  if FInspector.Designer = D then FInspector.RefreshValues;
  { a name or a caption the Object TreeView shows may have changed }
  if FObjTree.Designer = D then FObjTreeDirty := True;
  UpdateStatus;
end;

procedure TMainForm.DesStructureChanged(D: TFormDesigner);
begin
  if FClosing then Exit;
  if FInspector.Designer = D then FInspector.StructureChanged;
  { the Object TreeView's nodes may point to deleted components until StructTimer }
  if FObjTree.Designer = D then
  begin
    FObjTree.Outdated;
    FObjTreeDirty := True;
  end;
  StructTimer.Enabled := False;
  StructTimer.Enabled := True;
end;


procedure TMainForm.DesFocusInspector(Key: Char; const PropName: string);
begin
  ShowDockPanel(FInspPanel);
  FInspector.FocusProperty(Key, PropName);
end;

procedure TMainForm.DesVerbExecute(Sender: TObject);
var
  D: TFormDesigner;
begin
  D := ActiveDesigner;
  if D <> nil then D.ExecuteVerb(TAction(Sender).Tag);
end;

{ an item of the code editor's menu that is a command of the main menu under Delphi's other name }
procedure TMainForm.ActTwin(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to High(FTwins) do
    if FTwins[I, 0] = Sender then FTwins[I, 1].Execute;
end;

{ pairs of twin and command }
procedure TMainForm.AddTwins(const Pairs: array of TAction);
var
  I, N: Integer;
begin
  I := 0;
  while I < High(Pairs) do
  begin
    N := Length(FTwins);
    SetLength(FTwins, N + 1);
    FTwins[N, 0] := Pairs[I];
    FTwins[N, 1] := Pairs[I + 1];
    Inc(I, 2);
  end;
end;

{ The designer's context menu, Delphi 7's: the verbs of the component editor, the Edit and Control
  submenus, the verbs of the selection editors (DesignPopupPopup), then Delphi's designer commands.
  Its commands are the main menu's actions themselves (caption, icon, shortcut, state and the
  routing in one place): the right click that opens the menu has put the keyboard on the design
  surface, so ActEdit sends the Edit submenu's commands to this designer. }
procedure TMainForm.DesContextMenu(D: TFormDesigner; const ScreenPt: TPoint);
begin
  FVerbDesigner := D;
  DesignPopup.Popup(ScreenPt.X, ScreenPt.Y);
end;

{ the verbs, as the menu opens (also when the test channel opens it): an action each, in
  VerbActions, its item made ready by its editor (PrepareItem through SdDesignMenus) - for the
  designer the right click was on, else the active one. The component editor's go to the top, a
  line under them when one of them shows; the selection editors' (experts' commands) after the
  Control submenu. As in Delphi's designer, Edit is enabled when one of its commands is, and
  Control (the z-order) shows when a control of the form is selected. }
procedure TMainForm.DesignPopupPopup(Sender: TObject);
var
  D: TFormDesigner;
  Verbs: TStringList;
  Item: TMenuItem;
  I, CompVerbs: Integer;
  Shown, Controls: Boolean;
begin
  D := FVerbDesigner;
  FVerbDesigner := nil;
  if D = nil then D := ActiveDesigner;
  DropVerbs;
  UpdateActionStates;
  Shown := False;
  Controls := False;
  if D <> nil then
  begin
    Verbs := TStringList.Create;
    try
      CompVerbs := D.GetVerbs(Verbs);
      for I := 0 to Verbs.Count - 1 do
      begin
        if I < CompVerbs then
          Item := NewActionItem(DesignPopup.Items, NewAction(VerbActions, Verbs[I], '', I, DesVerbExecute), I)
        else
          Item := NewActionItem(DesignPopup.Items, NewAction(VerbActions, Verbs[I], '', I, DesVerbExecute),
            pmDesignSelSep.MenuIndex);
        D.PrepareVerb(I, MenuItemIntf(Item, VerbActions));
        if I < CompVerbs then Shown := Shown or Item.Visible;
      end;
    finally
      Verbs.Free;
    end;
    Controls := SelectedControlCount(D) > 0;
  end;
  pmDesignVerbSep.Visible := Shown;
  pmDesignEdit.Enabled := EditUndoCommand.Enabled or EditCutCommand.Enabled or EditCopyCommand.Enabled or
    EditPasteCommand.Enabled or EditDeleteCommand.Enabled or EditSelectAllCommand.Enabled;
  pmDesignControl.Visible := Controls;
end;

{ the Components view: Enter or a double click adds the component (PlaceComponent), a drag
  onto the form drops it at the point }
procedure TMainForm.CompBarAdd(Sender: TObject; Cls: TComponentClass; var Done: Boolean);
var
  It: TPaletteItem;
begin
  Done := ActiveDesigner <> nil;
  It := FCompBar.SelectedItem;
  { the Frames tool: a frame of the project, in the selected container }
  if (It <> nil) and It.IsFrames then
  begin
    Done := InsertFrame(ActiveDesigner, False, Point(0, 0));
    Exit;
  end;
  { a component template: its components, in the selected container }
  if (It <> nil) and (It.Template <> '') then
  begin
    if Done then ActiveDesigner.PasteText(ShiftTemplateText(It.Template, 8, 8));
    Exit;
  end;
  PlaceComponent(Cls);
end;

{ a drag over the code or the diagram of a unit with a form shows its form, where the component
  can go }
procedure TMainForm.CompBarCanDrop(Sender: TObject; const ScreenPt: TPoint; var Accept: Boolean);
var
  P: TEditorPage;
  V: TWinControl;
  R: TRect;
begin
  P := ActivePage;
  if (P <> nil) and P.HasForm and not P.DesignView then
  begin
    if P.DiagramView then V := P.Diagram else V := P.Editor.Window;
    if (V <> nil) and V.HandleAllocated and IsWindowVisible(V.Handle) then
    begin
      GetWindowRect(V.Handle, R);
      if PtInRect(R, ScreenPt) then P.ShowDesign(True, False);
    end;
  end;
  Accept := (ActiveDesigner <> nil) and (ActiveDesigner.ControlAtScreen(ScreenPt) <> nil);
end;

procedure TMainForm.CompBarDrop(Sender: TObject; Cls: TComponentClass; const ScreenPt: TPoint; var Done: Boolean);
var
  It: TPaletteItem;
begin
  It := FCompBar.DragItem;
  if (It <> nil) and It.IsFrames then
    Done := InsertFrame(ActiveDesigner, True, ScreenPt)
  else if (It <> nil) and (It.Template <> '') then
    Done := (ActiveDesigner <> nil) and ActiveDesigner.DropText(It.Template, ScreenPt)
  else
    Done := (ActiveDesigner <> nil) and ActiveDesigner.DropComponent(Cls, ScreenPt);
end;

{ a left click on the designed form while a tool is chosen on the hidden palette (an expert chose
  it, SdOtaPalette): the tool goes there, as Delphi's palette places it; then the selector is down
  again, unless Shift is held }
function TMainForm.PaletteToolClick(Designer: TFormDesigner; const ScreenPt: TPoint;
  Shift: TShiftState): Boolean;
var
  It: TPaletteItem;
begin
  Result := False;
  if FIdePalette = nil then Exit;
  It := FIdePalette.SelectedItem;
  if It = nil then Exit;
  Result := True;
  if It.IsFrames then InsertFrame(Designer, True, ScreenPt)
  else if It.Template <> '' then Designer.DropText(It.Template, ScreenPt)
  else Designer.DropComponent(It.ComponentClass, ScreenPt);
  if not (ssShift in Shift) then FIdePalette.ClearSelection;
end;

{ a component on the form being designed, inside the selected container (Enter or a double
  click in the Components view, View | Component List | Add to form) }
procedure TMainForm.PlaceComponent(Cls: TComponentClass);
var
  D: TFormDesigner;
  C: TComponent;
  Parent: TComponent;
begin
  D := ActiveDesigner;
  if (D = nil) or (Cls = nil) then Exit;
  Parent := D.Root;
  if (D.SelectionCount = 1) and (D.Selections[0] is TWinControl) and
    (csAcceptsControls in TWinControl(D.Selections[0]).ControlStyle) then
    Parent := TComponent(D.Selections[0]);
  C := D.AddComponent(Cls, Parent, 16, 16, 0, 0);
  if C <> nil then D.Select(C);
end;

procedure TMainForm.StructTimerTick(Sender: TObject);
begin
  StructTimer.Enabled := False;
  { the timer follows every change of the page as well: the Object TreeView only when its form changed }
  RefreshObjTree(FObjTreeDirty);
  if not FClosing then FNavBar.Follow(ActivePage, True);
  TodoTypingPause;
end;

{ the Object TreeView: the form of the active page's designer - also while the page shows its code
  (the Object Inspector follows that designer too). Force: made again for the same designer (its
  form changed: StructTimer) }
procedure TMainForm.RefreshObjTree(Force: Boolean);
var
  P: TEditorPage;
  D: TFormDesigner;
begin
  if FClosing or not FObjTree.Visible then Exit;
  P := ActivePage;
  D := nil;
  if P <> nil then D := P.Designer;
  if D = nil then
  begin
    if FObjTree.Designer <> nil then FObjTree.Clear;
    Exit;
  end;
  if not Force and (D = FObjTree.Designer) then Exit;
  FObjTree.ShowDesigner(D);
  FObjTreeDirty := False;
end;

{ the Code Explorer: the unit of the active page, its picture made
  again only when its text changed (the caret moving changes the page too) and only while the view
  is shown. No page, a page of another kind of file: an empty tree - the next unit starts as new
  (Delphi's new model); a parse that fails leaves the tree as it was }
procedure TMainForm.RefreshExplorer;
var
  P: TEditorPage;
  Root: TCIExpNode;
begin
  if FClosing then Exit;
  UpdateExplorerTitle;
  if not FCodeExp.Visible then Exit;
  P := ActivePage;
  if (P = nil) or not P.IsPascal then
  begin
    ExpForget;
    Exit;
  end;
  if (P = FExpPage) and (P.TextVersion = FExpVersion) then Exit;
  Root := FCodeInsight.GetExplorer(P.FileName, P.GetSource);
  if Root = nil then Exit;
  FCodeExp.ShowExplorer(Root, not FExpFilled);
  FExpPage := P;
  FExpVersion := P.TextVersion;
  FExpFilled := True;
  ExpFollowCaret(P);
end;

{ the page whose unit the Code Explorer shows while it is the active one (nil: none); Edit - only
  while its text may be changed }
function TMainForm.ExpPageOf(Edit: Boolean): TEditorPage;
begin
  Result := ActivePage;
  if (Result = nil) or (Result <> FExpPage) or Edit and Result.Editor.ReadOnly then Result := nil;
end;

{ the Code Explorer shows no unit: an empty tree, the next unit starts as new (Delphi's new model) }
procedure TMainForm.ExpForget;
begin
  if FCodeExp.Root <> nil then FCodeExp.Clear;
  FExpPage := nil;
  FExpVersion := -1;
  FExpFilled := False;
end;

{ Synchronize with the editor (Environment Options | Explorer): the caret of the page whose text the
  Code Explorer shows as it is now - a changed text waits for its new tree (RefreshExplorer) }
procedure TMainForm.ExpFollowCaret(Page: TEditorPage);
var
  E: TSciEdit;
begin
  if not EnvOptions.ExSyncEditor or (Page = nil) or (Page <> FExpPage) or (Page.TextVersion <> FExpVersion) then Exit;
  E := Page.Editor;
  { code insight's column: the byte in the line + 1 }
  FCodeExp.CaretMoved(E.CaretLine + 1, E.CaretPos - E.PosFromLine(E.CaretLine) + 1);
end;

{ Delphi's caption "Exploring Unit1.pas" (the file's name; a page of another kind of file
  "Exploring "), without a page the view's name; its tab says Code Explorer }
procedure TMainForm.UpdateExplorerTitle;
var
  P: TEditorPage;
  T: string;
begin
  if FCodeExpPanel = nil then Exit;
  P := ActivePage;
  if P = nil then T := 'Code Explorer'
  else if P.IsPascal then T := 'Exploring ' + ExtractFileName(P.FileName)
  else T := 'Exploring ';
  if FCodeExpPanel.Title <> T then FCodeExpPanel.Title := T;
end;

procedure TMainForm.ExpParse(Sender: TObject);
begin
  RefreshExplorer;
end;

{ Enter, a double click in the Code Explorer: the page's code with TopLine at its top and the caret
  at the place, the editor focused (Delphi's ShowSource / ShowText). A node chosen with Synchronize
  with the editor: the same in the code shown - the focus stays in the tree, the browse history
  takes no jump, a form shown stays }
procedure TMainForm.ExpShowSource(Sender: TObject; TopLine, Line, Col: Integer; TakeFocus: Boolean);
var
  P: TEditorPage;
begin
  P := ExpPageOf(False);
  if P = nil then Exit;
  if not TakeFocus then
  begin
    if P.CodeView then P.ShowText(TopLine, Line, Col);
    Exit;
  end;
  NavMark;
  P.ShowDesign(False);
  P.ShowText(TopLine, Line, Col);
  if P.Editor.CanFocus then P.Editor.SetFocus;
end;

{ View Editor: the page's code, focused }
procedure TMainForm.ExpViewEditor(Sender: TObject);
var
  P: TEditorPage;
begin
  P := ActivePage;
  if P = nil then Exit;
  P.ShowDesign(False);
  if P.Editor.CanFocus then P.Editor.SetFocus;
end;

{ Properties: Environment Options at its Explorer page (Delphi: the dialog Explorer Options, that
  page alone) }
procedure TMainForm.ExpProperties(Sender: TObject);
begin
  ShowOptions(osEnvironment, EnvOptionsExplorerPage);
end;

{ New: what New's edit took, written into the page's unit as Delphi writes it (SdExplorerEdit);
  Delphi's reason when it cannot }
function TMainForm.ExpNew(Sender: TObject; const Place: TExpNewPlace; const Text: string): Boolean;
var
  P: TEditorPage;
  S, Err: string;
  OK: Boolean;
begin
  Result := False;
  P := ExpPageOf(True);
  if P = nil then Exit;
  { the call first: ExpApply's arguments S and Err would be taken (pushed) before a call among them
    fills them }
  OK := FCodeInsight.ExplorerNew(P.FileName, P.GetSource, Place.ClassName, Place.Access, Place.InUses,
    Text, S, Err);
  Result := ExpApply(P, OK, S, Err);
end;

{ Rename: a form's class, its components and its event handlers through the designer - the form
  renamed, the component renamed, the handler renamed with its events (Delphi's IForm) -, anything
  else in the page's unit as Delphi renames it (SdExplorerEdit) }
function TMainForm.ExpRename(Sender: TObject; Node: TCIExpNode; const ClassName, NewName: string): Boolean;
var
  P: TEditorPage;
  D: TFormDesigner;
  Kind: TExpRenameKind;
  C: TComponent;
  S, Err: string;
begin
  Result := False;
  P := ExpPageOf(True);
  if P = nil then Exit;
  case Node.Kind of
    xkClass: Kind := erClass;
    xkProcedure, xkFunction: Kind := erMethod;
    xkProperty: Kind := erProperty;
  else
    Kind := erField;
  end;
  { the unit's rename first: it checks the new name (Delphi's reasons) and is the text of all but
    the form's own }
  if not FCodeInsight.ExplorerRename(P.FileName, P.GetSource, Kind, ClassName, Node.Name, NewName, S, Err) then
  begin
    ExpApply(P, False, '', Err);
    Exit;
  end;
  { the designer for what is the form's (its class, a component, an event handler): the form
    follows }
  D := nil;
  if P.HasForm and (P.FormClass <> '') and (SameText(ClassName, P.FormClass) or
    (Kind = erClass) and SameText(Node.Name, P.FormClass)) and P.EnsureDesigner then D := P.Designer;
  if (D <> nil) and (D.Root <> nil) then
  begin
    try
      if (Kind = erClass) and SameText(Node.Name, D.Root.ClassName) then
      begin
        if (Length(NewName) > 1) and (UpCase(NewName[1]) = 'T') then D.Root.Name := Copy(NewName, 2, MaxInt)
        else D.Root.Name := NewName;
        D.Modified;
        Result := True;
        Exit;
      end;
      if SameText(ClassName, D.Root.ClassName) then
        if Kind = erField then
        begin
          C := D.Root.FindComponent(Node.Name);
          if C <> nil then
          begin
            C.Name := NewName;
            D.Modified;
            Result := True;
            Exit;
          end;
        end
        else if (Kind = erMethod) and (D.Root.MethodAddress(Node.Name) <> nil) then
        begin
          D.RenameMethod(Node.Name, NewName);
          D.Modified;
          Result := True;
          Exit;
        end;
    except
      on E: Exception do
      begin
        ExpApply(P, False, '', E.Message);
        Exit;
      end;
    end;
  end;
  Result := ExpApply(P, True, S, '');
end;

{ what New or Rename made of the page's text: NewSource taken as one step of its undo; when OK is
  False, Error in a message box }
function TMainForm.ExpApply(P: TEditorPage; OK: Boolean; const NewSource, Error: string): Boolean;
begin
  Result := OK;
  if not OK then
    MessageBox(Handle, PChar(Error), AppTitle, MB_OK or MB_ICONERROR)
  else if NewSource <> P.GetSource then
    P.SetSourceUndoable(NewSource);
end;

procedure TMainForm.StructGotoLine(Sender: TObject; Line, Col: Integer);
var
  P: TEditorPage;
begin
  P := ActivePage;
  if P = nil then Exit;
  NavMark;
  P.ShowDesign(False);
  P.GotoLine(Line, Col);
  if P.Editor.CanFocus then P.Editor.SetFocus;
end;

procedure TMainForm.StructAddItem;
var
  D: TFormDesigner;
  Obj: TPersistent;
  Item: TCollectionItem;
  MI, ParentItem: TMenuItem;
begin
  D := ActiveDesigner;
  Obj := FObjTree.SelectedObject;
  if (D = nil) or (Obj = nil) then Exit;
  if Obj is TCollectionItem then Obj := TCollectionItem(Obj).Collection;
  if Obj is TCollection then
  begin
    Item := TCollection(Obj).Add;
    D.Modified;
    RefreshObjTree(True);
    D.Select(Item);
  end
  else if (Obj is TMenu) or (Obj is TMenuItem) then
  begin
    { a placed frame's menu takes no new item }
    if not D.MayAddTo(TComponent(Obj)) then Exit;
    if Obj is TMenu then ParentItem := TMenu(Obj).Items else ParentItem := TMenuItem(Obj);
    MI := TMenuItem.Create(D.Root);
    MI.Name := D.UniqueName('TMenuItem');
    MI.Caption := MI.Name;
    ParentItem.Add(MI);
    D.Bridge.ComponentAdded(MI);
    D.Modified;
    RefreshObjTree(True);
    D.Select(MI);
  end;
end;

{ the Object TreeView's Add Item and Delete (Del) }
procedure TMainForm.ObjTreeCommand(Sender: TObject);
begin
  if Sender = FObjTree.aObjTreeAdd then StructAddItem
  else if Sender = FObjTree.aObjTreeDelete then StructDeleteItem;
end;

procedure TMainForm.StructDeleteItem;
var
  D: TFormDesigner;
  Obj: TPersistent;
begin
  D := ActiveDesigner;
  Obj := FObjTree.SelectedObject;
  if (D = nil) or (Obj = nil) then Exit;
  if Obj is TCollectionItem then
  begin
    D.Select(D.Root);
    Obj.Free;
    D.Modified;
    RefreshObjTree(True);
  end
  else if (Obj is TComponent) and (Obj <> D.Root) then
  begin
    D.Select(Obj);
    D.DeleteSelected;
  end;
end;

{ ---------------------------------------------------------------- search }

{ Find / Replace closed with OK. Scope Selected text: the search stays within the selection as
  it is now (taken once: the found matches take the selection's place) - without a selection it
  is the whole file. Origin Entire scope, and always within a selection: the search starts at
  the range's start (backwards at its end); From cursor: at the caret }
procedure TMainForm.BeginSearch(Ed: TSciEdit);
var
  Lo, Hi, L: Integer;
begin
  FFindSkipEd := nil;
  if FFind.SelectedOnly and (Ed.SelEnd > Ed.SelStart) then
  begin
    FFindRangeEd := Ed;
    FFindLo := Ed.SelStart;
    FFindHi := Ed.SelEnd;
    { lines selected whole end at the start of the next one: that line is not taken in (^
      would match there) }
    L := Ed.LineFromPos(FFindHi);
    if (L > Ed.LineFromPos(FFindLo)) and (Ed.PosFromLine(L) = FFindHi) then FFindHi := Ed.LineEndPos(L - 1);
  end
  else
    FFindRangeEd := nil;
  if FFind.EntireScope or (FFindRangeEd <> nil) then
  begin
    SearchRange(Ed, Lo, Hi);
    if FFind.Backward then Ed.GotoPos(Hi) else Ed.GotoPos(Lo);
  end;
end;

{ where Find, Replace and Search Again look in Ed: the range of Selected text, else all of it }
procedure TMainForm.SearchRange(Ed: TSciEdit; out Lo, Hi: Integer);
begin
  Lo := 0;
  Hi := Ed.TextLength;
  if not FFind.SelectedOnly or (FFindRangeEd <> Ed) then Exit;
  if FFindLo < Hi then Lo := FFindLo else Lo := Hi;     // the text may have become shorter
  if FFindHi < Hi then Hi := FFindHi;
  if Hi < Lo then Hi := Lo;
end;

function TMainForm.FindNextMatch(ShowNotFound: Boolean): Boolean;
var
  Ed: TSciEdit;
  Lo, Hi, Skip: Integer;
begin
  Result := False;
  Ed := ActiveEditor;
  if (Ed = nil) or (FFind.FindText = '') then Exit;
  SearchRange(Ed, Lo, Hi);
  { an empty match (^, x*) found or replaced last, where the caret still is: the next one }
  Skip := -1;
  if (FFindSkipEd = Ed) and (Ed.SelStart = FFindSkip) and (Ed.SelEnd = FFindSkip) then Skip := FFindSkip;
  Result := Ed.FindInRange(FFind.FindText, FFind.MatchCase, FFind.WholeWord, FFind.RegExp, not FFind.Backward,
    False, Lo, Hi, Skip);
  if Result and (Ed.SelStart = Ed.SelEnd) then
  begin
    FFindSkipEd := Ed;
    FFindSkip := Ed.SelStart;
  end
  else
    FFindSkipEd := nil;
  if not Result and ShowNotFound then
    MessageBox(Handle, PChar(Format('Search string ''%s'' not found', [FFind.FindText])), 'Information',
      MB_OK or MB_ICONINFORMATION);
end;

{ the replace part of Replace (BeginSearch has run): every match of the range after the caret
  in the direction chosen - unprompted Replace All at once, else one by one }
procedure TMainForm.DoReplace;
var
  Ed: TSciEdit;
  N, Res, Lo, Hi, OldHi, Len, At: Integer;
  Empty: Boolean;
begin
  Ed := ActiveEditor;
  if Ed = nil then Exit;
  if FFind.ReplaceAll and not FFind.PromptOnReplace then
  begin
    { from the caret on (backwards: up to it) within the range }
    SearchRange(Ed, Lo, Hi);
    if FFind.Backward then
    begin
      if Ed.SelStart < Hi then Hi := Ed.SelStart;
    end
    else if Ed.SelEnd > Lo then
      Lo := Ed.SelEnd;
    if Hi < Lo then Hi := Lo;
    OldHi := Hi;
    N := Ed.ReplaceAll(FFind.FindText, FFind.ReplaceText, FFind.MatchCase, FFind.WholeWord, FFind.RegExp, Lo, Hi);
    if FFindRangeEd = Ed then Inc(FFindHi, Hi - OldHi);
    StatusBar.Panels[spMessage].Text := Format('%d occurrences replaced.', [N]);
    Exit;
  end;
  N := 0;
  while FindNextMatch(N = 0) do
  begin
    Inc(N);
    if not FFind.PromptOnReplace then
      Res := IDYES
    else
      Res := MessageBox(Handle, PChar(Format('Replace this occurrence of ''%s''?', [FFind.FindText])),
        'Confirm', MB_YESNOCANCEL or MB_ICONQUESTION);
    if Res = IDCANCEL then Break;
    if Res = IDYES then
    begin
      Len := Ed.TextLength;
      At := Ed.SelStart;
      Empty := Ed.SelEnd = At;
      if Ed.ReplaceCurrent(FFind.FindText, FFind.ReplaceText, FFind.MatchCase, FFind.WholeWord, FFind.RegExp) then
      begin
        { the range's end moves with the text; backwards the search goes on before the
          replacement (it may match again), after an empty match a character further }
        if FFindRangeEd = Ed then Inc(FFindHi, Ed.TextLength - Len);
        if FFind.Backward then Ed.SetSel(At, At);
        if Empty then
        begin
          FFindSkipEd := Ed;
          FFindSkip := Ed.SelStart;
        end
        else
          FFindSkipEd := nil;
      end;
    end;
    if not FFind.ReplaceAll then Break;
  end;
end;

{ a row of Search Results opened (its double click): that file at that line }
procedure TMainForm.SearchOpen(Sender: TObject; const FileName: string; Line: Integer);
begin
  ShowFileLine(FileName, Line, 1);
end;

{ the project file and the files of its units (Find in Files, the To-Do List) }
procedure TMainForm.AddProjectFiles(Files: TStrings);
var
  I: Integer;
begin
  if FProject = nil then Exit;
  Files.Add(FProject.FileName);
  for I := 0 to FProject.UnitCount - 1 do Files.Add(FProject.Units[I].FileName);
end;

{ a character of a word for Whole word (Find in Files): a letter or digit of any script, '_' }
function IsWordCharW(C: WideChar): Boolean;
begin
  Result := (C = '_') or IsCharAlphaNumericW(C);
end;

procedure TMainForm.DoFindInFiles;
var
  Files, Unread: TStringList;
  I, Hits: Integer;
  E: TSdEncoding;
  Text: string;
  Needle: WideString;

  { the files of a folder through the Unicode API: every name becomes a usable one }
  procedure AddDir(const Dir: WideString);
  var
    FD: TWin32FindDataW;
    H: THandle;
    Masks: TStringList;
    M: Integer;
    Name: WideString;
  begin
    Masks := TStringList.Create;
    try
      Masks.Delimiter := ';';
      Masks.DelimitedText := FFindFiles.Mask;
      for M := 0 to Masks.Count - 1 do
      begin
        H := FindFirstFileW(PWideChar(Dir + '\' + WideString(Trim(Masks[M]))), FD);
        if H <> INVALID_HANDLE_VALUE then
        begin
          repeat
            if FD.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0 then
              Files.Add(UsablePath(Dir + '\' + WideString(FD.cFileName)));
          until not FindNextFileW(H, FD);
          Windows.FindClose(H);
        end;
      end;
    finally
      Masks.Free;
    end;
    if FFindFiles.Recurse then
    begin
      H := FindFirstFileW(PWideChar(Dir + '\*'), FD);
      if H <> INVALID_HANDLE_VALUE then
      begin
        repeat
          Name := FD.cFileName;
          if (FD.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and (Name <> '.') and (Name <> '..') then
            AddDir(Dir + '\' + Name);
        until not FindNextFileW(H, FD);
        Windows.FindClose(H);
      end;
    end;
  end;

  { the needle in a line (both in Unicode, the case folded for any script unless Case
    sensitive); Whole word: any of its places in the line that is one }
  function LineMatches(const Line: WideString): Boolean;
  var
    Hay: WideString;
    P, From: Integer;
  begin
    if FFindFiles.MatchCase then Hay := Line else Hay := WideLowerCase(Line);
    From := 0;
    repeat
      if From = 0 then P := Pos(Needle, Hay) else P := Pos(Needle, Copy(Hay, From + 1, MaxInt));
      Result := P > 0;
      if not Result or not FFindFiles.WholeWord then Exit;
      Inc(P, From);
      Result := ((P = 1) or not IsWordCharW(Hay[P - 1])) and
        ((P + Length(Needle) > Length(Hay)) or not IsWordCharW(Hay[P + Length(Needle)]));
      From := P;
    until Result;
  end;

  { a line of Search Results: the item keeps the usable name (the view's double click opens it),
    its Unicode form is shown }
  procedure AddResult(const Item: string; const Shown: WideString);
  begin
    FSearchView.AddResult(Item, Shown);
  end;

  { Text is editor text of encoding E, its lines are compared and shown in Unicode; a text that
    has the needle nowhere (it has no line break) is not taken apart into lines }
  procedure SearchText(const FileName, Text: string; const E: TSdEncoding);
  var
    L: TStringList;
    K: Integer;
    W, Shown: WideString;
    Named: Boolean;
  begin
    W := EditorToWide(Text, E);
    if not FFindFiles.MatchCase then W := WideLowerCase(W);
    if Pos(Needle, W) = 0 then Exit;
    W := '';
    Named := False;
    L := TStringList.Create;
    try
      L.Text := Text;
      for K := 0 to L.Count - 1 do
        if LineMatches(EditorToWide(L[K], E)) then
        begin
          { the file's real name (a lookup on the disk): once for all its lines }
          if not Named then
          begin
            Shown := DisplayPath(FileName);
            Named := True;
          end;
          AddResult(Format('%s(%d): %s', [FileName, K + 1, EditorToAnsi(Trim(L[K]), E)]),
            Shown + WideString(Format('(%d): ', [K + 1])) + EditorToWide(Trim(L[K]), E));
          Inc(Hits);
        end;
    finally
      L.Free;
    end;
  end;

begin
  InitialFindText(FFindFiles.FindText);
  if (FFindFiles.Directory = '') and (FProject <> nil) then
    FFindFiles.Directory := ExcludeTrailingPathDelimiter(FProject.Dir);
  if not FindInFilesDialog(Self, FFindFiles) then Exit;
  Files := TStringList.Create;
  Unread := TStringList.Create;
  Screen.Cursor := crHourGlass;
  try
    case FFindFiles.Where of
      0: AddProjectFiles(Files);
      1:
        for I := 0 to FPages.Count - 1 do Files.Add(Pages[I].FileName);
      2:
        if DirectoryExists(FFindFiles.Directory) then
          AddDir(WidePath(ExcludeTrailingPathDelimiter(FFindFiles.Directory)));
    end;
    Needle := ToWide(FFindFiles.FindText, CP_ACP);
    if not FFindFiles.MatchCase then Needle := WideLowerCase(Needle);
    FSearchView.BeginResults;
    try
      Hits := 0;
      for I := 0 to Files.Count - 1 do
        try
          { an open file as the editor has it, any other as the editor would open it }
          Text := SourceAndEncoding(Files[I], E);
          SearchText(Files[I], Text, E);
        except
          { a file that is missing or cannot be read (locked, no access) is named, not skipped }
          Unread.Add(Files[I]);
        end;
      for I := 0 to Unread.Count - 1 do
        AddResult(Unread[I] + ': could not be read', DisplayPath(Unread[I]) + ': could not be read');
    finally
      FSearchView.EndResults;
    end;
    Text := Format('%d matches of ''%s'' in %d files.', [Hits, FFindFiles.FindText, Files.Count - Unread.Count]);
    if Unread.Count = 1 then Text := Text + ' 1 file could not be read.'
    else if Unread.Count > 1 then Text := Text + Format(' %d files could not be read.', [Unread.Count]);
    StatusBar.Panels[spMessage].Text := Text;
  finally
    Screen.Cursor := crDefault;
    Unread.Free;
    Files.Free;
  end;
  ShowBottom(BT_SEARCH);
end;

{ ---------------------------------------------------------------- action handlers: file }

{ The file of a new project, asked as Delphi does (Save Project As): the name must be an
  identifier, then the group before is closed - not when the project joins it (Add New Project:
  FNewProjectMode), nor when a new package opens beside it (File | New | Package). }
function TMainForm.AskNewProject(const Kind, Ext: string; var FileName, ProjName: string): Boolean;
begin
  Result := False;
  if Ext = 'dpk' then FileName := 'Package1.dpk' else FileName := 'Project1.dpr';
  if not AskSaveName('New ' + Kind + ' - Save Project As', ProjectFilter(Ext = 'dpk'), Ext, FileName) then Exit;
  ProjName := ChangeFileExt(ExtractFileName(FileName), '');
  if IsUnicodePath(FileName) then
    MessageBox(Handle, 'The folder of a project must have a name Delphi 7 can use (the characters of ' +
      'the system code page, or a drive with short names).', AppTitle, MB_OK or MB_ICONERROR)
  else if not IsValidIdent(ProjName) then
    MessageBox(Handle, 'The project name must be a valid identifier.', AppTitle, MB_OK or MB_ICONERROR)
  else if (FNewProjectMode = omAddToGroup) or OpensBeside(FileName, FNewProjectMode) then
    Result := True
  else
    Result := CloseForProject(FileName, FNewProjectMode);
end;

procedure TMainForm.ActNewApp(Sender: TObject);
var
  FileName, ProjName: string;
  Def: string;
begin
  { the repository's New Project: that project copied }
  Def := RepositoryDefault('DefaultProject');
  if Def <> '' then
  begin
    CopyProjectTemplate(Def);
    Exit;
  end;
  if AskNewProject('Application', 'dpr', FileName, ProjName) then NewApplication(FileName);
end;

{ the template the repository has for Key (DefaultNewForm, DefaultMainForm, DefaultProject): its
  files without extension, '' none (or gone) }
function TMainForm.RepositoryDefault(const Key: string): string;
var
  Repo: TRepository;
  It: TRepoItem;
begin
  Result := '';
  Repo := TRepository.Create;
  try
    Repo.Load;
    It := Repo.Default(Key);
    if (It <> nil) and (FileExistsU(It.Path + '.pas') or FileExistsU(It.Path + '.dpr')) then Result := It.Path;
  finally
    Repo.Free;
  end;
end;

{ File | New | Application at FileName (the project is closed already): the .dpr, a form unit and
  the project's .res; the project is opened }
procedure TMainForm.NewApplication(const FileName: string);
var
  Dir, ProjName, UnitName, FormName, Def, Pas, Dfm, Cls, Src: string;
  E: TSdEncoding;
begin
  Dir := ExtractFilePath(FileName);
  ProjName := ChangeFileExt(ExtractFileName(FileName), '');
  { never over a unit the folder has already (Unit1.pas of another project) }
  UnitName := UniqueUnitName('Unit', Dir);
  FormName := 'Form1';
  { the repository's Main Form: a copy of it is the main form }
  Def := RepositoryDefault('DefaultMainForm');
  if Def <> '' then
  begin
    Pas := ReadSourceFile(Def + '.pas', E);
    FSRenameUnit(Pas, UnitName);
    if not ReadFormHeader(Def + '.dfm', Dfm, FormName, Cls) then Def := '';
  end;
  { the repository's unit: the copy keeps its encoding }
  if Def <> '' then
  begin
    WriteSourceFile(Dir + UnitName + '.pas', Pas, E);
    WriteFileU(Dir + UnitName + '.dfm', Dfm);
  end
  else
  begin
    FormName := 'Form1';
    WriteFileU(Dir + UnitName + '.pas', NewFormUnitSource(UnitName, 'Form1'));
    WriteFileU(Dir + UnitName + '.dfm', FormFileText(NewFormDfm('Form1')));     // New forms as text
  end;
  Src := NewApplicationSource(ProjName, UnitName, FormName);
  { the repository's form keeps its class (not always T + its name) }
  if Def <> '' then DprRenameCreateForm(Src, '', FormName, Cls, FormName);
  WriteFileU(Dir + ProjName + '.dpr', Src);
  NewProjectRes(Dir + ProjName + '.dpr');
  OpenProject(Dir + ProjName + '.dpr', FNewProjectMode);
end;

procedure TMainForm.ActNewConsole(Sender: TObject);
begin
  NewProjectOfKind(npConsole);
end;

{ File | New | Package: a .dpk without units (New Unit, New Form, Add to Project fill its
  contains clause) }
procedure TMainForm.ActNewPackage(Sender: TObject);
begin
  NewProjectOfKind(npPackage);
end;

{ a new project of one file - a console application, a package, a DLL (New Items): its name
  asked as Delphi asks it, the file written, the project opened }
procedure TMainForm.NewProjectOfKind(Kind: TNewProjectKind);
const
  KindNames: array[TNewProjectKind] of string = ('Console Application', 'Package', 'DLL');
  Exts: array[TNewProjectKind] of string = ('dpr', 'dpk', 'dpr');
  DllSource =
    '{ Important note about DLL memory management: ShareMem must be the'#13#10 +
    '  first unit in your library''s USES clause AND your project''s (select'#13#10 +
    '  Project-View Source) USES clause if your DLL exports any procedures or'#13#10 +
    '  functions that pass strings as parameters or function results. This'#13#10 +
    '  applies to all strings passed to and from your DLL--even those that'#13#10 +
    '  are nested in records and classes. ShareMem is the interface unit to'#13#10 +
    '  the BORLNDMM.DLL shared memory manager, which must be deployed along'#13#10 +
    '  with your DLL. To avoid using BORLNDMM.DLL, pass string information'#13#10 +
    '  using PChar or ShortString parameters. }'#13#10#13#10 +
    'uses'#13#10 +
    '  SysUtils,'#13#10 +
    '  Classes;'#13#10#13#10 +
    '{$R *.res}'#13#10#13#10 +
    'begin'#13#10 +
    'end.'#13#10;
var
  FileName, ProjName: string;
begin
  if not AskNewProject(KindNames[Kind], Exts[Kind], FileName, ProjName) then Exit;
  case Kind of
    npConsole:
      begin
        { with its .res, as a new application: the program's manifest goes there }
        WriteFileU(FileName, NewConsoleSource(ProjName, True));
        NewProjectRes(FileName);
      end;
    npPackage: WriteFileU(FileName, NewPackageSource(ProjName));
  else
    WriteFileU(FileName, 'library ' + ProjName + ';'#13#10#13#10 + DllSource);
  end;
  OpenProject(FileName, FNewProjectMode);
end;

procedure TMainForm.ActNewUnit(Sender: TObject);
var
  Name: string;
begin
  Name := UniqueUnitName('Unit');
  NewProjectUnit(Name, NewUnitSource(Name));
end;

{ a new unit: in the project's folder and its uses clause, without a project an untitled page }
{ the bytes of a new file made from IDE text (a name or a text the user typed in it): the system
  code page, as every new file; a character that code page lacks keeps the text UTF-8 }
function NewFileBytes(const Text: string): string;
var
  Lost: Boolean;
begin
  Result := IdeToSystem(Text, Lost);
  if Lost then Result := Text;
end;
procedure TMainForm.NewProjectUnit(const Name, Source: string);
var
  FileName, Src: string;
begin
  if FProject <> nil then
  begin
    FileName := FProject.Dir + Name + '.pas';
    WriteFileU(FileName, NewFileBytes(Source));
    Src := ProjectSource;
    DprAddUnit(Src, Name, Name + '.pas', '');
    ProjectSourceChanged(Src);
    OpenFile(FileName, True);
  end
  else
    NewUntitledPage(Name + '.pas', Source);
end;

procedure TMainForm.NewUntitledPage(const Name, Text: string; const Dfm: string; Named: Boolean);
var
  P: TEditorPage;
begin
  P := TEditorPage.Create(Self);
  AddPageTab(P);
  P.NewFile(Name, Text, Dfm, Named);
  AddDoc(P);
  ActivatePage(P);
end;

{ File | New | Other: Delphi's New Items }
procedure TMainForm.NewItems;
var
  It: TNewItem;
  Mode: TNewItemMode;
  Cls, TName, N, Dfm: string;
  Forms: TStringList;
  I: Integer;
begin
  { the project's page: its forms (name, class, unit) }
  Forms := TStringList.Create;
  try
    if FProject <> nil then
      for I := 0 to FProject.UnitCount - 1 do
        if ReadFormHeader(ChangeFileExt(FProject.Units[I].FileName, '.dfm'), Dfm, N, Cls) and (Cls <> '') then
          Forms.Add(N + '|' + Cls + '|' + ChangeFileExt(FProject.Units[I].FileName, ''));
    if FProject <> nil then N := FProject.Name else N := '';
    if not TNewItemsDlg.Execute(Self, N, Forms, It, Mode) then Exit;
  finally
    Forms.Free;
  end;
  try
    if (It.Kind in [nkDataModule, nkForm, nkFrame, nkFormTemplate, nkProjectForm]) and (FProject = nil) then
    begin
      MessageBox(Handle, PChar(It.Name + ' needs a project: open or create one first.'), 'New Items',
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    case It.Kind of
      nkWizard: OtaExecuteWizard(It.Wizard);       // an expert's repository wizard
      nkApplication: ActNewApp(FileNewVclApplicationCommand);
      nkConsole: ActNewConsole(aNewConsole);
      nkPackage: ActNewPackage(aNewPackage);
      nkDataModule: ActNewForm(FileNewVclDataModuleCommand);
      nkForm: ActNewForm(FileNewVclFormCommand);
      nkFrame: ActNewForm(FileNewVclFrameCommand);
      nkUnit: ActNewUnit(FileNewUnitCommand);
      nkComponent: NewComponent;
      nkDll: NewProjectOfKind(npDll);
      nkText: NewUntitledPage(UniqueUnitName('File', '', '.txt') + '.txt', '');
      nkBatchFile: NewUntitledPage(UniqueUnitName('Batch', '', '.bat') + '.bat', '');
      nkThread:
        if TNewThreadDlg.Execute(Self, Cls, TName) then
        begin
          N := UniqueUnitName('Unit');
          NewProjectUnit(N, NewThreadSource(N, Cls, TName));
        end;
      nkFormTemplate:
        if Mode = nmInherit then
        begin
          { the template's class, from its form }
          if ReadFormHeader(It.Path + '.dfm', Dfm, N, Cls) then AddInheritedForm(It.Path, Cls);
        end
        else
          AddFormTemplate(It.Path, Mode = nmUse);
      nkProjectForm: AddInheritedForm(It.Path, It.FormClass);
      nkProjectTemplate: CopyProjectTemplate(It.Path);
    end;
  finally
    It.Free;
  end;
end;

{ a form of the repository: Copy - its unit and form under a new unit name in the project's
  folder, the form under a free name when the project has its name already (Form1 -> Form4, its
  class T + the name, as Delphi does); Use - the repository's own files in the project (changes
  go to the repository) }
procedure TMainForm.AddFormTemplate(const Path: string; Use: Boolean);
var
  Src, Pas, Dfm, Text, N, C, NewN, NewC, UnitName, FileName, Rel: string;
  I: Integer;
  E: TSdEncoding;
begin
  if not FileExists(Path + '.pas') then Exit;
  Dfm := '';
  if FileExists(Path + '.dfm') then Dfm := ReadFileU(Path + '.dfm');
  DfmTextAndHeader(Dfm, Text, N, C);
  if Use then
  begin
    UnitName := ChangeFileExt(ExtractFileName(Path), '');
    FileName := Path + '.pas';
  end
  else
  begin
    UnitName := UniqueUnitName('Unit');
    FileName := FProject.Dir + UnitName + '.pas';
    Pas := ReadSourceFile(Path + '.pas', E);
    FSRenameUnit(Pas, UnitName);
    if (N <> '') and RootNameUsed(N) then
    begin
      I := Length(N);
      while (I > 1) and (N[I] in ['0'..'9']) do Dec(I);
      NewN := UniqueRootName(Copy(N, 1, I));
      NewC := 'T' + NewN;
      FSRenameClass(Pas, C, NewC);
      FSRenameFormVar(Pas, NewC, N, NewN);
      if DfmIsBinary(Dfm) then Dfm := DfmTextToBinary(DfmRenameRoot(Text, NewN, NewC))
      else Dfm := DfmRenameRoot(Text, NewN, NewC);
      N := NewN;
      C := NewC;
    end;
    WriteSourceFile(FileName, Pas, E);      // the copy keeps the encoding of the repository's unit
    if Dfm <> '' then WriteFileU(ChangeFileExt(FileName, '.dfm'), Dfm);
  end;
  Src := ProjectSource;
  if ProjectSourceName(FProject, FileName, Rel) then
  begin
    DprAddUnit(Src, UnitName, Rel, N);
    if (N <> '') and EnvOptions.AutoCreateForms then DprAddCreateForm(Src, C, N);
    ProjectSourceChanged(Src);
  end;
  OpenFile(FileName, True);
end;

{ a project of the repository: its folder copied to one the user chooses, then opened }
procedure TMainForm.CopyProjectTemplate(const Path: string);
var
  Dir, Src, Failed: string;
  SR: TSearchRec;
  Names, There: TStringList;
  I: Integer;
begin
  Dir := '';
  if not SelectDirectory('Select Directory', '', Dir) then Exit;
  Dir := IncludeTrailingPathDelimiter(Dir);
  Src := ExtractFilePath(Path);
  Names := TStringList.Create;
  There := TStringList.Create;
  try
    if FindFirst(Src + '*.*', faAnyFile and not faDirectory, SR) = 0 then
    begin
      repeat
        Names.Add(SR.Name);
        if FileExists(Dir + SR.Name) then There.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    { files of the template the folder has already: asked (No copies nothing - the old project
      would open as if it were the new one) }
    if (There.Count > 0) and (MessageBox(Handle, PChar(Format('%s has these files of the template already:'#13#10'%s'#13#10 +
      'Overwrite them?', [Dir, There.Text])), 'Confirm', MB_YESNO or MB_ICONWARNING) <> IDYES) then Exit;
    Failed := '';
    for I := 0 to Names.Count - 1 do
      if not CopyFile(PChar(Src + Names[I]), PChar(Dir + Names[I]), False) then
        Failed := Failed + #13#10 + Names[I] + ': ' + SysErrorMessage(GetLastError);
    if Failed <> '' then
    begin
      MessageBox(Handle, PChar('These files of the template could not be copied:' + Failed), AppTitle,
        MB_OK or MB_ICONERROR);
      Exit;
    end;
  finally
    There.Free;
    Names.Free;
  end;
  if FileExists(Dir + ExtractFileName(Path) + '.dpr') then OpenProject(Dir + ExtractFileName(Path) + '.dpr', FNewProjectMode);
end;

{ the .dfm of a new form, data module or frame: text, or binary when Environment Options |
  Designer | New forms as text is off }
function FormFileText(const Dfm: string): string;
begin
  if EnvOptions.NewFormsAsText then Result := Dfm else Result := DfmTextToBinary(Dfm);
end;

{ Add to Repository: a form of the project (the designer's menu: the active page's form chosen
  in the dialog's list) or the project (Project | Add to Repository) - an item of the repository
  that names its files where they are (saved first) }
procedure TMainForm.AddToRepository(Project: Boolean);
var
  Repo: TRepository;
  Item: TRepoItem;
  Info: TRepoInfo;
  Forms, Paths: TStringList;
  Idx, I: Integer;
  Path, N, C, Dfm: string;
  P: TEditorPage;
begin
  if FProject = nil then Exit;
  Repo := TRepository.Create;
  Forms := TStringList.Create;
  Paths := TStringList.Create;
  try
    Repo.Load;
    Info.Title := '';
    Info.Description := '';
    Info.Author := '';
    Info.Icon := '';
    Idx := -1;
    P := ActivePage;
    if Project then
    begin
      Info.Page := 'Projects';
      if not AddRepositoryDialog(Self, '', nil, Repo.Pages, Idx, Info) or not SaveAllPages then Exit;
      Path := ChangeFileExt(FProject.FileName, '');
    end
    else
    begin
      for I := 0 to FProject.UnitCount - 1 do
      begin
        if not ReadFormHeader(ChangeFileExt(FProject.Units[I].FileName, '.dfm'), Dfm, N, C) then Continue;
        if (P <> nil) and SameText(P.FileName, FProject.Units[I].FileName) then Idx := Forms.Count;
        Forms.Add(N);
        Paths.Add(ChangeFileExt(FProject.Units[I].FileName, ''));
      end;
      Info.Page := 'Forms';
      if not AddRepositoryDialog(Self, '', Forms, Repo.Pages, Idx, Info) or (Idx < 0) then Exit;
      Path := Paths[Idx];
      for I := 0 to FPages.Count - 1 do
        if SameText(ChangeFileExt(Pages[I].FileName, ''), Path) and Pages[I].Modified and not SavePage(Pages[I]) then Exit;
    end;
    Item := Repo.Add(Path, Project);
    Item.Values['Name'] := Info.Title;
    Item.Values['Page'] := Info.Page;
    Item.Values['Icon'] := Info.Icon;
    Item.Values['Description'] := Info.Description;
    Item.Values['Author'] := Info.Author;
    if Project then
      Item.Flags['DefaultProject'] := Item.Flags['DefaultProject']
    else
    begin
      Item.Flags['DefaultMainForm'] := Item.Flags['DefaultMainForm'];
      Item.Flags['DefaultNewForm'] := Item.Flags['DefaultNewForm'];
    end;
    if Repo.Pages.IndexOf(Info.Page) < 0 then Repo.Pages.Add(Info.Page);
    Repo.Save;
  finally
    Paths.Free;
    Forms.Free;
    Repo.Free;
  end;
end;

{ Tools | Repository: Delphi's dialog on a copy, kept with OK }
procedure TMainForm.EditRepository;
var
  Repo: TRepository;
begin
  Repo := TRepository.Create;
  try
    Repo.Load;
    if RepositoryDialog(Self, Repo) then Repo.Save;
  finally
    Repo.Free;
  end;
end;

{ the component templates onto the palette (the Components view) }
procedure TMainForm.LoadCompTemplates;
var
  T: TCompTemplates;
  I: Integer;
begin
  if DesignHost = nil then Exit;
  DesignHost.ClearTemplates;
  T := TCompTemplates.Create;
  try
    T.Load;
    for I := 0 to T.Count - 1 do
      DesignHost.AddTemplate(T[I].Name, T[I].Page, DesignHost.FindComponentClass(T[I].ClassName), T[I].Text,
        T[I].IconFile);
  finally
    T.Free;
  end;
  DesignHost.TemplatesChanged;
end;

{ Component | Create Component Template: the selected components (with what they contain) as a
  template - Delphi's dialog: its name, its page, its icon }
procedure TMainForm.CreateCompTemplate;
var
  D: TFormDesigner;
  Text, Name, Page, Icon, Cls: string;
  T: TCompTemplates;
  Tpl: TCompTemplate;
  Pages: TStringList;
  I: Integer;
begin
  D := ActiveDesigner;
  if (D = nil) or (D.SelectionCount = 0) or (D.Selections[0] = D.Root) then Exit;
  Text := D.SelectionText;
  if Text = '' then Exit;
  Cls := D.Selections[0].ClassName;
  Name := Cls + 'Template';
  Page := 'Templates';
  Icon := '';
  Pages := TStringList.Create;
  T := TCompTemplates.Create;
  try
    for I := 0 to DesignHost.PageCount - 1 do Pages.Add(DesignHost.Pages[I].Name);
    if Pages.IndexOf(Page) < 0 then Pages.Add(Page);
    if not CompTemplateDialog(Self, Pages, DesignHost.ComponentBitmap(D.Selections[0].ClassType), Name, Page, Icon) then Exit;
    T.Load;
    Tpl := T.Add(Name);
    Tpl.Page := Page;
    Tpl.ClassName := Cls;
    Tpl.IconFile := Icon;
    Tpl.Text := MakeTemplateText(Text);
    T.Save;
  finally
    T.Free;
    Pages.Free;
  end;
  LoadCompTemplates;
end;

{ File | New | Other: a form inherited from another (the project's, or one of the repository's
  - its unit then joins the project): its unit derives the class, its .dfm says what it changes }
{ a new unit and its form file in the project's folder, into the project (Src: the project's
  source, Comment: its uses entry's comment; the form auto-created when CanCreate and Environment
  Options say so), shown in the designer }
procedure TMainForm.AddFormUnit(Src: string; const UnitName, RootName, Code, Dfm, Comment: string;
  CanCreate: Boolean);
var
  FileName: string;
begin
  FileName := FProject.Dir + UnitName + '.pas';
  WriteFileU(FileName, Code);
  WriteFileU(ChangeFileExt(FileName, '.dfm'), FormFileText(Dfm));
  DprAddUnit(Src, UnitName, UnitName + '.pas', Comment);
  if CanCreate and EnvOptions.AutoCreateForms then DprAddCreateForm(Src, 'T' + RootName, RootName);
  ProjectSourceChanged(Src);
  OpenFileView(FileName, True, True);
end;
procedure TMainForm.AddInheritedForm(const AncestorFile, AncestorClass: string);
var
  UnitName, RootName, Src, AncUnit, Rel: string;
begin
  if FProject = nil then Exit;
  { the ancestor's unit goes into the project first: a source that cannot name it gets no form }
  if not ProjectSourceName(FProject, ChangeFileExt(AncestorFile, '.pas'), Rel) then Exit;
  Src := ProjectSource;
  AncUnit := ChangeFileExt(ExtractFileName(AncestorFile), '');
  DprAddUnit(Src, AncUnit, Rel, '');
  UnitName := UniqueUnitName('Unit');
  RootName := UniqueRootName('Form');
  AddFormUnit(Src, UnitName, RootName, NewFormUnitSource(UnitName, RootName, AncestorClass, AncUnit),
    NewInheritedFormDfm(RootName), RootName, True);
end;

procedure TMainForm.ActNewForm(Sender: TObject);
var
  UnitName, RootName, Src, Code, Dfm, Comment, Def: string;
begin
  { a form, a data module or a frame: a unit with a .dfm, added to the project }
  if FProject = nil then Exit;
  { the repository's New Form: a copy of it }
  if Sender = FileNewVclFormCommand then
  begin
    Def := RepositoryDefault('DefaultNewForm');
    if Def <> '' then
    begin
      AddFormTemplate(Def, False);
      Exit;
    end;
  end;
  UnitName := UniqueUnitName('Unit');
  Src := ProjectSource;
  { the .dpr's comment names a data module's and a frame's type; a frame is never auto-created }
  if Sender = FileNewVclDataModuleCommand then
  begin
    RootName := UniqueRootName('DataModule');
    Code := NewDataModuleSource(UnitName, RootName);
    Dfm := NewDataModuleDfm(RootName);
    Comment := RootName + ': TDataModule';
  end
  else if Sender = FileNewVclFrameCommand then
  begin
    RootName := UniqueRootName('Frame');
    Code := NewFrameSource(UnitName, RootName);
    Dfm := NewFrameDfm(RootName);
    Comment := RootName + ': TFrame';
  end
  else
  begin
    RootName := UniqueRootName('Form');
    Code := NewFormUnitSource(UnitName, RootName);
    Dfm := NewFormDfm(RootName);
    Comment := RootName;
  end;
  AddFormUnit(Src, UnitName, RootName, Code, Dfm, Comment, Sender <> FileNewVclFrameCommand);
end;

procedure TMainForm.ActOpen(Sender: TObject);
var
  Files: TStringList;
  I: Integer;
begin
  Files := TStringList.Create;
  try
    if BrowseFiles('', 'Delphi files (*.pas;*.dpr;*.dpk;*.inc;*.dfm)|*.pas;*.dpr;*.dpk;*.inc;*.dfm|' +
      'Delphi projects (*.dpr;*.dpk;*.bpg)|*.dpr;*.dpk;*.bpg|Delphi units (*.pas)|*.pas|Any file (*.*)|*.*', Files) then
      for I := 0 to Files.Count - 1 do OpenAny(Files[I]);
  finally
    Files.Free;
  end;
end;

procedure TMainForm.ActOpenProject(Sender: TObject);
var
  F: string;
begin
  if AskProjectFile(True, F) then OpenProject(F);
end;

procedure TMainForm.ActSave(Sender: TObject);
begin
  if ActiveDoc <> nil then SaveDoc(ActiveDoc);
end;

{ every project of the group whose unit the page is (a unit of two projects: both) follows: the
  unit's entry in its uses clause under the new name and path. Write: Save As; else the page and
  the projects' sources are renamed unsaved (Delphi 7's IOTAModule.FileName) }
function TMainForm.RenamePage(P: TEditorPage; const FileName: string; Write: Boolean): Boolean;
var
  Src, Rel, Full: string;
  U: TProjectUnit;
  L, Owners: TList;
  Names, Rels: TStringList;
  I: Integer;
  Prj: TSdProject;
begin
  Result := False;
  Full := ExpandPathU(FileName);
  L := TList.Create;
  Owners := TList.Create;
  Names := TStringList.Create;
  Rels := TStringList.Create;
  try
    FGroup.OwnersOf(P.FileName, L);
    for I := 0 to L.Count - 1 do
    begin
      Prj := TSdProject(L[I]);
      U := Prj.FindUnit(P.FileName);
      if U = nil then Continue;
      { the new name as each project source writes it: one that cannot name it saves nothing }
      if not ProjectSourceName(Prj, Full, Rel) then Exit;
      Owners.Add(Prj);
      Names.Add(U.Name);
      Rels.Add(Rel);
    end;
    if Write then Result := SavePageAs(P, FileName)
    else
    begin
      RenamePageOnly(P, FileName);
      Result := True;
    end;
    if not Result then Exit;
    UpdatePageTab(P);
    for I := 0 to Owners.Count - 1 do
    begin
      Prj := TSdProject(Owners[I]);
      Src := SourceOf(Prj.FileName);
      DprRenameUnit(Src, Names[I], P.UnitName, Rels[I]);
      SetProjectSourceOf(Prj, Src);
    end;
    if Owners.Count > 0 then
    begin
      RefreshProjectTree;
      ConfigureCodeInsight;
    end;
  finally
    Rels.Free;
    Names.Free;
    Owners.Free;
    L.Free;
  end;
end;

function TMainForm.SaveDocAs(P: TEditorPage): Boolean;
var
  FileName: string;
begin
  FileName := P.FileName;
  Result := AskSaveName('', UnitFilter, Copy(ExtractFileExt(P.FileName), 2, MaxInt), FileName) and
    RenamePage(P, FileName, True);
end;

procedure TMainForm.ActSaveAs(Sender: TObject);
begin
  if ActivePage <> nil then SaveDocAs(ActivePage);
end;

procedure TMainForm.ActSaveAll(Sender: TObject);
begin
  SaveAllFiles;
end;

{ File | Save All (Delphi's Modules.SaveModifiedModules): every modified page, the active
  project's options (the other projects' are written whenever they change), and the project group
  when it has more than one project and changed - a group without a file asks for its name }
function TMainForm.SaveAllFiles: Boolean;
begin
  FlushOtaOptions;
  Result := SaveAllPages;
  if FProject <> nil then FProject.SaveOptions;
  if (FGroup.Count > 1) and FGroup.Modified and not SaveGroup(FGroup.FileName = '') then Result := False;
end;

procedure TMainForm.ActClose(Sender: TObject);
begin
  if ActiveDoc <> nil then CloseDoc(ActiveDoc, True);
end;

function TMainForm.CloseAllFiles: Boolean;
begin
  if FGroup.AllCount > 0 then
  begin
    { the group with its projects, the packages beside it and every file }
    Result := ConfirmSaveGroup and CloseGroup;
    if Result then RefreshProjectTree;
  end
  else
    Result := CloseAllDocs(True);
end;

procedure TMainForm.ActCloseAll(Sender: TObject);
begin
  CloseAllFiles;
end;

procedure TMainForm.ActExit(Sender: TObject);
begin
  Close;
end;

{ ---------------------------------------------------------------- action handlers: edit / design }

{ True when Wnd is Ctl's window or one of its child windows }
function WindowIn(Ctl: TWinControl; Wnd: HWND): Boolean;
begin
  Result := (Ctl <> nil) and Ctl.HandleAllocated and ((Wnd = Ctl.Handle) or IsChild(Ctl.Handle, Wnd));
end;

procedure TMainForm.ActEdit(Sender: TObject);
var
  Ed: TSciEdit;
  D: TFormDesigner;
  P: TEditorPage;
  R: TSdResPage;
  A: TCustomAction;
  Focus, Child: HWND;
  IsEdit: Boolean;
begin
  P := ActivePage;
  Ed := ActiveEditor;
  D := ActiveDesigner;
  { The edit commands' keys are shortcuts of the main form and arrive whatever has the keyboard
    (a floating group's window too). They act on the editor or the designer when the keyboard
    is in the active page - or in the Object TreeView showing its designer, as in Delphi's Object
    TreeView; any other window gets the command as its own message (an inspector or dialog
    edit, the edit of a view's combo box), a window that has no such command ignores it. }
  Focus := Windows.GetFocus;
  if (Focus = 0) and (Screen.ActiveControl <> nil) and Screen.ActiveControl.HandleAllocated then
    Focus := Screen.ActiveControl.Handle;
  { a resource page: its editor's command of the same name (an edit box of the page - the find
    box, a cell's edit - has none: it gets the command as its own message, below) }
  R := ActiveResPage;
  if (R <> nil) and ((Focus = 0) or (Focus = Handle) or WindowIn(R, Focus)) then
  begin
    A := R.EditAction(TComponent(Sender).Name);
    if A <> nil then
    begin
      A.Execute;
      Exit;
    end;
  end;
  { (the page's code is in the file area's window, which lies over the page) }
  if (Focus <> 0) and (Focus <> Handle) and not WindowIn(P, Focus) and not WindowIn(FEditWindow, Focus) and
    not (WindowIn(FObjTree, Focus) and (D <> nil) and (FObjTree.Designer = D)) then
  begin
    IsEdit := SendMessage(Focus, WM_GETDLGCODE, 0, 0) and DLGC_HASSETSEL <> 0;
    if not IsEdit then
    begin
      Child := FindWindowEx(Focus, 0, 'Edit', nil);      // a combo box: its edit
      if Child <> 0 then
      begin
        Focus := Child;
        IsEdit := True;
      end;
    end;
    if Sender = EditCutCommand then SendMessage(Focus, WM_CUT, 0, 0)
    else if Sender = EditCopyCommand then SendMessage(Focus, WM_COPY, 0, 0)
    else if Sender = EditPasteCommand then SendMessage(Focus, WM_PASTE, 0, 0)
    else if Sender = EditDeleteCommand then SendMessage(Focus, WM_CLEAR, 0, 0)
    else if IsEdit and (Sender = EditSelectAllCommand) then SendMessage(Focus, EM_SETSEL, 0, -1)
    else if IsEdit and (Sender = EditUndoCommand) then SendMessage(Focus, EM_UNDO, 0, 0);
    Exit;
  end;
  if Ed <> nil then
  begin
    if Sender = EditUndoCommand then Ed.Undo
    else if Sender = EditRedoCommand then Ed.Redo
    else if Sender = EditCutCommand then Ed.Cut
    else if Sender = EditCopyCommand then Ed.Copy
    else if Sender = EditPasteCommand then Ed.Paste
    else if Sender = EditDeleteCommand then Ed.ReplaceSel('')
    else if Sender = EditSelectAllCommand then Ed.SelectAll
    else if Sender = aToggleComment then Ed.ToggleComment
    else if Sender = aIndent then Ed.IndentSelection(False)
    else if Sender = aUnindent then Ed.IndentSelection(True);
  end
  else if D <> nil then
  begin
    if Sender = EditUndoCommand then ActivePage.DesignUndo
    else if Sender = EditRedoCommand then ActivePage.DesignRedo
    else if Sender = EditCutCommand then D.CutSelected
    else if Sender = EditCopyCommand then D.CopySelected
    else if Sender = EditPasteCommand then D.PasteFromClipboard
    else if Sender = EditDeleteCommand then D.DeleteSelected
    else if Sender = EditSelectAllCommand then D.SelectAll;
  end;
end;

{ the editor's own commands: lines, carets, the selection, folding }
procedure TMainForm.ActEditor(Sender: TObject);
var
  Ed: TSciEdit;
  FA: TSciFoldAction;
begin
  Ed := ActiveEditor;
  if Ed = nil then Exit;
  if Sender = aDuplicateLine then Ed.DuplicateSelection
  else if Sender = aMoveLinesUp then Ed.MoveLines(True)
  else if Sender = aMoveLinesDown then Ed.MoveLines(False)
  else if Sender = aJoinLines then Ed.JoinLines
  else if Sender = aSelectNextOccurrence then Ed.SelectNextOccurrence
  else if Sender = aSelectAllOccurrences then Ed.SelectAllOccurrences
  else if Sender = aAddCaretAbove then Ed.AddCaret(False)
  else if Sender = aAddCaretBelow then Ed.AddCaret(True)
  else if Sender = aExpandSelection then Ed.ExpandSelection
  else if Sender = aShrinkSelection then Ed.ShrinkSelection
  else
    for FA := Low(TSciFoldAction) to High(TSciFoldAction) do
      if Sender = FoldAction(FA) then Ed.Fold(FA);
end;

{ the action of a folding command (Edit | Folding) }
function TMainForm.FoldAction(FA: TSciFoldAction): TAction;
begin
  case FA of
    sfFoldAll: Result := aFoldAll;
    sfUnfoldAll: Result := aUnfoldAll;
    sfFold: Result := aFold;
    sfUnfold: Result := aUnfold;
    sfToggle: Result := aFoldToggle;
    sfFoldMethods: Result := aFoldMethods;
    sfFoldClasses: Result := aFoldClasses;
    sfFoldSections: Result := aFoldSections;
    sfFoldUnit: Result := aFoldUnit;
    sfFoldNested: Result := aFoldNested;
  else
    Result := aFoldRegions;
  end;
end;

{ Edit | Folding | Code Folding: Editor Options' Code folding on or off, kept in the settings and
  applied to every editor (off: everything folded is shown) }
procedure TMainForm.ActCodeFolding(Sender: TObject);
begin
  EditorOptions.ShowFolding := not EditorOptions.ShowFolding;
  SaveEditorOptions(Settings);
  SaveSettings;
  ApplyEditorOptions;
end;

{ View | Zoom and the zoom bar's buttons: the zoom of the view shown (SdZoom) - the editors' (one for
  every editor), the designer's, the diagram's, a resource editor's }
procedure TMainForm.ActZoom(Sender: TObject);
var
  V: ISdZoomView;
begin
  V := DocZoomView(ActiveDoc);
  if V = nil then Exit;
  if Sender = aZoomIn then V.ZoomStep(1, False, Point(0, 0))
  else if Sender = aZoomOut then V.ZoomStep(-1, False, Point(0, 0))
  else if Sender = aZoomFit then V.ZoomFit
  else V.ZoomTo(100);
  UpdateStatus;
end;

procedure TMainForm.ApplyZoom;
begin
  SciApplyZoom;
  UpdateStatus;
end;

procedure TMainForm.ActDesign(Sender: TObject);
var
  D: TFormDesigner;
begin
  D := ActiveDesigner;
  if D = nil then Exit;
  if Sender = EditAlignGridCommand then D.AlignSelectedToGrid
  else if Sender = EditFrontCommand then D.BringSelectedToFront
  else if Sender = EditBackCommand then D.SendSelectedToBack
  else if Sender = EditLockControlsCommand then D.Locked := not D.Locked
  else if (Sender = EditFlipChildrenAllCommand) or (Sender = EditFlipChildrenSelectedCommand) then FlipDesignChildren(D, Sender = EditFlipChildrenAllCommand)
  else if Sender = EditAlignCommand then AlignSelection(D)
  else if Sender = EditSizeCommand then SizeSelection(D)
  else if Sender = EditScaleCommand then ScaleRoot(D)
  else if Sender = EditTabOrderCommand then EditTabOrder(D)
  else if Sender = EditCreationOrderCommand then EditCreationOrder(D);
end;

{ View as Text / View as Form (Alt+F12, Delphi's): the form of the unit being designed as its
  .dfm text in a page of its own (its designer goes); from that page back into the form - also
  when the page is closed. The experts are told as Delphi 7 tells them (measured): the text opens
  as a module of its own and the unit's module closes; back, the unit's module opens and the
  text's closes }
procedure TMainForm.ActFormText(Sender: TObject);
var
  P, T: TEditorPage;
begin
  P := ActivePage;
  if P = nil then Exit;
  if P.FormOwner <> nil then
  begin
    T := P;
    P := T.FormOwner;
    if not OtaFileNotification(ofnFileOpening, P.FileName) then Exit;
    if not T.ApplyFormText then Exit;
    OtaFileNotification(ofnFileOpened, P.FileName);
    OtaFileNotification(ofnFileClosing, T.FileName);
    { the form comes up in its design view, made while it is hidden, over the text, which goes
      then (SwapPage; shown in the code view and switched, the code showed first) }
    P.ShowDesign(True, False);
    SwapPage(P, T);
    ActivatePage(P);
    P.ShowDesign(True);                  // the designer takes the focus
    UpdatePageTab(P);
    OtaModules.PageOpened(P);
  end
  else if P.DesignView and P.HasForm then
  begin
    if not OtaFileNotification(ofnFileOpening, P.FormFileName) then Exit;
    ForgetDesigner(P);                   // DropDesigner frees the designer
    T := TEditorPage.Create(Self);
    AddPageTab(T);
    T.ShowFormText(P);
    AddDoc(T);
    { the text comes up over the form before the designer goes and the unit shows its code }
    SwapPage(T, nil);
    P.DropDesigner;
    ActivatePage(T);
    OtaFileNotification(ofnFileOpened, T.FileName);
    OtaModules.PageOpened(T);
    OtaFileNotification(ofnFileClosing, P.FileName);
    OtaModules.ModuleClosed(P.FileName);
  end;
end;

{ the designer's page bar: Delphi's ten alignments of the selected controls (TFormDesigner.
  AlignSelected); the edges and centers need two controls, spacing three, centering one. False
  for an action that is none of the ten }
function TMainForm.AlignActionKind(A: TObject; out Kind: TAlignKind; out Need: Integer): Boolean;
begin
  Result := True;
  if A = aAlignLeftEdges then Kind := akLeftEdges
  else if A = aAlignHCenters then Kind := akHCenters
  else if A = aAlignHWinCenter then Kind := akCenterInWindowH
  else if A = aAlignHSpace then Kind := akSpaceEquallyH
  else if A = aAlignRightEdges then Kind := akRightEdges
  else if A = aAlignTops then Kind := akTopEdges
  else if A = aAlignVCenters then Kind := akVCenters
  else if A = aAlignVWinCenter then Kind := akCenterInWindowV
  else if A = aAlignVSpace then Kind := akSpaceEquallyV
  else if A = aAlignBottoms then Kind := akBottomEdges
  else
  begin
    Kind := akLeftEdges;
    Need := 0;
    Result := False;
    Exit;
  end;
  case Kind of
    akCenterInWindowH, akCenterInWindowV: Need := 1;
    akSpaceEquallyH, akSpaceEquallyV: Need := 3;
  else
    Need := 2;
  end;
end;

procedure TMainForm.ActAlign(Sender: TObject);
var
  Kind: TAlignKind;
  Need: Integer;
begin
  if AlignActionKind(Sender, Kind, Need) and (ActiveDesigner <> nil) then
    ActiveDesigner.AlignSelected(Kind);
end;

{ Edit | Align: Delphi's Alignment dialog on the designer's alignments }
procedure TMainForm.AlignSelection(D: TFormDesigner);
const
  HKinds: array[1..5] of TAlignKind = (akLeftEdges, akHCenters, akRightEdges, akSpaceEquallyH, akCenterInWindowH);
  VKinds: array[1..5] of TAlignKind = (akTopEdges, akVCenters, akBottomEdges, akSpaceEquallyV, akCenterInWindowV);
var
  H, V: Integer;
begin
  H := 0;
  V := 0;
  if not AlignDialog(Self, H, V) then Exit;
  if H > 0 then D.AlignSelected(HKinds[H]);
  if V > 0 then D.AlignSelected(VKinds[V]);
end;

{ the selected controls of the designer (not the form itself) }
procedure SelectedControls(D: TFormDesigner; L: TList);
var
  I: Integer;
begin
  for I := 0 to D.SelectionCount - 1 do
    if (D.Selections[I] is TControl) and (D.Selections[I] <> D.Root) then L.Add(D.Selections[I]);
end;

{ Edit | Size: the width and height of the selected controls }
procedure TMainForm.SizeSelection(D: TFormDesigner);
var
  L: TList;
  I, HMode, VMode, W, H, MinW, MaxW, MinH, MaxH: Integer;
  C: TControl;
begin
  L := TList.Create;
  try
    SelectedControls(D, L);
    if L.Count = 0 then Exit;
    C := TControl(L[0]);
    W := C.Width;
    H := C.Height;
    HMode := 0;
    VMode := 0;
    if not SizeDialog(Self, HMode, VMode, W, H) then Exit;
    MinW := MaxInt; MaxW := 0; MinH := MaxInt; MaxH := 0;
    for I := 0 to L.Count - 1 do
    begin
      C := TControl(L[I]);
      if C.Width < MinW then MinW := C.Width;
      if C.Width > MaxW then MaxW := C.Width;
      if C.Height < MinH then MinH := C.Height;
      if C.Height > MaxH then MaxH := C.Height;
    end;
    for I := 0 to L.Count - 1 do
    begin
      C := TControl(L[I]);
      case HMode of
        1: C.Width := MinW;
        2: C.Width := MaxW;
        3: C.Width := W;
      end;
      case VMode of
        1: C.Height := MinH;
        2: C.Height := MaxH;
        3: C.Height := H;
      end;
    end;
  finally
    L.Free;
  end;
  D.Modified;
  D.UpdateHelpers;
end;

{ Edit | Scale: the form and everything on it, in percent }
procedure TMainForm.ScaleRoot(D: TFormDesigner);
var
  N: Integer;
begin
  if not (D.Root is TWinControl) then Exit;
  N := 100;
  if not ScaleDialog(Self, N) or (N = 100) then Exit;
  TWinControl(D.Root).ScaleBy(N, 100);
  D.Modified;
  D.UpdateHelpers;
end;

{ Edit | Tab Order: the windowed controls of the parent of the selection (of the form when the
  form is selected), in tab order - a placed frame's own as well (a change of TabOrder) }
procedure TMainForm.EditTabOrder(D: TFormDesigner);
var
  P: TWinControl;
  L: TStringList;
  I, J: Integer;
  C: TWinControl;
begin
  if not (D.Root is TWinControl) then Exit;
  P := TWinControl(D.Root);
  if (D.SelectionCount = 1) and (D.Selections[0] is TControl) and (D.Selections[0] <> D.Root) then
    P := TControl(D.Selections[0]).Parent;
  if P = nil then Exit;
  L := TStringList.Create;
  try
    for I := 0 to P.ControlCount - 1 do
      if (P.Controls[I] is TWinControl) and D.IsDesigned(P.Controls[I]) then
      begin
        C := TWinControl(P.Controls[I]);
        J := 0;
        while (J < L.Count) and (TWinControl(L.Objects[J]).TabOrder < C.TabOrder) do Inc(J);
        L.InsertObject(J, C.Name + ': ' + C.ClassName, C);
      end;
    if L.Count = 0 then Exit;
    if not TabOrderDialog(Self, L) then Exit;
    for I := 0 to L.Count - 1 do TWinControl(L.Objects[I]).TabOrder := I;
  finally
    L.Free;
  end;
  D.Modified;
end;

{ Edit | Creation Order: the non-visual components of the form in the order they are created;
  they are moved to the end of the form's components in the new order (a form writes its
  non-visual components before its controls, so nothing else changes) }
procedure TMainForm.EditCreationOrder(D: TFormDesigner);
var
  L: TStringList;
  I: Integer;
  C: TComponent;
begin
  L := TStringList.Create;
  try
    for I := 0 to D.Root.ComponentCount - 1 do
    begin
      C := D.Root.Components[I];
      if not (C is TControl) then L.AddObject(C.Name + ': ' + C.ClassName, C);
    end;
    if L.Count = 0 then Exit;
    if not TabOrderDialog(Self, L, True) then Exit;
    for I := 0 to L.Count - 1 do TComponent(L.Objects[I]).ComponentIndex := D.Root.ComponentCount - 1;
  finally
    L.Free;
  end;
  D.Modified;
end;

type
  { a closed file's text as the To-Do List read it (TMainForm.TodoSource), and the file's stamp
    then (SdFileNames): while the stamp is the same, the text is the same }
  TTodoText = class
    Stamp: TSdFileStamp;
    Text: string;
  end;

{ View | To-Do List: the TODO and DONE comments of the project's files (Current project source
  files), of the open files (Open source files) - as the editor has them - and of the project's
  To-Do file (Project To-Do file: the items of Add...; SdTodo). A closed file is read only when it
  changed since the list read it last (FTodoTexts): the list is the same as if every file were read }
procedure TMainForm.RefreshTodoList;
var
  Files, Old: TStringList;
  Ext: TList;
  I, OldLine: Integer;
  Text, F, OldFile: string;
  OldExt: IInterface;
  E: TSdEncoding;
  Ansi: Boolean;

  { the text of a file as the list shows its items (TodoSource: the system code page when it can):
    an open page's from its editor; a closed file's as the list read it before while its stamp is
    the same, else read again - the stamp taken first, so that a change while it is read reads it
    again the next time }
  function TextOf(const FileName: string): string;
  var
    K: Integer;
    T: TTodoText;
    Stamp: TSdFileStamp;
  begin
    if FindPage(FileName) <> nil then
    begin
      Result := TodoSource(FileName, E, Ansi);
      Exit;
    end;
    K := FTodoTexts.IndexOf(FileName);            // read in this refresh already
    if K >= 0 then
    begin
      Result := TTodoText(FTodoTexts.Objects[K]).Text;
      Exit;
    end;
    Stamp := FileStampU(FileName);
    K := Old.IndexOf(FileName);
    if (K >= 0) and Stamp.Exists and SameFileStamp(Stamp, TTodoText(Old.Objects[K]).Stamp) then
    begin
      T := TTodoText(Old.Objects[K]);
      Old.Delete(K);
    end
    else
    begin
      T := TTodoText.Create;
      try
        T.Text := TodoSource(FileName, E, Ansi);
      except
        T.Free;
        raise;
      end;
      T.Stamp := Stamp;
    end;
    FTodoTexts.AddObject(FileName, T);
    Result := T.Text;
  end;

begin
  { while the view is in a call to an expert or a dialog has an item: after it }
  if FTodoLock > 0 then
  begin
    FTodoPending := True;
    FTodoPendingFull := True;
    Exit;
  end;
  FTodoEditsSeen := FTodoEdits;
  { the chosen item by its place (an expert's by its interface): the items are made anew }
  FTodoView.SelectionKey(OldFile, OldLine, OldExt);
  { the experts' items first (SdOtaToDo): nothing of the list is freed while experts run }
  Ext := TList.Create;
  try
    Inc(FTodoLock);
    try
      OtaTodoCollect(Ext);
    finally
      Dec(FTodoLock);
    end;
    FTodoPendingFull := False;
    if FTodoPending then TodoRefreshLater;
    FTodo.Clear;                     // the view's rows point to them until FTodoView.Fill: no messages here
    for I := 0 to Ext.Count - 1 do FTodo.AddExternal(TSdTodoItem(Ext[I]));
    Ext.Clear;
  finally
    for I := 0 to Ext.Count - 1 do TObject(Ext[I]).Free;
    Ext.Free;
  end;
  { the texts of the files read before: what this refresh reads again or takes over goes into a
    new list, the rest (files no longer listed, changed ones) is freed at the end }
  if FTodoTexts = nil then FTodoTexts := TStringList.Create;
  Old := FTodoTexts;
  FTodoTexts := TStringList.Create;
  Files := TStringList.Create;
  try
    AddProjectFiles(Files);
    for I := 0 to Files.Count - 1 do Files.Objects[I] := Pointer(1);    // in the project
    for I := 0 to PageCount - 1 do
      if (Files.IndexOf(Pages[I].FileName) < 0) and not SameText(ExtractFileExt(Pages[I].FileName), TodoExt) then
        Files.Add(Pages[I].FileName);
    for I := 0 to Files.Count - 1 do
      if (Files[I] <> '') and (FileExists(Files[I]) or (FindPage(Files[I]) <> nil)) then
      begin
        try
          Text := TextOf(Files[I]);
        except
          Continue;
        end;
        FTodo.Scan(Files[I], Text, Files.Objects[I] <> nil, FindPage(Files[I]) <> nil, False);
      end;
    { the project's To-Do file (its source may be gone from the disk meanwhile) }
    if FProject <> nil then
      try
        F := TodoFileOf(ProjectSource, FProject.Dir);
        if (F <> '') and (FileExistsU(F) or (FindPage(F) <> nil)) then
          FTodo.Scan(F, TextOf(F), False, False, True);
      except
      end;
  finally
    Files.Free;
    for I := 0 to Old.Count - 1 do Old.Objects[I].Free;
    Old.Free;
    { the rows pointed to the items Clear freed: always made anew }
    FTodo.Collate;
    FTodoView.Fill(OldFile, OldLine, OldExt);
  end;
end;

{ IOTAToDoServices.UpdateList: the experts' items collected again (the files are not read again)
  and shown - at once, so that the expert's GetItemCount right after it sees them. Nothing before
  the view was first shown: Delphi 7's list collects only once its window was made }
procedure TMainForm.TodoExpertsChanged;
var
  Ext: TList;
  I, OldLine: Integer;
  OldFile: string;
  OldExt: IInterface;
begin
  if not FTodoShown then Exit;
  if FTodoLock > 0 then
  begin
    FTodoPending := True;
    Exit;
  end;
  FTodoView.SelectionKey(OldFile, OldLine, OldExt);
  Ext := TList.Create;
  try
    Inc(FTodoLock);
    try
      OtaTodoCollect(Ext);
    finally
      Dec(FTodoLock);
    end;
    if FTodoPending then TodoRefreshLater;
    FTodo.ClearExternal;             // the view's rows point to them until FTodoView.Fill: no messages here
    for I := 0 to Ext.Count - 1 do FTodo.AddExternal(TSdTodoItem(Ext[I]));
    Ext.Clear;
    FTodo.Collate;
    FTodoView.Fill(OldFile, OldLine, OldExt);
  finally
    for I := 0 to Ext.Count - 1 do TObject(Ext[I]).Free;
    Ext.Free;
  end;
end;

{ a package goes (Module), or the IDE ends (0): the experts' items of its code out at once - their
  interfaces released while the code is still there -, the rows made anew without asking any
  expert }
procedure TMainForm.TodoDropModule(Module: HMODULE);
var
  I, OldLine: Integer;
  It: TSdTodoItem;
  OldFile: string;
  OldExt: IInterface;
  Changed: Boolean;
begin
  FTodoView.DropExpertModule(Module);
  FTodoView.SelectionKey(OldFile, OldLine, OldExt);
  if (OldExt <> nil) and ((Module = 0) or (InterfaceModule(OldExt) = Module)) then OldExt := nil;
  Changed := False;
  for I := FTodo.ExternalCount - 1 downto 0 do
  begin
    It := FTodo.ExternalItem(I);
    if (Module = 0) or (InterfaceModule(It.Ext) = Module) then
    begin
      FTodo.RemoveExternal(It);
      Changed := True;
    end;
  end;
  if not Changed then Exit;
  FTodo.Collate;
  FTodoView.Fill(OldFile, OldLine, OldExt);
end;

procedure TMainForm.TodoUnlock;
begin
  Dec(FTodoLock);
  if (FTodoLock = 0) and FTodoPending then TodoRefreshLater;
end;

{ the list made anew after what runs now }
procedure TMainForm.TodoRefreshLater;
begin
  FTodoPending := False;
  if FTodoPosted or not HandleAllocated then Exit;
  FTodoPosted := True;
  PostMessage(Handle, WM_SDTODOREFRESH, 0, 0);
end;

{ a file opened in a page: the list takes its text from the editor from now on, and reads the file
  again once it is closed (its encoding may change while it is open, its stamp then not) }
procedure TMainForm.TodoForget(const FileName: string);
var
  K: Integer;
begin
  if FTodoTexts = nil then Exit;
  K := FTodoTexts.IndexOf(FileName);
  if K < 0 then Exit;
  FTodoTexts.Objects[K].Free;
  FTodoTexts.Delete(K);
end;

{ the project goes, or the IDE ends: the texts are let go }
procedure TMainForm.ClearTodoTexts;
var
  I: Integer;
begin
  if FTodoTexts = nil then Exit;
  for I := 0 to FTodoTexts.Count - 1 do FTodoTexts.Objects[I].Free;
  FTodoTexts.Clear;
end;

{ the files read again when a refresh of the view asked for it, else the experts' items }
procedure TMainForm.WMTodoRefresh(var Message: TMessage);
var
  Full: Boolean;
begin
  FTodoPosted := False;
  Full := FTodoPendingFull;
  FTodoPendingFull := False;
  if FClosing then Exit;
  if Full and FBottomPanels[BT_TODO].Showing then RefreshTodoList else TodoExpertsChanged;
end;

{ the active project changed (opened, closed, another of the group): the experts' To-Do managers
  are asked for their items once the change is over - not told IOTAToDoManager.ProjectChanged, which
  Delphi 7 calls on no expert's manager }
procedure TMainForm.TodoProjectLater;
begin
  if FTodoProjectPosted or not HandleAllocated then Exit;
  FTodoProjectPosted := True;
  PostMessage(Handle, WM_SDTODOPROJECT, 0, 0);
end;

procedure TMainForm.WMTodoProject(var Message: TMessage);
var
  F: string;
begin
  FTodoProjectPosted := False;
  if FClosing then Exit;
  if FProject <> nil then F := FProject.FileName else F := '';
  FTodoProject := F;
  TodoExpertsChanged;                // the views were emptied with the project
end;

{ Delphi collects the list again after each pause in typing while its window shows: here the
  files and the experts' items, when a text changed since the list was made }
procedure TMainForm.TodoTypingPause;
begin
  if (FTodoEdits <> FTodoEditsSeen) and not FClosing and FBottomPanels[BT_TODO].Showing then RefreshTodoList;
end;

procedure TMainForm.TodoExpertCommand(Item: TSdTodoItem; Action: TSdTodoAction);
begin
  if (Item = nil) or (Item.Ext = nil) then Exit;
  Inc(FTodoLock);
  try
    OtaTodoAction(Item, Action);
  finally
    Dec(FTodoLock);
  end;
  { the expert's items may have changed (Delete, Edit ...): collected again after the call }
  TodoRefreshLater;
end;

{ View | Component List: Delphi's Components window over the classes of the palette }
procedure TMainForm.ShowComponentList;
var
  L: TStringList;
  I, J: Integer;
  Item: TPaletteItem;
begin
  L := TStringList.Create;
  try
    for I := 0 to DesignHost.PageCount - 1 do
      for J := 0 to DesignHost.Pages[I].Items.Count - 1 do
      begin
        Item := TPaletteItem(DesignHost.Pages[I].Items[J]);
        { the Frames tool is no component class }
        if not Item.Hidden and not Item.IsFrames then
          L.AddObject(Item.ComponentClass.ClassName, TObject(Item.ComponentClass));
      end;
    PlaceComponent(TCompListDlg.Execute(Self, L));
  finally
    L.Free;
  end;
end;

{ New Component's ancestor types (the base classes and every registered component class) and
  palette pages }
procedure TMainForm.GetComponentClasses(Classes, Pages: TStrings);
const
  BaseClasses: array[0..5] of string = ('TComponent', 'TControl', 'TWinControl', 'TGraphicControl',
    'TCustomControl', 'TCustomPanel');
var
  L: TStringList;
  I, J: Integer;
begin
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupIgnore;
    for I := Low(BaseClasses) to High(BaseClasses) do L.Add(BaseClasses[I]);
    for I := 0 to DesignHost.PageCount - 1 do
    begin
      Pages.Add(DesignHost.Pages[I].Name);
      for J := 0 to DesignHost.Pages[I].Items.Count - 1 do
        if not TPaletteItem(DesignHost.Pages[I].Items[J]).IsFrames then
          L.Add(TPaletteItem(DesignHost.Pages[I].Items[J]).ComponentClass.ClassName);
    end;
    Classes.Assign(L);
  finally
    L.Free;
  end;
end;

{ the unit of a new component (New Component, the package editor's Add), written and opened:
  its uses are SysUtils, Classes, Controls for a control and the ancestor's own unit }
procedure TMainForm.WriteNewComponent(const Info: TNewCompInfo);
var
  Units: TStringList;
  Cls: TPersistentClass;
  U: string;
begin
  Units := TStringList.Create;
  try
    Units.Add('SysUtils');
    Units.Add('Classes');
    Cls := GetClass(Info.Ancestor);
    if (Cls <> nil) and Cls.InheritsFrom(TControl) then Units.Add('Controls');
    if (Cls <> nil) and (Cls.ClassInfo <> nil) then
    begin
      U := GetTypeData(PTypeInfo(Cls.ClassInfo))^.UnitName;
      if (U <> '') and (Units.IndexOf(U) < 0) then Units.Add(U);
    end;
    WriteFileU(Info.UnitFile, NewFileBytes(NewComponentSource(ChangeFileExt(ExtractFileName(Info.UnitFile), ''),
      Info.NewClass, Info.Ancestor, Info.Page, StringReplace(Trim(Units.CommaText), ',', ', ', [rfReplaceAll]))));
    OpenFile(Info.UnitFile, True);
  finally
    Units.Free;
  end;
end;

{ Component | New Component: Delphi's wizard; the unit is written and opened, Install... then
  installs it into a package (Install Component) }
procedure TMainForm.NewComponent;
var
  Classes, Pages: TStringList;
  Info: TNewCompInfo;
  Dir: string;
begin
  Classes := TStringList.Create;
  Pages := TStringList.Create;
  try
    GetComponentClasses(Classes, Pages);
    if FProject <> nil then Dir := FProject.Dir else Dir := GetCurrentDir;
    FillChar(Info, SizeOf(Info), 0);
    Info.Page := 'Samples';
    Info.SearchPath := EnvOptions.LibraryPath;
    if not TNewCompDlg.Execute(Self, Classes, Pages, Dir, Info) then Exit;
    WriteNewComponent(Info);
    if Info.Install then InstallComponent;
  finally
    Pages.Free;
    Classes.Free;
  end;
end;

{ Search | Find Error: the source line of a run-time error address ("Access violation at
  address 00452A1C") in the project's program, from its TD32 debug information or its detailed
  map file (Project Options | Linker) }
procedure TMainForm.FindErrorAddress;
var
  S, Src: string;
  Addr: Cardinal;
  A64: Int64;
  Info: TTD32Info;
  L: TTDLine;
  Found: Boolean;
  U: TProjectUnit;
begin
  if FProject = nil then Exit;
  S := '';
  if not FindErrorDialog(Self, S) then Exit;
  S := Trim(S);
  if (S <> '') and (S[1] = '$') then Delete(S, 1, 1);
  if UpperCase(Copy(S, 1, 2)) = '0X' then Delete(S, 1, 2);
  A64 := StrToInt64Def('$' + S, -1);
  if (S = '') or (A64 < 0) or (A64 > High(Cardinal)) then
  begin
    MessageBox(Handle, PChar('''' + S + ''' is not a valid address.'), 'Find Error', MB_OK or MB_ICONERROR);
    Exit;
  end;
  Addr := A64;
  Info := TTD32Info.Create;
  try
    Found := Info.LoadAny(FProject.ExeName);
    if not Found then
    begin
      MessageBox(Handle, PChar(Format('%s has no debug information: compile it with TD32 debug information or a ' +
        'detailed map file (Project | Options | Linker).', [ExtractFileName(FProject.ExeName)])), 'Find Error',
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    { an address of the running program: the image base off; a small number is an RVA }
    if Addr >= Info.ImageBase then Dec(Addr, Info.ImageBase);
    if not Info.AddrToLine(Addr, L) then
    begin
      MessageBox(Handle, PChar(Format('Address %s is not in the source of %s.', [S, ExtractFileName(FProject.ExeName)])),
        'Find Error', MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    Src := Info.SrcName[L.Src];
  finally
    Info.Free;
  end;
  { the unit of the project, else a file next to the project }
  U := FProject.FindUnitByName(ChangeFileExt(ExtractFileName(Src), ''));
  if U <> nil then Src := U.FileName
  else if not FileExists(Src) then Src := FProject.Dir + ExtractFileName(Src);
  FServices.OpenFileAt(Src, L.Line, 1);
end;

{ Search | Browse Symbol: a symbol - "Unit", "TClass", "TClass.Member", "Unit.Ident" - found by
  code insight as from a unit that uses the project's units, shown in the Browser (else its
  declaration) }
procedure TMainForm.BrowseSymbol;
const
  Common = 'Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls';
var
  S, Src, UsesList, Dir: string;
  I, P: Integer;
  Item: TCIItem;
begin
  S := '';
  if (ActivePage <> nil) and ActivePage.CodeView then S := ActivePage.WordAtCaret;
  if not BrowseSymbolDialog(Self, S) then Exit;
  UsesList := Common;
  if FProject <> nil then
    for I := 0 to FProject.UnitCount - 1 do UsesList := UsesList + ', ' + FProject.Units[I].Name;
  Src := 'unit SdBrowseSymbol;'#13#10'interface'#13#10'uses ' + UsesList + ';'#13#10'implementation'#13#10 +
    'procedure Browse;'#13#10'begin'#13#10'  ';
  P := Length(Src) + Length(S) - 1;      // 0-based offset of the last character of the symbol
  Src := Src + S + ';'#13#10'end;'#13#10'end.'#13#10;
  if FProject <> nil then Dir := FProject.Dir else Dir := IncludeTrailingPathDelimiter(GetCurrentDir);
  if (FCodeInsight <> nil) and FCodeInsight.FindDeclaration(Dir + 'SdBrowseSymbol.pas', Src, P, Item) and
    (Item.Line > 0) and (Item.FileName <> '') then
    ShowBrowsedSymbol(Item)
  else
    MessageBox(Handle, PChar(Format('Symbol ''%s'' not found.', [S])), 'Browse Symbol', MB_OK or MB_ICONINFORMATION);
end;

{ a symbol code insight found: in the Browser, as Delphi shows it; one the Browser does not have
  (outside its scope): its declaration }
procedure TMainForm.ShowBrowsedSymbol(const Item: TCIItem);
begin
  if FProject <> nil then
  begin
    RebuildBrowser;
    if FBrowser.ShowSymbol(FBrowser.FindSym(Item.FileName, Item.Line)) then
    begin
      FBrowserFresh := True;
      ShowDockPanel(FBrowserPanel);
      FBrowserFresh := False;
      Exit;
    end;
  end;
  FServices.OpenFileAt(Item.FileName, Item.Line, Item.Col);
end;

{ the editor's Browse Symbol at Cursor: the declaration of the name at the caret, as Find
  Declaration finds it, in the Browser }
procedure TMainForm.BrowseSymbolAtCursor;
var
  P: TEditorPage;
  Item: TCIItem;
begin
  P := ActivePage;
  if (P = nil) or not P.CodeView or not P.IsPascal or (FCodeInsight = nil) then Exit;
  if FCodeInsight.FindDeclaration(P.FileName, P.GetSource, P.Editor.CaretPos, Item) and (Item.Line > 0) then
  begin
    if Item.FileName = '' then Item.FileName := P.FileName;
    ShowBrowsedSymbol(Item);
  end
  else
    MessageBeep(MB_ICONASTERISK);
end;

{ Help in the menus of the Object Inspector and the Object TreeView: Delphi 7's VCL help at the
  chosen property (the inspector), else at the chosen component's class }
procedure TMainForm.ViewHelp;
var
  G: TPropGrid;
  O: TPersistent;
  K: string;
begin
  K := '';
  if FMenuPanel = FInspPanel then
  begin
    G := FInspector.Grid;
    if (G.SelectedRow >= 0) and (G.SelectedRow < G.RowCount) then K := G.Rows[G.SelectedRow].Name;
  end
  else
  begin
    O := FObjTree.SelectedObject;
    if O <> nil then K := O.ClassName;
  end;
  OpenHelpFile(DelphiRoot + HelpVclFile, K);
end;

{ Project | Information: Delphi's figures from the last compile }
procedure TMainForm.ShowProjectInfo;
var
  Info: TCompileInfo;
  S: string;
  SR: TSearchRec;

  { the number before Tail in the compiler's summary ("1234 lines, 0.5 seconds, 5678 bytes code") }
  function Num(const Tail: string): Integer;
  var
    E, B: Integer;
  begin
    Result := -1;
    E := Pos(Tail, S);
    if E = 0 then Exit;
    B := E - 1;
    while (B > 0) and (S[B] in ['0'..'9', ',', '.']) do Dec(B);
    Result := StrToIntDef(StringReplace(StringReplace(Copy(S, B + 1, E - B - 1), ',', '', [rfReplaceAll]), '.', '',
      [rfReplaceAll]), -1);
  end;

begin
  if FProject = nil then Exit;
  S := FCompiler.Summary;
  Info.Lines := Num(' lines');
  Info.CodeSize := Num(' bytes code');
  Info.DataSize := Num(' bytes data');
  Info.StackSize := FProject.OptInt('Linker', 'MaxStackSize', 1048576);
  Info.FileSize := -1;
  if FindFirst(FProject.ExeName, faAnyFile, SR) = 0 then
  begin
    Info.FileSize := SR.Size;
    FindClose(SR);
  end;
  if S = '' then Info.Status := 'Not compiled.'
  else if FCompiler.Errors > 0 then Info.Status := 'Compile failed.'
  else Info.Status := 'Compiled.';
  if FProject.OptInt('Directories', 'UsePackages', 0) <> 0 then
    Info.Packages := FProject.OptStr('Directories', 'Packages', '')
  else
    Info.Packages := '';
  CompileInfoDialog(Self, 'Information for ' + FProject.Name, Info);
end;

{ Edit | Flip Children: the controls mirrored right to left, as TControl.FlipChildren does it -
  All: every control of the form, Selected: the selected controls and what they contain }
procedure TMainForm.FlipDesignChildren(D: TFormDesigner; All: Boolean);
var
  I: Integer;
begin
  if All then
  begin
    if D.Root is TWinControl then TWinControl(D.Root).FlipChildren(True);
  end
  else
    for I := 0 to D.SelectionCount - 1 do
      if (D.Selections[I] is TControl) and (D.Selections[I] <> D.Root) then
        with TControl(D.Selections[I]) do
          if Parent <> nil then
          begin
            Left := Parent.ClientWidth - Left - Width;
            if D.Selections[I] is TWinControl then TWinControl(D.Selections[I]).FlipChildren(True);
          end;
  D.Modified;
end;

{ ---------------------------------------------------------------- action handlers: search / view }

{ the text Find, Replace and Find in Files start with (the dialogs hold text of the system code
  page, the editor its file's encoding): the selection of the code editor when it is one line,
  else, with Editor Options | Find text at cursor, the word at the caret; else FindText stays }
procedure TMainForm.InitialFindText(var FindText: string);
var
  P: TEditorPage;
  Sel: string;
begin
  P := ActivePage;
  if (P = nil) or not P.CodeView then Exit;
  if P.Editor.SelEnd > P.Editor.SelStart then
  begin
    Sel := P.Editor.SelText;
    if (Pos(#10, Sel) = 0) and (Pos(#13, Sel) = 0) then FindText := EditorToAnsi(Sel, P.Editor.Encoding);
  end
  else if EditorOptions.FindTextAtCursor and (P.WordAtCaret <> '') then
    FindText := P.WordAtCaret;                          // ANSI already
end;
procedure TMainForm.ActSearch(Sender: TObject);
var
  P: TEditorPage;
  Line: Integer;
begin
  P := ActivePage;
  if Sender = SearchFileFindCommand then
  begin
    DoFindInFiles;
    Exit;
  end;
  if Sender = SearchFindErrCommand then
  begin
    FindErrorAddress;
    Exit;
  end;
  if Sender = SearchSymbolCommand then
  begin
    BrowseSymbol;
    Exit;
  end;
  if (P = nil) or not P.CodeView then Exit;
  if (Sender = SearchFindCommand) or (Sender = SearchReplaceCommand) then
  begin
    InitialFindText(FFind.FindText);
    if FindDialog(Self, FFind, Sender = SearchReplaceCommand) then
    begin
      BeginSearch(P.Editor);
      if Sender = SearchReplaceCommand then DoReplace else FindNextMatch(True);
      { Highlighting | Find matches: every place of the text searched for }
      P.Editor.MarkMatches(FFind.FindText, FFind.MatchCase, FFind.WholeWord, FFind.RegExp);
    end;
  end
  else if Sender = SearchAgainCommand then
  begin
    FindNextMatch(True);
    P.Editor.MarkMatches(FFind.FindText, FFind.MatchCase, FFind.WholeWord, FFind.RegExp);
  end
  else if Sender = SearchIncrementalCommand then
    P.IncrementalSearch
  else if Sender = SearchGoToCommand then
  begin
    Line := P.Editor.CaretLine + 1;
    if GotoLineDialog(Self, P.Editor.LineCount, Line) then
    begin
      NavMark;
      P.GotoLine(Line, 1);
    end;
  end
  else if Sender = aFindDecl then
    P.FindDeclarationAtCaret
  else if Sender = aComplete then
    P.ShowCompletion
  else if Sender = aTemplates then
    P.ShowCodeTemplates
  else if Sender = aParams then
    P.ShowParamHint;
end;

{ the History tab's commands (SdHistoryFrame) on the page shown's tab; its switches on every page's -
  kept in the settings (SaveState) }
procedure TMainForm.ActHistory(Sender: TObject);
var
  P: TEditorPage;
  Hv: TSdHistoryView;
  S: string;
  I: Integer;
begin
  P := ActivePage;
  if P = nil then Exit;
  if Sender = aHistRoutine then
  begin
    { the routine at the caret: its versions alone (none there: every version) }
    S := RoutineAt(P.GetSource, P.Editor.CaretLine);
    P.ShowHistory(True);
    if P.History <> nil then P.History.ShowRoutine(S);
    Exit;
  end;
  if (Sender = aHistSideBySide) or (Sender = aHistIgnoreBlanks) or (Sender = aHistComparePrev) then
  begin
    if Sender = aHistSideBySide then HistorySideBySide := not HistorySideBySide
    else if Sender = aHistIgnoreBlanks then HistoryIgnoreBlanks := not HistoryIgnoreBlanks
    else HistoryComparePrevious := not HistoryComparePrevious;
    for I := 0 to PageCount - 1 do
      if Pages[I].History <> nil then Pages[I].History.SwitchesChanged;
    UpdateActionStates;
    Exit;
  end;
  if not P.HistoryView or (P.History = nil) then Exit;
  Hv := P.History;
  if Sender = aHistPrevChange then Hv.GotoChange(False)
  else if Sender = aHistNextChange then Hv.GotoChange(True)
  else if Sender = aHistRestore then Hv.Restore
  else if Sender = aHistRestoreChange then Hv.RestoreChange
  else if Sender = aHistGotoCode then Hv.GotoCode
  else if Sender = aHistCopy then Hv.CopySelection
  else if Sender = aHistRemoveLabel then Hv.RemoveLabel
  else if Sender = aHistLabel then
  begin
    S := Hv.LabelOfChoice;
    if InputDialog(Self, 'Label', 'A name for the version (it is kept for good):', S) then Hv.LabelChoice(S);
  end;
  UpdateActionStates;
end;

{ the History tab's menu: the timeline's commands on its list (Tag 1), the diff's on its windows
  (Tag 2), the switches on both - every one when it opens on neither (a command of its own) }
procedure TMainForm.HistoryMenuPopup(Sender: TObject);
var
  I: Integer;
  OnList, OnDiff: Boolean;
begin
  OnList := HistoryMenu.PopupComponent is TListBox;
  OnDiff := HistoryMenu.PopupComponent is TSciWindow;
  for I := 0 to HistoryMenu.Items.Count - 1 do
    with HistoryMenu.Items[I] do
      Visible := (Tag = 0) or (Tag = 1) and not OnDiff or (Tag = 2) and not OnList;
  UpdateActionStates;
end;

{ every few minutes: the unsaved text of each page, when it changed since its last version (one
  Unsaved version per file, replaced each time, gone with the save) }
procedure TMainForm.HistoryTimerTick(Sender: TObject);
var
  I: Integer;
begin
  if FClosing then Exit;
  for I := 0 to PageCount - 1 do
    if Pages[I].Modified then Pages[I].KeepVersion(hkUnsaved);
end;

{ the versions of a file changed (SdHistory): the History tab of its page - the unit's or its form's }
procedure TMainForm.HistoryFileChanged(const FileName: string);
var
  I: Integer;
begin
  if FClosing then Exit;
  for I := 0 to PageCount - 1 do
    if SameText(Pages[I].FileName, FileName) or SameText(Pages[I].FormFileName, FileName) then
      Pages[I].HistoryChanged;
end;

{ Editor Options | Display | Keep file history and the versions kept per file }
procedure TMainForm.ApplyHistoryOptions;
begin
  SdHistory.HistoryEnabled := EditorOptions.KeepHistory;
  if EditorOptions.HistoryLimit < 1 then SdHistory.HistoryLimit := 1
  else SdHistory.HistoryLimit := EditorOptions.HistoryLimit;
  HistoryTimer.Enabled := SdHistory.HistoryEnabled;
end;

procedure TMainForm.ActView(Sender: TObject);
var
  L, Sel: TStringList;
  I, Idx: Integer;
  S: string;
  P: TEditorPage;
begin
  if Sender = ViewPrjMgrCommand then ViewDockPanel(FProjPanel)
  else if Sender = aViewPackage then ShowPackageEditor(FProject, True)   // the active package's editor
  else if Sender = aViewResources then ViewDockPanel(FResPanel)
  else if Sender = ViewObjTreeViewCommand then ViewDockPanel(FObjTreePanel)
  else if (Sender = ViewCodeExplorerCommand) or (Sender = ecViewExplorer) then
  begin
    { the editor's View Explorer (Ctrl+Shift+E) back to the editor from the explorer (Delphi's help:
      it toggles) }
    if (Sender = ecViewExplorer) and FCodeExp.Tree.Focused and (ActivePage <> nil) then
      ExpViewEditor(Sender)
    else
      ViewDockPanel(FCodeExpPanel);
  end
  else if Sender = ViewWindowListCommand then
  begin
    L := TStringList.Create;
    try
      for I := 0 to FDocs.Count - 1 do L.Add(DocTitle(TWinControl(FDocs[I])));
      Idx := FDocs.IndexOf(ActiveDoc);
      if WindowListDialog(Self, L, Idx) then ActivatePage(TWinControl(FDocs[Idx]));
    finally
      L.Free;
    end;
  end
  else if Sender = ViewCompListCommand then ShowComponentList
  else if Sender = ViewToDoListCommand then ViewDockPanel(FBottomPanels[BT_TODO])
  else if Sender = DebugThreadsCommand then ViewDockPanel(FMachinePanels[0])
  else if Sender = DebugModulesCommand then ViewDockPanel(FMachinePanels[1])
  else if Sender = DebugCPUCommand then ViewDockPanel(FMachinePanels[2])
  else if Sender = DebugFPUCommand then ViewDockPanel(FMachinePanels[3])
  else if Sender = ViewNextWindow then
  begin
    if FDocs.Count > 1 then ActivatePage(TWinControl(FDocs[(FDocs.IndexOf(ActiveDoc) + 1) mod FDocs.Count]));
  end
  else if Sender = aDesktops then ShowDesktops
  else if (Sender = ViewSaveDesktopCommand) or (Sender = ViewDeleteDesktopCommand) or (Sender = ViewRuntimeDesktopCommand) then
  begin
    { Delphi's Save Desktop, Delete Saved Desktop and Select debug desktop }
    L := TStringList.Create;
    try
      DesktopNames(L);
      if Sender = ViewSaveDesktopCommand then
      begin
        S := Settings.ReadString('Desktops', '.Current', '');
        if DesktopDialog(Self, False, L, S) and (Copy(S, 1, 1) <> '.') then SaveNamedDesktop(S);
      end
      else if Sender = ViewRuntimeDesktopCommand then
      begin
        S := Settings.ReadString('Desktops', '.Debug', '');
        if DesktopDialog(Self, True, L, S) then SetDebugDesktop(S);
      end
      else if L.Count > 0 then
      begin
        { Delphi's Delete Saved Desktop: every desktop selected there }
        Sel := TStringList.Create;
        try
          if DesktopDeleteDialog(Self, L, Sel) then
            for I := 0 to Sel.Count - 1 do DeleteNamedDesktop(Sel[I]);
        finally
          Sel.Free;
        end;
      end;
    finally
      L.Free;
    end;
  end
  else if Sender = aViewComponents then ViewDockPanel(FCompPanel)
  else if Sender = ViewObjInspCommand then ViewDockPanel(FInspPanel)
  else if Sender = aViewMessages then ViewDockPanel(FBottomPanels[BT_MESSAGES])
  else if Sender = aViewErrorList then ViewDockPanel(FBottomPanels[BT_ERRORS])
  else if Sender = DebugBreakPointsCommand then ViewDockPanel(FBottomPanels[BT_BREAKS])
  else if Sender = DebugCallStackCommand then ViewDockPanel(FBottomPanels[BT_STACK])
  else if Sender = DebugWatchesCommand then ViewDockPanel(FBottomPanels[BT_WATCHES])
  else if Sender = DebugLocalVariablesCommand then ViewDockPanel(FBottomPanels[BT_LOCALS])
  else if Sender = DebugEventLogCommand then ViewDockPanel(FBottomPanels[BT_LOG])
  else if Sender = ViewToggleFormCommand then
  begin
    if ActivePage <> nil then ActivePage.ToggleView;
  end
  else if Sender = aViewDiagram then
  begin
    { the page's Diagram tab, or back to its code }
    if ActivePage <> nil then ActivePage.ShowDiagram(not ActivePage.DiagramView);
  end
  else if Sender = aViewHistory then
  begin
    { the page's History tab, or back to its code }
    if ActivePage <> nil then ActivePage.ShowHistory(not ActivePage.HistoryView);
  end
  else if (Sender = aDiagExpandAll) or (Sender = aDiagCollapseAll) or (Sender = aDiagReset) then
  begin
    if (ActivePage = nil) or not ActivePage.DiagramView or (ActivePage.Diagram = nil) then Exit;
    with ActivePage.Diagram do
      if Sender = aDiagExpandAll then ExpandAll(True)
      else if Sender = aDiagCollapseAll then ExpandAll(False)
      else ResetView;
  end
  else if (Sender = ViewUnitCommand) or (Sender = ViewFormCommand) then
  begin
    if FProject = nil then Exit;
    L := TStringList.Create;
    try
      if Sender = ViewUnitCommand then L.AddObject(FProject.Name, nil);
      for I := 0 to FProject.UnitCount - 1 do
        if Sender = ViewUnitCommand then
          L.AddObject(FProject.Units[I].Name, FProject.Units[I])
        else if FProject.Units[I].HasForm then
          L.AddObject(FProject.Units[I].FormName, FProject.Units[I]);
      { by name, case-insensitive, the project among the units: Delphi 7's TViewDialog has a sorted list }
      L.Sort;
      Idx := 0;
      if Sender = ViewUnitCommand then
      begin
        if ListDialog(Self, 'View Unit', L, Idx) then
          if L.Objects[Idx] = nil then
            OpenFile(FProject.FileName, True)
          else
          begin
            P := OpenFile(TProjectUnit(L.Objects[Idx]).FileName, True);
            if P <> nil then P.ShowDesign(False);
          end;
      end
      else if ListDialog(Self, 'View Form', L, Idx) then
      begin
        OpenFileView(TProjectUnit(L.Objects[Idx]).FileName, True, True);
      end;
    finally
      L.Free;
    end;
  end;
end;

{ ---------------------------------------------------------------- action handlers: project / run / tools }

{ ---------------------------------------------------------------- packages (.dpk) }

{ the design package entry of the project's .bpl, nil when it is not installed (a design
  package is a 32-bit Delphi 7 package: a Win64 build never is one) }
function TMainForm.InstalledPackage(P: TSdProject): TPackageEntry;
begin
  Result := nil;
  if (P <> nil) and P.IsPackage and (P.Platform = spWin32) then
    Result := DesignHost.FindPackage(P.ExeName);
end;

{ compiles a package and installs its .bpl (its components appear in the Components view), then says what it
  registered (Project | Install Package, Component | Install Component); installed already, it
  is compiled and loaded again }
function TMainForm.InstallPackageProject(P: TSdProject): Boolean;
var
  E: TPackageEntry;
  Err: string;
begin
  Result := False;
  if P.IsRunOnly then
  begin
    MessageBox(Handle, PChar(Format('%s is a run-time only package ({$RUNONLY}): it cannot be installed.',
      [ExtractFileName(P.FileName)])), AppTitle, MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  if not CompileProject(P, False, False, False) then Exit;
  Screen.Cursor := crHourGlass;
  try
    E := DesignHost.InstallPackage(P.ExeName, Err);
  finally
    Screen.Cursor := crDefault;
  end;
  DesignHost.SavePackageList;
  Result := (E <> nil) and (Err = '');
  if not Result then
    MessageBox(Handle, PChar(Format('%s cannot be installed.'#13#10#13#10'%s', [ExtractFileName(P.ExeName),
      Err])), AppTitle, MB_OK or MB_ICONERROR)
  else
    MessageBox(Handle, PChar(DesignHost.InstallReport(E)), AppTitle, MB_OK or MB_ICONINFORMATION);
end;

{ Project | Uninstall Package, as the Uninstall button of Delphi's package editor: P's .bpl out of
  the installed packages }
procedure TMainForm.UninstallPackageOf(P: TSdProject);
var
  E: TPackageEntry;
  Err: string;
begin
  E := InstalledPackage(P);
  if E = nil then Exit;
  if not DesignHost.RemovePackage(E, Err) then
  begin
    MessageBox(Handle, PChar(Err), AppTitle, MB_OK or MB_ICONERROR);
    Exit;
  end;
  DesignHost.SavePackageList;
  MessageBox(Handle, PChar(Format('Package %s has been uninstalled.', [P.ExeName])), AppTitle,
    MB_OK or MB_ICONINFORMATION);
end;

{ the form of a unit: the object its .dfm (text or binary) declares, '' without one }
function UnitFormName(const PasFile: string): string;
var
  Dfm, N, C: string;
begin
  if ReadFormHeader(ChangeFileExt(PasFile, '.dfm'), Dfm, N, C) then Result := N else Result := '';
end;
{ P's search path: SearchPath (a dialog's), with Dir added when it is neither P's folder nor in
  the path already - Delphi adds the folder of a unit it installs to its library path, so that the
  unit's other units (or a required package's .dcp) are found }
procedure TMainForm.SetPackageSearchPath(P: TSdProject; const SearchPath, Dir: string);
var
  Dirs, D: string;
begin
  Dirs := SearchPath;
  D := ExcludeTrailingPathDelimiter(Dir);
  if (D <> '') and not SameText(D, ExcludeTrailingPathDelimiter(P.Dir)) and
    not PathHasDir(Dirs, D) then
  begin
    if Dirs <> '' then Dirs := Dirs + ';';
    Dirs := Dirs + D;
  end;
  if Dirs <> P.SearchPathList then
  begin
    P.SetOptStr('Directories', 'SearchPath', Dirs);
    P.SaveOptions;
  end;
end;

{ a unit into the contains clause of package P (Install Component, the package editor's Add) with
  its form, and the search path; False (said) when no contains clause could be written }
function TMainForm.AddUnitToPackage(P: TSdProject; const UnitFile, SearchPath: string): Boolean;
var
  UnitName, Src, Rel: string;
begin
  Result := True;
  UnitName := ChangeFileExt(ExtractFileName(UnitFile), '');
  if P.FindUnitByName(UnitName) = nil then
  begin
    if not ProjectSourceName(P, UnitFile, Rel) then
    begin
      Result := False;
      Exit;
    end;
    Src := SourceOf(P.FileName);
    if not DprAddUnit(Src, UnitName, Rel, UnitFormName(UnitFile)) then
    begin
      MessageBox(Handle, PChar(Format('%s cannot be added to %s (no contains clause could be written).',
        [UnitName, ExtractFileName(P.FileName)])), AppTitle, MB_OK or MB_ICONERROR);
      Result := False;
      Exit;
    end;
    SetProjectSourceOf(P, Src);
  end;
  SetPackageSearchPath(P, SearchPath, ExtractFilePath(UnitFile));
  { a project of the group or a package beside it: its units' nodes were made anew }
  if (FGroup.IndexOfProject(P) >= 0) or FGroup.IsBeside(P) then
  begin
    RefreshProjectTree;
    ConfigureCodeInsight;
  end;
end;

{ ---------------------------------------------------------------- the package editors }

{ a package editor (Delphi 7's window of a package): a view of the dock named AName - PackageEditor,
  PackageEditor2 ..., the name an arrangement keeps its place by -, floating at first as Delphi's
  window, hidden until a package takes it (PackageViewOf); its status line shows the chosen item's
  file }
function TMainForm.NewPackageView(const AName: string): TSdPackageView;
var
  Panel: TSdDockPanel;
  R: TRect;
  Offset: Integer;
begin
  Result := TSdPackageView.Create(Self);
  WireViewMenu(Result.PkgPopup, Result.MenuActions, ActPackage);
  PlaceView(Result, Result.PkgPopup);
  Result.Tree.Images := Icons;
  Result.Tree.PopupMenu := Result.PkgPopup;
  Result.Tree.OnChange := PkgTreeChange;
  Result.Tree.OnDblClick := PkgTreeDblClick;
  Result.Tree.OnKeyDown := PkgTreeKeyDown;
  Result.Tree.OnMouseDown := PkgTreeMouseDown;
  Result.Bar.Images := Icons;
  Result.tbPkgCompile.Action := Result.aPkgCompile;
  Result.tbPkgAdd.Action := Result.aPkgAdd;
  Result.tbPkgRemove.Action := Result.aPkgRemove;
  Result.tbPkgInstall.Action := Result.aPkgInstall;
  Result.tbPkgOptions.Action := Result.aPkgOptions;
  Result.ColumnWidth := Settings.ReadInteger('Layout', 'PackageColumnWidth', Result.ColumnWidth);
  AddDockItems([Result.PkgPopup]);
  Panel := FDock.AddPanel(Result, AName, 'Package', FRightArea);
  Panel.ToolBar := Result.Bar;
  Panel.PopupMenu := Result.PkgPopup;
  Panel.FocusControl := Result.Tree;
  Panel.ShowStatus := FPkgStatus;
  { Delphi's window is 368 x 244 in its font: a little larger, in the middle of the screen - each
    further one lower and to the right -, until the user moves it (a saved arrangement has its
    place) }
  R := Screen.WorkAreaRect;
  Offset := 24 * FPkgViews.Count;
  FDock.FloatPanel(Panel, Bounds((R.Left + R.Right - 380) div 2 + Offset, (R.Top + R.Bottom - 280) div 2 + Offset, 380, 280));
  FDock.HidePanel(Panel);
  FPkgViews.Add(Result);
end;

{ the package editors an arrangement names (PackageEditor<n>) are made before it is applied, so
  that it places them }
procedure TMainForm.ReservePackageViews(Names: TStrings);
var
  I: Integer;
begin
  for I := 0 to Names.Count - 1 do
    if SameText(Copy(Names[I], 1, Length('PackageEditor')), 'PackageEditor') and (FDock.FindPanel(Names[I]) = nil) then
      NewPackageView(Names[I]);
end;

{ the package editor of package P (nil: P is none). Make: one is given to it when it has none - the
  free one named AName (a desktop's), else the first free one, else a new one -, hidden until it
  is shown }
function TMainForm.PackageViewOf(P: TSdProject; Make: Boolean; const AName: string): TSdPackageView;
var
  I, N: Integer;
  V, Free: TSdPackageView;
  NewName: string;
begin
  Result := nil;
  if (P = nil) or not P.IsPackage then Exit;
  Free := nil;
  for I := 0 to FPkgViews.Count - 1 do
  begin
    V := TSdPackageView(FPkgViews[I]);
    if V.Project = P then
    begin
      Result := V;
      Exit;
    end;
    if (V.Project = nil) and ((Free = nil) or SameText(FDock.PanelOf(V).Name, AName)) then Free := V;
  end;
  if not Make then Exit;
  Result := Free;
  if Result = nil then
  begin
    NewName := AName;
    N := 1;
    while (NewName = '') or (FDock.FindPanel(NewName) <> nil) do
    begin
      Inc(N);
      NewName := 'PackageEditor' + IntToStr(N);
    end;
    Result := NewPackageView(NewName);
  end;
  Result.Project := P;
  RefreshPackageView(Result);
end;

{ the package editor of an action, a tree or a menu of one (they belong to its frame) }
function TMainForm.SenderPackageView(Sender: TObject): TSdPackageView;
begin
  Result := TSdPackageView(TComponent(Sender).Owner);
end;

{ P's package editor shown (one given to it when it has none): a package that opens, View | Package
  Editor, a package opened again; Focus: the keyboard to it too (ViewDockPanel) }
procedure TMainForm.ShowPackageEditor(P: TSdProject; Focus: Boolean);
var
  V: TSdPackageView;
begin
  V := PackageViewOf(P, True);
  if V = nil then Exit;
  if Focus then ViewDockPanel(FDock.PanelOf(V)) else ShowDockPanel(FDock.PanelOf(V));
end;

{ P goes (closed, out of the group, the group closed): its package editor is hidden and free for the
  next package - its package let go first, so that hiding it closes nothing (DockPanelHide) }
procedure TMainForm.ReleasePackageView(P: TSdProject);
var
  V: TSdPackageView;
begin
  V := PackageViewOf(P, False);
  if V = nil then Exit;
  V.Project := nil;
  RefreshPackageView(V);
  FDock.HidePanel(FDock.PanelOf(V));
end;

{ a package editor brought up to date: its title (Delphi's "Package - X.dpk"; its tab the file's
  name, which tells several apart), its clauses, the chosen item's file in the status line }
procedure TMainForm.RefreshPackageView(V: TSdPackageView);
var
  Panel: TSdDockPanel;
begin
  Panel := FDock.PanelOf(V);
  if V.Project = nil then
  begin
    Panel.Title := 'Package';
    Panel.TabText := '';
    Exit;
  end;
  Panel.Title := 'Package - ' + ExtractFileName(V.Project.FileName);
  Panel.TabText := ExtractFileName(V.Project.FileName);
  V.Fill(V.Project);
  Panel.StatusText := V.SelectedFile;
end;

{ every package's editor (a package's units are new objects after a change of its source) }
procedure TMainForm.RefreshPackageViews;
var
  I: Integer;
begin
  for I := 0 to FPkgViews.Count - 1 do
    if TSdPackageView(FPkgViews[I]).Project <> nil then RefreshPackageView(TSdPackageView(FPkgViews[I]));
end;

{ The editor of a package open beside the group closed by the user (its close box, Close): the
  package closes too, as Delphi's TPackageManager.CanCloseEditor closes it - from the message loop,
  after the dock's work (its questions may keep it open: then the editor shows again). The editor
  of a package of the group only hides. }
procedure TMainForm.DockPanelHide(Sender: TObject; Panel: TSdDockPanel);
begin
  if not FClosing and (Panel.Control is TSdPackageView) and FGroup.IsBeside(TSdPackageView(Panel.Control).Project) then
    PostMessage(Handle, WM_SDCLOSEBESIDE, 0, LPARAM(Panel.Control));
end;

procedure TMainForm.WMCloseBeside(var Message: TMessage);
var
  V: TSdPackageView;
  P: TSdProject;
  F: string;
begin
  V := TSdPackageView(Message.LParam);
  { still that package's editor, still closed }
  if (FPkgViews.IndexOf(V) < 0) or not FGroup.IsBeside(V.Project) or FDock.PanelOf(V).Visible then Exit;
  P := V.Project;
  F := P.FileName;                     // P is freed when it goes
  if not ProjectLeaves(F, False, False, False, True) then ShowPackageEditor(P);
end;

{ an expert's View as Text / View as Form (TOtaMainHost.SwapSourceFormLater): on its page, if it is
  still open }
procedure TMainForm.WMSwapForm(var Message: TMessage);
var
  P: TEditorPage;
begin
  P := TEditorPage(Message.LParam);
  if (FPages.IndexOf(P) < 0) or (FOtaHost = nil) then Exit;
  ActivatePage(P);
  FOtaHost.ExecuteAction(ViewSwapSourceFormCommand.Name);
end;

procedure TMainForm.PkgTreeChange(Sender: TObject; Node: TTreeNode);
var
  V: TSdPackageView;
begin
  V := SenderPackageView(Sender);
  FDock.PanelOf(V).StatusText := V.SelectedFile;
end;

procedure TMainForm.PkgTreeDblClick(Sender: TObject);
begin
  SenderPackageView(Sender).aPkgOpen.Execute;
end;

procedure TMainForm.PkgTreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Shift <> [] then Exit;
  if Key = VK_RETURN then SenderPackageView(Sender).aPkgOpen.Execute
  else if Key = VK_DELETE then SenderPackageView(Sender).aPkgRemove.Execute
  else Exit;
  Key := 0;
end;

{ a right click chooses the item first: its menu is about it (the tree's RightClickSelect only
  pretends while the menu is open, and the menu's command runs after it closed) - the Project
  Manager's, the package editor's, the resources', the Code Explorer's and the Object TreeView's
  trees }
procedure TMainForm.PkgTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  N: TTreeNode;
begin
  if Button <> mbRight then Exit;
  N := TTreeView(Sender).GetNodeAt(X, Y);
  if N <> nil then TTreeView(Sender).Selected := N;
end;

{ a unit of the project in the editor, its form in the designer }
procedure TMainForm.OpenProjectUnit(U: TProjectUnit);
begin
  OpenFileView(U.FileName, True, True);
end;

{ Add: Delphi's dialog - a unit, a required package, a new component or an ActiveX control's
  import into package P }
procedure TMainForm.AddToPackage(P: TSdProject);
var
  Info: TPackageAddInfo;
  Classes, Pages, ImportPages, Added: TStringList;
  OK: Boolean;
  F, Src: string;
begin
  if P = nil then Exit;
  Classes := TStringList.Create;
  Pages := TStringList.Create;
  ImportPages := TStringList.Create;
  Added := TStringList.Create;
  try
    GetComponentClasses(Classes, Pages);
    Info.SearchPath := P.SearchPathList;
    Info.NewComp.Page := 'Samples';
    Info.NewComp.SearchPath := P.SearchPathList;
    LoadImportInfo(True, Info.Import, ImportPages, Added);
    Info.Import.SearchPath := P.SearchPathList;
    OK := PackageAddDialog(Self, P.Dir, Classes, Pages, ImportPages, Added, Info);
    SaveImportInfo(True, Info.Import, Added, OK and (Info.Page = paActiveX));
    if not OK then Exit;
    case Info.Page of
      paUnit: AddUnitToPackage(P, Info.FileName, Info.SearchPath);
      paRequires:
        begin
          Src := SourceOf(P.FileName);
          if not DpkAddRequires(Src, Info.FileName) then
            MessageBox(Handle, PChar(Format('%s cannot be added to %s (no requires clause could be written).',
              [Info.FileName, ExtractFileName(P.FileName)])), AppTitle, MB_OK or MB_ICONERROR)
          else
          begin
            SetPackageSearchPath(P, Info.SearchPath, Info.PackageDir);
            ProjectSourceChangedOf(P, Src);
          end;
        end;
      paNewComponent:
        begin
          WriteNewComponent(Info.NewComp);
          AddUnitToPackage(P, Info.NewComp.UnitFile, Info.NewComp.SearchPath);
        end;
      paActiveX:
        begin
          F := ImportTypeLibUnit(True, Info.Import);
          if F <> '' then AddUnitToPackage(P, F, Info.Import.SearchPath);
        end;
    end;
  finally
    Added.Free;
    ImportPages.Free;
    Pages.Free;
    Classes.Free;
  end;
end;

{ Remove: the unit chosen in package editor V out of the contains clause (its file stays), or the
  chosen package out of the requires clause - asked first }
procedure TMainForm.RemoveFromPackage(V: TSdPackageView);
var
  P: TSdProject;
  U: TProjectUnit;
  Pkg, What, Src: string;
begin
  P := V.Project;
  if P = nil then Exit;
  U := V.SelectedUnit;
  Pkg := V.SelectedPackage;
  if U <> nil then What := ExtractFileName(U.FileName)
  else if Pkg <> '' then What := Pkg + '.dcp'
  else Exit;
  if MessageBox(Handle, PChar(Format('Remove %s from %s?', [What, ExtractFileName(P.FileName)])),
    'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  if U <> nil then RemoveProjectUnitOf(P, U)
  else
  begin
    Src := SourceOf(P.FileName);
    if DpkRemoveRequires(Src, Pkg) then ProjectSourceChangedOf(P, Src);
  end;
end;

{ a package editor's commands: its tool bar (Compile | Add, Remove | Install, Options) and its menu,
  on its own package - active, another one of the group or one beside it: the Project menu's
  routines for that package }
procedure TMainForm.ActPackage(Sender: TObject);
var
  V: TSdPackageView;
  P: TSdProject;
  I: Integer;
begin
  V := SenderPackageView(Sender);
  P := V.Project;
  if Sender = V.aPkgStatusBar then
  begin
    { one setting for every package editor }
    FPkgStatus := not FDock.PanelOf(V).ShowStatus;
    for I := 0 to FPkgViews.Count - 1 do FDock.PanelOf(TSdPackageView(FPkgViews[I])).ShowStatus := FPkgStatus;
  end
  else if P = nil then
    Exit
  else if (Sender = V.aPkgCompile) or (Sender = V.aPkgBuild) then CompileProject(P, Sender = V.aPkgBuild, False, False)
  else if Sender = V.aPkgAdd then AddToPackage(P)
  else if Sender = V.aPkgRemove then RemoveFromPackage(V)
  else if Sender = V.aPkgInstall then
  begin
    if InstalledPackage(P) <> nil then UninstallPackageOf(P) else InstallPackageProject(P);
  end
  else if Sender = V.aPkgOptions then ShowProjectOptionsOf(P, 0)
  else if Sender = V.aPkgViewSource then ViewProjectSource(P)
  else if (Sender = V.aPkgOpen) and (V.SelectedUnit <> nil) then OpenProjectUnit(V.SelectedUnit);
end;


{ ---------------------------------------------------------------- the Resources view }

{ the resources of the active project's .res, Key's chosen ('' the one
  chosen before); the title names the file, the status line the chosen resource or what is
  special about the file }
procedure TMainForm.RefreshResourceView(const Key: string);
var
  R: TSdResources;
begin
  FResView.Fill(FProject, Key);
  R := FResView.Resources;
  FResNote := '';
  if R <> nil then
  begin
    FResPanel.Title := 'Resources - ' + ExtractFileName(R.ResFile);
    FResNote := ExtractFileName(R.ResFile);
    if not R.CanWrite then FResNote := FResNote + ' is no 32-bit resource file: it is not changed'
    else if not FileExists(R.ResFile) then FResNote := FResNote + ': none yet (Add makes it)'
    else if not LinksProjectRes(ProjectSource) then
      FResNote := FResNote + ' is not linked: the project source has no $R *.res';
  end
  else
    FResPanel.Title := 'Resources';
  FResPanel.TabText := 'Resources';
  ResTreeChange(ResTree, ResTree.Selected);
end;

procedure TMainForm.ResTreeChange(Sender: TObject; Node: TTreeNode);
var
  It: TSdResItem;
begin
  It := FResView.Selected;
  if It = nil then FResPanel.StatusText := FResNote
  else if It.Size = 1 then FResPanel.StatusText := ResourceTitle(It) + ': 1 byte'
  else FResPanel.StatusText := Format('%s: %s bytes', [ResourceTitle(It), FormatFloat('#,##0', It.Size)]);
end;

procedure TMainForm.ResTreeDblClick(Sender: TObject);
begin
  if FResView.Selected <> nil then FResView.aResEdit.Execute;
end;

procedure TMainForm.ResTreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Shift <> [] then Exit;
  if (Key = VK_RETURN) and (FResView.Selected <> nil) then FResView.aResEdit.Execute
  else if Key = VK_DELETE then FResView.aResDelete.Execute
  else if Key = VK_F2 then FResView.aResRename.Execute
  else Exit;
  Key := 0;
end;

procedure TMainForm.UpdateResourceActions;
var
  R: TSdResources;
  It: TSdResItem;
  Can: Boolean;
begin
  R := FResView.Resources;
  It := FResView.Selected;
  Can := (R <> nil) and R.CanWrite and not FCompiler.Running;
  aResAdd.Enabled := Can;
  FResView.aResNewBitmap.Enabled := Can;
  FResView.aResNewIcon.Enabled := Can;
  FResView.aResNewCursor.Enabled := Can;
  FResView.aResNewStrings.Enabled := Can and (R.FindKind(rkStrings, 0) = nil);
  FResView.aResNewManifest.Enabled := Can and (R.FindKind(rkManifest) = nil);
  FResView.aResImport.Enabled := Can;
  FResView.aResEdit.Enabled := Can and (It <> nil);
  FResView.aResEditHex.Enabled := Can and (It <> nil) and (It.Kind in [rkData, rkManifest]) and not It.IdeManifest;
  FResView.aResDelete.Enabled := Can and (It <> nil);
  FResView.aResRename.Enabled := Can and (It <> nil) and (It.Kind <> rkVersion) and not It.IdeManifest;
  FResView.aResExport.Enabled := (It <> nil) and (It.Kind <> rkStrings);
end;

{ after a command: the view again with Key's resource chosen }
procedure TMainForm.ResourceDone(const Key: string);
begin
  RefreshResourceView(Key);
  UpdateResourceActions;
end;

{ ---------------------------------------------------------------- the resources' pages }

{ the resources of a project's .res: the Resources view's (the active project's), else made for
  the call (Own: the caller frees them) }
function TMainForm.ResourcesOf(const ProjectFile: string; out Own: Boolean): TSdResources;
begin
  Own := False;
  Result := FResView.Resources;
  if (Result <> nil) and SameText(Result.ProjectFile, ProjectFile) then Exit;
  Result := TSdResources.Create(ProjectFile);
  Own := True;
  Result.Refresh;
end;

function TMainForm.FindResPage(const ProjectFile, Key: string): TSdResPage;
var
  I: Integer;
begin
  for I := 0 to FDocs.Count - 1 do
    if TObject(FDocs[I]) is TSdResPage then
    begin
      Result := TSdResPage(FDocs[I]);
      if SameText(Result.ProjectFile, ProjectFile) and (Result.Key = Key) then Exit;
    end;
  Result := nil;
end;

{ a resource in its page of the file area (Hex: its bytes). Edit shows the page open already as
  it is; Edit as Hex shows its bytes - a page with another editor of it goes first, its changes
  saved or let go (Cancel: it stays). Raises what keeps the page from being made }
function TMainForm.OpenResPage(R: TSdResources; It: TSdResItem; Hex: Boolean): TSdResPage;
var
  Key: string;
begin
  Key := It.Key;
  Result := FindResPage(R.ProjectFile, Key);
  if Result <> nil then
  begin
    if not Hex or (Result.EditorKind = reHex) or not ConfirmSave(Result) then
    begin
      ActivatePage(Result);
      Exit;
    end;
    LeavePage(Result, False);
    { a save refreshed the resources' items: the item again }
    It := R.FindKey(Key);
    if It = nil then
    begin
      Result := nil;
      Exit;
    end;
  end;
  Result := MakeResPage(R, It, Hex, 0);
  ActivatePage(Result);
end;

{ New String Table: the page of a table the file does not have yet - written when it is saved
  with strings }
function TMainForm.OpenNewStringTable(R: TSdResources; Language: Integer): TSdResPage;
begin
  Result := FindResPage(R.ProjectFile, StringTableKey(Language));
  if Result = nil then Result := MakeResPage(R, nil, False, Language);
  ActivatePage(Result);
end;

{ a new page of a resource, with its tab: It's editor (Hex: its bytes), or with It nil the new
  string table of Language; raises what keeps it from being made (the page goes again) }
function TMainForm.MakeResPage(R: TSdResources; It: TSdResItem; Hex: Boolean; Language: Integer): TSdResPage;
begin
  Result := TSdResPage.Create(Self);
  AddPageTab(Result);
  try
    if It <> nil then Result.Open(R, It, Hex) else Result.OpenStrings(R, Language);
  except
    FreeAndNil(Result);
    raise;
  end;
  AddDoc(Result);
end;

{ Save: a resource page's edits into its project's .res (what keeps them from it is said, the
  editor shows the place); the Resources view shows them }
function TMainForm.SaveResPage(P: TSdResPage): Boolean;
var
  R: TSdResources;
  Own: Boolean;
  Msg, Key: string;
begin
  Result := False;
  Msg := P.CheckSave(True);
  if Msg <> '' then
  begin
    if P.ResKind = rkManifest then
      Msg := Format('The manifest is not saved - %s.'#13#10#13#10'Windows does not start a program whose ' +
        'manifest it cannot read.', [Msg])
    else
      Msg := Format('%s is not saved: %s', [P.Title, Msg]);
    MessageBox(Handle, PChar(Msg), 'Save', MB_OK or MB_ICONWARNING);
    Exit;
  end;
  R := ResourcesOf(P.ProjectFile, Own);
  try
    if not R.CanWrite then
      raise EInOutError.CreateFmt('%s is no 32-bit resource file: it is not changed.', [ExtractFileName(R.ResFile)]);
    Key := P.ApplyTo(R, True);
    P.Saved(Key);
    Result := True;
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), PChar(P.Title), MB_OK or MB_ICONERROR);
  end;
  if Own then R.Free;
  UpdatePageTab(P);
  UpdateStatus;
  if (FProject <> nil) and SameText(P.ProjectFile, FProject.FileName) then ResourceDone(P.Key);
end;

{ a compile of a project whose resources have unsaved pages: its .res as it would be with them
  ('' none) - a copy of the file's entries, which is not written (the scratch build takes it).
  What would keep a page from being saved is a warning of the compile (a manifest Windows
  cannot read) }
function TMainForm.UnsavedResources(const ProjectFile: string; Warnings: TStrings): string;
var
  I: Integer;
  P: TSdResPage;
  ResCopy: IOTAProjectResource;
  R: TSdResources;
  Msg: string;
begin
  Result := '';
  ResCopy := nil;
  R := nil;
  try
    for I := 0 to FDocs.Count - 1 do
    begin
      if not (TObject(FDocs[I]) is TSdResPage) then Continue;
      P := TSdResPage(FDocs[I]);
      if not SameText(P.ProjectFile, ProjectFile) or not P.Modified then Continue;
      if R = nil then
      begin
        ResCopy := OtaModules.ProjectResourceCopy(ProjectFile);
        if ResCopy = nil then Exit;
        R := TSdResources.CreateOn(ProjectFile, ResCopy);
        R.Refresh;
        if not R.CanWrite then Exit;
      end;
      Msg := P.CheckSave(False);
      if Msg <> '' then
        Warnings.Add(Format('[Warning] %s: %s - %s', [ExtractFileName(P.ResFile), P.Title, Msg]));
      P.ApplyTo(R, False);
    end;
    if R <> nil then Result := (ResCopy as ISdResFile).ResFileBytes;
  finally
    R.Free;
  end;
end;

{ Add: a new bitmap, icon or cursor (its size and colours asked; written, then its page), string
  table (its page: written when it is saved with strings), manifest (the one Project Options would
  write, as the project's own; written, then its page) }
procedure TMainForm.AddResource(Kind: TSdResKind);
const
  IconSet: array[0..4] of Integer = (16, 24, 32, 48, 256);
var
  R: TSdResources;
  Bits, I: Integer;
  Sizes: TSdSizes;
  Scale: Boolean;
  Img: TSdImage;
  Images: TList;
  Key: string;
begin
  R := FResView.Resources;
  if R = nil then Exit;
  Key := '';
  try
    case Kind of
      rkBitmap, rkIcon, rkCursor:
        begin
          { a bitmap 32 x 32 at 24 bits, an icon the usual sizes, a cursor 32 x 32 - at first }
          if Kind = rkIcon then
          begin
            SetLength(Sizes, Length(IconSet));
            for I := 0 to High(IconSet) do Sizes[I] := Point(IconSet[I], IconSet[I]);
          end
          else
          begin
            SetLength(Sizes, 1);
            Sizes[0] := Point(32, 32);
          end;
          if Kind = rkBitmap then Bits := 24 else Bits := 32;
          Scale := False;
          if not NewImageDialog(Self, ResImageKind(Kind), Sizes, Bits, False, Scale) then Exit;
          Images := TList.Create;
          try
            for I := 0 to High(Sizes) do
            begin
              Img := TSdImage.Create(Sizes[I].X, Sizes[I].Y, Bits);
              Images.Add(Img);
              if Kind = rkBitmap then
                FillChar(Img.Pixels[0], Length(Img.Pixels) * 4, $FF)     // white
              else
                Img.Png := (Img.Width >= 256) and (Img.Height >= 256) and (Bits = 32);
            end;
            if Kind = rkBitmap then Key := R.AddBitmap(R.NewName(rkBitmap), TSdImage(Images[0]))
            else Key := R.AddImages(Kind, R.NewName(Kind), Images);
          finally
            for I := 0 to Images.Count - 1 do TObject(Images[I]).Free;
            Images.Free;
          end;
          ResourceDone(Key);
          EditResource(False);
          Exit;
        end;
      rkStrings:
        begin
          { its page: the table is written when it is saved with strings }
          OpenNewStringTable(R, 0);
          Exit;
        end;
      rkManifest:
        begin
          Key := R.AddData(RT_MANIFEST_ID, '', '1', OwnManifestText(FProject));
          ResourceDone(Key);
          EditResource(False);
          Exit;
        end;
    end;
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), 'Resources', MB_OK or MB_ICONERROR);
  end;
  ResourceDone(Key);
end;

procedure TMainForm.ImportResource;
var
  R: TSdResources;
  FileName, Key: string;
begin
  R := FResView.Resources;
  if R = nil then Exit;
  FileName := '';
  if not BrowseFile('Import Resource', 'Resource files (*.bmp;*.ico;*.cur;*.manifest;*.png)|' +
    '*.bmp;*.ico;*.cur;*.manifest;*.png|All files (*.*)|*.*', FileName) then Exit;
  Key := '';
  try
    Key := R.Import(FileName, ReadFileU(FileName));
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), 'Import Resource', MB_OK or MB_ICONERROR);
  end;
  ResourceDone(Key);
end;

{ Edit: the chosen resource in its page of the file area (SdResPage) - a bitmap, an icon or a
  cursor in the image editor, a string table in its editor, a manifest of the project's own and
  data that is text in the text editor, other data (and with Hex any data or such a manifest) in
  the hex editor; what Project Options writes (the version information, D7 Studio's manifest) in
  Project Options }
procedure TMainForm.EditResource(Hex: Boolean);
var
  R: TSdResources;
  It: TSdResItem;
  Title: string;
begin
  R := FResView.Resources;
  It := FResView.Selected;
  if (R = nil) or (It = nil) then Exit;
  if not Hex then
    case It.Kind of
      rkVersion:
        begin
          ShowProjectOptions(ProjOptionsVersionPage);
          Exit;
        end;
      rkManifest:
        if It.IdeManifest then
        begin
          ShowProjectOptions(ProjOptionsApplicationPage);
          Exit;
        end;
    end;
  Title := ResourceTitle(It);
  try
    OpenResPage(R, It, Hex);
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), PChar(Title), MB_OK or MB_ICONERROR);
  end;
end;

{ Delete, asked first. The version information is taken out by switching Project | Options |
  Version Info off, D7 Studio's manifest by switching off what it is for - else the next compile
  would write them again. The resource's page closes with it }
procedure TMainForm.DeleteResource;
var
  R: TSdResources;
  It: TSdResItem;
  Msg, Key: string;
  Page: TSdResPage;
begin
  R := FResView.Resources;
  It := FResView.Selected;
  if (R = nil) or (It = nil) or (FProject = nil) then Exit;
  Key := It.Key;
  if It.Kind = rkVersion then
    Msg := 'Delete the version information? Project | Options | Version Info | Include version information is ' +
      'switched off.'
  else if It.IdeManifest then
    Msg := 'Delete the manifest? Project | Options | Application: the runtime themes and the DPI awareness are ' +
      'switched off, and Target Windows takes the system code page.'
  else if It.Kind in [rkIcon, rkCursor] then
    Msg := Format('Delete %s with its images?', [ResourceTitle(It)])
  else
    Msg := Format('Delete %s?', [ResourceTitle(It)]);
  if MessageBox(Handle, PChar(Msg), 'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  { the items are made anew when the view is refreshed (an activation of the IDE while the box
    was shown): the item again by its key }
  It := R.FindKey(Key);
  if It = nil then
  begin
    ResourceDone('');
    Exit;
  end;
  try
    if It.Kind = rkVersion then
    begin
      FProject.SetOptInt('Version Info', 'IncludeVerInfo', 0);
      FProject.SaveOptions;
      UpdateVersionInfo(FProject, False);
    end
    else
    begin
      if It.IdeManifest then
      begin
        FProject.SetOptInt(ThemeSection, ThemeKey, 0);
        if FProject.TargetWindows = twWindows10Utf8 then FProject.SetTargetWindows(twVista);
        FProject.SetDpiAwareness(daUnaware);
        FProject.SetExecutionLevel(elAsInvoker);
        FProject.SaveOptions;
      end;
      R.Delete(It);
    end;
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), 'Resources', MB_OK or MB_ICONERROR);
  end;
  Page := FindResPage(R.ProjectFile, Key);
  if Page <> nil then CloseDoc(Page, False);
  ResourceDone('');
end;

{ Properties: the type (data only), the name, the language }
function TMainForm.ResPropsCheck(const AType, AName: string; Language: Integer; var Bad: Integer): string;
var
  R: TSdResources;
  It, Other: TSdResItem;
begin
  Result := '';
  R := FResView.Resources;
  if R = nil then Exit;
  It := R.FindKey(FResPropsKey);
  if It = nil then Exit;
  if It.Kind = rkStrings then
  begin
    Other := R.FindKind(rkStrings, Language);
    Bad := 2;
    if (Other <> nil) and (Other <> It) then Result := 'There is a string table in that language already.';
    Exit;
  end;
  if It.Kind = rkData then
  begin
    Bad := 0;
    Result := R.CheckType(AType);
    if Result <> '' then Exit;
  end;
  Bad := 1;
  Result := R.CheckName(AName, 'The name');
  if (Result = '') and R.Taken(It, AType, AName, Language) then
    Result := Format('There is a resource %s %s in that language already.', [It.TypeText, UpperCase(AName)]);
end;

procedure TMainForm.RenameResource;
var
  R: TSdResources;
  It: TSdResItem;
  T, N, Key, OldKey: string;
  Lang: Integer;
  Page: TSdResPage;
begin
  R := FResView.Resources;
  It := FResView.Selected;
  if (R = nil) or (It = nil) then Exit;
  T := It.TypeText;
  N := It.NameText;
  if It.Kind = rkStrings then N := '';
  Lang := It.Language;
  { the items are made anew when the view is refreshed (an activation of the IDE while the
    dialog is shown): the item by its key, during the dialog and after it }
  OldKey := It.Key;
  FResPropsKey := OldKey;
  try
    if not ResPropsDialog(Self, 'Properties of ' + ResourceTitle(It), It.Kind = rkData, It.Kind <> rkStrings,
      T, N, Lang, ResPropsCheck) then Exit;
  finally
    FResPropsKey := '';
  end;
  It := R.FindKey(OldKey);
  if It = nil then Exit;
  Key := OldKey;
  try
    Key := R.Rename(It, T, N, Lang);
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), 'Resources', MB_OK or MB_ICONERROR);
  end;
  ResourceDone(Key);
  { its page has its new name }
  Page := FindResPage(R.ProjectFile, OldKey);
  It := R.FindKey(Key);
  if (Page <> nil) and (It <> nil) and (Key <> OldKey) then
  begin
    Page.Renamed(It);
    UpdatePageTab(Page);
  end;
end;

{ Export: the resource as a file - a bitmap .bmp, an icon .ico, a cursor .cur, a manifest
  .manifest, data as it is }
procedure TMainForm.ExportResource;
var
  R: TSdResources;
  It: TSdResItem;
  Bytes, Ext, FileName: string;
begin
  R := FResView.Resources;
  It := FResView.Selected;
  if (R = nil) or (It = nil) then Exit;
  try
    Bytes := R.ExportData(It, Ext);
    FileName := It.NameText + Ext;
    if not BrowseFile('Export ' + ResourceTitle(It), Format('%s files (*%s)|*%s|All files (*.*)|*.*',
      [UpperCase(Copy(Ext, 2, MaxInt)), Ext, Ext]), FileName, bfSave, Copy(Ext, 2, MaxInt)) then Exit;
    WriteFileU(FileName, Bytes);
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message), 'Export', MB_OK or MB_ICONERROR);
  end;
end;

{ the Resources view's commands: its tool bar (Add | Edit, Delete | Export), its menu and the
  Add menu }
procedure TMainForm.ActResources(Sender: TObject);
var
  P: TPoint;
begin
  if Sender = aResAdd then
  begin
    { the kinds to add, under the tool button (from the view's menu: its Add submenu) }
    P := FResView.tbResAdd.ClientToScreen(Point(0, FResView.tbResAdd.Height));
    FResView.ResAddMenu.Popup(P.X, P.Y);
  end
  else if Sender = FResView.aResNewBitmap then AddResource(rkBitmap)
  else if Sender = FResView.aResNewIcon then AddResource(rkIcon)
  else if Sender = FResView.aResNewCursor then AddResource(rkCursor)
  else if Sender = FResView.aResNewStrings then AddResource(rkStrings)
  else if Sender = FResView.aResNewManifest then AddResource(rkManifest)
  else if Sender = FResView.aResImport then ImportResource
  else if Sender = FResView.aResEdit then EditResource(False)
  else if Sender = FResView.aResEditHex then EditResource(True)
  else if Sender = FResView.aResDelete then DeleteResource
  else if Sender = FResView.aResRename then RenameResource
  else if Sender = FResView.aResExport then ExportResource
  else if Sender = FResView.aResStatusBar then FResPanel.ShowStatus := not FResPanel.ShowStatus;
end;


function TMainForm.ProjectAddUnit(const FileName: string): Boolean;
begin
  Result := ProjectAddUnitTo(FProject, FileName, UnitFormName(FileName));
end;

{ a unit into P, a project of the group (the active one, or another: the Open Tools API's
  IOTAProject.AddFile, a creator's owner) - its uses clause, a package's contains clause }
function TMainForm.ProjectAddUnitTo(P: TSdProject; const FileName, FormName: string): Boolean;
var
  Src, Rel: string;
begin
  Result := False;
  if P = nil then Exit;
  if P.IsPackage then
  begin
    Result := AddUnitToPackage(P, FileName, P.SearchPathList);
    if Result then OtaProjectFileChanged(FileName, True);
    Exit;
  end;
  if not ProjectSourceName(P, FileName, Rel) then Exit;
  Src := SourceOf(P.FileName);
  Result := DprAddUnit(Src, ChangeFileExt(ExtractFileName(FileName), ''), Rel, FormName);
  if Result then
  begin
    ProjectSourceChangedOf(P, Src);
    OtaProjectFileChanged(FileName, True);
  end;
end;

function TMainForm.ProjectAddResScriptTo(P: TSdProject; const FileName: string): Boolean;
var
  Src, Old, Rel: string;
begin
  Result := False;
  if P = nil then Exit;
  if not ProjectSourceName(P, FileName, Rel) then Exit;
  Src := SourceOf(P.FileName);
  Old := Src;
  Result := DprAddResScript(Src, ChangeFileExt(Rel, '.res'), Rel);
  if Result and (Src <> Old) then
  begin
    ProjectSourceChangedOf(P, Src);
    OtaProjectFileChanged(FileName, True);
  end;
end;

{ a unit out of the active project (its file stays): its entry and its form's CreateForm }
procedure TMainForm.RemoveProjectUnit(U: TProjectUnit);
begin
  RemoveProjectUnitOf(FProject, U);
end;

{ ... out of P, the project U is a unit of; a resource script (TProjectResScript): its $R }
procedure TMainForm.RemoveProjectUnitOf(P: TSdProject; U: TProjectUnit);
var
  Src, UnitName, FormName, FileName: string;
begin
  if (P = nil) or (U = nil) then Exit;
  UnitName := U.Name;                  // U goes when the source is parsed again
  FormName := U.FormName;
  FileName := U.FileName;
  Src := SourceOf(P.FileName);
  if U is TProjectResScript then
    DprRemoveResScript(Src, TProjectResScript(U).RelRc)
  else
  begin
    DprRemoveUnit(Src, UnitName);
    if FormName <> '' then DprRemoveCreateForm(Src, FormName);
  end;
  ProjectSourceChangedOf(P, Src);
  OtaProjectFileChanged(FileName, False);
end;

{ the Project Manager's Save on a project (Delphi's TStdProjectContainer.SaveProject, the project
  active or not): its modified pages - its project file, its units, its resources' - and its
  options }
function TMainForm.SaveProject(P: TSdProject): Boolean;
var
  I: Integer;
  D: TWinControl;
  F: string;
  L: TList;
begin
  Result := True;
  L := TList.Create;
  try
    for I := 0 to FDocs.Count - 1 do
    begin
      D := TWinControl(FDocs[I]);
      if not DocModified(D) then Continue;
      if D is TSdResPage then
      begin
        if SameText(TSdResPage(D).ProjectFile, P.FileName) then L.Add(D);
        Continue;
      end;
      if TEditorPage(D).FormOwner <> nil then F := TEditorPage(D).FormOwner.FileName
      else F := TEditorPage(D).FileName;
      if SameText(F, P.FileName) or (P.FindUnit(F) <> nil) or (P.FindResScript(F) <> nil) then L.Add(D);
    end;
    for I := 0 to L.Count - 1 do
      if (FDocs.IndexOf(L[I]) >= 0) and DocModified(TWinControl(L[I])) and not SaveDoc(TWinControl(L[I])) then
        Result := False;
  finally
    L.Free;
  end;
  try
    P.SaveOptions;
  except
    on E: EInOutError do
    begin
      MessageBox(Handle, PChar(E.Message), AppTitle, MB_OK or MB_ICONERROR);
      Result := False;
    end;
  end;
end;

{ a project's source in the code editor (Project | View Source, the Project Manager's) }
procedure TMainForm.ViewProjectSource(P: TSdProject);
var
  Page: TEditorPage;
begin
  if P = nil then Exit;
  Page := OpenFile(P.FileName, True);
  if Page <> nil then Page.ShowDesign(False);
end;

procedure TMainForm.ActProject(Sender: TObject);
var
  I, Idx: Integer;
  L: TStringList;
begin
  if FProject = nil then Exit;
  if Sender = ProjectAddCommand then
  begin
    L := TStringList.Create;
    try
      if not BrowseFiles('Add to Project', 'Delphi unit (*.pas)|*.pas|Resource script (*.rc)|*.rc', L,
        FProject.Dir) then Exit;
      for I := 0 to L.Count - 1 do
        if SameText(ExtractFileExt(L[I]), '.rc') then ProjectAddResScriptTo(FProject, L[I])
        else ProjectAddUnit(L[I]);
    finally
      L.Free;
    end;
  end
  else if Sender = ProjectRemoveCommand then
  begin
    { the units, then the resource scripts by their file names }
    L := TStringList.Create;
    try
      for I := 0 to FProject.UnitCount - 1 do L.AddObject(FProject.Units[I].Name, FProject.Units[I]);
      for I := 0 to FProject.ResScriptCount - 1 do L.AddObject(FProject.ResScripts[I].Name, FProject.ResScripts[I]);
      Idx := 0;
      if FProjView.SelectedUnit <> nil then Idx := L.IndexOfObject(FProjView.SelectedUnit);
      if (L.Count > 0) and ListDialog(Self, 'Remove From Project', L, Idx) then
        RemoveProjectUnit(TProjectUnit(L.Objects[Idx]));
    finally
      L.Free;
    end;
  end
  else if Sender = ProjectViewSourceCommand then ViewProjectSource(FProject)
  else if Sender = ProjectCompileCommand then DoCompile(False, False, False)
  else if Sender = ProjectBuildCommand then DoCompile(True, False, False)
  else if (Sender = ProjectCompileAllCommand) or (Sender = ProjectBuildAllCommand) then CompileAllProjects(Sender = ProjectBuildAllCommand)
  else if Sender = ProjectSyntaxCommand then DoCompile(False, False, True)
  else if Sender = ProjectInformationCommand then ShowProjectInfo
  else if Sender = aInstallPackage then InstallPackageProject(FProject)
  else if Sender = aUninstallPackage then UninstallPackageOf(FProject)
  else if Sender = ProjectOptionsCommand then
    ShowProjectOptions(0);
end;

{ Project | Options (and Component | Install Packages: its Packages page); without a project
  the default options }
procedure TMainForm.ShowProjectOptions(Page: Integer);
begin
  ShowProjectOptionsOf(FProject, Page);
end;

{ the options of P, a project of the group - the active one, or another (the Project Manager's
  Options, an expert's IOTAProjectOptions.EditOptions); nil: the default options }
procedure TMainForm.ShowProjectOptionsOf(P: TSdProject; Page: Integer);
var
  Src, Old, OldVersion: string;
begin
  { Version Info shows the version resource the program gets (an expert may have changed it), and
    a change made there goes into the .res at once - a compile keeps the one the .res has }
  if P <> nil then
    try
      VersionInfoFromRes(P);
    except
      on EInOutError do ;
    end;
  OldVersion := VersionOptionsText(P);
  if P <> nil then Src := SourceOf(P.FileName) else Src := '';
  Old := Src;
  if not ProjectOptionsDialog(Self, P, Page, Src) then
  begin
    { Packages | Edit: the package opens as File | Open opens it (Delphi's TPackageInstall.
      EditButtonClick: beside an open group) }
    if PackageToEdit <> '' then OpenProject(PackageToEdit);
  end
  else if P <> nil then
  begin
    if VersionOptionsText(P) <> OldVersion then UpdateVersionInfo(P, False);
    { the Forms page edits the Application.CreateForm lines of the project source }
    if Src <> Old then SetProjectSourceOf(P, Src);
    ConfigureCodeInsight;
    RefreshProjectTree;           // the target platform is shown at the project
  end;
end;

{ The program Run starts: the project's own, or for a library or package the host application
  of Run | Parameters (asked for before anything is compiled) }
function TMainForm.RunTarget(var Exe: string): Boolean;
var
  Kind: string;
begin
  Exe := FProject.OptStr('Parameters', 'HostApplication', '');
  Result := (Exe <> '') or not (FProject.IsLibrary or FProject.IsPackage);
  if not Result then
  begin
    if FProject.IsPackage then Kind := 'package' else Kind := 'library';
    MessageBox(Handle, PChar(Format('Cannot run a %s project without a host application (Run | Parameters).',
      [Kind])), AppTitle, MB_OK or MB_ICONINFORMATION);
  end
  else if Exe = '' then
    Exe := FProject.ExeName;
end;

{ Run | Run Without Debugging: compiles, then starts the program (or the host application) }
function TMainForm.RunWithoutDebugging: Boolean;
var
  Exe, Params, Path, WorkDir, Env, Cmd: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
begin
  Result := False;
  if (FProject = nil) or not RunTarget(Exe) or not DoCompile(False, False, False, True) then Exit;
  Params := FProject.OptStr('Parameters', 'RunParams', '');
  { a Win64 program built with run-time packages finds them in RAD Studio's bin64 (the
    program inherits the PATH of the IDE) }
  if (FProject.Platform = spWin64) and (FProject.OptInt('Directories', 'UsePackages', 0) <> 0) and
    (Win64PackageDir <> '') then
  begin
    Path := GetEnvironmentVariable('PATH');
    if not PathHasDir(Path, Win64PackageDir) then
      SetEnvironmentVariable('PATH', PChar(Path + ';' + Win64PackageDir));
  end;
  WorkDir := FProject.OptStr('Parameters', 'DebugCWD', '');
  if WorkDir = '' then WorkDir := ExtractFilePath(Exe);
  Env := ProjectEnvironment(FProject);
  if Env = '' then
    Result := ShellExecute(Handle, 'open', PChar(Exe), PChar(Params), PChar(WorkDir), SW_SHOWNORMAL) > 32
  else
  begin
    { an environment of its own: CreateProcess (ShellExecute passes the IDE's) }
    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(SI);
    Cmd := '"' + Exe + '" ' + Params;
    UniqueString(Cmd);
    Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, PChar(Env), PChar(WorkDir), SI, PI);
    if Result then
    begin
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  end;
  if not Result then
    MessageBox(Handle, PChar('Cannot run ' + Exe + BlockedExeHint(Exe, SysErrorMessage(GetLastError))),
      AppTitle, MB_OK or MB_ICONERROR);
end;

procedure TMainForm.ActRun(Sender: TObject);
var
  P: TEditorPage;
  Kind: TDbgBPKind;
  Added: Boolean;
  S: string;
begin
  P := ActivePage;
  { a command given in the CPU view's disassembly keeps the keyboard there when the program
    stops (Delphi's CPU window stays active; the stop shows the source line all the same) }
  FCpuStepping := FDebug.Paused and FCpuView.DisasmFocused;
  if (Sender = RunRunCommand) and (FProject <> nil) and (FProject.Platform = spWin64) and not FDebug.Active then
  begin
    { the integrated debugger is a 32-bit debugger }
    if RunWithoutDebugging then
      AddMessage('Win64: the program runs without the integrated debugger (it debugs 32-bit programs only).', nil);
  end
  else if Sender = RunRunCommand then
  begin
    if FDebug.Paused then FDebug.Resume
    else if not FDebug.Active then StartDebug(False);
  end
  else if Sender = RunRunNoDebugCommand then
    RunWithoutDebugging
  else if Sender = RunAttachCommand then AttachToProcess
  else if Sender = RunDetachCommand then FDebug.Detach
  else if Sender = RunParametersCommand then
  begin
    { Run | Parameters; Load starts the program under the debugger, stopped at its entry }
    if (FProject <> nil) and (RunParamsDialog(Self, FProject) = rpLoad) and not FDebug.Active then
      StartDebug(True);
  end
  else if ((Sender = RunStepOverCommand) or (Sender = RunTraceIntoCommand)) and FDebug.Paused and FCpuView.DisasmFocused then
    { in the CPU view's disassembly: one machine instruction (Delphi's) }
    FDebug.StepInstruction(Sender = RunStepOverCommand)
  else if Sender = RunTraceToSourceCommand then
  begin
    if FDebug.Paused then FDebug.TraceToSource
    else if not FDebug.Active then StartDebug(True);
  end
  else if Sender = aGotoAddress then CpuGotoAddress(nil)
  else if Sender = RunStepOverCommand then
  begin
    if FDebug.Paused then FDebug.StepOver
    else if not FDebug.Active then StartDebug(True);
  end
  else if Sender = RunTraceIntoCommand then
  begin
    if FDebug.Paused then FDebug.StepInto
    else if not FDebug.Active then StartDebug(True);
  end
  else if Sender = RunGotoCursorCommand then
  begin
    if (P <> nil) and FDebug.Paused then
    begin
      ClearExecMarkers;
      FDebug.RunToLine(P.FileName, P.Editor.CaretLine + 1);
    end;
  end
  else if Sender = RunUntilReturnCommand then FDebug.StepOut
  else if Sender = RunPauseCommand then FDebug.Pause
  else if Sender = RunResetCommand then FDebug.Stop
  else if Sender = RunEvalModCommand then
    FDebug.EvaluateDialog(CursorExpression(P))
  else if Sender = RunAddWatchCommand then
  begin
    FDebug.AddWatch(CursorExpression(P));
    ShowBottom(BT_WATCHES);
  end
  else if Sender = RunInspectCommand then
  begin
    S := CursorExpression(P);
    if InputDialog(Self, 'Inspect', '&Expression:', S) and (Trim(S) <> '') then InspectExpression(Trim(S));
  end
  else if Sender = aToggleBreak then
  begin
    { in the CPU view's disassembly: an address breakpoint on the chosen instruction (Delphi's) }
    if FDebug.Paused and FCpuView.DisasmFocused then FDebug.ToggleAddressBreakpoint(FCpuView.SelectedAddress)
    else if (P <> nil) and P.CodeView then FServices.ToggleBreakpoint(P, P.Editor.CaretLine + 1);
  end
  else if Sender = RunShowCSIPCommand then
  begin
    if FDebug.Paused and (FDebug.ExecFile <> '') then FServices.OpenFileAt(FDebug.ExecFile, FDebug.ExecLine, 1);
  end
  else if (Sender = RunAddSourceBreakpointCommand) or (Sender = RunAddAddressBreakpointCommand) or (Sender = RunAddDataBreakpointCommand) or (Sender = RunAddModuleLoadBreakpointCommand) then
  begin
    if Sender = RunAddSourceBreakpointCommand then Kind := bkSource
    else if Sender = RunAddAddressBreakpointCommand then Kind := bkAddress
    else if Sender = RunAddDataBreakpointCommand then Kind := bkData
    else Kind := bkModule;
    if (P <> nil) and P.CodeView then
      Added := FDebug.AddBreakpointDialog(Kind, P.FileName, P.Editor.CaretLine + 1)
    else
      Added := FDebug.AddBreakpointDialog(Kind, '', 0);
    if Added then ShowBottom(BT_BREAKS);
  end
  else if Sender = RunRegisterComCommand then RegisterServer(False)
  else if Sender = RunUnregisterComCommand then RegisterServer(True)
  else if Sender = FWatchView.aWatchNew then
    FDebug.AddWatch('')
  else if Sender = FWatchView.aWatchDelete then
    FDebug.DeleteSelectedWatch;
end;

{ Component | Install Component, as in Delphi 7: the unit goes into the contains clause of an
  existing package or of a new one, which is then built and installed. Offered
  packages: the recent ones of this command, the open project when it is a package, Delphi's
  own Lib\dclusr.dpk ("Borland User Components", its default). UnitFile: the unit offered (an
  import's), else the active page's. The package opens first, as Delphi 7 opens its package
  editor: it joins the group (a group of its own when none is open) as the active project - a
  package open beside the group becomes the active project where it is -, its package editor shows
  it, and it stays open whatever the build does. }
procedure TMainForm.InstallComponent(const UnitFile: string);
const
  Section = 'Install Component';
var
  Info: TInstallCompInfo;
  L: TStringList;
  P: TSdProject;
  I: Integer;
begin
  L := TStringList.Create;
  try
    GetRecent(Section, L);
    if (FProject <> nil) and FProject.IsPackage then L.Add(FProject.FileName);
    L.Add(DelphiRoot + 'Lib\dclusr.dpk');
    for I := L.Count - 1 downto 0 do
      if not FileExists(L[I]) or (L.IndexOf(L[I]) < I) then L.Delete(I);
    FillChar(Info, SizeOf(Info), 0);
    if L.Count > 0 then Info.PackageFile := L[0];
    if UnitFile <> '' then Info.UnitFile := UnitFile
    else if (ActivePage <> nil) and SameText(ExtractFileExt(ActivePage.FileName), '.pas') then
      Info.UnitFile := ActivePage.FileName;
    if not InstallComponentDialog(Self, L, Info) then Exit;
  finally
    L.Free;
  end;
  if Info.NewPackage then
    WriteFileU(Info.PackageFile, NewFileBytes(NewPackageSource(ChangeFileExt(ExtractFileName(Info.PackageFile), ''),
      Info.Description, 'rtl,vcl')));
  AddRecent(Section, Info.PackageFile);
  { not opened or not activated (a compile runs, the file cannot be read, an expert refused it):
    OpenProject has said why. A package open beside the group is activated where it is }
  if FGroup.IndexOfBeside(Info.PackageFile) >= 0 then ActivateProject(Info.PackageFile)
  else OpenProject(Info.PackageFile, omAddToGroup);
  P := FGroup.LoadedProjectOf(Info.PackageFile);
  if (P = nil) or (P <> FProject) then Exit;
  ShowPackageEditor(P);
  if not AddUnitToPackage(P, Info.UnitFile, Info.SearchPath) then Exit;
  if MessageBox(Handle, PChar(Format('Package %s will be built then installed. Continue?',
    [ExtractFileName(P.ExeName)])), 'Confirm', MB_YESNO or MB_ICONQUESTION) = IDYES then
    InstallPackageProject(P);
end;

const
  ImportSection = 'Import Type Library';

function ImportPageKey(ActiveX: Boolean): string;
begin
  if ActiveX then Result := 'OcxPage' else Result := 'ServerPage';
end;

{ Import Type Library's and Import ActiveX's values of the last time (unit folder, palette page,
  search path, wrappers), the palette pages and the library files added with Add... }
procedure TMainForm.LoadImportInfo(ActiveX: Boolean; var Info: TImportTLBInfo; Pages, Added: TStrings);
var
  I: Integer;
  Dir: string;
begin
  if FProject <> nil then Dir := ExcludeTrailingPathDelimiter(FProject.Dir) else Dir := SettingsDir + 'Imports';
  Info.Name := '';
  Info.FileName := '';
  Info.UnitDir := Settings.ReadString(ImportSection, 'UnitDir', Dir);
  if ActiveX then Info.PalettePage := Settings.ReadString(ImportSection, ImportPageKey(ActiveX), 'ActiveX')
  else Info.PalettePage := Settings.ReadString(ImportSection, ImportPageKey(ActiveX), 'Servers');
  Info.SearchPath := Settings.ReadString(ImportSection, 'SearchPath', '');
  Info.Wrappers := Settings.ReadBool(ImportSection, 'Wrappers', True);
  Info.Install := False;
  for I := 0 to DesignHost.PageCount - 1 do Pages.Add(DesignHost.Pages[I].Name);
  if Pages.IndexOf(Info.PalettePage) < 0 then Pages.Add(Info.PalettePage);
  Added.Text := StringReplace(Settings.ReadString(ImportSection, 'Added', ''), ';', #13#10, [rfReplaceAll]);
end;

{ ... kept for the next time: the files added, and the values when one was Chosen (the search
  path is Import's own: the caller keeps it) }
procedure TMainForm.SaveImportInfo(ActiveX: Boolean; const Info: TImportTLBInfo; Added: TStrings; Chosen: Boolean);
begin
  Settings.WriteString(ImportSection, 'Added', StringReplace(Trim(Added.Text), #13#10, ';', [rfReplaceAll]));
  if not Chosen then Exit;
  Settings.WriteString(ImportSection, 'UnitDir', Info.UnitDir);
  Settings.WriteString(ImportSection, ImportPageKey(ActiveX), Info.PalettePage);
  if not ActiveX then Settings.WriteBool(ImportSection, 'Wrappers', Info.Wrappers);
end;

{ the units of the library chosen and of the libraries it needs, written to the unit folder;
  the library's unit, '' when nothing was written }
function TMainForm.ImportTypeLibUnit(ActiveX: Boolean; const Info: TImportTLBInfo): string;
var
  Ref: TTypeLibRef;
  TL: ITypeLib;
  O: TTLBOptions;
begin
  Ref := TTypeLibRef.Create;
  try
    Ref.Guid := Info.Guid;
    Ref.Major := Info.Major;
    Ref.Minor := Info.Minor;
    Ref.Lcid := Info.Lcid;
    Ref.FileName := Info.FileName;
    TL := LoadTypeLibraryRef(Ref);
  finally
    Ref.Free;
  end;
  O.Wrappers := Info.Wrappers and not ActiveX;
  O.ControlsOnly := ActiveX;
  O.PalettePage := Info.PalettePage;
  O.Safecall := EnvOptions.TLSafeCall;
  Result := WriteTypeLibUnits(TL, O, Info.UnitDir);
end;

{ Project | Import Type Library, Component | Import ActiveX Control: the units of the library chosen and
  of the libraries it needs go to the unit
  folder (SdTypeLib); Create Unit adds the library's unit to the open project and shows it,
  Install... puts it into a package as Component | Install Component does }
procedure TMainForm.ImportTypeLibrary(ActiveX: Boolean);
var
  Info: TImportTLBInfo;
  Pages, Added: TStringList;
  OK: Boolean;
  Main, F, Src, Rel: string;
begin
  Pages := TStringList.Create;
  Added := TStringList.Create;
  try
    LoadImportInfo(ActiveX, Info, Pages, Added);
    OK := ImportTypeLibDialog(Self, ActiveX, Pages, Added, Info);
    SaveImportInfo(ActiveX, Info, Added, OK);
    if not OK then Exit;
    Settings.WriteString(ImportSection, 'SearchPath', Info.SearchPath);
    F := ImportTypeLibUnit(ActiveX, Info);
    if F = '' then Exit;
    Main := ChangeFileExt(ExtractFileName(F), '');
    if Info.Install then
      InstallComponent(F)
    else
    begin
      if (FProject <> nil) and (FProject.FindUnitByName(Main) = nil) then
      begin
        Src := ProjectSource;
        if ProjectSourceName(FProject, F, Rel) and DprAddUnit(Src, Main, Rel, '') then
          ProjectSourceChanged(Src);
      end;
      OpenFile(F, True);
    end;
  finally
    Added.Free;
    Pages.Free;
  end;
end;

{ the units of a type library and of the libraries it needs, written to UnitDir (asked first
  when some are there already); the library's unit, '' when nothing was written }
function TMainForm.WriteTypeLibUnits(TL: ITypeLib; const Options: TTLBOptions; const UnitDir: string): string;
var
  Imp: TTLBImport;
  Existing: TStringList;
  Dir, Main: string;
  I: Integer;
begin
  Result := '';
  Imp := TTLBImport.Create(Options);
  Existing := TStringList.Create;
  try
    Screen.Cursor := crHourGlass;
    try
      Main := Imp.Import(TL);
    finally
      Screen.Cursor := crDefault;
    end;
    Dir := IncludeTrailingPathDelimiter(UnitDir);
    ForceDirectories(Dir);
    for I := 0 to Imp.Count - 1 do
      if FileExistsU(Dir + Imp.UnitName(I) + '.pas') then Existing.Add(Imp.UnitName(I) + '.pas');
    if (Existing.Count > 0) and (MessageBox(Handle, PChar(Format('%s already in %s. Overwrite?',
      [StringReplace(Trim(Existing.Text), #13#10, ', ', [rfReplaceAll]), Dir])), 'Confirm',
      MB_YESNO or MB_ICONQUESTION) <> IDYES) then Exit;
    for I := 0 to Imp.Count - 1 do WriteFileU(Dir + Imp.UnitName(I) + '.pas', Imp.Source(I));
    Result := Dir + Main + '.pas';
  finally
    Existing.Free;
    Imp.Free;
  end;
end;

{ a type library in the Type Library view (its file holds none: a message). The view's library
  is a module of the Open Tools API: the experts hear it open, and the library shown before close
  (its module goes) }
function TMainForm.OpenTypeLibrary(const FileName: string): Boolean;
var
  Old: string;
  Same: Boolean;
begin
  Result := False;
  Old := FTypeLibView.FileName;
  Same := SameText(Old, FileName);
  if not Same and not OtaFileNotification(ofnFileOpening, FileName) then Exit;
  try
    FTypeLibView.Open(FileName);
  except
    on E: Exception do
    begin
      MessageBox(Handle, PChar(Format('%s holds no type library (%s).', [FileName, E.Message])),
        'Type Library', MB_OK or MB_ICONERROR);
      Exit;
    end;
  end;
  if not Same then
  begin
    if Old <> '' then
    begin
      OtaFileNotification(ofnFileClosing, Old);
      OtaModules.Forget(Old);
    end;
    OtaFileNotification(ofnFileOpened, FileName);
  end;
  ShowDockPanel(FTypeLibPanel);
  Result := True;
end;

{ View | Type Library: the library shown, else the project's (<project>.tlb), else one chosen;
  the view's Open, Save as Unit (the units, as Import Type Library writes them), Refresh }
procedure TMainForm.ActTypeLib(Sender: TObject);
var
  F, Dir: string;
  O: TTLBOptions;
begin
  F := '';
  if (Sender = ViewTypeLibraryCommand) and (FTypeLibView.FileName <> '') then
  begin
    ViewDockPanel(FTypeLibPanel);
    Exit;
  end;
  if (Sender = ViewTypeLibraryCommand) and (FProject <> nil) and FileExists(ChangeFileExt(FProject.FileName, '.tlb')) then
    F := ChangeFileExt(FProject.FileName, '.tlb')
  else if (Sender = ViewTypeLibraryCommand) or (Sender = FTypeLibView.aTlOpen) then
  begin
    if not BrowseFile('Open Type Library',
      'Type Library (*.tlb;*.olb;*.dll;*.ocx;*.exe)|*.tlb;*.olb;*.dll;*.ocx;*.exe|Any File (*.*)|*.*', F) then Exit;
  end
  else if Sender = FTypeLibView.aTlRefresh then
    F := FTypeLibView.FileName
  else if Sender = FTypeLibView.aTlExport then
  begin
    if FTypeLibView.TypeLib = nil then Exit;
    if FProject <> nil then Dir := FProject.Dir else Dir := ExtractFilePath(FTypeLibView.FileName);
    Dir := Settings.ReadString(ImportSection, 'UnitDir', ExcludeTrailingPathDelimiter(Dir));
    if not BrowseFolder('Save as Unit', '', Dir) then Exit;
    O.Wrappers := Settings.ReadBool(ImportSection, 'Wrappers', True);
    O.ControlsOnly := False;
    O.PalettePage := Settings.ReadString(ImportSection, ImportPageKey(False), 'Servers');
    O.Safecall := EnvOptions.TLSafeCall;
    F := WriteTypeLibUnits(FTypeLibView.TypeLib, O, Dir);
    if F <> '' then OpenFile(F, True);
    Exit;
  end;
  { OpenTypeLibrary shows the view; View | Type Library gives it the keyboard too }
  if (F <> '') and OpenTypeLibrary(F) and (Sender = ViewTypeLibraryCommand) then FDock.FocusPanel(FTypeLibPanel);
end;

procedure TMainForm.ActImport(Sender: TObject);
begin
  ImportTypeLibrary(Sender = ComponentImportAXCCommand);
end;

procedure TMainForm.ActTools(Sender: TObject);
begin
  if Sender = ComponentAddtoPackageCommand then
    InstallComponent
  else if Sender = ComponentInstallPackagesCommand then
    ShowProjectOptions(ProjOptionsPackagesPage)
  else if Sender = ToolsOptionsCommand then
    ShowOptions(osEnvironment)
  else if Sender = ComponentPaletteCommand then
    ShowOptions(osEnvironment, EnvOptionsPalettePage)     // Environment Options | Palette
  else if Sender = ToolsEditorOptionsCommand then
    ShowOptions(osEditor)
  else if Sender = ToolsDebuggerOptionsCommand then
    ShowOptions(osDebugger)
  else if Sender = aFormatterOptions then
    ShowOptions(osFormatter)
  else if Sender = ToolsToolsCommand then
    ConfigureToolsDialog(Self)
  else if Sender = ComponentNewCommand then
    NewComponent
  else if Sender = HelpAboutCommand then
    AboutDialog(Self)
  else if Sender = aCheckUpdates then
    CheckForUpdates(True);
end;

{ Edit | Format Source (Ctrl+D) and Project | Format Project Sources }
procedure TMainForm.ActFormat(Sender: TObject);
var
  P: TEditorPage;
  Msg: string;
begin
  if Sender = aFormatProject then
  begin
    FormatProjectSources;
    Exit;
  end;
  P := ActivePage;
  if (P = nil) or not P.CodeView then Exit;
  Msg := P.FormatSource(True);
  if Msg <> '' then MessageBox(Handle, PChar(Msg), AppTitle, MB_OK or MB_ICONWARNING);
  UpdateStatus;
end;

procedure TMainForm.FormatProjectSources;
var
  Files, Problems: TStringList;
  I, Changed: Integer;
  F, Text, Bytes, Msg: string;
  P: TEditorPage;
  Kind: TFmtFileKind;
  R: TFmtResult;
  E: TSdEncoding;
begin
  if FProject = nil then Exit;
  Files := TStringList.Create;
  Problems := TStringList.Create;
  try
    Files.Add(FProject.FileName);
    for I := 0 to FProject.UnitCount - 1 do
    begin
      Files.Add(FProject.Units[I].FileName);
      { a form is its unit's while the unit is open (the designer writes it in Delphi's layout) }
      if FormatterOptions.FormFiles and FProject.Units[I].HasForm and (FindPage(FProject.Units[I].FileName) = nil) and
        FileExistsU(FProject.Units[I].FormFileName) then
        Files.Add(FProject.Units[I].FormFileName);
    end;
    if FormatterOptions.Confirm and (MessageBox(Handle, PChar(Format('Format the %d source files of %s with ' +
      'the formatter options? Files open in the editor are formatted there; the others are written now.',
      [Files.Count, ExtractFileName(FProject.FileName)])), AppTitle, MB_YESNO or MB_ICONQUESTION) <> IDYES) then Exit;
    Changed := 0;
    for I := 0 to Files.Count - 1 do
    begin
      F := Files[I];
      Kind := FmtFileKind(F);
      if Kind = ffNone then Continue;
      P := FindPage(F);
      if P <> nil then
      begin
        if not P.CanFormat then Continue;
        Msg := P.FormatSource(False);
        if Msg <> '' then Problems.Add(ExtractFileName(F) + ': ' + Msg);
        Continue;
      end;
      if not FileExistsU(F) then Continue;
      try
        Bytes := ReadFileU(F);
        if (Kind = ffForm) and DfmIsBinary(Bytes) then Continue;       // binary: nothing to lay out
        E := FileEncoding(F, Bytes);
        Text := DecodeFile(Bytes, E, False);
        if not FormatText(Kind, Text, -1, -1, R, Msg) then
        begin
          Problems.Add(ExtractFileName(F) + ': ' + Msg);
          Continue;
        end;
        if R.Output = Text then Continue;
        RewriteSourceFile(F, R.Output, E, 'Format Project');
        Inc(Changed);
        if FCodeInsight <> nil then FCodeInsight.InvalidateFile(F);
      except
        on Ex: Exception do Problems.Add(ExtractFileName(F) + ': ' + Ex.Message);
      end;
    end;
    Msg := Format('%d of %d files formatted on the disk; open files were formatted in their editors.',
      [Changed, Files.Count]);
    if Problems.Count > 0 then Msg := Msg + #13#10#13#10 + Problems.Text;
    if Problems.Count > 0 then MessageBox(Handle, PChar(Msg), AppTitle, MB_OK or MB_ICONWARNING)
    else MessageBox(Handle, PChar(Msg), AppTitle, MB_OK or MB_ICONINFORMATION);
  finally
    Problems.Free;
    Files.Free;
  end;
  UpdateStatus;
end;

{ File | Reopen with Encoding (the bytes read again) and Convert to Encoding (the text kept,
  written in the new encoding) }
procedure TMainForm.ActEncoding(Sender: TObject);
var
  P: TEditorPage;
  L, Names: TStringList;
  I, Idx: Integer;
  E: TSdEncoding;
  Title: string;
  Lost: Boolean;
begin
  P := ActivePage;
  if P = nil then Exit;
  L := TStringList.Create;
  Names := TStringList.Create;
  try
    GetEncodingList(L);
    Idx := 0;
    for I := 0 to L.Count - 1 do
    begin
      Names.Add(L.Names[I]);
      if SameEncoding(EncodingFromListValue(L.ValueFromIndex[I]), P.Encoding) then Idx := I;
    end;
    if Sender = aReopenEncoding then Title := 'Reopen with Encoding' else Title := 'Convert to Encoding';
    if not ListDialog(Self, Title, Names, Idx) then Exit;
    E := EncodingFromListValue(L.ValueFromIndex[Idx]);
    if Sender = aReopenEncoding then
    begin
      if P.Modified and (MessageBox(Handle, PChar(Format('%s has unsaved changes. Read it again from ' +
        'the disk as %s and lose them?', [ExtractFileName(P.FileName), EncodingName(E)])), AppTitle,
        MB_YESNO or MB_ICONWARNING) <> IDYES) then Exit;
      { the page is read again, its markers with it: the breakpoints come back from the engine
        (as ReloadPage does) }
      SyncBreakpoints(P);
      P.ReopenWithEncoding(E);
      RefreshBreakMarkers(P);
    end
    else
    begin
      if SameEncoding(E, P.Encoding) then Exit;
      if not P.Editor.ConversionLoss(E, Lost) then
      begin
        MessageBox(Handle, PChar(Format('Windows cannot convert %s to %s; it stays as it is.',
          [ExtractFileName(P.FileName), EncodingName(E)])), AppTitle, MB_OK or MB_ICONERROR);
        Exit;
      end;
      if Lost and (MessageBox(Handle, PChar(Format('Some characters of %s cannot be ' +
        'written as %s and will become "?". Convert anyway?', [ExtractFileName(P.FileName), EncodingName(E)])),
        AppTitle, MB_YESNO or MB_ICONWARNING) <> IDYES) then Exit;
      P.ConvertToEncoding(E);
    end;
    UpdatePageTab(P);
    UpdateStatus;
  finally
    Names.Free;
    L.Free;
  end;
end;

end.
