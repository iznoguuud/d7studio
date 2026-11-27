{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdHints;

{ D7 Studio - the hints. Every hint has the look of D7 Studio's menus: the
  window's ground, a flat 1 px border, square corners, Windows' drop shadow and room around the
  text; it appears at once, without a fade. TSdHintWindow is the VCL's hint window
  (HintWindowClass: the hints of the tool buttons and the controls, the form designer's names);
  TSdCodeTip shows code in the editor's font and colours - the declaration under the mouse, an
  expert's hint, the parameter hints (SdCompletion); TSdValueTip is the debugger's value under the
  mouse, a tree whose rows open with a click. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, ExtCtrls, SdDbgEval;

type
  { a piece of a line of a tip: its text, colour and style, in the code's font (the code
    editor's) or the UI font; Boxed: on the accent box (the parameter at the caret) }
  TTipRun = record
    Text: string;
    Color: TColor;
    Style: TFontStyles;
    Code: Boolean;
    Boxed: Boolean;
  end;
  TTipRuns = array of TTipRun;

  { a line of a tip; Rule: a flat line across the tip above it }
  TTipLine = record
    Runs: TTipRuns;
    Rule: Boolean;
  end;
  TTipLines = array of TTipLine;

  { The frame of every hint: a topmost pop-up of the program's window that never takes the
    activation; the flat border over its 1 px frame, the ground and the content painted through
    one buffer (no erase). Shown at once, never by the VCL (it stays not Visible). }
  TSdTipWindow = class(THintWindow)
  private
    FBuffer: TBitmap;
    FTipShown: Boolean;
    FSource: TObject;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMNCPaint(var Message: TMessage); message WM_NCPAINT;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure NCPaint(DC: HDC); override;
    procedure Paint; override;
    { the content on DC in R - the client inside the padding -, on the ground already painted }
    procedure PaintContent(DC: HDC; const R: TRect); virtual;
    { the window made, owned by the program's window as the VCL's hints are }
    procedure TipHandleNeeded;
    { at R (screen: the window's bounds), topmost, not activated, painted at once }
    procedure ShowAt(const R: TRect);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure HideTip; virtual;
    property TipShown: Boolean read FTipShown;
    { what the tip is shown for (an editor): a page closes only its own tips }
    property Source: TObject read FSource write FSource;
  end;

  { the VCL's hint window (HintWindowClass, InstallHintWindow): the hint's lines in the UI font,
    wrapped in the width the VCL allows; the part of a line after a tab - a shortcut key - in grey
    at the line's right end }
  TSdHintWindow = class(TSdTipWindow)
  protected
    procedure PaintContent(DC: HDC; const R: TRect); override;
  public
    procedure ActivateHint(Rect: TRect; const AHint: string); override;
    function CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect; override;
  end;

  { a tip of lines of runs: code in the editor's font and colours. The mouse goes through it }
  TSdCodeTip = class(TSdTipWindow)
  private
    FLines: TTipLines;
    FWrap: Integer;              // the width its lines wrap in
  protected
    procedure PaintContent(DC: HDC; const R: TRect); override;
  public
    { ALines for the text at Line (screen: Line.Left where the text starts, Top and Bottom its
      line's): below the line, else above it, else on the side with more room on the work area of
      Line's monitor; at most 120 characters of the code wide (TipMaxChars) - a longer line wraps }
    procedure ShowLines(const ALines: TTipLines; const Line: TRect; ASource: TObject);
    function DebugText: string;  // the lines' texts, '|' after each, '--|' for a rule (tests)
  end;

  { the rows of an item of the value tip that is opened: Expr's members or elements }
  TValueTipChildren = function(const Expr: string; out Vars: TDbgVarArray): Boolean of object;

  { The debugger's value under the mouse: a tree in two columns,
    the names and the values. An item with members opens and closes with a click on its row - its
    rows are asked for then. It takes the mouse (not the activation): it stays while the pointer
    is on it or on the text it is shown for, and scrolls when it is longer than the room beside its
    line. }
  TSdValueTip = class(TSdTipWindow)
  private
    FNodes: TList;               // every item made (TValueNode)
    FRoot: TObject;              // the first item: the value shown
    FRows: TList;                // the rows shown, in order
    FTopRow: Integer;            // the first row in view
    FPageRows: Integer;          // rows in view
    FHotRow: Integer;            // the row under the pointer (-1: none)
    FWheel: Integer;             // a part of a wheel notch not used yet
    FChildren: TValueTipChildren;
    FExpr: string;
    FHover, FLine: TRect;        // the text it is shown for and that text's line (screen)
    FAbove: Boolean;             // ... above the line: its bottom stays at the line
    FTimer: TTimer;
    FRowH, FGlyph, FValueX: Integer;     // the layout: row height, glyph size, the values' column
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMMouseActivate(var Message: TWMMouseActivate); message WM_MOUSEACTIVATE;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
    procedure WMMouseLeave(var Message: TMessage); message WM_MOUSELEAVE;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMThemeChanged(var Message: TMessage); message WM_THEMECHANGED;
    procedure TimerTick(Sender: TObject);
    function NewNode(const V: TDbgVar; Level: Integer): TObject;
    procedure ClearNodes;
    procedure Load(Node: TObject);
    procedure Toggle(Row: Integer);
    procedure Layout(Place: Boolean);
    function RowAt(Y: Integer): Integer;
    procedure ScrollTo(Row: Integer);
    procedure SetHotRow(Row: Integer);
    procedure InvalidateRow(Row: Integer);
  protected
    procedure PaintContent(DC: HDC; const R: TRect); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Root's value for the text Hover (screen) on the line Line; the rows of an item that is
      opened come from AChildren. A record, or an array of records, shows its members at once }
    procedure ShowValue(const Root: TDbgVar; const Hover, Line: TRect; ASource: TObject;
      AChildren: TValueTipChildren);
    procedure HideTip; override;
    { the expression shown (Root.Name) }
    property Expr: string read FExpr;
    { rows, first row in view, rows in view, row height, glyph size, the values' column, above
      the line; then a row each: level, '+' closed / '-' open / ' ', name '=' what it shows
      (tests: the row of client y Y is FirstRow + (Y - 4) div RowHeight - 4 px: TipPadY) }
    function DebugText: string;
  end;

{ D7 Studio's hint window for the VCL (HintWindowClass) on the window's ground: once, at the start }
procedure InstallHintWindow;
{ a run of S at the end of Runs (it continues the last one when it looks the same) }
procedure AddTipRun(var Runs: TTipRuns; const S: string; Color: TColor; Style: TFontStyles; Code: Boolean;
  Boxed: Boolean = False);
{ Pascal code S as runs in the editor's colours (its tokens, SdPasLex): reserved words, strings,
  numbers, comments, directives as the Color page has them. Decl - a declaration: its directives
  are reserved words too (out, stdcall, overload, read ...) where they name nothing. Extra styles
  every run, Boxed puts them on the accent box (the parameter at the caret: bold, boxed) }
procedure AddCodeRuns(var Runs: TTipRuns; const S: string; Decl: Boolean; Extra: TFontStyles = [];
  Boxed: Boolean = False);
{ Runs as a line at the end of Lines (Rule: a flat line above it) }
procedure AddTipLine(var Lines: TTipLines; const Runs: TTipRuns; Rule: Boolean = False);
{ a declaration's hint of code insight (TCodeInsight.GetHint: the declaration, a line break, its
  place): the declaration as code, a rule, the place in grey in the UI font }
function DeclTipLines(const Hint: string): TTipLines;
{ a text's lines in the code's font, not coloured (an expert's hint: its language is its own) }
function TextTipLines(const Text: string): TTipLines;
{ Error Insight's messages, a line each in the UI font, in the colour of its marks }
function ErrorTipLines(const Msgs: array of string): TTipLines;
{ More after Lines - a rule above them when Lines has some }
procedure AppendTipLines(var Lines: TTipLines; const More: TTipLines);

implementation

uses
  Forms, Math, SdUI, SdPasLex, SdEditorThemes, SdEditorOptions;

const
  TipPadX = 8;                    // room left and right of a hint's text (the tabs' padding)
  TipPadY = 4;                    // ... above and below it
  TipMaxChars = 120;              // the widest code tip and value row: characters of the code's font
  TipShortcutGap = 2 * TipPadX;   // between a hint's text and its shortcut key
  TipRuleGap = TipPadY;           // above and below a rule
  TipLineGap = 2;                 // between two lines of a code tip
  TipBoxPadX = 2;                 // the accent box of the parameter at the caret: beside its text
  TipBoxPadY = TipLineGap div 2;  // ... above and below it - two lines' boxes never overlap
  GlyphGap = 2;                   // between a value row's glyph and its name
  ValueTipMaxRows = 40;           // the rows a value tip shows; more scroll
  ValueTipWheelRows = 3;          // rows per notch of the wheel
  ValueTipPoll = 100;             // ms between two looks where the pointer is

type
  { an item of the value tip's tree }
  TValueNode = class
  public
    Name, Value, TypeName, Expr: string;
    Level: Integer;
    Expandable, Expanded, Loaded: Boolean;
    Children: TList;             // its items once loaded (owned by the tip's list)
    Runs: TTipRuns;              // what its row shows as its value (ValueRuns) ...
    RunsMade, RunsOpen: Boolean; // ... made, for the item open or not (its type then)
    destructor Destroy; override;
  end;

destructor TValueNode.Destroy;
begin
  Children.Free;
  inherited Destroy;
end;

{ --- fonts and text ------------------------------------------------------------------------- }

var
  TipFonts: array[Boolean, Boolean, Boolean] of TFont;   // [Code, Bold, Italic]
  TipFontKey: array[Boolean] of string;                  // the face and size they were made for
  MeasureDC: HDC;                                         // text measured without a window

function FontKey(Code: Boolean): string;
begin
  if Code then
    Result := EditorOptions.FontName + '|' + IntToStr(EditorOptions.FontSize)
  else if UIFont <> nil then
    Result := UIFont.Name + '|' + IntToStr(UIFont.Size)
  else
    Result := '';
end;

{ the code's font (the editor's: Editor Options' font and size, not the zoom) or the UI font, in
  Style; made again when Editor Options or the UI font changed }
function TipFont(Code: Boolean; Style: TFontStyles): TFont;
var
  B, I: Boolean;
  K: string;
begin
  K := FontKey(Code);
  if K <> TipFontKey[Code] then
  begin
    for B := False to True do
      for I := False to True do
        FreeAndNil(TipFonts[Code, B, I]);
    TipFontKey[Code] := K;
  end;
  B := fsBold in Style;
  I := fsItalic in Style;
  Result := TipFonts[Code, B, I];
  if Result <> nil then Exit;
  Result := TFont.Create;
  if Code then
  begin
    Result.Name := EditorOptions.FontName;
    if EditorOptions.FontSize > 0 then Result.Size := EditorOptions.FontSize;
    Result.Charset := DEFAULT_CHARSET;
  end
  else if UIFont <> nil then
    Result.Assign(UIFont);
  Result.Color := clWindowText;
  Result.Style := Style * [fsBold, fsItalic];
  TipFonts[Code, B, I] := Result;
end;

function TipDC: HDC;
begin
  if MeasureDC = 0 then MeasureDC := CreateCompatibleDC(0);
  Result := MeasureDC;
end;

{ the height of the text of DC's font (tmHeight) }
function DCTextHeight(DC: HDC): Integer;
var
  TM: TTextMetric;
begin
  GetTextMetrics(DC, TM);
  Result := TM.tmHeight;
end;

{ Chars average characters of the code's font }
function CodeWidth(Chars: Integer): Integer;
var
  TM: TTextMetric;
  Old: HGDIOBJ;
begin
  Old := SelectObject(TipDC, TipFont(True, []).Handle);
  GetTextMetrics(TipDC, TM);
  SelectObject(TipDC, Old);
  Result := Chars * TM.tmAveCharWidth;
end;

{ the colours of code in a tip: the editor theme's while its ground is light, else D7 Studio's
  Light theme's - a tip has the window's ground }
procedure TipColors(var C: TEditorColors);
begin
  C := EditorOptions.Colors;
  if EditorIsDark(C) then BuiltinThemeColors(DefaultThemeName, C);
end;

{ ... of a variable's name (the completion list's colour of variables) }
function TipVariableColor: TColor;
var
  C: TEditorColors;
begin
  TipColors(C);
  Result := ElementFore(C, eeCompVariable);
end;

{ the flat line between a declaration and its place (the menus' separator) }
function RuleColor: TColor;
begin
  Result := UISeparatorColor(clWindow);
end;

procedure AddTipRun(var Runs: TTipRuns; const S: string; Color: TColor; Style: TFontStyles; Code: Boolean;
  Boxed: Boolean);
var
  N: Integer;
begin
  if S = '' then Exit;
  N := Length(Runs);
  if (N > 0) and (Runs[N - 1].Color = Color) and (Runs[N - 1].Style = Style) and (Runs[N - 1].Code = Code) and
    (Runs[N - 1].Boxed = Boxed) then
    Runs[N - 1].Text := Runs[N - 1].Text + S
  else
  begin
    SetLength(Runs, N + 1);
    Runs[N].Text := S;
    Runs[N].Color := Color;
    Runs[N].Style := Style;
    Runs[N].Code := Code;
    Runs[N].Boxed := Boxed;
  end;
end;

procedure AddTipLine(var Lines: TTipLines; const Runs: TTipRuns; Rule: Boolean);
var
  N: Integer;
begin
  N := Length(Lines);
  SetLength(Lines, N + 1);
  Lines[N].Runs := Runs;
  Lines[N].Rule := Rule;
end;

{ a directive word of a declaration that is one there: not a name - not after a routine's or a
  property's word or a '.', not before ':', ',', '=', '(', '[' or ')' }
function DirectiveHere(Toks: TRawToks; I: Integer): Boolean;
var
  J: Integer;
begin
  Result := False;
  J := I - 1;
  while (J >= 0) and (Toks.T[J].Kind = tkComment) do Dec(J);
  if (J >= 0) and (Toks.IsSy(J, syDot) or (Toks.T[J].Keyword in [kwProcedure, kwFunction, kwConstructor,
    kwDestructor, kwProperty])) then Exit;
  J := Toks.NextCode(I);
  if (J < Toks.N) and (Toks.T[J].Kind = tkSymbol) and
    (Toks.T[J].Symbol in [syColon, syComma, syEqual, syLParen, syLBracket, syRParen]) then Exit;
  Result := True;
end;

{ the element of the Color page that token I has (as the editor's Pascal lexer colours it) }
function TokenElement(Toks: TRawToks; I: Integer; Decl: Boolean): TEditorElement;
begin
  case Toks.T[I].Kind of
    tkKeyword: Result := eeReservedWord;
    tkString: Result := eeString;
    tkNumber:
      if Toks.T[I].Ptr^ = '$' then Result := eeHex else Result := eeNumber;
    tkComment:
      if Toks.IsDirective(I) then Result := eeDirective else Result := eeComment;
    tkSymbol: Result := eeSymbol;
  else
    if Decl and (Toks.T[I].Directive <> dvNone) and DirectiveHere(Toks, I) then
      Result := eeReservedWord
    else
      Result := eeIdentifier;
  end;
end;

procedure AddCodeRuns(var Runs: TTipRuns; const S: string; Decl: Boolean; Extra: TFontStyles;
  Boxed: Boolean);
var
  C: TEditorColors;
  Toks: TRawToks;
  I, P: Integer;

  procedure Add(const Text: string; E: TEditorElement);
  var
    St: TFontStyles;
  begin
    St := Extra;
    if E <> eePlainText then          // the blanks between the tokens; no underline in a tip
      St := St + (ElementFontStyles(C[E]) - [fsUnderline]);
    AddTipRun(Runs, Text, ElementFore(C, E), St, True, Boxed);
  end;

begin
  TipColors(C);
  Toks := TRawToks.Create(S, True);
  try
    P := 0;
    for I := 0 to Toks.N - 1 do
    begin
      if Toks.T[I].Start > P then Add(Copy(S, P + 1, Toks.T[I].Start - P), eePlainText);
      Add(Copy(S, Toks.T[I].Start + 1, Toks.T[I].Len), TokenElement(Toks, I, Decl));
      P := Toks.T[I].Start + Toks.T[I].Len;
    end;
    if P < Length(S) then Add(Copy(S, P + 1, MaxInt), eePlainText);
  finally
    Toks.Free;
  end;
end;

function DeclTipLines(const Hint: string): TTipLines;
var
  P: Integer;
  Decl, Place: string;
  Runs: TTipRuns;
begin
  Result := nil;
  Decl := Hint;
  Place := '';
  P := Pos(#10, Hint);
  if P > 0 then
  begin
    Decl := TrimRight(Copy(Hint, 1, P - 1));
    Place := Trim(Copy(Hint, P + 1, MaxInt));
  end;
  Runs := nil;
  AddCodeRuns(Runs, Decl, True);
  AddTipLine(Result, Runs);
  if Place <> '' then
  begin
    Runs := nil;
    AddTipRun(Runs, Place, clGrayText, [], False);
    AddTipLine(Result, Runs, True);
  end;
end;

function ErrorTipLines(const Msgs: array of string): TTipLines;
var
  I: Integer;
  C: TEditorColors;
  Runs: TTipRuns;
begin
  Result := nil;
  TipColors(C);
  for I := Low(Msgs) to High(Msgs) do
  begin
    Runs := nil;
    AddTipRun(Runs, Msgs[I], ErrorMarkColor(C), [], False);
    AddTipLine(Result, Runs);
  end;
end;

procedure AppendTipLines(var Lines: TTipLines; const More: TTipLines);
var
  I, N: Integer;
begin
  N := Length(Lines);
  SetLength(Lines, N + Length(More));
  for I := 0 to High(More) do Lines[N + I] := More[I];
  if (N > 0) and (Length(More) > 0) then Lines[N].Rule := True;
end;

function TextTipLines(const Text: string): TTipLines;
var
  L: TStringList;
  I: Integer;
  C: TEditorColors;
  Runs: TTipRuns;
begin
  Result := nil;
  TipColors(C);
  L := TStringList.Create;
  try
    L.Text := StringReplace(Text, #9, '  ', [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
    begin
      Runs := nil;
      AddTipRun(Runs, L[I], ElementFore(C, eePlainText), [], True);
      AddTipLine(Result, Runs);
    end;
  finally
    L.Free;
  end;
end;

type
  { a pass of LayoutTipLines: measure only, draw the accent boxes, draw the text }
  TTipPass = (tpMeasure, tpBoxes, tpText);

{ Lines on DC from X, Y in Width: a line longer than Width wraps at its spaces, the rest two
  spaces further in, a word longer than Width is cut with '...'; TipLineGap between two lines, a
  rule above a line that has one, from RuleX1 to RuleX2; boxed runs on one accent box per line.
  What Pass draws: nothing, the boxes, the text (and the rules) - the boxes first, as the text is
  drawn over them. The size the lines take: one routine measures and draws, so that they always
  agree. }
function LayoutTipLines(DC: HDC; const Lines: TTipLines; X, Y, Width: Integer; Pass: TTipPass;
  RuleX1, RuleX2: Integer): TSize;
var
  L, K, P, Q, CX, LineH, H, Indent, W, TW, Y0: Integer;
  BoxL, BoxR, BoxY, BoxH: Integer;     // the accent box being gathered (BoxL < 0: none)
  Run: TTipRun;
  Word: string;
  Fresh: Boolean;          // the line just wrapped: spaces at its start go
  Old: HGDIOBJ;
  R: TRect;

  procedure FlushBox;
  begin
    if (BoxL >= 0) and (Pass = tpBoxes) then
      UIDrawFlatButton(DC, Rect(BoxL - TipBoxPadX, BoxY - TipBoxPadY, BoxR + TipBoxPadX, BoxY + BoxH + TipBoxPadY),
        bsHot, clWindow);
    BoxL := -1;
  end;

begin
  Result.cx := 0;
  Y0 := Y;
  BoxL := -1;
  Old := SelectObject(DC, TipFont(False, []).Handle);
  try
    for L := 0 to High(Lines) do
    begin
      if Lines[L].Rule and (L > 0) then
      begin
        Inc(Y, TipRuleGap);
        if Pass = tpText then UIHLine(DC, RuleX1, RuleX2, Y, RuleColor);
        Inc(Y, 1 + TipRuleGap);
      end
      else if L > 0 then
        Inc(Y, TipLineGap);
      CX := X;
      LineH := 0;
      Indent := -1;
      Fresh := False;
      for K := 0 to High(Lines[L].Runs) do
      begin
        Run := Lines[L].Runs[K];
        SelectObject(DC, TipFont(Run.Code, Run.Style).Handle);
        H := DCTextHeight(DC);
        if Indent < 0 then Indent := UITextWidth(DC, '  ');
        if H > LineH then LineH := H;
        { word by word: a word with the spaces after it }
        P := 1;
        while P <= Length(Run.Text) do
        begin
          Q := P;
          while (Q <= Length(Run.Text)) and (Run.Text[Q] <> ' ') do Inc(Q);
          while (Q <= Length(Run.Text)) and (Run.Text[Q] = ' ') do Inc(Q);
          Word := Copy(Run.Text, P, Q - P);
          P := Q;
          TW := UITextWidth(DC, TrimRight(Word));
          if (CX > X) and not Fresh and (CX + TW > X + Width) then
          begin
            FlushBox;
            Inc(Y, LineH + TipLineGap);
            LineH := H;
            CX := X + Indent;
            Fresh := True;
          end;
          if Fresh then
          begin
            if Trim(Word) = '' then Continue;
            Fresh := False;
          end;
          W := UITextWidth(DC, Word);
          if CX + TW > X + Width then
          begin
            { longer than the whole width: cut }
            if Pass = tpText then
            begin
              R := Rect(CX, Y, X + Width, Y + H);
              UIText(DC, TrimRight(Word), R, DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS, Run.Color);
            end;
            TW := X + Width - CX;
            W := TW;
          end
          else if Pass = tpText then
          begin
            R := Rect(CX, Y, CX + W, Y + H);
            UIText(DC, Word, R, DT_SINGLELINE or DT_NOPREFIX or DT_NOCLIP, Run.Color);
          end;
          { a boxed run's words (not its spaces at the end) make the box; any other word ends it }
          if not Run.Boxed then
            FlushBox
          else if TW > 0 then
          begin
            if BoxL < 0 then
            begin
              BoxL := CX;
              BoxY := Y;
              BoxH := H;
            end;
            BoxR := CX + TW;
          end;
          if CX + TW - X > Result.cx then Result.cx := CX + TW - X;
          Inc(CX, W);
        end;
      end;
      FlushBox;
      if LineH = 0 then LineH := DCTextHeight(DC);     // an empty line
      Inc(Y, LineH);
    end;
  finally
    SelectObject(DC, Old);
  end;
  Result.cy := Y - Y0;
end;

{ the width of Runs on DC }
function RunsWidth(DC: HDC; const Runs: TTipRuns): Integer;
var
  I: Integer;
  Old: HGDIOBJ;
begin
  Result := 0;
  Old := SelectObject(DC, TipFont(False, []).Handle);
  try
    for I := 0 to High(Runs) do
    begin
      SelectObject(DC, TipFont(Runs[I].Code, Runs[I].Style).Handle);
      Inc(Result, UITextWidth(DC, Runs[I].Text));
    end;
  finally
    SelectObject(DC, Old);
  end;
end;

{ Runs on one line from X in R (its top and bottom, the text centred there), cut with '...'
  where they pass R.Right }
procedure DrawRunsCut(DC: HDC; const Runs: TTipRuns; X: Integer; const R: TRect);
var
  I, W: Integer;
  Old: HGDIOBJ;
  T: TRect;
begin
  Old := SelectObject(DC, TipFont(False, []).Handle);
  try
    for I := 0 to High(Runs) do
    begin
      if X >= R.Right then Break;
      SelectObject(DC, TipFont(Runs[I].Code, Runs[I].Style).Handle);
      W := UITextWidth(DC, Runs[I].Text);
      T := Rect(X, R.Top, Min(X + W, R.Right), R.Bottom);
      if X + W > R.Right then
        UIText(DC, Runs[I].Text, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, Runs[I].Color)
      else
        UIText(DC, Runs[I].Text, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_NOCLIP, Runs[I].Color);
      Inc(X, W);
    end;
  finally
    SelectObject(DC, Old);
  end;
end;

{ the VCL hint's text on DC in the UI font, from X, Y in Width - its lines wrapped there; a line's
  part after a tab (a shortcut key) in grey at the right end, TipShortcutGap after the rest. Drawn
  when Draw; the size it takes (one routine measures and draws) }
function HintLayout(DC: HDC; const Text: string; X, Y, Width: Integer; Draw: Boolean): TSize;
var
  Lines: TStringList;
  I, P, W, H, LineH: Integer;
  S, Key: string;
  R: TRect;
  Old: HGDIOBJ;
begin
  Result.cx := 0;
  Result.cy := 0;
  Old := SelectObject(DC, TipFont(False, []).Handle);
  Lines := TStringList.Create;
  try
    LineH := DCTextHeight(DC);
    Lines.Text := Text;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I];
      P := Pos(#9, S);
      if P > 0 then
      begin
        Key := Trim(Copy(S, P + 1, MaxInt));
        S := Copy(S, 1, P - 1);
        W := UITextWidth(DC, S) + TipShortcutGap + UITextWidth(DC, Key);
        H := LineH;
        if Draw then
        begin
          R := Rect(X, Y, X + Width, Y + H);
          UIText(DC, S, R, DT_SINGLELINE or DT_NOPREFIX, clWindowText);
          R := Rect(X, Y, X + Width, Y + H);
          UIText(DC, Key, R, DT_SINGLELINE or DT_NOPREFIX or DT_RIGHT, clGrayText);
        end;
      end
      else
      begin
        R := Rect(X, Y, X + Width, Y);
        UIText(DC, S, R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX, clWindowText);
        W := R.Right - R.Left;
        H := Max(R.Bottom - R.Top, LineH);
        if Draw then
        begin
          R := Rect(X, Y, X + Width, Y + H);
          UIText(DC, S, R, DT_WORDBREAK or DT_NOPREFIX, clWindowText);
        end;
      end;
      if W > Result.cx then Result.cx := W;
      Inc(Y, H);
      Inc(Result.cy, H);
    end;
  finally
    Lines.Free;
    SelectObject(DC, Old);
  end;
end;

procedure InstallHintWindow;
begin
  HintWindowClass := TSdHintWindow;
  Application.HintColor := clWindow;
end;

{ --- TSdTipWindow --- }

constructor TSdTipWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { shown by ShowAt only: a visible control would be shown by the VCL as soon as it gets the
    program's window as its owner (UpdateShowing) }
  Visible := False;
  Color := clWindow;
end;

destructor TSdTipWindow.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TSdTipWindow.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := WS_POPUP or WS_BORDER;
    ExStyle := ExStyle or WS_EX_TOOLWINDOW;
    WindowClass.Style := WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW) or CS_DROPSHADOW or CS_SAVEBITS;
  end;
end;

procedure TSdTipWindow.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;                  // Paint fills everything
end;

{ the frame: the flat border over Windows' 1 px line; a scroll bar (the value tip's) is Windows'
  own, drawn first }
procedure TSdTipWindow.WMNCPaint(var Message: TMessage);
var
  DC: HDC;
begin
  if GetWindowLong(Handle, GWL_STYLE) and WS_VSCROLL <> 0 then DefaultHandler(Message);
  DC := GetWindowDC(Handle);
  try
    NCPaint(DC);
  finally
    ReleaseDC(Handle, DC);
  end;
end;

procedure TSdTipWindow.NCPaint(DC: HDC);
var
  R: TRect;
begin
  GetWindowRect(Handle, R);
  OffsetRect(R, -R.Left, -R.Top);
  UIDrawBorder(DC, R);
end;

{ the size is the tip's own (CalcHintRect, ShowLines): a new text only repaints }
procedure TSdTipWindow.CMTextChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure TSdTipWindow.Paint;
var
  DC: HDC;
  R: TRect;
begin
  DC := UIBufferDC(FBuffer, Self);
  R := ClientRect;
  UIFill(DC, R, Color);
  InflateRect(R, -TipPadX, -TipPadY);
  PaintContent(DC, R);
  UIBufferFlush(FBuffer, Canvas);
end;

procedure TSdTipWindow.PaintContent(DC: HDC; const R: TRect);
begin
end;

procedure TSdTipWindow.TipHandleNeeded;
begin
  if ParentWindow = 0 then ParentWindow := Application.Handle;
  HandleNeeded;
end;

{ the frame is made again with the bounds (SWP_FRAMECHANGED): a scroll bar that came or went with
  a new size - the value tip's - is drawn whole at once, not only where the window grew.
  SWP_NOOWNERZORDER: the tip is owned by the application window, which owns the main window too -
  without it Windows moves that owner's windows up with the tip, and a tip shown while another
  program lies over the IDE lifted the IDE above that program }
procedure TSdTipWindow.ShowAt(const R: TRect);
begin
  TipHandleNeeded;
  UpdateBoundsRect(R);
  SetWindowPos(Handle, HWND_TOPMOST, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top,
    SWP_NOACTIVATE or SWP_SHOWWINDOW or SWP_FRAMECHANGED or SWP_NOOWNERZORDER);
  FTipShown := True;
  Invalidate;
  Update;
end;

procedure TSdTipWindow.HideTip;
begin
  FTipShown := False;
  FSource := nil;
  if HandleAllocated then
    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOZORDER or SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or
      SWP_HIDEWINDOW);
end;

{ --- TSdHintWindow --- }

function TSdHintWindow.CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect;
var
  S: TSize;
begin
  S := HintLayout(TipDC, AHint, 0, 0, Max(MaxWidth - 2 * TipPadX - 2, 1), False);
  Result := Rect(0, 0, S.cx + 2 * TipPadX + 2, S.cy + 2 * TipPadY + 2);
end;

{ Rect from CalcHintRect, where the VCL puts it (below the pointer); whole on the monitor of its
  top left corner }
procedure TSdHintWindow.ActivateHint(Rect: TRect; const AHint: string);
begin
  Caption := AHint;
  UIFitWorkAreaAt(Rect, Rect.TopLeft);
  ShowAt(Rect);
end;

procedure TSdHintWindow.PaintContent(DC: HDC; const R: TRect);
begin
  HintLayout(DC, Caption, R.Left, R.Top, R.Right - R.Left, True);
end;

{ --- TSdCodeTip --- }

procedure TSdCodeTip.ShowLines(const ALines: TTipLines; const Line: TRect; ASource: TObject);
var
  WA, R: TRect;
  S: TSize;
begin
  FLines := ALines;
  Source := ASource;
  WA := UIWorkAreaAt(Line.TopLeft);
  FWrap := Max(Min(CodeWidth(TipMaxChars), WA.Right - WA.Left - 2 * TipPadX - 2), 1);
  S := LayoutTipLines(TipDC, FLines, 0, 0, FWrap, tpMeasure, 0, 0);
  R := Bounds(Line.Left - TipPadX - 1, Line.Bottom, S.cx + 2 * TipPadX + 2, S.cy + 2 * TipPadY + 2);
  UIFitWorkAreaAt(R, Line.TopLeft);
  UITipOffLine(R, Line);
  ShowAt(R);
end;

procedure TSdCodeTip.PaintContent(DC: HDC; const R: TRect);
begin
  LayoutTipLines(DC, FLines, R.Left, R.Top, FWrap, tpBoxes, 0, 0);
  LayoutTipLines(DC, FLines, R.Left, R.Top, FWrap, tpText, R.Left - TipPadX, R.Right + TipPadX);
end;

function TSdCodeTip.DebugText: string;
var
  I, K: Integer;
begin
  Result := '';
  if not TipShown then Exit;
  for I := 0 to High(FLines) do
  begin
    if FLines[I].Rule then Result := Result + '--|';
    for K := 0 to High(FLines[I].Runs) do Result := Result + FLines[I].Runs[K].Text;
    Result := Result + '|';
  end;
end;

{ --- TSdValueTip --- }

constructor TSdValueTip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FNodes := TList.Create;
  FRows := TList.Create;
  FHotRow := -1;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := ValueTipPoll;
  FTimer.OnTimer := TimerTick;
end;

destructor TSdValueTip.Destroy;
begin
  ClearNodes;
  FNodes.Free;
  FRows.Free;
  inherited Destroy;
end;

function TSdValueTip.NewNode(const V: TDbgVar; Level: Integer): TObject;
var
  N: TValueNode;
begin
  N := TValueNode.Create;
  N.Name := V.Name;
  N.Value := V.Value;
  N.TypeName := V.TypeName;
  N.Expr := V.Expr;
  N.Level := Level;
  N.Expandable := V.Expandable;
  FNodes.Add(N);
  Result := N;
end;

procedure TSdValueTip.ClearNodes;
var
  I: Integer;
begin
  for I := 0 to FNodes.Count - 1 do TObject(FNodes[I]).Free;
  FNodes.Clear;
  FRows.Clear;
  FRoot := nil;
end;

{ an item's rows, asked for when it is first opened; one without any cannot be opened }
procedure TSdValueTip.Load(Node: TObject);
var
  N: TValueNode;
  Vars: TDbgVarArray;
  I: Integer;
begin
  N := TValueNode(Node);
  N.Loaded := True;
  Vars := nil;
  if not Assigned(FChildren) or not FChildren(N.Expr, Vars) or (Length(Vars) = 0) then
  begin
    N.Expandable := False;
    Exit;
  end;
  N.Children := TList.Create;
  for I := 0 to High(Vars) do N.Children.Add(NewNode(Vars[I], N.Level + 1));
end;

procedure TSdValueTip.ShowValue(const Root: TDbgVar; const Hover, Line: TRect; ASource: TObject;
  AChildren: TValueTipChildren);
var
  N: TValueNode;
begin
  ClearNodes;
  FChildren := AChildren;
  FExpr := Root.Name;
  FHover := Hover;
  FLine := Line;
  Source := ASource;
  N := TValueNode(NewNode(Root, 0));
  FRoot := N;
  { a record, or an array of records, shows its members at once }
  if N.Expandable and DbgValueIsList(N.Value) then
  begin
    Load(N);
    N.Expanded := N.Expandable;
  end;
  FTopRow := 0;
  FHotRow := -1;
  FWheel := 0;
  Layout(True);
  { the pointer is looked for while the tip shows - not in the test instance, whose pointer is
    the user's (the tests close it as a key or a scroll does) }
  FTimer.Enabled := not UITestMode;
end;

procedure TSdValueTip.HideTip;
begin
  FTimer.Enabled := False;
  inherited HideTip;
  ClearNodes;
  FExpr := '';
  FHotRow := -1;
end;

{ what a row shows as its value: the type of the item shown when it is open (its members are
  below it), else its value }
function ShownValue(N: TValueNode): string;
begin
  if (N.Level = 0) and N.Expanded and (N.TypeName <> '') then Result := N.TypeName else Result := N.Value;
end;

{ ... as runs (the value coloured as code): made once for the item open or closed - the rows are
  measured (Layout) and drawn (PaintContent) with them again and again }
function ValueRuns(N: TValueNode): TTipRuns;
var
  Open: Boolean;
begin
  Open := (N.Level = 0) and N.Expanded and (N.TypeName <> '');
  if not N.RunsMade or (N.RunsOpen <> Open) then
  begin
    N.Runs := nil;
    if Open then AddTipRun(N.Runs, N.TypeName, clGrayText, [], True)
    else AddCodeRuns(N.Runs, N.Value, False);
    N.RunsOpen := Open;
    N.RunsMade := True;
  end;
  Result := N.Runs;
end;

{ the rows anew (the items open), their columns, the size and the place: Place - first shown, the
  side of the line is chosen (below it where the rows fit, else above, else the side with more
  room); later the tip keeps its side and its edge at the line }
procedure TSdValueTip.Layout(Place: Boolean);

  procedure AddRows(N: TValueNode);
  var
    I: Integer;
  begin
    FRows.Add(N);
    if N.Expanded and (N.Children <> nil) then
      for I := 0 to N.Children.Count - 1 do AddRows(TValueNode(N.Children[I]));
  end;

var
  DC: HDC;
  Old: HGDIOBJ;
  I, NameRight, ValueW, Gap, Rows, Below, Above, Room, Need, W, H, Bar: Integer;
  N: TValueNode;
  WA, R: TRect;
begin
  FRows.Clear;
  if FRoot = nil then Exit;
  AddRows(TValueNode(FRoot));
  DC := TipDC;
  FGlyph := UITreeGlyphSize(DC);
  Old := SelectObject(DC, TipFont(True, []).Handle);
  try
    FRowH := Max(DCTextHeight(DC) + 2 * UIListPadY, FGlyph);
    Gap := UITextWidth(DC, '  ');
    NameRight := 0;
    for I := 0 to FRows.Count - 1 do
    begin
      N := FRows[I];
      NameRight := Max(NameRight, (N.Level + 1) * FGlyph + GlyphGap + UITextWidth(DC, N.Name));
    end;
  finally
    SelectObject(DC, Old);
  end;
  FValueX := NameRight + Gap;
  ValueW := 0;
  for I := 0 to FRows.Count - 1 do
    ValueW := Max(ValueW, RunsWidth(DC, ValueRuns(TValueNode(FRows[I]))));
  { a row - name and value - at most TipMaxChars characters wide; the values keep a quarter of
    that however deep the names go. A longer value ends in '...' }
  ValueW := Min(ValueW, Max(CodeWidth(TipMaxChars) - FValueX, CodeWidth(TipMaxChars div 4)));
  { the rows that fit beside the line, on the work area of its monitor }
  WA := UIWorkAreaAt(FLine.TopLeft);
  Below := WA.Bottom - FLine.Bottom - 2 * TipPadY - 2;
  Above := FLine.Top - WA.Top - 2 * TipPadY - 2;
  Rows := Min(FRows.Count, ValueTipMaxRows);
  if Place then
  begin
    Need := Rows * FRowH;
    if Need <= Below then FAbove := False
    else if Need <= Above then FAbove := True
    else FAbove := Above > Below;
  end;
  if FAbove then Room := Above else Room := Below;
  FPageRows := Max(1, Min(Rows, Room div FRowH));
  FTopRow := Max(0, Min(FTopRow, FRows.Count - FPageRows));
  if FRows.Count > FPageRows then Bar := GetSystemMetrics(SM_CXVSCROLL) else Bar := 0;
  W := FValueX + ValueW + 2 * TipPadX + 2 + Bar;
  W := Min(W, WA.Right - WA.Left);
  H := FPageRows * FRowH + 2 * TipPadY + 2;
  { the name of the first row under the text it is shown for }
  R.Left := FHover.Left - 1 - TipPadX - FGlyph - GlyphGap;
  if FAbove then R.Top := FLine.Top - H else R.Top := FLine.Bottom;
  R.Right := R.Left + W;
  R.Bottom := R.Top + H;
  UIFitWorkAreaAt(R, FLine.TopLeft);
  TipHandleNeeded;
  UISetScrollBar(Handle, SB_VERT, FRows.Count, FPageRows, FTopRow);
  if (FHotRow >= FRows.Count) then FHotRow := -1;
  ShowAt(R);
end;

function TSdValueTip.RowAt(Y: Integer): Integer;
begin
  Result := -1;
  if (FRowH <= 0) or (Y < TipPadY) then Exit;
  Result := (Y - TipPadY) div FRowH;
  if Result >= FPageRows then
    Result := -1
  else
  begin
    Inc(Result, FTopRow);
    if Result >= FRows.Count then Result := -1;
  end;
end;

{ the row under the pointer: the row it leaves and the one it comes to are painted again }
procedure TSdValueTip.SetHotRow(Row: Integer);
begin
  if Row = FHotRow then Exit;
  InvalidateRow(FHotRow);
  FHotRow := Row;
  InvalidateRow(FHotRow);
end;

{ a row in view to be painted again: across the whole client (the tint under the pointer is) }
procedure TSdValueTip.InvalidateRow(Row: Integer);
var
  R: TRect;
begin
  if (Row < FTopRow) or (Row >= FTopRow + FPageRows) or not HandleAllocated then Exit;
  R := Rect(0, TipPadY + (Row - FTopRow) * FRowH, ClientWidth, TipPadY + (Row - FTopRow + 1) * FRowH);
  InvalidateRect(Handle, @R, False);
end;

procedure TSdValueTip.Toggle(Row: Integer);
var
  N: TValueNode;
begin
  if (Row < 0) or (Row >= FRows.Count) then Exit;
  N := FRows[Row];
  if not N.Expandable then Exit;
  if not N.Expanded and not N.Loaded then Load(N);
  N.Expanded := N.Expandable and not N.Expanded;
  Layout(False);
end;

procedure TSdValueTip.ScrollTo(Row: Integer);
begin
  Row := Max(0, Min(Row, FRows.Count - FPageRows));
  if Row = FTopRow then Exit;
  FTopRow := Row;
  UISetScrollBar(Handle, SB_VERT, FRows.Count, FPageRows, FTopRow);
  Invalidate;
end;

procedure TSdValueTip.PaintContent(DC: HDC; const R: TRect);
var
  I, X, Y: Integer;
  N: TValueNode;
  G: TRect;
  Old: HGDIOBJ;
  T: TRect;
begin
  for I := FTopRow to Min(FRows.Count, FTopRow + FPageRows) - 1 do
  begin
    N := FRows[I];
    Y := R.Top + (I - FTopRow) * FRowH;
    { an item that opens: a tint under the pointer, as the menus' items }
    if (I = FHotRow) and N.Expandable then
      UIFill(DC, Rect(R.Left - TipPadX, Y, R.Right + TipPadX, Y + FRowH), UIBlend(clHighlight, Color, 12));
    X := R.Left + N.Level * FGlyph;
    if N.Expandable then
    begin
      G := Bounds(X, Y + (FRowH - FGlyph) div 2, FGlyph, FGlyph);
      UIDrawTreeGlyph(DC, G, N.Expanded, I = FHotRow);
    end;
    Old := SelectObject(DC, TipFont(True, []).Handle);
    T := Rect(X + FGlyph + GlyphGap, Y, R.Left + FValueX, Y + FRowH);
    UIText(DC, N.Name, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, TipVariableColor);
    SelectObject(DC, Old);
    DrawRunsCut(DC, ValueRuns(N), R.Left + FValueX, Rect(R.Left + FValueX, Y, R.Right, Y + FRowH));
  end;
end;

{ the tip takes the mouse (its rows open with a click; the scroll bar), not the activation: the
  keyboard stays in the editor }
procedure TSdValueTip.WMNCHitTest(var Message: TWMNCHitTest);
begin
  DefaultHandler(Message);
end;

procedure TSdValueTip.WMMouseActivate(var Message: TWMMouseActivate);
begin
  Message.Result := MA_NOACTIVATE;
end;

procedure TSdValueTip.WMMouseMove(var Message: TWMMouseMove);
var
  T: TTrackMouseEvent;
begin
  SetHotRow(RowAt(Message.YPos));
  T.cbSize := SizeOf(T);
  T.dwFlags := TME_LEAVE;
  T.hwndTrack := Handle;
  T.dwHoverTime := 0;
  TrackMouseEvent(T);
end;

procedure TSdValueTip.WMMouseLeave(var Message: TMessage);
begin
  SetHotRow(-1);
end;

procedure TSdValueTip.WMLButtonDown(var Message: TWMLButtonDown);
begin
  Toggle(RowAt(Message.YPos));
end;

{ a double click is two clicks: the item opens and closes again }
procedure TSdValueTip.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  Toggle(RowAt(Message.YPos));
end;

procedure TSdValueTip.WMMouseWheel(var Message: TWMMouseWheel);
var
  N: Integer;
begin
  Message.Result := 1;
  if FRows.Count <= FPageRows then Exit;
  N := UIWheelSteps(FWheel, Message.WheelDelta, ValueTipWheelRows);
  if N <> 0 then ScrollTo(FTopRow - N);
end;

procedure TSdValueTip.WMVScroll(var Message: TWMVScroll);
begin
  ScrollTo(UIScrollPos(Handle, SB_VERT, Message.ScrollCode, FTopRow, 1, FPageRows,
    FRows.Count - FPageRows));
end;

procedure TSdValueTip.WMThemeChanged(var Message: TMessage);
begin
  UICloseTreeTheme;
  inherited;
end;

{ the pointer left the tip and the text it is shown for (and what lies between them): it goes }
procedure TSdValueTip.TimerTick(Sender: TObject);
var
  P: TPoint;
  Keep: TRect;
begin
  if not TipShown then
  begin
    FTimer.Enabled := False;
    Exit;
  end;
  if not GetCursorPos(P) then Exit;
  UnionRect(Keep, FHover, BoundsRect);
  if not PtInRect(Keep, P) then HideTip;
end;

function TSdValueTip.DebugText: string;
var
  I: Integer;
  N: TValueNode;
  G: Char;
begin
  Result := '';
  if not TipShown then Exit;
  Result := Format('%d,%d,%d,%d,%d,%d,%d|', [FRows.Count, FTopRow, FPageRows, FRowH, FGlyph, FValueX,
    Ord(FAbove)]);
  for I := 0 to FRows.Count - 1 do
  begin
    N := FRows[I];
    if not N.Expandable then G := ' '
    else if N.Expanded then G := '-'
    else G := '+';
    Result := Result + IntToStr(N.Level) + G + N.Name + '=' + ShownValue(N) + '|';
  end;
end;

procedure FreeTipFonts;
var
  C, B, I: Boolean;
begin
  for C := False to True do
    for B := False to True do
      for I := False to True do
        FreeAndNil(TipFonts[C, B, I]);
end;

initialization

finalization
  FreeTipFonts;
  if MeasureDC <> 0 then DeleteDC(MeasureDC);
  MeasureDC := 0;

end.
