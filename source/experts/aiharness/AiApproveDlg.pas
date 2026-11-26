{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiApproveDlg;

{ The approval of a change the assistant wants to make: what changes (the tool's preview) as one
  list of lines - those at the start and the end that the text that goes and the text that comes
  share as context, between them the lines that go (red ground, '-') and the lines that come
  (green ground, '+') - and the user's answer: allow it, allow every change of this
  conversation, or deny it with words for the assistant. There is no default button: Enter in
  the reason box must not allow a change. The look is a task dialog's, as D7 Studio's messages:
  the content on clWindow, the buttons in a footer below a flat line; the IDE's fonts, the lines in
  its editor's. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, AiCore, AiAgent;

type
  TAiApproveDialog = class(TForm)
    TitleLabel: TLabel;
    NotesLabel: TLabel;
    DiffList: TListBox;
    ReasonLabel: TLabel;
    ReasonEdit: TEdit;
    Footer: TPanel;
    FooterLine: TShape;
    AllowButton: TButton;
    AllowAllButton: TButton;
    DenyButton: TButton;
    procedure DiffListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    procedure FillDiff(const Before, After: string; out Removed, Added: Integer);
  public
    { Reason: UTF-8 }
    class function Execute(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval;
  end;

implementation

{$R *.dfm}

uses
  AiText, AiUI;

const
  { a line's kind (KitDiffSame, KitDiffRemoved, KitDiffAdded) is its list item's object }
  MarkWidth = 18;              // the column of the marks, before the text
  TabSize = 4;

{ an IDE string's lines, tabs expanded }
procedure SplitLines(const S: string; Lines: TStrings);
var
  T: string;
  I: Integer;
begin
  Lines.Text := NormalizeNewLines(S, #13#10);
  for I := 0 to Lines.Count - 1 do
  begin
    T := Lines[I];
    if Pos(#9, T) > 0 then Lines[I] := StringReplace(T, #9, StringOfChar(' ', TabSize), [rfReplaceAll]);
  end;
end;

procedure TAiApproveDialog.FillDiff(const Before, After: string; out Removed, Added: Integer);
var
  B, A: TStringList;
  Head, Tail, I, W, Widest: Integer;
  Size: TSize;
  Text: WideString;
begin
  B := TStringList.Create;
  A := TStringList.Create;
  DiffList.Items.BeginUpdate;
  try
    SplitLines(Before, B);
    SplitLines(After, A);
    Head := 0;
    while (Head < B.Count) and (Head < A.Count) and (B[Head] = A[Head]) do Inc(Head);
    Tail := 0;
    while (Tail < B.Count - Head) and (Tail < A.Count - Head) and (B[B.Count - 1 - Tail] = A[A.Count - 1 - Tail]) do
      Inc(Tail);
    for I := 0 to Head - 1 do DiffList.Items.AddObject(B[I], TObject(KitDiffSame));
    for I := Head to B.Count - 1 - Tail do DiffList.Items.AddObject(B[I], TObject(KitDiffRemoved));
    for I := Head to A.Count - 1 - Tail do DiffList.Items.AddObject(A[I], TObject(KitDiffAdded));
    for I := B.Count - Tail to B.Count - 1 do DiffList.Items.AddObject(B[I], TObject(KitDiffSame));
    Removed := B.Count - Tail - Head;
    Added := A.Count - Tail - Head;
  finally
    DiffList.Items.EndUpdate;
    A.Free;
    B.Free;
  end;
  { the horizontal range: the widest line }
  DiffList.Canvas.Font := DiffList.Font;
  Widest := 0;
  for I := 0 to DiffList.Items.Count - 1 do
  begin
    Text := Utf8ToWide(IdeToUtf8(DiffList.Items[I]));
    if Text = '' then Continue;
    GetTextExtentPoint32W(DiffList.Canvas.Handle, PWideChar(Text), Length(Text), Size);
    W := Size.cx;
    if W > Widest then Widest := W;
  end;
  DiffList.Perform(LB_SETHORIZONTALEXTENT, MarkWidth + Widest + 8, 0);
end;

procedure TAiApproveDialog.DiffListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  { the lines are not chosen: no selection colour }
  KitDrawDiffLine(DiffList.Canvas, Rect, Integer(DiffList.Items.Objects[Index]),
    Utf8ToWide(IdeToUtf8(DiffList.Items[Index])), MarkWidth);
  { the list box draws a focus rectangle after this (XOR): drawn here first, it cancels out }
  if odFocused in State then DrawFocusRect(DiffList.Canvas.Handle, Rect);
end;

function Lines(N: Integer): string;
begin
  if N = 1 then Result := '1 line' else Result := Format('%d lines', [N]);
end;

class function TAiApproveDialog.Execute(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval;
var
  D: TAiApproveDialog;
  Removed, Added: Integer;
  Notes, Counts: string;
begin
  D := TAiApproveDialog.Create(Application);
  try
    KitPrepareDialog(D);
    D.TitleLabel.Font.Color := KitAccent;
    D.DiffList.Canvas.Font := D.DiffList.Font;
    D.DiffList.ItemHeight := D.DiffList.Canvas.TextHeight('Ag') + 3;
    D.TitleLabel.Caption := Change.Title;
    D.FillDiff(Change.Before, Change.After, Removed, Added);
    if Removed = 0 then Counts := Format('Adds %s.', [Lines(Added)])
    else if Added = 0 then Counts := Format('Removes %s.', [Lines(Removed)])
    else Counts := Format('Replaces %s with %d.', [Lines(Removed), Added]);
    if Change.Notes <> '' then Notes := Change.Notes + '  ' + Counts + '  (' + Tool.Name + ')'
    else Notes := 'The assistant asks to use ' + Tool.Name + '.  ' + Counts;
    D.NotesLabel.Caption := Notes;
    case D.ShowModal of
      mrYes: Result := aaAllow;
      mrAll: Result := aaAllowAll;
    else
      Result := aaDeny;
    end;
    Reason := IdeToUtf8(Trim(D.ReasonEdit.Text));
  finally
    D.Free;
  end;
end;

end.
