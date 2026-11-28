{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResImage;

{ D7 Studio - the images of a resource file.

  * A bitmap (RT_BITMAP) is a DIB without its file header; a .bmp file is the same with it.
  * An icon or a cursor is a group (RT_GROUP_ICON / RT_GROUP_CURSOR: a directory) of images
    (RT_ICON / RT_CURSOR). Each image is a DIB of twice its height - the colours, then the AND
    mask - or a PNG; a cursor's image starts with its hot spot. An .ico / .cur file holds the same
    images after a directory of its own.

  TSdIconEntry is one image as the files keep it (its bytes are not decoded: a group goes to an
  .ico file and back unchanged); TSdImage is one image decoded into 32-bit pixels for the image
  editor, with the format it is written in again (bit count, palette, PNG). PNG images are decoded
  and encoded by GDI+ (its flat API, loaded when first needed). }

interface

uses
  Windows, SysUtils, Classes, Graphics;

const
  RT_CURSOR_ID = 1;
  RT_BITMAP_ID = 2;
  RT_ICON_ID = 3;
  RT_GROUP_CURSOR_ID = 12;
  RT_GROUP_ICON_ID = 14;

  { the pixels of an icon or a cursor that are no colour (alpha 0): the screen, and the screen
    inverted; alpha 0 with another colour is the screen XORed with that colour }
  PixelTransparent = $00000000;
  PixelInverted = $00FFFFFF;

type
  TSdImageKind = (ikBitmap, ikIcon, ikCursor);

  TSdPixels = array of Cardinal;

  { one image as 32-bit pixels, $AARRGGBB, top-down, straight alpha }
  TSdImage = class
  public
    Width, Height: Integer;
    Pixels: TSdPixels;
    BitCount: Integer;             // the format it is written in: 1, 4, 8, 24 or 32
    Palette: TSdPixels;            // $00RRGGBB, for a BitCount up to 8
    Png: Boolean;                  // an icon's or a cursor's image kept as PNG
    HotX, HotY: Integer;           // a cursor's hot spot
    constructor Create(AWidth, AHeight, ABitCount: Integer);
    function Clone: TSdImage;
    procedure Assign(Source: TSdImage);
    procedure SetSize(AWidth, AHeight: Integer);     // every pixel transparent
    function Pixel(X, Y: Integer): Cardinal;         // outside: transparent
    procedure SetPixel(X, Y: Integer; C: Cardinal);  // outside: nothing
    function SameAs(Other: TSdImage): Boolean;       // the same pixels, size, format and hot spot
    function FormatText: string;                     // "32 x 32, 256 colours", "... 32 bits, PNG"
    { the colour of the palette nearest to C ($00RRGGBB) - the colour itself above 8 bits }
    function Nearest(C: Cardinal): Cardinal;
  end;

  TSdIconEntry = record
    Width, Height: Integer;        // 1 ... 256
    Colors, Planes, BitCount: Integer;
    HotX, HotY: Integer;           // a cursor's
    Data: string;                  // the image: a DIB with its mask, or a PNG
  end;
  TSdIconEntries = array of TSdIconEntry;
  TSdIds = array of Integer;
  TSdSizes = array of TPoint;           // image sizes (New Image)

  EResImage = class(Exception);

{ the palettes of new images: 2 colours (black, white), 16 (Windows' VGA colours), 256 (the
  halftone palette) }
function StandardPalette(BitCount: Integer): TSdPixels;
function BitCountText(BitCount: Integer): string;      // "monochrome", "16 colours", "32 bits"

{ a packed DIB (BITMAPINFOHEADER, palette, bits) as pixels / back: an RT_BITMAP (Mask False) or
  an icon's image (Mask: twice the height, the AND mask after the colours). DibToImage raises
  EResImage on data it cannot read. }
function DibToImage(const Dib: string; Mask: Boolean): TSdImage;
function ImageToDib(Img: TSdImage; Mask: Boolean): string;

{ an icon's or a cursor's image as pixels / back (a PNG stays a PNG) }
function EntryToImage(const E: TSdIconEntry): TSdImage;
function ImageToEntry(Img: TSdImage): TSdIconEntry;

{ .ico and .cur files: False when Bytes is neither }
function ReadIconFile(const Bytes: string; var Cursor: Boolean; var Entries: TSdIconEntries): Boolean;
function WriteIconFile(const Entries: TSdIconEntries; Cursor: Boolean): string;

{ the directory of a group: its entries without their data, the ids of their RT_ICON / RT_CURSOR
  images; and back. EntryResData is an image as an RT_ICON / RT_CURSOR holds it (a cursor's with
  its hot spot first), SetEntryResData the reverse. }
function ReadGroupDir(const Dir: string; Cursor: Boolean; var Entries: TSdIconEntries; var Ids: TSdIds): Boolean;
function MakeGroupDir(const Entries: TSdIconEntries; const Ids: TSdIds; Cursor: Boolean): string;
function EntryResData(const E: TSdIconEntry; Cursor: Boolean): string;
procedure SetEntryResData(var E: TSdIconEntry; const Data: string; Cursor: Boolean);

{ .bmp files: the DIB of one ('' when Bytes is no .bmp) / a .bmp of a DIB }
function BmpFileToDib(const Bytes: string): string;
function DibToBmpFile(const Dib: string): string;

function IsPng(const Data: string): Boolean;
function PngAvailable: Boolean;                         // GDI+ is there
function PngToImage(const Data: string): TSdImage;      // raises EResImage
function ImageToPng(Img: TSdImage): string;             // '' when GDI+ cannot
{ a picture file's first image as 32 bits: a .bmp by DibToImage, the rest (PNG, JPEG, GIF, TIFF,
  ICO) by GDI+; raises EResImage }
function PictureToImage(const Data: string): TSdImage;
{ a 32-bit DIB with a BITMAPV5HEADER and an alpha mask - the clipboard's CF_DIBV5, which other
  programs read with its transparency }
function ImageToDibV5(Img: TSdImage): string;
{ the image as a 32-bit DIB section of its pixels premultiplied by their alpha - what AlphaBlend and
  UIAlphaDraw take; 0 when it cannot be made. The caller deletes it }
function ImageToPremultipliedDib(Img: TSdImage): HBITMAP;

{ the image at another size, as a new image of its format: Smooth averages the pixels it covers
  (with their alpha) when it gets smaller and interpolates when it gets larger, else each pixel
  is the nearest one's (pixel art); the hot spot goes with it }
function ScaleImage(Src: TSdImage; W, H: Integer; Smooth: Boolean): TSdImage;
{ the image in another format: Bits 1, 4, 8 (the standard palette), 24 or 32; Mask: an icon's or a
  cursor's (below 32 bits a pixel is opaque or the screen; else a bitmap's - below 32 bits it is
  opaque) }
