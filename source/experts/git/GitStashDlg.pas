{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitStashDlg;

{ Stash Changes: a message for the stash (it may be left empty) and whether the untracked files go
  into it too. In the look of a task dialog, as the AI harness's dialogs (GitUI). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls;

type
  TGitStashDialog = class(TForm)
    MessageLabel: TLabel;
    MessageEdit: TEdit;
    UntrackedBox: TCheckBox;
    Footer: TPanel;
    FooterLine: TShape;
    OKButton: TButton;
    CancelButton: TButton;
  public
    { Msg: the stash's message (UTF-8) }
    class function Execute(out Msg: string; out Untracked: Boolean): Boolean;
  end;

implementation

{$R *.dfm}

uses
  GitText, GitUI;

class function TGitStashDialog.Execute(out Msg: string; out Untracked: Boolean): Boolean;
var
  D: TGitStashDialog;
begin
  Msg := '';
  Untracked := False;
  D := TGitStashDialog.Create(Application);
  try
    KitPrepareDialog(D);
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Msg := IdeToUtf8(Trim(D.MessageEdit.Text));
      Untracked := D.UntrackedBox.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
