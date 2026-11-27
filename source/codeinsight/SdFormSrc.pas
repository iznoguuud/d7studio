{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormSrc;

// D7 Studio - source text helpers used by the form designer to keep a form
// unit (and the project file) in sync. All functions are pure text
// transformations: token aware, case-insensitive on identifiers, they keep
// the rest of the text byte-for-byte and reuse the file's line-ending style.
// On failure they return False and leave Source untouched; they never raise.

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasParser;

function FSGetUnitName(const Source: string): string;
function FSRenameUnit(var Source: string; const NewName: string): Boolean;
function FSFindClass(const Source, AClassName: string; out DeclLine: Integer): Boolean;
function FSGetAncestorName(const Source, AClassName: string): string;
function FSFieldExists(const Source, AClassName, FieldName: string): Boolean;
function FSAddField(var Source: string; const AClassName, FieldName, FieldType: string): Boolean;
function FSRemoveField(var Source: string; const AClassName, FieldName: string): Boolean;
function FSRenameField(var Source: string; const AClassName, OldName, NewName: string): Boolean;
function FSSetFieldType(var Source: string; const AClassName, FieldName, NewType: string): Boolean;
procedure FSGetFields(const Source, AClassName: string; Names, Types: TStrings);
function FSMethodExists(const Source, AClassName, MethodName: string): Boolean;
procedure FSGetMethods(const Source, AClassName: string; Names, Signatures: TStrings);
function FSNormalizeSignature(IsFunction: Boolean; const Params, ResultType: string): string;
function FSAddMethod(var Source: string; const AClassName, MethodName, Params, ResultType: string;
  out BodyLine, BodyCol: Integer): Boolean;
function FSFindMethodBody(const Source, AClassName, MethodName: string; out BodyLine, BodyCol: Integer): Boolean;
{ Class completion (Delphi's Shift+Ctrl+C): the class whose declaration or one of
  whose method implementations holds Offset (0-based) is completed - a declared method without an
  implementation gets an empty one (not abstract or external ones), an implemented method without
  a declaration is declared (private), an accessor a property names that the class lacks is
  added (a field, or a getter / setter with its implementation), and with FinishProperties a
  property without read and write gets "read FName write SetName" with the field and the setter.
  BodyLine / BodyCol (1-based): the first new empty body, else the first new implementation.
  False: no class there or nothing to complete. }
function FSCompleteClass(var Source: string; Offset: Integer; FinishProperties: Boolean;
  out BodyLine, BodyCol: Integer): Boolean;
{ the class declared around Ofs (0-based), or the class of the method implemented around it; nil:
  none }
function ClassAtOffset(U: TUnitInfo; Ofs: Integer): TSymbol;
function FSRenameMethod(var Source: string; const AClassName, OldName, NewName: string): Boolean;
function FSRemoveEmptyMethods(var Source: string; const AClassName: string; Removed: TStrings): Integer;
function FSRenameClass(var Source: string; const OldClassName, NewClassName: string): Boolean;
function FSRenameFormVar(var Source: string; const AClassName, OldVarName, NewVarName: string): Boolean;
procedure FSGetUses(const Source: string; InInterface: Boolean; Units: TStrings);
{ the unit names of every uses clause of a source - a unit's two, a program's or a library's one;
  from its tokens, without parsing it (both sides of a conditional directive count) }
procedure UsesClauseNames(const Source: string; Units: TStrings);
{ the parts of a text that take the units Names out of its uses clause whose word begins at
  UsesOfs: a pair of offsets A, B (B excluded) in Ranges for each unit, with its comma - the
  whole clause with its lines when none stays. False: a unit is not in the clause, or a compiler
  directive between its units would go with one }
function UsesRemoveRanges(const Source: string; UsesOfs: Integer; Names: TStrings; Ranges: TList): Boolean;
function FSAddUses(var Source: string; const UnitName: string; InInterface: Boolean): Boolean;

{ The units of a project source: its uses clause, or the contains clause of a package (.dpk) -
  the Dpr* routines below work on either }
procedure DprGetUnits(const Source: string; Units, Paths, FormNames: TStrings);
{ the packages a package source requires (empty for a program or library) }
procedure DpkGetRequires(const Source: string; Packages: TStrings);
{ a package into / out of the requires clause of a package source (a new clause goes before the
  contains clause); adding one that is there already is True and changes nothing }
function DpkAddRequires(var Source: string; const Package: string): Boolean;
function DpkRemoveRequires(var Source: string; const Package: string): Boolean;
function DprAddUnit(var Source: string; const UnitName, RelPath, FormName: string): Boolean;
function DprRemoveUnit(var Source: string; const UnitName: string): Boolean;
function DprRenameUnit(var Source: string; const OldUnitName, NewUnitName, NewRelPath: string): Boolean;
procedure DprGetCreateForms(const Source: string; ClassNames, VarNames: TStrings);
function DprAddCreateForm(var Source: string; const FormClassName, FormVarName: string): Boolean;
function DprRemoveCreateForm(var Source: string; const FormVarName: string): Boolean;
function DprRenameCreateForm(var Source: string; const OldClass, OldVar, NewClass, NewVar: string): Boolean;
function DprSetProgramName(var Source: string; const NewName: string): Boolean;
{ "Application.<Prop> := '...';" of the main block (Project Options | Application: Title,
  HelpFile): its value, '' when there is none; setting '' removes the statement, a new one goes
  after "Application.Initialize;" }
function DprGetAppProp(const Source, Prop: string): string;
function DprSetAppProp(var Source: string; const Prop, Value: string): Boolean;
// a compiler directive (the DESCRIPTION of Linker | EXE Description) on the line after the
// program's header - the copy of a project source that is compiled
function DprAddDirective(var Source: string; const Directive: string): Boolean;
{ the entry of the project's To-Do file, %ToDo 'RelName' in braces (Delphi's entry of a
  project file that is no unit): before the uses clause (a package's
  requires, else contains clause) with an empty line after it; without a clause after the
  heading - in the text's own line ends }
function DprAddTodoFile(var Source: string; const RelName: string): Boolean;
{ The resource scripts of a project source: its $R (or $RESOURCE) directives with two file names,
  Delphi's $R 'x.res' 'x.rc' in braces - the .res the compiler links (dcc32 reads only that name)
  and the .rc the IDE compiles into it -, in their order; the names as written (from the
  project's folder), unquoted. $R with one name ($R *.res) and the switch $R+ / $R- are none. }
procedure DprGetResScripts(const Source: string; ResFiles, RcFiles: TStrings);
{ The .res files a project source links: the first name of each of its $R (or $RESOURCE)
  directives - $R *.res, a resource script's .res, a file of its own -, in their order, as
  written (from the project's folder; * stands for the project's name), unquoted }
procedure DprGetResFiles(const Source: string; ResFiles: TStrings);
{ a script into the project source, where Delphi 7 puts one: after the last script, else - a
  program or library - after the uses clause, on the line before a $R that comes next ($R *.res),
  a package after its first $R (without one after the heading); one of the same .rc already there
  is True and changes nothing }
function DprAddResScript(var Source: string; const RelRes, RelRc: string): Boolean;
{ the script of RelRc out of the project source - its line when nothing else stands on it }
function DprRemoveResScript(var Source: string; const RelRc: string): Boolean;
{ the script of RelRc with the names NewRelRes and NewRelRc (Save Project As into another folder) }
function DprRenameResScript(var Source: string; const RelRc, NewRelRes, NewRelRc: string): Boolean;

implementation

uses
  SdPasLex, SdCIEngine;

{ ---------------------------------------------------------------------------- }
{ text helpers (offsets are 0-based; the lines: SdPasLex's LineStartOf, LineEndOf, NextLineStart,
  IndentAt, IsBlank, WholeLines) }

{ from Ofs to the end of the line: only blanks, optionally followed by one comment }
function TailIsBlankOrComment(const S: string; Ofs: Integer): Boolean;
var
  I, E: Integer;
begin
  Result := True;
  E := LineEndOf(S, Ofs);
  I := Ofs;
  while (I < E) and (S[I + 1] in [' ', #9]) do Inc(I);
  if I >= E then Exit;
  if (S[I + 1] = '/') and (I + 1 < E) and (S[I + 2] = '/') then Exit;
  if (S[I + 1] = '{') and (I + 1 < E) and (S[I + 2] <> '$') then
  begin
    while (I < E) and (S[I + 1] <> '}') do Inc(I);
    if I < E then
    begin
      Inc(I);
      while (I < E) and (S[I + 1] in [' ', #9]) do Inc(I);
      if I >= E then Exit;
    end;
  end;
  Result := False;
end;

{ ---------------------------------------------------------------------------- }
{ edit list }

type
  TEditRec = record
    Ofs, Del: Integer;
    Ins: string;
  end;

  TEdits = class
  private
    FItems: array of TEditRec;
    FCount: Integer;
  public
    procedure Add(Ofs, Del: Integer; const Ins: string);
    function HasAt(Ofs: Integer): Boolean;
    procedure Apply(var S: string);
    property Count: Integer read FCount;
  end;

procedure TEdits.Add(Ofs, Del: Integer; const Ins: string);
begin
  if FCount >= Length(FItems) then SetLength(FItems, FCount + 8);
  FItems[FCount].Ofs := Ofs;
  FItems[FCount].Del := Del;
  FItems[FCount].Ins := Ins;
  Inc(FCount);
end;

function TEdits.HasAt(Ofs: Integer): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FCount - 1 do
    if FItems[I].Ofs = Ofs then Exit;
  Result := False;
end;

procedure TEdits.Apply(var S: string);
var
  Order: array of Integer;
  I, J, T: Integer;
begin
  SetLength(Order, FCount);
  for I := 0 to FCount - 1 do Order[I] := I;
  // descending by offset; for equal offsets the later added edit is applied first
  for I := 1 to FCount - 1 do
  begin
    T := Order[I];
    J := I - 1;
    while (J >= 0) and ((FItems[Order[J]].Ofs < FItems[T].Ofs) or
      ((FItems[Order[J]].Ofs = FItems[T].Ofs) and (Order[J] < T))) do
    begin
      Order[J + 1] := Order[J];
      Dec(J);
    end;
    Order[J + 1] := T;
  end;
  for I := 0 to FCount - 1 do
    with FItems[Order[I]] do
    begin
      if Del > 0 then Delete(S, Ofs + 1, Del);
      if Ins <> '' then Insert(Ins, S, Ofs + 1);
    end;
end;

{ deletes the declaration [A, B); whole lines when it stands alone }
procedure DeleteDecl(E: TEdits; const S: string; A, B: Integer);
var
  LS, J: Integer;
begin
  LS := LineStartOf(S, A);
  if IsBlank(S, LS, A) and TailIsBlankOrComment(S, B) then
    E.Add(LS, NextLineStart(S, B) - LS, '')
  else
  begin
    J := B;
    while (J < Length(S)) and (S[J + 1] = ' ') do Inc(J);
    E.Add(A, J - A, '');
  end;
end;

{ the edit that takes field M out of its group of names "A, M, B: T" - Prev, Next: its
  neighbours in the group (one of them at least) }
procedure UngroupEdit(E: TEdits; M, Prev, Next: TSymbol);
begin
  if Next <> nil then
    E.Add(M.DeclStart, Next.DeclStart - M.DeclStart, '')
  else
    E.Add(Prev.DeclStart + Length(Prev.Name), M.DeclStart + Length(M.Name) - (Prev.DeclStart + Length(Prev.Name)), '');
end;

{ ---------------------------------------------------------------------------- }
{ parsed view }

function ParseU(const Source: string): TUnitInfo;
begin
  Result := TUnitInfo.Create;
  ParseSource(Result, Source, False, nil, nil);
end;

var
  ViewUnit: TUnitInfo;          // the text ParsedView parsed last (its Source) and its symbols

{ the parsed view of Source for a query that only reads it: kept for the next query of the same
  text (the form designer asks several of one text); the caller never frees it }
function ParsedView(const Source: string): TUnitInfo;
begin
  if (ViewUnit = nil) or (ViewUnit.Source <> Source) then
  begin
    FreeAndNil(ViewUnit);
    ViewUnit := ParseU(Source);
  end;
  Result := ViewUnit;
end;


function FindClass(U: TUnitInfo; const AClassName: string): TSymbol;
begin
  Result := U.FindTypeSym(AClassName, [tyClass]);
end;

function FindMember(D: TTypeDesc; const Name: string; Kind: TSymKind): TSymbol;
begin
  Result := D.Members.Find(Name);
  while (Result <> nil) and (Result.Kind <> Kind) do Result := D.Members.FindNext(Result);
end;

function MemberStart(M: TSymbol): Integer;
begin
  if M is TRoutineSym then Result := TRoutineSym(M).HeadStart else Result := M.DeclStart;
end;

function SameGroup(A, B: TSymbol): Boolean;
begin
  Result := (A.Kind = skField) and (B.Kind = skField) and (A.TypeStart > 0) and (A.TypeStart = B.TypeStart);
end;

function TypeNorm(U: TUnitInfo; A, B: Integer): string;
begin
  if (B > A) and (B <= Length(U.Source)) then
    Result := LowerCase(NormalizeText(PChar(U.Source) + A, B - A, 0))
  else
    Result := '';
end;

function SigOfParams(U: TUnitInfo; Params: TList): string;
var
  I: Integer;
  P: TSymbol;
  T, M: string;
begin
  Result := '';
  if Params = nil then Exit;
  for I := 0 to Params.Count - 1 do
  begin
    P := TSymbol(Params[I]);
    M := ParamModifier(P);
    T := TypeNorm(U, P.TypeStart, P.TypeEnd);
    if (M <> '') and (T <> '') then T := M + ' ' + T
    else if M <> '' then T := M;
    if I > 0 then Result := Result + ';';
    Result := Result + T;
  end;
end;

function SigOfRoutine(U: TUnitInfo; R: TRoutineSym): string;
begin
  EnsureParams(R);
  if sfFunction in R.Flags then
    Result := 'function(' + SigOfParams(U, R.Params) + '):' + TypeNorm(U, R.TypeStart, R.TypeEnd)
  else if sfConstructor in R.Flags then
    Result := 'constructor(' + SigOfParams(U, R.Params) + ')'
  else if sfDestructor in R.Flags then
    Result := 'destructor(' + SigOfParams(U, R.Params) + ')'
  else
    Result := 'procedure(' + SigOfParams(U, R.Params) + ')';
end;

{ token index of the unit / program name; -1 if none }
function HeaderNameTok(RT: TRawToks): Integer;
var
  I: Integer;
begin
  Result := -1;
  I := RT.NextCode(-1);
  if I >= RT.N then Exit;
  if RT.IsKw(I, kwUnit) or RT.IsKw(I, kwProgram) or RT.IsKw(I, kwLibrary) or RT.IsId(I, 'package') then
  begin
    I := RT.NextCode(I);
    if RT.IsIdent(I) then Result := I;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ unit header }

function FSGetUnitName(const Source: string): string;
var
  RT: TRawToks;
  I: Integer;
begin
  Result := '';
  try
    RT := TRawToks.Create(Source);
    try
      I := HeaderNameTok(RT);
      if I >= 0 then Result := RT.Txt(I);
    finally
      RT.Free;
    end;
  except
    Result := '';
  end;
end;

function ReplaceHeaderName(var Source: string; const NewName: string): Boolean;
var
  RT: TRawToks;
  I: Integer;
  S: string;
begin
  Result := False;
  if not IsValidIdent(NewName) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      I := HeaderNameTok(RT);
      if I < 0 then Exit;
      S := Source;
      Delete(S, RT.T[I].Start + 1, RT.T[I].Len);
      Insert(NewName, S, RT.T[I].Start + 1);
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function FSRenameUnit(var Source: string; const NewName: string): Boolean;
begin
  Result := ReplaceHeaderName(Source, NewName);
end;

function DprSetProgramName(var Source: string; const NewName: string): Boolean;
begin
  Result := ReplaceHeaderName(Source, NewName);
end;

{ ---------------------------------------------------------------------------- }
{ class queries }

function FSFindClass(const Source, AClassName: string; out DeclLine: Integer): Boolean;
var
  C: TSymbol;
begin
  Result := False;
  DeclLine := 0;
  try
    C := FindClass(ParsedView(Source), AClassName);
    if C <> nil then
    begin
      DeclLine := C.Line;
      Result := True;
    end;
  except
    Result := False;
  end;
end;

function FSGetAncestorName(const Source, AClassName: string): string;
var
  C: TSymbol;
begin
  Result := '';
  try
    C := FindClass(ParsedView(Source), AClassName);
    if (C <> nil) and (C.TypeDesc.Ancestors <> nil) and (C.TypeDesc.Ancestors.Count > 0) then
      Result := C.TypeDesc.Ancestors[0];
  except
    Result := '';
  end;
end;

{ the class AClassName of Source has a member Name of that Kind }
function MemberExists(const Source, AClassName, Name: string; Kind: TSymKind): Boolean;
var
  C: TSymbol;
begin
  try
    C := FindClass(ParsedView(Source), AClassName);
    Result := (C <> nil) and (FindMember(C.TypeDesc, Name, Kind) <> nil);
  except
    Result := False;
  end;
end;

function FSFieldExists(const Source, AClassName, FieldName: string): Boolean;
begin
  Result := MemberExists(Source, AClassName, FieldName, skField);
end;

function FSMethodExists(const Source, AClassName, MethodName: string): Boolean;
begin
  Result := MemberExists(Source, AClassName, MethodName, skRoutine);
end;

procedure FSGetFields(const Source, AClassName: string; Names, Types: TStrings);
var
  U: TUnitInfo;
  C, M: TSymbol;
  I: Integer;
begin
  try
    U := ParsedView(Source);
    C := FindClass(U, AClassName);
    if C = nil then Exit;
    for I := 0 to C.TypeDesc.Members.Count - 1 do
    begin
      M := C.TypeDesc.Members[I];
      if (M.Kind = skField) and (M.Visibility = viPublished) then
      begin
        if Names <> nil then Names.Add(M.Name);
        if Types <> nil then
        begin
          if M.TypeEnd > M.TypeStart then
            Types.Add(NormalizeText(PChar(U.Source) + M.TypeStart, M.TypeEnd - M.TypeStart, 0))
          else
            Types.Add('');
        end;
      end;
    end;
  except
  end;
end;

procedure FSGetMethods(const Source, AClassName: string; Names, Signatures: TStrings);
var
  U: TUnitInfo;
  C, M: TSymbol;
  I: Integer;
begin
  try
    U := ParsedView(Source);
    C := FindClass(U, AClassName);
    if C = nil then Exit;
    for I := 0 to C.TypeDesc.Members.Count - 1 do
    begin
      M := C.TypeDesc.Members[I];
      if (M.Kind = skRoutine) and (M.Visibility = viPublished) and (M is TRoutineSym) then
      begin
        if Names <> nil then Names.Add(M.Name);
        if Signatures <> nil then Signatures.Add(SigOfRoutine(U, TRoutineSym(M)));
      end;
    end;
  except
  end;
end;

function FSNormalizeSignature(IsFunction: Boolean; const Params, ResultType: string): string;
var
  U: TUnitInfo;
  L: TList;
  Sig: string;
begin
  Sig := '';
  try
    U := TUnitInfo.Create;
    L := TList.Create;
    try
      U.Source := Params;
      ParseParamText(U, Params, L);
      Sig := SigOfParams(U, L);
    finally
      FreeSymList(L);
      U.Free;
    end;
  except
    Sig := '';
  end;
  if IsFunction then
    Result := 'function(' + Sig + '):' + LowerCase(NormalizeText(PChar(ResultType), Length(ResultType), 0))
  else
    Result := 'procedure(' + Sig + ')';
end;

{ ---------------------------------------------------------------------------- }
{ fields }

function DefaultLimit(D: TTypeDesc): Integer;
begin
  Result := D.FirstVisOfs;
  if Result = 0 then Result := D.EndOfs;
end;

{ where the member declaration Text goes into class C (D its type) of S: on a line of its own
  after Last, indented as Last when Last starts its line; with no Last after the class header,
  indented as Any (the first member, nil: none) or one level in from the class. Ofs: the place,
  Ins: the text to insert there. }
procedure MemberInsertion(const S, EOL, Text: string; C: TSymbol; D: TTypeDesc; Last, Any: TSymbol;
  out Ofs: Integer; out Ins: string);
var
  ClassIndent, Indent: string;
  Limit, LS: Integer;
begin
  Limit := DefaultLimit(D);
  ClassIndent := IndentAt(S, LineStartOf(S, C.DeclStart));
  if Last <> nil then
  begin
    LS := LineStartOf(S, MemberStart(Last));
    if IsBlank(S, LS, MemberStart(Last)) then Indent := IndentAt(S, LS) else Indent := ClassIndent + '  ';
    Ofs := NextLineStart(S, Last.FullEnd);
    if (Ofs > Limit) or not TailIsBlankOrComment(S, Last.FullEnd) then
    begin
      Ofs := Last.FullEnd;
      Ins := EOL + Indent + Text;
    end
    else
      Ins := Indent + Text + EOL;
  end
  else
  begin
    if (Any <> nil) and IsBlank(S, LineStartOf(S, MemberStart(Any)), MemberStart(Any)) then
      Indent := IndentAt(S, LineStartOf(S, MemberStart(Any)))
    else
      Indent := ClassIndent + '  ';
    Ofs := NextLineStart(S, D.HeaderEnd);
    if (Ofs > Limit) or ((Any <> nil) and (Ofs > MemberStart(Any))) then
    begin
      { something else follows the header on its line }
      Ofs := D.HeaderEnd;
      Ins := EOL + Indent + Text + EOL + ClassIndent;
    end
    else
      Ins := Indent + Text + EOL;
  end;
end;

function FSAddField(var Source: string; const AClassName, FieldName, FieldType: string): Boolean;
var
  U: TUnitInfo;
  C, M, Last, Any: TSymbol;
  D: TTypeDesc;
  S, Ins: string;
  I, Ofs, Limit: Integer;
begin
  Result := False;
  if not IsValidIdent(FieldName) or (Trim(FieldType) = '') then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      D := C.TypeDesc;
      if D.EndOfs = 0 then Exit;
      if D.Members.Find(FieldName) <> nil then Exit;
      S := Source;
      { after the last field of the default section }
      Limit := DefaultLimit(D);
      Last := nil;
      Any := nil;
      for I := 0 to D.Members.Count - 1 do
      begin
        M := D.Members[I];
        if MemberStart(M) >= Limit then Break;
        if Any = nil then Any := M;
        if M.Kind = skField then Last := M;
      end;
      MemberInsertion(S, DetectEOL(S), FieldName + ': ' + FieldType + ';', C, D, Last, Any, Ofs, Ins);
      Insert(Ins, S, Ofs + 1);
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

procedure GroupOf(D: TTypeDesc; M: TSymbol; out Prev, Next: TSymbol);
var
  I: Integer;
begin
  Prev := nil;
  Next := nil;
  for I := 0 to D.Members.Count - 1 do
    if D.Members[I] = M then
    begin
      if (I > 0) and SameGroup(D.Members[I - 1], M) then Prev := D.Members[I - 1];
      if (I < D.Members.Count - 1) and SameGroup(D.Members[I + 1], M) then Next := D.Members[I + 1];
      Exit;
    end;
end;

function FSRemoveField(var Source: string; const AClassName, FieldName: string): Boolean;
var
  U: TUnitInfo;
  C, M, Prev, Next: TSymbol;
  S: string;
  E: TEdits;
begin
  Result := False;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      M := FindMember(C.TypeDesc, FieldName, skField);
      if M = nil then Exit;
      S := Source;
      E := TEdits.Create;
      try
        GroupOf(C.TypeDesc, M, Prev, Next);
        if (Prev <> nil) or (Next <> nil) then
          UngroupEdit(E, M, Prev, Next)
        else
          DeleteDecl(E, S, M.DeclStart, M.FullEnd);
        E.Apply(S);
      finally
        E.Free;
      end;
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

function FSRenameField(var Source: string; const AClassName, OldName, NewName: string): Boolean;
var
  U: TUnitInfo;
  C, M: TSymbol;
  S: string;
begin
  Result := False;
  if not IsValidIdent(NewName) then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      M := FindMember(C.TypeDesc, OldName, skField);
      if M = nil then Exit;
      if not SameText(OldName, NewName) and (C.TypeDesc.Members.Find(NewName) <> nil) then Exit;
      S := Source;
      Delete(S, M.DeclStart + 1, Length(M.Name));
      Insert(NewName, S, M.DeclStart + 1);
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

function FSSetFieldType(var Source: string; const AClassName, FieldName, NewType: string): Boolean;
var
  U: TUnitInfo;
  C, M, Prev, Next: TSymbol;
  S, EOL, Indent: string;
  E: TEdits;
  Ofs: Integer;
begin
  Result := False;
  if Trim(NewType) = '' then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      M := FindMember(C.TypeDesc, FieldName, skField);
      if (M = nil) or (M.TypeEnd <= M.TypeStart) then Exit;
      S := Source;
      EOL := DetectEOL(S);
      E := TEdits.Create;
      try
        GroupOf(C.TypeDesc, M, Prev, Next);
        if (Prev = nil) and (Next = nil) then
          E.Add(M.TypeStart, M.TypeEnd - M.TypeStart, NewType)
        else
        begin
          // take the field out of its group and declare it on a line of its own
          UngroupEdit(E, M, Prev, Next);
          Indent := IndentAt(S, LineStartOf(S, M.DeclStart));
          Ofs := NextLineStart(S, M.FullEnd);
          if TailIsBlankOrComment(S, M.FullEnd) and (LineEndOf(S, M.FullEnd) < Length(S)) then
            E.Add(Ofs, 0, Indent + M.Name + ': ' + NewType + ';' + EOL)
          else
            E.Add(M.FullEnd, 0, EOL + Indent + M.Name + ': ' + NewType + ';');
        end;
        E.Apply(S);
      finally
        E.Free;
      end;
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ methods }

function BodyPosOf(U: TUnitInfo; R: TRoutineSym; out BodyLine, BodyCol: Integer): Boolean;
var
  BL, BC, NL, LE, J: Integer;
  S: string;
begin
  Result := False;
  BodyLine := 0;
  BodyCol := 0;
  if (R = nil) or not (sfHasBody in R.Flags) then Exit;
  S := U.Source;
  BL := U.LineOfOffset(R.BodyStart, BC);
  NL := NextLineStart(S, R.BodyStart);
  if (sfBodyClosed in R.Flags) and (R.BodyEnd <= NL) then
  begin
    // 'begin end' on one line
    BodyLine := BL;
    BodyCol := BC + 6;
    Result := True;
    Exit;
  end;
  BodyLine := BL + 1;
  LE := LineEndOf(S, NL);
  J := NL;
  while (J < LE) and (S[J + 1] in [' ', #9]) do Inc(J);
  if J >= LE then BodyCol := BC + 2 else BodyCol := J - NL + 1;
  Result := True;
end;

function FSFindMethodBody(const Source, AClassName, MethodName: string; out BodyLine, BodyCol: Integer): Boolean;
var
  U: TUnitInfo;
begin
  BodyLine := 0;
  BodyCol := 0;
  try
    U := ParsedView(Source);
    Result := BodyPosOf(U, U.FindImpl(AClassName, MethodName), BodyLine, BodyCol);
  except
    Result := False;
  end;
end;

{ offset where new method implementations are inserted; -1 if impossible }
function ImplInsertOfs(U: TUnitInfo; const S: string; out MidLine: Boolean): Integer;
var
  K, LS: Integer;
begin
  Result := -1;
  MidLine := False;
  if U.IsProgram then
  begin
    if U.MainBegin > 0 then K := U.MainBegin
    else if U.FinalEndOfs > 0 then K := U.FinalEndOfs
    else K := Length(S);
  end
  else
  begin
    if U.ImplOfs = MaxInt then Exit;
    if U.InitOfs > 0 then K := U.InitOfs
    else if U.FinalOfs > 0 then K := U.FinalOfs
    else if U.MainBegin > 0 then K := U.MainBegin
    else if U.FinalEndOfs > 0 then K := U.FinalEndOfs
    else K := Length(S);
  end;
  LS := LineStartOf(S, K);
  if IsBlank(S, LS, K) then
    Result := LS
  else
  begin
    Result := K;
    MidLine := True;
  end;
end;

function FSAddMethod(var Source: string; const AClassName, MethodName, Params, ResultType: string;
  out BodyLine, BodyCol: Integer): Boolean;
var
  U, U2: TUnitInfo;
  C, M, Last: TSymbol;
  D: TTypeDesc;
  E: TEdits;
  S, EOL, Head, Decl, Prefix, Ins: string;
  I, Ofs, Limit, InsOfs, PrevLS: Integer;
  HasImpl, MidLine: Boolean;
begin
  Result := False;
  BodyLine := 0;
  BodyCol := 0;
  if not IsValidIdent(MethodName) then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      D := C.TypeDesc;
      if D.EndOfs = 0 then Exit;
      M := FindMember(D, MethodName, skRoutine);
      HasImpl := U.FindImpl(C.Name, MethodName) <> nil;
      if (M <> nil) and HasImpl then
      begin
        Result := BodyPosOf(U, U.FindImpl(C.Name, MethodName), BodyLine, BodyCol);
        Exit;
      end;
      if (M = nil) and (D.Members.Find(MethodName) <> nil) then Exit;   // name used by a field/property
      S := Source;
      EOL := DetectEOL(S);
      if Trim(ResultType) <> '' then Head := 'function ' else Head := 'procedure ';
      Decl := MethodName;
      if Trim(Params) <> '' then Decl := Decl + '(' + Params + ')';
      if Trim(ResultType) <> '' then Decl := Decl + ': ' + ResultType;
      E := TEdits.Create;
      try
        if M = nil then
        begin
          { after the last member of the default section }
          Limit := DefaultLimit(D);
          Last := nil;
          for I := 0 to D.Members.Count - 1 do
          begin
            if MemberStart(D.Members[I]) >= Limit then Break;
            Last := D.Members[I];
          end;
          MemberInsertion(S, EOL, Head + Decl + ';', C, D, Last, nil, Ofs, Ins);
          E.Add(Ofs, 0, Ins);
        end;
        if not HasImpl then
        begin
          InsOfs := ImplInsertOfs(U, S, MidLine);
          if InsOfs < 0 then Exit;
          Prefix := '';
          if MidLine then
            Prefix := EOL + EOL
          else if InsOfs > 0 then
          begin
            PrevLS := PrevLineStart(S, InsOfs);
            if not IsBlank(S, PrevLS, InsOfs) then Prefix := EOL;
          end;
          if (InsOfs = Length(S)) and (InsOfs > 0) and not (S[InsOfs] in [#10, #13]) then
            Prefix := EOL + EOL;
          E.Add(InsOfs, 0, Prefix + Head + C.Name + '.' + Decl + ';' + EOL + 'begin' + EOL + EOL +
            'end;' + EOL + EOL);
        end;
        E.Apply(S);
      finally
        E.Free;
      end;
      U2 := ParseU(S);
      try
        if BodyPosOf(U2, U2.FindImpl(C.Name, MethodName), BodyLine, BodyCol) then
        begin
          Source := S;
          Result := True;
        end;
      finally
        U2.Free;
      end;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

{ --- class completion --- }

function ClassAtOffset(U: TUnitInfo; Ofs: Integer): TSymbol;

  function InTable(T: TSymTable): TSymbol;
  var
    I: Integer;
  begin
    Result := nil;
    for I := 0 to T.Count - 1 do
      if IsStructDecl(T[I], [tyClass]) and (T[I].DeclStart <= Ofs) and (T[I].TypeDesc.EndOfs > 0) and
        (Ofs <= T[I].TypeDesc.EndOfs + 3) then
      begin
        Result := T[I];
        Exit;
      end;
  end;

var
  I: Integer;
  R: TRoutineSym;
begin
  Result := InTable(U.IntfSyms);
  if Result = nil then Result := InTable(U.ImplSyms);
  if Result <> nil then Exit;
  for I := 0 to U.ImplRoutines.Count - 1 do
  begin
    R := TRoutineSym(U.ImplRoutines[I]);
    if (R.ClassQual <> '') and (Pos('.', R.ClassQual) = 0) and (R.HeadStart <= Ofs) and (Ofs <= R.BodyEnd) then
    begin
      Result := FindClass(U, R.ClassQual);
      Exit;
    end;
  end;
end;


{ the heading after the keyword as written: name, parameters, result type }
function HeadingText(const S: string; R: TRoutineSym): string;
begin
  Result := Copy(S, R.DeclStart + 1, R.DeclEnd - R.DeclStart);
end;

{ the words of a property declaration after its type: read X, write Y }
procedure PropertyAccessors(const S: string; P: TRoutineSym; out ReadName, WriteName: string);
var
  I, J: Integer;
  Words: TStringList;
begin
  ReadName := '';
  WriteName := '';
  Words := TStringList.Create;
  try
    I := P.DeclEnd + 1;
    while I <= P.FullEnd do
    begin
      if S[I] in ['A'..'Z', 'a'..'z', '_'] then
      begin
        J := I;
        while (J <= P.FullEnd) and (S[J] in ['A'..'Z', 'a'..'z', '_', '0'..'9', '.']) do Inc(J);
        Words.Add(Copy(S, I, J - I));
        I := J;
      end
      else
        Inc(I);
    end;
    for I := 0 to Words.Count - 2 do
      if SameText(Words[I], 'read') then ReadName := Words[I + 1]
      else if SameText(Words[I], 'write') then WriteName := Words[I + 1];
  finally
    Words.Free;
  end;
end;

function FSCompleteClass(var Source: string; Offset: Integer; FinishProperties: Boolean;
  out BodyLine, BodyCol: Integer): Boolean;
var
  U, U2: TUnitInfo;
  C, M: TSymbol;
  D: TTypeDesc;
  E: TEdits;
  S, EOL, ClsIndent, MemIndent, Fields, Methods, Impls, FirstBody, ReadName, WriteName, PType,
    Name, Spec: string;
  Impl: TList;
  I, K, FieldOfs, MethodOfs, ImplOfs, PrivKw, Limit: Integer;
  R, Last: TRoutineSym;
  Found, MidLine, HasPrivate: Boolean;
  Toks: TRawToks;

  function HasMember(const AName: string): Boolean;
  begin
    Result := D.Members.Find(AName) <> nil;
  end;

  function Declared(const AName: string): Boolean;
  begin
    Result := HasMember(AName) or (Pos(#10 + MemIndent + 'procedure ' + AName + '(', #10 + Methods) > 0) or
      (Pos(#10 + MemIndent + 'function ' + AName + ':', #10 + Methods) > 0) or
      (Pos(#10 + MemIndent + AName + ':', #10 + Fields) > 0);
  end;

  procedure AddField(const AName, AType: string);
  begin
    if not Declared(AName) then Fields := Fields + MemIndent + AName + ': ' + AType + ';' + EOL;
  end;

  procedure AddImpl(const Head, Body: string);
  begin
    Impls := Impls + EOL + Head + EOL + 'begin' + EOL + Body + 'end;' + EOL;
    if (FirstBody = '') and (Body = EOL) then FirstBody := Head;
  end;

  { a getter or setter of property P that the class lacks: declared and implemented }
  procedure AddAccessor(const AName: string; IsWrite: Boolean; const FieldName: string);
  begin
    if Declared(AName) then Exit;
    if IsWrite then
    begin
      Methods := Methods + MemIndent + 'procedure ' + AName + '(const Value: ' + PType + ');' + EOL;
      if FieldName <> '' then
        AddImpl('procedure ' + C.Name + '.' + AName + '(const Value: ' + PType + ');', '  ' + FieldName + ' := Value;' + EOL)
      else
        AddImpl('procedure ' + C.Name + '.' + AName + '(const Value: ' + PType + ');', EOL);
    end
    else
    begin
      Methods := Methods + MemIndent + 'function ' + AName + ': ' + PType + ';' + EOL;
      AddImpl('function ' + C.Name + '.' + AName + ': ' + PType + ';', EOL);
    end;
  end;

begin
  Result := False;
  BodyLine := 0;
  BodyCol := 0;
  try
    U := ParseU(Source);
    try
      C := ClassAtOffset(U, Offset);
      if (C = nil) or (C.TypeDesc.EndOfs = 0) then Exit;
      D := C.TypeDesc;
      S := Source;
      EOL := DetectEOL(S);
      ClsIndent := IndentAt(S, LineStartOf(S, C.DeclStart));
      MemIndent := ClsIndent + '  ';
      Fields := '';
      Methods := '';
      Impls := '';
      FirstBody := '';
      Impl := TList.Create;
      try
        { properties: specifiers that are missing, accessors the class lacks }
        for I := 0 to D.Members.Count - 1 do
        begin
          M := D.Members[I];
          if (M.Kind <> skProperty) or (sfArrayProp in M.Flags) or (M.TypeStart = 0) then Continue;
          R := TRoutineSym(M);
          PType := Trim(Copy(S, R.TypeStart + 1, R.TypeEnd - R.TypeStart));
          PropertyAccessors(S, R, ReadName, WriteName);
          if (ReadName = '') and (WriteName = '') then
          begin
            if not FinishProperties then Continue;
            ReadName := 'F' + R.Name;
            WriteName := 'Set' + R.Name;
            Impl.Add(Pointer(R));          // its specifiers go in at DeclEnd (below)
          end;
          if (ReadName <> '') and not Declared(ReadName) then
            if SameText(Copy(ReadName, 1, 3), 'Get') then AddAccessor(ReadName, False, '')
            else AddField(ReadName, PType);
          if (WriteName <> '') and not Declared(WriteName) then
            if SameText(Copy(WriteName, 1, 3), 'Set') then
            begin
              if (ReadName <> '') and not SameText(Copy(ReadName, 1, 3), 'Get') then AddAccessor(WriteName, True, ReadName)
              else AddAccessor(WriteName, True, '');
            end
            else AddField(WriteName, PType);
        end;
        E := TEdits.Create;
        try
          for I := 0 to Impl.Count - 1 do
          begin
            R := TRoutineSym(Impl[I]);
            E.Add(R.DeclEnd, 0, ' read F' + R.Name + ' write Set' + R.Name);
          end;
          Impl.Clear;
          { implemented methods without a declaration: declared }
          U.GetImpls(Impl, C.Name, '');
          for I := 0 to Impl.Count - 1 do
          begin
            R := TRoutineSym(Impl[I]);
            if (R.Name <> '') and (FindMember(D, R.Name, skRoutine) = nil) and not Declared(R.Name) then
              Methods := Methods + MemIndent + RoutineKeyword(R) + ' ' + HeadingText(S, R) + ';' + EOL;
          end;
          { declared methods without an implementation: an empty one each }
          for I := 0 to D.Members.Count - 1 do
          begin
            M := D.Members[I];
            if (M.Kind <> skRoutine) or not (M is TRoutineSym) or (sfAbstract in M.Flags) or (sfExternal in M.Flags) then Continue;
            Found := False;
            for K := 0 to Impl.Count - 1 do
              if SameText(TRoutineSym(Impl[K]).Name, M.Name) and (not (sfOverload in M.Flags) or
                (SigOfRoutine(U, TRoutineSym(Impl[K])) = SigOfRoutine(U, TRoutineSym(M)))) then Found := True;
            if not Found then
              AddImpl(RoutineKeyword(M) + ' ' + C.Name + '.' + HeadingText(S, TRoutineSym(M)) + ';', EOL);
          end;
          if (E.Count = 0) and (Fields = '') and (Methods = '') and (Impls = '') then Exit;
          { the private section: fields after its fields, methods after its last member; a new
            one after the default section }
          Limit := DefaultLimit(D);
          FieldOfs := -1;
          MethodOfs := -1;
          HasPrivate := False;
          for I := 0 to D.Members.Count - 1 do
          begin
            M := D.Members[I];
            if M.Visibility <> viPrivate then Continue;
            HasPrivate := True;
            if (M.Kind = skField) and (MemberStart(M) > FieldOfs) then FieldOfs := MemberStart(M);
            if NextLineStart(S, M.FullEnd) > MethodOfs then MethodOfs := NextLineStart(S, M.FullEnd);
          end;
          PrivKw := -1;
          if not HasPrivate then
          begin
            Toks := TRawToks.Create(S);
            try
              for I := 0 to Toks.N - 1 do
                if (Toks.T[I].Start > D.HeaderEnd) and (Toks.T[I].Start < D.EndOfs) and Toks.IsId(I, 'private') then
                begin
                  PrivKw := NextLineStart(S, Toks.T[I].Start);
                  Break;
                end;
            finally
              Toks.Free;
            end;
          end;
          if HasPrivate then
          begin
            if FieldOfs >= 0 then
            begin
              { after the last private field (its group of names ends with the type) }
              for I := 0 to D.Members.Count - 1 do
              begin
                M := D.Members[I];
                if (M.Visibility = viPrivate) and (M.Kind = skField) and (NextLineStart(S, M.FullEnd) > FieldOfs) then
                  FieldOfs := NextLineStart(S, M.FullEnd);
              end;
            end
            else
            begin
              { no field yet: before the first private member }
              FieldOfs := MaxInt;
              for I := 0 to D.Members.Count - 1 do
                if (D.Members[I].Visibility = viPrivate) and (LineStartOf(S, MemberStart(D.Members[I])) < FieldOfs) then
                  FieldOfs := LineStartOf(S, MemberStart(D.Members[I]));
            end;
            if Fields <> '' then E.Add(FieldOfs, 0, Fields);
            if Methods <> '' then E.Add(MethodOfs, 0, Methods);
          end
          else if PrivKw >= 0 then
            E.Add(PrivKw, 0, Fields + Methods)
          else if (Fields <> '') or (Methods <> '') then
            E.Add(LineStartOf(S, Limit), 0, ClsIndent + 'private' + EOL + Fields + Methods);
          { the implementations: after the class's last one, else where new ones go }
          if Impls <> '' then
          begin
            Last := nil;
            for I := 0 to Impl.Count - 1 do
              if (Last = nil) or (TRoutineSym(Impl[I]).BodyEnd > Last.BodyEnd) then Last := TRoutineSym(Impl[I]);
            if (Last <> nil) and (Last.BodyEnd > 0) then
              E.Add(NextLineStart(S, Last.BodyEnd), 0, Impls)
            else
            begin
              ImplOfs := ImplInsertOfs(U, S, MidLine);
              if ImplOfs < 0 then Exit;
              if MidLine then E.Add(ImplOfs, 0, EOL + Copy(Impls, Length(EOL) + 1, MaxInt) + EOL)
              else E.Add(ImplOfs, 0, Copy(Impls, Length(EOL) + 1, MaxInt) + EOL);
            end;
          end;
          E.Apply(S);
        finally
          E.Free;
        end;
      finally
        Impl.Free;
      end;
      { the caret: the first new empty body, else the first new implementation }
      if FirstBody = '' then
      begin
        K := Pos(EOL + 'begin', Impls);
        if K > 0 then FirstBody := Copy(Impls, Length(EOL) + 1, K - Length(EOL) - 1);
      end;
      if FirstBody <> '' then
      begin
        Spec := Copy(FirstBody, Pos('.', FirstBody) + 1, MaxInt);
        Name := '';
        K := 1;
        while (K <= Length(Spec)) and (Spec[K] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do Inc(K);
        Name := Copy(Spec, 1, K - 1);
        U2 := ParseU(S);
        try
          BodyPosOf(U2, U2.FindImpl(C.Name, Name), BodyLine, BodyCol);
        finally
          U2.Free;
        end;
      end;
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

function FSRenameMethod(var Source: string; const AClassName, OldName, NewName: string): Boolean;
var
  U: TUnitInfo;
  C, M: TSymbol;
  R: TRoutineSym;
  E: TEdits;
  S: string;
  I: Integer;
  ML: TList;
begin
  Result := False;
  if not IsValidIdent(NewName) then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      M := FindMember(C.TypeDesc, OldName, skRoutine);
      if M = nil then Exit;
      if not SameText(OldName, NewName) and (C.TypeDesc.Members.Find(NewName) <> nil) then Exit;
      S := Source;
      E := TEdits.Create;
      try
        while M <> nil do
        begin
          if M.Kind = skRoutine then E.Add(M.DeclStart, Length(M.Name), NewName);
          M := C.TypeDesc.Members.FindNext(M);
        end;
        ML := TList.Create;
        try
          U.GetImpls(ML, C.Name, OldName);
          for I := 0 to ML.Count - 1 do
          begin
            R := TRoutineSym(ML[I]);
            if not E.HasAt(R.DeclStart) then E.Add(R.DeclStart, Length(R.Name), NewName);
          end;
        finally
          ML.Free;
        end;
        E.Apply(S);
      finally
        E.Free;
      end;
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

function FSRemoveEmptyMethods(var Source: string; const AClassName: string; Removed: TStrings): Integer;
var
  U: TUnitInfo;
  C, M: TSymbol;
  D: TTypeDesc;
  R: TRoutineSym;
  E: TEdits;
  S: string;
  I, A, B, J, NB, Cnt: Integer;
begin
  Result := 0;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, AClassName);
      if C = nil then Exit;
      D := C.TypeDesc;
      S := Source;
      Cnt := 0;
      E := TEdits.Create;
      try
        for I := 0 to D.Members.Count - 1 do
        begin
          M := D.Members[I];
          if (M.Kind <> skRoutine) or (M.Visibility <> viPublished) or not (M is TRoutineSym) then Continue;
          if (sfOverload in M.Flags) or (sfAbstract in M.Flags) then Continue;
          if D.Members.FindNext(D.Members.Find(M.Name)) <> nil then Continue;   // ambiguous name
          R := U.FindImpl(C.Name, M.Name);
          if (R = nil) or not (sfHasBody in R.Flags) or not (sfBodyClosed in R.Flags) then Continue;
          if (R.Locals <> nil) and (R.Locals.Count > 0) then Continue;
          if not SameText(Copy(S, R.BodyStart + 1, 5), 'begin') then Continue;
          if not IsBlank(S, R.BodyStart + 5, R.BodyEnd - 3) then Continue;
          if not IsBlank(S, R.FullEnd, R.BodyStart) then Continue;
          if E.HasAt(LineStartOf(S, R.HeadStart)) or E.HasAt(R.HeadStart) then Continue;
          // implementation block
          A := LineStartOf(S, R.HeadStart);
          if not IsBlank(S, A, R.HeadStart) then A := R.HeadStart;
          B := R.BodyEnd;
          J := B;
          while (J < Length(S)) and (S[J + 1] in [' ', #9]) do Inc(J);
          if (J < Length(S)) and (S[J + 1] = ';') then B := J + 1;
          if IsBlank(S, B, LineEndOf(S, B)) and (A = LineStartOf(S, R.HeadStart)) then
          begin
            B := NextLineStart(S, B);
            NB := NextLineStart(S, B);
            if (NB > B) and IsBlank(S, B, NB) and (LineEndOf(S, B) < Length(S)) then B := NB;
          end;
          E.Add(A, B - A, '');
          // declaration
          DeleteDecl(E, S, TRoutineSym(M).HeadStart, M.FullEnd);
          if Removed <> nil then Removed.Add(M.Name);
          Inc(Cnt);
        end;
        if Cnt > 0 then
        begin
          E.Apply(S);
          Source := S;
        end;
        Result := Cnt;
      finally
        E.Free;
      end;
    finally
      U.Free;
    end;
  except
    Result := 0;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ class / form variable renaming }

{ the identifier OldName among the tokens of S[A, B) becomes NewName - at its first place there
  only (FirstOnly), else at each; a place E has an edit for already stays as it is }
procedure RenameIdentIn(E: TEdits; const S: string; A, B: Integer; const OldName, NewName: string;
  FirstOnly: Boolean);
var
  L: TPasLexer;
  Up: string;
begin
  Up := UpperCase(OldName);
  L := TPasLexer.Create(S, A, B);
  try
    L.ProcessDirectives := False;
    repeat
      L.Next;
      if (L.Tok.Kind = tkIdent) and L.TokenIs(Up) then
      begin
        if not E.HasAt(L.Tok.Start) then E.Add(L.Tok.Start, L.Tok.Len, NewName);
        if FirstOnly then Break;
      end;
    until L.Tok.Kind = tkEOF;
  finally
    L.Free;
  end;
end;

function FSRenameClass(var Source: string; const OldClassName, NewClassName: string): Boolean;
var
  U: TUnitInfo;
  C, V: TSymbol;
  R: TRoutineSym;
  E: TEdits;
  S: string;
  I, Pass: Integer;
  Tab: TSymTable;
  RT: TRawToks;
  ML: TList;
begin
  Result := False;
  ML := nil;
  if not IsValidIdent(NewClassName) then Exit;
  try
    U := ParseU(Source);
    try
      C := FindClass(U, OldClassName);
      if C = nil then Exit;
      if not SameText(OldClassName, NewClassName) and
        ((U.IntfSyms.Find(NewClassName) <> nil) or (U.ImplSyms.Find(NewClassName) <> nil)) then Exit;
      S := Source;
      E := TEdits.Create;
      try
        E.Add(C.DeclStart, Length(C.Name), NewClassName);
        // forward declaration, if any
        for Pass := 0 to 1 do
        begin
          if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
          for I := 0 to Tab.Count - 1 do
          begin
            V := Tab[I];
            if (V.Kind = skVar) and (V.TypeDesc <> nil) and (V.TypeDesc.Kind = tyAlias) and
              SameText(V.TypeDesc.RefName, OldClassName) and (V.TypeEnd > V.TypeStart) and
              not E.HasAt(V.TypeStart) then
              E.Add(V.TypeStart, V.TypeEnd - V.TypeStart, NewClassName)
            else if (V.Kind = skType) and (V <> C) and (V.TypeDesc <> nil) and
              (V.TypeDesc.Kind = tyClassRef) and SameText(V.TypeDesc.RefName, OldClassName) then
              // 'TFormClass = class of TOld' - the class name token
              RenameIdentIn(E, S, V.TypeStart, V.TypeEnd, OldClassName, NewClassName, False);
          end;
        end;
        // forward declaration 'TOld = class;'
        RT := TRawToks.Create(S);
        try
          I := RT.NextCode(-1);
          while I < RT.N do
          begin
            if RT.IsId(I, OldClassName) and not E.HasAt(RT.T[I].Start) then
            begin
              Pass := RT.NextCode(I);
              if RT.IsSy(Pass, syEqual) and RT.IsKw(RT.NextCode(Pass), kwClass) and
                RT.IsSy(RT.NextCode(RT.NextCode(Pass)), sySemicolon) then
                E.Add(RT.T[I].Start, RT.T[I].Len, NewClassName);
            end;
            I := RT.NextCode(I);
          end;
        finally
          RT.Free;
        end;
        // implementation headings: 'procedure TOld.Name'
        ML := TList.Create;
        U.GetImpls(ML, OldClassName, '');
        for I := 0 to ML.Count - 1 do
        begin
          R := TRoutineSym(ML[I]);
          if R.DeclStart > R.HeadStart then
            RenameIdentIn(E, S, R.HeadStart, R.DeclStart, OldClassName, NewClassName, True);
        end;
        E.Apply(S);
      finally
        ML.Free;
        E.Free;
      end;
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

function FSRenameFormVar(var Source: string; const AClassName, OldVarName, NewVarName: string): Boolean;
var
  U: TUnitInfo;
  V: TSymbol;
  S: string;
begin
  Result := False;
  if not IsValidIdent(NewVarName) then Exit;
  try
    U := ParseU(Source);
    try
      V := U.IntfSyms.Find(OldVarName);
      while (V <> nil) and not ((V.Kind = skVar) and ((AClassName = '') or
        ((V.TypeDesc <> nil) and (V.TypeDesc.Kind = tyAlias) and SameText(V.TypeDesc.RefName, AClassName)))) do
        V := U.IntfSyms.FindNext(V);
      if V = nil then Exit;
      if not SameText(OldVarName, NewVarName) and (U.IntfSyms.Find(NewVarName) <> nil) then Exit;
      S := Source;
      Delete(S, V.DeclStart + 1, Length(V.Name));
      Insert(NewVarName, S, V.DeclStart + 1);
      Source := S;
      Result := True;
    finally
      U.Free;
    end;
  except
    Result := False;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ uses clauses }

procedure FSGetUses(const Source: string; InInterface: Boolean; Units: TStrings);
var
  U: TUnitInfo;
begin
  if Units = nil then Exit;
  try
    U := ParsedView(Source);
    if InInterface and not U.IsProgram then Units.AddStrings(U.IntfUses)
    else Units.AddStrings(U.ImplUses);
  except
  end;
end;

function HeaderEndOfs(const Source: string): Integer;
var
  RT: TRawToks;
  I: Integer;
begin
  // offset just after the ';' of the 'program X;' header; -1 if none
  Result := -1;
  RT := TRawToks.Create(Source);
  try
    I := HeaderNameTok(RT);
    if I < 0 then Exit;
    I := RT.NextCode(I);
    while (I < RT.N) and not RT.IsSy(I, sySemicolon) do
    begin
      if RT.T[I].Kind = tkKeyword then Exit;
      I := RT.NextCode(I);
    end;
    if I < RT.N then Result := RT.EndOf(I);
  finally
    RT.Free;
  end;
end;

type
  TUsesEntry = record
    NameTok, StrTok, CommentTok, LastTok: Integer;
  end;
  TUsesEntries = array of TUsesEntry;

// The entries of the uses / contains clause whose keyword is token UsesTok: a unit name, its
// "in 'path'" and the comment with its form name. SemiTok = the ';'.
function ParseUsesEntries(RT: TRawToks; UsesTok: Integer; out SemiTok: Integer;
  out Entries: TUsesEntries): Boolean;
var
  I, J, Cnt: Integer;
begin
  SemiTok := -1;
  Entries := nil;
  Cnt := 0;
  I := RT.NextCode(UsesTok);
  while (UsesTok >= 0) and (I < RT.N) do
  begin
    if RT.T[I].Kind <> tkIdent then Break;
    if Cnt >= Length(Entries) then SetLength(Entries, Cnt * 2 + 16);
    Entries[Cnt].NameTok := I;
    Entries[Cnt].StrTok := -1;
    Entries[Cnt].CommentTok := -1;
    Entries[Cnt].LastTok := I;
    J := RT.NextCode(I);
    if RT.IsKw(J, kwIn) then
    begin
      J := RT.NextCode(J);
      if (J < RT.N) and (RT.T[J].Kind = tkString) then
      begin
        Entries[Cnt].StrTok := J;
        Entries[Cnt].LastTok := J;
      end;
    end;
    J := Entries[Cnt].LastTok + 1;
    if (J < RT.N) and (RT.T[J].Kind = tkComment) and (RT.T[J].PLen > 2) and
      (RT.T[J].Ptr[0] = '{') and not RT.IsDirective(J) then
    begin
      Entries[Cnt].CommentTok := J;
      Entries[Cnt].LastTok := J;
    end;
    Inc(Cnt);
    I := RT.NextCode(Entries[Cnt - 1].LastTok);
    if RT.IsSy(I, syComma) then
      I := RT.NextCode(I)
    else
    begin
      if RT.IsSy(I, sySemicolon) then SemiTok := I;
      Break;
    end;
  end;
  SetLength(Entries, Cnt);
  Result := (Cnt > 0) and (SemiTok >= 0);
end;

procedure UsesClauseNames(const Source: string; Units: TStrings);
var
  RT: TRawToks;
  I, Semi, K: Integer;
  Entries: TUsesEntries;
begin
  RT := TRawToks.Create(Source);
  try
    I := 0;
    while I < RT.N do
    begin
      if RT.IsKw(I, kwUses) and ParseUsesEntries(RT, I, Semi, Entries) then
      begin
        for K := 0 to High(Entries) do Units.Add(RT.Txt(Entries[K].NameTok));
        I := Semi;
      end;
      Inc(I);
    end;
  finally
    RT.Free;
  end;
end;

function FindUsesEntry(RT: TRawToks; const Entries: TUsesEntries; const UnitName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Entries) do
    if RT.IsId(Entries[I].NameTok, UnitName) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ the text [A, B) of the whole clause (and its lines) - with the empty line after it when one is
  before it too }
procedure UsesClauseRange(RT: TRawToks; const S: string; UsesTok, SemiTok: Integer; out A, B: Integer);
var
  NB: Integer;
begin
  A := RT.T[UsesTok].Start;
  B := RT.EndOf(SemiTok);
  if WholeLines(S, A, B) then
  begin
    { the line before: its end E (before its line break) }
    NB := A;
    if (NB > 0) and (S[NB] = #10) then Dec(NB);
    if (NB > 0) and (S[NB] = #13) then Dec(NB);
    if (A > 0) and (B < Length(S)) and IsBlank(S, LineStartOf(S, NB), NB) and
      IsBlank(S, B, LineEndOf(S, B)) and (NextLineStart(S, B) > B) then B := NextLineStart(S, B);
  end;
end;

{ the text [A, B) of entry K with the comma after it (WithNext: up to the next entry), else with the
  comma before it (from the entry before) }
procedure EntryRange(RT: TRawToks; const Entries: TUsesEntries; K: Integer; WithNext: Boolean; out A, B: Integer);
begin
  if WithNext then
  begin
    A := RT.T[Entries[K].NameTok].Start;
    B := RT.T[Entries[K + 1].NameTok].Start;
  end
  else
  begin
    A := RT.EndOf(Entries[K - 1].LastTok);
    B := RT.EndOf(Entries[K].LastTok);
  end;
end;

{ the text [A, B) that removes entry K: the entry with its comma; the whole clause when it is the
  only entry }
procedure UsesEntryRange(RT: TRawToks; const S: string; UsesTok, SemiTok: Integer;
  const Entries: TUsesEntries; K: Integer; out A, B: Integer);
begin
  if Length(Entries) = 1 then UsesClauseRange(RT, S, UsesTok, SemiTok, A, B)
  else EntryRange(RT, Entries, K, K < High(Entries), A, B);
end;

function UsesRemoveRanges(const Source: string; UsesOfs: Integer; Names: TStrings; Ranges: TList): Boolean;
var
  RT: TRawToks;
  UT, ST, K, J, I, A, B, P, S2: Integer;
  Entries: TUsesEntries;
  Gone: array of Boolean;
  Kept, AtKept: Boolean;
  Runs: TList;

  procedure Add(X, Y: Integer);
  begin
    if X >= Y then Exit;
    Ranges.Add(Pointer(X));
    Ranges.Add(Pointer(Y));
  end;

begin
  Result := False;
  Ranges.Clear;
  RT := TRawToks.Create(Source);
  try
    UT := RT.IndexAt(UsesOfs);
    if (UT < 0) or not ParseUsesEntries(RT, UT, ST, Entries) then Exit;
    SetLength(Gone, Length(Entries));
    for K := 0 to High(Gone) do Gone[K] := False;
    for I := 0 to Names.Count - 1 do
    begin
      K := FindUsesEntry(RT, Entries, Names[I]);
      if K < 0 then Exit;
      Gone[K] := True;
    end;
    Kept := False;
    for K := 0 to High(Gone) do
      if not Gone[K] then Kept := True;
    if not Kept then
    begin
      UsesClauseRange(RT, Source, UT, ST, A, B);
      Ranges.Add(Pointer(A));
      Ranges.Add(Pointer(B));
      Result := True;
      Exit;
    end;
    Runs := TList.Create;
    try
      for K := 0 to High(Entries) do
      begin
        if not Gone[K] then Continue;
        { with the comma after it while a unit that stays comes later, else with the one before it }
        J := K + 1;
        while (J <= High(Entries)) and Gone[J] do Inc(J);
        EntryRange(RT, Entries, K, J <= High(Entries), A, B);
        { a directive there would lose its other half }
        for J := RT.FirstAt(A) to RT.N - 1 do
        begin
          if RT.T[J].Start >= B then Break;
          if RT.IsDirective(J) then Exit;
        end;
        { the entries that go one after another as one run }
        if (Runs.Count > 0) and (A <= Integer(Runs[Runs.Count - 1])) then
          Runs[Runs.Count - 1] := Pointer(B)
        else
        begin
          Runs.Add(Pointer(A));
          Runs.Add(Pointer(B));
        end;
      end;
      { a run up to a unit that stays, after a unit that stays on its first line, over a line's end: the
        line's end stays - the run goes from that line's end, then up to the unit on the line it is on -,
        or the lines would run together }
      I := 0;
      while I < Runs.Count do
      begin
        A := Integer(Runs[I]);
        B := Integer(Runs[I + 1]);
        AtKept := False;
        for K := 0 to High(Entries) do
          if not Gone[K] and (RT.T[Entries[K].NameTok].Start = B) then AtKept := True;
        P := -1;
        for J := A to B - 1 do
          if Source[J + 1] in [#13, #10] then
          begin
            P := J;
            Break;
          end;
        if AtKept and (P >= 0) and not IsBlank(Source, LineStartOf(Source, A), A) then
        begin
          J := A;
          while (J > 0) and (Source[J] in [' ', #9]) do Dec(J);
          Add(J, P);
          S2 := NextLineStart(Source, P);
          while (S2 < B) and (Source[S2 + 1] in [' ', #9]) do Inc(S2);
          Add(S2, B);
        end
        else
          Add(A, B);
        Inc(I, 2);
      end;
    finally
      Runs.Free;
    end;
    Result := True;
  finally
    if not Result then Ranges.Clear;
    RT.Free;
  end;
end;

// Where a unit is appended to the clause whose ';' is token Semi: after the last unit, or after
// the directive that closes it ($ENDIF before the ';') - never into a comment that follows the
// last unit ("Forms // vcl" on the line above the ';').
function UsesAppendOfs(RT: TRawToks; Semi: Integer): Integer;
var
  I: Integer;
begin
  I := Semi - 1;
  while (I > 0) and (RT.T[I].Kind = tkComment) and not RT.IsDirective(I) do Dec(I);
  Result := RT.EndOf(I);
end;

function FSAddUses(var Source: string; const UnitName: string; InInterface: Boolean): Boolean;
var
  U: TUnitInfo;
  RT: TRawToks;
  E: TEdits;
  S, EOL, Ins, Indent, LineText: string;
  UseStart, UseEnd, InsOfs, LS, KwOfs, UT, ST, K, A, B: Integer;
  Entries: TUsesEntries;
  ToIntf: Boolean;
begin
  Result := False;
  if not IsValidIdent(UnitName) then Exit;
  try
    U := ParseU(Source);
    RT := TRawToks.Create(Source);
    E := TEdits.Create;
    try
      ToIntf := InInterface and not U.IsProgram;
      if (U.IntfUses.IndexOf(UnitName) >= 0) or (not ToIntf and (U.ImplUses.IndexOf(UnitName) >= 0)) then
      begin
        Result := True;
        Exit;
      end;
      S := Source;
      EOL := DetectEOL(S);
      if ToIntf and (U.ImplUses.IndexOf(UnitName) >= 0) then
      begin
        { only in the implementation clause, but the interface needs it now (the type of a field
          of the form class): it moves }
        UT := RT.IndexAt(U.ImplUsesStart);
        if not ParseUsesEntries(RT, UT, ST, Entries) then Exit;
        K := FindUsesEntry(RT, Entries, UnitName);
        if K < 0 then Exit;
        UsesEntryRange(RT, S, UT, ST, Entries, K, A, B);
        E.Add(A, B - A, '');
      end;
      if ToIntf then
      begin
        UseStart := U.IntfUsesStart;
        UseEnd := U.IntfUsesEnd;
      end
      else
      begin
        UseStart := U.ImplUsesStart;
        UseEnd := U.ImplUsesEnd;
      end;
      if UseEnd > UseStart then
      begin
        ST := RT.IndexAt(UseEnd);
        if ST <= 0 then Exit;
        InsOfs := UsesAppendOfs(RT, ST);
        LS := LineStartOf(S, InsOfs);
        if (InsOfs - LS) + Length(UnitName) + 3 > 80 then
        begin
          Indent := IndentAt(S, LS);
          LineText := Copy(S, LS + Length(Indent) + 1, 5);
          if SameText(Copy(LineText, 1, 4), 'uses') and ((Length(LineText) < 5) or (LineText[5] <= ' ')) then
            Indent := Indent + '  ';
          Ins := ',' + EOL + Indent + UnitName;
        end
        else
          Ins := ', ' + UnitName;
        E.Add(InsOfs, 0, Ins);
      end
      else
      begin
        // create the clause
        if U.IsProgram then
        begin
          KwOfs := HeaderEndOfs(S);
          if KwOfs < 0 then Exit;
        end
        else if ToIntf then
        begin
          if U.IntfOfs <= 0 then Exit;
          KwOfs := U.IntfOfs;
        end
        else
        begin
          if U.ImplOfs = MaxInt then Exit;
          KwOfs := U.ImplOfs;
        end;
        InsOfs := NextLineStart(S, KwOfs);
        Ins := EOL + 'uses' + EOL + '  ' + UnitName + ';' + EOL;
        if LineEndOf(S, KwOfs) >= Length(S) then
          Ins := EOL + Ins
        else if not IsBlank(S, InsOfs, NextLineStart(S, InsOfs)) or (InsOfs >= Length(S)) then
          Ins := Ins + EOL;
        E.Add(InsOfs, 0, Ins);
      end;
      E.Apply(S);
      Source := S;
      Result := True;
    finally
      E.Free;
      RT.Free;
      U.Free;
    end;
  except
    Result := False;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ project file }

type
  TCFRec = record
    AppTok, ClassTok, VarTok, EndTok: Integer;
  end;
  TCFList = array of TCFRec;

{ the source starts with "package" (a .dpk) }
function IsPackageSource(RT: TRawToks): Boolean;
begin
  Result := RT.IsId(RT.NextCode(-1), 'package');
end;

{ The unit list of a project source: the uses clause of a program or library, the contains
  clause of a package (its requires clause names packages, not units). }
function DprParseUses(RT: TRawToks; out UsesTok, SemiTok: Integer; out Entries: TUsesEntries): Boolean;
var
  I: Integer;
  Pkg: Boolean;
begin
  Result := False;
  UsesTok := -1;
  SemiTok := -1;
  Entries := nil;
  Pkg := IsPackageSource(RT);
  I := RT.NextCode(-1);
  while (I < RT.N) and not (RT.IsKw(I, kwUses) or (Pkg and RT.IsId(I, 'contains'))) do
  begin
    if RT.IsKw(I, kwBegin) or (Pkg and RT.IsKw(I, kwEnd)) then Exit;
    I := RT.NextCode(I);
  end;
  if I >= RT.N then Exit;
  UsesTok := I;
  Result := ParseUsesEntries(RT, UsesTok, SemiTok, Entries);
end;

function UnquoteStr(const S: string): string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
    Result := Copy(Result, 2, Length(Result) - 2);
  Result := StringReplace(Result, '''''', '''', [rfReplaceAll]);
end;

function QuoteStr(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function CommentFormName(const C: string): string;
var
  P: Integer;
begin
  Result := C;
  if (Length(Result) >= 2) and (Result[1] = '{') then Result := Copy(Result, 2, Length(Result) - 2);
  P := Pos(':', Result);
  if P > 0 then Result := Copy(Result, 1, P - 1);
  Result := Trim(Result);
end;

procedure DprGetUnits(const Source: string; Units, Paths, FormNames: TStrings);
var
  RT: TRawToks;
  UT, ST, I: Integer;
  Entries: TUsesEntries;
begin
  try
    RT := TRawToks.Create(Source);
    try
      DprParseUses(RT, UT, ST, Entries);
      for I := 0 to High(Entries) do
      begin
        if Units <> nil then Units.Add(RT.Txt(Entries[I].NameTok));
        if Paths <> nil then
        begin
          if Entries[I].StrTok >= 0 then Paths.Add(UnquoteStr(RT.Txt(Entries[I].StrTok)))
          else Paths.Add('');
        end;
        if FormNames <> nil then
        begin
          if Entries[I].CommentTok >= 0 then FormNames.Add(CommentFormName(RT.Txt(Entries[I].CommentTok)))
          else FormNames.Add('');
        end;
      end;
    finally
      RT.Free;
    end;
  except
  end;
end;

{ the keyword token of a package's requires clause; -1 when there is none (or no package) }
function DpkRequiresTok(RT: TRawToks): Integer;
var
  I: Integer;
begin
  Result := -1;
  if not IsPackageSource(RT) then Exit;
  I := RT.NextCode(-1);
  while I < RT.N do
  begin
    if RT.IsId(I, 'requires') then
    begin
      Result := I;
      Exit;
    end;
    if RT.IsId(I, 'contains') or RT.IsKw(I, kwEnd) then Exit;
    I := RT.NextCode(I);
  end;
end;

{ the entries of a package's requires clause (False: none, or not a clause that can be edited) }
function DpkParseRequires(RT: TRawToks; out ReqTok, SemiTok: Integer; out Entries: TUsesEntries): Boolean;
begin
  ReqTok := DpkRequiresTok(RT);
  SemiTok := -1;
  Entries := nil;
  Result := (ReqTok >= 0) and ParseUsesEntries(RT, ReqTok, SemiTok, Entries);
end;

procedure DpkGetRequires(const Source: string; Packages: TStrings);
var
  RT: TRawToks;
  RQ, ST, I: Integer;
  Entries: TUsesEntries;
begin
  try
    RT := TRawToks.Create(Source);
    try
      DpkParseRequires(RT, RQ, ST, Entries);
      for I := 0 to High(Entries) do Packages.Add(RT.Txt(Entries[I].NameTok));
    finally
      RT.Free;
    end;
  except
  end;
end;

function DprEntryText(const UnitName, RelPath, FormName: string): string;
begin
  Result := UnitName;
  if RelPath <> '' then Result := Result + ' in ' + QuoteStr(RelPath);
  if FormName <> '' then Result := Result + ' {' + FormName + '}';
end;

{ Text after the last entry of a clause, on a line of its own indented as that entry }
procedure AppendClauseEntry(RT: TRawToks; var S: string; const Entries: TUsesEntries; const EOL, Text: string);
var
  N, LS: Integer;
  Indent: string;
begin
  N := High(Entries);
  LS := LineStartOf(S, RT.T[Entries[N].NameTok].Start);
  if IsBlank(S, LS, RT.T[Entries[N].NameTok].Start) then Indent := IndentAt(S, LS)
  else Indent := '  ';
  Insert(',' + EOL + Indent + Text, S, RT.EndOf(Entries[N].LastTok) + 1);
end;

{ a new clause of a package ("Keyword Entry;" and an empty line) at the start of the line of
  token Before, else before the package's final "end."; False when there is neither }
function InsertPackageClause(RT: TRawToks; var S: string; Before: Integer; const EOL, Keyword, Entry: string): Boolean;
var
  N: Integer;
begin
  Result := False;
  if Before < 0 then
    for N := RT.N - 1 downto 0 do
      if RT.IsKw(N, kwEnd) then
      begin
        Before := N;
        Break;
      end;
  if Before < 0 then Exit;
  Insert(Keyword + EOL + '  ' + Entry + ';' + EOL + EOL, S, LineStartOf(S, RT.T[Before].Start) + 1);
  Result := True;
end;

function DpkAddRequires(var Source: string; const Package: string): Boolean;
var
  RT: TRawToks;
  RQ, ST, I: Integer;
  Entries: TUsesEntries;
  S: string;
begin
  Result := False;
  if not IsValidIdent(Package) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      if not IsPackageSource(RT) then Exit;
      S := Source;
      if DpkParseRequires(RT, RQ, ST, Entries) then
      begin
        Result := FindUsesEntry(RT, Entries, Package) >= 0;
        if Result then Exit;
        AppendClauseEntry(RT, S, Entries, DetectEOL(S), Package);
      end
      else
      begin
        { none yet: before the contains clause (Delphi's order), else before the "end." }
        if RQ >= 0 then Exit;     // malformed: do not touch
        I := RT.NextCode(-1);
        while (I < RT.N) and not RT.IsId(I, 'contains') do I := RT.NextCode(I);
        if I >= RT.N then I := -1;
        if not InsertPackageClause(RT, S, I, DetectEOL(S), 'requires', Package) then Exit;
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

type
  { finds a clause of a project or package source: its keyword's and its ';''s tokens, its entries }
  TClauseParser = function(RT: TRawToks; out KeyTok, SemiTok: Integer; out Entries: TUsesEntries): Boolean;

{ the entry Name taken out of the clause ParseClause finds (with its comma; the whole clause when
  it is its only entry) }
function RemoveClauseEntry(var Source: string; const Name: string; ParseClause: TClauseParser): Boolean;
var
  RT: TRawToks;
  KT, ST, K, A, B: Integer;
  Entries: TUsesEntries;
  S: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      if not ParseClause(RT, KT, ST, Entries) then Exit;
      K := FindUsesEntry(RT, Entries, Name);
      if K < 0 then Exit;
      S := Source;
      UsesEntryRange(RT, S, KT, ST, Entries, K, A, B);
      Delete(S, A + 1, B - A);
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DpkRemoveRequires(var Source: string; const Package: string): Boolean;
begin
  Result := RemoveClauseEntry(Source, Package, DpkParseRequires);
end;

function DprAddUnit(var Source: string; const UnitName, RelPath, FormName: string): Boolean;
var
  RT: TRawToks;
  UT, ST, Ofs: Integer;
  Entries: TUsesEntries;
  S, EOL: string;
begin
  Result := False;
  if not IsValidIdent(UnitName) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      S := Source;
      EOL := DetectEOL(S);
      if DprParseUses(RT, UT, ST, Entries) then
      begin
        if FindUsesEntry(RT, Entries, UnitName) >= 0 then
        begin
          Result := True;
          Exit;
        end;
        AppendClauseEntry(RT, S, Entries, EOL, DprEntryText(UnitName, RelPath, FormName));
      end
      else if IsPackageSource(RT) then
      begin
        { a package without units: the contains clause goes before its final "end." }
        if UT >= 0 then Exit;
        if not InsertPackageClause(RT, S, -1, EOL, 'contains', DprEntryText(UnitName, RelPath, FormName)) then Exit;
      end
      else
      begin
        if UT >= 0 then Exit;   // malformed uses clause: do not touch
        Ofs := HeaderEndOfs(S);
        if Ofs < 0 then Exit;
        Ofs := NextLineStart(S, Ofs);
        Insert(EOL + 'uses' + EOL + '  ' + DprEntryText(UnitName, RelPath, FormName) + ';' + EOL, S, Ofs + 1);
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprRemoveUnit(var Source: string; const UnitName: string): Boolean;
begin
  Result := RemoveClauseEntry(Source, UnitName, DprParseUses);
end;

function DprRenameUnit(var Source: string; const OldUnitName, NewUnitName, NewRelPath: string): Boolean;
var
  RT: TRawToks;
  UT, ST, K: Integer;
  Entries: TUsesEntries;
  S: string;
  E: TEdits;
begin
  Result := False;
  if not IsValidIdent(NewUnitName) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      if not DprParseUses(RT, UT, ST, Entries) then Exit;
      K := FindUsesEntry(RT, Entries, OldUnitName);
      if K < 0 then Exit;
      if not SameText(OldUnitName, NewUnitName) and (FindUsesEntry(RT, Entries, NewUnitName) >= 0) then Exit;
      S := Source;
      E := TEdits.Create;
      try
        E.Add(RT.T[Entries[K].NameTok].Start, RT.T[Entries[K].NameTok].Len, NewUnitName);
        if NewRelPath <> '' then
        begin
          if Entries[K].StrTok >= 0 then
            E.Add(RT.T[Entries[K].StrTok].Start, RT.T[Entries[K].StrTok].Len, QuoteStr(NewRelPath))
          else
            E.Add(RT.EndOf(Entries[K].NameTok), 0, ' in ' + QuoteStr(NewRelPath));
        end;
        E.Apply(S);
      finally
        E.Free;
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

{ token I begins "Application.Name": the token of Name (comments between them skipped); -1 not }
function AppMemberAt(RT: TRawToks; I: Integer; const Name: string): Integer;
var
  A: Integer;
begin
  Result := -1;
  if not RT.IsId(I, 'Application') then Exit;
  A := RT.NextCode(I);
  if RT.IsSy(A, syDot) and RT.IsId(RT.NextCode(A), Name) then Result := RT.NextCode(A);
end;

{ the tokens of "Application.<Prop> := <string> ;": Appl = Application, Str = the string,
  Last = the ';' (or the string); False when there is none }
function FindAppProp(RT: TRawToks; const Prop: string; out Appl, Str, Last: Integer): Boolean;
var
  I, B, C, D, E: Integer;
begin
  Result := False;
  I := RT.NextCode(-1);
  while I < RT.N do
  begin
    B := AppMemberAt(RT, I, Prop);
    if B >= 0 then
    begin
      C := RT.NextCode(B);
      D := RT.NextCode(C);
      if RT.IsSy(C, syAssign) and (D < RT.N) and (RT.T[D].Kind = tkString) then
      begin
        Appl := I;
        Str := D;
        E := RT.NextCode(D);
        if RT.IsSy(E, sySemicolon) then Last := E else Last := D;
        Result := True;
        Exit;
      end;
    end;
    I := RT.NextCode(I);
  end;
end;

function DprGetAppProp(const Source, Prop: string): string;
var
  RT: TRawToks;
  A, S, L: Integer;
begin
  Result := '';
  try
    RT := TRawToks.Create(Source);
    try
      if FindAppProp(RT, Prop, A, S, L) then Result := UnquoteStr(RT.Txt(S));
    finally
      RT.Free;
    end;
  except
    Result := '';
  end;
end;

function DprAddDirective(var Source: string; const Directive: string): Boolean;
var
  Ofs: Integer;
  S: string;
begin
  Result := False;
  S := Source;
  Ofs := HeaderEndOfs(S);
  if Ofs < 0 then Exit;
  Ofs := NextLineStart(S, Ofs);
  Insert(Directive + DetectEOL(S), S, Ofs + 1);
  Source := S;
  Result := True;
end;

function DprAddTodoFile(var Source: string; const RelName: string): Boolean;
var
  RT: TRawToks;
  K, ST, Ofs: Integer;
  Entries: TUsesEntries;
  S, EOL, Entry: string;
begin
  try
    RT := TRawToks.Create(Source);
    try
      S := Source;
      EOL := DetectEOL(S);
      Entry := '{%ToDo ' + QuoteStr(RelName) + '}';
      K := DpkRequiresTok(RT);
      if K < 0 then DprParseUses(RT, K, ST, Entries);
      if K >= 0 then
        Insert(Entry + EOL + EOL, S, RT.T[K].Start + 1)
      else
      begin
        Ofs := HeaderEndOfs(S);
        if Ofs < 0 then Ofs := Length(S);
        Insert(EOL + EOL + Entry, S, Ofs + 1);
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ $R directives; the resource scripts are those with two file names }

type
  TResScriptTok = record
    Tok: Integer;              // the directive's token
    Res, Rc: string;           // its first two names as written, unquoted (Rc '' with one name)
  end;
  TResScriptToks = array of TResScriptTok;

{ the names of the directive text Txt (its braces, or parenthesis and stars, included) when it is
  $R or $RESOURCE: quoted ones ('' is a quote) or up to the next blank; the switch $R+ / $R- has
  none }
function ResDirectiveNames(const Txt: string; Names: TStrings): Boolean;
var
  S, W: string;
  I, J, N: Integer;
begin
  Result := False;
  Names.Clear;
  if Copy(Txt, 1, 2) = '{$' then S := Copy(Txt, 3, Length(Txt) - 3)
  else if Copy(Txt, 1, 3) = '(*$' then S := Copy(Txt, 4, Length(Txt) - 5)
  else Exit;
  N := Length(S);
  I := 1;
  while (I <= N) and (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(I);
  W := UpperCase(Copy(S, 1, I - 1));
  if ((W <> 'R') and (W <> 'RESOURCE')) or ((I <= N) and (S[I] in ['+', '-'])) then Exit;
  while I <= N do
  begin
    while (I <= N) and (S[I] <= ' ') do Inc(I);
    if I > N then Break;
    W := '';
    if S[I] = '''' then
    begin
      Inc(I);
      while I <= N do
        if S[I] <> '''' then
        begin
          W := W + S[I];
          Inc(I);
        end
        else if (I < N) and (S[I + 1] = '''') then
        begin
          W := W + '''';
          Inc(I, 2);
        end
        else
        begin
          Inc(I);
          Break;
        end;
    end
    else
    begin
      J := I;
      while (I <= N) and (S[I] > ' ') do Inc(I);
      W := Copy(S, J, I - J);
    end;
    Names.Add(W);
  end;
  Result := Names.Count > 0;
end;

{ the $R / $RESOURCE directives of a project source with Count names, 0: any number, in their
  order - 2 the resource scripts (DprGetResScripts), 1 those like $R *.res }
function FindResDirectives(RT: TRawToks; Count: Integer): TResScriptToks;
var
  I, N: Integer;
  Names: TStringList;
begin
  Result := nil;
  Names := TStringList.Create;
  try
    for I := 0 to RT.N - 1 do
      if RT.IsDirective(I) and ResDirectiveNames(RT.Txt(I), Names) and ((Count = 0) or (Names.Count = Count)) then
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].Tok := I;
        Result[N].Res := Names[0];
        if Names.Count > 1 then Result[N].Rc := Names[1];
      end;
  finally
    Names.Free;
  end;
end;

{ the names of a project source's $R directives with Count names (FindResDirectives) into ResFiles
  and RcFiles, nil: not wanted }
procedure GetResDirectiveNames(const Source: string; Count: Integer; ResFiles, RcFiles: TStrings);
var
  RT: TRawToks;
  L: TResScriptToks;
  I: Integer;
begin
  try
    RT := TRawToks.Create(Source);
    try
      L := FindResDirectives(RT, Count);
      for I := 0 to High(L) do
      begin
        if ResFiles <> nil then ResFiles.Add(L[I].Res);
        if RcFiles <> nil then RcFiles.Add(L[I].Rc);
      end;
    finally
      RT.Free;
    end;
  except
  end;
end;

{ the same file name, either path separator }
function SameRelPath(const A, B: string): Boolean;
begin
  Result := SameText(StringReplace(A, '/', '\', [rfReplaceAll]), StringReplace(B, '/', '\', [rfReplaceAll]));
end;

function ResScriptText(const RelRes, RelRc: string): string;
begin
  Result := '{$R ' + QuoteStr(RelRes) + ' ' + QuoteStr(RelRc) + '}';
end;

procedure DprGetResScripts(const Source: string; ResFiles, RcFiles: TStrings);
begin
  GetResDirectiveNames(Source, 2, ResFiles, RcFiles);
end;

procedure DprGetResFiles(const Source: string; ResFiles: TStrings);
begin
  GetResDirectiveNames(Source, 0, ResFiles, nil);
end;

function DprAddResScript(var Source: string; const RelRes, RelRc: string): Boolean;
var
  RT: TRawToks;
  L, Ones: TResScriptToks;
  I, UT, ST, K, Ofs: Integer;
  Entries: TUsesEntries;
  S, EOL, Entry: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      L := FindResDirectives(RT, 2);
      for I := 0 to High(L) do
        if SameRelPath(L[I].Rc, RelRc) then
        begin
          Result := True;
          Exit;
        end;
      Ones := FindResDirectives(RT, 1);
      S := Source;
      EOL := DetectEOL(S);
      Entry := ResScriptText(RelRes, RelRc);
      if Length(L) > 0 then
        Insert(EOL + Entry, S, RT.EndOf(L[High(L)].Tok) + 1)
      else if IsPackageSource(RT) then
      begin
        if Length(Ones) > 0 then
          Insert(EOL + Entry, S, RT.EndOf(Ones[0].Tok) + 1)
        else
        begin
          Ofs := HeaderEndOfs(S);
          if Ofs < 0 then Exit;
          Insert(EOL + EOL + Entry, S, Ofs + 1);
        end;
      end
      else if DprParseUses(RT, UT, ST, Entries) and (ST >= 0) then
      begin
        { the $R that follows the uses clause, alone on its line: the script on the line before it }
        K := ST + 1;
        I := 0;
        while (I <= High(Ones)) and (Ones[I].Tok <> K) do Inc(I);
        if (I <= High(Ones)) and IsBlank(S, LineStartOf(S, RT.T[K].Start), RT.T[K].Start) then
          Insert(Entry + EOL, S, LineStartOf(S, RT.T[K].Start) + 1)
        else
          Insert(EOL + EOL + Entry, S, RT.EndOf(ST) + 1);
      end
      else
      begin
        Ofs := HeaderEndOfs(S);
        if Ofs < 0 then Exit;
        Insert(EOL + EOL + Entry, S, Ofs + 1);
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprRemoveResScript(var Source: string; const RelRc: string): Boolean;
var
  RT: TRawToks;
  L: TResScriptToks;
  I, A, B: Integer;
  S: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      L := FindResDirectives(RT, 2);
      for I := 0 to High(L) do
        if SameRelPath(L[I].Rc, RelRc) then
        begin
          S := Source;
          A := RT.T[L[I].Tok].Start;
          B := RT.EndOf(L[I].Tok);
          { its whole line; between two empty lines one of them goes too }
          if WholeLines(S, A, B) and (A > 0) and (B < Length(S)) and
            IsBlank(S, PrevLineStart(S, A), A) and IsBlank(S, B, LineEndOf(S, B)) then
            B := NextLineStart(S, B);
          Delete(S, A + 1, B - A);
          Source := S;
          Result := True;
          Exit;
        end;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprRenameResScript(var Source: string; const RelRc, NewRelRes, NewRelRc: string): Boolean;
var
  RT: TRawToks;
  L: TResScriptToks;
  I: Integer;
  S: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      L := FindResDirectives(RT, 2);
      for I := 0 to High(L) do
        if SameRelPath(L[I].Rc, RelRc) then
        begin
          S := Source;
          Delete(S, RT.T[L[I].Tok].Start + 1, RT.T[L[I].Tok].Len);
          Insert(ResScriptText(NewRelRes, NewRelRc), S, RT.T[L[I].Tok].Start + 1);
          Source := S;
          Result := True;
          Exit;
        end;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprSetAppProp(var Source: string; const Prop, Value: string): Boolean;
var
  RT: TRawToks;
  A, S, L, I, J, LS: Integer;
  Src, EOL, Indent: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      Src := Source;
      EOL := DetectEOL(Src);
      if FindAppProp(RT, Prop, A, S, L) then
      begin
        if Value <> '' then
        begin
          Delete(Src, RT.T[S].Start + 1, RT.T[S].Len);
          Insert(QuoteStr(Value), Src, RT.T[S].Start + 1);
        end
        else
        begin
          { the whole line when the statement is alone on it }
          I := RT.T[A].Start;
          J := RT.EndOf(L);
          WholeLines(Src, I, J);
          Delete(Src, I + 1, J - I);
        end;
      end
      else
      begin
        if Value = '' then
        begin
          Result := True;
          Exit;
        end;
        { after "Application.Initialize;", with its indentation }
        I := RT.NextCode(-1);
        J := -1;
        while I < RT.N do
        begin
          J := AppMemberAt(RT, I, 'Initialize');
          if J >= 0 then
          begin
            if RT.IsSy(RT.NextCode(J), sySemicolon) then J := RT.NextCode(J);
            Break;
          end;
          I := RT.NextCode(I);
        end;
        if J < 0 then Exit;
        LS := LineStartOf(Src, RT.T[I].Start);
        Indent := IndentAt(Src, LS);
        Insert(EOL + Indent + 'Application.' + Prop + ' := ' + QuoteStr(Value) + ';', Src, RT.EndOf(J) + 1);
      end;
      Source := Src;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

procedure FindCreateForms(RT: TRawToks; out List: TCFList);
var
  I, B, C, D, E2, F, G, H, Cnt: Integer;
begin
  List := nil;
  Cnt := 0;
  I := RT.NextCode(-1);
  while I < RT.N do
  begin
    B := AppMemberAt(RT, I, 'CreateForm');
    if B >= 0 then
    begin
      C := RT.NextCode(B);
      D := RT.NextCode(C);
      E2 := RT.NextCode(D);
      F := RT.NextCode(E2);
      G := RT.NextCode(F);
      if RT.IsSy(C, syLParen) and RT.IsIdent(D) and RT.IsSy(E2, syComma) and RT.IsIdent(F) and
        RT.IsSy(G, syRParen) then
      begin
        if Cnt >= Length(List) then SetLength(List, Cnt * 2 + 16);
        List[Cnt].AppTok := I;
        List[Cnt].ClassTok := D;
        List[Cnt].VarTok := F;
        List[Cnt].EndTok := G;
        H := RT.NextCode(G);
        if RT.IsSy(H, sySemicolon) then List[Cnt].EndTok := H;
        Inc(Cnt);
        I := List[Cnt - 1].EndTok;
      end;
    end;
    I := RT.NextCode(I);
  end;
  SetLength(List, Cnt);
end;

procedure DprGetCreateForms(const Source: string; ClassNames, VarNames: TStrings);
var
  RT: TRawToks;
  L: TCFList;
  I: Integer;
begin
  try
    RT := TRawToks.Create(Source);
    try
      FindCreateForms(RT, L);
      for I := 0 to High(L) do
      begin
        if ClassNames <> nil then ClassNames.Add(RT.Txt(L[I].ClassTok));
        if VarNames <> nil then VarNames.Add(RT.Txt(L[I].VarTok));
      end;
    finally
      RT.Free;
    end;
  except
  end;
end;

function DprAddCreateForm(var Source: string; const FormClassName, FormVarName: string): Boolean;
var
  RT: TRawToks;
  L: TCFList;
  I, C, Ofs, LS, Target: Integer;
  S, EOL, Indent, Stmt: string;
begin
  Result := False;
  if not IsValidIdent(FormClassName) or not IsValidIdent(FormVarName) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      FindCreateForms(RT, L);
      for I := 0 to High(L) do
        if RT.IsId(L[I].VarTok, FormVarName) then
        begin
          Result := True;
          Exit;
        end;
      S := Source;
      EOL := DetectEOL(S);
      Stmt := 'Application.CreateForm(' + FormClassName + ', ' + FormVarName + ');';
      if Length(L) > 0 then
      begin
        I := High(L);
        LS := LineStartOf(S, RT.T[L[I].AppTok].Start);
        Indent := IndentAt(S, LS);
        Ofs := RT.EndOf(L[I].EndTok);
        if IsBlank(S, Ofs, LineEndOf(S, Ofs)) and (LineEndOf(S, Ofs) < Length(S)) then
          Insert(Indent + Stmt + EOL, S, NextLineStart(S, Ofs) + 1)
        else
          Insert(EOL + Indent + Stmt, S, Ofs + 1);
      end
      else
      begin
        // before 'Application.Run', else before the final 'end.'
        Target := -1;
        I := RT.NextCode(-1);
        while I < RT.N do
        begin
          if AppMemberAt(RT, I, 'Run') >= 0 then
          begin
            Target := I;
            Break;
          end;
          I := RT.NextCode(I);
        end;
        Indent := '  ';
        if Target < 0 then
        begin
          I := RT.NextCode(-1);
          while I < RT.N do
          begin
            C := RT.NextCode(I);
            if RT.IsKw(I, kwEnd) and RT.IsSy(C, syDot) then Target := I;
            I := C;
          end;
          if Target < 0 then Exit;
        end
        else
        begin
          LS := LineStartOf(S, RT.T[Target].Start);
          if IsBlank(S, LS, RT.T[Target].Start) then Indent := IndentAt(S, LS);
        end;
        Ofs := RT.T[Target].Start;
        LS := LineStartOf(S, Ofs);
        if IsBlank(S, LS, Ofs) then
          Insert(Indent + Stmt + EOL, S, LS + 1)
        else
          Insert(Stmt + ' ', S, Ofs + 1);
      end;
      Source := S;
      Result := True;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprRemoveCreateForm(var Source: string; const FormVarName: string): Boolean;
var
  RT: TRawToks;
  L: TCFList;
  I, A, B: Integer;
  S: string;
begin
  Result := False;
  try
    RT := TRawToks.Create(Source);
    try
      FindCreateForms(RT, L);
      for I := 0 to High(L) do
        if RT.IsId(L[I].VarTok, FormVarName) then
        begin
          S := Source;
          A := RT.T[L[I].AppTok].Start;
          B := RT.EndOf(L[I].EndTok);
          WholeLines(S, A, B);
          Delete(S, A + 1, B - A);
          Source := S;
          Result := True;
          Exit;
        end;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

function DprRenameCreateForm(var Source: string; const OldClass, OldVar, NewClass, NewVar: string): Boolean;
var
  RT: TRawToks;
  L: TCFList;
  I: Integer;
  S: string;
  E: TEdits;
begin
  Result := False;
  if not IsValidIdent(NewClass) or not IsValidIdent(NewVar) then Exit;
  try
    RT := TRawToks.Create(Source);
    try
      FindCreateForms(RT, L);
      for I := 0 to High(L) do
        if RT.IsId(L[I].VarTok, OldVar) and ((OldClass = '') or RT.IsId(L[I].ClassTok, OldClass)) then
        begin
          S := Source;
          E := TEdits.Create;
          try
            E.Add(RT.T[L[I].ClassTok].Start, RT.T[L[I].ClassTok].Len, NewClass);
            E.Add(RT.T[L[I].VarTok].Start, RT.T[L[I].VarTok].Len, NewVar);
            E.Apply(S);
          finally
            E.Free;
          end;
          Source := S;
          Result := True;
          Exit;
        end;
    finally
      RT.Free;
    end;
  except
    Result := False;
  end;
end;

initialization

finalization
  FreeAndNil(ViewUnit);
end.
