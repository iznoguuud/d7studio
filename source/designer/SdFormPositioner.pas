{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormPositioner;

{ D7 Studio - the form positioner of the form designer.

  In the lower right corner of the design surface: the monitors in miniature - each with its work
  area and Windows' display number - and the designed form where it opens at run time. Dragging
  the form's miniature moves the form, always whole on the monitor under the pointer - the whole
  monitor, task bar included, as poScreenCenter centres on it -, snapped to that monitor's edges
  and centre lines when it comes near them (Snap);
  OnMoved gets the new Left, Top and Position when the button goes up - poScreenCenter for a form
  snapped to both centre lines of the primary monitor, where the VCL centres it. A double click on a monitor centres the form
  on it. Collapsed, the view is a small monitor glyph, nothing around it; a click on it opens the
  view, with a status line, until the pointer leaves it. The view has the proportions of the
  monitors' bounding box, so the margins are the same all round; a form on no monitor is shown
  dashed where a drag would put it. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, SdUI;

type
  TPositionerMoveEvent = procedure(Sender: TObject; ALeft, ATop: Integer; APosition: TPosition) of object;

  { a monitor as the positioner shows it }
  TPositionerMonitor = record
    Bounds, Work: TRect;              // screen coordinates: the monitor, its work area (poDefault)
    Number: Integer;                  // Windows' display number (\\.\DISPLAYn; 0: none)
    Primary: Boolean;
  end;

  TFormPositioner = class(TSdControl)
  private
    FLeft, FTop, FFormWidth, FFormHeight: Integer;    // the form's values
    FPosition: TPosition;
    FFormColor: TColor;
    FFormRect: TRect;                 // where the form opens at run time (screen coordinates) ...
    FOffScreen: Boolean;              // ... on no monitor: ...
    FShown: TRect;                    // ... the miniature stands at the nearest place it may go
    FMonitors: array of TPositionerMonitor;
    FSignature: string;               // the monitors as they were read last
    FArea: TRect;                     // the monitors' bounding box (screen coordinates) ...
    FInner: TRect;                    // ... and where it lies in the view (client coordinates)
    FPlace: TRect;                    // the room the view lies in, at its lower right
    FExpanded: Boolean;
    FWasExpanded: Boolean;            // the view was large at the last press (a double click's first)
    FPressed, FDragging: Boolean;     // a press on the form's miniature, and the drag it became ...
    FPressAt: TPoint;                 // ... where the press was (client coordinates)
    FGrab: TPoint;                    // ... the pointer's screen point less the form's top left then
    FDragRect: TRect;                 // ... the form's place while it is dragged (screen coordinates)
    FTarget: Integer;                 // ... the monitor it lies on
    FSnapX, FSnapY: Boolean;          // ... centred on that monitor, across / down
    FSnap: Boolean;                   // a dragged form snaps to the monitor's edges and centre lines
    FTracking: Boolean;               // TrackMouseEvent asked for WM_MOUSELEAVE
    FShaped: Boolean;                 // the window has the shape of FShape (ApplyShape) ...
    FShape: TPoint;                   // ... the glyph's size, (0, 0) for no region
    FOnMoved: TPositionerMoveEvent;
    function ReadMonitors: Boolean;
    procedure PlaceForm;
    function MonitorNear(const P: TPoint): Integer;
    function MonitorOf(const R: TRect): Integer;
    function KeepOn(const R: TRect; M: Integer): TRect;
    procedure UpdateBounds;
    function StatusHeight: Integer;
    function ViewX(X: Integer): Integer;
    function ViewY(Y: Integer): Integer;
    function ToView(const R: TRect): TRect;
    function ToScreen(X, Y: Integer): TPoint;
    function MonitorView(M: Integer): TRect;
    function MonitorInner(M: Integer): TRect;
    function ToMonitorView(M: Integer; const R: TRect): TRect;
    function Miniature: TRect;
    function OnMiniature(X, Y: Integer): Boolean;
    function MonitorAt(X, Y: Integer): Integer;
    function StatusText: string;
    procedure DragTo(X, Y: Integer);
    procedure MoveForm(ALeft, ATop: Integer; ScreenCenter: Boolean);
    procedure SetExpanded(Value: Boolean);
    procedure GlyphScreenSize(out W, H: Integer);
    procedure GlyphParts(out Scr, Neck, Foot: TRect);
    procedure ApplyShape;
    procedure PaintCollapsed(DC: HDC);
    procedure PressCancelled(Sender: TObject);
    procedure WMMouseLeave(var Message: TMessage); message WM_MOUSELEAVE;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
  protected
    procedure CreateWnd; override;
    procedure PaintBuffer(C: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    { the form's Left, Top, Width, Height, Position and Color (the miniature's face); the monitors
      are read again. Ignored while the form's miniature is dragged }
    procedure SetForm(ALeft, ATop, AWidth, AHeight: Integer; APosition: TPosition; AColor: TColor);
    { the room the view lies in, at its lower right (the parent's client coordinates); False: the
      room is too small for it }
    function PlaceIn(const R: TRect): Boolean;
    { test mode: expanded|the miniature l,t,r,b|Left,Top|width x height|status line|the monitors
      n:l,t,r,b;... (client coordinates) }
    function TestText: string;
    property Expanded: Boolean read FExpanded write SetExpanded;
    { a dragged form snaps to the monitor's edges and centre lines (the centre lines then show
      dotted); off, it follows the pointer, still whole on the monitor }
    property Snap: Boolean read FSnap write FSnap;
    property OnMoved: TPositionerMoveEvent read FOnMoved write FOnMoved;
  end;

implementation

uses
  Math, MultiMon;

const
  Margin = 8;                         // from the surface's edges (the stage's margin)
  Pad = 6;                            // the border and the space inside it, the same all round
  SnapReach = 4;                      // view pixels within which a dragged form snaps

function RectText(const R: TRect): string;
begin
  Result := Format('%d,%d,%d,%d', [R.Left, R.Top, R.Right, R.Bottom]);
end;

type
  { MONITORINFOEXA as Windows has it (72 bytes): MultiMon's TMonitorInfoEx has a device name one
    character longer, and GetMonitorInfo refuses any cbSize but 40 and 72 }
  TMonitorInfoDevice = record
    cbSize: DWORD;
    rcMonitor, rcWork: TRect;
    dwFlags: DWORD;
    szDevice: array[0..CCHDEVICENAME - 1] of AnsiChar;
  end;

{ the monitors, in Windows' order }
function EnumMonitor(Monitor: HMONITOR; DC: HDC; R: PRect; Data: LPARAM): BOOL; stdcall;
var
  P: TFormPositioner;
  Info: TMonitorInfoDevice;
  N, I: Integer;
  Dev: string;
begin
  P := TFormPositioner(Data);
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if GetMonitorInfo(Monitor, PMonitorInfo(@Info)) then
  begin
    N := Length(P.FMonitors);
    SetLength(P.FMonitors, N + 1);
    P.FMonitors[N].Bounds := Info.rcMonitor;
    P.FMonitors[N].Work := Info.rcWork;
    P.FMonitors[N].Primary := Info.dwFlags and MONITORINFOF_PRIMARY <> 0;
    { \\.\DISPLAY2 -> 2: the number of Windows' display settings }
    I := 0;
    while (I < CCHDEVICENAME) and (Info.szDevice[I] <> #0) do Inc(I);
    SetString(Dev, PChar(@Info.szDevice[0]), I);
    I := Length(Dev);
    while (I > 0) and (Dev[I] in ['0'..'9']) do Dec(I);
    P.FMonitors[N].Number := StrToIntDef(Copy(Dev, I + 1, MaxInt), 0);
  end;
  Result := True;
end;

constructor TFormPositioner.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Buffered := True;
  RedrawWhole := True;                // the miniature is drawn to the view's size
  TabStop := False;
  ShowHint := True;
  Hint := 'Form position: click to show';
  FArea := Rect(0, 0, 1, 1);
  FTarget := -1;
  FSnap := True;
  UIOnPressCancel(Self, PressCancelled);
end;

{ the monitors and their bounding box; True when they changed }
function TFormPositioner.ReadMonitors: Boolean;
var
  I: Integer;
  Sig: string;
begin
  SetLength(FMonitors, 0);
  EnumDisplayMonitors(0, nil, @EnumMonitor, LPARAM(Self));
  if Length(FMonitors) = 0 then
  begin
    { no monitor reported: the primary screen }
    SetLength(FMonitors, 1);
    FMonitors[0].Bounds := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
    SystemParametersInfo(SPI_GETWORKAREA, 0, @FMonitors[0].Work, 0);
    FMonitors[0].Number := 1;
    FMonitors[0].Primary := True;
  end;
  FArea := FMonitors[0].Bounds;
  Sig := '';
  for I := 0 to High(FMonitors) do
  begin
    UnionRect(FArea, FArea, FMonitors[I].Bounds);
    Sig := Sig + RectText(FMonitors[I].Bounds) + '/' + RectText(FMonitors[I].Work) + '/' +
      IntToStr(FMonitors[I].Number) + IntToStr(Ord(FMonitors[I].Primary)) + ';';
  end;
  if FArea.Right <= FArea.Left then FArea.Right := FArea.Left + 1;
  if FArea.Bottom <= FArea.Top then FArea.Bottom := FArea.Top + 1;
  Result := Sig <> FSignature;
  FSignature := Sig;
end;

{ the monitor whose bounds hold P, else the nearest one }
function TFormPositioner.MonitorNear(const P: TPoint): Integer;
var
  I, D, Best, DX, DY: Integer;
  B: TRect;
begin
  Result := 0;
  Best := MaxInt;
  for I := 0 to High(FMonitors) do
  begin
    B := FMonitors[I].Bounds;
    if PtInRect(B, P) then
    begin
      Result := I;
      Exit;
    end;
    DX := Max(B.Left - P.X, Max(0, P.X - (B.Right - 1)));
    DY := Max(B.Top - P.Y, Max(0, P.Y - (B.Bottom - 1)));
    D := Max(DX, DY);
    if D < Best then
    begin
      Best := D;
      Result := I;
    end;
  end;
end;

{ the monitor of a window at R: the one that holds its centre, else the nearest }
function TFormPositioner.MonitorOf(const R: TRect): Integer;
begin
  Result := MonitorNear(Point((R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2));
end;

{ R moved whole onto monitor M (one larger than it from the monitor's top left) }
function TFormPositioner.KeepOn(const R: TRect; M: Integer): TRect;
var
  W, H, L, T: Integer;
  A: TRect;
begin
  A := FMonitors[M].Bounds;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  L := Max(A.Left, Min(R.Left, A.Right - W));
  T := Max(A.Top, Min(R.Top, A.Bottom - H));
  Result := Rect(L, T, L + W, T + H);
end;

{ where the form opens at run time, as the VCL places it: Left and Top (poDesigned,
  poDefaultSizeOnly); centred on the primary monitor (poScreenCenter, and the main form's
  poMainFormCenter / poOwnerFormCenter) or on the desktop (poDesktopCenter); Windows' default
  place at the primary work area's top left (poDefault, poDefaultPosOnly) - and where its
  miniature stands: there, or for a form on no monitor the nearest place a drag may put it }
procedure TFormPositioner.PlaceForm;
var
  I, P, L, T: Integer;
  X: TRect;
begin
  P := 0;
  for I := 0 to High(FMonitors) do
    if FMonitors[I].Primary then P := I;
  case FPosition of
    poScreenCenter, poMainFormCenter, poOwnerFormCenter:
      with FMonitors[P].Bounds do
      begin
        L := Left + (Right - Left - FFormWidth) div 2;
        T := Top + (Bottom - Top - FFormHeight) div 2;
      end;
    poDesktopCenter:
      begin
        L := GetSystemMetrics(SM_XVIRTUALSCREEN) + (GetSystemMetrics(SM_CXVIRTUALSCREEN) - FFormWidth) div 2;
        T := GetSystemMetrics(SM_YVIRTUALSCREEN) + (GetSystemMetrics(SM_CYVIRTUALSCREEN) - FFormHeight) div 2;
      end;
    poDefault, poDefaultPosOnly:
      begin
        L := FMonitors[P].Work.Left;
        T := FMonitors[P].Work.Top;
      end;
  else
    L := FLeft;
    T := FTop;
  end;
  FFormRect := Rect(L, T, L + FFormWidth, T + FFormHeight);
  FOffScreen := True;
  for I := 0 to High(FMonitors) do
    if IntersectRect(X, FFormRect, FMonitors[I].Bounds) then FOffScreen := False;
  if FOffScreen then FShown := KeepOn(FFormRect, MonitorOf(FFormRect)) else FShown := FFormRect;
end;

procedure TFormPositioner.SetForm(ALeft, ATop, AWidth, AHeight: Integer; APosition: TPosition;
  AColor: TColor);
var
  Changed, Monitors: Boolean;
begin
  if FPressed then Exit;
  Changed := (ALeft <> FLeft) or (ATop <> FTop) or (AWidth <> FFormWidth) or (AHeight <> FFormHeight) or
    (APosition <> FPosition) or (AColor <> FFormColor);
  FLeft := ALeft;
  FTop := ATop;
  FFormWidth := Max(AWidth, 1);
  FFormHeight := Max(AHeight, 1);
  FPosition := APosition;
  FFormColor := AColor;
  Monitors := ReadMonitors;
  if Changed or Monitors then PlaceForm;
  { the collapsed glyph has the proportions of the form's monitor: placed again when that can
    have changed }
  if Monitors or (Changed and not FExpanded) then UpdateBounds;
  if Changed or Monitors then Invalidate;
end;

{ the collapsed glyph's screen: the proportions of the monitor the form stands on, with the area of
  a 3:2 screen twice the UI font's height + 4 px wide - every shape looks as large (3:2 itself
  before the monitors are read) }
procedure TFormPositioner.GlyphScreenSize(out W, H: Integer);
var
  S, AW, AH: Integer;
  Area: Double;
  B: TRect;
begin
  S := 2 * UITextHeight + 4;
  if Length(FMonitors) = 0 then
  begin
    W := S;
    H := (2 * S + 1) div 3;
    Exit;
  end;
  B := FMonitors[MonitorOf(FShown)].Bounds;
  AW := Max(B.Right - B.Left, 1);
  AH := Max(B.Bottom - B.Top, 1);
  Area := S * ((2 * S + 1) div 3);
  W := Max(6, Round(Sqrt(Area * AW / AH)));
  H := Max(6, Round(Sqrt(Area * AH / AW)));
end;

function TFormPositioner.PlaceIn(const R: TRect): Boolean;
begin
  FPlace := R;
  UpdateBounds;
  Result := (Width > 0) and (Height > 0);
end;

{ the status line of the large view: the UI font's height and 3 px above and below it }
function TFormPositioner.StatusHeight: Integer;
begin
  if FExpanded then Result := UITextHeight + 6 else Result := 0;
end;

{ Collapsed: the glyph's size - its screen in the proportions of the form's monitor
  (GlyphScreenSize), the stand under it -, so its margins are Margin on both sides; none when the
  room is smaller.
  Expanded: the monitors' bounding box fills the inner box, which has its proportions: the view is
  as large as that box and the margins (Pad) all round, the status line under it. The box is the
  largest of those proportions that fits 48 x 21 lines of the UI font and the room; when the room
  has not even 2 x 1 lines for it, the view collapses to the box again. }
procedure TFormPositioner.UpdateBounds;
var
  BoxW, BoxH, AW, AH, IW, IH, W, H: Integer;
  S: Double;
begin
  if not FExpanded then
  begin
    GlyphScreenSize(W, H);
    Inc(H, 3);                        // the stand under the screen
    if (FPlace.Right - FPlace.Left < W + 2 * Margin) or (FPlace.Bottom - FPlace.Top < H + 2 * Margin) then
    begin
      W := 0;
      H := 0;
    end;
    SetBounds(FPlace.Right - Margin - W, FPlace.Bottom - Margin - H, W, H);
    ApplyShape;
    Exit;
  end;
  ApplyShape;
  BoxW := 48 * UITextHeight;
  BoxH := 21 * UITextHeight;
  BoxW := Min(BoxW, FPlace.Right - FPlace.Left - 2 * Margin - 2 * Pad);
  BoxH := Min(BoxH, FPlace.Bottom - FPlace.Top - 2 * Margin - 2 * Pad - StatusHeight);
  AW := FArea.Right - FArea.Left;
  AH := FArea.Bottom - FArea.Top;
  S := Min(BoxW / AW, BoxH / AH);
  IW := Round(AW * S);
  IH := Round(AH * S);
  if (IW < 2 * UITextHeight) or (IH < UITextHeight) then
  begin
    { no room to open it: the box stays }
    FExpanded := False;
    ShowHint := True;
    UpdateBounds;
    Exit;
  end;
  W := IW + 2 * Pad;
  H := IH + 2 * Pad + StatusHeight;
  FInner := Rect(Pad, Pad, Pad + IW, Pad + IH);
  SetBounds(FPlace.Right - Margin - W, FPlace.Bottom - Margin - H, W, H);
end;

{ screen to view: the bounding box onto the inner box, edge onto edge }
function TFormPositioner.ViewX(X: Integer): Integer;
begin
  Result := FInner.Left + MulDiv(X - FArea.Left, FInner.Right - FInner.Left, FArea.Right - FArea.Left);
end;

function TFormPositioner.ViewY(Y: Integer): Integer;
begin
  Result := FInner.Top + MulDiv(Y - FArea.Top, FInner.Bottom - FInner.Top, FArea.Bottom - FArea.Top);
end;

function TFormPositioner.ToView(const R: TRect): TRect;
begin
  Result := Rect(ViewX(R.Left), ViewY(R.Top), ViewX(R.Right), ViewY(R.Bottom));
end;

{ view to screen: over a monitor the inverse of ToMonitorView, elsewhere of the whole view's scale }
function TFormPositioner.ToScreen(X, Y: Integer): TPoint;
var
  I: Integer;
  B, V: TRect;
begin
  for I := 0 to High(FMonitors) do
    if PtInRect(MonitorView(I), Point(X, Y)) then
    begin
      B := FMonitors[I].Bounds;
      V := MonitorInner(I);
      Result.X := B.Left + MulDiv(X - V.Left, B.Right - B.Left, Max(V.Right - V.Left, 1));
      Result.Y := B.Top + MulDiv(Y - V.Top, B.Bottom - B.Top, Max(V.Bottom - V.Top, 1));
      Exit;
    end;
  Result.X := FArea.Left + MulDiv(X - FInner.Left, FArea.Right - FArea.Left, Max(FInner.Right - FInner.Left, 1));
  Result.Y := FArea.Top + MulDiv(Y - FInner.Top, FArea.Bottom - FArea.Top, Max(FInner.Bottom - FInner.Top, 1));
end;

{ a monitor in the view, 1 px in from its edges: monitors side by side lie apart }
function TFormPositioner.MonitorView(M: Integer): TRect;
begin
  Result := ToView(FMonitors[M].Bounds);
  InflateRect(Result, -1, -1);
end;

{ inside a monitor's frame: what its bounds are drawn onto }
function TFormPositioner.MonitorInner(M: Integer): TRect;
begin
  Result := MonitorView(M);
  InflateRect(Result, -1, -1);
end;

{ screen to view on monitor M: its bounds onto the inside of its frame, so a form at the
  monitor's edge (Left 0, Top 0 on the primary one) touches the frame instead of lying over it }
function TFormPositioner.ToMonitorView(M: Integer; const R: TRect): TRect;
var
  B, V: TRect;
begin
  B := FMonitors[M].Bounds;
  V := MonitorInner(M);
  Result.Left := V.Left + MulDiv(R.Left - B.Left, V.Right - V.Left, Max(B.Right - B.Left, 1));
  Result.Right := V.Left + MulDiv(R.Right - B.Left, V.Right - V.Left, Max(B.Right - B.Left, 1));
  Result.Top := V.Top + MulDiv(R.Top - B.Top, V.Bottom - V.Top, Max(B.Bottom - B.Top, 1));
  Result.Bottom := V.Top + MulDiv(R.Bottom - B.Top, V.Bottom - V.Top, Max(B.Bottom - B.Top, 1));
end;

{ the form in the view, at least 5 x 4 pixels: where it is dragged to, else where it stands -
  on the monitor it lies on }
function TFormPositioner.Miniature: TRect;
begin
  if FDragging then Result := ToMonitorView(MonitorOf(FDragRect), FDragRect)
  else Result := ToMonitorView(MonitorOf(FShown), FShown);
  if Result.Right - Result.Left < 5 then Result.Right := Result.Left + 5;
  if Result.Bottom - Result.Top < 4 then Result.Bottom := Result.Top + 4;
end;

{ a small miniature is taken a little beyond its edges }
function TFormPositioner.OnMiniature(X, Y: Integer): Boolean;
var
  R: TRect;
begin
  R := Miniature;
  InflateRect(R, 2, 2);
  Result := PtInRect(R, Point(X, Y));
end;

{ the monitor at a point of the view (-1: none) }
function TFormPositioner.MonitorAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FMonitors) do
    if PtInRect(ToView(FMonitors[I].Bounds), Point(X, Y)) then
    begin
      Result := I;
      Exit;
    end;
end;

function TFormPositioner.StatusText: string;
begin
  if FDragging then
    Result := Format('Left %d, Top %d', [FDragRect.Left, FDragRect.Top])
  else
    case FPosition of
      poScreenCenter: Result := 'Screen center';
      poDesktopCenter: Result := 'Desktop center';
      poMainFormCenter: Result := 'Main form center';
      poOwnerFormCenter: Result := 'Owner form center';
      poDefault, poDefaultPosOnly: Result := 'Windows default';
    else
      if FOffScreen then
        Result := Format('Off screen: Left %d, Top %d', [FLeft, FTop])
      else
        Result := Format('Left %d, Top %d', [FLeft, FTop]);
    end;
end;

procedure TFormPositioner.SetExpanded(Value: Boolean);
begin
  if FExpanded = Value then Exit;
  FExpanded := Value;
  ShowHint := not Value;              // the large view says it in its status line
  UpdateBounds;
  Invalidate;
end;

{ the collapsed glyph's parts in client coordinates: it fills the control - the screen, then 3 px
  of stand, a neck and a foot }
procedure TFormPositioner.GlyphParts(out Scr, Neck, Foot: TRect);
var
  L: Integer;
begin
  Scr := Rect(0, 0, Width, Height - 3);
  L := Width div 2;
  Neck := Rect(L - 1, Scr.Bottom, L + 1, Scr.Bottom + 2);
  Foot := Rect(L - Width div 4, Scr.Bottom + 2, L + Width div 4, Scr.Bottom + 3);
end;

{ Collapsed, the window has the glyph's shape (SetWindowRgn): what lies under it - the design
  surface, the designed form - shows beside the stand, and only the glyph takes the mouse. Open,
  the window is whole. Set after the collapsed size, removed before the open one; a shape the
  window has already stays (SetWindowRgn moves the window and repaints it, and the designer places
  the positioner at each update). }
procedure TFormPositioner.ApplyShape;
var
  Scr, Neck, Foot: TRect;
  Rgn, Part: HRGN;
  Want: TPoint;
begin
  if not HandleAllocated then Exit;
  if FExpanded or (Width = 0) or (Height = 0) then Want := Point(0, 0) else Want := Point(Width, Height);
  if FShaped and (Want.X = FShape.X) and (Want.Y = FShape.Y) then Exit;
  FShaped := True;
  FShape := Want;
  if Want.X = 0 then
  begin
    SetWindowRgn(Handle, 0, True);
    Exit;
  end;
  GlyphParts(Scr, Neck, Foot);
  Rgn := CreateRectRgnIndirect(Scr);
  Part := CreateRectRgnIndirect(Neck);
  CombineRgn(Rgn, Rgn, Part, RGN_OR);
  DeleteObject(Part);
  Part := CreateRectRgnIndirect(Foot);
  CombineRgn(Rgn, Rgn, Part, RGN_OR);
  DeleteObject(Part);
  SetWindowRgn(Handle, Rgn, True);    // the window owns the region from now on
end;

procedure TFormPositioner.CreateWnd;
begin
  inherited CreateWnd;
  FShaped := False;                   // a new window has no region
  ApplyShape;
end;

{ the collapsed glyph: a monitor - its screen in clWindow, a dark frame, a stand under it - with a
  mark in the title bars' colour where the form stands on its monitor; nothing beside the stand
  (ApplyShape) }
procedure TFormPositioner.PaintCollapsed(DC: HDC);
var
  Scr, Neck, Foot, Inner, F, B: TRect;
  M: Integer;
  TitleBack, TitleFore, Edge: TColor;
begin
  Edge := UIBlend(clWindowText, clBtnShadow, 70);
  GlyphParts(Scr, Neck, Foot);
  UIFill(DC, Scr, clWindow);
  UIFrame(DC, Scr, Edge);
  UIFill(DC, Neck, Edge);
  UIFill(DC, Foot, Edge);
  { the form on the monitor it stands on, at least 4 x 3 pixels }
  if Length(FMonitors) > 0 then
  begin
    Inner := Scr;
    InflateRect(Inner, -1, -1);
    M := MonitorOf(FShown);
    B := FMonitors[M].Bounds;
    F.Left := Inner.Left + MulDiv(FShown.Left - B.Left, Inner.Right - Inner.Left, Max(B.Right - B.Left, 1));
    F.Top := Inner.Top + MulDiv(FShown.Top - B.Top, Inner.Bottom - Inner.Top, Max(B.Bottom - B.Top, 1));
    F.Right := Inner.Left + MulDiv(FShown.Right - B.Left, Inner.Right - Inner.Left, Max(B.Right - B.Left, 1));
    F.Bottom := Inner.Top + MulDiv(FShown.Bottom - B.Top, Inner.Bottom - Inner.Top, Max(B.Bottom - B.Top, 1));
    if F.Right - F.Left < 4 then F.Right := F.Left + 4;
    if F.Bottom - F.Top < 3 then F.Bottom := F.Top + 3;
    OffsetRect(F, Max(0, Inner.Left - F.Left) - Max(0, F.Right - Inner.Right),
      Max(0, Inner.Top - F.Top) - Max(0, F.Bottom - Inner.Bottom));
    IntersectRect(F, F, Inner);
    UITitleColors(TitleBack, TitleFore, True);
    UIFill(DC, F, TitleBack);
  end;
end;

procedure TFormPositioner.PaintBuffer(C: TCanvas);
var
  DC: HDC;
  R, M, Wk, F: TRect;
  I, Cap, Bottom, Cur: Integer;
  TitleBack, TitleFore, Edge: TColor;
  S: string;
  OldFont: HFONT;
begin
  DC := C.Handle;
  if not FExpanded then
  begin
    PaintCollapsed(DC);
    Exit;
  end;
  R := ClientRect;
  UIFill(DC, R, clBtnFace);
  Bottom := R.Bottom - StatusHeight;
  OldFont := SelectObject(DC, UIFont.Handle);
  try
    IntersectClipRect(DC, 1, 1, R.Right - 1, Bottom - 1);
    { the monitors, whole (poScreenCenter centres on the whole screen, task bar included): light -
      tinted for the one a drag puts the form on -, the frame grey (the primary monitor's darker);
      in the large view Windows' display number in the middle }
    for I := 0 to High(FMonitors) do
    begin
      M := MonitorView(I);
      if FMonitors[I].Primary then Edge := UIBlend(clWindowText, clBtnShadow, 45)
      else Edge := clBtnShadow;
      Wk := MonitorInner(I);
      if FDragging and (I = FTarget) then UIFill(DC, Wk, UISelectionTint(clWindow))
      else UIFill(DC, Wk, clWindow);
      UIFrame(DC, M, Edge);
      if FExpanded and (FMonitors[I].Number > 0) and (Wk.Bottom - Wk.Top >= UITextHeight + 2) then
        UIText(DC, IntToStr(FMonitors[I].Number), Wk, DT_CENTER or DT_VCENTER or DT_SINGLELINE, clGrayText);
    end;
    { snapped to a centre line of the monitor: the line, dotted }
    if FDragging and (FTarget >= 0) then
    begin
      Wk := MonitorInner(FTarget);
      if FSnapX then UIDottedVLine(DC, (Wk.Left + Wk.Right) div 2, Wk.Top + 1, Wk.Bottom - 1, clHighlight, True);
      if FSnapY then UIDottedHLine(DC, Wk.Left + 1, Wk.Right - 1, (Wk.Top + Wk.Bottom) div 2, clHighlight, True);
    end;
    { the form: its face in the form's colour, a caption bar in the title bars' colour, a dark
      frame - dotted for a form on no monitor, shown where a drag would put it }
    F := Miniature;
    UITitleColors(TitleBack, TitleFore, True);
    Cap := MulDiv(GetSystemMetrics(SM_CYCAPTION), FInner.Bottom - FInner.Top, FArea.Bottom - FArea.Top);
    Cap := Max(2, Min(Cap, (F.Bottom - F.Top) div 3));
    UIFill(DC, F, FFormColor);
    UIFill(DC, Rect(F.Left, F.Top, F.Right, F.Top + Cap), TitleBack);
    Edge := UIBlend(clWindowText, clBtnShadow, 70);
    if FOffScreen and not FDragging then
    begin
      UIFill(DC, Rect(F.Left, F.Top, F.Right, F.Top + 1), clBtnFace);
      UIDottedHLine(DC, F.Left, F.Right, F.Top, Edge, True);
      UIDottedHLine(DC, F.Left, F.Right, F.Bottom - 1, Edge, True);
      UIDottedVLine(DC, F.Left, F.Top, F.Bottom, Edge, True);
      UIDottedVLine(DC, F.Right - 1, F.Top, F.Bottom, Edge, True);
    end
    else
      UIFrame(DC, F, Edge);
    SelectClipRgn(DC, 0);
    { the large view's status line: where the form opens, or goes while it is dragged; the
      display it is on when there are several }
    if FExpanded then
    begin
      UIHLine(DC, 1, R.Right - 1, Bottom - 1, clBtnShadow);
      M := Rect(Pad, Bottom, R.Right - Pad, R.Bottom - 1);
      if FDragging then Cur := FTarget
      else if FOffScreen then Cur := -1           // on none: the miniature only stands nearest
      else Cur := MonitorOf(FShown);
      if (Length(FMonitors) > 1) and (Cur >= 0) and (FMonitors[Cur].Number > 0) then
      begin
        Wk := M;
        UIText(DC, 'Display ' + IntToStr(FMonitors[Cur].Number), Wk,
          DT_RIGHT or DT_VCENTER or DT_SINGLELINE, clGrayText);
        Dec(M.Right, UITextWidth(DC, 'Display 00') + Pad);
      end;
      S := StatusText;
      UIText(DC, S, M, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS, clWindowText);
    end;
  finally
    SelectObject(DC, OldFont);
  end;
  UIDrawBorder(DC, R);
end;

procedure TFormPositioner.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  M: Integer;
  P: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  { a click on the collapsed box opens the view; the box lies at the view's lower right corner,
    so the pointer stays over it }
  if not FExpanded then
  begin
    FWasExpanded := False;
    Expanded := True;
    Exit;
  end;
  { a double click on a monitor of the view (open at its first click): the form centred on it }
  if ssDouble in Shift then
  begin
    M := MonitorAt(X, Y);
    if FWasExpanded and (M >= 0) and not OnMiniature(X, Y) then
      with FMonitors[M].Bounds do
        MoveForm(Max(Left, Left + (Right - Left - FFormWidth) div 2),
          Max(Top, Top + (Bottom - Top - FFormHeight) div 2), False);
    Exit;
  end;
  FWasExpanded := FExpanded;
  if OnMiniature(X, Y) then
  begin
    FPressed := True;
    FDragging := False;
    FPressAt := Point(X, Y);
    P := ToScreen(X, Y);
    FGrab := Point(P.X - FShown.Left, P.Y - FShown.Top);
    FDragRect := FShown;
    FTarget := MonitorOf(FShown);
  end
  else
    Expanded := True;
end;

{ the form under the pointer, kept whole on the monitor there; with Snap, within SnapReach view
  pixels of the monitor's edges or centre lines it goes onto them (a reach of -1 matches nothing) -
  the primary monitor's centre is where poScreenCenter puts a form }
procedure TFormPositioner.DragTo(X, Y: Integer);
var
  P: TPoint;
  M, L, T, Reach, CX, CY: Integer;
  A: TRect;
begin
  P := ToScreen(X, Y);
  M := MonitorNear(P);
  A := FMonitors[M].Bounds;
  L := P.X - FGrab.X;
  T := P.Y - FGrab.Y;
  if FSnap then Reach := MulDiv(SnapReach, FArea.Right - FArea.Left, Max(FInner.Right - FInner.Left, 1))
  else Reach := -1;
  CX := A.Left + (A.Right - A.Left - FFormWidth) div 2;
  FSnapX := Abs(L - CX) <= Reach;
  if FSnapX then L := CX
  else if Abs(L - A.Left) <= Reach then L := A.Left
  else if Abs(L + FFormWidth - A.Right) <= Reach then L := A.Right - FFormWidth;
  if FSnap then Reach := MulDiv(SnapReach, FArea.Bottom - FArea.Top, Max(FInner.Bottom - FInner.Top, 1))
  else Reach := -1;
  CY := A.Top + (A.Bottom - A.Top - FFormHeight) div 2;
  FSnapY := Abs(T - CY) <= Reach;
  if FSnapY then T := CY
  else if Abs(T - A.Top) <= Reach then T := A.Top
  else if Abs(T + FFormHeight - A.Bottom) <= Reach then T := A.Bottom - FFormHeight;
  FDragRect := KeepOn(Rect(L, T, L + FFormWidth, T + FFormHeight), M);
  FSnapX := FSnapX and (FDragRect.Left = CX);
  FSnapY := FSnapY and (FDragRect.Top = CY);
  FTarget := M;
  Invalidate;
end;

procedure TFormPositioner.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  T: TTrackMouseEvent;
begin
  inherited MouseMove(Shift, X, Y);
  if FPressed then
  begin
    if not FDragging and UIDragStarted(FPressAt, Point(X, Y)) then FDragging := True;
    if FDragging then DragTo(X, Y);
    Exit;
  end;
  if FExpanded and OnMiniature(X, Y) then Cursor := crSizeAll else Cursor := crDefault;
  { the large view goes when the pointer leaves it }
  if FExpanded and not FTracking and HandleAllocated then
  begin
    T.cbSize := SizeOf(T);
    T.dwFlags := TME_LEAVE;
    T.hwndTrack := Handle;
    T.dwHoverTime := 0;
    FTracking := TrackMouseEvent(T);
  end;
end;

procedure TFormPositioner.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Dragged, Centred: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FPressed then Exit;
  FPressed := False;
  Dragged := FDragging;
  { snapped to both centre lines of the primary monitor: where poScreenCenter puts the form }
  Centred := Dragged and FSnapX and FSnapY and (FTarget >= 0) and FMonitors[FTarget].Primary;
  FDragging := False;
  FSnapX := False;
  FSnapY := False;
  if Centred then
  begin
    if FPosition <> poScreenCenter then MoveForm(FDragRect.Left, FDragRect.Top, True)
    else Invalidate;
  end
  else if Dragged and ((FDragRect.Left <> FFormRect.Left) or (FDragRect.Top <> FFormRect.Top) or
    not (FPosition in [poDesigned, poDefaultSizeOnly])) then
    MoveForm(FDragRect.Left, FDragRect.Top, False)
  else
    Invalidate;
end;

{ the form opens at ALeft, ATop now: poScreenCenter with ScreenCenter, else at that place -
  poDesigned unless poDefaultSizeOnly keeps Left and Top already }
procedure TFormPositioner.MoveForm(ALeft, ATop: Integer; ScreenCenter: Boolean);
begin
  FLeft := ALeft;
  FTop := ATop;
  if ScreenCenter then FPosition := poScreenCenter
  else if not (FPosition in [poDesigned, poDefaultSizeOnly]) then FPosition := poDesigned;
  PlaceForm;
  Invalidate;
  if Assigned(FOnMoved) then FOnMoved(Self, ALeft, ATop, FPosition);
end;

{ Esc, or another window took the mouse: the form stays where it was }
procedure TFormPositioner.PressCancelled(Sender: TObject);
begin
  if not FPressed then Exit;
  FPressed := False;
  FDragging := False;
  FSnapX := False;
  FSnapY := False;
  Invalidate;
end;

procedure TFormPositioner.WMMouseLeave(var Message: TMessage);
begin
  FTracking := False;
  if not FPressed then Expanded := False;
end;

{ the VCL's own notice (TApplication's idle check): also when the pointer left in one jump,
  before a move over the large view asked Windows for WM_MOUSELEAVE }
procedure TFormPositioner.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if (Message.LParam = 0) and not FPressed then Expanded := False;
end;

{ hidden with the design view: small again when it comes back }
procedure TFormPositioner.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if not Showing then
  begin
    FPressed := False;
    FDragging := False;
    Expanded := False;
  end;
end;

function TFormPositioner.TestText: string;
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 0 to High(FMonitors) do
    S := S + IntToStr(FMonitors[I].Number) + ':' + RectText(MonitorView(I)) + ';';
  Result := Format('%d|%s|%d,%d|%dx%d|%s|%s', [Ord(FExpanded), RectText(Miniature), FLeft, FTop,
    Width, Height, StatusText, S]);
end;

end.
