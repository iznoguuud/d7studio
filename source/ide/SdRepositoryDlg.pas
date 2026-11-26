{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRepositoryDlg;

{ D7 Studio - Tools | Repository: Delphi 7's Object Repository dialog. The pages in their order (add, delete -
  an empty one -, rename, move), the objects of the chosen page (edit its title, description,
  page, author and icon; delete it), and the defaults: a form is the New Form (File | New | Form)
  or the Main Form (File | New | Application), a project the New Project. It works on a copy of
  the repository; OK keeps the changes (SdRepository). }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, Buttons,
  ComCtrls, ActnList, SdRepository;

type
  TRepositoryDlg = class(TForm)
    PageLabel: TLabel;
    ObjectLabel: TLabel;
    PlaceHolder: TBevel;
    cbNewProject: TCheckBox;
    PageListBox: TListBox;
    cbMainForm: TCheckBox;
    MoveUp: TBitBtn;
    MoveDn: TBitBtn;
    cbNewForm: TCheckBox;
    AddButton: TButton;
    DeletePage: TButton;
    RenameButton: TButton;
    EditButton: TButton;
    DeleteObject: TButton;
    ObjectList: TListView;
    Actions: TActionList;
    aAddPage: TAction;
    aDeletePage: TAction;
    aRenamePage: TAction;
    aEditObject: TAction;
    aDeleteObject: TAction;
    aMoveUp: TAction;
    aMoveDown: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelBtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aAddPageExecute(Sender: TObject);
    procedure aDeletePageExecute(Sender: TObject);
    procedure aDeletePageUpdate(Sender: TObject);
    procedure aRenamePageExecute(Sender: TObject);
    procedure aPageUpdate(Sender: TObject);
    procedure aEditObjectExecute(Sender: TObject);
    procedure aObjectUpdate(Sender: TObject);
    procedure aDeleteObjectExecute(Sender: TObject);
    procedure PageMoveExecute(Sender: TObject);
    procedure PageMoveUpdate(Sender: TObject);
    procedure PageClick(Sender: TObject);
    procedure ObjectSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure ObjectDblClick(Sender: TObject);
    procedure FlagClick(Sender: TObject);
  private
    FRepo: TRepository;
    FFilling: Boolean;
    procedure FillPages(const Select: string);
    procedure FillObjects;
    procedure ShowFlags;
    function CurrentPage: string;
    function SelectedItem: TRepoItem;
    function PageEmpty(const Page: string): Boolean;
  public
    class function Execute(AOwner: TComponent; Repo: TRepository): Boolean;
  end;

var
  RepositoryDlg: TRepositoryDlg;

implementation

uses
  SdUI, SdDialogs, SdAddRepositoryDlg, SdIcons;

{$R *.dfm}

procedure TRepositoryDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  IconButton(MoveUp, iiMoveUp);
  IconButton(MoveDn, iiMoveDown);
end;

function TRepositoryDlg.CurrentPage: string;
begin
  if PageListBox.ItemIndex >= 0 then Result := PageListBox.Items[PageListBox.ItemIndex] else Result := '';
end;

function TRepositoryDlg.SelectedItem: TRepoItem;
begin
  if ObjectList.Selected <> nil then Result := TRepoItem(ObjectList.Selected.Data) else Result := nil;
end;

