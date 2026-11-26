{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTypeLib;

{ D7 Studio - COM type libraries: the registered libraries and
  ActiveX controls (HKCR\TypeLib, HKCR\CLSID\...\Control), and the Pascal unit of a library as
  Delphi 7's importer writes it (Project | Import Type Library, Component | Import ActiveX
  Control, the Text of the Type Library view): <Library>_TLB.pas with the GUIDs, enumerations,
  interfaces and their dispinterfaces, records, unions and aliases, the CoClass creators and the
  component wrappers - TOleControl for a control, TOleServer for any other CoClass. A library
  whose types this one uses is imported with it (its unit is in the uses clause); the types of
  stdole are the unit ActiveX's. }

interface

uses
  Windows, SysUtils, Classes, ActiveX;

type
  { a registered library, or the library of a registered ActiveX control }
  TTypeLibRef = class
  public
    Name: string;             // its help string: "Microsoft Scripting Runtime"
    Guid: TGUID;
    Major, Minor: Word;
    Lcid: Integer;
    FileName: string;         // its file (win32)
    ControlName: string;      // an ActiveX control: the control's name
  end;

  TTLBOptions = record
    Wrappers: Boolean;        // component wrappers: TOleControl, TOleServer
    ControlsOnly: Boolean;    // wrappers for the controls only (Import ActiveX Control)
    PalettePage: string;      // where Register puts them
    { Environment Options | Type Library | SafeCall function mapping: 0 every v-table interface,
      1 dual ones (Delphi's default), 2 none }
    Safecall: Integer;
  end;

  { the import of a library: its unit and the units of the libraries it needs }
  TTLBImport = class
  private
    FOptions: TTLBOptions;
    FWriters: TList;          // TTLBWriter, the first is the library imported
    function WriterOf(TL: ITypeLib): TObject;
  public
    constructor Create(const AOptions: TTLBOptions);
    destructor Destroy; override;
    { the units of TL and of the libraries it needs; returns the unit name of TL }
    function Import(TL: ITypeLib): string;
    function Count: Integer;
    function UnitName(I: Integer): string;
    function Source(I: Integer): string;
    { a type of TL as the unit declares it - TypeLibTypeText's text, with the names of the
      library's types made once for all the calls of one import }
    function TypeText(TL: ITypeLib; Index: Integer): string;
  end;

procedure ListTypeLibraries(List: TStrings);     // "Name (Version x.y)" -> TTypeLibRef
procedure ListActiveXControls(List: TStrings);   // "Name (Version x.y)" -> TTypeLibRef
procedure FreeTypeLibRefs(List: TStrings);
function IsTypeLibFile(const FileName: string): Boolean;      // .tlb, .olb: a type library of its own
function LoadTypeLibrary(const FileName: string): ITypeLib;   // raises EOleSysError
function LoadTypeLibraryRef(Ref: TTypeLibRef): ITypeLib;
function TypeLibName(TL: ITypeLib): string;      // its name in the library: "Scripting"
function TypeLibHelp(TL: ITypeLib): string;      // its help string
function TypeLibUnitName(TL: ITypeLib): string;  // Scripting_TLB
{ the wrapper classes an import makes, one per line }
function TypeLibWrapperNames(TL: ITypeLib; const Options: TTLBOptions): string;
{ a type of the library as the unit declares it (the Type Library view) }
function TypeLibTypeText(TL: ITypeLib; Index: Integer): string;
{ a new import with the options of that text and of the library's unit in the Type Library view:
  no wrappers, the safecall mapping of dual interfaces (the caller frees it) }
function TypeLibTextImport: TTLBImport;

{ the GUID of a type of a library (zero when it has none) }
function GuidOf(TI: ITypeInfo): TGUID;

implementation

uses
  Registry, ComObj, Variants, SdEncoding, SdFileNames;

const
  VT_RECORD = 36;           // (not in Delphi 7's ActiveX)
  StdOleLib: TGUID = '{00020430-0000-0000-C000-000000000046}';

  { names a library's identifier may not take in its unit: Pascal's reserved words, the types
    the unit uses }
  ReservedWords: array[0..65] of string = ('and', 'array', 'as', 'asm', 'begin', 'case', 'class',
    'const', 'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto', 'else', 'end',
    'except', 'exports', 'file', 'finalization', 'finally', 'for', 'function', 'goto', 'if',
    'implementation', 'in', 'inherited', 'initialization', 'inline', 'interface', 'is', 'label',
    'library', 'mod', 'nil', 'not', 'object', 'of', 'or', 'out', 'packed', 'procedure', 'program',
    'property', 'raise', 'record', 'repeat', 'resourcestring', 'set', 'shl', 'shr', 'string',
    'then', 'threadvar', 'to', 'try', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with',
    'xor', 'result');
  UnitNames: array[0..43] of string = ('Integer', 'Smallint', 'Shortint', 'Byte', 'Word',
    'LongWord', 'Int64', 'Single', 'Double', 'Currency', 'TDateTime', 'WideString', 'WordBool',
    'OleVariant', 'IUnknown', 'IDispatch', 'HResult', 'SCODE', 'TDecimal', 'SYSINT', 'SYSUINT',
    'Largeuint', 'Pointer', 'PSafeArray', 'TGUID', 'TOleEnum', 'TColor', 'TFont', 'TPicture',
    'TOleControl', 'TOleServer', 'TComponent', 'TObject', 'TControlData2', 'TServerData',
    'TVariantArray', 'TVarData', 'TDispID', 'TNotifyEvent', 'Register', 'dtlOcxPage',
    'dtlServerPage', 'PChar', 'PWideChar');
  { members of TOleControl / TOleServer and their ancestors: a wrapper's member of that name gets
    an underscore }
  WrapperMembers: array[0..97] of string = ('Create', 'Destroy', 'Free', 'ClassName', 'ClassType',
    'ClassInfo', 'ClassParent', 'InheritsFrom', 'Dispatch', 'Assign', 'Name', 'Tag', 'Owner',
    'Components', 'ComponentCount', 'ComponentIndex', 'ComponentState', 'Parent', 'Left', 'Top',
    'Width', 'Height', 'Align', 'Anchors', 'Visible', 'Enabled', 'Hint', 'ShowHint', 'Color',
    'Font', 'Caption', 'Text', 'Cursor', 'PopupMenu', 'Handle', 'TabStop', 'TabOrder', 'Controls',
    'ControlCount', 'Refresh', 'Repaint', 'Update', 'Invalidate', 'SetFocus', 'Focused', 'Show',
    'Hide', 'BringToFront', 'SendToBack', 'ClientWidth', 'ClientHeight', 'ClientRect',
    'BoundsRect', 'Constraints', 'Action', 'DragMode', 'DragCursor', 'DragKind', 'BiDiMode',
    'ParentShowHint', 'ParentFont', 'ParentColor', 'HelpContext', 'HelpType', 'HelpKeyword',
    'OleObject', 'DefaultDispatch', 'ControlData', 'Perform', 'Click', 'DblClick', 'WindowProc',
    'Brush', 'DoubleBuffered', 'Showing', 'Loaded', 'InitControlData', 'CreateControl',
    'ControlInterface', 'DefaultInterface', 'Connect', 'ConnectTo', 'Disconnect', 'AutoConnect',
    'ConnectKind', 'RemoteMachineName', 'ServerData', 'InitServerData', 'InvokeEvent',
    'GetServer', 'Release', 'AddRef', 'QueryInterface', 'Destroying', 'Notification',
    'SetBounds', 'DoObjectVerb', 'AboutBox');
  { the published members every TOleControl wrapper has }
  ControlPublished: array[0..15] of string = ('Anchors', 'TabStop', 'Align', 'DragCursor',
    'DragMode', 'ParentShowHint', 'PopupMenu', 'ShowHint', 'TabOrder', 'Visible', 'OnDragDrop',
    'OnDragOver', 'OnEndDrag', 'OnEnter', 'OnExit', 'OnStartDrag');
  IDispatchMembers: array[0..6] of string = ('QueryInterface', 'AddRef', 'Release',
    'GetTypeInfoCount', 'GetTypeInfo', 'GetIDsOfNames', 'Invoke');

  { a parameter's kind (TTLParam.Mode) }
  pmValue = 0;
  pmConst = 1;
  pmVar = 2;
  pmOut = 3;

function InList(const S: string; const L: array of string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := Low(L) to High(L) do
    if SameText(S, L[I]) then Exit;
  Result := False;
end;

function GuidText(const G: TGUID): string;
begin
  Result := GUIDToString(G);
end;


{ ---------------------------------------------------------------- the registry }

procedure FreeTypeLibRefs(List: TStrings);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do List.Objects[I].Free;
  List.Clear;
end;

function HexWord(const S: string; out W: Word): Boolean;
var
  V, Code: Integer;
begin
  Val('$' + S, V, Code);
  Result := (Code = 0) and (V >= 0) and (V <= $FFFF);
  if Result then W := V;
end;

{ the version keys "1.0", "2.a" (hexadecimal) of a library, the first language under one that has
  a win32 file }
procedure ListTypeLibraries(List: TStrings);
var
  R: TRegistry;
  Guids, Vers, Langs: TStringList;
  G, V, L, P: Integer;
  Ref: TTypeLibRef;
  Path, Name, Key: string;
  Major, Minor, Lang: Word;
begin
  FreeTypeLibRefs(List);
  R := TRegistry.Create(KEY_READ);
  Guids := TStringList.Create;
  Vers := TStringList.Create;
  Langs := TStringList.Create;
  try
    R.RootKey := HKEY_CLASSES_ROOT;
    if not R.OpenKeyReadOnly('TypeLib') then Exit;
    R.GetKeyNames(Guids);
    R.CloseKey;
    for G := 0 to Guids.Count - 1 do
    begin
      if not R.OpenKeyReadOnly('TypeLib\' + Guids[G]) then Continue;
      R.GetKeyNames(Vers);
      R.CloseKey;
      for V := 0 to Vers.Count - 1 do
      begin
        P := Pos('.', Vers[V]);
        if (P = 0) or not HexWord(Copy(Vers[V], 1, P - 1), Major) or
          not HexWord(Copy(Vers[V], P + 1, MaxInt), Minor) then Continue;
        Key := 'TypeLib\' + Guids[G] + '\' + Vers[V];
        if not R.OpenKeyReadOnly(Key) then Continue;
        Name := R.ReadString('');
        R.GetKeyNames(Langs);
        R.CloseKey;
        for L := 0 to Langs.Count - 1 do
        begin
          { a locale's key is hexadecimal ("409"); FLAGS and HELPDIR are none }
          if not HexWord(Langs[L], Lang) then Continue;
          if not R.OpenKeyReadOnly(Key + '\' + Langs[L] + '\win32') then Continue;
          Path := R.ReadString('');
          R.CloseKey;
          if Path = '' then Continue;
          Ref := TTypeLibRef.Create;
          try
            Ref.Guid := StringToGUID(Guids[G]);
          except
            Ref.Free;
            Continue;
          end;
          if Name = '' then Name := ExtractFileName(Path);
          Ref.Name := Name;
          Ref.Major := Major;
          Ref.Minor := Minor;
          Ref.Lcid := Lang;
          Ref.FileName := Path;
          List.AddObject(Format('%s (Version %d.%d)', [Name, Major, Minor]), Ref);
          Break;
        end;
      end;
    end;
  finally
    Langs.Free;
    Vers.Free;
    Guids.Free;
    R.Free;
  end;
  if List is TStringList then TStringList(List).Sort;
end;

{ the CoClasses registered with a Control key: their library (of their version, else the highest) }
procedure ListActiveXControls(List: TStrings);
var
  R: TRegistry;
  Keys, Libs, ByGuid: TStringList;
  I, K, P, J, Best: Integer;
  Lib, Ver, Name: string;
  Ref, LibRef, Cand: TTypeLibRef;
  Major, Minor: Word;
  HasVer: Boolean;
begin
  FreeTypeLibRefs(List);
  Libs := TStringList.Create;
  R := TRegistry.Create(KEY_READ);
  Keys := TStringList.Create;
  { the libraries by their GUID (a library has an entry per version), each with its place in
    Libs: one lookup per control instead of a pass over every library }
  ByGuid := TStringList.Create;
  try
    ListTypeLibraries(Libs);
    for K := 0 to Libs.Count - 1 do
      ByGuid.AddObject(GUIDToString(TTypeLibRef(Libs.Objects[K]).Guid), TObject(K));
    ByGuid.Duplicates := dupAccept;
    ByGuid.Sorted := True;
    R.RootKey := HKEY_CLASSES_ROOT;
    if not R.OpenKeyReadOnly('CLSID') then Exit;
    R.GetKeyNames(Keys);
    R.CloseKey;
    for I := 0 to Keys.Count - 1 do
    begin
      if not R.KeyExists('CLSID\' + Keys[I] + '\Control') then Continue;
      if not R.OpenKeyReadOnly('CLSID\' + Keys[I]) then Continue;
      Name := R.ReadString('');
      R.CloseKey;
      Lib := '';
      Ver := '';
      if R.OpenKeyReadOnly('CLSID\' + Keys[I] + '\TypeLib') then
      begin
        Lib := R.ReadString('');
        R.CloseKey;
      end;
      if R.OpenKeyReadOnly('CLSID\' + Keys[I] + '\Version') then
      begin
        Ver := R.ReadString('');
        R.CloseKey;
      end;
      if Lib = '' then Continue;
      P := Pos('.', Ver);
      HasVer := (P > 0) and HexWord(Copy(Ver, 1, P - 1), Major) and HexWord(Copy(Ver, P + 1, MaxInt), Minor);
      { its version, else the highest (the first of that major version in the list's order) }
      Best := -1;
      ByGuid.Find(Lib, K);                // the first entry of the GUID (dupAccept)
      while (K < ByGuid.Count) and SameText(ByGuid[K], Lib) do
      begin
        J := Integer(ByGuid.Objects[K]);
        Cand := TTypeLibRef(Libs.Objects[J]);
        if HasVer and (Cand.Major = Major) and (Cand.Minor = Minor) then
        begin
          Best := J;
          Break;
        end;
        if (Best < 0) or (Cand.Major > TTypeLibRef(Libs.Objects[Best]).Major) or
          ((Cand.Major = TTypeLibRef(Libs.Objects[Best]).Major) and (J < Best)) then Best := J;
        Inc(K);
      end;
      if Best < 0 then Continue;
      LibRef := TTypeLibRef(Libs.Objects[Best]);
      if Name = '' then Name := Keys[I];
      Ref := TTypeLibRef.Create;
      Ref.Name := LibRef.Name;
      Ref.Guid := LibRef.Guid;
      Ref.Major := LibRef.Major;
      Ref.Minor := LibRef.Minor;
      Ref.Lcid := LibRef.Lcid;
      Ref.FileName := LibRef.FileName;
      Ref.ControlName := Name;
      List.AddObject(Format('%s (Version %d.%d)', [Name, LibRef.Major, LibRef.Minor]), Ref);
    end;
  finally
    ByGuid.Free;
    Keys.Free;
    R.Free;
    FreeTypeLibRefs(Libs);
    Libs.Free;
  end;
  if List is TStringList then TStringList(List).Sort;
end;

function IsTypeLibFile(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.tlb') or SameText(ExtractFileExt(FileName), '.olb');
end;

function LoadTypeLibrary(const FileName: string): ITypeLib;
var
  W: WideString;
begin
  W := WidePath(FileName);           // a usable name, a marked one too (SdFileNames)
  OleCheck(LoadTypeLib(PWideChar(W), Result));
end;

function LoadTypeLibraryRef(Ref: TTypeLibRef): ITypeLib;
begin
  if Failed(LoadRegTypeLib(Ref.Guid, Ref.Major, Ref.Minor, Ref.Lcid, Result)) then
    Result := LoadTypeLibrary(Ref.FileName);
end;

function TypeLibName(TL: ITypeLib): string;
var
  N: WideString;
begin
  N := '';
  TL.GetDocumentation(-1, @N, nil, nil, nil);
  Result := WideToIde(N);
end;

function TypeLibHelp(TL: ITypeLib): string;
var
  N: WideString;
begin
  N := '';
  TL.GetDocumentation(-1, nil, @N, nil, nil);
  Result := WideToIde(N);
end;

function TypeLibUnitName(TL: ITypeLib): string;
begin
  Result := TypeLibName(TL) + '_TLB';
end;

{ ---------------------------------------------------------------- types of a library }

type
  { a type as the unit writes it }
  TTLType = record
    Name: string;             // the type (pointers to it: Level)
    Level: Integer;           // pointers to it (an interface pointer: 0)
    Intf: Boolean;            // an interface or dispinterface
    Disp: Boolean;            // a dispinterface (not dual): no "as", a cast of an IDispatch
    Enum: Boolean;            // an enumeration of a library
    Managed: Boolean;         // WideString, OleVariant, an interface (not in a union)
    Base: Integer;            // the VT of what it is in the end (an alias resolved)
    Std: string;              // a type of stdole: its name (OLE_COLOR, Font ...)
  end;

  TTLParam = record
    Name: string;
    Mode: Integer;            // pmValue, pmConst, pmVar, pmOut
    T: TTLType;
  end;
  TTLParams = array of TTLParam;

  { a member of a dispatch view: a method, or a property from its get / put functions }
  TTLMember = class
  public
    Name: string;             // its Pascal name
    Raw: string;              // its name in the library
    DispID: Integer;
    IsProp: Boolean;
    CanRead, CanWrite: Boolean;
    PutRef: Boolean;          // a property set by reference only (_Set_ in the v-table)
    PutType, RefType: string; // the value types of its put and putref
    Params: TTLParams;        // a property: its index
    Result: TTLType;          // a function's result, a property's type
    HasResult: Boolean;
    Hidden: Boolean;
    EventType: string;        // an event: the type of its handler
  end;

function NoType: TTLType;
begin
  Result.Name := '';
  Result.Level := 0;
  Result.Intf := False;
  Result.Disp := False;
  Result.Enum := False;
  Result.Managed := False;
  Result.Base := VT_EMPTY;
  Result.Std := '';
end;

{ a type where a type name stands (a field, a result, an alias): a pointer is a Pointer }
function ValueText(const T: TTLType): string;
begin
  if T.Level <= 0 then Result := T.Name else Result := 'Pointer';
end;

{ a type a dispinterface can hold (an automation type; Delphi 7 refuses Shortint and Word there,
  measured) }
function AutoType(const T: TTLType): Boolean;
begin
  Result := (T.Level <= 1) and not (T.Base in [VT_RECORD, VT_CARRAY, VT_I1, VT_UI2]) and
    not InList(T.Name, ['Pointer', 'PChar', 'PWideChar', 'TDecimal', 'TGUID', 'PSafeArray']);
end;

{ a member's name in an interface: a reserved word gets an underscore }
function IntfName(const Raw: string): string;
begin
  Result := Raw;
  if InList(Result, ReservedWords) then Result := Result + '_';
end;

{ the type of a property's value from a setter's last parameter (a VARIANT* is an OleVariant) }
function ValueOf(T: TTLType): TTLType;
begin
  if T.Level = 1 then T.Level := 0;
  Result := T;
end;

function ParamDecl(const P: TTLParams; First, Last: Integer): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := First to Last do
  begin
    case P[I].Mode of
      pmConst: S := 'const ';
      pmVar: S := 'var ';
      pmOut: S := 'out ';
    else
      S := '';
    end;
    if P[I].T.Level > 1 then S := S + P[I].Name + ': Pointer'
    else S := S + P[I].Name + ': ' + P[I].T.Name;
    if Result <> '' then Result := Result + '; ';
    Result := Result + S;
  end;
end;

function ParamArgs(const P: TTLParams; First, Last: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := First to Last do
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + P[I].Name;
  end;
end;

function TypeKindOf(TI: ITypeInfo; out Flags: Word): TTypeKind;
var
  A: PTypeAttr;
begin
  Result := TKIND_MAX;
  Flags := 0;
  if Failed(TI.GetTypeAttr(A)) then Exit;
  Result := A.typekind;
  Flags := A.wTypeFlags;
  TI.ReleaseTypeAttr(A);
end;

function GuidOf(TI: ITypeInfo): TGUID;
var
  A: PTypeAttr;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  Result := A.guid;
  TI.ReleaseTypeAttr(A);
end;

{ a CoClass whose default interface is a dispinterface (not a dual one) }
function PureDispOf(CoTI: ITypeInfo): Boolean;
var
  A: PTypeAttr;
  I, F: Integer;
  R: HRefType;
  D: ITypeInfo;
  DF: Word;
begin
  Result := False;
  if Failed(CoTI.GetTypeAttr(A)) then Exit;
  try
    for I := 0 to A.cImplTypes - 1 do
      if Succeeded(CoTI.GetImplTypeFlags(I, F)) and (F and IMPLTYPEFLAG_FSOURCE = 0) and
        (F and IMPLTYPEFLAG_FDEFAULT <> 0) and Succeeded(CoTI.GetRefTypeOfImplType(I, R)) and
        Succeeded(CoTI.GetRefTypeInfo(R, D)) then
      begin
        Result := (TypeKindOf(D, DF) = TKIND_DISPATCH) and (DF and TYPEFLAG_FDUAL = 0);
        Exit;
      end;
  finally
    CoTI.ReleaseTypeAttr(A);
  end;
end;

{ an interface reference as type T: "as" for an interface, a cast of the IDispatch for a
  dispinterface (Delphi 7 has no "as" for those) }
function AsIntf(const Expr: string; const T: TTLType; const Name: string): string;
begin
  if T.Disp then Result := Format('%s(IDispatch(%s))', [Name, Expr])
  else Result := Format('%s as %s', [Expr, Name]);
end;

{ the names of a member: its own first, then its parameters' }
function MemberNames(TI: ITypeInfo; MemID: Integer): TStringList;
var
  B: array[0..63] of TBStr;
  N, I: Integer;
begin
  Result := TStringList.Create;
  N := 0;
  if Succeeded(TI.GetNames(MemID, @B, 64, N)) then
    for I := 0 to N - 1 do
    begin
      Result.Add(WideToIde(WideString(B[I])));
      SysFreeString(B[I]);
    end;
end;

function MemberName(TI: ITypeInfo; MemID: Integer): string;
var
  Doc: WideString;
begin
  Doc := '';
  TI.GetDocumentation(MemID, @Doc, nil, nil, nil);
  Result := WideToIde(Doc);
end;

{ a value of a module's constant: a number, a string (#n for what is not printable ASCII) }
function ConstText(const V: OleVariant): string;
var
  S: string;
  I: Integer;
  InQ: Boolean;
begin
  case VarType(V) and varTypeMask of
    varSmallint, varInteger, varByte, varShortInt, varWord, varLongWord, varInt64:
      begin
        Result := VarToStr(V);
        if Result = '-2147483648' then Result := '-2147483647 - 1';   // the literal overflows
      end;
    varSingle, varDouble, varCurrency:
      Result := StringReplace(FloatToStr(V), DecimalSeparator, '.', []);
    varBoolean:
      if V then Result := 'True' else Result := 'False';
    varOleStr, varString:
      begin
        if VarType(V) and varTypeMask = varOleStr then S := WideToIde(VarToWideStr(V)) else S := VarToStr(V);
        Result := '';
        InQ := False;
        for I := 1 to Length(S) do
          if (S[I] >= ' ') and (S[I] <= '~') then
          begin
            if not InQ then Result := Result + '''';
            InQ := True;
            if S[I] = '''' then Result := Result + '''''' else Result := Result + S[I];
          end
          else
          begin
            if InQ then Result := Result + '''';
            InQ := False;
            Result := Result + '#' + IntToStr(Ord(S[I]));
          end;
        if InQ then Result := Result + '''';
        if Result = '' then Result := '''''';
      end;
  else
    Result := '0';
  end;
end;

{ lines dcc32 can read (it stops at 1023 characters): a long line is broken after a comma or a
  semicolon outside a string, near 200 characters; a comment is cut short }
procedure WrapLong(L: TStrings);
const
  Max = 200;
var
  I, K, Cut, Indent: Integer;
  S: string;
  InQ: Boolean;
begin
  I := 0;
  while I < L.Count do
  begin
    S := L[I];
    if Length(S) > Max then
      if Copy(TrimLeft(S), 1, 2) = '//' then
        L[I] := Copy(S, 1, 1000)
      else
      begin
        { the last separator before Max, else the first after it }
        Cut := 0;
        InQ := False;
        for K := 1 to Length(S) - 1 do
          if S[K] = '''' then InQ := not InQ
          else if not InQ and (S[K] in [',', ';']) and (S[K + 1] = ' ') and (K > 40) then
          begin
            if (K <= Max) or (Cut = 0) then Cut := K;
            if K > Max then Break;
          end;
        if (Cut > 0) and (Cut < Length(S) - 1) then
        begin
          Indent := 1;
          while (Indent <= Length(S)) and (S[Indent] = ' ') do Inc(Indent);
          L[I] := Copy(S, 1, Cut);
          L.Insert(I + 1, StringOfChar(' ', Indent - 1) + '    ' + TrimLeft(Copy(S, Cut + 1, MaxInt)));
        end;
      end;
    Inc(I);
  end;
end;

{ ---------------------------------------------------------------- the writer of a unit }

type
  TTLBWriter = class
  private
    FImp: TTLBImport;
    FTL: ITypeLib;
    FLibName, FUnit, FFile, FHelp: string;
    FGuid: TGUID;
    FMajor, FMinor: Word;
    FNames: TStringList;      // per type index: its Pascal name
    FDispNames: TStringList;  // per type index: a dual interface's dispinterface (Name + Disp)
    FTypeNames: TStringList;  // FNames and FDispNames sorted (any case): an FNames one's object is its index, a dispinterface's -1
    FUsed: TStringList;       // the unit's identifiers (sorted, any case)
    FAdded: TStringList;      // nil, or what Unique adds to FUsed meanwhile (TTLBImport.TypeText)
    FDeps: TStringList;       // the units of other libraries this one uses
    FSource: string;
    FWritten: Boolean;
    function Unique(const S: string): string;
    function TypeInfoAt(I: Integer): ITypeInfo;
    function KindAt(I: Integer): TTypeKind;
    function FlagsAt(I: Integer): Word;
    function RefType(TI: ITypeInfo; Ref: HRefType; out T: TTLType): Boolean;
    function Resolve(TI: ITypeInfo; const TD: TTypeDesc): TTLType;
    function FieldText(TI: ITypeInfo; const TD: TTypeDesc; InUnion: Boolean): string;
    function FuncParams(TI: ITypeInfo; FD: PFuncDesc; Safecall, Disp: Boolean; out Res: TTLType;
      out HasResult: Boolean): TTLParams;
    function DualParts(TI: ITypeInfo; out VTI, DTI: ITypeInfo): Boolean;
    function DefaultIntf(CoTI: ITypeInfo; Source: Boolean; out Name: string): ITypeInfo;
    procedure DispMembers(DTI: ITypeInfo; L: TList; ForWrapper: Boolean);
    procedure AddEnum(I: Integer; Dst: TStrings);
    procedure AddModule(I: Integer; Dst: TStrings);
    procedure AddRecord(I: Integer; Dst: TStrings);
    procedure AddAlias(I: Integer; Dst: TStrings);
    procedure AddInterface(VTI: ITypeInfo; const Name: string; Dst: TStrings);
    procedure AddDispinterface(DTI: ITypeInfo; const Name: string; Dst: TStrings);
    procedure AddIntfOf(I: Integer; Dst: TStrings);
    procedure AddForwarders(const Cls: string; Members: TList; Decl, Impl, Pubs: TStrings; Control, Dual: Boolean);
    procedure AddWrapper(I: Integer; Decl, Impl, Reg: TStrings; Control: Boolean);
    function WantsWrapper(I: Integer; out Control: Boolean): Boolean;
    function EventArg(const P: TTLParam; Index: Integer): string;
    function Q(const Name: string): string;
    function IsOwn(TL: ITypeLib): Boolean;
  public
    constructor Create(AImp: TTLBImport; ATL: ITypeLib);
    destructor Destroy; override;
    procedure Write;
    function TypeText(Index: Integer): string;
    function WrapperNames: string;
  end;

constructor TTLBWriter.Create(AImp: TTLBImport; ATL: ITypeLib);
var
  A: PTLibAttr;
  I, N: Integer;
  Doc: WideString;
begin
  inherited Create;
  FImp := AImp;
  FTL := ATL;
  FLibName := TypeLibName(ATL);
  FHelp := TypeLibHelp(ATL);
  FUnit := FLibName + '_TLB';
  if Succeeded(ATL.GetLibAttr(A)) then
  begin
    FGuid := A.guid;
    FMajor := A.wMajorVerNum;
    FMinor := A.wMinorVerNum;
    ATL.ReleaseTLibAttr(A);
  end;
  Doc := '';
  if Succeeded(QueryPathOfRegTypeLib(FGuid, FMajor, FMinor, 0, Doc)) then FFile := WideToIde(Doc);
  FNames := TStringList.Create;
  FUsed := TStringList.Create;
  FUsed.Sorted := True;
  FUsed.Duplicates := dupIgnore;
  FDeps := TStringList.Create;
  for I := Low(ReservedWords) to High(ReservedWords) do FUsed.Add(ReservedWords[I]);
  for I := Low(UnitNames) to High(UnitNames) do FUsed.Add(UnitNames[I]);
  FUsed.Add(FUnit);
  { the types keep their names (one that is taken gets an underscore); a dual interface's
    dispinterface is its name + Disp }
  N := ATL.GetTypeInfoCount;
  for I := 0 to N - 1 do
  begin
    Doc := '';
    ATL.GetDocumentation(I, @Doc, nil, nil, nil);
    FNames.Add(Unique(WideToIde(Doc)));
  end;
  FDispNames := TStringList.Create;
  for I := 0 to N - 1 do
    if (KindAt(I) in [TKIND_DISPATCH, TKIND_INTERFACE]) and (FlagsAt(I) and TYPEFLAG_FDUAL <> 0) then
      FDispNames.Add(Unique(FNames[I] + 'Disp'))
    else
      FDispNames.Add('');
  { (the names are unique: Unique) }
  FTypeNames := TStringList.Create;
  for I := 0 to N - 1 do
  begin
    FTypeNames.AddObject(FNames[I], TObject(I));
    if FDispNames[I] <> '' then FTypeNames.AddObject(FDispNames[I], TObject(-1));
  end;
  FTypeNames.Sorted := True;
end;

destructor TTLBWriter.Destroy;
begin
  FNames.Free;
  FDispNames.Free;
  FTypeNames.Free;
  FUsed.Free;
  FDeps.Free;
  inherited Destroy;
end;

{ S, or S with underscores until no identifier of the unit has that name }
function TTLBWriter.Unique(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  if Result = '' then Result := 'Unnamed';
  while FUsed.Find(Result, I) do Result := Result + '_';
  FUsed.Add(Result);
  if FAdded <> nil then FAdded.Add(Result);
end;

function TTLBWriter.TypeInfoAt(I: Integer): ITypeInfo;
begin
  OleCheck(FTL.GetTypeInfo(I, Result));
end;

function TTLBWriter.KindAt(I: Integer): TTypeKind;
begin
  if Failed(FTL.GetTypeInfoType(I, Result)) then Result := TKIND_MAX;
end;

function TTLBWriter.FlagsAt(I: Integer): Word;
begin
  TypeKindOf(TypeInfoAt(I), Result);
end;

{ a type of a library: its name (another library's with its unit), whether it is an interface,
  an enumeration, what an alias stands for }
function TTLBWriter.RefType(TI: ITypeInfo; Ref: HRefType; out T: TTLType): Boolean;
var
  R: ITypeInfo;
  RTL: ITypeLib;
  A: PTypeAttr;
  LA: PTLibAttr;
  Idx: Integer;
  W: TTLBWriter;
  Doc: string;
  Inner: TTLType;
  IsStd: Boolean;
begin
  Result := False;
  T := NoType;
  if Failed(TI.GetRefTypeInfo(Ref, R)) or Failed(R.GetTypeAttr(A)) then Exit;
  try
    Doc := MemberName(R, -1);
    T.Name := Doc;
    if Succeeded(R.GetContainingTypeLib(RTL, Idx)) and (RTL <> nil) then
    begin
      IsStd := False;
      if Succeeded(RTL.GetLibAttr(LA)) then
      begin
        IsStd := IsEqualGUID(LA.guid, StdOleLib);
        RTL.ReleaseTLibAttr(LA);
      end;
      if IsStd then
      begin
        { stdole: the unit ActiveX has its types }
        T.Std := Doc;
        if SameText(Doc, 'GUID') then T.Name := 'TGUID'
        else if SameText(Doc, 'StdFont') then T.Name := 'Font'
        else if SameText(Doc, 'StdPicture') then T.Name := 'Picture';
      end
      else
      begin
        W := TTLBWriter(FImp.WriterOf(RTL));
        if W = Self then T.Name := FNames[Idx]
        else
        begin
          T.Name := W.FUnit + '.' + W.FNames[Idx];
          if FDeps.IndexOf(W.FUnit) < 0 then FDeps.Add(W.FUnit);
        end;
      end;
    end;
    case A.typekind of
      TKIND_INTERFACE, TKIND_DISPATCH, TKIND_COCLASS:
        begin
          T.Intf := True;
          T.Managed := True;
          T.Level := -1;                { the interface itself: a pointer to it is its value }
          T.Base := VT_UNKNOWN;
          T.Disp := (A.typekind = TKIND_DISPATCH) and (A.wTypeFlags and TYPEFLAG_FDUAL = 0);
          if A.typekind = TKIND_COCLASS then T.Disp := PureDispOf(R);
        end;
      TKIND_ENUM:
        begin
          T.Enum := True;
          T.Base := VT_I4;
        end;
      TKIND_ALIAS:
        begin
          Inner := Resolve(R, A.tdescAlias);
          T.Intf := Inner.Intf;
          T.Disp := Inner.Disp;
          T.Enum := Inner.Enum;
          T.Managed := Inner.Managed;
          T.Base := Inner.Base;
          if Inner.Intf then T.Level := Inner.Level;
        end;
      TKIND_RECORD, TKIND_UNION:
        T.Base := VT_RECORD;
    else
      T.Base := VT_USERDEFINED;
    end;
    Result := True;
  finally
    R.ReleaseTypeAttr(A);
  end;
end;

function TTLBWriter.Resolve(TI: ITypeInfo; const TD: TTypeDesc): TTLType;

  procedure Simple(const N: string; VT: Integer; Managed: Boolean);
  begin
    Result.Name := N;
    Result.Base := VT;
    Result.Managed := Managed;
  end;

begin
  Result := NoType;
  case TD.vt of
    VT_PTR:
      begin
        Result := Resolve(TI, TD.ptdesc^);
        Inc(Result.Level);
      end;
    VT_SAFEARRAY: Simple('PSafeArray', VT_SAFEARRAY, False);
    VT_CARRAY: Simple('Pointer', VT_CARRAY, False);
    VT_USERDEFINED:
      if not RefType(TI, TD.hreftype, Result) then Simple('Pointer', VT_PTR, False);
    VT_DISPATCH:
      begin
        Simple('IDispatch', VT_DISPATCH, True);
        Result.Intf := True;
      end;
    VT_UNKNOWN:
      begin
        Simple('IUnknown', VT_UNKNOWN, True);
        Result.Intf := True;
      end;
    VT_VOID:
      begin
        Simple('Pointer', VT_VOID, False);
        Result.Level := -1;           { void*: a Pointer }
      end;
    VT_I2: Simple('Smallint', VT_I2, False);
    VT_I4: Simple('Integer', VT_I4, False);
    VT_R4: Simple('Single', VT_R4, False);
    VT_R8: Simple('Double', VT_R8, False);
    VT_CY: Simple('Currency', VT_CY, False);
    VT_DATE: Simple('TDateTime', VT_DATE, False);
    VT_BSTR: Simple('WideString', VT_BSTR, True);
    VT_ERROR: Simple('SCODE', VT_ERROR, False);
    VT_BOOL: Simple('WordBool', VT_BOOL, False);
    VT_VARIANT: Simple('OleVariant', VT_VARIANT, True);
    VT_DECIMAL: Simple('TDecimal', VT_DECIMAL, False);
    VT_I1: Simple('Shortint', VT_I1, False);
    VT_UI1: Simple('Byte', VT_UI1, False);
    VT_UI2: Simple('Word', VT_UI2, False);
    VT_UI4: Simple('LongWord', VT_UI4, False);
    VT_I8: Simple('Int64', VT_I8, False);
    VT_UI8: Simple('Largeuint', VT_UI8, False);
    VT_INT: Simple('SYSINT', VT_I4, False);
    VT_UINT: Simple('SYSUINT', VT_UI4, False);
    VT_HRESULT: Simple('HResult', VT_HRESULT, False);
    VT_LPSTR: Simple('PChar', VT_LPSTR, False);
    VT_LPWSTR: Simple('PWideChar', VT_LPWSTR, False);
    VT_CLSID: Simple('TGUID', VT_CLSID, False);
  else
    Simple('Pointer', VT_PTR, False);
  end;
end;

{ a field: a pointer is a Pointer, an array its bounds; in a union what the compiler cannot keep
  there (strings, variants, interfaces, records) is a Pointer }
function TTLBWriter.FieldText(TI: ITypeInfo; const TD: TTypeDesc; InUnion: Boolean): string;
var
  T: TTLType;
  I: Integer;
  AD: PArrayDesc;
begin
  if TD.vt = VT_CARRAY then
  begin
    AD := TD.padesc;
    Result := 'array[';
    for I := 0 to AD.cDims - 1 do
    begin
      if I > 0 then Result := Result + ', ';
      Result := Result + Format('%d..%d', [AD.rgbounds[I].lLbound,
        AD.rgbounds[I].lLbound + Integer(AD.rgbounds[I].cElements) - 1]);
    end;
    Result := Result + '] of ' + FieldText(TI, AD.tdescElem, InUnion);
    Exit;
  end;
  T := Resolve(TI, TD);
  if InUnion and (T.Level <= 0) and (T.Managed or (T.Base = VT_RECORD)) then Result := 'Pointer'
  else Result := ValueText(T);
end;

{ the parameters of a function: a value (an interface or a WideString const), a pointer var (out
  when it only goes out), deeper pointers a var Pointer. Safecall: the HRESULT goes, the retval
  parameter is the result; Disp: a dispatch view's member (its result as declared, no out). }
function TTLBWriter.FuncParams(TI: ITypeInfo; FD: PFuncDesc; Safecall, Disp: Boolean; out Res: TTLType;
  out HasResult: Boolean): TTLParams;
var
  N: TStringList;
  I, Last, J: Integer;
  E: PElemDesc;
  PN, Own: string;
  Flags: Word;
begin
  N := MemberNames(TI, FD.memid);
  try
    if N.Count > 0 then Own := N[0] else Own := '';
    Res := NoType;
    HasResult := False;
    Last := FD.cParams - 1;
    if (Safecall or Disp) and (Last >= 0) and
      (FD.lprgelemdescParam^[Last].paramdesc.wParamFlags and PARAMFLAG_FRETVAL <> 0) then
    begin
      Res := Resolve(TI, FD.lprgelemdescParam^[Last].tdesc);
      Dec(Res.Level);
      HasResult := True;
      Dec(Last);
    end
    else if not Safecall and (FD.elemdescFunc.tdesc.vt <> VT_VOID) and
      not (Disp and (FD.elemdescFunc.tdesc.vt = VT_HRESULT)) then
    begin
      Res := Resolve(TI, FD.elemdescFunc.tdesc);
      HasResult := True;
    end;
    SetLength(Result, Last + 1);
    for I := 0 to Last do
    begin
      E := @FD.lprgelemdescParam^[I];
      if I + 1 < N.Count then PN := N[I + 1]
      else if (I = Last) and (FD.invkind and (INVOKE_PROPERTYPUT or INVOKE_PROPERTYPUTREF) <> 0) then PN := 'Value'
      else PN := 'Param' + IntToStr(I + 1);
      if InList(PN, ReservedWords) then PN := PN + '_';
      Result[I].T := Resolve(TI, E.tdesc);
      { a name taken in the heading, or the name of a type of it, gets an underscore }
      J := 0;
      while J < I do
        if SameText(Result[J].Name, PN) or SameText(Result[J].T.Name, PN) or SameText(Result[I].T.Name, PN) or
          SameText(Res.Name, PN) or SameText(Own, PN) then
        begin
          PN := PN + '_';
          J := 0;
        end
        else
          Inc(J);
      if SameText(Result[I].T.Name, PN) or SameText(Res.Name, PN) or SameText(Own, PN) then PN := PN + '_';
      Result[I].Name := PN;
      Flags := E.paramdesc.wParamFlags;
      if Result[I].T.Level <= 0 then
      begin
        if Result[I].T.Intf or (Result[I].T.Name = 'WideString') then Result[I].Mode := pmConst
        else Result[I].Mode := pmValue;
      end
      else if not Disp and (Flags and PARAMFLAG_FOUT <> 0) and (Flags and PARAMFLAG_FIN = 0) then
        Result[I].Mode := pmOut
      else
        Result[I].Mode := pmVar;
    end;
  finally
    N.Free;
  end;
end;

{ an interface: its v-table part and its dispatch part (a dual one has both) }
function TTLBWriter.DualParts(TI: ITypeInfo; out VTI, DTI: ITypeInfo): Boolean;
var
  R: HRefType;
  Other: ITypeInfo;
  K: TTypeKind;
  F: Word;
begin
  VTI := nil;
  DTI := nil;
  K := TypeKindOf(TI, F);
  Result := F and TYPEFLAG_FDUAL <> 0;
  if K = TKIND_DISPATCH then DTI := TI else VTI := TI;
  if Result and Succeeded(TI.GetRefTypeOfImplType(-1, R)) and Succeeded(TI.GetRefTypeInfo(R, Other)) then
    if K = TKIND_DISPATCH then VTI := Other else DTI := Other;
end;

{ a CoClass's default interface (or default source interface) and its name in the unit }
function TTLBWriter.DefaultIntf(CoTI: ITypeInfo; Source: Boolean; out Name: string): ITypeInfo;
var
  A: PTypeAttr;
  I, F, Pick: Integer;
  R, PickRef: HRefType;
  T: TTLType;
begin
  Result := nil;
  Name := '';
  Pick := -1;
  PickRef := 0;
  if Failed(CoTI.GetTypeAttr(A)) then Exit;
  try
    for I := 0 to A.cImplTypes - 1 do
    begin
      if Failed(CoTI.GetImplTypeFlags(I, F)) then Continue;
      if (F and IMPLTYPEFLAG_FSOURCE <> 0) <> Source then Continue;
      if Failed(CoTI.GetRefTypeOfImplType(I, R)) then Continue;
      if (F and IMPLTYPEFLAG_FDEFAULT <> 0) or (Pick < 0) then
      begin
        Pick := I;
        PickRef := R;
        if F and IMPLTYPEFLAG_FDEFAULT <> 0 then Break;
      end;
    end;
  finally
    CoTI.ReleaseTypeAttr(A);
  end;
  if Pick < 0 then Exit;
  if Failed(CoTI.GetRefTypeInfo(PickRef, Result)) then
  begin
    Result := nil;
    Exit;
  end;
  if RefType(CoTI, PickRef, T) then Name := T.Name else Result := nil;
end;

{ the members of a dispatch view, without IUnknown's and IDispatch's: methods, and properties
  from their get / put functions and from variables }
procedure TTLBWriter.DispMembers(DTI: ITypeInfo; L: TList; ForWrapper: Boolean);
var
  A: PTypeAttr;
  I, K: Integer;
  FD: PFuncDesc;
  VD: PVarDesc;
  M: TTLMember;
  Name: string;
  P: TTLParams;
  Res: TTLType;
  HasRes: Boolean;

  function FindProp(const N: string): TTLMember;
  var
    J: Integer;
  begin
    for J := 0 to L.Count - 1 do
    begin
      Result := TTLMember(L[J]);
      if Result.IsProp and SameText(Result.Raw, N) then Exit;
    end;
    Result := nil;
  end;

begin
  if Failed(DTI.GetTypeAttr(A)) then Exit;
  try
    for I := 0 to A.cFuncs - 1 do
    begin
      if Failed(DTI.GetFuncDesc(I, FD)) then Continue;
      try
        Name := MemberName(DTI, FD.memid);
        if InList(Name, IDispatchMembers) then Continue;
        P := FuncParams(DTI, FD, False, True, Res, HasRes);
        if FD.invkind = INVOKE_FUNC then
        begin
          M := TTLMember.Create;
          M.Raw := Name;
          M.DispID := FD.memid;
          M.Params := P;
          M.Result := Res;
          M.HasResult := HasRes;
          M.Hidden := FD.wFuncFlags and (FUNCFLAG_FHIDDEN or FUNCFLAG_FRESTRICTED) <> 0;
          L.Add(M);
          Continue;
        end;
        M := FindProp(Name);
        if M = nil then
        begin
          M := TTLMember.Create;
          M.Raw := Name;
          M.IsProp := True;
          M.DispID := FD.memid;
          M.Hidden := FD.wFuncFlags and (FUNCFLAG_FHIDDEN or FUNCFLAG_FRESTRICTED) <> 0;
          L.Add(M);
        end;
        if FD.invkind = INVOKE_PROPERTYGET then
        begin
          M.CanRead := True;
          M.Params := P;
          M.Result := Res;
          M.HasResult := HasRes;
        end
        else
        begin
          M.CanWrite := True;
          if Length(P) > 0 then
            if FD.invkind = INVOKE_PROPERTYPUTREF then M.RefType := ValueText(ValueOf(P[High(P)].T))
            else M.PutType := ValueText(ValueOf(P[High(P)].T));
          M.PutRef := (M.PutType = '') and (M.RefType <> '');
          if not M.CanRead and (Length(P) > 0) then
          begin
            { the type: the value; the index: the parameters before it }
            M.Result := ValueOf(P[High(P)].T);
            M.HasResult := True;
            SetLength(P, Length(P) - 1);
            M.Params := P;
          end;
        end;
      finally
        DTI.ReleaseFuncDesc(FD);
      end;
    end;
    for I := 0 to A.cVars - 1 do
    begin
      if Failed(DTI.GetVarDesc(I, VD)) then Continue;
      try
        M := TTLMember.Create;
        M.Raw := MemberName(DTI, VD.memid);
        M.IsProp := True;
        M.DispID := VD.memid;
        M.CanRead := True;
        M.CanWrite := VD.wVarFlags and VARFLAG_FREADONLY = 0;
        M.Result := Resolve(DTI, VD.elemdescVar.tdesc);
        M.HasResult := True;
        M.Hidden := VD.wVarFlags and (VARFLAG_FHIDDEN or VARFLAG_FRESTRICTED) <> 0;
        L.Add(M);
      finally
        DTI.ReleaseVarDesc(VD);
      end;
    end;
  finally
    DTI.ReleaseTypeAttr(A);
  end;
  { a name the view repeats (a derived interface's member of an ancestor's name): the first stays }
  for I := L.Count - 1 downto 1 do
    for K := 0 to I - 1 do
      if SameText(TTLMember(L[K]).Raw, TTLMember(L[I]).Raw) then
      begin
        TObject(L[I]).Free;
        L.Delete(I);
        Break;
      end;
  for I := 0 to L.Count - 1 do
  begin
    M := TTLMember(L[I]);
    M.Name := M.Raw;
    if InList(M.Name, ReservedWords) then M.Name := M.Name + '_';
    if ForWrapper and (InList(M.Name, WrapperMembers) or InList(M.Name, ControlPublished)) then M.Name := M.Name + '_';
  end;
end;

procedure TTLBWriter.AddEnum(I: Integer; Dst: TStrings);
var
  TI: ITypeInfo;
  A: PTypeAttr;
  K: Integer;
  VD: PVarDesc;
  V: Int64;
begin
  TI := TypeInfoAt(I);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  try
    Dst.Add('// Constants for enum ' + FNames[I]);
    Dst.Add('type');
    Dst.Add('  ' + FNames[I] + ' = TOleEnum;');
    if A.cVars > 0 then Dst.Add('const');
    for K := 0 to A.cVars - 1 do
    begin
      if Failed(TI.GetVarDesc(K, VD)) then Continue;
      try
        V := 0;
        if (VD.varkind = VAR_CONST) and (VD.lpvarValue <> nil) then
          try
            V := VD.lpvarValue^;
          except
            V := 0;
          end;
        Dst.Add(Format('  %s = $%.8x;', [Unique(MemberName(TI, VD.memid)), Cardinal(V)]));
      finally
        TI.ReleaseVarDesc(VD);
      end;
    end;
    Dst.Add('');
  finally
    TI.ReleaseTypeAttr(A);
  end;
end;

procedure TTLBWriter.AddModule(I: Integer; Dst: TStrings);
var
  TI: ITypeInfo;
  A: PTypeAttr;
  K, N: Integer;
  VD: PVarDesc;
begin
  TI := TypeInfoAt(I);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  try
    N := 0;
    for K := 0 to A.cVars - 1 do
    begin
      if Failed(TI.GetVarDesc(K, VD)) then Continue;
      try
        if (VD.varkind <> VAR_CONST) or (VD.lpvarValue = nil) then Continue;
        if N = 0 then
        begin
          Dst.Add('// Constants for module ' + FNames[I]);
          Dst.Add('const');
        end;
        Inc(N);
        Dst.Add(Format('  %s = %s;', [Unique(MemberName(TI, VD.memid)), ConstText(VD.lpvarValue^)]));
      finally
        TI.ReleaseVarDesc(VD);
      end;
    end;
    if N > 0 then Dst.Add('');
  finally
    TI.ReleaseTypeAttr(A);
  end;
end;

procedure TTLBWriter.AddRecord(I: Integer; Dst: TStrings);
var
  TI: ITypeInfo;
  A: PTypeAttr;
  K: Integer;
  VD: PVarDesc;
  Union: Boolean;
  F: string;
begin
  TI := TypeInfoAt(I);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  try
    Union := A.typekind = TKIND_UNION;
    Dst.Add('  ' + FNames[I] + ' = record');
    if Union then Dst.Add('    case Integer of');
    for K := 0 to A.cVars - 1 do
    begin
      if Failed(TI.GetVarDesc(K, VD)) then Continue;
      try
        F := MemberName(TI, VD.memid);
        if InList(F, ReservedWords) then F := F + '_';
        if Union then Dst.Add(Format('      %d: (%s: %s);', [K, F, FieldText(TI, VD.elemdescVar.tdesc, True)]))
        else Dst.Add(Format('    %s: %s;', [F, FieldText(TI, VD.elemdescVar.tdesc, False)]));
      finally
        TI.ReleaseVarDesc(VD);
      end;
    end;
    if A.cVars = 0 then
      if Union then Dst.Add('      0: (Dummy: Integer);') else Dst.Add('    Dummy: Integer;');
    Dst.Add('  end;');
    Dst.Add('');
  finally
    TI.ReleaseTypeAttr(A);
  end;
end;

procedure TTLBWriter.AddAlias(I: Integer; Dst: TStrings);
var
  TI: ITypeInfo;
  A: PTypeAttr;
begin
  TI := TypeInfoAt(I);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  try
    Dst.Add('  ' + FNames[I] + ' = ' + FieldText(TI, A.tdescAlias, False) + ';');
  finally
    TI.ReleaseTypeAttr(A);
  end;
end;

{ a v-table interface: its functions in the order of its v-table, then the properties of its
  get / put functions (safecall ones; a getter's parameters are the index) }
procedure TTLBWriter.AddInterface(VTI: ITypeInfo; const Name: string; Dst: TStrings);
type
  TProp = record
    Name, Index, Typ, Getter, Put, PutType, Ref, RefType: string;
    DispID: Integer;
  end;
var
  A: PTypeAttr;
  I, K: Integer;
  FD: PFuncDesc;
  R: HRefType;
  Anc, Res: TTLType;
  Raw, Fn, H, Conv, PD: string;
  P: TTLParams;
  HasRes, Safe, IsSafe: Boolean;
  Props: array of TProp;
  Methods: TStringList;
begin
  if Failed(VTI.GetTypeAttr(A)) then Exit;
  { the function names taken, looked up for every function and property: sorted, a binary search
    (an interface of Office or MSHTML has hundreds of functions; nothing reads the list in order) }
  Methods := TStringList.Create;
  Methods.Sorted := True;
  try
    Anc := NoType;
    Anc.Name := 'IUnknown';
    if (A.cImplTypes > 0) and Succeeded(VTI.GetRefTypeOfImplType(0, R)) then
      if not RefType(VTI, R, Anc) then Anc.Name := 'IUnknown';
    Safe := (FImp.FOptions.Safecall = 0) or
      (FImp.FOptions.Safecall = 1) and (A.wTypeFlags and TYPEFLAG_FDUAL <> 0);
    Dst.Add('// *********************************************************************//');
    Dst.Add('// Interface: ' + Name);
    Dst.Add('// GUID:      ' + GuidText(A.guid));
    Dst.Add('// *********************************************************************//');
    Dst.Add('  ' + Name + ' = interface(' + Anc.Name + ')');
    Dst.Add('    [''' + GuidText(A.guid) + ''']');
    for I := 0 to A.cFuncs - 1 do
    begin
      if Failed(VTI.GetFuncDesc(I, FD)) then Continue;
      try
        Raw := MemberName(VTI, FD.memid);
        Fn := Raw;
        if InList(Fn, ReservedWords) then Fn := Fn + '_';
        case FD.invkind of
          INVOKE_PROPERTYGET: Fn := 'Get_' + Raw;
          INVOKE_PROPERTYPUT: Fn := 'Set_' + Raw;
          INVOKE_PROPERTYPUTREF: Fn := '_Set_' + Raw;
        end;
        { two functions of one name: the second gets an underscore }
        while Methods.IndexOf(Fn) >= 0 do Fn := Fn + '_';
        Methods.Add(Fn);
        IsSafe := Safe and (FD.elemdescFunc.tdesc.vt = VT_HRESULT);
        P := FuncParams(VTI, FD, IsSafe, False, Res, HasRes);
        PD := ParamDecl(P, 0, High(P));
        if HasRes then H := 'function ' + Fn else H := 'procedure ' + Fn;
        if PD <> '' then H := H + '(' + PD + ')';
        if HasRes then H := H + ': ' + ValueText(Res);
        if IsSafe then Conv := 'safecall'
        else if FD.callconv = CC_CDECL then Conv := 'cdecl'
        else Conv := 'stdcall';
        Dst.Add('    ' + H + '; ' + Conv + ';');
        if (FD.invkind = INVOKE_FUNC) or not IsSafe then Continue;
        K := 0;
        while (K < Length(Props)) and not SameText(Props[K].Name, Raw) do Inc(K);
        if K = Length(Props) then
        begin
          SetLength(Props, K + 1);
          Props[K].Name := Raw;
          Props[K].Getter := '';
          Props[K].Put := '';
          Props[K].PutType := '';
          Props[K].Ref := '';
          Props[K].RefType := '';
          Props[K].Index := '';
          Props[K].Typ := '';
          Props[K].DispID := FD.memid;
        end;
        if FD.invkind = INVOKE_PROPERTYGET then
        begin
          if HasRes then
          begin
            Props[K].Getter := Fn;
            Props[K].Typ := ValueText(Res);
            Props[K].Index := PD;
          end;
        end
        else if Length(P) > 0 then
          if FD.invkind = INVOKE_PROPERTYPUTREF then
          begin
            Props[K].Ref := Fn;
            Props[K].RefType := ValueText(ValueOf(P[High(P)].T));
          end
          else
          begin
            Props[K].Put := Fn;
            Props[K].PutType := ValueText(ValueOf(P[High(P)].T));
          end;
      finally
        VTI.ReleaseFuncDesc(FD);
      end;
    end;
    for K := 0 to High(Props) do
    begin
      { a property needs a type and a getter (Delphi's write-only ones are left out) }
      if (Props[K].Typ = '') or (Props[K].Getter = '') or (Methods.IndexOf(Props[K].Name) >= 0) then Continue;
      H := '    property ' + Props[K].Name;
      if InList(Props[K].Name, ReservedWords) then H := H + '_';
      if Props[K].Index <> '' then H := H + '[' + Props[K].Index + ']';
      H := H + ': ' + Props[K].Typ + ' read ' + Props[K].Getter;
      { the setter of the getter's type (a put, else a putref); none: read-only }
      if SameText(Props[K].PutType, Props[K].Typ) then H := H + ' write ' + Props[K].Put
      else if SameText(Props[K].RefType, Props[K].Typ) then H := H + ' write ' + Props[K].Ref;
      H := H + ';';
      if (Props[K].DispID = DISPID_VALUE) and (Props[K].Index <> '') then H := H + ' default;';
      Dst.Add(H);
    end;
    Dst.Add('  end;');
    Dst.Add('');
  finally
    Methods.Free;
    VTI.ReleaseTypeAttr(A);
  end;
end;

{ M as a dispinterface declares it - its safe arrays as OleVariant -; True when its result and its
  parameters are automation types }
function DispMember(M: TTLMember): Boolean;
var
  K: Integer;
begin
  for K := 0 to High(M.Params) do
    if M.Params[K].T.Name = 'PSafeArray' then M.Params[K].T.Name := 'OleVariant';
  if M.Result.Name = 'PSafeArray' then M.Result.Name := 'OleVariant';
  Result := not M.HasResult or (M.Result.Level <= 0) and AutoType(M.Result);
  for K := 0 to High(M.Params) do
    if not AutoType(M.Params[K].T) then Result := False;
end;

procedure TTLBWriter.AddDispinterface(DTI: ITypeInfo; const Name: string; Dst: TStrings);
var
  L: TList;
  I: Integer;
  M: TTLMember;
  H, PD: string;
  G: TGUID;
  Auto: Boolean;
begin
  G := GuidOf(DTI);
  L := TList.Create;
  try
    DispMembers(DTI, L, False);
    Dst.Add('// *********************************************************************//');
    Dst.Add('// DispIntf:  ' + Name);
    Dst.Add('// GUID:      ' + GuidText(G));
    Dst.Add('// *********************************************************************//');
    Dst.Add('  ' + Name + ' = dispinterface');
    Dst.Add('    [''' + GuidText(G) + ''']');
    for I := 0 to L.Count - 1 do
    begin
      M := TTLMember(L[I]);
      Auto := DispMember(M);
      PD := ParamDecl(M.Params, 0, High(M.Params));
      if M.IsProp then
      begin
        if not M.HasResult then Continue;
        H := '    property ' + M.Name;
        if PD <> '' then H := H + '[' + PD + ']';
        H := H + ': ' + ValueText(M.Result);
        if not M.CanWrite then H := H + ' readonly'
        else if not M.CanRead then H := H + ' writeonly';
        H := H + Format(' dispid %d;', [M.DispID]);
        if (M.DispID = DISPID_VALUE) and (PD <> '') then H := H + ' default;';
      end
      else
      begin
        if M.HasResult then H := '    function ' + M.Name else H := '    procedure ' + M.Name;
        if PD <> '' then H := H + '(' + PD + ')';
        if M.HasResult then H := H + ': ' + ValueText(M.Result);
        H := H + Format('; dispid %d;', [M.DispID]);
      end;
      { not an automation type: what the importer cannot declare stays a comment }
      if not Auto then H := '    // ' + TrimLeft(H);
      Dst.Add(H);
    end;
    Dst.Add('  end;');
    Dst.Add('');
  finally
    for I := 0 to L.Count - 1 do TObject(L[I]).Free;
    L.Free;
  end;
end;

{ an interface type of the library: a dual one as interface + dispinterface }
procedure TTLBWriter.AddIntfOf(I: Integer; Dst: TStrings);
var
  VTI, DTI: ITypeInfo;
begin
  if DualParts(TypeInfoAt(I), VTI, DTI) then
  begin
    if VTI <> nil then AddInterface(VTI, FNames[I], Dst);
    if DTI <> nil then AddDispinterface(DTI, FDispNames[I], Dst);
  end
  else if VTI <> nil then AddInterface(VTI, FNames[I], Dst)
  else if DTI <> nil then AddDispinterface(DTI, FNames[I], Dst);
end;

{ a CoClass with a wrapper: a creatable control (TOleControl; Import ActiveX Control or wrappers
  on), any other creatable one (TOleServer, wrappers on); its default interface has a dispatch
  view }
function TTLBWriter.WantsWrapper(I: Integer; out Control: Boolean): Boolean;
var
  TI, D, VTI, DTI: ITypeInfo;
  F: Word;
  N: string;
begin
  Result := False;
  Control := False;
  if KindAt(I) <> TKIND_COCLASS then Exit;
  TI := TypeInfoAt(I);
  TypeKindOf(TI, F);
  if F and TYPEFLAG_FCANCREATE = 0 then Exit;
  Control := F and TYPEFLAG_FCONTROL <> 0;
  if Control then
  begin
    if not (FImp.FOptions.Wrappers or FImp.FOptions.ControlsOnly) then Exit;
  end
  else if not FImp.FOptions.Wrappers or FImp.FOptions.ControlsOnly then Exit;
  D := DefaultIntf(TI, False, N);
  if D = nil then Exit;
  DualParts(D, VTI, DTI);
  Result := DTI <> nil;
end;

function TTLBWriter.WrapperNames: string;
var
  I: Integer;
  C: Boolean;
begin
  Result := '';
  for I := 0 to FNames.Count - 1 do
    if WantsWrapper(I, C) then Result := Result + 'T' + FNames[I] + #13#10;
end;

{ the accessor of TOleControl for a property of this type (Get<Kind>Prop), '' none; the type the
  property then has }
function ControlAccessor(const T: TTLType; out Typ: string): string;
begin
  Result := '';
  Typ := T.Name;
  if T.Level > 0 then Exit;
  if SameText(T.Std, 'OLE_COLOR') then
  begin
    Result := 'TColor';
    Typ := 'TColor';
  end
  else if SameText(T.Name, 'Font') or SameText(T.Name, 'IFontDisp') then
  begin
    if T.Std = '' then Exit;
    Result := 'TFont';
    Typ := 'TFont';
  end
  else if SameText(T.Name, 'Picture') or SameText(T.Name, 'IPictureDisp') then
  begin
    if T.Std = '' then Exit;
    Result := 'TPicture';
    Typ := 'TPicture';
  end
  else if T.Enum then Result := 'TOleEnum'
  else if T.Intf then
  begin
    if SameText(T.Name, 'IDispatch') then Result := 'IDispatch'
    else if SameText(T.Name, 'IUnknown') then Result := 'IUnknown';
  end
  else
    case T.Base of
      VT_I4: Result := 'Integer';
      VT_I2: Result := 'Smallint';
      VT_UI1: Result := 'Byte';
      VT_I1: Result := 'ShortInt';
      VT_UI2: Result := 'Word';
      VT_BSTR: Result := 'WideString';
      VT_BOOL: Result := 'WordBool';
      VT_R8: Result := 'Double';
      VT_R4: Result := 'Single';
      VT_CY: Result := 'Currency';
      VT_DATE: Result := 'TDateTime';
      VT_VARIANT: Result := 'OleVariant';
    end;
end;

{ the members of the default interface, forwarded: methods, properties through accessors - or a
  control's simple ones through TOleControl's Get<Kind>Prop by their dispid (published when they
  can be read and written). Dual: the calls go to the v-table's functions (Get_X, Set_X, _Set_X:
  they are there, a property of the interface may not be); else to the dispinterface, whose
  members of other than automation types are not declared. }
procedure TTLBWriter.AddForwarders(const Cls: string; Members: TList; Decl, Impl, Pubs: TStrings;
  Control, Dual: Boolean);
var
  I: Integer;
  M: TTLMember;
  H, Acc, Typ, Idx, Args, Call, PD, RT, Setter: string;
  Prot, Pub: TStringList;
begin
  Prot := TStringList.Create;
  Pub := TStringList.Create;
  try
    for I := 0 to Members.Count - 1 do
    begin
      M := TTLMember(Members[I]);
      if not Dual then
        if not DispMember(M) then Continue;
      PD := ParamDecl(M.Params, 0, High(M.Params));
      Args := ParamArgs(M.Params, 0, High(M.Params));
      RT := ValueText(M.Result);
      if M.IsProp then
      begin
        if not M.HasResult then Continue;
        Acc := '';
        if Control and (PD = '') then Acc := ControlAccessor(M.Result, Typ);
        if Acc <> '' then
        begin
          H := Format('    property %s: %s index %d read Get%sProp', [M.Name, Typ, M.DispID, Acc]);
          if M.CanWrite then H := H + ' write Set' + Acc + 'Prop';
          if M.CanWrite and M.CanRead and not M.Hidden then Pubs.Add(H + ' stored False;')
          else Pub.Add(H + ';');
          Continue;
        end;
        if not M.CanRead then Continue;
        if Args <> '' then Idx := '[' + Args + ']' else Idx := '';
        if Dual then
        begin
          if Args <> '' then Call := 'DefaultInterface.Get_' + M.Raw + '(' + Args + ')'
          else Call := 'DefaultInterface.Get_' + M.Raw;
          { the setter of the property's type }
          Setter := '';
          if SameText(M.PutType, RT) then Setter := 'Set_' + M.Raw
          else if SameText(M.RefType, RT) then Setter := '_Set_' + M.Raw;
        end
        else
        begin
          Call := 'DefaultInterface.' + IntfName(M.Raw) + Idx;
          Setter := '=';
        end;
        H := '    property ' + M.Name;
        if PD <> '' then H := H + '[' + PD + ']';
        H := H + ': ' + RT + ' read Get_' + M.Name;
        if PD <> '' then
        begin
          Prot.Add(Format('    function Get_%s(%s): %s;', [M.Name, PD, RT]));
          Impl.Add(Format('function %s.Get_%s(%s): %s;', [Cls, M.Name, PD, RT]));
        end
        else
        begin
          Prot.Add(Format('    function Get_%s: %s;', [M.Name, RT]));
          Impl.Add(Format('function %s.Get_%s: %s;', [Cls, M.Name, RT]));
        end;
        Impl.Add('begin');
        Impl.Add('  Result := ' + Call + ';');
        Impl.Add('end;');
        Impl.Add('');
        if M.CanWrite and (Setter <> '') then
        begin
          if PD <> '' then
          begin
            Prot.Add(Format('    procedure Set_%s(%s; Value: %s);', [M.Name, PD, RT]));
            Impl.Add(Format('procedure %s.Set_%s(%s; Value: %s);', [Cls, M.Name, PD, RT]));
          end
          else
          begin
            Prot.Add(Format('    procedure Set_%s(Value: %s);', [M.Name, RT]));
            Impl.Add(Format('procedure %s.Set_%s(Value: %s);', [Cls, M.Name, RT]));
          end;
          Impl.Add('begin');
          if not Dual then Impl.Add('  ' + Call + ' := Value;')
          else if Args <> '' then Impl.Add('  DefaultInterface.' + Setter + '(' + Args + ', Value);')
          else Impl.Add('  DefaultInterface.' + Setter + '(Value);');
          Impl.Add('end;');
          Impl.Add('');
          H := H + ' write Set_' + M.Name;
        end;
        Pub.Add(H + ';');
      end
      else
      begin
        if M.Hidden then Continue;
        if PD <> '' then PD := '(' + PD + ')';
        if M.HasResult then
        begin
          Pub.Add(Format('    function %s%s: %s;', [M.Name, PD, RT]));
          Impl.Add(Format('function %s.%s%s: %s;', [Cls, M.Name, PD, RT]));
        end
        else
        begin
          Pub.Add(Format('    procedure %s%s;', [M.Name, PD]));
          Impl.Add(Format('procedure %s.%s%s;', [Cls, M.Name, PD]));
        end;
        Call := 'DefaultInterface.' + IntfName(M.Raw);
        if Args <> '' then Call := Call + '(' + Args + ')';
        Impl.Add('begin');
        if M.HasResult then Impl.Add('  Result := ' + Call + ';') else Impl.Add('  ' + Call + ';');
        Impl.Add('end;');
        Impl.Add('');
      end;
    end;
    Decl.Add('  protected');
    Decl.AddStrings(Prot);
    Decl.Add('  public');
    Decl.AddStrings(Pub);
  finally
    Pub.Free;
    Prot.Free;
  end;
end;

{ an event's argument from the variants of a server's call (a by-reference one through its pointer) }
function TTLBWriter.EventArg(const P: TTLParam; Index: Integer): string;
begin
  if P.Mode in [pmVar, pmOut] then
  begin
    if P.T.Level > 1 then Result := Format('Pointer((TVarData(Params[%d]).VPointer)^)', [Index])
    else Result := Format('%s((TVarData(Params[%d]).VPointer)^)', [Q(P.T.Name), Index]);
  end
  else if P.T.Disp then
    Result := Format('%s(IDispatch(Params[%d]))', [Q(P.T.Name), Index])
  else if P.T.Intf and not SameText(P.T.Name, 'IDispatch') and not SameText(P.T.Name, 'IUnknown') then
    Result := Format('IUnknown(TVarData(Params[%d]).VPointer) as %s', [Index, Q(P.T.Name)])
  else
    Result := Format('Params[%d]', [Index]);
end;

{ TL is this writer's library (a comparison: no writer is made for another) }
function TTLBWriter.IsOwn(TL: ITypeLib): Boolean;
var
  A: PTLibAttr;
begin
  Result := False;
  if (TL = nil) or Failed(TL.GetLibAttr(A)) then Exit;
  Result := IsEqualGUID(A.guid, FGuid);
  TL.ReleaseTLibAttr(A);
end;

{ a type of this unit in a wrapper's method, qualified: the class can have a member of its name
  (MMC's Document, VsHelp's Help) }
function TTLBWriter.Q(const Name: string): string;
var
  I: Integer;
begin
  if (Pos('.', Name) = 0) and FTypeNames.Find(Name, I) then
    Result := FUnit + '.' + Name
  else
    Result := Name;
end;

{ an event a server's wrapper can pass on: its values come out of variants }
function EventPassable(M: TTLMember): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to High(M.Params) do
    if not (M.Params[I].Mode in [pmVar, pmOut]) and ((M.Params[I].T.Level > 0) or not AutoType(M.Params[I].T)) then
      Result := False;
end;

{ the wrapper of a CoClass: TOleControl (InitControlData, its events in the order of their fields)
  or TOleServer (Connect, ConnectTo, InvokeEvent) }
procedure TTLBWriter.AddWrapper(I: Integer; Decl, Impl, Reg: TStrings; Control: Boolean);
var
  TI, D, VTI, DTI, Src: ITypeInfo;
  Cls, Intf, SrcName, Ev, H, Ids, Args, Fonts, Pictures, PT: string;
  Members, Events: TList;
  K, J, NE, NF, NP: Integer;
  M: TTLMember;
  Pubs, Types: TStringList;
  DefT: TTLType;
begin
  TI := TypeInfoAt(I);
  D := DefaultIntf(TI, False, Intf);
  if D = nil then Exit;
  DualParts(D, VTI, DTI);
  if DTI = nil then Exit;
  DefT := NoType;
  DefT.Disp := VTI = nil;
  { no safecall mapping: the v-table has no accessors to forward to - the wrapper works through
    the dispinterface of a dual interface of this library }
  if (VTI <> nil) and (FImp.FOptions.Safecall = 2) then
  begin
    if FTypeNames.Find(Intf, K) then K := Integer(FTypeNames.Objects[K]) else K := -1;
    if (K < 0) or (FDispNames[K] = '') then Exit;
    Intf := FDispNames[K];
    VTI := nil;
    DefT.Disp := True;
  end;
  Cls := Unique('T' + FNames[I]);
  Src := DefaultIntf(TI, True, SrcName);
  Members := TList.Create;
  Events := TList.Create;
  Pubs := TStringList.Create;
  Types := TStringList.Create;
  try
    DispMembers(DTI, Members, True);
    if Src <> nil then DispMembers(Src, Events, False);
    for K := Events.Count - 1 downto 0 do
      if TTLMember(Events[K]).IsProp or not Control and not EventPassable(TTLMember(Events[K])) then
      begin
        TObject(Events[K]).Free;
        Events.Delete(K);
      end;
    { the types of the event handlers }
    for K := 0 to Events.Count - 1 do
    begin
      M := TTLMember(Events[K]);
      if Length(M.Params) = 0 then M.EventType := 'TNotifyEvent'
      else
      begin
        M.EventType := Unique(Cls + M.Raw);
        Types.Add(Format('  %s = procedure(ASender: TObject; %s) of object;',
          [M.EventType, ParamDecl(M.Params, 0, High(M.Params))]));
      end;
    end;
    if Types.Count > 0 then
    begin
      Decl.AddStrings(Types);
      Decl.Add('');
    end;
    Decl.Add('// *********************************************************************//');
    if Control then Decl.Add('// OLE Control Proxy class declaration') else Decl.Add('// OLE Server Proxy class declaration');
    Decl.Add('// Control Name     : ' + Cls);
    Decl.Add('// Default Interface: ' + Intf);
    if SrcName <> '' then Decl.Add('// Event   Interface: ' + SrcName);
    Decl.Add('// *********************************************************************//');
    if Control then Decl.Add('  ' + Cls + ' = class(TOleControl)') else Decl.Add('  ' + Cls + ' = class(TOleServer)');
    Decl.Add('  private');
    for K := 0 to Events.Count - 1 do
      Decl.Add(Format('    FOn%s: %s;', [TTLMember(Events[K]).Raw, TTLMember(Events[K]).EventType]));
    Decl.Add('    FIntf: ' + Intf + ';');
    if Control then
    begin
      Decl.Add('    function  GetControlInterface: ' + Intf + ';');
      Decl.Add('  protected');
      Decl.Add('    procedure CreateControl;');
      Decl.Add('    procedure InitControlData; override;');
    end
    else
    begin
      Decl.Add('    function  GetDefaultInterface: ' + Intf + ';');
      Decl.Add('  protected');
      Decl.Add('    procedure InitServerData; override;');
      if Events.Count > 0 then Decl.Add('    procedure InvokeEvent(DispID: TDispID; var Params: TVariantArray); override;');
    end;
    AddForwarders(Cls, Members, Decl, Impl, Pubs, Control, VTI <> nil);
    if Control then
    begin
      Decl.Add('    property  ControlInterface: ' + Intf + ' read GetControlInterface;');
      Decl.Add('    property  DefaultInterface: ' + Intf + ' read GetControlInterface;');
    end
    else
    begin
      Decl.Add('    constructor Create(AOwner: TComponent); override;');
      Decl.Add('    destructor  Destroy; override;');
      Decl.Add('    procedure Connect; override;');
      Decl.Add('    procedure ConnectTo(svrIntf: ' + Intf + ');');
      Decl.Add('    procedure Disconnect; override;');
      Decl.Add('    property DefaultInterface: ' + Intf + ' read GetDefaultInterface;');
    end;
    Decl.Add('  published');
    if Control then
      for K := Low(ControlPublished) to High(ControlPublished) do Decl.Add('    property ' + ControlPublished[K] + ';');
    Decl.AddStrings(Pubs);
    for K := 0 to Events.Count - 1 do
    begin
      M := TTLMember(Events[K]);
      Ev := 'On' + M.Raw;
      if InList(Ev, ControlPublished) or InList(Ev, WrapperMembers) then Ev := Ev + '_';
      Decl.Add(Format('    property %s: %s read FOn%s write FOn%s;', [Ev, M.EventType, M.Raw, M.Raw]));
    end;
    Decl.Add('  end;');
    Decl.Add('');
    Reg.Add(Cls);
    if Control then
    begin
      { the dispids of the events in the order of their fields; the fonts and pictures the
        control has (TOleControl keeps their objects) }
      Ids := '';
      NE := Events.Count;
      for K := 0 to NE - 1 do
      begin
        if K > 0 then Ids := Ids + ', ';
        if (K > 0) and (K mod 6 = 0) then Ids := Ids + #13#10'    ';
        Ids := Ids + Format('$%.8x', [Cardinal(TTLMember(Events[K]).DispID)]);
      end;
      Fonts := '';
      Pictures := '';
      NF := 0;
      NP := 0;
      for K := 0 to Members.Count - 1 do
      begin
        M := TTLMember(Members[K]);
        if not M.IsProp or (Length(M.Params) > 0) then Continue;
        H := ControlAccessor(M.Result, PT);
        if H = 'TFont' then
        begin
          if Fonts <> '' then Fonts := Fonts + ', ';
          Fonts := Fonts + Format('$%.8x', [Cardinal(M.DispID)]);
          Inc(NF);
        end
        else if H = 'TPicture' then
        begin
          if Pictures <> '' then Pictures := Pictures + ', ';
          Pictures := Pictures + Format('$%.8x', [Cardinal(M.DispID)]);
          Inc(NP);
        end;
      end;
      Impl.Add(Format('procedure %s.InitControlData;', [Cls]));
      Impl.Add('const');
      if NE > 0 then Impl.Add(Format('  CEventDispIDs: array [0..%d] of DWORD = (%s);', [NE - 1, Ids]));
      if NF > 0 then Impl.Add(Format('  CTFontIDs: array [0..%d] of DWORD = (%s);', [NF - 1, Fonts]));
      if NP > 0 then Impl.Add(Format('  CTPictureIDs: array [0..%d] of DWORD = (%s);', [NP - 1, Pictures]));
      Impl.Add('  CControlData: TControlData2 = (');
      Impl.Add('    ClassID: ''' + GuidText(GuidOf(TI)) + ''';');
      if NE > 0 then Impl.Add('    EventIID: ''' + GuidText(GuidOf(Src)) + ''';')
      else Impl.Add('    EventIID: ''{00000000-0000-0000-0000-000000000000}'';');
      Impl.Add(Format('    EventCount: %d;', [NE]));
      if NE > 0 then Impl.Add('    EventDispIDs: @CEventDispIDs;') else Impl.Add('    EventDispIDs: nil;');
      Impl.Add('    LicenseKey: nil;');
      Impl.Add('    Flags: $00000000;');
      if NF + NP = 0 then Impl.Add('    Version: 401);')
      else
      begin
        Impl.Add('    Version: 401;');
        Impl.Add(Format('    FontCount: %d;', [NF]));
        if NF > 0 then Impl.Add('    FontIDs: @CTFontIDs;') else Impl.Add('    FontIDs: nil;');
        Impl.Add(Format('    PictureCount: %d;', [NP]));
        if NP > 0 then Impl.Add('    PictureIDs: @CTPictureIDs);') else Impl.Add('    PictureIDs: nil);');
      end;
      Impl.Add('begin');
      Impl.Add('  ControlData := @CControlData;');
      if NE > 0 then
        Impl.Add(Format('  TControlData2(CControlData).FirstEventOfs := Cardinal(@@FOn%s) - Cardinal(Self);',
          [TTLMember(Events[0]).Raw]));
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('procedure %s.CreateControl;', [Cls]));
      Impl.Add('');
      Impl.Add('  procedure DoCreate;');
      Impl.Add('  begin');
      Impl.Add('    FIntf := ' + AsIntf('IUnknown(OleObject)', DefT, Q(Intf)) + ';');
      Impl.Add('  end;');
      Impl.Add('');
      Impl.Add('begin');
      Impl.Add('  if FIntf = nil then DoCreate;');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('function %s.GetControlInterface: %s;', [Cls, Intf]));
      Impl.Add('begin');
      Impl.Add('  CreateControl;');
      Impl.Add('  Result := FIntf;');
      Impl.Add('end;');
      Impl.Add('');
    end
    else
    begin
      Impl.Add(Format('procedure %s.InitServerData;', [Cls]));
      Impl.Add('const');
      Impl.Add('  CServerData: TServerData = (');
      Impl.Add('    ClassID:   ''' + GuidText(GuidOf(TI)) + ''';');
      Impl.Add('    IntfIID:   ''' + GuidText(GuidOf(D)) + ''';');
      if Events.Count > 0 then Impl.Add('    EventIID:  ''' + GuidText(GuidOf(Src)) + ''';')
      else Impl.Add('    EventIID:  '''';');
      Impl.Add('    LicenseKey: nil;');
      Impl.Add('    Version: 500);');
      Impl.Add('begin');
      Impl.Add('  ServerData := @CServerData;');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('procedure %s.Connect;', [Cls]));
      Impl.Add('var');
      Impl.Add('  punk: IUnknown;');
      Impl.Add('begin');
      Impl.Add('  if FIntf = nil then');
      Impl.Add('  begin');
      Impl.Add('    punk := GetServer;');
      if Events.Count > 0 then Impl.Add('    ConnectEvents(punk);');
      Impl.Add('    FIntf := ' + AsIntf('punk', DefT, Q(Intf)) + ';');
      Impl.Add('  end;');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('procedure %s.ConnectTo(svrIntf: %s);', [Cls, Intf]));
      Impl.Add('begin');
      Impl.Add('  Disconnect;');
      Impl.Add('  FIntf := svrIntf;');
      if Events.Count > 0 then Impl.Add('  ConnectEvents(FIntf);');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('procedure %s.Disconnect;', [Cls]));
      Impl.Add('begin');
      Impl.Add('  if FIntf <> nil then');
      Impl.Add('  begin');
      if Events.Count > 0 then Impl.Add('    DisconnectEvents(FIntf);');
      Impl.Add('    FIntf := nil;');
      Impl.Add('  end;');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('function %s.GetDefaultInterface: %s;', [Cls, Intf]));
      Impl.Add('begin');
      Impl.Add('  if FIntf = nil then Connect;');
      Impl.Add('  Assert(FIntf <> nil, ''DefaultInterface is NULL. Component is not connected to Server. ' +
        'You must call ''''Connect'''' or ''''ConnectTo'''' before this operation'');');
      Impl.Add('  Result := FIntf;');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('constructor %s.Create(AOwner: TComponent);', [Cls]));
      Impl.Add('begin');
      Impl.Add('  inherited Create(AOwner);');
      Impl.Add('end;');
      Impl.Add('');
      Impl.Add(Format('destructor %s.Destroy;', [Cls]));
      Impl.Add('begin');
      Impl.Add('  inherited Destroy;');
      Impl.Add('end;');
      Impl.Add('');
      if Events.Count > 0 then
      begin
        Impl.Add(Format('procedure %s.InvokeEvent(DispID: TDispID; var Params: TVariantArray);', [Cls]));
        Impl.Add('begin');
        Impl.Add('  case DispID of');
        Impl.Add('    -1: Exit;  // DISPID_UNKNOWN');
        for K := 0 to Events.Count - 1 do
        begin
          M := TTLMember(Events[K]);
          Args := '';
          for J := 0 to High(M.Params) do Args := Args + ', ' + EventArg(M.Params[J], J);
          Impl.Add(Format('    %d: if Assigned(FOn%s) then FOn%s(Self%s);', [M.DispID, M.Raw, M.Raw, Args]));
        end;
        Impl.Add('  end;');
        Impl.Add('end;');
        Impl.Add('');
      end;
    end;
  finally
    Types.Free;
    Pubs.Free;
    for K := 0 to Members.Count - 1 do TObject(Members[K]).Free;
    Members.Free;
    for K := 0 to Events.Count - 1 do TObject(Events[K]).Free;
    Events.Free;
  end;
end;

{ the whole unit }
procedure TTLBWriter.Write;
var
  N, I, Pass: Integer;
  Dst, Consts, Enums, Fwd, CoAlias, Recs, Intfs, Creators, CoImpl, Wrappers, WImpl, Reg, RegServers: TStringList;
  TI: ITypeInfo;
  Kind: TTypeKind;
  F: Word;
  Done: array of Boolean;
  Progress, Control: Boolean;
  S, DefName: string;

  { a record, union or alias that holds one of this library not written yet waits }
  function Ready(Idx: Integer): Boolean;
  var
    T: ITypeInfo;
    A: PTypeAttr;
    J: Integer;
    VD: PVarDesc;

    function Needs(const TD: TTypeDesc): Boolean;
    var
      R: ITypeInfo;
      RTL: ITypeLib;
      RI: Integer;
      TD2: TTypeDesc;
    begin
      Result := False;
      TD2 := TD;
      while TD2.vt = VT_CARRAY do TD2 := TD2.padesc.tdescElem;
      if TD2.vt <> VT_USERDEFINED then Exit;
      if Failed(T.GetRefTypeInfo(TD2.hreftype, R)) or Failed(R.GetContainingTypeLib(RTL, RI)) then Exit;
      if IsOwn(RTL) and (KindAt(RI) in [TKIND_RECORD, TKIND_UNION, TKIND_ALIAS]) then
        Result := not Done[RI];
    end;

  begin
    Result := True;
    T := TypeInfoAt(Idx);
    if Failed(T.GetTypeAttr(A)) then Exit;
    try
      if A.typekind = TKIND_ALIAS then Result := not Needs(A.tdescAlias)
      else
        for J := 0 to A.cVars - 1 do
          if Succeeded(T.GetVarDesc(J, VD)) then
            try
              if Needs(VD.elemdescVar.tdesc) then Result := False;
            finally
              T.ReleaseVarDesc(VD);
            end;
    finally
      T.ReleaseTypeAttr(A);
    end;
  end;

  { an interface whose ancestor of this library is not written yet waits }
  function IntfReady(Idx: Integer): Boolean;
  var
    V, Dd, R: ITypeInfo;
    RTL: ITypeLib;
    RI: Integer;
    Href: HRefType;
    A: PTypeAttr;
    Has: Boolean;
  begin
    Result := True;
    DualParts(TypeInfoAt(Idx), V, Dd);
    if V = nil then Exit;
    if Failed(V.GetTypeAttr(A)) then Exit;
    try
      Has := (A.cImplTypes > 0) and Succeeded(V.GetRefTypeOfImplType(0, Href));
    finally
      V.ReleaseTypeAttr(A);
    end;
    if not Has or Failed(V.GetRefTypeInfo(Href, R)) or Failed(R.GetContainingTypeLib(RTL, RI)) then Exit;
    if IsOwn(RTL) and (RI <> Idx) then Result := Done[RI];
  end;

  function Joined(L: TStrings): string;
  begin
    Result := StringReplace(Trim(L.Text), #13#10, ', ', [rfReplaceAll]);
  end;

begin
  if FWritten then Exit;
  FWritten := True;
  N := FTL.GetTypeInfoCount;
  Dst := TStringList.Create;
  Consts := TStringList.Create;
  Enums := TStringList.Create;
  Fwd := TStringList.Create;
  CoAlias := TStringList.Create;
  Recs := TStringList.Create;
  Intfs := TStringList.Create;
  Creators := TStringList.Create;
  CoImpl := TStringList.Create;
  Wrappers := TStringList.Create;
  WImpl := TStringList.Create;
  Reg := TStringList.Create;
  RegServers := TStringList.Create;
  try
    SetLength(Done, N);
    { GUIDs }
    Consts.Add(Format('  %sMajorVersion = %d;', [FLibName, FMajor]));
    Consts.Add(Format('  %sMinorVersion = %d;', [FLibName, FMinor]));
    Consts.Add('');
    Consts.Add(Format('  LIBID_%s: TGUID = ''%s'';', [FLibName, GuidText(FGuid)]));
    Consts.Add('');
    for I := 0 to N - 1 do
    begin
      TI := TypeInfoAt(I);
      Kind := TypeKindOf(TI, F);
      if (Kind = TKIND_INTERFACE) or (Kind = TKIND_DISPATCH) and (F and TYPEFLAG_FDUAL <> 0) then
        Consts.Add(Format('  %s: TGUID = ''%s'';', [Unique('IID_' + FNames[I]), GuidText(GuidOf(TI))]))
      else if Kind = TKIND_DISPATCH then
        Consts.Add(Format('  %s: TGUID = ''%s'';', [Unique('DIID_' + FNames[I]), GuidText(GuidOf(TI))]))
      else if Kind = TKIND_COCLASS then
        Consts.Add(Format('  %s: TGUID = ''%s'';', [Unique('CLASS_' + FNames[I]), GuidText(GuidOf(TI))]));
    end;
    { enumerations, module constants }
    for I := 0 to N - 1 do
      case KindAt(I) of
        TKIND_ENUM: AddEnum(I, Enums);
        TKIND_MODULE: AddModule(I, Enums);
      end;
    { forward declarations; CoClasses as their default interface, with a creator }
    for I := 0 to N - 1 do
    begin
      Kind := TypeKindOf(TypeInfoAt(I), F);
      if Kind = TKIND_INTERFACE then Fwd.Add('  ' + FNames[I] + ' = interface;')
      else if Kind = TKIND_DISPATCH then
        if F and TYPEFLAG_FDUAL <> 0 then
        begin
          Fwd.Add('  ' + FNames[I] + ' = interface;');
          Fwd.Add('  ' + FDispNames[I] + ' = dispinterface;');
        end
        else
          Fwd.Add('  ' + FNames[I] + ' = dispinterface;');
    end;
    for I := 0 to N - 1 do
    begin
      if KindAt(I) <> TKIND_COCLASS then Continue;
      TI := TypeInfoAt(I);
      Done[I] := True;
      if DefaultIntf(TI, False, DefName) = nil then DefName := 'IUnknown';
      CoAlias.Add('  ' + FNames[I] + ' = ' + DefName + ';');
      TypeKindOf(TI, F);
      if (F and TYPEFLAG_FCANCREATE = 0) or (DefName = 'IUnknown') then Continue;
      S := Unique('Co' + FNames[I]);
      Creators.Add('// *********************************************************************//');
      Creators.Add('// The Class ' + S + ' provides a Create and CreateRemote method to');
      Creators.Add('// create instances of the default interface ' + DefName + ' exposed by');
      Creators.Add('// the CoClass ' + FNames[I] + '.');
      Creators.Add('// *********************************************************************//');
      Creators.Add('  ' + S + ' = class');
      Creators.Add('    class function Create: ' + DefName + ';');
      Creators.Add('    class function CreateRemote(const MachineName: string): ' + DefName + ';');
      Creators.Add('  end;');
      Creators.Add('');
      CoImpl.Add(Format('class function %s.Create: %s;', [S, DefName]));
      CoImpl.Add('begin');
      CoImpl.Add(Format('  Result := CreateComObject(CLASS_%s) as %s;', [FNames[I], DefName]));
      CoImpl.Add('end;');
      CoImpl.Add('');
      CoImpl.Add(Format('class function %s.CreateRemote(const MachineName: string): %s;', [S, DefName]));
      CoImpl.Add('begin');
      CoImpl.Add(Format('  Result := CreateRemoteComObject(MachineName, CLASS_%s) as %s;', [FNames[I], DefName]));
      CoImpl.Add('end;');
      CoImpl.Add('');
    end;
    { records, unions and aliases, each after those it holds }
    repeat
      Progress := False;
      for I := 0 to N - 1 do
        if not Done[I] and (KindAt(I) in [TKIND_RECORD, TKIND_UNION, TKIND_ALIAS]) and Ready(I) then
        begin
          if KindAt(I) = TKIND_ALIAS then AddAlias(I, Recs) else AddRecord(I, Recs);
          Done[I] := True;
          Progress := True;
        end;
    until not Progress;
    for I := 0 to N - 1 do
      if not Done[I] and (KindAt(I) in [TKIND_RECORD, TKIND_UNION, TKIND_ALIAS]) then
      begin
        if KindAt(I) = TKIND_ALIAS then AddAlias(I, Recs) else AddRecord(I, Recs);
        Done[I] := True;
      end;
    { interfaces, each after its ancestor }
    repeat
      Progress := False;
      for I := 0 to N - 1 do
        if not Done[I] and (KindAt(I) in [TKIND_INTERFACE, TKIND_DISPATCH]) and IntfReady(I) then
        begin
          AddIntfOf(I, Intfs);
          Done[I] := True;
          Progress := True;
        end;
    until not Progress;
    for I := 0 to N - 1 do
      if not Done[I] and (KindAt(I) in [TKIND_INTERFACE, TKIND_DISPATCH]) then
      begin
        AddIntfOf(I, Intfs);
        Done[I] := True;
      end;
    { the wrappers: the controls', then the servers' }
    for Pass := 0 to 1 do
      for I := 0 to N - 1 do
        if WantsWrapper(I, Control) and (Control = (Pass = 0)) then
          if Control then AddWrapper(I, Wrappers, WImpl, Reg, True)
          else AddWrapper(I, Wrappers, WImpl, RegServers, False);
    { the unit }
    Dst.Add('unit ' + FUnit + ';');
    Dst.Add('');
    Dst.Add('// ************************************************************************ //');
    Dst.Add('// WARNING');
    Dst.Add('// -------');
    Dst.Add('// The types declared in this file were generated from data read from a');
    Dst.Add('// Type Library. If this type library is explicitly or indirectly (via');
    Dst.Add('// another type library referring to this type library) re-imported, the');
    Dst.Add('// contents of this file will be regenerated and all manual modifications');
    Dst.Add('// will be lost.');
    Dst.Add('// ************************************************************************ //');
    Dst.Add('');
    Dst.Add('// Generated by D7 Studio from the Type Library described below.');
    Dst.Add('');
    Dst.Add('// ************************************************************************ //');
    Dst.Add('// Type Lib: ' + FFile);
    Dst.Add('// LIBID: ' + GuidText(FGuid));
    Dst.Add('// HelpString: ' + FHelp);
    if FDeps.Count > 0 then Dst.Add('// DepndLst: ' + Joined(FDeps));
    Dst.Add('// ************************************************************************ //');
    Dst.Add('{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers.');
    Dst.Add('{$WARN SYMBOL_PLATFORM OFF}');
    Dst.Add('{$WRITEABLECONST ON}');
    Dst.Add('{$VARPROPSETTER ON}');
    Dst.Add('interface');
    Dst.Add('');
    S := 'uses Windows, ActiveX, Classes, Graphics, Variants';
    if Reg.Count > 0 then S := S + ', OleCtrls';
    if RegServers.Count > 0 then S := S + ', OleServer';
    for I := 0 to FDeps.Count - 1 do S := S + ', ' + FDeps[I];
    Dst.Add(S + ';');
    Dst.Add('');
    Dst.Add('// *********************************************************************//');
    Dst.Add('// GUIDS declared in the TypeLibrary. Following prefixes are used:');
    Dst.Add('//   Type Libraries     : LIBID_xxxx');
    Dst.Add('//   CoClasses          : CLASS_xxxx');
    Dst.Add('//   DISPInterfaces     : DIID_xxxx');
    Dst.Add('//   Non-DISP interfaces: IID_xxxx');
    Dst.Add('// *********************************************************************//');
    Dst.Add('const');
    Dst.AddStrings(Consts);
    Dst.Add('');
    if Enums.Count > 0 then
    begin
      Dst.Add('// *********************************************************************//');
      Dst.Add('// Declaration of Enumerations defined in Type Library');
      Dst.Add('// *********************************************************************//');
      Dst.AddStrings(Enums);
    end;
    if Fwd.Count + CoAlias.Count + Recs.Count + Intfs.Count + Creators.Count + Wrappers.Count > 0 then
    begin
      Dst.Add('type');
      Dst.Add('');
    end;
    if Fwd.Count > 0 then
    begin
      Dst.Add('// *********************************************************************//');
      Dst.Add('// Forward declaration of types defined in TypeLibrary');
      Dst.Add('// *********************************************************************//');
      Dst.AddStrings(Fwd);
      Dst.Add('');
    end;
    if CoAlias.Count > 0 then
    begin
      Dst.Add('// *********************************************************************//');
      Dst.Add('// Declaration of CoClasses defined in Type Library');
      Dst.Add('// (NOTE: Here we map each CoClass to its Default Interface)');
      Dst.Add('// *********************************************************************//');
      Dst.AddStrings(CoAlias);
      Dst.Add('');
    end;
    if Recs.Count > 0 then
    begin
      Dst.Add('// *********************************************************************//');
      Dst.Add('// Declaration of structures, unions and aliases.');
      Dst.Add('// *********************************************************************//');
      Dst.AddStrings(Recs);
      Dst.Add('');
    end;
    Dst.AddStrings(Intfs);
    Dst.AddStrings(Creators);
    Dst.AddStrings(Wrappers);
    if Reg.Count + RegServers.Count > 0 then
    begin
      Dst.Add('procedure Register;');
      Dst.Add('');
      Dst.Add('resourcestring');
      { the page as the user typed it: a quote in it stays inside the literal }
      Dst.Add('  dtlServerPage = ' + QuotedStr(FImp.FOptions.PalettePage) + ';');
      Dst.Add('  dtlOcxPage = ' + QuotedStr(FImp.FOptions.PalettePage) + ';');
      Dst.Add('');
    end;
    Dst.Add('implementation');
    Dst.Add('');
    Dst.Add('uses ComObj;');
    Dst.Add('');
    Dst.AddStrings(CoImpl);
    Dst.AddStrings(WImpl);
    if Reg.Count + RegServers.Count > 0 then
    begin
      Dst.Add('procedure Register;');
      Dst.Add('begin');
      if Reg.Count > 0 then Dst.Add('  RegisterComponents(dtlOcxPage, [' + Joined(Reg) + ']);');
      if RegServers.Count > 0 then Dst.Add('  RegisterComponents(dtlServerPage, [' + Joined(RegServers) + ']);');
      Dst.Add('end;');
      Dst.Add('');
    end;
    Dst.Add('end.');
    Dst.Text := Dst.Text;     // the lines with line breaks of their own (event dispids) split
    WrapLong(Dst);
    FSource := Dst.Text;
  finally
    RegServers.Free;
    Reg.Free;
    WImpl.Free;
    Wrappers.Free;
    CoImpl.Free;
    Creators.Free;
    Intfs.Free;
    Recs.Free;
    CoAlias.Free;
    Fwd.Free;
    Enums.Free;
    Consts.Free;
    Dst.Free;
  end;
end;

{ one type as the unit declares it }
function TTLBWriter.TypeText(Index: Integer): string;
var
  L: TStringList;
  Def: string;
begin
  L := TStringList.Create;
  try
    case KindAt(Index) of
      TKIND_ENUM: AddEnum(Index, L);
      TKIND_MODULE: AddModule(Index, L);
      TKIND_RECORD, TKIND_UNION: AddRecord(Index, L);
      TKIND_ALIAS: AddAlias(Index, L);
      TKIND_INTERFACE, TKIND_DISPATCH: AddIntfOf(Index, L);
      TKIND_COCLASS:
        begin
          if DefaultIntf(TypeInfoAt(Index), False, Def) = nil then Def := 'IUnknown';
          L.Add('  ' + FNames[Index] + ' = ' + Def + ';');
          L.Add('  CLASS_' + FNames[Index] + ': TGUID = ''' + GuidText(GuidOf(TypeInfoAt(Index))) + ''';');
        end;
    end;
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- TTLBImport }

constructor TTLBImport.Create(const AOptions: TTLBOptions);
begin
  inherited Create;
  FOptions := AOptions;
  if FOptions.PalettePage = '' then FOptions.PalettePage := 'ActiveX';
  FWriters := TList.Create;
end;

destructor TTLBImport.Destroy;
var
  I: Integer;
begin
  for I := 0 to FWriters.Count - 1 do TObject(FWriters[I]).Free;
  FWriters.Free;
  inherited Destroy;
end;

{ the writer of a library (one per library: made, and its types named, the first time) }
function TTLBImport.WriterOf(TL: ITypeLib): TObject;
var
  I: Integer;
  A: PTLibAttr;
  G: TGUID;
begin
  FillChar(G, SizeOf(G), 0);
  if Succeeded(TL.GetLibAttr(A)) then
  begin
    G := A.guid;
    TL.ReleaseTLibAttr(A);
  end;
  for I := 0 to FWriters.Count - 1 do
  begin
    Result := TObject(FWriters[I]);
    if IsEqualGUID(TTLBWriter(Result).FGuid, G) then Exit;
  end;
  Result := TTLBWriter.Create(Self, TL);
  FWriters.Add(Result);
end;

function TTLBImport.Import(TL: ITypeLib): string;
var
  I: Integer;
begin
  Result := TTLBWriter(WriterOf(TL)).FUnit;
  { writing one can bring others along: until all are written }
  I := 0;
  while I < FWriters.Count do
  begin
    TTLBWriter(FWriters[I]).Write;
    Inc(I);
  end;
end;

function TTLBImport.Count: Integer;
begin
  Result := FWriters.Count;
end;

function TTLBImport.UnitName(I: Integer): string;
begin
  Result := TTLBWriter(FWriters[I]).FUnit;
end;

function TTLBImport.Source(I: Integer): string;
begin
  Result := TTLBWriter(FWriters[I]).FSource;
end;

{ The writer names every type of its library once, when it is made. A type's text takes names of
  its own besides (Unique: the constants of an enumeration or a module): they are taken out of
  FUsed again, so that each text is the one a writer of its own gives - whatever was asked for
  before. Nothing else of a writer changes with a type's text but the units it depends on, which
  only its unit (Write) names. }
function TTLBImport.TypeText(TL: ITypeLib; Index: Integer): string;
var
  W: TTLBWriter;
  I, K: Integer;
begin
  W := TTLBWriter(WriterOf(TL));
  W.FAdded := TStringList.Create;
  try
    Result := W.TypeText(Index);
  finally
    for I := 0 to W.FAdded.Count - 1 do
      if W.FUsed.Find(W.FAdded[I], K) then W.FUsed.Delete(K);
    FreeAndNil(W.FAdded);
  end;
end;

function TypeLibWrapperNames(TL: ITypeLib; const Options: TTLBOptions): string;
var
  Imp: TTLBImport;
begin
  Imp := TTLBImport.Create(Options);
  try
    Result := TTLBWriter(Imp.WriterOf(TL)).WrapperNames;
  finally
    Imp.Free;
  end;
end;

function TypeLibTypeText(TL: ITypeLib; Index: Integer): string;
var
  Imp: TTLBImport;
begin
  Imp := TypeLibTextImport;
  try
    Result := TTLBWriter(Imp.WriterOf(TL)).TypeText(Index);
  finally
    Imp.Free;
  end;
end;

function TypeLibTextImport: TTLBImport;
var
  O: TTLBOptions;
begin
  FillChar(O, SizeOf(O), 0);
  O.Safecall := 1;            // as the library's own text and the import's default: the same declarations
  Result := TTLBImport.Create(O);
end;

end.
