{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitWizard;

{ The Git expert (a design-time package; install GitExpert.bpl with Component | Install Packages).
  It adds View | Git and View | Git History after Window List (Delphi 7's item ViewWindowListItem in
  ViewsMenu, found by name as experts find their places), the dockable views of GitChanges,
  GitHistory and GitDiff, registered with the IDE's desktop, and a Git submenu at the end of
  the code editor's local menu (EditorLocalMenu of every edit window, put there again when a window
  appears - a file opened, View | New Edit Window): Diff with HEAD and Blame of the editor's text -
  also when it is not saved -, and the file's History. Its IDE notifier also tells the host
  (GitHost) of projects opened, closed or made active. With the environment variable
  GITEXPERT_SELFTEST_LOG set it also adds Tools | Git Self-Test (GitSelfTest). Removing the package
  takes all of it away (the destructor). }

interface

procedure Register;

implementation

uses
  Windows, SysUtils, Classes, Forms, Menus, ActnList, ExtCtrls, ToolsAPI, GitUI, GitHost, GitIde, GitChanges, GitHistory,
  GitDiff, GitSelfTest;

const
  ActionCategory = 'Git';
  EditorMenuName = 'GitEditorMenu';
  EditorSepName = 'GitEditorSep';
  WindowCheck = 1000;          // ms between the looks for new edit windows

