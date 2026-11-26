{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitHistory;

{ The Git History view: the commits of the repository - of the current branch, or of every branch and
  tag - or of one file (its renames followed), newest first, with the chosen commit's message and
  files. A dockable tool window (DockForm.TDockableForm) laid out as a view of D7 Studio (GitUI): its
  tool bar - Refresh, All Branches, Whole Repository, Copy Commit Id - in IntelliJ's images,
  what is shown on its right; the commits (message, author, date, commit) in a flat frame, under them
  the commit's message and its files in flat frames; the status line at the foot of D7 Studio's view,
  else the window's own.
  * Double click: a commit's changes - in a file's history the file's, under the name it had in that
    commit -, or a file's changes in the commit (GitDiff).
  * The history is read in pages of PageSize commits; "More ..." at the end reads the next page.
  * It is read again when the repository's HEAD moves (a commit, a switch, a pull) while it shows -
    with All Branches also when a branch moves. }

interface

uses
  Windows, Messages, SysUtils, Classes, Contnrs, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ToolWin, ImgList, Menus, ActnList, DockForm, GitCore, GitHost;

const
  GitHistorySection = 'GitHistoryView';
  PageSize = 200;

type
  TGitHistoryView = class(TDockableForm)
    TopBar: TPanel;
    HistBar: TToolBar;
    RefreshButton: TToolButton;
    Sep1: TToolButton;
    AllButton: TToolButton;
    RepoButton: TToolButton;
    Sep2: TToolButton;
    CopyButton: TToolButton;
    ScopeLabel: TLabel;
    ListPanel: TPanel;
    CommitList: TListView;
    Splitter: TSplitter;
    DetailPanel: TPanel;
    InfoPanel: TPanel;
    InfoMemo: TMemo;
    Gap: TPanel;
    FilesList: TListBox;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    Actions: TActionList;
    aRefresh: TAction;
    aAllBranches: TAction;
    aRepository: TAction;
    aCopyId: TAction;
    aShowCommit: TAction;
    aCopyMessage: TAction;
    aNewBranchHere: TAction;
    aShowFile: TAction;
    aOpenFile: TAction;
    Icons: TImageList;
    IconsDisabled: TImageList;
    CommitMenu: TPopupMenu;
    miShowCommit: TMenuItem;
    miCopyId: TMenuItem;
    miCopyMessage: TMenuItem;
    miSep1: TMenuItem;
    miNewBranchHere: TMenuItem;
    FilesMenu: TPopupMenu;
    miShowFile: TMenuItem;
    miOpenFile: TMenuItem;
    procedure aRefreshExecute(Sender: TObject);
    procedure aRefreshUpdate(Sender: TObject);
    procedure aAllBranchesExecute(Sender: TObject);
    procedure aRepositoryExecute(Sender: TObject);
    procedure aRepositoryUpdate(Sender: TObject);
    procedure aCopyIdExecute(Sender: TObject);
    procedure CommitCommandUpdate(Sender: TObject);
    procedure aShowCommitExecute(Sender: TObject);
    procedure aCopyMessageExecute(Sender: TObject);
    procedure aNewBranchHereExecute(Sender: TObject);
    procedure aShowFileExecute(Sender: TObject);
    procedure aShowFileUpdate(Sender: TObject);
    procedure aOpenFileExecute(Sender: TObject);
    procedure TopBarResize(Sender: TObject);
    procedure ListPanelResize(Sender: TObject);
    procedure CommitListData(Sender: TObject; Item: TListItem);
    procedure CommitListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure CommitListDblClick(Sender: TObject);
    procedure CommitListCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure FilesListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure FilesListDblClick(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FCommits: TObjectList;       // TGitCommit, newest first
    FMore: Boolean;              // the last page was full: there may be more
    FPath: string;               // the file whose history is shown; '' the repository's
    FAll: Boolean;
    FTag: Integer;
    FInfoTag: Integer;
    FLoading: Boolean;
    FLoadedHead: string;         // HEAD when the history was read
    FLoadedRoot: string;
    FLoadedRefs: string;         // with All Branches: the branches and their commits then
    FFiles: TObjectList;         // TGitFileChange of the commit shown below
    FInfoId: string;             // the commit shown below; '' none
    FRequestedId: string;        // the commit whose details are being read
    FMessage: string;            // its message (UTF-8)
    FScopeText, FScopeHint: string;
    procedure InitLook;
    procedure HostChanged(Sender: TObject);
    procedure UpdateStatus;
    procedure UpdateScope;
    procedure Reload;
    procedure LoadMore;
    procedure ClearDetails;
    { the details of the selected commit read, unless they show or are being read }
    procedure LoadDetails;
    procedure LogDone(Task: TGitTask);
    procedure CommitDone(Task: TGitTask);
    function SelectedCommit: TGitCommit;
    function SelectedFile: TGitFileChange;
    function RefsKey: string;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the history of the file Path (a repository path), or of the repository when Path is '' }
    procedure ShowHistory(const Path: string);
    property Commits: TObjectList read FCommits;
    property Files: TObjectList read FFiles;
    property Loading: Boolean read FLoading;
  end;

var
  GitHistoryForm: TGitHistoryView;

procedure RegisterGitHistoryView;
procedure UnregisterGitHistoryView;
procedure ShowGitHistory(const Path: string);

implementation

{$R *.dfm}

uses
  ToolsAPI, DeskUtil, Clipbrd, GitText, GitUI, GitIde, GitViews, GitDiff, GitBranchDlg;

const
  { the commands' images (GitIcons.bmp's cells), in the order of the actions' ImageIndex in the .dfm }
  IconCells: array[0..5] of Integer = (giRefresh, giAllBranches, giRepository, giCopy, giDiff, giOpenFile);

procedure RegisterGitHistoryView;
begin
  RegisterView(TGitHistoryView, GitHistorySection, @GitHistoryForm);
end;

procedure UnregisterGitHistoryView;
begin
  UnregisterView(GitHistoryForm);
end;

procedure ShowGitHistory(const Path: string);
begin
  if GitHistoryForm = nil then GitHistoryForm := TGitHistoryView.Create(nil);
  GitHistoryForm.ShowHistory(Path);
  FocusWindow(GitHistoryForm);
end;

{ ---------------------------------------------------------------- TGitHistoryView }

constructor TGitHistoryView.Create(AOwner: TComponent);
begin
  inherited;
  DeskSection := GitHistorySection;
  AutoSave := True;
  FCommits := TObjectList.Create(True);
  FFiles := TObjectList.Create(True);
  InitLook;
  GitHostInstance.AddListener(HostChanged);
end;

destructor TGitHistoryView.Destroy;
begin
  ViewGoes(Self, HostChanged);
  FFiles.Free;
  FCommits.Free;
  inherited;
end;

procedure TGitHistoryView.InitLook;
begin
  KitUseIdeFont(Self);
  KitBitmapIcons(Actions, [HistBar], [CommitMenu, FilesMenu], GitIconsResource, IconCells, Icons, IconsDisabled);
  KitFlatToolBar(HistBar);
  KitFlatFrame(ListPanel);
  KitFlatFrame(InfoPanel);
  KitFlatFrame(FilesList);
  FilesList.Canvas.Font := FilesList.Font;
  FilesList.ItemHeight := FilesList.Canvas.TextHeight('Ag') + 4;
  FilesList.DoubleBuffered := True;
  RepaintOnWidthChange(FilesList);
end;

procedure TGitHistoryView.CreateWnd;
begin
  inherited;
  if FCommits <> nil then UpdateStatus;
end;

{ while it shows, changes of the work tree are read (GitHost), so a commit made elsewhere moves HEAD
  and reads the history again }
procedure TGitHistoryView.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if FCommits = nil then Exit;
  GitHostInstance.ViewShowing(Showing);
  if Showing then HostChanged(nil);
end;

procedure TGitHistoryView.UpdateStatus;
var
  S: string;
begin
  if GitHostInstance.Repo = nil then S := 'No repository'
  else if FLoading then S := 'Reading the history ...'
  else if FCommits.Count = 0 then S := 'No commits'
  else if FCommits.Count = 1 then S := '1 commit'
  else if FMore then S := Format('%d commits shown', [FCommits.Count])
  else S := Format('%d commits', [FCommits.Count]);
  ShowViewStatus(Self, StatusPanel, StatusLabel, S);
end;

procedure TGitHistoryView.UpdateScope;
begin
  if FPath <> '' then FScopeText := Utf8ToIde(PathName(FPath)) + GitDot + 'file'
  else if FAll then FScopeText := 'All branches'
  else if GitHostInstance.Status.Branch <> '' then FScopeText := Utf8ToIde(GitHostInstance.Status.Branch)
  else FScopeText := 'HEAD';
  { a file's history: its whole path in the hint }
  FScopeHint := PathText(FPath);
  KitLayoutBarLabel(ScopeLabel, HistBar, FScopeText, '', FScopeHint);
end;

procedure TGitHistoryView.TopBarResize(Sender: TObject);
begin
  KitLayoutBarLabel(ScopeLabel, HistBar, FScopeText, '', FScopeHint);
end;

{ the message's column takes what the others leave }
procedure TGitHistoryView.ListPanelResize(Sender: TObject);
var
  W: Integer;
begin
  if CommitList.Columns.Count < 4 then Exit;
  W := CommitList.ClientWidth - CommitList.Columns[1].Width - CommitList.Columns[2].Width -
    CommitList.Columns[3].Width - 2;
  if W < 80 then W := 80;
  CommitList.Columns[0].Width := W;
end;

{ every branch and its commit: what All Branches shows moves when it changes }
function TGitHistoryView.RefsKey: string;
var
  I: Integer;
  B: TGitBranch;
begin
  Result := '';
  if not FAll then Exit;
  for I := 0 to GitHostInstance.Branches.Count - 1 do
  begin
    B := TGitBranch(GitHostInstance.Branches[I]);
    Result := Result + B.Name + #1 + B.Commit + #2;
  end;
end;

{ read again when HEAD moved, a branch with All Branches, or the repository is another; the scope's
  text follows the branch }
procedure TGitHistoryView.HostChanged(Sender: TObject);
var
  H: TGitHost;
  Root: string;
begin
  H := GitHostInstance;
  if H.Repo <> nil then Root := H.Repo.Root else Root := '';
  UpdateScope;
  if Showing and not FLoading and ((Root <> FLoadedRoot) or (H.Status.Head <> FLoadedHead) or
    (RefsKey <> FLoadedRefs)) then Reload
  else UpdateStatus;
end;

procedure TGitHistoryView.ShowHistory(const Path: string);
begin
  FPath := Path;
  UpdateScope;
  Reload;
end;

procedure TGitHistoryView.ClearDetails;
begin
  Inc(FInfoTag);
  FFiles.Clear;
  FInfoId := '';
  FRequestedId := '';
  FMessage := '';
  InfoMemo.Clear;
  FilesList.Count := 0;
  FilesList.Invalidate;
end;

procedure TGitHistoryView.Reload;
var
  H: TGitHost;
begin
  H := GitHostInstance;
  Inc(FTag);
  ClearDetails;
  FCommits.Clear;
  FMore := False;
  CommitList.Items.Count := 0;
  CommitList.Invalidate;
  FLoading := H.Repo <> nil;
  if FLoading then
  begin
    FLoadedRoot := H.Repo.Root;
    FLoadedHead := H.Status.Head;
    FLoadedRefs := RefsKey;
    H.LoadLog(Self, FTag, FPath, FAll, 0, PageSize, LogDone);
  end
  else
  begin
    FLoadedRoot := '';
    FLoadedHead := '';
    FLoadedRefs := '';
  end;
  UpdateStatus;
end;

procedure TGitHistoryView.LoadMore;
begin
  if FLoading or not FMore or (GitHostInstance.Repo = nil) then Exit;
  FLoading := True;
  UpdateStatus;
  GitHostInstance.LoadLog(Self, FTag, FPath, FAll, FCommits.Count, PageSize, LogDone);
end;

procedure TGitHistoryView.LogDone(Task: TGitTask);
var
  I: Integer;
  First: Boolean;
begin
  if Task.Tag <> FTag then Exit;
  FLoading := False;
  First := FCommits.Count = 0;
  if (Task.Error = '') and (Task.List <> nil) then
  begin
    { the commits move over to the view }
    Task.List.OwnsObjects := False;
    for I := 0 to Task.List.Count - 1 do FCommits.Add(Task.List[I]);
    FMore := Task.List.Count >= PageSize;
  end
  else FMore := False;
  CommitList.Items.Count := FCommits.Count + Ord(FMore);
  CommitList.Invalidate;
  ListPanelResize(nil);
  if First and (FCommits.Count > 0) then
  begin
    CommitList.ItemIndex := 0;
    if CommitList.Selected <> nil then CommitList.Selected.Focused := True;
  end;
  { after More ... the selected row is a commit of the new page: no select event says so }
  LoadDetails;
  UpdateStatus;
end;

procedure TGitHistoryView.CommitListData(Sender: TObject; Item: TListItem);
var
  C: TGitCommit;
  S: string;
begin
  if Item.Index >= FCommits.Count then
  begin
    Item.Caption := 'More ...';
    Exit;
  end;
  C := TGitCommit(FCommits[Item.Index]);
  S := C.Subject;
  if C.Refs <> '' then S := '(' + C.Refs + ')  ' + S;
  Item.Caption := Utf8ToIde(S);
  Item.SubItems.Add(Utf8ToIde(C.Author));
  Item.SubItems.Add(GitTimeText(C.Time));
  Item.SubItems.Add(C.ShortId);
end;

procedure TGitHistoryView.CommitListCustomDrawItem(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  if Item.Index >= FCommits.Count then Sender.Canvas.Font.Color := clGrayText;
  DefaultDraw := True;
end;

function TGitHistoryView.SelectedCommit: TGitCommit;
var
  I: Integer;
begin
  I := CommitList.ItemIndex;
  if (I >= 0) and (I < FCommits.Count) then Result := TGitCommit(FCommits[I]) else Result := nil;
end;

function TGitHistoryView.SelectedFile: TGitFileChange;
var
  I: Integer;
begin
  I := FilesList.ItemIndex;
  if (I >= 0) and (I < FFiles.Count) then Result := TGitFileChange(FFiles[I]) else Result := nil;
end;

procedure TGitHistoryView.CommitListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then LoadDetails;
end;

procedure TGitHistoryView.LoadDetails;
var
  C: TGitCommit;
begin
  C := SelectedCommit;
  if (C = nil) or (C.Id = FInfoId) or (C.Id = FRequestedId) then Exit;
  { what shows below is another commit's until the answer comes: nothing shows }
  ClearDetails;
  FRequestedId := C.Id;
  GitHostInstance.LoadCommit(Self, FInfoTag, C.Id, CommitDone);
end;

{ the commit's message under the list, its files beside it }
procedure TGitHistoryView.CommitDone(Task: TGitTask);
var
  S: string;
begin
  if Task.Tag <> FInfoTag then Exit;
  FRequestedId := '';
  FFiles.Clear;
  FMessage := '';
  if Task.Error = '' then
  begin
    FInfoId := Task.Text;
    { the message first - the list has the author and the date -, then the commit's details }
    FMessage := Task.Info;
    S := Task.Info + #10#10 + 'Commit ' + Task.Text + #10 + Task.Text2 + '  ' + #$C2#$B7 + '  ' +
      GitTimeText(Task.Time);
    if Task.Bytes <> '' then S := S + #10 + Task.Bytes;
    InfoMemo.Text := Utf8ToIde(NormalizeNewLines(S, #13#10));
    if Task.List <> nil then
    begin
      FFiles.Free;
      FFiles := Task.List;
      Task.List := nil;
    end;
  end
  else
  begin
    FInfoId := '';
    InfoMemo.Clear;
  end;
  FilesList.Count := FFiles.Count;
  FilesList.Invalidate;
end;

procedure TGitHistoryView.CommitListDblClick(Sender: TObject);
begin
  if (CommitList.ItemIndex >= FCommits.Count) and FMore then LoadMore
  else aShowCommit.Execute;
end;

procedure TGitHistoryView.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key <> VK_RETURN then Exit;
  Key := 0;
  if Sender = FilesList then FilesListDblClick(nil) else CommitListDblClick(nil);
end;

procedure TGitHistoryView.FilesListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  F: TGitFileChange;
begin
  if (Index < 0) or (Index >= FFiles.Count) then Exit;
  F := TGitFileChange(FFiles[Index]);
  DrawFileRow(FilesList.Canvas, Rect, 2, F.State, F.Path, F.OrigPath, odSelected in State);
end;

procedure TGitHistoryView.FilesListDblClick(Sender: TObject);
begin
  aShowFile.Execute;
end;

{ ---------------------------------------------------------------- commands }

procedure TGitHistoryView.aRefreshUpdate(Sender: TObject);
begin
  aRefresh.Enabled := GitHostInstance.Repo <> nil;
  aAllBranches.Checked := FAll;
end;

procedure TGitHistoryView.aRefreshExecute(Sender: TObject);
begin
  Reload;
end;

procedure TGitHistoryView.aAllBranchesExecute(Sender: TObject);
begin
  FAll := not FAll;
  aAllBranches.Checked := FAll;
  UpdateScope;
  Reload;
end;

procedure TGitHistoryView.aRepositoryUpdate(Sender: TObject);
begin
  aRepository.Enabled := FPath <> '';
end;

procedure TGitHistoryView.aRepositoryExecute(Sender: TObject);
begin
  ShowHistory('');
end;

procedure TGitHistoryView.CommitCommandUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := SelectedCommit <> nil;
end;

procedure TGitHistoryView.aCopyIdExecute(Sender: TObject);
begin
  if SelectedCommit <> nil then Clipboard.AsText := SelectedCommit.Id;
end;

procedure TGitHistoryView.aCopyMessageExecute(Sender: TObject);
var
  C: TGitCommit;
begin
  C := SelectedCommit;
  if C = nil then Exit;
  { the whole message when it shows below, else the subject }
  if (C.Id = FInfoId) and (FMessage <> '') then Clipboard.AsText := Utf8ToIde(NormalizeNewLines(FMessage, #13#10))
  else Clipboard.AsText := Utf8ToIde(C.Subject);
end;

{ a commit's changes: of the file whose history is shown - under its name in that commit -, else all
  of them }
procedure TGitHistoryView.aShowCommitExecute(Sender: TObject);
var
  C: TGitCommit;
begin
  C := SelectedCommit;
  if C = nil then Exit;
  if FPath = '' then ShowGitDiff(gkCommit, '', '', C.Id, '', C.ShortId)
  else if C.Path <> '' then ShowGitDiff(gkCommit, C.Path, C.OrigPath, C.Id, '', C.ShortId)
  else ShowGitDiff(gkCommit, FPath, '', C.Id, '', C.ShortId);
end;

procedure TGitHistoryView.aNewBranchHereExecute(Sender: TObject);
begin
  if SelectedCommit <> nil then GitNewBranch(SelectedCommit.Id);
end;

procedure TGitHistoryView.aShowFileUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (SelectedFile <> nil) and (FInfoId <> '');
end;

procedure TGitHistoryView.aShowFileExecute(Sender: TObject);
var
  F: TGitFileChange;
begin
  F := SelectedFile;
  if (F <> nil) and (FInfoId <> '') then ShowGitDiff(gkCommit, F.Path, F.OrigPath, FInfoId, '', Copy(FInfoId, 1, 7));
end;

procedure TGitHistoryView.aOpenFileExecute(Sender: TObject);
var
  F: TGitFileChange;
  Name: string;
begin
  F := SelectedFile;
  if F = nil then Exit;
  Name := GitHostInstance.FileOf(F.Path);
  if (Name <> '') and FileExists(Name) then ShowFileAt(Name, 1, 1)
  else GitInform(Format('%s is not in the work tree any more.', [PathText(F.Path)]));
end;

end.
