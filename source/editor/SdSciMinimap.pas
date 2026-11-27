{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSciMinimap;

{ D7 Studio - the code editor's minimap: the text in miniature in a strip between the editor's text
  and its vertical scroll bar (Editor Options | Display | Scroll bars | Minimap).

  Every character is a cell of a few pixels in its style's colour, its top and bottom half shaded by
  the kind of character (a capital, a small letter, one with a descender, a dot ...); a line is two
  cells high. The lines in view lie in the visible-area box, a darker ground than the map's - a
  shade darker while the pointer is on it, darker still while it is dragged. A text longer than the
  strip holds scrolls in it only as far as the box needs to stay in it, so what is drawn under the
  pointer is the text a press brings into view.
  Also drawn: the caret's line, the selections and the ranges of the indicators the editor names
  (the find matches, Error Insight's errors). It shows display lines: folded lines are left out, a
  wrapped line takes its rows.

  Like the scroll bars (SdSciScroll) it lives in the window's non-client area: WM_NCCALCSIZE takes
  its room from the client area's right, WM_NCPAINT paints it through a DIB section in one piece,
  WM_NCHITTEST names it HTBORDER, and its presses are handled here. A press anywhere brings the line
  drawn under the pointer into the middle of the view - the box then lies there, under the pointer -
  and drags the box from there, line for line with the pointer; held beyond the strip's top or
  bottom, the view scrolls on by itself. The wheel scrolls the editor (the window's own); the
  pointer over it shows the code around its line in a tip beside it. It reads
  the text, the styles, the folding and the scrolling from the Scintilla window (SciCall); the
  editor styles what it shows and is not styled yet (OnStyleTo) and makes the tip's lines
  (OnPreview: none, no tip, unless Editor Options | Display | Minimap is Enabled + preview). A change of the text or of the marks repaints it once the
  messages waiting are done (Changed); a scroll, a new caret line or selection at the editor's next
  notification (Update). }

interface

uses
  Windows, Messages, Classes, Graphics, Controls, SdUI, SdHints;

type
  { Scintilla's Sci_TextRange (SCI_GETSTYLEDTEXT, SCI_GETTEXTRANGE) }
  TSciTextRange = record
    cpMin, cpMax: Integer;
    Text: PChar;
  end;

  TSciMapSci = function(Msg: Cardinal; W: Cardinal; L: Integer): Integer of object;
  { the text up to ToPos styled }
  TSciMapStyleTo = procedure(ToPos: Integer) of object;
  { the tip's lines for the document line Line: the code around it }
  TSciMapPreview = procedure(Line: Integer; var Lines: TTipLines) of object;

  { an indicator whose ranges the map tints, and its colour }
  TSciMapTint = record
    Indicator: Integer;
    Color: TColor;
  end;
  TSciMapTints = array of TSciMapTint;

  TSciMapColors = record
    Ground: TColor;              // the map's
    View: TColor;                // the lines in view: the box's ground
    ViewHot, ViewDown: TColor;   // ... while the pointer is on it, while it is dragged
    Tip: TColor;                 // the tip's ground (the editor's)
    Caret: TColor;               // the caret's line: a band of it
    Selection, SelectionText: TColor;   // the selections' ground, their characters' colour
    Tints: TSciMapTints;
  end;

  { the map's geometry against the editor's scrolling, in display lines (rows) }
  TSciMapView = record
    R: TRect;                    // the map in window coordinates
    Cell, LineH: Integer;        // a character's cell and a row, in pixels
    Fit, Rows: Integer;          // the rows the map holds whole, the rows it shows (the last one cut)
    First, Page: Integer;        // the editor's first row in view, its rows in view
    Total: Integer;              // the rows of the text
    Last: Integer;               // the editor's last first row
    Top, TopMax: Integer;        // the map's first row (TSciMinimap.ReadView), its last one
  end;

  { a hook of the editor's window procedure (TUIWindowHook: given back when the map goes) }
  TSciMinimap = class(TUIWindowHook)
  private
    FRoom: Integer;              // the width it takes from the client area (0: none, nothing shown) ...
    FTaken: Integer;             // ... as much of it as the client area had (WM_NCCALCSIZE): never over the bar
    FColors: TSciMapColors;
    FSciCall: TSciMapSci;
    FOnStyleTo: TSciMapStyleTo;
    FOnPreview: TSciMapPreview;
    FDC: HDC;                    // the picture: a DIB section in a memory DC, kept between paints
    FDib, FOldDib: HBITMAP;
    FBits: PCardinal;
    FDibW, FDibH: Integer;
    FBuf: string;                // a row's styled text
    FColOf: array of Integer;    // ... the column of each of its bytes
    FGrounds: array of Cardinal; // ... the ground of each column
    FSelected: array of Boolean; // ... the columns a selection takes (their characters in its text colour)
    { what was painted last: Update paints again when it changed }
    FFirst, FPage, FTotal, FTop, FCaret, FSelA, FSelB, FSelN: Integer;
    FSize: TPoint;
    FDirty: Boolean;             // the text or the marks changed since
    FPosted: Boolean;            // WM_SCIMAPCHANGED is on its way
    FMapTop: Integer;            // the map's first row: it moves only as far as the box needs (-1: placed anew)
    FDown: Boolean;              // the box is dragged
    FHot: Boolean;               // the pointer is on the box
    FGrab: Integer;              // where the box was taken, from its top
    FTracking: Boolean;          // TrackMouseEvent asked for WM_NCMOUSELEAVE
    FMouse: TPoint;              // the pointer, window coordinates (the last message)
    FMouseIn: Boolean;           // ... over the map
    FTip: TSdCodeTip;            // the code around the line under the pointer
    FTipLine: Integer;           // ... its document line (-1: none shown)
    function Sci(Msg: Cardinal; W: Cardinal = 0; L: Integer = 0): Integer;
    function MapRect: TRect;
    procedure ReadView(out V: TSciMapView);
    procedure ReadMarks(out CaretRow, SelA, SelB, SelN: Integer);
    function BoxRect(const V: TSciMapView): TRect;
    function RowAt(const V: TSciMapView; Y: Integer): Integer;
    procedure ScrollTo(const V: TSciMapView; First: Integer);
    procedure MoveBox(const V: TSciMapView; Y: Integer);
    function EnsureDib(W, H: Integer): Boolean;
    procedure FreeDib;
    procedure Fill(X, Y, W, H: Integer; C: Cardinal);
    procedure Render(const V: TSciMapView; W, H: Integer);
    procedure Hover(const P: TPoint; Inside: Boolean);
    procedure Press(const P: TPoint);
    procedure Drag(const P: TPoint);
    procedure EndPress;
    procedure ShowTip(const V: TSciMapView; const P: TPoint);
    procedure SetRoom(Value: Integer);
  protected
    procedure Hook(var Message: TMessage); override;
  public
    constructor Create(AControl: TWinControl); reintroduce;
    destructor Destroy; override;
    { the scrolling, the caret's line, the selections again: painted again when they changed (or
      the text did) }
    procedure Update;
    procedure Paint;
    { the text or the marks changed: painted again once the messages waiting are done }
    procedure Changed;
    { another document in the window: the tip goes, the map is painted again }
    procedure Reset;
    procedure HideTip;
    procedure SetColors(const C: TSciMapColors);
    property Room: Integer read FRoom write SetRoom;
    property SciCall: TSciMapSci read FSciCall write FSciCall;
    property OnStyleTo: TSciMapStyleTo read FOnStyleTo write FOnStyleTo;
    property OnPreview: TSciMapPreview read FOnPreview write FOnPreview;
    { tests: the pointer at the window point X, Y as a WM_NCMOUSEMOVE puts it, without asking for
      WM_NCMOUSELEAVE (it would come at once: the real pointer is elsewhere) }
    procedure TestHover(X, Y: Integer);
    { tests: 'room=n map=l,t,r,b top=first row box=top-bottom hot=0|1 down=0|1 tip=its lines' -
      window coordinates; tip SdHints' DebugText, '' while none is shown }
    function StateText: string;
  end;

{ the room the map takes at Dpi: MapColumns cells and its margins }
function SciMapWidth(Dpi: Integer): Integer;

{ a line's text in columns, for the map and the tip of its lines (TSciEdit.StyledRuns): the styled
  text of Len bytes from Pos into Buf (SCI_GETSTYLEDTEXT - each byte, then its style byte; Buf
  grows as needed); the editor's tab width; the column after the byte Ch at column Col - a tab to
  the next tab stop, a byte that continues a character of UTF-8 (Cont) none, any other one }
procedure SciStyledText(const Sci: TSciMapSci; Pos, Len: Integer; var Buf: string);
function SciTabWidth(const Sci: TSciMapSci): Integer;
function SciColumnAfter(Ch: Char; Col, TabW: Integer; Cont: Boolean): Integer;

implementation

uses
  SysUtils, SdSciDefs, SdSciScroll;

const
  MapColumns = 100;                       // the characters of a row the map shows
  WM_SCIMAPCHANGED = WM_APP + $1A2;       // the text or the marks changed: painted again
  CaretAlpha = 64;                        // of 256: the caret's band over the row's ground
  MapTimerId = $5D53;                     // the drag held past the map: not Scintilla's, the bars' or the editor's
  MapRepeat = 40;                         // ... its ms

{ a character's cell at Dpi: a pixel at 96, more at higher ones (rounded) }
function MapCell(Dpi: Integer): Integer;
begin
  Result := (Dpi + 48) div 96;
  if Result < 1 then Result := 1;
end;

{ two cells of margin at the left, one at the right }
function SciMapWidth(Dpi: Integer): Integer;
begin
  Result := (MapColumns + 3) * MapCell(Dpi);
end;

procedure SciStyledText(const Sci: TSciMapSci; Pos, Len: Integer; var Buf: string);
var
  TR: TSciTextRange;
begin
  if Len <= 0 then Exit;
  if Length(Buf) < 2 * Len + 2 then SetLength(Buf, 2 * Len + 2);
  TR.cpMin := Pos;
  TR.cpMax := Pos + Len;
  TR.Text := PChar(Buf);
  Sci(SCI_GETSTYLEDTEXT, 0, Integer(@TR));
end;

function SciTabWidth(const Sci: TSciMapSci): Integer;
begin
  Result := Sci(SCI_GETTABWIDTH, 0, 0);
  if Result < 1 then Result := 8;
end;

function SciColumnAfter(Ch: Char; Col, TabW: Integer; Cont: Boolean): Integer;
begin
  if Ch = #9 then Result := (Col div TabW + 1) * TabW
  else if Cont then Result := Col
  else Result := Col + 1;
end;

{ a colour as a pixel of a 32-bit DIB section }
function Pixel(C: TColor): Cardinal;
var
  X: COLORREF;
begin
  X := ColorToRGB(C);
  Result := (Cardinal(GetRValue(X)) shl 16) or (Cardinal(GetGValue(X)) shl 8) or Cardinal(GetBValue(X));
end;

{ A over B, A taking P of 256 }
function Mix(A, B: Cardinal; P: Integer): Cardinal;
begin
  Result := ((((A shr 16) and $FF) * Cardinal(P) + ((B shr 16) and $FF) * Cardinal(256 - P)) shr 8) shl 16 or
    ((((A shr 8) and $FF) * Cardinal(P) + ((B shr 8) and $FF) * Cardinal(256 - P)) shr 8) shl 8 or
    (((A and $FF) * Cardinal(P) + (B and $FF) * Cardinal(256 - P)) shr 8);
end;

{ how much of the text's colour the top and the bottom half of a character's cell take (of 256):
  what its glyph covers there; 0 and 0 for a blank }
procedure GlyphShade(Ch: Char; out Top, Bottom: Integer);
const
  Tall = ['A'..'Z', '0'..'9', 'b', 'd', 'f', 'h', 'k', 'l', 't', '#', '$', '%', '&', '@', '!', '?', '|'];
  Small = ['a', 'c', 'e', 'i', 'm', 'n', 'o', 'r', 's', 'u', 'v', 'w', 'x', 'z'];
  Deep = ['g', 'j', 'p', 'q', 'y'];
  Bracket = ['(', ')', '[', ']', '{', '}', '<', '>', '/', '\'];
  Stroke = ['-', '+', '=', '~', '*', '^'];
  Quote = ['''', '"', '`'];
begin
  if Ch <= ' ' then
  begin
    Top := 0;
    Bottom := 0;
  end
  else if Ch in Tall then
  begin
    Top := 150;
    Bottom := 170;
  end
  else if Ch in Small then
  begin
    Top := 60;
    Bottom := 170;
  end
  else if Ch in Deep then
  begin
    Top := 60;
    Bottom := 200;
  end
  else if Ch in Bracket then
  begin
    Top := 120;
    Bottom := 120;
  end
  else if Ch in Stroke then
  begin
    Top := 90;
    Bottom := 90;
  end
  else if Ch in Quote then
  begin
    Top := 120;
    Bottom := 0;
  end
  else if Ch in ['.', ','] then
  begin
    Top := 0;
    Bottom := 110;
  end
  else if Ch in [':', ';'] then
  begin
    Top := 80;
    Bottom := 100;
  end
  else if Ch = '_' then
  begin
    Top := 0;
    Bottom := 120;
  end
  else if Ch >= #128 then
  begin
    Top := 130;
    Bottom := 150;
  end
  else
  begin
    Top := 100;
    Bottom := 100;
  end;
end;

{ ---------------------------------------------------------------- TSciMinimap }

constructor TSciMinimap.Create(AControl: TWinControl);
begin
  inherited Create(AControl, True);
  FTipLine := -1;
  FMapTop := -1;
  FDirty := True;
  FColors.Ground := clBtnFace;
  FColors.View := clBtnShadow;
  FColors.ViewHot := clGrayText;
  FColors.ViewDown := clBtnText;
  FColors.Tip := clWindow;
  FColors.Caret := clBtnShadow;
  FColors.Selection := clHighlight;
  FColors.SelectionText := clHighlightText;
end;

destructor TSciMinimap.Destroy;
begin
  HideTip;
  FreeDib;
  inherited Destroy;
end;

function TSciMinimap.Sci(Msg: Cardinal; W: Cardinal; L: Integer): Integer;
begin
  if Assigned(FSciCall) then Result := FSciCall(Msg, W, L) else Result := 0;
end;

function TSciMinimap.MapRect: TRect;
var
  O, S: TPoint;
begin
  Result := Rect(0, 0, 0, 0);
  if (FTaken <= 0) or not FControl.HandleAllocated then Exit;
  O := SciClientOrigin(FControl.Handle, S);
  Result := Rect(O.X + S.X, O.Y, O.X + S.X + FTaken, O.Y + S.Y);
end;

{ The map's first row stays where it is while the box over the lines in view lies in the map; a box
  that went past the map's top or bottom takes the map with it by as much, a box the map does not
  show at all (a jump, another document) is put into the map's middle. So the rows drawn do not move
  under the pointer when the editor scrolls inside them - a press there brings those rows into view }
procedure TSciMinimap.ReadView(out V: TSciMapView);
var
  H: Integer;
begin
  V.R := MapRect;
  V.Cell := MapCell(GetControlDpi(FControl));
  V.LineH := 2 * V.Cell;
  H := V.R.Bottom - V.R.Top;
  if H < 0 then H := 0;
  V.Fit := H div V.LineH;
  V.Rows := (H + V.LineH - 1) div V.LineH;
  V.First := Sci(SCI_GETFIRSTVISIBLELINE);
  V.Page := Sci(SCI_LINESONSCREEN);
  if V.Page < 1 then V.Page := 1;
  V.Total := Sci(SCI_VISIBLEFROMDOCLINE, Sci(SCI_GETLINECOUNT));
  { as the vertical scroll bar's range: the last line at the bottom, or at the top with Cursor
    beyond EOF }
  if Sci(SCI_GETENDATLASTLINE) <> 0 then V.Last := V.Total - V.Page else V.Last := V.Total - 1;
  if V.Last < 0 then V.Last := 0;
  V.TopMax := V.Total - V.Fit;
  if V.TopMax < 0 then V.TopMax := 0;
  V.Top := FMapTop;
  if (V.Top < 0) or (V.First + V.Page <= V.Top) or (V.First >= V.Top + V.Fit) then
    V.Top := V.First - (V.Fit - V.Page) div 2
  else if V.First + V.Page > V.Top + V.Fit then
    V.Top := V.First + V.Page - V.Fit;
  if V.First < V.Top then V.Top := V.First;           // a box taller than the map: its top shown
  if V.Top > V.TopMax then V.Top := V.TopMax;
  if V.Top < 0 then V.Top := 0;
  FMapTop := V.Top;
end;

{ the caret's row; the selections: a hash of their starts and of their ends (shifts, no arithmetic
  that could overflow), their count }
procedure TSciMinimap.ReadMarks(out CaretRow, SelA, SelB, SelN: Integer);
var
  I: Integer;
begin
  CaretRow := Sci(SCI_VISIBLEFROMDOCLINE, Sci(SCI_LINEFROMPOSITION, Sci(SCI_GETCURRENTPOS)));
  SelN := Sci(SCI_GETSELECTIONS);
  SelA := 0;
  SelB := 0;
  for I := 0 to SelN - 1 do
  begin
    SelA := (SelA shl 5) xor Sci(SCI_GETSELECTIONNSTART, I);
    SelB := (SelB shl 5) xor Sci(SCI_GETSELECTIONNEND, I);
  end;
end;

{ the box over the lines in view, window coordinates (inside the map) }
function TSciMinimap.BoxRect(const V: TSciMapView): TRect;
var
  Y: Integer;
begin
  Y := V.R.Top + (V.First - V.Top) * V.LineH;
  Result := Rect(V.R.Left, Y, V.R.Right, Y + V.Page * V.LineH);
  if Result.Top < V.R.Top then Result.Top := V.R.Top;
  if Result.Bottom > V.R.Bottom then Result.Bottom := V.R.Bottom;
  if Result.Bottom < Result.Top then Result.Bottom := Result.Top;
end;

function TSciMinimap.RowAt(const V: TSciMapView; Y: Integer): Integer;
begin
  if Y < V.R.Top then Y := V.R.Top;
  Result := V.Top + (Y - V.R.Top) div V.LineH;
end;

procedure TSciMinimap.ScrollTo(const V: TSciMapView; First: Integer);
begin
  if First > V.Last then First := V.Last;
  if First < 0 then First := 0;
  if First <> V.First then Sci(SCI_SETFIRSTVISIBLELINE, First);
end;

function TSciMinimap.EnsureDib(W, H: Integer): Boolean;
begin
  if (FDib = 0) or (W <> FDibW) or (H <> FDibH) then
  begin
    FreeDib;
    FDib := UICreateDib32(W, H, FBits);
    if FDib <> 0 then
    begin
      FDC := CreateCompatibleDC(0);
      FOldDib := SelectObject(FDC, FDib);
      FDibW := W;
      FDibH := H;
    end;
  end;
  Result := (FDib <> 0) and (FBits <> nil);
end;

procedure TSciMinimap.FreeDib;
begin
  if FDC <> 0 then
  begin
    SelectObject(FDC, FOldDib);
    DeleteDC(FDC);
    FDC := 0;
  end;
  if FDib <> 0 then DeleteObject(FDib);
  FDib := 0;
  FBits := nil;
  FDibW := 0;
  FDibH := 0;
end;

{ a rectangle of the picture in C, cut to it }
procedure TSciMinimap.Fill(X, Y, W, H: Integer; C: Cardinal);
var
  P: PCardinal;
  I, J: Integer;
begin
  if X < 0 then
  begin
    Inc(W, X);
    X := 0;
  end;
  if Y < 0 then
  begin
    Inc(H, Y);
    Y := 0;
  end;
  if X + W > FDibW then W := FDibW - X;
  if Y + H > FDibH then H := FDibH - Y;
  if (W <= 0) or (H <= 0) then Exit;
  for J := Y to Y + H - 1 do
  begin
    P := FBits;
    Inc(P, J * FDibW + X);
    for I := 1 to W do
    begin
      P^ := C;
      Inc(P);
    end;
  end;
end;

{ The picture of the rows V.Top .. on, W x H. Each row: its ground (the box's, the caret's band),
  the selections' and the tints' columns on it, then its characters - a row reads at most the bytes
  its columns can take, so a very long line costs no more than a short one. A wrapped line's rows
  show its bytes in equal parts }
procedure TSciMinimap.Render(const V: TSciMapView; W, H: Integer);
var
  Ground, View, Caret, Sel, SelText, Base, Fore: Cardinal;
  Fores: array[Byte] of Cardinal;
  Known: array[Byte] of Boolean;
  Tints: array of Cardinal;
  Row, Last, Y, D, S, E, N, Sub, Chunk, Len, K, Col, Cols, PadL, TabW, CaretRow, I, A, B, P, Q,
    Top, Bottom, St, X, NSel, SelA, SelB: Integer;
  LineEnd, Utf8, Wrap: Boolean;
  Ch: Char;

  { the columns of the bytes A .. B of the document on this row in C (Selected: a selection's);
    past the line's end too when the range goes on beyond it (PastEnd) }
  procedure Tint(A, B: Integer; C: Cardinal; PastEnd, Selected: Boolean);
  var
    I, C0, C1: Integer;
  begin
    if A < S then A := S;
    if B > S + Len then B := S + Len;
    if A > B then Exit;
    C0 := FColOf[A - S];
    C1 := FColOf[B - S];
    if PastEnd then C1 := Cols;
    if C1 > Cols then C1 := Cols;
    for I := C0 to C1 - 1 do
    begin
      FGrounds[I] := C;
      FSelected[I] := Selected;
    end;
  end;

begin
  if not EnsureDib(W, H) then Exit;
  GdiFlush;
  Ground := Pixel(FColors.Ground);
  if FDown then View := Pixel(FColors.ViewDown)
  else if FHot then View := Pixel(FColors.ViewHot)
  else View := Pixel(FColors.View);
  Caret := Pixel(FColors.Caret);
  Sel := Pixel(FColors.Selection);
  SelText := Pixel(FColors.SelectionText);
  SetLength(Tints, Length(FColors.Tints));
  for I := 0 to High(Tints) do Tints[I] := Pixel(FColors.Tints[I].Color);
  Fill(0, 0, W, H, Ground);
  ReadMarks(CaretRow, SelA, SelB, NSel);
  PadL := 2 * V.Cell;
  Cols := (W - 3 * V.Cell) div V.Cell;
  if Cols > MapColumns then Cols := MapColumns;
  Last := V.Top + V.Rows;
  if Last > V.Total then Last := V.Total;
  if (Cols > 0) and (Last > V.Top) then
  begin
    { the lexer has styled the lines in view only }
    if Assigned(FOnStyleTo) then
      FOnStyleTo(Sci(SCI_GETLINEENDPOSITION, Sci(SCI_DOCLINEFROMVISIBLE, Last - 1)));
    Utf8 := Sci(SCI_GETCODEPAGE) = SC_CP_UTF8;
    Wrap := Sci(SCI_GETWRAPMODE) <> SC_WRAP_NONE;
    TabW := SciTabWidth(FSciCall);
    FillChar(Known, SizeOf(Known), 0);
    SetLength(FGrounds, Cols);
    SetLength(FSelected, Cols);
    for Row := V.Top to Last - 1 do
    begin
      Y := (Row - V.Top) * V.LineH;
      D := Sci(SCI_DOCLINEFROMVISIBLE, Row);
      S := Sci(SCI_POSITIONFROMLINE, D);
      E := Sci(SCI_GETLINEENDPOSITION, D);
      LineEnd := True;
      if Wrap then
      begin
        N := Sci(SCI_WRAPCOUNT, D);
        if N > 1 then
        begin
          Sub := Row - Sci(SCI_VISIBLEFROMDOCLINE, D);
          Chunk := (E - S + N - 1) div N;
          Inc(S, Sub * Chunk);
          if S > E then S := E;
          if Sub < N - 1 then
          begin
            if S + Chunk < E then E := S + Chunk;
            LineEnd := False;
          end;
        end;
      end;
      { the row's ground }
      if (Row >= V.First) and (Row < V.First + V.Page) then Base := View else Base := Ground;
      if Row = CaretRow then Base := Mix(Caret, Base, CaretAlpha);
      Fill(0, Y, W, V.LineH, Base);
      for I := 0 to Cols - 1 do
      begin
        FGrounds[I] := Base;
        FSelected[I] := False;
      end;
      { its bytes: as many as its columns can take (a tab takes several columns, a character of
        UTF-8 several bytes) }
      Len := E - S;
      if Len > 4 * Cols then Len := 4 * Cols;
      if Length(FColOf) < Len + 1 then SetLength(FColOf, Len + 1);
      SciStyledText(FSciCall, S, Len, FBuf);
      Col := 0;
      for K := 0 to Len - 1 do
      begin
        FColOf[K] := Col;
        Ch := FBuf[2 * K + 1];
        Col := SciColumnAfter(Ch, Col, TabW, Utf8 and (Byte(Ch) and $C0 = $80));
      end;
      FColOf[Len] := Col;
      { the selections; the tints' ranges }
      for I := 0 to NSel - 1 do
      begin
        A := Sci(SCI_GETSELECTIONNSTART, I);
        B := Sci(SCI_GETSELECTIONNEND, I);
        if (A < B) and (A <= E) and (B >= S) then
          Tint(A, B, Sel, LineEnd and (B > E) and (Len = E - S), True);
      end;
      for I := 0 to High(Tints) do
      begin
        P := S;
        while P < S + Len do
        begin
          Q := Sci(SCI_INDICATOREND, FColors.Tints[I].Indicator, P);
          if Q <= P then Break;
          if Sci(SCI_INDICATORVALUEAT, FColors.Tints[I].Indicator, P) <> 0 then Tint(P, Q, Tints[I], False, False);
          P := Q;
        end;
      end;
      for I := 0 to Cols - 1 do
        if FGrounds[I] <> Base then Fill(PadL + I * V.Cell, Y, V.Cell, V.LineH, FGrounds[I]);
      { the characters }
      for K := 0 to Len - 1 do
      begin
        Col := FColOf[K];
        if Col >= Cols then Break;
        Ch := FBuf[2 * K + 1];
        if (Ch <= ' ') or (Utf8 and (Byte(Ch) and $C0 = $80)) then Continue;
        GlyphShade(Ch, Top, Bottom);
        St := Byte(FBuf[2 * K + 2]);
        if not Known[St] then
        begin
          Fores[St] := Pixel(TColor(Sci(SCI_STYLEGETFORE, St)));
          Known[St] := True;
        end;
        if FSelected[Col] then Fore := SelText else Fore := Fores[St];
        X := PadL + Col * V.Cell;
        if Top > 0 then Fill(X, Y, V.Cell, V.Cell, Mix(Fore, FGrounds[Col], Top));
        if Bottom > 0 then Fill(X, Y + V.Cell, V.Cell, V.Cell, Mix(Fore, FGrounds[Col], Bottom));
      end;
    end;
  end;
  FFirst := V.First;
  FPage := V.Page;
  FTotal := V.Total;
  FTop := V.Top;
  FCaret := CaretRow;
  FSelA := SelA;
  FSelB := SelB;
  FSelN := NSel;
  FSize := Point(W, H);
  FDirty := False;
end;

procedure TSciMinimap.Paint;
var
  V: TSciMapView;
  DC: HDC;
  W, H: Integer;
begin
  if (FRoom <= 0) or not Assigned(FSciCall) or not FControl.HandleAllocated or
    not IsWindowVisible(FControl.Handle) then Exit;
  ReadView(V);
  W := V.R.Right - V.R.Left;
  H := V.R.Bottom - V.R.Top;
  if (W <= 0) or (H <= 0) then Exit;
  Render(V, W, H);
  if FDC = 0 then Exit;
  DC := GetWindowDC(FControl.Handle);
  try
    BitBlt(DC, V.R.Left, V.R.Top, W, H, FDC, 0, 0, SRCCOPY);
  finally
    ReleaseDC(FControl.Handle, DC);
  end;
end;

procedure TSciMinimap.Update;
var
  V: TSciMapView;
  CaretRow, SelA, SelB, SelN: Integer;
  Moved: Boolean;
begin
  if (FRoom <= 0) or not FControl.HandleAllocated or not IsWindowVisible(FControl.Handle) then Exit;
  ReadView(V);
  ReadMarks(CaretRow, SelA, SelB, SelN);
  Moved := (V.First <> FFirst) or (V.Top <> FTop);
  if FDirty or Moved or (V.Page <> FPage) or (V.Total <> FTotal) or (CaretRow <> FCaret) or (SelA <> FSelA) or
    (SelB <> FSelB) or (SelN <> FSelN) or (V.R.Right - V.R.Left <> FSize.X) or (V.R.Bottom - V.R.Top <> FSize.Y) then
  begin
    Paint;
    { the text under the pointer moved: the tip shows what is there now }
    if Moved and FMouseIn and not FDown and (FTipLine >= 0) then Hover(FMouse, True);
  end;
end;

procedure TSciMinimap.Changed;
begin
  FDirty := True;
  if not FPosted and (FRoom > 0) and FControl.HandleAllocated then
  begin
    FPosted := True;
    PostMessage(FControl.Handle, WM_SCIMAPCHANGED, 0, 0);
  end;
end;

procedure TSciMinimap.Reset;
begin
  HideTip;
  FHot := False;
  FMapTop := -1;                      // the new document's box into the map's middle
  Changed;
end;

procedure TSciMinimap.SetColors(const C: TSciMapColors);
begin
  FColors := C;
  Changed;
end;

procedure TSciMinimap.SetRoom(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value = FRoom then Exit;
  FRoom := Value;
  HideTip;
  FHot := False;
  FDirty := True;
  { the client area changes: the frame is made again (WM_NCCALCSIZE) and painted }
  if FControl.HandleAllocated then
    SetWindowPos(FControl.Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE or SWP_FRAMECHANGED);
end;

procedure TSciMinimap.HideTip;
begin
  FTipLine := -1;
  if (FTip <> nil) and FTip.TipShown then FTip.HideTip;
end;

procedure TSciMinimap.TestHover(X, Y: Integer);
var
  P: TPoint;
begin
  P := Point(X, Y);
  Hover(P, PtInRect(MapRect, P));
end;

function TSciMinimap.StateText: string;
var
  V: TSciMapView;
  B: TRect;
  Tip: string;
begin
  ReadView(V);
  B := BoxRect(V);
  if FTip <> nil then Tip := FTip.DebugText else Tip := '';
  Result := Format('room=%d map=%d,%d,%d,%d top=%d box=%d-%d hot=%d down=%d tip=%s', [FRoom, V.R.Left, V.R.Top,
    V.R.Right, V.R.Bottom, V.Top, B.Top, B.Bottom, Ord(FHot), Ord(FDown), Tip]);
end;

{ the code around the line under the pointer, beside the map at its row; a new line under it, a new
  tip }
procedure TSciMinimap.ShowTip(const V: TSciMapView; const P: TPoint);
var
  Row, Line, Y: Integer;
  Lines: TTipLines;
  WR, A: TRect;
begin
  Row := RowAt(V, P.Y);
  if (Row >= V.Total) or not Assigned(FOnPreview) then
  begin
    HideTip;
    Exit;
  end;
  Line := Sci(SCI_DOCLINEFROMVISIBLE, Row);
  if (Line = FTipLine) and (FTip <> nil) and FTip.TipShown then Exit;
  Lines := nil;
  FOnPreview(Line, Lines);
  if Lines = nil then
  begin
    HideTip;
    Exit;
  end;
  if FTip = nil then FTip := TSdCodeTip.Create(Self);
  FTip.Color := FColors.Tip;
  GetWindowRect(FControl.Handle, WR);
  Y := V.R.Top + (Row - V.Top) * V.LineH;
  A := Rect(WR.Left + V.R.Left, WR.Top + Y, WR.Left + V.R.Right, WR.Top + Y + V.LineH);
  FTip.ShowLinesBeside(Lines, A, Self);
  FTipLine := Line;
end;

procedure TSciMinimap.Hover(const P: TPoint; Inside: Boolean);
var
  V: TSciMapView;
  Hot: Boolean;
begin
  FMouse := P;
  FMouseIn := Inside;
  if FDown then Exit;
  Hot := False;
  if Inside then
  begin
    ReadView(V);
    Hot := PtInRect(BoxRect(V), P);
    ShowTip(V, P);
  end
  else
    HideTip;
  if Hot <> FHot then
  begin
    FHot := Hot;
    Paint;
  end;
end;

{ the editor scrolled so that the box's top lies at Y - FGrab (window coordinates) on the rows the
  map draws now, line for line, the box inside the map while the pointer is; past the map's top or
  bottom the box goes on beyond it - as many rows as the pointer is past it, at least one - and
  takes the map with it (ReadView) }
procedure TSciMinimap.MoveBox(const V: TSciMapView; Y: Integer);
var
  D, T: Integer;
begin
  D := Y - FGrab - V.R.Top;
  if D < 0 then D := D - V.LineH + 1;                  // rounded down above the map too
  T := D div V.LineH;
  if T > V.Fit - V.Page then T := V.Fit - V.Page;
  if T < 0 then T := 0;
  if Y < V.R.Top then Dec(T, (V.R.Top - Y) div V.LineH + 1)
  else if Y >= V.R.Bottom then Inc(T, (Y - V.R.Bottom) div V.LineH + 1);
  ScrollTo(V, V.Top + T);
end;

{ a press anywhere - on the box too - brings the line drawn under the pointer into the middle of
  the view: the box then lies around that line, under the pointer (the map moves only when the box
  would go past its top or bottom); then the box is dragged from there }
procedure TSciMinimap.Press(const P: TPoint);
var
  V: TSciMapView;
begin
  HideTip;
  ReadView(V);
  ScrollTo(V, RowAt(V, P.Y) - V.Page div 2);
  ReadView(V);
  FGrab := P.Y - (V.R.Top + (V.First - V.Top) * V.LineH);
  FMouse := P;
  FDown := True;
  SetCapture(FControl.Handle);
  Paint;
end;

{ the box follows the pointer; held past the map's top or bottom, the view scrolls on by itself
  (MapTimerId: the drag again every MapRepeat ms, as far as the pointer is past the edge) }
procedure TSciMinimap.Drag(const P: TPoint);
var
  V: TSciMapView;
begin
  FMouse := P;
  ReadView(V);
  MoveBox(V, P.Y);
  if (P.Y < V.R.Top) or (P.Y >= V.R.Bottom) then SetTimer(FControl.Handle, MapTimerId, MapRepeat, nil)
  else KillTimer(FControl.Handle, MapTimerId);
  Update;
end;

procedure TSciMinimap.EndPress;
begin
  if not FDown then Exit;
  FDown := False;
  FHot := False;
  if FControl.HandleAllocated then KillTimer(FControl.Handle, MapTimerId);
  Paint;
end;

procedure TSciMinimap.Hook(var Message: TMessage);
var
  R: PRect;
  P: TPoint;
begin
  case Message.Msg of
    { its room from what the client area has left (the scroll bars took theirs): a window too narrow
      for it gets a narrower map, never one over the vertical bar }
    WM_NCCALCSIZE:
      begin
        FOldProc(Message);
        R := SciNcCalcRect(Message);
        FTaken := FRoom;
        if FTaken > R^.Right - R^.Left then FTaken := R^.Right - R^.Left;
        if FTaken < 0 then FTaken := 0;
        R^.Right := R^.Right - FTaken;
        Exit;
      end;
    WM_NCPAINT:
      begin
        FOldProc(Message);
        Paint;
        Exit;
      end;
    { a new size: painted again once the batch of moves it may be part of is done (as the scroll
      bars are) }
    WM_SIZE:
      begin
        FOldProc(Message);
        Changed;
        Exit;
      end;
    WM_SCIMAPCHANGED:
      begin
        FPosted := False;
        if FDirty then Paint;
        Exit;
      end;
    WM_TIMER:
      if Message.WParam = MapTimerId then
      begin
        if FDown then Drag(FMouse) else KillTimer(FControl.Handle, MapTimerId);
        Exit;
      end;
    WM_NCHITTEST:
      begin
        FOldProc(Message);
        if PtInRect(MapRect, SciWindowPoint(FControl.Handle, Message.LParam)) then Message.Result := HTBORDER;
        Exit;
      end;
    WM_NCLBUTTONDOWN, WM_NCLBUTTONDBLCLK:
      if Message.WParam = HTBORDER then
      begin
        P := SciWindowPoint(FControl.Handle, Message.LParam);
        if PtInRect(MapRect, P) then
        begin
          Press(P);
          Message.Result := 0;
          Exit;
        end;
      end;
    WM_NCMOUSEMOVE:
      begin
        P := SciWindowPoint(FControl.Handle, Message.LParam);
        Hover(P, PtInRect(MapRect, P));
        if FMouseIn and not FTracking then FTracking := SciTrackNcLeave(FControl.Handle);
      end;
    WM_NCMOUSELEAVE:
      begin
        FTracking := False;
        Hover(Point(0, 0), False);
      end;
    WM_MOUSEMOVE:
      if FDown then
      begin
        Drag(SciClientPoint(FControl.Handle, Message.LParam));
        Exit;
      end;
    WM_LBUTTONUP:
      if FDown then
      begin
        ReleaseCapture;               // WM_CAPTURECHANGED ends the press
        EndPress;
        Exit;
      end;
    WM_CAPTURECHANGED:
      EndPress;
    WM_KEYDOWN, WM_SYSKEYDOWN:
      HideTip;
    WM_WINDOWPOSCHANGED:
      if PWindowPos(Message.LParam)^.flags and SWP_HIDEWINDOW <> 0 then HideTip;
    WM_CONTEXTMENU:
      { the map has no menu (the editor's would open there) }
      if (Message.LParam <> -1) and PtInRect(MapRect, SciWindowPoint(FControl.Handle, Message.LParam)) then Exit;
    WM_DESTROY:
      HideTip;
  end;
  FOldProc(Message);
end;

end.
