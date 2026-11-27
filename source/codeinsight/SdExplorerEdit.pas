{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdExplorerEdit;

{ D7 Studio - what the Code Explorer's New and Rename write into a unit's text (as Delphi 7
  writes them: a new field, method, property or uses entry; a renamed field, method, property
  or class). Each
  function takes the parser's picture of the text (TUnitInfo, its Source the text) and gives the
  text changed, or the reason why it cannot. Where Delphi 7 writes something that does not compile
  or moves the user's text (a property's write that repeats its read, a new section in the middle of
  another, a member put between a line's ";" and its comment), the text is written as Delphi means
  it. New text takes the line ends of the unit. }

interface

uses
  SysUtils, Classes, SdPasLex, SdPasParser;

type
  { what Rename renames: a class, a routine or method (every overload), a field, variable or
    constant, a property }
  TExpRenameKind = (erClass, erMethod, erField, erProperty);

{ New: Text as typed in the explorer's edit. ClassName: the class the item goes into, in the section
  Access (0 published, 1 private, 2 protected, 3 public); '' - the unit's: InUses - a unit added to
  the interface's uses clause. True: NewSource is the text with the item (the same text when there
  is nothing to do); False: Error says why not }
function ExplorerNew(U: TUnitInfo; const ClassName: string; Access: Integer; InUses: Boolean;
  const Text: string; out NewSource, Error: string): Boolean;

