{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAlignDlg;

{ D7 Studio - Delphi 7's Alignment dialog, Edit | Align: how the
  selected controls are aligned horizontally and vertically. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TAlignDlg = class(TForm)
    xGroupBox1: TGroupBox;
    hNoChange: TRadioButton;
    hLeftSides: TRadioButton;
    hCenters: TRadioButton;
    hRightSides: TRadioButton;
    hSpaceEqual: TRadioButton;
    hCenterInWindow: TRadioButton;
    xGroupBox2: TGroupBox;
    vNoChange: TRadioButton;
    vTops: TRadioButton;
    vCenters: TRadioButton;
    vBottoms: TRadioButton;
    vSpaceEqual: TRadioButton;
    vCenterInWindow: TRadioButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
  public
    { H, V: 0 no change, 1 left sides / tops, 2 centers, 3 right sides / bottoms, 4 space
      equally, 5 center in window }
    class function Execute(AOwner: TComponent; var H, V: Integer): Boolean;
  end;

var
  AlignDlg: TAlignDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TAlignDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

class function TAlignDlg.Execute(AOwner: TComponent; var H, V: Integer): Boolean;
var
  D: TAlignDlg;
  HB, VB: array[0..5] of TRadioButton;
  I: Integer;
begin
  D := TAlignDlg.Create(AOwner);
  try
    HB[0] := D.hNoChange; HB[1] := D.hLeftSides; HB[2] := D.hCenters;
    HB[3] := D.hRightSides; HB[4] := D.hSpaceEqual; HB[5] := D.hCenterInWindow;
    VB[0] := D.vNoChange; VB[1] := D.vTops; VB[2] := D.vCenters;
    VB[3] := D.vBottoms; VB[4] := D.vSpaceEqual; VB[5] := D.vCenterInWindow;
    if (H < 0) or (H > 5) then H := 0;
    if (V < 0) or (V > 5) then V := 0;
    HB[H].Checked := True;
    VB[V].Checked := True;
    Result := D.ShowModal = mrOk;
    if Result then
      for I := 0 to 5 do
      begin
        if HB[I].Checked then H := I;
        if VB[I].Checked then V := I;
      end;
  finally
    D.Free;
  end;
end;

end.
