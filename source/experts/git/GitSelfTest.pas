{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitSelfTest;

{ The Git expert's self-test in the IDE: with GITEXPERT_SELFTEST_LOG set, Tools |
  Git Self-Test opens the scratch project of GITEXPERT_SELFTEST_DIR - a new Git repository with
  Project1.dpr, Unit1.pas and its form, nothing committed - and works with it through the views'
  own actions and the editor's commands: stage, commit, the history, an edit and its diff, the editor's
  diff and blame of unsaved text, unstage, branches, stashes (the editor reading the file again),
  discard, an untracked file deleted, a failure reported, another project in a folder of no
  repository and the first one again (the views follow), a change of the form alone discarded (the
  IDE reads the form again). With GITEXPERT_SELFTEST_DIALOGS set it then
  makes changes of every kind, shows a diff, and shows the dialogs New Branch, Stash Changes and
  Settings in turn (the test that starts it takes the pictures and closes the dialogs). The questions the
  views ask are answered
  yes (GitHost.GitAsk) and failures are logged (GitHost.GitError): no message box stops it. Between
  the steps it waits, the IDE's messages going on, until no git command runs. Each check writes PASS
  or FAIL to the log, the last line is DONE. It starts from a timer, so that the menu command returns
  at once. }

interface

procedure StartGitSelfTest;
procedure StopGitSelfTest;

implementation

uses
  Windows, Messages, SysUtils, Classes, Forms, ExtCtrls, Menus, ActnList, TypInfo, ToolsAPI, GitText, GitCore,
  GitHost, GitIde, GitUI, GitChanges, GitHistory, GitDiff, GitBranchDlg, GitStashDlg, GitSettingsDlg;

type
  TGitSelfTest = class(TKitSelfTest)
  private
    FAsked: Integer;
    FLastError: string;
    { the IDE's messages go on until no git command has run for a while }
    procedure WaitIdle(TimeoutMs: Cardinal = 30000);
    { the IDE's messages go on for Ms (a timer of the host's has to fire first) }
    procedure Pause(Ms: Cardinal);
    function Host: TGitHost;
    function IdeAction(const Name: string): TContainedAction;
    function FindChange(const Path: string; out C: TGitChange): Boolean;
    procedure RunChecks;
    procedure ShowForPictures;
  protected
    { the checks, the host's questions and messages answered by the test (TestAsk, TestError) }
    procedure Run; override;
    { for screenshots: ShowForPictures when GITEXPERT_SELFTEST_DIALOGS is set }
    procedure Finished; override;
  public
    destructor Destroy; override;
  end;

var
  Test: TGitSelfTest;

function TestAsk(const Text: string; Buttons: Integer): Integer;
begin
  if Test <> nil then
  begin
    Inc(Test.FAsked);
    Test.Say('NOTE asked: ' + StringReplace(Text, #13#10, ' | ', [rfReplaceAll]));
  end;
  Result := IDYES;
end;

procedure TestError(const Text: string);
begin
  if Test = nil then Exit;
  Test.FLastError := Text;
  Test.Say('NOTE message: ' + StringReplace(Text, #13#10, ' | ', [rfReplaceAll]));
end;

procedure StartGitSelfTest;
begin
  if Test <> nil then Exit;
  Test := TGitSelfTest.Create('GITEXPERT_SELFTEST_LOG', 'GITEXPERT_SELFTEST_DIR');
end;

procedure StopGitSelfTest;
begin
  FreeAndNil(Test);
end;

destructor TGitSelfTest.Destroy;
begin
  GitAsk := nil;
  GitError := nil;
  inherited;
end;

procedure TGitSelfTest.Run;
begin
  GitAsk := TestAsk;
  GitError := TestError;
  try
    RunChecks;
  finally
    GitAsk := nil;
    GitError := nil;
  end;
end;

{ the test that starts it closes each dialog }
procedure TGitSelfTest.Finished;
begin
  if GetEnvironmentVariable('GITEXPERT_SELFTEST_DIALOGS') = '' then Exit;
  try
    ShowForPictures;
  except
    on E: Exception do Say('FAIL pictures: ' + E.ClassName + ': ' + E.Message);
  end;
end;

{ changes of every kind - a file changed on disk, one staged, one untracked -, a second branch and
  the diff of the changed file in the views; PICTURES in the log; then the dialogs in turn }
procedure TGitSelfTest.ShowForPictures;
var
  Name, Start, Msg: string;
  SwitchTo, Untracked: Boolean;
  L: TStringList;
begin
  GitAsk := TestAsk;
  GitError := TestError;
  WriteFileW(CodePageToWide(FDir + 'Unit1.pas', CP_ACP), ReadFileW(CodePageToWide(FDir + 'Unit1.pas', CP_ACP)) +
    '// a change on disk'#13#10);
  WriteFileW(CodePageToWide(FDir + 'Notes.txt', CP_ACP), 'notes'#13#10);
  WriteFileW(CodePageToWide(FDir + 'Second.pas', CP_ACP), 'unit Second;'#13#10);
  L := TStringList.Create;
  try
    L.Add('Second.pas');
    Host.Stage(L);
  finally
    L.Free;
  end;
  Host.CreateBranch('feature', '', False);
  WaitIdle;
  ShowGitDiff(gkWorkTree, 'Unit1.pas', '', '', '', 'not staged');
  WaitIdle;
  GitAsk := nil;
  GitError := nil;
  Say('PICTURES');
  TGitBranchDialog.Execute('', Name, Start, SwitchTo);
  TGitStashDialog.Execute(Msg, Untracked);
  TGitSettingsDialog.Execute;
  Say('DIALOGS');
end;


procedure TGitSelfTest.WaitIdle(TimeoutMs: Cardinal);
var
  Start: Cardinal;
  Quiet: Integer;
begin
  Start := GetTickCount;
  Quiet := 0;
  repeat
    Application.ProcessMessages;
    Sleep(15);
    if Host.Busy then Quiet := 0 else Inc(Quiet);
  until (Quiet >= 12) or (GetTickCount - Start > TimeoutMs);
end;

function TGitSelfTest.Host: TGitHost;
begin
  Result := GitHostInstance;
end;

function TGitSelfTest.IdeAction(const Name: string): TContainedAction;
var
  L: TCustomActionList;
  I: Integer;
begin
  Result := nil;
  L := (BorlandIDEServices as INTAServices).ActionList;
  for I := 0 to L.ActionCount - 1 do
    if SameText(L.Actions[I].Name, Name) then
    begin
      Result := L.Actions[I];
      Exit;
    end;
end;

function TGitSelfTest.FindChange(const Path: string; out C: TGitChange): Boolean;
var
  I: Integer;
begin
  for I := 0 to Host.Status.Count - 1 do
    if Host.Status[I].Path = Path then
    begin
      C := Host.Status[I];
      Result := True;
      Exit;
    end;
  C := nil;
  Result := False;
end;

{ the caption of the form of the unit UnitFile as the IDE's designer holds it }
function FormCaption(const UnitFile: string): string;
var
  F: IOTAFormEditor;
  C: IOTAComponent;
  N: INTAComponent;
begin
  Result := '';
  F := FormEditorOf(FindModuleOf(UnitFile));
  if F = nil then Exit;
  C := F.GetRootComponent;
  if (C <> nil) and Supports(C, INTAComponent, N) and (N.GetComponent <> nil) then
    Result := GetStrProp(N.GetComponent, 'Caption');
end;

{ the number of the editor's lines that hold Sub }
function CountIn(const Text, Sub: string): Integer;
var
  P: Integer;
  S: string;
begin
  Result := 0;
  S := Text;
  P := Pos(Sub, S);
  while P > 0 do
  begin
    Inc(Result);
    Delete(S, 1, P + Length(Sub) - 1);
    P := Pos(Sub, S);
  end;
end;

{ Delphi 7's IDE writes a unit's diagram (.ddp) beside it as it saves the unit: the test's repository
  leaves those out, as a Delphi project's ignore list does (.git\info\exclude: no file of its own) }
procedure ExcludeDiagrams(const Dir: string);
var
  L: TStringList;
  F: string;
begin
  F := Dir + '.git\info\exclude';
  if not DirectoryExists(ExtractFilePath(F)) then Exit;
  L := TStringList.Create;
  try
    if FileExists(F) then L.LoadFromFile(F);
    if L.IndexOf('*.ddp') < 0 then
    begin
      L.Add('*.ddp');
      L.SaveToFile(F);
    end;
  finally
    L.Free;
  end;
end;

procedure TGitSelfTest.RunChecks;
var
  V: TGitChangesView;
  C: TGitChange;
  E: IOTASourceEditor;
  M: IOTAModule;
  I, Row: Integer;
  Text, Main, UnitFile, Other, FormFile: string;
  A: TContainedAction;
  Found: Boolean;
  F: TComponent;
begin
  Say('START');
  UnitFile := FDir + 'Unit1.pas';
  ExcludeDiagrams(FDir);
  (BorlandIDEServices as IOTAActionServices).OpenProject(FDir + 'Project1.dpr', True);
  WaitIdle;
  Check(ActiveProject <> nil, 'the scratch project is open');

  { the view of the repository: everything untracked }
  ShowGitView;
  WaitIdle;
  V := GitChangesForm;
  Check(V <> nil, 'View | Git made the view');
  if V = nil then Exit;
  Check(Host.GitFound, 'git.exe found', WideToCodePage(Host.GitExe, CP_ACP));
  Check(Host.Repo <> nil, 'the repository of the project');
  if Host.Repo = nil then Exit;
  Check(SameText(IncludeTrailingPathDelimiter(Utf8ToIde(Host.Repo.Root)), FDir), 'its work tree is the project''s folder',
    Host.Repo.Root);
  Check(FindChange('Unit1.pas', C) and C.Untracked, 'Unit1.pas is untracked');
  Check(Host.Status.CountUntracked >= 3, 'the untracked files', IntToStr(Host.Status.CountUntracked));
  Check(V.RowIndex(ggUntracked, '') >= 0, 'the Untracked Files group');
  { the status line: in D7 Studio's view's strip, in an IDE without one (Delphi 7's) the view's own }
  Check(V.StatusPanel.Visible = not KitViewStatus(V, V.StatusLabel.Caption),
    'the status line is the view''s strip in D7 Studio, else its own', V.StatusLabel.Caption);
  Check(not V.EmptyPanel.Visible and V.ChangesList.Visible, 'the list shows');

  { stage every untracked file through their group, then commit }
  V.SelectRow(V.RowIndex(ggUntracked, ''));
  V.aStage.Update;
  Check(V.aStage.Enabled, 'Stage is enabled for the group');
  V.aStage.Execute;
  WaitIdle;
  Check(Host.Status.CountStaged >= 3, 'staged', IntToStr(Host.Status.CountStaged));
  Check(V.RowIndex(ggStaged, 'Unit1.pas') >= 0, 'Unit1.pas in Staged Changes');
  V.MessageMemo.Text := 'First commit of the self-test';
  V.aCommit.Update;
  Check(V.aCommit.Enabled, 'Commit is enabled with a message');
  V.aCommit.Execute;
  WaitIdle;
  Check(Host.Status.Head <> '', 'committed');
  Check(Host.Status.Count = 0, 'nothing left to commit', IntToStr(Host.Status.Count));
  Check(V.MessageMemo.Text = '', 'the message box is empty again');
  Main := Host.Status.Branch;
  Check(Main <> '', 'on a branch', Main);

  { the history }
  ShowGitHistory('');
  WaitIdle;
  Check((GitHistoryForm <> nil) and (GitHistoryForm.Commits.Count = 1), 'the history: one commit');
  if GitHistoryForm <> nil then
  begin
    WaitIdle;
    Check(GitHistoryForm.Files.Count >= 3, 'the commit''s files', IntToStr(GitHistoryForm.Files.Count));
    Check(Pos('First commit', GitHistoryForm.InfoMemo.Text) > 0, 'the commit''s message', GitHistoryForm.InfoMemo.Text);
  end;

  { an edit in the editor, saved: Changes, then its diff }
  E := OpenSourceEditor(UnitFile);
  Check(E <> nil, 'Unit1.pas opened');
  if E = nil then Exit;
  Text := EditorText(E);
  ReplaceText(E, Pos(#10, Text), Pos(#10, Text), '// changed by the self-test'#13#10);
  M := FindModuleOf(UnitFile);
  if M <> nil then M.Save(False, True);
  Host.Refresh;
  WaitIdle;
  Check(FindChange('Unit1.pas', C) and C.Unstaged, 'the saved edit is a change');
  Row := V.RowIndex(ggChanges, 'Unit1.pas');
  Check(Row >= 0, 'Unit1.pas in Changes');
  V.SelectRow(Row);
  V.aDiff.Update;
  V.aDiff.Execute;
  WaitIdle;
  Check((GitDiffForm <> nil) and (GitDiffForm.Mode = gmDiff) and (GitDiffForm.Diff.Added = 1) and
    (GitDiffForm.Diff.Removed = 0), 'the diff of the change: one line added');

  { the editor's commands on text that is not saved }
  Text := EditorText(E);
  ReplaceText(E, Pos(#10, Text), Pos(#10, Text), '// not saved'#13#10);
  A := IdeAction('GitEditorDiffCommand');
  Check(A <> nil, 'the editor''s Diff with HEAD');
  if A <> nil then
  begin
    A.Update;
    A.Execute;
    WaitIdle;
    Check((GitDiffForm.Mode = gmDiff) and (GitDiffForm.Diff.Added = 2), 'Diff with HEAD has the unsaved line',
      IntToStr(GitDiffForm.Diff.Added));
  end;
  A := IdeAction('GitEditorBlameCommand');
  Check(A <> nil, 'the editor''s Blame');
  if A <> nil then
  begin
    A.Execute;
    WaitIdle;
    Found := False;
    for I := 0 to GitDiffForm.Blame.Count - 1 do
      if (Pos('not saved', GitDiffForm.Blame[I].Text) > 0) and GitDiffForm.Blame[I].Commit.Uncommitted then Found := True;
    Check((GitDiffForm.Mode = gmBlame) and Found, 'Blame: the unsaved line is not committed');
    Check((GitDiffForm.Blame.Count > 0) and not GitDiffForm.Blame[0].Commit.Uncommitted, 'Blame: the first line is');
  end;
  M := FindModuleOf(UnitFile);
  if M <> nil then M.Save(False, True);
  Host.Refresh;
  WaitIdle;

  { stage and unstage one file }
  V.SelectRow(V.RowIndex(ggChanges, 'Unit1.pas'));
  V.aStage.Execute;
  WaitIdle;
  Check(V.RowIndex(ggStaged, 'Unit1.pas') >= 0, 'staged one file');
  V.SelectRow(V.RowIndex(ggStaged, 'Unit1.pas'));
  V.aUnstage.Update;
  Check(V.aUnstage.Enabled, 'Unstage is enabled');
  V.aUnstage.Execute;
  WaitIdle;
  Check((V.RowIndex(ggChanges, 'Unit1.pas') >= 0) and (V.RowIndex(ggStaged, 'Unit1.pas') < 0), 'unstaged');

  { branches: one made and switched to, the menu, back }
  Host.CreateBranch('self-test', '', True);
  WaitIdle;
  Check(Host.Status.Branch = 'self-test', 'switched to the new branch', Host.Status.Branch);
  V.BranchMenu.OnPopup(V.BranchMenu);
  Found := False;
  for I := 0 to V.BranchMenu.Items.Count - 1 do
    if (Pos('self-test', V.BranchMenu.Items[I].Caption) > 0) and V.BranchMenu.Items[I].Checked then Found := True;
  Check(Found, 'the Branch menu checks the current branch');
  Host.Switch(Main, False);
  WaitIdle;
  Check(Host.Status.Branch = Main, 'switched back', Host.Status.Branch);
  Check(FindChange('Unit1.pas', C), 'the change came along');

  { a stash: the editor reads the file again }
  Host.StashPush('self-test stash', False);
  WaitIdle;
  Check((Host.Status.Count = 0) and (Host.Stashes.Count = 1), 'stashed');
  Check(CountIn(EditorText(E), 'changed by the self-test') = 0, 'the editor read the stashed file again');
  Host.StashPop;
  WaitIdle;
  Check(FindChange('Unit1.pas', C) and (Host.Stashes.Count = 0), 'popped');
  Check(CountIn(EditorText(E), 'changed by the self-test') = 1, 'the editor read the popped file again');

  { discard every change through the group's header (the question answered yes): saving the unit
    wrote its form too (D7 Studio adds Position = poDesigned) }
  FAsked := 0;
  V.SelectRow(V.RowIndex(ggChanges, ''));
  V.aDiscard.Update;
  Check(V.aDiscard.Enabled, 'Discard is enabled');
  V.aDiscard.Execute;
  WaitIdle;
  Check(FAsked = 1, 'Discard asked first');
  Check(Host.Status.Count = 0, 'discarded', IntToStr(Host.Status.Count));
  Check(CountIn(EditorText(E), 'changed by the self-test') = 0, 'the editor read the discarded file again');

  { an untracked file deleted }
  WriteFileW(CodePageToWide(FDir + 'scratch.txt', CP_ACP), 'scratch'#13#10);
  Host.Refresh;
  WaitIdle;
  Row := V.RowIndex(ggUntracked, 'scratch.txt');
  Check(Row >= 0, 'the new file is untracked');
  V.SelectRow(Row);
  V.aDiscard.Execute;
  WaitIdle;
  Check(not FileExists(FDir + 'scratch.txt'), 'the untracked file is deleted');

  { the menus }
  Check(IdeAction('GitShowCommand') <> nil, 'View | Git');
  Check(IdeAction('GitHistoryCommand') <> nil, 'View | Git History');
  Found := False;
  for I := 0 to Screen.FormCount - 1 do
  begin
    F := Screen.Forms[I].FindComponent('EditorLocalMenu');
    if (F is TPopupMenu) and (TPopupMenu(F).FindComponent('GitEditorMenu') <> nil) then Found := True;
  end;
  Check(Found, 'the Git submenu of the editor''s local menu');

  { a failure is reported, not raised }
  FLastError := '';
  Host.Switch('no-such-branch', False);
  WaitIdle;
  Check(FLastError <> '', 'a failure of git is reported');

  { another project, in a folder of no repository, then the first one again: the view follows. The
    unit's editor and module are let go first: Delphi 7's IDE reports a module closed while an
    expert holds them (a dangling reference count) }
  E := nil;
  M := nil;
  Other := ExtractFilePath(ExcludeTrailingPathDelimiter(FDir)) + 'other\';
  ForceDirectories(Other);
  WriteFileW(CodePageToWide(Other + 'Other.dpr', CP_ACP), 'program Other;'#13#10#13#10'begin'#13#10'end.'#13#10);
  (BorlandIDEServices as IOTAActionServices).OpenProject(Other + 'Other.dpr', True);
  Pause(700);
  WaitIdle;
  Check(Host.Repo = nil, 'another project: no repository', Host.ProjectFolder);
  Check(V.EmptyPanel.Visible and not V.ChangesList.Visible, 'the view says so');
  (BorlandIDEServices as IOTAActionServices).OpenProject(FDir + 'Project1.dpr', True);
  Pause(700);
  WaitIdle;
  Check((Host.Repo <> nil) and V.ChangesList.Visible, 'the first project again: its repository');

  { the form changed on disk and read by the IDE, then discarded: the IDE reads the form again - the
    unit, which did not change, says nothing of it }
  FormFile := ChangeFileExt(UnitFile, '.dfm');
  E := OpenSourceEditor(UnitFile);
  Check(E <> nil, 'Unit1.pas opened again');
  if E = nil then Exit;
  Text := ReadFileW(CodePageToWide(FormFile, CP_ACP));
  WriteFileW(CodePageToWide(FormFile, CP_ACP), StringReplace(Text, 'Caption = ''Form1''',
    'Caption = ''Changed on disk''', []));
  (BorlandIDEServices as IOTAActionServices).ReloadFile(UnitFile);
  Check(FormCaption(UnitFile) = 'Changed on disk', 'the IDE has the form changed on disk', FormCaption(UnitFile));
  Host.Refresh;
  WaitIdle;
  Row := V.RowIndex(ggChanges, 'Unit1.dfm');
  Check(Row >= 0, 'the form alone is a change');
  if Row < 0 then Exit;
  V.SelectRow(Row);
  V.aDiscard.Execute;
  WaitIdle;
  Check(not FindChange('Unit1.dfm', C), 'the form discarded');
  Check(FormCaption(UnitFile) = 'Form1', 'the IDE read the discarded form again', FormCaption(UnitFile));
end;

procedure TGitSelfTest.Pause(Ms: Cardinal);
var
  Start: Cardinal;
begin
  Start := GetTickCount;
  while GetTickCount - Start < Ms do
  begin
    Application.ProcessMessages;
    Sleep(15);
  end;
end;

end.
