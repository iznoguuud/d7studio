{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitHost;

{ The Git expert in the IDE: its settings, the repository of the active project, and the git commands
  run for the views, one at a time, in a worker thread.
  * The repository is the one whose work tree holds the active project's folder, else the folder of
    the file in the code editor. It is looked for again at every refresh: when a view shows, when the
    active project changes (ProjectChanged, which the expert's IDE notifier calls; with no view shown
    only when the project's folder is another one: FollowProject), when files change.
    A folder whose repository git refuses to open (a work tree of another user's, a damaged one) is not
    taken for one without a repository: RepoFailure says why.
  * A command is a task (TGitTask): its Proc runs in the worker thread with the task's own data and
    repository, its OnDone in the IDE's main thread. A task that changed the repository reads the
    status again; a fetch or a push may be stopped. Failures are shown in a message box (GitFail).
    A view's read that waits is dropped when the view asks for another one of its kind.
  * The views follow the host (AddListener): its status, branches and stashes, and whether a task runs.
    A refresh that fails keeps what was read before and says why (StatusFailure).
  * Files: before a commit or a command that rewrites the work tree, the IDE's files of the work tree
    with unsaved changes are saved when the user agrees (SaveFiles); after a command that rewrote it,
    the open modules one of whose files changed on disk - the unit, its form - are read again
    (IOTAActionServices.ReloadFile). A module with unsaved changes keeps them, and the user is told so;
    so is a project whose options changed on disk.
  * Refresh: the work tree is watched in a thread of its own (a change notification); a change, or
    the IDE becoming the active program, reads the status again - while a view shows it, else when the
    next one does. A change seen before a refresh started is in what that refresh reads.
  * When the host goes (the package unloaded, the IDE closing), a command that only reads, a fetch, a
    pull and a push are stopped (TGit.ReadStop, TGitTask.Cancelled); a command that writes the
    repository is waited for.
  Settings: HKEY_CURRENT_USER\<the IDE's registry key>\Git - GitPath (git.exe; empty: found on the
  PATH or in Git for Windows' folder), AutoRefresh (1/0). }

interface

uses
  Windows, Messages, SysUtils, Classes, Contnrs, Forms, ToolsAPI, GitText, GitCore;

const
  GitSettingsSubKey = 'Git';

type
  TGitTask = class;
  { a task's work in the worker thread; its end in the main thread }
  TGitTaskProc = procedure(Task: TGitTask) of object;
  TGitTaskEvent = procedure(Task: TGitTask) of object;

  TGitTask = class
  private
    FCancelled: Boolean;
  public
    Title: string;            // the status line while it runs: 'Pulling ...'
    Proc: TGitTaskProc;
    OnDone: TGitTaskEvent;
    Owner: TObject;           // the view that asked: its OnDone is dropped when it goes
    Tag: Integer;             // the view's number of the request: an answer to an older one is dropped
    Repo: TGitRepo;           // the repository it runs in (set when it starts)
    { what it is given }
    Paths: TStringList;       // repository paths (UTF-8)
    Paths2: TStringList;
    Text, Text2: string;      // a message, a branch, a commit, a start point ... (UTF-8)
    Bytes: string;            // a file as the editor holds it
    Flag, Flag2: Boolean;
    Number, Number2: Integer;
    Stoppable: Boolean;       // a fetch, a push: the user may stop it
    NoRepo: Boolean;          // it runs without a repository (a refresh, a new repository)
    IsRefresh: Boolean;
    Changes: Boolean;         // it changes the repository: the status is read again after it
    RewritesTree: Boolean;    // it may change files of the work tree: open files read again after it
    Silent: Boolean;          // a failure is not shown
    Supersedes: Boolean;      // a view's read: one of the same view and kind that waits is dropped
    DropUnsaved: Boolean;     // after it, changed modules are read again also with unsaved changes
    { what it gives back }
    Error: string;            // the failure (IDE string); '' when it worked
    Status: TGitStatus;
    List, List2: TObjectList;
    Diff: TGitDiff;
    Blame: TGitBlame;
    Info: string;
    Time: Int64;
    Found: TGitRepo;          // a refresh: the repository found (nil: none)
    RepoState: TGitRepoState;
    constructor Create;
    destructor Destroy; override;
    { asked by git's process while it runs (TKitCancelQuery) }
    function Cancelled: Boolean;
  end;

  TGitHost = class
  private
    FGit: TGit;
    FGitExe: WideString;
    FGitChecked: Boolean;
    FGitStale: Boolean;
    FRepo: TGitRepo;
    FRepoFailure: string;
    FStatus: TGitStatus;
    FStatusFailure: string;
    FBranches: TObjectList;
    FStashes: TObjectList;
    FState: TGitRepoState;
    FListeners: TList;          // PMethod of TNotifyEvent
    FQueue: TList;
    FRunning: TGitTask;
    FWorker: TThread;
    FWnd: HWND;
    FWatcher: TThread;
    FWatched: string;
    FShowing: Integer;
    FDirty: Boolean;
    FFolder: string;            // the folder the repository was last looked for in (UTF-8)
    FRefreshQueued: Boolean;
    FRefreshStart: Cardinal;    // GetTickCount when the last refresh started
    FSnapModules: TStringList;  // the modules of the work tree before a command that rewrites it
    FSnapFiles, FSnapStamps: TStringList;
    FLastSaved: Integer;
    FClosing: Boolean;
    FKey: string;
    procedure WndProc(var Message: TMessage);
    procedure CheckGit;
    function StopReading: Boolean;
    procedure StartNext;
    procedure TaskDone;
    procedure Changed;
    procedure FileChanged;
    procedure FollowProject;
    procedure RefreshDone(Task: TGitTask);
    procedure StartWatcher;
    procedure Snapshot;
    procedure ReloadChanged(DropUnsaved: Boolean);
    function NewTask(const ATitle: string; AProc: TGitTaskProc): TGitTask;
    { a view's read: its answer goes to OnDone, a newer one of the view drops it when it waits }
    function NewRead(const ATitle: string; AProc: TGitTaskProc; AOwner: TObject; ATag: Integer;
      AOnDone: TGitTaskEvent): TGitTask;
    { the work, in the worker thread }
    procedure DoRefresh(Task: TGitTask);
    procedure DoStage(Task: TGitTask);
    procedure DoUnstage(Task: TGitTask);
    procedure DoDiscard(Task: TGitTask);
    procedure DoCommit(Task: TGitTask);
    procedure DoFetch(Task: TGitTask);
    procedure DoPull(Task: TGitTask);
    procedure DoPush(Task: TGitTask);
    procedure DoSwitch(Task: TGitTask);
    procedure DoCreateBranch(Task: TGitTask);
    procedure DoDeleteBranch(Task: TGitTask);
    procedure DoStash(Task: TGitTask);
    procedure DoAbort(Task: TGitTask);
    procedure DoInit(Task: TGitTask);
    procedure DoLog(Task: TGitTask);
    procedure DoCommitInfo(Task: TGitTask);
    procedure DoDiff(Task: TGitTask);
    procedure DoBlame(Task: TGitTask);
    procedure DoLastMessage(Task: TGitTask);
  public
    constructor Create;
    destructor Destroy; override;
    { settings }
    function ReadSetting(const Name, Default: string): string;
    procedure WriteSetting(const Name, Value: string);
    { the settings changed: git.exe is looked for again, the watching of the work tree follows }
    procedure SettingsChanged;
    function GitExe: WideString;
    function GitFound: Boolean;
    function Git: TGit;
    { the folder whose repository the views show: the active project's, else the code editor's file's
      (UTF-8, no '\' at the end; '' none) }
    function ProjectFolder: string;
    { the repository for the active project looked for again, then its status read }
    procedure Refresh;
    { a refresh waits or runs }
    function RefreshPending: Boolean;
    { a project opens or closes, another becomes the active one (the IDE's notification): a refresh
      a moment later }
    procedure ProjectChanged;
    { the active project's repository opened now (git rev-parse, in this thread) when the host has none
      yet - for a command of the editor before any view showed; its status follows }
    function EnsureRepo: Boolean;
    { the status read now, in this thread (a commit right after files were saved); False when it
      cannot be read }
    function ReadStatus(Status: TGitStatus): Boolean;
    { a view shows (True) or hides: a change seen meanwhile is read when one shows }
    procedure ViewShowing(Shown: Boolean);
    procedure AddListener(E: TNotifyEvent);
    procedure RemoveListener(E: TNotifyEvent);
    { a view goes: the answers of its tasks are dropped }
    procedure ForgetOwner(Owner: TObject);
    { queues Task (the host owns it from here) }
    procedure Run(Task: TGitTask);
    { the fetch or push that runs stopped }
    procedure CancelRunning;
    function Busy: Boolean;
    function BusyTitle: string;
    function CanCancel: Boolean;
    { a command that changes the repository runs or waits: the views' commands wait for it }
    function Changing: Boolean;
    { an IDE file name of a repository path, and the repository path of an IDE file name ('' outside) }
    function FileOf(const Path: string): string;
    function PathOf(const FileName: string): string;
    { the branch called Name (UTF-8), local or remote; nil when there is none }
    function FindBranch(const Name: string; Remote: Boolean): TGitBranch;
    { the IDE's files of the work tree with unsaved changes saved when the user agrees (Why: what is
      about to happen); False when the user cancels or a file could not be saved. LastSaved: how
      many were saved }
    function SaveFiles(const Why: string): Boolean;
    { the open modules with unsaved changes one of whose files is among Paths (repository paths): their
      file names in L }
    procedure UnsavedModules(Paths, L: TStrings);
    { the commands: each a task }
    procedure Stage(Paths: TStrings);
    procedure Unstage(Paths: TStrings);
    { Tracked: their changes undone - also the IDE's unsaved ones: their modules are read again;
      Untracked: deleted }
    procedure Discard(Tracked, Untracked: TStrings);
    procedure Commit(const Message: string; Amend, StageTracked: Boolean; Owner: TObject; OnDone: TGitTaskEvent);
    procedure Fetch;
    procedure Pull;
    procedure Push(const Remote: string);
    procedure Switch(const Branch: string; Remote: Boolean);
    procedure CreateBranch(const Name, StartPoint: string; SwitchTo: Boolean);
    { a failure goes to OnDone, not into a message box, when OnDone is given }
    procedure DeleteBranch(const Name: string; Force: Boolean; Owner: TObject; OnDone: TGitTaskEvent);
    procedure StashPush(const Message: string; Untracked: Boolean);
    procedure StashPop;
    procedure StashApply(const Ref: string);
    procedure StashDrop(const Ref: string);
    procedure AbortOperation;
    procedure InitRepository;
    { what the views read; the answer is in the task handed to OnDone }
    procedure LoadLog(Owner: TObject; Tag: Integer; const Path: string; AllBranches: Boolean; Skip, Max: Integer;
      OnDone: TGitTaskEvent);
    procedure LoadCommit(Owner: TObject; Tag: Integer; const Id: string; OnDone: TGitTaskEvent);
    { Kind (GitDiff's gk...): 0 the work tree against the index, 1 the index against HEAD (OrigPath:
      a staged rename's source), 2 an untracked file, 3 a commit (Id; Path '' all its files), 4 HEAD
      against Bytes, 5 the work tree against HEAD (a file with a conflict) }
    procedure LoadDiff(Owner: TObject; Tag, Kind: Integer; const Path, OrigPath, Id, Bytes: string;
      OnDone: TGitTaskEvent);
    procedure LoadBlame(Owner: TObject; Tag: Integer; const Path, Bytes: string; HasBytes: Boolean;
      OnDone: TGitTaskEvent);
    procedure LoadLastMessage(Owner: TObject; OnDone: TGitTaskEvent);
    property Repo: TGitRepo read FRepo;
    { why git cannot open the repository of the project's folder (git's message); '' when there is
      one, or none at all }
    property RepoFailure: string read FRepoFailure;
    property Status: TGitStatus read FStatus;
    { why the last refresh could not read the status (what was read before stays); '' when it could }
    property StatusFailure: string read FStatusFailure;
    property Branches: TObjectList read FBranches;
    property Stashes: TObjectList read FStashes;
    property State: TGitRepoState read FState;
    property LastSaved: Integer read FLastSaved;
  end;

  TGitAskFunc = function(const Text: string; Buttons: Integer): Integer;
  TGitErrorProc = procedure(const Text: string);

var
  { the questions and the messages shown to the user (a self-test answers them itself) }
  GitAsk: TGitAskFunc;
  GitError: TGitErrorProc;

{ a question: MessageBox buttons and icon in Buttons, the button chosen }
function GitConfirm(const Text: string; Buttons: Integer): Integer;
{ a note, and a failure }
procedure GitInform(const Text: string);
procedure GitFail(const Text: string);

{ the host, made at the first call }
function GitHostInstance: TGitHost;
{ the host when there is one (nil after FreeGitHost): what a view that goes asks }
function GitHostIfAny: TGitHost;
procedure FreeGitHost;

implementation

uses
  GitIde;

const
  WM_GITTASKDONE = WM_APP + $4701;
  WM_GITCHANGED = WM_APP + $4702;     // LParam: GetTickCount when the change was seen
  ChangeTimer = 1;
  ChangeDelay = 800;           // ms of quiet before a change is read
  ProjectTimer = 2;
  ProjectDelay = 300;          // ms after the IDE told of a project opened, closed or made active

type
  PMethod = ^TMethod;

  TGitWorker = class(TThread)
  private
    FTask: TGitTask;
    FWnd: HWND;
  protected
    procedure Execute; override;
  end;

  { the work tree watched: a message to the host's window for every change }
  TGitWatcher = class(TThread)
  private
    FDir: WideString;
    FWnd: HWND;
    FStop: THandle;
  protected
    procedure Execute; override;
  public
    constructor Create(const ADir: WideString; AWnd: HWND);
    destructor Destroy; override;
  end;

var
  FHost: TGitHost;

function GitConfirm(const Text: string; Buttons: Integer): Integer;
begin
  if Assigned(GitAsk) then Result := GitAsk(Text, Buttons)
  else Result := Application.MessageBox(PChar(Text), 'Git', Buttons);
end;

procedure GitInform(const Text: string);
begin
  if Assigned(GitError) then GitError(Text)
  else Application.MessageBox(PChar(Text), 'Git', MB_OK or MB_ICONINFORMATION);
end;

procedure GitFail(const Text: string);
begin
  if Assigned(GitError) then GitError(Text)
  else Application.MessageBox(PChar(Text), 'Git', MB_OK or MB_ICONERROR);
end;

function GitHostInstance: TGitHost;
begin
  if FHost = nil then FHost := TGitHost.Create;
  Result := FHost;
end;

function GitHostIfAny: TGitHost;
begin
  Result := FHost;
end;

procedure FreeGitHost;
begin
  FreeAndNil(FHost);
end;

{ ---------------------------------------------------------------- TGitTask }

constructor TGitTask.Create;
begin
  inherited Create;
  Paths := TStringList.Create;
  Paths2 := TStringList.Create;
end;

destructor TGitTask.Destroy;
begin
  Found.Free;
  Status.Free;
  List.Free;
  List2.Free;
  Diff.Free;
  Blame.Free;
  Paths2.Free;
  Paths.Free;
  inherited;
end;

function TGitTask.Cancelled: Boolean;
begin
  Result := FCancelled;
end;

{ ---------------------------------------------------------------- threads }

procedure TGitWorker.Execute;
begin
  try
    FTask.Proc(FTask);
  except
    on E: Exception do
    begin
      FTask.Error := E.Message;
      if FTask.Error = '' then FTask.Error := E.ClassName;
    end;
  end;
  PostMessage(FWnd, WM_GITTASKDONE, 0, 0);
end;

constructor TGitWatcher.Create(const ADir: WideString; AWnd: HWND);
begin
  FDir := ADir;
  FWnd := AWnd;
  FStop := CreateEvent(nil, True, False, nil);
  inherited Create(False);
end;

destructor TGitWatcher.Destroy;
begin
  Terminate;
  SetEvent(FStop);
  inherited;          // waits for Execute to end
  CloseHandle(FStop);
end;

procedure TGitWatcher.Execute;
var
  H: THandle;
  Handles: array[0..1] of THandle;
begin
  H := FindFirstChangeNotificationW(PWideChar(FDir), True, FILE_NOTIFY_CHANGE_FILE_NAME or
    FILE_NOTIFY_CHANGE_DIR_NAME or FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_SIZE);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    Handles[0] := FStop;
    Handles[1] := H;
    while not Terminated do
      case WaitForMultipleObjects(2, @Handles[0], False, INFINITE) of
        WAIT_OBJECT_0 + 1:
          begin
            PostMessage(FWnd, WM_GITCHANGED, 0, LPARAM(GetTickCount));
            if not FindNextChangeNotification(H) then Break;
          end;
      else
        Break;
      end;
  finally
    FindCloseChangeNotification(H);
  end;
end;

{ ---------------------------------------------------------------- TGitHost }

constructor TGitHost.Create;
var
  Base: string;
begin
  inherited Create;
  FStatus := TGitStatus.Create;
  FBranches := TObjectList.Create(True);
  FStashes := TObjectList.Create(True);
  FListeners := TList.Create;
  FQueue := TList.Create;
  FSnapModules := TStringList.Create;
  FSnapFiles := TStringList.Create;
  FSnapStamps := TStringList.Create;
  FWnd := Classes.AllocateHWnd(WndProc);
  Base := '';
  if BorlandIDEServices <> nil then Base := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey;
  if Base = '' then Base := 'Software\D7GitExpert';
  if Base[1] = '\' then Delete(Base, 1, 1);
  FKey := IncludeTrailingPathDelimiter(Base) + GitSettingsSubKey;
end;

destructor TGitHost.Destroy;
var
  I: Integer;
begin
  { from here StopReading is True: a command that only reads ends at once }
  FClosing := True;
  FreeAndNil(FWatcher);
  if FRunning <> nil then
  begin
    { a fetch, pull or push is stopped too; a command that writes the repository ends on its own }
    FRunning.FCancelled := True;
    FWorker.WaitFor;
  end;
  FreeAndNil(FWorker);
  FreeAndNil(FRunning);
  for I := 0 to FQueue.Count - 1 do TGitTask(FQueue[I]).Free;
  FQueue.Free;
  KillTimer(FWnd, ChangeTimer);
  KillTimer(FWnd, ProjectTimer);
  Classes.DeallocateHWnd(FWnd);
  for I := 0 to FListeners.Count - 1 do Dispose(PMethod(FListeners[I]));
  FListeners.Free;
  FSnapStamps.Free;
  FSnapFiles.Free;
  FSnapModules.Free;
  FStashes.Free;
  FBranches.Free;
  FStatus.Free;
  FRepo.Free;
  FGit.Free;
  inherited;
end;

function TGitHost.ReadSetting(const Name, Default: string): string;
begin
  Result := KitReadRegString(FKey, Name, Default);
end;

procedure TGitHost.WriteSetting(const Name, Value: string);
begin
  KitWriteRegString(FKey, Name, Value);
end;

procedure TGitHost.CheckGit;
var
  Old: TGitRepo;
begin
  { a new path: the git of a task that runs stays until the task ends }
  if FGitStale and (FRunning = nil) then
  begin
    FreeAndNil(FGit);
    FGitChecked := False;
    FGitStale := False;
  end;
  if FGitChecked then Exit;
  FGitChecked := True;
  FGitExe := FindGitExe(CodePageToWide(ReadSetting('GitPath', ''), CP_ACP));
  if FGitExe <> '' then
  begin
    FGit := TGit.Create(FGitExe);
    FGit.ReadStop := StopReading;
  end;
  { the repository runs its commands with the git there is now (no task uses it here) }
  if FRepo <> nil then
  begin
    Old := FRepo;
    if FGit <> nil then FRepo := TGitRepo.Create(FGit, Old.Root, Old.GitDir) else FRepo := nil;
    Old.Free;
  end;
end;

function TGitHost.StopReading: Boolean;
begin
  Result := FClosing;
end;

procedure TGitHost.SettingsChanged;
begin
  FGitStale := True;
  { the watcher is made again at the end of the refresh, as the setting says }
  FWatched := #0;
  Refresh;
end;

function TGitHost.GitExe: WideString;
begin
  CheckGit;
  Result := FGitExe;
end;

function TGitHost.GitFound: Boolean;
begin
  CheckGit;
  Result := FGit <> nil;
end;

function TGitHost.Git: TGit;
begin
  CheckGit;
  Result := FGit;
end;

function TGitHost.ProjectFolder: string;
var
  P: IOTAProject;
  V: IOTAEditView;
  F: string;
begin
  F := '';
  try
    P := ActiveProject;
    if P <> nil then F := ExtractFileDir(P.FileName);
    if F = '' then
    begin
      V := TopView;
      if (V <> nil) and (V.Buffer <> nil) then F := ExtractFileDir(V.Buffer.FileName);
    end;
  except
    F := '';
  end;
  Result := IdeToUtf8(F);
end;

procedure TGitHost.AddListener(E: TNotifyEvent);
var
  P: PMethod;
begin
  New(P);
  P^ := TMethod(E);
  FListeners.Add(P);
end;

procedure TGitHost.RemoveListener(E: TNotifyEvent);
var
  I: Integer;
begin
  for I := FListeners.Count - 1 downto 0 do
    if (PMethod(FListeners[I]).Code = TMethod(E).Code) and (PMethod(FListeners[I]).Data = TMethod(E).Data) then
    begin
      Dispose(PMethod(FListeners[I]));
      FListeners.Delete(I);
    end;
end;

procedure TGitHost.Changed;
var
  I: Integer;
  E: TNotifyEvent;
begin
  if FClosing then Exit;
  for I := FListeners.Count - 1 downto 0 do
    if I < FListeners.Count then
    begin
      TMethod(E) := PMethod(FListeners[I])^;
      E(Self);
    end;
end;

procedure TGitHost.ForgetOwner(Owner: TObject);
var
  I: Integer;
begin
  if (FRunning <> nil) and (FRunning.Owner = Owner) then
  begin
    FRunning.OnDone := nil;
    FRunning.Owner := nil;
  end;
  for I := 0 to FQueue.Count - 1 do
    if TGitTask(FQueue[I]).Owner = Owner then
    begin
      TGitTask(FQueue[I]).OnDone := nil;
      TGitTask(FQueue[I]).Owner := nil;
    end;
end;

procedure TGitHost.ViewShowing(Shown: Boolean);
begin
  if Shown then Inc(FShowing) else Dec(FShowing);
  if FShowing < 0 then FShowing := 0;
  if Shown and FDirty then Refresh;
end;

function TGitHost.Busy: Boolean;
begin
  Result := FRunning <> nil;
end;

function TGitHost.BusyTitle: string;
begin
  if FRunning <> nil then Result := FRunning.Title else Result := '';
end;

function TGitHost.CanCancel: Boolean;
begin
  Result := (FRunning <> nil) and FRunning.Stoppable and not FRunning.FCancelled;
end;

procedure TGitHost.CancelRunning;
begin
  if CanCancel then FRunning.FCancelled := True;
end;

function TGitHost.Changing: Boolean;
var
  I: Integer;
begin
  Result := (FRunning <> nil) and FRunning.Changes;
  for I := 0 to FQueue.Count - 1 do
    if TGitTask(FQueue[I]).Changes then Result := True;
end;

function TGitHost.FileOf(const Path: string): string;
begin
  if FRepo = nil then Result := '' else Result := Utf8ToIde(FRepo.FullPath(Path));
end;

function TGitHost.PathOf(const FileName: string): string;
begin
  if FRepo = nil then Result := '' else Result := FRepo.RelativePath(IdeToUtf8(FileName));
end;

function TGitHost.FindBranch(const Name: string; Remote: Boolean): TGitBranch;
var
  I: Integer;
begin
  for I := 0 to FBranches.Count - 1 do
  begin
    Result := TGitBranch(FBranches[I]);
    if (Result.Remote = Remote) and (Result.Name = Name) then Exit;
  end;
  Result := nil;
end;

function TGitHost.NewTask(const ATitle: string; AProc: TGitTaskProc): TGitTask;
begin
  Result := TGitTask.Create;
  Result.Title := ATitle;
  Result.Proc := AProc;
end;

function TGitHost.NewRead(const ATitle: string; AProc: TGitTaskProc; AOwner: TObject; ATag: Integer;
  AOnDone: TGitTaskEvent): TGitTask;
begin
  Result := NewTask(ATitle, AProc);
  Result.Owner := AOwner;
  Result.Tag := ATag;
  Result.OnDone := AOnDone;
  Result.Supersedes := True;
end;

procedure TGitHost.Run(Task: TGitTask);
var
  I: Integer;
  T: TGitTask;
begin
  if FClosing then
  begin
    Task.Free;
    Exit;
  end;
  { the view asked again: its read of the same kind that waits is not wanted any more }
  if Task.Supersedes and (Task.Owner <> nil) then
    for I := FQueue.Count - 1 downto 0 do
    begin
      T := TGitTask(FQueue[I]);
      if (T.Owner = Task.Owner) and (TMethod(T.Proc).Code = TMethod(Task.Proc).Code) then
      begin
        T.Free;
        FQueue.Delete(I);
      end;
    end;
  FQueue.Add(Task);
  StartNext;
end;

procedure TGitHost.StartNext;
var
  T: TGitTask;
  W: TGitWorker;
begin
  if (FRunning <> nil) or (FQueue.Count = 0) or FClosing then Exit;
  T := TGitTask(FQueue[0]);
  FQueue.Delete(0);
  if T.IsRefresh then FRefreshQueued := False;
  CheckGit;
  if (FGit = nil) or ((FRepo = nil) and not T.NoRepo) then
  begin
    { nothing to run it with: its view gets the reason (the views say why there is nothing) }
    try
      if T.IsRefresh then RefreshDone(nil)
      else if Assigned(T.OnDone) then
      begin
        if FGit = nil then T.Error := 'git.exe was not found.' else T.Error := 'There is no repository.';
        T.OnDone(T);
      end;
    finally
      T.Free;
    end;
    Changed;
    StartNext;
    Exit;
  end;
  T.Repo := FRepo;
  if T.IsRefresh then
  begin
    { the project's folder now: a refresh queued while the IDE opened another project looks for that
      one's repository; the changes seen until now are in what it reads }
    T.Text := ProjectFolder;
    FRefreshStart := GetTickCount;
    KillTimer(FWnd, ChangeTimer);
  end;
  FRunning := T;
  if T.RewritesTree then Snapshot;
  W := TGitWorker.Create(True);
  W.FTask := T;
  W.FWnd := FWnd;
  FWorker := W;
  W.Resume;
  Changed;
end;

procedure TGitHost.TaskDone;
var
  T: TGitTask;
begin
  if FRunning = nil then Exit;
  FWorker.WaitFor;
  FreeAndNil(FWorker);
  T := FRunning;
  FRunning := nil;
  try
    if T.RewritesTree then ReloadChanged(T.DropUnsaved);
    { a task the user stopped ends without a message }
    if (T.Error <> '') and not T.Silent and not T.FCancelled and not FClosing then GitFail(T.Error);
    if Assigned(T.OnDone) then T.OnDone(T);
    if T.Changes then Refresh;
  finally
    T.Free;
  end;
  Changed;
  StartNext;
end;

procedure TGitHost.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_GITTASKDONE: TaskDone;
    WM_GITCHANGED:
      { a change seen before the last refresh started is in what it read; a burst of changes is read
        once, after a moment of quiet }
      if Integer(Cardinal(Message.LParam) - FRefreshStart) >= 0 then
      begin
        KillTimer(FWnd, ChangeTimer);
        SetTimer(FWnd, ChangeTimer, ChangeDelay, nil);
      end;
    WM_TIMER:
      if (Message.WParam = ChangeTimer) or (Message.WParam = ProjectTimer) then
      begin
        KillTimer(FWnd, Message.WParam);
        if Message.WParam = ProjectTimer then FollowProject else FileChanged;
      end;
    WM_ACTIVATEAPP:
      if Message.WParam <> 0 then FileChanged;
  end;
  Message.Result := DefWindowProc(FWnd, Message.Msg, Message.WParam, Message.LParam);
end;

procedure TGitHost.FileChanged;
begin
  if FClosing then Exit;
  if FShowing > 0 then Refresh else FDirty := True;
end;

{ the IDE tells of a project before it is done (a project's closing comes before the close, and none
  comes after it), so the repository is looked for again a moment later }
procedure TGitHost.ProjectChanged;
begin
  if FClosing then Exit;
  KillTimer(FWnd, ProjectTimer);
  SetTimer(FWnd, ProjectTimer, ProjectDelay, nil);
end;

{ while a view shows, the status is read again; with none shown the repository is looked for again when
  the project's folder is another one - the editor's commands and Git History use it, and the IDE may
  hide the views as it opens a project (Delphi 7's does) }
procedure TGitHost.FollowProject;
begin
  if FClosing then Exit;
  if (FShowing > 0) or not SameText(ProjectFolder, FFolder) then Refresh else FDirty := True;
end;

procedure TGitHost.Refresh;
var
  T: TGitTask;
begin
  FDirty := False;
  if FRefreshQueued then Exit;
  FRefreshQueued := True;
  { the project's folder is taken when the task starts (StartNext) }
  T := NewTask('Reading the status ...', DoRefresh);
  T.Silent := True;
  T.NoRepo := True;
  T.IsRefresh := True;
  T.OnDone := RefreshDone;
  Run(T);
end;

function TGitHost.RefreshPending: Boolean;
begin
  Result := FRefreshQueued or ((FRunning <> nil) and FRunning.IsRefresh);
end;

function TGitHost.EnsureRepo: Boolean;
begin
  CheckGit;
  { while there is none no task uses it: a refresh that runs puts what it finds in its place }
  if (FRepo = nil) and (FGit <> nil) then
  begin
    FFolder := ProjectFolder;
    FRepo := TGitRepo.Open(FGit, FFolder);
    if FRepo <> nil then Refresh;
  end;
  Result := FRepo <> nil;
end;

function TGitHost.ReadStatus(Status: TGitStatus): Boolean;
begin
  Result := False;
  if FRepo = nil then Exit;
  try
    FRepo.GetStatus(Status);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TGitHost.RefreshDone(Task: TGitTask);
var
  Root: string;
  Found: TGitRepo;
begin
  FRepoFailure := '';
  FStatusFailure := '';
  Found := nil;
  if Task <> nil then
  begin
    Found := Task.Found;
    FFolder := Task.Text;
  end;
  if (Found = nil) or (FRepo = nil) or (FRepo.Git <> Found.Git) or not SameText(FRepo.Root, Found.Root) or
    not SameText(FRepo.GitDir, Found.GitDir) then
  begin
    { another repository, or none: nothing read of the one before stays }
    if (Found = nil) or (FRepo = nil) or not SameText(FRepo.Root, Found.Root) then
    begin
      FStatus.Clear;
      FBranches.Clear;
      FStashes.Clear;
      FState := rsNormal;
    end;
    FreeAndNil(FRepo);
    if Found <> nil then
    begin
      FRepo := Found;
      Task.Found := nil;
    end
    else if Task <> nil then
    begin
      FRepoFailure := Task.Info;
      if FRepoFailure = '' then FRepoFailure := Task.Error;
    end;
  end;
  if (FRepo <> nil) and (Task <> nil) then
    if Task.Error <> '' then
      { what was read before stays: it is this repository's }
      FStatusFailure := Task.Error
    else
    begin
      if Task.Status <> nil then
      begin
        FStatus.Free;
        FStatus := Task.Status;
        Task.Status := nil;
      end;
      if Task.List <> nil then
      begin
        FBranches.Free;
        FBranches := Task.List;
        Task.List := nil;
      end;
      if Task.List2 <> nil then
      begin
        FStashes.Free;
        FStashes := Task.List2;
        Task.List2 := nil;
      end;
      FState := Task.RepoState;
    end;
  if FRepo <> nil then Root := FRepo.Root else Root := '';
  if Root <> FWatched then StartWatcher;
end;

procedure TGitHost.StartWatcher;
begin
  FreeAndNil(FWatcher);
  if FRepo <> nil then FWatched := FRepo.Root else FWatched := '';
  if (FWatched <> '') and (ReadSetting('AutoRefresh', '1') <> '0') then
    FWatcher := TGitWatcher.Create(Utf8ToWide(FWatched), FWnd);
end;

{ the last write time and size of a file, '' when it is missing }
function FileStamp(const FileName: string): string;
var
  D: TWin32FileAttributeData;
begin
  if GetFileAttributesExW(PWideChar(CodePageToWide(FileName, CP_ACP)), GetFileExInfoStandard, @D) then
    Result := Format('%x.%x.%d.%d', [D.ftLastWriteTime.dwHighDateTime, D.ftLastWriteTime.dwLowDateTime,
      D.nFileSizeHigh, D.nFileSizeLow])
  else
    Result := '';
end;

{ the files of module M: its own, then its editors' (a unit's form) }
procedure ModuleFiles(M: IOTAModule; L: TStrings);
var
  J: Integer;
  F: string;
begin
  L.Clear;
  L.Add(M.FileName);
  for J := 0 to M.GetModuleFileCount - 1 do
  begin
    F := KitEditorFile(M, J);
    if (F <> '') and (L.IndexOf(F) < 0) then L.Add(F);
  end;
end;

{ the stamps of the open modules' files in the work tree: FSnapFiles' Objects is the module's index
  in FSnapModules, -1 - that index for a project's options (which the IDE keeps in memory) }
procedure TGitHost.Snapshot;
var
  S: IOTAModuleServices;
  M: IOTAModule;
  Files: TStringList;
  I, J, K: Integer;
begin
  FSnapModules.Clear;
  FSnapFiles.Clear;
  FSnapStamps.Clear;
  Files := TStringList.Create;
  try
    try
      S := ModuleServices;
      for I := 0 to S.ModuleCount - 1 do
      begin
        M := S.Modules[I];
        if Supports(M, IOTAProjectGroup) then Continue;
        ModuleFiles(M, Files);
        if Supports(M, IOTAProject) then Files.AddObject(ChangeFileExt(M.FileName, '.dof'), TObject(1));
        K := -1;
        for J := 0 to Files.Count - 1 do
        begin
          if PathOf(Files[J]) = '' then Continue;
          if K < 0 then K := FSnapModules.Add(M.FileName);
          if Files.Objects[J] <> nil then FSnapFiles.AddObject(Files[J], TObject(-1 - K))
          else FSnapFiles.AddObject(Files[J], TObject(K));
          FSnapStamps.Add(FileStamp(Files[J]));
        end;
      end;
    except
      FSnapModules.Clear;
      FSnapFiles.Clear;
      FSnapStamps.Clear;
    end;
  finally
    Files.Free;
  end;
end;

{ the modules whose files the command changed read again; those with unsaved changes keep them (unless
  DropUnsaved), and the user is told so - as of a project whose options changed }
procedure TGitHost.ReloadChanged(DropUnsaved: Boolean);
var
  I, K: Integer;
  S, Kept, Options: string;
  Reload, NewOptions: array of Boolean;
  A: IOTAActionServices;
  M: IOTAModule;
begin
  SetLength(Reload, FSnapModules.Count);
  SetLength(NewOptions, FSnapModules.Count);
  for I := 0 to FSnapFiles.Count - 1 do
  begin
    S := FileStamp(FSnapFiles[I]);
    { a file git deleted stays as the IDE holds it }
    if (S = '') or (S = FSnapStamps[I]) then Continue;
    K := Integer(FSnapFiles.Objects[I]);
    if K >= 0 then Reload[K] := True else NewOptions[-1 - K] := True;
  end;
  Kept := '';
  Options := '';
  if Supports(BorlandIDEServices, IOTAActionServices, A) then
    for K := 0 to FSnapModules.Count - 1 do
    begin
      if NewOptions[K] then Options := Options + #13#10'    ' + ExtractFileName(FSnapModules[K]);
      if not Reload[K] then Continue;
      try
        M := FindModuleOf(FSnapModules[K]);
        if M = nil then Continue;
        if ModuleModified(M) and not DropUnsaved then Kept := Kept + #13#10'    ' + ExtractFileName(FSnapModules[K])
        else A.ReloadFile(FSnapModules[K]);
      except
        { a file the IDE cannot read again keeps what it shows }
      end;
    end;
  FSnapModules.Clear;
  FSnapFiles.Clear;
  FSnapStamps.Clear;
  if Kept <> '' then
    GitInform('These files changed on disk, but they have unsaved changes in the IDE, which were kept:' + Kept +
      #13#10#13#10'Saving them writes the IDE''s text over what is on disk now.');
  if Options <> '' then
    GitInform('The options of these projects changed on disk:' + Options + #13#10#13#10 +
      'The IDE keeps the options it read, and writes them when the project is saved: open the project again to use the new ones.');
end;

function TGitHost.SaveFiles(const Why: string): Boolean;
var
  S: IOTAModuleServices;
  M: IOTAModule;
  Mods: array of IOTAModule;
  Files: TStringList;
  I, J, N: Integer;
  Text: string;
begin
  Result := True;
  FLastSaved := 0;
  if FRepo = nil then Exit;
  N := 0;
  Files := TStringList.Create;
  try
    S := ModuleServices;
    for I := 0 to S.ModuleCount - 1 do
    begin
      M := S.Modules[I];
      if Supports(M, IOTAProjectGroup) or not ModuleModified(M) then Continue;
      ModuleFiles(M, Files);
      for J := 0 to Files.Count - 1 do
        if PathOf(Files[J]) <> '' then
        begin
          SetLength(Mods, N + 1);
          Mods[N] := M;
          Inc(N);
          Break;
        end;
    end;
  finally
    Files.Free;
  end;
  if N = 0 then Exit;
  Text := '';
  for I := 0 to N - 1 do
    if I < 8 then Text := Text + #13#10 + '    ' + ExtractFileName(Mods[I].FileName);
  if N > 8 then Text := Text + #13#10 + '    ...';
  if N = 1 then Text := 'A file of the repository has unsaved changes:' + Text
  else Text := Format('%d files of the repository have unsaved changes:', [N]) + Text;
  case GitConfirm(Text + #13#10#13#10 + Why + ' Save them first?', MB_YESNOCANCEL or MB_ICONQUESTION) of
    IDYES:
      for I := 0 to N - 1 do
      begin
        { a file that is not saved stops the command: git would work with what is on disk }
        if not Mods[I].Save(False, True) then
        begin
          Result := False;
          Exit;
        end;
        Inc(FLastSaved);
      end;
    IDNO: ;
  else
    Result := False;
  end;
end;

procedure TGitHost.UnsavedModules(Paths, L: TStrings);
var
  S: IOTAModuleServices;
  M: IOTAModule;
  Files: TStringList;
  Wanted: TGitPathList;
  I, J, N: Integer;
begin
  L.Clear;
  if (FRepo = nil) or (Paths.Count = 0) then Exit;
  Files := TStringList.Create;
  Wanted := TGitPathList.Create;
  try
    Wanted.Assign(Paths);
    S := ModuleServices;
    for I := 0 to S.ModuleCount - 1 do
    begin
      M := S.Modules[I];
      if Supports(M, IOTAProjectGroup) or not ModuleModified(M) then Continue;
      ModuleFiles(M, Files);
      for J := 0 to Files.Count - 1 do
        if Wanted.Find(PathOf(Files[J]), N) then
        begin
          L.Add(M.FileName);
          Break;
        end;
    end;
  finally
    Wanted.Free;
    Files.Free;
  end;
end;

{ ---------------------------------------------------------------- the commands }

procedure TGitHost.Stage(Paths: TStrings);
var
  T: TGitTask;
begin
  T := NewTask('Staging ...', DoStage);
  T.Paths.Assign(Paths);
  T.Changes := True;
  Run(T);
end;

procedure TGitHost.Unstage(Paths: TStrings);
var
  T: TGitTask;
begin
  T := NewTask('Unstaging ...', DoUnstage);
  T.Paths.Assign(Paths);
  T.Changes := True;
  Run(T);
end;

procedure TGitHost.Discard(Tracked, Untracked: TStrings);
var
  T: TGitTask;
begin
  T := NewTask('Discarding the changes ...', DoDiscard);
  if Tracked <> nil then T.Paths.Assign(Tracked);
  if Untracked <> nil then T.Paths2.Assign(Untracked);
  T.Changes := True;
  T.RewritesTree := True;
  T.DropUnsaved := True;
  Run(T);
end;

procedure TGitHost.Commit(const Message: string; Amend, StageTracked: Boolean; Owner: TObject;
  OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewTask('Committing ...', DoCommit);
  T.Text := Message;
  T.Flag := Amend;
  T.Flag2 := StageTracked;
  T.Changes := True;
  T.Owner := Owner;
  T.OnDone := OnDone;
  Run(T);
end;

procedure TGitHost.Fetch;
var
  T: TGitTask;
begin
  T := NewTask('Fetching ...', DoFetch);
  T.Stoppable := True;
  T.Changes := True;
  Run(T);
end;

{ not stoppable: stopped while it merges, a pull could leave the index locked and the work tree half
  changed }
procedure TGitHost.Pull;
var
  T: TGitTask;
begin
  T := NewTask('Pulling ...', DoPull);
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.Push(const Remote: string);
var
  T: TGitTask;
begin
  T := NewTask('Pushing ...', DoPush);
  T.Text := Remote;
  T.Stoppable := True;
  T.Changes := True;
  Run(T);
end;

procedure TGitHost.Switch(const Branch: string; Remote: Boolean);
var
  T: TGitTask;
begin
  T := NewTask('Switching to ' + Utf8ToIde(Branch) + ' ...', DoSwitch);
  T.Text := Branch;
  T.Flag := Remote;
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.CreateBranch(const Name, StartPoint: string; SwitchTo: Boolean);
var
  T: TGitTask;
begin
  T := NewTask('Creating the branch ' + Utf8ToIde(Name) + ' ...', DoCreateBranch);
  T.Text := Name;
  T.Text2 := StartPoint;
  T.Flag := SwitchTo;
  T.Changes := True;
  T.RewritesTree := SwitchTo;
  Run(T);
end;

procedure TGitHost.DeleteBranch(const Name: string; Force: Boolean; Owner: TObject; OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewTask('Deleting the branch ' + Utf8ToIde(Name) + ' ...', DoDeleteBranch);
  T.Text := Name;
  T.Flag := Force;
  T.Changes := True;
  T.Owner := Owner;
  T.OnDone := OnDone;
  T.Silent := Assigned(OnDone);
  Run(T);
end;

procedure TGitHost.StashPush(const Message: string; Untracked: Boolean);
var
  T: TGitTask;
begin
  T := NewTask('Stashing ...', DoStash);
  T.Number := 0;
  T.Text := Message;
  T.Flag := Untracked;
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.StashPop;
var
  T: TGitTask;
begin
  T := NewTask('Popping the stash ...', DoStash);
  T.Number := 1;
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.StashApply(const Ref: string);
var
  T: TGitTask;
begin
  T := NewTask('Applying ' + Ref + ' ...', DoStash);
  T.Number := 2;
  T.Text := Ref;
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.StashDrop(const Ref: string);
var
  T: TGitTask;
begin
  T := NewTask('Dropping ' + Ref + ' ...', DoStash);
  T.Number := 3;
  T.Text := Ref;
  T.Changes := True;
  Run(T);
end;

procedure TGitHost.AbortOperation;
var
  T: TGitTask;
begin
  T := NewTask('Aborting ...', DoAbort);
  T.Changes := True;
  T.RewritesTree := True;
  Run(T);
end;

procedure TGitHost.InitRepository;
var
  T: TGitTask;
begin
  T := NewTask('Creating the repository ...', DoInit);
  T.NoRepo := True;
  T.Text := ProjectFolder;
  T.Changes := True;
  Run(T);
end;

procedure TGitHost.LoadLog(Owner: TObject; Tag: Integer; const Path: string; AllBranches: Boolean;
  Skip, Max: Integer; OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewRead('Reading the history ...', DoLog, Owner, Tag, OnDone);
  T.Text := Path;
  T.Flag := AllBranches;
  T.Number := Skip;
  T.Number2 := Max;
  Run(T);
end;

procedure TGitHost.LoadCommit(Owner: TObject; Tag: Integer; const Id: string; OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewRead('Reading the commit ...', DoCommitInfo, Owner, Tag, OnDone);
  T.Text := Id;
  Run(T);
end;

procedure TGitHost.LoadDiff(Owner: TObject; Tag, Kind: Integer; const Path, OrigPath, Id, Bytes: string;
  OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewRead('Reading the changes ...', DoDiff, Owner, Tag, OnDone);
  T.Number := Kind;
  T.Text := Path;
  T.Text2 := Id;
  T.Info := OrigPath;
  T.Bytes := Bytes;
  Run(T);
end;

procedure TGitHost.LoadBlame(Owner: TObject; Tag: Integer; const Path, Bytes: string; HasBytes: Boolean;
  OnDone: TGitTaskEvent);
var
  T: TGitTask;
begin
  T := NewRead('Reading the blame ...', DoBlame, Owner, Tag, OnDone);
  T.Text := Path;
  T.Bytes := Bytes;
  T.Flag := HasBytes;
  Run(T);
end;

procedure TGitHost.LoadLastMessage(Owner: TObject; OnDone: TGitTaskEvent);
begin
  Run(NewRead('Reading the last commit ...', DoLastMessage, Owner, 0, OnDone));
end;

{ ---------------------------------------------------------------- the work (worker thread) }

procedure TGitHost.DoRefresh(Task: TGitTask);
var
  Failure: string;
begin
  Task.Found := TGitRepo.Open(FGit, Task.Text, Failure);
  Task.Info := Failure;
  if Task.Found = nil then Exit;
  Task.RepoState := Task.Found.State;
  Task.Status := TGitStatus.Create;
  Task.Found.GetStatus(Task.Status);
  Task.List := TObjectList.Create(True);
  Task.Found.GetBranches(Task.List);
  Task.List2 := TObjectList.Create(True);
  Task.Found.GetStashes(Task.List2);
end;

procedure TGitHost.DoStage(Task: TGitTask);
begin
  Task.Repo.Stage(Task.Paths);
end;

procedure TGitHost.DoUnstage(Task: TGitTask);
begin
  Task.Repo.Unstage(Task.Paths);
end;

procedure TGitHost.DoDiscard(Task: TGitTask);
begin
  Task.Repo.Discard(Task.Paths);
  Task.Repo.DeleteUntracked(Task.Paths2);
end;

procedure TGitHost.DoCommit(Task: TGitTask);
begin
  if Task.Flag2 then Task.Repo.StageTracked;
  Task.Repo.Commit(Task.Text, Task.Flag);
end;

procedure TGitHost.DoFetch(Task: TGitTask);
begin
  Task.Repo.Fetch(Task.Cancelled);
end;

procedure TGitHost.DoPull(Task: TGitTask);
begin
  { Cancelled is True only when the host goes }
  Task.Repo.Pull(Task.Cancelled);
end;

procedure TGitHost.DoPush(Task: TGitTask);
begin
  Task.Repo.Push(Task.Text, Task.Cancelled);
end;

procedure TGitHost.DoSwitch(Task: TGitTask);
begin
  Task.Repo.Switch(Task.Text, Task.Flag);
end;

procedure TGitHost.DoCreateBranch(Task: TGitTask);
begin
  Task.Repo.CreateBranch(Task.Text, Task.Text2, Task.Flag);
end;

procedure TGitHost.DoDeleteBranch(Task: TGitTask);
begin
  Task.Repo.DeleteBranch(Task.Text, Task.Flag);
end;

procedure TGitHost.DoStash(Task: TGitTask);
begin
  case Task.Number of
    0: Task.Repo.StashPush(Task.Text, Task.Flag);
    1: Task.Repo.StashPop;
    2: Task.Repo.StashApply(Task.Text);
    3: Task.Repo.StashDrop(Task.Text);
  end;
end;

procedure TGitHost.DoAbort(Task: TGitTask);
begin
  Task.Repo.AbortOperation;
end;

procedure TGitHost.DoInit(Task: TGitTask);
begin
  if Task.Text = '' then raise EGitError.Create('There is no project folder to create the repository in.');
  TGitRepo.Init(FGit, Task.Text);
end;

procedure TGitHost.DoLog(Task: TGitTask);
begin
  Task.List := TObjectList.Create(True);
  Task.Repo.GetLog(Task.List, Task.Text, Task.Flag, Task.Number, Task.Number2);
end;

procedure TGitHost.DoCommitInfo(Task: TGitTask);
var
  Author, Refs: string;
  Time: Int64;
begin
  Task.Info := Task.Repo.CommitInfo(Task.Text, Author, Time, Refs);
  Task.Text2 := Author;
  Task.Bytes := Refs;
  Task.Time := Time;
  Task.List := TObjectList.Create(True);
  Task.Repo.GetCommitFiles(Task.Text, Task.List);
end;

procedure TGitHost.DoDiff(Task: TGitTask);
begin
  Task.Diff := TGitDiff.Create;
  Task.Diff.Clear;
  case Task.Number of
    0: Task.Repo.GetWorkTreeDiff(Task.Text, '', gbIndex, Task.Diff);
    1: Task.Repo.GetWorkTreeDiff(Task.Text, Task.Info, gbStaged, Task.Diff);
    2: Task.Repo.GetUntrackedDiff(Task.Text, Task.Diff);
    3: Task.Repo.GetCommitDiff(Task.Text2, Task.Text, Task.Info, Task.Diff);
    4: Task.Repo.GetTextDiff(Task.Text, Task.Bytes, Task.Diff);
    5: Task.Repo.GetWorkTreeDiff(Task.Text, '', gbHead, Task.Diff);
  end;
end;

procedure TGitHost.DoBlame(Task: TGitTask);
begin
  Task.Blame := TGitBlame.Create;
  Task.Repo.GetBlame(Task.Text, Task.Bytes, Task.Flag, Task.Blame);
end;

procedure TGitHost.DoLastMessage(Task: TGitTask);
begin
  Task.Info := Task.Repo.LastMessage;
end;

initialization
  GitAsk := nil;
  GitError := nil;
finalization
  FreeGitHost;
end.
