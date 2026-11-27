{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPasBlocks;

{ D7 Studio - the block structure of a Pascal text for the code editor: the reserved words that open a
  block - begin, case, try, asm, record, class,
  object, interface, dispinterface, repeat - paired with the word that closes it (end, until) and
  the words between (except, finally); the brackets with their depth and partner; the routines
  (heading to the end of the body). Taken from the text's tokens (SdPasLex.TRawToks): a word in a
  comment or a string is none, the text of an asm block is assembler.

  A text being typed is seldom complete, and the rules keep a missing word local: a routine's
  heading (procedure, function, constructor, destructor outside a type) leaves the statement
  blocks still open unclosed, implementation / initialization / finalization all of them; end
  passes an open repeat by, until the blocks that are no repeat; a case inside a record is its
  variant part (the record's end closes both). Brackets still open at begin, end, try, repeat,
  until, except, finally or a routine's heading stay unpaired.

  The folds are the parts of the text the code editor folds, by lines: the unit's sections (each up
  to the line before the next one, or before end.), a uses clause over several lines, the types
  with a body, the routines from their heading, the statement blocks, $REGION ... $ENDREGION,
  $IF... ... $ENDIF, comments over several lines and runs of lines that are // comments. A region
  or conditional not closed yet folds nothing. }

{$Q-,R-,B-,H+}

interface

uses
  SdPasLex;

type
  TPasBlockKind = (bkNone, bkBegin, bkCase, bkTry, bkAsm, bkRecord, bkClass, bkObject,
    bkInterface, bkRepeat);
  TPasWordRole = (wrOpen, wrMiddle, wrClose);

  { a reserved word of the block structure }
  TPasWord = record
    Start, Len: Integer;          // 0-based offset in the text, length
    Line: Integer;                // 0-based
    Tok: Integer;                 // its token's index (ExpandRange's tokens)
    Role: TPasWordRole;
    Kind: TPasBlockKind;          // the block's; bkNone: a closing or middle word without block
    Opener: Integer;              // the block's opening word (an opener: itself); -1 none
    Closer: Integer;              // an opener: its closing word; -1 none (not closed)
    Head: Integer;                // an opener that is a routine's body: the heading's offset, else -1
  end;

  TPasBracket = record
    Start: Integer;
    Tok: Integer;
    Open, Square: Boolean;        // ( [ (else ) ]); [ ] (else ( ))
    Depth: Integer;               // the pairs around it (its partner has the same)
    Partner: Integer;             // the other bracket's index; -1 none
  end;

  TPasRoutine = record
    Start, Stop: Integer;         // its heading's first word (class ...) to after the body's end and ;
    Body: Integer;                // the body's opening word
    Line, LastLine: Integer;      // 0-based: its heading's first line, the line of the body's end
    Nested: Boolean;              // declared inside another routine (before that one's body)
  end;

  TPasFoldKind = (fkSection, fkUses, fkType, fkRoutine, fkStatement, fkRegion, fkConditional,
    fkComment);

  TPasFold = record
    Kind: TPasFoldKind;
    Line, LastLine: Integer;      // 0-based: its first line (it stays shown), its last line
    Nested: Boolean;              // fkRoutine: a nested routine
  end;

  TPasBlocks = class
  private
    FLength: Integer;
    FToks: TRawToks;
    function TokEnd(I: Integer): Integer;
    function WordOfTok(Tok: Integer): Integer;
    function BracketOfTok(Tok: Integer): Integer;
  public
    Words: array of TPasWord;     // in the text's order
    WordCount: Integer;
    Brackets: array of TPasBracket;
    BracketCount: Integer;
    Routines: array of TPasRoutine;
    RoutineCount: Integer;
    Folds: array of TPasFold;     // in no particular order; each over two lines at least
    FoldCount: Integer;
    { KeepTokens: the tokens stay for ExpandRange }
    constructor Create(const Text: string; KeepTokens: Boolean = False);
    destructor Destroy; override;
    { the last word that starts at Pos or before it; -1 none }
    function LastWordBefore(Pos: Integer): Integer;
    { the word that holds Pos or ends at it; -1 none }
    function WordAt(Pos: Integer): Integer;
    { the bracket that starts at Pos, else the one that ends there; -1 none }
    function BracketAt(Pos: Integer): Integer;
    { the opener of the innermost closed block around Pos (from its opening word's start to its
      closing word's end); -1 none }
    function EnclosingBlock(Pos: Integer): Integer;
    { the next larger part of the text around A..B for Expand Selection: the token, a dotted
      name, a string's text, the inside of brackets and the brackets, a statement or
      declaration, a part of a block (between its words) and the block, a routine, the whole
      text. False: there is none. Needs KeepTokens. }
    function ExpandRange(var A, B: Integer): Boolean;
  end;

implementation

const
  StatementKinds = [bkBegin, bkCase, bkTry, bkAsm, bkRepeat];
  TypeKinds = [bkRecord, bkClass, bkObject, bkInterface];
  { a block's fold: a type's (True), else a statement block's }
  BlockFoldKinds: array[Boolean] of TPasFoldKind = (fkStatement, fkType);

{ the line breaks in Len characters at P, counted as the lexer counts them (CR LF, CR, LF) }
function LineBreaks(P: PChar; Len: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  I := 0;
  while I < Len do
  begin
    if P[I] = #13 then
    begin
      Inc(Result);
      if (I + 1 < Len) and (P[I + 1] = #10) then Inc(I);
    end
    else if P[I] = #10 then
      Inc(Result);
    Inc(I);
  end;
end;

{ a compiler directive's name in capitals ($REGION 'x': REGION) }
function DirectiveName(P: PChar; Len: Integer): string;
var
  I: Integer;
begin
  Result := '';
  if P[0] = '{' then I := 2 else I := 3;    // after {$ or (*$
  while (I < Len) and (P[I] in ['A'..'Z', 'a'..'z']) do
  begin
    Result := Result + UpCase(P[I]);
    Inc(I);
  end;
end;

constructor TPasBlocks.Create(const Text: string; KeepTokens: Boolean);
var
  RT: TRawToks;
  Stack, BStack, RStack: array of Integer;
  SP, BSP, RSP, I, K: Integer;
  T: PToken;
  InIntf: Boolean;
  SecLine: Integer;                 // the open section's keyword's line; -1 none
  SecKw: TKeyword;                  // ... its keyword

  function AddFold(Kind: TPasFoldKind; Line, LastLine: Integer): Integer;
  begin
    Result := -1;
    if (Line < 0) or (LastLine <= Line) then Exit;
    if FoldCount = Length(Folds) then SetLength(Folds, FoldCount * 2 + 32);
    Result := FoldCount;
    Inc(FoldCount);
    Folds[Result].Kind := Kind;
    Folds[Result].Line := Line;
    Folds[Result].LastLine := LastLine;
    Folds[Result].Nested := False;
  end;

  { the comments and directives: their folds; then taken out of the tokens, which are the code's
    from here on }
  procedure TakeComments;
  type
    TLines = array of Integer;
  var
    I, K, Line, Last, PrevLast, RunFirst, RunLast, CondSP, RegSP: Integer;
    CondLines, RegLines: TLines;
    Name: string;
    T: PToken;

    { an opening directive's line }
    procedure Push(var Lines: TLines; var SP: Integer);
    begin
      if SP = Length(Lines) then SetLength(Lines, SP * 2 + 8);
      Lines[SP] := Line;
      Inc(SP);
    end;

    { the last opening directive's fold to the closing one's line (none without one) }
    procedure Pop(var Lines: TLines; var SP: Integer; Kind: TPasFoldKind);
    begin
      if SP = 0 then Exit;
      Dec(SP);
      AddFold(Kind, Lines[SP], Line);
    end;

  begin
    K := 0;
    PrevLast := -1;
    RunFirst := -1;
    RunLast := -2;
    CondSP := 0;
    RegSP := 0;
    for I := 0 to RT.N - 1 do
    begin
      T := @RT.T[I];
      Line := T.Line - 1;
      if T.Kind <> tkComment then
      begin
        PrevLast := Line;
        if K < I then RT.T[K] := T^;
        Inc(K);
        Continue;
      end;
      Last := Line + LineBreaks(T.Ptr, T.PLen);
      if (T.PLen >= 2) and (T.Ptr[0] = '/') and (T.Ptr[1] = '/') then
      begin
        { a line that holds only a // comment: lines of them in a row fold }
        if PrevLast < Line then
        begin
          if Line <> RunLast + 1 then
          begin
            AddFold(fkComment, RunFirst, RunLast);
            RunFirst := Line;
          end;
          RunLast := Line;
        end;
      end
      else if RT.IsDirective(I) then
      begin
        Name := DirectiveName(T.Ptr, T.PLen);
        if Name = 'REGION' then Push(RegLines, RegSP)
        else if Name = 'ENDREGION' then Pop(RegLines, RegSP, fkRegion)
        else if (Name = 'IF') or (Name = 'IFDEF') or (Name = 'IFNDEF') or (Name = 'IFOPT') then Push(CondLines, CondSP)
        else if (Name = 'ENDIF') or (Name = 'IFEND') then Pop(CondLines, CondSP, fkConditional);
      end
      else
        AddFold(fkComment, Line, Last);
      PrevLast := Last;
    end;
    AddFold(fkComment, RunFirst, RunLast);
    RT.N := K;
  end;

  { the section that begins at Line ends at the line before it }
  procedure CloseSection(Line: Integer);
  begin
    if SecLine >= 0 then AddFold(fkSection, SecLine, Line - 1);
    SecLine := -1;
  end;

  procedure OpenSection(Tok: Integer);
  begin
    CloseSection(RT.T[Tok].Line - 1);
    SecLine := RT.T[Tok].Line - 1;
    SecKw := RT.T[Tok].Keyword;
  end;

  { the uses clause at Tok to its ; (in may come in a program's) }
  procedure UsesFold(Tok: Integer);
  var
    J: Integer;
  begin
    J := Tok + 1;
    while (J < RT.N) and not RT.IsSy(J, sySemicolon) do
    begin
      if (RT.T[J].Kind = tkKeyword) and (RT.T[J].Keyword <> kwIn) then Exit;
      Inc(J);
    end;
    if J < RT.N then AddFold(fkUses, RT.T[Tok].Line - 1, RT.T[J].Line - 1);
  end;

  function AddWord(Tok: Integer; Role: TPasWordRole; Kind: TPasBlockKind; Opener: Integer): Integer;
  begin
    if WordCount = Length(Words) then SetLength(Words, WordCount * 2 + 64);
    Result := WordCount;
    Inc(WordCount);
    Words[Result].Start := RT.T[Tok].Start;
    Words[Result].Len := RT.T[Tok].Len;
    Words[Result].Line := RT.T[Tok].Line - 1;
    Words[Result].Tok := Tok;
    Words[Result].Role := Role;
    Words[Result].Kind := Kind;
    if Role = wrOpen then Opener := Result;
    Words[Result].Opener := Opener;
    Words[Result].Closer := -1;
    Words[Result].Head := -1;
  end;

  procedure Open(Tok: Integer; Kind: TPasBlockKind);
  var
    W: Integer;
  begin
    W := AddWord(Tok, wrOpen, Kind, -1);
    { the first block at the top level after a routine's heading is its body }
    if (SP = 0) and (Kind in [bkBegin, bkAsm]) and (RSP > 0) then
    begin
      Words[W].Head := RStack[RSP - 1];
      Dec(RSP);
    end;
    if SP = Length(Stack) then SetLength(Stack, SP * 2 + 16);
    Stack[SP] := W;
    Inc(SP);
  end;

  procedure AddRoutine(Opener, CloserTok: Integer);
  var
    Stop: Integer;
  begin
    if RT.IsSy(CloserTok + 1, sySemicolon) then Inc(CloserTok);
    Stop := RT.T[CloserTok].Start + RT.T[CloserTok].Len;
    if RoutineCount = Length(Routines) then SetLength(Routines, RoutineCount * 2 + 16);
    Routines[RoutineCount].Start := Words[Opener].Head;
    Routines[RoutineCount].Stop := Stop;
    Routines[RoutineCount].Body := Opener;
    Routines[RoutineCount].Line := RT.T[RT.FirstAt(Words[Opener].Head)].Line - 1;
    Routines[RoutineCount].LastLine := RT.T[CloserTok].Line - 1;
    { a heading still waiting for its body: this routine is declared inside that one }
    Routines[RoutineCount].Nested := RSP > 0;
    Inc(RoutineCount);
  end;

  procedure Close(Tok: Integer; IsUntil: Boolean);
  var
    K, O, W: Integer;
  begin
    BSP := 0;
    K := SP - 1;
    if IsUntil then
      while (K >= 0) and (Words[Stack[K]].Kind <> bkRepeat) do Dec(K)
    else
      while (K >= 0) and (Words[Stack[K]].Kind = bkRepeat) do Dec(K);
    if K < 0 then
    begin
      AddWord(Tok, wrClose, bkNone, -1);
      Exit;
    end;
    O := Stack[K];
    SP := K;
    W := AddWord(Tok, wrClose, Words[O].Kind, O);
    Words[O].Closer := W;
    if Words[O].Head >= 0 then AddRoutine(O, Tok);
  end;

  procedure Middle(Tok: Integer);
  begin
    BSP := 0;
    if (SP > 0) and (Words[Stack[SP - 1]].Kind = bkTry) then AddWord(Tok, wrMiddle, bkTry, Stack[SP - 1])
    else AddWord(Tok, wrMiddle, bkNone, -1);
  end;

  { class, object, interface after "=" (or "= packed"): a type being declared }
  function TypeStart(I: Integer): Boolean;
  begin
    Result := RT.IsSy(I - 1, syEqual) or (RT.IsKw(I - 1, kwPacked) and RT.IsSy(I - 2, syEqual));
  end;

  { a class with a body: not "class;" (forward), "class of", "class(TBase);" }
  function ClassHasBody(I: Integer): Boolean;
  var
    J, D: Integer;
  begin
    Result := False;
    J := I + 1;
    if (J >= RT.N) or RT.IsSy(J, sySemicolon) or RT.IsKw(J, kwOf) then Exit;
    Result := True;
    if not RT.IsSy(J, syLParen) then Exit;
    D := 0;
    while J < RT.N do
    begin
      if RT.IsSy(J, syLParen) then Inc(D)
      else if RT.IsSy(J, syRParen) then
      begin
        Dec(D);
        if D = 0 then
        begin
          Result := not RT.IsSy(J + 1, sySemicolon);
          Exit;
        end;
      end
      else if RT.IsSy(J, sySemicolon) or (RT.T[J].Kind = tkKeyword) then
        Exit;                                        // an ancestor list being typed
      Inc(J);
    end;
  end;

  procedure Bracket(Tok: Integer; IsOpen, Square: Boolean);
  var
    B, K, O: Integer;
  begin
    if BracketCount = Length(Brackets) then SetLength(Brackets, BracketCount * 2 + 64);
    B := BracketCount;
    Inc(BracketCount);
    Brackets[B].Start := RT.T[Tok].Start;
    Brackets[B].Tok := Tok;
    Brackets[B].Open := IsOpen;
    Brackets[B].Square := Square;
    Brackets[B].Partner := -1;
    Brackets[B].Depth := BSP;
    if IsOpen then
    begin
      if BSP = Length(BStack) then SetLength(BStack, BSP * 2 + 16);
      BStack[BSP] := B;
      Inc(BSP);
      Exit;
    end;
    { the nearest open bracket of its kind; those inside it stay unpaired }
    K := BSP - 1;
    while (K >= 0) and (Brackets[BStack[K]].Square <> Square) do Dec(K);
    if K < 0 then Exit;
    O := BStack[K];
    BSP := K;
    Brackets[B].Depth := Brackets[O].Depth;
    Brackets[B].Partner := O;
    Brackets[O].Partner := B;
  end;

begin
  inherited Create;
  FLength := Length(Text);
  RT := TRawToks.Create(Text, True);
  try
    TakeComments;
    SP := 0;
    BSP := 0;
    RSP := 0;
    InIntf := False;
    SecLine := -1;
    SecKw := kwNone;
    for I := 0 to RT.N - 1 do
    begin
      T := @RT.T[I];
      if (T.Len = 0) or T.InAsm then Continue;
      case T.Kind of
        tkKeyword:
          case T.Keyword of
            kwBegin, kwTry, kwRepeat, kwAsm:
              begin
                { a unit's begin ... end. after its implementation, no routine's body: the
                  initialization part }
                if (T.Keyword = kwBegin) and (SP = 0) and (RSP = 0) and (SecKw = kwImplementation) then
                  CloseSection(T.Line - 1);
                BSP := 0;
                case T.Keyword of
                  kwBegin: Open(I, bkBegin);
                  kwTry: Open(I, bkTry);
                  kwRepeat: Open(I, bkRepeat);
                else
                  Open(I, bkAsm);
                end;
              end;
            { a case inside a record is its variant part, which the record's end closes }
            kwCase:
              if not ((SP > 0) and (Words[Stack[SP - 1]].Kind = bkRecord)) then Open(I, bkCase);
            kwRecord: Open(I, bkRecord);
            kwClass:
              if TypeStart(I) and ClassHasBody(I) then Open(I, bkClass);
            kwObject:
              if TypeStart(I) then Open(I, bkObject);
            kwInterface, kwDispinterface:
              if TypeStart(I) then
              begin
                if not RT.IsSy(I + 1, sySemicolon) then Open(I, bkInterface);
              end
              else if (T.Keyword = kwInterface) and (SP = 0) then
              begin
                InIntf := True;                      // the unit's interface section
                OpenSection(I);
              end;
            kwExcept, kwFinally: Middle(I);
            kwEnd:
              begin
                if RT.IsSy(I + 1, syDot) then CloseSection(T.Line - 1);    // the unit's end.
                Close(I, False);
              end;
            kwUses: UsesFold(I);
            kwUntil: Close(I, True);
            kwProcedure, kwFunction, kwConstructor, kwDestructor:
              begin
                while (SP > 0) and (Words[Stack[SP - 1]].Kind in StatementKinds) do Dec(SP);
                { a routine of the unit with a body to come: not a method of a type being
                  declared, not a procedural type (= procedure, : procedure, of procedure) }
                if not InIntf and not ((SP > 0) and (Words[Stack[SP - 1]].Kind in TypeKinds)) and
                  not RT.IsSy(I - 1, syEqual) and not RT.IsSy(I - 1, syColon) and not RT.IsKw(I - 1, kwOf) then
                begin
                  BSP := 0;
                  if RT.IsKw(I - 1, kwClass) then K := RT.T[I - 1].Start else K := T.Start;
                  if RSP = Length(RStack) then SetLength(RStack, RSP * 2 + 16);
                  RStack[RSP] := K;
                  Inc(RSP);
                end;
              end;
            kwImplementation, kwInitialization, kwFinalization:
              begin
                OpenSection(I);
                SP := 0;
                BSP := 0;
                RSP := 0;
                InIntf := False;
              end;
          end;
        tkIdent:
          { a heading declared forward or external has no body here }
          if (T.Directive in [dvForward, dvExternal]) and (SP = 0) and (RSP > 0) and
            RT.IsSy(I - 1, sySemicolon) then
            Dec(RSP);
        tkSymbol:
          case T.Symbol of
            syLParen: Bracket(I, True, False);
            syLBracket: Bracket(I, True, True);
            syRParen: Bracket(I, False, False);
            syRBracket: Bracket(I, False, True);
          end;
      end;
    end;
    { a section without end. yet: to the last line of code }
    if (SecLine >= 0) and (RT.N > 0) then CloseSection(RT.T[RT.N - 1].Line);
    { the types and statement blocks, the routines from their heading }
    for I := 0 to WordCount - 1 do
      if (Words[I].Role = wrOpen) and (Words[I].Closer >= 0) then
        AddFold(BlockFoldKinds[Words[I].Kind in TypeKinds], Words[I].Line, Words[Words[I].Closer].Line);
    for I := 0 to RoutineCount - 1 do
    begin
      K := AddFold(fkRoutine, Routines[I].Line, Routines[I].LastLine);
      if K >= 0 then Folds[K].Nested := Routines[I].Nested;
    end;
  finally
    if KeepTokens then FToks := RT else RT.Free;
  end;
end;

destructor TPasBlocks.Destroy;
begin
  FToks.Free;
  inherited Destroy;
end;

function TPasBlocks.TokEnd(I: Integer): Integer;
begin
  Result := FToks.T[I].Start + FToks.T[I].Len;
end;

{ the last word that starts at Pos or before it; -1 none }
function TPasBlocks.LastWordBefore(Pos: Integer): Integer;
var
  Lo, Hi, M: Integer;
begin
  Lo := 0;
  Hi := WordCount;
  while Lo < Hi do
  begin
    M := (Lo + Hi) div 2;
    if Words[M].Start <= Pos then Lo := M + 1 else Hi := M;
  end;
  Result := Lo - 1;
end;

function TPasBlocks.WordAt(Pos: Integer): Integer;
begin
  Result := LastWordBefore(Pos);
  if (Result >= 0) and (Pos > Words[Result].Start + Words[Result].Len) then Result := -1;
end;

function TPasBlocks.BracketAt(Pos: Integer): Integer;
var
  Lo, Hi, M: Integer;
begin
  { the last bracket that starts at Pos or before it: at Pos, or at Pos - 1 }
  Lo := 0;
  Hi := BracketCount;
  while Lo < Hi do
  begin
    M := (Lo + Hi) div 2;
    if Brackets[M].Start <= Pos then Lo := M + 1 else Hi := M;
  end;
  Result := Lo - 1;
  if (Result >= 0) and (Brackets[Result].Start <> Pos) and (Brackets[Result].Start <> Pos - 1) then Result := -1;
end;

function TPasBlocks.EnclosingBlock(Pos: Integer): Integer;
var
  K, C: Integer;
begin
  { going back from Pos, the first opener whose closing word ends at Pos or after it is the
    innermost: a block that starts later and holds Pos lies inside it }
  for K := LastWordBefore(Pos) downto 0 do
    if (Words[K].Role = wrOpen) and (Words[K].Closer >= 0) then
    begin
      C := Words[K].Closer;
      if Words[C].Start + Words[C].Len >= Pos then
      begin
        Result := K;
        Exit;
      end;
    end;
  Result := -1;
end;

function TPasBlocks.WordOfTok(Tok: Integer): Integer;
var
  Lo, Hi, M: Integer;
begin
  Lo := 0;
  Hi := WordCount - 1;
  while Lo <= Hi do
  begin
    M := (Lo + Hi) div 2;
    if Words[M].Tok = Tok then
    begin
      Result := M;
      Exit;
    end;
    if Words[M].Tok < Tok then Lo := M + 1 else Hi := M - 1;
  end;
  Result := -1;
end;

function TPasBlocks.BracketOfTok(Tok: Integer): Integer;
var
  Lo, Hi, M: Integer;
begin
  Lo := 0;
  Hi := BracketCount - 1;
  while Lo <= Hi do
  begin
    M := (Lo + Hi) div 2;
    if Brackets[M].Tok = Tok then
    begin
      Result := M;
      Exit;
    end;
    if Brackets[M].Tok < Tok then Lo := M + 1 else Hi := M - 1;
  end;
  Result := -1;
end;

function TPasBlocks.ExpandRange(var A, B: Integer): Boolean;
var
  BestA, BestB, I, J, K, P, C, Q: Integer;
  T: PToken;

  { a candidate: the smallest one that holds A..B and is larger wins }
  procedure Offer(X, Y: Integer);
  begin
    if (Y > X) and (X <= A) and (Y >= B) and ((X < A) or (Y > B)) and
      ((BestA < 0) or (Y - X < BestB - BestA)) then
    begin
      BestA := X;
      BestB := Y;
    end;
  end;

  { the statements or declarations of the tokens P..Q, separated by ; - the blocks and brackets
    inside them taken whole }
  procedure Statements(P, Q: Integer);
  var
    S, K, W, Br: Integer;
  begin
    S := P;
    K := P;
    while K <= Q do
    begin
      W := WordOfTok(K);
      if (W >= 0) and (Words[W].Role = wrOpen) and (Words[W].Closer >= 0) and
        (Words[Words[W].Closer].Tok <= Q) then
        K := Words[Words[W].Closer].Tok
      else
      begin
        Br := BracketOfTok(K);
        if (Br >= 0) and Brackets[Br].Open and (Brackets[Br].Partner >= 0) and
          (Brackets[Brackets[Br].Partner].Tok <= Q) then
          K := Brackets[Brackets[Br].Partner].Tok;
      end;
      if FToks.IsSy(K, sySemicolon) or (K >= Q) then
      begin
        Offer(FToks.T[S].Start, TokEnd(K));
        S := K + 1;
      end;
      Inc(K);
    end;
  end;

  { the tokens P..Q between two words of a block: all of them, and their statements }
  procedure Inside(P, Q: Integer);
  begin
    if P > Q then Exit;
    Offer(FToks.T[P].Start, TokEnd(Q));
    Statements(P, Q);
  end;

begin
  Result := False;
  if FToks = nil then Exit;
  BestA := -1;
  BestB := -1;
  { the token at A (a caret at a word's end: that word), a string's text, a dotted name }
  I := FToks.FirstAt(A + 1) - 1;
  if (I >= 0) and (I < FToks.N) and (TokEnd(I) >= A) then
  begin
    T := @FToks.T[I];
    Offer(T.Start, TokEnd(I));
    if (T.Kind = tkString) and (T.Len >= 2) and (T.Ptr[0] = '''') and (T.Ptr[T.PLen - 1] = '''') then
      Offer(T.Start + 1, TokEnd(I) - 1);
    if T.Kind = tkIdent then
    begin
      J := I;
      while (J >= 2) and FToks.IsSy(J - 1, syDot) and (FToks.T[J - 2].Kind = tkIdent) do Dec(J, 2);
      K := I;
      while (K + 2 < FToks.N) and FToks.IsSy(K + 1, syDot) and (FToks.T[K + 2].Kind = tkIdent) do Inc(K, 2);
      Offer(FToks.T[J].Start, TokEnd(K));
    end;
  end;
  { brackets around A..B: their inside, then the brackets }
  for K := 0 to BracketCount - 1 do
    if Brackets[K].Open and (Brackets[K].Partner >= 0) and (Brackets[K].Start < A) then
    begin
      C := Brackets[K].Partner;
      if Brackets[C].Start < B then Continue;
      if Brackets[C].Tok > Brackets[K].Tok + 1 then
        Offer(FToks.T[Brackets[K].Tok + 1].Start, TokEnd(Brackets[C].Tok - 1));
      Offer(Brackets[K].Start, Brackets[C].Start + 1);
    end;
  { the blocks around A..B: each part between two of its words, then the block with its ; }
  for K := 0 to WordCount - 1 do
    if (Words[K].Role = wrOpen) and (Words[K].Closer >= 0) and (Words[K].Start <= A) then
    begin
      C := Words[K].Closer;
      Q := Words[C].Tok;
      if FToks.IsSy(Q + 1, sySemicolon) then Inc(Q);
      if TokEnd(Q) < B then Continue;
      P := K;
      for J := K + 1 to C do
        if (J = C) or ((Words[J].Role = wrMiddle) and (Words[J].Opener = K)) then
        begin
          Inside(Words[P].Tok + 1, Words[J].Tok - 1);
          P := J;
        end;
      Offer(Words[K].Start, TokEnd(Q));
    end;
  { the declarations of the text's top level }
  if FToks.N > 0 then Statements(0, FToks.N - 1);
  for K := 0 to RoutineCount - 1 do Offer(Routines[K].Start, Routines[K].Stop);
  Offer(0, FLength);
  if BestA < 0 then Exit;
  A := BestA;
  B := BestB;
  Result := True;
end;

end.
