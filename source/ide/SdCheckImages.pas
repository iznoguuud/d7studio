{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCheckImages;

{ D7 Studio - the state images of a tree view with check boxes, drawn by the visual style: none
  (ciNone), unchecked, checked and mixed (a node of which only some children are checked). The cell
  is the image list's Width x Height at 96 DPI (the modernized VCL resamples the image lists of a
  form for its monitor), the box sits at its left. A cell wider than high keeps the box clear of
  the selection, which the Explorer style of the tree starts a few pixels before the node's text.
  The Watch List (SdWatchViewFrame, 16 x 16) and migrate.exe's dialog Migrate from Delphi 7
  (MigDlg, 20 x 16) use them. }

interface

uses
  ImgList;

const
  CheckBoxSize = 13;         // the check box in a state image

  { the state images, a node's StateIndex }
  ciNone = 0;
  ciUnchecked = 1;
  ciChecked = 2;
  ciMixed = 3;

{ Images made the four state images, in cells of its Width x Height }
procedure MakeCheckImages(Images: TCustomImageList);

implementation

uses
  Classes, Graphics, Themes;

procedure MakeCheckImages(Images: TCustomImageList);
const
  Parts: array[ciUnchecked..ciMixed] of TThemedButton = (tbCheckBoxUncheckedNormal,
    tbCheckBoxCheckedNormal, tbCheckBoxMixedNormal);
var
  B: TBitmap;
  I, M: Integer;
begin
  Images.Clear;
  B := TBitmap.Create;
  try
    B.Width := Images.Width;
    B.Height := Images.Height;
    { the box centred vertically, as far from the left edge as from the top }
    M := (Images.Height - CheckBoxSize) div 2;
    for I := ciNone to ciMixed do
    begin
      B.Canvas.Brush.Color := clWindow;
      B.Canvas.FillRect(Rect(0, 0, B.Width, B.Height));
      if I > ciNone then
        ThemeServices.DrawElement(B.Canvas.Handle, ThemeServices.GetElementDetails(Parts[I]),
          Rect(M, M, M + CheckBoxSize, M + CheckBoxSize));
      Images.Add(B, nil);
    end;
  finally
    B.Free;
  end;
end;

end.
