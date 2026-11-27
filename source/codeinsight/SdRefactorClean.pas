{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorClean;

{ D7 Studio - the refactorings that clean code up: Remove With (the names a with statement gives
  named through its expressions), Clean Uses (the units a unit does without out of its uses clauses,
  those only its implementation needs moved there), Safe Delete (a declaration nothing names taken
  out) and Const Parameters (the parameters a routine never changes made const). As SdRefactor's:
  edits of the texts code insight reads, shown before they are applied. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex, SdPasParser, SdCodeInsight, SdRefactor;

type
  { a parameter Const Parameters can make const }
  TRefConstParam = class
  public
    Routine: string;           // its routine as a list names it: TClass.Name
    Param: string;             // 'Name: Type'
    NameOfs: Integer;          // where its routine's implementation names it (an offset of the unit)
    Index: Integer;            // its place in the routine's parameters
    Checked: Boolean;
  end;

{ Remove With: the with statement at Pos taken away - each name its expressions give the statement
  named through them, through a new local variable an expression that is no plain designator }
function PlanRemoveWith(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;

{ Clean Uses: what the unit's uses clauses can do without - Items 'remove'#9'Unit' (out of its
  clause), 'move'#9'Unit' (out of the interface's into the implementation's) - and what stays for a
  reason (Kept: 'Unit: why'); Files - the projects, whose programs say whether a unit's start-up
  code would leave them }
function CleanUsesTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Files: TStrings;
  Items, Kept: TStrings; out Error: string): Boolean;
{ Items (as CleanUsesTarget gives them) made, Kept in the notes }
function PlanCleanUses(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Items, Kept: TStrings;
  out Error: string): Boolean;

{ Safe Delete: the declaration of the symbol at Pos taken out - with a routine's implementations, a
  class's methods - when nothing in Files names it; else False and where it is named in Used
  ('File(line): text') }
function PlanSafeDelete(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files, Used: TStrings; out Info: TCISymbolInfo; out Error: string): Boolean;

{ Const Parameters: the unit's parameters that can be const (TRefConstParam, the caller frees them) -
  of a string, record, array, Variant or interface type, never changed, of a routine that no event,
  procedural value, interface or ancestor outside Files needs as it is -, those of the routine at Pos
  checked (every one when Pos is in none) }
function ConstParamsTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; Params: TList; out Error: string): Boolean;
{ the checked Params made const in every heading of their routines }
function PlanConstParams(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Files: TStrings;
  Params: TList; out Error: string): Boolean;

implementation

uses
  SdFormSrc;

{ the line of Ofs in U's text (1-based) }
function LineOf(U: TUnitInfo; Ofs: Integer): Integer;
var
  Col: Integer;
begin
  Result := U.LineOfOffset(Ofs, Col);
end;

{ the lines that begin in LS .. LE moved Delta columns to the left - none when one of them that is
  not empty is indented less }
procedure DedentLines(R: TRefactoring; const FileName, Src: string; LS, LE, Delta: Integer);
var
  L, Pass: Integer;
begin
  if Delta <= 0 then Exit;
  for Pass := 0 to 1 do
  begin
    L := LS;
    while L < LE do
    begin
      if not IsBlank(Src, L, LineEndOf(Src, L)) then
        if Pass = 0 then
        begin
          if Length(IndentAt(Src, L)) < Delta then Exit;
        end
        else
          R.AddEdit(FileName, L, Delta, '');
      if NextLineStart(Src, L) <= L then Break;
      L := NextLineStart(Src, L);
    end;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Remove With }

{ a new local variable's name for a value of the type T: its name without the T of a type (one
  that Taken does not hold) }
function VarNameFor(const T: string; Taken: TStrings): string;
var
  Base: string;
  N: Integer;
begin
  Base := Copy(T, LastDelimiter('.', T) + 1, MaxInt);
  if (Length(Base) > 1) and (Base[1] in ['T', 'I']) and (Base[2] in ['A'..'Z']) then Delete(Base, 1, 1);
  if CheckNewName(Base) <> '' then Base := 'Item';
  Result := Base;
  N := 1;
  while Taken.IndexOf(Result) >= 0 do
  begin
    Inc(N);
    Result := Base + IntToStr(N);
  end;
end;

