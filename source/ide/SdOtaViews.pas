{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaViews;

{ D7 Studio - the experts' dockable windows as views of the dock.
  An expert's tool window is a dockable form of designide (DockForm.TDockableForm: CompBar's,
  GExperts' ...), which Delphi docks into its own dock sites. D7 Studio puts it into a view of its
  dock instead: TSdExpertView, which the form fills as a docked form fills Delphi's dock site
  (its Parent). designide's TDesktopForm.FormCreate calls DeskForm.InitializeForm for every
  desktop form that is made (SdOtaDesktop), and the main form adopts the dockable ones
  (TSdExpertViews.Adopt) - the packages' design windows (TDesignWindow) are not desktop forms and
  keep floating as in Delphi.
  * The view floats in a window of its own the first time the form is shown, at the form's own
    place and size, unless the arrangement saved last placed it (Placed); it docks, becomes a
    tab and floats again as every view does, and keeps its place in the arrangement by its name,
    Expert.<the form's name>.
  * An arrangement keeps the place of a view whose expert makes its form only when it is asked
    for: an arrangement applied makes a view without a form for each such name it lists
    (Reserve), the dock places it and saves it again, and the form fills it when it is made. Once
    the experts have loaded, the forms of the views an arrangement shows are made as Delphi's
    desktop makes them (MakeForms, SdOtaDesktop.DeskMakeForm); a view whose form cannot be made
    is hidden, and every form is shown or hidden as its view is.
  * The form and its view show and hide together: the expert's Show, Visible or FocusWindow
    shows the view and gives it the keyboard - FocusWindow and BringToFront of a form shown
    already too (WM_CHILDACTIVATE) -, closing the view hides the form; a desktop that shows or
    hides the form leaves the keyboard where it is.
  * VCL docking is off for the form (Dockable, DragKind, DragMode, DockSite): the dock moves it.
  * A form that goes (its expert freed it, its package was unloaded: DropModule) leaves its view
    hidden and empty; a form of the same name fills it again later, where it was. At the end
    the forms are given back (ReleaseAll): their experts free them. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, SdUI, SdDock;

const
  ExpertViewPrefix = 'Expert.';
  ExpertStatusMessageName = 'D7Studio.ExpertViewStatus';
  EditorOptionsMessageName = 'D7Studio.EditorOptionsChanged';

var
  { RegisterWindowMessage(ExpertStatusMessageName): an expert's form sets its view's status line }
  ExpertStatusMessage: UINT;
  { RegisterWindowMessage(EditorOptionsMessageName): options were applied; an expert reads what it
    shows of them again (IOTAEditOptions: the editor's font) }
  EditorOptionsMessage: UINT;

{ EditorOptionsMessage to every window of the IDE's thread: the experts' forms and controls, docked,
  floating or hidden }
procedure NotifyEditorOptionsChanged;

type
  TSdShowPanelProc = procedure(P: TSdDockPanel) of object;

  TSdExpertViews = class;

  { the view of an expert's form: the form fills it }
  TSdExpertView = class(TSdControl)
  private
    FViews: TSdExpertViews;
    FForm: TCustomForm;
    FHook: TUIWindowHook;           // on the form: its showing and its caption
    FPanel: TSdDockPanel;
    FFloatRect: TRect;              // the form's own place (screen) when it came: its first window
    FPlaced: Boolean;               // floated once, or placed by a saved arrangement
    FSyncing: Boolean;
    procedure NoVclDocking;
    procedure FollowPanel;
    procedure ShowForExpert;
    function CanFollow: Boolean;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WndProc(var Message: TMessage); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    procedure Take(Form: TCustomForm);
    procedure Release;
    procedure FormVisibleChanged;
    procedure FormBroughtUp;
    procedure FormTextChanged;
    property Form: TCustomForm read FForm;
    property Panel: TSdDockPanel read FPanel;
  end;

  TSdExpertViews = class
  private
    FOwner: TComponent;
    FDock: TSdDock;
    FArea: TSdDockArea;
    FShowPanel: TSdShowPanelProc;
    FViews: TList;
    FClosing: Boolean;
    function Find(const AName: string): TSdExpertView;
    function GetView(Index: Integer): TSdExpertView;
    function NewView(const AName, ATitle: string): TSdExpertView;
  public
    { AOwner owns the views; ADock / AArea: a new view's place until it floats; AShowPanel: how
      the main window shows a view the expert shows (a hidden group slides out, the keyboard goes
      to it ...) }
    constructor Create(AOwner: TComponent; ADock: TSdDock; AArea: TSdDockArea;
      AShowPanel: TSdShowPanelProc);
    destructor Destroy; override;
    { DeskForm.InitializeForm (SdOtaDesktop): a dockable form becomes a view }
    procedure Adopt(Form: TCustomForm);
    { before an arrangement is applied (Names: the views it lists): a view without a form for each
      expert view it names that is not there, for the arrangement to place }
    procedure Reserve(Names: TStrings);
    { the arrangement saved last was applied again: the views it names are where it put them }
    procedure Placed(Names: TStrings);
    { after an arrangement was applied: the forms of the views it shows that have none made, as
      Delphi's desktop makes them, and every form shown or hidden as its view is; a view whose
      form cannot be made is hidden }
    procedure MakeForms;
    { a package goes: the forms of its classes are given back }
    procedure DropModule(Module: HMODULE);
    { the end: every form given back }
    procedure ReleaseAll;
    function Count: Integer;
    { test mode: 'name:form,shown,floating;...' }
    function DebugText: string;
    property Views[Index: Integer]: TSdExpertView read GetView;
  end;

implementation

uses
  DockForm, SdEncoding, SdOtaDesktop;

type
  TFormAccess = class(TCustomForm);
  TDockableAccess = class(TDockableForm);

  { the expert's form: its view follows when it is shown or hidden and when its caption changes }
  TExpertFormHook = class(TUIWindowHook)
  private
    FView: TSdExpertView;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TExpertFormHook.Hook(var Message: TMessage);
begin
  FOldProc(Message);
  if FView = nil then Exit;
  case Message.Msg of
    CM_VISIBLECHANGED: FView.FormVisibleChanged;
    CM_TEXTCHANGED: FView.FormTextChanged;
    { the form brought to the front (designide's FocusWindow, BringToFront): a child window gets
      this from SetWindowPos }
    WM_CHILDACTIVATE: FView.FormBroughtUp;
  end;
end;

{ ---------------------------------------------------------------- TSdExpertView }

{ the expert's form covers the view (no erase, TSdControl); resized with it inside: no repaint
  of the whole for it }
procedure TSdExpertView.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

const
  { posted to the view: the dock is laid out again for its status line }
  WM_RELAYOUTSTATUS = WM_APP + $5D1;
  { posted to the view: the keyboard to it again once the expert's call that showed it is over }
  WM_FOCUSVIEW = WM_APP + $5D2;

{ the expert's form sets the view's status line (ExpertStatusMessage). The form sends it also while
  the dock lays the view out (showing the view shows the form): a layout called from there is lost,
  so a status line that comes or goes has the dock laid out again afterwards, from a posted message }
procedure TSdExpertView.WndProc(var Message: TMessage);
var
  Was: Boolean;
begin
  if (Message.Msg = ExpertStatusMessage) and (ExpertStatusMessage <> 0) then
  begin
    if FPanel <> nil then
    begin
      Was := FPanel.ShowStatus;
      if (Message.WParam <> 0) and (Message.LParam <> 0) then
      begin
        FPanel.StatusText := WideToIde(PWideChar(Message.LParam));
        FPanel.ShowStatus := True;
      end
      else
        FPanel.ShowStatus := False;
      if (FPanel.ShowStatus <> Was) and HandleAllocated then PostMessage(Handle, WM_RELAYOUTSTATUS, 0, 0);
      Message.Result := 1;
    end;
    Exit;
  end;
  if Message.Msg = WM_RELAYOUTSTATUS then
  begin
    if (FViews <> nil) and not FViews.FClosing then FViews.FDock.Layout;
    Exit;
  end;
  if Message.Msg = WM_FOCUSVIEW then
  begin
    if (FViews <> nil) and not FViews.FClosing and (FPanel <> nil) then FViews.FDock.FocusPanel(FPanel);
    Exit;
  end;
  inherited;
end;

procedure TSdExpertView.Take(Form: TCustomForm);
begin
  FForm := Form;
  Form.FreeNotification(Self);
  FFloatRect := Form.BoundsRect;
  FHook := TExpertFormHook.Create(Form, True);
  TExpertFormHook(FHook).FView := Self;
  FSyncing := True;
  try
    TFormAccess(Form).BorderStyle := bsNone;
    { a form with a parent is not moved to another monitor when it is shown }
    TFormAccess(Form).DefaultMonitor := dmDesktop;
    Form.Parent := Self;
    Form.Align := alClient;
  finally
    FSyncing := False;
  end;
  FPanel.Title := Form.Caption;
end;

procedure TSdExpertView.NoVclDocking;
begin
  if FForm = nil then Exit;
  if FForm is TDockableForm then TDockableAccess(FForm).Dockable := False;
  TFormAccess(FForm).DragMode := dmManual;
  TFormAccess(FForm).DragKind := dkDrag;
  TFormAccess(FForm).DockSite := False;
end;

procedure TSdExpertView.Release;
var
  F: TCustomForm;
begin
  F := FForm;
  if F = nil then Exit;
  FSyncing := True;
  try
    F.RemoveFreeNotification(Self);
    FreeAndNil(FHook);
    F.Visible := False;
    F.Align := alNone;
    F.Parent := nil;
  finally
    FSyncing := False;
  end;
  FForm := nil;
  if (FPanel <> nil) and not FViews.FClosing then FViews.FDock.HidePanel(FPanel);
end;

procedure TSdExpertView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FForm) then
  begin
    { its hook goes with it (owned by the form) }
    FForm := nil;
    FHook := nil;
    if (FPanel <> nil) and not FViews.FClosing then FViews.FDock.HidePanel(FPanel);
  end;
end;

{ the expert showed or hid its form: the view does the same - the first time it floats in a
  window of its own at the form's place, unless a saved arrangement placed it }
procedure TSdExpertView.FormVisibleChanged;
begin
  if not CanFollow then Exit;
  FSyncing := True;
  try
    if FForm.Visible then
    begin
      NoVclDocking;
      if not FPlaced then
      begin
        FPlaced := True;
        FViews.FDock.FloatPanel(FPanel, FFloatRect);
      end;
      ShowForExpert;
    end
    else
      FViews.FDock.HidePanel(FPanel);
  finally
    FSyncing := False;
  end;
end;

{ the expert brought its shown form to the front: its view comes up as when it was shown - its tab
  chosen, the keyboard in it }
procedure TSdExpertView.FormBroughtUp;
begin
  if CanFollow and FForm.Visible then ShowForExpert;
end;

{ the form and its view may follow each other: both there, neither following the other already, not
  the end }
function TSdExpertView.CanFollow: Boolean;
begin
  Result := not FSyncing and (FForm <> nil) and (FPanel <> nil) and not FViews.FClosing;
end;

{ the view shown as the main window shows one the expert shows (AShowPanel: the keyboard goes to
  it), and the keyboard to it again once the expert's call is over - what the expert does after
  showing it (reading its data, showing other controls) may hide the control that got it }
procedure TSdExpertView.ShowForExpert;
begin
  FViews.FShowPanel(FPanel);
  if HandleAllocated then PostMessage(Handle, WM_FOCUSVIEW, 0, 0);
end;

procedure TSdExpertView.FormTextChanged;
begin
  if (FForm <> nil) and (FPanel <> nil) then FPanel.Title := FForm.Caption;
end;

{ the dock showed or hid the view: closing it (its close box, its window's) hides the form, a
  desktop that has it shows the form - another tab of its group being chosen does neither }
procedure TSdExpertView.CMVisibleChanged(var Message: TMessage);
begin
  inherited;
  if CanFollow then FollowPanel;
end;

{ the form shown or hidden as the dock has its view }
procedure TSdExpertView.FollowPanel;
begin
  if (FForm = nil) or (FForm.Visible = FPanel.Visible) then Exit;
  FSyncing := True;
  try
    if FPanel.Visible then
    begin
      NoVclDocking;
      FPlaced := True;
    end;
    FForm.Visible := FPanel.Visible;
  finally
    FSyncing := False;
  end;
end;

{ ---------------------------------------------------------------- TSdExpertViews }

constructor TSdExpertViews.Create(AOwner: TComponent; ADock: TSdDock; AArea: TSdDockArea;
  AShowPanel: TSdShowPanelProc);
begin
  inherited Create;
  FOwner := AOwner;
  FDock := ADock;
  FArea := AArea;
  FShowPanel := AShowPanel;
  FViews := TList.Create;
end;

destructor TSdExpertViews.Destroy;
begin
  FViews.Free;
  inherited;
end;

function TSdExpertViews.GetView(Index: Integer): TSdExpertView;
begin
  Result := TSdExpertView(FViews[Index]);
end;

function TSdExpertViews.Count: Integer;
begin
  Result := FViews.Count;
end;

function TSdExpertViews.Find(const AName: string): TSdExpertView;
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if SameText(Views[I].FPanel.Name, AName) then
    begin
      Result := Views[I];
      Exit;
    end;
  Result := nil;
end;

{ a view without a form: added and hidden again before anything is drawn - it appears when its
  form is shown or an arrangement shows it }
function TSdExpertViews.NewView(const AName, ATitle: string): TSdExpertView;
begin
  Result := TSdExpertView.Create(FOwner);
  Result.FViews := Self;
  UIFreezeRedraw(FDock, True);
  try
    Result.FPanel := FDock.AddPanel(Result, AName, ATitle, FArea);
    FDock.HidePanel(Result.FPanel);
  finally
    UIFreezeRedraw(FDock, False, False);
  end;
  FViews.Add(Result);
end;

procedure TSdExpertViews.Adopt(Form: TCustomForm);
var
  N: string;
  V: TSdExpertView;
begin
  if FClosing or not (Form is TDockableForm) then Exit;
  if Form.Name <> '' then N := ExpertViewPrefix + Form.Name
  else N := ExpertViewPrefix + Form.ClassName;
  V := Find(N);
  if V = nil then V := NewView(N, Form.Caption)
  else V.Release;
  V.Take(Form);
end;

{ the form name in the name of an expert's view (Expert.<the form's name>); '' for another view's }
function ViewFormName(const ViewName: string): string;
var
  L: Integer;
begin
  L := Length(ExpertViewPrefix);
  if (Length(ViewName) > L) and SameText(Copy(ViewName, 1, L), ExpertViewPrefix) then
    Result := Copy(ViewName, L + 1, MaxInt)
  else
    Result := '';
end;

procedure TSdExpertViews.Reserve(Names: TStrings);
var
  I: Integer;
  F: string;
begin
  if FClosing then Exit;
  for I := 0 to Names.Count - 1 do
  begin
    F := ViewFormName(Names[I]);
    if (F <> '') and (Find(Names[I]) = nil) then NewView(Names[I], F);
  end;
end;

procedure TSdExpertViews.Placed(Names: TStrings);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if Names.IndexOf(Views[I].FPanel.Name) >= 0 then Views[I].FPlaced := True;
end;

procedure TSdExpertViews.MakeForms;
var
  I, N: Integer;
  V: TSdExpertView;
begin
  if FClosing then Exit;
  { a form whose name is not its view's adds a view of its own, which is not looked at }
  N := FViews.Count;
  for I := 0 to N - 1 do
  begin
    V := Views[I];
    if (V.FForm = nil) and V.FPanel.Visible then DeskMakeForm(ViewFormName(V.FPanel.Name));
    { a form made here fills its view as it is made (Adopt); a form its expert made while it
      loaded filled a view the arrangement of the start had shown already, which the dock does not
      show again (no CM_VISIBLECHANGED). Either is shown or hidden as the arrangement has its
      view, the view left where it put it - not shown as the expert's Show shows it }
    if V.FForm <> nil then V.FollowPanel
    else if V.FPanel.Visible then FDock.HidePanel(V.FPanel);
  end;
end;

procedure TSdExpertViews.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  if Module = 0 then Exit;
  for I := 0 to FViews.Count - 1 do
    if (Views[I].FForm <> nil) and (FindHInstance(Pointer(Views[I].FForm.ClassType)) = Module) then
      Views[I].Release;
end;

procedure TSdExpertViews.ReleaseAll;
var
  I: Integer;
begin
  FClosing := True;
  for I := 0 to FViews.Count - 1 do Views[I].Release;
end;

function TSdExpertViews.DebugText: string;
var
  I: Integer;
  V: TSdExpertView;
  F: string;
begin
  Result := '';
  for I := 0 to FViews.Count - 1 do
  begin
    V := Views[I];
    if V.FForm <> nil then F := V.FForm.ClassName else F := '-';
    Result := Result + Format('%s:%s,%d,%d;', [V.FPanel.Name, F, Ord(V.FPanel.Visible),
      Ord(V.FPanel.Group.Floating)]);
  end;
end;

{ a child window of another thread (a window that thread made inside one of the IDE's) is left out:
  a message sent to it would wait for that thread }
function NotifyChildWindow(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
begin
  if GetWindowThreadProcessId(Wnd, nil) = GetCurrentThreadId then
    SendMessage(Wnd, EditorOptionsMessage, 0, 0);
  Result := True;
end;

function NotifyTopWindow(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
begin
  SendMessage(Wnd, EditorOptionsMessage, 0, 0);
  EnumChildWindows(Wnd, @NotifyChildWindow, 0);
  Result := True;
end;

procedure NotifyEditorOptionsChanged;
begin
  EnumThreadWindows(GetCurrentThreadId, @NotifyTopWindow, 0);
end;

initialization
  ExpertStatusMessage := RegisterWindowMessage(ExpertStatusMessageName);
  EditorOptionsMessage := RegisterWindowMessage(EditorOptionsMessageName);
end.
