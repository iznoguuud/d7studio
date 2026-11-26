{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdStringTableFrame;

{ D7 Studio - the editor of a string table in its page of the file area (SdResPage), as Visual Studio's:
  the strings by id in a list, edited in place - F2
  (the text) or a double click on a cell (its id or its text) puts an edit over it; Enter or a
  click elsewhere takes it, Esc leaves the cell as it was, Tab goes on to the next cell. Line
  breaks and tabs are written \n, \r and \t, a backslash \\. A click on a column's header sorts by
  it (again: the other way round); Find shows the rows whose id or text holds what is typed. Add
  makes a row with the next free id, Delete (also Del in the list) takes the chosen rows (several
  with Shift and Ctrl). The texts are UTF-16 in the resource and the IDE's text here; a text that
  is not changed is written back as it was read, also where the IDE's code page cannot show it.
  Before it is saved the ids are checked (0 ... 65535, each once). }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  ActnList, SdResources, SdResPage;

type
  TStringTableFrame = class(TFrame, ISdResEditor)
    TopPanel: TPanel;
    TopBar: TToolBar;
    tbAdd: TToolButton;
    tbDelete: TToolButton;
    lblFind: TLabel;
    edFind: TEdit;
    List: TListView;
    CellEdit: TEdit;
    Actions: TActionList;
    aAdd: TAction;
    EditDeleteCommand: TAction;
    aEdit: TAction;
    procedure edFindChange(Sender: TObject);
    procedure ListColumnClick(Sender: TObject; Column: TListColumn);
    procedure ListCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    procedure ListDblClick(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure aAddExecute(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure aDeleteUpdate(Sender: TObject);
    procedure aEditExecute(Sender: TObject);
    procedure aEditUpdate(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditExit(Sender: TObject);
  private
    FItems: TSdStringItems;      // by the rows' Data (an index); a deleted one has the id -2
    FEditRow: TListItem;
    FEditCol: Integer;
    FClickCol: Integer;          // the column the last click was in
    FSortCol: Integer;
    FSortDown: Boolean;
    FModified: Boolean;
    procedure Fill(KeepIndex: Integer);
    procedure ShowRow(It: TListItem; Index: Integer);
    procedure SelectRow(It: TListItem; Show: Boolean);
    function RowIndex(It: TListItem): Integer;
    function ColumnAt(X: Integer): Integer;
    function NextId: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Load(const Items: TSdStringItems);
    { the strings to write: the ones with a text (an empty text is no string of the table) }
    function Strings: TSdStringItems;
    procedure StartEdit(It: TListItem; Col: Integer);
    procedure EndEdit(Accept: Boolean);
    { ISdResEditor }
    function EditorModified: Boolean;
    procedure EditorSaved;
    function EditorCheck(Show: Boolean): string;
    procedure EditorFocus;
    function EditorTestText: string;
    function EditorBar: TWinControl;
    function EditorStatus: TWinControl;
  end;

{ a text with its line breaks, tabs and backslashes written \n, \r, \t, \\ / back }
function EscapeText(const S: string): string;
function UnescapeText(const S: string): string;

implementation

uses
  Math, CommCtrl, SdUI, SdEncoding, SdIcons;

{$R *.dfm}

type
  { the edit over a cell: it takes Enter, Esc and Tab itself }
  TCellEditHook = class(TUIWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

  { the list ends an edit when it scrolls (the edit would stay where the cell was) }
  TScrollEnd = class(TUIWindowHook)
  private
    FFrame: TStringTableFrame;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TCellEditHook.Hook(var Message: TMessage);
begin
  if (Message.Msg = CM_WANTSPECIALKEY) and (TCMWantSpecialKey(Message).CharCode in [VK_RETURN, VK_ESCAPE, VK_TAB]) then
  begin
    Message.Result := 1;
    Exit;
  end;
  FOldProc(Message);
  if Message.Msg = WM_GETDLGCODE then Message.Result := Message.Result or DLGC_WANTALLKEYS or DLGC_WANTTAB;
end;

procedure TScrollEnd.Hook(var Message: TMessage);
begin
  case Message.Msg of
    WM_VSCROLL, WM_HSCROLL, WM_MOUSEWHEEL:
      FFrame.EndEdit(True);
  end;
  FOldProc(Message);
end;

{ written into a string of the longest length the result can have (each character escaped), cut
  at the end - not grown a character at a time (every row of a table goes through it at each
  refill of the list) }
function EscapeText(const S: string): string;
var
  I, N: Integer;
  E: Char;
begin
  SetLength(Result, 2 * Length(S));
  N := 0;
  for I := 1 to Length(S) do
  begin
    case S[I] of
      #10: E := 'n';
      #13: E := 'r';
      #9: E := 't';
      '\': E := '\';
    else
      E := #0;
    end;
    Inc(N);
    if E = #0 then Result[N] := S[I]
    else
    begin
      Result[N] := '\';
      Inc(N);
      Result[N] := E;
    end;
  end;
  SetLength(Result, N);
end;

{ ... backwards: never longer than S }
function UnescapeText(const S: string): string;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    Inc(N);
    if (S[I] = '\') and (I < Length(S)) then
    begin
      Inc(I);
      case S[I] of
        'n': Result[N] := #10;
        'r': Result[N] := #13;
        't': Result[N] := #9;
        '\': Result[N] := '\';
      else
        Result[N] := '\';
        Inc(N);
        Result[N] := S[I];
      end;
    end
    else
      Result[N] := S[I];
    Inc(I);
  end;
  SetLength(Result, N);
end;


constructor TStringTableFrame.Create(AOwner: TComponent);
var
  H: TScrollEnd;
begin
  inherited Create(AOwner);
  { the command icons first: UIPrepareFrame gives the bar its look and the disabled images }
  TopBar.Images := IconList;
  UIPrepareFrame(Self);
  { the edit lies over the list's cells: the list's child (a .dfm cannot nest a control in a list view) }
  CellEdit.Parent := List;
  TCellEditHook.Create(CellEdit, True);
  H := TScrollEnd.Create(List, True);
  H.FFrame := Self;
  FSortCol := 0;
end;

procedure TStringTableFrame.Load(const Items: TSdStringItems);
begin
  FItems := Copy(Items, 0, Length(Items));
  FModified := False;
  Fill(-1);
end;

function TStringTableFrame.Strings: TSdStringItems;
var
  I, N: Integer;
begin
  EndEdit(True);
  Result := nil;
  SetLength(Result, Length(FItems));
  N := 0;
  for I := 0 to High(FItems) do
    { an id outside 0 ... 65535 is no string of a table (EditorCheck says so before a save; a
      compile takes the page unsaved) }
    if (FItems[I].Id >= 0) and (FItems[I].Id <= 65535) and (FItems[I].Text <> '') then
    begin
      Result[N] := FItems[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

function TStringTableFrame.RowIndex(It: TListItem): Integer;
begin
  if It = nil then Result := -1 else Result := Integer(It.Data);
end;

function TStringTableFrame.ColumnAt(X: Integer): Integer;
begin
  if X + GetScrollPos(List.Handle, SB_HORZ) < List.Columns[0].Width then Result := 0 else Result := 1;
end;

procedure TStringTableFrame.ShowRow(It: TListItem; Index: Integer);
begin
  It.Caption := IntToStr(FItems[Index].Id);
  if It.SubItems.Count = 0 then It.SubItems.Add('');
  It.SubItems[0] := EscapeText(WideToIde(FItems[Index].Text));
  It.Data := Pointer(Index);
end;

{ It the one row chosen, with the caret; Show: scrolled into view }
procedure TStringTableFrame.SelectRow(It: TListItem; Show: Boolean);
begin
  List.Selected := nil;
  It.Selected := True;
  It.Focused := True;
  if Show then It.MakeVisible(False);
end;

{ the rows that Find lets through, sorted; KeepIndex: the item chosen afterwards (-1 the first) }
procedure TStringTableFrame.Fill(KeepIndex: Integer);
var
  I: Integer;
  F: string;
  It: TListItem;
begin
  EndEdit(True);
  F := AnsiLowerCase(Trim(edFind.Text));
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    for I := 0 to High(FItems) do
    begin
      if FItems[I].Id < -1 then Continue;
      if (F <> '') and (Pos(F, IntToStr(FItems[I].Id) + #1 + AnsiLowerCase(EscapeText(WideToIde(FItems[I].Text)))) = 0) then
        Continue;
      It := List.Items.Add;
      ShowRow(It, I);
    end;
    List.AlphaSort;
  finally
    List.Items.EndUpdate;
  end;
  UIListSortArrow(List, FSortCol, not FSortDown);
  It := nil;
  for I := 0 to List.Items.Count - 1 do
    if RowIndex(List.Items[I]) = KeepIndex then It := List.Items[I];
  if (It = nil) and (List.Items.Count > 0) then It := List.Items[0];
  if It <> nil then SelectRow(It, True);
end;

procedure TStringTableFrame.edFindChange(Sender: TObject);
begin
  Fill(RowIndex(List.Selected));
end;

procedure TStringTableFrame.ListColumnClick(Sender: TObject; Column: TListColumn);
begin
  EndEdit(True);
  if Column.Index = FSortCol then FSortDown := not FSortDown
  else
  begin
    FSortCol := Column.Index;
    FSortDown := False;
  end;
  List.AlphaSort;
  UIListSortArrow(List, FSortCol, not FSortDown);
end;

procedure TStringTableFrame.ListCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer;
  var Compare: Integer);
var
  A, B: Integer;
begin
  A := RowIndex(Item1);
  B := RowIndex(Item2);
  if FSortCol = 0 then Compare := FItems[A].Id - FItems[B].Id
  else Compare := AnsiCompareText(Item1.SubItems[0], Item2.SubItems[0]);
  if Compare = 0 then Compare := FItems[A].Id - FItems[B].Id;
  if FSortDown then Compare := -Compare;
end;

procedure TStringTableFrame.ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FClickCol := ColumnAt(X);
end;

procedure TStringTableFrame.ListDblClick(Sender: TObject);
begin
  if List.Selected <> nil then StartEdit(List.Selected, FClickCol);
end;

{ Del in the list deletes the chosen rows (an edit box keeps its own Del) }
procedure TStringTableFrame.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_DELETE) and (Shift = []) and EditDeleteCommand.Enabled then
  begin
    EditDeleteCommand.Execute;
    Key := 0;
  end;
end;

{ an edit over the cell: the text in its written form }
procedure TStringTableFrame.StartEdit(It: TListItem; Col: Integer);
var
  R: TRect;
begin
  EndEdit(True);
  if It = nil then Exit;
  It.MakeVisible(False);
  if Col = 0 then ListView_GetItemRect(List.Handle, It.Index, R, LVIR_LABEL)
  else ListView_GetSubItemRect(List.Handle, It.Index, Col, LVIR_LABEL, @R);
  FEditRow := It;
  FEditCol := Col;
  if Col = 0 then CellEdit.Text := It.Caption else CellEdit.Text := It.SubItems[0];
  CellEdit.SetBounds(R.Left, R.Top - 1, Max(R.Right - R.Left, 40), R.Bottom - R.Top + 2);
  CellEdit.Visible := True;
  CellEdit.SetFocus;
  CellEdit.SelectAll;
end;

{ the edit's text into the cell (Accept), or the cell as it was }
procedure TStringTableFrame.EndEdit(Accept: Boolean);
var
  It: TListItem;
  I: Integer;
  W: WideString;
begin
  if (CellEdit = nil) or not CellEdit.Visible then Exit;
  It := FEditRow;
  FEditRow := nil;
  CellEdit.Visible := False;
  if Accept and (It <> nil) then
  begin
    I := RowIndex(It);
    if FEditCol = 0 then
    begin
      if Trim(CellEdit.Text) <> It.Caption then
      begin
        FItems[I].Id := StrToIntDef(Trim(CellEdit.Text), -1);
        if FItems[I].Id < 0 then FItems[I].Id := -1;    // -2 marks a deleted row: never typed
        It.Caption := Trim(CellEdit.Text);
        FModified := True;
      end;
    end
    else if CellEdit.Text <> It.SubItems[0] then
    begin
      W := ToWide(UnescapeText(CellEdit.Text), CP_ACP);
      FItems[I].Text := W;
      It.SubItems[0] := EscapeText(WideToIde(W));
      FModified := True;
    end;
  end;
  if List.CanFocus then List.SetFocus;
end;

procedure TStringTableFrame.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  It: TListItem;
  Col: Integer;
begin
  case Key of
    VK_RETURN:
      EndEdit(True);
    VK_ESCAPE:
      EndEdit(False);
    VK_TAB:
      begin
        It := FEditRow;
        Col := FEditCol;
        EndEdit(True);
        if It = nil then Exit;
        { the next cell: the text after the id, the next row's id after the text (Shift: back) }
        if ssShift in Shift then
        begin
          if Col = 1 then Col := 0
          else if It.Index > 0 then
          begin
            It := List.Items[It.Index - 1];
            Col := 1;
          end;
        end
        else if Col = 0 then Col := 1
        else if It.Index < List.Items.Count - 1 then
        begin
          It := List.Items[It.Index + 1];
          Col := 0;
        end;
        SelectRow(It, False);             // StartEdit brings it into view
        StartEdit(It, Col);
      end;
  else
    Exit;
  end;
  Key := 0;
end;

procedure TStringTableFrame.EditExit(Sender: TObject);
begin
  EndEdit(True);
end;

function TStringTableFrame.NextId: Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to High(FItems) do
    if FItems[I].Id >= Result then Result := FItems[I].Id + 1;
  if Result > $FFFF then Result := 0;
end;

procedure TStringTableFrame.aAddExecute(Sender: TObject);
var
  I: Integer;
begin
  EndEdit(True);
  edFind.Text := '';
  I := Length(FItems);
  SetLength(FItems, I + 1);
  FItems[I].Id := NextId;
  FItems[I].Text := '';
  FModified := True;
  Fill(I);
  if List.Selected <> nil then StartEdit(List.Selected, 1);
end;

procedure TStringTableFrame.aDeleteExecute(Sender: TObject);
var
  I, N: Integer;
begin
  EndEdit(True);
  if List.SelCount = 0 then Exit;
  N := List.Selected.Index;
  for I := 0 to List.Items.Count - 1 do
    if List.Items[I].Selected then FItems[RowIndex(List.Items[I])].Id := -2;
  FModified := True;
  Fill(-1);
  if N >= List.Items.Count then N := List.Items.Count - 1;
  if N >= 0 then SelectRow(List.Items[N], False);
end;

procedure TStringTableFrame.aDeleteUpdate(Sender: TObject);
begin
  EditDeleteCommand.Enabled := (List.SelCount > 0) and not CellEdit.Visible;
end;

{ F2: the text of the chosen row (as Visual Studio's) }
procedure TStringTableFrame.aEditExecute(Sender: TObject);
begin
  if List.Selected <> nil then StartEdit(List.Selected, 1);
end;

procedure TStringTableFrame.aEditUpdate(Sender: TObject);
begin
  aEdit.Enabled := (List.Selected <> nil) and not CellEdit.Visible;
end;

function TStringTableFrame.EditorModified: Boolean;
begin
  Result := FModified;
end;

procedure TStringTableFrame.EditorSaved;
begin
  FModified := False;
end;

{ every id 0 ... 65535 and once only; Show: the row of the first one that is not is chosen }
function TStringTableFrame.EditorCheck(Show: Boolean): string;
var
  I, J, A, Bad: Integer;
begin
  EndEdit(True);
  Result := '';
  Bad := -1;
  for I := 0 to High(FItems) do
  begin
    A := FItems[I].Id;
    if A = -2 then Continue;
    if (A < 0) or (A > $FFFF) then
    begin
      Result := 'An id is a number from 0 to 65535.';
      Bad := I;
      Break;
    end;
    for J := I + 1 to High(FItems) do
      if FItems[J].Id = A then
      begin
        Result := Format('The id %d is there twice.', [A]);
        Bad := J;
        Break;
      end;
    if Bad >= 0 then Break;
  end;
  if (Bad < 0) or not Show then Exit;
  if edFind.Text <> '' then edFind.Text := '';
  for I := 0 to List.Items.Count - 1 do
    if RowIndex(List.Items[I]) = Bad then SelectRow(List.Items[I], True);
  if List.CanFocus then List.SetFocus;
end;

procedure TStringTableFrame.EditorFocus;
begin
  if List.CanFocus then List.SetFocus;
end;

{ the strip with the tool bar and the find box }
function TStringTableFrame.EditorBar: TWinControl;
begin
  Result := TopPanel;
end;

{ none: a page shows a status line only when it has something to say (the list's hint tells how
  cells are edited) }
function TStringTableFrame.EditorStatus: TWinControl;
begin
  Result := nil;
end;

function TStringTableFrame.EditorTestText: string;
var
  I: Integer;
begin
  Result := Format('rows=%d|selected=%d|editing=%d,%d|modified=%d|sort=%d,%d|', [List.Items.Count,
    List.SelCount, Ord(CellEdit.Visible), FEditCol, Ord(FModified), FSortCol, Ord(FSortDown)]);
  for I := 0 to List.Items.Count - 1 do
    Result := Result + List.Items[I].Caption + '=' + List.Items[I].SubItems[0] + ';';
end;

end.
