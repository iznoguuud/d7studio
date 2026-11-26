{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitBranchDlg;

{ New Branch: the branch's name, what it starts from - the current HEAD, a commit, another branch -
  and whether to switch to it. In the look of a task dialog, as the AI harness's dialogs: the content
  on clWindow, the buttons in a footer below a flat line, the IDE's font, flat boxes (GitUI). The
  name is checked as git checks it (git check-ref-format --branch) and against the branches there
  are. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls;

type
  TGitBranchDialog = class(TForm)
    NameLabel: TLabel;
    NameEdit: TEdit;
    StartLabel: TLabel;
    StartCombo: TComboBox;
    SwitchBox: TCheckBox;
    Footer: TPanel;
    FooterLine: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure OKButtonClick(Sender: TObject);
  private
    FStarts: TStringList;      // what each of StartCombo's entries names (UTF-8; '' the current HEAD)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { StartAt: the commit to start from ('' the current HEAD); Name and StartPoint chosen (UTF-8) }
    class function Execute(const StartAt: string; out Name, StartPoint: string; out SwitchTo: Boolean): Boolean;
  end;

{ New Branch from StartAt ('' the current HEAD): the dialog, the files saved when it switches to the
  branch, then the branch made }
procedure GitNewBranch(const StartAt: string);

implementation

{$R *.dfm}

uses
  GitText, GitUI, GitCore, GitHost, GitViews;

procedure GitNewBranch(const StartAt: string);
var
  Name, Start: string;
  SwitchTo: Boolean;
begin
  if not TGitBranchDialog.Execute(StartAt, Name, Start, SwitchTo) then Exit;
  if SwitchTo and not GitHostInstance.SaveFiles(GitSwitchWhy) then Exit;
  GitHostInstance.CreateBranch(Name, Start, SwitchTo);
end;

constructor TGitBranchDialog.Create(AOwner: TComponent);
begin
  inherited;
  FStarts := TStringList.Create;
end;

destructor TGitBranchDialog.Destroy;
begin
  FStarts.Free;
  inherited;
end;

class function TGitBranchDialog.Execute(const StartAt: string; out Name, StartPoint: string;
  out SwitchTo: Boolean): Boolean;
var
  D: TGitBranchDialog;
  H: TGitHost;
  I: Integer;
  B: TGitBranch;
begin
  Name := '';
  StartPoint := '';
  SwitchTo := False;
  H := GitHostInstance;
  D := TGitBranchDialog.Create(Application);
  try
    KitPrepareDialog(D);
    if StartAt <> '' then D.StartCombo.Items.Add('Commit ' + Copy(StartAt, 1, 7))
    else if H.Status.Branch <> '' then D.StartCombo.Items.Add('The current branch, ' + Utf8ToIde(H.Status.Branch))
    else D.StartCombo.Items.Add('The current commit');
    D.FStarts.Add(StartAt);
    for I := 0 to H.Branches.Count - 1 do
    begin
      B := TGitBranch(H.Branches[I]);
      if B.Current then Continue;
      D.StartCombo.Items.Add(Utf8ToIde(B.Name));
      D.FStarts.Add(B.Name);
    end;
    D.StartCombo.ItemIndex := 0;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Name := IdeToUtf8(Trim(D.NameEdit.Text));
      StartPoint := D.FStarts[D.StartCombo.ItemIndex];
      SwitchTo := D.SwitchBox.Checked;
    end;
  finally
    D.Free;
  end;
end;

procedure TGitBranchDialog.OKButtonClick(Sender: TObject);
var
  H: TGitHost;
  Name: string;
begin
  H := GitHostInstance;
  Name := IdeToUtf8(Trim(NameEdit.Text));
  if Name = '' then
  begin
    NameEdit.SetFocus;
    raise Exception.Create('Type the name of the branch.');
  end;
  if H.FindBranch(Name, False) <> nil then
  begin
    NameEdit.SetFocus;
    raise Exception.CreateFmt('There is a branch %s already.', [Utf8ToIde(Name)]);
  end;
  if (H.Repo <> nil) and not H.Repo.ValidBranchName(Name) then
  begin
    NameEdit.SetFocus;
    raise Exception.CreateFmt('%s cannot be the name of a branch: no spaces, no ".." and none of ~ ^ : ? * [ \.',
      [Utf8ToIde(Name)]);
  end;
  ModalResult := mrOk;
end;

end.
