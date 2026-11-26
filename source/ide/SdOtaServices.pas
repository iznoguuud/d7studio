{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaServices;

{ D7 Studio - the Open Tools API's services: BorlandIDEServices, as Delphi 7's IDE
  gives it to the packages and DLLs that extend it.

  * The root object answers IBorlandIDEServices; every service is an aggregated object of its own
    (their methods share names - AddNotifier, GetEditOptions ...), found by QueryInterface on the
    root, and each one finds the others through it:
      IOTAServices (IDE notifiers, the folders, the registry key), INTAServices (main menu, action
      list, image list, tool bar), IOTAWizardServices, IOTAModuleServices + IOTAActionServices,
      IOTAEditorServices, IOTAMessageServices (message groups: tabs of the Messages view),
      IOTAKeyboardServices (key bindings of the code editor), IOTAPackageServices,
      IOTADebuggerServices (SdOtaDebug), IOTAToDoServices (SdOtaToDo), IOTACodeInsightServices
      (SdOtaCodeInsight).
  * Wizards: what a package registers (RegisterPackageWizard - SdDesignHost passes it on) and
    what a DLL expert registers through its entry point INITWIZARD0001 (Delphi 1-3's experts,
    INITEXPERT0017 and RegisterLibraryExpert: SdOtaLegacy - as wizards too); the DLLs are named in
    D7 Studio's registry key, Wizards and Experts (Delphi's layout), or in [Wizards] and [Experts]
    of the settings.
    IOTAMenuWizard: an item of the Help menu (an action of WizardActions); IOTARepositoryWizard:
    an item of File | New | Other. A package that is unloaded takes its wizards, notifiers and key
    bindings with it (OtaPackageUnloading), before its code goes.
  * Packages that use BorlandIDEServices load after the main window is there
    (TDesignHost.LoadDeferredPackages): an expert adds its menus in its constructor.
  * The IDE tells the services what happens (the Ota* routines below): files opening and closing,
    compiles, the debugger, packages - and the experts' notifiers hear it. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, Graphics, Menus, ActnList, ImgList, ComCtrls,
  StdCtrls, ToolsAPI, SdOtaCore, SdOtaModules, SdOtaDebug, SdProject, SdSciEdit, SdEditorPage,
  SdMessageView, SdKeymaps;

type
  { a message of the Open Tools API in the Messages view: the main window's double click on
    Build finds its file and line as a compiler message's }
  TSdOtaMessage = class(TCompilerMessage)
  public
    Parent: TSdOtaMessage;
    Level: Integer;
    Compiler: Boolean;      // AddCompilerMessage: one of the compiler's (ClearCompilerMessages)
    { AddCustomMessage: the expert's message - its text read when its row is drawn (Text keeps
      the text it had), drawn by it (INTACustomDrawMessage), F1 its ShowHelp; nil once its
      package went }
    Custom: IOTACustomMessage;
    CustomDraw: INTACustomDrawMessage;
    DrawFailed: Boolean;    // its Draw raised: drawn as text from then on
    ChildCount: Integer;    // the messages under it
    Expanded: Boolean;      // its children are rows of the list (Delphi's tree: closed when added)
  end;

{ BorlandIDEServices made (the units' initialisation: before any package loads) }
procedure InstallIDEServices;
{ the main window is there (OtaHost set): the messages view taken, the menu wizards' items made }
procedure OtaHostReady(View: TSdMessageView);
{ the main window is Application.MainForm (its CreateForm returned): Delphi 1-3's version control
  manager and the experts' DLLs load - as in Delphi 7, whose experts look for the main form while
  they start (GExperts asserts it) }
procedure OtaLoadExperts;

var
  { called after each expert DLL has started (the start-up screen lays out what it put on it) }
  OtaExpertLoaded: procedure = nil;
{ D7 Studio ends: the wizards are told Destroyed, the DLL experts terminated and unloaded }
procedure OtaShutdown;
{ IOTAIDENotifier.FileNotification - False when an expert set Cancel }
function OtaFileNotification(Code: TOTAFileNotification; const FileName: string): Boolean;
{ IOTAIDENotifier.BeforeCompile (False: cancelled) / AfterCompile. A compile calls BeforeCompile
  after the IDE's own changes of the project's .res (the manifest, the version information) and
  writes the resources the experts changed then }
function OtaBeforeCompile(const ProjectFile: string): Boolean;
procedure OtaAfterCompile(Succeeded: Boolean);
{ the resources changed through the Open Tools API written, before the IDE changes a .res itself }
procedure OtaFlushResources;
{ the debugger's state / its breakpoints changed }
procedure OtaDebugStateChanged;
procedure OtaBreakpointsChanged;
{ the Build group was emptied by the IDE (a compile): the services' messages there go too }
procedure OtaBuildMessagesCleared;
{ ... a group's list (Messages' Clear Messages on it; 0 Build) }
procedure OtaMessageGroupCleared(Index: Integer);
{ File | New | Other: the repository wizards (IOTARepositoryWizard) }
procedure OtaRepositoryWizards(List: TInterfaceList);
procedure OtaExecuteWizard(const Wizard: IOTAWizard);
{ test mode: 'wizards=n menu=n experts=n bindings=n notifiers=n groups=... highlighters=active/dormant
  filters=n filesystems=n rec=state:items speed=settings:name' }
function OtaDebugText: string;
{ the rows of a list of the Messages view as the state dump shows them: a message with children
  '+' (closed) or '-' (open) before its text }
procedure OtaMessageRows(List: TListBox; Rows: TStrings);
{ the IDE's keystroke macro (Edit | Record Macro, Play Macro - Delphi's record of the keyboard
  services): Record starts and stops it, Play plays it in the active code editor; the state of
  the keyboard services' records - one records (not paused), one plays; the macro's items }
procedure OtaRecordMacro;
procedure OtaPlayMacro;
function OtaMacroRecording: Boolean;
function OtaMacroPlaying: Boolean;
function OtaMacroLength: Integer;
{ the experts of Delphi 1-3 (SdOtaLegacy) hear what the IDE does: a file added to (Added) or removed
  from the active project; the active project closed }
procedure OtaProjectFileChanged(const FileName: string; Added: Boolean);
procedure OtaProjectClosed;
{ test mode: the state dump's "legacy=" field and [legacy] lines (Delphi 1-3's experts); File | New
  | Other's item of a repository wizard named Name run as the dialog runs it (False: none) }
procedure OtaLegacyState(L: TStrings);
function OtaRunRepositoryWizard(const Name: string): Boolean;

implementation

uses
  Messages, Registry, Contnrs, TypInfo, Variants, SdDesignHost, SdSettings, SdDelphiDir, SdEnvOptions,
  SdEditorThemes, SdEditorOptions, SdIcons,
  SdFileNames, SdOtaDesktop, SdFormDesigner, SdOtaToDo, SdOtaCodeInsight, SdOtaHighlight, SdOtaSpeedSettings,
  SdOtaToolsFilter, SdOtaRecord, SdOtaFileSystems, SdPageFileSystem, SdUI, SdOtaLegacy, SdOtaEditWindow,
  SdTypeLib, Utf8Mode;

type
  TSdIDEServices = class;

  { a service: an aggregated object of the root }
  TSdOtaService = class(TAggregatedObject)
  protected
    function Root: TSdIDEServices;
  end;

  TSdOtaGeneral = class(TSdOtaService, IOTAServices50, IOTAServices60, IOTAServices)
  private
    FNotifiers: TSdNotifierList;
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    function AddNotifier(const Notifier: IOTAIDENotifier): Integer;
    procedure RemoveNotifier(Index: Integer);
    function GetBaseRegistryKey: string;
    function GetProductIdentifier: string;
    function GetParentHandle: HWND;
    function GetEnvironmentOptions: IOTAEnvironmentOptions;
    function GetActiveDesignerType: string;
    function GetRootDirectory: string;
    function GetBinDirectory: string;
    function GetTemplateDirectory: string;
  end;

  TSdOtaNta = class(TSdOtaService, INTAServices40, INTAServices)
  private
    FIdents: TStringList;            // AddMasked's Ident -> image index (Objects)
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    function AddMasked(Image: TBitmap; MaskColor: TColor): Integer; overload;
    function AddMasked(Image: TBitmap; MaskColor: TColor; const Ident: string): Integer; overload;
    function GetActionList: TCustomActionList;
    function GetImageList: TCustomImageList;
    function GetMainMenu: TMainMenu;
    function GetToolBar(const ToolBarName: string): TToolBar;
  end;

  { an IOTAMenuWizard's command: an action of the main window, its item in the Help menu }
  TSdWizardAction = class(TAction)
  private
    FWizard: IOTAWizard;
    FItem: TMenuItem;
    procedure DoExecute(Sender: TObject);
    procedure DoUpdate(Sender: TObject);
  public
    destructor Destroy; override;
  end;

  TSdOtaWizards = class(TSdOtaService, IOTAWizardServices)
  private
    FWizards: TSdNotifierList;
    FActions: TList;                 // TSdWizardAction of the menu wizards
    FExpertItems: Integer;           // ... of them Delphi 1-3's experts' (the first items)
    FSeparator: TMenuItem;           // the group's line where the menu has no anchor of its own
    function Anchor(Menu: TMenuItem; Make: Boolean): TMenuItem;
    procedure Install(const W: IOTAWizard);
    procedure Uninstall(const W: IOTAWizard);
    procedure DropWizard(Index: Integer; Tell: Boolean);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    procedure HostReady;
    procedure DropModule(Module: HMODULE);
    procedure Shutdown;
    function AddWizard(const AWizard: IOTAWizard): Integer;
    procedure RemoveWizard(Index: Integer);
  end;

  TSdOtaModuleServices = class(TSdOtaService, IOTAModuleServices, IOTAActionServices)
  private
    FFileSystems: TSdNotifierList;
    function CreateUnit(const C: IOTAModuleCreator): IOTAModule;
    function CreateProject(const C: IOTAProjectCreator): IOTAModule;
    function CreateGroup(const C: IOTAProjectGroupCreator): IOTAModule;
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    { the file system of the ID; nil: none (FindFileSystem raises then) }
    function FileSystemOf(const Name: string): IOTAFileSystem;
    { IOTAModuleServices }
    function AddFileSystem(FileSystem: IOTAFileSystem): Integer;
    function CloseAll: Boolean;
    function CreateModule(const Creator: IOTACreator): IOTAModule;
    function CurrentModule: IOTAModule;
    function FindFileSystem(const Name: string): IOTAFileSystem;
    function FindFormModule(const FormName: string): IOTAModule;
    function FindModule(const FileName: string): IOTAModule;
    function GetModuleCount: Integer;
    function GetModule(Index: Integer): IOTAModule;
    procedure GetNewModuleAndClassName(const Prefix: string; var UnitIdent, ClassName, FileName: string);
    function NewModule: Boolean;
    procedure RemoveFileSystem(Index: Integer);
    function SaveAll: Boolean;
    { IOTAActionServices }
    function CloseFile(const FileName: string): Boolean;
    function OpenFile(const FileName: string): Boolean;
    function OpenProject(const ProjName: string; NewProjGroup: Boolean): Boolean;
    function ReloadFile(const FileName: string): Boolean;
    function SaveFile(const FileName: string): Boolean;
  end;

  TSdOtaEditorServices = class(TSdOtaService, IOTAEditorServices60, IOTAEditorServices)
  public
    function GetEditOptions: IOTAEditOptions; overload;
    function GetEditBufferIterator(out Iterator: IOTAEditBufferIterator): Boolean;
    function GetKeyboardServices: IOTAKeyboardServices;
    function GetTopBuffer: IOTAEditBuffer;
    function GetTopView: IOTAEditView;
    function GetEditOptions(const IDString: string): IOTAEditOptions; overload;
    function GetEditOptionsForFile(const FileName: string): IOTAEditOptions;
    function AddEditOptions(const IDString: string): IOTAEditOptions;
    procedure DeleteEditOptions(const IDString: string);
    function GetEditOptionsCount: Integer;
    function GetEditOptionsIndex(Index: Integer): IOTAEditOptions;
  end;

  TSdOtaBufferIterator = class(TInterfacedObject, IOTAEditBufferIterator)
  private
    FBuffers: TInterfaceList;
  public
    constructor Create;
    destructor Destroy; override;
    function GetCount: Integer;
    function GetEditBuffer(Index: Integer): IOTAEditBuffer;
  end;

  TSdOtaMessageGroup = class(TInterfacedObject, IOTAMessageGroup)
  private
    FName: string;
    FMessages: TObjectList;          // TSdOtaMessage, owned
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function GetGroupName: string;
  end;

  TSdOtaMessages = class(TSdOtaService, IOTAMessageServices40, IOTAMessageServices50,
    IOTAMessageServices60, IOTAMessageServices)
  private
    FGroups: TList;                  // TSdOtaMessageGroup, Build first (the view's order) ...
    FGroupRefs: TInterfaceList;      // ... their references
    FNotifiers: TSdNotifierList;
    FView: TSdMessageView;
    function GroupObj(const G: IOTAMessageGroup): TSdOtaMessageGroup;
    function List(Index: Integer): TListBox;
    function Add(const G: IOTAMessageGroup; M: TSdOtaMessage; Parent: Pointer): Pointer;
    function NewCustom(const C: IOTACustomMessage): TSdOtaMessage;
    procedure AddCustomChildren(const G: IOTAMessageGroup; P: TSdOtaMessage; const C: IOTACustomMessage50);
    procedure ClearGroup(Index: Integer; ToolOnly: Boolean);
    { ClearGroup on the group of G, on every group when G is nil }
    procedure ClearGroups(const G: IOTAMessageGroup; ToolOnly: Boolean);
    procedure GroupDblClick(Sender: TObject);
    procedure Notify(const G: IOTAMessageGroup; Added: Boolean);
    procedure SetupList(L: TListBox);
    procedure DrawMessage(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    function GroupOfList(L: TListBox): TSdOtaMessageGroup;
    procedure InsertChildren(L: TListBox; G: TSdOtaMessageGroup; P: TSdOtaMessage; var At: Integer);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    procedure AttachView(View: TSdMessageView);
    { the IDE ends: the lists draw and take keys as plain lists again, nothing of the experts' is
      called from them }
    procedure DetachView;
    procedure GroupCleared(Index: Integer);
    function DebugText: string;
    { a message with children in L opened or closed (its row Row) }
    procedure Toggle(L: TListBox; Row: Integer);
    { the experts' messages of a package that goes keep their texts, nothing of the package's is
      called any more }
    procedure DropModule(Module: HMODULE);
    { IOTAMessageServices40 }
    procedure AddCustomMessage(const CustomMsg: IOTACustomMessage); overload;
    procedure AddTitleMessage(const MessageStr: string); overload;
    procedure AddToolMessage(const FileName, MessageStr, PrefixStr: string;
      LineNumber, ColumnNumber: Integer); overload;
    procedure ClearAllMessages;
    procedure ClearCompilerMessages;
    procedure ClearSearchMessages;
    procedure ClearToolMessages; overload;
    { IOTAMessageServices50 }
    procedure AddToolMessage(const FileName, MessageStr, PrefixStr: string;
      LineNumber, ColumnNumber: Integer; Parent: Pointer; out LineRef: Pointer); overload;
    { IOTAMessageServices60 }
    function AddNotifier(const ANotifier: IOTAMessageNotifier): Integer;
    procedure RemoveNotifier(Index: Integer);
    function AddMessageGroup(const GroupName: string): IOTAMessageGroup;
    procedure AddCustomMessage(const CustomMsg: IOTACustomMessage;
      const MessageGroupIntf: IOTAMessageGroup); overload;
    procedure AddTitleMessage(const MessageStr: string; const MessageGroupIntf: IOTAMessageGroup); overload;
    procedure AddToolMessage(const FileName, MessageStr, PrefixStr: string;
      LineNumber, ColumnNumber: Integer; Parent: Pointer; out LineRef: Pointer;
      const MessageGroupIntf: IOTAMessageGroup); overload;
    procedure ClearMessageGroup(const MessageGroupIntf: IOTAMessageGroup);
    procedure ClearToolMessages(const MessageGroupIntf: IOTAMessageGroup); overload;
    function GetMessageGroupCount: Integer;
    function GetMessageGroup(Index: Integer): IOTAMessageGroup;
    function GetGroup(const GroupName: string): IOTAMessageGroup;
    procedure ShowMessageView(const MessageGroupIntf: IOTAMessageGroup);
    procedure RemoveMessageGroup(const MessageGroupIntf: IOTAMessageGroup);
    { IOTAMessageServices }
    procedure AddCompilerMessage(const FileName, MessageStr, ToolName: string;
      Kind: TOTAMessageKind; LineNumber, ColumnNumber: Integer;
      Parent: Pointer; out LineRef: Pointer); overload;
  end;

  { a key binding an expert made: keys, its procedure, the binding (IOTAKeyboardBinding) it came
    with, the keyboard it belongs to ('' the editor's) }
  { a binding of IOTAKeyBindingServices: keys, a menu command (AddMenuCommand) or the default
    procedure of a keyboard (SetDefaultKeyProc) }
  TSdKeyBindKind = (kbKeys, kbMenuCommand, kbDefault);
  TShortCutArray = array of TShortCut;

  TSdKeyBind = class
  public
    Kind: TSdKeyBindKind;
    Keys: TShortCutArray;
    Command: string;                 // kbMenuCommand: Delphi's name (mcClipCopy ...)
    Proc: TKeyBindingProc;
    Context: Pointer;
    Flags: TKeyBindingFlags;
    Keyboard: string;
    Owner: Integer;                  // the index AddKeyboardBinding returned
    Id: Integer;
  end;

  TSdOtaKeyboard = class(TSdOtaService, IOTAKeyboardServices, IOTAKeyboardDiagnostics)
  private
    FBindings: TSdNotifierList;      // IOTAKeyboardBinding
    FKeys: TObjectList;              // TSdKeyBind, the newest last
    FKeyboards: TStringList;         // the pushed keyboards
    FPending: TShortCutArray;        // the keys so far of an expert's sequence
    FIdeCmds: array of TEdCmd;       // the IDE's key mapping as binding records (LookupKeyBinding):
    FIdeArgs: array of Integer;      // ... their commands, Context = index + 1
    FProcessed: LongWord;
    FTracing: Boolean;
    FNextId: Integer;
    FOldExecute: TActionEvent;       // the main action list's OnExecute before the menu commands'
    FIdeRecord: IOTARecord;          // the IDE's own keystroke macro (Shift+Ctrl+R / Shift+Ctrl+P)
    FRecord: IOTARecord;             // the record keys go into (CurrentRecord; nil: none yet)
    FPlayback: IOTARecord;           // the record played last (CurrentPlayback)
    FInKey: Integer;                 // a key of a code editor is handled while one records
    function Matches(B: TSdKeyBind; Index: Integer; Key: TShortCut): Boolean;
    function Active(B: TSdKeyBind): Boolean;
    function FindNext(FromIndex, KeyCount: Integer; const Keys: array of TShortCut): Integer;
    function BindById(Id: Integer): TSdKeyBind;
    function StartsSequence(const Keys: array of TShortCut): Boolean;
    function DefaultBind: TSdKeyBind;
    function Call(B: TSdKeyBind; Key: TShortCut; Page: TEditorPage): TKeyBindingResult;
    function BindRec(B: TSdKeyBind; out Rec: TKeyBindingRec): Boolean;
    function IdeRec(const Keys: array of TShortCut; out Rec: TKeyBindingRec): Boolean;
    procedure IdeKeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut;
      var BindingResult: TKeyBindingResult);
    function NewBind(Owner: Integer; Kind: TSdKeyBindKind; Proc: TKeyBindingProc; Context: Pointer): TSdKeyBind;
    procedure ActionExecute(Action: TBasicAction; var Handled: Boolean);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    function EditorKey(Ed: TSciEdit; Key: Word; Shift: TShiftState; InChord: Boolean): TSciKeyHookResult;
    function EditorMenuCommand(Ed: TSciEdit; const Command: string): Boolean;
    function AddBind(Owner: Integer; const Keys: array of TShortCut; Proc: TKeyBindingProc;
      Context: Pointer; Flags: TKeyBindingFlags; const Keyboard: string): Boolean;
    function AddMenuCommand(Owner: Integer; const Command: string; Proc: TKeyBindingProc; Context: Pointer): Boolean;
    procedure SetDefaultKeyProc(Owner: Integer; Proc: TKeyBindingProc; Context: Pointer; const Keyboard: string);
    { the main action list's commands that are Delphi's menu commands (mcClipCopy ...) go to an
      expert's procedure first (AddMenuCommand) }
    procedure HookActions(List: TActionList);
    procedure DropModule(Module: HMODULE);
    function BindingCount: Integer;
    { the keystroke macros (Delphi's Kbclient.TKeyboardServices): RecordKeyMacro starts R - or
      stops the current record, a toggle -, PlayKeyMacro plays R key by key in the active code
      editor; the editor's keys and characters while a record records }
    procedure RecordKeyMacro(const R: IOTARecord);
    procedure PlayKeyMacro(const R: IOTARecord);
    function Recording: Boolean;
    function Playing: Boolean;
    function PageEditor(Ed: TSciEdit): Boolean;
    function MacroKeyStart(Ed: TSciEdit): Boolean;
    procedure MacroKeyEnd(Ed: TSciEdit; Key: Word; Shift: TShiftState; Add: Boolean);
    procedure MacroChar(Ed: TSciEdit; Ch: Char);
    function PlayCommand(Ed: TSciEdit; const Name: string): Boolean;
    function RecordDebugText: string;
    { IOTAKeyboardServices }
    function AddKeyboardBinding(const KeyBinding: IOTAKeyboardBinding): Integer;
    function GetCurrentPlayback: IOTARecord;
    function GetCurrentRecord: IOTARecord;
    function GetEditorServices: IOTAEditorServices;
    function GetKeysProcessed: LongWord;
    function NewRecordObject(out ARecord: IOTARecord): Boolean;
    procedure PausePlayback;
    procedure PauseRecord;
    procedure PopKeyboard(const Keyboard: string);
    function PushKeyboard(const Keyboard: string): string;
    procedure RestartKeyboardServices;
    procedure ResumePlayback;
    procedure ResumeRecord;
    procedure RemoveKeyboardBinding(Index: Integer);
    procedure SetPlaybackObject(const ARecord: IOTARecord);
    procedure SetRecordObject(const ARecord: IOTARecord);
    function LookupKeyBinding(const Keys: array of TShortCut; out BindingRec: TKeyBindingRec;
      const KeyBoard: string = ''): Boolean;
    function GetNextBindingRec(var BindingRec: TKeyBindingRec): Boolean;
    function CallKeyBindingProc(const BindingRec: TKeyBindingRec): TKeyBindingResult;
    { IOTAKeyboardDiagnostics }
    function GetKeyTracing: Boolean;
    procedure SetKeyTracing(Value: Boolean);
  end;

  { what BindKeyboard gets: the bindings it adds belong to one IOTAKeyboardBinding }
  TSdOtaBindingServices = class(TInterfacedObject, IOTAKeyBindingServices)
  private
    FKeyboard: TSdOtaKeyboard;
    FOwner: Integer;
  public
    constructor Create(AKeyboard: TSdOtaKeyboard; AOwner: Integer);
    function AddKeyBinding(const Keys: array of TShortCut; KeyProc: TKeyBindingProc;
      Context: Pointer; Flags: TKeyBindingFlags = kfImplicitShift or kfImplicitModifier or
      kfImplicitKeypad; const Keyboard: string = ''; const MenuItemName: string = ''): Boolean;
    function AddMenuCommand(const Command: string; KeyProc: TKeyBindingProc; Context: Pointer): Boolean;
    procedure SetDefaultKeyProc(KeyProc: TKeyBindingProc; Context: Pointer; const Keyboard: string = '');
  end;

  TSdOtaKeyContext = class(TInterfacedObject, IOTAKeyContext)
  private
    FContext: Pointer;
    FBuffer: IOTAEditBuffer;
    FKeyboard: IOTAKeyboardServices;
    FRec: TKeyBindingRec;
  public
    constructor Create(AContext: Pointer; const ABuffer: IOTAEditBuffer;
      const AKeyboard: IOTAKeyboardServices; const ARec: TKeyBindingRec);
    function GetContext: Pointer;
    function GetEditBuffer: IOTAEditBuffer;
    function GetKeyboardServices: IOTAKeyboardServices;
    function GetKeyBindingRec(out BindingRec: TKeyBindingRec): Boolean;
  end;

  TSdOtaPackages = class(TSdOtaService, IOTAPackageServices)
  public
    function GetPackageCount: Integer;
    function GetPackageName(Index: Integer): string;
    function GetComponentCount(PkgIndex: Integer): Integer;
    function GetComponentName(PkgIndex, CompIndex: Integer): string;
  end;

  { Delphi's environment options that experts read: the library's paths and folders }
  TSdOtaEnvOptions = class(TInterfacedObject, IOTAOptions, IOTAEnvironmentOptions)
  public
    procedure EditOptions;
    function GetOptionValue(const ValueName: string): Variant;
    procedure SetOptionValue(const ValueName: string; const Value: Variant);
    function GetOptionNames: TOTAOptionNameArray;
  end;

  TSdIDEServices = class(TInterfacedObject, IInterface, IBorlandIDEServices)
  private
    FServices: TObjectList;          // the aggregated services, owned
    FGeneral: TSdOtaGeneral;
    FNta: TSdOtaNta;
    FWizards: TSdOtaWizards;
    FModules: TSdOtaModuleServices;
    FEditor: TSdOtaEditorServices;
    FMessages: TSdOtaMessages;
    FKeyboard: TSdOtaKeyboard;
    FPackages: TSdOtaPackages;
    FDebugger: TSdOtaDebuggerServices;
    FToDo: TSdOtaToDoServices;
    FCodeInsight: TSdOtaCodeInsightServices;
    FHighlight: TSdOtaHighlightServices;
    FToolsFilter: TSdOtaToolsFilter;
    FOldActiveFormChange: TNotifyEvent;
    procedure ActiveFormChange(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
  end;

  { a DLL expert (INITWIZARD0001, Delphi 1-3's INITEXPERT0017, or both) }
  TSdExpertDll = class
  public
    FileName: string;
    Module: HMODULE;
    Terminate: TWizardTerminateProc;
    OldTerminate: TWizardTerminateProc;   // INITEXPERT0017's (ExptIntf.TExpertTerminateProc)
  end;

var
  Services: TSdIDEServices;          // the root (BorlandIDEServices holds it)
  Experts: TObjectList;              // TSdExpertDll
  HostIsReady: Boolean;

{ ---------------------------------------------------------------- TSdOtaService }

function TSdOtaService.Root: TSdIDEServices;
begin
  Result := Services;
end;

{ ---------------------------------------------------------------- TSdIDEServices }

constructor TSdIDEServices.Create;
begin
  inherited Create;
  FServices := TObjectList.Create(True);
  FGeneral := TSdOtaGeneral.Create(Self);
  FServices.Add(FGeneral);
  FNta := TSdOtaNta.Create(Self);
  FServices.Add(FNta);
  FWizards := TSdOtaWizards.Create(Self);
  FServices.Add(FWizards);
  FModules := TSdOtaModuleServices.Create(Self);
  FServices.Add(FModules);
  FEditor := TSdOtaEditorServices.Create(Self);
  FServices.Add(FEditor);
  FMessages := TSdOtaMessages.Create(Self);
  FServices.Add(FMessages);
  FKeyboard := TSdOtaKeyboard.Create(Self);
  FServices.Add(FKeyboard);
  FPackages := TSdOtaPackages.Create(Self);
  FServices.Add(FPackages);
  FDebugger := TSdOtaDebuggerServices.Create(Self);
  FServices.Add(FDebugger);
  FToDo := TSdOtaToDoServices.Create(Self);
  FServices.Add(FToDo);
  FCodeInsight := TSdOtaCodeInsightServices.Create(Self);
  FServices.Add(FCodeInsight);
  FHighlight := TSdOtaHighlightServices.Create(Self);
  FServices.Add(FHighlight);
  { kept, not offered: Delphi 7's BorlandIDEServices has no IOTAToolsFilter }
  FToolsFilter := TSdOtaToolsFilter.Create(Self);
  FOldActiveFormChange := Screen.OnActiveFormChange;
  Screen.OnActiveFormChange := ActiveFormChange;
end;

destructor TSdIDEServices.Destroy;
begin
  { the last reference went (ToolsAPI's finalization at a Halt): nothing may reach it any more }
  if Services = Self then Services := nil;
  if Screen <> nil then Screen.OnActiveFormChange := FOldActiveFormChange;
  FServices.Free;
  FToolsFilter.Free;
  inherited;
end;

{ the root first, then each service: the interfaces of every service are the root's }
function TSdIDEServices.QueryInterface(const IID: TGUID; out Obj): HResult;
var
  I: Integer;
begin
  if GetInterface(IID, Obj) then
  begin
    Result := S_OK;
    Exit;
  end;
  for I := 0 to FServices.Count - 1 do
    if FServices[I].GetInterface(IID, Obj) then
    begin
      Result := S_OK;
      Exit;
    end;
  Result := E_NOINTERFACE;
end;

const
  CodeEditorCommand = 'Code Editor...';

{ A dialog became active: the string list editors' "Code Editor..." (a TStrings shown as a
  source module of a file system of their own) is disabled - D7 Studio has no such modules, and
  what was typed there would be lost. }
procedure TSdIDEServices.ActiveFormChange(Sender: TObject);
var
  F: TCustomForm;
  I: Integer;
  C: TComponent;
begin
  F := Screen.ActiveCustomForm;
  if F <> nil then
    for I := 0 to F.ComponentCount - 1 do
    begin
      C := F.Components[I];
      if (C is TButton) and (StripHotkey(TButton(C).Caption) = CodeEditorCommand) then
        TButton(C).Enabled := False
      else if (C is TMenuItem) and (StripHotkey(TMenuItem(C).Caption) = CodeEditorCommand) then
        TMenuItem(C).Enabled := False;
    end;
  if Assigned(FOldActiveFormChange) then FOldActiveFormChange(Sender);
end;

{ ---------------------------------------------------------------- IOTAServices }

constructor TSdOtaGeneral.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FNotifiers := TSdNotifierList.Create;
end;

destructor TSdOtaGeneral.Destroy;
begin
  FNotifiers.Free;
  inherited;
end;

function TSdOtaGeneral.AddNotifier(const Notifier: IOTAIDENotifier): Integer;
begin
  Result := FNotifiers.Add(Notifier);
end;

procedure TSdOtaGeneral.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

{ D7 Studio's own key, never Delphi's: an expert's settings stay with this IDE }
{ D7 Studio's own key, with the backslash in front that Delphi 7's has (measured) }
function TSdOtaGeneral.GetBaseRegistryKey: string;
begin
  Result := '\' + SettingsRegKey;
end;

function TSdOtaGeneral.GetProductIdentifier: string;
begin
  Result := 'Delphi';
end;

function TSdOtaGeneral.GetParentHandle: HWND;
begin
  Result := Application.Handle;
end;

function TSdOtaGeneral.GetEnvironmentOptions: IOTAEnvironmentOptions;
begin
  Result := TSdOtaEnvOptions.Create;
end;

function TSdOtaGeneral.GetActiveDesignerType: string;
begin
  Result := dVCL;
end;

function TSdOtaGeneral.GetRootDirectory: string;
begin
  Result := DelphiRoot;
end;

function TSdOtaGeneral.GetBinDirectory: string;
begin
  Result := DelphiBin;
end;

function TSdOtaGeneral.GetTemplateDirectory: string;
begin
  Result := DelphiRoot + 'ObjRepos\';
end;

{ ---------------------------------------------------------------- environment options }

const
  { Delphi 7's environment options as its IDE lists them (measured: GetOptionNames, in its order),
    "Name:kind" - b a Boolean, its value the string '-1' or '0'; e an enumeration, the string of
    its number; f a flag of the Color page's element (Whitespace: Plain text here), -1 or 0 as a
    number; n an enumeration as a number; i a number; s a string. The last are the Pascal file
    type's Source Options. }
  EnvOptionList =
    'BoldFont:f ItalicFont:f UnderlineFont:f UseDefaultForeground:f UseDefaultBackground:f InsertMode:b ' +
    'CursorInTabs:b GroupUndo:b CursorAfterEOF:b UndoAfterSave:b PersistentBlocks:b OverwriteBlocks:b ' +
    'DoubleClickLine:b FindTextAtCursor:b CutCopyEnabled:b UndoLimit:i BRIEFCursors:b CreateBackup:b ' +
    'ZoomFullScreen:b VisibleRightMargin:b RightMargin:i VisibleGutter:b GutterWidth:i EditorFont:s ' +
    'FontSize:i BRIEFRegEx:b EditorSpeedSetting:s EditorKeymapping:e ColorSpeedSetting:e ' +
    'EditorEmulation:s EditorOptionsSortPagesMenu:b PreserveLineEnds:b FindAutoCompletes:b ' +
    'AutoSaveEditorFiles:b AutoSaveDesktop:b AutoSaveSymbols:n DisplayGrid:b SnapToGrid:b ' +
    'ShowComponentCaptions:b GridSizeX:i GridSizeY:i ShowDesignerHints:b DFMAsText:b AutoCreateForms:b ' +
    'ShowExtendedControlHints:b ShowNonVisualComponents:b StepProgramBlock:b HideDesignersOnRun:b ' +
    'MinimizeOnRun:b ToolTipWatches:b DetailedExceptions:b ShowCompilerProgress:b ' +
    'WarnOnPackageRebuild:b CompileBeep:b CacheHeaders:b BackgroundCompilation:b ShowCommandLine:b ' +
    'RepositoryDir:s LibraryPath:s PackageDPLOutput:s PackageDCPOutput:s BrowsingPath:s ' +
    'PackageSearchPath:s NamespaceSearchPath:s CodeCompletion:b CodeParameters:b CodeCompleteDelay:i ' +
    'ScopeSort:b DeclarationInformation:b CodeCompleteHeight:i CodeCompleteWidth:i ' +
    'CodeCompleteAutoParens:b PaletteVisible:b SpeedbarVisible:b PaletteHints:b SpeedbarHints:b ' +
    'SplitPosition:i AutoDragDocking:b MainWindowSortWindowMenu:b MainWindowSortPaletteTabsMenu:b ' +
    'MainWindowShowWindowMenu:b HeaderPage:b LineNumbers:b SyntaxPrint:b UseColor:b WrapLines:b ' +
    'LeftMargin:i SearchCaseSensitive:b SearchWholeWords:b SearchRegularExp:b SearchForward:b ' +
    'SearchFromCursor:b SearchFileMask:s SearchIncludeSubDirs:b SearchGlobal:b ' +
    'SearchSeparateSearchResults:b ReplaceCaseSensitive:b ReplaceWholeWords:b ReplaceRegularExp:b ' +
    'ReplacePrompt:b ReplaceFromCursor:b ReplaceGlobal:b ReplaceForward:b ' +
    'ModuleExplorerHighlightIncomplete:b ModuleExplorerSorting:e ModuleExplorerExpanding:e ' +
    'ModuleExplorerGrouping:e ModuleExplorerCategorySort:s ModuleExplorerDeclarationSyntax:b ' +
    'ShowModExp:b BrowserLocation:s InitialView:e BrowserOptionsSymbolScope:e ' +
    'ClassCompletionBooleanProperties:b ClassCompletionBooleanCompleteNavigation:b ' +
    'ClassCompletionBooleanAddInterface:b ModuleExplorerPrivateVisible:b ModuleExplorerPrivateExpand:b ' +
    'ModuleExplorerPublicVisible:b ModuleExplorerPublicExpand:b ModuleExplorerProtectedVisible:b ' +
    'ModuleExplorerProtectedExpand:b ModuleExplorerPublishedVisible:b ModuleExplorerPublishedExpand:b ' +
    'ModuleExplorerMethodsVisible:b ModuleExplorerMethodsExpand:b ModuleExplorerPropertiesVisible:b ' +
    'ModuleExplorerPropertiesExpand:b ModuleExplorerFieldsVisible:b ModuleExplorerFieldsExpand:b ' +
    'ModuleExplorerClassesVisible:b ModuleExplorerClassesExpand:b ModuleExplorerInterfacesVisible:b ' +
    'ModuleExplorerInterfacesExpand:b ModuleExplorerProceduresVisible:b ModuleExplorerTypesVisible:b ' +
    'ModuleExplorerVariablesVisible:b ModuleExplorerProceduresExpand:b ModuleExplorerTypesExpand:b ' +
    'ModuleExplorerVariablesExpand:b ModuleExplorerUsesVisible:b ModuleExplorerUsesExpand:b ' +
    'ModuleExplorerCategoriesBooleanPropField2:b ModuleExplorerCategoriesBooleanPropField:b ' +
    'ModuleExplorerCategoriesBooleanPropField3:b ModuleExplorerCategoriesBooleanPropField4:b ' +
    'ModuleExplorerCategoriesBooleanPropField5:b ModuleExplorerCategoriesBooleanPropField7:b ' +
    'ModuleExplorerCategoriesBooleanPropField8:b ModuleExplorerCategoriesBooleanPropField9:b ' +
    'TlibEditLanguage:e SafeCallMapping:e ShowUpdatesUI:b IgnoreSpecialFlags:b MakeComponent:b ' +
    'IgnorePreDeclId:b IgnoreReserved:b IgnoreHidden:b IgnoreCanCreate:b DispInterfInControlWrappers:b ' +
    'MsStylePropGetSet:b CppChangeSuffixInCompWrap:b CppOcXSuffix:s ImplementBase:b ' +
    'ObjInspShowStatusBar:b ObjInspShowInstanceList:b ObjInspShowGridLines:b ObjInspIntegralHeight:b ' +
    'ObjInspShowClassnames:b ObjInspReferenceExpandable:b ObjInspReferenceOnEvents:b ' +
    'ObjInspShowReadOnlyProps:b ObjInspBoldNonDefault:b WinHelpPath:s WinHelpFiles:s ' +
    'MetaPrintSelected:b MetaPrintVisible:b MetaPrintHeader:b MetaPrintBorder:b MetaPrintToSingle:b ' +
    'MetaPrintToFile:b MetaPrintFile:s MetaPrintDescription:b UseTabCharacter:b SmartTab:b ' +
    'OptimalFill:b BackspaceUnindents:b KeepTrailingBlanks:b SyntaxHighlight:b TabStops:s ' +
    'ShowTabCharacter:b ShowSpaceCharacter:b FileExtensions:s AutoIndent:b BlockIndent:i ' +
    'SourceOptionName:s SyntaxHighlighterID:s SourceOptionIDString:s';

  { the options D7 Studio keeps: Delphi's name; the kind letter of each (p a path that may hold
    $(DELPHI), d the Code Insight delay - tenths of a second, as Delphi 7's slider has it, t the
    completion list's ground in the editor theme: no field) in EnvKinds; where it is: EnvField.
    RootDir and BinDir are D7 Studio's names of before, the Object Inspector's colours and
    InsightBGColor later Delphis' - none of them in Delphi 7's list: they answer as they are. }
  EnvNames: array[0..72] of string = ('LibraryPath', 'BrowsingPath', 'PackageDPLOutput', 'PackageDCPOutput',
    'RepositoryDir', 'AutoSaveEditorFiles', 'AutoSaveDesktop', 'AutoDragDocking', 'WarnOnPackageRebuild',
    'MinimizeOnRun', 'ShowCompilerProgress', 'ShowDesignerHints', 'ShowExtendedControlHints',
    'DFMAsText', 'AutoCreateForms', 'ObjInspShowInstanceList', 'ObjInspShowClassnames', 'ObjInspShowStatusBar',
    'ObjInspShowGridLines', 'ObjInspIntegralHeight', 'ObjInspShowReadOnlyProps', 'ObjInspBoldNonDefault',
    'ObjInspReferenceExpandable', 'ObjInspReferenceOnEvents', 'ObjInspBackgroundColor', 'ObjInspCategoryColor',
    'ObjInspNameColor', 'ObjInspValueColor', 'ObjInspNonDefaultColor', 'ObjInspReferenceColor',
    'ObjInspReadonlyColor', 'DisplayGrid', 'SnapToGrid', 'ShowComponentCaptions', 'GridSizeX', 'GridSizeY',
    'ShowModExp', 'ModuleExplorerHighlightIncomplete', 'ModuleExplorerDeclarationSyntax',
    'ClassCompletionBooleanProperties', 'SafeCallMapping', 'IgnoreSpecialFlags', 'IgnorePreDeclId',
    'IgnoreReserved', 'IgnoreHidden', 'IgnoreCanCreate', 'InsertMode', 'CursorInTabs', 'GroupUndo',
    'CursorAfterEOF', 'UndoAfterSave', 'PersistentBlocks', 'OverwriteBlocks', 'DoubleClickLine',
    'FindTextAtCursor', 'CutCopyEnabled', 'UndoLimit', 'BRIEFCursors', 'CreateBackup', 'VisibleRightMargin',
    'RightMargin', 'VisibleGutter', 'GutterWidth', 'EditorFont', 'FontSize', 'BRIEFRegEx',
    'EditorOptionsSortPagesMenu', 'PreserveLineEnds', 'FindAutoCompletes', 'CodeCompletion', 'CodeParameters',
    'CodeCompleteDelay', 'InsightBGColor');
  EnvKinds = 'pppppbbbbbbbbbbbbbbbbbbbcccccccbbbiibbbbibbbbbbbbbbbbbbbibbbibisibbbbbbdt';
  EnvEditorFirst = 46;          // EnvNames from here on are editor options (SaveEditorOptions)

{ where D7 Studio keeps EnvNames[I] }
function EnvField(I: Integer): Pointer;
begin
  case I of
    0: Result := @EnvOptions.LibraryPath;
    1: Result := @EnvOptions.BrowsingPath;
    2: Result := @EnvOptions.BplOutputDir;
    3: Result := @EnvOptions.DcpOutputDir;
    4: Result := @EnvOptions.RepositoryDir;
    5: Result := @EnvOptions.AutosaveEditor;
    6: Result := @EnvOptions.AutosaveDesktop;
    7: Result := @EnvOptions.AutoDragDocking;
    8: Result := @EnvOptions.WarnPackageRebuild;
    9: Result := @EnvOptions.MinimizeOnRun;
    10: Result := @EnvOptions.ShowCompilerProgress;
    11: Result := @EnvOptions.ShowDesignerHints;
    12: Result := @EnvOptions.ShowExtendedHints;
    13: Result := @EnvOptions.NewFormsAsText;
    14: Result := @EnvOptions.AutoCreateForms;
    15: Result := @EnvOptions.OIShowInstanceList;
    16: Result := @EnvOptions.OIShowClassNames;
    17: Result := @EnvOptions.OIShowStatusBar;
    18: Result := @EnvOptions.OIRenderGrid;
    19: Result := @EnvOptions.OIIntegralHeight;
    20: Result := @EnvOptions.OIShowReadOnly;
    21: Result := @EnvOptions.OIBoldNonDefault;
    22: Result := @EnvOptions.OIRefExpand;
    23: Result := @EnvOptions.OIRefOnEvents;
    24: Result := @EnvOptions.OIColors[ocBackground];
    25: Result := @EnvOptions.OIColors[ocCategory];
    26: Result := @EnvOptions.OIColors[ocName];
    27: Result := @EnvOptions.OIColors[ocValue];
    28: Result := @EnvOptions.OIColors[ocNonDefault];
    29: Result := @EnvOptions.OIColors[ocReference];
    30: Result := @EnvOptions.OIColors[ocReadOnly];
    31: Result := @DesignEnv.ShowGrid;
    32: Result := @DesignEnv.SnapToGrid;
    33: Result := @DesignEnv.ShowCaptions;
    34: Result := @DesignEnv.GridX;
    35: Result := @DesignEnv.GridY;
    36: Result := @EnvOptions.ExAutoShow;
    37: Result := @EnvOptions.ExHighlightIncomplete;
    38: Result := @EnvOptions.ExShowSyntax;
    39: Result := @EnvOptions.ExFinishProperties;
    40: Result := @EnvOptions.TLSafeCall;
    41: Result := @EnvOptions.TLIgnoreFlags;
    42..45: Result := @EnvOptions.TLFlags[I - 42];
    46: Result := @EditorOptions.InsertMode;
    47: Result := @EditorOptions.CursorThroughTabs;
    48: Result := @EditorOptions.GroupUndo;
    49: Result := @EditorOptions.CursorBeyondEOF;
    50: Result := @EditorOptions.UndoAfterSave;
    51: Result := @EditorOptions.PersistentBlocks;
    52: Result := @EditorOptions.OverwriteBlocks;
    53: Result := @EditorOptions.DoubleClickLine;
    54: Result := @EditorOptions.FindTextAtCursor;
    55: Result := @EditorOptions.ForceCutCopy;
    56: Result := @EditorOptions.UndoLimit;
    57: Result := @EditorOptions.BriefCursors;
    58: Result := @EditorOptions.CreateBackup;
    59: Result := @EditorOptions.ShowRightMargin;
    60: Result := @EditorOptions.RightMargin;
    61: Result := @EditorOptions.VisibleGutter;
    62: Result := @EditorOptions.GutterWidth;
    63: Result := @EditorOptions.FontName;
    64: Result := @EditorOptions.FontSize;
    65: Result := @EditorOptions.BriefRegExp;
    66: Result := @EditorOptions.SortPagesMenu;
    67: Result := @EditorOptions.PreserveLineEnds;
    68: Result := @EditorOptions.FindAutoComplete;
    69: Result := @EditorOptions.AutoComplete;
    70: Result := @EditorOptions.AutoParameters;
    71: Result := @EditorOptions.CodeDelay;
  else
    Result := nil;
  end;
end;

function EnvIndex(const Name: string): Integer;
var
  I: Integer;
begin
  for I := Low(EnvNames) to High(EnvNames) do
    if SameText(EnvNames[I], Name) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ Delphi's options of the Code Explorer (Environment Options | Explorer) that are not one field each:
  ModuleExplorerSorting, ModuleExplorerCategorySort and ModuleExplorer<Key>Visible / <Key>Expand -
  where D7 Studio keeps them, and their kind ('o' the sorting: Delphi's enumeration, 1 Alphabetical,
  2 Source - ExSortAlpha; 's' the order; 'b' a flag) }
function ExplorerOption(const Name: string; out P: Pointer; out Kind: Char): Boolean;
var
  X: TExpCategory;
begin
  Result := True;
  if SameText(Name, 'ModuleExplorerSorting') then
  begin
    P := @EnvOptions.ExSortAlpha;
    Kind := 'o';
    Exit;
  end;
  if SameText(Name, 'ModuleExplorerCategorySort') then
  begin
    P := @EnvOptions.ExCategorySort;
    Kind := 's';
    Exit;
  end;
  Kind := 'b';
  for X := Low(TExpCategory) to High(TExpCategory) do
    if SameText(Name, 'ModuleExplorer' + ExpCategoryKeys[X] + 'Visible') then
    begin
      P := @EnvOptions.ExVisible[X];
      Exit;
    end
    else if SameText(Name, 'ModuleExplorer' + ExpCategoryKeys[X] + 'Expand') then
    begin
      P := @EnvOptions.ExExpand[X];
      Exit;
    end;
  Result := False;
end;

{ the kind letter of a Delphi environment option (#0: no such option) }
function EnvListKind(const Name: string): Char;
var
  P: Integer;
begin
  Result := #0;
  P := Pos(' ' + UpperCase(Name) + ':', ' ' + UpperCase(EnvOptionList));
  if P > 0 then Result := EnvOptionList[P + Length(Name) + 1];
end;

{ a value an expert gives - a Boolean, a number, Delphi's '-1' / '0', 'True' / 'False' - as a
  Boolean or a number }
function OptionBool(const V: Variant): Boolean;
var
  S: string;
begin
  if VarIsEmpty(V) or VarIsNull(V) then Result := False
  else if (VarType(V) = varString) or (VarType(V) = varOleStr) then
  begin
    S := Trim(VarToStr(V));
    Result := SameText(S, 'True') or (StrToIntDef(S, 0) <> 0);
  end
  else Result := V <> 0;
end;

function OptionInt(const V: Variant): Integer;
begin
  if VarIsEmpty(V) or VarIsNull(V) then Result := 0
  else if VarType(V) = varBoolean then Result := -Ord(Boolean(V))
  else if (VarType(V) = varString) or (VarType(V) = varOleStr) then Result := StrToIntDef(Trim(VarToStr(V)), 0)
  else Result := V;
end;

const
  { Delphi 7's Source Options of its environment list: the Pascal file type's, and their kinds }
  SourceOptNames: array[0..14] of string = ('UseTabCharacter', 'SmartTab', 'OptimalFill',
    'BackspaceUnindents', 'KeepTrailingBlanks', 'SyntaxHighlight', 'TabStops', 'ShowTabCharacter',
    'ShowSpaceCharacter', 'FileExtensions', 'AutoIndent', 'BlockIndent', 'SourceOptionName',
    'SyntaxHighlighterID', 'SourceOptionIDString');
  SourceOptKinds = 'bbbbbbsbbsbisss';
  { the flags of the Color page's element }
  ElementOptNames: array[0..4] of string = ('BoldFont', 'ItalicFont', 'UnderlineFont',
    'UseDefaultForeground', 'UseDefaultBackground');

function NameIndex(const Names: array of string; const Name: string): Integer;
begin
  for Result := Low(Names) to High(Names) do
    if SameText(Names[Result], Name) then Exit;
  Result := -1;
end;

{ a Source Option of the Pascal file type: where it is ('b' a Boolean, 'i' a number, 's' a string) }
function SourceOption(const Name: string; out P: Pointer; out Kind: Char): Boolean;
var
  I, FT: Integer;
begin
  Result := False;
  I := NameIndex(SourceOptNames, Name);
  FT := EditorFileTypeOfID('Borland.EditOptions.Pascal');
  if (I < 0) or (FT < 0) then Exit;
  Kind := SourceOptKinds[I + 1];
  with EditorOptions.FileTypes[FT] do
    case I of
      0: P := @UseTabChar;
      1: P := @SmartTab;
      2: P := @OptimalFill;
      3: P := @BackspaceUnindents;
      4: P := @KeepTrailingBlanks;
      5: P := @UseSyntaxHighlight;
      6: P := @TabStops;
      7: P := @ShowTabChar;
      8: P := @ShowSpaceChar;
      9: P := @Extensions;
      10: P := @AutoIndent;
      11: P := @BlockIndent;
      12: P := @Name;
      13: P := @Highlighter;
    else
      P := @ID;
    end;
  Result := True;
end;

{ D7 Studio's value of an option - Unassigned: one it has none of }
function RawOption(const ValueName: string): Variant;
var
  I: Integer;
  F: Pointer;
  K: Char;
  C: TEditorColor;
begin
  Result := Unassigned;
  if ExplorerOption(ValueName, F, K) then
    case K of
      'o': if PBoolean(F)^ then Result := 1 else Result := 2;
      's': Result := PString(F)^;
    else
      Result := PBoolean(F)^;
    end
  else if SourceOption(ValueName, F, K) then
    case K of
      'b': Result := PBoolean(F)^;
      'i': Result := PInteger(F)^;
    else
      Result := PString(F)^;
    end
  else if NameIndex(ElementOptNames, ValueName) >= 0 then
  begin
    C := EditorOptions.Colors[eePlainText];
    case NameIndex(ElementOptNames, ValueName) of
      0: Result := C.Bold;
      1: Result := C.Italic;
      2: Result := C.Underline;
      3: Result := C.Fore = clDefault;
    else
      Result := C.Back = clDefault;
    end;
  end
  else if SameText(ValueName, 'RootDir') then Result := DelphiRoot
  else if SameText(ValueName, 'BinDir') then Result := DelphiBin
  else
  begin
    I := EnvIndex(ValueName);
    if I < 0 then Exit;
    F := EnvField(I);
    case EnvKinds[I + 1] of
      'p': Result := ExpandDelphiMacros(PString(F)^);
      's': Result := PString(F)^;
      'b': Result := PBoolean(F)^;
      't': Result := Integer(ElementBack(EditorOptions.Colors, eeCompletion));
    else
      Result := PInteger(F)^;
    end;
  end;
end;

procedure TSdOtaEnvOptions.EditOptions;
begin
  if OtaHost <> nil then OtaHost.ExecuteAction('ToolsOptionsCommand');
end;

{ in Delphi 7's form of its kind (measured; EnvOptionList) - an option D7 Studio keeps no value of
  has its kind's empty one; a name Delphi 7 does not list answers as D7 Studio keeps it }
function TSdOtaEnvOptions.GetOptionValue(const ValueName: string): Variant;
var
  Raw: Variant;
begin
  Raw := RawOption(ValueName);
  case EnvListKind(ValueName) of
    'b': if OptionBool(Raw) then Result := '-1' else Result := '0';
    'e': Result := IntToStr(OptionInt(Raw));
    'f': Result := -Ord(OptionBool(Raw));
    'n', 'i': Result := OptionInt(Raw);
    's': Result := VarToStr(Raw);
  else
    Result := Raw;
  end;
end;

{ the setting changed at once; written, and the editors changed, once at the next idle }
procedure TSdOtaEnvOptions.SetOptionValue(const ValueName: string; const Value: Variant);
var
  I: Integer;
  F: Pointer;
  C: TEditorColor;
  K: Char;
begin
  if ExplorerOption(ValueName, F, K) then
  begin
    case K of
      'o': PBoolean(F)^ := OptionInt(Value) <> 2;
      's': PString(F)^ := ExpSortText(ExpSortedCategories(VarToStr(Value)));
    else
      PBoolean(F)^ := OptionBool(Value);
    end;
    if OtaHost <> nil then OtaHost.EnvironmentOptionsChanged;
    Exit;
  end;
  if SourceOption(ValueName, F, K) then
  begin
    case K of
      'b': PBoolean(F)^ := OptionBool(Value);
      'i': PInteger(F)^ := OptionInt(Value);
    else
      PString(F)^ := VarToStr(Value);
    end;
    if OtaHost <> nil then OtaHost.EditorOptionsChanged;
    Exit;
  end;
  I := NameIndex(ElementOptNames, ValueName);
  if I >= 0 then
  begin
    C := EditorOptions.Colors[eePlainText];
    case I of
      0: C.Bold := OptionBool(Value);
      1: C.Italic := OptionBool(Value);
      2: C.Underline := OptionBool(Value);
      3: if OptionBool(Value) then C.Fore := clDefault
         else if C.Fore = clDefault then C.Fore := ElementFore(EditorOptions.Colors, eePlainText);
    else
      if OptionBool(Value) then C.Back := clDefault
      else if C.Back = clDefault then C.Back := ElementBack(EditorOptions.Colors, eePlainText);
    end;
    ChangeThemeElement(EditorOptions, eePlainText, C);
    if OtaHost <> nil then OtaHost.EditorOptionsChanged;
    Exit;
  end;
  I := EnvIndex(ValueName);
  if I < 0 then Exit;
  F := EnvField(I);
  case EnvKinds[I + 1] of
    'p', 's': PString(F)^ := VarToStr(Value);
    'b': PBoolean(F)^ := OptionBool(Value);
    { the theme in use changes (a built-in one: the user's copy of it) - not for the colour the
      list has already (an expert that writes back what it read) }
    't':
      begin
        C := EditorOptions.Colors[eeCompletion];
        if (TColor(OptionInt(Value)) = C.Back) or
          (ColorToRGB(TColor(OptionInt(Value))) = ColorToRGB(ElementBack(EditorOptions.Colors, eeCompletion))) then
          Exit;
        C.Back := TColor(OptionInt(Value));
        ChangeThemeElement(EditorOptions, eeCompletion, C);
      end;
  else
    PInteger(F)^ := OptionInt(Value);
  end;
  if OtaHost = nil then Exit;
  if I >= EnvEditorFirst then OtaHost.EditorOptionsChanged else OtaHost.EnvironmentOptionsChanged;
end;

function TSdOtaEnvOptions.GetOptionNames: TOTAOptionNameArray;
var
  L: TStringList;
  I, P: Integer;
begin
  L := TStringList.Create;
  try
    L.Delimiter := ' ';
    L.DelimitedText := EnvOptionList;
    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do
    begin
      P := Pos(':', L[I]);
      Result[I].Name := Copy(L[I], 1, P - 1);
      case L[I][P + 1] of
        's': Result[I].Kind := tkLString;
        'i': Result[I].Kind := tkInteger;
      else
        Result[I].Kind := tkEnumeration;
      end;
    end;
  finally
    L.Free;
  end;
end;
{ ---------------------------------------------------------------- INTAServices }

constructor TSdOtaNta.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FIdents := TStringList.Create;
end;

destructor TSdOtaNta.Destroy;
begin
  FIdents.Free;
  inherited;
end;

function TSdOtaNta.AddMasked(Image: TBitmap; MaskColor: TColor): Integer;
begin
  Result := AddExtraIcon(Image, MaskColor);
end;

{ an image added again under the same Ident (an expert loaded again) gets the index it had }
function TSdOtaNta.AddMasked(Image: TBitmap; MaskColor: TColor; const Ident: string): Integer;
var
  I: Integer;
begin
  I := FIdents.IndexOf(Ident);
  if (Ident <> '') and (I >= 0) then
  begin
    Result := Integer(FIdents.Objects[I]);
    Exit;
  end;
  Result := AddExtraIcon(Image, MaskColor);
  if (Ident <> '') and (Result >= 0) then FIdents.AddObject(Ident, TObject(Result));
end;

function TSdOtaNta.GetActionList: TCustomActionList;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.ActionList;
end;

function TSdOtaNta.GetImageList: TCustomImageList;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.ImageList;
end;

function TSdOtaNta.GetMainMenu: TMainMenu;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.MainMenu;
end;

function TSdOtaNta.GetToolBar(const ToolBarName: string): TToolBar;
begin
  if OtaHost = nil then Result := nil else Result := OtaHost.ToolBar(ToolBarName);
end;

{ ---------------------------------------------------------------- wizards }

destructor TSdWizardAction.Destroy;
begin
  FItem.Free;
  FWizard := nil;
  inherited;
end;

procedure TSdWizardAction.DoExecute(Sender: TObject);
begin
  OtaExecuteWizard(FWizard);
end;

{ the state and the caption whenever the Help menu drops down (Delphi 7's UpdateMenuItems): a menu
  wizard's text may say what it does now }
procedure TSdWizardAction.DoUpdate(Sender: TObject);
var
  S: TWizardState;
  MW: IOTAMenuWizard;
  T: string;
begin
  try
    S := FWizard.GetState;
  except
    S := [];
  end;
  Enabled := wsEnabled in S;
  Checked := wsChecked in S;
  if Supports(FWizard, IOTAMenuWizard, MW) then
    try
      T := MW.GetMenuText;
      if T <> '' then Caption := T;
    except
    end;
end;

constructor TSdOtaWizards.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FWizards := TSdNotifierList.Create;
  FActions := TList.Create;
end;

destructor TSdOtaWizards.Destroy;
begin
  FActions.Free;
  FWizards.Free;
  inherited;
end;

const
  { Delphi 7's hidden line of the Help menu after which the experts' and wizards' items go }
  WizardAnchorName = 'HelpProgGuideSeparater';
  { the help context of the experts' and wizards' items in Delphi 7 }
  WizardHelpContext = 4520;

{ the line the items follow: the menu's HelpProgGuideSeparater (shown while it has items), else a
  line of their own before the menu's last line (About), made when Make }
function TSdOtaWizards.Anchor(Menu: TMenuItem; Make: Boolean): TMenuItem;
var
  I, At: Integer;
begin
  for I := 0 to Menu.Count - 1 do
    if SameText(Menu[I].Name, WizardAnchorName) then
    begin
      Result := Menu[I];
      Exit;
    end;
  if (FSeparator = nil) and Make then
  begin
    At := Menu.Count;
    for I := Menu.Count - 1 downto 0 do
      if Menu[I].IsLine then
      begin
        At := I;
        Break;
      end;
    FSeparator := NewLine;
    Menu.Insert(At, FSeparator);
  end;
  Result := FSeparator;
end;

{ a menu wizard's item in the Help menu, in Delphi 7's order: Delphi 1-3's experts above the menu
  wizards, the newest of each on top; named after its ID when that makes a free component name }
procedure TSdOtaWizards.Install(const W: IOTAWizard);
var
  MW: IOTAMenuWizard;
  LE: ISdLegacyExpert;
  A: TSdWizardAction;
  Menu, Line: TMenuItem;
  IsExpert: Boolean;
  I: Integer;
  N: string;
begin
  if (OtaHost = nil) or not Supports(W, IOTAMenuWizard, MW) then Exit;
  Menu := OtaHost.WizardMenu;
  if Menu = nil then Exit;
  IsExpert := Supports(W, ISdLegacyExpert, LE);
  A := TSdWizardAction.Create(OtaHost.WizardActions);
  A.ActionList := OtaHost.WizardActions;
  A.FWizard := W;
  A.HelpContext := WizardHelpContext;
  N := '';
  try
    A.Caption := MW.GetMenuText;
    A.Hint := W.GetName;
    N := W.GetIDString;
  except
    OtaCaught('IOTAMenuWizard.GetMenuText', False);
  end;
  A.OnExecute := A.DoExecute;
  A.OnUpdate := A.DoUpdate;
  Line := Anchor(Menu, True);
  Line.Visible := True;
  A.FItem := TMenuItem.Create(OtaHost.MainForm);
  A.FItem.Action := A;
  for I := 1 to Length(N) do
    if not (N[I] in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) then N[I] := '_';
  if IsValidIdent(N) and (OtaHost.MainForm.FindComponent(N) = nil) then
    try
      A.FItem.Name := N;
    except
    end;
  if IsExpert then
  begin
    Menu.Insert(Line.MenuIndex + 1, A.FItem);
    Inc(FExpertItems);
  end
  else
    Menu.Insert(Line.MenuIndex + 1 + FExpertItems, A.FItem);
  FActions.Add(A);
end;

procedure TSdOtaWizards.Uninstall(const W: IOTAWizard);
var
  I: Integer;
  A: TSdWizardAction;
  LE: ISdLegacyExpert;
  Menu: TMenuItem;
begin
  for I := FActions.Count - 1 downto 0 do
  begin
    A := TSdWizardAction(FActions[I]);
    if SameInterface(A.FWizard, W) then
    begin
      if Supports(A.FWizard, ISdLegacyExpert, LE) then Dec(FExpertItems);
      LE := nil;
      FActions.Delete(I);
      A.Free;
    end;
  end;
  if FActions.Count > 0 then Exit;
  if FSeparator <> nil then FreeAndNil(FSeparator)
  else if OtaHost <> nil then
  begin
    Menu := OtaHost.WizardMenu;
    if (Menu <> nil) and (Anchor(Menu, False) <> nil) then Anchor(Menu, False).Visible := False;
  end;
end;

procedure TSdOtaWizards.HostReady;
var
  I: Integer;
  W: IOTAWizard;
begin
  for I := 0 to FWizards.Count - 1 do
    if Supports(FWizards[I], IOTAWizard, W) then Install(W);
end;

{ Delphi 7's manager of experts and wizards refuses a wizard without a name and one whose ID an
  expert or a wizard has already (CompareText) }
function TSdOtaWizards.AddWizard(const AWizard: IOTAWizard): Integer;
var
  ID: string;
  I: Integer;
  W: IOTAWizard;
begin
  Result := -1;
  if AWizard = nil then Exit;
  if AWizard.GetName = '' then raise Exception.Create('Cannot register an unnamed Wizard');
  ID := AWizard.GetIDString;
  for I := 0 to FWizards.Count - 1 do
    if Supports(FWizards[I], IOTAWizard, W) and (CompareText(W.GetIDString, ID) = 0) then
      raise Exception.CreateFmt('Cannot register Wizard, %s, twice', [ID]);
  Result := FWizards.Add(AWizard);
  if (Result >= 0) and HostIsReady then Install(AWizard);
end;

{ its menu item first; the list then holds the last reference, which RemoveTold lets go of in its
  guard (the entry read into a variable: FWizards[Index] passed on as an argument would be a
  hidden temporary holding a reference until this routine returns) }
{ an expert's own RemoveWizard: taken out and released, not told Destroyed - Delphi 7's (measured) }
procedure TSdOtaWizards.RemoveWizard(Index: Integer);
begin
  DropWizard(Index, False);
end;

{ Tell: told Destroyed before it is released (its package goes, the IDE ends) }
procedure TSdOtaWizards.DropWizard(Index: Integer; Tell: Boolean);
var
  X: IInterface;
  W: IOTAWizard;
begin
  X := FWizards[Index];
  if not Supports(X, IOTAWizard, W) then Exit;
  X := nil;
  Uninstall(W);
  W := nil;
  if Tell then FWizards.RemoveTold(Index, IOTAWizard, 'IOTAWizard') else FWizards.Remove(Index);
end;

{ the wizards of a package that goes: told Destroyed and released, while their code is there }
procedure TSdOtaWizards.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  for I := FWizards.Count - 1 downto 0 do
    if (FWizards[I] <> nil) and (InterfaceModule(FWizards[I]) = Module) then DropWizard(I, True);
end;

procedure TSdOtaWizards.Shutdown;
var
  I: Integer;
begin
  for I := FWizards.Count - 1 downto 0 do
    if FWizards[I] <> nil then DropWizard(I, True);
end;

{ what the wizard raises, whatever its class (a DLL expert's own), is logged and shown }
procedure OtaExecuteWizard(const Wizard: IOTAWizard);
begin
  if Wizard = nil then Exit;
  try
    Wizard.Execute;
  except
    OtaCaught('IOTAWizard.Execute', True);
  end;
end;

procedure OtaRepositoryWizards(List: TInterfaceList);
var
  I: Integer;
  R: IOTARepositoryWizard;
  R60: IOTARepositoryWizard60;
  D: string;
begin
  List.Clear;
  if Services = nil then Exit;
  for I := 0 to Services.FWizards.FWizards.Count - 1 do
    if Supports(Services.FWizards.FWizards[I], IOTARepositoryWizard, R) then
    begin
      { a CLX wizard has no place in a VCL IDE }
      if Supports(R, IOTARepositoryWizard60, R60) then
        try
          D := R60.GetDesigner;
          if not (SameText(D, dVCL) or SameText(D, dAny) or (D = '')) then Continue;
        except
        end;
      List.Add(R);
    end;
end;

{ the registration of a package's wizard (LibraryWizardProc): a refused one is logged, and raises
  out of the package's Register as in Delphi }
function RegisterWizard(const Wizard: IOTAWizard): Boolean;
begin
  try
    Result := (Services <> nil) and (Services.FWizards.AddWizard(Wizard) >= 0);
  except
    OtaCaught('wizard registration', False);
    raise;
  end;
end;

{ ... of a DLL expert's (its INITWIZARD0001's register procedure): a refused one is logged, False }
function RegisterDllWizard(const Wizard: IOTAWizard): Boolean;
begin
  Result := False;
  try
    Result := (Services <> nil) and (Services.FWizards.AddWizard(Wizard) >= 0);
  except
    OtaCaught('wizard registration', False);
  end;
end;

function OtaRunRepositoryWizard(const Name: string): Boolean;
var
  L: TInterfaceList;
  I: Integer;
  W: IOTARepositoryWizard;
begin
  Result := False;
  L := TInterfaceList.Create;
  try
    OtaRepositoryWizards(L);
    for I := 0 to L.Count - 1 do
    begin
      W := IOTARepositoryWizard(L[I]);
      try
        if not SameText(W.GetName, Name) then Continue;
      except
        Continue;
      end;
      Result := True;
      OtaExecuteWizard(W);
      Exit;
    end;
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- DLL experts }

{ the experts' DLLs, as Delphi 7 reads them - Wizards, then Experts (any value name, the file as
  its value; each DLL may have either entry point): D7 Studio's registry key in Delphi's layout,
  and the sections [Wizards] and [Experts] of the settings (name=file); each file once }
procedure ExpertFiles(Files: TStrings);
const
  Sections: array[0..1] of string = ('Wizards', 'Experts');
var
  Reg: TRegistry;
  Names: TStringList;
  I, K: Integer;
  F: string;
begin
  Files.Clear;
  Names := TStringList.Create;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    for K := Low(Sections) to High(Sections) do
    begin
      try
        Names.Clear;
        if Reg.OpenKeyReadOnly(SettingsRegKey + '\' + Sections[K]) then
        begin
          Reg.GetValueNames(Names);
          for I := 0 to Names.Count - 1 do
          begin
            F := ExpandDelphiMacros(Reg.ReadString(Names[I]));
            if (F <> '') and (Files.IndexOf(F) < 0) then Files.Add(F);
          end;
          Reg.CloseKey;
        end;
      except
      end;
      if Settings <> nil then
      begin
        Names.Clear;
        Settings.ReadSectionValues(Sections[K], Names);
        for I := 0 to Names.Count - 1 do
        begin
          F := ExpandDelphiMacros(Names.ValueFromIndex[I]);
          if (F <> '') and (Files.IndexOf(F) < 0) then Files.Add(F);
        end;
      end;
    end;
  finally
    Reg.Free;
    Names.Free;
  end;
end;

procedure PackageUnloading(Module: HMODULE); forward;

{ a DLL expert's terminate procedures (Delphi's order: INITEXPERT0017's, then INITWIZARD0001's) }
procedure TerminateDll(const OldTerm, Term: TWizardTerminateProc; const FileName: string);
begin
  if Assigned(OldTerm) then
    try
      OldTerm;
    except
      OtaCaught('expert ' + FileName, False);
    end;
  if Assigned(Term) then
    try
      Term;
    except
      OtaCaught('expert ' + FileName, False);
    end;
end;

{ Delphi 7's LoadExpertLib for each DLL: Delphi 1-3's entry point INITEXPERT0017 first, then the
  Open Tools API's INITWIZARD0001 - a DLL may have both. One that fails - an entry point returns
  False or raises, or it has neither - loses what it registered, its terminate procedures run, it
  is unloaded; why is logged (error.log), and the next DLL goes on. }
procedure LoadExperts;
var
  Files: TStringList;
  I: Integer;
  X: TSdExpertDll;
  M: HMODULE;
  OldInit: Pointer;
  Init: TWizardInitProc;
  Term, OldTerm: TWizardTerminateProc;
  Ok: Boolean;
begin
  Files := TStringList.Create;
  try
    ExpertFiles(Files);
    for I := 0 to Files.Count - 1 do
    begin
      { an expert that cannot be loaded: why, in error.log }
      if not FileExists(Files[I]) then
      begin
        OtaLog('expert ' + Files[I], Format('Could not find Wizard, ''%s''', [Files[I]]));
        Continue;
      end;
      M := SafeLoadLibrary(Files[I]);
      if M = 0 then
      begin
        OtaLog('expert ' + Files[I], Format('Could not find Wizard, ''%s''', [Files[I]]) + ' ' +
          SysErrorMessage(GetLastError));
        Continue;
      end;
      InstallUtf8ShimsForModules;
      OldInit := GetProcAddress(M, 'INITEXPERT0017');
      @Init := GetProcAddress(M, WizardEntryPoint);
      if (OldInit = nil) and not Assigned(Init) then
      begin
        OtaLog('expert ' + Files[I], Format('Wizard, ''%s'', is not a valid version', [Files[I]]));
        FreeLibrary(M);
        Continue;
      end;
      Term := nil;
      OldTerm := nil;
      Ok := True;
      if OldInit <> nil then Ok := LegacyInitDll(OldInit, Files[I], OldTerm);
      if Ok and Assigned(Init) then
      begin
        Ok := False;
        try
          if Init(BorlandIDEServices, RegisterDllWizard, Term) then Ok := True
          else OtaLog('expert ' + Files[I], Format('Unable to establish interface with Wizard, ''%s''', [Files[I]]));
        except
          OtaCaught('expert ' + Files[I], False);
        end;
      end;
      if not Ok then
      begin
        PackageUnloading(M);            // what it registered goes before its code
        TerminateDll(OldTerm, Term, Files[I]);
        FreeLibrary(M);
        Continue;
      end;
      X := TSdExpertDll.Create;
      X.FileName := Files[I];
      X.Module := M;
      X.Terminate := Term;
      X.OldTerminate := OldTerm;
      Experts.Add(X);
      if Assigned(OtaExpertLoaded) then OtaExpertLoaded;
    end;
  finally
    Files.Free;
  end;
end;

{ ---------------------------------------------------------------- IOTAModuleServices }

constructor TSdOtaModuleServices.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FFileSystems := TSdNotifierList.Create;
  OtaFileSystemList := FFileSystems;
end;

destructor TSdOtaModuleServices.Destroy;
begin
  if OtaFileSystemList = FFileSystems then OtaFileSystemList := nil;
  FFileSystems.Free;
  inherited;
end;

function TSdOtaModuleServices.AddFileSystem(FileSystem: IOTAFileSystem): Integer;
begin
  Result := FFileSystems.Add(FileSystem);
end;

{ Delphi 7's (measured): taken out of the list, the later ones one index down; a bad index raises
  EListError }
procedure TSdOtaModuleServices.RemoveFileSystem(Index: Integer);
begin
  FFileSystems.DeleteChecked(Index);
end;

{ the file system of the ID, any case; nil: none }
function TSdOtaModuleServices.FileSystemOf(const Name: string): IOTAFileSystem;
var
  I: Integer;
  F: IOTAFileSystem;
begin
  Result := nil;
  for I := 0 to FFileSystems.Count - 1 do
    if Supports(FFileSystems[I], IOTAFileSystem, F) and SameText(F.GetIDString, Name) then
    begin
      Result := F;
      Exit;
    end;
end;

{ Delphi 7's (measured): an ID no file system has raises "Unable to locate file system, '<ID>'" }
function TSdOtaModuleServices.FindFileSystem(const Name: string): IOTAFileSystem;
begin
  Result := FileSystemOf(Name);
  if Result = nil then raise Exception.CreateFmt(SUnknownFileSystem, [Name]);
end;

function TSdOtaModuleServices.CloseAll: Boolean;
begin
  Result := (OtaHost = nil) or OtaHost.CloseAll;
end;

function TSdOtaModuleServices.CurrentModule: IOTAModule;
begin
  Result := OtaModules.CurrentModule;
end;

function TSdOtaModuleServices.FindFormModule(const FormName: string): IOTAModule;
begin
  Result := OtaModules.FindFormModule(FormName);
end;

{ Delphi 7's FindModule (measured): the module of the name it has, in any case - none for the name
  written with forward slashes or as its 8.3 name; a unit whose form is shown as text gives the
  text's module }
function TSdOtaModuleServices.FindModule(const FileName: string): IOTAModule;
var
  P: TEditorPage;
begin
  if OtaHost <> nil then P := OtaHost.FindPage(FileName) else P := nil;
  if (P <> nil) and (P.FormTextPage <> nil) and SameText(P.FileName, FileName) then
  begin
    Result := OtaModules.ModuleIntf(P.FormTextPage.FileName);
    Exit;
  end;
  Result := OtaModules.ModuleIntf(FileName);
  if (Result <> nil) and not SameText(Result.FileName, FileName) then Result := nil;
end;

function TSdOtaModuleServices.GetModuleCount: Integer;
var
  L: TInterfaceList;
begin
  L := TInterfaceList.Create;
  try
    OtaModules.List(L);
    Result := L.Count;
  finally
    L.Free;
  end;
end;

function TSdOtaModuleServices.GetModule(Index: Integer): IOTAModule;
var
  L: TInterfaceList;
begin
  Result := nil;
  L := TInterfaceList.Create;
  try
    OtaModules.List(L);
    if (Index >= 0) and (Index < L.Count) then Result := IOTAModule(L[Index]);
  finally
    L.Free;
  end;
end;

procedure TSdOtaModuleServices.GetNewModuleAndClassName(const Prefix: string; var UnitIdent,
  ClassName, FileName: string);
var
  Root: string;
begin
  if OtaHost = nil then Exit;
  UnitIdent := OtaHost.UniqueUnitName('Unit');
  if Prefix = '' then Root := OtaHost.UniqueRootName('Form') else Root := OtaHost.UniqueRootName(Prefix);
  ClassName := 'T' + Root;
  FileName := OtaHost.DefaultDir + UnitIdent + '.pas';
end;

function TSdOtaModuleServices.NewModule: Boolean;
begin
  Result := (OtaHost <> nil) and OtaHost.NewItemsDialog;
end;

function TSdOtaModuleServices.SaveAll: Boolean;
begin
  Result := (OtaHost = nil) or OtaHost.SaveAll;
  OtaModules.FlushResources;
end;

function FileSource(const F: IOTAFile): string;
begin
  if F = nil then Result := '' else Result := F.GetSource;
end;

{ The additional files of a creator (IOTAAdditionalFilesModuleCreator, Delphi's adapter): each
  source the creator gives - none: no file -, under the name it gives or the unit's name with its
  extension, made as the unit's source is (a page in memory, written when it is saved - also with
  the unit's module, IOTAModule.Save; an unnamed creator's is an untitled page) and kept with the
  module. A page that came up on top makes room for the unit's again. }
procedure AddCreatedFiles(const AC: IOTAAdditionalFilesModuleCreator; M: TSdOtaModule; UnitPage: TEditorPage;
  const ImplName, UnitIdent, FormName, Ancestor: string; Unnamed, Show: Boolean);
var
  I, N: Integer;
  F: IOTAFile;
  Name, Src: string;
  P: TEditorPage;
begin
  try
    N := AC.GetAdditionalFilesCount;
  except
    OtaCaught('IOTAAdditionalFilesModuleCreator.GetAdditionalFilesCount', False);
    Exit;
  end;
  for I := 0 to N - 1 do
  begin
    try
      F := AC.NewAdditionalFileSource(I, UnitIdent, FormName, Ancestor);
      if F = nil then Continue;
      Name := AC.GetAdditionalFileName(I);
      if Name = '' then Name := ChangeFileExt(ImplName, AC.GetAdditionalFileExt(I));
      Src := FileSource(F);
    except
      OtaCaught('IOTAAdditionalFilesModuleCreator', False);
      Continue;
    end;
    P := OtaHost.NewModule(Name, Src, '', Unnamed, False, False, False);
    if P <> nil then Name := P.FileName;
    M.AddAdditionalFile(Name);
  end;
  if Show and (UnitPage <> nil) and (OtaHost.ActivePage <> UnitPage) then OtaHost.ShowPage(UnitPage);
end;

{ a unit, a form or a text (the creator's type) from what the creator gives, the IDE's defaults
  for what it leaves out (Delphi's); a creator's file system (IOTACreator.GetFileSystem) must be
  there - its file is read (Existing) and written through it }
function TSdOtaModuleServices.CreateUnit(const C: IOTAModuleCreator): IOTAModule;
var
  Kind, FileName, UnitIdent, FormName, Ancestor, Source, Dfm, FSName: string;
  Owner: IOTAModule;
  Proj: IOTAProject;
  OwnerPrj: TSdProject;
  Page: TEditorPage;
  F: IOTAFile;
  FE: IOTAFormEditor;
  M: TSdOtaModule;
  AC: IOTAAdditionalFilesModuleCreator;
  Given: Boolean;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  Owner := C.GetOwner;
  FSName := C.GetFileSystem;
  if FSName <> '' then FindFileSystem(FSName);
  if C.GetExisting then
  begin
    FileName := C.GetImplFileName;
    if FileName = '' then Exit;
    { Delphi 7's (measured): the file is not read - the creator's text is the module's, else a unit
      creator's the IDE's new unit, a text creator's none; another creator's reads it }
    UnitIdent := ChangeFileExt(ExtractFileName(FileName), '');
    Kind := C.GetCreatorType;
    F := C.NewImplSource(UnitIdent, C.GetFormName, C.GetAncestorName);
    Given := True;
    if F <> nil then Source := FileSource(F)
    else if SameText(Kind, sText) then Source := ''
    else if SameText(Kind, sUnit) then Source := NewUnitSource(UnitIdent)
    else Given := False;
    if Given then Page := OtaHost.OpenWithText(FileName, FSName, Source, C.GetShowSource)
    else if FSName <> '' then Page := OtaHost.OpenVirtualFile(FileName, FSName, '', False, C.GetShowSource)
    else Page := OtaHost.OpenFile(FileName, C.GetShowSource);
    F := nil;
    if Page <> nil then
    begin
      Result := OtaModules.ModuleIntf(Page.FileName);
      { an existing unit whose owner is a project of the group joins it (Delphi's) }
      OwnerPrj := nil;
      if (FSName = '') and (Owner <> nil) and Supports(Owner, IOTAProject, Proj) then
        OwnerPrj := OtaHost.GroupProject(Proj.FileName);
      if (OwnerPrj <> nil) and (OwnerPrj.FindUnit(FileName) = nil) then OtaHost.ProjectAddFileTo(OwnerPrj, FileName);
    end;
    Exit;
  end;
  Kind := C.GetCreatorType;
  FileName := C.GetImplFileName;
  if FileName = '' then
    if SameText(Kind, sText) then FileName := OtaHost.DefaultDir + OtaHost.UniqueUnitName('File') + '.txt'
    else FileName := OtaHost.DefaultDir + OtaHost.UniqueUnitName('Unit') + '.pas';
  UnitIdent := ChangeFileExt(ExtractFileName(FileName), '');
  FormName := C.GetFormName;
  if (FormName = '') and SameText(Kind, sForm) then FormName := OtaHost.UniqueRootName('Form');
  Ancestor := C.GetAncestorName;
  if (Ancestor = '') and (FormName <> '') then Ancestor := 'Form';
  F := C.NewImplSource(UnitIdent, FormName, Ancestor);
  if F <> nil then Source := FileSource(F)
  else if SameText(Kind, sForm) then Source := NewFormUnitSource(UnitIdent, FormName, 'T' + Ancestor)
  else if SameText(Kind, sUnit) then Source := NewUnitSource(UnitIdent)
  else Source := '';
  Dfm := '';
  if FormName <> '' then
  begin
    F := C.NewFormFile(FormName, Ancestor);
    if F <> nil then Dfm := FileSource(F)
    else if SameText(Kind, sForm) then Dfm := NewFormDfm(FormName);
  end;
  if FSName <> '' then
    Page := OtaHost.OpenVirtualFile(FileName, FSName, Source, True, C.GetShowSource)
  else
  begin
    { the owner a project of the group, active or not: the unit goes into its uses clause }
    OwnerPrj := nil;
    if (Owner <> nil) and Supports(Owner, IOTAProject, Proj) then OwnerPrj := OtaHost.GroupProject(Proj.FileName);
    Page := OtaHost.NewModuleOf(OwnerPrj, FileName, Source, Dfm, C.GetUnnamed, C.GetShowForm, C.GetShowSource);
  end;
  if Page = nil then Exit;
  M := OtaModules.Find(Page.FileName);
  if M = nil then Exit;
  Result := M;
  if (Dfm <> '') and (FSName = '') then
  begin
    FE := M.FormEditor;
    if FE <> nil then
      try
        C.FormCreated(FE);
      except
        OtaCaught('IOTAModuleCreator.FormCreated', False);
      end;
  end;
  if Supports(C, IOTAAdditionalFilesModuleCreator, AC) then
    AddCreatedFiles(AC, M, Page, FileName, UnitIdent, FormName, Ancestor, C.GetUnnamed,
      C.GetShowSource or C.GetShowForm);
end;

{ a project from its creator: its source written, opened (Owner a project group: into the open
  group, else a new one), then the creator's resource and default modules }
function TSdOtaModuleServices.CreateProject(const C: IOTAProjectCreator): IOTAModule;
var
  Kind, FileName, Name, Source: string;
  P: IOTAProject;
  G: IOTAProjectGroup;
  C50: IOTAProjectCreator50;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  Kind := C.GetCreatorType;
  FileName := C.GetFileName;
  if FileName = '' then
  begin
    if SameText(Kind, sPackage) then FileName := OtaHost.DefaultDir + OtaHost.UniqueUnitName('Package') + '.dpk'
    else FileName := OtaHost.DefaultDir + OtaHost.UniqueUnitName('Project') + '.dpr';
  end;
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  if not C.GetExisting then
  begin
    Source := FileSource(C.NewProjectSource(Name));
    if Source = '' then
      if SameText(Kind, sPackage) then Source := NewPackageSource(Name)
      else if SameText(Kind, sConsole) then Source := NewConsoleSource(Name)
      else if SameText(Kind, sLibrary) then
        Source := 'library ' + Name + ';'#13#10#13#10'uses'#13#10'  SysUtils,'#13#10'  Classes;'#13#10#13#10 +
          '{$R *.res}'#13#10#13#10'begin'#13#10'end.'#13#10
      else
        Source := 'program ' + Name + ';'#13#10#13#10'uses'#13#10'  Forms;'#13#10#13#10'{$R *.res}'#13#10#13#10 +
          'begin'#13#10'  Application.Initialize;'#13#10'  Application.Run;'#13#10'end.'#13#10;
    ForceDirectories(ExtractFilePath(FileName));
    WriteFileU(FileName, Source);
  end;
  if not OtaHost.OpenProject(FileName, not Supports(C.GetOwner, IOTAProjectGroup, G)) then Exit;
  Result := OtaModules.ModuleIntf(FileName);
  if not Supports(Result, IOTAProject, P) or C.GetExisting then Exit;
  try
    C.NewProjectResource(P);
    if Supports(C, IOTAProjectCreator50, C50) then C50.NewDefaultProjectModule(P)
    else C.NewDefaultModule;
  except
    OtaCaught('IOTAProjectCreator', False);
  end;
end;

function TSdOtaModuleServices.CreateGroup(const C: IOTAProjectGroupCreator): IOTAModule;
var
  FileName, Source: string;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  FileName := C.GetFileName;
  if FileName = '' then Exit;
  if not C.GetExisting then
  begin
    Source := FileSource(C.NewProjectGroupSource(ChangeFileExt(ExtractFileName(FileName), '')));
    if Source = '' then Exit;
    WriteFileU(FileName, Source);
  end;
  if OtaHost.OpenProject(FileName, True) then Result := OtaModules.ModuleIntf(FileName);
end;

function TSdOtaModuleServices.CreateModule(const Creator: IOTACreator): IOTAModule;
var
  GC: IOTAProjectGroupCreator;
  PC: IOTAProjectCreator;
  MC: IOTAModuleCreator;
begin
  Result := nil;
  try
    if Supports(Creator, IOTAProjectGroupCreator, GC) then Result := CreateGroup(GC)
    else if Supports(Creator, IOTAProjectCreator, PC) then Result := CreateProject(PC)
    else if Supports(Creator, IOTAModuleCreator, MC) then Result := CreateUnit(MC);
  except
    OtaCaught('IOTAModuleServices.CreateModule', False);
    raise;
  end;
end;

{ the file's module closes, whatever OpenFile opened (Delphi's FindDocModule, then its Close): a
  page, a project (one of the group stays in it closed), a package beside the group, the group,
  the Type Library view's library; True when the file has no module }
function TSdOtaModuleServices.CloseFile(const FileName: string): Boolean;
var
  M: IOTAModule;
begin
  Result := False;
  if OtaHost = nil then Exit;
  M := OtaModules.ModuleIntf(FileName);
  Result := (M = nil) or M.Close;
end;

{ as Delphi's CallDefaultOpenProc opens it: a project, a package or a project group in a group of
  its own - the open group closed first, as Delphi 7's does (measured in its IDE: File | Open alone
  opens a package beside the group) -, a type library in its view, any other file as a page }
function TSdOtaModuleServices.OpenFile(const FileName: string): Boolean;
begin
  Result := (OtaHost <> nil) and OtaHost.OpenAny(FileName);
end;

function TSdOtaModuleServices.OpenProject(const ProjName: string; NewProjGroup: Boolean): Boolean;
begin
  Result := (OtaHost <> nil) and OtaHost.OpenProject(ProjName, NewProjGroup);
end;

function TSdOtaModuleServices.ReloadFile(const FileName: string): Boolean;
var
  P: TEditorPage;
begin
  Result := False;
  if OtaHost = nil then Exit;
  P := OtaHost.FindPage(FileName);
  Result := (P <> nil) and OtaHost.ReloadPage(P);
end;

function TSdOtaModuleServices.SaveFile(const FileName: string): Boolean;
var
  P: TEditorPage;
begin
  Result := False;
  if OtaHost = nil then Exit;
  P := OtaHost.FindPage(FileName);
  Result := (P <> nil) and OtaHost.SavePage(P, False);
end;

{ ---------------------------------------------------------------- IOTAEditorServices }

{ the page whose editor experts mean: the active one, else the last one shown in its code }
{ the page the user sees - a form shown as text too: its buffer is that text (OtaPageBuffer) }
function TopPage: TEditorPage;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  Result := OtaHost.ActivePage;
end;

function TSdOtaEditorServices.GetEditOptions: IOTAEditOptions;
var
  P: TEditorPage;
begin
  P := TopPage;
  if P <> nil then Result := OtaEditOptionsOf(P.FileName) else Result := OtaEditOptionsIndex(0);
end;

function TSdOtaEditorServices.GetEditBufferIterator(out Iterator: IOTAEditBufferIterator): Boolean;
begin
  Iterator := TSdOtaBufferIterator.Create;
  Result := True;
end;

function TSdOtaEditorServices.GetKeyboardServices: IOTAKeyboardServices;
begin
  Result := Root.FKeyboard;
end;

function TSdOtaEditorServices.GetTopBuffer: IOTAEditBuffer;
begin
  Result := OtaPageBuffer(TopPage);
end;

function TSdOtaEditorServices.GetTopView: IOTAEditView;
var
  B: IOTAEditBuffer;
begin
  B := GetTopBuffer;
  if B = nil then Result := nil else Result := B.TopView;
end;

function TSdOtaEditorServices.GetEditOptions(const IDString: string): IOTAEditOptions;
var
  I: Integer;
begin
  I := EditorFileTypeOfID(IDString);
  if I < 0 then Result := nil else Result := OtaEditOptionsIndex(I);
end;

function TSdOtaEditorServices.GetEditOptionsForFile(const FileName: string): IOTAEditOptions;
begin
  Result := OtaEditOptionsOf(FileName);
end;

{ a source file type of its own (Source Options): the default type's settings, no extensions }
function TSdOtaEditorServices.AddEditOptions(const IDString: string): IOTAEditOptions;
var
  N, D: Integer;
begin
  Result := GetEditOptions(IDString);
  if (Result <> nil) or (IDString = '') then Exit;
  D := EditorFileTypeIndex('');            // the Default type: its settings for the new one
  N := Length(EditorOptions.FileTypes);
  SetLength(EditorOptions.FileTypes, N + 1);
  if D >= 0 then EditorOptions.FileTypes[N] := EditorOptions.FileTypes[D];
  EditorOptions.FileTypes[N].ID := IDString;
  EditorOptions.FileTypes[N].Name := IDString;
  EditorOptions.FileTypes[N].Extensions := '';
  if OtaHost <> nil then OtaHost.EditorOptionsChanged;
  Result := OtaEditOptionsIndex(N);
end;

procedure TSdOtaEditorServices.DeleteEditOptions(const IDString: string);
var
  I, J: Integer;
begin
  I := EditorFileTypeOfID(IDString);
  if I < 0 then raise Exception.CreateFmt('Edit options %s not found', [IDString]);
  for J := I to High(EditorOptions.FileTypes) - 1 do
    EditorOptions.FileTypes[J] := EditorOptions.FileTypes[J + 1];
  SetLength(EditorOptions.FileTypes, Length(EditorOptions.FileTypes) - 1);
  if OtaHost <> nil then OtaHost.EditorOptionsChanged;
end;

function TSdOtaEditorServices.GetEditOptionsCount: Integer;
begin
  Result := OtaEditOptionsCount;
end;

function TSdOtaEditorServices.GetEditOptionsIndex(Index: Integer): IOTAEditOptions;
begin
  Result := OtaEditOptionsIndex(Index);
end;

constructor TSdOtaBufferIterator.Create;
var
  I: Integer;
  B: IOTAEditBuffer;
  P: TEditorPage;
begin
  inherited Create;
  FBuffers := TInterfaceList.Create;
  if OtaHost = nil then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    P := OtaHost.Pages(I);
    B := OtaPageBuffer(P);          // a form shown as text too: a buffer of its own
    if B <> nil then FBuffers.Add(B);
  end;
end;

destructor TSdOtaBufferIterator.Destroy;
begin
  FBuffers.Free;
  inherited;
end;

function TSdOtaBufferIterator.GetCount: Integer;
begin
  Result := FBuffers.Count;
end;

function TSdOtaBufferIterator.GetEditBuffer(Index: Integer): IOTAEditBuffer;
begin
  if (Index >= 0) and (Index < FBuffers.Count) then Result := IOTAEditBuffer(FBuffers[Index])
  else Result := nil;
end;

{ ---------------------------------------------------------------- IOTAMessageServices }

const
  BuildGroupName = 'Build';

constructor TSdOtaMessageGroup.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FMessages := TObjectList.Create(True);
end;

destructor TSdOtaMessageGroup.Destroy;
begin
  FMessages.Free;
  inherited;
end;

function TSdOtaMessageGroup.GetGroupName: string;
begin
  Result := FName;
end;

constructor TSdOtaMessages.Create(const Controller: IInterface);
var
  G: TSdOtaMessageGroup;
begin
  inherited Create(Controller);
  FGroups := TList.Create;
  FGroupRefs := TInterfaceList.Create;
  FNotifiers := TSdNotifierList.Create;
  G := TSdOtaMessageGroup.Create(BuildGroupName);
  FGroups.Add(G);
  FGroupRefs.Add(IOTAMessageGroup(G));
end;

destructor TSdOtaMessages.Destroy;
begin
  FNotifiers.Free;
  FGroupRefs.Free;
  FGroups.Free;
  inherited;
end;

{ M is a row: every message above it is open }
function Shown(M: TSdOtaMessage): Boolean;
var
  X: TSdOtaMessage;
begin
  Result := False;
  X := M.Parent;
  while X <> nil do
  begin
    if not X.Expanded then Exit;
    X := X.Parent;
  end;
  Result := True;
end;

{ the rows of a group's messages that are shown, in the group's order }
procedure FillRows(L: TListBox; G: TSdOtaMessageGroup);
var
  I: Integer;
  M: TSdOtaMessage;
begin
  for I := 0 to G.FMessages.Count - 1 do
  begin
    M := TSdOtaMessage(G.FMessages[I]);
    if Shown(M) then L.Items.AddObject(M.Text, M);
  end;
end;

{ the view: a list for each group made before it was there, the messages that are rows }
procedure TSdOtaMessages.AttachView(View: TSdMessageView);
var
  I: Integer;
  G: TSdOtaMessageGroup;
begin
  FView := View;
  if View = nil then Exit;
  SetupList(View.Lists[0]);
  for I := 1 to FGroups.Count - 1 do
  begin
    G := TSdOtaMessageGroup(FGroups[I]);
    View.AddGroup(G.FName, GroupDblClick);
    SetupList(View.Lists[I]);
    FillRows(View.Lists[I], G);
  end;
  FillRows(View.Lists[0], TSdOtaMessageGroup(FGroups[0]));
end;

type
  { the keys and clicks of a list of the Messages view on its messages (Delphi's message tree):
    on a message with children + and Right open it, - and Left close it (Left on a child goes to
    its parent), a click on its box opens or closes it, and so does a double click on it when it
    names no file; F1 on an expert's message is its ShowHelp }
  TSdMsgListHook = class(TUIWindowHook)
  private
    FMessages: TSdOtaMessages;       // nil: the IDE ends, the list is a plain list again
    function BoxHit(L: TListBox; X, Y: Integer; out Row: Integer): Boolean;
  protected
    procedure Hook(var Message: TMessage); override;
  public
    constructor Create(AList: TListBox; AMessages: TSdOtaMessages);
  end;

const
  ExpandBoxSize = 9;               // SdUI.UIDrawExpandBox
  ExpandBoxGap = 4;                // between the box and the text

{ where a message's expand box begins in its row: 2 px in, after its indentation (its text begins
  with it as blanks) in the font selected into DC }
function BoxLeft(DC: HDC; M: TSdOtaMessage): Integer;
begin
  Result := 2;
  if M.Level > 0 then Inc(Result, UITextWidth(DC, StringOfChar(' ', 4 * M.Level)));
end;

{ ... in the list's font }
function ListBoxLeft(L: TListBox; M: TSdOtaMessage): Integer;
var
  DC: HDC;
  Old: HGDIOBJ;
begin
  Result := 2;
  if M.Level <= 0 then Exit;
  DC := GetDC(L.Handle);
  try
    Old := SelectObject(DC, L.Font.Handle);
    Result := BoxLeft(DC, M);
    SelectObject(DC, Old);
  finally
    ReleaseDC(L.Handle, DC);
  end;
end;

constructor TSdMsgListHook.Create(AList: TListBox; AMessages: TSdOtaMessages);
begin
  inherited Create(AList, True);
  FMessages := AMessages;
end;

{ the point (client) lies on the box of a message with children; Row: the row under it }
function TSdMsgListHook.BoxHit(L: TListBox; X, Y: Integer; out Row: Integer): Boolean;
var
  M: TSdOtaMessage;
  BoxX: Integer;
begin
  Result := False;
  Row := L.ItemAtPos(Point(X, Y), True);
  if (Row < 0) or not (L.Items.Objects[Row] is TSdOtaMessage) then Exit;
  M := TSdOtaMessage(L.Items.Objects[Row]);
  if M.ChildCount = 0 then Exit;
  { the rows are drawn from the scrolled range's left edge }
  Inc(X, GetScrollPos(L.Handle, SB_HORZ));
  BoxX := ListBoxLeft(L, M);
  Result := (X >= BoxX - 2) and (X < BoxX + ExpandBoxSize + 2);
end;

procedure TSdMsgListHook.Hook(var Message: TMessage);
var
  L: TListBox;
  Row, I: Integer;
  M: TSdOtaMessage;
  Key: Word;
begin
  if FMessages = nil then
  begin
    FOldProc(Message);
    Exit;
  end;
  L := TListBox(FControl);
  case Message.Msg of
    CN_KEYDOWN:
      begin
        Key := TWMKeyDown(Message).CharCode;
        Row := L.ItemIndex;
        M := nil;
        if (Row >= 0) and (Row < L.Items.Count) and (L.Items.Objects[Row] is TSdOtaMessage) then
          M := TSdOtaMessage(L.Items.Objects[Row]);
        if (M <> nil) and (KeyDataToShiftState(TWMKeyDown(Message).KeyData) = []) then
        begin
          if (Key = VK_F1) and (M.Custom <> nil) then
          begin
            try
              M.Custom.ShowHelp;
            except
              OtaCaught('IOTACustomMessage.ShowHelp', False);
            end;
            Message.Result := 1;
            Exit;
          end;
          if (Key in [VK_ADD, VK_RIGHT]) and (M.ChildCount > 0) then
          begin
            if not M.Expanded then FMessages.Toggle(L, Row)
            else if Key = VK_RIGHT then L.ItemIndex := Row + 1;
            Message.Result := 1;
            Exit;
          end;
          if (Key in [VK_SUBTRACT, VK_LEFT]) and (M.ChildCount > 0) and M.Expanded then
          begin
            FMessages.Toggle(L, Row);
            Message.Result := 1;
            Exit;
          end;
          if (Key = VK_LEFT) and (M.Parent <> nil) then
          begin
            for I := Row - 1 downto 0 do
              if L.Items.Objects[I] = M.Parent then
              begin
                L.ItemIndex := I;
                Break;
              end;
            Message.Result := 1;
            Exit;
          end;
        end;
      end;
    WM_LBUTTONDOWN:
      if BoxHit(L, TWMMouse(Message).XPos, TWMMouse(Message).YPos, Row) then FMessages.Toggle(L, Row);
    WM_LBUTTONDBLCLK:
      begin
        Row := L.ItemAtPos(Point(TWMMouse(Message).XPos, TWMMouse(Message).YPos), True);
        if (Row >= 0) and (L.Items.Objects[Row] is TSdOtaMessage) and
          not BoxHit(L, TWMMouse(Message).XPos, TWMMouse(Message).YPos, I) then
        begin
          M := TSdOtaMessage(L.Items.Objects[Row]);
          if (M.ChildCount > 0) and (M.FileName = '') then FMessages.Toggle(L, Row);
        end;
      end;
  end;
  FOldProc(Message);
end;

{ a list of the view: its rows drawn by the services (only a message with children or an
  expert's message looks other than a plain row), its keys and clicks on the messages }
procedure TSdOtaMessages.SetupList(L: TListBox);
begin
  if (L = nil) or (UIFindHook(L, TSdMsgListHook) <> nil) then Exit;
  L.OnDrawItem := DrawMessage;
  TSdMsgListHook.Create(L, Self);
end;

procedure TSdOtaMessages.DetachView;
var
  I: Integer;
  L: TListBox;
  H: TSdMsgListHook;
begin
  if FView = nil then Exit;
  for I := 0 to FView.GroupCount - 1 do
  begin
    L := FView.Lists[I];
    if L = nil then Continue;
    L.OnDrawItem := nil;
    H := TSdMsgListHook(UIFindHook(L, TSdMsgListHook));
    if H <> nil then H.FMessages := nil;
  end;
  FView := nil;
end;

function TSdOtaMessages.GroupOfList(L: TListBox): TSdOtaMessageGroup;
var
  I: Integer;
begin
  Result := nil;
  if FView = nil then Exit;
  I := FView.ListGroup(L);
  if (I >= 0) and (I < FGroups.Count) then Result := TSdOtaMessageGroup(FGroups[I]);
end;

{ the shown text of a message: an expert's as it says it now (the text it had when it fails) }
function MessageText(M: TSdOtaMessage): string;
begin
  Result := Copy(M.Text, 4 * M.Level + 1, MaxInt);
  if M.Custom <> nil then
    try
      Result := M.Custom.GetLineText;
    except
      OtaCaught('IOTACustomMessage.GetLineText', False);
    end;
end;

{ A row as the list tracking draws a plain list's (SdUI.UIDrawListRow); a message with children
  has the expand box of the IDE's trees before its text, at its indentation, and an expert's
  message is drawn by it (INTACustomDrawMessage.Draw on the list's canvas, which has the row's
  colours) or shows its text as it is now. The row's width: the text's, or the expert's CalcRect. }
procedure TSdOtaMessages.DrawMessage(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  L: TListBox;
  Obj: TObject;
  M: TSdOtaMessage;
  DC: HDC;
  Back, Fore: TColor;
  Old: HGDIOBJ;
  X, Right: Integer;
  T, CR: TRect;
  S: string;
begin
  L := TListBox(Control);
  DC := L.Canvas.Handle;
  Obj := L.Items.Objects[Index];
  if not (Obj is TSdOtaMessage) or ((TSdOtaMessage(Obj).ChildCount = 0) and (TSdOtaMessage(Obj).Custom = nil)) then
  begin
    UIDrawListRow(L, DC, Rect, L.Items[Index], odSelected in State);
    Exit;
  end;
  M := TSdOtaMessage(Obj);
  UIListRowColors(L, odSelected in State, Back, Fore);
  UIFill(DC, Rect, Back);
  Old := SelectObject(DC, L.Font.Handle);
  try
    X := Rect.Left + BoxLeft(DC, M);
    if M.ChildCount > 0 then
    begin
      UIDrawExpandBox(DC, X, Rect.Top + (Rect.Bottom - Rect.Top - ExpandBoxSize) div 2, M.Expanded, ExpandBoxSize);
      Inc(X, ExpandBoxSize + ExpandBoxGap);
    end;
    T := Classes.Rect(X, Rect.Top, Rect.Right, Rect.Bottom);
    Right := -1;
    if (M.CustomDraw <> nil) and not M.DrawFailed then
      try
        M.CustomDraw.Draw(L.Canvas, T, False);
        CR := M.CustomDraw.CalcRect(L.Canvas, MaxInt, False);
        Right := X + CR.Right - CR.Left;
      except
        M.DrawFailed := True;
        OtaCaught('INTACustomDrawMessage.Draw', False);
        UIFill(DC, T, Back);
        Right := -1;
      end;
    if Right < 0 then
    begin
      SelectObject(DC, L.Font.Handle);
      S := MessageText(M);
      UIText(DC, S, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX, Fore);
      Right := T.Left + UITextWidth(DC, S);
    end;
    UIListRowWidth(L, Right);
  finally
    SelectObject(DC, Old);
  end;
end;

{ the rows of P's children after At - and of theirs that are open - in the group's order }
procedure TSdOtaMessages.InsertChildren(L: TListBox; G: TSdOtaMessageGroup; P: TSdOtaMessage; var At: Integer);
var
  I: Integer;
  X: TSdOtaMessage;
begin
  for I := 0 to G.FMessages.Count - 1 do
  begin
    X := TSdOtaMessage(G.FMessages[I]);
    if X.Parent <> P then Continue;
    L.Items.InsertObject(At, X.Text, X);
    Inc(At);
    if X.Expanded and (X.ChildCount > 0) then InsertChildren(L, G, X, At);
  end;
end;

{ Obj is a message under M }
function IsUnder(Obj: TObject; M: TSdOtaMessage): Boolean;
var
  X: TSdOtaMessage;
begin
  Result := False;
  if not (Obj is TSdOtaMessage) then Exit;
  X := TSdOtaMessage(Obj).Parent;
  while X <> nil do
  begin
    if X = M then
    begin
      Result := True;
      Exit;
    end;
    X := X.Parent;
  end;
end;

procedure TSdOtaMessages.Toggle(L: TListBox; Row: Integer);
var
  M: TSdOtaMessage;
  G: TSdOtaMessageGroup;
  At, Top, Sel: Integer;
  R: TRect;
begin
  if (L = nil) or (Row < 0) or (Row >= L.Items.Count) or not (L.Items.Objects[Row] is TSdOtaMessage) then Exit;
  M := TSdOtaMessage(L.Items.Objects[Row]);
  G := GroupOfList(L);
  if (M.ChildCount = 0) or (G = nil) then Exit;
  Top := L.TopIndex;
  Sel := L.ItemIndex;
  L.Items.BeginUpdate;
  try
    M.Expanded := not M.Expanded;
    if M.Expanded then
    begin
      At := Row + 1;
      InsertChildren(L, G, M, At);
    end
    else
    begin
      { a row inside goes: the selection to the message closed }
      if (Sel > Row) and (Sel < L.Items.Count) and IsUnder(L.Items.Objects[Sel], M) then Sel := Row;
      while (Row + 1 < L.Items.Count) and IsUnder(L.Items.Objects[Row + 1], M) do L.Items.Delete(Row + 1);
      if Sel > Row then Sel := L.ItemIndex;
    end;
  finally
    L.Items.EndUpdate;
  end;
  if L.TopIndex <> Top then L.TopIndex := Top;
  if (Sel = Row) and (L.ItemIndex <> Row) then L.ItemIndex := Row;
  R := L.ItemRect(Row);
  InvalidateRect(L.Handle, @R, False);
end;

{ some of a group's messages went: the counts of the children again, and a message whose parent
  went is a row of its own (L: the group's list, nil without the view) }
procedure Reparent(G: TSdOtaMessageGroup; L: TListBox);
var
  I: Integer;
  M: TSdOtaMessage;
  Orphans: Boolean;
begin
  Orphans := False;
  for I := 0 to G.FMessages.Count - 1 do TSdOtaMessage(G.FMessages[I]).ChildCount := 0;
  for I := 0 to G.FMessages.Count - 1 do
  begin
    M := TSdOtaMessage(G.FMessages[I]);
    if (M.Parent <> nil) and (G.FMessages.IndexOf(M.Parent) < 0) then
    begin
      M.Parent := nil;
      Orphans := True;
    end;
    if M.Parent <> nil then Inc(M.Parent.ChildCount);
  end;
  if not Orphans or (L = nil) then Exit;
  for I := 0 to G.FMessages.Count - 1 do
  begin
    M := TSdOtaMessage(G.FMessages[I]);
    if Shown(M) and (L.Items.IndexOfObject(M) < 0) then L.Items.AddObject(M.Text, M);
  end;
end;

procedure TSdOtaMessages.DropModule(Module: HMODULE);
var
  I, J: Integer;
  G: TSdOtaMessageGroup;
  M: TSdOtaMessage;
  Changed: Boolean;
begin
  if Module = 0 then Exit;
  for I := 0 to FGroups.Count - 1 do
  begin
    G := TSdOtaMessageGroup(FGroups[I]);
    Changed := False;
    for J := 0 to G.FMessages.Count - 1 do
    begin
      M := TSdOtaMessage(G.FMessages[J]);
      if (M.Custom <> nil) and (InterfaceModule(M.Custom) = Module) then
      begin
        M.CustomDraw := nil;
        M.Custom := nil;
        Changed := True;
      end;
    end;
    if Changed and (List(I) <> nil) then List(I).Invalidate;
  end;
end;

function TSdOtaMessages.GroupObj(const G: IOTAMessageGroup): TSdOtaMessageGroup;
var
  I: Integer;
begin
  Result := TSdOtaMessageGroup(FGroups[0]);
  if G = nil then Exit;
  I := FGroupRefs.IndexOf(G);
  if I >= 0 then Result := TSdOtaMessageGroup(FGroups[I]);
end;

function TSdOtaMessages.List(Index: Integer): TListBox;
begin
  if FView = nil then Result := nil else Result := FView.Lists[Index];
end;

{ row I in view: the list scrolls only when it is not, as far as needed }
procedure ShowRow(L: TListBox; I: Integer);
var
  Rows: Integer;
begin
  Rows := 1;
  if L.ItemHeight > 0 then Rows := L.ClientHeight div L.ItemHeight;
  if Rows < 1 then Rows := 1;
  if I < L.TopIndex then L.TopIndex := I
  else if I >= L.TopIndex + Rows then L.TopIndex := I - Rows + 1;
end;

{ The parent of a message is looked for from the end - of the group's messages and of the list's
  rows -, as it was usually added just before its children: a tree of messages (a parent per file,
  its hits as children) is added in linear time, not in one pass per message over every message
  and every row (each row's object costs the list box a message). }

{ the index of Obj in L from the end (-1: not there) }
function IndexFromEnd(L: TList; Obj: Pointer): Integer;
begin
  Result := L.Count - 1;
  while (Result >= 0) and (L[Result] <> Obj) do Dec(Result);
end;

{ the row of Obj in L from the last row (-1: no row) }
function RowFromEnd(L: TListBox; Obj: TObject): Integer;
begin
  Result := L.Items.Count - 1;
  while (Result >= 0) and (L.Items.Objects[Result] <> Obj) do Dec(Result);
end;

{ M into its group and its list: a child after its parent's last descendant, indented }
function TSdOtaMessages.Add(const G: IOTAMessageGroup; M: TSdOtaMessage; Parent: Pointer): Pointer;
var
  Grp: TSdOtaMessageGroup;
  GI, I: Integer;
  L: TListBox;
  P, X: TSdOtaMessage;
  R: TRect;
begin
  Grp := GroupObj(G);
  GI := FGroups.IndexOf(Grp);
  P := nil;
  if (Parent <> nil) and (IndexFromEnd(Grp.FMessages, Parent) >= 0) then P := TSdOtaMessage(Parent);
  M.Parent := P;
  if P <> nil then
  begin
    M.Level := P.Level + 1;
    M.Text := StringOfChar(' ', 4 * M.Level) + M.Text;
    Inc(P.ChildCount);
  end;
  Grp.FMessages.Add(M);
  Result := M;
  L := List(GI);
  if L = nil then Exit;
  { under a closed message: no row (Delphi's tree adds children closed) - its parent's row gets
    its box with the first child }
  if not Shown(M) then
  begin
    if (P <> nil) and (P.ChildCount = 1) then
    begin
      I := RowFromEnd(L, P);
      if I >= 0 then
      begin
        R := L.ItemRect(I);
        InvalidateRect(L.Handle, @R, False);
      end;
    end;
    Exit;
  end;
  I := -1;
  if P <> nil then
  begin
    I := RowFromEnd(L, P);
    if I >= 0 then
    begin
      Inc(I);
      while I < L.Items.Count do
      begin
        if not (L.Items.Objects[I] is TSdOtaMessage) then Break;
        X := TSdOtaMessage(L.Items.Objects[I]).Parent;
        while (X <> nil) and (X <> P) do X := X.Parent;
        if X = nil then Break;
        Inc(I);
      end;
    end;
  end;
  if I < 0 then I := L.Items.AddObject(M.Text, M) else L.Items.InsertObject(I, M.Text, M);
  ShowRow(L, I);
end;

procedure GroupAddedOne(const N: IInterface; Data: Pointer);
begin
  IOTAMessageNotifier(N).MessageGroupAdded(IOTAMessageGroup(Data));
end;

procedure GroupDeletedOne(const N: IInterface; Data: Pointer);
begin
  IOTAMessageNotifier(N).MessageGroupDeleted(IOTAMessageGroup(Data));
end;

procedure TSdOtaMessages.Notify(const G: IOTAMessageGroup; Added: Boolean);
begin
  if Added then FNotifiers.Each(IOTAMessageNotifier, GroupAddedOne, Pointer(G), 'IOTAMessageNotifier')
  else FNotifiers.Each(IOTAMessageNotifier, GroupDeletedOne, Pointer(G), 'IOTAMessageNotifier');
end;

{ a group's messages out of its list (ToolOnly: the services' messages; else everything the list
  shows - the compiler's too on Build) and freed }
function IsCompilerMessage(Obj: TObject): Boolean;
begin
  Result := (Obj is TSdOtaMessage) and TSdOtaMessage(Obj).Compiler;
end;

{ a group's messages (ToolOnly: the services' tool, title and custom ones - the compiler's of
  AddCompilerMessage stay, ClearCompilerMessages takes them). A row whose object is a
  TSdOtaMessage is a message of the list's group: rows are made from the group's messages only,
  and a list is emptied before its messages are freed (GroupCleared). }
procedure TSdOtaMessages.ClearGroup(Index: Integer; ToolOnly: Boolean);
var
  G: TSdOtaMessageGroup;
  L: TListBox;
  I: Integer;
  Obj: TObject;
begin
  G := TSdOtaMessageGroup(FGroups[Index]);
  L := List(Index);
  if L <> nil then
    if ToolOnly then
    begin
      L.Items.BeginUpdate;
      try
        for I := L.Items.Count - 1 downto 0 do
        begin
          Obj := L.Items.Objects[I];
          if (Obj is TSdOtaMessage) and not TSdOtaMessage(Obj).Compiler then L.Items.Delete(I);
        end;
      finally
        L.Items.EndUpdate;
      end;
    end
    else
      L.Items.Clear;
  if ToolOnly then
  begin
    for I := G.FMessages.Count - 1 downto 0 do
      if not IsCompilerMessage(G.FMessages[I]) then G.FMessages.Delete(I);
    Reparent(G, L);
  end
  else
    G.FMessages.Clear;
end;

procedure TSdOtaMessages.GroupCleared(Index: Integer);
begin
  if (Index >= 0) and (Index < FGroups.Count) then TSdOtaMessageGroup(FGroups[Index]).FMessages.Clear;
end;

procedure TSdOtaMessages.GroupDblClick(Sender: TObject);
var
  L: TListBox;
  M: TSdOtaMessage;
begin
  L := TListBox(Sender);
  if (L.ItemIndex < 0) or not (L.Items.Objects[L.ItemIndex] is TSdOtaMessage) then Exit;
  M := TSdOtaMessage(L.Items.Objects[L.ItemIndex]);
  if (M.FileName <> '') and (OtaHost <> nil) then OtaHost.ShowFileLine(M.FileName, M.Line, M.Column);
end;

function TSdOtaMessages.DebugText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FGroups.Count - 1 do
    Result := Result + Format('%s:%d;', [TSdOtaMessageGroup(FGroups[I]).FName,
      TSdOtaMessageGroup(FGroups[I]).FMessages.Count]);
end;

function ToolText(const FileName, MessageStr, PrefixStr: string; LineNumber: Integer): string;
begin
  Result := MessageStr;
  if FileName <> '' then
    if LineNumber > 0 then Result := Format('%s(%d): %s', [ExtractFileName(FileName), LineNumber, Result])
    else Result := ExtractFileName(FileName) + ': ' + Result;
  if PrefixStr <> '' then Result := '[' + PrefixStr + '] ' + Result;
end;

procedure TSdOtaMessages.AddCustomMessage(const CustomMsg: IOTACustomMessage);
begin
  AddCustomMessage(CustomMsg, nil);
end;

{ an expert's message: its text, file, line and column copied (the row shows the text when the
  expert's object is gone with its package; a double click goes to the place it had), the
  interfaces kept - the text as it is when the row is drawn, its own drawing, its help }
function TSdOtaMessages.NewCustom(const C: IOTACustomMessage): TSdOtaMessage;
begin
  Result := TSdOtaMessage.Create;
  Result.Kind := mkHint;
  try
    Result.Text := C.GetLineText;
    Result.FileName := C.GetFileName;
    Result.Line := C.GetLineNumber;
    Result.Column := C.GetColumnNumber;
  except
    OtaCaught('IOTACustomMessage', False);
  end;
  Result.Custom := C;
  if not Supports(C, INTACustomDrawMessage, Result.CustomDraw) then Result.CustomDraw := nil;
end;

{ the children of an expert's IOTACustomMessage50, read once, when it is added (Delphi's), each
  with its own children }
procedure TSdOtaMessages.AddCustomChildren(const G: IOTAMessageGroup; P: TSdOtaMessage;
  const C: IOTACustomMessage50);
var
  I, N: Integer;
  Child: IOTACustomMessage50;
  M: TSdOtaMessage;
begin
  try
    N := C.GetChildCount;
  except
    OtaCaught('IOTACustomMessage50.GetChildCount', False);
    Exit;
  end;
  for I := 0 to N - 1 do
  begin
    try
      Child := C.GetChild(I);
    except
      OtaCaught('IOTACustomMessage50.GetChild', False);
      Child := nil;
    end;
    if Child = nil then Continue;
    M := NewCustom(Child);
    Add(G, M, P);
    AddCustomChildren(G, M, Child);
  end;
end;

procedure TSdOtaMessages.AddCustomMessage(const CustomMsg: IOTACustomMessage;
  const MessageGroupIntf: IOTAMessageGroup);
var
  M: TSdOtaMessage;
  C50: IOTACustomMessage50;
begin
  if CustomMsg = nil then Exit;
  M := NewCustom(CustomMsg);
  Add(MessageGroupIntf, M, nil);
  if Supports(CustomMsg, IOTACustomMessage50, C50) then AddCustomChildren(MessageGroupIntf, M, C50);
end;

procedure TSdOtaMessages.AddTitleMessage(const MessageStr: string);
begin
  AddTitleMessage(MessageStr, nil);
end;

procedure TSdOtaMessages.AddTitleMessage(const MessageStr: string; const MessageGroupIntf: IOTAMessageGroup);
var
  M: TSdOtaMessage;
begin
  M := TSdOtaMessage.Create;
  M.Kind := mkInfo;
  M.Text := MessageStr;
  Add(MessageGroupIntf, M, nil);
end;

procedure TSdOtaMessages.AddToolMessage(const FileName, MessageStr, PrefixStr: string;
  LineNumber, ColumnNumber: Integer);
var
  Ref: Pointer;
begin
  AddToolMessage(FileName, MessageStr, PrefixStr, LineNumber, ColumnNumber, nil, Ref, nil);
end;

procedure TSdOtaMessages.AddToolMessage(const FileName, MessageStr, PrefixStr: string;
  LineNumber, ColumnNumber: Integer; Parent: Pointer; out LineRef: Pointer);
begin
  AddToolMessage(FileName, MessageStr, PrefixStr, LineNumber, ColumnNumber, Parent, LineRef, nil);
end;

procedure TSdOtaMessages.AddToolMessage(const FileName, MessageStr, PrefixStr: string;
  LineNumber, ColumnNumber: Integer; Parent: Pointer; out LineRef: Pointer;
  const MessageGroupIntf: IOTAMessageGroup);
var
  M: TSdOtaMessage;
begin
  M := TSdOtaMessage.Create;
  M.Kind := mkHint;
  M.FileName := FileName;
  M.Line := LineNumber;
  M.Column := ColumnNumber;
  M.Text := ToolText(FileName, MessageStr, PrefixStr, LineNumber);
  LineRef := Add(MessageGroupIntf, M, Parent);
end;

procedure TSdOtaMessages.AddCompilerMessage(const FileName, MessageStr, ToolName: string;
  Kind: TOTAMessageKind; LineNumber, ColumnNumber: Integer; Parent: Pointer; out LineRef: Pointer);
const
  Kinds: array[TOTAMessageKind] of TMsgKind = (mkHint, mkWarning, mkError, mkFatal, mkInfo);
  Names: array[TOTAMessageKind] of string = ('Hint', 'Warning', 'Error', 'Fatal Error', '');
var
  M: TSdOtaMessage;
begin
  M := TSdOtaMessage.Create;
  M.Kind := Kinds[Kind];
  M.FileName := FileName;
  M.Line := LineNumber;
  M.Column := ColumnNumber;
  M.Compiler := True;
  M.Text := ToolText(FileName, MessageStr, Names[Kind], LineNumber);
  LineRef := Add(nil, M, Parent);
end;

procedure TSdOtaMessages.ClearAllMessages;
begin
  ClearGroups(nil, False);
  ClearSearchMessages;
end;

{ the compiler's messages of Build go - the IDE's own and the experts' (AddCompilerMessage) -, the
  services' tool, title and custom messages stay. Without the view (before OtaHostReady) the
  experts' compiler messages go all the same: the view would show them when it comes. }
procedure TSdOtaMessages.ClearCompilerMessages;
var
  G: TSdOtaMessageGroup;
  L: TListBox;
  I: Integer;
  Obj: TObject;
begin
  G := TSdOtaMessageGroup(FGroups[0]);
  L := List(0);
  if L <> nil then L.Items.BeginUpdate;
  try
    { the rows first, while their objects are there }
    if L <> nil then
      for I := L.Items.Count - 1 downto 0 do
      begin
        Obj := L.Items.Objects[I];
        if not (Obj is TSdOtaMessage) or TSdOtaMessage(Obj).Compiler then L.Items.Delete(I);
      end;
    { then every compiler message of the group, a row or not (under a closed message) - owned:
      freed }
    for I := G.FMessages.Count - 1 downto 0 do
      if TSdOtaMessage(G.FMessages[I]).Compiler then G.FMessages.Delete(I);
    Reparent(G, L);
  finally
    if L <> nil then L.Items.EndUpdate;
  end;
end;

procedure TSdOtaMessages.ClearSearchMessages;
begin
  if OtaHost <> nil then OtaHost.ClearSearchResults;
end;

procedure TSdOtaMessages.ClearToolMessages;
begin
  ClearToolMessages(nil);
end;

procedure TSdOtaMessages.ClearGroups(const G: IOTAMessageGroup; ToolOnly: Boolean);
var
  I: Integer;
begin
  if G = nil then
    for I := 0 to FGroups.Count - 1 do ClearGroup(I, ToolOnly)
  else
  begin
    I := FGroupRefs.IndexOf(G);
    if I >= 0 then ClearGroup(I, ToolOnly);
  end;
end;

procedure TSdOtaMessages.ClearToolMessages(const MessageGroupIntf: IOTAMessageGroup);
begin
  ClearGroups(MessageGroupIntf, True);
end;

procedure TSdOtaMessages.ClearMessageGroup(const MessageGroupIntf: IOTAMessageGroup);
begin
  ClearGroups(MessageGroupIntf, False);
end;

function TSdOtaMessages.AddNotifier(const ANotifier: IOTAMessageNotifier): Integer;
begin
  Result := FNotifiers.Add(ANotifier);
end;

procedure TSdOtaMessages.RemoveNotifier(Index: Integer);
begin
  FNotifiers.Remove(Index);
end;

function TSdOtaMessages.AddMessageGroup(const GroupName: string): IOTAMessageGroup;
var
  G: TSdOtaMessageGroup;
begin
  Result := GetGroup(GroupName);
  if Result <> nil then Exit;
  G := TSdOtaMessageGroup.Create(GroupName);
  FGroups.Add(G);
  Result := G;
  FGroupRefs.Add(Result);
  if FView <> nil then SetupList(FView.Lists[FView.AddGroup(GroupName, GroupDblClick)]);
  Notify(Result, True);
end;

function TSdOtaMessages.GetMessageGroupCount: Integer;
begin
  Result := FGroups.Count;
end;

function TSdOtaMessages.GetMessageGroup(Index: Integer): IOTAMessageGroup;
begin
  if (Index >= 0) and (Index < FGroupRefs.Count) then Result := IOTAMessageGroup(FGroupRefs[Index])
  else Result := nil;
end;

function TSdOtaMessages.GetGroup(const GroupName: string): IOTAMessageGroup;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FGroups.Count - 1 do
    if SameText(TSdOtaMessageGroup(FGroups[I]).FName, GroupName) then
    begin
      Result := IOTAMessageGroup(FGroupRefs[I]);
      Exit;
    end;
end;

procedure TSdOtaMessages.ShowMessageView(const MessageGroupIntf: IOTAMessageGroup);
var
  I: Integer;
begin
  if OtaHost = nil then Exit;
  OtaHost.ShowMessages;
  if (MessageGroupIntf = nil) or (FView = nil) then Exit;
  I := FGroupRefs.IndexOf(MessageGroupIntf);
  if I >= 0 then FView.ShowGroup(I);
end;

procedure TSdOtaMessages.RemoveMessageGroup(const MessageGroupIntf: IOTAMessageGroup);
var
  I: Integer;
  G: IOTAMessageGroup;
begin
  if MessageGroupIntf = nil then Exit;
  I := FGroupRefs.IndexOf(MessageGroupIntf);
  if I <= 0 then Exit;                 // Build stays
  G := IOTAMessageGroup(FGroupRefs[I]);
  ClearGroup(I, False);
  if FView <> nil then FView.RemoveGroup(I);
  FGroups.Delete(I);
  FGroupRefs.Delete(I);
  Notify(G, False);
end;

{ ---------------------------------------------------------------- IOTAKeyboardServices }

constructor TSdOtaKeyboard.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FBindings := TSdNotifierList.Create;
  FKeys := TObjectList.Create(True);
  FKeyboards := TStringList.Create;
  FIdeRecord := TSdOtaRecord.Create;
end;

destructor TSdOtaKeyboard.Destroy;
begin
  FKeyboards.Free;
  FKeys.Free;
  FBindings.Free;
  inherited;
end;

function TSdOtaKeyboard.BindingCount: Integer;
begin
  Result := FKeys.Count;
end;

function TSdOtaKeyboard.NewBind(Owner: Integer; Kind: TSdKeyBindKind; Proc: TKeyBindingProc;
  Context: Pointer): TSdKeyBind;
begin
  Result := TSdKeyBind.Create;
  Result.Kind := Kind;
  Result.Proc := Proc;
  Result.Context := Context;
  Result.Owner := Owner;
  Inc(FNextId);
  Result.Id := FNextId;
  FKeys.Add(Result);
end;

function TSdOtaKeyboard.AddBind(Owner: Integer; const Keys: array of TShortCut; Proc: TKeyBindingProc;
  Context: Pointer; Flags: TKeyBindingFlags; const Keyboard: string): Boolean;
var
  B: TSdKeyBind;
  I: Integer;
begin
  Result := (Length(Keys) > 0) and Assigned(Proc);
  if not Result then Exit;
  B := NewBind(Owner, kbKeys, Proc, Context);
  SetLength(B.Keys, Length(Keys));
  for I := 0 to High(Keys) do B.Keys[I] := Keys[I];
  B.Flags := Flags;
  if SameText(Keyboard, sEditor) then B.Keyboard := '' else B.Keyboard := Keyboard;
end;

type
  { Delphi's menu commands an expert's keyboard may take over (AddMenuCommand) and the main
    window's actions that run them - the main menu's, the code editor's local menu's }
  TMenuCommandAction = record
    Command, Action, EditorAction: string;
  end;
  TIntArray = array of Integer;

const
  MenuCommandActions: array[0..17] of TMenuCommandAction = (
    (Command: mcGetFindString; Action: 'SearchFindCommand'; EditorAction: ''),
    (Command: mcReplace; Action: 'SearchReplaceCommand'; EditorAction: ''),
    (Command: mcRepeatSearch; Action: 'SearchAgainCommand'; EditorAction: ''),
    (Command: mcIncrementalSearch; Action: 'SearchIncrementalCommand'; EditorAction: ''),
    (Command: mcGotoLine; Action: 'SearchGoToCommand'; EditorAction: ''),
    (Command: mcClipCut; Action: 'EditCutCommand'; EditorAction: ''),
    (Command: mcClipCopy; Action: 'EditCopyCommand'; EditorAction: ''),
    (Command: mcClipPaste; Action: 'EditPasteCommand'; EditorAction: ''),
    (Command: mcClipClear; Action: 'EditDeleteCommand'; EditorAction: ''),
    (Command: mcHelpKeywordSearch; Action: 'aTopicSearch'; EditorAction: ''),
    (Command: mcOpenFileAtCursor; Action: 'aOpenFileAtCursor'; EditorAction: ''),
    (Command: mcToggleBreakpoint; Action: 'aToggleBreak'; EditorAction: 'aEdToggleBreak'),
    (Command: mcRunToHere; Action: 'RunGotoCursorCommand'; EditorAction: 'aEdRunToCursor'),
    (Command: mcUndo; Action: 'EditUndoCommand'; EditorAction: ''),
    (Command: mcRedo; Action: 'EditRedoCommand'; EditorAction: ''),
    (Command: mcModify; Action: 'RunEvalModCommand'; EditorAction: 'aEdEvaluate'),
    (Command: mcAddWatchAtCursor; Action: 'RunAddWatchCommand'; EditorAction: 'aEdAddWatch'),
    (Command: mcInspectAtCursor; Action: 'RunInspectCommand'; EditorAction: 'aEdInspect'));

{ the menu command an action runs ('' none) }
function MenuCommandOf(const ActionName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(MenuCommandActions) to High(MenuCommandActions) do
    if SameText(MenuCommandActions[I].Action, ActionName) or
      ((MenuCommandActions[I].EditorAction <> '') and SameText(MenuCommandActions[I].EditorAction, ActionName)) then
    begin
      Result := MenuCommandActions[I].Command;
      Exit;
    end;
end;

{ the entry of a menu command (mcClipCopy ...) in MenuCommandActions (-1: none) }
function MenuCommandIndex(const Command: string): Integer;
begin
  for Result := Low(MenuCommandActions) to High(MenuCommandActions) do
    if SameText(MenuCommandActions[Result].Command, Command) then Exit;
  Result := -1;
end;

function TSdOtaKeyboard.AddMenuCommand(Owner: Integer; const Command: string; Proc: TKeyBindingProc;
  Context: Pointer): Boolean;
begin
  Result := Assigned(Proc) and (MenuCommandIndex(Command) >= 0);
  if Result then NewBind(Owner, kbMenuCommand, Proc, Context).Command := Command;
end;

{ one default procedure per keyboard: a new one takes the place of the one before }
procedure TSdOtaKeyboard.SetDefaultKeyProc(Owner: Integer; Proc: TKeyBindingProc; Context: Pointer;
  const Keyboard: string);
var
  I: Integer;
  B: TSdKeyBind;
  K: string;
begin
  if SameText(Keyboard, sEditor) then K := '' else K := Keyboard;
  for I := FKeys.Count - 1 downto 0 do
  begin
    B := TSdKeyBind(FKeys[I]);
    if (B.Kind = kbDefault) and SameText(B.Keyboard, K) then FKeys.Delete(I);
  end;
  if Assigned(Proc) then NewBind(Owner, kbDefault, Proc, Context).Keyboard := K;
end;

{ a binding's Index-th key is Key - with Delphi's implicit forms, for its last key only: the last key
  of a sequence with or without Ctrl (kfImplicitModifier: <Ctrl+K><Ctrl+B> = <Ctrl+K><B>); the keypad's
  keys come as the other ones (kfImplicitKeypad needs nothing). kfImplicitShift binds no key with
  Shift: Delphi 7's does not (measured; it binds the key code's lower case, no key a letter gives) }
function TSdOtaKeyboard.Matches(B: TSdKeyBind; Index: Integer; Key: TShortCut): Boolean;
var
  K: TShortCut;
begin
  K := B.Keys[Index];
  Result := K = Key;
  if Result or (Index <> High(B.Keys)) then Exit;
  if (Index > 0) and (B.Flags and kfImplicitModifier <> 0) then
    Result := (K and not scCtrl) = (Key and not scCtrl);
end;

{ the editor's own bindings, or one of the keyboards pushed }
function TSdOtaKeyboard.Active(B: TSdKeyBind): Boolean;
begin
  Result := (B.Keyboard = '') or (FKeyboards.IndexOf(B.Keyboard) >= 0);
end;

{ the newest key binding before FromIndex (exclusive, counting down) of KeyCount keys that are Keys }
function TSdOtaKeyboard.FindNext(FromIndex, KeyCount: Integer; const Keys: array of TShortCut): Integer;
var
  I, J: Integer;
  B: TSdKeyBind;
  Ok: Boolean;
begin
  for I := FromIndex - 1 downto 0 do
  begin
    B := TSdKeyBind(FKeys[I]);
    if (B.Kind <> kbKeys) or (Length(B.Keys) <> KeyCount) or not Active(B) then Continue;
    Ok := True;
    for J := 0 to KeyCount - 1 do
      if not Matches(B, J, Keys[J]) then Ok := False;
    if Ok then
    begin
      Result := I;
      Exit;
    end;
  end;
  Result := -1;
end;

{ the ids of the bindings of Keys in the order they are called: the keyboard pushed last first
  (PushKeyboard is a stack), the editor's own last; in each the newest first. Keyboard (not '*'):
  that keyboard's only ('' the editor's) }
function KeyChain(K: TSdOtaKeyboard; const Keys: array of TShortCut; const Keyboard: string): TIntArray;
var
  Level, I: Integer;
  Name: string;
  B: TSdKeyBind;
begin
  Result := nil;
  for Level := K.FKeyboards.Count downto 0 do
  begin
    if Level = 0 then Name := '' else Name := K.FKeyboards[Level - 1];
    if (Keyboard <> '*') and not SameText(Keyboard, Name) then Continue;
    I := K.FindNext(K.FKeys.Count, Length(Keys), Keys);
    while I >= 0 do
    begin
      B := TSdKeyBind(K.FKeys[I]);
      if SameText(B.Keyboard, Name) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := B.Id;
      end;
      I := K.FindNext(I, Length(Keys), Keys);
    end;
  end;
end;

function TSdOtaKeyboard.BindById(Id: Integer): TSdKeyBind;
var
  I: Integer;
begin
  for I := 0 to FKeys.Count - 1 do
    if TSdKeyBind(FKeys[I]).Id = Id then
    begin
      Result := TSdKeyBind(FKeys[I]);
      Exit;
    end;
  Result := nil;
end;

{ the keys so far begin a longer sequence of an active binding }
function TSdOtaKeyboard.StartsSequence(const Keys: array of TShortCut): Boolean;
var
  I, J: Integer;
  B: TSdKeyBind;
begin
  Result := False;
  for I := FKeys.Count - 1 downto 0 do
  begin
    B := TSdKeyBind(FKeys[I]);
    if (B.Kind <> kbKeys) or (Length(B.Keys) <= Length(Keys)) or not Active(B) then Continue;
    Result := True;
    for J := 0 to High(Keys) do
      if B.Keys[J] <> Keys[J] then Result := False;
    if Result then Exit;
  end;
end;

{ the default procedure of the keyboard in force: the keyboard pushed last that has one, else the
  editor's }
function TSdOtaKeyboard.DefaultBind: TSdKeyBind;
var
  Level, I: Integer;
  Name: string;
  B: TSdKeyBind;
begin
  for Level := FKeyboards.Count downto 0 do
  begin
    if Level = 0 then Name := '' else Name := FKeyboards[Level - 1];
    for I := FKeys.Count - 1 downto 0 do
    begin
      B := TSdKeyBind(FKeys[I]);
      if (B.Kind = kbDefault) and SameText(B.Keyboard, Name) then
      begin
        Result := B;
        Exit;
      end;
    end;
  end;
  Result := nil;
end;

const
  IdeNext = -2;                  // TKeyBindingRec.Next: the IDE's key mapping comes next

{ a binding as Delphi's record: Reserved its id, Next the id of the binding called after it -
  IdeNext: the IDE's key mapping, -1 none }
function TSdOtaKeyboard.BindRec(B: TSdKeyBind; out Rec: TKeyBindingRec): Boolean;
var
  Chain: TIntArray;
  I: Integer;
begin
  FillChar(Rec, SizeOf(Rec), 0);
  Rec.Next := -1;
  Rec.Reserved := -1;
  Result := B <> nil;
  if not Result then Exit;
  Rec.KeyProc := B.Proc;
  Rec.Context := B.Context;
  Rec.Reserved := B.Id;
  if B.Kind <> kbKeys then Exit;
  Rec.KeyCode := B.Keys[High(B.Keys)];
  Chain := KeyChain(Self, B.Keys, '*');
  for I := 0 to High(Chain) do
    if Chain[I] = B.Id then
    begin
      { the IDE's key mapping is not after it: an expert's binding takes its key from it (Delphi 7's,
        measured) }
      if I < High(Chain) then Rec.Next := Chain[I + 1];
      Break;
    end;
end;

{ the IDE's key mapping as a binding record: the command its keys run - one key, or a chord of
  two (Ctrl+K B) }
function TSdOtaKeyboard.IdeRec(const Keys: array of TShortCut; out Rec: TKeyBindingRec): Boolean;
var
  Map: TKeyBindings;
  Prefix: TShortCut;
  Cmd: TEdCmd;
  Arg, N, I: Integer;
begin
  FillChar(Rec, SizeOf(Rec), 0);
  Rec.Next := -1;
  Rec.Reserved := -1;
  Result := False;
  if (Length(Keys) < 1) or (Length(Keys) > 2) then Exit;
  Map := Keymap(EditorOptions.Keymapping);
  Prefix := 0;
  if (Length(Keys) = 2) and (KeymapLookup(Map, Prefix, Keys[0], Cmd, Arg) <> kmPrefix) then Exit;
  if KeymapLookup(Map, Prefix, Keys[High(Keys)], Cmd, Arg) <> kmCommand then Exit;
  N := -1;
  for I := 0 to High(FIdeCmds) do
    if (FIdeCmds[I] = Cmd) and (FIdeArgs[I] = Arg) then N := I;
  if N < 0 then
  begin
    N := Length(FIdeCmds);
    SetLength(FIdeCmds, N + 1);
    SetLength(FIdeArgs, N + 1);
    FIdeCmds[N] := Cmd;
    FIdeArgs[N] := Arg;
  end;
  Rec.KeyCode := Keys[High(Keys)];
  Rec.KeyProc := IdeKeyProc;
  Rec.Context := Pointer(N + 1);
  Result := True;
end;

{ a command of the IDE's key mapping as a key procedure (LookupKeyBinding, GetNextBindingRec):
  run in the code editor of the context's buffer }
procedure TSdOtaKeyboard.IdeKeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut;
  var BindingResult: TKeyBindingResult);
var
  N: Integer;
  P: TEditorPage;
begin
  BindingResult := krUnhandled;
  if (Context = nil) or (OtaHost = nil) then Exit;
  N := Integer(Context.Context) - 1;
  if (N < 0) or (N > High(FIdeCmds)) then Exit;
  P := nil;
  if Context.EditBuffer <> nil then P := OtaHost.FindPage(Context.EditBuffer.FileName);
  if P = nil then P := OtaHost.ActivePage;
  if (P = nil) or not P.Editor.Ready then Exit;
  P.Editor.ExecCommand(FIdeCmds[N], FIdeArgs[N]);
  BindingResult := krHandled;
end;

function TSdOtaKeyboard.Call(B: TSdKeyBind; Key: TShortCut; Page: TEditorPage): TKeyBindingResult;
var
  Rec: TKeyBindingRec;
  Ctx: IOTAKeyContext;
begin
  Result := krUnhandled;
  BindRec(B, Rec);
  Ctx := TSdOtaKeyContext.Create(B.Context, OtaPageBuffer(Page), Self, Rec);
  try
    B.Proc(Ctx, Key, Result);
  except
    OtaCaught('key binding', True);
    Result := krHandled;
  end;
end;

{ a key that types a character (no Ctrl, no Alt, a character key: Enter, Tab, Backspace, Esc too) }
function TypedKey(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := (Shift * [ssCtrl, ssAlt] = []) and (MapVirtualKey(Key, 2) <> 0);
end;

{ SdSciEdit's key hook, as Delphi 7's editor takes a key (measured): the experts' bindings first, in
  Delphi's order (KeyChain), krUnhandled and krNextProc handing it on to the next one, krHandled
  ending it - and the IDE's key mapping does not run for a key an expert binds, whatever the last one
  answered; after a last krUnhandled a menu's shortcut may take the key (khMenu), else none. Sequences of any
  length; a first key the key mapping begins a chord with goes on to it as well, so that the IDE's
  own sequences keep working; inside the IDE's chord only an expert's sequence of the same first key
  goes on. A key no binding has goes to the keyboard's default procedure - not a typed character, a
  key of the IDE's key mapping or a menu's shortcut: Delphi 7 gave it none of these. }
function TSdOtaKeyboard.EditorKey(Ed: TSciEdit; Key: Word; Shift: TShiftState; InChord: Boolean): TSciKeyHookResult;
var
  SC: TShortCut;
  I, N: Integer;
  Last: TKeyBindingResult;
  Page: TEditorPage;
  Keys: TShortCutArray;
  Ids: TIntArray;
  B: TSdKeyBind;
  Map: TKeyBindings;
  Prefix: TShortCut;
  Cmd: TEdCmd;
  Arg: Integer;
begin
  Result := khNone;
  if (FKeys.Count = 0) or (OtaHost = nil) then Exit;
  { the experts' bindings are keys of the code editor: not of the other editors (Code Templates,
    a resource's text, the Formatter's preview) - their context would have no edit buffer }
  Page := OtaPageOfEditor(Ed);
  if Page = nil then Exit;
  if InChord and (Length(FPending) = 0) then Exit;
  SC := ShortCut(Key, Shift);
  N := Length(FPending);
  SetLength(Keys, N + 1);
  for I := 0 to N - 1 do Keys[I] := FPending[I];
  Keys[N] := SC;
  FPending := nil;
  { the bindings of these keys, taken before one is called: a key procedure may remove bindings }
  Ids := KeyChain(Self, Keys, '*');
  Last := krUnhandled;
  for I := 0 to High(Ids) do
  begin
    B := BindById(Ids[I]);
    if B = nil then Continue;
    Inc(FProcessed);
    Last := Call(B, SC, Page);
    if Last = krHandled then Break;
  end;
  if Length(Ids) > 0 then
  begin
    if Last = krUnhandled then Result := khMenu else Result := khHandled;
    Exit;
  end;
  Map := Keymap(EditorOptions.Keymapping);
  if StartsSequence(Keys) then
  begin
    FPending := Keys;
    Result := khHandled;
    if Length(Keys) = 1 then
    begin
      Prefix := 0;
      if KeymapLookup(Map, Prefix, SC, Cmd, Arg) = kmPrefix then Result := khNone;
    end;
    Exit;
  end;
  if InChord or (Length(Keys) > 1) or TypedKey(Key, Shift) or OtaHost.MenuShortCut(SC) then Exit;
  Prefix := 0;
  if KeymapLookup(Map, Prefix, SC, Cmd, Arg) <> kmNone then Exit;
  B := DefaultBind;
  if B = nil then Exit;
  Inc(FProcessed);
  case Call(B, SC, Page) of
    krHandled: Result := khHandled;
    krNextProc: Result := khPassOn;
  end;
end;
{ an action of the main window that is one of Delphi's menu commands: an expert's procedure for it
  (AddMenuCommand) runs instead while the code editor has the keyboard - krHandled: the command
  itself does not }
procedure TSdOtaKeyboard.ActionExecute(Action: TBasicAction; var Handled: Boolean);
var
  Cmd: string;
  I: Integer;
  B: TSdKeyBind;
  Page: TEditorPage;
begin
  if Assigned(FOldExecute) then FOldExecute(Action, Handled);
  if Handled or (OtaHost = nil) then Exit;
  Cmd := MenuCommandOf(Action.Name);
  if Cmd = '' then Exit;
  Page := OtaHost.ActivePage;
  if (Page = nil) or not Page.CodeView or not Page.Editor.Shown or (Screen.ActiveControl <> Page.Editor.Window) then Exit;
  { a keystroke macro that records takes the command by its name - not one a key of the editor
    runs: the key is in the macro }
  if Recording and (FInKey = 0) then OwnRecord(FRecord).AppendCommand(Cmd);
  { the clipboard commands are the editor's own (EditorMenuCommand): Delphi 7's Edit menu runs no
    expert's procedure for them (measured) }
  if SameText(Cmd, mcClipCut) or SameText(Cmd, mcClipCopy) or SameText(Cmd, mcClipPaste) or
    SameText(Cmd, mcClipClear) then Exit;
  for I := FKeys.Count - 1 downto 0 do
  begin
    B := TSdKeyBind(FKeys[I]);
    if (B.Kind = kbMenuCommand) and SameText(B.Command, Cmd) then
    begin
      Inc(FProcessed);
      Handled := Call(B, 0, Page) = krHandled;
      Exit;
    end;
  end;
end;

{ a clipboard message of the code editor's window (WM_COPY ...): an expert's procedure for it
  (AddMenuCommand) runs instead - krHandled: the command itself does not (Delphi 7's, measured: its
  Edit menu and the editor's Ctrl+Insert run none) }
function TSdOtaKeyboard.EditorMenuCommand(Ed: TSciEdit; const Command: string): Boolean;
var
  I: Integer;
  B: TSdKeyBind;
  Page: TEditorPage;
begin
  Result := False;
  Page := OtaPageOfEditor(Ed);
  if Page = nil then Exit;
  for I := FKeys.Count - 1 downto 0 do
  begin
    B := TSdKeyBind(FKeys[I]);
    if (B.Kind = kbMenuCommand) and SameText(B.Command, Command) then
    begin
      Inc(FProcessed);
      Result := Call(B, 0, Page) = krHandled;
      Exit;
    end;
  end;
end;
procedure TSdOtaKeyboard.HookActions(List: TActionList);
begin
  if List = nil then Exit;
  FOldExecute := List.OnExecute;
  List.OnExecute := ActionExecute;
end;

procedure TSdOtaKeyboard.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  for I := FKeys.Count - 1 downto 0 do
    if FindHInstance(TMethod(TSdKeyBind(FKeys[I]).Proc).Code) = Module then FKeys.Delete(I);
  FBindings.DropModule(Module);
end;

function TSdOtaKeyboard.AddKeyboardBinding(const KeyBinding: IOTAKeyboardBinding): Integer;
begin
  Result := FBindings.Add(KeyBinding);
  if Result < 0 then Exit;
  try
    KeyBinding.BindKeyboard(TSdOtaBindingServices.Create(Self, Result));
  except
    OtaCaught('IOTAKeyboardBinding.BindKeyboard', False);
  end;
end;

procedure TSdOtaKeyboard.RemoveKeyboardBinding(Index: Integer);
var
  I: Integer;
begin
  for I := FKeys.Count - 1 downto 0 do
    if TSdKeyBind(FKeys[I]).Owner = Index then FKeys.Delete(I);
  FBindings.RemoveTold(Index, IOTAKeyboardBinding, 'IOTAKeyboardBinding');
end;

function TSdOtaKeyboard.GetCurrentPlayback: IOTARecord;
begin
  Result := FPlayback;
end;

function TSdOtaKeyboard.GetCurrentRecord: IOTARecord;
begin
  Result := FRecord;
end;

{ the current record records and is not paused }
function TSdOtaKeyboard.Recording: Boolean;
var
  R: TSdOtaRecord;
begin
  R := OwnRecord(FRecord);
  Result := (R <> nil) and R.Recording and not R.Paused;
end;

{ a record plays and is not paused }
function TSdOtaKeyboard.Playing: Boolean;
var
  R: TSdOtaRecord;
begin
  R := OwnRecord(FPlayback);
  Result := (R <> nil) and R.Playing and not R.Paused;
end;

{ the code editor of a file page (not a dialog's, a resource's or the Formatter's preview) }
function TSdOtaKeyboard.PageEditor(Ed: TSciEdit): Boolean;
begin
  Result := OtaPageOfEditor(Ed) <> nil;
end;

{ Delphi's RecordKeyMacro: nothing while a record plays; the current record recording (not
  paused) stops - a toggle -; else R starts, emptied first unless it is the current record that
  was paused (then it goes on) }
procedure TSdOtaKeyboard.RecordKeyMacro(const R: IOTARecord);
var
  New, Cur: TSdOtaRecord;
begin
  New := OwnRecord(R);
  if (New = nil) or Playing then Exit;
  Cur := OwnRecord(FRecord);
  if (Cur <> nil) and Cur.Recording and not Cur.Paused then
  begin
    Cur.Recording := False;
    Exit;
  end;
  if (Cur = nil) or not Cur.Paused or (Cur <> New) then
  begin
    if (Cur <> nil) and (Cur <> New) then
    begin
      Cur.Recording := False;
      Cur.Paused := False;
    end;
    New.Clear;
    FRecord := R;
  end;
  New.Recording := True;
  New.Paused := False;
end;

{ the active page's code editor: nil when no page shows its code }
function PlaybackEditor: TSciEdit;
var
  P: TEditorPage;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  P := OtaHost.ActivePage;
  if (P <> nil) and P.CodeView and P.Editor.Ready then Result := P.Editor;
end;

{ Delphi's PlayKeyMacro: nothing while a record records or without a code editor; R becomes the
  current playback and plays - from where it was paused, else from its start, one undo step -
  until its end or until an expert's binding pauses it (PausePlayback). A key goes through the
  key mapping, the experts' bindings and the menus' shortcuts as typed (TSciEdit.PlayKey), a
  character is typed, a command runs by its name (Delphi's menu commands: the main window's
  actions; the key mappings' commands: the editor's). }
procedure TSdOtaKeyboard.PlayKeyMacro(const R: IOTARecord);
var
  Rec: TSdOtaRecord;
  Ed: TSciEdit;
  It: TSdMacroItem;
  Key: Word;
  Shift: TShiftState;
begin
  Rec := OwnRecord(R);
  if (Rec = nil) or Recording then Exit;
  Ed := PlaybackEditor;
  if Ed = nil then Exit;
  FPlayback := R;
  if (Rec.Playing and not Rec.Paused) or (Rec.Count = 0) then Exit;
  if not Rec.Paused then Rec.Position := 0;
  Rec.Playing := True;
  Rec.Paused := False;
  Ed.BeginKeyPlayback;
  try
    while Rec.Position < Rec.Count do
    begin
      It := Rec.Items[Rec.Position];
      Rec.Position := Rec.Position + 1;
      if It.IsCommand then PlayCommand(Ed, It.Command)
      else if (It.Code and Integer($FFFF0000) = 0) and (It.Code and $FF >= 32) then Ed.PlayChar(Char(It.Code and $FF))
      else
      begin
        ShortCutToKey(KeyCodeToShortCut(It.Code), Key, Shift);
        if Key <> 0 then Ed.PlayKey(Key, Shift);
      end;
      { a key may close the page, an expert's binding pause the playback }
      if Rec.Paused or not PageEditor(Ed) then Break;
    end;
  finally
    if PageEditor(Ed) then Ed.EndKeyPlayback;
    if not Rec.Paused then Rec.Playing := False;
  end;
end;

function TSdOtaKeyboard.PlayCommand(Ed: TSciEdit; const Name: string): Boolean;
var
  I: Integer;
  Cmd: TEdCmd;
begin
  Result := False;
  I := MenuCommandIndex(Name);
  if I >= 0 then
  begin
    Result := (OtaHost <> nil) and OtaHost.ExecuteAction(MenuCommandActions[I].Action);
    Exit;
  end;
  if EdCmdByName(Name, Cmd) then
  begin
    Ed.ExecCommand(Cmd, 0);
    Result := True;
  end;
end;

{ SdSciEdit's hooks: a key of a page's code editor while a record records; Add - it goes into the
  record when the record still records (the key that stopped it is not in it) }
function TSdOtaKeyboard.MacroKeyStart(Ed: TSciEdit): Boolean;
begin
  Result := Recording and PageEditor(Ed);
  if Result then Inc(FInKey);
end;

procedure TSdOtaKeyboard.MacroKeyEnd(Ed: TSciEdit; Key: Word; Shift: TShiftState; Add: Boolean);
begin
  if FInKey > 0 then Dec(FInKey);
  if Add and Recording then OwnRecord(FRecord).AppendKey(ShortCutToKeyCode(ShortCut(Key, Shift)));
end;

procedure TSdOtaKeyboard.MacroChar(Ed: TSciEdit; Ch: Char);
begin
  if Recording and PageEditor(Ed) then OwnRecord(FRecord).AppendKey(Ord(Ch));
end;

{ test mode: what the current record and the current playback do - idle, rec, recpaused, play,
  playpaused - and their items }
function TSdOtaKeyboard.RecordDebugText: string;
var
  R, P: TSdOtaRecord;
begin
  R := OwnRecord(FRecord);
  P := OwnRecord(FPlayback);
  if (R <> nil) and R.Recording then
  begin
    if R.Paused then Result := 'recpaused' else Result := 'rec';
    Result := Result + ':' + IntToStr(R.Count);
  end
  else if (P <> nil) and P.Playing then
  begin
    if P.Paused then Result := 'playpaused' else Result := 'play';
    Result := Result + ':' + IntToStr(P.Count);
  end
  else if R <> nil then Result := 'idle:' + IntToStr(R.Count)
  else Result := 'idle:0';
end;

function TSdOtaKeyboard.GetEditorServices: IOTAEditorServices;
begin
  Result := Root.FEditor;
end;

function TSdOtaKeyboard.GetKeysProcessed: LongWord;
begin
  Result := FProcessed;
end;

function TSdOtaKeyboard.NewRecordObject(out ARecord: IOTARecord): Boolean;
begin
  ARecord := TSdOtaRecord.Create;
  Result := True;
end;

procedure TSdOtaKeyboard.PausePlayback;
var
  R: TSdOtaRecord;
begin
  R := OwnRecord(FPlayback);
  if (R <> nil) and R.Playing then R.Paused := True;
end;

procedure TSdOtaKeyboard.PauseRecord;
var
  R: TSdOtaRecord;
begin
  R := OwnRecord(FRecord);
  if (R <> nil) and R.Recording then R.Paused := True;
end;

{ Delphi's: the current playback plays on (PlayKeyMacro) }
procedure TSdOtaKeyboard.ResumePlayback;
begin
  if FPlayback <> nil then PlayKeyMacro(FPlayback);
end;

{ Delphi's: RecordKeyMacro of the current record - a paused one goes on, one that records stops }
procedure TSdOtaKeyboard.ResumeRecord;
begin
  if FRecord <> nil then RecordKeyMacro(FRecord);
end;

procedure TSdOtaKeyboard.RestartKeyboardServices;
begin
  FPending := nil;
end;

{ only the keyboard services' own records (NewRecordObject; an expert's own IOTARecord is ignored,
  as Delphi ignores it); not while the current playback plays, nor one that records or plays }
procedure TSdOtaKeyboard.SetPlaybackObject(const ARecord: IOTARecord);
var
  R, Cur: TSdOtaRecord;
begin
  Cur := OwnRecord(FPlayback);
  if (Cur <> nil) and Cur.Playing then Exit;
  if ARecord = nil then
  begin
    FPlayback := nil;
    Exit;
  end;
  R := OwnRecord(ARecord);
  if (R = nil) or R.Recording or R.Playing then Exit;
  FPlayback := ARecord;
end;

{ ... the record keys go into; nil clears it (Delphi 7 clears the playback instead) }
procedure TSdOtaKeyboard.SetRecordObject(const ARecord: IOTARecord);
var
  R, Cur: TSdOtaRecord;
begin
  Cur := OwnRecord(FRecord);
  if (Cur <> nil) and Cur.Recording then Exit;
  if ARecord = nil then
  begin
    FRecord := nil;
    Exit;
  end;
  R := OwnRecord(ARecord);
  if (R = nil) or R.Recording or R.Playing then Exit;
  FRecord := ARecord;
end;

procedure TSdOtaKeyboard.PopKeyboard(const Keyboard: string);
var
  I: Integer;
begin
  I := FKeyboards.IndexOf(Keyboard);
  if I >= 0 then FKeyboards.Delete(I);
end;

{ the keyboard pushed before - the editor's own by Delphi 7's name, 'Editor' (measured) }
function TSdOtaKeyboard.PushKeyboard(const Keyboard: string): string;
begin
  if FKeyboards.Count > 0 then Result := FKeyboards[FKeyboards.Count - 1] else Result := 'Editor';
  if not SameText(Keyboard, sEditor) then FKeyboards.Add(Keyboard);
end;

{ the first binding of Keys in the order they are called (KeyBoard: of that keyboard only, ''
  the editor's own); none of the experts': the IDE's key mapping - an expert chains to it }
function TSdOtaKeyboard.LookupKeyBinding(const Keys: array of TShortCut; out BindingRec: TKeyBindingRec;
  const KeyBoard: string): Boolean;
var
  Chain: TIntArray;
begin
  if KeyBoard = '' then Chain := KeyChain(Self, Keys, '*')
  else if SameText(KeyBoard, sEditor) then Chain := KeyChain(Self, Keys, '')
  else Chain := KeyChain(Self, Keys, KeyBoard);
  if Length(Chain) > 0 then Result := BindRec(BindById(Chain[0]), BindingRec)
  else Result := IdeRec(Keys, BindingRec);
end;

{ the binding called after BindingRec's (Next): an expert's, or the IDE's key mapping last }
function TSdOtaKeyboard.GetNextBindingRec(var BindingRec: TKeyBindingRec): Boolean;
var
  B: TSdKeyBind;
begin
  if BindingRec.Next = IdeNext then
  begin
    B := BindById(BindingRec.Reserved);
    Result := (B <> nil) and IdeRec(B.Keys, BindingRec);
  end
  else
    Result := BindRec(BindById(BindingRec.Next), BindingRec);
end;

function TSdOtaKeyboard.CallKeyBindingProc(const BindingRec: TKeyBindingRec): TKeyBindingResult;
var
  B: TSdKeyBind;
  Ctx: IOTAKeyContext;
begin
  Result := krUnhandled;
  if OtaHost = nil then Exit;
  B := BindById(BindingRec.Reserved);
  if B <> nil then
    Result := Call(B, BindingRec.KeyCode, OtaHost.ActivePage)
  else if Assigned(BindingRec.KeyProc) then
  begin
    { the IDE's key mapping (IdeRec) }
    Ctx := TSdOtaKeyContext.Create(BindingRec.Context, OtaPageBuffer(OtaHost.ActivePage), Self, BindingRec);
    try
      BindingRec.KeyProc(Ctx, BindingRec.KeyCode, Result);
    except
      OtaCaught('key binding', False);
    end;
  end;
end;

function TSdOtaKeyboard.GetKeyTracing: Boolean;
begin
  Result := FTracing;
end;

procedure TSdOtaKeyboard.SetKeyTracing(Value: Boolean);
begin
  FTracing := Value;
end;

constructor TSdOtaBindingServices.Create(AKeyboard: TSdOtaKeyboard; AOwner: Integer);
begin
  inherited Create;
  FKeyboard := AKeyboard;
  FOwner := AOwner;
end;

function TSdOtaBindingServices.AddKeyBinding(const Keys: array of TShortCut; KeyProc: TKeyBindingProc;
  Context: Pointer; Flags: TKeyBindingFlags; const Keyboard: string; const MenuItemName: string): Boolean;
begin
  Result := FKeyboard.AddBind(FOwner, Keys, KeyProc, Context, Flags, Keyboard);
end;

{ the menu commands' macros (mcClipCopy ...) are D7 Studio's actions: not rebound }
function TSdOtaBindingServices.AddMenuCommand(const Command: string; KeyProc: TKeyBindingProc;
  Context: Pointer): Boolean;
begin
  Result := FKeyboard.AddMenuCommand(FOwner, Command, KeyProc, Context);
end;

procedure TSdOtaBindingServices.SetDefaultKeyProc(KeyProc: TKeyBindingProc; Context: Pointer;
  const Keyboard: string);
begin
  FKeyboard.SetDefaultKeyProc(FOwner, KeyProc, Context, Keyboard);
end;

constructor TSdOtaKeyContext.Create(AContext: Pointer; const ABuffer: IOTAEditBuffer;
  const AKeyboard: IOTAKeyboardServices; const ARec: TKeyBindingRec);
begin
  inherited Create;
  FContext := AContext;
  FBuffer := ABuffer;
  FKeyboard := AKeyboard;
  FRec := ARec;
end;

function TSdOtaKeyContext.GetContext: Pointer;
begin
  Result := FContext;
end;

function TSdOtaKeyContext.GetEditBuffer: IOTAEditBuffer;
begin
  Result := FBuffer;
end;

function TSdOtaKeyContext.GetKeyboardServices: IOTAKeyboardServices;
begin
  Result := FKeyboard;
end;

function TSdOtaKeyContext.GetKeyBindingRec(out BindingRec: TKeyBindingRec): Boolean;
begin
  BindingRec := FRec;
  Result := True;
end;

{ ---------------------------------------------------------------- IOTAPackageServices }

{ the loaded packages (Delphi's list: OtaPackageEntry), the designer's own one included }
function TSdOtaPackages.GetPackageCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  if DesignHost = nil then Exit;
  for I := 0 to DesignHost.PackageCount - 1 do
    if DesignHost.Packages[I].Loaded then Inc(Result);
end;

function TSdOtaPackages.GetPackageName(Index: Integer): string;
var
  E: TPackageEntry;
begin
  E := OtaPackageEntry(Index);
  if E = nil then Result := '' else Result := ChangeFileExt(ExtractFileName(E.FileName), '');
end;

function TSdOtaPackages.GetComponentCount(PkgIndex: Integer): Integer;
var
  E: TPackageEntry;
  L: TStringList;
begin
  Result := 0;
  E := OtaPackageEntry(PkgIndex);
  if E = nil then Exit;
  L := TStringList.Create;
  try
    DesignHost.GetPackageComponents(E, L);
    Result := L.Count;
  finally
    L.Free;
  end;
end;

function TSdOtaPackages.GetComponentName(PkgIndex, CompIndex: Integer): string;
var
  E: TPackageEntry;
  L: TStringList;
begin
  Result := '';
  E := OtaPackageEntry(PkgIndex);
  if E = nil then Exit;
  L := TStringList.Create;
  try
    DesignHost.GetPackageComponents(E, L);
    if (CompIndex >= 0) and (CompIndex < L.Count) then Result := L.Names[CompIndex];
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- the IDE's events }

procedure InstallIDEServices;
begin
  if Services <> nil then Exit;
  Services := TSdIDEServices.Create;
  BorlandIDEServices := Services;
end;

{ every IDE notifier, IOTAIDENotifier50's own overloads where an expert has them }
type
  TIdeEvent = (ieFile, ieBefore, ieAfter);

type
  PIdeCall = ^TIdeCall;
  TIdeCall = record
    Event: TIdeEvent;
    Code: TOTAFileNotification;
    FileName: string;
    Project: IOTAProject;
    Succeeded: Boolean;
    Cancelled: Boolean;              // a notifier cancelled (FileNotification, BeforeCompile)
  end;

procedure IdeNotifyOne(const N: IInterface; Data: Pointer);
var
  N50: IOTAIDENotifier50;
  Cancel: Boolean;
begin
  Cancel := False;
  with PIdeCall(Data)^ do
    try
      case Event of
        ieFile: IOTAIDENotifier(N).FileNotification(Code, FileName, Cancel);
        ieBefore:
          if Supports(N, IOTAIDENotifier50, N50) then N50.BeforeCompile(Project, False, Cancel)
          else IOTAIDENotifier(N).BeforeCompile(Project, Cancel);
        ieAfter:
          if Supports(N, IOTAIDENotifier50, N50) then N50.AfterCompile(Succeeded, False)
          else IOTAIDENotifier(N).AfterCompile(Succeeded);
      end;
    finally
      { also when the notifier raised after it cancelled }
      if Cancel then Cancelled := True;
    end;
end;

function CallIde(Event: TIdeEvent; Code: TOTAFileNotification; const FileName: string;
  const Project: IOTAProject; Succeeded: Boolean): Boolean;
var
  C: TIdeCall;
begin
  Result := True;
  if Services = nil then Exit;
  C.Event := Event;
  C.Code := Code;
  C.FileName := FileName;
  C.Project := Project;
  C.Succeeded := Succeeded;
  C.Cancelled := False;
  Services.FGeneral.FNotifiers.Each(IOTAIDENotifier, IdeNotifyOne, @C, 'IOTAIDENotifier');
  Result := not C.Cancelled;
end;

{ the IDE notifiers first; when none cancelled, Delphi 1-3's add-in notifiers }
function OtaFileNotification(Code: TOTAFileNotification; const FileName: string): Boolean;
begin
  Result := CallIde(ieFile, Code, FileName, nil, False);
  if Result then Result := LegacyFileNotification(Code, FileName);
end;

procedure OtaProjectFileChanged(const FileName: string; Added: Boolean);
begin
  LegacyProjectFile(FileName, Added);
end;

procedure OtaProjectClosed;
begin
  LegacyProjectChanged;
end;

procedure OtaLegacyState(L: TStrings);
begin
  L.Add('legacy=' + LegacyDebugText);
  LegacyDebugLines(L);
end;

function OtaBeforeCompile(const ProjectFile: string): Boolean;
var
  P: IOTAProject;
begin
  { Delphi's kibitz manager hears the compile (Cominout.EvBeforeCompile): code insight ends }
  if Services <> nil then Services.FCodeInsight.Cancel;
  { Delphi 1-3's add-in notifiers before the IDE notifiers (Delphi 7's compile); they may change
    the project's resources (TIResourceFile), written below }
  Result := LegacyCompile(True, False);
  Supports(OtaModules.ModuleIntf(ProjectFile), IOTAProject, P);
  if Result then Result := CallIde(ieBefore, ofnFileOpening, '', P, False);
  { what the experts changed through IOTAProjectResource (a build counter, the time of the build)
    goes into the .res the compiler links }
  OtaModules.FlushResources;
  { the compile takes the forms as they are, unsaved ones too: streamed out }
  if Result then OtaModules.FormsStreamed;
end;

procedure OtaFlushResources;
begin
  OtaModules.FlushResources;
end;

procedure OtaAfterCompile(Succeeded: Boolean);
begin
  LegacyCompile(False, Succeeded);
  CallIde(ieAfter, ofnFileOpening, '', nil, Succeeded);
end;

procedure OtaDebugStateChanged;
begin
  if Services <> nil then
    try
      Services.FDebugger.StateChanged;
    except
      OtaCaught('debugger', False);
    end;
end;

procedure OtaBreakpointsChanged;
begin
  if Services <> nil then
    try
      Services.FDebugger.BreakpointsChanged;
    except
      OtaCaught('breakpoints', False);
    end;
end;

procedure OtaBuildMessagesCleared;
begin
  OtaMessageGroupCleared(0);
end;

procedure OtaMessageGroupCleared(Index: Integer);
begin
  if Services <> nil then Services.FMessages.GroupCleared(Index);
end;

{ SdSciEdit's hooks }
function EditorKeyHook(Ed: TSciEdit; Key: Word; Shift: TShiftState; InChord: Boolean): TSciKeyHookResult;
begin
  if Services = nil then Result := khNone
  else Result := Services.FKeyboard.EditorKey(Ed, Key, Shift, InChord);
end;

function MenuCommandHook(Ed: TSciEdit; const Command: string): Boolean;
begin
  Result := (Services <> nil) and Services.FKeyboard.EditorMenuCommand(Ed, Command);
end;

function MacroKeyStartHook(Ed: TSciEdit): Boolean;
begin
  Result := (Services <> nil) and Services.FKeyboard.MacroKeyStart(Ed);
end;

procedure MacroKeyEndHook(Ed: TSciEdit; Key: Word; Shift: TShiftState; Add: Boolean);
begin
  if Services <> nil then Services.FKeyboard.MacroKeyEnd(Ed, Key, Shift, Add);
end;

procedure MacroCharHook(Ed: TSciEdit; Ch: Char);
begin
  if Services <> nil then Services.FKeyboard.MacroChar(Ed, Ch);
end;

{ SdPageFileSystem's: an expert's file system of the ID (IOTAModuleServices.AddFileSystem) }
function PageFileSystemOfID(const ID: string): TSdPageFileSystem;
var
  FS: IOTAFileSystem;
begin
  Result := nil;
  if (Services = nil) or (ID = '') then Exit;
  FS := Services.FModules.FileSystemOf(ID);
  if FS <> nil then Result := TSdOtaPageFileSystem.Create(FS);
end;

{ the pages read and written through a file system whose code lies in Module: closed while the
  file system is still there (Save asks, and writes through it), else closed without asking }
procedure CloseFileSystemPages(Module: HMODULE);
var
  I, K: Integer;
  P: TEditorPage;
  FS: IOTAFileSystem;
begin
  if OtaHost = nil then Exit;
  I := OtaHost.PageCount - 1;
  while I >= 0 do
  begin
    if I < OtaHost.PageCount then
    begin
      P := OtaHost.Pages(I);
      if P.FileSystem <> '' then
      begin
        FS := Services.FModules.FileSystemOf(P.FileSystem);
        if (FS <> nil) and (InterfaceModule(FS) = Module) then
        begin
          FS := nil;
          if not OtaHost.ClosePage(P, True) then
            for K := 0 to OtaHost.PageCount - 1 do
              if OtaHost.Pages(K) = P then
              begin
                OtaHost.ClosePage(P, False);
                Break;
              end;
        end;
      end;
    end;
    Dec(I);
  end;
end;

{ SdDesignHost's hooks }
procedure PackageUnloading(Module: HMODULE);
begin
  if Services = nil then Exit;
  { Delphi 1-3's experts first: their wizards' code is the IDE's, the experts' the package's }
  try
    LegacyDropModule(Module);
  except
    OtaCaught('Delphi 1-3 experts of a module that goes', False);
  end;
  Services.FWizards.DropModule(Module);
  Services.FGeneral.FNotifiers.DropModule(Module);
  Services.FMessages.FNotifiers.DropModule(Module);
  Services.FMessages.DropModule(Module);
  Services.FKeyboard.DropModule(Module);
  CloseFileSystemPages(Module);
  Services.FModules.FFileSystems.DropModule(Module);
  Services.FDebugger.DropModule(Module);
  Services.FToDo.DropModule(Module);
  Services.FCodeInsight.DropModule(Module);
  Services.FHighlight.DropModule(Module);
  Services.FToolsFilter.DropModule(Module);
  SpeedSettings.DropModule(Module);
  OtaModules.DropModule(Module);
  DeskDropModule(Module);
end;

procedure PackageChanged(const FileName: string; Loaded: Boolean);
begin
  if Loaded then OtaFileNotification(ofnPackageInstalled, FileName)
  else OtaFileNotification(ofnPackageUninstalled, FileName);
end;

procedure OtaHostReady(View: TSdMessageView);
begin
  if Services = nil then Exit;
  HostIsReady := True;
  Services.FMessages.AttachView(View);
  Services.FWizards.HostReady;
  if (OtaHost <> nil) and (OtaHost.ActionList is TActionList) then
    Services.FKeyboard.HookActions(TActionList(OtaHost.ActionList));
end;

procedure OtaLoadExperts;
begin
  if (Services = nil) or not HostIsReady then Exit;
  { Delphi 7's order: the version control manager, then the experts' DLLs }
  LegacyHostReady;
  LoadExperts;
end;

{ The IDE ends, as Delphi 7's does: the wizards (and Delphi 1-3's experts) told Destroyed and
  released, the DLL experts terminated, the version control manager unloaded, the experts'
  packages unloaded (their finalization runs; Borland's other design packages stay), what is still
  registered with the services told Destroyed, the experts' DLLs unloaded. }
procedure OtaShutdown;
var
  I: Integer;
  X: TSdExpertDll;
  Mods: TList;
begin
  if Services = nil then Exit;
  Mods := TList.Create;
  try
    { the experts' packages: where the code of their wizards and notifiers is }
    Services.FWizards.FWizards.AddModules(Mods);
    Services.FGeneral.FNotifiers.AddModules(Mods);
    Services.FKeyboard.FBindings.AddModules(Mods);
    Services.FToDo.AddModules(Mods);
    Services.FCodeInsight.AddModules(Mods);
    Services.FHighlight.AddModules(Mods);
    Services.FToolsFilter.AddModules(Mods);
    Services.FModules.FFileSystems.AddModules(Mods);
    SpeedSettings.AddModules(Mods);
    LegacyAddModules(Mods);
    Mods.Remove(Pointer(HInstance));
    { the Messages view's lists draw and take keys as plain lists from now on }
    Services.FMessages.DetachView;
    Services.FWizards.Shutdown;
    for I := Experts.Count - 1 downto 0 do
    begin
      X := TSdExpertDll(Experts[I]);
      TerminateDll(X.OldTerminate, X.Terminate, X.FileName);
    end;
    { the edit window's stand-in once the wizards have ended, as Delphi closes its edit windows
      before it unloads the experts: what they put on it - GExperts adds a component as its
      wizards end - is freed while their code is loaded, packages and DLLs (SdOtaEditWindow) }
    DestroyEditWindow;
    { Delphi 1-3's version control manager released and unloaded (Delphi 7: before the experts) }
    LegacyShutdown;
    { the To-Do List's notifiers told Destroyed, its managers and the experts' items released, the
      code insight managers too - while the experts' packages are still there }
    try
      Services.FToDo.Shutdown;
      Services.FCodeInsight.Shutdown;
    except
      OtaCaught('To-Do List and code insight at exit', False);
    end;
    { the experts' highlighters, tools filters and speed settings told Destroyed, while their
      packages are there }
    try
      Services.FHighlight.Shutdown;
      Services.FToolsFilter.Shutdown;
      SpeedSettings.Shutdown;
    except
      OtaCaught('highlighters, tools filters and speed settings at exit', False);
    end;
    try
      DesignHost.UnloadAtExit(Mods);
    except
      OtaCaught('the experts'' packages at exit', False);
    end;
  finally
    Mods.Free;
  end;
  Services.FGeneral.FNotifiers.DestroyAll('IOTAIDENotifier');
  Services.FMessages.FNotifiers.DestroyAll('IOTAMessageNotifier');
  Services.FKeyboard.FBindings.DestroyAll('IOTAKeyboardBinding');
  Services.FDebugger.Shutdown;
  HostIsReady := False;
  { the experts' DLLs unloaded last (Delphi 7's FreeLibrary after their terminate procedures),
    when nothing of theirs is called any more: what they left registered is dropped first }
  for I := Experts.Count - 1 downto 0 do
  begin
    X := TSdExpertDll(Experts[I]);
    try
      PackageUnloading(X.Module);
      FreeLibrary(X.Module);
    except
      OtaCaught('expert ' + X.FileName + ' at exit', False);
    end;
  end;
  Experts.Clear;
end;

function OtaDebugText: string;
var
  I, N: Integer;
begin
  Result := '';
  if Services = nil then Exit;
  N := 0;
  for I := 0 to Services.FWizards.FWizards.Count - 1 do
    if Services.FWizards.FWizards[I] <> nil then Inc(N);
  Result := Format('wizards=%d menu=%d experts=%d bindings=%d notifiers=%d groups=%s ' +
    'highlighters=%s filters=%s filesystems=%d rec=%s speed=%s',
    [N, Services.FWizards.FActions.Count, Experts.Count, Services.FKeyboard.BindingCount,
     Services.FGeneral.FNotifiers.Active, Services.FMessages.DebugText, Services.FHighlight.DebugText,
     Services.FToolsFilter.DebugText, Services.FModules.FFileSystems.Active,
     Services.FKeyboard.RecordDebugText, SpeedSettings.DebugText]);
end;

procedure OtaMessageRows(List: TListBox; Rows: TStrings);
var
  I: Integer;
  O: TObject;
begin
  for I := 0 to List.Items.Count - 1 do
  begin
    O := List.Items.Objects[I];
    if (O is TSdOtaMessage) and (TSdOtaMessage(O).ChildCount > 0) then
    begin
      if TSdOtaMessage(O).Expanded then Rows.Add('-' + List.Items[I]) else Rows.Add('+' + List.Items[I]);
    end
    else
      Rows.Add(List.Items[I]);
  end;
end;

procedure OtaRecordMacro;
begin
  if Services <> nil then Services.FKeyboard.RecordKeyMacro(Services.FKeyboard.FIdeRecord);
end;

procedure OtaPlayMacro;
begin
  if Services <> nil then Services.FKeyboard.PlayKeyMacro(Services.FKeyboard.FIdeRecord);
end;

function OtaMacroRecording: Boolean;
begin
  Result := (Services <> nil) and Services.FKeyboard.Recording;
end;

function OtaMacroPlaying: Boolean;
begin
  Result := (Services <> nil) and Services.FKeyboard.Playing;
end;

function OtaMacroLength: Integer;
var
  R: TSdOtaRecord;
begin
  Result := 0;
  if Services = nil then Exit;
  R := OwnRecord(Services.FKeyboard.FIdeRecord);
  if R <> nil then Result := R.Count;
end;

initialization
  Experts := TObjectList.Create(True);
  InstallIDEServices;
  OtaWizardHook := RegisterWizard;
  OtaPackageUnloading := PackageUnloading;
  OtaPackageChanged := PackageChanged;
  SciKeyHook := EditorKeyHook;
  SciMenuCommandHook := MenuCommandHook;
  SciMacroKeyStart := MacroKeyStartHook;
  SciMacroKeyEnd := MacroKeyEndHook;
  SciMacroChar := MacroCharHook;
  PageFileSystemOf := PageFileSystemOfID;
end.
