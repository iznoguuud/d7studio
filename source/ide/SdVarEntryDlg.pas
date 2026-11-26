{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdVarEntryDlg;

{ D7 Studio - Delphi 7's variable entry: the name and the
  value of an environment variable (Environment Options | Environment Variables, Run |
  Parameters | Environment Block). }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TVarEntryDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    VarName: TEdit;
    VarValue: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    bOk: TButton;
    bCancel: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; const ACaption: string; var Name, Value: string): Boolean;
  end;

var
  VarEntryDlg: TVarEntryDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TVarEntryDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

class function TVarEntryDlg.Execute(AOwner: TComponent; const ACaption: string; var Name, Value: string): Boolean;
var
  D: TVarEntryDlg;
begin
  D := TVarEntryDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    D.VarName.Text := Name;
    D.VarValue.Text := Value;
    { a system variable that is overridden keeps its name }
    if (Name <> '') and (Pos('Override', ACaption) > 0) then D.ActiveControl := D.VarValue;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Name := D.VarName.Text;
      Value := D.VarValue.Text;
    end;
  finally
    D.Free;
  end;
end;

end.
