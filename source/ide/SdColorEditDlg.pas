{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdColorEditDlg;

{ D7 Studio - a colour of the image editor: red, green, blue and - for
  an image of 32 bits - alpha, 0 ... 255; the same as hex (RRGGBB, AARRGGBB); the colour as it was
  and as it is now, side by side over a checkerboard; Windows' colour dialog for a colour of its
  own. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  Dialogs;

type
  TColorEditDlg = class(TForm)
    lblRed: TLabel;
    edRed: TEdit;
    udRed: TUpDown;
    lblGreen: TLabel;
    edGreen: TEdit;
    udGreen: TUpDown;
    lblBlue: TLabel;
    edBlue: TEdit;
    udBlue: TUpDown;
    lblAlpha: TLabel;
    edAlpha: TEdit;
    udAlpha: TUpDown;
    lblHex: TLabel;
    edHex: TEdit;
    pbSample: TPaintBox;
    btnMore: TButton;
    ColorDialog: TColorDialog;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ChannelChange(Sender: TObject);
    procedure edHexChange(Sender: TObject);
    procedure pbSamplePaint(Sender: TObject);
    procedure btnMoreClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FOld, FNew: Cardinal;          // $AARRGGBB
    FAlpha: Boolean;
    FSyncing: Boolean;
    procedure ShowColor(FromHex: Boolean);
  public
    class function Execute(AOwner: TComponent; const ACaption: string; var Color: Cardinal; Alpha: Boolean): Boolean;
  end;

var
  ColorEditDlg: TColorEditDlg;

implementation

uses
  SdUI, SdResImage;

{$R *.dfm}

procedure TColorEditDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the channels and the hex text say the same colour: the one not edited follows }
procedure TColorEditDlg.ShowColor(FromHex: Boolean);
begin
  FSyncing := True;
  try
    if FromHex then
    begin
      udRed.Position := FNew shr 16 and $FF;
      udGreen.Position := FNew shr 8 and $FF;
      udBlue.Position := FNew and $FF;
      udAlpha.Position := FNew shr 24;
    end
    else if FAlpha then edHex.Text := IntToHex(FNew, 8)
    else edHex.Text := IntToHex(FNew and $FFFFFF, 6);
  finally
    FSyncing := False;
  end;
  pbSample.Invalidate;
end;

function Channel(E: TEdit): Cardinal;
begin
  Result := Cardinal(StrToIntDef(Trim(E.Text), 0));
  if Result > 255 then Result := 255;
end;

procedure TColorEditDlg.ChannelChange(Sender: TObject);
var
  A: Cardinal;
begin
  if FSyncing then Exit;
  if FAlpha then A := Channel(edAlpha) else A := 255;
  FNew := A shl 24 or Channel(edRed) shl 16 or Channel(edGreen) shl 8 or Channel(edBlue);
  ShowColor(False);
end;

procedure TColorEditDlg.edHexChange(Sender: TObject);
var
  S: string;
  V: Int64;
begin
  if FSyncing then Exit;
  S := Trim(edHex.Text);
  if (S <> '') and (S[1] = '#') then Delete(S, 1, 1);
  if not (Length(S) in [6, 8]) or not TryStrToInt64('$' + S, V) then Exit;
  if Length(S) = 6 then V := V or $FF000000;
  if not FAlpha then V := V or $FF000000;
  FNew := Cardinal(V);
  ShowColor(True);
end;

{ the colour as it was (left) and now (right) over one checkerboard of 8 px: what its alpha shows }
procedure TColorEditDlg.pbSamplePaint(Sender: TObject);
var
  DC: HDC;
  R: TRect;
  Half: Integer;
begin
  DC := pbSample.Canvas.Handle;
  R := pbSample.ClientRect;
  Half := R.Left + (R.Right - R.Left) div 2;
  DrawChecked(DC, Rect(R.Left, R.Top, Half, R.Bottom), FOld, 8, R.TopLeft, False);
  DrawChecked(DC, Rect(Half, R.Top, R.Right, R.Bottom), FNew, 8, R.TopLeft, False);
  UIDrawBorder(DC, R);
end;

procedure TColorEditDlg.btnMoreClick(Sender: TObject);
begin
  ColorDialog.Color := SwapRB(FNew);
  if not ColorDialog.Execute then Exit;
  FNew := (FNew and $FF000000) or RGBOf(ColorDialog.Color);
  ShowColor(True);
  ShowColor(False);
end;

procedure TColorEditDlg.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

class function TColorEditDlg.Execute(AOwner: TComponent; const ACaption: string; var Color: Cardinal;
  Alpha: Boolean): Boolean;
var
  D: TColorEditDlg;
begin
  D := TColorEditDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    D.FAlpha := Alpha;
    if not Alpha then Color := Color or $FF000000;
    D.FOld := Color;
    D.FNew := Color;
    D.lblAlpha.Enabled := Alpha;
    D.edAlpha.Enabled := Alpha;
    D.udAlpha.Enabled := Alpha;
    D.ShowColor(True);
    D.ShowColor(False);
    Result := D.ShowModal = mrOk;
    if Result then Color := D.FNew;
  finally
    D.Free;
  end;
end;

end.