function PlanRemoveWith(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  Rou: TRoutineSym;
  W, D, First, Last, SE, K, I, J, N, Depth, Lo, Hi, A, B, BodyFirst, Delta, DedentEnd: Integer;
  Starts, Ends: array of Integer;
  Prefix: array of string;
  AllUses: TList;
  Taken, Assigns: TStringList;
  NU: TCINameUse;
  EOL, IndW, Text, T, VName, Shown: string;
  InList, Block, Plain, HeadLines: Boolean;

  { the text of the expression E, the names an earlier expression of the with gives it named
    through that one }
  function ExprText(E: Integer): string;
  var
    X, Y, Z: Integer;
    N2: TCINameUse;
  begin
    Result := '';
    Y := RT.T[Starts[E]].Start;
    for X := 0 to AllUses.Count - 1 do
    begin
      N2 := TCINameUse(AllUses[X]);
      if N2.Qualified or (N2.Start < RT.T[Starts[E]].Start) or (N2.Start >= RT.EndOf(Ends[E])) then Continue;
      for Z := 0 to E - 1 do
        if N2.WithStart = RT.T[Starts[Z]].Start then
        begin
          Result := Result + Copy(Source, Y + 1, N2.Start - Y) + Prefix[Z];
          Y := N2.Start;
        end;
    end;
    Result := Result + Copy(Source, Y + 1, RT.EndOf(Ends[E]) - Y);
  end;

begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  AllUses := TList.Create;
  Taken := TStringList.Create;
  Assigns := TStringList.Create;
  try
    { the with around Pos: going back, the first one whose statement holds it }
    W := -1;
    First := -1;
    Last := -1;
    K := RT.FirstAt(Pos);
    if K >= RT.N then K := RT.N - 1;
    while (K > 0) and (W < 0) do
    begin
      if RT.IsKw(K, kwWith) and InStatements(U, RT.T[K].Start) then
      begin
        D := K + 1;
        Depth := 0;
        while (D < RT.N) and not ((Depth = 0) and (RT.IsKw(D, kwDo) or RT.IsSy(D, sySemicolon))) do
        begin
          if RT.IsSy(D, syLParen) or RT.IsSy(D, syLBracket) then Inc(Depth)
          else if RT.IsSy(D, syRParen) or RT.IsSy(D, syRBracket) then Dec(Depth);
          Inc(D);
        end;
        if RT.IsKw(D, kwDo) and (D + 1 < RT.N) then
        begin
          SE := StatementEnd(RT, D + 1);
          if (SE > D + 1) and (Pos <= RT.EndOf(SE - 1)) then
          begin
            W := K;
            First := D + 1;
            Last := SE - 1;
          end;
        end;
      end;
      Dec(K);
    end;
    if W < 0 then
    begin
      Error := 'Put the caret in a with statement';
      Exit;
    end;
    { its expressions }
    N := 0;
    K := W + 1;
    Depth := 0;
    for J := W + 1 to First - 1 do
      if (J = First - 1) or ((Depth = 0) and RT.IsSy(J, syComma)) then
      begin
        if J = K then
        begin
          Error := 'The with statement has an empty expression';
          Exit;
        end;
        SetLength(Starts, N + 1);
        SetLength(Ends, N + 1);
        Starts[N] := K;
        Ends[N] := J - 1;
        Inc(N);
        K := J + 1;
      end
      else if RT.IsSy(J, syLParen) or RT.IsSy(J, syLBracket) then Inc(Depth)
      else if RT.IsSy(J, syRParen) or RT.IsSy(J, syRBracket) then Dec(Depth);
    SetLength(Prefix, N);
    Shown := Trim(Copy(Source, RT.T[W + 1].Start + 1, RT.EndOf(First - 2) - RT.T[W + 1].Start));
    { every one a structured type whose members are all known: else a name of the statement might
      be one of them unseen }
    for J := 0 to N - 1 do
      if not CI.ExprMembersKnown(FileName, Source, RT.T[Starts[J]].Start, RT.EndOf(Ends[J])) then
      begin
        Error := Format('What %s gives the statement is not known: code insight does not find its type, or an ancestor of it',
          [Trim(Copy(Source, RT.T[Starts[J]].Start + 1, RT.EndOf(Ends[J]) - RT.T[Starts[J]].Start))]);
        Exit;
      end;
    { the names of the routine, as code insight resolves them; those it declares are taken }
    Rou := BodyAround(U, RT.T[W].Start, RT.T[W].Start);
    if Rou <> nil then
    begin
      Lo := Rou.BodyStart;
      Hi := Rou.BodyEnd;
      if Rou.Locals <> nil then
        for I := 0 to Rou.Locals.Count - 1 do Taken.Add(Rou.Locals[I].Name);
      EnsureParams(Rou);
      if Rou.Params <> nil then
        for I := 0 to Rou.Params.Count - 1 do Taken.Add(TSymbol(Rou.Params[I]).Name);
    end
    else
    begin
      Lo := RT.T[W].Start;
      Hi := RT.EndOf(Last);
    end;
    if not CI.NameUses(FileName, Source, Lo, Hi, AllUses) then
    begin
      Error := 'Code insight could not read the statements';
      Exit;
    end;
    for I := 0 to AllUses.Count - 1 do
    begin
      NU := TCINameUse(AllUses[I]);
      Taken.Add(NU.Name);
      if not NU.Qualified and (NU.Kind = ckUnknown) and (NU.Start >= RT.EndOf(Ends[0])) and (NU.Start < RT.EndOf(Last)) then
      begin
        Error := Format('Line %d: code insight does not know %s, so whether the with gives it cannot be told',
          [LineOf(U, NU.Start), NU.Name]);
        Exit;
      end;
    end;
    { what names each expression's members: the expression itself when it is a plain designator,
      else a new local variable given its value first }
    for J := 0 to N - 1 do
    begin
      Plain := True;
      for K := Starts[J] to Ends[J] do
        if not ((RT.T[K].Kind = tkIdent) or RT.IsSy(K, syDot) or RT.IsSy(K, syCaret)) then Plain := False;
      for I := 0 to AllUses.Count - 1 do
      begin
        NU := TCINameUse(AllUses[I]);
        if (NU.Start >= RT.T[Starts[J]].Start) and (NU.Start < RT.EndOf(Ends[J])) and
          (IsRoutineKind(NU.Kind) or (NU.Kind = ckUnknown)) then
          Plain := False;
      end;
      if Plain then
      begin
        Prefix[J] := ExprText(J) + '.';
        Continue;
      end;
      Text := Trim(Copy(Source, RT.T[Starts[J]].Start + 1, RT.EndOf(Ends[J]) - RT.T[Starts[J]].Start));
      if Rou = nil then
      begin
        Error := Format('%s needs a variable, which a with statement outside a routine cannot have', [Text]);
        Exit;
      end;
      T := CI.ExprTypeName(FileName, Source, RT.T[Starts[J]].Start, RT.EndOf(Ends[J]));
      if T = '' then
      begin
        Error := Format('The type of %s is not known: it needs a variable', [Text]);
        Exit;
      end;
      VName := VarNameFor(T, Taken);
      Taken.Add(VName);
      if not AddLocalDecl(R, FileName, Source, RT, Rou, kwVar, VName + ': ' + T + ';') then
      begin
        Error := 'Could not find where to declare the variable';
        Exit;
      end;
      Assigns.Add(VName + ' := ' + ExprText(J) + ';');
      Prefix[J] := VName + '.';
    end;
    { the names the with gives the statement, named through their expression }
    for I := 0 to AllUses.Count - 1 do
    begin
      NU := TCINameUse(AllUses[I]);
      if NU.Qualified or (NU.WithStart < 0) or (NU.Start < RT.T[First].Start) or (NU.Start >= RT.EndOf(Last)) then Continue;
      for J := 0 to N - 1 do
        if NU.WithStart = RT.T[Starts[J]].Start then R.AddEdit(FileName, NU.Start, 0, Prefix[J]);
    end;
    { the with itself: a block of a statement list gives its statements the with's place, a
      statement of its own takes it, the variables' values come first }
    IndW := IndentAt(Source, RT.T[W].Start);
    InList := RT.IsSy(W - 1, sySemicolon) or ((RT.T[W - 1].Kind = tkKeyword) and
      (RT.T[W - 1].Keyword in [kwBegin, kwTry, kwFinally, kwExcept, kwRepeat]));
    Block := RT.IsKw(First, kwBegin) and (BlockEnd(RT, First) = Last);
    if Block and (First + 1 = Last) then
    begin
      { an empty block: the statement goes, the values stay }
      A := RT.T[W].Start;
      if RT.IsSy(Last + 1, sySemicolon) and InList then B := RT.EndOf(Last + 1) else B := RT.EndOf(Last);
      Text := '';
      for I := 0 to Assigns.Count - 1 do Text := Text + Assigns[I] + ' ';
      if not InList and (Text <> '') then Text := 'begin ' + Text + 'end';
      R.AddEdit(FileName, A, B - A, TrimRight(Text));
    end
    else if Block and not InList then
    begin
      { the block stays the one statement: the header goes, the values go first into it }
      A := RT.T[W].Start;
      B := RT.T[First].Start;
      R.AddEdit(FileName, A, B - A, '');
      if Assigns.Count > 0 then
      begin
        if FirstOnLine(Source, RT.T[First + 1].Start) and LastOnLine(Source, RT.EndOf(First)) then
        begin
          Text := '';
          for I := 0 to Assigns.Count - 1 do Text := Text + IndentAt(Source, RT.T[First + 1].Start) + Assigns[I] + EOL;
          R.AddEdit(FileName, LineStartOf(Source, RT.T[First + 1].Start), 0, Text);
        end
        else
        begin
          Text := '';
          for I := 0 to Assigns.Count - 1 do Text := Text + ' ' + Assigns[I];
          R.AddEdit(FileName, RT.EndOf(First), 0, Text);
        end;
      end;
    end
    else
    begin
      { the with's statement - a block's statements in a list - in the with's place }
      if Block then BodyFirst := First + 1 else BodyFirst := First;
      if Block then DedentEnd := LineStartOf(Source, RT.T[Last].Start)
      else DedentEnd := NextLineStart(Source, RT.EndOf(Last));
      HeadLines := FirstOnLine(Source, RT.T[W].Start) and LastOnLine(Source, RT.EndOf(BodyFirst - 1)) and
        (LineStartOf(Source, RT.T[BodyFirst].Start) > LineStartOf(Source, RT.T[W].Start));
      if HeadLines then
      begin
        A := LineStartOf(Source, RT.T[W].Start);
        B := NextLineStart(Source, RT.EndOf(BodyFirst - 1));
        Text := '';
        for I := 0 to Assigns.Count - 1 do Text := Text + IndW + Assigns[I] + EOL;
        if not InList and (Assigns.Count > 0) then Text := IndW + 'begin' + EOL + Text;
        R.AddEdit(FileName, A, B - A, Text);
        Delta := Length(IndentAt(Source, RT.T[BodyFirst].Start)) - Length(IndW);
        if not InList and (Assigns.Count > 0) then Dec(Delta, 2);
        DedentLines(R, FileName, Source, B, DedentEnd, Delta);
      end
      else
      begin
        A := RT.T[W].Start;
        B := RT.T[BodyFirst].Start;
        Text := '';
        for I := 0 to Assigns.Count - 1 do Text := Text + Assigns[I] + ' ';
        if not InList and (Assigns.Count > 0) then Text := 'begin ' + Text;
        R.AddEdit(FileName, A, B - A, Text);
      end;
      if not InList and (Assigns.Count > 0) then
      begin
        if HeadLines then R.AddEdit(FileName, RT.EndOf(Last), 0, EOL + IndW + 'end')
        else R.AddEdit(FileName, RT.EndOf(Last), 0, ' end');
      end;
      if Block then
      begin
        { the block's end: with the ";" after it, that the last statement takes over }
        K := Last - 1;
        if RT.IsSy(K, sySemicolon) and RT.IsSy(Last + 1, sySemicolon) then B := RT.EndOf(Last + 1)
        else B := RT.EndOf(Last);
        R.AddEdit(FileName, RT.EndOf(K), B - RT.EndOf(K), '');
      end;
    end;
    R.Title := Format('Remove with %s', [Shown]);
    Result := True;
  finally
    Assigns.Free;
    Taken.Free;
    FreeObjects(AllUses);
    AllUses.Free;
    U.Free;
    RT.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Clean Uses }

type
  { a unit of the programs' uses graph }
  TUsesNode = class
  public
    Name, FileName: string;
    UsesList: TStringList;     // the units its uses clauses name (a project's: its units)
    Effects: Integer;          // -1 not looked at; 0 none; 1 start-up code or a resource it links, or no source to tell
    Walk: Integer;             // the walk that reached it last
    constructor Create;
    destructor Destroy; override;
  end;

  TUsesGraph = class
  private
    FCI: TCodeInsight;
    FNodes: TStringList;
    FWalk: Integer;
  public
    constructor Create(CI: TCodeInsight);
    destructor Destroy; override;
    { the unit Name as FromFile finds it (its uses read once) }
    function Node(const Name, FromFile: string): TUsesNode;
    { a project's file: its units }
    function ProjectNode(const FileName: string): TUsesNode;
    { the units Roots reach, not through SkipFrom's use of SkipTo, in Reached; the walk's number }
    function Reach(Roots: TList; SkipFrom, SkipTo: TUsesNode; Reached: TList): Integer;
    { what N does when a program starts or is linked: an initialization or finalization part, a main
      block, a resource it links; True too when it has no source to tell }
    function HasEffects(N: TUsesNode): Boolean;
  end;

constructor TUsesNode.Create;
begin
  inherited Create;
  UsesList := TStringList.Create;
  Effects := -1;
end;

destructor TUsesNode.Destroy;
begin
  UsesList.Free;
  inherited Destroy;
end;

constructor TUsesGraph.Create(CI: TCodeInsight);
begin
  inherited Create;
  FCI := CI;
  FNodes := TStringList.Create;
  FNodes.Sorted := True;
end;

destructor TUsesGraph.Destroy;
var
  I: Integer;
begin
  for I := 0 to FNodes.Count - 1 do FNodes.Objects[I].Free;
  FNodes.Free;
  inherited Destroy;
end;

function TUsesGraph.Node(const Name, FromFile: string): TUsesNode;
var
  I: Integer;
  F, Text: string;
begin
  if FNodes.Find(Name, I) then
  begin
    Result := TUsesNode(FNodes.Objects[I]);
    Exit;
  end;
  Result := TUsesNode.Create;
  Result.Name := Name;
  FNodes.AddObject(Name, Result);
  F := FCI.FindUnitFile(Name, FromFile);
  if (F <> '') and SameText(ExtractFileExt(F), '.pas') and FCI.ReadText(F, Text) then
  begin
    Result.FileName := F;
    UsesClauseNames(Text, Result.UsesList);
  end;
end;

function TUsesGraph.ProjectNode(const FileName: string): TUsesNode;
var
  I: Integer;
  Text: string;
  Paths, Forms: TStringList;
begin
  if FNodes.Find('<' + FileName, I) then
  begin
    Result := TUsesNode(FNodes.Objects[I]);
    Exit;
  end;
  Result := TUsesNode.Create;
  Result.Name := '<' + FileName;
  Result.FileName := FileName;
  Result.Effects := 0;
  FNodes.AddObject(Result.Name, Result);
  if not FCI.ReadText(FileName, Text) then Exit;
  Paths := TStringList.Create;
  Forms := TStringList.Create;
  try
    DprGetUnits(Text, Result.UsesList, Paths, Forms);
  finally
    Forms.Free;
    Paths.Free;
  end;
end;

function TUsesGraph.Reach(Roots: TList; SkipFrom, SkipTo: TUsesNode; Reached: TList): Integer;
var
  Stack: TList;
  N, M: TUsesNode;
  I: Integer;
begin
  Inc(FWalk);
  Result := FWalk;
  Reached.Clear;
  Stack := TList.Create;
  try
    for I := 0 to Roots.Count - 1 do
    begin
      N := TUsesNode(Roots[I]);
      if N.Walk = FWalk then Continue;
      N.Walk := FWalk;
      Reached.Add(N);
      Stack.Add(N);
    end;
    while Stack.Count > 0 do
    begin
      N := TUsesNode(Stack[Stack.Count - 1]);
      Stack.Delete(Stack.Count - 1);
      for I := 0 to N.UsesList.Count - 1 do
      begin
        M := Node(N.UsesList[I], N.FileName);
        if (M.Walk = FWalk) or ((N = SkipFrom) and (M = SkipTo)) then Continue;
        M.Walk := FWalk;
        Reached.Add(M);
        Stack.Add(M);
      end;
    end;
  finally
    Stack.Free;
  end;
end;

function TUsesGraph.HasEffects(N: TUsesNode): Boolean;
var
  Text, T: string;
  L: TPasLexer;
  U: TUnitInfo;
begin
  if N.Effects < 0 then
  begin
    N.Effects := 1;
    if (N.FileName <> '') and FCI.ReadText(N.FileName, Text) then
    begin
      U := TUnitInfo.Create;
      try
        ParseSource(U, Text, False, FCI.Defines, nil);
        if (U.InitOfs = 0) and (U.FinalOfs = 0) and (U.MainBegin = 0) then N.Effects := 0;
      finally
        U.Free;
      end;
      { a resource it links: $R and a file's name (not the switch $R+ / $R-) }
      if N.Effects = 0 then
      begin
        L := TPasLexer.Create(Text);
        try
          L.ProcessDirectives := False;
          L.ReturnComments := True;
          L.Next;
          while (L.Tok.Kind <> tkEOF) and (N.Effects = 0) do
          begin
            if (L.Tok.Kind = tkComment) and (L.Tok.PLen > 4) and (L.Tok.Ptr[0] = '{') and (L.Tok.Ptr[1] = '$') then
            begin
              SetString(T, L.Tok.Ptr, L.Tok.PLen);
              T := UpperCase(T);
              if (Copy(T, 1, 4) = '{$R ') or (Copy(T, 1, 11) = '{$RESOURCE ') then N.Effects := 1;
            end;
            L.Next;
          end;
        finally
          L.Free;
        end;
      end;
    end;
  end;
  Result := N.Effects = 1;
end;

function CleanUsesTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Files: TStrings;
  Items, Kept: TStrings; out Error: string): Boolean;
var
  U: TUnitInfo;
  Names, Roots, Base, Without, Hits: TList;
  Units, UnitFiles, FileIdx, Pending, Candidates: TStringList;
  UsedIntf, UsedImpl: array of Boolean;
  NU: TCINameUse;
  I, J, K: Integer;
  InIntf: Boolean;
  KF, LastKey, Why: string;
  Graph: TUsesGraph;
  Me, C, X: TUsesNode;

  procedure Mark(J: Integer);
  begin
    if InIntf then UsedIntf[J] := True else UsedImpl[J] := True;
  end;

  { a name whose declaring units count as used - a routine (its overloads), a name code insight does
    not know -: Pending, with where it is named (1 the interface, 2 the implementation) }
  procedure Lookup(const Name: string);
  var
    Q, Flag: Integer;
  begin
    if InIntf then Flag := 1 else Flag := 2;
    if Pending.Find(Name, Q) then Pending.Objects[Q] := TObject(Integer(Pending.Objects[Q]) or Flag)
    else Pending.AddObject(Name, TObject(Flag));
  end;

  function InClause(Ofs: Integer): Boolean;
  begin
    Result := ((U.IntfUsesEnd > 0) and (Ofs >= U.IntfUsesStart) and (Ofs <= U.IntfUsesEnd)) or
      ((U.ImplUsesEnd > 0) and (Ofs >= U.ImplUsesStart) and (Ofs <= U.ImplUsesEnd));
  end;

begin
  Result := False;
  Error := '';
  Items.Clear;
  Kept.Clear;
  R.SetSource(FileName, Source);
  U := ParseText(CI, FileName, Source);
  Names := TList.Create;
  Units := TStringList.Create;
  UnitFiles := TStringList.Create;
  FileIdx := TStringList.Create;
  Pending := TStringList.Create;
  Hits := TList.Create;
  Candidates := TStringList.Create;
  Graph := nil;
  Roots := TList.Create;
  Base := TList.Create;
  Without := TList.Create;
  try
    if U.IsProgram then
    begin
      Error := 'Clean Uses works on a unit: a program''s or a package''s clause lists its units';
      Exit;
    end;
    { the units of the clauses: the interface's (object 0), the implementation's (1) }
    for I := 0 to U.IntfUses.Count - 1 do Units.AddObject(U.IntfUses[I], nil);
    for I := 0 to U.ImplUses.Count - 1 do Units.AddObject(U.ImplUses[I], Pointer(1));
    if Units.Count = 0 then
    begin
      Error := Format('%s uses no unit', [U.Name]);
      Exit;
    end;
    SetLength(UsedIntf, Units.Count);
    SetLength(UsedImpl, Units.Count);
    for I := 0 to Units.Count - 1 do
    begin
      UsedIntf[I] := False;
      UsedImpl[I] := False;
      UnitFiles.Add(CI.FindUnitFile(Units[I], FileName));
    end;
    { what the unit's names name: a unit's declaration, a unit itself; a name code insight does not
      know, and a routine (its overloads), any unit that declares one of its name }
    if not CI.NameUses(FileName, Source, 0, Length(Source), Names) then
    begin
      Error := 'Code insight could not read the unit';
      Exit;
    end;
    FileIdx.Sorted := True;
    FileIdx.Duplicates := dupAccept;
    for I := 0 to UnitFiles.Count - 1 do
      if UnitFiles[I] <> '' then FileIdx.AddObject(ExpandFileName(UnitFiles[I]), TObject(I));
    Pending.Sorted := True;
    for I := 0 to Names.Count - 1 do
    begin
      NU := TCINameUse(Names[I]);
      if NU.Qualified or InClause(NU.Start) then Continue;
      InIntf := NU.Start < U.ImplOfs;
      if NU.Kind = ckUnit then
      begin
        J := Units.IndexOf(NU.Name);
        if J >= 0 then Mark(J);
      end
      else if (NU.Key <> '') and (NU.Key <> 'RESULT') and (NU.Key <> 'SELF') then
      begin
        { the unit of its declaration (the names of a file come one after another: its full name once) }
        if KeyFile(NU.Key) <> LastKey then
        begin
          LastKey := KeyFile(NU.Key);
          KF := ExpandFileName(LastKey);
        end;
        if FileIdx.Find(KF, J) then
          while (J < FileIdx.Count) and SameText(FileIdx[J], KF) do
          begin
            Mark(Integer(FileIdx.Objects[J]));
            Inc(J);
          end;
        if IsRoutineKind(NU.Kind) then Lookup(NU.Name);
      end
      else if NU.Kind = ckUnknown then
        Lookup(NU.Name);
    end;
    { the units that declare such a name, asked once for all the names; a unit whose source is not
      there to tell counts as one }
    if Pending.Count > 0 then
    begin
      CI.UnitsDeclare(FileName, Units, Pending, Hits);
      for J := 0 to Units.Count - 1 do
        for K := 0 to Pending.Count - 1 do
          if (Hits[J] = nil) or TBits(Hits[J]).Bits[K] then
          begin
            if Integer(Pending.Objects[K]) and 1 <> 0 then UsedIntf[J] := True;
            if Integer(Pending.Objects[K]) and 2 <> 0 then UsedImpl[J] := True;
          end;
    end;
    { what each unit is to the unit }
    for J := 0 to Units.Count - 1 do
    begin
      if UsedIntf[J] or ((Units.Objects[J] <> nil) and UsedImpl[J]) then Continue;
      if (UnitFiles[J] = '') or not SameText(ExtractFileExt(UnitFiles[J]), '.pas') then
      begin
        Kept.Add(Units[J] + ': its source is not found, so what it declares is not known');
        Continue;
      end;
      if UsedImpl[J] then Items.Add('move'#9 + Units[J])
      else Candidates.Add(Units[J]);
    end;
    { a unit that goes must not take start-up code out of a program with it: what the projects reach
      without it (the unit alone's when no project reaches it) }
    if Candidates.Count > 0 then
    begin
      Graph := TUsesGraph.Create(CI);
      for I := 0 to Files.Count - 1 do
        if SameText(ExtractFileExt(Files[I]), '.dpr') or SameText(ExtractFileExt(Files[I]), '.dpk') then
          Roots.Add(Graph.ProjectNode(Files[I]));
      Me := Graph.Node(U.Name, FileName);
      K := Graph.Reach(Roots, nil, nil, Base);
      if Me.Walk <> K then
      begin
        Roots.Clear;
        Roots.Add(Me);
        Graph.Reach(Roots, nil, nil, Base);
      end;
      for I := 0 to Candidates.Count - 1 do
      begin
        C := Graph.Node(Candidates[I], FileName);
        K := Graph.Reach(Roots, Me, C, Without);
        Why := '';
        for J := 0 to Base.Count - 1 do
        begin
          X := TUsesNode(Base[J]);
          if (X.Walk = K) or not Graph.HasEffects(X) then Continue;
          if X = C then Why := 'its start-up code or a resource it links would leave the program'
          else Why := Format('%s, which only it brings into the program, has start-up code or a resource', [X.Name]);
          Break;
        end;
        if Why <> '' then Kept.Add(Candidates[I] + ': ' + Why)
        else Items.Add('remove'#9 + Candidates[I]);
      end;
    end;
    if Items.Count = 0 then
    begin
      if Kept.Count > 0 then Error := Format('%s needs every unit it uses, or keeps them for a reason: %s', [U.Name, Kept[0]])
      else Error := Format('%s needs every unit it uses where it uses it', [U.Name]);
      Exit;
    end;
    Result := True;
  finally
    Graph.Free;
    Without.Free;
    Base.Free;
    Roots.Free;
    Candidates.Free;
    FreeObjects(Hits);
    Hits.Free;
    Pending.Free;
    FileIdx.Free;
    UnitFiles.Free;
    Units.Free;
    FreeObjects(Names);
    Names.Free;
    U.Free;
  end;
end;

function PlanCleanUses(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Items, Kept: TStrings;
  out Error: string): Boolean;
var
  U: TUnitInfo;
  RT: TRawToks;
  FromIntf, FromImpl, Moved, Ranges: TList;
  RemIntf, RemImpl, MoveNames: TStringList;
  I, P, K: Integer;
  Kind, Name, EOL: string;

  function Remove(Names: TStrings; UsesOfs: Integer; const Part: string): Boolean;
  var
    Q: Integer;
  begin
    Result := True;
    if Names.Count = 0 then Exit;
    Result := UsesRemoveRanges(Source, UsesOfs, Names, Ranges);
    if not Result then
    begin
      Error := Format('The uses clause of the %s has compiler directives between its units: clean it by hand', [Part]);
      Exit;
    end;
    Q := 0;
    while Q + 1 < Ranges.Count do
    begin
      R.AddEdit(FileName, Integer(Ranges[Q]), Integer(Ranges[Q + 1]) - Integer(Ranges[Q]), '');
      Inc(Q, 2);
    end;
  end;

begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  U := ParseText(CI, FileName, Source);
  RT := TRawToks.Create(Source, False);
  RemIntf := TStringList.Create;
  RemImpl := TStringList.Create;
  MoveNames := TStringList.Create;
  Ranges := TList.Create;
  FromIntf := nil;
  FromImpl := nil;
  Moved := nil;
  try
    for I := 0 to Items.Count - 1 do
    begin
      P := System.Pos(#9, Items[I]);
      Kind := Copy(Items[I], 1, P - 1);
      Name := Copy(Items[I], P + 1, MaxInt);
      if Kind = 'move' then
      begin
        RemIntf.Add(Name);
        MoveNames.Add(Name);
      end
      else if U.IntfUses.IndexOf(Name) >= 0 then RemIntf.Add(Name)
      else RemImpl.Add(Name);
    end;
    if not Remove(RemIntf, U.IntfUsesStart, 'interface') then Exit;
    if (MoveNames.Count > 0) and (RemImpl.Count > 0) and (RemImpl.Count = U.ImplUses.Count) then
    begin
      { every unit of the implementation's clause goes and others come: they take its units' place }
      K := RT.IndexAt(U.ImplUsesStart);
      if K < 0 then
      begin
        Error := 'Could not read the uses clause of the implementation';
        Exit;
      end;
      Name := '';
      for I := 0 to MoveNames.Count - 1 do
      begin
        if I > 0 then Name := Name + ', ';
        Name := Name + MoveNames[I];
      end;
      R.AddEdit(FileName, RT.EndOf(K), U.ImplUsesEnd - RT.EndOf(K), EOL + '  ' + Name);
    end
    else
    begin
      if not Remove(RemImpl, U.ImplUsesStart, 'implementation') then Exit;
      if (MoveNames.Count > 0) and not AddUsesNames(R, FileName, Source, RT, U, MoveNames, True) then
      begin
        Error := 'Could not add to the uses clause of the implementation';
        Exit;
      end;
    end;
    for I := 0 to Kept.Count - 1 do
      R.Notes.Add(Copy(Kept[I], 1, System.Pos(':', Kept[I]) - 1) + ' stays:' + Copy(Kept[I], System.Pos(':', Kept[I]) + 1, MaxInt) + '.');
    if MoveNames.Count > 0 then
      R.Notes.Add('A unit moved to the implementation may be initialized at another time of the start-up.');
    R.Title := Format('Clean the uses clauses of %s', [U.Name]);
    Result := True;
  finally
    FromIntf.Free;
    FromImpl.Free;
    Moved.Free;
    Ranges.Free;
    MoveNames.Free;
    RemImpl.Free;
    RemIntf.Free;
    RT.Free;
    U.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Safe Delete }

type
  { a part of a file's text that goes }
  TDelRange = class
  public
    FileName: string;
    A, B: Integer;
  end;

function PlanSafeDelete(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files, Used: TStrings; out Info: TCISymbolInfo; out Error: string): Boolean;
var
  Places, Dels, Items, L: TList;
  P: TCIPlace;
  Src, Cls, What: string;
  U: TUnitInfo;
  RT: TRawToks;
  S: TSymbol;
  Rou: TRoutineSym;
  I, J, K, A, DeclOfs: Integer;
  Own, Inside: Boolean;
  Cache: TStringList;

  procedure AddRange(const F: string; RA, RB: Integer);
  var
    X: TDelRange;
  begin
    X := TDelRange.Create;
    X.FileName := F;
    X.A := RA;
    X.B := RB;
    Dels.Add(X);
  end;

  { whole lines RA .. RB go: with an empty line after them when one is before them too }
  procedure AddLines(const F, Text: string; RA, RB: Integer);
  begin
    AddRange(F, RA, BlankAfter(Text, RA, RB));
  end;

  { the declaration RA .. RB goes: its lines and the comment above them when nothing else stands on them }
  procedure AddBlock(const F, Text: string; RA, RB: Integer);
  begin
    if WholeLines(Text, RA, RB) then AddLines(F, Text, CommentStart(Text, RA), RB)
    else AddRange(F, RA, RB);
  end;

  { an implementation goes }
  procedure AddBody(const F, Text: string; X: TRawToks; RS: TRoutineSym);
  var
    RA, RB: Integer;
  begin
    BodyRange(Text, X, RS, RA, RB);
    AddLines(F, Text, RA, RB);
  end;

  function Loaded(const F: string): TUnitInfo;
  var
    X: Integer;
  begin
    X := Cache.IndexOf(F);
    if X < 0 then X := Cache.AddObject(F, ParseText(CI, F, R.Source(F)));
    Result := TUnitInfo(Cache.Objects[X]);
  end;

begin
  Result := False;
  Error := '';
  Used.Clear;
  R.SetSource(FileName, Source);
  Places := TList.Create;
  Dels := TList.Create;
  Items := TList.Create;
  L := TList.Create;
  Cache := TStringList.Create;
  RT := nil;
  try
    if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) then
    begin
      Error := 'Put the caret on a name that code insight knows';
      Exit;
    end;
    What := SymbolTitle(Info);
    case Info.Kind of
      ckUnit: Error := 'A unit is not deleted here: remove it from the project';
      ckParam: Error := 'A parameter goes with Change Parameters';
      ckEnumValue: Error := 'A value of an enumeration does not go alone: the values after it would change';
      ckLabel, ckKeyword, ckTemplate, ckUnknown: Error := Format('%s cannot be deleted', [Info.Name]);
    end;
    if Error <> '' then Exit;
    if (Info.FileName = '') or not InList(Files, Info.FileName) then
    begin
      Error := Format('%s is not declared in the project', [What]);
      Exit;
    end;
    if Info.Overloaded then
    begin
      Error := Format('%s is overloaded: delete an overload by hand', [What]);
      Exit;
    end;
    if Info.Outside <> '' then
    begin
      Error := Format('%s overrides %s, which is not part of the project: its code may call it', [What, Info.Outside]);
      Exit;
    end;
    Src := R.Source(Info.FileName);
    U := Loaded(Info.FileName);
    RT := TRawToks.Create(Src, False);
    { the declaration }
    DeclOfs := -1;
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl and SameText(P.FileName, Info.FileName) and ((DeclOfs < 0) or (P.Start < DeclOfs)) then DeclOfs := P.Start;
    end;
    S := nil;
    if DeclOfs >= 0 then S := SymbolAt(U, DeclOfs);
    if (S = nil) and IsRoutineKind(Info.Kind) and (DeclOfs >= 0) then S := RoutineNamedAt(U, DeclOfs);
    if S = nil then
    begin
      Error := Format('The declaration of %s is not found', [What]);
      Exit;
    end;
    { what goes: by its kind }
    if IsRoutineKind(Info.Kind) then
    begin
      { the routine's declarations and implementations - of its class alone in a hierarchy, whose
        overrides would have nothing to override if it introduces the method }
      for I := 0 to Places.Count - 1 do
      begin
        P := TCIPlace(Places[I]);
        if not P.Decl then Continue;
        U := Loaded(P.FileName);
        Rou := RoutineNamedAt(U, P.Start);
        if Rou = nil then Continue;
        Cls := Rou.ClassQual;
        if (Cls = '') and (Rou.Owner is TTypeDesc) and (TTypeDesc(Rou.Owner).Sym <> nil) then
          Cls := TTypeDesc(Rou.Owner).Sym.Name;
        Own := SameText(Cls, Info.Owner);
        if not Own then
        begin
          if not (sfOverride in S.Flags) then
          begin
            Error := Format('%s.%s overrides it', [Cls, Rou.Name]);
            Exit;
          end;
          Continue;
        end;
        RT.Free;
        RT := TRawToks.Create(R.Source(P.FileName), False);
        if sfImplBody in Rou.Flags then AddBody(P.FileName, R.Source(P.FileName), RT, Rou)
        else AddBlock(P.FileName, R.Source(P.FileName), Rou.HeadStart, Rou.FullEnd);
      end;
      RT.Free;
      RT := TRawToks.Create(Src, False);
      U := Loaded(Info.FileName);
      { a method that implements an interface's: the interface needs it }
      if Info.OwnerIsClass then
      begin
        J := U.FindTypeSym(Info.Owner, [tyClass]).DeclStart;
        if CI.ClassMethods(Info.FileName, Src, J, True, Cls, Items) then
          for I := 0 to Items.Count - 1 do
            if TCIMethodItem(Items[I]).FromInterface and SameText(TCIMethodItem(Items[I]).Name, Info.Name) then
            begin
              Error := Format('%s implements %s.%s', [What, TCIMethodItem(Items[I]).Owner, Info.Name]);
              Exit;
            end;
      end;
    end
    else if Info.Kind = ckProperty then
    begin
      K := RT.FirstAt(S.DeclStart) - 1;
      while (K > 0) and not RT.IsKw(K, kwProperty) do Dec(K);
      if K <= 0 then
      begin
        Error := Format('The declaration of %s is not found', [What]);
        Exit;
      end;
      AddBlock(Info.FileName, Src, RT.T[K].Start, S.FullEnd);
    end
    else if (Info.Kind = ckClass) and (S.TypeDesc <> nil) then
    begin
      { the class, its forward declarations, the bodies of its methods and the comment that marks them }
      AddBlock(Info.FileName, Src, S.DeclStart, S.FullEnd);
      for K := 0 to RT.N - 4 do
        if RT.IsId(K, Info.Name) and (RT.T[K].Start <> S.DeclStart) and RT.IsSy(K + 1, syEqual) and
          RT.IsKw(K + 2, kwClass) and RT.IsSy(K + 3, sySemicolon) then
          AddBlock(Info.FileName, Src, RT.T[K].Start, RT.EndOf(K + 3));
      U.GetImpls(L, Info.Name, '');
      A := MaxInt;
      for I := 0 to L.Count - 1 do
      begin
        AddBody(Info.FileName, Src, RT, TRoutineSym(L[I]));
        if TRoutineSym(L[I]).HeadStart < A then A := TRoutineSym(L[I]).HeadStart;
      end;
      if A < MaxInt then
      begin
        K := MarkerAbove(Src, Info.Name, A);
        if K >= 0 then AddRange(Info.FileName, K, NextLineStart(Src, K));
      end;
    end
    else
    begin
      { a field, a variable, a constant, a type: its declaration (a name of a list alone) }
      J := Dels.Count;
      if not RemoveDecl(R, Info.FileName, Src, RT, S.DeclStart, -1, True) then
      begin
        Error := Format('Could not take the declaration of %s out', [What]);
        Exit;
      end;
      AddRange(Info.FileName, S.DeclStart, S.FullEnd);
      { the range is a filter of the uses only: RemoveDecl made the change }
      TDelRange(Dels[J]).FileName := '*' + Info.FileName;
    end;
    { what still names it: the places outside what goes }
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl then Continue;
      Inside := False;
      for J := 0 to Dels.Count - 1 do
        with TDelRange(Dels[J]) do
          if (SameText(FileName, P.FileName) or SameText(FileName, '*' + P.FileName)) and (P.Start >= A) and
            (P.Start < B) then Inside := True;
      if not Inside then Used.Add(Format('%s(%d): %s', [ExtractFileName(P.FileName), P.Line, P.LineText]));
    end;
    if Used.Count > 0 then
    begin
      if Used.Count = 1 then Error := Format('%s is still used: %s', [What, Used[0]])
      else Error := Format('%s is still used, %d times: %s ...', [What, Used.Count, Used[0]]);
      Exit;
    end;
    for J := 0 to Dels.Count - 1 do
      with TDelRange(Dels[J]) do
        if Copy(FileName, 1, 1) <> '*' then
          if R.AddEdit(FileName, A, B - A, '') = nil then
          begin
            Error := Format('%s: the parts to delete overlap', [ExtractFileName(FileName)]);
            Exit;
          end;
    R.Title := Format('Safe delete %s', [What]);
    Result := True;
  finally
    RT.Free;
    for I := 0 to Cache.Count - 1 do Cache.Objects[I].Free;
    Cache.Free;
    L.Free;
    FreeObjects(Items);
    Items.Free;
    FreeObjects(Dels);
    Dels.Free;
    FreeObjects(Places);
    Places.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Const Parameters }

{ the routines of U with a body: those of the unit and those nested in them }
procedure BodiesOf(U: TUnitInfo; List: TList);

  procedure Nested(R: TRoutineSym);
  var
    I: Integer;
    S: TSymbol;
  begin
    if R.Locals = nil then Exit;
    for I := 0 to R.Locals.Count - 1 do
    begin
      S := R.Locals[I];
      if (S is TRoutineSym) and (sfImplBody in S.Flags) and (sfHasBody in S.Flags) then
      begin
        List.Add(S);
        Nested(TRoutineSym(S));
      end;
    end;
  end;

var
  I: Integer;
begin
  for I := 0 to U.ImplRoutines.Count - 1 do
    if sfHasBody in TRoutineSym(U.ImplRoutines[I]).Flags then
    begin
      List.Add(U.ImplRoutines[I]);
      Nested(TRoutineSym(U.ImplRoutines[I]));
    end;
end;

{ the declaration of the routine implemented as R (its class's member, the unit's routine); nil none }
function DeclOf(U: TUnitInfo; R: TRoutineSym): TRoutineSym;
var
  S: TSymbol;
  L: TList;
begin
  Result := nil;
  L := TList.Create;
  try
    if R.ClassQual <> '' then
    begin
      S := U.FindTypeSym(R.ClassQual, [tyClass, tyObject, tyRecord]);
      if S <> nil then AddRoutines(S.TypeDesc.Members, R.Name, [], [], L);
    end
    else if OuterOf(R) = nil then
    begin
      AddRoutines(U.IntfSyms, R.Name, [], [sfImplBody], L);
      AddRoutines(U.ImplSyms, R.Name, [], [sfImplBody], L);
    end;
    S := PairRoutine(R, L);
    if S is TRoutineSym then Result := TRoutineSym(S);
  finally
    L.Free;
  end;
end;

{ the parameter Index of the routine implemented as R is assigned in its statements (or has its
  address taken, is passed where it may be assigned) }
function ParamWritten(CI: TCodeInsight; const FileName, Source: string; R: TRoutineSym; P: TSymbol): Boolean;
var
  L: TList;
  I: Integer;
  NU: TCINameUse;
begin
  Result := True;
  L := TList.Create;
  try
    if not CI.NameUses(FileName, Source, R.FullEnd, R.BodyEnd, L) then Exit;
    Result := False;
    for I := 0 to L.Count - 1 do
    begin
      NU := TCINameUse(L[I]);
      if not NU.Qualified and (NU.Kind = ckParam) and SameText(NU.Name, P.Name) and (KeyOffset(NU.Key) = P.DeclStart) and
        NU.Written then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    FreeObjects(L);
    L.Free;
  end;
end;

function CompareConstParams(Item1, Item2: Pointer): Integer;
begin
  Result := TRefConstParam(Item1).NameOfs - TRefConstParam(Item2).NameOfs;
  if Result = 0 then Result := TRefConstParam(Item1).Index - TRefConstParam(Item2).Index;
end;

function ConstParamsTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; Params: TList; out Error: string): Boolean;
const
  Costly = [tcString, tcShortString, tcVariant, tcInterface, tcRecord, tcArray];
var
  U, U2: TUnitInfo;
  RT, RT2: TRawToks;
  Bodies, Cands, Places, Items, Firsts, Lasts: TList;
  Rou, Decl, Here, Other: TRoutineSym;
  Ps: TList;
  Pm, Pm2: TSymbol;
  I, J, K, Q, T: Integer;
  Info: TCISymbolInfo;
  P: TCIPlace;
  TT, Cls, Src2, Arg, Key: string;
  Cat: TCITypeCategory;
  Skip, Defaults: Boolean;
  C: TRefConstParam;
  Cats: TStringList;           // the types' categories: 'type' or 'type@scope', Ord(category)
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  U := ParseText(CI, FileName, Source);
  RT := TRawToks.Create(Source, False);
  Cats := TStringList.Create;
  Cats.Sorted := True;
  Bodies := TList.Create;
  Cands := TList.Create;
  Places := TList.Create;
  Items := TList.Create;
  Firsts := TList.Create;
  Lasts := TList.Create;
  try
    Here := RoutineAround(U, Pos, Pos);
    BodiesOf(U, Bodies);
    for I := 0 to Bodies.Count - 1 do
    begin
      Rou := TRoutineSym(Bodies[I]);
      if RT.IsKw(RT.FirstAt(Rou.BodyStart), kwAsm) or (sfExternal in Rou.Flags) then Continue;
      { the parameters: the implementation's, else its declaration's }
      EnsureParams(Rou);
      Ps := Rou.Params;
      if (Ps = nil) or (Ps.Count = 0) then
      begin
        Decl := DeclOf(U, Rou);
        if Decl = nil then Continue;
        EnsureParams(Decl);
        Ps := Decl.Params;
        if Ps = nil then Continue;
      end;
      FreeObjects(Cands);
      Defaults := True;
      for J := 0 to Ps.Count - 1 do
      begin
        Pm := TSymbol(Ps[J]);
        if not (sfHasDefault in Pm.Flags) then Defaults := False;
        if (ParamModifier(Pm) <> '') or (Pm.TypeEnd <= Pm.TypeStart) or (Pm.UnitInfo = nil) then Continue;
        TT := Trim(Copy(Pm.UnitInfo.Source, Pm.TypeStart + 1, Pm.TypeEnd - Pm.TypeStart));
        { a type's category once per scope: the unit's, or a routine's with the routines nested in it }
        if OuterOf(Rou) = nil then Key := TT else Key := TT + '@' + IntToStr(Outermost(Rou).HeadStart);
        if Cats.Find(Key, Q) then
          Cat := TCITypeCategory(Cats.Objects[Q])
        else
        begin
          Cat := CI.TypeCategory(FileName, Source, Rou.HeadStart, TT);
          Cats.AddObject(Key, TObject(Ord(Cat)));
        end;
        if not (Cat in Costly) or ParamWritten(CI, FileName, Source, Rou, Pm) then Continue;
        C := TRefConstParam.Create;
        Cands.Add(C);
        C.Param := Pm.Name + ': ' + TT;
        C.NameOfs := Rou.DeclStart;
        C.Index := J;
        C.Checked := Cat = tcInterface;       // a mark until the calls are seen: an interface
      end;
      if Cands.Count = 0 then Continue;
      { the routine as its places show it }
      FreeObjects(Places);
      if not CI.SymbolPlaces(FileName, Source, Rou.DeclStart, Files, Info, Places) or Info.Overloaded or
        (Info.Outside <> '') or (Info.OwnerIsClass and (Info.Visibility in [cvPublished, cvNone])) then Continue;
      Skip := False;
      { a method of an interface: the interface's heading is the one it must have }
      if Info.OwnerIsClass and (U.FindTypeSym(Info.Owner, [tyClass]) <> nil) then
      begin
        FreeObjects(Items);
        if CI.ClassMethods(FileName, Source, U.FindTypeSym(Info.Owner, [tyClass]).DeclStart, True, Cls, Items) then
          for J := 0 to Items.Count - 1 do
            if TCIMethodItem(Items[J]).FromInterface and SameText(TCIMethodItem(Items[J]).Name, Rou.Name) then Skip := True;
      end;
      for J := 0 to Places.Count - 1 do
      begin
        if Skip then Break;
        P := TCIPlace(Places[J]);
        Src2 := R.Source(P.FileName);
        RT2 := TRawToks.Create(Src2, False);
        U2 := nil;
        try
          K := RT2.FirstAt(P.Start);
          if P.Decl then
          begin
            { an override's statements must not change it either }
            U2 := ParseText(CI, P.FileName, Src2);
            Other := RoutineNamedAt(U2, P.Start);
            if (Other <> nil) and (sfImplBody in Other.Flags) and (sfHasBody in Other.Flags) and
              not (SameText(P.FileName, FileName) and (P.Start = Rou.DeclStart)) then
            begin
              EnsureParams(Other);
              for Q := Cands.Count - 1 downto 0 do
              begin
                C := TRefConstParam(Cands[Q]);
                if (Other.Params = nil) or (C.Index >= Other.Params.Count) then Continue;
                Pm2 := TSymbol(Other.Params[C.Index]);
                if ParamWritten(CI, P.FileName, Src2, Other, Pm2) then
                begin
                  C.Free;
                  Cands.Delete(Q);
                end;
              end;
            end;
            Continue;
          end;
          { a procedural value (its address, the routine itself named): its type is the heading it needs }
          if RT2.IsSy(K - 1, syAt) or (not RT2.IsSy(K + 1, syLParen) and (not Defaults or RT2.IsSy(K - 1, syAssign) or
            RT2.IsSy(K - 1, syLParen) or RT2.IsSy(K - 1, syComma))) then
          begin
            Skip := True;
            Continue;
          end;
          { an interface made of a new object (TFoo.Create): a const parameter would never free it }
          if RT2.IsSy(K + 1, syLParen) then
          begin
            Firsts.Clear;
            Lasts.Clear;
            Q := RT2.MatchClose(K + 1);
            if Q < 0 then Continue;
            for T := Cands.Count - 1 downto 0 do
            begin
              C := TRefConstParam(Cands[T]);
              if not C.Checked then Continue;
              Firsts.Clear;
              Lasts.Clear;
              { the arguments }
              Arg := '';
              Q := K + 2;
              while (Q < RT2.N) and (Firsts.Count <= C.Index) do
              begin
                Firsts.Add(Pointer(Q));
                while (Q < RT2.N) and not RT2.IsSy(Q, syComma) and not RT2.IsSy(Q, syRParen) do
                  if RT2.IsSy(Q, syLParen) or RT2.IsSy(Q, syLBracket) then Q := RT2.MatchClose(Q) + 1 else Inc(Q);
                Lasts.Add(Pointer(Q - 1));
                if not RT2.IsSy(Q, syComma) then Break;
                Inc(Q);
              end;
              if C.Index < Firsts.Count then
                for Q := Integer(Firsts[C.Index]) to Integer(Lasts[C.Index]) do
                  if RT2.IsId(Q, 'Create') and RT2.IsSy(Q - 1, syDot) then
                  begin
                    R.Notes.Add(Format('%s(%d): %s gets a new object there; it stays as it is.',
                      [ExtractFileName(P.FileName), P.Line, C.Param]));
                    C.Free;
                    Cands.Delete(T);
                    Break;
                  end;
            end;
          end;
        finally
          U2.Free;
          RT2.Free;
        end;
      end;
      if Skip then Continue;
      if Rou.ClassQual <> '' then TT := Rou.ClassQual + '.' + Rou.Name else TT := Rou.Name;
      for J := 0 to Cands.Count - 1 do
      begin
        C := TRefConstParam(Cands[J]);
        C.Routine := TT;
        C.Checked := (Here = nil) or (Here = Rou);
        Params.Add(C);
      end;
      Cands.Clear;
    end;
    if Params.Count = 0 then
    begin
      Error := Format('No parameter of %s can be const: none of a string, record, array, Variant or interface type that its routine never changes',
        [U.Name]);
      Exit;
    end;
    Params.Sort(CompareConstParams);
    Result := True;
  finally
    FreeObjects(Cands);
    Cands.Free;
    FreeObjects(Places);
    Places.Free;
    FreeObjects(Items);
    Items.Free;
    Firsts.Free;
    Lasts.Free;
    Bodies.Free;
    Cats.Free;
    RT.Free;
    U.Free;
  end;
end;

function PlanConstParams(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Files: TStrings;
  Params: TList; out Error: string): Boolean;
var
  I, J, K, Open, Close, G, N, Q, First, Mods, Colon, Last, Count: Integer;
  Places: TList;
  Info: TCISymbolInfo;
  P: TCIPlace;
  Src, Text, TypeText: string;
  RT: TRawToks;
  Want: TStringList;
  C: TRefConstParam;
  Names: array of Integer;
  AllIn, AnyIn: Boolean;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  Places := TList.Create;
  Want := TStringList.Create;
  try
    I := 0;
    while I < Params.Count do
    begin
      { a routine's parameters to make const: their places in its lists }
      C := TRefConstParam(Params[I]);
      Want.Clear;
      J := I;
      while (J < Params.Count) and (TRefConstParam(Params[J]).NameOfs = C.NameOfs) do
      begin
        if TRefConstParam(Params[J]).Checked then Want.Add(IntToStr(TRefConstParam(Params[J]).Index));
        Inc(J);
      end;
      I := J;
      if Want.Count = 0 then Continue;
      FreeObjects(Places);
      if not CI.SymbolPlaces(FileName, Source, C.NameOfs, Files, Info, Places) then
      begin
        Error := Format('Code insight does not find %s any more', [C.Routine]);
        Exit;
      end;
      for J := 0 to Places.Count - 1 do
      begin
        P := TCIPlace(Places[J]);
        if not P.Decl then Continue;
        Src := R.Source(P.FileName);
        RT := TRawToks.Create(Src, False);
        try
          K := RT.FirstAt(P.Start);
          HeadingParams(RT, Src, K, nil, Open, Close);
          if Open < 0 then Continue;
          { the list's groups - [kind] names [: type [= default]] - by their names' places }
          Count := 0;
          G := Open + 1;
          while G < Close do
          begin
            First := G;
            Mods := -1;
            if RT.IsKw(G, kwConst) or RT.IsKw(G, kwVar) or ((RT.T[G].Kind = tkIdent) and (RT.T[G].Directive = dvOut) and
              (RT.T[G + 1].Kind = tkIdent)) then
            begin
              Mods := G;
              Inc(G);
            end;
            SetLength(Names, 0);
            while (G < Close) and (RT.T[G].Kind = tkIdent) do
            begin
              SetLength(Names, Length(Names) + 1);
              Names[High(Names)] := G;
              Inc(G);
              if RT.IsSy(G, syComma) then Inc(G) else Break;
            end;
            Colon := G;
            Last := G;
            N := 0;
            while (Last < Close) and not ((N = 0) and RT.IsSy(Last, sySemicolon)) do
            begin
              if RT.IsSy(Last, syLParen) or RT.IsSy(Last, syLBracket) then Inc(N)
              else if RT.IsSy(Last, syRParen) or RT.IsSy(Last, syRBracket) then Dec(N);
              Inc(Last);
            end;
            { the group's names: all of them const, else the group taken apart }
            AllIn := Length(Names) > 0;
            AnyIn := False;
            for Q := 0 to High(Names) do
              if Want.IndexOf(IntToStr(Count + Q)) >= 0 then AnyIn := True else AllIn := False;
            if (Mods < 0) and AnyIn and RT.IsSy(Colon, syColon) then
              if AllIn then
                R.AddEdit(P.FileName, RT.T[First].Start, 0, 'const ')
              else
              begin
                TypeText := Trim(Copy(Src, RT.EndOf(Colon) + 1, RT.EndOf(Last - 1) - RT.EndOf(Colon)));
                Text := '';
                for Q := 0 to High(Names) do
                begin
                  if Q > 0 then Text := Text + '; ';
                  if Want.IndexOf(IntToStr(Count + Q)) >= 0 then Text := Text + 'const ';
                  Text := Text + RT.Txt(Names[Q]) + ': ' + TypeText;
                end;
                R.AddEdit(P.FileName, RT.T[First].Start, RT.EndOf(Last - 1) - RT.T[First].Start, Text);
              end;
            Inc(Count, Length(Names));
            G := Last + 1;
          end;
        finally
          RT.Free;
        end;
      end;
    end;
    R.Notes.Add('A const string, Variant or interface parameter is not reference-counted: a routine that frees or ' +
      'changes what was passed in through another name sees it change.');
    R.Title := 'Make parameters const';
    Result := True;
  finally
    FreeObjects(Places);
    Places.Free;
    Want.Free;
  end;
end;

end.
