{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDiagram;

{ D7 Studio - the Diagram tab of a Pascal page, beside Code and Design. The classes,
  interfaces and records of the unit, each a box with its fields, methods and properties; a line
  from each to its ancestor and, dashed, to the interfaces it implements, ending in a hollow
  triangle (UML's). An ancestor of another unit is a box with its name only, in grey. The boxes
  stand in layers by their depth of inheritance - the ancestors on top - and a layer that is
  wider than the view goes on in a row below. A box shows its members only when it is open:
  every box starts closed, the box in its head opens and closes it. Zoom: the diagram is laid out again for the
  zoom (font, sizes and gaps scaled, lines 1 px) - the rows wrap as at 100 %, so the picture
  scales. The data is TCodeInsight.GetStructure's; a double click or Enter
  on a box or a member goes to its declaration (OnGoto). Painted in one pass into a buffer,
  never erased. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SdUI, SdCodeInsight, SdIcons, SdZoom;

type
  TSdDiagramGotoEvent = procedure(Sender: TObject; Line, Col: Integer) of object;

  TSdDiagramView = class(TSdScrollControl, ISdZoomView)
  private
    FBoxes: TList;            // TDiagramBox (owned): the unit's in source order, then the others' ancestors
    FOrder: TList;            // the boxes as laid out: by layer, then left to right (the keyboard's order)
    FUnitName: string;
    FSize: TPoint;            // the diagram's extent (at the zoom)
    FSel: TObject;            // the selected box (TDiagramBox), nil none
    FSelMember: Integer;      // ... its member, -1 the box itself
    FZoom: Integer;           // percent
    FWheelZoom: Integer;      // parts of wheel notches with the zoom key (UIWheelSteps)
    FFont, FBoldFont: TFont;  // Font at the zoom
    FIcon: Integer;           // the icons' size at the zoom
    FRowH, FHeadH: Integer;
    FLayoutWidth: Integer;    // the window width the boxes were laid out for
    FMaxLayer: Integer;       // the boxes' last layer (Measure)
    FTopSpace: Integer;       // the height of the controls aligned at the top (TopBarsHeight)
    FIconCache: array[TSdIcon] of HICON;   // PaintIcon at a zoom: IconList's icons made once (0: not yet)
    FIconCacheList: THandle;               // ... while IconList has this handle
    FPaintBuf: TBitmap;       // Paint draws on it (UIBufferDC), then copies the client to the screen
    FOnGoto: TSdDiagramGotoEvent;
    function S(V: Integer): Integer;
    function ExpandSize: Integer;
    procedure ClearBoxes;
    procedure AddBox(N: TCIStructNode);
    procedure LinkBases;
    procedure Layout;
    procedure Measure;
    procedure Arrange;
    procedure FreeIconCache;
    procedure LayoutKeeping(Box: TObject);
    function Place(WrapRight, MaxLayer: Integer): Integer;
    function Route(Rows: Integer): Integer;
    procedure SetZoom(Value: Integer; const Anchor: TPoint);
    procedure StepZoom(Delta: Integer; const Anchor: TPoint);
    procedure SetOpen(Box: TObject; Value: Boolean);
    procedure ScrollBy(DX, DY: Integer);
    procedure HitTest(X, Y: Integer; out Box: TObject; out Member: Integer; out OnButton: Boolean);
    procedure Select(Box: TObject; Member: Integer);
    procedure MakeVisible;
    procedure GotoSelected;
    procedure MoveSelection(Delta: Integer);
    function ButtonRect(Box: TObject): TRect;
    procedure PaintIcon(DC: HDC; Icon: TSdIcon; X, Y: Integer);
    procedure PaintBox(DC: HDC; Box: TObject);
    function TopBarsHeight: Integer;
    procedure PaintControlsGround(DC: HDC);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    function ContentSize: TPoint; override;      // FSize
    function LineSize: Integer; override;        // a row
    procedure EraseGround(DC: HDC); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure AlignControls(AControl: TControl; var Rect: TRect); override;
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the unit's structure (TCodeInsight.GetStructure; the caller keeps it). KeepView: the same
      unit again - the open boxes, the selection, the zoom and the scroll positions stay }
    procedure ShowStructure(Root: TCIStructNode; const AUnitName: string; KeepView: Boolean);
    { the Diagram tab's tool bar (the main form's actions): every box open or closed; a step of
      the zoom, the view's middle staying where it is; Reset - 100 %, every box closed, the top }
    procedure ExpandAll(Value: Boolean);
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ResetView;
    function CanExpand: Boolean;      // a closed box has members
    function CanCollapse: Boolean;    // a box is open
    function CanZoomIn: Boolean;
    function CanZoomOut: Boolean;
    { ISdZoomView: the zoom bar, View | Zoom; steps of 5 % (SdZoom), Fit the whole diagram in view }
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
    { test mode: count|selected|scroll x,y|size w x h|zoom|open boxes; Boxes: one line per box,
      name|kind|open|left,top,right,bottom (client)|its box's middle x,y|bases (~ dashed)|member@top,...; }
    function StateText: string;
    procedure BoxesText(List: TStrings);
    property Zoom: Integer read FZoom;
    property OnGoto: TSdDiagramGotoEvent read FOnGoto write FOnGoto;
  end;

implementation

uses
  Math, CommCtrl, SdCodeExplorer;

const
  { the sizes at 100 % (S scales them) }
  Margin = 16;                // around the diagram
  ColGap = 24;                // between two boxes of a row
  RowGap = 60;                // between two rows: the lines run there
  BusTop = 8;                 // the first line above a row ...
  BusStep = 5;                // ... and the next ones (one per ancestor the row's boxes have)
  BusCount = 5;
  BelowTop = 6;               // the first line below a row, under the triangles ...
  BelowCount = 3;             // ... and the next ones, BusStep apart
  LaneStep = 6;               // the lanes at the left edge, for lines that pass rows
  LaneGap = 6;                // between the last lane and the boxes
  MinBoxWidth = 120;
  MaxBoxWidth = 420;
  Pad = 6;                    // the text's distance from a box's edge
  IconGap = 4;                // between an icon and its text
  CompPad = 3;                // above and below the rows of a compartment
  ArrowLen = 8;               // the hollow triangle at an ancestor's box
  ArrowHalf = 5;
  BoxSize = 9;                // the box that opens and closes a box
  DashOn = 4;                 // the dashes of a line to an interface (1 px at every zoom)
  DashOff = 3;
  MinZoom = 5;                // SdZoom's steps of 5 %; a fitted zoom may lie between them
  MaxZoom = 400;

type
  TDiagramControl = class(TControl);    // its protected Color

  { the line from a box to one of its bases (TSdDiagramView.Route) }
  TRoute = record
    Bus: Integer;             // the y of its stretch above the box's row
    Long: Boolean;            // the base is not in the row just above: through a lane
    Lane: Integer;            // ... the lane's x
    Below: Integer;           // ... the y of its stretch below the base's row
  end;

  TDiagramMember = class
  public
    Caption, Plain: string;
    Kind: TCIKind;
    Line, Col: Integer;
    Top: Integer;             // relative to its box
  end;

  TDiagramBox = class
  public
    Name: string;
    Kind: TCIKind;            // ckClass, ckInterface, ckRecord; ckUnknown: an ancestor of another unit
    Line, Col: Integer;
    Open: Boolean;            // its members are shown
    Bases: TStringList;       // as written: the ancestor first, then the interfaces
    BaseBoxes: TList;         // ... their boxes, in that order
    Routes: array of TRoute;  // ... the line to each of them
    Row: Integer;             // the row it stands in
    Members: TList;           // TDiagramMember (owned): fields, methods, properties
    Seps: array of Integer;   // the lines above the compartments, relative to the box
    Layer: Integer;           // -1 not known yet, -2 being found (a cycle in a broken source)
    Seq: Integer;             // the order of first appearance
    Want: Integer;            // the left edge it would like: centred under its bases
    R: TRect;                 // in the diagram's coordinates
    constructor Create;
    destructor Destroy; override;
    function Foreign: Boolean;
    function HasButton: Boolean;
    function Shown: Boolean;  // its members are in view
    function Center: Integer;
  end;

constructor TDiagramBox.Create;
begin
  inherited Create;
  Bases := TStringList.Create;
  BaseBoxes := TList.Create;
  Members := TList.Create;
  Layer := -1;
end;

destructor TDiagramBox.Destroy;
var
  I: Integer;
begin
  for I := 0 to Members.Count - 1 do TObject(Members[I]).Free;
  Members.Free;
  BaseBoxes.Free;
  Bases.Free;
  inherited;
end;

function TDiagramBox.Foreign: Boolean;
begin
  Result := Kind = ckUnknown;
end;

function TDiagramBox.HasButton: Boolean;
begin
  Result := not Foreign and (Members.Count > 0);
end;

function TDiagramBox.Shown: Boolean;
begin
  Result := Open and (Members.Count > 0);
end;

function TDiagramBox.Center: Integer;
begin
  Result := (R.Left + R.Right) div 2;
end;

function LayerOf(B: TDiagramBox): Integer;
var
  I: Integer;
begin
  if B.Layer = -2 then
  begin
    Result := 0;
    Exit;
  end;
  if B.Layer < 0 then
  begin
    B.Layer := -2;
    Result := 0;
    for I := 0 to B.BaseBoxes.Count - 1 do
      Result := Max(Result, LayerOf(TDiagramBox(B.BaseBoxes[I])) + 1);
    B.Layer := Result;
  end;
  Result := B.Layer;
end;

function CompareWant(A, B: Pointer): Integer;
begin
  Result := TDiagramBox(A).Want - TDiagramBox(B).Want;
  if Result = 0 then Result := TDiagramBox(A).Seq - TDiagramBox(B).Seq;
end;

{ the member's compartment: 0 fields, 1 methods, 2 properties }
function Compartment(Kind: TCIKind): Integer;
begin
  case Kind of
    ckProcedure, ckFunction, ckConstructor, ckDestructor: Result := 1;
    ckProperty: Result := 2;
  else
    Result := 0;
  end;
end;

function KindName(Kind: TCIKind): string;
begin
  case Kind of
    ckClass: Result := 'class';
    ckInterface: Result := 'interface';
    ckRecord: Result := 'record';
  else
    Result := 'other';
  end;
end;

{ a line along x (Vertical: along y) from A to B (either order), dashed or not }
procedure EdgeLine(DC: HDC; Vertical: Boolean; Fixed, A, B: Integer; Color: TColor; Dashed: Boolean);
var
  P, E: Integer;
begin
  if A > B then
  begin
    P := A;
    A := B;
    B := P;
  end;
  Inc(B);
  P := A;
  while P < B do
  begin
    if Dashed then E := Min(P + DashOn, B) else E := B;
    if Vertical then UIVLine(DC, Fixed, P, E, Color) else UIHLine(DC, P, E, Fixed, Color);
    P := E + DashOff;
  end;
end;

{ ---------------------------------------------------------------- TSdDiagramView }

constructor TSdDiagramView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption] + [csOpaque];
  TabStop := True;
  InitIcons;
  FBoxes := TList.Create;
  FOrder := TList.Create;
  FFont := TFont.Create;
  FBoldFont := TFont.Create;
  FZoom := 100;
  FSelMember := -1;
end;

destructor TSdDiagramView.Destroy;
begin
  ClearBoxes;
  FreeIconCache;
  FreeAndNil(FPaintBuf);
  FreeAndNil(FOrder);
  FreeAndNil(FBoxes);
  FreeAndNil(FBoldFont);
  FreeAndNil(FFont);
  inherited;
end;

{ a resize lays the boxes out again and repaints all of it (Resize): no CS_HREDRAW/CS_VREDRAW,
  nothing erased. No border: the page's frame is around it and its bar (SdPageBar); the controls
  on it are not painted over }
procedure TSdDiagramView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the controls aligned at the top lie over the diagram: the boxes start below them, and scroll
  under them }
function TSdDiagramView.TopBarsHeight: Integer;
var
  I: Integer;
  C: TControl;
begin
  Result := 0;
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if C.Visible and (C.Align = alTop) then Result := Max(Result, C.Top + C.Height);
  end;
end;

procedure TSdDiagramView.AlignControls(AControl: TControl; var Rect: TRect);
begin
  inherited AlignControls(AControl, Rect);
  if TopBarsHeight = FTopSpace then Exit;
  FTopSpace := TopBarsHeight;
  if FBoxes.Count > 0 then Layout;
  UpdateScrollBars;
  Invalidate;
end;

{ a flat tool bar on the diagram takes its ground from its parent (DrawThemeParentBackground:
  WM_ERASEBKGND, then WM_PRINTCLIENT into the bar's DC): the controls' own colour under them }
procedure TSdDiagramView.PaintControlsGround(DC: HDC);
var
  I: Integer;
  C: TControl;
begin
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if C.Visible then UIFill(DC, C.BoundsRect, TDiagramControl(C).Color);
  end;
end;

{ a size at the zoom }
function TSdDiagramView.S(V: Integer): Integer;
begin
  Result := Max(1, MulDiv(V, FZoom, 100));
end;

function TSdDiagramView.ExpandSize: Integer;
begin
  Result := Max(7, S(BoxSize)) or 1;      // a plus to see also when zoomed out
end;

procedure TSdDiagramView.ClearBoxes;
var
  I: Integer;
begin
  if FBoxes = nil then Exit;
  for I := 0 to FBoxes.Count - 1 do TObject(FBoxes[I]).Free;
  FBoxes.Clear;
  FOrder.Clear;
  FSel := nil;
  FSelMember := -1;
end;

procedure TSdDiagramView.AddBox(N: TCIStructNode);
var
  B: TDiagramBox;
  M: TDiagramMember;
  C, I: Integer;
begin
  B := TDiagramBox.Create;
  FBoxes.Add(B);
  if N.Plain <> '' then B.Name := N.Plain else B.Name := N.Caption;
  B.Kind := N.Kind;
  B.Line := N.Line;
  B.Col := N.Col;
  B.Bases.CommaText := N.Ancestors;
  { the members by compartment, each in the order of the source }
  for C := 0 to 2 do
    for I := 0 to N.Count - 1 do
      if Compartment(N[I].Kind) = C then
      begin
        M := TDiagramMember.Create;
        B.Members.Add(M);
        M.Caption := N[I].Caption;
        if N[I].Plain <> '' then M.Plain := N[I].Plain else M.Plain := N[I].Caption;
        M.Kind := N[I].Kind;
        M.Line := N[I].Line;
        M.Col := N[I].Col;
      end;
end;

{ every box's bases as boxes - an ancestor of another unit gets a box of its own - and the
  order in which the boxes first appear (an ancestor before its first descendant) }
procedure TSdDiagramView.LinkBases;
var
  I, K, J, Own, Seq: Integer;
  B, Base: TDiagramBox;
  N: string;
begin
  Own := FBoxes.Count;
  Seq := 0;
  for I := 0 to Own - 1 do
  begin
    B := TDiagramBox(FBoxes[I]);
    for K := 0 to B.Bases.Count - 1 do
    begin
      N := B.Bases[K];
      { Unit1.TFoo within Unit1 is TFoo }
      J := LastDelimiter('.', N);
      if (J > 0) and SameText(Copy(N, 1, J - 1), FUnitName) then N := Copy(N, J + 1, MaxInt);
      Base := nil;
      for J := 0 to FBoxes.Count - 1 do
        if SameText(TDiagramBox(FBoxes[J]).Name, N) then
        begin
          Base := TDiagramBox(FBoxes[J]);
          Break;
        end;
      if Base = nil then
      begin
        Base := TDiagramBox.Create;
        Base.Name := N;
        Base.Kind := ckUnknown;
        Base.Seq := Seq;
        Inc(Seq);
        FBoxes.Add(Base);
      end;
      if Base <> B then B.BaseBoxes.Add(Base);
    end;
    B.Seq := Seq;
    Inc(Seq);
  end;
end;

{ the boxes' sizes at the zoom and their layers (Measure), then their places and the lines between
  them for the window's width (Arrange) }
procedure TSdDiagramView.Layout;
begin
  Measure;
  Arrange;
end;

{ the boxes' sizes at the zoom and their layers (a box below all of its bases); a new width of the
  window leaves them as they are (Resize: Arrange alone) }
procedure TSdDiagramView.Measure;
var
  DC: HDC;
  OldFont: HFONT;
  TM: TTextMetric;
  I, J, L, MaxLayer, W, H: Integer;
  B: TDiagramBox;
  M: TDiagramMember;
  Layer: TList;
begin
  FFont.Assign(Font);
  FFont.Height := MulDiv(Font.Height, FZoom, 100);
  FBoldFont.Assign(FFont);
  FBoldFont.Style := [fsBold];
  FIcon := S(16);
  DC := CreateCompatibleDC(0);
  try
    OldFont := SelectObject(DC, FFont.Handle);
    GetTextMetrics(DC, TM);
    FRowH := Max(FIcon, TM.tmHeight) + S(4);
    FHeadH := Max(FIcon, TM.tmHeight) + S(8);
    { the sizes }
    for I := 0 to FBoxes.Count - 1 do
    begin
      B := TDiagramBox(FBoxes[I]);
      SelectObject(DC, FBoldFont.Handle);
      W := S(Pad) + UITextWidth(DC, B.Name) + S(Pad);
      if not B.Foreign then Inc(W, FIcon + S(IconGap));
      if B.HasButton then Inc(W, S(IconGap) + ExpandSize);
      SelectObject(DC, FFont.Handle);
      H := FHeadH;
      SetLength(B.Seps, 0);
      if B.Shown then
      begin
        L := -1;
        for J := 0 to B.Members.Count - 1 do
        begin
          M := TDiagramMember(B.Members[J]);
          if Compartment(M.Kind) <> L then
          begin
            if L >= 0 then Inc(H, S(CompPad));
            L := Compartment(M.Kind);
            SetLength(B.Seps, Length(B.Seps) + 1);   // three at most
            B.Seps[High(B.Seps)] := H;
            Inc(H, 1 + S(CompPad));
          end;
          M.Top := H;
          Inc(H, FRowH);
          W := Max(W, S(Pad) + FIcon + S(IconGap) + UITextWidth(DC, M.Caption) + S(Pad));
        end;
        Inc(H, S(CompPad));
      end
      else if not B.Foreign and (B.Members.Count = 0) then
      begin
        { an empty class: one empty compartment, as UML draws it }
        SetLength(B.Seps, 1);
        B.Seps[0] := H;
        Inc(H, 1 + 2 * S(CompPad));
      end;
      W := Min(S(MaxBoxWidth), Max(S(MinBoxWidth), W));
      B.R := Rect(0, 0, W, H);
      B.Layer := -1;
    end;
    SelectObject(DC, OldFont);
  finally
    DeleteDC(DC);
  end;
  MaxLayer := 0;
  for I := 0 to FBoxes.Count - 1 do MaxLayer := Max(MaxLayer, LayerOf(TDiagramBox(FBoxes[I])));
  { a box with neither ancestors nor descendants here comes after the hierarchy, in rows of its
    own: the hierarchy stays together at the top }
  if MaxLayer > 0 then
  begin
    Layer := TList.Create;
    try
      for I := 0 to FBoxes.Count - 1 do
      begin
        B := TDiagramBox(FBoxes[I]);
        for J := 0 to B.BaseBoxes.Count - 1 do
          if Layer.IndexOf(B.BaseBoxes[J]) < 0 then Layer.Add(B.BaseBoxes[J]);
      end;
      for I := 0 to FBoxes.Count - 1 do
      begin
        B := TDiagramBox(FBoxes[I]);
        if (B.BaseBoxes.Count = 0) and (Layer.IndexOf(B) < 0) then B.Layer := MaxLayer + 1;
      end;
      Inc(MaxLayer);
    finally
      Layer.Free;
    end;
  end;
  FMaxLayer := MaxLayer;
end;

{ the measured boxes in their places (Place) and the lines between them (Route), for the window's
  width }
procedure TSdDiagramView.Arrange;
var
  WrapRight, Pass, Shift: Integer;
begin
  FOrder.Clear;
  if HandleAllocated then FLayoutWidth := Width else FLayoutWidth := 0;
  { the width of the window at 100 %, scaled: the rows wrap where they wrap at 100 % }
  if FLayoutWidth > 0 then WrapRight := MulDiv(FLayoutWidth - GetSystemMetrics(SM_CXVSCROLL) - Margin, FZoom, 100)
  else WrapRight := S(800);
  { placed twice when lanes are needed: again in the width they leave }
  for Pass := 0 to 1 do
  begin
    Shift := Route(Place(WrapRight, FMaxLayer));
    if Shift = 0 then Break;
    WrapRight := Max(S(Margin + MinBoxWidth), WrapRight - Shift);
  end;
end;

{ Layout, Box (when it is laid out) staying where it is in the window }
procedure TSdDiagramView.LayoutKeeping(Box: TObject);
var
  B: TDiagramBox;
  Old: TPoint;
begin
  B := TDiagramBox(Box);
  if B <> nil then Old := Point(B.R.Left - FOrigin.X, B.R.Top - FOrigin.Y);
  Layout;
  if B <> nil then FOrigin := Point(B.R.Left - Old.X, B.R.Top - Old.Y);
  UpdateScrollBars;
  Invalidate;
end;

{ the boxes in their places, layer after layer, each as near as it can be under the middle of its
  bases, a row full at WrapRight going on in a row below; the number of rows }
function TSdDiagramView.Place(WrapRight, MaxLayer: Integer): Integer;
var
  I, K, L, W, H, Y, X, RowTop, RowH: Integer;
  B: TDiagramBox;
  Layer: TList;
  First: Boolean;
begin
  FOrder.Clear;
  FSize := Point(0, 0);
  Y := S(Margin) + FTopSpace;
  Result := 0;
  Layer := TList.Create;
  try
    for L := 0 to MaxLayer do
    begin
      Layer.Clear;
      for I := 0 to FBoxes.Count - 1 do
      begin
        B := TDiagramBox(FBoxes[I]);
        if B.Layer <> L then Continue;
        B.Want := 0;
        if B.BaseBoxes.Count > 0 then
        begin
          for K := 0 to B.BaseBoxes.Count - 1 do Inc(B.Want, TDiagramBox(B.BaseBoxes[K]).Center);
          B.Want := B.Want div B.BaseBoxes.Count - (B.R.Right - B.R.Left) div 2;
        end;
        Layer.Add(B);
      end;
      if Layer.Count = 0 then Continue;
      Layer.Sort(CompareWant);
      X := S(Margin);
      RowTop := Y;
      RowH := 0;
      First := True;
      for I := 0 to Layer.Count - 1 do
      begin
        B := TDiagramBox(Layer[I]);
        W := B.R.Right - B.R.Left;
        H := B.R.Bottom - B.R.Top;
        X := Max(X, B.Want);
        if not First and (X + W > WrapRight) then
        begin
          RowTop := RowTop + RowH + S(RowGap);
          RowH := 0;
          Inc(Result);
          X := Max(S(Margin), B.Want);
          First := True;
        end;
        if First and (X + W > WrapRight) then X := Max(S(Margin), WrapRight - W);
        B.R := Rect(X, RowTop, X + W, RowTop + H);
        B.Row := Result;
        FOrder.Add(B);
        RowH := Max(RowH, H);
        FSize.X := Max(FSize.X, B.R.Right + S(Margin));
        Inc(X, W + S(ColGap));
        First := False;
      end;
      Y := RowTop + RowH + S(RowGap);
      Inc(Result);
    end;
    FSize.Y := Y - S(RowGap) + S(Margin);
  finally
    Layer.Free;
  end;
end;

{ The lines from each box to its bases. Up from the box's top to a line above its row (one height
  per base the row's boxes have), along it, up to the base's triangle - when the base is in the
  row just above. A base further up is reached through a lane at the diagram's left edge, so that
  no line runs behind a box: along the line above the row to the lane, up the lane, along a line
  below the base's row (one height per base there) and up to the triangle. The lanes are shared
  by lines whose stretches do not meet; the boxes move right to make room for them (the result:
  by how much). }
function TSdDiagramView.Route(Rows: Integer): Integer;
var
  RowBottom: array of Integer;
  LaneEnd: array of Integer;
  EdgeBox: TList;
  EdgeIndex: array of Integer;
  RowBases, LongBases: TList;
  I, J, K, N, Last, Lane, Lanes, Tmp: Integer;
  B, Base: TDiagramBox;
  P: Pointer;
begin
  Result := 0;
  Lanes := 0;
  SetLength(RowBottom, Rows + 1);
  for I := 0 to FOrder.Count - 1 do
  begin
    B := TDiagramBox(FOrder[I]);
    if (B.Row >= 0) and (B.Row <= Rows) then RowBottom[B.Row] := Max(RowBottom[B.Row], B.R.Bottom);
  end;
  RowBases := TList.Create;
  LongBases := TList.Create;
  EdgeBox := TList.Create;
  try
    Last := -1;
    for I := 0 to FOrder.Count - 1 do
    begin
      B := TDiagramBox(FOrder[I]);
      if B.Row <> Last then RowBases.Clear;
      Last := B.Row;
      SetLength(B.Routes, B.BaseBoxes.Count);
      for J := 0 to B.BaseBoxes.Count - 1 do
      begin
        Base := TDiagramBox(B.BaseBoxes[J]);
        if RowBases.IndexOf(Base) < 0 then RowBases.Add(Base);
        B.Routes[J].Bus := B.R.Top - S(BusTop) - (RowBases.IndexOf(Base) mod BusCount) * S(BusStep);
        B.Routes[J].Long := Base.Row <> B.Row - 1;
        if not B.Routes[J].Long then Continue;
        { the line below the base's row: one height per base of that row reached so }
        if LongBases.IndexOf(Base) < 0 then LongBases.Add(Base);
        N := 0;
        for K := 0 to LongBases.IndexOf(Base) - 1 do
          if TDiagramBox(LongBases[K]).Row = Base.Row then Inc(N);
        B.Routes[J].Below := RowBottom[Max(0, Min(Rows, Base.Row))] + S(ArrowLen) + S(BelowTop) +
          (N mod BelowCount) * S(BusStep);
        EdgeBox.Add(B);
        if EdgeBox.Count > Length(EdgeIndex) then SetLength(EdgeIndex, 2 * EdgeBox.Count);
        EdgeIndex[EdgeBox.Count - 1] := J;
      end;
    end;
    { the lanes: the stretches by their tops, each in the first lane that is free there }
    for I := 0 to EdgeBox.Count - 2 do
      for K := I + 1 to EdgeBox.Count - 1 do
        if TDiagramBox(EdgeBox[K]).Routes[EdgeIndex[K]].Below <
          TDiagramBox(EdgeBox[I]).Routes[EdgeIndex[I]].Below then
        begin
          P := EdgeBox[I];
          EdgeBox[I] := EdgeBox[K];
          EdgeBox[K] := P;
          Tmp := EdgeIndex[I];
          EdgeIndex[I] := EdgeIndex[K];
          EdgeIndex[K] := Tmp;
        end;
    for I := 0 to EdgeBox.Count - 1 do
    begin
      B := TDiagramBox(EdgeBox[I]);
      J := EdgeIndex[I];
      Lane := 0;
      while (Lane < Lanes) and (LaneEnd[Lane] + S(BusStep) > B.Routes[J].Below) do Inc(Lane);
      if Lane = Lanes then
      begin
        Inc(Lanes);
        if Lanes > Length(LaneEnd) then SetLength(LaneEnd, 2 * Lanes);
      end;
      LaneEnd[Lane] := B.Routes[J].Bus;
      B.Routes[J].Lane := S(Margin) + Lane * S(LaneStep);
    end;
  finally
    EdgeBox.Free;
    LongBases.Free;
    RowBases.Free;
  end;
  if Lanes > 0 then
  begin
    Result := Lanes * S(LaneStep) + S(LaneGap);
    for I := 0 to FOrder.Count - 1 do OffsetRect(TDiagramBox(FOrder[I]).R, Result, 0);
    Inc(FSize.X, Result);
  end;
end;

procedure TSdDiagramView.ShowStructure(Root: TCIStructNode; const AUnitName: string; KeepView: Boolean);
var
  OldBox, OldMember: string;
  OpenBoxes: TStringList;
  I, J: Integer;
  Cat: TCIStructNode;
  B: TDiagramBox;
begin
  OldBox := '';
  OldMember := '';
  OpenBoxes := TStringList.Create;
  try
    if KeepView then
    begin
      for I := 0 to FBoxes.Count - 1 do
        if TDiagramBox(FBoxes[I]).Open then OpenBoxes.Add(TDiagramBox(FBoxes[I]).Name);
      if FSel <> nil then
      begin
        B := TDiagramBox(FSel);
        OldBox := B.Name;
        if FSelMember >= 0 then OldMember := TDiagramMember(B.Members[FSelMember]).Caption;
      end;
    end
    else
      FZoom := 100;
    ClearBoxes;
    FUnitName := AUnitName;
    { the categories of the structure (Classes, Types ...): their classes, interfaces and records }
    if Root <> nil then
      for I := 0 to Root.Count - 1 do
      begin
        Cat := Root[I];
        for J := 0 to Cat.Count - 1 do
          if Cat[J].Kind in [ckClass, ckInterface, ckRecord] then AddBox(Cat[J]);
      end;
    for I := 0 to FBoxes.Count - 1 do
      TDiagramBox(FBoxes[I]).Open := OpenBoxes.IndexOf(TDiagramBox(FBoxes[I]).Name) >= 0;
  finally
    OpenBoxes.Free;
  end;
  LinkBases;
  Layout;
  if not KeepView then FOrigin := Point(0, 0);
  if OldBox <> '' then
    for I := 0 to FOrder.Count - 1 do
    begin
      B := TDiagramBox(FOrder[I]);
      if B.Name <> OldBox then Continue;
      FSel := B;
      if B.Shown then
        for J := 0 to B.Members.Count - 1 do
          if TDiagramMember(B.Members[J]).Caption = OldMember then
          begin
            FSelMember := J;
            Break;
          end;
      Break;
    end;
  UpdateScrollBars;
  Invalidate;
end;

{ --- open and closed boxes, the zoom --- }

procedure TSdDiagramView.SetOpen(Box: TObject; Value: Boolean);
var
  B: TDiagramBox;
begin
  B := TDiagramBox(Box);
  if (B = nil) or not B.HasButton or (B.Open = Value) then Exit;
  B.Open := Value;
  if (FSel = B) and not Value then FSelMember := -1;
  LayoutKeeping(B);
end;

procedure TSdDiagramView.ExpandAll(Value: Boolean);
var
  I: Integer;
begin
  for I := 0 to FBoxes.Count - 1 do
    with TDiagramBox(FBoxes[I]) do
      if HasButton then Open := Value;
  if not Value then FSelMember := -1;
  LayoutKeeping(FSel);
end;

function TSdDiagramView.CanExpand: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FBoxes.Count - 1 do
    with TDiagramBox(FBoxes[I]) do
      if HasButton and not Open then Exit;
  Result := False;
end;

function TSdDiagramView.CanCollapse: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FBoxes.Count - 1 do
    with TDiagramBox(FBoxes[I]) do
      if HasButton and Open then Exit;
  Result := False;
end;

{ the zoom; Anchor (a client point) shows the same point of the diagram afterwards }
procedure TSdDiagramView.SetZoom(Value: Integer; const Anchor: TPoint);
var
  P: TPoint;
  Old: Integer;
begin
  if Value < MinZoom then Value := MinZoom;
  if Value > MaxZoom then Value := MaxZoom;
  if Value = FZoom then Exit;
  P := Point(FOrigin.X + Anchor.X, FOrigin.Y + Anchor.Y);
  Old := FZoom;
  FZoom := Value;
  Layout;
  FOrigin := Point(MulDiv(P.X, FZoom, Old) - Anchor.X, MulDiv(P.Y, FZoom, Old) - Anchor.Y);
  UpdateScrollBars;
  Invalidate;
  ZoomChanged(Self);
end;

{ Delta steps of SdZoom's 5 % up (> 0) or down }
procedure TSdDiagramView.StepZoom(Delta: Integer; const Anchor: TPoint);
begin
  SetZoom(ZoomPercentStep(FZoom, Delta, MinZoom, MaxZoom), Anchor);
end;

procedure TSdDiagramView.ZoomIn;
begin
  StepZoom(1, Point(ClientWidth div 2, ClientHeight div 2));
end;

procedure TSdDiagramView.ZoomOut;
begin
  StepZoom(-1, Point(ClientWidth div 2, ClientHeight div 2));
end;

function TSdDiagramView.CanZoomIn: Boolean;
begin
  Result := CanZoom(1);
end;

function TSdDiagramView.CanZoomOut: Boolean;
begin
  Result := CanZoom(-1);
end;

function TSdDiagramView.ZoomPercent: Integer;
begin
  Result := FZoom;
end;

function TSdDiagramView.CanZoom(Delta: Integer): Boolean;
begin
  Result := CanStepZoom(FZoom, Delta, MinZoom, MaxZoom);
end;

procedure TSdDiagramView.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
begin
  if AtPoint then StepZoom(Delta, ScreenToClient(At))
  else StepZoom(Delta, Point(ClientWidth div 2, ClientHeight div 2));
end;

procedure TSdDiagramView.ZoomTo(Percent: Integer);
begin
  SetZoom(Percent, Point(ClientWidth div 2, ClientHeight div 2));
end;

{ a diagram has a Fit (an empty one keeps its zoom) }
function TSdDiagramView.CanZoomFit: Boolean;
begin
  Result := True;
end;

{ the whole diagram in the window: the zoom its size at the zoom shown tells, a little less until
  it fits (sizes are rounded at each zoom), the top left in view }
procedure TSdDiagramView.ZoomFit;
var
  Z, CW, CH, N: Integer;
begin
  if (FBoxes.Count = 0) or (FSize.X <= 0) or (FSize.Y <= 0) then Exit;
  CW := ClientWidth;
  CH := ClientHeight - FTopSpace;
  Z := FZoom * CW div FSize.X;
  if FZoom * CH div FSize.Y < Z then Z := FZoom * CH div FSize.Y;
  N := 0;
  repeat
    SetZoom(Z, Point(0, 0));
    Z := FZoom - Max(1, FZoom div 20);
    Inc(N);
  until ((FSize.X <= CW) and (FSize.Y <= CH)) or (FZoom <= MinZoom) or (N > 8);
  ScrollTo(0, 0);
end;

procedure TSdDiagramView.ResetView;
var
  I: Integer;
begin
  FZoom := 100;
  for I := 0 to FBoxes.Count - 1 do TDiagramBox(FBoxes[I]).Open := False;
  FSel := nil;
  FSelMember := -1;
  FOrigin := Point(0, 0);
  Layout;
  UpdateScrollBars;
  Invalidate;
  ZoomChanged(Self);
end;

{ --- scrolling --- }

function TSdDiagramView.ContentSize: TPoint;
begin
  Result := FSize;
end;

function TSdDiagramView.LineSize: Integer;
begin
  Result := FRowH;
end;

procedure TSdDiagramView.ScrollBy(DX, DY: Integer);
begin
  ScrollTo(FOrigin.X + DX, FOrigin.Y + DY);
end;

{ the wheel scrolls (with Shift: sideways); with the zoom key it zooms at the pointer (SdZoom) }
function TSdDiagramView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  D: Integer;
begin
  Result := True;
  if ZoomByWheel(Self, FWheelZoom, WheelZooms(Shift), WheelDelta, MousePos) then Exit;
  D := -WheelDelta * 3 * FRowH div WHEEL_DELTA;
  if ssShift in Shift then ScrollBy(D, 0) else ScrollBy(0, D);
end;

procedure TSdDiagramView.Resize;
begin
  inherited;
  { another width wraps the rows elsewhere; the boxes' sizes stay (every change of them - the
    structure, the zoom, a box opened, the font - is a whole Layout) }
  if HandleAllocated and (Width <> FLayoutWidth) and (FBoxes.Count > 0) then Arrange;
  UpdateScrollBars;
  Invalidate;
end;

{ --- the selection, the mouse and the keyboard --- }

{ the box that opens and closes B, in the diagram's coordinates }
function TSdDiagramView.ButtonRect(Box: TObject): TRect;
var
  B: TDiagramBox;
  E: Integer;
begin
  B := TDiagramBox(Box);
  E := ExpandSize;
  Result.Left := B.R.Right - S(Pad) - E;
  Result.Top := B.R.Top + (FHeadH - E) div 2;
  Result.Right := Result.Left + E;
  Result.Bottom := Result.Top + E;
end;

procedure TSdDiagramView.HitTest(X, Y: Integer; out Box: TObject; out Member: Integer; out OnButton: Boolean);
var
  I, J: Integer;
  B: TDiagramBox;
  P: TPoint;
  R: TRect;
begin
  Box := nil;
  Member := -1;
  OnButton := False;
  P := Point(X + FOrigin.X, Y + FOrigin.Y);
  for I := 0 to FOrder.Count - 1 do
  begin
    B := TDiagramBox(FOrder[I]);
    if not PtInRect(B.R, P) then Continue;
    Box := B;
    if B.HasButton then
    begin
      { the box and a few pixels around it }
      R := ButtonRect(B);
      InflateRect(R, S(3), S(3));
      OnButton := PtInRect(R, P);
    end;
    if B.Shown then
      for J := 0 to B.Members.Count - 1 do
        with TDiagramMember(B.Members[J]) do
          if (P.Y >= B.R.Top + Top) and (P.Y < B.R.Top + Top + FRowH) then Member := J;
    Exit;
  end;
end;

procedure TSdDiagramView.Select(Box: TObject; Member: Integer);
begin
  if (Box = FSel) and (Member = FSelMember) then Exit;
  FSel := Box;
  FSelMember := Member;
  Invalidate;
end;

{ the selected box, or the row of the selected member, scrolled into view }
procedure TSdDiagramView.MakeVisible;
var
  B: TDiagramBox;
  R: TRect;
  X, Y: Integer;
begin
  if FSel = nil then Exit;
  B := TDiagramBox(FSel);
  R := B.R;
  if FSelMember >= 0 then
  begin
    R.Top := B.R.Top + TDiagramMember(B.Members[FSelMember]).Top;
    R.Bottom := R.Top + FRowH;
  end;
  X := FOrigin.X;
  Y := FOrigin.Y;
  if R.Right - X > ClientWidth then X := R.Right - ClientWidth + S(Margin);
  if R.Left - X < 0 then X := R.Left - S(Margin);
  if R.Bottom - Y > ClientHeight then Y := R.Bottom - ClientHeight + S(Margin);
  if R.Top - Y < FTopSpace then Y := R.Top - FTopSpace - S(Margin);
  ScrollTo(X, Y);
end;

procedure TSdDiagramView.GotoSelected;
var
  B: TDiagramBox;
begin
  if (FSel = nil) or not Assigned(FOnGoto) then Exit;
  B := TDiagramBox(FSel);
  if B.Foreign then Exit;                       // declared in another unit
  if FSelMember >= 0 then
    with TDiagramMember(B.Members[FSelMember]) do FOnGoto(Self, Line, Col)
  else
    FOnGoto(Self, B.Line, B.Col);
end;

{ Up / Down: the boxes in their order, an open box's members after it }
procedure TSdDiagramView.MoveSelection(Delta: Integer);
var
  Box, Member: Integer;
begin
  if FOrder.Count = 0 then Exit;
  Box := FOrder.IndexOf(FSel);
  Member := FSelMember;
  if Box < 0 then
  begin
    Box := 0;
    Member := -1;
  end
  else if Delta > 0 then
  begin
    if TDiagramBox(FOrder[Box]).Shown and (Member + 1 < TDiagramBox(FOrder[Box]).Members.Count) then Inc(Member)
    else if Box + 1 < FOrder.Count then
    begin
      Inc(Box);
      Member := -1;
    end;
  end
  else if Member >= 0 then Dec(Member)
  else if Box > 0 then
  begin
    Dec(Box);
    if TDiagramBox(FOrder[Box]).Shown then Member := TDiagramBox(FOrder[Box]).Members.Count - 1
    else Member := -1;
  end;
  Select(FOrder[Box], Member);
  MakeVisible;
end;

{ a click chooses a box or a member; on the box in a head it opens or closes that box }
procedure TSdDiagramView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Box: TObject;
  Member: Integer;
  OnButton: Boolean;
begin
  if CanFocus then SetFocus;
  HitTest(X, Y, Box, Member, OnButton);
  Select(Box, Member);
  if OnButton and (Button = mbLeft) then SetOpen(Box, not TDiagramBox(Box).Open);
  inherited;
end;

{ a double click comes without a position through DblClick: taken from the message. The second
  click on a box's open/close box is a click (inherited: MouseDown), not a way to the code }
procedure TSdDiagramView.WMLButtonDblClk(var Message: TWMLButtonDblClk);
var
  Box: TObject;
  Member: Integer;
  OnButton: Boolean;
begin
  HitTest(Message.XPos, Message.YPos, Box, Member, OnButton);
  inherited;
  if (Box <> nil) and not OnButton then
  begin
    Select(Box, Member);
    GotoSelected;
  end;
end;

{ Up / Down choose, Enter goes to the declaration, Right / + open the chosen box, Left / - close
  it (without a choice they scroll sideways), the page keys and Home / End scroll }
procedure TSdDiagramView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP: MoveSelection(-1);
    VK_DOWN: MoveSelection(1);
    VK_RETURN: GotoSelected;
    VK_RIGHT, VK_ADD:
      if FSel <> nil then SetOpen(FSel, True) else if Key = VK_RIGHT then ScrollBy(FRowH, 0);
    VK_LEFT, VK_SUBTRACT:
      if FSel <> nil then
      begin
        FSelMember := -1;
        SetOpen(FSel, False);
        Invalidate;
      end
      else if Key = VK_LEFT then ScrollBy(-FRowH, 0);
    VK_PRIOR: ScrollBy(0, -Max(FRowH, ClientHeight - FTopSpace - FRowH));
    VK_NEXT: ScrollBy(0, Max(FRowH, ClientHeight - FTopSpace - FRowH));
    VK_HOME: ScrollTo(0, 0);
    VK_END: ScrollTo(FOrigin.X, FSize.Y);
  else
    inherited;
    Exit;
  end;
  Key := 0;
end;

procedure TSdDiagramView.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS;
end;

procedure TSdDiagramView.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdDiagramView.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdDiagramView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  if FBoxes.Count > 0 then
  begin
    Layout;
    UpdateScrollBars;
  end;
  Invalidate;
end;

{ --- painting --- }

procedure TSdDiagramView.EraseGround(DC: HDC);
begin
  PaintControlsGround(DC);
end;

{ an icon of the list at the zoom's size: at another size than the list's through an icon made of
  the list's image once (again when the list has another handle) }
procedure TSdDiagramView.PaintIcon(DC: HDC; Icon: TSdIcon; X, Y: Integer);
begin
  if FIcon = 16 then
    ImageList_Draw(IconList.Handle, IconIndex(Icon), DC, X, Y, ILD_TRANSPARENT)
  else
  begin
    if FIconCacheList <> IconList.Handle then
    begin
      FreeIconCache;
      FIconCacheList := IconList.Handle;
    end;
    if FIconCache[Icon] = 0 then
      FIconCache[Icon] := ImageList_GetIcon(IconList.Handle, IconIndex(Icon), ILD_TRANSPARENT);
    if FIconCache[Icon] <> 0 then DrawIconEx(DC, X, Y, FIconCache[Icon], FIcon, FIcon, 0, 0, DI_NORMAL);
  end;
end;

procedure TSdDiagramView.FreeIconCache;
var
  I: TSdIcon;
begin
  for I := Low(TSdIcon) to High(TSdIcon) do
    if FIconCache[I] <> 0 then
    begin
      DestroyIcon(FIconCache[I]);
      FIconCache[I] := 0;
    end;
end;

procedure TSdDiagramView.PaintBox(DC: HDC; Box: TObject);
var
  B: TDiagramBox;
  M: TDiagramMember;
  R, T, E: TRect;
  I: Integer;
  Back, Fore, Text: TColor;
  Sel, Focus: Boolean;
begin
  B := TDiagramBox(Box);
  Sel := Box = FSel;
  Focus := Focused;
  R := B.R;
  UIFill(DC, R, clWindow);
  { the head: the icon, the name, the box that opens and closes it (an ancestor of another unit:
    its name in grey, nothing else) }
  T := Rect(R.Left, R.Top, R.Right, R.Top + FHeadH);
  Back := clBtnFace;
  if B.Foreign then Fore := clGrayText else Fore := clBtnText;
  if Sel and (FSelMember < 0) then UITitleColors(Back, Fore, Focus);
  UIFill(DC, T, Back);
  if B.HasButton then
  begin
    E := ButtonRect(B);
    UIDrawExpandBox(DC, E.Left, E.Top, B.Open, E.Right - E.Left);
    T.Right := E.Left - S(IconGap);
  end
  else
    T.Right := T.Right - S(Pad);
  T.Left := T.Left + S(Pad);
  if not B.Foreign then
  begin
    PaintIcon(DC, KindIcon(B.Kind), T.Left, T.Top + (FHeadH - FIcon) div 2);
    T.Left := T.Left + FIcon + S(IconGap);
  end;
  SelectObject(DC, FBoldFont.Handle);
  UIText(DC, B.Name, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, Fore);
  SelectObject(DC, FFont.Handle);
  { the compartments }
  for I := 0 to High(B.Seps) do UIHLine(DC, R.Left, R.Right, R.Top + B.Seps[I], clBtnShadow);
  if B.Shown then
    for I := 0 to B.Members.Count - 1 do
    begin
      M := TDiagramMember(B.Members[I]);
      T := Rect(R.Left + 1, R.Top + M.Top, R.Right - 1, R.Top + M.Top + FRowH);
      Text := clWindowText;
      if Sel and (I = FSelMember) then
        if Focus then
        begin
          UIFill(DC, T, clHighlight);
          Text := clHighlightText;
        end
        else
          UIFill(DC, T, UISelectionTint(clWindow));
      PaintIcon(DC, KindIcon(M.Kind), R.Left + S(Pad), T.Top + (FRowH - FIcon) div 2);
      T.Left := R.Left + S(Pad) + FIcon + S(IconGap);
      T.Right := R.Right - S(Pad);
      UIText(DC, M.Caption, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, Text);
    end;
  { the border: the title colour around the selected box }
  if Sel and (FSelMember < 0) then
  begin
    UITitleColors(Back, Fore, Focus);
    UIFrame(DC, R, Back);
  end
  else
    UIDrawBorder(DC, R);
end;

{ the whole client drawn on a kept bitmap (UIBufferDC), then the client copied to the screen in one
  piece - the client exactly: TSdControl's buffered painting copies the canvas's clip box, which a
  DC given with WM_PRINTCLIENT need not keep inside the client (the border, the scroll bars) }
procedure TSdDiagramView.Paint;
var
  DC: HDC;
  Saved, CW, CH, I, K, CX, PX, Tip: Integer;
  B, Base: TDiagramBox;
  View, R: TRect;
  Line: TColor;
  Dashed: Boolean;
  Pen: HPEN;
  Brush: HBRUSH;
  OldPen: HPEN;
  OldBrush: HBRUSH;
  Pts: array[0..2] of TPoint;
  Msg: string;
begin
  DC := UIBufferDC(FPaintBuf, Self);
  CW := Max(1, ClientWidth);
  CH := Max(1, ClientHeight);
  { the bitmap is kept: the state the drawing gives its DC - the fonts selected, the background
    mode, the origin - goes again afterwards }
  Saved := SaveDC(DC);
  try
    UIFill(DC, Rect(0, 0, CW, CH), clWindow);
    SetBkMode(DC, TRANSPARENT);
    SelectObject(DC, FFont.Handle);
    if FOrder.Count = 0 then
    begin
      if FUnitName <> '' then
      begin
        Msg := 'There are no classes, interfaces or records in ' + FUnitName + '.';
        R := Rect(Margin, Margin + FTopSpace, CW - Margin, CH - Margin);
        SelectObject(DC, Font.Handle);
        UIText(DC, Msg, R, DT_CENTER or DT_WORDBREAK or DT_NOPREFIX, clGrayText);
      end;
    end
    else
    begin
      SetWindowOrgEx(DC, FOrigin.X, FOrigin.Y, nil);
      View := Rect(FOrigin.X, FOrigin.Y, FOrigin.X + CW, FOrigin.Y + CH);
      Line := clGrayText;
      { the lines first: they run behind the boxes they pass }
      for I := 0 to FOrder.Count - 1 do
      begin
        B := TDiagramBox(FOrder[I]);
        CX := B.Center;
        for K := 0 to B.BaseBoxes.Count - 1 do
        begin
          Base := TDiagramBox(B.BaseBoxes[K]);
          { a class's ancestor solid, the interfaces it implements dashed }
          Dashed := (K > 0) and (B.Kind = ckClass);
          PX := Base.Center;
          with B.Routes[K] do
          begin
            EdgeLine(DC, True, CX, Bus, B.R.Top - 1, Line, Dashed);
            if Long then
            begin
              EdgeLine(DC, False, Bus, CX, Lane, Line, Dashed);
              EdgeLine(DC, True, Lane, Below, Bus, Line, Dashed);
              EdgeLine(DC, False, Below, Lane, PX, Line, Dashed);
              EdgeLine(DC, True, PX, Base.R.Bottom + S(ArrowLen), Below, Line, Dashed);
            end
            else
            begin
              EdgeLine(DC, False, Bus, CX, PX, Line, Dashed);
              EdgeLine(DC, True, PX, Base.R.Bottom + S(ArrowLen), Bus, Line, Dashed);
            end;
          end;
        end;
      end;
      { the hollow triangles at the ancestors }
      Pen := CreatePen(PS_SOLID, 1, ColorToRGB(Line));
      Brush := CreateSolidBrush(ColorToRGB(clWindow));
      OldPen := SelectObject(DC, Pen);
      OldBrush := SelectObject(DC, Brush);
      try
        for I := 0 to FOrder.Count - 1 do
        begin
          B := TDiagramBox(FOrder[I]);
          for K := 0 to B.BaseBoxes.Count - 1 do
          begin
            Base := TDiagramBox(B.BaseBoxes[K]);
            PX := Base.Center;
            Tip := Base.R.Bottom;
            Pts[0] := Point(PX, Tip);
            Pts[1] := Point(PX - S(ArrowHalf), Tip + S(ArrowLen));
            Pts[2] := Point(PX + S(ArrowHalf), Tip + S(ArrowLen));
            Polygon(DC, Pts, 3);
          end;
        end;
      finally
        SelectObject(DC, OldBrush);
        SelectObject(DC, OldPen);
        DeleteObject(Brush);
        DeleteObject(Pen);
      end;
      for I := 0 to FOrder.Count - 1 do
        if IntersectRect(R, TDiagramBox(FOrder[I]).R, View) then PaintBox(DC, FOrder[I]);
      SetWindowOrgEx(DC, 0, 0, nil);
    end;
    PaintControlsGround(DC);
  finally
    RestoreDC(DC, Saved);
  end;
  BitBlt(Canvas.Handle, 0, 0, CW, CH, DC, 0, 0, SRCCOPY);
end;

{ --- test mode --- }

function TSdDiagramView.StateText: string;
var
  Sel: string;
  B: TDiagramBox;
  I, Open: Integer;
begin
  Sel := '';
  if FSel <> nil then
  begin
    B := TDiagramBox(FSel);
    Sel := B.Name;
    if FSelMember >= 0 then Sel := Sel + '.' + TDiagramMember(B.Members[FSelMember]).Plain;
  end;
  Open := 0;
  for I := 0 to FBoxes.Count - 1 do
    if TDiagramBox(FBoxes[I]).Open then Inc(Open);
  Result := Format('%d|%s|%d,%d|%dx%d|%d|%d', [FOrder.Count, Sel, FOrigin.X, FOrigin.Y, FSize.X, FSize.Y,
    FZoom, Open]);
end;

procedure TSdDiagramView.BoxesText(List: TStrings);
var
  I, J: Integer;
  B: TDiagramBox;
  E: TRect;
  Button, Bases, Members: string;
begin
  for I := 0 to FOrder.Count - 1 do
  begin
    B := TDiagramBox(FOrder[I]);
    Bases := '';
    for J := 0 to B.BaseBoxes.Count - 1 do
    begin
      if Bases <> '' then Bases := Bases + ',';
      if (J > 0) and (B.Kind = ckClass) then Bases := Bases + '~';
      Bases := Bases + TDiagramBox(B.BaseBoxes[J]).Name;
    end;
    Members := '';
    if B.Shown then
      for J := 0 to B.Members.Count - 1 do
        with TDiagramMember(B.Members[J]) do
          Members := Members + Format('%s@%d,', [Plain, B.R.Top + Top - FOrigin.Y]);
    Button := '';
    if B.HasButton then
    begin
      E := ButtonRect(B);
      Button := Format('%d,%d', [(E.Left + E.Right) div 2 - FOrigin.X, (E.Top + E.Bottom) div 2 - FOrigin.Y]);
    end;
    List.Add(Format('%s|%s|%d|%d,%d,%d,%d|%s|%s|%s', [B.Name, KindName(B.Kind), Ord(B.Open),
      B.R.Left - FOrigin.X, B.R.Top - FOrigin.Y, B.R.Right - FOrigin.X, B.R.Bottom - FOrigin.Y,
      Button, Bases, Members]));
  end;
end;

end.
