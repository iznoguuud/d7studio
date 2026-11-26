{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMessageView;

{ D7 Studio - the Messages view: the compiler's messages (Build, the
  list of the .dfm) and the message groups experts add through IOTAMessageServices, one list each,
  with Delphi 7's tabs below them - only when there is more than one group. The view holds the
  lists and the tabs; what a list shows and what its double click does are the main window's
  (Build) and the Open Tools services' (the experts' groups).

  As the IDE's other containers it never paints: the shown list and the tabs cover it (no erase,
  no CS_HREDRAW / CS_VREDRAW); a new list gets the lists' padding, horizontal
  tracking and buffer (UIReduceFlickerOf). }

interface

uses
  Classes, Controls, StdCtrls, SdUI, SdTabStrip;

type
  TSdMessageView = class(TSdControl)
  private
    FLists: TList;                   // the groups' lists, Build first
    FTabs: TSdTabStrip;
    FShown: Integer;                 // the group shown
    FOnGroupChange: TNotifyEvent;
    procedure TabsChange(Sender: TObject);
    procedure Arrange;
    function GetList(Index: Integer): TListBox;
    function MakeList(OnDblClick: TNotifyEvent): TListBox;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the .dfm's list becomes the first group, Build }
    procedure Attach(ABuild: TListBox);
    { a group's list, made like Build's (font, row height, double click); the index of the group }
    function AddGroup(const Name: string; OnDblClick: TNotifyEvent): Integer;
    procedure RemoveGroup(Index: Integer);
    function GroupCount: Integer;
    function GroupName(Index: Integer): string;
    procedure ShowGroup(Index: Integer);
    function ShownGroup: Integer;
    function ShownList: TListBox;
    function ListGroup(L: TListBox): Integer;       // the group whose list L is; -1 none
    { test mode: 'group*;group;...' - the groups, * the one shown }
    function DebugText: string;
    property Lists[Index: Integer]: TListBox read GetList;
    property OnGroupChange: TNotifyEvent read FOnGroupChange write FOnGroupChange;
  end;

implementation

const
  BuildGroup = 'Build';

constructor TSdMessageView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FLists := TList.Create;
  FTabs := TSdTabStrip.Create(Self);
  FTabs.Parent := Self;
  FTabs.Side := tsBottom;
  FTabs.Visible := False;
  FTabs.OnChange := TabsChange;
end;

destructor TSdMessageView.Destroy;
begin
  FLists.Free;
  inherited;
end;


function TSdMessageView.GetList(Index: Integer): TListBox;
begin
  if (Index >= 0) and (Index < FLists.Count) then Result := TListBox(FLists[Index]) else Result := nil;
end;

procedure TSdMessageView.Attach(ABuild: TListBox);
begin
  FLists.Clear;
  FLists.Add(ABuild);
  ABuild.Parent := Self;
  ABuild.Visible := True;            // the .dfm's views are hidden: the dock shows this view
  FTabs.Tabs.Clear;
  FTabs.Tabs.Add(BuildGroup);
  FShown := 0;
  Arrange;
end;

{ a group's list, made like Build's: its font, rows, colour, menu and keys - they act on the list
  shown (Enter: its double click) }
function TSdMessageView.MakeList(OnDblClick: TNotifyEvent): TListBox;
var
  B: TListBox;
begin
  B := Lists[0];
  Result := TListBox.Create(Self);
  Result.Parent := Self;
  Result.Visible := False;
  if B <> nil then
  begin
    Result.Font := B.Font;
    Result.ItemHeight := B.ItemHeight;
    Result.Color := B.Color;
    Result.PopupMenu := B.PopupMenu;
    Result.OnKeyDown := B.OnKeyDown;
  end;
  Result.OnDblClick := OnDblClick;
  UIReduceFlickerOf(Result);
end;

function TSdMessageView.AddGroup(const Name: string; OnDblClick: TNotifyEvent): Integer;
begin
  Result := FLists.Add(MakeList(OnDblClick));
  FTabs.Tabs.Add(Name);
  Arrange;
end;

procedure TSdMessageView.RemoveGroup(Index: Integer);
begin
  if (Index <= 0) or (Index >= FLists.Count) then Exit;     // Build stays
  if FShown = Index then
  begin
    FShown := 0;
    Arrange;                         // Build shown before the list goes: the keyboard moves to it
  end
  else if FShown > Index then Dec(FShown);
  TObject(FLists[Index]).Free;
  FLists.Delete(Index);
  FTabs.Tabs.Delete(Index);
  Arrange;
end;

function TSdMessageView.GroupCount: Integer;
begin
  Result := FLists.Count;
end;

function TSdMessageView.GroupName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FTabs.Tabs.Count) then Result := FTabs.Tabs[Index] else Result := '';
end;

procedure TSdMessageView.ShowGroup(Index: Integer);
begin
  if (Index < 0) or (Index >= FLists.Count) or (Index = FShown) then Exit;
  FShown := Index;
  Arrange;
  if Assigned(FOnGroupChange) then FOnGroupChange(Self);
end;

function TSdMessageView.ShownGroup: Integer;
begin
  Result := FShown;
end;

function TSdMessageView.ShownList: TListBox;
begin
  Result := Lists[FShown];
end;

function TSdMessageView.ListGroup(L: TListBox): Integer;
begin
  Result := FLists.IndexOf(L);
end;

procedure TSdMessageView.TabsChange(Sender: TObject);
begin
  ShowGroup(FTabs.TabIndex);
end;

procedure TSdMessageView.Resize;
begin
  inherited;
  Arrange;
end;

{ the shown group's list over the client, the tabs below it when there are groups to choose
  from; the shown list comes first, the hidden one goes after it (no ground between them) }
procedure TSdMessageView.Arrange;
var
  W, H, ListH, I: Integer;
  Tabs: Boolean;
  L: TListBox;

  procedure Hide(Other: TListBox);
  begin
    if (Other = nil) or (Other = L) then Exit;
    UIPassKeyboard(Other, L);           // a group's tab chosen: the keyboard stays in the view
    Other.Visible := False;
  end;

begin
  if FLists.Count = 0 then Exit;
  W := ClientWidth;
  H := ClientHeight;
  Tabs := FTabs.Tabs.Count > 1;
  if Tabs then ListH := H - UIDockTabHeight else ListH := H;
  if ListH < 2 then ListH := 2;
  if FTabs.TabIndex <> FShown then FTabs.TabIndex := FShown;
  L := ShownList;
  L.SetBounds(0, 0, W, ListH);
  L.Visible := True;
  for I := 0 to FLists.Count - 1 do Hide(Lists[I]);
  if Tabs then FTabs.SetBounds(0, ListH, W, H - ListH);
  FTabs.Visible := Tabs;
end;

function TSdMessageView.DebugText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FTabs.Tabs.Count - 1 do
  begin
    Result := Result + FTabs.Tabs[I];
    if I = FShown then Result := Result + '*';
    Result := Result + ';';
  end;
end;

end.
