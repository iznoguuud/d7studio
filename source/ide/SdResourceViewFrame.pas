{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResourceViewFrame;

{ D7 Studio - the Resources view (View | Resources): the resources of
  the active project's .res under its tool bar (Add | Edit, Delete | Export), in two columns -
  Resource and Details -, a folder per kind of resource as Visual Studio's Resource View has
  them. A frame inherited from the column tree's (SdColumnTreeFrame; SdResourceViewFrame.dfm: the
  columns, the tool bar), made by the main form (CreatePanes), which links the buttons to its
  commands; it fills the view (Fill) and runs the commands (SdResources does the work). }

interface

uses
  SysUtils, Classes, Graphics, ComCtrls, Menus, ActnList, SdColumnTreeFrame,
  SdProject, SdResources;

type
  TSdResourceView = class(TSdColumnTree)
    Bar: TToolBar;
    MenuActions: TActionList;
    aResEdit: TAction;
    aResEditHex: TAction;
    aResNewBitmap: TAction;
    aResNewIcon: TAction;
    aResNewCursor: TAction;
    aResNewStrings: TAction;
    aResNewManifest: TAction;
    aResImport: TAction;
    aResRename: TAction;
    aResDelete: TAction;
    aResExport: TAction;
    aResStatusBar: TAction;
    ResPopup: TPopupMenu;
    ResAddMenu: TPopupMenu;
    pmResEdit: TMenuItem;
    pmResEditHex: TMenuItem;
    pmResAdd: TMenuItem;
    pmResAddBitmap: TMenuItem;
    pmResAddIcon: TMenuItem;
    pmResAddCursor: TMenuItem;
    pmResAddStrings: TMenuItem;
    pmResAddManifest: TMenuItem;
    pmResAddN1: TMenuItem;
    pmResAddImport: TMenuItem;
    pmResRename: TMenuItem;
    pmResDelete: TMenuItem;
    pmResExport: TMenuItem;
    pmResN1: TMenuItem;
    pmResStatusBar: TMenuItem;
    raBitmap: TMenuItem;
    raIcon: TMenuItem;
    raCursor: TMenuItem;
    raStrings: TMenuItem;
    raManifest: TMenuItem;
    raN1: TMenuItem;
    raImport: TMenuItem;
    tbResAdd: TToolButton;
    tbResEdit: TToolButton;
    tbResDelete: TToolButton;
    tbResSep1: TToolButton;
    tbResExport: TToolButton;
  private
    FProject: TSdProject;
    FRes: TSdResources;
    procedure Cell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the resources of the project (nil: none) read again; the chosen item stays chosen, or the
      item of SelectKey is chosen; folders open as they were }
    procedure Fill(P: TSdProject; const SelectKey: string = '');
    function Selected: TSdResItem;                // the chosen resource (a folder: nil)
    function DebugText: string;   // the state dump's resview=: project|file|rows (> level, * chosen)
    property Project: TSdProject read FProject;
    property Resources: TSdResources read FRes;   // nil without a project
  end;

function ResKindIcon(Kind: TSdResKind): Integer;

implementation

{$R *.dfm}

uses
  SdIcons, SdUI;

function ResKindIcon(Kind: TSdResKind): Integer;
const
  Icons: array[TSdResKind] of TSdIcon = (iiResBitmap, iiResIcon, iiResCursor, iiResStrings,
    iiResVersion, iiResManifest, iiResData);
begin
  Result := IconIndex(Icons[Kind]);
end;

constructor TSdResourceView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnCell := Cell;
end;

destructor TSdResourceView.Destroy;
begin
  FreeAndNil(FRes);
  inherited Destroy;
end;

procedure TSdResourceView.Cell(Sender: TObject; Node: TTreeNode; var Value: string; var Color: TColor);
begin
  if Node.Data <> nil then Value := TSdResItem(Node.Data).Detail;
end;

procedure TSdResourceView.Fill(P: TSdProject; const SelectKey: string);
var
  I: Integer;
  It: TSdResItem;
  Folder, N, Chosen: TTreeNode;
  Key, FolderText: string;
  Closed: TStringList;
  Place: TUITreePlace;
begin
  { what was chosen and which folders were closed: the same project keeps them }
  Key := SelectKey;
  if (Key = '') and (Selected <> nil) then Key := Selected.Key;
  Closed := TStringList.Create;
  try
    if P = FProject then
    begin
      Place := UISaveTreePlace(Tree);
      N := Tree.Items.GetFirstNode;
      while N <> nil do
      begin
        if not N.Expanded then Closed.Add(N.Text);
        N := N.GetNextSibling;
      end;
    end
    else
      Key := SelectKey;
    Chosen := nil;
    Tree.Items.BeginUpdate;
    try
      { the rows go before the items they point to (the tree's change event reads them) }
      Tree.Items.Clear;
      if (FRes <> nil) and ((P = nil) or (FRes.ProjectFile <> P.FileName)) then FreeAndNil(FRes);
      FProject := P;
      if (P <> nil) and (FRes = nil) then FRes := TSdResources.Create(P.FileName);
      if FRes = nil then Exit;
      FRes.Refresh;
      Folder := nil;
      FolderText := '';
      for I := 0 to FRes.Count - 1 do
      begin
        It := FRes.Item(I);
        if (Folder = nil) or (It.TypeText <> FolderText) then
        begin
          FolderText := It.TypeText;
          if It.Kind = rkData then Folder := Tree.Items.AddChild(nil, FolderText)
          else Folder := Tree.Items.AddChild(nil, ResKindText(It.Kind));
          Folder.ImageIndex := IconIndex(iiFolder);
          Folder.SelectedIndex := Folder.ImageIndex;
        end;
        N := Tree.Items.AddChild(Folder, It.NameText);
        N.ImageIndex := ResKindIcon(It.Kind);
        N.SelectedIndex := N.ImageIndex;
        N.Data := It;
        if It.Key = Key then Chosen := N;
      end;
      N := Tree.Items.GetFirstNode;
      while N <> nil do
      begin
        if Closed.IndexOf(N.Text) < 0 then N.Expand(False);
        N := N.GetNextSibling;
      end;
    finally
      Tree.Items.EndUpdate;
    end;
    { the same project: its place again; another one: Place is empty - the top (the Expands above
      scrolled the tree to its bottom) }
    if Chosen <> nil then
    begin
      Chosen.Selected := True;
      Chosen.MakeVisible;
    end
    else if (P <> nil) and (SelectKey = '') then
      UIRestoreTreePlace(Tree, Place);
  finally
    Closed.Free;
  end;
end;

function TSdResourceView.Selected: TSdResItem;
begin
  Result := nil;
  if (Tree.Selected <> nil) and (Tree.Selected.Data <> nil) then Result := TSdResItem(Tree.Selected.Data);
end;

function TSdResourceView.DebugText: string;
begin
  Result := '';
  if FProject <> nil then Result := ExtractFileName(FProject.FileName);
  Result := Result + '|';
  if FRes <> nil then
  begin
    Result := Result + ExtractFileName(FRes.ResFile);
    if not FRes.CanWrite then Result := Result + '(invalid)';
  end;
  { an item's row with its Details (Cell), also an empty one }
  Result := Result + '|' + RowsText(True);
end;

end.
