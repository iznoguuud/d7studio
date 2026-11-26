{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSizeDlg;

{ D7 Studio - Delphi 7's Size dialog, Edit | Size: the width and
  the height of the selected controls - unchanged, the smallest, the largest or a value. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TSizeDlg = class(TForm)
    xGroupBox1: TGroupBox;
    hNoChange: TRadioButton;
    hShrink: TRadioButton;
    hGrow: TRadioButton;
    hAbsolute: TRadioButton;
    hWidth: TEdit;
    xGroupBox2: TGroupBox;
    vNoChange: TRadioButton;
    vShrink: TRadioButton;
    vGrow: TRadioButton;
    vAbsolute: TRadioButton;
    vHeight: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure ValueChange(Sender: TObject);
  private
  public
    { modes: 0 no change, 1 shrink to smallest, 2 grow to largest, 3 the value W / H }
    class function Execute(AOwner: TComponent; var HMode, VMode, W, H: Integer): Boolean;
  end;

var
  SizeDlg: TSizeDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TSizeDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ typing a value chooses it, as in Delphi }
procedure TSizeDlg.ValueChange(Sender: TObject);
begin
  if (Sender = hWidth) and hWidth.Focused then hAbsolute.Checked := True;
  if (Sender = vHeight) and vHeight.Focused then vAbsolute.Checked := True;
end;

{ a value chosen must be a number }
procedure TSizeDlg.OKButtonClick(Sender: TObject);
const
  Msg = 'Please enter a valid number.';
begin
  if DialogValid(Self, not hAbsolute.Checked or (StrToIntDef(Trim(hWidth.Text), -1) >= 0), Msg, hWidth) and
    DialogValid(Self, not vAbsolute.Checked or (StrToIntDef(Trim(vHeight.Text), -1) >= 0), Msg, vHeight) then
    ModalResult := mrOk;
end;

class function TSizeDlg.Execute(AOwner: TComponent; var HMode, VMode, W, H: Integer): Boolean;
var
  D: TSizeDlg;
  HB, VB: array[0..3] of TRadioButton;
  I: Integer;
begin
  D := TSizeDlg.Create(AOwner);
  try
    HB[0] := D.hNoChange; HB[1] := D.hShrink; HB[2] := D.hGrow; HB[3] := D.hAbsolute;
    VB[0] := D.vNoChange; VB[1] := D.vShrink; VB[2] := D.vGrow; VB[3] := D.vAbsolute;
    if (HMode < 0) or (HMode > 3) then HMode := 0;
    if (VMode < 0) or (VMode > 3) then VMode := 0;
    HB[HMode].Checked := True;
    VB[VMode].Checked := True;
    D.hWidth.Text := IntToStr(W);
    D.vHeight.Text := IntToStr(H);
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    for I := 0 to 3 do
    begin
      if HB[I].Checked then HMode := I;
      if VB[I].Checked then VMode := I;
    end;
    W := StrToIntDef(Trim(D.hWidth.Text), -1);
    H := StrToIntDef(Trim(D.vHeight.Text), -1);
  finally
    D.Free;
  end;
end;

end.
