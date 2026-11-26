{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitViews;

{ What the Git expert's views share: the texts of the branch and of the status line, how a changed
  file is drawn in a list - its state's letter in a colour, its name, its folder in grey, in the
  list's colours (clHighlight when it is selected, no focus rectangle: D7 Studio's lists) -, the
  views' registration with the IDE's desktop and their status line, and the editor's text of a file
  as git compares it. Text of git's is UTF-8 and drawn as UTF-16, so names beyond the IDE's code page
  show as they are. The questions and messages to the user are GitHost's (GitConfirm, GitInform,
  GitFail). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, DeskForm, GitCore;

const
  { why the files are saved first (GitHost.SaveFiles) }
  GitSwitchWhy = 'Switching branches may change files of the work tree.';

  { the views' images: IntelliJ's, the cells of the resource GitIconsResource (GitIcons.bmp,
    linked by GitExpert.dpk through GitIcons.rc), in the order of the constants gi... below }
  GitIconsResource = 'GITICONS';
  giRefresh = 0;
  giCommit = 1;
  giFetch = 2;
  giPull = 3;
  giPush = 4;
  giBranch = 5;
  giStash = 6;
  giHistory = 7;
  giOpenFile = 8;
  giDiff = 9;
  giStage = 10;
  giUnstage = 11;
  giDiscard = 12;
  giBlame = 13;
  giCopy = 14;
  giSettings = 15;
  giStop = 16;
  giAllBranches = 17;
  giRepository = 18;
  giPreviousChange = 19;
  giNextChange = 20;

{ ' · ' in the IDE's code page: the separator of a status line's parts }
function GitDot: string;
{ the branch with its distance to its upstream - arrows where the IDE shows Unicode, else + and - -
  or '(detached abc1234)'; '' before the first commit (an IDE string) }
function BranchText(S: TGitStatus): string;

