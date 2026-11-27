{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPasLex;

// D7 Studio - Delphi 7 Pascal tokenizer.
// Allocation-free scanning, conditional compilation ($IFDEF .. $IF),
// include files, optional comment tokens (raw mode for source editing).

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes;

type
  TTokenKind = (tkEOF, tkIdent, tkKeyword, tkNumber, tkString, tkSymbol, tkComment);

  TKeyword = (kwNone,
    kwAnd, kwArray, kwAs, kwAsm, kwBegin, kwCase, kwClass, kwConst,
    kwConstructor, kwDestructor, kwDispinterface, kwDiv, kwDo, kwDownto,
    kwElse, kwEnd, kwExcept, kwExports, kwFile, kwFinalization, kwFinally,
    kwFor, kwFunction, kwGoto, kwIf, kwImplementation, kwIn, kwInherited,
    kwInitialization, kwInline, kwInterface, kwIs, kwLabel, kwLibrary, kwMod,
    kwNil, kwNot, kwObject, kwOf, kwOr, kwPacked, kwProcedure, kwProgram,
    kwProperty, kwRaise, kwRecord, kwRepeat, kwResourcestring, kwSet, kwShl,
    kwShr, kwString, kwThen, kwThreadvar, kwTo, kwTry, kwType, kwUnit,
    kwUntil, kwUses, kwVar, kwWhile, kwWith, kwXor);

  TDirective = (dvNone,
    dvAbsolute, dvAbstract, dvAssembler, dvAt, dvAutomated, dvCdecl,
    dvContains, dvDefault, dvDeprecated, dvDispid, dvDynamic, dvExport,
    dvExternal, dvFar, dvForward, dvImplements, dvIndex, dvLocal, dvMessage,
    dvName, dvNear, dvNodefault, dvOn, dvOut, dvOverload, dvOverride,
    dvPackage, dvPascal, dvPlatform, dvPrivate, dvProtected, dvPublic,
    dvPublished, dvRead, dvReadonly, dvRegister, dvReintroduce, dvRequires,
    dvResident, dvSafecall, dvStdcall, dvStored, dvVarargs, dvVirtual,
    dvWrite, dvWriteonly);

const
  { the directives of a routine's heading, its calling conventions, a class's visibilities }
  RoutineDirs = [dvAbstract, dvAssembler, dvCdecl, dvDeprecated, dvDispid, dvDynamic, dvExport,
    dvExternal, dvFar, dvForward, dvLocal, dvMessage, dvNear, dvOverload, dvOverride, dvPascal,
    dvPlatform, dvRegister, dvReintroduce, dvSafecall, dvStdcall, dvVarargs, dvVirtual];
  CallConvDirs = [dvCdecl, dvPascal, dvRegister, dvSafecall, dvStdcall, dvVarargs, dvFar, dvNear,
    dvExport];
  VisibilityDirs = [dvPrivate, dvProtected, dvPublic, dvPublished, dvAutomated];

type
  TSymbolId =(syNone, syLParen, syRParen, syLBracket, syRBracket, syDot,
    syDotDot, syComma, sySemicolon, syColon, syAssign, syEqual, syNotEqual,
    syLess, syLessEq, syGreater, syGreaterEq, syPlus, syMinus, syStar,
    sySlash, syCaret, syAt, syOther);

  PToken = ^TToken;
  TToken = record
    Kind: TTokenKind;
    Keyword: TKeyword;
    Directive: TDirective;
    Symbol: TSymbolId;
    InAsm: Boolean;      // inside an asm block (not its asm / end): lexed in AsmMode
    Uncertain: Boolean;  // under a conditional whose condition was not known: a $IF of what the lexer
                         // cannot evaluate (taken as true), a $IFOPT (taken as false)
    Start: Integer;      // 0-based offset into the main source
    Len: Integer;        // length in the main source (0 for tokens coming from an include file)
    Line: Integer;       // 1-based
    Col: Integer;        // 1-based
    Ptr: PChar;          // token text
    PLen: Integer;       // token text length
  end;
  TTokenArray = array of TToken;

  TLexIncludeEvent = function(const IncName: string; var Text: string): Boolean of object;

  TCondState = record
    ParentActive: Boolean;
    Active: Boolean;
    Taken: Boolean;
    Uncertain: Boolean;  // its condition, or an enclosing one, was not known
  end;

  TIncState = record
    Source: string;
    Pos, EndPos, Line, LineStart: Integer;
  end;

  TPasLexer = class
  private
    FSource: string;
    FBuf: PChar;
    FBase: Integer;
    FPos: Integer;
    FEnd: Integer;
    FLine: Integer;
    FLineStart: Integer;
    FHasPeek: Boolean;
    FPeek: TToken;
    FDefines: TStringList;
    FCond: array of TCondState;
    FCondCount: Integer;
    FUnknown: Boolean;           // the last EvalIf met what it cannot evaluate
    FSkipping: Boolean;
    FProcessDirectives: Boolean;
    FReturnComments: Boolean;
    FAsmMode: Boolean;
    FAutoAsm: Boolean;
    FInComment: Boolean;
    FInString: Boolean;
    FOnInclude: TLexIncludeEvent;
    FIncStack: array of TIncState;
    FIncDepth: Integer;
    FIncKeep: array of string;
    FIncStart, FIncLine, FIncCol: Integer;
    FDirStart, FDirLine, FDirCol: Integer;
    procedure Scan(var T: TToken);
    procedure LineBreak(var P: Integer);
    function SkipComment(var P: Integer; Paren: Boolean): Boolean;
    procedure SkipInactive;
    function Defines: TStringList;
    procedure HandleDirective(BodyStart, BodyEnd: Integer);
    procedure PushCond(Cond: Boolean);
    procedure PopCond;
    procedure DoElse;
    procedure DoElseIf(const Expr: string);
    procedure DoInclude(ArgStart, ArgEnd: Integer);
    procedure PopInclude;
    function IsDefined(const S: string): Boolean;
    function EvalIf(const S: string): Boolean;
    function DirArg(ArgStart, ArgEnd: Integer): string;
  public
    Tok: TToken;
    { Lexes ASource[AStart..AEnd) (0-based offsets; AEnd < 0 = to the end).
      Token offsets are always relative to the start of ASource. }
    constructor Create(const ASource: string; AStart: Integer = 0; AEnd: Integer = -1);
    destructor Destroy; override;
    procedure SetStartLineCol(ALine, ACol: Integer);
    procedure Next;
    function Peek: PToken;
    function TokenText: string;
    function TokenIs(const UpperS: string): Boolean;
    procedure AddDefine(const S: string);
    procedure AddDefines(List: TStrings);
    property ProcessDirectives: Boolean read FProcessDirectives write FProcessDirectives;
    property ReturnComments: Boolean read FReturnComments write FReturnComments;
    property AsmMode: Boolean read FAsmMode write FAsmMode;
    { the reserved word asm sets AsmMode, end clears it (the one rule of every token array) }
    property AutoAsm: Boolean read FAutoAsm write FAutoAsm;
    property EndedInComment: Boolean read FInComment;
    property EndedInString: Boolean read FInString;
    property OnInclude: TLexIncludeEvent read FOnInclude write FOnInclude;
  end;

  { A text's tokens in an array. Create: every token of ASrc as source editing sees it -
    conditional compilation not applied (a directive is a comment token), asm blocks lexed as
    assembler (AutoAsm), comments only with Comments. Take: appends the tokens of a lexer the
    caller set up, to its end or to the first token that starts at Limit or after (taken too);
    False once the lexer is at its end. }
  TRawToks = class
  public
    Src: string;
    T: TTokenArray;
    N: Integer;
    constructor Create(const ASrc: string; Comments: Boolean = True);
    function Take(L: TPasLexer; Limit: Integer = MaxInt): Boolean;
    function Txt(I: Integer): string;
    function IsId(I: Integer; const S: string): Boolean;
    function IsSy(I: Integer; S: TSymbolId): Boolean;
    function IsKw(I: Integer; K: TKeyword): Boolean;
    function IsIdent(I: Integer): Boolean;
    function IsDirective(I: Integer): Boolean;
    function NextCode(I: Integer): Integer;
    function EndOf(I: Integer): Integer;
    function FirstAt(Ofs: Integer): Integer;
    function IndexAt(Ofs: Integer): Integer;
    { the token that closes the bracket ( or [ at I (-1: none) }
    function MatchClose(I: Integer): Integer;
    { the argument whose first token is I: the token of the called routine's name and the
      argument's index; False - I begins no argument of a call }
    function ArgumentOf(I: Integer; out NameTok, ArgIdx: Integer): Boolean;
  end;

const
  KeywordNames: array[TKeyword] of string = ('',
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library', 'mod',
    'nil', 'not', 'object', 'of', 'or', 'packed', 'procedure', 'program',
    'property', 'raise', 'record', 'repeat', 'resourcestring', 'set', 'shl',
    'shr', 'string', 'then', 'threadvar', 'to', 'try', 'type', 'unit',
    'until', 'uses', 'var', 'while', 'with', 'xor');

var
  UpTab: array[Char] of Char;
  IdentTab: array[Char] of Boolean;

function HashUpper(P: PChar; Len: Integer): Cardinal;
function SameTextP(P: PChar; Len: Integer; const S: string): Boolean;
{ the line end of a text - its first one: CRLF, LF or a lone CR; CRLF when it has none (what an
  insertion into the text uses, so that a file keeps its own line ends) }
function DetectEOL(const S: string): string;
{ the lines of a text by offset (0-based): the start of the line Ofs lies in, the end of that line
  (before its line break), the start of the line after it (the text's end on the last line) }
function LineStartOf(const S: string; Ofs: Integer): Integer;
function LineEndOf(const S: string; Ofs: Integer): Integer;
function NextLineStart(const S: string; Ofs: Integer): Integer;
{ the start of the line before the one that begins at LS (0 on the first line) }
function PrevLineStart(const S: string; LS: Integer): Integer;
{ the identifier at Pos of S (0-based; in it or at its end): its offsets A .. E (E excluded); False:
  none there }
function IdentRangeAt(const S: string; Pos: Integer; out A, E: Integer): Boolean;
{ the white space that begins the line of Ofs }
function IndentAt(const S: string; Ofs: Integer): string;
{ nothing but white space (line breaks too) in A .. B (B excluded) }
function IsBlank(const S: string; A, B: Integer): Boolean;
{ only white space between the start of Ofs's line and Ofs }
function FirstOnLine(const S: string; Ofs: Integer): Boolean;
{ only white space - and a // comment - between Ofs and the end of its line }
function LastOnLine(const S: string; Ofs: Integer): Boolean;
{ A .. B widened to whole lines - from the start of A's line to the start of the line after B's -
  when nothing else stands on them (a // comment after B goes with them); False: left as it is }
function WholeLines(const S: string; var A, B: Integer): Boolean;

implementation

const
  DirectiveNames: array[TDirective] of string = ('',
    'absolute', 'abstract', 'assembler', 'at', 'automated', 'cdecl',
    'contains', 'default', 'deprecated', 'dispid', 'dynamic', 'export',
    'external', 'far', 'forward', 'implements', 'index', 'local', 'message',
    'name', 'near', 'nodefault', 'on', 'out', 'overload', 'override',
    'package', 'pascal', 'platform', 'private', 'protected', 'public',
    'published', 'read', 'readonly', 'register', 'reintroduce', 'requires',
    'resident', 'safecall', 'stdcall', 'stored', 'varargs', 'virtual',
    'write', 'writeonly');

  WordTabSize = 512;

type
  TWordEntry = record
    Name: string;
    Kw: TKeyword;
    Dv: TDirective;
  end;

var
  WordTab: array[0..WordTabSize - 1] of TWordEntry;

function HashUpper(P: PChar; Len: Integer): Cardinal;
var
  I: Integer;
begin
  Result := Cardinal(Len);
  for I := 0 to Len - 1 do
    Result := Result * 31 + Ord(UpTab[P[I]]);
end;

function SameTextP(P: PChar; Len: Integer; const S: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Len <> Length(S) then Exit;
  for I := 0 to Len - 1 do
    if UpTab[P[I]] <> UpTab[S[I + 1]] then Exit;
  Result := True;
end;

function DetectEOL(const S: string): string;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if S[I] = #13 then
    begin
      if (I < Length(S)) and (S[I + 1] = #10) then Result := #13#10 else Result := #13;
      Exit;
    end
    else if S[I] = #10 then
    begin
      Result := #10;
      Exit;
    end;
  Result := #13#10;
end;

function LineStartOf(const S: string; Ofs: Integer): Integer;
begin
  Result := Ofs;
  if Result > Length(S) then Result := Length(S);
  while (Result > 0) and not (S[Result] in [#10, #13]) do Dec(Result);
end;

function LineEndOf(const S: string; Ofs: Integer): Integer;
begin
  Result := Ofs;
  while (Result < Length(S)) and not (S[Result + 1] in [#10, #13]) do Inc(Result);
end;

function IdentRangeAt(const S: string; Pos: Integer; out A, E: Integer): Boolean;
begin
  if Pos < 0 then Pos := 0;
  if Pos > Length(S) then Pos := Length(S);
  E := Pos;
  while (E < Length(S)) and IdentTab[S[E + 1]] do Inc(E);
  A := Pos;
  while (A > 0) and IdentTab[S[A]] do Dec(A);
  Result := (A < E) and not (S[A + 1] in ['0'..'9']);
end;

function NextLineStart(const S: string; Ofs: Integer): Integer;
begin
  Result := LineEndOf(S, Ofs);
  if Result < Length(S) then
  begin
    if (S[Result + 1] = #13) and (Result + 1 < Length(S)) and (S[Result + 2] = #10) then Inc(Result, 2)
    else Inc(Result);
  end;
end;

function PrevLineStart(const S: string; LS: Integer): Integer;
var
  P: Integer;
begin
  { from the line break before LS - from its CR when it is a CR LF - back to its line's start }
  P := LS - 1;
  if (P > 0) and (P < Length(S)) and (S[P + 1] = #10) and (S[P] = #13) then Dec(P);
  if P < 0 then P := 0;
  Result := LineStartOf(S, P);
end;

function IndentAt(const S: string; Ofs: Integer): string;
var
  P, Q: Integer;
begin
  P := LineStartOf(S, Ofs);
  Q := P;
  while (Q < Length(S)) and (S[Q + 1] in [' ', #9]) do Inc(Q);
  Result := Copy(S, P + 1, Q - P);
end;

function IsBlank(const S: string; A, B: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if B > Length(S) then B := Length(S);
  for I := A + 1 to B do
    if S[I] > ' ' then Exit;
  Result := True;
end;

function FirstOnLine(const S: string; Ofs: Integer): Boolean;
begin
  Result := IsBlank(S, LineStartOf(S, Ofs), Ofs);
end;

function LastOnLine(const S: string; Ofs: Integer): Boolean;
var
  E: Integer;
begin
  E := LineEndOf(S, Ofs);
  while (Ofs < E) and (S[Ofs + 1] <= ' ') do Inc(Ofs);
  Result := (Ofs >= E) or ((Ofs + 1 < E) and (S[Ofs + 1] = '/') and (S[Ofs + 2] = '/'));
end;

function WholeLines(const S: string; var A, B: Integer): Boolean;
begin
  Result := FirstOnLine(S, A) and LastOnLine(S, B);
  if Result then
  begin
    A := LineStartOf(S, A);
    B := NextLineStart(S, B);
  end;
end;

procedure AddWord(const S: string; Kw: TKeyword; Dv: TDirective);
var
  H: Cardinal;
  U: string;
begin
  U := UpperCase(S);
  H := HashUpper(PChar(U), Length(U)) and (WordTabSize - 1);
  while WordTab[H].Name <> '' do
    H := (H + 1) and (WordTabSize - 1);
  WordTab[H].Name := U;
  WordTab[H].Kw := Kw;
  WordTab[H].Dv := Dv;
end;

procedure LookupWord(P: PChar; Len: Integer; var Kw: TKeyword; var Dv: TDirective);
var
  H: Cardinal;
  I: Integer;
  N: PChar;
begin
  if (Len < 2) or (Len > 14) then Exit;
  H := HashUpper(P, Len) and (WordTabSize - 1);
  while True do
  begin
    N := Pointer(WordTab[H].Name);
    if N = nil then Exit;
    if PInteger(N - 4)^ = Len then
    begin
      I := 0;
      while (I < Len) and (UpTab[P[I]] = N[I]) do Inc(I);
      if I = Len then
      begin
        Kw := WordTab[H].Kw;
        Dv := WordTab[H].Dv;
        Exit;
      end;
    end;
    H := (H + 1) and (WordTabSize - 1);
  end;
end;

procedure InitTables;
var
  C: Char;
  K: TKeyword;
  D: TDirective;
begin
  for C := Low(Char) to High(Char) do
  begin
    UpTab[C] := C;
    IdentTab[C] := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
  end;
  for C := 'a' to 'z' do
    UpTab[C] := Chr(Ord(C) - 32);
  for K := Succ(kwNone) to High(TKeyword) do
    AddWord(KeywordNames[K], K, dvNone);
  for D := Succ(dvNone) to High(TDirective) do
    AddWord(DirectiveNames[D], kwNone, D);
end;

{ the length of a UTF-8 byte order mark at the start of a text (0 = none) }
function BOMLength(B: PChar; Len: Integer): Integer;
begin
  if (Len >= 3) and (B[0] = #$EF) and (B[1] = #$BB) and (B[2] = #$BF) then Result := 3 else Result := 0;
end;

{ TPasLexer }

constructor TPasLexer.Create(const ASource: string; AStart: Integer; AEnd: Integer);
begin
  inherited Create;
  if (AEnd < 0) or (AEnd > Length(ASource)) then AEnd := Length(ASource);
  if AStart < 0 then AStart := 0;
  if AStart > AEnd then AStart := AEnd;
  FLine := 1;
  if AEnd = Length(ASource) then
  begin
    { to the end: the text itself (its terminating #0 ends the lexing), no copy }
    FSource := ASource;
    FBase := 0;
    FPos := AStart;
  end
  else
  begin
    FSource := Copy(ASource, AStart + 1, AEnd - AStart);
    FBase := AStart;
    FPos := 0;
  end;
  FBuf := PChar(FSource);
  FEnd := Length(FSource);
  { columns count from AStart (SetStartLineCol sets the real ones) }
  FLineStart := FPos;
  // tolerate a UTF-8 byte order mark at the very start of a file
  if AStart = 0 then FPos := BOMLength(FBuf, FEnd);
  FProcessDirectives := True;
  Tok.Kind := tkEOF;
  Tok.Ptr := FBuf;
end;

destructor TPasLexer.Destroy;
begin
  FDefines.Free;
  inherited Destroy;
end;

{ the defined symbols: the compiler's own (Delphi 7 on Windows) and those added - made at their
  first use, as a lexer that does not process directives needs none }
function TPasLexer.Defines: TStringList;
begin
  if FDefines = nil then
  begin
    FDefines := TStringList.Create;
    FDefines.Sorted := True;
    FDefines.Duplicates := dupIgnore;
    FDefines.Add('MSWINDOWS');
    FDefines.Add('WIN32');
    FDefines.Add('VER150');
    FDefines.Add('CPU386');
    FDefines.Add('CONDITIONALEXPRESSIONS');
  end;
  Result := FDefines;
end;

procedure TPasLexer.SetStartLineCol(ALine, ACol: Integer);
begin
  FLine := ALine;
  FLineStart := FPos - (ACol - 1);
end;

procedure TPasLexer.AddDefine(const S: string);
begin
  if S <> '' then Defines.Add(UpperCase(S));
end;

procedure TPasLexer.AddDefines(List: TStrings);
var
  I: Integer;
begin
  if List = nil then Exit;
  for I := 0 to List.Count - 1 do
    AddDefine(Trim(List[I]));
end;

procedure TPasLexer.Next;
begin
  if FHasPeek then
  begin
    Tok := FPeek;
    FHasPeek := False;
  end
  else
    Scan(Tok);
end;

function TPasLexer.Peek: PToken;
begin
  if not FHasPeek then
  begin
    Scan(FPeek);
    FHasPeek := True;
  end;
  Result := @FPeek;
end;

function TPasLexer.TokenText: string;
begin
  SetString(Result, Tok.Ptr, Tok.PLen);
end;

function TPasLexer.TokenIs(const UpperS: string): Boolean;
begin
  Result := SameTextP(Tok.Ptr, Tok.PLen, UpperS);
end;

function TPasLexer.IsDefined(const S: string): Boolean;
var
  I: Integer;
begin
  Result := Defines.Find(UpperCase(S), I);
end;

procedure TPasLexer.PushCond(Cond: Boolean);
begin
  if FCondCount >= Length(FCond) then SetLength(FCond, FCondCount + 16);
  with FCond[FCondCount] do
  begin
    ParentActive := not FSkipping;
    Active := ParentActive and Cond;
    Taken := Active or not ParentActive;
    Uncertain := (FCondCount > 0) and FCond[FCondCount - 1].Uncertain;
  end;
  FSkipping := not FCond[FCondCount].Active;
  Inc(FCondCount);
end;

procedure TPasLexer.PopCond;
begin
  if FCondCount = 0 then Exit;
  Dec(FCondCount);
  FSkipping := not FCond[FCondCount].ParentActive;
end;

procedure TPasLexer.DoElse;
begin
  if FCondCount = 0 then
  begin
    // unmatched $ELSE: lexing started inside the taken branch -> skip to $ENDIF
    if FCondCount >= Length(FCond) then SetLength(FCond, FCondCount + 16);
    FCond[0].ParentActive := True;
    FCond[0].Active := False;
    FCond[0].Taken := True;
    FCond[0].Uncertain := False;
    FCondCount := 1;
    FSkipping := True;
    Exit;
  end;
  with FCond[FCondCount - 1] do
  begin
    Active := ParentActive and not Taken;
    Taken := True;
    FSkipping := not Active;
  end;
end;

procedure TPasLexer.DoElseIf(const Expr: string);
begin
  if FCondCount = 0 then
  begin
    DoElse;
    Exit;
  end;
  with FCond[FCondCount - 1] do
  begin
    if ParentActive and not Taken then
    begin
      Active := EvalIf(Expr);
      Taken := Active;
      if FUnknown then Uncertain := True;
    end
    else
      Active := False;
    FSkipping := not Active;
  end;
end;

function TPasLexer.DirArg(ArgStart, ArgEnd: Integer): string;
begin
  if ArgEnd > ArgStart then
    SetString(Result, FBuf + ArgStart, ArgEnd - ArgStart)
  else
    Result := '';
  Result := Trim(Result);
end;

function TPasLexer.EvalIf(const S: string): Boolean;
type
  TV = record
    IsNum: Boolean;
    B: Boolean;
    N: Extended;
  end;
var
  U: string;
  P: Integer;
  Unknown: Boolean;
  Guard: Integer;

  procedure SkipWS;
  begin
    while (P <= Length(U)) and (U[P] <= ' ') do Inc(P);
  end;

  function PeekWord: string;
  var
    Q: Integer;
  begin
    SkipWS;
    Q := P;
    while (Q <= Length(U)) and (U[Q] in ['A'..'Z', '0'..'9', '_']) do Inc(Q);
    Result := Copy(U, P, Q - P);
  end;

  function ParseExpr: TV; forward;

  function ParenArg: string;
  var
    Q: Integer;
  begin
    Result := '';
    SkipWS;
    if (P <= Length(U)) and (U[P] = '(') then
    begin
      Inc(P);
      Q := P;
      while (Q <= Length(U)) and (U[Q] <> ')') do Inc(Q);
      Result := Trim(Copy(U, P, Q - P));
      P := Q + 1;
    end;
  end;

  function ParsePrimary: TV;
  var
    W: string;
    Q: Integer;
    Frac: Extended;
  begin
    Result.IsNum := False;
    Result.B := True;
    Result.N := 0;
    Inc(Guard);
    if Guard > 200 then begin Unknown := True; P := Length(U) + 1; Exit; end;
    SkipWS;
    if P > Length(U) then begin Unknown := True; Exit; end;
    if U[P] = '(' then
    begin
      Inc(P);
      Result := ParseExpr;
      SkipWS;
      if (P <= Length(U)) and (U[P] = ')') then Inc(P);
    end
    else if U[P] in ['0'..'9'] then
    begin
      Result.IsNum := True;
      while (P <= Length(U)) and (U[P] in ['0'..'9']) do
      begin
        Result.N := Result.N * 10 + (Ord(U[P]) - 48);
        Inc(P);
      end;
      if (P <= Length(U)) and (U[P] = '.') then
      begin
        Inc(P);
        Frac := 0.1;
        while (P <= Length(U)) and (U[P] in ['0'..'9']) do
        begin
          Result.N := Result.N + (Ord(U[P]) - 48) * Frac;
          Frac := Frac / 10;
          Inc(P);
        end;
      end;
    end
    else if U[P] in ['A'..'Z', '_'] then
    begin
      W := PeekWord;
      Inc(P, Length(W));
      if W = 'DEFINED' then
        Result.B := IsDefined(ParenArg)
      else if W = 'DECLARED' then
      begin
        ParenArg;
        Unknown := True;
      end
      else if (W = 'COMPILERVERSION') or (W = 'RTLVERSION') then
      begin
        Result.IsNum := True;
        Result.N := 15.0;
      end
      else if W = 'TRUE' then
        Result.B := True
      else if W = 'FALSE' then
        Result.B := False
      else
      begin
        Unknown := True;
        SkipWS;
        if (P <= Length(U)) and (U[P] = '(') then
        begin
          Q := 0;
          while P <= Length(U) do
          begin
            if U[P] = '(' then Inc(Q)
            else if U[P] = ')' then
            begin
              Dec(Q);
              if Q = 0 then begin Inc(P); Break; end;
            end;
            Inc(P);
          end;
        end;
      end;
    end
    else
    begin
      Unknown := True;
      Inc(P);
    end;
  end;

  function ParseFactor: TV;
  begin
    if PeekWord = 'NOT' then
    begin
      Inc(P, 3);
      Result := ParseFactor;
      Result.B := not Result.B;
    end
    else
      Result := ParsePrimary;
  end;

  function ParseTerm: TV;
  var
    R: TV;
  begin
    Result := ParseFactor;
    while PeekWord = 'AND' do
    begin
      Inc(P, 3);
      R := ParseFactor;
      Result.B := Result.B and R.B;
      Result.IsNum := False;
    end;
  end;

  function ParseSimple: TV;
  var
    R: TV;
    W: string;
  begin
    Result := ParseTerm;
    while True do
    begin
      W := PeekWord;
      if (W <> 'OR') and (W <> 'XOR') then Break;
      Inc(P, Length(W));
      R := ParseTerm;
      if W = 'OR' then Result.B := Result.B or R.B
      else Result.B := Result.B xor R.B;
      Result.IsNum := False;
    end;
  end;

  function ParseExpr: TV;
  var
    R: TV;
    Op: string;
  begin
    Result := ParseSimple;
    SkipWS;
    if (P <= Length(U)) and (U[P] in ['=', '<', '>']) then
    begin
      Op := U[P];
      Inc(P);
      if (P <= Length(U)) and (U[P] in ['=', '>']) then
      begin
        Op := Op + U[P];
        Inc(P);
      end;
      R := ParseSimple;
      if Result.IsNum and R.IsNum then
      begin
        if Op = '=' then Result.B := Result.N = R.N
        else if Op = '<>' then Result.B := Result.N <> R.N
        else if Op = '<' then Result.B := Result.N < R.N
        else if Op = '<=' then Result.B := Result.N <= R.N
        else if Op = '>' then Result.B := Result.N > R.N
        else if Op = '>=' then Result.B := Result.N >= R.N;
      end
      else if (not Result.IsNum) and (not R.IsNum) then
      begin
        if Op = '=' then Result.B := Result.B = R.B
        else if Op = '<>' then Result.B := Result.B <> R.B
        else Unknown := True;
      end
      else
        Unknown := True;
      Result.IsNum := False;
    end;
  end;

var
  V: TV;
begin
  U := UpperCase(S);
  P := 1;
  Unknown := False;
  Guard := 0;
  try
    V := ParseExpr;
    Result := V.B;
    if V.IsNum then Result := V.N <> 0;
  except
    Unknown := True;
    Result := True;
  end;
  if Unknown then Result := True;
  FUnknown := Unknown;
end;

procedure TPasLexer.DoInclude(ArgStart, ArgEnd: Integer);
var
  Name, Text: string;
  N: Integer;
begin
  Name := DirArg(ArgStart, ArgEnd);
  if (Length(Name) >= 2) and (Name[1] = '''') and (Name[Length(Name)] = '''') then
    Name := Copy(Name, 2, Length(Name) - 2);
  if (Name = '') or (FIncDepth >= 8) or not Assigned(FOnInclude) then Exit;
  Text := '';
  try
    if not FOnInclude(Name, Text) then Exit;
  except
    Exit;
  end;
  if FIncDepth >= Length(FIncStack) then SetLength(FIncStack, FIncDepth + 4);
  with FIncStack[FIncDepth] do
  begin
    Source := FSource;
    Pos := FPos;
    EndPos := FEnd;
    Line := FLine;
    LineStart := FLineStart;
  end;
  if FIncDepth = 0 then
  begin
    FIncStart := FDirStart;
    FIncLine := FDirLine;
    FIncCol := FDirCol;
  end;
  Inc(FIncDepth);
  N := Length(FIncKeep);
  SetLength(FIncKeep, N + 1);
  FIncKeep[N] := Text;
  FSource := Text;
  FBuf := PChar(FSource);
  FPos := 0;
  FEnd := Length(FSource);
  FLine := 1;
  FLineStart := 0;
  // an include file saved with a byte order mark: its bytes would be symbols in the middle
  // of a declaration
  FPos := BOMLength(FBuf, FEnd);
end;

procedure TPasLexer.PopInclude;
begin
  if FIncDepth = 0 then Exit;
  Dec(FIncDepth);
  with FIncStack[FIncDepth] do
  begin
    FSource := Source;
    FPos := Pos;
    FEnd := EndPos;
    FLine := Line;
    FLineStart := LineStart;
    Source := '';
  end;
  FBuf := PChar(FSource);
end;

procedure TPasLexer.HandleDirective(BodyStart, BodyEnd: Integer);
var
  B: PChar;
  I, N: Integer;
  Name: string;
begin
  B := FBuf;
  N := 0;
  I := BodyStart;
  while (I < BodyEnd) and (N < 15) and (B[I] in ['A'..'Z', 'a'..'z']) do
  begin
    Inc(N);
    Inc(I);
  end;
  if N = 0 then Exit;
  SetString(Name, B + BodyStart, N);
  Name := UpperCase(Name);
  case Name[1] of
    'I':
      if (Name = 'I') or (Name = 'INCLUDE') then
      begin
        if FSkipping then Exit;
        while (I < BodyEnd) and (B[I] <= ' ') do Inc(I);
        if (I < BodyEnd) and not (B[I] in ['+', '-']) then
          DoInclude(I, BodyEnd);
      end
      else if Name = 'IFDEF' then
        PushCond(not FSkipping and IsDefined(DirArg(I, BodyEnd)))
      else if Name = 'IFNDEF' then
        PushCond(not FSkipping and not IsDefined(DirArg(I, BodyEnd)))
      else if Name = 'IFOPT' then
      begin
        PushCond(False);
        FCond[FCondCount - 1].Uncertain := True;
      end
      else if Name = 'IF' then
      begin
        if FSkipping then PushCond(False)
        else
        begin
          PushCond(EvalIf(DirArg(I, BodyEnd)));
          if FUnknown then FCond[FCondCount - 1].Uncertain := True;
        end;
      end
      else if Name = 'IFEND' then
        PopCond;
    'E':
      if Name = 'ELSE' then DoElse
      else if Name = 'ELSEIF' then DoElseIf(DirArg(I, BodyEnd))
      else if Name = 'ENDIF' then PopCond;
    'D':
      if (Name = 'DEFINE') and not FSkipping then
        AddDefine(DirArg(I, BodyEnd));
    'U':
      if (Name = 'UNDEF') and not FSkipping then
      begin
        if Defines.Find(UpperCase(DirArg(I, BodyEnd)), N) then
          Defines.Delete(N);
      end;
  end;
end;

{ the line break at P (#10 or #13; a CR LF counts once, at its #10): P after it, the line counted }
procedure TPasLexer.LineBreak(var P: Integer);
begin
  Inc(P);
  if (FBuf[P - 1] = #10) or (FBuf[P] <> #10) then
  begin
    Inc(FLine);
    FLineStart := P;
  end;
end;

{ the comment at P - a brace comment, else a (* *) one (Paren) - skipped with its line breaks
  counted: P after its end, or at the end of the text when it is not closed (False) }
function TPasLexer.SkipComment(var P: Integer; Paren: Boolean): Boolean;
var
  B: PChar;
  C: Char;
begin
  B := FBuf;
  if Paren then Inc(P, 2) else Inc(P);
  Result := True;
  repeat
    C := B[P];
    if Paren and (C = '*') and (B[P + 1] = ')') then
    begin
      Inc(P, 2);
      Exit;
    end
    else if not Paren and (C = '}') then
    begin
      Inc(P);
      Exit;
    end
    else if (C = #10) or (C = #13) then
      LineBreak(P)
    else if (C = #0) and (P >= FEnd) then
      Break
    else
      Inc(P);
  until False;
  Result := False;
end;

procedure TPasLexer.SkipInactive;
var
  B: PChar;
  P, S, W: Integer;
  C: Char;
begin
  B := FBuf;
  P := FPos;
  while FSkipping do
  begin
    C := B[P];
    case C of
      #0:
        if P >= FEnd then Break else Inc(P);
      #10, #13:
        LineBreak(P);
      '''':
        begin
          Inc(P);
          while not (B[P] in ['''', #10, #13, #0]) do Inc(P);
          if B[P] = '''' then Inc(P);
        end;
      '/':
        if B[P + 1] = '/' then
        begin
          while not (B[P] in [#10, #13, #0]) do Inc(P);
          if (B[P] = #0) and (P < FEnd) then Inc(P);
        end
        else
          Inc(P);
      '{', '(':
        if (C = '(') and (B[P + 1] <> '*') then
          Inc(P)
        else
        begin
          { a comment; a directive among them is processed (W: the length of its opening and
            of its closing) }
          S := P;
          W := 1 + Ord(C = '(');
          if SkipComment(P, W = 2) and (B[S + W] = '$') then
          begin
            FPos := P;
            HandleDirective(S + W + 1, P - W);
            B := FBuf;
            P := FPos;
          end;
        end;
    else
      Inc(P);
    end;
  end;
  FPos := P;
end;

procedure TPasLexer.Scan(var T: TToken);
label
  Again, CommentDone;
var
  B: PChar;
  P, S, Q, W: Integer;
  C: Char;
  Closed: Boolean;
begin
Again:
  if FSkipping then SkipInactive;
  B := FBuf;
  P := FPos;
  repeat
    C := B[P];
    if (C = ' ') or (C = #9) then Inc(P)
    else if (C = #10) or (C = #13) then LineBreak(P)
    else if C = #0 then
    begin
      if P >= FEnd then Break;
      Inc(P);
    end
    else if C < ' ' then Inc(P)
    else Break;
  until False;
  FPos := P;
  S := P;
  T.Keyword := kwNone;
  T.Directive := dvNone;
  T.Symbol := syNone;
  T.InAsm := FAsmMode;
  T.Uncertain := (FCondCount > 0) and FCond[FCondCount - 1].Uncertain;
  T.Ptr := B + P;
  if FIncDepth > 0 then
  begin
    T.Start := FIncStart;
    T.Line := FIncLine;
    T.Col := FIncCol;
  end
  else
  begin
    T.Start := FBase + P;
    T.Line := FLine;
    T.Col := P - FLineStart + 1;
  end;
  case C of
    #0:
      begin
        if FIncDepth > 0 then
        begin
          PopInclude;
          goto Again;
        end;
        T.Kind := tkEOF;
        T.Len := 0;
        T.PLen := 0;
        Exit;
      end;
    'A'..'Z', 'a'..'z', '_':
      begin
        Inc(P);
        while IdentTab[B[P]] do Inc(P);
        T.Kind := tkIdent;
        LookupWord(B + S, P - S, T.Keyword, T.Directive);
        if T.Keyword <> kwNone then T.Kind := tkKeyword;
      end;
    '0'..'9':
      begin
        Inc(P);
        while B[P] in ['0'..'9'] do Inc(P);
        if (B[P] = '.') and (B[P + 1] in ['0'..'9']) then
        begin
          Inc(P);
          while B[P] in ['0'..'9'] do Inc(P);
        end;
        if (B[P] = 'e') or (B[P] = 'E') then
        begin
          Q := P + 1;
          if (B[Q] = '+') or (B[Q] = '-') then Inc(Q);
          if B[Q] in ['0'..'9'] then
          begin
            P := Q;
            while B[P] in ['0'..'9'] do Inc(P);
          end;
        end;
        T.Kind := tkNumber;
      end;
    '$':
      begin
        Inc(P);
        while B[P] in ['0'..'9', 'A'..'F', 'a'..'f'] do Inc(P);
        T.Kind := tkNumber;
      end;
    '''', '#':
      begin
        repeat
          if B[P] = '''' then
          begin
            Inc(P);
            repeat
              C := B[P];
              if C = '''' then
              begin
                Inc(P);
                if B[P] = '''' then Inc(P) else Break;
              end
              else if (C = #10) or (C = #13) then Break
              else if (C = #0) and (P >= FEnd) then
              begin
                FInString := True;
                Break;
              end
              else Inc(P);
            until False;
          end
          else
          begin
            Inc(P);
            if B[P] = '$' then
            begin
              Inc(P);
              while B[P] in ['0'..'9', 'A'..'F', 'a'..'f'] do Inc(P);
            end
            else
              while B[P] in ['0'..'9'] do Inc(P);
          end;
        until (B[P] <> '''') and (B[P] <> '#');
        T.Kind := tkString;
      end;
    '"':
      begin
        Inc(P);
        while not (B[P] in ['"', #10, #13, #0]) do Inc(P);
        if B[P] = '"' then Inc(P);
        T.Kind := tkString;
      end;
    '{', '(':
      if (C = '(') and (B[P + 1] <> '*') then
      begin
        Inc(P);
        T.Kind := tkSymbol;
        T.Symbol := syLParen;
      end
      else
      begin
        { a comment; a directive among them is processed (W: the length of its opening and of
          its closing). FPos goes first: an include file takes over the position. }
        W := 1 + Ord(C = '(');
        Closed := SkipComment(P, W = 2);
        FPos := P;
        if not Closed then
          FInComment := True
        else if (B[S + W] = '$') and FProcessDirectives then
        begin
          FDirStart := T.Start;
          FDirLine := T.Line;
          FDirCol := T.Col;
          HandleDirective(S + W + 1, P - W);
        end;
        goto CommentDone;
      end;
    '/':
      if B[P + 1] = '/' then
      begin
        Inc(P, 2);
        repeat
          C := B[P];
          if (C = #10) or (C = #13) then Break;
          if C = #0 then
          begin
            if P >= FEnd then
            begin
              FInComment := True;
              Break;
            end;
          end;
          Inc(P);
        until False;
        FPos := P;
        goto CommentDone;
      end
      else
      begin
        Inc(P);
        T.Kind := tkSymbol;
        T.Symbol := sySlash;
      end;
    ')': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syRParen; end;
    '[': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syLBracket; end;
    ']': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syRBracket; end;
    '.':
      begin
        T.Kind := tkSymbol;
        if B[P + 1] = '.' then
        begin
          Inc(P, 2);
          T.Symbol := syDotDot;
        end
        else
        begin
          Inc(P);
          T.Symbol := syDot;
        end;
      end;
    ',': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syComma; end;
    ';': begin Inc(P); T.Kind := tkSymbol; T.Symbol := sySemicolon; end;
    ':':
      begin
        T.Kind := tkSymbol;
        if B[P + 1] = '=' then
        begin
          Inc(P, 2);
          T.Symbol := syAssign;
        end
        else
        begin
          Inc(P);
          T.Symbol := syColon;
        end;
      end;
    '=': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syEqual; end;
    '<':
      begin
        T.Kind := tkSymbol;
        if B[P + 1] = '>' then begin Inc(P, 2); T.Symbol := syNotEqual; end
        else if B[P + 1] = '=' then begin Inc(P, 2); T.Symbol := syLessEq; end
        else begin Inc(P); T.Symbol := syLess; end;
      end;
    '>':
      begin
        T.Kind := tkSymbol;
        if B[P + 1] = '=' then begin Inc(P, 2); T.Symbol := syGreaterEq; end
        else begin Inc(P); T.Symbol := syGreater; end;
      end;
    '+': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syPlus; end;
    '-': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syMinus; end;
    '*': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syStar; end;
    '^': begin Inc(P); T.Kind := tkSymbol; T.Symbol := syCaret; end;
    '@':
      if FAsmMode and (IdentTab[B[P + 1]] or (B[P + 1] = '@')) then
      begin
        Inc(P);
        while IdentTab[B[P]] or (B[P] = '@') do Inc(P);
        T.Kind := tkIdent;
      end
      else
      begin
        Inc(P);
        T.Kind := tkSymbol;
        T.Symbol := syAt;
      end;
  else
    Inc(P);
    T.Kind := tkSymbol;
    T.Symbol := syOther;
  end;
  FPos := P;
  T.PLen := P - S;
  if FIncDepth > 0 then T.Len := 0 else T.Len := P - S;
  if FAutoAsm and (T.Kind = tkKeyword) then
    if T.Keyword = kwAsm then
      FAsmMode := True
    else if T.Keyword = kwEnd then
    begin
      FAsmMode := False;
      T.InAsm := False;
    end;
  Exit;
CommentDone:
  { a comment: the token (ReturnComments), else the next one }
  if not FReturnComments then goto Again;
  T.Kind := tkComment;
  T.PLen := P - S;
  if FIncDepth > 0 then T.Len := 0 else T.Len := P - S;
end;

{ TRawToks }

constructor TRawToks.Create(const ASrc: string; Comments: Boolean);
var
  L: TPasLexer;
begin
  inherited Create;
  Src := ASrc;
  { no text, no tokens: the array as Take leaves it, without making a lexer (TCIContext starts
    its shared array so) }
  if ASrc = '' then
  begin
    SetLength(T, 256);
    Exit;
  end;
  L := TPasLexer.Create(Src);
  try
    L.ProcessDirectives := False;
    L.ReturnComments := Comments;
    L.AutoAsm := True;
    Take(L);
  finally
    L.Free;
  end;
end;

function TRawToks.Take(L: TPasLexer; Limit: Integer): Boolean;
begin
  Result := False;
  if Length(T) = 0 then SetLength(T, 256);
  repeat
    L.Next;
    if L.Tok.Kind = tkEOF then Exit;
    if N >= Length(T) then SetLength(T, N * 2);
    T[N] := L.Tok;
    Inc(N);
  until L.Tok.Start >= Limit;
  Result := True;
end;

function TRawToks.Txt(I: Integer): string;
begin
  if (I >= 0) and (I < N) then SetString(Result, T[I].Ptr, T[I].PLen) else Result := '';
end;

function TRawToks.IsId(I: Integer; const S: string): Boolean;
begin
  Result := (I >= 0) and (I < N) and (T[I].Kind = tkIdent) and SameTextP(T[I].Ptr, T[I].PLen, S);
end;

function TRawToks.IsIdent(I: Integer): Boolean;
begin
  Result := (I >= 0) and (I < N) and (T[I].Kind = tkIdent);
end;

function TRawToks.IsSy(I: Integer; S: TSymbolId): Boolean;
begin
  Result := (I >= 0) and (I < N) and (T[I].Symbol = S);
end;

function TRawToks.IsKw(I: Integer; K: TKeyword): Boolean;
begin
  Result := (I >= 0) and (I < N) and (T[I].Keyword = K);
end;

function TRawToks.NextCode(I: Integer): Integer;
begin
  Result := I + 1;
  while (Result < N) and (T[Result].Kind = tkComment) do Inc(Result);
end;

function TRawToks.EndOf(I: Integer): Integer;
begin
  Result := T[I].Start + T[I].Len;
end;

{ a compiler directive (brace or parenthesis-star comment starting with $), not a plain comment }
function TRawToks.IsDirective(I: Integer): Boolean;
begin
  Result := (I >= 0) and (I < N) and (T[I].Kind = tkComment) and (T[I].PLen > 2) and
    (((T[I].Ptr[0] = '{') and (T[I].Ptr[1] = '$')) or
     ((T[I].Ptr[0] = '(') and (T[I].Ptr[1] = '*') and (T[I].Ptr[2] = '$')));
end;

{ the first token that starts at Ofs or after (N: none) - the tokens are in source order }
function TRawToks.FirstAt(Ofs: Integer): Integer;
var
  Hi, M: Integer;
begin
  Result := 0;
  Hi := N;
  while Result < Hi do
  begin
    M := (Result + Hi) div 2;
    if T[M].Start < Ofs then Result := M + 1 else Hi := M;
  end;
end;

{ the token that starts at Ofs; -1 if none }
function TRawToks.MatchClose(I: Integer): Integer;
var
  D: Integer;
begin
  D := 0;
  Result := I;
  while Result < N do
  begin
    if IsSy(Result, syLParen) or IsSy(Result, syLBracket) then Inc(D)
    else if IsSy(Result, syRParen) or IsSy(Result, syRBracket) then
    begin
      Dec(D);
      if D = 0 then Exit;
    end;
    Inc(Result);
  end;
  Result := -1;
end;

function TRawToks.ArgumentOf(I: Integer; out NameTok, ArgIdx: Integer): Boolean;
var
  J, Depth: Integer;
begin
  Result := False;
  NameTok := -1;
  ArgIdx := 0;
  J := I - 1;
  Depth := 0;
  while J >= 0 do
  begin
    if IsSy(J, syRParen) or IsSy(J, syRBracket) then Inc(Depth)
    else if IsSy(J, syLParen) or IsSy(J, syLBracket) then
    begin
      if Depth = 0 then Break;
      Dec(Depth);
    end
    else if (Depth = 0) and IsSy(J, syComma) then Inc(ArgIdx)
    else if (Depth = 0) and (IsSy(J, sySemicolon) or (T[J].Kind = tkKeyword) and
      (T[J].Keyword in [kwBegin, kwEnd, kwThen, kwDo, kwElse, kwTry, kwRepeat])) then Exit;
    Dec(J);
  end;
  if (J <= 0) or not IsSy(J, syLParen) or (T[J - 1].Kind <> tkIdent) then Exit;
  NameTok := J - 1;
  Result := True;
end;

function TRawToks.IndexAt(Ofs: Integer): Integer;
begin
  Result := FirstAt(Ofs);
  if (Result >= N) or (T[Result].Start <> Ofs) then Result := -1;
end;

initialization
  InitTables;

end.
