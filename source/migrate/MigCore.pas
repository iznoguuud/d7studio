{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit MigCore;

{ migrate - what every part uses: the run's options and counts, the report, Delphi 7's and
  D7 Studio's folders and registry keys, Delphi 7's paths as D7 Studio's, the settings file
  (D7Studio.ini), copies of files, copies of registry keys.

  D7 Studio runs on the installed Delphi 7 (SdDelphiDir): its $(DELPHI) is Delphi 7's folder,
  wherever D7Studio.exe lies (Delphi 7's Bin, or a build folder). Delphi 7's packages, experts,
  Imports and ObjRepos are therefore D7 Studio's as they are: nothing of Delphi 7's folder is
  copied, a path in it is only written as $(DELPHI)\....

  The program runs in UTF-8 mode (ModernManUtf8), as D7 Studio does: every string is UTF-8 -
  registry values read through the A functions, D7Studio.ini, the names of files - and text files
  of the system code page are converted when TStrings reads them (Utf8Mode.LegacyTextCodePage).
  Text is written as UTF-8 without a BOM, as D7 Studio writes its files.

  migrate.exe runs it (RunMigration) with arguments (the console) and without them (the dialog,
  MigDlg: from Explorer, Setup's last page, the Tools menu of D7 Studio). The report goes to
  OnReport when it is set, else to the console. }

interface

uses
  Windows, SysUtils, Classes, IniFiles, Registry;

type
  EMigrate = class(Exception);

  { the result of copying one file into D7 Studio's settings folder }
  TCopyResult = (crCopied, crSame, crKept, crMissing);

  { a line of the report }
  TMigReportEvent = procedure(const Line: string) of object;

  { a group of parts or a part: its name (-Only, -Skip) and its text (the dialog) }
  TMigName = record
    Name, Caption: string;
  end;

const
  { the groups, in the order they run. A group's parts are named <group>.<part>; a group of one
    part is that part (packages, tools, variables) }
  GroupCount = 10;
  MigGroups: array[0..GroupCount - 1] of TMigName = (
    (Name: 'library'; Caption: 'Library'),
    (Name: 'packages'; Caption: 'Design packages'),
    (Name: 'experts'; Caption: 'Experts'),
    (Name: 'files'; Caption: 'Files'),
    (Name: 'environment'; Caption: 'Environment Options'),
    (Name: 'editor'; Caption: 'Editor Options'),
    (Name: 'debugger'; Caption: 'Debugger Options'),
    (Name: 'tools'; Caption: 'Tools menu'),
    (Name: 'variables'; Caption: 'Environment variables'),
    (Name: 'history'; Caption: 'History'));
  { the parts, in the order they run }
  PartCount = 29;
  MigParts: array[0..PartCount - 1] of TMigName = (
    (Name: 'library.search'; Caption: 'Library path'),
    (Name: 'library.browsing'; Caption: 'Browsing path'),
    (Name: 'library.output'; Caption: 'Package output folders (BPL, DCP)'),
    (Name: 'packages'; Caption: 'Design packages'),
    (Name: 'experts.dll'; Caption: 'DLL experts'),
    (Name: 'experts.settings'; Caption: 'Settings of experts and design windows'),
    (Name: 'files.templates'; Caption: 'Code templates (delphi32.dci)'),
    (Name: 'files.repository'; Caption: 'Object Repository (Delphi32.dro)'),
    (Name: 'files.projectoptions'; Caption: 'Default project options (defproj.dof)'),
    (Name: 'files.messagehints'; Caption: 'Message hints (msginfo70.ini)'),
    (Name: 'files.menutemplates'; Caption: 'Menu templates (delphi32.dmt)'),
    (Name: 'environment.preferences'; Caption: 'Preferences'),
    (Name: 'environment.designer'; Caption: 'Designer'),
    (Name: 'environment.inspector'; Caption: 'Object Inspector'),
    (Name: 'environment.explorer'; Caption: 'Explorer and class completion'),
    (Name: 'environment.typelibrary'; Caption: 'Type Library'),
    (Name: 'environment.palette'; Caption: 'Component arrangement (palette pages)'),
    (Name: 'environment.todo'; Caption: 'To-Do List filters'),
    (Name: 'editor.settings'; Caption: 'Editor and code insight settings'),
    (Name: 'editor.keymapping'; Caption: 'Key mapping'),
    (Name: 'editor.colors'; Caption: 'Colours (as a colour theme)'),
    (Name: 'editor.filetypes'; Caption: 'File types (Source Options)'),
    (Name: 'debugger.settings'; Caption: 'Debugger settings and paths'),
    (Name: 'debugger.eventlog'; Caption: 'Event log'),
    (Name: 'tools'; Caption: 'Tools menu'),
    (Name: 'variables'; Caption: 'Environment variables'),
    (Name: 'history.lists'; Caption: 'History lists'),
    (Name: 'history.projects'; Caption: 'Recent projects'),
    (Name: 'history.files'; Caption: 'Recent files'));
  { the part of the first versions that stands for the groups environment, editor and debugger }
  OptionsName = 'options';
  OptionsGroups = '|environment|editor|debugger|';
  { the parts whose items can be left out one by one (ListItems, ItemExcluded) }
  ItemParts = 'packages,experts.dll,experts.settings,tools,variables';

var
  OnReport: TMigReportEvent;  // the report's lines (nil: the console)
  WhatIf: Boolean;            // report what would change, change nothing
  Overwrite: Boolean;         // a copied file replaces a different one D7 Studio already has (D7Studio.dmt)
  DelphiRoot: string;         // Delphi 7's folder, without a trailing backslash ('' unknown)
  DelphiKey: string;          // Delphi 7's registry key under HKEY_CURRENT_USER
  StudioRoot: string;         // D7 Studio's folder (its EXE's), without a trailing backslash
  SettingsDir: string;        // the folder of D7Studio.ini, without a trailing backslash
  StudioKey: string;          // D7 Studio's registry key under HKEY_CURRENT_USER
  Settings: TMemIniFile;      // D7Studio.ini as it is written at the end
  Excluded: TStringList;      // items and files left out: <part>:<name> or a name alone (lower case)

  { the summary }
  SettingsChanged, RegistryChanged, FilesCopied, FilesKept, Warnings: Integer;
  BytesCopied: Int64;

{ --- the report --- }
procedure Part(const Title: string);
procedure Say(const S: string);
procedure Warn(const S: string);

{ --- Delphi 7's registry key (read only) --- }
function DelphiKeyExists(const SubKey: string): Boolean;
{ a value as text: a string as it is, a number in decimal; False when there is none (or binary) }
function DelphiValue(const SubKey, Name: string; var Value: string): Boolean;
{ the values of a key as Name=Value in the registry's order (none: an empty list) }
procedure DelphiValueList(const SubKey: string; List: TStrings);
procedure DelphiSubKeys(const SubKey: string; List: TStrings);
{ RootDir of Delphi 7's key, the user's, else the machine's ('' none) }
function DelphiRootDir: string;

{ --- paths --- }
{ a path of Delphi 7 as D7 Studio writes it (SdDelphiDir.CollapseDelphiMacros): $(DELPHI)\...
  when it lies in Delphi 7's folder (by its macro or by its full name), else as it is }
function StudioPath(const P: string): string;
{ ... each folder of a ';' separated list }
function StudioPathList(const L: string): string;
{ a leading $(DELPHI) or $(BDS) as Delphi 7's folder: the full name }
function ExpandDelphi(const P: string): string;
{ the same folder for D7 Studio (macros expanded, any case, with or without a trailing backslash) }
function SamePath(const A, B: string): Boolean;
{ a ';' separated list: its folders, trimmed, without empty ones }
procedure SplitList(const S: string; List: TStrings);
function JoinList(List: TStrings): string;

{ --- the settings file --- }
procedure LoadSettingsFile;
{ a value set; reported when it changes }
procedure SetSetting(const Section, Key, Value: string);
{ a section made exactly Lines (Name=Value, in order) when its values differ; True: it did }
function ReplaceSection(const Section: string; Lines: TStrings): Boolean;
procedure SaveSettingsFile;

{ --- files --- }
function CopyOneFile(const Src, Dst: string): TCopyResult;
function SameFileContent(const A, B: string): Boolean;
{ text written safely (a temporary file that takes the file's place) unless WhatIf }
procedure WriteTextFile(const FileName, Text: string);
function ReadTextFile(const FileName: string): string;
function FileSizeOf(const FileName: string): Int64;

{ --- D7 Studio's registry key --- }
{ Delphi 7's key SubKey with its subkeys into D7 Studio's key DstSubKey: values that differ are
  set, other values stay. The number of values set }
function CopyKey(const SubKey, DstSubKey: string): Integer;
{ the value of D7 Studio's key as text ('' none) }
procedure StudioValueList(const SubKey: string; List: TStrings);

{ --- the running D7 Studio --- }
{ a process runs D7Studio.exe of D7 Studio's folder }
function StudioRunning: Boolean;

{ -Exclude names Name alone }
function IsExcluded(const Name: string): Boolean;
{ an item of a part is left out: -Exclude names it as <part>:<name>, or by its name alone }
function ItemExcluded(const PartName, Name: string): Boolean;

{ --- the parts --- }
{ the group of a part: its name up to the '.' }
function PartGroup(const PartName: string): string;
{ the parts a name of -Only or -Skip stands for - a part, a group or "options" (the groups
  environment, editor and debugger) -, added to List unless it has them; False: no such name }
function AddParts(const Name: string; List: TStrings): Boolean;
{ the running migration takes the part (RunMigration's Parts) }
function Wanted(const PartName: string): Boolean;
{ ... one of the group's parts at least }
function WantedGroup(const Group: string): Boolean;

{ --- the items --- }
{ the items of Delphi 7's configuration that can be left out one by one (ItemParts: its design
  packages, DLL experts, keys of experts' settings, tools and environment variables), as lines
  <part> #9 <name> #9 <caption>, in the order the parts run. Only what the migration can take: the
  packages and experts whose files are there, without Borland's IDE's own packages }
procedure ListItems(List: TStrings);
{ a line of ListItems }
procedure AddItem(List: TStrings; const PartName, Name, Caption: string);

{ --- a run --- }
{ DelphiRoot, when it is '', from Delphi 7's registry key (RootDir) }
procedure FindDelphiRoot;
{ a folder of D7 Studio: it has D7Studio.exe }
function IsStudioFolder(const Dir: string): Boolean;
{ Parts (names of AddParts: parts, groups) of Delphi 7's configuration into D7 Studio's, as the
  variables above say (the folders and keys, WhatIf, Overwrite, Excluded); the counts start at 0.
  StudioMayRun: D7 Studio of the folder may run (the dialog, which says so), so no check that none
  runs - when it closes it writes only what it changed itself, and it reads the migrated values
  when it starts again. False: no Delphi 7 configuration was found (the report says so). Raises
  EMigrate (a D7 Studio of the folder runs, StudioMayRun False) and what a part raises }
function RunMigration(Parts: TStrings; StudioMayRun: Boolean): Boolean;

implementation

uses
  TlHelp32, MigOptions, MigItems;

{ --- the report --- }

procedure Emit(const Line: string);
begin
  if Assigned(OnReport) then OnReport(Line) else Writeln(Line);
end;

procedure Part(const Title: string);
begin
  Emit('');
  Emit(Title);
end;

procedure Say(const S: string);
begin
  Emit('  ' + S);
end;

procedure Warn(const S: string);
begin
  Emit('  warning: ' + S);
  Inc(Warnings);
end;

{ --- registry --- }

function OpenRead(const Path: string): TRegistry;
begin
  Result := TRegistry.Create(KEY_READ);
  Result.RootKey := HKEY_CURRENT_USER;
  if not Result.OpenKeyReadOnly(Path) then FreeAndNil(Result);
end;

function KeyPath(const Base, SubKey: string): string;
begin
  if SubKey = '' then Result := Base else Result := Base + '\' + SubKey;
end;

function RegText(R: TRegistry; const Name: string; var Value: string): Boolean;
begin
  Result := False;
  try
    case R.GetDataType(Name) of
      rdString, rdExpandString:
        begin
          Value := R.ReadString(Name);
          Result := True;
        end;
      rdInteger:
        begin
          Value := IntToStr(R.ReadInteger(Name));
          Result := True;
        end;
    end;
  except
    Result := False;
  end;
end;

function DelphiKeyExists(const SubKey: string): Boolean;
var
  R: TRegistry;
begin
  R := OpenRead(KeyPath(DelphiKey, SubKey));
  Result := R <> nil;
  R.Free;
end;

function DelphiValue(const SubKey, Name: string; var Value: string): Boolean;
var
  R: TRegistry;
begin
  Result := False;
  R := OpenRead(KeyPath(DelphiKey, SubKey));
  if R = nil then Exit;
  try
    Result := R.ValueExists(Name) and RegText(R, Name, Value);
  finally
    R.Free;
  end;
end;

procedure ValueList(const Path: string; List: TStrings);
var
  R: TRegistry;
  Names: TStringList;
  I: Integer;
  V: string;
begin
  List.Clear;
  R := OpenRead(Path);
  if R = nil then Exit;
  Names := TStringList.Create;
  try
    R.GetValueNames(Names);
    for I := 0 to Names.Count - 1 do
      if (Names[I] <> '') and RegText(R, Names[I], V) then List.Add(Names[I] + '=' + V);
  finally
    Names.Free;
    R.Free;
  end;
end;

procedure DelphiValueList(const SubKey: string; List: TStrings);
begin
  ValueList(KeyPath(DelphiKey, SubKey), List);
end;

procedure StudioValueList(const SubKey: string; List: TStrings);
begin
  ValueList(KeyPath(StudioKey, SubKey), List);
end;

procedure DelphiSubKeys(const SubKey: string; List: TStrings);
var
  R: TRegistry;
begin
  List.Clear;
  R := OpenRead(KeyPath(DelphiKey, SubKey));
  if R = nil then Exit;
  try
    R.GetKeyNames(List);
  finally
    R.Free;
  end;
end;

function DelphiRootDir: string;
var
  R: TRegistry;
begin
  Result := '';
  if DelphiValue('', 'RootDir', Result) and (Result <> '') then Exit;
  { the machine's key: Software\WOW6432Node for this 32-bit program on 64-bit Windows }
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKeyReadOnly(DelphiKey) and R.ValueExists('RootDir') then Result := R.ReadString('RootDir');
  finally
    R.Free;
  end;
end;

{ --- paths --- }

function MacroRest(const P: string; var Rest: string): Boolean;
begin
  Result := True;
  if SameText(Copy(P, 1, 9), '$(DELPHI)') then Rest := Copy(P, 10, MaxInt)
  else if SameText(Copy(P, 1, 6), '$(BDS)') then Rest := Copy(P, 7, MaxInt)
  else Result := False;
end;

{ P in Delphi 7's folder: Rest is what follows the folder ('' or '\...') }
function DelphiRest(const P: string; var Rest: string): Boolean;
var
  N: Integer;
begin
  Result := MacroRest(P, Rest);
  if Result or (DelphiRoot = '') then Exit;
  N := Length(DelphiRoot);
  if SameText(Copy(P, 1, N), DelphiRoot) and ((Length(P) = N) or (P[N + 1] = '\')) then
  begin
    Rest := Copy(P, N + 1, MaxInt);
    Result := True;
  end;
end;

function StudioPath(const P: string): string;
var
  Rest: string;
begin
  Result := Trim(P);
  if DelphiRest(Result, Rest) then Result := '$(DELPHI)' + Rest;
end;

function StudioPathList(const L: string): string;
var
  Items: TStringList;
  I: Integer;
begin
  Items := TStringList.Create;
  try
    SplitList(L, Items);
    for I := 0 to Items.Count - 1 do Items[I] := StudioPath(Items[I]);
    Result := JoinList(Items);
  finally
    Items.Free;
  end;
end;

function ExpandDelphi(const P: string): string;
var
  Rest: string;
begin
  if (DelphiRoot <> '') and MacroRest(P, Rest) then Result := DelphiRoot + Rest else Result := P;
end;

function SamePath(const A, B: string): Boolean;
begin
  Result := SameText(ExcludeTrailingPathDelimiter(ExpandDelphi(Trim(A))),
    ExcludeTrailingPathDelimiter(ExpandDelphi(Trim(B))));
end;

procedure SplitList(const S: string; List: TStrings);
var
  L: TStringList;
  I: Integer;
begin
  List.Clear;
  L := TStringList.Create;
  try
    { at ';' only: DelimitedText splits at blanks too ("Program Files") }
    L.Text := StringReplace(S, ';', #13#10, [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) <> '' then List.Add(Trim(L[I]));
  finally
    L.Free;
  end;
end;

function JoinList(List: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to List.Count - 1 do
  begin
    if I > 0 then Result := Result + ';';
    Result := Result + List[I];
  end;
end;

{ --- the settings file --- }

procedure LoadSettingsFile;
begin
  FreeAndNil(Settings);
  Settings := TMemIniFile.Create(SettingsDir + '\D7Studio.ini');
end;

procedure SetSetting(const Section, Key, Value: string);
var
  Old: string;
  Had: Boolean;
begin
  Had := Settings.ValueExists(Section, Key);
  Old := Settings.ReadString(Section, Key, '');
  if Had and (Old = Value) then Exit;
  Settings.WriteString(Section, Key, Value);
  Inc(SettingsChanged);
  if Had then Say(Format('[%s] %s: %s -> %s', [Section, Key, Old, Value]))
  else Say(Format('[%s] %s = %s', [Section, Key, Value]));
end;

function ReplaceSection(const Section: string; Lines: TStrings): Boolean;
var
  Cur: TStringList;
  I: Integer;
begin
  Cur := TStringList.Create;
  try
    Settings.ReadSectionValues(Section, Cur);
    Result := Cur.Count <> Lines.Count;
    if not Result then
      for I := 0 to Lines.Count - 1 do
        if (Cur.IndexOfName(Lines.Names[I]) < 0) or
          (Cur.Values[Lines.Names[I]] <> Lines.ValueFromIndex[I]) then
        begin
          Result := True;
          Break;
        end;
    if not Result then Exit;
    Settings.EraseSection(Section);
    for I := 0 to Lines.Count - 1 do
      Settings.WriteString(Section, Lines.Names[I], Lines.ValueFromIndex[I]);
    Inc(SettingsChanged);
  finally
    Cur.Free;
  end;
end;

procedure SaveSettingsFile;
var
  L: TStringList;
begin
  if SettingsChanged = 0 then Exit;
  L := TStringList.Create;
  try
    Settings.GetStrings(L);
    WriteTextFile(Settings.FileName, L.Text);
  finally
    L.Free;
  end;
end;

{ --- files --- }

function FileSizeOf(const FileName: string): Int64;
var
  D: TWin32FileAttributeData;
begin
  if GetFileAttributesEx(PChar(FileName), GetFileExInfoStandard, @D) then
    Result := Int64(D.nFileSizeHigh) shl 32 or D.nFileSizeLow
  else
    Result := -1;
end;

function SameFileContent(const A, B: string): Boolean;
const
  Chunk = 65536;
var
  DA, DB: TWin32FileAttributeData;
  SA, SB: TFileStream;
  BA, BB: string;
  N: Integer;
begin
  Result := False;
  if not GetFileAttributesEx(PChar(A), GetFileExInfoStandard, @DA) or
    not GetFileAttributesEx(PChar(B), GetFileExInfoStandard, @DB) then Exit;
  if (DA.nFileSizeLow <> DB.nFileSizeLow) or (DA.nFileSizeHigh <> DB.nFileSizeHigh) then Exit;
  if CompareFileTime(DA.ftLastWriteTime, DB.ftLastWriteTime) = 0 then
  begin
    Result := True;
    Exit;
  end;
  SA := TFileStream.Create(A, fmOpenRead or fmShareDenyNone);
  try
    SB := TFileStream.Create(B, fmOpenRead or fmShareDenyNone);
    try
      SetLength(BA, Chunk);
      SetLength(BB, Chunk);
      repeat
        N := SA.Read(BA[1], Chunk);
        if SB.Read(BB[1], Chunk) <> N then Exit;
        if (N > 0) and not CompareMem(@BA[1], @BB[1], N) then Exit;
      until N < Chunk;
      Result := True;
    finally
      SB.Free;
    end;
  finally
    SA.Free;
  end;
end;

function CopyOneFile(const Src, Dst: string): TCopyResult;
begin
  if not FileExists(Src) then
  begin
    Result := crMissing;
    Exit;
  end;
  if FileExists(Dst) then
  begin
    if SameFileContent(Src, Dst) then
    begin
      Result := crSame;
      Exit;
    end;
    if not Overwrite then
    begin
      Inc(FilesKept);
      Result := crKept;
      Exit;
    end;
  end;
  if not WhatIf then
  begin
    ForceDirectories(ExtractFileDir(Dst));
    if not CopyFile(PChar(Src), PChar(Dst), False) then
      raise EMigrate.CreateFmt('Cannot copy %s to %s: %s', [Src, Dst, SysErrorMessage(GetLastError)]);
  end;
  Inc(FilesCopied);
  Inc(BytesCopied, FileSizeOf(Src));
  Result := crCopied;
end;

procedure WriteTextFile(const FileName, Text: string);
var
  Tmp: string;
  S: TFileStream;
begin
  if WhatIf then Exit;
  ForceDirectories(ExtractFileDir(FileName));
  Tmp := FileName + '.migrate';
  S := TFileStream.Create(Tmp, fmCreate);
  try
    if Text <> '' then S.WriteBuffer(Text[1], Length(Text));
  finally
    S.Free;
  end;
  if not MoveFileEx(PChar(Tmp), PChar(FileName), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
  begin
    DeleteFile(Tmp);
    raise EMigrate.CreateFmt('Cannot write %s: %s', [FileName, SysErrorMessage(GetLastError)]);
  end;
end;

function ReadTextFile(const FileName: string): string;
var
  L: TStringList;
begin
  { through TStrings: a file of the system code page becomes UTF-8 }
  L := TStringList.Create;
  try
    L.LoadFromFile(FileName);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ --- D7 Studio's registry key --- }

function CopyKey(const SubKey, DstSubKey: string): Integer;
var
  Src, Dst: HKEY;
  Names: TStringList;
  I: Integer;
  NameBuf: array[0..16383] of Char;
  NameLen, Typ, Size, DTyp, DSize: DWORD;
  Data, Old: string;
  DstPath: string;
begin
  Result := 0;
  if RegOpenKeyEx(HKEY_CURRENT_USER, PChar(KeyPath(DelphiKey, SubKey)), 0, KEY_READ, Src) <> ERROR_SUCCESS then Exit;
  try
    DstPath := KeyPath(StudioKey, DstSubKey);
    Dst := 0;
    if WhatIf then
    begin
      if RegOpenKeyEx(HKEY_CURRENT_USER, PChar(DstPath), 0, KEY_READ, Dst) <> ERROR_SUCCESS then Dst := 0;
    end
    else if RegCreateKeyEx(HKEY_CURRENT_USER, PChar(DstPath), 0, nil, 0, KEY_READ or KEY_WRITE, nil, Dst, nil) <> ERROR_SUCCESS then
      raise EMigrate.CreateFmt('Cannot write HKEY_CURRENT_USER\%s', [DstPath]);
    try
      I := 0;
      repeat
        NameLen := SizeOf(NameBuf);
        Size := 0;
        if RegEnumValue(Src, I, NameBuf, NameLen, nil, @Typ, nil, @Size) <> ERROR_SUCCESS then Break;
        Inc(I);
        { text in UTF-8 can take more bytes than the size the first call gives (UTF-16's) }
        Size := Size * 2 + 16;
        SetLength(Data, Size);
        NameLen := SizeOf(NameBuf);
        if RegEnumValue(Src, I - 1, NameBuf, NameLen, nil, @Typ, PByte(Data), @Size) <> ERROR_SUCCESS then
        begin
          Warn(Format('HKEY_CURRENT_USER\%s\%s could not be read', [KeyPath(DelphiKey, SubKey), string(NameBuf)]));
          Continue;
        end;
        SetLength(Data, Size);
        { the value D7 Studio's key has }
        Old := '';
        DTyp := REG_NONE;
        if Dst <> 0 then
        begin
          DSize := 0;
          if RegQueryValueEx(Dst, NameBuf, nil, @DTyp, nil, @DSize) = ERROR_SUCCESS then
          begin
            DSize := DSize * 2 + 16;
            SetLength(Old, DSize);
            if RegQueryValueEx(Dst, NameBuf, nil, @DTyp, PByte(Old), @DSize) = ERROR_SUCCESS then
              SetLength(Old, DSize)
            else
              DTyp := REG_NONE;
          end
          else
            DTyp := REG_NONE;
        end;
        if (DTyp = Typ) and (Old = Data) then Continue;
        if not WhatIf then
          if RegSetValueEx(Dst, NameBuf, 0, Typ, PChar(Data), Length(Data)) <> ERROR_SUCCESS then
            raise EMigrate.CreateFmt('Cannot write HKEY_CURRENT_USER\%s\%s', [DstPath, string(NameBuf)]);
        Inc(Result);
      until False;
    finally
      if Dst <> 0 then RegCloseKey(Dst);
    end;
    { the subkeys }
    Names := TStringList.Create;
    try
      DelphiSubKeys(SubKey, Names);
      for I := 0 to Names.Count - 1 do
        Inc(Result, CopyKey(KeyPath(SubKey, Names[I]), KeyPath(DstSubKey, Names[I])));
    finally
      Names.Free;
    end;
  finally
    RegCloseKey(Src);
  end;
end;

{ --- the running D7 Studio --- }

function QueryFullProcessImageName(Process: THandle; Flags: DWORD; ExeName: PChar;
  var Size: DWORD): BOOL; stdcall; external kernel32 name 'QueryFullProcessImageNameA';

function StudioRunning: Boolean;
const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
var
  Snap, P: THandle;
  E: TProcessEntry32;
  Buf: array[0..MAX_PATH * 4] of Char;
  Size: DWORD;
  Exe: string;
begin
  Result := False;
  Exe := StudioRoot + '\D7Studio.exe';
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then Exit;
  try
    E.dwSize := SizeOf(E);
    if not Process32First(Snap, E) then Exit;
    repeat
      if SameText(ExtractFileName(E.szExeFile), 'D7Studio.exe') then
      begin
        P := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, E.th32ProcessID);
        if P <> 0 then
          try
            Size := SizeOf(Buf);
            if QueryFullProcessImageName(P, 0, Buf, Size) and SameText(Buf, Exe) then Result := True;
          finally
            CloseHandle(P);
          end;
      end;
    until Result or not Process32Next(Snap, E);
  finally
    CloseHandle(Snap);
  end;
end;

function IsExcluded(const Name: string): Boolean;
begin
  Result := (Name <> '') and (Excluded.IndexOf(LowerCase(Name)) >= 0);
end;

function ItemExcluded(const PartName, Name: string): Boolean;
begin
  Result := IsExcluded(Name) or ((Name <> '') and (Excluded.IndexOf(LowerCase(PartName + ':' + Name)) >= 0));
end;

{ --- the parts --- }

var
  { the parts of the running migration }
  RunParts: TStringList;

function PartGroup(const PartName: string): string;
var
  K: Integer;
begin
  K := Pos('.', PartName);
  if K = 0 then Result := PartName else Result := Copy(PartName, 1, K - 1);
end;

function AddParts(const Name: string; List: TStrings): Boolean;
var
  I: Integer;
  N, G: string;
begin
  N := LowerCase(Trim(Name));
  Result := False;
  for I := 0 to PartCount - 1 do
  begin
    G := PartGroup(MigParts[I].Name);
    if (MigParts[I].Name = N) or (G = N) or ((N = OptionsName) and (Pos('|' + G + '|', OptionsGroups) > 0)) then
    begin
      Result := True;
      if List.IndexOf(MigParts[I].Name) < 0 then List.Add(MigParts[I].Name);
    end;
  end;
end;

function Wanted(const PartName: string): Boolean;
begin
  Result := RunParts.IndexOf(PartName) >= 0;
end;

function WantedGroup(const Group: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to RunParts.Count - 1 do
    if PartGroup(RunParts[I]) = Group then Result := True;
end;

{ --- the items --- }

procedure AddItem(List: TStrings; const PartName, Name, Caption: string);
begin
  List.Add(PartName + #9 + Name + #9 + Caption);
end;

procedure ListItems(List: TStrings);
begin
  FindDelphiRoot;
  ListPackages(List);
  ListExperts(List);
  ListExpertKeys(List);
  ListTools(List);
  ListVariables(List);
end;

{ --- a run --- }

procedure FindDelphiRoot;
begin
  if DelphiRoot = '' then DelphiRoot := ExcludeTrailingPathDelimiter(DelphiRootDir);
end;

function IsStudioFolder(const Dir: string): Boolean;
begin
  Result := (Dir <> '') and FileExists(IncludeTrailingPathDelimiter(Dir) + 'D7Studio.exe');
end;

function RunMigration(Parts: TStrings; StudioMayRun: Boolean): Boolean;
var
  S: string;
  I: Integer;
begin
  SettingsChanged := 0;
  RegistryChanged := 0;
  FilesCopied := 0;
  FilesKept := 0;
  Warnings := 0;
  BytesCopied := 0;
  RunParts.Clear;
  for I := 0 to Parts.Count - 1 do AddParts(Parts[I], RunParts);
  FindDelphiRoot;
  Result := DelphiKeyExists('') or ((DelphiRoot <> '') and DirectoryExists(DelphiRoot));
  if not Result then
  begin
    Emit(Format('No Delphi 7 configuration found (HKEY_CURRENT_USER\%s and its folder are missing).', [DelphiKey]));
    Exit;
  end;
  Emit(Format('From  Delphi 7: %s  (HKEY_CURRENT_USER\%s)', [DelphiRoot, DelphiKey]));
  Emit(Format('Into  D7 Studio: %s  (%s\D7Studio.ini, HKEY_CURRENT_USER\%s)', [StudioRoot, SettingsDir, StudioKey]));
  if WhatIf then Emit('WhatIf: nothing is changed.');
  if (DelphiRoot <> '') and not DirectoryExists(DelphiRoot) then
    Warn(Format('Delphi 7''s folder %s is not there: only its registry settings are migrated', [DelphiRoot]));
  if not StudioMayRun and StudioRunning then
    if WhatIf then Warn('D7 Studio runs from this folder: close it before the migration')
    else raise EMigrate.Create('D7 Studio runs from this folder: close it first (it writes its settings when it closes)');
  LoadSettingsFile;
  if WantedGroup('library') then MigrateLibrary;
  if Wanted('packages') then MigratePackages;
  if WantedGroup('experts') then MigrateExperts;
  if WantedGroup('files') then MigrateFiles;
  if WantedGroup('environment') then MigrateEnvironment;
  if WantedGroup('editor') then MigrateEditor;
  if WantedGroup('debugger') then MigrateDebugger;
  if Wanted('tools') then MigrateTools;
  if Wanted('variables') then MigrateVariables;
  if WantedGroup('history') then MigrateHistory;
  SaveSettingsFile;
  if WhatIf then S := 'Would change' else S := 'Changed';
  Emit('');
  Emit(Format('%s: %d settings, %d registry values, %d files copied (%.1f MB), %d files kept, %d warnings',
    [S, SettingsChanged, RegistryChanged, FilesCopied, BytesCopied / (1024 * 1024), FilesKept, Warnings]));
end;

initialization
  Excluded := TStringList.Create;
  RunParts := TStringList.Create;

finalization
  Settings.Free;
  RunParts.Free;
  Excluded.Free;

end.
