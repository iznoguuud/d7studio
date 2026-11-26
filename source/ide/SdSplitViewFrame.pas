{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSplitViewFrame;

{ D7 Studio - a view of two sides (the Browser, the Type Library view). One side: its
  tabs (if it has any) above its content; the other: a line with an icon and a text (DrawHeader,
  DrawHeaderLine), its tabs, its content. The sides lie side by side when the view is wider than
  tall, else one above the other; the gap between them moves them (the first side's share, per
  mille; Esc puts it back). Each content lies 1 px inside a flat frame (UIDrawBorder). Of the
  controls that can fill a side
  (AddSide), the one ShownFirst / ShownSecond names is placed, the others are hidden; Details
  shows the second side or not. Flicker-free (TSdFrame): no CS_HREDRAW / CS_VREDRAW, no erase,
  the ground around the children painted through a buffer; moves in one batch. A frame, reused:
  the Browser and the Type Library view are frames inherited from it (their trees and lists in
  their .dfm), made by the main form (CreatePanes); the tab strips, D7 Studio's own control, are
  made in code (NewTabs). Flat: the look of a page of the file area, which has the frame (the
  History tab) - no frames, no line above the second side, the gap a flat line on the window's
  colour. }

interface

uses
  Windows, Classes, Graphics, Controls, ComCtrls, CommCtrl, ImgList, SdUI,
  SdBaseFrame, SdTabStrip;

type
  TSdSplitView = class(TSdFrame)
  private
    FFirstTabs, FSecondTabs: TSdTabStrip;
    FFirsts, FSeconds: TList;         // the controls that can fill each side
    FDetails: Boolean;
    FSplit: Integer;
    { a press on the gap: it moves the gap once it is a drag (UIDragStarted), by as much as the
      pointer moved; Esc or the mouse taken away puts the gap back }
    FSplitting, FSplitDragging: Boolean;
    FSplitFrom: TPoint;
    FSplitOld, FSplitStart: Integer;  // FSplit and the gap's place when the press began
    FHeader, FFirstFrame, FSecondFrame, FSplitRect: TRect;
    FPainting: TCanvas;               // the buffer's canvas while PaintBuffer runs
    FFlat: Boolean;
    procedure SetDetails(Value: Boolean);
    procedure SetFlat(Value: Boolean);
    procedure SplitCancelled(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure PaintBuffer(C: TCanvas); override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function SideBySide: Boolean;
    procedure Arrange;
    { the tab strip of a side (one each) and a control that can fill a side (its child) }
    function NewTabs(const Titles: array of string; First: Boolean): TSdTabStrip;
    procedure AddSide(C: TWinControl; First: Boolean);
    function ShownFirst: TWinControl; virtual;      // default: the first one added
    function ShownSecond: TWinControl; virtual;
    procedure DrawHeader(const R: TRect); virtual;  // the line above the second side's tabs
    { the line as the views draw it: image ImageIndex of Images 3 px in, centred from top to
      bottom, and Text from 23 px on in the view's font (one line, an ellipsis where it is cut);
      into the paint's buffer - only DrawHeader calls it }
    procedure DrawHeaderLine(const R: TRect; Images: TCustomImageList; ImageIndex: Integer;
      const Text: string);
    procedure DetailsChanged; virtual;              // Details was switched
    procedure InvalidateHeader;
    { a list view with one column: the column as wide as the list (without its scroll bar).
      TListColumn.Width keeps the value and sends nothing when it is the same again: set while
      the list was empty or hidden, the column stayed 0 px wide. }
    procedure FitColumn(V: TListView);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Details: Boolean read FDetails write SetDetails;
    property Flat: Boolean read FFlat write SetFlat;
    { the first side's share of the view, per mille (100 .. 900): the gap's place }
    property Split: Integer read FSplit write FSplit;
  end;

implementation

{$R *.dfm}

const
  SplitGap = 4;

constructor TSdSplitView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque] - [csSetCaption];
  Color := clBtnFace;
  FDetails := True;
  FSplit := 400;
  FFirsts := TList.Create;
  FSeconds := TList.Create;
  Buffered := True;
  UIOnPressCancel(Self, SplitCancelled);
end;

destructor TSdSplitView.Destroy;
begin
  FFirsts.Free;
  FSeconds.Free;
  inherited Destroy;
end;

procedure TSdSplitView.CreateWnd;
begin
  inherited CreateWnd;
  Arrange;
end;

function TSdSplitView.NewTabs(const Titles: array of string; First: Boolean): TSdTabStrip;
var
  I: Integer;
begin
  Result := TSdTabStrip.Create(Self);
  Result.Parent := Self;
  Result.Side := tsTop;
  for I := Low(Titles) to High(Titles) do Result.Tabs.Add(Titles[I]);
  Result.TabIndex := 0;
  if First then FFirstTabs := Result else FSecondTabs := Result;
end;

procedure TSdSplitView.AddSide(C: TWinControl; First: Boolean);
begin
  C.Parent := Self;                  // a control of the .dfm is the frame's already; the tabs are made here
  if First then FFirsts.Add(C) else FSeconds.Add(C);
end;

function TSdSplitView.ShownFirst: TWinControl;
begin
  if FFirsts.Count > 0 then Result := TWinControl(FFirsts[0]) else Result := nil;
end;

function TSdSplitView.ShownSecond: TWinControl;
begin
  if FSeconds.Count > 0 then Result := TWinControl(FSeconds[0]) else Result := nil;
end;

procedure TSdSplitView.DrawHeader(const R: TRect);
begin
end;

procedure TSdSplitView.DrawHeaderLine(const R: TRect; Images: TCustomImageList; ImageIndex: Integer;
  const Text: string);
var
  T: TRect;
  C: TCanvas;
begin
  C := FPainting;
  if C = nil then Exit;
  T := R;
  Images.Draw(C, T.Left + 3, T.Top + (T.Bottom - T.Top - Images.Height) div 2, ImageIndex);
  T.Left := T.Left + 23;
  C.Font := Font;
  C.Brush.Style := bsClear;
  DrawText(C.Handle, PChar(Text), Length(Text), T, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or
    DT_NOPREFIX);
  C.Brush.Style := bsSolid;
end;

procedure TSdSplitView.DetailsChanged;
begin
end;

procedure TSdSplitView.InvalidateHeader;
begin
  if HandleAllocated then InvalidateRect(Handle, @FHeader, False);
end;

procedure TSdSplitView.FitColumn(V: TListView);
begin
  if V.HandleAllocated then ListView_SetColumnWidth(V.Handle, 0, LVSCW_AUTOSIZE_USEHEADER);
end;

function TSdSplitView.SideBySide: Boolean;
begin
  Result := ClientWidth >= ClientHeight;
end;

{ the first side's tabs and content; the gap; the line, the tabs and the content of the second
  side - beside the first or below it; everything in one batch }
procedure TSdSplitView.Arrange;
var
  W, H, TabH, FirstTabH, SecondTabH, LineH, S, X, Y, I: Integer;
  Ctl: array of TWinControl;
  Rc: array of TRect;
  FirstR, SecondR, FirstTabsR, SecondTabsR: TRect;
  A, B: TWinControl;

  procedure Put(C: TWinControl; const R: TRect);
  begin
    if C = nil then Exit;
    SetLength(Ctl, Length(Ctl) + 1);
    SetLength(Rc, Length(Rc) + 1);
    Ctl[High(Ctl)] := C;
    Rc[High(Rc)] := R;
  end;

begin
  { not while the frame's .dfm is read: the sides of a derived view are not all there yet }
  if not HandleAllocated or (csLoading in ComponentState) then Exit;
  W := ClientWidth;
  H := ClientHeight;
  if (W <= 0) or (H <= 0) then Exit;
  TabH := UIDockTabHeight;
  if FFirstTabs <> nil then FirstTabH := TabH else FirstTabH := 0;
  if FSecondTabs <> nil then SecondTabH := TabH else SecondTabH := 0;
  if FFlat then LineH := 0 else LineH := UITextHeight + 8;
  FirstTabsR := Rect(0, 0, W, FirstTabH);
  FFirstFrame := Rect(0, FirstTabH, W, H);
  FSplitRect := Rect(0, 0, 0, 0);
  FHeader := Rect(0, 0, 0, 0);
  FSecondFrame := Rect(0, 0, 0, 0);
  SecondTabsR := Rect(0, 0, 0, 0);
  if FDetails then
    if SideBySide then
    begin
      S := W * FSplit div 1000;
      if S > W - 60 then S := W - 60;
      if S < 60 then S := 60;
      FirstTabsR.Right := S;
      FFirstFrame.Right := S;
      FSplitRect := Rect(S, 0, S + SplitGap, H);
      X := S + SplitGap;
      FHeader := Rect(X, 0, W, LineH);
      SecondTabsR := Rect(X, LineH, W, LineH + SecondTabH);
      FSecondFrame := Rect(X, LineH + SecondTabH, W, H);
    end
    else
    begin
      S := H * FSplit div 1000;
      if S > H - 60 then S := H - 60;
      if S < FirstTabH + 30 then S := FirstTabH + 30;
      FFirstFrame.Bottom := S;
      FSplitRect := Rect(0, S, W, S + SplitGap);
      Y := S + SplitGap;
      FHeader := Rect(0, Y, W, Y + LineH);
      SecondTabsR := Rect(0, Y + LineH, W, Y + LineH + SecondTabH);
      FSecondFrame := Rect(0, Y + LineH + SecondTabH, W, H);
    end;
  if FFlat then
  begin
    FirstR := FFirstFrame;
    SecondR := FSecondFrame;
  end
  else
  begin
    with FFirstFrame do FirstR := Rect(Left + 1, Top + 1, Right - 1, Bottom - 1);
    with FSecondFrame do SecondR := Rect(Left + 1, Top + 1, Right - 1, Bottom - 1);
  end;
  if FirstR.Bottom < FirstR.Top then FirstR.Bottom := FirstR.Top;
  if SecondR.Bottom < SecondR.Top then SecondR.Bottom := SecondR.Top;
  if SecondR.Right < SecondR.Left then SecondR.Right := SecondR.Left;
  A := ShownFirst;
  B := ShownSecond;
  Put(FFirstTabs, FirstTabsR);
  Put(FSecondTabs, SecondTabsR);
  Put(A, FirstR);
  Put(B, SecondR);
  for I := 0 to FFirsts.Count - 1 do
    if FFirsts[I] <> A then Put(TWinControl(FFirsts[I]), Rect(0, 0, 0, 0));
  for I := 0 to FSeconds.Count - 1 do
    if FSeconds[I] <> B then Put(TWinControl(FSeconds[I]), Rect(0, 0, 0, 0));
  UIMoveControls(Ctl, Rc);
  { the shown ones first: a tab chosen keeps the keyboard in the view - from what goes to what
    takes its place on that side (the first side's when the details go) }
  if A <> nil then A.Visible := True;
  if FDetails and (B <> nil) then B.Visible := True;
  for I := 0 to FFirsts.Count - 1 do
    if FFirsts[I] <> A then
    begin
      UIPassKeyboard(TWinControl(FFirsts[I]), A);
      TWinControl(FFirsts[I]).Visible := False;
    end;
  for I := 0 to FSeconds.Count - 1 do
    if not FDetails or (FSeconds[I] <> B) then
    begin
      if FDetails then UIPassKeyboard(TWinControl(FSeconds[I]), B)
      else UIPassKeyboard(TWinControl(FSeconds[I]), A);
      TWinControl(FSeconds[I]).Visible := False;
    end;
  if FSecondTabs <> nil then FSecondTabs.Visible := FDetails;
  for I := 0 to FFirsts.Count - 1 do
    if TObject(FFirsts[I]) is TListView then FitColumn(TListView(FFirsts[I]));
  for I := 0 to FSeconds.Count - 1 do
    if (TObject(FSeconds[I]) is TListView) and (TListView(FSeconds[I]).Columns.Count = 1) then
      FitColumn(TListView(FSeconds[I]));
  Invalidate;
end;

procedure TSdSplitView.Resize;
begin
  inherited Resize;
  Arrange;
end;

procedure TSdSplitView.SetDetails(Value: Boolean);
begin
  if Value = FDetails then Exit;
  FDetails := Value;
  Arrange;
  DetailsChanged;
end;

procedure TSdSplitView.SetFlat(Value: Boolean);
begin
  if Value = FFlat then Exit;
  FFlat := Value;
  if FFlat then Color := clWindow else Color := clBtnFace;
  Arrange;
end;

{ the ground around the children (they are clipped), the frames and the line, in the buffer -
  the line's text is never seen erased }
procedure TSdSplitView.PaintBuffer(C: TCanvas);
begin
  if FFlat then
  begin
    C.Brush.Color := clWindow;
    C.FillRect(Canvas.ClipRect);
    if not FDetails then Exit;
    with FSplitRect do
      if SideBySide then UIVLine(C.Handle, (Left + Right) div 2, Top, Bottom, clBtnShadow)
      else UIHLine(C.Handle, Left, Right, (Top + Bottom) div 2, clBtnShadow);
    Exit;
  end;
  C.Brush.Color := clBtnFace;
  C.FillRect(Canvas.ClipRect);
  UIDrawBorder(C.Handle, FFirstFrame);
  if not FDetails then Exit;
  UIDrawBorder(C.Handle, FSecondFrame);
  FPainting := C;
  try
    DrawHeader(FHeader);
  finally
    FPainting := nil;
  end;
end;

{ --- the gap between the sides --- }

procedure TSdSplitView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and FDetails and PtInRect(FSplitRect, Point(X, Y)) then
  begin
    FSplitting := True;
    FSplitDragging := False;
    FSplitFrom := Point(X, Y);
    FSplitOld := FSplit;
    if SideBySide then FSplitStart := FSplitRect.Left else FSplitStart := FSplitRect.Top;
    MouseCapture := True;
  end;
end;

procedure TSdSplitView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Total, P: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FSplitting then
  begin
    if not FSplitDragging and UIDragStarted(FSplitFrom, Point(X, Y)) then FSplitDragging := True;
    if not FSplitDragging then Exit;
    if SideBySide then
    begin
      Total := ClientWidth;
      P := FSplitStart + X - FSplitFrom.X;
    end
    else
    begin
      Total := ClientHeight;
      P := FSplitStart + Y - FSplitFrom.Y;
    end;
    if Total <= 0 then Exit;
    FSplit := P * 1000 div Total;
    if FSplit < 100 then FSplit := 100;
    if FSplit > 900 then FSplit := 900;
    Arrange;
    UIPaintNow(Self);                   // each step of the drag painted before the next
  end
  else if FDetails and PtInRect(FSplitRect, Point(X, Y)) then
  begin
    if SideBySide then Cursor := crHSplit else Cursor := crVSplit;
  end
  else
    Cursor := crDefault;
end;

procedure TSdSplitView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FSplitting then
  begin
    FSplitting := False;
    MouseCapture := False;
  end;
end;

{ Esc, or another window took the mouse (UIOnPressCancel): the gap goes back where it was }
procedure TSdSplitView.SplitCancelled(Sender: TObject);
begin
  if not FSplitting then Exit;
  FSplitting := False;
  if FSplit <> FSplitOld then
  begin
    FSplit := FSplitOld;
    Arrange;
  end;
end;

end.
