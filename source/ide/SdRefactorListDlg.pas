{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorListDlg;

{ D7 Studio - what a refactoring takes of a list: the items under their groups, each with a check
  box (a group's box checks or unchecks its items), a choice of the refactoring's own and a check
  box. The rows a refactoring does not ask for are hidden and the ones below move up. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, ImgList;

type
  { what the dialog shows and gives back: Items - 'group'#9'item' (no tab: an item without a group),
    in their order, an object not nil when the item is checked (after OK: the items checked);
    Choices - the choice row's items, one per line ('': no choice row); CheckCaption - the check
    box ('': none) }
  TRefListData = record
    Caption, Prompt: string;
    Items: TStrings;
    ChoiceCaption, Choices: string;
    Choice: Integer;
    CheckCaption: string;
    Checked: Boolean;
  end;

  TRefactorListDlg = class(TForm)
    lblItems: TLabel;
    tvItems: TTreeView;
    lblChoice: TLabel;
    cbChoice: TComboBox;
    cbCheck: TCheckBox;
    Checks: TImageList;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure tvItemsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure tvItemsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure tvItemsKeyPress(Sender: TObject; var Key: Char);
  private
    FItems: TList;                 // the item nodes, in the order of the items
    procedure Fill(Items: TStrings);
  public
    destructor Destroy; override;
    class function Execute(AOwner: TComponent; var Data: TRefListData): Boolean;
  end;

{ the data of a dialog with ACaption, Prompt and Items: no choice, no check box }
function RefListData(const ACaption, Prompt: string; Items: TStrings): TRefListData;

var
  RefactorListDlg: TRefactorListDlg;

implementation

uses
  SdUI, SdDialogs, SdCheckImages;

{$R *.dfm}

function RefListData(const ACaption, Prompt: string; Items: TStrings): TRefListData;
begin
  Finalize(Result);
  FillChar(Result, SizeOf(Result), 0);
  Result.Caption := ACaption;
  Result.Prompt := Prompt;
  Result.Items := Items;
end;

procedure TRefactorListDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  FItems := TList.Create;
  MakeCheckImages(Checks);
end;

destructor TRefactorListDlg.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

{ the groups in the order they first come, their items under them; a group open when one of its
  items is checked }
procedure TRefactorListDlg.Fill(Items: TStrings);
var
  I, P: Integer;
  Group, Node: TTreeNode;
  Groups: TStringList;
  G: string;
begin
  Groups := TStringList.Create;
  tvItems.Items.BeginUpdate;
  try
    for I := 0 to Items.Count - 1 do
    begin
      P := Pos(#9, Items[I]);
      Group := nil;
      if P > 0 then
      begin
        G := Copy(Items[I], 1, P - 1);
        if Groups.IndexOf(G) >= 0 then Group := TTreeNode(Groups.Objects[Groups.IndexOf(G)])
        else
        begin
          Group := tvItems.Items.AddChild(nil, G);
          Group.StateIndex := ciUnchecked;
          Groups.AddObject(G, Group);
        end;
      end;
      Node := tvItems.Items.AddChild(Group, Copy(Items[I], P + 1, MaxInt));
      FItems.Add(Node);
      SetCheck(Node, Items.Objects[I] <> nil);
    end;
    for I := 0 to Groups.Count - 1 do
      if TTreeNode(Groups.Objects[I]).StateIndex <> ciUnchecked then TTreeNode(Groups.Objects[I]).Expand(False);
    { items without groups: a plain list, no lines at the root }
    tvItems.ShowRoot := Groups.Count > 0;
    if tvItems.Items.Count > 0 then tvItems.Selected := tvItems.Items[0];
  finally
    tvItems.Items.EndUpdate;
    Groups.Free;
  end;
end;

procedure TRefactorListDlg.btnOKClick(Sender: TObject);
var
  I: Integer;
  Any: Boolean;
begin
  Any := False;
  for I := 0 to FItems.Count - 1 do
    if TTreeNode(FItems[I]).StateIndex = ciChecked then Any := True;
  if not DialogValid(Self, Any, 'Check what to take', tvItems) then Exit;
  ModalResult := mrOk;
end;

procedure TRefactorListDlg.tvItemsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if (Button = mbLeft) and (htOnStateIcon in tvItems.GetHitTestInfoAt(X, Y)) then
    ToggleCheck(tvItems.GetNodeAt(X, Y));
end;

procedure TRefactorListDlg.tvItemsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_SPACE) and (Shift = []) then
  begin
    ToggleCheck(tvItems.Selected);
    Key := 0;
  end;
end;

{ the Space that toggled a box does not go on to the tree's incremental search (which beeps) }
procedure TRefactorListDlg.tvItemsKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = ' ' then Key := #0;
end;

class function TRefactorListDlg.Execute(AOwner: TComponent; var Data: TRefListData): Boolean;
var
  D: TRefactorListDlg;
  I: Integer;
begin
  D := TRefactorListDlg.Create(AOwner);
  try
    D.Caption := Data.Caption;
    if Data.Prompt <> '' then D.lblItems.Caption := Data.Prompt;
    D.Fill(Data.Items);
    if Data.ChoiceCaption <> '' then D.lblChoice.Caption := Data.ChoiceCaption;
    D.cbChoice.Items.Text := Data.Choices;
    if (Data.Choice >= 0) and (Data.Choice < D.cbChoice.Items.Count) then D.cbChoice.ItemIndex := Data.Choice
    else if D.cbChoice.Items.Count > 0 then D.cbChoice.ItemIndex := 0;
    D.cbCheck.Caption := Data.CheckCaption;
    D.cbCheck.Checked := Data.Checked;
    { the rows not asked for, the last one first }
    if Data.CheckCaption = '' then HideDialogRow(D, [D.cbCheck], D.pnlFooter.Top - D.cbCheck.Top);
    if Data.Choices = '' then HideDialogRow(D, [D.lblChoice, D.cbChoice], D.cbCheck.Top - D.lblChoice.Top);
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      for I := 0 to D.FItems.Count - 1 do
        if TTreeNode(D.FItems[I]).StateIndex = ciChecked then Data.Items.Objects[I] := Pointer(1)
        else Data.Items.Objects[I] := nil;
      Data.Choice := D.cbChoice.ItemIndex;
      Data.Checked := D.cbCheck.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
