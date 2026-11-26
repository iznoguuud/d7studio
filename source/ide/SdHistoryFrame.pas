{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdHistoryFrame;

{ D7 Studio - the History tab of a file's page: the versions D7 Studio keeps of the file (SdHistory)
  and what changed between them.

  * On the left the timeline, the newest first: Now - the text in the editor - and the versions by
    day, each with its time, what took it (saved, unsaved changes, closed without saving, changed
    outside D7 Studio, a label ...), the lines it added and removed against the version before it
    and the Pascal routines and types it changed. A unit with a form has a tab for each of its two
    files above it.
  * On the right the chosen version against the text now (HistoryComparePrevious: against the
    version before it; two versions chosen with Ctrl or Shift: against each other), line by line
    with the changed words marked (SdTextDiff), in the code editor's font, colours and zoom: inline
    - a change's removed lines above its added ones, both line numbers in the margin - or side by
    side (HistorySideBySide), the two sides' lines in line and scrolled together. Unchanged
    stretches are folded to the three lines around each change: a click on a fold shows its
    lines. Below it what is compared and how much changed.
  * On the page bar the routine filter - the timeline keeps the versions that changed the routine,
    the diff shows the routine alone - and the find box: the versions whose text holds it, its
    places marked in the diff.
  * Restore puts the version into the editor as one undo step (a unit with a form: the unit and its
    form as they were then); Restore Change the change at the caret alone, against the text now;
    Go to Code shows the line in the editor; a label names a version (or the text now) and keeps it
    for good.
  The page answers for its file through a THistoryHost (SdEditorPage). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  SdUI, SdSplitViewFrame, SdTabStrip, SdSciEdit, SdEncoding, SdTextDiff, SdHistory;

const
  CM_SD_HISTORYREFRESH = WM_APP + 130;   // the versions changed: read again once the change is over

type
  { what the view asks of its page about the unit's file, or its form file (Form) }
  THistoryHost = class
  public
    function FileName(Form: Boolean): string; virtual; abstract;
    function HasForm: Boolean; virtual; abstract;
    function CurrentText(Form: Boolean): string; virtual; abstract;        // the text now
    function CurrentBytes(Form: Boolean): string; virtual; abstract;       // ... as a save would write it
    function TextEncoding(Form: Boolean): TSdEncoding; virtual; abstract;  // the encoding of those texts
    function Modified(Form: Boolean): Boolean; virtual; abstract;
    function CanEdit(Form: Boolean): Boolean; virtual; abstract;
    { Text in place of the file's text, one undo step }
    procedure Restore(Form: Boolean; const Text: string); virtual; abstract;
    { the code shown at Line (0-based) }
    procedure GotoLine(Line: Integer); virtual; abstract;
  end;

  THistoryRowKind = (hrNow, hrDay, hrVersion);
  THistoryRow = record
    Kind: THistoryRowKind;
    Version: Integer;          // hrVersion: the version's index in the history
    Day: Integer;              // hrDay: the local date
  end;

  { a line of a diff window: unchanged, removed or added; on one side an empty line across from the
    other side's lines; unchanged lines folded away. Its line in the old and the new text (-1: none),
    its run of the diff }
  TDiffLineKind = (dlEqual, dlRemoved, dlAdded, dlFiller, dlFold);
  TDiffLine = record
    Kind: TDiffLineKind;
    OldLine, NewLine: Integer;
    Run: Integer;
    Folded: Integer;           // dlFold: the lines folded away
  end;
  TDiffLines = array of TDiffLine;

  TSdHistoryView = class(TSdSplitView)
    Timeline: TListBox;
    DiffHost: TPanel;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    FilterPanel: TPanel;
    RoutineBox: TComboBox;
    FindBox: TEdit;
    FindTimer: TTimer;
    procedure TimelineClick(Sender: TObject);
    procedure TimelineDblClick(Sender: TObject);
    procedure TimelineDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure TimelineKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimelineMeasureItem(Control: TWinControl; Index: Integer; var Height: Integer);
    procedure TimelineMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DiffHostResize(Sender: TObject);
    procedure FilterPanelResize(Sender: TObject);
    procedure RoutineBoxChange(Sender: TObject);
    procedure FindBoxChange(Sender: TObject);
    procedure FindBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FindTimerTimer(Sender: TObject);
  private
    FHost: THistoryHost;
    FFileTabs: TSdTabStrip;
    FForm: Boolean;                    // the form file's versions are shown
    FHistory: TFileHistory;
    FRows: array of THistoryRow;
    FNowBase: Integer;                 // the version the Now row compares with (-1: none)
    FNowAdded, FNowRemoved: Integer;   // ... its lines added and removed (-1: no version)
    FFrom, FTo: Integer;               // compared: versions; -1 the text now (FTo), -2 nothing (FFrom)
    FLeft, FRight: TSciWindow;
    FDivider: TPanel;
    FDiff: TLineDiff;
    FLinesL, FLinesR: TDiffLines;
    FExpanded: array of Boolean;       // per run of FDiff: its fold shown whole
    FTextKeys: TStringList;            // the versions' texts read: <id>|<encoding>|<form> ...
    FTextValues: array of string;      // ... and the texts
    FRoutine: string;                  // the routine filter ('' none)
    FShownChanges, FShownAdded, FShownRemoved: Integer;   // ... what the diff shows of the changes
    FFind: string;                     // the find box's text, as the timeline is filtered by it
    FSyncing: Boolean;
    FStale: Boolean;                   // the versions changed while the view was not shown
    FStatus: string;
    FShownOnce: Boolean;
    function VersionText(V: Integer): string;
    function TextOf(V: Integer): string;
    function VersionWanted(V: Integer): Boolean;
    function RowOfVersion(V: Integer): Integer;
    function VersionOfRow(R: Integer): Integer;
    function ChosenVersion: Integer;
    procedure DropHistory;
    function DayCaption(Day: Integer): string;
    function VersionCaption(V: Integer; Long: Boolean): string;
    function Described(V: Integer): string;
    procedure BuildRows;
    procedure FillRoutines;
    procedure UpdateFileTabs;
    procedure FileTabsChange(Sender: TObject);
    procedure ChooseCompared;
    procedure Compare(KeepPlace: Boolean);
    procedure Render;
    procedure LoadWindow(W: TSciWindow; Texts: TStringList; const Lines: TDiffLines; Count, Digits: Integer;
      Side: Integer);
    procedure ArrangeDiff;
    procedure ShowStatus;
    function NewDiffWindow: TSciWindow;
    function ActiveWindow: TSciWindow;
    function LinesOf(Ed: TSciEdit): TDiffLines;
    function CaretLine(out Lines: TDiffLines): Integer;
    procedure FocusDiff;
    procedure ChangeKey(var Key: Word; Shift: TShiftState);
    function ChangeTarget(Next: Boolean): Integer;
    procedure CaretTo(Line: Integer);
    procedure SetTopLine(Line: Integer);
    procedure DiffUpdateUI(Sender: TObject; Updated: Integer);
    procedure DiffMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DiffDblClick(Sender: TObject);
    procedure DiffKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DiffZoomed(Sender: TObject);
    procedure ExpandFold(Run: Integer);
    function ExpandFoldAt(const Lines: TDiffLines; L: Integer): Boolean;
    procedure MarkFind;
    function TopNewLine: Integer;
    procedure ScrollToNewLine(Line: Integer);
    procedure ShowFirstChange;
    procedure CMHistoryRefresh(var Message: TMessage); message CM_SD_HISTORYREFRESH;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the versions read again - the versions chosen and the place in the diff kept }
    procedure Refresh;
    { the versions of the file changed: read again now when the view is shown, else when it is }
    procedure HistoryChanged;
    { the view is shown (the History tab): read again what changed meanwhile }
    procedure Shown;
    { the editor's options changed: the diff windows take them }
    procedure OptionsChanged;
    { the routine filter (the code editor's History of Routine; '' every routine) }
    procedure ShowRoutine(const Name: string);
    { the versions of the unit's form file (Form), else of the unit - as its file tab chooses them }
    procedure ShowFile(Form: Boolean);
    { the switches of every view (HistorySideBySide ...) changed }
    procedure SwitchesChanged;
    { the find box's text S at once (not after the pause of typing) }
    procedure FindText(const S: string);
    { the strip on the page bar: the routine filter, the find box }
    function FilterBar: TWinControl;
    function DiffWindow: TSciWindow;              // the inline one, the left one side by side
    function SideWindow: TSciWindow;              // the right one side by side
    { the commands (the main form's actions) }
    function CanGotoChange(Next: Boolean): Boolean;
    procedure GotoChange(Next: Boolean);
    function CanRestore: Boolean;
    procedure Restore;
    function RestoreDescription: string;          // what Restore puts back (its confirmation)
    function CanRestoreChange: Boolean;
    procedure RestoreChange;
    function CanGotoCode: Boolean;
    procedure GotoCode;
    function CanCopy: Boolean;
    procedure CopySelection;
    { a label: on the version chosen, else the text now (False: nothing to label) }
    function CanLabel: Boolean;
    function LabelOfChoice: string;
    procedure LabelChoice(const Text: string);
    function CanRemoveLabel: Boolean;
    procedure RemoveLabel;
    { test mode: the rows (one of the timeline chosen or two together, as with Ctrl), the state,
      the timeline's rows and the diff's lines }
    procedure SelectRows(A, B: Integer);
    function StateText: string;
    procedure RowsText(L: TStrings);
    procedure DiffText(L: TStrings);
    property Host: THistoryHost read FHost write FHost;
    property FormShown: Boolean read FForm;
    property History: TFileHistory read FHistory;
  end;

var
  { the switches of every History tab (the main form's commands, kept in the settings): side by
    side, blanks ignored, a version against the one before it (else against the text now) }
  HistorySideBySide: Boolean = False;
  HistoryIgnoreBlanks: Boolean = False;
  HistoryComparePrevious: Boolean = False;

{ a version's routines without their classes (the timeline's second line) }
function ShortRoutines(const Routines: string): string;

implementation

{$R *.dfm}

uses
  Math, CommCtrl, SdSciDefs, SdZoom;

const
  Context = 3;                         // unchanged lines shown around a change
  DayNames: array[1..7] of string = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
  MonthNames: array[1..12] of string = ('January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December');
  RowText = DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX;     // a line of a timeline's row

function ShortRoutines(const Routines: string): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    SplitRoutines(Routines, L);
    for I := 0 to L.Count - 1 do L[I] := System.Copy(L[I], LastDelimiter('.', L[I]) + 1, MaxInt);
    Result := JoinRoutines(L);
  finally
    L.Free;
  end;
end;

{ N and the noun, its plural but for one: "1 change", "3 changes" }
function CountText(N: Integer; const Noun: string): string;
begin
  Result := IntToStr(N) + ' ' + Noun;
  if N <> 1 then Result := Result + 's';
end;

{ hh:mm of a local time }
function ClockText(T: TDateTime): string;
var
  H, M, S, MS: Word;
begin
  DecodeTime(T, H, M, S, MS);
  Result := Format('%.2d:%.2d', [H, M]);
end;

{ Name is one of a version's routines }
function HasRoutine(const Routines, Name: string): Boolean;
begin
  Result := Pos(RoutineSeparator + Name + RoutineSeparator, RoutineSeparator + Routines + RoutineSeparator) > 0;
end;

{ ---------------------------------------------------------------- TSdHistoryView }

constructor TSdHistoryView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Flat := True;
  Split := 280;
  FTextKeys := TStringList.Create;
  FFrom := -2;
  FTo := -1;
  FNowBase := -1;
  UIPrepareFrame(Self);
  UINoListTracking(Timeline);
  UINoListPadding(Timeline);
  UIRepaintOnWidth(Timeline);           // its counts at the right, its days' lines across
  UIPageStatus(StatusPanel);
  FLeft := NewDiffWindow;
  FRight := NewDiffWindow;
  FRight.Visible := False;
  FDivider := TPanel.Create(Self);
  FDivider.BevelOuter := bvNone;
  FDivider.Color := clBtnShadow;
  FDivider.Visible := False;
  FDivider.Parent := DiffHost;
  AddSide(Timeline, True);
  AddSide(DiffHost, False);
  RoutineBox.Items.Add('All routines');
  RoutineBox.ItemIndex := 0;
end;

destructor TSdHistoryView.Destroy;
begin
  DropHistory;
  FreeAndNil(FDiff);
  FTextKeys.Free;
  inherited Destroy;
end;

{ the versions let go, and the timeline's rows with them: the list draws a row whenever the
  keyboard leaves or comes back (the controls going, a message box closing) }
procedure TSdHistoryView.DropHistory;
begin
  SetLength(FRows, 0);
  FreeAndNil(FHistory);
end;

function TSdHistoryView.NewDiffWindow: TSciWindow;
begin
  Result := TSciWindow.Create(Self);
  Result.Borderless := True;
  Result.Parent := DiffHost;
  Result.Edit.DiffView := True;
  Result.Edit.OnZoom := DiffZoomed;
  Result.Edit.OnUpdateUI := DiffUpdateUI;
  Result.Edit.OnMouseUp := DiffMouseUp;
  Result.Edit.OnDblClick := DiffDblClick;
  Result.Edit.OnKeyDown := DiffKeyDown;
end;

function TSdHistoryView.FilterBar: TWinControl;
begin
  Result := FilterPanel;
end;

function TSdHistoryView.DiffWindow: TSciWindow;
begin
  Result := FLeft;
end;

function TSdHistoryView.SideWindow: TSciWindow;
begin
  Result := FRight;
end;

{ the window that has the keyboard, else the left one }
function TSdHistoryView.ActiveWindow: TSciWindow;
begin
  if HistorySideBySide and FRight.Edit.Focused then Result := FRight else Result := FLeft;
end;

{ the routine box, then the find box, which takes the rest }
procedure TSdHistoryView.FilterPanelResize(Sender: TObject);
var
  W, R: Integer;
  Cue: WideString;
begin
  W := FilterPanel.ClientWidth;
  R := Min(260, W * 45 div 100);
  RoutineBox.SetBounds(0, RoutineBox.Top, R, RoutineBox.Height);
  FindBox.SetBounds(R + 6, FindBox.Top, Max(W - R - 6, 0), FindBox.Height);
  if FindBox.HandleAllocated then
  begin
    Cue := 'Find in versions';
    SendMessage(FindBox.Handle, EM_SETCUEBANNER, 0, LPARAM(PWideChar(Cue)));
  end;
end;

{ inline: one window; side by side: two halves, a flat line between them; the status line below }
procedure TSdHistoryView.ArrangeDiff;
var
  W, H, Half: Integer;
begin
  { not while the frame's .dfm is read: the windows are made after it }
  if (FLeft = nil) or (FRight = nil) or (FDivider = nil) then Exit;
  W := DiffHost.ClientWidth;
  H := DiffHost.ClientHeight - StatusPanel.Height;
  if H < 0 then H := 0;
  if HistorySideBySide then
  begin
    Half := (W - 1) div 2;
    FDivider.Visible := True;
    FRight.Visible := True;
    if FLeft.HandleAllocated and FRight.HandleAllocated and FDivider.HandleAllocated then
      UIMoveControls([FLeft, FDivider, FRight], [Rect(0, 0, Half, H), Rect(Half, 0, Half + 1, H),
        Rect(Half + 1, 0, W, H)])
    else
    begin
      FLeft.SetBounds(0, 0, Half, H);
      FDivider.SetBounds(Half, 0, 1, H);
      FRight.SetBounds(Half + 1, 0, W - Half - 1, H);
    end;
  end
  else
  begin
    FLeft.SetBounds(0, 0, W, H);
    FRight.Visible := False;
    FDivider.Visible := False;
  end;
end;

procedure TSdHistoryView.DiffHostResize(Sender: TObject);
begin
  ArrangeDiff;
end;

{ --- the versions --- }

function TSdHistoryView.VersionText(V: Integer): string;
var
  Key: string;
  E: TSdEncoding;
  I: Integer;
begin
  E := FHost.TextEncoding(FForm);
  Key := IntToStr(FHistory[V].Id) + '|' + EncodingToSetting(E) + '|' + IntToStr(Ord(FForm));
  I := FTextKeys.IndexOf(Key);
  if I >= 0 then
  begin
    Result := FTextValues[I];
    Exit;
  end;
  try
    Result := FHistory.Text(V, E);
  except
    Result := '';
  end;
  SetLength(FTextValues, FTextKeys.Count + 1);
  FTextValues[FTextKeys.Count] := Result;
  FTextKeys.Add(Key);
end;

function TSdHistoryView.TextOf(V: Integer): string;
begin
  if V = -1 then Result := FHost.CurrentText(FForm)
  else if V < -1 then Result := ''
  else Result := VersionText(V);
end;

function TSdHistoryView.VersionWanted(V: Integer): Boolean;
begin
  Result := ((FRoutine = '') or HasRoutine(FHistory[V].Routines, FRoutine)) and
    ((FFind = '') or (Pos(LowerCase(FFind), LowerCase(VersionText(V))) > 0));
end;

function TSdHistoryView.RowOfVersion(V: Integer): Integer;
begin
  for Result := 0 to High(FRows) do
    if (FRows[Result].Kind = hrVersion) and (FRows[Result].Version = V) then Exit;
  Result := -1;
end;

{ a row's version: -1 the text now, -2 a day's row }
function TSdHistoryView.VersionOfRow(R: Integer): Integer;
begin
  case FRows[R].Kind of
    hrNow: Result := -1;
    hrVersion: Result := FRows[R].Version;
  else
    Result := -2;
  end;
end;

{ the version chosen alone in the timeline (-1: none - the text now, or more than one row) }
function TSdHistoryView.ChosenVersion: Integer;
var
  I: Integer;
begin
  Result := -1;
  I := Timeline.ItemIndex;
  if (FHistory <> nil) and (Timeline.SelCount = 1) and (I >= 0) and (I <= High(FRows)) and
    (FRows[I].Kind = hrVersion) then
    Result := FRows[I].Version;
end;

function TSdHistoryView.DayCaption(Day: Integer): string;
var
  Y, M, D, TY, TM, TD: Word;
  Today: Integer;
begin
  Today := Trunc(Now);
  if Day = Today then Result := 'Today'
  else if Day = Today - 1 then Result := 'Yesterday'
  else
  begin
    DecodeDate(Day, Y, M, D);
    DecodeDate(Today, TY, TM, TD);
    Result := Format('%s %d %s', [DayNames[DayOfWeek(Day)], D, MonthNames[M]]);
    if Y <> TY then Result := Result + ' ' + IntToStr(Y);
  end;
end;

{ what took a version - its label, the program that wrote the file -, Long: with its day }
function TSdHistoryView.VersionCaption(V: Integer; Long: Boolean): string;
var
  T: TDateTime;
begin
  with FHistory[V] do
    if LabelText <> '' then Result := '"' + LabelText + '"'
    else if (Kind = hkWritten) and (Writer <> '') then Result := Writer
    else Result := HistoryKindCaptions[Kind];
  if not Long then Exit;
  T := HistoryLocalTime(FHistory[V].Time);
  if Trunc(T) = Trunc(Now) then Result := Result + ' ' + ClockText(T)
  else Result := Result + ' ' + DayCaption(Trunc(T)) + ' ' + ClockText(T);
end;

{ a side of the comparison in the status line }
function TSdHistoryView.Described(V: Integer): string;
begin
  if V = -1 then Result := 'the text now'
  else if V < -1 then Result := 'nothing'
  else Result := VersionCaption(V, True);
end;

procedure TSdHistoryView.FillRoutines;
var
  Names, L: TStringList;
  I, K: Integer;
  Keep: string;
begin
  Keep := FRoutine;
  Names := TStringList.Create;
  L := TStringList.Create;
  try
    for I := FHistory.Count - 1 downto 0 do
    begin
      SplitRoutines(FHistory[I].Routines, L);
      for K := 0 to L.Count - 1 do
        if (L[K] <> '') and (Names.IndexOf(L[K]) < 0) then Names.Add(L[K]);
    end;
    if (Keep <> '') and (Names.IndexOf(Keep) < 0) then Names.Insert(0, Keep);
    RoutineBox.Items.BeginUpdate;
    try
      RoutineBox.Items.Clear;
      RoutineBox.Items.Add('All routines');
      RoutineBox.Items.AddStrings(Names);
    finally
      RoutineBox.Items.EndUpdate;
    end;
    if Keep = '' then RoutineBox.ItemIndex := 0 else RoutineBox.ItemIndex := RoutineBox.Items.IndexOf(Keep);
  finally
    L.Free;
    Names.Free;
  end;
end;

{ the timeline: Now, then the versions the filters keep, newest first, each day's under its day }
procedure TSdHistoryView.BuildRows;
var
  I, N, Day, LastDay: Integer;
begin
  SetLength(FRows, FHistory.Count * 2 + 1);
  FRows[0].Kind := hrNow;
  N := 1;
  LastDay := -1;
  for I := FHistory.Count - 1 downto 0 do
  begin
    if not VersionWanted(I) then Continue;
    Day := Trunc(HistoryLocalTime(FHistory[I].Time));
    if Day <> LastDay then
    begin
      FRows[N].Kind := hrDay;
      FRows[N].Day := Day;
      Inc(N);
      LastDay := Day;
    end;
    FRows[N].Kind := hrVersion;
    FRows[N].Version := I;
    Inc(N);
  end;
  SetLength(FRows, N);
  Timeline.Items.BeginUpdate;
  try
    Timeline.Items.Clear;
    for I := 0 to N - 1 do Timeline.Items.Add('');
  finally
    Timeline.Items.EndUpdate;
  end;
end;

{ a unit with a form: a tab for each file above the timeline }
procedure TSdHistoryView.UpdateFileTabs;
begin
  if FHost.HasForm then
  begin
    if FFileTabs = nil then
    begin
      FFileTabs := NewTabs([ExtractFileName(FHost.FileName(False)), ExtractFileName(FHost.FileName(True))], True);
      FFileTabs.OnChange := FileTabsChange;
    end
    else
    begin
      FFileTabs.Tabs[0] := ExtractFileName(FHost.FileName(False));
      FFileTabs.Tabs[1] := ExtractFileName(FHost.FileName(True));
    end;
    FFileTabs.TabIndex := Ord(FForm);
    FFileTabs.Visible := True;
  end
  else
  begin
    FForm := False;
    if FFileTabs <> nil then
    begin
      FFileTabs.Free;
      FFileTabs := nil;
    end;
  end;
  Arrange;
end;

procedure TSdHistoryView.FileTabsChange(Sender: TObject);
begin
  ShowFile(FFileTabs.TabIndex = 1);
end;

procedure TSdHistoryView.ShowFile(Form: Boolean);
begin
  if (Form = FForm) or Form and not FHost.HasForm then Exit;
  FForm := Form;
  if FFileTabs <> nil then FFileTabs.TabIndex := Ord(Form);
  DropHistory;
  FRoutine := '';
  Refresh;
end;

procedure TSdHistoryView.Refresh;
var
  Ids: TList;
  NowChosen: Boolean;
  I, V, Top: Integer;
  NowText: string;
  D: TLineDiff;
begin
  if FHost = nil then Exit;
  FStale := False;
  { the choice by the versions' ids: their indexes change when old ones go }
  Ids := TList.Create;
  try
    NowChosen := False;
    if FHistory <> nil then
      for I := 0 to Timeline.Items.Count - 1 do
        if Timeline.Selected[I] and (I <= High(FRows)) then
          if FRows[I].Kind = hrNow then NowChosen := True
          else if FRows[I].Kind = hrVersion then Ids.Add(Pointer(FHistory[FRows[I].Version].Id));
    Top := Timeline.TopIndex;
    DropHistory;
    UpdateFileTabs;
    FHistory := TFileHistory.Create(FHost.FileName(FForm));
    FillRoutines;
    { the Now row: against the newest version with another text - the unsaved changes, else what the
      last save changed }
    NowText := FHost.CurrentText(FForm);
    FNowBase := -1;
    FNowAdded := -1;
    FNowRemoved := -1;
    for V := FHistory.Count - 1 downto Max(FHistory.Count - 20, 0) do
      if VersionText(V) <> NowText then
      begin
        FNowBase := V;
        Break;
      end;
    if FNowBase >= 0 then
    begin
      D := TLineDiff.Create(VersionText(FNowBase), NowText);
      try
        FNowAdded := D.Added;
        FNowRemoved := D.Removed;
      finally
        D.Free;
      end;
    end;
    BuildRows;
    { the rows chosen before, else Now }
    for I := 0 to High(FRows) do
      if (FRows[I].Kind = hrNow) and NowChosen or
        (FRows[I].Kind = hrVersion) and (Ids.IndexOf(Pointer(FHistory[FRows[I].Version].Id)) >= 0) then
        Timeline.Selected[I] := True;
    if Timeline.SelCount = 0 then
    begin
      Timeline.Selected[0] := True;
      Top := 0;
    end;
    if Top < Timeline.Items.Count then Timeline.TopIndex := Top;
  finally
    Ids.Free;
  end;
  Compare(FShownOnce);
  FShownOnce := True;
end;

{ not at once: the change may come from inside the history of the view (SetLabel, Add) }
procedure TSdHistoryView.HistoryChanged;
begin
  FStale := True;
  if Showing and HandleAllocated then PostMessage(Handle, CM_SD_HISTORYREFRESH, 0, 0);
end;

procedure TSdHistoryView.CMHistoryRefresh(var Message: TMessage);
begin
  if FStale and Showing then Refresh;
end;

procedure TSdHistoryView.Shown;
begin
  if FStale or (FHistory = nil) then Refresh
  else Compare(True);                  // the text now may have changed
end;

procedure TSdHistoryView.OptionsChanged;
begin
  FLeft.Edit.ApplyOptions;
  FRight.Edit.ApplyOptions;
end;

procedure TSdHistoryView.SwitchesChanged;
begin
  ArrangeDiff;
  if FHistory <> nil then
  begin
    ChooseCompared;
    Compare(True);
  end;
end;

procedure TSdHistoryView.ShowRoutine(const Name: string);
begin
  FRoutine := Name;
  if FHistory = nil then Refresh
  else
  begin
    FillRoutines;
    BuildRows;
    Timeline.Selected[0] := True;
    Compare(False);
  end;
end;

procedure TSdHistoryView.RoutineBoxChange(Sender: TObject);
begin
  if RoutineBox.ItemIndex <= 0 then FRoutine := '' else FRoutine := RoutineBox.Items[RoutineBox.ItemIndex];
  ShowRoutine(FRoutine);
end;

procedure TSdHistoryView.FindBoxChange(Sender: TObject);
begin
  FindTimer.Enabled := False;
  FindTimer.Enabled := True;
end;

procedure TSdHistoryView.FindBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
      begin
        Key := 0;
        FindTimerTimer(nil);
        FocusDiff;
      end;
    VK_ESCAPE:
      if FindBox.Text <> '' then
      begin
        Key := 0;
        FindText('');
      end;
  end;
end;

procedure TSdHistoryView.FindText(const S: string);
begin
  FindBox.Text := S;
  FindTimerTimer(nil);
end;

{ the timeline keeps the versions that hold the text, the diff marks it }
procedure TSdHistoryView.FindTimerTimer(Sender: TObject);
var
  V: Integer;
begin
  FindTimer.Enabled := False;
  if (FHistory = nil) or (FindBox.Text = FFind) then
  begin
    MarkFind;
    Exit;
  end;
  FFind := FindBox.Text;
  if Timeline.SelCount > 0 then V := VersionOfRow(Timeline.ItemIndex) else V := -1;
  BuildRows;
  if (V >= 0) and (RowOfVersion(V) >= 0) then Timeline.Selected[RowOfVersion(V)] := True
  else if (FFind <> '') and (Length(FRows) > 1) then Timeline.Selected[1 + Ord(FRows[1].Kind = hrDay)] := True
  else Timeline.Selected[0] := True;
  Compare(False);
end;

{ --- the comparison --- }

procedure TSdHistoryView.ChooseCompared;
var
  I, First, Last, V: Integer;
begin
  First := -1;
  Last := -1;
  for I := 0 to Timeline.Items.Count - 1 do
    if Timeline.Selected[I] and (I <= High(FRows)) and (FRows[I].Kind <> hrDay) then
    begin
      if First < 0 then First := I;
      Last := I;
    end;
  if (First < 0) or (FRows[First].Kind = hrNow) and (First = Last) then
  begin
    { Now: against the newest version with another text }
    if FNowBase >= 0 then FFrom := FNowBase
    else if FHistory.Count > 0 then FFrom := FHistory.Count - 1
    else FFrom := -1;
    FTo := -1;
  end
  else if First = Last then
  begin
    V := FRows[First].Version;
    { under a routine filter a version's row says it changed the routine: what it did there }
    if HistoryComparePrevious or (FRoutine <> '') then
    begin
      FTo := V;
      if V > 0 then FFrom := V - 1 else FFrom := -2;
    end
    else
    begin
      FFrom := V;
      FTo := -1;
    end;
  end
  else
  begin
    { two or more: the oldest against the newest of them (the rows go newest first) }
    FTo := VersionOfRow(First);
    FFrom := VersionOfRow(Last);
  end;
end;

{ the first new-text line in view (-1: none) }
function TSdHistoryView.TopNewLine: Integer;
var
  I: Integer;
begin
  Result := -1;
  I := FLeft.Edit.Sci(SCI_GETFIRSTVISIBLELINE);
  while (I >= 0) and (I <= High(FLinesL)) do
  begin
    if FLinesL[I].NewLine >= 0 then
    begin
      Result := FLinesL[I].NewLine;
      Exit;
    end;
    Inc(I);
  end;
end;

procedure TSdHistoryView.ScrollToNewLine(Line: Integer);
var
  I: Integer;
begin
  for I := 0 to High(FLinesL) do
    if FLinesL[I].NewLine >= Line then
    begin
      SetTopLine(I);
      Exit;
    end;
end;

{ line Line of the diff at the top of its windows (side by side: the two in line) }
procedure TSdHistoryView.SetTopLine(Line: Integer);
begin
  FLeft.Edit.Sci(SCI_SETFIRSTVISIBLELINE, Line);
  if HistorySideBySide then FRight.Edit.Sci(SCI_SETFIRSTVISIBLELINE, Line);
end;

{ the caret on line Line of the diff, in view (side by side: in both windows) }
procedure TSdHistoryView.CaretTo(Line: Integer);
begin
  FLeft.Edit.GotoLineCol(Line, 0, True);
  if HistorySideBySide then FRight.Edit.GotoLineCol(Line, 0, True);
end;

{ the versions chosen compared and shown; KeepPlace: the same lines of the text stay in view, else
  the first change comes up }
procedure TSdHistoryView.Compare(KeepPlace: Boolean);
var
  Place: Integer;
begin
  if FHistory = nil then Exit;
  Place := -1;
  if KeepPlace and (FDiff <> nil) then Place := TopNewLine;
  ChooseCompared;
  FreeAndNil(FDiff);
  FDiff := TLineDiff.Create(TextOf(FFrom), TextOf(FTo), HistoryIgnoreBlanks);
  SetLength(FExpanded, 0);
  SetLength(FExpanded, FDiff.RunCount);
  Render;
  if Place >= 0 then ScrollToNewLine(Place) else ShowFirstChange;
  MarkFind;
  ShowStatus;
end;

{ the caret on the first change, else on the first line }
procedure TSdHistoryView.ShowFirstChange;
begin
  CaretTo(Max(FLeft.Edit.MarkerNext(0, 1 shl MK_DIFF_CHANGE), 0));
end;

procedure TSdHistoryView.ShowStatus;
var
  S: string;
begin
  if FDiff = nil then Exit;
  if (FHistory.Count = 0) then
    S := 'No versions yet: D7 Studio keeps one at every save of the file.'
  else
  begin
    S := Described(FFrom) + ' -> ' + Described(FTo);
    if FRoutine <> '' then S := S + ' (' + FRoutine + ')';
    if FShownChanges = 0 then S := S + ': no differences'
    else S := S + Format(': %s, +%d -%d', [CountText(FShownChanges, 'change'), FShownAdded, FShownRemoved]);
    if HistoryIgnoreBlanks then S := S + ', blanks ignored';
  end;
  FStatus := S;
  StatusLabel.Caption := S;
  StatusLabel.Hint := S;
end;

{ the lines of the diff windows from FDiff: unchanged runs folded (but for a run shown whole, and
  under a routine filter: the routine's lines alone), a change's removed lines above its added ones -
  side by side across from each other, the shorter side filled }
procedure TSdHistoryView.Render;
type
  TPendingWord = record
    Right: Boolean;                    // in the right window, else the left
    Line, Start, Len, Ind: Integer;
  end;
var
  TL, TR: TStringList;
  NL, NR, R, CurRun, K, N, Head, Tail, Digits, I: Integer;
  D: TDiffRun;
  Side: TDiffSide;
  Has: array[TDiffSide] of Boolean;   // the routine of the filter is in the side's text ...
  Span: array[TDiffSide] of TCodeSpan;   // ... on these lines
  Filtered, Fold: Boolean;
  Doc: array[TDiffSide] of TIntArray; // a change's lines: their line in a window (-1: not shown)
  Words: array of TPendingWord;
  NW: Integer;
  SA, SB: TDiffSpans;
  Ed: TSciEdit;

  procedure Put(var Lines: TDiffLines; var Count: Integer; Texts: TStringList; Kind: TDiffLineKind;
    OldLine, NewLine, Folded: Integer; const Text: string);
  begin
    if Count = Length(Lines) then SetLength(Lines, Count * 2 + 64);
    Lines[Count].Kind := Kind;
    Lines[Count].OldLine := OldLine;
    Lines[Count].NewLine := NewLine;
    Lines[Count].Run := CurRun;
    Lines[Count].Folded := Folded;
    Texts.Add(Text);
    Inc(Count);
  end;

  procedure AddLine(Right: Boolean; Kind: TDiffLineKind; OldLine, NewLine: Integer; const Text: string;
    Folded: Integer = 0);
  begin
    if Right then Put(FLinesR, NR, TR, Kind, OldLine, NewLine, Folded, Text)
    else Put(FLinesL, NL, TL, Kind, OldLine, NewLine, Folded, Text);
  end;

  procedure AddEqual(K: Integer);
  begin
    if HistorySideBySide then
    begin
      AddLine(False, dlEqual, D.A + K, D.B + K, FDiff.OldLines.Line(D.A + K));
      AddLine(True, dlEqual, D.A + K, D.B + K, FDiff.NewLines.Line(D.B + K));
    end
    else
      AddLine(False, dlEqual, D.A + K, D.B + K, FDiff.NewLines.Line(D.B + K));
  end;

  procedure AddFold(Count: Integer);
  begin
    AddLine(False, dlFold, -1, -1, '', Count);
    if HistorySideBySide then AddLine(True, dlFold, -1, -1, '', Count);
  end;

  procedure AddWord(Right: Boolean; Line, Start, Len, Ind: Integer);
  begin
    if NW = Length(Words) then SetLength(Words, NW * 2 + 32);
    Words[NW].Right := Right;
    Words[NW].Line := Line;
    Words[NW].Start := Start;
    Words[NW].Len := Len;
    Words[NW].Ind := Ind;
    Inc(NW);
  end;

  { the span of the filter's routine in Text }
  function FindSpan(const Text: string; out S: TCodeSpan): Boolean;
  var
    Spans: TCodeSpans;
    J: Integer;
  begin
    Result := False;
    Spans := CodeSpans(Text);
    for J := 0 to High(Spans) do
      if Spans[J].Name = FRoutine then
      begin
        S := Spans[J];
        Result := True;
        Exit;
      end;
  end;

  { line Line of Side's text lies in the filter's routine }
  function InRoutine(Side: TDiffSide; Line: Integer): Boolean;
  begin
    Result := Has[Side] and SpanHolds(Span[Side], Line);
  end;

  { line K of the change's Side does }
  function InChange(Side: TDiffSide; K: Integer): Boolean;
  begin
    Result := (K < RunLength(D, Side)) and InRoutine(Side, RunStart(D, Side) + K);
  end;

  function EqualWanted(K: Integer): Boolean;
  begin
    if Has[dsNew] then Result := InRoutine(dsNew, D.B + K)
    else Result := InRoutine(dsOld, D.A + K);
  end;

  { line K of the change's Side - removed (the old text) or added (the new) - into the right window
    or the left one, its line there kept for the changed words }
  procedure AddChanged(Side: TDiffSide; K: Integer; Right: Boolean);
  var
    Line: Integer;
  begin
    Line := RunStart(D, Side) + K;
    if Right then Doc[Side][K] := NR else Doc[Side][K] := NL;
    if Side = dsOld then AddLine(Right, dlRemoved, Line, -1, FDiff.OldLines.Line(Line))
    else AddLine(Right, dlAdded, -1, Line, FDiff.NewLines.Line(Line));
  end;

  { the lines of the change's Side shown }
  function Shown(Side: TDiffSide): Integer;
  var
    J: Integer;
  begin
    Result := 0;
    for J := 0 to High(Doc[Side]) do
      if Doc[Side][J] >= 0 then Inc(Result);
  end;

begin
  TL := TStringList.Create;
  TR := TStringList.Create;
  try
    NL := 0;
    NR := 0;
    NW := 0;
    SetLength(FLinesL, 0);
    SetLength(FLinesR, 0);
    for Side := dsOld to dsNew do
      Has[Side] := (FRoutine <> '') and FindSpan(FDiff.Lines(Side).Text, Span[Side]);
    Filtered := Has[dsOld] or Has[dsNew];
    { folding only where there are changes to show around }
    Fold := (FDiff.Changes > 0) and not Filtered;
    FShownChanges := 0;
    FShownAdded := 0;
    FShownRemoved := 0;
    for R := 0 to FDiff.RunCount - 1 do
    begin
      CurRun := R;
      D := FDiff[R];
      if D.Kind = dkEqual then
      begin
        N := D.LenA;
        if Filtered then
        begin
          for K := 0 to N - 1 do
            if EqualWanted(K) then AddEqual(K);
          Continue;
        end;
        if R > 0 then Head := Context else Head := 0;
        if R < FDiff.RunCount - 1 then Tail := Context else Tail := 0;
        if Fold and not FExpanded[R] and (N > Head + Tail + 1) then
        begin
          for K := 0 to Head - 1 do AddEqual(K);
          AddFold(N - Head - Tail);
          for K := N - Tail to N - 1 do AddEqual(K);
        end
        else
          for K := 0 to N - 1 do AddEqual(K);
        Continue;
      end;
      { a change: its lines - side by side across from each other, the shorter side filled -, and the
        pairs of a removed and an added line for the words }
      for Side := dsOld to dsNew do
      begin
        SetLength(Doc[Side], RunLength(D, Side));
        for K := 0 to High(Doc[Side]) do Doc[Side][K] := -1;
      end;
      if HistorySideBySide then
        for K := 0 to Max(D.LenA, D.LenB) - 1 do
        begin
          if Filtered and not InChange(dsOld, K) and not InChange(dsNew, K) then Continue;
          if K < D.LenA then AddChanged(dsOld, K, False) else AddLine(False, dlFiller, -1, -1, '');
          if K < D.LenB then AddChanged(dsNew, K, True) else AddLine(True, dlFiller, -1, -1, '');
        end
      else
        for Side := dsOld to dsNew do
          for K := 0 to RunLength(D, Side) - 1 do
            if not Filtered or InChange(Side, K) then AddChanged(Side, K, False);
      { what is shown of the change counts }
      Inc(FShownRemoved, Shown(dsOld));
      Inc(FShownAdded, Shown(dsNew));
      if Shown(dsOld) + Shown(dsNew) > 0 then Inc(FShownChanges);
      for K := 0 to Min(D.LenA, D.LenB) - 1 do
        if (Doc[dsOld][K] >= 0) and (Doc[dsNew][K] >= 0) and
          WordDiff(FDiff.OldLines.Line(D.A + K), FDiff.NewLines.Line(D.B + K), SA, SB) then
        begin
          for I := 0 to High(SA) do AddWord(False, Doc[dsOld][K], SA[I].Start, SA[I].Len, IND_DIFF_REMOVED);
          for I := 0 to High(SB) do AddWord(HistorySideBySide, Doc[dsNew][K], SB[I].Start, SB[I].Len, IND_DIFF_ADDED);
        end;
    end;
    SetLength(FLinesL, NL);
    SetLength(FLinesR, NR);
    Digits := Max(Length(IntToStr(Max(FDiff.OldLines.Count, FDiff.NewLines.Count))), 3);
    if HistorySideBySide then
    begin
      LoadWindow(FLeft, TL, FLinesL, NL, Digits, 1);
      LoadWindow(FRight, TR, FLinesR, NR, Digits, 2);
    end
    else
      LoadWindow(FLeft, TL, FLinesL, NL, Digits, 0);
    for I := 0 to NW - 1 do
    begin
      if Words[I].Right then Ed := FRight.Edit else Ed := FLeft.Edit;
      Ed.FillIndicator(Words[I].Ind, Ed.PosFromLine(Words[I].Line) + Words[I].Start, Words[I].Len);
    end;
  finally
    TL.Free;
    TR.Free;
  end;
end;

{ a window's text, its lines' grounds, margins and notes; Side: 0 inline (both numbers), 1 the old
  side, 2 the new side }
procedure TSdHistoryView.LoadWindow(W: TSciWindow; Texts: TStringList; const Lines: TDiffLines;
  Count, Digits, Side: Integer);
var
  Ed: TSciEdit;
  S, M, St, OldNo, NewNo, Sign: string;
  I, NumStyle, SignStyle, LastRun: Integer;

  function Num(N: Integer): string;
  begin
    if N >= 0 then Result := IntToStr(N + 1) else Result := '';
    Result := StringOfChar(' ', Digits - Length(Result)) + Result;
  end;

begin
  Ed := W.Edit;
  S := Texts.Text;
  if S <> '' then SetLength(S, Length(S) - 2);
  Ed.SetLanguageFromFile(FHost.FileName(FForm));
  Ed.LoadFromStringAs(S, FHost.TextEncoding(FForm));
  Ed.ReadOnly := True;
  if Side = 0 then Ed.DiffMarginChars := 2 * Digits + 3 else Ed.DiffMarginChars := Digits + 2;
  LastRun := -1;
  for I := 0 to Count - 1 do
  begin
    OldNo := Num(Lines[I].OldLine);
    NewNo := Num(Lines[I].NewLine);
    Sign := ' ';
    NumStyle := STYLE_DIFF_NUMBERS;
    SignStyle := STYLE_DIFF_NUMBERS;
    case Lines[I].Kind of
      dlRemoved:
        begin
          Ed.MarkerAdd(I, MK_DIFF_REMOVED);
          Sign := '-';
          NumStyle := STYLE_DIFF_REMOVED;
          SignStyle := STYLE_DIFF_REMOVED_SIGN;
        end;
      dlAdded:
        begin
          Ed.MarkerAdd(I, MK_DIFF_ADDED);
          Sign := '+';
          NumStyle := STYLE_DIFF_ADDED;
          SignStyle := STYLE_DIFF_ADDED_SIGN;
        end;
      dlFiller:
        Ed.MarkerAdd(I, MK_DIFF_FILLER);
      dlFold:
        begin
          Ed.MarkerAdd(I, MK_DIFF_FOLD);
          Ed.SetDiffNote(I, '  ... ' + CountText(Lines[I].Folded, 'unchanged line'));
        end;
    end;
    if (Lines[I].Kind in [dlRemoved, dlAdded, dlFiller]) and (Lines[I].Run <> LastRun) then
      Ed.MarkerAdd(I, MK_DIFF_CHANGE);
    if Lines[I].Kind in [dlRemoved, dlAdded, dlFiller] then LastRun := Lines[I].Run else LastRun := -1;
    case Side of
      0: M := OldNo + ' ' + NewNo + ' ' + Sign;
      1: M := OldNo + ' ' + Sign;
    else
      M := NewNo + ' ' + Sign;
    end;
    St := StringOfChar(Chr(NumStyle), Length(M) - 1) + Chr(SignStyle);
    Ed.SetDiffMargin(I, M, St);
  end;
end;

{ --- the diff windows --- }

{ side by side, the other side scrolls with the one that scrolled }
procedure TSdHistoryView.DiffUpdateUI(Sender: TObject; Updated: Integer);
var
  A, B: TSciEdit;
begin
  if FSyncing or not HistorySideBySide or (Updated and (SC_UPDATE_V_SCROLL or SC_UPDATE_H_SCROLL) = 0) then Exit;
  A := TSciEdit(Sender);
  if A = FLeft.Edit then B := FRight.Edit else B := FLeft.Edit;
  FSyncing := True;
  try
    if B.Sci(SCI_GETFIRSTVISIBLELINE) <> A.Sci(SCI_GETFIRSTVISIBLELINE) then
      B.Sci(SCI_SETFIRSTVISIBLELINE, A.Sci(SCI_GETFIRSTVISIBLELINE));
    if B.Sci(SCI_GETXOFFSET) <> A.Sci(SCI_GETXOFFSET) then B.Sci(SCI_SETXOFFSET, A.Sci(SCI_GETXOFFSET));
  finally
    FSyncing := False;
  end;
end;

{ the lines of a diff window }
function TSdHistoryView.LinesOf(Ed: TSciEdit): TDiffLines;
begin
  if Ed = FRight.Edit then Result := FLinesR else Result := FLinesL;
end;

{ the lines of the window with the keyboard, and its caret's line }
function TSdHistoryView.CaretLine(out Lines: TDiffLines): Integer;
var
  Ed: TSciEdit;
begin
  Ed := ActiveWindow.Edit;
  Lines := LinesOf(Ed);
  Result := Ed.CaretLine;
end;

procedure TSdHistoryView.FocusDiff;
begin
  if FLeft.Edit.CanFocus then FLeft.Edit.SetFocus;
end;

{ Alt+Up / Alt+Down in the timeline or the diff: the previous / next change }
procedure TSdHistoryView.ChangeKey(var Key: Word; Shift: TShiftState);
begin
  if not (Key in [VK_UP, VK_DOWN]) or (Shift <> [ssAlt]) then Exit;
  GotoChange(Key = VK_DOWN);
  Key := 0;
end;

procedure TSdHistoryView.ExpandFold(Run: Integer);
var
  Place: Integer;
begin
  if (Run < 0) or (Run > High(FExpanded)) then Exit;
  Place := FLeft.Edit.Sci(SCI_GETFIRSTVISIBLELINE);
  FExpanded[Run] := True;
  Render;
  SetTopLine(Place);
  MarkFind;
end;

{ line L of Lines is a fold: its lines shown (False: no fold there) }
function TSdHistoryView.ExpandFoldAt(const Lines: TDiffLines; L: Integer): Boolean;
begin
  Result := (L >= 0) and (L <= High(Lines)) and (Lines[L].Kind = dlFold);
  if Result then ExpandFold(Lines[L].Run);
end;

{ a click on a fold shows its lines }
procedure TSdHistoryView.DiffMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Ed: TSciEdit;
begin
  if Button <> mbLeft then Exit;
  Ed := TSciEdit(Sender);
  ExpandFoldAt(LinesOf(Ed), Ed.Sci(SCI_LINEFROMPOSITION, Ed.Sci(SCI_POSITIONFROMPOINT, X, Y)));
end;

procedure TSdHistoryView.DiffDblClick(Sender: TObject);
begin
  if CanGotoCode then GotoCode;
end;

{ Enter: a fold shown, else the line in the editor }
procedure TSdHistoryView.DiffKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  L: Integer;
  Lines: TDiffLines;
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    L := CaretLine(Lines);
    if not ExpandFoldAt(Lines, L) and CanGotoCode then GotoCode;
    Key := 0;
  end
  else
    ChangeKey(Key, Shift);
end;

{ Ctrl+wheel in a diff window: every editor takes the zoom }
procedure TSdHistoryView.DiffZoomed(Sender: TObject);
begin
  if Assigned(OnEditorZoom) then OnEditorZoom(Self);
end;

{ the find box's text marked in the diff }
procedure TSdHistoryView.MarkFind;
begin
  FLeft.Edit.MarkMatches(FFind, False, False, False);
  if HistorySideBySide then FRight.Edit.MarkMatches(FFind, False, False, False);
end;

{ --- the timeline --- }

procedure TSdHistoryView.TimelineMeasureItem(Control: TWinControl; Index: Integer; var Height: Integer);
begin
  if (Index <= High(FRows)) and (FRows[Index].Kind = hrDay) then Height := UITextHeight + 10
  else Height := 2 * UITextHeight + 10;
end;

function KindColor(K: THistoryKind): TColor;
begin
  case K of
    hkSaved, hkWritten: Result := UIBlend(clGreen, clWindow, 85);
    hkUnsaved: Result := UIBlend($0000A0F0, clWindow, 90);
    hkClosed, hkReloaded: Result := UIBlend(clRed, clWindow, 80);
    hkOutside: Result := UIBlend(clBlue, clWindow, 70);
    hkLabel: Result := clHighlight;
  else
    Result := clGrayText;
  end;
end;

procedure TSdHistoryView.TimelineDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  DC: HDC;
  Back, Fore, Dim, Dot, PlusC, MinusC: TColor;
  R, T: TRect;
  Line1, Line2, Counts, Plus, Minus: string;
  H, X, Y, CW, Added, Removed: Integer;
  V: THistoryVersion;
  Sel, Labelled: Boolean;
  Pts: array[0..3] of TPoint;
  OldFont: HFONT;
  Bold: TFont;
begin
  if Index > High(FRows) then Exit;
  C := Timeline.Canvas;
  C.Font := Timeline.Font;
  DC := C.Handle;
  H := UITextHeight;
  if FRows[Index].Kind = hrDay then
  begin
    UIFill(DC, Rect, clWindow);
    T := Classes.Rect(Rect.Left + 8, Rect.Top + 4, Rect.Right - 4, Rect.Bottom);
    UIText(DC, DayCaption(FRows[Index].Day), T, RowText, clGrayText);
    UIHLine(DC, Rect.Left + 8, Rect.Right - 4, Rect.Bottom - 2, UIBlend(clGrayText, clWindow, 25));
    Exit;
  end;
  Sel := odSelected in State;
  UIListRowColors(Timeline, Sel, Back, Fore);
  UIFill(DC, Rect, Back);
  if Sel then Dim := Fore else Dim := clGrayText;
  Labelled := False;
  if FRows[Index].Kind = hrNow then
  begin
    Line1 := 'Now';
    if FHost.Modified(FForm) then Line2 := 'unsaved changes' else Line2 := 'the text in the editor';
    Added := FNowAdded;
    Removed := FNowRemoved;
    if FHost.Modified(FForm) then Dot := KindColor(hkUnsaved) else Dot := clGrayText;
  end
  else
  begin
    V := FHistory[FRows[Index].Version];
    Line1 := ClockText(HistoryLocalTime(V.Time)) + '  ' + VersionCaption(FRows[Index].Version, False);
    Labelled := V.LabelText <> '';
    Line2 := ShortRoutines(V.Routines);
    if Line2 = '' then Line2 := V.Snippet;
    if (Line2 = '') and (V.Added < 0) then Line2 := 'the first version';
    Added := V.Added;
    Removed := V.Removed;
    if Labelled then Dot := clHighlight else Dot := KindColor(V.Kind);
  end;
  if Sel then Dot := Fore;
  { the dot of its kind (a diamond: a label) in the first line }
  X := Rect.Left + 10;
  Y := Rect.Top + 5 + H div 2;
  C.Pen.Color := Dot;
  C.Brush.Color := Dot;
  if Labelled then
  begin
    Pts[0] := Point(X, Y - 5);
    Pts[1] := Point(X + 5, Y);
    Pts[2] := Point(X, Y + 5);
    Pts[3] := Point(X - 5, Y);
    C.Polygon(Pts);
  end
  else
    C.Ellipse(X - 4, Y - 4, X + 4, Y + 4);
  { the lines added and removed at the right of the first line }
  Counts := '';
  if Added >= 0 then
  begin
    Plus := '+' + IntToStr(Added);
    Minus := '-' + IntToStr(Removed);
    if Sel then
    begin
      PlusC := Fore;
      MinusC := Fore;
    end
    else
    begin
      PlusC := UIBlend(clGreen, clWindowText, 85);
      MinusC := UIBlend(clRed, clWindowText, 75);
    end;
    CW := UITextWidth(DC, Plus + ' ' + Minus);
    T := Classes.Rect(Rect.Right - 6 - CW, Rect.Top + 5, Rect.Right - 6, Rect.Top + 5 + H);
    UIText(DC, Plus, T, DT_SINGLELINE or DT_NOPREFIX, PlusC);
    T.Left := T.Left + UITextWidth(DC, Plus + ' ');
    UIText(DC, Minus, T, DT_SINGLELINE or DT_NOPREFIX, MinusC);
    Counts := Plus + ' ' + Minus;
  end;
  R := Classes.Rect(Rect.Left + 20, Rect.Top + 5, Rect.Right - 6, Rect.Top + 5 + H);
  if Counts <> '' then Dec(R.Right, UITextWidth(DC, Counts) + 8);
  { the first line in bold for Now and a label }
  Bold := nil;
  OldFont := 0;
  try
    if Labelled or (FRows[Index].Kind = hrNow) then
    begin
      Bold := TFont.Create;
      Bold.Assign(Timeline.Font);
      Bold.Style := [fsBold];
      OldFont := SelectObject(DC, Bold.Handle);
    end;
    UIText(DC, Line1, R, RowText, Fore);
  finally
    if Bold <> nil then
    begin
      SelectObject(DC, OldFont);
      Bold.Free;
    end;
  end;
  R := Classes.Rect(Rect.Left + 20, Rect.Top + 5 + H, Rect.Right - 6, Rect.Top + 5 + 2 * H);
  UIText(DC, Line2, R, RowText, Dim);
end;

{ a day's row is no choice: the row after it is taken }
procedure TSdHistoryView.TimelineClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Timeline.Items.Count - 1 do
    if Timeline.Selected[I] and (I <= High(FRows)) and (FRows[I].Kind = hrDay) then
    begin
      Timeline.Selected[I] := False;
      if (Timeline.SelCount = 0) and (I + 1 < Timeline.Items.Count) then
      begin
        Timeline.Selected[I + 1] := True;
        Timeline.ItemIndex := I + 1;
      end;
    end;
  Compare(True);
end;

{ a right click on a row that is not chosen chooses it alone: the menu acts on it }
procedure TSdHistoryView.TimelineMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button <> mbRight then Exit;
  I := Timeline.ItemAtPos(Point(X, Y), True);
  if (I < 0) or Timeline.Selected[I] then Exit;
  SelectRows(I, -1);
end;

procedure TSdHistoryView.TimelineDblClick(Sender: TObject);
begin
  FocusDiff;
end;

{ Enter: into the diff }
procedure TSdHistoryView.TimelineKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    FocusDiff;
  end
  else
    ChangeKey(Key, Shift);
end;

procedure TSdHistoryView.SelectRows(A, B: Integer);
var
  I: Integer;
begin
  for I := 0 to Timeline.Items.Count - 1 do Timeline.Selected[I] := (I = A) or (I = B);
  if (A >= 0) and (A < Timeline.Items.Count) then Timeline.ItemIndex := A;
  TimelineClick(nil);
end;

{ --- the commands --- }

{ the line of the change after (before) the caret's line (-1: none) }
function TSdHistoryView.ChangeTarget(Next: Boolean): Integer;
var
  L: Integer;
  Lines: TDiffLines;
begin
  Result := -1;
  if FDiff = nil then Exit;
  L := CaretLine(Lines);
  if Next then Result := ActiveWindow.Edit.MarkerNext(L + 1, 1 shl MK_DIFF_CHANGE)
  else if L > 0 then Result := ActiveWindow.Edit.Sci(SCI_MARKERPREVIOUS, L - 1, 1 shl MK_DIFF_CHANGE);
end;

function TSdHistoryView.CanGotoChange(Next: Boolean): Boolean;
begin
  Result := ChangeTarget(Next) >= 0;
end;

procedure TSdHistoryView.GotoChange(Next: Boolean);
var
  T: Integer;
begin
  T := ChangeTarget(Next);
  if T >= 0 then CaretTo(T);
end;

{ a version chosen alone, not the text now }
function TSdHistoryView.CanRestore: Boolean;
begin
  Result := (ChosenVersion >= 0) and FHost.CanEdit(FForm);
end;

function TSdHistoryView.RestoreDescription: string;
begin
  Result := '';
  if CanRestore then Result := VersionCaption(ChosenVersion, True);
end;

{ the version into the editor; a unit with a form: the other file as it was then too - its newest
  version taken by then (a save takes both at one time), else its original - when it is not the text
  now }
procedure TSdHistoryView.Restore;
var
  V, I, Best: Integer;
  Other: TFileHistory;
  Txt: string;
begin
  if not CanRestore then Exit;
  V := ChosenVersion;
  FHost.Restore(FForm, VersionText(V));
  if FHost.HasForm and FHost.CanEdit(not FForm) then
  begin
    Other := TFileHistory.Create(FHost.FileName(not FForm));
    try
      Best := -1;
      for I := 0 to Other.Count - 1 do
        if Other[I].Time <= FHistory[V].Time then Best := I;
      { none so old: the other file as it was before its history (its original) }
      if (Best < 0) and (Other.Count > 0) and (Other[0].Kind = hkOriginal) then Best := 0;
      if Best >= 0 then
      begin
        Txt := Other.Text(Best, FHost.TextEncoding(not FForm));
        if Txt <> FHost.CurrentText(not FForm) then FHost.Restore(not FForm, Txt);
      end;
    finally
      Other.Free;
    end;
  end;
  Refresh;
end;

{ the change at the caret, against the text now }
function TSdHistoryView.CanRestoreChange: Boolean;
var
  L: Integer;
  Lines: TDiffLines;
begin
  Result := False;
  if (FDiff = nil) or (FTo <> -1) or (FFrom < 0) or not FHost.CanEdit(FForm) then Exit;
  L := CaretLine(Lines);
  Result := (L >= 0) and (L <= High(Lines)) and (Lines[L].Kind in [dlRemoved, dlAdded, dlFiller]) and
    (Lines[L].Run >= 0) and (FDiff[Lines[L].Run].Kind = dkChange);
end;

{ the text now with the change's new lines replaced by its old ones: the lines before it, the old
  lines, the lines after it - the text now's line end between two parts }
procedure TSdHistoryView.RestoreChange;
var
  L, Place, After: Integer;
  Lines: TDiffLines;
  D: TDiffRun;
  NowL: TTextLines;
  Txt: string;
  Joined: Boolean;

  procedure Part(Src: TTextLines; First, Count: Integer);
  begin
    if Count <= 0 then Exit;
    if Joined then Txt := Txt + NowL.LineEnd;
    Txt := Txt + Src.Range(First, Count);
    Joined := True;
  end;

begin
  if not CanRestoreChange then Exit;
  L := CaretLine(Lines);
  D := FDiff[Lines[L].Run];
  NowL := FDiff.NewLines;
  Txt := '';
  Joined := False;
  After := D.B + D.LenB;
  Part(NowL, 0, D.B);
  Part(FDiff.OldLines, D.A, D.LenA);
  Part(NowL, After, NowL.Count - After);
  Place := TopNewLine;
  FHost.Restore(FForm, Txt);
  Compare(False);
  if Place >= 0 then ScrollToNewLine(Place);
end;

function TSdHistoryView.CanGotoCode: Boolean;
begin
  Result := (FDiff <> nil) and (FTo = -1) and not FForm and (Length(FLinesL) > 0);
end;

{ the caret's line in the text now - a removed line's place there }
procedure TSdHistoryView.GotoCode;
var
  L, N: Integer;
  Lines: TDiffLines;
begin
  if not CanGotoCode then Exit;
  L := CaretLine(Lines);
  if (L < 0) or (L > High(Lines)) then Exit;
  N := Lines[L].NewLine;
  if (N < 0) and (Lines[L].Run >= 0) then N := FDiff[Lines[L].Run].B;
  if N < 0 then N := 0;
  FHost.GotoLine(N);
end;

function TSdHistoryView.CanCopy: Boolean;
begin
  Result := ActiveWindow.Edit.SelEnd > ActiveWindow.Edit.SelStart;
end;

procedure TSdHistoryView.CopySelection;
begin
  ActiveWindow.Edit.Copy;
end;

function TSdHistoryView.CanLabel: Boolean;
begin
  Result := (FHistory <> nil) and (Timeline.SelCount <= 1);
end;

{ the label of the version chosen ('' none, or the text now) }
function TSdHistoryView.LabelOfChoice: string;
var
  V: Integer;
begin
  Result := '';
  V := ChosenVersion;
  if V >= 0 then Result := FHistory[V].LabelText;
end;

procedure TSdHistoryView.LabelChoice(const Text: string);
var
  V: Integer;
begin
  if not CanLabel or (Trim(Text) = '') then Exit;
  V := ChosenVersion;
  if V >= 0 then FHistory.SetLabel(V, Trim(Text))
  else HistoryKeep(FHost.FileName(FForm), FHost.CurrentBytes(FForm), FHost.TextEncoding(FForm), hkLabel, Trim(Text));
  Refresh;
end;

function TSdHistoryView.CanRemoveLabel: Boolean;
begin
  Result := LabelOfChoice <> '';
end;

procedure TSdHistoryView.RemoveLabel;
begin
  if not CanRemoveLabel then Exit;
  FHistory.SetLabel(ChosenVersion, '');
  Refresh;
end;

{ --- test mode --- }

{ shown|file|rows|chosen rows|from|to|side by side|blanks|previous|routine|find|changes|status }
function TSdHistoryView.StateText: string;
var
  I: Integer;
  Sel: string;
begin
  Sel := '';
  for I := 0 to Timeline.Items.Count - 1 do
    if Timeline.Selected[I] then Sel := Sel + IntToStr(I) + ',';
  Result := Format('%d|%s|%d|%s|%d|%d|%d%d%d|%s|%s|', [Ord(Showing), ExtractFileName(FHost.FileName(FForm)),
    Length(FRows), Sel, FFrom, FTo, Ord(HistorySideBySide), Ord(HistoryIgnoreBlanks), Ord(HistoryComparePrevious),
    FRoutine, FFind]);
  if FDiff <> nil then Result := Result + Format('%d+%d-%d|', [FShownChanges, FShownAdded, FShownRemoved])
  else Result := Result + '-|';
  Result := Result + FStatus;
end;

{ a row each: now|+a-r, day|caption, version|id|kind|time|+a-r|routines|label }
procedure TSdHistoryView.RowsText(L: TStrings);
var
  I: Integer;
  V: THistoryVersion;
begin
  for I := 0 to High(FRows) do
    case FRows[I].Kind of
      hrNow: L.Add(Format('now|+%d-%d', [FNowAdded, FNowRemoved]));
      hrDay: L.Add('day|' + DayCaption(FRows[I].Day));
    else
      V := FHistory[FRows[I].Version];
      L.Add(Format('version|%d|%s|%s|+%d-%d|%s|%s', [V.Id, HistoryKindKeys[V.Kind],
        FormatDateTime('hh:nn:ss', HistoryLocalTime(V.Time)), V.Added, V.Removed, V.Routines, V.LabelText]));
    end;
end;

{ a line each of the left (inline) window: kind|old|new|text, then the right window's under [right] }
procedure TSdHistoryView.DiffText(L: TStrings);
const
  Kinds: array[TDiffLineKind] of string = ('=', '-', '+', '~', '...');

  procedure Lines(const A: TDiffLines; W: TSciWindow);
  var
    K: Integer;
  begin
    for K := 0 to High(A) do
      L.Add(Format('%s|%d|%d|%s', [Kinds[A[K].Kind], A[K].OldLine + 1, A[K].NewLine + 1, W.Edit.GetLineText(K)]));
  end;

begin
  Lines(FLinesL, FLeft);
  if HistorySideBySide then
  begin
    L.Add('[right]');
    Lines(FLinesR, FRight);
  end;
end;

end.
