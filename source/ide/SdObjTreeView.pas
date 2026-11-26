{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdObjTreeView;

{ D7 Studio - the Object TreeView: the components of the form of the active page, menu items, actions
  and collection items with them, a placed frame's
  components under it. A form made once (its tree, its menu and the actions only that menu has in
  the .dfm), docked by the IDE - a child window then, without a border. The menu's Hide and Help
  and the dock's commands at its end are the IDE's (TMainForm.CreatePanes, AddDockItems); Add Item
  and Delete are carried out by the IDE (OnCommand). The form does not take the name of Delphi's
  (TObjectTreeView): experts look for that class. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, Menus, ActnList, TypInfo,
  SdUI, SdIcons, SdFormDesigner;

type
  TObjTreeView = class(TForm)
    Tree: TTreeView;
    Actions: TActionList;
    aObjTreeAdd: TAction;
    aObjTreeDelete: TAction;
    ObjTreePopup: TPopupMenu;
    pmObjTreeHide: TMenuItem;
    pmObjTreeHelp: TMenuItem;
    pmObjTreeLine: TMenuItem;
    pmObjTreeAdd: TMenuItem;
    pmObjTreeDelete: TMenuItem;
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ObjTreePopupPopup(Sender: TObject);
    procedure CommandExecute(Sender: TObject);
  private
    FDesigner: TFormDesigner;
    FUpdating: Boolean;
    FStale: Boolean;          // the designer's components changed: the nodes may point to freed ones
    FOnCommand: TNotifyEvent;
    FOnMenuPopup: TNotifyEvent;
    { ShowDesigner: the children of each component of the root, as lists through the indexes
      of Root.Components - FKidHead[I + 1] the first child of component I (of the root at 0),
      FKidNext[J] the one after child J; -1 ends a list }
    FKidHead, FKidNext: array of Integer;
    procedure IndexChildren(Root: TComponent);
    procedure AddComponentNodes(Parent: TTreeNode; C: TComponent);
    procedure AddFrameNodes(Parent: TTreeNode; Frame: TComponent; Container: TWinControl);
    procedure AddCollections(Parent: TTreeNode; C: TComponent);
    function FindData(Data: Pointer): TTreeNode;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear;
    procedure ShowDesigner(D: TFormDesigner);
    procedure SyncSelection;
    { the object of the chosen node (nil: none, or the tree is not up to date) }
    function SelectedObject: TPersistent;
    { the designer's components were added, deleted or renamed: until the tree is made again its
      nodes are not taken (a deleted component's node points to freed memory) }
    procedure Outdated;
    { the designer whose form the tree shows (nil: none) }
    property Designer: TFormDesigner read FDesigner;
    { Add Item, Delete (also Del in the tree): Sender is the action }
    property OnCommand: TNotifyEvent read FOnCommand write FOnCommand;
    { the menu opens (before its own states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

{$R *.dfm}

constructor TObjTreeView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Tree.Images := IconList;
  Actions.Images := IconList;
  ObjTreePopup.Images := IconList;
  UIOwnerDrawMenus(Self);
end;

{ No flicker: the tree fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TObjTreeView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the tree covers the whole view: nothing of the form shows, nothing to erase }
procedure TObjTreeView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TObjTreeView.Clear;
begin
  FStale := False;
  FUpdating := True;
  try
    Tree.Items.Clear;
  finally
    FUpdating := False;
  end;
  FDesigner := nil;
end;

procedure TObjTreeView.AddCollections(Parent: TTreeNode; C: TComponent);
var
  Count, I, J: Integer;
  Props: PPropList;
  Obj: TObject;
  N, M: TTreeNode;
  Col: TCollection;
begin
  Count := GetPropList(C.ClassInfo, [tkClass], nil);
  if Count = 0 then Exit;
  GetMem(Props, Count * SizeOf(PPropInfo));
  try
    GetPropList(C.ClassInfo, [tkClass], Props);
    for I := 0 to Count - 1 do
    begin
      Obj := GetObjectProp(C, Props^[I]);
      if not (Obj is TCollection) then Continue;
      Col := TCollection(Obj);
      N := Tree.Items.AddChild(Parent, Props^[I]^.Name);
      N.ImageIndex := IconIndex(iiCollection);
      N.SelectedIndex := N.ImageIndex;
      N.Data := Col;
      for J := 0 to Col.Count - 1 do
      begin
        M := Tree.Items.AddChild(N, Format('%d - %s', [J, Col.Items[J].DisplayName]));
        M.ImageIndex := IconIndex(iiItem);
        M.SelectedIndex := M.ImageIndex;
        M.Data := Col.Items[J];
      end;
    end;
  finally
    FreeMem(Props);
  end;
end;

procedure TObjTreeView.AddComponentNodes(Parent: TTreeNode; C: TComponent);
var
  I: Integer;
  N: TTreeNode;
  Root: TComponent;
  MI: TMenuItem;
begin
  Root := FDesigner.Root;
  N := Tree.Items.AddChild(Parent, C.Name);
  if C = Root then N.ImageIndex := IconIndex(iiForm)
  else if C is TControl then N.ImageIndex := IconIndex(iiControl)
  else if C is TMenuItem then N.ImageIndex := IconIndex(iiItem)
  else N.ImageIndex := IconIndex(iiNonVisual);
  N.SelectedIndex := N.ImageIndex;
  N.Data := C;
  if C is TMenuItem then
  begin
    if TMenuItem(C).Caption <> '' then N.Text := C.Name + '  ' + TMenuItem(C).Caption;
    for I := 0 to TMenuItem(C).Count - 1 do AddComponentNodes(N, TMenuItem(C).Items[I]);
    Exit;
  end;
  if C is TMenu then
  begin
    MI := TMenu(C).Items;
    for I := 0 to MI.Count - 1 do AddComponentNodes(N, MI.Items[I]);
  end;
  if C is TCustomActionList then
    for I := 0 to TCustomActionList(C).ActionCount - 1 do
      AddComponentNodes(N, TCustomActionList(C).Actions[I]);
  AddCollections(N, C);
  { children: controls by parent; everything else under the root (IndexChildren) }
  if C = Root then I := FKidHead[0]
  else if C.Owner = Root then I := FKidHead[C.ComponentIndex + 1]
  else I := -1;
  while I >= 0 do
  begin
    AddComponentNodes(N, Root.Components[I]);
    I := FKidNext[I];
  end;
  { a placed frame: its own components, and in its containers theirs }
  if FDesigner.InFrameInstance(C) and (C is TWinControl) then AddFrameNodes(N, C.Owner, TWinControl(C));
  if (C <> Root) and FDesigner.IsDesigned(C) and (csInline in C.ComponentState) and (C is TWinControl) then
    AddFrameNodes(N, C, TWinControl(C));
end;

{ the components of a placed frame (Frame) under the node of Container - the frame or one of its
  controls: its controls there, and under the frame itself the others that have no parent }
procedure TObjTreeView.AddFrameNodes(Parent: TTreeNode; Frame: TComponent; Container: TWinControl);
var
  I: Integer;
  C: TComponent;
begin
  for I := 0 to Frame.ComponentCount - 1 do
  begin
    C := Frame.Components[I];
    if C is TControl then
    begin
      if TControl(C).Parent <> Container then Continue;
    end
    else if (Container <> Frame) or C.HasParent then
      Continue;
    AddComponentNodes(Parent, C);
  end;
end;

{ the children of every component at once (a component's own walk over all of the root's
  components was quadratic): a control under its parent (the root's when it has none), any other
  component under the root unless it has a parent of its own (a menu item) - in the order of
  Root.Components }
procedure TObjTreeView.IndexChildren(Root: TComponent);
var
  I, P: Integer;
  Child, PC: TComponent;
  Par: TWinControl;
begin
  SetLength(FKidHead, Root.ComponentCount + 1);
  SetLength(FKidNext, Root.ComponentCount);
  for I := 0 to High(FKidHead) do FKidHead[I] := -1;
  for I := Root.ComponentCount - 1 downto 0 do
  begin
    Child := Root.Components[I];
    P := -2;
    if Child is TControl then
    begin
      Par := TControl(Child).Parent;
      if (Par = nil) or (Par = Root) then P := -1
      else if Par.Owner = Root then P := Par.ComponentIndex;
    end
    else if not Child.HasParent then
      P := -1
    else if not (Child is TMenuItem) and not (Child is TContainedAction) then
    begin
      { a component with a parent component of its own - a dataset's persistent fields, a chart's
        series: under it, as in Delphi's Object TreeView (menu items and actions come under their
        menu and their action list) }
      PC := Child.GetParentComponent;
      if PC = Root then P := -1
      else if (PC <> nil) and (PC.Owner = Root) then P := PC.ComponentIndex;
    end;
    FKidNext[I] := -1;
    if P > -2 then
    begin
      FKidNext[I] := FKidHead[P + 1];
      FKidHead[P + 1] := I;
    end;
  end;
end;

procedure TObjTreeView.ShowDesigner(D: TFormDesigner);
var
  Open: TList;
  Same: Boolean;
  Place: TUITreePlace;
  I: Integer;
begin
  { the same designer again (its form changed): the nodes the user opened (by their objects) and
    the place in the list stay; another designer starts with its root open }
  Same := (D <> nil) and (D = FDesigner);
  Open := TList.Create;
  try
    if Same then
    begin
      Place := UISaveTreePlace(Tree);
      for I := 0 to Tree.Items.Count - 1 do
        if Tree.Items[I].Expanded and (Tree.Items[I].Data <> nil) then Open.Add(Tree.Items[I].Data);
    end;
    FStale := False;
    FDesigner := D;
    FUpdating := True;
    Tree.Items.BeginUpdate;
    try
      Tree.Items.Clear;
      if (D <> nil) and (D.Root <> nil) then
      begin
        IndexChildren(D.Root);
        AddComponentNodes(nil, D.Root);
        if Tree.Items.Count > 0 then Tree.Items[0].Expand(False);
        if Open.Count > 0 then
          for I := 0 to Tree.Items.Count - 1 do
            if (Tree.Items[I].Data <> nil) and (Open.IndexOf(Tree.Items[I].Data) >= 0) then
              Tree.Items[I].Expand(False);
      end;
    finally
      Tree.Items.EndUpdate;
      if Same then UIRestoreTreePlace(Tree, Place);     // FUpdating: TreeChange selects nothing
      FUpdating := False;
    end;
  finally
    Open.Free;
  end;
  SyncSelection;
end;

function TObjTreeView.FindData(Data: Pointer): TTreeNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Tree.Items.Count - 1 do
    if Tree.Items[I].Data = Data then
    begin
      Result := Tree.Items[I];
      Exit;
    end;
end;

procedure TObjTreeView.SyncSelection;
var
  N: TTreeNode;
begin
  if (FDesigner = nil) or (FDesigner.SelectionCount = 0) then Exit;
  N := FindData(FDesigner.Selections[0]);
  if (N <> nil) and (Tree.Selected <> N) then
  begin
    FUpdating := True;
    try
      Tree.Selected := N;
      N.MakeVisible;
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TObjTreeView.Outdated;
begin
  FStale := True;
end;

function TObjTreeView.SelectedObject: TPersistent;
begin
  Result := nil;
  if FStale or (FDesigner = nil) or (Tree.Selected = nil) or (Tree.Selected.Data = nil) then Exit;
  Result := TPersistent(Tree.Selected.Data);
end;

procedure TObjTreeView.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FUpdating or FStale or (FDesigner = nil) or (Node = nil) or (Node.Data = nil) then Exit;
  if TObject(Node.Data) is TCollection then Exit;
  FDesigner.Select(TPersistent(Node.Data));
end;

procedure TObjTreeView.TreeDblClick(Sender: TObject);
var
  N: TTreeNode;
begin
  N := Tree.Selected;
  if (N = nil) or FStale then Exit;
  if (FDesigner <> nil) and (TObject(N.Data) is TComponent) then
    FDesigner.EditComponent(TComponent(N.Data));
end;

procedure TObjTreeView.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    TreeDblClick(Sender);
    Key := 0;
  end
  else if Key = VK_DELETE then
  begin
    { the node's object, not the designer's selection (a collection's node selects nothing there) }
    if not FStale and Assigned(FOnCommand) then FOnCommand(aObjTreeDelete);
    Key := 0;
  end;
end;

{ Add Item and Delete, named and shown for the object of the node under the mouse }
procedure TObjTreeView.ObjTreePopupPopup(Sender: TObject);
var
  Obj: TPersistent;
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  aObjTreeAdd.Visible := False;
  aObjTreeDelete.Visible := False;
  Obj := SelectedObject;
  if Obj = nil then Exit;
  if (Obj is TCollection) or (Obj is TCollectionItem) then
  begin
    aObjTreeAdd.Caption := '&Add Item';
    aObjTreeAdd.Visible := True;
    aObjTreeDelete.Caption := '&Delete Item';
    aObjTreeDelete.Visible := Obj is TCollectionItem;
  end
  else if (Obj is TMenu) or (Obj is TMenuItem) then
  begin
    aObjTreeAdd.Caption := '&Add Menu Item';
    aObjTreeAdd.Visible := True;
    aObjTreeDelete.Caption := '&Delete';
    aObjTreeDelete.Visible := Obj is TMenuItem;
  end
  else if (Obj is TComponent) and (Obj <> FDesigner.Root) then
  begin
    aObjTreeDelete.Caption := '&Delete';
    aObjTreeDelete.Visible := True;
  end;
end;

procedure TObjTreeView.CommandExecute(Sender: TObject);
begin
  if Assigned(FOnCommand) then FOnCommand(Sender);
end;

end.
