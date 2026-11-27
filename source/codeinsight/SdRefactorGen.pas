{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorGen;

{ D7 Studio - the refactorings that write code: Implement Methods (the methods a class's interfaces
  lack, its ancestors' virtual methods overridden), Encapsulate Field (a field behind a property),
  Complete Case (a branch for every value of an enumeration), Extract Constant (a literal named) and
  Convert to Format (a concatenation as Format). As SdRefactor's: edits of the texts code insight
  reads, shown before they are applied. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex, SdPasParser, SdCodeInsight, SdExplorerEdit, SdRefactor;

{ Implement Methods: the class at Pos and what it can be given (TCIMethodItem, the caller frees
  them): its interfaces' methods it lacks, its ancestors' virtual methods }
function ImplementTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer; out ClassName: string;
  Items: TList; out Error: string): Boolean;
{ Items written into the class ClassName: declared - an interface's method in the section Access (as
  the Code Explorer's), an override in its ancestor's visibility - and implemented, an override
  calling the inherited method (CallInherited; not an abstract one) }
function PlanImplementMethods(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string;
  Items: TList; Access: Integer; CallInherited: Boolean; out Error: string): Boolean;
{ an item as Implement Methods declares it, without its directives: 'function Get(I: Integer): string' }
function MethodItemText(It: TCIMethodItem): string;

{ Encapsulate Field: the field of a class at Pos (Info, Places as TCodeInsight.SymbolPlaces gives
  them), its type, the name its property gets (the field's without its F) }
function EncapsulateTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; out PropName, TypeText: string;
  out Error: string): Boolean;
{ the field private - F and the property's name when it had the property's -, the property PropName
  in the section Access reading it and writing it (Setter: through SetName); the class's methods
  keep the field, everything else names the property }
function PlanEncapsulateField(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  const PropName, TypeText: string; Access: Integer; Setter: Boolean; out Error: string): Boolean;

{ Complete Case: the case statement around Pos given a branch for each value of its enumerated type
  that none of its branches names }
function PlanCompleteCase(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;

{ Extract Constant: the number or string at A (A = B), else the constant expression A .. B
  selected, a name for it; Local - it is in a routine, whose constants it can join }
function ConstTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer; out Expr, Name: string;
  out Local: Boolean; out Error: string): Boolean;
{ Where: 0 the routine's constants, 1 the implementation's, 2 the interface's; ReplaceAll - the same
  value elsewhere there too (in the routine, in the unit's statements) }
function PlanExtractConstant(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name: string; Where: Integer; ReplaceAll: Boolean; out Error: string): Boolean;

{ Convert to Format: the string concatenation at A (A = B), else A .. B selected, as a call of
  Format - its texts the format, %d for IntToStr, %g for FloatToStr, %.Nx for IntToHex(X, N), %s
  for the rest; SysUtils used when the unit does not use it }
function PlanConvertToFormat(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out Error: string): Boolean;

implementation

{ ---------------------------------------------------------------------------- }
{ Implement Methods }

function ImplementTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer; out ClassName: string;
  Items: TList; out Error: string): Boolean;
begin
  Result := False;
  Error := '';
  if not CI.ClassMethods(FileName, Source, Pos, False, ClassName, Items) then
  begin
    Error := 'Put the caret in the declaration of a class or in one of its methods';
    Exit;
  end;
  if Items.Count = 0 then
  begin
    Error := Format('%s has every method of its interfaces and overrides every virtual method of its ancestors',
      [ClassName]);
    Exit;
  end;
  Result := True;
end;

function MethodItemText(It: TCIMethodItem): string;
begin
  Result := It.Keyword + ' ' + It.Name;
  if It.Params <> '' then Result := Result + '(' + It.Params + ')';
  if It.ResultType <> '' then Result := Result + ': ' + It.ResultType;
end;

{ a parameter list's text without its default values (an implementation's heading) }
function WithoutDefaults(const Params: string): string;
var
  L: TPasLexer;
  Depth, P, Cut: Integer;
begin
  Result := '';
  P := 0;
  Cut := -1;
  Depth := 0;
  L := TPasLexer.Create(Params);
  try
    L.Next;
    while L.Tok.Kind <> tkEOF do
    begin
      if L.Tok.Kind = tkSymbol then
        case L.Tok.Symbol of
          syLParen, syLBracket: Inc(Depth);
          syRParen, syRBracket: Dec(Depth);
          syEqual:
            if (Depth = 0) and (Cut < 0) then Cut := L.Tok.Start;
          sySemicolon:
            if (Depth = 0) and (Cut >= 0) then
            begin
              Result := Result + TrimRight(Copy(Params, P + 1, Cut - P));
              P := L.Tok.Start;
              Cut := -1;
            end;
        end;
      L.Next;
    end;
  finally
    L.Free;
  end;
  if Cut >= 0 then Result := Result + TrimRight(Copy(Params, P + 1, Cut - P))
  else Result := Result + Copy(Params, P + 1, MaxInt);
end;

{ a parameter list's names as a call's arguments: '(A, B)'; '' none }
function ArgsOf(const Params: string): string;
var
  L: TList;
  I: Integer;
begin
  Result := '';
  L := TList.Create;
  try
    ReadParamList(Params, L);
    for I := 0 to L.Count - 1 do
    begin
      if I > 0 then Result := Result + ', ';
      Result := Result + TRefParam(L[I]).Name;
    end;
  finally
    FreeObjects(L);
    L.Free;
  end;
  if Result <> '' then Result := '(' + Result + ')';
end;

{ the Code Explorer's section (1 private, 2 protected, 3 public) of an ancestor's method: a method
  of a class's first section - published to the parser, public unless the class keeps run-time type
  information, as TObject does not - public too }
function AccessOf(V: TCIVisibility): Integer;
begin
  case V of
    cvPrivate: Result := 1;
    cvProtected: Result := 2;
  else
    Result := 3;
  end;
end;

function CompareItemNames(Item1, Item2: Pointer): Integer;
begin
  Result := CompareText(TCIMethodItem(Item1).Name, TCIMethodItem(Item2).Name);
end;

function PlanImplementMethods(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string;
  Items: TList; Access: Integer; CallInherited: Boolean; out Error: string): Boolean;
const
  { the sections in the order a class has them: private, protected, public, published }
  Sections: array[0..3] of Integer = (1, 2, 3, 0);
var
  U: TUnitInfo;
  L: TList;
  I, J, A, Start, P: Integer;
  It: TCIMethodItem;
  EOL, Decls, Dirs, Head, Body, Text: string;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  U := ParseText(CI, FileName, Source);
  L := TList.Create;
  try
    if U.FindTypeSym(ClassName, [tyClass]) = nil then
    begin
      Error := Format('%s is not declared in this unit', [ClassName]);
      Exit;
    end;
    for I := 0 to Items.Count - 1 do L.Add(Items[I]);
    if L.Count = 0 then
    begin
      Error := 'Nothing is chosen';
      Exit;
    end;
    L.Sort(CompareItemNames);
    { the declarations: one insertion for each section }
    for J := 0 to High(Sections) do
    begin
      Decls := '';
      for I := 0 to L.Count - 1 do
      begin
        It := TCIMethodItem(L[I]);
        if It.FromInterface then A := Access else A := AccessOf(It.Visibility);
        if A <> Sections[J] then Continue;
        Dirs := '';
        if It.Overload then Dirs := Dirs + ' overload;';
        if not It.FromInterface then Dirs := Dirs + ' override;';
        if It.CallConv <> '' then Dirs := Dirs + ' ' + It.CallConv + ';';
        if Decls <> '' then Decls := Decls + EOL;
        Decls := Decls + '    ' + MethodItemText(It) + ';' + Dirs;
      end;
      if Decls = '' then Continue;
      if not ExplorerMemberEdit(U, ClassName, Sections[J], False, Decls, Start, Text, Error) then Exit;
      R.AddEdit(FileName, Start, 0, Text);
    end;
    { the bodies, where the Code Explorer puts a new method's }
    for I := 0 to L.Count - 1 do
    begin
      It := TCIMethodItem(L[I]);
      Head := It.Keyword + ' ' + ClassName + '.' + It.Name;
      if It.Params <> '' then Head := Head + '(' + WithoutDefaults(It.Params) + ')';
      if It.ResultType <> '' then Head := Head + ': ' + It.ResultType;
      Body := EOL;
      if CallInherited and not It.FromInterface and not It.Abstract then
        if System.Pos('destructor', It.Keyword) > 0 then Body := EOL + '  inherited;' + EOL
        else if System.Pos('constructor', It.Keyword) > 0 then Body := '  inherited ' + It.Name + ArgsOf(It.Params) + ';' + EOL + EOL
        else if It.ResultType <> '' then Body := '  Result := inherited ' + It.Name + ArgsOf(It.Params) + ';' + EOL
        else Body := '  inherited;' + EOL;
      P := ExplorerBodyPos(U, ClassName, It.Name);
      if P < 0 then
      begin
        Error := Format('Could not find where to implement %s.%s', [ClassName, It.Name]);
        Exit;
      end;
      R.AddEdit(FileName, P, 0, Head + ';' + EOL + 'begin' + EOL + Body + 'end;' + EOL + EOL);
    end;
    if L.Count = 1 then R.Title := Format('Implement %s.%s', [ClassName, TCIMethodItem(L[0]).Name])
    else R.Title := Format('Implement %d methods in %s', [L.Count, ClassName]);
    Result := True;
  finally
    L.Free;
    U.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Encapsulate Field }

function EncapsulateTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; out PropName, TypeText: string;
  out Error: string): Boolean;
var
  U: TUnitInfo;
  S, M: TSymbol;
begin
  Result := False;
  Error := '';
  PropName := '';
  TypeText := '';
  R.SetSource(FileName, Source);
  if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) or (Info.Kind <> ckField) or Info.Local then
  begin
    Error := 'Put the caret on a field of a class';
    Exit;
  end;
  if not Info.OwnerIsClass then
  begin
    Error := Format('%s is a field of %s, which is no class: it can have no property', [Info.Name, Info.Owner]);
    Exit;
  end;
  if (Info.FileName = '') or not InList(Files, Info.FileName) then
  begin
    Error := Format('%s is declared in %s, which is not part of the project', [SymbolTitle(Info),
      ExtractFileName(Info.FileName)]);
    Exit;
  end;
  if Info.Visibility = cvPublished then
  begin
    Error := Format('%s is published: its form finds it by its name', [SymbolTitle(Info)]);
    Exit;
  end;
  U := ParseText(CI, Info.FileName, R.Source(Info.FileName));
  try
    S := U.FindTypeSym(Info.Owner, [tyClass]);
    M := nil;
    if S <> nil then M := S.TypeDesc.Members.Find(Info.Name);
    if (M = nil) or (M.Kind <> skField) or (M.TypeEnd <= M.TypeStart) then
    begin
      Error := Format('The declaration of %s is not found', [SymbolTitle(Info)]);
      Exit;
    end;
    TypeText := Trim(Copy(U.Source, M.TypeStart + 1, M.TypeEnd - M.TypeStart));
  finally
    U.Free;
  end;
  PropName := Info.Name;
  if (Length(PropName) > 1) and (UpCase(PropName[1]) = 'F') and (PropName[2] in ['A'..'Z']) then
    Delete(PropName, 1, 1);
  Result := True;
end;

{ the token that opens the bracket closed at I, going back (-1: none) }
function OpenOf(RT: TRawToks; I: Integer): Integer;
var
  D: Integer;
begin
  D := 0;
  Result := I;
  while Result >= 0 do
  begin
    if RT.IsSy(Result, syRParen) or RT.IsSy(Result, syRBracket) then Inc(D)
    else if RT.IsSy(Result, syLParen) or RT.IsSy(Result, syLBracket) then
    begin
      Dec(D);
      if D = 0 then Exit;
    end;
    Dec(Result);
  end;
end;

{ why the name at token K - a field that becomes a property - cannot stay as it is written: its
  address taken, an argument a routine assigns, a part of it assigned (Cat: its type); '': it can }
function PropertyCannot(CI: TCodeInsight; const FileName, Src: string; RT: TRawToks; K: Integer;
  Cat: TCITypeCategory): string;
var
  S, E, NameTok, ArgIdx, Known: Integer;
  Item: TCIItem;
  L: TList;
begin
  Result := '';
  { the chain it is in: back over the names, calls and indexes before it, on over those after it }
  S := K;
  while (S >= 2) and RT.IsSy(S - 1, syDot) do
  begin
    S := S - 2;
    while (S >= 0) and (RT.IsSy(S, syRParen) or RT.IsSy(S, syRBracket) or RT.IsSy(S, syCaret)) do
      if RT.IsSy(S, syCaret) then Dec(S) else S := OpenOf(RT, S) - 1;
    if S < 0 then Exit;
  end;
  E := K;
  while E + 1 < RT.N do
    if RT.IsSy(E + 1, syDot) and (E + 2 < RT.N) and (RT.T[E + 2].Kind = tkIdent) then Inc(E, 2)
    else if RT.IsSy(E + 1, syCaret) then Inc(E)
    else if RT.IsSy(E + 1, syLBracket) or RT.IsSy(E + 1, syLParen) then
    begin
      E := RT.MatchClose(E + 1);
      if E < 0 then Exit;
    end
    else
      Break;
  if RT.IsSy(S - 1, syAt) then
  begin
    Result := 'has its address taken';
    Exit;
  end;
  if RT.IsSy(E + 1, syAssign) then
  begin
    if (E > K) and (Cat in [tcRecord, tcObject, tcArray, tcString, tcShortString, tcVariant, tcSet, tcUnknown]) then
      Result := 'has a part of it assigned';
    Exit;
  end;
  if (RT.IsSy(S - 1, syLParen) or RT.IsSy(S - 1, syComma)) and (RT.IsSy(E + 1, syComma) or RT.IsSy(E + 1, syRParen)) and
    RT.ArgumentOf(S, NameTok, ArgIdx) then
  begin
    Known := KnownAssigns(RT.Txt(NameTok), ArgIdx);
    if Known = 1 then Result := 'is passed to ' + RT.Txt(NameTok) + ', which assigns it'
    else if (Known < 0) and CI.FindDeclaration(FileName, Src, RT.EndOf(NameTok), Item) then
    begin
      if IsRoutineKind(Item.Kind) and (Item.Params <> '') then
      begin
        L := TList.Create;
        try
          ReadParamList(Item.Params, L);
          if (ArgIdx < L.Count) and ((TRefParam(L[ArgIdx]).Modifier = 'var') or (TRefParam(L[ArgIdx]).Modifier = 'out')) then
            Result := 'is passed as a ' + TRefParam(L[ArgIdx]).Modifier + ' parameter';
        finally
          FreeObjects(L);
          L.Free;
        end;
      end;
    end
    else if Known < 0 then
      Result := 'is passed to ' + RT.Txt(NameTok) + ', which code insight does not know';
  end;
end;

function PlanEncapsulateField(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  const PropName, TypeText: string; Access: Integer; Setter: Boolean; out Error: string): Boolean;
var
  U, U2: TUnitInfo;
  RT, RT2: TRawToks;
  S, Field: TSymbol;
  Rou, M: TRoutineSym;
  P: TCIPlace;
  I, Start, BodyPos: Integer;
  FieldName, SetName, Src, Src2, EOL, Why, Priv, Decl, Text, Writes: string;
  Cat: TCITypeCategory;
  Inside: Boolean;

  procedure Load(const F: string);
  begin
    if (U2 <> nil) and SameText(U2.FileName, F) then Exit;
    FreeAndNil(U2);
    FreeAndNil(RT2);
    Src2 := R.Source(F);
    U2 := ParseText(CI, F, Src2);
    RT2 := TRawToks.Create(Src2, False);
  end;

  function Taken(const Name: string): Boolean;
  begin
    Result := not SameText(Name, Info.Name) and (S.TypeDesc.Members.Find(Name) <> nil);
    if Result then Error := Format('%s already has a member named %s', [Info.Owner, Name]);
  end;

begin
  Result := False;
  Error := CheckNewName(PropName);
  if Error <> '' then Exit;
  if SameText(PropName, Info.Name) then FieldName := 'F' + PropName else FieldName := Info.Name;
  SetName := 'Set' + PropName;
  Src := R.Source(Info.FileName);
  EOL := DetectEOL(Src);
  U := ParseText(CI, Info.FileName, Src);
  RT := TRawToks.Create(Src, False);
  U2 := nil;
  RT2 := nil;
  try
    S := U.FindTypeSym(Info.Owner, [tyClass]);
    Field := nil;
    if S <> nil then Field := S.TypeDesc.Members.Find(Info.Name);
    if (Field = nil) or (Field.Kind <> skField) then
    begin
      Error := Format('The declaration of %s is not found', [SymbolTitle(Info)]);
      Exit;
    end;
    if Taken(PropName) or Taken(FieldName) or (Setter and Taken(SetName)) then Exit;
    Cat := CI.TypeCategory(Info.FileName, Src, Field.DeclStart, TypeText);
    { the places: in the class's methods the field, everywhere else the property }
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl then Continue;
      Load(P.FileName);
      Rou := RoutineAround(U2, P.Start, P.Start);
      M := nil;
      if Rou <> nil then M := MethodOf(Rou);
      Inside := (M <> nil) and SameText(M.ClassQual, Info.Owner) and SameText(P.FileName, Info.FileName);
      if Inside then
      begin
        if not SameText(FieldName, Info.Name) then R.AddEdit(P.FileName, P.Start, P.Len, FieldName);
        Continue;
      end;
      Why := PropertyCannot(CI, P.FileName, Src2, RT2, RT2.FirstAt(P.Start), Cat);
      if Why <> '' then
      begin
        Error := Format('%s(%d): %s cannot be a property there: it %s', [ExtractFileName(P.FileName), P.Line,
          Info.Name, Why]);
        Exit;
      end;
      if not SameText(PropName, Info.Name) then R.AddEdit(P.FileName, P.Start, P.Len, PropName);
    end;
    { the field private, the setter with it; the property in its section (the private one with them) }
    Priv := '';
    if Field.Visibility = viPrivate then
    begin
      if not SameText(FieldName, Info.Name) then R.AddEdit(Info.FileName, Field.DeclStart, Length(Info.Name), FieldName);
    end
    else
    begin
      if not RemoveDecl(R, Info.FileName, Src, RT, Field.DeclStart, -1, False) then
      begin
        Error := Format('Could not take the declaration of %s out', [SymbolTitle(Info)]);
        Exit;
      end;
      Priv := '    ' + FieldName + ': ' + TypeText + ';';
    end;
    if Setter then
    begin
      if Priv <> '' then Priv := Priv + EOL;
      Priv := Priv + '    procedure ' + SetName + '(const Value: ' + TypeText + ');';
      Writes := SetName;
    end
    else
      Writes := FieldName;
    Decl := '    property ' + PropName + ': ' + TypeText + ' read ' + FieldName + ' write ' + Writes + ';';
    if Access = 1 then
    begin
      if Priv <> '' then Priv := Priv + EOL;
      Priv := Priv + Decl;
      Decl := '';
    end;
    if Priv <> '' then
    begin
      if not ExplorerMemberEdit(U, Info.Owner, 1, Field.Visibility <> viPrivate, Priv, Start, Text, Error) then Exit;
      R.AddEdit(Info.FileName, Start, 0, Text);
    end;
    if Decl <> '' then
    begin
      if not ExplorerMemberEdit(U, Info.Owner, Access, False, Decl, Start, Text, Error) then Exit;
      R.AddEdit(Info.FileName, Start, 0, Text);
    end;
    if Setter then
    begin
      BodyPos := ExplorerBodyPos(U, Info.Owner, SetName);
      if BodyPos < 0 then
      begin
        Error := Format('Could not find where to implement %s.%s', [Info.Owner, SetName]);
        Exit;
      end;
      R.AddEdit(Info.FileName, BodyPos, 0, 'procedure ' + Info.Owner + '.' + SetName + '(const Value: ' + TypeText + ');' +
        EOL + 'begin' + EOL + '  ' + FieldName + ' := Value;' + EOL + 'end;' + EOL + EOL);
    end;
    R.Title := Format('Encapsulate %s as the property %s', [SymbolTitle(Info), PropName]);
    Result := True;
  finally
    RT2.Free;
    U2.Free;
    RT.Free;
    U.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Complete Case }

function PlanCompleteCase(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K, C, J, OfTok, EndTok, ElseTok, Ins, Depth, E, A, B, I: Integer;
  Values, Missing: TStringList;
  Covered: array of Boolean;
  TypeName, EOL, Ind, Text: string;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  Values := TStringList.Create;
  Missing := TStringList.Create;
  try
    { the case statement around Pos: the innermost one of the statements }
    C := -1;
    EndTok := -1;
    for K := 0 to RT.N - 1 do
    begin
      if RT.T[K].Start > Pos then Break;
      if not RT.IsKw(K, kwCase) or not InStatements(U, RT.T[K].Start) then Continue;
      J := BlockEnd(RT, K);
      if (J >= 0) and (Pos <= RT.EndOf(J)) then
      begin
        C := K;
        EndTok := J;
      end;
    end;
    if C < 0 then
    begin
      Error := 'Put the caret in a case statement';
      Exit;
    end;
    { its expression, up to of }
    OfTok := C + 1;
    Depth := 0;
    while (OfTok < EndTok) and not ((Depth = 0) and RT.IsKw(OfTok, kwOf)) do
    begin
      if RT.IsSy(OfTok, syLParen) or RT.IsSy(OfTok, syLBracket) then Inc(Depth)
      else if RT.IsSy(OfTok, syRParen) or RT.IsSy(OfTok, syRBracket) then Dec(Depth);
      Inc(OfTok);
    end;
    if (OfTok >= EndTok) or (OfTok = C + 1) then
    begin
      Error := 'The case statement has no expression';
      Exit;
    end;
    if not CI.EnumValues(FileName, Source, RT.T[C + 1].Start, RT.EndOf(OfTok - 1), TypeName, Values) then
    begin
      Error := 'The case''s expression is not of an enumerated type that code insight knows';
      Exit;
    end;
    SetLength(Covered, Values.Count);
    for I := 0 to High(Covered) do Covered[I] := False;
    { the branches: their labels up to ":" (values, ranges), their statements; an else part }
    ElseTok := -1;
    K := OfTok + 1;
    while K < EndTok do
    begin
      if RT.IsKw(K, kwElse) then
      begin
        ElseTok := K;
        Break;
      end;
      Depth := 0;
      while (K < EndTok) and not ((Depth = 0) and RT.IsSy(K, syColon)) do
      begin
        if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then Inc(Depth)
        else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then Dec(Depth)
        else if (Depth = 0) and (RT.T[K].Kind = tkIdent) and not RT.IsSy(K - 1, syDot) then
        begin
          A := Values.IndexOf(RT.Txt(K));
          if A >= 0 then
          begin
            B := A;
            if RT.IsSy(K + 1, syDotDot) and (K + 2 < EndTok) and (RT.T[K + 2].Kind = tkIdent) then
            begin
              B := Values.IndexOf(RT.Txt(K + 2));
              if B < A then B := A;
              Inc(K, 2);
            end;
            for I := A to B do Covered[I] := True;
          end;
        end;
        Inc(K);
      end;
      if K >= EndTok then Break;
      E := StatementEnd(RT, K + 1);
      if E >= EndTok then Break;
      if RT.IsSy(E, sySemicolon) then K := E + 1 else K := E;
    end;
    for I := 0 to Values.Count - 1 do
      if not Covered[I] then Missing.Add(Values[I]);
    if Missing.Count = 0 then
    begin
      Error := Format('Every value of %s has its branch', [TypeName]);
      Exit;
    end;
    if ElseTok >= 0 then Ins := ElseTok else Ins := EndTok;
    { indented as the first branch, else two more than the case }
    if (OfTok + 1 < Ins) and FirstOnLine(Source, RT.T[OfTok + 1].Start) then Ind := IndentAt(Source, RT.T[OfTok + 1].Start)
    else Ind := IndentAt(Source, RT.T[C].Start) + '  ';
    { the statement before them ends with ";" }
    if not RT.IsSy(Ins - 1, sySemicolon) and not RT.IsKw(Ins - 1, kwOf) then
      R.AddEdit(FileName, RT.EndOf(Ins - 1), 0, ';');
    Text := '';
    if FirstOnLine(Source, RT.T[Ins].Start) then
    begin
      for I := 0 to Missing.Count - 1 do Text := Text + Ind + Missing[I] + ': ;' + EOL;
      R.AddEdit(FileName, LineStartOf(Source, RT.T[Ins].Start), 0, Text);
    end
    else
    begin
      for I := 0 to Missing.Count - 1 do Text := Text + Missing[I] + ': ; ';
      R.AddEdit(FileName, RT.T[Ins].Start, 0, Text);
    end;
    if Missing.Count = 1 then R.Title := Format('Complete the case of %s: %s', [TypeName, Missing[0]])
    else R.Title := Format('Complete the case of %s: %d branches', [TypeName, Missing.Count]);
    Result := True;
  finally
    Missing.Free;
    Values.Free;
    U.Free;
    RT.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Extract Constant }

{ the value Extract Constant names: the literal at A (A = B) - a number with its sign, a string -,
  else the selection A .. B, a constant expression that is a whole operand where it stands; in
  statements }
function ConstRange(CI: TCodeInsight; const FileName, Source: string; RT: TRawToks; U: TUnitInfo; A, B: Integer;
  out K0, K1: Integer; out Error: string): Boolean;
var
  K, Depth, I: Integer;
  L: TList;
begin
  Result := False;
  K0 := -1;
  K1 := -1;
  if A = B then
  begin
    if not LiteralAt(RT, A, K0, K1) then
    begin
      K := RT.FirstAt(A);
      if (K >= RT.N) or (RT.T[K].Start > A) or (RT.T[K].Kind <> tkNumber) then Dec(K);
      if (K < 0) or (K >= RT.N) or (RT.T[K].Kind <> tkNumber) or (A > RT.EndOf(K)) then
      begin
        Error := 'Put the caret on a number or a string, or select a constant expression';
        Exit;
      end;
      K0 := K;
      K1 := K;
      if RT.IsSy(K - 1, syMinus) and not EndsOperand(RT, K - 2) then K0 := K - 1;
    end;
  end
  else
  begin
    if not SelTokens(RT, A, B, K0, K1) then
    begin
      Error := 'Select a constant expression';
      Exit;
    end;
    if RT.IsSy(K1, sySemicolon) then Dec(K1);
    Depth := 0;
    for K := K0 to K1 do
    begin
      if not ((RT.T[K].Kind in [tkNumber, tkString, tkIdent]) or
        ((RT.T[K].Kind = tkSymbol) and (RT.T[K].Symbol in [syPlus, syMinus, syStar, sySlash, syLParen, syRParen])) or
        ((RT.T[K].Kind = tkKeyword) and (RT.T[K].Keyword in [kwDiv, kwMod, kwShl, kwShr, kwAnd, kwOr, kwXor, kwNot]))) then
        Depth := -100
      else if RT.IsSy(K, syLParen) then Inc(Depth)
      else if RT.IsSy(K, syRParen) then Dec(Depth);
      if Depth < 0 then Break;
    end;
    if (K1 < K0) or (Depth <> 0) then
    begin
      Error := 'The selection is not a constant expression';
      Exit;
    end;
    { its names: constants }
    L := TList.Create;
    try
      CI.NameUses(FileName, Source, RT.T[K0].Start, RT.EndOf(K1), L);
      for I := 0 to L.Count - 1 do
        if not (TCINameUse(L[I]).Kind in [ckConst, ckEnumValue]) then
        begin
          Error := Format('%s is not a constant', [TCINameUse(L[I]).Name]);
          Exit;
        end;
    finally
      FreeObjects(L);
      L.Free;
    end;
    if not WholeOperand(RT, K0, K1) then
    begin
      Error := 'The selection is not a whole part of the expression around it';
      Exit;
    end;
  end;
  if not InStatements(U, RT.T[K0].Start) then
  begin
    Error := 'Extract Constant works on a value in statements';
    Exit;
  end;
  Result := True;
end;

function ConstTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer; out Expr, Name: string;
  out Local: Boolean; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1, I: Integer;
begin
  Expr := '';
  Name := '';
  Local := False;
  Error := '';
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    Result := ConstRange(CI, FileName, Source, RT, U, A, B, K0, K1, Error);
    if not Result then Exit;
    Expr := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    Local := BodyAround(U, RT.T[K0].Start, RT.T[K0].Start) <> nil;
    { a name: a string's words after S (SysUtils' way), a number's digits after Value }
    if RT.T[K0].Kind = tkString then
      Name := 'S' + Copy(NameForString(Expr), 4, MaxInt)
    else if K0 = K1 - Ord(RT.IsSy(K0, syMinus)) then
    begin
      Name := 'Value';
      if RT.IsSy(K0, syMinus) then Name := Name + 'Minus';
      for I := 1 to Length(Expr) do
        if Expr[I] in ['0'..'9', 'A'..'Z', 'a'..'z'] then Name := Name + Expr[I]
        else if Expr[I] = '.' then Name := Name + '_';
    end
    else
      Name := 'NewConstant';
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanExtractConstant(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name: string; Where: Integer; ReplaceAll: Boolean; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1, N, K, Lo, Hi: Integer;
  Rou: TRoutineSym;
  Expr, Decl: string;
begin
  Result := False;
  Error := CheckNewName(Name);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    if not ConstRange(CI, FileName, Source, RT, U, A, B, K0, K1, Error) then Exit;
    Expr := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    Rou := BodyAround(U, RT.T[K0].Start, RT.T[K0].Start);
    if (Where = 0) and (Rou = nil) then Where := 1;
    if U.IsProgram and (Where = 2) then Where := 1;
    { the name free where it is declared }
    if (Where = 0) and RoutineDeclares(Rou, Name) then
    begin
      Error := Format('%s already declares %s', [Rou.Name, Name]);
      Exit;
    end;
    if (Where > 0) and ((U.IntfSyms.Find(Name) <> nil) or (U.ImplSyms.Find(Name) <> nil)) then
    begin
      Error := Format('%s already declares %s', [U.Name, Name]);
      Exit;
    end;
    Decl := Name + ' = ' + Expr + ';';
    if Where = 0 then Result := AddLocalDecl(R, FileName, Source, RT, Rou, kwConst, Decl)
    else Result := AddSectionDecl(R, FileName, Source, RT, U, kwConst, Where = 2, False, Decl);
    if not Result then
    begin
      Error := 'Could not find where to declare the constant';
      Exit;
    end;
    R.AddEdit(FileName, RT.T[K0].Start, RT.EndOf(K1) - RT.T[K0].Start, Name);
    if ReplaceAll then
    begin
      { the same value again: in the routine's statements, else in the unit's }
      if Where = 0 then
      begin
        Lo := RT.FirstAt(Rou.BodyStart);
        Hi := RT.FirstAt(Rou.BodyEnd);
      end
      else
      begin
        Lo := 0;
        Hi := RT.N;
      end;
      N := K1 - K0 + 1;
      K := Lo;
      while K + N <= Hi do
        if (K <> K0) and SameTokens(RT, K, K0, N) and not RT.IsSy(K - 1, syDot) and InStatements(U, RT.T[K].Start) and
          WholeOperand(RT, K, K + N - 1) and not ((N = 1) and RT.IsSy(K - 1, syMinus) and RT.IsSy(K0, syMinus)) then
        begin
          R.AddEdit(FileName, RT.T[K].Start, RT.EndOf(K + N - 1) - RT.T[K].Start, Name);
          Inc(K, N);
        end
        else
          Inc(K);
    end;
    R.Title := Format('Extract constant %s = %s', [Name, Expr]);
  finally
    U.Free;
    RT.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Convert to Format }

{ the expression around the token K: back and on over its operands and operators, up to what ends an
  expression (an assignment, a statement's or an argument's end, a comparison, a reserved word) }
procedure ExprAround(RT: TRawToks; K: Integer; out K0, K1: Integer);

  function Stops(I: Integer): Boolean;
  begin
    with RT.T[I] do
      if Kind = tkSymbol then
        Result := Symbol in [syAssign, sySemicolon, syComma, syColon, syEqual, syNotEqual, syLess, syLessEq, syGreater,
          syGreaterEq, syDotDot]
      else if Kind = tkKeyword then
        Result := not (Keyword in [kwDiv, kwMod, kwAnd, kwOr, kwXor, kwShl, kwShr, kwNot, kwNil, kwString])
      else
        Result := False;
  end;

begin
  K0 := K;
  while K0 > 0 do
  begin
    if RT.IsSy(K0 - 1, syRParen) or RT.IsSy(K0 - 1, syRBracket) then
    begin
      K0 := OpenOf(RT, K0 - 1);
      if K0 < 0 then K0 := 0;
    end
    else if RT.IsSy(K0 - 1, syLParen) or RT.IsSy(K0 - 1, syLBracket) or Stops(K0 - 1) then
      Break
    else
      Dec(K0);
  end;
  K1 := K;
  while K1 + 1 < RT.N do
  begin
    if RT.IsSy(K1 + 1, syLParen) or RT.IsSy(K1 + 1, syLBracket) then
    begin
      K1 := RT.MatchClose(K1 + 1);
      if K1 < 0 then K1 := RT.N - 1;
    end
    else if RT.IsSy(K1 + 1, syRParen) or RT.IsSy(K1 + 1, syRBracket) or Stops(K1 + 1) then
      Break
    else
      Inc(K1);
  end;
end;

{ a text's literal tokens S .. E for a format: % doubled }
function FormatText(RT: TRawToks; S, E: Integer): string;
var
  K, I: Integer;
  T: string;
begin
  Result := '';
  for K := S to E do
  begin
    T := RT.Txt(K);
    if (T <> '') and (T[1] = '#') then
    begin
      if StrToIntDef(Copy(T, 2, MaxInt), -1) = 37 then T := '''%%''';
    end
    else
    begin
      I := Length(T);
      while I > 0 do
      begin
        if T[I] = '%' then Insert('%', T, I);
        Dec(I);
      end;
    end;
    Result := Result + T;
  end;
end;

{ Piece (a literal's text) after the format so far: quoted parts that meet joined }
function JoinFormat(const Fmt, Piece: string): string;
begin
  if (Fmt <> '') and (Fmt[Length(Fmt)] = '''') and (Piece <> '') and (Piece[1] = '''') then
    Result := Copy(Fmt, 1, Length(Fmt) - 1) + Copy(Piece, 2, MaxInt)
  else
    Result := Fmt + Piece;
end;

{ the arguments of the call whose brackets are the tokens Open and Close: their first and last
  tokens into Firsts and Lasts }
procedure CallArgs(RT: TRawToks; Open, Close: Integer; Firsts, Lasts: TList);
var
  J, Depth, S: Integer;
begin
  Depth := 0;
  S := Open + 1;
  for J := Open + 1 to Close do
    if (J = Close) or ((Depth = 0) and RT.IsSy(J, syComma)) then
    begin
      if J > S then
      begin
        Firsts.Add(Pointer(S));
        Lasts.Add(Pointer(J - 1));
      end;
      S := J + 1;
    end
    else if RT.IsSy(J, syLParen) or RT.IsSy(J, syLBracket) then Inc(Depth)
    else if RT.IsSy(J, syRParen) or RT.IsSy(J, syRBracket) then Dec(Depth);
end;

{ the format of the operand S .. E and the value it gives the format: IntToStr(X) %d with X,
  FloatToStr(X) %g with X, IntToHex(X, N) %.Nx with X, else %s with the operand }
function OperandFormat(RT: TRawToks; const Source: string; S, E: Integer; out Arg: string): string;
var
  Firsts, Lasts: TList;
  Name, N: string;
  F, L: Integer;
begin
  Result := '%s';
  Arg := Copy(Source, RT.T[S].Start + 1, RT.EndOf(E) - RT.T[S].Start);
  if not ((RT.T[S].Kind = tkIdent) and RT.IsSy(S + 1, syLParen) and (RT.MatchClose(S + 1) = E)) then Exit;
  Name := RT.Txt(S);
  Firsts := TList.Create;
  Lasts := TList.Create;
  try
    CallArgs(RT, S + 1, E, Firsts, Lasts);
    if (Firsts.Count = 1) and SameText(Name, 'IntToStr') then Result := '%d'
    else if (Firsts.Count = 1) and SameText(Name, 'FloatToStr') then Result := '%g'
    else if (Firsts.Count = 2) and SameText(Name, 'IntToHex') and (Firsts[1] = Lasts[1]) then
    begin
      N := RT.Txt(Integer(Firsts[1]));
      if (N <> '') and (N[1] in ['0'..'9']) then Result := '%.' + N + 'x';
    end;
    if Result <> '%s' then
    begin
      F := Integer(Firsts[0]);
      L := Integer(Lasts[0]);
      Arg := Copy(Source, RT.T[F].Start + 1, RT.EndOf(L) - RT.T[F].Start);
    end;
  finally
    Lasts.Free;
    Firsts.Free;
  end;
end;

function PlanConvertToFormat(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K, K0, K1, S, E, Depth, J: Integer;
  Fmt, Args, Arg, T: string;
  HasText, AllText: Boolean;
  Names: TStringList;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  Names := TStringList.Create;
  try
    if A <> B then
    begin
      if not SelTokens(RT, A, B, K0, K1) then K1 := K0 - 1;
      if (K1 >= K0) and RT.IsSy(K1, sySemicolon) then Dec(K1);
    end
    else
    begin
      K := RT.FirstAt(A);
      if (K >= RT.N) or (RT.T[K].Start > A) then Dec(K);
      if (K < 0) or (K >= RT.N) then
      begin
        Error := 'Put the caret on a string concatenation';
        Exit;
      end;
      ExprAround(RT, K, K0, K1);
    end;
    if (K1 < K0) or not InStatements(U, RT.T[K0].Start) then
    begin
      Error := 'Put the caret on a string concatenation in statements';
      Exit;
    end;
    { operands joined by + alone }
    Depth := 0;
    for K := K0 to K1 do
      if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then Inc(Depth)
      else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then Dec(Depth)
      else if (Depth = 0) and (OpPrec(RT, K) > 0) and not (RT.IsSy(K, syPlus) and EndsOperand(RT, K - 1)) then
      begin
        Error := 'The expression is more than a concatenation of strings';
        Exit;
      end;
    T := CI.ExprTypeName(FileName, Source, RT.T[K0].Start, RT.EndOf(K1));
    if not SameText(T, 'string') then
    begin
      Error := 'The expression is not a concatenation of strings';
      Exit;
    end;
    { each operand: a text, else a value of the format }
    Fmt := '';
    Args := '';
    HasText := False;
    S := K0;
    Depth := 0;
    for K := K0 to K1 + 1 do
    begin
      if K <= K1 then
      begin
        if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then Inc(Depth)
        else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then Dec(Depth);
        if not ((Depth = 0) and RT.IsSy(K, syPlus)) then Continue;
      end;
      E := K - 1;
      if E < S then
      begin
        Error := 'The concatenation has an empty part';
        Exit;
      end;
      AllText := True;
      for J := S to E do
        if RT.T[J].Kind <> tkString then AllText := False;
      if AllText then
      begin
        Fmt := JoinFormat(Fmt, FormatText(RT, S, E));
        HasText := True;
      end
      else
      begin
        Fmt := JoinFormat(Fmt, '''' + OperandFormat(RT, Source, S, E, Arg) + '''');
        if Args <> '' then Args := Args + ', ';
        Args := Args + Arg;
      end;
      S := K + 1;
    end;
    if Args = '' then
    begin
      Error := 'The expression is all text: there is nothing to format';
      Exit;
    end;
    if not HasText then
    begin
      Error := 'The concatenation has no text of its own';
      Exit;
    end;
    R.AddEdit(FileName, RT.T[K0].Start, RT.EndOf(K1) - RT.T[K0].Start, 'Format(' + Fmt + ', [' + Args + '])');
    { Format is SysUtils' }
    if not SameText(U.Name, 'SysUtils') and (U.IntfUses.IndexOf('SysUtils') < 0) and (U.ImplUses.IndexOf('SysUtils') < 0) then
    begin
      Names.Add('SysUtils');
      if not AddUsesNames(R, FileName, Source, RT, U, Names, not U.IsProgram and (RT.T[K0].Start > U.ImplOfs)) then
      begin
        Error := 'Could not add SysUtils to the uses clause';
        Exit;
      end;
      R.Notes.Add('SysUtils goes into the uses clause: Format is its.');
    end;
    R.Title := 'Convert to Format';
    Result := True;
  finally
    Names.Free;
    U.Free;
    RT.Free;
  end;
end;

end.
