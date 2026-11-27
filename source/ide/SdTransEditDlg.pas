{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTransEditDlg;

{ D7 Studio - Delphi 7's Tool Properties, Configure Tools | Add /
  Edit: title, program, working directory and parameters of a program of the Tools menu; Macros
  shows the macros of the parameters (SdMain.ExpandTransferMacros), Insert puts one in. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Buttons,
  ActnList, SdEnvOptions;

type
  { the form and its controls keep Delphi 7's names, the class does not: an expert that enhances Delphi's
    dialog by its class name finds controls and handlers this one lays out otherwise - its buttons in the
    band at the foot, no Help button, Macros an action - and fails }
  TToolPropertiesDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    MacroLabel: TLabel;
    xLabel4: TLabel;
    edTitle: TEdit;
    edProgram: TEdit;
    edParameters: TEdit;
    MacroButton: TBitBtn;
    MacroList: TListBox;
    edWorkingDir: TEdit;
    InsertButton: TButton;
    BrowseButton: TButton;
    Actions: TActionList;
    aMacros: TAction;
    aInsertMacro: TAction;
    aBrowse: TAction;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aMacrosExecute(Sender: TObject);
    procedure aInsertMacroExecute(Sender: TObject);
    procedure aInsertMacroUpdate(Sender: TObject);
    procedure aBrowseExecute(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure MacroDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FFullHeight, FFooterTop: Integer;
    procedure ShowMacros(Show: Boolean);
  public
    class function Execute(AOwner: TComponent; const ACaption: string; var Tool: TTransferTool): Boolean;
  end;

var
  TransEditDlg: TToolPropertiesDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

const
  Macros: array[0..13] of array[0..1] of string = (
    ('$COL', 'Column number'), ('$ROW', 'Row number'), ('$CURTOKEN', 'Word at cursor'),
    ('$DIR()', 'Directory of the argument'), ('$EDNAME', 'Expanded editor file name'),
    ('$EXENAME', 'Expanded program name'), ('$EXT()', 'Extension of the argument'),
    ('$NAME()', 'File name of the argument'), ('$NAMEONLY()', 'File name without extension'),
    ('$PARAMS', 'Run parameters'), ('$PATH()', 'Path of the argument'),
    ('$PROMPT', 'Prompt for the parameters'), ('$SAVE', 'Save the current file'),
    ('$SAVEALL', 'Save all files'));

procedure TToolPropertiesDlg.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  for I := Low(Macros) to High(Macros) do MacroList.Items.Add(Macros[I][0]);
  MacroList.ItemHeight := MacroList.Canvas.TextHeight('Wg') + 2;
  FFullHeight := ClientHeight;
  FFooterTop := pnlFooter.Top;
  ShowMacros(False);
  PathBox(edProgram, False);
  PathBox(edWorkingDir, True);
end;

{ Delphi's list: the macro and what it stands for, in two columns }
procedure TToolPropertiesDlg.MacroDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  X: Integer;
begin
  C := MacroList.Canvas;
  C.FillRect(Rect);
  C.TextOut(Rect.Left + 2, UIListTextTop(C.Handle, Rect), Macros[Index][0]);
  X := Rect.Left + 2 + C.TextWidth('$NAMEONLY()') + 12;
  C.TextOut(X, UIListTextTop(C.Handle, Rect), Macros[Index][1]);
  UIListRowWidth(MacroList, X + C.TextWidth(Macros[Index][1]));
end;

{ the list and its button are below the fields: the dialog grows to show them, the band of the
  buttons below them; without them the band is as far below the Macros button as below the list }
procedure TToolPropertiesDlg.ShowMacros(Show: Boolean);
begin
  MacroLabel.Visible := Show;
  MacroList.Visible := Show;
  InsertButton.Visible := Show;
  if Show then
  begin
    ClientHeight := FFullHeight;
    pnlFooter.Top := FFooterTop;
    aMacros.Caption := '&Macros <<';
  end
  else
  begin
    pnlFooter.Top := MacroButton.Top + MacroButton.Height + FFooterTop - (MacroList.Top + MacroList.Height);
    ClientHeight := pnlFooter.Top + pnlFooter.Height;
    aMacros.Caption := '&Macros >>';
  end;
end;

procedure TToolPropertiesDlg.aMacrosExecute(Sender: TObject);
begin
  ShowMacros(not MacroList.Visible);
end;

procedure TToolPropertiesDlg.aInsertMacroExecute(Sender: TObject);
begin
  if MacroList.ItemIndex < 0 then Exit;
  edParameters.SelText := Macros[MacroList.ItemIndex][0];
  edParameters.SetFocus;
end;

procedure TToolPropertiesDlg.aInsertMacroUpdate(Sender: TObject);
begin
  aInsertMacro.Enabled := MacroList.ItemIndex >= 0;
end;

procedure TToolPropertiesDlg.aBrowseExecute(Sender: TObject);
begin
  if not BrowseFile(edProgram, 'Select Transfer Item',
    'Programs (*.exe;*.com;*.bat;*.cmd)|*.exe;*.com;*.bat;*.cmd|Any file (*.*)|*.*') then Exit;
  if edWorkingDir.Text = '' then edWorkingDir.Text := ExtractFileDir(edProgram.Text);
  if edTitle.Text = '' then edTitle.Text := ChangeFileExt(ExtractFileName(edProgram.Text), '');
end;

procedure TToolPropertiesDlg.aOKExecute(Sender: TObject);
const
  Msg = 'A tool needs a title and a program.';
begin
  if DialogValid(Self, Trim(edTitle.Text) <> '', Msg, edTitle) and
    DialogValid(Self, Trim(edProgram.Text) <> '', Msg, edProgram) then ModalResult := mrOk;
end;

class function TToolPropertiesDlg.Execute(AOwner: TComponent; const ACaption: string; var Tool: TTransferTool): Boolean;
var
  D: TToolPropertiesDlg;
begin
  D := TToolPropertiesDlg.Create(AOwner);
  try
    if ACaption <> '' then D.Caption := ACaption;
    D.edTitle.Text := Tool.Title;
    D.edProgram.Text := Tool.Path;
    D.edWorkingDir.Text := Tool.WorkingDir;
    D.edParameters.Text := Tool.Params;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    Tool.Title := Trim(D.edTitle.Text);
    Tool.Path := Trim(D.edProgram.Text);
    Tool.WorkingDir := Trim(D.edWorkingDir.Text);
    Tool.Params := D.edParameters.Text;
  finally
    D.Free;
  end;
end;

end.
