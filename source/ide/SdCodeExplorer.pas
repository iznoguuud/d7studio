{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCodeExplorer;

{ D7 Studio - the Code Explorer: Delphi 7's. A form made once (its
  tree, menu, actions and timers in the .dfm), docked by the IDE -
  a child window then, without a border. Its picture of the unit is TCodeInsight.GetExplorer's; the
  categories, the order, the texts and the bold items follow Environment Options | Explorer
  (SdEnvOptions). What reaches beyond the view - the source shown in the editor, New and Rename
  writing it, the picture made again, View Editor, Properties - the IDE carries out (the On...
  events); the dock's commands at the menu's end are the IDE's too (TMainForm.AddDockItems). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, CommCtrl, Menus,
  ActnList, ExtCtrls, SdUI, SdIcons, SdCodeInsight, SdEnvOptions;

type
  { what a node of the tree stands for: an item of the picture, a category's folder, New's edit }
  TExpItemKind = (eiItem, eiFolder, eiNew);

  TExpItem = class
  public
    Kind: TExpItemKind;
    Node: TCIExpNode;             // an item's
    Category: TExpCategory;       // a folder's
    Key: string;                  // what it is, the same in the next tree: its open state goes by it
    Sort: string;                 // its text for the order (a folder's: #255, its place in the list)
    Members: TList;               // a folder's items while the tree is made
    TreeNode: TTreeNode;          // its node (nil: none any more - New's edit ended)
  end;

  { where New makes an item: a member of the class ClassName in the section Access; ClassName '':
    the unit's - a unit of its uses clause when InUses. Parent: the node New's edit goes under }
  TExpNewPlace = record
    Valid: Boolean;
    Parent: TTreeNode;
    ClassName: string;
    Access: TCIExpAccess;
    InUses: Boolean;
  end;

  { TakeFocus: Enter, a double click - the editor takes the focus; else Synchronize with the editor
    moves its caret }
  TExpShowEvent = procedure(Sender: TObject; TopLine, Line, Col: Integer; TakeFocus: Boolean) of object;
  { the source written for what New's edit took (True: done) }
  TExpNewEvent = function(Sender: TObject; const Place: TExpNewPlace; const Text: string): Boolean of object;
  { the source written for Node's new name - ClassName its class or interface ('': the unit's) }
  TExpRenameEvent = function(Sender: TObject; Node: TCIExpNode; const ClassName, NewName: string): Boolean of object;

  TCodeExplorerView = class(TForm)
    Tree: TTreeView;
    Actions: TActionList;
    aExpNew: TAction;
    aExpRename: TAction;
    aExpViewEditor: TAction;
    aExpProperties: TAction;
    ExpPopup: TPopupMenu;
    pmExpNew: TMenuItem;
    pmExpRename: TMenuItem;
    pmExpLine1: TMenuItem;
    pmExpViewEditor: TMenuItem;
    pmExpLine2: TMenuItem;
    pmExpProperties: TMenuItem;
    SearchTimer: TTimer;
    ParseTimer: TTimer;
    FollowTimer: TTimer;
    procedure TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeKeyPress(Sender: TObject; var Key: Char);
    procedure TreeExit(Sender: TObject);
    procedure TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure FollowTimerTimer(Sender: TObject);
    procedure SearchTimerTimer(Sender: TObject);
    procedure ParseTimerTimer(Sender: TObject);
    procedure aExpNewExecute(Sender: TObject);
    procedure aExpNewUpdate(Sender: TObject);
    procedure aExpRenameExecute(Sender: TObject);
    procedure aExpRenameUpdate(Sender: TObject);
    procedure aExpViewEditorExecute(Sender: TObject);
    procedure aExpPropertiesExecute(Sender: TObject);
  private
    FRoot: TCIExpNode;            // the picture shown (owned)
    FItems: TList;                // TExpItem of the tree's nodes (owned)
    FSearch: string;              // what typing looks for
    FEditEnter: Boolean;          // Enter ended the edit running (anything else cancels it)
    FNewPlace: TExpNewPlace;      // New's edit: where it makes the item
    FNewBack: string;             // ... the key of the node chosen before it
    FEditWnd: HWND;               // the edit of New or Rename, hooked (0: none)
    FEditOldProc: Pointer;        // ... the procedure it had
    FEditProc: Pointer;           // EditHook as a window procedure
    FShowTop, FShowLine, FShowCol: Integer;   // the place New's commit shows (posted)
    FSyncing: Boolean;            // the tree chooses a node itself: the editor is not moved by it
    FCaretLine, FCaretCol: Integer;           // the editor's caret, for FollowTimer
    FOnShowSource: TExpShowEvent;
    FOnNew: TExpNewEvent;
    FOnRename: TExpRenameEvent;
    FOnParse: TNotifyEvent;
    FOnViewEditor: TNotifyEvent;
    FOnProperties: TNotifyEvent;
    function NewItem(AKind: TExpItemKind): TExpItem;
    procedure FreeItems;
    function Build(Parent: TTreeNode; const ParentKey: string; Src: TCIExpNode; Fresh: Boolean;
      Known, Open: TStringList): Boolean;
    function AddNode(Parent: TTreeNode; It: TExpItem; const Text: string; Icon: TSdIcon;
      First: Boolean = False): TTreeNode;
    procedure Settle(N: TTreeNode; It: TExpItem; Default, Fresh: Boolean; Known, Open: TStringList);
    function FindKey(const Key: string): TTreeNode;
    function OwnerNode(N: TTreeNode): TTreeNode;
    function Searchable(N: TTreeNode): Boolean;
    function FindFrom(Start: TTreeNode; const Text: string; SkipStart: Boolean): TTreeNode;
    procedure Choose(N: TTreeNode);
    procedure SearchKey(C: Char);
    procedure SearchNext;
    procedure ResetSearch;
    function SourcePlace(N: TTreeNode; out Top, Line, Col: Integer): Boolean;
    procedure ShowSourceOf(N: TTreeNode);
    function NewPlace(N: TTreeNode): TExpNewPlace;
    function CanRename(N: TTreeNode): Boolean;
    procedure ChooseAt(Line, Col: Integer);
    procedure TreeCancelEdit(Sender: TObject; Node: TTreeNode);
    procedure WMExpDropNew(var Message: TMessage); message WM_USER + 1;
    procedure WMExpShowNew(var Message: TMessage); message WM_USER + 2;
    procedure WMExpHookEdit(var Message: TMessage); message WM_USER + 3;
    procedure EditHook(var Message: TMessage);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    { the picture Root shown - taken: the view frees it. Fresh: a unit after none or after a file
      of another kind - every node as new (Delphi's new model); else a node keeps its open state
      and the tree its chosen node and its first row by what they are (Delphi's nodes updated in
      place) }
    procedure ShowExplorer(Root: TCIExpNode; Fresh: Boolean);
    { the unit's text changed, another page came up: OnParse 500 ms after the last call (Delphi's
      parse thread) }
    procedure Modified;
    { an edit of New or Rename ends without a change (a compile starts: Delphi's BeforeCompile) }
    procedure CancelEdit;
    { the editor's caret moved (its page is the unit shown, its text the tree's): with Synchronize with
      the editor the node of the place is chosen after a pause }
    procedure CaretMoved(Line, Col: Integer);
    function Item(Node: TTreeNode): TExpItem;
    property Root: TCIExpNode read FRoot;
    { Enter, a double click: the editor shows TopLine at its top (0: from the text's start) and
      takes the focus with the caret at Line, Col (code insight's columns); a node chosen with
      Synchronize with the editor: the same without the focus (TakeFocus False) }
    property OnShowSource: TExpShowEvent read FOnShowSource write FOnShowSource;
    property OnNew: TExpNewEvent read FOnNew write FOnNew;
    property OnRename: TExpRenameEvent read FOnRename write FOnRename;
    { time to make the picture again (Modified) }
    property OnParse: TNotifyEvent read FOnParse write FOnParse;
    property OnViewEditor: TNotifyEvent read FOnViewEditor write FOnViewEditor;
    property OnProperties: TNotifyEvent read FOnProperties write FOnProperties;
  end;

{ the icon of a node of the picture (Delphi 7's explorer images in the Delphi 7 set) }
function ExplorerIcon(N: TCIExpNode): TSdIcon;
{ the icon of a kind of symbol (the Diagram tab's, the navigation bar's, the Browser's) }
function KindIcon(Kind: TCIKind): TSdIcon;

implementation

{$R *.dfm}

const
  VK_PERIOD = $BE;                // VK_OEM_PERIOD: the key of "." beside the letters

type
  TTreeAccess = class(TTreeView);

  { the keys of the edits of New and Rename }
  TExpTreeHook = class(TUIWindowHook)
  private
    FView: TCodeExplorerView;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TExpTreeHook.Hook(var Message: TMessage);
begin
  { Enter and Esc go to the edit of New or Rename (else they are the form's dialog keys and the
    edit never sees them) }
  if (Message.Msg = CM_WANTSPECIALKEY) and FView.Tree.IsEditing and
    ((TCMWantSpecialKey(Message).CharCode = VK_RETURN) or (TCMWantSpecialKey(Message).CharCode = VK_ESCAPE)) then
  begin
    Message.Result := 1;
    Exit;
  end;
  FOldProc(Message);
end;

function KindIcon(Kind: TCIKind): TSdIcon;
begin
  case Kind of
    ckUnit: Result := iiUnit;
    ckConst, ckEnumValue, ckResourceString: Result := iiConst;
    ckVar, ckParam, ckLocalVar: Result := iiVar;
    ckField: Result := iiField;
    ckType: Result := iiType;
    ckClass: Result := iiClass;
    ckInterface: Result := iiInterface;
    ckRecord: Result := iiRecord;
    ckEnum: Result := iiEnum;
    ckProcedure, ckConstructor, ckDestructor: Result := iiProcedure;
    ckFunction: Result := iiFunction;
    ckProperty: Result := iiProperty;
  else
    Result := iiFolder;
  end;
end;

function ExplorerIcon(N: TCIExpNode): TSdIcon;
begin
  case N.Kind of
    xkClass: Result := iiClass;
    xkInterface: Result := iiInterface;
    xkProcedure: Result := iiProcedure;
    xkFunction: Result := iiFunction;
    xkProperty: Result := iiProperty;
    xkType: Result := iiType;
    xkUses: Result := iiUses;
    xkField:
      if N.Group = xgVariables then Result := iiVar else Result := iiField;
  else
    Result := iiField;            // the heritage list's interfaces: Delphi's image of a plain symbol
  end;
end;

{ the text of an item: its name, with Show declaration syntax what its declaration adds }
function ItemText(N: TCIExpNode): string;
begin
  if EnvOptions.ExShowSyntax then Result := N.Name + N.Syntax else Result := N.Name;
end;

var
  { TList.Sort takes a plain function: its mode }
  SortBySource: Boolean;

{ Delphi's order: by the sort texts (CompareText; a folder's begins with #255, so the folders come
  after the items, in the order of the categories' list); Source - two items with places by their
  places }
function CompareItems(A, B: Pointer): Integer;
var
  X, Y: TExpItem;
begin
  X := TExpItem(A);
  Y := TExpItem(B);
  if SortBySource and (X.Kind = eiItem) and (Y.Kind = eiItem) and (X.Node.SortPos >= 0) and
    (Y.Node.SortPos >= 0) and (X.Node.SortPos <> Y.Node.SortPos) then
    Result := X.Node.SortPos - Y.Node.SortPos
  else
    Result := CompareText(X.Sort, Y.Sort);
end;

{ ---------------------------------------------------------------- the view }

constructor TCodeExplorerView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Tree.Images := IconList;
  Actions.Images := IconList;
  ExpPopup.Images := IconList;
  UIOwnerDrawMenus(Self);
  FItems := TList.Create;
  { a cancelled edit (Esc, the focus leaving): TCustomTreeView's, not published by TTreeView }
  TTreeAccess(Tree).OnCancelEdit := TreeCancelEdit;
  TExpTreeHook.Create(Tree, True).FView := Self;
  { a double click opens or closes no node (Delphi's tree opens a folder only by its box and the
    keys) and acts only on the node it hits }
  UITreeNoDblClickToggle(Tree);
  FEditProc := MakeObjectInstance(EditHook);
end;

destructor TCodeExplorerView.Destroy;
begin
  if FEditWnd <> 0 then SetWindowLongW(FEditWnd, GWL_WNDPROC, Integer(FEditOldProc));
  FreeObjectInstance(FEditProc);
  FreeItems;
  FItems.Free;
  FRoot.Free;
  inherited;
end;

{ No flicker: the tree fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TCodeExplorerView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the tree covers the whole view: nothing of the form shows, nothing to erase }
procedure TCodeExplorerView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TCodeExplorerView.NewItem(AKind: TExpItemKind): TExpItem;
begin
  Result := TExpItem.Create;
  Result.Kind := AKind;
  FItems.Add(Result);
end;

procedure TCodeExplorerView.FreeItems;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    TExpItem(FItems[I]).Members.Free;
    TObject(FItems[I]).Free;
  end;
  FItems.Clear;
end;

function TCodeExplorerView.Item(Node: TTreeNode): TExpItem;
begin
  if Node = nil then Result := nil else Result := TExpItem(Node.Data);
end;

procedure TCodeExplorerView.Clear;
begin
  ResetSearch;
  FollowTimer.Enabled := False;
  FCaretLine := 0;
  if Tree.IsEditing and (Tree.Selected <> nil) then Tree.Selected.EndEdit(True);
  { the nodes going choose others: not the editor's place }
  FSyncing := True;
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
  finally
    Tree.Items.EndUpdate;
    FSyncing := False;
  end;
  FreeItems;
  FreeAndNil(FRoot);
end;

procedure TCodeExplorerView.Modified;
begin
  ParseTimer.Enabled := False;
  ParseTimer.Enabled := True;
end;

procedure TCodeExplorerView.ParseTimerTimer(Sender: TObject);
begin
  ParseTimer.Enabled := False;
  { not while an edit of New or Rename runs: the node edited would go }
  if Tree.IsEditing then
  begin
    ParseTimer.Enabled := True;
    Exit;
  end;
  if Assigned(FOnParse) then FOnParse(Self);
end;

procedure TCodeExplorerView.CancelEdit;
begin
  if Tree.IsEditing and (Tree.Selected <> nil) then Tree.Selected.EndEdit(True);
end;

{ ---------------------------------------------------------------- the tree made }

{ It's node under Parent: its last child, the first when First }
function TCodeExplorerView.AddNode(Parent: TTreeNode; It: TExpItem; const Text: string; Icon: TSdIcon;
  First: Boolean): TTreeNode;
begin
  if First then Result := Tree.Items.AddChildFirst(Parent, Text)
  else Result := Tree.Items.AddChild(Parent, Text);
  Result.Data := It;
  It.TreeNode := Result;
  Result.ImageIndex := IconIndex(Icon);
  Result.SelectedIndex := Result.ImageIndex;
end;

{ a node that has children opens as it did in the last tree, else as Delphi opens a new one
  (Default) }
procedure TCodeExplorerView.Settle(N: TTreeNode; It: TExpItem; Default, Fresh: Boolean; Known,
  Open: TStringList);
var
  K: Integer;
  Wanted: Boolean;
begin
  if not N.HasChildren then Exit;
  Wanted := Default;
  if not Fresh and Known.Find(It.Key, K) then Wanted := Open.Find(It.Key, K);
  if Wanted then N.Expand(False);
end;

{ the children of Src under Parent, in Delphi's arrangement: a category that is a folder (its
  Visible) holds its items, one that is not lays them out among the others; a class's members by
  visibility while one of Private, Protected, Public is a folder (Delphi's test reads Public twice
  and never Published), else by kind. True: Delphi would open the node of Src at first - one of its
  children is no folder, or a folder that starts open }
function TCodeExplorerView.Build(Parent: TTreeNode; const ParentKey: string; Src: TCIExpNode;
  Fresh: Boolean; Known, Open: TStringList): Boolean;
const
  AccessCategory: array[TCIExpAccess] of TExpCategory = (ecPublished, ecPrivate, ecProtected, ecPublic);
var
  Entries: TList;
  I, K: Integer;
  It, M: TExpItem;
  N: TTreeNode;
  A: TCIExpAccess;

  function ItemOf(X: TCIExpNode; const Key: string): TExpItem;
  begin
    Result := NewItem(eiItem);
    Result.Node := X;
    Result.Key := Key + '/' + IntToStr(Ord(X.Kind)) + UpperCase(X.Name);
    Result.Sort := ItemText(X);
  end;

  { the children of Src the test takes: a folder of them, or each among the others }
  procedure Take(Cat: TExpCategory; Members: TList);
  var
    J: Integer;
    F: TExpItem;
  begin
    if Members.Count = 0 then
    begin
      Members.Free;
      Exit;
    end;
    if EnvOptions.ExVisible[Cat] then
    begin
      F := NewItem(eiFolder);
      F.Category := Cat;
      F.Key := ParentKey + '/F' + ExpCategoryKeys[Cat];
      F.Sort := #255 + Format('%3d%s', [Pos(ExpCategoryKeys[Cat], EnvOptions.ExCategorySort),
        ExpCategoryCaptions[Cat]]);
      F.Members := TList.Create;
      for J := 0 to Members.Count - 1 do F.Members.Add(ItemOf(TCIExpNode(Members[J]), F.Key));
      Entries.Add(F);
    end
    else
      for J := 0 to Members.Count - 1 do Entries.Add(ItemOf(TCIExpNode(Members[J]), ParentKey));
    Members.Free;
  end;

  procedure TakeGroup(G: TCIExpGroup; Cat: TExpCategory);
  var
    J: Integer;
    L: TList;
  begin
    L := TList.Create;
    for J := 0 to Src.Count - 1 do
      if Src[J].Group = G then L.Add(Src[J]);
    Take(Cat, L);
  end;

  procedure TakeAccess(Acc: TCIExpAccess);
  var
    J: Integer;
    L: TList;
  begin
    L := TList.Create;
    for J := 0 to Src.Count - 1 do
      if (Src[J].Group in [xgFields, xgProperties, xgMethods]) and (Src[J].Access = Acc) then L.Add(Src[J]);
    Take(AccessCategory[Acc], L);
  end;

  { an item's node and what is below it: a class's or an interface's members, a routine's
    overloads (in the picture's order: Delphi does not sort them) }
  procedure AddItem(P: TTreeNode; X: TExpItem);
  var
    J: Integer;
    C: TTreeNode;
    S: TExpItem;
    Default: Boolean;
  begin
    C := AddNode(P, X, ItemText(X.Node), ExplorerIcon(X.Node));
    Default := False;
    if X.Node.Kind in [xkClass, xkInterface] then
      Default := Build(C, X.Key, X.Node, Fresh, Known, Open)
    else if X.Node.Count > 0 then
    begin
      Default := True;                      // a routine with overloads: open (no state of its own)
      for J := 0 to X.Node.Count - 1 do
      begin
        S := NewItem(eiItem);
        S.Node := X.Node[J];
        S.Key := X.Key + '/#' + IntToStr(J);
        AddNode(C, S, ItemText(S.Node), ExplorerIcon(S.Node));
      end;
    end;
    Settle(C, X, Default, Fresh, Known, Open);
  end;

begin
  Result := False;
  Entries := TList.Create;
  try
    case Src.Kind of
      xkUnit:
        begin
          TakeGroup(xgClasses, ecClasses);
          TakeGroup(xgInterfaces, ecInterfaces);
          TakeGroup(xgProcedures, ecProcedures);
          TakeGroup(xgTypes, ecTypes);
          TakeGroup(xgVariables, ecVariables);
          TakeGroup(xgUses, ecUses);
        end;
      xkClass:
        begin
          TakeGroup(xgHeritage, ecInterfaces);
          if EnvOptions.ExVisible[ecPrivate] or EnvOptions.ExVisible[ecPublic] or EnvOptions.ExVisible[ecProtected] then
            for A := Low(TCIExpAccess) to High(TCIExpAccess) do TakeAccess(A)
          else
          begin
            TakeGroup(xgFields, ecFields);
            TakeGroup(xgProperties, ecProperties);
            TakeGroup(xgMethods, ecMethods);
          end;
        end;
      xkInterface:
        begin
          TakeGroup(xgProperties, ecProperties);
          TakeGroup(xgMethods, ecMethods);
        end;
    end;
    SortBySource := not EnvOptions.ExSortAlpha;
    Entries.Sort(CompareItems);
    for I := 0 to Entries.Count - 1 do
    begin
      It := TExpItem(Entries[I]);
      if It.Kind = eiFolder then
      begin
        N := AddNode(Parent, It, ExpCategoryCaptions[It.Category], iiExpFolder);
        It.Members.Sort(CompareItems);
        for K := 0 to It.Members.Count - 1 do
        begin
          M := TExpItem(It.Members[K]);
          AddItem(N, M);
        end;
        FreeAndNil(It.Members);
        Settle(N, It, EnvOptions.ExExpand[It.Category], Fresh, Known, Open);
        if EnvOptions.ExExpand[It.Category] then Result := True;
      end
      else
      begin
        AddItem(Parent, It);
        Result := True;
      end;
    end;
  finally
    Entries.Free;
  end;
end;

procedure TCodeExplorerView.ShowExplorer(Root: TCIExpNode; Fresh: Boolean);
var
  Known, Open: TStringList;
  I: Integer;
  Chosen, Top: string;
  N: TTreeNode;
  It: TExpItem;
begin
  ResetSearch;
  if Tree.IsEditing and (Tree.Selected <> nil) then Tree.Selected.EndEdit(True);
  Known := TStringList.Create;
  Open := TStringList.Create;
  try
    Chosen := '';
    Top := '';
    if not Fresh then
    begin
      for I := 0 to FItems.Count - 1 do
      begin
        It := TExpItem(FItems[I]);
        if It.TreeNode = nil then Continue;
        Known.Add(It.Key);
        if It.TreeNode.Expanded then Open.Add(It.Key);
      end;
      if Item(Tree.Selected) <> nil then Chosen := Item(Tree.Selected).Key;
      if Item(Tree.TopItem) <> nil then Top := Item(Tree.TopItem).Key;
    end;
    Known.Sorted := True;
    Open.Sorted := True;
    { the tree made again chooses nodes itself: not the editor's place; it has not followed the
      caret yet }
    FCaretLine := 0;
    FollowTimer.Enabled := False;
    FSyncing := True;
    try
      Tree.Items.BeginUpdate;
      try
        Tree.Items.Clear;
        FreeItems;
        FreeAndNil(FRoot);
        FRoot := Root;
        if FRoot <> nil then Build(nil, '', FRoot, Fresh, Known, Open);
      finally
        Tree.Items.EndUpdate;
      end;
      { the chosen node again - else the first, as Delphi's tree focuses its first node when the
        focused one went; then the first row as it was (the nodes opened scrolled the tree) }
      N := nil;
      if Chosen <> '' then N := FindKey(Chosen);
      if N = nil then N := Tree.Items.GetFirstNode;
      Tree.Selected := N;
      N := nil;
      if Top <> '' then N := FindKey(Top);
      if N = nil then N := Tree.Items.GetFirstNode;
      if N <> nil then Tree.TopItem := N;
    finally
      FSyncing := False;
    end;
  finally
    Open.Free;
    Known.Free;
  end;
end;

{ by the items: no message to the tree for each node }
function TCodeExplorerView.FindKey(const Key: string): TTreeNode;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if (TExpItem(FItems[I]).TreeNode <> nil) and (TExpItem(FItems[I]).Key = Key) then
    begin
      Result := TExpItem(FItems[I]).TreeNode;
      Exit;
    end;
  Result := nil;
end;

{ the class or interface a node lies in (nil: the unit's) }
function TCodeExplorerView.OwnerNode(N: TTreeNode): TTreeNode;
var
  It: TExpItem;
begin
  Result := nil;
  if N = nil then Exit;
  N := N.Parent;
  while N <> nil do
  begin
    It := Item(N);
    if (It <> nil) and (It.Kind = eiItem) and (It.Node.Kind in [xkClass, xkInterface]) then
    begin
      Result := N;
      Exit;
    end;
    N := N.Parent;
  end;
end;

procedure TCodeExplorerView.TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  It: TExpItem;
begin
  It := Item(Node);
  if (It <> nil) and (It.Kind = eiItem) and It.Node.Incomplete and EnvOptions.ExHighlightIncomplete then
    Sender.Canvas.Font.Style := [fsBold];
  DefaultDraw := True;
end;

{ ---------------------------------------------------------------- the source shown }

{ Delphi's ShowSource: the caret's place from the node, else from the nearest node above it that
  has one; the top line likewise (none: the text's start). False: no place (a top-level folder) }
function TCodeExplorerView.SourcePlace(N: TTreeNode; out Top, Line, Col: Integer): Boolean;
var
  It: TExpItem;
  Skip: TTreeNode;
begin
  Top := 0;
  Line := 0;
  Col := 0;
  { an overload's row: the top line its own or its class's - not its routine's, which is the first
    row's }
  Skip := nil;
  if (Item(N) <> nil) and (Item(N).Kind = eiItem) and Item(N).Node.Signature then Skip := N.Parent;
  while N <> nil do
  begin
    It := Item(N);
    if (It <> nil) and (It.Kind = eiItem) then
    begin
      if (Line = 0) and (It.Node.Line > 0) then
      begin
        Line := It.Node.Line;
        Col := It.Node.Col;
      end;
      if (Top = 0) and (It.Node.TopLine > 0) and (N <> Skip) then Top := It.Node.TopLine;
      if (Line > 0) and (Top > 0) then Break;
    end;
    N := N.Parent;
  end;
  Result := Line > 0;
end;

procedure TCodeExplorerView.ShowSourceOf(N: TTreeNode);
var
  Top, Line, Col: Integer;
begin
  if SourcePlace(N, Top, Line, Col) and Assigned(FOnShowSource) then FOnShowSource(Self, Top, Line, Col, True);
end;

{ on the node it hits only (Delphi: a double click on the focused node) }
procedure TCodeExplorerView.TreeDblClick(Sender: TObject);
var
  N: TTreeNode;
begin
  N := UITreeDblClickNode(Tree);
  if (N = nil) or (N <> Tree.Selected) or Tree.IsEditing then Exit;
  ShowSourceOf(N);
end;

{ ---------------------------------------------------------------- typing searches }

{ Delphi's TTreeControlSearch: the keys of letters, digits and "." make a text looked for at the
  start of the nodes' texts (case-insensitive) - from the chosen node on through the whole tree,
  closed nodes too, and round once; folders and overload rows never match }

function TCodeExplorerView.Searchable(N: TTreeNode): Boolean;
var
  It: TExpItem;
begin
  It := Item(N);
  Result := (It <> nil) and (It.Kind = eiItem) and not It.Node.Signature;
end;

function TCodeExplorerView.FindFrom(Start: TTreeNode; const Text: string; SkipStart: Boolean): TTreeNode;
var
  N: TTreeNode;
  I: Integer;

  function NextOf(X: TTreeNode): TTreeNode;
  begin
    Result := X.GetNext;
    if Result = nil then Result := Tree.Items.GetFirstNode;
  end;

begin
  Result := nil;
  if Tree.Items.Count = 0 then Exit;
  if Start = nil then Start := Tree.Items.GetFirstNode;
  N := Start;
  if SkipStart then N := NextOf(N);
  for I := 1 to Tree.Items.Count do
  begin
    if Searchable(N) and ((Text = '') or (CompareText(Copy(N.Text, 1, Length(Text)), Text) = 0)) then
    begin
      Result := N;
      Exit;
    end;
    N := NextOf(N);
  end;
end;

{ chosen, its parents opened, scrolled into view as little as needed }
procedure TCodeExplorerView.Choose(N: TTreeNode);
begin
  Tree.Selected := N;
  N.MakeVisible;
end;

{ a key that finds nothing is dropped }
procedure TCodeExplorerView.SearchKey(C: Char);
var
  N: TTreeNode;
begin
  N := FindFrom(Tree.Selected, FSearch + C, False);
  if N <> nil then
  begin
    FSearch := FSearch + C;
    Choose(N);
  end;
  SearchTimer.Enabled := False;
  SearchTimer.Enabled := True;
end;

{ Space: the next match (without a text, the next node) }
procedure TCodeExplorerView.SearchNext;
var
  N: TTreeNode;
begin
  N := FindFrom(Tree.Selected, FSearch, True);
  if N <> nil then Choose(N);
  SearchTimer.Enabled := False;
  SearchTimer.Enabled := True;
end;

procedure TCodeExplorerView.ResetSearch;
begin
  FSearch := '';
  SearchTimer.Enabled := False;
end;

{ 1 s after the last key }
procedure TCodeExplorerView.SearchTimerTimer(Sender: TObject);
begin
  ResetSearch;
end;

procedure TCodeExplorerView.TreeExit(Sender: TObject);
begin
  ResetSearch;
end;

procedure TCodeExplorerView.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  N: TTreeNode;
begin
  { the edit of New or Rename: only Enter takes what it holds }
  if Tree.IsEditing then
  begin
    if Key = VK_RETURN then FEditEnter := True;
    Exit;
  end;
  if Shift * [ssCtrl, ssAlt] = [] then
  begin
    case Key of
      Ord('A')..Ord('Z'), Ord('0')..Ord('9'):
        begin
          SearchKey(Chr(Key));
          Key := 0;
          Exit;
        end;
      VK_PERIOD:
        begin
          if (FSearch <> '') and (FSearch[Length(FSearch)] <> '.') then SearchKey('.');
          Key := 0;
          Exit;
        end;
      VK_BACK:
        begin
          if Length(FSearch) > 1 then
          begin
            Delete(FSearch, Length(FSearch), 1);
            N := FindFrom(Tree.Selected, FSearch, False);
            if N <> nil then Choose(N);
            SearchTimer.Enabled := False;
            SearchTimer.Enabled := True;
          end;
          Key := 0;
          Exit;
        end;
      VK_SPACE:
        begin
          SearchNext;
          Key := 0;
          Exit;
        end;
      VK_ESCAPE:
        begin
          ResetSearch;
          Key := 0;
          Exit;
        end;
    end;
  end;
  { every other key (not Shift, Ctrl, Alt themselves) forgets the text and does what it does in the
    tree }
  if (Key = VK_SHIFT) or (Key = VK_CONTROL) or (Key = VK_MENU) then Exit;
  ResetSearch;
  case Key of
    VK_RETURN:
      begin
        if ssCtrl in Shift then aExpRename.Execute else ShowSourceOf(Tree.Selected);
        Key := 0;
      end;
    VK_F2:
      begin
        aExpRename.Execute;
        Key := 0;
      end;
  end;
end;

{ the characters of the keys: the search has them (the tree's own search would look for them too) }
procedure TCodeExplorerView.TreeKeyPress(Sender: TObject; var Key: Char);
begin
  if not Tree.IsEditing then Key := #0;
end;

{ ---------------------------------------------------------------- New and Rename }

{ Delphi's CanNew / GetNewableChild: on a class, a member of it; on a member, a routine, a variable
  or a uses entry, one beside it (in a class: in the section of the visibility folder right above
  it, else public); on a folder, as on its first item (an empty folder, the kind folders of a class:
  none); not on types, interfaces, the members of interfaces and overload rows }
function TCodeExplorerView.NewPlace(N: TTreeNode): TExpNewPlace;
const
  FolderAccess: array[ecPrivate..ecPublished] of TCIExpAccess = (xaPrivate, xaProtected, xaPublic, xaPublished);
var
  It, Folder: TExpItem;
  O: TTreeNode;
begin
  Result.Valid := False;
  Result.Parent := nil;
  Result.ClassName := '';
  Result.Access := xaPublic;
  Result.InUses := False;
  It := Item(N);
  if (It = nil) or (FRoot = nil) then Exit;
  case It.Kind of
    eiFolder:
      begin
        if (It.Category in [ecFields, ecProperties, ecMethods]) or (N.GetFirstChild = nil) then Exit;
        Result := NewPlace(N.GetFirstChild);
      end;
    eiItem:
      if It.Node.Kind = xkClass then
      begin
        Result.Parent := N;
        Result.ClassName := It.Node.Name;
        Result.Valid := True;
      end
      else if (It.Node.Kind in [xkField, xkProperty, xkProcedure, xkFunction, xkUses]) and not It.Node.Signature then
      begin
        O := OwnerNode(N);
        if O <> nil then
        begin
          if Item(O).Node.Kind <> xkClass then Exit;
          Result.ClassName := Item(O).Node.Name;
          Folder := Item(N.Parent);
          if (Folder <> nil) and (Folder.Kind = eiFolder) and (Folder.Category in [ecPrivate..ecPublished]) then
            Result.Access := FolderAccess[Folder.Category];
        end
        else
          Result.InUses := It.Node.Kind = xkUses;
        Result.Parent := N.Parent;
        Result.Valid := True;
      end;
  end;
end;

{ Delphi's CanRename: the node has a symbol - classes, routines, fields, variables, constants and
  properties; not folders, uses entries, types, interfaces, overload rows }
function Renamable(It: TExpItem): Boolean;
begin
  Result := (It <> nil) and (It.Kind = eiItem) and not It.Node.Signature and
    (It.Node.Kind in [xkClass, xkProcedure, xkFunction, xkField, xkProperty]);
end;

function TCodeExplorerView.CanRename(N: TTreeNode): Boolean;
begin
  Result := Renamable(Item(N)) and not Tree.IsEditing;
end;

procedure TCodeExplorerView.aExpNewUpdate(Sender: TObject);
begin
  aExpNew.Enabled := not Tree.IsEditing and NewPlace(Tree.Selected).Valid;
end;

{ an edit of <item> (<unit name> in Uses) under the place's node, first of its children }
procedure TCodeExplorerView.aExpNewExecute(Sender: TObject);
var
  It: TExpItem;
  N: TTreeNode;
  T: string;
begin
  if Tree.IsEditing then Exit;
  FNewPlace := NewPlace(Tree.Selected);
  if not FNewPlace.Valid then Exit;
  FNewBack := '';
  if Item(Tree.Selected) <> nil then FNewBack := Item(Tree.Selected).Key;
  It := NewItem(eiNew);
  It.Key := '<new>';
  if FNewPlace.InUses then T := '<unit name>' else T := '<item>';
  N := AddNode(FNewPlace.Parent, It, T, iiField, True);
  Choose(N);
  FEditEnter := False;
  N.EditText;
end;

procedure TCodeExplorerView.aExpRenameUpdate(Sender: TObject);
begin
  aExpRename.Enabled := CanRename(Tree.Selected);
end;

procedure TCodeExplorerView.aExpRenameExecute(Sender: TObject);
begin
  if CanRename(Tree.Selected) then
  begin
    FEditEnter := False;
    Tree.Selected.EditText;
  end;
end;

{ New's edit, or a rename: the edit shows the name alone (not the declaration's text) }
procedure TCodeExplorerView.TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
var
  It: TExpItem;
  E: HWND;
begin
  It := Item(Node);
  FEditEnter := False;
  { the edit's keys: the tree view's own procedure takes Enter before the VCL's sees it }
  PostMessage(Handle, WM_USER + 3, 0, 0);
  if (It <> nil) and (It.Kind = eiNew) then
  begin
    AllowEdit := True;
    Exit;
  end;
  AllowEdit := Renamable(It);
  if not AllowEdit then Exit;
  ResetSearch;
  E := TreeView_GetEditControl(Tree.Handle);
  if E <> 0 then
  begin
    SetWindowText(E, PChar(It.Node.Name));
    SendMessage(E, EM_SETSEL, 0, -1);
  end;
end;

{ taken by Enter only (Delphi's tree posts no edit that ends otherwise); the tree shows the new
  text once the picture is made again }
procedure TCodeExplorerView.TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
  It: TExpItem;
  Enter: Boolean;
  Place: TExpNewPlace;
  O: TTreeNode;
  Owner: string;
  Top, Line, Col: Integer;
begin
  It := Item(Node);
  Enter := FEditEnter;
  FEditEnter := False;
  S := Trim(S);
  if It = nil then Exit;
  if It.Kind = eiNew then
  begin
    Place := FNewPlace;
    if Enter and (S <> '') and Assigned(FOnNew) and FOnNew(Self, Place, S) then
      { Delphi shows the source of its placeholder, which has no place: its class's }
      if SourcePlace(Place.Parent, Top, Line, Col) then
      begin
        FShowTop := Top;
        FShowLine := Line;
        FShowCol := Col;
        PostMessage(Handle, WM_USER + 2, 0, 0);
      end;
    S := Node.Text;
    PostMessage(Handle, WM_USER + 1, 0, 0);
    Exit;
  end;
  if Enter and (It.Kind = eiItem) and (S <> '') and (S <> It.Node.Name) and Assigned(FOnRename) then
  begin
    O := OwnerNode(Node);
    if O <> nil then Owner := Item(O).Node.Name else Owner := '';
    FOnRename(Self, It.Node, Owner, S);
  end;
  S := Node.Text;
end;

procedure TCodeExplorerView.TreeCancelEdit(Sender: TObject; Node: TTreeNode);
begin
  FEditEnter := False;
  if (Item(Node) <> nil) and (Item(Node).Kind = eiNew) then PostMessage(Handle, WM_USER + 1, 0, 0);
end;

{ New's edit ended: its node goes, the node chosen before is chosen again - the tree as it was, the
  editor not moved by it (a New taken has shown its class already) }
procedure TCodeExplorerView.WMExpDropNew(var Message: TMessage);
var
  I: Integer;
  N: TTreeNode;
  It: TExpItem;
begin
  if Tree.IsEditing then Exit;
  FSyncing := True;
  try
    for I := 0 to FItems.Count - 1 do
    begin
      It := TExpItem(FItems[I]);
      if (It.Kind = eiNew) and (It.TreeNode <> nil) then
      begin
        It.TreeNode.Delete;
        It.TreeNode := nil;
      end;
    end;
    if FNewBack <> '' then
    begin
      N := FindKey(FNewBack);
      if N <> nil then Tree.Selected := N;
      FNewBack := '';
    end;
  finally
    FSyncing := False;
  end;
end;

procedure TCodeExplorerView.WMExpShowNew(var Message: TMessage);
begin
  if Assigned(FOnShowSource) then FOnShowSource(Self, FShowTop, FShowLine, FShowCol, True);
end;

{ ---------------------------------------------------------------- Synchronize with the editor }

{ (Environment Options | Explorer, off by default - Delphi 7 does neither, though its help says it
  does both) a node chosen moves the editor's caret to its place; the caret moving chooses the node
  of its place after a pause }

procedure TCodeExplorerView.TreeChange(Sender: TObject; Node: TTreeNode);
var
  Top, Line, Col: Integer;
begin
  if FSyncing or not EnvOptions.ExSyncEditor or Tree.IsEditing or (Node = nil) then Exit;
  FollowTimer.Enabled := False;          // the user's choice wins over a caret that moved before it
  if (Item(Node) <> nil) and (Item(Node).Kind = eiItem) and SourcePlace(Node, Top, Line, Col) and
    Assigned(FOnShowSource) then
    FOnShowSource(Self, Top, Line, Col, False);
end;

procedure TCodeExplorerView.CaretMoved(Line, Col: Integer);
begin
  if not EnvOptions.ExSyncEditor then Exit;
  { the editor scrolled, the caret stayed: the node chosen stays - also one that is no place's (a
    folder) }
  if (Line = FCaretLine) and (Col = FCaretCol) then Exit;
  FCaretLine := Line;
  FCaretCol := Col;
  FollowTimer.Enabled := False;
  FollowTimer.Enabled := True;
end;

procedure TCodeExplorerView.FollowTimerTimer(Sender: TObject);
begin
  FollowTimer.Enabled := False;
  if not Tree.IsEditing then ChooseAt(FCaretLine, FCaretCol);
end;

{ the node of the place: the one covering the fewest lines that covers Line (a declaration's own
  line counts as one), of several on Line the last that begins at Col or before it; the chosen node
  stays when it is as good, and when the place is its own (it put the caret there: a routine's name
  goes to its first overload, a heritage entry to its class). Its folders opened, scrolled into view
  as little as needed }
procedure TCodeExplorerView.ChooseAt(Line, Col: Integer);
var
  I, Span, BestSpan, BestCol, C, T, L: Integer;
  N, Best, Sel: TTreeNode;
  It: TExpItem;

  function Better(Node: TTreeNode; ASpan, ACol: Integer): Boolean;
  begin
    Result := (Best = nil) or (ASpan < BestSpan) or (ASpan = BestSpan) and (ACol > BestCol) or
      (ASpan = BestSpan) and (ACol = BestCol) and (Node = Sel);
  end;

begin
  Sel := Tree.Selected;
  if (Item(Sel) <> nil) and (Item(Sel).Kind = eiItem) and SourcePlace(Sel, T, L, C) and (L = Line) and
    (C = Col) then Exit;
  Best := nil;
  BestSpan := MaxInt;
  BestCol := -1;
  { by the items: no message to the tree for each node }
  for I := 0 to FItems.Count - 1 do
  begin
    It := TExpItem(FItems[I]);
    N := It.TreeNode;
    if (It.Kind <> eiItem) or (N = nil) then Continue;
    if It.Node.DeclLine = Line then
      Span := 0
    else if (It.Node.FirstLine > 0) and (It.Node.FirstLine <= Line) and (Line <= It.Node.LastLine) then
      Span := It.Node.LastLine - It.Node.FirstLine
    else
      Span := -1;                      // it does not cover the line
    if Span < 0 then Continue;
    { of the items of one line, the one the caret is on }
    C := -1;
    if (Span = 0) and (It.Node.Line = Line) and (It.Node.Col <= Col) then C := It.Node.Col;
    if Better(N, Span, C) then
    begin
      Best := N;
      BestSpan := Span;
      BestCol := C;
    end;
  end;
  if (Best = nil) or (Best = Sel) then Exit;
  FSyncing := True;
  try
    Tree.Selected := Best;
    Best.MakeVisible;
  finally
    FSyncing := False;
  end;
end;

{ the edit of New or Rename, once it is there: a procedure before the tree view's own (which ends
  the edit on Enter and Esc without passing them on) tells Enter apart from the other ends of an
  edit - a Unicode one, so that nothing converts the edit's text }
procedure TCodeExplorerView.WMExpHookEdit(var Message: TMessage);
var
  E: HWND;
begin
  if not Tree.IsEditing then Exit;
  E := TreeView_GetEditControl(Tree.Handle);
  if (E = 0) or (E = FEditWnd) then Exit;
  if FEditWnd <> 0 then SetWindowLongW(FEditWnd, GWL_WNDPROC, Integer(FEditOldProc));
  FEditWnd := E;
  FEditOldProc := Pointer(SetWindowLongW(E, GWL_WNDPROC, Integer(FEditProc)));
end;

procedure TCodeExplorerView.EditHook(var Message: TMessage);
var
  Wnd: HWND;
  Old: Pointer;
begin
  Wnd := FEditWnd;
  Old := FEditOldProc;
  if (Message.Msg = WM_KEYDOWN) and (Message.WParam = VK_RETURN) then FEditEnter := True;
  if Message.Msg = WM_NCDESTROY then
  begin
    SetWindowLongW(Wnd, GWL_WNDPROC, Integer(Old));
    FEditWnd := 0;
    FEditOldProc := nil;
  end;
  Message.Result := CallWindowProcW(Old, Wnd, Message.Msg, Message.WParam, Message.LParam);
end;

procedure TCodeExplorerView.aExpViewEditorExecute(Sender: TObject);
begin
  if Assigned(FOnViewEditor) then FOnViewEditor(Self);
end;

procedure TCodeExplorerView.aExpPropertiesExecute(Sender: TObject);
begin
  if Assigned(FOnProperties) then FOnProperties(Self);
end;

end.
