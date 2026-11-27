{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaLegacyExperts;

{ D7 Studio's demo of Delphi 1-3's expert API: experts written as
  they were for Delphi 2 and 3 - classes of ExptIntf's TIExpert registered with
  RegisterLibraryExpert, the IDE reached through ExptIntf.ToolServices (ToolIntf, EditIntf).

    * Help | OTA Legacy: About (esStandard): its menu text counts how often the IDE asked for it -
      Delphi asks GetMenuText each time the Help menu drops down;
    * File | New | Other, page OTA Legacy: OTA Legacy Form (esForm): a form unit made by a
      TIModuleCreator (ToolServices.ModuleCreate);
    * File | New | Other, page Wizards (it names no page): OTA Legacy Project (esProject): a program
      made by a TIProjectCreatorEx (ToolServices.ProjectCreateEx), its options file included;
    * an add-in (esAddIn) that makes the menu OTA Legacy before Tools through the menu interfaces
      (GetMainMenu, FindMenuItem('ToolsMenu'), InsertItem) - Run self-test and Check services
      (OtaLegacyTest) - and logs the IDE's file and compile events (AddNotifierEx).

  Install: compile OtaLegacy.dpk (it requires designide), then Component | Install Packages | Add
  OtaLegacy.bpl. Removing the package takes it all away again (the IDE frees the experts; the add-in
  frees its menu items and removes its notifier). }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

interface

uses
  Windows, SysUtils, Classes, VirtIntf, ExptIntf, ToolIntf, EditIntf;

type
  { the add-in's log of the IDE's events (FileNotification, EventNotification): "file <code> <file>",
    "event <code> <Cancel as it came>" }
  TLegacyNotifier = class(TIAddInNotifier)
  public
    CancelCompile: Boolean;          // enBeforeCompile answers Cancel (the self-test's check)
    procedure FileNotification(NotifyCode: TFileNotification; const FileName: string;
      var Cancel: Boolean); override;
    procedure EventNotification(NotifyCode: TEventNotification; var Cancel: Boolean); override;
  end;

  { a module created by the demo: a form unit (TIModuleCreator) }
  TLegacyFormCreator = class(TIModuleCreator)
  private
    FFileName: string;
    FFormName: string;
  public
    constructor Create(const AFileName, AFormName: string);
    function Existing: Boolean; override;
    function GetAncestorName: string; override;
    function GetFileName: string; override;
    function GetFileSystem: string; override;
    function GetFormName: string; override;
    function NewModuleSource(const UnitIdent, FormIdent, AncestorIdent: string): string; override;
    procedure FormCreated(Form: TIFormInterface); override;
  end;

  { a program with its form and its options (TIProjectCreatorEx) }
  TLegacyProjectCreator = class(TIProjectCreatorEx)
  private
    FFileName: string;
    FUnitName: string;
  public
    DefaultModules: Integer;         // NewDefaultModule calls
    ResourceCalls: Integer;          // NewProjectResource calls
    constructor Create(const AFileName, AUnitName: string);
    function Existing: Boolean; override;
    function GetFileName: string; override;
    function GetFileSystem: string; override;
    function NewProjectSource(const ProjectName: string): string; override;
    procedure NewDefaultModule; override;
    procedure NewProjectResource(Module: TIModuleInterface); override;
    function GetOptionName: string; override;
    function NewOptionSource(const ProjectName: string): string; override;
  end;

const
  AboutID = 'D7Studio.OtaLegacy.About';
  FormExpertID = 'D7Studio.OtaLegacy.Form';
  ProjectExpertID = 'D7Studio.OtaLegacy.Project';
  AddInID = 'D7Studio.OtaLegacy.AddIn';

var
  LegacyEvents: TStringList;         // what the add-in's notifier heard
  MenuTextCalls: Integer;            // GetMenuText of the About expert
  AboutRuns: Integer;                // its Execute
  Notifier: TLegacyNotifier;         // the add-in's (nil while it is not registered)

procedure Register;

implementation

uses
  Dialogs, OtaLegacyTest;

type
  TLegacyAbout = class(TIExpert)
  public
    function GetName: string; override;
    function GetAuthor: string; override;
    function GetComment: string; override;
    function GetPage: string; override;
    function GetGlyph: HICON; override;
    function GetStyle: TExpertStyle; override;
    function GetState: TExpertState; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

  TLegacyFormExpert = class(TLegacyAbout)
  public
    function GetName: string; override;
    function GetComment: string; override;
    function GetPage: string; override;
    function GetStyle: TExpertStyle; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

  TLegacyProjectExpert = class(TLegacyAbout)
  public
    function GetName: string; override;
    function GetComment: string; override;
    function GetPage: string; override;
    function GetStyle: TExpertStyle; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

  { the add-in: its menu and its notifier live as long as the expert }
  TLegacyAddIn = class(TLegacyAbout)
  private
    FMenu: TIMenuItemIntf;
    FRun: TIMenuItemIntf;
    FServices: TIMenuItemIntf;
    procedure RunClick(Sender: TIMenuItemIntf);
    procedure ServicesClick(Sender: TIMenuItemIntf);
  public
    constructor Create;
    destructor Destroy; override;
    function GetName: string; override;
    function GetStyle: TExpertStyle; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

const
  FileCodes: array[TFileNotification] of string = ('fnFileOpening', 'fnFileOpened', 'fnFileClosing',
    'fnProjectOpening', 'fnProjectOpened', 'fnProjectClosing', 'fnAddedToProject',
    'fnRemovedFromProject', 'fnDefaultDesktopLoad', 'fnDefaultDesktopSave', 'fnProjectDesktopLoad',
    'fnProjectDesktopSave', 'fnPackageInstalled', 'fnPackageUninstalled');
  EventCodes: array[TEventNotification] of string = ('enBeforeCompile', 'enAfterCompile');

{ ---------------------------------------------------------------- the notifier }

procedure TLegacyNotifier.FileNotification(NotifyCode: TFileNotification; const FileName: string;
  var Cancel: Boolean);
begin
  LegacyEvents.Add('file ' + FileCodes[NotifyCode] + ' ' + FileName);
end;

procedure TLegacyNotifier.EventNotification(NotifyCode: TEventNotification; var Cancel: Boolean);
begin
  LegacyEvents.Add(Format('event %s %d', [EventCodes[NotifyCode], Ord(Cancel)]));
  if (NotifyCode = enBeforeCompile) and CancelCompile then Cancel := True;
end;

{ ---------------------------------------------------------------- creators }

constructor TLegacyFormCreator.Create(const AFileName, AFormName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FFormName := AFormName;
end;

function TLegacyFormCreator.Existing: Boolean;
begin
  Result := False;
end;

function TLegacyFormCreator.GetAncestorName: string;
begin
  Result := 'Form';
end;

function TLegacyFormCreator.GetFileName: string;
begin
  Result := FFileName;
end;

function TLegacyFormCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TLegacyFormCreator.GetFormName: string;
begin
  Result := FFormName;
end;

function TLegacyFormCreator.NewModuleSource(const UnitIdent, FormIdent, AncestorIdent: string): string;
begin
  Result :=
    'unit ' + UnitIdent + ';'#13#10#13#10 +
    'interface'#13#10#13#10 +
    'uses'#13#10 +
    '  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;'#13#10#13#10 +
    'type'#13#10 +
    '  T' + FormIdent + ' = class(T' + AncestorIdent + ')'#13#10 +
    '  private'#13#10 +
    '    { Private declarations }'#13#10 +
    '  public'#13#10 +
    '    { Public declarations }'#13#10 +
    '  end;'#13#10#13#10 +
    'var'#13#10 +
    '  ' + FormIdent + ': T' + FormIdent + ';'#13#10#13#10 +
    'implementation'#13#10#13#10 +
    '{$R *.dfm}'#13#10#13#10 +
    '{ made by the OTA Legacy demo''s module creator }'#13#10#13#10 +
    'end.'#13#10;
end;

{ Delphi 7 never calls it }
procedure TLegacyFormCreator.FormCreated(Form: TIFormInterface);
begin
end;

constructor TLegacyProjectCreator.Create(const AFileName, AUnitName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FUnitName := AUnitName;
end;

function TLegacyProjectCreator.Existing: Boolean;
begin
  Result := False;
end;

function TLegacyProjectCreator.GetFileName: string;
begin
  Result := FFileName;
end;

function TLegacyProjectCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TLegacyProjectCreator.NewProjectSource(const ProjectName: string): string;
begin
  Result :=
    'program ' + ProjectName + ';'#13#10#13#10 +
    'uses'#13#10 +
    '  Forms;'#13#10#13#10 +
    '{$R *.res}'#13#10#13#10 +
    'begin'#13#10 +
    '  Application.Initialize;'#13#10 +
    '  Application.Run;'#13#10 +
    'end.'#13#10;
end;

{ the project's form: a module of the demo's form creator, in the project }
procedure TLegacyProjectCreator.NewDefaultModule;
var
  C: TLegacyFormCreator;
  M: TIModuleInterface;
begin
  Inc(DefaultModules);
  if FUnitName = '' then Exit;
  C := TLegacyFormCreator.Create(ExtractFilePath(FFileName) + FUnitName + '.pas', 'LegacyForm');
  try
    M := ToolServices.ModuleCreate(C, [cmAddToProject, cmShowSource, cmShowForm]);
    if M <> nil then M.Free;
  finally
    C.Free;
  end;
end;

procedure TLegacyProjectCreator.NewProjectResource(Module: TIModuleInterface);
begin
  Inc(ResourceCalls);
end;

function TLegacyProjectCreator.GetOptionName: string;
begin
  Result := ChangeFileExt(FFileName, '.dof');
end;

{ run-time packages: a statically linked test program can be quarantined by a virus scanner }
function TLegacyProjectCreator.NewOptionSource(const ProjectName: string): string;
begin
  Result :=
    '[Directories]'#13#10 +
    'UsePackages=1'#13#10 +
    'Packages=rtl;vcl'#13#10;
end;

{ ---------------------------------------------------------------- the experts }

function TLegacyAbout.GetName: string;
begin
  Result := 'OTA Legacy About';
end;

function TLegacyAbout.GetAuthor: string;
begin
  Result := 'D7 Studio';
end;

function TLegacyAbout.GetComment: string;
begin
  Result := 'Delphi 1-3''s expert API in D7 Studio';
end;

function TLegacyAbout.GetPage: string;
begin
  Result := '';
end;

function TLegacyAbout.GetGlyph: HICON;
begin
  Result := 0;
end;

function TLegacyAbout.GetStyle: TExpertStyle;
begin
  Result := esStandard;
end;

function TLegacyAbout.GetState: TExpertState;
begin
  Result := [esEnabled];
end;

function TLegacyAbout.GetIDString: string;
begin
  Result := AboutID;
end;

{ asked each time the Help menu drops down: the count shows it }
function TLegacyAbout.GetMenuText: string;
begin
  Inc(MenuTextCalls);
  Result := Format('OTA Legacy: About (%d)', [MenuTextCalls]);
end;

procedure TLegacyAbout.Execute;
begin
  Inc(AboutRuns);
  if not LegacyUnattended then
    MessageDlg('OTA Legacy: experts of Delphi 1-3 (ExptIntf, ToolIntf, EditIntf) in D7 Studio.', mtInformation,
      [mbOK], 0);
end;

function TLegacyFormExpert.GetName: string;
begin
  Result := 'OTA Legacy Form';
end;

function TLegacyFormExpert.GetComment: string;
begin
  Result := 'A form unit made by a module creator of Delphi 1-3 (TIModuleCreator)';
end;

function TLegacyFormExpert.GetPage: string;
begin
  Result := 'OTA Legacy';
end;

function TLegacyFormExpert.GetStyle: TExpertStyle;
begin
  Result := esForm;
end;

function TLegacyFormExpert.GetIDString: string;
begin
  Result := FormExpertID;
end;

function TLegacyFormExpert.GetMenuText: string;
begin
  Result := '';
end;

procedure TLegacyFormExpert.Execute;
var
  UnitIdent, FileName: string;
  C: TLegacyFormCreator;
  M: TIModuleInterface;
begin
  if not ToolServices.GetNewModuleName(UnitIdent, FileName) then Exit;
  C := TLegacyFormCreator.Create(FileName, '');
  try
    M := ToolServices.ModuleCreate(C, [cmAddToProject, cmShowSource, cmShowForm, cmMarkModified]);
    if M <> nil then M.Free;
  finally
    C.Free;
  end;
end;

function TLegacyProjectExpert.GetName: string;
begin
  Result := 'OTA Legacy Project';
end;

function TLegacyProjectExpert.GetComment: string;
begin
  Result := 'A program made by a project creator of Delphi 1-3 (TIProjectCreatorEx)';
end;

{ no page: Delphi 7 puts it on Wizards }
function TLegacyProjectExpert.GetPage: string;
begin
  Result := '';
end;

function TLegacyProjectExpert.GetStyle: TExpertStyle;
begin
  Result := esProject;
end;

function TLegacyProjectExpert.GetIDString: string;
begin
  Result := ProjectExpertID;
end;

function TLegacyProjectExpert.GetMenuText: string;
begin
  Result := '';
end;

procedure TLegacyProjectExpert.Execute;
var
  UnitIdent, FileName: string;
  C: TLegacyProjectCreator;
  M: TIModuleInterface;
begin
  if not ToolServices.GetNewModuleName(UnitIdent, FileName) then Exit;
  C := TLegacyProjectCreator.Create(ExtractFilePath(FileName) + 'LegacyProject1.dpr', UnitIdent);
  try
    M := ToolServices.ProjectCreateEx(C, [cpApplication, cpCanShowSource]);
    if M <> nil then M.Free;
  finally
    C.Free;
  end;
end;

{ ---------------------------------------------------------------- the add-in }

constructor TLegacyAddIn.Create;
var
  Main: TIMainMenuIntf;
  Tools, Bar: TIMenuItemIntf;
begin
  inherited Create;
  Notifier := TLegacyNotifier.Create;
  ToolServices.AddNotifierEx(Notifier);
  { the menu before Tools, found by Delphi 7's name of it }
  Main := ToolServices.GetMainMenu;
  if Main = nil then Exit;
  try
    Tools := Main.FindMenuItem('ToolsMenu');
    if Tools = nil then Exit;
    try
      Bar := Tools.GetParent;
      if Bar = nil then Exit;
      try
        FMenu := Bar.InsertItem(Tools.GetIndex, 'OTA &Legacy', 'OtaLegacyMenu', 'Delphi 1-3''s expert API',
          0, 0, 0, [mfVisible, mfEnabled], nil);
      finally
        Bar.Free;
      end;
    finally
      Tools.Free;
    end;
    if FMenu = nil then Exit;
    FRun := FMenu.InsertItem(-1, 'Run self-test', 'OtaLegacyRun', 'Checks Delphi 1-3''s expert API', 0, 0, 0,
      [mfVisible, mfEnabled], RunClick);
    FServices := FMenu.InsertItem(-1, 'Check services', 'OtaLegacyServices',
      'Checks what File | New | Service Application and Service made', 0, 0, 0, [mfVisible, mfEnabled], ServicesClick);
  finally
    Main.Free;
  end;
end;

{ the items it made go with the interfaces InsertItem gave (the creator's Free), the notifier is
  removed: nothing of the package is called after it went }
destructor TLegacyAddIn.Destroy;
begin
  StopLegacyTest;
  if FServices <> nil then FServices.Free;
  if FRun <> nil then FRun.Free;
  if FMenu <> nil then FMenu.Free;
  if Notifier <> nil then
  begin
    ToolServices.RemoveNotifier(Notifier);
    Notifier.Free;
    Notifier := nil;
  end;
  inherited;
end;

procedure TLegacyAddIn.RunClick(Sender: TIMenuItemIntf);
begin
  RunLegacyTest(False);
end;

procedure TLegacyAddIn.ServicesClick(Sender: TIMenuItemIntf);
begin
  RunLegacyTest(True);
end;

function TLegacyAddIn.GetName: string;
begin
  Result := 'OTA Legacy Add-In';
end;

function TLegacyAddIn.GetStyle: TExpertStyle;
begin
  Result := esAddIn;
end;

function TLegacyAddIn.GetIDString: string;
begin
  Result := AddInID;
end;

function TLegacyAddIn.GetMenuText: string;
begin
  Result := '';
end;

{ an add-in is never executed (the IDE's rule) }
procedure TLegacyAddIn.Execute;
begin
  Inc(AboutRuns, 1000);
end;

procedure Register;
begin
  RegisterLibraryExpert(TLegacyAbout.Create);
  RegisterLibraryExpert(TLegacyFormExpert.Create);
  RegisterLibraryExpert(TLegacyProjectExpert.Create);
  RegisterLibraryExpert(TLegacyAddIn.Create);
end;

initialization
  LegacyEvents := TStringList.Create;
finalization
  FreeAndNil(LegacyEvents);
end.
