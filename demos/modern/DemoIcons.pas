{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DemoIcons;

{ The demo's icons: Windows' stock icons (ShellAPI.SHGetStockIconInfo), which Windows draws for each
  size - SHDefExtractIcon gives one at any size, made from the nearest one Windows has.

  How an image list gets them shows what the modernized ImgList adds:
  - AddIcons(List, [16, 20, 24, 32]) gives a list the icons drawn at four sizes. At 100, 125, 150
    and 200 % it shows the size drawn for that scale; at any other it shrinks the next larger size.
  - AddIcons(List, [16]) gives it only the 16 x 16 ones, so above 100 % it must enlarge them, which
    blurs them.
  The Display page shows both lists side by side: compare them at 125 % or 150 %. }

interface

uses
  Windows, ShellAPI, Classes, Graphics, ImgList;

const
  { the icons, in the order of the image lists }
  icoRefresh = 0;
  icoFloat = 1;
  icoClear = 2;
  icoDisplay = 3;       // the five areas of the sidebar follow, in its order
  icoUnicode = 4;
  icoDialogs = 5;
  icoLook = 6;
  icoSystem = 7;

{ Gives List the icons drawn at each of Sizes (in pixels; the first one is the list's own size). }
procedure AddIcons(List: TCustomImageList; const Sizes: array of Integer);

implementation

const
  { each icon's stock icon, in the order above }
  StockIcons: array[icoRefresh..icoSystem] of Integer = (SIID_FIND, SIID_APPLICATION, SIID_DELETE,
    SIID_DESKTOPPC, SIID_DOCASSOC, SIID_INFO, SIID_IMAGEFILES, SIID_SOFTWARE);

{ All the icons side by side at Size x Size pixels: a 32-bit bitmap, transparent around them. }
function MakeStrip(Size: Integer): TBitmap;
var
  I: Integer;
  Info: TSHStockIconInfo;
  Icon: HICON;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.Width := Size * Length(StockIcons);
  Result.Height := Size;
  Result.Canvas.Brush.Color := clBlack;    // every byte 0: transparent
  Result.Canvas.FillRect(Rect(0, 0, Result.Width, Size));
  for I := 0 to High(StockIcons) do
  begin
    { where Windows keeps the stock icon, then the icon from there at this size }
    FillChar(Info, SizeOf(Info), 0);
    Info.cbSize := SizeOf(Info);
    Icon := 0;
    if Succeeded(SHGetStockIconInfo(StockIcons[I], SHGSI_ICONLOCATION, Info)) and
      Succeeded(SHDefExtractIconW(Info.szPath, Info.iIcon, 0, @Icon, nil, Size)) and (Icon <> 0) then
    begin
      DrawIconEx(Result.Canvas.Handle, I * Size, 0, Icon, Size, Size, 0, 0, DI_NORMAL);
      DestroyIcon(Icon);
    end;
  end;
end;

procedure AddIcons(List: TCustomImageList; const Sizes: array of Integer);
var
  I: Integer;
  Strip: TBitmap;
begin
  for I := Low(Sizes) to High(Sizes) do
  begin
    Strip := MakeStrip(Sizes[I]);
    try
      { Delphi 7's image list keeps no transparency of a 32-bit bitmap, so the first strip only makes
        its images; every strip, the first too, is then given as a set of the same images at that
        size, with its transparency (ImgList.AddImageListResolution) }
      if List.Count = 0 then
        List.Add(Strip, nil);
      AddImageListResolution(List, Strip);
    finally
      Strip.Free;
    end;
  end;
end;

end.