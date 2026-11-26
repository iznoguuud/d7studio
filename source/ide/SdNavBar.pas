{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNavBar;

{ D7 Studio - the code editor's navigation bar: the boxes Class and
  Methods/functions over the code of a Pascal file. One bar for every page, as there is one editor
  window: a form made once, lent to the page bar of the page shown while its code view shows a
  Pascal file (SdPageBar, TEditorPage.ArrangePageBar), where it takes the width the zoom bar leaves.
  Its lists are the unit's classes and the routines of the class shown (TCodeInsight.GetNavigation,
  made again when the text changed), in alphabetical order; they show where the caret is, and a
  choice goes there. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, SdCodeInsight,
  SdEditorPage;

const
  { a box closed its list, or took an item while closed: WParam the box (0 Class, 1 Methods),
    LParam 1 - an item was taken while the list was closed }
  CM_SD_NAVDONE = WM_APP + 140;

type
  TNavGotoEvent = procedure(Sender: TObject; Line, Col: Integer) of object;

  TNavigationBar = class(TForm)
    ClassBox: TComboBox;
    MethodBox: TComboBox;
    procedure FormResize(Sender: TObject);
    procedure BoxDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure BoxDropDown(Sender: TObject);
    procedure BoxCloseUp(Sender: TObject);
    procedure ClassBoxSelect(Sender: TObject);
    procedure MethodBoxSelect(Sender: TObject);
  private
    FNav: TCINavigation;          // what the lists show (nil: nothing)
    FPage: TEditorPage;           // ... of this page's text
    FVersion: Integer;            // ... as it was then (TEditorPage.TextVersion)
    FListed: Boolean;             // the Methods box lists the routines of FClass
    FClass: TCINavItem;           // ... of this class (nil: the unit's plain routines)
    FDropped: TComboBox;          // the box whose list is open, until CM_SD_NAVDONE (nil: none)
    FChosen: Boolean;             // ... and it closed on an item (CBN_SELENDOK)
    FOnGoto: TNavGotoEvent;
    procedure SetPage(Page: TEditorPage);
    procedure Clear;
    procedure FillClasses;
    procedure ListMethods(Cls: TCINavItem);
    procedure Sync;
    procedure Choose(Box: TComboBox);
    procedure FocusEditor;
    procedure PostDone(Box: TComboBox; Taken: Boolean);
    procedure CMNavDone(var Message: TMessage); message CM_SD_NAVDONE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Page is shown (nil: none), or its caret moved: the boxes show where the caret is. Its lists
      are made when they are of another page; TextChanged (after a pause in typing) also when its
      text changed since - else a changed text waits for that. Nothing while the page wants no
      boxes (TEditorPage.NavigationWanted) or does not show its code, or while a list is open. }
    procedure Follow(Page: TEditorPage; TextChanged: Boolean);
    { test mode: shown|x,y wxh|class|method|classes|methods - the items' texts, ';' after each }
    function TestText: string;
    property OnGoto: TNavGotoEvent read FOnGoto write FOnGoto;
  end;

implementation

{$R *.dfm}

uses
  MultiMon, SdUI, SdIcons, SdCodeExplorer;

const
  GlobalItem = '(global)';        // the Class box's first item: the unit's plain routines
  Gap = 4;                        // between the boxes
  ItemPad = 2;                    // before an item's icon, between the icon and the text, after it

type
  { CBN_SELENDOK of a box whose list is open: it closes on an item, it was not cancelled }
  TBoxHook = class(TUIWindowHook)
  private
    FBar: TNavigationBar;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TBoxHook.Hook(var Message: TMessage);
begin
  if (Message.Msg = CN_COMMAND) and (TWMCommand(Message).NotifyCode = CBN_SELENDOK) and
    (FBar.FDropped = FControl) then
    FBar.FChosen := True;
  FOldProc(Message);
end;

{ the items of List in Box; the same texts keep the box as it is and take the new objects }
procedure SetItems(Box: TComboBox; List: TStrings);
var
  I: Integer;
  Same: Boolean;
begin
  Same := Box.Items.Count = List.Count;
  I := 0;
  while Same and (I < List.Count) do
  begin
    Same := Box.Items[I] = List[I];
    Inc(I);
  end;
  if Same then
    for I := 0 to List.Count - 1 do Box.Items.Objects[I] := List.Objects[I]
  else
    Box.Items.Assign(List);
end;

procedure SetIndex(Box: TComboBox; Index: Integer);
begin
  if Box.ItemIndex <> Index then Box.ItemIndex := Index;
end;

{ ---------------------------------------------------------------- TNavigationBar }

constructor TNavigationBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form parented as a child keeps its own font }
  UIApplyFont(Self);
  { the boxes as high as an edit (as the Object Inspector's instance box), in one paint each, with
    the flat border of the views' lists }
  ClassBox.ItemHeight := UIEditHeight - 6;
  MethodBox.ItemHeight := UIEditHeight - 6;
  ClassBox.Height := UIEditHeight;
  MethodBox.Height := UIEditHeight;
  ClassBox.DoubleBuffered := True;
  MethodBox.DoubleBuffered := True;
  UIFlatBorder(ClassBox);
  UIFlatBorder(MethodBox);
  TBoxHook.Create(ClassBox, True).FBar := Self;
  TBoxHook.Create(MethodBox, True).FBar := Self;
  { on the page bar's ground (the page bar has the margins and the line under them) }
  Color := UIBarColor;
end;

destructor TNavigationBar.Destroy;
begin
  FreeAndNil(FNav);
  inherited Destroy;
end;

{ resized with the page, covered by its boxes but for the margins and the gap: no CS_HREDRAW /
  CS_VREDRAW, which would repaint the boxes at every step of a resize }
procedure TNavigationBar.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure TNavigationBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FPage) then
  begin
    FPage := nil;
    if not (csDestroying in ComponentState) then Clear;
  end;
end;

{ the Class box a third of the width, the Methods box the rest }
procedure TNavigationBar.FormResize(Sender: TObject);
var
  W: Integer;
begin
  if (ClassBox = nil) or (MethodBox = nil) then Exit;     // sized while its .dfm is read
  W := (ClientWidth - Gap) div 3;
  if W < 0 then W := 0;
  UIMoveControls([ClassBox, MethodBox], [Bounds(0, ClassBox.Top, W, ClassBox.Height),
    Bounds(W + Gap, MethodBox.Top, ClientWidth - W - Gap, MethodBox.Height)]);
end;

procedure TNavigationBar.SetPage(Page: TEditorPage);
begin
  if FPage = Page then Exit;
  if FPage <> nil then FPage.RemoveFreeNotification(Self);
  FPage := Page;
  if Page <> nil then Page.FreeNotification(Self);
end;

procedure TNavigationBar.Clear;
begin
  FreeAndNil(FNav);
  SetPage(nil);
  FListed := False;
  FClass := nil;
  ClassBox.Items.Clear;
  MethodBox.Items.Clear;
end;

procedure TNavigationBar.Follow(Page: TEditorPage; TextChanged: Boolean);
var
  Nav: TCINavigation;
begin
  if FDropped <> nil then Exit;
  if (Page = nil) or not Page.NavigationWanted or not Page.CodeView or (IDE = nil) or (IDE.CodeInsight = nil) then
  begin
    if Page <> FPage then Clear;
    Exit;
  end;
  if (Page <> FPage) or (FNav = nil) or (TextChanged and (Page.TextVersion <> FVersion)) then
  begin
    Nav := IDE.CodeInsight.GetNavigation(Page.FileName, Page.GetSource);
    FreeAndNil(FNav);
    FNav := Nav;
    SetPage(Page);
    FVersion := Page.TextVersion;
    FListed := False;
    FillClasses;
  end;
  { lines of another text would point elsewhere }
  if Page.TextVersion = FVersion then Sync;
end;

{ (global), then the classes by name }
procedure TNavigationBar.FillClasses;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupAccept;
    for I := 0 to FNav.Classes.Count - 1 do L.AddObject(TCINavItem(FNav.Classes[I]).Name, FNav.Classes[I]);
    L.Sorted := False;
    L.InsertObject(0, GlobalItem, nil);
    SetItems(ClassBox, L);
  finally
    L.Free;
  end;
end;

{ the routines of Cls (nil: the plain routines), by their captions }
procedure TNavigationBar.ListMethods(Cls: TCINavItem);
var
  L: TStringList;
  I: Integer;
  It: TCINavItem;
begin
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupAccept;
    for I := 0 to FNav.Routines.Count - 1 do
    begin
      It := TCINavItem(FNav.Routines[I]);
      if It.Owner = Cls then L.AddObject(It.Caption, It);
    end;
    SetItems(MethodBox, L);
  finally
    L.Free;
  end;
  FClass := Cls;
  FListed := True;
end;

{ the class and the routine that hold the caret's line; outside every class (global) }
procedure TNavigationBar.Sync;
var
  Cls, It: TCINavItem;
begin
  if (FNav = nil) or (FPage = nil) or (FDropped <> nil) then Exit;
  It := FNav.At(FPage.Editor.CaretLine + 1, Cls);
  if not FListed or (Cls <> FClass) then ListMethods(Cls);
  if Cls = nil then SetIndex(ClassBox, 0) else SetIndex(ClassBox, ClassBox.Items.IndexOfObject(Cls));
  if It = nil then SetIndex(MethodBox, -1) else SetIndex(MethodBox, MethodBox.Items.IndexOfObject(It));
end;

procedure TNavigationBar.FocusEditor;
begin
  if (FPage <> nil) and FPage.Editor.CanFocus then FPage.Editor.SetFocus;
end;

{ the item chosen in Box: a class goes to its declaration and the Methods box lists its routines
  ((global): the plain routines, the caret stays); a routine goes to its implementation, else its
  declaration }
procedure TNavigationBar.Choose(Box: TComboBox);
var
  It: TCINavItem;
begin
  if (FNav = nil) or (Box.ItemIndex < 0) then Exit;
  It := TCINavItem(Box.Items.Objects[Box.ItemIndex]);
  if Box = ClassBox then
  begin
    ListMethods(It);
    SetIndex(MethodBox, -1);
  end;
  if (It <> nil) and Assigned(FOnGoto) then FOnGoto(Self, It.Line, It.Col)
  else FocusEditor;
end;

{ Nothing is done inside a box's notifications: a jump moves the keyboard to the code, and a box
  that loses the focus while it is closing its list - its mouse and capture handling not
  finished - took no item at the next opening. And the order of CBN_SELENDOK, CBN_CLOSEUP and
  CBN_SELCHANGE depends on the input (a click sends the change last). The boxes note what
  happened; the bar acts once they are done (CM_SD_NAVDONE). }
procedure TNavigationBar.PostDone(Box: TComboBox; Taken: Boolean);
begin
  if HandleAllocated then PostMessage(Handle, CM_SD_NAVDONE, Ord(Box = MethodBox), Ord(Taken));
end;

procedure TNavigationBar.CMNavDone(var Message: TMessage);
var
  Box: TComboBox;
  Taken: Boolean;
begin
  if Message.WParam = 0 then Box := ClassBox else Box := MethodBox;
  if (Message.LParam = 0) and (FDropped <> Box) then Exit;      // a close-up handled already
  Taken := (Message.LParam <> 0) or FChosen;
  FDropped := nil;
  FChosen := False;
  if Taken then Choose(Box)
  else
  begin
    Sync;                         // cancelled: the place of the caret again
    FocusEditor;
  end;
end;

{ from the keyboard or the wheel while the list is closed; while it is open (and until its close
  is handled) the item it closes on counts }
procedure TNavigationBar.ClassBoxSelect(Sender: TObject);
begin
  if FDropped = nil then PostDone(ClassBox, True);
end;

procedure TNavigationBar.MethodBoxSelect(Sender: TObject);
begin
  if FDropped = nil then PostDone(MethodBox, True);
end;

{ the list as wide as its widest item (at most the monitor's width) }
procedure TNavigationBar.BoxDropDown(Sender: TObject);
var
  Box: TComboBox;
  I, W, MaxW: Integer;
  Info: TMonitorInfo;
begin
  Box := Sender as TComboBox;
  FDropped := Box;
  FChosen := False;
  W := Box.Width;
  Box.Canvas.Font := Box.Font;
  for I := 0 to Box.Items.Count - 1 do
  begin
    MaxW := Box.Canvas.TextWidth(Box.Items[I]) + 16 + 4 * ItemPad + GetSystemMetrics(SM_CXVSCROLL);
    if MaxW > W then W := MaxW;
  end;
  { the monitor's width from the API: Screen's list of monitors does not know one connected after
    the start (Screen.MonitorFromWindow answers nil for it) }
  Info.cbSize := SizeOf(Info);
  if MultiMon.GetMonitorInfo(MultiMon.MonitorFromWindow(Box.Handle, MONITOR_DEFAULTTONEAREST), @Info) then
    MaxW := Info.rcMonitor.Right - Info.rcMonitor.Left
  else
    MaxW := GetSystemMetrics(SM_CXSCREEN);
  if W > MaxW then W := MaxW;
  Box.Perform(CB_SETDROPPEDWIDTH, W, 0);
end;

{ closed on an item: there; cancelled: the boxes show the caret's place again. The keyboard goes
  back to the code either way - once the box is done (CMNavDone) }
procedure TNavigationBar.BoxCloseUp(Sender: TObject);
begin
  PostDone(Sender as TComboBox, False);
end;

{ an item: the icon of its kind, its text; (global) the unit's icon }
procedure TNavigationBar.BoxDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  Box: TComboBox;
  Cv: TCanvas;
  It: TCINavItem;
  Icon: TSdIcon;
  R: TRect;
  Fore: TColor;
begin
  Box := Control as TComboBox;
  Cv := Box.Canvas;
  if odSelected in State then
  begin
    Cv.Brush.Color := clHighlight;
    Fore := clHighlightText;
  end
  else
  begin
    Cv.Brush.Color := clWindow;
    Fore := clWindowText;
  end;
  Cv.FillRect(Rect);
  if (Index < 0) or (Index >= Box.Items.Count) then Exit;
  It := TCINavItem(Box.Items.Objects[Index]);
  if It = nil then Icon := iiUnit else Icon := KindIcon(It.Kind);
  if (IconList <> nil) and (IconIndex(Icon) >= 0) then
    IconList.Draw(Cv, Rect.Left + ItemPad, Rect.Top + (Rect.Bottom - Rect.Top - 16) div 2, IconIndex(Icon));
  R := Classes.Rect(Rect.Left + 16 + 2 * ItemPad, Rect.Top, Rect.Right - ItemPad, Rect.Bottom);
  UIText(Cv.Handle, Box.Items[Index], R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or
    DT_END_ELLIPSIS, Fore);
end;

function TNavigationBar.TestText: string;

  function Texts(Box: TComboBox): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to Box.Items.Count - 1 do Result := Result + Box.Items[I] + ';';
  end;

  function Shown(Box: TComboBox): string;
  begin
    if Box.ItemIndex < 0 then Result := '-' else Result := Box.Items[Box.ItemIndex];
  end;

begin
  Result := Format('%d|%d,%d %dx%d|%s|%s|%s|%s', [Ord(Visible), Left, Top, Width, Height, Shown(ClassBox),
    Shown(MethodBox), Texts(ClassBox), Texts(MethodBox)]);
end;

end.
