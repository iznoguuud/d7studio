{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSettings;

{ D7 Studio - persistent settings (D7Studio.ini in the folder of D7Studio.exe). }

interface

uses
  Types, SysUtils, Classes, Graphics, IniFiles, SdEncoding;

type
  { The values of one kind of options, under Delphi 7's value names (migrate.exe copies Delphi 7's
    into the settings when D7 Studio is installed): a section of the settings, else the default
    the caller gives. Delphi writes every value as a string ("True", "80", "clGray"). }
  TDelphiValues = class
  private
    FIni: TCustomIniFile;
    FSection: string;
  public
    constructor Create(Ini: TCustomIniFile; const Section: string);
    function ReadString(const Name, Default: string): string;
    function ReadBool(const Name: string; Default: Boolean): Boolean;    // True, Yes, 1
    function ReadInteger(const Name: string; Default: Integer): Integer;
    function ReadColor(const Name: string; Default: TColor): TColor;
  end;

  { how a value of an options record is kept: okBool as True / False (Delphi's values), okFlag as
    1 / 0 (TCustomIniFile.WriteBool), okInt a number, okStr text, okColor a colour's name or number }
  TSdOptionKind = (okBool, okFlag, okInt, okStr, okColor);

  { a value of an options record under its key - one table for reading and for writing, so each
    key is written once (OptBool ...: Value is the record's field). Source: which TDelphiValues
    of ReadOptions reads it; another number (-1) or none given: the ini file alone }
  TSdOption = record
    Key: string;
    Kind: TSdOptionKind;
    Value: Pointer;
    Source: Integer;
  end;
  TSdOptions = array of TSdOption;

var
  Settings: TMemIniFile;

function OptBool(const Key: string; var Value: Boolean; Source: Integer = 0): TSdOption;
function OptFlag(const Key: string; var Value: Boolean; Source: Integer = 0): TSdOption;
function OptInt(const Key: string; var Value: Integer; Source: Integer = 0): TSdOption;
function OptStr(const Key: string; var Value: string; Source: Integer = 0): TSdOption;
function OptColor(const Key: string; var Value: TColor; Source: Integer = 0): TSdOption;
procedure AddOptions(var Table: TSdOptions; const Items: array of TSdOption);
{ each value of Table read: by its Source (a TDelphiValues: True, Yes or 1 for a flag), or from
  Section of Ini alone; a value that is not there keeps the one the field has - its default }
procedure ReadOptions(const Table: TSdOptions; Ini: TCustomIniFile; const Section: string;
  const Sources: array of TDelphiValues);
{ ... written into Section of Ini, in the table's order }
procedure WriteOptions(const Table: TSdOptions; Ini: TCustomIniFile; const Section: string);

procedure LoadSettings;
{ Writes what this instance changed into the settings file (see the implementation). Quiet: a
  failure is logged in error.log and gives False - SettingsSaveError says why; the settings stay
  in memory, and the next save tries again. A command of the user that saves reports False. }
function SaveSettings: Boolean;
function SettingsSaveError: string;
{ an ini file in memory written to its file whole and safely (SdFileNames.WriteFileU: the old file
  stays as it was when the write fails); raises EInOutError with the file's name and the reason }
procedure WriteIniFile(Ini: TMemIniFile);
{ an ini file that Delphi 7 reads too (a project's .dof, the default project options, Delphi's
  .dro): read as SdEncoding.SystemFileToIde, written as IdeToSystemFile - safely, as WriteIniFile }
function OpenSystemIniFile(const FileName: string): TMemIniFile;
procedure WriteSystemIniFile(Ini: TMemIniFile);
{ the folder of D7 Studio's settings and its other files of the user (D7Studio.ini, error.log,
  D7Studio.dof, the repository and templates ...), with a trailing backslash: the folder of
  D7Studio.exe - each copy has its own (also one copied into Delphi's Bin: its two files whose
  names Delphi's Bin has as well are D7Studio.dof and D7Studio.msginfo.ini, SdProject /
  SdMsgInfo - Delphi's own are never written); D7S_HOME names another one (the tests) }
function SettingsDir: string;
{ D7 Studio's own registry key (HKEY_CURRENT_USER, no leading backslash): Software\D7Studio, for
  the test instance (D7S_HOME) Software\D7Studio\Test. Borland's design-time windows keep their
  settings in it (BaseRegistryKey). }
function SettingsRegKey: string;
{ the main window's place when it is not maximized ([Layout] Left, Top, Width, Height): where
  it opens, and the monitor of the start-up screen }
function MainWindowRect: TRect;
procedure AddRecent(const Section, FileName: string);
procedure GetRecent(const Section: string; List: TStrings);
{ Delphi's history lists of the option combo boxes: section "HistoryLists\<Name>" with Count and
  Item0.. (newest first) - in the project's .dof or in D7 Studio's settings }
procedure LoadHistory(Ini: TCustomIniFile; const Name: string; Items: TStrings);
procedure AddHistory(Ini: TCustomIniFile; const Name, Value: string);
{ ... a whole list written (newest first) }
procedure SaveHistory(Ini: TCustomIniFile; const Name: string; Items: TStrings);
{ Value as the newest entry of a list of recent values: once (case does not count), at most
  MaxCount entries; an empty Value changes nothing }
procedure PushHistory(Items: TStrings; const Value: string; MaxCount: Integer = 20);
{ a colour written as text (clWindow, $00FF0000, a number); Default when the text is none - a
  damaged value of the settings must not stop the start }
function ColorFromText(const S: string; Default: TColor): TColor;
{ The encoding of a file that is not open: the one remembered for it in [Encodings] - the user's
  choice (Reopen with Encoding, Convert to Encoding) -, else the one its bytes tell
  (DetectEncoding). Text below is editor text. }
function FileEncoding(const FileName, Bytes: string): TSdEncoding;
function RememberedEncoding(const FileName: string; var E: TSdEncoding): Boolean;
procedure RememberFileEncoding(const FileName: string; const E: TSdEncoding);
{ the design packages of Ini's [Design Packages], in its order: "file=description", the file's
  $(DELPHI) expanded, a leading '-' when it is disabled; False when Ini has no such list (D7 Studio
  then starts with Borland's standard packages) }
function SettingsPackages(Ini: TCustomIniFile; Names: TStrings): Boolean;
{ the experts' DLLs, as Delphi 7 reads them - Wizards, then Experts (any value name, the file as
  its value; each DLL may have either entry point): the registry key RegKey in Delphi's layout
  (SettingsRegKey), and the sections [Wizards] and [Experts] of Ini (name=file; nil: none);
  $(DELPHI) expanded, each file once }
procedure ExpertFiles(Ini: TCustomIniFile; const RegKey: string; Files: TStrings);

implementation

uses
  Windows, Registry, SdFileNames, SdCrashLog, SdDelphiDir;

const
  EncodingSection = 'Encodings';   // <file name, lower case>=<encoding> chosen by the user (EncodingKey)

{ ---------------------------------------------------------------- TDelphiValues }

constructor TDelphiValues.Create(Ini: TCustomIniFile; const Section: string);
begin
  inherited Create;
  FIni := Ini;
  FSection := Section;
end;

{ a key that is there answers its value, also an empty one }
function TDelphiValues.ReadString(const Name, Default: string): string;
begin
  if FIni <> nil then Result := FIni.ReadString(FSection, Name, Default) else Result := Default;
end;

function TDelphiValues.ReadBool(const Name: string; Default: Boolean): Boolean;
var
  T: string;
begin
  T := ReadString(Name, '');
  if T = '' then Result := Default
  else Result := SameText(T, 'True') or SameText(T, 'Yes') or (T = '1');
end;

function TDelphiValues.ReadInteger(const Name: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(ReadString(Name, ''), Default);
end;

function TDelphiValues.ReadColor(const Name: string; Default: TColor): TColor;
var
  T: string;
begin
  T := ReadString(Name, '');
  Result := ColorFromText(T, Default);
end;

{ ---------------------------------------------------------------- option tables }

function NewOption(const Key: string; Kind: TSdOptionKind; Value: Pointer; Source: Integer): TSdOption;
begin
  Result.Key := Key;
  Result.Kind := Kind;
  Result.Value := Value;
  Result.Source := Source;
end;

function OptBool(const Key: string; var Value: Boolean; Source: Integer): TSdOption;
begin
  Result := NewOption(Key, okBool, @Value, Source);
end;

function OptFlag(const Key: string; var Value: Boolean; Source: Integer): TSdOption;
begin
  Result := NewOption(Key, okFlag, @Value, Source);
end;

function OptInt(const Key: string; var Value: Integer; Source: Integer): TSdOption;
begin
  Result := NewOption(Key, okInt, @Value, Source);
end;

function OptStr(const Key: string; var Value: string; Source: Integer): TSdOption;
begin
  Result := NewOption(Key, okStr, @Value, Source);
end;

function OptColor(const Key: string; var Value: TColor; Source: Integer): TSdOption;
begin
  Result := NewOption(Key, okColor, @Value, Source);
end;

procedure AddOptions(var Table: TSdOptions; const Items: array of TSdOption);
var
  I, N: Integer;
begin
  N := Length(Table);
  SetLength(Table, N + Length(Items));
  for I := 0 to High(Items) do Table[N + I] := Items[I];
end;

procedure ReadOptions(const Table: TSdOptions; Ini: TCustomIniFile; const Section: string;
  const Sources: array of TDelphiValues);
var
  I: Integer;
  S: TDelphiValues;
  T: string;
begin
  for I := 0 to High(Table) do
    with Table[I] do
    begin
      if (Source >= 0) and (Source <= High(Sources)) then S := Sources[Source] else S := nil;
      if S <> nil then
        case Kind of
          okBool, okFlag: PBoolean(Value)^ := S.ReadBool(Key, PBoolean(Value)^);
          okInt: PInteger(Value)^ := S.ReadInteger(Key, PInteger(Value)^);
          okStr: PString(Value)^ := S.ReadString(Key, PString(Value)^);
          okColor: PColor(Value)^ := S.ReadColor(Key, PColor(Value)^);
        end
      else
        case Kind of
          okBool:
            begin
              T := Ini.ReadString(Section, Key, '');
              if T <> '' then PBoolean(Value)^ := SameText(T, 'True') or SameText(T, 'Yes') or (T = '1');
            end;
          okFlag: PBoolean(Value)^ := Ini.ReadBool(Section, Key, PBoolean(Value)^);
          okInt: PInteger(Value)^ := Ini.ReadInteger(Section, Key, PInteger(Value)^);
          okStr: PString(Value)^ := Ini.ReadString(Section, Key, PString(Value)^);
          okColor: PColor(Value)^ := ColorFromText(Ini.ReadString(Section, Key, ''), PColor(Value)^);
        end;
    end;
end;

procedure WriteOptions(const Table: TSdOptions; Ini: TCustomIniFile; const Section: string);
const
  BoolTexts: array[Boolean] of string = ('False', 'True');
var
  I: Integer;
begin
  for I := 0 to High(Table) do
    with Table[I] do
      case Kind of
        okBool: Ini.WriteString(Section, Key, BoolTexts[PBoolean(Value)^]);
        okFlag: Ini.WriteBool(Section, Key, PBoolean(Value)^);
        okInt: Ini.WriteInteger(Section, Key, PInteger(Value)^);
        okStr: Ini.WriteString(Section, Key, PString(Value)^);
        okColor: Ini.WriteString(Section, Key, ColorToString(PColor(Value)^));
      end;
end;

procedure WriteIniFile(Ini: TMemIniFile);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    Ini.GetStrings(L);
    WriteFileU(Ini.FileName, L.Text);
  finally
    L.Free;
  end;
end;

function OpenSystemIniFile(const FileName: string): TMemIniFile;
var
  L: TStringList;
begin
  Result := TMemIniFile.Create('');
  Result.Rename(FileName, False);
  if not FileExistsU(FileName) then Exit;
  L := TStringList.Create;
  try
    L.Text := SystemFileToIde(ReadFileU(FileName));
    Result.SetStrings(L);
  finally
    L.Free;
  end;
end;

procedure WriteSystemIniFile(Ini: TMemIniFile);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    Ini.GetStrings(L);
    WriteFileU(Ini.FileName, IdeToSystemFile(L.Text));
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- the settings }

function ColorFromText(const S: string; Default: TColor): TColor;
begin
  Result := Default;
  if Trim(S) <> '' then
    try
      Result := StringToColor(Trim(S));
    except
      Result := Default;
    end;
end;

procedure PushHistory(Items: TStrings; const Value: string; MaxCount: Integer = 20);
var
  I: Integer;
begin
  if Trim(Value) = '' then Exit;
  for I := Items.Count - 1 downto 0 do
    if SameText(Items[I], Value) then Items.Delete(I);
  Items.Insert(0, Value);
  while Items.Count > MaxCount do Items.Delete(Items.Count - 1);
end;

procedure LoadHistory(Ini: TCustomIniFile; const Name: string; Items: TStrings);
var
  I, N: Integer;
begin
  Items.Clear;
  if Ini = nil then Exit;
  N := Ini.ReadInteger('HistoryLists\' + Name, 'Count', 0);
  for I := 0 to N - 1 do Items.Add(Ini.ReadString('HistoryLists\' + Name, 'Item' + IntToStr(I), ''));
end;

procedure SaveHistory(Ini: TCustomIniFile; const Name: string; Items: TStrings);
var
  I: Integer;
begin
  if Ini = nil then Exit;
  Ini.EraseSection('HistoryLists\' + Name);
  Ini.WriteInteger('HistoryLists\' + Name, 'Count', Items.Count);
  for I := 0 to Items.Count - 1 do Ini.WriteString('HistoryLists\' + Name, 'Item' + IntToStr(I), Items[I]);
end;

procedure AddHistory(Ini: TCustomIniFile; const Name, Value: string);
var
  L: TStringList;
begin
  if (Ini = nil) or (Trim(Value) = '') then Exit;
  L := TStringList.Create;
  try
    LoadHistory(Ini, Name, L);
    PushHistory(L, Value);
    SaveHistory(Ini, Name, L);
  finally
    L.Free;
  end;
end;

function SettingsDir: string;
begin
  { D7S_HOME redirects the settings (used by the automated UI tests) }
  Result := GetEnvironmentVariable('D7S_HOME');
  if Result <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(Result);
    Exit;
  end;
  { the folder of the EXE, not %APPDATA%\D7Studio: there every copy of D7 Studio used that one
    file, and a copy whose $(DELPHI) is another folder found none of the packages of this one's
    list }
  Result := ExtractFilePath(ParamStr(0));
end;

function SettingsRegKey: string;
begin
  Result := 'Software\D7Studio';
  if GetEnvironmentVariable('D7S_HOME') <> '' then Result := Result + '\Test';
end;

function MainWindowRect: TRect;
begin
  Result.Left := Settings.ReadInteger('Layout', 'Left', 20);
  Result.Top := Settings.ReadInteger('Layout', 'Top', 20);
  Result.Right := Result.Left + Settings.ReadInteger('Layout', 'Width', 1280);
  Result.Bottom := Result.Top + Settings.ReadInteger('Layout', 'Height', 700);
end;

var
  Loaded: TMemIniFile;     // the settings as they were read (or last saved)
  SaveError: string;       // why the last save failed ('' after one that worked)

procedure CopySettings(From, Into: TMemIniFile);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    From.GetStrings(L);
    Into.SetStrings(L);
  finally
    L.Free;
  end;
end;

function SettingsSaveError: string;
begin
  Result := SaveError;
end;

procedure LoadSettings;
begin
  if Settings <> nil then Exit;
  ForceDirectories(SettingsDir);
  Settings := TMemIniFile.Create(SettingsDir + 'D7Studio.ini');
  Loaded := TMemIniFile.Create('');
  CopySettings(Settings, Loaded);
end;

{ Several D7 Studios may run at once, and each writes its settings when it closes: the last one
  put back what it had read at its start over what the others had changed meanwhile (a font
  chosen in one was lost when a D7 Studio started earlier closed after it). The file is therefore read again and gets only what this
  instance changed: the keys it wrote with another value, the keys and sections that went. A
  failure (a read-only file, a full disk) is not swallowed: it goes to error.log and the caller
  gets False. }
function SaveSettings: Boolean;
var
  Disk: TMemIniFile;
  Secs, Keys: TStringList;
  I, J: Integer;
  V: string;
begin
  Result := True;
  if Settings = nil then Exit;
  try
    Disk := TMemIniFile.Create(Settings.FileName);
    Secs := TStringList.Create;
    Keys := TStringList.Create;
    try
      { a key that is there answers its value, one that is not the default #1 (no value holds it):
        ValueExists would read the names of the whole section for each key }
      Loaded.ReadSections(Secs);
      for I := 0 to Secs.Count - 1 do
        if not Settings.SectionExists(Secs[I]) then
          Disk.EraseSection(Secs[I])
        else
        begin
          Loaded.ReadSection(Secs[I], Keys);
          for J := 0 to Keys.Count - 1 do
            if Settings.ReadString(Secs[I], Keys[J], #1) = #1 then Disk.DeleteKey(Secs[I], Keys[J]);
        end;
      Settings.ReadSections(Secs);
      for I := 0 to Secs.Count - 1 do
      begin
        Settings.ReadSection(Secs[I], Keys);
        for J := 0 to Keys.Count - 1 do
        begin
          V := Settings.ReadString(Secs[I], Keys[J], '');
          if Loaded.ReadString(Secs[I], Keys[J], #1) <> V then Disk.WriteString(Secs[I], Keys[J], V);
        end;
      end;
      WriteIniFile(Disk);
      CopySettings(Settings, Loaded);
      SaveError := '';
    finally
      Keys.Free;
      Secs.Free;
      Disk.Free;
    end;
  except
    on E: Exception do
    begin
      Result := False;
      SaveError := E.Message;
      LogException(E, 'saving the settings', SettingsDir + 'error.log');
    end;
  end;
end;

procedure GetRecent(const Section: string; List: TStrings);
var
  I: Integer;
  S: string;
begin
  List.Clear;
  if Settings = nil then Exit;
  for I := 0 to 9 do
  begin
    S := Settings.ReadString(Section, 'File' + IntToStr(I), '');
    if S <> '' then List.Add(S);
  end;
end;

procedure AddRecent(const Section, FileName: string);
var
  L: TStringList;
  I: Integer;
begin
  if Settings = nil then Exit;
  L := TStringList.Create;
  try
    GetRecent(Section, L);
    PushHistory(L, FileName, 10);
    Settings.EraseSection(Section);
    for I := 0 to L.Count - 1 do
      Settings.WriteString(Section, 'File' + IntToStr(I), L[I]);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- encodings of files }

{ the key of a file in [Encodings]: an INI key ends at its first '=' - one in the path is written
  as '|', which no Windows file name has (the key would never be found again otherwise, and every
  choice would add a line) }
function EncodingKey(const FileName: string): string;
begin
  Result := StringReplace(LowerCase(ExpandPathU(FileName)), '=', '|', [rfReplaceAll]);
end;

function RememberedEncoding(const FileName: string; var E: TSdEncoding): Boolean;
begin
  Result := (Settings <> nil) and
    EncodingFromSetting(Settings.ReadString(EncodingSection, EncodingKey(FileName), ''), E);
end;

procedure RememberFileEncoding(const FileName: string; const E: TSdEncoding);
begin
  if Settings <> nil then Settings.WriteString(EncodingSection, EncodingKey(FileName), EncodingToSetting(E));
end;

function FileEncoding(const FileName, Bytes: string): TSdEncoding;
begin
  if not RememberedEncoding(FileName, Result) then Result := DetectEncoding(Bytes);
end;

function SettingsPackages(Ini: TCustomIniFile; Names: TStrings): Boolean;
const
  Section = 'Design Packages';
var
  I, N, P1, P2: Integer;
  S, FileName: string;
begin
  Names.Clear;
  Result := (Ini <> nil) and (Ini.ReadInteger(Section, 'Count', -1) >= 0);
  if not Result then Exit;
  N := Ini.ReadInteger(Section, 'Count', 0);
  for I := 0 to N - 1 do
  begin
    { "P<n>=<1 or 0>|<file>|<description>"; $(DELPHI)\...: a package of D7 Studio's folder
      (SdDesignHost.SavePackageList) }
    S := Ini.ReadString(Section, 'P' + IntToStr(I), '');
    P1 := Pos('|', S);
    if P1 = 0 then Continue;
    FileName := Copy(S, P1 + 1, MaxInt);
    P2 := Pos('|', FileName);
    if P2 = 0 then P2 := Length(FileName) + 1;
    FileName := ExpandDelphiMacros(Copy(FileName, 1, P2 - 1)) + '=' + Copy(FileName, P2 + 1, MaxInt);
    if Copy(S, 1, P1 - 1) = '0' then FileName := '-' + FileName;
    Names.Add(FileName);
  end;
end;

procedure ExpertFiles(Ini: TCustomIniFile; const RegKey: string; Files: TStrings);
const
  Sections: array[0..1] of string = ('Wizards', 'Experts');
var
  Reg: TRegistry;
  Names: TStringList;
  I, K: Integer;
  F: string;
begin
  Files.Clear;
  Names := TStringList.Create;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    for K := Low(Sections) to High(Sections) do
    begin
      try
        Names.Clear;
        if Reg.OpenKeyReadOnly(RegKey + '\' + Sections[K]) then
        begin
          Reg.GetValueNames(Names);
          for I := 0 to Names.Count - 1 do
          begin
            F := ExpandDelphiMacros(Reg.ReadString(Names[I]));
            if (F <> '') and (Files.IndexOf(F) < 0) then Files.Add(F);
          end;
          Reg.CloseKey;
        end;
      except
      end;
      if Ini <> nil then
      begin
        Names.Clear;
        Ini.ReadSectionValues(Sections[K], Names);
        for I := 0 to Names.Count - 1 do
        begin
          F := ExpandDelphiMacros(Names.ValueFromIndex[I]);
          if (F <> '') and (Files.IndexOf(F) < 0) then Files.Add(F);
        end;
      end;
    end;
  finally
    Reg.Free;
    Names.Free;
  end;
end;

initialization
  { (empty: a finalization section needs one) }

finalization
  FreeAndNil(Settings);
  FreeAndNil(Loaded);

end.
