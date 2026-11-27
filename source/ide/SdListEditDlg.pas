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
  in one go; a path can be chosen with "...", dropped from Explorer, made relative to the project's folder (or
  $(DELPHI)) or absolute. *Edit as text* shows the entries one a line in a text box, to edit many at once. }

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
    TextMemo: TMemo;
    chkText: TCheckBox;
    RelativeButton: TButton;
    AbsoluteButton: TButton;
    Actions: TActionList;
    aRelative: TAction;
    aAbsolute: TAction;
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
    procedure aRelativeExecute(Sender: TObject);
    procedure aRelativeUpdate(Sender: TObject);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure TextModeClick(Sender: TObject);
  private
    FPaths: Boolean;
    FBaseDir: string;
    FChecked: TStringList;       // the entries looked at (sorted), Objects: non-nil for a folder that exists
    function Valid(const S: string): Boolean;
    { the text box's lines (not blank) into the list }
    procedure TakeText;
    procedure FilesDropped(Control: TControl; Files: TStrings);
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
  SdUI, SdDialogs, SdIcons, SdProject, SdDelphiDir;

{$R *.dfm}

procedure TListEditDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  IconButton(UpButton, iiMoveUp);
  IconButton(DownButton, iiMoveDown);
  UIFlatBorder(TextMemo);
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

{ Edit as text: the list's entries one a line in the text box, and back; the list's commands wait
  meanwhile (ActionsUpdate) }
procedure TListEditDlg.TextModeClick(Sender: TObject);
begin
  if chkText.Checked then TextMemo.Lines.Assign(CreationList.Items) else TakeText;
  TextMemo.Visible := chkText.Checked;
  CreationList.Visible := not chkText.Checked;
  ElementEdit.Enabled := not chkText.Checked;
  if TextMemo.Visible and TextMemo.CanFocus then TextMemo.SetFocus;
end;

procedure TListEditDlg.TakeText;
var
  I: Integer;
begin
  CreationList.Items.BeginUpdate;
  try
    CreationList.Items.Clear;
    for I := 0 to TextMemo.Lines.Count - 1 do
      if Trim(TextMemo.Lines[I]) <> '' then CreationList.Items.Add(Trim(TextMemo.Lines[I]));
  finally
    CreationList.Items.EndUpdate;
  end;
  if CreationList.Items.Count > 0 then CreationList.ItemIndex := 0;
  ListClick(nil);
end;

procedure TListEditDlg.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
begin
  Handled := chkText.Checked;
  if Handled and (Action is TCustomAction) then TCustomAction(Action).Enabled := False;
end;

{ dropped folders (a file: its folder) as entries, relative to the project's folder as "..." gives
  them; at the end of the text in Edit as text }
procedure TListEditDlg.FilesDropped(Control: TControl; Files: TStrings);
var
  I: Integer;
  S: string;
begin
  for I := 0 to Files.Count - 1 do
  begin
    S := Files[I];
    if not DirectoryExists(S) then S := ExtractFileDir(S);
    S := OptionPath(S, FBaseDir);
    if chkText.Checked then TextMemo.Lines.Add(S)
    else if CreationList.Items.IndexOf(S) < 0 then CreationList.ItemIndex := CreationList.Items.Add(S);
  end;
  ListClick(nil);
end;

procedure TListEditDlg.aRelativeUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := FPaths and (CreationList.ItemIndex >= 0);
end;

{ Make Relative: a folder under Delphi's as $(DELPHI)\..., else relative to the project's folder (on its
  drive); Make Absolute: the full name - an entry of $(...) stays as it is, a relative one without a
  folder to be relative to too }
procedure TListEditDlg.aRelativeExecute(Sender: TObject);
var
  S, Full: string;
  I: Integer;
begin
  I := CreationList.ItemIndex;
  S := CreationList.Items[I];
  if Copy(S, 1, 2) = '$(' then Exit;
  if not IsAbsolutePath(S) and (FBaseDir = '') then Exit;
  Full := ExcludeTrailingPathDelimiter(ExpandFileName(FullOptionPath(S, FBaseDir)));
  if Sender = aAbsolute then S := Full
  else
  begin
    S := CollapseDelphiMacros(Full);
    if (S = Full) and (FBaseDir <> '') and SameText(ExtractFileDrive(Full), ExtractFileDrive(FBaseDir)) then
    begin
      S := ExcludeTrailingPathDelimiter(ExtractRelativePath(FBaseDir, IncludeTrailingPathDelimiter(Full)));
      if S = '' then S := '.';
    end;
  end;
  CreationList.Items[I] := S;
  CreationList.ItemIndex := I;
  ListClick(nil);
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
    D.RelativeButton.Visible := Paths;
    D.AbsoluteButton.Visible := Paths;
    if Paths then
    begin
      PathBox(D.ElementEdit, True);
      AcceptFileDrops(D.CreationList, D.FilesDropped);
      AcceptFileDrops(D.TextMemo, D.FilesDropped);
    end
    else
    begin
      { no row of Make Relative / Absolute: the dialog a row lower }
      D.Constraints.MinHeight := D.Constraints.MinHeight - (D.RelativeButton.Top - D.ReplaceButton.Top);
      D.ClientHeight := D.ClientHeight - (D.RelativeButton.Top - D.ReplaceButton.Top);
    end;
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
      if D.chkText.Checked then D.TakeText;
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
