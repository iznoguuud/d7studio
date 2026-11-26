{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdScaleDlg;

{ D7 Studio - Delphi 7's Scale dialog, Edit | Scale: the form and
  its controls scaled by a factor in percent (25 .. 400). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TScaleDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    Edit: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FPercent: Integer;
  public
    class function Execute(AOwner: TComponent; var Percent: Integer): Boolean;
  end;

var
  ScaleDlg: TScaleDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TScaleDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TScaleDlg.OKButtonClick(Sender: TObject);
begin
  if DialogValid(Self, CheckNumber(Edit, 25, 400, 'The scaling factor must be between 25 and 400 percent.', FPercent),
    Edit) then ModalResult := mrOk;
end;

class function TScaleDlg.Execute(AOwner: TComponent; var Percent: Integer): Boolean;
var
  D: TScaleDlg;
begin
  D := TScaleDlg.Create(AOwner);
  try
    D.Edit.Text := IntToStr(Percent);
    Result := D.ShowModal = mrOk;
    if Result then Percent := D.FPercent;
  finally
    D.Free;
  end;
end;

end.
