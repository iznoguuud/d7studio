{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTodoView;

{ D7 Studio - the To-Do List view (Delphi 7's TToDoListWindow): the items of the To-Do List
  (SdTodo's TSdTodoList, which the IDE collects) with their check boxes, the sorted column's arrow,
  the whole text of a cut cell as a hint, the local menu and the actions only that menu has. A
  form made once (its list, menu and actions in the .dfm), docked by the IDE - a child window then,
  without a border. What needs the IDE - the items' files, the project, the experts' To-Do
  managers - goes through Host (TTodoHost); the dock's commands at the menu's end are the IDE's
  (TMainForm.AddDockItems). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, CommCtrl, Menus, ActnList,
  Clipbrd, SdUI, SdIcons, SdTodo, SdOtaCore, SdOtaToDo, SdDialogs;

const
  WM_SDTODOCHECK = WM_APP + 86;      // an item's check box was clicked: its comment changes (WMTodoCheck)

type
  { what the view asks of the IDE }
  TTodoHost = class
  public
    { Edit and Delete may change the item (nil: none chosen) }
    function CanEdit(Item: TSdTodoItem): Boolean; virtual; abstract;
    function HasProject: Boolean; virtual; abstract;
    procedure Add; virtual; abstract;
    procedure Edit(Item: TSdTodoItem); virtual; abstract;
    { the item's comment becomes NewComment ('': taken out) }
    procedure ChangeComment(Item: TSdTodoItem; const NewComment: string); virtual; abstract;
    { the line of the item's comment }
    procedure OpenSource(Item: TSdTodoItem); virtual; abstract;
    { an expert's item (SdOtaToDo): a question or a change, the list kept while the expert runs }
    function ExpertQuery(Item: TSdTodoItem; Action: TSdTodoAction): Boolean; virtual; abstract;
    { ... a command: the experts' items collected again after it }
    procedure ExpertCommand(Item: TSdTodoItem; Action: TSdTodoAction); virtual; abstract;
    { ... its image in R; False: it raised (it is not asked again) }
    function ExpertDrawImage(Item: TSdTodoItem; Canvas: TCanvas; const R: TRect): Boolean; virtual; abstract;
    { the experts' items collected again and shown }
    procedure ExpertsChanged; virtual; abstract;
  end;

  TTodoListView = class(TForm)
    TodoList: TListView;
    Actions: TActionList;
    aTodoOpen: TAction;
    aTodoAdd: TAction;
    aTodoEdit: TAction;
    aTodoDelete: TAction;
    aTodoSortItem: TAction;
    aTodoSortStatus: TAction;
    aTodoSortType: TAction;
    aTodoSortPriority: TAction;
    aTodoSortModule: TAction;
    aTodoSortOwner: TAction;
    aTodoSortCategory: TAction;
    aTodoFilterCategories: TAction;
    aTodoFilterOwners: TAction;
    aTodoFilterTypes: TAction;
    aTodoShowCompleted: TAction;
    aTodoTooltips: TAction;
    aTodoCopyText: TAction;
    aTodoCopyHtml: TAction;
    aTodoTableProps: TAction;
    TodoPopup: TPopupMenu;
    pmTodo1: TMenuItem;
    pmTodo2: TMenuItem;
    pmTodo3: TMenuItem;
    pmTodo4: TMenuItem;
    pmTodo5: TMenuItem;
    pmTodo6: TMenuItem;
    pmTodo7: TMenuItem;
    pmTodo8: TMenuItem;
    pmTodo9: TMenuItem;
    pmTodo10: TMenuItem;
    pmTodo11: TMenuItem;
    pmTodo12: TMenuItem;
    pmTodo13: TMenuItem;
    pmTodo14: TMenuItem;
    pmTodo15: TMenuItem;
    pmTodo16: TMenuItem;
    pmTodo17: TMenuItem;
    pmTodo18: TMenuItem;
    pmTodo19: TMenuItem;
    pmTodo20: TMenuItem;
    pmTodo21: TMenuItem;
    pmTodo22: TMenuItem;
    pmTodo23: TMenuItem;
    pmTodo24: TMenuItem;
    procedure TodoListColumnClick(Sender: TObject; Column: TListColumn);
    procedure TodoListDblClick(Sender: TObject);
    procedure TodoListChange(Sender: TObject; Item: TListItem; Change: TItemChange);
    procedure TodoListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TodoPopupPopup(Sender: TObject);
    procedure ItemCommand(Sender: TObject);
    procedure SortCommand(Sender: TObject);
    procedure FilterCommand(Sender: TObject);
    procedure ViewCommand(Sender: TObject);
  private
    FTodo: TSdTodoList;
    FHost: TTodoHost;
    FFilling: Boolean;                 // the rows are made: their check boxes change nothing
    FCheckFile: string;                // the item whose check box was clicked (by its place) ...
    FCheckLine: Integer;
    FCheckDone: Boolean;               // ... and what the box says now
    FCheckExt: IInterface;             // ... an expert's item: its INTAToDoItem
    FOnMenuPopup: TNotifyEvent;
    procedure WMTodoCheck(var Message: TMessage); message WM_SDTODOCHECK;
    procedure CopyText;
    procedure Filter(Kind: TSdTodoFilter);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear;
    { the items the filters let through, in their order: the chosen item stays chosen; the header
      shows the order's column and direction }
    procedure Fill; overload;
    { ... with the item of that file and line chosen (an expert's: of that interface) }
    procedure Fill(const OldFile: string; OldLine: Integer; const OldExt: IInterface = nil); overload;
    { the chosen item; nil: none }
    function SelectedItem: TSdTodoItem;
    { the chosen item by its place (an expert's by its interface): the items may be made anew }
    procedure SelectionKey(out F: string; out L: Integer; out X: IInterface);
    { the item of a row; nil: none }
    function RowItem(Row: Integer): TSdTodoItem;
    { Delphi greys an item whose CanEdit says no (an expert's: what it said when it was collected) }
    function Editable(Item: TSdTodoItem): Boolean;
    procedure DrawExpertImage(Item: TSdTodoItem; DC: HDC; Row: Integer);
    { Show ToolTips when Clipped at P (the list's client coordinates): the cell's whole text }
    function CellHint(P: TPoint; out Text: string; out R: TRect): Boolean;
    { Edit and Delete shown while an item is chosen; Ask: an expert's item is asked (else they are
      off for it) }
    procedure UpdateCommands(Ask: Boolean);
    { a package goes (Module; 0: the IDE ends): a check of its expert's item is forgotten }
    procedure DropExpertModule(Module: HMODULE);
    property Todo: TSdTodoList read FTodo write FTodo;
    property Host: TTodoHost read FHost write FHost;
    { the menu opens (before its own states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

{$R *.dfm}

const
  { the columns' sort orders: a click on a column's header sorts by it (Delphi's GridMouseUp) }
  TodoColumnSort: array[0..4] of TSdTodoSort = (tsActionItem, tsPriority, tsModule, tsOwner, tsCategory);
  { what a list view draws around a text, measured (it ends the text with ... when it does not
    fit): 4 in the first column's label, 10 in a column's cell }
  TodoLabelMargin = 4;
  TodoCellMargin = 10;

type
  { the rows (Delphi's TToDoListWindow.GridDrawCell): grey while the item cannot be edited, struck
    out once it is done; an expert's item draws its image (INTAToDoItem.DrawImage) in the image
    place after its check box. The list's custom drawing is taken here, before the VCL's (the list
    has no drawing events) }
  TTodoDraw = class(TUIWindowHook)
  private
    FView: TTodoListView;
    FStrike: HFONT;              // the list's font struck out ...
    FStrikeOf: HFONT;            // ... made from this font
    FOldFont: HFONT;             // the row's font, given back after the row
    function StrikeFont: HFONT;
  protected
    procedure Hook(var Message: TMessage); override;
  public
    destructor Destroy; override;
  end;

destructor TTodoDraw.Destroy;
begin
  if FStrike <> 0 then DeleteObject(FStrike);
  inherited;
end;

function TTodoDraw.StrikeFont: HFONT;
var
  LF: TLogFont;
  F: HFONT;
begin
  F := FView.TodoList.Font.Handle;
  if (FStrike = 0) or (FStrikeOf <> F) then
  begin
    if FStrike <> 0 then DeleteObject(FStrike);
    FStrike := 0;
    if GetObject(F, SizeOf(LF), @LF) <> 0 then
    begin
      LF.lfStrikeOut := 1;
      FStrike := CreateFontIndirect(LF);
    end;
    FStrikeOf := F;
  end;
  Result := FStrike;
end;

procedure TTodoDraw.Hook(var Message: TMessage);
var
  CD: PNMLVCustomDraw;
  It: TSdTodoItem;
  F: HFONT;
begin
  if (Message.Msg <> CN_NOTIFY) or (TWMNotify(Message).NMHdr^.code <> NM_CUSTOMDRAW) then
  begin
    FOldProc(Message);
    Exit;
  end;
  CD := PNMLVCustomDraw(TWMNotify(Message).NMHdr);
  Message.Result := CDRF_DODEFAULT;
  case CD^.nmcd.dwDrawStage of
    CDDS_PREPAINT:
      Message.Result := CDRF_NOTIFYITEMDRAW;
    CDDS_ITEMPREPAINT:
      begin
        It := FView.RowItem(CD^.nmcd.dwItemSpec);
        if It = nil then Exit;
        if not FView.Editable(It) then CD^.clrText := ColorToRGB(clGrayText);
        if It.Done then
        begin
          F := StrikeFont;
          if F <> 0 then
          begin
            FOldFont := SelectObject(CD^.nmcd.hdc, F);
            Message.Result := CDRF_NEWFONT or CDRF_NOTIFYPOSTPAINT;
          end;
        end;
        if It.Ext <> nil then Message.Result := Message.Result or CDRF_NOTIFYPOSTPAINT;
      end;
    CDDS_ITEMPOSTPAINT:
      begin
        if FOldFont <> 0 then
        begin
          SelectObject(CD^.nmcd.hdc, FOldFont);
          FOldFont := 0;
        end;
        It := FView.RowItem(CD^.nmcd.dwItemSpec);
        if (It <> nil) and (It.Ext <> nil) then FView.DrawExpertImage(It, CD^.nmcd.hdc, CD^.nmcd.dwItemSpec);
      end;
  end;
end;

{ ---------------------------------------------------------------- TTodoListView }

constructor TTodoListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only - Delphi's image place in every
    row (an expert's item draws its own: TTodoDraw) }
  TodoList.SmallImages := IconList;
  Actions.Images := IconList;
  TodoPopup.Images := IconList;
  UIOwnerDrawMenus(Self);
  TTodoDraw.Create(TodoList, True).FView := Self;
end;

{ No flicker: the list fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TTodoListView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the list covers the whole view: nothing of the form shows, nothing to erase }
procedure TTodoListView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TTodoListView.Clear;
begin
  TodoList.Items.Clear;
end;

procedure TTodoListView.Fill;
var
  F: string;
  L: Integer;
  X: IInterface;
begin
  SelectionKey(F, L, X);
  Fill(F, L, X);
end;

procedure TTodoListView.Fill(const OldFile: string; OldLine: Integer; const OldExt: IInterface);
var
  I, Sel, Top, C: Integer;
  It: TListItem;
  Item: TSdTodoItem;
begin
  Top := -1;
  if TodoList.HandleAllocated then Top := ListView_GetTopIndex(TodoList.Handle);
  Sel := -1;
  FFilling := True;
  TodoList.Items.BeginUpdate;
  try
    TodoList.Items.Clear;
    for I := 0 to FTodo.Count - 1 do
    begin
      Item := FTodo[I];
      It := TodoList.Items.Add;
      It.Caption := Item.Text;
      It.Checked := Item.Done;
      It.ImageIndex := TodoImageIndex(Item);
      if Item.Priority > 0 then It.SubItems.Add(IntToStr(Item.Priority)) else It.SubItems.Add('');
      It.SubItems.Add(Item.ModuleCaption);
      It.SubItems.Add(Item.Owner);
      It.SubItems.Add(Item.Category);
      It.Data := Item;
      if (Sel < 0) and (Item.Ext = OldExt) and ((OldExt <> nil) or ((Item.Line = OldLine) and
        SameText(Item.FileName, OldFile))) then Sel := I;
    end;
    if Sel >= 0 then
    begin
      TodoList.Selected := TodoList.Items[Sel];
      TodoList.ItemFocused := TodoList.Selected;
    end;
  finally
    TodoList.Items.EndUpdate;
    FFilling := False;
  end;
  { the rows that were at the top stay there }
  if (Top > 0) and (Top < TodoList.Items.Count) then
    ListView_Scroll(TodoList.Handle, 0, TodoList.Items[Top].DisplayRect(drBounds).Top - TodoList.Items[0].DisplayRect(drBounds).Top);
  { the header: the sorted column's arrow, in the theme's drawing }
  C := -1;
  for I := High(TodoColumnSort) downto 0 do
    if TodoColumnSort[I] = FTodo.SortOrder then C := I;
  UIListSortArrow(TodoList, C, FTodo.Ascending);
end;

function TTodoListView.SelectedItem: TSdTodoItem;
begin
  if TodoList.Selected = nil then Result := nil else Result := TSdTodoItem(TodoList.Selected.Data);
end;

procedure TTodoListView.SelectionKey(out F: string; out L: Integer; out X: IInterface);
var
  It: TSdTodoItem;
begin
  F := '';
  L := 0;
  X := nil;
  It := SelectedItem;
  if It = nil then Exit;
  F := It.FileName;
  L := It.Line;
  X := It.Ext;
end;

function TTodoListView.RowItem(Row: Integer): TSdTodoItem;
begin
  if (Row >= 0) and (Row < TodoList.Items.Count) then Result := TSdTodoItem(TodoList.Items[Row].Data)
  else Result := nil;
end;

function TTodoListView.Editable(Item: TSdTodoItem): Boolean;
begin
  if Item.Ext <> nil then Result := Item.ExtEditable else Result := FHost.CanEdit(Item);
end;

{ an expert's item in its row's image place: the place filled with the window's colour, then its
  DrawImage in the image list's size (Delphi's GridDrawCell); one that raised is not asked again }
procedure TTodoListView.DrawExpertImage(Item: TSdTodoItem; DC: HDC; Row: Integer);
var
  R: TRect;
  C: TCanvas;
  Saved: Integer;
begin
  if Item.ExtNoDraw or (TodoList.SmallImages = nil) or
    not ListView_GetItemRect(TodoList.Handle, Row, R, LVIR_ICON) then Exit;
  Saved := SaveDC(DC);
  C := TCanvas.Create;
  try
    C.Handle := DC;
    C.Brush.Color := clWindow;
    C.FillRect(R);
    R.Top := R.Top + (R.Bottom - R.Top - TodoList.SmallImages.Height) div 2;
    R.Right := R.Left + TodoList.SmallImages.Width;
    R.Bottom := R.Top + TodoList.SmallImages.Height;
    if not FHost.ExpertDrawImage(Item, C, R) then Item.ExtNoDraw := True;
  finally
    C.Handle := 0;
    C.Free;
    RestoreDC(DC, Saved);
  end;
end;

{ Show ToolTips when Clipped (Delphi's GridHint): over a cell whose text the column cuts - or the
  text of an item of several lines (the hint shows its lines) - the whole text }
function TTodoListView.CellHint(P: TPoint; out Text: string; out R: TRect): Boolean;
var
  HT: TLVHitTestInfo;
  It: TListItem;
  W: Integer;
  S: string;
begin
  Result := False;
  if not FTodo.ShowHints or not TodoList.HandleAllocated then Exit;
  FillChar(HT, SizeOf(HT), 0);
  HT.pt := P;
  if ListView_SubItemHitTest(TodoList.Handle, @HT) < 0 then Exit;
  if (HT.iItem < 0) or (HT.iItem >= TodoList.Items.Count) then Exit;
  It := TodoList.Items[HT.iItem];
  if HT.iSubItem = 0 then Text := It.Caption
  else if HT.iSubItem - 1 < It.SubItems.Count then Text := It.SubItems[HT.iSubItem - 1]
  else Exit;
  if Text = '' then Exit;
  if HT.iSubItem = 0 then ListView_GetItemRect(TodoList.Handle, HT.iItem, R, LVIR_LABEL)
  else ListView_GetSubItemRect(TodoList.Handle, HT.iItem, HT.iSubItem, LVIR_BOUNDS, @R);
  TodoList.Canvas.Font := TodoList.Font;
  W := TodoList.Canvas.TextWidth(Text);
  if HT.iSubItem = 0 then Inc(W, TodoLabelMargin) else Inc(W, TodoCellMargin);
  Result := W > R.Right - R.Left;
  if HT.iSubItem = 0 then
  begin
    S := TrimRight(TSdTodoItem(It.Data).RawText);
    if Pos(#10, S) > 0 then
    begin
      Text := S;
      Result := True;
    end;
  end;
end;

{ Delphi's ToDoItemsUpdate: Edit and Delete shown while an item is chosen, enabled when they can
  change it; Open for an item with a source; Add with a project. An expert's item answers itself
  (CanShow and IsValid, CanEdit and IsValid, CanDelete) }
procedure TTodoListView.UpdateCommands(Ask: Boolean);
var
  It: TSdTodoItem;
begin
  It := SelectedItem;
  aTodoOpen.Enabled := (It <> nil) and not It.InTodoFile;
  aTodoEdit.Visible := It <> nil;
  aTodoEdit.Enabled := FHost.CanEdit(It);
  aTodoDelete.Visible := It <> nil;
  aTodoDelete.Enabled := aTodoEdit.Enabled;
  aTodoAdd.Enabled := FHost.HasProject;
  if (It = nil) or (It.Ext = nil) then Exit;
  aTodoOpen.Enabled := False;
  aTodoEdit.Enabled := False;
  aTodoDelete.Enabled := False;
  if not Ask then Exit;
  aTodoOpen.Enabled := FHost.ExpertQuery(It, taCanShow);
  aTodoEdit.Enabled := FHost.ExpertQuery(It, taCanEdit);
  aTodoDelete.Enabled := FHost.ExpertQuery(It, taCanDelete);
end;

procedure TTodoListView.DropExpertModule(Module: HMODULE);
begin
  if (FCheckExt <> nil) and ((Module = 0) or (InterfaceModule(FCheckExt) = Module)) then FCheckExt := nil;
end;

{ the menu: the dock's commands (the IDE), the items' commands, Sort, Show Completed Items, Show
  ToolTips when Clipped, Copy As }
procedure TTodoListView.TodoPopupPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  UpdateCommands(True);
  aTodoSortItem.Checked := FTodo.SortOrder = tsActionItem;
  aTodoSortStatus.Checked := FTodo.SortOrder = tsStatus;
  aTodoSortType.Checked := FTodo.SortOrder = tsType;
  aTodoSortPriority.Checked := FTodo.SortOrder = tsPriority;
  aTodoSortModule.Checked := FTodo.SortOrder = tsModule;
  aTodoSortOwner.Checked := FTodo.SortOrder = tsOwner;
  aTodoSortCategory.Checked := FTodo.SortOrder = tsCategory;
  aTodoShowCompleted.Checked := FTodo.ShowCompleted;
  aTodoTooltips.Checked := FTodo.ShowHints;
  aTodoCopyText.Enabled := TodoList.Items.Count > 0;
  aTodoCopyHtml.Enabled := aTodoCopyText.Enabled;           // Delphi's: as Copy As | Text
end;

{ Open, Add, Edit, Delete: an expert's item through its expert, D7 Studio's through the IDE }
procedure TTodoListView.ItemCommand(Sender: TObject);
var
  It: TSdTodoItem;
begin
  It := SelectedItem;
  if Sender = aTodoOpen then
  begin
    { an expert's item: its Show; D7 Studio's: the line of its comment }
    if (It <> nil) and (It.Ext <> nil) then FHost.ExpertCommand(It, taShow) else TodoListDblClick(TodoList);
  end
  else if Sender = aTodoAdd then FHost.Add
  else if Sender = aTodoEdit then
  begin
    if (It <> nil) and (It.Ext <> nil) then FHost.ExpertCommand(It, taEdit) else FHost.Edit(It);
  end
  else if Sender = aTodoDelete then
  begin
    { Delphi's: the comment with its delimiters (a // one with its line break), no question; an
      expert's item: its Delete }
    if (It <> nil) and (It.Ext <> nil) then FHost.ExpertCommand(It, taDelete)
    else if FHost.CanEdit(It) then FHost.ChangeComment(It, '');
  end;
end;

{ Delphi's Sort: the action's Tag is its order; the same order again turns its direction round }
procedure TTodoListView.SortCommand(Sender: TObject);
begin
  FTodo.SetSort(TSdTodoSort(TAction(Sender).Tag));
  Fill;
end;

procedure TTodoListView.FilterCommand(Sender: TObject);
begin
  Filter(TSdTodoFilter(TAction(Sender).Tag));
end;

{ Show Completed Items, Show ToolTips when Clipped, Copy As | Text and HTML Table, Table
  Properties }
procedure TTodoListView.ViewCommand(Sender: TObject);
begin
  if Sender = aTodoShowCompleted then
  begin
    FTodo.SetShowCompleted(not FTodo.ShowCompleted);
    Fill;
  end
  else if Sender = aTodoTooltips then FTodo.ShowHints := not FTodo.ShowHints
  else if Sender = aTodoCopyHtml then
  begin
    { Delphi's: the text of the table (CF_TEXT), and only while a project is open }
    if FHost.HasProject then Clipboard.AsText := FTodo.Table.Html(FTodo);
  end
  else if Sender = aTodoTableProps then TableOptionsDialog(Application.MainForm, FTodo.Table)
  else if Sender = aTodoCopyText then CopyText;
end;

{ Copy As | Text: the rows, their columns' texts separated by tabs }
procedure TTodoListView.CopyText;
var
  All: TStringList;
  I, K: Integer;
  S: string;
begin
  All := TStringList.Create;
  try
    for I := 0 to TodoList.Items.Count - 1 do
    begin
      S := TodoList.Items[I].Caption;
      for K := 0 to TodoList.Items[I].SubItems.Count - 1 do
        if K < TodoList.Columns.Count - 1 then S := S + #9 + TodoList.Items[I].SubItems[K];
      All.Add(S);
    end;
    Clipboard.AsText := All.Text;
  finally
    All.Free;
  end;
end;

{ Filter | Categories..., Owners..., Item Types...: Delphi's Filter To-Do List with the values
  of the items shown and those hidden; what is unchecked is hidden }
procedure TTodoListView.Filter(Kind: TSdTodoFilter);
const
  Prompts: array[TSdTodoFilter] of string = ('&Filter by Category:', '&Filter by Owner:', '&Filter by Origin:');
var
  Values, Hidden: TStringList;
  Shown: TList;
begin
  Values := TStringList.Create;
  Hidden := TStringList.Create;
  Shown := TList.Create;
  try
    FTodo.GetFilter(Kind, Values, Shown);
    if not TodoFilterDialog(Application.MainForm, Prompts[Kind], Values, Shown, Hidden) then Exit;
    FTodo.SetHidden(Kind, Hidden);
    Fill;
  finally
    Shown.Free;
    Hidden.Free;
    Values.Free;
  end;
end;

procedure TTodoListView.TodoListColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index > High(TodoColumnSort) then Exit;
  FTodo.SetSort(TodoColumnSort[Column.Index]);
  Fill;
end;

{ a double click (and Open): the line of the item; an item of the To-Do file has no source to
  show - Delphi edits it; an expert's item: its DoubleClicked }
procedure TTodoListView.TodoListDblClick(Sender: TObject);
var
  It: TSdTodoItem;
begin
  It := SelectedItem;
  if It = nil then Exit;
  if It.Ext <> nil then FHost.ExpertCommand(It, taDoubleClicked)
  else if It.InTodoFile then FHost.Edit(It)
  else FHost.OpenSource(It);
end;

{ Enter: Open (Delphi's GridKeyPress) }
procedure TTodoListView.TodoListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key <> VK_RETURN) or (Shift <> []) or (SelectedItem = nil) then Exit;
  Key := 0;
  UpdateCommands(True);
  if aTodoOpen.Enabled then aTodoOpen.Execute;
end;

{ An item's check box clicked: Done or not, written into its comment as Delphi 7's list does - the
  comment changes after the list's notification, by the item's place (the change makes the rows
  anew); one that cannot change (a read-only file) gets its box back from the items }
procedure TTodoListView.TodoListChange(Sender: TObject; Item: TListItem; Change: TItemChange);
begin
  if FFilling or (Change <> ctState) or (Item = nil) or (Item.Data = nil) then Exit;
  if Item.Checked = TSdTodoItem(Item.Data).Done then Exit;
  FCheckFile := TSdTodoItem(Item.Data).FileName;
  FCheckLine := TSdTodoItem(Item.Data).Line;
  FCheckExt := TSdTodoItem(Item.Data).Ext;
  FCheckDone := Item.Checked;
  PostMessage(Handle, WM_SDTODOCHECK, 0, 0);
end;

procedure TTodoListView.WMTodoCheck(var Message: TMessage);
var
  I: Integer;
  T: TSdTodoItem;
  S: string;
  X: IInterface;
begin
  T := nil;
  X := FCheckExt;
  FCheckExt := nil;
  { an expert's item: SetChecked(not GetChecked) when it can be edited (Delphi's GridMouseUp), then
    its items as the expert has them now - a box it refused springs back }
  if X <> nil then
  begin
    for I := 0 to FTodo.Count - 1 do
      if FTodo[I].Ext = X then
      begin
        T := FTodo[I];
        Break;
      end;
    if T <> nil then
    begin
      FHost.ExpertQuery(T, taToggleChecked);
      FHost.ExpertsChanged;
    end
    else
      Fill('', 0, X);
    Exit;
  end;
  for I := 0 to FTodo.Count - 1 do
    if (FTodo[I].Line = FCheckLine) and SameText(FTodo[I].FileName, FCheckFile) then
    begin
      T := FTodo[I];
      Break;
    end;
  if (T <> nil) and (T.Done <> FCheckDone) and FHost.CanEdit(T) then
  begin
    S := TodoEditComment(T, FCheckDone, T.Priority, T.Owner, T.Category, T.RawText);
    if S <> T.Comment then
    begin
      FHost.ChangeComment(T, S);
      Exit;
    end;
  end;
  Fill(FCheckFile, FCheckLine);      // the boxes as the items are
end;

end.
