{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdListEditDlg;

{ D7 Studio - Delphi 7's ordered list editor (built on its
  Creation Order dialog): the entries of a ';' separated option - search paths, conditional
  defines, unit aliases - in their order. Paths that do not exist are greyed and can be deleted
  in one go; a path can be chosen with "...". }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  Buttons, ActnList;

type
  TListEditDlg = class(TForm)
    InvalidPathLbl: TLabel;
    CreationList: TListBox;
    UpButton: TBitBtn;
    DownButton: TBitBtn;
    ElementEdit: TEdit;
    ReplaceButton: TButton;
    AddButton: TButton;
    DeleteButton: TButton;
    BrowseButton: TButton;
    DeleteInvalidBtn: TButton;
    Actions: TActionList;
    aReplace: TAction;
    aAdd: TAction;
    aDelete: TAction;
    aBrowse: TAction;
    aDeleteInvalid: TAction;
    aUp: TAction;
    aDown: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aReplaceExecute(Sender: TObject);
    procedure aReplaceUpdate(Sender: TObject);
    procedure aAddExecute(Sender: TObject);
    procedure aAddUpdate(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure aDeleteUpdate(Sender: TObject);
    procedure aBrowseExecute(Sender: TObject);
    procedure aDeleteInvalidExecute(Sender: TObject);
    procedure aDeleteInvalidUpdate(Sender: TObject);
    procedure aMoveExecute(Sender: TObject);
    procedure aMoveUpdate(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FPaths: Boolean;
    FBaseDir: string;
    FChecked: TStringList;       // the entries looked at (sorted), Objects: non-nil for a folder that exists
    function Valid(const S: string): Boolean;
  public
    destructor Destroy; override;
    { Paths: the entries are folders (relative ones from BaseDir; $(DELPHI) ... expanded) }
    class function Execute(AOwner: TComponent; const ACaption: string; Paths: Boolean;
      const BaseDir: string; var Value: string): Boolean;
  end;

var
  ListEditDlg: TListEditDlg;

implementation

uses
  SdUI, SdDialogs, SdIcons;

{$R *.dfm}

procedure TListEditDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  IconButton(UpButton, iiMoveUp);
  IconButton(DownButton, iiMoveDown);
  FChecked := TStringList.Create;
  FChecked.Sorted := True;
end;

destructor TListEditDlg.Destroy;
begin
  FreeAndNil(FChecked);
  inherited Destroy;
end;

{ a folder that exists; each entry is looked up once (painting and the idle updates ask again
  and again, and a folder of an unreachable share takes seconds) - an entry added or replaced is
  a new text, looked up when it is first asked about }
function TListEditDlg.Valid(const S: string): Boolean;
var
  D: string;
  K: Integer;
begin
  Result := True;
  if not FPaths then Exit;
  K := FChecked.IndexOf(S);
  if K < 0 then
  begin
    D := FullOptionPath(S, FBaseDir);
    K := FChecked.AddObject(S, TObject(Ord(DirectoryExists(D))));
  end;
  Result := FChecked.Objects[K] <> nil;
end;

{ invalid paths are greyed, as in Delphi }
procedure TListEditDlg.ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
begin
  C := CreationList.Canvas;
  C.FillRect(Rect);
  if not (odSelected in State) and not Valid(CreationList.Items[Index]) then C.Font.Color := clGrayText;
  C.TextOut(Rect.Left + 2, UIListTextTop(C.Handle, Rect), CreationList.Items[Index]);
end;

procedure TListEditDlg.ListClick(Sender: TObject);
begin
  if CreationList.ItemIndex >= 0 then ElementEdit.Text := CreationList.Items[CreationList.ItemIndex];
end;

procedure TListEditDlg.aReplaceUpdate(Sender: TObject);
begin
  aReplace.Enabled := (CreationList.ItemIndex >= 0) and (Trim(ElementEdit.Text) <> '');
end;

procedure TListEditDlg.aReplaceExecute(Sender: TObject);
begin
  CreationList.Items[CreationList.ItemIndex] := Trim(ElementEdit.Text);
end;

procedure TListEditDlg.aAddUpdate(Sender: TObject);
begin
  aAdd.Enabled := (Trim(ElementEdit.Text) <> '') and (CreationList.Items.IndexOf(Trim(ElementEdit.Text)) < 0);
end;

procedure TListEditDlg.aAddExecute(Sender: TObject);
begin
  CreationList.ItemIndex := CreationList.Items.Add(Trim(ElementEdit.Text));
end;

procedure TListEditDlg.aDeleteUpdate(Sender: TObject);
begin
  aDelete.Enabled := CreationList.ItemIndex >= 0;
end;

procedure TListEditDlg.aDeleteExecute(Sender: TObject);
begin
  DeleteListRow(CreationList);
  ListClick(nil);
end;

procedure TListEditDlg.aBrowseExecute(Sender: TObject);
begin
  BrowseFolder(ElementEdit, 'Directory', FBaseDir);
end;

procedure TListEditDlg.aDeleteInvalidUpdate(Sender: TObject);
var
  I: Integer;
  Any: Boolean;
begin
  Any := False;
  if FPaths then
    for I := 0 to CreationList.Items.Count - 1 do
      if not Valid(CreationList.Items[I]) then
      begin
        Any := True;
        Break;
      end;
  aDeleteInvalid.Enabled := Any;
end;

procedure TListEditDlg.aDeleteInvalidExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := CreationList.Items.Count - 1 downto 0 do
    if not Valid(CreationList.Items[I]) then CreationList.Items.Delete(I);
end;

procedure TListEditDlg.aMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CanMoveListRow(CreationList, Sender = aUp);
end;

procedure TListEditDlg.aMoveExecute(Sender: TObject);
begin
  MoveListRow(CreationList, Sender = aUp);
end;

class function TListEditDlg.Execute(AOwner: TComponent; const ACaption: string; Paths: Boolean;
  const BaseDir: string; var Value: string): Boolean;
var
  D: TListEditDlg;
  L: TStringList;
  I: Integer;
begin
  D := TListEditDlg.Create(AOwner);
  L := TStringList.Create;
  try
    D.Caption := ACaption;
    D.FPaths := Paths;
    D.FBaseDir := BaseFolder(BaseDir);
    D.InvalidPathLbl.Visible := Paths;
    D.BrowseButton.Visible := Paths;
    D.DeleteInvalidBtn.Visible := Paths;
    { split at ';' only (DelimitedText of Delphi 7 also splits at blanks: "Program Files") }
    L.Text := StringReplace(Value, ';', #13#10, [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) <> '' then D.CreationList.Items.Add(Trim(L[I]));
    if D.CreationList.Items.Count > 0 then
    begin
      D.CreationList.ItemIndex := 0;
      D.ListClick(nil);
    end;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      L.Assign(D.CreationList.Items);
      Value := '';
      for I := 0 to L.Count - 1 do
      begin
        if I > 0 then Value := Value + ';';
        Value := Value + L[I];
      end;
    end;
  finally
    L.Free;
    D.Free;
  end;
end;

end.
