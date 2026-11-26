{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompInfoDlg;

{ D7 Studio - Delphi 7's Information dialog, Project |
  Information for <project>: what the last compile reported (lines, code and data size), the
  stack size of the options, the size of the file and the run-time packages it uses. }

interface

uses
  SysUtils, Classes, Forms, StdCtrls, ExtCtrls;

type
  TCompileInfo = record
    Lines, CodeSize, DataSize, StackSize, FileSize: Integer;   // -1: not known
    Status: string;
    Packages: string;           // ';' separated
  end;

  TCompInfoDlg = class(TForm)
    CompilerGroup: TGroupBox;
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    xLabel4: TLabel;
    CompiledLabel: TLabel;
    CodeSizeLabel: TLabel;
    DataSizeLabel: TLabel;
    StackSizeLabel: TLabel;
    xLabel5: TLabel;
    FileSizeLabel: TLabel;
    xGroupBox1: TGroupBox;
    StatusLabel: TLabel;
    PkgGroup: TGroupBox;
    PkgListBox: TListBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class procedure Execute(AOwner: TComponent; const ACaption: string; const Info: TCompileInfo);
  end;

var
  CompInfoDlg: TCompInfoDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TCompInfoDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ Delphi's form: "1234 lines", "56789 bytes" }
function Amount(N: Integer; const Unit_: string): string;
begin
  if N < 0 then Result := '' else Result := FormatFloat('#,##0', N) + ' ' + Unit_;
end;

class procedure TCompInfoDlg.Execute(AOwner: TComponent; const ACaption: string; const Info: TCompileInfo);
var
  D: TCompInfoDlg;
begin
  D := TCompInfoDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    D.CompiledLabel.Caption := Amount(Info.Lines, 'lines');
    D.CodeSizeLabel.Caption := Amount(Info.CodeSize, 'bytes');
    D.DataSizeLabel.Caption := Amount(Info.DataSize, 'bytes');
    D.StackSizeLabel.Caption := Amount(Info.StackSize, 'bytes');
    D.FileSizeLabel.Caption := Amount(Info.FileSize, 'bytes');
    D.StatusLabel.Caption := Info.Status;
    D.PkgListBox.Items.Text := StringReplace(Info.Packages, ';', #13#10, [rfReplaceAll]);
    if D.PkgListBox.Items.Count = 0 then D.PkgListBox.Items.Add('(none)');
    D.ShowModal;
  finally
    D.Free;
  end;
end;

end.
