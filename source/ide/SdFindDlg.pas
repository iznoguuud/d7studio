{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFindDlg;

{ D7 Studio - the Find Text dialog (Search | Find). }

interface

uses
  Classes, Forms, StdCtrls, ExtCtrls, SdDialogs;

type
  TFindDlg = class(TForm)
    lblFind: TLabel;
    cbFind: TComboBox;
    gbOptions: TGroupBox;
    chkCase: TCheckBox;
    chkWholeWord: TCheckBox;
    chkRegExp: TCheckBox;
    gbDirection: TGroupBox;
    rbForward: TRadioButton;
    rbBackward: TRadioButton;
    gbScope: TGroupBox;
    rbGlobal: TRadioButton;
    rbSelected: TRadioButton;
    gbOrigin: TGroupBox;
    rbFromCursor: TRadioButton;
    rbEntireScope: TRadioButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; var Opts: TFindOptionsRec): Boolean;
  end;

var
  FindDlg: TFindDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TFindDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the controls it shares with the Replace dialog are filled and read by SdDialogs.RunFindDialog }
class function TFindDlg.Execute(AOwner: TComponent; var Opts: TFindOptionsRec): Boolean;
begin
  Result := RunFindDialog(TFindDlg.Create(AOwner), Opts);
end;

end.
