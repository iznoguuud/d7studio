{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

library OtaDemoDll;

{ D7 Studio's Open Tools API demo: an IDE expert in a DLL. The IDE calls its entry point
  INITWIZARD0001 (ToolsAPI.WizardEntryPoint) with BorlandIDEServices; the expert registers an
  IOTAMenuWizard (Help | OTA Demo DLL: Hello) and is told when the IDE ends (Terminate).

  Build it with run-time packages (rtl, vcl, designide): it then shares the IDE's memory manager,
  its VCL and its BorlandIDEServices. The IDEs build it so from OtaDemoDll.dof; dcc32 alone does
  not read a .dof (make -f OtaDemo.bpg, a command line): dcc32 -LUrtl;vcl;designide OtaDemoDll.dpr.
  Built without them, the DLL does not register (InitWizard). Name it in D7 Studio's settings,
  [Experts] OtaDemoDll=<its path>, or as Delphi 7 does in the registry: a string value under
  HKEY_CURRENT_USER\Software\D7Studio\Experts. }

uses
  Windows, SysUtils, Classes, Forms, Menus, ToolsAPI;

type
  TDllWizard = class(TNotifierObject, IOTANotifier, IOTAWizard, IOTAMenuWizard)
  public
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    function GetMenuText: string;
  end;

function TDllWizard.GetIDString: string;
begin
  Result := 'D7Studio.OtaDemoDll';
end;

function TDllWizard.GetName: string;
begin
  Result := 'OTA Demo DLL';
end;

function TDllWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

function TDllWizard.GetMenuText: string;
begin
  Result := 'OTA Demo DLL: &Hello';
end;

{ a line in the Build group of the Messages view: the DLL reaches the IDE's services and its
  main window like a package does - the main menu's items by their names, Delphi 7's (FileMenu,
  EditMenu ... ViewsMenu ... WindowsMenu, HelpMenu) }
procedure TDllWizard.Execute;
var
  Msgs: IOTAMessageServices;
  NTA: INTAServices;
  Mods: IOTAModuleServices;
  Names: string;
  I: Integer;
begin
  Msgs := BorlandIDEServices as IOTAMessageServices;
  NTA := BorlandIDEServices as INTAServices;
  Mods := BorlandIDEServices as IOTAModuleServices;
  Names := '';
  for I := 0 to NTA.MainMenu.Items.Count - 1 do
  begin
    if Names <> '' then Names := Names + ', ';
    Names := Names + NTA.MainMenu.Items[I].Name;
  end;
  Msgs.AddTitleMessage(Format('Hello from the DLL expert %s: the main menu %s; %d modules open',
    [ExtractFileName(GetModuleName(HInstance)), Names, Mods.ModuleCount]));
  Msgs.ShowMessageView(Msgs.GetGroup('Build'));
end;

procedure DoneWizard;
begin
  { nothing to release: the IDE releases the wizard it was given }
end;

{ a DLL linked without run-time packages has a TObject, a memory manager and a VCL of its own:
  its strings and objects cannot go to the IDE, and it refuses to register }
function InitWizard(const Services: IBorlandIDEServices; RegisterProc: TWizardRegisterProc;
  var Terminate: TWizardTerminateProc): Boolean; stdcall;
begin
  Result := FindClassHInstance(TObject) <> HInstance;
  if not Result then Exit;
  BorlandIDEServices := Services;
  Terminate := DoneWizard;
  Result := RegisterProc(TDllWizard.Create);
end;

exports
  InitWizard name WizardEntryPoint;

begin
end.
