{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdProjectManager;

{ D7 Studio - the Project Manager view: the project group, its projects, their units and
  resource scripts, and the packages a package requires - after the group, as Delphi 7 shows them,
  the packages open beside it (its unbound packages); Delphi's tool bar (New, Remove, Activate -
  not its projects box; laid out by the dock: TSdDockPanel.ToolBar) and the local menu of its
  nodes. A form made once (its tool bar, tree, menu and
  actions in the .dfm), docked by the IDE - a child window then, without a border. The menu's
  group commands are the main form's actions: the IDE sets them when it makes the view
  (TMainForm.CreatePanes), as a link to another module in the .dfm ("AppBuilder.ProjectBuildAll
  Command") is bound by a designer to the running IDE's own main form, also named AppBuilder; the
  dock's commands at the menu's end are the IDE's too (TMainForm.AddDockItems). The commands of
  the view's own actions are carried out by the IDE (OnCommand). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, CommCtrl, Menus, ActnList,
  SdUI, SdIcons, SdDock, SdProject, SdProjectGroup;

type
  { a node opened by a double click: the group's, a project's, a unit's or another one }
  TProjectNodeEvent = procedure(Sender: TObject; Node: TTreeNode) of object;

  TProjectManagerView = class(TForm)
    Bar: TToolBar;
    tbPMNew: TToolButton;
    tbPMRemove: TToolButton;
    tbPMActivate: TToolButton;
    Tree: TTreeView;
    Actions: TActionList;
    aSaveGroup: TAction;
    aSaveGroupAs: TAction;
    aActivateProject: TAction;
    aRemoveProject: TAction;
    aPMSave: TAction;
    aPMOptions: TAction;
    aPMCompile: TAction;
    aPMBuild: TAction;
    aPMViewSource: TAction;
    aPMStatusBar: TAction;
    ProjPopup: TPopupMenu;
    pmProjG1: TMenuItem;
    pmProjG2: TMenuItem;
    pmProjG3: TMenuItem;
    pmProjG4: TMenuItem;
    pmProjG9: TMenuItem;
    pmProjG10: TMenuItem;
    pmProjG11: TMenuItem;
    pmProjG5: TMenuItem;
    pmProjP1: TMenuItem;
    pmProjP2: TMenuItem;
    pmProjP3: TMenuItem;
    pmProjG6: TMenuItem;
    pmProjP4: TMenuItem;
    pmProjP5: TMenuItem;
    pmProjP6: TMenuItem;
    pmProjG7: TMenuItem;
    pmProjG8: TMenuItem;
    pmProj1: TMenuItem;
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure TreeDblClick(Sender: TObject);
    procedure CommandExecute(Sender: TObject);
    procedure StatusBarExecute(Sender: TObject);
    procedure ProjPopupPopup(Sender: TObject);
  private
    FGroup: TSdProjectGroup;
    FPanel: TSdDockPanel;
    FTreeProjects: TStringList;      // the project nodes' files: the group's projects, then the packages beside it
    FTreeGroupCount: Integer;        // ... how many are the group's (the children of its node)
    FActiveFile: string;             // the active project's file, its node in bold ('' none)
    FOnCommand: TNotifyEvent;
    FOnOpen: TProjectNodeEvent;
    FOnMenuPopup: TNotifyEvent;
    function GroupNode: TTreeNode;
    function ProjectIndexOf(N: TTreeNode): Integer;
    function ProjectNodeIndex(N: TTreeNode): Integer;
    procedure SetBold(N: TTreeNode);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    { the group's projects in its order, then the packages beside the group as nodes of their own
      named as Delphi 7 names them - the active project in bold - with their units, resource
      scripts and required packages; open nodes stay open and the chosen node stays chosen }
    procedure ShowGroup(Active: TSdProject);
    { the active project's node in bold again: a new window of the tree (its group floated or
      docked) keeps the nodes as they were, opened and chosen, but not their bold }
    procedure MarkActive;
    { N is a project's node (a project of the group, a package beside it) }
    function IsProjectNode(N: TTreeNode): Boolean;
    { the enabled states of the view's own commands }
    procedure UpdateCommands(Compiling, Debugging: Boolean; Active: TSdProject);
    { the project file of the chosen project node (or of the project a chosen node belongs to);
      '' none }
    function SelectedProject: string;
    { the unit of the chosen node - a resource script's node gives its TProjectResScript; nil:
      neither }
    function SelectedUnit: TProjectUnit;
    { the node of project Index (0: the group's first; after the group's, the packages beside it);
      nil: none }
    function ProjectNode(Index: Integer): TTreeNode;
    property Group: TSdProjectGroup read FGroup write FGroup;
    { the dock's panel of the view: its status line shows the chosen node's file }
    property Panel: TSdDockPanel read FPanel write FPanel;
    { one of the view's actions but the status bar's: Sender is the action }
    property OnCommand: TNotifyEvent read FOnCommand write FOnCommand;
    property OnOpen: TProjectNodeEvent read FOnOpen write FOnOpen;
    { the menu opens (before its own states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

{$R *.dfm}

constructor TProjectManagerView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Tree.Images := IconList;
  Actions.Images := IconList;
  ProjPopup.Images := IconList;
  Bar.Images := IconList;
  UIOwnerDrawMenus(Self);
  { a double click activates a project (or opens a unit), as Delphi's: it opens or closes no node }
  UITreeNoDblClickToggle(Tree);
  FTreeProjects := TStringList.Create;
end;

destructor TProjectManagerView.Destroy;
begin
  FTreeProjects.Free;
  inherited;
end;

{ No flicker: the tree fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TProjectManagerView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the tree covers the whole view (the tool bar is the dock's to lay out): nothing of the form
  shows, nothing to erase }
procedure TProjectManagerView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

{ Without a window (its group floated or docked while hidden) the tree empties nothing: the VCL
  keeps its nodes and gives them back with the next window, their units gone by then. A tree
  filled before gets its window first, the nodes then come back and go at once (no OnChange: it
  reads a node's unit) }
procedure TProjectManagerView.Clear;
var
  Change: TTVChangedEvent;
begin
  Change := Tree.OnChange;
  Tree.OnChange := nil;
  try
    if (FTreeProjects.Count > 0) and not Tree.HandleAllocated then Tree.HandleNeeded;
    Tree.Items.Clear;
  finally
    Tree.OnChange := Change;
  end;
  FTreeProjects.Clear;
  FTreeGroupCount := 0;
  FActiveFile := '';
end;

{ The nodes are found by their places, never kept: a new window of the tree (its group floated or
  docked) makes new ones. The group's node: the first while the group has projects (nil: none) }
function TProjectManagerView.GroupNode: TTreeNode;
begin
  if FTreeGroupCount > 0 then Result := Tree.Items.GetFirstNode else Result := nil;
end;

{ the index of the project node N is or lies under (FTreeProjects); -1: none - the group's node,
  a node from before the last fill }
function TProjectManagerView.ProjectIndexOf(N: TTreeNode): Integer;
var
  G: TTreeNode;
begin
  Result := -1;
  if N = nil then Exit;
  G := GroupNode;
  { up to the project's node: a child of the group's node, else a node of its own after it }
  while (N.Parent <> nil) and (N.Parent <> G) do N := N.Parent;
  if N = G then Exit;
  if N.Parent <> nil then Result := N.Index else Result := FTreeGroupCount + N.Index - Ord(G <> nil);
  if Result >= FTreeProjects.Count then Result := -1;
end;

{ the index of N when it is a project's node itself; -1: it is not }
function TProjectManagerView.ProjectNodeIndex(N: TTreeNode): Integer;
begin
  if (N <> nil) and ((N.Parent = nil) or (N.Parent = GroupNode)) then Result := ProjectIndexOf(N)
  else Result := -1;
end;

function TProjectManagerView.IsProjectNode(N: TTreeNode): Boolean;
begin
  Result := ProjectNodeIndex(N) >= 0;
end;

{ the status line: the file of the chosen item (a unit, a project, the group), the name of a
  required package }
procedure TProjectManagerView.TreeChange(Sender: TObject; Node: TTreeNode);
var
  S: string;
  I: Integer;
begin
  if FPanel = nil then Exit;
  S := '';
  if Node <> nil then
  begin
    I := ProjectNodeIndex(Node);
    if Node.Data <> nil then S := TProjectUnit(Node.Data).FileName
    else if I >= 0 then S := FTreeProjects[I]
    else if Node = GroupNode then S := FGroup.FileName
    else S := Node.Text;
  end;
  FPanel.StatusText := S;
end;

{ a closed project of the group (IOTAModule.CloseModule: Activate loads it again) - its node in
  grey }
procedure TProjectManagerView.TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  I: Integer;
begin
  I := ProjectNodeIndex(Node);
  if (I >= 0) and (FGroup.LoadedProjectOf(FTreeProjects[I]) = nil) and not (cdsSelected in State) then
    Sender.Canvas.Font.Color := clGrayText;
end;

{ on the node it hits only (its box: none) }
procedure TProjectManagerView.TreeDblClick(Sender: TObject);
var
  N: TTreeNode;
begin
  N := UITreeDblClickNode(Tree);
  if (N <> nil) and (N = Tree.Selected) and Assigned(FOnOpen) then FOnOpen(Self, N);
end;

procedure TProjectManagerView.CommandExecute(Sender: TObject);
begin
  if Assigned(FOnCommand) then FOnCommand(Sender);
end;

procedure TProjectManagerView.StatusBarExecute(Sender: TObject);
begin
  if FPanel <> nil then FPanel.ShowStatus := not FPanel.ShowStatus;
end;

procedure TProjectManagerView.ProjPopupPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  aPMStatusBar.Checked := (FPanel <> nil) and FPanel.ShowStatus;
end;

{ N in bold: a state of its item in the tree's window, which a new window does not keep }
procedure TProjectManagerView.SetBold(N: TTreeNode);
var
  Item: TTVItem;
begin
  if N = nil then Exit;
  FillChar(Item, SizeOf(Item), 0);
  Item.mask := TVIF_STATE or TVIF_HANDLE;
  Item.hItem := N.ItemId;
  Item.stateMask := TVIS_BOLD;
  Item.state := TVIS_BOLD;
  TreeView_SetItem(Tree.Handle, Item);
end;

procedure TProjectManagerView.MarkActive;
begin
  if FActiveFile <> '' then SetBold(ProjectNode(FTreeProjects.IndexOf(FActiveFile)));
end;

procedure TProjectManagerView.ShowGroup(Active: TSdProject);
var
  Sel, N, G: TTreeNode;
  I, SelDepth: Integer;
  Opened, Known, ByName: TStringList;
  SelProject, SelText: string;
  SelGroup: Boolean;

  { a project's node under Parent (the group's; nil: a package beside the group, a node of its
    own) with its units, resource scripts and required packages; the node chosen before is found
    again by its project, its depth under the project and its text }
  procedure AddProject(Parent: TTreeNode; const FileName, Text: string; P: TSdProject);
  var
    PN, N, Req: TTreeNode;
    I: Integer;
    U: TProjectUnit;

    function Child(AParent: TTreeNode; const AText: string; Image: TSdIcon; Depth: Integer): TTreeNode;
    begin
      Result := Tree.Items.AddChild(AParent, AText);
      Result.ImageIndex := IconIndex(Image);
      Result.SelectedIndex := Result.ImageIndex;
      if (Sel = PN) and (SelDepth = Depth) and (AText = SelText) then Sel := Result;
    end;

  begin
    PN := Tree.Items.AddChild(Parent, Text);
    { Delphi 7's images: a package's, every other project's (an application, a library) }
    if IsPackageFile(FileName) then PN.ImageIndex := IconIndex(iiPmPackage)
    else PN.ImageIndex := IconIndex(iiPmProject);
    PN.SelectedIndex := PN.ImageIndex;
    FTreeProjects.Add(FileName);
    if (SelDepth >= 0) and SameText(SelProject, FileName) then Sel := PN;
    { a closed project (IOTAModule.CloseModule): its node alone, greyed (TreeCustomDrawItem) }
    if P = nil then Exit;
    if P.Platform = spWin64 then PN.Text := PN.Text + ' (Win64)';
    ByName.Clear;
    for I := 0 to P.UnitCount - 1 do ByName.AddObject(P.Units[I].Name, P.Units[I]);
    for I := 0 to ByName.Count - 1 do
    begin
      U := TProjectUnit(ByName.Objects[I]);
      if U.HasForm then N := Child(PN, U.Name, iiPmUnitForm, 1) else N := Child(PN, U.Name, iiPmSource, 1);
      N.Data := U;
    end;
    { the resource scripts ($R 'x.res' 'x.rc') by their file names, after the units }
    ByName.Clear;
    for I := 0 to P.ResScriptCount - 1 do ByName.AddObject(P.ResScripts[I].Name, P.ResScripts[I]);
    for I := 0 to ByName.Count - 1 do Child(PN, ByName[I], iiPmSource, 1).Data := ByName.Objects[I];
    { a package: the packages it is built on, as in Delphi's package editor }
    if P.Requires.Count > 0 then
    begin
      Req := Child(PN, 'Requires', iiPmFolder, 1);
      ByName.Clear;
      ByName.AddStrings(P.Requires);
      for I := 0 to ByName.Count - 1 do Child(Req, ByName[I] + '.dcp', iiPmSource, 2);
    end;
    if P = Active then SetBold(PN);
    { open as it was - activating opens or closes no node, as in Delphi; a project new in the
      tree opens when it is the active one }
    if (Opened.IndexOf(FileName) >= 0) or ((P = Active) and (Known.IndexOf(FileName) < 0)) then
      PN.Expand(False);
  end;

begin
  Opened := TStringList.Create;
  Known := TStringList.Create;
  { a project's units and a package's required packages by name, as Delphi 7's Project Manager
    lists them (the project keeps the order of its uses / requires clause) }
  ByName := TStringList.Create;
  ByName.Sorted := True;
  ByName.Duplicates := dupAccept;
  { the tree may get its window now (BeginUpdate), with its nodes read back from before - their
    units may be gone: no OnChange (it reads a unit) until the tree is filled anew }
  Tree.OnChange := nil;
  Tree.Items.BeginUpdate;
  try
    { the projects' nodes that are open stay open, and the chosen node stays chosen - known by
      their projects' files }
    for I := 0 to FTreeProjects.Count - 1 do
    begin
      N := ProjectNode(I);
      if (N <> nil) and N.Expanded then Opened.Add(FTreeProjects[I]);
    end;
    Known.Assign(FTreeProjects);
    SelDepth := -1;
    SelProject := '';
    SelText := '';
    SelGroup := False;
    if Tree.Selected <> nil then
    begin
      SelText := Tree.Selected.Text;
      I := ProjectIndexOf(Tree.Selected);
      N := ProjectNode(I);
      if N <> nil then
      begin
        SelProject := FTreeProjects[I];
        SelDepth := Tree.Selected.Level - N.Level;
      end
      else
        SelGroup := Tree.Selected = GroupNode;
    end;
    Clear;
    Sel := nil;
    if Active <> nil then FActiveFile := Active.FileName;
    if FGroup.Count > 0 then
    begin
      G := Tree.Items.Add(nil, FGroup.Name);
      G.ImageIndex := IconIndex(iiPmGroup);
      G.SelectedIndex := G.ImageIndex;
      if SelGroup then Sel := G;
      for I := 0 to FGroup.Count - 1 do AddProject(G, FGroup.Projects[I], FGroup.Target(I), FGroup.Project(I));
      FTreeGroupCount := FGroup.Count;
      G.Expand(False);
    end;
    { the packages beside the group: named by their files alone, as Delphi 7 names its unbound
      packages }
    for I := 0 to FGroup.BesideCount - 1 do
      AddProject(nil, FGroup.AllFile(FGroup.Count + I), FGroup.Beside(I).Name, FGroup.Beside(I));
    if Sel <> nil then Sel.Selected := True;
  finally
    Tree.Items.EndUpdate;
    Tree.OnChange := TreeChange;
    Opened.Free;
    Known.Free;
    ByName.Free;
  end;
  { the status line: the node chosen now }
  TreeChange(Tree, Tree.Selected);
end;

{ the group's projects are the children of its node, the packages beside the group the nodes after
  it }
function TProjectManagerView.ProjectNode(Index: Integer): TTreeNode;
var
  G: TTreeNode;
begin
  Result := nil;
  if (Index < 0) or (Index >= FTreeProjects.Count) then Exit;
  G := GroupNode;
  if Index < FTreeGroupCount then
  begin
    if (G <> nil) and (Index < G.Count) then Result := G.Item[Index];
    Exit;
  end;
  Result := Tree.Items.GetFirstNode;
  if G <> nil then Result := Result.GetNextSibling;
  Dec(Index, FTreeGroupCount);
  while (Result <> nil) and (Index > 0) do
  begin
    Result := Result.GetNextSibling;
    Dec(Index);
  end;
end;

procedure TProjectManagerView.UpdateCommands(Compiling, Debugging: Boolean; Active: TSdProject);
var
  S: string;
begin
  S := SelectedProject;
  aSaveGroup.Enabled := FGroup.Count > 0;
  aSaveGroupAs.Enabled := FGroup.Count > 0;
  { also a closed project (Activate loads it again) - while no project is active too }
  aActivateProject.Enabled := not Compiling and (S <> '') and
    ((Active = nil) or not SameText(S, Active.FileName));
  { a package beside the group: it closes (Delphi's Remove of an unbound package) }
  aRemoveProject.Enabled := not Compiling and (S <> '');
  { the chosen project node's commands, on that project (not on a closed one) }
  aPMSave.Enabled := FGroup.LoadedProjectOf(S) <> nil;
  aPMOptions.Enabled := aPMSave.Enabled;
  aPMViewSource.Enabled := aPMSave.Enabled;
  aPMCompile.Enabled := aPMSave.Enabled and not Debugging and not Compiling;
  aPMBuild.Enabled := aPMCompile.Enabled;
end;

function TProjectManagerView.SelectedProject: string;
var
  I: Integer;
begin
  I := ProjectIndexOf(Tree.Selected);
  if I >= 0 then Result := FTreeProjects[I] else Result := '';
end;

function TProjectManagerView.SelectedUnit: TProjectUnit;
begin
  if (Tree.Selected <> nil) and (Tree.Selected.Data <> nil) then Result := TProjectUnit(Tree.Selected.Data)
  else Result := nil;
end;

end.