type
  TGitExpert = class;

  { the IDE's file notifications: a file opened may have brought an edit window, whose local menu
    gets the Git submenu; a project opened, closed or made active moves the host's repository }
  TGitIdeNotifier = class(TNotifierObject, IOTAIDENotifier)
  private
    Expert: TGitExpert;
  public
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
  end;

  TGitExpert = class(TNotifierObject, IOTAWizard)
  private
    FActions: TList;            // the expert's actions in the IDE's action list
    FItems: TList;              // its items in the IDE's main menu
    FEdDiff, FEdHistory, FEdBlame: TAction;
    FNotifier: Integer;
    FWindowTimer: TTimer;       // new edit windows (no notification tells of them)
    FFormCount: Integer;
    function NewAction(const ACaption, AName: string; Handler, Update: TNotifyEvent): TAction;
    procedure AddMenuItem(A: TAction; const AName: string; Parent, After: TMenuItem);
    procedure ShowView(Sender: TObject);
    procedure ShowHistory(Sender: TObject);
    procedure SelfTest(Sender: TObject);
    procedure EditorUpdate(Sender: TObject);
    procedure EditorDiff(Sender: TObject);
    procedure EditorHistory(Sender: TObject);
    procedure EditorBlame(Sender: TObject);
    procedure WindowTimerTick(Sender: TObject);
    { the code editor's file: its name in the IDE and its repository path (UTF-8); False, after
      saying why, when it is not in the active project's repository }
    function EditorFile(out FileName, Path: string): Boolean;
    procedure RemoveEditorMenus;
  public
    constructor Create;
    destructor Destroy; override;
    { the Git submenu in the local menu of every edit window that has none }
    procedure InstallEditorMenus;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

{ ---------------------------------------------------------------- TGitIdeNotifier }

procedure TGitIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
begin
  if Expert = nil then Exit;
  if NotifyCode = ofnFileOpened then Expert.InstallEditorMenus;
  { the host is there once a view or a command of the editor asked for it }
  if (NotifyCode in [ofnActiveProjectChanged, ofnFileOpened, ofnFileClosing]) and (GitHostIfAny <> nil) then
    GitHostIfAny.ProjectChanged;
end;

procedure TGitIdeNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
end;

procedure TGitIdeNotifier.AfterCompile(Succeeded: Boolean);
begin
end;

{ ---------------------------------------------------------------- TGitExpert }

constructor TGitExpert.Create;
var
  NTA: INTAServices;
  After, Views, Tools: TMenuItem;
  N: TGitIdeNotifier;
  A: TAction;
begin
  inherited Create;
  FActions := TList.Create;
  FItems := TList.Create;
  RegisterGitView;
  RegisterGitHistoryView;
  RegisterGitDiffView;
  NTA := BorlandIDEServices as INTAServices;
  After := KitFindMenuItem(NTA.MainMenu.Items, 'ViewWindowListItem');
  Views := KitFindMenuItem(NTA.MainMenu.Items, 'ViewsMenu');
  A := NewAction('&Git', 'GitShowCommand', ShowView, nil);
  AddMenuItem(A, 'GitShowItem', Views, After);
  A := NewAction('Git &History', 'GitHistoryCommand', ShowHistory, nil);
  AddMenuItem(A, 'GitHistoryItem', Views, TMenuItem(FItems[FItems.Count - 1]));
  FEdDiff := NewAction('&Diff with HEAD', 'GitEditorDiffCommand', EditorDiff, EditorUpdate);
  FEdHistory := NewAction('&History', 'GitEditorHistoryCommand', EditorHistory, EditorUpdate);
  FEdBlame := NewAction('&Blame', 'GitEditorBlameCommand', EditorBlame, EditorUpdate);
  if GetEnvironmentVariable('GITEXPERT_SELFTEST_LOG') <> '' then
  begin
    A := NewAction('Git Self-Test', 'GitSelfTestCommand', SelfTest, nil);
    Tools := KitFindMenuItem(NTA.MainMenu.Items, 'ToolsMenu');
    AddMenuItem(A, 'GitSelfTestItem', Tools, nil);
  end;
  N := TGitIdeNotifier.Create;
  N.Expert := Self;
  FNotifier := (BorlandIDEServices as IOTAServices).AddNotifier(N);
  InstallEditorMenus;
  FWindowTimer := TTimer.Create(nil);
  FWindowTimer.Interval := WindowCheck;
  FWindowTimer.OnTimer := WindowTimerTick;
end;

destructor TGitExpert.Destroy;
var
  I: Integer;
begin
  FreeAndNil(FWindowTimer);
  StopGitSelfTest;
  if FNotifier >= 0 then (BorlandIDEServices as IOTAServices).RemoveNotifier(FNotifier);
  RemoveEditorMenus;
  for I := FItems.Count - 1 downto 0 do TObject(FItems[I]).Free;
  FItems.Free;
  for I := FActions.Count - 1 downto 0 do TObject(FActions[I]).Free;
  FActions.Free;
  UnregisterGitDiffView;
  UnregisterGitHistoryView;
  UnregisterGitView;
  FreeGitHost;
  inherited;
end;

function TGitExpert.NewAction(const ACaption, AName: string; Handler, Update: TNotifyEvent): TAction;
begin
  Result := TAction.Create(nil);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Category := ActionCategory;
  Result.OnExecute := Handler;
  Result.OnUpdate := Update;
  Result.ActionList := (BorlandIDEServices as INTAServices).ActionList;
  FActions.Add(Result);
end;

{ an item of A after After (else at the end of Parent, else of the menu bar) }
procedure TGitExpert.AddMenuItem(A: TAction; const AName: string; Parent, After: TMenuItem);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(nil);
  Item.Name := AName;
  Item.Action := A;
  if After <> nil then After.Parent.Insert(After.MenuIndex + 1, Item)
  else if Parent <> nil then Parent.Add(Item)
  else (BorlandIDEServices as INTAServices).MainMenu.Items.Add(Item);
  FItems.Add(Item);
end;

procedure TGitExpert.InstallEditorMenus;
var
  I: Integer;
  M: TComponent;
  Menu: TPopupMenu;
  Sep, Sub, Item: TMenuItem;

  procedure AddItem(A: TAction);
  begin
    Item := TMenuItem.Create(Sub);
    Item.Action := A;
    Sub.Add(Item);
  end;

begin
  FFormCount := Screen.FormCount;
  for I := 0 to Screen.FormCount - 1 do
  begin
    M := Screen.Forms[I].FindComponent('EditorLocalMenu');
    if not (M is TPopupMenu) then Continue;
    Menu := TPopupMenu(M);
    if Menu.FindComponent(EditorMenuName) <> nil then Continue;
    { owned by the menu: they go with it when the edit window goes first }
    Sep := TMenuItem.Create(Menu);
    Sep.Name := EditorSepName;
    Sep.Caption := '-';
    Menu.Items.Add(Sep);
    Sub := TMenuItem.Create(Menu);
    Sub.Name := EditorMenuName;
    Sub.Caption := '&Git';
    Menu.Items.Add(Sub);
    AddItem(FEdDiff);
    AddItem(FEdBlame);
    AddItem(FEdHistory);
  end;
end;

{ a window came or went (Delphi 7's View | New Edit Window opens a window and no file) }
procedure TGitExpert.WindowTimerTick(Sender: TObject);
begin
  if Screen.FormCount <> FFormCount then InstallEditorMenus;
end;

procedure TGitExpert.RemoveEditorMenus;
var
  I: Integer;
  M: TComponent;
begin
  for I := 0 to Screen.FormCount - 1 do
  begin
    M := Screen.Forms[I].FindComponent('EditorLocalMenu');
    if not (M is TPopupMenu) then Continue;
    TPopupMenu(M).FindComponent(EditorMenuName).Free;
    TPopupMenu(M).FindComponent(EditorSepName).Free;
  end;
end;

procedure TGitExpert.ShowView(Sender: TObject);
begin
  ShowGitView;
end;

procedure TGitExpert.ShowHistory(Sender: TObject);
begin
  if GitHostInstance.EnsureRepo then ShowGitHistory('')
  else ShowGitView;
end;

procedure TGitExpert.SelfTest(Sender: TObject);
begin
  StartGitSelfTest;
end;

procedure TGitExpert.EditorUpdate(Sender: TObject);
var
  V: IOTAEditView;
begin
  V := nil;
  try
    V := TopView;
  except
    V := nil;
  end;
  TAction(Sender).Enabled := (V <> nil) and (V.Buffer <> nil) and (V.Buffer.FileName <> '');
end;

function TGitExpert.EditorFile(out FileName, Path: string): Boolean;
var
  V: IOTAEditView;
  H: TGitHost;
begin
  Result := False;
  FileName := '';
  Path := '';
  V := TopView;
  if (V = nil) or (V.Buffer = nil) then Exit;
  FileName := V.Buffer.FileName;
  H := GitHostInstance;
  if not H.GitFound then
  begin
    GitInform('git.exe was not found: View | Git tells how to set it.');
    Exit;
  end;
  if H.EnsureRepo then Path := H.PathOf(FileName);
  if Path = '' then
  begin
    GitInform(Format('%s is not in the Git repository of the active project.', [ExtractFileName(FileName)]));
    Exit;
  end;
  Result := True;
end;

procedure TGitExpert.EditorDiff(Sender: TObject);
var
  FileName, Path: string;
begin
  if EditorFile(FileName, Path) then ShowGitDiff(gkText, Path, '', '', FileName, 'editor against HEAD');
end;

procedure TGitExpert.EditorBlame(Sender: TObject);
var
  FileName, Path: string;
begin
  if EditorFile(FileName, Path) then ShowGitBlame(Path, FileName);
end;

procedure TGitExpert.EditorHistory(Sender: TObject);
var
  FileName, Path: string;
begin
  if EditorFile(FileName, Path) then ShowGitHistory(Path);
end;

function TGitExpert.GetIDString: string;
begin
  Result := 'D7Studio.GitExpert';
end;

function TGitExpert.GetName: string;
begin
  Result := 'Git';
end;

function TGitExpert.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TGitExpert.Execute;
begin
  ShowGitView;
end;

procedure Register;
begin
  RegisterPackageWizard(TGitExpert.Create);
end;

end.
