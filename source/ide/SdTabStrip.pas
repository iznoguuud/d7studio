{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTabStrip;

{ D7 Studio - tabs. Every tab of the IDE is drawn by
  UIDrawTab: flat, the chosen one in the window colour with a bar in the colour of the title bars.
  * TSdTabStrip: a strip of tabs on a side of the view it switches - the tabs of the dock's
    groups (TSdDockTabs: below, above, left or right of the view), the Code /
    Design tabs of a form unit's page (below) and the inspector's Properties / Events (above).
    The tab under the pointer hot. A tab may show an icon before its title (TabImage of
    TabImages) and a title in a colour of its own (TabTextColor). A tab is as long as its title
    and icon; all are cut down alike when
    the strip is too short. Painted through a bitmap it keeps and never erased (no flicker); a
    change of the hot or the chosen tab repaints those two tabs only.
  * TSdFileTabs: the editor's file tabs - Windows' tab control (it scrolls its tabs and keeps
    every file name), painted over with the same tabs and close boxes; the row of tabs only.
  * TSdPressBoxes: the close boxes of the file tabs (and the buttons of the dock's captions): which one
    is under the pointer, which one is pressed, which one a click acts on. }

interface

uses
  Windows, Messages, Classes, Graphics, Controls, ComCtrls, CommCtrl, ImgList, SdUI;

type
  { box Index - the close box of tab Index, a button of a caption (False: there is no such box) }
  TSdTabBoxFunc = function(Index: Integer; out R: TRect): Boolean of object;
  TSdTabCloseEvent = procedure(Sender: TObject; Index: Integer) of object;
  { tab FromIndex is now at ToIndex (TStrings.Move: the others between them moved one place) }
  TSdTabMoveEvent = procedure(Sender: TObject; FromIndex, ToIndex: Integer) of object;

{ A tab dragged along its row - the file tabs, the dock's tab strips: Lo..Hi its span along the
  row, X the pointer, Dir the move's direction along it (X less where the pointer was before).
  1: it changes places with the next tab (HasNext) - the pointer, moving on, reached that tab
  (passed the dragged tab's end); -1: with the tab before it (HasPrev) - moving back, the pointer
  reached that one; 0: it stays. Only the direction of the move counts: after a step the pointer
  may lie over the neighbour (a longer one), and the tab goes back only when the pointer moves
  back. A fast move passes several: ask again after each step }
function TabReorderStep(X, Dir, Lo, Hi: Integer; HasPrev, HasNext: Boolean): Integer;

type
  { Boxes that act when a press ends on them: the close boxes of a row of tabs, the buttons of a
    caption. A box is hot under the pointer and pressed while a press that began on it is over
    it; letting go there is a click. Positions come from the mouse messages; the control
    repaints the boxes that change. }
  TSdPressBoxes = class
  private
    FControl: TWinControl;
    FBox: TSdTabBoxFunc;
    FHot, FDown: Integer;           // -1: none
    procedure Repaint(Index: Integer);
    procedure SetHot(Value: Integer);
  public
    constructor Create(AControl: TWinControl; ABox: TSdTabBoxFunc);
    function BoxAt(X, Y: Integer): Integer;
    function State(Index: Integer): TUIButtonState;
    function Press(X, Y: Integer): Boolean;          // the left button went down: on a box?
    procedure Move(X, Y: Integer);
    function Release(X, Y: Integer): Integer;        // let go: the tab to close, or -1
    procedure Reset;                                 // the pointer left, the capture went, tabs changed
    function Pressed: Boolean;
  end;

  TSdTabStrip = class(TSdControl)
  private
    FTabs: TStringList;
    FTabIndex: Integer;
    FRects: array of TRect;
    FHot: Integer;
    FSide: TUITabSide;
    FImages: TCustomImageList;
    FOnChange: TNotifyEvent;
    procedure SetImages(Value: TCustomImageList);
    function GetTabs: TStrings;
    procedure SetTabIndex(Value: Integer);
    procedure SetSide(Value: TUITabSide);
    procedure SetHot(Value: Integer);
    procedure InvalidateTab(Index: Integer);
    procedure TabsChanged(Sender: TObject);
    procedure Arrange;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure PaintBuffer(C: TCanvas); override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    { a click (either button) on another tab: by default it becomes the chosen one and
      OnChange follows }
    procedure Choose(Index: Integer); virtual;
    { a tab's name in DebugPositions: by default its title }
    function TabName(Index: Integer): string; virtual;
    { the icon of TabImages before a tab's title: -1 none (the default) }
    function TabImage(Index: Integer): Integer; virtual;
    { the list of the tabs' icons: by default Images }
    function TabImages: TCustomImageList; virtual;
    { a tab's title colour: clNone (the default) the state's }
    function TabTextColor(Index: Integer): TColor; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function TabAt(X, Y: Integer): Integer;       // -1: no tab there
    function TabRect(Index: Integer): TRect;
    { where tab Index starts and ends along the strip (top to bottom on a left or right strip) }
    procedure TabSpan(Index: Integer; out Lo, Hi: Integer);
    function Vertical: Boolean;                   // left or right of the view: tabs top to bottom
    { the tabs become the strings and objects of Items - made again (one repaint) only when they
      differ from what the strip has }
    procedure SetItems(Items: TStrings);
    function TabObject(Index: Integer): TObject;  // Tabs.Objects[Index]
    { test mode: 'name@start-end,...' - every tab's place along the strip (TabSpan) }
    function DebugPositions: string;
    { the tabs' icons (TabImage) or title colours (TabTextColor) changed, or the images of their
      list: measured and painted again }
    procedure LooksChanged;
    property Side: TUITabSide read FSide write SetSide;   // where the strip lies next to the view
    property Images: TCustomImageList read FImages write SetImages;   // the tabs' icons (TabImage)
    property Tabs: TStrings read GetTabs;         // titles (Objects free for the owner)
    property TabIndex: Integer read FTabIndex write SetTabIndex;   // setting it calls no OnChange
    property OnChange: TNotifyEvent read FOnChange write FOnChange;   // a click chose a tab
  end;

  { The file tabs: Windows' tab control measures, scrolls and hit-tests the tabs and keeps their
    titles (also names outside the code page: SetTabTextW); it is the row of tabs only (the pages
    lie below it, beside it Back and Forward: TMainForm's FTabRow), painted over with the tabs as
    UIDrawTab's. A click on a tab's close box calls OnClose instead of choosing the tab. A tab
    pressed (and so chosen) and dragged along the row changes places with a neighbour the moment
    the pointer reaches it, in the direction the pointer moves (TabReorderStep, as the dock's tabs;
    OnMove after each step); Esc or another window taking the mouse puts it back where it was. }
  TSdFileTabs = class(TTabControl)
  private
    FCloser: TSdPressBoxes;
    FHotTab: Integer;
    FOnClose: TSdTabCloseEvent;
    FPress: Integer;              // the tab the left button went down on (-1: none); it moves while dragged
    FPressOrigin: Integer;        // ... its place when the press began
    FLastX: Integer;              // ... where the pointer was at the last move (the press first)
    FDragging: Boolean;           // ... the pointer moved with the button down: the row holds the mouse
    FOnMove: TSdTabMoveEvent;
    function BoxOf(Index: Integer; out R: TRect): Boolean;
    procedure SetHotTab(Value: Integer);
    procedure DragTo(Index: Integer);
    procedure EndPress;
    procedure PressCancelled(Sender: TObject);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure WMLButtonUp(var Message: TWMLButtonUp); message WM_LBUTTONUP;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure CreateWnd; override;
    procedure PaintWindow(DC: HDC); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function RowHeight: Integer;                  // the height of the tabs
    { the tabs made higher (TabHeight) when RowHeight is less than MinHeight: what lies beside
      them in the row (Back / Forward, the open files' drop-down) is as high as the row }
    procedure FitRowHeight(MinHeight: Integer);
    function TabTextW(Index: Integer): WideString;
    procedure SetTabTextW(Index: Integer; const W: WideString);
    { tab FromIndex to ToIndex with its title and object, the chosen tab still chosen (no OnChange,
      no OnMove: the caller moves what belongs to the tabs) }
    procedure MoveTab(FromIndex, ToIndex: Integer);
    { test mode: 'title@left-right/box left,top,right,bottom;...' (client coordinates) }
    function DebugTabs: string;
    property OnClose: TSdTabCloseEvent read FOnClose write FOnClose;
    { a dragged tab changed places (MoveTab done): what belongs to the tabs follows }
    property OnMove: TSdTabMoveEvent read FOnMove write FOnMove;
  end;

implementation

uses
  SysUtils, SdEncoding;

const
  TabPad = 8;            // between the title and the ends of its tab
  MinTab = 32;            // a tab is cut down to this when the strip is too short

function TabReorderStep(X, Dir, Lo, Hi: Integer; HasPrev, HasNext: Boolean): Integer;
begin
  if (Dir > 0) and HasNext and (X >= Hi) then Result := 1
  else if (Dir < 0) and HasPrev and (X < Lo) then Result := -1
  else Result := 0;
end;

{ ---------------------------------------------------------------- TSdPressBoxes }

constructor TSdPressBoxes.Create(AControl: TWinControl; ABox: TSdTabBoxFunc);
begin
  inherited Create;
  FControl := AControl;
  FBox := ABox;
  FHot := -1;
  FDown := -1;
end;

function TSdPressBoxes.BoxAt(X, Y: Integer): Integer;
var
  R: TRect;
begin
  Result := 0;
  while FBox(Result, R) do
  begin
    if PtInRect(R, Point(X, Y)) then Exit;
    Inc(Result);
  end;
  Result := -1;
end;

function TSdPressBoxes.State(Index: Integer): TUIButtonState;
begin
  if Index < 0 then Result := bsNormal
  else if FDown >= 0 then
  begin
    if (Index = FDown) and (Index = FHot) then Result := bsDown else Result := bsNormal;
  end
  else if Index = FHot then Result := bsHot
  else Result := bsNormal;
end;

procedure TSdPressBoxes.Repaint(Index: Integer);
var
  R: TRect;
begin
  if (Index >= 0) and FControl.HandleAllocated and FBox(Index, R) then
    InvalidateRect(FControl.Handle, @R, False);
end;

procedure TSdPressBoxes.SetHot(Value: Integer);
begin
  if Value = FHot then Exit;
  Repaint(FHot);
  FHot := Value;
  Repaint(FHot);
end;

function TSdPressBoxes.Press(X, Y: Integer): Boolean;
var
  I: Integer;
begin
  I := BoxAt(X, Y);
  SetHot(-1);
  FDown := I;
  SetHot(I);
  Result := I >= 0;
end;

procedure TSdPressBoxes.Move(X, Y: Integer);
begin
  SetHot(BoxAt(X, Y));
end;

function TSdPressBoxes.Release(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if FDown < 0 then Exit;
  I := BoxAt(X, Y);
  if I = FDown then Result := I;
  Repaint(FDown);
  FDown := -1;
  SetHot(-1);
  SetHot(I);
end;

procedure TSdPressBoxes.Reset;
begin
  Repaint(FDown);
  FDown := -1;
  SetHot(-1);
end;

function TSdPressBoxes.Pressed: Boolean;
begin
  Result := FDown >= 0;
end;

{ ---------------------------------------------------------------- TSdTabStrip }

constructor TSdTabStrip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls, csSetCaption, csParentBackground];
  FTabs := TStringList.Create;
  FTabs.OnChange := TabsChanged;
  FTabIndex := -1;
  FHot := -1;
  Height := UIDockTabHeight;
  Buffered := True;
  RedrawWhole := True;
end;

destructor TSdTabStrip.Destroy;
begin
  FTabs.Free;
  inherited;
end;

function TSdTabStrip.GetTabs: TStrings;
begin
  Result := FTabs;
end;


procedure TSdTabStrip.TabsChanged(Sender: TObject);
begin
  if FTabIndex >= FTabs.Count then FTabIndex := FTabs.Count - 1;
  FHot := -1;
  Arrange;
  Invalidate;
end;

procedure TSdTabStrip.SetTabIndex(Value: Integer);
begin
  if (Value < -1) or (Value >= FTabs.Count) then Value := -1;
  if Value <> FTabIndex then
  begin
    InvalidateTab(FTabIndex);
    FTabIndex := Value;
    InvalidateTab(FTabIndex);
  end;
end;

procedure TSdTabStrip.SetHot(Value: Integer);
begin
  if Value = FHot then Exit;
  InvalidateTab(FHot);
  FHot := Value;
  InvalidateTab(FHot);
end;

procedure TSdTabStrip.InvalidateTab(Index: Integer);
var
  R: TRect;
begin
  if (Index < 0) or (Index > High(FRects)) or not HandleAllocated then Exit;
  R := FRects[Index];
  InvalidateRect(Handle, @R, False);
end;

procedure TSdTabStrip.SetItems(Items: TStrings);
var
  I: Integer;
  Same: Boolean;
begin
  Same := Items.Count = FTabs.Count;
  for I := 0 to Items.Count - 1 do
    if Same and ((FTabs.Objects[I] <> Items.Objects[I]) or (FTabs[I] <> Items[I])) then Same := False;
  if not Same then FTabs.Assign(Items);         // one change (TStrings.Assign: BeginUpdate)
end;

function TSdTabStrip.TabObject(Index: Integer): TObject;
begin
  Result := FTabs.Objects[Index];
end;

function TSdTabStrip.TabName(Index: Integer): string;
begin
  Result := FTabs[Index];
end;

function TSdTabStrip.TabImage(Index: Integer): Integer;
begin
  Result := -1;
end;

function TSdTabStrip.TabImages: TCustomImageList;
begin
  Result := FImages;
end;

function TSdTabStrip.TabTextColor(Index: Integer): TColor;
begin
  Result := clNone;
end;

procedure TSdTabStrip.SetImages(Value: TCustomImageList);
begin
  if Value = FImages then Exit;
  FImages := Value;
  LooksChanged;
end;

procedure TSdTabStrip.LooksChanged;
begin
  Arrange;
  Invalidate;
end;

function TSdTabStrip.DebugPositions: string;
var
  I, Lo, Hi: Integer;
begin
  Result := '';
  for I := 0 to FTabs.Count - 1 do
  begin
    if I > 0 then Result := Result + ',';
    TabSpan(I, Lo, Hi);
    Result := Result + Format('%s@%d-%d', [TabName(I), Lo, Hi]);
  end;
end;

procedure TSdTabStrip.SetSide(Value: TUITabSide);
begin
  if Value = FSide then Exit;
  FSide := Value;
  Arrange;
  Invalidate;
end;

function TSdTabStrip.Vertical: Boolean;
begin
  Result := FSide in [tsLeft, tsRight];
end;

{ the tabs as long as their titles, all cut down alike when the strip is too short (the titles
  then end in an ellipsis); measured on the screen, so that it works before the strip has a
  window. A tab fills the strip across. }
procedure TSdTabStrip.Arrange;
var
  I, X, Total, Avail, Len: Integer;
  W: array of Integer;
  DC: HDC;
  Old: HGDIOBJ;
begin
  SetLength(FRects, FTabs.Count);
  SetLength(W, FTabs.Count);
  Total := 0;
  DC := GetDC(0);
  Old := SelectObject(DC, UIFont.Handle);
  try
    for I := 0 to FTabs.Count - 1 do
    begin
      W[I] := UITextWidth(DC, FTabs[I]) + 2 * TabPad + UITabImageRoom(TabImages, TabImage(I));
      Inc(Total, W[I]);
    end;
  finally
    SelectObject(DC, Old);
    ReleaseDC(0, DC);
  end;
  if Vertical then Len := Height else Len := Width;
  Avail := Len;
  if (Total > Avail) and (Total > 0) then
    for I := 0 to FTabs.Count - 1 do
    begin
      W[I] := W[I] * Avail div Total;
      if W[I] < MinTab then W[I] := MinTab;
    end;
  X := 0;
  for I := 0 to FTabs.Count - 1 do
  begin
    if Vertical then FRects[I] := Rect(0, X, Width, X + W[I])
    else FRects[I] := Rect(X, 0, X + W[I], Height);
    Inc(X, W[I]);
  end;
end;

procedure TSdTabStrip.Resize;
begin
  inherited;
  Arrange;
  Invalidate;
end;

function TSdTabStrip.TabRect(Index: Integer): TRect;
begin
  Result := FRects[Index];
end;

procedure TSdTabStrip.TabSpan(Index: Integer; out Lo, Hi: Integer);
begin
  if Vertical then
  begin
    Lo := FRects[Index].Top;
    Hi := FRects[Index].Bottom;
  end
  else
  begin
    Lo := FRects[Index].Left;
    Hi := FRects[Index].Right;
  end;
end;


function TSdTabStrip.TabAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if (X < 0) or (X >= Width) or (Y < 0) or (Y >= Height) then Exit;
  for I := 0 to High(FRects) do
    if Vertical and (Y >= FRects[I].Top) and (Y < FRects[I].Bottom) or
      not Vertical and (X >= FRects[I].Left) and (X < FRects[I].Right) then
    begin
      Result := I;
      Exit;
    end;
end;

{ what is to be painted (the tabs that changed, else all) in the bitmap, then copied in one piece }
procedure TSdTabStrip.PaintBuffer(C: TCanvas);
var
  I: Integer;
  S: TUIButtonState;
  Clip, X: TRect;
  DC: HDC;
begin
  DC := C.Handle;
  Clip := Canvas.ClipRect;
  UIFill(DC, Clip, clBtnFace);
  for I := 0 to High(FRects) do
    if IntersectRect(X, FRects[I], Clip) then
    begin
      if I = FTabIndex then S := bsChecked
      else if I = FHot then S := bsHot
      else S := bsNormal;
      UIDrawTab(DC, FRects[I], ToWide(FTabs[I], CP_ACP), S, FSide, False, bsNormal, TabImages, TabImage(I),
        TabTextColor(I));
    end;
end;

procedure TSdTabStrip.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  SetHot(-1);
end;


procedure TSdTabStrip.Choose(Index: Integer);
begin
  TabIndex := Index;
  if Assigned(FOnChange) then FOnChange(Self);
end;

{ positions come from the mouse messages }
procedure TSdTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited;
  I := TabAt(X, Y);
  if (I >= 0) and (I <> FTabIndex) and (Button in [mbLeft, mbRight]) then Choose(I);
end;

procedure TSdTabStrip.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if not (ssLeft in Shift) then SetHot(TabAt(X, Y));
end;


{ ---------------------------------------------------------------- TSdFileTabs }

const
  ItemPadX = 6;           // comctl32's own padding at each end of a title, and above and below it
  ItemPadY = 3;

constructor TSdFileTabs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCloser := TSdPressBoxes.Create(Self, BoxOf);
  FHotTab := -1;
  FPress := -1;
  UIOnPressCancel(Self, PressCancelled);         // a tab dragged along the row
end;

destructor TSdFileTabs.Destroy;
begin
  FreeAndNil(FCloser);
  inherited;
end;

{ the title ends a close box before the tab's end; the tab control centres it, so the same room
  lies before it. No minimum width: the control's own (74 px here) applied only to tabs whose
  title was set again, so a tab that lost its modified mark stayed wider than it was opened }
procedure TSdFileTabs.CreateWnd;
begin
  inherited CreateWnd;
  SendMessage(Handle, TCM_SETPADDING, 0, MakeLParam(ItemPadX + UITabCloseRoom, ItemPadY));
  SendMessage(Handle, TCM_SETMINTABWIDTH, 0, 0);
end;

{ the row of tabs: as high as the control makes its items }
function TSdFileTabs.RowHeight: Integer;
var
  R: TRect;
begin
  Result := UIDockTabHeight;
  if HandleAllocated and (Tabs.Count > 0) and
    (SendMessage(Handle, TCM_GETITEMRECT, 0, Integer(@R)) <> 0) then Result := R.Bottom;
end;

{ with a small UI font (Tahoma 8) the tabs were 20 px and the tool buttons beside them 22 px
  (a 16 px image and its frame - a tool bar makes no button lower): the buttons' bottom was cut
  off, so the tabs are raised to the buttons' height }
procedure TSdFileTabs.FitRowHeight(MinHeight: Integer);
var
  R: TRect;
begin
  if RowHeight >= MinHeight then Exit;
  if HandleAllocated and (Tabs.Count > 0) and
    (SendMessage(Handle, TCM_GETITEMRECT, 0, Integer(@R)) <> 0) then
    TabHeight := MinHeight - R.Top;     // the row ends at the item's bottom (RowHeight)
end;

function TSdFileTabs.TabTextW(Index: Integer): WideString;
var
  Item: TTCItemW;
  Buf: array[0..MAX_PATH] of WideChar;
begin
  FillChar(Item, SizeOf(Item), 0);
  Item.mask := TCIF_TEXT;
  Item.pszText := Buf;
  Item.cchTextMax := Length(Buf);
  Buf[0] := #0;
  if HandleAllocated and (SendMessage(Handle, TCM_GETITEMW, Index, LPARAM(@Item)) <> 0) then
    Result := Item.pszText
  else
    Result := ToWide(Tabs[Index], CP_ACP);
end;

procedure TSdFileTabs.SetTabTextW(Index: Integer; const W: WideString);
var
  Item: TTCItemW;
begin
  FillChar(Item, SizeOf(Item), 0);
  Item.mask := TCIF_TEXT;
  Item.pszText := PWideChar(W);
  SendMessage(Handle, TCM_SETITEMW, Index, LPARAM(@Item));
  Invalidate;
end;

{ Windows' tab control has no move: the tab goes and comes again (TStrings.Move, one repaint) with
  its title as the control had it - a name outside the code page too }
procedure TSdFileTabs.MoveTab(FromIndex, ToIndex: Integer);
var
  W: WideString;
  Chosen: Integer;
begin
  if (FromIndex = ToIndex) or (FromIndex < 0) or (ToIndex < 0) or (FromIndex >= Tabs.Count) or
    (ToIndex >= Tabs.Count) then Exit;
  W := TabTextW(FromIndex);
  Chosen := TabIndex;
  if Chosen = FromIndex then Chosen := ToIndex
  else if (FromIndex < Chosen) and (ToIndex >= Chosen) then Dec(Chosen)
  else if (FromIndex > Chosen) and (ToIndex <= Chosen) then Inc(Chosen);
  Tabs.Move(FromIndex, ToIndex);
  if HandleAllocated then SetTabTextW(ToIndex, W);
  TabIndex := Chosen;
end;

function TSdFileTabs.DebugTabs: string;
var
  I: Integer;
  R, B: TRect;
begin
  Result := '';
  if not HandleAllocated then Exit;
  for I := 0 to Tabs.Count - 1 do
  begin
    R := TabRect(I);
    if not BoxOf(I, B) then B := Rect(0, 0, 0, 0);
    Result := Result + Format('%s@%d-%d/%d,%d,%d,%d;', [Tabs[I], R.Left, R.Right, B.Left, B.Top,
      B.Right, B.Bottom]);
  end;
end;

function TSdFileTabs.BoxOf(Index: Integer; out R: TRect): Boolean;
begin
  Result := (Index >= 0) and (Index < Tabs.Count) and HandleAllocated;
  if Result then
  begin
    R := TabRect(Index);
    R.Top := 0;
    R.Bottom := RowHeight;
    R := UITabCloseRect(R);
  end;
end;

procedure TSdFileTabs.SetHotTab(Value: Integer);
var
  R: TRect;
begin
  if Value = FHotTab then Exit;
  FHotTab := Value;
  if HandleAllocated then
  begin
    R := Rect(0, 0, ClientWidth, RowHeight);
    InvalidateRect(Handle, @R, False);
  end;
end;

{ the VCL paints the control through PaintWindow also when it has no pages yet }
procedure TSdFileTabs.WMPaint(var Message: TWMPaint);
begin
  ControlState := ControlState + [csCustomPaint];
  inherited;
  ControlState := ControlState - [csCustomPaint];
end;

{ The control's own painting (its themed tabs and frame) is covered: the face colour, the tabs
  on it. Painted into the VCL's buffer (DoubleBuffered: no flicker). }
procedure TSdFileTabs.PaintWindow(DC: HDC);
var
  I, Row: Integer;
  R: TRect;
  S: TUIButtonState;
begin
  Row := RowHeight;
  UIFill(DC, Rect(0, 0, ClientWidth, ClientHeight), clBtnFace);
  for I := 0 to Tabs.Count - 1 do
  begin
    R := TabRect(I);
    R.Top := 0;
    R.Bottom := Row;
    if I = TabIndex then S := bsChecked
    else if I = FHotTab then S := bsHot
    else S := bsNormal;
    UIDrawTab(DC, R, TabTextW(I), S, tsTop, True, FCloser.State(I));
  end;
end;

{ a press on a box does not reach the tab control: the tab is not chosen. A press on a tab chooses
  it (the tab control: OnChange) and may become a drag of it along the row - the row takes the
  mouse only then, at a move with the button still down (a dialog that came up meanwhile took the
  press) }
procedure TSdFileTabs.WMLButtonDown(var Message: TWMLButtonDown);
begin
  if (FCloser <> nil) and FCloser.Press(Message.XPos, Message.YPos) then
    MouseCapture := True
  else
  begin
    inherited;
    FPress := IndexOfTabAt(Message.XPos, Message.YPos);
    FPressOrigin := FPress;
    FLastX := Message.XPos;
    FDragging := False;
  end;
end;

{ the pressed tab changes places with tab Index (OnMove follows); a tab list changed meanwhile ends
  the drag }
procedure TSdFileTabs.DragTo(Index: Integer);
var
  From: Integer;
begin
  From := FPress;
  if (From < 0) or (From >= Tabs.Count) or (Index < 0) or (Index >= Tabs.Count) then
  begin
    EndPress;
    Exit;
  end;
  if Index = From then Exit;
  MoveTab(From, Index);
  FPress := Index;
  if Assigned(FOnMove) then FOnMove(Self, From, Index);
end;

procedure TSdFileTabs.EndPress;
var
  Held: Boolean;
begin
  Held := FDragging;
  FPress := -1;
  FDragging := False;
  if Held and MouseCapture then MouseCapture := False;
end;

{ Esc, or another window took the mouse (UIOnPressCancel): a dragged tab goes back to where the
  press found it; a pressed close box closes nothing }
procedure TSdFileTabs.PressCancelled(Sender: TObject);
begin
  if FDragging and (FPress >= 0) and (FPress <> FPressOrigin) then DragTo(FPressOrigin);
  EndPress;
  if (FCloser <> nil) and FCloser.Pressed then
  begin
    FCloser.Reset;
    if MouseCapture then MouseCapture := False;
  end;
end;

procedure TSdFileTabs.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  if (FCloser <> nil) and (FCloser.BoxAt(Message.XPos, Message.YPos) >= 0) then
    WMLButtonDown(TWMLButtonDown(Message))
  else
    inherited;
end;

procedure TSdFileTabs.WMLButtonUp(var Message: TWMLButtonUp);
var
  I: Integer;
begin
  if (FCloser = nil) or not FCloser.Pressed then
  begin
    EndPress;                     // a dragged tab stays where it is now
    inherited;
    Exit;
  end;
  I := FCloser.Release(Message.XPos, Message.YPos);
  MouseCapture := False;
  if (I >= 0) and Assigned(FOnClose) then FOnClose(Self, I);
end;

{ a dragged tab follows the pointer at once: it changes places with the neighbour the pointer
  reaches, in the direction the pointer moves (TabReorderStep) }
procedure TSdFileTabs.WMMouseMove(var Message: TWMMouseMove);
var
  X, Dir, Guard: Integer;
  R: TRect;
begin
  inherited;
  if FCloser = nil then Exit;
  if FCloser.Pressed or (Message.Keys and MK_LBUTTON = 0) then FCloser.Move(Message.XPos, Message.YPos);
  if FPress >= 0 then
    if Message.Keys and MK_LBUTTON = 0 then
      EndPress                    // let go elsewhere: a dialog took the press
    else
    begin
      X := Message.XPos;
      Dir := X - FLastX;
      FLastX := X;
      if not FDragging then
      begin
        FDragging := True;
        MouseCapture := True;
      end;
      for Guard := 1 to Tabs.Count do
      begin
        if FPress < 0 then Break;
        R := TabRect(FPress);
        case TabReorderStep(X, Dir, R.Left, R.Right, FPress > 0, FPress + 1 < Tabs.Count) of
          1: DragTo(FPress + 1);
          -1: DragTo(FPress - 1);
        else
          Break;
        end;
      end;
    end;
  SetHotTab(IndexOfTabAt(Message.XPos, Message.YPos));
end;

procedure TSdFileTabs.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FCloser = nil then Exit;
  if not FCloser.Pressed then FCloser.Reset;
  SetHotTab(-1);
end;

procedure TSdFileTabs.WMCaptureChanged(var Message: TMessage);
begin
  inherited;
  if (FCloser <> nil) and UICaptureLost(Self, Message) then FCloser.Reset;
end;

end.