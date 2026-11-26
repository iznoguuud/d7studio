{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTextDiff;

{ D7 Studio - the differences between two texts, as the History tab shows them.

  Line by line: the lines that occur once in each text and keep their order anchor the comparison
  (a patience diff), between the anchors - and where there are none - Myers' algorithm finds a
  longest common subsequence in linear space. A block of lines only inserted or only deleted that
  could lie a few lines higher or lower (its lines repeat around it) is slid to where it reads best:
  after a blank line, ending with one, its first line the least indented. Inside a changed line
  the words that differ are found the same way, word by word.

  The lines of a text lie between its line ends (CR LF, LF or CR): a text that ends with a line end
  has an empty last line, as the editor counts them. With blanks ignored, two lines are the same
  when they are with each run of spaces and tabs as one space and none at their ends. A comparison
  too costly (two long texts with little in common) takes the rest as replaced whole (Complete
  False). Nothing here needs the IDE. }

{$Q-,R-,B-,H+}

interface

type
  TIntArray = array of Integer;

  { a text's lines: where each begins and how long it is without its line end (0-based offsets) }
  TTextLines = class
  private
    FText: string;
    FStart, FLen: TIntArray;
    FCount: Integer;
  public
    constructor Create(const AText: string);
    function Line(I: Integer): string;
    function LineStart(I: Integer): Integer;
    function LineLength(I: Integer): Integer;
    { the line that holds offset P (0-based) }
    function LineOf(P: Integer): Integer;
    { lines First .. First + Count - 1 with the line ends between them, none after the last }
    function Range(First, Count: Integer): string;
    { the text's line end: its first one's, CR LF when it has none }
    function LineEnd: string;
    property Count: Integer read FCount;
    property Text: string read FText;
  end;

  { the old text of a comparison, or the new one }
  TDiffSide = (dsOld, dsNew);

  { a stretch of the two texts: dkEqual - LenA = LenB lines alike in both, from line A of the old
    text and line B of the new (0-based); dkChange - LenA lines of the old text replaced by LenB
    lines of the new, one of them 0 for an insertion or a deletion. Runs alternate. }
  TDiffKind = (dkEqual, dkChange);
  TDiffRun = record
    Kind: TDiffKind;
    A, B, LenA, LenB: Integer;
  end;
  TDiffRuns = array of TDiffRun;

  TLineDiff = class
  private
    FOld, FNew: TTextLines;
    FRuns: TDiffRuns;
    FCount: Integer;
    FAdded, FRemoved, FChanges: Integer;
    FComplete: Boolean;
    function GetRun(I: Integer): TDiffRun;
    procedure AddRun(Kind: TDiffKind; A, B, LenA, LenB: Integer; Always: Boolean = False);
    procedure Slide(const IdA, IdB: TIntArray);
    procedure Normalize;
    procedure Count;
  public
    constructor Create(const OldText, NewText: string; IgnoreBlanks: Boolean = False);
    destructor Destroy; override;
    { a side's text }
    function Lines(Side: TDiffSide): TTextLines;
    { the run that holds line Line of Side's text; -1 none - past the end }
    function RunOf(Side: TDiffSide; Line: Integer): Integer;
    { where line Line of Side's text is in the other: an equal line's partner, a changed line's place
      in the other side of its change (its first line, or the line after an insertion or a deletion) }
    function MapLine(Side: TDiffSide; Line: Integer): Integer;
    property Runs[I: Integer]: TDiffRun read GetRun; default;
    property RunCount: Integer read FCount;
    property OldLines: TTextLines read FOld;
    property NewLines: TTextLines read FNew;
    property Added: Integer read FAdded;           // lines only in the new text
    property Removed: Integer read FRemoved;       // lines only in the old
    property Changes: Integer read FChanges;       // the dkChange runs
    property Complete: Boolean read FComplete;     // False: a part was taken as replaced whole
  end;

  { a part of a line: Len characters from Start (0-based) }
  TDiffSpan = record
    Start, Len: Integer;
  end;
  TDiffSpans = array of TDiffSpan;

{ where run R begins in Side's text, and how many of its lines it holds there }
function RunStart(const R: TDiffRun; Side: TDiffSide): Integer;
function RunLength(const R: TDiffRun; Side: TDiffSide): Integer;

{ the parts of line A and of line B that differ, word by word - a word is a run of letters, digits,
  '_' and bytes beyond ASCII, a run of blanks, or one other character; neighbouring changed words
  are one part, with the blanks between them. False when the lines have too little in common to be
  one line changed (less than a third of their characters): no parts then }
function WordDiff(const A, B: string; out SpansA, SpansB: TDiffSpans): Boolean;

{ a line with each run of spaces and tabs as one space and none at its ends }
function NormalizeBlanks(const S: string): string;

{ a string as a number (FNV-1a): the lines' and words' table; a file's folder in the history }
function TextHash(const S: string): Cardinal;

{ the work a comparison may do before it takes the rest as replaced (steps of Myers' snakes) }
var
  DiffWorkLimit: Integer = 40000000;

implementation

const
  Blanks = [' ', #9];

type
  TBoolArray = array of Boolean;

  { equal strings get equal numbers: the lines (words) are compared as numbers }
  TInterner = class
  private
    FKeys: array of string;
    FCount: Integer;
    FTable: TIntArray;            // a slot holds a key's number + 1; 0 an empty slot
    FMask: Integer;
    procedure Grow;
  public
    constructor Create(Capacity: Integer);
    function Id(const S: string): Integer;
    property Count: Integer read FCount;
  end;

function TextHash(const S: string): Cardinal;
var
  I: Integer;
begin
  Result := 2166136261;
  for I := 1 to Length(S) do
    Result := (Result xor Ord(S[I])) * 16777619;
end;

constructor TInterner.Create(Capacity: Integer);
var
  Size: Integer;
begin
  inherited Create;
  Size := 64;
  while Size < Capacity * 2 do Size := Size * 2;
  SetLength(FTable, Size);
  FMask := Size - 1;
  SetLength(FKeys, Capacity + 16);
end;

procedure TInterner.Grow;
var
  I, Slot: Integer;
begin
  SetLength(FTable, 0);
  SetLength(FTable, (FMask + 1) * 2);
  FMask := (FMask + 1) * 2 - 1;
  for I := 0 to FCount - 1 do
  begin
    Slot := Integer(TextHash(FKeys[I]) and Cardinal(FMask));
    while FTable[Slot] <> 0 do Slot := (Slot + 1) and FMask;
    FTable[Slot] := I + 1;
  end;
end;

function TInterner.Id(const S: string): Integer;
var
  Slot: Integer;
begin
  Slot := Integer(TextHash(S) and Cardinal(FMask));
  while FTable[Slot] <> 0 do
  begin
    if FKeys[FTable[Slot] - 1] = S then
    begin
      Result := FTable[Slot] - 1;
      Exit;
    end;
    Slot := (Slot + 1) and FMask;
  end;
  if FCount = Length(FKeys) then SetLength(FKeys, FCount * 2 + 16);
  FKeys[FCount] := S;
  FTable[Slot] := FCount + 1;
  Result := FCount;
  Inc(FCount);
  if FCount * 2 > FMask then Grow;
end;

function NormalizeBlanks(const S: string): string;
var
  I, N: Integer;
  Blank: Boolean;
begin
  SetLength(Result, Length(S));
  N := 0;
  Blank := False;
  for I := 1 to Length(S) do
    if S[I] in Blanks then
      Blank := N > 0
    else
    begin
      if Blank then
      begin
        Inc(N);
        Result[N] := ' ';
        Blank := False;
      end;
      Inc(N);
      Result[N] := S[I];
    end;
  SetLength(Result, N);
end;

{ ---------------------------------------------------------------- TTextLines }

constructor TTextLines.Create(const AText: string);
var
  I, N, Start: Integer;
begin
  inherited Create;
  FText := AText;
  N := Length(AText);
  SetLength(FStart, 64);
  SetLength(FLen, 64);
  FCount := 0;
  Start := 0;
  I := 1;
  while True do
  begin
    if (I > N) or (AText[I] = #13) or (AText[I] = #10) then
    begin
      if FCount = Length(FStart) then
      begin
        SetLength(FStart, FCount * 2);
        SetLength(FLen, FCount * 2);
      end;
      FStart[FCount] := Start;
      FLen[FCount] := I - 1 - Start;
      Inc(FCount);
      if I > N then Break;
      if (AText[I] = #13) and (I < N) and (AText[I + 1] = #10) then Inc(I);
      Start := I;
    end;
    Inc(I);
  end;
end;

function TTextLines.Line(I: Integer): string;
begin
  Result := Copy(FText, FStart[I] + 1, FLen[I]);
end;

function TTextLines.LineStart(I: Integer): Integer;
begin
  Result := FStart[I];
end;

function TTextLines.LineLength(I: Integer): Integer;
begin
  Result := FLen[I];
end;

function TTextLines.LineOf(P: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := FCount - 1;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi + 1) div 2;
    if FStart[Mid] <= P then Lo := Mid else Hi := Mid - 1;
  end;
  Result := Lo;
end;

function TTextLines.Range(First, Count: Integer): string;
var
  Last: Integer;
begin
  Result := '';
  if Count <= 0 then Exit;
  Last := First + Count - 1;
  Result := Copy(FText, FStart[First] + 1, FStart[Last] + FLen[Last] - FStart[First]);
end;

function TTextLines.LineEnd: string;
begin
  if FCount < 2 then Result := #13#10
  else Result := Copy(FText, FLen[0] + 1, FStart[1] - FLen[0]);
end;

{ ---------------------------------------------------------------- the common items }

type
  { the ranges still to compare: A[A0..A1) with B[B0..B1); Patience: its unique items may anchor it }
  TRange = record
    A0, A1, B0, B1: Integer;
    Patience: Boolean;
  end;

  TCommon = class
  private
    A, B: TIntArray;
    KeepA, KeepB: TBoolArray;
    CountA, CountB, PosA, PosB: TIntArray;   // per item number, while a range is anchored
    Stack: array of TRange;
    SP: Integer;
    Work: Int64;
    Complete: Boolean;
    procedure Push(A0, A1, B0, B1: Integer; Patience: Boolean);
    function Anchor(const R: TRange): Boolean;
    function Bisect(const R: TRange; out X, Y: Integer): Boolean;
  public
    constructor Create(const AA, BB: TIntArray; NA, NB, Ids: Integer; Patience: Boolean);
  end;

{ the items of a longest common subsequence of AA[0..NA) and BB[0..NB) marked in KeepA / KeepB;
  Ids: the item numbers are below it }
constructor TCommon.Create(const AA, BB: TIntArray; NA, NB, Ids: Integer; Patience: Boolean);
var
  R: TRange;
  X, Y: Integer;
begin
  inherited Create;
  A := AA;
  B := BB;
  SetLength(KeepA, NA);
  SetLength(KeepB, NB);
  Complete := True;
  if Patience then
  begin
    SetLength(CountA, Ids);
    SetLength(CountB, Ids);
    SetLength(PosA, Ids);
    SetLength(PosB, Ids);
  end;
  SP := 0;
  Push(0, NA, 0, NB, Patience);
  while SP > 0 do
  begin
    Dec(SP);
    R := Stack[SP];
    { the common start and end are kept }
    while (R.A0 < R.A1) and (R.B0 < R.B1) and (A[R.A0] = B[R.B0]) do
    begin
      KeepA[R.A0] := True;
      KeepB[R.B0] := True;
      Inc(R.A0);
      Inc(R.B0);
    end;
    while (R.A0 < R.A1) and (R.B0 < R.B1) and (A[R.A1 - 1] = B[R.B1 - 1]) do
    begin
      KeepA[R.A1 - 1] := True;
      KeepB[R.B1 - 1] := True;
      Dec(R.A1);
      Dec(R.B1);
    end;
    if (R.A0 = R.A1) or (R.B0 = R.B1) then Continue;
    if R.Patience and Anchor(R) then Continue;
    if (Work <= DiffWorkLimit) and Bisect(R, X, Y) then
    begin
      Push(X, R.A1, Y, R.B1, False);
      Push(R.A0, X, R.B0, Y, False);
    end
    else if Work > DiffWorkLimit then
      Complete := False;
  end;
end;

procedure TCommon.Push(A0, A1, B0, B1: Integer; Patience: Boolean);
begin
  if SP = Length(Stack) then SetLength(Stack, SP * 2 + 16);
  Stack[SP].A0 := A0;
  Stack[SP].A1 := A1;
  Stack[SP].B0 := B0;
  Stack[SP].B1 := B1;
  Stack[SP].Patience := Patience;
  Inc(SP);
end;

{ the items that occur once in each side of the range, in the longest run of them that keeps its
  order on both sides, are kept and split the range: the parts between them are compared each on
  its own. False: there are none }
function TCommon.Anchor(const R: TRange): Boolean;
var
  I, K, N, Lo, Hi, Mid, Len: Integer;
  PA, PB, Tails, Prev, Seq: TIntArray;
  LastA, LastB: Integer;
begin
  Result := False;
  for I := R.A0 to R.A1 - 1 do
  begin
    Inc(CountA[A[I]]);
    PosA[A[I]] := I;
  end;
  for I := R.B0 to R.B1 - 1 do
  begin
    Inc(CountB[B[I]]);
    PosB[B[I]] := I;
  end;
  { the unique pairs in the old side's order }
  N := 0;
  for I := R.A0 to R.A1 - 1 do
    if (CountA[A[I]] = 1) and (CountB[A[I]] = 1) then
    begin
      if N = Length(PA) then
      begin
        SetLength(PA, N * 2 + 16);
        SetLength(PB, N * 2 + 16);
      end;
      PA[N] := I;
      PB[N] := PosB[A[I]];
      Inc(N);
    end;
  for I := R.A0 to R.A1 - 1 do CountA[A[I]] := 0;
  for I := R.B0 to R.B1 - 1 do CountB[B[I]] := 0;
  Inc(Work, (R.A1 - R.A0) + (R.B1 - R.B0));
  if N = 0 then Exit;
  { the longest increasing run of their places in the new side (patience sorting) }
  SetLength(Tails, N);
  SetLength(Prev, N);
  Len := 0;
  for I := 0 to N - 1 do
  begin
    Lo := 0;
    Hi := Len;
    while Lo < Hi do
    begin
      Mid := (Lo + Hi) div 2;
      if PB[Tails[Mid]] < PB[I] then Lo := Mid + 1 else Hi := Mid;
    end;
    if Lo > 0 then Prev[I] := Tails[Lo - 1] else Prev[I] := -1;
    Tails[Lo] := I;
    if Lo = Len then Inc(Len);
  end;
  SetLength(Seq, Len);
  K := Tails[Len - 1];
  for I := Len - 1 downto 0 do
  begin
    Seq[I] := K;
    K := Prev[K];
  end;
  { kept; the parts between them compared on their own (the last part first off the stack: pushed
    first) }
  LastA := R.A1;
  LastB := R.B1;
  for I := Len - 1 downto 0 do
  begin
    K := Seq[I];
    KeepA[PA[K]] := True;
    KeepB[PB[K]] := True;
    if (PA[K] + 1 < LastA) or (PB[K] + 1 < LastB) then Push(PA[K] + 1, LastA, PB[K] + 1, LastB, True);
    LastA := PA[K];
    LastB := PB[K];
  end;
  if (R.A0 < LastA) or (R.B0 < LastB) then Push(R.A0, LastA, R.B0, LastB, True);
  Result := True;
end;

{ Myers' middle snake: a point (X, Y) the shortest edit script of the range passes through, at
  the end of a snake - the parts before and after it are compared on their own. False: the range
  has nothing in common, or the work grew past DiffWorkLimit (then nothing of it is kept) }
function TCommon.Bisect(const R: TRange; out X, Y: Integer): Boolean;
var
  N, M, MaxD, VOff, VLen, Delta, D, K1, K2, K1Off, K2Off, X1, Y1, X2, Y2, I: Integer;
  K1Start, K1End, K2Start, K2End: Integer;
  V1, V2: TIntArray;
  Front: Boolean;
begin
  Result := False;
  N := R.A1 - R.A0;
  M := R.B1 - R.B0;
  MaxD := (N + M + 1) div 2;
  VOff := MaxD;
  VLen := 2 * MaxD;
  SetLength(V1, VLen + 2);
  SetLength(V2, VLen + 2);
  for I := 0 to VLen + 1 do
  begin
    V1[I] := -1;
    V2[I] := -1;
  end;
  V1[VOff + 1] := 0;
  V2[VOff + 1] := 0;
  Delta := N - M;
  Front := Odd(Delta);
  K1Start := 0;
  K1End := 0;
  K2Start := 0;
  K2End := 0;
  for D := 0 to MaxD - 1 do
  begin
    { forward }
    K1 := -D + K1Start;
    while K1 <= D - K1End do
    begin
      K1Off := VOff + K1;
      if (K1 = -D) or ((K1 <> D) and (V1[K1Off - 1] < V1[K1Off + 1])) then X1 := V1[K1Off + 1]
      else X1 := V1[K1Off - 1] + 1;
      Y1 := X1 - K1;
      while (X1 < N) and (Y1 < M) and (A[R.A0 + X1] = B[R.B0 + Y1]) do
      begin
        Inc(X1);
        Inc(Y1);
      end;
      V1[K1Off] := X1;
      if X1 > N then Inc(K1End, 2)
      else if Y1 > M then Inc(K1Start, 2)
      else if Front then
      begin
        K2Off := VOff + Delta - K1;
        if (K2Off >= 0) and (K2Off < VLen) and (V2[K2Off] <> -1) then
        begin
          X2 := N - V2[K2Off];
          if X1 >= X2 then
          begin
            X := R.A0 + X1;
            Y := R.B0 + Y1;
            Result := ((X <> R.A0) or (Y <> R.B0)) and ((X <> R.A1) or (Y <> R.B1));
            Exit;
          end;
        end;
      end;
      Inc(K1, 2);
    end;
    { backward }
    K2 := -D + K2Start;
    while K2 <= D - K2End do
    begin
      K2Off := VOff + K2;
      if (K2 = -D) or ((K2 <> D) and (V2[K2Off - 1] < V2[K2Off + 1])) then X2 := V2[K2Off + 1]
      else X2 := V2[K2Off - 1] + 1;
      Y2 := X2 - K2;
      while (X2 < N) and (Y2 < M) and (A[R.A1 - 1 - X2] = B[R.B1 - 1 - Y2]) do
      begin
        Inc(X2);
        Inc(Y2);
      end;
      V2[K2Off] := X2;
      if X2 > N then Inc(K2End, 2)
      else if Y2 > M then Inc(K2Start, 2)
      else if not Front then
      begin
        K1Off := VOff + Delta - K2;
        if (K1Off >= 0) and (K1Off < VLen) and (V1[K1Off] <> -1) then
        begin
          X1 := V1[K1Off];
          Y1 := VOff + X1 - K1Off;
          X2 := N - X2;
          if X1 >= X2 then
          begin
            X := R.A0 + X1;
            Y := R.B0 + Y1;
            Result := ((X <> R.A0) or (Y <> R.B0)) and ((X <> R.A1) or (Y <> R.B1));
            Exit;
          end;
        end;
      end;
      Inc(K2, 2);
    end;
    Inc(Work, 2 * D + 2);
    if Work > DiffWorkLimit then Exit;
  end;
end;

{ ---------------------------------------------------------------- TLineDiff }

constructor TLineDiff.Create(const OldText, NewText: string; IgnoreBlanks: Boolean);
var
  Names: TInterner;
  IdA, IdB: TIntArray;
  I, J, I0, J0: Integer;
  C: TCommon;

  { the lines as numbers: alike lines - blanks ignored, alike but for their blanks - one number }
  function LineIds(L: TTextLines): TIntArray;
  var
    K: Integer;
  begin
    SetLength(Result, L.Count);
    for K := 0 to L.Count - 1 do
      if IgnoreBlanks then Result[K] := Names.Id(NormalizeBlanks(L.Line(K))) else Result[K] := Names.Id(L.Line(K));
  end;

begin
  inherited Create;
  FOld := TTextLines.Create(OldText);
  FNew := TTextLines.Create(NewText);
  Names := TInterner.Create(FOld.Count + FNew.Count);
  try
    IdA := LineIds(FOld);
    IdB := LineIds(FNew);
    C := TCommon.Create(IdA, IdB, FOld.Count, FNew.Count, Names.Count, True);
    try
      FComplete := C.Complete;
      { the runs: kept lines pair up in their order. An empty equal run at each end gives a block
        that slides there (Slide) the run its lines go into; Normalize takes the empty ones out }
      FCount := 0;
      AddRun(dkEqual, 0, 0, 0, 0, True);
      I := 0;
      J := 0;
      while (I < FOld.Count) or (J < FNew.Count) do
        if (I < FOld.Count) and (J < FNew.Count) and C.KeepA[I] and C.KeepB[J] then
        begin
          I0 := I;
          J0 := J;
          while (I < FOld.Count) and (J < FNew.Count) and C.KeepA[I] and C.KeepB[J] do
          begin
            Inc(I);
            Inc(J);
          end;
          AddRun(dkEqual, I0, J0, I - I0, J - J0);
        end
        else
        begin
          I0 := I;
          J0 := J;
          while (I < FOld.Count) and not C.KeepA[I] do Inc(I);
          while (J < FNew.Count) and not C.KeepB[J] do Inc(J);
          AddRun(dkChange, I0, J0, I - I0, J - J0);
        end;
      AddRun(dkEqual, FOld.Count, FNew.Count, 0, 0, True);
    finally
      C.Free;
    end;
  finally
    Names.Free;
  end;
  Slide(IdA, IdB);
  Normalize;
  Count;
end;

destructor TLineDiff.Destroy;
begin
  FOld.Free;
  FNew.Free;
  inherited;
end;

{ a run after the others; an empty one only Always (the sentinels at the ends) }
procedure TLineDiff.AddRun(Kind: TDiffKind; A, B, LenA, LenB: Integer; Always: Boolean);
begin
  if not Always and (LenA = 0) and (LenB = 0) then Exit;
  if FCount = Length(FRuns) then SetLength(FRuns, FCount * 2 + 16);
  FRuns[FCount].Kind := Kind;
  FRuns[FCount].A := A;
  FRuns[FCount].B := B;
  FRuns[FCount].LenA := LenA;
  FRuns[FCount].LenB := LenB;
  Inc(FCount);
end;

function TLineDiff.GetRun(I: Integer): TDiffRun;
begin
  Result := FRuns[I];
end;

const
  NoIndent = MaxInt div 2;        // a blank line's indent: none of its own

{ the blanks line I begins with; NoIndent: the line is blank }
function LineIndent(L: TTextLines; I: Integer): Integer;
var
  S: Integer;
begin
  S := L.LineStart(I);
  Result := 0;
  while (Result < L.LineLength(I)) and (L.Text[S + Result + 1] in Blanks) do Inc(Result);
  if Result = L.LineLength(I) then Result := NoIndent;
end;

function LineIsBlank(L: TTextLines; I: Integer): Boolean;
begin
  Result := LineIndent(L, I) = NoIndent;
end;

{ a block only inserted or only deleted whose lines repeat around it may lie a few lines higher or
  lower: it goes where it reads best - after a blank line (or at the text's start), ending with a
  blank line, its first line the least indented; of equal places the lowest }
procedure TLineDiff.Slide(const IdA, IdB: TIntArray);
var
  I, S, E, Up, Down, T, Best, Score, BestScore, Room: Integer;
  Ids: TIntArray;
  L: TTextLines;
  Insert: Boolean;
begin
  for I := 0 to FCount - 1 do
  begin
    if (FRuns[I].Kind <> dkChange) or ((FRuns[I].LenA > 0) and (FRuns[I].LenB > 0)) then Continue;
    Insert := FRuns[I].LenA = 0;
    if Insert then
    begin
      Ids := IdB;
      L := FNew;
      S := FRuns[I].B;
      E := S + FRuns[I].LenB;
    end
    else
    begin
      Ids := IdA;
      L := FOld;
      S := FRuns[I].A;
      E := S + FRuns[I].LenA;
    end;
    { the room above: the equal run before it, its lines alike the block's last ones }
    Up := 0;
    if (I > 0) and (FRuns[I - 1].Kind = dkEqual) then
    begin
      Room := FRuns[I - 1].LenA;
      while (Up < Room) and (Ids[S - Up - 1] = Ids[E - Up - 1]) do Inc(Up);
    end;
    Down := 0;
    if (I < FCount - 1) and (FRuns[I + 1].Kind = dkEqual) then
    begin
      Room := FRuns[I + 1].LenA;
      while (Down < Room) and (Ids[S + Down] = Ids[E + Down]) do Inc(Down);
    end;
    if Up + Down = 0 then Continue;
    Best := 0;
    BestScore := Low(Integer);
    for T := -Up to Down do
    begin
      Score := 0;
      if (S + T = 0) or LineIsBlank(L, S + T - 1) then Inc(Score, 4000000);
      if LineIsBlank(L, E + T - 1) then Inc(Score, 2000000);
      Dec(Score, LineIndent(L, S + T) div 2);
      if Score >= BestScore then
      begin
        BestScore := Score;
        Best := T;
      end;
    end;
    if Best = 0 then Continue;
    { the equal runs around it give and take the lines }
    Inc(FRuns[I].A, Best);
    Inc(FRuns[I].B, Best);
    if I > 0 then
    begin
      Inc(FRuns[I - 1].LenA, Best);
      Inc(FRuns[I - 1].LenB, Best);
    end;
    if I < FCount - 1 then
    begin
      Inc(FRuns[I + 1].A, Best);
      Inc(FRuns[I + 1].B, Best);
      Dec(FRuns[I + 1].LenA, Best);
      Dec(FRuns[I + 1].LenB, Best);
    end;
  end;
end;

{ empty runs out, neighbours of a kind one run }
procedure TLineDiff.Normalize;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to FCount - 1 do
  begin
    if (FRuns[I].LenA = 0) and (FRuns[I].LenB = 0) then Continue;
    if (N > 0) and (FRuns[N - 1].Kind = FRuns[I].Kind) then
    begin
      Inc(FRuns[N - 1].LenA, FRuns[I].LenA);
      Inc(FRuns[N - 1].LenB, FRuns[I].LenB);
    end
    else
    begin
      FRuns[N] := FRuns[I];
      Inc(N);
    end;
  end;
  FCount := N;
end;

procedure TLineDiff.Count;
var
  I: Integer;
begin
  FAdded := 0;
  FRemoved := 0;
  FChanges := 0;
  for I := 0 to FCount - 1 do
    if FRuns[I].Kind = dkChange then
    begin
      Inc(FAdded, FRuns[I].LenB);
      Inc(FRemoved, FRuns[I].LenA);
      Inc(FChanges);
    end;
end;

function RunStart(const R: TDiffRun; Side: TDiffSide): Integer;
begin
  if Side = dsOld then Result := R.A else Result := R.B;
end;

function RunLength(const R: TDiffRun; Side: TDiffSide): Integer;
begin
  if Side = dsOld then Result := R.LenA else Result := R.LenB;
end;

function TLineDiff.Lines(Side: TDiffSide): TTextLines;
begin
  if Side = dsOld then Result := FOld else Result := FNew;
end;

function TLineDiff.RunOf(Side: TDiffSide; Line: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Result := -1;
  Lo := 0;
  Hi := FCount - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if Line < RunStart(FRuns[Mid], Side) then Hi := Mid - 1
    else if Line >= RunStart(FRuns[Mid], Side) + RunLength(FRuns[Mid], Side) then Lo := Mid + 1
    else
    begin
      Result := Mid;
      Exit;
    end;
  end;
end;

{ an equal run has as many lines on each side (none empty after Normalize): a line's partner is at
  its place; in a change the same place, at most the change's last line there, its first when the
  other side has none }
function TLineDiff.MapLine(Side: TDiffSide; Line: Integer): Integer;
var
  R, Start, Len: Integer;
  Other: TDiffSide;
begin
  if Side = dsOld then Other := dsNew else Other := dsOld;
  R := RunOf(Side, Line);
  if R < 0 then
    Result := Lines(Other).Count
  else
  begin
    Start := RunStart(FRuns[R], Other);
    Len := RunLength(FRuns[R], Other);
    Result := Start + Line - RunStart(FRuns[R], Side);
    if Result >= Start + Len then Result := Start + Len - 1;
    if Len = 0 then Result := Start;
  end;
  if Result >= Lines(Other).Count then Result := Lines(Other).Count - 1;
  if Result < 0 then Result := 0;
end;

{ ---------------------------------------------------------------- words }

type
  TWords = record
    Start, Len, Id: TIntArray;
    Count: Integer;
  end;

function IsWordChar(C: Char): Boolean;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']) or (Ord(C) >= 128);
end;

procedure SplitWords(const S: string; Names: TInterner; var W: TWords);
var
  I, J, N: Integer;
begin
  N := Length(S);
  SetLength(W.Start, N);
  SetLength(W.Len, N);
  SetLength(W.Id, N);
  W.Count := 0;
  I := 1;
  while I <= N do
  begin
    J := I + 1;
    if IsWordChar(S[I]) then
      while (J <= N) and IsWordChar(S[J]) do Inc(J)
    else if S[I] in Blanks then
      while (J <= N) and (S[J] in Blanks) do Inc(J);
    W.Start[W.Count] := I - 1;
    W.Len[W.Count] := J - I;
    W.Id[W.Count] := Names.Id(Copy(S, I, J - I));
    Inc(W.Count);
    I := J;
  end;
end;

{ word K of S (split into W) is a run of blanks }
function BlankWord(const S: string; const W: TWords; K: Integer): Boolean;
begin
  Result := S[W.Start[K] + 1] in Blanks;
end;

{ the changed words as spans; a run of blanks between two changed words joins them }
procedure ChangedSpans(const S: string; const W: TWords; const Keep: TBoolArray; var Spans: TDiffSpans);
var
  I, N, Start, Stop: Integer;
begin
  SetLength(Spans, 0);
  N := 0;
  I := 0;
  while I < W.Count do
  begin
    if Keep[I] then
    begin
      Inc(I);
      Continue;
    end;
    Start := W.Start[I];
    Stop := W.Start[I] + W.Len[I];
    Inc(I);
    while I < W.Count do
      if not Keep[I] then
      begin
        Stop := W.Start[I] + W.Len[I];
        Inc(I);
      end
      else if BlankWord(S, W, I) and (I + 1 < W.Count) and not Keep[I + 1] then
      begin
        Stop := W.Start[I + 1] + W.Len[I + 1];
        Inc(I, 2);
      end
      else
        Break;
    SetLength(Spans, N + 1);
    Spans[N].Start := Start;
    Spans[N].Len := Stop - Start;
    Inc(N);
  end;
end;

function WordDiff(const A, B: string; out SpansA, SpansB: TDiffSpans): Boolean;
var
  Names: TInterner;
  WA, WB: TWords;
  C: TCommon;
  I, Common: Integer;
begin
  SetLength(SpansA, 0);
  SetLength(SpansB, 0);
  Result := False;
  if (A = '') or (B = '') or (A = B) then Exit;
  Names := TInterner.Create(64);
  try
    SplitWords(A, Names, WA);
    SplitWords(B, Names, WB);
    C := TCommon.Create(WA.Id, WB.Id, WA.Count, WB.Count, Names.Count, False);
    try
      Common := 0;
      for I := 0 to WA.Count - 1 do
        if C.KeepA[I] and not BlankWord(A, WA, I) then Inc(Common, WA.Len[I]);
      { too little alike - what they share is less than a third of both together: two different
        lines, not one line changed }
      if 6 * Common < Length(NormalizeBlanks(A)) + Length(NormalizeBlanks(B)) then Exit;
      ChangedSpans(A, WA, C.KeepA, SpansA);
      ChangedSpans(B, WB, C.KeepB, SpansB);
      Result := True;
    finally
      C.Free;
    end;
  finally
    Names.Free;
  end;
end;

end.
