{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompileDlg;

{ D7 Studio - the compiler progress dialog of Delphi 7 (Environment Options | Preferences |
  Show compiler progress):

      Project:    D:\Projects\Project1.dpr
      Compiling:  Unit1.pas                     ->  Done:  Compiled.  /  There are errors.
      [ Current line:          123 ] [ Total lines:        4567 ]
      [ Hints:     0 ] [ Warnings:     0 ] [ Errors:          0 ]
                         [  Cancel  ]           ->  [    OK    ]

  The compiler runs inside the modal loop of the dialog. A compile is the whole IDE's, so the
  dialog is centred on the main window (Position = poMainFormCenter) also when it was started
  from a floating view - the package editor's Compile, an expert's window. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls,
  SdProject;

const
  CM_STARTCOMPILE = WM_APP + 71;

type
  TCompileDlg = class(TForm)
    lblProjectCap: TLabel;
    lblProject: TLabel;
    lblAction: TLabel;
    lblFile: TLabel;
    pnlLine: TPanel;
    shpLine: TShape;
    lblLineCap: TLabel;
    lblLine: TLabel;
    pnlTotal: TPanel;
    shpTotal: TShape;
    lblTotalCap: TLabel;
    lblTotal: TLabel;
    pnlHints: TPanel;
    shpHints: TShape;
    lblHintsCap: TLabel;
    lblHints: TLabel;
    pnlWarnings: TPanel;
    shpWarnings: TShape;
    lblWarningsCap: TLabel;
    lblWarnings: TLabel;
    pnlErrors: TPanel;
    shpErrors: TShape;
    lblErrorsCap: TLabel;
    lblErrors: TLabel;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnAction: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnActionClick(Sender: TObject);
  private
    FCompiler: TSdCompiler;
    FDcc32, FArgs, FWorkDir, FSearchPath: string;
    FAutoClose, FStarted, FRunning, FSuccess: Boolean;
    FLastUpdate: Cardinal;
    FCurFile: string;
    FCurLine, FCurTotal: Integer;
    procedure FitCell(Cap, Value: TLabel);
    procedure CompilerProgress(const FileName: string; Line, TotalLines: Integer);
    procedure ShowProgress;
    procedure CMStartCompile(var Message: TMessage); message CM_STARTCOMPILE;
    procedure WMClose(var Message: TWMClose); message WM_CLOSE;
  public
    { Runs the compiler behind the dialog. AutoClose: the dialog closes by itself after a
      successful compile (Run; any compile with Environment Options | Preferences | Auto close
      on successful compile); otherwise it waits for OK. Returns the compiler's result. }
    class function Execute(AOwner: TComponent; Compiler: TSdCompiler; const ProjectFile, Dcc32,
      Args, WorkDir, SearchPath: string; AutoClose: Boolean): Boolean;
  end;

var
  CompileDlg: TCompileDlg;

implementation

uses
  {$WARN UNIT_PLATFORM OFF} FileCtrl, {$WARN UNIT_PLATFORM ON}     // MinimizeName
  SdUI;

{$R *.dfm}

procedure TCompileDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  FitCell(lblLineCap, lblLine);
  FitCell(lblTotalCap, lblTotal);
  FitCell(lblHintsCap, lblHints);
  FitCell(lblWarningsCap, lblWarnings);
  FitCell(lblErrorsCap, lblErrors);
end;

{ a sunken cell: the caption on the left, the number takes the rest and is right-aligned }
procedure TCompileDlg.FitCell(Cap, Value: TLabel);
var
  X: Integer;
begin
  X := Cap.Left + Cap.Width + 4;
  Value.SetBounds(X, Cap.Top, Cap.Parent.Width - Cap.Left - X, Cap.Height);
end;

procedure TCompileDlg.FormShow(Sender: TObject);
begin
  if not FStarted then
  begin
    FStarted := True;
    PostMessage(Handle, CM_STARTCOMPILE, 0, 0);
  end;
end;

procedure TCompileDlg.ShowProgress;
begin
  lblFile.Caption := ExtractFileName(FCurFile);
  lblLine.Caption := IntToStr(FCurLine);
  lblTotal.Caption := IntToStr(FCurTotal);
  lblHints.Caption := IntToStr(FCompiler.Hints);
  lblWarnings.Caption := IntToStr(FCompiler.Warnings);
  lblErrors.Caption := IntToStr(FCompiler.Errors);
end;

procedure TCompileDlg.CompilerProgress(const FileName: string; Line, TotalLines: Integer);
begin
  FCurFile := FileName;
  FCurLine := Line;
  FCurTotal := TotalLines;
  { the compiler reports far more often than a display needs }
  if GetTickCount - FLastUpdate >= 40 then
  begin
    FLastUpdate := GetTickCount;
    ShowProgress;
    Update;
  end;
end;

procedure TCompileDlg.CMStartCompile(var Message: TMessage);
var
  OldProgress: TCompileProgressEvent;
begin
  OldProgress := FCompiler.OnProgress;
  FCompiler.OnProgress := CompilerProgress;
  FRunning := True;
  try
    FSuccess := FCompiler.Run(FDcc32, FArgs, FWorkDir, FSearchPath);
  finally
    FRunning := False;
    FCompiler.OnProgress := OldProgress;
  end;
  if FCompiler.Cancelled then
  begin
    ModalResult := mrCancel;
    Exit;
  end;
  FCurTotal := FCompiler.TotalLines;
  ShowProgress;
  lblAction.Caption := 'Done:';
  if FSuccess then lblFile.Caption := 'Compiled.' else lblFile.Caption := 'There are errors.';
  btnAction.Caption := 'OK';
  if FAutoClose and FSuccess then ModalResult := mrOk;
end;

procedure TCompileDlg.btnActionClick(Sender: TObject);
begin
  if FRunning then FCompiler.Cancel else ModalResult := mrOk;
end;

procedure TCompileDlg.WMClose(var Message: TWMClose);
begin
  { Alt+F4 while the compiler runs means Cancel; the dialog goes away when it has stopped
    (a modal form's Close would merely set ModalResult and let the compiler finish) }
  if FRunning then FCompiler.Cancel else inherited;
end;

class function TCompileDlg.Execute(AOwner: TComponent; Compiler: TSdCompiler; const ProjectFile,
  Dcc32, Args, WorkDir, SearchPath: string; AutoClose: Boolean): Boolean;
var
  D: TCompileDlg;
begin
  D := TCompileDlg.Create(AOwner);
  try
    D.FCompiler := Compiler;
    D.FDcc32 := Dcc32;
    D.FArgs := Args;
    D.FWorkDir := WorkDir;
    D.FSearchPath := SearchPath;
    D.FAutoClose := AutoClose;
    D.Canvas.Font := D.Font;
    D.lblProject.Caption := MinimizeName(ProjectFile, D.Canvas, D.lblProject.Width);
    D.ShowModal;
    Result := D.FSuccess;
  finally
    D.Free;
  end;
end;

end.
