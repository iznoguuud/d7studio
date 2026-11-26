{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPackageViewFrame;

{ D7 Studio - Delphi 7's package editor as a view of the dock:
  under its tool bar (Compile | Add, Remove | Install, Options) the package in two columns, Files
  and Path - Contains with the units of the contains clause, Requires with the packages of the
  requires clause (their .dcp where the compiler finds it). A frame inherited from the column
  tree's (SdColumnTreeFrame; SdPackageViewFrame.dfm: the columns, the tool bar), made by the main
  form (NewPackageView) - one view for every open package, as Delphi 7 has a window for each -,
  which links the buttons to its commands, gives the view its package (Project), fills it (Fill)
  and runs the commands on that package. }

interface

uses
  SysUtils, Classes, Graphics, ComCtrls, Menus, ActnList, SdColumnTreeFrame,
  SdProject;

type
  TSdPackageView = class(TSdColumnTree)
    Bar: TToolBar;
    MenuActions: TActionList;
    aPkgOpen: TAction;
    aPkgAdd: TAction;
    aPkgRemove: TAction;
    aPkgCompile: TAction;
    aPkgBuild: TAction;
    aPkgInstall: TAction;
    aPkgViewSource: TAction;
    aPkgOptions: TAction;
    aPkgStatusBar: TAction;
    PkgPopup: TPopupMenu;
    pmPkgOpen: TMenuItem;
    pmPkgN1: TMenuItem;
    pmPkgAdd: TMenuItem;
    pmPkgRemove: TMenuItem;
    pmPkgN2: TMenuItem;
    pmPkgCompile: TMenuItem;
    pmPkgBuild: TMenuItem;
    pmPkgInstall: TMenuItem;
    pmPkgViewSource: TMenuItem;
    pmPkgOptions: TMenuItem;
    pmPkgN3: TMenuItem;
    pmPkgStatusBar: TMenuItem;
    tbPkgCompile: TToolButton;
    tbPkgSep1: TToolButton;
    tbPkgAdd: TToolButton;
    tbPkgRemove: TToolButton;
    tbPkgSep2: TToolButton;
    tbPkgInstall: TToolButton;
    tbPkgOptions: TToolButton;
  private
    FProject: TSdProject;
    FContains, FRequires: TTreeNode;
    FReqPaths: TStringList;          // the .dcp of each required package ('' not found)
    procedure Cell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
    procedure SetProject(Value: TSdProject);
  protected
    { unnamed while its .dfm is read: several views of it share the main form as owner }
    procedure SetName(const NewName: TComponentName); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the package's contains and requires clauses (P: the view's package; nil or not a package:
      empty); the chosen item stays chosen }
    procedure Fill(P: TSdProject);
    function SelectedUnit: TProjectUnit;          // a unit of Contains, else nil
    function SelectedPackage: string;             // a package of Requires, else ''
    function SelectedFile: string;                // the chosen item's file ('' none)
    function DebugText: string;   // the state dump's pkgview=: project|rows (name=path, * chosen, > level)
    { the package the view is for (nil: none - a free view); another one empties the view until
      Fill fills it }
    property Project: TSdProject read FProject write SetProject;
  end;

implementation

{$R *.dfm}

uses
  SdIcons, SdUI;

constructor TSdPackageView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReqPaths := TStringList.Create;
  OnCell := Cell;
end;

destructor TSdPackageView.Destroy;
begin
  FreeAndNil(FReqPaths);
  inherited Destroy;
end;

procedure TSdPackageView.SetName(const NewName: TComponentName);
begin
  if csReading in ComponentState then inherited SetName('') else inherited SetName(NewName);
end;

procedure TSdPackageView.SetProject(Value: TSdProject);
begin
  if Value = FProject then Exit;
  Fill(nil);                           // its rows point into the project before
  if (Value <> nil) and Value.IsPackage then FProject := Value;
end;

procedure TSdPackageView.Cell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
begin
  if Node.Data <> nil then Value := ExtractFileDir(TProjectUnit(Node.Data).FileName)
  else if (Node.Parent = FRequires) and (Node.Index < FReqPaths.Count) then Value := ExtractFileDir(FReqPaths[Node.Index]);
end;

procedure TSdPackageView.Fill(P: TSdProject);
var
  I: Integer;
  N: TTreeNode;
  Place: TUITreePlace;

  { the images are the Project Manager's tree images, as a package's nodes there have them }
  function Folder(const Text: string): TTreeNode;
  begin
    Result := Tree.Items.AddChild(nil, Text);
    Result.ImageIndex := IconIndex(iiPmFolder);
    Result.SelectedIndex := Result.ImageIndex;
  end;

begin
  if (P <> nil) and not P.IsPackage then P := nil;
  { the same package again keeps its place; another one starts at the top }
  if P = FProject then Place := UISaveTreePlace(Tree);
  FProject := P;
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    FContains := nil;
    FRequires := nil;
    FReqPaths.Clear;
    if P = nil then Exit;
    FContains := Folder('Contains');
    for I := 0 to P.UnitCount - 1 do
    begin
      N := Tree.Items.AddChild(FContains, ExtractFileName(P.Units[I].FileName));
      if P.Units[I].HasForm then N.ImageIndex := IconIndex(iiPmUnitForm) else N.ImageIndex := IconIndex(iiPmSource);
      N.SelectedIndex := N.ImageIndex;
      N.Data := P.Units[I];
    end;
    FRequires := Folder('Requires');
    for I := 0 to P.Requires.Count - 1 do
    begin
      N := Tree.Items.AddChild(FRequires, P.Requires[I] + '.dcp');
      N.ImageIndex := IconIndex(iiPmSource);
      N.SelectedIndex := N.ImageIndex;
      FReqPaths.Add(P.FindDcp(P.Requires[I]));
    end;
    FContains.Expand(False);
    FRequires.Expand(False);
  finally
    Tree.Items.EndUpdate;
  end;
  if P <> nil then UIRestoreTreePlace(Tree, Place);   // not the bottom, where the Expands scrolled to
end;

function TSdPackageView.SelectedUnit: TProjectUnit;
begin
  Result := nil;
  if (Tree.Selected <> nil) and (Tree.Selected.Parent = FContains) then Result := TProjectUnit(Tree.Selected.Data);
end;

function TSdPackageView.SelectedPackage: string;
begin
  Result := '';
  if (Tree.Selected <> nil) and (Tree.Selected.Parent = FRequires) then
    Result := ChangeFileExt(Tree.Selected.Text, '');
end;

function TSdPackageView.SelectedFile: string;
var
  N: TTreeNode;
begin
  Result := '';
  N := Tree.Selected;
  if N = nil then Exit;
  if N.Data <> nil then Result := TProjectUnit(N.Data).FileName
  else if (N.Parent = FRequires) and (N.Index < FReqPaths.Count) then
  begin
    Result := FReqPaths[N.Index];
    if Result = '' then Result := N.Text;
  end;
end;

function TSdPackageView.DebugText: string;
begin
  Result := '';
  if FProject <> nil then Result := ExtractFileName(FProject.FileName);
  Result := Result + '|' + RowsText(False);
end;

end.
