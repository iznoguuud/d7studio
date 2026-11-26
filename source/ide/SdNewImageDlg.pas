{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNewImageDlg;

{ D7 Studio - the size and the colours of new images: the Resources
  view's New Bitmap (width and height), New Icon and New Cursor and the image editor's New Image
  (the usual sizes of an icon as a set - 16, 20, 24, 32, 40, 48, 64, 96, 128, 256 - and another
  one, made at once; the editor's: empty, or the image shown scaled to them). An icon or a cursor is
  at most 256 x 256; one of 256 x 256 at 32 bits is kept as PNG, as Windows' own icons are. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  CheckLst, SdResImage;

type
  TNewImageDlg = class(TForm)
    lblSizes: TLabel;
    clbSizes: TCheckListBox;
    cbOther: TCheckBox;
    edOtherW: TEdit;
    udOtherW: TUpDown;
    lblBy: TLabel;
    edOtherH: TEdit;
    udOtherH: TUpDown;
    lblWidth: TLabel;
    edWidth: TEdit;
    udWidth: TUpDown;
    lblHeight: TLabel;
    edHeight: TEdit;
    udHeight: TUpDown;
    lblColors: TLabel;
    cbColors: TComboBox;
    rbEmpty: TRadioButton;
    rbScaled: TRadioButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FKind: TSdImageKind;
    FMax: Integer;
    procedure BitmapLayout;
  public
    { Sizes: the sizes chosen at first (an icon's: the ones checked) and then; Bits: the colours;
      OfferScale: the editor's New Image - Scale: the image shown, scaled }
    class function Execute(AOwner: TComponent; Kind: TSdImageKind; var Sizes: TSdSizes; var Bits: Integer;
      OfferScale: Boolean; var Scale: Boolean): Boolean;
  end;

var
  NewImageDlg: TNewImageDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

const
  ColorBits: array[0..4] of Integer = (1, 4, 8, 24, 32);
  IconSizes: array[0..9] of Integer = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256);

procedure TNewImageDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ a bitmap's: width and height in the place of the sizes, the colours under them, the dialog
  only as large as that - from the positions the layout for the UI font gave }
procedure TNewImageDlg.BitmapLayout;
var
  Step: Integer;
begin
  Step := edHeight.Top - edWidth.Top;
  lblColors.SetBounds(lblWidth.Left, lblHeight.Top + Step, lblColors.Width, lblColors.Height);
  cbColors.SetBounds(edWidth.Left, edHeight.Top + Step, cbColors.Width, cbColors.Height);
  { the band of the buttons under the colours: anchored to the dialog's sides and bottom, it follows
    the new size (its buttons keep to its right end) }
  ClientWidth := cbColors.Left + cbColors.Width + lblWidth.Left;
  ClientHeight := cbColors.Top + cbColors.Height + Step - edHeight.Height + 4 + pnlFooter.Height;
end;

procedure TNewImageDlg.btnOKClick(Sender: TObject);
var
  I: Integer;
  Any: Boolean;
begin
  if FKind = ikBitmap then
  begin
    if SizeValid(Self, edWidth, edHeight, FMax) then ModalResult := mrOk;
    Exit;
  end;
  Any := cbOther.Checked;
  for I := 0 to clbSizes.Items.Count - 1 do
    if clbSizes.Checked[I] then Any := True;
  if not DialogValid(Self, Any, 'Check at least one size.', clbSizes) then Exit;
  if cbOther.Checked and not SizeValid(Self, edOtherW, edOtherH, FMax) then Exit;
  ModalResult := mrOk;
end;

class function TNewImageDlg.Execute(AOwner: TComponent; Kind: TSdImageKind; var Sizes: TSdSizes;
  var Bits: Integer; OfferScale: Boolean; var Scale: Boolean): Boolean;
var
  D: TNewImageDlg;
  I, J, N: Integer;
  Icon, Listed: Boolean;
begin
  D := TNewImageDlg.Create(AOwner);
  try
    D.FKind := Kind;
    Icon := Kind <> ikBitmap;
    case Kind of
      ikBitmap: D.Caption := 'New Bitmap';
      ikIcon: if OfferScale then D.Caption := 'New Icon Images' else D.Caption := 'New Icon';
    else
      if OfferScale then D.Caption := 'New Cursor Images' else D.Caption := 'New Cursor';
    end;
    D.FMax := MaxImageSize(Kind);
    { the controls of the other kind go }
    D.lblSizes.Visible := Icon;
    D.clbSizes.Visible := Icon;
    D.cbOther.Visible := Icon;
    D.edOtherW.Visible := Icon;
    D.udOtherW.Visible := Icon;
    D.lblBy.Visible := Icon;
    D.edOtherH.Visible := Icon;
    D.udOtherH.Visible := Icon;
    D.lblWidth.Visible := not Icon;
    D.edWidth.Visible := not Icon;
    D.udWidth.Visible := not Icon;
    D.lblHeight.Visible := not Icon;
    D.edHeight.Visible := not Icon;
    D.udHeight.Visible := not Icon;
    D.rbEmpty.Visible := OfferScale;
    D.rbScaled.Visible := OfferScale;
    D.rbScaled.Checked := Scale;
    D.rbEmpty.Checked := not Scale;
    if Icon then D.ActiveControl := D.clbSizes
    else
    begin
      D.BitmapLayout;
      D.ActiveControl := D.edWidth;
    end;
    D.udWidth.Max := D.FMax;
    D.udHeight.Max := D.FMax;
    D.udOtherW.Max := D.FMax;
    D.udOtherH.Max := D.FMax;
    if Length(Sizes) > 0 then
    begin
      D.udWidth.Position := Sizes[0].X;
      D.udHeight.Position := Sizes[0].Y;
    end;
    { the sizes given: checked in the list, or the other size }
    D.clbSizes.Items.Clear;
    for I := 0 to High(IconSizes) do D.clbSizes.Items.Add(Format('%d x %d', [IconSizes[I], IconSizes[I]]));
    for J := 0 to High(Sizes) do
    begin
      Listed := False;
      for I := 0 to High(IconSizes) do
        if (Sizes[J].X = IconSizes[I]) and (Sizes[J].Y = IconSizes[I]) then
        begin
          D.clbSizes.Checked[I] := True;
          Listed := True;
        end;
      if not Listed then
      begin
        D.cbOther.Checked := True;
        D.udOtherW.Position := Sizes[J].X;
        D.udOtherH.Position := Sizes[J].Y;
      end;
    end;
    D.cbColors.Items.Clear;
    for I := 0 to High(ColorBits) do D.cbColors.Items.Add(BitCountText(ColorBits[I]));
    D.cbColors.ItemIndex := D.cbColors.Items.Count - 1;
    for I := 0 to High(ColorBits) do
      if ColorBits[I] = Bits then D.cbColors.ItemIndex := I;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    Bits := ColorBits[D.cbColors.ItemIndex];
    Scale := OfferScale and D.rbScaled.Checked;
    if not Icon then
    begin
      SetLength(Sizes, 1);
      Sizes[0] := Point(StrToInt(Trim(D.edWidth.Text)), StrToInt(Trim(D.edHeight.Text)));
      Exit;
    end;
    Sizes := nil;
    N := 0;
    for I := 0 to D.clbSizes.Items.Count - 1 do
      if D.clbSizes.Checked[I] then
      begin
        SetLength(Sizes, N + 1);
        Sizes[N] := Point(IconSizes[I], IconSizes[I]);
        Inc(N);
      end;
    if D.cbOther.Checked then
    begin
      SetLength(Sizes, N + 1);
      Sizes[N] := Point(StrToInt(Trim(D.edOtherW.Text)), StrToInt(Trim(D.edOtherH.Text)));
    end;
  finally
    D.Free;
  end;
end;

end.
