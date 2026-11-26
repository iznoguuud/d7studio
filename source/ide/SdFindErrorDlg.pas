{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFindErrorDlg;

{ D7 Studio - Delphi 7's Find Error, Search | Find Error: the
  address of a run-time error ("Access violation at address 00452A1C"); D7 Studio shows the
  source line of the program that contains it. ExecuteHistoryCombo runs it and Browse Symbol
  (the same shape: one combo box with a history list). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TFindErrorDlg = class(TForm)
    xLabel1: TLabel;
    ErrorAddress: TComboBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; var Address: string): Boolean;
  end;

var
  FindErrorDlg: TFindErrorDlg;

{ a dialog with one history combo box: the text chosen is added to the history list History }
function ExecuteHistoryCombo(Dlg: TForm; Combo: TComboBox; const History: string; var Value: string): Boolean;

implementation

uses
  SdUI, SdSettings;

{$R *.dfm}

function ExecuteHistoryCombo(Dlg: TForm; Combo: TComboBox; const History: string; var Value: string): Boolean;
begin
  LoadHistory(Settings, History, Combo.Items);
  if Value <> '' then Combo.Text := Value
  else if Combo.Items.Count > 0 then Combo.Text := Combo.Items[0];
  Result := (Dlg.ShowModal = mrOk) and (Trim(Combo.Text) <> '');
  if Result then
  begin
    Value := Trim(Combo.Text);
    AddHistory(Settings, History, Value);
  end;
end;

procedure TFindErrorDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

class function TFindErrorDlg.Execute(AOwner: TComponent; var Address: string): Boolean;
var
  D: TFindErrorDlg;
begin
  D := TFindErrorDlg.Create(AOwner);
  try
    Result := ExecuteHistoryCombo(D, D.ErrorAddress, 'hlErrorAddress', Address);
  finally
    D.Free;
  end;
end;

end.
