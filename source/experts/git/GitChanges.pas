{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitChanges;

{ The Git view: the changes of the active project's repository and the commands on them - a
  dockable tool window of the IDE (DockForm.TDockableForm, registered with designide's desktop),
  laid out as a view of D7 Studio (GitUI): on the view's ground a tool bar - Refresh, Commit, Fetch,
  Pull, Push, Branch, Stash, History - in IntelliJ's images, the branch on its right (ahead and
  behind its upstream); the commit message with Commit and Amend, then the changes in groups -
  Merge Conflicts, Staged Changes, Changes, Untracked Files -, each in a flat frame; the status line
  at the foot of D7 Studio's view (KitViewStatus), else the window's own.
  * The list: a group's header (a click opens or closes it, and does not select it) and its files -
    the state's letter, the name, the folder. Commands act on the selected files; a header selected
    with the keyboard stands for its group's files (not for Open). Double click / Enter: the diff
    (GitDiff); Space: stage or unstage; Delete: discard.
  * Commit: the staged changes with the message (Ctrl+Enter); with nothing staged, every change of the
    tracked files after a question; a merge with the files as they are. Amend fills in the last
    commit's message. Staging a file with a conflict marks it resolved, after a question.
  * Branch and Stash open menus made from the repository's branches and stashes.
  * The commands that change the repository wait while one of them runs or waits; reads do not
    stop them.
  * Without git.exe, outside a repository, or in one git refuses to open, the view says so: Settings,
    Create Repository, Refresh. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ToolWin, ImgList, Menus, ActnList, DockForm, GitCore, GitHost;

const
  GitChangesSection = 'GitChangesView';

type
  TGitGroup = (ggConflicts, ggStaged, ggChanges, ggUntracked);
  TGitGroups = set of TGitGroup;

  { what SelectedPaths gives: file rows only (a selected header gives nothing), the old names of
    staged renames too }
  TGitSelectOption = (soFilesOnly, soRenameSources);
  TGitSelectOptions = set of TGitSelectOption;

  TGitRow = record
    Header: Boolean;
    Group: TGitGroup;
    Letter: Char;         // a file's state in its group
    Path: string;         // a file's repository path (UTF-8)
    OrigPath: string;
    Count: Integer;       // a header: its group's files
  end;

  TGitRowIndexes = array of Integer;

  TGitChangesView = class(TDockableForm)
    TopBar: TPanel;
    MainBar: TToolBar;
    RefreshButton: TToolButton;
    Sep1: TToolButton;
    CommitBarButton: TToolButton;
    Sep2: TToolButton;
    FetchButton: TToolButton;
    PullButton: TToolButton;
    PushButton: TToolButton;
    Sep3: TToolButton;
    BranchButton: TToolButton;
    StashButton: TToolButton;
    Sep4: TToolButton;
    HistoryButton: TToolButton;
    BranchLabel: TLabel;
    MessagePanel: TPanel;
    MessageMemo: TMemo;
    CommitSide: TPanel;
    CommitButton: TButton;
    AmendBox: TCheckBox;
    Splitter: TSplitter;
    ChangesList: TListBox;
    EmptyPanel: TPanel;
    EmptyLabel: TLabel;
    EmptyButton: TButton;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    Actions: TActionList;
    aRefresh: TAction;
    aCommit: TAction;
    aFetch: TAction;
    aPull: TAction;
    aPush: TAction;
    aBranch: TAction;
    aStash: TAction;
    aHistory: TAction;
    aOpen: TAction;
    aDiff: TAction;
    aStage: TAction;
    aUnstage: TAction;
    aDiscard: TAction;
    aFileHistory: TAction;
    aBlame: TAction;
    aCopyPath: TAction;
    aAbort: TAction;
    aStop: TAction;
    aSettings: TAction;
    aInit: TAction;
    aNewBranch: TAction;
    aStashSave: TAction;
    aStashPop: TAction;
    Icons: TImageList;
    IconsDisabled: TImageList;
    ChangesMenu: TPopupMenu;
    miDiff: TMenuItem;
    miOpen: TMenuItem;
    miSep1: TMenuItem;
    miStage: TMenuItem;
    miUnstage: TMenuItem;
    miDiscard: TMenuItem;
    miSep2: TMenuItem;
    miFileHistory: TMenuItem;
    miBlame: TMenuItem;
    miSep3: TMenuItem;
    miCopyPath: TMenuItem;
    miSep4: TMenuItem;
    miAbort: TMenuItem;
    miStop: TMenuItem;
    miSettings: TMenuItem;
    BranchMenu: TPopupMenu;
    StashMenu: TPopupMenu;
    procedure aRefreshExecute(Sender: TObject);
    procedure aCommitExecute(Sender: TObject);
    procedure aCommitUpdate(Sender: TObject);
    procedure aFetchExecute(Sender: TObject);
    procedure aPullExecute(Sender: TObject);
    procedure aPushExecute(Sender: TObject);
    procedure RepoCommandUpdate(Sender: TObject);
    procedure aBranchExecute(Sender: TObject);
    procedure aStashExecute(Sender: TObject);
    procedure aHistoryExecute(Sender: TObject);
    procedure aHistoryUpdate(Sender: TObject);
    procedure aOpenExecute(Sender: TObject);
    procedure aOpenUpdate(Sender: TObject);
    procedure aDiffExecute(Sender: TObject);
    procedure aDiffUpdate(Sender: TObject);
    procedure aStageExecute(Sender: TObject);
    procedure aStageUpdate(Sender: TObject);
    procedure aUnstageExecute(Sender: TObject);
    procedure aUnstageUpdate(Sender: TObject);
    procedure aDiscardExecute(Sender: TObject);
    procedure aDiscardUpdate(Sender: TObject);
    procedure aFileHistoryExecute(Sender: TObject);
    procedure aBlameExecute(Sender: TObject);
    procedure aCopyPathExecute(Sender: TObject);
    procedure aAbortExecute(Sender: TObject);
    procedure aAbortUpdate(Sender: TObject);
    procedure aStopExecute(Sender: TObject);
    procedure aStopUpdate(Sender: TObject);
    procedure aSettingsExecute(Sender: TObject);
    procedure aInitExecute(Sender: TObject);
    procedure aNewBranchExecute(Sender: TObject);
    procedure aStashSaveExecute(Sender: TObject);
    procedure aStashPopExecute(Sender: TObject);
    procedure aStashPopUpdate(Sender: TObject);
    procedure TopBarResize(Sender: TObject);
    procedure EmptyPanelResize(Sender: TObject);
    procedure MessageMemoChange(Sender: TObject);
    procedure MessageMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AmendBoxClick(Sender: TObject);
    procedure ChangesListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ChangesListDblClick(Sender: TObject);
    procedure ChangesListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ChangesListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BranchMenuPopup(Sender: TObject);
    procedure StashMenuPopup(Sender: TObject);
  private
    FRows: array of TGitRow;
    FRowCount: Integer;
    FKey: string;                       // the status shown (TGitStatus.Key) and the groups closed
    FClosed: array[TGitGroup] of Boolean;
    FBranchText, FBranchShort, FBranchHint: string;
    FAmendText: string;                 // the last commit's message put into the box by Amend
    FListActions: TActionList;          // the menus' entries made from data
    FListNames: TStringList;            // ... what each acts on (UTF-8), by the action's Tag
    FPaths: TStringList;                // scratch
    procedure InitLook;
    procedure HostChanged(Sender: TObject);
    procedure Rebuild;
    procedure UpdateBranch;
    procedure UpdateEmpty;
    procedure LayoutEmpty;
    function Host: TGitHost;
    { the selected rows, in their order }
    function SelectedRows: TGitRowIndexes;
    { a row of Groups is selected (FilesOnly: a file's row) }
    function HasSelected(Groups: TGitGroups; FilesOnly: Boolean): Boolean;
    { the row a command on one file acts on: the caret's when it is selected, else the first selected }
    function FocusedRow(out Row: TGitRow): Boolean;
    { the caret's row (selected or not) }
    function CaretRow(out Row: TGitRow): Boolean;
    { the files of the selected rows in the groups Groups (a header: its group's files), each once }
    procedure SelectedPaths(Groups: TGitGroups; L: TStrings; Options: TGitSelectOptions = []);
    procedure ToggleGroup(G: TGitGroup);
    procedure CommitDone(Task: TGitTask);
    procedure LastMessageDone(Task: TGitTask);
    procedure DeleteBranchDone(Task: TGitTask);
    procedure ClearListActions;
    { an action of a menu made from data, which acts on Name (UTF-8); ACaption: its text (an IDE
      string, '&' shown as itself) }
    function ListAction(const Name, ACaption: string; Handler: TNotifyEvent): TAction;
    function ListName(Sender: TObject): string;
    procedure SwitchClick(Sender: TObject);
    procedure SwitchRemoteClick(Sender: TObject);
    procedure DeleteBranchClick(Sender: TObject);
    procedure StashApplyClick(Sender: TObject);
    procedure StashDropClick(Sender: TObject);
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the row of the file Path in group G (Path '': the group's header); -1 when there is none }
    function RowIndex(G: TGitGroup; const Path: string): Integer;
    { that row alone selected, the caret on it }
    procedure SelectRow(Index: Integer);
  end;

var
  GitChangesForm: TGitChangesView;

procedure RegisterGitView;
procedure UnregisterGitView;
procedure ShowGitView;

implementation

{$R *.dfm}

uses
  ToolsAPI, DeskUtil, Clipbrd, GitText, GitUI, GitIde, GitViews, GitDiff, GitHistory, GitBranchDlg,
  GitStashDlg, GitSettingsDlg;

const
  { the commands' images (GitIcons.bmp's cells), in the order of the actions' ImageIndex in the .dfm }
  IconCells: array[0..16] of Integer = (giRefresh, giCommit, giFetch, giPull, giPush, giBranch, giStash,
    giHistory, giOpenFile, giDiff, giStage, giUnstage, giDiscard, giBlame, giCopy, giSettings, giStop);

  GroupNames: array[TGitGroup] of string = ('Merge Conflicts', 'Staged Changes', 'Changes', 'Untracked Files');
  GroupKinds: array[TGitGroup] of TGitChangeKind = (ckConflict, ckStaged, ckUnstaged, ckUntracked);
  AllGroups = [ggConflicts, ggStaged, ggChanges, ggUntracked];

  IndentFile = 20;     // a file's letter, from the row's left
  EmptyButtonGap = 7;  // between the note of an empty view and its button

type
  { a press of the left button on a group's header opens or closes the group; the list box does not
    see it, so the header is not selected - a selected header stands for its group's files }
  THeaderClick = class(TKitWindowHook)
  private
    FView: TGitChangesView;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure THeaderClick.Hook(var Message: TMessage);
var
  I: Integer;
begin
  if ((Message.Msg = WM_LBUTTONDOWN) or (Message.Msg = WM_LBUTTONDBLCLK)) and
    (Message.WParam and (MK_SHIFT or MK_CONTROL) = 0) then
  begin
    I := FView.ChangesList.ItemAtPos(Point(TWMMouse(Message).XPos, TWMMouse(Message).YPos), True);
    if (I >= 0) and (I < FView.FRowCount) and FView.FRows[I].Header then
    begin
      if Control.CanFocus then Control.SetFocus;
      { the caret only: the keyboard goes on from the header }
      FView.ChangesList.ItemIndex := I;
      FView.ToggleGroup(FView.FRows[I].Group);
      Message.Result := 0;
      Exit;
    end;
  end;
  CallOld(Message);
end;

procedure RegisterGitView;
begin
  RegisterView(TGitChangesView, GitChangesSection, @GitChangesForm);
end;

procedure UnregisterGitView;
begin
  UnregisterView(GitChangesForm);
end;

procedure ShowGitView;
var
  H: TGitHost;
begin
  if GitChangesForm = nil then GitChangesForm := TGitChangesView.Create(nil);
  FocusWindow(GitChangesForm);
  { a view that comes reads a change seen meanwhile (ViewShowing); else the status is read now }
  H := GitHostInstance;
  if not H.RefreshPending then H.Refresh;
end;

{ the first line of S }
function FirstLine(const S: string): string;
var
  P: Integer;
begin
  P := Pos(#13, S);
  if P = 0 then P := Pos(#10, S);
  if P = 0 then Result := S else Result := Copy(S, 1, P - 1);
end;

{ ---------------------------------------------------------------- TGitChangesView }

constructor TGitChangesView.Create(AOwner: TComponent);
begin
  inherited;
  { before OnCreate (OldCreateOrder is False): TDockableForm.FormCreate reads Dockable from this
    section of DeskUtil.IDEIniFile }
  DeskSection := GitChangesSection;
  AutoSave := True;
  FPaths := TStringList.Create;
  FListNames := TStringList.Create;
  FListActions := TActionList.Create(Self);
  InitLook;
  GitHostInstance.AddListener(HostChanged);
  HostChanged(nil);
end;

destructor TGitChangesView.Destroy;
begin
  ViewGoes(Self, HostChanged);
  FListNames.Free;
  FPaths.Free;
  inherited;
end;

function TGitChangesView.Host: TGitHost;
begin
  Result := GitHostInstance;
end;

{ the IDE's font (the form laid out for it), the images, the bars' and frames' look, the hint text }
procedure TGitChangesView.InitLook;
begin
  KitUseIdeFont(Self);
  KitBitmapIcons(Actions, [MainBar], [ChangesMenu], GitIconsResource, IconCells, Icons, IconsDisabled);
  KitFlatToolBar(MainBar);
  KitFlatFrame(MessagePanel);
  KitFlatFrame(ChangesList);
  KitFlatFrame(EmptyPanel);
  KitCueText(MessageMemo, 'Message (Ctrl+Enter commits)');
  ChangesList.Canvas.Font := ChangesList.Font;
  ChangesList.ItemHeight := ChangesList.Canvas.TextHeight('Ag') + 4;
  ChangesList.DoubleBuffered := True;
  RepaintOnWidthChange(ChangesList);
  THeaderClick.Create(ChangesList).FView := Self;
end;

procedure TGitChangesView.CreateWnd;
begin
  inherited;
  if FPaths <> nil then HostChanged(nil);
end;

procedure TGitChangesView.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if FPaths = nil then Exit;
  GitHostInstance.ViewShowing(Showing);
  if Showing then HostChanged(nil);
end;

procedure TGitChangesView.HostChanged(Sender: TObject);
var
  H: TGitHost;
  S: string;
  St: TGitStatus;
  N: Integer;
begin
  H := Host;
  UpdateEmpty;
  UpdateBranch;
  Rebuild;
  if not H.GitFound then S := 'git.exe was not found'
  else if H.Busy then S := H.BusyTitle
  else if H.Repo = nil then S := 'No repository'
  else
  begin
    St := H.Status;
    S := BranchText(St);
    if S = '' then S := 'No commits yet';
    case H.State of
      rsMerging: S := S + GitDot + 'Merging';
      rsRebasing: S := S + GitDot + 'Rebasing';
      rsCherryPicking: S := S + GitDot + 'Cherry-picking';
      rsReverting: S := S + GitDot + 'Reverting';
      rsApplying: S := S + GitDot + 'Applying patches';
    end;
    if H.StatusFailure <> '' then S := S + GitDot + 'The status could not be read: ' + FirstLine(H.StatusFailure)
    else
    begin
      N := St.Count;
      if N = 0 then S := S + GitDot + 'No changes'
      else if N = 1 then S := S + GitDot + '1 change'
      else S := S + GitDot + Format('%d changes', [N]);
      if St.CountStaged > 0 then S := S + GitDot + Format('%d staged', [St.CountStaged]);
      if St.CountConflicts > 0 then S := S + GitDot + Format('%d conflicts', [St.CountConflicts]);
    end;
  end;
  ShowViewStatus(Self, StatusPanel, StatusLabel, S);
end;

{ the list, or the note why there is none }
procedure TGitChangesView.UpdateEmpty;
var
  H: TGitHost;
  Empty: Boolean;
begin
  H := Host;
  Empty := not H.GitFound or (H.Repo = nil);
  if Empty then
  begin
    if not H.GitFound then
    begin
      EmptyLabel.Caption := 'git.exe was not found. Install Git for Windows, or tell the Git expert where git.exe is.';
      EmptyButton.Action := aSettings;
    end
    else if H.ProjectFolder = '' then
    begin
      EmptyLabel.Caption := 'Open a project that is saved in a folder: its Git repository is shown here.';
      EmptyButton.Action := aRefresh;
    end
    else if H.RepoFailure <> '' then
    begin
      { a repository git refuses to open: never one made inside it }
      EmptyLabel.Caption := 'Git cannot open the repository of the project''s folder:'#13#10 + H.RepoFailure;
      EmptyButton.Action := aRefresh;
    end
    else
    begin
      EmptyLabel.Caption := Format('The folder of the project is not in a Git repository:'#13#10'%s',
        [Utf8ToIde(H.ProjectFolder)]);
      EmptyButton.Action := aInit;
    end;
    LayoutEmpty;
  end;
  if EmptyPanel.Visible <> Empty then
  begin
    { what replaces the other comes first }
    if Empty then
    begin
      EmptyPanel.Visible := True;
      KitPassKeyboard(ChangesList, EmptyButton);
      ChangesList.Visible := False;
    end
    else
    begin
      ChangesList.Visible := True;
      KitPassKeyboard(EmptyPanel, ChangesList);
      EmptyPanel.Visible := False;
    end;
  end;
  if MessagePanel.Visible = Empty then
  begin
    { the keyboard leaves the message that goes for the note's button }
    if Empty then KitPassKeyboard(MessagePanel, EmptyButton);
    MessagePanel.Visible := not Empty;
    { aligned controls go by their edges: the splitter, which slid up while both were hidden, comes
      after the message again - not between the tool bar and it }
    Splitter.Top := MessagePanel.Top + MessagePanel.Height;
    Splitter.Visible := not Empty;
  end;
end;

{ the note as high as its lines (three at least), its button below it }
procedure TGitChangesView.LayoutEmpty;
var
  R: TRect;
  H: Integer;
begin
  if not EmptyPanel.HandleAllocated then Exit;
  R := Rect(0, 0, EmptyLabel.Width, 0);
  EmptyLabel.Canvas.Font := EmptyLabel.Font;
  DrawText(EmptyLabel.Canvas.Handle, PChar(EmptyLabel.Caption), -1, R, DT_CALCRECT or DT_WORDBREAK or
    DT_NOPREFIX);
  H := 3 * EmptyLabel.Canvas.TextHeight('Ag');
  if R.Bottom > H then H := R.Bottom;
  EmptyLabel.Height := H;
  EmptyButton.Top := EmptyLabel.Top + H + EmptyButtonGap;
end;

procedure TGitChangesView.EmptyPanelResize(Sender: TObject);
begin
  if EmptyPanel.Visible then LayoutEmpty;
end;

procedure TGitChangesView.UpdateBranch;
var
  H: TGitHost;
begin
  H := Host;
  FBranchText := '';
  FBranchShort := '';
  FBranchHint := '';
  if H.Repo <> nil then
  begin
    FBranchText := BranchText(H.Status);
    FBranchShort := Utf8ToIde(H.Status.Branch);
    if H.Status.Branch = '' then FBranchHint := FBranchText
    else if H.Status.Upstream = '' then
      FBranchHint := Format('Branch %s, with no upstream branch', [FBranchShort])
    else
      FBranchHint := Format('Branch %s, tracking %s: %d ahead, %d behind', [FBranchShort,
        Utf8ToIde(H.Status.Upstream), H.Status.Ahead, H.Status.Behind]);
  end;
  KitLayoutBarLabel(BranchLabel, MainBar, FBranchText, FBranchShort, FBranchHint);
end;

procedure TGitChangesView.TopBarResize(Sender: TObject);
begin
  KitLayoutBarLabel(BranchLabel, MainBar, FBranchText, FBranchShort, FBranchHint);
end;

{ the rows from the host's status: the groups in their order, each header and, when it is open,
  its files by path; what was selected stays selected, the list where it was }
procedure TGitChangesView.Rebuild;
var
  H: TGitHost;
  St: TGitStatus;
  StatusKey, RowKeyText, Sel: string;
  G: TGitGroup;
  I, N, Top, Focus: Integer;
  C: TGitChange;
  Files: TStringList;
  Selected: TGitPathList;
  Rows: TGitRowIndexes;
  R: TGitRow;

  procedure AddRow(const Row: TGitRow);
  begin
    if FRowCount = Length(FRows) then SetLength(FRows, FRowCount * 2 + 16);
    FRows[FRowCount] := Row;
    Inc(FRowCount);
  end;

  function RowKey(const Row: TGitRow): string;
  begin
    Result := IntToStr(Ord(Row.Group)) + IntToStr(Ord(Row.Header)) + #1 + Row.Path;
  end;

begin
  H := Host;
  St := H.Status;
  StatusKey := '';
  if H.Repo <> nil then StatusKey := H.Repo.Root + #2 + St.Key;
  for G := Low(TGitGroup) to High(TGitGroup) do StatusKey := StatusKey + Chr(Ord('0') + Ord(FClosed[G]));
  if StatusKey = FKey then Exit;
  FKey := StatusKey;
  Selected := TGitPathList.Create;
  Files := TStringList.Create;
  try
    { what is selected, by group and path }
    Rows := SelectedRows;
    for I := 0 to High(Rows) do
      if Rows[I] < FRowCount then Selected.Add(RowKey(FRows[Rows[I]]));
    if (ChangesList.ItemIndex >= 0) and (ChangesList.ItemIndex < FRowCount) then
      Sel := RowKey(FRows[ChangesList.ItemIndex])
    else Sel := '';
    Top := ChangesList.TopIndex;
    FRowCount := 0;
    if H.Repo <> nil then
      for G := Low(TGitGroup) to High(TGitGroup) do
      begin
        Files.Clear;
        for I := 0 to St.Count - 1 do
        begin
          C := St[I];
          if C.IsKind(GroupKinds[G]) then Files.AddObject(C.Path, C);
        end;
        if Files.Count = 0 then Continue;
        Files.Sort;
        FillChar(R, SizeOf(R), 0);
        R.Header := True;
        R.Group := G;
        R.Count := Files.Count;
        AddRow(R);
        if FClosed[G] then Continue;
        for I := 0 to Files.Count - 1 do
        begin
          C := TGitChange(Files.Objects[I]);
          R.Header := False;
          R.Path := C.Path;
          R.OrigPath := C.OrigPath;
          case G of
            ggConflicts: R.Letter := '!';
            ggStaged: R.Letter := C.X;
            ggChanges: R.Letter := C.Y;
          else
            R.Letter := 'U';
          end;
          AddRow(R);
        end;
      end;
    ChangesList.Items.BeginUpdate;
    try
      ChangesList.Count := FRowCount;
      ChangesList.Perform(LB_SETSEL, 0, -1);
      Focus := -1;
      for I := 0 to FRowCount - 1 do
      begin
        RowKeyText := RowKey(FRows[I]);
        if (Selected.Count > 0) and Selected.Find(RowKeyText, N) then ChangesList.Selected[I] := True;
        if RowKeyText = Sel then Focus := I;
      end;
      if Focus >= 0 then ChangesList.ItemIndex := Focus;
      if Top < FRowCount then ChangesList.TopIndex := Top;
    finally
      ChangesList.Items.EndUpdate;
    end;
    ChangesList.Invalidate;
  finally
    Files.Free;
    Selected.Free;
  end;
end;

function TGitChangesView.RowIndex(G: TGitGroup; const Path: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FRowCount - 1 do
    if (FRows[I].Group = G) and (FRows[I].Header = (Path = '')) and ((Path = '') or (FRows[I].Path = Path)) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TGitChangesView.SelectRow(Index: Integer);
begin
  ChangesList.Perform(LB_SETSEL, 0, -1);
  if (Index < 0) or (Index >= FRowCount) then Exit;
  ChangesList.Selected[Index] := True;
  ChangesList.ItemIndex := Index;
end;

function TGitChangesView.SelectedRows: TGitRowIndexes;
var
  N: Integer;
begin
  Result := nil;
  if not ChangesList.HandleAllocated then Exit;
  N := ChangesList.Perform(LB_GETSELCOUNT, 0, 0);
  if N <= 0 then Exit;
  SetLength(Result, N);
  N := ChangesList.Perform(LB_GETSELITEMS, N, Integer(@Result[0]));
  if N < 0 then N := 0;
  SetLength(Result, N);
end;

function TGitChangesView.HasSelected(Groups: TGitGroups; FilesOnly: Boolean): Boolean;
var
  Rows: TGitRowIndexes;
  I: Integer;
begin
  Result := False;
  Rows := SelectedRows;
  for I := 0 to High(Rows) do
    if (Rows[I] < FRowCount) and (FRows[Rows[I]].Group in Groups) and not (FilesOnly and FRows[Rows[I]].Header) then
    begin
      Result := True;
      Exit;
    end;
end;

function TGitChangesView.CaretRow(out Row: TGitRow): Boolean;
var
  I: Integer;
begin
  I := ChangesList.ItemIndex;
  Result := (I >= 0) and (I < FRowCount);
  if Result then Row := FRows[I];
end;

function TGitChangesView.FocusedRow(out Row: TGitRow): Boolean;
var
  I: Integer;
  Rows: TGitRowIndexes;
begin
  I := ChangesList.ItemIndex;
  if (I < 0) or (I >= FRowCount) or not ChangesList.Selected[I] then
  begin
    Rows := SelectedRows;
    if Length(Rows) > 0 then I := Rows[0] else I := -1;
  end;
  Result := (I >= 0) and (I < FRowCount);
  if Result then Row := FRows[I];
end;

procedure TGitChangesView.SelectedPaths(Groups: TGitGroups; L: TStrings; Options: TGitSelectOptions);
var
  Rows: TGitRowIndexes;
  I: Integer;
  St: TGitStatus;
  C: TGitChange;
  G: TGitGroup;
  R: TGitRow;
  Picked: array[TGitGroup] of Boolean;
  Paths: TGitPathList;
begin
  FillChar(Picked, SizeOf(Picked), 0);
  Paths := TGitPathList.Create;
  try
    Rows := SelectedRows;
    for I := 0 to High(Rows) do
    begin
      if Rows[I] >= FRowCount then Continue;
      R := FRows[Rows[I]];
      if not (R.Group in Groups) then Continue;
      if R.Header then
      begin
        if not (soFilesOnly in Options) then Picked[R.Group] := True;
      end
      else
      begin
        Paths.Add(R.Path);
        { a staged rename unstaged: its old name too, else the deletion stays staged }
        if (soRenameSources in Options) and (R.Group = ggStaged) and (R.Letter = 'R') then Paths.Add(R.OrigPath);
      end;
    end;
    { a header: every file of its group, also those of a closed group }
    St := Host.Status;
    for G := Low(TGitGroup) to High(TGitGroup) do
      if Picked[G] then
        for I := 0 to St.Count - 1 do
        begin
          C := St[I];
          if not C.IsKind(GroupKinds[G]) then Continue;
          Paths.Add(C.Path);
          if (soRenameSources in Options) and (G = ggStaged) and (C.X = 'R') then Paths.Add(C.OrigPath);
        end;
    L.Assign(Paths);
  finally
    Paths.Free;
  end;
end;

procedure TGitChangesView.ToggleGroup(G: TGitGroup);
begin
  FClosed[G] := not FClosed[G];
  Rebuild;
end;

{ a header: its chevron, the group's name and its count; a file: GitViews.DrawFileRow }
procedure TGitChangesView.ChangesListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  R: TRect;
  Row: TGitRow;
  W: WideString;
  Chevron: WideChar;
  OldFont: TFont;
  TextColor, GreyColor: TColor;
begin
  if (Index < 0) or (Index >= FRowCount) then Exit;
  C := ChangesList.Canvas;
  Row := FRows[Index];
  if not Row.Header then
  begin
    DrawFileRow(C, Rect, IndentFile, Row.Letter, Row.Path, Row.OrigPath, odSelected in State);
    Exit;
  end;
  RowColors(C, odSelected in State, TextColor, GreyColor);
  C.FillRect(Rect);
  SetBkMode(C.Handle, TRANSPARENT);
  R := Rect;
  R.Right := R.Left + IndentFile;
  if KitIconFont <> '' then
  begin
    OldFont := TFont.Create;
    try
      OldFont.Assign(C.Font);
      C.Font.Name := KitIconFont;
      C.Font.Height := -9;
      C.Font.Style := [];
      C.Font.Color := GreyColor;
      if FClosed[Row.Group] then Chevron := WideChar($E76C) else Chevron := WideChar($E70D);
      DrawTextW(C.Handle, @Chevron, 1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
      C.Font.Assign(OldFont);
    finally
      OldFont.Free;
    end;
  end;
  R.Left := R.Right;
  R.Right := Rect.Right;
  C.Font.Style := [fsBold];
  C.Font.Color := TextColor;
  W := GroupNames[Row.Group];
  DrawTextW(C.Handle, PWideChar(W), Length(W), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  Inc(R.Left, KitTextWidthW(C, W) + 8);
  C.Font.Style := [];
  C.Font.Color := GreyColor;
  W := IntToStr(Row.Count);
  DrawTextW(C.Handle, PWideChar(W), Length(W), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

{ the context menu acts on the row under the pointer: it alone selected when it was not; the caret
  goes there either way (the commands on one file act on it) }
procedure TGitChangesView.ChangesListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button <> mbRight then Exit;
  I := ChangesList.ItemAtPos(Point(X, Y), True);
  if (I < 0) or (I >= FRowCount) then Exit;
  if not ChangesList.Selected[I] then SelectRow(I)
  else ChangesList.ItemIndex := I;
end;

procedure TGitChangesView.ChangesListDblClick(Sender: TObject);
var
  Row: TGitRow;
begin
  if FocusedRow(Row) and not Row.Header then aDiff.Execute;
end;

procedure TGitChangesView.ChangesListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Caret, Row: TGitRow;
  OnHeader: Boolean;
begin
  OnHeader := CaretRow(Caret) and Caret.Header;
  case Key of
    VK_RETURN:
      begin
        if OnHeader then ToggleGroup(Caret.Group)
        else if FocusedRow(Row) and not Row.Header then aDiff.Execute;
        Key := 0;
      end;
    VK_SPACE:
      begin
        if FocusedRow(Row) then
          if Row.Group = ggStaged then aUnstage.Execute else aStage.Execute;
        Key := 0;
      end;
    VK_DELETE:
      begin
        aDiscard.Execute;
        Key := 0;
      end;
    VK_LEFT, VK_RIGHT:
      if OnHeader and (FClosed[Caret.Group] = (Key = VK_RIGHT)) then
      begin
        ToggleGroup(Caret.Group);
        Key := 0;
      end;
  end;
end;

{ ---------------------------------------------------------------- commands }

procedure TGitChangesView.RepoCommandUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (Host.Repo <> nil) and not Host.Changing;
end;

procedure TGitChangesView.aRefreshExecute(Sender: TObject);
begin
  Host.Refresh;
end;

procedure TGitChangesView.aCommitUpdate(Sender: TObject);
begin
  aCommit.Enabled := (Host.Repo <> nil) and not Host.Changing and (Trim(MessageMemo.Text) <> '');
end;

procedure TGitChangesView.aCommitExecute(Sender: TObject);
var
  St, Current: TGitStatus;
  Msg: string;
  StageAll: Boolean;
begin
  Msg := TrimRightText(IdeToUtf8(MessageMemo.Text));
  if Trim(Msg) = '' then
  begin
    MessageMemo.SetFocus;
    Exit;
  end;
  { the files first: what is not saved is not committed }
  if not Host.SaveFiles('Changes that are not saved are not committed.') then Exit;
  Current := nil;
  try
    St := Host.Status;
    { files were saved: the status as it is now }
    if Host.LastSaved > 0 then
    begin
      Current := TGitStatus.Create;
      if Host.ReadStatus(Current) then St := Current;
    end;
    if St.CountConflicts > 0 then
    begin
      GitInform('Resolve the conflicts first: stage each file when its conflict is resolved.');
      Exit;
    end;
    StageAll := False;
    { a merge is concluded by a commit, also when its result is HEAD's files }
    if (St.CountStaged = 0) and not AmendBox.Checked and (Host.State <> rsMerging) then
    begin
      if St.CountUnstaged = 0 then
      begin
        GitInform('There is nothing to commit: stage the files to commit first.');
        Exit;
      end;
      if GitConfirm('There are no staged changes. Stage every change of the tracked files and commit them?',
        MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
      StageAll := True;
    end;
    Host.Commit(Msg, AmendBox.Checked, StageAll, Self, CommitDone);
  finally
    Current.Free;
  end;
end;

procedure TGitChangesView.CommitDone(Task: TGitTask);
begin
  if Task.Error <> '' then Exit;
  MessageMemo.Clear;
  FAmendText := '';
  AmendBox.Checked := False;
end;

procedure TGitChangesView.AmendBoxClick(Sender: TObject);
begin
  if AmendBox.Checked then
  begin
    if (Trim(MessageMemo.Text) = '') and (Host.Repo <> nil) then Host.LoadLastMessage(Self, LastMessageDone);
  end
  else if (FAmendText <> '') and (MessageMemo.Text = FAmendText) then
  begin
    MessageMemo.Clear;
    FAmendText := '';
  end;
end;

procedure TGitChangesView.LastMessageDone(Task: TGitTask);
begin
  if (Task.Error <> '') or not AmendBox.Checked or (Trim(MessageMemo.Text) <> '') then Exit;
  FAmendText := Utf8ToIde(NormalizeNewLines(Task.Info, #13#10));
  MessageMemo.Text := FAmendText;
end;

procedure TGitChangesView.MessageMemoChange(Sender: TObject);
begin
  { the hint text of an empty box comes and goes }
  MessageMemo.Invalidate;
end;

procedure TGitChangesView.MessageMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    aCommit.Execute;
  end;
end;

procedure TGitChangesView.aFetchExecute(Sender: TObject);
begin
  Host.Fetch;
end;

procedure TGitChangesView.aPullExecute(Sender: TObject);
begin
  if Host.SaveFiles('Pulling may change files of the work tree.') then Host.Pull;
end;

procedure TGitChangesView.aPushExecute(Sender: TObject);
var
  Remotes: TStringList;
  Remote: string;
begin
  if Host.Status.Branch = '' then
  begin
    GitInform('HEAD is not on a branch: switch to a branch to push it.');
    Exit;
  end;
  if Host.Status.Upstream <> '' then
  begin
    Host.Push('');
    Exit;
  end;
  Remotes := TStringList.Create;
  try
    try
      Remotes.Text := Host.Repo.Remotes;
    except
      Remotes.Clear;
    end;
    if Remotes.Count = 0 then
    begin
      GitInform('The repository has no remote to push to.');
      Exit;
    end;
    if Remotes.IndexOf('origin') >= 0 then Remote := 'origin' else Remote := Remotes[0];
    if GitConfirm(Format('The branch %s has no upstream branch. Push it to %s and track it there?',
      [Utf8ToIde(Host.Status.Branch), Utf8ToIde(Remote)]), MB_YESNO or MB_ICONQUESTION) = IDYES then
      Host.Push(Remote);
  finally
    Remotes.Free;
  end;
end;

{ a menu below its tool button }
procedure DropMenu(Menu: TPopupMenu; Button: TToolButton);
var
  P: TPoint;
begin
  P := Button.ClientToScreen(Point(0, Button.Height));
  Menu.PopupComponent := Button;
  Menu.Popup(P.X, P.Y);
end;

procedure TGitChangesView.aBranchExecute(Sender: TObject);
begin
  DropMenu(BranchMenu, BranchButton);
end;

procedure TGitChangesView.aStashExecute(Sender: TObject);
begin
  DropMenu(StashMenu, StashButton);
end;

procedure TGitChangesView.aHistoryUpdate(Sender: TObject);
begin
  aHistory.Enabled := Host.Repo <> nil;
end;

procedure TGitChangesView.aHistoryExecute(Sender: TObject);
begin
  ShowGitHistory('');
end;

{ Open and Copy Path; Open takes the files' rows only - a group's header would open all of them }
procedure TGitChangesView.aOpenUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (Host.Repo <> nil) and HasSelected(AllGroups, Sender = aOpen);
end;

procedure TGitChangesView.aOpenExecute(Sender: TObject);
var
  I: Integer;
  F: string;
begin
  SelectedPaths(AllGroups, FPaths, [soFilesOnly]);
  for I := 0 to FPaths.Count - 1 do
  begin
    F := Host.FileOf(FPaths[I]);
    if FileExists(F) then ShowFileAt(F, 1, 1);
  end;
end;

{ Diff, File History and Blame: a file's row; Blame: a file with a history }
procedure TGitChangesView.aDiffUpdate(Sender: TObject);
var
  Row: TGitRow;
begin
  TAction(Sender).Enabled := (Host.Repo <> nil) and FocusedRow(Row) and not Row.Header and
    ((Sender <> aBlame) or (Row.Group <> ggUntracked));
end;

procedure TGitChangesView.aDiffExecute(Sender: TObject);
var
  Row: TGitRow;
begin
  if not FocusedRow(Row) or Row.Header then Exit;
  case Row.Group of
    ggStaged: ShowGitDiff(gkStaged, Row.Path, Row.OrigPath, '', '', 'staged');
    ggUntracked: ShowGitDiff(gkUntracked, Row.Path, '', '', '', 'untracked');
    ggConflicts: ShowGitDiff(gkConflict, Row.Path, '', '', '', 'conflict, against HEAD');
  else
    ShowGitDiff(gkWorkTree, Row.Path, '', '', '', 'not staged');
  end;
end;

procedure TGitChangesView.aStageUpdate(Sender: TObject);
begin
  aStage.Enabled := (Host.Repo <> nil) and not Host.Changing and HasSelected([ggConflicts, ggChanges, ggUntracked], False);
end;

procedure TGitChangesView.aStageExecute(Sender: TObject);
var
  Conflicts: TStringList;
  S: string;
begin
  SelectedPaths([ggConflicts, ggChanges, ggUntracked], FPaths);
  if FPaths.Count = 0 then Exit;
  { staging a file with a conflict marks the conflict resolved }
  Conflicts := TStringList.Create;
  try
    SelectedPaths([ggConflicts], Conflicts);
    if Conflicts.Count > 0 then
    begin
      if Conflicts.Count = 1 then S := Format('Mark the conflict of %s as resolved?', [PathText(Conflicts[0])])
      else S := Format('Mark the conflicts of %d files as resolved?', [Conflicts.Count]);
      if GitConfirm(S + ' Stage a file when its conflict markers are gone.', MB_YESNO or MB_ICONQUESTION) <> IDYES then
        Exit;
    end;
  finally
    Conflicts.Free;
  end;
  Host.Stage(FPaths);
end;

procedure TGitChangesView.aUnstageUpdate(Sender: TObject);
begin
  aUnstage.Enabled := (Host.Repo <> nil) and not Host.Changing and HasSelected([ggStaged], False);
end;

procedure TGitChangesView.aUnstageExecute(Sender: TObject);
begin
  SelectedPaths([ggStaged], FPaths, [soRenameSources]);
  if FPaths.Count > 0 then Host.Unstage(FPaths);
end;

procedure TGitChangesView.aDiscardUpdate(Sender: TObject);
begin
  aDiscard.Enabled := (Host.Repo <> nil) and not Host.Changing and HasSelected([ggChanges, ggUntracked], False);
end;

procedure TGitChangesView.aDiscardExecute(Sender: TObject);
var
  Tracked, Untracked, Unsaved: TStringList;
  S: string;
  I: Integer;
begin
  Tracked := TStringList.Create;
  Untracked := TStringList.Create;
  Unsaved := TStringList.Create;
  try
    SelectedPaths([ggChanges], Tracked);
    SelectedPaths([ggUntracked], Untracked);
    if Tracked.Count + Untracked.Count = 0 then Exit;
    S := '';
    if Tracked.Count = 1 then S := Format('Discard the changes of %s?', [PathText(Tracked[0])])
    else if Tracked.Count > 1 then S := Format('Discard the changes of %d files?', [Tracked.Count]);
    if Untracked.Count > 0 then
    begin
      if S <> '' then S := S + #13#10;
      if Untracked.Count = 1 then S := S + Format('Delete the untracked file %s?', [PathText(Untracked[0])])
      else S := S + Format('Delete %d untracked files?', [Untracked.Count]);
    end;
    { the IDE reads the discarded files again: what it has not saved of them goes too }
    Host.UnsavedModules(Tracked, Unsaved);
    if Unsaved.Count > 0 then
    begin
      S := S + #13#10#13#10'The changes the IDE has not saved in these files are discarded too:';
      for I := 0 to Unsaved.Count - 1 do S := S + #13#10'    ' + ExtractFileName(Unsaved[I]);
    end;
    S := S + #13#10#13#10'This cannot be undone.';
    if GitConfirm(S, MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) <> IDYES then Exit;
    Host.Discard(Tracked, Untracked);
  finally
    Unsaved.Free;
    Untracked.Free;
    Tracked.Free;
  end;
end;

procedure TGitChangesView.aFileHistoryExecute(Sender: TObject);
var
  Row: TGitRow;
begin
  if FocusedRow(Row) and not Row.Header then ShowGitHistory(Row.Path);
end;

procedure TGitChangesView.aBlameExecute(Sender: TObject);
var
  Row: TGitRow;
begin
  if FocusedRow(Row) and not Row.Header and (Row.Group <> ggUntracked) then ShowGitBlame(Row.Path, '');
end;

procedure TGitChangesView.aCopyPathExecute(Sender: TObject);
var
  I: Integer;
  S: string;
begin
  SelectedPaths(AllGroups, FPaths);
  S := '';
  for I := 0 to FPaths.Count - 1 do
  begin
    if S <> '' then S := S + #13#10;
    S := S + Host.FileOf(FPaths[I]);
  end;
  if S <> '' then Clipboard.AsText := S;
end;

procedure TGitChangesView.aAbortUpdate(Sender: TObject);
const
  Captions: array[TGitRepoState] of string = ('&Abort', '&Abort Merge', '&Abort Rebase', '&Abort Cherry-Pick',
    '&Abort Revert', '&Abort git am');
begin
  aAbort.Visible := (Host.Repo <> nil) and (Host.State <> rsNormal);
  aAbort.Enabled := aAbort.Visible and not Host.Changing;
  aAbort.Caption := Captions[Host.State];
end;

procedure TGitChangesView.aAbortExecute(Sender: TObject);
begin
  if GitConfirm('Abandon what is going on and go back to the state before it? Its changes are lost.',
    MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) = IDYES then Host.AbortOperation;
end;

procedure TGitChangesView.aStopUpdate(Sender: TObject);
begin
  aStop.Enabled := Host.CanCancel;
end;

procedure TGitChangesView.aStopExecute(Sender: TObject);
begin
  Host.CancelRunning;
end;

procedure TGitChangesView.aSettingsExecute(Sender: TObject);
begin
  if TGitSettingsDialog.Execute then Host.SettingsChanged;
end;

procedure TGitChangesView.aInitExecute(Sender: TObject);
begin
  if GitConfirm(Format('Create a Git repository in %s?', [Utf8ToIde(Host.ProjectFolder)]), MB_YESNO or MB_ICONQUESTION) = IDYES then
    Host.InitRepository;
end;

procedure TGitChangesView.aNewBranchExecute(Sender: TObject);
begin
  GitNewBranch('');
end;

procedure TGitChangesView.aStashSaveExecute(Sender: TObject);
var
  Msg: string;
  Untracked: Boolean;
begin
  if not TGitStashDialog.Execute(Msg, Untracked) then Exit;
  if Host.SaveFiles('Stashing takes the changes out of the work tree.') then Host.StashPush(Msg, Untracked);
end;

procedure TGitChangesView.aStashPopUpdate(Sender: TObject);
begin
  aStashPop.Enabled := (Host.Repo <> nil) and not Host.Changing and (Host.Stashes.Count > 0);
end;

procedure TGitChangesView.aStashPopExecute(Sender: TObject);
begin
  if Host.SaveFiles('Popping the stash changes files of the work tree.') then Host.StashPop;
end;

{ ---------------------------------------------------------------- the menus made from data }

procedure TGitChangesView.ClearListActions;
begin
  while FListActions.ActionCount > 0 do FListActions.Actions[0].Free;
  FListNames.Clear;
end;

function TGitChangesView.ListAction(const Name, ACaption: string; Handler: TNotifyEvent): TAction;
begin
  Result := TAction.Create(FListActions);
  Result.ActionList := FListActions;
  Result.Caption := StringReplace(ACaption, '&', '&&', [rfReplaceAll]);
  Result.OnExecute := Handler;
  Result.Tag := FListNames.Add(Name);
end;

function TGitChangesView.ListName(Sender: TObject): string;
var
  I: Integer;
begin
  I := TComponent(Sender).Tag;
  if (I >= 0) and (I < FListNames.Count) then Result := FListNames[I] else Result := '';
end;

{ the menu's items made from data (Tag 1) taken away; the fixed ones stay }
procedure ClearDataItems(Menu: TMenuItem);
var
  I: Integer;
begin
  for I := Menu.Count - 1 downto 0 do
    if Menu[I].Tag = 1 then Menu[I].Free;
end;

{ an item made from data: of action A; a separator without one }
function DataItem(Parent: TMenuItem; A: TBasicAction): TMenuItem;
begin
  Result := TMenuItem.Create(Parent);
  Result.Tag := 1;
  if A <> nil then Result.Action := A else Result.Caption := '-';
  Parent.Add(Result);
end;

{ a submenu made from data }
function DataSubmenu(Parent: TMenuItem; const ACaption: string; AEnabled: Boolean): TMenuItem;
begin
  Result := TMenuItem.Create(Parent);
  Result.Tag := 1;
  Result.Caption := ACaption;
  Result.Enabled := AEnabled;
  Parent.Add(Result);
end;

{ the local branches (the current one checked) to switch to, the remote ones to track, New Branch and
  the branches to delete }
procedure TGitChangesView.BranchMenuPopup(Sender: TObject);
var
  I: Integer;
  B: TGitBranch;
  Remote, Delete: TMenuItem;
  A: TAction;
  Free: Boolean;
begin
  ClearDataItems(BranchMenu.Items);
  ClearListActions;
  Free := not Host.Changing and (Host.Repo <> nil);
  for I := 0 to Host.Branches.Count - 1 do
  begin
    B := TGitBranch(Host.Branches[I]);
    if B.Remote then Continue;
    A := ListAction(B.Name, Utf8ToIde(B.Name), SwitchClick);
    A.Checked := B.Current;
    A.Enabled := Free and not B.Current;
    DataItem(BranchMenu.Items, A).RadioItem := True;
  end;
  Remote := nil;
  for I := 0 to Host.Branches.Count - 1 do
  begin
    B := TGitBranch(Host.Branches[I]);
    if not B.Remote then Continue;
    if Remote = nil then
    begin
      DataItem(BranchMenu.Items, nil);
      Remote := DataSubmenu(BranchMenu.Items, '&Remote Branches', Free);
    end;
    DataItem(Remote, ListAction(B.Name, Utf8ToIde(B.Name), SwitchRemoteClick));
  end;
  DataItem(BranchMenu.Items, nil);
  DataItem(BranchMenu.Items, aNewBranch);
  Delete := nil;
  for I := 0 to Host.Branches.Count - 1 do
  begin
    B := TGitBranch(Host.Branches[I]);
    if B.Remote or B.Current then Continue;
    if Delete = nil then Delete := DataSubmenu(BranchMenu.Items, '&Delete Branch', Free);
    DataItem(Delete, ListAction(B.Name, Utf8ToIde(B.Name), DeleteBranchClick));
  end;
end;

{ Stash Changes, Pop Latest Stash, and the stashes to apply or to drop }
procedure TGitChangesView.StashMenuPopup(Sender: TObject);
var
  I: Integer;
  S: TGitStash;
  Apply, Drop: TMenuItem;
  Cap: string;
begin
  ClearDataItems(StashMenu.Items);
  ClearListActions;
  DataItem(StashMenu.Items, aStashSave);
  DataItem(StashMenu.Items, aStashPop);
  if Host.Stashes.Count = 0 then Exit;
  DataItem(StashMenu.Items, nil);
  Apply := DataSubmenu(StashMenu.Items, '&Apply', not Host.Changing and (Host.Repo <> nil));
  Drop := DataSubmenu(StashMenu.Items, '&Drop', Apply.Enabled);
  for I := 0 to Host.Stashes.Count - 1 do
  begin
    S := TGitStash(Host.Stashes[I]);
    Cap := Utf8ToIde(S.Ref + ':  ' + S.Message);
    DataItem(Apply, ListAction(S.Ref, Cap, StashApplyClick));
    DataItem(Drop, ListAction(S.Ref, Cap, StashDropClick));
  end;
end;

procedure TGitChangesView.SwitchClick(Sender: TObject);
var
  Name: string;
begin
  Name := ListName(Sender);
  if (Name <> '') and Host.SaveFiles(GitSwitchWhy) then Host.Switch(Name, False);
end;

{ a remote branch: a local branch of its name when there is one, else a new one that tracks it }
procedure TGitChangesView.SwitchRemoteClick(Sender: TObject);
var
  Name, Local: string;
begin
  Name := ListName(Sender);
  if (Name = '') or not Host.SaveFiles(GitSwitchWhy) then Exit;
  Local := Copy(Name, Pos('/', Name) + 1, MaxInt);
  if Host.FindBranch(Local, False) <> nil then Host.Switch(Local, False)
  else Host.Switch(Name, True);
end;

procedure TGitChangesView.DeleteBranchClick(Sender: TObject);
var
  Name: string;
begin
  Name := ListName(Sender);
  if Name = '' then Exit;
  if GitConfirm(Format('Delete the branch %s?', [Utf8ToIde(Name)]), MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2) <> IDYES then Exit;
  Host.DeleteBranch(Name, False, Self, DeleteBranchDone);
end;

{ a branch that is not merged is deleted only when the user says so once more }
procedure TGitChangesView.DeleteBranchDone(Task: TGitTask);
begin
  if Task.Error = '' then Exit;
  if Pos('not fully merged', Task.Error) > 0 then
  begin
    if GitConfirm(Task.Error + #13#10#13#10'Delete it anyway? Its commits that no other branch has are lost.',
      MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) = IDYES then Host.DeleteBranch(Task.Text, True, nil, nil);
  end
  else GitFail(Task.Error);
end;

procedure TGitChangesView.StashApplyClick(Sender: TObject);
var
  Ref: string;
begin
  Ref := ListName(Sender);
  if (Ref <> '') and Host.SaveFiles('Applying a stash changes files of the work tree.') then Host.StashApply(Ref);
end;

procedure TGitChangesView.StashDropClick(Sender: TObject);
var
  Ref: string;
begin
  Ref := ListName(Sender);
  if (Ref <> '') and (GitConfirm(Format('Drop %s? Its changes are lost.', [Ref]), MB_YESNO or MB_ICONWARNING or
    MB_DEFBUTTON2) = IDYES) then Host.StashDrop(Ref);
end;

end.
