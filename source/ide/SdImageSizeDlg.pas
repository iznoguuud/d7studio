{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdImageSizeDlg;

{ D7 Studio - the image editor's Resize: the image's new width and
  height (its proportions kept when Keep the proportions is checked) and how it gets there: scaled
  smoothly, scaled by its pixels (each the nearest one's: pixel art), or a canvas of the new size
  with the image at its top left or in its middle. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  SdResImage;

type
  TImageSizeDlg = class(TForm)
    lblWidth: TLabel;
    edWidth: TEdit;
    udWidth: TUpDown;
    lblHeight: TLabel;
    edHeight: TEdit;
    udHeight: TUpDown;
    cbKeep: TCheckBox;
    gbMode: TGroupBox;
    rbSmooth: TRadioButton;
    rbPixels: TRadioButton;
    rbCanvas: TRadioButton;
    rbCanvasCentre: TRadioButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure edWidthChange(Sender: TObject);
    procedure edHeightChange(Sender: TObject);
  private
    FW0, FH0, FMax: Integer;
    FSyncing: Boolean;
  public
    { Mode: 0 scaled smoothly, 1 scaled by pixels, 2 the canvas at the top left, 3 the canvas
      centred }
    class function Execute(AOwner: TComponent; Kind: TSdImageKind; var W, H, Mode: Integer): Boolean;
  end;

var
  ImageSizeDlg: TImageSizeDlg;

implementation

uses
  Math, SdUI, SdDialogs;

{$R *.dfm}

procedure TImageSizeDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the other side follows while the proportions are kept }
procedure TImageSizeDlg.edWidthChange(Sender: TObject);
var
  W: Integer;
begin
  if FSyncing or not cbKeep.Checked or (FW0 = 0) then Exit;
  W := StrToIntDef(Trim(edWidth.Text), 0);
  if W <= 0 then Exit;
  FSyncing := True;
  try
    udHeight.Position := Max(1, Round(W * FH0 / FW0));
  finally
    FSyncing := False;
  end;
end;

procedure TImageSizeDlg.edHeightChange(Sender: TObject);
var
  H: Integer;
begin
  if FSyncing or not cbKeep.Checked or (FH0 = 0) then Exit;
  H := StrToIntDef(Trim(edHeight.Text), 0);
  if H <= 0 then Exit;
  FSyncing := True;
  try
    udWidth.Position := Max(1, Round(H * FW0 / FH0));
  finally
    FSyncing := False;
  end;
end;

procedure TImageSizeDlg.btnOKClick(Sender: TObject);
begin
  if SizeValid(Self, edWidth, edHeight, FMax) then ModalResult := mrOk;
end;

class function TImageSizeDlg.Execute(AOwner: TComponent; Kind: TSdImageKind; var W, H, Mode: Integer): Boolean;
var
  D: TImageSizeDlg;
begin
  D := TImageSizeDlg.Create(AOwner);
  try
    D.FMax := MaxImageSize(Kind);
    D.FW0 := W;
    D.FH0 := H;
    D.FSyncing := True;
    try
      D.udWidth.Max := D.FMax;
      D.udHeight.Max := D.FMax;
      D.udWidth.Position := W;
      D.udHeight.Position := H;
    finally
      D.FSyncing := False;
    end;
    case Mode of
      1: D.rbPixels.Checked := True;
      2: D.rbCanvas.Checked := True;
      3: D.rbCanvasCentre.Checked := True;
    else
      D.rbSmooth.Checked := True;
    end;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    W := StrToInt(Trim(D.edWidth.Text));
    H := StrToInt(Trim(D.edHeight.Text));
    if D.rbPixels.Checked then Mode := 1
    else if D.rbCanvas.Checked then Mode := 2
    else if D.rbCanvasCentre.Checked then Mode := 3
    else Mode := 0;
  finally
    D.Free;
  end;
end;

end.