procedure ConvertImage(Img: TSdImage; Bits: Integer; Mask: Boolean);
{ a pixel as Img's format holds it ($AARRGGBB): Mask as above }
function ConformPixel(Img: TSdImage; P: Cardinal; Mask: Boolean): Cardinal;
{ the largest width and height of an image of Kind: a bitmap's 4096, an icon's or a cursor's 256 }
function MaxImageSize(Kind: TSdImageKind): Integer;
{ the length of EntryResData(E, Cursor), without making that string }
function EntryResSize(const E: TSdIconEntry; Cursor: Boolean): Integer;

const
  { the checkerboard under what is not opaque (the image editor, its colours) }
  CheckLight = $FFFFFF;
  CheckDark = $E4E4E4;

{ a pixel ($AARRGGBB) as it shows over the colour Board ($00RRGGBB): blended by its alpha;
  XorScreen: alpha 0 with a colour is the screen XORed with that colour, else alpha 0 is Board }
function ComposePixel(P, Board: Cardinal; XorScreen: Boolean): Cardinal;
function SwapRB(C: Cardinal): TColor;        // $00RRGGBB as a TColor
function RGBOf(C: TColor): Cardinal;         // a TColor (a system colour too) as $00RRGGBB
{ R filled with the colour C ($AARRGGBB) over a checkerboard of Cell-pixel squares, laid from
  Origin (ComposePixel) }
procedure DrawChecked(DC: HDC; const R: TRect; C: Cardinal; Cell: Integer; const Origin: TPoint;
  XorScreen: Boolean);

{ the little-endian numbers of the resource formats: a word / a double word at P of S (1-based; 0
  when S ends before it), and the bytes of one }
function GetW(const S: string; P: Integer): Word;
function GetD(const S: string; P: Integer): Cardinal;
function WordStr(W: Word): string;
function DWordStr(D: Cardinal): string;
{ the type or the name in the header of a .res file's entry at P: an ordinal (FFFF nnnn: Ord, Name
  '') or a string of WCHARs ended by 0 (Ord -1, Name as IDE text); P comes back after it. A string
  that S ends inside of ends with S }
procedure ReadResId(const S: string; var P: Integer; var Ord: Integer; var Name: string);
function ResIdBytes(Ord: Integer; const Name: string): string;   // the bytes ReadResId reads
{ a type or a name as the resource API takes it: the ordinal Ord in the low word (Ord >= 0), else
  the string Name, which must live while the pointer is used }
function ResIdPtr(Ord: Integer; const Name: string): PChar;
{ ... and back: an ordinal (high word 0) gives Ord and Name '', a string Ord -1 and its text }
procedure SplitResId(P: PChar; var Ord: Integer; var Name: string);

implementation

uses
  ActiveX, SdEncoding, SdUI;

const
  PngSignature = #$89'PNG'#13#10#$1A#10;

type
  TBmpInfo = record
    HeaderSize, Width, Height, Bits, Compression, ClrUsed: Integer;
    TopDown: Boolean;
    PalOfs, PalCount, PalEntry: Integer;   // where the palette starts (1-based), its size, 4 or 3 bytes
    BitsOfs: Integer;                      // where the colours start (1-based)
    Masks: array[0..3] of Cardinal;        // BI_BITFIELDS: red, green, blue, alpha
  end;

{ ---------------------------------------------------------------- bytes }

function GetW(const S: string; P: Integer): Word;
begin
  if P + 1 <= Length(S) then Move(S[P], Result, 2) else Result := 0;
end;

function GetD(const S: string; P: Integer): Cardinal;
begin
  if P + 3 <= Length(S) then Move(S[P], Result, 4) else Result := 0;
end;

function GetBE(const S: string; P: Integer): Cardinal;
begin
  Result := 0;
  if P + 3 <= Length(S) then
    Result := Cardinal(Ord(S[P])) shl 24 or Cardinal(Ord(S[P + 1])) shl 16 or
      Cardinal(Ord(S[P + 2])) shl 8 or Cardinal(Ord(S[P + 3]));
end;

function WordStr(W: Word): string;
begin
  SetLength(Result, 2);
  Move(W, Result[1], 2);
end;

function DWordStr(D: Cardinal): string;
begin
  SetLength(Result, 4);
  Move(D, Result[1], 4);
end;

procedure ReadResId(const S: string; var P: Integer; var Ord: Integer; var Name: string);
var
  W: WideString;
  C: Word;
  Lost: Boolean;
begin
  if GetW(S, P) = $FFFF then
  begin
    Ord := GetW(S, P + 2);
    Name := '';
    Inc(P, 4);
    Exit;
  end;
  Ord := -1;
  W := '';
  repeat
    C := GetW(S, P);
    Inc(P, 2);
    if C <> 0 then W := W + WideChar(C);
  until (C = 0) or (P > Length(S));
  Name := FromWide(W, CP_ACP, Lost);       // IDE text (an implicit conversion takes the locale's code page)
end;

function ResIdBytes(Ord: Integer; const Name: string): string;
var
  W: WideString;
  I: Integer;
begin
  if Ord >= 0 then
    Result := WordStr($FFFF) + WordStr(Ord)
  else
  begin
    W := ToWide(Name, CP_ACP);
    Result := '';
    for I := 1 to Length(W) do Result := Result + WordStr(Word(W[I]));
    Result := Result + WordStr(0);
  end;
end;

function ResIdPtr(Ord: Integer; const Name: string): PChar;
begin
  if Ord >= 0 then Result := PChar(Ord) else Result := PChar(Name);
end;

procedure SplitResId(P: PChar; var Ord: Integer; var Name: string);
begin
  if Cardinal(P) shr 16 = 0 then
  begin
    Ord := Cardinal(P) and $FFFF;
    Name := '';
  end
  else
  begin
    Ord := -1;
    Name := StrPas(P);
  end;
end;

procedure Fail(const Msg: string);
begin
  raise EResImage.Create(Msg);
end;

function Max1(N: Integer): Integer;
begin
  if N < 1 then Result := 1 else Result := N;
end;

function Clamp255(V: Single): Single;
begin
  if V < 0 then Result := 0 else if V > 255 then Result := 255 else Result := V;
end;

{ the entry of the first Count of Pal nearest to C (squared RGB distance; the first of equals) }
function NearestIndex(const Pal: TSdPixels; Count: Integer; C: Cardinal): Integer;
var
  J, Best, D, DR, DG, DB: Integer;
begin
  Result := 0;
  Best := MaxInt;
  for J := 0 to Count - 1 do
  begin
    DR := Integer(C shr 16 and $FF) - Integer(Pal[J] shr 16 and $FF);
    DG := Integer(C shr 8 and $FF) - Integer(Pal[J] shr 8 and $FF);
    DB := Integer(C and $FF) - Integer(Pal[J] and $FF);
    D := DR * DR + DG * DG + DB * DB;
    if D < Best then
    begin
      Best := D;
      Result := J;
      if D = 0 then Exit;
    end;
  end;
end;

{ ---------------------------------------------------------------- TSdImage }

constructor TSdImage.Create(AWidth, AHeight, ABitCount: Integer);
begin
  inherited Create;
  BitCount := ABitCount;
  if BitCount <= 8 then Palette := StandardPalette(BitCount);
  SetSize(AWidth, AHeight);
end;

function TSdImage.Clone: TSdImage;
begin
  Result := TSdImage.Create(0, 0, 32);
  Result.Assign(Self);
end;

procedure TSdImage.Assign(Source: TSdImage);
begin
  Width := Source.Width;
  Height := Source.Height;
  Pixels := Copy(Source.Pixels, 0, Length(Source.Pixels));
  BitCount := Source.BitCount;
  Palette := Copy(Source.Palette, 0, Length(Source.Palette));
  Png := Source.Png;
  HotX := Source.HotX;
  HotY := Source.HotY;
end;

procedure TSdImage.SetSize(AWidth, AHeight: Integer);
begin
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  Width := AWidth;
  Height := AHeight;
  Pixels := nil;
  SetLength(Pixels, Width * Height);    // zeroed: transparent
end;

function TSdImage.Pixel(X, Y: Integer): Cardinal;
begin
  if (X >= 0) and (Y >= 0) and (X < Width) and (Y < Height) then Result := Pixels[Y * Width + X]
  else Result := PixelTransparent;
end;

procedure TSdImage.SetPixel(X, Y: Integer; C: Cardinal);
begin
  if (X >= 0) and (Y >= 0) and (X < Width) and (Y < Height) then Pixels[Y * Width + X] := C;
end;

function TSdImage.SameAs(Other: TSdImage): Boolean;
var
  I: Integer;
begin
  Result := (Other <> nil) and (Width = Other.Width) and (Height = Other.Height) and
    (BitCount = Other.BitCount) and (Png = Other.Png) and (HotX = Other.HotX) and (HotY = Other.HotY) and
    (Length(Palette) = Length(Other.Palette));
  if not Result then Exit;
  for I := 0 to High(Palette) do
    if Palette[I] <> Other.Palette[I] then
    begin
      Result := False;
      Exit;
    end;
  if Length(Pixels) > 0 then Result := CompareMem(@Pixels[0], @Other.Pixels[0], Length(Pixels) * 4);
end;

function TSdImage.FormatText: string;
begin
  Result := Format('%d x %d, %s', [Width, Height, BitCountText(BitCount)]);
  if Png then Result := Result + ', PNG';
end;

function TSdImage.Nearest(C: Cardinal): Cardinal;
begin
  C := C and $FFFFFF;
  if (BitCount > 8) or (Length(Palette) = 0) then Result := C
  else Result := Palette[NearestIndex(Palette, Length(Palette), C)] and $FFFFFF;
end;

{ ---------------------------------------------------------------- palettes }

const
  VgaColors: array[0..15] of Cardinal = (
    $000000, $800000, $008000, $808000, $000080, $800080, $008080, $C0C0C0,
    $808080, $FF0000, $00FF00, $FFFF00, $0000FF, $FF00FF, $00FFFF, $FFFFFF);

function StandardPalette(BitCount: Integer): TSdPixels;
var
  I: Integer;
  DC: HDC;
  Pal: HPALETTE;
  E: array[0..255] of TPaletteEntry;
begin
  Result := nil;
  case BitCount of
    1:
      begin
        SetLength(Result, 2);
        Result[0] := $000000;
        Result[1] := $FFFFFF;
      end;
    4:
      begin
        SetLength(Result, 16);
        for I := 0 to 15 do Result[I] := VgaColors[I];
      end;
    8:
      begin
        SetLength(Result, 256);
        DC := GetDC(0);
        try
          Pal := CreateHalftonePalette(DC);
        finally
          ReleaseDC(0, DC);
        end;
        FillChar(E, SizeOf(E), 0);
        if Pal <> 0 then
        begin
          GetPaletteEntries(Pal, 0, 256, E);
          DeleteObject(Pal);
        end;
        for I := 0 to 255 do
          Result[I] := Cardinal(E[I].peRed) shl 16 or Cardinal(E[I].peGreen) shl 8 or E[I].peBlue;
        { the VGA colours where the halftone palette has them (its first and last ten are
          Windows' static colours) }
        for I := 0 to 15 do
          if I < 8 then Result[I] := VgaColors[I] else Result[248 + I - 8] := VgaColors[I];
      end;
  end;
end;

function BitCountText(BitCount: Integer): string;
begin
  case BitCount of
    1: Result := 'monochrome';
    4: Result := '16 colours';
    8: Result := '256 colours';
  else
    Result := IntToStr(BitCount) + ' bits';
  end;
end;

{ ---------------------------------------------------------------- DIB }

function MaskShift(M: Cardinal): Integer;
begin
  Result := 0;
  if M = 0 then Exit;
  while M and 1 = 0 do
  begin
    M := M shr 1;
    Inc(Result);
  end;
end;

{ a channel of a BI_BITFIELDS pixel, 0..255 }
function MaskValue(V, M: Cardinal): Cardinal;
var
  Max: Cardinal;
begin
  Result := 0;
  if M = 0 then Exit;
  V := (V and M) shr MaskShift(M);
  Max := M shr MaskShift(M);
  Result := (V * 255 + Max div 2) div Max;
end;

function ReadBmpInfo(const Dib: string; Mask: Boolean; var B: TBmpInfo): Boolean;
var
  H: Integer;
begin
  Result := False;
  FillChar(B, SizeOf(B), 0);
  if Length(Dib) < 12 then Exit;
  B.HeaderSize := GetD(Dib, 1);
  if B.HeaderSize = 12 then
  begin
    { BITMAPCOREHEADER: 16-bit sizes, a palette of RGB triples }
    B.Width := GetW(Dib, 5);
    H := SmallInt(GetW(Dib, 7));
    B.Bits := GetW(Dib, 11);
    B.Compression := BI_RGB;
    B.PalEntry := 3;
  end
  else
  begin
    if (B.HeaderSize < 40) or (Length(Dib) < B.HeaderSize) then Exit;
    B.Width := Integer(GetD(Dib, 5));
    H := Integer(GetD(Dib, 9));
    B.Bits := GetW(Dib, 15);
    B.Compression := GetD(Dib, 17);
    B.ClrUsed := GetD(Dib, 33);
    B.PalEntry := 4;
  end;
  B.TopDown := H < 0;
  H := Abs(H);
  if Mask then H := H div 2;
  B.Height := H;
  if (B.Width <= 0) or (B.Height <= 0) or (B.Width > 32768) or (B.Height > 32768) then Exit;
  B.PalOfs := B.HeaderSize + 1;
  if B.Compression = BI_BITFIELDS then
  begin
    if B.HeaderSize >= 52 then
    begin
      B.Masks[0] := GetD(Dib, 41);
      B.Masks[1] := GetD(Dib, 45);
      B.Masks[2] := GetD(Dib, 49);
      if B.HeaderSize >= 56 then B.Masks[3] := GetD(Dib, 53);
    end
    else
    begin
      B.Masks[0] := GetD(Dib, B.HeaderSize + 1);
      B.Masks[1] := GetD(Dib, B.HeaderSize + 5);
      B.Masks[2] := GetD(Dib, B.HeaderSize + 9);
      Inc(B.PalOfs, 12);
    end;
  end
  else if (B.Bits = 16) and (B.Compression = BI_RGB) then
  begin
    B.Masks[0] := $7C00;
    B.Masks[1] := $03E0;
    B.Masks[2] := $001F;
  end;
  if B.Bits <= 8 then
  begin
    B.PalCount := B.ClrUsed;
    if (B.PalCount = 0) or (B.PalCount > 1 shl B.Bits) then B.PalCount := 1 shl B.Bits;
  end
  else
    B.PalCount := B.ClrUsed;      // an optional palette before the colours of a true-colour DIB
  B.BitsOfs := B.PalOfs + B.PalCount * B.PalEntry;
  Result := B.BitsOfs <= Length(Dib) + 1;
end;

function Stride(Width, Bits: Integer): Integer;
begin
  Result := ((Width * Bits + 31) div 32) * 4;
end;

{ a DIB Windows reads and this code does not (run-length encoded): drawn into a 32-bit DIB
  section by GDI, opaque }
function GdiDecode(const Dib: string; const B: TBmpInfo): TSdImage;
var
  Bits, P: PCardinal;
  Bmp: HBITMAP;
  DC: HDC;
  Old: HGDIOBJ;
  I: Integer;
begin
  DC := CreateCompatibleDC(0);
  try
    Bmp := UICreateDib32(B.Width, B.Height, Bits);
    if Bmp = 0 then Fail('The bitmap cannot be read.');
    try
      Old := SelectObject(DC, Bmp);
      SetDIBitsToDevice(DC, 0, 0, B.Width, B.Height, 0, 0, 0, B.Height, @Dib[B.BitsOfs],
        PBitmapInfo(@Dib[1])^, DIB_RGB_COLORS);
      GdiFlush;
      SelectObject(DC, Old);
      Result := TSdImage.Create(B.Width, B.Height, 24);
      P := Bits;
      for I := 0 to B.Width * B.Height - 1 do
      begin
        Result.Pixels[I] := $FF000000 or (P^ and $FFFFFF);
        Inc(P);
      end;
    finally
      DeleteObject(Bmp);
    end;
  finally
    DeleteDC(DC);
  end;
end;

function DibToImage(const Dib: string; Mask: Boolean): TSdImage;
var
  B: TBmpInfo;
  Pal: TSdPixels;
  X, Y, Row, RowStride, MaskRow, MaskStride, MaskOfs, I, V: Integer;
  SrcY: Integer;
  C, A: Cardinal;
  HasAlpha, MaskBit: Boolean;
  Img: TSdImage;
begin
  if not ReadBmpInfo(Dib, Mask, B) then Fail('The image is not a bitmap Windows reads.');
  if not (B.Compression in [BI_RGB, BI_BITFIELDS]) then
  begin
    if Mask then Fail('The icon image is compressed in a way that cannot be read.');
    Result := GdiDecode(Dib, B);
    Exit;
  end;
  if not (B.Bits in [1, 4, 8, 16, 24, 32]) then Fail(Format('Images of %d bits cannot be read.', [B.Bits]));
  RowStride := Stride(B.Width, B.Bits);
  MaskStride := Stride(B.Width, 1);
  MaskOfs := B.BitsOfs + RowStride * B.Height;
  { an icon's mask may be cut short by a careless writer (what is missing shows the image): the
    colours must be there }
  if MaskOfs - 1 > Length(Dib) then Fail('The image data is cut short.');
  SetLength(Pal, B.PalCount);
  for I := 0 to B.PalCount - 1 do
    Pal[I] := GetD(Dib, B.PalOfs + I * B.PalEntry) and $FFFFFF;
  if B.Bits <= 8 then Img := TSdImage.Create(B.Width, B.Height, B.Bits)
  else if B.Bits = 32 then Img := TSdImage.Create(B.Width, B.Height, 32)
  else Img := TSdImage.Create(B.Width, B.Height, 24);
  try
    if B.Bits <= 8 then
    begin
      Img.Palette := Copy(Pal, 0, Length(Pal));
      { an image whose palette is shorter than its bit count allows keeps the standard entries
        for the rest (no index may point outside the palette) }
      if Length(Img.Palette) < 1 shl B.Bits then
      begin
        I := Length(Img.Palette);
        SetLength(Img.Palette, 1 shl B.Bits);
        for V := I to High(Img.Palette) do Img.Palette[V] := 0;
      end;
    end;
    HasAlpha := False;
    for Y := 0 to B.Height - 1 do
    begin
      if B.TopDown then SrcY := Y else SrcY := B.Height - 1 - Y;
      Row := B.BitsOfs + SrcY * RowStride;
      MaskRow := MaskOfs + SrcY * MaskStride;
      for X := 0 to B.Width - 1 do
      begin
        case B.Bits of
          1, 4, 8:
            begin
              case B.Bits of
                1: V := (Ord(Dib[Row + X shr 3]) shr (7 - X and 7)) and 1;
                4: V := (Ord(Dib[Row + X shr 1]) shr (4 * (1 - X and 1))) and $F;
              else
                V := Ord(Dib[Row + X]);
              end;
              if V < Length(Img.Palette) then C := Img.Palette[V] else C := 0;
              A := 255;
            end;
          16:
            begin
              V := GetW(Dib, Row + X * 2);
              C := MaskValue(V, B.Masks[0]) shl 16 or MaskValue(V, B.Masks[1]) shl 8 or MaskValue(V, B.Masks[2]);
              A := 255;
            end;
          24:
            begin
              C := Cardinal(Ord(Dib[Row + X * 3 + 2])) shl 16 or Cardinal(Ord(Dib[Row + X * 3 + 1])) shl 8 or
                Cardinal(Ord(Dib[Row + X * 3]));
              A := 255;
            end;
        else
          begin
            V := Integer(GetD(Dib, Row + X * 4));
            if B.Compression = BI_BITFIELDS then
            begin
              C := MaskValue(V, B.Masks[0]) shl 16 or MaskValue(V, B.Masks[1]) shl 8 or MaskValue(V, B.Masks[2]);
              if B.Masks[3] <> 0 then A := MaskValue(V, B.Masks[3]) else A := 0;
            end
            else
            begin
              C := Cardinal(V) and $FFFFFF;
              A := Cardinal(V) shr 24;
            end;
            if A <> 0 then HasAlpha := True;
          end;
        end;
        MaskBit := False;
        if Mask and (MaskRow + X shr 3 <= Length(Dib)) then
          MaskBit := (Ord(Dib[MaskRow + X shr 3]) shr (7 - X and 7)) and 1 <> 0;
        if B.Bits = 32 then
          { the alpha decides when there is one (below); else the mask }
          Img.Pixels[Y * B.Width + X] := A shl 24 or C
        else if MaskBit then
          Img.Pixels[Y * B.Width + X] := C          // alpha 0: the screen (XORed with C)
        else
          Img.Pixels[Y * B.Width + X] := $FF000000 or C;
      end;
    end;
    if B.Bits = 32 then
    begin
      if HasAlpha then
      begin
        { straight alpha; what is fully transparent has no colour }
        for I := 0 to High(Img.Pixels) do
          if Img.Pixels[I] shr 24 = 0 then Img.Pixels[I] := PixelTransparent;
      end
      else
        { no alpha (an old 32-bit image): opaque, an icon's transparency from its mask }
        for Y := 0 to B.Height - 1 do
        begin
          if B.TopDown then SrcY := Y else SrcY := B.Height - 1 - Y;
          MaskRow := MaskOfs + SrcY * MaskStride;
          for X := 0 to B.Width - 1 do
          begin
            I := Y * B.Width + X;
            MaskBit := Mask and (MaskRow + X shr 3 <= Length(Dib)) and
              ((Ord(Dib[MaskRow + X shr 3]) shr (7 - X and 7)) and 1 <> 0);
            if MaskBit then Img.Pixels[I] := Img.Pixels[I] and $FFFFFF
            else Img.Pixels[I] := Img.Pixels[I] or $FF000000;
          end;
        end;
    end;
    Result := Img;
  except
    Img.Free;
    raise;
  end;
end;

{ the AND mask's bit of a pixel: the screen shows through. At 32 bits alpha 0 only (the alpha
  blends the rest); below, everything less than half opaque }
function IsScreen(P: Cardinal; Bits: Integer): Boolean;
begin
  if Bits = 32 then Result := P shr 24 = 0 else Result := P shr 24 < 128;
end;

function ImageToDib(Img: TSdImage; Mask: Boolean): string;
var
  Bits, PalCount, RowStride, MaskStride, X, Y, I, Ofs, Idx, LastIdx: Integer;
  P, C, LastC: Cardinal;
  Pal: TSdPixels;
  H: TBitmapInfoHeader;
  Rows: string;

  { the colour of the pixel before is asked again most of the time }
  function IndexOf(Color: Cardinal): Integer;
  begin
    if Color <> LastC then
    begin
      LastIdx := NearestIndex(Pal, PalCount, Color);
      LastC := Color;
    end;
    Result := LastIdx;
  end;

begin
  Bits := Img.BitCount;
  if not (Bits in [1, 4, 8, 24, 32]) then Bits := 24;
  PalCount := 0;
  if Bits <= 8 then
  begin
    PalCount := 1 shl Bits;
    Pal := Copy(Img.Palette, 0, Length(Img.Palette));
    if Length(Pal) = 0 then Pal := StandardPalette(Bits);
    I := Length(Pal);
    SetLength(Pal, PalCount);
    for X := I to PalCount - 1 do Pal[X] := 0;
  end;
  RowStride := Stride(Img.Width, Bits);
  MaskStride := Stride(Img.Width, 1);
  FillChar(H, SizeOf(H), 0);
  H.biSize := SizeOf(H);
  H.biWidth := Img.Width;
  H.biHeight := Img.Height;
  if Mask then H.biHeight := Img.Height * 2;
  H.biPlanes := 1;
  H.biBitCount := Bits;
  H.biCompression := BI_RGB;
  H.biSizeImage := RowStride * Img.Height;
  if Mask then Inc(H.biSizeImage, MaskStride * Img.Height);
  SetLength(Result, SizeOf(H));
  Move(H, Result[1], SizeOf(H));
  for I := 0 to PalCount - 1 do Result := Result + DWordStr(Pal[I] and $FFFFFF);
  LastC := $FFFFFFFF;
  LastIdx := 0;
  SetLength(Rows, RowStride * Img.Height);
  if Rows <> '' then FillChar(Rows[1], Length(Rows), 0);
  for Y := 0 to Img.Height - 1 do
  begin
    Ofs := (Img.Height - 1 - Y) * RowStride + 1;
    for X := 0 to Img.Width - 1 do
    begin
      P := Img.Pixels[Y * Img.Width + X];
      { what the colour bits hold: the colour; under the mask the XOR colour (black: the screen
        as it is) - fully transparent at 32 bits has none }
      if Mask and IsScreen(P, Bits) then
      begin
        if (Bits = 32) or (P shr 24 <> 0) then C := 0 else C := P and $FFFFFF;
      end
      else
        C := P and $FFFFFF;
      case Bits of
        1:
          begin
            Idx := IndexOf(C);
            if Idx <> 0 then
              Rows[Ofs + X shr 3] := Chr(Ord(Rows[Ofs + X shr 3]) or (1 shl (7 - X and 7)));
          end;
        4:
          begin
            Idx := IndexOf(C);
            Rows[Ofs + X shr 1] := Chr(Ord(Rows[Ofs + X shr 1]) or (Idx shl (4 * (1 - X and 1))));
          end;
        8:
          Rows[Ofs + X] := Chr(IndexOf(C));
        24:
          begin
            Rows[Ofs + X * 3] := Chr(C and $FF);
            Rows[Ofs + X * 3 + 1] := Chr(C shr 8 and $FF);
            Rows[Ofs + X * 3 + 2] := Chr(C shr 16 and $FF);
          end;
      else
        begin
          { the alpha too; a fully transparent pixel of an icon has no colour }
          if Mask and (P shr 24 = 0) then C := 0 else C := P;
          Move(C, Rows[Ofs + X * 4], 4);
        end;
      end;
    end;
  end;
  Result := Result + Rows;
  if Mask then
  begin
    SetLength(Rows, MaskStride * Img.Height);
    if Rows <> '' then FillChar(Rows[1], Length(Rows), 0);
    for Y := 0 to Img.Height - 1 do
    begin
      Ofs := (Img.Height - 1 - Y) * MaskStride + 1;
      for X := 0 to Img.Width - 1 do
        if IsScreen(Img.Pixels[Y * Img.Width + X], Bits) then
          Rows[Ofs + X shr 3] := Chr(Ord(Rows[Ofs + X shr 3]) or (1 shl (7 - X and 7)));
    end;
    Result := Result + Rows;
  end;
end;

{ ---------------------------------------------------------------- PNG (GDI+) }

type
  TGdiplusStartupInput = record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs: BOOL;
  end;
  TGpBitmapData = record
    Width, Height: UINT;
    Stride: Integer;
    PixelFormat: Integer;
    Scan0: Pointer;
    Reserved: UINT;
  end;
  TGpRect = record
    X, Y, Width, Height: Integer;
  end;

const
  PixelFormat32bppARGB = $26200A;
  ImageLockModeRead = 1;
  PngEncoder: TGUID = '{557CF406-1A04-11D3-9A73-0000F81EF32E}';

var
  GpLib: HMODULE;
  GpTried: Boolean;
  GpToken: ULONG;
  GdiplusStartup: function(out Token: ULONG; Input: Pointer; Output: Pointer): Integer; stdcall;
  GdiplusShutdown: procedure(Token: ULONG); stdcall;
  GdipCreateBitmapFromStream: function(Stream: IStream; out Bitmap: Pointer): Integer; stdcall;
  GdipCreateBitmapFromScan0: function(Width, Height, Stride, Format: Integer; Scan0: Pointer;
    out Bitmap: Pointer): Integer; stdcall;
  GdipGetImageWidth: function(Image: Pointer; var Width: UINT): Integer; stdcall;
  GdipGetImageHeight: function(Image: Pointer; var Height: UINT): Integer; stdcall;
  GdipBitmapLockBits: function(Bitmap: Pointer; Rect: Pointer; Flags: UINT; Format: Integer;
    var Data: TGpBitmapData): Integer; stdcall;
  GdipBitmapUnlockBits: function(Bitmap: Pointer; var Data: TGpBitmapData): Integer; stdcall;
  GdipSaveImageToStream: function(Image: Pointer; Stream: IStream; Clsid: PGUID; Params: Pointer): Integer; stdcall;
  GdipDisposeImage: function(Image: Pointer): Integer; stdcall;

function PngAvailable: Boolean;
var
  Input: TGdiplusStartupInput;

  function Get(const Name: string): Pointer;
  begin
    Result := GetProcAddress(GpLib, PChar(Name));
    if Result = nil then GpLib := 0;
  end;

begin
  if not GpTried then
  begin
    GpTried := True;
    GpLib := LoadLibrary('gdiplus.dll');
    if GpLib <> 0 then
    begin
      @GdiplusStartup := Get('GdiplusStartup');
      @GdiplusShutdown := Get('GdiplusShutdown');
      @GdipCreateBitmapFromStream := Get('GdipCreateBitmapFromStream');
      @GdipCreateBitmapFromScan0 := Get('GdipCreateBitmapFromScan0');
      @GdipGetImageWidth := Get('GdipGetImageWidth');
      @GdipGetImageHeight := Get('GdipGetImageHeight');
      @GdipBitmapLockBits := Get('GdipBitmapLockBits');
      @GdipBitmapUnlockBits := Get('GdipBitmapUnlockBits');
      @GdipSaveImageToStream := Get('GdipSaveImageToStream');
      @GdipDisposeImage := Get('GdipDisposeImage');
    end;
    if GpLib <> 0 then
    begin
      FillChar(Input, SizeOf(Input), 0);
      Input.GdiplusVersion := 1;
      if GdiplusStartup(GpToken, @Input, nil) <> 0 then GpLib := 0;
    end;
  end;
  Result := GpLib <> 0;
end;

function IsPng(const Data: string): Boolean;
begin
  Result := Copy(Data, 1, 8) = PngSignature;
end;

function GdipToImage(const Data: string): TSdImage;
var
  MS: TMemoryStream;
  Stream: IStream;
  Bmp: Pointer;
  W, H: UINT;
  BD: TGpBitmapData;
  R: TGpRect;
  Y: Integer;
begin
  if not PngAvailable then Fail('The picture cannot be read on this system (GDI+ is missing).');
  MS := TMemoryStream.Create;
  try
    MS.WriteBuffer(Data[1], Length(Data));
    MS.Position := 0;
    { the adapter lives as long as GDI+'s bitmap reads from it }
    Stream := TStreamAdapter.Create(MS, soReference);
    if GdipCreateBitmapFromStream(Stream, Bmp) <> 0 then
      Fail('The picture cannot be read.');
    try
      GdipGetImageWidth(Bmp, W);
      GdipGetImageHeight(Bmp, H);
      R.X := 0;
      R.Y := 0;
      R.Width := W;
      R.Height := H;
      if GdipBitmapLockBits(Bmp, @R, ImageLockModeRead, PixelFormat32bppARGB, BD) <> 0 then
        Fail('The picture cannot be read.');
      try
        Result := TSdImage.Create(W, H, 32);
        for Y := 0 to Integer(H) - 1 do
          Move(Pointer(Integer(BD.Scan0) + Y * BD.Stride)^, Result.Pixels[Y * Integer(W)], Integer(W) * 4);
        for Y := 0 to High(Result.Pixels) do
          if Result.Pixels[Y] shr 24 = 0 then Result.Pixels[Y] := PixelTransparent;
      finally
        GdipBitmapUnlockBits(Bmp, BD);
      end;
    finally
      GdipDisposeImage(Bmp);
    end;
  finally
    Stream := nil;
    MS.Free;
  end;
end;

function PngToImage(const Data: string): TSdImage;
begin
  Result := GdipToImage(Data);
  Result.Png := True;
end;

function PictureToImage(const Data: string): TSdImage;
begin
  if Copy(Data, 1, 2) = 'BM' then Result := DibToImage(BmpFileToDib(Data), False)
  else Result := GdipToImage(Data);
end;

function ImageToPng(Img: TSdImage): string;
var
  MS: TMemoryStream;
  Bmp: Pointer;
  Stream: IStream;
begin
  Result := '';
  if (Img.Width = 0) or (Img.Height = 0) or not PngAvailable then Exit;
  if GdipCreateBitmapFromScan0(Img.Width, Img.Height, Img.Width * 4, PixelFormat32bppARGB,
    @Img.Pixels[0], Bmp) <> 0 then Exit;
  MS := TMemoryStream.Create;
  try
    Stream := TStreamAdapter.Create(MS, soReference);
    try
      if GdipSaveImageToStream(Bmp, Stream, @PngEncoder, nil) = 0 then
        SetString(Result, PChar(MS.Memory), MS.Size);
    finally
      GdipDisposeImage(Bmp);
    end;
  finally
    Stream := nil;
    MS.Free;
  end;
end;

{ ---------------------------------------------------------------- icon entries }

{ the size and the format of an entry's image, read from the image itself (the directories'
  values are often wrong); values that cannot be read stay }
procedure EntryInfo(var E: TSdIconEntry);
var
  B: TBmpInfo;
begin
  if IsPng(E.Data) then
  begin
    E.Width := GetBE(E.Data, 17);
    E.Height := GetBE(E.Data, 21);
    E.BitCount := 32;
    E.Planes := 1;
    E.Colors := 0;
  end
  else if ReadBmpInfo(E.Data, True, B) then
  begin
    E.Width := B.Width;
    E.Height := B.Height;
    E.BitCount := B.Bits;
    E.Planes := 1;
    if B.Bits <= 8 then E.Colors := (1 shl B.Bits) and $FF else E.Colors := 0;
  end;
end;

function EntryToImage(const E: TSdIconEntry): TSdImage;
begin
  if IsPng(E.Data) then Result := PngToImage(E.Data) else Result := DibToImage(E.Data, True);
  Result.HotX := E.HotX;
  Result.HotY := E.HotY;
end;

function ImageToEntry(Img: TSdImage): TSdIconEntry;
var
  Dib: TSdImage;
begin
  Result.Width := Img.Width;
  Result.Height := Img.Height;
  Result.BitCount := Img.BitCount;
  Result.Planes := 1;
  Result.Colors := 0;
  Result.HotX := Img.HotX;
  Result.HotY := Img.HotY;
  Result.Data := '';
  if Img.Png then
  begin
    Result.Data := ImageToPng(Img);
    if Result.Data = '' then
    begin
      { GDI+ cannot write it: a DIB of 32 bits }
      Dib := Img.Clone;
      try
        Dib.BitCount := 32;
        Dib.Png := False;
        Result.Data := ImageToDib(Dib, True);
      finally
        Dib.Free;
      end;
    end;
  end
  else
    Result.Data := ImageToDib(Img, True);
  EntryInfo(Result);
end;

function ReadIconFile(const Bytes: string; var Cursor: Boolean; var Entries: TSdIconEntries): Boolean;
var
  Count, I, P, Size, Ofs: Integer;
begin
  Result := False;
  Entries := nil;
  if (Length(Bytes) < 6) or (GetW(Bytes, 1) <> 0) or not (GetW(Bytes, 3) in [1, 2]) then Exit;
  Cursor := GetW(Bytes, 3) = 2;
  Count := GetW(Bytes, 5);
  if (Count = 0) or (6 + Count * 16 > Length(Bytes)) then Exit;
  SetLength(Entries, Count);
  for I := 0 to Count - 1 do
  begin
    P := 7 + I * 16;
    Entries[I].Width := Ord(Bytes[P]);
    if Entries[I].Width = 0 then Entries[I].Width := 256;
    Entries[I].Height := Ord(Bytes[P + 1]);
    if Entries[I].Height = 0 then Entries[I].Height := 256;
    Entries[I].Colors := Ord(Bytes[P + 2]);
    if Cursor then
    begin
      Entries[I].HotX := GetW(Bytes, P + 4);
      Entries[I].HotY := GetW(Bytes, P + 6);
      Entries[I].Planes := 1;
      Entries[I].BitCount := 0;
    end
    else
    begin
      Entries[I].Planes := GetW(Bytes, P + 4);
      Entries[I].BitCount := GetW(Bytes, P + 6);
    end;
    Size := GetD(Bytes, P + 8);
    Ofs := GetD(Bytes, P + 12);
    if (Size <= 0) or (Ofs < 6) or (Ofs + Size > Length(Bytes)) then
    begin
      Entries := nil;
      Exit;
    end;
    Entries[I].Data := Copy(Bytes, Ofs + 1, Size);
    EntryInfo(Entries[I]);
  end;
  Result := True;
end;

function WriteIconFile(const Entries: TSdIconEntries; Cursor: Boolean): string;
var
  I, Ofs: Integer;
  Dir, Data: string;
begin
  Dir := WordStr(0) + WordStr(Ord(Cursor) + 1) + WordStr(Length(Entries));
  Data := '';
  Ofs := 6 + 16 * Length(Entries);
  for I := 0 to High(Entries) do
  begin
    Dir := Dir + Chr(Entries[I].Width and $FF) + Chr(Entries[I].Height and $FF) +
      Chr(Entries[I].Colors and $FF) + #0;
    if Cursor then Dir := Dir + WordStr(Entries[I].HotX) + WordStr(Entries[I].HotY)
    else Dir := Dir + WordStr(Entries[I].Planes) + WordStr(Entries[I].BitCount);
    Dir := Dir + DWordStr(Length(Entries[I].Data)) + DWordStr(Ofs);
    Inc(Ofs, Length(Entries[I].Data));
    Data := Data + Entries[I].Data;
  end;
  Result := Dir + Data;
end;

function ReadGroupDir(const Dir: string; Cursor: Boolean; var Entries: TSdIconEntries; var Ids: TSdIds): Boolean;
var
  Count, I, P: Integer;
begin
  Result := False;
  Entries := nil;
  Ids := nil;
  if Length(Dir) < 6 then Exit;
  Count := GetW(Dir, 5);
  if 6 + Count * 14 > Length(Dir) then Count := (Length(Dir) - 6) div 14;
  SetLength(Entries, Count);
  SetLength(Ids, Count);
  for I := 0 to Count - 1 do
  begin
    P := 7 + I * 14;
    if Cursor then
    begin
      Entries[I].Width := GetW(Dir, P);
      Entries[I].Height := GetW(Dir, P + 2) div 2;
      Entries[I].Colors := 0;
    end
    else
    begin
      Entries[I].Width := Ord(Dir[P]);
      if Entries[I].Width = 0 then Entries[I].Width := 256;
      Entries[I].Height := Ord(Dir[P + 1]);
      if Entries[I].Height = 0 then Entries[I].Height := 256;
      Entries[I].Colors := Ord(Dir[P + 2]);
    end;
    Entries[I].Planes := GetW(Dir, P + 4);
    Entries[I].BitCount := GetW(Dir, P + 6);
    Entries[I].Data := '';
    Ids[I] := GetW(Dir, P + 12);
  end;
  Result := True;
end;

function MakeGroupDir(const Entries: TSdIconEntries; const Ids: TSdIds; Cursor: Boolean): string;
var
  I: Integer;
begin
  Result := WordStr(0) + WordStr(Ord(Cursor) + 1) + WordStr(Length(Entries));
  for I := 0 to High(Entries) do
  begin
    if Cursor then
      Result := Result + WordStr(Entries[I].Width) + WordStr(Entries[I].Height * 2)
    else
      Result := Result + Chr(Entries[I].Width and $FF) + Chr(Entries[I].Height and $FF) +
        Chr(Entries[I].Colors and $FF) + #0;
    Result := Result + WordStr(Entries[I].Planes) + WordStr(Entries[I].BitCount) +
      DWordStr(EntryResSize(Entries[I], Cursor)) + WordStr(Ids[I]);
  end;
end;

function EntryResData(const E: TSdIconEntry; Cursor: Boolean): string;
begin
  if Cursor then Result := WordStr(E.HotX) + WordStr(E.HotY) + E.Data else Result := E.Data;
end;

{ a cursor's hot spot (two words) comes before its image }
function EntryResSize(const E: TSdIconEntry; Cursor: Boolean): Integer;
begin
  Result := Length(E.Data);
  if Cursor then Inc(Result, 4);
end;

procedure SetEntryResData(var E: TSdIconEntry; const Data: string; Cursor: Boolean);
begin
  if Cursor then
  begin
    E.HotX := GetW(Data, 1);
    E.HotY := GetW(Data, 3);
    E.Data := Copy(Data, 5, MaxInt);
  end
  else
    E.Data := Data;
  EntryInfo(E);
end;

{ ---------------------------------------------------------------- premultiplied pixels }

function ImageToPremultipliedDib(Img: TSdImage): HBITMAP;
var
  Bits: PCardinal;
  I: Integer;
  P, A: Cardinal;
begin
  Result := UICreateDib32(Img.Width, Img.Height, Bits);
  if Result = 0 then Exit;
  for I := 0 to Img.Width * Img.Height - 1 do
  begin
    P := Img.Pixels[I];
    A := P shr 24;
    if A < 255 then
      P := A shl 24 or ((P shr 16 and $FF) * A div 255) shl 16 or
        ((P shr 8 and $FF) * A div 255) shl 8 or (P and $FF) * A div 255;
    Bits^ := P;
    Inc(Bits);
  end;
end;

{ ---------------------------------------------------------------- the clipboard's DIB }

function ImageToDibV5(Img: TSdImage): string;
type
  TV5 = packed record
    Size: Cardinal;
    Width, Height: Integer;
    Planes, BitCount: Word;
    Compression, SizeImage: Cardinal;
    XPels, YPels: Integer;
    ClrUsed, ClrImportant: Cardinal;
    RedMask, GreenMask, BlueMask, AlphaMask, CSType: Cardinal;
    Endpoints: array[0..8] of Integer;
    GammaRed, GammaGreen, GammaBlue, Intent, ProfileData, ProfileSize, Reserved: Cardinal;
  end;
var
  H: TV5;
  Y: Integer;
  Rows: string;
begin
  FillChar(H, SizeOf(H), 0);
  H.Size := SizeOf(H);
  H.Width := Img.Width;
  H.Height := -Img.Height;              // top-down: the rows as the image keeps them
  H.Planes := 1;
  H.BitCount := 32;
  H.Compression := BI_BITFIELDS;
  H.SizeImage := Img.Width * Img.Height * 4;
  H.RedMask := $00FF0000;
  H.GreenMask := $0000FF00;
  H.BlueMask := $000000FF;
  H.AlphaMask := $FF000000;
  H.CSType := $73524742;                // 'sRGB'
  H.Intent := 4;                        // LCS_GM_IMAGES
  SetLength(Result, SizeOf(H));
  Move(H, Result[1], SizeOf(H));
  SetLength(Rows, Img.Width * 4);
  for Y := 0 to Img.Height - 1 do
  begin
    if Img.Width > 0 then Move(Img.Pixels[Y * Img.Width], Rows[1], Length(Rows));
    Result := Result + Rows;
  end;
end;

{ ---------------------------------------------------------------- scaling, formats }

function ConformPixel(Img: TSdImage; P: Cardinal; Mask: Boolean): Cardinal;
begin
  Result := P;
  if Img.BitCount < 32 then
  begin
    if not Mask then Result := $FF000000 or (P and $FFFFFF)
    else if P shr 24 >= 128 then Result := $FF000000 or (P and $FFFFFF)
    else if P shr 24 <> 0 then Result := PixelTransparent;
  end
  else if P shr 24 = 0 then
    Result := PixelTransparent;
  if (Img.BitCount <= 8) and (Result shr 24 = 255) then Result := $FF000000 or Img.Nearest(Result);
end;

{ every pixel of Img as its format holds it (ConformPixel); pixels repeat: the result of the pixel
  before is taken again for the same colour }
procedure ConformAll(Img: TSdImage; Mask: Boolean);
var
  I: Integer;
  Last, LastOut: Cardinal;
begin
  Last := 0;
  LastOut := ConformPixel(Img, Last, Mask);
  for I := 0 to High(Img.Pixels) do
  begin
    if Img.Pixels[I] <> Last then
    begin
      Last := Img.Pixels[I];
      LastOut := ConformPixel(Img, Last, Mask);
    end;
    Img.Pixels[I] := LastOut;
  end;
end;

procedure ConvertImage(Img: TSdImage; Bits: Integer; Mask: Boolean);
begin
  if not (Bits in [1, 4, 8, 24, 32]) then Exit;
  Img.BitCount := Bits;
  if Bits <= 8 then Img.Palette := StandardPalette(Bits) else Img.Palette := nil;
  if Bits < 32 then Img.Png := False;
  ConformAll(Img, Mask);
end;

function MaxImageSize(Kind: TSdImageKind): Integer;
begin
  if Kind = ikBitmap then Result := 4096 else Result := 256;
end;

type
  TChannels = array of Single;          // premultiplied A, R, G, B per pixel

{ one pass of the resampling: N1 values of Src (Stride apart, Count lines Line apart) to N2 values
  of Dst - the source span a destination value covers averaged (getting smaller), or the two
  nearest values interpolated (getting larger) }
procedure Resample(const Src: TChannels; var Dst: TChannels; N1, N2, Count, SrcStep, SrcLine, DstStep,
  DstLine: Integer);
var
  I, J, K, C, S0, S1: Integer;
  Scale, A, B, W, Sum, X: Single;
  Acc: array[0..3] of Single;
begin
  Scale := N1 / N2;
  for K := 0 to Count - 1 do
    for I := 0 to N2 - 1 do
    begin
      for C := 0 to 3 do Acc[C] := 0;
      if Scale > 1 then
      begin
        A := I * Scale;
        B := A + Scale;
        S0 := Trunc(A);
        S1 := Trunc(B);
        if S1 >= N1 then S1 := N1 - 1;
        Sum := 0;
        for J := S0 to S1 do
        begin
          { the part of source value J inside A..B }
          W := 1;
          if J < A then W := W - (A - J);
          if J + 1 > B then W := W - (J + 1 - B);
          if W <= 0 then Continue;
          for C := 0 to 3 do Acc[C] := Acc[C] + W * Src[(K * SrcLine + J * SrcStep) * 4 + C];
          Sum := Sum + W;
        end;
        if Sum > 0 then
          for C := 0 to 3 do Acc[C] := Acc[C] / Sum;
      end
      else
      begin
        X := (I + 0.5) * Scale - 0.5;
        if X < 0 then X := 0;
        S0 := Trunc(X);
        if S0 > N1 - 1 then S0 := N1 - 1;
        S1 := S0 + 1;
        if S1 > N1 - 1 then S1 := N1 - 1;
        W := X - S0;
        for C := 0 to 3 do
          Acc[C] := Src[(K * SrcLine + S0 * SrcStep) * 4 + C] * (1 - W) +
            Src[(K * SrcLine + S1 * SrcStep) * 4 + C] * W;
      end;
      for C := 0 to 3 do Dst[(K * DstLine + I * DstStep) * 4 + C] := Acc[C];
    end;
end;

function ScaleImage(Src: TSdImage; W, H: Integer; Smooth: Boolean): TSdImage;
var
  X, Y, I: Integer;
  P: Cardinal;
  A: Single;
  C0, C1, C2: TChannels;
begin
  Result := Src.Clone;
  Result.SetSize(W, H);
  Result.HotX := Src.HotX * W div Max1(Src.Width);
  Result.HotY := Src.HotY * H div Max1(Src.Height);
  if (Src.Width = 0) or (Src.Height = 0) or (W <= 0) or (H <= 0) then Exit;
  if not Smooth then
  begin
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
        Result.Pixels[Y * W + X] := Src.Pixels[(Y * Src.Height div H) * Src.Width + X * Src.Width div W];
    Exit;
  end;
  { premultiplied, so that transparent pixels lend no colour; the screen inverted (alpha 0 with a
    colour) counts as transparent }
  SetLength(C0, Src.Width * Src.Height * 4);
  for I := 0 to Src.Width * Src.Height - 1 do
  begin
    P := Src.Pixels[I];
    A := (P shr 24) / 255;
    C0[I * 4] := A;
    C0[I * 4 + 1] := (P shr 16 and $FF) * A;
    C0[I * 4 + 2] := (P shr 8 and $FF) * A;
    C0[I * 4 + 3] := (P and $FF) * A;
  end;
  SetLength(C1, W * Src.Height * 4);
  Resample(C0, C1, Src.Width, W, Src.Height, 1, Src.Width, 1, W);
  C0 := nil;
  SetLength(C2, W * H * 4);
  Resample(C1, C2, Src.Height, H, W, W, 1, W, 1);
  C1 := nil;
  for I := 0 to W * H - 1 do
  begin
    A := C2[I * 4];
    if A <= 0.002 then P := PixelTransparent
    else
      P := Cardinal(Round(A * 255)) shl 24 or Cardinal(Round(Clamp255(C2[I * 4 + 1] / A))) shl 16 or
        Cardinal(Round(Clamp255(C2[I * 4 + 2] / A))) shl 8 or Cardinal(Round(Clamp255(C2[I * 4 + 3] / A)));
    Result.Pixels[I] := P;
  end;
  { a format without partial alpha takes what it can hold }
  if Result.BitCount < 32 then ConformAll(Result, True);
end;

{ ---------------------------------------------------------------- colours }

function ComposePixel(P, Board: Cardinal; XorScreen: Boolean): Cardinal;
var
  A, R, G, B: Cardinal;
begin
  A := P shr 24;
  if A = 255 then Result := P and $FFFFFF
  else if A = 0 then
  begin
    if XorScreen then Result := Board xor (P and $FFFFFF) else Result := Board;
  end
  else
  begin
    R := ((P shr 16 and $FF) * A + (Board shr 16 and $FF) * (255 - A)) div 255;
    G := ((P shr 8 and $FF) * A + (Board shr 8 and $FF) * (255 - A)) div 255;
    B := ((P and $FF) * A + (Board and $FF) * (255 - A)) div 255;
    Result := R shl 16 or G shl 8 or B;
  end;
end;

function SwapRB(C: Cardinal): TColor;
begin
  Result := TColor((C and $FF) shl 16 or (C and $FF00) or (C shr 16 and $FF));
end;

function RGBOf(C: TColor): Cardinal;
begin
  Result := Cardinal(ColorToRGB(C));
  Result := (Result and $FF) shl 16 or (Result and $FF00) or (Result shr 16 and $FF);
end;

procedure DrawChecked(DC: HDC; const R: TRect; C: Cardinal; Cell: Integer; const Origin: TPoint;
  XorScreen: Boolean);
var
  X, Y: Integer;
  B: Cardinal;
begin
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
    begin
      if ((X - Origin.X) div Cell + (Y - Origin.Y) div Cell) and 1 = 0 then B := CheckLight else B := CheckDark;
      SetPixelV(DC, X, Y, SwapRB(ComposePixel(C, B, XorScreen)));
    end;
end;

{ ---------------------------------------------------------------- .bmp files }

function BmpFileToDib(const Bytes: string): string;
begin
  Result := '';
  if (Length(Bytes) > 14 + 12) and (Copy(Bytes, 1, 2) = 'BM') then Result := Copy(Bytes, 15, MaxInt);
end;

function DibToBmpFile(const Dib: string): string;
var
  B: TBmpInfo;
  Ofs: Cardinal;
begin
  if ReadBmpInfo(Dib, False, B) then Ofs := 14 + B.BitsOfs - 1 else Ofs := 14 + Length(Dib);
  Result := 'BM' + DWordStr(14 + Length(Dib)) + DWordStr(0) + DWordStr(Ofs) + Dib;
end;

initialization

finalization
  if (GpLib <> 0) and (GpToken <> 0) then GdiplusShutdown(GpToken);

end.
