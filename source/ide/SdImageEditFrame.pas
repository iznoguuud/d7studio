{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdImageEditFrame;

{ D7 Studio - the image editor of a resource's page in the file area
  (SdResPage): a bitmap, or the images of an icon or a cursor (the list beside the tools: New
  Image, Delete Image), pixel by pixel - Delphi's Image Editor's tools, Visual Studio's keys.

  * The tools (the palette at the left, two columns, as Delphi's): select, lasso, zoom, colour
    picker, eraser, fill, pencil, brush, airbrush, text, line, rectangle, rounded rectangle,
    ellipse, and for a cursor its hot spot. Under them the tool's options: the width of the
    brush, the eraser, the line, the airbrush and of a shape's outline (1 - 8 pixels); a shape
    outlined, outlined and filled, or filled; a selection opaque or transparent (its pixels of
    the secondary colour show what is under them).
  * The left button draws in the primary colour, the right one in the secondary colour (a shape
    outlined and filled is filled with the other one). Shift keeps a line straight or diagonal,
    a rectangle or an ellipse square.
  * A selection (rectangle or lasso) is dragged, or moved by the arrow keys (Shift: 8 pixels);
    Esc puts it down. Cut, Copy, Paste (with transparency: PNG, CF_DIBV5, CF_DIB), Delete,
    Select All; Flip, Rotate and Invert act on the selection, else on the image.
  * Esc ends a drawing that is not finished (the image goes back to how it was).
  * The view: zoom (the wheel with the zoom key at the mouse, SdZoom; the zoom bar on the page bar;
    Ctrl+Shift+M toggles 1:1), the grid between the
    pixels from 6:1 on, panning with the middle button or Space + drag; beside it the image at
    its actual size on a light and on a dark ground.
  * Image commands: Resize (scaled smoothly or by pixels, or the canvas), the colour depth,
    Import (a picture file as a selection), New Image (several sizes at once, empty or scaled
    from the image shown).
  * The colour bar: the palette - an image of up to 256 colours shows its own, and a double click
    changes an entry together with the image's pixels of that colour -, Screen and Inverse for
    icons and cursors, the colours used last; a double click on the primary or the secondary
    colour edits it (RGB, hex, alpha).
  * Undo / Redo per image (50 steps). The tool, its options, the colours and the text font are
    kept ([Image Editor]).
  The view, the tool options, the preview and the colour bar are controls of this unit, made in
  the frame's constructor; the .dfm holds the standard controls. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  ActnList, Menus, SdUI, SdUndo, SdResImage, SdResPage, SdZoom;

type
  TPixelTool = (ptSelect, ptLasso, ptZoom, ptPicker, ptEraser, ptFill, ptPencil, ptBrush,
    ptAirbrush, ptText, ptLine, ptRect, ptRoundRect, ptEllipse, ptHotspot);
  TShapeStyle = (ssOutline, ssOutlineFill, ssFill);
  TBools = array of Boolean;

  TImageEditFrame = class;

  { an image being edited, with its undo and redo steps (TSdImage snapshots of SdUndo's stack) }
  TEditImage = class
  public
    Image: TSdImage;
    Steps: TSdUndoStack;
    Modified: Boolean;
    constructor Create(AImage: TSdImage);
    destructor Destroy; override;
    procedure Snapshot;
    procedure Restore(Back: Boolean);    // Undo (Back) or Redo
    procedure DropLast;            // the last snapshot back, as if nothing had happened
  end;

  { the image, zoomed: scroll bars of its own, the tools on the mouse }
  TSdPixelView = class(TSdControl)
  private
    FDlg: TImageEditFrame;
    FImg: TEditImage;
    FZoom: Integer;
    FScroll: TPoint;
    FWheel, FWheelZoom: Integer;      // parts of wheel notches (UIWheelSteps): scrolling, zoom
    FFitPending: Boolean;
    FDib: HBITMAP;
    FDibDC: HDC;
    FDibBits: PCardinal;
    FDibW, FDibH: Integer;
    { a press of a mouse button }
    FDown: Boolean;
    FButton: TMouseButton;
    FStart, FLast: TPoint;
    FBase: TSdPixels;              // the pixels when a shape began: it is drawn on them at each move
    FSnapped: Boolean;             // the press took an undo step (Esc gives it back)
    FSelecting, FDragging, FPanning, FLassoing: Boolean;
    FPanFrom, FPanScroll: TPoint;
    FLasso: array of TPoint;
    FSpace: Boolean;               // Space is held: the left button pans
    FTimer: TTimer;                // the airbrush sprays while the button is held
    { the selection }
    FSel: TRect;
    FFloat: TSdImage;              // lifted off the image (moved, pasted), at FFloatPos
    FFloatMask: TBools;            // its pixels that belong to it (nil: all): a lasso's, a text's
    FFloatBlend: Boolean;          // laid over the image by its alpha (smooth text), else it replaces
    FFloatPos, FDragOfs, FDragFrom: TPoint;
    FMouse: TPoint;
    function Origin: TPoint;
    function ToImage(X, Y: Integer): TPoint;
    procedure NeedDib(W, H: Integer);
    procedure FreeDib;
    procedure ScrollTo(X, Y: Integer);
    procedure Snap;
    procedure DrawTool(A, B: TPoint);
    procedure Spray(P: TPoint);
    procedure SprayTick(Sender: TObject);
    procedure LiftLasso;
    procedure Nudge(DX, DY: Integer);
    procedure PressCancel(Sender: TObject);
    function ToolCursor(X, Y: Integer): TCursor;
    function FloatVisible(X, Y: Integer; P, Key: Cardinal; Trans: Boolean): Boolean;
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMWantSpecialKey(var Message: TCMWantSpecialKey); message CM_WANTSPECIALKEY;
    procedure WMTextTool(var Message: TMessage); message WM_APP + 77;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure UpdateScrollBars;
    procedure SetImage(Img: TEditImage);
    procedure SetZoom(Z: Integer; const At: TPoint);
    procedure StepZoom(N: Integer; const At: TPoint);
    procedure FitZoom;
    procedure Lift;                    // the selection lifted off the image
    procedure Drop;                    // a lifted selection put down
    procedure DropInto(Img: TSdImage); // ... into another image (the preview's copy)
    { a new lifted selection (pasted, imported, a text): Mask its pixels (nil all), Blend laid over
      by its alpha }
    procedure FloatImage(Img: TSdImage; const Mask: TBools; Blend: Boolean; const At: TPoint);
    procedure ClearSelection;
    function HasSelection: Boolean;
    property Zoom: Integer read FZoom;
    property Sel: TRect read FSel;
    property Floating: TSdImage read FFloat;
  end;

  { the options of the tool: widths, a shape's style, a selection opaque or transparent }
  TSdToolOptions = class(TSdControl)
  private
    FDlg: TImageEditFrame;
    function ItemRect(Kind, Index: Integer): TRect;
    function ItemCount(Kind: Integer): Integer;
  protected
    procedure PaintBuffer(C: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    function DebugText: string;
  end;

  { the image at its actual size (scaled down when it is larger than the room) on a light and a
    dark ground }
  TSdImagePreview = class(TSdControl)
  private
    FDlg: TImageEditFrame;
  protected
    procedure PaintBuffer(C: TCanvas); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { the colours: the primary and the secondary one, a palette, the screen and the screen
    inverted, the colours used last }
  TSdColorBar = class(TSdControl)
  private
    FDlg: TImageEditFrame;
    FColors: TSdPixels;               // the palette shown ($00RRGGBB)
    FImagePalette: Boolean;           // ... the image's own: a double click changes an entry
    FCols, FRows, FCell, FStep: Integer;
    FPrimary, FSecondary: Cardinal;   // $AARRGGBB
    FTransparent, FInverted: Boolean; // offered
    FDblPos: TPoint;                  // where the last double click was (DblClick has no position)
    function PaletteRight: Integer;
    { the palette's cells; -1 the screen, -2 the screen inverted; -10 - n the colour used n-th
      last; -20 the primary colour, -21 the secondary one }
    function CellRect(Index: Integer): TRect;
    function CellAt(X, Y: Integer; var Index: Integer): Boolean;
    function CellColor(Index: Integer): Cardinal;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
  protected
    procedure PaintBuffer(C: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetPalette(const Colors: TSdPixels; ImagePalette, Transparent, Inverted: Boolean);
    function NeededHeight: Integer;
    function IndexOf(C: Cardinal): Integer;
    function DebugText: string;
    property Primary: Cardinal read FPrimary write FPrimary;
    property Secondary: Cardinal read FSecondary write FSecondary;
    property Colors: TSdPixels read FColors;
  end;

  TImageEditFrame = class(TFrame, ISdResEditor, ISdZoomView)
    TopBar: TToolBar;
    tbDepth: TToolButton;
    tbSep5: TToolButton;
    ToolPanel: TPanel;
    Tools: TToolBar;
    lbImages: TListBox;
    BottomPanel: TPanel;
    StatusPanel: TPanel;
    lblStatus: TLabel;
    DepthMenu: TPopupMenu;
    Actions: TActionList;
    aHotspot: TAction;
    EditUndoCommand: TAction;
    EditRedoCommand: TAction;
    EditCutCommand: TAction;
    EditCopyCommand: TAction;
    EditPasteCommand: TAction;
    EditDeleteCommand: TAction;
    aOpaque: TAction;
    aZoomIn: TAction;
    aZoomOut: TAction;
    aGrid: TAction;
    aPreview: TAction;
    aNewImage: TAction;
    aDeleteImage: TAction;
    procedure ToolExecute(Sender: TObject);
    procedure ToolUpdate(Sender: TObject);
    procedure ShapeExecute(Sender: TObject);
    procedure WidthExecute(Sender: TObject);
    procedure ColorStepExecute(Sender: TObject);
    procedure DepthExecute(Sender: TObject);
    procedure DepthUpdate(Sender: TObject);
    procedure CommandExecute(Sender: TObject);
    procedure ActionsExecute(Action: TBasicAction; var Handled: Boolean);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure lbImagesClick(Sender: TObject);
    procedure lbImagesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FKind: TSdImageKind;
    FImages: TList;              // TEditImage
    FCurrent: Integer;
    FTool: TPixelTool;
    FLastTool: TPixelTool;       // the colour picker goes back to it
    FWidth: Integer;             // 1 .. 8
    FStyle: TShapeStyle;
    FTransparentSel: Boolean;
    FGrid, FShowPreview: Boolean;
    FTextFont: TFont;
    FTextSmooth: Boolean;
    FRecent: TSdPixels;          // the colours used last, the last first
    FListChanged: Boolean;       // an image was added or deleted
    FUnzoom: Integer;            // Ctrl+Shift+M: the zoom before 1:1 (0 none)
    FLoaded: Boolean;            // Load ran: the settings are kept when the editor goes
    FView: TSdPixelView;
    FColors: TSdColorBar;
    FOptions: TSdToolOptions;
    FPreview: TSdImagePreview;
    function Current: TEditImage;
    procedure ShowImage(Index: Integer);
    procedure SetTool(T: TPixelTool);
    function Background: Cardinal;
    function HasAlpha: Boolean;
    function HasMask: Boolean;
    procedure Changed;
    procedure ViewChanged;
    procedure Transform(Kind: Integer);
    procedure CopySelection;
    procedure PasteImage;
    procedure DeleteSelection;
    procedure ResizeImage;
    procedure SetDepth(Bits: Integer);
    procedure ImportPicture;
    procedure NewImages;
    procedure DeleteImage;
    procedure PlaceText(const At: TPoint);
    procedure EditBarColor(Secondary: Boolean);
    procedure EditPaletteEntry(Index: Integer);
    procedure LayoutBottom;
    procedure LayoutPreview;
    procedure LoadSettings;
    procedure SaveSettings;
    function AnyModified: Boolean;
  public
    function Conform(P: Cardinal): Cardinal;     // a colour as the current image can hold it
    function ToolColor(Button: TMouseButton): Cardinal;
    function OtherColor(Button: TMouseButton): Cardinal;
    procedure UsedColor(C: Cardinal);
    procedure PickColor(Button: TMouseButton; P: Cardinal);
    procedure ShowStatus;
    function Composite: TSdImage;                // the image with the lifted selection on it (a copy)
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { after the frame has its parent: Images (TSdImage objects, copied - the caller keeps them) of
      Kind }
    procedure Load(Kind: TSdImageKind; Images: TList);
    { copies of the images into Images (the caller frees them); Drop: a lifted selection is put
      down first, else the current image is taken with it (Composite) }
    procedure GetImages(Images: TList; Drop: Boolean);
    { ISdResEditor }
    function EditorModified: Boolean;
    procedure EditorSaved;
    function EditorCheck(Show: Boolean): string;
    procedure EditorFocus;
    function EditorTestText: string;
    function EditorBar: TWinControl;
    function EditorStatus: TWinControl;
    { ISdZoomView (the zoom bar, View | Zoom): the view's zoom, 1:1 .. 32:1 as 100 .. 3200 %; Fit
      as large as the image fits }
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
  end;

implementation

uses
  Math, SdDialogs, SdIcons, SdSettings, SdEncoding, SdFileNames;

{$R *.dfm}

const
  PixelZooms: array[0..12] of Integer = (1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32);
  MaxUndo = 50;
  RecentMax = 8;
  CheckGround = $FFFFFFFF;            // DrawImage's ground: the checkerboard
  DarkGround = $2D2D30;
  Section = 'Image Editor';
  { the palette of a true-colour image: Windows' 16 colours and twelve more }
  BarColors: array[0..27] of Cardinal = (
    $000000, $808080, $800000, $808000, $008000, $008080, $000080, $800080, $808040, $004040,
    $0080FF, $004080, $8000FF, $804000,
    $FFFFFF, $C0C0C0, $FF0000, $FFFF00, $00FF00, $00FFFF, $0000FF, $FF00FF, $FFFF80, $00FF80,
    $80FFFF, $8080FF, $FF0080, $FF8040);
  WidthTools = [ptBrush, ptEraser, ptLine, ptAirbrush, ptRect, ptRoundRect, ptEllipse];
  ShapeTools = [ptRect, ptRoundRect, ptEllipse];
  ToolNames: array[TPixelTool] of string = ('Select', 'Lasso', 'Zoom', 'Pick Colour', 'Eraser', 'Fill',
    'Pencil', 'Brush', 'Airbrush', 'Text', 'Line', 'Rectangle', 'Rounded Rectangle', 'Ellipse', 'Hot Spot');
  WM_TEXTTOOL = WM_APP + 77;

var
  PenCache: array[1..8] of array of TPoint;

{ ---------------------------------------------------------------- pixels }

{ S over D (straight alpha); a destination that is the screen counts as transparent }
function Over(S, D: Cardinal): Cardinal;
var
  SA, DA, OA: Integer;
begin
  SA := S shr 24;
  if SA = 255 then
  begin
    Result := S;
    Exit;
  end;
  if SA = 0 then
  begin
    Result := D;
    Exit;
  end;
  DA := D shr 24;
  OA := SA * 255 + DA * (255 - SA);          // the result's alpha, times 255
  Result := Cardinal((OA + 127) div 255) shl 24 or
    (Cardinal((Integer(S shr 16 and $FF) * SA * 255 + Integer(D shr 16 and $FF) * DA * (255 - SA)) div OA) and $FF) shl 16 or
    (Cardinal((Integer(S shr 8 and $FF) * SA * 255 + Integer(D shr 8 and $FF) * DA * (255 - SA)) div OA) and $FF) shl 8 or
    (Cardinal((Integer(S and $FF) * SA * 255 + Integer(D and $FF) * DA * (255 - SA)) div OA) and $FF);
end;

{ an image in R: in whole steps up to MaxZoom (1: its actual size), smaller ones when it does not
  fit; over a checkerboard of 4 px (Ground CheckGround) or a colour }
procedure DrawImage(DC: HDC; const R: TRect; Img: TSdImage; XorScreen: Boolean; Ground: Cardinal;
  MaxZoom: Integer);
var
  W, H, Z, X, Y, OX, OY, IX, IY, M: Integer;
  Bmp: HBITMAP;
  Bits, P: PCardinal;
  MemDC: HDC;
  Old: HGDIOBJ;
  Back, Board: Cardinal;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then Exit;
  Bmp := UICreateDib32(W, H, Bits);
  if Bmp = 0 then Exit;
  MemDC := CreateCompatibleDC(DC);
  Old := SelectObject(MemDC, Bmp);
  try
    if Ground = CheckGround then Back := RGBOf(clWindow) else Back := Ground;
    Z := 1;
    OX := 0;
    OY := 0;
    M := 1;
    if (Img <> nil) and (Img.Width > 0) and (Img.Height > 0) then
    begin
      Z := Min(Min(W div Img.Width, H div Img.Height), MaxZoom);
      if Z >= 1 then
      begin
        OX := (W - Img.Width * Z) div 2;
        OY := (H - Img.Height * Z) div 2;
      end
      else
      begin
        M := Max((Img.Width + W - 1) div W, (Img.Height + H - 1) div H);
        OX := (W - Img.Width div M) div 2;
        OY := (H - Img.Height div M) div 2;
      end;
    end;
    P := Bits;
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        P^ := Back;
        if (Img <> nil) and (Img.Width > 0) and (X >= OX) and (Y >= OY) then
        begin
          if Z >= 1 then
          begin
            IX := (X - OX) div Z;
            IY := (Y - OY) div Z;
          end
          else
          begin
            IX := (X - OX) * M;
            IY := (Y - OY) * M;
          end;
          if (IX < Img.Width) and (IY < Img.Height) then
          begin
            if Ground <> CheckGround then Board := Ground
            else if ((X - OX) shr 2 + (Y - OY) shr 2) and 1 = 0 then Board := CheckLight
            else Board := CheckDark;
            P^ := ComposePixel(Img.Pixels[IY * Img.Width + IX], Board, XorScreen);
          end;
        end;
        Inc(P);
      end;
    GdiFlush;
    BitBlt(DC, R.Left, R.Top, W, H, MemDC, 0, 0, SRCCOPY);
  finally
    SelectObject(MemDC, Old);
    DeleteDC(MemDC);
    DeleteObject(Bmp);
  end;
end;

{ ---------------------------------------------------------------- drawing }

{ the pixels of a round pen W wide, from its top left: one pixel, two by two, then discs }
procedure NeedPen(W: Integer);
var
  X, Y, N: Integer;
  C, R2: Double;
begin
  if (W < 1) or (W > 8) or (Length(PenCache[W]) > 0) then Exit;
  C := (W - 1) / 2;
  if W <= 2 then R2 := 2 else R2 := Sqr(W / 2) - W / 4;
  N := 0;
  for Y := 0 to W - 1 do
    for X := 0 to W - 1 do
      if Sqr(X - C) + Sqr(Y - C) <= R2 + 1E-6 then
      begin
        SetLength(PenCache[W], N + 1);
        PenCache[W][N] := Point(X, Y);
        Inc(N);
      end;
end;

procedure Stamp(Img: TSdImage; X, Y, W: Integer; C: Cardinal);
var
  I, H: Integer;
begin
  if W <= 1 then
  begin
    Img.SetPixel(X, Y, C);
    Exit;
  end;
  if W > 8 then W := 8;
  NeedPen(W);
  H := (W - 1) div 2;
  for I := 0 to High(PenCache[W]) do Img.SetPixel(X - H + PenCache[W][I].X, Y - H + PenCache[W][I].Y, C);
end;

{ a line of pen stamps (Bresenham) }
procedure StrokeLine(Img: TSdImage; X0, Y0, X1, Y1, W: Integer; C: Cardinal);
var
  DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X1 - X0);
  DY := -Abs(Y1 - Y0);
  if X0 < X1 then SX := 1 else SX := -1;
  if Y0 < Y1 then SY := 1 else SY := -1;
  Err := DX + DY;
  while True do
  begin
    Stamp(Img, X0, Y0, W, C);
    if (X0 = X1) and (Y0 = Y1) then Break;
    E2 := 2 * Err;
    if E2 >= DY then
    begin
      Inc(Err, DY);
      Inc(X0, SX);
    end;
    if E2 <= DX then
    begin
      Inc(Err, DX);
      Inc(Y0, SY);
    end;
  end;
end;

procedure HSpan(Img: TSdImage; X0, X1, Y: Integer; C: Cardinal);
var
  X: Integer;
begin
  for X := Min(X0, X1) to Max(X0, X1) do Img.SetPixel(X, Y, C);
end;

{ the filled ellipse in the box X0,Y0 - X1,Y1 (A. Zingl's algorithm: every size, also even ones) }
procedure FillEllipse(Img: TSdImage; X0, Y0, X1, Y1: Integer; C: Cardinal);
var
  A, B, B1, DX, DY, Err, E2: Int64;
begin
  A := X1 - X0;
  B := Y1 - Y0;
  B1 := B and 1;
  DX := 4 * (1 - A) * B * B;
  DY := 4 * (B1 + 1) * A * A;
  Err := DX + DY + B1 * A * A;
  Inc(Y0, (B + 1) div 2);
  Y1 := Y0 - B1;
  A := 8 * A * A;
  B1 := 8 * B * B;
  repeat
    HSpan(Img, X0, X1, Y0, C);
    HSpan(Img, X0, X1, Y1, C);
    E2 := 2 * Err;
    if E2 <= DY then
    begin
      Inc(Y0);
      Dec(Y1);
      Inc(DY, A);
      Inc(Err, DY);
    end;
    if (E2 >= DX) or (2 * Err > DY) then
    begin
      Inc(X0);
      Dec(X1);
      Inc(DX, B1);
      Inc(Err, DX);
    end;
  until X0 > X1;
  { the tips of a flat ellipse }
  while Y0 - Y1 < B do
  begin
    Img.SetPixel(X0 - 1, Y0, C);
    Img.SetPixel(X1 + 1, Y0, C);
    Inc(Y0);
    Img.SetPixel(X0 - 1, Y1, C);
    Img.SetPixel(X1 + 1, Y1, C);
    Dec(Y1);
  end;
end;

{ the pixels of a shape in a box W x H (row by row) }
function ShapeMask(Tool: TPixelTool; W, H: Integer): TBools;
var
  T: TSdImage;
  I, X, Y, R, EY, X0: Integer;
  E: TBools;
begin
  SetLength(Result, W * H);
  case Tool of
    ptEllipse:
      begin
        T := TSdImage.Create(W, H, 32);
        try
          FillEllipse(T, 0, 0, W - 1, H - 1, 1);
          for I := 0 to W * H - 1 do Result[I] := T.Pixels[I] <> 0;
        finally
          T.Free;
        end;
      end;
    ptRoundRect:
      begin
        { the corners are the quarters of a circle a third of the shorter side wide (at most 24) }
        R := Max(1, Min(Min(W, H) div 3, 12));
        E := ShapeMask(ptEllipse, 2 * R, 2 * R);
        for Y := 0 to H - 1 do
        begin
          if Y < R then EY := Y
          else if Y >= H - R then EY := 2 * R - (H - Y)
          else EY := -1;
          X0 := 0;
          if EY >= 0 then
            while (X0 < R) and not E[EY * 2 * R + X0] do Inc(X0);
          for X := X0 to W - 1 - X0 do Result[Y * W + X] := True;
        end;
      end;
  else
    for I := 0 to W * H - 1 do Result[I] := True;
  end;
end;

{ a mask without its edge: a pixel stays when its four neighbours are in it }
function Erode(const M: TBools; W, H: Integer): TBools;
var
  X, Y, I: Integer;
begin
  SetLength(Result, W * H);
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      I := Y * W + X;
      Result[I] := M[I] and (X > 0) and M[I - 1] and (X < W - 1) and M[I + 1] and (Y > 0) and M[I - W] and
        (Y < H - 1) and M[I + W];
    end;
end;

{ a rectangle, a rounded rectangle or an ellipse in the box of A and B: its outline Width wide
  in Outline, its inside in Fill, as Style says }
procedure DrawShape(Img: TSdImage; Tool: TPixelTool; Style: TShapeStyle; A, B: TPoint; Width: Integer;
  Outline, Fill: Cardinal);
var
  X0, Y0, W, H, I, K: Integer;
  M, E: TBools;
begin
  X0 := Min(A.X, B.X);
  Y0 := Min(A.Y, B.Y);
  W := Abs(B.X - A.X) + 1;
  H := Abs(B.Y - A.Y) + 1;
  M := ShapeMask(Tool, W, H);
  if Style <> ssOutline then
    for I := 0 to W * H - 1 do
      if M[I] then Img.SetPixel(X0 + I mod W, Y0 + I div W, Fill);
  if Style <> ssFill then
  begin
    E := Copy(M, 0, Length(M));
    for K := 1 to Width do E := Erode(E, W, H);
    for I := 0 to W * H - 1 do
      if M[I] and not E[I] then Img.SetPixel(X0 + I mod W, Y0 + I div W, Outline);
  end;
end;

procedure FloodFill(Img: TSdImage; X, Y: Integer; C: Cardinal);
var
  Target: Cardinal;
  Stack: array of Integer;
  N, P, L, R: Integer;

  procedure Push(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= Img.Width) or (PY >= Img.Height) then Exit;
    if Img.Pixels[PY * Img.Width + PX] <> Target then Exit;
    if N >= Length(Stack) then SetLength(Stack, Length(Stack) * 2 + 64);
    Stack[N] := PY * Img.Width + PX;
    Inc(N);
  end;

begin
  if (X < 0) or (Y < 0) or (X >= Img.Width) or (Y >= Img.Height) then Exit;
  Target := Img.Pixels[Y * Img.Width + X];
  if Target = C then Exit;
  N := 0;
  Push(X, Y);
  while N > 0 do
  begin
    Dec(N);
    P := Stack[N];
    X := P mod Img.Width;
    Y := P div Img.Width;
    if Img.Pixels[P] <> Target then Continue;
    L := X;
    while (L > 0) and (Img.Pixels[Y * Img.Width + L - 1] = Target) do Dec(L);
    R := X;
    while (R < Img.Width - 1) and (Img.Pixels[Y * Img.Width + R + 1] = Target) do Inc(R);
    for X := L to R do
    begin
      Img.Pixels[Y * Img.Width + X] := C;
      Push(X, Y - 1);
      Push(X, Y + 1);
    end;
  end;
end;

{ Shift: a line straight or at 45 degrees, a square box }
function Constrain(Tool: TPixelTool; A, B: TPoint): TPoint;
var
  DX, DY, D: Integer;
begin
  Result := B;
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  if (Tool = ptLine) and (Abs(DX) > 2 * Abs(DY)) then Result.Y := A.Y
  else if (Tool = ptLine) and (Abs(DY) > 2 * Abs(DX)) then Result.X := A.X
  else
  begin
    D := Max(Abs(DX), Abs(DY));
    if DX < 0 then Result.X := A.X - D else Result.X := A.X + D;
    if DY < 0 then Result.Y := A.Y - D else Result.Y := A.Y + D;
  end;
end;

{ a text in Font as an image of its colour: coverage as alpha (Smooth) or whole pixels; Mask: the
  pixels it covers }
function RenderText(const Text: WideString; Font: TFont; Smooth: Boolean; Color: Cardinal;
  var Mask: TBools): TSdImage;
var
  DC: HDC;
  LF: TLogFont;
  F, OldF: HFONT;
  R: TRect;
  Bmp: HBITMAP;
  Bits, P: PCardinal;
  OldB: HGDIOBJ;
  I, Cov: Integer;
begin
  Result := nil;
  Mask := nil;
  if Text = '' then Exit;
  GetObject(Font.Handle, SizeOf(LF), @LF);
  if Smooth then LF.lfQuality := ANTIALIASED_QUALITY else LF.lfQuality := NONANTIALIASED_QUALITY;
  F := CreateFontIndirect(LF);
  DC := CreateCompatibleDC(0);
  try
    OldF := SelectObject(DC, F);
    try
      R := Rect(0, 0, 0, 0);
      DrawTextW(DC, PWideChar(Text), Length(Text), R, DT_CALCRECT or DT_NOPREFIX);
      if (R.Right <= 0) or (R.Bottom <= 0) then Exit;
      Bmp := UICreateDib32(R.Right, R.Bottom, Bits);
      if Bmp = 0 then Exit;
      OldB := SelectObject(DC, Bmp);
      try
        SetTextColor(DC, $FFFFFF);
        SetBkMode(DC, TRANSPARENT);
        DrawTextW(DC, PWideChar(Text), Length(Text), R, DT_NOPREFIX);
        GdiFlush;
        Result := TSdImage.Create(R.Right, R.Bottom, 32);
        SetLength(Mask, R.Right * R.Bottom);
        P := Bits;
        for I := 0 to R.Right * R.Bottom - 1 do
        begin
          Cov := (P^ shr 8) and $FF;           // the green channel: the coverage
          if Smooth then
          begin
            Mask[I] := Cov > 0;
            if Cov > 0 then Result.Pixels[I] := Cardinal(Cov) shl 24 or (Color and $FFFFFF);
          end
          else
          begin
            Mask[I] := Cov >= 128;
            if Mask[I] then Result.Pixels[I] := $FF000000 or (Color and $FFFFFF);
          end;
          Inc(P);
        end;
      finally
        SelectObject(DC, OldB);
        DeleteObject(Bmp);
      end;
    finally
      SelectObject(DC, OldF);
    end;
  finally
    DeleteDC(DC);
    DeleteObject(F);
  end;
end;

function FloorDiv(A, B: Integer): Integer;
begin
  Result := A div B;
  if (A mod B <> 0) and (A < 0) then Dec(Result);
end;

{ ---------------------------------------------------------------- TEditImage }

constructor TEditImage.Create(AImage: TSdImage);
begin
  inherited Create;
  Image := AImage;
  Steps := TSdUndoStack.Create(MaxUndo);
end;

destructor TEditImage.Destroy;
begin
  Steps.Free;
  Image.Free;
  inherited Destroy;
end;

procedure TEditImage.Snapshot;
begin
  Steps.Done(Image.Clone);
end;

{ Undo or Redo: the image as it was, the current one kept for the way back }
procedure TEditImage.Restore(Back: Boolean);
var
  S: TSdImage;
begin
  if Back then S := TSdImage(Steps.TakeUndo) else S := TSdImage(Steps.TakeRedo);
  if S = nil then Exit;
  if Back then Steps.AddRedo(Image.Clone) else Steps.AddUndo(Image.Clone);
  Image.Assign(S);
  S.Free;
  Modified := True;
end;

procedure TEditImage.DropLast;
var
  S: TSdImage;
begin
  S := TSdImage(Steps.TakeUndo);
  if S = nil then Exit;
  Image.Assign(S);
  S.Free;
end;

{ ---------------------------------------------------------------- TSdPixelView }

constructor TSdPixelView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls];
  TabStop := True;
  FZoom := 8;
  FMouse := Point(-1, -1);
  SetRectEmpty(FSel);
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 40;
  FTimer.OnTimer := SprayTick;
end;

destructor TSdPixelView.Destroy;
begin
  FreeAndNil(FFloat);
  FreeDib;
  inherited Destroy;
end;


procedure TSdPixelView.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FMouse := Point(-1, -1);
  if FDlg <> nil then FDlg.ShowStatus;
end;

{ the keys the view takes from the dialog: Esc while there is something to end (else it is the
  dialog's Cancel), the arrows while there is a selection to move }
procedure TSdPixelView.CMWantSpecialKey(var Message: TCMWantSpecialKey);
begin
  inherited;
  case Message.CharCode of
    VK_ESCAPE:
      if FDown or HasSelection then Message.Result := 1;
    VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
      if HasSelection then Message.Result := 1;
  end;
end;

{ a lost mouse ends a press of a button the guard of UIOnPressCancel does not watch (the right
  one, the middle one) - letting go releases the capture first: that is no loss }
procedure TSdPixelView.WMCaptureChanged(var Message: TMessage);
begin
  inherited;
  if FDown and (FButton <> mbLeft) and (HWND(Message.LParam) <> Handle) and
    ((GetKeyState(VK_RBUTTON) < 0) or (GetKeyState(VK_MBUTTON) < 0)) then PressCancel(Self);
end;

procedure TSdPixelView.FreeDib;
begin
  if FDibDC <> 0 then DeleteDC(FDibDC);
  if FDib <> 0 then DeleteObject(FDib);
  FDibDC := 0;
  FDib := 0;
  FDibW := 0;
  FDibH := 0;
end;

procedure TSdPixelView.NeedDib(W, H: Integer);
begin
  if (W = FDibW) and (H = FDibH) and (FDib <> 0) then Exit;
  FreeDib;
  FDib := UICreateDib32(W, H, FDibBits);
  if FDib = 0 then Exit;
  FDibDC := CreateCompatibleDC(0);
  SelectObject(FDibDC, FDib);
  FDibW := W;
  FDibH := H;
end;

function TSdPixelView.Origin: TPoint;
var
  ZW, ZH: Integer;
begin
  Result := Point(0, 0);
  if FImg = nil then Exit;
  ZW := FImg.Image.Width * FZoom;
  ZH := FImg.Image.Height * FZoom;
  if ZW < ClientWidth then Result.X := (ClientWidth - ZW) div 2 else Result.X := -FScroll.X;
  if ZH < ClientHeight then Result.Y := (ClientHeight - ZH) div 2 else Result.Y := -FScroll.Y;
end;

function TSdPixelView.ToImage(X, Y: Integer): TPoint;
var
  O: TPoint;
begin
  O := Origin;
  Result.X := FloorDiv(X - O.X, FZoom);
  Result.Y := FloorDiv(Y - O.Y, FZoom);
end;

procedure TSdPixelView.UpdateScrollBars;
var
  ZW, ZH, I: Integer;
begin
  if not HandleAllocated then Exit;
  ZW := 0;
  ZH := 0;
  if FImg <> nil then
  begin
    ZW := FImg.Image.Width * FZoom;
    ZH := FImg.Image.Height * FZoom;
  end;
  { twice: a scroll bar that comes takes room from the other direction }
  for I := 1 to 2 do
  begin
    FScroll.X := Max(0, Min(FScroll.X, ZW - ClientWidth));
    UISetScrollBar(Handle, SB_HORZ, ZW, ClientWidth, FScroll.X);
    FScroll.Y := Max(0, Min(FScroll.Y, ZH - ClientHeight));
    UISetScrollBar(Handle, SB_VERT, ZH, ClientHeight, FScroll.Y);
  end;
end;

procedure TSdPixelView.ScrollTo(X, Y: Integer);
begin
  FScroll := Point(X, Y);
  UpdateScrollBars;
  Invalidate;
end;

{ a line is 4 image pixels; the end is clamped by UpdateScrollBars }
procedure TSdPixelView.WMHScroll(var Message: TWMHScroll);
begin
  ScrollTo(UIScrollPos(Handle, SB_HORZ, Message.ScrollCode, FScroll.X, FZoom * 4, ClientWidth, MaxInt div 2),
    FScroll.Y);
end;

procedure TSdPixelView.WMVScroll(var Message: TWMVScroll);
begin
  ScrollTo(FScroll.X,
    UIScrollPos(Handle, SB_VERT, Message.ScrollCode, FScroll.Y, FZoom * 4, ClientHeight, MaxInt div 2));
end;

function TSdPixelView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  if FImg = nil then Exit;
  { the zoom key: a level per whole notch at the mouse (the frame's ISdZoomView) }
  if ZoomByWheel(FDlg, FWheelZoom, WheelZooms(Shift), WheelDelta, MousePos) then Exit;
  if ssShift in Shift then
    ScrollTo(FScroll.X - UIWheelSteps(FWheel, WheelDelta, FZoom * 4), FScroll.Y)
  else
    ScrollTo(FScroll.X, FScroll.Y - UIWheelSteps(FWheel, WheelDelta, FZoom * 4));
end;

{ the zoom changed: the image pixel at At (client coordinates) stays where it is }
procedure TSdPixelView.SetZoom(Z: Integer; const At: TPoint);
var
  P, O: TPoint;
begin
  if (FImg = nil) or (Z = FZoom) then Exit;
  O := Origin;
  P.X := (At.X - O.X) * Z div FZoom;
  P.Y := (At.Y - O.Y) * Z div FZoom;
  FZoom := Z;
  FScroll := Point(P.X - At.X, P.Y - At.Y);
  UpdateScrollBars;
  Invalidate;
  FDlg.ShowStatus;
  ZoomChanged(FDlg);
end;

{ N levels of PixelZooms larger (smaller: N < 0), within them - the zoom is always one of them }
procedure TSdPixelView.StepZoom(N: Integer; const At: TPoint);
var
  I: Integer;
begin
  I := 0;
  while (I < High(PixelZooms)) and (PixelZooms[I] < FZoom) do Inc(I);
  SetZoom(PixelZooms[Max(0, Min(I + N, High(PixelZooms)))], At);
end;

{ as large as the image fits into the view, at most 16:1 }
procedure TSdPixelView.FitZoom;
var
  I: Integer;
begin
  if FImg = nil then Exit;
  if not HandleAllocated or (ClientWidth < 16) then
  begin
    FFitPending := True;
    Exit;
  end;
  FFitPending := False;
  FZoom := 1;
  for I := 0 to High(PixelZooms) do
    if (PixelZooms[I] <= 16) and (FImg.Image.Width * PixelZooms[I] <= ClientWidth - 16) and
      (FImg.Image.Height * PixelZooms[I] <= ClientHeight - 16) then FZoom := PixelZooms[I];
  FScroll := Point(0, 0);
  UpdateScrollBars;
  Invalidate;
  if FDlg <> nil then FDlg.ShowStatus;
  ZoomChanged(FDlg);
end;

procedure TSdPixelView.Resize;
begin
  inherited Resize;
  if FFitPending then FitZoom else UpdateScrollBars;
  Invalidate;
end;

procedure TSdPixelView.SetImage(Img: TEditImage);
begin
  Drop;
  ClearSelection;
  FImg := Img;
  FitZoom;
  Invalidate;
end;

function TSdPixelView.HasSelection: Boolean;
begin
  Result := (FFloat <> nil) or not IsRectEmpty(FSel);
end;

procedure TSdPixelView.ClearSelection;
begin
  SetRectEmpty(FSel);
  Invalidate;
end;

procedure TSdPixelView.Snap;
begin
  FImg.Snapshot;
  FSnapped := True;
end;

{ a pixel of the lifted selection that shows: in its mask, and not the secondary colour of a
  transparent selection }
function TSdPixelView.FloatVisible(X, Y: Integer; P, Key: Cardinal; Trans: Boolean): Boolean;
begin
  Result := ((FFloatMask = nil) or FFloatMask[Y * FFloat.Width + X]) and not (Trans and (P = Key));
end;

procedure TSdPixelView.Lift;
var
  X, Y: Integer;
  R: TRect;
  Img: TSdImage;
begin
  if (FFloat <> nil) or IsRectEmpty(FSel) or (FImg = nil) then Exit;
  Img := FImg.Image;
  IntersectRect(R, FSel, Rect(0, 0, Img.Width, Img.Height));
  if IsRectEmpty(R) then Exit;
  FImg.Snapshot;
  FFloat := TSdImage.Create(R.Right - R.Left, R.Bottom - R.Top, 32);
  FFloatMask := nil;
  FFloatBlend := False;
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
    begin
      FFloat.SetPixel(X - R.Left, Y - R.Top, Img.Pixel(X, Y));
      Img.SetPixel(X, Y, FDlg.Background);
    end;
  FFloatPos := R.TopLeft;
  FSel := R;
  FDlg.Changed;
end;

{ the lasso's pixels lifted off the image: inside its outline (even-odd, by the pixels' centres)
  and on it }
procedure TSdPixelView.LiftLasso;
var
  Img: TSdImage;
  R: TRect;
  W, H, X, Y, I, J, N, K, Count: Integer;
  M: TBools;
  Xs: array of Double;
  YC, T, X0, Y0, X1, Y1: Double;
  P: TPoint;
  Any: Boolean;
begin
  N := Length(FLasso);
  if (N < 2) or (FImg = nil) then Exit;
  Img := FImg.Image;
  R := Rect(FLasso[0].X, FLasso[0].Y, FLasso[0].X + 1, FLasso[0].Y + 1);
  for I := 1 to N - 1 do
  begin
    R.Left := Min(R.Left, FLasso[I].X);
    R.Top := Min(R.Top, FLasso[I].Y);
    R.Right := Max(R.Right, FLasso[I].X + 1);
    R.Bottom := Max(R.Bottom, FLasso[I].Y + 1);
  end;
  IntersectRect(R, R, Rect(0, 0, Img.Width, Img.Height));
  if IsRectEmpty(R) then Exit;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  SetLength(M, W * H);
  SetLength(Xs, N);
  for Y := R.Top to R.Bottom - 1 do
  begin
    YC := Y + 0.5;
    Count := 0;
    for I := 0 to N - 1 do
    begin
      J := (I + 1) mod N;
      X0 := FLasso[I].X + 0.5;
      Y0 := FLasso[I].Y + 0.5;
      X1 := FLasso[J].X + 0.5;
      Y1 := FLasso[J].Y + 0.5;
      if ((Y0 <= YC) and (Y1 > YC)) or ((Y1 <= YC) and (Y0 > YC)) then
      begin
        Xs[Count] := X0 + (YC - Y0) * (X1 - X0) / (Y1 - Y0);
        Inc(Count);
      end;
    end;
    { sorted: few crossings }
    for I := 1 to Count - 1 do
      for J := I downto 1 do
        if Xs[J] < Xs[J - 1] then
        begin
          T := Xs[J];
          Xs[J] := Xs[J - 1];
          Xs[J - 1] := T;
        end;
    I := 0;
    while I + 1 < Count do
    begin
      for X := R.Left to R.Right - 1 do
        if (X + 0.5 >= Xs[I]) and (X + 0.5 < Xs[I + 1]) then M[(Y - R.Top) * W + X - R.Left] := True;
      Inc(I, 2);
    end;
  end;
  { the outline itself, so that a thin lasso takes what it went over }
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    X := FLasso[I].X;
    Y := FLasso[I].Y;
    K := Max(Abs(FLasso[J].X - X), Abs(FLasso[J].Y - Y));
    for Count := 0 to K do
    begin
      if K = 0 then P := FLasso[I]
      else P := Point(X + Round((FLasso[J].X - X) * Count / K), Y + Round((FLasso[J].Y - Y) * Count / K));
      if (P.X >= R.Left) and (P.Y >= R.Top) and (P.X < R.Right) and (P.Y < R.Bottom) then
        M[(P.Y - R.Top) * W + P.X - R.Left] := True;
    end;
  end;
  Any := False;
  for I := 0 to High(M) do
    if M[I] then Any := True;
  if not Any then Exit;
  FImg.Snapshot;
  FFloat := TSdImage.Create(W, H, 32);
  for I := 0 to W * H - 1 do
    if M[I] then
    begin
      X := R.Left + I mod W;
      Y := R.Top + I div W;
      FFloat.Pixels[I] := Img.Pixel(X, Y);
      Img.SetPixel(X, Y, FDlg.Background);
    end;
  FFloatMask := M;
  FFloatBlend := False;
  FFloatPos := R.TopLeft;
  FSel := R;
  FDlg.Changed;
end;

procedure TSdPixelView.FloatImage(Img: TSdImage; const Mask: TBools; Blend: Boolean; const At: TPoint);
begin
  Drop;
  FImg.Snapshot;
  FFloat := Img;
  FFloatMask := Mask;
  FFloatBlend := Blend;
  FFloatPos := At;
  FSel := Bounds(At.X, At.Y, Img.Width, Img.Height);
  FDlg.Changed;
end;

procedure TSdPixelView.DropInto(Img: TSdImage);
var
  X, Y: Integer;
  P, Key, Last, LastOut: Cardinal;
  Trans: Boolean;
begin
  if FFloat = nil then Exit;
  Trans := FDlg.FTransparentSel;
  Key := FDlg.Conform(FDlg.FColors.Secondary);
  { pixels repeat (the preview does this at every move of a drag): the conformed colour of the
    pixel before is taken again for the same colour - below 8 bits each one is a palette search }
  Last := 0;
  LastOut := FDlg.Conform(Last);
  for Y := 0 to FFloat.Height - 1 do
    for X := 0 to FFloat.Width - 1 do
    begin
      P := FFloat.Pixels[Y * FFloat.Width + X];
      if not FloatVisible(X, Y, P, Key, Trans) then Continue;
      if FFloatBlend then P := Over(P, Img.Pixel(FFloatPos.X + X, FFloatPos.Y + Y));
      if P <> Last then
      begin
        Last := P;
        LastOut := FDlg.Conform(P);
      end;
      Img.SetPixel(FFloatPos.X + X, FFloatPos.Y + Y, LastOut);
    end;
end;

procedure TSdPixelView.Drop;
begin
  if FFloat = nil then Exit;
  if FImg <> nil then DropInto(FImg.Image);
  FreeAndNil(FFloat);
  FFloatMask := nil;
  if FImg <> nil then IntersectRect(FSel, FSel, Rect(0, 0, FImg.Image.Width, FImg.Image.Height));
  FDlg.Changed;
  Invalidate;
end;

procedure TSdPixelView.Nudge(DX, DY: Integer);
begin
  if not HasSelection then Exit;
  Lift;
  if FFloat = nil then Exit;
  Inc(FFloatPos.X, DX);
  Inc(FFloatPos.Y, DY);
  FSel := Bounds(FFloatPos.X, FFloatPos.Y, FFloat.Width, FFloat.Height);
  FDlg.Changed;
end;

{ a line, a rectangle, a rounded rectangle or an ellipse from A to B, on the pixels of before }
procedure TSdPixelView.DrawTool(A, B: TPoint);
var
  Img: TSdImage;
  C, Fill: Cardinal;
begin
  Img := FImg.Image;
  Img.Pixels := Copy(FBase, 0, Length(FBase));
  C := FDlg.ToolColor(FButton);
  if FDlg.FTool = ptLine then StrokeLine(Img, A.X, A.Y, B.X, B.Y, FDlg.FWidth, C)
  else
  begin
    if FDlg.FStyle = ssOutlineFill then Fill := FDlg.OtherColor(FButton) else Fill := C;
    DrawShape(Img, FDlg.FTool, FDlg.FStyle, A, B, FDlg.FWidth, C, Fill);
  end;
end;

{ the airbrush: a few pixels in a circle as wide as its size says }
procedure TSdPixelView.Spray(P: TPoint);
var
  R, N, DX, DY: Integer;
  C: Cardinal;
begin
  R := 2 + FDlg.FWidth * 2;
  C := FDlg.ToolColor(FButton);
  for N := 1 to Max(2, R * R div 6) do
  begin
    repeat
      DX := Random(2 * R + 1) - R;
      DY := Random(2 * R + 1) - R;
    until DX * DX + DY * DY <= R * R;
    FImg.Image.SetPixel(P.X + DX, P.Y + DY, C);
  end;
end;

procedure TSdPixelView.SprayTick(Sender: TObject);
begin
  if not FDown or (FDlg.FTool <> ptAirbrush) or (FImg = nil) then
  begin
    FTimer.Enabled := False;
    Exit;
  end;
  Spray(FLast);
  FDlg.ViewChanged;
end;

{ the press ended by Esc or a lost mouse: what it did is undone }
procedure TSdPixelView.PressCancel(Sender: TObject);
begin
  if not FDown then Exit;
  FDown := False;
  FTimer.Enabled := False;
  if FButton <> mbLeft then MouseCapture := False;
  if FPanning then ScrollTo(FPanScroll.X, FPanScroll.Y)
  else if FLassoing then FLasso := nil
  else if FDragging then
  begin
    FFloatPos := FDragFrom;
    if FFloat <> nil then FSel := Bounds(FFloatPos.X, FFloatPos.Y, FFloat.Width, FFloat.Height);
  end
  else if FSelecting then SetRectEmpty(FSel)
  else if FSnapped then FImg.DropLast;
  FPanning := False;
  FLassoing := False;
  FDragging := False;
  FSelecting := False;
  FSnapped := False;
  FBase := nil;
  FDlg.ViewChanged;
  FDlg.ShowStatus;
end;

function InFloat(View: TSdPixelView; P: TPoint): Boolean;
begin
  Result := (View.FFloat <> nil) and (P.X >= View.FFloatPos.X) and (P.Y >= View.FFloatPos.Y) and
    (P.X < View.FFloatPos.X + View.FFloat.Width) and (P.Y < View.FFloatPos.Y + View.FFloat.Height);
end;

function TSdPixelView.ToolCursor(X, Y: Integer): TCursor;
var
  P: TPoint;
begin
  P := ToImage(X, Y);
  if FSpace or FPanning then Result := crHandPoint
  else if (FDlg.FTool in [ptSelect, ptLasso]) and
    (InFloat(Self, P) or (not IsRectEmpty(FSel) and PtInRect(FSel, P))) then Result := crSizeAll
  else if FDlg.FTool = ptText then Result := crIBeam
  else Result := crCross;
end;

procedure TSdPixelView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  C: Cardinal;
  Inside: Boolean;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus and not Focused then SetFocus;
  if (FImg = nil) or FDown then Exit;
  P := ToImage(X, Y);
  FButton := Button;
  FStart := P;
  FLast := P;
  FDown := True;
  FSnapped := False;
  { the VCL holds the mouse for the left button only }
  if Button <> mbLeft then MouseCapture := True;
  if (Button = mbMiddle) or (FSpace and (Button = mbLeft)) then
  begin
    FPanning := True;
    FPanFrom := Point(X, Y);
    FPanScroll := FScroll;
    Cursor := crHandPoint;
    Exit;
  end;
  Inside := (P.X >= 0) and (P.Y >= 0) and (P.X < FImg.Image.Width) and (P.Y < FImg.Image.Height);
  C := FDlg.ToolColor(Button);
  case FDlg.FTool of
    ptPencil:
      begin
        Snap;
        FImg.Image.SetPixel(P.X, P.Y, C);
      end;
    ptBrush, ptEraser:
      begin
        Snap;
        Stamp(FImg.Image, P.X, P.Y, FDlg.FWidth, C);
      end;
    ptAirbrush:
      begin
        Snap;
        Spray(P);
        FTimer.Enabled := True;
      end;
    ptLine, ptRect, ptRoundRect, ptEllipse:
      begin
        Snap;
        FBase := Copy(FImg.Image.Pixels, 0, Length(FImg.Image.Pixels));
        DrawTool(P, P);
      end;
    ptFill:
      begin
        FDown := False;
        if Inside and (FImg.Image.Pixel(P.X, P.Y) <> C) then
        begin
          FImg.Snapshot;
          FloodFill(FImg.Image, P.X, P.Y, C);
          FDlg.UsedColor(C);
          FDlg.Changed;
        end;
      end;
    ptPicker:
      begin
        FDown := False;
        if Inside then FDlg.PickColor(Button, FImg.Image.Pixel(P.X, P.Y));
      end;
    ptZoom:
      begin
        FDown := False;
        if Button = mbRight then StepZoom(-1, Point(X, Y)) else StepZoom(1, Point(X, Y));
      end;
    ptText:
      begin
        { the text's dialog once the click is over (the mouse is the view's until then) }
        FDown := False;
        if Inside and (Button = mbLeft) then PostMessage(Handle, WM_TEXTTOOL, P.X, P.Y);
      end;
    ptHotspot:
      begin
        Snap;
        FImg.Image.HotX := Max(0, Min(P.X, FImg.Image.Width - 1));
        FImg.Image.HotY := Max(0, Min(P.Y, FImg.Image.Height - 1));
      end;
    ptSelect, ptLasso:
      begin
        FDragging := False;
        FSelecting := False;
        if (Button = mbLeft) and not InFloat(Self, P) and not IsRectEmpty(FSel) and PtInRect(FSel, P) then Lift;
        if (Button = mbLeft) and InFloat(Self, P) then
        begin
          FDragging := True;
          FDragOfs := Point(P.X - FFloatPos.X, P.Y - FFloatPos.Y);
          FDragFrom := FFloatPos;
        end
        else
        begin
          Drop;
          SetRectEmpty(FSel);
          if FDlg.FTool = ptLasso then
          begin
            FLassoing := True;
            SetLength(FLasso, 1);
            FLasso[0] := P;
          end
          else
            FSelecting := True;
        end;
      end;
  end;
  if not FDown and (FButton <> mbLeft) then MouseCapture := False;
  if FDlg.FTool in [ptSelect, ptLasso] then Invalidate else FDlg.ViewChanged;
end;

procedure TSdPixelView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P, Q: TPoint;
  C: Cardinal;
  N: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  P := ToImage(X, Y);
  FMouse := P;
  if FDlg <> nil then FDlg.ShowStatus;
  if FImg = nil then Exit;
  if not FDown then
  begin
    Cursor := ToolCursor(X, Y);
    Exit;
  end;
  if FPanning then
  begin
    ScrollTo(FPanScroll.X - (X - FPanFrom.X), FPanScroll.Y - (Y - FPanFrom.Y));
    Exit;
  end;
  C := FDlg.ToolColor(FButton);
  case FDlg.FTool of
    ptPencil:
      StrokeLine(FImg.Image, FLast.X, FLast.Y, P.X, P.Y, 1, C);
    ptBrush, ptEraser:
      StrokeLine(FImg.Image, FLast.X, FLast.Y, P.X, P.Y, FDlg.FWidth, C);
    ptAirbrush:
      Spray(P);
    ptLine, ptRect, ptRoundRect, ptEllipse:
      begin
        Q := P;
        if ssShift in Shift then Q := Constrain(FDlg.FTool, FStart, P);
        DrawTool(FStart, Q);
      end;
    ptHotspot:
      begin
        FImg.Image.HotX := Max(0, Min(P.X, FImg.Image.Width - 1));
        FImg.Image.HotY := Max(0, Min(P.Y, FImg.Image.Height - 1));
      end;
    ptSelect, ptLasso:
      if FDragging then
      begin
        FFloatPos := Point(P.X - FDragOfs.X, P.Y - FDragOfs.Y);
        FSel := Bounds(FFloatPos.X, FFloatPos.Y, FFloat.Width, FFloat.Height);
      end
      else if FSelecting then
      begin
        FSel := Rect(Min(FStart.X, P.X), Min(FStart.Y, P.Y), Max(FStart.X, P.X) + 1, Max(FStart.Y, P.Y) + 1);
        IntersectRect(FSel, FSel, Rect(0, 0, FImg.Image.Width, FImg.Image.Height));
      end
      else if FLassoing then
      begin
        N := Length(FLasso);
        if (FLasso[N - 1].X <> P.X) or (FLasso[N - 1].Y <> P.Y) then
        begin
          SetLength(FLasso, N + 1);
          FLasso[N] := P;
        end;
      end;
  end;
  FLast := P;
  if FDlg.FTool in [ptSelect, ptLasso] then
  begin
    Invalidate;
    if FDragging then FDlg.ViewChanged;
  end
  else
    FDlg.ViewChanged;
end;

procedure TSdPixelView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Drew: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FDown or (Button <> FButton) then Exit;
  FDown := False;
  FTimer.Enabled := False;
  if Button <> mbLeft then MouseCapture := False;
  if FPanning then
  begin
    FPanning := False;
    Cursor := ToolCursor(X, Y);
    Exit;
  end;
  if FLassoing then
  begin
    FLassoing := False;
    LiftLasso;
    FLasso := nil;
  end;
  FBase := nil;
  FSelecting := False;
  FDragging := False;
  Drew := FSnapped and (FDlg.FTool in [ptPencil, ptBrush, ptAirbrush, ptLine, ptRect, ptRoundRect, ptEllipse]);
  FSnapped := False;
  if Drew then FDlg.UsedColor(FDlg.ToolColor(Button));
  if FDlg.FTool in [ptSelect, ptLasso] then
  begin
    Invalidate;
    FDlg.ShowStatus;
  end
  else
    FDlg.Changed;
end;

procedure TSdPixelView.KeyDown(var Key: Word; Shift: TShiftState);
var
  D: Integer;
begin
  inherited KeyDown(Key, Shift);
  if ssShift in Shift then D := 8 else D := 1;
  case Key of
    VK_ESCAPE:
      if FDown then PressCancel(Self)
      else if HasSelection then
      begin
        Drop;
        ClearSelection;
        FDlg.ShowStatus;
      end;
    VK_SPACE:
      if not FSpace then
      begin
        FSpace := True;
        Cursor := crHandPoint;
      end;
    VK_LEFT: if Shift - [ssShift] = [] then Nudge(-D, 0);
    VK_RIGHT: if Shift - [ssShift] = [] then Nudge(D, 0);
    VK_UP: if Shift - [ssShift] = [] then Nudge(0, -D);
    VK_DOWN: if Shift - [ssShift] = [] then Nudge(0, D);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TSdPixelView.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
  if Key = VK_SPACE then
  begin
    FSpace := False;
    Cursor := crCross;
  end;
end;

procedure TSdPixelView.WMTextTool(var Message: TMessage);
begin
  FDlg.PlaceText(Point(Message.WParam, Message.LParam));
end;

procedure TSdPixelView.Paint;
var
  W, H, X, Y, IX, IY, Z, IW, FX, FY, RowKey, LastKey: Integer;
  O: TPoint;
  Cols: array of Integer;
  Row, P, LastRow: PCardinal;
  Bg, Board, C, Key, FP: Cardinal;
  Img: TSdImage;
  XorScreen, Grid, Trans: Boolean;
  R: TRect;

  procedure Dot(DX, DY: Integer; Color: Cardinal);
  begin
    if (DX >= 0) and (DY >= 0) and (DX < W) and (DY < H) then
      PCardinal(Integer(FDibBits) + (DY * W + DX) * 4)^ := Color;
  end;

  { a dotted frame: black and white in turns of four }
  procedure Frame(const S: TRect);
  var
    K: Integer;
  begin
    for K := S.Left to S.Right do
    begin
      if ((K shr 2) and 1) = 0 then C := 0 else C := $FFFFFF;
      Dot(K, S.Top, C);
      Dot(K, S.Bottom, C);
    end;
    for K := S.Top to S.Bottom do
    begin
      if ((K shr 2) and 1) = 0 then C := 0 else C := $FFFFFF;
      Dot(S.Left, K, C);
      Dot(S.Right, K, C);
    end;
  end;

  { the lasso's way so far, dotted }
  procedure Path;
  var
    I, K, N, AX, AY, BX, BY: Integer;
  begin
    for I := 0 to High(FLasso) - 1 do
    begin
      AX := O.X + FLasso[I].X * Z + Z div 2;
      AY := O.Y + FLasso[I].Y * Z + Z div 2;
      BX := O.X + FLasso[I + 1].X * Z + Z div 2;
      BY := O.Y + FLasso[I + 1].Y * Z + Z div 2;
      N := Max(Abs(BX - AX), Abs(BY - AY));
      for K := 0 to N do
      begin
        if N = 0 then
        begin
          IX := AX;
          IY := AY;
        end
        else
        begin
          IX := AX + (BX - AX) * K div N;
          IY := AY + (BY - AY) * K div N;
        end;
        if ((IX + IY) shr 2) and 1 = 0 then Dot(IX, IY, 0) else Dot(IX, IY, $FFFFFF);
      end;
    end;
  end;

begin
  W := ClientWidth;
  H := ClientHeight;
  if (W <= 0) or (H <= 0) then Exit;
  NeedDib(W, H);
  if FDib = 0 then Exit;
  Bg := RGBOf(clWindow);             // the page's ground around the image
  O := Origin;
  Z := FZoom;
  Img := nil;
  if FImg <> nil then Img := FImg.Image;
  XorScreen := (FDlg <> nil) and FDlg.HasMask and (Img <> nil) and (Img.BitCount < 32);
  Grid := FDlg.FGrid and (Z >= 6);
  Trans := FDlg.FTransparentSel;
  Key := FDlg.Conform(FDlg.FColors.Secondary);
  SetLength(Cols, W);
  IW := 0;
  if Img <> nil then IW := Img.Width;
  for X := 0 to W - 1 do
  begin
    Cols[X] := FloorDiv(X - O.X, Z);
    if (Cols[X] < 0) or (Cols[X] >= IW) then Cols[X] := -1;
  end;
  Row := FDibBits;
  LastRow := nil;
  LastKey := -3;
  for Y := 0 to H - 1 do
  begin
    IY := -1;
    if Img <> nil then
    begin
      IY := FloorDiv(Y - O.Y, Z);
      if (IY < 0) or (IY >= Img.Height) then IY := -1;
    end;
    { A row is the row before it, copied, when both show the same: the same image row in the same
      band of the checkerboard (8 px), neither of them a line of the grid - or both the ground
      alone, above or below the image (not the grid's line under it). Key -2: a row of its own.
      At a zoom of Z, Z rows show an image row: they are composed once. }
    if IY >= 0 then
    begin
      if Grid and ((Y - O.Y) mod Z = 0) then RowKey := -2
      else RowKey := IY * 2 + (((Y - O.Y) shr 3) and 1);
    end
    else if Grid and (Img <> nil) and (Y = O.Y + Img.Height * Z) then RowKey := -2
    else RowKey := -1;
    if (RowKey <> -2) and (RowKey = LastKey) then
      Move(LastRow^, Row^, W * SizeOf(Cardinal))
    else
    begin
      P := Row;
      for X := 0 to W - 1 do
      begin
        IX := Cols[X];
        if (IY < 0) or (IX < 0) then
        begin
          P^ := Bg;
          { the grid's lines after the last column and the last row, the image's right and bottom
            edges (its left and top ones are its first pixels' lines) }
          if Grid and (Img <> nil) and
            (((X = O.X + IW * Z) and (Y >= O.Y) and (Y <= O.Y + Img.Height * Z)) or
             ((Y = O.Y + Img.Height * Z) and (X >= O.X) and (X <= O.X + IW * Z))) then
            P^ := ((Bg and $FEFEFE) shr 1) + $505050;
        end
        else
        begin
          if (((X - O.X) shr 3) + ((Y - O.Y) shr 3)) and 1 = 0 then Board := CheckLight else Board := CheckDark;
          C := Img.Pixels[IY * Img.Width + IX];
          if FFloat <> nil then
          begin
            FX := IX - FFloatPos.X;
            FY := IY - FFloatPos.Y;
            if (FX >= 0) and (FY >= 0) and (FX < FFloat.Width) and (FY < FFloat.Height) then
            begin
              FP := FFloat.Pixels[FY * FFloat.Width + FX];
              if FloatVisible(FX, FY, FP, Key, Trans) then
                if FFloatBlend then C := Over(FP, C) else C := FP;
            end;
          end;
          C := ComposePixel(C, Board, XorScreen);
          if Grid and (((X - O.X) mod Z = 0) or ((Y - O.Y) mod Z = 0)) then
            C := ((C and $FEFEFE) shr 1) + $505050;
          P^ := C;
        end;
        Inc(P);
      end;
    end;
    if RowKey <> -2 then
    begin
      LastKey := RowKey;
      LastRow := Row;
    end;
    Inc(Row, W);
  end;
  { the selection, the lasso, the hot spot }
  if (Img <> nil) and HasSelection then
  begin
    if FFloat <> nil then R := Bounds(FFloatPos.X, FFloatPos.Y, FFloat.Width, FFloat.Height) else R := FSel;
    Frame(Rect(O.X + R.Left * Z, O.Y + R.Top * Z, O.X + R.Right * Z - 1, O.Y + R.Bottom * Z - 1));
  end;
  if FLassoing then Path;
  if (Img <> nil) and (FDlg.FKind = ikCursor) then
  begin
    X := O.X + Img.HotX * Z + Z div 2;
    Y := O.Y + Img.HotY * Z + Z div 2;
    for IX := -Max(4, Z) to Max(4, Z) do
    begin
      Dot(X + IX, Y, $FF0000);
      Dot(X, Y + IX, $FF0000);
    end;
  end;
  GdiFlush;
  BitBlt(Canvas.Handle, 0, 0, W, H, FDibDC, 0, 0, SRCCOPY);
end;

{ ---------------------------------------------------------------- TSdToolOptions }

const
  OptWidths = 0;
  OptStyles = 1;
  OptSelection = 2;
  OptRow: array[OptWidths..OptSelection] of Integer = (11, 18, 26);

constructor TSdToolOptions.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Buffered := True;
  RedrawWhole := True;
end;

{ what the tool offers: 8 widths, 3 shape styles, opaque / transparent }
function TSdToolOptions.ItemCount(Kind: Integer): Integer;
begin
  Result := 0;
  if FDlg = nil then Exit;
  case Kind of
    OptWidths: if FDlg.FTool in WidthTools then Result := 8;
    OptStyles: if FDlg.FTool in ShapeTools then Result := 3;
    OptSelection: if FDlg.FTool in [ptSelect, ptLasso] then Result := 2;
  end;
end;

function TSdToolOptions.ItemRect(Kind, Index: Integer): TRect;
var
  Y, K: Integer;
begin
  Y := 4;
  for K := OptWidths to Kind - 1 do
    if ItemCount(K) > 0 then Inc(Y, ItemCount(K) * OptRow[K] + 6);
  Result := Rect(4, Y + Index * OptRow[Kind], ClientWidth - 4, Y + (Index + 1) * OptRow[Kind]);
end;

procedure TSdToolOptions.PaintBuffer(C: TCanvas);
var
  DC: HDC;
  K, I, Th, Mid, Bottom: Integer;
  R, S: TRect;
  On: Boolean;
begin
  DC := C.Handle;
  UIFill(DC, ClientRect, clWindow);
  Bottom := 0;
  for K := OptWidths to OptSelection do
    if ItemCount(K) > 0 then Bottom := ItemRect(K, ItemCount(K) - 1).Bottom;
  if Bottom > 0 then UIDrawBorder(DC, Rect(1, 1, ClientWidth - 1, Bottom + 3));
  for K := OptWidths to OptSelection do
    for I := 0 to ItemCount(K) - 1 do
    begin
      R := ItemRect(K, I);
      case K of
        OptWidths: On := FDlg.FWidth = I + 1;
        OptStyles: On := Ord(FDlg.FStyle) = I;
      else
        On := FDlg.FTransparentSel = (I = 1);
      end;
      if On then UIFill(DC, R, UISelectionTint(clWindow));
      case K of
        OptWidths:
          begin
            Th := I + 1;
            Mid := (R.Top + R.Bottom) div 2;
            UIFill(DC, Rect(R.Left + 4, Mid - Th div 2, R.Right - 4, Mid - Th div 2 + Th), clWindowText);
          end;
        OptStyles:
          begin
            { outlined, outlined and filled, filled }
            S := Rect(R.Left + 6, R.Top + 3, R.Right - 6, R.Bottom - 3);
            if I <> 0 then UIFill(DC, S, clBtnShadow);
            if I <> 2 then UIFrame(DC, S, clWindowText);
          end;
      else
        begin
          { opaque: the selection on its own ground; transparent: on a checkerboard }
          S := Rect(R.Left + 4, R.Top + 3, R.Right - 4, R.Bottom - 3);
          UIFill(DC, S, clWindow);
          if I = 1 then
            for Mid := 0 to (S.Right - S.Left - 1) div 4 do
              for Th := 0 to (S.Bottom - S.Top - 1) div 4 do
                if (Mid + Th) and 1 = 1 then
                  UIFill(DC, Rect(S.Left + Mid * 4, S.Top + Th * 4, Min(S.Right, S.Left + Mid * 4 + 4),
                    Min(S.Bottom, S.Top + Th * 4 + 4)), clBtnFace);
          UIFill(DC, Rect(S.Left + 5, S.Top + 5, S.Right - 5, S.Bottom - 5), clHighlight);
          UIFrame(DC, S, clBtnShadow);
        end;
      end;
      if On then UIFrame(DC, R, clHighlight);
    end;
end;

procedure TSdToolOptions.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  K, I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  for K := OptWidths to OptSelection do
    for I := 0 to ItemCount(K) - 1 do
      if PtInRect(ItemRect(K, I), Point(X, Y)) then
      begin
        case K of
          OptWidths: FDlg.FWidth := I + 1;
          OptStyles: FDlg.FStyle := TShapeStyle(I);
        else
          FDlg.FTransparentSel := I = 1;
        end;
        Invalidate;
        FDlg.ViewChanged;
        FDlg.ShowStatus;
        Exit;
      end;
end;

function TSdToolOptions.DebugText: string;
var
  K, I: Integer;
  R: TRect;
const
  Names: array[OptWidths..OptSelection] of string = ('width', 'style', 'selection');
begin
  Result := '';
  for K := OptWidths to OptSelection do
    for I := 0 to ItemCount(K) - 1 do
    begin
      R := ItemRect(K, I);
      Result := Result + Format('%s%d@%d,%d;', [Names[K], I, (R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2]);
    end;
end;

{ ---------------------------------------------------------------- TSdImagePreview }

constructor TSdImagePreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Buffered := True;
  RedrawWhole := True;
end;

procedure TSdImagePreview.PaintBuffer(C: TCanvas);
var
  DC: HDC;
  Img: TSdImage;
  H: Integer;
  XorScreen: Boolean;
begin
  DC := C.Handle;
  UIFill(DC, ClientRect, clWindow);
  Img := nil;
  if FDlg <> nil then Img := FDlg.Composite;
  try
    XorScreen := (Img <> nil) and FDlg.HasMask and (Img.BitCount < 32);
    H := (ClientHeight - 12) div 2;
    { on the window colour, then on a dark ground, each in its flat frame }
    DrawImage(DC, Rect(5, 5, ClientWidth - 5, 5 + H), Img, XorScreen, RGBOf(clWindow), 1);
    DrawImage(DC, Rect(5, 7 + H, ClientWidth - 5, 7 + 2 * H), Img, XorScreen, DarkGround, 1);
    UIDrawBorder(DC, Rect(4, 4, ClientWidth - 4, 6 + H));
    UIDrawBorder(DC, Rect(4, 6 + H, ClientWidth - 4, 8 + 2 * H));
  finally
    Img.Free;
  end;
end;

{ ---------------------------------------------------------------- TSdColorBar }

constructor TSdColorBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks] - [csAcceptsControls];
  FPrimary := $FF000000;
  FSecondary := $FFFFFFFF;
  FCell := 15;
  FStep := 17;
  FRows := 2;
  FCols := 1;
  Buffered := True;
  RedrawWhole := True;
end;

procedure TSdColorBar.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  FDblPos := Point(Message.XPos, Message.YPos);
  inherited;
end;

{ 256 colours in small cells, 32 x 8; fewer in two rows of larger ones }
procedure TSdColorBar.SetPalette(const Colors: TSdPixels; ImagePalette, Transparent, Inverted: Boolean);
begin
  FColors := Copy(Colors, 0, Length(Colors));
  FImagePalette := ImagePalette;
  if Length(FColors) > 32 then
  begin
    FCell := 8;
    FStep := 9;
    FRows := 8;
  end
  else
  begin
    FCell := 15;
    FStep := 17;
    FRows := 2;
  end;
  FCols := Max(1, (Length(FColors) + FRows - 1) div FRows);
  FTransparent := Transparent;
  FInverted := Inverted;
  Invalidate;
end;

function TSdColorBar.NeededHeight: Integer;
begin
  Result := Max(42, FRows * FStep + 8);
end;

function TSdColorBar.PaletteRight: Integer;
begin
  Result := 56 + FCols * FStep;
end;

function TSdColorBar.CellRect(Index: Integer): TRect;
begin
  case Index of
    -20: Result := Bounds(6, 4, 24, 24);
    -21: Result := Bounds(18, 16, 24, 24);
    -2, -1:
      Result := Bounds(PaletteRight + 8 + (-Index - 1) * 50, 4, 46, 32);
  else
    if Index >= 0 then
      Result := Bounds(56 + (Index mod FCols) * FStep, 4 + (Index div FCols) * FStep, FCell, FCell)
    else
    begin
      { the colours used last: two rows of four after the screen and the screen inverted }
      Index := -10 - Index;
      Result := Bounds(PaletteRight + 8 + 2 * 50 + 4 + (Index mod 4) * 17, 4 + (Index div 4) * 17, 15, 15);
    end;
  end;
end;

function TSdColorBar.CellColor(Index: Integer): Cardinal;
begin
  case Index of
    -20: Result := FPrimary;
    -21: Result := FSecondary;
    -1: Result := PixelTransparent;
    -2: Result := PixelInverted;
  else
    if Index >= 0 then Result := $FF000000 or FColors[Index]
    else Result := FDlg.FRecent[-10 - Index];
  end;
end;

function TSdColorBar.CellAt(X, Y: Integer; var Index: Integer): Boolean;
var
  I: Integer;
  P: TPoint;
begin
  Result := True;
  P := Point(X, Y);
  for I := 0 to High(FColors) do
    if PtInRect(CellRect(I), P) then
    begin
      Index := I;
      Exit;
    end;
  if FTransparent and PtInRect(CellRect(-1), P) then
  begin
    Index := -1;
    Exit;
  end;
  if FInverted and PtInRect(CellRect(-2), P) then
  begin
    Index := -2;
    Exit;
  end;
  if FDlg <> nil then
    for I := 0 to High(FDlg.FRecent) do
      if PtInRect(CellRect(-10 - I), P) then
      begin
        Index := -10 - I;
        Exit;
      end;
  { the primary colour lies over the secondary one }
  if PtInRect(CellRect(-20), P) then
  begin
    Index := -20;
    Exit;
  end;
  if PtInRect(CellRect(-21), P) then
  begin
    Index := -21;
    Exit;
  end;
  Result := False;
end;

function TSdColorBar.IndexOf(C: Cardinal): Integer;
begin
  for Result := 0 to High(FColors) do
    if (FColors[Result] = C and $FFFFFF) and (C shr 24 = 255) then Exit;
  Result := -1;
end;

{ a swatch: the colour, or for the screen a small checkerboard (inverted for the screen inverted) }
procedure DrawSwatch(DC: HDC; const R: TRect; C: Cardinal);
begin
  if C shr 24 = 255 then UIFill(DC, R, SwapRB(C))
  else DrawChecked(DC, R, C, 4, R.TopLeft, True);
  UIFrame(DC, R, clBtnShadow);
end;

procedure TSdColorBar.PaintBuffer(C: TCanvas);
var
  DC: HDC;
  I: Integer;
  R: TRect;
begin
  DC := C.Handle;
  UIFill(DC, ClientRect, Color);
  { the secondary colour behind the primary one }
  DrawSwatch(DC, CellRect(-21), FSecondary);
  DrawSwatch(DC, CellRect(-20), FPrimary);
  for I := 0 to High(FColors) do DrawSwatch(DC, CellRect(I), $FF000000 or FColors[I]);
  SelectObject(DC, Font.Handle);
  SetBkMode(DC, TRANSPARENT);
  if FTransparent then
  begin
    R := CellRect(-1);
    DrawSwatch(DC, R, PixelTransparent);
    UIText(DC, 'Screen', R, DT_CENTER or DT_VCENTER or DT_SINGLELINE, clWindowText);
  end;
  if FInverted then
  begin
    R := CellRect(-2);
    DrawSwatch(DC, R, PixelInverted);
    UIText(DC, 'Inverse', R, DT_CENTER or DT_VCENTER or DT_SINGLELINE, clWhite);
  end;
  if FDlg <> nil then
    for I := 0 to High(FDlg.FRecent) do DrawSwatch(DC, CellRect(-10 - I), FDlg.FRecent[I]);
end;

procedure TSdColorBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  C: Cardinal;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not CellAt(X, Y, I) or (I = -20) or (I = -21) then Exit;
  C := CellColor(I);
  if Button = mbRight then FSecondary := C else FPrimary := C;
  Invalidate;
  if FDlg <> nil then FDlg.ViewChanged;
end;

{ a double click edits: the primary or the secondary colour, or an entry of the palette (of the
  image's own palette: the image changes with it) }
procedure TSdColorBar.DblClick;
var
  I: Integer;
begin
  inherited DblClick;
  if (FDlg = nil) or not CellAt(FDblPos.X, FDblPos.Y, I) then Exit;
  if I = -20 then FDlg.EditBarColor(False)
  else if I = -21 then FDlg.EditBarColor(True)
  else if I >= 0 then FDlg.EditPaletteEntry(I);
end;

function TSdColorBar.DebugText: string;
var
  I: Integer;
  R: TRect;
begin
  Result := Format('primary=%.8x secondary=%.8x cells=', [FPrimary, FSecondary]);
  for I := 0 to High(FColors) do
  begin
    R := CellRect(I);
    Result := Result + Format('%.6x@%d,%d;', [FColors[I], (R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2]);
  end;
  if FTransparent then
  begin
    R := CellRect(-1);
    Result := Result + Format('screen@%d,%d;', [(R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2]);
  end;
  if FInverted then
  begin
    R := CellRect(-2);
    Result := Result + Format('inverse@%d,%d;', [(R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2]);
  end;
  if FDlg <> nil then
    for I := 0 to High(FDlg.FRecent) do
    begin
      R := CellRect(-10 - I);
      Result := Result + Format('recent%.8x@%d,%d;', [FDlg.FRecent[I], (R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2]);
    end;
  R := CellRect(-20);
  Result := Result + Format('primarycell@%d,%d;', [R.Left + 6, R.Top + 6]);
  R := CellRect(-21);
  Result := Result + Format('secondarycell@%d,%d;', [R.Right - 4, R.Bottom - 4]);
end;

{ ---------------------------------------------------------------- TImageEditFrame }

constructor TImageEditFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the command icons first: UIPrepareFrame gives the bars their look and the disabled images }
  TopBar.Images := IconList;
  Tools.Images := IconList;
  DepthMenu.Images := IconList;
  UIPrepareFrame(Self);
  FImages := TList.Create;
  FTextFont := TFont.Create;
  UINoListTracking(lbImages);
  UINoListPadding(lbImages);
  UIFlatBorder(lbImages);
  FOptions := TSdToolOptions.Create(Self);
  FOptions.FDlg := Self;
  FOptions.Align := alClient;
  FOptions.Parent := ToolPanel;
  FPreview := TSdImagePreview.Create(Self);
  FPreview.FDlg := Self;
  FPreview.Align := alRight;
  FPreview.Width := 80;
  FPreview.Parent := Self;
  FView := TSdPixelView.Create(Self);
  FView.FDlg := Self;
  FView.Align := alClient;
  FView.Parent := Self;
  UIOnPressCancel(FView, FView.PressCancel);
  FColors := TSdColorBar.Create(Self);
  FColors.FDlg := Self;
  FColors.Parent := BottomPanel;
  FColors.SetBounds(4, 2, BottomPanel.ClientWidth - 8, 42);
  FColors.Anchors := [akLeft, akTop, akRight];
  FTool := ptPencil;
  FLastTool := ptPencil;
  FWidth := 1;
  FGrid := True;
  FShowPreview := True;
  Randomize;
end;

{ the settings of the editor go with it (the page closes) }
destructor TImageEditFrame.Destroy;
var
  I: Integer;
begin
  if FLoaded then SaveSettings;
  { a press the view still holds must not reach the images freed here (its window goes later and
    takes the capture with it: PressCancel) }
  if FView <> nil then
  begin
    FView.FDown := False;
    FView.FImg := nil;
  end;
  if FImages <> nil then
    for I := 0 to FImages.Count - 1 do TObject(FImages[I]).Free;
  FreeAndNil(FImages);
  FreeAndNil(FTextFont);
  inherited Destroy;
end;

procedure TImageEditFrame.Load(Kind: TSdImageKind; Images: TList);
var
  I: Integer;
begin
  FKind := Kind;
  LoadSettings;
  FLoaded := True;
  for I := 0 to Images.Count - 1 do
  begin
    FImages.Add(TEditImage.Create(TSdImage(Images[I]).Clone));
    lbImages.Items.Add('');
  end;
  lbImages.Visible := Kind <> ikBitmap;
  aNewImage.Visible := Kind <> ikBitmap;
  aDeleteImage.Visible := Kind <> ikBitmap;
  aHotspot.Visible := Kind = ikCursor;
  { the separator before New Image and Delete Image goes with them }
  tbSep5.Visible := Kind <> ikBitmap;
  ShowImage(0);
  SetTool(FTool);
end;

procedure TImageEditFrame.GetImages(Images: TList; Drop: Boolean);
var
  I: Integer;
begin
  if Drop then FView.Drop;
  for I := 0 to FImages.Count - 1 do
    if I = FCurrent then Images.Add(Composite)
    else Images.Add(TEditImage(FImages[I]).Image.Clone);
end;

function TImageEditFrame.AnyModified: Boolean;
var
  I: Integer;
begin
  Result := FListChanged or ((FView <> nil) and (FView.Floating <> nil));
  for I := 0 to FImages.Count - 1 do
    if TEditImage(FImages[I]).Modified then Result := True;
end;

function TImageEditFrame.EditorModified: Boolean;
begin
  Result := AnyModified;
end;

procedure TImageEditFrame.EditorSaved;
var
  I: Integer;
begin
  FListChanged := False;
  for I := 0 to FImages.Count - 1 do TEditImage(FImages[I]).Modified := False;
  lbImages.Invalidate;
end;

function TImageEditFrame.EditorCheck(Show: Boolean): string;
begin
  Result := '';
end;

procedure TImageEditFrame.EditorFocus;
begin
  if FView.CanFocus then FView.SetFocus;
end;

function TImageEditFrame.EditorBar: TWinControl;
begin
  Result := TopBar;
end;

function TImageEditFrame.ZoomPercent: Integer;
begin
  Result := FView.Zoom * 100;
end;

function TImageEditFrame.CanZoom(Delta: Integer): Boolean;
begin
  Result := (Current <> nil) and CanStepZoom(FView.Zoom, Delta, PixelZooms[0], PixelZooms[High(PixelZooms)]);
end;

procedure TImageEditFrame.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
begin
  if AtPoint then FView.StepZoom(Delta, FView.ScreenToClient(At))
  else FView.StepZoom(Delta, Point(FView.ClientWidth div 2, FView.ClientHeight div 2));
end;

{ the level nearest to Percent (the view's zoom is always one of its levels) }
procedure TImageEditFrame.ZoomTo(Percent: Integer);
var
  I, Best: Integer;
begin
  Best := 0;
  for I := 1 to High(PixelZooms) do
    if Abs(PixelZooms[I] * 100 - Percent) < Abs(PixelZooms[Best] * 100 - Percent) then Best := I;
  FView.SetZoom(PixelZooms[Best], Point(FView.ClientWidth div 2, FView.ClientHeight div 2));
end;

function TImageEditFrame.CanZoomFit: Boolean;
begin
  Result := Current <> nil;
end;

procedure TImageEditFrame.ZoomFit;
begin
  FView.FitZoom;
end;

{ the status line under the colour bar }
function TImageEditFrame.EditorStatus: TWinControl;
begin
  Result := StatusPanel;
end;

function TImageEditFrame.Current: TEditImage;
begin
  if (FImages = nil) or (FCurrent < 0) or (FCurrent >= FImages.Count) then Result := nil
  else Result := TEditImage(FImages[FCurrent]);
end;

{ an icon's or a cursor's image has a mask: the screen shows through it }
function TImageEditFrame.HasMask: Boolean;
begin
  Result := FKind <> ikBitmap;
end;

function TImageEditFrame.HasAlpha: Boolean;
begin
  Result := HasMask or ((Current <> nil) and (Current.Image.BitCount = 32));
end;

function TImageEditFrame.Background: Cardinal;
begin
  if HasAlpha then Result := PixelTransparent else Result := Conform(FColors.Secondary);
end;

function TImageEditFrame.Conform(P: Cardinal): Cardinal;
begin
  if Current = nil then Result := P
  else Result := ConformPixel(Current.Image, P, HasMask);
end;

function TImageEditFrame.ToolColor(Button: TMouseButton): Cardinal;
begin
  if FTool = ptEraser then Result := Background
  else if Button = mbRight then Result := Conform(FColors.Secondary)
  else Result := Conform(FColors.Primary);
end;

function TImageEditFrame.OtherColor(Button: TMouseButton): Cardinal;
begin
  if Button = mbRight then Result := Conform(FColors.Primary) else Result := Conform(FColors.Secondary);
end;

{ a colour drawn with joins the colours used last (not the palette's, not the screen) }
procedure TImageEditFrame.UsedColor(C: Cardinal);
var
  I, J: Integer;
begin
  if (C shr 24 = 0) or (FColors.IndexOf(C) >= 0) then Exit;
  J := -1;
  for I := 0 to High(FRecent) do
    if FRecent[I] = C then J := I;
  if J = 0 then Exit;
  if J < 0 then
  begin
    if Length(FRecent) < RecentMax then SetLength(FRecent, Length(FRecent) + 1);
    J := High(FRecent);
  end;
  for I := J downto 1 do FRecent[I] := FRecent[I - 1];
  FRecent[0] := C;
  FColors.Invalidate;
end;

procedure TImageEditFrame.PickColor(Button: TMouseButton; P: Cardinal);
begin
  if Button = mbRight then FColors.Secondary := P else FColors.Primary := P;
  FColors.Invalidate;
  SetTool(FLastTool);
end;

procedure TImageEditFrame.SetTool(T: TPixelTool);
begin
  if (T <> ptSelect) and (T <> ptLasso) and (FView <> nil) then
  begin
    FView.Drop;
    FView.ClearSelection;
  end;
  if (FTool <> ptPicker) and (T = ptPicker) then FLastTool := FTool;
  FTool := T;
  if FOptions <> nil then FOptions.Invalidate;
  ShowStatus;
end;

procedure TImageEditFrame.ToolExecute(Sender: TObject);
begin
  SetTool(TPixelTool(TComponent(Sender).Tag));
end;

procedure TImageEditFrame.ToolUpdate(Sender: TObject);
begin
  TAction(Sender).Checked := FTool = TPixelTool(TComponent(Sender).Tag);
end;

{ Visual Studio's keys of the shapes: the tool (Tag div 3) with its style (Tag mod 3) }
procedure TImageEditFrame.ShapeExecute(Sender: TObject);
const
  Shapes: array[0..2] of TPixelTool = (ptRect, ptRoundRect, ptEllipse);
begin
  FStyle := TShapeStyle(TComponent(Sender).Tag mod 3);
  SetTool(Shapes[TComponent(Sender).Tag div 3]);
end;

{ Larger (Tag 1), smaller (-1), one pixel (0) }
procedure TImageEditFrame.WidthExecute(Sender: TObject);
begin
  case TComponent(Sender).Tag of
    1: FWidth := Min(8, FWidth + 1);
    -1: FWidth := Max(1, FWidth - 1);
  else
    FWidth := 1;
  end;
  FOptions.Invalidate;
  ShowStatus;
end;

{ the next or the previous colour of the palette as the primary (Tag 1, -1) or the secondary
  colour (2, -2) }
procedure TImageEditFrame.ColorStepExecute(Sender: TObject);
var
  T, I, N: Integer;
  C: Cardinal;
begin
  N := Length(FColors.Colors);
  if N = 0 then Exit;
  T := TComponent(Sender).Tag;
  if Abs(T) = 2 then C := FColors.Secondary else C := FColors.Primary;
  I := FColors.IndexOf(C);
  if T > 0 then I := (I + 1) mod N
  else if I <= 0 then I := N - 1
  else Dec(I);
  C := $FF000000 or FColors.Colors[I];
  if Abs(T) = 2 then FColors.Secondary := C else FColors.Primary := C;
  FColors.Invalidate;
end;

procedure TImageEditFrame.DepthExecute(Sender: TObject);
begin
  SetDepth(TComponent(Sender).Tag);
end;

procedure TImageEditFrame.DepthUpdate(Sender: TObject);
begin
  TAction(Sender).Checked := (Current <> nil) and (Current.Image.BitCount = TComponent(Sender).Tag);
end;

{ the commands of the tool bar and the keys, by their action's name }
procedure TImageEditFrame.CommandExecute(Sender: TObject);
var
  N: string;
  P: TPoint;
begin
  N := TComponent(Sender).Name;
  if N = 'EditUndoCommand' then
  begin
    FView.Drop;
    FView.ClearSelection;
    Current.Restore(True);
    Changed;
    ShowImage(FCurrent);
  end
  else if N = 'EditRedoCommand' then
  begin
    FView.Drop;
    FView.ClearSelection;
    Current.Restore(False);
    Changed;
    ShowImage(FCurrent);
  end
  else if N = 'EditCutCommand' then
  begin
    CopySelection;
    DeleteSelection;
  end
  else if N = 'EditCopyCommand' then CopySelection
  else if N = 'EditPasteCommand' then PasteImage
  else if N = 'EditDeleteCommand' then DeleteSelection
  else if N = 'EditSelectAllCommand' then
  begin
    FView.Drop;
    if FTool <> ptLasso then SetTool(ptSelect);
    FView.FSel := Rect(0, 0, Current.Image.Width, Current.Image.Height);
    FView.Invalidate;
    ShowStatus;
  end
  else if N = 'aFlipHorz' then Transform(0)
  else if N = 'aFlipVert' then Transform(1)
  else if N = 'aRotate' then Transform(2)
  else if N = 'aInvert' then Transform(3)
  else if N = 'aOpaque' then
  begin
    FTransparentSel := not FTransparentSel;
    FOptions.Invalidate;
    ViewChanged;
  end
  else if N = 'aResize' then ResizeImage
  else if N = 'aDepth' then
  begin
    P := TopBar.ClientToScreen(Point(tbDepth.Left, tbDepth.Top + tbDepth.Height));
    DepthMenu.Popup(P.X, P.Y);
  end
  else if N = 'aImport' then ImportPicture
  else if N = 'aZoomIn' then FView.StepZoom(1, Point(FView.ClientWidth div 2, FView.ClientHeight div 2))
  else if N = 'aZoomOut' then FView.StepZoom(-1, Point(FView.ClientWidth div 2, FView.ClientHeight div 2))
  else if N = 'aMagnify' then
  begin
    { 1:1 and back }
    if (FView.Zoom = 1) and (FUnzoom > 1) then
    begin
      FView.SetZoom(FUnzoom, Point(FView.ClientWidth div 2, FView.ClientHeight div 2));
      FUnzoom := 0;
    end
    else if FView.Zoom > 1 then
    begin
      FUnzoom := FView.Zoom;
      FView.SetZoom(1, Point(FView.ClientWidth div 2, FView.ClientHeight div 2));
    end;
  end
  else if N = 'aGrid' then
  begin
    FGrid := not FGrid;
    FView.Invalidate;
  end
  else if N = 'aPreview' then
  begin
    FShowPreview := not FShowPreview;
    LayoutPreview;
  end
  else if N = 'aNewImage' then NewImages
  else if N = 'aDeleteImage' then DeleteImage;
end;

{ A command while a mouse button is held in the view (its shortcut): the press ends first, as Esc
  ends it - the command would change or free what the press works on (a lifted selection, the
  image a stroke draws into, the tool). Undo during a stroke takes back just the stroke. }
procedure TImageEditFrame.ActionsExecute(Action: TBasicAction; var Handled: Boolean);
var
  Stroke: Boolean;
begin
  if (FView = nil) or not FView.FDown then Exit;
  Stroke := FView.FSnapped;
  FView.PressCancel(FView);
  Handled := (Action = EditUndoCommand) and Stroke;
end;

{ The action list's update runs for every action that is updated (each tool button's at every idle
  moment): the states are cheap, but the clipboard's is asked of Windows - only when Paste itself
  is updated (Execute updates an action before it runs). }
procedure TImageEditFrame.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
var
  Sel, Img: Boolean;
begin
  Img := Current <> nil;
  Sel := Img and FView.HasSelection;
  EditUndoCommand.Enabled := Img and (Current.Steps.UndoCount > 0);
  EditRedoCommand.Enabled := Img and (Current.Steps.RedoCount > 0);
  EditCutCommand.Enabled := Sel;
  EditCopyCommand.Enabled := Img;
  EditDeleteCommand.Enabled := Sel;
  if Action = EditPasteCommand then
    EditPasteCommand.Enabled := Img and (IsClipboardFormatAvailable(CF_DIB) or
      IsClipboardFormatAvailable(RegisterClipboardFormat('PNG')));
  aZoomIn.Enabled := Img and (FView.Zoom < PixelZooms[High(PixelZooms)]);
  aZoomOut.Enabled := Img and (FView.Zoom > 1);
  aGrid.Checked := FGrid;
  aPreview.Checked := FShowPreview;
  aOpaque.Checked := not FTransparentSel;
  aDeleteImage.Enabled := FImages.Count > 1;
end;

{ the current image changed: its row in the list, the view, the preview, the status }
procedure TImageEditFrame.Changed;
begin
  if Current <> nil then Current.Modified := True;
  lbImages.Invalidate;
  FView.UpdateScrollBars;
  ViewChanged;
  ShowStatus;
end;

{ ... what is shown changed (a drawing on its way) }
procedure TImageEditFrame.ViewChanged;
begin
  FView.Invalidate;
  if FPreview.Visible then FPreview.Invalidate;
end;

function TImageEditFrame.Composite: TSdImage;
begin
  Result := nil;
  if Current = nil then Exit;
  Result := Current.Image.Clone;
  FView.DropInto(Result);
end;

procedure TImageEditFrame.ShowStatus;
var
  S: string;
  Img: TSdImage;
  P: TPoint;
  C: Cardinal;
begin
  if (FView = nil) or (Current = nil) then Exit;
  Img := Current.Image;
  S := Format('%s    %s    zoom %d:1', [Img.FormatText, ToolNames[FTool], FView.Zoom]);
  if FTool in WidthTools then S := S + Format('    width %d', [FWidth]);
  if FKind = ikCursor then S := S + Format('    hot spot %d, %d', [Img.HotX, Img.HotY]);
  P := FView.FMouse;
  if (P.X >= 0) and (P.Y >= 0) and (P.X < Img.Width) and (P.Y < Img.Height) then
  begin
    C := Img.Pixel(P.X, P.Y);
    S := S + Format('    %d, %d  ', [P.X, P.Y]);
    if C shr 24 = 0 then
    begin
      if C = PixelTransparent then S := S + 'screen' else S := S + 'inverse screen';
    end
    else
    begin
      S := S + Format('#%.6x', [C and $FFFFFF]);
      if C shr 24 <> 255 then S := S + Format(' (alpha %d)', [C shr 24]);
    end;
  end;
  if FView.Floating <> nil then S := S + Format('    selection %d x %d', [FView.Floating.Width, FView.Floating.Height])
  else if FView.HasSelection then
    S := S + Format('    selection %d x %d', [FView.Sel.Right - FView.Sel.Left, FView.Sel.Bottom - FView.Sel.Top]);
  lblStatus.Caption := S;
end;

{ the colour bar as tall as its palette, the status line under it }
procedure TImageEditFrame.LayoutBottom;
var
  H: Integer;
begin
  H := FColors.NeededHeight;
  BottomPanel.Height := H + 6 + StatusPanel.Height;
  FColors.SetBounds(4, 2, BottomPanel.ClientWidth - 8, H);
end;

{ the preview as wide as the image (at most 256 pixels), on its own or not at all }
procedure TImageEditFrame.LayoutPreview;
begin
  if Current = nil then Exit;
  FPreview.Width := Max(64, Min(Current.Image.Width, 256)) + 10;
  FPreview.Visible := FShowPreview;
  FPreview.Invalidate;
end;

procedure TImageEditFrame.ShowImage(Index: Integer);
var
  Img: TSdImage;
  Pal: TSdPixels;
  I: Integer;
begin
  if FView <> nil then FView.Drop;
  FCurrent := Index;
  if lbImages.Visible then lbImages.ItemIndex := Index;
  Img := Current.Image;
  if Img.BitCount <= 8 then Pal := Copy(Img.Palette, 0, Length(Img.Palette))
  else
  begin
    SetLength(Pal, Length(BarColors));
    for I := 0 to High(BarColors) do Pal[I] := BarColors[I];
  end;
  FColors.SetPalette(Pal, Img.BitCount <= 8, HasAlpha, HasMask and (Img.BitCount < 32));
  FColors.Primary := Conform(FColors.Primary);
  FColors.Secondary := Conform(FColors.Secondary);
  LayoutBottom;
  LayoutPreview;
  FView.SetImage(Current);
  ShowStatus;
end;

procedure TImageEditFrame.lbImagesClick(Sender: TObject);
begin
  if (lbImages.ItemIndex >= 0) and (lbImages.ItemIndex <> FCurrent) then ShowImage(lbImages.ItemIndex);
end;

procedure TImageEditFrame.lbImagesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  DC: HDC;
  Img: TSdImage;
  R: TRect;
  Fore: TColor;
  S: string;
begin
  DC := lbImages.Canvas.Handle;
  if odSelected in State then
  begin
    UIFill(DC, Rect, clHighlight);
    Fore := clHighlightText;
  end
  else
  begin
    UIFill(DC, Rect, clWindow);
    Fore := clWindowText;
  end;
  if (Index < 0) or (Index >= FImages.Count) then Exit;
  Img := TEditImage(FImages[Index]).Image;
  R := Bounds(Rect.Left + 4, Rect.Top + 4, 32, 32);
  DrawImage(DC, R, Img, HasMask and (Img.BitCount < 32), CheckGround, 1);
  SelectObject(DC, lbImages.Font.Handle);
  SetBkMode(DC, TRANSPARENT);
  R := Classes.Rect(Rect.Left + 42, Rect.Top + 3, Rect.Right - 2, Rect.Top + 21);
  S := Format('%d x %d', [Img.Width, Img.Height]);
  if TEditImage(FImages[Index]).Modified then S := S + ' *';
  UIText(DC, S, R, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX, Fore);
  R := Classes.Rect(Rect.Left + 42, Rect.Top + 21, Rect.Right - 2, Rect.Bottom);
  S := BitCountText(Img.BitCount);
  if Img.Png then S := S + ', PNG';
  UIText(DC, S, R, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX, Fore);
end;

{ ---- the selection and the clipboard ---- }

{ the selection (lifted or not) or the whole image onto the clipboard: PNG, CF_DIBV5 and CF_DIB,
  each with the transparency }
procedure TImageEditFrame.CopySelection;
var
  Img, Part, F: TSdImage;
  R: TRect;
  X, Y: Integer;
  Key: Cardinal;

  procedure Put(Fmt: UINT; const Data: string);
  begin
    if Data <> '' then UIClipboardSet(Fmt, PChar(Data), Length(Data));
  end;

begin
  Img := Current.Image;
  F := FView.Floating;
  if F <> nil then
  begin
    Part := TSdImage.Create(F.Width, F.Height, 32);
    Key := Conform(FColors.Secondary);
    for Y := 0 to F.Height - 1 do
      for X := 0 to F.Width - 1 do
        if FView.FloatVisible(X, Y, F.Pixels[Y * F.Width + X], Key, FTransparentSel) then
          Part.Pixels[Y * F.Width + X] := F.Pixels[Y * F.Width + X];
  end
  else
  begin
    if FView.HasSelection then R := FView.Sel else R := Rect(0, 0, Img.Width, Img.Height);
    Part := TSdImage.Create(R.Right - R.Left, R.Bottom - R.Top, 32);
    for Y := R.Top to R.Bottom - 1 do
      for X := R.Left to R.Right - 1 do Part.SetPixel(X - R.Left, Y - R.Top, Img.Pixel(X, Y));
  end;
  try
    { the screen inverted has no colour outside an icon }
    for X := 0 to High(Part.Pixels) do
      if Part.Pixels[X] shr 24 = 0 then Part.Pixels[X] := PixelTransparent;
    if UIOpenClipboard(Handle) then
      try
        EmptyClipboard;
        Put(RegisterClipboardFormat('PNG'), ImageToPng(Part));
        Put(CF_DIBV5, ImageToDibV5(Part));
        Put(CF_DIB, ImageToDib(Part, False));
      finally
        CloseClipboard;
      end;
  finally
    Part.Free;
  end;
end;

{ the clipboard's picture as a lifted selection at the view's top left: its PNG, else its DIB }
procedure TImageEditFrame.PasteImage;
var
  Fmt: UINT;
  S: string;
  Img: TSdImage;
  At: TPoint;
begin
  Fmt := RegisterClipboardFormat('PNG');
  if not UIOpenClipboard(Handle) then Exit;
  try
    if not IsClipboardFormatAvailable(Fmt) then
      if IsClipboardFormatAvailable(CF_DIBV5) then Fmt := CF_DIBV5 else Fmt := CF_DIB;
    if not UIClipboardGet(Fmt, S) then Exit;
  finally
    CloseClipboard;
  end;
  try
    if (Fmt = CF_DIB) or (Fmt = CF_DIBV5) then Img := DibToImage(S, False) else Img := PictureToImage(S);
  except
    on E: Exception do
    begin
      MessageBox(EditorOwnerWnd(Self), PChar('The clipboard''s picture cannot be pasted: ' + E.Message), 'Paste',
        MB_OK or MB_ICONERROR);
      Exit;
    end;
  end;
  if FTool <> ptLasso then SetTool(ptSelect);
  At := FView.ToImage(0, 0);
  FView.FloatImage(Img, nil, False, Point(Max(0, At.X), Max(0, At.Y)));
end;

procedure TImageEditFrame.DeleteSelection;
var
  X, Y: Integer;
  R: TRect;
begin
  if FView.Floating <> nil then
  begin
    { the lifted pixels go; the image had them taken out already }
    FreeAndNil(FView.FFloat);
    FView.FFloatMask := nil;
  end
  else if FView.HasSelection then
  begin
    Current.Snapshot;
    R := FView.Sel;
    for Y := R.Top to R.Bottom - 1 do
      for X := R.Left to R.Right - 1 do Current.Image.SetPixel(X, Y, Background);
  end;
  FView.ClearSelection;
  Changed;
end;

{ Kind 0: flip horizontally, 1: vertically, 2: a quarter turn clockwise, 3: the colours inverted -
  the selection (lifted first), else the whole image (its hot spot with it) }
procedure TImageEditFrame.Transform(Kind: Integer);
var
  Src, Dst: TSdImage;
  X, Y, W, H: Integer;
  Whole: Boolean;
  P: Cardinal;
  M: TBools;
begin
  if FView.HasSelection then
  begin
    FView.Lift;
    Src := FView.Floating;
    Whole := False;
  end
  else
  begin
    Current.Snapshot;
    Src := Current.Image;
    Whole := True;
  end;
  if Src = nil then Exit;
  W := Src.Width;
  H := Src.Height;
  if Kind = 3 then
  begin
    { the colours of what is opaque, a little or wholly; the screen stays the screen }
    for X := 0 to High(Src.Pixels) do
    begin
      P := Src.Pixels[X];
      if P shr 24 <> 0 then Src.Pixels[X] := (P and $FF000000) or (not P and $FFFFFF);
    end;
    if Whole then
      for X := 0 to High(Src.Pixels) do Src.Pixels[X] := Conform(Src.Pixels[X]);
    Changed;
    Exit;
  end;
  Dst := Src.Clone;
  try
    if Kind = 2 then Dst.SetSize(H, W);
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
        case Kind of
          0: Dst.SetPixel(W - 1 - X, Y, Src.Pixel(X, Y));
          1: Dst.SetPixel(X, H - 1 - Y, Src.Pixel(X, Y));
        else
          Dst.SetPixel(H - 1 - Y, X, Src.Pixel(X, Y));
        end;
    { a lasso's outline goes with its pixels }
    if not Whole and (FView.FFloatMask <> nil) then
    begin
      SetLength(M, W * H);
      for Y := 0 to H - 1 do
        for X := 0 to W - 1 do
          case Kind of
            0: M[Y * W + W - 1 - X] := FView.FFloatMask[Y * W + X];
            1: M[(H - 1 - Y) * W + X] := FView.FFloatMask[Y * W + X];
          else
            M[X * H + H - 1 - Y] := FView.FFloatMask[Y * W + X];
          end;
      FView.FFloatMask := M;
    end;
    if Whole then
      case Kind of
        0: Dst.HotX := W - 1 - Src.HotX;
        1: Dst.HotY := H - 1 - Src.HotY;
      else
        begin
          Dst.HotX := H - 1 - Src.HotY;
          Dst.HotY := Src.HotX;
        end;
      end;
    Src.Assign(Dst);
  finally
    Dst.Free;
  end;
  if not Whole then
    FView.FSel := Bounds(FView.FFloatPos.X, FView.FFloatPos.Y, Src.Width, Src.Height);
  Changed;
  if Whole and (Kind = 2) and (W <> H) then ShowImage(FCurrent);
end;

{ ---- image commands ---- }

procedure TImageEditFrame.ResizeImage;
var
  W, H, Mode, X, Y, OX, OY: Integer;
  Img, New: TSdImage;
begin
  FView.Drop;
  FView.ClearSelection;
  Img := Current.Image;
  W := Img.Width;
  H := Img.Height;
  Mode := 0;
  if not ImageSizeDialog(Self, FKind, W, H, Mode) then Exit;
  if (W = Img.Width) and (H = Img.Height) then Exit;
  Current.Snapshot;
  if Mode <= 1 then New := ScaleImage(Img, W, H, Mode = 0)
  else
  begin
    { the canvas: the pixels stay, at the top left or in the middle; what is new is the
      background }
    New := Img.Clone;
    New.SetSize(W, H);
    for X := 0 to High(New.Pixels) do New.Pixels[X] := Background;
    OX := 0;
    OY := 0;
    if Mode = 3 then
    begin
      OX := (W - Img.Width) div 2;
      OY := (H - Img.Height) div 2;
    end;
    for Y := 0 to Img.Height - 1 do
      for X := 0 to Img.Width - 1 do New.SetPixel(X + OX, Y + OY, Img.Pixel(X, Y));
    New.HotX := Max(0, Min(Img.HotX + OX, W - 1));
    New.HotY := Max(0, Min(Img.HotY + OY, H - 1));
  end;
  try
    New.Png := Img.Png;
    Img.Assign(New);
  finally
    New.Free;
  end;
  Changed;
  ShowImage(FCurrent);
end;

procedure TImageEditFrame.SetDepth(Bits: Integer);
var
  I: Integer;
  Img, Other: TSdImage;
begin
  Img := Current.Image;
  if Img.BitCount = Bits then Exit;
  if HasMask then
    for I := 0 to FImages.Count - 1 do
    begin
      Other := TEditImage(FImages[I]).Image;
      if (I <> FCurrent) and (Other.Width = Img.Width) and (Other.Height = Img.Height) and (Other.BitCount = Bits) then
      begin
        MessageBox(EditorOwnerWnd(Self), PChar(Format('There is an image of %d x %d, %s already.',
          [Img.Width, Img.Height, BitCountText(Bits)])), 'Image Editor', MB_OK or MB_ICONINFORMATION);
        Exit;
      end;
    end;
  FView.Drop;
  FView.ClearSelection;
  Current.Snapshot;
  ConvertImage(Img, Bits, HasMask);
  Img.Png := (Bits = 32) and (Img.Width >= 256) and (Img.Height >= 256) and HasMask;
  Changed;
  ShowImage(FCurrent);
end;

{ a picture file (PNG, BMP, JPEG, GIF, ICO, TIFF) as a lifted selection; one larger than the
  image is scaled to fit it }
procedure TImageEditFrame.ImportPicture;
var
  FileName: string;
  Img, Small: TSdImage;
  F: Double;
begin
  FileName := '';
  if not BrowseFile('Import Picture', 'Pictures (*.png;*.bmp;*.ico;*.jpg;*.jpeg;*.gif;*.tif;*.tiff)|' +
    '*.png;*.bmp;*.ico;*.jpg;*.jpeg;*.gif;*.tif;*.tiff|All files (*.*)|*.*', FileName) then Exit;
  try
    Img := PictureToImage(ReadFileU(FileName));
  except
    on E: Exception do
    begin
      MessageBox(EditorOwnerWnd(Self), PChar(E.Message), 'Import Picture', MB_OK or MB_ICONERROR);
      Exit;
    end;
  end;
  if (Img.Width > Current.Image.Width) or (Img.Height > Current.Image.Height) then
  begin
    F := Min(Current.Image.Width / Img.Width, Current.Image.Height / Img.Height);
    Small := ScaleImage(Img, Max(1, Round(Img.Width * F)), Max(1, Round(Img.Height * F)), True);
    Img.Free;
    Img := Small;
  end;
  if FTool <> ptLasso then SetTool(ptSelect);
  FView.FloatImage(Img, nil, False, Point(0, 0));
end;

{ New Image: sizes not there yet, empty or the image shown scaled to them; kept as PNG at 256 x
  256 and 32 bits, as Windows keeps its large icons }
procedure TImageEditFrame.NewImages;
var
  Sizes: TSdSizes;
  Bits, I, J, Count0: Integer;
  Scale, Have: Boolean;
  Img, Src, Other: TSdImage;
  Skipped: string;
begin
  SetLength(Sizes, 1);
  Sizes[0] := Point(Current.Image.Width, Current.Image.Height);
  Bits := 32;
  Scale := True;
  if not NewImageDialog(Self, FKind, Sizes, Bits, True, Scale) then Exit;
  FView.Drop;
  Src := Current.Image;
  Skipped := '';
  Count0 := FImages.Count;
  for J := 0 to High(Sizes) do
  begin
    Have := False;
    for I := 0 to FImages.Count - 1 do
    begin
      Other := TEditImage(FImages[I]).Image;
      if (Other.Width = Sizes[J].X) and (Other.Height = Sizes[J].Y) and (Other.BitCount = Bits) then Have := True;
    end;
    if Have then
    begin
      Skipped := Skipped + Format(#13#10'%d x %d', [Sizes[J].X, Sizes[J].Y]);
      Continue;
    end;
    if Scale then
    begin
      Img := ScaleImage(Src, Sizes[J].X, Sizes[J].Y, True);
      ConvertImage(Img, Bits, HasMask);
    end
    else
      Img := TSdImage.Create(Sizes[J].X, Sizes[J].Y, Bits);
    Img.Png := (Sizes[J].X >= 256) and (Sizes[J].Y >= 256) and (Bits = 32);
    FImages.Add(TEditImage.Create(Img));
    TEditImage(FImages[FImages.Count - 1]).Modified := True;
    FListChanged := True;
    lbImages.Items.Add('');
  end;
  if Skipped <> '' then
    MessageBox(EditorOwnerWnd(Self), PChar(Format('These images of %s are there already:%s', [BitCountText(Bits), Skipped])),
      'Image Editor', MB_OK or MB_ICONINFORMATION);
  if FImages.Count > Count0 then ShowImage(FImages.Count - 1);     // a new one: the last
end;

procedure TImageEditFrame.DeleteImage;
var
  I: Integer;
begin
  if FImages.Count <= 1 then Exit;
  if MessageBox(EditorOwnerWnd(Self), PChar(Format('Delete the image of %s?', [Current.Image.FormatText])),
    'Confirm', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  FView.Drop;
  I := FCurrent;
  FView.SetImage(nil);
  TObject(FImages[I]).Free;
  FImages.Delete(I);
  lbImages.Items.Delete(I);
  FListChanged := True;
  ShowImage(Min(I, FImages.Count - 1));
end;

{ the text tool: its dialog, then the text as a lifted selection where the image was clicked
  (laid over by its coverage on a 32-bit image, else whole pixels) }
procedure TImageEditFrame.PlaceText(const At: TPoint);
var
  Text: string;
  Img: TSdImage;
  Mask: TBools;
  Smooth: Boolean;
begin
  Text := '';
  if not ImageTextDialog(Self, Text, FTextFont, FTextSmooth) or (Text = '') then Exit;
  Smooth := FTextSmooth and (Current.Image.BitCount = 32);
  Img := RenderText(ToWide(Text, CP_ACP), FTextFont, Smooth, Conform(FColors.Primary), Mask);
  if Img = nil then Exit;
  UsedColor(Conform(FColors.Primary));
  SetTool(ptSelect);
  FView.FloatImage(Img, Mask, Smooth, At);
end;

{ a double click on the primary or the secondary colour: its RGB, hex and alpha (a 32-bit image) }
procedure TImageEditFrame.EditBarColor(Secondary: Boolean);
var
  C: Cardinal;
begin
  if Secondary then C := FColors.Secondary else C := FColors.Primary;
  if C shr 24 = 0 then C := $FF000000 or (C and $FFFFFF);
  if not ColorEditDialog(Self, 'Edit Colour', C, Current.Image.BitCount = 32) then Exit;
  C := Conform(C);
  if Secondary then FColors.Secondary := C else FColors.Primary := C;
  UsedColor(C);
  FColors.Invalidate;
  ViewChanged;
end;

{ a double click on the palette: an entry of the image's own palette changes, and so do the
  image's pixels of its colour; else the bar's colour there }
procedure TImageEditFrame.EditPaletteEntry(Index: Integer);
var
  Img: TSdImage;
  Old, C: Cardinal;
  I: Integer;
  Pal: TSdPixels;
begin
  Img := Current.Image;
  Old := FColors.Colors[Index];
  C := $FF000000 or Old;
  if not ColorEditDialog(Self, 'Edit Palette Colour', C, False) then Exit;
  C := C and $FFFFFF;
  if C = Old then Exit;
  Pal := Copy(FColors.Colors, 0, Length(FColors.Colors));
  Pal[Index] := C;
  if FColors.FImagePalette and (Img.BitCount <= 8) then
  begin
    FView.Drop;
    Current.Snapshot;
    if Index < Length(Img.Palette) then Img.Palette[Index] := C;
    for I := 0 to High(Img.Pixels) do
      if (Img.Pixels[I] shr 24 = 255) and (Img.Pixels[I] and $FFFFFF = Old) then Img.Pixels[I] := $FF000000 or C;
    Changed;
  end;
  FColors.SetPalette(Pal, FColors.FImagePalette, FColors.FTransparent, FColors.FInverted);
  FColors.Primary := $FF000000 or C;
end;

{ ---- settings ---- }

procedure TImageEditFrame.LoadSettings;
var
  L: TStringList;
  I: Integer;
begin
  I := Settings.ReadInteger(Section, 'Tool', Ord(ptPencil));
  if (I >= Ord(Low(TPixelTool))) and (I <= Ord(High(TPixelTool))) then FTool := TPixelTool(I);
  if (FTool = ptHotspot) and (FKind <> ikCursor) then FTool := ptPencil;
  FLastTool := FTool;
  FWidth := Max(1, Min(8, Settings.ReadInteger(Section, 'Width', 1)));
  I := Settings.ReadInteger(Section, 'ShapeStyle', 0);
  if (I >= 0) and (I <= 2) then FStyle := TShapeStyle(I);
  FTransparentSel := Settings.ReadBool(Section, 'TransparentSelection', False);
  FGrid := Settings.ReadBool(Section, 'Grid', True);
  FShowPreview := Settings.ReadBool(Section, 'Preview', True);
  FColors.Primary := Cardinal(StrToInt64Def('$' + Settings.ReadString(Section, 'Primary', 'FF000000'), $FF000000));
  FColors.Secondary := Cardinal(StrToInt64Def('$' + Settings.ReadString(Section, 'Secondary', 'FFFFFFFF'), $FFFFFFFF));
  L := TStringList.Create;
  try
    L.CommaText := Settings.ReadString(Section, 'Recent', '');
    for I := 0 to Min(L.Count, RecentMax) - 1 do
    begin
      SetLength(FRecent, Length(FRecent) + 1);
      FRecent[High(FRecent)] := Cardinal(StrToInt64Def('$' + L[I], 0));
    end;
    L.CommaText := Settings.ReadString(Section, 'TextFont', '"Segoe UI",9,0');
    if L.Count >= 3 then
    begin
      FTextFont.Name := L[0];
      FTextFont.Size := StrToIntDef(L[1], 9);
      FTextFont.Style := TFontStyles(Byte(StrToIntDef(L[2], 0)));
    end;
  finally
    L.Free;
  end;
  FTextSmooth := Settings.ReadBool(Section, 'TextSmooth', True);
end;

procedure TImageEditFrame.SaveSettings;
var
  S: string;
  I: Integer;
begin
  Settings.WriteInteger(Section, 'Tool', Ord(FTool));
  Settings.WriteInteger(Section, 'Width', FWidth);
  Settings.WriteInteger(Section, 'ShapeStyle', Ord(FStyle));
  Settings.WriteBool(Section, 'TransparentSelection', FTransparentSel);
  Settings.WriteBool(Section, 'Grid', FGrid);
  Settings.WriteBool(Section, 'Preview', FShowPreview);
  Settings.WriteString(Section, 'Primary', IntToHex(FColors.Primary, 8));
  Settings.WriteString(Section, 'Secondary', IntToHex(FColors.Secondary, 8));
  S := '';
  for I := 0 to High(FRecent) do
  begin
    if S <> '' then S := S + ',';
    S := S + IntToHex(FRecent[I], 8);
  end;
  Settings.WriteString(Section, 'Recent', S);
  Settings.WriteString(Section, 'TextFont', Format('"%s",%d,%d', [FTextFont.Name, FTextFont.Size,
    Byte(FTextFont.Style)]));
  Settings.WriteBool(Section, 'TextSmooth', FTextSmooth);
end;

function TImageEditFrame.EditorTestText: string;
var
  I: Integer;
  Img: TSdImage;
  H: Cardinal;
  O: TPoint;
  Kinds: array[TSdImageKind] of string;

  function Buttons(Bar: TToolBar; const Name: string): string;
  var
    K: Integer;
    B: TToolButton;
  begin
    Result := '|' + Name + '=';
    for K := 0 to Bar.ButtonCount - 1 do
    begin
      B := Bar.Buttons[K];
      if (B.Style <> tbsSeparator) and B.Visible then
        Result := Result + Format('%s@%d,%d,', [Copy(B.Name, 3, MaxInt), B.Left + B.Width div 2, B.Top + B.Height div 2]);
    end;
  end;

begin
  Kinds[ikBitmap] := 'bitmap';
  Kinds[ikIcon] := 'icon';
  Kinds[ikCursor] := 'cursor';
  Result := Format('%s|%d/%d', [Kinds[FKind], FCurrent, FImages.Count]);
  if Current = nil then Exit;
  Img := Current.Image;
  H := 0;
  for I := 0 to High(Img.Pixels) do H := ((H shl 5) or (H shr 27)) xor Img.Pixels[I];
  O := FView.Origin;
  Result := Result + Format('|%dx%d %d bits%s|tool=%s|width=%d|style=%d|transparent=%d|grid=%d|preview=%d|zoom=%d|origin=%d,%d|sel=%d,%d,%d,%d|float=%d|hot=%d,%d|undo=%d|redo=%d|modified=%d|hash=%.8x|',
    [Img.Width, Img.Height, Img.BitCount, Copy(', PNG', 1, Ord(Img.Png) * 5), ToolNames[FTool], FWidth,
     Ord(FStyle), Ord(FTransparentSel), Ord(FGrid), Ord(FPreview.Visible), FView.Zoom, O.X, O.Y,
     FView.Sel.Left, FView.Sel.Top, FView.Sel.Right, FView.Sel.Bottom, Ord(FView.Floating <> nil),
     Img.HotX, Img.HotY, Current.Steps.UndoCount, Current.Steps.RedoCount, Ord(Current.Modified), H]);
  Result := Result + FColors.DebugText + '|options=' + FOptions.DebugText + Buttons(TopBar, 'topbar') +
    Buttons(Tools, 'tools');
end;

end.
