{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitSettingsDlg;

{ The Git expert's settings: where git.exe is (empty: found on the PATH or in Git for Windows' folder;
  the one found, with its version, is named below the box) and whether the views read the status
  again when files of the work tree change. In the look of a task dialog, as the AI harness's
  settings: sections with headings and flat rules on clWindow, the buttons in a footer below a flat
  line (GitUI). The values are under the IDE's registry key, in Git (GitHost). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Dialogs;

type
  TGitSettingsDialog = class(TForm)
    GitHeading: TLabel;
    GitRule: TShape;
    PathLabel: TLabel;
    PathEdit: TEdit;
    BrowseButton: TButton;
    FoundLabel: TLabel;
    RefreshHeading: TLabel;
    RefreshRule: TShape;
    AutoRefreshBox: TCheckBox;
    Footer: TPanel;
    FooterLine: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    OpenDialog: TOpenDialog;
    procedure BrowseButtonClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure PathEditExit(Sender: TObject);
  private
    procedure ShowFound;
  public
    { True when the settings were saved }
    class function Execute: Boolean;
  end;

implementation

{$R *.dfm}

uses
  GitText, GitUI, GitCore, GitHost;

class function TGitSettingsDialog.Execute: Boolean;
var
  D: TGitSettingsDialog;
  H: TGitHost;
begin
  H := GitHostInstance;
  D := TGitSettingsDialog.Create(Application);
  try
    KitPrepareDialog(D);
    KitSection(D.GitHeading, D.GitRule);
    KitSection(D.RefreshHeading, D.RefreshRule);
    D.PathEdit.Text := H.ReadSetting('GitPath', '');
    D.AutoRefreshBox.Checked := H.ReadSetting('AutoRefresh', '1') <> '0';
    D.ShowFound;
    Result := D.ShowModal = mrOk;
  finally
    D.Free;
  end;
end;

{ the git.exe the box names (or the one found without it) and its version }
procedure TGitSettingsDialog.ShowFound;
var
  Exe, Typed: WideString;
  G: TGit;
  V: string;
begin
  Typed := CodePageToWide(Trim(PathEdit.Text), CP_ACP);
  if (Typed <> '') and not FileExistsW(Typed) then
  begin
    FoundLabel.Caption := Format('There is no file %s.', [Trim(PathEdit.Text)]);
    Exit;
  end;
  Exe := FindGitExe(Typed);
  if Exe = '' then
  begin
    FoundLabel.Caption := 'git.exe was not found: install Git for Windows, or name git.exe above.';
    Exit;
  end;
  G := TGit.Create(Exe);
  try
    V := G.Version;
  finally
    G.Free;
  end;
  FoundLabel.Caption := Format('Uses %s%s%s', [WideToCodePage(Exe, CP_ACP), #13#10, V]);
end;

procedure TGitSettingsDialog.PathEditExit(Sender: TObject);
begin
  ShowFound;
end;

procedure TGitSettingsDialog.BrowseButtonClick(Sender: TObject);
begin
  OpenDialog.FileName := Trim(PathEdit.Text);
  if not OpenDialog.Execute then Exit;
  PathEdit.Text := OpenDialog.FileName;
  ShowFound;
end;

procedure TGitSettingsDialog.OKButtonClick(Sender: TObject);
var
  H: TGitHost;
  P: string;
begin
  P := Trim(PathEdit.Text);
  if (P <> '') and not FileExistsW(CodePageToWide(P, CP_ACP)) then
  begin
    PathEdit.SetFocus;
    raise Exception.CreateFmt('There is no file %s. Leave the box empty to find git.exe on the PATH.', [P]);
  end;
  H := GitHostInstance;
  H.WriteSetting('GitPath', P);
  if AutoRefreshBox.Checked then H.WriteSetting('AutoRefresh', '1') else H.WriteSetting('AutoRefresh', '0');
  ModalResult := mrOk;
end;

end.
