{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCIEngine;

// D7 Studio - code insight engine core: unit cache, unit lookup on the search
// path, scope / type / member resolution and display text helpers.

{$Q-,R-,B-,H+}

interface

uses
  Windows, SysUtils, Classes, SdPasLex, SdPasParser;

type
  TEngGetSource = function(const FileName: string; var Source: string): Boolean of object;
  { the units the IDE puts into the interface uses clause of an open file before it is saved or
    compiled (those of the components placed on its form), into Units }
  TEngGetUses = procedure(const FileName: string; Units: TStrings) of object;
  { File access that also reaches names the ANSI file functions cannot open (the marked names
    '?U:...' of SdFileNames, which is not reachable from here - the IDE plugs its functions in):
    the bytes of a file (raises when it cannot read it) and its age (-1 = no such file) }
  TCIReadFileFunc = function(const FileName: string): string;
  TCIFileAgeFunc = function(const FileName: string): Integer;

  TDirIndex = class
  public
    Files: TStringList;     // sorted base names (case-insensitive)
    Tick: Cardinal;
    destructor Destroy; override;
  end;

  { a place in the walk over the symbol tables of a unit's scope (TCIEngine.NextScope): zeroed
    to start }
  TScopeCursor = record
    Step, Index: Integer;
  end;

  TCIEngine = class
  private
    FUnits: TStringList;
    FDirs: TStringList;
    FPathDirs: TStringList;
    FPathValid: Boolean;
    FBuiltin: TUnitInfo;
    FSystem: TUnitInfo;
    FSystemGen: Integer;
    FSysInit: TUnitInfo;
    FSysInitGen: Integer;
    FIncDir: string;
    FUnitIndex: TStringList;    // UnitFiles' unit names, sorted (NameIndex); nil: made at the next lookup
    function GetEntry(const FileName: string): TUnitInfo;
    procedure ClearDirs;
    procedure UnitFilesChanging(Sender: TObject);
    function FindUnitFor(const UnitName, FromFile: string; FromU: TUnitInfo): string;
    function DirIndex(const ADir: string): TDirIndex;
    procedure DoParse(U: TUnitInfo; const S: string; Full, CanTruncate: Boolean);
    procedure BuildPathDirs;
    function IsRootType(D: TTypeDesc): Boolean;
    function FileAgeOf(const FileName: string): Integer;
    function FileThere(const FileName: string): Boolean;
  public
    SearchPath: TStringList;
    Defines: TStringList;
    UnitFiles: TStringList;
    OnGetSource: TEngGetSource;
    { an open file's units still to come into its uses clause: in its scope as the interface's
      last ones, as the compiler will get them (ResolveUses) }
    OnGetPendingUses: TEngGetUses;
    ReadFileFunc: TCIReadFileFunc;     // nil = ReadFileText
    FileAgeFunc: TCIFileAgeFunc;       // nil = SysUtils.FileAge
    Gen: Integer;
    CurUnit: TUnitInfo;
    constructor Create;
    destructor Destroy; override;
    procedure BeginCall;
    procedure ClearCache;
    procedure InvalidateFile(const FileName: string);
    procedure PathChanged;
    procedure DefinesChanged;
    function NormFileName(const FileName: string): string;
    { a file's text from disk (ReadFileFunc) }
    function ReadSource(const FileName: string; var Text: string): Boolean;
    function FindUnitFile(const UnitName, FromFile: string): string;
    { a used unit: only its interface is parsed (the current unit comes through LoadCurrent) }
    function LoadFile(const FileName: string): TUnitInfo;
    function LoadCurrent(const FileName, Source: string): TUnitInfo;
    function UnitByName(const Name: string; FromUnit: TUnitInfo): TUnitInfo;
    function SystemUnit: TUnitInfo;
    { SysInit, in every unit's scope after System as the compiler puts it there; nil: not found }
    function SysInitUnit: TUnitInfo;
    { the text of the file an include directive names: Name as it is (a full path), in
      IncludeDir, else in a folder of the search path; no extension: .pas (the lexer's
      TLexIncludeEvent) }
    function HandleInclude(const IncName: string; var Text: string): Boolean;
    { the folder of the file being parsed - where HandleInclude looks first }
    property IncludeDir: string read FIncDir write FIncDir;
    procedure ResolveUses(U: TUnitInfo);
    procedure GetUnitNames(List: TStrings; const FromFile: string);
    // lookups
    { the symbol tables of unit U's scope, one per call, in lookup order: the implementation's
      own (InImpl), the interface's, the units the implementation (InImpl) and the interface use -
      the last one first, resolved only when the walk gets there -, System and the built-in
      declarations. Hide: a System unit's table, whose names starting with _ are no completions.
      False: no more tables. }
    function NextScope(U: TUnitInfo; InImpl: Boolean; var Cursor: TScopeCursor; out Tab: TSymTable;
      out Hide: Boolean): Boolean;
    function FindInUnitScope(P: PChar; Len: Integer; U: TUnitInfo; InImpl: Boolean): TSymbol;
    function FindQualified(const Name: string; U: TUnitInfo; InImpl: Boolean; OwnerRoutine: TSymbol): TSymbol;
    function ResolveDesc(D: TTypeDesc): TTypeDesc;
    function AncestorOf(D: TTypeDesc): TTypeDesc;
    function FindMember(D: TTypeDesc; P: PChar; Len: Integer; out DeclDesc: TTypeDesc): TSymbol;
    function InheritsFrom(D, Anc: TTypeDesc): Boolean;
    function PropertyType(S: TSymbol): TTypeDesc;
    // display text
    function RangeText(U: TUnitInfo; A, B: Integer; MaxLen: Integer): string;
    function TypeText(S: TSymbol): string;
    function ParamsText(S: TSymbol): string;
    function HeadingText(R: TRoutineSym; Qualified, WithDirectives: Boolean): string;
    function DeclText(S: TSymbol): string;
    function ParamText(P: TSymbol): string;
    property Builtin: TUnitInfo read FBuiltin;
  end;

function ReadFileText(const FileName: string; var Text: string): Boolean;
{ the symbols a unit exports: the interface of a unit, everything of a program }
function UnitSyms(UU: TUnitInfo): TSymTable;

implementation

const
  BuiltinLines: array[0..113] of string = (
    'unit System;',
    'interface',
    'type',
    '  Integer = __int32; Cardinal = __uint32; ShortInt = __int8; SmallInt = __int16;',
    '  LongInt = __int32; Int64 = __int64; Byte = __uint8; Word = __uint16; LongWord = __uint32; UInt64 = __uint64;',
    '  Boolean = (False, True);',
    '  ByteBool = __bool8; WordBool = __bool16; LongBool = __bool32;',
    '  Char = __ansichar; AnsiChar = __ansichar; WideChar = __widechar;',
    '  AnsiString = string; WideString = __widestring; ShortString = __shortstring;',
    '  Single = __single; Double = __double; Extended = __extended; Real = __double;',
    '  Real48 = __real48; Comp = __comp; Currency = __currency;',
    '  Pointer = __pointer; PChar = ^Char; PAnsiChar = ^AnsiChar; PWideChar = ^WideChar;',
    '  Variant = __variant; OleVariant = __olevariant;',
    '  Text = __textfile; TextFile = Text;',
    '  TObject = class;',
    '  TClass = class of TObject;',
    '  TObject = class',
    '    constructor Create;',
    '    procedure Free;',
    '    class function ClassName: ShortString;',
    '    class function ClassParent: TClass;',
    '    class function InheritsFrom(AClass: TClass): Boolean;',
    '    function ClassType: TClass;',
    '    destructor Destroy; virtual;',
    '  end;',
    '  IInterface = interface',
    '    function QueryInterface(const IID; out Obj): Integer; stdcall;',
    '    function _AddRef: Integer; stdcall;',
    '    function _Release: Integer; stdcall;',
    '  end;',
    '  IUnknown = IInterface;',
    'const',
    '  MaxInt = 2147483647;',
    '  MaxLongint = 2147483647;',
    '  Pi = 3.1415926535897932385;',
    'procedure Inc(var X; N: Longint = 1);',
    'procedure Dec(var X; N: Longint = 1);',
    'function Length(const S): Integer;',
    'procedure SetLength(var S; NewLength: Integer);',
    'procedure SetString(var S: string; Buffer: PChar; Len: Integer);',
    'function Copy(const S; Index, Count: Integer): string;',
    'procedure Delete(var S: string; Index, Count: Integer);',
    'procedure Insert(const Source: string; var S: string; Index: Integer);',
    'function Pos(const Substr, S: string): Integer;',
    'procedure Str(const X; var S: string);',
    'procedure Val(const S: string; var V; var Code: Integer);',
    'procedure Write(P1; P2; Pn);',
    'procedure Writeln(P1; P2; Pn);',
    'procedure Read(var V1; var V2; var Vn);',
    'procedure Readln(var V1; var V2; var Vn);',
    'procedure New(var P: Pointer);',
    'procedure Dispose(var P: Pointer);',
    'procedure GetMem(var P: Pointer; Size: Integer);',
    'procedure FreeMem(var P: Pointer; Size: Integer = 0);',
    'procedure ReallocMem(var P: Pointer; Size: Integer);',
    'function High(const X): Integer;',
    'function Low(const X): Integer;',
    'function Ord(const X): Integer;',
    'function Chr(X: Byte): Char;',
    'function Succ(const X): Integer;',
    'function Pred(const X): Integer;',
    'function SizeOf(const X): Integer;',
    'function Assigned(const P): Boolean;',
    'procedure Exit;',
    'procedure Break;',
    'procedure Continue;',
    'procedure Halt(ExitCode: Integer = 0);',
    'procedure RunError(ErrorCode: Byte = 0);',
    'procedure Include(var S; I: Integer);',
    'procedure Exclude(var S; I: Integer);',
    'function Abs(X: Extended): Extended;',
    'function Sqr(X: Extended): Extended;',
    'function Sqrt(X: Extended): Extended; function Ln(X: Extended): Extended; function Exp(X: Extended): Extended;',
    'function Sin(X: Extended): Extended; function Cos(X: Extended): Extended; function ArcTan(X: Extended): Extended;',
    'function Odd(X: Longint): Boolean;',
    'function Round(X: Extended): Int64;',
    'function Trunc(X: Extended): Int64;',
    'function Int(X: Extended): Extended;',
    'function Frac(X: Extended): Extended;',
    'function Concat(const S1, S2: string): string;',
    'procedure Assert(Expr: Boolean; const Msg: string = '''');',
    'procedure FillChar(var X; Count: Integer; Value: Byte);',
    'procedure Move(const Source; var Dest; Count: Integer);',
    'procedure Finalize(var V; Count: Integer = 1);',
    'procedure Initialize(var V; Count: Integer = 1);',
    'function TypeInfo(const TypeIdent): Pointer; function TypeOf(const X): Pointer;',
    'function Swap(X: Integer): Integer;',
    'function Hi(X: Integer): Byte;',
    'function Lo(X: Integer): Byte;',
    'function Addr(var X): Pointer;',
    'function Ptr(Address: Integer): Pointer;',
    'function UpCase(Ch: Char): Char; function StringOfChar(Ch: Char; Count: Integer): string;',
    'function Eof(var F: Text): Boolean;',
    'function Eoln(var F: Text): Boolean;',
    'procedure Assign(var F; const FileName: string);',
    'procedure AssignFile(var F; const FileName: string);',
    'procedure Reset(var F; RecSize: Word = 128);',
    'procedure Rewrite(var F; RecSize: Word = 128);',
    'procedure Append(var F: Text);',
    'procedure Close(var F);',
    'procedure CloseFile(var F);',
    'procedure BlockRead(var F: file; var Buf; Count: Integer; var AmtTransferred: Integer);',
    'procedure BlockWrite(var F: file; const Buf; Count: Integer; var AmtTransferred: Integer);',
    'procedure Seek(var F; N: Longint);',
    'function FilePos(var F): Longint;',
    'function FileSize(var F): Integer;',
    'procedure Flush(var F: Text); procedure Truncate(var F); procedure Erase(var F); procedure Rename(var F; NewName: string);',
    'function SeekEof(var F: Text): Boolean; function SeekEoln(var F: Text): Boolean; procedure GetDir(D: Byte; var S: string);',
    'procedure SetTextBuf(var F: Text; var Buf; Size: Integer = 0);',
    'function Random(Range: Integer): Integer; overload; function Random: Extended; overload; procedure Randomize;',
    'function ParamStr(Index: Integer): string; function ParamCount: Integer; function IOResult: Integer;',
    'function Slice(var A; Count: Integer): Pointer; procedure VarArrayRedim(var A: Variant; HighBound: Integer);',
    'procedure VarClear(var V: Variant); procedure VarCast(var Dest: Variant; const Source: Variant; VarType: Integer);',
    'implementation end.');

function BuiltinSource: string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(BuiltinLines) to High(BuiltinLines) do
    Result := Result + BuiltinLines[I] + #13#10;
end;

function ReadFileText(const FileName: string; var Text: string): Boolean;
var
  H: THandle;
  Size, Got: DWORD;
begin
  Result := False;
  Text := '';
  H := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    Size := GetFileSize(H, nil);
    if (Size = $FFFFFFFF) or (Size > 64 * 1024 * 1024) then Exit;
    SetLength(Text, Size);
    Got := 0;
    if Size > 0 then
      if not Windows.ReadFile(H, Text[1], Size, Got, nil) or (Got <> Size) then
      begin
        Text := '';
        Exit;
      end;
    Result := True;
  finally
    CloseHandle(H);
  end;
end;

{ TDirIndex }

destructor TDirIndex.Destroy;
begin
  Files.Free;
  inherited Destroy;
end;

{ TCIEngine }

constructor TCIEngine.Create;
begin
  inherited Create;
  FUnits := TStringList.Create;
  FUnits.Sorted := True;
  FDirs := TStringList.Create;
  FDirs.Sorted := True;
  FPathDirs := TStringList.Create;
  SearchPath := TStringList.Create;
  Defines := TStringList.Create;
  UnitFiles := TStringList.Create;
  UnitFiles.OnChanging := UnitFilesChanging;
  Gen := 1;
  FBuiltin := TUnitInfo.Create;
  FBuiltin.Name := 'System';
  ParseSource(FBuiltin, BuiltinSource, True, nil, nil);
  FBuiltin.Name := 'System';
  FBuiltin.Loaded := True;
end;

destructor TCIEngine.Destroy;
begin
  ClearCache;
  FBuiltin.Free;
  FUnits.Free;
  FDirs.Free;
  FPathDirs.Free;
  SearchPath.Free;
  Defines.Free;
  UnitFiles.Free;
  FUnitIndex.Free;
  inherited Destroy;
end;

{ the indexes of the folders' files go (they are listed again when asked for) }
procedure TCIEngine.ClearDirs;
var
  I: Integer;
begin
  for I := 0 to FDirs.Count - 1 do
    FDirs.Objects[I].Free;
  FDirs.Clear;
end;

{ UnitFiles is about to change (also at the start of an update): its index is made again at the
  next lookup }
procedure TCIEngine.UnitFilesChanging(Sender: TObject);
begin
  FreeAndNil(FUnitIndex);
end;

{ the index of the entry 'Name=...' of a name=value list - the first one of that name, as
  IndexOfName finds it -; -1 none. Index caches the list's names sorted (made when nil). }
function NameIndex(List: TStringList; var Index: TStringList; const Name: string): Integer;
var
  I: Integer;
  N: string;
begin
  if Index = nil then
  begin
    Index := TStringList.Create;
    Index.CaseSensitive := List.CaseSensitive;
    Index.Duplicates := dupIgnore;
    Index.Sorted := True;
    for I := 0 to List.Count - 1 do
    begin
      N := List.Names[I];
      if N <> '' then Index.AddObject(N, TObject(I));
    end;
  end;
  if Index.Find(Name, I) then Result := Integer(Index.Objects[I]) else Result := -1;
end;

procedure TCIEngine.BeginCall;
begin
  Inc(Gen);
  if Gen > $3FFFFFFF then
  begin
    ClearCache;
    Gen := 2;
  end;
  CurUnit := nil;
end;

procedure TCIEngine.ClearCache;
var
  I: Integer;
begin
  for I := 0 to FUnits.Count - 1 do
    FUnits.Objects[I].Free;
  FUnits.Clear;
  ClearDirs;
  FSystem := nil;
  FSystemGen := 0;
  FSysInit := nil;
  FSysInitGen := 0;
  CurUnit := nil;
  FPathValid := False;
end;

procedure TCIEngine.PathChanged;
var
  I: Integer;
begin
  FPathValid := False;
  ClearDirs;
  FreeAndNil(FUnitIndex);
  // unit name -> file bindings may change: force re-resolution (cheap)
  for I := 0 to FUnits.Count - 1 do
    TUnitInfo(FUnits.Objects[I]).UnitsGen := 0;
  FSystemGen := 0;
  FSysInitGen := 0;
end;

procedure TCIEngine.DefinesChanged;
var
  I: Integer;
begin
  for I := 0 to FUnits.Count - 1 do
    TUnitInfo(FUnits.Objects[I]).Loaded := False;
end;

procedure TCIEngine.InvalidateFile(const FileName: string);
var
  I: Integer;
  D: string;
begin
  if FUnits.Find(AnsiUpperCase(NormFileName(FileName)), I) then
    TUnitInfo(FUnits.Objects[I]).FileAgeStamp := -2;
  // a new file may have appeared in that directory
  D := AnsiUpperCase(ExcludeTrailingPathDelimiter(ExtractFilePath(NormFileName(FileName))));
  if FDirs.Find(D, I) then
    TDirIndex(FDirs.Objects[I]).Tick := GetTickCount - 100000;
end;

{ a name ExpandFileName must not touch: '<untitled>' and the like, and the marked names
  '?U:<UTF-8 path>' of SdFileNames (its ExpandPathU leaves them alone too) - expanded, the
  marked name became '<current dir>\?U:...' and Find Declaration opened that }
function IsSpecialName(const FileName: string): Boolean;
begin
  Result := (FileName <> '') and (FileName[1] in ['<', '?']);
end;

function TCIEngine.NormFileName(const FileName: string): string;
begin
  if FileName = '' then
    Result := '<untitled>'
  else if (Length(FileName) > 2) and ((FileName[2] = ':') or ((FileName[1] = '\') and (FileName[2] = '\'))) and
    (Pos('..', FileName) = 0) and (Pos('/', FileName) = 0) then
    Result := FileName
  else if IsSpecialName(FileName) then
    Result := FileName
  else
    Result := ExpandFileName(FileName);
end;

function TCIEngine.ReadSource(const FileName: string; var Text: string): Boolean;
begin
  if not Assigned(ReadFileFunc) then
  begin
    Result := ReadFileText(FileName, Text);
    Exit;
  end;
  try
    Text := ReadFileFunc(FileName);
    Result := True;
  except
    Text := '';
    Result := False;
  end;
end;

function TCIEngine.FileAgeOf(const FileName: string): Integer;
begin
  if Assigned(FileAgeFunc) then Result := FileAgeFunc(FileName) else Result := FileAge(FileName);
end;

function TCIEngine.FileThere(const FileName: string): Boolean;
begin
  Result := FileAgeOf(FileName) <> -1;
end;

{ the cache entry of a file, under its full name (NormFileName): a unit found through a relative
  folder of the search path ('..\lib') is the same entry as the file's full name - InvalidateFile
  reaches it, and it is never parsed twice }
function TCIEngine.GetEntry(const FileName: string): TUnitInfo;
var
  Key, F: string;
  I: Integer;
begin
  F := NormFileName(FileName);
  Key := AnsiUpperCase(F);
  if FUnits.Find(Key, I) then
    Result := TUnitInfo(FUnits.Objects[I])
  else
  begin
    Result := TUnitInfo.Create;
    Result.FileName := F;
    Result.Name := ChangeFileExt(ExtractFileName(F), '');
    FUnits.AddObject(Key, Result);
  end;
end;

procedure TCIEngine.BuildPathDirs;
var
  I, P: Integer;
  S, D: string;
begin
  FPathDirs.Clear;
  for I := 0 to SearchPath.Count - 1 do
  begin
    S := SearchPath[I];
    while S <> '' do
    begin
      P := Pos(';', S);
      if P = 0 then P := Length(S) + 1;
      D := Trim(Copy(S, 1, P - 1));
      Delete(S, 1, P);
      if (Length(D) >= 2) and (D[1] = '"') and (D[Length(D)] = '"') then
        D := Copy(D, 2, Length(D) - 2);
      D := ExcludeTrailingPathDelimiter(D);
      if (D <> '') and (FPathDirs.IndexOf(D) < 0) then FPathDirs.Add(D);
    end;
  end;
  FPathValid := True;
end;

function TCIEngine.DirIndex(const ADir: string): TDirIndex;
var
  Key: string;
  I: Integer;
  SR: TSearchRec;
  Tick: Cardinal;
begin
  Key := AnsiUpperCase(ADir);
  Tick := GetTickCount;
  if FDirs.Find(Key, I) then
  begin
    Result := TDirIndex(FDirs.Objects[I]);
    if Tick - Result.Tick < 5000 then Exit;
    Result.Files.Clear;
  end
  else
  begin
    Result := TDirIndex.Create;
    Result.Files := TStringList.Create;
    FDirs.AddObject(Key, Result);
  end;
  Result.Files.Sorted := False;
  if FindFirst(ADir + '\*.pas', faAnyFile and not faDirectory, SR) = 0 then
  begin
    repeat
      if SameText(ExtractFileExt(SR.Name), '.pas') then
        Result.Files.Add(ChangeFileExt(SR.Name, ''));
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
  Result.Files.Sorted := True;
  Result.Tick := Tick;
end;

function TCIEngine.FindUnitFile(const UnitName, FromFile: string): string;
var
  J: Integer;
  FU: TUnitInfo;
begin
  FU := nil;
  if (FromFile <> '') and (FromFile[1] <> '<') and FUnits.Find(AnsiUpperCase(NormFileName(FromFile)), J) then
    FU := TUnitInfo(FUnits.Objects[J]);
  Result := FindUnitFor(UnitName, FromFile, FU);
end;

{ FindUnitFile with the referencing file's cache entry at hand (FromU, nil: none): its
  "uses X in 'path'" clauses come before the folders }
function TCIEngine.FindUnitFor(const UnitName, FromFile: string; FromU: TUnitInfo): string;
var
  I, J: Integer;
  D, P: string;
  DI: TDirIndex;
begin
  Result := '';
  if UnitName = '' then Exit;
  // explicit mapping supplied by the IDE
  I := NameIndex(UnitFiles, FUnitIndex, UnitName);
  if I >= 0 then
  begin
    Result := Copy(UnitFiles[I], Length(UnitName) + 2, MaxInt);
    if Result <> '' then Exit;
  end;
  D := '';
  if (FromFile <> '') and (FromFile[1] <> '<') then
  begin
    D := ExcludeTrailingPathDelimiter(ExtractFilePath(FromFile));
    // "uses X in 'path'" of the referencing file
    if FromU <> nil then
    begin
      if FromU.UsesIn.Count > 0 then
      begin
        J := NameIndex(FromU.UsesIn, FromU.UsesInIndex, UnitName);
        if J >= 0 then
        begin
          P := Copy(FromU.UsesIn[J], Length(UnitName) + 2, MaxInt);
          if (Length(P) > 1) and (P[2] <> ':') and (P[1] <> '\') and (D <> '') then
          begin
            if IsSpecialName(D) then P := D + '\' + P else P := ExpandFileName(D + '\' + P);
          end;
          if FileThere(P) then
          begin
            Result := P;
            Exit;
          end;
        end;
      end;
    end;
    if IsSpecialName(D) then
    begin
      // a folder the ANSI functions cannot list (a marked name): ask for the file itself
      P := D + '\' + UnitName + '.pas';
      if FileThere(P) then
      begin
        Result := P;
        Exit;
      end;
    end
    else if D <> '' then
    begin
      DI := DirIndex(D);
      if DI.Files.Find(UnitName, J) then
      begin
        Result := D + '\' + DI.Files[J] + '.pas';
        Exit;
      end;
    end;
  end;
  if not FPathValid then BuildPathDirs;
  for I := 0 to FPathDirs.Count - 1 do
  begin
    DI := DirIndex(FPathDirs[I]);
    if DI.Files.Find(UnitName, J) then
    begin
      Result := FPathDirs[I] + '\' + DI.Files[J] + '.pas';
      Exit;
    end;
  end;
end;

procedure TCIEngine.GetUnitNames(List: TStrings; const FromFile: string);
var
  I, J: Integer;
  DI: TDirIndex;
  D: string;
  Seen: TStringList;
begin
  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    Seen.Duplicates := dupIgnore;
    for I := 0 to UnitFiles.Count - 1 do
      if UnitFiles.Names[I] <> '' then Seen.Add(UnitFiles.Names[I]);
    // (a folder with a marked name cannot be listed through the ANSI functions)
    if not IsSpecialName(FromFile) then
    begin
      D := ExcludeTrailingPathDelimiter(ExtractFilePath(FromFile));
      if D <> '' then
      begin
        DI := DirIndex(D);
        for J := 0 to DI.Files.Count - 1 do Seen.Add(DI.Files[J]);
      end;
    end;
    if not FPathValid then BuildPathDirs;
    for I := 0 to FPathDirs.Count - 1 do
    begin
      DI := DirIndex(FPathDirs[I]);
      for J := 0 to DI.Files.Count - 1 do Seen.Add(DI.Files[J]);
    end;
    List.AddStrings(Seen);
  finally
    Seen.Free;
  end;
end;

function TCIEngine.HandleInclude(const IncName: string; var Text: string): Boolean;
var
  N: string;
  I: Integer;
begin
  Result := False;
  N := IncName;
  if ExtractFileExt(N) = '' then N := N + '.pas';
  if (Length(N) > 1) and ((N[2] = ':') or (N[1] = '\')) then
  begin
    Result := ReadSource(N, Text);
    Exit;
  end;
  if (FIncDir <> '') and FileThere(FIncDir + N) then
  begin
    Result := ReadSource(FIncDir + N, Text);
    Exit;
  end;
  if not FPathValid then BuildPathDirs;
  for I := 0 to FPathDirs.Count - 1 do
    if FileThere(FPathDirs[I] + '\' + N) then
    begin
      Result := ReadSource(FPathDirs[I] + '\' + N, Text);
      Exit;
    end;
end;

procedure TCIEngine.DoParse(U: TUnitInfo; const S: string; Full, CanTruncate: Boolean);
var
  DefName: string;
begin
  DefName := ChangeFileExt(ExtractFileName(U.FileName), '');
  if (U.FileName <> '') and (U.FileName[1] <> '<') then
    FIncDir := ExtractFilePath(U.FileName)
  else
    FIncDir := '';
  U.Name := DefName;
  ParseSource(U, S, not Full, Defines, HandleInclude);
  if U.Name = '' then U.Name := DefName;
  // interface-only units read from disk keep just the interface text (saves memory)
  if CanTruncate and not Full and not U.IsProgram and (U.ImplOfs < MaxInt) and
    (U.ImplOfs + 4096 < Length(S)) then
    U.Source := Copy(S, 1, U.ImplOfs + 14);
end;

function TCIEngine.LoadFile(const FileName: string): TUnitInfo;
var
  U: TUnitInfo;
  S, F: string;
  Age: Integer;
  Changed, FromIDE: Boolean;
begin
  U := GetEntry(FileName);
  Result := U;
  if U = CurUnit then Exit;
  if U.CheckGen <> Gen then
  begin
    F := U.FileName;
    U.CheckGen := Gen;
    FromIDE := False;
    S := '';
    if Assigned(OnGetSource) then
      try
        FromIDE := OnGetSource(F, S);
      except
        FromIDE := False;
      end;
    if FromIDE then
      Changed := (not U.Loaded) or (not U.FromIDE) or (U.Source <> S)
    else
    begin
      Age := FileAgeOf(F);
      Changed := (not U.Loaded) or U.FromIDE or (Age <> U.FileAgeStamp);
      if Changed then
      begin
        if (Age = -1) or not ReadSource(F, S) then S := '';
        U.FileAgeStamp := Age;
      end;
    end;
    if Changed then
    begin
      DoParse(U, S, False, not FromIDE);
      U.FromIDE := FromIDE;
      U.Loaded := True;
    end;
  end;
end;

function TCIEngine.LoadCurrent(const FileName, Source: string): TUnitInfo;
var
  U: TUnitInfo;
begin
  U := GetEntry(FileName);
  CurUnit := U;
  if (not U.Loaded) or (not U.FullParsed) or (U.Source <> Source) then
    DoParse(U, Source, True, False);
  U.Loaded := True;
  U.FromIDE := True;
  U.CheckGen := Gen;
  Result := U;
end;

function TCIEngine.SystemUnit: TUnitInfo;
var
  F: string;
begin
  if FSystemGen <> Gen then
  begin
    FSystemGen := Gen;
    F := FindUnitFile('System', '');
    if F <> '' then FSystem := LoadFile(F) else FSystem := nil;
  end;
  Result := FSystem;
end;

function TCIEngine.SysInitUnit: TUnitInfo;
var
  F: string;
begin
  if FSysInitGen <> Gen then
  begin
    FSysInitGen := Gen;
    F := FindUnitFile('SysInit', '');
    if F <> '' then FSysInit := LoadFile(F) else FSysInit := nil;
  end;
  Result := FSysInit;
end;

function TCIEngine.UnitByName(const Name: string; FromUnit: TUnitInfo): TUnitInfo;
var
  F: string;
begin
  if (FromUnit <> nil) and SameText(Name, FromUnit.Name) then
    Result := FromUnit
  else if (CurUnit <> nil) and SameText(Name, CurUnit.Name) then
    Result := CurUnit
  else if SameText(Name, 'System') then
  begin
    Result := SystemUnit;
    if Result = nil then Result := FBuiltin;
  end
  else
  begin
    if FromUnit <> nil then F := FindUnitFor(Name, FromUnit.FileName, FromUnit)
    else F := FindUnitFor(Name, '', nil);
    if F = '' then Result := nil
    else Result := LoadFile(F);
  end;
end;

{ the units of U's uses clauses; an open file's (FromIDE) units still to come into its interface
  clause (OnGetPendingUses) after the interface's own - where FSAddUses appends them, so they come
  first in the lookup, as the compiler will see them; one the clause names already is not added
  twice. A unit that is not found is nil: its scope is not known (TCIContext.ScopeKnown) }
procedure TCIEngine.ResolveUses(U: TUnitInfo);
var
  I, N: Integer;
  Pending: TStringList;
begin
  if U.UnitsGen = Gen then Exit;
  U.UnitsGen := Gen;
  Pending := TStringList.Create;
  try
    if U.FromIDE and Assigned(OnGetPendingUses) then
    begin
      try
        OnGetPendingUses(U.FileName, Pending);
      except
        Pending.Clear;
      end;
      for I := Pending.Count - 1 downto 0 do
        if (U.IntfUses.IndexOf(Pending[I]) >= 0) or (Pending.IndexOf(Pending[I]) < I) then Pending.Delete(I);
    end;
    N := U.IntfUses.Count;
    SetLength(U.IntfUnits, N + Pending.Count);
    for I := 0 to N - 1 do
      U.IntfUnits[I] := UnitByName(U.IntfUses[I], U);
    for I := 0 to Pending.Count - 1 do
      U.IntfUnits[N + I] := UnitByName(Pending[I], U);
  finally
    Pending.Free;
  end;
  SetLength(U.ImplUnits, U.ImplUses.Count);
  for I := 0 to U.ImplUses.Count - 1 do
    U.ImplUnits[I] := UnitByName(U.ImplUses[I], U);
end;

function UnitSyms(UU: TUnitInfo): TSymTable;
begin
  if UU.IsProgram then Result := UU.ImplSyms else Result := UU.IntfSyms;
end;

function TCIEngine.NextScope(U: TUnitInfo; InImpl: Boolean; var Cursor: TScopeCursor;
  out Tab: TSymTable; out Hide: Boolean): Boolean;
var
  UU: TUnitInfo;
begin
  Result := True;
  Hide := False;
  while True do
    case Cursor.Step of
      0:
        begin
          Cursor.Step := 1;
          if InImpl then
          begin
            Tab := U.ImplSyms;
            Exit;
          end;
        end;
      1:
        begin
          Cursor.Step := 2;
          Tab := U.IntfSyms;
          Exit;
        end;
      2:
        begin
          ResolveUses(U);
          Cursor.Step := 3;
          if InImpl then Cursor.Index := High(U.ImplUnits) else Cursor.Index := -1;
        end;
      3, 4:   // the units the implementation, then the interface use, the last one first
        if Cursor.Index < 0 then
        begin
          if Cursor.Step = 3 then Cursor.Index := High(U.IntfUnits);
          Inc(Cursor.Step);
        end
        else
        begin
          if Cursor.Step = 3 then UU := U.ImplUnits[Cursor.Index] else UU := U.IntfUnits[Cursor.Index];
          Dec(Cursor.Index);
          if UU <> nil then
          begin
            Tab := UU.IntfSyms;
            Hide := SameText(UU.Name, 'System');
            Exit;
          end;
        end;
      5:
        begin
          Cursor.Step := 6;
          if U <> FBuiltin then
          begin
            UU := SystemUnit;
            if (UU <> nil) and (UU <> U) then
            begin
              Tab := UU.IntfSyms;
              Hide := True;
              Exit;
            end;
          end;
        end;
      6:   // SysInit: the compiler adds it to every unit, as it adds System (HInstance ...)
        begin
          Cursor.Step := 7;
          if U <> FBuiltin then
          begin
            UU := SysInitUnit;
            if (UU <> nil) and (UU <> U) then
            begin
              Tab := UU.IntfSyms;
              Hide := True;
              Exit;
            end;
          end;
        end;
      7:
        begin
          Cursor.Step := 8;
          if U <> FBuiltin then
          begin
            Tab := FBuiltin.IntfSyms;
            Hide := True;
            Exit;
          end;
        end;
    else
      Result := False;
      Exit;
    end;
end;

function TCIEngine.FindInUnitScope(P: PChar; Len: Integer; U: TUnitInfo; InImpl: Boolean): TSymbol;
var
  H: Cardinal;
  C: TScopeCursor;
  Tab: TSymTable;
  Hide: Boolean;
begin
  H := HashUpper(P, Len);
  C.Step := 0;
  C.Index := 0;
  while NextScope(U, InImpl, C, Tab, Hide) do
  begin
    Result := Tab.FindHashed(P, Len, H);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;

function TCIEngine.FindQualified(const Name: string; U: TUnitInfo; InImpl: Boolean;
  OwnerRoutine: TSymbol): TSymbol;
var
  D, I: Integer;
  Left, Right: string;
  UU: TUnitInfo;
  R: TSymbol;
begin
  Result := nil;
  if (Name = '') or (U = nil) then Exit;
  D := Pos('.', Name);
  if D = 0 then
  begin
    R := OwnerRoutine;
    I := 0;
    while (R <> nil) and (R is TRoutineSym) and (I < 32) do
    begin
      if TRoutineSym(R).Locals <> nil then
      begin
        Result := TRoutineSym(R).Locals.Find(Name);
        if Result <> nil then Exit;
      end;
      if R.Owner is TRoutineSym then R := TSymbol(R.Owner) else R := nil;
      Inc(I);
    end;
    Result := FindInUnitScope(PChar(Name), Length(Name), U, InImpl);
  end
  else
  begin
    Left := Copy(Name, 1, D - 1);
    Right := Copy(Name, D + 1, MaxInt);
    D := Pos('.', Right);
    while D > 0 do
    begin
      Delete(Right, 1, D);
      D := Pos('.', Right);
    end;
    UU := UnitByName(Left, U);
    if UU = nil then Exit;
    if (UU = U) and InImpl then Result := U.ImplSyms.Find(Right);
    if Result = nil then Result := UnitSyms(UU).Find(Right);
    if (Result = nil) and (UU <> FBuiltin) and SameText(Left, 'System') then
      Result := FBuiltin.IntfSyms.Find(Right);
  end;
end;

function TCIEngine.ResolveDesc(D: TTypeDesc): TTypeDesc;
var
  Depth: Integer;
  S: TSymbol;
  Tab: TSymTable;
begin
  Result := D;
  Depth := 0;
  while Result <> nil do
  begin
    Inc(Depth);
    if Depth > 40 then
    begin
      Result := nil;
      Exit;
    end;
    case Result.Kind of
      tyAlias:
        begin
          S := FindQualified(Result.RefName, Result.UnitInfo, Result.InImpl, Result.OwnerRoutine);
          if (S = nil) or (S.Kind <> skType) or (S.TypeDesc = nil) or (S.TypeDesc = Result) then
          begin
            Result := nil;
            Exit;
          end;
          Result := S.TypeDesc;
        end;
      tyClass, tyInterface:
        begin
          if not Result.IsForward then Exit;
          // unresolved forward declaration: look for a complete one with the same name
          if (Result.Sym = nil) or (Result.UnitInfo = nil) then
          begin
            Result := nil;
            Exit;
          end;
          if Result.InImpl then Tab := Result.UnitInfo.ImplSyms else Tab := Result.UnitInfo.IntfSyms;
          S := Tab.Find(Result.Sym.Name);
          while (S <> nil) and not ((S.Kind = skType) and (S.TypeDesc <> nil) and not S.TypeDesc.IsForward) do
            S := Tab.FindNext(S);
          if S = nil then Exit;   // keep the forward (no members)
          Result := S.TypeDesc;
        end;
    else
      Exit;
    end;
  end;
end;

function TCIEngine.IsRootType(D: TTypeDesc): Boolean;
begin
  Result := False;
  if D.Sym = nil then Exit;
  if D.Kind = tyClass then
    Result := SameText(D.Sym.Name, 'TObject')
  else if D.Kind = tyInterface then
    Result := SameText(D.Sym.Name, 'IInterface') or SameText(D.Sym.Name, 'IUnknown');
end;

function TCIEngine.AncestorOf(D: TTypeDesc): TTypeDesc;
var
  S: TSymbol;
  AncName: string;
begin
  if D.AncGen = Gen then
  begin
    Result := D.AncCache;
    Exit;
  end;
  D.AncGen := Gen;
  D.AncCache := nil;
  Result := nil;
  AncName := '';
  if D.Kind in [tyClass, tyInterface, tyObject] then
  begin
    if (D.Ancestors <> nil) and (D.Ancestors.Count > 0) then
      AncName := D.Ancestors[0]
    else if IsRootType(D) then
      AncName := ''
    else if D.Kind = tyClass then
      AncName := 'TObject'
    else if D.Kind = tyInterface then
      AncName := 'IInterface';
    if AncName <> '' then
    begin
      S := FindQualified(AncName, D.UnitInfo, D.InImpl, D.OwnerRoutine);
      if (S <> nil) and (S.Kind = skType) and (S.TypeDesc <> nil) and (S.TypeDesc <> D) then
        Result := ResolveDesc(S.TypeDesc);
      if Result = D then Result := nil;
      if (Result <> nil) and not (Result.Kind in [tyClass, tyInterface, tyObject, tyRecord]) then
        Result := nil;
    end;
  end;
  D.AncCache := Result;
end;

function TCIEngine.FindMember(D: TTypeDesc; P: PChar; Len: Integer; out DeclDesc: TTypeDesc): TSymbol;
var
  H: Cardinal;
  Depth: Integer;
  Cur: TTypeDesc;
begin
  H := HashUpper(P, Len);
  Cur := D;
  Depth := 0;
  while (Cur <> nil) and (Depth < 64) do
  begin
    if Cur.Members <> nil then
    begin
      Result := Cur.Members.FindHashed(P, Len, H);
      if Result <> nil then
      begin
        DeclDesc := Cur;
        Exit;
      end;
    end;
    Cur := AncestorOf(Cur);
    Inc(Depth);
  end;
  Result := nil;
  DeclDesc := nil;
end;

function TCIEngine.InheritsFrom(D, Anc: TTypeDesc): Boolean;
var
  Depth: Integer;
begin
  Result := True;
  Depth := 0;
  while (D <> nil) and (Depth < 64) do
  begin
    if D = Anc then Exit;
    D := AncestorOf(D);
    Inc(Depth);
  end;
  Result := False;
end;

function TCIEngine.PropertyType(S: TSymbol): TTypeDesc;
var
  D, DD: TTypeDesc;
  M: TSymbol;
  Depth: Integer;
begin
  Result := S.TypeDesc;
  if (Result <> nil) or not (S.Owner is TTypeDesc) then Exit;
  D := AncestorOf(TTypeDesc(S.Owner));
  Depth := 0;
  while (D <> nil) and (Depth < 64) do
  begin
    M := FindMember(D, PChar(S.Name), Length(S.Name), DD);
    if M = nil then Exit;
    if M.TypeDesc <> nil then
    begin
      Result := M.TypeDesc;
      Exit;
    end;
    D := AncestorOf(DD);
    Inc(Depth);
  end;
end;

{ display text }

function TCIEngine.RangeText(U: TUnitInfo; A, B: Integer; MaxLen: Integer): string;
begin
  Result := '';
  if (U = nil) or (B <= A) or (A < 0) or (B > Length(U.Source)) then Exit;
  Result := NormalizeText(PChar(U.Source) + A, B - A, MaxLen);
end;

function TCIEngine.TypeText(S: TSymbol): string;
var
  D: TTypeDesc;
begin
  Result := S.DispType;
  if Result <> '' then Exit;
  D := S.TypeDesc;
  case S.Kind of
    skType: Result := '';
    skEnumValue:
      if (D <> nil) and (D.Sym <> nil) then Result := D.Sym.Name;
  else
    if (D <> nil) and (D.Kind in [tyRecord, tyClass, tyInterface, tyObject]) then
    begin
      case D.Kind of
        tyRecord: Result := 'record';
        tyClass: Result := 'class';
        tyInterface: Result := 'interface';
        tyObject: Result := 'object';
      end;
    end
    else if S.TypeEnd > S.TypeStart then
      Result := RangeText(S.UnitInfo, S.TypeStart, S.TypeEnd, 100)
    else if (D <> nil) and (D.Kind = tyAlias) then
      Result := D.RefName
    else if (S.Kind = skProperty) and (D = nil) then
    begin
      D := PropertyType(S);
      if (D <> nil) and (D.Kind = tyAlias) then Result := D.RefName;
    end;
  end;
  S.DispType := Result;
end;

function TCIEngine.ParamsText(S: TSymbol): string;
begin
  Result := RoutineParamsText(S);
end;

function TCIEngine.HeadingText(R: TRoutineSym; Qualified, WithDirectives: Boolean): string;
var
  P, T: string;
begin
  Result := RoutineKeyword(R) + ' ';
  if Qualified then
  begin
    if R.ClassQual <> '' then Result := Result + R.ClassQual + '.'
    else if (R.Owner is TTypeDesc) and (TTypeDesc(R.Owner).Sym <> nil) then
      Result := Result + TTypeDesc(R.Owner).Sym.Name + '.';
  end;
  Result := Result + R.Name;
  P := ParamsText(R);
  if P <> '' then Result := Result + '(' + P + ')';
  T := TypeText(R);
  if T <> '' then Result := Result + ': ' + T;
  if WithDirectives then
  begin
    if sfOverload in R.Flags then Result := Result + '; overload';
    if sfVirtual in R.Flags then Result := Result + '; virtual';
    if sfDynamic in R.Flags then Result := Result + '; dynamic';
    if sfOverride in R.Flags then Result := Result + '; override';
    if sfAbstract in R.Flags then Result := Result + '; abstract';
  end;
end;

function TCIEngine.ParamText(P: TSymbol): string;
var
  T: string;
begin
  Result := ParamModifier(P);
  if Result <> '' then Result := Result + ' ';
  Result := Result + P.Name;
  if P.TypeEnd > P.TypeStart then
  begin
    T := RangeText(P.UnitInfo, P.TypeStart, P.TypeEnd, 100);
    Result := Result + ': ' + T;
    if (sfHasDefault in P.Flags) and (P.DeclEnd > P.TypeEnd) then
      Result := Result + ' ' + RangeText(P.UnitInfo, P.TypeEnd, P.DeclEnd, 60);
  end;
end;

function TCIEngine.DeclText(S: TSymbol): string;
var
  D: TTypeDesc;
  T: string;
  I: Integer;
begin
  if sfDispReady in S.Flags then
  begin
    Result := S.DispDecl;
    Exit;
  end;
  Result := '';
  D := S.TypeDesc;
  case S.Kind of
    skConst, skResStr:
      begin
        if S.DeclEnd > S.DeclStart then
          Result := RangeText(S.UnitInfo, S.DeclStart, S.DeclEnd, 120)
        else
          Result := S.Name;
        if S.Kind = skResStr then Result := 'resourcestring ' + Result
        else Result := 'const ' + Result;
      end;
    skVar, skLocal, skField:
      begin
        T := TypeText(S);
        Result := 'var ' + S.Name;
        if T <> '' then Result := Result + ': ' + T;
      end;
    skParam:
      Result := ParamText(S);
    skEnumValue:
      begin
        T := TypeText(S);
        Result := 'const ' + S.Name;
        if T <> '' then Result := Result + ': ' + T;
      end;
    skLabel:
      Result := 'label ' + S.Name;
    skProperty:
      begin
        Result := 'property ' + S.Name;
        T := ParamsText(S);
        if T <> '' then Result := Result + '[' + T + ']';
        T := TypeText(S);
        if T <> '' then Result := Result + ': ' + T;
      end;
    skRoutine:
      Result := HeadingText(TRoutineSym(S), False, True);
    skType:
      begin
        Result := S.Name;
        if (D <> nil) and (S.UnitInfo = FBuiltin) and (D.Kind = tyAlias) and (Copy(D.RefName, 1, 2) = '__') then
          Result := 'type ' + S.Name
        else if D <> nil then
          case D.Kind of
            tyClass, tyInterface, tyObject:
              begin
                case D.Kind of
                  tyClass: Result := Result + ' = class';
                  tyInterface: Result := Result + ' = interface';
                  tyObject: Result := Result + ' = object';
                end;
                if (D.Ancestors <> nil) and (D.Ancestors.Count > 0) then
                begin
                  Result := Result + '(';
                  for I := 0 to D.Ancestors.Count - 1 do
                  begin
                    if I > 0 then Result := Result + ', ';
                    Result := Result + D.Ancestors[I];
                  end;
                  Result := Result + ')';
                end;
              end;
            tyRecord:
              Result := Result + ' = record';
          else
            if S.TypeEnd > S.TypeStart then
              Result := Result + ' = ' + RangeText(S.UnitInfo, S.TypeStart, S.TypeEnd, 120);
          end;
      end;
  else
    Result := S.Name;
  end;
  S.DispDecl := Result;
  Include(S.Flags, sfDispReady);
end;

end.