{ the colour of a file's state letter: added green, deleted and conflicts red, others the accent }
function StateColor(Letter: Char): TColor;
{ a row's ground in C (clHighlight when Selected) and the colours of its text and of its grey text }
procedure RowColors(C: TCanvas; Selected: Boolean; out TextColor, GreyColor: TColor);
{ a changed file in R of C: the ground (clHighlight when Selected), its state's letter from Indent,
  its name, then its folder in grey (and where a rename came from) }
procedure DrawFileRow(C: TCanvas; const R: TRect; Indent: Integer; Letter: Char; const Path, OrigPath: string;
  Selected: Boolean);
{ the name, and the folder with '\', of a repository path }
function PathName(const Path: string): string;
function PathFolder(const Path: string): string;
{ a repository path as Windows writes it, an IDE string (a hint, a message) }
function PathText(const Path: string): string;
{ UTF-8 as the views draw it: UTF-16, a tab as four spaces }
function ViewText(const Utf8: string): WideString;
{ List painted again as a whole when its width changes: a list box paints only what a resize
  uncovers, and DrawFileRow ends a row in an ellipsis that depends on the width }
procedure RepaintOnWidthChange(List: TWinControl);

{ a view's class registered with the IDE's desktop under Section, and Field (the view's variable)
  with it: the desktop makes the view and clears the variable when it goes }
procedure RegisterView(AClass: TDesktopFormClass; const Section: string; Field: Pointer);
{ the view of Field freed and its registration taken back }
procedure UnregisterView(var Field);
{ a view goes: the host forgets it (Listener: its HostChanged, if it has one) }
procedure ViewGoes(View: TCustomForm; Listener: TNotifyEvent);
{ S in the view's status line: the foot of D7 Studio's view, else the view's own Panel }
procedure ShowViewStatus(View: TCustomForm; Panel: TPanel; Lbl: TLabel; const S: string);

{ the text of file FileName (an IDE name) as git compares it: the editor's - also what is not
  saved - in the encoding of the file on disk, else the file's bytes; False when there is neither }
function FileBytes(const FileName: string; out Bytes: string): Boolean;

implementation

uses
  Messages, ToolsAPI, DeskUtil, GitText, GitUI, GitIde, GitHost;

type
  TWidthRepaint = class(TKitWindowHook)
  private
    FWidth: Integer;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TWidthRepaint.Hook(var Message: TMessage);
begin
  CallOld(Message);
  if (Message.Msg = WM_SIZE) and (Control.Width <> FWidth) then
  begin
    FWidth := Control.Width;
    Control.Invalidate;
  end;
end;

procedure RepaintOnWidthChange(List: TWinControl);
begin
  TWidthRepaint.Create(List).FWidth := List.Width;
end;

procedure RegisterView(AClass: TDesktopFormClass; const Section: string; Field: Pointer);
begin
  RegisterDesktopFormClass(AClass, Section, Section);
  if Assigned(RegisterFieldAddress) then RegisterFieldAddress(Section, Field);
end;

procedure UnregisterView(var Field);
begin
  TObject(Field).Free;
  if Assigned(UnregisterFieldAddress) then UnregisterFieldAddress(@Field);
  Pointer(Field) := nil;
end;

procedure ViewGoes(View: TCustomForm; Listener: TNotifyEvent);
var
  H: TGitHost;
begin
  H := GitHostIfAny;
  if H = nil then Exit;
  if Assigned(Listener) then
  begin
    if View.Showing then H.ViewShowing(False);
    H.RemoveListener(Listener);
  end;
  H.ForgetOwner(View);
end;

procedure ShowViewStatus(View: TCustomForm; Panel: TPanel; Lbl: TLabel; const S: string);
begin
  Lbl.Caption := S;
  Panel.Visible := not KitViewStatus(View, S);
end;

function FileBytes(const FileName: string; out Bytes: string): Boolean;
var
  E: IOTASourceEditor;
  Enc: TKitFileEncoding;
begin
  Result := False;
  Bytes := '';
  E := FindSourceEditor(FileName);
  if E <> nil then
  begin
    { git compares bytes: the editor's text in the encoding of the file on disk }
    Enc := feAnsi;
    if FileExists(FileName) then ReadTextFile(FileName, Enc);
    Bytes := EncodeText(IdeToUtf8(EditorText(E)), Enc);
    Result := True;
  end
  else if FileExists(FileName) then
  begin
    Bytes := ReadFileBytes(FileName);
    Result := True;
  end;
end;

function GitDot: string;
begin
  Result := '  ' + Utf8ToIde(#$C2#$B7) + '  ';
end;

function BranchText(S: TGitStatus): string;
begin
  if S.Branch <> '' then Result := S.Branch
  else if S.Head <> '' then Result := '(detached ' + Copy(S.Head, 1, 7) + ')'
  else Result := '';
  if ProcessIsUtf8 then
  begin
    if S.Ahead > 0 then Result := Result + '  ' + #$E2#$86#$91 + IntToStr(S.Ahead);
    if S.Behind > 0 then Result := Result + '  ' + #$E2#$86#$93 + IntToStr(S.Behind);
  end
  else
  begin
    if S.Ahead > 0 then Result := Result + '  +' + IntToStr(S.Ahead);
    if S.Behind > 0 then Result := Result + '  -' + IntToStr(S.Behind);
  end;
  Result := Utf8ToIde(Result);
end;

function StateColor(Letter: Char): TColor;
begin
  case Letter of
    'A', 'U', '?': Result := KitBlend(clGreen, clWindowText, 80);
    'D', '!': Result := KitBlend(clRed, clWindowText, 75);
  else
    Result := KitAccent;
  end;
end;

procedure RowColors(C: TCanvas; Selected: Boolean; out TextColor, GreyColor: TColor);
begin
  if Selected then
  begin
    C.Brush.Color := clHighlight;
    TextColor := clHighlightText;
    GreyColor := KitBlend(clHighlightText, clHighlight, 70);
  end
  else
  begin
    C.Brush.Color := clWindow;
    TextColor := clWindowText;
    GreyColor := clGrayText;
  end;
end;

function PathName(const Path: string): string;
var
  P: Integer;
begin
  P := Length(Path);
  while (P > 0) and (Path[P] <> '/') do Dec(P);
  Result := Copy(Path, P + 1, MaxInt);
end;

function PathFolder(const Path: string): string;
var
  P: Integer;
begin
  P := Length(Path);
  while (P > 0) and (Path[P] <> '/') do Dec(P);
  if P > 0 then Result := StringReplace(Copy(Path, 1, P - 1), '/', '\', [rfReplaceAll]) else Result := '';
end;

function PathText(const Path: string): string;
begin
  Result := Utf8ToIde(StringReplace(Path, '/', '\', [rfReplaceAll]));
end;

function ViewText(const Utf8: string): WideString;
var
  W: WideString;
  I, J, Tabs: Integer;
begin
  W := Utf8ToWide(Utf8);
  Tabs := 0;
  for I := 1 to Length(W) do
    if W[I] = #9 then Inc(Tabs);
  if Tabs = 0 then
  begin
    Result := W;
    Exit;
  end;
  SetLength(Result, Length(W) + 3 * Tabs);
  J := 1;
  for I := 1 to Length(W) do
    if W[I] = #9 then
    begin
      Result[J] := ' ';
      Result[J + 1] := ' ';
      Result[J + 2] := ' ';
      Result[J + 3] := ' ';
      Inc(J, 4);
    end
    else
    begin
      Result[J] := W[I];
      Inc(J);
    end;
end;

procedure DrawFileRow(C: TCanvas; const R: TRect; Indent: Integer; Letter: Char; const Path, OrigPath: string;
  Selected: Boolean);
const
  LetterWidth = 16;
var
  RR: TRect;
  W: WideString;
  Folder: string;
  TextColor, GreyColor: TColor;
begin
  RowColors(C, Selected, TextColor, GreyColor);
  C.FillRect(R);
  SetBkMode(C.Handle, TRANSPARENT);
  RR := R;
  RR.Left := R.Left + Indent;
  RR.Right := RR.Left + LetterWidth;
  C.Font.Style := [fsBold];
  if Selected then C.Font.Color := TextColor else C.Font.Color := StateColor(Letter);
  W := WideChar(Letter);
  DrawTextW(C.Handle, PWideChar(W), 1, RR, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  C.Font.Style := [];
  RR.Left := RR.Right + 4;
  RR.Right := R.Right;
  C.Font.Color := TextColor;
  W := Utf8ToWide(PathName(Path));
  DrawTextW(C.Handle, PWideChar(W), Length(W), RR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  Folder := PathFolder(Path);
  if OrigPath <> '' then Folder := Folder + '  <- ' + StringReplace(OrigPath, '/', '\', [rfReplaceAll]);
  if Folder = '' then Exit;
  Inc(RR.Left, KitTextWidthW(C, W) + 8);
  C.Font.Color := GreyColor;
  W := Utf8ToWide(Folder);
  DrawTextW(C.Handle, PWideChar(W), Length(W), RR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or
    DT_END_ELLIPSIS);
end;

end.
