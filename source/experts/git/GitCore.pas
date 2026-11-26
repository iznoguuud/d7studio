{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitCore;

{ Git through its command line - git.exe of Git for Windows - without the IDE: finding git.exe,
  running it, the operations on a repository, and reading what git prints (the status of the work
  tree, branches, the log, a commit's files, diffs, blame, stashes).
  * Text: git's paths and messages are UTF-8. A repository path is relative to the work tree, with
    '/', as git writes it; the work tree's folder (TGitRepo.Root) is a Windows path in UTF-8. The
    lines of files in diffs and blame are UTF-8 too: a file whose lines are not valid UTF-8 is read
    in the system code page, as Delphi 7 writes its sources.
  * Running: a command runs in the calling thread (the IDE's views run them in a worker thread:
    GitHost). The command line goes to Windows as UTF-16, so names outside the IDE's code page reach
    git as they are. git never waits for a terminal or an editor (GIT_TERMINAL_PROMPT=0, no stdin,
    GIT_EDITOR=true, GIT_MERGE_AUTOEDIT=no), and a status does not write the index
    (GIT_OPTIONAL_LOCKS=0). Fetch, pull and push may be cancelled.
  * Files: commands that take several files read them from a file (--pathspec-from-file, NUL
    separated) as literal names (--literal-pathspecs); one file follows "--". }

interface

uses
  Windows, SysUtils, Classes, Contnrs, GitText, GitProcess;

const
  GitLocalTimeout = 2 * 60 * 1000;        // a local command, ms
  GitNetworkTimeout = 10 * 60 * 1000;     // fetch, pull, push
  GitZeroId = '0000000000000000000000000000000000000000';
  MaxUntrackedSize = 4 * 1024 * 1024;     // the largest untracked file shown as lines, bytes

type
  { git failed; the message is git's own (an IDE string) }
  EGitError = class(Exception);

  { a sorted list of repository paths, each once, compared byte for byte: two names that differ are
    two files, whatever the locale's comparison says }
  TGitPathList = class(TStringList)
  protected
    function CompareStrings(const S1, S2: string): Integer; override;
  public
    constructor Create;
  end;

  { what a change of the status is }
  TGitChangeKind = (ckStaged, ckUnstaged, ckUntracked, ckConflict);

  { a changed file of the work tree (git status --porcelain=v2) }
  TGitChange = class
  public
    Path: string;          // UTF-8, relative to the work tree, '/'
    OrigPath: string;      // where a renamed or copied file came from; '' else
    X: Char;               // the index: '.' unchanged, M A D R C T, U unmerged; '?' untracked
    Y: Char;               // the work tree, the same letters
    Conflict: Boolean;     // unmerged: a conflict to resolve
    function Staged: Boolean;
    function Unstaged: Boolean;
    function Untracked: Boolean;
    function IsKind(Kind: TGitChangeKind): Boolean;
  end;

  TGitStatus = class
  private
    FChanges: TObjectList;
    function GetChange(Index: Integer): TGitChange;
    function CountKind(Kind: TGitChangeKind): Integer;
  public
    Branch: string;        // UTF-8; '' when HEAD is detached
    Head: string;          // HEAD's commit; '' before the first commit
    Upstream: string;      // '' when the branch has none
    Ahead, Behind: Integer;
    Stashes: Integer;
    Key: string;           // all of it in one string: two statuses with the same key are the same
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add: TGitChange;
    function Count: Integer;
    function CountStaged: Integer;
    function CountUnstaged: Integer;
    function CountUntracked: Integer;
    function CountConflicts: Integer;
    property Changes[Index: Integer]: TGitChange read GetChange; default;
  end;

  TGitBranch = class
  public
    Name: string;          // short: 'main', 'origin/main' (UTF-8)
    Remote: Boolean;
    Current: Boolean;
    Upstream: string;      // a local branch's upstream, short
    Track: string;         // '[ahead 1, behind 2]', '[gone]', ''
    Commit: string;        // its commit, short
    Subject: string;
  end;

  TGitCommit = class
  public
    Id, ShortId: string;
    Parents: string;       // the parents' ids, separated by spaces
    Author, Email: string; // UTF-8
    Time: Int64;           // the author's date, Unix time
    Refs: string;          // 'HEAD -> main, origin/main, tag: v1'
    Subject: string;       // UTF-8
    { a file's history: the file's name in this commit, and where this commit renamed it from }
    Path, OrigPath: string;
  end;

  { a file of a commit (git show --name-status) }
  TGitFileChange = class
  public
    State: Char;           // A M D R C T
    Path, OrigPath: string;
  end;

  TGitStash = class
  public
    Ref: string;           // 'stash@{0}'
    Time: Int64;
    Message: string;       // UTF-8
  end;

  TGitDiffKind = (gdFile, gdNote, gdHunk, gdSame, gdRemoved, gdAdded);

  TGitDiffLine = record
    Kind: TGitDiffKind;
    OldLine, NewLine: Integer;   // 1-based; 0 where the line has none
    Text: string;                // UTF-8: a file's path, a note, a hunk's header, a line of the file
  end;

  { a diff in lines: per file a gdFile line with its path, notes (new, deleted, renamed, binary),
    then its hunks - a gdHunk line and the lines of the file }
  TGitDiff = class
  private
    FLines: array of TGitDiffLine;
    FCount: Integer;
    FFileLine: Integer;
    function GetLine(Index: Integer): TGitDiffLine;
  public
    Added, Removed, Hunks, Files: Integer;
    procedure Clear;
    procedure Add(Kind: TGitDiffKind; OldLine, NewLine: Integer; const Text: string);
    { Text (UTF-8) as the lines of a new file Path: an untracked file }
    procedure AddWholeFile(const Path, Text: string);
    { the path of the last file line (a diff of two scratch files shows the real one) }
    procedure SetFilePath(const Path: string);
    property Count: Integer read FCount;
    property Lines[Index: Integer]: TGitDiffLine read GetLine; default;
  end;

  TGitBlameCommit = class
  public
    Id, Author: string;
    Time: Int64;
    Summary: string;
    function Uncommitted: Boolean;
  end;

  TGitBlameLine = record
    Commit: TGitBlameCommit;
    Line: Integer;               // in the file blamed, 1-based
    Text: string;                // UTF-8
    First: Boolean;              // the first line of a run of the same commit
  end;

  TGitBlame = class
  private
    FCommits: TObjectList;
    FIndex: TStringList;         // the commits by id (sorted): a large file has thousands
    FLines: array of TGitBlameLine;
    FCount: Integer;
    function GetLine(Index: Integer): TGitBlameLine;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function CommitOf(const Id: string): TGitBlameCommit;
    procedure Add(Commit: TGitBlameCommit; Line: Integer; const Text: string);
    function CommitCount: Integer;
    property Count: Integer read FCount;
    property Lines[Index: Integer]: TGitBlameLine read GetLine; default;
  end;

  { git.exe, and the environment it runs in }
  TGit = class
  private
    FExe: WideString;
    FEnv: TStringList;
    FReadStop: TKitCancelQuery;
  public
    constructor Create(const AExe: WideString);
    destructor Destroy; override;
    { runs git with Args (UTF-8) in Dir (a Windows path in UTF-8): its exit code, what it wrote to
      stdout and to stderr }
    function Run(const Dir: string; const Args: array of string; out Output, Errors: string;
      TimeoutMs: Cardinal = GitLocalTimeout; Cancelled: TKitCancelQuery = nil): Integer;
    { Run that raises EGitError with git's message when the exit code is not 0; stdout }
    function Exec(const Dir: string; const Args: array of string; Cancelled: TKitCancelQuery = nil;
      TimeoutMs: Cardinal = GitLocalTimeout): string;
    { 'git version 2.53.0.windows.1' }
    function Version: string;
    property Exe: WideString read FExe;
    { asked while a command of TGitRepo that only reads runs (a status, the log, a diff, blame):
      True stops it - its owner goes away. A command that writes runs to its end: stopped, it could
      leave the index locked or a merge half done }
    property ReadStop: TKitCancelQuery read FReadStop write FReadStop;
  end;

  { what is going on: a merge, a rebase, a cherry-pick, a revert, or git am applying patches }
  TGitRepoState = (rsNormal, rsMerging, rsRebasing, rsCherryPicking, rsReverting, rsApplying);

  { a diff of the work tree: against the index, the index against HEAD, the work tree against HEAD }
  TGitDiffBase = (gbIndex, gbStaged, gbHead);

  { a repository: its work tree and what can be done in it }
  TGitRepo = class
  private
    FGit: TGit;
    FRoot: string;
    FGitDir: string;
    function Exec(const Args: array of string; Cancelled: TKitCancelQuery = nil;
      TimeoutMs: Cardinal = GitLocalTimeout): string;
    { Exec of a command that only reads (TGit.ReadStop) }
    function Query(const Args: array of string): string;
    { runs git with Args followed by the files Paths (given through a file) }
    procedure ExecPaths(const Args: array of string; Paths: TStrings);
  public
    constructor Create(AGit: TGit; const ARoot, AGitDir: string);
    { the repository whose work tree holds Folder (a Windows path in UTF-8); nil when there is none.
      Failure: '' when Folder is in no repository, else why git cannot open the one that is there
      (git's message: a work tree of another user's, a damaged repository ...) }
    class function Open(AGit: TGit; const Folder: string): TGitRepo; overload;
    class function Open(AGit: TGit; const Folder: string; out Failure: string): TGitRepo; overload;
    { a new repository in Folder }
    class procedure Init(AGit: TGit; const Folder: string);
    function State: TGitRepoState;
    { the Windows path (UTF-8) of a repository path, and the repository path of a Windows path ('' when
      it lies outside the work tree). The Windows path is compared as Windows resolves it
      (CanonicalPath): the IDE may name a file through a subst drive or a junction, or in another
      case, than git names the work tree }
    function FullPath(const Path: string): string;
    function RelativePath(const FullName: string): string;
    procedure GetStatus(Status: TGitStatus);
    procedure GetBranches(List: TObjectList);
    procedure GetStashes(List: TObjectList);
    { the remotes' names, one per line }
    function Remotes: string;
    { commits of the current branch (of every branch and tag with AllBranches; of the file Path, its
      renames followed, when Path is given), newest first: Max of them after the first Skip, added to
      List (a history loads more at its end) }
    procedure GetLog(List: TObjectList; const Path: string; AllBranches: Boolean; Skip, Max: Integer);
    { a commit's author, date and message (UTF-8): 'Author <mail>'#10'Unix time'#10'refs'#10'message' }
    function CommitInfo(const Id: string; out Author: string; out Time: Int64; out Refs: string): string;
    procedure GetCommitFiles(const Id: string; List: TObjectList);
    { the changes of Path: in the work tree against the index, in the index against HEAD (OrigPath:
      where a staged rename came from), or in the work tree against HEAD (a file with a conflict) }
    procedure GetWorkTreeDiff(const Path, OrigPath: string; Base: TGitDiffBase; Diff: TGitDiff);
    { the changes of commit Id (against its first parent) - of Path only when it is given; OrigPath:
      where Path came from when the commit renamed it }
    procedure GetCommitDiff(const Id, Path, OrigPath: string; Diff: TGitDiff);
    { HEAD's Path against Bytes (the file as the editor holds it, in its encoding) }
    procedure GetTextDiff(const Path, Bytes: string; Diff: TGitDiff);
    { an untracked file as a diff of a new file: its lines; a note for a binary file, one too large
      to show (over MaxUntrackedSize bytes) and a folder (Path ends with '/': a repository of its
      own in the work tree) }
    procedure GetUntrackedDiff(const Path: string; Diff: TGitDiff);
    { blame of Path as it is on disk, or as Bytes are (HasBytes: the editor's text) }
    procedure GetBlame(const Path, Bytes: string; HasBytes: Boolean; Blame: TGitBlame);
    { the message of HEAD's commit (UTF-8), '' before the first commit }
    function LastMessage: string;
    procedure Stage(Paths: TStrings);
    { every change of a tracked file into the index (git add -u) }
    procedure StageTracked;
    procedure Unstage(Paths: TStrings);
    { the work tree's changes of tracked files undone (from the index) }
    procedure Discard(Paths: TStrings);
    { untracked files deleted; a folder (a repository of its own) is not: EGitError }
    procedure DeleteUntracked(Paths: TStrings);
    procedure Commit(const Message: string; Amend: Boolean);
    procedure Fetch(Cancelled: TKitCancelQuery);
    procedure Pull(Cancelled: TKitCancelQuery);
    { pushes the current branch; to Remote, made its upstream, when Remote is given }
    procedure Push(const Remote: string; Cancelled: TKitCancelQuery);
    { switches to Branch; a remote branch ('origin/x') becomes a local branch that tracks it }
    procedure Switch(const Branch: string; Remote: Boolean);
    procedure CreateBranch(const Name, StartPoint: string; SwitchTo: Boolean);
    procedure DeleteBranch(const Name: string; Force: Boolean);
    function ValidBranchName(const Name: string): Boolean;
    procedure StashPush(const Message: string; Untracked: Boolean);
    procedure StashPop;
    procedure StashApply(const Ref: string);
    procedure StashDrop(const Ref: string);
    { the merge, rebase, cherry-pick, revert or git am that is going on, abandoned }
    procedure AbortOperation;
    property Root: string read FRoot;
    property GitDir: string read FGitDir;
    property Git: TGit read FGit;
  end;

{ git.exe: Configured when it names one, else the one in a folder of the PATH (its absolute folders
  only: never the current folder - a project's - nor the IDE's), else Git for Windows' (its registry
  key, the Program Files folders); '' when there is none }
function FindGitExe(const Configured: WideString): WideString;
{ Arg as Windows' command line rules read it back (CommandLineToArgvW, the C runtime): quoted when
  it is empty or holds a space, a tab or a quote }
function QuoteArg(const Arg: WideString): WideString;

{ git's output read; ParseLog adds to List, the others fill it anew }
procedure ParseStatus(const Output: string; Status: TGitStatus);
procedure ParseBranches(const Output: string; List: TObjectList);
procedure ParseLog(const Output: string; List: TObjectList);
procedure ParseNameStatus(const Output: string; List: TObjectList);
procedure ParseStashes(const Output: string; List: TObjectList);
procedure ParseDiff(const Output: string; Diff: TGitDiff);
procedure ParseBlame(const Output: string; Blame: TGitBlame);

{ a Unix time as the local date and time, 'yyyy-mm-dd hh:nn' }
function GitTimeText(T: Int64): string;
{ a path of C-style quotes as git writes unusual names ("a\tb", octal bytes) read back }
function UnquoteC(const S: string): string;
{ lines of a file (bytes) as UTF-8: as they are when valid UTF-8, else from the system code page }
function FileLinesToUtf8(const S: string; IsUtf8: Boolean): string;

{ a new empty file of its own in %TEMP%\D7GitExpert }
function TempFileW(const Prefix: string): WideString;
{ a Windows path (UTF-8) as Windows resolves it - subst drives and junctions followed, the case of
  the disk - for a file or folder that exists, else for its folder; as it is where Windows cannot
  tell (before Vista) }
function CanonicalPath(const Path: string): string;

implementation

uses
  Registry;

{ ---------------------------------------------------------------- files }

type
  TGetFinalPathNameByHandleW = function(hFile: THandle; lpszFilePath: PWideChar; cchFilePath, dwFlags: DWORD): DWORD; stdcall;

var
  GetFinalPathNameByHandleW: TGetFinalPathNameByHandleW;
  FinalPathLooked: Boolean;

{ Name (UTF-16) as Windows resolves it, '' where it cannot (no such file, before Vista) }
function FinalPath(const Name: WideString): WideString;
const
  FILE_FLAG_BACKUP_SEMANTICS_ = $02000000;   // opens a folder too
var
  H: THandle;
  Buf: array of WideChar;
  N: DWORD;
begin
  Result := '';
  if not FinalPathLooked then
  begin
    GetFinalPathNameByHandleW := GetProcAddress(GetModuleHandle(kernel32), 'GetFinalPathNameByHandleW');
    FinalPathLooked := True;
  end;
  if not Assigned(GetFinalPathNameByHandleW) then Exit;
  H := CreateFileW(PWideChar(Name), 0, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS_, 0);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    SetLength(Buf, MAX_PATH + 1);
    N := GetFinalPathNameByHandleW(H, @Buf[0], Length(Buf), 0);
    if N >= DWORD(Length(Buf)) then
    begin
      SetLength(Buf, N + 1);
      N := GetFinalPathNameByHandleW(H, @Buf[0], Length(Buf), 0);
    end;
    if (N = 0) or (N >= DWORD(Length(Buf))) then Exit;
    SetString(Result, PWideChar(@Buf[0]), N);
  finally
    CloseHandle(H);
  end;
  { '\\?\C:\...' -> 'C:\...', '\\?\UNC\server\share' -> '\\server\share' }
  if Copy(Result, 1, 8) = '\\?\UNC\' then Result := '\\' + Copy(Result, 9, MaxInt)
  else if Copy(Result, 1, 4) = '\\?\' then Result := Copy(Result, 5, MaxInt);
end;

function CanonicalPath(const Path: string): string;
var
  W, F: WideString;
  P: Integer;
begin
  Result := Path;
  W := Utf8ToWide(Path);
  F := FinalPath(W);
  if F = '' then
  begin
    { a file that is not there (yet): its folder resolved, its name as it is }
    P := Length(W);
    while (P > 0) and (W[P] <> '\') do Dec(P);
    if P <= 1 then Exit;
    F := FinalPath(Copy(W, 1, P - 1));
    if F = '' then Exit;
    F := F + Copy(W, P, MaxInt);
  end;
  Result := WideToUtf8(F);
end;

function TempFileW(const Prefix: string): WideString;
var
  Dir: array[0..MAX_PATH] of WideChar;
  Name: array[0..MAX_PATH] of WideChar;
  Folder: WideString;
begin
  GetTempPathW(MAX_PATH, Dir);
  Folder := WideString(PWideChar(@Dir[0])) + 'D7GitExpert';
  CreateDirectoryW(PWideChar(Folder), nil);
  if GetTempFileNameW(PWideChar(Folder), PWideChar(WideString(Prefix)), 0, Name) = 0 then RaiseLastOSError;
  Result := PWideChar(@Name[0]);
end;

{ ---------------------------------------------------------------- text }

constructor TGitPathList.Create;
begin
  inherited Create;
  Duplicates := dupIgnore;
  Sorted := True;
end;

function TGitPathList.CompareStrings(const S1, S2: string): Integer;
begin
  Result := CompareStr(S1, S2);
end;

function FileLinesToUtf8(const S: string; IsUtf8: Boolean): string;
begin
  if IsUtf8 or not HasHighBytes(S) then Result := S
  else Result := WideToUtf8(CodePageToWide(S, SystemCodePage));
end;

{ S split at #10, a #13 before it dropped (the lines of CR LF files keep no CR) }
procedure SplitLinesLF(const S: string; L: TStrings);
var
  I, Start, Len: Integer;
begin
  L.Clear;
  Start := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then
    begin
      Len := I - Start;
      if (Len > 0) and (S[Start + Len - 1] = #13) then Dec(Len);
      L.Add(Copy(S, Start, Len));
      Start := I + 1;
    end;
  if Start <= Length(S) then
  begin
    Len := Length(S) - Start + 1;
    if S[Length(S)] = #13 then Dec(Len);
    L.Add(Copy(S, Start, Len));
  end;
end;

{ S split at Sep (each part ends with it; a last part without it counts too) }
procedure SplitAt(const S: string; Sep: Char; L: TStrings);
var
  I, Start: Integer;
begin
  L.Clear;
  Start := 1;
  for I := 1 to Length(S) do
    if S[I] = Sep then
    begin
      L.Add(Copy(S, Start, I - Start));
      Start := I + 1;
    end;
  if Start <= Length(S) then L.Add(Copy(S, Start, MaxInt));
end;

{ the text after the first N fields of S (fields separated by single spaces) }
function AfterFields(const S: string; N: Integer): string;
var
  I, Found: Integer;
begin
  Found := 0;
  for I := 1 to Length(S) do
    if S[I] = ' ' then
    begin
      Inc(Found);
      if Found = N then
      begin
        Result := Copy(S, I + 1, MaxInt);
        Exit;
      end;
    end;
  Result := '';
end;

{ field N (0-based) of S, fields separated by single spaces }
function FieldOf(const S: string; N: Integer): string;
var
  I, Start, Found: Integer;
begin
  Found := 0;
  Start := 1;
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = ' ') then
    begin
      if Found = N then
      begin
        Result := Copy(S, Start, I - Start);
        Exit;
      end;
      Inc(Found);
      Start := I + 1;
    end;
  Result := '';
end;

{ S begins with Prefix (no copy of S made: the parsers ask it of every line) }
{ the lines of L from First on whose first character is one of Marks (the lines of a file in git's
  output) are valid UTF-8 - up to the first line that begins with Stop ('': to the end) }
function LinesAreUtf8(L: TStrings; First: Integer; const Marks: TSysCharSet; const Stop: string): Boolean;
var
  K: Integer;
  T: string;
begin
  Result := True;
  for K := First to L.Count - 1 do
  begin
    T := L[K];
    if (Stop <> '') and KitStartsWith(T, Stop) then Exit;
    if (T <> '') and (T[1] in Marks) and HasHighBytes(T) and not IsValidUtf8(T) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

type
  TStringArray = array of string;

{ Items added at the end of A: git's arguments built in parts }
procedure AddArgs(var A: TStringArray; const Items: array of string);
var
  I, N: Integer;
begin
  N := Length(A);
  SetLength(A, N + Length(Items));
  for I := 0 to High(Items) do A[N + I] := Items[I];
end;

function UnquoteC(const S: string): string;
var
  I, V, K: Integer;
  B: TKitStringBuilder;
begin
  if (Length(S) < 2) or (S[1] <> '"') or (S[Length(S)] <> '"') then
  begin
    Result := S;
    Exit;
  end;
  B := TKitStringBuilder.Create;
  try
    I := 2;
    while I < Length(S) do
    begin
      if (S[I] = '\') and (I + 1 < Length(S)) then
      begin
        Inc(I);
        case S[I] of
          'a': B.AppendChar(#7);
          'b': B.AppendChar(#8);
          't': B.AppendChar(#9);
          'n': B.AppendChar(#10);
          'v': B.AppendChar(#11);
          'f': B.AppendChar(#12);
          'r': B.AppendChar(#13);
          '0'..'7':
            begin
              V := 0;
              K := 0;
              while (K < 3) and (I < Length(S)) and (S[I] in ['0'..'7']) do
              begin
                V := V * 8 + Ord(S[I]) - Ord('0');
                Inc(I);
                Inc(K);
              end;
              B.AppendChar(Chr(V and $FF));
              Continue;
            end;
        else
          B.AppendChar(S[I]);
        end;
        Inc(I);
      end
      else
      begin
        B.AppendChar(S[I]);
        Inc(I);
      end;
    end;
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function GitTimeText(T: Int64): string;
var
  FT: TFileTime;
  UTC, ST: TSystemTime;
  V: Int64;
begin
  if T <= 0 then
  begin
    Result := '';
    Exit;
  end;
  { Unix time -> FILETIME (100 ns since 1601) -> local time with the daylight saving of that date
    (FileTimeToLocalFileTime takes today's) }
  V := (T + 11644473600) * 10000000;
  FT.dwLowDateTime := DWORD(V and $FFFFFFFF);
  FT.dwHighDateTime := DWORD(V shr 32);
  FileTimeToSystemTime(FT, UTC);
  if not SystemTimeToTzSpecificLocalTime(nil, UTC, ST) then ST := UTC;
  Result := Format('%.4d-%.2d-%.2d %.2d:%.2d', [ST.wYear, ST.wMonth, ST.wDay, ST.wHour, ST.wMinute]);
end;

{ ---------------------------------------------------------------- git.exe }

function QuoteArg(const Arg: WideString): WideString;
var
  I, N, K: Integer;
  Need: Boolean;
begin
  Need := Arg = '';
  for I := 1 to Length(Arg) do
    if (Arg[I] = ' ') or (Arg[I] = #9) or (Arg[I] = '"') then Need := True;
  if not Need then
  begin
    Result := Arg;
    Exit;
  end;
  Result := '"';
  I := 1;
  while True do
  begin
    N := 0;
    while (I <= Length(Arg)) and (Arg[I] = '\') do
    begin
      Inc(N);
      Inc(I);
    end;
    if I > Length(Arg) then
    begin
      { backslashes before the closing quote doubled }
      for K := 1 to N * 2 do Result := Result + '\';
      Break;
    end;
    if Arg[I] = '"' then
    begin
      for K := 1 to N * 2 + 1 do Result := Result + '\';
      Result := Result + '"';
    end
    else
    begin
      for K := 1 to N do Result := Result + '\';
      Result := Result + Arg[I];
    end;
    Inc(I);
  end;
  Result := Result + '"';
end;

{ an environment variable (UTF-16), however long it is }
function EnvW(const Name: WideString): WideString;
var
  N: DWORD;
  Buf: WideString;
begin
  Result := '';
  N := GetEnvironmentVariableW(PWideChar(Name), nil, 0);
  if N = 0 then Exit;
  SetLength(Buf, N);
  N := GetEnvironmentVariableW(PWideChar(Name), PWideChar(Buf), N);
  if (N > 0) and (N < DWORD(Length(Buf))) then Result := Copy(Buf, 1, N);
end;

{ the file Name in the first absolute folder of the PATH that has it; '' none. Not SearchPathW: it
  looks in the program's folder and the current one (the active project's) first }
function FindOnPath(const Name: WideString): WideString;
var
  Path, Dir: WideString;
  I, Start: Integer;
begin
  Result := '';
  Path := EnvW('PATH') + ';';
  Start := 1;
  for I := 1 to Length(Path) do
    if Path[I] = ';' then
    begin
      Dir := Trim(Copy(Path, Start, I - Start));
      Start := I + 1;
      if (Length(Dir) >= 2) and (Dir[1] = '"') and (Dir[Length(Dir)] = '"') then Dir := Copy(Dir, 2, Length(Dir) - 2);
      if not (((Length(Dir) >= 3) and (Dir[2] = ':') and (Dir[3] = '\')) or (Copy(Dir, 1, 2) = '\\')) then Continue;
      if Dir[Length(Dir)] <> '\' then Dir := Dir + '\';
      if FileExistsW(Dir + Name) then
      begin
        Result := Dir + Name;
        Exit;
      end;
    end;
end;

function FindGitExe(const Configured: WideString): WideString;
const
  KEY_WOW64_64KEY = $0100;
var
  R: TRegistry;
  Dir: string;
  Candidates: array[0..2] of WideString;
  I: Integer;
begin
  Result := Configured;
  if (Result <> '') and FileExistsW(Result) then Exit;
  Result := FindOnPath('git.exe');
  if Result <> '' then Exit;
  { Git for Windows writes its folder into the 64-bit registry. OpenKey keeps the flag for it;
    Delphi 7's OpenKeyReadOnly opens with KEY_READ alone, the 32-bit view }
  R := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKey('SOFTWARE\GitForWindows', False) then
    begin
      Dir := R.ReadString('InstallPath');
      R.CloseKey;
      if Dir <> '' then
      begin
        Result := CodePageToWide(IncludeTrailingPathDelimiter(Dir) + 'cmd\git.exe', CP_ACP);
        if FileExistsW(Result) then Exit;
      end;
    end;
  finally
    R.Free;
  end;
  Candidates[0] := EnvW('ProgramW6432');
  Candidates[1] := EnvW('ProgramFiles');
  Candidates[2] := EnvW('LOCALAPPDATA');
  if Candidates[2] <> '' then Candidates[2] := Candidates[2] + '\Programs';
  for I := 0 to High(Candidates) do
    if Candidates[I] <> '' then
    begin
      Result := Candidates[I] + '\Git\cmd\git.exe';
      if FileExistsW(Result) then Exit;
    end;
  Result := '';
end;

constructor TGit.Create(const AExe: WideString);
begin
  inherited Create;
  FExe := AExe;
  FEnv := TStringList.Create;
  FEnv.Add('GIT_TERMINAL_PROMPT=0');
  FEnv.Add('GIT_OPTIONAL_LOCKS=0');
  FEnv.Add('GIT_EDITOR=true');
  FEnv.Add('GIT_MERGE_AUTOEDIT=no');
  FEnv.Add('GIT_PAGER=cat');
end;

destructor TGit.Destroy;
begin
  FEnv.Free;
  inherited;
end;

function TGit.Run(const Dir: string; const Args: array of string; out Output, Errors: string;
  TimeoutMs: Cardinal; Cancelled: TKitCancelQuery): Integer;
var
  Cmd: WideString;
  I: Integer;
begin
  { what the user's configuration must not change in what is read back }
  Cmd := QuoteArg(FExe) + ' --no-pager -c core.quotepath=off -c color.ui=never -c log.showSignature=false' +
    ' -c log.showRoot=true -c i18n.logOutputEncoding=UTF-8';
  for I := 0 to High(Args) do Cmd := Cmd + ' ' + QuoteArg(Utf8ToWide(Args[I]));
  Result := RunProcess(Cmd, Utf8ToWide(Dir), FEnv, False, Output, Errors, TimeoutMs, Cancelled);
end;

{ git's message of a failure: that it was stopped (its output so far says nothing of that), else
  what it wrote to stderr, else to stdout, else the exit code }
function FailureText(const Args: array of string; Code: Integer; const Output, Errors: string): string;
var
  Cmd: string;
begin
  { the command itself, past the global options (--literal-pathspecs ...) }
  Cmd := '';
  if Length(Args) > 0 then Cmd := Args[0];
  if (Length(Args) > 1) and KitStartsWith(Cmd, '--') then Cmd := Args[1];
  if Code < 0 then Result := Format('git %s was stopped.', [Cmd])
  else
  begin
    Result := Trim(Errors);
    if Result = '' then Result := Trim(Output);
    if Result = '' then Result := Format('git %s ended with the exit code %d.', [Cmd, Code]);
  end;
  Result := Utf8ToIde(NormalizeNewLines(Result, #13#10));
end;

function TGit.Exec(const Dir: string; const Args: array of string; Cancelled: TKitCancelQuery;
  TimeoutMs: Cardinal): string;
var
  Errors: string;
  Code: Integer;
begin
  Code := Run(Dir, Args, Result, Errors, TimeoutMs, Cancelled);
  if Code <> 0 then raise EGitError.Create(FailureText(Args, Code, Result, Errors));
end;

function TGit.Version: string;
var
  Errors: string;
begin
  if Run('', ['--version'], Result, Errors) <> 0 then Result := '';
  Result := Trim(Result);
end;

{ ---------------------------------------------------------------- status }

function TGitChange.Staged: Boolean;
begin
  Result := not Conflict and (X <> '.') and (X <> '?');
end;

function TGitChange.Unstaged: Boolean;
begin
  Result := not Conflict and (Y <> '.') and (Y <> '?');
end;

function TGitChange.Untracked: Boolean;
begin
  Result := X = '?';
end;

function TGitChange.IsKind(Kind: TGitChangeKind): Boolean;
begin
  case Kind of
    ckStaged: Result := Staged;
    ckUnstaged: Result := Unstaged;
    ckUntracked: Result := Untracked;
  else
    Result := Conflict;
  end;
end;

constructor TGitStatus.Create;
begin
  inherited Create;
  FChanges := TObjectList.Create(True);
end;

destructor TGitStatus.Destroy;
begin
  FChanges.Free;
  inherited;
end;

procedure TGitStatus.Clear;
begin
  FChanges.Clear;
  Branch := '';
  Head := '';
  Upstream := '';
  Ahead := 0;
  Behind := 0;
  Stashes := 0;
  Key := '';
end;

function TGitStatus.Add: TGitChange;
begin
  Result := TGitChange.Create;
  FChanges.Add(Result);
end;

function TGitStatus.Count: Integer;
begin
  Result := FChanges.Count;
end;

function TGitStatus.GetChange(Index: Integer): TGitChange;
begin
  Result := TGitChange(FChanges[Index]);
end;

function TGitStatus.CountKind(Kind: TGitChangeKind): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Changes[I].IsKind(Kind) then Inc(Result);
end;

function TGitStatus.CountStaged: Integer;
begin
  Result := CountKind(ckStaged);
end;

function TGitStatus.CountUnstaged: Integer;
begin
  Result := CountKind(ckUnstaged);
end;

function TGitStatus.CountUntracked: Integer;
begin
  Result := CountKind(ckUntracked);
end;

function TGitStatus.CountConflicts: Integer;
begin
  Result := CountKind(ckConflict);
end;

{ git status --porcelain=v2 --branch --show-stash -z: records ending in NUL - headers '# name
  value', entries '1 XY ... path', '2 XY ... score path' NUL 'origPath', 'u XY ... path', '? path' }
procedure ParseStatus(const Output: string; Status: TGitStatus);
var
  L: TStringList;
  I: Integer;
  S, V: string;
  C: TGitChange;
  B: TKitStringBuilder;
begin
  Status.Clear;
  L := TStringList.Create;
  B := TKitStringBuilder.Create;
  try
    SplitAt(Output, #0, L);
    I := 0;
    while I < L.Count do
    begin
      S := L[I];
      Inc(I);
      if S = '' then Continue;
      B.Append(S);
      B.AppendChar(#1);
      case S[1] of
        '#':
          begin
            V := AfterFields(S, 2);
            if KitStartsWith(S, '# branch.oid ') then
            begin
              if V <> '(initial)' then Status.Head := V;
            end
            else if KitStartsWith(S, '# branch.head ') then
            begin
              if V <> '(detached)' then Status.Branch := V;
            end
            else if KitStartsWith(S, '# branch.upstream ') then Status.Upstream := V
            else if KitStartsWith(S, '# branch.ab ') then
            begin
              Status.Ahead := StrToIntDef(Copy(FieldOf(S, 2), 2, MaxInt), 0);
              Status.Behind := StrToIntDef(Copy(FieldOf(S, 3), 2, MaxInt), 0);
            end
            else if KitStartsWith(S, '# stash ') then Status.Stashes := StrToIntDef(V, 0);
          end;
        '1', '2', 'u':
          if Length(S) >= 4 then
          begin
            C := Status.Add;
            C.X := S[3];
            C.Y := S[4];
            case S[1] of
              '1': C.Path := AfterFields(S, 8);
              '2':
                begin
                  C.Path := AfterFields(S, 9);
                  if I < L.Count then
                  begin
                    C.OrigPath := L[I];
                    B.Append(L[I]);
                    B.AppendChar(#1);
                    Inc(I);
                  end;
                end;
              'u':
                begin
                  C.Path := AfterFields(S, 10);
                  C.Conflict := True;
                end;
            end;
          end;
        '?':
          begin
            C := Status.Add;
            C.X := '?';
            C.Y := '?';
            C.Path := Copy(S, 3, MaxInt);
          end;
      end;
    end;
    Status.Key := B.Text;
  finally
    B.Free;
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- branches, log, stashes }

{ git for-each-ref --format=%(HEAD)%00%(refname)%00%(refname:short)%00%(upstream:short)%00
  %(upstream:track)%00%(objectname:short)%00%(contents:subject): a line per ref }
procedure ParseBranches(const Output: string; List: TObjectList);
var
  Lines, F: TStringList;
  I: Integer;
  B: TGitBranch;
begin
  List.Clear;
  Lines := TStringList.Create;
  F := TStringList.Create;
  try
    SplitLinesLF(Output, Lines);
    for I := 0 to Lines.Count - 1 do
    begin
      SplitAt(Lines[I] + #0, #0, F);
      if F.Count < 7 then Continue;
      { origin/HEAD names the remote's default branch: not a branch of its own }
      if (Copy(F[1], 1, 13) = 'refs/remotes/') and (Copy(F[1], Length(F[1]) - 4, 5) = '/HEAD') then Continue;
      B := TGitBranch.Create;
      B.Current := F[0] = '*';
      B.Remote := Copy(F[1], 1, 13) = 'refs/remotes/';
      B.Name := F[2];
      B.Upstream := F[3];
      B.Track := F[4];
      B.Commit := F[5];
      B.Subject := F[6];
      List.Add(B);
    end;
  finally
    F.Free;
    Lines.Free;
  end;
end;

{ git log -z --format=%H%x1f%h%x1f%P%x1f%an%x1f%ae%x1f%at%x1f%D%x1f%s: a record per commit (its
  fields separated by #31). With --name-status a file's state follows its commit's record: LF and
  the state, then its path - a rename's old and new one - each ending with NUL }
procedure ParseLog(const Output: string; List: TObjectList);
var
  Recs, F: TStringList;
  I: Integer;
  C: TGitCommit;
  S: string;
begin
  Recs := TStringList.Create;
  F := TStringList.Create;
  try
    SplitAt(Output, #0, Recs);
    C := nil;
    I := 0;
    while I < Recs.Count do
    begin
      S := Recs[I];
      Inc(I);
      while (S <> '') and (S[1] in [#10, #13]) do Delete(S, 1, 1);
      if S = '' then Continue;
      if Pos(#31, S) = 0 then
      begin
        { a state: the file's name in the commit before }
        if (C <> nil) and (S[1] in ['A', 'C', 'D', 'M', 'R', 'T']) and (I < Recs.Count) then
        begin
          if S[1] in ['R', 'C'] then
          begin
            C.OrigPath := Recs[I];
            Inc(I);
          end;
          if I < Recs.Count then C.Path := Recs[I];
          Inc(I);
        end;
        Continue;
      end;
      SplitAt(S + #31, #31, F);
      C := nil;
      if F.Count < 8 then Continue;
      C := TGitCommit.Create;
      C.Id := F[0];
      C.ShortId := F[1];
      C.Parents := F[2];
      C.Author := F[3];
      C.Email := F[4];
      C.Time := StrToInt64Def(F[5], 0);
      C.Refs := F[6];
      C.Subject := F[7];
      List.Add(C);
    end;
  finally
    F.Free;
    Recs.Free;
  end;
end;

{ --name-status -z: 'M' NUL path NUL, 'R100' NUL old NUL new NUL ... }
procedure ParseNameStatus(const Output: string; List: TObjectList);
var
  L: TStringList;
  I: Integer;
  S: string;
  F: TGitFileChange;
begin
  List.Clear;
  L := TStringList.Create;
  try
    SplitAt(Output, #0, L);
    I := 0;
    while I < L.Count do
    begin
      S := L[I];
      Inc(I);
      while (S <> '') and (S[1] in [#10, #13]) do Delete(S, 1, 1);
      if (S = '') or not (S[1] in ['A', 'C', 'D', 'M', 'R', 'T', 'U', 'X']) or (I >= L.Count) then Continue;
      F := TGitFileChange.Create;
      F.State := S[1];
      if S[1] in ['R', 'C'] then
      begin
        F.OrigPath := L[I];
        Inc(I);
        if I < L.Count then F.Path := L[I];
        Inc(I);
      end
      else
      begin
        F.Path := L[I];
        Inc(I);
      end;
      List.Add(F);
    end;
  finally
    L.Free;
  end;
end;

{ git stash list --format=%gd%x1f%ct%x1f%gs: a line per stash }
procedure ParseStashes(const Output: string; List: TObjectList);
var
  Lines, F: TStringList;
  I: Integer;
  S: TGitStash;
begin
  List.Clear;
  Lines := TStringList.Create;
  F := TStringList.Create;
  try
    SplitLinesLF(Output, Lines);
    for I := 0 to Lines.Count - 1 do
    begin
      SplitAt(Lines[I] + #31, #31, F);
      if (F.Count < 3) or (F[0] = '') then Continue;
      S := TGitStash.Create;
      S.Ref := F[0];
      S.Time := StrToInt64Def(F[1], 0);
      S.Message := F[2];
      List.Add(S);
    end;
  finally
    F.Free;
    Lines.Free;
  end;
end;

{ ---------------------------------------------------------------- diffs }

procedure TGitDiff.Clear;
begin
  FLines := nil;
  FCount := 0;
  FFileLine := -1;
  Added := 0;
  Removed := 0;
  Hunks := 0;
  Files := 0;
end;

function TGitDiff.GetLine(Index: Integer): TGitDiffLine;
begin
  Result := FLines[Index];
end;

procedure TGitDiff.Add(Kind: TGitDiffKind; OldLine, NewLine: Integer; const Text: string);
begin
  if FCount = Length(FLines) then SetLength(FLines, FCount * 2 + 64);
  FLines[FCount].Kind := Kind;
  FLines[FCount].OldLine := OldLine;
  FLines[FCount].NewLine := NewLine;
  FLines[FCount].Text := Text;
  case Kind of
    gdFile:
      begin
        FFileLine := FCount;
        Inc(Files);
      end;
    gdHunk: Inc(Hunks);
    gdRemoved: Inc(Removed);
    gdAdded: Inc(Added);
  end;
  Inc(FCount);
end;

procedure TGitDiff.SetFilePath(const Path: string);
begin
  if FFileLine >= 0 then FLines[FFileLine].Text := Path;
end;

procedure TGitDiff.AddWholeFile(const Path, Text: string);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    SplitLinesLF(Text, L);
    Add(gdFile, 0, 0, Path);
    Add(gdNote, 0, 0, 'Untracked file');
    if L.Count = 0 then Exit;
    Add(gdHunk, 0, 0, Format('@@ -0,0 +1,%d @@', [L.Count]));
    for I := 0 to L.Count - 1 do Add(gdAdded, 0, I + 1, L[I]);
  finally
    L.Free;
  end;
end;

{ the path of a header line's name: C quotes read back, the prefix a/ or b/ dropped }
function DiffName(const S: string): string;
begin
  Result := UnquoteC(S);
  if KitStartsWith(Result, 'a/') or KitStartsWith(Result, 'b/') then Delete(Result, 1, 2);
end;

{ the name of a '--- ' or '+++ ' line: git ends it with a tab when it holds a space (a tab in a name
  is written \t) }
function MarkerName(const S: string): string;
begin
  Result := Copy(S, 5, MaxInt);
  if (Result <> '') and (Result[Length(Result)] = #9) then SetLength(Result, Length(Result) - 1);
end;

{ the new name of 'diff --git a/X b/Y' (Rest: 'a/X b/Y'). Unquoted, the names are the same unless
  the file was renamed or copied (its 'rename to' / 'copy to' line names it then): the middle of the
  pair, as git's apply reads it. Quoted, the second token }
function HeaderName(const Rest: string): string;
var
  I, N: Integer;
begin
  if KitStartsWith(Rest, '"') then
  begin
    I := 2;
    while (I <= Length(Rest)) and (Rest[I] <> '"') do
    begin
      if Rest[I] = '\' then Inc(I);
      Inc(I);
    end;
    Result := DiffName(TrimLeft(Copy(Rest, I + 1, MaxInt)));
    Exit;
  end;
  N := (Length(Rest) - 5) div 2;
  if (N > 0) and (Length(Rest) = 2 * N + 5) and (Copy(Rest, 3, N) = Copy(Rest, N + 6, N)) then
    Result := Copy(Rest, 3, N)
  else
  begin
    { names that differ: what follows the last ' b/' }
    I := Length(Rest) - 2;
    while (I > 0) and (Copy(Rest, I, 3) <> ' b/') do Dec(I);
    if I > 0 then Result := UnquoteC(Copy(Rest, I + 3, MaxInt)) else Result := DiffName(Rest);
  end;
end;

procedure ParseDiff(const Output: string; Diff: TGitDiff);
var
  L: TStringList;
  I, OldNo, NewNo: Integer;
  S, Name: string;
  Utf8, InHunk: Boolean;

  { '@@ -a,b +c,d @@': the first lines a and c }
  procedure HunkStart(const H: string; out A, C: Integer);

    { the number after Mark in H, up to a blank or a comma; 0 when there is no Mark }
    function NumberAfter(const Mark: string): Integer;
    var
      P: Integer;
      T: string;
    begin
      Result := 0;
      P := Pos(Mark, H);
      if P = 0 then Exit;
      T := Copy(H, P + Length(Mark), MaxInt);
      T := Copy(T, 1, Pos(' ', T + ' ') - 1);
      if Pos(',', T) > 0 then T := Copy(T, 1, Pos(',', T) - 1);
      Result := StrToIntDef(T, 0);
    end;

  begin
    A := NumberAfter('-');
    C := NumberAfter(' +');
  end;

begin
  Diff.Clear;
  L := TStringList.Create;
  try
    SplitLinesLF(Output, L);
    Utf8 := True;
    InHunk := False;
    OldNo := 0;
    NewNo := 0;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      if KitStartsWith(S, 'diff --git ') then
      begin
        InHunk := False;
        Utf8 := LinesAreUtf8(L, I + 1, [' ', '-', '+'], 'diff --git ');
        Diff.Add(gdFile, 0, 0, HeaderName(Copy(S, 12, MaxInt)));
        Continue;
      end;
      if not InHunk or ((S <> '') and not (S[1] in [' ', '-', '+', '\'])) then
      begin
        InHunk := False;
        if KitStartsWith(S, '@@ ') then
        begin
          HunkStart(S, OldNo, NewNo);
          Diff.Add(gdHunk, OldNo, NewNo, S);
          InHunk := True;
        end
        else if KitStartsWith(S, '+++ ') then
        begin
          Name := MarkerName(S);
          if Name <> '/dev/null' then Diff.SetFilePath(DiffName(Name));
        end
        else if KitStartsWith(S, '--- ') then
        begin
          { a deleted file has no new name: the old one (after its note) }
          Name := MarkerName(S);
          if (Name <> '/dev/null') and (Diff.Count > 0) and (Diff[Diff.Count - 1].Kind <> gdFile) then
            Diff.SetFilePath(DiffName(Name));
        end
        else if KitStartsWith(S, 'new file mode ') then Diff.Add(gdNote, 0, 0, 'New file')
        else if KitStartsWith(S, 'deleted file mode ') then Diff.Add(gdNote, 0, 0, 'Deleted file')
        else if KitStartsWith(S, 'rename from ') then
          Diff.Add(gdNote, 0, 0, 'Renamed from ' + UnquoteC(Copy(S, 13, MaxInt)))
        else if KitStartsWith(S, 'rename to ') then Diff.SetFilePath(UnquoteC(Copy(S, 11, MaxInt)))
        else if KitStartsWith(S, 'copy from ') then
          Diff.Add(gdNote, 0, 0, 'Copied from ' + UnquoteC(Copy(S, 11, MaxInt)))
        else if KitStartsWith(S, 'copy to ') then Diff.SetFilePath(UnquoteC(Copy(S, 9, MaxInt)))
        else if KitStartsWith(S, 'new mode ') then Diff.Add(gdNote, 0, 0, 'Mode changed')
        else if KitStartsWith(S, 'Binary files ') or (S = 'GIT binary patch') then
          Diff.Add(gdNote, 0, 0, 'Binary file');
        Continue;
      end;
      if S = '' then
      begin
        { an empty context line whose space was trimmed by something in between }
        Diff.Add(gdSame, OldNo, NewNo, '');
        Inc(OldNo);
        Inc(NewNo);
        Continue;
      end;
      case S[1] of
        ' ':
          begin
            Diff.Add(gdSame, OldNo, NewNo, FileLinesToUtf8(Copy(S, 2, MaxInt), Utf8));
            Inc(OldNo);
            Inc(NewNo);
          end;
        '-':
          begin
            Diff.Add(gdRemoved, OldNo, 0, FileLinesToUtf8(Copy(S, 2, MaxInt), Utf8));
            Inc(OldNo);
          end;
        '+':
          begin
            Diff.Add(gdAdded, 0, NewNo, FileLinesToUtf8(Copy(S, 2, MaxInt), Utf8));
            Inc(NewNo);
          end;
        '\': Diff.Add(gdNote, 0, 0, 'No line break at the end of the file');
      end;
    end;
  finally
    L.Free;
  end;
end;
{ ---------------------------------------------------------------- blame }

function TGitBlameCommit.Uncommitted: Boolean;
begin
  Result := Id = GitZeroId;
end;

constructor TGitBlame.Create;
begin
  inherited Create;
  FCommits := TObjectList.Create(True);
  FIndex := TStringList.Create;
  FIndex.CaseSensitive := True;
  FIndex.Sorted := True;
end;

destructor TGitBlame.Destroy;
begin
  FIndex.Free;
  FCommits.Free;
  inherited;
end;

procedure TGitBlame.Clear;
begin
  FIndex.Clear;
  FCommits.Clear;
  FLines := nil;
  FCount := 0;
end;

function TGitBlame.CommitCount: Integer;
begin
  Result := FCommits.Count;
end;

function TGitBlame.GetLine(Index: Integer): TGitBlameLine;
begin
  Result := FLines[Index];
end;

function TGitBlame.CommitOf(const Id: string): TGitBlameCommit;
var
  I: Integer;
begin
  if FIndex.Find(Id, I) then
  begin
    Result := TGitBlameCommit(FIndex.Objects[I]);
    Exit;
  end;
  Result := TGitBlameCommit.Create;
  Result.Id := Id;
  FCommits.Add(Result);
  FIndex.AddObject(Id, Result);
end;

procedure TGitBlame.Add(Commit: TGitBlameCommit; Line: Integer; const Text: string);
begin
  if FCount = Length(FLines) then SetLength(FLines, FCount * 2 + 64);
  FLines[FCount].Commit := Commit;
  FLines[FCount].Line := Line;
  FLines[FCount].Text := Text;
  FLines[FCount].First := (FCount = 0) or (FLines[FCount - 1].Commit <> Commit);
  Inc(FCount);
end;

{ git blame --porcelain: per line '<id> <orig> <final>[ <count>]', the commit's 'key value' lines
  the first time it appears, then the line itself after a tab }
procedure ParseBlame(const Output: string; Blame: TGitBlame);
var
  L: TStringList;
  I, LineNo: Integer;
  S: string;
  C: TGitBlameCommit;
  Utf8: Boolean;
begin
  Blame.Clear;
  L := TStringList.Create;
  try
    SplitLinesLF(Output, L);
    Utf8 := LinesAreUtf8(L, 0, [#9], '');
    I := 0;
    while I < L.Count do
    begin
      S := L[I];
      Inc(I);
      if (Length(S) < 40) or (S[1] = #9) then Continue;
      C := Blame.CommitOf(Copy(S, 1, 40));
      LineNo := StrToIntDef(FieldOf(S, 2), 0);
      while (I < L.Count) and ((L[I] = '') or (L[I][1] <> #9)) do
      begin
        S := L[I];
        if KitStartsWith(S, 'author ') then C.Author := Copy(S, 8, MaxInt)
        else if KitStartsWith(S, 'author-time ') then C.Time := StrToInt64Def(Copy(S, 13, MaxInt), 0)
        else if KitStartsWith(S, 'summary ') then C.Summary := Copy(S, 9, MaxInt);
        Inc(I);
      end;
      if I < L.Count then
      begin
        Blame.Add(C, LineNo, FileLinesToUtf8(Copy(L[I], 2, MaxInt), Utf8));
        Inc(I);
      end;
    end;
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- TGitRepo }

{ git's '/' path as Windows writes it }
function WindowsPath(const S: string): string;
begin
  Result := StringReplace(Trim(S), '/', '\', [rfReplaceAll]);
  if (Length(Result) > 3) and (Result[Length(Result)] = '\') then SetLength(Result, Length(Result) - 1);
end;

constructor TGitRepo.Create(AGit: TGit; const ARoot, AGitDir: string);
begin
  inherited Create;
  FGit := AGit;
  FRoot := ARoot;
  FGitDir := AGitDir;
end;

{ a .git - the folder of a repository, the file of a linked work tree or a submodule - in Folder or
  in a folder above it }
function GitEntryAbove(const Folder: string): Boolean;
var
  D: WideString;
  P: Integer;
begin
  Result := False;
  D := Utf8ToWide(Folder);
  while (D <> '') and (D[Length(D)] = '\') do SetLength(D, Length(D) - 1);
  while D <> '' do
  begin
    if GetFileAttributesW(PWideChar(D + '\.git')) <> $FFFFFFFF then
    begin
      Result := True;
      Exit;
    end;
    P := Length(D);
    while (P > 0) and (D[P] <> '\') do Dec(P);
    if P <= 1 then Exit;
    SetLength(D, P - 1);
  end;
end;

class function TGitRepo.Open(AGit: TGit; const Folder: string): TGitRepo;
var
  Failure: string;
begin
  Result := Open(AGit, Folder, Failure);
end;

class function TGitRepo.Open(AGit: TGit; const Folder: string; out Failure: string): TGitRepo;
var
  Output, Errors: string;
  L: TStringList;
  Code: Integer;
begin
  Result := nil;
  Failure := '';
  if (Folder = '') or not DirExistsW(Utf8ToWide(Folder)) then Exit;
  Code := AGit.Run(Folder, ['rev-parse', '--show-toplevel', '--absolute-git-dir'], Output, Errors, GitLocalTimeout,
    AGit.ReadStop);
  if Code <> 0 then
  begin
    { "not a git repository" in the user's language, or a repository git refuses: told apart by the
      .git that is there }
    if GitEntryAbove(Folder) then Failure := FailureText(['rev-parse'], Code, Output, Errors);
    Exit;
  end;
  L := TStringList.Create;
  try
    SplitLinesLF(Output, L);
    if (L.Count >= 2) and (L[0] <> '') then
      Result := TGitRepo.Create(AGit, CanonicalPath(WindowsPath(L[0])), WindowsPath(L[1]));
  finally
    L.Free;
  end;
end;

class procedure TGitRepo.Init(AGit: TGit; const Folder: string);
begin
  AGit.Exec(Folder, ['init', '-q']);
end;

function TGitRepo.Exec(const Args: array of string; Cancelled: TKitCancelQuery; TimeoutMs: Cardinal): string;
begin
  Result := FGit.Exec(FRoot, Args, Cancelled, TimeoutMs);
end;

function TGitRepo.Query(const Args: array of string): string;
begin
  Result := FGit.Exec(FRoot, Args, FGit.ReadStop);
end;

procedure TGitRepo.ExecPaths(const Args: array of string; Paths: TStrings);
var
  Name: WideString;
  B: TKitStringBuilder;
  A: TStringArray;
  I: Integer;
begin
  if Paths.Count = 0 then Exit;
  B := TKitStringBuilder.Create;
  try
    for I := 0 to Paths.Count - 1 do
    begin
      B.Append(Paths[I]);
      B.AppendChar(#0);
    end;
    Name := TempFileW('git');
    WriteFileW(Name, B.Text);
  finally
    B.Free;
  end;
  try
    A := nil;
    AddArgs(A, ['--literal-pathspecs']);
    AddArgs(A, Args);
    AddArgs(A, ['--pathspec-from-file=' + WideToUtf8(Name), '--pathspec-file-nul']);
    Exec(A);
  finally
    DeleteFileW(PWideChar(Name));
  end;
end;

function TGitRepo.State: TGitRepoState;
var
  D: WideString;
begin
  D := Utf8ToWide(FGitDir) + '\';
  if FileExistsW(D + 'MERGE_HEAD') then Result := rsMerging
  { rebase-apply is git am's too: its file applying says so }
  else if FileExistsW(D + 'rebase-apply\applying') then Result := rsApplying
  else if DirExistsW(D + 'rebase-merge') or DirExistsW(D + 'rebase-apply') then Result := rsRebasing
  else if FileExistsW(D + 'CHERRY_PICK_HEAD') then Result := rsCherryPicking
  else if FileExistsW(D + 'REVERT_HEAD') then Result := rsReverting
  else Result := rsNormal;
end;

function TGitRepo.FullPath(const Path: string): string;
begin
  { a work tree at a drive's root ends with its '\' already }
  Result := IncludeTrailingPathDelimiter(FRoot) + StringReplace(Path, '/', '\', [rfReplaceAll]);
end;

function TGitRepo.RelativePath(const FullName: string): string;
var
  R, F: string;
begin
  Result := '';
  if FullName = '' then Exit;
  R := IncludeTrailingPathDelimiter(FRoot);
  F := CanonicalPath(FullName);
  if (Length(F) > Length(R)) and SameText(Copy(F, 1, Length(R)), R) then
    Result := StringReplace(Copy(F, Length(R) + 1, MaxInt), '\', '/', [rfReplaceAll]);
end;

procedure TGitRepo.GetStatus(Status: TGitStatus);
begin
  ParseStatus(Query(['status', '--porcelain=v2', '--branch', '--show-stash', '-z', '--untracked-files=all']), Status);
end;

procedure TGitRepo.GetBranches(List: TObjectList);
begin
  ParseBranches(Query(['for-each-ref',
    '--format=%(HEAD)%00%(refname)%00%(refname:short)%00%(upstream:short)%00%(upstream:track)%00%(objectname:short)%00%(contents:subject)',
    'refs/heads', 'refs/remotes']), List);
end;

procedure TGitRepo.GetStashes(List: TObjectList);
begin
  ParseStashes(Query(['stash', 'list', '--format=%gd%x1f%ct%x1f%gs']), List);
end;

function TGitRepo.Remotes: string;
begin
  Result := Query(['remote']);
end;

procedure TGitRepo.GetLog(List: TObjectList; const Path: string; AllBranches: Boolean; Skip, Max: Integer);
var
  A: TStringArray;
  I: Integer;
  Output, Errors, Name: string;
  Code: Integer;
  Page: TObjectList;
  C: TGitCommit;
begin
  A := nil;
  AddArgs(A, ['log', '-z', '--format=%H%x1f%h%x1f%P%x1f%an%x1f%ae%x1f%at%x1f%D%x1f%s']);
  { --follow looks at the commits only after --skip counted them, so a rename among the skipped
    ones is missed: a file's history is read from its start, the first Skip dropped }
  if Path <> '' then AddArgs(A, ['--max-count=' + IntToStr(Skip + Max), '--name-status'])
  else
  begin
    AddArgs(A, ['--max-count=' + IntToStr(Max)]);
    if Skip > 0 then AddArgs(A, ['--skip=' + IntToStr(Skip)]);
  end;
  if AllBranches then AddArgs(A, ['--branches', '--remotes', '--tags']);
  if Path <> '' then AddArgs(A, ['--follow', '--', Path]);
  Code := FGit.Run(FRoot, A, Output, Errors, GitLocalTimeout, FGit.ReadStop);
  { a repository without commits has no log yet }
  if (Code <> 0) and (Pos('does not have any commits', Errors) = 0) then
    raise EGitError.Create(FailureText(A, Code, Output, Errors));
  if Path = '' then
  begin
    ParseLog(Output, List);
    Exit;
  end;
  Page := TObjectList.Create(False);
  try
    ParseLog(Output, Page);
    { the file's name in each commit, newest first: a merge has no state of its own and keeps the
      name of the commit after it; older commits have a rename's old name }
    Name := Path;
    for I := 0 to Page.Count - 1 do
    begin
      C := TGitCommit(Page[I]);
      if C.Path = '' then C.Path := Name
      else if C.OrigPath <> '' then Name := C.OrigPath
      else Name := C.Path;
    end;
    for I := 0 to Page.Count - 1 do
      if I < Skip then TObject(Page[I]).Free else List.Add(Page[I]);
  finally
    Page.Free;
  end;
end;

function TGitRepo.CommitInfo(const Id: string; out Author: string; out Time: Int64; out Refs: string): string;
var
  F: TStringList;
begin
  Author := '';
  Time := 0;
  Refs := '';
  Result := '';
  F := TStringList.Create;
  try
    SplitAt(Query(['show', '-s', '--format=%an <%ae>%x1f%at%x1f%D%x1f%B', Id]) + #31, #31, F);
    if F.Count >= 4 then
    begin
      Author := F[0];
      Time := StrToInt64Def(F[1], 0);
      Refs := F[2];
      Result := TrimRightText(F[3]);
    end;
  finally
    F.Free;
  end;
end;

procedure TGitRepo.GetCommitFiles(const Id: string; List: TObjectList);
begin
  ParseNameStatus(Query(['show', '-m', '--first-parent', '-M', '--name-status', '-z', '--format=', Id]), List);
end;

const
  DiffOptions: array[0..4] of string = ('--no-color', '--no-ext-diff', '-U3', '--src-prefix=a/', '--dst-prefix=b/');

procedure TGitRepo.GetWorkTreeDiff(const Path, OrigPath: string; Base: TGitDiffBase; Diff: TGitDiff);
var
  A: TStringArray;
begin
  A := nil;
  AddArgs(A, ['diff']);
  AddArgs(A, DiffOptions);
  { a file with a conflict against HEAD: against the index git shows a combined diff }
  case Base of
    gbStaged: AddArgs(A, ['--cached', '-M']);
    gbHead: AddArgs(A, ['HEAD']);
  end;
  AddArgs(A, ['--', Path]);
  { a rename pairs only when both its names are given }
  if OrigPath <> '' then AddArgs(A, [OrigPath]);
  ParseDiff(Query(A), Diff);
end;

procedure TGitRepo.GetCommitDiff(const Id, Path, OrigPath: string; Diff: TGitDiff);
var
  A: TStringArray;
begin
  A := nil;
  AddArgs(A, ['show', '-m', '--first-parent', '-M', '--format=']);
  AddArgs(A, DiffOptions);
  AddArgs(A, [Id]);
  if Path <> '' then
  begin
    AddArgs(A, ['--', Path]);
    if OrigPath <> '' then AddArgs(A, [OrigPath]);
  end;
  ParseDiff(Query(A), Diff);
end;

procedure TGitRepo.GetTextDiff(const Path, Bytes: string; Diff: TGitDiff);
var
  OldName, NewName: WideString;
  Old, Output, Errors: string;
  Code: Integer;
  A: TStringArray;
begin
  { HEAD's file as a checkout writes it (line ends, filters); none when HEAD does not have it }
  if FGit.Run(FRoot, ['cat-file', '--filters', 'HEAD:' + Path], Old, Errors, GitLocalTimeout, FGit.ReadStop) <> 0 then
    Old := '';
  OldName := TempFileW('old');
  NewName := TempFileW('new');
  try
    WriteFileW(OldName, Old);
    WriteFileW(NewName, Bytes);
    A := nil;
    AddArgs(A, ['diff', '--no-index']);
    AddArgs(A, DiffOptions);
    AddArgs(A, ['--', WideToUtf8(OldName), WideToUtf8(NewName)]);
    Code := FGit.Run(FRoot, A, Output, Errors, GitLocalTimeout, FGit.ReadStop);
    { 1: the files differ }
    if (Code <> 0) and (Code <> 1) then
      raise EGitError.Create(FailureText(['diff'], Code, Output, Errors));
    ParseDiff(Output, Diff);
    if Diff.Count > 0 then Diff.SetFilePath(Path);
  finally
    DeleteFileW(PWideChar(OldName));
    DeleteFileW(PWideChar(NewName));
  end;
end;

procedure TGitRepo.GetUntrackedDiff(const Path: string; Diff: TGitDiff);
var
  Name: WideString;
  D: TWin32FileAttributeData;
  Size: Int64;
  Bytes: string;
  Enc: TKitFileEncoding;
begin
  Diff.Clear;
  if (Path <> '') and (Path[Length(Path)] = '/') then
  begin
    Diff.Add(gdFile, 0, 0, Copy(Path, 1, Length(Path) - 1));
    Diff.Add(gdNote, 0, 0, 'A folder with a Git repository of its own');
    Exit;
  end;
  Name := Utf8ToWide(FullPath(Path));
  if not GetFileAttributesExW(PWideChar(Name), GetFileExInfoStandard, @D) then
    raise EGitError.CreateFmt('%s cannot be read: %s', [Utf8ToIde(Path), SysErrorMessage(GetLastError)]);
  Size := Int64(D.nFileSizeHigh) shl 32 or D.nFileSizeLow;
  if Size > MaxUntrackedSize then
  begin
    Diff.Add(gdFile, 0, 0, Path);
    Diff.Add(gdNote, 0, 0, Format('Untracked file of %d KB: too large to show', [Size div 1024]));
    Exit;
  end;
  Bytes := ReadFileW(Name);
  { git's test: a NUL among the first 8000 bytes }
  if Pos(#0, Copy(Bytes, 1, 8000)) > 0 then
  begin
    Diff.Add(gdFile, 0, 0, Path);
    Diff.Add(gdNote, 0, 0, 'Untracked binary file');
    Exit;
  end;
  Diff.AddWholeFile(Path, DecodeText(Bytes, Enc));
end;

procedure TGitRepo.GetBlame(const Path, Bytes: string; HasBytes: Boolean; Blame: TGitBlame);
var
  Name: WideString;
begin
  if not HasBytes then
  begin
    ParseBlame(Query(['blame', '--porcelain', '--', Path]), Blame);
    Exit;
  end;
  Name := TempFileW('blm');
  try
    WriteFileW(Name, Bytes);
    ParseBlame(Query(['blame', '--porcelain', '--contents', WideToUtf8(Name), '--', Path]), Blame);
  finally
    DeleteFileW(PWideChar(Name));
  end;
end;

function TGitRepo.LastMessage: string;
var
  Output, Errors: string;
begin
  if FGit.Run(FRoot, ['log', '-1', '--format=%B'], Output, Errors, GitLocalTimeout, FGit.ReadStop) <> 0 then Output := '';
  Result := TrimRightText(Output);
end;

procedure TGitRepo.Stage(Paths: TStrings);
begin
  ExecPaths(['add', '-A'], Paths);
end;

procedure TGitRepo.StageTracked;
begin
  Exec(['add', '-u']);
end;

procedure TGitRepo.Unstage(Paths: TStrings);
var
  Output, Errors: string;
begin
  { before the first commit there is no HEAD to take the files back from: they leave the index }
  if FGit.Run(FRoot, ['rev-parse', '--verify', '-q', 'HEAD'], Output, Errors) <> 0 then
    ExecPaths(['rm', '--cached', '-r', '-q'], Paths)
  else
    ExecPaths(['restore', '--staged'], Paths);
end;

procedure TGitRepo.Discard(Paths: TStrings);
begin
  ExecPaths(['restore', '--worktree'], Paths);
end;

procedure TGitRepo.DeleteUntracked(Paths: TStrings);
var
  I: Integer;
  Name: WideString;
  Kept: string;
begin
  Kept := '';
  for I := 0 to Paths.Count - 1 do
  begin
    { a folder that git lists whole holds a repository of its own: never deleted from here }
    if (Paths[I] <> '') and (Paths[I][Length(Paths[I])] = '/') then
    begin
      Kept := Kept + #13#10 + '    ' + Utf8ToIde(Copy(Paths[I], 1, Length(Paths[I]) - 1));
      Continue;
    end;
    Name := Utf8ToWide(FullPath(Paths[I]));
    if FileExistsW(Name) and not DeleteFileW(PWideChar(Name)) then
      raise EGitError.CreateFmt('%s cannot be deleted: %s', [Utf8ToIde(Paths[I]), SysErrorMessage(GetLastError)]);
  end;
  if Kept <> '' then
    raise EGitError.Create('These folders hold a Git repository of their own; they were not deleted:' + Kept);
end;

procedure TGitRepo.Commit(const Message: string; Amend: Boolean);
var
  Name: WideString;
begin
  Name := TempFileW('msg');
  try
    WriteFileW(Name, NormalizeNewLines(Message, #10) + #10);
    if Amend then Exec(['commit', '-q', '--amend', '-F', WideToUtf8(Name)])
    else Exec(['commit', '-q', '-F', WideToUtf8(Name)]);
  finally
    DeleteFileW(PWideChar(Name));
  end;
end;

procedure TGitRepo.Fetch(Cancelled: TKitCancelQuery);
begin
  Exec(['fetch', '--all', '--prune'], Cancelled, GitNetworkTimeout);
end;

procedure TGitRepo.Pull(Cancelled: TKitCancelQuery);
begin
  Exec(['pull', '--no-edit'], Cancelled, GitNetworkTimeout);
end;

procedure TGitRepo.Push(const Remote: string; Cancelled: TKitCancelQuery);
begin
  if Remote <> '' then Exec(['push', '-u', Remote, 'HEAD'], Cancelled, GitNetworkTimeout)
  else Exec(['push'], Cancelled, GitNetworkTimeout);
end;

procedure TGitRepo.Switch(const Branch: string; Remote: Boolean);
begin
  if Remote then Exec(['switch', '--track', Branch]) else Exec(['switch', Branch]);
end;

procedure TGitRepo.CreateBranch(const Name, StartPoint: string; SwitchTo: Boolean);
var
  A: TStringArray;
begin
  A := nil;
  if SwitchTo then AddArgs(A, ['switch', '-c', Name]) else AddArgs(A, ['branch', Name]);
  if StartPoint <> '' then AddArgs(A, [StartPoint]);
  Exec(A);
end;

procedure TGitRepo.DeleteBranch(const Name: string; Force: Boolean);
begin
  if Force then Exec(['branch', '-D', Name]) else Exec(['branch', '-d', Name]);
end;

function TGitRepo.ValidBranchName(const Name: string): Boolean;
var
  Output, Errors: string;
begin
  Result := (Name <> '') and (FGit.Run(FRoot, ['check-ref-format', '--branch', Name], Output, Errors) = 0);
end;

procedure TGitRepo.StashPush(const Message: string; Untracked: Boolean);
var
  A: TStringArray;
begin
  A := nil;
  AddArgs(A, ['stash', 'push']);
  if Untracked then AddArgs(A, ['-u']);
  if Message <> '' then AddArgs(A, ['-m', Message]);
  Exec(A);
end;

procedure TGitRepo.StashPop;
begin
  Exec(['stash', 'pop']);
end;

procedure TGitRepo.StashApply(const Ref: string);
begin
  Exec(['stash', 'apply', Ref]);
end;

procedure TGitRepo.StashDrop(const Ref: string);
begin
  Exec(['stash', 'drop', Ref]);
end;

procedure TGitRepo.AbortOperation;
begin
  case State of
    rsMerging: Exec(['merge', '--abort']);
    rsRebasing: Exec(['rebase', '--abort']);
    rsCherryPicking: Exec(['cherry-pick', '--abort']);
    rsReverting: Exec(['revert', '--abort']);
    rsApplying: Exec(['am', '--abort']);
  end;
end;

end.