function TRepositoryDlg.PageEmpty(const Page: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FRepo.Count - 1 do
    if (FRepo[I].IsForm or FRepo[I].IsProject) and SameText(FRepo[I].Values['Page'], Page) then Exit;
  Result := True;
end;

procedure TRepositoryDlg.FillPages(const Select: string);
var
  I: Integer;
begin
  PageListBox.Items.Assign(FRepo.Pages);
  I := PageListBox.Items.IndexOf(Select);
  if (I < 0) and (PageListBox.Items.Count > 0) then I := 0;
  PageListBox.ItemIndex := I;
  FillObjects;
end;

procedure TRepositoryDlg.FillObjects;
var
  I: Integer;
  It: TListItem;
begin
  ObjectList.Items.BeginUpdate;
  try
    ObjectList.Items.Clear;
    for I := 0 to FRepo.Count - 1 do
      if (FRepo[I].IsForm or FRepo[I].IsProject) and SameText(FRepo[I].Values['Page'], CurrentPage) then
      begin
        It := ObjectList.Items.Add;
        It.Caption := FRepo[I].Values['Name'];
        if It.Caption = '' then It.Caption := ExtractFileName(FRepo[I].Path);
        It.Data := FRepo[I];
      end;
  finally
    ObjectList.Items.EndUpdate;
  end;
  if ObjectList.Items.Count > 0 then ObjectList.Items[0].Selected := True;
  ShowFlags;
end;

{ a form: New Form and Main Form; a project: New Project }
procedure TRepositoryDlg.ShowFlags;
var
  It: TRepoItem;
begin
  It := SelectedItem;
  FFilling := True;
  try
    cbNewForm.Visible := (It = nil) or It.IsForm;
    cbMainForm.Visible := (It = nil) or It.IsForm;
    cbNewProject.Visible := (It <> nil) and It.IsProject;
    cbNewForm.Enabled := It <> nil;
    cbMainForm.Enabled := It <> nil;
    cbNewForm.Checked := (It <> nil) and It.Flags['DefaultNewForm'];
    cbMainForm.Checked := (It <> nil) and It.Flags['DefaultMainForm'];
    cbNewProject.Checked := (It <> nil) and It.Flags['DefaultProject'];
  finally
    FFilling := False;
  end;
end;

procedure TRepositoryDlg.FlagClick(Sender: TObject);
begin
  if FFilling or (SelectedItem = nil) then Exit;
  if Sender = cbNewForm then FRepo.SetDefault('DefaultNewForm', SelectedItem, cbNewForm.Checked)
  else if Sender = cbMainForm then FRepo.SetDefault('DefaultMainForm', SelectedItem, cbMainForm.Checked)
  else FRepo.SetDefault('DefaultProject', SelectedItem, cbNewProject.Checked);
end;

procedure TRepositoryDlg.PageClick(Sender: TObject);
begin
  FillObjects;
end;

procedure TRepositoryDlg.ObjectSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  ShowFlags;
end;

procedure TRepositoryDlg.ObjectDblClick(Sender: TObject);
begin
  if aEditObject.Enabled then aEditObject.Execute;
end;

procedure TRepositoryDlg.aAddPageExecute(Sender: TObject);
var
  S: string;
begin
  S := '';
  if not InputDialog(Self, 'Add Page', '&Page Name:', S) or (Trim(S) = '') then Exit;
  S := Trim(S);
  if FRepo.Pages.IndexOf(S) < 0 then FRepo.Pages.Add(S);
  FillPages(S);
end;

procedure TRepositoryDlg.aDeletePageExecute(Sender: TObject);
var
  I: Integer;
begin
  I := FRepo.Pages.IndexOf(CurrentPage);
  if I >= 0 then FRepo.Pages.Delete(I);
  FillPages('');
end;

procedure TRepositoryDlg.aDeletePageUpdate(Sender: TObject);
begin
  aDeletePage.Enabled := (CurrentPage <> '') and PageEmpty(CurrentPage);
end;

procedure TRepositoryDlg.aRenamePageExecute(Sender: TObject);
var
  Old, S: string;
  I: Integer;
begin
  Old := CurrentPage;
  S := Old;
  if not InputDialog(Self, 'Rename Page', '&Page Name:', S) or (Trim(S) = '') then Exit;
  S := Trim(S);
  if not PageNameFree(Self, FRepo.Pages, S, FRepo.Pages.IndexOf(Old)) then Exit;
  I := FRepo.Pages.IndexOf(Old);
  if I >= 0 then FRepo.Pages[I] := S;
  for I := 0 to FRepo.Count - 1 do
    if SameText(FRepo[I].Values['Page'], Old) then FRepo[I].Values['Page'] := S;
  FillPages(S);
end;

procedure TRepositoryDlg.aPageUpdate(Sender: TObject);
begin
  aRenamePage.Enabled := CurrentPage <> '';
end;

procedure TRepositoryDlg.aEditObjectExecute(Sender: TObject);
var
  It: TRepoItem;
  Info: TRepoInfo;
  Dummy: Integer;
begin
  It := SelectedItem;
  if It = nil then Exit;
  Info.Title := It.Values['Name'];
  Info.Description := It.Values['Description'];
  Info.Page := It.Values['Page'];
  Info.Author := It.Values['Author'];
  Info.Icon := It.Values['Icon'];
  Dummy := -1;
  if not TAddRepositoryDlg.Execute(Self, 'Edit Object Info', nil, FRepo.Pages, Dummy, Info) then Exit;
  It.Values['Name'] := Info.Title;
  It.Values['Description'] := Info.Description;
  It.Values['Page'] := Info.Page;
  It.Values['Author'] := Info.Author;
  It.Values['Icon'] := Info.Icon;
  if FRepo.Pages.IndexOf(Info.Page) < 0 then FRepo.Pages.Add(Info.Page);
  FillPages(CurrentPage);
end;

procedure TRepositoryDlg.aObjectUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := SelectedItem <> nil;
end;

procedure TRepositoryDlg.aDeleteObjectExecute(Sender: TObject);
begin
  if SelectedItem = nil then Exit;
  if MessageBox(Handle, PChar(Format('Delete %s from the repository? (Its files stay.)',
    [ObjectList.Selected.Caption])), 'Object Repository', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  FRepo.Delete(SelectedItem);
  FillObjects;
end;

{ Move Up / Move Down of a page: the list shows the repository's pages in their order }
procedure TRepositoryDlg.PageMoveExecute(Sender: TObject);
var
  I: Integer;
begin
  I := MoveListRow(PageListBox, Sender = aMoveUp);
  if I >= 0 then FRepo.Pages.Exchange(I, PageListBox.ItemIndex);
end;

procedure TRepositoryDlg.PageMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CanMoveListRow(PageListBox, Sender = aMoveUp);
end;

class function TRepositoryDlg.Execute(AOwner: TComponent; Repo: TRepository): Boolean;
var
  D: TRepositoryDlg;
begin
  D := TRepositoryDlg.Create(AOwner);
  try
    D.FRepo := Repo;
    D.FillPages('');
    Result := D.ShowModal = mrOk;
  finally
    D.Free;
  end;
end;

end.
