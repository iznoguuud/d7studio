{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdUpdateDlg;

{ D7 Studio - a newer release: its notes, and Update, which downloads its setup with a progress bar
  and checks it (SdUpdate.TSdUpdateDownload). The dialog ends with OK once the setup is checked:
  the main window then closes and D7Studio.dpr starts the setup. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, SdUpdate;

type
  TUpdateDlg = class(TForm)
    lblTitle: TLabel;
    lblInfo: TLabel;
    lblNotes: TLabel;
    mmNotes: TMemo;
    lblStatus: TLabel;
    pbDownload: TProgressBar;
    tmProgress: TTimer;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnReleasePage: TButton;
    btnUpdate: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnReleasePageClick(Sender: TObject);
    procedure btnUpdateClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure tmProgressTimer(Sender: TObject);
  private
    FRelease: TSdRelease;
    FDownload: TSdUpdateDownload;
    FSetupFile: string;
    procedure DownloadEnded(Accept: Boolean);
  public
    { Release is newer than the running D7 Studio; True with SetupFile once its setup is downloaded
      and checked }
    class function Execute(AOwner: TComponent; const Release: TSdRelease; out SetupFile: string): Boolean;
  end;

var
  UpdateDlg: TUpdateDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TUpdateDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TUpdateDlg.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  { a download that runs is cancelled first: the dialog closes when it has ended, and a setup it
    finished meanwhile is not taken }
  if FDownload <> nil then
  begin
    FDownload.Cancel;
    FDownload.WaitFor;
    DownloadEnded(False);
  end;
end;

procedure TUpdateDlg.btnReleasePageClick(Sender: TObject);
begin
  UIOpenUrl(FRelease.PageUrl);
end;

procedure TUpdateDlg.btnUpdateClick(Sender: TObject);
begin
  btnUpdate.Enabled := False;
  btnClose.Caption := 'Cancel';
  lblStatus.Caption := 'Downloading ' + FRelease.SetupName + '...';
  lblStatus.Visible := True;
  pbDownload.Position := 0;
  pbDownload.Visible := True;
  FDownload := TSdUpdateDownload.Create(FRelease);
  FDownload.Resume;
  tmProgress.Enabled := True;
end;

procedure TUpdateDlg.btnCloseClick(Sender: TObject);
begin
  if FDownload <> nil then
  begin
    lblStatus.Caption := 'Cancelling...';
    FDownload.Cancel;
  end
  else
    ModalResult := mrCancel;
end;

procedure TUpdateDlg.tmProgressTimer(Sender: TObject);
begin
  if FDownload = nil then Exit;
  if FDownload.Total > 0 then
  begin
    pbDownload.Max := FDownload.Total;
    pbDownload.Position := FDownload.Done;
    lblStatus.Caption := Format('Downloading %s: %d of %d KB', [FRelease.SetupName, FDownload.Done div 1024,
      FDownload.Total div 1024]);
  end;
  if FDownload.Finished then
  begin
    FDownload.WaitFor;
    DownloadEnded(True);
  end;
end;

{ the download thread has ended: the setup goes to the caller (Accept: not while the dialog closes),
  or the dialog is ready again }
procedure TUpdateDlg.DownloadEnded(Accept: Boolean);
var
  Error: string;
begin
  tmProgress.Enabled := False;
  Error := FDownload.Error;
  if Accept then FSetupFile := FDownload.SetupFile;
  FreeAndNil(FDownload);
  btnClose.Caption := 'Close';
  if not Accept then Exit;
  if FSetupFile <> '' then
  begin
    lblStatus.Caption := 'The setup is downloaded and checked.';
    ModalResult := mrOk;
    Exit;
  end;
  pbDownload.Visible := False;
  btnUpdate.Enabled := True;
  if Error = 'Cancelled.' then
    lblStatus.Caption := 'The download was cancelled.'
  else
  begin
    lblStatus.Caption := 'The download failed.';
    MessageBox(Handle, PChar('The update could not be downloaded.'#13#10#13#10 + Error), 'D7 Studio',
      MB_OK or MB_ICONERROR);
  end;
end;

class function TUpdateDlg.Execute(AOwner: TComponent; const Release: TSdRelease; out SetupFile: string): Boolean;
var
  D: TUpdateDlg;
begin
  SetupFile := '';
  D := TUpdateDlg.Create(AOwner);
  try
    D.FRelease := Release;
    D.lblTitle.Caption := Format('D7 Studio %s is available.', [Release.Version]);
    D.lblInfo.Caption := Format('You have version %s. Update downloads the setup, closes D7 Studio and ' +
      'starts the setup, which updates D7 Studio and keeps its settings.', [CurrentVersion]);
    D.mmNotes.Lines.Text := MarkdownToText(Release.Notes);
    D.btnReleasePage.Enabled := UIIsUrl(Release.PageUrl);
    Result := D.ShowModal = mrOk;
    if Result then SetupFile := D.FSetupFile;
  finally
    D.Free;
  end;
end;

end.
