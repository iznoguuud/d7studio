{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAddTodoDlg;

{ D7 Studio - Delphi 7's Add To-Do Item:
  text, priority, owner, category and Done. Three uses: the editor's Add
  To-Do Item (Shift+Ctrl+T - the comment goes in at the caret), the To-Do List's Add... (Delphi's
  Add: Done hidden, the values of the last OK offered again, the item goes into the project's
  To-Do file) and its Edit... (Delphi's Edit: "Edit To-Do Item", the item's values). OK checks the
  priority as Delphi does: a number from 0 to 5. }

interface

uses
  Windows, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls;

type
  TTodoDlgMode = (tmEditorAdd, tmAdd, tmEdit);

  { what the dialog shows and gives back }
  TTodoValues = record
    Text, Owner, Category: string;
    Priority: Integer;
    Done: Boolean;
  end;

  TAddTodoDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    xLabel4: TLabel;
    Memo: TMemo;
    xUpDown1: TUpDown;
    cbCategory: TComboBox;
    PriorityEdit: TEdit;
    cbOwner: TComboBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    CheckedBox: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FPriority: Integer;
  public
    { Owners and Categories: the ones offered (the To-Do list's). tmEditorAdd: the Windows user's
      name as the owner, Done offered; tmAdd: Done hidden, the text selected; tmEdit: Done offered.
      V in: the values shown (tmEditorAdd: none), out: the values after OK. }
    class function Execute(AOwner: TComponent; Mode: TTodoDlgMode; Owners, Categories: TStrings;
      var V: TTodoValues): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdDialogs;

procedure TAddTodoDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ Delphi's OKButtonClick: the priority must be a number (the RTL's message) from 0 to 5 ("Priority
  must be between 0 and 5."); the dialog stays with the priority selected }
procedure TAddTodoDlg.OKButtonClick(Sender: TObject);
begin
  if DialogValid(Self, CheckNumber(PriorityEdit, 0, 5, 'Priority must be between 0 and 5.', FPriority),
    PriorityEdit, 'Error') then ModalResult := mrOk;
end;

class function TAddTodoDlg.Execute(AOwner: TComponent; Mode: TTodoDlgMode; Owners, Categories: TStrings;
  var V: TTodoValues): Boolean;
var
  D: TAddTodoDlg;
  User: array[0..256] of Char;
  Size: DWORD;
begin
  D := TAddTodoDlg.Create(AOwner);
  try
    D.cbOwner.Items.Assign(Owners);
    D.cbCategory.Items.Assign(Categories);
    if Mode = tmEditorAdd then
    begin
      Size := SizeOf(User);
      if GetUserName(User, Size) then D.cbOwner.Text := User;
    end
    else
    begin
      D.Memo.Text := V.Text;
      D.xUpDown1.Position := V.Priority;       // it writes its edit's text when it gets its window
      D.cbOwner.Text := V.Owner;
      D.cbCategory.Text := V.Category;
      D.CheckedBox.Checked := V.Done;
      D.CheckedBox.Visible := Mode = tmEdit;
      if Mode = tmEdit then D.Caption := 'Edit To-Do Item';
      if Mode = tmAdd then D.Memo.SelectAll;
    end;
    D.ActiveControl := D.Memo;
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      V.Text := D.Memo.Text;
      V.Priority := D.FPriority;
      V.Owner := D.cbOwner.Text;
      V.Category := D.cbCategory.Text;
      V.Done := D.CheckedBox.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
