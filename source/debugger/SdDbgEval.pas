{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDbgEval;

{ D7 Studio debugger - expression evaluator and Delphi-style value formatter.

  Works on debuggee memory through an abstract host (implemented by
  SdDbgEngine) and on the TD32 type information (SdDbgTD32). }

interface

uses
  Windows, SysUtils, Classes, SdDbgTD32;

type
  TDbgVar = record
    Name: string;
    Value: string;           // formatted Delphi-style
    TypeName: string;
    Expandable: Boolean;     // has children (record/object fields, array elements, dereferenced pointer)
    Expr: string;            // expression usable with Evaluate/GetChildren to re-evaluate this item
    { set by Evaluate only: }
    Address: Cardinal;       // the program's memory that holds the value (0: none - a register, a constant)
    Size: Integer;           // its size in bytes (0: unknown)
    CanModify: Boolean;      // a variable (memory or register): Modify can change it
  end;
  TDbgVarArray = array of TDbgVar;

  { What the evaluator needs from the debugger: memory, registers, the frame being inspected
    and the debug information of the loaded modules. }
  TDbgEvalHost = class
  public
    function ReadMem(Addr: Cardinal; var Buf; Size: Integer): Boolean; virtual; abstract;
    function WriteMem(Addr: Cardinal; const Buf; Size: Integer): Boolean; virtual; abstract;
    function GetReg(CVReg: Integer; out Value: Cardinal): Boolean; virtual; abstract;
    function SetReg(CVReg: Integer; Value: Cardinal): Boolean; virtual; abstract;
    function FrameEIP: Cardinal; virtual; abstract;      // address used for scope lookup
    function FrameEBP: Cardinal; virtual; abstract;
    function IsTopFrame: Boolean; virtual; abstract;     // register variables are only valid there
    function InfoCount: Integer; virtual; abstract;
    function GetInfo(Index: Integer; out Info: TTD32Info; out Base: Cardinal): Boolean; virtual; abstract;
    function InfoByAddr(Addr: Cardinal; out Info: TTD32Info; out Base: Cardinal): Boolean; virtual; abstract;
    function AddrToSymbol(Addr: Cardinal): string; virtual; abstract;   // 'Unit.Proc' when Addr is a routine start
    { Calling code of the program (function calls, properties read by a method). CallScratch:
      memory of the thread for arguments and results ( bytes, 0: no calls); CallCode runs
      Addr with up to three register arguments (EAX, EDX, ECX) and the stack arguments (pushed in
      their order) and gives EAX, EDX and ST(0) back; FindCode: the code of Routine of class
      ClassName among the packages' exports (Routine may be an export's own name). The defaults: none. }
    function CallScratch: Cardinal; virtual;
    function CallCode(Addr: Cardinal; const Regs, Stack: array of Cardinal; out EAX, EDX: Cardinal;
      out ST0: Extended; out Error: string): Boolean; virtual;
    function FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal; virtual;
  end;

  EDbgEval = class(Exception);

  { reads debuggee memory: TDbgEvalHost.ReadMem, or the debugger's own reader }
  TDbgReadMem = function(Addr: Cardinal; var Buf; Size: Integer): Boolean of object;

  { evCall: a routine or method not yet called - Addr its code, TypeIdx its procedure type (0:
    unknown, then ModIdx the type of its result), I the object (Reg = 1: a method), S its name }
  TEvKind = (evNone, evMem, evReg, evConst, evType, evUnit, evCall);
  TEvConst = (ecInt, ecFloat, ecStr, ecBool, ecChar, ecPtr);

  TEvValue = record
    Kind: TEvKind;
    Info: TTD32Info;         // owner of TypeIdx (nil: primitive index only)
    Base: Cardinal;          // load address of the module Info belongs to
    TypeIdx: Cardinal;       // TD32 type index, 0 = untyped constant
    Addr: Cardinal;          // evMem
    Reg: Integer;            // evReg: CodeView register number
    CK: TEvConst;            // evConst
    I: Int64;
    F: Extended;
    S: string;
    ModIdx: Integer;         // evUnit
    HighKnown: Boolean;      // open array parameter: High() is known
    HighValue: Integer;
  end;

  TTokKind = (ttEOF, ttIdent, ttInt, ttFloat, ttStr, ttSym);

  { the rows of a list the evaluator makes (fields, elements, locals, the Debug Inspector's methods
    and properties): the array grows by doubling (a thousand elements were a thousand copies of
    the whole list); Indexed: a row is found by its name (letter case aside) in a sorted list }
  TVarRows = class
  private
    FNames: TStringList;              // Objects: the row
  public
    Vars: TDbgVarArray;
    Count: Integer;
    constructor Create(Indexed: Boolean);
    destructor Destroy; override;
    function Add(const Name: string): Integer;      // a new row at the end (its Name set)
    function Find(const Name: string): Integer;     // the row of Name, -1: none (Indexed only)
    function RowOf(const Name: string): Integer;    // the row of Name, a new one when there is none
    procedure Finish(out A: TDbgVarArray);          // the rows, as many as there are
  end;

  TDbgEvaluator = class
  private
    FHost: TDbgEvalHost;
    FText: string;
    FPos: Integer;
    FTok: TTokKind;
    FTokStr: string;
    FTokInt: Int64;
    FTokFloat: Extended;
    FFmt: Char;
    // frame
    FFrameReady: Boolean;
    FAllowCalls: Boolean;
    FTopClass: Cardinal;           // SearchClass: the class the search began with (virtual methods)
    FScratch, FScratchUsed: Cardinal;   // the memory of the calls of this evaluation
    FFrameInfo: TTD32Info;
    FFrameBase: Cardinal;
    FFrameProc: Integer;
    FFrameModule: Integer;
    FFrameSyms: TTDSymbolArray;
    FDynName: string;
    FDynInfo: TTD32Info;
    FDynIdx: Cardinal;
    procedure Err(const Msg: string);
    procedure InitFrame;
    { lexer }
    procedure NextTok;
    function IsSym(const S: string): Boolean;
    function IsKeyword(const S: string): Boolean;
    procedure Expect(const S: string);
    { type helpers }
    function GetT(Info: TTD32Info; Idx: Cardinal; out T: TTDTypeInfo): Boolean;
    function TypeOf(const V: TEvValue; out T: TTDTypeInfo): Boolean;
    function SizeOfType(Info: TTD32Info; Idx: Cardinal): Integer;
    function TypeNameOf(const V: TEvValue): string;
    function OrdWidth(const V: TEvValue; X: Int64; out Signed: Boolean): Integer;
    { memory helpers }
    function RdDWord(Addr: Cardinal; out V: Cardinal): Boolean;
    procedure LoadRaw(const V: TEvValue; var Buf; Size: Integer);
    function LoadInt(const V: TEvValue): Int64;
    function LoadFloat(const V: TEvValue): Extended;
    function LoadPtr(const V: TEvValue): Cardinal;
    function IsFloatValue(const V: TEvValue): Boolean;
    function IsStringValue(const V: TEvValue): Boolean;
    function IsOrdinalValue(const V: TEvValue): Boolean;
    function LoadStr(const V: TEvValue): string;
    function LenAt(P: Cardinal): Cardinal;
    function ReadCStr(P: Cardinal; MaxLen: Integer; out Truncated: Boolean): string;
    function ReadWStr(P: Cardinal; CharCount: Integer; ZeroTerm: Boolean; out Truncated: Boolean): string;
    function ReadLStr(P: Cardinal; MaxLen: Integer; out S: string; out Truncated: Boolean): Boolean;
    function ReadWideStr(P: Cardinal; out Truncated: Boolean): string;
    function LoadShortStr(const V: TEvValue): string;
    { value constructors }
    function MemValue(Info: TTD32Info; Base, Addr, TypeIdx: Cardinal): TEvValue;
    function IntConst(I: Int64): TEvValue;
    function FloatConst(F: Extended): TEvValue;
    function BoolConst(B: Boolean): TEvValue;
    function StrConst(const S: string): TEvValue;
    function AutoDeref(const V: TEvValue): TEvValue;
    function SymValue(Info: TTD32Info; Base: Cardinal; const Sym: TTDSymbol; EBP, EIP: Cardinal;
      Top: Boolean): TEvValue;
    { symbol lookup }
    function PickLocal(const Name: string; const Syms: TTDSymbolArray; out Index: Integer): Boolean;
    function LookupLocal(const Name: string; out V: TEvValue): Boolean;
    function LookupWith(const Name: string; Heuristic: Boolean; out V: TEvValue): Boolean;
    function LookupSelf(const Name: string; out V: TEvValue): Boolean;
    function LookupParents(const Name: string; out V: TEvValue): Boolean;
    function LookupGlobal(const Name: string; OnlyInfo: TTD32Info; OnlyBase: Cardinal; OnlyModule: Integer;
      out V: TEvValue): Boolean;
    function LookupType(const Name: string; out V: TEvValue): Boolean;
    function LookupUnit(const Name: string; out V: TEvValue): Boolean;
    function LookupRegister(const Name: string; out V: TEvValue): Boolean;
    function ResolveIdent(const Name: string): TEvValue;
    function DynamicClass(Info: TTD32Info; Obj: Cardinal; out ClassIdx: Cardinal): Boolean;
    function SearchClass(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal; const Name: string;
      out R: TEvValue; Depth: Integer): Boolean;
    function FindMember(const V: TEvValue; const Name: string; out R: TEvValue): Boolean;
    { operations }
    function Deref(const V: TEvValue): TEvValue;
    function IndexValue(const V: TEvValue; Index: Int64): TEvValue;
    function CastValue(const T, V: TEvValue): TEvValue;
    function AddressOf(const V: TEvValue): TEvValue;
    function BinaryOp(const Op: string; const L, R: TEvValue): TEvValue;
    function Compare(const Op: string; const L, R: TEvValue): TEvValue;
    function InSet(const L, R: TEvValue): TEvValue;
    function CallIntrinsic(const Name: string; var Handled: Boolean): TEvValue;
    { calls of code of the program (AllowCalls) }
    function CodeOf(Info: TTD32Info; ClassIdx: Cardinal; const Routine: string; var C: TEvValue;
      out ExportName: string; Virt: Boolean = True): Boolean;
    function IsVirtual(Info: TTD32Info; ClassIdx: Cardinal; const Method: string): Boolean;
    function LookupRoutine(const Name: string; out V: TEvValue): Boolean;
    function ScratchAlloc(Size: Integer): Cardinal;
    function CallValue(const C: TEvValue; const Args: array of TEvValue): TEvValue;
    function GetterCall(Info: TTD32Info; Base, ClassIdx, Obj: Cardinal; const Getter: string;
      PropType, DeclClass: Cardinal): TEvValue;
    { parser }
    function ParseExpr: TEvValue;
    function ParseSimple: TEvValue;
    function ParseTerm: TEvValue;
    function ParseFactor: TEvValue;
    function ParsePostfix(const AV: TEvValue): TEvValue;
    function EvalText(const Expr: string): TEvValue;
    { formatting }
    function QuoteStr(const S: string): string;
    function QuoteTrunc(const S: string; Truncated: Boolean): string;
    function CharLit(C: Integer): string;
    function FloatText(X: Extended; Prec: Integer): string;
    function FormatSet(const V: TEvValue; const T: TTDTypeInfo): string;
    function FormatVariant(Addr: Cardinal): string;
    function FormatOrdinal(Info: TTD32Info; TypeIdx: Cardinal; Value: Int64): string;
    function FormatValue(const V: TEvValue; Depth: Integer): string;
    function HasChildren(const V: TEvValue): Boolean;
    procedure CollectFields(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal; const ParentExpr: string;
      Rows: TVarRows; Depth: Integer);
    procedure CollectMembers(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal; const ParentExpr: string;
      Dynamic: Boolean; Methods, Props: TVarRows; Depth: Integer);
    function Inspected(const Expr: string; out Val: TEvValue; out T: TTDTypeInfo): Boolean;
    function SeenThrough(var Val: TEvValue; out T: TTDTypeInfo): Boolean;
    procedure ChildRows(const Val: TEvValue; const T: TTDTypeInfo; const Expr: string; Rows: TVarRows);
    procedure MemberRows(const Val: TEvValue; const T: TTDTypeInfo; const Expr: string; Dynamic: Boolean;
      MRows, PRows: TVarRows);
    function EvaluateTo(const Expr: string; out V: TDbgVar; out Error: string; out Val: TEvValue): Boolean;
    procedure AddVar(Rows: TVarRows; const Name, Expr: string; const V: TEvValue);
    function MakeVar(const Name, Expr: string; const V: TEvValue): TDbgVar;
    function ChildExpr(const Parent, Suffix: string): string;
    procedure StoreValue(const Dest, Src: TEvValue);
  public
    constructor Create(AHost: TDbgEvalHost);      // the evaluator owns AHost and frees it
    destructor Destroy; override;
    function Evaluate(const Expr: string; out V: TDbgVar; out Error: string): Boolean;
    function GetChildren(const Expr: string; out Vars: TDbgVarArray; out Error: string): Boolean;
    { the methods (Value: the signature) and properties of the object or record Expr (the Debug
      Inspector's Methods and Properties); Dynamic: also the properties read by a method }
    function GetMembers(const Expr: string; Dynamic: Boolean; out Methods, Props: TDbgVarArray;
      out Error: string): Boolean;
    { Evaluate, GetChildren (when the value has parts: V.Expandable) and GetMembers from one
      evaluation of Expr - its calls run once (the Debug Inspector's); the rows of a value that
      cannot be read are empty }
    function Inspect(const Expr: string; Dynamic: Boolean; out V: TDbgVar; out Children, Methods,
      Props: TDbgVarArray; out Error: string): Boolean;
    function GetLocals(out Vars: TDbgVarArray): Boolean;
    { methods and properties read by a method may be called (Evaluate/Modify, breakpoint conditions,
      the inspector, a watch with Allow Function Calls - not hints) }
    property AllowCalls: Boolean read FAllowCalls write FAllowCalls;
    function Modify(const Expr, NewValue: string; out Error: string): Boolean;
    function EvalBoolean(const Expr: string; out Value: Boolean; out Error: string): Boolean;
    { helpers shared with the engine }
    function ReadClassName(Obj: Cardinal): string;
    function ReadVMTClassName(VMT: Cardinal): string;
    function ReadAnsiString(P: Cardinal; MaxLen: Integer): string;   // '' when it cannot be read
    function InheritsFromName(Obj: Cardinal; const AClassName: string): Boolean;
  end;

{ The #0-terminated string at P, at most MaxLen characters; Truncated: no #0 within them, or the
  memory ends before one. Reads up to the end of each page, so that a string that ends just
  before an unreadable page is still read. False when nothing at P can be read. }
function ReadCString(Read: TDbgReadMem; P: Cardinal; MaxLen: Integer; out S: string;
  out Truncated: Boolean): Boolean;

{ UTF-16 text of the debuggee in the code page the IDE's ANSI windows show (UTF-8: D7 Studio runs
  in UTF-8 mode; Delphi 7 would convert with the user locale's code page). }
function WideToAnsi(const W: WideString): string;
{ the bytes of an ANSI string of the debuggee as the IDE shows text: as they are when they are
  UTF-8 (a program in UTF-8 mode - D7 Studio's default for programs), else read in the system code
  page (a program without it) }
function ProgramText(const S: string): string;

{ the value tip (SdHints.TSdValueTip) shows a value's members at once when Value - the evaluator's
  text of a value - is a record "(Name: value; ...)" (split at the semicolons outside brackets and
  quotes), or an array "(a, b, ...)" whose elements are such values. Not: an array of plain
  values, a method pointer, the depth limit's "(...)", an empty record }
function DbgValueIsList(const Value: string): Boolean;

implementation

uses
  SdEncoding;

const
  MAX_STR_DISPLAY = 1024;
  MAX_ARRAY_DISPLAY = 32;
  MAX_CHILDREN = 1000;
  MAX_FORMAT_DEPTH = 3;
  vmtClassName = -44;
  vmtParent = -36;

  T_PVOID = $0403;
  T_PPASCHAR = $0461;
  T_PWCHAR = $0471;

{ ---------------------------------------------------------------- TDbgEvalHost }

function TDbgEvalHost.CallScratch: Cardinal;
begin
  Result := 0;
end;

function TDbgEvalHost.CallCode(Addr: Cardinal; const Regs, Stack: array of Cardinal; out EAX, EDX: Cardinal;
  out ST0: Extended; out Error: string): Boolean;
begin
  EAX := 0;
  EDX := 0;
  ST0 := 0;
  Error := 'Function calls are not possible here';
  Result := False;
end;

function TDbgEvalHost.FindCode(const ClassName, Routine: string; out ExportName: string): Cardinal;
begin
  ExportName := '';
  Result := 0;
end;

procedure InitValue(var V: TEvValue);
begin
  V.Kind := evNone;
  V.Info := nil;
  V.Base := 0;
  V.TypeIdx := 0;
  V.Addr := 0;
  V.Reg := 0;
  V.CK := ecInt;
  V.I := 0;
  V.F := 0;
  V.S := '';
  V.ModIdx := -1;
  V.HighKnown := False;
  V.HighValue := -1;
end;

{ a block a read - at most what MaxLen still allows and the #0 after it, never beyond the page -,
  its characters up to the #0 appended in one piece }
function ReadCString(Read: TDbgReadMem; P: Cardinal; MaxLen: Integer; out S: string;
  out Truncated: Boolean): Boolean;
var
  Buf: array[0..1023] of Char;
  N, Z, Chunk: Integer;
  Done: Boolean;
begin
  S := '';
  Result := False;
  Done := False;
  while not Done and (Length(S) < MaxLen) do
  begin
    Chunk := SizeOf(Buf);
    N := MaxLen - Length(S) + 1;
    if N < Chunk then Chunk := N;
    N := $1000 - Integer(P and $FFF);
    if N < Chunk then Chunk := N;
    if not Read(P, Buf, Chunk) then Break;
    Result := True;
    Z := 0;
    while (Z < Chunk) and (Buf[Z] <> #0) do Inc(Z);
    Done := Z < Chunk;
    if Z > 0 then
    begin
      N := Length(S);
      SetLength(S, N + Z);
      Move(Buf[0], S[N + 1], Z);
    end;
    Inc(P, Chunk);
  end;
  Truncated := not Done or (Length(S) > MaxLen);
  if Length(S) > MaxLen then SetLength(S, MaxLen);
end;

{ ---------------------------------------------------------------- TVarRows }

constructor TVarRows.Create(Indexed: Boolean);
begin
  inherited Create;
  if Indexed then
  begin
    FNames := TStringList.Create;
    FNames.Sorted := True;
    FNames.CaseSensitive := False;
  end;
end;

destructor TVarRows.Destroy;
begin
  FNames.Free;
  inherited Destroy;
end;

function TVarRows.Add(const Name: string): Integer;
begin
  if Count >= Length(Vars) then
    if Count = 0 then SetLength(Vars, 16) else SetLength(Vars, Count * 2);
  Result := Count;
  Inc(Count);
  Vars[Result].Name := Name;
  if FNames <> nil then FNames.AddObject(Name, TObject(Result));
end;

function TVarRows.Find(const Name: string): Integer;
begin
  if (FNames <> nil) and FNames.Find(Name, Result) then
    Result := Integer(FNames.Objects[Result])
  else
    Result := -1;
end;

function TVarRows.RowOf(const Name: string): Integer;
begin
  Result := Find(Name);
  if Result < 0 then Result := Add(Name);
end;

procedure TVarRows.Finish(out A: TDbgVarArray);
begin
  SetLength(Vars, Count);
  A := Vars;
end;

function WideToAnsi(const W: WideString): string;
var
  Lost: Boolean;
begin
  Result := FromWide(W, CP_ACP, Lost);
end;

function ProgramText(const S: string): string;
begin
  if HasHighBytes(S) and not IsValidUtf8(S) then Result := SystemToIde(S) else Result := S;
end;

{ in the evaluator's text of a list "(...)": the position of the next Sep from From on that lies
  outside brackets and quotes (From: the start of a part); Length(Value) - the closing bracket -
  when there is none and the brackets match up to it; 0 when they do not }
function NextTopLevel(const Value: string; From: Integer; Sep: Char): Integer;
var
  I, Depth: Integer;
  InStr: Boolean;
begin
  Result := 0;
  Depth := 0;
  InStr := False;
  for I := From to Length(Value) - 1 do
    if Value[I] = '''' then
      InStr := not InStr                  // a doubled quote inside a string toggles twice
    else if not InStr then
      case Value[I] of
        '(', '[':
          Inc(Depth);
        ')', ']':
          begin
            Dec(Depth);
            if Depth < 0 then Exit;
          end;
      else
        if (Value[I] = Sep) and (Depth = 0) then
        begin
          Result := I;
          Exit;
        end;
      end;
  if not InStr and (Depth = 0) then Result := Length(Value);
end;

{ Value is the evaluator's text of a record: "(Name: value; ...)", every part between the
  semicolons outside brackets and quotes a field name and its value }
function IsRecordText(const Value: string): Boolean;
var
  I, Start: Integer;

  function IsField(const F: string): Boolean;
  var
    P, J: Integer;
  begin
    Result := False;
    P := Pos(': ', F);
    if (P < 2) or (F[1] in ['0'..'9']) then Exit;
    for J := 1 to P - 1 do
      if not (F[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
    Result := True;
  end;

begin
  Result := False;
  if (Length(Value) < 5) or (Value[1] <> '(') or (Value[Length(Value)] <> ')') then Exit;
  Start := 2;
  repeat
    I := NextTopLevel(Value, Start, ';');
    if (I = 0) or not IsField(Copy(Value, Start, I - Start)) then Exit;
    Start := I + 1;
    if Copy(Value, Start, 1) = ' ' then Inc(Start);
  until I = Length(Value);
  Result := True;
end;

{ the first element of an array's text "(a, b, ...)": up to the first comma outside brackets and
  quotes; '' when Value is no such text }
function FirstElementText(const Value: string): string;
var
  I: Integer;
begin
  Result := '';
  if (Length(Value) < 3) or (Value[1] <> '(') or (Value[Length(Value)] <> ')') then Exit;
  I := NextTopLevel(Value, 2, ',');
  if I > 0 then Result := Copy(Value, 2, I - 2);
end;

function DbgValueIsList(const Value: string): Boolean;
var
  E: string;
begin
  Result := IsRecordText(Value);
  if not Result then
  begin
    E := FirstElementText(Value);
    Result := (E <> '') and DbgValueIsList(E);
  end;
end;

{ TDbgEvaluator }

constructor TDbgEvaluator.Create(AHost: TDbgEvalHost);
begin
  inherited Create;
  FHost := AHost;
end;

destructor TDbgEvaluator.Destroy;
begin
  FHost.Free;
  inherited Destroy;
end;

procedure TDbgEvaluator.Err(const Msg: string);
begin
  raise EDbgEval.Create(Msg);
end;

procedure TDbgEvaluator.InitFrame;
var
  EIP: Cardinal;
begin
  FFrameReady := True;
  FFrameInfo := nil;
  FFrameBase := 0;
  FFrameProc := -1;
  FFrameModule := -1;
  FFrameSyms := nil;
  EIP := FHost.FrameEIP;
  if FHost.InfoByAddr(EIP, FFrameInfo, FFrameBase) and (FFrameInfo <> nil) then
  begin
    FFrameProc := FFrameInfo.ProcByAddr(EIP - FFrameBase);
    if FFrameProc >= 0 then
    begin
      FFrameModule := FFrameInfo.Procs[FFrameProc]^.Module;
      FFrameInfo.GetProcSymbols(FFrameProc, FFrameSyms);
    end
    else
      FFrameModule := FFrameInfo.ModuleByAddr(EIP - FFrameBase);
  end
  else
    FFrameInfo := nil;
end;

{ lexer }

procedure TDbgEvaluator.NextTok;
var
  Start, Code, N: Integer;
  S: string;
  C: Char;
  IsFloat: Boolean;
begin
  FTokStr := '';
  while (FPos <= Length(FText)) and (FText[FPos] <= ' ') do Inc(FPos);
  if FPos > Length(FText) then
  begin
    FTok := ttEOF;
    Exit;
  end;
  C := FText[FPos];
  if C in ['A'..'Z', 'a'..'z', '_'] then
  begin
    Start := FPos;
    while (FPos <= Length(FText)) and (FText[FPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(FPos);
    FTokStr := Copy(FText, Start, FPos - Start);
    FTok := ttIdent;
    Exit;
  end;
  if C = '$' then
  begin
    Start := FPos;
    Inc(FPos);
    while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(FPos);
    S := Copy(FText, Start, FPos - Start);
    if Length(S) = 1 then
    begin
      // '$' followed by identifier characters: a compiler temporary name ($46032308) never
      // reaches here because those start with digits; treat a lone $ as an error
      Err('Invalid hexadecimal number');
    end;
    FTokInt := StrToInt64(S);
    if Length(S) <= 9 then FTokInt := FTokInt and $FFFFFFFF;
    FTok := ttInt;
    Exit;
  end;
  if C in ['0'..'9'] then
  begin
    Start := FPos;
    IsFloat := False;
    while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
    if (FPos < Length(FText)) and (FText[FPos] = '.') and (FText[FPos + 1] in ['0'..'9']) then
    begin
      IsFloat := True;
      Inc(FPos);
      while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
    end;
    if (FPos <= Length(FText)) and (FText[FPos] in ['e', 'E']) then
    begin
      N := FPos + 1;
      if (N <= Length(FText)) and (FText[N] in ['+', '-']) then Inc(N);
      if (N <= Length(FText)) and (FText[N] in ['0'..'9']) then
      begin
        IsFloat := True;
        FPos := N;
        while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
      end;
    end;
    S := Copy(FText, Start, FPos - Start);
    if IsFloat then
    begin
      Val(S, FTokFloat, Code);
      if Code <> 0 then Err('Invalid number: ' + S);
      FTok := ttFloat;
    end
    else
    begin
      Val(S, FTokInt, Code);
      if Code <> 0 then Err('Invalid number: ' + S);
      FTok := ttInt;
    end;
    Exit;
  end;
  if (C = '''') or (C = '#') then
  begin
    // string literal: 'text' and #nn pieces concatenated
    S := '';
    while FPos <= Length(FText) do
    begin
      if FText[FPos] = '''' then
      begin
        Inc(FPos);
        while True do
        begin
          if FPos > Length(FText) then Err('Unterminated string');
          if FText[FPos] = '''' then
          begin
            if (FPos < Length(FText)) and (FText[FPos + 1] = '''') then
            begin
              S := S + '''';
              Inc(FPos, 2);
            end
            else
            begin
              Inc(FPos);
              Break;
            end;
          end
          else
          begin
            S := S + FText[FPos];
            Inc(FPos);
          end;
        end;
      end
      else if FText[FPos] = '#' then
      begin
        Inc(FPos);
        Start := FPos;
        if (FPos <= Length(FText)) and (FText[FPos] = '$') then Inc(FPos);
        while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(FPos);
        N := StrToIntDef(Copy(FText, Start, FPos - Start), -1);
        if (N < 0) or (N > 255) then Err('Invalid character code');
        S := S + Chr(N);
      end
      else
        Break;
    end;
    FTokStr := S;
    FTok := ttStr;
    Exit;
  end;
  // symbols
  FTok := ttSym;
  if FPos < Length(FText) then
  begin
    S := Copy(FText, FPos, 2);
    if (S = '<>') or (S = '<=') or (S = '>=') then
    begin
      FTokStr := S;
      Inc(FPos, 2);
      Exit;
    end;
  end;
  FTokStr := C;
  Inc(FPos);
  if not (C in ['+', '-', '*', '/', '(', ')', '[', ']', '.', ',', '^', '@', '=', '<', '>']) then
    Err('Unexpected character "' + C + '"');
end;

function TDbgEvaluator.IsSym(const S: string): Boolean;
begin
  Result := (FTok = ttSym) and (FTokStr = S);
end;

function TDbgEvaluator.IsKeyword(const S: string): Boolean;
begin
  Result := (FTok = ttIdent) and SameText(FTokStr, S);
end;

procedure TDbgEvaluator.Expect(const S: string);
begin
  if not IsSym(S) then Err('"' + S + '" expected');
  NextTok;
end;

{ type helpers }

function TDbgEvaluator.GetT(Info: TTD32Info; Idx: Cardinal; out T: TTDTypeInfo): Boolean;
begin
  if Idx < $1000 then
    Result := GetPrimitiveType(Idx, T)
  else if Info <> nil then
    Result := Info.GetType(Idx, T)
  else
  begin
    GetPrimitiveType(0, T);
    Result := False;
  end;
end;

function TDbgEvaluator.TypeOf(const V: TEvValue; out T: TTDTypeInfo): Boolean;
begin
  Result := GetT(V.Info, V.TypeIdx, T);
end;

function TDbgEvaluator.SizeOfType(Info: TTD32Info; Idx: Cardinal): Integer;
var
  T: TTDTypeInfo;
begin
  if GetT(Info, Idx, T) then
    Result := T.Size
  else
    Result := -1;
end;

function TDbgEvaluator.TypeNameOf(const V: TEvValue): string;
begin
  Result := '';
  case V.Kind of
    evConst:
      if V.TypeIdx = 0 then
        case V.CK of
          ecInt: Result := 'Integer';
          ecFloat: Result := 'Extended';
          ecStr: Result := 'string';
          ecBool: Result := 'Boolean';
          ecChar: Result := 'Char';
          ecPtr: Result := 'Pointer';
        end;
    evUnit: Result := 'unit';
  end;
  if Result <> '' then Exit;
  if V.TypeIdx < $1000 then
    Result := PrimitiveTypeName(V.TypeIdx)
  else if V.Info <> nil then
    Result := V.Info.TypeName(V.TypeIdx)
  else
    Result := '?';
end;

{ Size in bytes of the integer type V has for "not", "shl" and "shr", which work in the operand's
  own type; Signed: Integer-like. An untyped constant is an Integer, a Cardinal or an Int64 by
  its value. X: the value of V. }
function TDbgEvaluator.OrdWidth(const V: TEvValue; X: Int64; out Signed: Boolean): Integer;
var
  T: TTDTypeInfo;
begin
  if (V.Kind <> evConst) and TypeOf(V, T) and (T.Size in [1, 2, 4, 8]) then
  begin
    Result := T.Size;
    Signed := (T.Kind = tkInteger) and T.Signed;
  end
  else
  begin
    Signed := (X >= Low(Integer)) and (X <= High(Integer));
    if Signed or ((X >= 0) and (X <= High(Cardinal))) then Result := 4 else Result := 8;
    if Result = 8 then Signed := True;
  end;
end;

{ memory helpers }

function TDbgEvaluator.RdDWord(Addr: Cardinal; out V: Cardinal): Boolean;
begin
  V := 0;
  Result := FHost.ReadMem(Addr, V, 4);
end;

procedure TDbgEvaluator.LoadRaw(const V: TEvValue; var Buf; Size: Integer);
var
  R: Cardinal;
  Tmp: Int64;
begin
  case V.Kind of
    evMem:
      if not FHost.ReadMem(V.Addr, Buf, Size) then
        Err(Format('Cannot read memory at $%.8x', [V.Addr]));
    evReg:
      begin
        if not FHost.GetReg(V.Reg, R) then Err('Register value is not available');
        FillChar(Buf, Size, 0);
        if Size > 4 then Move(R, Buf, 4) else Move(R, Buf, Size);
      end;
    evConst:
      begin
        Tmp := V.I;
        FillChar(Buf, Size, 0);
        if Size > 8 then Move(Tmp, Buf, 8) else Move(Tmp, Buf, Size);
      end;
  else
    Err('Expression has no value');
  end;
end;

function TDbgEvaluator.LoadInt(const V: TEvValue): Int64;
var
  T: TTDTypeInfo;
  B: array[0..7] of Byte;
  Size: Integer;
begin
  Result := 0;
  if V.Kind = evConst then
  begin
    case V.CK of
      ecInt, ecBool, ecChar, ecPtr: Result := V.I;
      ecFloat: Err('Ordinal value expected');
      ecStr:
        if Length(V.S) = 1 then
          Result := Ord(V.S[1])
        else
          Err('Ordinal value expected');
    end;
    Exit;
  end;
  if not TypeOf(V, T) then Err('Unknown type');
  Size := T.Size;
  case T.Kind of
    tkInteger, tkBoolean, tkChar, tkWideChar, tkEnum: ;
    tkPointer, tkClassRef, tkObject, tkInterface, tkProcedure, tkDynArray, tkAnsiString, tkWideString,
    tkOpenArray:
      Size := 4;
  else
    Err('Ordinal value expected');
  end;
  if not (Size in [1, 2, 4, 8]) then Err('Unsupported ordinal size');
  FillChar(B, SizeOf(B), 0);
  LoadRaw(V, B, Size);
  case Size of
    1: if (T.Kind = tkInteger) and T.Signed then Result := ShortInt(B[0]) else Result := B[0];
    2: if (T.Kind = tkInteger) and T.Signed then Result := PSmallInt(@B)^ else Result := PWord(@B)^;
    4: if (T.Kind = tkInteger) and T.Signed then Result := PInteger(@B)^ else Result := PCardinal(@B)^;
    8: Result := PInt64(@B)^;
  end;
end;

function TDbgEvaluator.LoadPtr(const V: TEvValue): Cardinal;
begin
  Result := Cardinal(LoadInt(V) and $FFFFFFFF);
end;

function TDbgEvaluator.IsFloatValue(const V: TEvValue): Boolean;
var
  T: TTDTypeInfo;
begin
  if V.Kind = evConst then
    Result := V.CK = ecFloat
  else
    Result := TypeOf(V, T) and (T.Kind in [tkFloat, tkCurrency]);
end;

function TDbgEvaluator.LoadFloat(const V: TEvValue): Extended;
var
  T: TTDTypeInfo;
  S: Single;
  D: Double;
  E: Extended;
  R: Real48;
  C: Int64;
begin
  Result := 0;
  if V.Kind = evConst then
  begin
    if V.CK = ecFloat then Result := V.F else Result := LoadInt(V);
    Exit;
  end;
  if not TypeOf(V, T) then Err('Unknown type');
  case T.Kind of
    tkFloat:
      case T.FloatKind of
        fkSingle: begin LoadRaw(V, S, 4); Result := S; end;
        fkDouble: begin LoadRaw(V, D, 8); Result := D; end;
        fkExtended: begin LoadRaw(V, E, 10); Result := E; end;
        fkReal48: begin LoadRaw(V, R, 6); Result := R; end;
      end;
    tkCurrency:
      begin
        LoadRaw(V, C, 8);
        Result := C / 10000;
      end;
  else
    Result := LoadInt(V);
  end;
end;

function TDbgEvaluator.IsOrdinalValue(const V: TEvValue): Boolean;
var
  T: TTDTypeInfo;
begin
  if V.Kind = evConst then
    Result := (V.CK in [ecInt, ecBool, ecChar, ecPtr]) or ((V.CK = ecStr) and (Length(V.S) = 1))
  else
    Result := TypeOf(V, T) and (T.Kind in [tkInteger, tkBoolean, tkChar, tkWideChar, tkEnum, tkPointer,
      tkClassRef, tkObject, tkInterface, tkProcedure, tkDynArray]);
end;

function TDbgEvaluator.IsStringValue(const V: TEvValue): Boolean;
var
  T, E: TTDTypeInfo;
begin
  Result := False;
  if V.Kind = evConst then
  begin
    Result := V.CK in [ecStr, ecChar];
    Exit;
  end;
  if not TypeOf(V, T) then Exit;
  case T.Kind of
    tkAnsiString, tkWideString, tkShortString, tkChar, tkWideChar: Result := True;
    tkPointer:
      Result := not T.IsRef and GetT(V.Info, T.ElemType, E) and (E.Kind in [tkChar, tkWideChar]);
  end;
end;

function TDbgEvaluator.LenAt(P: Cardinal): Cardinal;
begin
  // the length stored before the data of a long string or a dynamic array
  if not RdDWord(P - 4, Result) then Err(Format('Cannot read memory at $%.8x', [P - 4]));
end;

function TDbgEvaluator.ReadCStr(P: Cardinal; MaxLen: Integer; out Truncated: Boolean): string;
begin
  // a dangling PChar is an error, not an empty string
  if not ReadCString(FHost.ReadMem, P, MaxLen, Result, Truncated) then
    Err(Format('Cannot read memory at $%.8x', [P]));
end;

function TDbgEvaluator.ReadWStr(P: Cardinal; CharCount: Integer; ZeroTerm: Boolean; out Truncated: Boolean): string;
var
  W: WideString;
  Buf: array[0..127] of WideChar;
  N, Chunk, Total: Integer;
  Done: Boolean;
begin
  Truncated := False;
  W := '';
  Done := False;
  Total := 0;
  if not ZeroTerm and (CharCount > MAX_STR_DISPLAY) then
  begin
    CharCount := MAX_STR_DISPLAY;
    Truncated := True;
  end;
  while not Done do
  begin
    Chunk := SizeOf(Buf);
    N := $1000 - Integer(P and $FFF);
    if N < Chunk then Chunk := N and not 1;
    if Chunk <= 0 then Chunk := 2;
    if not ZeroTerm and (Chunk > (CharCount - Total) * 2) then Chunk := (CharCount - Total) * 2;
    if Chunk <= 0 then Break;
    if not FHost.ReadMem(P, Buf, Chunk) then
    begin
      // nothing readable is an error; a string running into an unreadable page is cut short
      if Total = 0 then Err(Format('Cannot read memory at $%.8x', [P]));
      Truncated := True;
      Break;
    end;
    { the characters of the chunk up to a #0, appended in one piece (a WideString has no spare
      room: each character on its own was a reallocation) }
    N := 0;
    while (N < Chunk div 2) and not (ZeroTerm and (Buf[N] = #0)) do Inc(N);
    Done := N < Chunk div 2;
    if N > 0 then
    begin
      SetLength(W, Total + N);
      Move(Buf[0], W[Total + 1], N * SizeOf(WideChar));
      Inc(Total, N);
    end;
    Inc(P, Chunk);
    if ZeroTerm and (Total >= MAX_STR_DISPLAY) then
    begin
      Truncated := True;
      Break;
    end;
    if not ZeroTerm and (Total >= CharCount) then Break;
  end;
  Result := WideToAnsi(W);
end;

function TDbgEvaluator.ReadLStr(P: Cardinal; MaxLen: Integer; out S: string; out Truncated: Boolean): Boolean;
var
  Len: Cardinal;
begin
  S := '';
  Truncated := False;
  Result := P = 0;               // nil is the empty string
  if Result or not RdDWord(P - 4, Len) then Exit;
  Truncated := Len > Cardinal(MaxLen);
  if Truncated then Len := MaxLen;
  SetLength(S, Len);
  Result := (Len = 0) or FHost.ReadMem(P, S[1], Len);
  if not Result then S := '';
end;

function TDbgEvaluator.ReadWideStr(P: Cardinal; out Truncated: Boolean): string;
begin
  Truncated := False;
  Result := '';
  // the length before the characters counts bytes
  if P <> 0 then Result := ReadWStr(P, LenAt(P) div 2, False, Truncated);
end;

function TDbgEvaluator.LoadShortStr(const V: TEvValue): string;
var
  B: Byte;
begin
  if V.Kind <> evMem then Err('Cannot read string');
  LoadRaw(V, B, 1);
  SetLength(Result, B);
  if (B > 0) and not FHost.ReadMem(V.Addr + 1, Result[1], B) then Err('Cannot read string');
end;

function TDbgEvaluator.ReadAnsiString(P: Cardinal; MaxLen: Integer): string;
var
  Trunc: Boolean;
begin
  ReadLStr(P, MaxLen, Result, Trunc);
end;

function TDbgEvaluator.LoadStr(const V: TEvValue): string;
var
  T: TTDTypeInfo;
  P: Cardinal;
  Trunc: Boolean;
begin
  Result := '';
  if V.Kind = evConst then
  begin
    case V.CK of
      ecStr: Result := V.S;
      ecChar: Result := Chr(V.I and $FF);
    else
      Err('String value expected');
    end;
    Exit;
  end;
  if not TypeOf(V, T) then Err('Unknown type');
  case T.Kind of
    tkAnsiString:
      if not ReadLStr(LoadPtr(V), 1024 * 1024, Result, Trunc) then Err('Cannot read string');
    tkShortString: Result := LoadShortStr(V);
    tkWideString: Result := ReadWideStr(LoadPtr(V), Trunc);
    tkChar: Result := Chr(LoadInt(V) and $FF);
    tkWideChar: Result := WideToAnsi(WideChar(LoadInt(V) and $FFFF));
    tkPointer:
      begin
        P := LoadPtr(V);
        if P <> 0 then
        begin
          if IsStringValue(V) and GetT(V.Info, T.ElemType, T) and (T.Kind = tkWideChar) then
            Result := ReadWStr(P, 0, True, Trunc)
          else
            Result := ReadCStr(P, 65536, Trunc);
        end;
      end;
  else
    Err('String value expected');
  end;
end;

function TDbgEvaluator.ReadVMTClassName(VMT: Cardinal): string;
var
  NamePtr: Cardinal;
  S: ShortString;
  I: Integer;
begin
  Result := '';
  if (VMT < $10000) or not RdDWord(VMT + Cardinal(vmtClassName), NamePtr) then Exit;
  if NamePtr < $10000 then Exit;
  S[0] := #0;
  if not FHost.ReadMem(NamePtr, S[0], 1) then Exit;
  if (S[0] = #0) or (Ord(S[0]) > 100) then Exit;
  if not FHost.ReadMem(NamePtr + 1, S[1], Ord(S[0])) then Exit;
  for I := 1 to Length(S) do
    if not (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
  Result := S;
end;

function TDbgEvaluator.ReadClassName(Obj: Cardinal): string;
var
  VMT: Cardinal;
begin
  Result := '';
  if (Obj < $10000) or not RdDWord(Obj, VMT) then Exit;
  Result := ReadVMTClassName(VMT);
end;

function TDbgEvaluator.InheritsFromName(Obj: Cardinal; const AClassName: string): Boolean;
var
  VMT, P: Cardinal;
  Guard: Integer;
begin
  Result := False;
  if (Obj < $10000) or not RdDWord(Obj, VMT) then Exit;
  Guard := 0;
  while (VMT >= $10000) and (Guard < 64) do
  begin
    Inc(Guard);
    if SameText(ReadVMTClassName(VMT), AClassName) then
    begin
      Result := True;
      Exit;
    end;
    // vmtParent holds a pointer to a variable containing the parent class
    if not RdDWord(VMT + Cardinal(vmtParent), P) or (P < $10000) then Exit;
    if not RdDWord(P, VMT) then Exit;
  end;
end;

{ value constructors }

function TDbgEvaluator.MemValue(Info: TTD32Info; Base, Addr, TypeIdx: Cardinal): TEvValue;
begin
  InitValue(Result);
  Result.Kind := evMem;
  Result.Info := Info;
  Result.Base := Base;
  Result.Addr := Addr;
  Result.TypeIdx := TypeIdx;
end;

function TDbgEvaluator.IntConst(I: Int64): TEvValue;
begin
  InitValue(Result);
  Result.Kind := evConst;
  Result.CK := ecInt;
  Result.I := I;
end;

function TDbgEvaluator.FloatConst(F: Extended): TEvValue;
begin
  InitValue(Result);
  Result.Kind := evConst;
  Result.CK := ecFloat;
  Result.F := F;
end;

function TDbgEvaluator.BoolConst(B: Boolean): TEvValue;
begin
  InitValue(Result);
  Result.Kind := evConst;
  Result.CK := ecBool;
  Result.I := Ord(B);
end;

function TDbgEvaluator.StrConst(const S: string): TEvValue;
begin
  InitValue(Result);
  Result.Kind := evConst;
  Result.CK := ecStr;
  Result.S := S;
end;

function TDbgEvaluator.AutoDeref(const V: TEvValue): TEvValue;
var
  T: TTDTypeInfo;
  P, H: Cardinal;
begin
  Result := V;
  if (V.Kind in [evMem, evReg]) and TypeOf(V, T) then
  begin
    if (T.Kind = tkPointer) and T.IsRef then
    begin
      P := LoadPtr(V);
      Result := MemValue(V.Info, V.Base, P, T.ElemType);
    end
    else if (T.Kind = tkOpenArray) and (V.Kind = evMem) and (T.Leaf = LF_POINTER) then
    begin
      // open array parameter: the hidden High value sits in the next lower stack slot
      if RdDWord(V.Addr - 4, H) and (Integer(H) >= -1) and (Integer(H) < $1000000) then
      begin
        Result.HighKnown := True;
        Result.HighValue := Integer(H);
      end;
    end;
  end;
end;

function TDbgEvaluator.SymValue(Info: TTD32Info; Base: Cardinal; const Sym: TTDSymbol; EBP, EIP: Cardinal;
  Top: Boolean): TEvValue;
var
  I, Reg: Integer;
  Nm: string;
begin
  InitValue(Result);
  Result.Info := Info;
  Result.Base := Base;
  Result.TypeIdx := Sym.TypeIdx;
  Nm := Info.NameStr(Sym.NameIdx);
  case Sym.Kind of
    S_BPREL32:
      begin
        Result.Kind := evMem;
        Result.Addr := EBP + Cardinal(Sym.Offset);
      end;
    S_REGISTER:
      begin
        if not Top then
          Err(Format('"%s" is held in a register and is not available in this stack frame', [Nm]));
        Reg := Sym.Reg;
        if Reg = 0 then
          for I := 0 to High(Sym.Ranges) do
            if (EIP - Base >= Sym.Ranges[I].Start) and (EIP - Base < Sym.Ranges[I].Start + Sym.Ranges[I].Len) then
            begin
              Reg := Sym.Ranges[I].Reg;
              Break;
            end;
        if Reg = 0 then
          Err(Format('"%s" is not available here (eliminated by the optimizer)', [Nm]));
        Result.Kind := evReg;
        Result.Reg := Reg;
      end;
    S_LDATA32, S_GDATA32, S_PUB32:
      begin
        Result.Kind := evMem;
        Result.Addr := Base + Cardinal(Sym.Offset);
      end;
    S_PCONSTANT, S_CONST:
      begin
        Result.Kind := evConst;
        Result.CK := ecInt;
        Result.I := Sym.Value;
      end;
  else
    Err(Format('"%s" cannot be evaluated', [Nm]));
  end;
  Result := AutoDeref(Result);
end;

{ symbol lookup }

function TDbgEvaluator.PickLocal(const Name: string; const Syms: TTDSymbolArray; out Index: Integer): Boolean;
var
  I, Count, First, J, Best: Integer;
  Cand: array[0..31] of Integer;
  Code: array of Byte;
  ProcStart, EIP, BestAddr, A: Cardinal;
  Len, D: Integer;
begin
  Index := -1;
  Count := 0;
  First := -1;
  for I := 0 to High(Syms) do
    if ((Syms[I].Kind = S_BPREL32) or (Syms[I].Kind = S_REGISTER) or (Syms[I].Kind = S_LDATA32) or
      (Syms[I].Kind = S_PCONSTANT) or (Syms[I].Kind = S_CONST)) and
      FFrameInfo.NameEquals(Syms[I].NameIdx, Name) then
    begin
      if First < 0 then First := I;
      if Count < 32 then
      begin
        Cand[Count] := I;
        Inc(Count);
      end;
    end;
  Result := First >= 0;
  if not Result then Exit;
  Index := First;
  if Count < 2 then Exit;
  // Several locals share the name (typically "E" of several "on E: ..." handlers, which the
  // compiler does not put into separate scopes). Pick the one whose stack slot was written
  // last before the current location: mov [ebp+d],eax = 89 45 dd | 89 85 dddddddd.
  if (FFrameProc < 0) or (FFrameInfo = nil) then Exit;
  ProcStart := FFrameBase + FFrameInfo.Procs[FFrameProc]^.Start;
  EIP := FHost.FrameEIP;
  if (EIP <= ProcStart) or (EIP - ProcStart > $40000) then Exit;
  Len := EIP - ProcStart;
  SetLength(Code, Len + 8);
  if not FHost.ReadMem(ProcStart, Code[0], Len) then Exit;
  Best := -1;
  BestAddr := 0;
  for J := 0 to Count - 1 do
    if Syms[Cand[J]].Kind = S_BPREL32 then
    begin
      D := Syms[Cand[J]].Offset;
      A := 0;
      I := 0;
      while I < Len - 2 do
      begin
        if Code[I] = $89 then
        begin
          if (D >= -128) and (D <= 127) and (Code[I + 1] = $45) and (ShortInt(Code[I + 2]) = D) then
            A := ProcStart + Cardinal(I)
          else if (Code[I + 1] = $85) and (I < Len - 5) and (PInteger(@Code[I + 2])^ = D) then
            A := ProcStart + Cardinal(I);
        end;
        Inc(I);
      end;
      if (A <> 0) and (A >= BestAddr) then
      begin
        BestAddr := A;
        Best := Cand[J];
      end;
    end;
  if Best >= 0 then Index := Best;
end;

function TDbgEvaluator.LookupLocal(const Name: string; out V: TEvValue): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  InitValue(V);
  if (FFrameInfo = nil) or (FFrameProc < 0) then Exit;
  if not PickLocal(Name, FFrameSyms, Idx) then Exit;
  V := SymValue(FFrameInfo, FFrameBase, FFrameSyms[Idx], FHost.FrameEBP, FHost.FrameEIP, FHost.IsTopFrame);
  Result := True;
end;

function TDbgEvaluator.LookupWith(const Name: string; Heuristic: Boolean; out V: TEvValue): Boolean;
var
  I, J, N: Integer;
  Order: array[0..31] of Integer;
  T: Integer;
  RVA: Cardinal;
  W: TEvValue;
  WName: string;
  TI: TTDTypeInfo;
  Swap: Boolean;
begin
  Result := False;
  InitValue(V);
  if (FFrameInfo = nil) or (FFrameProc < 0) then Exit;
  RVA := FHost.FrameEIP - FFrameBase;
  N := 0;
  for I := 0 to High(FFrameSyms) do
    if (FFrameSyms[I].Kind = S_WITH32) and (N < 32) then
    begin
      if not Heuristic then
      begin
        if (RVA < FFrameSyms[I].ScopeStart) or (RVA >= FFrameSyms[I].ScopeStart + FFrameSyms[I].ScopeLen) then
          Continue;
      end
      else
      begin
        // When the with-expression needs a temporary pointer the compiler records only the
        // range of the code that sets the temporary up, not the body of the statement.
        // Fallback: any such scope whose set-up code lies before the current location.
        WName := FFrameInfo.NameStr(FFrameSyms[I].NameIdx);
        if (WName = '') or (WName[1] <> '$') then Continue;
        if RVA < FFrameSyms[I].ScopeStart + FFrameSyms[I].ScopeLen then Continue;
      end;
      Order[N] := I;
      Inc(N);
    end;
  // exact scopes: innermost (smallest range) first; fallback scopes: most recent first
  for I := 0 to N - 2 do
    for J := I + 1 to N - 1 do
    begin
      if Heuristic then
        Swap := FFrameSyms[Order[J]].ScopeStart > FFrameSyms[Order[I]].ScopeStart
      else
        Swap := FFrameSyms[Order[J]].ScopeLen < FFrameSyms[Order[I]].ScopeLen;
      if Swap then
      begin
        T := Order[I];
        Order[I] := Order[J];
        Order[J] := T;
      end;
    end;
  for I := 0 to N - 1 do
  begin
    WName := FFrameInfo.NameStr(FFrameSyms[Order[I]].NameIdx);
    try
      if not LookupLocal(WName, W) then
        if not LookupParents(WName, W) then
          if not LookupGlobal(WName, nil, 0, -1, W) then Continue;
      // a compiler temporary holds a pointer to the with-target
      if TypeOf(W, TI) and (TI.Kind = tkPointer) then
        W := MemValue(W.Info, W.Base, LoadPtr(W), FFrameSyms[Order[I]].TypeIdx);
      if FindMember(W, Name, V) then
      begin
        Result := True;
        Exit;
      end;
    except
      on EDbgEval do ;   // try the next scope
    end;
  end;
end;

function TDbgEvaluator.LookupSelf(const Name: string; out V: TEvValue): Boolean;
var
  SelfV: TEvValue;
begin
  Result := False;
  InitValue(V);
  if SameText(Name, 'Self') then Exit;
  try
    if not LookupLocal('Self', SelfV) then
      if not LookupParents('Self', SelfV) then Exit;
    Result := FindMember(SelfV, Name, V);
  except
    on EDbgEval do Result := False;
  end;
end;

function TDbgEvaluator.LookupParents(const Name: string; out V: TEvValue): Boolean;
var
  P: PTDProc;
  EBP, ParentEBP: Cardinal;
  Syms: TTDSymbolArray;
  I, PI, Guard, Link, Idx: Integer;
  Found: Boolean;
begin
  Result := False;
  InitValue(V);
  if (FFrameInfo = nil) or (FFrameProc < 0) then Exit;
  P := FFrameInfo.Procs[FFrameProc];
  EBP := FHost.FrameEBP;
  Syms := FFrameSyms;
  Guard := 0;
  while (P <> nil) and (P^.ParentOfs <> 0) and (Guard < 16) do
  begin
    Inc(Guard);
    Found := False;
    Link := 0;
    for I := 0 to High(Syms) do
      if Syms[I].Kind = S_SLINK32 then
      begin
        Link := Syms[I].Offset;
        Found := True;
        Break;
      end;
    if not Found then Exit;
    if not RdDWord(EBP + Cardinal(Link), ParentEBP) then Exit;
    PI := FFrameInfo.ProcByRecOfs(P^.ParentOfs);
    if PI < 0 then Exit;
    FFrameInfo.GetProcSymbols(PI, Syms);
    Idx := -1;
    for I := 0 to High(Syms) do
      if (Syms[I].Kind = S_BPREL32) and FFrameInfo.NameEquals(Syms[I].NameIdx, Name) then
      begin
        Idx := I;
        Break;
      end;
    if Idx >= 0 then
    begin
      V := SymValue(FFrameInfo, FFrameBase, Syms[Idx], ParentEBP, 0, False);
      Result := True;
      Exit;
    end;
    P := FFrameInfo.Procs[PI];
    EBP := ParentEBP;
  end;
end;

function TDbgEvaluator.LookupGlobal(const Name: string; OnlyInfo: TTD32Info; OnlyBase: Cardinal;
  OnlyModule: Integer; out V: TEvValue): Boolean;
var
  Sym: TTDSymbol;
  M, I: Integer;
  Info: TTD32Info;
  Base: Cardinal;
begin
  Result := False;
  InitValue(V);
  if OnlyInfo <> nil then
  begin
    // unit qualified: only that module (loaded at OnlyBase)
    if OnlyInfo.FindGlobal(Name, OnlyModule, True, Sym, M) then
    begin
      V := SymValue(OnlyInfo, OnlyBase, Sym, 0, 0, False);
      Result := True;
    end;
    Exit;
  end;
  if (FFrameInfo <> nil) and FFrameInfo.FindGlobal(Name, FFrameModule, False, Sym, M) then
  begin
    V := SymValue(FFrameInfo, FFrameBase, Sym, 0, 0, False);
    Result := True;
    Exit;
  end;
  for I := 0 to FHost.InfoCount - 1 do
    if FHost.GetInfo(I, Info, Base) and (Info <> nil) and (Info <> FFrameInfo) and
      Info.FindGlobal(Name, -1, False, Sym, M) then
    begin
      V := SymValue(Info, Base, Sym, 0, 0, False);
      Result := True;
      Exit;
    end;
end;

function TDbgEvaluator.LookupType(const Name: string; out V: TEvValue): Boolean;
const
  BuiltIn: array[0..24] of record N: string; T: Cardinal end = (
    (N: 'Integer'; T: T_INT4), (N: 'Longint'; T: T_INT4), (N: 'Cardinal'; T: T_UINT4),
    (N: 'LongWord'; T: T_UINT4), (N: 'DWORD'; T: T_UINT4), (N: 'Byte'; T: T_UCHAR),
    (N: 'Word'; T: T_UINT2), (N: 'Smallint'; T: T_INT2), (N: 'Shortint'; T: T_CHAR),
    (N: 'Int64'; T: T_INT8), (N: 'Char'; T: T_PASCHAR), (N: 'AnsiChar'; T: T_PASCHAR),
    (N: 'WideChar'; T: T_WCHAR), (N: 'Boolean'; T: T_BOOL08), (N: 'Single'; T: T_REAL32),
    (N: 'Double'; T: T_REAL64), (N: 'Real'; T: T_REAL64), (N: 'Extended'; T: T_REAL80),
    (N: 'Currency'; T: T_CURRENCY), (N: 'Pointer'; T: T_PVOID), (N: 'PChar'; T: T_PPASCHAR),
    (N: 'PAnsiChar'; T: T_PPASCHAR), (N: 'PWideChar'; T: T_PWCHAR), (N: 'Real48'; T: T_REAL48),
    (N: 'Comp'; T: T_INT8));
var
  I: Integer;
  Idx: Cardinal;
  Info: TTD32Info;
  Base: Cardinal;
begin
  Result := False;
  InitValue(V);
  for I := Low(BuiltIn) to High(BuiltIn) do
    if SameText(BuiltIn[I].N, Name) then
    begin
      V.Kind := evType;
      V.Info := FFrameInfo;
      V.Base := FFrameBase;
      V.TypeIdx := BuiltIn[I].T;
      Result := True;
      Exit;
    end;
  if (FFrameInfo <> nil) and FFrameInfo.FindUDT(Name, FFrameModule, Idx) then
  begin
    V.Kind := evType;
    V.Info := FFrameInfo;
    V.Base := FFrameBase;
    V.TypeIdx := Idx;
    Result := True;
    Exit;
  end;
  for I := 0 to FHost.InfoCount - 1 do
    if FHost.GetInfo(I, Info, Base) and (Info <> nil) and (Info <> FFrameInfo) and Info.FindUDT(Name, -1, Idx) then
    begin
      V.Kind := evType;
      V.Info := Info;
      V.Base := Base;
      V.TypeIdx := Idx;
      Result := True;
      Exit;
    end;
end;

function TDbgEvaluator.LookupUnit(const Name: string; out V: TEvValue): Boolean;
var
  I, M: Integer;
  Info: TTD32Info;
  Base: Cardinal;
begin
  Result := False;
  InitValue(V);
  for I := 0 to FHost.InfoCount - 1 do
    if FHost.GetInfo(I, Info, Base) and (Info <> nil) then
    begin
      M := Info.FindModule(Name);
      if M >= 0 then
      begin
        V.Kind := evUnit;
        V.Info := Info;
        V.Base := Base;
        V.ModIdx := M;
        Result := True;
        Exit;
      end;
    end;
end;

function TDbgEvaluator.LookupRegister(const Name: string; out V: TEvValue): Boolean;
const
  Names: array[0..23] of string = ('AL', 'CL', 'DL', 'BL', 'AH', 'CH', 'DH', 'BH', 'AX', 'CX', 'DX', 'BX',
    'SP', 'BP', 'SI', 'DI', 'EAX', 'ECX', 'EDX', 'EBX', 'ESP', 'EBP', 'ESI', 'EDI');
var
  I: Integer;
begin
  Result := False;
  InitValue(V);
  for I := 0 to High(Names) do
    if SameText(Names[I], Name) then
    begin
      V.Kind := evReg;
      V.Reg := I + 1;
      if I < 8 then
        V.TypeIdx := T_UCHAR
      else if I < 16 then
        V.TypeIdx := T_UINT2
      else
        V.TypeIdx := T_UINT4;
      Result := True;
      Exit;
    end;
  if SameText(Name, 'EIP') then
  begin
    V.Kind := evReg;
    V.Reg := 33;
    V.TypeIdx := T_UINT4;
    Result := True;
  end
  else if SameText(Name, 'EFLAGS') then
  begin
    V.Kind := evReg;
    V.Reg := 34;
    V.TypeIdx := T_UINT4;
    Result := True;
  end;
end;

function TDbgEvaluator.ResolveIdent(const Name: string): TEvValue;
begin
  if not FFrameReady then InitFrame;
  if LookupWith(Name, False, Result) then Exit;
  if LookupLocal(Name, Result) then Exit;
  if LookupParents(Name, Result) then Exit;
  if LookupSelf(Name, Result) then Exit;
  if LookupGlobal(Name, nil, 0, -1, Result) then Exit;
  if LookupWith(Name, True, Result) then Exit;
  if LookupType(Name, Result) then Exit;
  if LookupUnit(Name, Result) then Exit;
  if LookupRegister(Name, Result) then Exit;
  if FAllowCalls and LookupRoutine(Name, Result) then Exit;
  Err(Format('Undeclared identifier: "%s"', [Name]));
end;

function TDbgEvaluator.DynamicClass(Info: TTD32Info; Obj: Cardinal; out ClassIdx: Cardinal): Boolean;
var
  Nm: string;
begin
  Result := False;
  ClassIdx := 0;
  if Info = nil then Exit;
  Nm := ReadClassName(Obj);
  if Nm = '' then Exit;
  if (FDynInfo = Info) and (FDynName = Nm) then
  begin
    ClassIdx := FDynIdx;
    Result := ClassIdx <> 0;
    Exit;
  end;
  FDynInfo := Info;
  FDynName := Nm;
  FDynIdx := 0;
  if Info.FindClassType(Nm, ClassIdx) then
  begin
    FDynIdx := ClassIdx;
    Result := True;
  end;
end;

function TDbgEvaluator.SearchClass(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal;
  const Name: string; out R: TEvValue; Depth: Integer): Boolean;
var
  CT, PT: TTDTypeInfo;
  Fields: TTDFieldArray;
  I: Integer;
  Attr: Word;
  Exp: string;
begin
  Result := False;
  InitValue(R);
  if (Info = nil) or (Depth > 32) then Exit;
  if Depth = 0 then FTopClass := ClassIdx;
  if not Info.GetType(ClassIdx, CT) or not Info.GetFields(CT.FieldList, Fields) then Exit;
  for I := 0 to High(Fields) do
    if (Fields[I].NameIdx <> 0) and Info.NameEquals(Fields[I].NameIdx, Name) then
      case Fields[I].Kind of
        fdMember:
          begin
            R := MemValue(Info, Base, Addr + Cardinal(Fields[I].Offset), Fields[I].TypeIdx);
            Result := True;
            Exit;
          end;
        fdProperty:
          begin
            if not Info.GetType(Fields[I].TypeIdx, PT) then Err('Bad property information');
            if (PT.PropFlags and PROPF_GETMETHOD) <> 0 then
            begin
              if not FAllowCalls then
                Err(Format('Property "%s" is read through the method %s; evaluating it calls code ' +
                  'in the program (Evaluate/Modify does)', [Name, CleanProcName(Info.NameStr(PT.PropGet))]));
              { called now - an array property's getter when its index follows (ParsePostfix) }
              R := GetterCall(Info, Base, FTopClass, Addr, Info.NameStr(PT.PropGet), PT.ElemType, ClassIdx);
              if not R.HighKnown then R := CallValue(R, []);
              Result := True;
              Exit;
            end;
            R := MemValue(Info, Base, Addr + PT.PropGet, PT.ElemType);
            Result := True;
            Exit;
          end;
        fdMethod:
          begin
            if not FAllowCalls then
              Err(Format('"%s" is a method; calling it runs code in the program (Evaluate/Modify does)', [Name]));
            InitValue(R);
            R.Kind := evCall;
            R.Info := Info;
            R.Base := Base;
            R.I := Addr;
            R.Reg := 1;
            R.S := Name;
            if not Info.MethodEntry(Fields[I].TypeIdx, Attr, R.TypeIdx) then R.TypeIdx := 0;
            if Attr and (MA_CONSTRUCTOR or MA_DESTRUCTOR) <> 0 then
              Err(Format('"%s" is a constructor or destructor: it is not called by the evaluator', [Name]));
            CodeOf(Info, FTopClass, Name, R, Exp);
            Result := True;
            Exit;
          end;
      end;
  for I := 0 to High(Fields) do
    if Fields[I].Kind = fdBaseClass then
      if SearchClass(Info, Base, Fields[I].TypeIdx, Addr + Cardinal(Fields[I].Offset), Name, R, Depth + 1) then
      begin
        Result := True;
        Exit;
      end;
end;

function TDbgEvaluator.FindMember(const V: TEvValue; const Name: string; out R: TEvValue): Boolean;
var
  T, E: TTDTypeInfo;
  P, Dyn: Cardinal;
begin
  Result := False;
  InitValue(R);
  if V.Kind = evUnit then
  begin
    Result := LookupGlobal(Name, V.Info, V.Base, V.ModIdx, R);
    if not Result then
    begin
      // a type declared in that unit
      if V.Info.FindUDT(Name, V.ModIdx, P) then
      begin
        R.Kind := evType;
        R.Info := V.Info;
        R.Base := V.Base;
        R.TypeIdx := P;
        Result := True;
      end;
    end;
    Exit;
  end;
  if not (V.Kind in [evMem, evReg, evConst]) or not TypeOf(V, T) then Exit;
  case T.Kind of
    tkRecord, tkClass:
      if V.Kind = evMem then
        Result := SearchClass(V.Info, V.Base, V.TypeIdx, V.Addr, Name, R, 0);
    tkObject, tkInterface:
      begin
        P := LoadPtr(V);
        if P = 0 then Err(Format('Cannot access "%s": the object reference is nil', [Name]));
        if (T.Kind = tkObject) and DynamicClass(V.Info, P, Dyn) and (Dyn <> T.ElemType) and
          SearchClass(V.Info, V.Base, Dyn, P, Name, R, 0) then
          Result := True
        else
          Result := SearchClass(V.Info, V.Base, T.ElemType, P, Name, R, 0);
      end;
    tkPointer:
      if GetT(V.Info, T.ElemType, E) and (E.Kind in [tkRecord, tkClass, tkObject]) then
      begin
        P := LoadPtr(V);
        if P = 0 then Err(Format('Cannot access "%s": the pointer is nil', [Name]));
        Result := FindMember(MemValue(V.Info, V.Base, P, T.ElemType), Name, R);
      end;
  end;
end;

{ operations }

function TDbgEvaluator.Deref(const V: TEvValue): TEvValue;
var
  T, E: TTDTypeInfo;
  P: Cardinal;
begin
  if not (V.Kind in [evMem, evReg, evConst]) or not TypeOf(V, T) then Err('Pointer value expected before "^"');
  case T.Kind of
    tkPointer:
      begin
        if not GetT(V.Info, T.ElemType, E) or (E.Kind = tkVoid) then
          Err('Cannot dereference an untyped pointer; use a typecast, e.g. PInteger(p)^');
        P := LoadPtr(V);
        if P = 0 then Err('Cannot dereference a nil pointer');
        Result := MemValue(V.Info, V.Base, P, T.ElemType);
      end;
    tkObject, tkInterface:
      begin
        P := LoadPtr(V);
        if P = 0 then Err('Cannot dereference a nil reference');
        Result := MemValue(V.Info, V.Base, P, T.ElemType);
      end;
  else
    Err('Pointer value expected before "^"');
  end;
end;

function TDbgEvaluator.IndexValue(const V: TEvValue; Index: Int64): TEvValue;
var
  T: TTDTypeInfo;
  ES: Integer;
  P, Len: Cardinal;
  B: Byte;
begin
  if not (V.Kind in [evMem, evReg, evConst]) or not TypeOf(V, T) then Err('Array or string expected before "["');
  case T.Kind of
    tkArray:
      begin
        if V.Kind <> evMem then Err('Array expected before "["');
        ES := SizeOfType(V.Info, T.ElemType);
        if (T.Count > 0) and (T.Size > 0) then ES := T.Size div T.Count;
        if ES <= 0 then Err('Unknown array element size');
        if (Index < T.Low) or (Index > T.High) then
          Err(Format('Index %d is out of bounds (%d..%d)', [Index, T.Low, T.High]));
        Result := MemValue(V.Info, V.Base, V.Addr + Cardinal((Index - T.Low) * ES), T.ElemType);
      end;
    tkDynArray:
      begin
        P := LoadPtr(V);
        if P = 0 then Err('The dynamic array is empty (nil)');
        Len := LenAt(P);
        if (Index < 0) or (Index >= Len) then
          Err(Format('Index %d is out of bounds (0..%d)', [Index, Integer(Len) - 1]));
        ES := SizeOfType(V.Info, T.ElemType);
        if ES <= 0 then Err('Unknown array element size');
        Result := MemValue(V.Info, V.Base, P + Cardinal(Index * ES), T.ElemType);
      end;
    tkOpenArray:
      begin
        if T.Leaf = LF_POINTER then P := LoadPtr(V) else P := V.Addr;
        if P = 0 then Err('The open array is nil');
        if V.HighKnown and ((Index < 0) or (Index > V.HighValue)) then
          Err(Format('Index %d is out of bounds (0..%d)', [Index, V.HighValue]));
        ES := SizeOfType(V.Info, T.ElemType);
        if ES <= 0 then Err('Unknown array element size');
        Result := MemValue(V.Info, V.Base, P + Cardinal(Index * ES), T.ElemType);
      end;
    tkAnsiString:
      begin
        P := LoadPtr(V);
        Len := 0;
        if P <> 0 then Len := LenAt(P);
        if (Index < 1) or (Index > Len) then
          Err(Format('String index %d is out of bounds (1..%d)', [Index, Len]));
        Result := MemValue(V.Info, V.Base, P + Cardinal(Index - 1), T_PASCHAR);
      end;
    tkWideString:
      begin
        P := LoadPtr(V);
        Len := 0;
        if P <> 0 then Len := LenAt(P) div 2;
        if (Index < 1) or (Index > Len) then
          Err(Format('String index %d is out of bounds (1..%d)', [Index, Len]));
        Result := MemValue(V.Info, V.Base, P + Cardinal((Index - 1) * 2), T_WCHAR);
      end;
    tkShortString:
      begin
        if V.Kind <> evMem then Err('String expected before "["');
        LoadRaw(V, B, 1);
        if (Index < 0) or (Index > B) then
          Err(Format('String index %d is out of bounds (0..%d)', [Index, B]));
        Result := MemValue(V.Info, V.Base, V.Addr + Cardinal(Index), T_PASCHAR);
      end;
    tkPointer:
      begin
        ES := SizeOfType(V.Info, T.ElemType);
        if ES <= 0 then Err('Cannot index an untyped pointer');
        P := LoadPtr(V);
        if P = 0 then Err('Cannot index a nil pointer');
        Result := MemValue(V.Info, V.Base, P + Cardinal(Index * ES), T.ElemType);
      end;
  else
    Err('Array or string expected before "["');
  end;
end;

function TDbgEvaluator.CastValue(const T, V: TEvValue): TEvValue;
var
  TT, VT: TTDTypeInfo;
  SrcOrd, DstOrd: Boolean;
  X: Int64;
begin
  if not GetT(T.Info, T.TypeIdx, TT) then Err('Unknown type in typecast');
  if not (V.Kind in [evMem, evReg, evConst]) then Err('Invalid typecast');
  DstOrd := TT.Kind in [tkInteger, tkBoolean, tkChar, tkWideChar, tkEnum, tkPointer, tkClassRef, tkObject,
    tkInterface, tkProcedure, tkDynArray];
  SrcOrd := IsOrdinalValue(V);
  if DstOrd and SrcOrd then
  begin
    // value cast between ordinal / pointer types
    X := LoadInt(V);
    case TT.Size of
      1: if TT.Signed then X := ShortInt(X and $FF) else X := X and $FF;
      2: if TT.Signed then X := SmallInt(X and $FFFF) else X := X and $FFFF;
      4: if TT.Signed and (TT.Kind = tkInteger) then X := Integer(X and $FFFFFFFF) else X := X and $FFFFFFFF;
    end;
    InitValue(Result);
    Result.Kind := evConst;
    Result.CK := ecInt;
    Result.I := X;
    Result.Info := T.Info;
    Result.Base := T.Base;
    Result.TypeIdx := T.TypeIdx;
    Exit;
  end;
  if (TT.Kind in [tkFloat, tkCurrency]) and (V.Kind = evConst) then
  begin
    Result := FloatConst(LoadFloat(V));
    Exit;
  end;
  if V.Kind = evMem then
  begin
    // reinterpret the storage
    if TypeOf(V, VT) and (VT.Size > 0) and (TT.Size > VT.Size) then
      Err('Invalid typecast: the target type is larger than the value');
    Result := MemValue(T.Info, T.Base, V.Addr, T.TypeIdx);
    Exit;
  end;
  Err('Invalid typecast');
end;

function TDbgEvaluator.AddressOf(const V: TEvValue): TEvValue;
begin
  if V.Kind <> evMem then Err('Variable expected after "@"');
  InitValue(Result);
  Result.Kind := evConst;
  Result.CK := ecPtr;
  Result.I := V.Addr;
end;

function TDbgEvaluator.InSet(const L, R: TEvValue): TEvValue;
var
  T: TTDTypeInfo;
  X: Int64;
  Bits: array[0..31] of Byte;
  Bit: Int64;
begin
  if (R.Kind <> evMem) or not TypeOf(R, T) or (T.Kind <> tkSet) then Err('Set expected after "in"');
  X := LoadInt(L);
  FillChar(Bits, SizeOf(Bits), 0);
  if (T.Size < 1) or (T.Size > 32) then Err('Unsupported set size');
  LoadRaw(R, Bits, T.Size);
  Bit := X - Int64(T.SetLowByte) * 8;
  if (Bit < 0) or (Bit >= T.Size * 8) then
    Result := BoolConst(False)
  else
    Result := BoolConst((Bits[Bit shr 3] and (1 shl (Bit and 7))) <> 0);
end;

function TDbgEvaluator.Compare(const Op: string; const L, R: TEvValue): TEvValue;
var
  C: Integer;
  A, B: Extended;
  X, Y: Int64;
  LS, RS: Boolean;
begin
  LS := IsStringValue(L);
  RS := IsStringValue(R);
  // a single character against a single character compares as ordinals
  if LS and RS and not (IsOrdinalValue(L) and IsOrdinalValue(R)) then
    C := CompareStr(LoadStr(L), LoadStr(R))
  else if IsFloatValue(L) or IsFloatValue(R) then
  begin
    A := LoadFloat(L);
    B := LoadFloat(R);
    if A < B then C := -1 else if A > B then C := 1 else C := 0;
  end
  else
  begin
    X := LoadInt(L);
    Y := LoadInt(R);
    if X < Y then C := -1 else if X > Y then C := 1 else C := 0;
  end;
  if Op = '=' then Result := BoolConst(C = 0)
  else if Op = '<>' then Result := BoolConst(C <> 0)
  else if Op = '<' then Result := BoolConst(C < 0)
  else if Op = '>' then Result := BoolConst(C > 0)
  else if Op = '<=' then Result := BoolConst(C <= 0)
  else Result := BoolConst(C >= 0);
end;

function TDbgEvaluator.BinaryOp(const Op: string; const L, R: TEvValue): TEvValue;

  function IsBool(const V: TEvValue): Boolean;
  var
    T: TTDTypeInfo;
  begin
    if V.Kind = evConst then
      Result := V.CK = ecBool
    else
      Result := TypeOf(V, T) and (T.Kind = tkBoolean);
  end;

var
  X, Y: Int64;
  A, B: Extended;
  C: Cardinal;
  W: Integer;
  Signed: Boolean;
begin
  if (Op = '+') and IsStringValue(L) and IsStringValue(R) then
  begin
    Result := StrConst(LoadStr(L) + LoadStr(R));
    Exit;
  end;
  if (Op = 'and') or (Op = 'or') or (Op = 'xor') then
  begin
    X := LoadInt(L);
    Y := LoadInt(R);
    if IsBool(L) and IsBool(R) then
    begin
      if Op = 'and' then Result := BoolConst((X <> 0) and (Y <> 0))
      else if Op = 'or' then Result := BoolConst((X <> 0) or (Y <> 0))
      else Result := BoolConst((X <> 0) xor (Y <> 0));
    end
    else if Op = 'and' then Result := IntConst(X and Y)
    else if Op = 'or' then Result := IntConst(X or Y)
    else Result := IntConst(X xor Y);
    Exit;
  end;
  if (Op = '/') or IsFloatValue(L) or IsFloatValue(R) then
  begin
    if (Op = 'div') or (Op = 'mod') or (Op = 'shl') or (Op = 'shr') then
      Err('Operator "' + Op + '" needs integer operands');
    A := LoadFloat(L);
    B := LoadFloat(R);
    if Op = '+' then Result := FloatConst(A + B)
    else if Op = '-' then Result := FloatConst(A - B)
    else if Op = '*' then Result := FloatConst(A * B)
    else
    begin
      if B = 0 then Err('Division by zero');
      Result := FloatConst(A / B);
    end;
    Exit;
  end;
  X := LoadInt(L);
  Y := LoadInt(R);
  if Op = '+' then Result := IntConst(X + Y)
  else if Op = '-' then Result := IntConst(X - Y)
  else if Op = '*' then Result := IntConst(X * Y)
  else if Op = 'div' then
  begin
    if Y = 0 then Err('Division by zero');
    Result := IntConst(X div Y);
  end
  else if Op = 'mod' then
  begin
    if Y = 0 then Err('Division by zero');
    Result := IntConst(X mod Y);
  end
  else if (Op = 'shl') or (Op = 'shr') then
  begin
    // in the left operand's type, as Delphi computes it: Int64 for 8 bytes, else 32 bits -
    // Cardinal for an unsigned 4-byte value, Integer for the rest (Byte, Word ... are promoted)
    W := OrdWidth(L, X, Signed);
    if W = 8 then
    begin
      if Op = 'shl' then X := X shl (Y and 63) else X := X shr (Y and 63);
      Result := IntConst(X);
    end
    else
    begin
      if W < 4 then Signed := True;
      if Op = 'shl' then C := Cardinal(X) shl (Y and 31) else C := Cardinal(X) shr (Y and 31);
      if Signed then Result := IntConst(Integer(C)) else Result := IntConst(C);
    end;
  end
  else
    Err('Unknown operator ' + Op);
end;

function TDbgEvaluator.CallIntrinsic(const Name: string; var Handled: Boolean): TEvValue;
var
  A: TEvValue;
  T: TTDTypeInfo;
  P, Len: Cardinal;
  B: Byte;
  Which: Integer;
begin
  Handled := True;
  InitValue(Result);
  if SameText(Name, 'Length') then Which := 0
  else if SameText(Name, 'High') then Which := 1
  else if SameText(Name, 'Low') then Which := 2
  else if SameText(Name, 'Ord') then Which := 3
  else if SameText(Name, 'Chr') then Which := 4
  else if SameText(Name, 'SizeOf') then Which := 5
  else if SameText(Name, 'Assigned') then Which := 6
  else if SameText(Name, 'Abs') then Which := 7
  else if SameText(Name, 'Trunc') then Which := 8
  else if SameText(Name, 'Round') then Which := 9
  else if SameText(Name, 'Odd') then Which := 10
  else if SameText(Name, 'Addr') then Which := 11
  else
  begin
    Handled := False;
    Exit;
  end;
  // only an intrinsic when followed by '('
  if not IsSym('(') then
  begin
    Handled := False;
    Exit;
  end;
  NextTok;
  A := ParseExpr;
  Expect(')');
  case Which of
    0, 1, 2:
      begin
        if A.Kind = evType then
        begin
          if not GetT(A.Info, A.TypeIdx, T) then Err('Unknown type');
          case T.Kind of
            tkArray, tkEnum:
              if Which = 0 then Result := IntConst(T.High - T.Low + 1)
              else if Which = 1 then Result := IntConst(T.High)
              else Result := IntConst(T.Low);
            tkInteger, tkChar, tkBoolean:
              if T.Leaf = LF_SUBRANGE then
              begin
                if Which = 1 then Result := IntConst(T.High) else Result := IntConst(T.Low);
              end
              else
                Err('Low/High of this type is not supported');
          else
            Err('Array or ordinal type expected');
          end;
          Exit;
        end;
        if A.Kind = evConst then
        begin
          if A.CK in [ecStr, ecChar] then
          begin
            if Which = 0 then Result := IntConst(Length(LoadStr(A)))
            else Err('Variable expected');
            Exit;
          end;
          Err('Array or string expected');
        end;
        if not TypeOf(A, T) then Err('Unknown type');
        case T.Kind of
          tkArray:
            if Which = 0 then Result := IntConst(T.Count)
            else if Which = 1 then Result := IntConst(T.High)
            else Result := IntConst(T.Low);
          tkDynArray:
            begin
              P := LoadPtr(A);
              Len := 0;
              if P <> 0 then Len := LenAt(P);
              if Which = 0 then Result := IntConst(Len)
              else if Which = 1 then Result := IntConst(Int64(Len) - 1)
              else Result := IntConst(0);
            end;
          tkOpenArray:
            begin
              if not A.HighKnown then Err('The size of the open array is not known');
              if Which = 0 then Result := IntConst(A.HighValue + 1)
              else if Which = 1 then Result := IntConst(A.HighValue)
              else Result := IntConst(0);
            end;
          tkAnsiString, tkWideString:
            begin
              P := LoadPtr(A);
              Len := 0;
              if P <> 0 then Len := LenAt(P);
              if T.Kind = tkWideString then Len := Len div 2;
              if Which = 0 then Result := IntConst(Len)
              else if Which = 1 then Result := IntConst(Len)
              else Result := IntConst(1);
            end;
          tkShortString:
            begin
              LoadRaw(A, B, 1);
              if Which = 0 then Result := IntConst(B)
              else if Which = 1 then Result := IntConst(T.Size - 1)
              else Result := IntConst(0);
            end;
          tkPointer:
            if IsStringValue(A) and (Which = 0) then
              Result := IntConst(Length(LoadStr(A)))
            else
              Err('Array or string expected');
          tkInteger, tkChar, tkBoolean, tkEnum:
            if (T.Leaf = LF_SUBRANGE) or (T.Kind = tkEnum) then
            begin
              if Which = 0 then Err('Array or string expected');
              if Which = 1 then Result := IntConst(T.High) else Result := IntConst(T.Low);
            end
            else
              Err('Array or string expected');
        else
          Err('Array or string expected');
        end;
      end;
    3: Result := IntConst(LoadInt(A));
    4:
      begin
        InitValue(Result);
        Result.Kind := evConst;
        Result.CK := ecChar;
        Result.I := LoadInt(A) and $FF;
      end;
    5:
      begin
        if not GetT(A.Info, A.TypeIdx, T) or (T.Size < 0) then Err('Size is not known');
        Result := IntConst(T.Size);
      end;
    6: Result := BoolConst(LoadInt(A) <> 0);
    7:
      if IsFloatValue(A) then Result := FloatConst(Abs(LoadFloat(A))) else Result := IntConst(Abs(LoadInt(A)));
    8: Result := IntConst(Trunc(LoadFloat(A)));
    9: Result := IntConst(Round(LoadFloat(A)));
    10: Result := BoolConst(Odd(LoadInt(A)));
    11: Result := AddressOf(A);
  end;
end;

{ parser }

function TDbgEvaluator.ParseExpr: TEvValue;
var
  Op: string;
  R: TEvValue;
begin
  Result := ParseSimple;
  while True do
  begin
    if (FTok = ttSym) and ((FTokStr = '=') or (FTokStr = '<>') or (FTokStr = '<') or (FTokStr = '>') or
      (FTokStr = '<=') or (FTokStr = '>=')) then
    begin
      Op := FTokStr;
      NextTok;
      R := ParseSimple;
      Result := Compare(Op, Result, R);
    end
    else if IsKeyword('in') then
    begin
      NextTok;
      R := ParseSimple;
      Result := InSet(Result, R);
    end
    else
      Break;
  end;
end;

function TDbgEvaluator.ParseSimple: TEvValue;
var
  Op: string;
  R: TEvValue;
begin
  Result := ParseTerm;
  while True do
  begin
    if IsSym('+') or IsSym('-') then
      Op := FTokStr
    else if IsKeyword('or') or IsKeyword('xor') then
      Op := LowerCase(FTokStr)
    else
      Break;
    NextTok;
    R := ParseTerm;
    Result := BinaryOp(Op, Result, R);
  end;
end;

function TDbgEvaluator.ParseTerm: TEvValue;
var
  Op: string;
  R: TEvValue;
begin
  Result := ParseFactor;
  while True do
  begin
    if IsSym('*') or IsSym('/') then
      Op := FTokStr
    else if IsKeyword('div') or IsKeyword('mod') or IsKeyword('and') or IsKeyword('shl') or IsKeyword('shr') then
      Op := LowerCase(FTokStr)
    else
      Break;
    NextTok;
    R := ParseFactor;
    Result := BinaryOp(Op, Result, R);
  end;
end;

function TDbgEvaluator.ParseFactor: TEvValue;
var
  Name: string;
  Handled, Signed: Boolean;
  V: TEvValue;
  T: TTDTypeInfo;
  X: Int64;
  W: Integer;
begin
  InitValue(Result);
  case FTok of
    ttInt:
      begin
        Result := IntConst(FTokInt);
        NextTok;
      end;
    ttFloat:
      begin
        Result := FloatConst(FTokFloat);
        NextTok;
      end;
    ttStr:
      begin
        Result := StrConst(FTokStr);
        NextTok;
        Result := ParsePostfix(Result);
      end;
    ttSym:
      if FTokStr = '(' then
      begin
        NextTok;
        Result := ParseExpr;
        Expect(')');
        Result := ParsePostfix(Result);
      end
      else if FTokStr = '-' then
      begin
        NextTok;
        V := ParseFactor;
        if IsFloatValue(V) then Result := FloatConst(-LoadFloat(V)) else Result := IntConst(-LoadInt(V));
      end
      else if FTokStr = '+' then
      begin
        NextTok;
        Result := ParseFactor;
      end
      else if FTokStr = '@' then
      begin
        NextTok;
        V := ParseFactor;
        Result := AddressOf(V);
      end
      else
        Err('Unexpected "' + FTokStr + '"');
    ttIdent:
      begin
        Name := FTokStr;
        if SameText(Name, 'not') then
        begin
          NextTok;
          V := ParseFactor;
          if ((V.Kind = evConst) and (V.CK = ecBool)) or
            ((V.Kind <> evConst) and TypeOf(V, T) and (T.Kind = tkBoolean)) then
            Result := BoolConst(LoadInt(V) = 0)
          else
          begin
            // in the operand's own type: not Byte(5) = 250, not Cardinal(0) = 4294967295
            X := LoadInt(V);
            W := OrdWidth(V, X, Signed);
            if Signed or (W = 8) then
              Result := IntConst(not X)
            else
              Result := IntConst((not X) and ((Int64(1) shl (W * 8)) - 1));
          end;
          Exit;
        end;
        NextTok;
        if SameText(Name, 'nil') then
        begin
          InitValue(Result);
          Result.Kind := evConst;
          Result.CK := ecPtr;
          Result.I := 0;
          Exit;
        end;
        if SameText(Name, 'True') then
        begin
          Result := BoolConst(True);
          Exit;
        end;
        if SameText(Name, 'False') then
        begin
          Result := BoolConst(False);
          Exit;
        end;
        Handled := False;
        Result := CallIntrinsic(Name, Handled);
        if not Handled then Result := ResolveIdent(Name);
        Result := ParsePostfix(Result);
      end;
  else
    Err('Expression expected');
  end;
end;

{ ---------------------------------------------------------------- calls }

{ the parameters a mangled routine name gives beyond the object ('@TClass@GetX$qqrv': none):
  0, 1 (one or more: an array property's index), -1 unknown }
function MangledArity(const Name: string): Integer;
var
  P: Integer;
begin
  Result := -1;
  P := Pos('$qqr', Name);
  if P = 0 then Exit;
  if Copy(Name, P + 4, 1) = 'v' then Result := 0 else Result := 1;
end;

{ the call of a property's getter Getter (its mangled name in the debug information) for the
  object Obj of class ClassIdx; an array property's getter needs its index (HighValue: the
  arguments it needs at least) }
function TDbgEvaluator.GetterCall(Info: TTD32Info; Base, ClassIdx, Obj: Cardinal; const Getter: string;
  PropType, DeclClass: Cardinal): TEvValue;
var
  PT: TTDTypeInfo;
  Exp, Clean: string;
begin
  InitValue(Result);
  Result.Kind := evCall;
  Result.Info := Info;
  Result.Base := Base;
  Result.I := Obj;
  Result.Reg := 1;
  Result.S := CleanProcName(Getter);
  Result.ModIdx := Integer(PropType);
  Clean := CleanProcName(Getter);
  CodeOf(Info, ClassIdx, Getter, Result, Exp,
    IsVirtual(Info, DeclClass, Copy(Clean, LastDelimiter('.', Clean) + 1, MaxInt)));
  { an array property's getter takes its index: its type says so, else its export's or its own
    mangled name ('$qqri') }
  if (Result.TypeIdx <> 0) and GetT(Result.Info, Result.TypeIdx, PT) and (PT.Kind = tkProcedure) then
    Result.HighKnown := PT.ArgCount > 0
  else
    Result.HighKnown := (MangledArity(Exp) > 0) or (MangledArity(Getter) > 0);
  Result.HighValue := Ord(Result.HighKnown);
end;

{ The code of Routine for an object of class ClassIdx, into C: Addr, and - when the debug
  information has the routine - TypeIdx with Info and Base of its module. A virtual method (Virt)
  is looked for in the object's class and then its ancestors (the first one that has the code: an
  override before what it overrides), a static one of a 'TClass.Method' name in that class first;
  the debug information first, then the packages' exports (FindCode). }
function TDbgEvaluator.CodeOf(Info: TTD32Info; ClassIdx: Cardinal; const Routine: string; var C: TEvValue;
  out ExportName: string; Virt: Boolean): Boolean;

  function Find(const Cls, Method: string): Boolean;
  var
    I, P: Integer;
    MI: TTD32Info;
    MB: Cardinal;
  begin
    for I := 0 to FHost.InfoCount - 1 do
      if FHost.GetInfo(I, MI, MB) and (MI <> nil) then
      begin
        P := MI.FindProcByName(Cls + '.' + Method);
        if P < 0 then Continue;
        C.Addr := MB + MI.Procs[P].Start;
        C.TypeIdx := MI.Procs[P].TypeIdx;
        C.Info := MI;
        C.Base := MB;
        Result := True;
        Exit;
      end;
    C.Addr := FHost.FindCode(Cls, Method, ExportName);
    Result := C.Addr <> 0;
  end;

var
  CT: TTDTypeInfo;
  Fields: TTDFieldArray;
  I, Depth, P: Integer;
  Found: Boolean;
  Clean, Cls, Method: string;
begin
  Result := True;
  ExportName := '';
  if (Routine <> '') and (Routine[1] = '@') then
  begin
    C.Addr := FHost.FindCode('', Routine, ExportName);
    if C.Addr <> 0 then Exit;
  end;
  { 'TClass.Method' (or 'Unit.TClass.Method'): that class, without its unit }
  Clean := CleanProcName(Routine);
  P := LastDelimiter('.', Clean);
  Method := Copy(Clean, P + 1, MaxInt);
  Cls := '';
  if P > 0 then
  begin
    Cls := Copy(Clean, 1, P - 1);
    Cls := Copy(Cls, LastDelimiter('.', Cls) + 1, MaxInt);
    if not Virt and Find(Cls, Method) then Exit;
  end;
  Depth := 0;
  while (Info <> nil) and (ClassIdx <> 0) and (Depth < 32) do
  begin
    Inc(Depth);
    if Find(Info.TypeName(ClassIdx), Method) then Exit;
    if not Info.GetType(ClassIdx, CT) or not Info.GetFields(CT.FieldList, Fields) then Break;
    Found := False;
    for I := 0 to High(Fields) do
      if Fields[I].Kind = fdBaseClass then
      begin
        ClassIdx := Fields[I].TypeIdx;
        Found := True;
        Break;
      end;
    if not Found then Break;
  end;
  if (Cls <> '') and Find(Cls, Method) then Exit;
  C.Addr := 0;
  Result := False;
end;

{ whether Method of class ClassIdx (or of an ancestor) is virtual: the method list's attribute
  (mprop: virtual, introducing virtual, pure virtual, pure introducing virtual) }
function TDbgEvaluator.IsVirtual(Info: TTD32Info; ClassIdx: Cardinal; const Method: string): Boolean;
var
  CT: TTDTypeInfo;
  Fields: TTDFieldArray;
  I, Depth: Integer;
  Attr: Word;
  MT, Base: Cardinal;
begin
  Result := False;
  Depth := 0;
  while (Info <> nil) and (ClassIdx <> 0) and (Depth < 32) do
  begin
    Inc(Depth);
    if not Info.GetType(ClassIdx, CT) or not Info.GetFields(CT.FieldList, Fields) then Exit;
    Base := 0;
    for I := 0 to High(Fields) do
      if (Fields[I].Kind = fdMethod) and Info.NameEquals(Fields[I].NameIdx, Method) then
      begin
        Result := Info.MethodEntry(Fields[I].TypeIdx, Attr, MT) and (((Attr shr 2) and 7) in [1, 4, 5, 6]);
        Exit;
      end
      else if Fields[I].Kind = fdBaseClass then
        Base := Fields[I].TypeIdx;
    ClassIdx := Base;
  end;
end;

{ a routine of the program by its name ('Proc', 'Unit.Proc', 'TClass.Method' for a class method) }
function TDbgEvaluator.LookupRoutine(const Name: string; out V: TEvValue): Boolean;
var
  I, P: Integer;
  Info: TTD32Info;
  Base: Cardinal;
  Pr: PTDProc;
begin
  Result := False;
  InitValue(V);
  for I := 0 to FHost.InfoCount - 1 do
    if FHost.GetInfo(I, Info, Base) and (Info <> nil) then
    begin
      P := Info.FindProcByName(Name);
      if P < 0 then Continue;
      Pr := Info.Procs[P];
      V.Kind := evCall;
      V.Info := Info;
      V.Base := Base;
      V.Addr := Base + Pr.Start;
      V.TypeIdx := Pr.TypeIdx;
      V.S := Name;
      Result := True;
      Exit;
    end;
end;

{ memory of the thread for this evaluation's calls (results, literals), zeroed }
function TDbgEvaluator.ScratchAlloc(Size: Integer): Cardinal;
const
  ScratchSize = $C00;
var
  Z: array of Byte;
begin
  if FScratch = 0 then FScratch := FHost.CallScratch;
  if FScratch = 0 then Err('Function calls are not possible here');
  Size := (Size + 7) and not 7;
  if FScratchUsed + Cardinal(Size) > ScratchSize then Err('The expression calls too much');
  Result := FScratch + FScratchUsed;
  Inc(FScratchUsed, Size);
  SetLength(Z, Size);
  FillChar(Z[0], Size, 0);
  if not FHost.WriteMem(Result, Z[0], Size) then Err('Cannot write the memory of the call');
end;

{ C called with Args in Delphi's register convention: the object and the first parameters that
  fit in EAX, EDX, ECX, the others on the stack in their order; a string, a record that is not 1,
  2 or 4 bytes long and other managed results go to a variable passed as a hidden last
  parameter, ordinal results come in EAX (Int64: EDX:EAX), floating-point ones in ST(0). The
  result is a value in the memory of the call. }
function TDbgEvaluator.CallValue(const C: TEvValue; const Args: array of TEvValue): TEvValue;
var
  PT, AT, RT: TTDTypeInfo;
  ArgTypes: TCardinalArray;
  Regs, Stack: array of Cardinal;
  RetType, Slot, P, EAX, EDX: Cardinal;
  ST0: Extended;
  I, Size: Integer;
  HiddenResult, Void: Boolean;
  Err0: string;
  X: Int64;
  S4: Single;
  D8: Double;

  procedure Push(Value: Cardinal);
  var
    N: Integer;
  begin
    N := Length(Stack);
    SetLength(Stack, N + 1);
    Stack[N] := Value;
  end;

  { the next parameter: in EAX, EDX, ECX while one is free, else on the stack }
  procedure Pass(Value: Cardinal);
  var
    N: Integer;
  begin
    if Length(Regs) < 3 then
    begin
      N := Length(Regs);
      SetLength(Regs, N + 1);
      Regs[N] := Value;
    end
    else
      Push(Value);
  end;

  { a string constant as Delphi keeps a literal: reference count -1, length, characters, #0 }
  function Literal(const Text: string): Cardinal;
  var
    Buf: array of Byte;
    L: Integer;
  begin
    L := Length(Text);
    SetLength(Buf, 9 + L);
    PInteger(@Buf[0])^ := -1;
    PInteger(@Buf[4])^ := L;
    if L > 0 then Move(Text[1], Buf[8], L);
    Buf[8 + L] := 0;
    Result := ScratchAlloc(Length(Buf));
    if not FHost.WriteMem(Result, Buf[0], Length(Buf)) then Err('Cannot write the memory of the call');
    Inc(Result, 8);
  end;

begin
  InitValue(Result);
  if C.Addr = 0 then
    Err(Format('The code of %s is not in the program (the linker left it out: it is never called), or in ' +
      'neither its debug information nor its exports', [C.S]));
  ArgTypes := nil;
  if (C.TypeIdx <> 0) and GetT(C.Info, C.TypeIdx, PT) and (PT.Kind = tkProcedure) then
  begin
    RetType := PT.RetType;
    if not C.Info.GetArgs(PT.ArgList, ArgTypes) then ArgTypes := nil;
  end
  else
    RetType := Cardinal(C.ModIdx);           // a getter: its property's type
  if C.HighKnown and (Length(Args) < C.HighValue) then
    Err(Format('%s reads an array property: give its index in [ ]', [C.S]));
  if C.TypeIdx <> 0 then
  begin
    if Length(Args) < Length(ArgTypes) then Err(Format('Not enough actual parameters for %s', [C.S]));
    if Length(Args) > Length(ArgTypes) then Err(Format('Too many actual parameters for %s', [C.S]));
  end;
  Regs := nil;
  Stack := nil;
  if C.Reg = 1 then Pass(Cardinal(C.I));    // Self
  for I := 0 to High(Args) do
  begin
    if I > High(ArgTypes) then
    begin
      { a getter known by its mangled name only: an index as it is - a string, or a number }
      if IsStringValue(Args[I]) then
      begin
        if Args[I].Kind = evMem then Pass(LoadPtr(Args[I])) else Pass(Literal(LoadStr(Args[I])));
      end
      else
        Pass(Cardinal(LoadInt(Args[I]) and $FFFFFFFF));
      Continue;
    end;
    if not GetT(C.Info, ArgTypes[I], AT) then Err('Unknown parameter type');
    if (AT.Kind = tkPointer) and AT.IsRef then
    begin
      { var, out, const by reference: the address of the argument (a value of its own when it
        has none) }
      if Args[I].Kind = evMem then
        Pass(Args[I].Addr)
      else
      begin
        Size := SizeOfType(C.Info, AT.ElemType);
        if (Size <= 0) or (Size > 8) then Err('The argument needs a variable');
        P := ScratchAlloc(Size);
        X := LoadInt(Args[I]);
        if not FHost.WriteMem(P, X, Size) then Err('Cannot write the memory of the call');
        Pass(P);
      end;
    end
    else if AT.Kind = tkAnsiString then
    begin
      if Args[I].Kind = evMem then Pass(LoadPtr(Args[I])) else Pass(Literal(LoadStr(Args[I])));
    end
    else if AT.Kind in [tkFloat, tkCurrency] then
      Err('Floating-point arguments are not supported in calls')
    else if (AT.Kind in [tkRecord, tkArray, tkShortString, tkVariant, tkWideString]) then
    begin
      if Args[I].Kind <> evMem then Err('The argument needs a variable');
      Pass(Args[I].Addr);
    end
    else if AT.Size = 8 then
    begin
      X := LoadInt(Args[I]);
      Push(Cardinal(X shr 32));
      Push(Cardinal(X and $FFFFFFFF));
    end
    else
      Pass(Cardinal(LoadInt(Args[I]) and $FFFFFFFF));
  end;
  { the result }
  Void := (RetType = 0) or (RetType = T_VOID);
  HiddenResult := False;
  Size := 4;
  if not Void then
  begin
    if not GetT(C.Info, RetType, RT) then Err('Unknown result type');
    Size := SizeOfType(C.Info, RetType);
    if Size < 4 then Size := 4;
    HiddenResult := (RT.Kind in [tkAnsiString, tkWideString, tkVariant, tkInterface, tkDynArray, tkShortString,
      tkMethod]) or ((RT.Kind in [tkRecord, tkArray, tkSet]) and not (RT.Size in [1, 2, 4]));
  end;
  if Size > 1024 then Err('The result is too large');
  Slot := ScratchAlloc(Size + 4);
  if HiddenResult then Pass(Slot);
  if not FHost.CallCode(C.Addr, Regs, Stack, EAX, EDX, ST0, Err0) then
    Err(Format('%s: %s', [C.S, Err0]));
  if Void then
  begin
    Result.Kind := evNone;
    Exit;
  end;
  if not HiddenResult then
    if RT.Kind in [tkFloat, tkCurrency] then
      case RT.Size of
        4:
          begin
            S4 := ST0;
            FHost.WriteMem(Slot, S4, 4);
          end;
        8:
          if RT.Kind = tkCurrency then
          begin
            X := Round(ST0);
            FHost.WriteMem(Slot, X, 8);
          end
          else
          begin
            D8 := ST0;
            FHost.WriteMem(Slot, D8, 8);
          end;
      else
        FHost.WriteMem(Slot, ST0, 10);
      end
    else
    begin
      FHost.WriteMem(Slot, EAX, 4);
      if RT.Size = 8 then FHost.WriteMem(Slot + 4, EDX, 4);
    end;
  Result := MemValue(C.Info, C.Base, Slot, RetType);
end;

function TDbgEvaluator.ParsePostfix(const AV: TEvValue): TEvValue;
var
  V, Idx, R: TEvValue;
  Name: string;
  Args: array of TEvValue;
  N: Integer;
begin
  V := AV;
  while True do
  begin
    if V.Kind = evCall then
    begin
      { a routine or method: called, with its arguments when it has some }
      Args := nil;
      if IsSym('(') or (V.HighKnown and IsSym('[')) then
      begin
        if IsSym('(') then Name := ')' else Name := ']';
        NextTok;
        if not IsSym(Name) then
          repeat
            N := Length(Args);
            SetLength(Args, N + 1);
            Args[N] := ParseExpr;
            if IsSym(',') then NextTok else Break;
          until False;
        Expect(Name);
      end;
      V := CallValue(V, Args);
    end
    else if IsSym('.') then
    begin
      NextTok;
      if FTok <> ttIdent then Err('Identifier expected after "."');
      Name := FTokStr;
      NextTok;
      if not FindMember(V, Name, R) then
      begin
        if V.Kind = evUnit then
          Err(Format('"%s" is not declared in unit %s', [Name, V.Info.Modules[V.ModIdx].Name]))
        else
          Err(Format('"%s" is not a member of %s', [Name, TypeNameOf(V)]));
      end;
      if R.Kind = evCall then V := R else V := AutoDeref(R);
    end
    else if IsSym('[') then
    begin
      NextTok;
      while True do
      begin
        Idx := ParseExpr;
        V := IndexValue(V, LoadInt(Idx));
        if IsSym(',') then
          NextTok
        else
          Break;
      end;
      Expect(']');
    end
    else if IsSym('^') then
    begin
      NextTok;
      V := Deref(V);
    end
    else if IsSym('(') and (V.Kind = evType) then
    begin
      NextTok;
      R := ParseExpr;
      Expect(')');
      V := CastValue(V, R);
    end
    else
      Break;
  end;
  Result := V;
end;

function TDbgEvaluator.EvalText(const Expr: string): TEvValue;
begin
  FText := Expr;
  FPos := 1;
  FScratch := 0;
  FScratchUsed := 0;
  if not FFrameReady then InitFrame;
  NextTok;
  if FTok = ttEOF then Err('Expression expected');
  Result := ParseExpr;
  if FTok <> ttEOF then Err('Unexpected text after the expression: ' + Copy(FText, FPos - Length(FTokStr), 20));
  if Result.Kind = evType then Err('Expression expected, but a type name was found');
  if Result.Kind = evUnit then Err('Expression expected, but a unit name was found');
  if Result.Kind = evNone then Err('Expression has no value');
end;

{ formatting }

function TDbgEvaluator.CharLit(C: Integer): string;
begin
  if (C >= 32) and (C <= 255) and (C <> 127) then
  begin
    if C = Ord('''') then
      Result := ''''''''''
    else
      Result := '''' + ProgramText(Chr(C)) + '''';
  end
  else
    Result := '#' + IntToStr(C);
end;

function TDbgEvaluator.QuoteStr(const S: string): string;
var
  I: Integer;
  InQuote: Boolean;
  C: Char;
begin
  if S = '' then
  begin
    Result := '''''';
    Exit;
  end;
  Result := '';
  InQuote := False;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C < ' ') or (C = #127) then
    begin
      if InQuote then
      begin
        Result := Result + '''';
        InQuote := False;
      end;
      Result := Result + '#' + IntToStr(Ord(C));
    end
    else
    begin
      if not InQuote then
      begin
        Result := Result + '''';
        InQuote := True;
      end;
      if C = '''' then Result := Result + '''''' else Result := Result + C;
    end;
  end;
  if InQuote then Result := Result + '''';
end;

{ '...' after a string of which only the start was read }
function TDbgEvaluator.QuoteTrunc(const S: string; Truncated: Boolean): string;
begin
  Result := QuoteStr(S);
  if Truncated then Result := Result + '...';
end;

function TDbgEvaluator.FloatText(X: Extended; Prec: Integer): string;
var
  I: Integer;
begin
  Result := FloatToStrF(X, ffGeneral, Prec, 0);
  if DecimalSeparator <> '.' then
    for I := 1 to Length(Result) do
      if Result[I] = DecimalSeparator then Result[I] := '.';
end;

function TDbgEvaluator.FormatOrdinal(Info: TTD32Info; TypeIdx: Cardinal; Value: Int64): string;
var
  T: TTDTypeInfo;
  Nm: string;
begin
  if not GetT(Info, TypeIdx, T) then
  begin
    Result := IntToStr(Value);
    Exit;
  end;
  case T.Kind of
    tkBoolean:
      if Value = 0 then Result := 'False' else Result := 'True';
    tkChar: Result := CharLit(Value and $FF);
    tkWideChar:
      if (Value >= 32) and (Value < 127) then
        Result := CharLit(Value)
      else
        Result := '#' + IntToStr(Value);
    tkEnum:
      if (Info <> nil) and Info.EnumName(T, Value, Nm) then
        Result := Nm
      else
        Result := Format('%s(%d)', [Info.TypeName(TypeIdx), Value]);
  else
    Result := IntToStr(Value);
  end;
end;

function TDbgEvaluator.FormatSet(const V: TEvValue; const T: TTDTypeInfo): string;
var
  Bits: array[0..31] of Byte;
  I, N, RunStart: Integer;
  Base: Integer;

  function IsSet(Bit: Integer): Boolean;
  begin
    Result := (Bit >= 0) and (Bit < T.Size * 8) and ((Bits[Bit shr 3] and (1 shl (Bit and 7))) <> 0);
  end;

  procedure AddItem(const S: string);
  begin
    if Result <> '[' then Result := Result + ',';
    Result := Result + S;
  end;

var
  ET: TTDTypeInfo;
  UseRanges: Boolean;
begin
  Result := '[';
  if (T.Size < 1) or (T.Size > 32) then
  begin
    Result := '[?]';
    Exit;
  end;
  FillChar(Bits, SizeOf(Bits), 0);
  LoadRaw(V, Bits, T.Size);
  Base := T.SetLowByte * 8;
  N := T.Size * 8;
  UseRanges := not (GetT(V.Info, T.ElemType, ET) and (ET.Kind = tkEnum));
  I := 0;
  while I < N do
  begin
    if IsSet(I) then
    begin
      RunStart := I;
      while IsSet(I + 1) do Inc(I);
      if UseRanges and (I - RunStart >= 2) then
        AddItem(FormatOrdinal(V.Info, T.ElemType, Base + RunStart) + '..' +
          FormatOrdinal(V.Info, T.ElemType, Base + I))
      else
        for RunStart := RunStart to I do
          AddItem(FormatOrdinal(V.Info, T.ElemType, Base + RunStart));
    end;
    Inc(I);
  end;
  Result := Result + ']';
end;

function TDbgEvaluator.FormatVariant(Addr: Cardinal): string;
var
  VD: array[0..15] of Byte;
  VT: Word;
  Trunc: Boolean;
  S: string;
begin
  if not FHost.ReadMem(Addr, VD, 16) then
  begin
    Result := '?';
    Exit;
  end;
  VT := PWord(@VD[0])^;
  if (VT and $2000) <> 0 then
  begin
    Result := 'Variant array';
    Exit;
  end;
  if (VT and $4000) <> 0 then
  begin
    Result := Format('Variant by reference ($%.8x)', [PCardinal(@VD[8])^]);
    Exit;
  end;
  case VT of
    $0000: Result := 'Unassigned';
    $0001: Result := 'Null';
    $0002: Result := IntToStr(PSmallInt(@VD[8])^);
    $0003: Result := IntToStr(PInteger(@VD[8])^);
    $0004: Result := FloatText(PSingle(@VD[8])^, 8);
    $0005: Result := FloatText(PDouble(@VD[8])^, 15);
    $0006: Result := FloatText(PInt64(@VD[8])^ / 10000, 18);
    $0007: Result := FloatText(PDouble(@VD[8])^, 15);
    $0008:
      begin
        S := ReadWideStr(PCardinal(@VD[8])^, Trunc);
        Result := QuoteTrunc(S, Trunc);
      end;
    $000B: if PWord(@VD[8])^ <> 0 then Result := 'True' else Result := 'False';
    $0010: Result := IntToStr(PShortInt(@VD[8])^);
    $0011: Result := IntToStr(VD[8]);
    $0012: Result := IntToStr(PWord(@VD[8])^);
    $0013: Result := IntToStr(PCardinal(@VD[8])^);
    $0014: Result := IntToStr(PInt64(@VD[8])^);
    $0100:
      if ReadLStr(PCardinal(@VD[8])^, MAX_STR_DISPLAY, S, Trunc) then
        Result := QuoteTrunc(S, Trunc)
      else
        Result := '?';
    $0009: Result := Format('IDispatch($%.8x)', [PCardinal(@VD[8])^]);
    $000D: Result := Format('IUnknown($%.8x)', [PCardinal(@VD[8])^]);
  else
    Result := Format('Variant(type $%.4x)', [VT]);
  end;
end;

function TDbgEvaluator.FormatValue(const V: TEvValue; Depth: Integer): string;
var
  T, E: TTDTypeInfo;
  X: Int64;
  P, Len, Code, Data: Cardinal;
  S, Nm: string;
  Trunc: Boolean;
  I, N, ES: Integer;
  Fields: TTDFieldArray;
  C: Int64;
  Elem: TEvValue;
  MP: array[0..1] of Cardinal;

  function Hex(Value: Int64; Size: Integer): string;
  begin
    if Size <= 0 then Size := 4;
    if Size >= 8 then
      Result := '$' + IntToHex(Value, 16)
    else
      Result := '$' + IntToHex(Value and ((Int64(1) shl (Size * 8)) - 1), Size * 2);
  end;

  function ElemList(BaseAddr: Cardinal; Count, ElemSize: Integer; ElemType: Cardinal): string;
  var
    K, Shown: Integer;
  begin
    Result := '(';
    Shown := Count;
    if Shown > MAX_ARRAY_DISPLAY then Shown := MAX_ARRAY_DISPLAY;
    for K := 0 to Shown - 1 do
    begin
      if K > 0 then Result := Result + ', ';
      // one element that cannot be shown (unreadable, a float that is no number) spoils no other
      try
        Result := Result + FormatValue(MemValue(V.Info, V.Base, BaseAddr + Cardinal(K * ElemSize), ElemType),
          Depth + 1);
      except
        Result := Result + '?';
      end;
    end;
    if Count > Shown then Result := Result + ', ...';
    Result := Result + ')';
  end;

begin
  Result := '';
  if V.Kind = evConst then
  begin
    if V.TypeIdx = 0 then
    begin
      case V.CK of
        ecInt:
          if FFmt = 'x' then Result := '$' + IntToHex(V.I, 1) else Result := IntToStr(V.I);
        ecFloat: Result := FloatText(V.F, 18);
        ecStr: Result := QuoteStr(V.S);
        ecBool: if V.I <> 0 then Result := 'True' else Result := 'False';
        ecChar: Result := CharLit(V.I);
        ecPtr: if V.I = 0 then Result := 'nil' else Result := '$' + IntToHex(V.I, 8);
      end;
      Exit;
    end;
  end;
  if not (V.Kind in [evMem, evReg, evConst]) then Err('Expression has no value');
  if not TypeOf(V, T) then
  begin
    Result := '?';
    Exit;
  end;
  case T.Kind of
    tkInteger:
      begin
        X := LoadInt(V);
        if FFmt = 'x' then
          Result := Hex(X, T.Size)
        else if FFmt = 'c' then
          Result := CharLit(X and $FF)
        else if (T.Size = 4) and not T.Signed then
          Result := IntToStr(X and $FFFFFFFF)
        else
          Result := IntToStr(X);
      end;
    tkBoolean, tkChar, tkWideChar, tkEnum:
      begin
        X := LoadInt(V);
        if (FFmt = 'x') or (FFmt = 'd') then
        begin
          if FFmt = 'x' then Result := Hex(X, T.Size) else Result := IntToStr(X);
        end
        else
          Result := FormatOrdinal(V.Info, V.TypeIdx, X);
      end;
    tkFloat:
      case T.FloatKind of
        fkSingle: Result := FloatText(LoadFloat(V), 8);
        fkDouble, fkReal48: Result := FloatText(LoadFloat(V), 15);
      else
        Result := FloatText(LoadFloat(V), 18);
      end;
    tkCurrency:
      begin
        LoadRaw(V, C, 8);
        Result := FloatText(C / 10000, 18);
      end;
    tkSet: Result := FormatSet(V, T);
    tkPointer:
      begin
        P := LoadPtr(V);
        if T.IsRef then
        begin
          if P = 0 then
            Result := 'nil'
          else
            Result := FormatValue(MemValue(V.Info, V.Base, P, T.ElemType), Depth);
        end
        else if P = 0 then
          Result := 'nil'
        else if (FFmt <> 'p') and (FFmt <> 'x') and GetT(V.Info, T.ElemType, E) and
          (E.Kind in [tkChar, tkWideChar]) then
        begin
          if E.Kind = tkChar then S := ReadCStr(P, MAX_STR_DISPLAY, Trunc) else S := ReadWStr(P, 0, True, Trunc);
          Result := QuoteTrunc(S, Trunc);
        end
        else
          Result := '$' + IntToHex(P, 8);
      end;
    tkClassRef:
      begin
        P := LoadPtr(V);
        if P = 0 then
          Result := 'nil'
        else
        begin
          Nm := ReadVMTClassName(P);
          if Nm <> '' then Result := Nm else Result := '$' + IntToHex(P, 8);
        end;
      end;
    tkObject:
      begin
        P := LoadPtr(V);
        if P = 0 then
          Result := 'nil'
        else
        begin
          Nm := ReadClassName(P);
          if Nm = '' then Nm := TypeNameOf(V);
          Result := Format('%s($%.8x)', [Nm, P]);
        end;
      end;
    tkInterface:
      begin
        P := LoadPtr(V);
        if P = 0 then Result := 'nil' else Result := Format('%s($%.8x)', [TypeNameOf(V), P]);
      end;
    tkProcedure:
      begin
        P := LoadPtr(V);
        if P = 0 then
          Result := 'nil'
        else
        begin
          Nm := FHost.AddrToSymbol(P);
          if Nm <> '' then Result := Format('%s ($%.8x)', [Nm, P]) else Result := '$' + IntToHex(P, 8);
        end;
      end;
    tkMethod:
      begin
        LoadRaw(V, MP, 8);
        Code := MP[0];
        Data := MP[1];
        if Code = 0 then
          Result := 'nil'
        else
        begin
          Nm := FHost.AddrToSymbol(Code);
          if Nm = '' then Nm := '$' + IntToHex(Code, 8);
          Result := Format('(%s, $%.8x)', [Nm, Data]);
        end;
      end;
    tkVariant:
      if V.Kind = evMem then Result := FormatVariant(V.Addr) else Result := '?';
    tkShortString: Result := QuoteStr(ProgramText(LoadShortStr(V)));
    tkAnsiString:
      begin
        P := LoadPtr(V);
        if not ReadLStr(P, MAX_STR_DISPLAY, S, Trunc) then Err(Format('Cannot read string at $%.8x', [P]));
        Result := QuoteTrunc(ProgramText(S), Trunc);
      end;
    tkWideString:
      begin
        S := ReadWideStr(LoadPtr(V), Trunc);
        Result := QuoteTrunc(S, Trunc);
      end;
    tkArray:
      begin
        if V.Kind <> evMem then Err('Cannot read array');
        if Depth > MAX_FORMAT_DEPTH then
        begin
          Result := '(...)';
          Exit;
        end;
        ES := SizeOfType(V.Info, T.ElemType);
        if (T.Count > 0) and (T.Size > 0) then ES := T.Size div T.Count;
        if ES <= 0 then Err('Unknown array element size');
        Result := ElemList(V.Addr, T.Count, ES, T.ElemType);
      end;
    tkDynArray:
      begin
        P := LoadPtr(V);
        if P = 0 then
          Result := '()'
        else
        begin
          Len := LenAt(P);
          if Depth > MAX_FORMAT_DEPTH then
          begin
            Result := '(...)';
            Exit;
          end;
          ES := SizeOfType(V.Info, T.ElemType);
          if ES <= 0 then Err('Unknown array element size');
          if Len > $1000000 then Err('Invalid dynamic array');
          Result := ElemList(P, Len, ES, T.ElemType);
        end;
      end;
    tkOpenArray:
      begin
        if T.Leaf = LF_POINTER then P := LoadPtr(V) else P := V.Addr;
        if P = 0 then
          Result := 'nil'
        else if V.HighKnown then
        begin
          ES := SizeOfType(V.Info, T.ElemType);
          if ES <= 0 then Err('Unknown array element size');
          Result := ElemList(P, V.HighValue + 1, ES, T.ElemType);
        end
        else
          Result := '$' + IntToHex(P, 8);
      end;
    tkRecord, tkClass:
      begin
        if V.Kind <> evMem then Err('Cannot read record');
        if Depth > MAX_FORMAT_DEPTH then
        begin
          Result := '(...)';
          Exit;
        end;
        Result := '(';
        N := 0;
        if (V.Info <> nil) and V.Info.GetFields(T.FieldList, Fields) then
          for I := 0 to High(Fields) do
            if Fields[I].Kind = fdMember then
            begin
              if N > 0 then Result := Result + '; ';
              Inc(N);
              Elem := MemValue(V.Info, V.Base, V.Addr + Cardinal(Fields[I].Offset), Fields[I].TypeIdx);
              // one field that cannot be shown spoils no other
              try
                S := FormatValue(Elem, Depth + 1);
              except
                S := '?';
              end;
              Result := Result + V.Info.NameStr(Fields[I].NameIdx) + ': ' + S;
            end;
        Result := Result + ')';
      end;
    tkVoid: Result := '(void)';
  else
    Result := '?';
  end;
end;

function TDbgEvaluator.HasChildren(const V: TEvValue): Boolean;
var
  T, E: TTDTypeInfo;
  P: Cardinal;
begin
  Result := False;
  if not (V.Kind in [evMem, evReg, evConst]) or (V.TypeIdx = 0) or not TypeOf(V, T) then Exit;
  try
    case T.Kind of
      tkRecord, tkClass: Result := V.Kind = evMem;
      tkArray: Result := (V.Kind = evMem) and (T.Count > 0);
      tkObject: Result := LoadPtr(V) <> 0;
      tkDynArray:
        begin
          P := LoadPtr(V);
          Result := (P <> 0) and (LenAt(P) > 0);
        end;
      tkOpenArray: Result := V.HighKnown and (V.HighValue >= 0);
      tkPointer:
        if T.IsRef then
        begin
          P := LoadPtr(V);
          Result := (P <> 0) and HasChildren(MemValue(V.Info, V.Base, P, T.ElemType));
        end
        else
        begin
          P := LoadPtr(V);
          Result := (P <> 0) and GetT(V.Info, T.ElemType, E) and
            not (E.Kind in [tkVoid, tkUnknown, tkChar, tkWideChar, tkProcedure]);
        end;
    end;
  except
    on EDbgEval do Result := False;
  end;
end;

function TDbgEvaluator.MakeVar(const Name, Expr: string; const V: TEvValue): TDbgVar;
begin
  Result.Name := Name;
  Result.Expr := Expr;
  Result.TypeName := TypeNameOf(V);
  // any exception: garbage in an uninitialised variable can also make the RTL fail (an Extended
  // that is no number raises EInvalidOp when formatted) - it belongs to this row only
  try
    Result.Value := FormatValue(V, 0);
    Result.Expandable := HasChildren(V);
  except
    on E: Exception do
    begin
      Result.Value := '<' + E.Message + '>';
      Result.Expandable := False;
    end;
  end;
end;

procedure TDbgEvaluator.AddVar(Rows: TVarRows; const Name, Expr: string; const V: TEvValue);
var
  R: TDbgVar;
begin
  R := MakeVar(Name, Expr, V);
  Rows.Vars[Rows.Add(Name)] := R;
end;

function TDbgEvaluator.ChildExpr(const Parent, Suffix: string): string;
var
  I: Integer;
  Simple: Boolean;
begin
  Simple := Parent <> '';
  for I := 1 to Length(Parent) do
    if not (Parent[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '[', ']', '^', ',', ' ', '$']) then
    begin
      Simple := False;
      Break;
    end;
  if Simple then
    Result := Parent + Suffix
  else
    Result := '(' + Parent + ')' + Suffix;
end;

procedure TDbgEvaluator.CollectFields(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal;
  const ParentExpr: string; Rows: TVarRows; Depth: Integer);
var
  CT: TTDTypeInfo;
  Fields: TTDFieldArray;
  I: Integer;
  Nm: string;
begin
  if (Info = nil) or (Depth > 32) then Exit;
  if not Info.GetType(ClassIdx, CT) or not Info.GetFields(CT.FieldList, Fields) then Exit;
  // inherited fields first
  for I := 0 to High(Fields) do
    if Fields[I].Kind = fdBaseClass then
      CollectFields(Info, Base, Fields[I].TypeIdx, Addr + Cardinal(Fields[I].Offset), ParentExpr, Rows, Depth + 1);
  for I := 0 to High(Fields) do
    if Fields[I].Kind = fdMember then
    begin
      Nm := Info.NameStr(Fields[I].NameIdx);
      AddVar(Rows, Nm, ChildExpr(ParentExpr, '.' + Nm),
        MemValue(Info, Base, Addr + Cardinal(Fields[I].Offset), Fields[I].TypeIdx));
    end;
end;

{ the methods and properties of a class and its ancestors, the ancestors' first (as the fields);
  a name once, in the place of the ancestor's and as the class itself declares it (a constructor
  with its own parameters). A property read through a field shows its value, one read by a method
  says so (the program's code is not called). }
procedure TDbgEvaluator.CollectMembers(Info: TTD32Info; Base: Cardinal; ClassIdx, Addr: Cardinal;
  const ParentExpr: string; Dynamic: Boolean; Methods, Props: TVarRows; Depth: Integer);

  { the row of Name (a new one at the end when the ancestors have none) with these texts }
  procedure AddText(Rows: TVarRows; const Name, Expr, Value, TypeName: string);
  var
    N: Integer;
  begin
    N := Rows.RowOf(Name);
    Rows.Vars[N].Name := Name;
    Rows.Vars[N].Expr := Expr;
    Rows.Vars[N].Value := Value;
    Rows.Vars[N].TypeName := TypeName;
    Rows.Vars[N].Expandable := False;
  end;

  { the row of Name with the value V }
  procedure AddValue(Rows: TVarRows; const Name, Expr: string; const V: TEvValue);
  var
    R: TDbgVar;
  begin
    R := MakeVar(Name, Expr, V);
    Rows.Vars[Rows.RowOf(Name)] := R;
  end;

var
  CT, PT: TTDTypeInfo;
  Fields: TTDFieldArray;
  I: Integer;
  Nm: string;
  Getter: TEvValue;
begin
  if (Info = nil) or (Depth > 32) then Exit;
  if Depth = 0 then FTopClass := ClassIdx;
  if not Info.GetType(ClassIdx, CT) or not Info.GetFields(CT.FieldList, Fields) then Exit;
  for I := 0 to High(Fields) do
    if Fields[I].Kind = fdBaseClass then
      CollectMembers(Info, Base, Fields[I].TypeIdx, Addr + Cardinal(Fields[I].Offset), ParentExpr,
        Dynamic, Methods, Props, Depth + 1);
  for I := 0 to High(Fields) do
  begin
    if Fields[I].NameIdx = 0 then Continue;
    Nm := Info.NameStr(Fields[I].NameIdx);
    case Fields[I].Kind of
      fdMethod:
        AddText(Methods, Nm, '', Info.MethodSignature(Fields[I].TypeIdx), Info.TypeName(ClassIdx));
      fdProperty:
        if Info.GetType(Fields[I].TypeIdx, PT) then
          if (PT.PropFlags and PROPF_GETMETHOD) <> 0 then
          begin
            { Show Dynamic Properties: their getters are called (Delphi's inspector does) }
            if Dynamic then
              try
                FScratchUsed := 0;      // each value is read before the next call
                Getter := GetterCall(Info, Base, FTopClass, Addr, Info.NameStr(PT.PropGet), PT.ElemType, ClassIdx);
                if Getter.HighKnown then
                  AddText(Props, Nm, ChildExpr(ParentExpr, '.' + Nm), '<array property>', Info.TypeName(PT.ElemType))
                else
                  AddValue(Props, Nm, ChildExpr(ParentExpr, '.' + Nm), CallValue(Getter, []));
              except
                on E: Exception do
                  AddText(Props, Nm, ChildExpr(ParentExpr, '.' + Nm), '<' + E.Message + '>', Info.TypeName(PT.ElemType));
              end;
          end
          else
            try
              AddValue(Props, Nm, ChildExpr(ParentExpr, '.' + Nm), MemValue(Info, Base, Addr + PT.PropGet, PT.ElemType));
            except
              on E: Exception do
                AddText(Props, Nm, ChildExpr(ParentExpr, '.' + Nm), '<' + E.Message + '>', Info.TypeName(PT.ElemType));
            end;
    end;
  end;
end;

procedure TDbgEvaluator.StoreValue(const Dest, Src: TEvValue);
var
  T, ST: TTDTypeInfo;
  X: Int64;
  W: WideString;
  F: Extended;
  S4: Single;
  D8: Double;
  R6: Real48;
  C8: Int64;
  Str: string;
  SS: ShortString;
  Buf: array[0..7] of Byte;
begin
  if not (Dest.Kind in [evMem, evReg]) then Err('The expression cannot be modified');
  if not TypeOf(Dest, T) then Err('Unknown type');
  case T.Kind of
    tkInteger, tkBoolean, tkChar, tkWideChar, tkEnum, tkPointer, tkClassRef, tkObject, tkInterface,
    tkProcedure:
      begin
        if (T.Kind = tkPointer) and T.IsRef then Err('The expression cannot be modified');
        X := LoadInt(Src);
        // an ANSI character into a WideChar: the character it shows, not its code (euro sign: $80 -> U+20AC)
        if (T.Kind = tkWideChar) and (X >= $80) and (X <= $FF) and
          (((Src.Kind = evConst) and (Src.CK in [ecStr, ecChar])) or (TypeOf(Src, ST) and (ST.Kind = tkChar))) then
        begin
          W := ToWide(Chr(Byte(X)), CP_ACP);
          if W <> '' then X := Ord(W[1]);
        end;
        if Dest.Kind = evReg then
        begin
          if not FHost.SetReg(Dest.Reg, Cardinal(X and $FFFFFFFF)) then Err('Cannot write the register');
          Exit;
        end;
        if not (T.Size in [1, 2, 4, 8]) then Err('Unsupported size');
        if (T.Kind = tkInteger) and (T.Leaf = LF_SUBRANGE) and (T.ElemType >= $1000) and
          ((X < T.Low) or (X > T.High)) then
          Err(Format('Value %d is out of range (%d..%d)', [X, T.Low, T.High]));
        Move(X, Buf, 8);
        if not FHost.WriteMem(Dest.Addr, Buf, T.Size) then Err(Format('Cannot write memory at $%.8x', [Dest.Addr]));
      end;
    tkFloat:
      begin
        if Dest.Kind <> evMem then Err('The expression cannot be modified');
        F := LoadFloat(Src);
        case T.FloatKind of
          fkSingle:
            begin
              S4 := F;
              if not FHost.WriteMem(Dest.Addr, S4, 4) then Err('Cannot write memory');
            end;
          fkDouble:
            begin
              D8 := F;
              if not FHost.WriteMem(Dest.Addr, D8, 8) then Err('Cannot write memory');
            end;
          fkExtended:
            if not FHost.WriteMem(Dest.Addr, F, 10) then Err('Cannot write memory');
          fkReal48:
            begin
              R6 := F;
              if not FHost.WriteMem(Dest.Addr, R6, 6) then Err('Cannot write memory');
            end;
        end;
      end;
    tkCurrency:
      begin
        if Dest.Kind <> evMem then Err('The expression cannot be modified');
        C8 := Round(LoadFloat(Src) * 10000);
        if not FHost.WriteMem(Dest.Addr, C8, 8) then Err('Cannot write memory');
      end;
    tkShortString:
      begin
        if Dest.Kind <> evMem then Err('The expression cannot be modified');
        Str := LoadStr(Src);
        if (T.Size > 0) and (Length(Str) > T.Size - 1) then
          Err(Format('The string is too long (maximum %d characters)', [T.Size - 1]));
        SS := Str;
        if not FHost.WriteMem(Dest.Addr, SS, Length(SS) + 1) then Err('Cannot write memory');
      end;
    tkAnsiString, tkWideString, tkDynArray:
      Err('Long strings and dynamic arrays cannot be modified (that needs memory allocation in the program)');
  else
    Err('Values of this type cannot be modified');
  end;
end;

{ public API }

function TDbgEvaluator.Evaluate(const Expr: string; out V: TDbgVar; out Error: string): Boolean;
var
  Val: TEvValue;
begin
  Result := EvaluateTo(Expr, V, Error, Val);
end;

{ Evaluate, and the value itself (Val) for what is read of it after its text }
function TDbgEvaluator.EvaluateTo(const Expr: string; out V: TDbgVar; out Error: string; out Val: TEvValue): Boolean;
var
  S, Spec: string;
  I: Integer;
begin
  Result := False;
  InitValue(Val);
  Error := '';
  V.Name := Expr;
  V.Value := '';
  V.TypeName := '';
  V.Expandable := False;
  V.Address := 0;
  V.Size := 0;
  V.CanModify := False;
  FFmt := #0;
  FFrameReady := False;
  // optional format specifier: "expr,x" - only letters follow the last comma
  S := Trim(Expr);
  I := Length(S);
  while (I > 0) and (S[I] in ['A'..'Z', 'a'..'z', ' ']) do Dec(I);
  if (I > 0) and (S[I] = ',') then
  begin
    Spec := LowerCase(Trim(Copy(S, I + 1, MaxInt)));
    if Spec = 'h' then Spec := 'x';
    if (Spec = 'x') or (Spec = 'd') or (Spec = 'c') or (Spec = 'p') or (Spec = 's') then
    begin
      FFmt := Spec[1];
      S := Trim(Copy(S, 1, I - 1));
    end;
  end;
  // the expression without the specifier: GetChildren gets it to expand the item
  V.Expr := S;
  try
    Val := EvalText(S);
    V.TypeName := TypeNameOf(Val);
    V.Value := FormatValue(Val, 0);
    V.Expandable := HasChildren(Val);
    if Val.Kind = evMem then V.Address := Val.Addr;
    if Val.TypeIdx <> 0 then V.Size := SizeOfType(Val.Info, Val.TypeIdx);
    if V.Size < 0 then V.Size := 0;
    V.CanModify := Val.Kind in [evMem, evReg];
    Result := True;
  except
    on E: EDbgEval do Error := E.Message;
    on E: Exception do Error := 'Evaluation failed: ' + E.Message;
  end;
  FFmt := #0;
end;

function TDbgEvaluator.EvalBoolean(const Expr: string; out Value: Boolean; out Error: string): Boolean;
var
  Val: TEvValue;
begin
  Result := False;
  Value := False;
  Error := '';
  FFmt := #0;
  FFrameReady := False;
  try
    Val := EvalText(Expr);
    if IsFloatValue(Val) then
      Value := LoadFloat(Val) <> 0
    else
      Value := LoadInt(Val) <> 0;
    Result := True;
  except
    on E: EDbgEval do Error := E.Message;
    on E: Exception do Error := 'Evaluation failed: ' + E.Message;
  end;
end;

{ Expr's value seen through references (SeenThrough) }
function TDbgEvaluator.Inspected(const Expr: string; out Val: TEvValue; out T: TTDTypeInfo): Boolean;
begin
  Val := EvalText(Expr);
  Result := SeenThrough(Val, T);
end;

{ Val seen through references (var parameters, Self), T its type: False for a nil reference, which
  has no children or members }
function TDbgEvaluator.SeenThrough(var Val: TEvValue; out T: TTDTypeInfo): Boolean;
var
  P: Cardinal;
  Guard: Integer;
begin
  Result := False;
  Guard := 0;
  while (Guard < 4) and TypeOf(Val, T) and (T.Kind = tkPointer) and T.IsRef do
  begin
    Inc(Guard);
    P := LoadPtr(Val);
    if P = 0 then Exit;
    Val := MemValue(Val.Info, Val.Base, P, T.ElemType);
  end;
  if not TypeOf(Val, T) then Err('Unknown type');
  Result := True;
end;

{ the rows of the parts of Val (of type T, the value of Expr): fields, elements, what it points to }
procedure TDbgEvaluator.ChildRows(const Val: TEvValue; const T: TTDTypeInfo; const Expr: string; Rows: TVarRows);
var
  E: TTDTypeInfo;
  P, Len, Dyn: Cardinal;
  I, ES, N: Integer;
begin
  case T.Kind of
    tkRecord, tkClass:
      if Val.Kind = evMem then
        CollectFields(Val.Info, Val.Base, Val.TypeIdx, Val.Addr, Expr, Rows, 0);
    tkObject:
      begin
        P := LoadPtr(Val);
        if P <> 0 then
        begin
          if not DynamicClass(Val.Info, P, Dyn) then Dyn := T.ElemType;
          CollectFields(Val.Info, Val.Base, Dyn, P, Expr, Rows, 0);
        end;
      end;
    tkArray:
      if Val.Kind = evMem then
      begin
        ES := SizeOfType(Val.Info, T.ElemType);
        if (T.Count > 0) and (T.Size > 0) then ES := T.Size div T.Count;
        if ES <= 0 then Err('Unknown array element size');
        N := T.Count;
        if N > MAX_CHILDREN then N := MAX_CHILDREN;
        for I := 0 to N - 1 do
          AddVar(Rows, Format('[%d]', [T.Low + I]), ChildExpr(Expr, Format('[%d]', [T.Low + I])),
            MemValue(Val.Info, Val.Base, Val.Addr + Cardinal(I * ES), T.ElemType));
      end;
    tkDynArray, tkOpenArray:
      begin
        if (T.Kind = tkOpenArray) and (T.Leaf <> LF_POINTER) then P := Val.Addr else P := LoadPtr(Val);
        if P <> 0 then
        begin
          if T.Kind = tkDynArray then
            Len := LenAt(P)
          else if Val.HighKnown then
            Len := Val.HighValue + 1
          else
            Len := 0;
          ES := SizeOfType(Val.Info, T.ElemType);
          if ES <= 0 then Err('Unknown array element size');
          N := Len;
          if (N > MAX_CHILDREN) or (N < 0) then N := MAX_CHILDREN;
          for I := 0 to N - 1 do
            AddVar(Rows, Format('[%d]', [I]), ChildExpr(Expr, Format('[%d]', [I])),
              MemValue(Val.Info, Val.Base, P + Cardinal(I * ES), T.ElemType));
        end;
      end;
    tkPointer:
      begin
        P := LoadPtr(Val);
        if (P <> 0) and GetT(Val.Info, T.ElemType, E) and not (E.Kind in [tkVoid, tkUnknown]) then
          AddVar(Rows, ChildExpr(Expr, '^'), ChildExpr(Expr, '^'), MemValue(Val.Info, Val.Base, P, T.ElemType));
      end;
  end;
end;

{ the methods and properties of Val (of type T, the value of Expr): an object's, as its own class
  has them, or a record's }
procedure TDbgEvaluator.MemberRows(const Val: TEvValue; const T: TTDTypeInfo; const Expr: string; Dynamic: Boolean;
  MRows, PRows: TVarRows);
var
  ClassIdx, Addr: Cardinal;
begin
  case T.Kind of
    tkRecord, tkClass:
      if Val.Kind = evMem then
        CollectMembers(Val.Info, Val.Base, Val.TypeIdx, Val.Addr, Expr, Dynamic, MRows, PRows, 0);
    tkObject:
      begin
        Addr := LoadPtr(Val);
        if Addr <> 0 then
        begin
          if not DynamicClass(Val.Info, Addr, ClassIdx) then ClassIdx := T.ElemType;
          CollectMembers(Val.Info, Val.Base, ClassIdx, Addr, Expr, Dynamic, MRows, PRows, 0);
        end;
      end;
  end;
end;

function TDbgEvaluator.GetChildren(const Expr: string; out Vars: TDbgVarArray; out Error: string): Boolean;
var
  Val: TEvValue;
  T: TTDTypeInfo;
  Rows: TVarRows;
begin
  Result := False;
  Vars := nil;
  Error := '';
  FFmt := #0;
  FFrameReady := False;
  Rows := TVarRows.Create(False);
  try
    try
      if not Inspected(Expr, Val, T) then
      begin
        Result := True;
        Exit;
      end;
      ChildRows(Val, T, Expr, Rows);
      Rows.Finish(Vars);
      Result := True;
    except
      on Ex: EDbgEval do Error := Ex.Message;
      on Ex: Exception do Error := 'Evaluation failed: ' + Ex.Message;
    end;
  finally
    Rows.Free;
  end;
end;

function TDbgEvaluator.GetMembers(const Expr: string; Dynamic: Boolean; out Methods, Props: TDbgVarArray;
  out Error: string): Boolean;
var
  Val: TEvValue;
  T: TTDTypeInfo;
  MRows, PRows: TVarRows;
begin
  Result := False;
  Methods := nil;
  Props := nil;
  Error := '';
  FFmt := #0;
  FFrameReady := False;
  FAllowCalls := Dynamic;
  MRows := TVarRows.Create(True);
  PRows := TVarRows.Create(True);
  try
    try
      if Inspected(Expr, Val, T) then MemberRows(Val, T, Expr, Dynamic, MRows, PRows);
      MRows.Finish(Methods);
      PRows.Finish(Props);
      Result := True;
    except
      on Ex: EDbgEval do Error := Ex.Message;
      on Ex: Exception do Error := 'Evaluation failed: ' + Ex.Message;
    end;
  finally
    MRows.Free;
    PRows.Free;
  end;
end;

{ the value's text as Evaluate gives it; its parts and members as GetChildren and GetMembers give
  them for the expression without its format specifier (V.Expr), each part on its own: one that
  cannot be read leaves its rows empty (the error of the last one in Error) }
function TDbgEvaluator.Inspect(const Expr: string; Dynamic: Boolean; out V: TDbgVar; out Children, Methods,
  Props: TDbgVarArray; out Error: string): Boolean;
var
  Val: TEvValue;
  T: TTDTypeInfo;
  Seen: Boolean;
  Rows, MRows, PRows: TVarRows;
begin
  Children := nil;
  Methods := nil;
  Props := nil;
  Result := EvaluateTo(Expr, V, Error, Val);
  if not Result then Exit;
  Rows := TVarRows.Create(False);
  MRows := TVarRows.Create(True);
  PRows := TVarRows.Create(True);
  try
    Seen := False;
    try
      Seen := SeenThrough(Val, T);
      if Seen and V.Expandable then
      begin
        ChildRows(Val, T, V.Expr, Rows);
        Rows.Finish(Children);
      end;
    except
      on Ex: EDbgEval do Error := Ex.Message;
      on Ex: Exception do Error := 'Evaluation failed: ' + Ex.Message;
    end;
    if Seen then
      try
        MemberRows(Val, T, V.Expr, Dynamic, MRows, PRows);
        MRows.Finish(Methods);
        PRows.Finish(Props);
      except
        on Ex: EDbgEval do Error := Ex.Message;
        on Ex: Exception do Error := 'Evaluation failed: ' + Ex.Message;
      end;
  finally
    Rows.Free;
    MRows.Free;
    PRows.Free;
  end;
end;

function TDbgEvaluator.GetLocals(out Vars: TDbgVarArray): Boolean;
var
  I, Idx, N: Integer;
  Nm: string;
  R: TDbgVar;
  Rows: TVarRows;
begin
  Vars := nil;
  Result := False;
  FFmt := #0;
  FFrameReady := False;
  Rows := TVarRows.Create(True);
  try
    try
      InitFrame;
      if (FFrameInfo = nil) or (FFrameProc < 0) then Exit;
      for I := 0 to High(FFrameSyms) do
        if (FFrameSyms[I].Kind = S_BPREL32) or (FFrameSyms[I].Kind = S_REGISTER) then
        begin
          Nm := FFrameInfo.NameStr(FFrameSyms[I].NameIdx);
          if (Nm = '') or (Nm[1] = '$') then Continue;      // compiler temporaries
          // several locals with one name: show only the live one
          if Rows.Find(Nm) >= 0 then Continue;
          if not PickLocal(Nm, FFrameSyms, Idx) then Idx := I;
          // a local that cannot be shown gets its message; the others are still listed
          try
            R := MakeVar(Nm, Nm, SymValue(FFrameInfo, FFrameBase, FFrameSyms[Idx], FHost.FrameEBP, FHost.FrameEIP,
              FHost.IsTopFrame));
          except
            on E: Exception do
            begin
              R.Name := Nm;
              R.Expr := Nm;
              R.Value := '<' + E.Message + '>';
              R.TypeName := FFrameInfo.TypeName(FFrameSyms[Idx].TypeIdx);
              R.Expandable := False;
            end;
          end;
          N := Rows.Add(Nm);
          Rows.Vars[N] := R;
        end;
      Rows.Finish(Vars);
      Result := True;
    except
      on E: Exception do Result := False;
    end;
  finally
    Rows.Free;
  end;
end;

function TDbgEvaluator.Modify(const Expr, NewValue: string; out Error: string): Boolean;
var
  Dest, Src: TEvValue;
begin
  Result := False;
  Error := '';
  FFmt := #0;
  FFrameReady := False;
  try
    Dest := EvalText(Expr);
    Src := EvalText(NewValue);
    StoreValue(Dest, Src);
    Result := True;
  except
    on E: EDbgEval do Error := E.Message;
    on E: Exception do Error := 'Modify failed: ' + E.Message;
  end;
end;

end.
