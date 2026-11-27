{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoWin;

{ The OTA demo's tool window: a dockable form of designide (DockForm.TDockableForm), made the way
  Delphi 7's experts make theirs (CompBar, GExperts ...):
    * RegisterDesktopFormClass and RegisterFieldAddress (DeskUtil) tell the IDE the form's class
      and the variable that holds the form; the IDE clears that variable when the form is freed;
    * DeskSection names the section of the IDE's ini file (DeskUtil.IDEIniFile, the IDE's registry
      key) where TDockableForm keeps whether the window docks (Dockable);
    * FocusWindow (DeskUtil) shows it.
  It shows the main menu by its items' names - Delphi 7's names (FileMenu, ViewsMenu,
  ToolsOptionsItem ...), the ones experts look for - and the desktop events the demo has seen:
  the main window created and shown (DeskUtil.AddMainFormCreatedEvent / AddMainFormShownEvent)
  and TDesktopForm.DoMainFormShown. The IDE sends those once, while it starts: a package
  installed later sees none of them, in Delphi 7 as in D7 Studio. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, Menus, DockForm;

const
  DemoWindowSection = 'OtaDemoWindow';

type
  TOtaDemoWindow = class(TDockableForm)
    MenuTree: TTreeView;
    Splitter: TSplitter;
    EventList: TListBox;
    BottomPanel: TPanel;
    RefreshButton: TButton;
    procedure RefreshButtonClick(Sender: TObject);
  private
    procedure FillMenuTree;
  public
    constructor Create(AOwner: TComponent); override;
    procedure DoMainFormShown; override;
    procedure FillEvents;
  end;

var
  OtaDemoWindow: TOtaDemoWindow;

{ a desktop event the demo saw: kept, also before the window exists }
procedure DemoEvent(const Text: string);
{ the window's class and variable told to the IDE's desktop, the window made (hidden) }
procedure RegisterDemoWindow;
{ the window freed (its variable cleared through the IDE), the variable no longer known }
procedure UnregisterDemoWindow;
procedure ShowDemoWindow;

implementation

{$R *.dfm}

uses
  ToolsAPI, DeskUtil;

var
  Events: TStringList;

procedure DemoEvent(const Text: string);
begin
  if Events = nil then Events := TStringList.Create;
  Events.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + Text);
  if OtaDemoWindow <> nil then OtaDemoWindow.FillEvents;
end;

procedure RegisterDemoWindow;
begin
  RegisterDesktopFormClass(TOtaDemoWindow, DemoWindowSection, DemoWindowSection);
  if Assigned(RegisterFieldAddress) then RegisterFieldAddress(DemoWindowSection, @OtaDemoWindow);
  { made now, as an expert makes its windows while the IDE starts: a TDesktopForm that exists
    then is told that the main window is shown (DoMainFormShown) }
  if OtaDemoWindow = nil then OtaDemoWindow := TOtaDemoWindow.Create(nil);
end;

procedure UnregisterDemoWindow;
begin
  { the IDE sets OtaDemoWindow, the variable registered for it, to nil as the form is freed }
  OtaDemoWindow.Free;
  if Assigned(UnregisterFieldAddress) then UnregisterFieldAddress(@OtaDemoWindow);
  OtaDemoWindow := nil;
end;

procedure ShowDemoWindow;
begin
  if OtaDemoWindow = nil then OtaDemoWindow := TOtaDemoWindow.Create(nil);
  OtaDemoWindow.FillMenuTree;
  OtaDemoWindow.FillEvents;
  FocusWindow(OtaDemoWindow);
end;

{ ---------------------------------------------------------------- TOtaDemoWindow }

constructor TOtaDemoWindow.Create(AOwner: TComponent);
begin
  inherited;
  { before OnCreate (OldCreateOrder is False): the form reads its Dockable setting from this
    section of the IDE's ini file (DeskUtil.IDEIniFile) as it is made }
  DeskSection := DemoWindowSection;
  AutoSave := True;
end;

procedure TOtaDemoWindow.DoMainFormShown;
begin
  inherited;
  DemoEvent('TDesktopForm.DoMainFormShown: the window existed when the main window was shown');
end;

procedure TOtaDemoWindow.FillMenuTree;

  procedure AddItems(Parent: TTreeNode; Item: TMenuItem);
  var
    I, P: Integer;
    C: TMenuItem;
    Name, Caption: string;
  begin
    for I := 0 to Item.Count - 1 do
    begin
      C := Item[I];
      if C.IsLine then Continue;
      Name := C.Name;
      if Name = '' then Name := '(no name)';
      Caption := StripHotkey(C.Caption);
      P := Pos(#9, Caption);
      if P > 0 then Caption := Copy(Caption, 1, P - 1);
      AddItems(MenuTree.Items.AddChild(Parent, Name + ' - ' + Caption), C);
    end;
  end;

var
  Menu: TMainMenu;
begin
  MenuTree.Items.BeginUpdate;
  try
    MenuTree.Items.Clear;
    Menu := nil;
    if BorlandIDEServices <> nil then Menu := (BorlandIDEServices as INTAServices).MainMenu;
    if Menu <> nil then AddItems(nil, Menu.Items);
  finally
    MenuTree.Items.EndUpdate;
  end;
end;

procedure TOtaDemoWindow.FillEvents;
begin
  EventList.Items.BeginUpdate;
  try
    EventList.Items.Clear;
    if Events <> nil then EventList.Items.Assign(Events);
    if EventList.Items.Count = 0 then
      EventList.Items.Add('No desktop event yet: the IDE sends them once, while it starts.');
  finally
    EventList.Items.EndUpdate;
  end;
end;

procedure TOtaDemoWindow.RefreshButtonClick(Sender: TObject);
begin
  FillMenuTree;
  FillEvents;
end;

initialization
finalization
  Events.Free;
end.
