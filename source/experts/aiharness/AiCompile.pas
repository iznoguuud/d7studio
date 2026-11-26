{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiCompile;

{ The harness's compile tool (compile_project): the project compiled by Delphi's command-line
  compiler, dcc32, with what the editor holds - unsaved changes included - and its messages
  returned with file and line.

  The project's own output is not touched: everything goes to a scratch folder
  (AiCompileCore.ScratchFolder) -
    src\<project file>  a copy of the project file whose "in" paths are absolute and name the
                        scratch copies (src\m<n>\) of the units with unsaved changes (text or
                        form) and of the units dcc32 cannot read as they are (a BOM, UTF-16);
    src\<project>.cfg   the project's .cfg (written by the IDE when the project is saved): the
                        project's folder and the copied units' own folders first on the unit,
                        include, resource and object paths, then the .cfg's own, then the IDE's
                        library path (Delphi 7 writes the .cfg without it); the output folders
                        replaced;
    out\, dcu\          what the compiler writes.
  It makes the project (-M) like the IDE: units whose .dcu is up to date are not compiled again.
  The .dcu of every unit copied, this time or the last time, is deleted first, so that one
  compiled from changes that were undone since is not used. dcc32 runs in the project's folder,
  so the relative paths of the .cfg stay right. dcc32 reads its files and arguments in the
  system code page: the paths it gets are the short (8.3) ones when they hold other characters
  (the IDE's strings are UTF-8 in D7 Studio), and the files written for it are in the system
  code page; the names it prints are mapped back. Files with unsaved changes that the project
  file does not name (include files, units found on the search path) are compiled from disk; the
  result says so.
  The compiler runs in the worker thread (the IDE stays responsive); the IDE's parts run in the
  main thread. The messages also go to the IDE's Messages view, in the group "AI Harness". }

interface

uses
  AiCore;

procedure AddCompileTools(List: TAiToolList);

implementation

uses
  Windows, SysUtils, Classes, ToolsAPI, AiJson, AiText, AiIde, AiCompileCore, AiProcess;

const
  GroupName = 'AI Harness';
  MaxListed = 100;
  MirroredList = 'mirrored.txt';

type
  TCompileTool = class(TAiTool)
  private
    FInput: TJson;
    FProblem: string;
    FDcc: string;
    FCmd: string;
    FDir: string;              // the project's folder
    FRunDir: string;           // the same as dcc32 names it
    FProjFile: string;
    FScratch: string;
    FCompileFile: string;
    FMap: TStringList;         // original=scratch copy (IDE strings)
    FBack: TStringList;        // a scratch copy as dcc32 names it=original
    FFound: TStringList;       // the project file's units (originals)
    FNotIncluded: TStringList;
    FIncluded: Integer;
    FOutput: string;
    FExitCode: Integer;
    FResultText: string;
    FSummary: string;
    procedure Mirror(const F, Text: string; FE: IOTAFormEditor);
    procedure Prepare;
    procedure Report;
    function OriginalOf(const FileName: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    function RunsInMainThread: Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

procedure AddCompileTools(List: TAiToolList);
begin
  List.Add(TCompileTool.Create);
end;

procedure DeleteTree(const Dir: string);
var
  SR: TSearchRec;
  D: string;
begin
  D := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(D + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          DeleteTree(D + SR.Name);
          RemoveDir(D + SR.Name);
        end
        else DeleteFile(D + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
end;

function GetShortPathNameW_(lpszLongPath, lpszShortPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall;
  external kernel32 name 'GetShortPathNameW';
function GetLongPathNameW_(lpszShortPath, lpszLongPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall;
  external kernel32 name 'GetLongPathNameW';

{ a path as dcc32 can read it (an IDE string): itself when it is ASCII, else its short (8.3)
  form when the volume has one }
function CompilerPath(const P: string): string;
var
  Buf: array[0..1023] of WideChar;
  N: DWORD;
begin
  Result := P;
  if not HasHighBytes(P) then Exit;
  N := GetShortPathNameW_(PWideChar(CodePageToWide(P, CP_ACP)), Buf, Length(Buf));
  if (N > 0) and (N < DWORD(Length(Buf))) then Result := WideToCodePage(PWideChar(@Buf[0]), CP_ACP);
end;

{ a path for a file dcc32 reads: the compiler's form in the system code page }
function CompilerText(const P: string): string;
begin
  Result := IdeToSystem(CompilerPath(P));
end;

{ the long form of a path (an IDE string) that may hold short (8.3) names }
function LongPath(const P: string): string;
var
  Buf: array[0..1023] of WideChar;
  N: DWORD;
begin
  Result := P;
  if Pos('~', P) = 0 then Exit;
  N := GetLongPathNameW_(PWideChar(CodePageToWide(P, CP_ACP)), Buf, Length(Buf));
  if (N > 0) and (N < DWORD(Length(Buf))) then Result := WideToCodePage(PWideChar(@Buf[0]), CP_ACP);
end;

function NoSlash(const Dir: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(Dir);
  if (Length(Result) = 2) and (Result[2] = ':') then Result := Result + '\';
end;

{ each folder of a ';' list (an IDE string) in the compiler's form and code page }
function CompilerList(const Dirs: string): string;
var
  P, Q: Integer;
  D: string;
begin
  Result := '';
  P := 1;
  while P <= Length(Dirs) do
  begin
    Q := P;
    while (Q <= Length(Dirs)) and (Dirs[Q] <> ';') do Inc(Q);
    D := Trim(Copy(Dirs, P, Q - P));
    if D <> '' then
    begin
      if Result <> '' then Result := Result + ';';
      Result := Result + CompilerText(NoSlash(D));
    end;
    P := Q + 1;
  end;
end;

{ the project's .cfg for the scratch build: Front (the project's folder and the copied units'
  folders) first on the paths, then the .cfg's own, then LibPath (the IDE's library path); the
  outputs replaced. Front, LibPath and Scratch are in the system code page already. }
function ScratchCfg(const CfgFile, Front, LibPath, Scratch: string): string;
var
  L, R: TStringList;
  I, K: Integer;
  S, Flag, Value, Tail: string;
  Seen: array[0..3] of Boolean;
const
  PathFlags: array[0..3] of string = ('-U', '-I', '-R', '-O');
begin
  L := TStringList.Create;
  R := TStringList.Create;
  try
    if FileExists(CfgFile) then L.Text := ReadFileBytes(CfgFile);
    if LibPath <> '' then Tail := ';' + LibPath else Tail := '';
    for K := 0 to 3 do Seen[K] := False;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if S = '' then Continue;
      Flag := UpperCase(Copy(S, 1, 3));
      if (Flag = '-LE') or (Flag = '-LN') or (UpperCase(Copy(S, 1, 2)) = '-E') or (UpperCase(Copy(S, 1, 2)) = '-N') then
        Continue;
      Flag := UpperCase(Copy(S, 1, 2));
      for K := 0 to 3 do
        if (Flag = PathFlags[K]) and not ((K = 2) and (UpperCase(Copy(S, 1, 3)) = '-R+')) then
        begin
          Value := Copy(S, 3, MaxInt);
          if (Length(Value) >= 2) and (Value[1] = '"') and (Value[Length(Value)] = '"') then
            Value := Copy(Value, 2, Length(Value) - 2);
          S := PathFlags[K] + '"' + Front + ';' + Value + Tail + '"';
          Seen[K] := True;
          Break;
        end;
      R.Add(S);
    end;
    for K := 0 to 3 do
      if not Seen[K] then R.Add(PathFlags[K] + '"' + Front + Tail + '"');
    R.Add('-E"' + NoSlash(Scratch + 'out') + '"');
    R.Add('-N"' + NoSlash(Scratch + 'dcu') + '"');
    R.Add('-LE"' + NoSlash(Scratch + 'out') + '"');
    R.Add('-LN"' + NoSlash(Scratch + 'out') + '"');
    Result := R.Text;
  finally
    R.Free;
    L.Free;
  end;
end;

{ the form of a form editor as a form file, as INTAFormEditor.GetFormResource gives it - in the
  form file's format: its text, or the binary form file (the resource header before the TPF0
  stream; RLINK32 cannot open the stream alone); '' when there is none }
function FormFile(FE: IOTAFormEditor): string;
var
  N: INTAFormEditor;
  S: TStringStream;
begin
  Result := '';
  if not Supports(FE, INTAFormEditor, N) then Exit;
  S := TStringStream.Create('');
  try
    N.GetFormResource(S);
    Result := S.DataString;
  finally
    S.Free;
  end;
end;

{ the file starts with a byte order mark: dcc32 cannot read it as it is }
function HasBom(const FileName: string): Boolean;
var
  F: TFileStream;
  B: array[0..2] of Byte;
  N: Integer;
begin
  Result := False;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      FillChar(B, SizeOf(B), 0);
      N := F.Read(B, 3);
    finally
      F.Free;
    end;
  except
    Exit;
  end;
  Result := ((N >= 3) and (B[0] = $EF) and (B[1] = $BB) and (B[2] = $BF)) or
    ((N >= 2) and (((B[0] = $FF) and (B[1] = $FE)) or ((B[0] = $FE) and (B[1] = $FF))));
end;

{ a file's text in the system code page, the encoding it has on disk converted }
function SystemText(const FileName: string): string;
var
  Enc: TKitFileEncoding;
begin
  Result := EncodeText(ReadTextFile(FileName, Enc), feAnsi);
end;

{ ---------------------------------------------------------------- TCompileTool }

constructor TCompileTool.Create;
begin
  inherited Create;
  FMap := TStringList.Create;
  FBack := TStringList.Create;
  FFound := TStringList.Create;
  FNotIncluded := TStringList.Create;
end;

destructor TCompileTool.Destroy;
begin
  FMap.Free;
  FBack.Free;
  FFound.Free;
  FNotIncluded.Free;
  inherited;
end;

function TCompileTool.Name: string;
begin
  Result := 'compile_project';
end;

function TCompileTool.Description: string;
begin
  Result := 'Compiles a project (the active one by default) with Delphi 7''s command-line compiler and returns its ' +
    'errors, warnings and hints with file and line. It compiles what the editor holds, unsaved changes included, ' +
    'and writes the program and the .dcu files to a scratch folder: the project''s own output folders and files ' +
    'are not touched. Call it after you change code to check the change, and fix what it reports.';
end;

procedure TCompileTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'project', 'string', 'The project''s file or name, for a project of the group that is not the ' +
    'active one.', False);
  SchemaProp(Schema, 'show_in_ide', 'boolean', 'Also list the messages in the IDE''s Messages view (default true).', False);
end;

function TCompileTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('project');
end;

function TCompileTool.RunsInMainThread: Boolean;
begin
  Result := False;
end;

procedure TCompileTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
begin
  FInput := Input;
  FProblem := '';
  Context.RunInMainThread(Prepare);
  if FProblem <> '' then
  begin
    Res.Fail(FProblem);
    Exit;
  end;
  Context.Status('Compiling ' + IdeToUtf8(ExtractFileName(FProjFile)) + ' ...');
  FExitCode := RunConsole(FCmd, FRunDir, FOutput, 10 * 60 * 1000, Context.Cancelled);
  if Context.Cancelled then
  begin
    Res.Fail('The compile was stopped.');
    Exit;
  end;
  Context.RunInMainThread(Report);
  Res.Ok(FResultText, FSummary);
end;

{ a scratch copy of the unit F with Text (the system code page) and its form: the designer's
  when it has unsaved changes, else the file's }
procedure TCompileTool.Mirror(const F, Text: string; FE: IOTAFormEditor);
var
  Copy_, Form, Dfm: string;
begin
  Copy_ := FScratch + 'src\m' + IntToStr(FMap.Count + 1) + '\' + ExtractFileName(F);
  ForceDirectories(ExtractFilePath(Copy_));
  WriteFileBytes(Copy_, Text);
  Form := ChangeFileExt(F, '.dfm');
  Dfm := '';
  if (FE <> nil) and (FE.Modified or not FileExists(Form)) then Dfm := FormFile(FE);
  if Dfm <> '' then WriteFileBytes(ChangeFileExt(Copy_, '.dfm'), Dfm)
  else if FileExists(Form) then CopyFile(PChar(Form), PChar(ChangeFileExt(Copy_, '.dfm')), False);
  FMap.Add(F + '=' + Copy_);
end;

{ main thread: the scratch folder, the copies, the command line }
procedure TCompileTool.Prepare;
var
  P: IOTAProject;
  E: IOTASourceEditor;
  Open, Units, SysMap, Gone: TStringList;
  I: Integer;
  F, Ext, Copy_, ProjText, SysDir, Front, Dcu: string;
begin
  FMap.Clear;
  FBack.Clear;
  FFound.Clear;
  FNotIncluded.Clear;
  FIncluded := 0;
  P := FindProject(Utf8ToIde(FInput.Str('project')));
  if P = nil then
  begin
    FProblem := 'No such project is open.';
    Exit;
  end;
  FProjFile := P.FileName;
  Ext := LowerCase(ExtractFileExt(FProjFile));
  if (Ext <> '.dpr') and (Ext <> '.dpk') then
  begin
    FProblem := 'Only Delphi projects (.dpr) and packages (.dpk) can be compiled: ' + IdeToUtf8(FProjFile);
    Exit;
  end;
  FDcc := DelphiBinFolder + 'dcc32.exe';
  if not FileExists(FDcc) then
  begin
    FProblem := 'Delphi''s compiler was not found (' + IdeToUtf8(FDcc) + ').';
    Exit;
  end;
  FDir := ExtractFilePath(FProjFile);
  FScratch := ScratchFolder(FProjFile);
  ForceDirectories(FScratch + 'src');
  ForceDirectories(FScratch + 'out');
  ForceDirectories(FScratch + 'dcu');
  DeleteTree(FScratch + 'src');
  { the project file's text in the system code page }
  E := FindSourceEditor(FProjFile);
  if E <> nil then ProjText := IdeToSystem(EditorText(E)) else ProjText := SystemText(FProjFile);
  SysDir := CompilerText(NoSlash(FDir));
  Open := TStringList.Create;
  Units := TStringList.Create;
  SysMap := TStringList.Create;
  Gone := TStringList.Create;
  try
    { the units the project file names, as dcc32 will look for them }
    RewriteUnitPaths(ProjText, SysDir, '', Units);
    for I := 0 to Units.Count - 1 do Units[I] := LongPath(SystemToIde(Units[I]));
    { the open units with unsaved changes (text or form) }
    OpenFiles(Open);
    for I := 0 to Open.Count - 1 do
    begin
      F := Open[I];
      if (Open.Objects[I] = nil) or SameText(F, FProjFile) then Continue;
      Ext := LowerCase(ExtractFileExt(F));
      if (Ext <> '.pas') and (Ext <> '.inc') then Continue;
      E := FindSourceEditor(F);
      if E <> nil then Mirror(F, IdeToSystem(EditorText(E)), FormEditorOf(FindModuleOf(F)));
    end;
    { the project's units dcc32 cannot read as they are }
    for I := 0 to Units.Count - 1 do
    begin
      F := Units[I];
      if (FMap.IndexOfName(F) < 0) and FileExists(F) and HasBom(F) then Mirror(F, SystemText(F), nil);
    end;
    { the project file again, its units' paths absolute and the copies named; the copies' folders
      first on the include and resource paths ($I and $R look next to the unit first) }
    Front := SysDir;
    for I := 0 to FMap.Count - 1 do
    begin
      F := FMap.Names[I];
      Copy_ := Copy(FMap[I], Length(F) + 2, MaxInt);
      SysMap.Add(CompilerText(F) + '=' + CompilerText(Copy_));
      FBack.Add(CompilerPath(Copy_) + '=' + F);
      if Pos(';' + CompilerText(NoSlash(ExtractFilePath(F))) + ';', ';' + Front + ';') = 0 then
        Front := Front + ';' + CompilerText(NoSlash(ExtractFilePath(F)));
    end;
    FCompileFile := FScratch + 'src\' + ExtractFileName(FProjFile);
    WriteFileBytes(FCompileFile, RewriteUnitPaths(ProjText, SysDir, SysMap.Text, FFound));
    for I := 0 to FMap.Count - 1 do
      if FFound.IndexOf(SysMap.Names[I]) >= 0 then Inc(FIncluded)
      else FNotIncluded.Add(FMap.Names[I]);
    for I := 0 to FFound.Count - 1 do FFound[I] := LongPath(SystemToIde(FFound[I]));
    { no .dcu of a unit copied the last time or now: it may hold changes undone since }
    if FileExists(FScratch + MirroredList) then Gone.Text := ReadFileBytes(FScratch + MirroredList);
    for I := 0 to FMap.Count - 1 do Gone.Add(ChangeFileExt(ExtractFileName(FMap.Names[I]), ''));
    for I := 0 to Gone.Count - 1 do
    begin
      Dcu := FScratch + 'dcu\' + Trim(Gone[I]) + '.dcu';
      if (Trim(Gone[I]) <> '') and FileExists(Dcu) then DeleteFile(Dcu);
    end;
    Gone.Clear;
    for I := 0 to FMap.Count - 1 do Gone.Add(ChangeFileExt(ExtractFileName(FMap.Names[I]), ''));
    WriteFileBytes(FScratch + MirroredList, Gone.Text);
  finally
    Gone.Free;
    SysMap.Free;
    Units.Free;
    Open.Free;
  end;
  WriteFileBytes(ChangeFileExt(FCompileFile, '.cfg'),
    ScratchCfg(ChangeFileExt(FProjFile, '.cfg'), Front, CompilerList(IdeLibraryPath), CompilerText(FScratch)));
  if FileExists(ChangeFileExt(FProjFile, '.res')) then
    CopyFile(PChar(ChangeFileExt(FProjFile, '.res')), PChar(ChangeFileExt(FCompileFile, '.res')), False);
  FCmd := Format('"%s" -Q -M "%s"', [CompilerPath(FDcc), CompilerPath(FCompileFile)]);
  FRunDir := CompilerPath(FDir);
end;

{ the original file of a name the compiler printed (a name it printed without a folder stays
  so when it is not one of the project's units: the search path found it) }
function TCompileTool.OriginalOf(const FileName: string): string;
var
  I: Integer;
  F: string;
begin
  F := FileName;
  Result := F;
  if F = '' then Exit;
  if SameText(F, CompilerPath(FCompileFile)) or SameText(LongPath(F), FCompileFile) or
    SameText(F, ExtractFileName(FCompileFile)) then
  begin
    Result := FProjFile;
    Exit;
  end;
  I := FBack.IndexOfName(F);
  if I >= 0 then
  begin
    Result := Copy(FBack[I], Length(FBack.Names[I]) + 2, MaxInt);
    Exit;
  end;
  if (Length(F) > 1) and ((F[2] = ':') or (Copy(F, 1, 2) = '\\')) then
  begin
    Result := LongPath(F);
    Exit;
  end;
  for I := 0 to FFound.Count - 1 do
    if SameText(ExtractFileName(FFound[I]), F) then
    begin
      Result := FFound[I];
      Exit;
    end;
  if FileExists(FDir + F) then Result := FDir + F;
end;

{ main thread: the messages read, shown in the IDE, and the result written }
procedure TCompileTool.Report;
var
  Msgs: TAiCompilerMessages;
  Services: IOTAMessageServices;
  Group: IOTAMessageGroup;
  B: TStringList;
  I, Errors, Warnings, Hints: Integer;
  M: TAiCompilerMessage;
  Ref: Pointer;
  Tail: string;
begin
  Msgs := TAiCompilerMessages.Create;
  B := TStringList.Create;
  try
    ParseCompilerOutput(SystemToIde(FOutput), Msgs);
    for I := 0 to Msgs.Count - 1 do Msgs[I].FileName := OriginalOf(Msgs[I].FileName);
    Errors := Msgs.CountOf('Error') + Msgs.CountOf('Fatal');
    Warnings := Msgs.CountOf('Warning');
    Hints := Msgs.CountOf('Hint');
    if FInput.Bool('show_in_ide', True) then
    begin
      Services := BorlandIDEServices as IOTAMessageServices;
      Group := Services.GetGroup(GroupName);
      if Group = nil then Group := Services.AddMessageGroup(GroupName);
      Services.ClearMessageGroup(Group);
      if (FExitCode = 0) and (Msgs.Count = 0) then
        Services.AddTitleMessage('AI Harness: ' + ExtractFileName(FProjFile) + ' compiled without messages.', Group)
      else
        for I := 0 to Msgs.Count - 1 do
        begin
          M := Msgs[I];
          Services.AddToolMessage(M.FileName, M.Kind + ': ' + M.Text, 'AI', M.Line, 1, nil, Ref, Group);
        end;
    end;
    if FExitCode = 0 then
      B.Add(Format('Compiled %s successfully: %d errors, %d warnings, %d hints.', [FProjFile, Errors, Warnings, Hints]))
    else
      B.Add(Format('The compile of %s failed: %d errors, %d warnings, %d hints.', [FProjFile, Errors, Warnings, Hints]));
    if FIncluded > 0 then B.Add(Format('The unsaved changes of %d file(s) were compiled.', [FIncluded]));
    for I := 0 to FNotIncluded.Count - 1 do
      B.Add('Unsaved changes in ' + FNotIncluded[I] + ' were not compiled (the project file does not name it): ' +
        'save it first (save_files) to include them.');
    for I := 0 to Msgs.Count - 1 do
    begin
      if I >= MaxListed then
      begin
        B.Add(Format('... and %d more messages.', [Msgs.Count - MaxListed]));
        Break;
      end;
      M := Msgs[I];
      if M.FileName <> '' then B.Add(Format('%s(%d): %s: %s', [DisplayPath(M.FileName), M.Line, M.Kind, M.Text]))
      else B.Add(M.Kind + ': ' + M.Text);
    end;
    if (FExitCode <> 0) and (Msgs.Count = 0) then
    begin
      Tail := Trim(SystemToIde(FOutput));
      if Length(Tail) > 3000 then Tail := '...' + Copy(Tail, Length(Tail) - 3000, MaxInt);
      B.Add(Format('dcc32 ended with exit code %d. Its output:', [FExitCode]));
      B.Add(Tail);
    end;
    FResultText := IdeToUtf8(B.Text);
    if FExitCode = 0 then FSummary := Format('compiled: %d warnings, %d hints', [Warnings, Hints])
    else FSummary := Format('%d errors', [Errors]);
  finally
    B.Free;
    Msgs.Free;
  end;
end;

end.
