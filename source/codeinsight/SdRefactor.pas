{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactor;

{ D7 Studio - the refactorings: what Rename, Declare Variable / Field, Extract Method, Find Unit,
  Extract Resource String, Change Parameters, Introduce Variable and Inline Variable change in the
  texts of a project, as edits to show before they are applied. The texts are the ones code insight
  reads - an open file's editor text, else the file's text as the editor would read it (the
  TRefGetSource the caller gives) -, offsets are 0-based into them. Nothing here writes a file; a
  form file follows a rename through TRefFormRename and DfmRename. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex, SdPasParser, SdCodeInsight, SdExplorerEdit;

type
  TRefGetSource = function(const FileName: string; out Source: string): Boolean of object;

  { Len characters at Start of a file's text replaced with Text }
  TRefEdit = class
  public
    FileName: string;
    Start, Len: Integer;
    Text: string;
  end;

  { a place of the preview: a file's lines that edits change, before and after them }
  TRefLine = class
  public
    FileName: string;
    Line: Integer;               // its first line (1-based, in the text before)
    Start: Integer;              // the offset of its first edit
    Before, After: string;       // the lines (line breaks kept)
  end;

  { what a rename changes in the forms: a component of the form class ClassName, an event
    handler (a method of ClassName), a class's name in the forms' headers }
  TRefFormKind = (rfComponent, rfHandler, rfClass);

  TRefFormRename = class
  public
    Kind: TRefFormKind;
    ClassName: string;           // rfComponent, rfHandler: the class; rfClass: the class renamed
    OldName, NewName: string;
  end;

  { a parameter of Change Parameters }
  TRefParam = class
  public
    Name, Modifier, TypeText, Default: string;   // Modifier: '', 'const', 'var', 'out'; Default: the value after "=" ('' none)
    OldIndex: Integer;           // its place in the list before (-1: a new one)
    CallValue: string;           // a new parameter's value at the calls ('': its default)
    function Text(WithDefault: Boolean): string;
    procedure Assign(Source: TRefParam);
  end;

  { what of a parameter CheckParamList finds wrong }
  TRefParamField = (pfName, pfType, pfValue);

  TRefactoring = class
  private
    FGetSource: TRefGetSource;
    FNames, FTexts: TStringList;
    FAncestors: TStringList;     // ClassAncestor's: 'TClass=TAncestor' of the files' classes
    function SourceIndex(const FileName: string): Integer;
  public
    Title: string;
    Edits: TList;                // TRefEdit, by file (in the order they came) and place after Finish
    Lines: TList;                // TRefLine: Finish makes them
    FormRenames: TList;          // TRefFormRename
    Notes: TStringList;          // what to know about the changes
    Renames: TStringList;        // files renamed once the changes are made: 'old file=new file'
    constructor Create(AGetSource: TRefGetSource);
    destructor Destroy; override;
    { a file's text: the caller's, read once }
    function Source(const FileName: string): string;
    procedure SetSource(const FileName, Text: string);
    { a change; nil when it overlaps another change of the file }
    function AddEdit(const FileName: string; Start, Len: Integer; const Text: string): TRefEdit;
    procedure AddFormRename(Kind: TRefFormKind; const ClassName, OldName, NewName: string);
    { the changes in order and the preview's lines }
    procedure Finish;
    { the files with changes, in their order }
    procedure GetFiles(List: TStrings);
    { a file's text with its changes }
    function NewText(const FileName: string): string;
    function EditCount: Integer;
    { a whole new text of a file (a form file renamed in): its changed lines as changes }
    procedure AddTextChange(const FileName, OldText, NewText: string);
    { the ancestor of the class ClassName as the files declare it ('': none known) }
    function ClassAncestor(CI: TCodeInsight; Files: TStrings; const ClassName: string): string;
    { the class ClassName is Base or derives from it, as the files declare them }
    function ClassIs(CI: TCodeInsight; Files: TStrings; const ClassName, Base: string): Boolean;
    { the classes of the files whose ancestor ClassName is, into List }
    procedure Descendants(CI: TCodeInsight; Files: TStrings; const ClassName: string; List: TStrings);
  end;

{ Rename: why the symbol cannot be renamed ('': it can) - the compiler's own, outside the files,
  a unit }
function CanRename(const Info: TCISymbolInfo; Files: TStrings): string;
{ Rename: the new name checked against the symbol (TCodeInsight.SymbolPlaces' Info and Places),
  the edits made. Files: the project's files }
function PlanRename(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places, Files: TStrings;
  const NewName: string; out Error: string): Boolean; overload;
function PlanRename(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList; Files: TStrings;
  const NewName: string; out Error: string): Boolean; overload;

{ a form file's text (Delphi's text format) with a rename. Own - the form of the class renamed in
  (or of a class derived from it): rfComponent - the component OldName in the headers (not those of
  the frames placed on the form) and in the values that name it; rfHandler - the handler's name in
  the values. Every form: rfComponent - FormName.OldName, as another form names the component;
  rfClass - the class's name in the headers. The same text when nothing changes }
function DfmRename(const Dfm: string; Kind: TRefFormKind; const OldName, NewName, FormName: string;
  Own: Boolean): string;

{ Declare Variable / Field: the undeclared name at Pos (in it or at its end) and a guess of its
  type ('': none); InMethod - it stands in a method, so that a field can be declared }
function DeclareTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Name, TypeName: string; out InMethod: Boolean; out Error: string): Boolean;
function PlanDeclareVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name, TypeName: string; out Error: string): Boolean;
{ Access: as the Code Explorer's (0 published, 1 private, 2 protected, 3 public) }
function PlanDeclareField(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name, TypeName: string; Access: Integer; out Error: string): Boolean;

{ Find Unit: the name at Pos and the units that declare it, not used yet ('Unit=kind') }
function FindUnitTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer; out Name: string;
  Units: TStrings; out InImpl: Boolean; out Error: string): Boolean;
{ UnitName into the uses clause of the interface, or of the implementation (InImpl) }
function PlanAddUses(R: TRefactoring; CI: TCodeInsight; const FileName, Source, UnitName: string;
  InImpl: Boolean; out Error: string): Boolean;

{ Extract Resource String: the string at Pos (its literal as written, a name for it) }
function ResStringTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Literal, Name: string; out Error: string): Boolean;
function PlanExtractResString(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name: string; out Error: string): Boolean;

{ Change Parameters: the routine at Pos (its places in Files, its parameters - TRefParam, the
  caller frees them -, its result type, its heading's start: 'procedure TClass.Name') }
function ChangeParamsTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places, Params: TList; out ResultType, Head: string;
  out Error: string): Boolean;
{ NewParams: TRefParam, OldIndex their place before }
function PlanChangeParams(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places, NewParams: TList;
  out Error: string): Boolean;

{ Extract Method: the statements A .. B checked; ClassName - the class whose method they are in ('':
  a plain routine) }
function ExtractTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out ClassName: string; out Error: string): Boolean;
function PlanExtractMethod(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name: string; Access: Integer; out Error: string): Boolean;

{ Introduce Variable: the expression A .. B, its type ('': unknown) and a name for it }
function IntroduceTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out Expr, TypeName, Name: string; out Error: string): Boolean;
function PlanIntroduceVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name, TypeName: string; ReplaceAll: Boolean; out Error: string): Boolean;

{ Inline Variable: the local variable at Pos, assigned once, replaced by its value }
function PlanInlineVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;

{ a name the user typed: an identifier that is not a reserved word ('' - it is; else why not) }
function CheckNewName(const Name: string): string;

{ the objects of a list freed, the list emptied }
procedure FreeObjects(L: TList);

{ a symbol as a refactoring names it: Class.Member, else its name alone }
function SymbolTitle(const Info: TCISymbolInfo): string;

{ the parameters of a parameter list's text ('A: Integer; const B: string = ''x''') as TRefParam
  into Params, OldIndex their places }
procedure ReadParamList(const Text: string; Params: TList);

{ the text of a parameter list (TRefParam), '; ' between them; WithDefaults: their default values }
function ParamListText(Params: TList; WithDefaults: Boolean): string;

{ what is wrong with a new parameter list ('': nothing) - Bad the parameter, Field what of it }
function CheckParamList(Params: TList; out Bad: Integer; out Field: TRefParamField): string;

{ --- what the refactorings share (SdRefactorGen, SdRefactorClean, SdRefactorMove): places in a text,
  its statements, declarations made and taken out }

{ the text parsed (its own picture: the routines' and declarations' places) }
function ParseText(CI: TCodeInsight; const FileName, Source: string): TUnitInfo;
{ the start of the line of Ofs, or of the comment lines right above it (no empty line between):
  where a declaration begins with what describes it }
function CommentStart(const Src: string; Ofs: Integer): Integer;
{ the innermost routine whose text holds A .. B; nil: none }
function RoutineAround(U: TUnitInfo; A, B: Integer): TRoutineSym;
{ the routine whose body (after its begin) holds A .. B; nil: none }
function BodyAround(U: TUnitInfo; A, B: Integer): TRoutineSym;
{ the method R is (or is nested in); nil: a plain routine }
function MethodOf(R: TRoutineSym): TRoutineSym;
function Outermost(R: TRoutineSym): TRoutineSym;
{ R declares Name: a local, a parameter }
function RoutineDeclares(R: TRoutineSym; const Name: string): Boolean;
{ the token of a statement's own end after K, at K's level: ;, end, else (not one of an if the
  statement holds), until, except, finally (the token itself; RT.N: the text's end) }
function StatementEnd(RT: TRawToks; K: Integer): Integer;
{ a statement begins after the token K: ; begin try finally except repeat then else do }
function BeginsStatement(RT: TRawToks; K: Integer): Boolean;
{ Decl ('Name: Type;', 'Name = Value;') into a routine's sections of the kind Section (kwVar,
  kwConst): after the last declaration of its last such section, else in a new one before its
  begin }
function AddLocalDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; Rou: TRoutineSym;
  Section: TKeyword; const Decl: string): Boolean;
{ Decl into a unit's sections of the kind Section (kwConst, kwResourcestring, kwVar, kwType) -
  of its interface (InIntf), else of its implementation, before its first routine: after the last
  declaration of the last such section, else in a new one after the part's uses clause (and the
  directives after it). AtEnd: after every declaration of the part - in its last section when that
  is of the kind, else in a new one at the part's end }
function AddSectionDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo;
  Section: TKeyword; InIntf, AtEnd: Boolean; const Decl: string): Boolean;
{ the declaration of the name at DeclOfs taken out: the name from a list of names (A, B: T), else
  the whole declaration up to DeclEnd (-1: its ";") - with its section's word when the section has
  nothing else, its lines when nothing else is on them, the comment lines above it (WithComments).
  False: it was left (another change is there, or it cannot be cut cleanly) }
function RemoveDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; DeclOfs, DeclEnd: Integer;
  WithComments: Boolean): Boolean;
{ the declarations of U's sections whose names begin at the offsets Decls (Integer values) taken out
  together, each as RemoveDecl takes one: a declaration whose names all go goes whole, a section whose
  declarations all go goes with its word. False: one was left }
function RemoveDecls(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo; Decls: TList;
  WithComments: Boolean): Boolean;
{ the word (kwType, kwConst, kwVar, kwResourcestring, kwThreadvar) of the section of U's declaration
  whose name begins at DeclOfs: the word before the first declaration of the section; kwNone - none }
function SectionWordOf(RT: TRawToks; U: TUnitInfo; DeclOfs: Integer): TKeyword;
{ the symbol of U whose declaration begins at Ofs: the unit's, its types' members, its routines'
  locals; nil none }
function SymbolAt(U: TUnitInfo; Ofs: Integer): TSymbol;
{ the expression K0 .. K1 put in the place of the name at token P needs brackets there }
function NeedsBrackets(RT: TRawToks; K0, K1, P: Integer): Boolean;
{ the precedence of the operator at K (4: not @, 3: * / div mod and shl shr as, 2: + - or xor, 1: the
  comparisons, in, is; 0: no operator) }
function OpPrec(RT: TRawToks; K: Integer): Integer;
{ the token K is a value's end (a sign after it is a binary operator) }
function EndsOperand(RT: TRawToks; K: Integer): Boolean;
{ the weakest precedence of the operators of K0 .. K1 outside brackets (a sign at the start or after
  an operator is unary: 4); 5: none }
function WeakestOp(RT: TRawToks; K0, K1: Integer): Integer;
{ the expression K0 .. K1 is a whole operand where it stands: the operators beside it bind less
  (after it: no more, as Pascal's operators bind to the left) }
function WholeOperand(RT: TRawToks; K0, K1: Integer): Boolean;
{ the N tokens at K are those at K0 (a string's case counts, a name's does not) }
function SameTokens(RT: TRawToks; K, K0, N: Integer): Boolean;
{ the end of the block the token K opens (begin, try, case, asm): its end's token; -1: none }
function BlockEnd(RT: TRawToks; K: Integer): Integer;
{ an implementation's text A .. B: its heading to its body's ";" - its whole lines with the comment
  above them when nothing else stands on them }
procedure BodyRange(const Src: string; RT: TRawToks; RS: TRoutineSym; out A, B: Integer);
{ the comment that marks a class's bodies - its name in braces - above the body that begins at A
  (empty lines between): its line's start; -1 none }
function MarkerAbove(const Src, ClassName: string; A: Integer): Integer;
{ the end of whole lines A .. B that go: past the empty line after them when an empty line is before
  them too (one of the two stays), else B }
function BlankAfter(const Src: string; A, B: Integer): Integer;
{ Ofs is in statements: a routine's body, the unit's initialization or finalization, a program's
  main block }
function InStatements(U: TUnitInfo; Ofs: Integer): Boolean;
{ the units Names into the uses clause of the interface, or of the implementation (InImpl; a program
  has the one), before its ";" - a line wrapped at column 75 -, else in a clause of their own }
function AddUsesNames(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo; Names: TStrings;
  InImpl: Boolean): Boolean;
{ the routine (a declaration or an implementation) whose name begins at Ofs; nil: none }
function RoutineNamedAt(U: TUnitInfo; Ofs: Integer): TRoutineSym;
{ L holds the file S }
function InList(L: TStrings; const S: string): Boolean;
{ a new variable's or field's name and type ('': fine) }
function CheckDeclaration(const Name, TypeName: string): string;
{ a symbol's identity (TCINameUse.Key: file#offset): the offset of its declaration (-1: none), its file }
function KeyOffset(const Key: string): Integer;
function KeyFile(const Key: string): string;
{ the string literal at Pos - adjoining string and character tokens: 'a'#13'b' -: its tokens }
function LiteralAt(RT: TRawToks; Pos: Integer; out K0, K1: Integer): Boolean;
{ a name for a string: Str and its words ('Cannot open %s' - StrCannotOpenS) }
function NameForString(const Literal: string): string;
{ the parameters of the heading whose name token is K: TRefParam into Params (nil: not read); Open,
  Close - its brackets' tokens (-1: no list) }
procedure HeadingParams(RT: TRawToks; const Src: string; K: Integer; Params: TList; out Open, Close: Integer);
function IsRoutineKind(K: TCIKind): Boolean;
{ the tokens of A .. B (whole tokens) }
function SelTokens(RT: TRawToks; A, B: Integer; out K0, K1: Integer): Boolean;
{ the statement whose head is the token W (with, for, while, on ... do; repeat): its last token }
function ScopeEnd(RT: TRawToks; W: Integer): Integer;
{ the expression A .. B checked: whole tokens of one expression in a routine's statement (St: the
  statement's first token) }
function ExprCheck(RT: TRawToks; U: TUnitInfo; A, B: Integer; out K0, K1, St: Integer; out Rou: TRoutineSym;
  out Error: string): Boolean;

implementation

const
  WrapColumn = 75;
  SectionWords = [kwVar, kwConst, kwType, kwResourcestring, kwThreadvar];

{ ---------------------------------------------------------------------------- }
{ TRefParam }

function TRefParam.Text(WithDefault: Boolean): string;
begin
  Result := Name;
  if Modifier <> '' then Result := Modifier + ' ' + Result;
  if TypeText <> '' then Result := Result + ': ' + TypeText;
  if WithDefault and (Default <> '') and (TypeText <> '') then Result := Result + ' = ' + Default;
end;

procedure TRefParam.Assign(Source: TRefParam);
begin
  Name := Source.Name;
  Modifier := Source.Modifier;
  TypeText := Source.TypeText;
  Default := Source.Default;
  OldIndex := Source.OldIndex;
  CallValue := Source.CallValue;
end;

{ ---------------------------------------------------------------------------- }
{ TRefactoring }

constructor TRefactoring.Create(AGetSource: TRefGetSource);
begin
  inherited Create;
  FGetSource := AGetSource;
  FNames := TStringList.Create;
  FTexts := TStringList.Create;
  Edits := TList.Create;
  Lines := TList.Create;
  FormRenames := TList.Create;
  Notes := TStringList.Create;
  Renames := TStringList.Create;
end;

destructor TRefactoring.Destroy;
begin
  FreeObjects(Edits);
  FreeObjects(Lines);
  FreeObjects(FormRenames);
  Edits.Free;
  Lines.Free;
  FormRenames.Free;
  Notes.Free;
  Renames.Free;
  FTexts.Free;
  FNames.Free;
  FAncestors.Free;
  inherited Destroy;
end;

function TRefactoring.SourceIndex(const FileName: string): Integer;
var
  S: string;
begin
  for Result := 0 to FNames.Count - 1 do
    if SameText(FNames[Result], FileName) then Exit;
  S := '';
  if Assigned(FGetSource) and not FGetSource(FileName, S) then S := '';
  FNames.Add(FileName);
  Result := FTexts.Add(S);
end;

function TRefactoring.Source(const FileName: string): string;
begin
  Result := FTexts[SourceIndex(FileName)];
end;

procedure TRefactoring.SetSource(const FileName, Text: string);
var
  I: Integer;
begin
  for I := 0 to FNames.Count - 1 do
    if SameText(FNames[I], FileName) then
    begin
      FTexts[I] := Text;
      Exit;
    end;
  FNames.Add(FileName);
  FTexts.Add(Text);
end;

function TRefactoring.AddEdit(const FileName: string; Start, Len: Integer; const Text: string): TRefEdit;
var
  I: Integer;
  E: TRefEdit;
begin
  Result := nil;
  SourceIndex(FileName);
  for I := 0 to Edits.Count - 1 do
  begin
    E := TRefEdit(Edits[I]);
    if not SameText(E.FileName, FileName) then Continue;
    if (E.Start = Start) and (E.Len = Len) and (E.Text = Text) then Exit;      // the same change twice
    { overlapping changes; two insertions at one place stay in their order }
    if (Start < E.Start + E.Len) and (E.Start < Start + Len) then Exit;
    if (Len > 0) and (E.Len = 0) and (E.Start > Start) and (E.Start < Start + Len) then Exit;
    if (Len = 0) and (E.Len > 0) and (Start > E.Start) and (Start < E.Start + E.Len) then Exit;
  end;
  Result := TRefEdit.Create;
  Result.FileName := FileName;
  Result.Start := Start;
  Result.Len := Len;
  Result.Text := Text;
  Edits.Add(Result);
end;

procedure TRefactoring.AddFormRename(Kind: TRefFormKind; const ClassName, OldName, NewName: string);
var
  F: TRefFormRename;
begin
  F := TRefFormRename.Create;
  F.Kind := Kind;
  F.ClassName := ClassName;
  F.OldName := OldName;
  F.NewName := NewName;
  FormRenames.Add(F);
end;

function TRefactoring.EditCount: Integer;
begin
  Result := Edits.Count;
end;

procedure TRefactoring.GetFiles(List: TStrings);
var
  I: Integer;
begin
  List.Clear;
  for I := 0 to Edits.Count - 1 do
    if List.IndexOf(TRefEdit(Edits[I]).FileName) < 0 then List.Add(TRefEdit(Edits[I]).FileName);
end;

{ the order of the changes: by file (the order of the files' first changes), then by place - an
  insertion before a replacement at the same place, insertions in the order they came }
var
  SortFiles: TStringList;

function CompareEdits(Item1, Item2: Pointer): Integer;
var
  A, B: TRefEdit;
begin
  A := TRefEdit(Item1);
  B := TRefEdit(Item2);
  Result := SortFiles.IndexOf(A.FileName) - SortFiles.IndexOf(B.FileName);
  if Result = 0 then Result := A.Start - B.Start;
  if Result = 0 then Result := A.Len - B.Len;
end;

procedure TRefactoring.Finish;
var
  Files: TStringList;
  I, J, K, LS, LE, P: Integer;
  Src, S: string;
  E: TRefEdit;
  L: TRefLine;
begin
  FreeObjects(Lines);
  Files := TStringList.Create;
  try
    GetFiles(Files);
    { an insertion sort: stable, the changes that came first stay first }
    SortFiles := Files;
    for I := 1 to Edits.Count - 1 do
    begin
      E := TRefEdit(Edits[I]);
      J := I - 1;
      while (J >= 0) and (CompareEdits(Edits[J], E) > 0) do
      begin
        Edits[J + 1] := Edits[J];
        Dec(J);
      end;
      Edits[J + 1] := E;
    end;
    SortFiles := nil;
    { the preview: the lines each run of changes touches, before and after }
    I := 0;
    while I < Edits.Count do
    begin
      E := TRefEdit(Edits[I]);
      Src := Source(E.FileName);
      LS := LineStartOf(Src, E.Start);
      LE := LineEndOf(Src, E.Start + E.Len);
      J := I + 1;
      while (J < Edits.Count) and SameText(TRefEdit(Edits[J]).FileName, E.FileName) and
        (TRefEdit(Edits[J]).Start <= LE) do
      begin
        if LineEndOf(Src, TRefEdit(Edits[J]).Start + TRefEdit(Edits[J]).Len) > LE then
          LE := LineEndOf(Src, TRefEdit(Edits[J]).Start + TRefEdit(Edits[J]).Len);
        Inc(J);
      end;
      L := TRefLine.Create;
      Lines.Add(L);
      L.FileName := E.FileName;
      L.Start := E.Start;
      L.Line := 1;
      for K := 1 to LS do
        if Src[K] = #10 then Inc(L.Line)
        else if (Src[K] = #13) and ((K = Length(Src)) or (Src[K + 1] <> #10)) then Inc(L.Line);
      L.Before := Copy(Src, LS + 1, LE - LS);
      S := '';
      P := LS;
      for K := I to J - 1 do
        with TRefEdit(Edits[K]) do
        begin
          S := S + Copy(Src, P + 1, Start - P) + Text;
          P := Start + Len;
        end;
      L.After := S + Copy(Src, P + 1, LE - P);
      I := J;
    end;
  finally
    Files.Free;
  end;
end;

function TRefactoring.NewText(const FileName: string): string;
var
  I, P: Integer;
  Src: string;
  E: TRefEdit;
begin
  Src := Source(FileName);
  Result := '';
  P := 0;
  for I := 0 to Edits.Count - 1 do
  begin
    E := TRefEdit(Edits[I]);
    if not SameText(E.FileName, FileName) then Continue;
    Result := Result + Copy(Src, P + 1, E.Start - P) + E.Text;
    P := E.Start + E.Len;
  end;
  Result := Result + Copy(Src, P + 1, MaxInt);
end;

procedure TRefactoring.AddTextChange(const FileName, OldText, NewText: string);
var
  PA, PB, EA, EB: Integer;
begin
  SetSource(FileName, OldText);
  PA := 0;
  PB := 0;
  while (PA < Length(OldText)) or (PB < Length(NewText)) do
  begin
    EA := LineEndOf(OldText, PA);
    EB := LineEndOf(NewText, PB);
    if Copy(OldText, PA + 1, EA - PA) <> Copy(NewText, PB + 1, EB - PB) then
      AddEdit(FileName, PA, EA - PA, Copy(NewText, PB + 1, EB - PB));
    if (PA >= Length(OldText)) <> (PB >= Length(NewText)) then
    begin
      { the line counts differ: the rest as one change }
      AddEdit(FileName, EA, Length(OldText) - EA, Copy(NewText, EB + 1, MaxInt));
      Exit;
    end;
    PA := NextLineStart(OldText, PA);
    PB := NextLineStart(NewText, PB);
    if (PA = EA) and (PB = EB) then Break;
  end;
end;

function TRefactoring.ClassAncestor(CI: TCodeInsight; Files: TStrings; const ClassName: string): string;
var
  I, J, Pass: Integer;
  U: TUnitInfo;
  Tab: TSymTable;
  S: TSymbol;
begin
  if FAncestors = nil then
  begin
    FAncestors := TStringList.Create;
    for I := 0 to Files.Count - 1 do
    begin
      if not (SameText(ExtractFileExt(Files[I]), '.pas') or SameText(ExtractFileExt(Files[I]), '.dpr')) then Continue;
      U := ParseText(CI, Files[I], Source(Files[I]));
      try
        for Pass := 0 to 1 do
        begin
          if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
          for J := 0 to Tab.Count - 1 do
          begin
            S := Tab[J];
            if (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Kind = tyClass) and
              not S.TypeDesc.IsForward and (S.TypeDesc.Ancestors <> nil) and (S.TypeDesc.Ancestors.Count > 0) then
              FAncestors.Add(S.Name + '=' + S.TypeDesc.Ancestors[0]);
          end;
        end;
      finally
        U.Free;
      end;
    end;
  end;
  Result := FAncestors.Values[ClassName];
  { a qualified ancestor: Unit.TClass }
  if LastDelimiter('.', Result) > 0 then Result := Copy(Result, LastDelimiter('.', Result) + 1, MaxInt);
end;

procedure TRefactoring.Descendants(CI: TCodeInsight; Files: TStrings; const ClassName: string; List: TStrings);
var
  I: Integer;
  A: string;
begin
  List.Clear;
  ClassAncestor(CI, Files, ClassName);           // the classes of the files, once
  for I := 0 to FAncestors.Count - 1 do
  begin
    A := Copy(FAncestors[I], System.Pos('=', FAncestors[I]) + 1, MaxInt);
    if LastDelimiter('.', A) > 0 then A := Copy(A, LastDelimiter('.', A) + 1, MaxInt);
    if SameText(A, ClassName) then List.Add(FAncestors.Names[I]);
  end;
end;

function TRefactoring.ClassIs(CI: TCodeInsight; Files: TStrings; const ClassName, Base: string): Boolean;
var
  C: string;
  Depth: Integer;
begin
  C := ClassName;
  Depth := 0;
  while (C <> '') and (Depth < 32) do
  begin
    if SameText(C, Base) then
    begin
      Result := True;
      Exit;
    end;
    C := ClassAncestor(CI, Files, C);
    Inc(Depth);
  end;
  Result := False;
end;

{ ---------------------------------------------------------------------------- }
{ helpers }

function CheckNewName(const Name: string): string;
var
  L: TPasLexer;
begin
  Result := '';
  if not IsValidIdent(Name) then
  begin
    Result := Format('''%s'' is not a valid identifier', [Name]);
    Exit;
  end;
  L := TPasLexer.Create(Name);
  try
    L.Next;
    if L.Tok.Kind = tkKeyword then Result := Format('''%s'' is a reserved word', [Name]);
  finally
    L.Free;
  end;
end;

procedure FreeObjects(L: TList);
var
  I: Integer;
begin
  for I := 0 to L.Count - 1 do TObject(L[I]).Free;
  L.Clear;
end;

function SymbolTitle(const Info: TCISymbolInfo): string;
begin
  Result := Info.Name;
  if (Info.Owner <> '') and not Info.Local then Result := Info.Owner + '.' + Result;
end;

procedure ReadParamList(const Text: string; Params: TList);
var
  L: TList;
  U: TUnitInfo;
  I: Integer;
  S: TSymbol;
  P: TRefParam;
begin
  L := TList.Create;
  U := TUnitInfo.Create;
  try
    ParseParamText(U, Text, L);
    for I := 0 to L.Count - 1 do
    begin
      S := TSymbol(L[I]);
      P := TRefParam.Create;
      Params.Add(P);
      P.Name := S.Name;
      P.Modifier := ParamModifier(S);
      P.OldIndex := I;
      if S.TypeEnd > S.TypeStart then P.TypeText := Trim(Copy(Text, S.TypeStart + 1, S.TypeEnd - S.TypeStart));
      if (sfHasDefault in S.Flags) and (S.DeclEnd > S.TypeEnd) then
      begin
        P.Default := Trim(Copy(Text, S.TypeEnd + 1, S.DeclEnd - S.TypeEnd));
        if (P.Default <> '') and (P.Default[1] = '=') then P.Default := Trim(Copy(P.Default, 2, MaxInt));
      end;
    end;
  finally
    FreeSymList(L);
    U.Free;
  end;
end;

function ParamListText(Params: TList; WithDefaults: Boolean): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Params.Count - 1 do
  begin
    if I > 0 then Result := Result + '; ';
    Result := Result + TRefParam(Params[I]).Text(WithDefaults);
  end;
end;

function CheckParamList(Params: TList; out Bad: Integer; out Field: TRefParamField): string;
var
  I, J: Integer;
  P: TRefParam;
begin
  for I := 0 to Params.Count - 1 do
  begin
    Bad := I;
    P := TRefParam(Params[I]);
    Field := pfName;
    Result := CheckNewName(P.Name);
    if Result <> '' then Exit;
    for J := 0 to I - 1 do
      if SameText(TRefParam(Params[J]).Name, P.Name) then
      begin
        Result := Format('Two parameters are named %s', [P.Name]);
        Exit;
      end;
    Field := pfType;
    if (P.TypeText = '') and (P.Modifier = '') then
    begin
      Result := Format('Give %s a type', [P.Name]);
      Exit;
    end;
    Field := pfValue;
    if (P.OldIndex < 0) and (P.CallValue = '') and (P.Default = '') then
    begin
      Result := Format('Give %s a value for the calls, or a default value', [P.Name]);
      Exit;
    end;
  end;
  Bad := -1;
  Result := '';
end;

function CheckDeclaration(const Name, TypeName: string): string;
begin
  Result := CheckNewName(Name);
  if (Result = '') and (Trim(TypeName) = '') then Result := 'Give it a type';
end;

function KeyOffset(const Key: string): Integer;
begin
  Result := StrToIntDef(Copy(Key, LastDelimiter('#', Key) + 1, MaxInt), -1);
end;

function KeyFile(const Key: string): string;
begin
  Result := Copy(Key, 1, LastDelimiter('#', Key) - 1);
end;

function ParseText(CI: TCodeInsight; const FileName, Source: string): TUnitInfo;
begin
  Result := TUnitInfo.Create;
  Result.FileName := FileName;
  ParseSource(Result, Source, False, CI.Defines, nil);
end;

function CommentStart(const Src: string; Ofs: Integer): Integer;
var
  J, K, K2: Integer;
  Line, Up: string;
  Opened: Boolean;
begin
  Result := LineStartOf(Src, Ofs);
  while Result > 0 do
  begin
    J := PrevLineStart(Src, Result);
    Line := Trim(Copy(Src, J + 1, Result - J));
    if (Line <> '') and ((Copy(Line, 1, 2) = '//') or (Line[1] = '{') and (Copy(Line, 1, 2) <> '{$') and
      (Line[Length(Line)] = '}')) then
      Result := J
    else if (Line <> '') and (Line[Length(Line)] = '}') and (System.Pos('{', Line) = 0) then
    begin
      { the last line of a comment over several lines: up to the line that opens it }
      K := J;
      Opened := False;
      while K > 0 do
      begin
        K2 := PrevLineStart(Src, K);
        Up := Trim(Copy(Src, K2 + 1, K - K2));
        if System.Pos('}', Up) > 0 then Break;
        if (Copy(Up, 1, 1) = '{') and (Copy(Up, 1, 2) <> '{$') then
        begin
          Opened := True;
          K := K2;
          Break;
        end;
        if System.Pos('{', Up) > 0 then Break;
        K := K2;
      end;
      if not Opened then Break;
      Result := K;
    end
    else
      Break;
  end;
end;

function RoutineHas(R: TRoutineSym; A, B: Integer): Boolean;
begin
  Result := (sfHasBody in R.Flags) and (R.HeadStart <= A) and (B <= R.BodyEnd);
end;

function RoutineAround(U: TUnitInfo; A, B: Integer): TRoutineSym;
var
  I: Integer;
  R, N: TRoutineSym;
  S: TSymbol;
begin
  Result := nil;
  for I := 0 to U.ImplRoutines.Count - 1 do
  begin
    R := TRoutineSym(U.ImplRoutines[I]);
    if RoutineHas(R, A, B) then Result := R;
  end;
  while Result <> nil do
  begin
    N := nil;
    if Result.Locals <> nil then
      for I := 0 to Result.Locals.Count - 1 do
      begin
        S := Result.Locals[I];
        if (S is TRoutineSym) and (sfImplBody in S.Flags) and RoutineHas(TRoutineSym(S), A, B) then
          N := TRoutineSym(S);
      end;
    if N = nil then Break;
    Result := N;
  end;
end;

function BodyAround(U: TUnitInfo; A, B: Integer): TRoutineSym;
begin
  Result := RoutineAround(U, A, B);
  if (Result <> nil) and not ((A > Result.BodyStart) and (B <= Result.BodyEnd)) then Result := nil;
end;

function MethodOf(R: TRoutineSym): TRoutineSym;
begin
  Result := R;
  while (Result <> nil) and (Result.ClassQual = '') do Result := OuterOf(Result);
end;

function Outermost(R: TRoutineSym): TRoutineSym;
begin
  Result := R;
  while OuterOf(Result) <> nil do Result := OuterOf(Result);
end;

{ R declares Name: a local, a parameter }
function RoutineDeclares(R: TRoutineSym; const Name: string): Boolean;
var
  I: Integer;
begin
  Result := (R.Locals <> nil) and (R.Locals.Find(Name) <> nil);
  if Result then Exit;
  EnsureParams(R);
  if R.Params <> nil then
    for I := 0 to R.Params.Count - 1 do
      if SameText(TSymbol(R.Params[I]).Name, Name) then
      begin
        Result := True;
        Exit;
      end;
end;

function StatementEnd(RT: TRawToks; K: Integer): Integer;
var
  Depth, Block, Ifs: Integer;
begin
  Depth := 0;
  Block := 0;
  Ifs := 0;                        // the ifs of the statement still without their else
  Result := K;
  while Result < RT.N do
  begin
    with RT.T[Result] do
      if Kind = tkSymbol then
      begin
        if Symbol in [syLParen, syLBracket] then Inc(Depth)
        else if Symbol in [syRParen, syRBracket] then Dec(Depth)
        else if (Symbol = sySemicolon) and (Depth <= 0) and (Block = 0) then Exit;
      end
      else if Kind = tkKeyword then
        case Keyword of
          kwBegin, kwTry, kwCase, kwRepeat, kwAsm: Inc(Block);
          kwEnd, kwUntil:
            begin
              if Block = 0 then Exit;
              Dec(Block);
            end;
          kwIf:
            if Block = 0 then Inc(Ifs);
          kwElse:
            if (Block = 0) and (Depth <= 0) then
            begin
              if Ifs = 0 then Exit;
              Dec(Ifs);
            end;
          kwExcept, kwFinally:
            if (Block = 0) and (Depth <= 0) then Exit;
        end;
    Inc(Result);
  end;
end;

function BeginsStatement(RT: TRawToks; K: Integer): Boolean;
begin
  Result := RT.IsSy(K, sySemicolon) or
    ((RT.T[K].Kind = tkKeyword) and (RT.T[K].Keyword in [kwBegin, kwTry, kwFinally, kwExcept, kwRepeat,
      kwThen, kwElse, kwDo]));
end;

function AddLocalDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; Rou: TRoutineSym;
  Section: TKeyword; const Decl: string): Boolean;
var
  K, K0, K1, I, LastSemi, Depth, Nest: Integer;
  InVar: Boolean;
  EOL, Ind, Word: string;

  function InNested(Ofs: Integer): Boolean;
  var
    J: Integer;
    N: TSymbol;
  begin
    Result := False;
    if Rou.Locals = nil then Exit;
    for J := 0 to Rou.Locals.Count - 1 do
    begin
      N := Rou.Locals[J];
      if (N is TRoutineSym) and (sfImplBody in N.Flags) and (TRoutineSym(N).HeadStart <= Ofs) and
        (Ofs < TRoutineSym(N).BodyEnd) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

begin
  EOL := DetectEOL(Src);
  Word := KeywordNames[Section];
  K0 := RT.FirstAt(Rou.FullEnd);
  K1 := RT.FirstAt(Rou.BodyStart);
  InVar := False;
  LastSemi := -1;
  Depth := 0;
  Nest := 0;
  for K := K0 to K1 - 1 do
  begin
    if InNested(RT.T[K].Start) then
    begin
      InVar := False;
      Continue;
    end;
    if RT.T[K].Kind = tkKeyword then
      case RT.T[K].Keyword of
        kwRecord, kwObject: Inc(Nest);
        kwEnd: if Nest > 0 then Dec(Nest);
        kwVar, kwConst, kwType, kwLabel, kwResourcestring, kwProcedure, kwFunction, kwConstructor, kwDestructor,
        kwClass, kwThreadvar:
          if (Nest = 0) and (Depth = 0) then InVar := RT.T[K].Keyword = Section;
      end
    else if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then
      Inc(Depth)
    else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then
      Dec(Depth)
    else if InVar and (Depth = 0) and (Nest = 0) and RT.IsSy(K, sySemicolon) then
      LastSemi := K;
  end;
  if LastSemi >= 0 then
  begin
    { the indentation of the last declaration }
    I := LastSemi;
    while (I > K0) and not RT.IsSy(I - 1, sySemicolon) and not RT.IsKw(I - 1, Section) do Dec(I);
    Ind := IndentAt(Src, RT.T[I].Start);
    if not FirstOnLine(Src, RT.T[I].Start) then Ind := IndentAt(Src, RT.T[I].Start) + '  ';
    Result := R.AddEdit(FileName, LineEndOf(Src, RT.T[LastSemi].Start), 0, EOL + Ind + Decl) <> nil;
  end
  else
  begin
    Ind := IndentAt(Src, Rou.BodyStart);
    if FirstOnLine(Src, Rou.BodyStart) then
      Result := R.AddEdit(FileName, LineStartOf(Src, Rou.BodyStart), 0,
        Ind + Word + EOL + Ind + '  ' + Decl + EOL) <> nil
    else
      Result := R.AddEdit(FileName, Rou.BodyStart, 0, Word + ' ' + Decl + ' ') <> nil;
  end;
end;

function RemoveDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; DeclOfs, DeclEnd: Integer;
  WithComments: Boolean): Boolean;
var
  K, S, A, B, Depth: Integer;
  Alone: Boolean;
begin
  Result := False;
  K := RT.FirstAt(DeclOfs);
  if (K <= 0) or (K >= RT.N) or (RT.T[K].Start <> DeclOfs) then Exit;
  if RT.IsSy(K + 1, syComma) then
  begin
    Result := R.AddEdit(FileName, RT.T[K].Start, RT.T[K + 2].Start - RT.T[K].Start, '') <> nil;
    Exit;
  end;
  if RT.IsSy(K - 1, syComma) then
  begin
    Result := R.AddEdit(FileName, RT.T[K - 1].Start, RT.EndOf(K) - RT.T[K - 1].Start, '') <> nil;
    Exit;
  end;
  { its own declaration: to DeclEnd, else to its ";" outside brackets }
  if DeclEnd > DeclOfs then
    S := RT.FirstAt(DeclEnd) - 1
  else
  begin
    S := K;
    Depth := 0;
    while S < RT.N do
    begin
      if RT.IsSy(S, syLParen) or RT.IsSy(S, syLBracket) then Inc(Depth)
      else if RT.IsSy(S, syRParen) or RT.IsSy(S, syRBracket) then Dec(Depth)
      else if (Depth = 0) and RT.IsSy(S, sySemicolon) then Break;
      Inc(S);
    end;
  end;
  if (S < K) or (S >= RT.N) then Exit;
  { the only declaration of its section: the section's word before it, no declaration after it }
  Alone := (RT.T[K - 1].Kind = tkKeyword) and (RT.T[K - 1].Keyword in SectionWords) and
    not ((S + 1 < RT.N) and (RT.T[S + 1].Kind = tkIdent) and
    (RT.IsSy(S + 2, syColon) or RT.IsSy(S + 2, syComma) or RT.IsSy(S + 2, syEqual)));
  if Alone then A := RT.T[K - 1].Start else A := RT.T[K].Start;
  B := RT.EndOf(S);
  if WholeLines(Src, A, B) then
  begin
    if WithComments then A := CommentStart(Src, A);
    B := BlankAfter(Src, A, B);
  end
  else if Alone then
    Exit;
  Result := R.AddEdit(FileName, A, B - A, '') <> nil;
end;

function CompareDeclStart(Item1, Item2: Pointer): Integer;
begin
  Result := TSymbol(Item1).DeclStart - TSymbol(Item2).DeclStart;
end;

{ the declarations of U's sections - constants, resource strings, variables, types -, in the text's
  order }
procedure SectionSyms(U: TUnitInfo; Syms: TList);

  procedure Collect(Tab: TSymTable);
  var
    I: Integer;
  begin
    if Tab <> nil then
      for I := 0 to Tab.Count - 1 do
        if (Tab[I].Kind in [skConst, skResStr, skVar, skType]) and (Tab[I].FullEnd > Tab[I].DeclStart) then
          Syms.Add(Tab[I]);
  end;

begin
  Collect(U.IntfSyms);
  Collect(U.ImplSyms);
  Syms.Sort(CompareDeclStart);
end;

{ the section of Syms[I] (SectionSyms): the declarations around it with nothing between them, First ..
  Last, and the token of the section's word right before the first; -1 - no word there (a declaration
  the parser keeps no symbol of stands before it, a forward declaration of a class) }
function SectionSpan(RT: TRawToks; Syms: TList; I: Integer; out First, Last: Integer): Integer;

  { the declaration after Q goes on its section: a name of its list, or nothing between them }
  function Continues(Q: Integer): Boolean;
  begin
    Result := (Q + 1 < Syms.Count) and ((TSymbol(Syms[Q + 1]).DeclStart < TSymbol(Syms[Q]).FullEnd) or
      (RT.FirstAt(TSymbol(Syms[Q]).FullEnd) = RT.FirstAt(TSymbol(Syms[Q + 1]).DeclStart)));
  end;

begin
  First := I;
  while (First > 0) and Continues(First - 1) do Dec(First);
  Last := I;
  while Continues(Last) do Inc(Last);
  Result := RT.FirstAt(TSymbol(Syms[First]).DeclStart) - 1;
  if (Result < 0) or (RT.T[Result].Kind <> tkKeyword) or not (RT.T[Result].Keyword in SectionWords) then Result := -1;
end;

function SectionWordOf(RT: TRawToks; U: TUnitInfo; DeclOfs: Integer): TKeyword;
var
  Syms: TList;
  I, F, L, W: Integer;
begin
  Result := kwNone;
  Syms := TList.Create;
  try
    SectionSyms(U, Syms);
    for I := 0 to Syms.Count - 1 do
      if TSymbol(Syms[I]).DeclStart = DeclOfs then
      begin
        W := SectionSpan(RT, Syms, I, F, L);
        if W >= 0 then Result := RT.T[W].Keyword;
        Exit;
      end;
  finally
    Syms.Free;
  end;
end;

function RemoveDecls(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo; Decls: TList;
  WithComments: Boolean): Boolean;
var
  Syms, Taken: TList;
  I, J, F, L, X, Y, W, N: Integer;
  All: Boolean;

  function Sym(Q: Integer): TSymbol;
  begin
    Result := TSymbol(Syms[Q]);
  end;

  function Goes(Q: Integer): Boolean;
  begin
    Result := Decls.IndexOf(Pointer(Sym(Q).DeclStart)) >= 0;
  end;

  { the declarations First .. Last go: the text A .. B, its lines with the comment above them when
    nothing else stands on them }
  function Cut(First, Last, A, B: Integer): Boolean;
  var
    Q: Integer;
  begin
    for Q := First to Last do Taken.Add(Pointer(Sym(Q).DeclStart));
    if WholeLines(Src, A, B) then
    begin
      if WithComments then A := CommentStart(Src, A);
      B := BlankAfter(Src, A, B);
    end;
    Result := R.AddEdit(FileName, A, B - A, '') <> nil;
  end;

begin
  Result := False;
  Syms := TList.Create;
  Taken := TList.Create;
  try
    SectionSyms(U, Syms);
    for I := 0 to Syms.Count - 1 do
    begin
      if not Goes(I) or (Taken.IndexOf(Pointer(Sym(I).DeclStart)) >= 0) then Continue;
      { the whole section with its word, when no declaration follows it that the parser keeps no
        symbol of }
      W := SectionSpan(RT, Syms, I, F, L);
      N := RT.FirstAt(Sym(L).FullEnd);
      All := (W >= 0) and not ((N < RT.N) and (RT.T[N].Kind = tkIdent));
      for J := F to L do
        if not Goes(J) then All := False;
      if All then
      begin
        if not Cut(F, L, RT.T[W].Start, Sym(L).FullEnd) then Exit;
        Continue;
      end;
      { a declaration of several names that all go }
      X := I;
      while (X > F) and (Sym(X - 1).FullEnd = Sym(I).FullEnd) do Dec(X);
      Y := I;
      while (Y < L) and (Sym(Y + 1).FullEnd = Sym(I).FullEnd) do Inc(Y);
      All := Y > X;
      for J := X to Y do
        if not Goes(J) then All := False;
      if All then
      begin
        if not Cut(X, Y, Sym(X).DeclStart, Sym(Y).FullEnd) then Exit;
        Continue;
      end;
      Taken.Add(Pointer(Sym(I).DeclStart));
      if not RemoveDecl(R, FileName, Src, RT, Sym(I).DeclStart, Sym(I).FullEnd, WithComments) then Exit;
    end;
    { what is no declaration of a section the parser knows: one by one }
    for I := 0 to Decls.Count - 1 do
      if Taken.IndexOf(Decls[I]) < 0 then
      begin
        Taken.Add(Decls[I]);
        if not RemoveDecl(R, FileName, Src, RT, Integer(Decls[I]), -1, WithComments) then Exit;
      end;
    Result := True;
  finally
    Taken.Free;
    Syms.Free;
  end;
end;

function SymbolAt(U: TUnitInfo; Ofs: Integer): TSymbol;

  function InTable(Tab: TSymTable): TSymbol;
  var
    I: Integer;
    S: TSymbol;
  begin
    Result := nil;
    if Tab = nil then Exit;
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if S.DeclStart = Ofs then
      begin
        Result := S;
        Exit;
      end;
      if (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Sym = S) and (S.TypeDesc.Members <> nil) then
      begin
        Result := InTable(S.TypeDesc.Members);
        if Result <> nil then Exit;
      end;
      if (S is TRoutineSym) and (TRoutineSym(S).Locals <> nil) then
      begin
        Result := InTable(TRoutineSym(S).Locals);
        if Result <> nil then Exit;
      end;
    end;
  end;

var
  I: Integer;
begin
  Result := InTable(U.IntfSyms);
  if Result = nil then Result := InTable(U.ImplSyms);
  if Result <> nil then Exit;
  for I := 0 to U.ImplRoutines.Count - 1 do
    if TRoutineSym(U.ImplRoutines[I]).Locals <> nil then
    begin
      Result := InTable(TRoutineSym(U.ImplRoutines[I]).Locals);
      if Result <> nil then Exit;
    end;
end;

{ the type text of the parameter ArgIdx of a routine whose parameter list Params is (code
  insight's TCIItem.Params) }
function ParamTypeOf(const Params: string; ArgIdx: Integer): string;
var
  L: TList;
begin
  Result := '';
  L := TList.Create;
  try
    ReadParamList(Params, L);
    if (ArgIdx >= 0) and (ArgIdx < L.Count) then Result := TRefParam(L[ArgIdx]).TypeText;
  finally
    FreeObjects(L);
    L.Free;
  end;
end;

function OpPrec(RT: TRawToks; K: Integer): Integer;
begin
  Result := 0;
  if (K < 0) or (K >= RT.N) then Exit;
  with RT.T[K] do
    if Kind = tkSymbol then
      case Symbol of
        syAt: Result := 4;
        syStar, sySlash: Result := 3;
        syPlus, syMinus: Result := 2;
        syEqual, syNotEqual, syLess, syLessEq, syGreater, syGreaterEq: Result := 1;
      end
    else if Kind = tkKeyword then
      case Keyword of
        kwNot: Result := 4;
        kwDiv, kwMod, kwAnd, kwShl, kwShr, kwAs: Result := 3;
        kwOr, kwXor: Result := 2;
        kwIn, kwIs: Result := 1;
      end;
end;

function EndsOperand(RT: TRawToks; K: Integer): Boolean;
begin
  Result := (K >= 0) and ((RT.T[K].Kind in [tkIdent, tkNumber, tkString]) or RT.IsSy(K, syRParen) or
    RT.IsSy(K, syRBracket) or RT.IsSy(K, syCaret) or RT.IsKw(K, kwNil) or RT.IsKw(K, kwString));
end;

function WeakestOp(RT: TRawToks; K0, K1: Integer): Integer;
var
  K, Depth, C: Integer;
begin
  Result := 5;
  Depth := 0;
  for K := K0 to K1 do
    if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then Inc(Depth)
    else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then Dec(Depth)
    else if (Depth = 0) and (OpPrec(RT, K) > 0) then
    begin
      C := OpPrec(RT, K);
      { a sign or not at the start, or after an operator, is unary }
      if (C in [2, 4]) and ((K = K0) or not EndsOperand(RT, K - 1)) then C := 4;
      if C < Result then Result := C;
    end;
end;

function WholeOperand(RT: TRawToks; K0, K1: Integer): Boolean;
var
  E, Before: Integer;
begin
  E := WeakestOp(RT, K0, K1);
  Before := OpPrec(RT, K0 - 1);
  if (Before in [2, 4]) and not EndsOperand(RT, K0 - 2) then Before := 4;     // unary
  Result := (E = 5) or ((Before < E) and (OpPrec(RT, K1 + 1) <= E));
end;

function SameTokens(RT: TRawToks; K, K0, N: Integer): Boolean;
var
  I: Integer;
begin
  Result := (K + N <= RT.N) and (K0 + N <= RT.N);
  I := 0;
  while Result and (I < N) do
  begin
    if (RT.T[K + I].Kind <> RT.T[K0 + I].Kind) or (RT.T[K + I].PLen <> RT.T[K0 + I].PLen) then Result := False
    else if RT.T[K + I].Kind = tkString then
      Result := StrLComp(RT.T[K + I].Ptr, RT.T[K0 + I].Ptr, RT.T[K + I].PLen) = 0
    else
      Result := StrLIComp(RT.T[K + I].Ptr, RT.T[K0 + I].Ptr, RT.T[K + I].PLen) = 0;
    Inc(I);
  end;
end;

function BlockEnd(RT: TRawToks; K: Integer): Integer;
var
  D: Integer;
begin
  D := 0;
  Result := K;
  while Result < RT.N do
  begin
    if RT.T[Result].Kind = tkKeyword then
      case RT.T[Result].Keyword of
        kwBegin, kwTry, kwCase, kwAsm: Inc(D);
        kwEnd:
          begin
            Dec(D);
            if D <= 0 then Exit;
          end;
      end;
    Inc(Result);
  end;
  Result := -1;
end;

procedure BodyRange(const Src: string; RT: TRawToks; RS: TRoutineSym; out A, B: Integer);
var
  E: Integer;
begin
  A := RS.HeadStart;
  E := RT.FirstAt(RS.BodyEnd);
  if RT.IsSy(E, sySemicolon) then B := RT.EndOf(E) else B := RS.BodyEnd;
  if WholeLines(Src, A, B) then A := CommentStart(Src, A);
end;

function MarkerAbove(const Src, ClassName: string; A: Integer): Integer;
var
  B: Integer;
begin
  Result := -1;
  B := CommentStart(Src, A);
  while (B > 0) and IsBlank(Src, PrevLineStart(Src, B), B) do B := PrevLineStart(Src, B);
  if B <= 0 then Exit;
  B := PrevLineStart(Src, B);
  if SameText(Trim(Copy(Src, B + 1, LineEndOf(Src, B) - B)), '{ ' + ClassName + ' }') then Result := B;
end;

function BlankAfter(const Src: string; A, B: Integer): Integer;
begin
  Result := B;
  if (A > 0) and (LineStartOf(Src, A) = A) and IsBlank(Src, PrevLineStart(Src, A), A) and (B < Length(Src)) and
    IsBlank(Src, B, LineEndOf(Src, B)) then
    Result := NextLineStart(Src, B);
end;

function InStatements(U: TUnitInfo; Ofs: Integer): Boolean;
begin
  Result := (BodyAround(U, Ofs, Ofs) <> nil) or ((U.MainBegin > 0) and (Ofs > U.MainBegin)) or
    ((U.InitOfs > 0) and (Ofs > U.InitOfs)) or ((U.FinalOfs > 0) and (Ofs > U.FinalOfs));
end;

{ the expression K0 .. K1 put in the place of the name at token P needs brackets there: its
  weakest operator binds less than the operators beside the place (as strongly, after a - / div mod
  shl shr), or the place heads a chain (.Member, [Index], (Args), ^) }
function NeedsBrackets(RT: TRawToks; K0, K1, P: Integer): Boolean;
var
  E, C, Before: Integer;
begin
  E := WeakestOp(RT, K0, K1);
  if E = 5 then
  begin
    Result := False;
    Exit;
  end;
  if RT.IsSy(P + 1, syDot) or RT.IsSy(P + 1, syLBracket) or RT.IsSy(P + 1, syLParen) or RT.IsSy(P + 1, syCaret) then
  begin
    Result := True;
    Exit;
  end;
  Before := OpPrec(RT, P - 1);
  if (Before in [2, 4]) and not EndsOperand(RT, P - 2) then Before := 4;     // unary
  C := OpPrec(RT, P + 1);
  if Before > C then C := Before;
  Result := (E < C) or ((E = C) and (Before = E) and (RT.IsSy(P - 1, syMinus) or RT.IsSy(P - 1, sySlash) or
    RT.IsKw(P - 1, kwDiv) or RT.IsKw(P - 1, kwMod) or RT.IsKw(P - 1, kwShl) or RT.IsKw(P - 1, kwShr)));
end;

{ the routine (a declaration or an implementation) whose name begins at Ofs; nil: none }
function RoutineNamedAt(U: TUnitInfo; Ofs: Integer): TRoutineSym;

  function InTable(Tab: TSymTable): TRoutineSym;
  var
    I: Integer;
    S: TSymbol;
  begin
    Result := nil;
    if Tab = nil then Exit;
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if (S is TRoutineSym) and (S.DeclStart = Ofs) then
      begin
        Result := TRoutineSym(S);
        Exit;
      end;
      if (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Members <> nil) and (S.TypeDesc.Sym = S) then
      begin
        Result := InTable(S.TypeDesc.Members);
        if Result <> nil then Exit;
      end;
      if (S is TRoutineSym) and (TRoutineSym(S).Locals <> nil) then
      begin
        Result := InTable(TRoutineSym(S).Locals);
        if Result <> nil then Exit;
      end;
    end;
  end;

var
  I: Integer;
  S: TObject;
begin
  Result := InTable(U.IntfSyms);
  if Result = nil then Result := InTable(U.ImplSyms);
  if Result <> nil then Exit;
  for I := 0 to U.ImplRoutines.Count - 1 do
  begin
    S := U.ImplRoutines[I];
    if (S is TRoutineSym) and (TRoutineSym(S).DeclStart = Ofs) then
    begin
      Result := TRoutineSym(S);
      Exit;
    end;
    if (S is TRoutineSym) and (TRoutineSym(S).Locals <> nil) then
    begin
      Result := InTable(TRoutineSym(S).Locals);
      if Result <> nil then Exit;
    end;
  end;
  for I := 0 to U.OwnedExtra.Count - 1 do
  begin
    S := U.OwnedExtra[I];
    if (S is TRoutineSym) and (TRoutineSym(S).DeclStart = Ofs) then
    begin
      Result := TRoutineSym(S);
      Exit;
    end;
  end;
end;

function InList(L: TStrings; const S: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to L.Count - 1 do
    if SameText(ExpandFileName(L[I]), ExpandFileName(S)) then Exit;
  Result := False;
end;

{ ---------------------------------------------------------------------------- }
{ Rename }

function CanRename(const Info: TCISymbolInfo; Files: TStrings): string;
var
  What: string;
begin
  Result := '';
  What := SymbolTitle(Info);
  case Info.Kind of
    ckUnit:
      Result := 'A unit is renamed by saving it under another name (File | Save As)';
    ckUnknown, ckKeyword, ckTemplate:
      Result := Format('%s cannot be renamed', [Info.Name]);
  else
    if Info.FileName = '' then
      Result := Format('%s is the compiler''s own: it cannot be renamed', [Info.Name])
    else if not InList(Files, Info.FileName) then
      Result := Format('%s is declared in %s, which is not part of the project', [What, ExtractFileName(Info.FileName)])
    else if Info.Outside <> '' then
      Result := Format('%s overrides %s, which is not part of the project', [What, Info.Outside]);
  end;
end;

function PlanRename(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places: TList; Files: TStrings;
  const NewName: string; out Error: string): Boolean;
var
  I, DeclOfs: Integer;
  P: TCIPlace;
  U: TUnitInfo;
  S: TSymbol;
  Rou: TRoutineSym;
  What: string;
begin
  Result := False;
  What := SymbolTitle(Info);
  Error := CanRename(Info, Files);
  if Error <> '' then Exit;
  Error := CheckNewName(NewName);
  if Error <> '' then Exit;
  if NewName = Info.Name then
  begin
    Error := 'The new name is the name it has';
    Exit;
  end;
  { a name that is there already, where the symbol is declared }
  if not SameText(NewName, Info.Name) then
  begin
    DeclOfs := -1;
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl and SameText(P.FileName, Info.FileName) and ((DeclOfs < 0) or (P.Start < DeclOfs)) then DeclOfs := P.Start;
    end;
    U := ParseText(CI, Info.FileName, R.Source(Info.FileName));
    try
      if Info.Local and (DeclOfs >= 0) then
      begin
        Rou := RoutineAround(U, DeclOfs, DeclOfs);
        if (Rou <> nil) and RoutineDeclares(Rou, NewName) then
        begin
          Error := Format('%s already declares %s', [Rou.Name, NewName]);
          Exit;
        end;
      end
      else if Info.Owner <> '' then
      begin
        S := U.FindTypeSym(Info.Owner, [tyClass, tyObject, tyRecord, tyInterface]);
        if (S <> nil) and (S.TypeDesc.Members.Find(NewName) <> nil) then
        begin
          Error := Format('%s already has a member named %s', [Info.Owner, NewName]);
          Exit;
        end;
      end
      else if (U.IntfSyms.Find(NewName) <> nil) or (U.ImplSyms.Find(NewName) <> nil) then
      begin
        Error := Format('%s already declares %s', [U.Name, NewName]);
        Exit;
      end;
    finally
      U.Free;
    end;
  end;
  R.Title := Format('Rename %s to %s', [What, NewName]);
  for I := 0 to Places.Count - 1 do
  begin
    P := TCIPlace(Places[I]);
    R.AddEdit(P.FileName, P.Start, P.Len, NewName);
  end;
  if Info.OwnerIsClass and not Info.Local then
    case Info.Kind of
      ckField: R.AddFormRename(rfComponent, Info.Owner, Info.Name, NewName);
      ckProcedure, ckFunction: R.AddFormRename(rfHandler, Info.Owner, Info.Name, NewName);
    end;
  if Info.Kind = ckClass then R.AddFormRename(rfClass, Info.Name, Info.Name, NewName);
  if Info.Overloaded then R.Notes.Add(Format('Every overload of %s is renamed.', [Info.Name]));
  if Info.Hierarchy then R.Notes.Add(Format('The methods that %s overrides and that override it are renamed too.', [Info.Name]));
  Result := True;
end;

function PlanRename(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places, Files: TStrings;
  const NewName: string; out Error: string): Boolean;
var
  L: TList;
  I: Integer;
begin
  L := TList.Create;
  try
    for I := 0 to Places.Count - 1 do L.Add(Places.Objects[I]);
    Result := PlanRename(R, CI, Info, L, Files, NewName, Error);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ form files }

function DfmRename(const Dfm: string; Kind: TRefFormKind; const OldName, NewName, FormName: string;
  Own: Boolean): string;
var
  P, LS, LE, Depth, I, J, Q: Integer;
  Line, T, Word, Name, Cls, Value: string;
  InList: Char;
  Stack: array of Boolean;           // the blocks open: True - inside a frame placed on the form

  function IsValueName(const S: string): Boolean;
  var
    K: Integer;
  begin
    Result := S <> '';
    for K := 1 to Length(S) do
      if not (IdentTab[S[K]] or (S[K] = '.')) then Result := False;
  end;

  procedure Push(Frame: Boolean);
  begin
    SetLength(Stack, Depth + 1);
    Stack[Depth] := Frame or ((Depth > 0) and Stack[Depth - 1]);
    Inc(Depth);
  end;

begin
  Result := '';
  P := 0;
  Depth := 0;
  InList := #0;
  while P < Length(Dfm) do
  begin
    LS := P;
    LE := LineEndOf(Dfm, P);
    P := NextLineStart(Dfm, P);
    if P <= LS then P := Length(Dfm);
    Line := Copy(Dfm, LS + 1, LE - LS);
    T := Trim(Line);
    I := Length(Line) - Length(TrimLeft(Line));         // the indentation
    if InList <> #0 then
    begin
      { a list of strings, a binary property: up to its closing bracket }
      if (T <> '') and (T[Length(T)] = InList) then InList := #0;
    end
    else
    begin
      J := System.Pos(' ', T);
      Word := LowerCase(Copy(T, 1, J - 1));
      if (Word = 'object') or (Word = 'inherited') or (Word = 'inline') then
      begin
        { object Name: TClass [n] }
        Q := System.Pos(':', T);
        if Q > 0 then
        begin
          Name := Trim(Copy(T, J + 1, Q - J - 1));
          Cls := Trim(Copy(T, Q + 1, MaxInt));
          if System.Pos(' ', Cls) > 0 then Cls := Copy(Cls, 1, System.Pos(' ', Cls) - 1);
        end
        else
        begin
          Name := '';
          Cls := Trim(Copy(T, J + 1, MaxInt));
        end;
        case Kind of
          rfComponent:
            if Own and SameText(Name, OldName) and not ((Depth > 0) and Stack[Depth - 1]) and (Depth > 0) then
              Line := Copy(Line, 1, I + J) + NewName + Copy(Line, I + J + Length(Name) + 1, MaxInt);
          rfClass:
            if SameText(Cls, OldName) then
            begin
              Q := I + System.Pos(':', T);
              while (Q < Length(Line)) and (Line[Q + 1] = ' ') do Inc(Q);
              Line := Copy(Line, 1, Q) + NewName + Copy(Line, Q + Length(Cls) + 1, MaxInt);
            end;
        end;
        Push(Word = 'inline');
      end
      else if (T = 'item') then
        Push(False)
      else if (LowerCase(T) = 'end') or (LowerCase(T) = 'end>') then
      begin
        if Depth > 0 then Dec(Depth);
      end
      else
      begin
        Q := System.Pos(' = ', T);
        if Q > 0 then
        begin
          Value := Copy(T, Q + 3, MaxInt);
          if (Value = '(') or (Value = '{') then
          begin
            if Value = '(' then InList := ')' else InList := '}';
          end
          else if Value = '<' then
            { a collection: its items follow as item ... end }
          else if IsValueName(Value) then
          begin
            if Own and (Kind <> rfClass) and SameText(Value, OldName) then
              Line := Copy(Line, 1, I + Q + 2) + NewName + Copy(Line, I + Q + 2 + Length(Value) + 1, MaxInt)
            else if (Kind = rfComponent) and (FormName <> '') and SameText(Value, FormName + '.' + OldName) then
              Line := Copy(Line, 1, I + Q + 2) + FormName + '.' + NewName +
                Copy(Line, I + Q + 2 + Length(Value) + 1, MaxInt);
          end
          else if (Value <> '') and (Value[1] = '<') and (Value[Length(Value)] = '>') then
            { an empty collection }
          else if (Value <> '') and (Value[1] = '(') and (Value[Length(Value)] <> ')') then
            InList := ')'
          else if (Value <> '') and (Value[1] = '{') and (Value[Length(Value)] <> '}') then
            InList := '}';
        end;
      end;
    end;
    Result := Result + Line + Copy(Dfm, LE + 1, P - LE);
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Declare Variable / Field }

function DeclareTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Name, TypeName: string; out InMethod: Boolean; out Error: string): Boolean;
var
  A, E, K, J, NameTok, ArgIdx, X: Integer;
  RT: TRawToks;
  U: TUnitInfo;
  Rou: TRoutineSym;
  Item: TCIItem;
begin
  Result := False;
  Name := '';
  TypeName := '';
  InMethod := False;
  Error := '';
  if not IdentRangeAt(Source, Pos, A, E) then
  begin
    Error := 'Put the caret on the name to declare';
    Exit;
  end;
  Name := Copy(Source, A + 1, E - A);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    K := RT.FirstAt(A);
    if (K >= RT.N) or (RT.T[K].Start <> A) or (RT.T[K].Kind <> tkIdent) then
    begin
      Error := 'Put the caret on the name to declare';
      Exit;
    end;
    if RT.IsSy(K - 1, syDot) then
    begin
      Error := Format('%s is a member of something else: declare it there', [Name]);
      Exit;
    end;
    Rou := BodyAround(U, A, E);
    if Rou = nil then
    begin
      Error := 'Declare Variable and Declare Field work on a name in a routine';
      Exit;
    end;
    InMethod := MethodOf(Rou) <> nil;
    if CI.FindDeclaration(FileName, Source, E, Item) then
    begin
      Error := Format('%s is declared already', [Name]);
      Exit;
    end;
    { the type: of what is assigned to it, of what it is assigned to, of the parameter it is
      passed to; a for loop's variable an Integer }
    if RT.IsSy(K + 1, syAssign) then
    begin
      J := StatementEnd(RT, K + 2);
      if J > K + 2 then TypeName := CI.ExprTypeName(FileName, Source, RT.T[K + 2].Start, RT.EndOf(J - 1));
      if RT.IsKw(K - 1, kwFor) then TypeName := 'Integer';
    end
    else if RT.IsSy(K - 1, syAssign) then
    begin
      J := K - 2;
      while (J > 0) and not BeginsStatement(RT, J - 1) do Dec(J);
      if J >= 0 then TypeName := CI.ExprTypeName(FileName, Source, RT.T[J].Start, RT.EndOf(K - 2));
    end
    else if (RT.IsSy(K - 1, syLParen) or RT.IsSy(K - 1, syComma)) and RT.ArgumentOf(K, NameTok, ArgIdx) then
    begin
      X := RT.EndOf(NameTok);
      if CI.FindDeclaration(FileName, Source, X, Item) and (Item.Params <> '') then
        TypeName := ParamTypeOf(Item.Params, ArgIdx);
    end;
    Result := True;
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanDeclareVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name, TypeName: string; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  Rou: TRoutineSym;
begin
  Result := False;
  Error := CheckDeclaration(Name, TypeName);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    Rou := BodyAround(U, Pos, Pos);
    if Rou = nil then
    begin
      Error := 'Declare Variable works on a name in a routine';
      Exit;
    end;
    if RoutineDeclares(Rou, Name) then
    begin
      Error := Format('%s already declares %s', [Rou.Name, Name]);
      Exit;
    end;
    R.Title := Format('Declare variable %s: %s', [Name, Trim(TypeName)]);
    Result := AddLocalDecl(R, FileName, Source, RT, Rou, kwVar, Name + ': ' + Trim(TypeName) + ';');
    if not Result then Error := 'Could not find where to declare the variable';
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanDeclareField(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name, TypeName: string; Access: Integer; out Error: string): Boolean;
var
  U: TUnitInfo;
  Rou, M: TRoutineSym;
  S: TSymbol;
  Start: Integer;
  Text: string;
begin
  Result := False;
  Error := CheckDeclaration(Name, TypeName);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  U := ParseText(CI, FileName, Source);
  try
    Rou := BodyAround(U, Pos, Pos);
    if Rou <> nil then M := MethodOf(Rou) else M := nil;
    if M = nil then
    begin
      Error := 'Declare Field works on a name in a method of a class';
      Exit;
    end;
    S := U.FindTypeSym(M.ClassQual, [tyClass, tyObject, tyRecord]);
    if S = nil then
    begin
      Error := Format('%s is not declared in this unit', [M.ClassQual]);
      Exit;
    end;
    if S.TypeDesc.Members.Find(Name) <> nil then
    begin
      Error := Format('%s already has a member named %s', [M.ClassQual, Name]);
      Exit;
    end;
    if not ExplorerMemberEdit(U, M.ClassQual, Access, True, '    ' + Name + ': ' + Trim(TypeName) + ';', Start, Text, Error) then
      Exit;
    R.Title := Format('Declare field %s.%s: %s', [M.ClassQual, Name, Trim(TypeName)]);
    Result := R.AddEdit(FileName, Start, 0, Text) <> nil;
  finally
    U.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Find Unit }

function FindUnitTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer; out Name: string;
  Units: TStrings; out InImpl: Boolean; out Error: string): Boolean;
var
  A, E, I: Integer;
  U: TUnitInfo;
  N: string;
begin
  Result := False;
  Error := '';
  Name := '';
  InImpl := False;
  Units.Clear;
  if not IdentRangeAt(Source, Pos, A, E) then
  begin
    Error := 'Put the caret on the name whose unit to find';
    Exit;
  end;
  Name := Copy(Source, A + 1, E - A);
  CI.UnitsDeclaring(Name, FileName, Units);
  U := ParseText(CI, FileName, Source);
  try
    { the name in the implementation: its uses clause; in the interface (a program has one) the
      interface's }
    InImpl := not U.IsProgram and (Pos >= U.ImplOfs);
    for I := Units.Count - 1 downto 0 do
    begin
      N := Units.Names[I];
      if (U.IntfUses.IndexOf(N) >= 0) or (U.ImplUses.IndexOf(N) >= 0) or SameText(N, U.Name) then Units.Delete(I);
    end;
  finally
    U.Free;
  end;
  if Units.Count = 0 then
  begin
    Error := Format('No unit on the search path that this unit does not use declares %s', [Name]);
    Exit;
  end;
  Result := True;
end;

function PlanAddUses(R: TRefactoring; CI: TCodeInsight; const FileName, Source, UnitName: string;
  InImpl: Boolean; out Error: string): Boolean;
var
  U: TUnitInfo;
  RT: TRawToks;
  Names: TStringList;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  U := ParseText(CI, FileName, Source);
  RT := TRawToks.Create(Source, False);
  Names := TStringList.Create;
  try
    if (U.IntfUses.IndexOf(UnitName) >= 0) or (U.ImplUses.IndexOf(UnitName) >= 0) then
    begin
      Error := Format('%s uses %s already', [U.Name, UnitName]);
      Exit;
    end;
    R.Title := Format('Add %s to the uses clause', [UnitName]);
    Names.Add(UnitName);
    Result := AddUsesNames(R, FileName, Source, RT, U, Names, InImpl);
    if not Result then Error := 'Could not find where to add the uses clause';
  finally
    Names.Free;
    RT.Free;
    U.Free;
  end;
end;

function AddUsesNames(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo; Names: TStrings;
  InImpl: Boolean): Boolean;
var
  P, K: Integer;
  EOL: string;

  { the names from column C on, each after ", " - after "," and a line break where the line would
    grow past column 75 -; From 1: the first one alone }
  function Joined(C, From: Integer): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to Names.Count - 1 do
      if I < From then
      begin
        Result := Names[I];
        Inc(C, Length(Names[I]));
      end
      else if C + Length(', ' + Names[I]) > WrapColumn then
      begin
        Result := Result + ',' + EOL + '  ' + Names[I];
        C := 2 + Length(Names[I]);
      end
      else
      begin
        Result := Result + ', ' + Names[I];
        Inc(C, 2 + Length(Names[I]));
      end;
  end;

begin
  Result := False;
  if Names.Count = 0 then Exit;
  EOL := DetectEOL(Src);
  if U.IsProgram then InImpl := False;
  if InImpl then P := U.ImplUsesEnd else P := U.IntfUsesEnd;
  if P > 0 then
  begin
    { before the clause's ";" }
    Result := R.AddEdit(FileName, P, 0, Joined(P - LineStartOf(Src, P), 0)) <> nil;
    Exit;
  end;
  { a clause of its own: after the section's word, or after a program's heading }
  if U.IsProgram then
  begin
    K := 0;
    while (K < RT.N) and not RT.IsSy(K, sySemicolon) do Inc(K);
    if K >= RT.N then Exit;
    P := RT.T[K].Start + 1;
  end
  else
  begin
    if InImpl then K := RT.FirstAt(U.ImplOfs) else K := RT.FirstAt(U.IntfOfs);
    if (K >= RT.N) or not (RT.IsKw(K, kwImplementation) or RT.IsKw(K, kwInterface)) then Exit;
    P := RT.EndOf(K);
  end;
  Result := R.AddEdit(FileName, P, 0, EOL + EOL + 'uses' + EOL + '  ' + Joined(2, 1) + ';') <> nil;
end;

{ ---------------------------------------------------------------------------- }
{ Extract Resource String }

{ the string literal at Pos - adjoining string and character tokens: 'a'#13'b' -: its tokens }
function LiteralAt(RT: TRawToks; Pos: Integer; out K0, K1: Integer): Boolean;
var
  K: Integer;
begin
  Result := False;
  K := RT.FirstAt(Pos);
  if (K >= RT.N) or (RT.T[K].Start > Pos) then Dec(K);
  if (K < RT.N) and (K > 0) and (RT.T[K].Start = Pos) and (RT.T[K].Kind <> tkString) then Dec(K);
  if (K < 0) or (K >= RT.N) or (RT.T[K].Kind <> tkString) or (Pos > RT.EndOf(K)) then Exit;
  K0 := K;
  while (K0 > 0) and (RT.T[K0 - 1].Kind = tkString) and (RT.EndOf(K0 - 1) = RT.T[K0].Start) do
    Dec(K0);
  K1 := K;
  while (K1 + 1 < RT.N) and (RT.T[K1 + 1].Kind = tkString) and (RT.EndOf(K1) = RT.T[K1 + 1].Start) do
    Inc(K1);
  Result := True;
end;

{ a name for a string: Str and its words ('Cannot open %s' - StrCannotOpenS) }
function NameForString(const Literal: string): string;
var
  I: Integer;
  InQuote, Up: Boolean;
  C: Char;
begin
  Result := 'Str';
  InQuote := False;
  Up := True;
  I := 1;
  while I <= Length(Literal) do
  begin
    C := Literal[I];
    if C = '''' then
    begin
      if InQuote and (I < Length(Literal)) and (Literal[I + 1] = '''') then
      begin
        Inc(I, 2);
        Up := True;
        Continue;
      end;
      InQuote := not InQuote;
    end
    else if InQuote and (C in ['A'..'Z', 'a'..'z', '0'..'9']) then
    begin
      if Length(Result) < 32 then
        if Up then Result := Result + UpCase(C) else Result := Result + C;
      Up := False;
    end
    else
      Up := True;
    Inc(I);
  end;
  if Result = 'Str' then Result := 'StrText';
end;

function ResStringTarget(CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Literal, Name: string; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1: Integer;
begin
  Result := False;
  Error := '';
  Literal := '';
  Name := '';
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    if not LiteralAt(RT, Pos, K0, K1) then
    begin
      Error := 'Put the caret on a string';
      Exit;
    end;
    if not InStatements(U, RT.T[K0].Start) then
    begin
      Error := 'Extract Resource String works on a string in a routine';
      Exit;
    end;
    Literal := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    Name := NameForString(Literal);
    Result := True;
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanExtractResString(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  const Name: string; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1: Integer;
  Literal: string;
begin
  Result := False;
  Error := CheckNewName(Name);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    if not LiteralAt(RT, Pos, K0, K1) then
    begin
      Error := 'Put the caret on a string';
      Exit;
    end;
    if (U.IntfSyms.Find(Name) <> nil) or (U.ImplSyms.Find(Name) <> nil) then
    begin
      Error := Format('%s already declares %s', [U.Name, Name]);
      Exit;
    end;
    Literal := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    R.Title := Format('Extract resource string %s = %s', [Name, Literal]);
    Result := AddSectionDecl(R, FileName, Source, RT, U, kwResourcestring, False, False, Name + ' = ' + Literal + ';') and
      (R.AddEdit(FileName, RT.T[K0].Start, RT.EndOf(K1) - RT.T[K0].Start, Name) <> nil);
    if not Result then Error := 'Could not find where to declare the string';
  finally
    U.Free;
    RT.Free;
  end;
end;

function AddSectionDecl(R: TRefactoring; const FileName, Src: string; RT: TRawToks; U: TUnitInfo;
  Section: TKeyword; InIntf, AtEnd: Boolean; const Decl: string): Boolean;
var
  K, K0, J, Lim, From, LastSec, Semi, P, I, Depth, Nest, Prev, First: Integer;
  EOL, Word, Ind: string;
  Other: Boolean;
  L: TPasLexer;
begin
  Result := False;
  EOL := DetectEOL(Src);
  Word := KeywordNames[Section];
  if U.IsProgram then InIntf := False;
  { the part's declarations: the interface's up to the implementation; the implementation's (a
    program's: after its uses clause) up to its first routine }
  if InIntf then
  begin
    K0 := RT.FirstAt(U.IntfOfs);
    if (K0 >= RT.N) or not RT.IsKw(K0, kwInterface) then Exit;
    Inc(K0);
    Lim := U.ImplOfs;
    if Lim > Length(Src) then Lim := Length(Src);
  end
  else
  begin
    if U.IsProgram then From := U.IntfUsesEnd else From := U.ImplOfs;
    if From < 0 then From := 0;
    K0 := RT.FirstAt(From);
    Lim := Length(Src);
    for I := 0 to U.ImplRoutines.Count - 1 do
      if TRoutineSym(U.ImplRoutines[I]).HeadStart < Lim then Lim := TRoutineSym(U.ImplRoutines[I]).HeadStart;
    if (U.InitOfs > 0) and (U.InitOfs < Lim) then Lim := U.InitOfs;
    if (U.MainBegin > 0) and (U.MainBegin < Lim) then Lim := U.MainBegin;
    if (U.FinalEndOfs > 0) and (U.FinalEndOfs < Lim) then Lim := U.FinalEndOfs;
  end;
  { the sections of the part: the last one of the kind, its last declaration's ";" (not one inside
    a record, a class, brackets); Other - another section or a routine after it }
  LastSec := -1;
  Semi := -1;
  Prev := -1;
  First := -1;
  Depth := 0;
  Nest := 0;
  Other := False;
  for K := K0 to RT.N - 1 do
  begin
    if RT.T[K].Start >= Lim then Break;
    if RT.T[K].Kind = tkKeyword then
      case RT.T[K].Keyword of
        kwRecord, kwObject:
          Inc(Nest);
        kwClass, kwInterface, kwDispinterface:
          begin
            { a body - not a forward declaration, a class reference, a class method, class(Ancestor); }
            J := K + 1;
            if RT.IsSy(J, syLParen) then
            begin
              J := RT.MatchClose(J);
              if J < 0 then J := RT.N else Inc(J);
            end;
            if (J < RT.N) and not (RT.IsSy(J, sySemicolon) or ((RT.T[J].Kind = tkKeyword) and
              (RT.T[J].Keyword in [kwOf, kwProcedure, kwFunction, kwConstructor, kwDestructor]))) then
              Inc(Nest);
          end;
        kwEnd:
          if Nest > 0 then Dec(Nest);
        kwVar, kwConst, kwType, kwResourcestring, kwThreadvar, kwLabel, kwProcedure, kwFunction, kwConstructor,
        kwDestructor, kwExports, kwBegin:
          if (Nest = 0) and (Depth = 0) then
            if RT.T[K].Keyword = Section then
            begin
              LastSec := K;
              Prev := K;
              Other := False;
            end
            else if LastSec >= 0 then
              Other := True;
      end
    else if RT.IsSy(K, syLParen) or RT.IsSy(K, syLBracket) then
      Inc(Depth)
    else if RT.IsSy(K, syRParen) or RT.IsSy(K, syRBracket) then
      Dec(Depth)
    else if (LastSec >= 0) and not Other and (Depth = 0) and (Nest = 0) and RT.IsSy(K, sySemicolon) then
    begin
      Semi := K;
      First := Prev + 1;
      Prev := K;
    end;
  end;
  if (Semi >= 0) and not (AtEnd and Other) then
  begin
    { after the last declaration of the section, indented as it is }
    Ind := IndentAt(Src, RT.T[First].Start);
    if not FirstOnLine(Src, RT.T[First].Start) then Ind := IndentAt(Src, RT.T[LastSec].Start) + '  ';
    Result := R.AddEdit(FileName, LineEndOf(Src, RT.T[Semi].Start), 0, EOL + Ind + Decl) <> nil;
    Exit;
  end;
  if AtEnd then
  begin
    { a section of its own at the part's end: before the implementation's word, before the first
      routine and the comment lines above it }
    if InIntf then P := LineStartOf(Src, U.ImplOfs) else P := CommentStart(Src, Lim);
    Result := R.AddEdit(FileName, P, 0, Word + EOL + '  ' + Decl + EOL + EOL) <> nil;
    Exit;
  end;
  { a section of its own after the part's word or its uses clause, and the directives after them ($R) }
  if InIntf then
  begin
    if U.IntfUsesEnd > 0 then P := U.IntfUsesEnd + 1 else P := RT.EndOf(K0 - 1);
  end
  else if U.IsProgram then
  begin
    P := U.IntfUsesEnd + 1;
    if U.IntfUsesEnd <= 0 then
    begin
      K := 0;
      while (K < RT.N) and not RT.IsSy(K, sySemicolon) do Inc(K);
      if K < RT.N then P := RT.T[K].Start + 1 else P := 0;
    end;
  end
  else if U.ImplUsesEnd > 0 then
    P := U.ImplUsesEnd + 1
  else
  begin
    K := RT.FirstAt(U.ImplOfs);
    if (K >= RT.N) or not RT.IsKw(K, kwImplementation) then Exit;
    P := RT.EndOf(K);
  end;
  L := TPasLexer.Create(Src, P, Lim);
  try
    L.ReturnComments := True;
    L.Next;
    while (L.Tok.Kind = tkComment) and (L.Tok.PLen > 2) and (L.Tok.Ptr[0] = '{') and (L.Tok.Ptr[1] = '$') do
    begin
      P := L.Tok.Start + L.Tok.Len;
      L.Next;
    end;
  finally
    L.Free;
  end;
  Result := R.AddEdit(FileName, LineEndOf(Src, P), 0, EOL + EOL + Word + EOL + '  ' + Decl) <> nil;
end;

{ ---------------------------------------------------------------------------- }
{ Change Parameters }

{ the parameters of the heading whose name token is K: TRefParam into Params; False - no list
  (Open: the "(" token, -1 none) }
procedure HeadingParams(RT: TRawToks; const Src: string; K: Integer; Params: TList; out Open, Close: Integer);
begin
  Open := -1;
  Close := -1;
  if not RT.IsSy(K + 1, syLParen) then Exit;
  Open := K + 1;
  Close := RT.MatchClose(Open);
  if Close < 0 then Exit;
  if Params <> nil then ReadParamList(Copy(Src, RT.T[Open].Start + 2, RT.T[Close].Start - RT.T[Open].Start - 1), Params);
end;

function IsRoutineKind(K: TCIKind): Boolean;
begin
  Result := K in [ckProcedure, ckFunction, ckConstructor, ckDestructor];
end;

function ChangeParamsTarget(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  Files: TStrings; out Info: TCISymbolInfo; Places, Params: TList; out ResultType, Head: string;
  out Error: string): Boolean;
const
  Words: array[ckProcedure..ckDestructor] of string = ('procedure', 'function', 'constructor', 'destructor');
var
  I, K, J, E, Open, Close: Integer;
  P: TCIPlace;
  Src: string;
  RT: TRawToks;
  U: TUnitInfo;
  RS: TRoutineSym;
  Found: Boolean;
begin
  Result := False;
  Error := '';
  ResultType := '';
  Head := '';
  R.SetSource(FileName, Source);
  if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) then
  begin
    Error := 'Put the caret on the name of a routine';
    Exit;
  end;
  if not IsRoutineKind(Info.Kind) then
  begin
    Error := Format('%s is not a routine', [Info.Name]);
    Exit;
  end;
  if Info.Overloaded then
  begin
    Error := Format('%s is overloaded: change the parameters of each overload by hand', [Info.Name]);
    Exit;
  end;
  if (Info.FileName = '') or not InList(Files, Info.FileName) then
  begin
    Error := Format('%s is not declared in the project', [Info.Name]);
    Exit;
  end;
  if Info.Outside <> '' then
  begin
    Error := Format('%s overrides %s, which is not part of the project', [Info.Name, Info.Outside]);
    Exit;
  end;
  { the parameters and the result of its declaration (an implementation's when it has none other) }
  Found := False;
  for J := 0 to 1 do
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if Found or not P.Decl then Continue;
      Src := R.Source(P.FileName);
      RT := TRawToks.Create(Src, False);
      U := ParseText(CI, P.FileName, Src);
      try
        K := RT.FirstAt(P.Start);
        if (K >= RT.N) or (RT.T[K].Start <> P.Start) then Continue;
        RS := RoutineNamedAt(U, P.Start);
        if (J = 0) and (((RS <> nil) and (sfImplBody in RS.Flags)) or RT.IsSy(K - 1, syDot)) then Continue;
        HeadingParams(RT, Src, K, Params, Open, Close);
        if Close >= 0 then K := Close;
        if RT.IsSy(K + 1, syColon) then
        begin
          E := StatementEnd(RT, K + 2);
          ResultType := Trim(Copy(Src, RT.T[K + 2].Start + 1, RT.EndOf(E - 1) - RT.T[K + 2].Start));
        end;
        Found := True;
      finally
        U.Free;
        RT.Free;
      end;
    end;
  if not Found then
  begin
    Error := Format('The declaration of %s is not found', [Info.Name]);
    Exit;
  end;
  Head := Words[Info.Kind] + ' ' + SymbolTitle(Info);
  Result := True;
end;
function PlanChangeParams(R: TRefactoring; CI: TCodeInsight; const Info: TCISymbolInfo; Places, NewParams: TList;
  out Error: string): Boolean;
var
  I, K, J, Open, Close, M, N, A: Integer;
  P: TCIPlace;
  Src, Text, Old, Value: string;
  RT: TRawToks;
  U: TUnitInfo;
  RS: TRoutineSym;
  OldParams, Args: TList;
  Vals: TStringList;
  Omit: array of Boolean;
  IsImpl: Boolean;
  NP: TRefParam;
  Field: TRefParamField;
  Files: TStringList;

begin
  Result := False;
  Error := CheckParamList(NewParams, I, Field);
  if Error <> '' then Exit;
  R.Title := Format('Change the parameters of %s', [Info.Name]);
  OldParams := TList.Create;
  Args := TList.Create;
  Vals := TStringList.Create;
  Files := TStringList.Create;
  try
    for I := 0 to Places.Count - 1 do
      if Files.IndexOf(TCIPlace(Places[I]).FileName) < 0 then Files.Add(TCIPlace(Places[I]).FileName);
    { the parameters before: of the first declaration }
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if not P.Decl then Continue;
      Src := R.Source(P.FileName);
      RT := TRawToks.Create(Src, False);
      try
        K := RT.FirstAt(P.Start);
        HeadingParams(RT, Src, K, OldParams, Open, Close);
      finally
        RT.Free;
      end;
      if Open >= 0 then Break;
    end;
    for J := 0 to Files.Count - 1 do
    begin
      Src := R.Source(Files[J]);
      RT := TRawToks.Create(Src, False);
      U := ParseText(CI, Files[J], Src);
      try
        for I := 0 to Places.Count - 1 do
        begin
          P := TCIPlace(Places[I]);
          if not SameText(P.FileName, Files[J]) then Continue;
          K := RT.FirstAt(P.Start);
          if (K >= RT.N) or (RT.T[K].Start <> P.Start) then Continue;
          if P.Decl then
          begin
            { a heading: its list written again (an implementation without one keeps none) }
            RS := RoutineNamedAt(U, P.Start);
            IsImpl := ((RS <> nil) and (sfImplBody in RS.Flags)) or RT.IsSy(K - 1, syDot);
            HeadingParams(RT, Src, K, nil, Open, Close);
            if Open >= 0 then
            begin
              if NewParams.Count = 0 then Text := '' else Text := '(' + ParamListText(NewParams, not IsImpl) + ')';
              R.AddEdit(P.FileName, RT.T[Open].Start, RT.T[Close].Start + 1 - RT.T[Open].Start, Text);
            end
            else if (NewParams.Count > 0) and not (IsImpl and (RS <> nil) and (RS.ParamsStart <= 0) and
              (OldParams.Count > 0)) then
              R.AddEdit(P.FileName, RT.EndOf(K), 0, '(' + ParamListText(NewParams, not IsImpl) + ')');
            Continue;
          end;
          { a call }
          if RT.IsSy(K - 1, syAt) then
          begin
            R.Notes.Add(Format('%s(%d): the address of %s is taken there; that line is not changed.',
              [ExtractFileName(P.FileName), P.Line, Info.Name]));
            Continue;
          end;
          Vals.Clear;
          if RT.IsSy(K + 1, syLParen) then
          begin
            Open := K + 1;
            Close := RT.MatchClose(Open);
            if Close < 0 then Continue;
            { the arguments as written }
            A := Open + 1;
            M := 0;
            for N := Open + 1 to Close do
            begin
              if RT.IsSy(N, syLParen) or RT.IsSy(N, syLBracket) then Inc(M)
              else if (M > 0) and (RT.IsSy(N, syRParen) or RT.IsSy(N, syRBracket)) and (N < Close) then Dec(M)
              else if ((M = 0) and RT.IsSy(N, syComma)) or (N = Close) then
              begin
                if N > A then Vals.Add(Trim(Copy(Src, RT.T[A].Start + 1, RT.T[N].Start - RT.T[A].Start)));
                A := N + 1;
              end;
            end;
          end
          else
          begin
            Open := -1;
            Close := -1;
            if (Info.Kind = ckProcedure) and (RT.IsSy(K - 1, syAssign) or RT.IsSy(K - 1, syComma) or
              RT.IsSy(K - 1, syLParen)) then
            begin
              R.Notes.Add(Format('%s(%d): %s is used as a method or procedure pointer there; that line is not changed.',
                [ExtractFileName(P.FileName), P.Line, Info.Name]));
              Continue;
            end;
          end;
          { the new arguments: the old ones moved, the new ones' values, defaults left out at the end }
          SetLength(Omit, NewParams.Count);
          Text := '';
          Args.Clear;
          for N := 0 to NewParams.Count - 1 do
          begin
            NP := TRefParam(NewParams[N]);
            Omit[N] := False;
            if (NP.OldIndex >= 0) and (NP.OldIndex < Vals.Count) then
              Value := Vals[NP.OldIndex]
            else if NP.OldIndex >= 0 then
            begin
              { left out at this call: its default }
              Value := '';
              if NP.OldIndex < OldParams.Count then Value := TRefParam(OldParams[NP.OldIndex]).Default;
              Omit[N] := NP.Default <> '';
              if Value = '' then Value := NP.Default;
            end
            else
            begin
              Value := NP.CallValue;
              if Value = '' then
              begin
                Value := NP.Default;
                Omit[N] := True;
              end;
            end;
            if Value = '' then
            begin
              Error := Format('%s(%d): no value for %s', [ExtractFileName(P.FileName), P.Line, NP.Name]);
              Exit;
            end;
            Args.Add(Pointer(N));
            Vals.Add(Value);
          end;
          N := NewParams.Count - 1;
          while (N >= 0) and Omit[N] do Dec(N);
          Old := '';
          for M := 0 to N do
          begin
            if M > 0 then Old := Old + ', ';
            Old := Old + Vals[Vals.Count - NewParams.Count + M];
          end;
          if Old <> '' then Old := '(' + Old + ')';
          if Open >= 0 then
            R.AddEdit(P.FileName, RT.T[Open].Start, RT.T[Close].Start + 1 - RT.T[Open].Start, Old)
          else if Old <> '' then
            R.AddEdit(P.FileName, RT.EndOf(K), 0, Old);
        end;
      finally
        U.Free;
        RT.Free;
      end;
    end;
    if Info.OwnerIsClass and (Info.Visibility = cvPublished) then
      R.Notes.Add(Format('%s is published: if it is a form''s event handler, its parameters must be the event''s.', [Info.Name]));
    if Info.Hierarchy then R.Notes.Add(Format('The methods that %s overrides and that override it change too.', [Info.Name]));
    Result := True;
  finally
    FreeObjects(OldParams);
    OldParams.Free;
    Args.Free;
    Vals.Free;
    Files.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Extract Method, Introduce Variable, Inline Variable: the statements of a selection }

type
  { a local variable or parameter the extracted statements use }
  TExtractVar = class
  public
    Key, Name, TypeText, Modifier: string;
    IsParam, ReadFirst, Written, Before, After: Boolean;
  end;

const
  { the parameter the function's Result becomes when it is passed in }
  ResultParam = 'AResult';

{ the result type of the function whose Result the statements of R name - R's, else the one R is
  nested in -, as its heading or its declaration writes it ('': none known) }
function ResultTypeOf(U: TUnitInfo; R: TRoutineSym): string;
var
  F: TRoutineSym;
  S: TSymbol;
  L: TList;
  Tab: TSymTable;
begin
  Result := '';
  F := R;
  while (F <> nil) and not (sfFunction in F.Flags) do F := OuterOf(F);
  if F = nil then Exit;
  if F.TypeEnd > F.TypeStart then
  begin
    Result := Trim(Copy(U.Source, F.TypeStart + 1, F.TypeEnd - F.TypeStart));
    Exit;
  end;
  { an implementation that does not repeat its heading: its declaration's }
  Tab := nil;
  if F.ClassQual <> '' then
  begin
    S := U.FindTypeSym(F.ClassQual, [tyClass, tyObject, tyRecord]);
    if S <> nil then Tab := S.TypeDesc.Members;
  end
  else
    Tab := U.IntfSyms;
  if Tab = nil then Exit;
  L := TList.Create;
  try
    AddRoutines(Tab, F.Name, [], [], L);
    S := PairRoutine(F, L);
    if (S <> nil) and (S.TypeEnd > S.TypeStart) then Result := Trim(Copy(U.Source, S.TypeStart + 1, S.TypeEnd - S.TypeStart));
  finally
    L.Free;
  end;
end;

{ the tokens of A .. B (whole tokens; a ";" right after them taken in) }
function SelTokens(RT: TRawToks; A, B: Integer; out K0, K1: Integer): Boolean;
begin
  K0 := RT.FirstAt(A);
  K1 := K0 - 1;
  while (K1 + 1 < RT.N) and (RT.EndOf(K1 + 1) <= B) do Inc(K1);
  Result := K0 <= K1;
end;

{ the statement whose head is the token W (with, for, while, on ... do; repeat): its last token }
function ScopeEnd(RT: TRawToks; W: Integer): Integer;
var
  D, Depth: Integer;
begin
  Result := RT.N - 1;
  if RT.IsKw(W, kwRepeat) then
  begin
    Depth := 0;
    for D := W to RT.N - 1 do
      if RT.IsKw(D, kwRepeat) then Inc(Depth)
      else if RT.IsKw(D, kwUntil) then
      begin
        Dec(Depth);
        if Depth = 0 then
        begin
          Result := StatementEnd(RT, D) - 1;
          Exit;
        end;
      end;
    Exit;
  end;
  D := W;
  while (D < RT.N) and not RT.IsKw(D, kwDo) do Inc(D);
  if D >= RT.N then Exit;
  Result := StatementEnd(RT, D + 1) - 1;
end;

function ExtractCheck(CI: TCodeInsight; const Source: string; RT: TRawToks; U: TUnitInfo; A, B: Integer;
  out K0, K1: Integer; out Rou: TRoutineSym; out InLoop: Boolean; out Error: string): Boolean;
var
  K, Loops, Depth: Integer;
  Stack: string;
  Single: Boolean;
  W: string;
begin
  Result := False;
  InLoop := False;
  Rou := nil;
  if not SelTokens(RT, A, B, K0, K1) then
  begin
    Error := 'Select the statements to extract';
    Exit;
  end;
  if RT.IsSy(K1 + 1, sySemicolon) then Inc(K1);
  Rou := BodyAround(U, RT.T[K0].Start, RT.EndOf(K1));
  if (Rou = nil) or (RT.EndOf(K1) > Rou.BodyEnd - 3) then
  begin
    Error := 'Select statements of a routine';
    Exit;
  end;
  { whole statements: after a statement's start, before a statement's end }
  if not BeginsStatement(RT, K0 - 1) then
  begin
    Error := 'The selection does not begin with a statement';
    Exit;
  end;
  if not (RT.IsSy(K1, sySemicolon) or RT.IsSy(K1 + 1, sySemicolon) or
    ((RT.T[K1 + 1].Kind = tkKeyword) and (RT.T[K1 + 1].Keyword in [kwEnd, kwUntil, kwFinally, kwExcept, kwElse]))) then
  begin
    Error := 'The selection does not end with a statement';
    Exit;
  end;
  Stack := '';
  Loops := 0;
  Depth := 0;
  Single := True;
  for K := K0 to K1 do
  begin
    with RT.T[K] do
      if Kind = tkKeyword then
        case Keyword of
          kwBegin, kwTry, kwCase, kwAsm: Stack := Stack + 'b';
          kwRepeat:
            begin
              Stack := Stack + 'r';
              Inc(Loops);
            end;
          kwEnd:
            begin
              { an except part ends with its try's end }
              while (Stack <> '') and (Stack[Length(Stack)] = 'x') do Delete(Stack, Length(Stack), 1);
              if (Stack = '') or (Stack[Length(Stack)] <> 'b') then
              begin
                Error := 'The selection is not whole statements';
                Exit;
              end;
              Delete(Stack, Length(Stack), 1);
            end;
          kwUntil:
            begin
              if (Stack = '') or (Stack[Length(Stack)] <> 'r') then
              begin
                Error := 'The selection is not whole statements';
                Exit;
              end;
              Delete(Stack, Length(Stack), 1);
            end;
          kwFor, kwWhile: Inc(Loops);
          kwGoto, kwLabel:
            begin
              Error := 'The selection has a goto or a label';
              Exit;
            end;
          kwInherited:
            if RT.T[K + 1].Kind <> tkIdent then
            begin
              Error := 'The selection calls inherited without a name';
              Exit;
            end;
          kwRaise:
            if RT.IsSy(K + 1, sySemicolon) and (System.Pos('x', Stack) = 0) then
            begin
              Error := 'The selection raises the exception again outside its handler';
              Exit;
            end;
          kwExcept:
            Stack := Stack + 'x';
        end
      else if Kind = tkSymbol then
      begin
        if Symbol in [syLParen, syLBracket] then Inc(Depth)
        else if Symbol in [syRParen, syRBracket] then Dec(Depth)
        else if (Symbol = sySemicolon) and (Stack = '') and (Depth = 0) and (K < K1) then Single := False;
      end
      else if (Kind = tkIdent) and not RT.IsSy(K - 1, syDot) then
      begin
        SetString(W, Ptr, PLen);
        if SameText(W, 'Exit') then
        begin
          Error := 'The selection leaves the routine (Exit)';
          Exit;
        end;
        if (SameText(W, 'Break') or SameText(W, 'Continue')) and (Loops = 0) then
        begin
          Error := Format('The selection has a %s of a loop around it', [W]);
          Exit;
        end;
      end;
  end;

  { the x marks: drop them for the balance }
  while System.Pos('x', Stack) > 0 do Delete(Stack, System.Pos('x', Stack), 1);
  if (Stack <> '') or (Depth <> 0) then
  begin
    Error := 'The selection is not whole statements';
    Exit;
  end;
  { the statement of a then, else, do: the selection must be one statement }
  if not Single and not (RT.IsSy(K0 - 1, sySemicolon) or ((RT.T[K0 - 1].Kind = tkKeyword) and
    (RT.T[K0 - 1].Keyword in [kwBegin, kwTry, kwFinally, kwExcept, kwRepeat]))) then
  begin
    Error := 'The selection is more than the one statement of a then, else or do';
    Exit;
  end;
  { a with around the selection: its names would lose their object }
  for K := RT.FirstAt(Rou.BodyStart) to K0 - 1 do
    if RT.IsKw(K, kwWith) and (ScopeEnd(RT, K) >= K1) then
    begin
      Error := 'The selection is inside a with statement';
      Exit;
    end
    else if ((RT.T[K].Kind = tkKeyword) and (RT.T[K].Keyword in [kwFor, kwWhile, kwRepeat])) and
      (ScopeEnd(RT, K) >= K1) then
      InLoop := True;
  Result := True;
end;

function ExtractTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out ClassName: string; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1: Integer;
  Rou, M: TRoutineSym;
  InLoop: Boolean;
begin
  ClassName := '';
  Error := '';
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    Result := ExtractCheck(CI, Source, RT, U, A, B, K0, K1, Rou, InLoop, Error);
    if Result then
    begin
      M := MethodOf(Rou);
      if M <> nil then ClassName := M.ClassQual;
    end;
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanExtractMethod(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name: string; Access: Integer; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1, I, J, A2, B2, Start, Mins, Ind, P: Integer;
  Rou, M, Top: TRoutineSym;
  InLoop, Lines, RenameResult: Boolean;
  Sel, Bef, Aft: TList;
  Vars: TStringList;
  V, ResultVar: TExtractVar;
  NU: TCINameUse;
  EOL, ParamList, ArgList, LocalList, Kw, Prefix, Heading, Body, Call, Text, Line, ResType, ClassName: string;
  SL: TStringList;


  { the name declares its variable (its own place in the var section) }
  function OwnDecl(NU: TCINameUse): Boolean;
  begin
    Result := KeyOffset(NU.Key) = NU.Start;
  end;

  function VarOf(const Key: string): TExtractVar;
  var
    X: Integer;
  begin
    X := Vars.IndexOf(Key);
    if X >= 0 then Result := TExtractVar(Vars.Objects[X]) else Result := nil;
  end;

  { the text of P0 .. P1 for the new routine: the function's Result named ResultParam there when it
    is passed in }
  function Region(P0, P1: Integer): string;
  var
    X: Integer;
    U2: TCINameUse;
  begin
    Result := Copy(Source, P0 + 1, P1 - P0);
    if not RenameResult then Exit;
    for X := Sel.Count - 1 downto 0 do
    begin
      U2 := TCINameUse(Sel[X]);
      if (U2.Key = 'RESULT') and (U2.Start >= P0) and (U2.Start + U2.Len <= P1) then
        Result := Copy(Result, 1, U2.Start - P0) + ResultParam + Copy(Result, U2.Start - P0 + U2.Len + 1, MaxInt);
    end;
  end;

begin
  Result := False;
  RenameResult := False;
  Error := CheckNewName(Name);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  Sel := TList.Create;
  Bef := TList.Create;
  Aft := TList.Create;
  Vars := TStringList.Create;
  SL := TStringList.Create;
  try
    if not ExtractCheck(CI, Source, RT, U, A, B, K0, K1, Rou, InLoop, Error) then Exit;
    A2 := RT.T[K0].Start;
    B2 := RT.EndOf(K1);
    M := MethodOf(Rou);
    if M <> nil then ClassName := M.ClassQual else ClassName := '';
    Top := Outermost(Rou);
    if (M <> nil) and (U.FindTypeSym(ClassName, [tyClass, tyObject, tyRecord]) = nil) then
    begin
      Error := Format('%s is not declared in this unit', [ClassName]);
      Exit;
    end;
    if M <> nil then
    begin
      if U.FindTypeSym(ClassName, [tyClass, tyObject, tyRecord]).TypeDesc.Members.Find(Name) <> nil then
      begin
        Error := Format('%s already has a member named %s', [ClassName, Name]);
        Exit;
      end;
    end
    else if (U.IntfSyms.Find(Name) <> nil) or (U.ImplSyms.Find(Name) <> nil) then
    begin
      Error := Format('%s already declares %s', [U.Name, Name]);
      Exit;
    end;
    if not CI.NameUses(FileName, Source, A2, B2, Sel) or
      not CI.NameUses(FileName, Source, Rou.FullEnd, A2, Bef) or
      not CI.NameUses(FileName, Source, B2, Rou.BodyEnd, Aft) then
    begin
      Error := 'Code insight could not read the routine';
      Exit;
    end;
    { the routine's variables the statements use, in the order they come }
    for I := 0 to Sel.Count - 1 do
    begin
      NU := TCINameUse(Sel[I]);
      if NU.NestedRoutine then
      begin
        Error := Format('The selection calls %s, a routine nested in %s', [NU.Name, Rou.Name]);
        Exit;
      end;
      if NU.LocalType and not NU.Qualified then
      begin
        Error := Format('The selection uses %s, declared in %s', [NU.Name, Rou.Name]);
        Exit;
      end;
      if NU.Key = 'RESULT' then
      begin
        { the function's Result: it goes in when read first, and comes out when assigned - the
          function gives it back }
        V := VarOf('RESULT');
        if V = nil then
        begin
          V := TExtractVar.Create;
          Vars.AddObject('RESULT', V);
          V.Key := 'RESULT';
          V.Name := 'Result';
          V.TypeText := ResultTypeOf(U, Rou);
          if V.TypeText = '' then
          begin
            Error := 'The type of the function''s Result is not known';
            Exit;
          end;
          V.ReadFirst := NU.Read;
          V.After := True;
        end;
        if NU.Written then V.Written := True;
        Continue;
      end;
      if SameText(NU.Name, ResultParam) then
      begin
        Error := Format('The selection uses %s, the name the function''s Result would get', [ResultParam]);
        Exit;
      end;
      if not NU.Local then Continue;
      V := VarOf(NU.Key);
      if V = nil then
      begin
        if NU.TypeText = '' then
        begin
          Error := Format('The type of %s is not known', [NU.Name]);
          Exit;
        end;
        V := TExtractVar.Create;
        Vars.AddObject(NU.Key, V);
        V.Key := NU.Key;
        V.Name := NU.Name;
        V.TypeText := NU.TypeText;
        V.Modifier := NU.Modifier;
        V.IsParam := NU.Kind = ckParam;
        V.ReadFirst := NU.Read;
      end;
      if NU.Written then V.Written := True;
    end;
    for I := 0 to Bef.Count - 1 do
    begin
      V := VarOf(TCINameUse(Bef[I]).Key);
      if (V <> nil) and not OwnDecl(TCINameUse(Bef[I])) then V.Before := True;
    end;
    for I := 0 to Aft.Count - 1 do
    begin
      V := VarOf(TCINameUse(Aft[I]).Key);
      if (V <> nil) and not OwnDecl(TCINameUse(Aft[I])) then V.After := True;
    end;
    { which go in, which come out: one that only comes out is the result of a function }
    ResultVar := nil;
    J := 0;
    for I := 0 to Vars.Count - 1 do
    begin
      V := TExtractVar(Vars.Objects[I]);
      if V.Written and (V.After or (V.IsParam and ((V.Modifier = 'var') or (V.Modifier = 'out'))) or
        (V.Before and InLoop)) then
      begin
        Inc(J);
        if not (V.ReadFirst and (V.IsParam or V.Before or V.After)) then ResultVar := V;
      end;
    end;
    if J <> 1 then ResultVar := nil;
    ParamList := '';
    ArgList := '';
    LocalList := '';
    for I := 0 to Vars.Count - 1 do
    begin
      V := TExtractVar(Vars.Objects[I]);
      if V = ResultVar then
      begin
        if V.Key <> 'RESULT' then LocalList := LocalList + '  ' + V.Name + ': ' + V.TypeText + ';' + EOL;
        Continue;
      end;
      if V.ReadFirst and (V.IsParam or V.Before or V.After) or
        V.Written and (V.After or (V.IsParam and ((V.Modifier = 'var') or (V.Modifier = 'out'))) or (V.Before and InLoop)) then
      begin
        if ParamList <> '' then
        begin
          ParamList := ParamList + '; ';
          ArgList := ArgList + ', ';
        end;
        if V.Written and (V.After or (V.IsParam and ((V.Modifier = 'var') or (V.Modifier = 'out'))) or (V.Before and InLoop)) then
          ParamList := ParamList + 'var '
        else if V.Modifier = 'const' then
          ParamList := ParamList + 'const ';
        if V.Key = 'RESULT' then ParamList := ParamList + ResultParam + ': ' + V.TypeText
        else ParamList := ParamList + V.Name + ': ' + V.TypeText;
        ArgList := ArgList + V.Name;
      end
      else
        LocalList := LocalList + '  ' + V.Name + ': ' + V.TypeText + ';' + EOL;
    end;
    if ParamList <> '' then
    begin
      ParamList := '(' + ParamList + ')';
      ArgList := '(' + ArgList + ')';
    end;
    if ResultVar <> nil then
    begin
      Kw := 'function';
      ResType := ': ' + ResultVar.TypeText;
    end
    else
    begin
      Kw := 'procedure';
      ResType := '';
    end;
    Prefix := '';
    if (M <> nil) and (sfClassMethod in M.Flags) then Prefix := 'class ';
    { the body: the statements indented for it }
    RenameResult := (VarOf('RESULT') <> nil) and (VarOf('RESULT') <> ResultVar);
    Lines := FirstOnLine(Source, A2) and LastOnLine(Source, B2);
    if Lines then
    begin
      SL.Text := Region(LineStartOf(Source, A2), LineEndOf(Source, B2));
      Mins := MaxInt;
      for I := 0 to SL.Count - 1 do
        if Trim(SL[I]) <> '' then
        begin
          Ind := Length(SL[I]) - Length(TrimLeft(SL[I]));
          if Ind < Mins then Mins := Ind;
        end;
      if Mins = MaxInt then Mins := 0;
      Text := '';
      for I := 0 to SL.Count - 1 do
      begin
        Line := SL[I];
        if Trim(Line) = '' then Line := '' else Line := '  ' + Copy(Line, Mins + 1, MaxInt);
        Text := Text + Line;
        if I < SL.Count - 1 then Text := Text + EOL;
      end;
    end
    else
      Text := '  ' + Region(A2, B2);
    if (ResultVar <> nil) and (ResultVar.Key <> 'RESULT') then
    begin
      if (TrimRight(Text) <> '') and (TrimRight(Text)[Length(TrimRight(Text))] <> ';') then Text := TrimRight(Text) + ';';
      Text := Text + EOL + '  Result := ' + ResultVar.Name + ';';
    end;
    if ClassName <> '' then
      Heading := Prefix + Kw + ' ' + ClassName + '.' + Name + ParamList + ResType + ';'
    else
      Heading := Kw + ' ' + Name + ParamList + ResType + ';';
    Body := Heading + EOL;
    if LocalList <> '' then Body := Body + 'var' + EOL + LocalList;
    Body := Body + 'begin' + EOL + Text + EOL + 'end;';
    { the call in the statements' place }
    Call := Name + ArgList;
    if ResultVar <> nil then Call := ResultVar.Name + ' := ' + Call;
    if RT.IsSy(K1, sySemicolon) then Call := Call + ';';
    if ClassName <> '' then
    begin
      { a method: declared in its class, its body after the routine it comes from }
      if not ExplorerMemberEdit(U, ClassName, Access, False, '    ' + Prefix + Kw + ' ' + Name + ParamList + ResType + ';',
        Start, Text, Error) then Exit;
      if R.AddEdit(FileName, Start, 0, Text) = nil then
      begin
        Error := 'Could not declare the method';
        Exit;
      end;
      J := RT.FirstAt(Top.BodyEnd);
      if RT.IsSy(J, sySemicolon) then P := LineEndOf(Source, RT.T[J].Start) else P := LineEndOf(Source, Top.BodyEnd);
      R.AddEdit(FileName, P, 0, EOL + EOL + Body);
    end
    else
    begin
      { a plain routine: before the routine it comes from (and the comment lines above it) }
      R.AddEdit(FileName, CommentStart(Source, Top.HeadStart), 0, Body + EOL + EOL);
    end;
    R.AddEdit(FileName, A2, B2 - A2, Call);
    { the variables that moved: their declarations leave the routine }
    for I := 0 to Vars.Count - 1 do
    begin
      V := TExtractVar(Vars.Objects[I]);
      if V.IsParam or V.Before or V.After then Continue;
      if SameText(ExpandFileName(KeyFile(V.Key)), ExpandFileName(FileName)) then
        RemoveDecl(R, FileName, Source, RT, KeyOffset(V.Key), -1, False);
    end;
    if ClassName <> '' then
      R.Title := Format('Extract method %s.%s', [ClassName, Name])
    else
      R.Title := Format('Extract routine %s', [Name]);
    Result := True;
  finally
    for I := 0 to Vars.Count - 1 do Vars.Objects[I].Free;
    Vars.Free;
    SL.Free;
    FreeObjects(Sel);
    FreeObjects(Bef);
    FreeObjects(Aft);
    Sel.Free;
    Bef.Free;
    Aft.Free;
    U.Free;
    RT.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Introduce Variable }

{ the expression A .. B checked: whole tokens of one expression in a routine's statement }
function ExprCheck(RT: TRawToks; U: TUnitInfo; A, B: Integer; out K0, K1, St: Integer; out Rou: TRoutineSym;
  out Error: string): Boolean;
var
  K, Depth, J: Integer;
begin
  Result := False;
  Rou := nil;
  St := -1;
  if not SelTokens(RT, A, B, K0, K1) then
  begin
    Error := 'Select an expression';
    Exit;
  end;
  if RT.IsSy(K1, sySemicolon) then Dec(K1);
  if K1 < K0 then
  begin
    Error := 'Select an expression';
    Exit;
  end;
  Rou := BodyAround(U, RT.T[K0].Start, RT.EndOf(K1));
  if Rou = nil then
  begin
    Error := 'Select an expression in a routine';
    Exit;
  end;
  Depth := 0;
  for K := K0 to K1 do
    with RT.T[K] do
      if Kind = tkSymbol then
      begin
        if Symbol in [syLParen, syLBracket] then Inc(Depth)
        else if Symbol in [syRParen, syRBracket] then
        begin
          Dec(Depth);
          if Depth < 0 then Break;
        end
        else if Symbol in [sySemicolon, syAssign, syColon, syDotDot] then Depth := -100;
      end
      else if (Kind = tkKeyword) and not (Keyword in [kwNot, kwAnd, kwOr, kwXor, kwDiv, kwMod, kwShl, kwShr, kwIn,
        kwIs, kwAs, kwNil, kwString, kwInherited]) then
        Depth := -100;
  if Depth <> 0 then
  begin
    Error := 'The selection is not an expression';
    Exit;
  end;
  if RT.IsSy(K1 + 1, syAssign) or RT.IsSy(K1 + 1, syDot) or RT.IsSy(K0 - 1, syDot) or RT.IsSy(K0 - 1, syAt) then
  begin
    Error := 'The selection is not an expression whose value can be kept';
    Exit;
  end;
  { the statement it is in: back to what begins it }
  J := K0 - 1;
  Depth := 0;
  while J >= 0 do
  begin
    if RT.IsSy(J, syRParen) or RT.IsSy(J, syRBracket) then Inc(Depth)
    else if RT.IsSy(J, syLParen) or RT.IsSy(J, syLBracket) then
    begin
      if Depth > 0 then Dec(Depth);
    end
    else if (Depth = 0) and (BeginsStatement(RT, J) or RT.IsSy(J, syColon)) then
      Break;
    Dec(J);
  end;
  if (J < 0) or (RT.T[J].Kind = tkKeyword) and (RT.T[J].Keyword in [kwThen, kwElse, kwDo]) or RT.IsSy(J, syColon) then
  begin
    Error := 'The statement is the one statement of a then, else, do or case label: put it in begin ... end first';
    Exit;
  end;
  St := J + 1;
  if (RT.T[St].Kind = tkKeyword) and (RT.T[St].Keyword in [kwWhile, kwUntil]) then
  begin
    Error := 'The expression is a loop''s condition, which is evaluated again and again';
    Exit;
  end;
  Result := True;
end;

function IntroduceTarget(CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  out Expr, TypeName, Name: string; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1, St, K: Integer;
  Rou: TRoutineSym;
begin
  Expr := '';
  TypeName := '';
  Name := '';
  Error := '';
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    Result := ExprCheck(RT, U, A, B, K0, K1, St, Rou, Error);
    if not Result then Exit;
    Expr := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    TypeName := CI.ExprTypeName(FileName, Source, RT.T[K0].Start, RT.EndOf(K1));
    { a name: the expression's last name, as a local variable is often named }
    Name := 'Value';
    for K := K1 downto K0 do
      if RT.T[K].Kind = tkIdent then
      begin
        SetString(Name, RT.T[K].Ptr, RT.T[K].PLen);
        Name := 'L' + UpCase(Name[1]) + Copy(Name, 2, MaxInt);
        Break;
      end;
  finally
    U.Free;
    RT.Free;
  end;
end;

function PlanIntroduceVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; A, B: Integer;
  const Name, TypeName: string; ReplaceAll: Boolean; out Error: string): Boolean;
var
  RT: TRawToks;
  U: TUnitInfo;
  K0, K1, St, K, N, Lim: Integer;
  Rou: TRoutineSym;
  Expr, EOL: string;
begin
  Result := False;
  Error := CheckDeclaration(Name, TypeName);
  if Error <> '' then Exit;
  R.SetSource(FileName, Source);
  EOL := DetectEOL(Source);
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    if not ExprCheck(RT, U, A, B, K0, K1, St, Rou, Error) then Exit;
    if RoutineDeclares(Rou, Name) then
    begin
      Error := Format('%s already declares %s', [Rou.Name, Name]);
      Exit;
    end;
    Expr := Copy(Source, RT.T[K0].Start + 1, RT.EndOf(K1) - RT.T[K0].Start);
    R.Title := Format('Introduce variable %s := %s', [Name, Expr]);
    if not AddLocalDecl(R, FileName, Source, RT, Rou, kwVar, Name + ': ' + Trim(TypeName) + ';') then
    begin
      Error := 'Could not find where to declare the variable';
      Exit;
    end;
    { the assignment before the statement }
    if FirstOnLine(Source, RT.T[St].Start) then
      R.AddEdit(FileName, LineStartOf(Source, RT.T[St].Start), 0,
        IndentAt(Source, RT.T[St].Start) + Name + ' := ' + Expr + ';' + EOL)
    else
      R.AddEdit(FileName, RT.T[St].Start, 0, Name + ' := ' + Expr + '; ');
    R.AddEdit(FileName, RT.T[K0].Start, RT.EndOf(K1) - RT.T[K0].Start, Name);
    if ReplaceAll then
    begin
      { the same tokens again further on in the routine }
      N := K1 - K0 + 1;
      Lim := RT.FirstAt(Rou.BodyEnd);
      K := St;
      while K + N <= Lim do
      begin
        if (K <> K0) and SameTokens(RT, K, K0, N) and not RT.IsSy(K + N, syAssign) and not RT.IsSy(K - 1, syDot) and
          not RT.IsSy(K + N, syDot) and
          not RT.IsSy(K + N, syLParen) and not RT.IsSy(K + N, syLBracket) then
        begin
          R.AddEdit(FileName, RT.T[K].Start, RT.EndOf(K + N - 1) - RT.T[K].Start, Name);
          Inc(K, N);
        end
        else
          Inc(K);
      end;
    end;
    Result := True;
  finally
    U.Free;
    RT.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Inline Variable }

function PlanInlineVariable(R: TRefactoring; CI: TCodeInsight; const FileName, Source: string; Pos: Integer;
  out Error: string): Boolean;
var
  Info: TCISymbolInfo;
  Places, Uses_, Reads: TList;
  Files: TStringList;
  RT: TRawToks;
  U: TUnitInfo;
  Rou: TRoutineSym;
  I, J, AK, SE, DeclOfs, A, B: Integer;
  P: TCIPlace;
  NU, Assign: TCINameUse;
  Expr, Repl: string;
begin
  Result := False;
  Error := '';
  R.SetSource(FileName, Source);
  Places := TList.Create;
  Uses_ := TList.Create;
  Reads := TList.Create;
  Files := TStringList.Create;
  RT := TRawToks.Create(Source, False);
  U := ParseText(CI, FileName, Source);
  try
    Files.Add(FileName);
    if not CI.SymbolPlaces(FileName, Source, Pos, Files, Info, Places) then
    begin
      Error := 'Put the caret on a local variable';
      Exit;
    end;
    if Info.Kind <> ckLocalVar then
    begin
      Error := Format('%s is not a local variable', [Info.Name]);
      Exit;
    end;
    DeclOfs := -1;
    for I := 0 to Places.Count - 1 do
      if TCIPlace(Places[I]).Decl then DeclOfs := TCIPlace(Places[I]).Start;
    if DeclOfs < 0 then
    begin
      Error := Format('The declaration of %s is not found', [Info.Name]);
      Exit;
    end;
    Rou := RoutineAround(U, DeclOfs, DeclOfs);
    if (Rou = nil) or not (sfHasBody in Rou.Flags) then
    begin
      Error := Format('The routine of %s is not found', [Info.Name]);
      Exit;
    end;
    if not CI.NameUses(FileName, Source, Rou.FullEnd, Rou.BodyEnd, Uses_) then
    begin
      Error := 'Code insight could not read the routine';
      Exit;
    end;
    { its one assignment, then only reads }
    Assign := nil;
    for I := 0 to Places.Count - 1 do
    begin
      P := TCIPlace(Places[I]);
      if P.Decl then Continue;
      NU := nil;
      for J := 0 to Uses_.Count - 1 do
        if TCINameUse(Uses_[J]).Start = P.Start then NU := TCINameUse(Uses_[J]);
      if NU = nil then
      begin
        Error := Format('Line %d: %s is not understood there', [P.Line, Info.Name]);
        Exit;
      end;
      if NU.Written then
      begin
        if (Assign <> nil) or NU.Read then
        begin
          Error := Format('%s is assigned more than once', [Info.Name]);
          Exit;
        end;
        Assign := NU;
      end
      else
        Reads.Add(NU);
    end;
    if Assign = nil then
    begin
      Error := Format('%s is never assigned', [Info.Name]);
      Exit;
    end;
    AK := RT.FirstAt(Assign.Start);
    if not RT.IsSy(AK + 1, syAssign) or not BeginsStatement(RT, AK - 1) or
      ((RT.T[AK - 1].Kind = tkKeyword) and (RT.T[AK - 1].Keyword in [kwThen, kwElse, kwDo])) then
    begin
      Error := Format('%s is not assigned by a statement of its own', [Info.Name]);
      Exit;
    end;
    SE := StatementEnd(RT, AK + 2);
    if SE <= AK + 2 then
    begin
      Error := 'The assignment has no value';
      Exit;
    end;
    for I := 0 to Reads.Count - 1 do
      if TCINameUse(Reads[I]).Start < Assign.Start then
      begin
        Error := Format('%s is read before it is assigned', [Info.Name]);
        Exit;
      end;
    Expr := Copy(Source, RT.T[AK + 2].Start + 1, RT.EndOf(SE - 1) - RT.T[AK + 2].Start);
    R.Title := Format('Inline variable %s := %s', [Info.Name, Expr]);
    for I := 0 to Reads.Count - 1 do
    begin
      if NeedsBrackets(RT, AK + 2, SE - 1, RT.FirstAt(TCINameUse(Reads[I]).Start)) then Repl := '(' + Expr + ')'
      else Repl := Expr;
      R.AddEdit(FileName, TCINameUse(Reads[I]).Start, TCINameUse(Reads[I]).Len, Repl);
    end;
    { the assignment, the declaration }
    A := RT.T[AK].Start;
    if RT.IsSy(SE, sySemicolon) then B := RT.T[SE].Start + 1 else B := RT.EndOf(SE - 1);
    WholeLines(Source, A, B);
    R.AddEdit(FileName, A, B - A, '');
    if not RemoveDecl(R, FileName, Source, RT, DeclOfs, -1, False) then
      R.Notes.Add(Format('The declaration of %s stays: take it out by hand.', [Info.Name]));
    if Reads.Count = 0 then R.Notes.Add(Format('%s is never read: its assignment is taken out.', [Info.Name]));
    Result := True;
  finally
    FreeObjects(Places);
    FreeObjects(Uses_);
    Places.Free;
    Uses_.Free;
    Reads.Free;
    Files.Free;
    U.Free;
    RT.Free;
  end;
end;

end.