{ Rename: OldName - of the kind Kind, of the class or interface ClassName ('': the unit's) -
  renamed NewName }
function ExplorerRename(U: TUnitInfo; Kind: TExpRenameKind; const ClassName, OldName, NewName: string;
  out NewSource, Error: string): Boolean;

{ where New puts a class's member: Member (its lines, the first indented 4) in the section Access (as
  ExplorerNew's) of the class ClassName, a field after the section's last field (AsField) - as one
  insertion of Text at Start; False: Error says why not }
function ExplorerMemberEdit(U: TUnitInfo; const ClassName: string; Access: Integer; AsField: Boolean;
  const Member: string; out Start: Integer; out Text, Error: string): Boolean;

{ where New puts the body of the method Name of the class ClassName ('': a plain routine at the
  unit's end); -1: none }
function ExplorerBodyPos(U: TUnitInfo; const ClassName, Name: string): Integer;

implementation

const
  WrapColumn = 75;                  // Delphi's FormatText: lines of new declarations end there
  SectionWords: array[1..4] of string = ('private', 'protected', 'public', 'published');

type
  TExpEdit = record
    Start, Len: Integer;            // the 0-based offset and the length of what is replaced
    Text: string;
  end;
  TExpEdits = array of TExpEdit;

  { a heading typed for New: [class] procedure|function|constructor|destructor Name(...): T; ... }
  THeading = record
    IsClass: Boolean;
    Keyword, Name, Params, ResultType, Directives: string;
  end;

  { a section of a class's body: its visibility (0: the one before the first visibility word;
    1 private .. 4 published), its word, where its last field and its last member end (0: none) }
  TSection = record
    Vis: Integer;
    KeyStart, KeyEnd: Integer;
    FieldEnd, MemberEnd: Integer;
  end;
  TSections = array of TSection;

  TSymKinds = set of TSymKind;

var
  EOL: string = #13#10;             // the line end of the unit being changed (ExplorerNew)

{ the unit's line end: LF when that is all it has, else CR LF }
function EolOf(const S: string): string;
begin
  if (Pos(#10, S) > 0) and (Pos(#13#10, S) = 0) then Result := #10 else Result := #13#10;
end;

procedure AddEdit(var E: TExpEdits; AStart, ALen: Integer; const AText: string);
var
  I: Integer;
begin
  for I := 0 to High(E) do
    if E[I].Start = AStart then Exit;          // the same place named twice
  I := Length(E);
  SetLength(E, I + 1);
  E[I].Start := AStart;
  E[I].Len := ALen;
  E[I].Text := AText;
end;

{ the edits made in one pass over the text, in the order of their places }
function ApplyEdits(const Src: string; const E: TExpEdits): string;
var
  Order: array of Integer;
  I, J, T, P: Integer;
begin
  SetLength(Order, Length(E));
  for I := 0 to High(E) do Order[I] := I;
  for I := 1 to High(Order) do
  begin
    T := Order[I];
    J := I - 1;
    while (J >= 0) and (E[Order[J]].Start > E[T].Start) do
    begin
      Order[J + 1] := Order[J];
      Dec(J);
    end;
    Order[J + 1] := T;
  end;
  Result := '';
  P := 0;
  for I := 0 to High(Order) do
    with E[Order[I]] do
    begin
      Result := Result + Copy(Src, P + 1, Start - P) + Text;
      P := Start + Len;
    end;
  Result := Result + Copy(Src, P + 1, MaxInt);
end;

function TokIs(L: TPasLexer; S: TSymbolId): Boolean;
begin
  Result := (L.Tok.Kind = tkSymbol) and (L.Tok.Symbol = S);
end;

{ from the Open token at L to its Close (L there); False: the text ends first }
function ToClose(L: TPasLexer; Open, Close: TSymbolId): Boolean;
var
  Depth: Integer;
begin
  Depth := 0;
  repeat
    if TokIs(L, Open) then Inc(Depth)
    else if TokIs(L, Close) then Dec(Depth);
    if Depth = 0 then Break;
    L.Next;
  until L.Tok.Kind = tkEOF;
  Result := L.Tok.Kind <> tkEOF;
end;

{ a text with its blanks made one space each (Delphi rebuilds it from its tokens) }
function Tidy(const S: string): string;
begin
  if S = '' then Result := '' else Result := Trim(NormalizeText(PChar(S), Length(S), MaxInt));
end;

{ the text from L up to a ";" or the end, tidied (L at the ";" or the end) }
function UpToSemicolon(L: TPasLexer; const Text: string): string;
var
  P0: Integer;
begin
  P0 := L.Tok.Start;
  while (L.Tok.Kind <> tkEOF) and not TokIs(L, sySemicolon) do L.Next;
  if L.Tok.Kind = tkEOF then Result := Tidy(Copy(Text, P0 + 1, MaxInt))
  else Result := Tidy(Copy(Text, P0 + 1, L.Tok.Start - P0));
end;

function IsReserved(const S: string): Boolean;
var
  L: TPasLexer;
begin
  L := TPasLexer.Create(S);
  try
    L.Next;
    Result := (L.Tok.Kind = tkKeyword) and (L.Tok.PLen = Length(S));
  finally
    L.Free;
  end;
end;

function ValidIdent(const S: string): Boolean;
begin
  Result := IsValidIdent(S) and not IsReserved(S);
end;

{ the parameters with one blank after each "," and ";" and Delphi's break points ('|') after them;
  quoted text as it is }
function MarkParams(const S: string): string;
var
  I, Depth: Integer;
  C: Char;
  Quoted: Boolean;
begin
  Result := '';
  Depth := 0;
  Quoted := False;
  I := 1;
  while I <= Length(S) do
  begin
    C := S[I];
    Result := Result + C;
    if C = '''' then Quoted := not Quoted
    else if not Quoted then
    begin
      if C in ['(', '['] then Inc(Depth)
      else if C in [')', ']'] then Dec(Depth)
      else if (C in [',', ';']) and (Depth = 0) then
      begin
        while (I < Length(S)) and (S[I + 1] = ' ') do Inc(I);
        Result := Result + ' |';
      end;
    end;
    Inc(I);
  end;
end;

{ Delphi's FormatText: a declaration in lines of at most WrapColumn columns, broken at its break
  points ('|'); a line after the first indented Indent }
function Wrap(const Text: string; Indent: Integer): string;
var
  Rest, Piece, Line: string;
  K: Integer;
begin
  Result := '';
  Line := '';
  Rest := Text;
  while Rest <> '' do
  begin
    K := Pos('|', Rest);
    if K = 0 then K := Length(Rest) + 1;
    Piece := Copy(Rest, 1, K - 1);
    Delete(Rest, 1, K);
    if (Line <> '') and (Length(Line) + Length(TrimRight(Piece)) > WrapColumn) then
    begin
      Result := Result + TrimRight(Line) + EOL;
      Line := StringOfChar(' ', Indent) + Piece;
    end
    else
      Line := Line + Piece;
  end;
  Result := Result + Line;
end;

{ the heading of a routine as New writes it: no directives in an implementation's (Body) }
function HeadingText(const H: THeading; const Qualifier: string; Body: Boolean): string;
begin
  Result := '';
  if H.IsClass then Result := 'class ';
  Result := Result + H.Keyword + ' ';
  if Qualifier <> '' then Result := Result + Qualifier + '.';
  Result := Result + H.Name;
  if H.Params <> '' then Result := Result + '(' + MarkParams(H.Params) + ')';
  if H.ResultType <> '' then Result := Result + ': ' + H.ResultType;
  Result := Result + ';';
  if not Body and (H.Directives <> '') then Result := Result + ' ' + H.Directives + ';';
end;

function ParseHeading(const Text: string; var H: THeading; out Error: string): Boolean;
var
  L: TPasLexer;
  P0: Integer;
begin
  Result := False;
  H.IsClass := False;
  H.Params := '';
  H.ResultType := '';
  H.Directives := '';
  L := TPasLexer.Create(Text);
  try
    L.Next;
    if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword = kwClass) then
    begin
      H.IsClass := True;
      L.Next;
    end;
    if not ((L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor])) or
      (H.IsClass and (L.Tok.Keyword in [kwConstructor, kwDestructor])) then
    begin
      Error := 'procedure or function expected';
      Exit;
    end;
    H.Keyword := LowerCase(L.TokenText);
    L.Next;
    if L.Tok.Kind <> tkIdent then
    begin
      Error := 'Identifier expected';
      Exit;
    end;
    H.Name := L.TokenText;
    L.Next;
    if TokIs(L, syLParen) then
    begin
      P0 := L.Tok.Start + 1;
      if not ToClose(L, syLParen, syRParen) then
      begin
        Error := ''')'' expected';
        Exit;
      end;
      H.Params := Tidy(Copy(Text, P0 + 1, L.Tok.Start - P0));
      L.Next;
    end;
    if TokIs(L, syColon) then
    begin
      if H.Keyword <> 'function' then
      begin
        Error := ''';'' expected';
        Exit;
      end;
      L.Next;
      H.ResultType := UpToSemicolon(L, Text);
      if H.ResultType = '' then
      begin
        Error := 'Type expected';
        Exit;
      end;
    end
    else if H.Keyword = 'function' then
    begin
      Error := ''':'' expected';
      Exit;
    end;
    if TokIs(L, sySemicolon) then
    begin
      L.Next;
      if L.Tok.Kind <> tkEOF then H.Directives := Tidy(Copy(Text, L.Tok.Start + 1, MaxInt));
      while (H.Directives <> '') and (H.Directives[Length(H.Directives)] = ';') do
        H.Directives := TrimRight(Copy(H.Directives, 1, Length(H.Directives) - 1));
    end
    else if L.Tok.Kind <> tkEOF then
    begin
      Error := ''';'' expected';
      Exit;
    end;
    Result := True;
  finally
    L.Free;
  end;
end;

{ "Name: Type" typed for New (what follows the type is left out, as Delphi does) }
function ParseField(const Text: string; out Name, TypeText, Error: string): Boolean;
var
  L: TPasLexer;
begin
  Result := False;
  L := TPasLexer.Create(Text);
  try
    L.Next;
    if L.Tok.Kind <> tkIdent then
    begin
      Error := 'Identifier expected';
      Exit;
    end;
    Name := L.TokenText;
    L.Next;
    if not TokIs(L, syColon) then
    begin
      Error := ''':'' expected';
      Exit;
    end;
    L.Next;
    TypeText := UpToSemicolon(L, Text);
    if TypeText = '' then
    begin
      Error := 'Type expected';
      Exit;
    end;
    Result := True;
  finally
    L.Free;
  end;
end;

{ "property Name[...]: Type read R write W" typed for New - only these (Delphi's NewProperty) }
function ParseProperty(const Text: string; out Decl, Error: string): Boolean;
var
  L: TPasLexer;
  P0: Integer;
  Name, Index, TypeText, R, W: string;
begin
  Result := False;
  Index := '';
  R := '';
  W := '';
  L := TPasLexer.Create(Text);
  try
    L.Next;
    L.Next;                                   // property
    if L.Tok.Kind <> tkIdent then
    begin
      Error := 'Identifier expected';
      Exit;
    end;
    Name := L.TokenText;
    L.Next;
    if TokIs(L, syLBracket) then
    begin
      P0 := L.Tok.Start + 1;
      if not ToClose(L, syLBracket, syRBracket) then
      begin
        Error := ''']'' expected';
        Exit;
      end;
      Index := '[' + Tidy(Copy(Text, P0 + 1, L.Tok.Start - P0)) + ']';
      L.Next;
    end;
    if not TokIs(L, syColon) then
    begin
      Error := ''':'' expected';
      Exit;
    end;
    L.Next;
    if not (L.Tok.Kind in [tkIdent, tkKeyword]) then
    begin
      Error := 'Type expected';
      Exit;
    end;
    TypeText := L.TokenText;
    L.Next;
    while TokIs(L, syDot) do
    begin
      L.Next;
      TypeText := TypeText + '.' + L.TokenText;
      L.Next;
    end;
    while (L.Tok.Kind = tkIdent) and (L.Tok.Directive in [dvRead, dvWrite]) do
    begin
      if L.Tok.Directive = dvRead then
      begin
        L.Next;
        R := L.TokenText;
      end
      else
      begin
        L.Next;
        W := L.TokenText;
      end;
      if L.Tok.Kind <> tkIdent then
      begin
        Error := 'Identifier expected';
        Exit;
      end;
      L.Next;
    end;
    if TokIs(L, sySemicolon) then L.Next;
    if L.Tok.Kind <> tkEOF then
    begin
      Error := ''';'' expected';
      Exit;
    end;
    Decl := 'property ' + Name + Index + ': ' + TypeText;
    if R <> '' then Decl := Decl + ' read ' + R;
    if W <> '' then Decl := Decl + ' write ' + W;
    Decl := Decl + ';';
    Result := True;
  finally
    L.Free;
  end;
end;

{ the class (or interface) ClassName of the unit with a body; nil: none }
function FindClass(U: TUnitInfo; const ClassName: string): TSymbol;
begin
  Result := U.FindTypeSym(ClassName, [tyClass, tyObject, tyInterface]);
end;

function MemberOffset(U: TUnitInfo; M: TSymbol): Integer;
begin
  if M is TRoutineSym then Result := TRoutineSym(M).HeadStart else Result := U.OffsetOf(M.Line, M.Col);
end;

{ a class's sections in the order of its text: the one before the first visibility word, then one
  per visibility word (the parser's rule: the word not followed by ":" or ","), with where their
  last field and their last member end }
function ClassSections(U: TUnitInfo; D: TTypeDesc): TSections;
var
  L: TPasLexer;
  N, I, K, Ofs: Integer;
  P: PToken;
  M: TSymbol;
begin
  SetLength(Result, 1);
  Result[0].Vis := 0;
  Result[0].KeyStart := D.HeaderEnd;
  Result[0].KeyEnd := D.HeaderEnd;
  Result[0].FieldEnd := 0;
  Result[0].MemberEnd := 0;
  if D.EndOfs <= D.HeaderEnd then Exit;
  L := TPasLexer.Create(U.Source, D.HeaderEnd, D.EndOfs);
  try
    L.Next;
    while L.Tok.Kind <> tkEOF do
    begin
      if (L.Tok.Kind = tkIdent) and (L.Tok.Directive in VisibilityDirs) then
      begin
        P := L.Peek;
        if not ((P^.Kind = tkSymbol) and (P^.Symbol in [syColon, syComma])) then
        begin
          N := Length(Result);
          SetLength(Result, N + 1);
          case L.Tok.Directive of
            dvPrivate: Result[N].Vis := 1;
            dvProtected: Result[N].Vis := 2;
            dvPublished: Result[N].Vis := 4;
          else
            Result[N].Vis := 3;
          end;
          Result[N].KeyStart := L.Tok.Start;
          Result[N].KeyEnd := L.Tok.Start + L.Tok.Len;
          Result[N].FieldEnd := 0;
          Result[N].MemberEnd := 0;
        end;
      end;
      L.Next;
    end;
  finally
    L.Free;
  end;
  if D.Members = nil then Exit;
  for I := 0 to D.Members.Count - 1 do
  begin
    M := D.Members[I];
    Ofs := MemberOffset(U, M);
    K := 0;
    while (K < High(Result)) and (Result[K + 1].KeyStart <= Ofs) do Inc(K);
    if M.FullEnd > Result[K].MemberEnd then Result[K].MemberEnd := M.FullEnd;
    if (M.Kind = skField) and (M.FullEnd > Result[K].FieldEnd) then Result[K].FieldEnd := M.FullEnd;
  end;
end;

{ Text put before the token at Ofs: at the start of its line when nothing else is before it there,
  else right before it on a line of its own (the token then indented 2, as a class's end and its
  visibility words are) }
procedure AddBefore(var E: TExpEdits; const Src: string; Ofs: Integer; const Text: string);
var
  P: Integer;
begin
  P := LineStartOf(Src, Ofs);
  if Trim(Copy(Src, P + 1, Ofs - P)) = '' then AddEdit(E, P, 0, Text + EOL)
  else AddEdit(E, Ofs, 0, EOL + Text + EOL + '  ');
end;

{ the member text Member (its first line indented 4, as Delphi writes it) put into the section Vis
  of the class: after the section's last field (AsField) or its last member, an empty section's
  right after its word - the first section of that visibility (Delphi ignores a second one); a
  section the class lacks added after the sections of lower visibility }
function PlaceMember(U: TUnitInfo; D: TTypeDesc; Vis: Integer; AsField: Boolean; const Member: string;
  var E: TExpEdits; out Error: string): Boolean;
var
  S: TSections;
  I, K, After, P, L: Integer;
begin
  Result := False;
  if D.EndOfs <= D.HeaderEnd then
  begin
    Error := 'Could not find source location to add the member';
    Exit;
  end;
  S := ClassSections(U, D);
  for I := 1 to High(S) do
    if S[I].Vis = Vis then
    begin
      if AsField then P := S[I].FieldEnd else P := S[I].MemberEnd;
      if P = 0 then P := S[I].KeyEnd;
      { at the end of the line - before the class's end when that is on the same line }
      L := LineEndOf(U.Source, P);
      if L > D.EndOfs then AddEdit(E, D.EndOfs, 0, EOL + Member + EOL + '  ')
      else AddEdit(E, L, 0, EOL + Member);
      Result := True;
      Exit;
    end;
  { a new section: after the last of the sections of lower visibility (before the next one), else
    before the first section (the class's end when it has none) }
  After := -1;
  for I := 1 to High(S) do
    if (S[I].Vis < Vis) and ((After < 0) or (S[I].KeyStart > S[After].KeyStart)) then After := I;
  K := -1;
  if After >= 0 then
  begin
    for I := 1 to High(S) do
      if (S[I].KeyStart > S[After].KeyStart) and ((K < 0) or (S[I].KeyStart < S[K].KeyStart)) then K := I;
  end
  else if High(S) >= 1 then
    K := 1;
  if K >= 0 then P := S[K].KeyStart else P := D.EndOfs;
  AddBefore(E, U.Source, P, '  ' + SectionWords[Vis] + EOL + Member);
  Result := True;
end;

{ a class of the unit (the marker comment of a class in the implementation part, Delphi's
  CheckClassSection, names one) }
function IsUnitClass(U: TUnitInfo; const Name: string): Boolean;
begin
  Result := U.FindTypeSym(Name, [tyClass, tyObject]) <> nil;
end;

{ where the unit's routines end: before initialization, finalization, the main begin or the final
  end. (Delphi's end position); -1: none }
function UnitEndPos(U: TUnitInfo): Integer;
begin
  if U.InitOfs > 0 then Result := U.InitOfs
  else if U.FinalOfs > 0 then Result := U.FinalOfs
  else if U.MainBegin > 0 then Result := U.MainBegin
  else if U.FinalEndOfs > 0 then Result := U.FinalEndOfs
  else Result := -1;
end;

{ Delphi's MethodAddPos: before the first of the class's bodies whose name sorts after Name while
  the bodies are in alphabetical order; else at the class's end - the marker comment (the name of a
  class in braces) of the class whose bodies follow its own, else the unit's end }
function BodyPos(U: TUnitInfo; const ClassName, Name: string): Integer;
var
  L: TList;
  I, Last, P: Integer;
  Sorted: Boolean;
  Lex: TPasLexer;
  T: string;
begin
  Result := -1;
  L := TList.Create;
  try
    U.GetImpls(L, ClassName, '');
    Sorted := True;
    for I := 1 to L.Count - 1 do
      if CompareText(TRoutineSym(L[I - 1]).Name, TRoutineSym(L[I]).Name) > 0 then Sorted := False;
    if Sorted then
      for I := 0 to L.Count - 1 do
        if CompareText(TRoutineSym(L[I]).Name, Name) > 0 then
        begin
          Result := TRoutineSym(L[I]).HeadStart;
          Exit;
        end;
    { the class's end: the next class's marker comment after its last body (or after its own
      marker) }
    Last := -1;
    for I := 0 to L.Count - 1 do
      if TRoutineSym(L[I]).BodyEnd > Last then Last := TRoutineSym(L[I]).BodyEnd;
    if U.ImplOfs > 0 then
    begin
      Lex := TPasLexer.Create(U.Source, U.ImplOfs, -1);
      try
        Lex.ReturnComments := True;
        Lex.Next;
        while Lex.Tok.Kind <> tkEOF do
        begin
          if (Lex.Tok.Kind = tkComment) and (Lex.Tok.PLen > 2) and (Lex.Tok.Ptr^ = '{') then
          begin
            SetString(T, Lex.Tok.Ptr + 1, Lex.Tok.PLen - 2);
            T := Trim(T);
            P := Lex.Tok.Start;
            if IsValidIdent(T) and IsUnitClass(U, T) then
            begin
              if SameText(T, ClassName) then
              begin
                if P > Last then Last := P;
              end
              else if (Last >= 0) and (P > Last) then
              begin
                Result := P;
                Exit;
              end;
            end;
          end;
          Lex.Next;
        end;
      finally
        Lex.Free;
      end;
    end;
  finally
    L.Free;
  end;
  Result := UnitEndPos(U);
end;

{ the end of the interface part's last token; whether its last declarations are routines
  (LastKind skRoutine) or a var section (skVar - Thread: a threadvar section, which a new variable
  does not join) }
function InterfaceEnd(U: TUnitInfo; out LastKind: TSymKind; out Thread: Boolean): Integer;
var
  L: TPasLexer;
  I, Best, Depth: Integer;
  S: TSymbol;
begin
  Result := -1;
  LastKind := skUnknown;
  Thread := False;
  if (U.IntfOfs <= 0) or (U.ImplOfs <= U.IntfOfs) then Exit;
  Depth := 0;
  L := TPasLexer.Create(U.Source, U.IntfOfs, U.ImplOfs);
  try
    L.Next;
    while L.Tok.Kind <> tkEOF do
    begin
      if TokIs(L, syLParen) then Inc(Depth)
      else if TokIs(L, syRParen) then Dec(Depth)
      else if (Depth = 0) and (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in [kwVar, kwThreadvar]) then
        Thread := L.Tok.Keyword = kwThreadvar;
      Result := L.Tok.Start + L.Tok.Len;
      L.Next;
    end;
  finally
    L.Free;
  end;
  Best := -1;
  for I := 0 to U.IntfSyms.Count - 1 do
  begin
    S := U.IntfSyms[I];
    if S.FullEnd > Best then
    begin
      Best := S.FullEnd;
      LastKind := S.Kind;
    end;
  end;
end;

function UnitHas(U: TUnitInfo; const Name: string): Boolean;
begin
  Result := (U.IntfSyms.Find(Name) <> nil) or (U.ImplSyms.Find(Name) <> nil);
end;

{ the class's member named Name of one of the kinds Kinds (nil: none) }
function FindMember(D: TTypeDesc; Kinds: TSymKinds; const Name: string): TSymbol;
begin
  Result := nil;
  if D.Members = nil then Exit;
  Result := D.Members.Find(Name);
  while (Result <> nil) and not (Result.Kind in Kinds) do Result := D.Members.FindNext(Result);
end;

function ClassHas(D: TTypeDesc; const Name: string): Boolean;
begin
  Result := (D.Members <> nil) and (D.Members.Find(Name) <> nil);
end;

function ExplorerNew(U: TUnitInfo; const ClassName: string; Access: Integer; InUses: Boolean;
  const Text: string; out NewSource, Error: string): Boolean;
const
  { TCIExpAccess (published, private, protected, public) -> the visibility of a section }
  AccessVis: array[0..3] of Integer = (4, 1, 2, 3);
var
  E: TExpEdits;
  L: TPasLexer;
  Cls: TSymbol;
  D: TTypeDesc;
  H: THeading;
  Name, TypeText, Decl: string;
  First: TToken;
  P, C: Integer;
  LastKind: TSymKind;
  Thread: Boolean;
begin
  Result := False;
  NewSource := U.Source;
  Error := '';
  E := nil;
  EOL := EolOf(U.Source);
  L := TPasLexer.Create(Text);
  try
    L.Next;
    First := L.Tok;
    if (First.Kind = tkKeyword) and (First.Keyword = kwClass) then L.Next;
    if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor]) then
      First := L.Tok;
  finally
    L.Free;
  end;
  { a unit of the interface's uses clause: appended before its ";", on a new line indented 2 when
    the line would reach past column 75 (none: nothing, as in Delphi) }
  if InUses then
  begin
    Name := Trim(Text);
    if not ValidIdent(Name) then
    begin
      Error := Format('''%s'' is not a valid unit name', [Name]);
      Exit;
    end;
    Result := True;
    if (U.IntfUsesEnd <= 0) or (U.IntfUses.IndexOf(Name) >= 0) or (U.ImplUses.IndexOf(Name) >= 0) then Exit;
    P := U.IntfUsesEnd;
    C := P - LineStartOf(U.Source, P);
    if C + Length(', ' + Name) > WrapColumn then AddEdit(E, P, 0, ',' + EOL + '  ' + Name)
    else AddEdit(E, P, 0, ', ' + Name);
    NewSource := ApplyEdits(U.Source, E);
    Exit;
  end;
  if ClassName <> '' then
  begin
    Cls := FindClass(U, ClassName);
    if (Cls = nil) or (Cls.TypeDesc = nil) or (Cls.TypeDesc.Kind = tyInterface) then
    begin
      Error := Format('Class %s not found', [ClassName]);
      Exit;
    end;
    D := Cls.TypeDesc;
    if (Access < 0) or (Access > 3) then Access := 3;
    if (First.Kind = tkKeyword) and (First.Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor]) then
    begin
      { a method: its declaration in the section, its empty body in the implementation }
      if not ParseHeading(Text, H, Error) then Exit;
      if not PlaceMember(U, D, AccessVis[Access], False, Wrap('    ' + HeadingText(H, '', False), 6), E, Error) then Exit;
      P := BodyPos(U, ClassName, H.Name);
      if P < 0 then
      begin
        Error := Format('Could not find source location to add method %s.%s', [ClassName, H.Name]);
        Exit;
      end;
      AddEdit(E, P, 0, Wrap(HeadingText(H, ClassName, True), 2) + EOL + 'begin' + EOL + EOL + 'end;' + EOL + EOL);
    end
    else if (First.Kind = tkKeyword) and (First.Keyword = kwProperty) then
    begin
      if not ParseProperty(Text, Decl, Error) then Exit;
      if not PlaceMember(U, D, AccessVis[Access], False, '    ' + Decl, E, Error) then Exit;
    end
    else if First.Kind = tkIdent then
    begin
      if not ParseField(Text, Name, TypeText, Error) then Exit;
      if ClassHas(D, Name) then
      begin
        Error := Format('Field %s already exists in class %s', [Name, ClassName]);
        Exit;
      end;
      if not PlaceMember(U, D, AccessVis[Access], True, '    ' + Name + ': ' + TypeText + ';', E, Error) then Exit;
    end
    else
    begin
      Error := 'Identifier expected';
      Exit;
    end;
  end
  else
  begin
    P := InterfaceEnd(U, LastKind, Thread);
    if (First.Kind = tkKeyword) and (First.Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor]) then
    begin
      { a routine: its declaration at the interface's end (after an empty line when the
        declarations before it are not routines), its body at the unit's end }
      if not ParseHeading(Text, H, Error) then Exit;
      if H.IsClass or (H.Keyword = 'constructor') or (H.Keyword = 'destructor') then
      begin
        Error := 'procedure or function expected';
        Exit;
      end;
      if P < 0 then
      begin
        Error := 'Could not find the interface section';
        Exit;
      end;
      Decl := EOL + Wrap(HeadingText(H, '', False), 2);
      if LastKind <> skRoutine then Decl := EOL + Decl;
      AddEdit(E, P, 0, Decl);
      C := UnitEndPos(U);
      if C < 0 then
      begin
        Error := Format('Could not find source location to add %s', [H.Name]);
        Exit;
      end;
      AddEdit(E, C, 0, Wrap(HeadingText(H, '', True), 2) + EOL + 'begin' + EOL + EOL + 'end;' + EOL + EOL);
    end
    else if (First.Kind = tkKeyword) and (First.Keyword = kwProperty) then
    begin
      Error := 'Property is only allowed in a class';
      Exit;
    end
    else if First.Kind = tkIdent then
    begin
      { a variable of the interface part: in its last section when that is a var section, else in
        a new one }
      if not ParseField(Text, Name, TypeText, Error) then Exit;
      if UnitHas(U, Name) then
      begin
        Error := Format('Variable %s already exists in unit %s', [Name, U.Name]);
        Exit;
      end;
      if P < 0 then
      begin
        Error := 'Could not find the interface section';
        Exit;
      end;
      Decl := EOL + '  ' + Name + ': ' + TypeText + ';';
      if (LastKind <> skVar) or Thread then Decl := EOL + EOL + 'var' + Decl;
      AddEdit(E, P, 0, Decl);
    end
    else
    begin
      Error := 'Identifier expected';
      Exit;
    end;
  end;
  NewSource := ApplyEdits(U.Source, E);
  Result := True;
end;

{ ---------------------------------------------------------------- Rename }

{ the name at Line, Col, NewName instead (only when the text there is the old name) }
procedure RenameAt(U: TUnitInfo; Line, Col: Integer; const OldName, NewName: string; var E: TExpEdits);
var
  P: Integer;
begin
  if Line <= 0 then Exit;
  P := U.OffsetOf(Line, Col);
  if SameText(Copy(U.Source, P + 1, Length(OldName)), OldName) then AddEdit(E, P, Length(OldName), NewName);
end;

{ the unit's symbols named OldName of the kinds Kinds in both parts (routines: the unit's own,
  not methods) }
procedure RenameUnitSymbols(U: TUnitInfo; Kinds: TSymKinds; const OldName, NewName: string; var E: TExpEdits);
var
  K: Integer;
  Tab: TSymTable;
  S: TSymbol;
begin
  for K := 0 to 1 do
  begin
    if K = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
    S := Tab.Find(OldName);
    while S <> nil do
    begin
      if (S.Kind in Kinds) and not ((S.Kind = skRoutine) and (TRoutineSym(S).ClassQual <> '')) then
        RenameAt(U, S.Line, S.Col, OldName, NewName, E);
      S := Tab.FindNext(S);
    end;
  end;
end;

{ a class's methods named OldName: their declarations and the headings of their implementations }
procedure RenameMethods(U: TUnitInfo; D: TTypeDesc; const ClassName, OldName, NewName: string; var E: TExpEdits);
var
  I: Integer;
  L: TList;
  M: TSymbol;
begin
  if D.Members <> nil then
  begin
    M := D.Members.Find(OldName);
    while M <> nil do
    begin
      if M.Kind = skRoutine then RenameAt(U, M.Line, M.Col, OldName, NewName, E);
      M := D.Members.FindNext(M);
    end;
  end;
  if D.Kind = tyInterface then Exit;
  L := TList.Create;
  try
    U.GetImpls(L, ClassName, OldName);
    for I := 0 to L.Count - 1 do
      RenameAt(U, TRoutineSym(L[I]).Line, TRoutineSym(L[I]).Col, OldName, NewName, E);
  finally
    L.Free;
  end;
end;

{ a class's forward declarations ("TOld = class;", an interface's "IOld = interface;"): the parser keeps
  only the place of the full declaration }
procedure RenameForwards(U: TUnitInfo; const OldName, NewName: string; var E: TExpEdits);
var
  L: TPasLexer;
  NameStart, NameLen: Integer;
begin
  L := TPasLexer.Create(U.Source);
  try
    L.Next;
    while L.Tok.Kind <> tkEOF do
    begin
      if (L.Tok.Kind = tkIdent) and SameText(L.TokenText, OldName) then
      begin
        NameStart := L.Tok.Start;
        NameLen := L.Tok.Len;
        L.Next;
        if TokIs(L, syEqual) then
        begin
          L.Next;
          if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in [kwClass, kwInterface, kwDispinterface]) then
          begin
            L.Next;
            if TokIs(L, sySemicolon) then AddEdit(E, NameStart, NameLen, NewName);
          end;
        end;
        Continue;                         // the token reached is looked at as it is
      end;
      L.Next;
    end;
  finally
    L.Free;
  end;
end;

{ the class name of the implementations' headings ("procedure TOld.Bar") }
procedure RenameQualifiers(U: TUnitInfo; const OldName, NewName: string; var E: TExpEdits);
var
  L: TList;
  I: Integer;
  R: TRoutineSym;
  Lex: TPasLexer;
begin
  L := TList.Create;
  try
    U.GetImpls(L, OldName, '');
    for I := 0 to L.Count - 1 do
    begin
      R := TRoutineSym(L[I]);
      Lex := TPasLexer.Create(U.Source, R.HeadStart, -1);
      try
        Lex.Next;
        if (Lex.Tok.Kind = tkKeyword) and (Lex.Tok.Keyword = kwClass) then Lex.Next;
        Lex.Next;                               // procedure / function / constructor / destructor
        if (Lex.Tok.Kind = tkIdent) and SameText(Lex.TokenText, OldName) then
          AddEdit(E, Lex.Tok.Start, Lex.Tok.Len, NewName);
      finally
        Lex.Free;
      end;
    end;
  finally
    L.Free;
  end;
end;

function ExplorerRename(U: TUnitInfo; Kind: TExpRenameKind; const ClassName, OldName, NewName: string;
  out NewSource, Error: string): Boolean;
const
  Accessors: array[0..4] of string = ('F', 'Get', 'Set', 'Stored', 'IsStored');
var
  E: TExpEdits;
  Cls, M, Prop: TSymbol;
  D: TTypeDesc;
  I, K: Integer;
  Lex: TPasLexer;
  Owner: string;
begin
  Result := False;
  NewSource := U.Source;
  Error := '';
  E := nil;
  if not ValidIdent(NewName) then
  begin
    Error := Format('''%s'' is not a valid identifier', [NewName]);
    Exit;
  end;
  if (OldName = NewName) or (SameText(OldName, NewName) and (Kind = erMethod)) then
  begin
    { the same name; a method's case alone is not changed (Delphi ignores it) }
    Result := True;
    Exit;
  end;
  D := nil;
  if (ClassName <> '') or (Kind = erClass) then
  begin
    if Kind = erClass then Owner := OldName else Owner := ClassName;
    Cls := FindClass(U, Owner);
    if (Cls = nil) or (Cls.TypeDesc = nil) then
    begin
      Error := Format('Class %s not found', [Owner]);
      Exit;
    end;
    D := Cls.TypeDesc;
  end;
  { a new name the class (the unit) has already - a change of case alone is not looked at }
  if not SameText(OldName, NewName) then
    if (Kind <> erClass) and (D <> nil) then
    begin
      if ClassHas(D, NewName) then
      begin
        Error := Format('%s already exists in class %s', [NewName, ClassName]);
        Exit;
      end;
    end
    else if UnitHas(U, NewName) then
    begin
      Error := Format('%s already exists in unit %s', [NewName, U.Name]);
      Exit;
    end;
  case Kind of
    erClass:
      begin
        { its declaration, its forward declarations and its methods' implementations }
        RenameUnitSymbols(U, [skType], OldName, NewName, E);
        RenameForwards(U, OldName, NewName, E);
        RenameQualifiers(U, OldName, NewName, E);
      end;
    erField:
      if D <> nil then
      begin
        M := FindMember(D, [skField], OldName);
        if M <> nil then RenameAt(U, M.Line, M.Col, OldName, NewName, E);
      end
      else
        RenameUnitSymbols(U, [skVar, skConst, skResStr], OldName, NewName, E);
    erMethod:
      if D <> nil then
        RenameMethods(U, D, ClassName, OldName, NewName, E)
      else
      begin
        { the unit's routine: its declarations of both parts and its implementations }
        RenameUnitSymbols(U, [skRoutine], OldName, NewName, E);
        for I := 0 to U.ImplRoutines.Count - 1 do
        begin
          M := TSymbol(U.ImplRoutines[I]);
          if (TRoutineSym(M).ClassQual = '') and SameText(M.Name, OldName) then
            RenameAt(U, M.Line, M.Col, OldName, NewName, E);
        end;
      end;
    erProperty:
      if D <> nil then
      begin
        Prop := FindMember(D, [skProperty], OldName);
        if Prop = nil then
        begin
          Error := Format('Property %s not found', [OldName]);
          Exit;
        end;
        RenameAt(U, Prop.Line, Prop.Col, OldName, NewName, E);
        { the accessors that follow the property's name: F<Old>, Get<Old>, Set<Old>, Stored<Old>,
          IsStored<Old> - in its read, write and stored, and as members of the class }
        Lex := TPasLexer.Create(U.Source, Prop.DeclEnd, Prop.FullEnd);
        try
          Lex.Next;
          while Lex.Tok.Kind <> tkEOF do
          begin
            if (Lex.Tok.Kind = tkIdent) and (Lex.Tok.Directive in [dvRead, dvWrite, dvStored]) then
            begin
              Lex.Next;
              if Lex.Tok.Kind = tkIdent then
                for K := 0 to High(Accessors) do
                  if SameText(Lex.TokenText, Accessors[K] + OldName) then
                    AddEdit(E, Lex.Tok.Start, Lex.Tok.Len, Accessors[K] + NewName);
            end;
            Lex.Next;
          end;
        finally
          Lex.Free;
        end;
        { the members of those names: the field F<Old>, the methods (every overload) }
        M := FindMember(D, [skField], Accessors[0] + OldName);
        if M <> nil then RenameAt(U, M.Line, M.Col, Accessors[0] + OldName, Accessors[0] + NewName, E);
        for K := 1 to High(Accessors) do
          if FindMember(D, [skRoutine], Accessors[K] + OldName) <> nil then
            RenameMethods(U, D, ClassName, Accessors[K] + OldName, Accessors[K] + NewName, E);
      end;
  end;
  NewSource := ApplyEdits(U.Source, E);
  Result := True;
end;

function ExplorerMemberEdit(U: TUnitInfo; const ClassName: string; Access: Integer; AsField: Boolean;
  const Member: string; out Start: Integer; out Text, Error: string): Boolean;
const
  AccessVis: array[0..3] of Integer = (4, 1, 2, 3);
var
  E: TExpEdits;
  Cls: TSymbol;
begin
  Result := False;
  Start := -1;
  Text := '';
  Error := '';
  E := nil;
  EOL := EolOf(U.Source);
  Cls := FindClass(U, ClassName);
  if (Cls = nil) or (Cls.TypeDesc = nil) or (Cls.TypeDesc.Kind = tyInterface) then
  begin
    Error := Format('Class %s not found', [ClassName]);
    Exit;
  end;
  if (Access < 0) or (Access > 3) then Access := 3;
  if not PlaceMember(U, Cls.TypeDesc, AccessVis[Access], AsField, Member, E, Error) or (Length(E) <> 1) then Exit;
  Start := E[0].Start;
  Text := E[0].Text;
  Result := True;
end;

function ExplorerBodyPos(U: TUnitInfo; const ClassName, Name: string): Integer;
begin
  if ClassName = '' then Result := UnitEndPos(U) else Result := BodyPos(U, ClassName, Name);
end;

end.
