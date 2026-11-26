{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiWizard;

{ The AI harness as an IDE expert (a design-time package; install AiHarness.bpl with Component |
  Install Packages). It adds View | AI Assistant, after Window List (Delphi 7's item
  ViewWindowListItem in ViewsMenu, found by name as experts find their places), and the dockable
  window of TAiChatWindow, registered with the IDE's desktop. With the environment variable
  AIHARNESS_SELFTEST_LOG set it also adds Tools | AI Harness Self-Test (AiSelfTest). Removing
  the package takes all of it away (the destructor). }

interface

procedure Register;

implementation

uses
  Windows, SysUtils, Classes, Menus, ActnList, ToolsAPI, AiUI, AiChatWin, AiHost, AiSelfTest;

const
  ActionCategory = 'AI Harness';

type
  TAiExpert = class(TNotifierObject, IOTAWizard)
  private
    FShowAction: TAction;
    FShowItem: TMenuItem;
    FTestAction: TAction;
    FTestItem: TMenuItem;
    function NewAction(const ACaption, AName: string; Handler: TNotifyEvent): TAction;
    procedure ShowWindow(Sender: TObject);
    procedure SelfTest(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

constructor TAiExpert.Create;
var
  NTA: INTAServices;
  After, Parent: TMenuItem;
begin
  inherited Create;
  NTA := BorlandIDEServices as INTAServices;
  RegisterChatWindow;
  FShowAction := NewAction('AI &Assistant', 'AiHarnessShowCommand', ShowWindow);
  FShowItem := TMenuItem.Create(nil);
  FShowItem.Name := 'AiHarnessShowItem';
  FShowItem.Action := FShowAction;
  After := KitFindMenuItem(NTA.MainMenu.Items, 'ViewWindowListItem');
  if After <> nil then After.Parent.Insert(After.MenuIndex + 1, FShowItem)
  else
  begin
    Parent := KitFindMenuItem(NTA.MainMenu.Items, 'ViewsMenu');
    if Parent <> nil then Parent.Add(FShowItem)
    else NTA.MainMenu.Items.Add(FShowItem);
  end;
  if GetEnvironmentVariable('AIHARNESS_SELFTEST_LOG') <> '' then
  begin
    FTestAction := NewAction('AI Harness Self-Test', 'AiHarnessSelfTestCommand', SelfTest);
    FTestItem := TMenuItem.Create(nil);
    FTestItem.Name := 'AiHarnessSelfTestItem';
    FTestItem.Action := FTestAction;
    Parent := KitFindMenuItem(NTA.MainMenu.Items, 'ToolsMenu');
    if Parent <> nil then Parent.Add(FTestItem) else NTA.MainMenu.Items.Add(FTestItem);
  end;
end;

destructor TAiExpert.Destroy;
begin
  StopSelfTest;
  FTestItem.Free;
  FTestAction.Free;
  FShowItem.Free;
  FShowAction.Free;
  UnregisterChatWindow;
  inherited;
end;

function TAiExpert.NewAction(const ACaption, AName: string; Handler: TNotifyEvent): TAction;
begin
  Result := TAction.Create(nil);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Category := ActionCategory;
  Result.OnExecute := Handler;
  Result.ActionList := (BorlandIDEServices as INTAServices).ActionList;
end;

procedure TAiExpert.ShowWindow(Sender: TObject);
begin
  ShowChatWindow;
end;

procedure TAiExpert.SelfTest(Sender: TObject);
begin
  StartSelfTest;
end;

function TAiExpert.GetIDString: string;
begin
  Result := 'D7Studio.AiHarness';
end;

function TAiExpert.GetName: string;
begin
  Result := 'AI Harness';
end;

function TAiExpert.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TAiExpert.Execute;
begin
  ShowChatWindow;
end;

procedure Register;
begin
  RegisterPackageWizard(TAiExpert.Create);
end;

end.
