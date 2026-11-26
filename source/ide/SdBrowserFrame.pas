{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdBrowserFrame;

{ D7 Studio - the Browser (View | Browser, Shift+Ctrl+B): Delphi 7's project
  browser as a docked view. On one side the symbols three
  ways - Globals (what the units browsed declare, alphabetical), Classes (the hierarchy from
  TObject down to the project's classes), Units -; on the other the chosen symbol: a line with
  its declaration, then Scope (what it declares: a class's members, a unit's symbols and uses),
  Inheritance (a class's ancestors down to it, and its descendants) and References (where the
  project names it). The two sides lie side by side in a wide view and one above the other in a
  tall one; the gap between them moves them. A double click or Enter goes to the declaration
  (or the place). The data comes from code insight (TCodeInsight.Browse), made again by Rebuild.

  Globals, Units and the Scope of a unit are virtual lists (all symbols: 21830 of them, the unit
  Windows alone 9000 - a tree view needs 4 s for 20000 nodes, it asks for every node's text);
  Classes, a class's Scope, Inheritance and References are trees. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, ComCtrls, Menus, ActnList,
  SdIcons, SdTabStrip, SdSplitViewFrame, SdCodeInsight, SdCodeExplorer, SdEnvOptions;

type
  TBrowseGotoEvent = procedure(Sender: TObject; const FileName: string; Line, Col: Integer) of object;
  TBrowseFilesEvent = procedure(Sender: TObject; Files: TStrings) of object;

  { a frame inherited from the split view's (SdBrowserFrame.dfm: the lists and trees of both sides
    and their events), made by the main form (CreatePanes), which gives it its icons }
  TSdBrowser = class(TSdSplitView)
    SymList: TListView;              // Globals, Units (virtual)
    MenuActions: TActionList;
    aBrGoto: TAction;
    aBrBrowse: TAction;
    aBrBack: TAction;
    aBrRefresh: TAction;
    aBrDetails: TAction;
    aBrProperties: TAction;
    BrowserPopup: TPopupMenu;
    pmBr1: TMenuItem;
    pmBrBrowse: TMenuItem;
    pmBrBack: TMenuItem;
    pmBr2: TMenuItem;
    pmBr3: TMenuItem;
    pmBr4: TMenuItem;
    pmBr5: TMenuItem;
    ClassTree: TTreeView;            // Classes
    DetailTree: TTreeView;
    DetailList: TListView;           // the Scope of a unit (virtual)
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure ListData(Sender: TObject; Item: TListItem);
    procedure ListDataFind(Sender: TObject; Find: TItemFind; const FindString: string;
      const FindPosition: TPoint; FindData: Pointer; StartIndex: Integer; Direction: TSearchDirection;
      Wrap: Boolean; var Index: Integer);
    procedure ListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    { the events every list and tree shares: go to on a double click or Enter, the one a command
      acts on }
    procedure ViewDblClick(Sender: TObject);
    procedure ViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ViewEnter(Sender: TObject);
    procedure ViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  private
    FCI: TCodeInsight;
    FModel: TCIBrowseModel;
    FAllUnits: Boolean;
    FViewTabs: TSdTabStrip;          // Globals, Classes, Units
    FListSyms: TList;                // its symbols in order
    FDetailTabs: TSdTabStrip;        // Scope, Inheritance, References
    FDetailRows: TStringList;        // its rows: captions, Objects the symbols (nil: a unit not browsed)
    FLast: TWinControl;              // the list or tree a command acts on
    FCurrent: TCIBrowseSym;          // the symbol on the detail side
    FRefs: TStringList;              // References: file#9line#9col#9text
    FFiles: TStringList;             // the project's files at the last Rebuild
    FHistory: TList;                 // the symbols Browse left, for Back
    FFilling: Boolean;
    FOnGoto: TBrowseGotoEvent;
    FOnChoose: TNotifyEvent;
    FOnGetFiles: TBrowseFilesEvent;
    function GetView: Integer;
    procedure SetView(Value: Integer);
    function ListMode: Boolean;
    function RowCount(V: TListView): Integer;
    function RowText(V: TListView; I: Integer): string;
    function RowSym(V: TListView; I: Integer): TCIBrowseSym;
    procedure SetRowCount(V: TListView; Count: Integer);
    function AddNode(Tree: TTreeView; Parent: TTreeNode; Sym: TCIBrowseSym; const Text: string): TTreeNode;
    function AddPlain(Tree: TTreeView; Parent: TTreeNode; const Text: string; Icon: TSdIcon;
      Data: Pointer): TTreeNode;
    procedure AddSyms(Tree: TTreeView; Parent: TTreeNode; Syms: TList; Captions: Boolean; Nodes: TList = nil);
    procedure AddDescendants(Tree: TTreeView; Parent: TTreeNode; C: TCIBrowseSym; NeededOnly: Boolean);
    procedure MarkNeeded;
    procedure FillSymbols;
    procedure FillDetail;
    procedure FillScope;
    procedure FillUnitScope;
    procedure FillInheritance;
    procedure FillReferences;
    function FindNode(Tree: TTreeView; Sym: TCIBrowseSym): TTreeNode;
    function UnitSym(const Name: string): TCIBrowseSym;
    procedure ShowTop(Tree: TTreeView);
    procedure SelectQuietly(Tree: TTreeView; N: TTreeNode);
    function ChooseInSymbols(Sym: TCIBrowseSym): Boolean;
    procedure SetCurrent(Sym: TCIBrowseSym);
    procedure ViewTabsChange(Sender: TObject);
    procedure DetailTabsChange(Sender: TObject);
    function ChosenSym(V: TWinControl): TCIBrowseSym;
    function Target(V: TWinControl; out FileName: string; out Line, Col: Integer): Boolean;
    procedure Go(Sym: TCIBrowseSym);
    function TreeText(Tree: TTreeView; Max: Integer): string;
  protected
    function ShownFirst: TWinControl; override;
    function ShownSecond: TWinControl; override;
    procedure DrawHeader(const R: TRect); override;
    procedure DetailsChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the project's files (OnGetFiles) browsed again; the view and the symbol shown stay when
      they are still there }
    procedure Rebuild;
    procedure Clear;                 // no project
    { a symbol of the data: its view (Units, Classes, Globals - a member through its class),
      chosen and shown; False: it is not in the views }
    function ShowSymbol(Sym: TCIBrowseSym): Boolean;
    function FindSym(const FileName: string; Line: Integer): TCIBrowseSym;
    function CanGoto: Boolean;
    procedure GotoSelected;
    procedure Choose;                { Enter, a double click: OnChoose (the owner's Go to Declaration), else GotoSelected }
    { Browse: the symbol of the chosen node (a member, an ancestor, a used unit) becomes the one
      on the detail side - its scope, inheritance, references; Back: the one before }
    function CanBrowse: Boolean;
    procedure BrowseSelected;
    function CanBack: Boolean;
    procedure Back;
    function DebugText: string;      // test mode: view|count|symbol|detail tab|detail nodes|selected
    function DebugTree: string;      // test mode: the symbols of the list or the tree
    property CodeInsight: TCodeInsight read FCI write FCI;
    property AllUnits: Boolean read FAllUnits write FAllUnits;   // Browser scope: all symbols
    property View: Integer read GetView write SetView;    // 0 Globals, 1 Classes, 2 Units
    property OnGoto: TBrowseGotoEvent read FOnGoto write FOnGoto;
    property OnChoose: TNotifyEvent read FOnChoose write FOnChoose;
    property OnGetFiles: TBrowseFilesEvent read FOnGetFiles write FOnGetFiles;
  end;

{ Environment Options | Explorer | Initial browser view (Classes, Units, Globals) as a View }
function BrowserViewOf(OptionIndex: Integer): Integer;

implementation

{$R *.dfm}

const
  ViewGlobals = 0;
  ViewClasses = 1;
  ViewUnits = 2;
  TabScope = 0;
  TabInheritance = 1;
  TabReferences = 2;

function BrowserViewOf(OptionIndex: Integer): Integer;
begin
  case OptionIndex of
    1: Result := ViewUnits;
    2: Result := ViewGlobals;
  else
    Result := ViewClasses;
  end;
end;

function CompareSyms(A, B: Pointer): Integer;
begin
  Result := CompareText(TCIBrowseSym(A).Name, TCIBrowseSym(B).Name);
  if (Result = 0) and (TCIBrowseSym(A).UnitInfo <> nil) and (TCIBrowseSym(B).UnitInfo <> nil) then
    Result := CompareText(TCIBrowseSym(A).UnitInfo.Name, TCIBrowseSym(B).UnitInfo.Name);
end;

function Field(const S: string; Index: Integer): string;
var
  I, P: Integer;
begin
  Result := S;
  for I := 1 to Index do
  begin
    P := Pos(#9, Result);
    if P = 0 then
    begin
      Result := '';
      Exit;
    end;
    Delete(Result, 1, P);
  end;
  P := Pos(#9, Result);
  if P > 0 then Result := Copy(Result, 1, P - 1);
end;

constructor TSdBrowser.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRefs := TStringList.Create;
  FFiles := TStringList.Create;
  FHistory := TList.Create;
  FListSyms := TList.Create;
  FViewTabs := NewTabs(['Globals', 'Classes', 'Units'], True);
  FViewTabs.TabIndex := ViewClasses;
  FViewTabs.OnChange := ViewTabsChange;
  FDetailRows := TStringList.Create;
  AddSide(SymList, True);
  AddSide(ClassTree, True);
  FDetailTabs := NewTabs(['Scope', 'Inheritance', 'References'], False);
  FDetailTabs.OnChange := DetailTabsChange;
  AddSide(DetailTree, False);
  AddSide(DetailList, False);
  FLast := ClassTree;
end;

destructor TSdBrowser.Destroy;
begin
  FFilling := True;
  FModel.Free;
  FModel := nil;
  FRefs.Free;
  FFiles.Free;
  FHistory.Free;
  FListSyms.Free;
  FDetailRows.Free;
  inherited Destroy;
end;

{ the detail side is the list: the Scope of a unit }
function TSdBrowser.ListMode: Boolean;
begin
  Result := (FCurrent <> nil) and (FCurrent.Kind = ckUnit) and (FDetailTabs.TabIndex = TabScope);
end;

function TSdBrowser.RowCount(V: TListView): Integer;
begin
  if V = SymList then Result := FListSyms.Count else Result := FDetailRows.Count;
end;

function TSdBrowser.RowText(V: TListView; I: Integer): string;
begin
  if V = SymList then Result := TCIBrowseSym(FListSyms[I]).Name else Result := FDetailRows[I];
end;

function TSdBrowser.RowSym(V: TListView; I: Integer): TCIBrowseSym;
begin
  if V = SymList then Result := TCIBrowseSym(FListSyms[I]) else Result := TCIBrowseSym(FDetailRows.Objects[I]);
end;

{ the rows a list shows (the count needs its window: none is made for an empty list) }
procedure TSdBrowser.SetRowCount(V: TListView; Count: Integer);
begin
  if not V.HandleAllocated and (Count = 0) then Exit;
  V.Items.Count := Count;
  FitColumn(V);
  V.Invalidate;
end;

{ --- the sides --- }

function TSdBrowser.ShownFirst: TWinControl;
begin
  if View = ViewClasses then Result := ClassTree else Result := SymList;
end;

function TSdBrowser.ShownSecond: TWinControl;
begin
  if ListMode then Result := DetailList else Result := DetailTree;
end;

{ the line above the detail side: the chosen symbol's icon and declaration }
procedure TSdBrowser.DrawHeader(const R: TRect);
var
  S: string;
begin
  if FCurrent = nil then Exit;
  S := FCurrent.Decl;
  if S = '' then S := FCurrent.Name;
  S := StringReplace(StringReplace(S, #13#10, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
  DrawHeaderLine(R, IconList, IconIndex(KindIcon(FCurrent.Kind)), S);
end;

procedure TSdBrowser.DetailsChanged;
begin
  if not Details and ((FLast = DetailTree) or (FLast = DetailList)) then
    if View = ViewClasses then FLast := ClassTree else FLast := SymList;
  FillDetail;
end;

{ --- the trees --- }

{ a node with its images set before it is in the tree: set afterwards, each one is a TVM_SETITEM
  that has the tree view measure the item }
function NewNode(Tree: TTreeView; Parent: TTreeNode; const Text: string; Icon: TSdIcon; Data: Pointer;
  First: Boolean): TTreeNode;
begin
  Result := TTreeNode.Create(Tree.Items);
  Result.ImageIndex := IconIndex(Icon);
  Result.SelectedIndex := Result.ImageIndex;
  if First then Tree.Items.AddNode(Result, Parent, Text, Data, naAddChildFirst)
  else Tree.Items.AddNode(Result, Parent, Text, Data, naAddChild);
end;

function TSdBrowser.AddNode(Tree: TTreeView; Parent: TTreeNode; Sym: TCIBrowseSym; const Text: string): TTreeNode;
begin
  Result := AddPlain(Tree, Parent, Text, KindIcon(Sym.Kind), Sym);
end;

function TSdBrowser.AddPlain(Tree: TTreeView; Parent: TTreeNode; const Text: string; Icon: TSdIcon;
  Data: Pointer): TTreeNode;
begin
  Result := NewNode(Tree, Parent, Text, Icon, Data, False);
end;

{ the nodes of Syms under Parent in their order (their captions or names; Nodes: the nodes in
  that order). They are added from the last one, each as the first child: a tree view looks for
  the last child at every TVI_LAST, which makes a long list quadratic. }
procedure TSdBrowser.AddSyms(Tree: TTreeView; Parent: TTreeNode; Syms: TList; Captions: Boolean; Nodes: TList);
var
  I: Integer;
  S: TCIBrowseSym;
  N: TTreeNode;
  T: string;
begin
  if Nodes <> nil then
  begin
    Nodes.Clear;
    Nodes.Count := Syms.Count;
  end;
  for I := Syms.Count - 1 downto 0 do
  begin
    S := TCIBrowseSym(Syms[I]);
    if Captions then T := S.Caption else T := S.Name;
    N := NewNode(Tree, Parent, T, KindIcon(S.Kind), S, True);
    if Nodes <> nil then Nodes[I] := N;
  end;
end;

{ Tag 1: a class of a unit browsed or an ancestor of one - the classes the Classes view shows }
procedure TSdBrowser.MarkNeeded;
var
  I: Integer;
  C: TCIBrowseSym;
begin
  for I := 0 to FModel.ClassList.Count - 1 do TCIBrowseSym(FModel.ClassList[I]).Tag := 0;
  for I := 0 to FModel.ClassList.Count - 1 do
  begin
    C := TCIBrowseSym(FModel.ClassList[I]);
    if C.UnitInfo.Shown then
      while (C <> nil) and (C.Tag = 0) do
      begin
        C.Tag := 1;
        C := C.Ancestor;
      end;
  end;
end;

procedure TSdBrowser.AddDescendants(Tree: TTreeView; Parent: TTreeNode; C: TCIBrowseSym; NeededOnly: Boolean);
var
  L, Nodes: TList;
  I: Integer;
begin
  L := TList.Create;
  Nodes := TList.Create;
  try
    for I := 0 to C.Descendants.Count - 1 do
      if not NeededOnly or (TCIBrowseSym(C.Descendants[I]).Tag = 1) then L.Add(C.Descendants[I]);
    L.Sort(CompareSyms);
    AddSyms(Tree, Parent, L, False, Nodes);
    for I := 0 to L.Count - 1 do AddDescendants(Tree, TTreeNode(Nodes[I]), TCIBrowseSym(L[I]), NeededOnly);
  finally
    Nodes.Free;
    L.Free;
  end;
end;

{ Globals: every symbol of the units browsed, Units: the units - the list; Classes: the tree,
  open down to the project's own classes }
procedure TSdBrowser.FillSymbols;
var
  L, Nodes: TList;
  I, K: Integer;
  BU: TCIBrowseUnit;
  C: TCIBrowseSym;
  N, P: TTreeNode;
begin
  FFilling := True;
  L := TList.Create;
  Nodes := TList.Create;
  try
    FListSyms.Clear;
    ClassTree.Items.BeginUpdate;
    try
      ClassTree.Items.Clear;
      if (FModel <> nil) and (View = ViewClasses) then
      begin
        MarkNeeded;
        for I := 0 to FModel.ClassList.Count - 1 do
        begin
          C := TCIBrowseSym(FModel.ClassList[I]);
          if (C.Ancestor = nil) and (C.Tag = 1) then L.Add(C);
        end;
        L.Sort(CompareSyms);
        AddSyms(ClassTree, nil, L, False, Nodes);
        for I := 0 to L.Count - 1 do AddDescendants(ClassTree, TTreeNode(Nodes[I]), TCIBrowseSym(L[I]), True);
        N := ClassTree.Items.GetFirstNode;
        while N <> nil do
        begin
          if TCIBrowseSym(N.Data).UnitInfo.InProject then
          begin
            P := N.Parent;
            while (P <> nil) and not P.Expanded do
            begin
              P.Expanded := True;
              P := P.Parent;
            end;
          end;
          N := N.GetNext;
        end;
      end;
      ShowTop(ClassTree);
    finally
      ClassTree.Items.EndUpdate;
    end;
    if (FModel <> nil) and (View <> ViewClasses) then
    begin
      for I := 0 to FModel.Units.Count - 1 do
      begin
        BU := TCIBrowseUnit(FModel.Units[I]);
        if not BU.Shown then Continue;
        if View = ViewUnits then FListSyms.Add(BU.Sym)
        else
          for K := 0 to BU.Syms.Count - 1 do FListSyms.Add(BU.Syms[K]);
      end;
      FListSyms.Sort(CompareSyms);
    end;
    SetRowCount(SymList, FListSyms.Count);
  finally
    Nodes.Free;
    L.Free;
    FFilling := False;
  end;
end;

{ a tree just filled: from its first node (expanding scrolled it), the chosen one in view -
  while the tree does not draw (it would scroll there step by step, painting every step) }
procedure TSdBrowser.ShowTop(Tree: TTreeView);
begin
  if Tree.Items.GetFirstNode = nil then Exit;
  Tree.TopItem := Tree.Items.GetFirstNode;
  if Tree.Selected <> nil then Tree.Selected.MakeVisible;
end;

{ a unit: its symbols, then the units it uses - the list (the order: Environment Options |
  Explorer | Explorer sorting) }
procedure TSdBrowser.FillUnitScope;
var
  L: TList;
  I: Integer;
  BU: TCIBrowseUnit;
begin
  BU := FCurrent.UnitInfo;
  L := TList.Create;
  try
    for I := 0 to BU.Syms.Count - 1 do L.Add(BU.Syms[I]);
    if EnvOptions.ExSortAlpha then L.Sort(CompareSyms);
    FDetailRows.Capacity := L.Count + BU.UsesList.Count;
    for I := 0 to L.Count - 1 do FDetailRows.AddObject(TCIBrowseSym(L[I]).Caption, L[I]);
  finally
    L.Free;
  end;
  for I := 0 to BU.UsesList.Count - 1 do FDetailRows.AddObject(BU.UsesList[I], UnitSym(BU.UsesList[I]));
end;

{ a class: its members in the folders of their visibility; a record or interface: its members }
procedure TSdBrowser.FillScope;
const
  VisNames: array[TCIVisibility] of string = ('', 'Private', 'Protected', 'Public', 'Published');
var
  L, Part: TList;
  I: Integer;
  V: TCIVisibility;
  F: TTreeNode;
begin
  L := TList.Create;
  Part := TList.Create;
  try
    for I := 0 to FCurrent.Members.Count - 1 do L.Add(FCurrent.Members[I]);
    if EnvOptions.ExSortAlpha then L.Sort(CompareSyms);
    for V := Low(TCIVisibility) to High(TCIVisibility) do
    begin
      Part.Clear;
      for I := 0 to L.Count - 1 do
        if TCIBrowseSym(L[I]).Visibility = V then Part.Add(L[I]);
      if Part.Count = 0 then Continue;
      F := nil;
      if (V <> cvNone) and (FCurrent.Kind = ckClass) then F := AddPlain(DetailTree, nil, VisNames[V], iiFolder, nil);
      AddSyms(DetailTree, F, Part, True);
    end;
  finally
    Part.Free;
    L.Free;
  end;
  DetailTree.FullExpand;
end;

{ a class or interface: its ancestors from the root down to it, then what derives from it }
procedure TSdBrowser.FillInheritance;
var
  Chain: TList;
  C: TCIBrowseSym;
  N: TTreeNode;
  I: Integer;
begin
  if not (FCurrent.Kind in [ckClass, ckInterface]) then Exit;
  Chain := TList.Create;
  try
    C := FCurrent;
    while C <> nil do
    begin
      Chain.Insert(0, C);
      C := C.Ancestor;
    end;
    N := nil;
    for I := 0 to Chain.Count - 1 do N := AddNode(DetailTree, N, TCIBrowseSym(Chain[I]), TCIBrowseSym(Chain[I]).Name);
    AddDescendants(DetailTree, N, FCurrent, False);
    DetailTree.FullExpand;
    SelectQuietly(DetailTree, N);
  finally
    Chain.Free;
  end;
end;

{ the files that name it, each with its places: "(line) text" }
procedure TSdBrowser.FillReferences;
var
  I: Integer;
  F, R: string;
  P: TTreeNode;
  Old: TCursor;
begin
  if FCI = nil then Exit;
  Old := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    FCI.FindReferences(FCurrent, FFiles, FRefs);
  finally
    Screen.Cursor := Old;
  end;
  P := nil;
  F := '';
  for I := 0 to FRefs.Count - 1 do
  begin
    R := FRefs[I];
    if (P = nil) or not SameText(Field(R, 0), F) then
    begin
      F := Field(R, 0);
      P := AddPlain(DetailTree, nil, ExtractFileName(F), iiUnit, nil);
    end;
    AddPlain(DetailTree, P, '(' + Field(R, 1) + ') ' + Field(R, 3), iiNone, Pointer(I + 1));
  end;
  DetailTree.FullExpand;
end;

procedure TSdBrowser.FillDetail;
begin
  FDetailRows.Clear;
  DetailTree.Items.BeginUpdate;
  try
    DetailTree.Items.Clear;
    FRefs.Clear;
    if (FCurrent <> nil) and Details then
      if ListMode then FillUnitScope
      else
        case FDetailTabs.TabIndex of
          TabScope: FillScope;
          TabInheritance: FillInheritance;
          TabReferences: FillReferences;
        end;
    ShowTop(DetailTree);
  finally
    DetailTree.Items.EndUpdate;
  end;
  SetRowCount(DetailList, FDetailRows.Count);
  if DetailList.HandleAllocated and (FDetailRows.Count > 0) then DetailList.Items[0].MakeVisible(False);
  { the list or the tree }
  if (ListMode <> DetailList.Visible) and Details then
  begin
    Arrange;
    if (FLast = DetailTree) or (FLast = DetailList) then
      if ListMode then FLast := DetailList else FLast := DetailTree;
  end;
end;

function TSdBrowser.FindNode(Tree: TTreeView; Sym: TCIBrowseSym): TTreeNode;
begin
  Result := Tree.Items.GetFirstNode;
  while (Result <> nil) and (Result.Data <> Sym) do Result := Result.GetNext;
end;

{ a unit of the data by its name (nil: not browsed) }
function TSdBrowser.UnitSym(const Name: string): TCIBrowseSym;
var
  I: Integer;
begin
  Result := nil;
  if FModel <> nil then
    for I := 0 to FModel.Units.Count - 1 do
      if SameText(TCIBrowseUnit(FModel.Units[I]).Name, Name) then
      begin
        Result := TCIBrowseUnit(FModel.Units[I]).Sym;
        Exit;
      end;
end;

{ N chosen without OnChange, in view: one paint, not the tree view's scrolling step by step }
procedure TSdBrowser.SelectQuietly(Tree: TTreeView; N: TTreeNode);
begin
  FFilling := True;
  Tree.Items.BeginUpdate;
  try
    Tree.Selected := N;
    if N <> nil then N.MakeVisible;
  finally
    Tree.Items.EndUpdate;
    FFilling := False;
  end;
end;

{ Sym chosen in the list or the tree of the symbols, without making it current (False: it is
  not there) }
function TSdBrowser.ChooseInSymbols(Sym: TCIBrowseSym): Boolean;
var
  I: Integer;
  N: TTreeNode;
begin
  if View = ViewClasses then
  begin
    N := FindNode(ClassTree, Sym);
    SelectQuietly(ClassTree, N);
    Result := N <> nil;
  end
  else
  begin
    I := FListSyms.IndexOf(Sym);
    FFilling := True;
    try
      SymList.ItemIndex := I;
    finally
      FFilling := False;
    end;
    if I >= 0 then SymList.Items[I].MakeVisible(False);
    Result := I >= 0;
  end;
end;

procedure TSdBrowser.SetCurrent(Sym: TCIBrowseSym);
begin
  FCurrent := Sym;
  FillDetail;
  InvalidateHeader;
end;

procedure TSdBrowser.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FFilling then Exit;
  if Node = nil then SetCurrent(nil) else SetCurrent(TCIBrowseSym(Node.Data));
end;

procedure TSdBrowser.ListData(Sender: TObject; Item: TListItem);
var
  V: TListView;
  S: TCIBrowseSym;
begin
  V := TListView(Sender);
  if (Item.Index < 0) or (Item.Index >= RowCount(V)) then Exit;
  S := RowSym(V, Item.Index);
  Item.Caption := RowText(V, Item.Index);
  if S <> nil then Item.ImageIndex := IconIndex(KindIcon(S.Kind)) else Item.ImageIndex := IconIndex(iiUnit);
end;

{ typing in the list: the next symbol that starts with what was typed }
procedure TSdBrowser.ListDataFind(Sender: TObject; Find: TItemFind; const FindString: string;
  const FindPosition: TPoint; FindData: Pointer; StartIndex: Integer; Direction: TSearchDirection;
  Wrap: Boolean; var Index: Integer);
var
  I, K, N: Integer;
begin
  Index := -1;
  N := RowCount(TListView(Sender));
  if (N = 0) or (FindString = '') then Exit;
  if (StartIndex < 0) or (StartIndex >= N) then StartIndex := 0;
  for K := 0 to N - 1 do
  begin
    I := StartIndex + K;
    if I >= N then
      if Wrap then Dec(I, N) else Exit;
    if AnsiStrLIComp(PChar(RowText(TListView(Sender), I)), PChar(FindString), Length(FindString)) = 0 then
    begin
      Index := I;
      Exit;
    end;
  end;
end;

procedure TSdBrowser.ListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if FFilling or not Selected or (Item = nil) then Exit;
  if (Item.Index >= 0) and (Item.Index < FListSyms.Count) then SetCurrent(TCIBrowseSym(FListSyms[Item.Index]));
end;

procedure TSdBrowser.ViewTabsChange(Sender: TObject);
begin
  Arrange;
  FillSymbols;
  ChooseInSymbols(FCurrent);
end;

procedure TSdBrowser.DetailTabsChange(Sender: TObject);
begin
  FillDetail;
end;

function TSdBrowser.GetView: Integer;
begin
  Result := FViewTabs.TabIndex;
end;

procedure TSdBrowser.SetView(Value: Integer);
begin
  if (Value < ViewGlobals) or (Value > ViewUnits) or (Value = FViewTabs.TabIndex) then Exit;
  FViewTabs.TabIndex := Value;
  ViewTabsChange(nil);
end;

{ --- commands --- }

{ the symbol chosen in the list or a tree (not a place of References, not a folder) }
function TSdBrowser.ChosenSym(V: TWinControl): TCIBrowseSym;
begin
  Result := nil;
  if V is TListView then
  begin
    if (TListView(V).ItemIndex >= 0) and (TListView(V).ItemIndex < RowCount(TListView(V))) then
      Result := RowSym(TListView(V), TListView(V).ItemIndex);
  end
  else if (V = ClassTree) or ((V = DetailTree) and (FDetailTabs.TabIndex <> TabReferences)) then
  begin
    if TTreeView(V).Selected <> nil then Result := TCIBrowseSym(TTreeView(V).Selected.Data);
  end;
end;

{ where the chosen symbol is declared, or the chosen place of References }
function TSdBrowser.Target(V: TWinControl; out FileName: string; out Line, Col: Integer): Boolean;
var
  S: TCIBrowseSym;
  R: string;
begin
  Result := False;
  FileName := '';
  Line := 0;
  Col := 0;
  if (V = DetailTree) and (FDetailTabs.TabIndex = TabReferences) then
  begin
    if (DetailTree.Selected = nil) or (DetailTree.Selected.Data = nil) then Exit;
    R := FRefs[Integer(DetailTree.Selected.Data) - 1];
    FileName := Field(R, 0);
    Line := StrToIntDef(Field(R, 1), 0);
    Col := StrToIntDef(Field(R, 2), 1);
  end
  else
  begin
    S := ChosenSym(V);
    if (S = nil) or (S.UnitInfo = nil) then Exit;
    FileName := S.UnitInfo.FileName;
    Line := S.Line;
    Col := S.Col;
  end;
  Result := (FileName <> '') and (Line > 0);
end;

function TSdBrowser.CanGoto: Boolean;
var
  F: string;
  L, C: Integer;
begin
  Result := Target(FLast, F, L, C);
end;

procedure TSdBrowser.Choose;
begin
  if Assigned(FOnChoose) then FOnChoose(Self) else GotoSelected;
end;

procedure TSdBrowser.GotoSelected;
var
  F: string;
  L, C: Integer;
begin
  if Target(FLast, F, L, C) and Assigned(FOnGoto) then FOnGoto(Self, F, L, C);
end;

{ Sym on the detail side, chosen in the symbols when it is there }
procedure TSdBrowser.Go(Sym: TCIBrowseSym);
begin
  ChooseInSymbols(Sym);
  SetCurrent(Sym);
end;

function TSdBrowser.CanBrowse: Boolean;
var
  S: TCIBrowseSym;
begin
  S := ChosenSym(FLast);
  Result := (S <> nil) and (S <> FCurrent);
end;

procedure TSdBrowser.BrowseSelected;
var
  S: TCIBrowseSym;
begin
  S := ChosenSym(FLast);
  if (S = nil) or (S = FCurrent) then Exit;
  if FCurrent <> nil then FHistory.Add(FCurrent);
  Go(S);
end;

function TSdBrowser.CanBack: Boolean;
begin
  Result := FHistory.Count > 0;
end;

procedure TSdBrowser.Back;
var
  S: TCIBrowseSym;
begin
  if FHistory.Count = 0 then Exit;
  S := TCIBrowseSym(FHistory[FHistory.Count - 1]);
  FHistory.Delete(FHistory.Count - 1);
  Go(S);
end;

procedure TSdBrowser.ViewDblClick(Sender: TObject);
begin
  FLast := TWinControl(Sender);
  Choose;
end;

procedure TSdBrowser.ViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    FLast := TWinControl(Sender);
    Choose;
    Key := 0;
  end;
end;

procedure TSdBrowser.ViewEnter(Sender: TObject);
begin
  FLast := TWinControl(Sender);
end;

procedure TSdBrowser.ViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FLast := TWinControl(Sender);
end;

{ --- the data --- }

procedure TSdBrowser.Rebuild;
var
  Old: string;
  OldCursor: TCursor;
  I: Integer;
  S: TCIBrowseSym;
  N: TTreeNode;
begin
  if FCurrent <> nil then Old := FCurrent.QualifiedName else Old := '';
  Clear;
  if Assigned(FOnGetFiles) then FOnGetFiles(Self, FFiles);
  if (FCI <> nil) and (FFiles.Count > 0) then
  begin
    OldCursor := Screen.Cursor;
    Screen.Cursor := crHourGlass;
    try
      FModel := FCI.Browse(FFiles, FAllUnits);
    finally
      Screen.Cursor := OldCursor;
    end;
  end;
  FillSymbols;
  if Old = '' then Exit;
  { the symbol shown before, when the view still has it }
  S := nil;
  if View = ViewClasses then
  begin
    N := ClassTree.Items.GetFirstNode;
    while (N <> nil) and not SameText(TCIBrowseSym(N.Data).QualifiedName, Old) do N := N.GetNext;
    if N <> nil then S := TCIBrowseSym(N.Data);
  end
  else
    for I := 0 to FListSyms.Count - 1 do
      if SameText(TCIBrowseSym(FListSyms[I]).QualifiedName, Old) then
      begin
        S := TCIBrowseSym(FListSyms[I]);
        Break;
      end;
  if S <> nil then Go(S);
end;

procedure TSdBrowser.Clear;
begin
  FFilling := True;
  try
    ClassTree.Items.Clear;
    DetailTree.Items.Clear;
    FListSyms.Clear;
    SetRowCount(SymList, 0);
    FDetailRows.Clear;
    SetRowCount(DetailList, 0);
  finally
    FFilling := False;
  end;
  FRefs.Clear;
  FFiles.Clear;
  FHistory.Clear;
  FCurrent := nil;
  FreeAndNil(FModel);
  Invalidate;
end;

function TSdBrowser.FindSym(const FileName: string; Line: Integer): TCIBrowseSym;

  function Search(L: TList): TCIBrowseSym;
  var
    I: Integer;
  begin
    for I := 0 to L.Count - 1 do
    begin
      Result := TCIBrowseSym(L[I]);
      if Result.Line = Line then Exit;
      Result := Search(Result.Members);
      if Result <> nil then Exit;
    end;
    Result := nil;
  end;

var
  I: Integer;
  BU: TCIBrowseUnit;
begin
  Result := nil;
  if FModel = nil then Exit;
  for I := 0 to FModel.Units.Count - 1 do
  begin
    BU := TCIBrowseUnit(FModel.Units[I]);
    if not SameText(BU.FileName, FileName) then Continue;
    Result := Search(BU.Syms);
    if (Result = nil) and (Line <= 1) then Result := BU.Sym;
    Exit;
  end;
end;

function TSdBrowser.ShowSymbol(Sym: TCIBrowseSym): Boolean;
var
  Top: TCIBrowseSym;
  N: TTreeNode;
begin
  Result := False;
  if Sym = nil then Exit;
  Top := Sym;
  while Top.Owner <> nil do Top := Top.Owner;
  if Top.Kind = ckUnit then View := ViewUnits
  else if Top.Kind in [ckClass, ckInterface] then View := ViewClasses
  else View := ViewGlobals;
  if not ChooseInSymbols(Top) then Exit;
  if View = ViewClasses then FLast := ClassTree else FLast := SymList;
  if Sym <> Top then FDetailTabs.TabIndex := TabScope;
  SetCurrent(Top);
  if Sym <> Top then
  begin
    N := FindNode(DetailTree, Sym);
    if N <> nil then
    begin
      SelectQuietly(DetailTree, N);
      FLast := DetailTree;
    end;
  end;
  Result := True;
end;

{ --- test mode --- }

function TSdBrowser.TreeText(Tree: TTreeView; Max: Integer): string;
var
  N: TTreeNode;
  K: Integer;
begin
  Result := '';
  N := Tree.Items.GetFirstNode;
  K := 0;
  while (N <> nil) and (K < Max) do
  begin
    Result := Result + StringOfChar('>', N.Level) + N.Text + ';';
    N := N.GetNext;
    Inc(K);
  end;
end;

function TSdBrowser.DebugText: string;
var
  S: TCIBrowseSym;
  I: Integer;
begin
  Result := FViewTabs.Tabs[FViewTabs.TabIndex] + '|';
  if View = ViewClasses then Result := Result + IntToStr(ClassTree.Items.Count)
  else Result := Result + IntToStr(FListSyms.Count);
  Result := Result + '|';
  if FCurrent <> nil then Result := Result + FCurrent.QualifiedName;
  Result := Result + '|' + FDetailTabs.Tabs[FDetailTabs.TabIndex] + '|';
  if ListMode then
    for I := 0 to FDetailRows.Count - 1 do
    begin
      if I = 80 then Break;
      Result := Result + FDetailRows[I] + ';';
    end
  else
    Result := Result + TreeText(DetailTree, 80);
  Result := Result + '|';
  if (FLast = DetailTree) and (DetailTree.Selected <> nil) then Result := Result + DetailTree.Selected.Text
  else
  begin
    S := ChosenSym(FLast);
    if S <> nil then Result := Result + S.Name;
  end;
end;

function TSdBrowser.DebugTree: string;
var
  I: Integer;
begin
  if View = ViewClasses then Result := TreeText(ClassTree, 200)
  else
  begin
    Result := '';
    for I := 0 to FListSyms.Count - 1 do
    begin
      if I = 200 then Break;
      Result := Result + TCIBrowseSym(FListSyms[I]).Name + ';';
    end;
  end;
end;

end.
