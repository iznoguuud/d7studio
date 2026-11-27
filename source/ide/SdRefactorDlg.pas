{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorDlg;

{ D7 Studio - what a refactoring asks before it shows its changes: a name, a type, the visibility
  of a new member, one choice of the refactoring's own, the value it is about (read only), a check
  box. The rows a refactoring does not ask for are hidden and the ones below move up. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TRefDlgRow = (rrName, rrType, rrAccess, rrChoice, rrValue, rrCheck);
  TRefDlgRows = set of TRefDlgRow;

  { what a refactoring asks: Rows - the rows shown; Access - as the Code Explorer's (0 published,
    1 private, 2 protected, 3 public); Choices - the choice row's items, one per line; ValueCaption,
    Value - the read-only row; CheckCaption, Checked - the check box }
  TRefDlgData = record
    Caption: string;
    Rows: TRefDlgRows;
    Name, TypeName: string;
    Access: Integer;
    ChoiceCaption, Choices: string;
    Choice: Integer;
    ValueCaption, Value: string;
    CheckCaption: string;
    Checked: Boolean;
  end;

  TRefactorDlg = class(TForm)
    lblName: TLabel;
    edName: TEdit;
    lblType: TLabel;
    edType: TEdit;
    lblAccess: TLabel;
    cbAccess: TComboBox;
    lblChoice: TLabel;
    cbChoice: TComboBox;
    lblValue: TLabel;
    edValue: TEdit;
    cbCheck: TCheckBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FRows: TRefDlgRows;
    procedure Arrange;
  public
    class function Execute(AOwner: TComponent; var Data: TRefDlgData): Boolean;
  end;

{ the data of a dialog with ACaption and Rows: nothing filled in, a new member private }
function RefDlgData(const ACaption: string; Rows: TRefDlgRows): TRefDlgData;

var
  RefactorDlg: TRefactorDlg;

implementation

uses
  SdUI, SdDialogs, SdRefactor;

{$R *.dfm}

function RefDlgData(const ACaption: string; Rows: TRefDlgRows): TRefDlgData;
begin
  Finalize(Result);
  FillChar(Result, SizeOf(Result), 0);
  Result.Caption := ACaption;
  Result.Rows := Rows;
  Result.Access := 1;
end;

procedure TRefactorDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TRefactorDlg.btnOKClick(Sender: TObject);
begin
  if (rrName in FRows) and not DialogValid(Self, CheckNewName(Trim(edName.Text)), edName) then Exit;
  if (rrType in FRows) and not DialogValid(Self, Trim(edType.Text) <> '', 'Give it a type', edType) then Exit;
  ModalResult := mrOk;
end;

{ the rows asked for in their places: each hidden row's height (to the next row, the last one's to
  the footer) taken out of those below it }
procedure TRefactorDlg.Arrange;
type
  TRowControls = array[0..1] of TControl;
var
  Rows: array[TRefDlgRow] of TRowControls;
  R: TRefDlgRow;
  H: Integer;
begin
  Rows[rrName][0] := lblName;      Rows[rrName][1] := edName;
  Rows[rrType][0] := lblType;      Rows[rrType][1] := edType;
  Rows[rrAccess][0] := lblAccess;  Rows[rrAccess][1] := cbAccess;
  Rows[rrChoice][0] := lblChoice;  Rows[rrChoice][1] := cbChoice;
  Rows[rrValue][0] := lblValue;    Rows[rrValue][1] := edValue;
  Rows[rrCheck][0] := cbCheck;     Rows[rrCheck][1] := nil;
  for R := High(TRefDlgRow) downto Low(TRefDlgRow) do
  begin
    if R in FRows then Continue;
    if R < High(TRefDlgRow) then H := Rows[Succ(R)][0].Top - Rows[R][0].Top
    else H := pnlFooter.Top - Rows[R][0].Top;
    HideDialogRow(Self, Rows[R], H);
  end;
end;

class function TRefactorDlg.Execute(AOwner: TComponent; var Data: TRefDlgData): Boolean;
var
  D: TRefactorDlg;
begin
  D := TRefactorDlg.Create(AOwner);
  try
    D.FRows := Data.Rows;
    D.Caption := Data.Caption;
    D.edName.Text := Data.Name;
    D.edType.Text := Data.TypeName;
    if (Data.Access >= 0) and (Data.Access < D.cbAccess.Items.Count) then D.cbAccess.ItemIndex := Data.Access
    else D.cbAccess.ItemIndex := 1;
    if Data.ChoiceCaption <> '' then D.lblChoice.Caption := Data.ChoiceCaption;
    D.cbChoice.Items.Text := Data.Choices;
    if (Data.Choice >= 0) and (Data.Choice < D.cbChoice.Items.Count) then D.cbChoice.ItemIndex := Data.Choice
    else if D.cbChoice.Items.Count > 0 then D.cbChoice.ItemIndex := 0;
    if Data.ValueCaption <> '' then D.lblValue.Caption := Data.ValueCaption;
    D.edValue.Text := Data.Value;
    if Data.CheckCaption <> '' then D.cbCheck.Caption := Data.CheckCaption;
    D.cbCheck.Checked := Data.Checked;
    D.Arrange;
    if rrName in Data.Rows then D.ActiveControl := D.edName
    else if rrType in Data.Rows then D.ActiveControl := D.edType;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Data.Name := Trim(D.edName.Text);
      Data.TypeName := Trim(D.edType.Text);
      Data.Access := D.cbAccess.ItemIndex;
      Data.Choice := D.cbChoice.ItemIndex;
      Data.Checked := D.cbCheck.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
