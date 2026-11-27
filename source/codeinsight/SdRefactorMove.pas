{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorMove;

{ D7 Studio - the refactorings that move code: Rename Unit (a unit, its file and its form's file
  renamed with every place that names it), Move to Unit (a declaration of a unit into another unit,
  the uses clauses following), Pull Members Up and Push Members Down (members of a class into its
  ancestor, into its descendants). As SdRefactor's: edits of the texts code insight reads, shown before
  they are applied; the files to rename in TRefactoring.Renames. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex, SdPasParser, SdCodeInsight, SdExplorerEdit, SdRefactor;

type
  { a member of a class that Pull Members Up or Push Members Down can move }
  TRefMember = class
  public
    Name: string;
    Text: string;              // its declaration: 'procedure Paint; override;'
    DeclStart: Integer;        // where the class names it (an offset of its unit)
    Checked: Boolean;
  end;

{ Rename Unit: the unit named at Pos - else the unit of the text - (Info, Places as
  TCodeInsight.SymbolPlaces gives them) }
function RenameUnitTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; out Error: string): Boolean;
{ NewName in every place that names the unit and in the projects' paths of its file; its file and its
  form's file renamed (R.Renames) }
function PlanRenameUnit(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  const NewName: string; out Error: string): Boolean;

{ Move to Unit: the declaration of the unit at Pos - a type (a class with its methods), a routine, a
  constant, a variable - (Info, Places) and the units of Files it can go to (Units: their files) }
function MoveTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; Units: TStrings; out Error: string): Boolean;
{ the declaration moved into the unit Target: in its interface when another unit names it; the
  units it needs into Target's uses clauses, Target into those of the units that name it;
  FormClass - the class of the source unit's form, which stays with its form ('' none) }
function PlanMoveToUnit(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  Files: TStrings; const Target, FormClass: string; out Error: string): Boolean;

{ Pull Members Up, Push Members Down: the class at Pos (ClassName), its members (TRefMember, the caller
  frees them; the one at Pos checked) and the classes of Files they can go to - Up: its ancestors,
  the nearest first; else its direct descendants }
function MembersTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; Up: Boolean; out ClassName: string; Members: TList; Targets: TStrings; out Error: string): Boolean;
{ the checked Members of ClassName moved into its ancestor Target: declared there in their sections,
  implemented in its unit }
function PlanPullUp(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string; Members: TList;
  Files: TStrings; const Target: string; out Error: string): Boolean;
{ the checked Members of ClassName moved into each of its direct descendants in Files }
function PlanPushDown(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string; Members: TList;
  Files: TStrings; out Error: string): Boolean;

implementation

uses
  Types, SdFormSrc;

type
  { a declaration of the source's implementation that moves along with what is moved }
  TMoveAlong = class
  public
    Name: string;
    Ofs: Integer;              // its place in the source: the order the target keeps
    Section: TKeyword;         // its section's word; kwNone - a routine
    Text: string;              // the declaration, or the routine's implementation
    Head: string;              // a routine's heading for the target's interface ('': none)
    InIntf: Boolean;           // a declaration into the target's interface
  end;

function CompareAlong(Item1, Item2: Pointer): Integer;
begin
  Result := TMoveAlong(Item1).Ofs - TMoveAlong(Item2).Ofs;
end;

{ ---------------------------------------------------------------------------- }
{ what they share }

{ the token of the unit's own name in its heading: unit Name; -1 none }
function HeadingNameTok(RT: TRawToks): Integer;
var
  K: Integer;
begin
  Result := -1;
  for K := 0 to RT.N - 2 do
    if RT.T[K].Kind = tkKeyword then
    begin
      if (RT.T[K].Keyword in [kwUnit, kwProgram, kwLibrary]) and (RT.T[K + 1].Kind = tkIdent) then Result := K + 1;
      Exit;
    end
    else if (RT.T[K].Kind = tkIdent) and (RT.T[K].Directive = dvPackage) then
    begin
      if RT.T[K + 1].Kind = tkIdent then Result := K + 1;
      Exit;
    end;
end;

{ the file of Files that declares the class Name (not as a forward declaration); '' none }
function ClassFile(R: TRefactoring; CI: TCodeInsight; Files: TStrings; const Name: string): string;
var
  I: Integer;
  U: TUnitInfo;
begin
  Result := '';
  for I := 0 to Files.Count - 1 do
  begin
    if not SameText(ExtractFileExt(Files[I]), '.pas') then Continue;
    U := ParseText(CI, Files[I], R.Source(Files[I]));
    try
      if U.FindTypeSym(Name, [tyClass]) <> nil then
      begin
        Result := Files[I];
        Exit;
      end;
    finally
      U.Free;
    end;
  end;
end;

{ the text of A .. B without the first line's indentation and the last line break: what a section
  of another unit takes }
function DeclText(const Src: string; A, B: Integer): string;
begin
  while (A < B) and (Src[A + 1] in [' ', #9]) do Inc(A);
  while (B > A) and (Src[B] in [#13, #10]) do Dec(B);
  Result := Copy(Src, A + 1, B - A);
end;

{ Ofs lies in one of the parts }
function InParts(const Parts: array of TPoint; Ofs: Integer): Boolean;
var
  Q: Integer;
begin
  Result := False;
  for Q := 0 to High(Parts) do
    if (Ofs >= Parts[Q].X) and (Ofs < Parts[Q].Y) then
    begin
      Result := True;
      Exit;
    end;
end;

{ the units the names of FileName's A .. B come from (Refs: the text's names, TCINameUse) - not the
  unit of ToFile, not System, not what is declared in the parts Skip of FileName (what moves with
  them) - into Needed }
procedure NamedUnits(Refs: TList; const FileName: string; A, B: Integer; const ToFile: string;
  const Skip: array of TPoint; Needed: TStrings);
var
  I: Integer;
  NU: TCINameUse;
  F, N: string;
begin
  for I := 0 to Refs.Count - 1 do
  begin
    NU := TCINameUse(Refs[I]);
    if (NU.Start < A) or (NU.Start >= B) or NU.Qualified then Continue;
    if NU.Kind = ckUnit then N := NU.Name
    else if (NU.Key <> '') and (NU.Key <> 'RESULT') and (NU.Key <> 'SELF') then
    begin
      F := KeyFile(NU.Key);
      if (F = '') or (F[1] = '<') or SameText(ExpandFileName(F), ExpandFileName(ToFile)) then Continue;
      if SameText(ExpandFileName(F), ExpandFileName(FileName)) and InParts(Skip, KeyOffset(NU.Key)) then Continue;
      N := ChangeFileExt(ExtractFileName(F), '');
    end
    else
      Continue;
    if not SameText(N, 'System') and not SameText(N, 'SysInit') and (Needed.IndexOf(N) < 0) then Needed.Add(N);
  end;
end;

{ the names of FileName's parts Parts[From ..] (TCINameUse) added to Refs; False: code insight could not
  read one }
function PartNames(CI: TCodeInsight; const FileName, Src: string; const Parts: array of TPoint; From: Integer;
  Refs: TList): Boolean;
var
  Q, I: Integer;
  L: TList;
begin
  Result := True;
  L := TList.Create;
  try
    for Q := From to High(Parts) do
    begin
      if not CI.NameUses(FileName, Src, Parts[Q].X, Parts[Q].Y, L) then Result := False;
      for I := 0 to L.Count - 1 do Refs.Add(L[I]);
      L.Clear;
    end;
  finally
    L.Free;
  end;
end;

{ the declaration of U's implementation, at the unit's level, that holds the place Ofs: a constant, a
  variable, a type (its members too), a routine's heading; nil - none (a routine's local) }
function ImplDeclAt(U: TUnitInfo; Ofs: Integer): TSymbol;
var
  I: Integer;
  S: TSymbol;
begin
  Result := nil;
  for I := 0 to U.ImplSyms.Count - 1 do
  begin
    S := U.ImplSyms[I];
    if S.DeclStart = Ofs then
    begin
      Result := S;
      Exit;
    end;
    if (S is TRoutineSym) and (Ofs >= TRoutineSym(S).HeadStart) and (Ofs < S.FullEnd) or
      not (S is TRoutineSym) and (Ofs > S.DeclStart) and (Ofs < S.FullEnd) then
      Result := S;
  end;
end;

{ the first name of the parts Scan of FileName (parsed: U; its names: Refs) that another unit could not
  reach once Moved has left: a declaration of U's implementation outside Moved (Decl: its declaration
  at the unit's level), or a member of a class of U that is private, or protected while the class
  Reacher does not derive from its class (Member). Part: the part of Scan that names it. False: none }
function Unreachable(R: TRefactoring; CI: TCodeInsight; Files: TStrings; U: TUnitInfo; Refs: TList;
  const FileName: string; const Scan, Moved: array of TPoint; const Reacher: string; out Decl, Member: TSymbol;
  out Part: Integer): Boolean;
var
  I, Q, Ofs: Integer;
  NU: TCINameUse;
  M: TSymbol;
begin
  Result := True;
  Decl := nil;
  Member := nil;
  for Q := 0 to High(Scan) do
    for I := 0 to Refs.Count - 1 do
    begin
      NU := TCINameUse(Refs[I]);
      if (NU.Start < Scan[Q].X) or (NU.Start >= Scan[Q].Y) or (NU.Key = '') or (NU.Key = 'RESULT') or
        (NU.Key = 'SELF') or not SameText(ExpandFileName(KeyFile(NU.Key)), ExpandFileName(FileName)) then Continue;
      Ofs := KeyOffset(NU.Key);
      if (Ofs < 0) or InParts(Moved, Ofs) then Continue;
      Part := Q;
      if Ofs >= U.ImplOfs then
      begin
        Decl := ImplDeclAt(U, Ofs);
        if Decl <> nil then Exit;
        Continue;
      end;
      M := SymbolAt(U, Ofs);
      if (M <> nil) and (M.Owner is TTypeDesc) and (TTypeDesc(M.Owner).Sym <> nil) and
        ((M.Visibility = viPrivate) or (M.Visibility = viProtected) and
        not R.ClassIs(CI, Files, Reacher, TTypeDesc(M.Owner).Sym.Name)) then
      begin
        Member := M;
        Exit;
      end;
    end;
  Part := -1;
  Result := False;
end;

{ why the members another unit gets cannot reach Member (Unreachable) }
function MemberCannot(const Who: string; Member: TSymbol; const Where: string): string;
var
  Vis: string;
begin
  if Member.Visibility = viPrivate then Vis := 'private' else Vis := 'protected';
  Result := Format('%s uses %s.%s, which is %s: %s could not reach it', [Who, TTypeDesc(Member.Owner).Sym.Name,
    Member.Name, Vis, Where]);
end;

{ the units of IntfNeeds and ImplNeeds into the uses clauses of the unit ToFile that does not use
  them: an interface's need into its interface's clause (the implementation's then dropped), an
  implementation's into its implementation's }
function AddNeeds(R: TRefactoring; CI: TCodeInsight; const ToFile: string; IntfNeeds, ImplNeeds: TStrings;
  out Error: string): Boolean;
var
  U: TUnitInfo;
  RT: TRawToks;
  Src: string;
  I: Integer;
  Intf, Impl: TStringList;
begin
  Result := False;
  Error := '';
  Src := R.Source(ToFile);
  U := ParseText(CI, ToFile, Src);
  RT := TRawToks.Create(Src, False);
  Intf := TStringList.Create;
  Impl := TStringList.Create;
  try
    for I := 0 to IntfNeeds.Count - 1 do
      if not SameText(IntfNeeds[I], U.Name) and (U.IntfUses.IndexOf(IntfNeeds[I]) < 0) then
      begin
        if U.ImplUses.IndexOf(IntfNeeds[I]) >= 0 then
        begin
          Error := Format('%s uses %s in its implementation: its interface would need it', [U.Name, IntfNeeds[I]]);
          Exit;
        end;
        Intf.Add(IntfNeeds[I]);
      end;
    for I := 0 to ImplNeeds.Count - 1 do
      if not SameText(ImplNeeds[I], U.Name) and (U.IntfUses.IndexOf(ImplNeeds[I]) < 0) and
        (U.ImplUses.IndexOf(ImplNeeds[I]) < 0) and (Intf.IndexOf(ImplNeeds[I]) < 0) then
        Impl.Add(ImplNeeds[I]);
    if (Intf.Count > 0) and not AddUsesNames(R, ToFile, Src, RT, U, Intf, False) then
    begin
      Error := Format('Could not add to the uses clause of %s', [U.Name]);
      Exit;
    end;
    if (Impl.Count > 0) and not AddUsesNames(R, ToFile, Src, RT, U, Impl, True) then
    begin
      Error := Format('Could not add to the uses clause of %s', [U.Name]);
      Exit;
    end;
    Result := True;
  finally
    Impl.Free;
    Intf.Free;
    RT.Free;
    U.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Rename Unit }

function RenameUnitTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; out Error: string): Boolean;
var
  RT: TRawToks;
  K: Integer;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) or (Info.Kind <> ckUnit) then
  begin
    { not on a unit's name: the unit of the text }
    FreeObjects(Places);
    RT := TRawToks.Create(Source, False);
    try
      K := HeadingNameTok(RT);
      if (K < 0) or not RT.IsKw(K - 1, kwUnit) then
      begin
        Error := 'Rename Unit renames a unit: Save Project As renames a project';
        Exit;
      end;
      if not CI.SymbolPlaces(FileName, Source, RT.T[K].Start, Files, Info, Places) or (Info.Kind <> ckUnit) then
      begin
        Error := 'Code insight does not know the unit';
        Exit;
      end;
    finally
      RT.Free;
    end;
  end;
  if (Info.FileName = '') or not InList(Files, Info.FileName) or not SameText(ExtractFileExt(Info.FileName), '.pas') then
  begin
    Error := Format('%s is not a unit of the project', [Info.Name]);
    Exit;
  end;
  Result := True;
end;

function PlanRenameUnit(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  const NewName: string; out Error: string): Boolean;
var
  I, K: Integer;
  P: TCIPlace;
  RT: TRawToks;
  Src, NewFile, OldDfm, Path, Lit, Found: string;
begin
  Result := False;
  Error := CheckNewName(NewName);
  if Error <> '' then Exit;
  if NewName = Info.Name then
  begin
    Error := 'The new name is the name it has';
    Exit;
  end;
  NewFile := ExtractFilePath(Info.FileName) + NewName + ExtractFileExt(Info.FileName);
  if not SameText(NewName, Info.Name) then
  begin
    if FileExists(NewFile) then
    begin
      Error := Format('%s exists already', [ExtractFileName(NewFile)]);
      Exit;
    end;
    Found := CI.FindUnitFile(NewName, Info.FileName);
    if Found <> '' then
    begin
      Error := Format('A unit %s is there already: %s', [NewName, Found]);
      Exit;
    end;
  end;
  for I := 0 to Places.Count - 1 do
  begin
    P := TCIPlace(Places[I]);
    R.AddEdit(P.FileName, P.Start, P.Len, NewName);
    { a project's entry: its path, Name in 'Path\Name.pas' }
    if SameText(ExtractFileExt(P.FileName), '.dpr') or SameText(ExtractFileExt(P.FileName), '.dpk') then
    begin
      Src := R.Source(P.FileName);
      RT := TRawToks.Create(Src, False);
      try
        K := RT.FirstAt(P.Start);
        if RT.IsKw(K + 1, kwIn) and (RT.T[K + 2].Kind = tkString) then
        begin
          Lit := RT.Txt(K + 2);
          Path := Copy(Lit, 2, Length(Lit) - 2);
          if SameText(ChangeFileExt(ExtractFileName(Path), ''), Info.Name) then
            R.AddEdit(P.FileName, RT.T[K + 2].Start, RT.T[K + 2].Len,
              '''' + ExtractFilePath(Path) + NewName + ExtractFileExt(Path) + '''');
        end;
      finally
        RT.Free;
      end;
    end;
  end;
  R.Renames.Add(Info.FileName + '=' + NewFile);
  OldDfm := ChangeFileExt(Info.FileName, '.dfm');
  if FileExists(OldDfm) then
  begin
    R.Renames.Add(OldDfm + '=' + ChangeFileExt(NewFile, '.dfm'));
    R.Notes.Add(Format('%s and %s are renamed %s and %s.', [ExtractFileName(Info.FileName), ExtractFileName(OldDfm),
      ExtractFileName(NewFile), ChangeFileExt(ExtractFileName(NewFile), '.dfm')]));
  end
  else
    R.Notes.Add(Format('%s is renamed %s.', [ExtractFileName(Info.FileName), ExtractFileName(NewFile)]));
  R.Title := Format('Rename unit %s to %s', [Info.Name, NewName]);
  Result := True;
end;

{ ---------------------------------------------------------------------------- }
{ Move to Unit }

function MoveTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places: TList; Units: TStrings; out Error: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  Error := '';
  Units.Clear;
  R.SetSource(FileName, Source);
  if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) then
  begin
    Error := 'Put the caret on the name of a declaration of the unit';
    Exit;
  end;
  if not (Info.Kind in [ckType, ckClass, ckInterface, ckRecord, ckEnum, ckProcedure, ckFunction, ckConst, ckVar,
    ckResourceString]) or Info.Local or (Info.Owner <> '') then
  begin
    Error := Format('%s is no type, routine, constant or variable of a unit', [SymbolTitle(Info)]);
    Exit;
  end;
  if (Info.FileName = '') or not InList(Files, Info.FileName) or not SameText(ExtractFileExt(Info.FileName), '.pas') then
  begin
    Error := Format('%s is not declared in a unit of the project', [Info.Name]);
    Exit;
  end;
  if Info.Overloaded then
  begin
    Error := Format('%s is overloaded: move its overloads by hand', [Info.Name]);
    Exit;
  end;
  for I := 0 to Files.Count - 1 do
    if SameText(ExtractFileExt(Files[I]), '.pas') and not SameText(ExpandFileName(Files[I]), ExpandFileName(Info.FileName)) then
      Units.Add(Files[I]);
  if Units.Count = 0 then
  begin
    Error := 'The project has no other unit';
    Exit;
  end;
  Result := True;
end;

function PlanMoveToUnit(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList;
  Files: TStrings; const Target, FormClass: string; out Error: string): Boolean;
var
  US, UT, UY: TUnitInfo;
  RT, RTY: TRawToks;
  Src, TSrc, YSrc, EOL, Head, Body, Bodies, Before, TName, SName, Reacher: string;
  S, D, E, Member: TSymbol;
  Rou, Decl: TRoutineSym;
  Moved: array of TPoint;      // the parts that leave the source: X .. Y
  Scan: array of TPoint;       // the parts whose names the target needs: those, and the type of a list's name
  IsBody: array of Boolean;    // a part of Scan is an implementation's (else a declaration's)
  L, Uses_, Gone, Along, Spots: TList;
  I, J, K, A, B, DeclOfs, First, Part, Scanned: Integer;
  NeedIntf, SIntf, SImpl, IsClass: Boolean;
  Section: TKeyword;
  P: TCIPlace;
  EInfo: TCISymbolInfo;
  Al: TMoveAlong;
  TIntf, TImpl, Needs, YIntf, YImpl, Done, Own: TStringList;
  Groups: TStringList;         // the declarations for the target: a section's text, Ord(word) * 2 + Ord(interface)

  { a part whose names the target needs (AsBody: an implementation's); Leaves - it leaves the source }
  procedure AddPart(X, Y: Integer; AsBody, Leaves: Boolean);
  begin
    SetLength(Scan, Length(Scan) + 1);
    SetLength(IsBody, Length(Scan));
    Scan[High(Scan)].X := X;
    Scan[High(Scan)].Y := Y;
    IsBody[High(Scan)] := AsBody;
    if Leaves then
    begin
      SetLength(Moved, Length(Moved) + 1);
      Moved[High(Moved)] := Scan[High(Scan)];
    end;
  end;

  procedure AddMoved(X, Y: Integer; AsBody: Boolean);
  begin
    AddPart(X, Y, AsBody, True);
  end;

  function SameFile(const F1, F2: string): Boolean;
  begin
    Result := SameText(ExpandFileName(F1), ExpandFileName(F2));
  end;

  function IsMoved(const F: string; Ofs: Integer): Boolean;
  begin
    Result := SameFile(F, Info.FileName) and InParts(Moved, Ofs);
  end;

  { the declaration S of a section moves: its text for the target (a name of a list as a declaration
    of its own), its section's word; it leaves the source with the others (Gone) }
  function TakeDecl(S: TSymbol; AsBody: Boolean; out Text: string; out Sec: TKeyword): Boolean;
  var
    T, X, Y: Integer;
  begin
    Result := False;
    Sec := SectionWordOf(RT, US, S.DeclStart);
    if Sec = kwNone then
    begin
      Error := Format('The section of %s is not found', [S.Name]);
      Exit;
    end;
    T := RT.FirstAt(S.DeclStart);
    if RT.IsSy(T + 1, syComma) or RT.IsSy(T - 1, syComma) then
    begin
      if S.TypeEnd <= S.TypeStart then
      begin
        Error := Format('The type of %s is not found', [S.Name]);
        Exit;
      end;
      Text := S.Name + ': ' + Trim(Copy(Src, S.TypeStart + 1, S.TypeEnd - S.TypeStart)) + ';';
      AddMoved(RT.T[T].Start, RT.EndOf(T), AsBody);
      { the type the list's names share stays: what it names the target needs too }
      AddPart(S.TypeStart, S.TypeEnd, AsBody, False);
    end
    else
    begin
      X := S.DeclStart;
      Y := S.FullEnd;
      if WholeLines(Src, X, Y) then X := CommentStart(Src, X);
      Text := DeclText(Src, X, S.FullEnd);
      AddMoved(X, Y, AsBody);
    end;
    Gone.Add(Pointer(S.DeclStart));
    Result := True;
  end;

  { the implementation Rou leaves the source: its text; Start - where it begins }
  function TakeBody(Rou: TRoutineSym; out Start: Integer): string;
  var
    Y: Integer;
  begin
    BodyRange(Src, RT, Rou, Start, Y);
    AddMoved(Start, Y, True);
    R.AddEdit(Info.FileName, Start, BlankAfter(Src, Start, Y) - Start, '');
    Result := DeclText(Src, Start, Y);
  end;

  { a declaration for a section Sec of the target's interface (InIntf) or implementation: after the
    others of that section }
  procedure AddDecl(Sec: TKeyword; InIntf: Boolean; const Text: string);
  var
    X: Integer;
  begin
    X := Groups.IndexOfObject(TObject(Ord(Sec) * 2 + Ord(InIntf)));
    if X < 0 then Groups.AddObject(Text, TObject(Ord(Sec) * 2 + Ord(InIntf)))
    else Groups[X] := Groups[X] + EOL + '  ' + Text;
  end;

begin
  Result := False;
  Error := '';
  Src := R.Source(Info.FileName);
  TSrc := R.Source(Target);
  EOL := DetectEOL(TSrc);
  US := ParseText(CI, Info.FileName, Src);
  UT := ParseText(CI, Target, TSrc);
  RT := TRawToks.Create(Src, False);
  L := TList.Create;
  Uses_ := TList.Create;
  Gone := TList.Create;
  Along := TList.Create;
  Spots := TList.Create;
  Own := TStringList.Create;
  Groups := TStringList.Create;
  TIntf := TStringList.Create;
  TImpl := TStringList.Create;
  Needs := TStringList.Create;
  YIntf := TStringList.Create;
  YImpl := TStringList.Create;
  Done := TStringList.Create;
  try
    SName := US.Name;
    TName := UT.Name;
    if UT.IsProgram then
    begin
      Error := 'A declaration moves into a unit, not into a program';
      Exit;
    end;
    if SameText(Info.Name, FormClass) then
    begin
      Error := Format('%s is the class of the form of %s: it stays with its form', [Info.Name, SName]);
      Exit;
    end;
    if (UT.IntfSyms.Find(Info.Name) <> nil) or (UT.ImplSyms.Find(Info.Name) <> nil) then
    begin
      Error := Format('%s already declares %s', [TName, Info.Name]);
      Exit;
    end;
    { the declaration }
    DeclOfs := -1;
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl and SameFile(P.FileName, Info.FileName) and ((DeclOfs < 0) or (P.Start < DeclOfs)) then DeclOfs := P.Start;
    end;
    S := nil;
    if DeclOfs >= 0 then
    begin
      S := US.IntfSyms.Find(Info.Name);
      while (S <> nil) and (S.DeclStart <> DeclOfs) do S := US.IntfSyms.FindNext(S);
      if S = nil then
      begin
        S := US.ImplSyms.Find(Info.Name);
        while (S <> nil) and (S.DeclStart <> DeclOfs) do S := US.ImplSyms.FindNext(S);
      end;
      if (S = nil) and IsRoutineKind(Info.Kind) then S := RoutineNamedAt(US, DeclOfs);
    end;
    if S = nil then
    begin
      Error := Format('The declaration of %s is not found', [Info.Name]);
      Exit;
    end;
    IsClass := (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Kind = tyClass);
    Section := kwNone;
    Head := '';
    Body := '';
    Bodies := '';
    Rou := nil;
    Decl := nil;
    { what moves, out of the source }
    if IsRoutineKind(Info.Kind) then
    begin
      { a routine: its declarations, its implementation }
      for I := 0 to Places.Count - 1 do
      begin
        P := TCIPlace(Places[I]);
        if not P.Decl or not SameFile(P.FileName, Info.FileName) then Continue;
        S := RoutineNamedAt(US, P.Start);
        if S = nil then Continue;
        if sfImplBody in S.Flags then
          Rou := TRoutineSym(S)
        else
        begin
          if Decl = nil then Decl := TRoutineSym(S);
          A := TRoutineSym(S).HeadStart;
          B := S.FullEnd;
          if WholeLines(Src, A, B) then A := CommentStart(Src, A);
          AddMoved(A, B, False);
          R.AddEdit(Info.FileName, A, BlankAfter(Src, A, B) - A, '');
        end;
      end;
      if Rou = nil then
      begin
        Error := Format('The implementation of %s is not found', [Info.Name]);
        Exit;
      end;
      Body := TakeBody(Rou, A);
      if Decl <> nil then Head := DeclText(Src, Decl.HeadStart, Decl.FullEnd)
      else Head := DeclText(Src, Rou.HeadStart, Rou.FullEnd);
    end
    else
    begin
      { a type, a constant, a variable: its declaration in its section }
      if not TakeDecl(S, False, Head, Section) then Exit;
      if IsClass then
      begin
        { a class: the bodies of its methods with the comment that marks them, its forward
          declarations }
        US.GetImpls(L, Info.Name, '');
        First := MaxInt;
        for I := 0 to L.Count - 1 do
        begin
          Bodies := Bodies + TakeBody(TRoutineSym(L[I]), A) + EOL + EOL;
          if A < First then First := A;
        end;
        if First < MaxInt then
        begin
          K := MarkerAbove(Src, Info.Name, First);
          if K >= 0 then R.AddEdit(Info.FileName, K, NextLineStart(Src, K) - K, '');
        end;
        for K := 0 to RT.N - 4 do
          if RT.IsId(K, Info.Name) and (RT.T[K].Start <> S.DeclStart) and RT.IsSy(K + 1, syEqual) and
            RT.IsKw(K + 2, kwClass) and RT.IsSy(K + 3, sySemicolon) then
          begin
            AddMoved(RT.T[K].Start, RT.EndOf(K + 3), False);
            RemoveDecl(R, Info.FileName, Src, RT, RT.T[K].Start, RT.EndOf(K + 3), False);
          end;
      end;
    end;
    { who names it: the source and the other units then use the target, in the part that names it;
      Unit.Name the target's name. What the source's interface declared stays in the target's }
    if IsRoutineKind(Info.Kind) then NeedIntf := (Decl <> nil) and (Decl.HeadStart < US.ImplOfs)
    else NeedIntf := S.DeclStart < US.ImplOfs;
    SIntf := False;
    SImpl := False;
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl or IsMoved(P.FileName, P.Start) or SameFile(P.FileName, Target) then Continue;
      NeedIntf := True;
      if SameFile(P.FileName, Info.FileName) then
      begin
        if P.Start < US.ImplOfs then SIntf := True else SImpl := True;
        Continue;
      end;
      if Done.IndexOf(P.FileName) >= 0 then Continue;
      Done.Add(P.FileName);
      YSrc := R.Source(P.FileName);
      UY := ParseText(CI, P.FileName, YSrc);
      RTY := TRawToks.Create(YSrc, False);
      try
        YIntf.Clear;
        YImpl.Clear;
        for J := I to Places.Count - 1 do
          with TCIPlace(Places[J]) do
            if not Decl and SameFile(FileName, P.FileName) then
            begin
              K := RTY.FirstAt(Start);
              if RTY.IsSy(K - 1, syDot) and RTY.IsId(K - 2, SName) then
                R.AddEdit(FileName, RTY.T[K - 2].Start, RTY.T[K - 2].Len, TName);
              if UY.IsProgram or (Start < UY.ImplOfs) then
              begin
                if YIntf.IndexOf(TName) < 0 then YIntf.Add(TName);
              end
              else if YImpl.IndexOf(TName) < 0 then
                YImpl.Add(TName);
            end;
        if not AddNeeds(R, CI, P.FileName, YIntf, YImpl, Error) then Exit;
      finally
        RTY.Free;
        UY.Free;
      end;
    end;
    { a routine only the implementation declared: its heading goes into the target's interface, and
      what it names into the interface's uses }
    if NeedIntf and (Rou <> nil) and (Decl = nil) then AddPart(Rou.HeadStart, Rou.FullEnd, False, False);
    { what the moved text names that the target could not reach: a declaration of the source's
      implementation moves along when nothing else of the source names it - into the target's
      interface when a declaration there names it -, then what it names in turn }
    if IsClass then Reacher := Info.Name else Reacher := '';
    Own.Add(Info.FileName);
    Scanned := 0;
    repeat
      if not PartNames(CI, Info.FileName, Src, Scan, Scanned, Uses_) then
      begin
        Error := Format('Code insight could not read %s', [SName]);
        Exit;
      end;
      Scanned := Length(Scan);
      if not Unreachable(R, CI, Files, US, Uses_, Info.FileName, Scan, Moved, Reacher, D, Member, Part) then Break;
      if Member <> nil then
      begin
        Error := MemberCannot(Info.Name, Member, TName);
        Exit;
      end;
      if (D is TRoutineSym) and ((D.Flags * [sfOverload, sfForward, sfExternal] <> []) or not (sfImplBody in D.Flags)) or
        (D.Kind = skType) and (D.TypeDesc <> nil) and (D.TypeDesc.Kind in [tyClass, tyObject, tyInterface]) then
      begin
        Error := Format('%s uses %s, which the implementation of %s declares: move it first', [Info.Name, D.Name, SName]);
        Exit;
      end;
      if D is TRoutineSym then
        BodyRange(Src, RT, TRoutineSym(D), A, B)
      else
      begin
        A := D.DeclStart;
        B := D.FullEnd;
      end;
      { nothing else of the source names what it declares: it, the values of an enumeration }
      for J := 0 to US.ImplSyms.Count - 1 do
      begin
        E := US.ImplSyms[J];
        if (E.DeclStart < A) or (E.DeclStart >= B) then Continue;
        FreeObjects(Spots);
        if not CI.SymbolPlaces(Info.FileName, Src, E.DeclStart, Own, EInfo, Spots) then Continue;
        for K := 0 to Spots.Count - 1 do
        begin
          P := TCIPlace(Spots[K]);
          if not P.Decl and SameFile(P.FileName, Info.FileName) and ((P.Start < A) or (P.Start >= B)) and
            not InParts(Moved, P.Start) then
          begin
            Error := Format('%s uses %s, which line %d of %s uses too: declare it in the interface of %s first',
              [Info.Name, D.Name, P.Line, SName, SName]);
            Exit;
          end;
        end;
      end;
      Al := TMoveAlong.Create;
      Along.Add(Al);
      Al.Name := D.Name;
      Al.InIntf := NeedIntf and not IsBody[Part];
      if D is TRoutineSym then
      begin
        Al.Section := kwNone;
        Al.Text := TakeBody(TRoutineSym(D), Al.Ofs);
        if Al.InIntf then
        begin
          Al.Head := DeclText(Src, TRoutineSym(D).HeadStart, D.FullEnd);
          AddPart(TRoutineSym(D).HeadStart, D.FullEnd, False, False);
        end;
      end
      else
      begin
        Al.Ofs := D.DeclStart;
        if not TakeDecl(D, not Al.InIntf, Al.Text, Al.Section) then Exit;
      end;
      R.Notes.Add(Format('%s moves with %s: nothing else of %s names it.', [D.Name, Info.Name, SName]));
    until False;
    if not RemoveDecls(R, Info.FileName, Src, RT, US, Gone, True) then
    begin
      Error := Format('Could not take the declaration of %s out', [Info.Name]);
      Exit;
    end;
    { what the moved text names: the units the target then uses - the source too, but the two never
      through both their interfaces }
    for I := 0 to High(Scan) do
    begin
      Needs.Clear;
      NamedUnits(Uses_, Info.FileName, Scan[I].X, Scan[I].Y, Target, Moved, Needs);
      for J := 0 to Needs.Count - 1 do
        if NeedIntf and not IsBody[I] then
        begin
          if TIntf.IndexOf(Needs[J]) < 0 then TIntf.Add(Needs[J]);
        end
        else if TImpl.IndexOf(Needs[J]) < 0 then
          TImpl.Add(Needs[J]);
    end;
    if (TIntf.IndexOf(SName) >= 0) and (SIntf or (US.IntfUses.IndexOf(TName) >= 0)) or
      SIntf and (UT.IntfUses.IndexOf(SName) >= 0) then
    begin
      Error := Format('%s and %s would use each other in their interfaces', [SName, TName]);
      Exit;
    end;
    if SIntf or SImpl then
    begin
      YIntf.Clear;
      YImpl.Clear;
      if SIntf then YIntf.Add(TName) else YImpl.Add(TName);
      if not AddNeeds(R, CI, Info.FileName, YIntf, YImpl, Error) then Exit;
    end;
    if not AddNeeds(R, CI, Target, TIntf, TImpl, Error) then Exit;
    { into the target, in the source's order: the declarations - what moves along, then the
      declaration -, those of a kind and a part in one section; the routines' headings in the
      interface; the routines that move along before the implementations, at its end }
    RT.Free;
    RT := TRawToks.Create(TSrc, False);
    Along.Sort(CompareAlong);
    for I := 0 to Along.Count - 1 do
      if TMoveAlong(Along[I]).Section <> kwNone then
        AddDecl(TMoveAlong(Along[I]).Section, TMoveAlong(Along[I]).InIntf, TMoveAlong(Along[I]).Text);
    if not IsRoutineKind(Info.Kind) then AddDecl(Section, NeedIntf, Head);
    for I := 0 to Groups.Count - 1 do
      if not AddSectionDecl(R, Target, TSrc, RT, UT, TKeyword(Integer(Groups.Objects[I]) div 2),
        Odd(Integer(Groups.Objects[I])), True, Groups[I]) then
      begin
        Error := Format('Could not find where to declare %s in %s', [Info.Name, TName]);
        Exit;
      end;
    Before := '';
    for I := 0 to Along.Count - 1 do
    begin
      Al := TMoveAlong(Along[I]);
      if Al.Section <> kwNone then Continue;
      Before := Before + Al.Text + EOL + EOL;
      if Al.Head <> '' then R.AddEdit(Target, LineStartOf(TSrc, UT.ImplOfs), 0, Al.Head + EOL + EOL);
    end;
    if IsRoutineKind(Info.Kind) then
    begin
      if NeedIntf then R.AddEdit(Target, LineStartOf(TSrc, UT.ImplOfs), 0, Head + EOL + EOL);
      Bodies := Body + EOL + EOL;
    end
    else if Bodies <> '' then
      Bodies := '{ ' + Info.Name + ' }' + EOL + EOL + Bodies;
    if Before + Bodies <> '' then
    begin
      if IsClass and (Bodies <> '') then A := ExplorerBodyPos(UT, Info.Name, '') else A := ExplorerBodyPos(UT, '', '');
      if A < 0 then
      begin
        Error := Format('Could not find where %s ends', [TName]);
        Exit;
      end;
      R.AddEdit(Target, A, 0, Before + Bodies);
    end;
    R.Title := Format('Move %s to %s', [Info.Name, TName]);
    Result := True;
  finally
    Done.Free;
    YImpl.Free;
    YIntf.Free;
    Needs.Free;
    TImpl.Free;
    TIntf.Free;
    Groups.Free;
    Own.Free;
    FreeObjects(Spots);
    Spots.Free;
    FreeObjects(Along);
    Along.Free;
    Gone.Free;
    FreeObjects(Uses_);
    Uses_.Free;
    L.Free;
    RT.Free;
    UT.Free;
    US.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Pull Members Up, Push Members Down }

{ where a member's declaration begins: a routine's word, a property's, a field's name }
function MemberStartOfs(RT: TRawToks; M: TSymbol): Integer;
var
  K: Integer;
begin
  if M is TRoutineSym then
  begin
    if M.Kind = skProperty then
    begin
      K := RT.FirstAt(M.DeclStart) - 1;
      while (K > 0) and not RT.IsKw(K, kwProperty) do Dec(K);
      if K > 0 then
      begin
        Result := RT.T[K].Start;
        Exit;
      end;
    end
    else if TRoutineSym(M).HeadStart > 0 then
    begin
      Result := TRoutineSym(M).HeadStart;
      Exit;
    end;
  end;
  Result := M.DeclStart;
end;

{ a member as a class declares it: a field alone with its type (out of a list too) }
function MemberText(const Src: string; RT: TRawToks; M: TSymbol): string;
begin
  if M.Kind = skField then Result := M.Name + ': ' + Trim(Copy(Src, M.TypeStart + 1, M.TypeEnd - M.TypeStart)) + ';'
  else Result := DeclText(Src, MemberStartOfs(RT, M), M.FullEnd);
end;

{ the Code Explorer's section of a member's visibility (a class's first section published) }
function SectionAccess(V: TVisibility): Integer;
begin
  case V of
    viPrivate: Result := 1;
    viProtected: Result := 2;
    viPublic: Result := 3;
  else
    Result := 0;
  end;
end;

{ the implementations of the method M of ClassName in U: an overload's own }
procedure MethodBodies(U: TUnitInfo; const ClassName: string; M: TSymbol; List: TList);
var
  S: TSymbol;
begin
  List.Clear;
  if M.Kind <> skRoutine then Exit;
  U.GetImpls(List, ClassName, M.Name);
  if (sfOverload in M.Flags) and (List.Count > 1) then
  begin
    S := PairRoutine(M, List);
    List.Clear;
    if S <> nil then List.Add(S);
  end;
end;

function MembersTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; Up: Boolean; out ClassName: string; Members: TList; Targets: TStrings; out Error: string): Boolean;
var
  U: TUnitInfo;
  RT: TRawToks;
  C, M: TSymbol;
  Rou: TRoutineSym;
  X: TRefMember;
  A: string;
  I, N: Integer;
begin
  Result := False;
  Error := '';
  ClassName := '';
  Targets.Clear;
  R.SetSource(FileName, Source);
  U := ParseText(CI, FileName, Source);
  RT := TRawToks.Create(Source, False);
  try
    C := ClassAtOffset(U, Pos);
    if (C = nil) or (C.TypeDesc = nil) or (C.TypeDesc.Members = nil) then
    begin
      Error := 'Put the caret in the declaration of a class or in one of its methods';
      Exit;
    end;
    ClassName := C.Name;
    if Up then
    begin
      A := R.ClassAncestor(CI, Files, ClassName);
      N := 0;
      while (A <> '') and (N < 32) do
      begin
        if ClassFile(R, CI, Files, A) <> '' then Targets.Add(A);
        A := R.ClassAncestor(CI, Files, A);
        Inc(N);
      end;
      if Targets.Count = 0 then
      begin
        Error := Format('No ancestor of %s is declared in the project', [ClassName]);
        Exit;
      end;
    end
    else
    begin
      R.Descendants(CI, Files, ClassName, Targets);
      if Targets.Count = 0 then
      begin
        Error := Format('No class of the project derives from %s', [ClassName]);
        Exit;
      end;
    end;
    { its members, the one at Pos (its declaration, its implementation) checked }
    Rou := RoutineAround(U, Pos, Pos);
    if Rou <> nil then Rou := MethodOf(Rou);
    for I := 0 to C.TypeDesc.Members.Count - 1 do
    begin
      M := C.TypeDesc.Members[I];
      if not (M.Kind in [skField, skRoutine, skProperty]) then Continue;
      X := TRefMember.Create;
      Members.Add(X);
      X.Name := M.Name;
      X.DeclStart := M.DeclStart;
      X.Text := MemberText(Source, RT, M);
      X.Checked := ((Pos >= MemberStartOfs(RT, M)) and (Pos <= M.FullEnd)) or ((Rou <> nil) and
        SameText(Rou.ClassQual, ClassName) and SameText(Rou.Name, M.Name));
    end;
    if Members.Count = 0 then
    begin
      Error := Format('%s has no fields, methods or properties of its own', [ClassName]);
      Exit;
    end;
    Result := True;
  finally
    RT.Free;
    U.Free;
  end;
end;

{ the checked Members of ClassName (in FileName) moved: Up - into the ancestor Targets[0]; else into
  each class of Targets (its direct descendants) }
function MoveMembers(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string; Members: TList;
  Files, Targets: TStrings; Up: Boolean; out Error: string): Boolean;
var
  US, UT, U2: TUnitInfo;
  RT: TRawToks;
  C, S, M2, D, Member: TSymbol;
  CD: TTypeDesc;
  Chosen, L, Places, Uses_: TList;
  Moved: array of TPoint;
  IsBody: array of Boolean;
  Names, TIntf, TImpl, Needs, Others: TStringList;
  I, J, K, A, B, Q, Access, Start: Integer;
  X: TRefMember;
  Info: TCISymbolInfo;
  P: TCIPlace;
  NU: TCINameUse;
  Rou: TRoutineSym;
  TFile, TSrc, Src2, Text, Ins, Shown, EOL, Body, Target: string;
  Field, Inside: Boolean;

  procedure AddMoved(X1, Y1: Integer; AsBody: Boolean);
  begin
    SetLength(Moved, Length(Moved) + 1);
    SetLength(IsBody, Length(Moved));
    Moved[High(Moved)].X := X1;
    Moved[High(Moved)].Y := Y1;
    IsBody[High(Moved)] := AsBody;
  end;

begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  US := ParseText(CI, FileName, Source);
  RT := TRawToks.Create(Source, False);
  Chosen := TList.Create;
  L := TList.Create;
  Places := TList.Create;
  Uses_ := TList.Create;
  Names := TStringList.Create;
  TIntf := TStringList.Create;
  TImpl := TStringList.Create;
  Needs := TStringList.Create;
  Others := TStringList.Create;
  try
    C := US.FindTypeSym(ClassName, [tyClass]);
    if C = nil then
    begin
      Error := Format('%s is not declared in this unit', [ClassName]);
      Exit;
    end;
    CD := C.TypeDesc;
    { the members chosen, by their places }
    for I := 0 to Members.Count - 1 do
    begin
      X := TRefMember(Members[I]);
      if not X.Checked then Continue;
      S := CD.Members.Find(X.Name);
      while (S <> nil) and (S.DeclStart <> X.DeclStart) do S := CD.Members.FindNext(S);
      if S = nil then
      begin
        Error := Format('%s.%s is not found any more', [ClassName, X.Name]);
        Exit;
      end;
      Chosen.Add(S);
      Names.Add(S.Name);
    end;
    if Chosen.Count = 0 then
    begin
      Error := 'Check what to move';
      Exit;
    end;
    Shown := Names.CommaText;
    { what moves: their declarations and implementations }
    for I := 0 to Chosen.Count - 1 do
    begin
      S := TSymbol(Chosen[I]);
      A := MemberStartOfs(RT, S);
      B := S.FullEnd;
      if S.Kind <> skField then
        if WholeLines(Source, A, B) then A := CommentStart(Source, A);
      AddMoved(A, B, False);
      MethodBodies(US, ClassName, S, L);
      for J := 0 to L.Count - 1 do
      begin
        BodyRange(Source, RT, TRoutineSym(L[J]), A, B);
        AddMoved(A, B, True);
      end;
    end;
    { what they name: no member of the class that stays (Self.Member too) }
    if not PartNames(CI, FileName, Source, Moved, 0, Uses_) then
    begin
      Error := 'Code insight could not read the members';
      Exit;
    end;
    for J := 0 to Uses_.Count - 1 do
    begin
      NU := TCINameUse(Uses_[J]);
      K := RT.FirstAt(NU.Start);
      if NU.Qualified and not (RT.IsSy(K - 1, syDot) and RT.IsId(K - 2, 'Self')) then Continue;
      if not SameText(ExpandFileName(KeyFile(NU.Key)), ExpandFileName(FileName)) then Continue;
      Q := KeyOffset(NU.Key);
      if (Q > C.DeclStart) and (Q < CD.EndOfs) and (Names.IndexOf(NU.Name) < 0) then
      begin
        Error := Format('%s uses %s, which stays in %s: move it too', [Names[0], NU.Name, ClassName]);
        Exit;
      end;
    end;
    if Up then
    begin
      { the ancestor and the rest of its descendants have no member of their names }
      Target := Targets[0];
      Others.Clear;
      R.Descendants(CI, Files, Target, Others);
      Others.Insert(0, Target);
      I := 0;
      while I < Others.Count do
      begin
        if not R.ClassIs(CI, Files, Others[I], ClassName) then
        begin
          TFile := ClassFile(R, CI, Files, Others[I]);
          if TFile <> '' then
          begin
            U2 := ParseText(CI, TFile, R.Source(TFile));
            try
              M2 := U2.FindTypeSym(Others[I], [tyClass]);
              if M2 <> nil then
                for J := 0 to Chosen.Count - 1 do
                  if M2.TypeDesc.Members.Find(TSymbol(Chosen[J]).Name) <> nil then
                  begin
                    Error := Format('%s has a member named %s already', [Others[I], TSymbol(Chosen[J]).Name]);
                    Exit;
                  end;
            finally
              U2.Free;
            end;
          end;
          { its descendants too }
          if I > 0 then
          begin
            Needs.Clear;
            R.Descendants(CI, Files, Others[I], Needs);
            for J := 0 to Needs.Count - 1 do
              if Others.IndexOf(Needs[J]) < 0 then Others.Add(Needs[J]);
          end;
        end;
        Inc(I);
      end;
    end
    else
    begin
      { nothing reaches them through the class but its descendants' methods; no descendant has them }
      for I := 0 to Chosen.Count - 1 do
      begin
        S := TSymbol(Chosen[I]);
        FreeObjects(Places);
        if not CI.SymbolPlaces(FileName, Source, S.DeclStart, Files, Info, Places) then Continue;
        for J := 0 to Places.Count - 1 do
        begin
          P := TCIPlace(Places[J]);
          if P.Decl or (SameText(ExpandFileName(P.FileName), ExpandFileName(FileName)) and InParts(Moved, P.Start)) then Continue;
          Src2 := R.Source(P.FileName);
          U2 := ParseText(CI, P.FileName, Src2);
          try
            Rou := RoutineAround(U2, P.Start, P.Start);
            if Rou <> nil then Rou := MethodOf(Rou);
            Inside := (Rou <> nil) and not SameText(Rou.ClassQual, ClassName) and
              R.ClassIs(CI, Files, Rou.ClassQual, ClassName);
          finally
            U2.Free;
          end;
          if not Inside then
          begin
            Error := Format('%s(%d) uses %s, which %s would no longer have', [ExtractFileName(P.FileName), P.Line,
              S.Name, ClassName]);
            Exit;
          end;
        end;
      end;
      for I := 0 to Targets.Count - 1 do
      begin
        TFile := ClassFile(R, CI, Files, Targets[I]);
        if TFile = '' then Continue;
        U2 := ParseText(CI, TFile, R.Source(TFile));
        try
          M2 := U2.FindTypeSym(Targets[I], [tyClass]);
          if M2 <> nil then
            for J := 0 to Chosen.Count - 1 do
              if M2.TypeDesc.Members.Find(TSymbol(Chosen[J]).Name) <> nil then
              begin
                Error := Format('%s has a member named %s already', [Targets[I], TSymbol(Chosen[J]).Name]);
                Exit;
              end;
        finally
          U2.Free;
        end;
      end;
    end;
    { out of the class }
    for I := 0 to Chosen.Count - 1 do
    begin
      S := TSymbol(Chosen[I]);
      if S.Kind = skField then
      begin
        if not RemoveDecl(R, FileName, Source, RT, S.DeclStart, -1, True) then
        begin
          Error := Format('Could not take %s out', [S.Name]);
          Exit;
        end;
      end
      else
      begin
        A := MemberStartOfs(RT, S);
        B := S.FullEnd;
        if WholeLines(Source, A, B) then A := CommentStart(Source, A);
        R.AddEdit(FileName, A, B - A, '');
      end;
      MethodBodies(US, ClassName, S, L);
      for J := 0 to L.Count - 1 do
      begin
        BodyRange(Source, RT, TRoutineSym(L[J]), A, B);
        R.AddEdit(FileName, A, BlankAfter(Source, A, B) - A, '');
      end;
    end;
    { into each target: the declarations in their sections (fields first), the bodies at the
      Code Explorer's place, the units they need }
    for I := 0 to Targets.Count - 1 do
    begin
      if Up and (I > 0) then Break;
      Target := Targets[I];
      TFile := ClassFile(R, CI, Files, Target);
      if TFile = '' then
      begin
        Error := Format('%s is not declared in the project', [Target]);
        Exit;
      end;
      TSrc := R.Source(TFile);
      UT := ParseText(CI, TFile, TSrc);
      try
        { in another unit: nothing they name may be the source's own alone }
        if not SameText(ExpandFileName(TFile), ExpandFileName(FileName)) and
          Unreachable(R, CI, Files, US, Uses_, FileName, Moved, Moved, Target, D, Member, Q) then
        begin
          if Member <> nil then Error := MemberCannot(Shown, Member, Target)
          else Error := Format('%s uses %s, which the implementation of %s declares: %s could not reach it',
            [Shown, D.Name, US.Name, UT.Name]);
          Exit;
        end;
        for Access := 0 to 3 do
        begin
          Text := '';
          Field := False;
          for Q := 0 to 1 do
            for J := 0 to Chosen.Count - 1 do
            begin
              S := TSymbol(Chosen[J]);
              K := SectionAccess(S.Visibility);
              { a private member of a class of another unit: protected, or what stays could not see it }
              if (K = 1) and not SameText(ExpandFileName(TFile), ExpandFileName(FileName)) then K := 2;
              if (K <> Access) or ((Q = 0) <> (S.Kind = skField)) then Continue;
              if Text <> '' then Text := Text + EOL;
              Text := Text + '    ' + MemberText(Source, RT, S);
              if S.Kind = skField then Field := True;
            end;
          if Text = '' then Continue;
          if not ExplorerMemberEdit(UT, Target, Access, Field, Text, Start, Ins, Error) then Exit;
          R.AddEdit(TFile, Start, 0, Ins);
        end;
        for J := 0 to Chosen.Count - 1 do
        begin
          S := TSymbol(Chosen[J]);
          MethodBodies(US, ClassName, S, L);
          for K := 0 to L.Count - 1 do
          begin
            BodyRange(Source, RT, TRoutineSym(L[K]), A, B);
            Body := DeclText(Source, A, B);
            Q := System.Pos(UpperCase(ClassName + '.' + S.Name), UpperCase(Body));
            if Q > 0 then Body := Copy(Body, 1, Q - 1) + Target + Copy(Body, Q + Length(ClassName), MaxInt);
            A := ExplorerBodyPos(UT, Target, S.Name);
            if A < 0 then
            begin
              Error := Format('Could not find where to implement %s.%s', [Target, S.Name]);
              Exit;
            end;
            R.AddEdit(TFile, A, 0, Body + EOL + EOL);
          end;
        end;
        { the units the moved text names }
        TIntf.Clear;
        TImpl.Clear;
        for J := 0 to High(Moved) do
        begin
          Needs.Clear;
          NamedUnits(Uses_, FileName, Moved[J].X, Moved[J].Y, TFile, Moved, Needs);
          for K := 0 to Needs.Count - 1 do
            if IsBody[J] then
            begin
              if TImpl.IndexOf(Needs[K]) < 0 then TImpl.Add(Needs[K]);
            end
            else if TIntf.IndexOf(Needs[K]) < 0 then
              TIntf.Add(Needs[K]);
        end;
        if Up and (TIntf.IndexOf(US.Name) >= 0) then
        begin
          Error := Format('The members name what %s declares: %s, which %s uses, would use it in its interface too',
            [US.Name, UT.Name, US.Name]);
          Exit;
        end;
        if not AddNeeds(R, CI, TFile, TIntf, TImpl, Error) then Exit;
      finally
        UT.Free;
      end;
    end;
    if Up then R.Title := Format('Pull %s up into %s', [Shown, Targets[0]])
    else R.Title := Format('Push %s down into %s', [Shown, Targets.CommaText]);
    Result := True;
  finally
    Others.Free;
    Needs.Free;
    TImpl.Free;
    TIntf.Free;
    Names.Free;
    FreeObjects(Uses_);
    Uses_.Free;
    FreeObjects(Places);
    Places.Free;
    L.Free;
    Chosen.Free;
    RT.Free;
    US.Free;
  end;
end;

function PlanPullUp(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string; Members: TList;
  Files: TStrings; const Target: string; out Error: string): Boolean;
var
  T: TStringList;
begin
  T := TStringList.Create;
  try
    T.Add(Target);
    Result := MoveMembers(R, CI, FileName, Source, ClassName, Members, Files, T, True, Error);
  finally
    T.Free;
  end;
end;

function PlanPushDown(R: TRefactoring; CI: TCodeInsight; const FileName, Source, ClassName: string; Members: TList;
  Files: TStrings; out Error: string): Boolean;
var
  T: TStringList;
begin
  T := TStringList.Create;
  try
    R.Descendants(CI, Files, ClassName, T);
    if T.Count = 0 then
    begin
      Error := Format('No class of the project derives from %s', [ClassName]);
      Result := False;
      Exit;
    end;
    Result := MoveMembers(R, CI, FileName, Source, ClassName, Members, Files, T, False, Error);
  finally
    T.Free;
  end;
end;

end.
