{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCodeInsight;

// D7 Studio - code insight public API: completion, parameter hints,
// find declaration, symbol hints and unit structure.
// All public methods are serialised by one critical section and never raise.

{$Q-,R-,B-,H+}

interface

uses
  Windows, SysUtils, Classes, SdPasLex, SdPasParser, SdCIEngine, SdExplorerEdit, SdPasCheck;

const
  MaxErrors = 1000;               // the most errors TCodeInsight.Diagnose gives for a text

type
  TCIKind = (ckUnknown, ckKeyword, ckUnit, ckConst, ckVar, ckType, ckClass, ckInterface, ckRecord,
    ckEnum, ckEnumValue, ckProcedure, ckFunction, ckConstructor, ckDestructor, ckProperty, ckField,
    ckParam, ckLocalVar, ckLabel, ckResourceString, ckTemplate);   // ckTemplate: a code template (Ctrl+J)
  TCIVisibility = (cvNone, cvPrivate, cvProtected, cvPublic, cvPublished);

  PCIItem = ^TCIItem;
  TCIItem = record
    Name: string;
    Kind: TCIKind;
    Decl: string;
    TypeName: string;
    Params: string;
    Scope: string;
    Visibility: TCIVisibility;
    FileName: string;
    Line, Col: Integer;
  end;

  TCIItemList = class
  private
    FList: TList;
    function GetItem(Index: Integer): PCIItem;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add: PCIItem;
    function Count: Integer;
    procedure Sort;
    property Items[Index: Integer]: PCIItem read GetItem; default;
  end;

  TCIParamHint = record
    Signature: string;
    Params: array of string;
  end;
  TCIParamHintArray = array of TCIParamHint;

  TCIStructNode = class
  private
    FChildren: TList;
    function GetChild(Index: Integer): TCIStructNode;
  public
    Caption: string;
    Kind: TCIKind;
    Line, Col: Integer;
    Plain: string;           // the name alone (Caption may carry parameters and type)
    Visibility: Integer;     // of a class member: Ord(TVisibility), 0 = none
    Incomplete: Boolean;     // a method of a class without an implementation
    Ancestors: string;       // a class, interface or record: its ancestor, then the interfaces it
                             // implements, comma separated ('' - none written; the Diagram tab)
    destructor Destroy; override;
    function Count: Integer;
    function AddChild(const ACaption: string; AKind: TCIKind; ALine, ACol: Integer): TCIStructNode;
    property Children[Index: Integer]: TCIStructNode read GetChild; default;
  end;

  { Delphi 7's Code Explorer: the symbols of a Pascal file as
    Delphi's parser (TUnitManager) and its tree (Pascalparsernodes) hold them - a picture taken by
    TCodeInsight.GetExplorer that keeps nothing of the parser's data. The root is the unit; its
    children say which category they belong to (Group), a class's children its own (the heritage
    list's interfaces, fields, properties, methods), an interface's (properties, methods); a
    routine with overloads has a row for each below it (Signature). Lines and columns are 1-based,
    columns as code insight counts them (bytes + 1). }
  TCIExpKind = (xkUnit, xkClass, xkInterface, xkProcedure, xkFunction, xkField, xkProperty, xkType,
    xkUses, xkHeritage);
  TCIExpGroup = (xgNone, xgClasses, xgInterfaces, xgProcedures, xgTypes, xgVariables, xgUses,
    xgHeritage, xgFields, xgProperties, xgMethods);
  { a class member's visibility as Delphi's explorer groups it: what comes before the first
    visibility word is published }
  TCIExpAccess = (xaPublished, xaPrivate, xaProtected, xaPublic);

  TCIExpNode = class
  private
    FChildren: TList;
    function GetChild(Index: Integer): TCIExpNode;
  public
    Kind: TCIExpKind;             // a variable or constant is an xkField of xgVariables
    Group: TCIExpGroup;
    Name: string;                 // the name alone
    Syntax: string;               // what Show declaration syntax adds to it: '(TForm)', ': TForm1',
                                  // '(Sender: TObject)', ': Integer' ...
    Access: TCIExpAccess;         // a class's member
    Signature: Boolean;           // one overload's row below its routine
    Incomplete: Boolean;          // bold with Highlight incomplete class items
    Line, Col: Integer;           // where Enter puts the caret (0: where its parent's is)
    TopLine: Integer;             // the line Enter puts at the window's top (0: its parent's)
    FirstLine, LastLine: Integer; // the lines it covers: a class's declaration, a routine's implementation,
                                  // else its declaration's line (0: none) - the editor's caret chooses it
    DeclLine: Integer;            // a routine's declaration apart from its implementation (0: none)
    SortPos: Integer;             // its place for the Source order, an offset (-1: none - by its text)
    destructor Destroy; override;
    function Count: Integer;
    function Add(AKind: TCIExpKind; AGroup: TCIExpGroup; const AName: string): TCIExpNode;
    property Children[Index: Integer]: TCIExpNode read GetChild; default;
  end;

  { The code editor's navigation bar (Class, Methods/functions): the classes of a unit and the
    routines of each, with the lines they cover - a picture taken by TCodeInsight.GetNavigation
    that keeps nothing of the parser's data. Lines are 1-based. }
  TCINavItem = class
  public
    Name: string;                 // the name alone
    Caption: string;              // a routine's with its parameters and result type (the Methods box's row)
    Kind: TCIKind;
    Line, Col: Integer;           // where it is: a class's declaration, a routine's implementation
                                  // (else its declaration) - Col as code insight counts (bytes + 1)
    FirstLine, LastLine: Integer; // what it covers: a class's declaration, a routine's implementation
                                  // from its heading to its end (0: none)
    DeclFirst, DeclLast: Integer; // a routine's declaration - in its class, in the interface (0: none)
    Owner: TCINavItem;            // a method's class (nil: a plain routine)
  end;

  TCINavigation = class
  public
    Classes: TList;               // TCINavItem (owned): classes, objects, interfaces - in source order
    Routines: TList;              // TCINavItem (owned): the classes' methods and the plain routines
    constructor Create;
    destructor Destroy; override;
    { what holds Line: the routine whose implementation does (the innermost), else the one whose
      declaration does (nil: none); Cls - that routine's class, else the class whose declaration
      holds Line (nil: none) }
    function At(Line: Integer; out Cls: TCINavItem): TCINavItem;
  end;

  { The Browser (View | Browser): the units of a project, what they declare, the
    classes and interfaces with their ancestors - a picture taken by TCodeInsight.Browse that
    keeps nothing of the parser's data. }
  TCIBrowseUnit = class;

  TCIBrowseSym = class
  public
    Name: string;
    Kind: TCIKind;                // ckUnit: the unit itself (UnitInfo)
    Visibility: TCIVisibility;
    Caption: string;              // the name, with parameters and type (as the navigation bar's routines)
    Decl: string;                 // the declaration
    UnitInfo: TCIBrowseUnit;      // where it is declared
    Line, Col: Integer;
    Owner: TCIBrowseSym;          // a member: its class, interface or record
    Members: TList;               // a class, interface or record: its members (owned)
    Ancestor: TCIBrowseSym;       // a class or interface: the one it derives from (nil: a root)
    Descendants: TList;           // the classes and interfaces that derive from it
    InImpl: Boolean;              // declared in the implementation part
    AncestorDone: Boolean;
    Tag: Integer;                 // free for the view
    constructor Create;
    destructor Destroy; override;
    function QualifiedName: string;   // Unit1.TForm1.Button1Click
  end;

  TCIBrowseUnit = class
  public
    Name, FileName: string;
    InProject: Boolean;           // a unit of the project (else one it uses)
    Shown: Boolean;               // in the scope browsed (else only the home of an ancestor)
    UsesList: TStringList;
    Syms: TList;                  // what it declares, in source order (owned)
    Sym: TCIBrowseSym;            // the unit as a symbol
    constructor Create;
    destructor Destroy; override;
  end;

  TCIBrowseModel = class
  public
    Units: TList;                 // TCIBrowseUnit (owned): the project's first, in its order
    ClassList: TList;             // every class and interface of Units
    constructor Create;
    destructor Destroy; override;
  end;

  TCIGetSourceEvent = function(const FileName: string; var Source: string): Boolean of object;
  { the units the IDE puts into the interface uses clause of an open file before it is saved or
    compiled, into Units }
  TCIGetUsesEvent = procedure(const FileName: string; Units: TStrings) of object;

  { an error of Error Insight: its place in the text (0-based offset and length; Len 0: a place
    without a token of its own - the end of the text, an include directive), its line and column
    (1-based), the message as Delphi 7's compiler words it }
  TCIError = record
    Start, Len, Line, Col: Integer;
    Msg: string;
  end;
  TCIErrors = array of TCIError;

  TCodeInsight = class
  private
    FLock: TRTLCriticalSection;
    FEng: TCIEngine;
    FOnGetSource: TCIGetSourceEvent;
    function GetSearchPath: TStrings;
    function GetDefines: TStrings;
    function GetUnitFiles: TStrings;
    function GetReadFileFunc: TCIReadFileFunc;
    procedure SetReadFileFunc(Value: TCIReadFileFunc);
    function GetFileAgeFunc: TCIFileAgeFunc;
    procedure SetFileAgeFunc(Value: TCIFileAgeFunc);
    function GetOnGetPendingUses: TCIGetUsesEvent;
    procedure SetOnGetPendingUses(Value: TCIGetUsesEvent);
    procedure PathChange(Sender: TObject);
    procedure DefinesChange(Sender: TObject);
    function EngGetSource(const FileName: string; var Source: string): Boolean;
    function SourceFor(const FileName: string; out Source: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure InvalidateFile(const FileName: string);
    procedure ClearCache;
    function FindUnitFile(const UnitName, FromFile: string): string;
    function GetCompletions(const FileName, Source: string; Pos: Integer; List: TCIItemList;
      out PrefixStart: Integer): Boolean;
    function GetParamHints(const FileName, Source: string; Pos: Integer;
      out Hints: TCIParamHintArray; out ActiveParam: Integer): Boolean;
    function FindDeclaration(const FileName, Source: string; Pos: Integer; out Item: TCIItem): Boolean;
    { Tooltip symbol insight: the declaration of the symbol at Pos on one line, then - after a line
      break - its place ("Scope - File.pas (line)"), when it has one (SdHints.DeclTipLines shows
      them so) }
    function GetHint(const FileName, Source: string; Pos: Integer; out HintText: string): Boolean;
    function GetStructure(const FileName, Source: string): TCIStructNode;
    { the Code Explorer's picture of the text (TCIExpNode); nil when the parse failed. The caller
      frees the result }
    function GetExplorer(const FileName, Source: string): TCIExpNode;
    { what the Code Explorer's New and Rename write (SdExplorerEdit): the text with the item, the
      text with the new name; False - Error says why not }
    function ExplorerNew(const FileName, Source, ClassName: string; Access: TCIExpAccess; InUses: Boolean;
      const Text: string; out NewSource, Error: string): Boolean;
    function ExplorerRename(const FileName, Source: string; Kind: TExpRenameKind;
      const ClassName, OldName, NewName: string; out NewSource, Error: string): Boolean;
    { the navigation bar's classes and routines of the text (never nil: empty when it cannot be
      parsed); the caller frees the result }
    function GetNavigation(const FileName, Source: string): TCINavigation;
    { the Browser: Files - the project file and its units (the editor's text where it has them);
      AllUnits - also every unit they use, directly or not (else only the homes of their classes'
      ancestors come along, not Shown). The caller frees the result. }
    function Browse(Files: TStrings; AllUnits: Boolean): TCIBrowseModel;
    { the places in Files that name Sym (of a Browse result) - its declaration too - as
      file#9line#9col#9the line's text, in the order of Files and of their text }
    function FindReferences(Sym: TCIBrowseSym; Files, List: TStrings): Boolean;
    { the places of a file's text that name the symbol of the identifier at Pos - its
      declaration, its uses, a routine's implementations -, resolved as Find Declaration
      resolves them (a local I of one routine is not another routine's): their offsets in
      Places, those of declarations also in Decls, in the text's order. False: no identifier
      there, or code insight does not know it. }
    function SymbolOccurrences(const FileName, Source: string; Pos: Integer; Places, Decls: TList): Boolean;
    { the kinds of names (the editor's names by kind): Ends - where each name of the file's text
      ends, in the text's order -; Kinds - the kind of each as Find Declaration resolves it (a
      parameter where a heading declares it; Self a parameter, Result and an exception handler's
      variable - on E: T do - a local variable), ckUnknown
      where code insight finds nothing. The text is parsed once (not again while it is the same)
      and passed over once for all of them. False: it could not be read }
    function NameKinds(const FileName, Source: string; const Ends: array of Integer;
      var Kinds: array of TCIKind): Boolean;
    { Error Insight: the errors of a file's text as Delphi 7's compiler reports them, in the
      text's order (at most MaxErrors) - its syntax errors (SdPasCheck); the names that are
      certainly not declared, before the first syntax error; and in a text without syntax
      errors the routines and methods declared without an implementation, the methods
      implemented without a declaration and those whose heading differs from it. A name counts
      as not declared only where every scope it could come from is known: the units it uses
      found with their sources, the classes and records it could be a member of complete with
      their ancestors, the with statements around it resolved. False: it could not be checked }
    function Diagnose(const FileName, Source: string; out Errors: TCIErrors; out Count: Integer): Boolean;
    property SearchPath: TStrings read GetSearchPath;
    property Defines: TStrings read GetDefines;
    property UnitFiles: TStrings read GetUnitFiles;
    property OnGetSource: TCIGetSourceEvent read FOnGetSource write FOnGetSource;
    { the units still to come into an open file's interface uses clause (a form's placed
      components, which Delphi 7's designer adds at the save or compile): every call (completion,
      Error Insight ...) sees them in the file's scope, as the compiler will }
    property OnGetPendingUses: TCIGetUsesEvent read GetOnGetPendingUses write SetOnGetPendingUses;
    { file access for names outside the system code page (SdFileNames' ReadFileU / FileAgeU;
      nil = the ANSI functions); set them before the first call }
    property ReadFileFunc: TCIReadFileFunc read GetReadFileFunc write SetReadFileFunc;
    property FileAgeFunc: TCIFileAgeFunc read GetFileAgeFunc write SetFileAgeFunc;
  end;

var
  { diagnostics: exceptions swallowed by the public API (should stay 0) }
  CISwallowedExceptions: Integer = 0;
  CILastException: string = '';

implementation

procedure NoteExc;
begin
  Inc(CISwallowedExceptions);
  if ExceptObject is Exception then
    CILastException := Exception(ExceptObject).ClassName + ': ' + Exception(ExceptObject).Message
  else
    CILastException := 'unknown exception';
end;

{ ---------------------------------------------------------------------------- }
{ TCIItemList }

function CompareItems(Item1, Item2: Pointer): Integer;
var
  PA, PB: PChar;
  CA, CB: Char;
begin
  PA := PChar(PCIItem(Item1)^.Name);
  PB := PChar(PCIItem(Item2)^.Name);
  repeat
    CA := UpTab[PA^];
    CB := UpTab[PB^];
    if (CA <> CB) or (CA = #0) then Break;
    Inc(PA);
    Inc(PB);
  until False;
  Result := Ord(CA) - Ord(CB);
  if Result = 0 then
    Result := Ord(PCIItem(Item1)^.Kind) - Ord(PCIItem(Item2)^.Kind);
  if Result = 0 then
    Result := PCIItem(Item1)^.Line - PCIItem(Item2)^.Line;
end;

constructor TCIItemList.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

destructor TCIItemList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TCIItemList.Clear;
var
  I: Integer;
begin
  if FList = nil then Exit;
  for I := 0 to FList.Count - 1 do
    Dispose(PCIItem(FList[I]));
  FList.Clear;
end;

function TCIItemList.Add: PCIItem;
begin
  if FList = nil then FList := TList.Create;
  New(Result);
  Result^.Kind := ckUnknown;
  Result^.Visibility := cvNone;
  Result^.Line := 0;
  Result^.Col := 0;
  FList.Add(Result);
end;

function TCIItemList.Count: Integer;
begin
  if FList = nil then Result := 0 else Result := FList.Count;
end;

function TCIItemList.GetItem(Index: Integer): PCIItem;
begin
  Result := PCIItem(FList[Index]);
end;

procedure TCIItemList.Sort;
begin
  if (FList <> nil) and (FList.Count > 1) then FList.Sort(CompareItems);
end;

{ TCIStructNode }

destructor TCIStructNode.Destroy;
var
  I: Integer;
begin
  if FChildren <> nil then
  begin
    for I := 0 to FChildren.Count - 1 do
      TObject(FChildren[I]).Free;
    FChildren.Free;
  end;
  inherited Destroy;
end;

function TCIStructNode.Count: Integer;
begin
  if FChildren = nil then Result := 0 else Result := FChildren.Count;
end;

function TCIStructNode.GetChild(Index: Integer): TCIStructNode;
begin
  Result := TCIStructNode(FChildren[Index]);
end;

function TCIStructNode.AddChild(const ACaption: string; AKind: TCIKind; ALine, ACol: Integer): TCIStructNode;
begin
  if FChildren = nil then FChildren := TList.Create;
  Result := TCIStructNode.Create;
  Result.Caption := ACaption;
  Result.Kind := AKind;
  Result.Line := ALine;
  Result.Col := ACol;
  FChildren.Add(Result);
end;

{ TCINavigation }

constructor TCINavigation.Create;
begin
  inherited Create;
  Classes := TList.Create;
  Routines := TList.Create;
end;

destructor TCINavigation.Destroy;
var
  I: Integer;
begin
  if Routines <> nil then
    for I := 0 to Routines.Count - 1 do TObject(Routines[I]).Free;
  if Classes <> nil then
    for I := 0 to Classes.Count - 1 do TObject(Classes[I]).Free;
  FreeAndNil(Routines);
  FreeAndNil(Classes);
  inherited Destroy;
end;

function TCINavigation.At(Line: Integer; out Cls: TCINavItem): TCINavItem;
var
  I: Integer;
  It: TCINavItem;
begin
  Result := nil;
  Cls := nil;
  { an implementation: the innermost one (an unfinished routine above another spans it) }
  for I := 0 to Routines.Count - 1 do
  begin
    It := TCINavItem(Routines[I]);
    if (It.FirstLine > 0) and (Line >= It.FirstLine) and (Line <= It.LastLine) and
      ((Result = nil) or (It.FirstLine > Result.FirstLine)) then
      Result := It;
  end;
  if Result <> nil then
  begin
    Cls := Result.Owner;
    Exit;
  end;
  for I := 0 to Classes.Count - 1 do
  begin
    It := TCINavItem(Classes[I]);
    if (It.FirstLine > 0) and (Line >= It.FirstLine) and (Line <= It.LastLine) then
    begin
      Cls := It;
      Break;
    end;
  end;
  { a declaration: in that class, else of a plain routine }
  for I := 0 to Routines.Count - 1 do
  begin
    It := TCINavItem(Routines[I]);
    if (It.Owner = Cls) and (It.DeclFirst > 0) and (Line >= It.DeclFirst) and (Line <= It.DeclLast) then
    begin
      Result := It;
      Exit;
    end;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ name set used to de-duplicate completion candidates }

type
  TNameEntry = record
    P: PChar;
    Len: Integer;
    Level: Integer;
    AllOverload: Boolean;
  end;

  TNameEntryArray = array of TNameEntry;

  TNameSet = class
  private
    FEntries: TNameEntryArray;
    FMask: Cardinal;
    FCount: Integer;
    procedure Grow;
    function Locate(P: PChar; Len: Integer): Integer;
  public
    Level: Integer;
    constructor Create;
    function Accept(S: TSymbol): Boolean;
    function AcceptName(const Name: string): Boolean;
  end;

constructor TNameSet.Create;
begin
  inherited Create;
  SetLength(FEntries, 2048);
  FMask := 2047;
end;

function SamePP(A, B: PChar; Len: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Len - 1 do
    if UpTab[A[I]] <> UpTab[B[I]] then Exit;
  Result := True;
end;

function TNameSet.Locate(P: PChar; Len: Integer): Integer;
var
  H: Cardinal;
begin
  H := HashUpper(P, Len) and FMask;
  while (FEntries[H].P <> nil) and
    not ((FEntries[H].Len = Len) and SamePP(FEntries[H].P, P, Len)) do
    H := (H + 1) and FMask;
  Result := H;
end;

procedure TNameSet.Grow;
var
  Old: TNameEntryArray;
  I, J: Integer;
begin
  Old := FEntries;
  FEntries := nil;
  SetLength(FEntries, Length(Old) * 4);
  FMask := Length(FEntries) - 1;
  for I := 0 to High(Old) do
    if Old[I].P <> nil then
    begin
      J := Locate(Old[I].P, Old[I].Len);
      FEntries[J] := Old[I];
    end;
end;

function TNameSet.Accept(S: TSymbol): Boolean;
var
  I: Integer;
  IsOvl: Boolean;
begin
  if S.Name = '' then
  begin
    Result := False;
    Exit;
  end;
  IsOvl := (S.Kind = skRoutine) and (sfOverload in S.Flags);
  I := Locate(PChar(S.Name), Length(S.Name));
  if FEntries[I].P = nil then
  begin
    FEntries[I].P := PChar(S.Name);
    FEntries[I].Len := Length(S.Name);
    FEntries[I].Level := Level;
    FEntries[I].AllOverload := IsOvl;
    Inc(FCount);
    if FCount * 2 > Length(FEntries) then Grow;
    Result := True;
  end
  else if FEntries[I].Level = Level then
  begin
    // same scope: overloads (several routines with one name) are all listed
    Result := S.Kind = skRoutine;
    if not IsOvl then FEntries[I].AllOverload := False;
  end
  else
  begin
    Result := FEntries[I].AllOverload and IsOvl;
  end;
end;

function TNameSet.AcceptName(const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Name = '' then Exit;
  I := Locate(PChar(Name), Length(Name));
  if FEntries[I].P <> nil then Exit;
  FEntries[I].P := PChar(Name);
  FEntries[I].Len := Length(Name);
  FEntries[I].Level := Level;
  FEntries[I].AllOverload := False;
  Inc(FCount);
  if FCount * 2 > Length(FEntries) then Grow;
  Result := True;
end;

{ ---------------------------------------------------------------------------- }
{ cursor context }

type
  TResKind = (rkNone, rkValue, rkType, rkUnit, rkRoutine);

  TResolved = record
    Kind: TResKind;
    TD: TTypeDesc;
    Sym: TSymbol;
    UnitInfo: TUnitInfo;
    SelfTD: TTypeDesc;
    NeedIndex: Boolean;
  end;

  { a with statement around the caret (its expression: tokens A .. B), or an exception handler's
    variable - on E: T do -, OnVar its name's token (-1: a with) and A .. B its type }
  TWithRec = record
    A, B: Integer;
    Depth: Integer;
    Single: Boolean;
    Evaluated: Boolean;
    Res: TResolved;
    OnVar: Integer;
  end;

  TCIContext = class
  private
    Eng: TCIEngine;
    U: TUnitInfo;
    Pos: Integer;
    Lex: TPasLexer;
    FToks: TRawToks;           // the tokens lexed from the scan start; Toks is its array
    Toks: TTokenArray;
    TokCount: Integer;         // those before the caret
    FTokStart: Integer;        // the scan start FToks was lexed from (-1: none)
    FMore: Boolean;            // shared: the lexer has more tokens
    Routine: TRoutineSym;
    ClassDesc: TTypeDesc;
    DeclClass: TTypeDesc;      // class / record declaration the caret is inside (declaration sections)
    InImpl: Boolean;
    Withs: array of TWithRec;
    WithCount: Integer;
    { ComputeWiths' state before token FWNext, of the scan from token FWithIdx (-1: none) - a
      caret further on in the same tokens goes on from there }
    FWithIdx, FWNext, FWDepth, FWPD, FWCount: Integer;
    FSeen: TNameSet;
    FEvalDepth: Integer;
    procedure Place(APos: Integer; Shared: Boolean);
    function RoutineContains(R: TRoutineSym; P: Integer): Boolean;
    function FindRoutineAt(P: Integer): TRoutineSym;
    function UnitScanStart: Integer;
    procedure CollectTokens(ScanStart: Integer; Shared: Boolean);
    procedure ComputeWiths(StartIdx: Integer);
    function IsSymAt(I: Integer; S: TSymbolId): Boolean;
    function IsKwAt(I: Integer; K: TKeyword): Boolean;
    function MatchOpen(K: Integer): Integer;
    function MatchClose(I, B: Integer): Integer;
    function ChainStart(EndIdx: Integer): Integer;
    function ChainEndForward(A, B: Integer): Integer;
    function EvalChain(A, B, WithLimit: Integer): TResolved;
    function EvalExprRange(A, B, WithLimit: Integer): TResolved;
    function EvalWith(I: Integer): TResolved;
    function LookupIdent(P: PChar; Len, WithLimit: Integer): TResolved;
    function LookupInherited(P: PChar; Len: Integer): TResolved;
    function FromSym(S: TSymbol): TResolved;
    function ToValue(const R: TResolved): TResolved;
    function ValueDesc(const R0: TResolved): TTypeDesc;
    function ClassRefTarget(D: TTypeDesc): TTypeDesc;
    function MemberScope(D: TTypeDesc; out ClassLevel: Boolean): TTypeDesc;
    function MemberRes(D, SelfD: TTypeDesc; P: PChar; Len: Integer; var R: TResolved): Boolean;
    function MemberOf(const R: TResolved; P: PChar; Len: Integer): TResolved;
    function ApplyCall(const R: TResolved): TResolved;
    function ApplyIndex(const R0: TResolved; NIdx: Integer): TResolved;
    function ApplyDeref(const R0: TResolved): TResolved;
    function DefaultPropOf(D: TTypeDesc): TSymbol;
    function InUsesClause(N: Integer): Boolean;
    function ScopeOf(S: TSymbol): string;
    procedure AddItem(List: TCIItemList; S: TSymbol);
    procedure AddPseudo(List: TCIItemList; const AName: string; AKind: TCIKind; const ADecl, AType: string);
    procedure AddTable(Tab: TSymTable; List: TCIItemList; HideUnderscore: Boolean);
    procedure AddClassMembers(D: TTypeDesc; List: TCIItemList; ClassLevelOnly: Boolean);
    procedure AddOwnMethods(D: TTypeDesc; List: TCIItemList);
    procedure AddMembersOf(const R0: TResolved; List: TCIItemList; HeadingMode: Boolean);
    procedure AddScope(List: TCIItemList);
    procedure AddUnitNames(List: TCIItemList);
    procedure BuildHint(RS: TRoutineSym; var H: TCIParamHint);
    function FindImplOf(S: TSymbol): TRoutineSym;
    function StructKnown(D: TTypeDesc): Boolean;
    function RoutineParams(R: TRoutineSym): TList;
    function ScopeKnown: Boolean;
  public
    InComment, InString: Boolean;
    constructor Create(AEng: TCIEngine; const AFileName, ASource: string; APos: Integer);
    { one context for many places of a file in source order (FindReferences): ResolveAt moves
      the caret; the tokens of a routine are lexed once for all of its places }
    constructor CreateShared(AEng: TCIEngine; const AFileName, ASource: string);
    destructor Destroy; override;
    function ResolveAt(APos: Integer; out R: TResolved): Boolean;
    { the name that ends at the caret declares a parameter: it stands in a heading's parameter
      list (a routine's, a procedural type's, a property's index list) where a parameter's name
      stands - after ( [ ; , var const out, before : , ; ) ] }
    function DeclaresParam: Boolean;
    procedure MakeItem(S: TSymbol; var Item: TCIItem);
    function Complete(List: TCIItemList; out PrefixStart: Integer): Boolean;
    function ParamHints(out Hints: TCIParamHintArray; out ActiveParam: Integer): Boolean;
    function ResolveHere(out R: TResolved): Boolean;
    function FindDecl(var Item: TCIItem): Boolean;
    { Error Insight: the name that ends at APos - standing as Use says (SdPasCheck's names) - is
      certainly not declared: it resolves to nothing where every scope it could come from is
      known (StructKnown, ScopeKnown) }
    function Undeclared(APos: Integer; Use: TPasNameUse): Boolean;
  end;

const
  NoRes: TResolved = (Kind: rkNone; TD: nil; Sym: nil; UnitInfo: nil; SelfTD: nil; NeedIndex: False);
  StructKinds = [tyClass, tyInterface, tyObject, tyRecord];

function SymKind(S: TSymbol): TCIKind;
begin
  case S.Kind of
    skConst: Result := ckConst;
    skResStr: Result := ckResourceString;
    skVar: Result := ckVar;
    skLocal: Result := ckLocalVar;
    skParam: Result := ckParam;
    skField: Result := ckField;
    skProperty: Result := ckProperty;
    skEnumValue: Result := ckEnumValue;
    skLabel: Result := ckLabel;
    skRoutine:
      if sfConstructor in S.Flags then Result := ckConstructor
      else if sfDestructor in S.Flags then Result := ckDestructor
      else if sfFunction in S.Flags then Result := ckFunction
      else Result := ckProcedure;
    skType:
      if S.TypeDesc = nil then Result := ckType
      else
        case S.TypeDesc.Kind of
          tyClass: Result := ckClass;
          tyInterface: Result := ckInterface;
          tyRecord, tyObject: Result := ckRecord;
          tyEnum: Result := ckEnum;
        else
          Result := ckType;
        end;
  else
    Result := ckUnknown;
  end;
end;

{ Enclosing routine whose locals are in scope. A method ('procedure TFoo.Bar')
  can never really be nested: when it appears so, the outer routine is an
  unfinished heading typed above it and contributes nothing. }
function OuterOf(R: TRoutineSym): TRoutineSym;
begin
  if (R.ClassQual = '') and (R.Owner is TRoutineSym) then Result := TRoutineSym(R.Owner)
  else Result := nil;
end;

{ TCIContext }

constructor TCIContext.Create(AEng: TCIEngine; const AFileName, ASource: string; APos: Integer);
begin
  inherited Create;
  Eng := AEng;
  U := Eng.LoadCurrent(AFileName, ASource);
  FTokStart := -1;
  FWithIdx := -1;
  Place(APos, False);
end;

constructor TCIContext.CreateShared(AEng: TCIEngine; const AFileName, ASource: string);
begin
  inherited Create;
  Eng := AEng;
  U := Eng.LoadCurrent(AFileName, ASource);
  FTokStart := -1;
  FWithIdx := -1;
end;

function TCIContext.ResolveAt(APos: Integer; out R: TResolved): Boolean;
begin
  Place(APos, True);
  Result := ResolveHere(R);
end;

function TCIContext.DeclaresParam: Boolean;
const
  { what a parameter list cannot hold: the walk back has left the heading }
  NotInList = [kwAsm, kwBegin, kwCase, kwDo, kwElse, kwEnd, kwExcept, kwExports, kwFinalization,
    kwFinally, kwFor, kwIf, kwImplementation, kwInitialization, kwInterface, kwLabel, kwLibrary,
    kwProgram, kwRepeat, kwResourcestring, kwThen, kwThreadvar, kwTry, kwType, kwUnit, kwUntil,
    kwUses, kwWhile, kwWith];
var
  N, I, Depth: Integer;
  Next: PToken;
begin
  Result := False;
  N := TokCount - 1;
  if (N < 2) or (FToks = nil) or (TokCount >= FToks.N) then Exit;
  if not ((Toks[N].Kind = tkIdent) and (Toks[N].Start + Toks[N].Len = Pos)) then Exit;
  { the token after the name: the shared lexer has taken it already }
  Next := @FToks.T[TokCount];
  if not ((Next.Kind = tkSymbol) and (Next.Symbol in [syColon, syComma, sySemicolon, syRParen, syRBracket])) then
    Exit;
  with Toks[N - 1] do
    if not (((Kind = tkSymbol) and (Symbol in [syLParen, syLBracket, sySemicolon, syComma])) or
      ((Kind = tkKeyword) and (Keyword in [kwVar, kwConst])) or ((Kind = tkIdent) and (Directive = dvOut))) then
      Exit;
  { back to the bracket that opens the list }
  Depth := 0;
  I := N - 1;
  while I >= 0 do
  begin
    if Toks[I].Kind = tkSymbol then
    begin
      if Toks[I].Symbol in [syRParen, syRBracket] then Inc(Depth)
      else if Toks[I].Symbol in [syLParen, syLBracket] then
        if Depth = 0 then Break else Dec(Depth);
    end
    else if (Toks[I].Kind = tkKeyword) and (Toks[I].Keyword in NotInList) then
      Exit;
    Dec(I);
  end;
  if I < 1 then Exit;
  { before it: procedure or function itself (a procedural type), else the name - qualified or
    not - after the heading's word }
  Dec(I);
  if (Toks[I].Kind = tkKeyword) and (Toks[I].Keyword in [kwProcedure, kwFunction]) then
  begin
    Result := Toks[I + 1].Symbol = syLParen;
    Exit;
  end;
  while (I >= 2) and (Toks[I].Kind = tkIdent) and IsSymAt(I - 1, syDot) do Dec(I, 2);
  Result := (I >= 1) and (Toks[I].Kind = tkIdent) and (Toks[I - 1].Kind = tkKeyword) and
    (Toks[I - 1].Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor, kwProperty]);
end;

{ the caret at APos: its routine, scan start, class and withs, the tokens up to it. Shared: the
  tokens lexed for an earlier (smaller) APos with the same scan start are lexed on, not again,
  and the withs go on from where they were }
procedure TCIContext.Place(APos: Integer; Shared: Boolean);
var
  ScanStart, WithOfs, I: Integer;
  R: TRoutineSym;
  S: TSymbol;
begin
  if APos < 0 then APos := 0;
  if APos > Length(U.Source) then APos := Length(U.Source);
  Pos := APos;
  InImpl := U.IsProgram or (Pos >= U.ImplOfs);
  DeclClass := nil;
  ClassDesc := nil;
  Routine := FindRoutineAt(Pos);
  WithOfs := -1;
  if Routine <> nil then
  begin
    R := Routine;
    while R.Owner is TRoutineSym do R := TRoutineSym(R.Owner);
    ScanStart := R.HeadStart;
    if (sfHasBody in Routine.Flags) and (Pos > Routine.BodyStart) then
      WithOfs := Routine.BodyStart;
  end
  else if (U.MainBegin > 0) and (Pos > U.MainBegin) then
  begin
    ScanStart := U.MainBegin;
    WithOfs := ScanStart;
  end
  else if (U.FinalOfs > 0) and (Pos > U.FinalOfs) then
  begin
    ScanStart := U.FinalOfs;
    WithOfs := ScanStart;
  end
  else if (U.InitOfs > 0) and (Pos > U.InitOfs) then
  begin
    ScanStart := U.InitOfs;
    WithOfs := ScanStart;
  end
  else
    ScanStart := UnitScanStart;
  CollectTokens(ScanStart, Shared);
  // class of the enclosing method
  R := Routine;
  while R <> nil do
  begin
    if R.ClassQual <> '' then
    begin
      S := Eng.FindQualified(R.ClassQual, U, True, nil);
      if (S <> nil) and (S.Kind = skType) and (S.TypeDesc <> nil) then
        ClassDesc := Eng.ResolveDesc(S.TypeDesc);
      Break;
    end;
    if R.Owner is TRoutineSym then R := TRoutineSym(R.Owner) else R := nil;
  end;
  if WithOfs >= 0 then
  begin
    I := FToks.FirstAt(WithOfs);
    if I > TokCount then I := TokCount;
    ComputeWiths(I);
  end
  else
    WithCount := 0;
end;

destructor TCIContext.Destroy;
begin
  FToks.Free;
  Lex.Free;
  inherited Destroy;
end;

function TCIContext.RoutineContains(R: TRoutineSym; P: Integer): Boolean;
var
  I: Integer;
  Src: PChar;
begin
  Result := False;
  if P < R.HeadStart then Exit;
  if sfBodyClosed in R.Flags then
  begin
    Result := P < R.BodyEnd;
    Exit;
  end;
  if P <= R.BodyEnd then
  begin
    Result := True;
    Exit;
  end;
  Src := PChar(U.Source);
  for I := R.BodyEnd to P - 1 do
    if Src[I] > ' ' then Exit;
  Result := True;
end;

function TCIContext.FindRoutineAt(P: Integer): TRoutineSym;
var
  I, Lim: Integer;
  R, Best, Nested, Prev: TRoutineSym;
  S: TSymbol;
  TL: TPasLexer;
  Broken: Boolean;
begin
  Best := nil;
  Prev := nil;
  for I := 0 to U.ImplRoutines.Count - 1 do
  begin
    R := TRoutineSym(U.ImplRoutines[I]);
    if R.HeadStart <= P then Prev := R else Break;
  end;
  if Prev <> nil then
  begin
    if RoutineContains(Prev, P) then
      Best := Prev
    else if (sfBodyClosed in Prev.Flags) and
      not ((U.MainBegin > Prev.BodyEnd) and (P > U.MainBegin)) and
      not ((U.InitOfs > Prev.BodyEnd) and (P > U.InitOfs)) and
      not ((U.FinalOfs > Prev.BodyEnd) and (P > U.FinalOfs)) then
    begin
      // The body was closed early by an unbalanced 'end' (code being typed):
      // statements follow the routine end -> still treat as inside.
      Broken := False;
      Lim := P;
      if Lim - Prev.BodyEnd > 4000 then Lim := Prev.BodyEnd + 4000;
      TL := TPasLexer.Create(U.Source, Prev.BodyEnd, Lim);
      try
        TL.Next;
        while TL.Tok.Symbol = sySemicolon do TL.Next;
        if (TL.Tok.Kind in [tkIdent, tkString, tkNumber]) or
          ((TL.Tok.Kind = tkKeyword) and (TL.Tok.Keyword in [kwIf, kwFor, kwWhile, kwRepeat,
            kwWith, kwCase, kwTry, kwRaise, kwInherited, kwEnd, kwElse, kwExcept, kwFinally,
            kwUntil, kwGoto])) or
          ((TL.Tok.Kind = tkSymbol) and (TL.Tok.Symbol in [syLParen, syAt, syDot])) then
          Broken := True;
      finally
        TL.Free;
      end;
      if Broken then Best := Prev;
    end;
  end;
  while Best <> nil do
  begin
    Nested := nil;
    if Best.Locals <> nil then
      for I := 0 to Best.Locals.Count - 1 do
      begin
        S := Best.Locals[I];
        if (S.Kind = skRoutine) and (S is TRoutineSym) then
        begin
          R := TRoutineSym(S);
          if (sfImplBody in R.Flags) and not (sfForward in R.Flags) and RoutineContains(R, P) and
            (R.HeadStart <= P) then
            Nested := R;
        end;
      end;
    if Nested = nil then Break;
    // a nested routine only counts when the caret is before the outer body
    if (sfHasBody in Best.Flags) and (P >= Best.BodyStart) and (sfBodyClosed in Nested.Flags) then Break;
    Best := Nested;
  end;
  Result := Best;
end;

type
  TScanEntry = record
    Start, Index: Integer;
    Sym: TSymbol;
  end;

{ the declarations of a part of U by their places (TUnitInfo.ScanSyms): its symbols but enum
  values, by where they begin - a routine at its heading -, those of one place in the table's
  order }
procedure MakeScanIndex(U: TUnitInfo; Impl: Boolean);
var
  Tab: TSymTable;
  E: array of TScanEntry;
  I, N: Integer;
  S: TSymbol;

  function Before(const A, B: TScanEntry): Boolean;
  begin
    Result := (A.Start < B.Start) or ((A.Start = B.Start) and (A.Index < B.Index));
  end;

  procedure Sort(L, R: Integer);
  var
    I, J: Integer;
    P, T: TScanEntry;
  begin
    repeat
      I := L;
      J := R;
      P := E[(L + R) shr 1];
      repeat
        while Before(E[I], P) do Inc(I);
        while Before(P, E[J]) do Dec(J);
        if I <= J then
        begin
          T := E[I];
          E[I] := E[J];
          E[J] := T;
          Inc(I);
          Dec(J);
        end;
      until I > J;
      if L < J then Sort(L, J);
      L := I;
    until I >= R;
  end;

begin
  if Impl then Tab := U.ImplSyms else Tab := U.IntfSyms;
  SetLength(E, Tab.Count);
  N := 0;
  for I := 0 to Tab.Count - 1 do
  begin
    S := Tab[I];
    if S.Kind = skEnumValue then Continue;
    if S is TRoutineSym then E[N].Start := TRoutineSym(S).HeadStart else E[N].Start := S.DeclStart;
    E[N].Index := I;
    E[N].Sym := S;
    Inc(N);
  end;
  if N > 1 then Sort(0, N - 1);
  SetLength(U.ScanSyms[Impl], N);
  SetLength(U.ScanStarts[Impl], N);
  for I := 0 to N - 1 do
  begin
    U.ScanSyms[Impl][I] := E[I].Sym;
    U.ScanStarts[Impl][I] := E[I].Start;
  end;
  U.ScanMade[Impl] := True;
end;

function TCIContext.UnitScanStart: Integer;
var
  I, B, Lo, Hi, M: Integer;
  S: TSymbol;
  R: TRoutineSym;
begin
  Result := 0;
  if InImpl and (U.ImplOfs < MaxInt) and (U.ImplOfs <= Pos) then Result := U.ImplOfs;
  for I := U.ImplRoutines.Count - 1 downto 0 do
  begin
    R := TRoutineSym(U.ImplRoutines[I]);
    if R.BodyEnd <= Pos then
    begin
      if R.BodyEnd > Result then Result := R.BodyEnd;
      Break;
    end;
  end;
  { the declaration the caret is in or after: the last one that begins at or before it, found
    by place (the table's order is the parse's: a type declared forward keeps the forward's
    slot, before the declarations its full declaration follows) }
  if not U.ScanMade[InImpl] then MakeScanIndex(U, InImpl);
  S := nil;
  B := 0;
  Lo := 0;
  Hi := High(U.ScanStarts[InImpl]);
  while Lo <= Hi do
  begin
    M := (Lo + Hi) shr 1;
    if U.ScanStarts[InImpl][M] <= Pos then
    begin
      S := U.ScanSyms[InImpl][M];
      B := U.ScanStarts[InImpl][M];
      Lo := M + 1;
    end
    else
      Hi := M - 1;
  end;
  if S = nil then Exit;
  if B > Result then Result := B;
  if (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Kind in StructKinds) and
    (S.TypeDesc.Members <> nil) and ((S.TypeDesc.EndOfs = 0) or (Pos <= S.TypeDesc.EndOfs)) then
    DeclClass := S.TypeDesc;
end;

{ the tokens from ScanStart to the caret (conditional compilation applied). Shared: the lexer
  runs to the end of the text and stops at the first token at the caret or after - a later caret
  with the same scan start lexes on from there }
procedure TCIContext.CollectTokens(ScanStart: Integer; Shared: Boolean);
var
  Line, Col, Lim: Integer;
begin
  if ScanStart > Pos then ScanStart := Pos;
  if not Shared or (ScanStart <> FTokStart) or (FToks = nil) then
  begin
    FreeAndNil(FToks);
    FreeAndNil(Lex);
    FTokStart := ScanStart;
    FWithIdx := -1;
    if Shared then Lim := Length(U.Source) else Lim := Pos;
    Lex := TPasLexer.Create(U.Source, ScanStart, Lim);
    Lex.AddDefines(Eng.Defines);
    Lex.AutoAsm := True;
    Line := U.LineOfOffset(ScanStart, Col);
    Lex.SetStartLineCol(Line, Col);
    FToks := TRawToks.Create('', False);
    FMore := True;
  end;
  if Shared then
  begin
    while FMore and ((FToks.N = 0) or (FToks.T[FToks.N - 1].Start < Pos)) do
      FMore := FToks.Take(Lex, Pos);
    TokCount := FToks.FirstAt(Pos);
    InComment := False;
    InString := False;
  end
  else
  begin
    FToks.Take(Lex);
    TokCount := FToks.N;
    InComment := Lex.EndedInComment;
    InString := Lex.EndedInString;
  end;
  Toks := FToks.T;
end;

function TCIContext.IsSymAt(I: Integer; S: TSymbolId): Boolean;
begin
  Result := (I >= 0) and (I < TokCount) and (Toks[I].Symbol = S);
end;

function TCIContext.IsKwAt(I: Integer; K: TKeyword): Boolean;
begin
  Result := (I >= 0) and (I < TokCount) and (Toks[I].Keyword = K);
end;

procedure TCIContext.ComputeWiths(StartIdx: Integer);
var
  I, J, K, Depth, PD, ExprStart, N0, M: Integer;
  Found: Boolean;

  procedure PushWith(A, B: Integer);
  begin
    if B < A then Exit;
    if WithCount >= Length(Withs) then SetLength(Withs, WithCount + 8);
    FillChar(Withs[WithCount], SizeOf(TWithRec), 0);
    Withs[WithCount].A := A;
    Withs[WithCount].B := B;
    Withs[WithCount].OnVar := -1;
    Inc(WithCount);
  end;

begin
  { the state is kept before each token: a later caret in the same tokens goes on from the last
    one (what looks past the caret - an asm block's end, a with's do and what follows it - is
    looked at again then) }
  if (StartIdx <> FWithIdx) or (FWNext > TokCount) then
  begin
    FWithIdx := StartIdx;
    FWNext := StartIdx;
    FWDepth := 0;
    FWPD := 0;
    FWCount := 0;
  end;
  WithCount := FWCount;
  Depth := FWDepth;
  PD := FWPD;
  I := FWNext;
  while I < TokCount do
  begin
    FWNext := I;
    FWDepth := Depth;
    FWPD := PD;
    FWCount := WithCount;
    { an exception handler, on E: T do: its variable is in scope in its statement as a with's
      members are in a with's. A caret in its heading stops the scan at on: a later caret looks
      at the heading again }
    if (Toks[I].Kind = tkIdent) and (Toks[I].Directive = dvOn) and
      ((I + 1 >= TokCount) or (Toks[I + 1].Kind = tkIdent) and ((I + 2 >= TokCount) or IsSymAt(I + 2, syColon))) then
    begin
      J := I + 3;
      while (J < TokCount) and ((Toks[J].Kind = tkIdent) or IsSymAt(J, syDot)) do Inc(J);
      if J >= TokCount then Break;
      if (J > I + 3) and IsKwAt(J, kwDo) then
      begin
        N0 := WithCount;
        PushWith(I + 3, J - 1);
        Withs[N0].OnVar := I + 1;
        if IsKwAt(J + 1, kwBegin) or IsKwAt(J + 1, kwTry) or IsKwAt(J + 1, kwCase) then
        begin
          Inc(Depth);
          Withs[N0].Depth := Depth;
          I := J + 2;
        end
        else
        begin
          Withs[N0].Depth := Depth;
          Withs[N0].Single := True;
          I := J + 1;
        end;
        Continue;
      end;
    end;
    if Toks[I].Kind = tkKeyword then
    begin
      case Toks[I].Keyword of
        kwBegin, kwTry, kwCase:
          Inc(Depth);
        kwAsm:
          begin
            Inc(I);
            while (I < TokCount) and (Toks[I].Keyword <> kwEnd) do Inc(I);
          end;
        kwEnd:
          begin
            while (WithCount > 0) and (Withs[WithCount - 1].Depth >= Depth) do Dec(WithCount);
            if Depth > 0 then Dec(Depth);
          end;
        kwWith:
          begin
            N0 := WithCount;
            J := I + 1;
            ExprStart := J;
            K := 0;
            Found := False;
            while J < TokCount do
            begin
              if Toks[J].Kind = tkSymbol then
              begin
                case Toks[J].Symbol of
                  syLParen, syLBracket: Inc(K);
                  syRParen, syRBracket: if K > 0 then Dec(K);
                  syComma:
                    if K = 0 then
                    begin
                      PushWith(ExprStart, J - 1);
                      ExprStart := J + 1;
                    end;
                  sySemicolon:
                    if K = 0 then Break;
                end;
              end
              else if Toks[J].Kind = tkKeyword then
              begin
                if (Toks[J].Keyword = kwDo) and (K = 0) then
                begin
                  PushWith(ExprStart, J - 1);
                  Found := True;
                  Break;
                end;
                if Toks[J].Keyword in [kwBegin, kwEnd, kwThen, kwElse, kwWith, kwTry, kwRepeat, kwUntil] then
                  Break;
              end;
              Inc(J);
            end;
            if not Found then
            begin
              { the caret inside the with's list: each expression sees the members of those before
                it (with A, B do is with A do with B do); else broken code }
              if J >= TokCount then Break;
              WithCount := N0;
              I := J;
              Continue;
            end;
            if (J + 1 < TokCount) and (Toks[J + 1].Keyword in [kwBegin, kwTry, kwCase]) then
            begin
              Inc(Depth);
              for M := N0 to WithCount - 1 do
              begin
                Withs[M].Depth := Depth;
                Withs[M].Single := False;
              end;
              I := J + 2;
              Continue;
            end
            else
            begin
              for M := N0 to WithCount - 1 do
              begin
                Withs[M].Depth := Depth;
                Withs[M].Single := True;
              end;
              I := J + 1;
              Continue;
            end;
          end;
      end;
    end
    else if Toks[I].Kind = tkSymbol then
    begin
      case Toks[I].Symbol of
        syLParen, syLBracket: Inc(PD);
        syRParen, syRBracket: if PD > 0 then Dec(PD);
        sySemicolon:
          if PD = 0 then
            while (WithCount > 0) and Withs[WithCount - 1].Single and
              (Withs[WithCount - 1].Depth = Depth) do Dec(WithCount);
      end;
    end;
    Inc(I);
  end;
end;

function TCIContext.MatchOpen(K: Integer): Integer;
var
  Depth: Integer;
begin
  Depth := 0;
  while K >= 0 do
  begin
    if Toks[K].Kind = tkSymbol then
      case Toks[K].Symbol of
        syRParen, syRBracket: Inc(Depth);
        syLParen, syLBracket:
          begin
            Dec(Depth);
            if Depth = 0 then
            begin
              Result := K;
              Exit;
            end;
          end;
      end;
    Dec(K);
  end;
  Result := -1;
end;

function TCIContext.MatchClose(I, B: Integer): Integer;
var
  Depth: Integer;
begin
  Depth := 0;
  while I <= B do
  begin
    if Toks[I].Kind = tkSymbol then
      case Toks[I].Symbol of
        syLParen, syLBracket: Inc(Depth);
        syRParen, syRBracket:
          begin
            Dec(Depth);
            if Depth = 0 then
            begin
              Result := I;
              Exit;
            end;
          end;
      end;
    Inc(I);
  end;
  Result := -1;
end;

{ index of the first token of the postfix chain that ends at EndIdx; -1 if none }
function TCIContext.ChainStart(EndIdx: Integer): Integer;
var
  K: Integer;
begin
  Result := -1;
  K := EndIdx;
  while K >= 0 do
  begin
    if IsSymAt(K, syRParen) or IsSymAt(K, syRBracket) then
    begin
      K := MatchOpen(K);
      if K < 0 then Exit;
      if (K > 0) and ((Toks[K - 1].Kind = tkIdent) or IsSymAt(K - 1, syRParen) or
        IsSymAt(K - 1, syRBracket) or IsSymAt(K - 1, syCaret) or IsKwAt(K - 1, kwString)) then
      begin
        Dec(K);
        Continue;
      end;
      if IsSymAt(K, syLParen) then Result := K;
      Exit;
    end
    else if IsSymAt(K, syCaret) then
      Dec(K)
    else if (Toks[K].Kind = tkIdent) or IsKwAt(K, kwString) or (Toks[K].Kind = tkString) then
    begin
      if (K >= 2) and IsSymAt(K - 1, syDot) then
      begin
        K := K - 2;
        Continue;
      end;
      if (K >= 1) and IsKwAt(K - 1, kwInherited) then
        Result := K - 1
      else
        Result := K;
      Exit;
    end
    else
      Exit;
  end;
end;

function TCIContext.ChainEndForward(A, B: Integer): Integer;
var
  I, J: Integer;
begin
  Result := A - 1;
  I := A;
  if I > B then Exit;
  if IsSymAt(I, syLParen) then
  begin
    J := MatchClose(I, B);
    if J < 0 then
    begin
      Result := B;
      Exit;
    end;
    I := J + 1;
  end
  else if IsKwAt(I, kwInherited) then
  begin
    Inc(I);
    if (I <= B) and (Toks[I].Kind = tkIdent) then Inc(I);
  end
  else if (Toks[I].Kind in [tkIdent, tkString]) or IsKwAt(I, kwString) then
    Inc(I)
  else
    Exit;
  while I <= B do
  begin
    if IsSymAt(I, syDot) and (I + 1 <= B) and (Toks[I + 1].Kind = tkIdent) then
      Inc(I, 2)
    else if IsSymAt(I, syLParen) or IsSymAt(I, syLBracket) then
    begin
      J := MatchClose(I, B);
      if J < 0 then
      begin
        Result := B;
        Exit;
      end;
      I := J + 1;
    end
    else if IsSymAt(I, syCaret) then
      Inc(I)
    else
      Break;
  end;
  Result := I - 1;
end;

function TCIContext.FromSym(S: TSymbol): TResolved;
begin
  Result := NoRes;
  Result.Sym := S;
  case S.Kind of
    skVar, skLocal, skParam, skField, skConst, skResStr, skEnumValue:
      begin
        Result.Kind := rkValue;
        Result.TD := S.TypeDesc;
      end;
    skProperty:
      begin
        Result.Kind := rkValue;
        Result.TD := Eng.PropertyType(S);
        Result.NeedIndex := sfArrayProp in S.Flags;
      end;
    skRoutine:
      Result.Kind := rkRoutine;
    skType:
      begin
        Result.Kind := rkType;
        Result.TD := S.TypeDesc;
      end;
  end;
end;

function TCIContext.ToValue(const R: TResolved): TResolved;
var
  RS: TSymbol;
begin
  Result := R;
  if R.Kind <> rkRoutine then Exit;
  Result := NoRes;
  Result.Sym := R.Sym;
  RS := R.Sym;
  if RS = nil then Exit;
  if sfConstructor in RS.Flags then
  begin
    Result.Kind := rkValue;
    Result.TD := R.SelfTD;
    if (Result.TD = nil) and (RS.Owner is TTypeDesc) then Result.TD := TTypeDesc(RS.Owner);
  end
  else if sfFunction in RS.Flags then
  begin
    Result.Kind := rkValue;
    Result.TD := RS.TypeDesc;
  end;
end;

function TCIContext.ValueDesc(const R0: TResolved): TTypeDesc;
var
  R: TResolved;
begin
  Result := nil;
  R := ToValue(R0);
  if (R.Kind <> rkValue) or (R.TD = nil) or R.NeedIndex then Exit;
  Result := Eng.ResolveDesc(R.TD);
  if (Result <> nil) and (Result.Kind = tyPointer) and (Result.Elem <> nil) then
    Result := Eng.ResolveDesc(Result.Elem);
end;

function TCIContext.ClassRefTarget(D: TTypeDesc): TTypeDesc;
var
  S: TSymbol;
begin
  Result := nil;
  S := Eng.FindQualified(D.RefName, D.UnitInfo, D.InImpl, D.OwnerRoutine);
  if (S <> nil) and (S.Kind = skType) and (S.TypeDesc <> nil) then
    Result := Eng.ResolveDesc(S.TypeDesc);
end;

{ the structured type whose members a value of type D offers - a class reference's class
  (ClassLevel: only its class methods and constructors) -; nil: none }
function TCIContext.MemberScope(D: TTypeDesc; out ClassLevel: Boolean): TTypeDesc;
begin
  ClassLevel := (D <> nil) and (D.Kind = tyClassRef);
  if ClassLevel then Result := ClassRefTarget(D)
  else if (D <> nil) and (D.Kind in StructKinds) then Result := D
  else Result := nil;
end;

{ the member P of D (or of an ancestor) as R, reached through SelfD; False: D has none (R stays
  as it was) }
function TCIContext.MemberRes(D, SelfD: TTypeDesc; P: PChar; Len: Integer; var R: TResolved): Boolean;
var
  S: TSymbol;
  DD: TTypeDesc;
begin
  S := Eng.FindMember(D, P, Len, DD);
  { a private member of a class of another unit is not visible here: the name is an ancestor's
    member, else a name of the scopes around (as the compiler sees it) }
  while (S <> nil) and (S.Visibility = viPrivate) and (DD <> nil) and (DD.UnitInfo <> U) do
    if (DD.Members <> nil) and (DD.Members.FindNext(S) <> nil) then
      S := DD.Members.FindNext(S)          // another declaration of the name: an overload
    else
    begin
      D := Eng.AncestorOf(DD);
      if D = nil then S := nil else S := Eng.FindMember(D, P, Len, DD);
    end;
  Result := S <> nil;
  if not Result then Exit;
  R := FromSym(S);
  R.SelfTD := SelfD;
end;

function TCIContext.MemberOf(const R: TResolved; P: PChar; Len: Integer): TResolved;
var
  D: TTypeDesc;
  S: TSymbol;
  ClassLevel: Boolean;
begin
  Result := NoRes;
  case R.Kind of
    rkUnit:
      begin
        S := nil;
        if R.UnitInfo = nil then Exit;
        if (R.UnitInfo = U) and InImpl then S := U.ImplSyms.FindP(P, Len);
        if S = nil then S := UnitSyms(R.UnitInfo).FindP(P, Len);
        if (S = nil) and SameText(R.UnitInfo.Name, 'System') then
          S := Eng.Builtin.IntfSyms.FindP(P, Len);
        if S <> nil then Result := FromSym(S);
      end;
    rkType:
      begin
        D := Eng.ResolveDesc(R.TD);
        if (D <> nil) and (D.Kind in StructKinds) then MemberRes(D, D, P, Len, Result);
      end;
    rkValue, rkRoutine:
      begin
        D := MemberScope(ValueDesc(R), ClassLevel);
        if D <> nil then MemberRes(D, D, P, Len, Result);
      end;
  end;
end;

function TCIContext.ApplyCall(const R: TResolved): TResolved;
var
  D: TTypeDesc;
begin
  Result := NoRes;
  case R.Kind of
    rkRoutine:
      Result := ToValue(R);
    rkType:
      begin
        Result := R;
        Result.Kind := rkValue;
      end;
    rkValue:
      begin
        if R.NeedIndex then Exit;
        D := Eng.ResolveDesc(R.TD);
        if (D <> nil) and (D.Kind = tyProc) and (D.Elem <> nil) then
        begin
          Result.Kind := rkValue;
          Result.TD := D.Elem;
        end;
      end;
  end;
end;

function TCIContext.DefaultPropOf(D: TTypeDesc): TSymbol;
var
  Depth: Integer;
begin
  Result := nil;
  Depth := 0;
  while (D <> nil) and (Depth < 64) do
  begin
    if D.DefaultProp <> nil then
    begin
      Result := D.DefaultProp;
      Exit;
    end;
    D := Eng.AncestorOf(D);
    Inc(Depth);
  end;
end;

function TCIContext.ApplyIndex(const R0: TResolved; NIdx: Integer): TResolved;
var
  R: TResolved;
  D, E: TTypeDesc;
  P: TSymbol;
begin
  Result := NoRes;
  R := ToValue(R0);
  if R.Kind <> rkValue then Exit;
  if R.NeedIndex then
  begin
    Result := R;
    Result.NeedIndex := False;
    Exit;
  end;
  D := Eng.ResolveDesc(R.TD);
  if D = nil then Exit;
  case D.Kind of
    tyArray:
      begin
        E := nil;
        while (NIdx > 0) and (D <> nil) and (D.Kind = tyArray) do
        begin
          E := D.Elem;
          Dec(NIdx);
          if NIdx > 0 then D := Eng.ResolveDesc(E);
        end;
        if E <> nil then
        begin
          Result.Kind := rkValue;
          Result.TD := E;
        end;
      end;
    tyPointer:
      if D.Elem <> nil then
      begin
        Result.Kind := rkValue;
        Result.TD := D.Elem;
      end;
    tyClass, tyInterface, tyObject, tyRecord:
      begin
        P := DefaultPropOf(D);
        if P <> nil then
        begin
          Result.Kind := rkValue;
          Result.TD := Eng.PropertyType(P);
          Result.Sym := P;
        end;
      end;
  end;
end;

function TCIContext.ApplyDeref(const R0: TResolved): TResolved;
var
  R: TResolved;
  D: TTypeDesc;
begin
  Result := NoRes;
  R := ToValue(R0);
  if (R.Kind <> rkValue) or R.NeedIndex then Exit;
  D := Eng.ResolveDesc(R.TD);
  if (D <> nil) and (D.Kind = tyPointer) and (D.Elem <> nil) then
  begin
    Result.Kind := rkValue;
    Result.TD := D.Elem;
  end;
end;

function TCIContext.EvalWith(I: Integer): TResolved;
begin
  { an exception handler's variable brings no members into scope (LookupIdent finds it by name) }
  if Withs[I].OnVar >= 0 then
  begin
    Result := NoRes;
    Exit;
  end;
  if not Withs[I].Evaluated then
  begin
    Withs[I].Evaluated := True;
    Withs[I].Res := NoRes;
    Withs[I].Res := EvalExprRange(Withs[I].A, Withs[I].B, I);
  end;
  Result := Withs[I].Res;
end;

function TCIContext.LookupInherited(P: PChar; Len: Integer): TResolved;
var
  Anc: TTypeDesc;
begin
  Result := NoRes;
  if ClassDesc = nil then Exit;
  Anc := Eng.AncestorOf(ClassDesc);
  if Anc <> nil then MemberRes(Anc, ClassDesc, P, Len, Result);
end;

function TCIContext.LookupIdent(P: PChar; Len, WithLimit: Integer): TResolved;
var
  R: TRoutineSym;
  S: TSymbol;
  I: Integer;
  D: TTypeDesc;
  UU: TUnitInfo;
  Name: string;
  T: PToken;
  Ps: TList;
begin
  Result := NoRes;
  if (ClassDesc <> nil) and SameTextP(P, Len, 'SELF') then
  begin
    Result.Kind := rkValue;
    Result.TD := ClassDesc;
    Exit;
  end;
  if SameTextP(P, Len, 'RESULT') then
  begin
    R := Routine;
    while R <> nil do
    begin
      if sfFunction in R.Flags then
      begin
        Result.Kind := rkValue;
        Result.TD := R.TypeDesc;
        Exit;
      end;
      R := OuterOf(R);
    end;
  end;
  // with scopes are innermost, with the variables of the exception handlers around the place
  for I := WithLimit - 1 downto 0 do
  begin
    if Withs[I].OnVar >= 0 then
    begin
      T := @Toks[Withs[I].OnVar];
      if (T.PLen = Len) and (StrLIComp(T.Ptr, P, Len) = 0) then
      begin
        { a value of the handler's type (none when the type is unknown: the name is declared) }
        Result := EvalExprRange(Withs[I].A, Withs[I].B, I);
        if Result.Kind <> rkType then Result := NoRes;
        Result.Kind := rkValue;
        Result.Sym := nil;
        Exit;
      end;
      Continue;
    end;
    D := ValueDesc(EvalWith(I));
    if (D <> nil) and (D.Kind in StructKinds) and MemberRes(D, D, P, Len, Result) then Exit;
  end;
  // locals and parameters of the enclosing routines
  R := Routine;
  while R <> nil do
  begin
    if R.Locals <> nil then
    begin
      S := R.Locals.FindP(P, Len);
      if S <> nil then
      begin
        Result := FromSym(S);
        Exit;
      end;
    end;
    Ps := RoutineParams(R);
    if Ps <> nil then
      for I := 0 to Ps.Count - 1 do
        if SameTextP(P, Len, TSymbol(Ps[I]).Name) then
        begin
          Result := FromSym(TSymbol(Ps[I]));
          Exit;
        end;
    R := OuterOf(R);
  end;
  // members of the enclosing class
  if (ClassDesc <> nil) and MemberRes(ClassDesc, ClassDesc, P, Len, Result) then Exit;
  // unit scope, used units, System
  S := Eng.FindInUnitScope(P, Len, U, InImpl);
  if S <> nil then
  begin
    Result := FromSym(S);
    Exit;
  end;
  // members of the class whose declaration the caret is in
  if (DeclClass <> nil) and MemberRes(DeclClass, DeclClass, P, Len, Result) then Exit;
  // unit names
  SetString(Name, P, Len);
  UU := nil;
  if SameText(Name, U.Name) then
    UU := U
  else if (U.IntfUses.IndexOf(Name) >= 0) or (U.ImplUses.IndexOf(Name) >= 0) or SameText(Name, 'System') or
    SameText(Name, 'SysInit') then
    UU := Eng.UnitByName(Name, U);
  if UU <> nil then
  begin
    Result.Kind := rkUnit;
    Result.UnitInfo := UU;
  end;
end;

function TCIContext.EvalChain(A, B, WithLimit: Integer): TResolved;
var
  I, J, K, N, Depth: Integer;
begin
  Result := NoRes;
  if (A < 0) or (A > B) or (B >= TokCount) then Exit;
  Inc(FEvalDepth);
  try
    if FEvalDepth > 24 then Exit;
    I := A;
    if IsSymAt(I, syLParen) then
    begin
      J := MatchClose(I, B);
      if J < 0 then J := B + 1;
      Result := EvalExprRange(I + 1, J - 1, WithLimit);
      I := J + 1;
    end
    else if IsKwAt(I, kwInherited) then
    begin
      Inc(I);
      if (I <= B) and (Toks[I].Kind = tkIdent) then
      begin
        Result := LookupInherited(Toks[I].Ptr, Toks[I].PLen);
        Inc(I);
      end
      else
        Exit;
    end
    else if Toks[I].Kind = tkIdent then
    begin
      Result := LookupIdent(Toks[I].Ptr, Toks[I].PLen, WithLimit);
      Inc(I);
    end
    else
      Exit;   // string literals / 'string' have no members
    while (I <= B) and (Result.Kind <> rkNone) do
    begin
      if IsSymAt(I, syDot) then
      begin
        if (I + 1 <= B) and (Toks[I + 1].Kind in [tkIdent, tkKeyword]) then
        begin
          Result := MemberOf(Result, Toks[I + 1].Ptr, Toks[I + 1].PLen);
          Inc(I, 2);
        end
        else
        begin
          Result := NoRes;
          Exit;
        end;
      end
      else if IsSymAt(I, syLParen) then
      begin
        J := MatchClose(I, B);
        if J < 0 then J := B;
        Result := ApplyCall(Result);
        I := J + 1;
      end
      else if IsSymAt(I, syLBracket) then
      begin
        J := MatchClose(I, B);
        if J < 0 then J := B;
        N := 1;
        Depth := 0;
        for K := I + 1 to J - 1 do
          if Toks[K].Kind = tkSymbol then
            case Toks[K].Symbol of
              syLParen, syLBracket: Inc(Depth);
              syRParen, syRBracket: Dec(Depth);
              syComma: if Depth = 0 then Inc(N);
            end;
        Result := ApplyIndex(Result, N);
        I := J + 1;
      end
      else if IsSymAt(I, syCaret) then
      begin
        Result := ApplyDeref(Result);
        Inc(I);
      end
      else
      begin
        Result := NoRes;
        Exit;
      end;
    end;
  finally
    Dec(FEvalDepth);
  end;
end;

function TCIContext.EvalExprRange(A, B, WithLimit: Integer): TResolved;
var
  I, Depth, LastAs, E: Integer;
  R: TResolved;
begin
  Result := NoRes;
  if (A < 0) or (A > B) or (B >= TokCount) then Exit;
  Depth := 0;
  LastAs := -1;
  for I := A to B do
    if Toks[I].Kind = tkSymbol then
    begin
      case Toks[I].Symbol of
        syLParen, syLBracket: Inc(Depth);
        syRParen, syRBracket: Dec(Depth);
      end;
    end
    else if (Depth = 0) and (Toks[I].Keyword = kwAs) then
      LastAs := I;
  if LastAs >= 0 then
  begin
    E := ChainEndForward(LastAs + 1, B);
    R := EvalChain(LastAs + 1, E, WithLimit);
    if R.Kind = rkType then
    begin
      R.Kind := rkValue;
      Result := R;
    end;
    Exit;
  end;
  I := A;
  while (I <= B) and (IsSymAt(I, syAt) or IsKwAt(I, kwNot) or IsSymAt(I, syMinus) or IsSymAt(I, syPlus)) do
    Inc(I);
  if I > B then Exit;
  E := ChainEndForward(I, B);
  if E < I then Exit;
  Result := EvalChain(I, E, WithLimit);
end;

function TCIContext.InUsesClause(N: Integer): Boolean;
var
  K: Integer;
begin
  Result := False;
  K := N - 1;
  while K >= 0 do
  begin
    case Toks[K].Kind of
      tkIdent, tkString: ;
      tkSymbol:
        if Toks[K].Symbol <> syComma then Exit;
      tkKeyword:
        begin
          if Toks[K].Keyword = kwUses then
          begin
            Result := True;
            Exit;
          end;
          if Toks[K].Keyword <> kwIn then Exit;
        end;
    else
      Exit;
    end;
    Dec(K);
  end;
end;

function TCIContext.ScopeOf(S: TSymbol): string;
begin
  if S.Owner is TTypeDesc then
  begin
    if TTypeDesc(S.Owner).Sym <> nil then Result := TTypeDesc(S.Owner).Sym.Name
    else Result := '';
  end
  else if S.Owner is TRoutineSym then
    Result := TRoutineSym(S.Owner).Name
  else if S.UnitInfo <> nil then
    Result := S.UnitInfo.Name
  else
    Result := '';
end;

procedure TCIContext.MakeItem(S: TSymbol; var Item: TCIItem);
begin
  Item.Name := S.Name;
  Item.Kind := SymKind(S);
  Item.Decl := Eng.DeclText(S);
  Item.TypeName := Eng.TypeText(S);
  if S is TRoutineSym then Item.Params := Eng.ParamsText(S) else Item.Params := '';
  Item.Scope := ScopeOf(S);
  Item.Visibility := TCIVisibility(Ord(S.Visibility));
  if S.UnitInfo <> nil then Item.FileName := S.UnitInfo.FileName else Item.FileName := '';
  if (Item.FileName <> '') and (Item.FileName[1] = '<') then Item.FileName := '';
  Item.Line := S.Line;
  Item.Col := S.Col;
  if S.UnitInfo = Eng.Builtin then
  begin
    Item.Line := 0;
    Item.Col := 0;
  end;
end;

procedure TCIContext.AddItem(List: TCIItemList; S: TSymbol);
begin
  MakeItem(S, List.Add^);
end;

procedure TCIContext.AddPseudo(List: TCIItemList; const AName: string; AKind: TCIKind;
  const ADecl, AType: string);
var
  P: PCIItem;
begin
  P := List.Add;
  P^.Name := AName;
  P^.Kind := AKind;
  P^.Decl := ADecl;
  P^.TypeName := AType;
end;

procedure TCIContext.AddTable(Tab: TSymTable; List: TCIItemList; HideUnderscore: Boolean);
var
  I: Integer;
  S: TSymbol;
begin
  if Tab = nil then Exit;
  for I := 0 to Tab.Count - 1 do
  begin
    S := Tab[I];
    if HideUnderscore and (S.Name <> '') and (S.Name[1] = '_') then Continue;
    if FSeen.Accept(S) then AddItem(List, S);
  end;
  Inc(FSeen.Level);
end;

procedure TCIContext.AddClassMembers(D: TTypeDesc; List: TCIItemList; ClassLevelOnly: Boolean);
var
  Cur: TTypeDesc;
  Depth, I: Integer;
  S: TSymbol;
  SameUnit, ProtOK: Boolean;
begin
  Cur := D;
  Depth := 0;
  while (Cur <> nil) and (Depth < 64) do
  begin
    if Cur.Members <> nil then
    begin
      SameUnit := Cur.UnitInfo = U;
      { protected members: only inside the class hierarchy, and only through a reference of
        the current class or one of its descendants (Edit1.SomeProtected is not accessible
        from a form method) }
      ProtOK := SameUnit or ((ClassDesc <> nil) and Eng.InheritsFrom(D, ClassDesc) and
        Eng.InheritsFrom(ClassDesc, Cur));
      for I := 0 to Cur.Members.Count - 1 do
      begin
        S := Cur.Members[I];
        if ClassLevelOnly and not ((S.Kind = skRoutine) and
          ((sfConstructor in S.Flags) or (sfClassMethod in S.Flags))) then Continue;
        case S.Visibility of
          viPrivate: if not SameUnit then Continue;
          viProtected: if not ProtOK then Continue;
        end;
        if FSeen.Accept(S) then AddItem(List, S);
      end;
      Inc(FSeen.Level);
    end;
    Cur := Eng.AncestorOf(Cur);
    Inc(Depth);
  end;
end;

procedure TCIContext.AddOwnMethods(D: TTypeDesc; List: TCIItemList);
var
  I: Integer;
  S: TSymbol;
begin
  if D.Members = nil then Exit;
  for I := 0 to D.Members.Count - 1 do
  begin
    S := D.Members[I];
    if (S.Kind = skRoutine) and FSeen.Accept(S) then AddItem(List, S);
  end;
  Inc(FSeen.Level);
end;

procedure TCIContext.AddMembersOf(const R0: TResolved; List: TCIItemList; HeadingMode: Boolean);
var
  D: TTypeDesc;
  ClassLevel: Boolean;
begin
  case R0.Kind of
    rkUnit:
      begin
        if R0.UnitInfo = nil then Exit;
        if (R0.UnitInfo = U) and InImpl then AddTable(U.ImplSyms, List, False);
        AddTable(UnitSyms(R0.UnitInfo), List, SameText(R0.UnitInfo.Name, 'System'));
        if SameText(R0.UnitInfo.Name, 'System') and (R0.UnitInfo <> Eng.Builtin) then
          AddTable(Eng.Builtin.IntfSyms, List, True);
      end;
    rkType:
      begin
        D := Eng.ResolveDesc(R0.TD);
        if D = nil then Exit;
        if D.Kind in [tyClass, tyObject] then
        begin
          if HeadingMode then AddOwnMethods(D, List)
          else AddClassMembers(D, List, True);
        end;
      end;
    rkValue, rkRoutine:
      begin
        D := MemberScope(ValueDesc(R0), ClassLevel);
        if D <> nil then AddClassMembers(D, List, ClassLevel);
      end;
  end;
end;

procedure TCIContext.AddUnitNames(List: TCIItemList);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    Eng.GetUnitNames(SL, U.FileName);
    for I := 0 to SL.Count - 1 do
      if not SameText(SL[I], U.Name) then
        AddPseudo(List, SL[I], ckUnit, 'unit ' + SL[I], '');
  finally
    SL.Free;
  end;
end;

procedure TCIContext.AddScope(List: TCIItemList);
var
  I: Integer;
  R: TRoutineSym;
  Ps: TList;
  D: TTypeDesc;
  K: TKeyword;
  HasResult, Hide: Boolean;
  S: string;
  C: TScopeCursor;
  Tab: TSymTable;
begin
  // with scopes
  for I := WithCount - 1 downto 0 do
  begin
    D := ValueDesc(EvalWith(I));
    if (D <> nil) and (D.Kind in StructKinds) then AddClassMembers(D, List, False);
  end;
  // locals
  HasResult := False;
  R := Routine;
  while R <> nil do
  begin
    Ps := RoutineParams(R);
    if Ps <> nil then
      for I := 0 to Ps.Count - 1 do
        if FSeen.Accept(TSymbol(Ps[I])) then AddItem(List, TSymbol(Ps[I]));
    if (sfFunction in R.Flags) and not HasResult then
    begin
      HasResult := True;
      if FSeen.AcceptName('Result') then
        AddPseudo(List, 'Result', ckLocalVar, 'var Result: ' + Eng.TypeText(R), Eng.TypeText(R));
    end;
    AddTable(R.Locals, List, False);
    R := OuterOf(R);
  end;
  // Self and class members
  if ClassDesc <> nil then
  begin
    S := '';
    if ClassDesc.Sym <> nil then S := ClassDesc.Sym.Name;
    if (Routine <> nil) and FSeen.AcceptName('Self') then
      AddPseudo(List, 'Self', ckLocalVar, 'var Self: ' + S, S);
    AddClassMembers(ClassDesc, List, False);
  end;
  // unit level: the unit, the units it uses, System - in the order lookups take
  C.Step := 0;
  C.Index := 0;
  while Eng.NextScope(U, InImpl, C, Tab, Hide) do AddTable(Tab, List, Hide);
  // unit names
  if FSeen.AcceptName(U.Name) then AddPseudo(List, U.Name, ckUnit, 'unit ' + U.Name, '');
  for I := 0 to U.IntfUses.Count - 1 do
    if FSeen.AcceptName(U.IntfUses[I]) then
      AddPseudo(List, U.IntfUses[I], ckUnit, 'unit ' + U.IntfUses[I], '');
  if InImpl then
    for I := 0 to U.ImplUses.Count - 1 do
      if FSeen.AcceptName(U.ImplUses[I]) then
        AddPseudo(List, U.ImplUses[I], ckUnit, 'unit ' + U.ImplUses[I], '');
  // keywords
  for K := Succ(kwNone) to High(TKeyword) do
    if FSeen.AcceptName(KeywordNames[K]) then
      AddPseudo(List, KeywordNames[K], ckKeyword, '', '');
end;

function TCIContext.Complete(List: TCIItemList; out PrefixStart: Integer): Boolean;
var
  N, CS: Integer;
  R: TResolved;
  HeadingMode: Boolean;
begin
  Result := False;
  PrefixStart := Pos;
  N := TokCount;
  if N > 0 then
    if (Toks[N - 1].Len > 0) and (Toks[N - 1].Start + Toks[N - 1].Len = Pos) then
    begin
      if Toks[N - 1].Kind in [tkIdent, tkKeyword] then
      begin
        PrefixStart := Toks[N - 1].Start;
        Dec(N);
      end
      else if Toks[N - 1].Kind = tkNumber then
        Exit;
    end;
  FSeen := TNameSet.Create;
  try
    if (N > 0) and IsSymAt(N - 1, syDot) then
    begin
      CS := ChainStart(N - 2);
      if CS < 0 then Exit;
      HeadingMode := (CS = N - 2) and (CS > 0) and
        (Toks[CS - 1].Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor]);
      R := EvalChain(CS, N - 2, WithCount);
      if R.Kind = rkNone then Exit;
      AddMembersOf(R, List, HeadingMode);
    end
    else if InUsesClause(N) then
      AddUnitNames(List)
    else if (N > 0) and IsKwAt(N - 1, kwInherited) and (ClassDesc <> nil) and
      (Eng.AncestorOf(ClassDesc) <> nil) then
      AddClassMembers(Eng.AncestorOf(ClassDesc), List, False)
    else
      AddScope(List);
    Result := List.Count > 0;
  finally
    FSeen.Free;
    FSeen := nil;
  end;
end;

procedure TCIContext.BuildHint(RS: TRoutineSym; var H: TCIParamHint);
var
  I: Integer;
begin
  H.Signature := Eng.HeadingText(RS, False, False);
  EnsureParams(RS);
  if RS.Params = nil then
    SetLength(H.Params, 0)
  else
  begin
    SetLength(H.Params, RS.Params.Count);
    for I := 0 to RS.Params.Count - 1 do
      H.Params[I] := Eng.ParamText(TSymbol(RS.Params[I]));
  end;
end;

function TCIContext.ParamHints(out Hints: TCIParamHintArray; out ActiveParam: Integer): Boolean;
var
  K, Depth, Commas, CallIdx, E, CS, I, N, Level: Integer;
  R, Q: TResolved;
  S, M: TSymbol;
  Tab: TSymTable;
  D, Cur: TTypeDesc;
  AllOvl: Boolean;

  procedure AddRoutine(RS: TSymbol);
  begin
    if not ((RS.Kind = skRoutine) and (RS is TRoutineSym)) then Exit;
    SetLength(Hints, N + 1);
    BuildHint(TRoutineSym(RS), Hints[N]);
    Inc(N);
    if not (sfOverload in RS.Flags) then AllOvl := False;
  end;

begin
  Result := False;
  Hints := nil;
  ActiveParam := 0;
  N := 0;
  Depth := 0;
  Commas := 0;
  CallIdx := -1;
  K := TokCount - 1;
  while K >= 0 do
  begin
    if Toks[K].Kind = tkSymbol then
    begin
      case Toks[K].Symbol of
        syRParen, syRBracket: Inc(Depth);
        syLParen:
          if Depth = 0 then
          begin
            if (K > 0) and (Toks[K - 1].Kind = tkIdent) then
            begin
              CallIdx := K;
              Break;
            end;
            Commas := 0;   // a grouping parenthesis inside an argument: keep looking outwards
          end
          else
            Dec(Depth);
        syLBracket:
          if Depth = 0 then Commas := 0 else Dec(Depth);
        syComma:
          if Depth = 0 then Inc(Commas);
        sySemicolon:
          if Depth = 0 then Break;
      end;
    end
    else if (Toks[K].Kind = tkKeyword) and (Depth = 0) and
      (Toks[K].Keyword in [kwBegin, kwEnd, kwThen, kwDo, kwElse, kwTry, kwRepeat, kwUntil,
        kwExcept, kwFinally, kwVar, kwConst, kwType, kwProcedure, kwFunction, kwImplementation,
        kwInterface, kwUses, kwConstructor, kwDestructor, kwProperty]) then
      Break;
    Dec(K);
  end;
  if CallIdx <= 0 then Exit;
  ActiveParam := Commas;
  E := CallIdx - 1;
  if Toks[E].Kind <> tkIdent then Exit;
  CS := ChainStart(E);
  if CS < 0 then Exit;
  if (CS > 0) and (Toks[CS - 1].Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor]) then Exit;
  AllOvl := True;
  if (E >= 2) and IsSymAt(E - 1, syDot) and (CS <= E - 2) then
  begin
    Q := EvalChain(CS, E - 2, WithCount);
    if Q.Kind = rkNone then Exit;
    R := MemberOf(Q, Toks[E].Ptr, Toks[E].PLen);
  end
  else if (E >= 1) and IsKwAt(E - 1, kwInherited) then
    R := LookupInherited(Toks[E].Ptr, Toks[E].PLen)
  else
    R := LookupIdent(Toks[E].Ptr, Toks[E].PLen, WithCount);
  S := R.Sym;
  if S = nil then Exit;
  if R.Kind = rkRoutine then
  begin
    if S.Owner is TTypeDesc then
    begin
      // all overloads in the class chain
      Cur := TTypeDesc(S.Owner);
      Level := 0;
      while (Cur <> nil) and (Level < 64) do
      begin
        if Cur.Members <> nil then
        begin
          M := Cur.Members.Find(S.Name);
          while M <> nil do
          begin
            AddRoutine(M);
            M := Cur.Members.FindNext(M);
          end;
        end;
        if not AllOvl then Break;
        Cur := Eng.AncestorOf(Cur);
        Inc(Level);
      end;
    end
    else
    begin
      if S.Owner is TRoutineSym then Tab := TRoutineSym(S.Owner).Locals
      else if S.UnitInfo = nil then Tab := nil
      else if (sfInImpl in S.Flags) or S.UnitInfo.IsProgram then Tab := S.UnitInfo.ImplSyms
      else Tab := S.UnitInfo.IntfSyms;
      if Tab <> nil then
      begin
        M := Tab.Find(S.Name);
        while M <> nil do
        begin
          AddRoutine(M);
          M := Tab.FindNext(M);
        end;
      end;
      if N = 0 then AddRoutine(S);
    end;
  end
  else if R.Kind = rkValue then
  begin
    // variable / property / field of a procedural type (events)
    if R.NeedIndex then Exit;
    D := Eng.ResolveDesc(R.TD);
    if (D = nil) or (D.Kind <> tyProc) then Exit;
    SetLength(Hints, 1);
    EnsureTypeParams(D);
    if D.IsFunction then Hints[0].Signature := 'function ' + S.Name
    else Hints[0].Signature := 'procedure ' + S.Name;
    if D.ParamsEnd > D.ParamsStart then
      Hints[0].Signature := Hints[0].Signature + '(' +
        Eng.RangeText(D.UnitInfo, D.ParamsStart, D.ParamsEnd, 400) + ')';
    if D.Params <> nil then
    begin
      SetLength(Hints[0].Params, D.Params.Count);
      for I := 0 to D.Params.Count - 1 do
        Hints[0].Params[I] := Eng.ParamText(TSymbol(D.Params[I]));
    end;
    N := 1;
  end;
  Result := N > 0;
end;


function TCIContext.FindImplOf(S: TSymbol): TRoutineSym;
var
  Qual: string;
  UU: TUnitInfo;
  Impls: TList;
begin
  Result := nil;
  UU := S.UnitInfo;
  if (UU = nil) or not (S is TRoutineSym) then Exit;
  if S.Owner is TTypeDesc then
  begin
    if TTypeDesc(S.Owner).Sym = nil then Exit;
    Qual := TTypeDesc(S.Owner).Sym.Name;
  end
  else if S.Owner = nil then
    Qual := ''
  else
    Exit;
  Impls := TList.Create;
  try
    UU.GetImpls(Impls, Qual, S.Name);
    Result := TRoutineSym(PairRoutine(S, Impls));
  finally
    Impls.Free;
  end;
end;

{ the identifier that ends at the position: what it names (False: nothing known) }
function TCIContext.ResolveHere(out R: TResolved): Boolean;
var
  N, CS: Integer;
  Q: TResolved;
  UU: TUnitInfo;
  Name: string;
begin
  R := NoRes;
  Result := False;
  if TokCount = 0 then Exit;
  N := TokCount - 1;
  if not ((Toks[N].Kind = tkIdent) and (Toks[N].Start + Toks[N].Len = Pos)) then Exit;
  if (N >= 2) and IsSymAt(N - 1, syDot) then
  begin
    CS := ChainStart(N - 2);
    if CS >= 0 then
    begin
      Q := EvalChain(CS, N - 2, WithCount);
      if Q.Kind <> rkNone then R := MemberOf(Q, Toks[N].Ptr, Toks[N].PLen);
    end;
  end
  else if InUsesClause(N) then
  begin
    SetString(Name, Toks[N].Ptr, Toks[N].PLen);
    UU := Eng.UnitByName(Name, U);
    if UU <> nil then
    begin
      R.Kind := rkUnit;
      R.UnitInfo := UU;
    end;
  end
  else if (N >= 1) and IsKwAt(N - 1, kwInherited) then
    R := LookupInherited(Toks[N].Ptr, Toks[N].PLen)
  else
    R := LookupIdent(Toks[N].Ptr, Toks[N].PLen, WithCount);
  Result := R.Kind <> rkNone;
end;

{ the parameters in scope in the body of R: its own, else - its implementation does not list them -
  those of its declaration (a method's in its class, a routine's in the interface or declared
  forward) }
function TCIContext.RoutineParams(R: TRoutineSym): TList;

  function Declared(Tab: TSymTable): TRoutineSym;
  var
    S: TSymbol;
  begin
    Result := nil;
    if Tab = nil then Exit;
    S := Tab.Find(R.Name);
    while (S <> nil) and not ((S <> R) and (S.Kind = skRoutine) and (S is TRoutineSym) and
      (TRoutineSym(S).ParamsStart > 0)) do S := Tab.FindNext(S);
    Result := TRoutineSym(S);
  end;

var
  C: TSymbol;
  D: TTypeDesc;
  Decl: TRoutineSym;
begin
  EnsureParams(R);
  Result := R.Params;
  { a routine nested in another is a local one, never the implementation of a declaration }
  if (R.ParamsStart > 0) or (R.Name = '') or (R.ClassQual = '') and (R.Owner is TRoutineSym) then Exit;
  Decl := nil;
  if R.ClassQual <> '' then
  begin
    C := Eng.FindQualified(R.ClassQual, U, True, nil);
    if (C <> nil) and (C.Kind = skType) and (C.TypeDesc <> nil) then
    begin
      D := Eng.ResolveDesc(C.TypeDesc);
      if (D <> nil) and (D.Kind in StructKinds) then Decl := Declared(D.Members);
    end;
  end
  else
  begin
    if not U.IsProgram then Decl := Declared(U.IntfSyms);
    if Decl = nil then Decl := Declared(U.ImplSyms);
  end;
  if Decl <> nil then
  begin
    EnsureParams(Decl);
    Result := Decl.Params;
  end;
end;

{ every member of D is known: a structured type that is not a forward declaration, whose
  ancestors resolve up to the root - the one its heritage names, else the implicit one (TObject of
  a class, IInterface of an interface) }
function TCIContext.StructKnown(D: TTypeDesc): Boolean;
var
  Depth: Integer;
  Named, Root: Boolean;
  Anc: TTypeDesc;
begin
  Result := False;
  Depth := 0;
  while D <> nil do
  begin
    if (Depth > 64) or D.IsForward or not (D.Kind in StructKinds) then Exit;
    Named := (D.Ancestors <> nil) and (D.Ancestors.Count > 0);
    Root := (D.Sym <> nil) and ((D.Kind = tyClass) and SameText(D.Sym.Name, 'TObject') or
      (D.Kind = tyInterface) and (SameText(D.Sym.Name, 'IInterface') or SameText(D.Sym.Name, 'IUnknown')));
    if D.Kind = tyRecord then Anc := nil else Anc := Eng.AncestorOf(D);
    if (Anc = nil) and (Named or (D.Kind in [tyClass, tyInterface]) and not Root) then Exit;
    D := Anc;
    Inc(Depth);
  end;
  Result := True;
end;

{ every scope a name at the place could come from is known: the units the unit uses are found
  (with their sources), System and SysInit too; a method's class and the class whose declaration
  the place is in are complete; every with statement around the place has a complete structured
  type }
function TCIContext.ScopeKnown: Boolean;
var
  I: Integer;
  R: TRoutineSym;
  D: TTypeDesc;
begin
  Result := False;
  Eng.ResolveUses(U);
  for I := 0 to High(U.IntfUnits) do
    if U.IntfUnits[I] = nil then Exit;
  for I := 0 to High(U.ImplUnits) do
    if U.ImplUnits[I] = nil then Exit;
  if (Eng.SystemUnit = nil) or (Eng.SysInitUnit = nil) then Exit;
  R := Routine;
  while R <> nil do
  begin
    if R.ClassQual <> '' then
    begin
      if (ClassDesc = nil) or not StructKnown(ClassDesc) then Exit;
      Break;
    end;
    if R.Owner is TRoutineSym then R := TRoutineSym(R.Owner) else R := nil;
  end;
  { the class declared around the place: its members count after its heading (its heritage is
    looked up in the unit's scope) }
  if (DeclClass <> nil) and (Pos > DeclClass.HeaderEnd) and not StructKnown(DeclClass) then Exit;
  for I := 0 to WithCount - 1 do
    if Withs[I].OnVar < 0 then
    begin
      D := ValueDesc(EvalWith(I));
      if (D = nil) or not StructKnown(D) then Exit;
    end;
  Result := True;
end;

function TCIContext.Undeclared(APos: Integer; Use: TPasNameUse): Boolean;
var
  N, CS, K: Integer;
  Q, R: TResolved;
  D: TTypeDesc;
  ClassLevel: Boolean;
begin
  Result := False;
  Place(APos, True);
  if TokCount = 0 then Exit;
  N := TokCount - 1;
  if not ((Toks[N].Kind = tkIdent) and (Toks[N].Start + Toks[N].Len = Pos)) then Exit;
  case Use of
    nuName:
      if not ((N >= 1) and (IsSymAt(N - 1, syDot) or IsKwAt(N - 1, kwInherited))) then
        Result := not ResolveHere(R) and ScopeKnown;
    nuMember:
      if (N >= 2) and IsSymAt(N - 1, syDot) then
      begin
        CS := ChainStart(N - 2);
        if CS < 0 then Exit;
        { after (X as T) the compiler also takes the members of X's own type: not checked }
        for K := CS to N - 2 do
          if IsKwAt(K, kwAs) then Exit;
        Q := EvalChain(CS, N - 2, WithCount);
        { the chain's head resolved where every scope is known: no unit's name hides it }
        if (Q.Kind = rkNone) or (MemberOf(Q, Toks[N].Ptr, Toks[N].PLen).Kind <> rkNone) or not ScopeKnown then Exit;
        case Q.Kind of
          { a unit's interface - not System's and SysInit's, which hold the compiler's own names }
          rkUnit:
            Result := (Q.UnitInfo <> nil) and (Q.UnitInfo <> Eng.Builtin) and
              not SameText(Q.UnitInfo.Name, 'System') and not SameText(Q.UnitInfo.Name, 'SysInit');
          rkType:
            begin
              D := Eng.ResolveDesc(Q.TD);
              Result := (D <> nil) and StructKnown(D);
            end;
          rkValue, rkRoutine:
            begin
              D := MemberScope(ValueDesc(Q), ClassLevel);
              Result := (D <> nil) and StructKnown(D);
            end;
        end;
      end;
    nuInherited:
      if (N >= 1) and IsKwAt(N - 1, kwInherited) and (ClassDesc <> nil) then
        Result := (LookupInherited(Toks[N].Ptr, Toks[N].PLen).Kind = rkNone) and StructKnown(ClassDesc) and ScopeKnown;
  end;
end;

function TCIContext.FindDecl(var Item: TCIItem): Boolean;
var
  N: Integer;
  R: TResolved;
  S: TSymbol;
  UU: TUnitInfo;
  Impl: TRoutineSym;
begin
  Result := False;
  if not ResolveHere(R) then Exit;
  N := TokCount - 1;
  case R.Kind of
    rkNone: Exit;
    rkUnit:
      begin
        UU := R.UnitInfo;
        if (UU = nil) or (UU = Eng.Builtin) then Exit;
        Item.Name := UU.Name;
        Item.Kind := ckUnit;
        Item.Decl := 'unit ' + UU.Name;
        Item.TypeName := '';
        Item.Params := '';
        Item.Scope := '';
        Item.Visibility := cvNone;
        Item.FileName := UU.FileName;
        Item.Line := 1;
        Item.Col := 1;
        Result := True;
      end;
  else
    S := R.Sym;
    if S = nil then Exit;
    MakeItem(S, Item);
    // caret already on the declaration of a routine: go to its implementation
    if (S.Kind = skRoutine) and (S.UnitInfo = U) and (S.DeclStart = Toks[N].Start) and
      not (sfImplBody in S.Flags) then
    begin
      Impl := FindImplOf(S);
      if Impl <> nil then
      begin
        Item.Line := Impl.Line;
        Item.Col := Impl.Col;
      end;
    end;
    Result := True;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ structure }

function MemberCaption(Eng: TCIEngine; S: TSymbol): string;
var
  T: string;
begin
  case S.Kind of
    skRoutine:
      begin
        Result := S.Name;
        T := Eng.ParamsText(S);
        if T <> '' then Result := Result + '(' + T + ')';
        T := Eng.TypeText(S);
        if T <> '' then Result := Result + ': ' + T;
      end;
    skProperty, skField, skVar, skLocal:
      begin
        Result := S.Name;
        T := Eng.TypeText(S);
        if T <> '' then Result := Result + ': ' + T;
      end;
  else
    Result := S.Name;
  end;
end;

{ 'CLASS.NAME' of the implementation of every class's method (GetMethodImpls), sorted, the
  routine as the object of its entry (one entry per implementation) }
function MethodImplIndex(U: TUnitInfo): TStringList;
var
  List: TList;
  K: Integer;
  R: TRoutineSym;
begin
  Result := TStringList.Create;
  List := TList.Create;
  try
    U.GetMethodImpls(List);
    for K := 0 to List.Count - 1 do
    begin
      R := TRoutineSym(List[K]);
      Result.AddObject(UpperCase(R.ClassQual + '.' + R.Name), R);
    end;
  finally
    List.Free;
  end;
  Result.Sorted := True;
end;

procedure AddRoutineNode(Eng: TCIEngine; Parent: TCIStructNode; R: TRoutineSym; Depth: Integer);
var
  N: TCIStructNode;
  I: Integer;
  C: string;
begin
  if R.Name = '' then Exit;
  if R.ClassQual <> '' then C := R.ClassQual + '.' + R.Name else C := R.Name;
  N := Parent.AddChild(C, SymKind(R), R.Line, R.Col);
  if (R.Locals <> nil) and (Depth < 8) then
    for I := 0 to R.Locals.Count - 1 do
      if (R.Locals[I].Kind = skRoutine) and (R.Locals[I] is TRoutineSym) and
        (sfImplBody in R.Locals[I].Flags) then
        AddRoutineNode(Eng, N, TRoutineSym(R.Locals[I]), Depth + 1);
end;

function BuildStructure(Eng: TCIEngine; U: TUnitInfo): TCIStructNode;
var
  NClasses, NTypes, NVars, NProcs, NUses, N: TCIStructNode;
  Pass, I, J: Integer;
  Tab: TSymTable;
  S, M: TSymbol;
  D: TTypeDesc;
  L: Integer;
  Impls: TStringList;          // MethodImplIndex, made at the first method

  function Implemented(const Cls, Name: string): Boolean;
  begin
    if Impls = nil then Impls := MethodImplIndex(U);
    Result := Impls.IndexOf(UpperCase(Cls + '.' + Name)) >= 0;
  end;

begin
  Impls := nil;
  try
    Result := TCIStructNode.Create;
    Result.Caption := U.Name;
    Result.Kind := ckUnit;
    Result.Line := 1;
    Result.Col := 1;
    NClasses := nil;
    NTypes := nil;
    NVars := nil;
    for Pass := 0 to 1 do
    begin
      if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
      for I := 0 to Tab.Count - 1 do
      begin
        S := Tab[I];
        case S.Kind of
          skType:
            begin
              D := S.TypeDesc;
              if (D <> nil) and (D.Kind in StructKinds) then
              begin
                if D.IsForward then Continue;
                if NClasses = nil then NClasses := Result.AddChild('Classes', ckUnknown, 0, 0);
                N := NClasses.AddChild(Eng.DeclText(S), SymKind(S), S.Line, S.Col);
                N.Plain := S.Name;
                if D.Ancestors <> nil then N.Ancestors := D.Ancestors.CommaText;
                if D.Members <> nil then
                  for J := 0 to D.Members.Count - 1 do
                  begin
                    M := D.Members[J];
                    with N.AddChild(MemberCaption(Eng, M), SymKind(M), M.Line, M.Col) do
                    begin
                      Plain := M.Name;
                      Visibility := Ord(M.Visibility);
                      { a method of a class that is declared but not implemented (Explorer |
                        Highlight incomplete class items) }
                      Incomplete := (M.Kind = skRoutine) and (D.Kind in [tyClass, tyObject]) and
                        not (sfAbstract in M.Flags) and not Implemented(S.Name, M.Name);
                    end;
                  end;
              end
              else
              begin
                if NTypes = nil then NTypes := Result.AddChild('Types', ckUnknown, 0, 0);
                NTypes.AddChild(Eng.DeclText(S), SymKind(S), S.Line, S.Col);
              end;
            end;
          skVar, skConst, skResStr:
            begin
              if NVars = nil then NVars := Result.AddChild('Variables/Constants', ckUnknown, 0, 0);
              if S.Kind = skVar then
                NVars.AddChild(MemberCaption(Eng, S), ckVar, S.Line, S.Col)
              else
                NVars.AddChild(S.Name, SymKind(S), S.Line, S.Col);
            end;
        end;
      end;
    end;
    if U.ImplRoutines.Count > 0 then
    begin
      NProcs := Result.AddChild('Procedures', ckUnknown, 0, 0);
      for I := 0 to U.ImplRoutines.Count - 1 do
        AddRoutineNode(Eng, NProcs, TRoutineSym(U.ImplRoutines[I]), 0);
    end;
    if U.IntfUses.Count + U.ImplUses.Count > 0 then
    begin
      NUses := Result.AddChild('Uses', ckUnknown, 0, 0);
      for I := 0 to U.IntfUses.Count - 1 do
      begin
        L := Integer(U.IntfUses.Objects[I]);
        NUses.AddChild(U.IntfUses[I], ckUnit, L shr 10, L and 1023);
      end;
      for I := 0 to U.ImplUses.Count - 1 do
      begin
        L := Integer(U.ImplUses.Objects[I]);
        NUses.AddChild(U.ImplUses[I], ckUnit, L shr 10, L and 1023);
      end;
    end;
  finally
    Impls.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Code Explorer: the picture of Delphi 7's }

destructor TCIExpNode.Destroy;
var
  I: Integer;
begin
  if FChildren <> nil then
  begin
    for I := 0 to FChildren.Count - 1 do TObject(FChildren[I]).Free;
    FChildren.Free;
  end;
  inherited;
end;

function TCIExpNode.Count: Integer;
begin
  if FChildren = nil then Result := 0 else Result := FChildren.Count;
end;

function TCIExpNode.GetChild(Index: Integer): TCIExpNode;
begin
  Result := TCIExpNode(FChildren[Index]);
end;

function TCIExpNode.Add(AKind: TCIExpKind; AGroup: TCIExpGroup; const AName: string): TCIExpNode;
begin
  Result := TCIExpNode.Create;
  Result.Kind := AKind;
  Result.Group := AGroup;
  Result.Name := AName;
  Result.SortPos := -1;
  if FChildren = nil then FChildren := TList.Create;
  FChildren.Add(Result);
end;

type
  { one overload of a routine: its declaration (nil: an implementation that nothing declares),
    its implementation (nil: none) and the offset of the first of them - Delphi makes the
    overloads in the order of the text }
  TExpSig = record
    Decl, Impl: TRoutineSym;
    First: Integer;
  end;
  TExpSigs = array of TExpSig;

  { the declarations and implementations of one name }
  TExpNameGroup = class
  public
    Decls, Bodies: TList;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TExpNameGroup.Create;
begin
  inherited Create;
  Decls := TList.Create;
  Bodies := TList.Create;
end;

destructor TExpNameGroup.Destroy;
begin
  Decls.Free;
  Bodies.Free;
  inherited;
end;

{ a type as Delphi's explorer writes it (TUnitManager's ExpectType rebuilds it from its tokens):
  names as written, keywords in lower case, no array bounds and no parameter lists, string[n] as
  ShortString, a function type as procedure, an enumeration or a subrange by its kind. Omit: a
  type Delphi's parser stops at (class of) - what has it is not shown }
function ExpTypeText(U: TUnitInfo; AStart, AEnd: Integer; out Omit: Boolean): string;
var
  L: TPasLexer;

  function IsSym(S: TSymbolId): Boolean;
  begin
    Result := (L.Tok.Kind = tkSymbol) and (L.Tok.Symbol = S);
  end;

  function IsKw(K: TKeyword): Boolean;
  begin
    Result := (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword = K);
  end;

  procedure SkipBalanced(Open, Close: TSymbolId);
  var
    Depth: Integer;
  begin
    Depth := 0;
    repeat
      if IsSym(Open) then Inc(Depth)
      else if IsSym(Close) then Dec(Depth);
      L.Next;
    until (Depth <= 0) or (L.Tok.Kind = tkEOF);
  end;

  function QualIdent: string;
  begin
    Result := L.TokenText;
    L.Next;
    while IsSym(syDot) do
    begin
      L.Next;
      if not (L.Tok.Kind in [tkIdent, tkKeyword]) then Break;
      Result := Result + '.' + L.TokenText;
      L.Next;
    end;
  end;

  function Read: string;
  begin
    Result := '';
    case L.Tok.Kind of
      tkIdent:
        begin
          Result := QualIdent;
          if IsSym(syDotDot) then Result := '<enumeration>';
        end;
      tkNumber, tkString:
        Result := '<subrange>';
      tkSymbol:
        if IsSym(syCaret) then
        begin
          L.Next;
          if L.Tok.Kind in [tkIdent, tkKeyword] then Result := '^' + QualIdent else Result := '^';
        end
        else if IsSym(syLParen) then
          Result := '<enumeration>'
        else
          Result := '<subrange>';
      tkKeyword:
        case L.Tok.Keyword of
          kwArray:
            begin
              L.Next;
              if IsSym(syLBracket) then SkipBalanced(syLBracket, syRBracket);
              if IsKw(kwOf) then
              begin
                L.Next;
                if IsKw(kwConst) then Result := 'array of const' else Result := 'array of ' + Read;
              end
              else
                Result := 'array';
            end;
          kwSet:
            begin
              L.Next;
              if IsKw(kwOf) then L.Next;
              Result := 'set of ' + Read;
            end;
          kwFile:
            begin
              L.Next;
              if IsKw(kwOf) then
              begin
                L.Next;
                Result := 'file of ' + Read;
              end
              else
                Result := 'file';
            end;
          kwString:
            begin
              Result := L.TokenText;
              L.Next;
              if IsSym(syLBracket) then Result := 'ShortString';
            end;
          kwProcedure:
            begin
              Result := 'procedure';
              L.Next;
              if IsSym(syLParen) then SkipBalanced(syLParen, syRParen);
              if IsKw(kwOf) then
              begin
                L.Next;
                if SameText(L.TokenText, 'object') then Result := 'procedure of object';
              end;
            end;
          kwFunction:
            Result := 'procedure';
          kwRecord:
            Result := 'record';
          kwPacked:
            begin
              L.Next;
              if IsKw(kwRecord) then Result := 'packed record' else Result := Read;
            end;
          kwClass:
            Omit := True;
        else
          Result := LowerCase(L.TokenText);
        end;
    end;
  end;

begin
  Result := '';
  Omit := False;
  if (U = nil) or (AEnd <= AStart) then Exit;
  L := TPasLexer.Create(U.Source, AStart, AEnd);
  try
    L.Next;
    Result := Read;
  finally
    L.Free;
  end;
end;

{ a parameter's or a result's type as Delphi's MethodHeader writes it: the last part of a
  qualified name, Longint as Integer, IUnknown as IInterface, other names as written; Arr - the
  parameter is an open array (array of ...) }
function ExpParamType(U: TUnitInfo; AStart, AEnd: Integer; out Arr: Boolean): string;
var
  L: TPasLexer;
begin
  Result := '';
  Arr := False;
  if (U = nil) or (AEnd <= AStart) then Exit;
  L := TPasLexer.Create(U.Source, AStart, AEnd);
  try
    L.Next;
    if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword = kwArray) then
    begin
      Arr := True;
      L.Next;
      if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword = kwOf) then L.Next;
    end;
    if L.Tok.Kind = tkEOF then Exit;
    Result := L.TokenText;
    L.Next;
    while (L.Tok.Kind = tkSymbol) and (L.Tok.Symbol = syDot) do
    begin
      L.Next;
      if not (L.Tok.Kind in [tkIdent, tkKeyword]) then Break;
      Result := L.TokenText;
      L.Next;
    end;
  finally
    L.Free;
  end;
  if SameText(Result, 'Longint') then Result := 'Integer'
  else if SameText(Result, 'IUnknown') then Result := 'IInterface';
end;

{ what Show declaration syntax adds to a routine's name (Delphi's MethodHeader): its parameters -
  the modifier, the names of neighbours with the same modifier and type joined, no default values
  - and a function's result; no keyword, no directives }
function ExpHeader(R: TRoutineSym): string;
var
  I, J, N: Integer;
  Mods, Types, Names: array of string;
  Arrs: array of Boolean;
  P: TSymbol;
  S, Part, T: string;
  Arr: Boolean;
begin
  Result := '';
  if R = nil then Exit;
  EnsureParams(R);
  N := 0;
  if R.Params <> nil then N := R.Params.Count;
  SetLength(Mods, N);
  SetLength(Types, N);
  SetLength(Names, N);
  SetLength(Arrs, N);
  for I := 0 to N - 1 do
  begin
    P := TSymbol(R.Params[I]);
    Names[I] := P.Name;
    Mods[I] := ParamModifier(P);
    Types[I] := ExpParamType(R.UnitInfo, P.TypeStart, P.TypeEnd, Arrs[I]);
  end;
  S := '';
  I := 0;
  while I < N do
  begin
    Part := Names[I];
    J := I + 1;
    while (J < N) and (Mods[J] = Mods[I]) and (Arrs[J] = Arrs[I]) and (Types[J] = Types[I]) do
    begin
      Part := Part + ', ' + Names[J];
      Inc(J);
    end;
    if Mods[I] <> '' then Part := Mods[I] + ' ' + Part;
    if Types[I] <> '' then
      if Arrs[I] then Part := Part + ': array of ' + Types[I] else Part := Part + ': ' + Types[I];
    if S <> '' then S := S + '; ';
    S := S + Part;
    I := J;
  end;
  if S <> '' then Result := '(' + S + ')';
  if sfFunction in R.Flags then
  begin
    T := ExpParamType(R.UnitInfo, R.TypeStart, R.TypeEnd, Arr);
    if T <> '' then Result := Result + ': ' + T;
  end;
end;

{ where Delphi's explorer puts the caret in a routine's body (GetNextLinePos): after its begin
  (or asm) the blanks and one line break skipped - the start of the next line, or the code on
  begin's own line -, after a leading "inherited;" the same after that }
function ExpBodyPos(R: TRoutineSym): Integer;
var
  Src: string;
  P, N, E: Integer;
  L: TPasLexer;

  procedure SkipToNextLine;
  begin
    while (P < N) and (Src[P + 1] in [' ', #9]) do Inc(P);
    if (P < N) and (Src[P + 1] = #13) then Inc(P);
    if (P < N) and (Src[P + 1] = #10) then Inc(P);
  end;

begin
  Src := R.UnitInfo.Source;
  N := Length(Src);
  P := R.BodyStart;
  if R.BodyEnd > R.BodyStart then E := R.BodyEnd else E := -1;
  L := TPasLexer.Create(Src, R.BodyStart, E);
  try
    L.Next;                                   // begin / asm
    if L.Tok.Kind <> tkEOF then P := L.Tok.Start + L.Tok.Len;
    L.Next;
    if (L.Tok.Kind = tkKeyword) and (L.Tok.Keyword = kwInherited) then
    begin
      L.Next;
      if (L.Tok.Kind = tkSymbol) and (L.Tok.Symbol = sySemicolon) then P := L.Tok.Start + L.Tok.Len;
    end;
  finally
    L.Free;
  end;
  SkipToNextLine;
  Result := P;
end;

function BuildExplorer(U: TUnitInfo): TCIExpNode;
var
  Root: TCIExpNode;

  { the caret on the symbol's name, the Source order by it }
  procedure Place(N: TCIExpNode; S: TSymbol);
  begin
    N.Line := S.Line;
    N.Col := S.Col;
    N.FirstLine := S.Line;
    N.LastLine := S.Line;
    N.SortPos := U.OffsetOf(S.Line, S.Col);
  end;

  { what comes before a class's first visibility word is published (Delphi's access 0) }
  function AccessOf(D: TTypeDesc; M: TSymbol): TCIExpAccess;
  var
    Ofs: Integer;
  begin
    if M is TRoutineSym then Ofs := TRoutineSym(M).HeadStart else Ofs := U.OffsetOf(M.Line, M.Col);
    if (D.FirstVisOfs = 0) or (Ofs < D.FirstVisOfs) then
      Result := xaPublished
    else
      case M.Visibility of
        viPrivate: Result := xaPrivate;
        viProtected: Result := xaProtected;
        viPublic: Result := xaPublic;
      else
        Result := xaPublished;
      end;
  end;

  { a property's read or write }
  function HasAccessor(M: TSymbol): Boolean;
  var
    L: TPasLexer;
  begin
    Result := False;
    if M.FullEnd <= M.DeclEnd then Exit;
    L := TPasLexer.Create(U.Source, M.DeclEnd, M.FullEnd);
    try
      L.Next;
      while L.Tok.Kind <> tkEOF do
      begin
        if (L.Tok.Kind = tkIdent) and (L.Tok.Directive in [dvRead, dvWrite]) then
        begin
          Result := True;
          Exit;
        end;
        L.Next;
      end;
    finally
      L.Free;
    end;
  end;

  function IsBody(S: TSymbol): Boolean;
  begin
    Result := (sfImplBody in S.Flags) and not (sfForward in S.Flags) and not (sfExternal in S.Flags);
  end;

  { the group of Name in Groups (made when missing) }
  function NameGroup(Groups: TStringList; const Name: string): TExpNameGroup;
  var
    I: Integer;
  begin
    if not Groups.Find(Name, I) then I := Groups.AddObject(Name, TExpNameGroup.Create);
    Result := TExpNameGroup(Groups.Objects[I]);
  end;

  procedure FreeGroups(Groups: TStringList);
  var
    I: Integer;
  begin
    for I := 0 to Groups.Count - 1 do Groups.Objects[I].Free;
    Groups.Free;
  end;

  { the overloads of a name: an implementation goes with the one declaration there is, whatever
    its parameters (Delphi reuses the signature of a routine without overloads), else with the
    declaration of the same parameters; one left over is an overload of its own. In the order of
    the text }
  function PairUp(G: TExpNameGroup): TExpSigs;
  var
    I, K: Integer;
    B: TRoutineSym;
    Found: Boolean;
    T: TExpSig;
  begin
    SetLength(Result, G.Decls.Count);
    for I := 0 to G.Decls.Count - 1 do
    begin
      Result[I].Decl := TRoutineSym(G.Decls[I]);
      Result[I].Impl := nil;
      Result[I].First := Result[I].Decl.HeadStart;
    end;
    for I := 0 to G.Bodies.Count - 1 do
    begin
      B := TRoutineSym(G.Bodies[I]);
      Found := False;
      if (G.Decls.Count = 1) and (Result[0].Impl = nil) then
      begin
        Result[0].Impl := B;
        Found := True;
      end
      else
        for K := 0 to G.Decls.Count - 1 do
          if (Result[K].Impl = nil) and SameText(RoutineParamsText(Result[K].Decl), RoutineParamsText(B)) then
          begin
            Result[K].Impl := B;
            Found := True;
            Break;
          end;
      if not Found then
      begin
        K := Length(Result);
        SetLength(Result, K + 1);
        Result[K].Decl := nil;
        Result[K].Impl := B;
        Result[K].First := B.HeadStart;
      end;
    end;
    for I := 1 to High(Result) do
    begin
      T := Result[I];
      K := I - 1;
      while (K >= 0) and (Result[K].First > T.First) do
      begin
        Result[K + 1] := Result[K];
        Dec(K);
      end;
      Result[K + 1] := T;
    end;
  end;

  { one overload's kind, text, boldness and place: with a body - its heading at the top, the
    caret in the body; else the caret on its name (the top: its class's line, the view takes it) }
  procedure FillSig(N: TCIExpNode; const Sig: TExpSig; ClassMethod: Boolean);
  var
    R: TRoutineSym;
    P, C: Integer;
  begin
    if Sig.Decl <> nil then R := Sig.Decl else R := Sig.Impl;
    if (sfFunction in R.Flags) and not (sfClassMethod in R.Flags) then N.Kind := xkFunction
    else N.Kind := xkProcedure;
    N.Syntax := ExpHeader(R);
    if ClassMethod then
      N.Incomplete := (Sig.Decl = nil) or ((Sig.Impl = nil) and not (sfAbstract in Sig.Decl.Flags));
    if (Sig.Impl <> nil) and (sfHasBody in Sig.Impl.Flags) then
    begin
      N.TopLine := U.LineOfOffset(Sig.Impl.HeadStart, C);
      P := ExpBodyPos(Sig.Impl);
      N.Line := U.LineOfOffset(P, C);
      N.Col := C;
      N.SortPos := P;
      N.FirstLine := N.TopLine;
      N.LastLine := U.LineOfOffset(Sig.Impl.BodyEnd, C);
      if Sig.Decl <> nil then N.DeclLine := Sig.Decl.Line;
    end
    else
    begin
      N.Line := R.Line;
      N.Col := R.Col;
      N.FirstLine := R.Line;
      N.LastLine := R.Line;
      if ClassMethod then N.SortPos := U.OffsetOf(R.Line, R.Col) else N.SortPos := R.HeadStart;
    end;
  end;

  { a routine's node: one overload - itself; several - its name, a row for each overload below it
    (the last made first: Delphi prepends them) and what the first row has }
  procedure AddRoutine(Parent: TCIExpNode; AGroup: TCIExpGroup; const Name: string; G: TExpNameGroup;
    ClassMethod: Boolean; Desc: TTypeDesc);
  var
    Sigs: TExpSigs;
    N, C: TCIExpNode;
    I: Integer;
  begin
    Sigs := PairUp(G);
    if Length(Sigs) = 0 then Exit;
    N := Parent.Add(xkProcedure, AGroup, Name);
    if Length(Sigs) = 1 then
      FillSig(N, Sigs[0], ClassMethod)
    else
    begin
      for I := High(Sigs) downto 0 do
      begin
        C := N.Add(xkProcedure, xgNone, Name);
        C.Signature := True;
        FillSig(C, Sigs[I], ClassMethod);
      end;
      C := N[0];
      N.Kind := C.Kind;
      N.Incomplete := C.Incomplete;
      N.Line := C.Line;
      N.Col := C.Col;
      N.TopLine := C.TopLine;
      N.SortPos := C.SortPos;
    end;
    if Desc <> nil then
    begin
      I := High(Sigs);
      if Sigs[I].Decl <> nil then N.Access := AccessOf(Desc, Sigs[I].Decl)
      else N.Access := xaPrivate;           // an implementation of the implementation part
    end;
  end;

  { a class or an interface: its line at the top; a class's interfaces of its heritage list, its
    fields (not one of a "class of" type), properties and methods - their implementations
    (Delphi's TFoo.Bar) with them }
  procedure AddStruct(S: TSymbol; IsClass: Boolean);
  var
    D: TTypeDesc;
    N, F: TCIExpNode;
    I: Integer;
    M: TSymbol;
    Groups: TStringList;
    Impls: TList;
    T: string;
    Omit: Boolean;
  begin
    D := S.TypeDesc;
    if IsClass then N := Root.Add(xkClass, xgClasses, S.Name)
    else N := Root.Add(xkInterface, xgInterfaces, S.Name);
    if (D.Ancestors <> nil) and (D.Ancestors.Count > 0) then N.Syntax := '(' + D.Ancestors[0] + ')'
    else if IsClass then N.Syntax := '(TObject)'
    else N.Syntax := '(IUnknown)';
    Place(N, S);
    N.TopLine := S.Line;
    if D.EndOfs > 0 then N.LastLine := U.LineOfOffset(D.EndOfs, I);
    if IsClass and (D.Ancestors <> nil) then
      for I := 1 to D.Ancestors.Count - 1 do N.Add(xkHeritage, xgHeritage, D.Ancestors[I]);
    Groups := TStringList.Create;
    Groups.Sorted := True;                     // found by a binary search: a unit has many routines
    try
      if D.Members <> nil then
        for I := 0 to D.Members.Count - 1 do
        begin
          M := D.Members[I];
          case M.Kind of
            skField:
              if IsClass then
              begin
                T := ExpTypeText(U, M.TypeStart, M.TypeEnd, Omit);
                if Omit then Continue;
                F := N.Add(xkField, xgFields, M.Name);
                if T <> '' then F.Syntax := ': ' + T;
                F.Access := AccessOf(D, M);
                Place(F, M);
              end;
            skProperty:
              begin
                T := ExpTypeText(U, M.TypeStart, M.TypeEnd, Omit);
                F := N.Add(xkProperty, xgProperties, M.Name);
                if T <> '' then F.Syntax := ': ' + T;
                F.Access := AccessOf(D, M);
                F.Incomplete := (T <> '') and not HasAccessor(M);
                Place(F, M);
                F.TopLine := M.Line;
              end;
            skRoutine:
              if M.Name <> '' then NameGroup(Groups, M.Name).Decls.Add(M);
          end;
        end;
      if IsClass then
      begin
        Impls := TList.Create;
        try
          U.GetImpls(Impls, S.Name, '');
          for I := 0 to Impls.Count - 1 do
            if TRoutineSym(Impls[I]).Name <> '' then
              NameGroup(Groups, TRoutineSym(Impls[I]).Name).Bodies.Add(Impls[I]);
        finally
          Impls.Free;
        end;
      end;
      for I := 0 to Groups.Count - 1 do
        AddRoutine(N, xgMethods, Groups[I], TExpNameGroup(Groups.Objects[I]), IsClass, D);
    finally
      FreeGroups(Groups);
    end;
  end;

  procedure AddSymbols(Tab: TSymTable);
  var
    I, C: Integer;
    S: TSymbol;
    D: TTypeDesc;
    N: TCIExpNode;
    T: string;
    Omit: Boolean;
  begin
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      case S.Kind of
        skType:
          begin
            D := S.TypeDesc;
            if (D <> nil) and (D.Kind in [tyClass, tyObject, tyInterface]) then
            begin
              if not D.IsForward then AddStruct(S, D.Kind <> tyInterface);
            end
            else
            begin
              N := Root.Add(xkType, xgTypes, S.Name);
              Place(N, S);
              { a record covers its declaration }
              if (D <> nil) and (D.EndOfs > 0) then N.LastLine := U.LineOfOffset(D.EndOfs, C);
            end;
          end;
        skVar, skConst, skResStr:
          begin
            T := '';
            Omit := False;
            if S.Kind <> skResStr then T := ExpTypeText(U, S.TypeStart, S.TypeEnd, Omit);
            if Omit then Continue;
            N := Root.Add(xkField, xgVariables, S.Name);
            if T <> '' then N.Syntax := ': ' + T;
            Place(N, S);
          end;
      end;
    end;
  end;

  { the unit's routines of both parts: a declaration (in the interface, forward, external) and its
    implementation one node, overloads one node }
  procedure AddRoutines;
  var
    Groups: TStringList;
    I: Integer;

    procedure Take(S: TSymbol);
    var
      G: TExpNameGroup;
    begin
      if (S.Kind <> skRoutine) or (S.Name = '') or (TRoutineSym(S).ClassQual <> '') then Exit;
      G := NameGroup(Groups, S.Name);
      if IsBody(S) then
      begin
        if G.Bodies.IndexOf(S) < 0 then G.Bodies.Add(S);
      end
      else if G.Decls.IndexOf(S) < 0 then
        G.Decls.Add(S);
    end;

  begin
    Groups := TStringList.Create;
    Groups.Sorted := True;                     // found by a binary search: a unit has many routines
    try
      for I := 0 to U.IntfSyms.Count - 1 do Take(U.IntfSyms[I]);
      for I := 0 to U.ImplSyms.Count - 1 do Take(U.ImplSyms[I]);
      for I := 0 to U.ImplRoutines.Count - 1 do Take(TSymbol(U.ImplRoutines[I]));
      for I := 0 to Groups.Count - 1 do
        AddRoutine(Root, xgProcedures, Groups[I], TExpNameGroup(Groups.Objects[I]), False, nil);
    finally
      FreeGroups(Groups);
    end;
  end;

  procedure AddUses(List: TStringList);
  var
    I, L: Integer;
    N: TCIExpNode;
  begin
    for I := 0 to List.Count - 1 do
    begin
      L := Integer(List.Objects[I]);
      N := Root.Add(xkUses, xgUses, List[I]);
      N.Line := L shr 10;
      N.Col := L and 1023;
      N.FirstLine := N.Line;
      N.LastLine := N.Line;
      N.SortPos := U.OffsetOf(N.Line, N.Col);
    end;
  end;

begin
  Root := TCIExpNode.Create;
  try
    Root.Kind := xkUnit;
    Root.Name := U.Name;
    Root.SortPos := -1;
    AddSymbols(U.IntfSyms);
    AddSymbols(U.ImplSyms);
    AddRoutines;
    AddUses(U.IntfUses);
    AddUses(U.ImplUses);
  except
    Root.Free;
    raise;
  end;
  Result := Root;
end;

{ ---------------------------------------------------------------------------- }
{ navigation bar }

function CompareHeadStart(A, B: Pointer): Integer;
begin
  Result := TRoutineSym(A).HeadStart - TRoutineSym(B).HeadStart;
end;

function BuildNavigation(Eng: TCIEngine; U: TUnitInfo): TCINavigation;
var
  Nav: TCINavigation;
  Impls: TStringList;          // 'CLASS.NAME' of every method's implementation, sorted (Objects: it; nil once taken)
  Cands, Spots: TList;
  Pass, I, J, K: Integer;
  Tab: TSymTable;
  S, M: TSymbol;
  R, Impl: TRoutineSym;
  C: TCINavItem;
  Key: string;

  procedure Lines(var First, Last: Integer; A, B: Integer);
  var
    Col: Integer;
  begin
    First := U.LineOfOffset(A, Col);
    if B < A then B := A;
    Last := U.LineOfOffset(B, Col);
  end;

  { a routine: Decl its declaration (nil: none), Impl its implementation (nil: none) }
  procedure AddRoutine(Owner: TCINavItem; Decl: TSymbol; Impl: TRoutineSym);
  var
    It: TCINavItem;
    Src: TSymbol;
  begin
    It := TCINavItem.Create;
    Nav.Routines.Add(It);
    It.Owner := Owner;
    if (Decl <> nil) and ((Impl = nil) or (Eng.ParamsText(Impl) = '') or (Owner <> nil)) then Src := Decl
    else Src := Impl;
    It.Name := Src.Name;
    It.Caption := MemberCaption(Eng, Src);
    It.Kind := SymKind(Src);
    if Decl is TRoutineSym then Lines(It.DeclFirst, It.DeclLast, TRoutineSym(Decl).HeadStart, Decl.FullEnd);
    if Impl <> nil then
    begin
      It.Line := Impl.Line;
      It.Col := Impl.Col;
      if Impl.BodyEnd > Impl.FullEnd then Lines(It.FirstLine, It.LastLine, Impl.HeadStart, Impl.BodyEnd)
      else Lines(It.FirstLine, It.LastLine, Impl.HeadStart, Impl.FullEnd);
    end
    else
    begin
      It.Line := Decl.Line;
      It.Col := Decl.Col;
    end;
  end;

  function FindClass(const Name: string): TCINavItem;
  var
    N: Integer;
  begin
    for N := 0 to Nav.Classes.Count - 1 do
    begin
      Result := TCINavItem(Nav.Classes[N]);
      if SameText(Result.Name, Name) then Exit;
    end;
    Result := nil;
  end;

  { the implementations of AKey not taken yet, in source order (Spots: their places in Impls, in
    the order of Impls) }
  procedure Candidates(const AKey: string);
  var
    N: Integer;
  begin
    Cands.Clear;
    Spots.Clear;
    if not Impls.Find(AKey, N) then Exit;
    while (N > 0) and (Impls[N - 1] = AKey) do Dec(N);
    while (N < Impls.Count) and (Impls[N] = AKey) do
    begin
      if Impls.Objects[N] <> nil then
      begin
        Cands.Add(Impls.Objects[N]);
        Spots.Add(Pointer(N));
      end;
      Inc(N);
    end;
    Cands.Sort(CompareHeadStart);
  end;

  { a plain routine's declaration in the interface: the one with Impl's parameters, else the first }
  function IntfDecl(Impl: TRoutineSym): TSymbol;
  var
    D: TSymbol;
    Decls: TList;
  begin
    Decls := TList.Create;
    try
      D := U.IntfSyms.Find(Impl.Name);
      while D <> nil do
      begin
        if D.Kind = skRoutine then Decls.Add(D);
        D := U.IntfSyms.FindNext(D);
      end;
      Result := TRoutineSym(PairRoutine(Impl, Decls));
    finally
      Decls.Free;
    end;
  end;

begin
  Nav := TCINavigation.Create;
  Impls := nil;
  Cands := TList.Create;
  Spots := TList.Create;
  try
    try
      Impls := MethodImplIndex(U);
      { the classes, objects and interfaces with their methods, each paired with its implementation }
      for Pass := 0 to 1 do
      begin
        if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
        for I := 0 to Tab.Count - 1 do
        begin
          S := Tab[I];
          if not IsStructDecl(S, [tyClass, tyObject, tyInterface]) then Continue;
          C := TCINavItem.Create;
          Nav.Classes.Add(C);
          C.Name := S.Name;
          C.Caption := S.Name;
          C.Kind := SymKind(S);
          C.Line := S.Line;
          C.Col := S.Col;
          Lines(C.FirstLine, C.LastLine, S.DeclStart, S.TypeDesc.EndOfs);
          for J := 0 to S.TypeDesc.Members.Count - 1 do
          begin
            M := S.TypeDesc.Members[J];
            if (M.Kind <> skRoutine) or not (M is TRoutineSym) then Continue;
            Candidates(UpperCase(S.Name + '.' + M.Name));
            Impl := TRoutineSym(PairRoutine(M, Cands));
            if Impl <> nil then
              for K := 0 to Spots.Count - 1 do
                if Impls.Objects[Integer(Spots[K])] = Impl then Impls.Objects[Integer(Spots[K])] := nil;
            AddRoutine(C, M, Impl);
          end;
        end;
      end;
      { implementations no declaration took (being typed, a class of another unit's name) }
      for I := 0 to Impls.Count - 1 do
      begin
        if Impls.Objects[I] = nil then Continue;
        R := TRoutineSym(Impls.Objects[I]);
        Key := R.ClassQual;
        if Pos('.', Key) > 0 then Continue;
        C := FindClass(Key);
        if C = nil then
        begin
          C := TCINavItem.Create;
          Nav.Classes.Add(C);
          C.Name := Key;
          C.Caption := Key;
          C.Kind := ckClass;
          C.Line := R.Line;
          C.Col := R.Col;
        end;
        AddRoutine(C, nil, R);
      end;
      { the plain routines of the unit (not those inside routines) }
      for I := 0 to U.ImplRoutines.Count - 1 do
      begin
        R := TRoutineSym(U.ImplRoutines[I]);
        if (R.ClassQual = '') and (R.Name <> '') then AddRoutine(nil, IntfDecl(R), R);
      end;
    except
      Nav.Free;
      raise;
    end;
  finally
    Spots.Free;
    Cands.Free;
    Impls.Free;
  end;
  Result := Nav;
end;

{ ---------------------------------------------------------------------------- }
{ browser }

constructor TCIBrowseSym.Create;
begin
  inherited Create;
  Members := TList.Create;
  Descendants := TList.Create;
end;

destructor TCIBrowseSym.Destroy;
var
  I: Integer;
begin
  for I := 0 to Members.Count - 1 do TObject(Members[I]).Free;
  Members.Free;
  Descendants.Free;
  inherited Destroy;
end;

function TCIBrowseSym.QualifiedName: string;
begin
  if Kind = ckUnit then Result := Name
  else if Owner <> nil then Result := Owner.QualifiedName + '.' + Name
  else if UnitInfo <> nil then Result := UnitInfo.Name + '.' + Name
  else Result := Name;
end;

constructor TCIBrowseUnit.Create;
begin
  inherited Create;
  UsesList := TStringList.Create;
  Syms := TList.Create;
  Sym := TCIBrowseSym.Create;
  Sym.Kind := ckUnit;
  Sym.UnitInfo := Self;
  Sym.Line := 1;
  Sym.Col := 1;
end;

destructor TCIBrowseUnit.Destroy;
var
  I: Integer;
begin
  for I := 0 to Syms.Count - 1 do TObject(Syms[I]).Free;
  Syms.Free;
  Sym.Free;
  UsesList.Free;
  inherited Destroy;
end;

constructor TCIBrowseModel.Create;
begin
  inherited Create;
  Units := TList.Create;
  ClassList := TList.Create;
end;

destructor TCIBrowseModel.Destroy;
var
  I: Integer;
begin
  for I := 0 to Units.Count - 1 do TObject(Units[I]).Free;
  Units.Free;
  ClassList.Free;
  inherited Destroy;
end;

type
  { makes a TCIBrowseModel of the parser's units (only while the engine's lock is held) }
  TBrowseBuilder = class
  private
    Eng: TCIEngine;
    Model: TCIBrowseModel;
    FDone: TStringList;           // file names of the units added (Objects: TCIBrowseUnit)
    FClasses: TStringList;        // a class's TTypeDesc (hex) -> its TCIBrowseSym
    FQueue: TList;                // TTypeDesc of the classes whose ancestor is to be linked
    function SymOfDesc(D: TTypeDesc): TCIBrowseSym;
    function AddSym(BU: TCIBrowseUnit; S: TSymbol; Owner: TCIBrowseSym; InImpl: Boolean): TCIBrowseSym;
  public
    constructor Create(AEng: TCIEngine; AModel: TCIBrowseModel);
    destructor Destroy; override;
    function AddUnit(U: TUnitInfo; InProject, Shown: Boolean): TCIBrowseUnit;
    procedure LinkAncestors;
  end;

constructor TBrowseBuilder.Create(AEng: TCIEngine; AModel: TCIBrowseModel);
begin
  inherited Create;
  Eng := AEng;
  Model := AModel;
  FDone := TStringList.Create;
  FDone.Sorted := True;
  FClasses := TStringList.Create;
  FClasses.Sorted := True;
  FClasses.Duplicates := dupIgnore;
  FQueue := TList.Create;
end;

destructor TBrowseBuilder.Destroy;
begin
  FQueue.Free;
  FClasses.Free;
  FDone.Free;
  inherited Destroy;
end;

function TBrowseBuilder.SymOfDesc(D: TTypeDesc): TCIBrowseSym;
var
  I: Integer;
begin
  Result := nil;
  if FClasses.Find(IntToHex(Integer(D), 8), I) then Result := TCIBrowseSym(FClasses.Objects[I]);
end;

function TBrowseBuilder.AddSym(BU: TCIBrowseUnit; S: TSymbol; Owner: TCIBrowseSym; InImpl: Boolean): TCIBrowseSym;
var
  I: Integer;
  M: TSymbol;
  D: TTypeDesc;
begin
  Result := TCIBrowseSym.Create;
  Result.Name := S.Name;
  Result.Kind := SymKind(S);
  Result.Visibility := TCIVisibility(Ord(S.Visibility));
  Result.Caption := MemberCaption(Eng, S);
  Result.Decl := Eng.DeclText(S);
  Result.UnitInfo := BU;
  Result.Line := S.Line;
  Result.Col := S.Col;
  Result.Owner := Owner;
  Result.InImpl := InImpl;
  D := S.TypeDesc;
  if (S.Kind = skType) and (D <> nil) and (D.Kind in StructKinds) then
  begin
    if D.Members <> nil then
      for I := 0 to D.Members.Count - 1 do
      begin
        M := D.Members[I];
        if M.Name <> '' then Result.Members.Add(AddSym(BU, M, Result, InImpl));
      end;
    if D.Kind in [tyClass, tyInterface] then
    begin
      Model.ClassList.Add(Result);
      FClasses.AddObject(IntToHex(Integer(D), 8), Result);
      if BU.Shown then FQueue.Add(D);
    end;
  end;
end;

{ a unit and what it declares: types (no forward declarations), constants, variables, routines
  (an implementation of a routine of the interface or of a method is not one of its own) }
function TBrowseBuilder.AddUnit(U: TUnitInfo; InProject, Shown: Boolean): TCIBrowseUnit;
var
  Pass, I: Integer;
  Tab: TSymTable;
  S: TSymbol;
begin
  if FDone.Find(U.FileName, I) then
  begin
    Result := TCIBrowseUnit(FDone.Objects[I]);
    Exit;
  end;
  Result := TCIBrowseUnit.Create;
  Result.Name := U.Name;
  Result.FileName := U.FileName;
  Result.InProject := InProject;
  Result.Shown := Shown;
  Result.Sym.Name := U.Name;
  Result.Sym.Caption := U.Name;
  if U.IsProgram then Result.Sym.Decl := 'program ' + U.Name else Result.Sym.Decl := 'unit ' + U.Name;
  for I := 0 to U.IntfUses.Count - 1 do Result.UsesList.Add(U.IntfUses[I]);
  for I := 0 to U.ImplUses.Count - 1 do Result.UsesList.Add(U.ImplUses[I]);
  Model.Units.Add(Result);
  FDone.AddObject(U.FileName, Result);
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if S.Name = '' then Continue;
      case S.Kind of
        skType:
          if (S.TypeDesc <> nil) and S.TypeDesc.IsForward then Continue;
        skConst, skResStr, skVar: ;
        skRoutine:
          if (sfForward in S.Flags) or ((S is TRoutineSym) and (TRoutineSym(S).ClassQual <> '')) or
            ((Pass = 1) and (U.IntfSyms.Find(S.Name) <> nil)) then Continue;
      else
        Continue;
      end;
      Result.Syms.Add(AddSym(Result, S, nil, (Pass = 1) and not U.IsProgram));
    end;
  end;
end;

{ the classes of the units browsed and, one after the other, their ancestors - whose units come
  along when they are not browsed }
procedure TBrowseBuilder.LinkAncestors;
var
  I: Integer;
  D, AD: TTypeDesc;
  C, A: TCIBrowseSym;
begin
  I := 0;
  while I < FQueue.Count do
  begin
    D := TTypeDesc(FQueue[I]);
    Inc(I);
    C := SymOfDesc(D);
    if (C = nil) or C.AncestorDone then Continue;
    C.AncestorDone := True;
    AD := Eng.AncestorOf(D);
    if (AD = nil) or (AD = D) then Continue;
    A := SymOfDesc(AD);
    if (A = nil) and (AD.UnitInfo <> nil) and (AD.UnitInfo <> Eng.Builtin) and (AD.UnitInfo.FileName <> '') then
    begin
      AddUnit(AD.UnitInfo, False, False);
      A := SymOfDesc(AD);
    end;
    if A = nil then Continue;
    C.Ancestor := A;
    A.Descendants.Add(C);
    FQueue.Add(AD);
  end;
end;

{ ---------------------------------------------------------------------------- }
{ TCodeInsight }

constructor TCodeInsight.Create;
begin
  inherited Create;
  InitializeCriticalSection(FLock);
  FEng := TCIEngine.Create;
  FEng.OnGetSource := EngGetSource;
  FEng.SearchPath.OnChange := PathChange;
  FEng.UnitFiles.OnChange := PathChange;
  FEng.Defines.OnChange := DefinesChange;
end;

destructor TCodeInsight.Destroy;
begin
  FEng.Free;
  DeleteCriticalSection(FLock);
  inherited Destroy;
end;

function TCodeInsight.GetSearchPath: TStrings;
begin
  Result := FEng.SearchPath;
end;

function TCodeInsight.GetDefines: TStrings;
begin
  Result := FEng.Defines;
end;

function TCodeInsight.GetUnitFiles: TStrings;
begin
  Result := FEng.UnitFiles;
end;

function TCodeInsight.GetReadFileFunc: TCIReadFileFunc;
begin
  Result := FEng.ReadFileFunc;
end;

procedure TCodeInsight.SetReadFileFunc(Value: TCIReadFileFunc);
begin
  FEng.ReadFileFunc := Value;
end;

function TCodeInsight.GetFileAgeFunc: TCIFileAgeFunc;
begin
  Result := FEng.FileAgeFunc;
end;

procedure TCodeInsight.SetFileAgeFunc(Value: TCIFileAgeFunc);
begin
  FEng.FileAgeFunc := Value;
end;

function TCodeInsight.GetOnGetPendingUses: TCIGetUsesEvent;
begin
  Result := FEng.OnGetPendingUses;
end;

procedure TCodeInsight.SetOnGetPendingUses(Value: TCIGetUsesEvent);
begin
  FEng.OnGetPendingUses := Value;
end;

procedure TCodeInsight.PathChange(Sender: TObject);
begin
  EnterCriticalSection(FLock);
  try
    FEng.PathChanged;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCodeInsight.DefinesChange(Sender: TObject);
begin
  EnterCriticalSection(FLock);
  try
    FEng.DefinesChanged;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.EngGetSource(const FileName: string; var Source: string): Boolean;
begin
  if Assigned(FOnGetSource) then
    Result := FOnGetSource(FileName, Source)
  else
    Result := False;
end;

procedure TCodeInsight.InvalidateFile(const FileName: string);
begin
  EnterCriticalSection(FLock);
  try
    try
      FEng.InvalidateFile(FileName);
    except
      NoteExc;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCodeInsight.ClearCache;
begin
  EnterCriticalSection(FLock);
  try
    try
      FEng.ClearCache;
    except
      NoteExc;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.FindUnitFile(const UnitName, FromFile: string): string;
begin
  Result := '';
  EnterCriticalSection(FLock);
  try
    try
      if FromFile = '' then
        Result := FEng.FindUnitFile(UnitName, '')
      else
        Result := FEng.FindUnitFile(UnitName, FEng.NormFileName(FromFile));
    except
      NoteExc;
      Result := '';
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ a context for the caret at Pos of a file's text, after the engine's BeginCall (the caller holds
  the lock); nil in a comment or a string, where code insight offers nothing }
function NewContext(Eng: TCIEngine; const FileName, Source: string; Pos: Integer): TCIContext;
begin
  Eng.BeginCall;
  Result := TCIContext.Create(Eng, FileName, Source, Pos);
  if Result.InComment or Result.InString then FreeAndNil(Result);
end;

function TCodeInsight.GetCompletions(const FileName, Source: string; Pos: Integer;
  List: TCIItemList; out PrefixStart: Integer): Boolean;
var
  Ctx: TCIContext;
begin
  Result := False;
  PrefixStart := Pos;
  if List = nil then Exit;
  EnterCriticalSection(FLock);
  try
    try
      List.Clear;
      Ctx := NewContext(FEng, FileName, Source, Pos);
      if Ctx <> nil then
      try
        Result := Ctx.Complete(List, PrefixStart);
      finally
        Ctx.Free;
      end;
    except
      NoteExc;
      Result := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.GetParamHints(const FileName, Source: string; Pos: Integer;
  out Hints: TCIParamHintArray; out ActiveParam: Integer): Boolean;
var
  Ctx: TCIContext;
begin
  Result := False;
  Hints := nil;
  ActiveParam := 0;
  EnterCriticalSection(FLock);
  try
    try
      Ctx := NewContext(FEng, FileName, Source, Pos);
      if Ctx <> nil then
      try
        Result := Ctx.ParamHints(Hints, ActiveParam);
      finally
        Ctx.Free;
      end;
    except
      NoteExc;
      Result := False;
      Hints := nil;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function IdentEndAt(const Source: string; Pos: Integer): Integer;
begin
  // Pos is a 0-based caret offset; extend to the end of the identifier under / before it
  if Pos < 0 then Pos := 0;
  if Pos > Length(Source) then Pos := Length(Source);
  Result := Pos;
  while (Result < Length(Source)) and IdentTab[Source[Result + 1]] do Inc(Result);
end;

function TCodeInsight.FindDeclaration(const FileName, Source: string; Pos: Integer;
  out Item: TCIItem): Boolean;
var
  Ctx: TCIContext;
begin
  Result := False;
  Finalize(Item);
  FillChar(Item, SizeOf(Item), 0);     // empty texts, ckUnknown, cvNone, no place
  EnterCriticalSection(FLock);
  try
    try
      Ctx := NewContext(FEng, FileName, Source, IdentEndAt(Source, Pos));
      if Ctx <> nil then
      try
        Result := Ctx.FindDecl(Item);
      finally
        Ctx.Free;
      end;
    except
      NoteExc;
      Result := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.GetHint(const FileName, Source: string; Pos: Integer;
  out HintText: string): Boolean;
var
  Item: TCIItem;
  Loc: string;
begin
  HintText := '';
  Result := FindDeclaration(FileName, Source, Pos, Item);
  if not Result then Exit;
  HintText := Item.Decl;
  if HintText = '' then HintText := Item.Name;
  Loc := '';
  if (Item.Scope <> '') and (Item.Kind <> ckUnit) then Loc := Item.Scope;
  if Item.FileName <> '' then
  begin
    if Loc <> '' then Loc := Loc + ' - ';
    Loc := Loc + ExtractFileName(Item.FileName);
    if Item.Line > 0 then Loc := Loc + ' (' + IntToStr(Item.Line) + ')';
  end;
  if Loc <> '' then HintText := HintText + #13#10 + Loc;
end;

function TCodeInsight.GetStructure(const FileName, Source: string): TCIStructNode;
var
  U: TUnitInfo;
begin
  Result := nil;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      U := FEng.LoadCurrent(FileName, Source);
      Result := BuildStructure(FEng, U);
    except
      NoteExc;
      FreeAndNil(Result);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Result = nil then
  begin
    Result := TCIStructNode.Create;
    Result.Caption := ChangeFileExt(ExtractFileName(FileName), '');
    Result.Kind := ckUnit;
  end;
end;

function TCodeInsight.ExplorerNew(const FileName, Source, ClassName: string; Access: TCIExpAccess;
  InUses: Boolean; const Text: string; out NewSource, Error: string): Boolean;
var
  U: TUnitInfo;
begin
  NewSource := Source;
  Error := '';
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      U := FEng.LoadCurrent(FileName, Source);
      Result := SdExplorerEdit.ExplorerNew(U, ClassName, Ord(Access), InUses, Text, NewSource, Error);
    except
      on E: Exception do
      begin
        NoteExc;
        Error := E.Message;
        Result := False;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.ExplorerRename(const FileName, Source: string; Kind: TExpRenameKind;
  const ClassName, OldName, NewName: string; out NewSource, Error: string): Boolean;
var
  U: TUnitInfo;
begin
  NewSource := Source;
  Error := '';
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      U := FEng.LoadCurrent(FileName, Source);
      Result := SdExplorerEdit.ExplorerRename(U, Kind, ClassName, OldName, NewName, NewSource, Error);
    except
      on E: Exception do
      begin
        NoteExc;
        Error := E.Message;
        Result := False;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.GetExplorer(const FileName, Source: string): TCIExpNode;
var
  U: TUnitInfo;
begin
  Result := nil;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      U := FEng.LoadCurrent(FileName, Source);
      Result := BuildExplorer(U);
    except
      NoteExc;
      FreeAndNil(Result);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.GetNavigation(const FileName, Source: string): TCINavigation;
var
  U: TUnitInfo;
begin
  Result := nil;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      U := FEng.LoadCurrent(FileName, Source);
      Result := BuildNavigation(FEng, U);
    except
      NoteExc;                  // BuildNavigation freed what it made: Result is still nil
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Result = nil then Result := TCINavigation.Create;
end;

{ the editor's text of a file, else the file's }
function TCodeInsight.SourceFor(const FileName: string; out Source: string): Boolean;
begin
  Source := '';
  Result := Assigned(FOnGetSource) and FOnGetSource(FileName, Source);
  if not Result then Result := FEng.ReadSource(FileName, Source);
end;

function TCodeInsight.Browse(Files: TStrings; AllUnits: Boolean): TCIBrowseModel;
var
  B: TBrowseBuilder;
  Loaded: TList;
  I, K: Integer;
  S: string;
  U: TUnitInfo;

  { a unit used directly or not, once (its marker: this call's Gen) }
  procedure Take(UU: TUnitInfo);
  begin
    if (UU = nil) or (UU = FEng.Builtin) or (UU.FileName = '') or (UU.MarkGen = FEng.Gen) then Exit;
    UU.MarkGen := FEng.Gen;
    Loaded.Add(UU);
    B.AddUnit(UU, False, True);
  end;

begin
  Result := TCIBrowseModel.Create;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      B := TBrowseBuilder.Create(FEng, Result);
      Loaded := TList.Create;
      try
        { the project's units whole (their implementation too), as the editor has them; from
          here on the engine parses none of them again in this call }
        for I := 0 to Files.Count - 1 do
          if SourceFor(Files[I], S) then
          begin
            U := FEng.LoadCurrent(Files[I], S);
            if U.MarkGen <> FEng.Gen then
            begin
              U.MarkGen := FEng.Gen;
              Loaded.Add(U);
            end;
          end;
        for I := 0 to Loaded.Count - 1 do B.AddUnit(TUnitInfo(Loaded[I]), True, True);
        if AllUnits then
        begin
          K := 0;
          while K < Loaded.Count do
          begin
            U := TUnitInfo(Loaded[K]);
            Inc(K);
            FEng.ResolveUses(U);
            for I := 0 to High(U.IntfUnits) do Take(U.IntfUnits[I]);
            for I := 0 to High(U.ImplUnits) do Take(U.ImplUnits[I]);
          end;
          Take(FEng.SystemUnit);
        end;
        B.LinkAncestors;
      finally
        Loaded.Free;
        B.Free;
      end;
    except
      NoteExc;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ the text of the line around offset Ofs (0-based) }
function LineAround(const S: string; Ofs: Integer): string;
var
  A: Integer;
begin
  A := LineStartOf(S, Ofs);
  Result := Trim(Copy(S, A + 1, LineEndOf(S, Ofs) - A));
end;

{ Ofs is where one of Targets (symbols of the parser's data) is declared in UU }
function IsDeclOf(Targets: TList; UU: TUnitInfo; Ofs: Integer): Boolean;
var
  K: Integer;
begin
  Result := True;
  for K := 0 to Targets.Count - 1 do
    if (TSymbol(Targets[K]).UnitInfo = UU) and (TSymbol(Targets[K]).DeclStart = Ofs) then Exit;
  Result := False;
end;

{ the identifiers of Src (the text of UF) that name one of Targets - or the unit TargetUnit -:
  their tokens' indexes in Hits. A declaration is found by its place, every other name as code
  insight resolves it. The tokens are the result (the caller frees them). }
function NamePlaces(Eng: TCIEngine; const FileName, Src: string; UF, TargetUnit: TUnitInfo;
  Targets: TList; const UName: string; Hits: TList): TRawToks;
var
  Ctx: TCIContext;
  R: TResolved;
  Hit, Heading: Boolean;
  T: PToken;
  K, Depth: Integer;
begin
  Result := TRawToks.Create(Src, False);
  { one context for the file's places: each routine lexed once for all of its places }
  Ctx := nil;
  try
    try
      { a parameter named in a routine's heading (in its brackets, before a colon or a comma)
        declares a name of its own: DoIt(Count: Integer) in a class does not name the class's
        property Count, although the class's scope finds it there }
      Heading := False;
      Depth := 0;
      for K := 0 to Result.N - 1 do
      begin
        T := @Result.T[K];
        case T.Kind of
          tkKeyword:
            if T.Keyword in [kwProcedure, kwFunction, kwConstructor, kwDestructor, kwProperty] then
            begin
              Heading := True;
              Depth := 0;
            end;
          tkSymbol:
            if Heading and (T.Symbol in [syLParen, syLBracket]) then Inc(Depth)
            else if (Depth > 0) and (T.Symbol in [syRParen, syRBracket]) then Dec(Depth)
            else if (Depth = 0) and (T.Symbol = sySemicolon) then Heading := False;
          tkIdent:
            if SameTextP(T.Ptr, T.PLen, UName) and not (Heading and (Depth > 0) and
              (Result.IsSy(K + 1, syColon) or Result.IsSy(K + 1, syComma))) then
            begin
              Hit := (TargetUnit = nil) and IsDeclOf(Targets, UF, T.Start);
              if not Hit then
              begin
                if Ctx = nil then Ctx := TCIContext.CreateShared(Eng, FileName, Src);
                Hit := Ctx.ResolveAt(T.Start + T.Len, R) and
                  (((TargetUnit <> nil) and (R.Kind = rkUnit) and (R.UnitInfo = TargetUnit)) or
                   ((R.Sym <> nil) and (Targets.IndexOf(R.Sym) >= 0)));
              end;
              if Hit then Hits.Add(Pointer(K));
            end;
        end;
      end;
    finally
      Ctx.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TCodeInsight.SymbolOccurrences(const FileName, Source: string; Pos: Integer;
  Places, Decls: TList): Boolean;
var
  Ctx: TCIContext;
  R: TResolved;
  U, TargetUnit: TUnitInfo;
  Targets, Hits: TList;
  S: TSymbol;
  RT: TRawToks;
  K, A, E: Integer;
  Qual: string;
begin
  Result := False;
  Places.Clear;
  Decls.Clear;
  { the identifier at Pos (in it, or at its end) }
  E := IdentEndAt(Source, Pos);
  A := Pos;
  if A > E then A := E;
  while (A > 0) and IdentTab[Source[A]] do Dec(A);
  if (A >= E) or (Source[A + 1] in ['0'..'9']) then Exit;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      Targets := TList.Create;
      Hits := TList.Create;
      try
        Ctx := TCIContext.Create(FEng, FileName, Source, E);
        try
          if Ctx.InComment or Ctx.InString or not Ctx.ResolveHere(R) then Exit;
        finally
          Ctx.Free;
        end;
        TargetUnit := nil;
        if R.Kind = rkUnit then
          TargetUnit := R.UnitInfo
        else if R.Sym <> nil then
        begin
          S := R.Sym;
          Targets.Add(S);
          { a routine: its implementations name it as well }
          if (S.Kind = skRoutine) and (S.UnitInfo <> nil) then
          begin
            Qual := '';
            if (S.Owner is TTypeDesc) and (TTypeDesc(S.Owner).Sym <> nil) then Qual := TTypeDesc(S.Owner).Sym.Name;
            S.UnitInfo.GetImpls(Targets, Qual, S.Name);
          end;
        end;
        if (TargetUnit = nil) and (Targets.Count = 0) then Exit;
        U := FEng.LoadCurrent(FileName, Source);
        RT := NamePlaces(FEng, FileName, Source, U, TargetUnit, Targets, UpperCase(Copy(Source, A + 1, E - A)), Hits);
        try
          for K := 0 to Hits.Count - 1 do
          begin
            A := RT.T[Integer(Hits[K])].Start;
            Places.Add(Pointer(A));
            if (TargetUnit = nil) and IsDeclOf(Targets, U, A) then Decls.Add(Pointer(A));
          end;
        finally
          RT.Free;
        end;
        Result := Places.Count > 0;
      finally
        Hits.Free;
        Targets.Free;
      end;
    except
      NoteExc;
      Result := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.NameKinds(const FileName, Source: string; const Ends: array of Integer;
  var Kinds: array of TCIKind): Boolean;
var
  Ctx: TCIContext;
  R: TResolved;
  I, Last: Integer;
  T: PToken;
begin
  for I := 0 to High(Kinds) do Kinds[I] := ckUnknown;
  Last := High(Ends);
  if Last > High(Kinds) then Last := High(Kinds);
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      { one context for all of them: each routine's tokens lexed once for all of its names }
      Ctx := TCIContext.CreateShared(FEng, FileName, Source);
      try
        for I := 0 to Last do
        begin
          if not Ctx.ResolveAt(Ends[I], R) then R := NoRes;
          if Ctx.DeclaresParam then
            Kinds[I] := ckParam
          else if R.Kind = rkUnit then
            Kinds[I] := ckUnit
          else if R.Sym <> nil then
            Kinds[I] := SymKind(R.Sym)
          else if R.Kind = rkValue then
          begin
            { Self: the method's hidden parameter; Result: the function's own variable, as an
              exception handler's (on E: T do) is the handler's }
            T := @Ctx.Toks[Ctx.TokCount - 1];
            if SameTextP(T.Ptr, T.PLen, 'SELF') then Kinds[I] := ckParam
            else Kinds[I] := ckLocalVar;
          end;
        end;
      finally
        Ctx.Free;
      end;
      Result := True;
    except
      NoteExc;
      Result := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Error Insight }

const
  { Delphi 7's compiler's messages }
  SUndeclared = 'Undeclared identifier: ''%s''';
  SUnsatisfied = 'Unsatisfied forward or external declaration: ''%s''';
  SDiffers = 'Declaration of ''%s'' differs from previous declaration';

type
  { the errors Diagnose gathers, for the text of U }
  TCIErrorList = class
  public
    U: TUnitInfo;
    Errors: TCIErrors;
    Count: Integer;
    procedure Add(AStart, ALen, ALine, ACol: Integer; const AMsg: string);
    { ... its line and column from the text }
    procedure AddAt(AStart, ALen: Integer; const AMsg: string);
    procedure Sort;
  end;

procedure TCIErrorList.Add(AStart, ALen, ALine, ACol: Integer; const AMsg: string);
begin
  if Count >= MaxErrors then Exit;
  if Count = Length(Errors) then SetLength(Errors, Count * 2 + 16);
  Errors[Count].Start := AStart;
  Errors[Count].Len := ALen;
  Errors[Count].Line := ALine;
  Errors[Count].Col := ACol;
  Errors[Count].Msg := AMsg;
  Inc(Count);
end;

procedure TCIErrorList.AddAt(AStart, ALen: Integer; const AMsg: string);
var
  Line, Col: Integer;
begin
  Line := U.LineOfOffset(AStart, Col);
  Add(AStart, ALen, Line, Col, AMsg);
end;

{ in the text's order (insertion: the lists come mostly in order already) }
procedure TCIErrorList.Sort;
var
  I, J: Integer;
  E: TCIError;
begin
  for I := 1 to Count - 1 do
    if Errors[I].Start < Errors[I - 1].Start then
    begin
      E := Errors[I];
      J := I;
      while (J > 0) and (Errors[J - 1].Start > E.Start) do
      begin
        Errors[J] := Errors[J - 1];
        Dec(J);
      end;
      Errors[J] := E;
    end;
end;

{ the routine kinds of a heading (procedure, function, constructor, destructor) }
function SameRoutineKind(A, B: TSymbol): Boolean;
const
  KindFlags = [sfFunction, sfConstructor, sfDestructor];
begin
  Result := A.Flags * KindFlags = B.Flags * KindFlags;
end;

{ Impl's heading differs from its declaration Decl as Delphi 7's compiler sees it: another kind
  of routine, or - Impl lists its parameters - another number of them, another name or another
  kind (var, const, out) of one. Their types are not compared: the compiler compares types, not
  their names (Integer and Longint are the same) }
function HeadingDiffers(Decl, Impl: TRoutineSym): Boolean;
const
  ParamFlags = [sfVarParam, sfConstParam, sfOutParam];
var
  I: Integer;
  A, B: TSymbol;
begin
  Result := not SameRoutineKind(Decl, Impl);
  if Result or (Impl.ParamsStart <= 0) then Exit;
  EnsureParams(Decl);
  EnsureParams(Impl);
  if (Decl.Params = nil) or (Impl.Params = nil) then Exit;
  Result := Decl.Params.Count <> Impl.Params.Count;
  I := 0;
  while not Result and (I < Decl.Params.Count) do
  begin
    A := TSymbol(Decl.Params[I]);
    B := TSymbol(Impl.Params[I]);
    Result := not SameText(A.Name, B.Name) or (A.Flags * ParamFlags <> B.Flags * ParamFlags);
    Inc(I);
  end;
end;

{ the routines of Tab named Name that have all of the flags Need and none of Skip, added to List }
procedure AddRoutines(Tab: TSymTable; const Name: string; Need, Skip: TSymFlags; List: TList);
var
  M: TSymbol;
begin
  M := Tab.Find(Name);
  while M <> nil do
  begin
    if (M.Kind = skRoutine) and (M is TRoutineSym) and (M.Flags * Need = Need) and (M.Flags * Skip = []) then
      List.Add(M);
    M := Tab.FindNext(M);
  end;
end;

{ Declarations vs. implementations in a text without syntax errors (Delphi 7's compiler's errors):
  the methods of the unit's classes, its interface's routines and its routines declared forward
  without an implementation; methods implemented that their class does not declare; and
  implementations whose heading differs from the declaration (one declaration of the name: an
  overload's implementation is the one with its parameters) }
procedure CheckBodies(U: TUnitInfo; L: TCIErrorList);
var
  Decls, Impls: TList;
  Index: TStringList;                      // the implementations by 'Class.Name' ('.Name': plain), sorted
  AliasNames, AliasTargets: TStringList;   // the unit's types X = Y: X, Y

  { the implementations of class Cls's ('' plain) routine Name, added to Impls }
  procedure ImplsOf(const Cls, Name: string);
  var
    I: Integer;
    Key: string;
  begin
    Key := Cls + '.' + Name;
    if Index.Find(Key, I) then
      while (I < Index.Count) and SameText(Index[I], Key) do
      begin
        Impls.Add(Index.Objects[I]);
        Inc(I);
      end;
  end;

  { the implementations of Decls - the declarations of one name (several: overloads) - of class
    Cls ('' plain routines), also under another name of the class (TAlias = TClass); Shown: the
    name in the message. With fewer implementations than declarations, the declarations no
    implementation has the parameters of are reported when they are as many as are missing }
  procedure NeedBodies(const Cls, Shown: string);
  var
    I, J, Unpaired: Integer;
    Paired, Used: array of Boolean;
    Name: string;
  begin
    if Decls.Count = 0 then Exit;
    Name := TSymbol(Decls[0]).Name;
    Impls.Clear;
    ImplsOf(Cls, Name);
    if Cls <> '' then
      for I := 0 to AliasTargets.Count - 1 do
        if SameText(AliasTargets[I], Cls) then ImplsOf(AliasNames[I], Name);
    if Impls.Count >= Decls.Count then Exit;
    SetLength(Paired, Decls.Count);
    SetLength(Used, Impls.Count);
    Unpaired := Decls.Count;
    for I := 0 to Decls.Count - 1 do
    begin
      Paired[I] := False;
      for J := 0 to Impls.Count - 1 do
        if not Used[J] and ((Decls.Count = 1) or
          SameText(RoutineParamsText(TSymbol(Decls[I])), RoutineParamsText(TSymbol(Impls[J])))) then
        begin
          Used[J] := True;
          Paired[I] := True;
          Dec(Unpaired);
          Break;
        end;
    end;
    if Unpaired <> Decls.Count - Impls.Count then Exit;
    for I := 0 to Decls.Count - 1 do
      if not Paired[I] then
        L.AddAt(TSymbol(Decls[I]).DeclStart, Length(TSymbol(Decls[I]).Name), Format(SUnsatisfied, [Shown]));
  end;

  { the routines of Tab that need an implementation - of each name once: the symbol its name finds;
    not abstract, not external; InImpl: only those declared forward; of the classes of Tab, their
    methods }
  procedure CheckTable(Tab: TSymTable; InImpl: Boolean);
  const
    NoBody = [sfAbstract, sfExternal];
  var
    I, K: Integer;
    S, M: TSymbol;
    Members: TSymTable;
  begin
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if (S.Kind = skRoutine) and (InImpl or not U.IsProgram) and (Tab.Find(S.Name) = S) then
      begin
        Decls.Clear;
        if InImpl then AddRoutines(Tab, S.Name, [sfForward], NoBody, Decls)
        else AddRoutines(Tab, S.Name, [], NoBody, Decls);
        NeedBodies('', S.Name);
      end
      else if (S.Kind = skType) and IsStructDecl(S, [tyClass, tyObject]) and (S.TypeDesc.Sym = S) and
        (S.TypeDesc.Members <> nil) then
      begin
        Members := S.TypeDesc.Members;
        for K := 0 to Members.Count - 1 do
        begin
          M := Members[K];
          if (M.Kind = skRoutine) and (Members.Find(M.Name) = M) then
          begin
            Decls.Clear;
            AddRoutines(Members, M.Name, [], NoBody, Decls);
            NeedBodies(S.Name, S.Name + '.' + M.Name);
          end;
        end;
      end;
    end;
  end;

  { an implementation: its declaration - in its class, else in the interface or declared forward -
    with the same heading }
  procedure CheckImpl(R: TRoutineSym);
  var
    C: TSymbol;
  begin
    Decls.Clear;
    if R.ClassQual <> '' then
    begin
      if Pos('.', R.ClassQual) > 0 then Exit;
      C := U.FindTypeSym(R.ClassQual, [tyClass, tyObject]);
      if (C = nil) or (C.TypeDesc.Members = nil) then Exit;
      if C.TypeDesc.Members.Find(R.Name) = nil then
      begin
        L.AddAt(R.DeclStart, Length(R.Name), Format(SUndeclared, [R.Name]));
        Exit;
      end;
      AddRoutines(C.TypeDesc.Members, R.Name, [], [], Decls);
    end
    else
    begin
      if not U.IsProgram then AddRoutines(U.IntfSyms, R.Name, [], [], Decls);
      AddRoutines(U.ImplSyms, R.Name, [sfForward], [], Decls);
    end;
    { an implementation that says overload may be a new overload of the implementation's own }
    if (Decls.Count = 1) and not (sfOverload in TSymbol(Decls[0]).Flags) and not (sfOverload in R.Flags) and
      HeadingDiffers(TRoutineSym(Decls[0]), R) then
      L.AddAt(R.DeclStart, Length(R.Name), Format(SDiffers, [R.Name]));
  end;

  procedure FindAliases(Tab: TSymTable);
  var
    I: Integer;
    S: TSymbol;
  begin
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc.Kind = tyAlias) then
      begin
        AliasNames.Add(S.Name);
        AliasTargets.Add(S.TypeDesc.RefName);
      end;
    end;
  end;

var
  I: Integer;
  R: TRoutineSym;
begin
  Decls := TList.Create;
  Impls := TList.Create;
  Index := TStringList.Create;
  Index.Duplicates := dupAccept;           // Find then gives the first of a name's implementations
  AliasNames := TStringList.Create;
  AliasTargets := TStringList.Create;
  try
    { the implementations: the routines with bodies, and the routines of the interface implemented
      as external ones (function accept; external ...: the parser keeps those in no table) }
    for I := 0 to U.ImplRoutines.Count - 1 do
    begin
      R := TRoutineSym(U.ImplRoutines[I]);
      Index.AddObject(R.ClassQual + '.' + R.Name, R);
    end;
    for I := 0 to U.OwnedExtra.Count - 1 do
      if (TObject(U.OwnedExtra[I]) is TRoutineSym) and (sfExternal in TSymbol(U.OwnedExtra[I]).Flags) then
        Index.AddObject('.' + TSymbol(U.OwnedExtra[I]).Name, U.OwnedExtra[I]);
    Index.Sorted := True;
    FindAliases(U.IntfSyms);
    FindAliases(U.ImplSyms);
    CheckTable(U.IntfSyms, False);
    CheckTable(U.ImplSyms, True);
    for I := 0 to U.ImplRoutines.Count - 1 do
      if TRoutineSym(U.ImplRoutines[I]).Name <> '' then CheckImpl(TRoutineSym(U.ImplRoutines[I]));
  finally
    AliasTargets.Free;
    AliasNames.Free;
    Index.Free;
    Impls.Free;
    Decls.Free;
  end;
end;
function TCodeInsight.Diagnose(const FileName, Source: string; out Errors: TCIErrors; out Count: Integer): Boolean;
var
  Ctx: TCIContext;
  Chk: TPasCheck;
  L: TCIErrorList;
  Limit, I: Integer;
  N: TPasName;
  E: TPasError;
  Name: string;
begin
  Errors := nil;
  Count := 0;
  Result := False;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      Ctx := nil;
      Chk := TPasCheck.Create;
      L := TCIErrorList.Create;
      try
        Ctx := TCIContext.CreateShared(FEng, FileName, Source);
        L.U := Ctx.U;
        FEng.IncludeDir := ExtractFilePath(FileName);
        Chk.Check(Source, FEng.Defines, FEng.HandleInclude, True);
        for I := 0 to Chk.ErrorCount - 1 do
        begin
          E := Chk.Errors[I];
          L.Add(E.Start, E.Len, E.Line, E.Col, E.Msg);
        end;
        { the names past the first syntax error stand where the parse is not certain }
        if Chk.ErrorCount > 0 then Limit := Chk.Errors[0].Start else Limit := MaxInt;
        for I := 0 to Chk.NameCount - 1 do
        begin
          N := Chk.Names[I];
          if (N.Start >= Limit) or (L.Count >= MaxErrors) then Break;
          if Ctx.Undeclared(N.Start + N.Len, N.Use) then
          begin
            SetString(Name, PChar(Source) + N.Start, N.Len);
            L.AddAt(N.Start, N.Len, Format(SUndeclared, [Name]));
          end;
        end;
        if Chk.ErrorCount = 0 then CheckBodies(Ctx.U, L);
        L.Sort;
        Errors := L.Errors;
        Count := L.Count;
      finally
        L.Free;
        Chk.Free;
        Ctx.Free;
      end;
      Result := True;
    except
      NoteExc;
      Errors := nil;
      Count := 0;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TCodeInsight.FindReferences(Sym: TCIBrowseSym; Files, List: TStrings): Boolean;
var
  Srcs: array of string;
  Targets, Hits: TList;
  TargetUnit, U: TUnitInfo;
  I, K, Pass: Integer;
  Tab: TSymTable;
  S, O: TSymbol;
  Qual, UName: string;
  RT: TRawToks;

  { the symbol Name declared on Line in Tab (an overload is another line) }
  function FindIn(Tab: TSymTable; const Name: string; Line: Integer): TSymbol;
  begin
    Result := nil;
    if Tab = nil then Exit;
    Result := Tab.Find(Name);
    while (Result <> nil) and (Result.Line <> Line) do Result := Tab.FindNext(Result);
  end;

begin
  Result := False;
  List.Clear;
  if (Sym = nil) or (Sym.UnitInfo = nil) then Exit;
  EnterCriticalSection(FLock);
  try
    try
      FEng.BeginCall;
      Targets := TList.Create;
      Hits := TList.Create;
      try
        { every file of the project whole, as in Browse - then the symbol in the parser's data }
        SetLength(Srcs, Files.Count);
        for I := 0 to Files.Count - 1 do
        begin
          if not SourceFor(Files[I], Srcs[I]) then Srcs[I] := '';
          FEng.LoadCurrent(Files[I], Srcs[I]);
        end;
        U := nil;
        for I := 0 to Files.Count - 1 do
          if SameText(FEng.NormFileName(Files[I]), FEng.NormFileName(Sym.UnitInfo.FileName)) then
            U := FEng.LoadCurrent(Files[I], Srcs[I]);
        if U = nil then U := FEng.LoadFile(FEng.NormFileName(Sym.UnitInfo.FileName));
        TargetUnit := nil;
        if Sym.Kind = ckUnit then TargetUnit := U
        else
        begin
          S := nil;
          if Sym.Owner = nil then
          begin
            for Pass := 0 to 1 do
              if S = nil then
              begin
                if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
                S := FindIn(Tab, Sym.Name, Sym.Line);
              end;
            Qual := '';
          end
          else
          begin
            O := FindIn(U.IntfSyms, Sym.Owner.Name, Sym.Owner.Line);
            if O = nil then O := FindIn(U.ImplSyms, Sym.Owner.Name, Sym.Owner.Line);
            if (O <> nil) and (O.TypeDesc <> nil) then S := FindIn(O.TypeDesc.Members, Sym.Name, Sym.Line);
            Qual := Sym.Owner.Name;
          end;
          if S = nil then Exit;
          Targets.Add(S);
          { a routine: its implementations name it as well }
          if S.Kind = skRoutine then U.GetImpls(Targets, Qual, S.Name);
        end;
        UName := UpperCase(Sym.Name);
        for I := 0 to Files.Count - 1 do
        begin
          Hits.Clear;
          RT := NamePlaces(FEng, Files[I], Srcs[I], FEng.LoadCurrent(Files[I], Srcs[I]), TargetUnit,
            Targets, UName, Hits);
          try
            for K := 0 to Hits.Count - 1 do
              with RT.T[Integer(Hits[K])] do
                List.Add(Files[I] + #9 + IntToStr(Line) + #9 + IntToStr(Col) + #9 + LineAround(Srcs[I], Start));
          finally
            RT.Free;
          end;
        end;
        Result := List.Count > 0;
      finally
        Hits.Free;
        Targets.Free;
      end;
    except
      NoteExc;
      Result := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

end.
