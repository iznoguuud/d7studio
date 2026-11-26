{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFindInFilesDlg;

{ D7 Studio - the Find in Files dialog (Search | Find in Files). }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, SdDialogs;

type
  TFindInFilesDlg = class(TForm)
    lblFind: TLabel;
    lblDirectory: TLabel;
    lblMask: TLabel;
    edFind: TEdit;
    gbOptions: TGroupBox;
    chkCase: TCheckBox;
    chkWholeWord: TCheckBox;
    chkRecurse: TCheckBox;
    gbWhere: TGroupBox;
    rbProject: TRadioButton;
    rbOpenFiles: TRadioButton;
    rbDirectories: TRadioButton;
    edDirectory: TEdit;
    edMask: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; var Opts: TFindInFilesRec): Boolean;
  end;

var
  FindInFilesDlg: TFindInFilesDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TFindInFilesDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

class function TFindInFilesDlg.Execute(AOwner: TComponent; var Opts: TFindInFilesRec): Boolean;
var
  D: TFindInFilesDlg;
begin
  D := TFindInFilesDlg.Create(AOwner);
  try
    D.edFind.Text := Opts.FindText;
    D.chkCase.Checked := Opts.MatchCase;
    D.chkWholeWord.Checked := Opts.WholeWord;
    D.chkRecurse.Checked := Opts.Recurse;
    case Opts.Where of
      1: D.rbOpenFiles.Checked := True;
      2: D.rbDirectories.Checked := True;
    else
      D.rbProject.Checked := True;
    end;
    D.edDirectory.Text := Opts.Directory;
    D.edMask.Text := Opts.Mask;
    Result := (D.ShowModal = mrOk) and (D.edFind.Text <> '');
    if Result then
    begin
      Opts.FindText := D.edFind.Text;
      Opts.MatchCase := D.chkCase.Checked;
      Opts.WholeWord := D.chkWholeWord.Checked;
      Opts.Recurse := D.chkRecurse.Checked;
      if D.rbDirectories.Checked then Opts.Where := 2
      else if D.rbOpenFiles.Checked then Opts.Where := 1
      else Opts.Where := 0;
      Opts.Directory := D.edDirectory.Text;
      Opts.Mask := D.edMask.Text;
    end;
  finally
    D.Free;
  end;
end;

end.
