{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdReplaceDlg;

{ D7 Studio - the Replace Text dialog (Search | Replace): the Find Text dialog with the
  replacement text, "Prompt on replace" and Replace All, as in Delphi 7. }

interface

uses
  Classes, Forms, StdCtrls, ExtCtrls, SdDialogs;

type
  TReplaceDlg = class(TForm)
    lblFind: TLabel;
    lblReplace: TLabel;
    cbFind: TComboBox;
    cbReplace: TComboBox;
    gbOptions: TGroupBox;
    chkCase: TCheckBox;
    chkWholeWord: TCheckBox;
    chkRegExp: TCheckBox;
    chkPrompt: TCheckBox;
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
    btnReplaceAll: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  public
    { Opts.ReplaceAll tells which button closed the dialog }
    class function Execute(AOwner: TComponent; var Opts: TFindOptionsRec): Boolean;
  end;

var
  ReplaceDlg: TReplaceDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TReplaceDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the Find dialog's controls, the replacement text and "Prompt on replace" are filled and read by
  SdDialogs.RunFindDialog }
class function TReplaceDlg.Execute(AOwner: TComponent; var Opts: TFindOptionsRec): Boolean;
begin
  Result := RunFindDialog(TReplaceDlg.Create(AOwner), Opts);
end;

end.
