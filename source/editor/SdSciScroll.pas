{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSciScroll;

{ D7 Studio - the code editor's scroll bars, drawn by D7 Studio in the editor's colours, with an
  option for their colour.

  Windows draws a window's own scroll bars in two looks only (the theme's light one and its
  DarkMode_Explorer), and draws them again on every scroll, hover and drag: painted over, they
  flicker. Scintilla's own bars are therefore switched off; these live in the editor's non-client
  area beside its border - WM_NCCALCSIZE takes their room from the client area, WM_NCPAINT paints
  them (in one piece each, through a memory bitmap), WM_NCHITTEST names them HTVSCROLL and
  HTHSCROLL, and their presses are handled here, never by Windows' own tracking. The editor
  tells their state (OnGetInfo) and scrolls (OnScroll). Positions come from the messages.
  The vertical bar lies at the frame's right edge: a strip that another hook takes between the
  client area and it (the minimap, SdSciMinimap) is that hook's to paint; the horizontal bar runs
  under the client area, the corner beside it under that strip too. }

interface

uses
  Windows, Messages, Classes, Graphics, Controls, SdUI;

type
  TSciBar = (sbVert, sbHorz);

  TSciScrollInfo = record
    Visible: Boolean;
    Pos, Max, Page: Integer;     // the positions 0..Max, Page of them in view
  end;

  TSciScrollAction = (saLineBack, saLineOn, saPageBack, saPageOn, saTo);
  TSciGetScrollInfo = procedure(Bar: TSciBar; var Info: TSciScrollInfo) of object;
  TSciScrollEvent = procedure(Bar: TSciBar; Action: TSciScrollAction; Pos: Integer) of object;

  TSciScrollColors = record
    Track, Thumb, ThumbHot, ThumbDown, Arrow, ArrowHot, ArrowOff: TColor;
  end;

  TSciBarPart = (bpNone, bpArrowBack, bpTrackBack, bpThumb, bpTrackOn, bpArrowOn);

  { a marker beside the vertical bar's track (the editor's Scroll bar markers): at a position of
    the bar (a display line), in a third of its width }
  TSciMarkLane = (mlLeft, mlCenter, mlRight);
  TSciScrollMark = record
    Pos: Integer;
    Color: TColor;
    Lane: TSciMarkLane;
  end;
  TSciScrollMarks = array of TSciScrollMark;
  { the markers (Marks[0 .. Count - 1]) and the caret's position (-1 none) }
  TSciGetScrollMarks = procedure(var Marks: TSciScrollMarks; out Count, Caret: Integer) of object;

  { a hook of the editor's window procedure (TUIWindowHook: given back when the bars go) }
  TSciScrollBars = class(TUIWindowHook)
  private
    FInfo: array[TSciBar] of TSciScrollInfo;
    FBuffers: array[TSciBar] of TBitmap;   // each bar is painted in its own (kept between paints)
    FColors: TSciScrollColors;
    FOnGetInfo: TSciGetScrollInfo;
    FOnScroll: TSciScrollEvent;
    FOnGetMarks: TSciGetScrollMarks;
    FOnPress: TNotifyEvent;
    FMarks: TSciScrollMarks;
    FHotBar, FDownBar: TSciBar;
    FHot, FDown: TSciBarPart;
    FMouse: TPoint;              // the pointer, window coordinates (the last message)
    FGrab: Integer;              // where the thumb was taken, from its start
    FFirstRepeat: Boolean;
    FTracking: Boolean;          // TrackMouseEvent asked for WM_NCMOUSELEAVE
    FSized: Boolean;             // a new size: the bars are painted again (WM_SCIBARSIZED posted)
    function Thick: Integer;
    function BarRect(Bar: TSciBar): TRect;
    procedure Parts(Bar: TSciBar; out ArrowBack, Track, Thumb, ArrowOn: TRect);
    function PartAt(const P: TPoint; out Bar: TSciBar): TSciBarPart;
    procedure Press(const P: TPoint);
    procedure Step;
    procedure Drag(const P: TPoint);
    procedure EndPress;
    procedure Hover(const P: TPoint; Inside: Boolean);
    procedure PaintBar(DC: HDC; Bar: TSciBar);
    procedure PaintMarks(C: TCanvas; const Track: TRect);
  protected
    procedure Hook(var Message: TMessage); override;
  public
    constructor Create(AControl: TWinControl); reintroduce;
    destructor Destroy; override;
    { the state from OnGetInfo again: the bars are painted again when it changed, the frame is
      made again when one appears or goes }
    procedure Update;
    procedure Paint;
    procedure SetColors(const C: TSciScrollColors);
    property OnGetInfo: TSciGetScrollInfo read FOnGetInfo write FOnGetInfo;
    property OnScroll: TSciScrollEvent read FOnScroll write FOnScroll;
    { the markers of the vertical bar, asked for at each paint }
    property OnGetMarks: TSciGetScrollMarks read FOnGetMarks write FOnGetMarks;
    { a press of the left button on a bar, before the bar acts on it (the editor's window never
      gets that message) }
    property OnPress: TNotifyEvent read FOnPress write FOnPress;
  end;

{ the bars' colours on the editor's ground: shades of it towards white (a dark ground) or black;
  Custom (not clDefault): the thumb in that colour, the track tinted with it }
function SciScrollColors(Ground, Custom: TColor): TSciScrollColors;

{ the parts of the editor's non-client area (the bars, the minimap) }
const
  WM_NCMOUSELEAVE = $02A2;

{ the client area's top left in Wnd's window coordinates - the frame's width at the left, which is
  its width at the right too - and its size }
function SciClientOrigin(Wnd: HWND; out Size: TPoint): TPoint;
{ the screen point of a message (its LParam) in Wnd's window coordinates }
function SciWindowPoint(Wnd: HWND; LParam: Integer): TPoint;
{ the client point of a mouse message (its LParam: WM_MOUSEMOVE while the mouse is captured) in Wnd's
  window coordinates }
function SciClientPoint(Wnd: HWND; LParam: Integer): TPoint;
{ the rectangle of a WM_NCCALCSIZE that the client area is made of: a hook takes its room from it }
function SciNcCalcRect(const Message: TMessage): PRect;
{ x of the frame's right edge (where the vertical bar ends) in Wnd's window coordinates }
function SciFrameRight(Wnd: HWND): Integer;
{ WM_NCMOUSELEAVE asked for when the pointer leaves Wnd's non-client area: True when it will come }
function SciTrackNcLeave(Wnd: HWND): Boolean;

implementation

const
  TimerId = $5D51;                        // not one of Scintilla's timers
  TME_NONCLIENT = $00000010;
  WM_SCIBARSIZED = WM_APP + $1A1;         // the editor has a new size: the bars painted again
  MinThumb = 12;

function SciClientOrigin(Wnd: HWND; out Size: TPoint): TPoint;
var
  W, C: TRect;
  P: TPoint;
begin
  GetWindowRect(Wnd, W);
  Windows.GetClientRect(Wnd, C);
  P := Point(0, 0);
  Windows.ClientToScreen(Wnd, P);
  Result := Point(P.X - W.Left, P.Y - W.Top);
  Size := Point(C.Right, C.Bottom);
end;

function SciWindowPoint(Wnd: HWND; LParam: Integer): TPoint;
var
  W: TRect;
begin
  GetWindowRect(Wnd, W);
  Result := Point(SmallInt(LoWord(LParam)) - W.Left, SmallInt(HiWord(LParam)) - W.Top);
end;

function SciClientPoint(Wnd: HWND; LParam: Integer): TPoint;
var
  S: TPoint;
begin
  Result := SciClientOrigin(Wnd, S);
  Inc(Result.X, SmallInt(LoWord(LParam)));
  Inc(Result.Y, SmallInt(HiWord(LParam)));
end;

function SciNcCalcRect(const Message: TMessage): PRect;
begin
  if Message.WParam <> 0 then Result := @PNCCalcSizeParams(Message.LParam)^.rgrc[0]
  else Result := PRect(Message.LParam);
end;

function SciFrameRight(Wnd: HWND): Integer;
var
  W: TRect;
  S: TPoint;
begin
  GetWindowRect(Wnd, W);
  Result := W.Right - W.Left - SciClientOrigin(Wnd, S).X;
end;

function SciTrackNcLeave(Wnd: HWND): Boolean;
var
  T: TTrackMouseEvent;
begin
  T.cbSize := SizeOf(T);
  T.dwFlags := TME_LEAVE or TME_NONCLIENT;
  T.hwndTrack := Wnd;
  T.dwHoverTime := 0;
  Result := TrackMouseEvent(T);
end;

function SciScrollColors(Ground, Custom: TColor): TSciScrollColors;
var
  G: COLORREF;
  Toward: TColor;
  Dark: Boolean;
begin
  G := ColorToRGB(Ground);
  Dark := UIIsDark(Ground);
  if Dark then Toward := clWhite else Toward := clBlack;
  with Result do
  begin
    if (Custom = clDefault) or (Custom = clNone) then
    begin
      { on white about Windows' own light scroll bar: F0F0F0, C0C0C0, A6A6A6, 8C8C8C, 606060 }
      Track := UIBlend(Toward, G, 6);
      if Dark then
      begin
        Thumb := UIBlend(Toward, G, 30);
        ThumbHot := UIBlend(Toward, G, 45);
        ThumbDown := UIBlend(Toward, G, 58);
      end
      else
      begin
        Thumb := UIBlend(Toward, G, 25);
        ThumbHot := UIBlend(Toward, G, 35);
        ThumbDown := UIBlend(Toward, G, 45);
      end;
      Arrow := UIBlend(Toward, G, 62);
      ArrowHot := UIBlend(Toward, G, 85);
    end
    else
    begin
      Thumb := ColorToRGB(Custom);
      Track := UIBlend(Thumb, G, 12);
      ThumbHot := UIBlend(Toward, Thumb, 20);
      ThumbDown := UIBlend(Toward, Thumb, 38);
      Arrow := Thumb;
      ArrowHot := ThumbDown;
    end;
    ArrowOff := UIBlend(Toward, G, 22);
  end;
end;

{ ---------------------------------------------------------------- TSciScrollBars }

constructor TSciScrollBars.Create(AControl: TWinControl);
begin
  inherited Create(AControl, True);
  FInfo[sbVert].Visible := True;          // Scintilla shows its vertical bar always: so do these
  FColors := SciScrollColors(clWindow, clDefault);
end;

destructor TSciScrollBars.Destroy;
begin
  FBuffers[sbVert].Free;
  FBuffers[sbHorz].Free;
  inherited Destroy;
end;

function TSciScrollBars.Thick: Integer;
begin
  Result := GetSystemMetrics(SM_CXVSCROLL);
end;

function TSciScrollBars.BarRect(Bar: TSciBar): TRect;
var
  O, S: TPoint;
  X: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if not FControl.HandleAllocated or not FInfo[Bar].Visible then Exit;
  O := SciClientOrigin(FControl.Handle, S);
  if Bar = sbVert then
  begin
    X := SciFrameRight(FControl.Handle);
    Result := Rect(X - Thick, O.Y, X, O.Y + S.Y);
  end
  else
    Result := Rect(O.X, O.Y + S.Y, O.X + S.X, O.Y + S.Y + GetSystemMetrics(SM_CYHSCROLL));
end;

procedure TSciScrollBars.Parts(Bar: TSciBar; out ArrowBack, Track, Thumb, ArrowOn: TRect);
var
  R: TRect;
  Len, A, TL, Size, At: Integer;
  I: TSciScrollInfo;
begin
  R := BarRect(Bar);
  I := FInfo[Bar];
  if Bar = sbVert then
  begin
    Len := R.Bottom - R.Top;
    A := R.Right - R.Left;
    if 2 * A > Len then A := Len div 2;
    ArrowBack := Rect(R.Left, R.Top, R.Right, R.Top + A);
    ArrowOn := Rect(R.Left, R.Bottom - A, R.Right, R.Bottom);
    Track := Rect(R.Left, ArrowBack.Bottom, R.Right, ArrowOn.Top);
    TL := Track.Bottom - Track.Top;
  end
  else
  begin
    Len := R.Right - R.Left;
    A := R.Bottom - R.Top;
    if 2 * A > Len then A := Len div 2;
    ArrowBack := Rect(R.Left, R.Top, R.Left + A, R.Bottom);
    ArrowOn := Rect(R.Right - A, R.Top, R.Right, R.Bottom);
    Track := Rect(ArrowBack.Right, R.Top, ArrowOn.Left, R.Bottom);
    TL := Track.Right - Track.Left;
  end;
  Thumb := Rect(0, 0, 0, 0);
  if (I.Max <= 0) or (TL < MinThumb) then Exit;      // nothing to scroll: no thumb, as Windows'
  Size := MulDiv(TL, I.Page, I.Max + I.Page);
  if Size < MinThumb then Size := MinThumb;
  if Size > TL then Size := TL;
  At := I.Pos;
  if At > I.Max then At := I.Max;
  if At < 0 then At := 0;
  At := MulDiv(TL - Size, At, I.Max);
  if Bar = sbVert then Thumb := Rect(Track.Left, Track.Top + At, Track.Right, Track.Top + At + Size)
  else Thumb := Rect(Track.Left + At, Track.Top, Track.Left + At + Size, Track.Bottom);
end;

function TSciScrollBars.PartAt(const P: TPoint; out Bar: TSciBar): TSciBarPart;
var
  B: TSciBar;
  AB, T, Th, AO: TRect;
begin
  Result := bpNone;
  Bar := sbVert;
  for B := Low(TSciBar) to High(TSciBar) do
    if PtInRect(BarRect(B), P) then
    begin
      Bar := B;
      Parts(B, AB, T, Th, AO);
      if PtInRect(AB, P) then Result := bpArrowBack
      else if PtInRect(AO, P) then Result := bpArrowOn
      else if PtInRect(Th, P) then Result := bpThumb
      else if IsRectEmpty(Th) then Result := bpTrackBack      // no thumb: a click does nothing
      else if ((B = sbVert) and (P.Y < Th.Top)) or ((B = sbHorz) and (P.X < Th.Left)) then Result := bpTrackBack
      else Result := bpTrackOn;
      Exit;
    end;
end;

procedure TSciScrollBars.Update;
var
  B: TSciBar;
  I: TSciScrollInfo;
  Changed, Frame: Boolean;
begin
  if not Assigned(FOnGetInfo) or not FControl.HandleAllocated then Exit;
  Changed := False;
  Frame := False;
  for B := Low(TSciBar) to High(TSciBar) do
  begin
    I := FInfo[B];
    FOnGetInfo(B, I);
    if I.Visible <> FInfo[B].Visible then Frame := True;
    if (I.Visible <> FInfo[B].Visible) or (I.Pos <> FInfo[B].Pos) or (I.Max <> FInfo[B].Max) or
      (I.Page <> FInfo[B].Page) then Changed := True;
    FInfo[B] := I;
  end;
  if Frame then
    { the client area changes: the frame is made again (WM_NCCALCSIZE) and painted }
    SetWindowPos(FControl.Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE or SWP_FRAMECHANGED)
  else if Changed then
    Paint;
end;

procedure TSciScrollBars.SetColors(const C: TSciScrollColors);
begin
  FColors := C;
  Paint;
end;

procedure TSciScrollBars.Paint;
var
  DC: HDC;
  V, H: TRect;
begin
  if not FControl.HandleAllocated or not IsWindowVisible(FControl.Handle) then Exit;
  DC := GetWindowDC(FControl.Handle);
  try
    PaintBar(DC, sbVert);
    PaintBar(DC, sbHorz);
    { the corner between them, under a strip between the client area and the vertical bar too }
    V := BarRect(sbVert);
    H := BarRect(sbHorz);
    if not IsRectEmpty(V) and not IsRectEmpty(H) then UIFill(DC, Rect(H.Right, H.Top, V.Right, H.Bottom), FColors.Track);
  finally
    ReleaseDC(FControl.Handle, DC);
  end;
end;

{ a triangle of pixel rows in R's centre, pointing back (up, left) or on (down, right) }
procedure DrawArrow(C: TCanvas; const R: TRect; Vertical, Back: Boolean; Color: TColor; Size: Integer);
var
  I, CX, CY, Row: Integer;
begin
  C.Brush.Color := Color;
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  for I := 0 to Size - 1 do
  begin
    { row I has 2 I + 1 pixels; the tip is row 0 }
    if Back then Row := I else Row := Size - 1 - I;
    if Vertical then
      C.FillRect(Rect(CX - I, CY - Size div 2 + Row, CX + I + 1, CY - Size div 2 + Row + 1))
    else
      C.FillRect(Rect(CX - Size div 2 + Row, CY - I, CX - Size div 2 + Row + 1, CY + I + 1));
  end;
end;

procedure TSciScrollBars.PaintBar(DC: HDC; Bar: TSciBar);
var
  R, AB, T, Th, AO, Local: TRect;
  Bmp: TBitmap;
  Vertical, Off: Boolean;
  Inset, Size: Integer;
  C: TColor;

  function Shift(const X: TRect): TRect;
  begin
    Result := X;
    OffsetRect(Result, -R.Left, -R.Top);
  end;

  function ArrowColor(Part: TSciBarPart): TColor;
  begin
    if Off then Result := FColors.ArrowOff
    else if ((FDown = Part) and (FDownBar = Bar)) or ((FHot = Part) and (FHotBar = Bar)) then Result := FColors.ArrowHot
    else Result := FColors.Arrow;
  end;

begin
  R := BarRect(Bar);
  if IsRectEmpty(R) then Exit;
  Parts(Bar, AB, T, Th, AO);
  Vertical := Bar = sbVert;
  Off := FInfo[Bar].Max <= 0;
  if FBuffers[Bar] = nil then FBuffers[Bar] := TBitmap.Create;
  Bmp := FBuffers[Bar];
  if (Bmp.Width <> R.Right - R.Left) or (Bmp.Height <> R.Bottom - R.Top) then
  begin
    Bmp.Width := R.Right - R.Left;
    Bmp.Height := R.Bottom - R.Top;
  end;
  Local := Rect(0, 0, Bmp.Width, Bmp.Height);
  Bmp.Canvas.Brush.Color := FColors.Track;
  Bmp.Canvas.FillRect(Local);
  if Vertical then Size := (R.Right - R.Left) div 4 else Size := (R.Bottom - R.Top) div 4;
  DrawArrow(Bmp.Canvas, Shift(AB), Vertical, True, ArrowColor(bpArrowBack), Size);
  DrawArrow(Bmp.Canvas, Shift(AO), Vertical, False, ArrowColor(bpArrowOn), Size);
  if not IsRectEmpty(Th) then
  begin
    if (FDown = bpThumb) and (FDownBar = Bar) then C := FColors.ThumbDown
    else if (FHot = bpThumb) and (FHotBar = Bar) then C := FColors.ThumbHot
    else C := FColors.Thumb;
    Bmp.Canvas.Brush.Color := C;
    Inset := (R.Right - R.Left) div 5;
    if not Vertical then Inset := (R.Bottom - R.Top) div 5;
    Th := Shift(Th);
    if Vertical then InflateRect(Th, -Inset, 0) else InflateRect(Th, 0, -Inset);
    Bmp.Canvas.FillRect(Th);
  end;
  if Vertical and Assigned(FOnGetMarks) then PaintMarks(Bmp.Canvas, Shift(T));
  BitBlt(DC, R.Left, R.Top, Bmp.Width, Bmp.Height, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
end;

{ the editor's markers along the track - each line at its place among the bar's positions, as
  the thumb is (a line in view lies under the thumb), in its third of the width -, over the
  thumb; the caret's line across the whole width, last }
procedure TSciScrollBars.PaintMarks(C: TCanvas; const Track: TRect);
var
  Count, Caret, K, Total, H, W, Y, X0, X1: Integer;

  function YOf(Pos: Integer): Integer;
  begin
    Result := Track.Top + MulDiv(Track.Bottom - Track.Top - H, Pos, Total);
  end;

begin
  FOnGetMarks(FMarks, Count, Caret);
  Total := FInfo[sbVert].Max + FInfo[sbVert].Page - 1;
  if Total < 1 then Total := 1;
  W := Track.Right - Track.Left;
  H := W div 5;
  if H < 2 then H := 2;
  if Track.Bottom - Track.Top <= H then Exit;
  for K := 0 to Count - 1 do
  begin
    { the changes a narrow strip at the left, the matches the middle, the lines' markers the right }
    case FMarks[K].Lane of
      mlLeft:
        begin
          X0 := Track.Left + 1;
          X1 := Track.Left + W div 4;
        end;
      mlCenter:
        begin
          X0 := Track.Left + W div 4;
          X1 := Track.Right - W div 4;
        end;
    else
      X0 := Track.Right - W div 4;
      X1 := Track.Right - 1;
    end;
    Y := YOf(FMarks[K].Pos);
    C.Brush.Color := FMarks[K].Color;
    C.FillRect(Rect(X0, Y, X1, Y + H));
  end;
  if Caret >= 0 then
  begin
    Y := YOf(Caret);
    C.Brush.Color := FColors.ArrowHot;
    C.FillRect(Rect(Track.Left + 1, Y, Track.Right - 1, Y + H));
  end;
end;

procedure TSciScrollBars.Press(const P: TPoint);
var
  Bar: TSciBar;
  Part: TSciBarPart;
  AB, T, Th, AO: TRect;
begin
  Part := PartAt(P, Bar);
  if Part = bpNone then Exit;
  FMouse := P;
  FDown := Part;
  FDownBar := Bar;
  SetCapture(FControl.Handle);
  if Part = bpThumb then
  begin
    Parts(Bar, AB, T, Th, AO);
    if Bar = sbVert then FGrab := P.Y - Th.Top else FGrab := P.X - Th.Left;
  end
  else
  begin
    Step;
    FFirstRepeat := True;
    SetTimer(FControl.Handle, TimerId, GetDoubleClickTime div 2, nil);
  end;
  Paint;
end;

{ one step of the pressed arrow or track - the track's only while the thumb has not reached the
  pointer }
procedure TSciScrollBars.Step;
var
  AB, T, Th, AO: TRect;
  Bar: TSciBar;
begin
  if not Assigned(FOnScroll) then Exit;
  if PartAt(FMouse, Bar) <> FDown then Exit;     // the pointer left the part: it waits
  if Bar <> FDownBar then Exit;
  Parts(FDownBar, AB, T, Th, AO);
  case FDown of
    bpArrowBack: FOnScroll(FDownBar, saLineBack, 0);
    bpArrowOn: FOnScroll(FDownBar, saLineOn, 0);
    bpTrackBack: if not IsRectEmpty(Th) then FOnScroll(FDownBar, saPageBack, 0);
    bpTrackOn: if not IsRectEmpty(Th) then FOnScroll(FDownBar, saPageOn, 0);
  end;
  Update;
end;

procedure TSciScrollBars.Drag(const P: TPoint);
var
  AB, T, Th, AO: TRect;
  TL, Size, At, Pos: Integer;
  I: TSciScrollInfo;
begin
  FMouse := P;
  if FDown <> bpThumb then
  begin
    Paint;
    Exit;
  end;
  Parts(FDownBar, AB, T, Th, AO);
  I := FInfo[FDownBar];
  if IsRectEmpty(Th) or not Assigned(FOnScroll) then Exit;
  if FDownBar = sbVert then
  begin
    TL := T.Bottom - T.Top;
    Size := Th.Bottom - Th.Top;
    At := P.Y - FGrab - T.Top;
  end
  else
  begin
    TL := T.Right - T.Left;
    Size := Th.Right - Th.Left;
    At := P.X - FGrab - T.Left;
  end;
  if TL <= Size then Exit;
  Pos := MulDiv(At, I.Max, TL - Size);
  if Pos < 0 then Pos := 0;
  if Pos > I.Max then Pos := I.Max;
  if Pos <> I.Pos then
  begin
    FOnScroll(FDownBar, saTo, Pos);
    Update;
  end;
end;

procedure TSciScrollBars.EndPress;
begin
  if FDown = bpNone then Exit;
  KillTimer(FControl.Handle, TimerId);
  FDown := bpNone;
  Paint;
end;

procedure TSciScrollBars.Hover(const P: TPoint; Inside: Boolean);
var
  Bar: TSciBar;
  Part: TSciBarPart;
begin
  if Inside then Part := PartAt(P, Bar) else
  begin
    Part := bpNone;
    Bar := sbVert;
  end;
  if (Part <> FHot) or (Bar <> FHotBar) then
  begin
    FHot := Part;
    FHotBar := Bar;
    Paint;
  end;
end;

procedure TSciScrollBars.Hook(var Message: TMessage);
var
  R: PRect;
  Bar: TSciBar;
begin
  case Message.Msg of
    WM_NCCALCSIZE:
      begin
        FOldProc(Message);
        R := SciNcCalcRect(Message);
        if FInfo[sbVert].Visible then R^.Right := R^.Right - Thick;
        if FInfo[sbHorz].Visible then R^.Bottom := R^.Bottom - GetSystemMetrics(SM_CYHSCROLL);
        if R^.Right < R^.Left then R^.Right := R^.Left;
        if R^.Bottom < R^.Top then R^.Bottom := R^.Top;
        Exit;
      end;
    WM_NCPAINT:
      begin
        FOldProc(Message);
        Paint;
        Exit;
      end;
    { the bars follow a new size before the editor paints at it - after its paint (SCN_PAINTED)
      the first frame showed the bars of the size before: View as Text's page, filled while
      hidden at a few pixels, came up with a horizontal bar that went a frame later. A frame
      made again inside the dock's batch of moves is painted, then covered with the old
      client's pixels when the batch ends (a horizontal bar's place showed text): the bars are
      painted again after it (posted: before the paint) }
    WM_SIZE:
      begin
        FOldProc(Message);
        Update;
        if not FSized and FControl.HandleAllocated then
        begin
          FSized := True;
          PostMessage(FControl.Handle, WM_SCIBARSIZED, 0, 0);
        end;
        Exit;
      end;
    WM_SCIBARSIZED:
      begin
        FSized := False;
        Paint;
        Exit;
      end;
    WM_NCHITTEST:
      begin
        FOldProc(Message);
        if PartAt(SciWindowPoint(FControl.Handle, Message.LParam), Bar) <> bpNone then
          if Bar = sbVert then Message.Result := HTVSCROLL else Message.Result := HTHSCROLL;
        Exit;
      end;
    WM_NCLBUTTONDOWN, WM_NCLBUTTONDBLCLK:
      if (Message.WParam = HTVSCROLL) or (Message.WParam = HTHSCROLL) then
      begin
        if Assigned(FOnPress) then FOnPress(Self);
        Press(SciWindowPoint(FControl.Handle, Message.LParam));
        Message.Result := 0;
        Exit;
      end;
    WM_NCMOUSEMOVE:
      begin
        Hover(SciWindowPoint(FControl.Handle, Message.LParam), True);
        if not FTracking then FTracking := SciTrackNcLeave(FControl.Handle);
      end;
    WM_NCMOUSELEAVE:
      begin
        FTracking := False;
        Hover(Point(0, 0), False);
      end;
    WM_MOUSEMOVE:
      if FDown <> bpNone then
      begin
        Drag(SciClientPoint(FControl.Handle, Message.LParam));
        Exit;
      end;
    WM_LBUTTONUP:
      if FDown <> bpNone then
      begin
        ReleaseCapture;               // WM_CAPTURECHANGED ends the press
        EndPress;
        Exit;
      end;
    WM_CAPTURECHANGED:
      EndPress;
    WM_TIMER:
      if Message.WParam = TimerId then
      begin
        if FFirstRepeat then
        begin
          FFirstRepeat := False;
          SetTimer(FControl.Handle, TimerId, 50, nil);
        end;
        Step;
        Exit;
      end;
    WM_CONTEXTMENU:
      if Message.LParam <> -1 then
      begin
        { the bars have no menu (Windows' own "Scroll Here" would scroll Scintilla's bars) }
        if PartAt(SciWindowPoint(FControl.Handle, Message.LParam), Bar) <> bpNone then Exit;
      end;
  end;
  FOldProc(Message);
end;

end.
