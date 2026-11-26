{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPasCheck;

{ D7 Studio - the strict syntax check of a Delphi 7 Pascal text: its syntax errors in the
  compiler's own words, and the names its code refers to, for the checks that resolve them.
  The text is lexed with conditional compilation applied; asm blocks are skipped. Check never
  raises and always ends.

  Errors: the first one, and later ones only from a place where the parse is certainly in step
  again - a routine heading at column 1 after an 'end;' at column 1 (implementation, program),
  a section keyword at column 1 (interface), initialization / finalization at column 1. After
  such a restart an error outside a routine or a declaration section ends the check unreported:
  it may come from a nested routine taken for one of the unit. An include file that cannot be
  read ends the reporting at its place (it may declare symbols the conditions after it test).
  Code under a conditional the lexer could not evaluate ($IF Declared(...), $IFOPT) is not
  reported either.

  Names: those of the code before the first error and after each restart - not those of code
  under a conditional the lexer could not evaluate, nor those after an include file that was not
  read. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex;

type
  TPasError = record
    Start, Len: Integer;   // 0-based offset and length in the main source of the token the error is at;
                           // Len 0: a place - the end of the text, or the {$I} directive whose file holds the error
    Line, Col: Integer;    // 1-based
    Msg: string;           // dcc32's (Delphi 7) text, without "[Error] file(line): "
  end;
  TPasErrors = array of TPasError;

  { how the code uses a name: the first name of a designator, a type or a constant (nuName), a
    name after a dot (nuMember), the name after inherited (nuInherited) }
  TPasNameUse = (nuName, nuMember, nuInherited);
  TPasName = record
    Start, Len: Integer;   // in the main source; names that come from include files are not listed
    Use: TPasNameUse;
  end;
  TPasNames = array of TPasName;

  { where declarations stand: an interface section, an implementation section, a program or
    library, a routine, a class, object or interface type }
  TPasDeclPlace = (dpInterface, dpImplementation, dpProgram, dpRoutine, dpMember);
  { the structured types with members }
  TPasBodyKind = (bkClass, bkObject, bkInterface, bkDispInterface);
  TPasKeywords = set of TKeyword;
  { a step of the parse: an item of a list, a declaration of a section }
  TPasStep = procedure of object;

  TPasCheck = class
  private
    FLexer: TPasLexer;
    FToks: TTokenArray;
    FN: Integer;                 // tokens in FToks, the last one the end of the text
    FI: Integer;                 // the current token
    T: PToken;                   // FToks[FI]
    FSource: string;
    FWantNames: Boolean;
    FOnInclude: TLexIncludeEvent;
    FIncFailed: Boolean;
    FIncSkipAt: Integer;         // the first token after an include file that was not read (MaxInt: none)
    FLocal: Integer;             // the depth of routine bodies
    FDepth: Integer;             // the depth of the recursion
    FResynced: Boolean;
    FErrTok: Integer;
    FErrMsg: string;
    FCommentAt, FCommentLen: Integer;   // a comment the text ends in (-1: none)
    FReachedEnd: Boolean;
    function GetIncludeMissed: Boolean;
    procedure Tokenize(Defines: TStrings);
    function LexInclude(const IncName: string; var Text: string): Boolean;
    procedure FindOpenComment;
    procedure LineColOf(Ofs: Integer; out Line, Col: Integer);
    // tokens
    procedure SetToken(J: Integer);
    procedure Next;
    function Tk(K: Integer): PToken;
    function IsKw(K: TKeyword): Boolean;
    function IsSym(S: TSymbolId): Boolean;
    function IsDir(D: TDirective): Boolean;
    function IsIdent: Boolean;
    function SymAt(K: Integer; S: TSymbolId): Boolean;
    function IdentAt(K: Integer): Boolean;
    function Adjacent(A, B: PToken): Boolean;
    function TokText: string;
    function StringChars(out Chars: Integer): Boolean;
    function IsReal: Boolean;
    procedure CheckString;
    procedure CheckNumber;
    // errors
    function Found: string;
    procedure Fail(const Msg: string);
    procedure Expected(const What: string);
    function KeywordText(K: TKeyword): string;
    procedure ExpectKw(K: TKeyword);
    procedure ExpectSym(S: TSymbolId; const What: string);
    procedure ExpectSemicolon;
    procedure ExpectIdent;
    procedure IllegalChar(C: Char);
    procedure DirectiveError(const Msg: string);
    procedure ClauseExpected(const Clauses: string);
    function StartsStatement: Boolean;
    procedure CheckOperatorMissing;
    procedure StatementEnd(EndKw: TKeyword);
    procedure Enter;
    procedure AddName(J: Integer; Use: TPasNameUse);
    procedure AddError(From: Integer);
    procedure Recover(Place: TPasDeclPlace; Start: Integer);
    function FindResync(Place: TPasDeclPlace; From: Integer): Integer;
    function AfterEnd(J: Integer): Boolean;
    // lists and names
    procedure CommaList(Item: TPasStep);
    procedure NameRef(Use: TPasNameUse);
    procedure MemberName;
    procedure TypeRef;
    procedure DeclName;
    procedure UnitItem;
    procedure ExprItem;
    procedure RangeItem;
    procedure LabelItem;
    // the file
    procedure ParseFile;
    procedure UnitFile;
    procedure ProgramFile;
    procedure PackageFile;
    procedure FileEnd;
    procedure UsesClause;
    procedure Hints;
    procedure HintsOnly;
    // declarations
    procedure DeclList(Place: TPasDeclPlace);
    function DeclItem(Place: TPasDeclPlace): Boolean;
    procedure Section(Decl: TPasStep);
    procedure ListSection(Item: TPasStep);
    procedure ConstDecl;
    procedure ResStrDecl;
    procedure TypeDecl;
    procedure VarDecl;
    procedure ExportItem;
    procedure IdentList;
    procedure RoutineDecl(Place: TPasDeclPlace);
    procedure ResultTypeOf(Place: TPasDeclPlace);
    function IsRoutineDir: Boolean;
    procedure RoutineDirective(var HasBody: Boolean);
    procedure RoutineDirectives(var HasBody: Boolean; Member: Boolean);
    procedure ParamList(Close: TSymbolId);
    procedure ParamType;
    procedure ResultType;
    procedure TypedConstValue;
    // types
    procedure ParseType;
    procedure OrdinalType;
    procedure SubrangeOrRef;
    procedure EnumType;
    procedure EnumItem;
    procedure ArrayType;
    procedure RecordType;
    procedure FieldList(InParens: Boolean);
    procedure FieldDecl(InParens: Boolean);
    procedure VariantPart;
    procedure Heritage(Several: Boolean);
    procedure ClassType;
    procedure ObjectType;
    procedure InterfaceType;
    procedure ClassBody(Kind: TPasBodyKind);
    procedure PropertyDecl(Kind: TPasBodyKind);
    procedure Accessor;
    procedure ProcType;
    // expressions
    function IsBinOp(Rel: Boolean): Boolean;
    function OperatorType(const Left: string): string;
    procedure Expr(Rel: Boolean);
    procedure Operand;
    procedure StringTail;
    function ControlChar: Boolean;
    procedure Postfix;
    procedure ParenPostfix;
    function WidthsCall: Boolean;
    procedure ArgList(Widths: Boolean);
    procedure SetConstructor;
    // statements
    procedure StmtList(const Ends: TPasKeywords; EndKw: TKeyword);
    procedure Statement;
    procedure SimpleStatement;
    procedure ExprStatement(const Typ: string);
    procedure ValueStatement;
    procedure Compound;
    procedure IfStatement;
    procedure CaseStatement;
    procedure ElseEnd;
    procedure ForStatement;
    procedure WhileStatement;
    procedure RepeatStatement;
    procedure WithStatement;
    procedure DoPart;
    procedure TryStatement;
    procedure Handlers;
    procedure RaiseStatement;
    procedure AsmBlock;
  public
    Errors: TPasErrors;
    ErrorCount: Integer;
    Names: TPasNames;      // in source order
    NameCount: Integer;
    { checks Source (a unit, program, library or package) with conditional compilation applied
      (Defines; OnInclude reads include files, nil: an include is skipped); WantNames: fill Names }
    procedure Check(const Source: string; Defines: TStrings; OnInclude: TLexIncludeEvent; WantNames: Boolean);
    { the last check parsed up to the end of the file - else it stopped at an error, or unreported (too
      deep a nesting, an error after an include file that was not read, an error after a restart) }
    property ReachedEnd: Boolean read FReachedEnd;
    { an include file of the last check was not read: no error after its place is reported }
    property IncludeMissed: Boolean read GetIncludeMissed;
  end;

implementation

type
  { ends the part being checked; the error is in FErrTok / FErrMsg (FErrMsg '': none) }
  EPasStop = class(Exception);
  { ends the check }
  EPasEnd = class(Exception);

const
  MaxDepth = 1000;
  MsgMissingOperator = 'Missing operator or semicolon';
  { the words of a property's specifiers: never the field or method it reads or writes }
  PropertyDirs = [dvRead, dvWrite, dvStored, dvDefault, dvNodefault, dvIndex, dvImplements, dvReadonly,
    dvWriteonly, dvDispid];
  { the reserved words that begin a statement or an operand }
  StatementWords = [kwBegin, kwIf, kwCase, kwFor, kwWhile, kwRepeat, kwWith, kwTry, kwRaise, kwGoto, kwAsm,
    kwInherited, kwNil, kwNot];
  { the reserved words that begin a routine or a method }
  RoutineWords = [kwProcedure, kwFunction, kwConstructor, kwDestructor, kwClass];
  { the section keywords where the declarations of an interface go on for certain at column 1 }
  InterfaceWords = [kwType, kwConst, kwVar, kwThreadvar, kwResourcestring, kwProcedure, kwFunction,
    kwImplementation];
  BlockEnds = [kwEnd, kwUntil, kwExcept, kwFinally];
  RelSymbols = [syEqual, syNotEqual, syLess, syLessEq, syGreater, syGreaterEq];

{ TPasCheck }

procedure TPasCheck.Check(const Source: string; Defines: TStrings; OnInclude: TLexIncludeEvent;
  WantNames: Boolean);
begin
  ErrorCount := 0;
  NameCount := 0;
  FWantNames := WantNames;
  FOnInclude := OnInclude;
  FSource := Source;
  FIncSkipAt := MaxInt;
  FResynced := False;
  FLocal := 0;
  FDepth := 0;
  FCommentAt := -1;
  FReachedEnd := False;
  FN := 0;
  try
    try
      Tokenize(Defines);
      FindOpenComment;
      ParseFile;
    except
      // nothing leaves the check
    end;
  finally
    FreeAndNil(FLexer);
    FSource := '';
    FOnInclude := nil;
  end;
end;

{ every token of the text, with conditional compilation applied and the include files read; the
  lexer stays: the tokens of include files point into its copies of them }
procedure TPasCheck.Tokenize(Defines: TStrings);
begin
  FLexer := TPasLexer.Create(FSource);
  FLexer.ProcessDirectives := True;
  FLexer.AutoAsm := True;
  FLexer.AddDefines(Defines);
  FLexer.OnInclude := LexInclude;
  if Length(FToks) < 1024 then SetLength(FToks, 1024);
  repeat
    FIncFailed := False;
    FLexer.Next;
    if FIncFailed and (FIncSkipAt = MaxInt) then FIncSkipAt := FN;
    if FN >= Length(FToks) then SetLength(FToks, FN * 2);
    FToks[FN] := FLexer.Tok;
    Inc(FN);
  until FLexer.Tok.Kind = tkEOF;
end;

function TPasCheck.GetIncludeMissed: Boolean;
begin
  Result := FIncSkipAt < MaxInt;
end;

function TPasCheck.LexInclude(const IncName: string; var Text: string): Boolean;
begin
  Result := False;
  if Assigned(FOnInclude) then
    try
      Result := FOnInclude(IncName, Text);
    except
      Result := False;
    end;
  if not Result then FIncFailed := True;
end;

{ the block comment the text ends in, if any: after the last token of the main text (a line
  comment at the very end is no error) }
procedure TPasCheck.FindOpenComment;
var
  P, L, Q, J: Integer;
  C: Char;
begin
  FCommentAt := -1;
  if not FLexer.EndedInComment then Exit;
  P := 0;
  for J := FN - 2 downto 0 do
    if FToks[J].Len > 0 then
    begin
      P := FToks[J].Start + FToks[J].Len;
      Break;
    end;
  L := Length(FSource);
  while P < L do
  begin
    C := FSource[P + 1];
    if C = '{' then
    begin
      Q := P;
      while (P < L) and (FSource[P + 1] <> '}') do Inc(P);
      if P >= L then
      begin
        FCommentAt := Q;
        FCommentLen := 1;
        Exit;
      end;
      Inc(P);
    end
    else if (C = '(') and (P + 1 < L) and (FSource[P + 2] = '*') then
    begin
      Q := P;
      Inc(P, 2);
      while (P + 1 < L) and not ((FSource[P + 1] = '*') and (FSource[P + 2] = ')')) do Inc(P);
      if P + 1 >= L then
      begin
        FCommentAt := Q;
        FCommentLen := 2;
        Exit;
      end;
      Inc(P, 2);
    end
    else if (C = '/') and (P + 1 < L) and (FSource[P + 2] = '/') then
      while (P < L) and not (FSource[P + 1] in [#10, #13]) do Inc(P)
    else
      Inc(P);
  end;
end;

{ the 1-based line and column of an offset of the main text, its line breaks counted as the
  lexer counts them }
procedure TPasCheck.LineColOf(Ofs: Integer; out Line, Col: Integer);
var
  I, LineStart: Integer;
begin
  Line := 1;
  LineStart := 0;
  I := 0;
  while I < Ofs do
  begin
    if FSource[I + 1] = #13 then
    begin
      if (I + 1 < Length(FSource)) and (FSource[I + 2] = #10) then Inc(I);
      Inc(Line);
      LineStart := I + 1;
    end
    else if FSource[I + 1] = #10 then
    begin
      Inc(Line);
      LineStart := I + 1;
    end;
    Inc(I);
  end;
  Col := Ofs - LineStart + 1;
end;

{ ---- tokens ---- }

{ token J becomes the current one; a token that cannot be lexed is an error now }
procedure TPasCheck.SetToken(J: Integer);
begin
  FI := J;
  T := @FToks[J];
  if not T.InAsm then
    case T.Kind of
      tkString: CheckString;
      tkNumber: CheckNumber;
      tkSymbol:
        if T.Symbol = syOther then IllegalChar(T.Ptr^);
    end;
end;

procedure TPasCheck.Next;
begin
  if FI < FN - 1 then SetToken(FI + 1);
end;

function TPasCheck.Tk(K: Integer): PToken;
var
  J: Integer;
begin
  J := FI + K;
  if J >= FN then J := FN - 1;
  Result := @FToks[J];
end;

function TPasCheck.IsKw(K: TKeyword): Boolean;
begin
  Result := (T.Kind = tkKeyword) and (T.Keyword = K);
end;

function TPasCheck.IsSym(S: TSymbolId): Boolean;
begin
  Result := (T.Kind = tkSymbol) and (T.Symbol = S);
end;

function TPasCheck.IsDir(D: TDirective): Boolean;
begin
  Result := (T.Kind = tkIdent) and (T.Directive = D);
end;

function TPasCheck.IsIdent: Boolean;
begin
  Result := T.Kind = tkIdent;
end;

function TPasCheck.SymAt(K: Integer; S: TSymbolId): Boolean;
var
  P: PToken;
begin
  P := Tk(K);
  Result := (P.Kind = tkSymbol) and (P.Symbol = S);
end;

function TPasCheck.IdentAt(K: Integer): Boolean;
begin
  Result := Tk(K).Kind = tkIdent;
end;

{ B follows A with nothing between them (both in the main text) }
function TPasCheck.Adjacent(A, B: PToken): Boolean;
begin
  Result := (A.Len > 0) and (B.Len > 0) and (A.Start + A.Len = B.Start);
end;

function TPasCheck.TokText: string;
begin
  SetString(Result, T.Ptr, T.PLen);
end;

{ the characters of the current string constant - a quoted character or a #code each; False: a
  quoted part does not end on its line }
function TPasCheck.StringChars(out Chars: Integer): Boolean;
var
  P, E: PChar;
begin
  Result := True;
  Chars := 0;
  P := T.Ptr;
  E := P + T.PLen;
  while P < E do
    if P^ = '''' then
    begin
      Inc(P);
      repeat
        if P >= E then
        begin
          Result := False;
          Exit;
        end;
        if P^ = '''' then
        begin
          Inc(P);
          if (P >= E) or (P^ <> '''') then Break;   // the closing quote; '' is a quote
        end;
        Inc(P);
        Inc(Chars);
      until False;
    end
    else if P^ = '#' then
    begin
      Inc(P);
      if (P < E) and (P^ = '$') then
      begin
        Inc(P);
        while (P < E) and (P^ in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(P);
      end
      else
        while (P < E) and (P^ in ['0'..'9']) do Inc(P);
      Inc(Chars);
    end
    else
      Exit;
end;

{ the current number is a real constant: decimal, with a point or an exponent }
function TPasCheck.IsReal: Boolean;
var
  P, E: PChar;
begin
  Result := False;
  P := T.Ptr;
  E := P + T.PLen;
  if (P < E) and (P^ = '$') then Exit;
  while P < E do
  begin
    if P^ in ['.', 'e', 'E'] then
    begin
      Result := True;
      Exit;
    end;
    Inc(P);
  end;
end;

{ a quoted part of a string constant ends on its line; a string in double quotes is no Pascal }
procedure TPasCheck.CheckString;
var
  Chars: Integer;
begin
  if T.Ptr^ = '"' then IllegalChar('"');
  if not StringChars(Chars) then Fail('Unterminated string');
end;

{ a decimal number the letter e follows: an exponent without digits }
procedure TPasCheck.CheckNumber;
var
  N: PToken;
begin
  if T.Ptr^ = '$' then Exit;
  N := Tk(1);
  if ((N.Kind = tkIdent) or (N.Kind = tkKeyword)) and Adjacent(T, N) and (N.Ptr^ in ['e', 'E']) then
    Fail('Syntax error in real number');
end;

{ ---- errors ---- }

{ the current token as the compiler names it in its messages }
function TPasCheck.Found: string;
begin
  case T.Kind of
    tkEOF: Result := 'end of file';
    tkIdent: Result := 'identifier ''' + TokText + '''';
    tkKeyword: Result := '''' + UpperCase(TokText) + '''';
    tkNumber:
      if IsReal then Result := 'real constant' else Result := 'number';
    tkString: Result := 'string constant';
  else
    Result := '''' + TokText + '''';
  end;
end;

procedure TPasCheck.Fail(const Msg: string);
begin
  FErrTok := FI;
  FErrMsg := Msg;
  raise EPasStop.Create('');
end;

procedure TPasCheck.Expected(const What: string);
begin
  Fail(What + ' expected but ' + Found + ' found');
end;

{ a reserved word as the compiler names it: 'END' }
function TPasCheck.KeywordText(K: TKeyword): string;
begin
  Result := '''' + UpperCase(KeywordNames[K]) + '''';
end;

procedure TPasCheck.ExpectKw(K: TKeyword);
begin
  if not IsKw(K) then Expected(KeywordText(K));
  Next;
end;

procedure TPasCheck.ExpectSym(S: TSymbolId; const What: string);
begin
  if not IsSym(S) then Expected(What);
  Next;
end;

procedure TPasCheck.ExpectSemicolon;
begin
  ExpectSym(sySemicolon, ''';''');
end;

procedure TPasCheck.ExpectIdent;
begin
  if T.Kind <> tkIdent then Expected('Identifier');
  Next;
end;

procedure TPasCheck.IllegalChar(C: Char);
begin
  Fail(Format('Illegal character in input file: ''%s'' ($%X)', [C, Ord(C)]));
end;

{ the current name taken for a directive the compiler does not know; Msg says how }
procedure TPasCheck.DirectiveError(const Msg: string);
begin
  Fail(Msg + ': ''' + TokText + '''');
end;

procedure TPasCheck.ClauseExpected(const Clauses: string);
begin
  Fail(Clauses + ' clause expected, but ' + Found + ' found');
end;

function TPasCheck.StartsStatement: Boolean;
begin
  Result := (T.Kind = tkKeyword) and (T.Keyword in StatementWords);
end;

{ an operand follows an operand - a constant, or a statement or an operand that begins with a
  reserved word: the compiler misses an operator }
procedure TPasCheck.CheckOperatorMissing;
begin
  if (T.Kind = tkNumber) or (T.Kind = tkString) or StartsStatement then Fail(MsgMissingOperator);
end;

{ a statement is followed by neither ';' nor the end of its block: before a name the compiler
  misses an operator too, else it names the block's end (EndKw; kwTry: except or finally) }
procedure TPasCheck.StatementEnd(EndKw: TKeyword);
begin
  if T.Kind = tkIdent then Fail(MsgMissingOperator);
  CheckOperatorMissing;
  if EndKw = kwTry then Fail('EXCEPT or FINALLY expected');
  Expected(KeywordText(EndKw));
end;

{ one level deeper; too deep a text ends the check unreported }
procedure TPasCheck.Enter;
begin
  Inc(FDepth);
  if FDepth > MaxDepth then
  begin
    FErrTok := FI;
    FErrMsg := '';
    raise EPasStop.Create('');
  end;
end;

procedure TPasCheck.AddName(J: Integer; Use: TPasNameUse);
begin
  if not FWantNames or (FToks[J].Len = 0) or FToks[J].Uncertain or (J >= FIncSkipAt) then Exit;
  if NameCount >= Length(Names) then SetLength(Names, NameCount * 2 + 256);
  Names[NameCount].Start := FToks[J].Start;
  Names[NameCount].Len := FToks[J].Len;
  Names[NameCount].Use := Use;
  Inc(NameCount);
end;

{ the error in FErrTok / FErrMsg of the part that began at token From - not when code under a
  conditional the lexer could not evaluate came before it in the part (the compiler may take the
  other branch); at the end of the text in an unclosed comment, the comment is the error }
procedure TPasCheck.AddError(From: Integer);
var
  P: PToken;
  E: TPasError;
  J: Integer;
begin
  if (FErrMsg = '') or (FErrTok >= FIncSkipAt) then Exit;
  for J := From to FErrTok do
    if FToks[J].Uncertain then Exit;
  P := @FToks[FErrTok];
  E.Start := P.Start;
  E.Len := P.Len;
  E.Line := P.Line;
  E.Col := P.Col;
  E.Msg := FErrMsg;
  if (P.Kind = tkEOF) and (FCommentAt >= 0) then
  begin
    E.Start := FCommentAt;
    E.Len := FCommentLen;
    LineColOf(FCommentAt, E.Line, E.Col);
    E.Msg := Format('Unexpected end of file in comment started on line %d', [E.Line]);
  end;
  if ErrorCount >= Length(Errors) then SetLength(Errors, ErrorCount + 8);
  Errors[ErrorCount] := E;
  Inc(ErrorCount);
end;

{ after an error in a declaration of Place that began at token Start: the error recorded and the
  parse moved on to the next place where it is in step again - else the check ends }
procedure TPasCheck.Recover(Place: TPasDeclPlace; Start: Integer);
var
  J: Integer;
begin
  FLocal := 0;
  FDepth := 0;
  if (FErrMsg = '') or (FErrTok >= FIncSkipAt) then raise EPasEnd.Create('');
  AddError(Start);
  J := FErrTok;
  if J <= Start then J := Start + 1;
  J := FindResync(Place, J);
  if J < 0 then raise EPasEnd.Create('');
  SetToken(J);
  FResynced := True;
end;

{ token J follows an 'end;' whose end stands at column 1 }
function TPasCheck.AfterEnd(J: Integer): Boolean;
begin
  Result := (J >= 2) and (FToks[J - 1].Kind = tkSymbol) and (FToks[J - 1].Symbol = sySemicolon) and
    (FToks[J - 2].Kind = tkKeyword) and (FToks[J - 2].Keyword = kwEnd) and (FToks[J - 2].Col = 1) and
    (FToks[J - 2].Len > 0);
end;

{ the next place from token From on where the declarations of Place go on for certain (-1: none) }
function TPasCheck.FindResync(Place: TPasDeclPlace; From: Integer): Integer;
var
  J: Integer;
begin
  for J := From to FN - 1 do
    with FToks[J] do
      if (Kind = tkKeyword) and (Col = 1) and (Len > 0) then
        if Place = dpInterface then
        begin
          if Keyword in InterfaceWords then
          begin
            Result := J;
            Exit;
          end;
        end
        else if ((Place = dpImplementation) and (Keyword in [kwInitialization, kwFinalization])) or
          ((Keyword in RoutineWords) and AfterEnd(J)) then
        begin
          Result := J;
          Exit;
        end;
  Result := -1;
end;

{ ---- lists and names ---- }

{ items separated by commas }
procedure TPasCheck.CommaList(Item: TPasStep);
begin
  repeat
    Item;
    if not IsSym(syComma) then Exit;
    Next;
  until False;
end;

{ an identifier the code names, listed with Use }
procedure TPasCheck.NameRef(Use: TPasNameUse);
begin
  if T.Kind <> tkIdent then Expected('Identifier');
  AddName(FI, Use);
  Next;
end;

{ the name after a dot: a member - or string, as in System.String }
procedure TPasCheck.MemberName;
begin
  if IsKw(kwString) then Next else NameRef(nuMember);
end;

{ a type named by an identifier, qualified or not }
procedure TPasCheck.TypeRef;
begin
  NameRef(nuName);
  while IsSym(syDot) do
  begin
    Next;
    MemberName;
  end;
end;

{ the name a heading declares: an identifier, dotted names accepted }
procedure TPasCheck.DeclName;
begin
  ExpectIdent;
  while IsSym(syDot) do
  begin
    Next;
    ExpectIdent;
  end;
end;

{ a unit of a uses or contains clause, with its file }
procedure TPasCheck.UnitItem;
begin
  DeclName;
  if IsKw(kwIn) then
  begin
    Next;
    if T.Kind <> tkString then Expected('string constant');
    Next;
  end;
end;

procedure TPasCheck.ExprItem;
begin
  Expr(True);
end;

{ a value or a range of values: a case label, a variant's label, a set's element }
procedure TPasCheck.RangeItem;
begin
  Expr(True);
  if IsSym(syDotDot) then
  begin
    Next;
    Expr(True);
  end;
end;

{ a label: a name or a number }
procedure TPasCheck.LabelItem;
begin
  if (T.Kind <> tkIdent) and (T.Kind <> tkNumber) then Expected('Identifier or number');
  Next;
end;

{ ---- the file ---- }

procedure TPasCheck.ParseFile;
begin
  try
    SetToken(0);
    if IsKw(kwUnit) then
      UnitFile
    else if IsDir(dvPackage) and IdentAt(1) then
      PackageFile
    else
      ProgramFile;
    FReachedEnd := True;
  except
    on EPasStop do
      if not FResynced then AddError(0);
    on EPasEnd do ;
  end;
end;

procedure TPasCheck.UnitFile;
begin
  Next;
  DeclName;
  Hints;
  ExpectSemicolon;
  ExpectKw(kwInterface);
  if IsKw(kwUses) then UsesClause;
  DeclList(dpInterface);
  // the compiler passes over an 'end' here
  if IsKw(kwEnd) then Next;
  ExpectKw(kwImplementation);
  if IsKw(kwUses) then UsesClause;
  DeclList(dpImplementation);
  if IsKw(kwBegin) then
  begin
    Next;
    StmtList([kwEnd], kwEnd);
  end
  else
  begin
    if IsKw(kwInitialization) then
    begin
      Next;
      StmtList([kwFinalization, kwEnd], kwEnd);
    end;
    if IsKw(kwFinalization) then
    begin
      Next;
      StmtList([kwEnd], kwEnd);
    end;
  end;
  FileEnd;
end;

procedure TPasCheck.ProgramFile;
begin
  if IsKw(kwProgram) or IsKw(kwLibrary) then
  begin
    Next;
    DeclName;
    if IsSym(syLParen) then
    begin
      Next;
      CommaList(ExpectIdent);
      ExpectSym(syRParen, ''')''');
    end;
    Hints;
    ExpectSemicolon;
  end;
  if IsKw(kwUses) then UsesClause;
  DeclList(dpProgram);
  if IsKw(kwBegin) then
  begin
    Next;
    StmtList([kwEnd], kwEnd);
  end;
  FileEnd;
end;

procedure TPasCheck.PackageFile;
begin
  Next;
  DeclName;
  ExpectSemicolon;
  if IsDir(dvRequires) then ListSection(DeclName);
  if IsDir(dvContains) then ListSection(UnitItem);
  FileEnd;
end;

{ the 'end.' of a file: what follows it is not read }
procedure TPasCheck.FileEnd;
begin
  ExpectKw(kwEnd);
  if not IsSym(syDot) then Expected('''.''');
end;

procedure TPasCheck.UsesClause;
begin
  Next;
  CommaList(UnitItem);
  if not IsSym(sySemicolon) then Expected(''','' or '';''');
  Next;
end;

{ platform, deprecated, library after a declaration }
procedure TPasCheck.Hints;
begin
  while IsDir(dvPlatform) or IsDir(dvDeprecated) or IsKw(kwLibrary) do Next;
end;

{ the hints after a variable, a field or a structured type: the compiler takes another name
  there for a directive }
procedure TPasCheck.HintsOnly;
begin
  Hints;
  if T.Kind = tkIdent then DirectiveError('Invalid compiler directive');
end;

{ ---- declarations ---- }

{ the declarations of a section or of a program; each one that fails is recorded and the parse
  goes on where it is in step again }
procedure TPasCheck.DeclList(Place: TPasDeclPlace);
var
  Start: Integer;
  Done: Boolean;
begin
  Done := False;
  repeat
    Start := FI;
    try
      if not DeclItem(Place) then
        if Place = dpInterface then
        begin
          if IsKw(kwImplementation) or IsKw(kwEnd) or (T.Kind = tkEOF) then
            Done := True
          else
            Expected('Declaration');
        end
        else if IsKw(kwBegin) or IsKw(kwEnd) or
          ((Place = dpImplementation) and (IsKw(kwInitialization) or IsKw(kwFinalization))) then
          Done := True
        else
          Expected('Declaration');
    except
      on EPasStop do Recover(Place, Start);
    end;
  until Done;
end;

{ one section or routine; False: the current token begins none }
function TPasCheck.DeclItem(Place: TPasDeclPlace): Boolean;
begin
  Result := (T.Kind = tkKeyword) and not ((Place = dpInterface) and
    (T.Keyword in [kwLabel, kwConstructor, kwDestructor, kwClass, kwExports]));
  if not Result then Exit;
  case T.Keyword of
    kwConst: Section(ConstDecl);
    kwResourcestring: Section(ResStrDecl);
    kwType: Section(TypeDecl);
    kwVar, kwThreadvar: Section(VarDecl);
    kwProcedure, kwFunction, kwConstructor, kwDestructor, kwClass: RoutineDecl(Place);
    kwLabel: ListSection(LabelItem);
    kwExports: ListSection(ExportItem);
  else
    Result := False;
  end;
end;

{ a section of declarations, each one ended by ';' }
procedure TPasCheck.Section(Decl: TPasStep);
begin
  Next;
  repeat
    Decl;
    ExpectSemicolon;
  until not IsIdent;
end;

{ a word, a list of items and ';' }
procedure TPasCheck.ListSection(Item: TPasStep);
begin
  Next;
  CommaList(Item);
  ExpectSemicolon;
end;

{ a constant: Name = Value, or Name: Type = Value }
procedure TPasCheck.ConstDecl;
begin
  if not SymAt(1, syColon) then
  begin
    ResStrDecl;
    Exit;
  end;
  ExpectIdent;
  Next;
  ParseType;
  ExpectSym(syEqual, '''=''');
  TypedConstValue;
  Hints;
end;

procedure TPasCheck.ResStrDecl;
begin
  ExpectIdent;
  ExpectSym(syEqual, '''=''');
  Expr(True);
  Hints;
end;

procedure TPasCheck.TypeDecl;
begin
  ExpectIdent;
  ExpectSym(syEqual, '''=''');
  if IsKw(kwType) then Next;
  ParseType;
  if (FToks[FI - 1].Kind = tkKeyword) and (FToks[FI - 1].Keyword = kwEnd) then HintsOnly else Hints;
end;

procedure TPasCheck.VarDecl;
begin
  IdentList;
  ParseType;
  Hints;
  if IsDir(dvAbsolute) then
  begin
    Next;
    Expr(True);
  end
  else if IsSym(syEqual) then
  begin
    Next;
    TypedConstValue;
  end;
  HintsOnly;
end;

procedure TPasCheck.ExportItem;
begin
  TypeRef;
  if IsSym(syLParen) then ParamList(syRParen);
  while IsDir(dvName) or IsDir(dvIndex) or IsDir(dvResident) do
    if IsDir(dvResident) then
      Next
    else
    begin
      Next;
      Expr(True);
    end;
end;

{ the names of a variable, a field or a parameter group, and its colon }
procedure TPasCheck.IdentList;
begin
  CommaList(ExpectIdent);
  if not IsSym(syColon) then Expected(''','' or '':''');
  Next;
end;

{ a routine or a method: its heading, its directives and - in an implementation, a program or a
  routine, unless forward or external - its body; in a class (dpMember) also a method resolution
  clause 'procedure IFoo.Bar = Baz;' }
procedure TPasCheck.RoutineDecl(Place: TPasDeclPlace);
var
  IsFunc, HasBody: Boolean;
begin
  Enter;
  if IsKw(kwClass) then
  begin
    Next;
    if not (IsKw(kwProcedure) or IsKw(kwFunction)) then Fail('PROCEDURE or FUNCTION expected');
  end;
  IsFunc := IsKw(kwFunction);
  Next;
  if T.Kind <> tkIdent then Expected('Identifier');
  if (Place <> dpInterface) and SymAt(1, syDot) then
  begin
    // the class or interface is named, the method is declared
    AddName(FI, nuName);
    Next;
    if Place = dpMember then
    begin
      Next;
      ExpectIdent;
      ExpectSym(syEqual, '''=''');
      ExpectIdent;
      ExpectSemicolon;
      Dec(FDepth);
      Exit;
    end;
    while IsSym(syDot) do
    begin
      Next;
      ExpectIdent;
    end;
  end
  else
    Next;
  if IsSym(syLParen) then ParamList(syRParen);
  if IsFunc then
    ResultTypeOf(Place)
  else if IsSym(syColon) then
    Fail('Procedure cannot have a result type');
  HasBody := Place in [dpImplementation, dpProgram, dpRoutine];
  RoutineDirectives(HasBody, Place = dpMember);
  if HasBody then
  begin
    Inc(FLocal);
    while DeclItem(dpRoutine) do ;
    if IsKw(kwAsm) then
      AsmBlock
    else if IsKw(kwBegin) then
      Compound
    else if IsKw(kwEnd) then
    begin
      // the compiler names the end, at the token after it
      Next;
      Fail('BEGIN expected but END found');
    end
    else
      Expected('Declaration');
    Dec(FLocal);
    ExpectSemicolon;
  end;
  Dec(FDepth);
end;

{ a function's ': Type'; only an implementation may leave it out (the declaration has it) }
procedure TPasCheck.ResultTypeOf(Place: TPasDeclPlace);
begin
  if IsSym(syColon) then
  begin
    Next;
    ResultType;
  end
  else if (Place in [dpInterface, dpMember]) or not (IsSym(sySemicolon) or IsRoutineDir) then
    Fail('Function needs result type');
end;

function TPasCheck.IsRoutineDir: Boolean;
begin
  Result := ((T.Kind = tkIdent) and (T.Directive in RoutineDirs)) or IsKw(kwLibrary);
end;

procedure TPasCheck.RoutineDirective(var HasBody: Boolean);
begin
  if T.Kind = tkKeyword then
  begin
    Next;
    Exit;
  end;
  case T.Directive of
    dvExternal:
      begin
        HasBody := False;
        Next;
        if not (IsSym(sySemicolon) or IsDir(dvName) or IsDir(dvIndex)) then Expr(True);
        while IsDir(dvName) or IsDir(dvIndex) do
        begin
          Next;
          Expr(True);
        end;
      end;
    dvForward:
      begin
        HasBody := False;
        Next;
      end;
    dvMessage, dvDispid:
      begin
        Next;
        Expr(True);
      end;
  else
    Next;
  end;
end;

{ the ';' that ends a heading and the directives after it, each with its ';' - which the compiler
  does not ask for after the last directive of a routine, only of a method (Member); a directive
  without one before the next is accepted. Before the heading's ';' only a calling convention. }
procedure TPasCheck.RoutineDirectives(var HasBody: Boolean; Member: Boolean);
begin
  while T.Kind = tkIdent do
    if T.Directive in CallConvDirs then Next else DirectiveError('Unknown directive');
  ExpectSemicolon;
  // after the ';' a routine takes any name for a directive; a method's is a field
  if not Member and (T.Kind = tkIdent) and not IsRoutineDir then DirectiveError('Unknown directive');
  while IsRoutineDir do
  begin
    RoutineDirective(HasBody);
    if IsSym(sySemicolon) then
      Next
    else if Member and not IsRoutineDir then
      ExpectSemicolon;
  end;
end;

procedure TPasCheck.ParamList(Close: TSymbolId);
var
  Modified: Boolean;
begin
  Next;
  if IsSym(Close) then
  begin
    Next;
    Exit;
  end;
  repeat
    Modified := IsKw(kwVar) or IsKw(kwConst) or (IsDir(dvOut) and IdentAt(1));
    if Modified then Next;
    CommaList(ExpectIdent);
    if IsSym(syColon) then
    begin
      Next;
      ParamType;
      if IsSym(syEqual) then
      begin
        Next;
        Expr(True);
      end;
    end
    else if not Modified then
      Fail('Missing parameter type');
    if not IsSym(sySemicolon) then Break;
    Next;
  until False;
  if not IsSym(Close) then
    if Close = syRParen then Expected(''';'', '')'' or ''=''') else Expected(''';'', '']'' or ''=''');
  Next;
end;

procedure TPasCheck.ParamType;
begin
  if IsKw(kwArray) then
  begin
    Next;
    ExpectKw(kwOf);
    if IsKw(kwConst) then
    begin
      Next;
      Exit;
    end;
  end;
  if IsKw(kwString) or IsKw(kwFile) then Next else TypeRef;
end;

procedure TPasCheck.ResultType;
begin
  if IsKw(kwString) then Next else TypeRef;
end;

{ the value of a typed constant or an initialised variable: an expression, a record's fields
  '(Name: Value; ...)' or an array's elements '(Value, ...)' }
procedure TPasCheck.TypedConstValue;
begin
  Enter;
  if not IsSym(syLParen) then
    Expr(True)
  else if IdentAt(1) and SymAt(2, syColon) then
  begin
    Next;
    repeat
      if IsSym(syRParen) then Break;
      ExpectIdent;
      ExpectSym(syColon, ''':''');
      TypedConstValue;
      if not IsSym(sySemicolon) then Break;
      Next;
    until False;
    ExpectSym(syRParen, ''')''');
  end
  else
  begin
    Next;
    if not IsSym(syRParen) then CommaList(TypedConstValue);
    ExpectSym(syRParen, ''')''');
    // a value in parentheses may go on as an expression: (1 + 2) * 3
    Postfix;
    while IsBinOp(True) do
    begin
      Next;
      Operand;
    end;
  end;
  Dec(FDepth);
end;

{ ---- types ---- }

procedure TPasCheck.ParseType;
begin
  Enter;
  case T.Kind of
    tkKeyword:
      case T.Keyword of
        kwPacked:
          begin
            Next;
            if (T.Kind = tkKeyword) and (T.Keyword in [kwArray, kwRecord, kwObject, kwClass, kwSet, kwFile]) then
              ParseType
            else
              Fail('PACKED not allowed here');
          end;
        kwArray: ArrayType;
        kwSet:
          begin
            Next;
            ExpectKw(kwOf);
            OrdinalType;
          end;
        kwFile:
          begin
            Next;
            if IsKw(kwOf) then
            begin
              Next;
              ParseType;
            end;
          end;
        kwRecord: RecordType;
        kwClass: ClassType;
        kwObject: ObjectType;
        kwInterface, kwDispinterface: InterfaceType;
        kwProcedure, kwFunction: ProcType;
        kwString:
          begin
            Next;
            if IsSym(syLBracket) then
            begin
              Next;
              Expr(True);
              ExpectSym(syRBracket, ''']''');
            end;
          end;
        kwNot, kwNil, kwInherited:
          SubrangeOrRef;
      else
        Expected('Type');
      end;
    tkSymbol:
      case T.Symbol of
        syLParen: EnumType;
        syCaret:
          begin
            Next;
            ResultType;
          end;
        syMinus, syPlus, syAt, syLBracket:
          SubrangeOrRef;
      else
        Expected('Type');
      end;
    tkIdent, tkNumber, tkString:
      SubrangeOrRef;
  else
    Expected('Type');
  end;
  Dec(FDepth);
end;

{ an index or element type of arrays and sets }
procedure TPasCheck.OrdinalType;
begin
  if IsSym(syLParen) then EnumType else ParseType;
end;

{ a type named by an identifier, or a subrange 'Low .. High' of constant expressions }
procedure TPasCheck.SubrangeOrRef;
var
  A, J: Integer;
  Simple: Boolean;
begin
  A := FI;
  Expr(False);
  if IsSym(syDotDot) then
  begin
    Next;
    Expr(False);
  end
  else
  begin
    // identifiers separated by dots name a type
    Simple := (FI > A) and ((FI - A) mod 2 = 1);
    J := A;
    while Simple and (J < FI) do
    begin
      if (J - A) mod 2 = 0 then
        Simple := (FToks[J].Kind = tkIdent) or ((J > A) and (FToks[J].Kind = tkKeyword) and (FToks[J].Keyword = kwString))
      else
        Simple := (FToks[J].Kind = tkSymbol) and (FToks[J].Symbol = syDot);
      Inc(J);
    end;
    if not Simple then Expected('''..''');
  end;
end;

procedure TPasCheck.EnumType;
begin
  Next;
  CommaList(EnumItem);
  ExpectSym(syRParen, ''','' or '')''');
end;

procedure TPasCheck.EnumItem;
begin
  ExpectIdent;
  if IsSym(syEqual) then
  begin
    Next;
    Expr(False);
  end;
end;

procedure TPasCheck.ArrayType;
begin
  Next;
  if IsSym(syLBracket) then
  begin
    Next;
    CommaList(OrdinalType);
    ExpectSym(syRBracket, ''']''');
  end;
  ExpectKw(kwOf);
  if IsKw(kwConst) then Next else ParseType;
end;

procedure TPasCheck.RecordType;
begin
  Next;
  FieldList(False);
  ExpectKw(kwEnd);
end;

{ the fields of a record, or of a variant in parentheses, and its variant part }
procedure TPasCheck.FieldList(InParens: Boolean);
begin
  while T.Kind = tkIdent do FieldDecl(InParens);
  if IsKw(kwCase) then VariantPart;
end;

{ a field's names and type, and its ';' - which the last one before 'end', 'case' or the ')' of a
  variant (InParens) may leave out }
procedure TPasCheck.FieldDecl(InParens: Boolean);
begin
  IdentList;
  ParseType;
  HintsOnly;
  if IsSym(sySemicolon) then
    Next
  else if not (IsKw(kwEnd) or IsKw(kwCase) or (InParens and IsSym(syRParen))) then
    Expected(''';''');
end;

procedure TPasCheck.VariantPart;
begin
  Enter;
  Next;
  if IsIdent and SymAt(1, syColon) then
  begin
    Next;
    Next;
  end;
  TypeRef;
  ExpectKw(kwOf);
  repeat
    CommaList(RangeItem);
    ExpectSym(syColon, ''':''');
    ExpectSym(syLParen, '''(''');
    FieldList(True);
    ExpectSym(syRParen, ''')''');
    if IsSym(sySemicolon) then Next;
  until IsKw(kwEnd) or IsSym(syRParen) or (T.Kind = tkEOF);
  Dec(FDepth);
end;

{ the ancestor in parentheses - a class's interfaces too (Several) }
procedure TPasCheck.Heritage(Several: Boolean);
begin
  Next;
  if Several then CommaList(TypeRef) else TypeRef;
  ExpectSym(syRParen, ''')''');
end;

procedure TPasCheck.ClassType;
begin
  Next;
  if IsKw(kwOf) then
  begin
    Next;
    TypeRef;
    Exit;
  end;
  if IsSym(sySemicolon) then Exit;   // a forward declaration
  if IsSym(syLParen) then
  begin
    Heritage(True);
    if IsSym(sySemicolon) then Exit;   // TFoo = class(TBar);
  end;
  ClassBody(bkClass);
end;

procedure TPasCheck.ObjectType;
begin
  Next;
  if IsSym(syLParen) then Heritage(False);
  ClassBody(bkObject);
end;

procedure TPasCheck.InterfaceType;
var
  Kind: TPasBodyKind;
begin
  if IsKw(kwDispinterface) then Kind := bkDispInterface else Kind := bkInterface;
  Next;
  if IsSym(sySemicolon) then Exit;   // a forward declaration
  if IsSym(syLParen) then Heritage(False);
  if IsSym(syLBracket) then
  begin
    Next;
    Expr(True);
    ExpectSym(syRBracket, ''']''');
  end;
  ClassBody(Kind);
end;

{ the members of a class, object or interface and their end; in a visibility section the fields
  come first }
procedure TPasCheck.ClassBody(Kind: TPasBodyKind);
var
  Methods: Boolean;
begin
  Methods := False;
  while not IsKw(kwEnd) do
    if (Kind in [bkClass, bkObject]) and (T.Kind = tkIdent) and (T.Directive in VisibilityDirs) and
      not (SymAt(1, syColon) or SymAt(1, syComma)) then
    begin
      Next;
      Methods := False;
    end
    else if (T.Kind = tkKeyword) and (T.Keyword in RoutineWords) then
    begin
      RoutineDecl(dpMember);
      Methods := True;
    end
    else if IsKw(kwProperty) then
    begin
      PropertyDecl(Kind);
      Methods := True;
    end
    else if (T.Kind = tkIdent) and (Kind in [bkClass, bkObject]) then
    begin
      if Methods then Fail('Field definition not allowed after methods or properties');
      FieldDecl(False);
    end
    else
      Expected('''END''');
  Next;
end;

procedure TPasCheck.PropertyDecl(Kind: TPasBodyKind);
var
  Typed: Boolean;
  Access: Integer;
begin
  Next;
  ExpectIdent;
  if IsSym(syLBracket) then ParamList(syRBracket);
  Typed := IsSym(syColon);
  if Typed then
  begin
    Next;
    ResultType;
  end;
  Access := 0;
  repeat
    if T.Kind = tkIdent then
      case T.Directive of
        dvIndex:
          begin
            Next;
            Expr(True);
            Inc(Access);
          end;
        dvRead, dvWrite:
          begin
            Next;
            Accessor;
            Inc(Access);
          end;
        dvStored, dvDefault, dvDispid:
          begin
            Next;
            Expr(True);
          end;
        dvNodefault, dvReadonly, dvWriteonly, dvPlatform, dvDeprecated:
          Next;
        dvImplements:
          begin
            Next;
            CommaList(TypeRef);
          end;
      else
        Break;
      end
    else if IsKw(kwLibrary) then
      Next
    else
      Break;
  until False;
  if Typed and (Access = 0) then
    if Kind = bkInterface then
      ClauseExpected('READ or WRITE')
    else if Kind <> bkDispInterface then
      ClauseExpected('INDEX, READ or WRITE');
  ExpectSemicolon;
  // an array property's 'default;'
  if IsDir(dvDefault) and SymAt(1, sySemicolon) then
  begin
    Next;
    Next;
  end;
end;

{ the field or method a property reads or writes }
procedure TPasCheck.Accessor;
begin
  if (T.Kind <> tkIdent) or (T.Directive in PropertyDirs) then
  begin
    // a ';' the compiler passes first
    if IsSym(sySemicolon) then Next;
    Fail('Field or method identifier expected');
  end;
  TypeRef;
end;

{ a procedural type, its calling convention with or without a ';' before it }
procedure TPasCheck.ProcType;
var
  IsFunc: Boolean;
  N: PToken;
begin
  IsFunc := IsKw(kwFunction);
  Next;
  if IsSym(syLParen) then ParamList(syRParen);
  if IsFunc then
  begin
    ExpectSym(syColon, ''':''');
    ResultType;
  end;
  if IsKw(kwOf) then
  begin
    Next;
    ExpectKw(kwObject);
  end;
  repeat
    if (T.Kind = tkIdent) and (T.Directive in CallConvDirs) then
      Next
    else if IsSym(sySemicolon) then
    begin
      N := Tk(1);
      if (N.Kind = tkIdent) and (N.Directive in CallConvDirs) and
        not (SymAt(2, syColon) or SymAt(2, syComma)) then
        Next
      else
        Break;
    end
    else
      Break;
  until False;
end;

{ ---- expressions ---- }

{ a binary operator; Rel: also the relational ones }
function TPasCheck.IsBinOp(Rel: Boolean): Boolean;
begin
  case T.Kind of
    tkSymbol:
      Result := (T.Symbol in [syPlus, syMinus, syStar, sySlash]) or Rel and (T.Symbol in RelSymbols);
    tkKeyword:
      Result := (T.Keyword in [kwAnd, kwOr, kwXor, kwDiv, kwMod, kwShl, kwShr, kwAs]) or
        Rel and (T.Keyword in [kwIn, kwIs]);
  else
    Result := False;
  end;
end;

{ the type the current operator gives for operands of the usual types, the left one of type Left
  ('': not known) }
function TPasCheck.OperatorType(const Left: string): string;
begin
  if (Left = 'Boolean') or ((T.Kind = tkKeyword) and (T.Keyword in [kwIn, kwIs, kwAnd, kwOr, kwXor])) or
    ((T.Kind = tkSymbol) and (T.Symbol in RelSymbols)) then
    Result := 'Boolean'
  else if IsSym(sySlash) then
    Result := 'Extended'
  else if IsSym(syPlus) and ((Left = 'Char') or (Left = 'String')) then
    Result := 'String'
  else if IsKw(kwAs) or ((Left = 'Extended') and (IsSym(syPlus) or IsSym(syMinus) or IsSym(syStar))) then
    Result := Left
  else
    Result := 'Integer';
end;

{ operands joined by operators (the precedence does not change what is valid); Rel: the
  relational operators too - not in a type, where '=' follows a typed constant's type }
procedure TPasCheck.Expr(Rel: Boolean);
begin
  Operand;
  while IsBinOp(Rel) do
  begin
    Next;
    Operand;
  end;
  CheckOperatorMissing;
end;

procedure TPasCheck.Operand;
begin
  Enter;
  case T.Kind of
    tkNumber:
      Next;
    tkString:
      begin
        Next;
        StringTail;
      end;
    tkIdent:
      begin
        NameRef(nuName);
        Postfix;
      end;
    tkKeyword:
      case T.Keyword of
        kwNil:
          Next;
        kwNot:
          begin
            Next;
            Operand;
          end;
        kwInherited:
          begin
            Next;
            if T.Kind = tkIdent then NameRef(nuInherited);
            Postfix;
          end;
        kwString, kwFile:
          begin
            Next;
            Postfix;
          end;
      else
        Expected('Expression');
      end;
    tkSymbol:
      case T.Symbol of
        syLParen:
          begin
            Next;
            Expr(True);
            ExpectSym(syRParen, ''')''');
            ParenPostfix;
          end;
        syLBracket:
          SetConstructor;
        syAt:
          begin
            Next;
            if IsSym(syAt) then Next;
            Operand;
          end;
        syMinus, syPlus:
          begin
            Next;
            Operand;
          end;
        syCaret:
          if ControlChar then StringTail else Expected('Expression');
      else
        Expected('Expression');
      end;
  else
    Expected('Expression');
  end;
  Dec(FDepth);
end;

{ the control characters (^M) and string parts that continue a string constant }
procedure TPasCheck.StringTail;
begin
  repeat
    if IsSym(syCaret) and (FI > 0) and Adjacent(@FToks[FI - 1], T) then
    begin
      if not ControlChar then Break;
    end
    else if (T.Kind = tkString) and (FI > 0) and Adjacent(@FToks[FI - 1], T) then
      Next
    else
      Break;
  until False;
end;

{ ^ and the character after it - any one, a blank too - are a character constant (^M, ^[); a
  word after ^ is the character and a name after it. False: no character follows on the line }
function TPasCheck.ControlChar: Boolean;
var
  N: PToken;
begin
  Result := False;
  if (T.Len = 0) or (T.Start + 2 > Length(FSource)) or (FSource[T.Start + 2] in [#10, #13]) then Exit;
  Result := True;
  N := Tk(1);
  if FSource[T.Start + 2] in [' ', #9] then
    Next
  else if (N.Len > 0) and (N.Start = T.Start + 1) then
  begin
    Next;
    if N.PLen > 1 then Fail(MsgMissingOperator);
    Next;
  end
  else
    Result := False;
end;

{ what follows a designator: members, indexes, dereferences, calls }
procedure TPasCheck.Postfix;
begin
  repeat
    if T.Kind <> tkSymbol then Exit;
    case T.Symbol of
      syDot:
        begin
          Next;
          MemberName;
        end;
      syLBracket:
        begin
          Next;
          CommaList(ExprItem);
          ExpectSym(syRBracket, ''']''');
        end;
      syCaret:
        Next;
      syLParen:
        ArgList(WidthsCall);
    else
      Exit;
    end;
  until False;
end;

{ what follows an expression in parentheses: members, indexes, dereferences - no arguments: the
  compiler takes the parentheses after it for another operand }
procedure TPasCheck.ParenPostfix;
begin
  if IsSym(syLParen) then Fail(MsgMissingOperator);
  Postfix;
end;

{ the arguments at hand are those of Write, Writeln or Str, the routines whose arguments may have
  field widths (X:10:2) }
function TPasCheck.WidthsCall: Boolean;
var
  P: PToken;
begin
  P := @FToks[FI - 1];
  Result := (P.Kind = tkIdent) and (SameTextP(P.Ptr, P.PLen, 'WRITE') or SameTextP(P.Ptr, P.PLen, 'WRITELN') or
    SameTextP(P.Ptr, P.PLen, 'STR'));
end;

{ a call's arguments: named ones of dispatch calls (Name := Value), field widths (X:10:2) when
  Widths }
procedure TPasCheck.ArgList(Widths: Boolean);
begin
  Next;
  if IsSym(syRParen) then
  begin
    Next;
    Exit;
  end;
  repeat
    if IsIdent and SymAt(1, syAssign) then
    begin
      Next;
      Next;
    end;
    Expr(True);
    if Widths and IsSym(syColon) then
    begin
      Next;
      Expr(True);
      if IsSym(syColon) then
      begin
        Next;
        Expr(True);
      end;
    end;
    if not IsSym(syComma) then Break;
    Next;
  until False;
  ExpectSym(syRParen, ''')''');
end;

procedure TPasCheck.SetConstructor;
begin
  Next;
  if not IsSym(syRBracket) then CommaList(RangeItem);
  ExpectSym(syRBracket, ''']''');
end;

{ ---- statements ---- }

{ statements separated by ';' up to one of Ends; EndKw: the block's end the compiler names
  instead of another one }
procedure TPasCheck.StmtList(const Ends: TPasKeywords; EndKw: TKeyword);
begin
  repeat
    if (T.Kind = tkKeyword) and (T.Keyword in Ends) then Exit;
    if IsKw(kwElse) and (FI > 0) and (FToks[FI - 1].Kind = tkSymbol) and (FToks[FI - 1].Symbol = sySemicolon) then
      Fail(''';'' not allowed before ''ELSE''');
    Statement;
    if IsSym(sySemicolon) then
      Next
    else if (T.Kind = tkKeyword) and (T.Keyword in Ends) then
      Exit
    else
      StatementEnd(EndKw);
  until False;
end;

procedure TPasCheck.Statement;
begin
  Enter;
  case T.Kind of
    tkIdent, tkNumber:
      if SymAt(1, syColon) then
      begin
        // a label
        Next;
        Next;
        Statement;
      end
      else if T.Kind = tkIdent then
        SimpleStatement
      else
        ValueStatement;
    tkString:
      ValueStatement;
    tkKeyword:
      case T.Keyword of
        kwBegin: Compound;
        kwIf: IfStatement;
        kwCase: CaseStatement;
        kwFor: ForStatement;
        kwWhile: WhileStatement;
        kwRepeat: RepeatStatement;
        kwWith: WithStatement;
        kwTry: TryStatement;
        kwRaise: RaiseStatement;
        kwGoto:
          begin
            Next;
            LabelItem;
          end;
        kwAsm: AsmBlock;
        kwInherited, kwString: SimpleStatement;
        kwNot, kwNil: ValueStatement;
        kwEnd, kwElse, kwUntil, kwExcept, kwFinally: ;   // an empty statement
      else
        Expected('Statement');
      end;
    tkSymbol:
      case T.Symbol of
        sySemicolon: ;
        syLParen, syAt: SimpleStatement;
      else
        Expected('Statement');
      end;
  end;
  Dec(FDepth);
end;

{ an assignment or a call: a designator, then ':=' and an expression or nothing }
procedure TPasCheck.SimpleStatement;
begin
  Operand;
  if IsSym(syAssign) then
  begin
    Next;
    Expr(True);
  end
  else if IsSym(syEqual) or IsSym(syColon) then
    Expected(''':=''')
  else if IsBinOp(True) then
    ExprStatement('');
end;

{ an expression where a statement belongs, its first operand parsed (Typ: its type, '' not known):
  the compiler names the expression's type at its end }
procedure TPasCheck.ExprStatement(const Typ: string);
var
  R: string;
begin
  R := Typ;
  while IsBinOp(True) do
  begin
    R := OperatorType(R);
    Next;
    Operand;
  end;
  CheckOperatorMissing;
  if R = '' then R := 'Integer';
  Fail('Statement expected, but expression of type ''' + R + ''' found');
end;

{ an expression where a statement belongs that begins with a constant, not or nil }
procedure TPasCheck.ValueStatement;
var
  Typ: string;
  Chars: Integer;
begin
  case T.Kind of
    tkNumber:
      if IsReal then Typ := 'Extended' else Typ := 'Integer';
    tkString:
      begin
        StringChars(Chars);
        if Chars = 1 then Typ := 'Char' else Typ := 'String';
      end;
  else
    if IsKw(kwNot) then Typ := 'Boolean' else Typ := 'Pointer';
  end;
  Operand;
  ExprStatement(Typ);
end;

procedure TPasCheck.Compound;
begin
  Next;
  StmtList([kwEnd], kwEnd);
  Next;
end;

{ if ... then ... else if ...: the chain of else-ifs without recursion }
procedure TPasCheck.IfStatement;
begin
  repeat
    Next;
    Expr(True);
    if not IsKw(kwThen) then Expected('''THEN''');
    Next;
    if not IsKw(kwElse) then Statement;
    if not IsKw(kwElse) then Exit;
    Next;
    if not IsKw(kwIf) then
    begin
      Statement;
      Exit;
    end;
  until False;
end;

procedure TPasCheck.CaseStatement;
begin
  Next;
  Expr(True);
  if not IsKw(kwOf) then Expected('''OF''');
  Next;
  repeat
    CommaList(RangeItem);
    if not IsSym(syColon) then Expected(''','' or '':''');
    Next;
    Statement;
    if not IsSym(sySemicolon) then Break;
    Next;
  until IsKw(kwElse) or IsKw(kwEnd);
  ElseEnd;
  Next;
end;

{ the else part of a case statement or of exception handlers, and the end it comes to }
procedure TPasCheck.ElseEnd;
begin
  if IsKw(kwElse) then
  begin
    Next;
    StmtList([kwEnd], kwEnd);
  end;
  if not IsKw(kwEnd) then StatementEnd(kwEnd);
end;

procedure TPasCheck.ForStatement;
begin
  Next;
  if T.Kind = tkNumber then Fail('For loop control variable must be simple local variable');
  NameRef(nuName);
  ExpectSym(syAssign, ''':=''');
  Expr(True);
  if not (IsKw(kwTo) or IsKw(kwDownto)) then Expected('''TO''');
  Next;
  Expr(True);
  DoPart;
end;

procedure TPasCheck.WhileStatement;
begin
  Next;
  Expr(True);
  DoPart;
end;

procedure TPasCheck.RepeatStatement;
begin
  Next;
  StmtList([kwUntil], kwUntil);
  Next;
  Expr(True);
end;

procedure TPasCheck.WithStatement;
begin
  Next;
  CommaList(ExprItem);
  DoPart;
end;

{ 'do' and the statement after it }
procedure TPasCheck.DoPart;
begin
  if not IsKw(kwDo) then Expected('''DO''');
  Next;
  Statement;
end;

procedure TPasCheck.TryStatement;
var
  IsExcept: Boolean;
begin
  Next;
  StmtList([kwExcept, kwFinally], kwTry);
  IsExcept := IsKw(kwExcept);
  Next;
  if IsExcept and IsDir(dvOn) and IdentAt(1) then Handlers else StmtList([kwEnd], kwEnd);
  ExpectKw(kwEnd);
end;

{ the exception handlers 'on [E:] T do Statement' and their else part }
procedure TPasCheck.Handlers;
begin
  repeat
    if not (IsDir(dvOn) and IdentAt(1)) then Expected('''END''');
    Next;
    if IsIdent and SymAt(1, syColon) then
    begin
      Next;
      Next;
    end;
    TypeRef;
    DoPart;
    if not IsSym(sySemicolon) then Break;
    Next;
  until IsKw(kwElse) or IsKw(kwEnd);
  ElseEnd;
end;

procedure TPasCheck.RaiseStatement;
begin
  Next;
  if IsSym(sySemicolon) or (T.Kind = tkEOF) or ((T.Kind = tkKeyword) and (T.Keyword in BlockEnds + [kwElse])) then
    Exit;
  Expr(True);
  if IsDir(dvAt) then
  begin
    Next;
    Expr(True);
  end;
end;

{ asm ... end: the assembler is not checked }
procedure TPasCheck.AsmBlock;
begin
  Next;
  while T.InAsm and (T.Kind <> tkEOF) do Next;
  ExpectKw(kwEnd);
end;

end.
