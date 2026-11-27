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
  The Watch List (SdWatchViewFrame, 16 x 16), migrate.exe's dialog Migrate from Delphi 7 (MigDlg,
  20 x 16) and the refactorings' choices (SdRefactorListDlg) use them; the boxes of a tree of
  groups follow each other through SetCheck / ToggleCheck. }

interface

uses
  ImgList, ComCtrls;

const
  CheckBoxSize = 13;         // the check box in a state image

  { the state images, a node's StateIndex }
  ciNone = 0;
  ciUnchecked = 1;
  ciChecked = 2;
  ciMixed = 3;

{ Images made the four state images, in cells of its Width x Height }
procedure MakeCheckImages(Images: TCustomImageList);

{ Node's box checked or not, and the nodes below it the same; the boxes above it checked when all
  their nodes are, unchecked when none is, mixed when some are }
procedure SetCheck(Node: TTreeNode; Checked: Boolean);
{ Node's box the other way: checked when it is not (mixed counts as not) }
procedure ToggleCheck(Node: TTreeNode);

implementation

uses
  Windows, Classes, Graphics, Themes;

procedure MakeCheckImages(Images: TCustomImageList);
const
  Parts: array[ciUnchecked..ciMixed] of TThemedButton = (tbCheckBoxUncheckedNormal,
    tbCheckBoxCheckedNormal, tbCheckBoxMixedNormal);
var
  B, Mask: TBitmap;
  I, M: Integer;
  Box: TRect;
begin
  Images.Clear;
  B := TBitmap.Create;
  Mask := TBitmap.Create;
  try
    B.Width := Images.Width;
    B.Height := Images.Height;
    { the box centred vertically, as far from the left edge as from the top }
    M := (Images.Height - CheckBoxSize) div 2;
    Box := Rect(M, M, M + CheckBoxSize, M + CheckBoxSize);
    { only the box is opaque: the tree draws its state image over the selection, whose frame starts
      inside the cell's padding (the Explorer style), and an opaque padding hid the frame's left edge }
    Mask.Monochrome := True;
    Mask.Width := Images.Width;
    Mask.Height := Images.Height;
    for I := ciNone to ciMixed do
    begin
      B.Canvas.Brush.Color := clWindow;
      B.Canvas.FillRect(Rect(0, 0, B.Width, B.Height));
      Mask.Canvas.Brush.Color := clWhite;            // transparent
      Mask.Canvas.FillRect(Rect(0, 0, Mask.Width, Mask.Height));
      if I > ciNone then
      begin
        ThemeServices.DrawElement(B.Canvas.Handle, ThemeServices.GetElementDetails(Parts[I]), Box);
        Mask.Canvas.Brush.Color := clBlack;          // opaque
        Mask.Canvas.FillRect(Box);
      end;
      Images.Add(B, Mask);
    end;
  finally
    Mask.Free;
    B.Free;
  end;
end;

procedure SetCheck(Node: TTreeNode; Checked: Boolean);
var
  State, I: Integer;
  Next: TTreeNode;
  All, None: Boolean;
begin
  if Node = nil then Exit;
  if Checked then State := ciChecked else State := ciUnchecked;
  { Node and the nodes below it: the ones that follow it with a deeper level }
  Node.StateIndex := State;
  Next := Node.GetNext;
  while (Next <> nil) and (Next.Level > Node.Level) do
  begin
    Next.StateIndex := State;
    Next := Next.GetNext;
  end;
  Node := Node.Parent;
  while Node <> nil do
  begin
    All := True;
    None := True;
    for I := 0 to Node.Count - 1 do
    begin
      if Node[I].StateIndex <> ciChecked then All := False;
      if Node[I].StateIndex <> ciUnchecked then None := False;
    end;
    if All then Node.StateIndex := ciChecked
    else if None then Node.StateIndex := ciUnchecked
    else Node.StateIndex := ciMixed;
    Node := Node.Parent;
  end;
end;

procedure ToggleCheck(Node: TTreeNode);
begin
  if Node <> nil then SetCheck(Node, Node.StateIndex <> ciChecked);
end;

end.
