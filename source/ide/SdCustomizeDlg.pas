{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCustomizeDlg;

{ D7 Studio - View | Toolbars | Customize: Delphi 7's Customize dialog.
  As Delphi's it stays open beside the IDE, and
  while it is open the tool bars are being customized: a press on a button no longer runs its
  command but drags the button - to another place of a bar, or off the bars, which removes it -
  and the commands of the Commands page are dragged onto a bar. The pages (Delphi's Toolbars
  page is not there: the bars are always shown):

  * Commands: the commands with an icon by category (the menus of the main menu, then the
    categories of the commands that no menu has), with their icons, and first in each the
    Separator (a drop of it adds a separator to the bar);
  * Options: tooltips on the tool bars, with or without their shortcut keys.

  What the bars hold and what a drop changes is the owner's (OnDrop, OnOptions); the dialog
  does the mouse. Positions come from the mouse messages. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ActnList, ImgList;

type
  { Drop False: may Action (nil: a separator) go to ScreenPt - Accept; Drop True: put it there.
    Source: the button it comes from (it leaves its place), nil from the Commands page }
  TCustomizeDropEvent = procedure(Sender: TObject; Action: TBasicAction; Source: TToolButton;
    const ScreenPt: TPoint; Drop: Boolean; var Accept: Boolean) of object;

  TCustomizeDlg = class(TForm)
    PageControl1: TPageControl;
    TabSheet2: TTabSheet;
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    CategoryList: TListBox;
    CommandList: TListView;
    TabSheet3: TTabSheet;
    xCheckBox1: TCheckBox;
    xCheckBox2: TCheckBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    CloseButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure CategoryListClick(Sender: TObject);
    procedure OptionClick(Sender: TObject);
  private
    FHooks: TList;                  // TCustomizeHook: the bars' messages while customizing
    FCategories: TStringList;       // category = TList of its actions
    { a press that may become a drag: on a bar's button or on a command }
    FPressCtl: TWinControl;
    FPressAction: TBasicAction;
    FPressSource: TToolButton;
    FPressFrom: TPoint;
    FDragging: Boolean;
    FOnDrop: TCustomizeDropEvent;
    FOnOptions: TNotifyEvent;
    FOnClosed: TNotifyEvent;
    function GetImages: TCustomImageList;
    procedure SetImages(Value: TCustomImageList);
    function GetShowTooltips: Boolean;
    procedure SetShowTooltips(Value: Boolean);
    function GetShowShortcuts: Boolean;
    procedure SetShowShortcuts(Value: Boolean);
    procedure CommandListDrawn(var Message: TMessage);
    function HandleMouse(C: TWinControl; var Message: TMessage): Boolean;
    function StartPress(C: TWinControl; const P: TPoint): Boolean;
    procedure EndPress;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure AddBar(Bar: TToolBar);  // a bar whose buttons are dragged while the dialog is open
    procedure AddCommand(const Category: string; Action: TContainedAction);   // once: the first category
    procedure Start;                // after the bars and the commands
    property Images: TCustomImageList read GetImages write SetImages;
    property ShowTooltips: Boolean read GetShowTooltips write SetShowTooltips;
    property ShowShortcuts: Boolean read GetShowShortcuts write SetShowShortcuts;
    property OnDrop: TCustomizeDropEvent read FOnDrop write FOnDrop;
    property OnOptions: TNotifyEvent read FOnOptions write FOnOptions;
    property OnClosed: TNotifyEvent read FOnClosed write FOnClosed;   // it is being freed
  end;

{ a command's text as the Commands page shows it: no access key, no shortcut }
function CommandCaption(const Caption: string): string;

implementation

{$R *.dfm}

uses
  Menus, CommCtrl, SdUI;

type
  { the messages of a bar, and of the command list, while the dialog is open: presses and drags
    go to the dialog; the command list's separator row is drawn after the list painted it. Owned
    by its control (it goes with it); the dialog frees the bars' when it closes }
  TCustomizeHook = class(TUIWindowHook)
  private
    FDlg: TCustomizeDlg;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TCustomizeHook.Hook(var Message: TMessage);
begin
  if FDlg.HandleMouse(FControl, Message) then Exit;
  FOldProc(Message);
  if FControl = FDlg.CommandList then FDlg.CommandListDrawn(Message);
end;

function CommandCaption(const Caption: string): string;
begin
  Result := Caption;
  if Pos(#9, Result) > 0 then Result := Copy(Result, 1, Pos(#9, Result) - 1);
  Result := StripHotkey(Result);
end;

procedure TCustomizeDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  FHooks := TList.Create;
  FCategories := TStringList.Create;
  TCustomizeHook.Create(CommandList, True).FDlg := Self;
end;

{ The lists are nil once freed: inherited Destroy frees the dialog's components, and each one
  that goes calls Notification, which looked through the freed list of hooks (an access
  violation in about 3 of 10 closes) }
destructor TCustomizeDlg.Destroy;
var
  I: Integer;
  L: TList;
begin
  if Assigned(FOnClosed) then FOnClosed(Self);
  if FHooks <> nil then
  begin
    { the bars get their window procedures back; a hook freed here notifies no list }
    L := FHooks;
    FHooks := nil;
    for I := L.Count - 1 downto 0 do TObject(L[I]).Free;
    L.Free;
  end;
  if FCategories <> nil then
  begin
    for I := 0 to FCategories.Count - 1 do FCategories.Objects[I].Free;
    FreeAndNil(FCategories);
  end;
  inherited Destroy;
end;

{ owned by the main window: above it, without a button of its own on the task bar }
procedure TCustomizeDlg.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if Owner is TWinControl then Params.WndParent := TWinControl(Owner).Handle;
end;

procedure TCustomizeDlg.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  Action := caFree;
end;

{ a bar's hook went with its bar }
procedure TCustomizeDlg.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (FHooks <> nil) then FHooks.Remove(AComponent);
end;

procedure TCustomizeDlg.AddBar(Bar: TToolBar);
var
  H: TCustomizeHook;
begin
  H := TCustomizeHook.Create(Bar, True);
  H.FDlg := Self;
  H.FreeNotification(Self);
  FHooks.Add(H);
end;

procedure TCustomizeDlg.AddCommand(const Category: string; Action: TContainedAction);
var
  I: Integer;
begin
  for I := 0 to FCategories.Count - 1 do
    if TList(FCategories.Objects[I]).IndexOf(Action) >= 0 then Exit;
  I := FCategories.IndexOf(Category);
  if I < 0 then I := FCategories.AddObject(Category, TList.Create);
  TList(FCategories.Objects[I]).Add(Action);
end;

procedure TCustomizeDlg.Start;
begin
  CategoryList.Items.Assign(FCategories);
  if CategoryList.Items.Count > 0 then CategoryList.ItemIndex := 0;
  CategoryListClick(nil);
end;

function TCustomizeDlg.GetImages: TCustomImageList;
begin
  Result := CommandList.SmallImages;
end;

procedure TCustomizeDlg.SetImages(Value: TCustomImageList);
begin
  CommandList.SmallImages := Value;
end;

function TCustomizeDlg.GetShowTooltips: Boolean;
begin
  Result := xCheckBox1.Checked;
end;

procedure TCustomizeDlg.SetShowTooltips(Value: Boolean);
begin
  xCheckBox1.Checked := Value;
end;

function TCustomizeDlg.GetShowShortcuts: Boolean;
begin
  Result := xCheckBox2.Checked;
end;

procedure TCustomizeDlg.SetShowShortcuts(Value: Boolean);
begin
  xCheckBox2.Checked := Value;
end;

procedure TCustomizeDlg.CategoryListClick(Sender: TObject);
var
  I: Integer;
  L: TList;
  A: TContainedAction;
  It: TListItem;
begin
  CommandList.Items.BeginUpdate;
  try
    CommandList.Items.Clear;
    if CategoryList.ItemIndex < 0 then Exit;
    L := TList(FCategories.Objects[FCategories.IndexOf(CategoryList.Items[CategoryList.ItemIndex])]);
    { first in every category: a separator (no action), drawn as the tool bar draws one }
    It := CommandList.Items.Add;
    It.Caption := 'Separator';
    It.ImageIndex := -1;
    It.Data := nil;
    for I := 0 to L.Count - 1 do
    begin
      A := TContainedAction(L[I]);
      It := CommandList.Items.Add;
      if A is TCustomAction then
      begin
        It.Caption := CommandCaption(TCustomAction(A).Caption);
        It.ImageIndex := TCustomAction(A).ImageIndex;
      end
      else
      begin
        It.Caption := A.Name;
        It.ImageIndex := -1;
      end;
      It.Data := A;
    end;
  finally
    CommandList.Items.EndUpdate;
  end;
  { the one column fills the list (beside a vertical scroll bar, without a horizontal one) }
  CommandList.Columns[0].Width := ColumnHeaderWidth;
end;

procedure TCustomizeDlg.OptionClick(Sender: TObject);
begin
  xCheckBox2.Enabled := xCheckBox1.Checked;
  if Assigned(FOnOptions) then FOnOptions(Self);
end;

procedure TCustomizeDlg.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

{ a message the command list has handled (its hook: the mouse is the customizing's): the
  Separator row gets the tool bar's separator in its icon's place (custom draw: after the row is
  painted) }
procedure TCustomizeDlg.CommandListDrawn(var Message: TMessage);
var
  CD: PNMLVCustomDraw;
  R: TRect;
  I: Integer;
begin
  if (Message.Msg <> CN_NOTIFY) or (TWMNotify(Message).NMHdr^.code <> NM_CUSTOMDRAW) then Exit;
  CD := PNMLVCustomDraw(TWMNotify(Message).NMHdr);
  I := Integer(CD^.nmcd.dwItemSpec);
  case CD^.nmcd.dwDrawStage of
    CDDS_PREPAINT:
      Message.Result := Message.Result or CDRF_NOTIFYITEMDRAW;
    CDDS_ITEMPREPAINT:
      if (I < CommandList.Items.Count) and (CommandList.Items[I].Data = nil) then
        Message.Result := Message.Result or CDRF_NOTIFYPOSTPAINT;
    CDDS_ITEMPOSTPAINT:
      if ListView_GetItemRect(CommandList.Handle, I, R, LVIR_ICON) then
        UIDrawToolSeparator(CD^.nmcd.hdc, R, CommandList.Color);
  end;
end;

{ a press on a bar's button or on a command: the control keeps the mouse until it is let go }
function TCustomizeDlg.StartPress(C: TWinControl; const P: TPoint): Boolean;
var
  I: Integer;
  Bar: TToolBar;
  It: TListItem;
begin
  Result := False;
  FPressAction := nil;
  FPressSource := nil;
  if C = CommandList then
  begin
    It := CommandList.GetItemAt(P.X, P.Y);
    if It = nil then Exit;
    CommandList.Selected := It;
    CommandList.ItemFocused := It;
    if CommandList.CanFocus then CommandList.SetFocus;
    FPressAction := TBasicAction(It.Data);
  end
  else
  begin
    Bar := TToolBar(C);
    for I := 0 to Bar.ButtonCount - 1 do
      if Bar.Buttons[I].Visible and PtInRect(Bar.Buttons[I].BoundsRect, P) then
        FPressSource := Bar.Buttons[I];
    if FPressSource = nil then Exit;
    FPressAction := FPressSource.Action;
  end;
  FPressCtl := C;
  FPressFrom := P;
  FDragging := False;
  SetCapture(C.Handle);
  Result := True;
end;

procedure TCustomizeDlg.EndPress;
var
  C: TWinControl;
begin
  if FDragging then Screen.Cursor := crDefault;
  C := FPressCtl;
  FPressCtl := nil;                 // before the capture goes: that is no cancel then
  FDragging := False;
  if (C <> nil) and C.HandleAllocated and (GetCapture = C.Handle) then ReleaseCapture;
end;

{ True: the message was the customizing's (a press on a bar is never a click there) }
function TCustomizeDlg.HandleMouse(C: TWinControl; var Message: TMessage): Boolean;
var
  P, S: TPoint;
  Accept, Drop: Boolean;
  Action: TBasicAction;
  Source: TToolButton;
begin
  Result := False;
  case Message.Msg of
    WM_LBUTTONDOWN, WM_LBUTTONDBLCLK:
      begin
        P := SmallPointToPoint(TWMMouse(Message).Pos);
        Result := StartPress(C, P) or (C <> CommandList);
        if Result then Message.Result := 0;
      end;
    WM_LBUTTONUP:
      if C <> CommandList then Result := True;
    { the right button opens the bar's menu (Reset...) also while customizing }
    WM_MBUTTONDOWN, WM_MBUTTONUP:
      Result := C <> CommandList;
  end;
  if (C <> FPressCtl) or (FPressCtl = nil) then Exit;
  case Message.Msg of
    WM_MOUSEMOVE:
      begin
        P := SmallPointToPoint(TWMMouse(Message).Pos);
        if not FDragging and UIDragStarted(FPressFrom, P) then FDragging := True;
        if FDragging then
        begin
          Accept := False;
          if Assigned(FOnDrop) then FOnDrop(Self, FPressAction, FPressSource, C.ClientToScreen(P), False, Accept);
          if Accept then Screen.Cursor := crDrag else Screen.Cursor := crNo;
        end;
        Message.Result := 0;
        Result := True;
      end;
    WM_LBUTTONUP:
      begin
        S := C.ClientToScreen(SmallPointToPoint(TWMMouse(Message).Pos));
        Drop := FDragging;
        Action := FPressAction;
        Source := FPressSource;
        EndPress;
        Accept := False;
        { the drop may rebuild the bar: the button pressed is gone afterwards }
        if Drop and Assigned(FOnDrop) then FOnDrop(Self, Action, Source, S, True, Accept);
        Message.Result := 0;
        Result := True;
      end;
    WM_CAPTURECHANGED:
      if UICaptureLost(C, Message) then EndPress;
    CN_KEYDOWN:
      if UIPressEscape(C, TWMKey(Message)) then
      begin
        EndPress;
        Message.Result := 1;
        Result := True;
      end;
  end;
end;

end.
