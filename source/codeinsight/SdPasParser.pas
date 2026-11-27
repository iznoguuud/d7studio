{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPasParser;

{ D7 Studio - tolerant Delphi 7 parser producing per-unit symbol tables.
  Never raises on malformed source; always makes progress. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, SdPasLex;

type
  TSymKind = (skUnknown, skConst, skResStr, skVar, skType, skRoutine, skField,
    skProperty, skParam, skLocal, skEnumValue, skLabel);

  TSymFlag = (sfFunction, sfConstructor, sfDestructor, sfClassMethod,
    sfOverload, sfVirtual, sfOverride, sfAbstract, sfDynamic,
    sfForward, sfExternal, sfVarParam, sfConstParam, sfOutParam,
    sfArrayProp, sfHasBody, sfBodyClosed, sfOwnsType, sfInImpl,
    sfHasDefault, sfDispReady, sfParamsParsed, sfImplBody);
  TSymFlags = set of TSymFlag;

  TVisibility = (viNone, viPrivate, viProtected, viPublic, viPublished);

  TTypeKind = (tyAlias, tyClass, tyInterface, tyRecord, tyObject, tyEnum,
    tySet, tyArray, tyPointer, tyProc, tyClassRef, tyFile, tySubrange);
  TTypeKinds = set of TTypeKind;

  TUnitInfo = class;
  TSymbol = class;
  TSymTable = class;

  TTypeDesc = class
  public
    Kind: TTypeKind;
    IsForward: Boolean;
    InImpl: Boolean;
    IsFunction: Boolean;
    ParamsParsed: Boolean;
    RefName: string;          // tyAlias / tyClassRef: referenced type name
    Elem: TTypeDesc;          // element / pointee / result type
    Members: TSymTable;       // class, interface, record, object
    Ancestors: TStringList;   // ancestor + implemented interfaces
    UnitInfo: TUnitInfo;
    OwnerRoutine: TSymbol;    // routine in whose local scope the type was written (nil = unit level)
    Sym: TSymbol;             // naming type symbol (nil = anonymous)
    DefaultProp: TSymbol;     // default array property declared in this type
    HeaderEnd: Integer;       // end offset of 'class(TFoo)' / 'record' header
    FirstVisOfs: Integer;     // offset of the first visibility keyword in the body (0 = none)
    EndOfs: Integer;          // offset of the terminating 'end' (0 = none / not found)
    ParamsStart, ParamsEnd: Integer;  // tyProc
    Params: TList;            // tyProc, lazily parsed (owned TSymbol)
    AncCache: TTypeDesc;
    AncGen: Integer;
    destructor Destroy; override;
  end;

  TSymbol = class
  public
    Name: string;
    Kind: TSymKind;
    Visibility: TVisibility;
    Flags: TSymFlags;
    Line, Col: Integer;        // position of the name
    DeclStart, DeclEnd: Integer;   // name start .. end of declaration text (kind specific)
    TypeStart, TypeEnd: Integer;   // source range of the type text
    FullEnd: Integer;          // offset just after the terminating ';' (and directives)
    TypeDesc: TTypeDesc;
    Owner: TObject;            // TTypeDesc for members, TRoutineSym for locals/params
    UnitInfo: TUnitInfo;
    HashNext: TSymbol;
    DispDecl, DispType: string;
    destructor Destroy; override;
  end;

  TRoutineSym = class(TSymbol)   // routines and properties
  public
    ParamsStart, ParamsEnd: Integer;   // inside the parentheses / brackets
    Params: TList;             // owned TSymbol (skParam), lazily parsed
    Locals: TSymTable;         // local declarations (implementation routines)
    ClassQual: string;         // 'TForm1' for 'procedure TForm1.Foo'
    HeadStart: Integer;        // offset of 'procedure' / 'class' keyword
    BodyStart, BodyEnd: Integer;
    DispParams: string;
    destructor Destroy; override;
  end;

  TSymTable = class
  private
    FBuckets: array of TSymbol;
    FMask: Cardinal;
    FItems: array of TSymbol;
    FCount: Integer;
    function GetItem(Index: Integer): TSymbol;
    procedure Rehash(NewSize: Integer);
    procedure Link(S: TSymbol);
  public
    destructor Destroy; override;
    procedure Add(S: TSymbol);
    function Find(const AName: string): TSymbol;
    function FindP(P: PChar; Len: Integer): TSymbol;
    function FindHashed(P: PChar; Len: Integer; H: Cardinal): TSymbol;
    function FindNext(S: TSymbol): TSymbol;
    property Count: Integer read FCount;
    property Items[Index: Integer]: TSymbol read GetItem; default;
  end;

  TUnitArray = array of TUnitInfo;

  TUnitInfo = class
  private
    FLineStarts: array of Integer;
    FLineCount: Integer;
    procedure BuildLines;
    procedure CollectImpls(List: TList; const Cls, Name: string; AllMethods: Boolean);
  public
    Name: string;
    FileName: string;
    Source: string;
    IsProgram: Boolean;
    IntfUses, ImplUses: TStringList;   // Objects = line shl 10 or col
    UsesIn: TStringList;               // 'Unit=path' from "uses X in 'path'"
    UsesInIndex: TStringList;          // UsesIn's unit names sorted, made by the engine at its first lookup (nil: none yet)
    IntfSyms, ImplSyms: TSymTable;
    ImplRoutines: TList;               // TRoutineSym with bodies, source order (not owned here)
    OwnedExtra: TList;                 // symbols owned by the unit but in no table
    IntfOfs, ImplOfs: Integer;
    IntfUsesStart, IntfUsesEnd: Integer;   // offset of 'uses' keyword / of the ';' (0 = none)
    ImplUsesStart, ImplUsesEnd: Integer;
    InitOfs, FinalOfs: Integer;        // 'initialization' / 'finalization' keyword offsets (0 = none)
    MainBegin: Integer;                // main 'begin' of the block (0 = none)
    FinalEndOfs: Integer;              // offset of the final 'end' of 'end.' (0 = not found)
    FullParsed: Boolean;
    // cache bookkeeping (used by TCodeInsight)
    Loaded: Boolean;
    FromIDE: Boolean;
    FileAgeStamp: Integer;
    CheckGen: Integer;
    UnitsGen: Integer;
    MarkGen: Integer;                  // a pass's marker: TCodeInsight.Browse took the unit in pass MarkGen
    IntfUnits, ImplUnits: TUnitArray;
    { the declarations of the interface (False) and of the implementation (True) by their places
      - IntfSyms / ImplSyms are in the order of the parse, where a type declared forward keeps the
      forward's slot -: made by code insight when it first needs them (TCIContext.UnitScanStart),
      dropped by Clear }
    ScanMade: array[Boolean] of Boolean;
    ScanSyms: array[Boolean] of array of TSymbol;
    ScanStarts: array[Boolean] of array of Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function LineOfOffset(Ofs: Integer; out Col: Integer): Integer;
    { ... and back: the offset of Line, Col (1-based; a line past the end: the text's end) }
    function OffsetOf(Line, Col: Integer): Integer;
    { The implementations ('procedure Cls.Name ...') of class Cls ('' = plain routines) named
      Name ('' = any name), in source order. While code is being typed a method can end up
      nested inside an unfinished routine above it: nested routines carrying the class
      qualifier are collected as well (after the others). }
    procedure GetImpls(List: TList; const Cls, Name: string);
    { the implementations of every class's methods (those with a class qualifier), as GetImpls
      collects them }
    procedure GetMethodImpls(List: TList);
    { the first of them; nil = none }
    function FindImpl(const Cls, Name: string): TRoutineSym;
    { the structured type Name (class, object, record, interface: Kinds says which) declared in
      the unit (the interface first) with its members - not a forward declaration, not a class
      without a body; nil = none }
    function FindTypeSym(const Name: string; Kinds: TTypeKinds): TSymbol;
    { Ctrl+Shift+Up/Down: the counterpart of what is on line Line (1-based) - from
      a method's implementation (its heading or anywhere in its body, nested routines included)
      to its declaration in the class, from a plain routine's implementation to its declaration
      in the interface, from a method's declaration in a class to its implementation; overloads
      pair by their parameters (PairRoutine). ToLine / ToCol: the counterpart's name (1-based). }
    function FindCounterpart(Line: Integer; out ToLine, ToCol: Integer): Boolean;
  end;

  TSymbolSet = set of TSymbolId;

  TPasParser = class
  private
    L: TPasLexer;
    U: TUnitInfo;
    FIntfOnly: Boolean;
    FTable: TSymTable;
    FInImpl: Boolean;
    FOwnerRoutine: TRoutineSym;
    FPrevEnd: Integer;
    FSeq: Integer;
    FSemiPos: Integer;
    FDepth: Integer;
    procedure Next;
    function IsKw(K: TKeyword): Boolean;
    function IsSym(S: TSymbolId): Boolean;
    function IsDir(D: TDirective): Boolean;
    procedure InitSym(S: TSymbol; AKind: TSymKind);
    function NewDesc(AKind: TTypeKind): TTypeDesc;
    function ParseQualIdent: string;
    procedure SkipToSemi;
    procedure SkipBalanced;
    procedure SkipExpr(Stops: TSymbolSet; Sync: Boolean);
    procedure SkipTypeExpr;
    procedure SkipHints;
    procedure SkipCallConv(TD: TTypeDesc);
    procedure SkipParams(out PS, PE: Integer);
    procedure ReadNames(List: TList; AKind: TSymKind; AOwner: TObject; AVis: TVisibility; AFlags: TSymFlags);
    procedure TypeNames(List: TList; First: Integer; TD: TTypeDesc; TS, TE, ADeclEnd: Integer;
      Table: TSymTable; AFlags: TSymFlags);
    procedure ParseAncestors(D: TTypeDesc; Several: Boolean);
    procedure ParseUses(List: TStringList; InIntf: Boolean);
    procedure ParseConstSection(IsResStr: Boolean);
    procedure ParseTypeSection;
    procedure ParseVarSection;
    function ConstLiteralType(out LitEnd: Integer): string;
    function ParseType: TTypeDesc;
    function ParseArray: TTypeDesc;
    function ParseEnum: TTypeDesc;
    function ParseRecord: TTypeDesc;
    function ParseClass: TTypeDesc;
    function ParseObject: TTypeDesc;
    function ParseInterface: TTypeDesc;
    function ParseProcType: TTypeDesc;
    procedure ParseFieldList(Desc: TTypeDesc; InVariant: Boolean);
    procedure ParseFieldDecl(Desc: TTypeDesc; Vis: TVisibility);
    procedure ParseVariantPart(Desc: TTypeDesc);
    procedure ParseClassBody(Desc: TTypeDesc; DefaultVis: TVisibility);
    procedure ParseProperty(Desc: TTypeDesc; Vis: TVisibility);
    function ParseRoutineHeading(HeadStart: Integer; IsClass: Boolean): TRoutineSym;
    procedure ParseRoutineDirectives(R: TRoutineSym);
    procedure ParseIntfRoutine(HeadStart: Integer; IsClass: Boolean);
    procedure ParseImplRoutine(HeadStart: Integer; IsClass: Boolean);
    procedure ParseDeclSections(IsLocal: Boolean);
    function SkipStatements(InInit: Boolean): Boolean;
    procedure SkipAsm;
    procedure ParseUnitSections;
    procedure ParseImplBody;
  public
    constructor Create(AUnit: TUnitInfo; ALexer: TPasLexer);
    procedure ParseUnit(IntfOnly: Boolean);
    procedure ParseParamList(List: TList; AOwner: TObject);
  end;

{ Parses Source into U (clears U first). Never raises. }
procedure ParseSource(U: TUnitInfo; const Source: string; IntfOnly: Boolean;
  Defines: TStrings; OnInclude: TLexIncludeEvent);
{ Lazily parses the parameter list of a routine / property. }
procedure EnsureParams(R: TRoutineSym);
procedure EnsureTypeParams(D: TTypeDesc);
{ Parses a free-standing parameter list text ('Sender: TObject; var Key: Word'). The
  symbols are added to List (caller owns); offsets refer to Text. }
procedure ParseParamText(U: TUnitInfo; const Text: string; List: TList);
procedure FreeSymList(List: TList);
{ the reserved words of a routine's heading: 'procedure', 'class function', 'constructor' ... }
function RoutineKeyword(R: TSymbol): string;
{ the reserved word of a parameter's kind: 'const', 'var', 'out'; '' for a value parameter }
function ParamModifier(P: TSymbol): string;
{ S declares a structured type of one of Kinds with its members: not a forward declaration, not
  a class without a body }
function IsStructDecl(S: TSymbol; Kinds: TTypeKinds): Boolean;
{ source text as one line: comments out, white space as one blank where it separates words;
  MaxLen > 0: cut there with '...' }
function NormalizeText(P: PChar; Len, MaxLen: Integer): string;
{ the parameter list of routine S as text (NormalizeText, inside its parentheses): the same for an
  overload's declaration and implementation; '' for none or for a symbol that is no routine - kept
  in its DispParams }
function RoutineParamsText(S: TSymbol): string;
{ of Routines - routines of S's name - S's counterpart (a declaration's implementation, an
  implementation's declaration): the one with S's parameters (overloads, whatever their order),
  else the first; S itself is skipped; nil when there is no other }
function PairRoutine(S: TSymbol; Routines: TList): TSymbol;
{ the routine a nested routine R is declared in (nil: R is no nested routine - a method's
  implementation, a routine of the unit) }
function OuterOf(R: TRoutineSym): TRoutineSym;
{ the routines of Tab named Name that have all of the flags Need and none of Skip, added to List
  (each once; Tab nil: none) }
procedure AddRoutines(Tab: TSymTable; const Name: string; Need, Skip: TSymFlags; List: TList);

implementation

procedure AddRoutines(Tab: TSymTable; const Name: string; Need, Skip: TSymFlags; List: TList);
var
  M: TSymbol;
begin
  if Tab = nil then Exit;
  M := Tab.Find(Name);
  while M <> nil do
  begin
    if (M.Kind = skRoutine) and (M is TRoutineSym) and (M.Flags * Need = Need) and (M.Flags * Skip = []) and
      (List.IndexOf(M) < 0) then
      List.Add(M);
    M := Tab.FindNext(M);
  end;
end;

function OuterOf(R: TRoutineSym): TRoutineSym;
begin
  if (R.ClassQual = '') and (R.Owner is TRoutineSym) then Result := TRoutineSym(R.Owner)
  else Result := nil;
end;

const
  SyncKeywords = [kwBegin, kwConst, kwType, kwVar, kwProcedure, kwFunction,
    kwConstructor, kwDestructor, kwImplementation, kwInitialization,
    kwFinalization, kwInterface, kwUses, kwUnit, kwProgram, kwLibrary,
    kwResourcestring, kwThreadvar, kwLabel, kwExports, kwEnd, kwAsm];

  // inside parentheses / brackets 'const' and 'var' are legitimate (parameters)
  ParenSyncKeywords = SyncKeywords - [kwConst, kwVar];

  BodySyncKeywords = [kwProcedure, kwFunction, kwConstructor, kwDestructor,
    kwImplementation, kwInitialization, kwFinalization, kwType, kwConst, kwVar,
    kwResourcestring, kwThreadvar, kwUses, kwUnit, kwLabel, kwInterface,
    kwClass, kwProgram, kwLibrary];

  MaxDepth = 120;

procedure FreeSymList(List: TList);
var
  I: Integer;
begin
  if List = nil then Exit;
  for I := 0 to List.Count - 1 do
    TObject(List[I]).Free;
  List.Free;
end;

{ TTypeDesc }

destructor TTypeDesc.Destroy;
begin
  Elem.Free;
  Members.Free;
  Ancestors.Free;
  FreeSymList(Params);
  inherited Destroy;
end;

{ TSymbol }

destructor TSymbol.Destroy;
begin
  if sfOwnsType in Flags then TypeDesc.Free;
  inherited Destroy;
end;

{ TRoutineSym }

destructor TRoutineSym.Destroy;
begin
  FreeSymList(Params);
  Locals.Free;
  inherited Destroy;
end;

{ TSymTable }

destructor TSymTable.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FItems[I].Free;
  inherited Destroy;
end;

function TSymTable.GetItem(Index: Integer): TSymbol;
begin
  Result := FItems[Index];
end;

{ S at the end of the chain of its bucket }
procedure TSymTable.Link(S: TSymbol);
var
  H: Cardinal;
  P: TSymbol;
begin
  S.HashNext := nil;
  H := HashUpper(PChar(S.Name), Length(S.Name)) and FMask;
  P := FBuckets[H];
  if P = nil then
    FBuckets[H] := S
  else
  begin
    while P.HashNext <> nil do P := P.HashNext;
    P.HashNext := S;
  end;
end;

procedure TSymTable.Rehash(NewSize: Integer);
var
  I: Integer;
begin
  FBuckets := nil;
  SetLength(FBuckets, NewSize);
  FMask := NewSize - 1;
  for I := 0 to FCount - 1 do Link(FItems[I]);
end;

procedure TSymTable.Add(S: TSymbol);
begin
  if FCount >= Length(FItems) then
  begin
    if FCount = 0 then SetLength(FItems, 8)
    else SetLength(FItems, FCount * 2);
  end;
  FItems[FCount] := S;
  Inc(FCount);
  if FCount > Length(FBuckets) then
  begin
    if Length(FBuckets) = 0 then Rehash(16)
    else Rehash(Length(FBuckets) * 2);
    Exit;
  end;
  Link(S);
end;

function TSymTable.FindHashed(P: PChar; Len: Integer; H: Cardinal): TSymbol;
begin
  Result := nil;
  if FCount = 0 then Exit;
  Result := FBuckets[H and FMask];
  while (Result <> nil) and not SameTextP(P, Len, Result.Name) do
    Result := Result.HashNext;
end;

function TSymTable.FindP(P: PChar; Len: Integer): TSymbol;
begin
  if FCount = 0 then Result := nil
  else Result := FindHashed(P, Len, HashUpper(P, Len));
end;

function TSymTable.Find(const AName: string): TSymbol;
begin
  Result := FindP(PChar(AName), Length(AName));
end;

function TSymTable.FindNext(S: TSymbol): TSymbol;
begin
  Result := S.HashNext;
  while (Result <> nil) and not SameTextP(PChar(S.Name), Length(S.Name), Result.Name) do
    Result := Result.HashNext;
end;

{ TUnitInfo }

constructor TUnitInfo.Create;
begin
  inherited Create;
  IntfUses := TStringList.Create;
  ImplUses := TStringList.Create;
  UsesIn := TStringList.Create;
  IntfSyms := TSymTable.Create;
  ImplSyms := TSymTable.Create;
  ImplRoutines := TList.Create;
  OwnedExtra := TList.Create;
  ImplOfs := MaxInt;
end;

destructor TUnitInfo.Destroy;
begin
  Clear;
  IntfUses.Free;
  ImplUses.Free;
  UsesIn.Free;
  IntfSyms.Free;
  ImplSyms.Free;
  ImplRoutines.Free;
  OwnedExtra.Free;
  inherited Destroy;
end;

procedure TUnitInfo.Clear;
var
  I: Integer;
begin
  IntfUses.Clear;
  ImplUses.Clear;
  UsesIn.Clear;
  FreeAndNil(UsesInIndex);
  IntfSyms.Free;
  ImplSyms.Free;
  IntfSyms := TSymTable.Create;
  ImplSyms := TSymTable.Create;
  ImplRoutines.Clear;
  for I := 0 to OwnedExtra.Count - 1 do
    TObject(OwnedExtra[I]).Free;
  OwnedExtra.Clear;
  FLineStarts := nil;
  FLineCount := 0;
  IntfOfs := 0;
  ImplOfs := MaxInt;
  IntfUsesStart := 0; IntfUsesEnd := 0;
  ImplUsesStart := 0; ImplUsesEnd := 0;
  InitOfs := 0; FinalOfs := 0;
  MainBegin := 0;
  FinalEndOfs := 0;
  FullParsed := False;
  IsProgram := False;
  IntfUnits := nil;
  ImplUnits := nil;
  UnitsGen := 0;
  ScanMade[False] := False;
  ScanMade[True] := False;
  ScanSyms[False] := nil;
  ScanSyms[True] := nil;
  ScanStarts[False] := nil;
  ScanStarts[True] := nil;
end;

procedure TUnitInfo.BuildLines;
var
  P: PChar;
  I, N, Cap: Integer;
begin
  Cap := 256;
  SetLength(FLineStarts, Cap);
  FLineStarts[0] := 0;
  N := 1;
  P := PChar(Source);
  I := 0;
  while I < Length(Source) do
  begin
    if P[I] = #10 then
    begin
      if N >= Cap then
      begin
        Cap := Cap * 2;
        SetLength(FLineStarts, Cap);
      end;
      FLineStarts[N] := I + 1;
      Inc(N);
    end
    else if (P[I] = #13) and (P[I + 1] <> #10) then
    begin
      if N >= Cap then
      begin
        Cap := Cap * 2;
        SetLength(FLineStarts, Cap);
      end;
      FLineStarts[N] := I + 1;
      Inc(N);
    end;
    Inc(I);
  end;
  FLineCount := N;
end;

function TUnitInfo.LineOfOffset(Ofs: Integer; out Col: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  if FLineCount = 0 then BuildLines;
  if Ofs < 0 then Ofs := 0;
  Lo := 0;
  Hi := FLineCount - 1;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi + 1) div 2;
    if FLineStarts[Mid] <= Ofs then Lo := Mid else Hi := Mid - 1;
  end;
  Result := Lo + 1;
  Col := Ofs - FLineStarts[Lo] + 1;
end;

function TUnitInfo.OffsetOf(Line, Col: Integer): Integer;
begin
  if FLineCount = 0 then BuildLines;
  if (Line < 1) or (Line > FLineCount) then
  begin
    Result := Length(Source);
    Exit;
  end;
  Result := FLineStarts[Line - 1] + Col - 1;
end;

procedure TUnitInfo.CollectImpls(List: TList; const Cls, Name: string; AllMethods: Boolean);

  function Wanted(R: TRoutineSym): Boolean;
  begin
    if AllMethods then Result := R.ClassQual <> ''
    else Result := SameText(R.ClassQual, Cls) and ((Name = '') or SameText(R.Name, Name));
  end;

  procedure AddNested(R: TRoutineSym; Depth: Integer);
  var
    I: Integer;
    S: TSymbol;
  begin
    if (R.Locals = nil) or (Depth > 16) then Exit;
    for I := 0 to R.Locals.Count - 1 do
    begin
      S := R.Locals[I];
      if (S.Kind = skRoutine) and (S is TRoutineSym) and (sfImplBody in S.Flags) and
        not (sfForward in S.Flags) and not (sfExternal in S.Flags) then
      begin
        if Wanted(TRoutineSym(S)) then List.Add(S);
        AddNested(TRoutineSym(S), Depth + 1);
      end;
    end;
  end;

var
  I: Integer;
begin
  for I := 0 to ImplRoutines.Count - 1 do
    if Wanted(TRoutineSym(ImplRoutines[I])) then List.Add(ImplRoutines[I]);
  // a nested routine without a class qualifier is a local one, never an implementation
  if AllMethods or (Cls <> '') then
    for I := 0 to ImplRoutines.Count - 1 do
      AddNested(TRoutineSym(ImplRoutines[I]), 0);
end;

procedure TUnitInfo.GetImpls(List: TList; const Cls, Name: string);
begin
  CollectImpls(List, Cls, Name, False);
end;

procedure TUnitInfo.GetMethodImpls(List: TList);
begin
  CollectImpls(List, '', '', True);
end;

function TUnitInfo.FindTypeSym(const Name: string; Kinds: TTypeKinds): TSymbol;
var
  N: Integer;
  Tab: TSymTable;
begin
  for N := 0 to 1 do
  begin
    if N = 0 then Tab := IntfSyms else Tab := ImplSyms;
    Result := Tab.Find(Name);
    while Result <> nil do
    begin
      if IsStructDecl(Result, Kinds) then Exit;
      Result := Tab.FindNext(Result);
    end;
  end;
end;

function IsStructDecl(S: TSymbol; Kinds: TTypeKinds): Boolean;
begin
  Result := (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Kind in Kinds) and
    not S.TypeDesc.IsForward and (S.TypeDesc.Members <> nil);
end;

function RoutineKeyword(R: TSymbol): string;
begin
  if sfConstructor in R.Flags then Result := 'constructor'
  else if sfDestructor in R.Flags then Result := 'destructor'
  else if sfFunction in R.Flags then Result := 'function'
  else Result := 'procedure';
  if sfClassMethod in R.Flags then Result := 'class ' + Result;
end;

function ParamModifier(P: TSymbol): string;
begin
  if sfConstParam in P.Flags then Result := 'const'
  else if sfVarParam in P.Flags then Result := 'var'
  else if sfOutParam in P.Flags then Result := 'out'
  else Result := '';
end;

function NormalizeText(P: PChar; Len, MaxLen: Integer): string;
var
  I, N: Integer;
  C, Last: Char;
  Pending: Boolean;

  procedure Emit(Ch: Char);
  begin
    Inc(N);
    Result[N] := Ch;
  end;

begin
  if Len <= 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Result, Len * 2 + 4);
  N := 0;
  I := 0;
  Last := #0;
  Pending := False;
  while I < Len do
  begin
    if (MaxLen > 0) and (N >= MaxLen) then
    begin
      Emit('.'); Emit('.'); Emit('.');
      Break;
    end;
    C := P[I];
    if C = '{' then
    begin
      while (I < Len) and (P[I] <> '}') do Inc(I);
      Inc(I);
      Pending := True;
      Continue;
    end;
    if (C = '(') and (I + 1 < Len) and (P[I + 1] = '*') then
    begin
      Inc(I, 2);
      while (I < Len) and not ((P[I] = '*') and (P[I + 1] = ')')) do Inc(I);
      Inc(I, 2);
      Pending := True;
      Continue;
    end;
    if (C = '/') and (I + 1 < Len) and (P[I + 1] = '/') then
    begin
      while (I < Len) and not (P[I] in [#10, #13]) do Inc(I);
      Pending := True;
      Continue;
    end;
    if C <= ' ' then
    begin
      Pending := True;
      Inc(I);
      Continue;
    end;
    if Pending and (N > 0) then
      if not (C in [',', ';', ')', ']']) and not (Last in ['(', '[']) and
        not ((C = ':') and not ((I + 1 < Len) and (P[I + 1] = '='))) then
        Emit(' ');
    Pending := False;
    if C = '''' then
    begin
      // copy the string literal verbatim
      Emit(C);
      Inc(I);
      while I < Len do
      begin
        C := P[I];
        if C in [#10, #13] then Break;
        Emit(C);
        Inc(I);
        if C = '''' then
        begin
          if (I < Len) and (P[I] = '''') then
          begin
            Emit('''');
            Inc(I);
          end
          else
            Break;
        end;
      end;
      Last := '''';
      Continue;
    end;
    Emit(C);
    Last := C;
    if (C = ',') or (C = ';') then Pending := True
    else if (C = ':') and not ((I + 1 < Len) and (P[I + 1] = '=')) then Pending := True;
    Inc(I);
  end;
  while (N > 0) and (Result[N] = ' ') do Dec(N);
  SetLength(Result, N);
end;

function RoutineParamsText(S: TSymbol): string;
var
  R: TRoutineSym;
  U: TUnitInfo;
begin
  Result := '';
  if not (S is TRoutineSym) then Exit;
  R := TRoutineSym(S);
  if R.DispParams = '' then
  begin
    U := R.UnitInfo;
    if (U <> nil) and (R.ParamsStart >= 0) and (R.ParamsEnd > R.ParamsStart) and (R.ParamsEnd <= Length(U.Source)) then
      R.DispParams := NormalizeText(PChar(U.Source) + R.ParamsStart, R.ParamsEnd - R.ParamsStart, 400);
  end;
  Result := R.DispParams;
end;

function PairRoutine(S: TSymbol; Routines: TList): TSymbol;
var
  I: Integer;
  PT: string;
begin
  Result := nil;
  PT := RoutineParamsText(S);
  for I := 0 to Routines.Count - 1 do
    if Routines[I] <> S then
    begin
      if SameText(RoutineParamsText(TSymbol(Routines[I])), PT) then
      begin
        Result := TSymbol(Routines[I]);
        Exit;
      end;
      if Result = nil then Result := TSymbol(Routines[I]);
    end;
end;

function TUnitInfo.FindImpl(const Cls, Name: string): TRoutineSym;
var
  L: TList;
begin
  L := TList.Create;
  try
    GetImpls(L, Cls, Name);
    if L.Count > 0 then Result := TRoutineSym(L[0]) else Result := nil;
  finally
    L.Free;
  end;
end;

function TUnitInfo.FindCounterpart(Line: Integer; out ToLine, ToCol: Integer): Boolean;
var
  LineLo, LineHi, I, J, K, T: Integer;
  R: TRoutineSym;
  S, M, Target: TSymbol;
  Desc: TTypeDesc;
  L: TList;
  Tables: array[0..1] of TSymTable;

  function Overlaps(Lo, Hi: Integer): Boolean;
  begin
    Result := (Lo <= LineHi) and (Hi >= LineLo);
  end;

begin
  Result := False;
  ToLine := 0;
  ToCol := 0;
  if FLineCount = 0 then BuildLines;
  if (Line < 1) or (Line > FLineCount) then Exit;
  LineLo := FLineStarts[Line - 1];
  if Line < FLineCount then LineHi := FLineStarts[Line] - 1 else LineHi := Length(Source);
  Tables[0] := IntfSyms;
  Tables[1] := ImplSyms;
  Target := nil;
  L := TList.Create;
  try
    { in an implementation (heading or body): its declaration, of overloads the one with its
      parameters (PairRoutine) }
    for I := 0 to ImplRoutines.Count - 1 do
    begin
      R := TRoutineSym(ImplRoutines[I]);
      K := R.BodyEnd;
      if K < R.FullEnd then K := R.FullEnd;
      if not Overlaps(R.HeadStart, K) then Continue;
      if R.ClassQual <> '' then
      begin
        S := FindTypeSym(R.ClassQual, [tyClass, tyObject]);
        if (S <> nil) and (S.TypeDesc <> nil) and (S.TypeDesc.Members <> nil) then
          for J := 0 to S.TypeDesc.Members.Count - 1 do
            if (S.TypeDesc.Members[J].Kind = skRoutine) and SameText(S.TypeDesc.Members[J].Name, R.Name) then
              L.Add(S.TypeDesc.Members[J]);
      end
      else
      begin
        S := IntfSyms.Find(R.Name);
        while S <> nil do
        begin
          if S.Kind = skRoutine then L.Add(S);
          S := IntfSyms.FindNext(S);
        end;
      end;
      Target := PairRoutine(R, L);
      Break;
    end;
    { on a method's declaration in a class: its implementation, of overloads the one with its
      parameters }
    if Target = nil then
      for T := 0 to 1 do
      begin
        for I := 0 to Tables[T].Count - 1 do
        begin
          S := Tables[T][I];
          if (S.Kind <> skType) or (S.TypeDesc = nil) or not (S.TypeDesc.Kind in [tyClass, tyObject]) or
            (S.TypeDesc.Members = nil) or not Overlaps(S.DeclStart, S.TypeDesc.EndOfs) then Continue;
          Desc := S.TypeDesc;
          for J := 0 to Desc.Members.Count - 1 do
          begin
            M := Desc.Members[J];
            if (M.Kind <> skRoutine) or not (M is TRoutineSym) or
              not Overlaps(TRoutineSym(M).HeadStart, M.FullEnd) then Continue;
            L.Clear;
            GetImpls(L, S.Name, M.Name);
            Target := PairRoutine(M, L);
            Break;
          end;
          if Target <> nil then Break;
        end;
        if Target <> nil then Break;
      end;
    { on a routine's declaration in the interface: its implementation, of overloads the one with
      its parameters }
    if Target = nil then
      for I := 0 to IntfSyms.Count - 1 do
      begin
        S := IntfSyms[I];
        if (S.Kind <> skRoutine) or not (S is TRoutineSym) or (sfImplBody in S.Flags) or
          (TRoutineSym(S).ClassQual <> '') or not Overlaps(TRoutineSym(S).HeadStart, S.FullEnd) then Continue;
        L.Clear;
        GetImpls(L, '', S.Name);
        Target := PairRoutine(S, L);
        Break;
      end;
  finally
    L.Free;
  end;
  if Target = nil then Exit;
  ToLine := Target.Line;
  ToCol := Target.Col;
  Result := True;
end;

{ TPasParser }

constructor TPasParser.Create(AUnit: TUnitInfo; ALexer: TPasLexer);
begin
  inherited Create;
  U := AUnit;
  L := ALexer;
  if U <> nil then FTable := U.IntfSyms;
end;

procedure TPasParser.Next;
begin
  FPrevEnd := L.Tok.Start + L.Tok.Len;
  L.Next;
  Inc(FSeq);
end;

function TPasParser.IsKw(K: TKeyword): Boolean;
begin
  Result := L.Tok.Keyword = K;
end;

function TPasParser.IsSym(S: TSymbolId): Boolean;
begin
  Result := L.Tok.Symbol = S;
end;

function TPasParser.IsDir(D: TDirective): Boolean;
begin
  Result := (L.Tok.Kind = tkIdent) and (L.Tok.Directive = D);
end;

procedure TPasParser.InitSym(S: TSymbol; AKind: TSymKind);
begin
  S.Kind := AKind;
  S.Name := L.TokenText;
  S.Line := L.Tok.Line;
  S.Col := L.Tok.Col;
  S.DeclStart := L.Tok.Start;
  S.DeclEnd := L.Tok.Start + L.Tok.Len;
  S.UnitInfo := U;
  if FInImpl then Include(S.Flags, sfInImpl);
end;

function TPasParser.NewDesc(AKind: TTypeKind): TTypeDesc;
begin
  Result := TTypeDesc.Create;
  Result.Kind := AKind;
  Result.UnitInfo := U;
  Result.InImpl := FInImpl;
  Result.OwnerRoutine := FOwnerRoutine;
end;

function TPasParser.ParseQualIdent: string;
begin
  Result := '';
  if L.Tok.Kind <> tkIdent then Exit;
  Result := L.TokenText;
  Next;
  while IsSym(syDot) and (L.Peek^.Kind = tkIdent) do
  begin
    Next;
    Result := Result + '.' + L.TokenText;
    Next;
  end;
end;

{ Skips to and consumes the next ';' at nesting depth 0. Stops (without
  consuming) at a synchronising keyword. FSemiPos = offset where the
  declaration text ends. }
procedure TPasParser.SkipToSemi;
var
  Depth: Integer;
begin
  Depth := 0;
  while L.Tok.Kind <> tkEOF do
  begin
    if L.Tok.Kind = tkSymbol then
    begin
      case L.Tok.Symbol of
        syLParen, syLBracket: Inc(Depth);
        syRParen, syRBracket: if Depth > 0 then Dec(Depth);
        sySemicolon:
          if Depth = 0 then
          begin
            FSemiPos := FPrevEnd;
            Next;
            Exit;
          end;
      end;
    end
    else if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in SyncKeywords) then
      Break;
    Next;
  end;
  FSemiPos := FPrevEnd;
end;

{ current token is '(' or '['; skips to just after the matching close }
procedure TPasParser.SkipBalanced;
var
  Depth: Integer;
begin
  Depth := 0;
  while L.Tok.Kind <> tkEOF do
  begin
    if L.Tok.Kind = tkSymbol then
    begin
      case L.Tok.Symbol of
        syLParen, syLBracket: Inc(Depth);
        syRParen, syRBracket:
          begin
            Dec(Depth);
            if Depth <= 0 then
            begin
              Next;
              Exit;
            end;
          end;
      end;
    end
    else if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in ParenSyncKeywords) then
      Exit;
    Next;
  end;
end;

{ to the first of the symbols Stops at bracket depth 0 - a closing bracket there ends it too - or,
  with Sync, to a synchronising keyword; the token there is not consumed }
procedure TPasParser.SkipExpr(Stops: TSymbolSet; Sync: Boolean);
var
  Depth: Integer;
begin
  Depth := 0;
  while L.Tok.Kind <> tkEOF do
  begin
    if L.Tok.Kind = tkSymbol then
      case L.Tok.Symbol of
        syLParen, syLBracket: Inc(Depth);
        syRParen, syRBracket:
          begin
            if Depth = 0 then Exit;
            Dec(Depth);
          end;
      else
        if (Depth = 0) and (L.Tok.Symbol in Stops) then Exit;
      end
    else if Sync and (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in SyncKeywords) then
      Exit;
    Next;
  end;
end;

{ the calling conventions after a procedural type ("TFoo = procedure; stdcall;"), with their ';' }
procedure TPasParser.SkipCallConv(TD: TTypeDesc);
begin
  if (TD <> nil) and (TD.Kind = tyProc) then
    while (L.Tok.Kind = tkIdent) and (L.Tok.Directive in CallConvDirs) and
      (L.Peek^.Symbol = sySemicolon) do
    begin
      Next;
      Next;
    end;
end;

{ current token is '(' or '[': the bracketed parameter list skipped, PS..PE the text inside }
procedure TPasParser.SkipParams(out PS, PE: Integer);
begin
  PS := L.Tok.Start + 1;
  SkipBalanced;
  PE := FPrevEnd - 1;
  if PE < PS then PE := PS;
end;

{ the names of a declaration up to the last of its comma separated list: new symbols in List }
procedure TPasParser.ReadNames(List: TList; AKind: TSymKind; AOwner: TObject; AVis: TVisibility;
  AFlags: TSymFlags);
var
  S: TSymbol;
begin
  while L.Tok.Kind = tkIdent do
  begin
    S := TSymbol.Create;
    InitSym(S, AKind);
    S.Visibility := AVis;
    S.Flags := S.Flags + AFlags;
    S.Owner := AOwner;
    List.Add(S);
    Next;
    if IsSym(syComma) then Next else Break;
  end;
end;

{ the names List[First..] of one declaration get its type (TD, the text TS..TE - the first name
  owns TD), the end of the declaration ADeclEnd and FullEnd the end of what was read; Table (if
  any) takes them }
procedure TPasParser.TypeNames(List: TList; First: Integer; TD: TTypeDesc; TS, TE, ADeclEnd: Integer;
  Table: TSymTable; AFlags: TSymFlags);
var
  I: Integer;
  S: TSymbol;
begin
  for I := First to List.Count - 1 do
  begin
    S := TSymbol(List[I]);
    S.TypeDesc := TD;
    S.TypeStart := TS;
    S.TypeEnd := TE;
    S.DeclEnd := ADeclEnd;
    S.FullEnd := FPrevEnd;
    S.Flags := S.Flags + AFlags;
    if (I = First) and (TD <> nil) then Include(S.Flags, sfOwnsType);
    if Table <> nil then Table.Add(S);
  end;
end;

{ current token is '(': the ancestor (Several: the ancestor and the interfaces) of a class,
  object or interface, up to after the ')' }
procedure TPasParser.ParseAncestors(D: TTypeDesc; Several: Boolean);
begin
  Next;
  D.Ancestors := TStringList.Create;
  while L.Tok.Kind = tkIdent do
  begin
    D.Ancestors.Add(ParseQualIdent);
    if not Several or not IsSym(syComma) then Break;
    Next;
  end;
  if IsSym(syRParen) then Next;
  D.HeaderEnd := FPrevEnd;
end;

procedure TPasParser.SkipTypeExpr;
var
  Depth: Integer;
begin
  Depth := 0;
  while L.Tok.Kind <> tkEOF do
  begin
    case L.Tok.Kind of
      tkSymbol:
        case L.Tok.Symbol of
          syLParen, syLBracket: Inc(Depth);
          syRParen, syRBracket:
            begin
              if Depth = 0 then Exit;
              Dec(Depth);
            end;
          sySemicolon, syEqual, syComma:
            if Depth = 0 then Exit;
        end;
      tkKeyword:
        if not (L.Tok.Keyword in [kwDiv, kwMod, kwShl, kwShr, kwAnd, kwOr, kwNot, kwXor, kwNil]) then
          Exit;
    end;
    Next;
  end;
end;

procedure TPasParser.SkipHints;
begin
  while IsDir(dvDeprecated) or IsDir(dvPlatform) do Next;
end;

procedure TPasParser.ParseUses(List: TStringList; InIntf: Boolean);
var
  UName: string;
  StartOfs: Integer;
begin
  StartOfs := L.Tok.Start;
  Next;
  while L.Tok.Kind <> tkEOF do
  begin
    if L.Tok.Kind = tkIdent then
    begin
      UName := L.TokenText;
      List.AddObject(UName, TObject((L.Tok.Line shl 10) or (L.Tok.Col and 1023)));
      Next;
      if IsKw(kwIn) then
      begin
        Next;
        if L.Tok.Kind = tkString then
        begin
          if L.Tok.PLen >= 2 then
            U.UsesIn.Add(UName + '=' + Copy(L.TokenText, 2, L.Tok.PLen - 2));
          Next;
        end;
      end;
    end
    else if IsSym(syComma) then
      Next
    else if IsSym(sySemicolon) then
    begin
      if InIntf then
      begin
        if U.IntfUsesStart = 0 then
        begin
          U.IntfUsesStart := StartOfs;
          U.IntfUsesEnd := L.Tok.Start;
        end;
      end
      else if U.ImplUsesStart = 0 then
      begin
        U.ImplUsesStart := StartOfs;
        U.ImplUsesEnd := L.Tok.Start;
      end;
      Next;
      Exit;
    end
    else
      Break;
  end;
end;

{ the characters a string literal stands for: a quoted part's (a doubled quote is one), one per
  #n }
function LiteralLength(P: PChar; Len: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  I := 0;
  while I < Len do
    if P[I] = '''' then
    begin
      Inc(I);
      while I < Len do
        if P[I] <> '''' then
        begin
          Inc(Result);
          Inc(I);
        end
        else if (I + 1 < Len) and (P[I + 1] = '''') then
        begin
          Inc(Result);
          Inc(I, 2);
        end
        else
        begin
          Inc(I);
          Break;
        end;
    end
    else if P[I] = '#' then
    begin
      Inc(Result);
      Inc(I);
      if (I < Len) and (P[I] = '$') then Inc(I);
      while (I < Len) and (P[I] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(I);
    end
    else
      Inc(I);
end;

{ The type of an untyped constant, from the first token of its value (the current one): a
  literal - a string (Char when it stands for one character), a number, a signed number - only
  when it is the whole value: LitEnd is its end, the caller checks that the value ends there
  (1 + 2 / 3 is no Integer, #13#10 no Char, 'a' + 'b' no Char). True / False, nil and a
  typecast name the type of any value they start (LitEnd -1). '' = not known. }
function TPasParser.ConstLiteralType(out LitEnd: Integer): string;
var
  T: PToken;
  I: Integer;
  HasDot: Boolean;
begin
  Result := '';
  LitEnd := -1;
  T := @L.Tok;
  if (T.Kind = tkSymbol) and (T.Symbol in [syMinus, syPlus]) and (L.Peek^.Kind = tkNumber) then
    T := L.Peek;
  case T.Kind of
    tkString:
      if LiteralLength(T.Ptr, T.PLen) = 1 then Result := 'Char' else Result := 'string';
    tkNumber:
      begin
        HasDot := False;
        if T.Ptr^ <> '$' then
          for I := 0 to T.PLen - 1 do
            if T.Ptr[I] in ['.', 'e', 'E'] then HasDot := True;
        if HasDot then Result := 'Extended' else Result := 'Integer';
      end;
    tkIdent:
      if L.TokenIs('TRUE') or L.TokenIs('FALSE') then Result := 'Boolean'
      else if L.Peek^.Symbol = syLParen then Result := L.TokenText;
    tkKeyword:
      if T.Keyword = kwNil then Result := 'Pointer';
  end;
  if T.Kind in [tkString, tkNumber] then LitEnd := T.Start + T.Len;
end;

procedure TPasParser.ParseConstSection(IsResStr: Boolean);
var
  S: TSymbol;
  Seq, LitEnd: Integer;
  TN: string;
begin
  Next;
  while L.Tok.Kind = tkIdent do
  begin
    Seq := FSeq;
    S := TSymbol.Create;
    if IsResStr then InitSym(S, skResStr) else InitSym(S, skConst);
    S.Owner := FOwnerRoutine;
    TN := '';
    LitEnd := -1;
    Next;
    if IsSym(syColon) then
    begin
      Next;
      S.TypeStart := L.Tok.Start;
      S.TypeDesc := ParseType;
      S.TypeEnd := FPrevEnd;
      if S.TypeDesc <> nil then Include(S.Flags, sfOwnsType);
    end;
    if IsSym(syEqual) then
    begin
      Next;
      if S.TypeDesc = nil then
      begin
        if IsResStr then
        begin
          S.TypeDesc := NewDesc(tyAlias);
          S.TypeDesc.RefName := 'string';
          Include(S.Flags, sfOwnsType);
        end
        else
          TN := ConstLiteralType(LitEnd);
      end;
    end;
    SkipToSemi;
    S.DeclEnd := FSemiPos;
    S.FullEnd := FPrevEnd;
    if (TN <> '') and ((LitEnd < 0) or (LitEnd = FSemiPos)) then
    begin
      S.TypeDesc := NewDesc(tyAlias);
      S.TypeDesc.RefName := TN;
      Include(S.Flags, sfOwnsType);
    end;
    FTable.Add(S);
    if FSeq = Seq then Next;
  end;
end;

procedure TPasParser.ParseTypeSection;
var
  S, Old: TSymbol;
  TD: TTypeDesc;
  Seq: Integer;
begin
  Next;
  while L.Tok.Kind = tkIdent do
  begin
    Seq := FSeq;
    if L.Peek^.Symbol <> syEqual then
    begin
      // not a type declaration ('Name =' expected): skip it
      Next;
      SkipToSemi;
      if FSeq = Seq then Next;
      Continue;
    end;
    S := TSymbol.Create;
    InitSym(S, skType);
    S.Owner := FOwnerRoutine;
    Next;   // name
    Next;   // '='
    S.TypeStart := L.Tok.Start;
    TD := ParseType;
    S.TypeEnd := FPrevEnd;
    S.TypeDesc := TD;
    if TD <> nil then
    begin
      Include(S.Flags, sfOwnsType);
      TD.Sym := S;
      if (TD.Kind in [tyClass, tyInterface, tyRecord, tyObject]) and (TD.HeaderEnd > 0) then
        S.DeclEnd := TD.HeaderEnd
      else
        S.DeclEnd := FPrevEnd;
    end
    else
      S.DeclEnd := FPrevEnd;
    SkipHints;
    if IsSym(sySemicolon) then Next
    else if not ((L.Tok.Kind = tkKeyword) or (L.Tok.Kind = tkEOF)) then SkipToSemi;
    SkipCallConv(TD);
    S.FullEnd := FPrevEnd;
    // replace a forward declaration
    Old := FTable.Find(S.Name);
    while (Old <> nil) and not ((Old.Kind = skType) and (Old.TypeDesc <> nil) and Old.TypeDesc.IsForward) do
      Old := FTable.FindNext(Old);
    if (Old <> nil) and (TD <> nil) and (TD.Kind = Old.TypeDesc.Kind) and not TD.IsForward then
    begin
      if sfOwnsType in Old.Flags then Old.TypeDesc.Free;
      Old.TypeDesc := TD;
      Include(Old.Flags, sfOwnsType);
      TD.Sym := Old;
      Old.Line := S.Line;
      Old.Col := S.Col;
      Old.DeclStart := S.DeclStart;
      Old.DeclEnd := S.DeclEnd;
      Old.TypeStart := S.TypeStart;
      Old.TypeEnd := S.TypeEnd;
      Old.FullEnd := S.FullEnd;
      Old.DispDecl := '';
      Exclude(Old.Flags, sfDispReady);
      Exclude(S.Flags, sfOwnsType);
      S.TypeDesc := nil;
      S.Free;
    end
    else
      FTable.Add(S);
    if FSeq = Seq then Next;
  end;
end;

procedure TPasParser.ParseVarSection;
var
  Names: TList;
  TD: TTypeDesc;
  TS, TE, I, Seq: Integer;
  Kind: TSymKind;
begin
  Next;   // var / threadvar
  if FOwnerRoutine <> nil then Kind := skLocal else Kind := skVar;
  Names := TList.Create;
  try
    while L.Tok.Kind = tkIdent do
    begin
      Seq := FSeq;
      Names.Clear;
      ReadNames(Names, Kind, FOwnerRoutine, viNone, []);
      if not IsSym(syColon) then
      begin
        // not a variable declaration (broken code): discard
        for I := 0 to Names.Count - 1 do TObject(Names[I]).Free;
        Names.Clear;
        SkipToSemi;
        if FSeq = Seq then Next;
        Continue;
      end;
      Next;
      TS := L.Tok.Start;
      TD := ParseType;
      TE := FPrevEnd;
      if IsDir(dvAbsolute) then
      begin
        Next;
        if L.Tok.Kind in [tkIdent, tkNumber] then Next;
        while IsSym(syDot) do
        begin
          Next;
          if L.Tok.Kind = tkIdent then Next;
        end;
      end;
      SkipHints;
      if IsSym(sySemicolon) then
      begin
        FSemiPos := FPrevEnd;
        Next;
      end
      else
        SkipToSemi;
      SkipCallConv(TD);
      TypeNames(Names, 0, TD, TS, TE, TE, FTable, []);
      Names.Clear;
      if FSeq = Seq then Next;
    end;
  finally
    for I := 0 to Names.Count - 1 do TObject(Names[I]).Free;
    Names.Free;
  end;
end;

function TPasParser.ParseType: TTypeDesc;
var
  S: string;
begin
  Result := nil;
  if FDepth > MaxDepth then Exit;
  Inc(FDepth);
  try
    case L.Tok.Kind of
      tkIdent:
        begin
          S := ParseQualIdent;
          if (L.Tok.Kind = tkSymbol) and (L.Tok.Symbol in [syDotDot, syLParen, syPlus, syMinus, syStar, sySlash]) then
          begin
            SkipTypeExpr;
            Result := NewDesc(tySubrange);
            Result.RefName := S;
          end
          else
          begin
            Result := NewDesc(tyAlias);
            Result.RefName := S;
          end;
        end;
      tkKeyword:
        case L.Tok.Keyword of
          kwString:
            begin
              Next;
              if IsSym(syLBracket) then SkipBalanced;
              Result := NewDesc(tyAlias);
              Result.RefName := 'string';
            end;
          kwArray: Result := ParseArray;
          kwSet:
            begin
              Next;
              if IsKw(kwOf) then Next;
              Result := NewDesc(tySet);
              Result.Elem := ParseType;
            end;
          kwFile:
            begin
              Next;
              Result := NewDesc(tyFile);
              if IsKw(kwOf) then
              begin
                Next;
                Result.Elem := ParseType;
              end;
            end;
          kwRecord: Result := ParseRecord;
          kwPacked:
            begin
              Next;
              Result := ParseType;
            end;
          kwClass: Result := ParseClass;
          kwObject: Result := ParseObject;
          kwInterface, kwDispinterface: Result := ParseInterface;
          kwProcedure, kwFunction: Result := ParseProcType;
          kwType:
            begin
              Next;
              Result := ParseType;
            end;
        end;
      tkSymbol:
        case L.Tok.Symbol of
          syCaret:
            begin
              Next;
              Result := NewDesc(tyPointer);
              Result.Elem := ParseType;
            end;
          syLParen: Result := ParseEnum;
          syMinus, syPlus:
            begin
              SkipTypeExpr;
              Result := NewDesc(tySubrange);
            end;
        end;
      tkNumber, tkString:
        begin
          SkipTypeExpr;
          Result := NewDesc(tySubrange);
        end;
    end;
  finally
    Dec(FDepth);
  end;
end;

function TPasParser.ParseArray: TTypeDesc;
var
  Dims, Depth, I: Integer;
  Elem, Outer: TTypeDesc;
begin
  Next;  // array
  Dims := 0;
  if IsSym(syLBracket) then
  begin
    Next;
    Depth := 1;
    Dims := 1;
    while (L.Tok.Kind <> tkEOF) and (Depth > 0) do
    begin
      if L.Tok.Kind = tkSymbol then
      begin
        case L.Tok.Symbol of
          syLBracket, syLParen: Inc(Depth);
          syRBracket, syRParen: Dec(Depth);
          syComma: if Depth = 1 then Inc(Dims);
          sySemicolon: Break;
        end;
      end
      else if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in SyncKeywords + [kwOf]) then
        Break;
      if Depth > 0 then Next;
    end;
    if IsSym(syRBracket) then Next;
  end;
  if IsKw(kwOf) then Next;
  if IsKw(kwConst) then
  begin
    Next;
    Elem := NewDesc(tyAlias);
    Elem.RefName := 'TVarRec';
  end
  else
    Elem := ParseType;
  Result := NewDesc(tyArray);
  Result.Elem := Elem;
  for I := 2 to Dims do
  begin
    Outer := NewDesc(tyArray);
    Outer.Elem := Result;
    Result := Outer;
  end;
end;

function TPasParser.ParseEnum: TTypeDesc;
var
  V: TSymbol;
begin
  Result := NewDesc(tyEnum);
  Next;  // (
  while L.Tok.Kind = tkIdent do
  begin
    V := TSymbol.Create;
    InitSym(V, skEnumValue);
    V.TypeDesc := Result;
    V.Owner := FOwnerRoutine;
    Next;
    if IsSym(syEqual) then
    begin
      Next;
      SkipExpr([syComma, sySemicolon], True);
    end;
    V.FullEnd := FPrevEnd;
    if FTable <> nil then FTable.Add(V) else V.Free;
    if IsSym(syComma) then Next else Break;
  end;
  if IsSym(syRParen) then Next;
end;

function TPasParser.ParseRecord: TTypeDesc;
begin
  Result := NewDesc(tyRecord);
  Result.Members := TSymTable.Create;
  Next;  // record
  Result.HeaderEnd := FPrevEnd;
  ParseFieldList(Result, False);
  if IsKw(kwEnd) then
  begin
    Result.EndOfs := L.Tok.Start;
    Next;
  end;
end;

procedure TPasParser.ParseFieldList(Desc: TTypeDesc; InVariant: Boolean);
var
  Seq: Integer;
begin
  if FDepth > MaxDepth then Exit;
  Inc(FDepth);
  try
    while L.Tok.Kind <> tkEOF do
    begin
      Seq := FSeq;
      case L.Tok.Kind of
        tkIdent: ParseFieldDecl(Desc, viPublic);
        tkKeyword:
          case L.Tok.Keyword of
            kwEnd: Exit;
            kwCase: ParseVariantPart(Desc);
            kwProcedure, kwFunction, kwConstructor, kwDestructor, kwProperty, kwClass:
              begin
                // methods in old-style objects / tolerated
                ParseClassBody(Desc, viPublic);
                Exit;
              end;
          else
            if L.Tok.Keyword in SyncKeywords then Exit;
            Next;
          end;
        tkSymbol:
          begin
            if InVariant and (L.Tok.Symbol = syRParen) then Exit;
            Next;
          end;
      else
        Next;
      end;
      if FSeq = Seq then Next;
    end;
  finally
    Dec(FDepth);
  end;
end;

procedure TPasParser.ParseFieldDecl(Desc: TTypeDesc; Vis: TVisibility);
var
  Names: TList;
  TD: TTypeDesc;
  TS, TE, I: Integer;
begin
  Names := TList.Create;
  try
    ReadNames(Names, skField, Desc, Vis, []);
    if IsSym(syColon) then
    begin
      Next;
      TS := L.Tok.Start;
      TD := ParseType;
      TE := FPrevEnd;
    end
    else
    begin
      // not a field declaration: drop the names, resynchronise
      for I := 0 to Names.Count - 1 do TObject(Names[I]).Free;
      Names.Clear;
      if not (IsSym(sySemicolon) or IsKw(kwEnd) or IsSym(syRParen)) then
        while (L.Tok.Kind <> tkEOF) and not IsSym(sySemicolon) and
          not (L.Tok.Kind = tkKeyword) and not IsSym(syRParen) do Next;
      if IsSym(sySemicolon) then Next;
      Exit;
    end;
    SkipHints;
    if IsSym(sySemicolon) then Next
    else if not (IsKw(kwEnd) or IsSym(syRParen) or IsKw(kwCase)) then
    begin
      while (L.Tok.Kind <> tkEOF) and not IsSym(sySemicolon) and
        not (L.Tok.Kind = tkKeyword) and not IsSym(syRParen) do Next;
      if IsSym(sySemicolon) then Next;
    end;
    TypeNames(Names, 0, TD, TS, TE, TE, Desc.Members, []);
    Names.Clear;
  finally
    for I := 0 to Names.Count - 1 do TObject(Names[I]).Free;
    Names.Free;
  end;
end;

procedure TPasParser.ParseVariantPart(Desc: TTypeDesc);
var
  S: TSymbol;
  Seq: Integer;
begin
  Next;  // case
  if (L.Tok.Kind = tkIdent) and (L.Peek^.Symbol = syColon) then
  begin
    S := TSymbol.Create;
    InitSym(S, skField);
    S.Visibility := viPublic;
    S.Owner := Desc;
    Next;
    Next;
    S.TypeStart := L.Tok.Start;
    S.TypeDesc := ParseType;
    S.TypeEnd := FPrevEnd;
    S.DeclEnd := FPrevEnd;
    S.FullEnd := FPrevEnd;
    if S.TypeDesc <> nil then Include(S.Flags, sfOwnsType);
    Desc.Members.Add(S);
  end;
  while (L.Tok.Kind <> tkEOF) and not IsKw(kwOf) and not IsKw(kwEnd) and not IsSym(sySemicolon) do
    Next;
  if IsKw(kwOf) then Next;
  while L.Tok.Kind <> tkEOF do
  begin
    Seq := FSeq;
    if IsKw(kwEnd) or IsSym(syRParen) then Exit;
    if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword in SyncKeywords) then Exit;
    // constant list up to ':'
    SkipExpr([syColon, sySemicolon], True);
    if IsSym(syColon) then
    begin
      Next;
      if IsSym(syLParen) then
      begin
        Next;
        ParseFieldList(Desc, True);
        if IsSym(syRParen) then Next;
      end;
    end;
    if IsSym(sySemicolon) then Next;
    if FSeq = Seq then Next;
  end;
end;

function TPasParser.ParseClass: TTypeDesc;
var
  HasParen: Boolean;
begin
  Next;  // class
  if IsKw(kwOf) then
  begin
    Next;
    Result := NewDesc(tyClassRef);
    Result.RefName := ParseQualIdent;
    Exit;
  end;
  Result := NewDesc(tyClass);
  Result.HeaderEnd := FPrevEnd;
  HasParen := IsSym(syLParen);
  if HasParen then ParseAncestors(Result, True);
  if IsSym(sySemicolon) then
  begin
    if not HasParen then Result.IsForward := True;
    Result.Members := TSymTable.Create;
    Exit;
  end;
  Result.Members := TSymTable.Create;
  ParseClassBody(Result, viPublished);
end;

function TPasParser.ParseObject: TTypeDesc;
begin
  Next;  // object
  Result := NewDesc(tyObject);
  Result.HeaderEnd := FPrevEnd;
  Result.Members := TSymTable.Create;
  if IsSym(syLParen) then ParseAncestors(Result, False);
  ParseClassBody(Result, viPublic);
end;

function TPasParser.ParseInterface: TTypeDesc;
begin
  Next;  // interface / dispinterface
  Result := NewDesc(tyInterface);
  Result.HeaderEnd := FPrevEnd;
  Result.Members := TSymTable.Create;
  if IsSym(sySemicolon) then
  begin
    Result.IsForward := True;
    Exit;
  end;
  if IsSym(syLParen) then
  begin
    ParseAncestors(Result, False);
    if IsSym(sySemicolon) then Exit;
  end;
  if IsSym(syLBracket) then SkipBalanced;
  ParseClassBody(Result, viPublic);
end;

function TPasParser.ParseProcType: TTypeDesc;
begin
  Result := NewDesc(tyProc);
  Result.IsFunction := IsKw(kwFunction);
  Next;
  if IsSym(syLParen) then SkipParams(Result.ParamsStart, Result.ParamsEnd);
  if IsSym(syColon) then
  begin
    Next;
    Result.Elem := ParseType;
  end;
  if IsKw(kwOf) then
  begin
    Next;
    if IsKw(kwObject) then Next;
  end;
  while (L.Tok.Kind = tkIdent) and (L.Tok.Directive in CallConvDirs) do Next;
end;

procedure TPasParser.ParseClassBody(Desc: TTypeDesc; DefaultVis: TVisibility);
var
  Vis: TVisibility;
  Seq, HS: Integer;
  R: TRoutineSym;
  P: PToken;
  IsClass: Boolean;
begin
  if FDepth > MaxDepth then Exit;
  Inc(FDepth);
  try
    Vis := DefaultVis;
    while L.Tok.Kind <> tkEOF do
    begin
      Seq := FSeq;
      case L.Tok.Kind of
        tkKeyword:
          case L.Tok.Keyword of
            kwEnd:
              begin
                Desc.EndOfs := L.Tok.Start;
                Next;
                Exit;
              end;
            kwProcedure, kwFunction, kwConstructor, kwDestructor, kwClass:
              begin
                HS := L.Tok.Start;
                IsClass := IsKw(kwClass);
                if IsClass then Next;
                if not IsClass or IsKw(kwProcedure) or IsKw(kwFunction) then
                begin
                  R := ParseRoutineHeading(HS, IsClass);
                  if R <> nil then
                  begin
                    R.Visibility := Vis;
                    R.Owner := Desc;
                    Desc.Members.Add(R);
                  end;
                end;
              end;
            kwProperty: ParseProperty(Desc, Vis);
            kwCase: ParseVariantPart(Desc);
            kwImplementation, kwInitialization, kwFinalization, kwBegin, kwType,
            kwConst, kwVar, kwUses, kwUnit, kwInterface, kwResourcestring,
            kwThreadvar, kwProgram, kwLibrary:
              Exit;   // class body not terminated
          else
            Next;
          end;
        tkIdent:
          begin
            if L.Tok.Directive in VisibilityDirs then
            begin
              P := L.Peek;
              if not ((P^.Kind = tkSymbol) and (P^.Symbol in [syColon, syComma])) then
              begin
                if Desc.FirstVisOfs = 0 then Desc.FirstVisOfs := L.Tok.Start;
                case L.Tok.Directive of
                  dvPrivate: Vis := viPrivate;
                  dvProtected: Vis := viProtected;
                  dvPublic, dvAutomated: Vis := viPublic;
                  dvPublished: Vis := viPublished;
                end;
                Next;
                Continue;
              end;
            end;
            ParseFieldDecl(Desc, Vis);
          end;
      else
        Next;
      end;
      if FSeq = Seq then Next;
    end;
  finally
    Dec(FDepth);
  end;
end;

procedure TPasParser.ParseProperty(Desc: TTypeDesc; Vis: TVisibility);
var
  S: TRoutineSym;
  PS: Integer;
begin
  PS := L.Tok.Start;
  Next;  // property
  if L.Tok.Kind <> tkIdent then
  begin
    SkipToSemi;
    Exit;
  end;
  S := TRoutineSym.Create;
  InitSym(S, skProperty);
  S.HeadStart := PS;
  S.Visibility := Vis;
  S.Owner := Desc;
  Next;
  if IsSym(syLBracket) then
  begin
    Include(S.Flags, sfArrayProp);
    SkipParams(S.ParamsStart, S.ParamsEnd);
  end;
  if IsSym(syColon) then
  begin
    Next;
    S.TypeStart := L.Tok.Start;
    S.TypeDesc := ParseType;
    S.TypeEnd := FPrevEnd;
    if S.TypeDesc <> nil then Include(S.Flags, sfOwnsType);
  end;
  S.DeclEnd := FPrevEnd;
  SkipToSemi;
  if IsDir(dvDefault) and (L.Peek^.Symbol = sySemicolon) then
  begin
    Desc.DefaultProp := S;
    Next;
    Next;
  end;
  S.FullEnd := FPrevEnd;
  Desc.Members.Add(S);
end;

function TPasParser.ParseRoutineHeading(HeadStart: Integer; IsClass: Boolean): TRoutineSym;
var
  K: TKeyword;
  R: TRoutineSym;
begin
  Result := nil;
  K := L.Tok.Keyword;
  Next;
  if L.Tok.Kind <> tkIdent then Exit;
  R := TRoutineSym.Create;
  InitSym(R, skRoutine);
  R.HeadStart := HeadStart;
  R.Owner := FOwnerRoutine;
  Next;
  while IsSym(syDot) do
  begin
    Next;
    if L.Tok.Kind = tkIdent then
    begin
      if R.ClassQual <> '' then R.ClassQual := R.ClassQual + '.' + R.Name
      else R.ClassQual := R.Name;
      R.Name := L.TokenText;
      R.Line := L.Tok.Line;
      R.Col := L.Tok.Col;
      R.DeclStart := L.Tok.Start;
      Next;
    end
    else
    begin
      // 'procedure TForm1.' being typed
      R.ClassQual := R.Name;
      R.Name := '';
      Break;
    end;
  end;
  if IsSym(syEqual) then
  begin
    // method resolution clause: procedure IFoo.Bar = Baz;
    SkipToSemi;
    R.Free;
    Exit;
  end;
  case K of
    kwFunction: Include(R.Flags, sfFunction);
    kwConstructor: Include(R.Flags, sfConstructor);
    kwDestructor: Include(R.Flags, sfDestructor);
  end;
  if IsClass then Include(R.Flags, sfClassMethod);
  if IsSym(syLParen) then SkipParams(R.ParamsStart, R.ParamsEnd);
  if IsSym(syColon) then
  begin
    Next;
    R.TypeStart := L.Tok.Start;
    R.TypeDesc := ParseType;
    R.TypeEnd := FPrevEnd;
    if R.TypeDesc <> nil then Include(R.Flags, sfOwnsType);
  end;
  R.DeclEnd := FPrevEnd;
  ParseRoutineDirectives(R);
  R.FullEnd := FPrevEnd;
  Result := R;
end;

procedure TPasParser.ParseRoutineDirectives(R: TRoutineSym);
var
  P: PToken;
  D: TDirective;
begin
  while True do
  begin
    if IsSym(sySemicolon) then Next;
    if (L.Tok.Kind = tkIdent) and (L.Tok.Directive in RoutineDirs) then
    begin
      P := L.Peek;
      if (P^.Kind = tkSymbol) and (P^.Symbol in [syColon, syComma, syEqual, syAssign, syDot, syLParen, syLBracket, syCaret]) then
        Break;
      D := L.Tok.Directive;
      case D of
        dvOverload: Include(R.Flags, sfOverload);
        dvVirtual: Include(R.Flags, sfVirtual);
        dvDynamic: Include(R.Flags, sfDynamic);
        dvOverride: Include(R.Flags, sfOverride);
        dvAbstract: Include(R.Flags, sfAbstract);
        dvForward: Include(R.Flags, sfForward);
        dvExternal: Include(R.Flags, sfExternal);
      end;
      Next;
      if D in [dvMessage, dvExternal, dvDispid] then
        SkipToSemi;
    end
    else
      Break;
  end;
end;

procedure TPasParser.ParseIntfRoutine(HeadStart: Integer; IsClass: Boolean);
var
  R: TRoutineSym;
begin
  R := ParseRoutineHeading(HeadStart, IsClass);
  if R = nil then Exit;
  if (R.Name = '') or (FTable = nil) then
    R.Free
  else
    FTable.Add(R);
end;

procedure TPasParser.ParseImplRoutine(HeadStart: Integer; IsClass: Boolean);
var
  R: TRoutineSym;
  Old: TSymbol;
  SaveTable: TSymTable;
  SaveOwner: TRoutineSym;
  InTable: Boolean;
begin
  R := ParseRoutineHeading(HeadStart, IsClass);
  if R = nil then Exit;
  Include(R.Flags, sfImplBody);
  // register
  if FOwnerRoutine <> nil then
  begin
    if FOwnerRoutine.Locals = nil then FOwnerRoutine.Locals := TSymTable.Create;
    FOwnerRoutine.Locals.Add(R);
  end
  else
  begin
    InTable := False;
    if (R.ClassQual = '') and (R.Name <> '') and (FTable <> nil) then
    begin
      InTable := True;
      // interface declaration exists -> the body is not a new unit level symbol
      Old := U.IntfSyms.Find(R.Name);
      while (Old <> nil) and (Old.Kind <> skRoutine) do Old := U.IntfSyms.FindNext(Old);
      if (Old <> nil) and not U.IsProgram then InTable := False;
      if InTable and not ((sfForward in R.Flags) or (sfExternal in R.Flags)) then
      begin
        Old := FTable.Find(R.Name);
        while (Old <> nil) and not ((Old.Kind = skRoutine) and (sfForward in Old.Flags)) do
          Old := FTable.FindNext(Old);
        if Old <> nil then InTable := False;
      end;
    end;
    if InTable then FTable.Add(R) else U.OwnedExtra.Add(R);
    if not ((sfForward in R.Flags) or (sfExternal in R.Flags)) then
      U.ImplRoutines.Add(R);
  end;
  if (sfForward in R.Flags) or (sfExternal in R.Flags) then
  begin
    R.BodyEnd := FPrevEnd;
    Exit;
  end;
  if FDepth > MaxDepth then Exit;
  Inc(FDepth);
  if R.Locals = nil then R.Locals := TSymTable.Create;
  SaveTable := FTable;
  SaveOwner := FOwnerRoutine;
  FTable := R.Locals;
  FOwnerRoutine := R;
  try
    ParseDeclSections(True);
    if IsKw(kwBegin) then
    begin
      R.BodyStart := L.Tok.Start;
      Include(R.Flags, sfHasBody);
      if SkipStatements(False) then Include(R.Flags, sfBodyClosed);
    end
    else if IsKw(kwAsm) then
    begin
      R.BodyStart := L.Tok.Start;
      Include(R.Flags, sfHasBody);
      SkipAsm;
      Include(R.Flags, sfBodyClosed);
    end;
    R.BodyEnd := FPrevEnd;
    if IsSym(sySemicolon) then Next;
  finally
    FTable := SaveTable;
    FOwnerRoutine := SaveOwner;
    Dec(FDepth);
  end;
end;

procedure TPasParser.ParseDeclSections(IsLocal: Boolean);
var
  Seq, HS: Integer;
  IsClass: Boolean;
begin
  while L.Tok.Kind <> tkEOF do
  begin
    Seq := FSeq;
    if L.Tok.Kind = tkKeyword then
    begin
      case L.Tok.Keyword of
        kwConst: ParseConstSection(False);
        kwResourcestring: ParseConstSection(True);
        kwType: ParseTypeSection;
        kwVar, kwThreadvar: ParseVarSection;
        kwLabel:
          begin
            Next;
            SkipToSemi;
          end;
        kwProcedure, kwFunction, kwConstructor, kwDestructor, kwClass:
          begin
            HS := L.Tok.Start;
            IsClass := IsKw(kwClass);
            if IsClass then Next;
            if not IsClass or IsKw(kwProcedure) or IsKw(kwFunction) then
              if FInImpl then ParseImplRoutine(HS, IsClass)
              else ParseIntfRoutine(HS, IsClass);
          end;
        kwExports:
          begin
            Next;
            SkipToSemi;
          end;
        kwUses:
          begin
            if IsLocal then Exit;
            if FInImpl then ParseUses(U.ImplUses, False)
            else ParseUses(U.IntfUses, True);
          end;
        kwBegin, kwAsm, kwEnd, kwImplementation, kwInitialization, kwFinalization:
          Exit;
        kwInterface, kwUnit, kwProgram, kwLibrary:
          begin
            if IsLocal then Exit;
            Next;
          end;
      else
        Next;
      end;
    end
    else
      Next;
    if FSeq = Seq then Next;
  end;
end;

{ Statements skipped by their begin / case / try ... end nesting, asm blocks whole; a keyword of
  the declarations ends them unconsumed. Not InInit: the block that starts at the current begin,
  up to after its end (True: that end was found). InInit: the statements of an initialization
  or finalization section, up to the end, initialization or finalization at depth 0 (not
  consumed). }
function TPasParser.SkipStatements(InInit: Boolean): Boolean;
var
  Depth: Integer;
begin
  Result := False;
  Depth := 0;
  while L.Tok.Kind <> tkEOF do
  begin
    if L.Tok.Kind = tkKeyword then
    begin
      case L.Tok.Keyword of
        kwBegin, kwCase, kwTry: Inc(Depth);
        kwAsm:
          begin
            SkipAsm;
            Continue;
          end;
        kwEnd:
          if InInit then
          begin
            if Depth = 0 then Exit;
            Dec(Depth);
          end
          else
          begin
            Dec(Depth);
            if Depth <= 0 then
            begin
              Next;
              Result := True;
              Exit;
            end;
          end;
        kwInitialization, kwFinalization:
          if not InInit or (Depth = 0) then Exit;
      else
        if L.Tok.Keyword in BodySyncKeywords then Exit;
      end;
    end;
    Next;
  end;
end;

{ the asm block (lexed as assembler: the lexer's AutoAsm) }
procedure TPasParser.SkipAsm;
begin
  Next;  // asm
  while (L.Tok.Kind <> tkEOF) and not IsKw(kwEnd) do Next;
  if IsKw(kwEnd) then Next;
end;

procedure TPasParser.ParseImplBody;
var
  Seq, E: Integer;
begin
  while L.Tok.Kind <> tkEOF do
  begin
    Seq := FSeq;
    ParseDeclSections(False);
    case L.Tok.Keyword of
      kwBegin:
        begin
          U.MainBegin := L.Tok.Start;
          SkipStatements(False);
          if IsSym(syDot) then
          begin
            U.FinalEndOfs := FPrevEnd - 3;
            Break;
          end;
          if IsSym(sySemicolon) then Next;
        end;
      kwAsm: SkipAsm;
      kwEnd:
        begin
          E := L.Tok.Start;
          Next;
          if IsSym(syDot) then
          begin
            U.FinalEndOfs := E;
            Break;
          end;
          if IsSym(sySemicolon) then Next;
        end;
      kwInitialization:
        begin
          U.InitOfs := L.Tok.Start;
          Next;
          SkipStatements(True);
        end;
      kwFinalization:
        begin
          U.FinalOfs := L.Tok.Start;
          Next;
          SkipStatements(True);
        end;
      kwImplementation:
        Next;
    end;
    if FSeq = Seq then Next;
  end;
end;

procedure TPasParser.ParseUnitSections;
var
  Seq: Integer;
begin
  if IsKw(kwInterface) then
  begin
    U.IntfOfs := L.Tok.Start;
    Next;
  end;
  FInImpl := False;
  FTable := U.IntfSyms;
  if IsKw(kwUses) then ParseUses(U.IntfUses, True);
  while L.Tok.Kind <> tkEOF do
  begin
    Seq := FSeq;
    ParseDeclSections(False);
    if (L.Tok.Kind = tkEOF) or IsKw(kwImplementation) then Break;
    if IsKw(kwEnd) and (L.Peek^.Symbol = syDot) then Break;
    if FSeq = Seq then Next;
  end;
  if IsKw(kwImplementation) then U.ImplOfs := L.Tok.Start
  else U.ImplOfs := MaxInt;
  if FIntfOnly then Exit;
  if IsKw(kwImplementation) then Next;
  FInImpl := True;
  FTable := U.ImplSyms;
  if IsKw(kwUses) then ParseUses(U.ImplUses, False);
  ParseImplBody;
end;

procedure TPasParser.ParseUnit(IntfOnly: Boolean);
begin
  FIntfOnly := IntfOnly;
  Next;
  FPrevEnd := 0;
  if IsKw(kwUnit) then
  begin
    Next;
    if L.Tok.Kind = tkIdent then
    begin
      U.Name := L.TokenText;
      Next;
    end;
    SkipToSemi;
    ParseUnitSections;
  end
  else
  begin
    U.IsProgram := True;
    if IsKw(kwProgram) or IsKw(kwLibrary) or IsDir(dvPackage) then
    begin
      Next;
      if L.Tok.Kind = tkIdent then
      begin
        U.Name := L.TokenText;
        Next;
      end;
      if IsSym(syLParen) then SkipBalanced;
      SkipToSemi;
    end;
    U.ImplOfs := 0;
    FInImpl := True;
    FTable := U.ImplSyms;
    if IntfOnly then
    begin
      // programs have no interface; only collect the uses clause
      if IsKw(kwUses) then ParseUses(U.ImplUses, False);
      Exit;
    end;
    ParseImplBody;
  end;
end;

procedure TPasParser.ParseParamList(List: TList; AOwner: TObject);
var
  Flags, DefFlags: TSymFlags;
  First, Seq, TS, TE: Integer;
  TD: TTypeDesc;
begin
  while L.Tok.Kind <> tkEOF do
  begin
    Seq := FSeq;
    if IsSym(syRParen) or IsSym(syRBracket) then Break;
    Flags := [];
    if IsKw(kwConst) then
    begin
      Flags := [sfConstParam];
      Next;
    end
    else if IsKw(kwVar) then
    begin
      Flags := [sfVarParam];
      Next;
    end
    else if IsDir(dvOut) and (L.Peek^.Kind = tkIdent) then
    begin
      Flags := [sfOutParam];
      Next;
    end;
    First := List.Count;
    ReadNames(List, skParam, AOwner, viNone, Flags);
    TD := nil;
    TS := 0;
    TE := 0;
    if IsSym(syColon) then
    begin
      Next;
      TS := L.Tok.Start;
      TD := ParseType;
      TE := FPrevEnd;
    end;
    DefFlags := [];
    if IsSym(syEqual) then
    begin
      DefFlags := [sfHasDefault];
      Next;
      SkipExpr([sySemicolon], False);
    end;
    if First = List.Count then
      TD.Free
    else
      TypeNames(List, First, TD, TS, TE, FPrevEnd, nil, DefFlags);
    if IsSym(sySemicolon) then Next;
    if FSeq = Seq then Next;
  end;
end;

procedure ParseSource(U: TUnitInfo; const Source: string; IntfOnly: Boolean;
  Defines: TStrings; OnInclude: TLexIncludeEvent);
var
  Lex: TPasLexer;
  P: TPasParser;
begin
  U.Clear;
  U.Source := Source;
  Lex := TPasLexer.Create(Source);
  try
    Lex.AddDefines(Defines);
    Lex.OnInclude := OnInclude;
    Lex.AutoAsm := True;
    P := TPasParser.Create(U, Lex);
    try
      try
        P.ParseUnit(IntfOnly);
      except
        // tolerate anything: keep what was collected so far
      end;
    finally
      P.Free;
    end;
  finally
    Lex.Free;
  end;
  U.FullParsed := not IntfOnly;
end;

{ the parameter list Lex reads into List (symbols of U; Owner their owner, OwnerRoutine the
  routine whose local scope they lie in); never raises }
procedure ParseParams(U: TUnitInfo; Lex: TPasLexer; InImpl: Boolean; List: TList; Owner: TObject;
  OwnerRoutine: TRoutineSym);
var
  P: TPasParser;
begin
  P := TPasParser.Create(U, Lex);
  try
    P.FInImpl := InImpl;
    P.FOwnerRoutine := OwnerRoutine;
    P.FTable := nil;
    try
      P.Next;
      P.ParseParamList(List, Owner);
    except
    end;
  finally
    P.Free;
  end;
end;

procedure ParseParamRange(U: TUnitInfo; AStart, AEnd: Integer; InImpl: Boolean;
  List: TList; Owner: TObject; OwnerRoutine: TRoutineSym);
var
  Lex: TPasLexer;
  Line, Col: Integer;
begin
  if (U = nil) or (AEnd <= AStart) then Exit;
  Lex := TPasLexer.Create(U.Source, AStart, AEnd);
  try
    Line := U.LineOfOffset(AStart, Col);
    Lex.SetStartLineCol(Line, Col);
    ParseParams(U, Lex, InImpl, List, Owner, OwnerRoutine);
  finally
    Lex.Free;
  end;
end;

procedure EnsureParams(R: TRoutineSym);
var
  OwnerR: TRoutineSym;
begin
  if sfParamsParsed in R.Flags then Exit;
  Include(R.Flags, sfParamsParsed);
  if R.ParamsEnd <= R.ParamsStart then Exit;
  if R.Params = nil then R.Params := TList.Create;
  if R.Owner is TRoutineSym then OwnerR := TRoutineSym(R.Owner) else OwnerR := nil;
  ParseParamRange(R.UnitInfo, R.ParamsStart, R.ParamsEnd, sfInImpl in R.Flags,
    R.Params, R, OwnerR);
end;

procedure EnsureTypeParams(D: TTypeDesc);
begin
  if D.ParamsParsed then Exit;
  D.ParamsParsed := True;
  if D.ParamsEnd <= D.ParamsStart then Exit;
  if D.Params = nil then D.Params := TList.Create;
  ParseParamRange(D.UnitInfo, D.ParamsStart, D.ParamsEnd, D.InImpl, D.Params, D,
    TRoutineSym(D.OwnerRoutine));
end;

procedure ParseParamText(U: TUnitInfo; const Text: string; List: TList);
var
  Lex: TPasLexer;
begin
  Lex := TPasLexer.Create(Text);
  try
    ParseParams(U, Lex, False, List, nil, nil);
  finally
    Lex.Free;
  end;
end;

end.
