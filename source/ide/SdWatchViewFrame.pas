{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdWatchViewFrame;

{ D7 Studio - Delphi 7's Watch List as a view (View | Debug Windows | Watches). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, ComCtrls, CommCtrl, Menus, ActnList, SdUI, SdTabStrip,
  SdColumnTreeFrame;

type
  { the text of a row of the Watch List: its value (the second column) and the colour of the row }
  TSdWatchCellEvent = TSdColumnCellEvent;

  { Delphi 7's Watch List: two columns, Watch Name and Value - their
    header shown or not (Show Column Headers), the first column's width moved there
    (SdColumnTreeFrame) -, a check box before each watch (enabled) and the groups as tabs below
    it (Delphi's TTabSet; here the IDE's tabs). The rows are the IDE's watch tree (a structured
    value opens as in Local Variables); the debugger front end fills it and says what each row
    shows (OnCell). A frame inherited from the column tree's (SdWatchViewFrame.dfm: the columns,
    the check boxes' image list), made by the main form (CreatePanes); the group tabs, the IDE's own
    control, are made in code. }
  TSdWatchView = class(TSdColumnTree)
    Checks: TImageList;
    MenuActions: TActionList;
    aWatchEdit: TAction;
    aWatchNew: TAction;
    aWatchEnable: TAction;
    aWatchDisable: TAction;
    aWatchDelete: TAction;
    aWatchCopyValue: TAction;
    aWatchCopyName: TAction;
    aWatchEnableAll: TAction;
    aWatchDisableAll: TAction;
    aWatchDeleteAll: TAction;
    aWatchAddGroup: TAction;
    aWatchDeleteGroup: TAction;
    aWatchMoveGroup: TAction;
    aWatchBreakChanged: TAction;
    aWatchHeaders: TAction;
    WatchPopup: TPopupMenu;
    pmWatch1: TMenuItem;
    pmWatch2: TMenuItem;
    pmWatch3: TMenuItem;
    pmWatch4: TMenuItem;
    pmWatch5: TMenuItem;
    pmWatch6: TMenuItem;
    pmWatch7: TMenuItem;
    pmWatch8: TMenuItem;
    pmWatch9: TMenuItem;
    pmWatch10: TMenuItem;
    pmWatch11: TMenuItem;
    pmWatch12: TMenuItem;
    pmWatch13: TMenuItem;
    pmWatch14: TMenuItem;
    pmWatch15: TMenuItem;
    pmWatch16: TMenuItem;
    pmWatch17: TMenuItem;
    pmWatch19: TMenuItem;
    pmWatch20: TMenuItem;
    pmWatch21: TMenuItem;
  private
    FTabs: TSdTabStrip;
    FOnGroupChange: TNotifyEvent;
    procedure TabsChange(Sender: TObject);
    procedure MakeChecks;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    { a watch's check box (a row of the first level; the others have none) }
    procedure SetChecked(Node: TTreeNode; Value: Boolean);
    function IsCheckBox(X, Y: Integer): Boolean;  // a point of the tree on a check box
    procedure SetGroups(Names: TStrings; Index: Integer);   // the tabs, the one shown
    function GroupIndex: Integer;                 // the tab shown
    function DebugText: string;   // the state dump's watchview=: headers|first column|tabs (* shown)|rows
    property OnGroupChange: TNotifyEvent read FOnGroupChange write FOnGroupChange;   // a tab chosen
  end;

implementation

{$R *.dfm}

uses
  Math, SdCheckImages;

{ ---------------------------------------------------------------- TSdWatchView }

constructor TSdWatchView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTabs := TSdTabStrip.Create(Self);
  FTabs.Parent := Self;
  FTabs.Side := tsBottom;
  FTabs.OnChange := TabsChange;
  MakeChecks;
end;

{ the state images of the tree: Delphi's check box unchecked and checked (SdCheckImages) }
procedure TSdWatchView.MakeChecks;
begin
  MakeCheckImages(Checks);
end;

procedure TSdWatchView.SetChecked(Node: TTreeNode; Value: Boolean);
begin
  if Value then Node.StateIndex := ciChecked else Node.StateIndex := ciUnchecked;
end;

function TSdWatchView.IsCheckBox(X, Y: Integer): Boolean;
begin
  Result := htOnStateIcon in Tree.GetHitTestInfoAt(X, Y);
end;

procedure TSdWatchView.SetGroups(Names: TStrings; Index: Integer);
var
  I: Integer;
begin
  if not FTabs.Tabs.Equals(Names) then
  begin
    FTabs.Tabs.BeginUpdate;
    try
      FTabs.Tabs.Clear;
      for I := 0 to Names.Count - 1 do FTabs.Tabs.Add(Names[I]);
    finally
      FTabs.Tabs.EndUpdate;
    end;
  end;
  FTabs.TabIndex := Index;
end;

function TSdWatchView.GroupIndex: Integer;
begin
  Result := FTabs.TabIndex;
end;

procedure TSdWatchView.TabsChange(Sender: TObject);
begin
  if Assigned(FOnGroupChange) then FOnGroupChange(Self);
end;

{ the rows in their frame, the groups' tabs below; in one batch }
procedure TSdWatchView.Resize;
var
  W, H, ListBottom: Integer;
begin
  W := ClientWidth;
  H := ClientHeight;
  if not HandleAllocated or (W <= 0) or (H <= 0) then Exit;
  ListBottom := Max(2, H - UIDockTabHeight);
  LayoutRows(Rect(0, 0, W, ListBottom), [FTabs], [Rect(0, ListBottom, W, H)]);
end;

function TSdWatchView.DebugText: string;
var
  I: Integer;
  N: TTreeNode;
  R: TRect;
begin
  Result := Format('%d|%d|', [Ord(ShowHeaders), ColumnWidth]);
  for I := 0 to FTabs.Tabs.Count - 1 do
  begin
    Result := Result + FTabs.Tabs[I];
    if I = FTabs.TabIndex then Result := Result + '*';
    Result := Result + ';';
  end;
  { the rows of the watches: their label's left (the check box is the 16 px before it) and their
    top and bottom in the tree, for posted clicks; + a selected one }
  Result := Result + '|';
  if not Tree.HandleAllocated then Exit;
  N := Tree.Items.GetFirstNode;
  while N <> nil do
  begin
    if TreeView_GetItemRect(Tree.Handle, N.ItemId, R, True) then
      Result := Result + Format('%s@%d,%d-%d%s;', [N.Text, R.Left, R.Top, R.Bottom, Copy('+', 1, Ord(N.Selected))]);
    N := N.GetNextSibling;
  end;
end;
end.
