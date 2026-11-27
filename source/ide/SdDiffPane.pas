{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDiffPane;

{ D7 Studio - two texts compared in the code editor (the History tab, the Refactorings view): line by
  line with the changed words marked (SdTextDiff), in the code editor's font, colours and zoom -
  inline (a change's removed lines above its added ones, both line numbers in the margin) or side by
  side (the two sides' lines in line and scrolled together). Unchanged stretches are folded to the
  three lines around each change: a click on a fold, or Enter on it, shows its lines. The lines can
  be limited to one routine (Routine), a text marked in them (Find). A control of D7 Studio's own,
  made in code: its windows are TSciWindows. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, ExtCtrls,
  SdUI, SdSciEdit, SdEncoding, SdTextDiff;

type
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

  TSdDiffPane = class(TWinControl)
  private
    FLeft, FRight: TSciWindow;
    FDivider: TPanel;
    FDiff: TLineDiff;
    FLinesL, FLinesR: TDiffLines;
    FExpanded: array of Boolean;       // per run of FDiff: its fold shown whole
    FSideBySide: Boolean;
    FRoutine: string;
    FFind: string;
    FFileName: string;
    FEncoding: TSdEncoding;
    FShownChanges, FShownAdded, FShownRemoved: Integer;
    FSyncing: Boolean;
    FOnZoom: TNotifyEvent;
    FOnOpenLine: TNotifyEvent;
    function NewWindow: TSciWindow;
    procedure Arrange;
    procedure LoadWindow(W: TSciWindow; Texts: TStringList; const Lines: TDiffLines; Count, Digits: Integer;
      Side: Integer);
    function LinesOf(Ed: TSciEdit): TDiffLines;
    function LineAt(Side: TDiffSide; Line: Integer): Integer;
    function ChangeTarget(Next: Boolean): Integer;
    procedure ExpandFold(Run: Integer);
    function ExpandFoldAt(const Lines: TDiffLines; L: Integer): Boolean;
    procedure MarkFind;
    procedure SetSideBySide(Value: Boolean);
    procedure SetFind(const Value: string);
    procedure EditUpdateUI(Sender: TObject; Updated: Integer);
    procedure EditMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditDblClick(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditZoomed(Sender: TObject);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Old against New, compared and shown - every fold shut -, blanks ignored (IgnoreBlanks): in
      the language of FileName, the texts in Encoding }
    procedure Compare(const Old, New: string; IgnoreBlanks: Boolean);
    { nothing compared }
    procedure Clear;
    { the lines of the comparison laid out again (after Routine or SideBySide changed) }
    procedure Render;
    { the editor's options changed: the windows take them }
    procedure ApplyOptions;
    { the window that has the keyboard, else the left one }
    function ActiveWindow: TSciWindow;
    { the lines of the window with the keyboard, and its caret's line }
    function CaretLine(out Lines: TDiffLines): Integer;
    { the caret's line in the Side's text (0-based): a line the side lacks - removed, added, filled, a
      fold - gives where its change begins there; -1: no line }
    function CaretTextLine(Side: TDiffSide): Integer;
    procedure FocusDiff;
    { the caret on line Line of the diff, in view (side by side: in both windows) }
    procedure CaretTo(Line: Integer);
    { line Line of the diff at the top of its windows }
    procedure SetTopLine(Line: Integer);
    { the first line of the new text in view (-1: none), and that line back at the top }
    function TopNewLine: Integer;
    procedure ScrollToNewLine(Line: Integer);
    { line Line of the Side's text shown (a few lines above it) with the caret on it }
    procedure ShowLine(Side: TDiffSide; Line: Integer);
    { the caret on the first change, else on the first line }
    procedure ShowFirstChange;
    function CanGotoChange(Next: Boolean): Boolean;
    procedure GotoChange(Next: Boolean);
    { Alt+Up / Alt+Down: the previous / next change (Key 0 when taken) }
    procedure ChangeKey(var Key: Word; Shift: TShiftState);
    { test mode: a line each of the left (inline) window: kind|old|new|text, then the right window's
      under [right] }
    procedure DiffText(L: TStrings);
    property Diff: TLineDiff read FDiff;
    property LeftLines: TDiffLines read FLinesL;
    property LeftWindow: TSciWindow read FLeft;       // the inline one, the left one side by side
    property RightWindow: TSciWindow read FRight;     // the right one side by side
    property SideBySide: Boolean read FSideBySide write SetSideBySide;
    property Routine: string read FRoutine write FRoutine;  // the routine whose lines alone are shown ('' all)
    property Find: string read FFind write SetFind;         // the text marked in the windows
    property FileName: string read FFileName write FFileName;
    property Encoding: TSdEncoding read FEncoding write FEncoding;
    property ShownChanges: Integer read FShownChanges;
    property ShownAdded: Integer read FShownAdded;
    property ShownRemoved: Integer read FShownRemoved;
    { Ctrl+wheel in a window: the editors' zoom changed }
    property OnZoom: TNotifyEvent read FOnZoom write FOnZoom;
    { a double click, or Enter, on a line that is no fold }
    property OnOpenLine: TNotifyEvent read FOnOpenLine write FOnOpenLine;
  end;

{ N and the noun, its plural but for one: "1 change", "3 changes" }
function CountText(N: Integer; const Noun: string): string;

implementation

uses
  Math, SdSciDefs, SdHistory;

const
  Context = 3;                         // unchanged lines shown around a change

function CountText(N: Integer; const Noun: string): string;
begin
  Result := IntToStr(N) + ' ' + Noun;
  if N <> 1 then Result := Result + 's';
end;

constructor TSdDiffPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEncoding := SystemEncoding;
  FLeft := NewWindow;
  FRight := NewWindow;
  FRight.Visible := False;
  FDivider := TPanel.Create(Self);
  FDivider.BevelOuter := bvNone;
  FDivider.Color := clBtnShadow;
  FDivider.Visible := False;
  FDivider.Parent := Self;
end;

destructor TSdDiffPane.Destroy;
begin
  FreeAndNil(FDiff);
  inherited Destroy;
end;

{ No flicker: the windows cover the pane - it paints nothing over them and is not drawn again
  whole when it is resized }
procedure TSdDiffPane.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
  Params.WindowClass.style := Params.WindowClass.style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure TSdDiffPane.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TSdDiffPane.NewWindow: TSciWindow;
begin
  Result := TSciWindow.Create(Self);
  Result.Borderless := True;
  Result.Parent := Self;
  Result.Edit.DiffView := True;
  Result.Edit.OnZoom := EditZoomed;
  Result.Edit.OnUpdateUI := EditUpdateUI;
  Result.Edit.OnMouseUp := EditMouseUp;
  Result.Edit.OnDblClick := EditDblClick;
  Result.Edit.OnKeyDown := EditKeyDown;
end;

procedure TSdDiffPane.Resize;
begin
  inherited Resize;
  Arrange;
end;

{ inline: one window; side by side: two halves, a flat line between them }
procedure TSdDiffPane.Arrange;
var
  W, H, Half: Integer;
begin
  if (FLeft = nil) or (FRight = nil) or (FDivider = nil) then Exit;
  W := ClientWidth;
  H := ClientHeight;
  if FSideBySide then
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

procedure TSdDiffPane.SetSideBySide(Value: Boolean);
begin
  FSideBySide := Value;
  Arrange;
end;

procedure TSdDiffPane.ApplyOptions;
begin
  FLeft.Edit.ApplyOptions;
  FRight.Edit.ApplyOptions;
end;

function TSdDiffPane.ActiveWindow: TSciWindow;
begin
  if FSideBySide and FRight.Edit.Focused then Result := FRight else Result := FLeft;
end;

procedure TSdDiffPane.Compare(const Old, New: string; IgnoreBlanks: Boolean);
begin
  FreeAndNil(FDiff);
  FDiff := TLineDiff.Create(Old, New, IgnoreBlanks);
  SetLength(FExpanded, 0);
  SetLength(FExpanded, FDiff.RunCount);
  Render;
end;

procedure TSdDiffPane.Clear;
begin
  FreeAndNil(FDiff);
  SetLength(FExpanded, 0);
  SetLength(FLinesL, 0);
  SetLength(FLinesR, 0);
  FShownChanges := 0;
  FShownAdded := 0;
  FShownRemoved := 0;
  FLeft.Edit.LoadFromStringAs('', FEncoding);
  FRight.Edit.LoadFromStringAs('', FEncoding);
end;

{ the lines of the diff windows from FDiff: unchanged runs folded (but for a run shown whole, and
  under a routine filter: the routine's lines alone), a change's removed lines above its added ones -
  side by side across from each other, the shorter side filled -, the find text marked }
procedure TSdDiffPane.Render;
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
    if FSideBySide then
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
    if FSideBySide then AddLine(True, dlFold, -1, -1, '', Count);
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
  if FDiff = nil then Exit;
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
      if FSideBySide then
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
          for I := 0 to High(SB) do AddWord(FSideBySide, Doc[dsNew][K], SB[I].Start, SB[I].Len, IND_DIFF_ADDED);
        end;
    end;
    SetLength(FLinesL, NL);
    SetLength(FLinesR, NR);
    Digits := Max(Length(IntToStr(Max(FDiff.OldLines.Count, FDiff.NewLines.Count))), 3);
    if FSideBySide then
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
  MarkFind;
end;

{ a window's text, its lines' grounds, margins and notes; Side: 0 inline (both numbers), 1 the old
  side, 2 the new side }
procedure TSdDiffPane.LoadWindow(W: TSciWindow; Texts: TStringList; const Lines: TDiffLines;
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
  Ed.SetLanguageFromFile(FFileName);
  Ed.LoadFromStringAs(S, FEncoding);
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

{ --- moving in the diff --- }

function TSdDiffPane.LinesOf(Ed: TSciEdit): TDiffLines;
begin
  if Ed = FRight.Edit then Result := FLinesR else Result := FLinesL;
end;

function TSdDiffPane.CaretLine(out Lines: TDiffLines): Integer;
var
  Ed: TSciEdit;
begin
  Ed := ActiveWindow.Edit;
  Lines := LinesOf(Ed);
  Result := Ed.CaretLine;
end;

function TSdDiffPane.CaretTextLine(Side: TDiffSide): Integer;
var
  L: Integer;
  Lines: TDiffLines;
begin
  Result := -1;
  L := CaretLine(Lines);
  if (FDiff = nil) or (L < 0) or (L > High(Lines)) then Exit;
  if Side = dsOld then Result := Lines[L].OldLine else Result := Lines[L].NewLine;
  if (Result < 0) and (Lines[L].Run >= 0) then Result := RunStart(FDiff[Lines[L].Run], Side);
  if Result < 0 then Result := 0;
end;

procedure TSdDiffPane.FocusDiff;
begin
  if FLeft.Edit.CanFocus then FLeft.Edit.SetFocus;
end;

procedure TSdDiffPane.CaretTo(Line: Integer);
begin
  FLeft.Edit.GotoLineCol(Line, 0, True);
  if FSideBySide then FRight.Edit.GotoLineCol(Line, 0, True);
end;

procedure TSdDiffPane.SetTopLine(Line: Integer);
begin
  FLeft.Edit.Sci(SCI_SETFIRSTVISIBLELINE, Line);
  if FSideBySide then FRight.Edit.Sci(SCI_SETFIRSTVISIBLELINE, Line);
end;

function TSdDiffPane.TopNewLine: Integer;
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

{ the first line of the diff that shows line Line of the Side's text or one after it (-1: none) }
function TSdDiffPane.LineAt(Side: TDiffSide; Line: Integer): Integer;
var
  N: Integer;
begin
  for Result := 0 to High(FLinesL) do
  begin
    if Side = dsOld then N := FLinesL[Result].OldLine else N := FLinesL[Result].NewLine;
    if N >= Line then Exit;
  end;
  Result := -1;
end;

procedure TSdDiffPane.ScrollToNewLine(Line: Integer);
var
  I: Integer;
begin
  I := LineAt(dsNew, Line);
  if I >= 0 then SetTopLine(I);
end;

procedure TSdDiffPane.ShowLine(Side: TDiffSide; Line: Integer);
var
  I: Integer;
begin
  I := LineAt(Side, Line);
  if I < 0 then Exit;
  SetTopLine(Max(I - Context, 0));
  CaretTo(I);
end;

procedure TSdDiffPane.ShowFirstChange;
begin
  CaretTo(Max(FLeft.Edit.MarkerNext(0, 1 shl MK_DIFF_CHANGE), 0));
end;

{ the line of the change after (before) the caret's line (-1: none) }
function TSdDiffPane.ChangeTarget(Next: Boolean): Integer;
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

function TSdDiffPane.CanGotoChange(Next: Boolean): Boolean;
begin
  Result := ChangeTarget(Next) >= 0;
end;

procedure TSdDiffPane.GotoChange(Next: Boolean);
var
  T: Integer;
begin
  T := ChangeTarget(Next);
  if T >= 0 then CaretTo(T);
end;

procedure TSdDiffPane.ChangeKey(var Key: Word; Shift: TShiftState);
begin
  if not (Key in [VK_UP, VK_DOWN]) or (Shift <> [ssAlt]) then Exit;
  GotoChange(Key = VK_DOWN);
  Key := 0;
end;

procedure TSdDiffPane.ExpandFold(Run: Integer);
var
  Place: Integer;
begin
  if (Run < 0) or (Run > High(FExpanded)) then Exit;
  Place := FLeft.Edit.Sci(SCI_GETFIRSTVISIBLELINE);
  FExpanded[Run] := True;
  Render;
  SetTopLine(Place);
end;

{ line L of Lines is a fold: its lines shown (False: no fold there) }
function TSdDiffPane.ExpandFoldAt(const Lines: TDiffLines; L: Integer): Boolean;
begin
  Result := (L >= 0) and (L <= High(Lines)) and (Lines[L].Kind = dlFold);
  if Result then ExpandFold(Lines[L].Run);
end;

procedure TSdDiffPane.MarkFind;
begin
  FLeft.Edit.MarkMatches(FFind, False, False, False);
  if FSideBySide then FRight.Edit.MarkMatches(FFind, False, False, False);
end;

procedure TSdDiffPane.SetFind(const Value: string);
begin
  FFind := Value;
  MarkFind;
end;

{ --- the windows --- }

{ side by side, the other side scrolls with the one that scrolled }
procedure TSdDiffPane.EditUpdateUI(Sender: TObject; Updated: Integer);
var
  A, B: TSciEdit;
begin
  if FSyncing or not FSideBySide or (Updated and (SC_UPDATE_V_SCROLL or SC_UPDATE_H_SCROLL) = 0) then Exit;
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

{ a click on a fold shows its lines }
procedure TSdDiffPane.EditMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Ed: TSciEdit;
begin
  if Button <> mbLeft then Exit;
  Ed := TSciEdit(Sender);
  ExpandFoldAt(LinesOf(Ed), Ed.Sci(SCI_LINEFROMPOSITION, Ed.Sci(SCI_POSITIONFROMPOINT, X, Y)));
end;

procedure TSdDiffPane.EditDblClick(Sender: TObject);
begin
  if Assigned(FOnOpenLine) then FOnOpenLine(Self);
end;

{ Enter: a fold shown, else the line opened; Alt+Up / Alt+Down: the changes }
procedure TSdDiffPane.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  L: Integer;
  Lines: TDiffLines;
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    L := CaretLine(Lines);
    if not ExpandFoldAt(Lines, L) and Assigned(FOnOpenLine) then FOnOpenLine(Self);
    Key := 0;
  end
  else
    ChangeKey(Key, Shift);
end;

procedure TSdDiffPane.EditZoomed(Sender: TObject);
begin
  if Assigned(FOnZoom) then FOnZoom(Self);
end;

procedure TSdDiffPane.DiffText(L: TStrings);
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
  if FSideBySide then
  begin
    L.Add('[right]');
    Lines(FLinesR, FRight);
  end;
end;

end.
