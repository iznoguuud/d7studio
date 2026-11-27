{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit BugCore;

{ bugreport.exe's work: D7 Studio's crash log (error.log, SdCrashLog) read back and written as a
  report for an issue.

  An entry of the log is a line "yyyy-mm-dd hh:nn:ss  <context>  <class>: <message>" (the message
  may go on over more lines), then its call stack, a line per frame "  <module> <offset>  <symbol>"
  (the offset from the module's base, hex; the symbol a procedure of the program's map with
  "(<file>:<line>)", or an export "<name> + <hex>", or none), then an empty line.

  The report:
  - the system: D7 Studio's version, Windows, the code pages, the monitors and their DPI, Delphi
    7's folder, whether the modernized RTL/VCL is applied, the run-time packages D7 Studio loads;
  - the design packages and DLL experts of the settings beside the log (D7Studio.ini);
  - the modules of the call stacks: where they are, their versions, their maps;
  - the errors grouped - the same class, message (addresses aside) and top of the stack -, newest
    first, each with its count and the call stack of its newest entry: a frame the log left
    without a symbol is resolved from the module's map when the map is of the module's build and
    the module was not built after the error; a frame with a source line shows the lines around it
    when the source is found;
  - the log's entries themselves.
  The report is UTF-8 (with a BOM): the log is D7 Studio's text, UTF-8. }

interface

uses
  Classes;

type
  TBugReportOptions = record
    LogFile: string;        // D7 Studio's error.log; the settings (D7Studio.ini) are beside it
    OutFile: string;        // the report
    SourceDirs: TStrings;   // more folders to find sources in, with their subfolders; nil: none
    Last: Integer;          // only the newest Last entries of the log; 0: all
    Context: Integer;       // source lines shown before and after a frame's line
  end;

{ writes the report (raises EInOutError when it cannot); Summary: a line for the
  console - how many errors, how many different }
procedure WriteBugReport(const Options: TBugReportOptions; out Summary: string);

implementation

uses
  Windows, SysUtils, IniFiles, Forms, ShellScaling, SdDbgTD32, SdCrashLog, SdFileNames, SdEncoding,
  SdSettings, SdDelphiDir, SdSysInfo;

const
  StackShown = 6;            // the frames of the top of the stack that tell two errors apart
  MapSlack = 10 / (24 * 60); // a map and its module from one build: written within 10 minutes
  LOCALE_SNAME = $5C;
  RuntimeModules: array[0..5] of string = ('rtl70.bpl', 'vcl70.bpl', 'vclx70.bpl', 'designide70.bpl',
    'coreide70.bpl', 'borlndmm.dll');

type
  TBugFrame = record
    Module: string;
    Offset: Cardinal;
    Symbol: string;          // the procedure or the export, as logged or from the map
    SrcFile: string;         // the source file as the map names it; '' unknown
    Line: Integer;
    FromMap: Boolean;        // resolved by this report
    Stale: Boolean;          // the module was built after the error: its map does not apply
  end;

  TBugEntry = class
  public
    Time: TDateTime;
    TimeText: string;
    Context, ExClass, Msg: string;
    Frames: array of TBugFrame;
    Raw: TStringList;        // the entry's lines in the log
    constructor Create;
    destructor Destroy; override;
  end;

  TBugGroup = class
  public
    Entries: TList;          // TBugEntry, oldest first
    constructor Create;
    destructor Destroy; override;
    function Newest: TBugEntry;
  end;

  TBugModule = class
  public
    Name: string;            // as the log names it
    FileName: string;        // where it is; '' not found
    FileTime: TDateTime;     // its last write; 0 unknown
    MapName: string;         // its map; '' none
    Info: TTD32Info;         // the map read; nil: not usable (Note says why)
    Note: string;
    destructor Destroy; override;
  end;

  TBugReport = class
  private
    FOptions: TBugReportOptions;
    FLogDir, FStudioExe: string;
    FOut: TStringList;
    FEntries: TList;         // TBugEntry, as the log has them (oldest first)
    FLogged: Integer;        // entries in the log, before Last
    FGroups: TList;          // TBugGroup, newest first
    FModules: TStringList;   // lower-case name -> TBugModule
    FModuleDirs: TStringList;
    FSrcNames: TStringList;  // lower-case file name -> index into FSrcPaths, sorted
    FSrcPaths: TStringList;
    FSrcIndexed: Boolean;
    FSrcCache: TStringList;  // full path -> TStringList of its lines
    FIni: TMemIniFile;       // D7Studio.ini beside the log; nil: none
    procedure Add(const S: string);
    procedure AddFmt(const Fmt: string; const Args: array of const);
    procedure Heading(const S: string);
    procedure Field(const Name, Value: string);
    procedure ReadLog;
    procedure GroupEntries;
    function Module(const Name: string): TBugModule;
    procedure Resolve;
    procedure IndexSources;
    procedure IndexDir(const Dir: string; Depth: Integer);
    function FindSource(const SrcFile: string): string;
    function SourceLines(const FileName: string): TStringList;
    procedure WriteSystem;
    procedure WriteSettings;
    procedure WriteModules;
    procedure WriteErrors;
    procedure WriteFrame(const F: TBugFrame);
    procedure WriteLog;
  public
    constructor Create(const Options: TBugReportOptions);
    destructor Destroy; override;
    procedure Run(out Summary: string);
  end;

{ ---------------------------------------------------------------- text }

{ a text file's lines as UTF-8 (the program runs in UTF-8 mode): its encoding found from its bytes -
  a byte order mark, UTF-8, else the system code page }
procedure LoadText(const FileName: string; Lines: TStrings);
begin
  Lines.Text := SystemFileToIde(ReadFileU(FileName));
end;

function IsHex8(const S: string; P: Integer): Boolean;
var
  I: Integer;
begin
  Result := P + 7 <= Length(S);
  if Result then
    for I := P to P + 7 do
      if not (S[I] in ['0'..'9', 'A'..'F', 'a'..'f']) then
      begin
        Result := False;
        Exit;
      end;
end;

{ S with every run of 8 hex digits (an address) as ########: two errors of the same place whose
  messages name other addresses are one }
function WithoutAddresses(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  I := 1;
  while I <= Length(Result) - 7 do
    if IsHex8(Result, I) and ((I = 1) or not (Result[I - 1] in ['0'..'9', 'A'..'Z', 'a'..'z'])) then
    begin
      Result := Copy(Result, 1, I - 1) + '########' + Copy(Result, I + 8, MaxInt);
      Inc(I, 8);
    end
    else
      Inc(I);
end;

{ the last write of a file, local time; 0 when it is not there }
function FileTime(const FileName: string): TDateTime;
var
  Age: Integer;
begin
  Result := 0;
  if FileName = '' then Exit;
  Age := FileAge(FileName);
  if Age <> -1 then Result := FileDateToDateTime(Age);
end;

function TimeText(T: TDateTime): string;
begin
  if T = 0 then Result := '?' else Result := FormatDateTime('yyyy-mm-dd hh:nn', T);
end;

{ "<file>, <version>, <time>": what a file is; "(not found)" for '' }
function FileFacts(const FileName: string): string;
var
  V: string;
begin
  if FileName = '' then
  begin
    Result := '(not found)';
    Exit;
  end;
  Result := FileName;
  V := FileVersionOf(FileName);
  if V <> '' then Result := Result + ', ' + V;
  Result := Result + ', ' + TimeText(FileTime(FileName));
end;

{ a file Windows' search would load for a module that names it without a folder: the folder of
  the program first (Dir), then the PATH; '' none }
function FindOnPath(const Dir, Name: string): string;
var
  Buf: array[0..MAX_PATH] of Char;
  Part: PChar;
begin
  if (Dir <> '') and FileExists(Dir + Name) then
  begin
    Result := Dir + Name;
    Exit;
  end;
  if SearchPath(nil, PChar(Name), nil, MAX_PATH, Buf, Part) > 0 then
    Result := Buf
  else
    Result := '';
end;

{ ---------------------------------------------------------------- the log's lines }

{ "yyyy-mm-dd hh:nn:ss  <context>  <class>: <message>": the context ends at the first two blanks
  that a class name and ": " follow (LogException; an empty context gives four blanks) }
function ParseHead(const S: string; E: TBugEntry): Boolean;
var
  Y, Mo, D, H, Mi, Se, P, J: Integer;
  DT, TM: TDateTime;
  Rest: string;
begin
  Result := False;
  if (Length(S) < 21) or (S[5] <> '-') or (S[8] <> '-') or (S[11] <> ' ') or (S[14] <> ':') or
    (S[17] <> ':') or (Copy(S, 20, 2) <> '  ') then Exit;
  Y := StrToIntDef(Copy(S, 1, 4), -1);
  Mo := StrToIntDef(Copy(S, 6, 2), -1);
  D := StrToIntDef(Copy(S, 9, 2), -1);
  H := StrToIntDef(Copy(S, 12, 2), -1);
  Mi := StrToIntDef(Copy(S, 15, 2), -1);
  Se := StrToIntDef(Copy(S, 18, 2), -1);
  if not TryEncodeDate(Y, Mo, D, DT) or not TryEncodeTime(H, Mi, Se, 0, TM) then Exit;
  E.Time := DT + TM;
  E.TimeText := Copy(S, 1, 19);
  Rest := Copy(S, 22, MaxInt);
  E.Context := Rest;
  E.ExClass := '';
  E.Msg := '';
  for P := 1 to Length(Rest) - 1 do
    if (Rest[P] = ' ') and (Rest[P + 1] = ' ') then
    begin
      J := P + 2;
      while (J <= Length(Rest)) and (Rest[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) do Inc(J);
      if (J > P + 2) and (Copy(Rest, J, 2) = ': ') then
      begin
        E.Context := Copy(Rest, 1, P - 1);
        E.ExClass := Copy(Rest, P + 2, J - P - 2);
        E.Msg := Copy(Rest, J + 2, MaxInt);
        Break;
      end;
    end;
  Result := True;
end;

{ "<name>  (<file>:<line>)" -> name, file, line; another symbol stays whole }
procedure SplitSymbol(const Sym: string; var F: TBugFrame);
var
  P, C, N: Integer;
  Inside: string;
begin
  F.Symbol := Sym;
  F.SrcFile := '';
  F.Line := 0;
  if (Sym = '') or (Sym[Length(Sym)] <> ')') then Exit;
  P := LastDelimiter('(', Sym);
  if P = 0 then Exit;
  Inside := Copy(Sym, P + 1, Length(Sym) - P - 1);
  C := LastDelimiter(':', Inside);
  if C = 0 then Exit;
  N := StrToIntDef(Copy(Inside, C + 1, MaxInt), 0);
  if N <= 0 then Exit;
  F.SrcFile := Copy(Inside, 1, C - 1);
  F.Line := N;
  F.Symbol := TrimRight(Copy(Sym, 1, P - 1));
end;

{ "  <module> <8 hex digits>[  <symbol>]" (SdCrashLog.Describe: the module padded to 18) }
function ParseFrame(const S: string; out F: TBugFrame): Boolean;
var
  T: string;
  I: Integer;
begin
  Result := False;
  FillChar(F, SizeOf(F), 0);
  if (Length(S) < 12) or (S[1] <> ' ') or (S[2] <> ' ') or (S[3] = ' ') then Exit;
  T := Copy(S, 3, MaxInt);
  for I := 2 to Length(T) - 7 do
    if (T[I - 1] = ' ') and IsHex8(T, I) and ((I + 8 > Length(T)) or (T[I + 8] = ' ')) then
    begin
      F.Module := Trim(Copy(T, 1, I - 1));
      F.Offset := Cardinal(StrToInt64('$' + Copy(T, I, 8)));
      SplitSymbol(Trim(Copy(T, I + 8, MaxInt)), F);
      Result := F.Module <> '';
      Exit;
    end;
end;

{ ---------------------------------------------------------------- the parts }

constructor TBugEntry.Create;
begin
  inherited Create;
  Raw := TStringList.Create;
end;

destructor TBugEntry.Destroy;
begin
  Raw.Free;
  inherited Destroy;
end;

constructor TBugGroup.Create;
begin
  inherited Create;
  Entries := TList.Create;
end;

destructor TBugGroup.Destroy;
begin
  Entries.Free;
  inherited Destroy;
end;

function TBugGroup.Newest: TBugEntry;
begin
  Result := TBugEntry(Entries[Entries.Count - 1]);
end;

destructor TBugModule.Destroy;
begin
  Info.Free;
  inherited Destroy;
end;

{ ---------------------------------------------------------------- the report }

constructor TBugReport.Create(const Options: TBugReportOptions);
var
  Names: TStringList;
  I: Integer;
  F: string;

  procedure AddDir(const Dir: string);
  var
    D: string;
  begin
    if Dir = '' then Exit;
    D := IncludeTrailingPathDelimiter(Dir);
    if FModuleDirs.IndexOf(D) < 0 then FModuleDirs.Add(D);
  end;

begin
  inherited Create;
  FOptions := Options;
  FLogDir := ExtractFilePath(ExpandFileName(Options.LogFile));
  FStudioExe := FLogDir + 'D7Studio.exe';
  if not FileExists(FStudioExe) then FStudioExe := ExtractFilePath(ParamStr(0)) + 'D7Studio.exe';
  if not FileExists(FStudioExe) then FStudioExe := '';
  FOut := TStringList.Create;
  FEntries := TList.Create;
  FGroups := TList.Create;
  FModules := TStringList.Create;
  FModules.Sorted := True;
  FModuleDirs := TStringList.Create;
  FSrcNames := TStringList.Create;
  FSrcNames.Sorted := True;
  FSrcNames.Duplicates := dupIgnore;
  FSrcPaths := TStringList.Create;
  FSrcCache := TStringList.Create;
  FSrcCache.Sorted := True;
  if FileExists(FLogDir + 'D7Studio.ini') then FIni := TMemIniFile.Create(FLogDir + 'D7Studio.ini');
  { where the modules of the stacks are looked for: D7 Studio's folder, Delphi 7's Bin and its
    packages' folder, the folders of the settings' packages and experts }
  AddDir(FLogDir);
  if FStudioExe <> '' then AddDir(ExtractFilePath(FStudioExe));
  AddDir(DelphiBin);
  AddDir(DelphiRoot + 'Projects\Bpl');
  Names := TStringList.Create;
  try
    SettingsPackages(FIni, Names);
    for I := 0 to Names.Count - 1 do
    begin
      F := Names.Names[I];
      if Copy(F, 1, 1) = '-' then Delete(F, 1, 1);
      AddDir(ExtractFilePath(F));
    end;
    ExpertFiles(FIni, SettingsRegKey, Names);
    for I := 0 to Names.Count - 1 do AddDir(ExtractFilePath(Names[I]));
  finally
    Names.Free;
  end;
end;

destructor TBugReport.Destroy;
var
  I: Integer;
begin
  for I := 0 to FEntries.Count - 1 do TObject(FEntries[I]).Free;
  for I := 0 to FGroups.Count - 1 do TObject(FGroups[I]).Free;
  for I := 0 to FModules.Count - 1 do FModules.Objects[I].Free;
  for I := 0 to FSrcCache.Count - 1 do FSrcCache.Objects[I].Free;
  FEntries.Free;
  FGroups.Free;
  FModules.Free;
  FModuleDirs.Free;
  FSrcNames.Free;
  FSrcPaths.Free;
  FSrcCache.Free;
  FIni.Free;
  FOut.Free;
  inherited Destroy;
end;

procedure TBugReport.Add(const S: string);
begin
  FOut.Add(S);
end;

procedure TBugReport.AddFmt(const Fmt: string; const Args: array of const);
begin
  FOut.Add(Format(Fmt, Args));
end;

procedure TBugReport.Heading(const S: string);
begin
  Add('');
  Add(S);
  Add(StringOfChar('-', Length(S)));
end;

procedure TBugReport.Field(const Name, Value: string);
begin
  AddFmt('  %-18s %s', [Name, Value]);
end;

{ the log's entries, oldest first; the oldest dropped beyond Last }
procedure TBugReport.ReadLog;
var
  Lines: TStringList;
  I: Integer;
  E, Head: TBugEntry;
  F: TBugFrame;
  S: string;
begin
  if not FileExists(FOptions.LogFile) then Exit;
  Lines := TStringList.Create;
  try
    LoadText(FOptions.LogFile, Lines);
    E := nil;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I];
      if (Length(S) >= 21) and (S[1] in ['0'..'9']) then
      begin
        Head := TBugEntry.Create;
        if ParseHead(S, Head) then
        begin
          E := Head;
          FEntries.Add(E);
          E.Raw.Add(S);
          Continue;
        end;
        Head.Free;                                // a line of a message that begins with a digit
      end;
      if E = nil then Continue;                   // before the first entry
      E.Raw.Add(S);
      if Trim(S) = '' then Continue;
      if ParseFrame(S, F) then
      begin
        SetLength(E.Frames, Length(E.Frames) + 1);
        E.Frames[High(E.Frames)] := F;
      end
      else if Length(E.Frames) = 0 then
        E.Msg := E.Msg + #13#10 + S;               // a message of more lines
    end;
  finally
    Lines.Free;
  end;
  for I := 0 to FEntries.Count - 1 do
  begin
    E := TBugEntry(FEntries[I]);
    while (E.Raw.Count > 0) and (Trim(E.Raw[E.Raw.Count - 1]) = '') do E.Raw.Delete(E.Raw.Count - 1);
  end;
  FLogged := FEntries.Count;
  if FOptions.Last > 0 then
    while FEntries.Count > FOptions.Last do
    begin
      TObject(FEntries[0]).Free;
      FEntries.Delete(0);
    end;
end;

function GroupKey(E: TBugEntry): string;
var
  I: Integer;
begin
  Result := E.ExClass + #1 + WithoutAddresses(E.Msg);
  for I := 0 to Length(E.Frames) - 1 do
  begin
    if I >= StackShown then Break;
    Result := Result + #1 + LowerCase(E.Frames[I].Module) + ':' + IntToHex(E.Frames[I].Offset, 8);
  end;
end;

function CompareNewest(A, B: Pointer): Integer;
var
  TA, TB: TDateTime;
begin
  TA := TBugGroup(A).Newest.Time;
  TB := TBugGroup(B).Newest.Time;
  if TA > TB then Result := -1 else if TA < TB then Result := 1 else Result := 0;
end;

procedure TBugReport.GroupEntries;
var
  Keys: TStringList;
  I, K: Integer;
  G: TBugGroup;
  Key: string;
begin
  Keys := TStringList.Create;
  try
    Keys.Sorted := True;
    for I := 0 to FEntries.Count - 1 do
    begin
      Key := GroupKey(TBugEntry(FEntries[I]));
      if Keys.Find(Key, K) then
        G := TBugGroup(Keys.Objects[K])
      else
      begin
        G := TBugGroup.Create;
        FGroups.Add(G);
        Keys.AddObject(Key, G);
      end;
      G.Entries.Add(FEntries[I]);
    end;
  finally
    Keys.Free;
  end;
  FGroups.Sort(CompareNewest);
end;

{ a module of the stacks, found and its map read the first time it is asked for }
function TBugReport.Module(const Name: string): TBugModule;
var
  I: Integer;
  MapTime: TDateTime;
begin
  if FModules.Find(LowerCase(Name), I) then
  begin
    Result := TBugModule(FModules.Objects[I]);
    Exit;
  end;
  Result := TBugModule.Create;
  Result.Name := Name;
  FModules.AddObject(LowerCase(Name), Result);
  if (Name = '') or (Name = '?') then
  begin
    Result.Note := 'not a module the log could name';
    Exit;
  end;
  for I := 0 to FModuleDirs.Count - 1 do
    if FileExists(FModuleDirs[I] + Name) then
    begin
      Result.FileName := FModuleDirs[I] + Name;
      Break;
    end;
  if Result.FileName = '' then Result.FileName := FindOnPath('', Name);
  if Result.FileName = '' then
  begin
    Result.Note := 'not found';
    Exit;
  end;
  Result.FileTime := FileTime(Result.FileName);
  Result.MapName := ChangeFileExt(Result.FileName, '.map');
  if not FileExists(Result.MapName) then
  begin
    Result.MapName := '';
    Result.Note := 'no map: names from its exports, as logged';
    Exit;
  end;
  MapTime := FileTime(Result.MapName);
  if Abs(MapTime - Result.FileTime) > MapSlack then
  begin
    Result.Note := Format('map %s (%s) is not of this build: not used', [ExtractFileName(Result.MapName),
      TimeText(MapTime)]);
    Exit;
  end;
  Result.Info := TTD32Info.Create;
  if Result.Info.LoadFromMap(Result.MapName, Result.FileName) then
    Result.Note := 'map ' + ExtractFileName(Result.MapName) + ' read'
  else
  begin
    FreeAndNil(Result.Info);
    Result.Note := 'map ' + ExtractFileName(Result.MapName) + ' could not be read';
  end;
end;

{ every frame the log left without a symbol or a line: from its module's map - unless the module
  was built after the error, when the offsets belong to another build }
procedure TBugReport.Resolve;
var
  I, K, Line: Integer;
  E: TBugEntry;
  M: TBugModule;
  Name, SrcFile: string;
begin
  for I := 0 to FEntries.Count - 1 do
  begin
    E := TBugEntry(FEntries[I]);
    for K := 0 to Length(E.Frames) - 1 do
    begin
      M := Module(E.Frames[K].Module);
      if (M.Info = nil) or ((E.Frames[K].Symbol <> '') and (E.Frames[K].Line > 0)) then Continue;
      if M.FileTime > E.Time + 1 / (24 * 60) then
      begin
        E.Frames[K].Stale := True;
        Continue;
      end;
      MapAddress(M.Info, E.Frames[K].Offset, Name, SrcFile, Line);
      if (E.Frames[K].Symbol = '') and (Name <> '') then
      begin
        E.Frames[K].Symbol := Name;
        E.Frames[K].FromMap := True;
      end;
      if (E.Frames[K].Line = 0) and (Line > 0) then
      begin
        E.Frames[K].SrcFile := SrcFile;
        E.Frames[K].Line := Line;
        E.Frames[K].FromMap := True;
      end;
    end;
  end;
end;

{ ---------------------------------------------------------------- sources }

procedure TBugReport.IndexDir(const Dir: string; Depth: Integer);
var
  SR: TSearchRec;
  Ext: string;
begin
  if (Depth > 8) or not DirectoryExists(Dir) then Exit;
  if FindFirst(Dir + '*', faAnyFile, SR) <> 0 then Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if SR.Attr and faDirectory <> 0 then
        IndexDir(Dir + SR.Name + '\', Depth + 1)
      else
      begin
        Ext := LowerCase(ExtractFileExt(SR.Name));
        if (Ext = '.pas') or (Ext = '.inc') or (Ext = '.dpr') or (Ext = '.dpk') then
          FSrcNames.AddObject(LowerCase(SR.Name), TObject(FSrcPaths.Add(Dir + SR.Name)));
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

{ the folders of sources, the first holding a file name winning: the ones given, D7 Studio's
  sources beside the folder of the log or of bugreport.exe (bin\..\source), Delphi 7's Source }
procedure TBugReport.IndexSources;
var
  I: Integer;
begin
  FSrcIndexed := True;
  if FOptions.SourceDirs <> nil then
    for I := 0 to FOptions.SourceDirs.Count - 1 do
      IndexDir(IncludeTrailingPathDelimiter(ExpandFileName(FOptions.SourceDirs[I])), 0);
  IndexDir(ExpandFileName(FLogDir + '..\source\'), 0);
  IndexDir(ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\source\'), 0);
  IndexDir(DelphiRoot + 'Source\', 0);
end;

function TBugReport.FindSource(const SrcFile: string): string;
var
  I: Integer;
begin
  Result := '';
  if SrcFile = '' then Exit;
  if (ExtractFileDrive(SrcFile) <> '') and FileExists(SrcFile) then
  begin
    Result := SrcFile;
    Exit;
  end;
  if not FSrcIndexed then IndexSources;
  if FSrcNames.Find(LowerCase(ExtractFileName(SrcFile)), I) then
    Result := FSrcPaths[Integer(FSrcNames.Objects[I])];
end;

function TBugReport.SourceLines(const FileName: string): TStringList;
var
  I: Integer;
begin
  if FSrcCache.Find(FileName, I) then
  begin
    Result := TStringList(FSrcCache.Objects[I]);
    Exit;
  end;
  Result := TStringList.Create;
  try
    LoadText(FileName, Result);
  except
    Result.Clear;
  end;
  FSrcCache.AddObject(FileName, Result);
end;

{ ---------------------------------------------------------------- writing }

function UserLocaleName: string;
var
  Buf: array[0..84] of WideChar;
begin
  if GetLocaleInfoW(GetUserDefaultLCID, LOCALE_SNAME, Buf, Length(Buf)) > 0 then
    Result := WideToIde(WideString(Buf))
  else
    Result := IntToHex(GetUserDefaultLCID, 4);
end;

procedure TBugReport.WriteSystem;
var
  L: TStringList;
  I, N: Integer;
  Dir, F, S: string;
  CP: Cardinal;
begin
  Heading('System');
  if FStudioExe <> '' then Field('D7 Studio', FileFacts(FStudioExe))
  else Field('D7 Studio', '(D7Studio.exe not found beside the log)');
  Field('Windows', WindowsDescription);
  CP := SystemEncoding.CodePage;
  S := Format('%d for programs', [CP]);
  if CP = CP_UTF8 then S := S + ' (UTF-8 for every program: Windows'' beta option is on)';
  Field('Code page', S + ', user locale ' + UserLocaleName);
  for I := 0 to Screen.MonitorCount - 1 do
    with Screen.Monitors[I] do
    begin
      N := GetDpiForMonitorHandle(Handle);
      S := Format('%d x %d at (%d, %d), %d dpi (%d %%)', [Width, Height, Left, Top, N, MulDiv(N, 100, 96)]);
      if Primary then S := S + ', primary';
      Field(Format('Monitor %d', [I + 1]), S);
    end;
  Field('Delphi 7', DelphiRoot);
  Field('delphi32.exe', FileFacts(FindOnPath(DelphiBin, 'delphi32.exe')));
  { the modernized RTL/VCL: D7 Studio's Setup and patch.ps1 list the files they patched }
  F := DelphiRoot + 'D7Studio\patch.txt';
  if FileExists(F) then
  begin
    L := TStringList.Create;
    try
      LoadText(F, L);
      N := 0;
      for I := 0 to L.Count - 1 do
        if Trim(L[I]) <> '' then Inc(N);
    finally
      L.Free;
    end;
    S := Format('applied: %d files (D7Studio\patch.txt, %s)', [N, TimeText(FileTime(F))]);
    if FileExists(DelphiRoot + 'D7Studio\unins000.exe') then S := S + ', installed by Setup';
  end
  else
    S := 'not applied (no D7Studio\patch.txt)';
  if not FileExists(DelphiRoot + 'Lib\Utf8Mode.dcu') then S := S + ', Lib without Utf8Mode.dcu';
  Field('RTL/VCL patch', S);
  { the run-time packages and the memory manager D7Studio.exe loads: beside it first, then the PATH }
  if FStudioExe <> '' then Dir := ExtractFilePath(FStudioExe) else Dir := '';
  for I := Low(RuntimeModules) to High(RuntimeModules) do
  begin
    F := FindOnPath(Dir, RuntimeModules[I]);
    S := FileFacts(F);
    if (F <> '') and (Dir <> '') and SameText(ExtractFilePath(F), Dir) and
      not SameText(Dir, DelphiBin) then
      S := S + ' - beside D7Studio.exe: loaded before Delphi 7''s';
    Field(RuntimeModules[I], S);
  end;
end;

procedure TBugReport.WriteSettings;
var
  L: TStringList;
  I: Integer;
  F, Desc, S: string;
  Enabled: Boolean;
begin
  Heading('Design packages and experts');
  if FIni = nil then
  begin
    Add('  (no D7Studio.ini beside the log)');
    Exit;
  end;
  L := TStringList.Create;
  try
    if not SettingsPackages(FIni, L) then
      Add('  Design packages: Borland''s standard ones (the settings list none)')
    else
    begin
      Add('  Design packages:');
      for I := 0 to L.Count - 1 do
      begin
        F := L.Names[I];
        Desc := L.ValueFromIndex[I];
        Enabled := Copy(F, 1, 1) <> '-';
        if not Enabled then Delete(F, 1, 1);
        if FileExists(F) then S := FileFacts(F) else S := F + ' (missing)';
        if Enabled then S := 'on   ' + S else S := 'off  ' + S;
        if Desc <> '' then S := S + ' - ' + Desc;
        Add('    ' + S);
      end;
    end;
    ExpertFiles(FIni, SettingsRegKey, L);
    if L.Count = 0 then
      Add('  DLL experts: none')
    else
    begin
      Add('  DLL experts:');
      for I := 0 to L.Count - 1 do
        if FileExists(L[I]) then Add('    ' + FileFacts(L[I]))
        else Add('    ' + L[I] + ' (missing)');
    end;
  finally
    L.Free;
  end;
end;

procedure TBugReport.WriteModules;
var
  I: Integer;
  M: TBugModule;
  S: string;
begin
  if FModules.Count = 0 then Exit;
  Heading('Modules in the call stacks');
  for I := 0 to FModules.Count - 1 do
  begin
    M := TBugModule(FModules.Objects[I]);
    if M.FileName = '' then S := M.Note
    else S := FileFacts(M.FileName) + '; ' + M.Note;
    Field(M.Name, S);
  end;
end;

procedure TBugReport.WriteFrame(const F: TBugFrame);
var
  S, Src: string;
  Lines: TStringList;
  I, First, LastLine: Integer;
  M: TBugModule;
begin
  S := '    ' + FrameText(F.Module, F.Offset, FrameSymbolText(F.Symbol, F.SrcFile, F.Line));
  if F.Stale then S := S + '  [built after this error: not resolved]'
  else if F.FromMap then S := S + '  [map]';
  Add(S);
  if (F.Line <= 0) or (FOptions.Context < 0) then Exit;
  Src := FindSource(F.SrcFile);
  if Src = '' then Exit;
  Lines := SourceLines(Src);
  if F.Line > Lines.Count then Exit;
  M := Module(F.Module);
  if (M.FileTime <> 0) and (FileTime(Src) > M.FileTime + MapSlack) then
    Add('        (' + Src + ' changed after ' + M.Name + ' was built: the lines may have moved)');
  First := F.Line - FOptions.Context;
  if First < 1 then First := 1;
  LastLine := F.Line + FOptions.Context;
  if LastLine > Lines.Count then LastLine := Lines.Count;
  for I := First to LastLine do
    if I = F.Line then AddFmt('      > %5d  %s', [I, Lines[I - 1]])
    else AddFmt('        %5d  %s', [I, Lines[I - 1]]);
end;

procedure TBugReport.WriteErrors;
var
  I, K: Integer;
  G: TBugGroup;
  E: TBugEntry;
  Contexts: TStringList;
  S: string;
begin
  if FEntries.Count = 0 then
  begin
    Heading('Errors');
    if FileExists(FOptions.LogFile) then Add('  The log holds no error.')
    else Add('  There is no log: D7 Studio has logged no error.');
    Exit;
  end;
  Heading(Format('Errors: %d, %d different (the newest first)', [FEntries.Count, FGroups.Count]));
  Contexts := TStringList.Create;
  try
    for I := 0 to FGroups.Count - 1 do
    begin
      G := TBugGroup(FGroups[I]);
      E := G.Newest;
      Add('');
      if G.Entries.Count = 1 then
        S := 'once, ' + E.TimeText
      else
        S := Format('%d times, %s to %s', [G.Entries.Count, TBugEntry(G.Entries[0]).TimeText, E.TimeText]);
      AddFmt('[%d] %s (%s)', [I + 1, E.ExClass, S]);
      Contexts.Clear;
      S := '';
      for K := 0 to G.Entries.Count - 1 do
        if Contexts.IndexOf(TBugEntry(G.Entries[K]).Context) < 0 then
        begin
          Contexts.Add(TBugEntry(G.Entries[K]).Context);
          if S <> '' then S := S + '; ';
          S := S + TBugEntry(G.Entries[K]).Context;
        end;
      if S = '' then S := '(none)';
      Field('Where', S);
      if E.Msg = '' then E.Msg := '(none)';
      Field('Message', StringReplace(E.Msg, #13#10, #13#10 + StringOfChar(' ', 21), [rfReplaceAll]));
      if Length(E.Frames) = 0 then
        Add('  (no call stack logged)')
      else
      begin
        Add('  Call stack:');
        for K := 0 to Length(E.Frames) - 1 do WriteFrame(E.Frames[K]);
      end;
    end;
  finally
    Contexts.Free;
  end;
end;

procedure TBugReport.WriteLog;
var
  I, K: Integer;
  E: TBugEntry;
begin
  if FEntries.Count = 0 then Exit;
  if FLogged > FEntries.Count then
    Heading(Format('The log (its newest %d entries of %d)', [FEntries.Count, FLogged]))
  else
    Heading('The log');
  for I := 0 to FEntries.Count - 1 do
  begin
    E := TBugEntry(FEntries[I]);
    for K := 0 to E.Raw.Count - 1 do Add(E.Raw[K]);
    Add('');
  end;
end;

procedure TBugReport.Run(out Summary: string);
var
  I, K: Integer;
  E: TBugEntry;
begin
  ReadLog;
  GroupEntries;
  for I := 0 to FEntries.Count - 1 do
  begin
    E := TBugEntry(FEntries[I]);
    for K := 0 to Length(E.Frames) - 1 do Module(E.Frames[K].Module);
  end;
  Resolve;
  Add('D7 Studio - bug report');
  Add('======================');
  Add('');
  Field('Made', FormatDateTime(CrashTimeFormat, Now));
  Field('Log', ExpandFileName(FOptions.LogFile));
  Field('Report it at', RepositoryUrl + '/issues - with this file, and what you did when it happened');
  WriteSystem;
  WriteSettings;
  WriteModules;
  WriteErrors;
  WriteLog;
  WriteFileU(FOptions.OutFile, #$EF#$BB#$BF + FOut.Text);
  if FEntries.Count = 0 then Summary := 'no errors logged'
  else Summary := Format('%d errors, %d different', [FEntries.Count, FGroups.Count]);
  if FLogged > FEntries.Count then Summary := Summary + Format(' (the newest of %d)', [FLogged]);
end;

procedure WriteBugReport(const Options: TBugReportOptions; out Summary: string);
var
  R: TBugReport;
begin
  R := TBugReport.Create(Options);
  try
    R.Run(Summary);
  finally
    R.Free;
  end;
end;

end.
