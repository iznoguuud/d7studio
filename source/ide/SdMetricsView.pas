{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMetricsView;

{ D7 Studio - the Metrics view: the results of Project | Metrics (SdMetrics) - the project, its
  units, their classes and routines as a tree in the first column of a list (a row indented by
  its level, its state image the glyph that opens and closes it), a column per metric that is on. A value over its upper limit is red, under its lower one blue, the name of a row with
  such a value bold. A click on a column's header sorts by it (again: the other way); a row's
  glyph, Left / Right and + / - open and close it; a double click or Enter opens its code
  (OnOpen). Hints tell what a column counts and a value's limits. Run / Run on Unit ask the IDE
  to compute them (OnRun), Options opens their page of Environment Options (OnOptions), Export
  writes them as HTML or CSV, Copy a row's values. A form made once, docked by the IDE: its tool
  bar goes to its panel of the dock (TSdDockPanel.ToolBar), the dock's commands to the end of its
  menu (TMainForm.AddDockItems). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, CommCtrl, ToolWin,
  Menus, ActnList, Clipbrd, SdUI, SdIcons, SdMetrics;

type
  { UnitOnly: Run on Unit - the file shown, else the active project }
  TMetricRunEvent = procedure(Sender: TObject; UnitOnly: Boolean) of object;
  TMetricOpenEvent = procedure(Sender: TObject; const FileName: string; Line: Integer) of object;

  TMetricsView = class(TForm)
    Bar: TToolBar;
    tbRun: TToolButton;
    tbRunUnit: TToolButton;
    tbSep1: TToolButton;
    tbExpand: TToolButton;
    tbCollapse: TToolButton;
    tbOutside: TToolButton;
    tbSep2: TToolButton;
    tbExport: TToolButton;
    tbOptions: TToolButton;
    MetricList: TListView;
    Actions: TActionList;
    aMetRun: TAction;
    aMetRunUnit: TAction;
    aMetExpand: TAction;
    aMetCollapse: TAction;
    aMetOutside: TAction;
    aMetExport: TAction;
    aMetOptions: TAction;
    aMetGoto: TAction;
    aMetCopy: TAction;
    MetricsPopup: TPopupMenu;
    pmGoto: TMenuItem;
    pmCopy: TMenuItem;
    pmSep1: TMenuItem;
    pmRun: TMenuItem;
    pmRunUnit: TMenuItem;
    pmSep2: TMenuItem;
    pmExpand: TMenuItem;
    pmCollapse: TMenuItem;
    pmOutside: TMenuItem;
    pmSep3: TMenuItem;
    pmExport: TMenuItem;
    pmOptions: TMenuItem;
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure Command(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure MetricListCustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure MetricListColumnClick(Sender: TObject; Column: TListColumn);
    procedure MetricListCustomDrawSubItem(Sender: TCustomListView; Item: TListItem;
      SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure MetricListDblClick(Sender: TObject);
    procedure MetricListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MetricListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
  private
    FRoot: TMetricNode;
    FGlyphs: TImageList;               // the rows' state images: closed, open
    FSettings: TMetricSettings;
    FIds: TMetricIds;                  // the columns: the metrics that are on
    FCols: array of TMetricId;         // the metric of each column after the first
    FSortCol: Integer;                 // -1 none, 0 the names, else a metric's column
    FSortDesc: Boolean;
    FCanRun, FCanRunUnit: Boolean;
    FGlyphHit: Boolean;                // the last press was on a row's glyph (no double click then)
    FOnRun: TMetricRunEvent;
    FOnOpen: TMetricOpenEvent;
    FOnOptions, FOnMenuPopup: TNotifyEvent;
    function NodeAt(Item: TListItem): TMetricNode;
    function SelectedNode: TMetricNode;
    function Shown(N: TMetricNode): Boolean;
    procedure Fill;
    procedure MakeColumns;
    procedure ShowSortMark;
    procedure SetOpened(N: TMetricNode; Opened, Below: Boolean);
    procedure Toggle(N: TMetricNode);
    procedure UpdateCommands;
    procedure RunCommand(A: TAction);
    procedure ExportResults;
    function RowText(N: TMetricNode): string;
    { the hint of a point of the list (client coordinates): a column's header or a value; False none }
    function HintAt(P: TPoint; out Text: string; out Area: TRect): Boolean;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the results of a run (the view owns Root from now on; nil: none), with the settings they were
      computed with }
    procedure ShowResults(Root: TMetricNode; const Settings: TMetricSettings);
    procedure Clear;
    { the settings changed in Environment Options: the columns, the limits' colours (values of a metric that
      was off come with the next run) }
    procedure SettingsChanged(const Settings: TMetricSettings);
    { what the IDE allows now: a run on the project, on the file shown }
    procedure SetState(CanRun, CanRunUnit: Boolean);
    { the counts for the status line: units, classes, routines, values outside their limits }
    function Summary: string;
    { the rows shown for the test instance's state dump: each its name after a '>' per level, '='
      and its values, '!' after a value outside its limits, '*' when chosen, then ';' }
    function DebugText: string;
    property Root: TMetricNode read FRoot;
    property OnRun: TMetricRunEvent read FOnRun write FOnRun;
    property OnOpen: TMetricOpenEvent read FOnOpen write FOnOpen;
    property OnOptions: TNotifyEvent read FOnOptions write FOnOptions;
    { a menu opens (before the view's states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

uses
  SdFileNames;

{$R *.dfm}

const
  OpenedTag = 1;                       // TMetricNode.Tag: the row's children are shown
  UnderColor = TColor($00C06000);      // a value under its lower limit (over: UIErrorTabText)
  LevelIcons: array[TMetricLevel] of TSdIcon = (iiProcedure, iiClass, iiUnit, iiProject);

type
  { the list's hints - a column's header, a value of a row -, and its rows again when its window is made
    again: the VCL keeps the items over a new window (a view docked or floated) but not their indents }
  THintHook = class(TUIWindowHook)
  private
    FView: TMetricsView;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

var
  RefillMessage: UINT;

procedure THintHook.Hook(var Message: TMessage);
var
  Text: string;
  Area: TRect;
begin
  if Message.Msg = WM_CREATE then
  begin
    FOldProc(Message);
    { the items come back after the window is made: the rows again once they are there }
    PostMessage(FControl.Handle, RefillMessage, 0, 0);
    Exit;
  end;
  if (Message.Msg = RefillMessage) and (RefillMessage <> 0) then
  begin
    FView.Fill;
    Exit;
  end;
  if Message.Msg = CM_HINTSHOW then
    with TCMHintShow(Message).HintInfo^ do
    begin
      if FView.HintAt(CursorPos, Text, Area) then
      begin
        HintStr := Text;
        CursorRect := Area;
        Message.Result := 0;
      end
      else
        Message.Result := 1;
      Exit;
    end;
  FOldProc(Message);
end;

constructor TMetricsView.Create(AOwner: TComponent);

  procedure AddGlyph(Icon: TSdIcon);
  var
    H: HICON;
  begin
    H := ImageList_GetIcon(IconList.Handle, IconIndex(Icon), ILD_NORMAL);
    ImageList_AddIcon(FGlyphs.Handle, H);
    DestroyIcon(H);
  end;

begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Actions.Images := IconList;
  Bar.Images := IconList;
  MetricsPopup.Images := IconList;
  MetricList.SmallImages := IconList;
  { the glyphs of a row with children, closed and open: IconList's images, their alpha kept }
  FGlyphs := TImageList.Create(Self);
  FGlyphs.Handle := ImageList_Create(16, 16, ILC_COLOR32, 2, 0);
  AddGlyph(iiNodeCollapsed);
  AddGlyph(iiNodeExpanded);
  MetricList.StateImages := FGlyphs;
  UIOwnerDrawMenus(Self);
  THintHook.Create(MetricList, True).FView := Self;
  MetricList.ShowHint := True;
  MetricList.Hint := ' ';
  FSortCol := -1;
  FSettings := MetricDefaults;
  MakeColumns;
end;

destructor TMetricsView.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

{ No flicker: the list fills the view, which the dock resizes with it - the view paints nothing
  over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TMetricsView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the list covers the whole view: nothing of the form shows, nothing to erase }
procedure TMetricsView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

{ --- the rows --- }

function TMetricsView.NodeAt(Item: TListItem): TMetricNode;
begin
  if Item = nil then Result := nil else Result := TMetricNode(Item.Data);
end;

function TMetricsView.SelectedNode: TMetricNode;
begin
  Result := NodeAt(MetricList.Selected);
end;

{ a row is shown unless Only Outside Limits hides it: nothing outside its limits in it or below it }
function TMetricsView.Shown(N: TMetricNode): Boolean;
begin
  Result := not aMetOutside.Checked or (N.Level = mlProject) or TreeOutside(N, FSettings, FIds);
end;

procedure TMetricsView.MakeColumns;
var
  M: TMetricId;
  C: TListColumn;
begin
  FIds := [];
  SetLength(FCols, 0);
  for M := Low(TMetricId) to High(TMetricId) do
    if FSettings[M].On then
    begin
      Include(FIds, M);
      SetLength(FCols, Length(FCols) + 1);
      FCols[High(FCols)] := M;
    end;
  MetricList.Columns.BeginUpdate;
  try
    if MetricList.Columns.Count = 0 then
    begin
      C := MetricList.Columns.Add;
      C.Caption := 'Name';
      C.Width := 280;
    end;
    while MetricList.Columns.Count > Length(FCols) + 1 do
      MetricList.Columns.Delete(MetricList.Columns.Count - 1);
    while MetricList.Columns.Count < Length(FCols) + 1 do
    begin
      C := MetricList.Columns.Add;
      C.Alignment := taRightJustify;
    end;
  finally
    MetricList.Columns.EndUpdate;
  end;
end;

procedure TMetricsView.Fill;
var
  Keep: TMetricNode;
  Widths: array of Integer;
  DC: HDC;
  OldFont: HGDIOBJ;
  I: Integer;

  procedure AddRow(N: TMetricNode; Depth: Integer);
  var
    It: TListItem;
    K, W: Integer;
    S: string;
  begin
    if not Shown(N) then Exit;
    It := MetricList.Items.Add;
    It.Caption := N.Name;
    It.Data := N;
    It.ImageIndex := IconIndex(LevelIcons[N.Level]);
    It.Indent := Depth;
    if N.Count = 0 then It.StateIndex := -1
    else if N.Tag and OpenedTag <> 0 then It.StateIndex := 1
    else It.StateIndex := 0;
    for K := 0 to High(FCols) do
    begin
      if FCols[K] in N.Has then S := MetricValueText(FCols[K], N.Values[FCols[K]]) else S := '';
      It.SubItems.Add(S);
      W := UITextWidth(DC, S);
      if W > Widths[K] then Widths[K] := W;
    end;
    if N = Keep then UIChooseItem(It, False);
    if N.Tag and OpenedTag <> 0 then
      for K := 0 to N.Count - 1 do AddRow(N.Child(K), Depth + 1);
  end;

begin
  Keep := SelectedNode;
  SetLength(Widths, Length(FCols));
  DC := GetDC(0);
  OldFont := SelectObject(DC, MetricList.Font.Handle);
  try
    for I := 0 to High(FCols) do Widths[I] := UITextWidth(DC, MetricDefs[FCols[I]].Id);
    MetricList.Items.BeginUpdate;
    try
      MetricList.Items.Clear;
      if FRoot <> nil then AddRow(FRoot, 0);
    finally
      MetricList.Items.EndUpdate;
    end;
  finally
    SelectObject(DC, OldFont);
    ReleaseDC(0, DC);
  end;
  { the metrics' columns as wide as their widest text, the sort mark's room included }
  for I := 0 to High(FCols) do
  begin
    MetricList.Columns[I + 1].Caption := MetricDefs[FCols[I]].Id;
    MetricList.Columns[I + 1].Width := Widths[I] + 28;
  end;
  ShowSortMark;
  if MetricList.Selected <> nil then MetricList.Selected.MakeVisible(False);
end;

{ the header's arrow on the sorted column (Common Controls 6) }
procedure TMetricsView.ShowSortMark;
const
  HDF_SORTDOWN = $0200;
  HDF_SORTUP = $0400;
var
  H: HWND;
  I: Integer;
  Item: THDItem;
begin
  if not MetricList.HandleAllocated then Exit;
  H := ListView_GetHeader(MetricList.Handle);
  if H = 0 then Exit;
  for I := 0 to Header_GetItemCount(H) - 1 do
  begin
    FillChar(Item, SizeOf(Item), 0);
    Item.Mask := HDI_FORMAT;
    if not Header_GetItem(H, I, Item) then Continue;
    Item.fmt := Item.fmt and not (HDF_SORTUP or HDF_SORTDOWN);
    if I = FSortCol then
      if FSortDesc then Item.fmt := Item.fmt or HDF_SORTDOWN else Item.fmt := Item.fmt or HDF_SORTUP;
    Header_SetItem(H, I, Item);
  end;
end;

procedure TMetricsView.ShowResults(Root: TMetricNode; const Settings: TMetricSettings);
begin
  if Root <> FRoot then FRoot.Free;
  FRoot := Root;
  FSettings := Settings;
  MakeColumns;
  if FRoot <> nil then
  begin
    FRoot.Tag := OpenedTag;
    if FSortCol > 0 then
      if FSortCol <= Length(FCols) then SortMetricTree(FRoot, FCols[FSortCol - 1], False, FSortDesc)
      else FSortCol := -1
    else if FSortCol = 0 then SortMetricTree(FRoot, miLOC, True, FSortDesc);
  end;
  Fill;
end;

procedure TMetricsView.Clear;
begin
  ShowResults(nil, FSettings);
end;

procedure TMetricsView.SettingsChanged(const Settings: TMetricSettings);
begin
  ShowResults(FRoot, Settings);
end;

procedure TMetricsView.SetState(CanRun, CanRunUnit: Boolean);
begin
  FCanRun := CanRun;
  FCanRunUnit := CanRunUnit;
end;

function TMetricsView.Summary: string;
var
  Counts: array[TMetricLevel] of Integer;
  Outside: Integer;

  procedure Count(N: TMetricNode);
  var
    I: Integer;
  begin
    Inc(Counts[N.Level]);
    if NodeOutside(N, FSettings, FIds) and (N.Level in [mlRoutine, mlClass]) then Inc(Outside);
    for I := 0 to N.Count - 1 do Count(N.Child(I));
  end;

begin
  Result := '';
  if FRoot = nil then Exit;
  FillChar(Counts, SizeOf(Counts), 0);
  Outside := 0;
  Count(FRoot);
  Result := Format('%d units, %d classes, %d routines; %d outside their limits',
    [Counts[mlUnit], Counts[mlClass], Counts[mlRoutine], Outside]);
end;

function TMetricsView.DebugText: string;
var
  I, K: Integer;
  N: TMetricNode;
  S: string;
begin
  Result := '';
  for I := 0 to MetricList.Items.Count - 1 do
  begin
    N := NodeAt(MetricList.Items[I]);
    S := StringOfChar('>', MetricList.Items[I].Indent) + N.Name + '=';
    for K := 0 to High(FCols) do
    begin
      if K > 0 then S := S + ',';
      if FCols[K] in N.Has then
      begin
        S := S + MetricValueText(FCols[K], N.Values[FCols[K]]);
        if MetricCellOutside(N, FCols[K], FSettings) <> 0 then S := S + '!';
      end;
    end;
    if MetricList.Items[I].Selected then S := S + '*';
    Result := Result + S + ';';
  end;
end;

{ --- opening and closing rows --- }

procedure TMetricsView.SetOpened(N: TMetricNode; Opened, Below: Boolean);
var
  I: Integer;
begin
  if Opened then N.Tag := N.Tag or OpenedTag else N.Tag := N.Tag and not OpenedTag;
  if Below then
    for I := 0 to N.Count - 1 do SetOpened(N.Child(I), Opened, True);
end;

procedure TMetricsView.Toggle(N: TMetricNode);
begin
  if (N = nil) or (N.Count = 0) then Exit;
  SetOpened(N, N.Tag and OpenedTag = 0, False);
  Fill;
end;

{ the name bold when the row has a value outside its limits }
procedure TMetricsView.MetricListCustomDrawItem(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  N: TMetricNode;
begin
  DefaultDraw := True;
  N := NodeAt(Item);
  if (N <> nil) and NodeOutside(N, FSettings, FIds) then Sender.Canvas.Font.Style := [fsBold]
  else Sender.Canvas.Font.Style := [];
end;

{ a value outside its limits: red over the upper one, blue under the lower one, bold }
procedure TMetricsView.MetricListCustomDrawSubItem(Sender: TCustomListView; Item: TListItem;
  SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  N: TMetricNode;
  M: TMetricId;
begin
  DefaultDraw := True;
  N := NodeAt(Item);
  { as an RGB value: never equal to the canvas's own colour (a system colour), so that the list is told
    of it - a colour the canvas already had would leave the cell before's in the list's drawing }
  Sender.Canvas.Font.Style := [];
  Sender.Canvas.Font.Color := ColorToRGB(MetricList.Font.Color);
  if (N = nil) or (SubItem < 1) or (SubItem > Length(FCols)) then Exit;
  M := FCols[SubItem - 1];
  case MetricCellOutside(N, M, FSettings) of
    1:
      begin
        Sender.Canvas.Font.Color := UIErrorTabText;
        Sender.Canvas.Font.Style := [fsBold];
      end;
    -1:
      begin
        Sender.Canvas.Font.Color := UnderColor;
        Sender.Canvas.Font.Style := [fsBold];
      end;
  end;
end;

procedure TMetricsView.MetricListMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  It: TListItem;
begin
  FGlyphHit := False;
  if Button <> mbLeft then Exit;
  It := MetricList.GetItemAt(X, Y);
  if It = nil then Exit;
  if htOnStateIcon in MetricList.GetHitTestInfoAt(X, Y) then
  begin
    FGlyphHit := True;
    Toggle(NodeAt(It));
  end;
end;

procedure TMetricsView.MetricListDblClick(Sender: TObject);
begin
  if not FGlyphHit then RunCommand(aMetGoto);
  FGlyphHit := False;
end;

procedure TMetricsView.MetricListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  N: TMetricNode;
  I: Integer;
begin
  N := SelectedNode;
  case Key of
    VK_RETURN: RunCommand(aMetGoto);
    VK_RIGHT, VK_ADD:
      if (N <> nil) and (N.Count > 0) then
      begin
        if N.Tag and OpenedTag = 0 then Toggle(N)
        else if (Key = VK_RIGHT) and (MetricList.Selected.Index + 1 < MetricList.Items.Count) then
        begin
          UIChooseItem(MetricList.Items[MetricList.Selected.Index + 1]);
        end;
      end
      else if Key = VK_ADD then Key := 0;
    VK_LEFT, VK_SUBTRACT:
      if N <> nil then
        if (N.Count > 0) and (N.Tag and OpenedTag <> 0) then Toggle(N)
        else if (Key = VK_LEFT) and (N.Parent <> nil) then
          for I := 0 to MetricList.Items.Count - 1 do
            if NodeAt(MetricList.Items[I]) = N.Parent then
            begin
              UIChooseItem(MetricList.Items[I]);
              Break;
            end;
  else
    Exit;
  end;
  Key := 0;
end;

{ a column's header: the rows sorted by it, the names A to Z first, the values highest first; again
  the other way }
procedure TMetricsView.MetricListColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FRoot = nil then Exit;
  if Column.Index = FSortCol then FSortDesc := not FSortDesc
  else
  begin
    FSortCol := Column.Index;
    FSortDesc := Column.Index > 0;
  end;
  if FSortCol = 0 then SortMetricTree(FRoot, miLOC, True, FSortDesc)
  else SortMetricTree(FRoot, FCols[FSortCol - 1], False, FSortDesc);
  Fill;
end;

function TMetricsView.HintAt(P: TPoint; out Text: string; out Area: TRect): Boolean;
var
  H: HWND;
  HR: TRect;
  I, Col: Integer;
  Info: TLVHitTestInfo;
  N: TMetricNode;
  M: TMetricId;
  S: TMetricSetting;
begin
  Result := False;
  Text := '';
  if not MetricList.HandleAllocated then Exit;
  { a column's header: what it counts }
  H := ListView_GetHeader(MetricList.Handle);
  if (H <> 0) and IsWindowVisible(H) then
  begin
    GetWindowRect(H, HR);
    HR.TopLeft := MetricList.ScreenToClient(HR.TopLeft);
    HR.BottomRight := MetricList.ScreenToClient(HR.BottomRight);
    if PtInRect(HR, P) then
    begin
      for I := 1 to Header_GetItemCount(H) - 1 do
      begin
        Header_GetItemRect(H, I, @Area);
        OffsetRect(Area, HR.Left, HR.Top);
        if PtInRect(Area, P) and (I <= Length(FCols)) then
        begin
          M := FCols[I - 1];
          Text := MetricDefs[M].Name + #13#10 + MetricDefs[M].Hint;
          Result := True;
          Exit;
        end;
      end;
      Exit;
    end;
  end;
  { a value: the metric, its limits, how a value of a level above was made }
  FillChar(Info, SizeOf(Info), 0);
  Info.pt := P;
  if ListView_SubItemHitTest(MetricList.Handle, @Info) < 0 then Exit;
  Col := Info.iSubItem;
  if (Info.iItem < 0) or (Col < 1) or (Col > Length(FCols)) then Exit;
  N := NodeAt(MetricList.Items[Info.iItem]);
  M := FCols[Col - 1];
  if (N = nil) or not (M in N.Has) then Exit;
  S := FSettings[M];
  Text := MetricDefs[M].Name + ': ' + MetricValueText(M, N.Values[M]);
  if not (N.Level in MetricDefs[M].Levels) then
    Text := Text + ' (' + LowerCase(MetricAggrNames[S.Aggr]) + ' of the ' +
      LowerCase(MetricLevelNames[mlRoutine]) + 's, classes or units below)';
  if MetricCellOutside(N, M, FSettings) > 0 then Text := Text + #13#10 + 'Over the upper limit: ' + MetricValueText(M, S.Upper)
  else if MetricCellOutside(N, M, FSettings) < 0 then Text := Text + #13#10 + 'Under the lower limit: ' + MetricValueText(M, S.Lower);
  ListView_GetSubItemRect(MetricList.Handle, Info.iItem, Col, LVIR_BOUNDS, @Area);
  Result := True;
end;

{ --- the commands --- }

procedure TMetricsView.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
begin
  UpdateCommands;
  Handled := True;
end;

procedure TMetricsView.UpdateCommands;
var
  N: TMetricNode;
begin
  N := SelectedNode;
  aMetRun.Enabled := FCanRun;
  aMetRunUnit.Enabled := FCanRunUnit;
  aMetExpand.Enabled := FRoot <> nil;
  aMetCollapse.Enabled := FRoot <> nil;
  aMetExport.Enabled := FRoot <> nil;
  aMetGoto.Enabled := (N <> nil) and (N.FileName <> '') and (N.Line > 0);
  aMetCopy.Enabled := N <> nil;
end;

procedure TMetricsView.RunCommand(A: TAction);
begin
  UpdateCommands;
  if A.Enabled then A.Execute;
end;

procedure TMetricsView.MenuPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  UpdateCommands;
end;

function TMetricsView.RowText(N: TMetricNode): string;
var
  K: Integer;
begin
  Result := N.Name;
  for K := 0 to High(FCols) do
  begin
    Result := Result + #9 + MetricDefs[FCols[K]].Id + '=';
    if FCols[K] in N.Has then Result := Result + MetricValueText(FCols[K], N.Values[FCols[K]]);
  end;
end;

procedure TMetricsView.ExportResults;
var
  D: TSdFileDialog;
begin
  if FRoot = nil then Exit;
  D := TSdFileDialog.Create(Self);
  try
    D.Title := 'Export Metrics';
    D.Filter := 'HTML file (*.html)|*.html|CSV file (*.csv)|*.csv';
    D.DefaultExt := 'html';
    D.FileName := ChangeFileExt(FRoot.Name, '') + '-metrics.html';
    if not D.ExecuteSave then Exit;
    if SameText(ExtractFileExt(D.FileName), '.csv') then
      WriteFileU(D.FileName, MetricsCsv(FRoot, FIds))
    else
      WriteFileU(D.FileName, MetricsHtml(FRoot, FSettings, FIds, 'Metrics of ' + FRoot.Name));
  finally
    D.Free;
  end;
end;

procedure TMetricsView.Command(Sender: TObject);
begin
  if Sender = aMetRun then
  begin
    if Assigned(FOnRun) then FOnRun(Self, False);
  end
  else if Sender = aMetRunUnit then
  begin
    if Assigned(FOnRun) then FOnRun(Self, True);
  end
  else if (Sender = aMetExpand) or (Sender = aMetCollapse) then
  begin
    if FRoot = nil then Exit;
    SetOpened(FRoot, Sender = aMetExpand, True);
    FRoot.Tag := OpenedTag;
    Fill;
  end
  else if Sender = aMetOutside then
  begin
    aMetOutside.Checked := not aMetOutside.Checked;
    { what is outside the limits is shown opened }
    if aMetOutside.Checked and (FRoot <> nil) then SetOpened(FRoot, True, True);
    Fill;
  end
  else if Sender = aMetExport then
    ExportResults
  else if Sender = aMetOptions then
  begin
    if Assigned(FOnOptions) then FOnOptions(Self);
  end
  else if Sender = aMetGoto then
  begin
    if (SelectedNode <> nil) and Assigned(FOnOpen) then
      FOnOpen(Self, SelectedNode.FileName, SelectedNode.Line);
  end
  else if Sender = aMetCopy then
    if SelectedNode <> nil then Clipboard.AsText := RowText(SelectedNode);
end;

initialization
  RefillMessage := RegisterWindowMessage('D7Studio.MetricsRefill');
end.
