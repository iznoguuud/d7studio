{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRichView;

{ D7 Studio - a rich text document (SdRichDoc) laid out and shown: its text wrapped in the width of
  the view in the view's font (headings larger, bold), code in the code editor's font and its
  colours (SdSciEdit.HighlightCode: the language's lexer, the editor's theme), quotes with a bar,
  lists with bullets, numbers or task boxes, tables with their columns fitted to the width, rules,
  pictures of the files beside the document (BaseFolder; PNG, JPEG, GIF, BMP, ICO through GDI+).
  The text can be selected with the mouse and copied (Ctrl+C, WM_COPY); a link is followed by a
  click - one to a heading of the document ('#name') by the view itself, any other by OnLink - and
  shows its target as its hint. It zooms (ISdZoomView) and scrolls by a pixel origin; painted in
  one pass into a buffer, never erased.

  The layout is made when it is needed (painting, scrolling, a place asked for) and again only for
  another width or zoom; its width leaves room for the vertical scroll bar whether it shows or not,
  so that the bar coming or going lays nothing out again. Text is measured by the widths of its
  characters, kept per font (each 256 characters read from GDI once); a piece with characters the
  font has no glyph of, of a script that is shaped, or of two UTF-16 units is measured by GDI. The
  pieces of the layout point into one text, the document's in reading order, which a selection
  copies. Code blocks are coloured once per document. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, SdUI, SdZoom, SdRichDoc;

type
  TSdRichLinkEvent = procedure(Sender: TObject; const Target: WideString) of object;

  TRichFrag = record
    X, W, H: Integer;          // H: a picture's height
    Line: Integer;             // the line it is on
    Offset, Len: Integer;      // its text in FText (0-based start)
    Font: Integer;             // its font's key (FontKey)
    Color: TColor;
    Back: TColor;              // clNone: none (inline code: its box)
    Link: Integer;             // the document's link (-1: none)
    Image: Integer;            // the picture it shows (FImages; -1: text)
  end;

  TRichLine = record
    Top, Height, Base: Integer; // Base: the baseline below Top
    X: Integer;                // where it begins (an empty line too)
    Offset: Integer;           // its first character in FText
    First, Count: Integer;     // its pieces
    Block: TSdBlock;           // the block whose text it shows (nil: none)
    SubLine: Integer;          // ... its line of code (code), else 0
  end;

  TRichDecoKind = (dkFill, dkFrame, dkDisc, dkCircle, dkSquare, dkCheck, dkText);
  TRichDeco = record
    Kind: TRichDecoKind;
    R: TRect;
    Color: TColor;
    Checked: Boolean;          // dkCheck
    Text: WideString;          // dkText: at R.Left, its baseline R.Top
    Font: Integer;
  end;

  PRichWidths = ^TRichWidths;
  TRichWidths = array[0..255] of Integer;       // -1: the font has no glyph of it
  TRichWidthPages = array[0..255] of PRichWidths;

  TSdRichView = class(TSdScrollControl, ISdZoomView)
  private
    FDoc: TSdRichDoc;
    FBaseFolder: string;
    FZoom: Integer;
    FDirty: Boolean;           // the layout is to be made (LayoutNeeded)
    FFrags: array of TRichFrag;
    FFragCount: Integer;
    FLines: array of TRichLine;
    FLineCount: Integer;
    FDecos: array of TRichDeco;
    FDecoCount: Integer;
    FAnchorBlocks: TList;      // the headings laid out ...
    FAnchorTops: array of Integer;   // ... and their tops
    FText: WideString;         // the text in reading order: what the pieces show, what a selection copies
    FTextLen: Integer;
    FSize: TPoint;
    FMaxRight: Integer;
    FLayoutWidth: Integer;
    FEm: Integer;              // the height of a line of the body's font
    FFontKeys: array of Integer;
    FFontHandles: array of HFONT;
    FFontAscent, FFontHeight: array of Integer;
    FFontWidths: array of TRichWidthPages;
    FMeasureDC: HDC;
    FMeasureFont: Integer;     // the font selected into FMeasureDC (-1: none)
    FImages: TStringList;      // the pictures loaded: their file names, a TRichImage each; never sorted
                               // nor shortened while the view lives (the pieces keep their indexes)
    FCode: TList;              // the code blocks coloured (TRichCode), for the document shown
    FSelA, FSelB: Integer;     // the selection's anchor and its moving end (offsets in FText)
    FSelecting: Boolean;
    FDownLink: Integer;
    FHotLink: Integer;
    FWheelZoom: Integer;
    FPaintBuf: TBitmap;
    FOnLink: TSdRichLinkEvent;
    { the line being laid out }
    FCurX, FInkX, FLineX, FLineW, FLineFirst: Integer;
    FLineOffset: Integer;
    FLineAlign: TAlignment;
    FLineLeading: Integer;
    FLineOpen: Boolean;
    FLineBlock: TSdBlock;      // the block of the lines laid out now, and the line of its code
    FLineSub: Integer;
    FContextPoint: TPoint;     // where the context menu was asked for (client), when by the mouse
    FContextByMouse: Boolean;
    function BodyPixels: Integer;
    function FontKey(Code: Boolean; Size: Integer; Bold, Italic, Strike, Underline: Boolean): Integer;
    function FontIndex(Key: Integer): Integer;
    function FontHandle(Key: Integer): HFONT;
    procedure FreeFonts;
    procedure FreeImages;
    procedure FreeCode;
    function MeasureDC: HDC;
    function SelectMeasureFont(Index: Integer): HDC;
    function WidthOf(P: PWideChar; Len, Key: Integer): Integer;
    function TextWidth(const T: WideString; Key: Integer): Integer;
    procedure AppendText(P: PWideChar; Len: Integer);
    procedure AppendBreak;
    function AddDeco(Kind: TRichDecoKind; const R: TRect; Color: TColor): Integer;
    procedure BeginLine(X, W: Integer; Align: TAlignment; Leading: Integer);
    procedure AddFrag(P: PWideChar; Len, Key: Integer; Color, Back: TColor; Link, Image, W, H: Integer);
    procedure EndLine(var Y: Integer);
    procedure NewLine(var Y: Integer);
    procedure LayoutRuns(const Runs: TSdRuns; X, W: Integer; var Y: Integer; Size: Integer; Bold: Boolean;
      Color: TColor; Align: TAlignment);
    function CodeOf(B: TSdBlock): TObject;
    procedure LayoutCode(B: TSdBlock; X, W: Integer; var Y: Integer);
    procedure LayoutList(L: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer);
    procedure LayoutTable(T: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor);
    procedure LayoutBlock(B: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer);
    procedure LayoutChildren(B: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer;
      Tight: Boolean);
    function RunsWidth(const Runs: TSdRuns; Bold: Boolean; Longest: Boolean): Integer;
    function WantedWidth: Integer;
    procedure Layout;
    procedure LayoutNeeded;
    function ImageOf(const Source: WideString): TObject;
    procedure ImageSize(Img: TObject; MaxW: Integer; out W, H: Integer);
    procedure DrawImage(DC: HDC; Img: TObject; X, Y, W, H: Integer);
    function FragRect(I: Integer): TRect;
    function FragAt(const P: TPoint): Integer;
    function NearestLine(const P: TPoint): Integer;
    function OffsetAt(const P: TPoint): Integer;
    function ContextContent: TPoint;
    function OffsetInFrag(I, PX: Integer): Integer;
    function LineOfOffset(Offset: Integer): Integer;
    function ContentPoint(X, Y: Integer): TPoint;
    procedure SetZoom(Value: Integer; const Anchor: TPoint);
    procedure SetHotLink(Value: Integer);
    procedure FollowLink(Link: Integer);
    procedure SelectWordAt(Offset: Integer);
    procedure PaintFrag(DC: HDC; I: Integer; SelStart, SelEnd: Integer);
    procedure PaintDeco(DC: HDC; const D: TRichDeco);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMCopy(var Message: TMessage); message WM_COPY;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CMHintShow(var Message: TCMHintShow); message CM_HINTSHOW;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure WMContextMenu(var Message: TWMContextMenu); message WM_CONTEXTMENU;
  protected
    function ContentSize: TPoint; override;
    function LineSize: Integer; override;
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the document shown, which the view owns from now on (nil: none); KeepPlace: the place in it
      stays (the same document again, changed), else its top is shown }
    procedure SetDocument(ADoc: TSdRichDoc; KeepPlace: Boolean);
    { the heading Name (a link's '#name', without the '#') at the top; False: no such heading }
    function GotoAnchor(const Name: WideString): Boolean;
    { the settings of the code editor changed (its font, its colours): the code is laid out again }
    procedure OptionsChanged;
    procedure SelectAll;
    procedure CopySelection;
    { W on the clipboard as text }
    procedure CopyText(const W: WideString);
    { a link's target followed as a click on it follows it: '#name' here, any other through OnLink }
    procedure FollowTarget(const Target: WideString);
    { the context menu's place (where the mouse asked for it, else the top of the view): the target of
      the link there ('' none), the line of the document's source its text comes from (-1 none) }
    function ContextLink: WideString;
    function ContextLine: Integer;
    function SelectedText: WideString;
    function HasSelection: Boolean;
    { ISdZoomView }
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
    { test mode: the zoom, the lines, the size, the selection and the links laid out }
    function StateText: string;
    property Document: TSdRichDoc read FDoc;
    { the folder the document's relative pictures are found from (with or without its backslash) }
    property BaseFolder: string read FBaseFolder write FBaseFolder;
    property OnLink: TSdRichLinkEvent read FOnLink write FOnLink;
    property PopupMenu;
  end;

{ a link's or a picture's target Ref as a file below BaseFolder: its %-escapes decoded, '/' as
  '\', relative to BaseFolder unless it is a full name ('file:' names too); Fragment the part after
  its '#'. '' for an address of the web (any scheme but file:) and for one to the document itself }
function RichLocalPath(const BaseFolder: string; const Ref: WideString; out Fragment: WideString): string;

implementation

uses
  Math, Themes, SdEncoding, SdFileNames, SdEditorOptions, SdEditorThemes, SdSciEdit, SdHints, SdResImage;

const
  MinZoom = 25;
  MaxZoom = 400;
  { the sizes of the fonts, per mille of the body's: the body, then the headings 1 .. 6 }
  SizeMille: array[0..6] of Integer = (1000, 2000, 1500, 1250, 1000, 875, 850);
  { code beside the body's text, per cent of its size }
  CodePercent = 90;
  GGI_MARK_NONEXISTING_GLYPHS = 1;
  Blank: WideChar = ' ';
  LineEnd: array[0..1] of WideChar = (#13, #10);

function GetGlyphIndicesW(DC: HDC; Str: PWideChar; Count: Integer; Indices: PWord; Flags: DWORD): DWORD;
  stdcall; external gdi32 name 'GetGlyphIndicesW';

type
  { a picture of the document: its file, loaded once (again when the file changed), and the bitmap
    it was last drawn from at its size }
  TRichImage = class
  public
    Path: string;
    Age: Integer;
    Img: TSdImage;
    Bmp: HBITMAP;
    BmpW, BmpH: Integer;
    destructor Destroy; override;
  end;

  { a code block's lines as the code editor colours them }
  TRichCodeRun = record
    Text: WideString;
    Color: TColor;
    Style: TFontStyles;
  end;
  TRichCodeLine = array of TRichCodeRun;

  TRichCode = class
  public
    Block: TSdBlock;
    Lines: array of TRichCodeLine;
  end;

destructor TRichImage.Destroy;
begin
  if Bmp <> 0 then DeleteObject(Bmp);
  Img.Free;
  inherited Destroy;
end;

function RichLocalPath(const BaseFolder: string; const Ref: WideString; out Fragment: WideString): string;
var
  R: WideString;
  P, I: Integer;
  Scheme: Boolean;
  Base: string;
begin
  Result := '';
  Fragment := '';
  R := Ref;
  P := Pos('#', R);
  if P > 0 then
  begin
    Fragment := UrlDecodeW(Copy(R, P + 1, MaxInt));
    R := Copy(R, 1, P - 1);
  end;
  P := Pos('?', R);
  if P > 0 then R := Copy(R, 1, P - 1);
  if R = '' then Exit;
  if WideLowerCase(Copy(R, 1, 5)) = 'file:' then
  begin
    Delete(R, 1, 5);
    while (R <> '') and (R[1] = '/') do Delete(R, 1, 1);
    { file://server/share: a UNC name; file:///C:/x a drive's }
    if (Length(R) < 2) or (R[2] <> ':') then R := '//' + R;
  end
  else
  begin
    { a scheme: letters and +.- before a ':' (a drive letter alone is none) }
    P := Pos(':', R);
    Scheme := P > 2;
    for I := 1 to P - 1 do
      if not (((R[I] >= 'a') and (R[I] <= 'z')) or ((R[I] >= 'A') and (R[I] <= 'Z')) or
        ((I > 1) and ((R[I] = '+') or (R[I] = '.') or (R[I] = '-') or ((R[I] >= '0') and (R[I] <= '9'))))) then
        Scheme := False;
    if Scheme then Exit;
  end;
  R := UrlDecodeW(R);
  for I := 1 to Length(R) do
    if R[I] = '/' then R[I] := '\';
  if not ((Length(R) >= 2) and (R[2] = ':')) and (Copy(R, 1, 2) <> '\\') then
  begin
    while (R <> '') and (R[1] = '\') do Delete(R, 1, 1);
    Base := BaseFolder;
    if (Base <> '') and (Base[Length(Base)] <> '\') then Base := Base + '\';
    Result := ExpandPathU(Base + WideToIde(R));
  end
  else
    Result := ExpandPathU(WideToIde(R));
end;

{ a character GDI shapes or that is half of a pair: such text is measured by GDI }
function IsShapedChar(C: WideChar): Boolean;
begin
  case Ord(C) of
    $0300..$036F,                  // combining diacritical marks
    $0590..$08FF,                  // Hebrew, Arabic, Syriac, Thaana, N'Ko ...
    $0900..$0DFF,                  // the Indic scripts
    $0E00..$0FFF,                  // Thai, Lao, Tibetan
    $1000..$109F, $1780..$18AF,    // Myanmar, Khmer, Mongolian
    $200B..$200F, $202A..$202E,    // zero widths, directions
    $D800..$DFFF,                  // surrogates
    $FB1D..$FDFF, $FE70..$FEFF:    // presentation forms
      Result := True;
  else
    Result := False;
  end;
end;

{ ---------------------------------------------------------------- TSdRichView }

constructor TSdRichView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption] + [csOpaque];
  TabStop := True;
  ShowHint := True;
  Cursor := crIBeam;
  FZoom := 100;
  FDownLink := -1;
  FHotLink := -1;
  FMeasureFont := -1;
  FAnchorBlocks := TList.Create;
  FImages := TStringList.Create;
  FCode := TList.Create;
end;

destructor TSdRichView.Destroy;
begin
  FreeFonts;
  FreeImages;
  FreeCode;
  FCode.Free;
  FImages.Free;
  FAnchorBlocks.Free;
  if FMeasureDC <> 0 then DeleteDC(FMeasureDC);
  FreeAndNil(FPaintBuf);
  FreeAndNil(FDoc);
  inherited Destroy;
end;

procedure TSdRichView.FreeImages;
var
  I: Integer;
begin
  for I := 0 to FImages.Count - 1 do FImages.Objects[I].Free;
  FImages.Clear;
end;

procedure TSdRichView.FreeCode;
var
  I: Integer;
begin
  for I := 0 to FCode.Count - 1 do TRichCode(FCode[I]).Free;
  FCode.Clear;
end;

function TSdRichView.MeasureDC: HDC;
begin
  if FMeasureDC = 0 then FMeasureDC := CreateCompatibleDC(0);
  Result := FMeasureDC;
end;

{ the measuring DC with the font of index Index in it (selected once while it stays the one) }
function TSdRichView.SelectMeasureFont(Index: Integer): HDC;
begin
  Result := MeasureDC;
  if FMeasureFont <> Index then
  begin
    SelectObject(Result, FFontHandles[Index]);
    FMeasureFont := Index;
  end;
end;

{ --- fonts --- }

{ the body's font height in pixels at 100 % (the view's font: the monitor's DPI is in it) }
function TSdRichView.BodyPixels: Integer;
begin
  Result := Abs(Font.Height);
  if Result = 0 then Result := MulDiv(9, Font.PixelsPerInch, 72);
end;

function TSdRichView.FontKey(Code: Boolean; Size: Integer; Bold, Italic, Strike, Underline: Boolean): Integer;
begin
  Result := Ord(Code) or (Size shl 1) or (Ord(Bold) shl 4) or (Ord(Italic) shl 5) or (Ord(Strike) shl 6) or
    (Ord(Underline) shl 7);
end;

function TSdRichView.FontIndex(Key: Integer): Integer;
var
  LF: TLogFont;
  Px, I: Integer;
  TM: TTextMetric;
  Face: string;
begin
  for I := 0 to High(FFontKeys) do
    if FFontKeys[I] = Key then
    begin
      Result := I;
      Exit;
    end;
  FillChar(LF, SizeOf(LF), 0);
  Px := BodyPixels * SizeMille[(Key shr 1) and 7] div 1000;
  if Key and 1 <> 0 then
  begin
    Face := EditorOptions.FontName;
    Px := Px * CodePercent div 100;
  end
  else
    Face := Font.Name;
  StrPLCopy(LF.lfFaceName, Face, SizeOf(LF.lfFaceName) - 1);
  LF.lfHeight := -Max(1, MulDiv(Px, FZoom, 100));
  if Key and 16 <> 0 then LF.lfWeight := FW_BOLD else LF.lfWeight := FW_NORMAL;
  LF.lfItalic := Ord(Key and 32 <> 0);
  LF.lfStrikeOut := Ord(Key and 64 <> 0);
  LF.lfUnderline := Ord(Key and 128 <> 0);
  LF.lfCharSet := DEFAULT_CHARSET;
  LF.lfQuality := DEFAULT_QUALITY;
  Result := Length(FFontKeys);
  SetLength(FFontKeys, Result + 1);
  SetLength(FFontHandles, Result + 1);
  SetLength(FFontAscent, Result + 1);
  SetLength(FFontHeight, Result + 1);
  SetLength(FFontWidths, Result + 1);
  FillChar(FFontWidths[Result], SizeOf(TRichWidthPages), 0);
  FFontKeys[Result] := Key;
  FFontHandles[Result] := CreateFontIndirect(LF);
  GetTextMetrics(SelectMeasureFont(Result), TM);
  FFontAscent[Result] := TM.tmAscent;
  FFontHeight[Result] := TM.tmHeight;
end;

function TSdRichView.FontHandle(Key: Integer): HFONT;
begin
  Result := FFontHandles[FontIndex(Key)];
end;

procedure TSdRichView.FreeFonts;
var
  I, K: Integer;
begin
  if FMeasureDC <> 0 then SelectObject(FMeasureDC, GetStockObject(SYSTEM_FONT));
  FMeasureFont := -1;
  for I := 0 to High(FFontHandles) do
  begin
    DeleteObject(FFontHandles[I]);
    for K := 0 to 255 do
      if FFontWidths[I][K] <> nil then Dispose(FFontWidths[I][K]);
  end;
  FFontKeys := nil;
  FFontHandles := nil;
  FFontAscent := nil;
  FFontHeight := nil;
  FFontWidths := nil;
end;

{ the width of Len characters at P in the font Key: the sum of their widths, read from GDI by 256 -
  GDI measures text with a character the font has no glyph of (it takes another font's), one it
  shapes or a surrogate }
function TSdRichView.WidthOf(P: PWideChar; Len, Key: Integer): Integer;
var
  F, I, Page, K, W: Integer;
  Pages: ^TRichWidthPages;
  DC: HDC;
  Chars: array[0..255] of WideChar;
  Glyphs: array[0..255] of Word;
  Sz: TSize;
begin
  Result := 0;
  if Len <= 0 then Exit;
  F := FontIndex(Key);
  Pages := @FFontWidths[F];
  for I := 0 to Len - 1 do
  begin
    if IsShapedChar(P[I]) then
    begin
      Result := -1;
      Break;
    end;
    Page := Ord(P[I]) shr 8;
    if Pages^[Page] = nil then
    begin
      New(Pages^[Page]);
      DC := SelectMeasureFont(F);
      if not GetCharWidth32W(DC, Page shl 8, Page shl 8 + 255, Pages^[Page]^[0]) then
        FillChar(Pages^[Page]^, SizeOf(TRichWidths), $FF)
      else
      begin
        for K := 0 to 255 do Chars[K] := WideChar(Page shl 8 + K);
        if GetGlyphIndicesW(DC, @Chars[0], 256, @Glyphs[0], GGI_MARK_NONEXISTING_GLYPHS) <> GDI_ERROR then
          for K := 0 to 255 do
            if (Glyphs[K] = $FFFF) and (Page shl 8 + K >= 32) then Pages^[Page]^[K] := -1;
      end;
    end;
    W := Pages^[Page]^[Ord(P[I]) and $FF];
    if W < 0 then
    begin
      Result := -1;
      Break;
    end;
    Inc(Result, W);
  end;
  if Result >= 0 then Exit;
  Result := 0;
  if GetTextExtentPoint32W(SelectMeasureFont(F), P, Len, Sz) then Result := Sz.cx;
end;

function TSdRichView.TextWidth(const T: WideString; Key: Integer): Integer;
begin
  Result := WidthOf(PWideChar(T), Length(T), Key);
end;

{ --- the layout --- }

procedure TSdRichView.AppendText(P: PWideChar; Len: Integer);
begin
  if Len <= 0 then Exit;
  if FTextLen + Len > Length(FText) then SetLength(FText, 2 * (FTextLen + Len) + 1024);
  Move(P^, FText[FTextLen + 1], Len * SizeOf(WideChar));
  Inc(FTextLen, Len);
end;

procedure TSdRichView.AppendBreak;
begin
  AppendText(@LineEnd[0], 2);
end;

function TSdRichView.AddDeco(Kind: TRichDecoKind; const R: TRect; Color: TColor): Integer;
begin
  if FDecoCount = Length(FDecos) then SetLength(FDecos, 2 * FDecoCount + 32);
  Result := FDecoCount;
  FDecos[Result].Kind := Kind;
  FDecos[Result].R := R;
  FDecos[Result].Color := Color;
  FDecos[Result].Checked := False;
  FDecos[Result].Text := '';
  FDecos[Result].Font := 0;
  Inc(FDecoCount);
end;

{ a line begins at X in the width W; Leading: what lies between its text and the next line's }
procedure TSdRichView.BeginLine(X, W: Integer; Align: TAlignment; Leading: Integer);
begin
  FLineX := X;
  FLineW := W;
  FCurX := 0;
  FInkX := 0;
  FLineFirst := FFragCount;
  FLineOffset := FTextLen;
  FLineAlign := Align;
  FLineLeading := Leading;
  FLineOpen := True;
end;

{ a piece of the line: Len characters at P in the font Key (appended to FText) or a picture
  W x H; joined to the piece before it when it is of the same kind and its text goes on there }
procedure TSdRichView.AddFrag(P: PWideChar; Len, Key: Integer; Color, Back: TColor; Link, Image, W, H: Integer);
var
  N: Integer;
begin
  N := FFragCount - 1;
  if (Image < 0) and (N >= FLineFirst) and (FFrags[N].Image < 0) and (FFrags[N].Font = Key) and
    (FFrags[N].Color = Color) and (FFrags[N].Back = Back) and (FFrags[N].Link = Link) and
    (FFrags[N].Offset + FFrags[N].Len = FTextLen) then
  begin
    Inc(FFrags[N].Len, Len);
    Inc(FFrags[N].W, W);
  end
  else
  begin
    if FFragCount = Length(FFrags) then SetLength(FFrags, 2 * FFragCount + 256);
    N := FFragCount;
    FFrags[N].X := FLineX + FCurX;
    FFrags[N].W := W;
    FFrags[N].H := H;
    FFrags[N].Line := FLineCount;
    FFrags[N].Offset := FTextLen;
    FFrags[N].Len := Len;
    FFrags[N].Font := Key;
    FFrags[N].Color := Color;
    FFrags[N].Back := Back;
    FFrags[N].Link := Link;
    FFrags[N].Image := Image;
    Inc(FFragCount);
  end;
  AppendText(P, Len);
  Inc(FCurX, W);
  if (Len <> 1) or (P^ <> ' ') or (Image >= 0) then FInkX := FCurX;
end;

{ the line ends: its height from its fonts and pictures, its pieces moved for its alignment; Y below it }
procedure TSdRichView.EndLine(var Y: Integer);
var
  I, K, Asc, Desc, Shift: Integer;
begin
  if not FLineOpen then Exit;
  FLineOpen := False;
  Asc := 0;
  Desc := 0;
  for I := FLineFirst to FFragCount - 1 do
    if FFrags[I].Image >= 0 then Asc := Max(Asc, FFrags[I].H)
    else
    begin
      K := FontIndex(FFrags[I].Font);
      Asc := Max(Asc, FFontAscent[K]);
      Desc := Max(Desc, FFontHeight[K] - FFontAscent[K]);
    end;
  if FFragCount = FLineFirst then
  begin
    { an empty line: the body's height }
    K := FontIndex(FontKey(False, 0, False, False, False, False));
    Asc := FFontAscent[K];
    Desc := FFontHeight[K] - FFontAscent[K];
  end;
  Shift := 0;
  case FLineAlign of
    taCenter: Shift := Max(0, (FLineW - FInkX) div 2);
    taRightJustify: Shift := Max(0, FLineW - FInkX);
  end;
  if Shift <> 0 then
    for I := FLineFirst to FFragCount - 1 do Inc(FFrags[I].X, Shift);
  if FLineCount = Length(FLines) then SetLength(FLines, 2 * FLineCount + 128);
  with FLines[FLineCount] do
  begin
    Top := Y;
    Base := FLineLeading div 2 + Asc;
    Height := Asc + Desc + FLineLeading;
    X := FLineX + Shift;
    Offset := FLineOffset;
    First := FLineFirst;
    Count := FFragCount - FLineFirst;
    Block := FLineBlock;
    SubLine := FLineSub;
    { the line's last ink: the blanks that end a wrapped line may lie past its width }
    FMaxRight := Max(FMaxRight, FLineX + Shift + FInkX);
    Inc(Y, Height);
  end;
  Inc(FLineCount);
end;

{ the line ends where it wraps, the next one begins in its place }
procedure TSdRichView.NewLine(var Y: Integer);
var
  X, W, Leading: Integer;
  Align: TAlignment;
begin
  X := FLineX;
  W := FLineW;
  Align := FLineAlign;
  Leading := FLineLeading;
  EndLine(Y);
  BeginLine(X, W, Align, Leading);
end;

{ runs wrapped in X .. X + W from Y on (Y below them afterwards): words and blanks, a word too
  long for the width cut between characters; Size the font's size (0 the body, 1 .. 6 a heading's) }
procedure TSdRichView.LayoutRuns(const Runs: TSdRuns; X, W: Integer; var Y: Integer; Size: Integer;
  Bold: Boolean; Color: TColor; Align: TAlignment);
var
  I, P, Q, Len, TW, Key, Fit, IW, IH, BlankW: Integer;
  T: PWideChar;
  Alt: WideString;
  Fore, Back, CodeBack: TColor;
  Img: TObject;
  Dx: array of Integer;
  Sz: TSize;
begin
  if Length(Runs) = 0 then Exit;
  CodeBack := UIBlend(clWindowText, clWindow, 8);
  BeginLine(X, W, Align, FEm * 3 div 10);
  for I := 0 to High(Runs) do
  begin
    if Runs[I].LineBreak then
    begin
      AppendBreak;
      NewLine(Y);
      Continue;
    end;
    if Runs[I].Link >= 0 then Fore := TColor($80000000 or COLOR_HOTLIGHT) else Fore := Color;
    if rsCode in Runs[I].Styles then Back := CodeBack else Back := clNone;
    Key := FontKey(rsCode in Runs[I].Styles, Size, Bold or (rsBold in Runs[I].Styles), rsItalic in Runs[I].Styles,
      rsStrike in Runs[I].Styles, False);
    T := PWideChar(Runs[I].Text);
    Len := Length(Runs[I].Text);
    if Runs[I].Image >= 0 then
    begin
      Img := ImageOf(FDoc.ImageSource(Runs[I].Image));
      if (Img <> nil) and (TRichImage(Img).Img <> nil) then
      begin
        ImageSize(Img, W, IW, IH);
        if (FCurX > 0) and (FCurX + IW > W) then NewLine(Y);
        AddFrag(nil, 0, Key, Fore, clNone, Runs[I].Link, FImages.IndexOfObject(Img), IW, IH);
        Continue;
      end;
      { no picture: its alternative text, in grey }
      Alt := Runs[I].Text;
      if Alt = '' then Alt := 'image';
      T := PWideChar(Alt);
      Len := Length(Alt);
      if Runs[I].Link < 0 then Fore := clGrayText;
      Key := FontKey(False, Size, Bold, True, False, False);
    end;
    BlankW := WidthOf(@Blank, 1, Key);
    P := 0;
    while P < Len do
    begin
      if T[P] = ' ' then
      begin
        { a blank at the start of a wrapped line is not shown (it stays in the text) }
        if FCurX = 0 then AppendText(@T[P], 1)
        else AddFrag(@T[P], 1, Key, Fore, Back, Runs[I].Link, -1, BlankW, 0);
        Inc(P);
        Continue;
      end;
      Q := P;
      while (Q < Len) and (T[Q] <> ' ') do Inc(Q);
      TW := WidthOf(@T[P], Q - P, Key);
      if (FCurX > 0) and (FCurX + TW > W) then NewLine(Y);
      { a word longer than the width: as many characters as fit on each line }
      while (TW > W - FCurX) and (Q - P > 1) do
      begin
        SetLength(Dx, Q - P);
        GetTextExtentExPointW(SelectMeasureFont(FontIndex(Key)), @T[P], Q - P, Max(1, W - FCurX), @Fit, @Dx[0], Sz);
        if Fit < 1 then Fit := 1;
        if Fit >= Q - P then Break;
        { never between the two halves of a surrogate pair }
        if (Fit > 1) and (Ord(T[P + Fit]) >= $DC00) and (Ord(T[P + Fit]) <= $DFFF) then Dec(Fit);
        AddFrag(@T[P], Fit, Key, Fore, Back, Runs[I].Link, -1, WidthOf(@T[P], Fit, Key), 0);
        Inc(P, Fit);
        NewLine(Y);
        TW := WidthOf(@T[P], Q - P, Key);
      end;
      AddFrag(@T[P], Q - P, Key, Fore, Back, Runs[I].Link, -1, TW, 0);
      P := Q;
    end;
  end;
  EndLine(Y);
end;

{ the width the runs take on one line (Longest: of their longest word - a table's column at least) }
function TSdRichView.RunsWidth(const Runs: TSdRuns; Bold: Boolean; Longest: Boolean): Integer;
var
  I, P, Q, Key, Line, IW, IH, Len: Integer;
  T: PWideChar;
  Img: TObject;
begin
  Result := 0;
  Line := 0;
  for I := 0 to High(Runs) do
  begin
    if Runs[I].LineBreak then
    begin
      Result := Max(Result, Line);
      Line := 0;
      Continue;
    end;
    Key := FontKey(rsCode in Runs[I].Styles, 0, Bold or (rsBold in Runs[I].Styles), rsItalic in Runs[I].Styles,
      False, False);
    if Runs[I].Image >= 0 then
    begin
      Img := ImageOf(FDoc.ImageSource(Runs[I].Image));
      if (Img <> nil) and (TRichImage(Img).Img <> nil) then
      begin
        ImageSize(Img, MaxInt div 4, IW, IH);
        if Longest then Result := Max(Result, IW) else Inc(Line, IW);
        Continue;
      end;
    end;
    T := PWideChar(Runs[I].Text);
    Len := Length(Runs[I].Text);
    if not Longest then
      Inc(Line, WidthOf(T, Len, Key))
    else
    begin
      P := 0;
      while P < Len do
      begin
        Q := P;
        while (Q < Len) and (T[Q] <> ' ') do Inc(Q);
        if Q > P then Result := Max(Result, WidthOf(@T[P], Q - P, Key));
        P := Q + 1;
      end;
    end;
  end;
  Result := Max(Result, Line);
end;

{ code block B's lines as the code editor colours them: made the first time it is laid out, kept
  with the document }
function TSdRichView.CodeOf(B: TSdBlock): TObject;
var
  I, K: Integer;
  C: TRichCode;
  Tip: TTipLines;
  Language: string;
begin
  for I := 0 to FCode.Count - 1 do
    if TRichCode(FCode[I]).Block = B then
    begin
      Result := FCode[I];
      Exit;
    end;
  C := TRichCode.Create;
  C.Block := B;
  FCode.Add(C);
  Result := C;
  if B.Kind = bkMarkup then Language := 'html' else Language := B.Language;
  Tip := HighlightCode(WideToIde(B.Text), Language);
  SetLength(C.Lines, Length(Tip));
  for I := 0 to High(Tip) do
  begin
    { an empty line is one blank in a tip's runs: none here }
    if (Length(Tip[I].Runs) = 1) and (Tip[I].Runs[0].Text = ' ') then Continue;
    SetLength(C.Lines[I], Length(Tip[I].Runs));
    for K := 0 to High(Tip[I].Runs) do
    begin
      C.Lines[I][K].Text := IdeTextToWide(Tip[I].Runs[K].Text);
      C.Lines[I][K].Color := Tip[I].Runs[K].Color;
      C.Lines[I][K].Style := Tip[I].Runs[K].Style;
    end;
  end;
end;
{ code in its box: each line of it as the code editor colours it, never wrapped (the box as wide
  as its longest line - the view scrolls sideways) }
procedure TSdRichView.LayoutCode(B: TSdBlock; X, W: Integer; var Y: Integer);
var
  C: TRichCode;
  I, K, Pad, Y0, Box, Key, Right: Integer;
  Back, Ground: TColor;
begin
  Ground := ElementBack(EditorOptions.Colors, eePlainText);
  { on the window's own colour the box is a shade darker, as a block apart }
  if ColorToRGB(Ground) = ColorToRGB(clWindow) then Back := UIBlend(clWindowText, clWindow, 4)
  else Back := Ground;
  C := TRichCode(CodeOf(B));
  Pad := FEm * 2 div 3;
  Y0 := Y;
  Box := AddDeco(dkFill, Rect(0, 0, 0, 0), Back);
  Inc(Y, Pad);
  Right := X + W;
  FLineBlock := B;
  for I := 0 to High(C.Lines) do
  begin
    FLineSub := I;
    BeginLine(X + Pad, MaxInt div 4, taLeftJustify, FEm div 6);
    for K := 0 to High(C.Lines[I]) do
      with C.Lines[I][K] do
      begin
        Key := FontKey(True, 0, fsBold in Style, fsItalic in Style, False, False);
        AddFrag(PWideChar(Text), Length(Text), Key, Color, clNone, -1, -1,
          WidthOf(PWideChar(Text), Length(Text), Key), 0);
      end;
    Right := Max(Right, X + Pad + FCurX + Pad);
    EndLine(Y);
    AppendBreak;
  end;
  FLineSub := 0;
  Inc(Y, Pad);
  FDecos[Box].R := Rect(X, Y0, Right, Y);
  if Back <> Ground then AddDeco(dkFrame, Rect(X, Y0, Right, Y), UIBlend(clWindowText, clWindow, 12));
  FMaxRight := Max(FMaxRight, Right);
end;

procedure TSdRichView.LayoutList(L: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer);
var
  I, Indent, MarkW, FirstLine, Top, Base, Asc, Key, Size, D, Mid: Integer;
  Item: TSdBlock;
  Num: WideString;
  Kind: TRichDecoKind;
begin
  Key := FontKey(False, 0, False, False, False, False);
  if L.Ordered then MarkW := TextWidth(WideString(IntToStr(L.Start + L.Count - 1)) + '.', Key) + FEm div 2
  else MarkW := FEm;
  Indent := Max(MarkW, FEm * 3 div 2);
  for I := 0 to L.Count - 1 do
  begin
    Item := L[I];
    if I > 0 then
      if L.Loose then Inc(Y, FEm * 2 div 3) else Inc(Y, FEm div 8);
    FirstLine := FLineCount;
    Top := Y;
    if Item.Count = 0 then
    begin
      FLineBlock := Item;
      BeginLine(X + Indent, W - Indent, taLeftJustify, FEm * 3 div 10);
      EndLine(Y);
    end
    else
      LayoutChildren(Item, X + Indent, W - Indent, Y, Color, Depth + 1, not L.Loose);
    { the mark on the item's first line }
    if FirstLine < FLineCount then
    begin
      Top := FLines[FirstLine].Top;
      Base := Top + FLines[FirstLine].Base;
    end
    else
      Base := Top + FEm;
    Asc := FFontAscent[FontIndex(Key)];
    Mid := Base - Asc * 2 div 5;
    if Item.Task >= 0 then
    begin
      Size := Max(8, FEm * 4 div 5);
      D := AddDeco(dkCheck, Rect(X + Indent - Size - FEm div 3, Mid - Size div 2,
        X + Indent - FEm div 3, Mid - Size div 2 + Size), Color);
      FDecos[D].Checked := Item.Task = 1;
    end
    else if L.Ordered then
    begin
      Num := WideString(IntToStr(L.Start + I)) + '.';
      D := AddDeco(dkText, Rect(X + Indent - FEm div 3 - TextWidth(Num, Key), Base, 0, 0), Color);
      FDecos[D].Text := Num;
      FDecos[D].Font := Key;
    end
    else
    begin
      case Depth mod 3 of
        0: Kind := dkDisc;
        1: Kind := dkCircle;
      else
        Kind := dkSquare;
      end;
      Size := Max(4, FEm div 3);
      AddDeco(Kind, Rect(X + Indent - FEm * 2 div 3 - Size div 2, Mid - Size div 2,
        X + Indent - FEm * 2 div 3 - Size div 2 + Size, Mid - Size div 2 + Size), Color);
    end;
  end;
end;

{ a table: its columns as wide as their text wants when that fits, else narrowed in proportion
  down to their longest words; the head bold on a shaded row, the rows striped, a grid }
procedure TSdRichView.LayoutTable(T: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor);
var
  Cols, R, C, PadX, PadY, Avail, SumNat, SumMin, CX, RowTop, RowBottom, CellY, Y0, Right, Ground: Integer;
  Nat, Mn, Wd: array of Integer;
  Row: TSdBlock;
  Grid: TColor;
begin
  Cols := 0;
  for R := 0 to T.Count - 1 do Cols := Max(Cols, T[R].Count);
  if Cols = 0 then Exit;
  SetLength(Nat, Cols);
  SetLength(Mn, Cols);
  SetLength(Wd, Cols);
  PadX := FEm div 2;
  PadY := FEm div 4;
  for R := 0 to T.Count - 1 do
    for C := 0 to T[R].Count - 1 do
    begin
      Nat[C] := Max(Nat[C], RunsWidth(T[R][C].Runs, T[R].Header, False));
      Mn[C] := Max(Mn[C], RunsWidth(T[R][C].Runs, T[R].Header, True));
    end;
  Avail := W - (Cols + 1) - Cols * 2 * PadX;
  SumNat := 0;
  SumMin := 0;
  for C := 0 to Cols - 1 do
  begin
    Nat[C] := Max(Nat[C], FEm);
    Mn[C] := Max(Mn[C], FEm);
    Inc(SumNat, Nat[C]);
    Inc(SumMin, Mn[C]);
  end;
  for C := 0 to Cols - 1 do
    if SumNat <= Avail then Wd[C] := Nat[C]
    else if SumMin >= Avail then Wd[C] := Mn[C]
    else Wd[C] := Mn[C] + MulDiv(Nat[C] - Mn[C], Avail - SumMin, Max(1, SumNat - SumMin));
  Right := X + 1;
  for C := 0 to Cols - 1 do Inc(Right, Wd[C] + 2 * PadX + 1);
  Grid := UIBlend(clWindowText, clWindow, 18);
  Y0 := Y;
  for R := 0 to T.Count - 1 do
  begin
    Row := T[R];
    RowTop := Y;
    RowBottom := RowTop + 1 + FEm + 2 * PadY;
    { the row's ground first: the painting takes the decorations in their order }
    if Row.Header then Ground := AddDeco(dkFill, Rect(X, RowTop, Right, RowTop), UIBlend(clWindowText, clWindow, 5))
    else if R mod 2 = 0 then Ground := AddDeco(dkFill, Rect(X, RowTop, Right, RowTop), UIBlend(clWindowText, clWindow, 3))
    else Ground := -1;
    CX := X + 1;
    for C := 0 to Row.Count - 1 do
    begin
      if C > 0 then AppendText(PWideChar(WideString(#9)), 1);
      CellY := RowTop + 1 + PadY;
      FLineBlock := Row[C];
      LayoutRuns(Row[C].Runs, CX + PadX, Wd[C], CellY, 0, Row.Header, Color, Row[C].Align);
      RowBottom := Max(RowBottom, CellY + PadY);
      Inc(CX, Wd[C] + 2 * PadX + 1);
    end;
    AppendBreak;
    if Ground >= 0 then FDecos[Ground].R.Bottom := RowBottom;
    AddDeco(dkFill, Rect(X, RowTop, Right, RowTop + 1), Grid);
    Y := RowBottom;
  end;
  AddDeco(dkFill, Rect(X, Y, Right, Y + 1), Grid);
  CX := X;
  AddDeco(dkFill, Rect(CX, Y0, CX + 1, Y + 1), Grid);
  for C := 0 to Cols - 1 do
  begin
    Inc(CX, Wd[C] + 2 * PadX + 1);
    AddDeco(dkFill, Rect(CX, Y0, CX + 1, Y + 1), Grid);
  end;
  Inc(Y);
  FMaxRight := Max(FMaxRight, Right);
end;

procedure TSdRichView.LayoutBlock(B: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer);
var
  Y0, N: Integer;
begin
  case B.Kind of
    bkParagraph:
      begin
        FLineBlock := B;
        LayoutRuns(B.Runs, X, W, Y, 0, False, Color, taLeftJustify);
        AppendBreak;
      end;
    bkHeading:
      begin
        if FLineCount > 0 then Inc(Y, FEm div 2);
        N := FAnchorBlocks.Add(B);
        if N >= Length(FAnchorTops) then SetLength(FAnchorTops, 2 * N + 16);
        FAnchorTops[N] := Y;
        FLineBlock := B;
        LayoutRuns(B.Runs, X, W, Y, B.Level, True, Color, taLeftJustify);
        AppendBreak;
        if B.Level <= 2 then
        begin
          Inc(Y, FEm div 6);
          AddDeco(dkFill, Rect(X, Y, X + W, Y + 1), UIBlend(clWindowText, clWindow, 15));
          Inc(Y, 1);
        end;
      end;
    bkCode, bkMarkup: LayoutCode(B, X, W, Y);
    bkQuote:
      begin
        Y0 := Y;
        LayoutChildren(B, X + FEm, W - FEm, Y, clGrayText, Depth, False);
        AddDeco(dkFill, Rect(X, Y0, X + Max(3, FEm div 5), Y), UIBlend(clWindowText, clWindow, 20));
      end;
    bkList: LayoutList(B, X, W, Y, Color, Depth);
    bkTable: LayoutTable(B, X, W, Y, Color);
    bkRule:
      begin
        Inc(Y, FEm div 3);
        AddDeco(dkFill, Rect(X, Y, X + W, Y + Max(2, FEm div 8)), UIBlend(clWindowText, clWindow, 15));
        Inc(Y, Max(2, FEm div 8) + FEm div 3);
      end;
  end;
end;

{ the blocks inside B, a gap between them (none in a tight list's item) }
procedure TSdRichView.LayoutChildren(B: TSdBlock; X, W: Integer; var Y: Integer; Color: TColor; Depth: Integer;
  Tight: Boolean);
var
  I: Integer;
begin
  for I := 0 to B.Count - 1 do
  begin
    if (I > 0) and not Tight then Inc(Y, FEm * 2 div 3);
    LayoutBlock(B[I], X, W, Y, Color, Depth);
  end;
end;

{ the width the text is laid out for: the client's without the vertical scroll bar, whether the bar
  shows or not }
function TSdRichView.WantedWidth: Integer;
begin
  Result := ClientWidth;
  if not HandleAllocated or (GetWindowLong(Handle, GWL_STYLE) and WS_VSCROLL = 0) then
    Dec(Result, GetSystemMetrics(SM_CXVSCROLL));
end;

procedure TSdRichView.Layout;
var
  Margin, W, Y: Integer;
begin
  FDirty := False;
  FFragCount := 0;
  FLineCount := 0;
  FDecoCount := 0;
  FTextLen := 0;
  FMaxRight := 0;
  FAnchorBlocks.Clear;
  FLineBlock := nil;
  FLineSub := 0;
  FLayoutWidth := WantedWidth;
  FEm := FFontHeight[FontIndex(FontKey(False, 0, False, False, False, False))];
  Margin := FEm;
  W := Max(FEm * 10, FLayoutWidth - 2 * Margin);
  Y := Margin;
  if FDoc <> nil then LayoutChildren(FDoc.Root, Margin, W, Y, clWindowText, 0, False);
  FSize := Point(FMaxRight + Margin, Y + Margin);
  FSelA := Min(FSelA, FTextLen);
  FSelB := Min(FSelB, FTextLen);
end;

{ the layout made now when it is to be made }
procedure TSdRichView.LayoutNeeded;
begin
  if FDirty then Layout;
end;

{ --- pictures --- }

function TSdRichView.ImageOf(const Source: WideString): TObject;
var
  Path: string;
  Frag: WideString;
  I, Age: Integer;
  E: TRichImage;
begin
  Result := nil;
  Path := RichLocalPath(FBaseFolder, Source, Frag);
  if Path = '' then Exit;
  Age := FileAgeU(Path);
  I := FImages.IndexOf(Path);
  if I >= 0 then
  begin
    E := TRichImage(FImages.Objects[I]);
    Result := E;
    if E.Age = Age then Exit;
    { the file changed: read again in the same entry }
    FreeAndNil(E.Img);
    if E.Bmp <> 0 then DeleteObject(E.Bmp);
    E.Bmp := 0;
  end
  else
  begin
    E := TRichImage.Create;
    E.Path := Path;
    FImages.AddObject(Path, E);
  end;
  E.Age := Age;
  if Age <> -1 then
    try
      E.Img := PictureToImage(ReadFileU(Path));
    except
      E.Img := nil;
    end;
  Result := E;
end;

{ a picture's size: its pixels at the monitor's DPI and the zoom, no wider than MaxW }
procedure TSdRichView.ImageSize(Img: TObject; MaxW: Integer; out W, H: Integer);
var
  I: TSdImage;
begin
  I := TRichImage(Img).Img;
  W := Max(1, MulDiv(MulDiv(I.Width, Font.PixelsPerInch, 96), FZoom, 100));
  H := Max(1, MulDiv(MulDiv(I.Height, Font.PixelsPerInch, 96), FZoom, 100));
  if W > MaxW then
  begin
    H := Max(1, MulDiv(H, MaxW, W));
    W := Max(1, MaxW);
  end;
end;

{ the picture at W x H with its transparency: from a bitmap of its pixels at that size,
  premultiplied (made again at another size) }
procedure TSdRichView.DrawImage(DC: HDC; Img: TObject; X, Y, W, H: Integer);
var
  E: TRichImage;
  Scaled: TSdImage;
begin
  E := TRichImage(Img);
  if (E = nil) or (E.Img = nil) then Exit;
  if (E.Bmp = 0) or (E.BmpW <> W) or (E.BmpH <> H) then
  begin
    if E.Bmp <> 0 then DeleteObject(E.Bmp);
    if (E.Img.Width = W) and (E.Img.Height = H) then Scaled := E.Img else Scaled := ScaleImage(E.Img, W, H, True);
    try
      E.Bmp := ImageToPremultipliedDib(Scaled);
    finally
      if Scaled <> E.Img then Scaled.Free;
    end;
    E.BmpW := W;
    E.BmpH := H;
  end;
  UIAlphaDraw(DC, E.Bmp, X, Y, W, H, 0, 0, 100);
end;
{ --- the document --- }

procedure TSdRichView.SetDocument(ADoc: TSdRichDoc; KeepPlace: Boolean);
begin
  FreeCode;
  if ADoc <> FDoc then FreeAndNil(FDoc);
  FDoc := ADoc;
  FSelA := 0;
  FSelB := 0;
  FHotLink := -1;
  FDownLink := -1;
  if not KeepPlace then FOrigin := Point(0, 0);
  FDirty := True;
  if HandleAllocated and Visible then UpdateScrollBars;
  Invalidate;
end;

function TSdRichView.GotoAnchor(const Name: WideString): Boolean;
var
  B: TSdBlock;
  I: Integer;
begin
  Result := False;
  if FDoc = nil then Exit;
  B := FDoc.FindAnchor(UrlDecodeW(Name));
  if B = nil then Exit;
  LayoutNeeded;
  I := FAnchorBlocks.IndexOf(B);
  if I < 0 then Exit;
  ScrollTo(FOrigin.X, FAnchorTops[I] - FEm div 2);
  Result := True;
end;

procedure TSdRichView.OptionsChanged;
begin
  FreeFonts;
  FreeCode;
  FDirty := True;
  if HandleAllocated and Visible then UpdateScrollBars;
  Invalidate;
end;

{ --- the selection --- }

function TSdRichView.HasSelection: Boolean;
begin
  Result := FSelA <> FSelB;
end;

function TSdRichView.SelectedText: WideString;
begin
  LayoutNeeded;
  Result := Copy(FText, Min(FSelA, FSelB) + 1, Abs(FSelB - FSelA));
end;

procedure TSdRichView.SelectAll;
begin
  LayoutNeeded;
  FSelA := 0;
  FSelB := FTextLen;
  Invalidate;
end;

procedure TSdRichView.CopySelection;
begin
  CopyText(SelectedText);
end;

procedure TSdRichView.CopyText(const W: WideString);
begin
  if W = '' then Exit;
  if not UIOpenClipboard(Handle) then Exit;
  try
    EmptyClipboard;
    UIClipboardSetText(W);
  finally
    CloseClipboard;
  end;
end;

{ the word around Offset (letters and digits; else the one character there) }
procedure TSdRichView.SelectWordAt(Offset: Integer);

  function IsWordChar(I: Integer): Boolean;
  begin
    Result := (I >= 1) and (I <= FTextLen) and (IsCharAlphaNumericW(FText[I]) or (FText[I] = '_'));
  end;

begin
  FSelA := Offset;
  FSelB := Offset;
  if IsWordChar(Offset + 1) or IsWordChar(Offset) then
  begin
    while IsWordChar(FSelA) do Dec(FSelA);
    while IsWordChar(FSelB + 1) do Inc(FSelB);
  end
  else if Offset < FTextLen then
    FSelB := Offset + 1;
  Invalidate;
end;

{ --- places --- }

function TSdRichView.ContentPoint(X, Y: Integer): TPoint;
begin
  Result := Point(X + FOrigin.X, Y + FOrigin.Y);
end;

function TSdRichView.FragRect(I: Integer): TRect;
begin
  with FLines[FFrags[I].Line] do
    Result := Rect(FFrags[I].X, Top, FFrags[I].X + FFrags[I].W, Top + Height);
end;

{ the piece at P (content coordinates); -1: none }
function TSdRichView.FragAt(const P: TPoint): Integer;
var
  I, K: Integer;
begin
  LayoutNeeded;
  for I := 0 to FLineCount - 1 do
    with FLines[I] do
      if (P.Y >= Top) and (P.Y < Top + Height) then
        for K := First to First + Count - 1 do
          if (P.X >= FFrags[K].X) and (P.X < FFrags[K].X + FFrags[K].W) then
          begin
            Result := K;
            Exit;
          end;
  Result := -1;
end;

{ the offset in FText of the boundary nearest to PX in piece I }
function TSdRichView.OffsetInFrag(I, PX: Integer): Integer;
var
  Dx: array of Integer;
  Fit, K, Prev: Integer;
  Sz: TSize;
begin
  with FFrags[I] do
  begin
    Result := Offset;
    if (Image >= 0) or (Len = 0) then
    begin
      if PX > X + W div 2 then Inc(Result, Len);
      Exit;
    end;
    SetLength(Dx, Len);
    GetTextExtentExPointW(SelectMeasureFont(FontIndex(Font)), @FText[Offset + 1], Len, MaxInt div 2, @Fit, @Dx[0], Sz);
    Prev := 0;
    for K := 0 to Len - 1 do
    begin
      if PX - X < (Prev + Dx[K]) div 2 then
      begin
        Result := Offset + K;
        Exit;
      end;
      Prev := Dx[K];
    end;
    Result := Offset + Len;
  end;
end;

{ the line nearest to P (content coordinates): the one under P - of those beside each other (a
  table's cells) the one nearest sideways -, else the nearest above or below; -1: no lines }
function TSdRichView.NearestLine(const P: TPoint): Integer;
var
  I, Dist, D, LeftX, RightX: Integer;
begin
  Result := -1;
  LayoutNeeded;
  Dist := MaxInt;
  for I := 0 to FLineCount - 1 do
    with FLines[I] do
    begin
      if Count > 0 then
      begin
        LeftX := FFrags[First].X;
        RightX := FFrags[First + Count - 1].X + FFrags[First + Count - 1].W;
      end
      else
      begin
        LeftX := X;
        RightX := X;
      end;
      { inside the line's height: the distance sideways; above or below it: the distance up or
        down counts much more }
      if P.Y < Top then D := Min(MaxInt div 4, (Top - P.Y) * 1000)
      else if P.Y >= Top + Height then D := Min(MaxInt div 4, (P.Y - Top - Height + 1) * 1000)
      else D := 0;
      if P.X < LeftX then Inc(D, LeftX - P.X) else if P.X > RightX then Inc(D, P.X - RightX);
      if D < Dist then
      begin
        Dist := D;
        Result := I;
      end;
    end;
end;

{ the offset in FText nearest to P (content coordinates), on its nearest line }
function TSdRichView.OffsetAt(const P: TPoint): Integer;
var
  L, K: Integer;
begin
  Result := 0;
  L := NearestLine(P);
  if L < 0 then Exit;
  with FLines[L] do
  begin
    if Count = 0 then
    begin
      Result := Offset;
      Exit;
    end;
    for K := First to First + Count - 1 do
    begin
      if P.X < FFrags[K].X then
      begin
        Result := FFrags[K].Offset;
        Exit;
      end;
      if P.X < FFrags[K].X + FFrags[K].W then
      begin
        Result := OffsetInFrag(K, P.X);
        Exit;
      end;
    end;
    K := First + Count - 1;
    Result := FFrags[K].Offset + FFrags[K].Len;
  end;
end;

{ the context menu's place in content coordinates }
function TSdRichView.ContextContent: TPoint;
begin
  if FContextByMouse then Result := ContentPoint(FContextPoint.X, FContextPoint.Y)
  else Result := ContentPoint(0, 0);
end;

function TSdRichView.ContextLink: WideString;
var
  F: Integer;
begin
  Result := '';
  if (FDoc = nil) or not FContextByMouse then Exit;
  F := FragAt(ContextContent);
  if (F >= 0) and (FFrags[F].Link >= 0) then Result := FDoc.LinkTarget(FFrags[F].Link);
end;

function TSdRichView.ContextLine: Integer;
var
  L: Integer;
begin
  Result := -1;
  L := NearestLine(ContextContent);
  if (L < 0) or (FLines[L].Block = nil) or (FLines[L].Block.Line < 0) then Exit;
  Result := FLines[L].Block.Line + FLines[L].SubLine;
end;
function TSdRichView.LineOfOffset(Offset: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FLineCount - 1 do
    if FLines[I].Offset <= Offset then
    begin
      if (Result < 0) or (FLines[I].Offset >= FLines[Result].Offset) then Result := I;
    end;
end;

{ --- zoom and scrolling --- }

function TSdRichView.ContentSize: TPoint;
begin
  LayoutNeeded;
  Result := FSize;
end;

function TSdRichView.LineSize: Integer;
begin
  Result := Max(1, FEm);
end;

procedure TSdRichView.SetZoom(Value: Integer; const Anchor: TPoint);
var
  Off, L: Integer;
begin
  Value := Max(MinZoom, Min(MaxZoom, Value));
  if Value = FZoom then Exit;
  { the text at the anchor's height stays there }
  Off := OffsetAt(ContentPoint(0, Anchor.Y));
  FZoom := Value;
  FreeFonts;
  Layout;
  L := LineOfOffset(Off);
  if L >= 0 then FOrigin.Y := FLines[L].Top - Anchor.Y;
  FOrigin.X := 0;
  UpdateScrollBars;
  Invalidate;
  ZoomChanged(Self);
end;

function TSdRichView.ZoomPercent: Integer;
begin
  Result := FZoom;
end;

function TSdRichView.CanZoom(Delta: Integer): Boolean;
begin
  Result := CanStepZoom(FZoom, Delta, MinZoom, MaxZoom);
end;

procedure TSdRichView.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
var
  A: TPoint;
begin
  if AtPoint then A := ScreenToClient(At) else A := Point(ClientWidth div 2, ClientHeight div 2);
  SetZoom(ZoomPercentStep(FZoom, Delta, MinZoom, MaxZoom), A);
end;

procedure TSdRichView.ZoomTo(Percent: Integer);
begin
  SetZoom(Percent, Point(0, 0));
end;

{ text that wraps in the width has no size to fit }
function TSdRichView.CanZoomFit: Boolean;
begin
  Result := False;
end;

procedure TSdRichView.ZoomFit;
begin
end;

function TSdRichView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  D: Integer;
begin
  Result := True;
  if ZoomByWheel(Self, FWheelZoom, WheelZooms(Shift), WheelDelta, MousePos) then Exit;
  D := -WheelDelta * 3 * LineSize div WHEEL_DELTA;
  if ssShift in Shift then ScrollTo(FOrigin.X + D, FOrigin.Y) else ScrollTo(FOrigin.X, FOrigin.Y + D);
end;

procedure TSdRichView.Resize;
var
  Off, L: Integer;
begin
  inherited;
  if not HandleAllocated or not Visible then Exit;
  if not FDirty and (WantedWidth <> FLayoutWidth) and (FDoc <> nil) then
  begin
    { another width wraps the text elsewhere: the line at the top stays at the top }
    Off := OffsetAt(ContentPoint(0, 0));
    Layout;
    L := LineOfOffset(Off);
    if (L >= 0) and (FOrigin.Y > 0) then FOrigin.Y := FLines[L].Top;
  end;
  UpdateScrollBars;
  Invalidate;
end;

{ --- the mouse and the keyboard --- }

procedure TSdRichView.SetHotLink(Value: Integer);
begin
  if Value = FHotLink then Exit;
  FHotLink := Value;
  if Value >= 0 then Cursor := crHandPoint else Cursor := crIBeam;
  Application.CancelHint;
  Invalidate;
end;

procedure TSdRichView.FollowLink(Link: Integer);
begin
  if FDoc <> nil then FollowTarget(FDoc.LinkTarget(Link));
end;

procedure TSdRichView.FollowTarget(const Target: WideString);
begin
  if Target = '' then Exit;
  if Target[1] = '#' then GotoAnchor(Copy(Target, 2, MaxInt))
  else if Assigned(FOnLink) then FOnLink(Self, Target);
end;

procedure TSdRichView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  F, Off: Integer;
begin
  inherited;
  if CanFocus and not Focused then SetFocus;
  if Button = mbRight then
  begin
    FContextPoint := Point(X, Y);
    FContextByMouse := True;
  end;
  if Button <> mbLeft then Exit;
  P := ContentPoint(X, Y);
  Off := OffsetAt(P);
  if ssDouble in Shift then
  begin
    SelectWordAt(Off);
    FSelecting := False;
    FDownLink := -1;
    Exit;
  end;
  if ssShift in Shift then FSelB := Off
  else
  begin
    FSelA := Off;
    FSelB := Off;
  end;
  FSelecting := True;
  F := FragAt(P);
  if F >= 0 then FDownLink := FFrags[F].Link else FDownLink := -1;
  Invalidate;
end;

procedure TSdRichView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  F, Off: Integer;
begin
  inherited;
  if FSelecting then
  begin
    { a drag beyond the window scrolls it }
    if Y < 0 then ScrollTo(FOrigin.X, FOrigin.Y + Y)
    else if Y > ClientHeight then ScrollTo(FOrigin.X, FOrigin.Y + Y - ClientHeight);
    Off := OffsetAt(ContentPoint(X, Y));
    if Off <> FSelB then
    begin
      FSelB := Off;
      Invalidate;
    end;
  end;
  P := ContentPoint(X, Y);
  F := FragAt(P);
  if (F >= 0) and (FFrags[F].Link >= 0) and not (FSelecting and (FSelA <> FSelB)) then SetHotLink(FFrags[F].Link)
  else SetHotLink(-1);
end;

procedure TSdRichView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  F, Link: Integer;
begin
  inherited;
  if Button <> mbLeft then Exit;
  FSelecting := False;
  Link := FDownLink;
  FDownLink := -1;
  if (Link >= 0) and (FSelA = FSelB) then
  begin
    F := FragAt(ContentPoint(X, Y));
    if (F >= 0) and (FFrags[F].Link = Link) then FollowLink(Link);
  end;
end;

procedure TSdRichView.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  SetHotLink(-1);
end;

{ the context menu by the keyboard (no place): its items take the top of the view }
procedure TSdRichView.WMContextMenu(var Message: TWMContextMenu);
begin
  if (Message.XPos = -1) and (Message.YPos = -1) then FContextByMouse := False;
  inherited;
end;

{ shown (a document set while hidden waits to be laid out at the width it is shown at): the scroll
  bars for it }
procedure TSdRichView.CMVisibleChanged(var Message: TMessage);
begin
  inherited;
  if Visible and HandleAllocated then UpdateScrollBars;
end;

procedure TSdRichView.CMHintShow(var Message: TCMHintShow);
var
  I: Integer;
  R: TRect;
begin
  Message.Result := 1;
  if (FHotLink < 0) or (FDoc = nil) then Exit;
  for I := 0 to FFragCount - 1 do
    if FFrags[I].Link = FHotLink then
    begin
      R := FragRect(I);
      OffsetRect(R, -FOrigin.X, -FOrigin.Y);
      if not PtInRect(R, Message.HintInfo^.CursorPos) then Continue;
      Message.HintInfo^.HintStr := WideToIde(FDoc.LinkTarget(FHotLink));
      Message.HintInfo^.CursorRect := R;
      Message.Result := 0;
      Exit;
    end;
end;

procedure TSdRichView.KeyDown(var Key: Word; Shift: TShiftState);
var
  Page: Integer;
begin
  Page := Max(LineSize, ClientHeight - LineSize);
  case Key of
    VK_UP: ScrollTo(FOrigin.X, FOrigin.Y - LineSize);
    VK_DOWN: ScrollTo(FOrigin.X, FOrigin.Y + LineSize);
    VK_LEFT: ScrollTo(FOrigin.X - LineSize, FOrigin.Y);
    VK_RIGHT: ScrollTo(FOrigin.X + LineSize, FOrigin.Y);
    VK_PRIOR: ScrollTo(FOrigin.X, FOrigin.Y - Page);
    VK_NEXT, VK_SPACE: ScrollTo(FOrigin.X, FOrigin.Y + Page);
    VK_HOME: ScrollTo(0, 0);
    VK_END: ScrollTo(FOrigin.X, ContentSize.Y);
    Ord('A'):
      if ssCtrl in Shift then SelectAll else Exit;
    Ord('C'), VK_INSERT:
      if ssCtrl in Shift then CopySelection else Exit;
  else
    inherited;
    Exit;
  end;
  Key := 0;
end;

procedure TSdRichView.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS;
end;

procedure TSdRichView.WMCopy(var Message: TMessage);
begin
  CopySelection;
end;

procedure TSdRichView.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdRichView.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdRichView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  OptionsChanged;
end;

{ --- painting --- }

procedure TSdRichView.PaintDeco(DC: HDC; const D: TRichDeco);
var
  Brush: HBRUSH;
  Pen: HPEN;
  OldB, OldP: HGDIOBJ;
  R: TRect;
  Part: TThemedButton;
begin
  if D.Color = clNone then Exit;
  R := D.R;
  case D.Kind of
    dkFill: UIFill(DC, R, D.Color);
    dkFrame: UIFrame(DC, R, D.Color);
    dkDisc, dkCircle:
      begin
        Pen := CreatePen(PS_SOLID, 1, ColorToRGB(D.Color));
        if D.Kind = dkDisc then Brush := CreateSolidBrush(ColorToRGB(D.Color))
        else Brush := GetStockObject(NULL_BRUSH);
        OldP := SelectObject(DC, Pen);
        OldB := SelectObject(DC, Brush);
        Ellipse(DC, R.Left, R.Top, R.Right, R.Bottom);
        SelectObject(DC, OldB);
        SelectObject(DC, OldP);
        DeleteObject(Pen);
        if D.Kind = dkDisc then DeleteObject(Brush);
      end;
    dkSquare: UIFill(DC, R, D.Color);
    dkCheck:
      begin
        if D.Checked then Part := tbCheckBoxCheckedNormal else Part := tbCheckBoxUncheckedNormal;
        ThemeServices.DrawElement(DC, ThemeServices.GetElementDetails(Part), R);
      end;
    dkText:
      begin
        SelectObject(DC, FontHandle(D.Font));
        SetTextColor(DC, ColorToRGB(D.Color));
        ExtTextOutW(DC, R.Left, R.Top, 0, nil, PWideChar(D.Text), Length(D.Text), nil);
      end;
  end;
end;

{ piece I at its place (DC's origin is the content's); the part of it in the selection on the
  selection's colours }
procedure TSdRichView.PaintFrag(DC: HDC; I: Integer; SelStart, SelEnd: Integer);
var
  Key, A, B, XA, XB, Base, Top, Height: Integer;
  SelBack, SelFore: TColor;
  T: PWideChar;

  procedure Part(From, Count, X: Integer; Fore: TColor);
  begin
    if Count <= 0 then Exit;
    SetTextColor(DC, ColorToRGB(Fore));
    ExtTextOutW(DC, X, Base, 0, nil, @T[From], Count, nil);
  end;

  function WidthOfPart(Count: Integer): Integer;
  var
    Sz: TSize;
  begin
    Result := 0;
    if (Count > 0) and GetTextExtentPoint32W(DC, T, Count, Sz) then Result := Sz.cx;
  end;

begin
  Top := FLines[FFrags[I].Line].Top;
  Height := FLines[FFrags[I].Line].Height;
  Base := Top + FLines[FFrags[I].Line].Base;
  if Focused then
  begin
    SelBack := clHighlight;
    SelFore := clHighlightText;
  end
  else
  begin
    SelBack := UISelectionTint(clWindow);
    SelFore := clWindowText;
  end;
  with FFrags[I] do
  begin
    if Image >= 0 then
    begin
      DrawImage(DC, FImages.Objects[Image], X, Base - H, W, H);
      if (SelStart <= Offset) and (SelEnd > Offset) then UIFill(DC, Rect(X, Base - H, X + W, Base), SelBack);
      Exit;
    end;
    if Len = 0 then Exit;
    T := @FText[Offset + 1];
    if Back <> clNone then
      UIFill(DC, Rect(X - 1, Top + Height div 8, X + W + 1, Top + Height - Height div 8), Back);
    Key := Font;
    if (Link >= 0) and (Link = FHotLink) then Key := Key or 128;
    SelectObject(DC, FontHandle(Key));
    A := Max(0, Min(Len, SelStart - Offset));
    B := Max(0, Min(Len, SelEnd - Offset));
    if A >= B then
    begin
      Part(0, Len, X, Color);
      Exit;
    end;
    XA := X + WidthOfPart(A);
    XB := X + WidthOfPart(B);
    { the code box's edges are selected with its ends }
    if Back <> clNone then
      UIFill(DC, Rect(XA - Ord(A = 0), Top, XB + Ord(B = Len), Top + Height), SelBack)
    else
      UIFill(DC, Rect(XA, Top, XB, Top + Height), SelBack);
    Part(0, A, X, Color);
    Part(A, B - A, XA, SelFore);
    Part(B, Len - B, XB, Color);
  end;
end;

procedure TSdRichView.Paint;
var
  DC: HDC;
  Saved, CW, CH, I, K, SelStart, SelEnd: Integer;
  View, R: TRect;
begin
  LayoutNeeded;
  DC := UIBufferDC(FPaintBuf, Self);
  CW := Max(1, ClientWidth);
  CH := Max(1, ClientHeight);
  Saved := SaveDC(DC);
  try
    UIFill(DC, Rect(0, 0, CW, CH), clWindow);
    SetWindowOrgEx(DC, FOrigin.X, FOrigin.Y, nil);
    View := Rect(FOrigin.X, FOrigin.Y, FOrigin.X + CW, FOrigin.Y + CH);
    SetBkMode(DC, TRANSPARENT);
    SetTextAlign(DC, TA_BASELINE or TA_LEFT);
    for I := 0 to FDecoCount - 1 do
    begin
      R := FDecos[I].R;
      if FDecos[I].Kind = dkText then R := Rect(R.Left, R.Top - FEm * 2, R.Left + FEm * 4, R.Top + FEm);
      if IntersectRect(R, R, View) then PaintDeco(DC, FDecos[I]);
    end;
    SelStart := Min(FSelA, FSelB);
    SelEnd := Max(FSelA, FSelB);
    for I := 0 to FLineCount - 1 do
      with FLines[I] do
      begin
        if (Top >= View.Bottom) or (Top + Height <= View.Top) then Continue;
        for K := First to First + Count - 1 do
          if (FFrags[K].X < View.Right) and (FFrags[K].X + FFrags[K].W > View.Left) then
            PaintFrag(DC, K, SelStart, SelEnd);
      end;
    SetWindowOrgEx(DC, 0, 0, nil);
  finally
    RestoreDC(DC, Saved);
  end;
  BitBlt(Canvas.Handle, 0, 0, CW, CH, DC, 0, 0, SRCCOPY);
end;

{ --- test mode --- }

function TSdRichView.StateText: string;
var
  I, Links: Integer;
begin
  LayoutNeeded;
  Links := 0;
  for I := 0 to FFragCount - 1 do
    if (FFrags[I].Link >= 0) and ((I = 0) or (FFrags[I - 1].Link <> FFrags[I].Link)) then Inc(Links);
  Result := Format('zoom=%d lines=%d frags=%d size=%dx%d origin=%d,%d sel=%d-%d links=%d images=%d',
    [FZoom, FLineCount, FFragCount, FSize.X, FSize.Y, FOrigin.X, FOrigin.Y, Min(FSelA, FSelB), Max(FSelA, FSelB),
    Links, FImages.Count]);
end;

end.
