{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdBreakpointsView;

{ D7 Studio - the Breakpoints view (Delphi 7's breakpoint window): the debugger's breakpoints in a
  list with check boxes (the debugger's front end, SdDebugUI's TDebugController, fills it and keeps
  its OnChange and OnKeyDown), Delphi's two local menus - a breakpoint's on an item, the list's
  elsewhere - and the actions only those menus have. A form made once (its list, menus and actions
  in the .dfm), docked by the IDE - a child window then, without a border. The menus' Add items
  (Run | Add Breakpoint) and the dock's commands at their end are the IDE's actions, given to them
  in code (TMainForm.CreatePanes, AddDockItems). }

interface

uses
  Windows, Messages, Classes, Controls, Forms, ComCtrls, Menus, ActnList, SdUI, SdIcons, SdDbgEngine,
  SdDebugUI, SdDialogs;

type
  TBreakpointsView = class(TForm)
    BreakList: TListView;
    Actions: TActionList;
    aBPDeleteAll: TAction;
    aBPDisableAll: TAction;
    aBPEnableAll: TAction;
    aBPDisableGroup: TAction;
    aBPEnableGroup: TAction;
    aBPEnabled: TAction;
    aBPDelete: TAction;
    aBPViewSource: TAction;
    aBPEditSource: TAction;
    aBPProperties: TAction;
    BreakPopup: TPopupMenu;
    pmBreak1: TMenuItem;
    pmBreak2: TMenuItem;
    pmBreak3: TMenuItem;
    pmBreak4: TMenuItem;
    pmBreak5: TMenuItem;
    pmBreak6: TMenuItem;
    pmBreak7: TMenuItem;
    pmBreak8: TMenuItem;
    pmBreak9: TMenuItem;
    pmBreak10: TMenuItem;
    BreakItemPopup: TPopupMenu;
    pmBreakItem1: TMenuItem;
    pmBreakItem2: TMenuItem;
    pmBreakItem3: TMenuItem;
    pmBreakItem4: TMenuItem;
    pmBreakItem5: TMenuItem;
    pmBreakItem6: TMenuItem;
    pmBreakItem7: TMenuItem;
    pmBreakItem8: TMenuItem;
    pmBreakItem9: TMenuItem;
    pmBreakItem10: TMenuItem;
    pmBreakItem11: TMenuItem;
    pmBreakItem12: TMenuItem;
    pmBreakItem13: TMenuItem;
    pmBreakItem14: TMenuItem;
    pmBreakItem15: TMenuItem;
    pmBreakItem16: TMenuItem;
    pmBreakItem17: TMenuItem;
    pmBreakItem18: TMenuItem;
    pmBreakItem19: TMenuItem;
    procedure BreakListContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure BreakListDblClick(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure Command(Sender: TObject);
  private
    FDebug: TDebugController;
    FOnMenuPopup: TNotifyEvent;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    { the actions' states: a breakpoint's commands while one is chosen, the list's while there are
      breakpoints (groups: while one has a group) }
    procedure UpdateCommands;
    property Debug: TDebugController read FDebug write FDebug;
    { a menu opens (before the view's states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

{$R *.dfm}

constructor TBreakpointsView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font (the list
    gets the debug views' font from the IDE: TMainForm.ApplyDebugFont) }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Actions.Images := IconList;
  BreakPopup.Images := IconList;
  BreakItemPopup.Images := IconList;
  UIOwnerDrawMenus(Self);
end;

{ No flicker: the list fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TBreakpointsView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the list covers the whole view: nothing of the form shows, nothing to erase }
procedure TBreakpointsView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TBreakpointsView.UpdateCommands;
var
  BP: TDbgBreakpoint;
begin
  BP := FDebug.SelectedBreakpoint;
  aBPEnabled.Enabled := BP <> nil;
  aBPEnabled.Checked := (BP <> nil) and BP.Enabled;
  aBPDelete.Enabled := BP <> nil;
  aBPViewSource.Enabled := BP <> nil;
  aBPEditSource.Enabled := BP <> nil;
  aBPProperties.Enabled := BP <> nil;
  aBPDeleteAll.Enabled := FDebug.BreakpointCount > 0;
  aBPDisableAll.Enabled := FDebug.BreakpointCount > 0;
  aBPEnableAll.Enabled := FDebug.BreakpointCount > 0;
  aBPDisableGroup.Enabled := FDebug.HasGroups;
  aBPEnableGroup.Enabled := aBPDisableGroup.Enabled;
end;

{ Delphi's menu of a breakpoint on an item, its menu of the list elsewhere }
procedure TBreakpointsView.BreakListContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  It: TListItem;
begin
  It := nil;
  if (MousePos.X >= 0) and (MousePos.Y >= 0) then It := BreakList.GetItemAt(MousePos.X, MousePos.Y);
  if It <> nil then BreakList.Selected := It
  else if (MousePos.X < 0) and (BreakList.Selected <> nil) then It := BreakList.Selected;   // the keyboard
  if It <> nil then BreakList.PopupMenu := BreakItemPopup else BreakList.PopupMenu := BreakPopup;
end;

{ a double click: View Source, the menu's command (its state made current first: the click may have
  changed the selection) }
procedure TBreakpointsView.BreakListDblClick(Sender: TObject);
begin
  UpdateCommands;
  aBPViewSource.Execute;
end;

procedure TBreakpointsView.MenuPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  UpdateCommands;
end;

{ the commands of the menus that D7 Studio can do }
procedure TBreakpointsView.Command(Sender: TObject);
var
  Groups: TStringList;
  I: Integer;
begin
  if Sender = aBPDeleteAll then FDebug.DeleteAllBreakpoints
  else if (Sender = aBPDisableGroup) or (Sender = aBPEnableGroup) then
  begin
    { Delphi asks for the group in a list }
    Groups := TStringList.Create;
    try
      FDebug.GetGroups(Groups);
      I := 0;
      if ListDialog(Application.MainForm, TAction(Sender).Caption, Groups, I) and (I >= 0) and (I < Groups.Count) then
        FDebug.EnableGroup(Groups[I], Sender = aBPEnableGroup);
    finally
      Groups.Free;
    end;
  end
  else if Sender = aBPDisableAll then FDebug.EnableAllBreakpoints(False)
  else if Sender = aBPEnableAll then FDebug.EnableAllBreakpoints(True)
  else if Sender = aBPEnabled then FDebug.ToggleSelectedBreakpoint
  else if Sender = aBPDelete then FDebug.DeleteSelectedBreakpoint
  else if Sender = aBPProperties then FDebug.EditSelectedBreakpoint
  else if (Sender = aBPViewSource) or (Sender = aBPEditSource) then
  begin
    FDebug.ShowBreakpointSource;
    if (Sender = aBPViewSource) and BreakList.CanFocus then BreakList.SetFocus;
  end;
end;

end.
