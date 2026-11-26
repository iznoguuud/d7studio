{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaLegacy;

{ D7 Studio - the experts' interface of Delphi 1-3 (ExptIntf, ToolIntf, VcsIntf) on top of D7 Studio's
Open Tools API, as Delphi 7's IDE still gives it.

  * ExptIntf.ToolServices (designide's variable, shared by every package; a DLL gets the same
    object as its entry point's argument) is a TSdToolServices: every TIToolServices method on the
    Open Tools API's services, OtaHost and OtaModules. It is never destroyed by an expert's Free.
  * An expert (TIExpert: a package's RegisterLibraryExpert, a DLL's INITEXPERT0017) becomes an
    IOTAWizard registered with IOTAWizardServices.AddWizard - one manager of experts and wizards, as
    in Delphi 7: esStandard an IOTAMenuWizard (an item of the Help menu, above the menu wizards'),
    esForm / esProject an IOTAFormWizard / IOTAProjectWizard (File | New | Other), esAddIn an
    IOTAWizard only (kept, never executed). The wizard frees the expert (TInterface.Free) when it
    goes: its package unloaded, the IDE's end.
  * The menu interfaces (TIMainMenuIntf, TIMenuItemIntf): the main menu's items by their names
    (Delphi 7's: ToolsMenu, HelpMenu ...); an item an expert inserts is an action of WizardActions
    with its menu item, and goes when the expert frees the interface InsertItem gave it.
  * The add-in notifiers (TIAddInNotifier), in the order registered: the Open Tools API's file
    events after the IDE notifiers (when none cancelled), files added to and removed from the
    project, and for AddNotifierEx's the compile (enBeforeCompile before the new BeforeCompile).
  * The version control manager of Delphi 1-3 (VcsIntf: a DLL with INITVCS0014, named in D7
    Studio's registry key or settings, Version Control | VCSManager), with a TIToolServices of its
    own: its menu before Tools, its verbs actions.
  * An expert's objects belong to another module (a DLL without packages has its own TObject,
    TInterface and Exception): only their virtual methods are called, and whatever they raise is
    caught whatever its class - logged (error.log), shown too while the user's command runs it.
    Load and registration errors are logged only.
  * The module interfaces and file systems of EditIntf / FileIntf: SdOtaLegacyModules. }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

interface

uses
  Windows, ActiveX, SysUtils, Classes, Menus, ActnList, ToolsAPI, VirtIntf, ExptIntf, EditIntf,
  FileIntf, ToolIntf;

type
  { an IOTAWizard that stands for a Delphi 1-3 expert: its Help item goes above the menu wizards' }
  ISdLegacyExpert = interface
    ['{4F7D2C61-0B3E-4A58-9C1D-6E2F8A3B5D17}']
    function ExpertStyle: TExpertStyle;
    function ExpertModule: HMODULE;     // where the expert's code is
  end;

{ a DLL's INITEXPERT0017 (Init) called with ToolServices; the experts it registers are the DLL's;
  Terminate its procedure for the end (ExptIntf.TExpertTerminateProc). False: the DLL refused or
  failed (logged) - what it registered is to be dropped }
function LegacyInitDll(Init: Pointer; const FileName: string; var Terminate: TWizardTerminateProc): Boolean;
{ the main window is there: the version control manager loaded, its menu made }
procedure LegacyHostReady;
{ a package or a DLL goes: its experts' wizards removed, its notifiers, file systems and module
  notifiers forgotten, the handlers of its menu items cleared }
procedure LegacyDropModule(Module: HMODULE);
{ the IDE ends: the version control manager released and unloaded }
procedure LegacyShutdown;
{ the packages of the experts and notifiers registered (HMODULE in List, each once) - Borland's own
  packages of Delphi's Bin left out: they stay loaded at the end }
procedure LegacyAddModules(List: TList);
{ the add-in notifiers hear a file event of the Open Tools API (False: one cancelled) }
function LegacyFileNotification(Code: TOTAFileNotification; const FileName: string): Boolean;
{ ... a file added to (Added) or removed from the active project }
procedure LegacyProjectFile(const FileName: string; Added: Boolean);
{ ... a compile: Before - enBeforeCompile (False: cancelled); else enAfterCompile with Succeeded }
function LegacyCompile(Before, Succeeded: Boolean): Boolean;
{ a project was opened, made active or closed: the version control manager hears it }
procedure LegacyProjectChanged;
{ the module whose code makes a wizard: a Delphi 1-3 expert's own, else where the wizard's vtable lies }
function WizardModule(const Wizard: IInterface): HMODULE;
{ a module of Borland's own packages: one of Delphi's Bin }
function IsDelphiBinModule(M: HMODULE): Boolean;
{ test mode: the state dump's "legacy=" field and its [legacy] lines }
function LegacyDebugText: string;
procedure LegacyDebugLines(L: TStrings);

implementation

uses
  Registry, Forms, SdOtaCore, SdOtaModules, SdOtaLegacyModules, SdSettings,
  SdDelphiDir, SdDesignHost, SdEditorPage, SdProject, SdProjectGroup, SdFileNames, Utf8Mode;

type
  { ToolServices: one object, never freed by an expert (Delphi's TToolServices; the version control
    manager gets one of its own) }
  TSdToolServices = class(TIToolServices)
  public
    function AddRef: Longint; override;
    function Release: Longint; override;
    { TIToolServices }
    function CloseProject: Boolean; override;
    function OpenProject(const ProjName: string): Boolean; override;
    function OpenProjectInfo(const ProjName: string): Boolean; override;
    function SaveProject: Boolean; override;
    function CloseFile(const FileName: string): Boolean; override;
    function SaveFile(const FileName: string): Boolean; override;
    function OpenFile(const FileName: string): Boolean; override;
    function ReloadFile(const FileName: string): Boolean; override;
    function ModalDialogBox(Instance: THandle; TemplateName: PChar; WndParent: HWnd;
      DialogFunc: TFarProc; InitParam: LongInt): Integer; override;
    function CreateModule(const ModuleName: string; Source, Form: IStream;
      CreateFlags: TCreateModuleFlags): Boolean; override;
    function CreateModuleEx(const ModuleName, FormName, AncestorClass, FileSystem: string;
      Source, Form: IStream; CreateFlags: TCreateModuleFlags): TIModuleInterface; override;
    function GetParentHandle: HWND; override;
    function GetProjectName: string; override;
    function GetUnitCount: Integer; override;
    function GetUnitName(Index: Integer): string; override;
    function EnumProjectUnits(EnumProc: TProjectEnumProc; Param: Pointer): Boolean; override;
    function GetFormCount: Integer; override;
    function GetFormName(Index: Integer): string; override;
    function GetCurrentFile: string; override;
    function IsFileOpen(const FileName: string): Boolean; override;
    function GetNewModuleName(var UnitIdent, FileName: string): Boolean; override;
    function GetModuleCount: Integer; override;
    function GetModuleName(Index: Integer): string; override;
    function GetComponentCount(ModIndex: Integer): Integer; override;
    function GetComponentName(ModIndex, CompIndex: Integer): string; override;
    function RegisterFileSystem(AVirtualFileSystem: TIVirtualFileSystem): Boolean; override;
    function UnRegisterFileSystem(const Ident: string): Boolean; override;
    function GetFileSystem(const Ident: string): TIVirtualFileSystem; override;
    function GetModuleInterface(const FileName: string): TIModuleInterface; override;
    function GetFormModuleInterface(const FormName: string): TIModuleInterface; override;
    function GetMainMenu: TIMainMenuIntf; override;
    function AddNotifier(AddInNotifier: TIAddInNotifier): Boolean; override;
    function RemoveNotifier(AddInNotifier: TIAddInNotifier): Boolean; override;
    function NewPascalString(Str: PChar): Pointer; override;
    procedure FreePascalString(var Str: Pointer); override;
    procedure ReferencePascalString(var Str: Pointer); override;
    procedure AssignPascalString(var Dest, Src: Pointer); override;
    procedure RaiseException(const Message: string); override;
    function GetBaseRegistryKey: string; override;
    function GetFormBounds(BoundsType: TBoundsType): TRect; override;
    function ProjectCreate(ProjectCreator: TIProjectCreator;
      CreateFlags: TCreateProjectFlags): TIModuleInterface; override;
    function ModuleCreate(ModuleCreator: TIModuleCreator;
      CreateFlags: TCreateModuleFlags): TIModuleInterface; override;
    function AddNotifierEx(AddInNotifier: TIAddInNotifier): Boolean; override;
    function GetNewModuleAndClassName(const Prefix: string; var UnitIdent,
      ClassName, FileName: string): Boolean; override;
    function CreateCppModule(const ModuleName, FormName, AncestorClass,
      FileSystem: string; HdrSource, Source, Form: IStream;
      CreateFlags: TCreateModuleFlags): TIModuleInterface; override;
    function GetVcsCount: Integer; override;
    procedure GetVcsList(List: TStringList); override;
    function GetVcsName(Index: Integer): string; override;
    function EnumProjectModules(EnumProc: TProjectEnumModuleProc; Param: Pointer): Boolean; override;
    function ProjectCreateEx(ProjectCreator: TIProjectCreatorEx;
      CreateFlags: TCreateProjectFlags): TIModuleInterface; override;
    function ModuleCreateEx(ModuleCreator: TIModuleCreatorEx;
      CreateFlags: TCreateModuleFlags): TIModuleInterface; override;
  end;

  { the texts of an expert the wizards hand on }
  TSdExpertText = (etName, etMenuText, etAuthor, etComment, etPage);

  { the IOTAWizard of an expert: it frees the expert once (TInterface.Free) when it goes }
  TSdExpertWizard = class(TInterfacedObject, IOTANotifier, IOTAWizard, ISdLegacyExpert)
  private
    FExpert: TIExpert;
    FStyle: TExpertStyle;
    FModule: HMODULE;                  // where the expert's code is
    FDll: Boolean;                     // registered by a DLL's INITEXPERT0017
    FIndex: Integer;                   // IOTAWizardServices.AddWizard's
    FRegistered: Boolean;              // the wizard services took it: the expert is freed at the end
    FID: string;
  protected
    { a text of the expert ('' once it was released) }
    function ExpertText(Which: TSdExpertText): string;
  public
    constructor Create(AExpert: TIExpert; AStyle: TExpertStyle; AModule: HMODULE; ADll: Boolean);
    destructor Destroy; override;
    procedure ReleaseExpert;
    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    { ISdLegacyExpert }
    function ExpertStyle: TExpertStyle;
    function ExpertModule: HMODULE;
  end;

  TSdExpertMenuWizard = class(TSdExpertWizard, IOTAMenuWizard)
  public
    function GetMenuText: string;
  end;

  TSdExpertRepositoryWizard = class(TSdExpertWizard, IOTARepositoryWizard)
  public
    function GetAuthor: string;
    function GetComment: string;
    function GetPage: string;
    function GetGlyph: Cardinal;
  end;

  TSdExpertFormWizard = class(TSdExpertRepositoryWizard, IOTAFormWizard);
  TSdExpertProjectWizard = class(TSdExpertRepositoryWizard, IOTAProjectWizard);

  TSdMenuItemIntf = class;

  { the command of a menu item an expert inserted (its OnClick) }
  TSdLegacyMenuAction = class(TAction)
  private
    FIntf: TSdMenuItemIntf;
    procedure DoExecute(Sender: TObject);
  end;

  { the main menu: its items by their names }
  TSdMainMenuIntf = class(TIMainMenuIntf)
  private
    FMenu: TMainMenu;
  public
    constructor Create(AMenu: TMainMenu);
    function GetMenuItems: TIMenuItemIntf; override;
    function FindMenuItem(const Name: string): TIMenuItemIntf; override;
  end;

  { an item of the main menu. One an expert inserted (Own) is changed through it, and goes with the
    last reference to it (the expert's Free, or DestroyMenuItem); the IDE's own items are read only }
  TSdMenuItemIntf = class(TIMenuItemIntf)
  private
    FItem: TMenuItem;
    FOwn: Boolean;
    FAction: TSdLegacyMenuAction;
    FOnClick: TIMenuClickEvent;
    procedure ItemGone;
    function CanModify: Boolean;
    procedure FreeItem;
  public
    constructor Create(AItem: TMenuItem; AOwn: Boolean);
    destructor Destroy; override;
    function DestroyMenuItem: Boolean; override;
    function GetIndex: Integer; override;
    function GetItemCount: Integer; override;
    function GetItem(Index: Integer): TIMenuItemIntf; override;
    function GetName: string; override;
    function GetParent: TIMenuItemIntf; override;
    function GetCaption: string; override;
    function SetCaption(const Caption: string): Boolean; override;
    function GetShortCut: Integer; override;
    function SetShortCut(ShortCut: Integer): Boolean; override;
    function GetFlags: TIMenuFlags; override;
    function SetFlags(Mask, Flags: TIMenuFlags): Boolean; override;
    function GetGroupIndex: Integer; override;
    function SetGroupIndex(GroupIndex: Integer): Boolean; override;
    function GetHint: string; override;
    function SetHint(Hint: string): Boolean; override;
    function getContext: Integer; override;
    function setContext(Context: Integer): Boolean; override;
    function GetOnClick: TIMenuClickEvent; override;
    function SetOnClick(Click: TIMenuClickEvent): Boolean; override;
    function InsertItem(Index: Integer; Caption, Name, Hint: string;
      ShortCut, Context, GroupIndex: Integer; Flags: TIMenuFlags;
      EventHandler: TIMenuClickEvent): TIMenuItemIntf; override;
  end;

  { hears the menu items the wrappers stand for being freed }
  TSdMenuWatch = class(TComponent)
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

  { VcsIntf.TIVCSClient, method for method: VcsIntf is a unit of Delphi's IDE (coreide70), not of
    designide, and the client is the DLL's object - only its virtual methods are called }
  TSdVcsClient = class(TInterface)
  public
    function GetIDString: string; virtual; stdcall; abstract;
    procedure ExecuteVerb(Index: Integer); virtual; stdcall; abstract;
    function GetMenuName: string; virtual; stdcall; abstract;
    function GetVerb(Index: Integer): string; virtual; stdcall; abstract;
    function GetVerbCount: Integer; virtual; stdcall; abstract;
    function GetVerbState(Index: Integer): Word; virtual; stdcall; abstract;
    procedure ProjectChange; virtual; stdcall; abstract;
  end;

  TVCSManagerInitProc = function(VCSInterface: TIToolServices): TSdVcsClient; stdcall;

  { a verb of the version control manager: its menu item's command }
  TSdVcsVerbAction = class(TAction)
  private
    FVerb: Integer;
    procedure DoExecute(Sender: TObject);
    procedure DoUpdate(Sender: TObject);
  end;

  { the version control manager: its DLL, its client, its ToolServices, its menu }
  TSdVcsManager = class
  public
    FileName: string;
    Module: HMODULE;
    Client: TSdVcsClient;
    Tools: TSdToolServices;
    ID: string;
    Menu: TMenuItem;
    Actions: TList;                    // TSdVcsVerbAction
    constructor Create;
    destructor Destroy; override;
    procedure MakeMenu;
    procedure FreeMenu;
  end;

const
  VcsEntryPoint = 'INITVCS0014';
  VcsSection = 'Version Control';
  VcsValue = 'VCSManager';
  vsEnabled = $01;
  vsChecked = $02;
  { the help context of the experts' items in Delphi 7 }
  ExpertHelpContext = 4520;

var
  Services: TSdToolServices;            // ExptIntf.ToolServices
  Wizards: TList;                       // TSdExpertWizard: the experts registered
  FileNotifiers: TList;                 // TIAddInNotifier (AddNotifier, AddNotifierEx)
  EventNotifiers: TList;                // TIAddInNotifier (AddNotifierEx)
  MenuIntfs: TList;                     // TSdMenuItemIntf alive
  MenuWatch: TSdMenuWatch;
  Vcs: TSdVcsManager;
  CurrentDllName: string;               // the DLL whose INITEXPERT0017 runs
  DllCount: Integer;                    // the DLLs whose INITEXPERT0017 accepted

{ ---------------------------------------------------------------- helpers }

function WizardServices: IOTAWizardServices;
begin
  if not Supports(BorlandIDEServices, IOTAWizardServices, Result) then Result := nil;
end;

type
  { a list of files of the active project into L (False: no project) }
  TSdFileLister = function(L: TStrings): Boolean;

{ Delphi 7's list of the active project's files: its source, its resources, its options, the units
  (Objects: their TProjectUnit) - for a version control system (ForVcs) each unit's form file after
  it and no objects; False: no project }
function ProjectFiles(L: TStrings; ForVcs: Boolean): Boolean;
var
  P: TSdProject;
  I: Integer;
begin
  L.Clear;
  Result := False;
  if (OtaHost = nil) or (OtaHost.Project = nil) then Exit;
  P := OtaHost.Project;
  L.Add(P.FileName);
  L.Add(ChangeFileExt(P.FileName, '.res'));
  L.Add(ChangeFileExt(P.FileName, '.dof'));
  for I := 0 to P.UnitCount - 1 do
    if not ForVcs then L.AddObject(P.Units[I].FileName, P.Units[I])
    else
    begin
      L.Add(P.Units[I].FileName);
      if P.Units[I].HasForm then L.Add(ChangeFileExt(P.Units[I].FileName, '.dfm'));
    end;
  Result := True;
end;

function ProjectFileList(L: TStrings): Boolean;
begin
  Result := ProjectFiles(L, False);
end;

{ the files a version control system keeps: the units' form files too }
function VcsFiles(L: TStrings): Boolean;
begin
  Result := ProjectFiles(L, True);
end;

{ the project's units with a form, the form files' names }
function FormFiles(L: TStrings): Boolean;
var
  P: TSdProject;
  I: Integer;
begin
  L.Clear;
  Result := False;
  if (OtaHost = nil) or (OtaHost.Project = nil) then Exit;
  P := OtaHost.Project;
  for I := 0 to P.UnitCount - 1 do
    if P.Units[I].HasForm then L.Add(ChangeFileExt(P.Units[I].FileName, '.dfm'));
  Result := True;
end;

{ the number of files Lister gives (what fails is reported as Where) }
function ListedCount(Lister: TSdFileLister; const Where: string): Integer;
var
  L: TStringList;
begin
  Result := 0;
  L := TStringList.Create;
  try
    try
      if Lister(L) then Result := L.Count;
    except
      LegacyFailed(Where);
    end;
  finally
    L.Free;
  end;
end;

{ ... the Index-th of them ('' none) }
function ListedItem(Lister: TSdFileLister; Index: Integer; const Where: string): string;
var
  L: TStringList;
begin
  Result := '';
  L := TStringList.Create;
  try
    try
      if Lister(L) and (Index >= 0) and (Index < L.Count) then Result := L[Index];
    except
      LegacyFailed(Where);
    end;
  finally
    L.Free;
  end;
end;

{ entry I of ProjectFileList as the enumerations give it: the names of its unit and of its form -
  the project's name for its source, neither for a file that is no unit }
procedure ProjectEntry(L: TStrings; I: Integer; out UnitName, FormName: string);
var
  U: TProjectUnit;
begin
  UnitName := '';
  FormName := '';
  U := TProjectUnit(L.Objects[I]);
  if I = 0 then UnitName := OtaHost.Project.Name
  else if U <> nil then
  begin
    UnitName := U.Name;
    FormName := U.FormName;
  end;
end;

{ ---------------------------------------------------------------- TSdExpertWizard }

constructor TSdExpertWizard.Create(AExpert: TIExpert; AStyle: TExpertStyle; AModule: HMODULE; ADll: Boolean);
begin
  inherited Create;
  FExpert := AExpert;
  FStyle := AStyle;
  FModule := AModule;
  FDll := ADll;
  FIndex := -1;
  Wizards.Add(Self);
end;

destructor TSdExpertWizard.Destroy;
begin
  Wizards.Remove(Self);
  ReleaseExpert;
  inherited;
end;

procedure TSdExpertWizard.ReleaseExpert;
var
  E: TIExpert;
begin
  E := FExpert;
  FExpert := nil;
  if (E = nil) or not FRegistered then Exit;
  try
    E.Free;
  except
    OtaCaught('TIExpert released', False);
  end;
end;

procedure TSdExpertWizard.AfterSave;
begin
end;

procedure TSdExpertWizard.BeforeSave;
begin
end;

procedure TSdExpertWizard.Destroyed;
begin
  ReleaseExpert;
end;

procedure TSdExpertWizard.Modified;
begin
end;

function TSdExpertWizard.GetIDString: string;
begin
  Result := FID;
  if FExpert = nil then Exit;
  try
    Result := FExpert.GetIDString;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

{ what the expert's code raises goes on to the caller as an Exception of this module }
function TSdExpertWizard.ExpertText(Which: TSdExpertText): string;
begin
  Result := '';
  if FExpert = nil then Exit;
  try
    case Which of
      etName: Result := FExpert.GetName;
      etMenuText: Result := FExpert.GetMenuText;
      etAuthor: Result := FExpert.GetAuthor;
      etComment: Result := FExpert.GetComment;
    else
      Result := FExpert.GetPage;
    end;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdExpertWizard.GetName: string;
begin
  Result := ExpertText(etName);
end;

function TSdExpertWizard.GetState: TWizardState;
var
  S: TExpertState;
begin
  Result := [];
  if FExpert = nil then Exit;
  try
    S := FExpert.GetState;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
  if esEnabled in S then Include(Result, wsEnabled);
  if esChecked in S then Include(Result, wsChecked);
end;

{ an add-in expert is never executed (Delphi 7) }
procedure TSdExpertWizard.Execute;
begin
  if (FExpert = nil) or (FStyle = esAddIn) then Exit;
  Inc(LegacyCommandDepth);
  try
    try
      FExpert.Execute;
    except
      on Exception do raise;
    else
      raise LegacyOwnException;
    end;
  finally
    Dec(LegacyCommandDepth);
  end;
end;

function TSdExpertWizard.ExpertStyle: TExpertStyle;
begin
  Result := FStyle;
end;

function TSdExpertWizard.ExpertModule: HMODULE;
begin
  Result := FModule;
end;

function WizardModule(const Wizard: IInterface): HMODULE;
var
  L: ISdLegacyExpert;
begin
  if Supports(Wizard, ISdLegacyExpert, L) then Result := L.ExpertModule
  else Result := InterfaceModule(Wizard);
end;

function IsDelphiBinModule(M: HMODULE): Boolean;
begin
  Result := (M <> 0) and SameText(ExtractFilePath(SysUtils.GetModuleName(M)), DelphiBin);
end;

function TSdExpertMenuWizard.GetMenuText: string;
begin
  Result := ExpertText(etMenuText);
end;

function TSdExpertRepositoryWizard.GetAuthor: string;
begin
  Result := ExpertText(etAuthor);
end;

function TSdExpertRepositoryWizard.GetComment: string;
begin
  Result := ExpertText(etComment);
end;

function TSdExpertRepositoryWizard.GetPage: string;
begin
  Result := ExpertText(etPage);
end;

{ an HICON (Delphi 1.0's experts gave a bitmap) }
function TSdExpertRepositoryWizard.GetGlyph: Cardinal;
begin
  Result := 0;
  if FExpert = nil then Exit;
  try
    Result := FExpert.GetGlyph;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

{ the registration of an expert (Delphi 7's AddExpert): a name, an ID no expert or wizard has
  (IOTAWizardServices.AddWizard checks both), its wizard by its style. Raises when refused. }
procedure RegisterExpert(Expert: TIExpert; Dll: Boolean);
var
  Name: string;
  Style: TExpertStyle;
  W: TSdExpertWizard;
  Ref: IOTAWizard;
  WS: IOTAWizardServices;
begin
  WS := WizardServices;
  if (Expert = nil) or (WS = nil) then Exit;
  try
    Name := Expert.GetName;
    Style := Expert.GetStyle;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
  if Name = '' then raise Exception.Create('Cannot register an unnamed Wizard');
  case Style of
    esStandard: W := TSdExpertMenuWizard.Create(Expert, Style, ObjectModule(Expert), Dll);
    esForm: W := TSdExpertFormWizard.Create(Expert, Style, ObjectModule(Expert), Dll);
    esProject: W := TSdExpertProjectWizard.Create(Expert, Style, ObjectModule(Expert), Dll);
  else
    W := TSdExpertWizard.Create(Expert, esAddIn, ObjectModule(Expert), Dll);
  end;
  Ref := W;
  W.FID := W.GetIDString;
  W.FIndex := WS.AddWizard(Ref);
  W.FRegistered := W.FIndex >= 0;
end;

{ RegisterLibraryExpert of a package (LibraryExpertProc): True always (Delphi 7's); a refused
  expert raises out of the package's Register, after it was logged }
function LegacyExpertHook(Expert: TIExpert): Boolean;
begin
  Result := True;
  try
    RegisterExpert(Expert, False);
  except
    OtaCaught('expert registration', False);
    raise;
  end;
end;

{ the register procedure of INITEXPERT0017: an expert of another version is logged and left out
  (True); a refused one logged, False }
function LegacyRegisterProc(Expert: TIExpert): Boolean;
var
  V: Integer;
  N: string;
begin
  Result := True;
  try
    if Expert = nil then
    begin
      Result := False;
      Exit;
    end;
    V := Expert.GetVersion;
    if V <> ValidExpertVersion then
    begin
      try
        N := Expert.GetName;
      except
        N := '';
      end;
      OtaLog('expert ' + CurrentDllName, Format('Wizard, %s is version %d while expecting version %d',
        [N, V, ValidExpertVersion]));
      Exit;
    end;
    RegisterExpert(Expert, True);
  except
    OtaCaught('expert ' + CurrentDllName, False);
    Result := False;
  end;
end;

function LegacyInitDll(Init: Pointer; const FileName: string; var Terminate: TWizardTerminateProc): Boolean;
var
  Term: TExpertTerminateProc;
begin
  Terminate := nil;
  Term := nil;
  CurrentDllName := FileName;
  try
    try
      Result := TExpertInitProc(Init)(ToolServices, LegacyRegisterProc, Term);
      if not Result then
        OtaLog('expert ' + FileName, Format('Unable to establish interface with Wizard, ''%s''', [FileName]));
    except
      OtaCaught('expert ' + FileName, False);
      Result := False;
    end;
  finally
    { also after a failure: its terminate procedure runs before the DLL is unloaded }
    Terminate := Term;
    CurrentDllName := '';
  end;
  if Result then Inc(DllCount);
end;

{ ---------------------------------------------------------------- TSdToolServices }

{ never destroyed by an expert: ToolServices lives as long as the IDE }
function TSdToolServices.AddRef: Longint;
begin
  Result := 2;
end;

function TSdToolServices.Release: Longint;
begin
  Result := 1;
end;

function TSdToolServices.CloseProject: Boolean;
begin
  Result := False;
  try
    Result := (OtaHost = nil) or (OtaHost.Project = nil) or OtaHost.CloseProject(False);
  except
    LegacyFailed('TIToolServices.CloseProject');
  end;
end;

{ '' a new application (File | New | Application); True when a project is open afterwards }
function TSdToolServices.OpenProject(const ProjName: string): Boolean;
begin
  Result := False;
  try
    if OtaHost = nil then Exit;
    if ProjName = '' then OtaHost.ExecuteAction('FileNewVclApplicationCommand')
    else OtaHost.OpenProject(ProjName, True);
    Result := OtaHost.Project <> nil;
  except
    LegacyFailed('TIToolServices.OpenProject');
  end;
end;

{ D7 Studio opens a project as a whole: as OpenProject }
function TSdToolServices.OpenProjectInfo(const ProjName: string): Boolean;
begin
  Result := OpenProject(ProjName);
end;

function TSdToolServices.SaveProject: Boolean;
var
  M: IOTAModule;
begin
  Result := False;
  try
    if (OtaHost = nil) or (OtaHost.Project = nil) then
    begin
      Result := True;
      Exit;
    end;
    M := OtaModules.ModuleIntf(OtaHost.Project.FileName);
    Result := (M <> nil) and M.Save(False, True);
  except
    LegacyFailed('TIToolServices.SaveProject');
  end;
end;

{ as IOTAActionServices.CloseFile (Delphi's both close the file's module, the user asked about unsaved
  changes; True when the file has no module); a form's file is its unit's }
function TSdToolServices.CloseFile(const FileName: string): Boolean;
var
  Name: string;
  A: IOTAActionServices;
begin
  Result := False;
  try
    Name := FileName;
    if SameText(ExtractFileExt(Name), '.dfm') then Name := ChangeFileExt(Name, '.pas');
    if Supports(BorlandIDEServices, IOTAActionServices, A) then Result := A.CloseFile(Name);
  except
    LegacyFailed('TIToolServices.CloseFile');
  end;
end;

{ saved when it is modified (an untitled one asks for its name) }
function TSdToolServices.SaveFile(const FileName: string): Boolean;
var
  P: TEditorPage;
begin
  Result := False;
  try
    if OtaHost = nil then Exit;
    P := OtaHost.FindPage(FileName);
    if P = nil then Exit;
    if P.FormOwner <> nil then P := P.FormOwner;
    Result := not P.Modified or OtaHost.SavePage(P, False);
  except
    LegacyFailed('TIToolServices.SaveFile');
  end;
end;

{ a form file opens its unit }
function TSdToolServices.OpenFile(const FileName: string): Boolean;
var
  Name: string;
  A: IOTAActionServices;
begin
  Result := False;
  try
    Name := FileName;
    if SameText(ExtractFileExt(Name), '.dfm') and FileExistsU(ChangeFileExt(Name, '.pas')) then
      Name := ChangeFileExt(Name, '.pas');
    if Supports(BorlandIDEServices, IOTAActionServices, A) then Result := A.OpenFile(Name);
  except
    LegacyFailed('TIToolServices.OpenFile');
  end;
end;

function TSdToolServices.ReloadFile(const FileName: string): Boolean;
var
  A: IOTAActionServices;
begin
  Result := False;
  try
    if Supports(BorlandIDEServices, IOTAActionServices, A) then Result := A.ReloadFile(FileName);
  except
    LegacyFailed('TIToolServices.ReloadFile');
  end;
end;

{ a dialog of a DLL that is not built with the VCL, modal to the IDE's windows }
function TSdToolServices.ModalDialogBox(Instance: THandle; TemplateName: PChar; WndParent: HWnd;
  DialogFunc: TFarProc; InitParam: LongInt): Integer;
var
  W: Pointer;
begin
  Result := -1;
  try
    W := DisableTaskWindows(0);
    try
      Result := DialogBoxParam(Instance, TemplateName, WndParent, DialogFunc, InitParam);
    finally
      EnableTaskWindows(W);
    end;
  except
    LegacyFailed('TIToolServices.ModalDialogBox');
  end;
end;

function TSdToolServices.CreateModule(const ModuleName: string; Source, Form: IStream;
  CreateFlags: TCreateModuleFlags): Boolean;
var
  M: TIModuleInterface;
begin
  M := CreateCppModule(ModuleName, '', '', '', nil, Source, Form, CreateFlags);
  Result := M <> nil;
  if M <> nil then M.Free;
end;

function TSdToolServices.CreateModuleEx(const ModuleName, FormName, AncestorClass, FileSystem: string;
  Source, Form: IStream; CreateFlags: TCreateModuleFlags): TIModuleInterface;
begin
  Result := CreateCppModule(ModuleName, FormName, AncestorClass, FileSystem, nil, Source, Form, CreateFlags);
end;

function TSdToolServices.GetParentHandle: HWND;
begin
  Result := Application.Handle;
end;

function TSdToolServices.GetProjectName: string;
begin
  Result := '';
  try
    if (OtaHost <> nil) and (OtaHost.Project <> nil) then Result := OtaHost.Project.FileName;
  except
    LegacyFailed('TIToolServices.GetProjectName');
  end;
end;

function TSdToolServices.GetUnitCount: Integer;
begin
  Result := ListedCount(ProjectFileList, 'TIToolServices.GetUnitCount');
end;

function TSdToolServices.GetUnitName(Index: Integer): string;
begin
  Result := ListedItem(ProjectFileList, Index, 'TIToolServices.GetUnitName');
end;

{ the project source first (its name as the unit's), then the further files: a unit with its
  name and form, the others with neither; EnumProc's False stops }
function TSdToolServices.EnumProjectUnits(EnumProc: TProjectEnumProc; Param: Pointer): Boolean;
var
  L: TStringList;
  I: Integer;
  UnitName, FormName: string;
begin
  Result := False;
  L := TStringList.Create;
  try
    try
      if not Assigned(EnumProc) or not ProjectFileList(L) then Exit;
      Result := True;
      for I := 0 to L.Count - 1 do
      begin
        ProjectEntry(L, I, UnitName, FormName);
        if not EnumProc(Param, L[I], UnitName, FormName) then Break;
      end;
    except
      LegacyFailed('TIToolServices.EnumProjectUnits');
    end;
  finally
    L.Free;
  end;
end;

function TSdToolServices.EnumProjectModules(EnumProc: TProjectEnumModuleProc; Param: Pointer): Boolean;
var
  L: TStringList;
  I: Integer;
  UnitName, FormName: string;
begin
  Result := False;
  L := TStringList.Create;
  try
    try
      if not Assigned(EnumProc) or not ProjectFileList(L) then Exit;
      Result := True;
      for I := 0 to L.Count - 1 do
      begin
        ProjectEntry(L, I, UnitName, FormName);
        if not EnumProc(Param, L[I], UnitName, FormName, '') then Break;
      end;
    except
      LegacyFailed('TIToolServices.EnumProjectModules');
    end;
  finally
    L.Free;
  end;
end;

function TSdToolServices.GetFormCount: Integer;
begin
  Result := ListedCount(FormFiles, 'TIToolServices.GetFormCount');
end;

function TSdToolServices.GetFormName(Index: Integer): string;
begin
  Result := ListedItem(FormFiles, Index, 'TIToolServices.GetFormName');
end;

{ the file the user works in: a unit shown as its form is its form file }
function TSdToolServices.GetCurrentFile: string;
var
  P: TEditorPage;
begin
  Result := '';
  try
    if OtaHost = nil then Exit;
    P := OtaHost.ActivePage;
    if P = nil then Exit;
    if (P.FormOwner = nil) and P.HasForm and P.DesignView then Result := ChangeFileExt(P.FileName, '.dfm')
    else Result := P.FileName;
  except
    LegacyFailed('TIToolServices.GetCurrentFile');
  end;
end;

function TSdToolServices.IsFileOpen(const FileName: string): Boolean;
begin
  Result := False;
  try
    if (OtaHost = nil) or (FileName = '') then Exit;
    Result := (OtaHost.FindPage(FileName) <> nil) or (OtaModules.Find(FileName, False) <> nil) or
      ((OtaHost.Project <> nil) and SameText(OtaHost.Project.FileName, FileName)) or
      ((OtaHost.ProjectGroup <> nil) and SameText(OtaHost.ProjectGroup.FileName, FileName));
  except
    LegacyFailed('TIToolServices.IsFileOpen');
  end;
end;

function TSdToolServices.GetNewModuleName(var UnitIdent, FileName: string): Boolean;
begin
  Result := False;
  try
    if OtaHost = nil then Exit;
    UnitIdent := OtaHost.UniqueUnitName('Unit');
    FileName := OtaHost.DefaultDir + UnitIdent + '.pas';
    Result := True;
  except
    LegacyFailed('TIToolServices.GetNewModuleName');
  end;
end;

function TSdToolServices.GetModuleCount: Integer;
var
  P: IOTAPackageServices;
begin
  Result := 0;
  try
    if Supports(BorlandIDEServices, IOTAPackageServices, P) then Result := P.PackageCount;
  except
    LegacyFailed('TIToolServices.GetModuleCount');
  end;
end;

{ the loaded design packages (IOTAPackageServices' list): Delphi 7 names them by their description }
function TSdToolServices.GetModuleName(Index: Integer): string;
var
  E: TPackageEntry;
begin
  Result := '';
  try
    E := OtaPackageEntry(Index);
    if E = nil then Exit;
    Result := E.Description;
    if Result = '' then Result := ChangeFileExt(ExtractFileName(E.FileName), '');
  except
    LegacyFailed('TIToolServices.GetModuleName');
  end;
end;

function TSdToolServices.GetComponentCount(ModIndex: Integer): Integer;
var
  P: IOTAPackageServices;
begin
  Result := 0;
  try
    if Supports(BorlandIDEServices, IOTAPackageServices, P) then Result := P.ComponentCount[ModIndex];
  except
    LegacyFailed('TIToolServices.GetComponentCount');
  end;
end;

function TSdToolServices.GetComponentName(ModIndex, CompIndex: Integer): string;
var
  P: IOTAPackageServices;
begin
  Result := '';
  try
    if Supports(BorlandIDEServices, IOTAPackageServices, P) then Result := P.ComponentNames[ModIndex, CompIndex];
  except
    LegacyFailed('TIToolServices.GetComponentName');
  end;
end;

function TSdToolServices.RegisterFileSystem(AVirtualFileSystem: TIVirtualFileSystem): Boolean;
begin
  Result := False;
  try
    Result := LegacyRegisterFileSystem(AVirtualFileSystem);
  except
    LegacyFailed('TIToolServices.RegisterFileSystem');
  end;
end;

function TSdToolServices.UnRegisterFileSystem(const Ident: string): Boolean;
begin
  Result := False;
  try
    Result := LegacyUnregisterFileSystem(Ident);
  except
    LegacyFailed('TIToolServices.UnRegisterFileSystem');
  end;
end;

function TSdToolServices.GetFileSystem(const Ident: string): TIVirtualFileSystem;
begin
  Result := nil;
  try
    Result := LegacyGetFileSystem(Ident);
  except
    LegacyFailed('TIToolServices.GetFileSystem');
  end;
end;

function TSdToolServices.GetModuleInterface(const FileName: string): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyModuleInterface(FileName);
  except
    LegacyFailed('TIToolServices.GetModuleInterface');
  end;
end;

function TSdToolServices.GetFormModuleInterface(const FormName: string): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyFormModuleInterface(FormName);
  except
    LegacyFailed('TIToolServices.GetFormModuleInterface');
  end;
end;

{ a new object each call: the caller frees it }
function TSdToolServices.GetMainMenu: TIMainMenuIntf;
begin
  Result := nil;
  try
    if (OtaHost <> nil) and (OtaHost.MainMenu <> nil) then Result := TSdMainMenuIntf.Create(OtaHost.MainMenu);
  except
    LegacyFailed('TIToolServices.GetMainMenu');
  end;
end;

{ the file notifiers, each once (False: it was there) }
function TSdToolServices.AddNotifier(AddInNotifier: TIAddInNotifier): Boolean;
begin
  Result := (AddInNotifier <> nil) and (FileNotifiers.IndexOf(AddInNotifier) < 0);
  if Result then FileNotifiers.Add(AddInNotifier);
end;

{ ... and the compile's }
function TSdToolServices.AddNotifierEx(AddInNotifier: TIAddInNotifier): Boolean;
begin
  Result := AddNotifier(AddInNotifier);
  if (AddInNotifier <> nil) and (EventNotifiers.IndexOf(AddInNotifier) < 0) then
  begin
    EventNotifiers.Add(AddInNotifier);
    Result := True;
  end;
end;

{ from both lists; True when it was a file notifier }
function TSdToolServices.RemoveNotifier(AddInNotifier: TIAddInNotifier): Boolean;
begin
  Result := FileNotifiers.Remove(AddInNotifier) >= 0;
  EventNotifiers.Remove(AddInNotifier);
end;

{ the strings of an expert written in another language than Pascal: a long string of this heap
  the caller owns (one reference) }
function TSdToolServices.NewPascalString(Str: PChar): Pointer;
var
  S: string;
begin
  Result := nil;
  if (Str = nil) or (Str^ = #0) then Exit;
  S := Str;
  Result := Pointer(S);
  Pointer(S) := nil;
end;

procedure TSdToolServices.FreePascalString(var Str: Pointer);
var
  S: string;
begin
  { the caller's reference taken over: let go of at the end of this procedure }
  Pointer(S) := Str;
  Str := nil;
end;

procedure TSdToolServices.ReferencePascalString(var Str: Pointer);
var
  S: string;
begin
  S := PString(@Str)^;
  Pointer(S) := nil;
end;

procedure TSdToolServices.AssignPascalString(var Dest, Src: Pointer);
begin
  PString(@Dest)^ := PString(@Src)^;
end;

{ on purpose: the stack unwinds through the expert's code }
procedure TSdToolServices.RaiseException(const Message: string);
begin
  raise Exception.Create(Message);
end;

{ D7 Studio's own key (HKEY_CURRENT_USER), never Delphi's }
function TSdToolServices.GetBaseRegistryKey: string;
begin
  Result := '\' + SettingsRegKey;
end;

{ the bounds of a new form and of a new data module (custom module) }
function TSdToolServices.GetFormBounds(BoundsType: TBoundsType): TRect;
begin
  if BoundsType = btCustomModule then Result := Rect(192, 107, 192 + 215, 107 + 150)
  else Result := Rect(192, 107, 192 + 696, 107 + 480);
end;

function TSdToolServices.ProjectCreate(ProjectCreator: TIProjectCreator;
  CreateFlags: TCreateProjectFlags): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyProjectCreate(ProjectCreator, CreateFlags, False);
  except
    LegacyFailed('TIToolServices.ProjectCreate');
  end;
end;

function TSdToolServices.ProjectCreateEx(ProjectCreator: TIProjectCreatorEx;
  CreateFlags: TCreateProjectFlags): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyProjectCreate(ProjectCreator, CreateFlags, True);
  except
    LegacyFailed('TIToolServices.ProjectCreateEx');
  end;
end;

function TSdToolServices.ModuleCreate(ModuleCreator: TIModuleCreator;
  CreateFlags: TCreateModuleFlags): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyModuleCreate(ModuleCreator, CreateFlags);
  except
    LegacyFailed('TIToolServices.ModuleCreate');
  end;
end;

{ C++Builder's header (GetIntfName, NewIntfSource) has no place in Delphi: as ModuleCreate }
function TSdToolServices.ModuleCreateEx(ModuleCreator: TIModuleCreatorEx;
  CreateFlags: TCreateModuleFlags): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyModuleCreate(ModuleCreator, CreateFlags);
  except
    LegacyFailed('TIToolServices.ModuleCreateEx');
  end;
end;

function TSdToolServices.GetNewModuleAndClassName(const Prefix: string; var UnitIdent,
  ClassName, FileName: string): Boolean;
var
  MS: IOTAModuleServices;
begin
  Result := False;
  try
    if not Supports(BorlandIDEServices, IOTAModuleServices, MS) or (OtaHost = nil) then Exit;
    MS.GetNewModuleAndClassName(Prefix, UnitIdent, ClassName, FileName);
    Result := True;
  except
    LegacyFailed('TIToolServices.GetNewModuleAndClassName');
  end;
end;

{ HdrSource (C++Builder's header) is not used }
function TSdToolServices.CreateCppModule(const ModuleName, FormName, AncestorClass,
  FileSystem: string; HdrSource, Source, Form: IStream;
  CreateFlags: TCreateModuleFlags): TIModuleInterface;
begin
  Result := nil;
  try
    Result := LegacyCreateModule(ModuleName, FormName, AncestorClass, FileSystem, Source, Form, CreateFlags);
  except
    LegacyFailed('TIToolServices.CreateCppModule');
  end;
end;

function TSdToolServices.GetVcsCount: Integer;
begin
  Result := ListedCount(VcsFiles, 'TIToolServices.GetVcsCount');
end;

procedure TSdToolServices.GetVcsList(List: TStringList);
begin
  try
    if List <> nil then VcsFiles(List);
  except
    LegacyFailed('TIToolServices.GetVcsList');
  end;
end;

function TSdToolServices.GetVcsName(Index: Integer): string;
begin
  Result := ListedItem(VcsFiles, Index, 'TIToolServices.GetVcsName');
end;

{ ---------------------------------------------------------------- menus }

procedure TSdMenuWatch.Notification(AComponent: TComponent; Operation: TOperation);
var
  I: Integer;
begin
  inherited;
  if Operation <> opRemove then Exit;
  for I := MenuIntfs.Count - 1 downto 0 do
    if (I < MenuIntfs.Count) and (TSdMenuItemIntf(MenuIntfs[I]).FItem = AComponent) then
      TSdMenuItemIntf(MenuIntfs[I]).ItemGone;
end;

{ the wrapper of a menu item: an item an expert inserted has its own (a reference added) }
function MenuItemIntf(Item: TMenuItem): TIMenuItemIntf;
var
  I: Integer;
begin
  Result := nil;
  if Item = nil then Exit;
  for I := 0 to MenuIntfs.Count - 1 do
    if TSdMenuItemIntf(MenuIntfs[I]).FOwn and (TSdMenuItemIntf(MenuIntfs[I]).FItem = Item) then
    begin
      Result := TSdMenuItemIntf(MenuIntfs[I]);
      Result.AddRef;
      Exit;
    end;
  Result := TSdMenuItemIntf.Create(Item, False);
end;

function FindItemByName(Items: TMenuItem; const Name: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  if (Items = nil) or (Name = '') then Exit;
  for I := 0 to Items.Count - 1 do
  begin
    if CompareText(Items[I].Name, Name) = 0 then Result := Items[I]
    else Result := FindItemByName(Items[I], Name);
    if Result <> nil then Exit;
  end;
end;

constructor TSdMainMenuIntf.Create(AMenu: TMainMenu);
begin
  inherited Create;
  FMenu := AMenu;
end;

function TSdMainMenuIntf.GetMenuItems: TIMenuItemIntf;
begin
  Result := nil;
  try
    Result := MenuItemIntf(FMenu.Items);
  except
    LegacyFailed('TIMainMenuIntf.GetMenuItems');
  end;
end;

function TSdMainMenuIntf.FindMenuItem(const Name: string): TIMenuItemIntf;
begin
  Result := nil;
  try
    Result := MenuItemIntf(FindItemByName(FMenu.Items, Name));
  except
    LegacyFailed('TIMainMenuIntf.FindMenuItem');
  end;
end;

constructor TSdMenuItemIntf.Create(AItem: TMenuItem; AOwn: Boolean);
begin
  inherited Create;
  FItem := AItem;
  FOwn := AOwn;
  MenuIntfs.Add(Self);
  if FItem <> nil then FItem.FreeNotification(MenuWatch);
end;

destructor TSdMenuItemIntf.Destroy;
begin
  MenuIntfs.Remove(Self);
  if FOwn then FreeItem;
  inherited;
end;

{ the item was freed by the IDE: its action goes too }
procedure TSdMenuItemIntf.ItemGone;
begin
  FItem := nil;
  if FAction <> nil then
  begin
    FAction.FIntf := nil;
    FreeAndNil(FAction);
  end;
end;

function TSdMenuItemIntf.CanModify: Boolean;
begin
  Result := FOwn and (FItem <> nil);
end;

procedure TSdMenuItemIntf.FreeItem;
var
  It: TMenuItem;
  A: TSdLegacyMenuAction;
begin
  It := FItem;
  A := FAction;
  FItem := nil;
  FAction := nil;
  if A <> nil then A.FIntf := nil;
  It.Free;
  A.Free;
end;

function TSdMenuItemIntf.DestroyMenuItem: Boolean;
begin
  Result := CanModify;
  if Result then FreeItem;
end;

function TSdMenuItemIntf.GetIndex: Integer;
begin
  Result := -1;
  if (FItem <> nil) and (FItem.Parent <> nil) then Result := FItem.MenuIndex;
end;

function TSdMenuItemIntf.GetItemCount: Integer;
begin
  if FItem = nil then Result := -1 else Result := FItem.Count;
end;

function TSdMenuItemIntf.GetItem(Index: Integer): TIMenuItemIntf;
begin
  Result := nil;
  try
    if (FItem <> nil) and (Index >= 0) and (Index < FItem.Count) then Result := MenuItemIntf(FItem[Index]);
  except
    LegacyFailed('TIMenuItemIntf.GetItem');
  end;
end;

function TSdMenuItemIntf.GetName: string;
begin
  if FItem = nil then Result := '' else Result := FItem.Name;
end;

{ the main menu's root has no parent }
function TSdMenuItemIntf.GetParent: TIMenuItemIntf;
begin
  Result := nil;
  try
    if FItem <> nil then Result := MenuItemIntf(FItem.Parent);
  except
    LegacyFailed('TIMenuItemIntf.GetParent');
  end;
end;

function TSdMenuItemIntf.GetCaption: string;
begin
  if FItem = nil then Result := '' else Result := FItem.Caption;
end;

function TSdMenuItemIntf.SetCaption(const Caption: string): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if FAction <> nil then FAction.Caption := Caption else FItem.Caption := Caption;
end;

function TSdMenuItemIntf.GetShortCut: Integer;
begin
  if FItem = nil then Result := 0 else Result := FItem.ShortCut;
end;

function TSdMenuItemIntf.SetShortCut(ShortCut: Integer): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if FAction <> nil then FAction.ShortCut := ShortCut else FItem.ShortCut := ShortCut;
end;

function TSdMenuItemIntf.GetFlags: TIMenuFlags;
begin
  if FItem = nil then
  begin
    Result := [mfInvalid];
    Exit;
  end;
  Result := [];
  if FItem.Visible then Include(Result, mfVisible);
  if FItem.Enabled then Include(Result, mfEnabled);
  if FItem.Checked then Include(Result, mfChecked);
  if FItem.Break = mbBreak then Include(Result, mfBreak);
  if FItem.Break = mbBarBreak then Include(Result, mfBarBreak);
  if FItem.RadioItem then Include(Result, mfRadioItem);
end;

function TSdMenuItemIntf.SetFlags(Mask, Flags: TIMenuFlags): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if mfEnabled in Mask then
    if FAction <> nil then FAction.Enabled := mfEnabled in Flags else FItem.Enabled := mfEnabled in Flags;
  if mfVisible in Mask then
    if FAction <> nil then FAction.Visible := mfVisible in Flags else FItem.Visible := mfVisible in Flags;
  if mfChecked in Mask then
    if FAction <> nil then FAction.Checked := mfChecked in Flags else FItem.Checked := mfChecked in Flags;
  if mfRadioItem in Mask then FItem.RadioItem := mfRadioItem in Flags;
  if (mfBreak in Mask) or (mfBarBreak in Mask) then
    if mfBarBreak in Flags then FItem.Break := mbBarBreak
    else if mfBreak in Flags then FItem.Break := mbBreak
    else FItem.Break := mbNone;
end;

function TSdMenuItemIntf.GetGroupIndex: Integer;
begin
  if FItem = nil then Result := 0 else Result := FItem.GroupIndex;
end;

function TSdMenuItemIntf.SetGroupIndex(GroupIndex: Integer): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if FAction <> nil then FAction.GroupIndex := GroupIndex else FItem.GroupIndex := GroupIndex;
end;

function TSdMenuItemIntf.GetHint: string;
begin
  if FItem = nil then Result := '' else Result := FItem.Hint;
end;

function TSdMenuItemIntf.SetHint(Hint: string): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if FAction <> nil then FAction.Hint := Hint else FItem.Hint := Hint;
end;

function TSdMenuItemIntf.getContext: Integer;
begin
  if FItem = nil then Result := 0 else Result := FItem.HelpContext;
end;

function TSdMenuItemIntf.setContext(Context: Integer): Boolean;
begin
  Result := CanModify;
  if not Result then Exit;
  if FAction <> nil then FAction.HelpContext := Context else FItem.HelpContext := Context;
end;

function TSdMenuItemIntf.GetOnClick: TIMenuClickEvent;
begin
  Result := FOnClick;
end;

function TSdMenuItemIntf.SetOnClick(Click: TIMenuClickEvent): Boolean;
begin
  Result := CanModify;
  if Result then FOnClick := Click;
end;

{ Delphi 7's InsertItem: a menu item of the main form (its name, else none: a name in use or not
  valid refuses the item), its command an action of the wizards' list; a line ("-") is no
  command. Index out of range: the end. }
function TSdMenuItemIntf.InsertItem(Index: Integer; Caption, Name, Hint: string;
  ShortCut, Context, GroupIndex: Integer; Flags: TIMenuFlags;
  EventHandler: TIMenuClickEvent): TIMenuItemIntf;
var
  It: TMenuItem;
  A: TSdLegacyMenuAction;
  W: TSdMenuItemIntf;
begin
  Result := nil;
  try
    if (FItem = nil) or (OtaHost = nil) or (OtaHost.MainForm = nil) then Exit;
    It := TMenuItem.Create(OtaHost.MainForm);
    A := nil;
    try
      if Name <> '' then It.Name := Name;
      if Caption = cLineCaption then It.Caption := cLineCaption
      else
      begin
        A := TSdLegacyMenuAction.Create(OtaHost.WizardActions);
        A.ActionList := OtaHost.WizardActions;
        A.OnExecute := A.DoExecute;
        A.Caption := Caption;
        A.Hint := Hint;
        A.ShortCut := ShortCut;
        A.HelpContext := Context;
        A.GroupIndex := GroupIndex;
        A.Checked := mfChecked in Flags;
        A.Enabled := mfEnabled in Flags;
        A.Visible := mfVisible in Flags;
        It.Action := A;
      end;
      It.RadioItem := mfRadioItem in Flags;
      It.GroupIndex := GroupIndex;
      if mfBarBreak in Flags then It.Break := mbBarBreak
      else if mfBreak in Flags then It.Break := mbBreak;
      if (Index < 0) or (Index > FItem.Count) then Index := FItem.Count;
      FItem.Insert(Index, It);
    except
      A.Free;
      It.Free;
      raise;
    end;
    W := TSdMenuItemIntf.Create(It, True);
    W.FAction := A;
    W.FOnClick := EventHandler;
    if A <> nil then A.FIntf := W;
    It.Tag := Integer(W);
    Result := W;
  except
    LegacyFailed('TIMenuItemIntf.InsertItem');
  end;
end;

{ the expert's OnClick with the item's interface (the handler is always there: the VCL never
  disables the action for want of one) }
procedure TSdLegacyMenuAction.DoExecute(Sender: TObject);
var
  W: TSdMenuItemIntf;
begin
  W := FIntf;
  if (W = nil) or not Assigned(W.FOnClick) then Exit;
  W.AddRef;
  Inc(LegacyCommandDepth);
  try
    try
      W.FOnClick(W);
    except
      OtaCaught('TIMenuItemIntf.OnClick', True);
    end;
  finally
    Dec(LegacyCommandDepth);
    W.Release;
  end;
end;

{ ---------------------------------------------------------------- add-in notifiers }

function IsProjectName(const FileName: string): Boolean;
begin
  Result := IsProjectFile(FileName) or IsProjectGroupFile(FileName);
end;

type
  { the arguments of a call of the add-in notifiers (LegacyEach's Data) and whether one cancelled }
  PFileCall = ^TFileCall;
  TFileCall = record
    Code: TFileNotification;
    FileName: string;
    Cancelled: Boolean;
  end;

  PCompileCall = ^TCompileCall;
  TCompileCall = record
    Before, Succeeded: Boolean;
    Cancelled: Boolean;
  end;

{ a notifier's Cancel counts also when it raised after it set it }
procedure FileNotifyOne(Obj: TObject; Data: Pointer);
var
  Cancel: Boolean;
begin
  Cancel := False;
  with PFileCall(Data)^ do
    try
      TIAddInNotifier(Obj).FileNotification(Code, FileName, Cancel);
    finally
      if Cancel then Cancelled := True;
    end;
end;

{ the file notifiers in the order registered (one removed meanwhile is not called), each guarded }
function NotifyFile(Code: TFileNotification; const FileName: string): Boolean;
var
  C: TFileCall;
begin
  C.Code := Code;
  C.FileName := FileName;
  C.Cancelled := False;
  LegacyEach(FileNotifiers, FileNotifyOne, @C, False, 'TIAddInNotifier.FileNotification');
  Result := not C.Cancelled;
end;

function LegacyFileNotification(Code: TOTAFileNotification; const FileName: string): Boolean;
var
  Prj: Boolean;
begin
  Result := True;
  Prj := IsProjectName(FileName);
  case Code of
    ofnFileOpening:
      if Prj then Result := NotifyFile(fnProjectOpening, FileName) else Result := NotifyFile(fnFileOpening, FileName);
    ofnFileOpened:
      if Prj then NotifyFile(fnProjectOpened, FileName) else NotifyFile(fnFileOpened, FileName);
    ofnFileClosing:
      if Prj then Result := NotifyFile(fnProjectClosing, FileName) else Result := NotifyFile(fnFileClosing, FileName);
    ofnDefaultDesktopLoad: NotifyFile(fnDefaultDesktopLoad, FileName);
    ofnDefaultDesktopSave: NotifyFile(fnDefaultDesktopSave, FileName);
    ofnProjectDesktopLoad: NotifyFile(fnProjectDesktopLoad, FileName);
    ofnProjectDesktopSave: NotifyFile(fnprojectDesktopSave, FileName);
    ofnPackageInstalled: NotifyFile(fnPackageInstalled, FileName);
    ofnPackageUninstalled: NotifyFile(fnPackageUninstalled, FileName);
    ofnActiveProjectChanged: LegacyProjectChanged;
  end;
end;

procedure LegacyProjectFile(const FileName: string; Added: Boolean);
begin
  if Added then NotifyFile(fnAddedToProject, FileName) else NotifyFile(fnRemovedFromProject, FileName);
end;

{ enBeforeCompile's Cancel counts when the notifier returned; enAfterCompile's is Succeeded }
procedure CompileNotifyOne(Obj: TObject; Data: Pointer);
var
  Cancel: Boolean;
begin
  with PCompileCall(Data)^ do
    if Before then
    begin
      Cancel := False;
      TIAddInNotifier(Obj).EventNotification(enBeforeCompile, Cancel);
      if Cancel then Cancelled := True;
    end
    else
    begin
      Cancel := Succeeded;
      TIAddInNotifier(Obj).EventNotification(enAfterCompile, Cancel);
    end;
end;

{ AddNotifierEx's notifiers, in the order registered }
function LegacyCompile(Before, Succeeded: Boolean): Boolean;
var
  C: TCompileCall;
begin
  C.Before := Before;
  C.Succeeded := Succeeded;
  C.Cancelled := False;
  LegacyEach(EventNotifiers, CompileNotifyOne, @C, False, 'TIAddInNotifier.EventNotification');
  Result := not C.Cancelled;
end;

{ ---------------------------------------------------------------- version control }

constructor TSdVcsManager.Create;
begin
  inherited Create;
  Actions := TList.Create;
  Tools := TSdToolServices.Create;
end;

destructor TSdVcsManager.Destroy;
begin
  FreeMenu;
  Actions.Free;
  if Client <> nil then
    try
      Client.Release;
    except
      OtaCaught('TIVCSClient released', False);
    end;
  Client := nil;
  if Module <> 0 then FreeLibrary(Module);
  { not freed: the DLL may have kept it (Delphi's TVCSInterface lived until its end) }
  Tools := nil;
  inherited;
end;

{ a top-level menu before Tools (Delphi 7's index 8): its verbs, an empty one a line }
procedure TSdVcsManager.MakeMenu;
var
  MenuName, Verb: string;
  I, N, At: Integer;
  Items, Before, It: TMenuItem;
  A: TSdVcsVerbAction;
begin
  if (Client = nil) or (OtaHost = nil) or (OtaHost.MainMenu = nil) then Exit;
  try
    MenuName := Client.GetMenuName;
    if MenuName = '' then Exit;
    N := Client.GetVerbCount;
  except
    OtaCaught('version control ' + FileName, False);
    Exit;
  end;
  Items := OtaHost.MainMenu.Items;
  Before := FindItemByName(Items, 'ToolsMenu');
  if (Before = nil) or (Before.Parent <> Items) then Before := FindItemByName(Items, 'HelpMenu');
  if (Before <> nil) and (Before.Parent = Items) then At := Before.MenuIndex else At := Items.Count;
  Menu := TMenuItem.Create(OtaHost.MainForm);
  Menu.Caption := MenuName;
  Items.Insert(At, Menu);
  for I := 0 to N - 1 do
  begin
    try
      Verb := Client.GetVerb(I);
    except
      OtaCaught('version control ' + FileName, False);
      Verb := '';
    end;
    It := TMenuItem.Create(OtaHost.MainForm);
    if Verb = '' then It.Caption := cLineCaption
    else
    begin
      A := TSdVcsVerbAction.Create(OtaHost.WizardActions);
      A.ActionList := OtaHost.WizardActions;
      A.FVerb := I;
      A.Caption := Verb;
      A.OnExecute := A.DoExecute;
      A.OnUpdate := A.DoUpdate;
      Actions.Add(A);
      It.Action := A;
    end;
    Menu.Add(It);
  end;
end;

procedure TSdVcsManager.FreeMenu;
var
  I: Integer;
begin
  FreeAndNil(Menu);
  for I := 0 to Actions.Count - 1 do TObject(Actions[I]).Free;
  Actions.Clear;
end;

procedure TSdVcsVerbAction.DoExecute(Sender: TObject);
begin
  if (Vcs = nil) or (Vcs.Client = nil) then Exit;
  Inc(LegacyCommandDepth);
  try
    try
      Vcs.Client.ExecuteVerb(FVerb);
    except
      OtaCaught('TIVCSClient.ExecuteVerb', True);
    end;
  finally
    Dec(LegacyCommandDepth);
  end;
end;

{ the verb's state and caption whenever its menu drops down (Delphi 7's UpdateMenuItems) }
procedure TSdVcsVerbAction.DoUpdate(Sender: TObject);
var
  S: Word;
  V: string;
begin
  if (Vcs = nil) or (Vcs.Client = nil) then Exit;
  try
    S := Vcs.Client.GetVerbState(FVerb);
    V := Vcs.Client.GetVerb(FVerb);
  except
    S := 0;
    V := Caption;
  end;
  Enabled := S and vsEnabled <> 0;
  Checked := S and vsChecked <> 0;
  if V <> '' then Caption := V;
end;

{ the version control manager's DLL: D7 Studio's registry key, Version Control | VCSManager, or
  [Version Control] VCSManager= of the settings }
function VcsFileName: string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    try
      if Reg.OpenKeyReadOnly(SettingsRegKey + '\' + VcsSection) then
      begin
        if Reg.ValueExists(VcsValue) then Result := Reg.ReadString(VcsValue);
        Reg.CloseKey;
      end;
    except
    end;
  finally
    Reg.Free;
  end;
  if (Result = '') and (Settings <> nil) then Result := Settings.ReadString(VcsSection, VcsValue, '');
  Result := ExpandDelphiMacros(Result);
end;

procedure LoadVcs;
var
  F: string;
  M: HMODULE;
  Init: TVCSManagerInitProc;
  X: TSdVcsManager;
begin
  F := VcsFileName;
  if F = '' then Exit;
  if not FileExists(F) then
  begin
    OtaLog('version control', Format('Unable to locate Version Manager (%s).', [F]));
    Exit;
  end;
  M := SafeLoadLibrary(F);
  if M = 0 then
  begin
    OtaLog('version control', Format('Unable to locate Version Manager (%s).', [F]) + ' ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  InstallUtf8ShimsForModules;
  @Init := GetProcAddress(M, VcsEntryPoint);
  if not Assigned(Init) then
  begin
    OtaLog('version control ' + F, 'Invalid VCS Manager version.');
    FreeLibrary(M);
    Exit;
  end;
  X := TSdVcsManager.Create;
  X.FileName := F;
  X.Module := M;
  try
    X.Client := Init(X.Tools);
    if X.Client <> nil then X.ID := X.Client.GetIDString;
  except
    OtaCaught('version control ' + F, False);
    X.Client := nil;
  end;
  if X.Client = nil then
  begin
    OtaLog('version control ' + F, 'Unable to establish interface with VCS Manager.');
    X.Free;
    Exit;
  end;
  Vcs := X;
  Vcs.MakeMenu;
end;

procedure LegacyHostReady;
begin
  try
    LoadVcs;
  except
    OtaCaught('version control', False);
  end;
end;

procedure LegacyProjectChanged;
begin
  if (Vcs = nil) or (Vcs.Client = nil) then Exit;
  try
    Vcs.Client.ProjectChange;
  except
    OtaCaught('TIVCSClient.ProjectChange', False);
  end;
end;

procedure LegacyShutdown;
begin
  try
    FreeAndNil(Vcs);
  except
    OtaCaught('version control at exit', False);
  end;
end;

{ ---------------------------------------------------------------- packages and DLLs }

procedure LegacyDropModule(Module: HMODULE);
var
  I, K: Integer;
  W: TSdExpertWizard;
  WS: IOTAWizardServices;
  M: TSdMenuItemIntf;
begin
  if Module = 0 then Exit;
  { the experts' wizards (the wizard services do not find them by their code: it is the IDE's).
    A wizard taken out keeps no index: the services give a freed index to the next wizard, and the
    wizard may live on while something holds it (it may be freed by the removal, too). }
  WS := WizardServices;
  for I := Wizards.Count - 1 downto 0 do
    if I < Wizards.Count then
    begin
      W := TSdExpertWizard(Wizards[I]);
      if (W.FModule = Module) and W.FRegistered and (W.FIndex >= 0) and (WS <> nil) then
      begin
        K := W.FIndex;
        W.FIndex := -1;
        try
          WS.RemoveWizard(K);
        except
          OtaCaught('expert removed', False);
        end;
      end;
    end;
  for I := FileNotifiers.Count - 1 downto 0 do
    if ObjectModule(TObject(FileNotifiers[I])) = Module then FileNotifiers.Delete(I);
  for I := EventNotifiers.Count - 1 downto 0 do
    if ObjectModule(TObject(EventNotifiers[I])) = Module then EventNotifiers.Delete(I);
  { the menu items it inserted and did not free stay; their handlers go with its code }
  for I := 0 to MenuIntfs.Count - 1 do
  begin
    M := TSdMenuItemIntf(MenuIntfs[I]);
    if Assigned(M.FOnClick) and (FindHInstance(TMethod(M.FOnClick).Code) = Module) then M.FOnClick := nil;
  end;
  LegacyModulesDropModule(Module);
end;

procedure LegacyAddModules(List: TList);

  procedure Add(M: HMODULE);
  begin
    if (M = 0) or (List.IndexOf(Pointer(M)) >= 0) then Exit;
    if IsDelphiBinModule(M) then Exit;
    List.Add(Pointer(M));
  end;

var
  I: Integer;
begin
  for I := 0 to Wizards.Count - 1 do
    if TSdExpertWizard(Wizards[I]).FRegistered and not TSdExpertWizard(Wizards[I]).FDll then
      Add(TSdExpertWizard(Wizards[I]).FModule);
  for I := 0 to FileNotifiers.Count - 1 do Add(ObjectModule(TObject(FileNotifiers[I])));
  for I := 0 to EventNotifiers.Count - 1 do Add(ObjectModule(TObject(EventNotifiers[I])));
end;

{ ---------------------------------------------------------------- the state dump }

const
  StyleNames: array[TExpertStyle] of string = ('standard', 'form', 'project', 'addin');

function LegacyDebugText: string;
var
  I, Own: Integer;
  N: array[TExpertStyle] of Integer;
  S: TExpertStyle;
  V, MM: string;
begin
  for S := Low(S) to High(S) do N[S] := 0;
  for I := 0 to Wizards.Count - 1 do
    if TSdExpertWizard(Wizards[I]).FRegistered then Inc(N[TSdExpertWizard(Wizards[I]).FStyle]);
  Own := 0;
  for I := 0 to MenuIntfs.Count - 1 do
    if TSdMenuItemIntf(MenuIntfs[I]).CanModify then Inc(Own);
  if (Vcs <> nil) and (Vcs.Client <> nil) then
  begin
    V := Vcs.ID;
    if Vcs.Menu <> nil then V := V + ':' + StringReplace(StripHotkey(Vcs.Menu.Caption), ' ', '_', [rfReplaceAll]) +
      ':' + IntToStr(Vcs.Menu.Count);
  end
  else
    V := '-';
  { the memory manager: another module's (ShareMem: borlndmm.dll's) or System's own, and the bytes
    System's own holds - what was allocated before ShareMem's initialisation set the other one: 0 }
  if IsMemoryManagerSet then MM := 'shared' else MM := 'own';
  Result := Format('experts=%d/%d/%d/%d menus=%d notifiers=%d/%d modnotifiers=%d filesystems=%d dlls=%d ' +
    'vcs=%s mm=%s:%d', [N[esStandard], N[esForm], N[esProject], N[esAddIn], Own, FileNotifiers.Count,
    EventNotifiers.Count, LegacyModuleNotifierCount, LegacyFileSystemCount, DllCount, V, MM,
    System.GetHeapStatus.TotalAllocated]);
end;

{ the experts: ID|style|module|menu caption or page }
procedure LegacyDebugLines(L: TStrings);
var
  I: Integer;
  W: TSdExpertWizard;
  Extra: string;
  MW: IOTAMenuWizard;
  RW: IOTARepositoryWizard;
  M: TSdMenuItemIntf;
begin
  L.Add('[legacy]');
  for I := 0 to Wizards.Count - 1 do
  begin
    W := TSdExpertWizard(Wizards[I]);
    if not W.FRegistered then Continue;
    Extra := '';
    try
      if Supports(TObject(W), IOTAMenuWizard, MW) then Extra := MW.GetMenuText
      else if Supports(TObject(W), IOTARepositoryWizard, RW) then
      begin
        Extra := RW.GetPage;
        if Extra = '' then Extra := 'Wizards';
        Extra := Extra + ':' + RW.GetName;
      end;
    except
      Extra := '?';
    end;
    L.Add(Format('expert=%s|%s|%s|%s', [W.FID, StyleNames[W.FStyle],
      ExtractFileName(SysUtils.GetModuleName(W.FModule)), Extra]));
  end;
  for I := 0 to MenuIntfs.Count - 1 do
  begin
    M := TSdMenuItemIntf(MenuIntfs[I]);
    if M.CanModify then
      L.Add(Format('menuitem=%s|%s|%d', [M.FItem.Name, M.FItem.Caption, Ord(Assigned(M.FOnClick))]));
  end;
  if Vcs <> nil then L.Add('vcsfile=' + Vcs.FileName);
end;

initialization
  Wizards := TList.Create;
  FileNotifiers := TList.Create;
  EventNotifiers := TList.Create;
  MenuIntfs := TList.Create;
  MenuWatch := TSdMenuWatch.Create(nil);
  Services := TSdToolServices.Create;
  ToolServices := Services;
  OtaExpertHook := LegacyExpertHook;
end.
