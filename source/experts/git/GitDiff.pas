{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitDiff;

{ The Git Diff view: the changes of a file - in the work tree, in the index, in a commit, in the
  editor against HEAD - or a file's blame, as lines in the code editor's font. A dockable tool window
  (DockForm.TDockableForm) laid out as a view of D7 Studio (GitUI): its tool bar - Previous Change,
  Next Change, Open in Editor, Refresh - in IntelliJ's images, what is shown on its right; the
  lines in a flat frame; the status line at the foot of D7 Studio's view, else the window's own.
  * A diff: per file its name, its notes (new, deleted, renamed, binary), its hunks - the hunk's
    header on a shade, the lines with the old and the new line number, removed ones on red, added
    ones on green (KitDrawDiffLine, as the AI harness's approval).
  * Blame: per line the commit, its author and its date at the start of each run of the same commit,
    the line's number and its text; lines that are not committed in the accent colour.
  * The editor's text (Diff with HEAD, the editor's Blame) is read when the view asks for the diff:
    Refresh takes what the editor holds then.
  * Double click or Enter opens the file in the editor at that line. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ToolWin, ImgList, Menus, ActnList, DockForm, GitCore, GitHost;

const
  GitDiffSection = 'GitDiffView';

  { the kinds of what the view reads (GitHost.LoadDiff) }
  gkWorkTree = 0;
  gkStaged = 1;
  gkUntracked = 2;
  gkCommit = 3;
  gkText = 4;
  gkConflict = 5;

type
  TGitDiffMode = (gmNone, gmDiff, gmBlame);

  TGitDiffView = class(TDockableForm)
    TopBar: TPanel;
    DiffBar: TToolBar;
    PrevButton: TToolButton;
    NextButton: TToolButton;
    Sep1: TToolButton;
    OpenButton: TToolButton;
    Sep2: TToolButton;
    RefreshButton: TToolButton;
    InfoLabel: TLabel;
    DiffList: TListBox;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    Actions: TActionList;
    aPrev: TAction;
    aNext: TAction;
    aOpen: TAction;
    aRefresh: TAction;
    aCopy: TAction;
    Icons: TImageList;
    IconsDisabled: TImageList;
    DiffMenu: TPopupMenu;
    miOpen: TMenuItem;
    miCopy: TMenuItem;
    miSep1: TMenuItem;
    miPrev: TMenuItem;
    miNext: TMenuItem;
    procedure aPrevExecute(Sender: TObject);
    procedure aNextExecute(Sender: TObject);
    procedure aMoveUpdate(Sender: TObject);
    procedure aOpenExecute(Sender: TObject);
    procedure aOpenUpdate(Sender: TObject);
    procedure aRefreshExecute(Sender: TObject);
    procedure aRefreshUpdate(Sender: TObject);
    procedure aCopyExecute(Sender: TObject);
    procedure TopBarResize(Sender: TObject);
    procedure DiffListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure DiffListDblClick(Sender: TObject);
    procedure DiffListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FMode: TGitDiffMode;
    FDiff: TGitDiff;
    FBlame: TGitBlame;
    FTexts: array of WideString;     // the lines as drawn
    FKind: Integer;                  // the request, for Refresh
    FPath, FOrigPath, FId, FNote: string;
    FEditorFile: string;             // the file whose editor text is compared or blamed (an IDE name)
    FTag: Integer;
    FLoading: Boolean;
    FInfoText, FInfoShort, FInfoHint: string;
    FNumWidth: Integer;              // a line number's column
    FMarkWidth: Integer;
    FInfoWidth: Integer;             // blame: the commit, author and date
    FMaxNo: Integer;                 // the highest line number shown (at least 100)
    FLongest: Integer;               // the row of the longest line, -1: none
    FRowFont: string;                // the list's font the rows were measured in (RowFontKey)
    procedure InitLook;
    procedure FitRows;
    procedure Measure;
    function RowFontKey: string;
    procedure FollowFont;
    procedure UpdateStatus;
    { what is shown next; the rows of something else go at once }
    procedure Target(Mode: TGitDiffMode; Kind: Integer; const Path, OrigPath, Id, EditorFile: string);
    procedure Request;
    procedure DiffDone(Task: TGitTask);
    procedure BlameDone(Task: TGitTask);
    procedure Fill;
    procedure SetInfo(const Full, Short, Hint: string);
    function LineCount: Integer;
    { the file and line that row Index stands for; False when it stands for none }
    function RowTarget(Index: Integer; out Path: string; out Line: Integer): Boolean;
    function IsStop(Index: Integer): Boolean;
    procedure MoveTo(Index: Integer);
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
  protected
    procedure CreateWnd; override;
    procedure WndProc(var Message: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Kind: gkWorkTree ... gkConflict; Path: the file (repository path); OrigPath: a rename's source;
      Id: a commit; EditorFile: gkText's file, whose editor text is compared (an IDE name); Note: what
      is compared, for the bar }
    procedure ShowDiff(Kind: Integer; const Path, OrigPath, Id, EditorFile, Note: string);
    { blame of Path: on disk, or of the editor's text of EditorFile (an IDE name) when it is given }
    procedure ShowBlame(const Path, EditorFile: string);
    property Diff: TGitDiff read FDiff;
    property Blame: TGitBlame read FBlame;
    property Mode: TGitDiffMode read FMode;
    property Loading: Boolean read FLoading;
  end;

var
  GitDiffForm: TGitDiffView;

procedure RegisterGitDiffView;
procedure UnregisterGitDiffView;
procedure ShowGitDiff(Kind: Integer; const Path, OrigPath, Id, EditorFile, Note: string);
procedure ShowGitBlame(const Path, EditorFile: string);

implementation

{$R *.dfm}

uses
  ToolsAPI, DeskUtil, Clipbrd, GitText, GitUI, GitIde, GitViews;

const
  { the commands' images (GitIcons.bmp's cells), in the order of the actions' ImageIndex in the .dfm }
  IconCells: array[0..4] of Integer = (giPreviousChange, giNextChange, giOpenFile, giRefresh, giCopy);

  AuthorChars = 18;    // of a blame line's author

procedure RegisterGitDiffView;
begin
  RegisterView(TGitDiffView, GitDiffSection, @GitDiffForm);
end;

procedure UnregisterGitDiffView;
begin
  UnregisterView(GitDiffForm);
end;

function DiffForm: TGitDiffView;
begin
  if GitDiffForm = nil then GitDiffForm := TGitDiffView.Create(nil);
  Result := GitDiffForm;
end;

procedure ShowGitDiff(Kind: Integer; const Path, OrigPath, Id, EditorFile, Note: string);
begin
  DiffForm.ShowDiff(Kind, Path, OrigPath, Id, EditorFile, Note);
  FocusWindow(GitDiffForm);
end;

procedure ShowGitBlame(const Path, EditorFile: string);
begin
  DiffForm.ShowBlame(Path, EditorFile);
  FocusWindow(GitDiffForm);
end;

{ ---------------------------------------------------------------- TGitDiffView }

constructor TGitDiffView.Create(AOwner: TComponent);
begin
  inherited;
  DeskSection := GitDiffSection;
  AutoSave := True;
  FDiff := TGitDiff.Create;
  FDiff.Clear;
  FBlame := TGitBlame.Create;
  FLongest := -1;
  InitLook;
  UpdateStatus;
end;

destructor TGitDiffView.Destroy;
begin
  ViewGoes(Self, nil);
  FBlame.Free;
  FDiff.Free;
  inherited;
end;

{ the IDE's fonts - the lines (Consolas in the .dfm) in the code editor's -, the images, the look }
procedure TGitDiffView.InitLook;
begin
  KitUseIdeFont(Self);
  KitBitmapIcons(Actions, [DiffBar], [DiffMenu], GitIconsResource, IconCells, Icons, IconsDisabled);
  KitFlatToolBar(DiffBar);
  KitFlatFrame(DiffList);
  FitRows;
  DiffList.DoubleBuffered := True;
end;

{ the rows' height for the list's font (the code editor's). A new height makes the list's window
  again; the VCL keeps its count, top row and selection, the kit its horizontal range }
procedure TGitDiffView.FitRows;
begin
  DiffList.Canvas.Font := DiffList.Font;
  DiffList.ItemHeight := DiffList.Canvas.TextHeight('Ag') + 3;
  FRowFont := RowFontKey;
end;

function TGitDiffView.RowFontKey: string;
begin
  Result := DiffList.Font.Name + '/' + IntToStr(DiffList.Font.Height);
end;

{ the list in a font other than its rows were measured in (the kit gave it the editor's): its rows
  and columns measured again }
procedure TGitDiffView.FollowFont;
begin
  if RowFontKey = FRowFont then Exit;
  FitRows;
  if Length(FTexts) > 0 then Measure;
  DiffList.Invalidate;
end;

procedure TGitDiffView.CreateWnd;
begin
  inherited;
  if FDiff <> nil then UpdateStatus;
end;

{ D7 Studio applied its options: the kit has given the list the editor's font (KitUseIdeFont's
  hook runs before the form) }
procedure TGitDiffView.WndProc(var Message: TMessage);
begin
  inherited;
  if KitIsEditorOptionsMessage(Message.Msg) then FollowFont;
end;

{ Shown, the view follows a font its list got while it had no window to hear the notice (the kit
  gives it when the form's window is made). Not in CreateWnd: measuring needs the list's window,
  which may be the one being made }
procedure TGitDiffView.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if Showing then FollowFont;
  if Showing and (FDiff <> nil) then UpdateStatus;
end;

procedure TGitDiffView.UpdateStatus;
var
  S: string;
begin
  if FLoading then S := 'Reading ...'
  else case FMode of
    gmDiff:
      if FDiff.Count = 0 then S := 'No changes'
      else
      begin
        S := Format('+%d  -%d', [FDiff.Added, FDiff.Removed]);
        if FDiff.Hunks = 1 then S := S + GitDot + '1 hunk'
        else if FDiff.Hunks > 1 then S := S + GitDot + Format('%d hunks', [FDiff.Hunks]);
        if FDiff.Files > 1 then S := S + GitDot + Format('%d files', [FDiff.Files]);
      end;
    gmBlame:
      begin
        S := Format('%d lines', [FBlame.Count]);
        if FBlame.CommitCount = 1 then S := S + GitDot + '1 commit'
        else S := S + GitDot + Format('%d commits', [FBlame.CommitCount]);
      end;
  else
    S := 'Nothing shown';
  end;
  ShowViewStatus(Self, StatusPanel, StatusLabel, S);
end;

procedure TGitDiffView.SetInfo(const Full, Short, Hint: string);
begin
  FInfoText := Full;
  FInfoShort := Short;
  FInfoHint := Hint;
  KitLayoutBarLabel(InfoLabel, DiffBar, FInfoText, FInfoShort, FInfoHint);
end;

procedure TGitDiffView.TopBarResize(Sender: TObject);
begin
  KitLayoutBarLabel(InfoLabel, DiffBar, FInfoText, FInfoShort, FInfoHint);
end;

procedure TGitDiffView.Target(Mode: TGitDiffMode; Kind: Integer; const Path, OrigPath, Id, EditorFile: string);
begin
  if (Mode <> FMode) or (Kind <> FKind) or (Path <> FPath) or (OrigPath <> FOrigPath) or (Id <> FId) or
    (EditorFile <> FEditorFile) then
  begin
    { the rows shown would be drawn and opened as the new file's until its answer comes }
    FDiff.Clear;
    FBlame.Clear;
    Fill;
  end;
  FMode := Mode;
  FKind := Kind;
  FPath := Path;
  FOrigPath := OrigPath;
  FId := Id;
  FEditorFile := EditorFile;
end;

procedure TGitDiffView.ShowDiff(Kind: Integer; const Path, OrigPath, Id, EditorFile, Note: string);
var
  Name: string;
begin
  Target(gmDiff, Kind, Path, OrigPath, Id, EditorFile);
  Caption := 'Git Diff';
  FNote := Note;
  if Path <> '' then Name := Utf8ToIde(PathName(Path)) else Name := 'Commit ' + Copy(Id, 1, 7);
  if Note <> '' then SetInfo(Name + GitDot + Note, Name, PathText(Path)) else SetInfo(Name, Name, PathText(Path));
  Request;
end;

procedure TGitDiffView.ShowBlame(const Path, EditorFile: string);
var
  Name: string;
begin
  Target(gmBlame, 0, Path, '', '', EditorFile);
  Caption := 'Git Blame';
  Name := Utf8ToIde(PathName(Path));
  SetInfo(Name + GitDot + 'blame', Name, PathText(Path));
  Request;
end;

procedure TGitDiffView.Request;
var
  H: TGitHost;
  Bytes: string;
  HasBytes: Boolean;
begin
  H := GitHostInstance;
  Inc(FTag);
  FLoading := True;
  UpdateStatus;
  { the editor's text as it is now }
  Bytes := '';
  HasBytes := (FEditorFile <> '') and FileBytes(FEditorFile, Bytes);
  if FMode = gmBlame then H.LoadBlame(Self, FTag, FPath, Bytes, HasBytes, BlameDone)
  else H.LoadDiff(Self, FTag, FKind, FPath, FOrigPath, FId, Bytes, DiffDone);
end;

procedure TGitDiffView.DiffDone(Task: TGitTask);
begin
  if Task.Tag <> FTag then Exit;
  FLoading := False;
  FDiff.Clear;
  if (Task.Error = '') and (Task.Diff <> nil) then
  begin
    FDiff.Free;
    FDiff := Task.Diff;
    Task.Diff := nil;
  end;
  Fill;
end;

procedure TGitDiffView.BlameDone(Task: TGitTask);
begin
  if Task.Tag <> FTag then Exit;
  FLoading := False;
  FBlame.Clear;
  if (Task.Error = '') and (Task.Blame <> nil) then
  begin
    FBlame.Free;
    FBlame := Task.Blame;
    Task.Blame := nil;
  end;
  Fill;
end;

function TGitDiffView.LineCount: Integer;
begin
  case FMode of
    gmDiff: Result := FDiff.Count;
    gmBlame: Result := FBlame.Count;
  else
    Result := 0;
  end;
end;

{ the columns' widths and the horizontal range in the list's font: the line numbers (FMaxNo), the
  change marks, blame's commit, author and date, the longest line (FLongest) }
procedure TGitDiffView.Measure;
var
  I, W, AuthorW: Integer;
  C: TCanvas;
  BC: TGitBlameCommit;
begin
  C := DiffList.Canvas;
  C.Font := DiffList.Font;
  FNumWidth := C.TextWidth(IntToStr(FMaxNo)) + 12;
  FMarkWidth := C.TextWidth('W') + 6;
  FInfoWidth := 0;
  if FMode = gmBlame then
  begin
    AuthorW := 0;
    for I := 0 to Length(FTexts) - 1 do
      if FBlame[I].First then
      begin
        BC := FBlame[I].Commit;
        W := KitTextWidthW(C, Copy(Utf8ToWide(BC.Author), 1, AuthorChars));
        if W > AuthorW then AuthorW := W;
      end;
    FInfoWidth := C.TextWidth('0000000  ') + AuthorW + C.TextWidth('  0000-00-00') + 16;
  end;
  { the horizontal range: the longest line (the lines are in the code editor's font) }
  if FMode = gmBlame then W := FInfoWidth + FNumWidth else W := 2 * FNumWidth + FMarkWidth;
  if FLongest >= 0 then Inc(W, KitTextWidthW(C, FTexts[FLongest]));
  KitListRange(DiffList, W + 8);
end;

{ the lines' texts and the columns' widths, then the list }
procedure TGitDiffView.Fill;
var
  I, N: Integer;
begin
  N := LineCount;
  SetLength(FTexts, N);
  FMaxNo := 0;
  FLongest := -1;
  for I := 0 to N - 1 do
  begin
    if FMode = gmDiff then
    begin
      FTexts[I] := ViewText(FDiff[I].Text);
      if FDiff[I].OldLine > FMaxNo then FMaxNo := FDiff[I].OldLine;
      if FDiff[I].NewLine > FMaxNo then FMaxNo := FDiff[I].NewLine;
    end
    else
    begin
      FTexts[I] := ViewText(FBlame[I].Text);
      if FBlame[I].Line > FMaxNo then FMaxNo := FBlame[I].Line;
    end;
    if (FLongest < 0) or (Length(FTexts[I]) > Length(FTexts[FLongest])) then FLongest := I;
  end;
  if FMaxNo < 100 then FMaxNo := 100;
  Measure;
  DiffList.Items.BeginUpdate;
  try
    DiffList.Count := N;
    if N > 0 then
    begin
      DiffList.ItemIndex := -1;
      DiffList.TopIndex := 0;
    end;
  finally
    DiffList.Items.EndUpdate;
  end;
  DiffList.Invalidate;
  UpdateStatus;
  { a diff opens at its first change, nothing selected }
  if FMode = gmDiff then
    for I := 0 to N - 1 do
      if IsStop(I) then
      begin
        if I > 2 then DiffList.TopIndex := I - 2;
        Break;
      end;
end;

procedure TGitDiffView.DiffListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  R: TRect;
  L: TGitDiffLine;
  B: TGitBlameLine;
  Sel: Boolean;
  Ground, Fore, Num: TColor;
  S: WideString;
  Kind: Integer;

  procedure Text(const T: WideString; X: Integer; Color: TColor; Right: Boolean; ToX: Integer);
  var
    RR: TRect;
    Flags: UINT;
  begin
    if T = '' then Exit;
    RR := Rect;
    RR.Left := Rect.Left + X;
    if ToX > 0 then RR.Right := Rect.Left + ToX;
    C.Font.Color := Color;
    Flags := DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX;
    if Right then Flags := Flags or DT_RIGHT else Flags := Flags or DT_LEFT;
    DrawTextW(C.Handle, PWideChar(T), Length(T), RR, Flags);
  end;

  function NumText(N: Integer): WideString;
  begin
    if N > 0 then Result := IntToStr(N) else Result := '';
  end;

begin
  if (Index < 0) or (Index >= LineCount) then Exit;
  C := DiffList.Canvas;
  Sel := odSelected in State;
  SetBkMode(C.Handle, TRANSPARENT);
  C.Font.Style := [];
  if FMode = gmBlame then
  begin
    B := FBlame[Index];
    if Sel then Ground := clHighlight
    else if B.Commit.Uncommitted then Ground := KitBlend(clHighlight, clWindow, 8)
    else Ground := clWindow;
    C.Brush.Color := Ground;
    C.FillRect(Rect);
    if Sel then Fore := clHighlightText else Fore := clWindowText;
    if Sel then Num := clHighlightText else Num := clGrayText;
    if B.First then
    begin
      { a run's first line: a rule above it, the commit, its author and date }
      if (Index > 0) and not Sel then
      begin
        C.Brush.Color := KitBlend(clBtnShadow, clWindow, 35);
        C.FillRect(Classes.Rect(Rect.Left, Rect.Top, Rect.Right, Rect.Top + 1));
      end;
      if B.Commit.Uncommitted then S := 'Not committed'
      else S := Copy(B.Commit.Id, 1, 7) + '  ' + Copy(Utf8ToWide(B.Commit.Author), 1, AuthorChars);
      if B.Commit.Uncommitted and not Sel then Text(S, 6, KitAccent, False, FInfoWidth - 8)
      else Text(S, 6, Num, False, FInfoWidth - 8);
      if not B.Commit.Uncommitted then Text(Copy(GitTimeText(B.Commit.Time), 1, 10), 6, Num, True, FInfoWidth - 8);
    end;
    Text(NumText(B.Line), FInfoWidth, Num, True, FInfoWidth + FNumWidth - 8);
    Text(FTexts[Index], FInfoWidth + FNumWidth, Fore, False, 0);
    Exit;
  end;
  L := FDiff[Index];
  case L.Kind of
    gdFile:
      begin
        if Sel then C.Brush.Color := clHighlight else C.Brush.Color := clBtnFace;
        C.FillRect(Rect);
        C.Font.Style := [fsBold];
        if Sel then Fore := clHighlightText else Fore := clBtnText;
        Text(FTexts[Index], 6, Fore, False, 0);
        C.Font.Style := [];
      end;
    gdNote:
      begin
        if Sel then C.Brush.Color := clHighlight else C.Brush.Color := clWindow;
        C.FillRect(Rect);
        C.Font.Style := [fsItalic];
        if Sel then Fore := clHighlightText else Fore := clGrayText;
        Text(FTexts[Index], 2 * FNumWidth + FMarkWidth, Fore, False, 0);
        C.Font.Style := [];
      end;
    gdHunk:
      begin
        if Sel then C.Brush.Color := clHighlight else C.Brush.Color := KitBlend(clHighlight, clWindow, 10);
        C.FillRect(Rect);
        if Sel then Fore := clHighlightText else Fore := KitAccent;
        Text(FTexts[Index], 2 * FNumWidth + FMarkWidth, Fore, False, 0);
      end;
  else
    case L.Kind of
      gdRemoved: Kind := KitDiffRemoved;
      gdAdded: Kind := KitDiffAdded;
    else
      Kind := KitDiffSame;
    end;
    R := Rect;
    if Sel then
    begin
      C.Brush.Color := clHighlight;
      C.FillRect(R);
      Fore := clHighlightText;
      Num := clHighlightText;
      Text(NumText(L.OldLine), 0, Num, True, FNumWidth - 6);
      Text(NumText(L.NewLine), FNumWidth, Num, True, 2 * FNumWidth - 6);
      if Kind = KitDiffRemoved then S := '-' else if Kind = KitDiffAdded then S := '+' else S := ' ';
      Text(S, 2 * FNumWidth, Fore, False, 2 * FNumWidth + FMarkWidth);
      Text(FTexts[Index], 2 * FNumWidth + FMarkWidth, Fore, False, 0);
    end
    else
    begin
      { the numbers on the line's ground, then the mark and the text (KitDrawDiffLine) }
      KitDiffColors(Kind, Ground, Num);
      C.Brush.Color := Ground;
      C.FillRect(Classes.Rect(R.Left, R.Top, R.Left + 2 * FNumWidth, R.Bottom));
      Text(NumText(L.OldLine), 0, clGrayText, True, FNumWidth - 6);
      Text(NumText(L.NewLine), FNumWidth, clGrayText, True, 2 * FNumWidth - 6);
      R.Left := R.Left + 2 * FNumWidth;
      KitDrawDiffLine(C, R, Kind, FTexts[Index], FMarkWidth);
    end;
  end;
end;

{ the file and line of a row: a diff's line its new number (a removed line: the next line's), a
  blame line its own }
function TGitDiffView.RowTarget(Index: Integer; out Path: string; out Line: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  Path := FPath;
  Line := 0;
  if (Index < 0) or (Index >= LineCount) then Exit;
  if FMode = gmBlame then
  begin
    Line := FBlame[Index].Line;
    Result := Path <> '';
    Exit;
  end;
  { the file the line belongs to (a commit's diff has several) }
  for I := Index downto 0 do
    if FDiff[I].Kind = gdFile then
    begin
      Path := FDiff[I].Text;
      Break;
    end;
  for I := Index to FDiff.Count - 1 do
  begin
    if FDiff[I].Kind = gdFile then Break;
    if FDiff[I].NewLine > 0 then
    begin
      Line := FDiff[I].NewLine;
      Break;
    end;
  end;
  if Line = 0 then Line := 1;
  Result := Path <> '';
end;

function TGitDiffView.IsStop(Index: Integer): Boolean;
begin
  if FMode = gmBlame then Result := FBlame[Index].First
  else Result := FDiff[Index].Kind = gdHunk;
end;

procedure TGitDiffView.MoveTo(Index: Integer);
begin
  if (Index < 0) or (Index >= LineCount) then Exit;
  DiffList.ItemIndex := Index;
  if Index > 2 then DiffList.TopIndex := Index - 2 else DiffList.TopIndex := 0;
end;

procedure TGitDiffView.aMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := LineCount > 0;
end;

procedure TGitDiffView.aPrevExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := DiffList.ItemIndex - 1 downto 0 do
    if IsStop(I) then
    begin
      MoveTo(I);
      Exit;
    end;
end;

procedure TGitDiffView.aNextExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := DiffList.ItemIndex + 1 to LineCount - 1 do
    if IsStop(I) then
    begin
      MoveTo(I);
      Exit;
    end;
end;

{ the file of the chosen line, else the file shown; which line it is is found when it opens }
procedure TGitDiffView.aOpenUpdate(Sender: TObject);
begin
  aOpen.Enabled := (GitHostInstance.Repo <> nil) and ((FPath <> '') or (LineCount > 0));
end;

procedure TGitDiffView.aOpenExecute(Sender: TObject);
var
  Path, F: string;
  Line: Integer;
begin
  if not RowTarget(DiffList.ItemIndex, Path, Line) then
  begin
    Path := FPath;
    Line := 1;
  end;
  if Path = '' then Exit;
  F := GitHostInstance.FileOf(Path);
  if (F <> '') and FileExists(F) then ShowFileAt(F, Line, 1)
  else GitInform(Format('%s is not in the work tree.', [PathText(Path)]));
end;

procedure TGitDiffView.aRefreshUpdate(Sender: TObject);
begin
  aRefresh.Enabled := FMode <> gmNone;
end;

procedure TGitDiffView.aRefreshExecute(Sender: TObject);
begin
  if FMode <> gmNone then Request;
end;

procedure TGitDiffView.aCopyExecute(Sender: TObject);
var
  I: Integer;
begin
  I := DiffList.ItemIndex;
  if (I >= 0) and (I < Length(FTexts)) then Clipboard.AsText := WideToCodePage(FTexts[I], CP_ACP);
end;

procedure TGitDiffView.DiffListDblClick(Sender: TObject);
begin
  aOpen.Execute;
end;

procedure TGitDiffView.DiffListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    DiffListDblClick(nil);
  end;
end;

end.
