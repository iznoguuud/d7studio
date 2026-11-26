{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesignEnv;

{ D7 Studio - the IDE side of Borland's component designer framework.

  Borland's design-time windows - the action list editor, the collection editor, the menu
  designer and everything else derived from DesignWindows.TDesignWindow - do not only talk to
  the IDesigner of the form. They ask ComponentDesigner.ActiveDesigner for the designer of the
  framework (IComponentDesigner) and that one for its "environment", the IDE:

      ActiveDesigner.Environment.GetMainWindowSize     where to put a new window
      ActiveDesigner.Environment.GetBaseRegKey         where to keep window settings
      ActiveDesigner.Environment.ModalEdit(Key, Wnd)   "type this into the Object Inspector"
      ActiveDesigner.SetSelection(Designer, Wnd, List) select components of the form

  TSdDesignEnvironment is that environment (IDesignEnvironment). The unit ComponentDesigner ships
  without source; the declaration of the interface, as the compiled unit has it, is repeated in
  the comments below. The compiler checks this
  class against the compiled unit, so a wrong signature cannot go unnoticed.

  The environment itself knows nothing about the main form: the shell plugs in the Host.

  What Borland's property editors and packages ask of the Open Tools API (BorlandIDEServices: the
  string list editor's IOTAModuleServices, dclnet70's IOTAServices ...) is SdOtaServices'. }

interface

uses
  SysUtils, Classes, Types, Controls, Forms, IniFiles, DesignIntf, Events,
  ComponentDesigner;

type
  { what the shell (main form) does for the design-time windows }
  ISdDesignHost = interface
    ['{6B5F0E0A-52C1-4E0B-9B38-0A7D3C1E5A11}']
    function MainWindowRect: TRect;                 // screen rectangle new windows are placed against
    function WorkspaceOrigin: TPoint;
    procedure FocusInspector(Key: Char; const PropName: string);
    procedure SelectionChanged;                     // a design window changed the selection
    procedure ComponentsChanged;                    // ... or added / deleted / renamed something
    function FindGlobalComponent(const Name: string): TComponent;    // "Form1.Button1"
    procedure OpenRootByName(const RootName: string; Show: Boolean);
    procedure DesignDialog(Dialog: TDesignDialog);
  end;

  TSdDesignEnvironment = class(TInterfacedObject, IDesignEnvironment)
  private
    FOptions: TMemIniFile;
    FInstalled: TEvent;
    FUninstalling: TEvent;
    FBaseName: string;
    FRegKey: string;
  public
    Host: ISdDesignHost;
    constructor Create(const ABaseName, ARegKey: string);
    destructor Destroy; override;
    property PackagesInstalled: TEvent read FInstalled;
    property PackagesUninstalling: TEvent read FUninstalling;
    { IDesignEnvironment, in the order of its declaration }
    procedure ActiveRootModified;
    procedure ComponentRenamed(const CurName, NewName: string);
    function FindComponent(const Name: string): TComponent;
    procedure ExecDesignDialog(DesignDialog: TDesignDialog);
    procedure RootActivated;
    function GetPathAndBaseExeName: string;
    function GetPrivateDirectory: string;
    function GetBaseRegKey: string;
    function GetIDEOptions: TCustomIniFile;
    function GetToolSelected: Boolean;
    function GetCurCompClass: IPaletteItem;
    function GetPaletteItem(ComponentClass: TComponentClass): IPaletteItem;
    function GetCurTime: Integer;
    procedure GetDesignerOptions(var Options: TDesignerOptions);
    function GetMainWindowSize: TRect;
    function GetWorkspaceOrigin: TPoint;
    function GetPackagesEvInstalled: TEvent;
    function GetPackagesEvUninstalling: TEvent;
    procedure ModalEdit(EditKey: Char; const ReturnWindow: IActivatable);
    procedure OpenRoot(const RootName: string; Show: Boolean);
    procedure ResetCompClass;
    procedure SelectionChanged;
    procedure ShowClassHelp(const ClassName: string);
    procedure ShowContextHelp(const HelpFile: string; Command, Data: Integer);
    procedure SelectItemName(const PropertyName: string);
    function CreateBackupFile: Boolean;
    procedure RequestTemplate(const CompName: string; Stream: TStream; Dependencies: TStrings);
    procedure ItemDeleted(const ADesigner: IDesigner; Item: TPersistent);
  end;

  { The designer of the framework, the object ComponentDesigner.ActiveDesigner returns. Borland's
    TComponentDesigner brings most of IComponentDesigner; what it leaves to the framework (VCL,
    CLX) is added here. D7 Studio's forms are not "roots" of this designer - they are designed
    by TFormDesigner - so everything about roots is empty; the designer exists for the design
    windows, which need the environment and SetSelection. }
  TSdComponentDesigner = class(TComponentDesigner, IComponentDesigner, IInternalComponentDesigner)
  public
    { IComponentDesigner }
    function CreateRoot(const AModule: IDesignerModule; const AFileName: string; Existing: Boolean;
      const ARootName, AAncestor, AFileSystem: string): IRoot;
    function CreateFromStream(const AModule: IDesignerModule; const AFileName, AFileSystem: string;
      const Stream: IDatedStream): IRoot;
    function CreateNewRoot(const AModule: IDesignerModule; const AFileName: string;
      const Creator: IInterface): IRoot;
    function Active: Boolean;
    function GetEnvironment: IDesignEnvironment;
    function GetExtension: string;
    function GetActiveClassGroup: TPersistentClass;
    procedure SetSelection(const Designer: IDesigner; const DesignWindow: IDesignWindow;
      const ComponentList: IDesignerSelections);
    { IInternalComponentDesigner }
    function FileSystemFileOpen(const FileSystem, FileName: string; Mode: Integer): TStream;
    function FileSystemFileAge(const FileSystem, FileName: string): Integer;
    function FileSystemFileExists(const FileSystem, FileName: string): Boolean;
    function FileSystemRenameFile(const FileSystem, OldName, NewName: string): Boolean;
    function FileSystemGetTempFileName(const FileSystem, FileName: string): string;
    function FileSystemGetBackupName(const FileSystem, FileName: string): string;
    function FileSystemIsReadOnly(const FileSystem, FileName: string): Boolean;
    procedure FileSystemDeleteFile(const FileSystem, FileName: string);
    procedure FileSystemSetDate(const FileSystem: string; Stream: TStream; Age: Integer);
    function ValidBaseClass(AClass: TComponentClass): Boolean; override;
  end;

var
  { trace of the calls Borland code makes into the environment (experiments, diagnosis) }
  EnvTrace: procedure(const S: string);
  DesignEnvironment: TSdDesignEnvironment;      // the installed environment (nil before)

{ Creates the environment and the component designer and makes the designer the active one:
  from then on ComponentDesigner.ActiveDesigner answers. BaseName: path and base name of the
  designers' own files (<BaseName>.dmt); RegKey: registry key for design window settings. }
function InstallComponentDesigner(const BaseName, RegKey: string): TSdDesignEnvironment;
procedure UninstallComponentDesigner;

implementation

uses
  Graphics, SdDesignHost, SdUI;

type
  { A palette item as Borland's code and experts ask for one (GetPaletteItem): its class, the
    component made from it, and its picture as on Delphi's palette - the 28 x 28 tile with the
    class's 24 x 24 image (CompBar paints its list with it) }
  TSdPaletteItem = class(TInterfacedObject, IPaletteItem, IComponentPaletteItem, IPalettePaint)
  private
    FClass: TComponentClass;
  public
    constructor Create(AClass: TComponentClass);
    function CreateComponent(const Owner, Parent: TComponent; const Module: IDesignerModule;
      const ARect: TRect): TComponent;
    function GetComponentClass: TComponentClass;
    procedure Paint(Canvas: TCanvas; X, Y: Integer; Style: TPaintItemStyle);
  end;

constructor TSdPaletteItem.Create(AClass: TComponentClass);
begin
  inherited Create;
  FClass := AClass;
end;

function TSdPaletteItem.CreateComponent(const Owner, Parent: TComponent; const Module: IDesignerModule;
  const ARect: TRect): TComponent;
begin
  Result := FClass.Create(Owner);
  if (Result is TControl) and (Parent is TWinControl) then
  begin
    TControl(Result).Parent := TWinControl(Parent);
    if not IsRectEmpty(ARect) then TControl(Result).BoundsRect := ARect;
  end;
end;

function TSdPaletteItem.GetComponentClass: TComponentClass;
begin
  Result := FClass;
end;

procedure TSdPaletteItem.Paint(Canvas: TCanvas; X, Y: Integer; Style: TPaintItemStyle);
begin
  UIDrawComponentTile(Canvas.Handle, Rect(X, Y, X + 28, Y + 28), DesignHost.ComponentBitmap(FClass));
end;

var
  EnvRef: IDesignEnvironment;
  DesignerRef: IInternalComponentDesigner;

procedure Trace(const S: string);
begin
  if Assigned(EnvTrace) then EnvTrace(S);
end;

constructor TSdDesignEnvironment.Create(const ABaseName, ARegKey: string);
begin
  inherited Create;
  FBaseName := ABaseName;
  FRegKey := ARegKey;
  FOptions := TMemIniFile.Create('');
  FInstalled := TEvent.Create;
  FUninstalling := TEvent.Create;
end;

destructor TSdDesignEnvironment.Destroy;
begin
  FUninstalling.Free;
  FInstalled.Free;
  FOptions.Free;
  inherited;
end;

procedure TSdDesignEnvironment.ActiveRootModified;
begin
  Trace('ActiveRootModified');
  if Host <> nil then Host.ComponentsChanged;
end;

procedure TSdDesignEnvironment.ComponentRenamed(const CurName, NewName: string);
begin
  Trace('ComponentRenamed ' + CurName + ' -> ' + NewName);
  if Host <> nil then Host.ComponentsChanged;
end;

function TSdDesignEnvironment.FindComponent(const Name: string): TComponent;
begin
  Trace('FindComponent ' + Name);
  if Host <> nil then Result := Host.FindGlobalComponent(Name) else Result := nil;
end;

procedure TSdDesignEnvironment.ExecDesignDialog(DesignDialog: TDesignDialog);
begin
  Trace('ExecDesignDialog');
  if Host <> nil then Host.DesignDialog(DesignDialog);
end;

procedure TSdDesignEnvironment.RootActivated;
begin
  Trace('RootActivated');
end;

{ Path and name, without extension, of the files Borland's designers keep next to the IDE:
  the menu templates are <this>.dmt. }
function TSdDesignEnvironment.GetPathAndBaseExeName: string;
begin
  Trace('GetPathAndBaseExeName');
  Result := FBaseName;
end;

function TSdDesignEnvironment.GetPrivateDirectory: string;
begin
  Trace('GetPrivateDirectory');
  Result := '';
end;

{ Registry key (HKEY_CURRENT_USER) under which design-time windows store their state. It is
  D7 Studio's own key, never Delphi's: the user's Delphi settings stay untouched. }
function TSdDesignEnvironment.GetBaseRegKey: string;
begin
  Trace('GetBaseRegKey');
  Result := FRegKey;
end;

function TSdDesignEnvironment.GetIDEOptions: TCustomIniFile;
begin
  Trace('GetIDEOptions');
  Result := FOptions;
end;

{ no component is ever chosen for a click on the form: the Components view adds components by
  Enter, a double click or a drag }
function TSdDesignEnvironment.GetToolSelected: Boolean;
begin
  Result := False;
end;

function TSdDesignEnvironment.GetCurCompClass: IPaletteItem;
begin
  Trace('GetCurCompClass');
  Result := nil;
end;

function TSdDesignEnvironment.GetPaletteItem(ComponentClass: TComponentClass): IPaletteItem;
begin
  Trace('GetPaletteItem');
  if ComponentClass = nil then Result := nil
  else Result := TSdPaletteItem.Create(ComponentClass);
end;

function TSdDesignEnvironment.GetCurTime: Integer;
begin
  Result := DateTimeToFileDate(Now);
end;

procedure TSdDesignEnvironment.GetDesignerOptions(var Options: TDesignerOptions);
begin
  Trace('GetDesignerOptions');
  FillChar(Options, SizeOf(Options), 0);
  Options.DisplayGrid := True;
  Options.SnapToGrid := True;
  Options.GridSizeX := 8;
  Options.GridSizeY := 8;
  Options.ShowComponentCaptions := False;
  Options.ShowDesignerHints := True;
  Options.DFMFormat := True;
  Options.ShowNonVisualComponents := True;
  Options.ShowExtendedControlHints := False;
end;

{ Delphi's main window is the bar at the top of the screen and a new design window opens 2 px
  below it, 200 px from the left. The host answers with the rectangle that plays that role. }
function TSdDesignEnvironment.GetMainWindowSize: TRect;
begin
  Trace('GetMainWindowSize');
  if Host <> nil then Result := Host.MainWindowRect
  else Result := Rect(0, 0, Screen.Width, 100);
end;

function TSdDesignEnvironment.GetWorkspaceOrigin: TPoint;
begin
  Trace('GetWorkspaceOrigin');
  if Host <> nil then Result := Host.WorkspaceOrigin else Result := Point(0, 0);
end;

function TSdDesignEnvironment.GetPackagesEvInstalled: TEvent;
begin
  Trace('GetPackagesEvInstalled');
  Result := FInstalled;
end;

function TSdDesignEnvironment.GetPackagesEvUninstalling: TEvent;
begin
  Trace('GetPackagesEvUninstalling');
  Result := FUninstalling;
end;

{ A design window received a key that belongs to the Object Inspector (the user started to
  type a property value while an item of the window was selected). }
procedure TSdDesignEnvironment.ModalEdit(EditKey: Char; const ReturnWindow: IActivatable);
begin
  Trace('ModalEdit');
  if Host <> nil then Host.FocusInspector(EditKey, '');
end;

procedure TSdDesignEnvironment.OpenRoot(const RootName: string; Show: Boolean);
begin
  Trace('OpenRoot ' + RootName);
  if Host <> nil then Host.OpenRootByName(RootName, Show);
end;

procedure TSdDesignEnvironment.ResetCompClass;
begin
  Trace('ResetCompClass');
end;

procedure TSdDesignEnvironment.SelectionChanged;
begin
  Trace('SelectionChanged');
  if Host <> nil then Host.SelectionChanged;
end;

procedure TSdDesignEnvironment.ShowClassHelp(const ClassName: string);
begin
  Trace('ShowClassHelp ' + ClassName);
end;

procedure TSdDesignEnvironment.ShowContextHelp(const HelpFile: string; Command, Data: Integer);
begin
  Trace('ShowContextHelp ' + HelpFile);
end;

procedure TSdDesignEnvironment.SelectItemName(const PropertyName: string);
begin
  Trace('SelectItemName ' + PropertyName);
  if Host <> nil then Host.FocusInspector(#0, PropertyName);
end;

function TSdDesignEnvironment.CreateBackupFile: Boolean;
begin
  Result := False;
end;

procedure TSdDesignEnvironment.RequestTemplate(const CompName: string; Stream: TStream; Dependencies: TStrings);
begin
  Trace('RequestTemplate ' + CompName);
end;

procedure TSdDesignEnvironment.ItemDeleted(const ADesigner: IDesigner; Item: TPersistent);
begin
  Trace('ItemDeleted');
  if Host <> nil then Host.ComponentsChanged;
end;

{ ---------------------------------------------------------------- TSdComponentDesigner }

function TSdComponentDesigner.CreateRoot(const AModule: IDesignerModule; const AFileName: string;
  Existing: Boolean; const ARootName, AAncestor, AFileSystem: string): IRoot;
begin
  Trace('designer.CreateRoot ' + AFileName);
  Result := nil;
end;

function TSdComponentDesigner.CreateFromStream(const AModule: IDesignerModule;
  const AFileName, AFileSystem: string; const Stream: IDatedStream): IRoot;
begin
  Trace('designer.CreateFromStream ' + AFileName);
  Result := nil;
end;

function TSdComponentDesigner.CreateNewRoot(const AModule: IDesignerModule; const AFileName: string;
  const Creator: IInterface): IRoot;
begin
  Trace('designer.CreateNewRoot ' + AFileName);
  Result := nil;
end;

function TSdComponentDesigner.Active: Boolean;
begin
  Result := True;
end;

function TSdComponentDesigner.GetEnvironment: IDesignEnvironment;
begin
  Result := Environment;
end;

function TSdComponentDesigner.GetExtension: string;
begin
  Result := 'dfm';
end;

function TSdComponentDesigner.GetActiveClassGroup: TPersistentClass;
begin
  Result := TControl;
end;

{ A design window selects components of the form it edits (the actions of an action list, the
  items of a menu, ...): the form's own designer does it, and tells the Object Inspector. }
procedure TSdComponentDesigner.SetSelection(const Designer: IDesigner; const DesignWindow: IDesignWindow;
  const ComponentList: IDesignerSelections);
begin
  Trace('designer.SetSelection');
  if Designer <> nil then Designer.SetSelections(ComponentList);
end;

function TSdComponentDesigner.FileSystemFileOpen(const FileSystem, FileName: string; Mode: Integer): TStream;
begin
  Result := TFileStream.Create(FileName, Mode);
end;

function TSdComponentDesigner.FileSystemFileAge(const FileSystem, FileName: string): Integer;
begin
  Result := FileAge(FileName);
end;

function TSdComponentDesigner.FileSystemFileExists(const FileSystem, FileName: string): Boolean;
begin
  Result := FileExists(FileName);
end;

function TSdComponentDesigner.FileSystemRenameFile(const FileSystem, OldName, NewName: string): Boolean;
begin
  Result := RenameFile(OldName, NewName);
end;

function TSdComponentDesigner.FileSystemGetTempFileName(const FileSystem, FileName: string): string;
begin
  Result := ChangeFileExt(FileName, '.$$$');
end;

function TSdComponentDesigner.FileSystemGetBackupName(const FileSystem, FileName: string): string;
begin
  Result := ChangeFileExt(FileName, '.~' + Copy(ExtractFileExt(FileName), 2, MaxInt));
end;

function TSdComponentDesigner.FileSystemIsReadOnly(const FileSystem, FileName: string): Boolean;
begin
  Result := FileExists(FileName) and FileIsReadOnly(FileName);
end;

procedure TSdComponentDesigner.FileSystemDeleteFile(const FileSystem, FileName: string);
begin
  DeleteFile(FileName);
end;

procedure TSdComponentDesigner.FileSystemSetDate(const FileSystem: string; Stream: TStream; Age: Integer);
begin
  if Stream is THandleStream then FileSetDate(THandleStream(Stream).Handle, Age);
end;

function TSdComponentDesigner.ValidBaseClass(AClass: TComponentClass): Boolean;
begin
  Result := (AClass <> nil) and (AClass.InheritsFrom(TCustomForm) or AClass.InheritsFrom(TDataModule) or
    AClass.InheritsFrom(TCustomFrame));
end;

{ ---------------------------------------------------------------- installation }

function InstallComponentDesigner(const BaseName, RegKey: string): TSdDesignEnvironment;
var
  D: TSdComponentDesigner;
  List: IInternalComponentDesigners;
begin
  if DesignEnvironment = nil then
  begin
    DesignEnvironment := TSdDesignEnvironment.Create(BaseName, RegKey);
    EnvRef := DesignEnvironment;
    { designer packages that registered an initialisation get the environment as well }
    InitializeDesigners(EnvRef);
    D := TSdComponentDesigner.Create;
    DesignerRef := D;
    D.Environment := EnvRef;
    if Supports(Designers, IInternalComponentDesigners, List) then
    begin
      List.AddDesigner(DesignerRef);
      List.ActivateDesigner(DesignerRef);
    end;
  end;
  Result := DesignEnvironment;
end;

procedure UninstallComponentDesigner;
var
  List: IInternalComponentDesigners;
begin
  if DesignerRef <> nil then
  begin
    try
      if Supports(Designers, IInternalComponentDesigners, List) then List.RemoveDesigner(DesignerRef);
    except
    end;
    List := nil;
    DesignerRef := nil;
  end;
  if DesignEnvironment <> nil then DesignEnvironment.Host := nil;
  DesignEnvironment := nil;
  EnvRef := nil;
end;

end.