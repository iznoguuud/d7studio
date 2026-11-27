{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMacros;

{ D7 Studio - the macro library: keystroke macros (SdOtaRecord's records) kept by name, in the
  order the Macro Library view shows them. A recording of the IDE's macro that ends with keys is
  added at the top; the current one is the macro Shift+Ctrl+P plays.

  * The settings ([Macros] of D7Studio.ini) and macro files (*.d7macros) hold them in one format:
    Count, then NameN and KeysN for each (1 based) - KeysN the record in the Open Tools API's stream
    format (IOTARecord.WriteToStream: 'TPOR', the items, 0) as hexadecimal digits -, and in the
    settings Current, the index of the current macro (-1 none), Times and ToEnd, what Play Macro
    Repeatedly was last asked. A macro whose keys do not read is left out.
  * MacroText: what a macro does, for the view - typed text in quotes, keys by their names (Ctrl+C,
    Enter), commands by their names in brackets. }

interface

uses
  SysUtils, Classes, IniFiles, ActiveX, Menus, ToolsAPI, SdOtaRecord;

const
  MacroSection = 'Macros';            // the section of D7Studio.ini and of a macro file
  MacroFileExt = '.d7macros';
  MacroFileFilter = 'D7 Studio macros (*.d7macros)|*.d7macros|Any file (*.*)|*.*';

type
  TSdMacro = class
  private
    FName: string;
    FRec: IOTARecord;
    function GetItems: TSdOtaRecord;
  public
    constructor Create(const AName: string);
    property Name: string read FName write FName;
    property Rec: IOTARecord read FRec;              // the macro's own record
    property Items: TSdOtaRecord read GetItems;
  end;

  TSdMacroLibrary = class
  private
    FList: TList;
    FCurrent, FTimes: Integer;
    FToEnd: Boolean;
    function GetMacro(Index: Integer): TSdMacro;
    { the macros of Ini's [Macros] added at the end, those whose keys do not read left out; the one
      of index Cur (0 based, -1 none) becomes the current one: their number }
    function ReadMacros(Ini: TCustomIniFile; Cur: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    function IndexOf(M: TSdMacro): Integer;
    { the current macro (nil: none) }
    function CurrentMacro: TSdMacro;
    { a copy of Rec's items under Name (made unique) at Index (clipped); its index }
    function Add(const Name: string; const Rec: IOTARecord; Index: Integer): Integer;
    procedure Delete(Index: Integer);
    procedure Move(Index, NewIndex: Integer);
    { 'Macro N', N one more than the highest such name }
    function NewName: string;
    { Name, or Name (2), (3) ... when another macro (not Other) has it }
    function UniqueName(const Name: string; Other: TSdMacro = nil): string;
    { the settings: the macros and the current one, those there before dropped }
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
    { a macro file: its macros added at the end (their number) / Macros (TSdMacro) written to it }
    function ImportFile(const FileName: string): Integer;
    procedure ExportFile(const FileName: string; Macros: TList);
    property Macros[Index: Integer]: TSdMacro read GetMacro; default;
    property Current: Integer read FCurrent write FCurrent;
    { Play Macro Repeatedly: the number of times, until the end of the file }
    property Times: Integer read FTimes write FTimes;
    property ToEnd: Boolean read FToEnd write FToEnd;
  end;

{ what a record does, in one line of at most MaxLen characters }
function MacroText(R: TSdOtaRecord; MaxLen: Integer = 200): string;

implementation

{ ---------------------------------------------------------------- TSdMacro }

constructor TSdMacro.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FRec := TSdOtaRecord.Create;
end;

function TSdMacro.GetItems: TSdOtaRecord;
begin
  Result := OwnRecord(FRec);
end;

{ ---------------------------------------------------------------- the format }

{ the adapter is held by a variable: an object made in the call and passed as a const interface
  would never be released }
function RecordToHex(R: IOTARecord): string;
var
  M: TMemoryStream;
  S: IStream;
begin
  M := TMemoryStream.Create;
  try
    S := TStreamAdapter.Create(M, soReference);
    R.WriteToStream(S);
    S := nil;
    SetLength(Result, M.Size * 2);
    if M.Size > 0 then BinToHex(PChar(M.Memory), PChar(Result), M.Size);
  finally
    M.Free;
  end;
end;

{ False: not an even number of hexadecimal digits, or not a record }
function HexToRecord(const Hex: string; R: IOTARecord): Boolean;
var
  M: TMemoryStream;
  S: IStream;
  N: Integer;
begin
  Result := False;
  if (Hex = '') or Odd(Length(Hex)) then Exit;
  M := TMemoryStream.Create;
  try
    M.Size := Length(Hex) div 2;
    N := HexToBin(PChar(Hex), PChar(M.Memory), M.Size);
    if N <> M.Size then Exit;
    S := TStreamAdapter.Create(M, soReference);
    try
      R.ReadFromStream(S);
      Result := True;
    except
      on Exception do R.Clear;
    end;
    S := nil;
  finally
    M.Free;
  end;
end;

function MacroText(R: TSdOtaRecord; MaxLen: Integer): string;
var
  I: Integer;
  It: TSdMacroItem;
  Typed: string;

  procedure Put(const S: string);
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + S;
  end;

  procedure EndTyped;
  begin
    if Typed <> '' then Put('"' + Typed + '"');
    Typed := '';
  end;

begin
  Result := '';
  Typed := '';
  if R = nil then Exit;
  for I := 0 to R.Count - 1 do
  begin
    It := R.Items[I];
    if It.IsCommand then
    begin
      EndTyped;
      Put('[' + It.Command + ']');
    end
    { a typed character: no flags in the high word, not a control character }
    else if (It.Code and Integer($FFFF0000) = 0) and (It.Code and $FF >= 32) then
      Typed := Typed + Char(It.Code and $FF)
    else
    begin
      EndTyped;
      Put(ShortCutToText(KeyCodeToShortCut(It.Code)));
    end;
    if Length(Result) + Length(Typed) > MaxLen then Break;
  end;
  EndTyped;
  if Length(Result) > MaxLen then Result := Copy(Result, 1, MaxLen - 3) + '...';
end;

{ ---------------------------------------------------------------- TSdMacroLibrary }

constructor TSdMacroLibrary.Create;
begin
  inherited Create;
  FList := TList.Create;
  FCurrent := -1;
  FTimes := 1;
end;

destructor TSdMacroLibrary.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TSdMacroLibrary.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do TSdMacro(FList[I]).Free;
  FList.Clear;
  FCurrent := -1;
end;

function TSdMacroLibrary.Count: Integer;
begin
  Result := FList.Count;
end;

function TSdMacroLibrary.GetMacro(Index: Integer): TSdMacro;
begin
  Result := TSdMacro(FList[Index]);
end;

function TSdMacroLibrary.IndexOf(M: TSdMacro): Integer;
begin
  Result := FList.IndexOf(M);
end;

{ the current macro (nil: none): Add, Delete and Move keep it by itself, not by its index }
function TSdMacroLibrary.CurrentMacro: TSdMacro;
begin
  if FCurrent >= 0 then Result := Macros[FCurrent] else Result := nil;
end;

function TSdMacroLibrary.Add(const Name: string; const Rec: IOTARecord; Index: Integer): Integer;
var
  M, Cur: TSdMacro;
begin
  M := TSdMacro.Create(UniqueName(Name));
  M.Rec.Append(Rec);
  if Index < 0 then Index := 0;
  if Index > FList.Count then Index := FList.Count;
  Cur := CurrentMacro;
  FList.Insert(Index, M);
  FCurrent := FList.IndexOf(Cur);
  Result := Index;
end;

procedure TSdMacroLibrary.Delete(Index: Integer);
var
  Cur: TSdMacro;
begin
  Cur := CurrentMacro;
  if Index = FCurrent then Cur := nil;
  Macros[Index].Free;
  FList.Delete(Index);
  FCurrent := FList.IndexOf(Cur);
end;

procedure TSdMacroLibrary.Move(Index, NewIndex: Integer);
var
  Cur: TSdMacro;
begin
  Cur := CurrentMacro;
  FList.Move(Index, NewIndex);
  FCurrent := FList.IndexOf(Cur);
end;

function TSdMacroLibrary.NewName: string;
const
  Base = 'Macro ';
var
  I, N, Top: Integer;
begin
  Top := 0;
  for I := 0 to FList.Count - 1 do
    if SameText(Copy(Macros[I].Name, 1, Length(Base)), Base) then
    begin
      N := StrToIntDef(Copy(Macros[I].Name, Length(Base) + 1, MaxInt), 0);
      if N > Top then Top := N;
    end;
  Result := Base + IntToStr(Top + 1);
end;

function TSdMacroLibrary.UniqueName(const Name: string; Other: TSdMacro): string;

  function Taken(const S: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to FList.Count - 1 do
      if (Macros[I] <> Other) and SameText(Macros[I].Name, S) then
      begin
        Result := True;
        Exit;
      end;
  end;

var
  Base: string;
  N: Integer;
begin
  Base := Trim(Name);
  if Base = '' then Base := NewName;
  Result := Base;
  N := 1;
  while Taken(Result) do
  begin
    Inc(N);
    Result := Format('%s (%d)', [Base, N]);
  end;
end;

function TSdMacroLibrary.ReadMacros(Ini: TCustomIniFile; Cur: Integer): Integer;
var
  I: Integer;
  M: TSdMacro;
begin
  Result := 0;
  for I := 1 to Ini.ReadInteger(MacroSection, 'Count', 0) do
  begin
    M := TSdMacro.Create('');
    if not HexToRecord(Ini.ReadString(MacroSection, 'Keys' + IntToStr(I), ''), M.Rec) or (M.Items.Count = 0) then
    begin
      M.Free;
      Continue;
    end;
    M.Name := UniqueName(Ini.ReadString(MacroSection, 'Name' + IntToStr(I), ''));
    if I - 1 = Cur then FCurrent := FList.Count;
    FList.Add(M);
    Inc(Result);
  end;
end;

procedure TSdMacroLibrary.Load(Ini: TCustomIniFile);
begin
  Clear;
  FTimes := Ini.ReadInteger(MacroSection, 'Times', 1);
  FToEnd := Ini.ReadBool(MacroSection, 'ToEnd', False);
  ReadMacros(Ini, Ini.ReadInteger(MacroSection, 'Current', -1));
end;

procedure WriteMacros(Ini: TCustomIniFile; Macros: TList);
var
  I: Integer;
begin
  Ini.EraseSection(MacroSection);
  Ini.WriteInteger(MacroSection, 'Count', Macros.Count);
  for I := 0 to Macros.Count - 1 do
  begin
    Ini.WriteString(MacroSection, 'Name' + IntToStr(I + 1), TSdMacro(Macros[I]).Name);
    Ini.WriteString(MacroSection, 'Keys' + IntToStr(I + 1), RecordToHex(TSdMacro(Macros[I]).Rec));
  end;
end;

procedure TSdMacroLibrary.Save(Ini: TCustomIniFile);
begin
  WriteMacros(Ini, FList);
  Ini.WriteInteger(MacroSection, 'Current', FCurrent);
  Ini.WriteInteger(MacroSection, 'Times', FTimes);
  Ini.WriteBool(MacroSection, 'ToEnd', FToEnd);
end;

function TSdMacroLibrary.ImportFile(const FileName: string): Integer;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FileName);
  try
    Result := ReadMacros(Ini, -1);
  finally
    Ini.Free;
  end;
end;

procedure TSdMacroLibrary.ExportFile(const FileName: string; Macros: TList);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create('');
  try
    WriteMacros(Ini, Macros);
    Ini.Rename(FileName, False);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
