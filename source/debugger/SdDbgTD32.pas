{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDbgTD32;

{ D7 Studio debugger - symbol information.

  Reader for the Borland TD32/TDS debug information ("FB09"/"FB0A") that
  dcc32 -V appends to an EXE/DLL/BPL (.debug section), plus a fallback loader
  for detailed .map files (dcc32 -GD) giving publics and line numbers only.

  All addresses handed out by this unit are RVAs (relative to the image base).

  Layout notes (verified against real Delphi 7 output):
    * header: 'FB09', DWORD offset of subsection directory (both relative to
      the header itself, which is also referenced by a trailer in the last
      8 bytes of the file: signature + distance from end of file)
    * directory: Word hdrSize, Word entrySize, DWORD count, ...; entries
      (Word type, Word module, DWORD offset, DWORD size)
    * sstModule $120, sstAlignSym $125, sstSrcModule $127, sstGlobalTypes $12B,
      sstNames $130.  Names are referenced by 1-based index everywhere.
    * segment numbers are 1-based PE section numbers; segment 2 (DATA) offsets
      run on into BSS (they are image offsets from the DATA section start).
}

interface

uses
  Windows, SysUtils, Classes;

const
  { symbol record kinds }
  S_COMPILE    = $0001;
  S_REGISTER   = $0002;
  S_CONST      = $0003;
  S_UDT        = $0004;
  S_SSEARCH    = $0005;
  S_END        = $0006;
  S_OBJNAME    = $0009;
  S_USES       = $0024;
  S_NAMESPACE  = $0025;
  S_USING      = $0026;
  S_PCONSTANT  = $0027;
  S_BPREL32    = $0200;
  S_LDATA32    = $0201;
  S_GDATA32    = $0202;
  S_PUB32      = $0203;
  S_LPROC32    = $0204;
  S_GPROC32    = $0205;
  S_THUNK32    = $0206;
  S_BLOCK32    = $0207;
  S_WITH32     = $0208;
  S_LABEL32    = $0209;
  S_OPTVAR32   = $0211;
  S_SLINK32    = $0230;

  { type leaves }
  LF_MODIFIER   = $0001;
  LF_POINTER    = $0002;
  LF_ARRAY      = $0003;
  LF_CLASS      = $0004;
  LF_STRUCTURE  = $0005;
  LF_UNION      = $0006;
  LF_ENUM       = $0007;
  LF_PROCEDURE  = $0008;
  LF_MFUNCTION  = $0009;
  LF_VTSHAPE    = $000A;
  LF_SET        = $0030;
  LF_SUBRANGE   = $0031;
  LF_PARRAY     = $0032;
  LF_PSTRING    = $0033;
  LF_CLOSURE    = $0034;
  LF_PROPERTY   = $0035;
  LF_LSTRING    = $0036;
  LF_VARIANT    = $0037;
  LF_CLASSREF   = $0038;
  LF_WSTRING    = $0039;
  LF_ARGLIST    = $0201;
  LF_FIELDLIST  = $0204;
  LF_METHODLIST = $0207;
  LF_BCLASS     = $0400;
  LF_VBCLASS    = $0401;
  LF_IVBCLASS   = $0402;
  LF_ENUMERATE  = $0403;
  LF_FRIENDFCN  = $0404;
  LF_INDEX      = $0405;
  LF_MEMBER     = $0406;
  LF_STMEMBER   = $0407;
  LF_METHOD     = $0408;
  LF_NESTTYPE   = $0409;
  LF_VFUNCTAB   = $040A;
  LF_FRIENDCLS  = $040B;

  { primitive type indices (mode 0) }
  T_NOTYPE   = $00;
  T_VOID     = $03;
  T_CURRENCY = $04;
  T_CHAR     = $10;
  T_SHORT    = $11;
  T_LONG     = $12;
  T_QUAD     = $13;
  T_UCHAR    = $20;
  T_USHORT   = $21;
  T_ULONG    = $22;
  T_UQUAD    = $23;
  T_BOOL08   = $30;
  T_BOOL16   = $31;
  T_BOOL32   = $32;
  T_BOOL64   = $33;
  T_REAL32   = $40;
  T_REAL64   = $41;
  T_REAL80   = $42;
  T_REAL48   = $44;
  T_PASCHAR  = $61;
  T_RCHAR    = $70;
  T_WCHAR    = $71;
  T_INT2     = $72;
  T_UINT2    = $73;
  T_INT4     = $74;
  T_UINT4    = $75;
  T_INT8     = $76;
  T_UINT8    = $77;

  { CodeView register numbers }
  CV_REG_AL = 1;  CV_REG_CL = 2;  CV_REG_DL = 3;  CV_REG_BL = 4;
  CV_REG_AH = 5;  CV_REG_CH = 6;  CV_REG_DH = 7;  CV_REG_BH = 8;
  CV_REG_AX = 9;  CV_REG_CX = 10; CV_REG_DX = 11; CV_REG_BX = 12;
  CV_REG_SP = 13; CV_REG_BP = 14; CV_REG_SI = 15; CV_REG_DI = 16;
  CV_REG_EAX = 17; CV_REG_ECX = 18; CV_REG_EDX = 19; CV_REG_EBX = 20;
  CV_REG_ESP = 21; CV_REG_EBP = 22; CV_REG_ESI = 23; CV_REG_EDI = 24;

  { procedure flags }
  PROCF_NOFRAME = $0002;     // no EBP frame (frameless / assembler routine)

  { the attribute of a method list entry (Borland's bits): a constructor, a destructor - the compiler
    passes both a hidden flag first }
  MA_CONSTRUCTOR = $0400;
  MA_DESTRUCTOR = $0800;

  { property flags }
  PROPF_GETMETHOD = $0002;   // getter is a method (name index) instead of a field offset
  PROPF_SETMETHOD = $0004;   // setter is a method (name index) or absent

type
  TCardinalArray = array of Cardinal;
  TIntegerArray = array of Integer;

  { the order of the items I and J of a table (< 0, 0, > 0) and their exchange: QuickSort }
  TSortCompare = function(I, J: Integer): Integer of object;
  TSortSwap = procedure(I, J: Integer) of object;

  { names in upper case with a number each, sorted by name and then number: the least number of
    a name is a binary search away (TTD32Info.FindProcByName) }
  TNameIndex = class
  private
    FKeys: array of string;
    FValues: TIntegerArray;
    FCount: Integer;
    function Compare(I, J: Integer): Integer;
    procedure Swap(I, J: Integer);
  public
    procedure Add(const Key: string; Value: Integer);
    procedure Sort;
    function Find(const Key: string): Integer;     // the least number of Key (upper case), -1: none
  end;

  TTDTypeKind = (
    tkUnknown, tkVoid, tkInteger, tkBoolean, tkChar, tkWideChar, tkFloat, tkCurrency,
    tkEnum, tkSet, tkPointer, tkClassRef, tkArray, tkDynArray, tkOpenArray,
    tkShortString, tkAnsiString, tkWideString, tkRecord,
    tkClass,        // the instance layout itself (target of an object reference)
    tkObject,       // object reference (pointer to a class instance)
    tkInterface,    // interface reference
    tkProcedure,    // procedural value (code pointer)
    tkMethod,       // method pointer (Code, Data)
    tkVariant, tkProperty);

  TTDFloatKind = (fkSingle, fkDouble, fkExtended, fkReal48);

  TTDTypeInfo = record
    Index: Cardinal;
    Kind: TTDTypeKind;
    Leaf: Word;              // raw leaf, 0 for primitive types
    Size: Integer;           // bytes occupied by a value of the type, -1 = unknown/open
    Signed: Boolean;         // integers
    FloatKind: TTDFloatKind;
    IsRef: Boolean;          // tkPointer: reference (var/const/out parameter, function result slot)
    ElemType: Cardinal;      // pointer target / array element / set base / classref class /
                             // subrange base / object: the LF_CLASS / property type
    IndexType: Cardinal;     // arrays, short strings
    Low, High: Int64;        // bounds: subranges, array index
    Count: Integer;          // array elements, enum members; -1 = open
    FieldList: Cardinal;     // records, classes, enums
    NameIdx: Cardinal;       // declared name (0 = anonymous)
    SetLowByte: Integer;     // sets: ordinal div 8 of the first stored byte
    PropFlags: Word;
    PropGet, PropSet: Cardinal;
    RetType: Cardinal;       // procedures
    ArgList: Cardinal;
    ArgCount: Integer;
  end;

  TTDFieldKind = (fdMember, fdBaseClass, fdEnumerate, fdMethod, fdProperty, fdStatic, fdVFuncTab, fdOther);

  TTDField = record
    Kind: TTDFieldKind;
    NameIdx: Cardinal;
    TypeIdx: Cardinal;
    Offset: Integer;         // members/base classes: byte offset
    Value: Int64;            // enumerates
    Attr: Word;
  end;
  TTDFieldArray = array of TTDField;

  TTDRegRange = record
    Start, Len: Cardinal;    // RVA range
    Reg: Word;
  end;

  TTDSymbol = record
    Kind: Word;              // S_xxx
    NameIdx: Cardinal;
    TypeIdx: Cardinal;
    Offset: Integer;         // S_BPREL32: EBP offset; data: RVA; S_SLINK32: EBP offset of static link
    Reg: Word;               // S_REGISTER (0 = see Ranges)
    Value: Int64;            // constants
    Ranges: array of TTDRegRange;   // S_REGISTER + S_OPTVAR32
    ScopeStart, ScopeLen: Cardinal; // S_WITH32 / symbols inside S_BLOCK32 (RVA); 0/0 = whole procedure
    Flags: Word;
  end;
  TTDSymbolArray = array of TTDSymbol;

  PTDProc = ^TTDProc;
  TTDProc = record
    Module: Integer;         // index into Modules
    NameIdx: Cardinal;
    MapName: Integer;        // index into FMapNames (map fallback) or -1
    Start: Cardinal;         // RVA
    Size: Cardinal;
    DebugStart: Cardinal;    // offset from Start where the frame is set up (= first statement)
    DebugEnd: Cardinal;
    TypeIdx: Cardinal;
    Flags: Word;
    RecOfs: Integer;         // buffer offset of the symbol record
    EndOfs: Integer;         // buffer offset of the matching S_END
    ParentOfs: Integer;      // buffer offset of the enclosing procedure record (nested procs) or 0
    Global: Boolean;
  end;

  TTDLine = record
    Addr: Cardinal;          // RVA of the first byte
    EndAddr: Cardinal;       // RVA one past the last byte
    Line: Integer;
    Src: Integer;            // index into source files
  end;
  PTDLine = ^TTDLine;

  TTDGlobRef = record
    NameIdx: Cardinal;
    RecOfs: Integer;
  end;
  TTDGlobRefArray = array of TTDGlobRef;

  TTDModule = record
    Name: string;
    NameIdx: Cardinal;
    CodeRVA, CodeSize: Cardinal;
    SymOfs, SymSize: Integer;     // sstAlignSym (buffer offsets), 0 = none
    DataOfs: Integer;             // buffer offset of the first module level data symbol, 0 = none
    HasLines: Boolean;
    UsesList: TIntegerArray;      // module indices from S_USES (in the order given)
    GlobsBuilt: Boolean;
    Globs: TTDGlobRefArray;       // module level symbols sorted by NameIdx
  end;

  TTDSrcFile = record
    Name: string;            // as stored (may contain a relative path)
    Module: Integer;
  end;

  TTDSection = record
    VA, VSize, RawPtr, RawSize, Flags: Cardinal;
  end;
  TTDSectionArray = array of TTDSection;

  { what the debugger reads of a PE header (ParsePEHeader) }
  TPEHeaderInfo = record
    EntryRVA, ImageBase, SizeOfImage: Cardinal;
    ExportRVA, ExportSize: Cardinal;      // 0: no export directory
    Sections: TTDSectionArray;            // as far as the buffer holds them
  end;

  TTD32Info = class
  private
    FBuf: PChar;
    FBufSize: Integer;
    FHasTD32: Boolean;
    FIsMap: Boolean;
    FMapSizes: Boolean;
    FTypeDepth: Integer;               // recursion guard for self-referential type records
    FNameDepth: Integer;
    FFileName: string;
    FSections: TTDSectionArray;
    FImageBase: Cardinal;
    FSizeOfImage: Cardinal;
    FEntryRVA: Cardinal;
    FNames: array of Integer;          // buffer offsets of names (length byte)
    FNameCount: Integer;
    FNameHashBuilt: Boolean;
    FNameBuckets: TIntegerArray;
    FNameNext: TIntegerArray;
    FModules: array of TTDModule;
    FSrcFiles: array of TTDSrcFile;
    FLines: array of TTDLine;          // sorted by Addr
    FLineCount: Integer;
    FLinesBySrc: TIntegerArray;        // indices into FLines sorted by (Src, Line, Addr)
    FProcs: array of TTDProc;          // sorted by Start
    FProcCount: Integer;
    FTypeBase: Integer;                // buffer offset of sstGlobalTypes
    FTypeCount: Integer;
    FUdtBuilt: Boolean;
    FUdtTypes: TCardinalArray;         // sorted type indices having a UDT name
    FUdtNames: TCardinalArray;
    FMapNames: TStringList;            // map fallback: public names
    FMapGlobals: TStringList;          // map fallback: data publics (Objects = RVA)
    FClassCacheBuilt: Boolean;
    FClassNames: TCardinalArray;       // name index of every LF_CLASS/LF_STRUCTURE
    FClassTypes: TCardinalArray;
    FClassKind: array of Byte;         // per type index: 0 unknown, 1 class, 2 interface
    { FindProcByName's index and FindGlobal's of a map file, made at the first search - by the debug
      thread or the IDE's (the evaluator runs on both): under the lock }
    FProcIndexLock: TRTLCriticalSection;
    FProcIndexBuilt: Boolean;
    FProcFull, FProcShort: TNameIndex; // 'UNIT.TCLASS.METHOD' / 'TCLASS.METHOD' -> procedure
    FMapIndex: TNameIndex;             // map fallback: FMapGlobals' names in upper case -> their index
    function InBuf(Ofs, Size: Integer): Boolean;
    function RB(Ofs: Integer): Byte;
    function RW(Ofs: Integer): Word;
    function RD(Ofs: Integer): Cardinal;
    function TypeSlot(Idx: Cardinal): Integer;
    function SegOfsToRVA(Seg: Word; Ofs: Cardinal): Cardinal;
    function ReadNumeric(var Ofs: Integer): Int64;
    procedure ParseDirectory(Base: Integer);
    function ReadBlock(const FileName: string): Boolean;
    procedure ParseModule(Ofs, Size, ModIdx: Integer);
    procedure ParseSrcModule(Ofs, Size, ModIdx: Integer);
    procedure ParseModuleSyms(ModIdx: Integer);
    procedure AddProc(const P: TTDProc);
    procedure AddLine(Addr, EndAddr: Cardinal; Line, Src: Integer);
    procedure FinishTables;
    function CompareProcs(I, J: Integer): Integer;
    procedure SwapProcs(I, J: Integer);
    function CompareLines(I, J: Integer): Integer;
    procedure SwapLines(I, J: Integer);
    function CompareLinesBySrc(I, J: Integer): Integer;
    procedure SwapLinesBySrc(I, J: Integer);
    procedure BuildNameHash;
    procedure BuildProcIndex;
    procedure BuildMapIndex;
    function QualifiedName(Index: Integer; const Short: string): string;
    procedure BuildModuleGlobs(ModIdx: Integer);
    function FindGlobRec(const Name: string; PreferModule: Integer; OnlyModule, Udt: Boolean;
      out RecOfs, ModIdx: Integer): Boolean;
    procedure BuildUdtMap;
    procedure BuildClassCache;
    function TypeRecOfs(Idx: Cardinal): Integer;
    function DecodeDataSym(Ofs: Integer; out Sym: TTDSymbol): Boolean;
    function DoGetType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
    function DoTypeName(Idx: Cardinal): string;
    function GetModule(Index: Integer): TTDModule;
    function GetSrcName(Index: Integer): string;
    function GetSrcModule(Index: Integer): Integer;
    function GetProc(Index: Integer): PTDProc;
    function GetLine(Index: Integer): PTDLine;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { Loads TD32 info from an EXE/DLL/BPL. False if the file has none. }
    function LoadFromFile(const FileName: string): Boolean;
    { Loads publics and line numbers from a detailed map file; ExeName supplies the section table. }
    function LoadFromMap(const MapName, ExeName: string): Boolean;
    { Reads the PE header only (sections, image base). }
    function LoadPEInfo(const FileName: string): Boolean;
    { The debug information of an executable: its TD32 information - in the file, else in the
      file TD32SideFile names for it -, else its detailed map file (<name>.map), else the PE
      header alone. True when there are line numbers. }
    function LoadAny(const ExeName: string): Boolean;
    { an EXE/DLL/BPL's TD32 information, in the file or kept apart (TD32SideFile) }
    function LoadWithSide(const FileName: string): Boolean;

    property HasTD32: Boolean read FHasTD32;
    property IsMap: Boolean read FIsMap;
    property FileName: string read FFileName;
    property ImageBase: Cardinal read FImageBase;
    property SizeOfImage: Cardinal read FSizeOfImage;
    property EntryRVA: Cardinal read FEntryRVA;            // program entry point (main block of an EXE)
    function HasLineInfo: Boolean;
    function RVAToFileOffset(RVA: Cardinal): Integer;      // -1 when not backed by file data

    { names }
    function NameStr(Idx: Cardinal): string;
    function NameEquals(Idx: Cardinal; const S: string): Boolean;
    function FindNames(const S: string; out Indices: TCardinalArray): Boolean;   // case-insensitive

    { modules (units) }
    function ModuleCount: Integer;
    property Modules[Index: Integer]: TTDModule read GetModule;
    function ModuleByAddr(RVA: Cardinal): Integer;
    function FindModule(const Name: string): Integer;

    { source files and line numbers }
    function SrcCount: Integer;
    property SrcName[Index: Integer]: string read GetSrcName;
    property SrcModule[Index: Integer]: Integer read GetSrcModule;
    function LineCount: Integer;
    property Lines[Index: Integer]: PTDLine read GetLine;
    function LineIndexByAddr(RVA: Cardinal): Integer;                   // -1 if none
    function AddrToLine(RVA: Cardinal; out L: TTDLine): Boolean;
    function LineToAddrs(Src, Line: Integer; out Addrs: TCardinalArray): Boolean;
    procedure GetSrcLines(Src: Integer; List: TList);                   // distinct line numbers with code

    { procedures }
    function ProcCount: Integer;
    property Procs[Index: Integer]: PTDProc read GetProc;
    function ProcByAddr(RVA: Cardinal): Integer;                        // -1 if none
    function ProcByRecOfs(RecOfs: Integer): Integer;
    function ProcName(Index: Integer): string;                          // 'Unit.TClass.Method'
    function ProcShortName(Index: Integer): string;                     // 'TClass.Method'
    function GetProcSymbols(Index: Integer; out Syms: TTDSymbolArray): Boolean;
    { 'Unit.Proc', 'Unit.TClass.Method', else 'Proc' or 'TClass.Method' (letter case aside): the
      first such procedure in address order, -1: none (an index of the names, made at the first
      search) }
    function FindProcByName(const Name: string): Integer;

    { module level symbols: variables, typed constants, constants }
    function FindGlobal(const Name: string; PreferModule: Integer; OnlyModule: Boolean;
      out Sym: TTDSymbol; out ModIdx: Integer): Boolean;
    function FindGlobalAddr(const UnitName, Name: string; out RVA: Cardinal): Boolean;
    function FindUDT(const Name: string; PreferModule: Integer; out TypeIdx: Cardinal): Boolean;

    { types }
    function TypeCount: Integer;                                        // indices $1000 .. $1000 + TypeCount - 1
    function GetType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
    function GetFields(FieldList: Cardinal; out Fields: TTDFieldArray): Boolean;
    function GetArgs(ArgList: Cardinal; out Args: TCardinalArray): Boolean;
    function TypeName(Idx: Cardinal): string;
    { a method of a class by its method list (LF_METHODLIST, the type of each overload): the
      first one's 'procedure(TObject)', 'function(Integer): Boolean', 'constructor(TComponent)';
      'method' when unknown }
    function MethodSignature(MList: Cardinal): string;
    { the first overload of a method list: its attribute (MA_CONSTRUCTOR, MA_DESTRUCTOR) and its
      LF_MFUNCTION type }
    function MethodEntry(MList: Cardinal; out Attr: Word; out TypeIdx: Cardinal): Boolean;
    function FindClassType(const AClassName: string; out ClassIdx: Cardinal): Boolean;  // LF_CLASS index
    function IsInterfaceClass(ClassIdx: Cardinal): Boolean;
    function EnumName(const TI: TTDTypeInfo; Value: Int64; out Name: string): Boolean;
  end;

function CleanProcName(const S: string): string;

{ The PE header in the first Size bytes of an image - read from its file or from the process's
  memory (a module the debugger meets). False when it is none, or too short for the fields;
  every field is checked against Size before it is read. }
function ParsePEHeader(const Buf; Size: Integer; out H: TPEHeaderInfo): Boolean;

{ Type information of a primitive (index < $1000) type; independent of any debug info. }
function GetPrimitiveType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
{ Delphi name of a primitive (index < $1000) type ('Integer', 'PChar', '^Word' ...), '?' if unknown. }
function PrimitiveTypeName(Idx: Cardinal): string;

{ Sorts the items L..R of a table: Compare tells the order of two, Swap exchanges them (a quicksort:
  items that compare equal keep no particular order). Every sort of the debugger goes through it. }
procedure QuickSort(L, R: Integer; Compare: TSortCompare; Swap: TSortSwap);

{ Sorts Keys[L..R] ascending; Values move along with their keys. }
procedure SortPairs(var Keys, Values: array of Cardinal; L, R: Integer);

var
  { the file that holds a program's TD32 block when it is not in the program (D7 Studio moves
    Run's debug information out of the program); '' when there is none. Set by
    the IDE; nil: the block is looked for in the program only }
  TD32SideFile: function(const FileName: string): string = nil;

implementation

const
  SIG_FB09 = $39304246;
  SIG_FB0A = $41304246;

type
  PCardinal = ^Cardinal;
  PWord = ^Word;

function CleanProcName(const S: string): string;
var
  I, P: Integer;
begin
  Result := S;
  if Result = '' then Exit;
  // C++ style decoration: cut at '$'
  P := Pos('$', Result);
  if P > 1 then SetLength(Result, P - 1);
  if (Result[1] = '@') and (Length(Result) > 1) then
  begin
    P := 0;
    for I := 2 to Length(Result) do
      if Result[I] = '@' then
      begin
        P := I;
        Break;
      end;
    if P > 0 then
    begin
      // '@TClass@Method' -> 'TClass.Method'
      Delete(Result, 1, 1);
      for I := 1 to Length(Result) do
        if Result[I] = '@' then Result[I] := '.';
      // '@System@@LStrAsg' style leaves '..' : restore the '@'
      P := Pos('..', Result);
      while P > 0 do
      begin
        Result[P + 1] := '@';
        P := Pos('..', Result);
      end;
    end;
  end;
end;

{ The pivot is an item (P), followed as the exchanges move it: the comparisons and exchanges are
  those of a quicksort that keeps the pivot's value. }
procedure QuickSort(L, R: Integer; Compare: TSortCompare; Swap: TSortSwap);
var
  I, J, P: Integer;
begin
  if L >= R then Exit;
  repeat
    I := L;
    J := R;
    P := (L + R) shr 1;
    repeat
      while Compare(I, P) < 0 do Inc(I);
      while Compare(J, P) > 0 do Dec(J);
      if I <= J then
      begin
        if I <> J then
        begin
          Swap(I, J);
          if P = I then P := J else if P = J then P := I;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(L, J, Compare, Swap);
    L := I;
  until I >= R;
end;

function CompareCardinals(A, B: Cardinal): Integer;
begin
  if A < B then Result := -1 else if A > B then Result := 1 else Result := 0;
end;

type
  TCardinals = array[0..MaxInt div 8] of Cardinal;
  PCardinals = ^TCardinals;

  { SortPairs: two arrays of the caller }
  TPairSorter = class
  public
    Keys, Values: PCardinals;
    function Compare(I, J: Integer): Integer;
    procedure Swap(I, J: Integer);
  end;

  { BuildModuleGlobs: a module's table (the array itself: the module record is not touched) }
  TGlobSorter = class
  public
    Globs: TTDGlobRefArray;
    function Compare(I, J: Integer): Integer;
    procedure Swap(I, J: Integer);
  end;

function TPairSorter.Compare(I, J: Integer): Integer;
begin
  Result := CompareCardinals(Keys^[I], Keys^[J]);
end;

procedure TPairSorter.Swap(I, J: Integer);
var
  T: Cardinal;
begin
  T := Keys^[I]; Keys^[I] := Keys^[J]; Keys^[J] := T;
  T := Values^[I]; Values^[I] := Values^[J]; Values^[J] := T;
end;

function TGlobSorter.Compare(I, J: Integer): Integer;
begin
  Result := CompareCardinals(Globs[I].NameIdx, Globs[J].NameIdx);
end;

procedure TGlobSorter.Swap(I, J: Integer);
var
  T: TTDGlobRef;
begin
  T := Globs[I];
  Globs[I] := Globs[J];
  Globs[J] := T;
end;

procedure SortPairs(var Keys, Values: array of Cardinal; L, R: Integer);
var
  S: TPairSorter;
begin
  if L >= R then Exit;
  S := TPairSorter.Create;
  try
    S.Keys := @Keys[0];
    S.Values := @Values[0];
    QuickSort(L, R, S.Compare, S.Swap);
  finally
    S.Free;
  end;
end;

{ TNameIndex }

procedure TNameIndex.Add(const Key: string; Value: Integer);
begin
  if FCount >= Length(FKeys) then
  begin
    if FCount = 0 then SetLength(FKeys, 256) else SetLength(FKeys, FCount * 2);
    SetLength(FValues, Length(FKeys));
  end;
  FKeys[FCount] := Key;
  FValues[FCount] := Value;
  Inc(FCount);
end;

function TNameIndex.Compare(I, J: Integer): Integer;
begin
  Result := CompareStr(FKeys[I], FKeys[J]);
  if Result = 0 then Result := FValues[I] - FValues[J];
end;

procedure TNameIndex.Swap(I, J: Integer);
var
  S: string;
  V: Integer;
begin
  S := FKeys[I]; FKeys[I] := FKeys[J]; FKeys[J] := S;
  V := FValues[I]; FValues[I] := FValues[J]; FValues[J] := V;
end;

procedure TNameIndex.Sort;
begin
  QuickSort(0, FCount - 1, Compare, Swap);
end;

function TNameIndex.Find(const Key: string): Integer;
var
  L, H, M, C: Integer;
begin
  Result := -1;
  L := 0;
  H := FCount - 1;
  while L <= H do
  begin
    M := (L + H) shr 1;
    C := CompareStr(FKeys[M], Key);
    if C < 0 then
      L := M + 1
    else
    begin
      if C = 0 then Result := FValues[M];      // the leftmost one is the least number
      H := M - 1;
    end;
  end;
end;

function UpHash(P: PChar; Len: Integer): Cardinal;
var
  I: Integer;
  C: Byte;
begin
  Result := 2166136261;
  for I := 0 to Len - 1 do
  begin
    C := Byte(P[I]);
    if (C >= Ord('a')) and (C <= Ord('z')) then Dec(C, 32);
    Result := (Result xor C) * 16777619;
  end;
end;

{ TTD32Info }

constructor TTD32Info.Create;
begin
  inherited Create;
  InitializeCriticalSection(FProcIndexLock);
  FMapNames := TStringList.Create;
  FMapGlobals := TStringList.Create;
end;

destructor TTD32Info.Destroy;
begin
  Clear;
  FMapNames.Free;
  FMapGlobals.Free;
  DeleteCriticalSection(FProcIndexLock);
  inherited Destroy;
end;

procedure TTD32Info.Clear;
begin
  if FBuf <> nil then FreeMem(FBuf);
  FBuf := nil;
  FBufSize := 0;
  FHasTD32 := False;
  FIsMap := False;
  FNames := nil;
  FNameCount := 0;
  FNameHashBuilt := False;
  FNameBuckets := nil;
  FNameNext := nil;
  FModules := nil;
  FSrcFiles := nil;
  FLines := nil;
  FLineCount := 0;
  FLinesBySrc := nil;
  FProcs := nil;
  FProcCount := 0;
  FTypeBase := 0;
  FTypeCount := 0;
  FUdtBuilt := False;
  FUdtTypes := nil;
  FUdtNames := nil;
  FClassCacheBuilt := False;
  FClassNames := nil;
  FClassTypes := nil;
  FClassKind := nil;
  FProcIndexBuilt := False;
  FreeAndNil(FProcFull);
  FreeAndNil(FProcShort);
  FreeAndNil(FMapIndex);
  FMapNames.Clear;
  FMapGlobals.Clear;
end;

{ The Size bytes at Ofs lie in the buffer. Offsets come from the file and may be anything:
  "Ofs + Size <= FBufSize" would overflow for an offset close to MaxInt and pass. }
function TTD32Info.InBuf(Ofs, Size: Integer): Boolean;
begin
  Result := (Ofs >= 0) and (Size >= 0) and (Ofs <= FBufSize - Size);
end;

function TTD32Info.RB(Ofs: Integer): Byte;
begin
  if InBuf(Ofs, 1) then
    Result := Byte(FBuf[Ofs])
  else
    Result := 0;
end;

function TTD32Info.RW(Ofs: Integer): Word;
begin
  if InBuf(Ofs, 2) then
    Result := PWord(FBuf + Ofs)^
  else
    Result := 0;
end;

function TTD32Info.RD(Ofs: Integer): Cardinal;
begin
  if InBuf(Ofs, 4) then
    Result := PCardinal(FBuf + Ofs)^
  else
    Result := 0;
end;

function TTD32Info.SegOfsToRVA(Seg: Word; Ofs: Cardinal): Cardinal;
begin
  if (Seg >= 1) and (Seg <= Length(FSections)) then
    Result := FSections[Seg - 1].VA + Ofs
  else
    Result := Ofs;
end;

function TTD32Info.ReadNumeric(var Ofs: Integer): Int64;
var
  W: Word;
begin
  W := RW(Ofs);
  Inc(Ofs, 2);
  if W < $8000 then
  begin
    Result := W;
    Exit;
  end;
  case W of
    $8000: begin Result := ShortInt(RB(Ofs)); Inc(Ofs, 1); end;
    $8001: begin Result := SmallInt(RW(Ofs)); Inc(Ofs, 2); end;
    $8002: begin Result := RW(Ofs); Inc(Ofs, 2); end;
    $8003: begin Result := Integer(RD(Ofs)); Inc(Ofs, 4); end;
    $8004: begin Result := RD(Ofs); Inc(Ofs, 4); end;
    $8005: begin Result := 0; Inc(Ofs, 4); end;
    $8006: begin Result := 0; Inc(Ofs, 8); end;
    $8007: begin Result := 0; Inc(Ofs, 10); end;
    $8008: begin Result := 0; Inc(Ofs, 16); end;
    $8009, $800A:
      begin
        Result := Int64(RD(Ofs)) or (Int64(RD(Ofs + 4)) shl 32);
        Inc(Ofs, 8);
      end;
    $800B: begin Result := 0; Inc(Ofs, 6); end;
  else
    Result := 0;
  end;
end;

function ParsePEHeader(const Buf; Size: Integer; out H: TPEHeaderInfo): Boolean;
var
  B: PByteArray;
  PE, Opt, OptSize, NSec, I, O: Integer;

  function U32(Ofs: Integer): Cardinal;
  begin
    Result := PCardinal(@B[Ofs])^;
  end;

begin
  Result := False;
  FillChar(H, SizeOf(H) - SizeOf(H.Sections), 0);
  H.Sections := nil;
  B := @Buf;
  if (Size < $40) or (B[0] <> Ord('M')) or (B[1] <> Ord('Z')) then Exit;
  PE := PInteger(@B[$3C])^;
  { the signature, the file header (20 bytes) and the optional header up to SizeOfImage }
  if (PE <= 0) or (PE > Size - (24 + 60)) or (U32(PE) <> $00004550) then Exit;
  NSec := PWord(@B[PE + 6])^;
  OptSize := PWord(@B[PE + 20])^;
  Opt := PE + 24;
  H.EntryRVA := U32(Opt + 16);
  H.ImageBase := U32(Opt + 28);
  H.SizeOfImage := U32(Opt + 56);
  { the export directory: the first data directory (NumberOfRvaAndSizes at 92) }
  if (OptSize >= 104) and (Opt + 104 <= Size) and (U32(Opt + 92) >= 1) then
  begin
    H.ExportRVA := U32(Opt + 96);
    H.ExportSize := U32(Opt + 100);
  end;
  SetLength(H.Sections, NSec);
  for I := 0 to NSec - 1 do
  begin
    O := Opt + OptSize + I * 40;
    if O > Size - 40 then
    begin
      SetLength(H.Sections, I);
      Break;
    end;
    H.Sections[I].VSize := U32(O + 8);
    H.Sections[I].VA := U32(O + 12);
    H.Sections[I].RawSize := U32(O + 16);
    H.Sections[I].RawPtr := U32(O + 20);
    H.Sections[I].Flags := U32(O + 36);
  end;
  Result := True;
end;

function TTD32Info.LoadPEInfo(const FileName: string): Boolean;
var
  FS: TFileStream;
  Hdr: array[0..4095] of Byte;
  N: Integer;
  H: TPEHeaderInfo;
begin
  Result := False;
  FSections := nil;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      N := FS.Read(Hdr, SizeOf(Hdr));
    finally
      FS.Free;
    end;
    if not ParsePEHeader(Hdr, N, H) then Exit;
    FEntryRVA := H.EntryRVA;
    FImageBase := H.ImageBase;
    FSizeOfImage := H.SizeOfImage;
    FSections := H.Sections;
    Result := Length(FSections) > 0;
  except
    Result := False;
  end;
end;

function TTD32Info.LoadAny(const ExeName: string): Boolean;
begin
  // both loaders read the PE header first and keep it when they find nothing more
  if not LoadWithSide(ExeName) then LoadFromMap(ChangeFileExt(ExeName, '.map'), ExeName);
  Result := HasLineInfo;
end;

function TTD32Info.LoadWithSide(const FileName: string): Boolean;
var
  Side: string;
begin
  Result := LoadFromFile(FileName);
  if Result or not Assigned(TD32SideFile) or (Length(FSections) = 0) then Exit;
  Side := TD32SideFile(FileName);
  Result := (Side <> '') and ReadBlock(Side);
end;

function TTD32Info.LoadFromFile(const FileName: string): Boolean;
begin
  Result := False;
  Clear;
  FFileName := FileName;
  if not LoadPEInfo(FileName) then Exit;
  Result := ReadBlock(FileName);
end;

{ the TD32 block at the end of a file ('FB09'/'FB0A' and its length last) - the program's own,
  or the file D7 Studio keeps it in; the PE header is the program's (read first) }
function TTD32Info.ReadBlock(const FileName: string): Boolean;
var
  FS: TFileStream;
  Tail: array[0..1] of Cardinal;
  FileSize, BaseOfs, Len: Integer;
  Hdr: array[0..1] of Cardinal;
begin
  Result := False;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      FileSize := FS.Size;
      if FileSize < 64 then Exit;
      FS.Position := FileSize - 8;
      FS.ReadBuffer(Tail, 8);
      if (Tail[0] <> SIG_FB09) and (Tail[0] <> SIG_FB0A) then Exit;
      if (Tail[1] < 16) or (Tail[1] > Cardinal(FileSize)) then Exit;
      BaseOfs := FileSize - Integer(Tail[1]);
      FS.Position := BaseOfs;
      FS.ReadBuffer(Hdr, 8);
      if (Hdr[0] <> SIG_FB09) and (Hdr[0] <> SIG_FB0A) then Exit;
      Len := FileSize - BaseOfs;
      GetMem(FBuf, Len + 16);
      FBufSize := Len;
      FS.Position := BaseOfs;
      FS.ReadBuffer(FBuf^, Len);
      FillChar((FBuf + Len)^, 16, 0);
    finally
      FS.Free;
    end;
    ParseDirectory(0);
    FinishTables;
    FHasTD32 := True;
    Result := True;
  except
    Clear;
    Result := False;
  end;
end;

procedure TTD32Info.ParseDirectory(Base: Integer);
var
  DirOfs, HdrSize, EntSize, Count, I, E, MaxMod, M: Integer;
  SubType, ModIdx: Word;
  Ofs, Size: Integer;
  NamesOfs, P, J, Pass: Integer;
begin
  DirOfs := Base + Integer(RD(Base + 4));
  HdrSize := RW(DirOfs);
  EntSize := RW(DirOfs + 2);
  Count := RD(DirOfs + 4);
  // divided, not multiplied: Count * EntSize overflows for a damaged count
  if (HdrSize < 16) or (EntSize < 12) or (Count <= 0) or not InBuf(DirOfs, HdrSize) or
    (Count > (FBufSize - DirOfs - HdrSize) div EntSize) then
    raise Exception.Create('Bad TD32 directory');
  // pass 1: names + module count
  MaxMod := 0;
  NamesOfs := 0;
  for I := 0 to Count - 1 do
  begin
    E := DirOfs + HdrSize + I * EntSize;
    SubType := RW(E);
    ModIdx := RW(E + 2);
    if (SubType = $120) and (ModIdx > MaxMod) then MaxMod := ModIdx;
    if SubType = $130 then NamesOfs := Base + Integer(RD(E + 4));
    if SubType = $12B then
    begin
      FTypeBase := Base + Integer(RD(E + 4));
      FTypeCount := RD(FTypeBase + 4);
      if (FTypeCount < 0) or not InBuf(FTypeBase, 8) or (FTypeCount > (FBufSize - FTypeBase - 8) div 4) then
        FTypeCount := 0;
    end;
  end;
  if NamesOfs <> 0 then
  begin
    FNameCount := RD(NamesOfs);
    // a name takes two bytes at least (length, terminator)
    if (FNameCount < 0) or (FNameCount > FBufSize div 2) then FNameCount := 0;
    SetLength(FNames, FNameCount);
    P := NamesOfs + 4;
    for J := 0 to FNameCount - 1 do
    begin
      // the whole name must lie in the buffer: NameStr and the name hash read it directly
      if not InBuf(P, 1) or not InBuf(P, Byte(FBuf[P]) + 1) then
      begin
        FNameCount := J;
        Break;
      end;
      FNames[J] := P;
      Inc(P, Byte(FBuf[P]) + 2);
    end;
  end;
  SetLength(FModules, MaxMod);
  // pass 2: modules; pass 3: line tables and symbols (need module info)
  for Pass := 2 to 3 do
    for I := 0 to Count - 1 do
    begin
      E := DirOfs + HdrSize + I * EntSize;
      SubType := RW(E);
      M := RW(E + 2) - 1;
      Ofs := Base + Integer(RD(E + 4));
      Size := RD(E + 8);
      if (M < 0) or (M >= MaxMod) or not InBuf(Ofs, Size) then Continue;
      if Pass = 2 then
        case SubType of
          $120: ParseModule(Ofs, Size, M);
          $124, $125:
            begin
              FModules[M].SymOfs := Ofs;
              FModules[M].SymSize := Size;
            end;
        end
      else if SubType = $127 then
        ParseSrcModule(Ofs, Size, M);
    end;
  for I := 0 to MaxMod - 1 do
    if FModules[I].SymOfs <> 0 then ParseModuleSyms(I);
end;

procedure TTD32Info.ParseModule(Ofs, Size, ModIdx: Integer);
var
  SegCount, I, O: Integer;
begin
  SegCount := RW(Ofs + 4);
  FModules[ModIdx].NameIdx := RD(Ofs + 8);
  FModules[ModIdx].Name := NameStr(FModules[ModIdx].NameIdx);
  for I := 0 to SegCount - 1 do
  begin
    O := Ofs + 28 + I * 12;
    if O + 12 > Ofs + Size then Break;
    if (RW(O + 2) and 1) <> 0 then   // code segment
    begin
      FModules[ModIdx].CodeRVA := SegOfsToRVA(RW(O), RD(O + 4));
      FModules[ModIdx].CodeSize := RD(O + 8);
      Break;
    end;
  end;
end;

procedure TTD32Info.ParseSrcModule(Ofs, Size, ModIdx: Integer);
var
  FileCount, F, S, K, FOfs, FSegCount, LOfs, PairCount, Src: Integer;
  Seg: Word;
  A, NextA: Cardinal;
  LineNo: Integer;

  { the N bytes at P lie in the subsection (P comes from the file: no sum that can overflow) }
  function Inside(P, N: Integer): Boolean;
  begin
    Result := (P >= Ofs) and (P - Ofs <= Size - N);
  end;

begin
  FileCount := RW(Ofs);
  for F := 0 to FileCount - 1 do
  begin
    FOfs := Ofs + Integer(RD(Ofs + 4 + F * 4));
    if not Inside(FOfs, 6) then Continue;
    FSegCount := RW(FOfs);
    Src := Length(FSrcFiles);
    SetLength(FSrcFiles, Src + 1);
    FSrcFiles[Src].Name := NameStr(RD(FOfs + 2));
    FSrcFiles[Src].Module := ModIdx;
    for S := 0 to FSegCount - 1 do
    begin
      LOfs := Ofs + Integer(RD(FOfs + 6 + S * 4));
      if not Inside(LOfs, 4) then Continue;
      Seg := RW(LOfs);
      PairCount := RW(LOfs + 2);
      if not Inside(LOfs, 4 + PairCount * 6) then Continue;
      for K := 0 to PairCount - 1 do
      begin
        A := SegOfsToRVA(Seg, RD(LOfs + 4 + K * 4));
        LineNo := RW(LOfs + 4 + PairCount * 4 + K * 2);
        // the range end stored in the table is the address of the last line record, not the
        // end of its code: the last record is sized later from the enclosing procedure
        if K < PairCount - 1 then
          NextA := SegOfsToRVA(Seg, RD(LOfs + 4 + (K + 1) * 4))
        else
          NextA := 0;
        if NextA < A then NextA := 0;       // fixed up after sorting
        AddLine(A, NextA, LineNo, Src);
      end;
      if PairCount > 0 then FModules[ModIdx].HasLines := True;
    end;
  end;
end;

procedure TTD32Info.AddLine(Addr, EndAddr: Cardinal; Line, Src: Integer);
begin
  if FLineCount >= Length(FLines) then
  begin
    if FLineCount = 0 then
      SetLength(FLines, 1024)
    else
      SetLength(FLines, FLineCount * 2);
  end;
  FLines[FLineCount].Addr := Addr;
  FLines[FLineCount].EndAddr := EndAddr;
  FLines[FLineCount].Line := Line;
  FLines[FLineCount].Src := Src;
  Inc(FLineCount);
end;

procedure TTD32Info.AddProc(const P: TTDProc);
begin
  if FProcCount >= Length(FProcs) then
  begin
    if FProcCount = 0 then
      SetLength(FProcs, 1024)
    else
      SetLength(FProcs, FProcCount * 2);
  end;
  FProcs[FProcCount] := P;
  Inc(FProcCount);
end;

procedure TTD32Info.ParseModuleSyms(ModIdx: Integer);
var
  SymBase, SymEnd, P, Len, Guard, UsesCnt, I, M: Integer;
  T: Word;
  Pr: TTDProc;
  NextOfs, PrevOfs: Cardinal;
begin
  SymBase := FModules[ModIdx].SymOfs;
  SymEnd := SymBase + FModules[ModIdx].SymSize;
  P := SymBase + 4;
  if P + 4 > SymEnd then Exit;
  // first record is normally S_SSEARCH: start of the procedure chain + first data symbol
  if RW(P + 2) = S_SSEARCH then
  begin
    NextOfs := RD(P + 4);
    // the record walks over the data symbols start here: only an offset inside the module
    P := SymBase + Integer(RD(P + 14));
    if (P > SymBase) and (P <= SymEnd - 4) then FModules[ModIdx].DataOfs := P;
    PrevOfs := 0;
    Guard := 0;
    while (NextOfs <> 0) and (Guard < 2000000) do
    begin
      Inc(Guard);
      // the chain runs forward through the records: a link back would be a cycle
      if NextOfs <= PrevOfs then Break;
      PrevOfs := NextOfs;
      P := SymBase + Integer(NextOfs);
      if (P < SymBase) or (P > SymEnd - 48) then Break;
      T := RW(P + 2);
      if (T <> S_GPROC32) and (T <> S_LPROC32) then Break;
      FillChar(Pr, SizeOf(Pr), 0);
      Pr.Module := ModIdx;
      Pr.MapName := -1;
      Pr.RecOfs := P;
      if RD(P + 4) <> 0 then Pr.ParentOfs := SymBase + Integer(RD(P + 4));
      Pr.EndOfs := SymBase + Integer(RD(P + 8));
      NextOfs := RD(P + 12);
      Pr.Size := RD(P + 16);
      Pr.DebugStart := RD(P + 20);
      Pr.DebugEnd := RD(P + 24);
      Pr.Start := SegOfsToRVA(RW(P + 32), RD(P + 28));
      Pr.Flags := RW(P + 34);
      Pr.TypeIdx := RD(P + 36);
      Pr.NameIdx := RD(P + 40);
      Pr.Global := T = S_GPROC32;
      if (Pr.EndOfs < P) or (Pr.EndOfs > SymEnd) then Pr.EndOfs := P + RW(P) + 2;
      AddProc(Pr);
    end;
  end;
  // module level records: find S_USES (scan the data area only)
  P := FModules[ModIdx].DataOfs;
  if P = 0 then
  begin
    // no data pointer: scan from the last procedure end
    P := SymBase + 4;
    if FProcCount > 0 then
      for I := FProcCount - 1 downto 0 do
        if FProcs[I].Module = ModIdx then
        begin
          if FProcs[I].EndOfs > P then P := FProcs[I].EndOfs;
        end
        else
          Break;
    FModules[ModIdx].DataOfs := P;
  end;
  Guard := 0;
  while (P >= SymBase) and (P + 4 <= SymEnd) and (Guard < 4000000) do
  begin
    Inc(Guard);
    Len := RW(P);
    if Len < 2 then Break;
    T := RW(P + 2);
    if T = S_USES then
    begin
      UsesCnt := (Len - 2) div 4;
      SetLength(FModules[ModIdx].UsesList, UsesCnt);
      for I := 0 to UsesCnt - 1 do
      begin
        M := Integer(RD(P + 4 + I * 4)) - 1;
        FModules[ModIdx].UsesList[I] := M;
      end;
      Break;
    end;
    Inc(P, Len + 2);
  end;
end;

{ the tables' orders (QuickSort): procedures and lines by address, the lines by source file, line
  and address }

function TTD32Info.CompareProcs(I, J: Integer): Integer;
begin
  Result := CompareCardinals(FProcs[I].Start, FProcs[J].Start);
end;

procedure TTD32Info.SwapProcs(I, J: Integer);
var
  T: TTDProc;
begin
  T := FProcs[I];
  FProcs[I] := FProcs[J];
  FProcs[J] := T;
end;

function TTD32Info.CompareLines(I, J: Integer): Integer;
begin
  Result := CompareCardinals(FLines[I].Addr, FLines[J].Addr);
end;

procedure TTD32Info.SwapLines(I, J: Integer);
var
  T: TTDLine;
begin
  T := FLines[I];
  FLines[I] := FLines[J];
  FLines[J] := T;
end;

function TTD32Info.CompareLinesBySrc(I, J: Integer): Integer;
var
  A, B: PTDLine;
begin
  A := @FLines[FLinesBySrc[I]];
  B := @FLines[FLinesBySrc[J]];
  if A^.Src <> B^.Src then
    Result := A^.Src - B^.Src
  else if A^.Line <> B^.Line then
    Result := A^.Line - B^.Line
  else
    Result := CompareCardinals(A^.Addr, B^.Addr);
end;

procedure TTD32Info.SwapLinesBySrc(I, J: Integer);
var
  T: Integer;
begin
  T := FLinesBySrc[I];
  FLinesBySrc[I] := FLinesBySrc[J];
  FLinesBySrc[J] := T;
end;

procedure TTD32Info.FinishTables;
var
  I, N, PI: Integer;
begin
  SetLength(FProcs, FProcCount);
  QuickSort(0, FProcCount - 1, CompareProcs, SwapProcs);
  if FMapSizes then
    // map file: a routine extends to the next public symbol (or the end of its module)
    for I := 0 to FProcCount - 1 do
    begin
      if I < FProcCount - 1 then
        FProcs[I].Size := FProcs[I + 1].Start - FProcs[I].Start;
      N := FProcs[I].Module;
      if (N >= 0) and ((FProcs[I].Size = 0) or
        (FProcs[I].Start + FProcs[I].Size > FModules[N].CodeRVA + FModules[N].CodeSize)) then
        FProcs[I].Size := FModules[N].CodeRVA + FModules[N].CodeSize - FProcs[I].Start;
    end;
  SetLength(FLines, FLineCount);
  QuickSort(0, FLineCount - 1, CompareLines, SwapLines);
  // remove exact duplicates (same address), fix up end addresses
  N := 0;
  for I := 0 to FLineCount - 1 do
  begin
    if (N > 0) and (FLines[N - 1].Addr = FLines[I].Addr) then
    begin
      // keep the later record's line if the earlier one is empty
      if FLines[N - 1].EndAddr <= FLines[N - 1].Addr then FLines[N - 1] := FLines[I];
      Continue;
    end;
    FLines[N] := FLines[I];
    Inc(N);
  end;
  FLineCount := N;
  SetLength(FLines, FLineCount);
  for I := 0 to FLineCount - 1 do
  begin
    if FLines[I].EndAddr <= FLines[I].Addr then
    begin
      // last record of a line table: runs to the end of its procedure
      PI := ProcByAddr(FLines[I].Addr);
      if (PI >= 0) and (FProcs[PI].Size > 0) then
        FLines[I].EndAddr := FProcs[PI].Start + FProcs[PI].Size
      else
        FLines[I].EndAddr := FLines[I].Addr + 1;
    end;
    if (I < FLineCount - 1) and (FLines[I].EndAddr > FLines[I + 1].Addr) then
      FLines[I].EndAddr := FLines[I + 1].Addr;
  end;
  SetLength(FLinesBySrc, FLineCount);
  for I := 0 to FLineCount - 1 do FLinesBySrc[I] := I;
  QuickSort(0, FLineCount - 1, CompareLinesBySrc, SwapLinesBySrc);
end;

function TTD32Info.HasLineInfo: Boolean;
begin
  Result := FLineCount > 0;
end;

function TTD32Info.RVAToFileOffset(RVA: Cardinal): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FSections) do
    if (RVA >= FSections[I].VA) and (RVA < FSections[I].VA + FSections[I].RawSize) then
    begin
      Result := Integer(FSections[I].RawPtr + (RVA - FSections[I].VA));
      Exit;
    end;
end;

{ names }

function TTD32Info.NameStr(Idx: Cardinal): string;
var
  O: Integer;
begin
  // compared unsigned: name indices come from the file
  if (Idx > 0) and (Idx <= Cardinal(FNameCount)) then
  begin
    O := FNames[Idx - 1];
    SetString(Result, FBuf + O + 1, Byte(FBuf[O]));
  end
  else
    Result := '';
end;

function TTD32Info.NameEquals(Idx: Cardinal; const S: string): Boolean;
var
  O, L: Integer;
begin
  Result := False;
  if (Idx > 0) and (Idx <= Cardinal(FNameCount)) then
  begin
    O := FNames[Idx - 1];
    L := Byte(FBuf[O]);
    if L <> Length(S) then Exit;
    Result := (L = 0) or (StrLIComp(FBuf + O + 1, PChar(S), L) = 0);
  end;
end;

procedure TTD32Info.BuildNameHash;
var
  Size, I, O: Integer;
  H: Cardinal;
begin
  if FNameHashBuilt then Exit;
  Size := 1024;
  while Size < FNameCount * 2 do Size := Size * 2;
  SetLength(FNameBuckets, Size);
  SetLength(FNameNext, FNameCount);
  for I := 0 to Size - 1 do FNameBuckets[I] := -1;
  for I := 0 to FNameCount - 1 do
  begin
    O := FNames[I];
    H := UpHash(FBuf + O + 1, Byte(FBuf[O])) and Cardinal(Size - 1);
    FNameNext[I] := FNameBuckets[H];
    FNameBuckets[H] := I;
  end;
  FNameHashBuilt := True;
end;

function TTD32Info.FindNames(const S: string; out Indices: TCardinalArray): Boolean;
var
  H: Cardinal;
  I, O, L, N: Integer;
begin
  Indices := nil;
  Result := False;
  if (FNameCount = 0) or (S = '') then Exit;
  BuildNameHash;
  L := Length(S);
  H := UpHash(PChar(S), L) and Cardinal(Length(FNameBuckets) - 1);
  I := FNameBuckets[H];
  N := 0;
  while I >= 0 do
  begin
    O := FNames[I];
    if (Byte(FBuf[O]) = L) and (StrLIComp(FBuf + O + 1, PChar(S), L) = 0) then
    begin
      SetLength(Indices, N + 1);
      Indices[N] := I + 1;
      Inc(N);
    end;
    I := FNameNext[I];
  end;
  Result := N > 0;
end;

{ modules }

function TTD32Info.ModuleCount: Integer;
begin
  Result := Length(FModules);
end;

function TTD32Info.GetModule(Index: Integer): TTDModule;
begin
  Result := FModules[Index];
end;

function TTD32Info.ModuleByAddr(RVA: Cardinal): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FModules) do
    if (FModules[I].CodeSize > 0) and (RVA >= FModules[I].CodeRVA) and
      (RVA < FModules[I].CodeRVA + FModules[I].CodeSize) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TTD32Info.FindModule(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FModules) do
    if SameText(FModules[I].Name, Name) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ source files / lines }

function TTD32Info.SrcCount: Integer;
begin
  Result := Length(FSrcFiles);
end;

function TTD32Info.GetSrcName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FSrcFiles)) then
    Result := FSrcFiles[Index].Name
  else
    Result := '';
end;

function TTD32Info.GetSrcModule(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < Length(FSrcFiles)) then
    Result := FSrcFiles[Index].Module
  else
    Result := -1;
end;

function TTD32Info.LineCount: Integer;
begin
  Result := FLineCount;
end;

function TTD32Info.GetLine(Index: Integer): PTDLine;
begin
  Result := @FLines[Index];
end;

function TTD32Info.LineIndexByAddr(RVA: Cardinal): Integer;
var
  L, H, M: Integer;
begin
  Result := -1;
  L := 0;
  H := FLineCount - 1;
  while L <= H do
  begin
    M := (L + H) shr 1;
    if FLines[M].Addr <= RVA then
    begin
      Result := M;
      L := M + 1;
    end
    else
      H := M - 1;
  end;
  if (Result >= 0) and (RVA >= FLines[Result].EndAddr) then Result := -1;
end;

function TTD32Info.AddrToLine(RVA: Cardinal; out L: TTDLine): Boolean;
var
  I: Integer;
begin
  I := LineIndexByAddr(RVA);
  Result := I >= 0;
  if Result then
    L := FLines[I]
  else
    FillChar(L, SizeOf(L), 0);
end;

function TTD32Info.LineToAddrs(Src, Line: Integer; out Addrs: TCardinalArray): Boolean;
var
  L, H, M, First, N, I: Integer;
  P: PTDLine;
begin
  Addrs := nil;
  First := -1;
  L := 0;
  H := FLineCount - 1;
  while L <= H do
  begin
    M := (L + H) shr 1;
    P := @FLines[FLinesBySrc[M]];
    if (P^.Src < Src) or ((P^.Src = Src) and (P^.Line < Line)) then
      L := M + 1
    else
    begin
      if (P^.Src = Src) and (P^.Line = Line) then First := M;
      H := M - 1;
    end;
  end;
  N := 0;
  if First >= 0 then
  begin
    I := First;
    while I < FLineCount do
    begin
      P := @FLines[FLinesBySrc[I]];
      if (P^.Src <> Src) or (P^.Line <> Line) then Break;
      SetLength(Addrs, N + 1);
      Addrs[N] := P^.Addr;
      Inc(N);
      Inc(I);
    end;
  end;
  Result := N > 0;
end;

procedure TTD32Info.GetSrcLines(Src: Integer; List: TList);
var
  L, H, M, First, I, Last: Integer;
  P: PTDLine;
begin
  First := FLineCount;
  L := 0;
  H := FLineCount - 1;
  while L <= H do
  begin
    M := (L + H) shr 1;
    P := @FLines[FLinesBySrc[M]];
    if P^.Src < Src then
      L := M + 1
    else
    begin
      if P^.Src = Src then First := M;
      H := M - 1;
    end;
  end;
  Last := -1;
  I := First;
  while I < FLineCount do
  begin
    P := @FLines[FLinesBySrc[I]];
    if P^.Src <> Src then Break;
    if P^.Line <> Last then
    begin
      List.Add(Pointer(P^.Line));
      Last := P^.Line;
    end;
    Inc(I);
  end;
end;

{ procedures }

function TTD32Info.ProcCount: Integer;
begin
  Result := FProcCount;
end;

function TTD32Info.GetProc(Index: Integer): PTDProc;
begin
  if (Index >= 0) and (Index < FProcCount) then
    Result := @FProcs[Index]
  else
    Result := nil;
end;

function TTD32Info.ProcByAddr(RVA: Cardinal): Integer;
var
  L, H, M: Integer;
begin
  Result := -1;
  L := 0;
  H := FProcCount - 1;
  while L <= H do
  begin
    M := (L + H) shr 1;
    if FProcs[M].Start <= RVA then
    begin
      Result := M;
      L := M + 1;
    end
    else
      H := M - 1;
  end;
  if Result >= 0 then
  begin
    if FProcs[Result].Size = 0 then
    begin
      // map fallback: size unknown, bounded by the next public / module end
      if (Result + 1 < FProcCount) and (RVA >= FProcs[Result + 1].Start) then Result := -1;
    end
    else if RVA >= FProcs[Result].Start + FProcs[Result].Size then
      Result := -1;
  end;
end;

function TTD32Info.ProcByRecOfs(RecOfs: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to FProcCount - 1 do
    if FProcs[I].RecOfs = RecOfs then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TTD32Info.ProcShortName(Index: Integer): string;
begin
  Result := '';
  if (Index < 0) or (Index >= FProcCount) then Exit;
  if FProcs[Index].MapName >= 0 then
    Result := FMapNames[FProcs[Index].MapName]
  else
    Result := CleanProcName(NameStr(FProcs[Index].NameIdx));
end;

{ the short name of procedure Index with its unit's name before it }
function TTD32Info.QualifiedName(Index: Integer; const Short: string): string;
var
  M: Integer;
begin
  Result := Short;
  if Result = '' then Exit;
  M := FProcs[Index].Module;
  if (M >= 0) and (M < Length(FModules)) and (FModules[M].Name <> '') then
    Result := FModules[M].Name + '.' + Result;
end;

function TTD32Info.ProcName(Index: Integer): string;
begin
  Result := QualifiedName(Index, ProcShortName(Index));
end;

{ every procedure's name with and without its unit (the evaluator's calls search per module, per
  class and its ancestors: two passes over all names each time were too slow) }
procedure TTD32Info.BuildProcIndex;
var
  I: Integer;
  Full, Short: TNameIndex;
  S: string;
begin
  if FProcIndexBuilt then Exit;
  EnterCriticalSection(FProcIndexLock);
  try
    if FProcIndexBuilt then Exit;
    Full := TNameIndex.Create;
    Short := TNameIndex.Create;
    try
      for I := 0 to FProcCount - 1 do
      begin
        S := ProcShortName(I);
        Short.Add(UpperCase(S), I);
        Full.Add(UpperCase(QualifiedName(I, S)), I);
      end;
      Full.Sort;
      Short.Sort;
    except
      Full.Free;
      Short.Free;
      raise;
    end;
    FProcFull := Full;
    FProcShort := Short;
    FProcIndexBuilt := True;     // last: the other thread reads the index once this is set
  finally
    LeaveCriticalSection(FProcIndexLock);
  end;
end;

{ the data publics of a map file by name: the least index of a name is its first public, the one
  a search of FMapGlobals in its order finds (a linear search compared every name at each lookup) }
procedure TTD32Info.BuildMapIndex;
var
  I: Integer;
  Index: TNameIndex;
begin
  if FMapIndex <> nil then Exit;
  EnterCriticalSection(FProcIndexLock);
  try
    if FMapIndex <> nil then Exit;
    Index := TNameIndex.Create;
    try
      for I := 0 to FMapGlobals.Count - 1 do Index.Add(UpperCase(FMapGlobals[I]), I);
      Index.Sort;
    except
      Index.Free;
      raise;
    end;
    FMapIndex := Index;          // last: the other thread reads the index once this is set
  finally
    LeaveCriticalSection(FProcIndexLock);
  end;
end;

{ a unit's name before the routine is a qualified name ('Unit.Proc' = the unit's name and the
  short name), so the qualified names are searched first and the short names after them; SameText
  compares as UpperCase does (ASCII letters) }
function TTD32Info.FindProcByName(const Name: string): Integer;
var
  K: string;
begin
  BuildProcIndex;
  K := UpperCase(Name);
  Result := FProcFull.Find(K);
  if Result < 0 then Result := FProcShort.Find(K);
end;

function TTD32Info.DecodeDataSym(Ofs: Integer; out Sym: TTDSymbol): Boolean;
var
  T: Word;
  O: Integer;
begin
  FillChar(Sym, SizeOf(Sym), 0);
  Sym.Ranges := nil;
  T := RW(Ofs + 2);
  Sym.Kind := T;
  Result := True;
  case T of
    S_BPREL32:
      begin
        Sym.Offset := Integer(RD(Ofs + 4));
        Sym.TypeIdx := RD(Ofs + 8);
        Sym.NameIdx := RD(Ofs + 12);
      end;
    S_REGISTER:
      begin
        Sym.TypeIdx := RD(Ofs + 4);
        Sym.Reg := RW(Ofs + 8);
        Sym.NameIdx := RD(Ofs + 10);
      end;
    S_LDATA32, S_GDATA32, S_PUB32:
      begin
        Sym.Offset := Integer(SegOfsToRVA(RW(Ofs + 8), RD(Ofs + 4)));
        Sym.Flags := RW(Ofs + 10);
        Sym.TypeIdx := RD(Ofs + 12);
        Sym.NameIdx := RD(Ofs + 16);
      end;
    S_PCONSTANT, S_CONST:
      begin
        Sym.TypeIdx := RD(Ofs + 4);
        Sym.Flags := RW(Ofs + 8);
        Sym.NameIdx := RD(Ofs + 10);
        O := Ofs + 18;
        Sym.Value := ReadNumeric(O);
      end;
    S_UDT:
      begin
        Sym.TypeIdx := RD(Ofs + 4);
        Sym.Flags := RW(Ofs + 8);
        Sym.NameIdx := RD(Ofs + 10);
      end;
    S_WITH32:
      begin
        Sym.ScopeLen := RD(Ofs + 8);
        Sym.ScopeStart := RD(Ofs + 12);    // procedure relative; fixed up by the caller
        Sym.TypeIdx := RD(Ofs + 20);
        Sym.NameIdx := RD(Ofs + 24);
      end;
    S_SLINK32:
      Sym.Offset := Integer(RD(Ofs + 4));
  else
    Result := False;
  end;
end;

function TTD32Info.GetProcSymbols(Index: Integer; out Syms: TTDSymbolArray): Boolean;
var
  P, EndP, Len, N, I, RangeCnt, Depth, Guard: Integer;
  T: Word;
  S: TTDSymbol;
  ProcStart: Cardinal;
  BlockStart, BlockLen: array[0..15] of Cardinal;
begin
  Syms := nil;
  Result := False;
  if (Index < 0) or (Index >= FProcCount) or not FHasTD32 then Exit;
  if FProcs[Index].RecOfs = 0 then Exit;
  P := FProcs[Index].RecOfs;
  EndP := FProcs[Index].EndOfs;
  ProcStart := FProcs[Index].Start;
  Inc(P, RW(P) + 2);
  N := 0;
  Depth := 0;
  Guard := 0;
  while (P < EndP) and (P + 4 <= FBufSize) and (Guard < 100000) do
  begin
    Inc(Guard);
    Len := RW(P);
    if Len < 2 then Break;
    T := RW(P + 2);
    case T of
      S_END:
        if Depth > 0 then Dec(Depth);
      S_BLOCK32:
        begin
          // parent(4) end(4) length(4) offset(4) seg(2) ... : nested lexical block
          if Depth < 16 then
          begin
            BlockLen[Depth] := RD(P + 12);
            BlockStart[Depth] := SegOfsToRVA(RW(P + 20), RD(P + 16));
          end;
          Inc(Depth);
        end;
      S_OPTVAR32:
        if (N > 0) and (Syms[N - 1].Kind = S_REGISTER) then
        begin
          RangeCnt := RW(P + 4);
          if 6 + RangeCnt * 10 <= Len + 2 then
          begin
            SetLength(Syms[N - 1].Ranges, RangeCnt);
            for I := 0 to RangeCnt - 1 do
            begin
              Syms[N - 1].Ranges[I].Start := ProcStart + RD(P + 6 + I * 10);
              Syms[N - 1].Ranges[I].Len := RD(P + 10 + I * 10);
              Syms[N - 1].Ranges[I].Reg := RW(P + 14 + I * 10);
            end;
          end;
        end;
    else
      if DecodeDataSym(P, S) then
      begin
        if T = S_WITH32 then
          S.ScopeStart := ProcStart + S.ScopeStart
        else if (Depth > 0) and (Depth <= 16) then
        begin
          S.ScopeStart := BlockStart[Depth - 1];
          S.ScopeLen := BlockLen[Depth - 1];
        end;
        if N >= Length(Syms) then
          if N = 0 then SetLength(Syms, 16) else SetLength(Syms, N * 2);
        Syms[N] := S;
        Inc(N);
      end;
    end;
    Inc(P, Len + 2);
  end;
  SetLength(Syms, N);
  Result := True;
end;

{ module level symbols }

procedure TTD32Info.BuildModuleGlobs(ModIdx: Integer);
var
  P, EndP, Len, N, Cap, Guard: Integer;
  T: Word;
  NameIdx: Cardinal;
  Sorter: TGlobSorter;
begin
  if FModules[ModIdx].GlobsBuilt then Exit;
  if (FModules[ModIdx].SymOfs = 0) or (FModules[ModIdx].DataOfs = 0) then
  begin
    FModules[ModIdx].GlobsBuilt := True;
    Exit;
  end;
  P := FModules[ModIdx].DataOfs;
  EndP := FModules[ModIdx].SymOfs + FModules[ModIdx].SymSize;
  N := 0;
  Cap := 0;
  Guard := 0;
  while (P + 4 <= EndP) and (Guard < 4000000) do
  begin
    Inc(Guard);
    Len := RW(P);
    if Len < 2 then Break;
    T := RW(P + 2);
    NameIdx := 0;
    case T of
      S_LDATA32, S_GDATA32, S_PUB32: NameIdx := RD(P + 16);
      S_PCONSTANT, S_CONST, S_UDT: NameIdx := RD(P + 10);
    end;
    if NameIdx <> 0 then
    begin
      if N >= Cap then
      begin
        if Cap = 0 then Cap := 64 else Cap := Cap * 2;
        SetLength(FModules[ModIdx].Globs, Cap);
      end;
      FModules[ModIdx].Globs[N].NameIdx := NameIdx;
      FModules[ModIdx].Globs[N].RecOfs := P;
      Inc(N);
    end;
    Inc(P, Len + 2);
  end;
  SetLength(FModules[ModIdx].Globs, N);
  Sorter := TGlobSorter.Create;
  try
    Sorter.Globs := FModules[ModIdx].Globs;     // the same array (dynamic arrays are references)
    QuickSort(0, N - 1, Sorter.Compare, Sorter.Swap);
  finally
    Sorter.Free;
  end;
  // only now: a build cut short by an exception would leave an unsorted table for good
  FModules[ModIdx].GlobsBuilt := True;
end;

{ The module level symbol Name: a type (Udt) or anything else, in the preferred module, then (not
  OnlyModule) in the units it uses in the order of its uses list, then in all modules from the
  last one on; RecOfs its record. FindGlobal and FindUDT search this way. }
function TTD32Info.FindGlobRec(const Name: string; PreferModule: Integer; OnlyModule, Udt: Boolean;
  out RecOfs, ModIdx: Integer): Boolean;
var
  NameIdx: TCardinalArray;

  function Search(M: Integer): Boolean;
  var
    K, L, H, Mid, First: Integer;
  begin
    Result := False;
    if (M < 0) or (M >= Length(FModules)) then Exit;
    BuildModuleGlobs(M);
    for K := 0 to High(NameIdx) do
    begin
      First := -1;
      L := 0;
      H := High(FModules[M].Globs);
      while L <= H do
      begin
        Mid := (L + H) shr 1;
        if FModules[M].Globs[Mid].NameIdx < NameIdx[K] then
          L := Mid + 1
        else
        begin
          if FModules[M].Globs[Mid].NameIdx = NameIdx[K] then First := Mid;
          H := Mid - 1;
        end;
      end;
      if First >= 0 then
        while (First <= High(FModules[M].Globs)) and (FModules[M].Globs[First].NameIdx = NameIdx[K]) do
        begin
          if (RW(FModules[M].Globs[First].RecOfs + 2) = S_UDT) = Udt then
          begin
            RecOfs := FModules[M].Globs[First].RecOfs;
            ModIdx := M;
            Result := True;
            Exit;
          end;
          Inc(First);
        end;
    end;
  end;

var
  I, J: Integer;
begin
  Result := True;
  RecOfs := 0;
  ModIdx := -1;
  if not FindNames(Name, NameIdx) then
    Result := False
  else if Search(PreferModule) then
    Exit
  else if OnlyModule then
    Result := False
  else
  begin
    if (PreferModule >= 0) and (PreferModule < Length(FModules)) then
      for I := 0 to High(FModules[PreferModule].UsesList) do
      begin
        J := FModules[PreferModule].UsesList[I];
        if (J <> PreferModule) and Search(J) then Exit;
      end;
    for I := High(FModules) downto 0 do
      if (I <> PreferModule) and Search(I) then Exit;
    Result := False;
  end;
end;

function TTD32Info.FindGlobal(const Name: string; PreferModule: Integer; OnlyModule: Boolean;
  out Sym: TTDSymbol; out ModIdx: Integer): Boolean;
var
  Idx, RecOfs: Integer;
  V: Cardinal;
begin
  Result := False;
  ModIdx := -1;
  FillChar(Sym, SizeOf(Sym), 0);
  Sym.Ranges := nil;
  if FIsMap then
  begin
    { the names are Pascal identifiers: upper case compares them as IndexOf did }
    BuildMapIndex;
    Idx := FMapIndex.Find(UpperCase(Name));
    if Idx >= 0 then
    begin
      Sym.Kind := S_GDATA32;
      V := Cardinal(FMapGlobals.Objects[Idx]);
      Sym.Offset := Integer(V);
      ModIdx := 0;
      Result := True;
    end;
    Exit;
  end;
  Result := FindGlobRec(Name, PreferModule, OnlyModule, False, RecOfs, ModIdx) and DecodeDataSym(RecOfs, Sym);
  if not Result then ModIdx := -1;
end;

function TTD32Info.FindGlobalAddr(const UnitName, Name: string; out RVA: Cardinal): Boolean;
var
  Sym: TTDSymbol;
  M, Found: Integer;
begin
  RVA := 0;
  M := -1;
  if UnitName <> '' then M := FindModule(UnitName);
  Result := FindGlobal(Name, M, (UnitName <> '') and (M >= 0) and not FIsMap, Sym, Found) and
    ((Sym.Kind = S_GDATA32) or (Sym.Kind = S_LDATA32) or (Sym.Kind = S_PUB32));
  if Result then RVA := Cardinal(Sym.Offset);
end;

function TTD32Info.FindUDT(const Name: string; PreferModule: Integer; out TypeIdx: Cardinal): Boolean;
var
  RecOfs, M: Integer;
begin
  TypeIdx := 0;
  Result := not FIsMap and FindGlobRec(Name, PreferModule, False, True, RecOfs, M);
  if Result then TypeIdx := RD(RecOfs + 4);
end;

{ types }

function TTD32Info.TypeCount: Integer;
begin
  Result := FTypeCount;
end;

function TTD32Info.TypeSlot(Idx: Cardinal): Integer;
begin
  // compared unsigned: an index of $80001000 or more read from the file is no negative slot
  if (Idx >= $1000) and (Idx - $1000 < Cardinal(FTypeCount)) then
    Result := Integer(Idx - $1000)
  else
    Result := -1;
end;

function TTD32Info.TypeRecOfs(Idx: Cardinal): Integer;
var
  O, Slot: Integer;
begin
  Result := 0;
  Slot := TypeSlot(Idx);
  if (Slot < 0) or (FTypeBase = 0) then Exit;
  O := FTypeBase + Integer(RD(FTypeBase + 8 + Slot * 4));
  if (O <= FTypeBase) or not InBuf(O, 4) then Exit;
  Result := O;
end;

function GetPrimitiveType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
var
  Base, Mode: Cardinal;
begin
  FillChar(TI, SizeOf(TI), 0);
  TI.Index := Idx;
  TI.Size := -1;
  TI.Count := -1;
  Result := True;
  Base := Idx and $FF;
  Mode := (Idx shr 8) and 7;
  if Mode <> 0 then
  begin
    TI.Kind := tkPointer;
    TI.Size := 4;
    TI.ElemType := Base;
    Exit;
  end;
  case Base of
    T_NOTYPE: begin TI.Kind := tkUnknown; TI.Size := -1; Result := Idx = 0; end;
    T_VOID: begin TI.Kind := tkVoid; TI.Size := 0; end;
    T_CURRENCY: begin TI.Kind := tkCurrency; TI.Size := 8; end;
    T_CHAR: begin TI.Kind := tkInteger; TI.Size := 1; TI.Signed := True; end;
    T_SHORT, T_INT2: begin TI.Kind := tkInteger; TI.Size := 2; TI.Signed := True; end;
    T_LONG, T_INT4: begin TI.Kind := tkInteger; TI.Size := 4; TI.Signed := True; end;
    T_QUAD, T_INT8: begin TI.Kind := tkInteger; TI.Size := 8; TI.Signed := True; end;
    T_UCHAR: begin TI.Kind := tkInteger; TI.Size := 1; end;
    T_USHORT, T_UINT2: begin TI.Kind := tkInteger; TI.Size := 2; end;
    T_ULONG, T_UINT4: begin TI.Kind := tkInteger; TI.Size := 4; end;
    T_UQUAD, T_UINT8: begin TI.Kind := tkInteger; TI.Size := 8; end;
    T_BOOL08: begin TI.Kind := tkBoolean; TI.Size := 1; end;
    T_BOOL16: begin TI.Kind := tkBoolean; TI.Size := 2; end;
    T_BOOL32: begin TI.Kind := tkBoolean; TI.Size := 4; end;
    T_BOOL64: begin TI.Kind := tkBoolean; TI.Size := 8; end;
    T_REAL32: begin TI.Kind := tkFloat; TI.Size := 4; TI.FloatKind := fkSingle; end;
    T_REAL64: begin TI.Kind := tkFloat; TI.Size := 8; TI.FloatKind := fkDouble; end;
    T_REAL80: begin TI.Kind := tkFloat; TI.Size := 10; TI.FloatKind := fkExtended; end;
    T_REAL48: begin TI.Kind := tkFloat; TI.Size := 6; TI.FloatKind := fkReal48; end;
    T_PASCHAR, T_RCHAR: begin TI.Kind := tkChar; TI.Size := 1; end;
    T_WCHAR: begin TI.Kind := tkWideChar; TI.Size := 2; end;
  else
    TI.Kind := tkUnknown;
    TI.Size := -1;
    Result := False;
  end;
end;

function PrimitiveTypeName(Idx: Cardinal): string;
begin
  if ((Idx shr 8) and 7) <> 0 then
  begin
    case Idx and $FF of
      T_VOID: Result := 'Pointer';
      T_PASCHAR, T_RCHAR: Result := 'PChar';
      T_WCHAR: Result := 'PWideChar';
    else
      Result := '^' + PrimitiveTypeName(Idx and $FF);
    end;
    Exit;
  end;
  case Idx and $FF of
    T_VOID: Result := 'void';
    T_CURRENCY: Result := 'Currency';
    T_CHAR: Result := 'Shortint';
    T_SHORT, T_INT2: Result := 'Smallint';
    T_LONG, T_INT4: Result := 'Integer';
    T_QUAD, T_INT8: Result := 'Int64';
    T_UCHAR: Result := 'Byte';
    T_USHORT, T_UINT2: Result := 'Word';
    T_ULONG, T_UINT4: Result := 'Cardinal';
    T_UQUAD, T_UINT8: Result := 'UInt64';
    T_BOOL08: Result := 'Boolean';
    T_BOOL16: Result := 'WordBool';
    T_BOOL32: Result := 'LongBool';
    T_REAL32: Result := 'Single';
    T_REAL64: Result := 'Double';
    T_REAL80: Result := 'Extended';
    T_REAL48: Result := 'Real48';
    T_PASCHAR, T_RCHAR: Result := 'Char';
    T_WCHAR: Result := 'WideChar';
  else
    Result := '?';
  end;
end;

function TTD32Info.GetType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
begin
  if FTypeDepth > 24 then
  begin
    // a type that (directly or not) refers to itself
    GetPrimitiveType(0, TI);
    TI.Index := Idx;
    Result := False;
    Exit;
  end;
  Inc(FTypeDepth);
  try
    Result := DoGetType(Idx, TI);
  finally
    Dec(FTypeDepth);
  end;
end;

function TTD32Info.DoGetType(Idx: Cardinal; out TI: TTDTypeInfo): Boolean;
var
  O, P, Len, Guard: Integer;
  Leaf, Attr: Word;
  Base, Idx2: TTDTypeInfo;
  S: string;
  V: Int64;
begin
  FillChar(TI, SizeOf(TI), 0);
  TI.Index := Idx;
  TI.Size := -1;
  TI.Count := -1;
  Result := False;
  if Idx < $1000 then
  begin
    Result := GetPrimitiveType(Idx, TI);
    Exit;
  end;
  if not FHasTD32 then Exit;
  Guard := 0;
  O := TypeRecOfs(Idx);
  // skip modifiers
  while (O <> 0) and (RW(O + 2) = LF_MODIFIER) and (Guard < 8) do
  begin
    Inc(Guard);
    Idx := RD(O + 6);
    if Idx < $1000 then
    begin
      Result := GetPrimitiveType(Idx, TI);
      Exit;
    end;
    O := TypeRecOfs(Idx);
  end;
  if O = 0 then Exit;
  Len := RW(O);
  Leaf := RW(O + 2);
  TI.Leaf := Leaf;
  P := O + 4;
  Result := True;
  case Leaf of
    LF_POINTER:
      begin
        Attr := RW(P);
        TI.ElemType := RD(P + 2);
        TI.Size := 4;
        TI.IsRef := ((Attr shr 5) and 7) = 1;
        TI.Kind := tkPointer;
        if TI.ElemType >= $1000 then
        begin
          O := TypeRecOfs(TI.ElemType);
          if O <> 0 then
            case RW(O + 2) of
              LF_CLASS:
                if TI.IsRef then
                begin
                  TI.IsRef := False;
                  if IsInterfaceClass(TI.ElemType) then
                    TI.Kind := tkInterface
                  else
                    TI.Kind := tkObject;
                  TI.NameIdx := RD(O + 4 + 20);
                end;
              LF_PARRAY:
                begin
                  // open (count = -1) array body: dynamic array or open array parameter
                  if GetType(TI.ElemType, Base) and (Base.Count < 0) then
                  begin
                    if TI.IsRef then
                      TI.Kind := tkOpenArray
                    else
                      TI.Kind := tkDynArray;
                    TI.IsRef := False;
                    TI.ElemType := Base.ElemType;
                    TI.Low := 0;
                    TI.High := -1;
                  end;
                end;
            end;
        end;
      end;
    LF_SUBRANGE:
      begin
        TI.ElemType := RD(P);
        TI.NameIdx := RD(P + 4);
        Inc(P, 8);
        TI.Low := ReadNumeric(P);
        TI.High := ReadNumeric(P);
        TI.Size := RW(P);
        TI.Kind := tkInteger;
        // classify through the base type
        if GetType(TI.ElemType, Base) then
        begin
          case Base.Kind of
            tkChar: TI.Kind := tkChar;
            tkWideChar: TI.Kind := tkWideChar;
            tkBoolean: TI.Kind := tkBoolean;
            tkEnum:
              begin
                TI.Kind := tkEnum;
                TI.FieldList := Base.FieldList;
                TI.Count := Base.Count;
              end;
            tkInteger:
              begin
                if (TI.ElemType < $1000) and not Base.Signed then
                begin
                  // bounds are stored as signed numerics
                  if TI.Size = 4 then
                  begin
                    TI.Low := TI.Low and $FFFFFFFF;
                    TI.High := TI.High and $FFFFFFFF;
                  end;
                end;
              end;
          end;
        end;
        TI.Signed := TI.Low < 0;
        if TI.NameIdx <> 0 then
        begin
          S := NameStr(TI.NameIdx);
          if SameText(S, 'ByteBool') or SameText(S, 'WordBool') or SameText(S, 'LongBool') then
            TI.Kind := tkBoolean;
        end;
      end;
    LF_ENUM:
      begin
        TI.Kind := tkEnum;
        TI.Count := RW(P);
        TI.FieldList := RD(P + 6);
        TI.NameIdx := RD(P + 14);
        // the underlying type field is not filled in by dcc32: size by member count ($Z1)
        if TI.Count <= 256 then
          TI.Size := 1
        else if TI.Count <= 65536 then
          TI.Size := 2
        else
          TI.Size := 4;
        TI.Low := 0;
        TI.High := TI.Count - 1;
      end;
    LF_SET:
      begin
        TI.Kind := tkSet;
        TI.ElemType := RD(P);
        TI.NameIdx := RD(P + 4);
        TI.SetLowByte := RW(P + 8);
        TI.Size := RW(P + 10);
      end;
    LF_PARRAY:
      begin
        TI.Kind := tkArray;
        TI.ElemType := RD(P);
        TI.IndexType := RD(P + 4);
        TI.NameIdx := RD(P + 8);
        Inc(P, 12);
        V := ReadNumeric(P);
        TI.Size := Integer(V);
        V := ReadNumeric(P);
        TI.Count := Integer(V);
        TI.Low := 0;
        TI.High := TI.Count - 1;
        if TI.Count >= 0 then
        begin
          if GetType(TI.IndexType, Idx2) then
            case Idx2.Kind of
              tkInteger, tkEnum, tkChar, tkBoolean, tkWideChar:
                if Idx2.Leaf = LF_SUBRANGE then
                begin
                  TI.Low := Idx2.Low;
                  TI.High := Idx2.High;
                end;
            end;
          if TI.High - TI.Low + 1 <> TI.Count then TI.High := TI.Low + TI.Count - 1;
        end
        else
        begin
          TI.Kind := tkOpenArray;
          TI.Size := -1;
        end;
      end;
    LF_PSTRING:
      begin
        TI.Kind := tkShortString;
        TI.ElemType := RD(P);
        TI.IndexType := RD(P + 4);
        TI.NameIdx := RD(P + 8);
        Inc(P, 12);
        V := ReadNumeric(P);
        TI.Size := Integer(V);
        if TI.Size <= 0 then TI.Size := -1;
        TI.Count := TI.Size;
      end;
    LF_LSTRING:
      begin
        TI.Kind := tkAnsiString;
        TI.NameIdx := RD(P);
        TI.Size := 4;
      end;
    LF_WSTRING:
      begin
        TI.Kind := tkWideString;
        TI.NameIdx := RD(P);
        TI.Size := 4;
      end;
    LF_VARIANT:
      begin
        TI.Kind := tkVariant;
        TI.NameIdx := RD(P);
        TI.Size := 16;
      end;
    LF_CLASSREF:
      begin
        TI.Kind := tkClassRef;
        TI.ElemType := RD(P);
        TI.Size := 4;
      end;
    LF_CLOSURE:
      begin
        TI.Kind := tkMethod;
        TI.RetType := RD(P);
        TI.ArgCount := RW(P + 6);
        TI.ArgList := RD(P + 8);
        TI.Size := 8;
      end;
    LF_PROCEDURE:
      begin
        TI.Kind := tkProcedure;
        TI.RetType := RD(P);
        TI.ArgCount := RW(P + 6);
        TI.ArgList := RD(P + 8);
        TI.Size := 4;
      end;
    LF_MFUNCTION:
      begin
        TI.Kind := tkProcedure;
        TI.RetType := RD(P);
        TI.ElemType := RD(P + 4);       // class
        TI.ArgCount := RW(P + 14);
        TI.ArgList := RD(P + 16);
        TI.Size := 4;
      end;
    LF_CLASS, LF_STRUCTURE, LF_UNION:
      begin
        if Leaf = LF_CLASS then TI.Kind := tkClass else TI.Kind := tkRecord;
        TI.Count := RW(P);
        TI.FieldList := RD(P + 2);
        if Leaf = LF_UNION then
        begin
          TI.NameIdx := RD(P + 12);
          Inc(P, 16);
        end
        else
        begin
          TI.NameIdx := RD(P + 20);
          Inc(P, 24);
        end;
        if P < O + Len + 2 then
          TI.Size := Integer(ReadNumeric(P));
      end;
    LF_PROPERTY:
      begin
        TI.Kind := tkProperty;
        TI.ElemType := RD(P);
        TI.PropFlags := RW(P + 4);
        TI.PropGet := RD(P + 14);
        TI.PropSet := RD(P + 18);
      end;
  else
    TI.Kind := tkUnknown;
  end;
end;

function TTD32Info.GetFields(FieldList: Cardinal; out Fields: TTDFieldArray): Boolean;
var
  O, P, EndP, N, Guard, Chain: Integer;
  Leaf: Word;
  F: TTDField;
  B: Byte;
  Done: Boolean;
begin
  Fields := nil;
  Result := False;
  N := 0;
  Chain := 0;
  while (FieldList >= $1000) and (Chain < 64) do
  begin
    Inc(Chain);
    O := TypeRecOfs(FieldList);
    FieldList := 0;
    if (O = 0) or (RW(O + 2) <> LF_FIELDLIST) then Break;
    Result := True;
    P := O + 4;
    EndP := O + RW(O) + 2;
    Guard := 0;
    Done := False;
    while (P + 2 <= EndP) and (Guard < 100000) and not Done do
    begin
      Inc(Guard);
      B := RB(P);
      if B >= $F0 then
      begin
        Inc(P, B and $0F);      // padding
        if (B and $0F) = 0 then Inc(P);
        Continue;
      end;
      Leaf := RW(P);
      FillChar(F, SizeOf(F), 0);
      case Leaf of
        LF_BCLASS:
          begin
            F.Kind := fdBaseClass;
            F.TypeIdx := RD(P + 2);
            F.Attr := RW(P + 6);
            Inc(P, 8);
            F.Offset := Integer(ReadNumeric(P));
          end;
        LF_VBCLASS, LF_IVBCLASS:
          begin
            F.Kind := fdOther;
            Inc(P, 12);
            ReadNumeric(P);
            ReadNumeric(P);
          end;
        LF_ENUMERATE:
          begin
            F.Kind := fdEnumerate;
            F.Attr := RW(P + 2);
            F.NameIdx := RD(P + 4);
            Inc(P, 12);
            F.Value := ReadNumeric(P);
          end;
        LF_INDEX:
          begin
            FieldList := RD(P + 2);
            Done := True;
            Continue;
          end;
        LF_MEMBER:
          begin
            F.Kind := fdMember;
            F.TypeIdx := RD(P + 2);
            F.Attr := RW(P + 6);
            F.NameIdx := RD(P + 8);
            Inc(P, 16);
            F.Offset := Integer(ReadNumeric(P));
            // a property is a member whose type is an LF_PROPERTY record (see GetType for
            // its getter/setter); it must not be resolved here: class graphs are cyclic
            if (F.TypeIdx >= $1000) and (TypeRecOfs(F.TypeIdx) <> 0) and
              (RW(TypeRecOfs(F.TypeIdx) + 2) = LF_PROPERTY) then
              F.Kind := fdProperty;
          end;
        LF_STMEMBER:
          begin
            F.Kind := fdStatic;
            F.TypeIdx := RD(P + 2);
            F.Attr := RW(P + 6);
            F.NameIdx := RD(P + 8);
            Inc(P, 16);
          end;
        LF_METHOD:
          begin
            F.Kind := fdMethod;
            F.TypeIdx := RD(P + 4);
            F.NameIdx := RD(P + 8);
            Inc(P, 12);
          end;
        LF_NESTTYPE:
          begin
            F.Kind := fdOther;
            F.TypeIdx := RD(P + 2);
            F.NameIdx := RD(P + 6);
            Inc(P, 14);
          end;
        LF_VFUNCTAB:
          begin
            F.Kind := fdVFuncTab;
            F.TypeIdx := RD(P + 2);
            Inc(P, 8);
          end;
        LF_FRIENDCLS:
          begin
            F.Kind := fdOther;
            Inc(P, 6);
          end;
        LF_FRIENDFCN:
          begin
            F.Kind := fdOther;
            Inc(P, 10);
          end;
      else
        Done := True;     // unknown sub-leaf: stop parsing this list
        Continue;
      end;
      if N >= Length(Fields) then
        if N = 0 then SetLength(Fields, 16) else SetLength(Fields, N * 2);
      Fields[N] := F;
      Inc(N);
    end;
  end;
  SetLength(Fields, N);
end;

function TTD32Info.MethodEntry(MList: Cardinal; out Attr: Word; out TypeIdx: Cardinal): Boolean;
var
  O: Integer;
begin
  Result := False;
  Attr := 0;
  TypeIdx := 0;
  O := TypeRecOfs(MList);
  if (O = 0) or (RW(O + 2) <> LF_METHODLIST) or (RW(O) < 8) then Exit;
  { an entry: the attribute (a word), then the type }
  Attr := RW(O + 4);
  TypeIdx := RD(O + 6);
  Result := (TypeIdx >= $1000) and (TypeRecOfs(TypeIdx) <> 0) and (RW(TypeRecOfs(TypeIdx) + 2) = LF_MFUNCTION);
end;

function TTD32Info.MethodSignature(MList: Cardinal): string;
var
  I: Integer;
  Attr: Word;
  Idx: Cardinal;
  TI: TTDTypeInfo;
  Args: TCardinalArray;
  S: string;
begin
  Result := 'method';
  if not MethodEntry(MList, Attr, Idx) or not GetType(Idx, TI) then Exit;
  S := '';
  if GetArgs(TI.ArgList, Args) then
    for I := Ord(Attr and (MA_CONSTRUCTOR or MA_DESTRUCTOR) <> 0) to High(Args) do
    begin
      if S <> '' then S := S + ', ';
      S := S + TypeName(Args[I]);
    end;
  if S <> '' then S := '(' + S + ')';
  if Attr and MA_CONSTRUCTOR <> 0 then
    Result := 'constructor' + S
  else if Attr and MA_DESTRUCTOR <> 0 then
    Result := 'destructor' + S
  else if (TI.RetType = T_VOID) or (TI.RetType = 0) then
    Result := 'procedure' + S
  else
    Result := 'function' + S + ': ' + TypeName(TI.RetType);
end;

function TTD32Info.GetArgs(ArgList: Cardinal; out Args: TCardinalArray): Boolean;
var
  O, N, I: Integer;
begin
  Args := nil;
  Result := False;
  O := TypeRecOfs(ArgList);
  if (O = 0) or (RW(O + 2) <> LF_ARGLIST) then Exit;
  N := RW(O + 4);
  if 6 + N * 4 > RW(O) + 2 then Exit;
  SetLength(Args, N);
  for I := 0 to N - 1 do Args[I] := RD(O + 6 + I * 4);
  Result := True;
end;

procedure TTD32Info.BuildUdtMap;
var
  M, N, Cap, P, EndP, Len, Guard, K: Integer;
  Seen: array of Byte;
  T: Cardinal;
begin
  if FUdtBuilt then Exit;
  N := 0;
  Cap := 0;
  // one name per type: the first UDT record in file order wins (System unit first)
  SetLength(Seen, (FTypeCount + 8) div 8 + 1);
  for M := 0 to High(FModules) do
  begin
    if (FModules[M].SymOfs = 0) or (FModules[M].DataOfs = 0) then Continue;
    P := FModules[M].DataOfs;
    EndP := FModules[M].SymOfs + FModules[M].SymSize;
    Guard := 0;
    while (P + 4 <= EndP) and (Guard < 4000000) do
    begin
      Inc(Guard);
      Len := RW(P);
      if Len < 2 then Break;
      if RW(P + 2) = S_UDT then
      begin
        T := RD(P + 4);
        K := TypeSlot(T);
        if K >= 0 then
        begin
          if (Seen[K shr 3] and (1 shl (K and 7))) = 0 then
          begin
            Seen[K shr 3] := Seen[K shr 3] or (1 shl (K and 7));
            if N >= Cap then
            begin
              if Cap = 0 then Cap := 1024 else Cap := Cap * 2;
              SetLength(FUdtTypes, Cap);
              SetLength(FUdtNames, Cap);
            end;
            FUdtTypes[N] := T;
            FUdtNames[N] := RD(P + 10);
            Inc(N);
          end;
        end;
      end;
      Inc(P, Len + 2);
    end;
  end;
  SetLength(FUdtTypes, N);
  SetLength(FUdtNames, N);
  if N > 1 then SortPairs(FUdtTypes, FUdtNames, 0, N - 1);
  // only now: a build cut short by an exception would leave an unsorted map for good
  FUdtBuilt := True;
end;

function TTD32Info.TypeName(Idx: Cardinal): string;
begin
  if FNameDepth > 16 then
  begin
    Result := '?';
    Exit;
  end;
  Inc(FNameDepth);
  try
    Result := DoTypeName(Idx);
  finally
    Dec(FNameDepth);
  end;
end;

function TTD32Info.DoTypeName(Idx: Cardinal): string;
var
  TI, E: TTDTypeInfo;
  L, H, M: Integer;
begin
  Result := '';
  if Idx < $1000 then
  begin
    Result := PrimitiveTypeName(Idx);
    Exit;
  end;
  if not FHasTD32 then Exit;
  if not GetType(Idx, TI) then
  begin
    Result := '?';
    Exit;
  end;
  // 1. the type's own declared name
  if TI.NameIdx <> 0 then
  begin
    Result := NameStr(TI.NameIdx);
    if SameText(Result, 'AnsiString') or SameText(Result, 'String') then Result := 'string';
    if Result <> '' then Exit;
  end;
  // 2. well known anonymous pointer types
  if (TI.Kind = tkPointer) and not TI.IsRef and GetType(TI.ElemType, E) then
  begin
    if E.Kind = tkVoid then
      Result := 'Pointer'
    else if (E.Kind = tkChar) and (E.Leaf = 0) then
      Result := 'PChar'
    else if (E.Kind = tkWideChar) and (E.Leaf = 0) then
      Result := 'PWideChar';
    if Result <> '' then Exit;
  end;
  // 3. a name given through a type declaration (pointer types, aliases ...)
  if not TI.IsRef then
  begin
    BuildUdtMap;
    L := 0;
    H := High(FUdtTypes);
    while L <= H do
    begin
      M := (L + H) shr 1;
      if FUdtTypes[M] < Idx then
        L := M + 1
      else if FUdtTypes[M] > Idx then
        H := M - 1
      else
      begin
        Result := NameStr(FUdtNames[M]);
        if Result <> '' then Exit;
        Break;
      end;
    end;
  end;
  case TI.Kind of
    tkPointer:
      begin
        if GetType(TI.ElemType, E) and (E.Kind = tkVoid) then
          Result := 'Pointer'
        else if TI.IsRef then
          Result := TypeName(TI.ElemType)
        else
        begin
          Result := TypeName(TI.ElemType);
          if SameText(Result, 'Char') then
            Result := 'PChar'
          else if SameText(Result, 'WideChar') then
            Result := 'PWideChar'
          else
            Result := '^' + Result;
        end;
      end;
    tkObject, tkInterface: Result := TypeName(TI.ElemType);
    tkDynArray, tkOpenArray: Result := 'array of ' + TypeName(TI.ElemType);
    tkArray: Result := Format('array[%d..%d] of %s', [TI.Low, TI.High, TypeName(TI.ElemType)]);
    tkSet: Result := 'set of ' + TypeName(TI.ElemType);
    tkShortString:
      if (TI.Size > 0) and (TI.Size < 256) then
        Result := Format('string[%d]', [TI.Size - 1])
      else
        Result := 'ShortString';
    tkAnsiString: Result := 'string';
    tkWideString: Result := 'WideString';
    tkVariant: Result := 'Variant';
    tkClassRef: Result := 'class of ' + TypeName(TI.ElemType);
    tkMethod:
      if (TI.RetType = T_VOID) or (TI.RetType = 0) then
        Result := 'procedure of object'
      else
        Result := 'function of object';
    tkProcedure:
      if (TI.RetType = T_VOID) or (TI.RetType = 0) then
        Result := 'procedure'
      else
        Result := 'function';
    tkInteger, tkChar, tkWideChar, tkBoolean, tkEnum:
      if TI.Leaf = LF_SUBRANGE then
      begin
        if (TI.ElemType < $1000) or (TI.Kind <> tkInteger) then
          Result := TypeName(TI.ElemType)
        else
          Result := Format('%d..%d', [TI.Low, TI.High]);
      end
      else
        Result := '?';
    tkRecord: Result := 'record';
    tkClass: Result := 'class';
    tkProperty: Result := TypeName(TI.ElemType);
  else
    Result := '?';
  end;
end;

procedure TTD32Info.BuildClassCache;
var
  I, N, Cap, O: Integer;
  Leaf: Word;
begin
  if FClassCacheBuilt then Exit;
  N := 0;
  Cap := 0;
  for I := 0 to FTypeCount - 1 do
  begin
    O := TypeRecOfs($1000 + Cardinal(I));
    if O = 0 then Continue;
    Leaf := RW(O + 2);
    if Leaf = LF_CLASS then
    begin
      if N >= Cap then
      begin
        if Cap = 0 then Cap := 256 else Cap := Cap * 2;
        SetLength(FClassNames, Cap);
        SetLength(FClassTypes, Cap);
      end;
      FClassNames[N] := RD(O + 4 + 20);
      FClassTypes[N] := $1000 + Cardinal(I);
      Inc(N);
    end;
  end;
  SetLength(FClassNames, N);
  SetLength(FClassTypes, N);
  // only now: a build cut short by an exception would leave a partial cache for good
  FClassCacheBuilt := True;
end;

function TTD32Info.FindClassType(const AClassName: string; out ClassIdx: Cardinal): Boolean;
var
  Idx: TCardinalArray;
  I, K: Integer;
  TI: TTDTypeInfo;
  Best: Cardinal;
begin
  Result := False;
  ClassIdx := 0;
  if not FHasTD32 or not FindNames(AClassName, Idx) then Exit;
  BuildClassCache;
  Best := 0;
  for I := 0 to High(FClassNames) do
    for K := 0 to High(Idx) do
      if FClassNames[I] = Idx[K] then
      begin
        // prefer a complete definition (one that has a field list)
        if GetType(FClassTypes[I], TI) and (TI.FieldList <> 0) then
        begin
          ClassIdx := FClassTypes[I];
          Result := True;
          Exit;
        end;
        if Best = 0 then Best := FClassTypes[I];
      end;
  if Best <> 0 then
  begin
    ClassIdx := Best;
    Result := True;
  end;
end;

function TTD32Info.IsInterfaceClass(ClassIdx: Cardinal): Boolean;
var
  Guard, O, FL, P, EndP, K, Slot: Integer;
  Next, NameIdx: Cardinal;
  B: Byte;
  Leaf: Word;
begin
  Result := False;
  // cached answer: 1 = class, 2 = interface
  Slot := TypeSlot(ClassIdx);
  if Slot >= 0 then
  begin
    if Length(FClassKind) <> FTypeCount then SetLength(FClassKind, FTypeCount);
    if FClassKind[Slot] <> 0 then
    begin
      Result := FClassKind[Slot] = 2;
      Exit;
    end;
  end;
  Guard := 0;
  while (ClassIdx >= $1000) and (Guard < 64) do
  begin
    Inc(Guard);
    O := TypeRecOfs(ClassIdx);
    if (O = 0) or (RW(O + 2) <> LF_CLASS) then Break;
    NameIdx := RD(O + 24);
    // the base class entry sits at the very start of the field list (after the vtable entry)
    Next := 0;
    FL := TypeRecOfs(RD(O + 6));
    if (FL <> 0) and (RW(FL + 2) = LF_FIELDLIST) then
    begin
      P := FL + 4;
      EndP := FL + RW(FL) + 2;
      K := 0;
      while (P + 2 <= EndP) and (K < 4) do
      begin
        Inc(K);
        B := RB(P);
        if B >= $F0 then
        begin
          if (B and $0F) = 0 then Inc(P) else Inc(P, B and $0F);
          Dec(K);
          Continue;
        end;
        Leaf := RW(P);
        if Leaf = LF_VFUNCTAB then
          Inc(P, 8)
        else if Leaf = LF_BCLASS then
        begin
          Next := RD(P + 2);
          Break;
        end
        else
          Break;
      end;
    end;
    if Next = 0 then
    begin
      // root of the hierarchy: classes end at TObject, interfaces at IInterface/IUnknown
      Result := not NameEquals(NameIdx, 'TObject');
      Break;
    end;
    ClassIdx := Next;
  end;
  if Slot >= 0 then
  begin
    if Result then FClassKind[Slot] := 2 else FClassKind[Slot] := 1;
  end;
end;

function TTD32Info.EnumName(const TI: TTDTypeInfo; Value: Int64; out Name: string): Boolean;
var
  Fields: TTDFieldArray;
  I: Integer;
begin
  Result := False;
  Name := '';
  if TI.FieldList = 0 then Exit;
  if not GetFields(TI.FieldList, Fields) then Exit;
  for I := 0 to High(Fields) do
    if (Fields[I].Kind = fdEnumerate) and (Fields[I].Value = Value) then
    begin
      Name := NameStr(Fields[I].NameIdx);
      Result := True;
      Exit;
    end;
end;

{ map file fallback }

function TTD32Info.LoadFromMap(const MapName, ExeName: string): Boolean;
type
  TState = (stNone, stSegments, stDetail, stPubName, stPubValue, stLines);
var
  SL: TStringList;
  I, P, Seg, Src, ModIdx, K, N: Integer;
  S, T, Nm, UnitName, SrcName: string;
  State: TState;
  Ofs, Len, DataLen, BssStart: Cardinal;
  Pr: TTDProc;
  Parts: TStringList;
  HaveData: Boolean;
  LastMod: Integer;

  function HexVal(const H: string): Cardinal;
  begin
    Result := Cardinal(StrToInt64Def('$' + H, 0));
  end;

  { the module of unit Name, a new one when there is none }
  function ModuleOf(const Name: string): Integer;
  begin
    Result := FindModule(Name);
    if Result >= 0 then Exit;
    Result := Length(FModules);
    SetLength(FModules, Result + 1);
    FModules[Result].Name := Name;
  end;

  { the module whose code holds RVA (ModuleByAddr): the publics and the lines come in address
    order, so the module of the one before is tried first }
  function ModuleAt(RVA: Cardinal): Integer;
  begin
    if (LastMod >= 0) and (RVA >= FModules[LastMod].CodeRVA) and
      (RVA < FModules[LastMod].CodeRVA + FModules[LastMod].CodeSize) then
      Result := LastMod
    else
    begin
      Result := ModuleByAddr(RVA);
      if Result >= 0 then LastMod := Result;
    end;
  end;

  function ParseAddr(const A: string; out ASeg: Integer; out AOfs: Cardinal): Boolean;
  begin
    Result := (Length(A) >= 13) and (A[5] = ':');
    if Result then
    begin
      ASeg := StrToIntDef('$' + Copy(A, 1, 4), -1);
      AOfs := HexVal(Copy(A, 6, 8));
      Result := ASeg >= 0;
    end;
  end;

  function DataRVA(AOfs: Cardinal): Cardinal;
  var
    J: Integer;
  begin
    // .data and .bss share link segment 2; .bss follows .data in the link map but starts
    // its own PE section
    if HaveData and (AOfs >= BssStart) and (Length(FSections) >= 3) then
    begin
      // find the BSS section: first section after DATA
      J := 2;
      Result := FSections[J].VA + (AOfs - BssStart);
    end
    else
      Result := SegOfsToRVA(2, AOfs);
  end;

begin
  Result := False;
  Clear;
  FFileName := ExeName;
  if not LoadPEInfo(ExeName) then Exit;
  if not FileExists(MapName) then Exit;
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    try
      SL.LoadFromFile(MapName);
      State := stNone;
      DataLen := 0;
      BssStart := 0;
      HaveData := False;
      Src := -1;
      LastMod := -1;
      for I := 0 to SL.Count - 1 do
      begin
        S := Trim(SL[I]);
        if S = '' then Continue;
        if Pos('Start', S) = 1 then
        begin
          State := stSegments;
          Continue;
        end;
        if Pos('Detailed map of segments', S) = 1 then
        begin
          State := stDetail;
          Continue;
        end;
        if Pos('Publics by Name', S) > 0 then
        begin
          State := stPubName;
          Continue;
        end;
        if Pos('Publics by Value', S) > 0 then
        begin
          State := stPubValue;
          Continue;
        end;
        if Pos('Line numbers for ', S) = 1 then
        begin
          State := stLines;
          // Line numbers for Unit(file.pas) segment .text
          T := Copy(S, 18, MaxInt);
          P := Pos('(', T);
          UnitName := Copy(T, 1, P - 1);
          Delete(T, 1, P);
          P := Pos(')', T);
          SrcName := Copy(T, 1, P - 1);
          ModIdx := ModuleOf(UnitName);
          FModules[ModIdx].HasLines := True;
          Src := Length(FSrcFiles);
          SetLength(FSrcFiles, Src + 1);
          FSrcFiles[Src].Name := SrcName;
          FSrcFiles[Src].Module := ModIdx;
          Continue;
        end;
        if (Pos('Program entry point', S) = 1) or (Pos('Bound resource files', S) = 1) then
        begin
          State := stNone;
          Continue;
        end;
        case State of
          stSegments:
            begin
              // 0002:00000000 000006A4H .data DATA
              if ParseAddr(S, Seg, Ofs) and (Seg = 2) then
              begin
                T := Trim(Copy(S, 14, MaxInt));
                P := Pos('H', T);
                if P > 1 then
                begin
                  Len := HexVal(Copy(T, 1, P - 1));
                  if Pos('.bss', LowerCase(T)) > 0 then
                  begin
                    BssStart := Ofs;
                    HaveData := True;
                  end
                  else if Pos('.data', LowerCase(T)) > 0 then
                    DataLen := Len;
                end;
              end;
            end;
          stDetail:
            begin
              // 0001:00000000 00005D6B C=CODE     S=.text    G=(none)   M=System   ACBP=A9
              if ParseAddr(S, Seg, Ofs) and (Seg = 1) then
              begin
                Len := HexVal(Copy(S, 15, 8));
                P := Pos('M=', S);
                if P > 0 then
                begin
                  T := Copy(S, P + 2, MaxInt);
                  P := Pos(' ', T);
                  if P > 0 then SetLength(T, P - 1);
                  ModIdx := ModuleOf(T);
                  if FModules[ModIdx].CodeSize = 0 then
                  begin
                    FModules[ModIdx].CodeRVA := SegOfsToRVA(1, Ofs);
                    FModules[ModIdx].CodeSize := Len;
                  end;
                end;
              end;
            end;
          stPubValue:
            begin
              if ParseAddr(S, Seg, Ofs) then
              begin
                Nm := Trim(Copy(S, 14, MaxInt));
                if Nm = '' then Continue;
                if Seg = 1 then
                begin
                  FillChar(Pr, SizeOf(Pr), 0);
                  Pr.Start := SegOfsToRVA(1, Ofs);
                  Pr.Module := ModuleAt(Pr.Start);
                  Pr.MapName := FMapNames.Add(Nm);
                  Pr.Global := True;
                  AddProc(Pr);
                end
                else if (Seg = 2) and (Ofs < $10000000) then
                  FMapGlobals.AddObject(Nm, TObject(DataRVA(Ofs)));
              end;
            end;
          stLines:
            begin
              //   13 0001:00016ED4    14 0001:00016EE0 ...
              Parts.Clear;
              ExtractStrings([' '], [' '], PChar(S), Parts);
              K := 0;
              while K + 1 < Parts.Count do
              begin
                N := StrToIntDef(Parts[K], -1);
                if (N >= 0) and ParseAddr(Parts[K + 1], Seg, Ofs) and (Src >= 0) then
                  AddLine(SegOfsToRVA(Seg, Ofs), 0, N, Src);
                Inc(K, 2);
              end;
            end;
        end;
      end;
      if DataLen = 0 then HaveData := False;
      FMapSizes := True;
      try
        FinishTables;
      finally
        FMapSizes := False;
      end;
      // line end addresses: bounded by the owning module's code range
      for I := 0 to FLineCount - 1 do
      begin
        ModIdx := ModuleAt(FLines[I].Addr);
        if (ModIdx >= 0) and (FLines[I].EndAddr > FModules[ModIdx].CodeRVA + FModules[ModIdx].CodeSize) then
          FLines[I].EndAddr := FModules[ModIdx].CodeRVA + FModules[ModIdx].CodeSize;
        if (I = FLineCount - 1) and (ModIdx >= 0) then
          FLines[I].EndAddr := FModules[ModIdx].CodeRVA + FModules[ModIdx].CodeSize;
      end;
      FIsMap := True;
      Result := (FProcCount > 0) or (FLineCount > 0);
    except
      Clear;
      Result := False;
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
end;

end.
