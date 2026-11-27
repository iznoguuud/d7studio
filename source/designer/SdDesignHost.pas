{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesignHost;

{ D7 Studio - host for the Delphi design-time packages.

  Loads designide-based packages (dcl*.bpl) into the process, captures their component
  registrations (palette pages), keeps the list of IDesignNotification sinks, and provides the
  24 x 24 palette bitmaps stored in the packages. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, ActnList, DB,
  TypInfo, DesignIntf, DesignEditors, VCLEditors, ToolsAPI, ExptIntf, PicEdit, SdDesignEnv;

type
  TPaletteItem = class
  public
    ComponentClass: TComponentClass;
    Page: string;                      // the page it is on
    RegPage: string;                   // the page it was registered on
    Module: HMODULE;
    Hidden: Boolean;                   // taken off the palette (Environment Options | Palette)
    { a component template (Component | Create Component Template): its name, its components
      as .dfm text, its own icon (owned; nil: ComponentClass's) }
    Caption: string;
    Template: string;
    Bitmap: TBitmap;
    { Delphi 7's Frames tool: no component of a package - placing it inserts a frame of the
      project ("Select frame to insert"). ComponentClass is TFrame, Caption 'Frames', Bitmap
      Delphi 7's image of it (else the icon iiFrameTool) }
    IsFrames: Boolean;
    destructor Destroy; override;
    { its name in the palette's layout (Environment Options | Palette): the class name, 'Frames'
      for the Frames tool }
    function LayoutName: string;
  end;

  TPalettePage = class
  public
    Name: string;
    Items: TList;                      // of TPaletteItem
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

  TPackageEntry = class
  public
    FileName: string;
    Description: string;
    Module: HMODULE;
    Loaded: Boolean;
    Enabled: Boolean;                  // the user wants it loaded (the check box of the list)
    BuiltIn: Boolean;                  // part of the designer itself: not in the package list
    Group: Integer;                    // editor group of everything it registered
    Error: string;
    Deferred: Boolean;                 // an IDE expert waiting for the main window (LoadDeferredPackages)
  end;

  THostLogEvent = procedure(const Text: string) of object;
  { a design-time window (a form of a package that registered as a design notification) is
    being constructed (Appearing) or destroyed }
  TDesignWindowEvent = procedure(Form: TCustomForm; Appearing: Boolean) of object;

  TDesignHost = class
  private
    FPages: TList;
    FTemplates: TList;               // the component templates' items (not in FItems)
    FItems: TStringList;
    FPackages: TList;
    FBitmaps: TStringList;
    FNotifications: TInterfaceList;
    FCurModule: HMODULE;
    FDefaultBitmap: TBitmap;
    FInitialized: Boolean;
    FOnLog: THostLogEvent;
    FOnLoading: THostLogEvent;
    FOnPaletteChanged: TNotifyEvent;
    FOnDesignWindow: TDesignWindowEvent;
    FOnSyncDesignWindows: TNotifyEvent;
    FOnPackageUnloading: TNotifyEvent;
    FOnPackageUnloaded: TNotifyEvent;
    FDesigners: TInterfaceList;        // the open form designers
    FIdeReady: Boolean;                // the IDE's main window is there: experts load at once
    FCustomModules: TList;             // TCustomModuleEntry: RegisterCustomModule's classes
    function LoadEntry(E: TPackageEntry): Boolean;
    function UnloadEntry(E: TPackageEntry; var Error: string): Boolean;
    procedure SeedPackages(Names: TStrings);
    function GetPage(Index: Integer): TPalettePage;
    function GetPackage(Index: Integer): TPackageEntry;
    function FindPage(const AName: string): TPalettePage;
    function NeedPage(const AName: string): TPalettePage;
    procedure RemovePaletteItem(Item: TPaletteItem);
    function HiddenOn(const PageName: string): string;
    function AddEntry(const FileName, Description: string; Enabled: Boolean): TPackageEntry;
    procedure AddFramesItem;
    function ClassOfModule(C: TClass; M: HMODULE): Boolean;
    procedure ForgetMissingBitmaps;
    procedure Log(const S: string);
    procedure CallRegister(Module: HMODULE; const PackageName: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    procedure LoadInstalledPackages;
    { the IDE experts among the installed packages (they use BorlandIDEServices: an expert makes
      its menus while it registers) - once the main window is there; from then on every package
      loads at once }
    procedure LoadDeferredPackages;
    { the package list of D7 Studio (Component | Install Packages) }
    function FindPackage(const FileName: string): TPackageEntry;
    function InstallPackage(const FileName: string; var Error: string): TPackageEntry;
    function RemovePackage(E: TPackageEntry; var Error: string): Boolean;
    function EnablePackage(E: TPackageEntry; Enable: Boolean; var Error: string): Boolean;
    { the IDE ends: the loaded packages whose module is in Modules (the experts') taken out, the last
      loaded first - their finalization runs, as when Delphi unloads its packages at exit; what
      loads at the next start is not changed, and nothing is told (palette, the Open Tools API's
      package notifications) }
    procedure UnloadAtExit(Modules: TList);
    function PackageInUse(E: TPackageEntry): string;
    procedure GetPackageComponents(E: TPackageEntry; List: TStrings);
    { Environment Options | Palette, kept as Delphi keeps it: "<page>=TClass;TClass;..." per page
      in palette order (the Frames tool as Frames: TPaletteItem.LayoutName), "<page>.Hidden=..."
      for components taken off it ([Palette] of the
      settings). PaletteLayout is the current arrangement in that form; SetPaletteLayout stores
      and applies one, '' returns to the registered pages. }
    function PaletteLayout: string;
    procedure SetPaletteLayout(const Text: string);
    procedure ArrangePalette;
    procedure ArrangeFrom(Cfg: TStrings);
    function DefaultPaletteLayout: string;      // the registered arrangement, nothing changed
    function ItemPackageName(Item: TPaletteItem): string;
    { what Delphi says after installing: the package and the components it registered }
    function InstallReport(E: TPackageEntry): string;
    procedure SavePackageList;
    procedure SyncDesignWindows;       // call when a component or property editor has returned
    procedure AddComponents(const Page: string; const Classes: array of TComponentClass);
    procedure AddNoIcon(const Classes: array of TComponentClass);
    function PageCount: Integer;
    function PackageCount: Integer;
    function FindItem(const AClassName: string): TPaletteItem;
    function FindComponentClass(const AClassName: string): TComponentClass;
    function ComponentBitmap(AClass: TClass): TBitmap;        // 24 x 24, owned by the host
    { a palette item's icon: its own (a component template's, the Frames tool's), else its class's }
    function ItemBitmap(Item: TPaletteItem): TBitmap;
    { the component templates on the palette (the Components view): all of them taken off, one
      put on (Cls: its first component's class; IconFile: a bitmap of its own, '' none), then
      TemplatesChanged: the palette arranged again, the views told }
    procedure ClearTemplates;
    procedure AddTemplate(const AName, APage: string; Cls: TComponentClass; const Text, IconFile: string);
    procedure TemplatesChanged;
    { design notifications }
    procedure AddNotification(const N: IDesignNotification);
    procedure RemoveNotification(const N: IDesignNotification);
    procedure NotifyItemDeleted(const D: IDesigner; Item: TPersistent);
    procedure NotifyItemInserted(const D: IDesigner; Item: TPersistent);
    procedure NotifyItemsModified(const D: IDesigner);
    procedure NotifySelectionChanged(const D: IDesigner; const Sel: IDesignerSelections);
    procedure NotifyDesignerOpened(const D: IDesigner);
    procedure NotifyDesignerClosed(const D: IDesigner);
    { the custom modules the packages registered (RegisterCustomModule: TService ...): a base
      class of designed modules, by its class name (nil: none of that name); a package that goes
      takes its own away }
    procedure AddCustomModule(Group: Integer; ComponentBaseClass: TComponentClass);
    function CustomModuleClass(const AClassName: string): TComponentClass;
    property Pages[Index: Integer]: TPalettePage read GetPage;
    property Packages[Index: Integer]: TPackageEntry read GetPackage;
    property OnLog: THostLogEvent read FOnLog write FOnLog;
    { a package is about to be loaded (its file name): the start-up screen names it }
    property OnLoading: THostLogEvent read FOnLoading write FOnLoading;
    property OnPaletteChanged: TNotifyEvent read FOnPaletteChanged write FOnPaletteChanged;
    property OnDesignWindow: TDesignWindowEvent read FOnDesignWindow write FOnDesignWindow;
    property OnSyncDesignWindows: TNotifyEvent read FOnSyncDesignWindows write FOnSyncDesignWindows;
    { a package goes: before, the property editors made of its classes must go (the Object
      Inspector lets go of its rows); after it, they may come again }
    property OnPackageUnloading: TNotifyEvent read FOnPackageUnloading write FOnPackageUnloading;
    property OnPackageUnloaded: TNotifyEvent read FOnPackageUnloaded write FOnPackageUnloaded;
  end;

const
  { the Frames tool's name: its caption, its name in the palette's layout and on Delphi's palette
    (SelectedToolName) }
  FramesToolName = 'Frames';

var
  DesignHost: TDesignHost;
  { the Open Tools API (SdOtaServices): a wizard a package registers (RegisterPackageWizard); a
    package that is about to be unloaded (its wizards, notifiers and key bindings go first, while
    its code is there); a package that was loaded or unloaded (the IDE notifiers hear it) }
  OtaWizardHook: TWizardRegisterProc;
  OtaPackageUnloading: procedure(Module: HMODULE);
  OtaPackageChanged: procedure(const FileName: string; Loaded: Boolean);
  { the experts' interface of Delphi 1-3 (SdOtaLegacy): an expert a package registers
    (RegisterLibraryExpert) }
  OtaExpertHook: TExpertRegisterProc;

function ClassUnitName(AClass: TClass): string;
{ a class name as Delphi shows components (palette, Components view and window, default names,
  file names): without its leading T - TButton -> Button }
function ComponentDisplayName(const ClassName: string): string;

implementation

uses
  ExtCtrls, SdIcons, SdSettings, SdDelphiDir, Utf8Mode;

const
  { packages that only extend the Borland IDE itself and cannot work in another host }
  SkipPackages: array[0..5] of string = (
    'dclsmpedit70', 'dclemacsedit70', 'designdgm70', 'dbx70', 'dcldbx70x', 'dclocx70x');
  { units whose Register procedure needs Borland IDE services }
  SkipUnits: array[0..1] of string = ('dbexpt', 'ddereg');

var
  CbtHook: HHOOK;
  SuppressedDialogs: Integer;

type
  { what of the IDE a package imports: nothing, the Open Tools API (BorlandIDEServices), or the
    experts' interface of Delphi 1-3 (ExptIntf, ToolIntf, EditIntf, FileIntf: SdOtaLegacy) }
  TIdeImports = (iiNone, iiOpenTools, iiOldExpert);

  { a custom module a package registered: the base class of the modules designed with it }
  TCustomModuleEntry = class
  public
    BaseClass: TComponentClass;
    Group: Integer;                    // the editor group of the package that registered it
    Module: HMODULE;                   // ... that package
  end;

function FileIdeImports(const FileName: string): TIdeImports;
var
  FS: TFileStream;
  S: string;
begin
  Result := iiNone;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      SetLength(S, FS.Size);
      if FS.Size > 0 then FS.ReadBuffer(S[1], FS.Size);
    finally
      FS.Free;
    end;
    if (Pos('@Exptintf@', S) > 0) or (Pos('@Toolintf@', S) > 0) or (Pos('@Editintf@', S) > 0) or
      (Pos('@Fileintf@', S) > 0) then
      Result := iiOldExpert
    else if Pos('@Toolsapi@BorlandIDEServices', S) > 0 then Result := iiOpenTools;
  except
  end;
end;

function IsSkippedPackage(const FileName: string): Boolean;
var
  Base: string;
  J: Integer;
begin
  Base := LowerCase(ChangeFileExt(ExtractFileName(FileName), ''));
  for J := Low(SkipPackages) to High(SkipPackages) do
    if Base = SkipPackages[J] then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function ComponentDisplayName(const ClassName: string): string;
begin
  Result := ClassName;
  if (Length(Result) > 1) and (UpCase(Result[1]) = 'T') then Delete(Result, 1, 1);
end;

function ClassUnitName(AClass: TClass): string;
begin
  Result := '';
  if (AClass <> nil) and (AClass.ClassInfo <> nil) then
    Result := GetTypeData(AClass.ClassInfo)^.UnitName;
end;

{ --- registration hooks (plain procedures required by the RTL/VCL) --- }

procedure HookRegisterComponents(const Page: string; const ComponentClasses: array of TComponentClass);
begin
  if DesignHost <> nil then DesignHost.AddComponents(Page, ComponentClasses);
end;

procedure HookRegisterNoIcon(const ComponentClasses: array of TComponentClass);
begin
  if DesignHost <> nil then DesignHost.AddNoIcon(ComponentClasses);
end;

procedure HookRegisterNonActiveX(const ComponentClasses: array of TComponentClass; AxRegType: TActiveXRegType);
begin
end;

procedure HookRegisterFields(const FieldClasses: array of TFieldClass);
var
  I: Integer;
begin
  for I := Low(FieldClasses) to High(FieldClasses) do
    try
      RegisterClass(FieldClasses[I]);
    except
    end;
end;

function HookLibraryExpert(Expert: TIExpert): Boolean;
begin
  if Assigned(OtaExpertHook) then Result := OtaExpertHook(Expert) else Result := True;
end;

function HookLibraryWizard(const Wizard: IOTAWizard): Boolean;
begin
  if Assigned(OtaWizardHook) then Result := OtaWizardHook(Wizard) else Result := True;
end;

{ the custom module class itself (the designer's behaviour for such modules: menu verbs, the
  validation of components) has no counterpart in D7 Studio's designer: the base class is kept -
  a module that descends from it is designed as the data module or form it is }
procedure HookRegisterCustomModule(Group: Integer; ComponentBaseClass: TComponentClass;
  CustomModuleClass: TCustomModuleClass);
begin
  if DesignHost <> nil then DesignHost.AddCustomModule(Group, ComponentBaseClass);
end;

{ the form behind a design notification, when it is one (TDesignWindow and its descendants) }
function NotificationForm(const DesignNotification: IDesignNotification): TCustomForm;
var
  Ref: IInterfaceComponentReference;
  C: TComponent;
begin
  Result := nil;
  if Supports(DesignNotification, IInterfaceComponentReference, Ref) then
  begin
    C := Ref.GetComponent;
    if C is TCustomForm then Result := TCustomForm(C);
  end;
end;

{ a design notification registered or unregistered; the shell hears of a design window's form
  (OnDesignWindow: appearing, or being destroyed) }
procedure DesignNotificationChanged(const DesignNotification: IDesignNotification; Registered: Boolean);
var
  F: TCustomForm;
begin
  if DesignHost = nil then Exit;
  if Registered then DesignHost.AddNotification(DesignNotification)
  else DesignHost.RemoveNotification(DesignNotification);
  if Assigned(DesignHost.FOnDesignWindow) then
  begin
    F := NotificationForm(DesignNotification);
    if F <> nil then DesignHost.FOnDesignWindow(F, Registered);
  end;
end;

procedure HookRegisterDesignNotification(const DesignNotification: IDesignNotification);
begin
  DesignNotificationChanged(DesignNotification, True);
end;

procedure HookUnregisterDesignNotification(const DesignNotification: IDesignNotification);
begin
  DesignNotificationChanged(DesignNotification, False);
end;

procedure HookRegisterDragTarget(const SourceName: string; TargetClass: TDragTargetClass);
begin
end;

procedure HookRegisterDesignDragObject(DragObjectClass: TDragObjectClass);
begin
end;

function CbtProc(Code: Integer; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  Cls: array[0..63] of Char;
begin
  if Code = HCBT_CREATEWND then
  begin
    GetClassName(HWND(W), Cls, SizeOf(Cls));
    if StrComp(Cls, '#32770') = 0 then
    begin
      Inc(SuppressedDialogs);
      Result := 1;    // veto message boxes raised by expert registration code
      Exit;
    end;
  end;
  Result := CallNextHookEx(CbtHook, Code, W, L);
end;

{ package code that runs between these two calls (initialisation, Register) cannot show a
  message box: it is vetoed and counted in SuppressedDialogs }
procedure HookDialogs;
begin
  SuppressedDialogs := 0;
  CbtHook := SetWindowsHookEx(WH_CBT, @CbtProc, 0, GetCurrentThreadId);
end;

procedure UnhookDialogs;
begin
  UnhookWindowsHookEx(CbtHook);
  CbtHook := 0;
end;

type
  TNotifyKind = (nkItemDeleted, nkItemInserted, nkItemsModified, nkSelectionChanged,
    nkDesignerOpened, nkDesignerClosed);

{ Every design notification hears of it; one that fails keeps none of the others from it. The
  newest hear first, and a window that unregisters (closes) meanwhile shifts nothing not yet
  called. }
procedure Broadcast(List: TInterfaceList; Kind: TNotifyKind; const D: IDesigner; Item: TPersistent;
  const Sel: IDesignerSelections);
var
  I: Integer;
  N: IDesignNotification;
begin
  for I := List.Count - 1 downto 0 do
    try
      if I >= List.Count then Continue;
      N := IDesignNotification(List[I]);
      case Kind of
        nkItemDeleted: N.ItemDeleted(D, Item);
        nkItemInserted: N.ItemInserted(D, Item);
        nkItemsModified: N.ItemsModified(D);
        nkSelectionChanged: N.SelectionChanged(D, Sel);
        nkDesignerOpened: N.DesignerOpened(D, False);
        nkDesignerClosed: N.DesignerClosed(D, False);
      end;
    except
    end;
end;

{ TPalettePage }

destructor TPaletteItem.Destroy;
begin
  Bitmap.Free;
  inherited Destroy;
end;

function TPaletteItem.LayoutName: string;
begin
  if IsFrames then Result := Caption else Result := ComponentClass.ClassName;
end;

constructor TPalettePage.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Items := TList.Create;
end;

destructor TPalettePage.Destroy;
begin
  Items.Free;
  inherited;
end;

{ TDesignHost }

constructor TDesignHost.Create;
begin
  inherited Create;
  FPages := TList.Create;
  FTemplates := TList.Create;
  FItems := TStringList.Create;
  FItems.Sorted := True;
  FItems.Duplicates := dupIgnore;
  FPackages := TList.Create;
  FBitmaps := TStringList.Create;
  FBitmaps.Sorted := True;
  FNotifications := TInterfaceList.Create;
  FDesigners := TInterfaceList.Create;
  FCustomModules := TList.Create;
end;

destructor TDesignHost.Destroy;
var
  I: Integer;
begin
  ClearTemplates;                     // before the pages go
  for I := 0 to FCustomModules.Count - 1 do TObject(FCustomModules[I]).Free;
  FCustomModules.Free;
  FDesigners.Free;
  FNotifications.Free;
  for I := 0 to FBitmaps.Count - 1 do FBitmaps.Objects[I].Free;
  FBitmaps.Free;
  for I := 0 to FItems.Count - 1 do FItems.Objects[I].Free;
  FItems.Free;
  for I := 0 to FPages.Count - 1 do TObject(FPages[I]).Free;
  FTemplates.Free;
  FPages.Free;
  for I := 0 to FPackages.Count - 1 do TObject(FPackages[I]).Free;
  FPackages.Free;
  FDefaultBitmap.Free;
  inherited;
end;

procedure TDesignHost.Log(const S: string);
begin
  if Assigned(FOnLog) then FOnLog(S);
end;

procedure TDesignHost.Initialize;
var
  Path, Base: string;
begin
  if FInitialized then Exit;
  FInitialized := True;
  { dependent packages of design packages are resolved through the search path }
  Path := GetEnvironmentVariable('PATH');
  SetEnvironmentVariable('PATH', PChar(ExcludeTrailingPathDelimiter(DelphiBin) + ';' + DelphiRoot + 'Projects\Bpl;' + Path));
  { registration hooks normally provided by the Borland IDE }
  RegisterComponentsProc := HookRegisterComponents;
  RegisterNoIconProc := HookRegisterNoIcon;
  RegisterNonActiveXProc := HookRegisterNonActiveX;
  RegisterFieldsProc := HookRegisterFields;
  RegisterActionsProc := RegActions;
  UnRegisterActionsProc := UnRegActions;
  EnumRegisteredActionsProc := EnumActions;
  CreateActionProc := CreateAction;
  LibraryExpertProc := HookLibraryExpert;
  LibraryWizardProc := HookLibraryWizard;
  RegisterCustomModuleProc := HookRegisterCustomModule;
  RegisterDesignNotificationProc := HookRegisterDesignNotification;
  UnregisterDesignNotificationProc := HookUnregisterDesignNotification;
  RegisterDragTargetProc := HookRegisterDragTarget;
  RegisterDesignDragObjectProc := HookRegisterDesignDragObject;
  BaseRegistryKey := '\' + SettingsRegKey;
  { The component designer and its environment: Borland's design-time windows (action list
    editor, collection editor, menu designer ...) ask ComponentDesigner.ActiveDesigner for
    them. Their own files (menu templates) live next to D7 Studio's settings, their window
    settings under D7 Studio's registry key - the test instance uses a key of its own. }
  Base := SettingsDir + 'D7Studio';
  if not FileExists(Base + '.dmt') and FileExists(DelphiBin + 'delphi32.dmt') then
    CopyFile(PChar(DelphiBin + 'delphi32.dmt'), PChar(Base + '.dmt'), True);
  InstallComponentDesigner(Base, SettingsRegKey);
  { standard VCL property editors (registered by the IDE core in Delphi itself) }
  RegisterPropertyEditor(TypeInfo(TComponentName), TComponent, 'Name', TComponentNameProperty);
  RegisterPropertyEditor(TypeInfo(TFontName), TFont, 'Name', TFontNameProperty);
  RegisterPropertyEditor(TypeInfo(TFontCharset), TFont, 'Charset', TFontCharsetProperty);
  RegisterPropertyEditor(TypeInfo(TImeName), nil, '', TImeNameProperty);
  RegisterPropertyEditor(TypeInfo(TColor), nil, '', TColorProperty);
  RegisterPropertyEditor(TypeInfo(TBrushStyle), nil, '', TBrushStyleProperty);
  RegisterPropertyEditor(TypeInfo(TPenStyle), nil, '', TPenStyleProperty);
  RegisterPropertyEditor(TypeInfo(TCursor), nil, '', TCursorProperty);
  RegisterPropertyEditor(TypeInfo(TFont), nil, '', TFontProperty);
  RegisterPropertyEditor(TypeInfo(TModalResult), nil, '', TModalResultProperty);
  RegisterPropertyEditor(TypeInfo(TShortCut), nil, '', TShortCutProperty);
  RegisterPropertyEditor(TypeInfo(TTabOrder), nil, '', TTabOrderProperty);
  RegisterPropertyEditor(TypeInfo(TCaption), nil, '', TCaptionProperty);
  RegisterPropertyEditor(TypeInfo(TDate), nil, '', TDateProperty);
  RegisterPropertyEditor(TypeInfo(TTime), nil, '', TTimeProperty);
  RegisterPropertyEditor(TypeInfo(TDateTime), nil, '', TDateTimeProperty);
  { pictures: the Picture Editor for TPicture and for every TGraphic (bitmaps, icons), and as
    the component editor of TImage (PicEdit has the classes, the IDE registers them) }
  RegisterPropertyEditor(TypeInfo(TPicture), nil, '', TPictureProperty);
  RegisterPropertyEditor(TypeInfo(TGraphic), nil, '', TGraphicProperty);
  RegisterComponentEditor(TImage, TGraphicEditor);
  AddFramesItem;
end;

const
  DefaultPageOrder: array[0..32] of string = (
    'Standard', 'Additional', 'Win32', 'System', 'Data Access', 'Data Controls', 'dbExpress',
    'DataSnap', 'BDE', 'ADO', 'InterBase', 'WebServices', 'InternetExpress', 'Internet',
    'WebSnap', 'Decision Cube', 'Dialogs', 'Win 3.1', 'Samples', 'ActiveX', 'Rave',
    'Indy Clients', 'Indy Servers', 'Indy Intercepts', 'Indy I/O Handlers', 'Indy Misc', 'COM+',
    'InterBase Admin', 'IW Standard', 'IW Data', 'IW Client Side', 'IW Control', 'Servers');

function PageRank(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(DefaultPageOrder) to High(DefaultPageOrder) do
    if SameText(DefaultPageOrder[I], AName) then
    begin
      Result := I;
      Exit;
    end;
end;

{ an item off every page, and freed. A page it leaves empty stays until the palette is arranged
  again (ArrangePalette): the layout may keep it, or components hidden on it }
procedure TDesignHost.RemovePaletteItem(Item: TPaletteItem);
var
  J: Integer;
begin
  for J := 0 to FPages.Count - 1 do TPalettePage(FPages[J]).Items.Remove(Item);
  Item.Free;
end;

{ the templates off the palette (the pages are arranged again by TemplatesChanged, after the new
  ones are on) }
procedure TDesignHost.ClearTemplates;
var
  I: Integer;
begin
  for I := 0 to FTemplates.Count - 1 do RemovePaletteItem(TPaletteItem(FTemplates[I]));
  FTemplates.Clear;
end;

procedure TDesignHost.AddTemplate(const AName, APage: string; Cls: TComponentClass; const Text, IconFile: string);
var
  Item: TPaletteItem;
begin
  if Cls = nil then Exit;
  Item := TPaletteItem.Create;
  Item.ComponentClass := Cls;
  Item.Page := APage;
  Item.RegPage := APage;
  Item.Caption := AName;
  Item.Template := Text;
  if (IconFile <> '') and FileExists(IconFile) then
  begin
    Item.Bitmap := TBitmap.Create;
    try
      Item.Bitmap.LoadFromFile(IconFile);
    except
      FreeAndNil(Item.Bitmap);
    end;
  end;
  FTemplates.Add(Item);
  NeedPage(APage).Items.Add(Item);
end;

{ the palette arranged again with the templates now on it: a page they left empty goes unless
  the layout keeps it }
procedure TDesignHost.TemplatesChanged;
begin
  ArrangePalette;
  if Assigned(FOnPaletteChanged) then FOnPaletteChanged(Self);
end;

function TDesignHost.FindPage(const AName: string): TPalettePage;
var
  I: Integer;
begin
  for I := 0 to FPages.Count - 1 do
  begin
    Result := TPalettePage(FPages[I]);
    if SameText(Result.Name, AName) then Exit;
  end;
  Result := nil;
end;

function TDesignHost.NeedPage(const AName: string): TPalettePage;
var
  I, Rank: Integer;
begin
  Result := FindPage(AName);
  if Result <> nil then Exit;
  Result := TPalettePage.Create(AName);
  { the page order of the Delphi 7 palette; unknown pages follow in registration order }
  Rank := PageRank(AName);
  I := FPages.Count;
  if Rank >= 0 then
  begin
    I := 0;
    while (I < FPages.Count) and (PageRank(TPalettePage(FPages[I]).Name) >= 0) and
      (PageRank(TPalettePage(FPages[I]).Name) < Rank) do Inc(I);
  end;
  FPages.Insert(I, Result);
end;

procedure TDesignHost.AddComponents(const Page: string; const Classes: array of TComponentClass);
var
  I: Integer;
  Item: TPaletteItem;
  P: TPalettePage;
begin
  P := NeedPage(Page);
  for I := Low(Classes) to High(Classes) do
  begin
    if Classes[I] = nil then Continue;
    try
      RegisterClass(Classes[I]);
    except
      { a class of that name is registered already: keep the first one }
    end;
    if FItems.IndexOf(Classes[I].ClassName) >= 0 then Continue;
    Item := TPaletteItem.Create;
    Item.ComponentClass := Classes[I];
    Item.Page := P.Name;
    Item.RegPage := P.Name;
    Item.Module := FCurModule;
    FItems.AddObject(Classes[I].ClassName, Item);
    P.Items.Add(Item);
  end;
end;

function TDesignHost.ItemPackageName(Item: TPaletteItem): string;
var
  I: Integer;
  E: TPackageEntry;
begin
  Result := '';
  for I := 0 to FPackages.Count - 1 do
  begin
    E := TPackageEntry(FPackages[I]);
    if E.Loaded and (E.Module = Item.Module) then
    begin
      Result := ChangeFileExt(ExtractFileName(E.FileName), '');
      Exit;
    end;
  end;
end;

{ the components taken off page PageName, in the layout's form ("TClass;TClass;"; '' none) }
function TDesignHost.HiddenOn(const PageName: string): string;
var
  J: Integer;
  Item: TPaletteItem;
begin
  Result := '';
  for J := 0 to FItems.Count - 1 do
  begin
    Item := TPaletteItem(FItems.Objects[J]);
    if Item.Hidden and SameText(Item.Page, PageName) then Result := Result + Item.LayoutName + ';';
  end;
end;

function TDesignHost.PaletteLayout: string;
var
  I, J: Integer;
  P: TPalettePage;
  Order, Classes, Hidden: string;
begin
  Result := '';
  Order := '';
  for I := 0 to FPages.Count - 1 do
  begin
    P := TPalettePage(FPages[I]);
    Order := Order + P.Name + ';';
    Classes := '';
    { the components, not the templates on the page: a template would be written as the class of
      its first component, and the layout would move or hide that component }
    for J := 0 to P.Items.Count - 1 do
      if TPaletteItem(P.Items[J]).Template = '' then
        Classes := Classes + TPaletteItem(P.Items[J]).LayoutName + ';';
    Result := Result + P.Name + '=' + Classes + #13#10;
    Hidden := HiddenOn(P.Name);
    if Hidden <> '' then Result := Result + P.Name + '.Hidden=' + Hidden + #13#10;
  end;
  Result := '.Order=' + Order + #13#10 + Result;
end;

procedure TDesignHost.SetPaletteLayout(const Text: string);
var
  L: TStringList;
  I: Integer;
begin
  if Settings = nil then Exit;
  Settings.EraseSection('Palette');
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
      if L.Names[I] <> '' then Settings.WriteString('Palette', L.Names[I], L.ValueFromIndex[I]);
  finally
    L.Free;
  end;
  SaveSettings;
  ArrangePalette;
  if Assigned(FOnPaletteChanged) then FOnPaletteChanged(Self);
end;

{ the pages and their components as the layout of the settings says }
procedure TDesignHost.ArrangePalette;
var
  Cfg: TStringList;
begin
  Cfg := TStringList.Create;
  try
    if Settings <> nil then Settings.ReadSectionValues('Palette', Cfg);
    ArrangeFrom(Cfg);
  finally
    Cfg.Free;
  end;
end;

{ Environment Options | Palette | Default Pages: the arrangement without a layout of the user's
  - arranged so, read, and the user's made again; the settings and the views are not touched
  (they change only with OK) }
function TDesignHost.DefaultPaletteLayout: string;
var
  Empty: TStringList;
begin
  Empty := TStringList.Create;
  try
    ArrangeFrom(Empty);
    Result := PaletteLayout;
  finally
    Empty.Free;
    ArrangePalette;
    { the user's own pages were made again as new objects: whoever keeps pages lets go of them }
    if Assigned(FOnPaletteChanged) then FOnPaletteChanged(Self);
  end;
end;

{ the pages and their components as a layout says (lines "page=classes;", "page.Hidden=...",
  ".Order=pages;"); components it does not name stay on the page they were registered on,
  after the ones it names }
procedure TDesignHost.ArrangeFrom(Cfg: TStrings);
var
  Names: TStringList;
  I, J, K: Integer;
  Item: TPaletteItem;
  P: TPalettePage;
  Order: TList;

  function Split(const S: string): TStringList;
  begin
    Result := TStringList.Create;
    Result.Text := StringReplace(S, ';', #13#10, [rfReplaceAll]);
  end;

  { a page the layout names: at the end, the order of the layout comes later }
  function PageOf(const AName: string): TPalettePage;
  begin
    Result := FindPage(AName);
    if Result <> nil then Exit;
    Result := TPalettePage.Create(AName);
    FPages.Add(Result);
  end;

begin
  Order := TList.Create;
  try
    { every component back to its registered page, shown }
    for I := 0 to FPages.Count - 1 do TPalettePage(FPages[I]).Items.Clear;
    for I := 0 to FItems.Count - 1 do
    begin
      Item := TPaletteItem(FItems.Objects[I]);
      Item.Hidden := False;
      Item.Page := '';
    end;
    if Cfg.Count > 0 then
    begin
      { the pages of the layout in its order }
      Names := Split(Cfg.Values['.Order']);
      try
        for I := 0 to Names.Count - 1 do
          if Trim(Names[I]) <> '' then Order.Add(PageOf(Trim(Names[I])));
      finally
        Names.Free;
      end;
      for I := 0 to Cfg.Count - 1 do
      begin
        if (Cfg.Names[I] = '') or (Cfg.Names[I][1] = '.') then Continue;
        Names := Split(Cfg.ValueFromIndex[I]);
        try
          K := Pos('.Hidden', Cfg.Names[I]);
          if (K > 0) and (K = Length(Cfg.Names[I]) - 6) then
          begin
            P := PageOf(Copy(Cfg.Names[I], 1, K - 1));
            for J := 0 to Names.Count - 1 do
            begin
              Item := FindItem(Trim(Names[J]));
              if Item <> nil then
              begin
                Item.Page := P.Name;
                Item.Hidden := True;
              end;
            end;
          end
          else
          begin
            P := PageOf(Cfg.Names[I]);
            for J := 0 to Names.Count - 1 do
            begin
              Item := FindItem(Trim(Names[J]));
              if (Item <> nil) and (Item.Page = '') then
              begin
                Item.Page := P.Name;
                P.Items.Add(Item);
              end;
            end;
          end;
        finally
          Names.Free;
        end;
      end;
    end;
    { the component templates: on their pages }
    for I := 0 to FTemplates.Count - 1 do
    begin
      Item := TPaletteItem(FTemplates[I]);
      NeedPage(Item.RegPage).Items.Add(Item);
    end;
    { what the layout does not name: on its registered page - the Frames tool first there, its
      place in Delphi 7 }
    for I := 0 to FItems.Count - 1 do
    begin
      Item := TPaletteItem(FItems.Objects[I]);
      if Item.Page = '' then
      begin
        P := NeedPage(Item.RegPage);
        Item.Page := P.Name;
        if Item.IsFrames then P.Items.Insert(0, Item) else P.Items.Add(Item);
      end;
    end;
    { the page order: the layout's first, then the others as they were }
    for I := Order.Count - 1 downto 0 do
    begin
      FPages.Remove(Order[I]);
      FPages.Insert(0, Order[I]);
    end;
    { pages left empty that the layout does not keep go away - not one that has hidden components }
    for I := FPages.Count - 1 downto 0 do
    begin
      P := TPalettePage(FPages[I]);
      if (P.Items.Count = 0) and (Order.IndexOf(P) < 0) and (HiddenOn(P.Name) = '') then
      begin
        FPages.Delete(I);
        P.Free;
      end;
    end;
  finally
    Order.Free;
  end;
end;

procedure TDesignHost.AddNoIcon(const Classes: array of TComponentClass);
var
  I: Integer;
begin
  for I := Low(Classes) to High(Classes) do
    if Classes[I] <> nil then
      try
        RegisterClass(Classes[I]);
      except
      end;
end;

type
  TRegProc = procedure;
  TEnumCtx = record
    Host: TDesignHost;
    Module: HMODULE;
    Units: TStringList;
  end;
  PEnumCtx = ^TEnumCtx;

procedure PackageInfoProc(const Name: string; NameType: TNameType; Flags: Byte; Param: Pointer);
begin
  if NameType = ntContainsUnit then PEnumCtx(Param)^.Units.Add(Name);
end;

procedure TDesignHost.CallRegister(Module: HMODULE; const PackageName: string);
var
  Ctx: TEnumCtx;
  Flags, I, J: Integer;
  Mangled, U: string;
  P: Pointer;
  Skip: Boolean;
begin
  Ctx.Host := Self;
  Ctx.Module := Module;
  Ctx.Units := TStringList.Create;
  try
    Flags := 0;
    GetPackageInfo(Module, @Ctx, Flags, PackageInfoProc);
    for I := 0 to Ctx.Units.Count - 1 do
    begin
      U := Ctx.Units[I];
      Skip := False;
      for J := Low(SkipUnits) to High(SkipUnits) do
        if SameText(U, SkipUnits[J]) then Skip := True;
      if Skip then Continue;
      Mangled := '@' + UpperCase(Copy(U, 1, 1)) + LowerCase(Copy(U, 2, MaxInt)) + '@Register$qqrv';
      P := GetProcAddress(Module, PChar(Mangled));
      if P = nil then Continue;
      HookDialogs;
      try
        try
          TRegProc(P);
        except
          on E: Exception do
            Log(Format('%s: %s.Register failed (%s)', [PackageName, U, E.Message]));
        end;
      finally
        UnhookDialogs;
      end;
      if SuppressedDialogs > 0 then
        Log(Format('%s: %s.Register needs Borland IDE services (ignored)', [PackageName, U]));
    end;
  finally
    Ctx.Units.Free;
  end;
end;

function TDesignHost.FindPackage(const FileName: string): TPackageEntry;
var
  I: Integer;
begin
  for I := 0 to FPackages.Count - 1 do
  begin
    Result := TPackageEntry(FPackages[I]);
    if SameText(Result.FileName, FileName) then Exit;
  end;
  Result := nil;
end;

{ a new entry at the end of the package list }
function TDesignHost.AddEntry(const FileName, Description: string; Enabled: Boolean): TPackageEntry;
begin
  Result := TPackageEntry.Create;
  Result.FileName := FileName;
  Result.Description := Description;
  Result.Enabled := Enabled;
  FPackages.Add(Result);
end;

{ Maps the package, runs its initialisation and the Register procedures of its units. Every
  editor it registers belongs to the entry's editor group, so that it can be taken out again. }
function TDesignHost.LoadEntry(E: TPackageEntry): Boolean;
var
  Base, Dir, Path, FileName: string;
begin
  Result := False;
  FileName := E.FileName;
  E.Error := '';
  E.Module := 0;
  Base := ChangeFileExt(ExtractFileName(FileName), '');
  if not FileExists(FileName) then
  begin
    E.Error := 'File not found';
    Log(Base + ': file not found');
    Exit;
  end;
  if Assigned(FOnLoading) then FOnLoading(FileName);
  { run-time packages that live next to the design package }
  Dir := ExtractFilePath(FileName);
  Path := GetEnvironmentVariable('PATH');
  if not PathHasDir(Path, Dir) then
    SetEnvironmentVariable('PATH', PChar(Path + ';' + ExcludeTrailingPathDelimiter(Dir)));
  { IDE experts (as opposed to component packages) talk to the IDE while they initialise and
    register; outside Delphi's own packages they are recognised by their imports. Experts of the
    Open Tools API and of Delphi 1-3 (ExptIntf, ToolIntf: SdOtaLegacy) load once the main window
    is there (their menus) - the file is read for its imports only while that is not the case. }
  E.Deferred := False;
  if not FIdeReady and not SameText(Dir, DelphiBin) and (FileIdeImports(FileName) <> iiNone) then
  begin
    E.Deferred := True;
    Log(Base + ': IDE expert - loaded with the main window');
    Exit;
  end;
  HookDialogs;
  try
    E.Module := SafeLoadLibrary(FileName);
    if E.Module = 0 then
      E.Error := SysErrorMessage(GetLastError)
    else
      try
        { UTF-8 mode: the package and the ones it brought along draw their text through the
          RTL's UTF-8 shims, as SysUtils.LoadPackage would set them (Utf8Mode) }
        InstallUtf8ShimsForModules;
        InitializePackage(E.Module);
      except
        on Ex: Exception do
        begin
          { the module stays mapped on purpose: units that did initialise may have left
            pointers into it behind }
          E.Error := Ex.Message;
        end;
      end;
  finally
    UnhookDialogs;
  end;
  if (E.Module = 0) or (E.Error <> '') then
  begin
    Log(Format('%s: cannot be loaded (%s)', [Base, E.Error]));
    Exit;
  end;
  FCurModule := E.Module;
  E.Group := NewEditorGroup;
  try
    CallRegister(E.Module, Base);
  finally
    FCurModule := 0;
  end;
  E.Loaded := True;
  Result := True;
  ForgetMissingBitmaps;
  ArrangePalette;                  // the user's palette layout (Environment Options | Palette)
  if DesignEnvironment <> nil then
    try
      DesignEnvironment.PackagesInstalled.Send(Self);
    except
    end;
  if Assigned(FOnPaletteChanged) then FOnPaletteChanged(Self);
  if Assigned(OtaPackageChanged) then OtaPackageChanged(FileName, True);
end;

procedure TDesignHost.LoadDeferredPackages;
var
  I: Integer;
  E: TPackageEntry;
begin
  FIdeReady := True;
  for I := 0 to FPackages.Count - 1 do
  begin
    E := TPackageEntry(FPackages[I]);
    if E.Deferred and E.Enabled and not E.Loaded then LoadEntry(E);
  end;
end;

type
  TRequireCtx = record
    Wanted: string;
    Found: Boolean;
  end;
  PRequireCtx = ^TRequireCtx;

procedure RequireInfoProc(const Name: string; NameType: TNameType; Flags: Byte; Param: Pointer);
begin
  if (NameType = ntRequiresPackage) and
    SameText(ChangeFileExt(ExtractFileName(Name), ''), PRequireCtx(Param)^.Wanted) then
    PRequireCtx(Param)^.Found := True;
end;

{ True when the loaded package Module was built on the package FileName. }
function PackageRequires(Module: HMODULE; const FileName: string): Boolean;
var
  Ctx: TRequireCtx;
  Flags: Integer;
begin
  Ctx.Wanted := ChangeFileExt(ExtractFileName(FileName), '');
  Ctx.Found := False;
  Flags := 0;
  try
    GetPackageInfo(Module, @Ctx, Flags, RequireInfoProc);
  except
  end;
  Result := Ctx.Found;
end;

{ C belongs to the package of module M: its code is there, or the package put it on the palette -
  a design package's components often live in a run-time package it requires, which goes with it }
function TDesignHost.ClassOfModule(C: TClass; M: HMODULE): Boolean;
var
  Item: TPaletteItem;
begin
  Result := HMODULE(FindClassHInstance(C)) = M;
  if not Result and (C <> nil) then
  begin
    Item := FindItem(C.ClassName);
    Result := (Item <> nil) and (Item.Module = M);
  end;
end;

{ '' when nothing that is open was made by the package; otherwise what uses it. }
function TDesignHost.PackageInUse(E: TPackageEntry): string;
var
  I, J: Integer;
  Root, C: TComponent;
  M: TCustomModuleEntry;
begin
  Result := '';
  if not E.Loaded or (E.Module = 0) then Exit;
  for I := 0 to FDesigners.Count - 1 do
  begin
    Root := IDesigner(FDesigners[I]).Root;
    if Root = nil then Continue;
    { a custom module the package registered: its designer holds an instance of the class (the
      root class name is the class's then) }
    for J := 0 to FCustomModules.Count - 1 do
    begin
      M := TCustomModuleEntry(FCustomModules[J]);
      if (M.Module = E.Module) and SameText(M.BaseClass.ClassName, IDesigner(FDesigners[I]).GetRootClassName) then
      begin
        Result := Format('%s is a %s module', [Root.Name, M.BaseClass.ClassName]);
        Exit;
      end;
    end;
    for J := 0 to Root.ComponentCount - 1 do
    begin
      C := Root.Components[J];
      if ClassOfModule(C.ClassType, E.Module) then
      begin
        Result := Format('%s uses %s (%s)', [Root.Name, C.ClassName, C.Name]);
        Exit;
      end;
    end;
  end;
end;

procedure TDesignHost.GetPackageComponents(E: TPackageEntry; List: TStrings);
var
  I: Integer;
  Item: TPaletteItem;
begin
  List.Clear;
  if not E.Loaded then Exit;
  for I := 0 to FItems.Count - 1 do
  begin
    Item := TPaletteItem(FItems.Objects[I]);
    if Item.Module = E.Module then List.Add(Item.ComponentClass.ClassName + '=' + Item.Page);
  end;
end;

function TDesignHost.InstallReport(E: TPackageEntry): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    GetPackageComponents(E, L);
    Result := Format('Package %s has been installed.', [E.FileName]);
    if L.Count = 0 then
      Result := Result + #13#10 + 'No new components were registered.'
    else
    begin
      Result := Result + #13#10 + 'The following new component(s) have been registered: ';
      for I := 0 to L.Count - 1 do
      begin
        if I > 0 then Result := Result + ', ';
        if I = 12 then
        begin
          Result := Result + '...';
          Break;
        end;
        Result := Result + L.Names[I];
      end;
      Result := Result + '.';
    end;
  finally
    L.Free;
  end;
end;

{ Takes a package out of the process: its design windows, its palette entries, its editors,
  then the code itself (finalization and FreeLibrary, which also releases the file). Refused
  while a form that is open contains one of its components or another package is built on it. }
function TDesignHost.UnloadEntry(E: TPackageEntry; var Error: string): Boolean;
var
  I, J, K: Integer;
  Item: TPaletteItem;
  Other: TPackageEntry;
  M: HMODULE;
  Base: string;
  Wins: TList;
begin
  Result := True;
  Error := '';
  if not E.Loaded then Exit;
  Result := False;
  Base := ExtractFileName(E.FileName);
  Error := PackageInUse(E);
  if Error <> '' then
  begin
    Error := Format('%s cannot be removed: %s. Close the form first.', [Base, Error]);
    Exit;
  end;
  for I := 0 to FPackages.Count - 1 do
  begin
    Other := TPackageEntry(FPackages[I]);
    if (Other <> E) and Other.Loaded and PackageRequires(Other.Module, E.FileName) then
    begin
      Error := Format('%s cannot be removed: %s is built on it. Remove that package first.',
        [Base, ExtractFileName(Other.FileName)]);
      Exit;
    end;
  end;
  M := E.Module;
  if Assigned(FOnPackageUnloading) then FOnPackageUnloading(Self);
  if DesignEnvironment <> nil then
    try
      DesignEnvironment.PackagesUninstalling.Send(Self);
    except
    end;
  { design windows whose class lives in the package - found first: freeing one may free others
    (an editor its own windows), so each is freed only while the screen still has it }
  Wins := TList.Create;
  try
    for I := 0 to Screen.CustomFormCount - 1 do
      if HMODULE(FindClassHInstance(Screen.CustomForms[I].ClassType)) = M then Wins.Add(Screen.CustomForms[I]);
    for I := Wins.Count - 1 downto 0 do
      try
        for J := 0 to Screen.CustomFormCount - 1 do
          if Screen.CustomForms[J] = Wins[I] then
          begin
            Screen.CustomForms[J].Free;
            Break;
          end;
      except
      end;
  finally
    Wins.Free;
  end;
  { the component templates of its classes go along (their class goes) - while its palette items
    are there to tell its classes }
  for I := FTemplates.Count - 1 downto 0 do
  begin
    Item := TPaletteItem(FTemplates[I]);
    if not ClassOfModule(Item.ComponentClass, M) then Continue;
    FTemplates.Delete(I);
    RemovePaletteItem(Item);
  end;
  { palette }
  for I := FItems.Count - 1 downto 0 do
  begin
    Item := TPaletteItem(FItems.Objects[I]);
    if Item.Module <> M then Continue;
    K := FBitmaps.IndexOf(FItems[I]);
    if K >= 0 then
    begin
      FBitmaps.Objects[K].Free;
      FBitmaps.Delete(K);
    end;
    FItems.Delete(I);
    RemovePaletteItem(Item);
  end;
  { the palette must forget the items before the code goes away (the pages left empty go,
    unless the layout keeps them) }
  ArrangePalette;
  if Assigned(FOnPaletteChanged) then FOnPaletteChanged(Self);
  { property, component and selection editors of the package, its custom modules }
  try
    FreeEditorGroup(E.Group);
  except
  end;
  for I := FCustomModules.Count - 1 downto 0 do
    if (TCustomModuleEntry(FCustomModules[I]).Module = M) or (TCustomModuleEntry(FCustomModules[I]).Group = E.Group) then
    begin
      TObject(FCustomModules[I]).Free;
      FCustomModules.Delete(I);
    end;
  { the Open Tools API lets go of the package's wizards, notifiers and key bindings }
  if Assigned(OtaPackageUnloading) then
    try
      OtaPackageUnloading(M);
    except
      on Ex: Exception do Log(Format('%s: %s while its wizards were released', [Base, Ex.Message]));
    end;
  { finalization sections, class registrations (module unload procedures), the module }
  try
    UnloadPackage(M);
  except
    on Ex: Exception do Log(Format('%s: %s while unloading', [Base, Ex.Message]));
  end;
  E.Module := 0;
  E.Loaded := False;
  Result := True;
  if Assigned(FOnPackageUnloaded) then FOnPackageUnloaded(Self);
  if Assigned(OtaPackageChanged) then OtaPackageChanged(E.FileName, False);
end;

procedure TDesignHost.UnloadAtExit(Modules: TList);
var
  I: Integer;
  E: TPackageEntry;
  Err: string;
  Changed: procedure(const FileName: string; Loaded: Boolean);
begin
  if (Modules = nil) or (Modules.Count = 0) then Exit;
  FOnPaletteChanged := nil;
  FOnPackageUnloaded := nil;
  Changed := OtaPackageChanged;
  OtaPackageChanged := nil;
  try
    for I := FPackages.Count - 1 downto 0 do
    begin
      E := TPackageEntry(FPackages[I]);
      if not E.Loaded or (Modules.IndexOf(Pointer(E.Module)) < 0) then Continue;
      try
        if not UnloadEntry(E, Err) then Log(Err);
      except
        on Ex: Exception do Log(Format('%s: %s while unloading at exit', [ExtractFileName(E.FileName), Ex.Message]));
      end;
    end;
  finally
    OtaPackageChanged := Changed;
  end;
end;

function TDesignHost.InstallPackage(const FileName: string; var Error: string): TPackageEntry;
var
  Desc: string;
begin
  Error := '';
  Initialize;
  Result := FindPackage(FileName);
  if (Result <> nil) and not Result.BuiltIn then
  begin
    Result.Enabled := True;
    if not Result.Loaded and not LoadEntry(Result) then Error := Result.Error;
    Exit;
  end;
  if IsSkippedPackage(FileName) then
  begin
    Error := ExtractFileName(FileName) + ' extends the Borland IDE itself and cannot work in D7 Studio.';
    Result := nil;
    Exit;
  end;
  try
    Desc := GetPackageDescription(PChar(FileName));
  except
    Desc := '';
  end;
  if Desc = '' then Desc := ChangeFileExt(ExtractFileName(FileName), '');
  Result := AddEntry(FileName, Desc, True);
  if not LoadEntry(Result) then
  begin
    { not a design package of this Delphi, or it needs something that is missing: forget it }
    Error := Result.Error;
    FPackages.Remove(Result);
    Result.Free;
    Result := nil;
  end;
end;

function TDesignHost.RemovePackage(E: TPackageEntry; var Error: string): Boolean;
begin
  Result := UnloadEntry(E, Error);
  if Result then
  begin
    FPackages.Remove(E);
    E.Free;
  end;
end;

function TDesignHost.EnablePackage(E: TPackageEntry; Enable: Boolean; var Error: string): Boolean;
begin
  Error := '';
  if Enable then
  begin
    Result := E.Loaded or LoadEntry(E);
    if not Result then Error := E.Error;
    E.Enabled := True;
  end
  else
  begin
    Result := UnloadEntry(E, Error);
    if Result then E.Enabled := False;
  end;
end;

{ The list lives in D7Studio.ini: [Design Packages] Count=n, P<i>=<0|1>|<file>|<description>; a
  file of D7 Studio's folder is written as $(DELPHI)\... (the list stays right when the folder
  is moved; LoadInstalledPackages expands it). }
procedure TDesignHost.SavePackageList;
var
  I, N: Integer;
  E: TPackageEntry;
  LastDir: string;
begin
  if Settings = nil then Exit;
  { the list is written anew; the folder of the Add dialog stays }
  LastDir := Settings.ReadString('Design Packages', 'LastDir', '');
  Settings.EraseSection('Design Packages');
  if LastDir <> '' then Settings.WriteString('Design Packages', 'LastDir', LastDir);
  N := 0;
  for I := 0 to FPackages.Count - 1 do
  begin
    E := TPackageEntry(FPackages[I]);
    if E.BuiltIn then Continue;
    Settings.WriteString('Design Packages', 'P' + IntToStr(N),
      Format('%d|%s|%s', [Ord(E.Enabled), CollapseDelphiMacros(E.FileName), E.Description]));
    Inc(N);
  end;
  Settings.WriteInteger('Design Packages', 'Count', N);
  SaveSettings;
end;

{ The first start (no list in the settings; migrate.exe copies Delphi 7's installed packages into
  them when D7 Studio is installed): Borland's standard packages ("file=description") }
procedure TDesignHost.SeedPackages(Names: TStrings);
var
  I: Integer;
  FileName: string;
begin
  Names.Clear;
  Names.Add(DelphiBin + 'dclstd70.bpl=Borland Standard Components');
  Names.Add(DelphiBin + 'dcldb70.bpl=Borland Database Components');
  Names.Add(DelphiBin + 'dclsmp70.bpl=Borland Sample Components');
  for I := Names.Count - 1 downto 0 do
  begin
    FileName := ExpandDelphiMacros(Names.Names[I]);
    if IsSkippedPackage(FileName) then Names.Delete(I)
    else Names[I] := FileName + '=' + Names.ValueFromIndex[I];
  end;
end;

procedure TDesignHost.LoadInstalledPackages;
var
  Names: TStringList;
  I: Integer;
  FileName: string;
  E: TPackageEntry;
  Enabled: Boolean;
begin
  Initialize;
  { Delphi's VCL designer package: the Menu Designer and its component and property editors.
    It belongs to the designer and is not part of the list the user manages. }
  FileName := DelphiBin + 'vcldesigner70.bpl';
  if FileExists(FileName) and (FindPackage(FileName) = nil) then
  begin
    E := AddEntry(FileName, 'Delphi VCL Designer', True);
    E.BuiltIn := True;
    LoadEntry(E);
  end;
  Names := TStringList.Create;
  try
    { "file=description", a leading '-' when disabled }
    if not SettingsPackages(Settings, Names) then
      SeedPackages(Names);
    { the standard package first: other packages depend on its registrations }
    for I := 0 to Names.Count - 1 do
      if Pos('dclstd70', LowerCase(Names.Names[I])) > 0 then
      begin
        Names.Move(I, 0);
        Break;
      end;
    for I := 0 to Names.Count - 1 do
    begin
      FileName := Names.Names[I];
      if FileName = '' then Continue;
      Enabled := FileName[1] <> '-';
      if not Enabled then Delete(FileName, 1, 1);
      if FindPackage(FileName) <> nil then Continue;
      E := AddEntry(FileName, Names.ValueFromIndex[I], Enabled);
      if Enabled then LoadEntry(E);
    end;
  finally
    Names.Free;
  end;
end;

function TDesignHost.GetPage(Index: Integer): TPalettePage;
begin
  Result := TPalettePage(FPages[Index]);
end;

function TDesignHost.GetPackage(Index: Integer): TPackageEntry;
begin
  Result := TPackageEntry(FPackages[Index]);
end;

function TDesignHost.PageCount: Integer;
begin
  Result := FPages.Count;
end;

function TDesignHost.PackageCount: Integer;
begin
  Result := FPackages.Count;
end;

function TDesignHost.FindItem(const AClassName: string): TPaletteItem;
var
  I: Integer;
begin
  I := FItems.IndexOf(AClassName);
  if I >= 0 then Result := TPaletteItem(FItems.Objects[I]) else Result := nil;
end;

function TDesignHost.FindComponentClass(const AClassName: string): TComponentClass;
var
  Item: TPaletteItem;
  C: TPersistentClass;
begin
  Result := nil;
  Item := FindItem(AClassName);
  if (Item <> nil) and not Item.IsFrames then      // the Frames tool is no class of that name
  begin
    Result := Item.ComponentClass;
    Exit;
  end;
  C := GetClass(AClassName);
  if (C <> nil) and C.InheritsFrom(TComponent) then Result := TComponentClass(C);
end;

{ the palette bitmap of a component without one of its own: a component's icon }
function LoadDefaultComponentBitmap: TBitmap;
begin
  Result := IconTile(iiNonVisual, 24, clWindow);
end;

const
  FramesBitmapModule = 'coreide70.bpl';
  FramesBitmapName = 'NESTEDFRAME';

{ The Frames tool's image as Delphi 7 shows it: its bitmap in the installed Delphi 7's IDE
  package, read as the components' images are read from their packages - from the module when it
  is loaded, else from its file as data (nil: not there) }
function LoadDelphiFramesBitmap: TBitmap;
var
  M: HMODULE;
  H: HBITMAP;
  Loaded: Boolean;
begin
  Result := nil;
  M := GetModuleHandle(FramesBitmapModule);
  Loaded := M = 0;
  if Loaded then M := LoadLibraryEx(PChar(DelphiBin + FramesBitmapModule), 0, LOAD_LIBRARY_AS_DATAFILE);
  if M = 0 then Exit;
  try
    if FindResource(M, FramesBitmapName, RT_BITMAP) = 0 then Exit;
    H := LoadBitmap(M, FramesBitmapName);
    if H = 0 then Exit;
    Result := TBitmap.Create;
    Result.Handle := H;
    Result.Transparent := True;
    Result.TransparentMode := tmAuto;      // bottom-left pixel, the Delphi convention
  finally
    if Loaded then FreeLibrary(M);
  end;
end;

{ Delphi 7's Frames tool on the Standard page (ArrangeFrom puts it first there unless the layout
  says otherwise), with Delphi 7's image of it - the icon iiFrameTool when that is not there }
procedure TDesignHost.AddFramesItem;
var
  Item: TPaletteItem;
begin
  if FindItem(FramesToolName) <> nil then Exit;
  Item := TPaletteItem.Create;
  Item.ComponentClass := TFrame;
  Item.Caption := FramesToolName;
  Item.IsFrames := True;
  Item.Page := 'Standard';
  Item.RegPage := Item.Page;
  Item.Bitmap := LoadDelphiFramesBitmap;
  if Item.Bitmap = nil then Item.Bitmap := IconTile(iiFrameTool, 24, clWindow);
  FItems.AddObject(FramesToolName, Item);
  NeedPage(Item.Page).Items.Insert(0, Item);
end;

{ As Delphi 7: the bitmap named after the class - in the module that registered it, or in any
  loaded package; a class without one shows the default component image (the bitmap of an
  ancestor is not used) }
function TDesignHost.ComponentBitmap(AClass: TClass): TBitmap;
var
  I, J: Integer;
  ResName: string;
  H: HBITMAP;
  M: HMODULE;
  Item: TPaletteItem;

  function TryModule(Module: HMODULE): Boolean;
  begin
    Result := False;
    if Module = 0 then Exit;
    if FindResource(Module, PChar(ResName), RT_BITMAP) = 0 then Exit;
    H := LoadBitmap(Module, PChar(ResName));
    Result := H <> 0;
  end;

begin
  Result := nil;
  if AClass = nil then Exit;
  I := FBitmaps.IndexOf(AClass.ClassName);
  if I >= 0 then
    Result := TBitmap(FBitmaps.Objects[I])        // nil: looked for before, in vain
  else
  begin
    H := 0;
    ResName := UpperCase(AClass.ClassName);
    Item := FindItem(AClass.ClassName);
    if (Item = nil) or not TryModule(Item.Module) then
      for J := 0 to FPackages.Count - 1 do
      begin
        M := TPackageEntry(FPackages[J]).Module;
        if TryModule(M) then Break;
      end;
    if H <> 0 then
    begin
      Result := TBitmap.Create;
      Result.Handle := H;
      Result.Transparent := True;
      Result.TransparentMode := tmAuto;      // bottom-left pixel, the Delphi convention
    end;
    { a miss is noted too - every paint of a tile asks - until another package is loaded
      (ForgetMissingBitmaps) }
    FBitmaps.AddObject(AClass.ClassName, Result);
  end;
  if Result = nil then
  begin
    { the shared default image }
    if FDefaultBitmap = nil then FDefaultBitmap := LoadDefaultComponentBitmap;
    Result := FDefaultBitmap;
  end;
end;

function TDesignHost.ItemBitmap(Item: TPaletteItem): TBitmap;
begin
  if Item.Bitmap <> nil then Result := Item.Bitmap else Result := ComponentBitmap(Item.ComponentClass);
end;

{ the classes noted without a bitmap: a package loaded now may have one for them }
procedure TDesignHost.ForgetMissingBitmaps;
var
  I: Integer;
begin
  for I := FBitmaps.Count - 1 downto 0 do
    if FBitmaps.Objects[I] = nil then FBitmaps.Delete(I);
end;

procedure TDesignHost.SyncDesignWindows;
begin
  if Assigned(FOnSyncDesignWindows) then FOnSyncDesignWindows(Self);
end;

{ --- design notifications --- }

procedure TDesignHost.AddNotification(const N: IDesignNotification);
begin
  if FNotifications.IndexOf(N) < 0 then FNotifications.Add(N);
end;

procedure TDesignHost.RemoveNotification(const N: IDesignNotification);
begin
  FNotifications.Remove(N);
end;

procedure TDesignHost.NotifyItemDeleted(const D: IDesigner; Item: TPersistent);
begin
  Broadcast(FNotifications, nkItemDeleted, D, Item, nil);
end;

procedure TDesignHost.NotifyItemInserted(const D: IDesigner; Item: TPersistent);
begin
  Broadcast(FNotifications, nkItemInserted, D, Item, nil);
end;

procedure TDesignHost.NotifyItemsModified(const D: IDesigner);
begin
  Broadcast(FNotifications, nkItemsModified, D, nil, nil);
end;

procedure TDesignHost.NotifySelectionChanged(const D: IDesigner; const Sel: IDesignerSelections);
begin
  Broadcast(FNotifications, nkSelectionChanged, D, nil, Sel);
end;

procedure TDesignHost.NotifyDesignerOpened(const D: IDesigner);
begin
  if FDesigners.IndexOf(D) < 0 then FDesigners.Add(D);
  Broadcast(FNotifications, nkDesignerOpened, D, nil, nil);
end;

procedure TDesignHost.NotifyDesignerClosed(const D: IDesigner);
begin
  FDesigners.Remove(D);
  Broadcast(FNotifications, nkDesignerClosed, D, nil, nil);
end;

{ the package registering now (its Register: FCurModule), else the base class's own module }
procedure TDesignHost.AddCustomModule(Group: Integer; ComponentBaseClass: TComponentClass);
var
  E: TCustomModuleEntry;
begin
  if ComponentBaseClass = nil then Exit;
  E := TCustomModuleEntry.Create;
  E.BaseClass := ComponentBaseClass;
  E.Group := Group;
  if FCurModule <> 0 then E.Module := FCurModule
  else E.Module := FindClassHInstance(ComponentBaseClass);
  FCustomModules.Add(E);
end;

function TDesignHost.CustomModuleClass(const AClassName: string): TComponentClass;
var
  I: Integer;
begin
  for I := FCustomModules.Count - 1 downto 0 do
  begin
    Result := TCustomModuleEntry(FCustomModules[I]).BaseClass;
    if SameText(Result.ClassName, AClassName) then Exit;
  end;
  Result := nil;
end;

initialization
  DesignHost := TDesignHost.Create;

finalization
  { packages stay loaded until the process ends; see SdMain for the shutdown sequence }
  FreeAndNil(DesignHost);

end.
