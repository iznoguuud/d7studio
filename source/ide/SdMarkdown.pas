{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMarkdown;

{ D7 Studio - Markdown read into a rich text document (SdRichDoc). CommonMark's blocks - ATX and
  setext headings, paragraphs, block quotes, bullet and numbered lists (tight or loose), fenced and
  indented code, thematic breaks, HTML blocks (kept as literal markup; comments left out), link
  reference definitions - and inlines - emphasis and strong emphasis by CommonMark's delimiter
  rules, code spans, links and images (inline, full, collapsed and shortcut references), autolinks,
  backslash escapes, entities, hard and soft line breaks - with GitHub's tables, task list items,
  strikethrough and bare links (http://, https://, www.); a YAML front matter becomes code. Inline
  HTML stays text but for <br>. Tabs are blanks to the next multiple of 4. }

interface

uses
  SdRichDoc;

{ Text read as Markdown: a new document, which the caller frees }
function ParseMarkdown(const Text: WideString): TSdRichDoc;
{ Markdown as plain text (TSdRichDoc.PlainText) }
function MarkdownToPlainText(const Text: WideString): WideString;

implementation

uses
  Windows, SysUtils, Classes;

type
  TWLines = array of WideString;
  TLineNums = array of Integer;

{ ---------------------------------------------------------------- characters }

function IsSpaceW(C: WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13) or (C = #12) or (C = #11);
end;

function IsDigitW(C: WideChar): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

function IsAsciiLetter(C: WideChar): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z'));
end;

function IsAsciiPunct(C: WideChar): Boolean;
begin
  Result := (Ord(C) < 128) and (Pos(Char(Ord(C)), '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~') > 0);
end;

{ punctuation for the delimiter rules: ASCII's, and beyond it what is neither a letter, a digit nor
  a blank }
function IsPunctW(C: WideChar): Boolean;
begin
  if Ord(C) < 128 then Result := IsAsciiPunct(C)
  else Result := not IsCharAlphaNumericW(C) and not IsSpaceW(C) and (C <> #$00A0);
end;

function LeadSpaces(const S: WideString): Integer;
begin
  Result := 0;
  while (Result < Length(S)) and (S[Result + 1] = ' ') do Inc(Result);
end;

function IsBlank(const S: WideString): Boolean;
begin
  Result := LeadSpaces(S) = Length(S);
end;

{ S without up to N blanks at its start }
function StripSpaces(const S: WideString; N: Integer): WideString;
var
  K: Integer;
begin
  K := LeadSpaces(S);
  if K > N then K := N;
  Result := Copy(S, K + 1, MaxInt);
end;

function StartsWithW(const S, Prefix: WideString): Boolean;
begin
  Result := Copy(S, 1, Length(Prefix)) = Prefix;
end;

function StartsWithTextW(const S, Prefix: WideString): Boolean;
begin
  Result := WideLowerCase(Copy(S, 1, Length(Prefix))) = Prefix;
end;

{ the ASCII letters, digits and signs of S; what else it has left out (a language's name) }
function AsciiOf(const S: WideString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if (Ord(S[I]) > 32) and (Ord(S[I]) < 127) then Result := Result + Char(Ord(S[I]));
end;

{ a line with its tabs as blanks to the next multiple of 4 }
function ExpandTabs(const S: WideString): WideString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] = #9 then
      repeat
        Result := Result + ' ';
      until Length(Result) mod 4 = 0
    else
      Result := Result + S[I];
end;

{ the lines of Text, tabs as blanks to the next multiple of 4 }
function SplitLines(const Text: WideString): TWLines;
var
  I, N, Start, Len: Integer;
  Tabs: Boolean;

  procedure Push(EndAt: Integer);
  begin
    if N = Length(Result) then SetLength(Result, 2 * N + 64);
    Result[N] := Copy(Text, Start, EndAt - Start);
    if Tabs then Result[N] := ExpandTabs(Result[N]);
    Inc(N);
    Tabs := False;
  end;

begin
  Result := nil;
  N := 0;
  Len := Length(Text);
  Start := 1;
  Tabs := False;
  I := 1;
  while I <= Len do
  begin
    case Text[I] of
      #13:
        begin
          Push(I);
          if (I < Len) and (Text[I + 1] = #10) then Inc(I);
          Start := I + 1;
        end;
      #10:
        begin
          Push(I);
          Start := I + 1;
        end;
      #9: Tabs := True;
    end;
    Inc(I);
  end;
  if Start <= Len then Push(Len + 1);
  SetLength(Result, N);
end;
procedure AddLine(var L: TWLines; const S: WideString);
begin
  SetLength(L, Length(L) + 1);
  L[High(L)] := S;
end;

procedure AddNum(var A: TLineNums; V: Integer);
begin
  SetLength(A, Length(A) + 1);
  A[High(A)] := V;
end;

function JoinLines(const L: TWLines): WideString;
var
  I, N, P: Integer;
begin
  N := 0;
  for I := 0 to High(L) do Inc(N, Length(L[I]) + 1);
  if N = 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Result, N - 1);
  P := 1;
  for I := 0 to High(L) do
  begin
    if I > 0 then
    begin
      Result[P] := #10;
      Inc(P);
    end;
    if L[I] <> '' then Move(PWideChar(L[I])^, Result[P], Length(L[I]) * SizeOf(WideChar));
    Inc(P, Length(L[I]));
  end;
end;

{ ---------------------------------------------------------------- entities }

const
  Entities: array[0..33] of record Name: string; Code: Word end = (
    (Name: 'amp'; Code: 38), (Name: 'lt'; Code: 60), (Name: 'gt'; Code: 62), (Name: 'quot'; Code: 34),
    (Name: 'apos'; Code: 39), (Name: 'nbsp'; Code: 160), (Name: 'copy'; Code: 169), (Name: 'reg'; Code: 174),
    (Name: 'trade'; Code: 8482), (Name: 'hellip'; Code: 8230), (Name: 'mdash'; Code: 8212),
    (Name: 'ndash'; Code: 8211), (Name: 'laquo'; Code: 171), (Name: 'raquo'; Code: 187),
    (Name: 'lsquo'; Code: 8216), (Name: 'rsquo'; Code: 8217), (Name: 'ldquo'; Code: 8220),
    (Name: 'rdquo'; Code: 8221), (Name: 'bull'; Code: 8226), (Name: 'middot'; Code: 183),
    (Name: 'deg'; Code: 176), (Name: 'times'; Code: 215), (Name: 'divide'; Code: 247),
    (Name: 'plusmn'; Code: 177), (Name: 'larr'; Code: 8592), (Name: 'rarr'; Code: 8594),
    (Name: 'uarr'; Code: 8593), (Name: 'darr'; Code: 8595), (Name: 'harr'; Code: 8596),
    (Name: 'euro'; Code: 8364), (Name: 'pound'; Code: 163), (Name: 'sect'; Code: 167),
    (Name: 'para'; Code: 182), (Name: 'check'; Code: 10003));

{ an entity at S[P] ('&'): its character and the position after its ';'; False: none }
function ReadEntity(const S: WideString; P: Integer; out Ch: WideString; out After: Integer): Boolean;
var
  Q, V, I, Digits: Integer;
  Hex: Boolean;
  Name: string;
begin
  Result := False;
  Q := P + 1;
  if (Q <= Length(S)) and (S[Q] = '#') then
  begin
    Inc(Q);
    Hex := (Q <= Length(S)) and ((S[Q] = 'x') or (S[Q] = 'X'));
    if Hex then Inc(Q);
    V := 0;
    Digits := 0;
    while (Q <= Length(S)) and (Digits < 7) do
    begin
      if IsDigitW(S[Q]) then V := V * (10 + 6 * Ord(Hex)) + Ord(S[Q]) - Ord('0')
      else if Hex and (HexDigitValue(S[Q]) >= 0) then V := V * 16 + HexDigitValue(S[Q])
      else Break;
      Inc(Digits);
      Inc(Q);
    end;
    if (Digits = 0) or (Q > Length(S)) or (S[Q] <> ';') then Exit;
    if (V = 0) or (V > $10FFFF) or ((V >= $D800) and (V <= $DFFF)) then V := $FFFD;
    if V > $FFFF then
    begin
      Dec(V, $10000);
      SetLength(Ch, 2);
      Ch[1] := WideChar($D800 + V shr 10);
      Ch[2] := WideChar($DC00 + V and $3FF);
    end
    else
      Ch := WideChar(V);
    After := Q + 1;
    Result := True;
    Exit;
  end;
  Name := '';
  while (Q <= Length(S)) and (IsAsciiLetter(S[Q]) or IsDigitW(S[Q])) and (Length(Name) < 32) do
  begin
    Name := Name + Char(Ord(S[Q]));
    Inc(Q);
  end;
  if (Name = '') or (Q > Length(S)) or (S[Q] <> ';') then Exit;
  for I := Low(Entities) to High(Entities) do
    if Entities[I].Name = Name then
    begin
      Ch := WideChar(Entities[I].Code);
      After := Q + 1;
      Result := True;
      Exit;
    end;
end;

{ S with its backslash escapes and entities as the characters they stand for (link targets,
  titles, a code block's language) }
function Unescape(const S: WideString): WideString;
var
  P, After: Integer;
  Ch: WideString;
begin
  Result := '';
  P := 1;
  while P <= Length(S) do
  begin
    if (S[P] = '\') and (P < Length(S)) and IsAsciiPunct(S[P + 1]) then
    begin
      Result := Result + S[P + 1];
      Inc(P, 2);
    end
    else if (S[P] = '&') and ReadEntity(S, P, Ch, After) then
    begin
      Result := Result + Ch;
      P := After;
    end
    else
    begin
      Result := Result + S[P];
      Inc(P);
    end;
  end;
end;

{ a reference's label as references are matched: lower case, its blanks one, none at its ends }
function NormLabel(const S: WideString): string;
var
  I: Integer;
  W: WideString;
  Blank: Boolean;
begin
  W := '';
  Blank := False;
  for I := 1 to Length(S) do
    if IsSpaceW(S[I]) then Blank := True
    else
    begin
      if Blank and (W <> '') then W := W + ' ';
      Blank := False;
      W := W + S[I];
    end;
  Result := UTF8Encode(WideLowerCase(W));
end;

{ ---------------------------------------------------------------- inlines }

type
  TInlKind = (ikText, ikCode, ikEmph, ikStrong, ikStrike, ikLink, ikImage, ikBreak, ikDelim, ikBracket);

  { a node of a paragraph's inlines while they are read: text, a code span, a break, emphasis or a
    link with the nodes inside it, and while it is unmatched a run of delimiters or a bracket }
  TInl = class
  public
    Kind: TInlKind;
    Text: WideString;
    Url: WideString;
    Children: TList;
    DChar: WideChar;            // a delimiter run's character: '*', '_', '~'
    DCount, DOrig: Integer;     // ... its characters left, at first
    CanOpen, CanClose: Boolean;
    IsImage, Active: Boolean;   // a bracket: '![', still able to make a link
    SrcPos: Integer;            // ... the position after it in the paragraph's text
    constructor Create(AKind: TInlKind);
    destructor Destroy; override;
  end;

constructor TInl.Create(AKind: TInlKind);
begin
  inherited Create;
  Kind := AKind;
  Children := TList.Create;
end;

destructor TInl.Destroy;
var
  I: Integer;
begin
  for I := 0 to Children.Count - 1 do TInl(Children[I]).Free;
  Children.Free;
  inherited Destroy;
end;

{ an unmatched delimiter run or bracket as the text it is }
procedure MakeText(N: TInl);
var
  I: Integer;
begin
  if N.Kind = ikDelim then
  begin
    N.Text := '';
    for I := 1 to N.DCount do N.Text := N.Text + N.DChar;
  end;
  N.Kind := ikText;
end;

{ CommonMark's process emphasis over the nodes after Bottom: each closer with its nearest opener
  of the same character - the rule of 3 for '*' and '_', equal runs for '~' -, what lies between
  them inside the emphasis made; the delimiters left over become text }
procedure ProcessEmphasis(Nodes: TList; Bottom: Integer);
var
  C, O, J, Use: Integer;
  Cl, Op, E: TInl;
  Found: Boolean;
  K: TInlKind;
begin
  C := Bottom + 1;
  while C < Nodes.Count do
  begin
    Cl := TInl(Nodes[C]);
    if (Cl.Kind <> ikDelim) or not Cl.CanClose then
    begin
      Inc(C);
      Continue;
    end;
    Found := False;
    O := C - 1;
    Op := nil;
    while O > Bottom do
    begin
      Op := TInl(Nodes[O]);
      if (Op.Kind = ikDelim) and Op.CanOpen and (Op.DChar = Cl.DChar) then
      begin
        if Cl.DChar = '~' then Found := Op.DCount = Cl.DCount
        else Found := not ((Op.CanClose or Cl.CanOpen) and ((Op.DOrig + Cl.DOrig) mod 3 = 0) and
          not ((Op.DOrig mod 3 = 0) and (Cl.DOrig mod 3 = 0)));
        if Found then Break;
      end;
      Dec(O);
    end;
    if not Found then
    begin
      if not Cl.CanOpen then MakeText(Cl);
      Inc(C);
      Continue;
    end;
    if Cl.DChar = '~' then
    begin
      Use := Cl.DCount;
      K := ikStrike;
    end
    else if (Op.DCount >= 2) and (Cl.DCount >= 2) then
    begin
      Use := 2;
      K := ikStrong;
    end
    else
    begin
      Use := 1;
      K := ikEmph;
    end;
    E := TInl.Create(K);
    for J := O + 1 to C - 1 do
    begin
      if TInl(Nodes[J]).Kind = ikDelim then MakeText(TInl(Nodes[J]));
      E.Children.Add(Nodes[J]);
    end;
    for J := C - 1 downto O + 1 do Nodes.Delete(J);
    Nodes.Insert(O + 1, E);
    Dec(Op.DCount, Use);
    Dec(Cl.DCount, Use);
    C := O + 2;
    if Op.DCount = 0 then
    begin
      Nodes.Delete(O);
      Op.Free;
      Dec(C);
    end;
    if Cl.DCount = 0 then
    begin
      Nodes.Delete(C);
      Cl.Free;
    end;
  end;
  for J := Bottom + 1 to Nodes.Count - 1 do
    if TInl(Nodes[J]).Kind = ikDelim then MakeText(TInl(Nodes[J]));
end;

type
  TMdParser = class
  private
    FDoc: TSdRichDoc;
    FRefs: TStringList;             // the link reference definitions' labels (NormLabel) ...
    FRefUrls: array of WideString;  // ... and their targets, by the list's objects
    function FindRef(const LabelText: WideString; out Url: WideString): Boolean;
    function TryRefDef(const T: WideString): Boolean;
    procedure ParseBlocks(const L: TWLines; const Nums: TLineNums; Parent: TSdBlock);
    procedure ParseInlines(const S: WideString; Nodes: TList);
    procedure Flatten(Nodes: TList; B: TSdBlock; Styles: TSdRunStyles; Link: Integer);
    procedure InlineAll(B: TSdBlock);
  public
    constructor Create(ADoc: TSdRichDoc);
    destructor Destroy; override;
  end;

constructor TMdParser.Create(ADoc: TSdRichDoc);
begin
  inherited Create;
  FDoc := ADoc;
  FRefs := TStringList.Create;
end;

destructor TMdParser.Destroy;
begin
  FRefs.Free;
  inherited Destroy;
end;

function TMdParser.FindRef(const LabelText: WideString; out Url: WideString): Boolean;
var
  I: Integer;
begin
  I := FRefs.IndexOf(NormLabel(LabelText));
  Result := (I >= 0) and (Trim(LabelText) <> '');
  if Result then Url := FRefUrls[Integer(FRefs.Objects[I])];
end;

{ a link destination at S[Q] - <...> or text without blanks whose parentheses pair -, Q after it;
  False: none }
function ReadDestination(const S: WideString; var Q: Integer; out Dest: WideString): Boolean;
var
  Depth, Start: Integer;
begin
  Result := False;
  Dest := '';
  if (Q <= Length(S)) and (S[Q] = '<') then
  begin
    Start := Q + 1;
    Inc(Q);
    while (Q <= Length(S)) and (S[Q] <> '>') and (S[Q] <> '<') and (S[Q] <> #10) do
    begin
      if (S[Q] = '\') and (Q < Length(S)) then Inc(Q);
      Inc(Q);
    end;
    if (Q > Length(S)) or (S[Q] <> '>') then Exit;
    Dest := Unescape(Copy(S, Start, Q - Start));
    Inc(Q);
    Result := True;
    Exit;
  end;
  Start := Q;
  Depth := 0;
  while (Q <= Length(S)) and not IsSpaceW(S[Q]) and (Ord(S[Q]) >= 32) do
  begin
    if (S[Q] = '\') and (Q < Length(S)) and IsAsciiPunct(S[Q + 1]) then Inc(Q)
    else if S[Q] = '(' then Inc(Depth)
    else if S[Q] = ')' then
    begin
      if Depth = 0 then Break;
      Dec(Depth);
    end;
    Inc(Q);
  end;
  if Depth <> 0 then Exit;
  Dest := Unescape(Copy(S, Start, Q - Start));
  Result := True;
end;

{ a link title at S[Q] - "...", '...' or (...) -, Q after it; False: none }
function ReadTitle(const S: WideString; var Q: Integer): Boolean;
var
  Close: WideChar;
begin
  Result := False;
  if Q > Length(S) then Exit;
  if S[Q] = '"' then Close := '"'
  else if S[Q] = '''' then Close := ''''
  else if S[Q] = '(' then Close := ')'
  else Exit;
  Inc(Q);
  while (Q <= Length(S)) and (S[Q] <> Close) do
  begin
    if (S[Q] = '\') and (Q < Length(S)) then Inc(Q);
    Inc(Q);
  end;
  if Q > Length(S) then Exit;
  Inc(Q);
  Result := True;
end;

procedure SkipBlanks(const S: WideString; var Q: Integer);
begin
  while (Q <= Length(S)) and IsSpaceW(S[Q]) do Inc(Q);
end;

{ an inline link's parentheses at S[Q] ('('): the target, Q after ')'; False: none }
function TryInlineLink(const S: WideString; var Q: Integer; out Url: WideString): Boolean;
var
  R: Integer;
begin
  Result := False;
  if (Q > Length(S)) or (S[Q] <> '(') then Exit;
  R := Q + 1;
  SkipBlanks(S, R);
  Url := '';
  if (R <= Length(S)) and (S[R] <> ')') then
  begin
    if not ReadDestination(S, R, Url) then Exit;
    SkipBlanks(S, R);
    if (R <= Length(S)) and (S[R] <> ')') then
    begin
      if not ReadTitle(S, R) then Exit;
      SkipBlanks(S, R);
    end;
  end;
  if (R > Length(S)) or (S[R] <> ')') then Exit;
  Q := R + 1;
  Result := True;
end;

{ a link reference definition: [label]: target "title"; True when T is one (it is kept) }
function TMdParser.TryRefDef(const T: WideString): Boolean;
var
  Q, Start, N: Integer;
  LabelText, Url: WideString;
  Key: string;
begin
  Result := False;
  if (T = '') or (T[1] <> '[') then Exit;
  Q := 2;
  Start := Q;
  while (Q <= Length(T)) and (T[Q] <> ']') do
  begin
    if T[Q] = '[' then Exit;
    if (T[Q] = '\') and (Q < Length(T)) then Inc(Q);
    Inc(Q);
  end;
  if (Q >= Length(T)) or (T[Q + 1] <> ':') then Exit;
  LabelText := Copy(T, Start, Q - Start);
  if Trim(LabelText) = '' then Exit;
  Inc(Q, 2);
  SkipBlanks(T, Q);
  if Q > Length(T) then Exit;
  if not ReadDestination(T, Q, Url) then Exit;
  SkipBlanks(T, Q);
  if Q <= Length(T) then
  begin
    if not ReadTitle(T, Q) then Exit;
    SkipBlanks(T, Q);
    if Q <= Length(T) then Exit;
  end;
  Result := True;
  { the first definition of a label counts }
  Key := NormLabel(LabelText);
  if FRefs.IndexOf(Key) >= 0 then Exit;
  N := Length(FRefUrls);
  SetLength(FRefUrls, N + 1);
  FRefUrls[N] := Url;
  FRefs.AddObject(Key, TObject(N));
end;

{ a character an inline may begin with (a bare link's first letter too) }
function IsInlineMark(C: WideChar): Boolean;
begin
  case C of
    '\', '`', '*', '_', '~', '!', '[', ']', '<', '&', #10, 'h', 'H', 'w', 'W': Result := True;
  else
    Result := False;
  end;
end;

procedure TMdParser.ParseInlines(const S: WideString; Nodes: TList);
var
  P, Q, N, Len, After, I, Depth: Integer;
  Buf, Ch, Url, LabelText, Code: WideString;
  C, Before, Next: WideChar;
  Openers: TList;
  Node, O: TInl;
  Matched, Left, Right: Boolean;

  procedure FlushText;
  var
    T: TInl;
  begin
    if Buf = '' then Exit;
    T := TInl.Create(ikText);
    T.Text := Buf;
    Nodes.Add(T);
    Buf := '';
  end;

  procedure AddNode(Kind: TInlKind; const Text: WideString);
  var
    T: TInl;
  begin
    FlushText;
    T := TInl.Create(Kind);
    T.Text := Text;
    Nodes.Add(T);
  end;

  procedure AddLinkNode(const Text, Target: WideString);
  var
    T, X: TInl;
  begin
    FlushText;
    T := TInl.Create(ikLink);
    T.Url := Target;
    X := TInl.Create(ikText);
    X.Text := Text;
    T.Children.Add(X);
    Nodes.Add(T);
  end;

  { the blanks at the end of the text so far (before a line break) }
  procedure TrimBufRight;
  begin
    while (Buf <> '') and (Buf[Length(Buf)] = ' ') do SetLength(Buf, Length(Buf) - 1);
  end;

  { a bare link of GitHub's at P (http://, https://, www.): its end; 0 when none }
  function BareLinkEnd: Integer;
  var
    E, Opens, Closes, K, Prefix, J: Integer;
  begin
    Result := 0;
    if (P > 1) and not IsSpaceW(S[P - 1]) and (S[P - 1] <> '*') and (S[P - 1] <> '_') and
      (S[P - 1] <> '~') and (S[P - 1] <> '(') then Exit;
    if StartsWithTextW(Copy(S, P, 8), 'https://') then Prefix := 8
    else if StartsWithTextW(Copy(S, P, 7), 'http://') then Prefix := 7
    else if StartsWithTextW(Copy(S, P, 4), 'www.') then Prefix := 4
    else Exit;
    E := P + Prefix;
    while (E <= Length(S)) and not IsSpaceW(S[E]) and (S[E] <> '<') do Inc(E);
    { trailing punctuation is not part of it, nor a closing parenthesis that has no opening one }
    repeat
      K := E;
      while (E > P) and (Pos(Char(Ord(S[E - 1]) and $FF), '?!.,:*_~''"') > 0) and (Ord(S[E - 1]) < 128) do Dec(E);
      if (E > P) and (S[E - 1] = ')') then
      begin
        Opens := 0;
        Closes := 0;
        for J := P to E - 1 do
          if S[J] = '(' then Inc(Opens) else if S[J] = ')' then Inc(Closes);
        if Closes > Opens then Dec(E);
      end;
    until E = K;
    { a host after the prefix }
    if E - P <= Prefix + 1 then Exit;
    Result := E;
  end;

begin
  Openers := TList.Create;
  try
    Buf := '';
    Len := Length(S);
    P := 1;
    while P <= Len do
    begin
      C := S[P];
      case C of
        '\':
          if (P < Len) and (S[P + 1] = #10) then
          begin
            AddNode(ikBreak, '');
            Inc(P, 2);
            while (P <= Len) and (S[P] = ' ') do Inc(P);
          end
          else if (P < Len) and IsAsciiPunct(S[P + 1]) then
          begin
            Buf := Buf + S[P + 1];
            Inc(P, 2);
          end
          else
          begin
            Buf := Buf + C;
            Inc(P);
          end;
        '`':
          begin
            N := 0;
            while (P + N <= Len) and (S[P + N] = '`') do Inc(N);
            { the closing run of exactly N backticks }
            Q := P + N;
            Matched := False;
            while Q <= Len do
            begin
              if S[Q] = '`' then
              begin
                I := 0;
                while (Q + I <= Len) and (S[Q + I] = '`') do Inc(I);
                if I = N then
                begin
                  Matched := True;
                  Break;
                end;
                Inc(Q, I);
              end
              else
                Inc(Q);
            end;
            if Matched then
            begin
              Code := Copy(S, P + N, Q - P - N);
              for I := 1 to Length(Code) do
                if Code[I] = #10 then Code[I] := ' ';
              if (Length(Code) >= 2) and (Code[1] = ' ') and (Code[Length(Code)] = ' ') and not IsBlank(Code) then
                Code := Copy(Code, 2, Length(Code) - 2);
              AddNode(ikCode, Code);
              P := Q + N;
            end
            else
            begin
              Buf := Buf + Copy(S, P, N);
              Inc(P, N);
            end;
          end;
        '*', '_', '~':
          begin
            N := 0;
            while (P + N <= Len) and (S[P + N] = C) do Inc(N);
            if (C = '~') and (N > 2) then
            begin
              Buf := Buf + Copy(S, P, N);
              Inc(P, N);
              Continue;
            end;
            if P > 1 then Before := S[P - 1] else Before := ' ';
            if P + N <= Len then Next := S[P + N] else Next := ' ';
            Left := not IsSpaceW(Next) and (not IsPunctW(Next) or IsSpaceW(Before) or IsPunctW(Before));
            Right := not IsSpaceW(Before) and (not IsPunctW(Before) or IsSpaceW(Next) or IsPunctW(Next));
            FlushText;
            Node := TInl.Create(ikDelim);
            Node.DChar := C;
            Node.DCount := N;
            Node.DOrig := N;
            if C = '_' then
            begin
              Node.CanOpen := Left and (not Right or IsPunctW(Before));
              Node.CanClose := Right and (not Left or IsPunctW(Next));
            end
            else
            begin
              Node.CanOpen := Left;
              Node.CanClose := Right;
            end;
            Nodes.Add(Node);
            Inc(P, N);
          end;
        '!', '[':
          if (C = '!') and ((P = Len) or (S[P + 1] <> '[')) then
          begin
            Buf := Buf + C;
            Inc(P);
          end
          else
          begin
            FlushText;
            Node := TInl.Create(ikBracket);
            Node.IsImage := C = '!';
            if Node.IsImage then Node.Text := '![' else Node.Text := '[';
            Node.Active := True;
            Inc(P, Length(Node.Text));
            Node.SrcPos := P;
            Nodes.Add(Node);
            Openers.Add(Node);
          end;
        ']':
          begin
            FlushText;
            if Openers.Count = 0 then
            begin
              Buf := Buf + ']';
              Inc(P);
              Continue;
            end;
            O := TInl(Openers[Openers.Count - 1]);
            if not O.Active then
            begin
              Openers.Delete(Openers.Count - 1);
              Buf := Buf + ']';
              Inc(P);
              Continue;
            end;
            Q := P + 1;
            Matched := TryInlineLink(S, Q, Url);
            if not Matched then
            begin
              { a reference: [text][label], [text][] or [text] }
              Q := P + 1;
              LabelText := Copy(S, O.SrcPos, P - O.SrcPos);
              if (Q <= Len) and (S[Q] = '[') then
              begin
                I := Q + 1;
                Depth := 0;
                while (I <= Len) and (S[I] <> ']') and (S[I] <> '[') do
                begin
                  if (S[I] = '\') and (I < Len) then Inc(I);
                  Inc(I);
                  Inc(Depth);
                end;
                if (I <= Len) and (S[I] = ']') then
                begin
                  if Depth > 0 then LabelText := Copy(S, Q + 1, I - Q - 1);
                  Q := I + 1;
                end;
              end;
              Matched := FindRef(LabelText, Url);
            end;
            Openers.Delete(Openers.Count - 1);
            if not Matched then
            begin
              Buf := Buf + ']';
              Inc(P);
              Continue;
            end;
            I := Nodes.IndexOf(O);
            ProcessEmphasis(Nodes, I);
            if O.IsImage then Node := TInl.Create(ikImage) else Node := TInl.Create(ikLink);
            Node.Url := Url;
            for N := I + 1 to Nodes.Count - 1 do Node.Children.Add(Nodes[N]);
            Nodes.Count := I;
            O.Free;
            Nodes.Add(Node);
            { no link inside a link: the brackets before it make none any more }
            if Node.Kind = ikLink then
              for N := 0 to Openers.Count - 1 do
                if not TInl(Openers[N]).IsImage then TInl(Openers[N]).Active := False;
            P := Q;
          end;
        '<':
          begin
            { an autolink <scheme:...> or <address@domain>; <br> a break; other markup is text }
            Q := P + 1;
            while (Q <= Len) and (S[Q] <> '>') and (S[Q] <> '<') and not IsSpaceW(S[Q]) do Inc(Q);
            Url := Copy(S, P + 1, Q - P - 1);
            if (Q <= Len) and (S[Q] = '>') and (Pos(':', Url) > 2) and IsAsciiLetter(Url[1]) then
            begin
              AddLinkNode(Url, Url);
              P := Q + 1;
            end
            else if (Q <= Len) and (S[Q] = '>') and (Pos('@', Url) > 1) and (Pos('.', Url) > Pos('@', Url)) then
            begin
              AddLinkNode(Url, 'mailto:' + Url);
              P := Q + 1;
            end
            else if StartsWithTextW(Copy(S, P, 3), '<br') and
              ((P + 3 <= Len) and ((S[P + 3] = '>') or (S[P + 3] = '/') or (S[P + 3] = ' '))) and
              (Pos('>', Copy(S, P, 8)) > 0) then
            begin
              AddNode(ikBreak, '');
              P := P + Pos('>', Copy(S, P, 8));
            end
            else
            begin
              Buf := Buf + C;
              Inc(P);
            end;
          end;
        '&':
          if ReadEntity(S, P, Ch, After) then
          begin
            Buf := Buf + Ch;
            P := After;
          end
          else
          begin
            Buf := Buf + C;
            Inc(P);
          end;
        #10:
          begin
            { two blanks or more before it: a hard break; else a soft one, a blank }
            if (Length(Buf) >= 2) and (Buf[Length(Buf)] = ' ') and (Buf[Length(Buf) - 1] = ' ') then
            begin
              TrimBufRight;
              AddNode(ikBreak, '');
            end
            else
            begin
              TrimBufRight;
              Buf := Buf + ' ';
            end;
            Inc(P);
            while (P <= Len) and (S[P] = ' ') do Inc(P);
          end;
      else
        After := 0;
        if (C = 'h') or (C = 'H') or (C = 'w') or (C = 'W') then After := BareLinkEnd;
        if After > 0 then
        begin
          Url := Copy(S, P, After - P);
          if StartsWithTextW(Url, 'www.') then AddLinkNode(Url, 'http://' + Url)
          else AddLinkNode(Url, Url);
          P := After;
        end
        else if (C = 'h') or (C = 'H') or (C = 'w') or (C = 'W') then
        begin
          Buf := Buf + C;
          Inc(P);
        end
        else
        begin
          { a run of characters that begin nothing, taken at once }
          Q := P + 1;
          while (Q <= Len) and not IsInlineMark(S[Q]) do Inc(Q);
          Buf := Buf + Copy(S, P, Q - P);
          P := Q;
        end;
      end;
    end;
    FlushText;
    ProcessEmphasis(Nodes, -1);
  finally
    Openers.Free;
  end;
end;

{ the text of nodes without their styles (an image's alternative text) }
function NodesText(Nodes: TList): WideString;
var
  I: Integer;
  N: TInl;
begin
  Result := '';
  for I := 0 to Nodes.Count - 1 do
  begin
    N := TInl(Nodes[I]);
    case N.Kind of
      ikBreak: Result := Result + ' ';
      ikEmph, ikStrong, ikStrike, ikLink, ikImage: Result := Result + NodesText(N.Children);
    else
      Result := Result + N.Text;
    end;
  end;
end;

procedure TMdParser.Flatten(Nodes: TList; B: TSdBlock; Styles: TSdRunStyles; Link: Integer);
var
  I: Integer;
  N: TInl;
begin
  for I := 0 to Nodes.Count - 1 do
  begin
    N := TInl(Nodes[I]);
    case N.Kind of
      ikText, ikDelim, ikBracket: B.AddRun(N.Text, Styles, Link);
      ikCode: B.AddRun(N.Text, Styles + [rsCode], Link);
      ikEmph: Flatten(N.Children, B, Styles + [rsItalic], Link);
      ikStrong: Flatten(N.Children, B, Styles + [rsBold], Link);
      ikStrike: Flatten(N.Children, B, Styles + [rsStrike], Link);
      ikLink: Flatten(N.Children, B, Styles, FDoc.AddLink(N.Url));
      ikImage: B.AddRun(NodesText(N.Children), Styles, Link, FDoc.AddImage(N.Url));
      ikBreak: B.AddBreak;
    end;
  end;
end;

{ the raw text the blocks kept (Text) read as inlines into their runs }
procedure TMdParser.InlineAll(B: TSdBlock);
var
  I: Integer;
  Nodes: TList;
begin
  if B.Kind in [bkParagraph, bkHeading, bkCell] then
  begin
    Nodes := TList.Create;
    try
      ParseInlines(B.Text, Nodes);
      Flatten(Nodes, B, [], -1);
    finally
      for I := 0 to Nodes.Count - 1 do TInl(Nodes[I]).Free;
      Nodes.Free;
    end;
    B.Text := '';
  end;
  for I := 0 to B.Count - 1 do InlineAll(B[I]);
end;

{ ---------------------------------------------------------------- blocks }

{ an opening code fence (T without its indentation): its character, length and info string }
function IsFence(const T: WideString; out Ch: WideChar; out Len: Integer; out Info: WideString): Boolean;
begin
  Result := False;
  if (T = '') or ((T[1] <> '`') and (T[1] <> '~')) then Exit;
  Ch := T[1];
  Len := 0;
  while (Len < Length(T)) and (T[Len + 1] = Ch) do Inc(Len);
  if Len < 3 then Exit;
  Info := Trim(Copy(T, Len + 1, MaxInt));
  if (Ch = '`') and (Pos('`', Info) > 0) then Exit;
  Result := True;
end;

function IsClosingFence(const T: WideString; Ch: WideChar; Len: Integer): Boolean;
var
  N: Integer;
begin
  N := 0;
  while (N < Length(T)) and (T[N + 1] = Ch) do Inc(N);
  Result := (N >= Len) and IsBlank(Copy(T, N + 1, MaxInt));
end;

{ an ATX heading's level (0: none) and its text }
function AtxLevel(const T: WideString; out Content: WideString): Integer;
var
  N, E: Integer;
begin
  Result := 0;
  N := 0;
  while (N < Length(T)) and (T[N + 1] = '#') do Inc(N);
  if (N = 0) or (N > 6) or ((N < Length(T)) and (T[N + 1] <> ' ')) then Exit;
  Result := N;
  Content := Trim(Copy(T, N + 1, MaxInt));
  { a closing sequence of '#' after a blank, or the whole text }
  E := Length(Content);
  while (E > 0) and (Content[E] = '#') do Dec(E);
  if E = 0 then Content := ''
  else if (E < Length(Content)) and (Content[E] = ' ') then Content := TrimRight(Copy(Content, 1, E));
end;

function IsRule(const T: WideString): Boolean;
var
  I, N: Integer;
  Ch: WideChar;
begin
  Result := False;
  if T = '' then Exit;
  Ch := T[1];
  if (Ch <> '-') and (Ch <> '*') and (Ch <> '_') then Exit;
  N := 0;
  for I := 1 to Length(T) do
    if T[I] = Ch then Inc(N)
    else if T[I] <> ' ' then Exit;
  Result := N >= 3;
end;

{ a setext underline: 1 for '=', 2 for '-', 0 none }
function SetextLevel(const T: WideString): Integer;
var
  Body: WideString;
  I: Integer;
begin
  Result := 0;
  Body := TrimRight(T);
  if Body = '' then Exit;
  for I := 1 to Length(Body) do
    if Body[I] <> Body[1] then Exit;
  if Body[1] = '=' then Result := 1
  else if Body[1] = '-' then Result := 2;
end;

{ a list item's marker on line S: bullet or number, the number, where its content begins (the
  columns a line of the item is indented by) and whether the item is empty on this line }
function ListMarker(const S: WideString; out Ordered: Boolean; out Mark: WideChar; out Num: Integer;
  out ContentCol: Integer; out Empty: Boolean): Boolean;
var
  Ind, P, Q, Digits, Sp: Integer;
begin
  Result := False;
  Ind := LeadSpaces(S);
  if Ind > 3 then Exit;
  P := Ind + 1;
  if P > Length(S) then Exit;
  Num := 1;
  if (S[P] = '-') or (S[P] = '+') or (S[P] = '*') then
  begin
    Ordered := False;
    Mark := S[P];
    Q := P + 1;
  end
  else
  begin
    Digits := 0;
    Num := 0;
    Q := P;
    while (Q <= Length(S)) and IsDigitW(S[Q]) and (Digits < 9) do
    begin
      Num := Num * 10 + Ord(S[Q]) - Ord('0');
      Inc(Q);
      Inc(Digits);
    end;
    if (Digits = 0) or (Q > Length(S)) or ((S[Q] <> '.') and (S[Q] <> ')')) then Exit;
    Ordered := True;
    Mark := S[Q];
    Inc(Q);
  end;
  if (Q <= Length(S)) and (S[Q] <> ' ') then Exit;
  Sp := 0;
  while (Q + Sp <= Length(S)) and (S[Q + Sp] = ' ') do Inc(Sp);
  Empty := Q + Sp > Length(S);
  { columns are 0-based: the marker ends at column Q - 1 }
  if Empty or (Sp > 4) then ContentCol := Q
  else ContentCol := Q - 1 + Sp;
  Result := True;
end;

const
  BlockTags: array[0..45] of string = ('address', 'article', 'aside', 'base', 'blockquote', 'body',
    'caption', 'center', 'col', 'colgroup', 'dd', 'details', 'dialog', 'dir', 'div', 'dl', 'dt',
    'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head',
    'header', 'hr', 'html', 'li', 'main', 'nav', 'ol', 'p', 'pre', 'section', 'summary', 'table',
    'tbody', 'td', 'th', 'tr', 'ul');

{ an HTML block's start (T without its indentation): 1 a comment, 6 a block element's tag, 7 a
  lone tag of another element (it cannot interrupt a paragraph), 0 none }
function HtmlBlockKind(const T: WideString): Integer;
var
  Q, I: Integer;
  Name: string;
begin
  Result := 0;
  if (T = '') or (T[1] <> '<') then Exit;
  if StartsWithW(T, '<!--') then
  begin
    Result := 1;
    Exit;
  end;
  Q := 2;
  if (Q <= Length(T)) and (T[Q] = '/') then Inc(Q);
  Name := '';
  while (Q <= Length(T)) and (IsAsciiLetter(T[Q]) or IsDigitW(T[Q]) or (T[Q] = '-')) do
  begin
    Name := Name + LowerCase(Char(Ord(T[Q])));
    Inc(Q);
  end;
  if (Name = '') or not IsAsciiLetter(WideChar(Name[1])) then Exit;
  if (Q <= Length(T)) and not IsSpaceW(T[Q]) and (T[Q] <> '>') and (T[Q] <> '/') then Exit;
  for I := Low(BlockTags) to High(BlockTags) do
    if BlockTags[I] = Name then
    begin
      Result := 6;
      Exit;
    end;
  if T[Length(TrimRight(T))] = '>' then Result := 7;
end;

{ the cells of a table's row: the line without its outer pipes, cut at the pipes that are not
  escaped }
function SplitCells(const T: WideString): TWLines;
var
  S, Cell: WideString;
  I: Integer;
begin
  Result := nil;
  S := Trim(T);
  if (S <> '') and (S[1] = '|') then Delete(S, 1, 1);
  if (S <> '') and (S[Length(S)] = '|') and ((Length(S) < 2) or (S[Length(S) - 1] <> '\')) then
    SetLength(S, Length(S) - 1);
  Cell := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) and (S[I + 1] = '|') then
    begin
      Cell := Cell + '|';
      Inc(I, 2);
      Continue;
    end;
    if S[I] = '|' then
    begin
      AddLine(Result, Trim(Cell));
      Cell := '';
    end
    else
      Cell := Cell + S[I];
    Inc(I);
  end;
  AddLine(Result, Trim(Cell));
end;

{ a table's delimiter row: its cells' alignments; False when T is none }
function DelimiterRow(const T: WideString; out Aligns: array of TAlignment; out Count: Integer): Boolean;
var
  Cells: TWLines;
  I, K: Integer;
  C: WideString;
  L, R: Boolean;
begin
  Result := False;
  Count := 0;
  if (Pos('|', T) = 0) and (Pos(':', T) = 0) then Exit;
  Cells := SplitCells(T);
  for I := 0 to High(Cells) do
  begin
    C := Cells[I];
    if C = '' then Exit;
    L := C[1] = ':';
    R := C[Length(C)] = ':';
    for K := 1 + Ord(L) to Length(C) - Ord(R) do
      if C[K] <> '-' then Exit;
    if Length(C) - Ord(L) - Ord(R) < 1 then Exit;
    if I <= High(Aligns) then
      if L and R then Aligns[I] := taCenter
      else if R then Aligns[I] := taRightJustify
      else Aligns[I] := taLeftJustify;
  end;
  Count := Length(Cells);
  Result := Count > 0;
end;

{ line S begins a block that ends a paragraph (and a lazy continuation) }
function InterruptsParagraph(const S: WideString): Boolean;
var
  T, Info, Content: WideString;
  Ch, Mark: WideChar;
  Len, Num, Col: Integer;
  Ordered, Empty: Boolean;
begin
  Result := False;
  if IsBlank(S) or (LeadSpaces(S) > 3) then Exit;
  T := TrimLeft(S);
  Result := IsFence(T, Ch, Len, Info) or (AtxLevel(T, Content) > 0) or IsRule(T) or (T[1] = '>') or
    (HtmlBlockKind(T) in [1, 6]);
  if not Result and ListMarker(S, Ordered, Mark, Num, Col, Empty) then
    Result := not Empty and (not Ordered or (Num = 1));
end;

{ the blocks of lines L into Parent; Nums: each line's number in the text (0-based) }
procedure TMdParser.ParseBlocks(const L: TWLines; const Nums: TLineNums; Parent: TSdBlock);
var
  I, N, Ind, Lvl, FLen, Num, Col, Cnt, HeadCnt, K, W: Integer;
  S, T, Info, Content: WideString;
  Para, Sub: TWLines;
  ParaNums, SubNums: TLineNums;
  FCh, Mark, Mark2: WideChar;
  B, List, Item, Row: TSdBlock;
  Ordered, Ordered2, Empty, TrailBlank, InFence: Boolean;
  Aligns: array[0..63] of TAlignment;
  Cells: TWLines;

  procedure Flush;
  begin
    if Length(Para) = 0 then Exit;
    B := Parent.Add(bkParagraph);
    B.Line := ParaNums[0];
    B.Text := TrimRight(JoinLines(Para));
    Para := nil;
    ParaNums := nil;
  end;

  procedure AddRow(const Line: WideString; Head: Boolean; LineNum: Integer);
  var
    C: Integer;
    Cell: TSdBlock;
    Parts: TWLines;
  begin
    Row := B.Add(bkRow);
    Row.Header := Head;
    Row.Line := LineNum;
    Parts := SplitCells(Line);
    { as many cells as the head: what is missing empty, what is over left out }
    for C := 0 to HeadCnt - 1 do
    begin
      Cell := Row.Add(bkCell);
      Cell.Line := LineNum;
      if C <= High(Aligns) then Cell.Align := Aligns[C];
      if C <= High(Parts) then Cell.Text := Parts[C];
    end;
  end;

begin
  N := Length(L);
  Para := nil;
  ParaNums := nil;
  I := 0;
  while I < N do
  begin
    S := L[I];
    if IsBlank(S) then
    begin
      Flush;
      Inc(I);
      Continue;
    end;
    Ind := LeadSpaces(S);
    T := Copy(S, Ind + 1, MaxInt);
    { indented code (a paragraph goes on through an indented line) }
    if Ind >= 4 then
    begin
      if Length(Para) > 0 then
      begin
        AddLine(Para, T);
        AddNum(ParaNums, Nums[I]);
        Inc(I);
        Continue;
      end;
      Sub := nil;
      K := Nums[I];
      while (I < N) and (IsBlank(L[I]) or (LeadSpaces(L[I]) >= 4)) do
      begin
        AddLine(Sub, StripSpaces(L[I], 4));
        Inc(I);
      end;
      while (Length(Sub) > 0) and IsBlank(Sub[High(Sub)]) do SetLength(Sub, Length(Sub) - 1);
      B := Parent.Add(bkCode);
      B.Line := K;
      B.Text := JoinLines(Sub);
      Continue;
    end;
    { fenced code }
    if IsFence(T, FCh, FLen, Info) then
    begin
      Flush;
      { the code's first line: the one after the fence }
      K := Nums[I] + 1;
      Inc(I);
      Sub := nil;
      while I < N do
      begin
        if (LeadSpaces(L[I]) < 4) and IsClosingFence(TrimLeft(L[I]), FCh, FLen) then
        begin
          Inc(I);
          Break;
        end;
        AddLine(Sub, StripSpaces(L[I], Ind));
        Inc(I);
      end;
      B := Parent.Add(bkCode);
      B.Line := K;
      B.Text := JoinLines(Sub);
      Info := Unescape(Info);
      K := Pos(' ', Info);
      if K > 0 then Info := Copy(Info, 1, K - 1);
      B.Language := AsciiOf(Info);
      while (B.Language <> '') and (B.Language[1] in ['{', '.']) do Delete(B.Language, 1, 1);
      if (B.Language <> '') and (B.Language[Length(B.Language)] = '}') then
        SetLength(B.Language, Length(B.Language) - 1);
      Continue;
    end;
    { ATX heading }
    Lvl := AtxLevel(T, Content);
    if Lvl > 0 then
    begin
      Flush;
      B := Parent.Add(bkHeading);
      B.Line := Nums[I];
      B.Level := Lvl;
      B.Text := Content;
      Inc(I);
      Continue;
    end;
    { setext heading: the paragraph above the underline }
    if Length(Para) > 0 then
    begin
      Lvl := SetextLevel(T);
      if Lvl > 0 then
      begin
        B := Parent.Add(bkHeading);
        B.Line := ParaNums[0];
        B.Level := Lvl;
        B.Text := TrimRight(JoinLines(Para));
        Para := nil;
        ParaNums := nil;
        Inc(I);
        Continue;
      end;
      { a table: the paragraph's last line its head, this line the delimiter row }
      if DelimiterRow(T, Aligns, Cnt) and (Length(SplitCells(Para[High(Para)])) = Cnt) then
      begin
        Info := Para[High(Para)];
        K := ParaNums[High(ParaNums)];
        SetLength(Para, Length(Para) - 1);
        SetLength(ParaNums, Length(ParaNums) - 1);
        Flush;
        HeadCnt := Cnt;
        B := Parent.Add(bkTable);
        B.Line := K;
        AddRow(Info, True, K);
        Inc(I);
        while (I < N) and not IsBlank(L[I]) and not InterruptsParagraph(L[I]) do
        begin
          AddRow(L[I], False, Nums[I]);
          Inc(I);
        end;
        Continue;
      end;
    end;
    { thematic break }
    if IsRule(T) then
    begin
      Flush;
      Parent.Add(bkRule).Line := Nums[I];
      Inc(I);
      Continue;
    end;
    { block quote: its lines without their '>', a paragraph's lazy lines with them }
    if T[1] = '>' then
    begin
      Flush;
      Sub := nil;
      SubNums := nil;
      K := Nums[I];
      while I < N do
      begin
        S := L[I];
        Ind := LeadSpaces(S);
        if (Ind < 4) and (Ind < Length(S)) and (S[Ind + 1] = '>') then
        begin
          T := Copy(S, Ind + 2, MaxInt);
          if (T <> '') and (T[1] = ' ') then Delete(T, 1, 1);
          AddLine(Sub, T);
        end
        else if not IsBlank(S) and (Length(Sub) > 0) and not IsBlank(Sub[High(Sub)]) and
          not InterruptsParagraph(S) then
          AddLine(Sub, TrimLeft(S))
        else
          Break;
        AddNum(SubNums, Nums[I]);
        Inc(I);
      end;
      B := Parent.Add(bkQuote);
      B.Line := K;
      ParseBlocks(Sub, SubNums, B);
      Continue;
    end;
    { a list: its items while their markers are of the same kind }
    if ListMarker(S, Ordered, Mark, Num, Col, Empty) and
      ((Length(Para) = 0) or (not Empty and (not Ordered or (Num = 1)))) then
    begin
      Flush;
      List := Parent.Add(bkList);
      List.Line := Nums[I];
      List.Ordered := Ordered;
      List.Start := Num;
      repeat
        ListMarker(L[I], Ordered2, Mark2, Num, Col, Empty);
        W := Col;
        Sub := nil;
        SubNums := nil;
        K := Nums[I];
        AddLine(Sub, Copy(L[I], W + 1, MaxInt));
        AddNum(SubNums, Nums[I]);
        Inc(I);
        while I < N do
        begin
          S := L[I];
          if IsBlank(S) then
          begin
            { an empty item ends at a blank line }
            if (Length(Sub) = 1) and (Sub[0] = '') then Break;
            AddLine(Sub, '');
          end
          else if LeadSpaces(S) >= W then
            AddLine(Sub, Copy(S, W + 1, MaxInt))
          else if not IsBlank(Sub[High(Sub)]) and not InterruptsParagraph(S) and
            not ListMarker(S, Ordered2, Mark2, Num, Col, Empty) then
            AddLine(Sub, TrimLeft(S))
          else
            Break;
          AddNum(SubNums, Nums[I]);
          Inc(I);
        end;
        TrailBlank := False;
        while (Length(Sub) > 0) and IsBlank(Sub[High(Sub)]) do
        begin
          SetLength(Sub, Length(Sub) - 1);
          SetLength(SubNums, Length(SubNums) - 1);
          TrailBlank := True;
        end;
        Item := List.Add(bkItem);
        Item.Line := K;
        { a task list item: [ ] or [x] first }
        if Length(Sub) > 0 then
        begin
          T := Sub[0];
          if (Length(T) >= 3) and (T[1] = '[') and (T[3] = ']') and ((T[2] = ' ') or (T[2] = 'x') or (T[2] = 'X')) and
            ((Length(T) = 3) or (T[4] = ' ')) then
          begin
            Item.Task := Ord(T[2] <> ' ');
            Sub[0] := Copy(T, 5, MaxInt);
          end;
        end;
        { a blank line between two of its blocks makes the list loose (not one inside its code,
          nor one before a list inside it) }
        InFence := False;
        for K := 0 to High(Sub) - 1 do
        begin
          if IsFence(TrimLeft(Sub[K]), FCh, FLen, Info) then InFence := not InFence;
          if not InFence and IsBlank(Sub[K]) and (K > 0) and not IsBlank(Sub[K + 1]) and
            (LeadSpaces(Sub[K + 1]) < 2) and not ListMarker(Sub[K + 1], Ordered2, Mark2, Num, Col, Empty) then
            List.Loose := True;
        end;
        ParseBlocks(Sub, SubNums, Item);
        if I >= N then Break;
        if not ListMarker(L[I], Ordered2, Mark2, Num, Col, Empty) or (Ordered2 <> Ordered) or
          (Mark2 <> Mark) or IsRule(TrimLeft(L[I])) then Break;
        if TrailBlank then List.Loose := True;
      until False;
      Continue;
    end;
    { HTML block: kept as markup; a comment left out }
    K := HtmlBlockKind(T);
    if (K = 1) or (K = 6) or ((K = 7) and (Length(Para) = 0)) then
    begin
      Flush;
      Sub := nil;
      if K = 1 then
      begin
        while I < N do
        begin
          Inc(I);
          if Pos('-->', L[I - 1]) > 0 then Break;
        end;
        Continue;
      end;
      K := Nums[I];
      while (I < N) and not IsBlank(L[I]) do
      begin
        AddLine(Sub, L[I]);
        Inc(I);
      end;
      B := Parent.Add(bkMarkup);
      B.Line := K;
      B.Text := JoinLines(Sub);
      Continue;
    end;
    { a link reference definition (before a paragraph begins) }
    if (Length(Para) = 0) and TryRefDef(T) then
    begin
      Inc(I);
      Continue;
    end;
    AddLine(Para, T);
    AddNum(ParaNums, Nums[I]);
    Inc(I);
  end;
  Flush;
end;

{ ---------------------------------------------------------------- the document }

function ParseMarkdown(const Text: WideString): TSdRichDoc;
var
  Lines, Front: TWLines;
  Nums: TLineNums;
  P: TMdParser;
  I, First: Integer;
  B: TSdBlock;
begin
  Result := TSdRichDoc.Create;
  try
    Lines := SplitLines(Text);
    First := 0;
    { a YAML front matter: between a '---' on the first line and the next '---' or '...' }
    if (Length(Lines) > 1) and (TrimRight(Lines[0]) = '---') then
      for I := 1 to High(Lines) do
        if (TrimRight(Lines[I]) = '---') or (TrimRight(Lines[I]) = '...') then
        begin
          Front := Copy(Lines, 1, I - 1);
          B := Result.Root.Add(bkCode);
          B.Text := JoinLines(Front);
          B.Line := 1;
          B.Language := 'yaml';
          First := I + 1;
          Break;
        end;
    P := TMdParser.Create(Result);
    try
      SetLength(Nums, Length(Lines) - First);
      for I := 0 to High(Nums) do Nums[I] := First + I;
      P.ParseBlocks(Copy(Lines, First, MaxInt), Nums, Result.Root);
      P.InlineAll(Result.Root);
    finally
      P.Free;
    end;
    Result.MakeAnchors;
  except
    Result.Free;
    raise;
  end;
end;

function MarkdownToPlainText(const Text: WideString): WideString;
var
  D: TSdRichDoc;
begin
  D := ParseMarkdown(Text);
  try
    Result := D.PlainText;
  finally
    D.Free;
  end;
end;

end.
