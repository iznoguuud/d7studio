{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOsFrame;

{ D7 Studio - the frame of a real top-level window of this system, painted by hand.

  The form being designed is a child window. Windows gives a child window with a caption the
  old "basic" frame, which looks like no window the finished program will ever have. With
  visual styles on, the designer therefore paints the frame the desktop window manager gives a
  top-level window (Windows 10/11), measured from captures of real windows at 96 DPI:

  * Of the 8 px frame of a sizeable window only the innermost pixel is visible: a 1 px border
    line around the client area. The outer 7 px at the left, right and bottom are the invisible
    sizing border - they show what lies behind the window. The window keeps its real size.
  * Title bar: from the top edge of the window down to the client area (31 px = 1 px border +
    30), over the full visible width. Icon 16 x 16 at x = 9; caption in the caption font,
    grey-scale anti-aliased, at x = 30; both vertically centred.
  * Caption buttons at the right: close, maximise, minimise, each glyph 10 x 10 at 10 px from
    the top, their left edges 29, 75 and 120 px from the right edge. The glyphs are the
    coverage maps of the real ones (GlyphMin, GlyphMax, GlyphClose) blended in the text colour.
    Without minimise and maximise box only the close button exists; with one of the two the
    other is shown disabled.
  * Colours: with "Show accent color on title bars and window borders" (registry DWM\
    ColorPrevalence) the active title bar and border have the accent colour (DWM\AccentColor),
    the text is white or black, whichever contrasts; otherwise the title bar is white with
    black text. Inactive: D8D8D8 with 818181 text (accent setting) or F3F3F3 with 9A9A9A.
  * Windows 11 (build 22000 and later) rounds the corners with a radius of 8 px. The two top
    corners are rounded here, anti-aliased against what lies behind the window; the bottom
    corners would cut into the client area and stay square. }

interface

uses
  Windows, SysUtils, Classes, Graphics;

type
  TOsFrame = record
    Width, Height: Integer;       // size of the window
    Client: TRect;                // its client rectangle in window coordinates
    TitleBottom: Integer;         // first row below the title bar (a menu bar may follow)
    Caption: string;
    Icon: HICON;                  // 0 = none
    Active: Boolean;
    SysMenu, MinBox, MaxBox: Boolean;
    SmallCaption: Boolean;        // tool window
    Back: TColor;                 // what lies behind the window
  end;

{ paints the whole non-client area except Skip (the design-time menu bar) }
procedure DrawOsFrame(DC: HDC; const F: TOsFrame; const Skip: TRect);

{ the colour of the 1 px border line DrawOsFrame puts around the client area }
function OsFrameBorderColor(Active: Boolean): TColor;

implementation

uses
  Registry, SdUI;

type
  TGlyph = array[0..9, 0..9] of Byte;

const
  GlyphMin: TGlyph = (
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (255, 255, 255, 255, 255, 255, 255, 255, 255, 255),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
  GlyphMax: TGlyph = (
    (146, 252, 255, 255, 255, 255, 255, 255, 252, 146),
    (252, 43, 16, 16, 16, 16, 16, 16, 36, 252),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (255, 16, 0, 0, 0, 0, 0, 0, 0, 255),
    (252, 36, 0, 0, 0, 0, 0, 0, 27, 252),
    (146, 252, 255, 255, 255, 255, 255, 255, 252, 146));
  GlyphClose: TGlyph = (
    (221, 65, 0, 0, 0, 0, 0, 0, 65, 220),
    (65, 230, 65, 0, 0, 0, 0, 65, 230, 65),
    (0, 65, 230, 65, 0, 0, 65, 230, 65, 0),
    (0, 0, 65, 230, 65, 65, 230, 65, 0, 0),
    (0, 0, 0, 65, 230, 230, 65, 0, 0, 0),
    (0, 0, 0, 65, 230, 230, 65, 0, 0, 0),
    (0, 0, 65, 230, 65, 65, 230, 65, 0, 0),
    (0, 65, 230, 65, 0, 0, 65, 230, 65, 0),
    (65, 230, 65, 0, 0, 0, 0, 65, 230, 65),
    (220, 65, 0, 0, 0, 0, 0, 0, 65, 221));
  CloseLeft = 29;               // left edge of the glyph, measured from the right edge
  MaxLeft = 75;
  MinLeft = 120;
  GlyphTop = 10;
  Radius = 8;

var
  SysTick: Cardinal;
  SysValid: Boolean;
  SysPrevalence: Boolean;
  SysAccent, SysAccentInactive: TColor;
  SysHasInactive: Boolean;
  SysRound: Boolean;
  CornerValid: Boolean;
  CornerIn, CornerRing: array[0..Radius - 1, 0..Radius - 1] of Byte;   // 0..16 samples

function Mix(A, B: TColor; Alpha: Integer): TColor;      // Alpha 0 = A ... 255 = B
var
  CA, CB: COLORREF;
begin
  CA := ColorToRGB(A);
  CB := ColorToRGB(B);
  Result := RGB(
    (GetRValue(CA) * (255 - Alpha) + GetRValue(CB) * Alpha + 127) div 255,
    (GetGValue(CA) * (255 - Alpha) + GetGValue(CB) * Alpha + 127) div 255,
    (GetBValue(CA) * (255 - Alpha) + GetBValue(CB) * Alpha + 127) div 255);
end;

procedure NeedSystem;
var
  Reg: TRegistry;
  S: string;
begin
  if SysValid and (GetTickCount - SysTick < 2000) then Exit;
  SysValid := True;
  SysTick := GetTickCount;
  SysPrevalence := False;
  SysAccent := TColor($00D77800);
  SysHasInactive := False;
  SysRound := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\DWM') then
      begin
        if Reg.ValueExists('ColorPrevalence') then SysPrevalence := Reg.ReadInteger('ColorPrevalence') <> 0;
        { ABGR: the low three bytes are a TColor }
        if Reg.ValueExists('AccentColor') then SysAccent := TColor(Reg.ReadInteger('AccentColor') and $00FFFFFF);
        if Reg.ValueExists('AccentColorInactive') then
        begin
          SysAccentInactive := TColor(Reg.ReadInteger('AccentColorInactive') and $00FFFFFF);
          SysHasInactive := True;
        end;
        Reg.CloseKey;
      end;
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows NT\CurrentVersion') then
      begin
        S := Reg.ReadString('CurrentBuildNumber');
        SysRound := StrToIntDef(S, 0) >= 22000;
        Reg.CloseKey;
      end;
    except
    end;
  finally
    Reg.Free;
  end;
end;

procedure FrameColors(Active: Boolean; var Title, Text, Border: TColor);
var
  C: COLORREF;
begin
  NeedSystem;
  if Active then
    if SysPrevalence then
    begin
      Title := SysAccent;
      Border := SysAccent;
      C := ColorToRGB(SysAccent);
      { the text contrasts with the accent colour }
      if GetRValue(C) * 299 + GetGValue(C) * 587 + GetBValue(C) * 114 < 150000 then Text := clWhite
      else Text := clBlack;
    end
    else
    begin
      Title := clWhite;
      Text := clBlack;
      Border := TColor($00A0A0A0);
    end
  else if SysPrevalence then
  begin
    if SysHasInactive then Title := SysAccentInactive else Title := TColor($00D8D8D8);
    Text := TColor($00818181);
    Border := TColor($00A0A0A0);
  end
  else
  begin
    Title := TColor($00F3F3F3);
    Text := TColor($009A9A9A);
    Border := TColor($00B0B0B0);
  end;
end;

function OsFrameBorderColor(Active: Boolean): TColor;
var
  Title, Text: TColor;
begin
  FrameColors(Active, Title, Text, Result);
end;

{ coverage of a quarter circle of radius 8 and of its 1 px rim, 4 x 4 samples per pixel }
procedure NeedCorner;
var
  I, J, S, T: Integer;
  X, Y, D: Double;
begin
  if CornerValid then Exit;
  CornerValid := True;
  for J := 0 to Radius - 1 do
    for I := 0 to Radius - 1 do
    begin
      CornerIn[J, I] := 0;
      CornerRing[J, I] := 0;
      for T := 0 to 3 do
        for S := 0 to 3 do
        begin
          X := I + (S + 0.5) / 4 - Radius;
          Y := J + (T + 0.5) / 4 - Radius;
          D := Sqrt(X * X + Y * Y);
          if D <= Radius then
          begin
            Inc(CornerIn[J, I]);
            if D > Radius - 1 then Inc(CornerRing[J, I]);
          end;
        end;
    end;
end;

{ the frame's parts can be empty or inverted for a very small window: nothing to fill then }
procedure Fill(DC: HDC; X1, Y1, X2, Y2: Integer; Color: TColor);
begin
  if (X2 > X1) and (Y2 > Y1) then UIFill(DC, Rect(X1, Y1, X2, Y2), Color);
end;

procedure DrawGlyph(DC: HDC; X, Y: Integer; const G: TGlyph; Back, Ink: TColor; Enabled: Boolean);
var
  I, J, A: Integer;
begin
  for J := 0 to 9 do
    for I := 0 to 9 do
    begin
      A := G[J, I];
      if A = 0 then Continue;
      if not Enabled then A := A * 90 div 255;
      SetPixelV(DC, X + I, Y + J, ColorToRGB(Mix(Back, Ink, A)));
    end;
end;

procedure DrawOsFrame(DC: HDC; const F: TOsFrame; const Skip: TRect);
var
  Title, Text, Border, C: TColor;
  V: TRect;                     // the visible window: the client area and 1 px around it
  Bmp: TBitmap;
  B: HDC;
  LF: TLogFont;
  Which: TUINonClientFont;
  Font, OldFont: HFONT;
  TR: TRect;
  TH, I, J, X, Right, Saved: Integer;
  TM: TTextMetric;
begin
  if (F.Width <= 0) or (F.Height <= 0) then Exit;
  FrameColors(F.Active, Title, Text, Border);
  V := Rect(F.Client.Left - 1, 0, F.Client.Right + 1, F.Client.Bottom + 1);
  TH := F.TitleBottom;
  Saved := SaveDC(DC);
  try
    ExcludeClipRect(DC, F.Client.Left, F.Client.Top, F.Client.Right, F.Client.Bottom);
    if not IsRectEmpty(Skip) then ExcludeClipRect(DC, Skip.Left, Skip.Top, Skip.Right, Skip.Bottom);
    { --- the part below the title bar: sizing border (what is behind the window), the border
          line left, right and below the client area --- }
    Fill(DC, 0, TH, V.Left, F.Height, F.Back);
    Fill(DC, V.Right, TH, F.Width, F.Height, F.Back);
    Fill(DC, V.Left, V.Bottom, V.Right, F.Height, F.Back);
    Fill(DC, V.Left, TH, V.Left + 1, V.Bottom, Border);
    Fill(DC, V.Right - 1, TH, V.Right, V.Bottom, Border);
    Fill(DC, V.Left, V.Bottom - 1, V.Right, V.Bottom, Border);
    { anything else of the non-client area between title bar and client area }
    Fill(DC, V.Left + 1, TH, V.Right - 1, F.Client.Top, Title);
    { --- the title bar, composed off screen --- }
    if TH <= 1 then Exit;
    Bmp := TBitmap.Create;
    try
      Bmp.PixelFormat := pf24bit;
      Bmp.Width := F.Width;
      Bmp.Height := TH;
      B := Bmp.Canvas.Handle;
      Fill(B, 0, 0, F.Width, TH, F.Back);
      Fill(B, V.Left, 0, V.Right, TH, Border);
      Fill(B, V.Left + 1, 1, V.Right - 1, TH, Title);
      Right := V.Right - 1;
      { buttons }
      if F.SysMenu then
      begin
        DrawGlyph(B, V.Right - CloseLeft, GlyphTop, GlyphClose, Title, Text, True);
        Right := V.Right - CloseLeft - 18;
        if (F.MinBox or F.MaxBox) and not F.SmallCaption then
        begin
          DrawGlyph(B, V.Right - MaxLeft, GlyphTop, GlyphMax, Title, Text, F.MaxBox);
          DrawGlyph(B, V.Right - MinLeft, GlyphTop, GlyphMin, Title, Text, F.MinBox);
          Right := V.Right - MinLeft - 18;
        end;
      end;
      { icon and caption }
      X := V.Left + 9;
      if (F.Icon <> 0) and not F.SmallCaption then
      begin
        DrawIconEx(B, X, (TH - 16 + 1) div 2, F.Icon, 16, 16, 0, 0, DI_NORMAL);
        X := V.Left + 30;
      end;
      Font := 0;
      if F.SmallCaption then Which := ncSmallCaption else Which := ncCaption;
      if UINonClientFont(Which, LF) then
      begin
        LF.lfQuality := ANTIALIASED_QUALITY;
        Font := CreateFontIndirect(LF);
      end;
      if Font = 0 then Font := GetStockObject(DEFAULT_GUI_FONT);
      OldFont := SelectObject(B, Font);
      GetTextMetrics(B, TM);
      SetBkMode(B, TRANSPARENT);
      SetTextColor(B, ColorToRGB(Text));
      TR := Rect(X, (TH - TM.tmHeight) div 2, Right, TH);
      if TR.Right > TR.Left then
        DrawText(B, PChar(F.Caption), Length(F.Caption), TR, DT_LEFT or DT_TOP or DT_SINGLELINE or
          DT_NOPREFIX or DT_END_ELLIPSIS);
      SelectObject(B, OldFont);
      if Font <> GetStockObject(DEFAULT_GUI_FONT) then DeleteObject(Font);
      { Windows 11: rounded top corners, against what is behind the window }
      if SysRound and (TH > Radius) and (V.Right - V.Left > 2 * Radius) then
      begin
        NeedCorner;
        for J := 0 to Radius - 1 do
          for I := 0 to Radius - 1 do
          begin
            if CornerIn[J, I] = 16 then
              if CornerRing[J, I] = 0 then Continue;       // plain interior: as painted
            if CornerIn[J, I] = 0 then
              C := F.Back
            else
              C := Mix(F.Back, Mix(Title, Border, CornerRing[J, I] * 255 div CornerIn[J, I]),
                CornerIn[J, I] * 255 div 16);
            SetPixelV(B, V.Left + I, J, ColorToRGB(C));
            SetPixelV(B, V.Right - 1 - I, J, ColorToRGB(C));
          end;
      end;
      BitBlt(DC, 0, 0, F.Width, TH, B, 0, 0, SRCCOPY);
    finally
      Bmp.Free;
    end;
  finally
    RestoreDC(DC, Saved);
  end;
end;

end.
