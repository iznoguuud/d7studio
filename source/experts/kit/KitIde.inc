{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

{ The IDE experts' access to the IDE through Delphi 7's Open Tools API (source\experts\kit: the AI
  harness's unit AiIde, the Git expert's GitIde) - standard ToolsAPI only, so it works in D7
  Studio and in Delphi 7's own IDE: projects, open modules, editor buffers (read with
  IOTAEditReader, changed with an undoable IOTAEditWriter), the state of the code editor. Call it
  in the IDE's main thread.
  Editor text is in the IDE's code page (UTF-8 in D7 Studio's UTF-8 mode); buffer positions are
  0-based offsets into that text, as the reader and the writer count them.
  Also an expert's self-test in the IDE: TKitSelfTest.
  The unit (interface: uses Windows, SysUtils, Classes, Forms, ExtCtrls, ToolsAPI and the expert's
  text unit of KitText.inc) includes this file in its interface with KIT_INTERFACE defined and again in its
  implementation. }

{$IFDEF KIT_INTERFACE}

function ModuleServices: IOTAModuleServices;
function EditorServices: IOTAEditorServices;
function IdeName: string;

function ProjectGroup: IOTAProjectGroup;
function ActiveProject: IOTAProject;
function ProjectFolder(P: IOTAProject): string;
{ the project file first, then the files of its modules }
procedure ProjectFiles(P: IOTAProject; L: TStrings);

function FindModuleOf(const FileName: string): IOTAModule;
{ the file of module M's editor Index; '' when the IDE gives no editor there (Delphi 7's may not) }
function KitEditorFile(M: IOTAModule; Index: Integer): string;
function SourceEditorOf(Module: IOTAModule; const FileName: string): IOTASourceEditor;
function FormEditorOf(Module: IOTAModule): IOTAFormEditor;
{ the source editor of an open file; nil when it is not open }
function FindSourceEditor(const FileName: string): IOTASourceEditor;
{ the file opened in the IDE when it is not open yet (KitOpenFile); nil when it cannot be }
function OpenSourceEditor(const FileName: string): IOTASourceEditor;
{ a file opened in the IDE as its text and shown: a project, package or project group file through a
  module creator of the existing file, owned by no project (a module of its text in Delphi 7's IDE
  too) - IOTAActionServices.OpenFile opens those as projects, in a group of their own -, any other
  file with OpenFile; False: not opened }
function KitOpenFile(const FileName: string): Boolean;
{ the files open in the IDE; Objects[i] <> nil when the file's module has unsaved changes (its
  text or its form) }
procedure OpenFiles(L: TStrings);
{ one of the module's editors (its text, its form) has unsaved changes }
function ModuleModified(M: IOTAModule): Boolean;

function EditorText(E: IOTASourceEditor): string;
{ replaces the text from StartPos up to EndPos (0-based offsets) with Text, undoable }
procedure ReplaceText(E: IOTASourceEditor; StartPos, EndPos: Integer; const Text: string);
{ several replacements in one undoable writer: Starts / Ends / Texts sorted by position }
procedure ReplaceTexts(E: IOTASourceEditor; Starts, Ends: array of Integer; Texts: TStrings);

{ a file's text as UTF-8: from its editor when the file is open (Modified: it has unsaved
  changes), else from disk }
function ReadFileUtf8(const FileName: string; out FromEditor, Modified: Boolean): string;
{ shows the file in the code editor with the cursor at Line, Column (1-based) }
procedure ShowFileAt(const FileName: string; Line, Column: Integer);
function TopView: IOTAEditView;
{ the offset of the cursor of View }
function CursorOffset(View: IOTAEditView): Integer;
{ the code editor's selection as a range that can be replaced: a visible stream block (the
  usual selection, inclusive or not), its offsets and text; False for no selection and for line
  and column blocks }
function SelectionOf(View: IOTAEditView; out StartPos, EndPos: Integer; out Text: string): Boolean;
{ the text of the code editor's visible selection, whatever its kind; '' when there is none }
function SelectedText(View: IOTAEditView): string;

type
  { an expert's self-test in the IDE, made by a menu command: it runs (Run) from a timer, so that
    the command returns at once. Its lines go to the log, the file the environment variable
    LogVariable names (none: no log): PASS or FAIL for each check, an exception that ends the run
    as FAIL exception with its code address (KitAddrInfo: the package's map names the routine), and
    last DONE passed=N failed=M. Dir: the scratch folder DirVariable names, with a backslash }
  TKitSelfTest = class
  private
    FTimer: TTimer;
    procedure Tick(Sender: TObject);
  protected
    FLog: string;
    FDir: string;
    FPassed: Integer;
    FFailed: Integer;
    procedure Run; virtual; abstract;
    { after the DONE line: nothing }
    procedure Finished; virtual;
    procedure Say(const S: string);
    { PASS Name, else FAIL Name: Detail - its lines joined by ' | ', at most 1500 characters }
    procedure Check(Cond: Boolean; const Name: string; const Detail: string = '');
  public
    constructor Create(const LogVariable, DirVariable: string);
    destructor Destroy; override;
  end;

{$ELSE}

function ModuleServices: IOTAModuleServices;
begin
  Result := BorlandIDEServices as IOTAModuleServices;
end;

function EditorServices: IOTAEditorServices;
begin
  Result := BorlandIDEServices as IOTAEditorServices;
end;

function IdeName: string;
begin
  Result := Application.Title;
  if Result = '' then Result := 'the Delphi IDE';
end;

function ProjectGroup: IOTAProjectGroup;
var
  S: IOTAModuleServices;
  I: Integer;
begin
  Result := nil;
  S := ModuleServices;
  for I := 0 to S.ModuleCount - 1 do
    if Supports(S.Modules[I], IOTAProjectGroup, Result) then Exit;
end;

function ActiveProject: IOTAProject;
var
  G: IOTAProjectGroup;
  S: IOTAModuleServices;
  I: Integer;
begin
  Result := nil;
  G := ProjectGroup;
  if G <> nil then Result := G.ActiveProject;
  if Result <> nil then Exit;
  S := ModuleServices;
  for I := 0 to S.ModuleCount - 1 do
    if Supports(S.Modules[I], IOTAProject, Result) then Exit;
end;

function ProjectFolder(P: IOTAProject): string;
begin
  if P = nil then Result := '' else Result := ExtractFilePath(P.FileName);
end;

procedure ProjectFiles(P: IOTAProject; L: TStrings);
var
  I: Integer;
  F: string;
begin
  if P = nil then Exit;
  L.Add(P.FileName);
  for I := 0 to P.GetModuleCount - 1 do
  begin
    F := P.GetModule(I).FileName;
    if (F <> '') and (L.IndexOf(F) < 0) then L.Add(F);
  end;
end;

function FindModuleOf(const FileName: string): IOTAModule;
var
  S: IOTAModuleServices;
  I, J: Integer;
  M: IOTAModule;
begin
  Result := nil;
  if FileName = '' then Exit;
  S := ModuleServices;
  for I := 0 to S.ModuleCount - 1 do
  begin
    M := S.Modules[I];
    if SameText(M.FileName, FileName) then
    begin
      Result := M;
      Exit;
    end;
    for J := 0 to M.GetModuleFileCount - 1 do
      if SameText(KitEditorFile(M, J), FileName) then
      begin
        Result := M;
        Exit;
      end;
  end;
end;

function KitEditorFile(M: IOTAModule; Index: Integer): string;
var
  E: IOTAEditor;
begin
  E := M.GetModuleFileEditor(Index);
  if E = nil then Result := '' else Result := E.FileName;
end;

function SourceEditorOf(Module: IOTAModule; const FileName: string): IOTASourceEditor;
var
  I: Integer;
  E: IOTASourceEditor;
  First: IOTASourceEditor;
begin
  Result := nil;
  First := nil;
  if Module = nil then Exit;
  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTASourceEditor, E) then
    begin
      if (FileName <> '') and SameText(E.FileName, FileName) then
      begin
        Result := E;
        Exit;
      end;
      if First = nil then First := E;
    end;
  if FileName = '' then Result := First
  else if (First <> nil) and SameText(ExtractFileExt(FileName), ExtractFileExt(First.FileName)) and
    SameText(Module.FileName, FileName) then Result := First;
end;

function FormEditorOf(Module: IOTAModule): IOTAFormEditor;
var
  I: Integer;
begin
  Result := nil;
  if Module = nil then Exit;
  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTAFormEditor, Result) then Exit;
  Result := nil;
end;

function FindSourceEditor(const FileName: string): IOTASourceEditor;
begin
  Result := SourceEditorOf(FindModuleOf(FileName), FileName);
end;

function OpenSourceEditor(const FileName: string): IOTASourceEditor;
begin
  Result := FindSourceEditor(FileName);
  if Result <> nil then Exit;
  if not FileExists(FileName) then Exit;
  KitOpenFile(FileName);
  Result := FindSourceEditor(FileName);
end;

type
  { a creator's text (IOTAFile): its age the file's }
  TKitFile = class(TInterfacedObject, IOTAFile)
  private
    FSource: string;
    FAge: TDateTime;
  public
    constructor Create(const ASource: string; AAge: TDateTime);
    function GetSource: string;
    function GetAge: TDateTime;
  end;

  { a module creator of an existing file: the IDE opens it as a module of its text, shown, in no
    project. The text is the creator's: Delphi 7 shows a text creator's existing file with the text
    NewImplSource gives and does not read the file - with none, an empty module }
  TKitFileCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

constructor TKitFile.Create(const ASource: string; AAge: TDateTime);
begin
  inherited Create;
  FSource := ASource;
  FAge := AAge;
end;

function TKitFile.GetSource: string;
begin
  Result := FSource;
end;

function TKitFile.GetAge: TDateTime;
begin
  Result := FAge;
end;

constructor TKitFileCreator.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TKitFileCreator.GetCreatorType: string; begin Result := sText; end;
function TKitFileCreator.GetExisting: Boolean; begin Result := True; end;
function TKitFileCreator.GetFileSystem: string; begin Result := ''; end;
function TKitFileCreator.GetOwner: IOTAModule; begin Result := nil; end;
function TKitFileCreator.GetUnnamed: Boolean; begin Result := False; end;
function TKitFileCreator.GetAncestorName: string; begin Result := ''; end;
function TKitFileCreator.GetImplFileName: string; begin Result := FFileName; end;
function TKitFileCreator.GetIntfFileName: string; begin Result := ''; end;
function TKitFileCreator.GetFormName: string; begin Result := ''; end;
function TKitFileCreator.GetMainForm: Boolean; begin Result := False; end;
function TKitFileCreator.GetShowForm: Boolean; begin Result := False; end;
function TKitFileCreator.GetShowSource: Boolean; begin Result := True; end;
function TKitFileCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile; begin Result := nil; end;
{ the file's text as an IDE string (nil when it cannot be read) }
function TKitFileCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
var
  E: TKitFileEncoding;
  Text: string;
  Age: Integer;
begin
  Result := nil;
  try
    Text := Utf8ToIde(ReadTextFile(FFileName, E));
  except
    on Exception do Exit;
  end;
  Age := FileAge(FFileName);
  if Age = -1 then Result := TKitFile.Create(Text, -1)
  else Result := TKitFile.Create(Text, FileDateToDateTime(Age));
end;

function TKitFileCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TKitFileCreator.FormCreated(const FormEditor: IOTAFormEditor); begin end;

function KitOpenFile(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  if (Ext = '.dpr') or (Ext = '.dpk') or (Ext = '.bpg') then
    Result := ModuleServices.CreateModule(TKitFileCreator.Create(FileName)) <> nil
  else
    Result := (BorlandIDEServices as IOTAActionServices).OpenFile(FileName);
end;

function ModuleModified(M: IOTAModule): Boolean;
var
  J: Integer;
  E: IOTAEditor;
begin
  Result := False;
  if M = nil then Exit;
  for J := 0 to M.GetModuleFileCount - 1 do
  begin
    { Delphi 7's IDE may give no editor for an index }
    E := M.GetModuleFileEditor(J);
    if (E <> nil) and E.Modified then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure OpenFiles(L: TStrings);
var
  S: IOTAModuleServices;
  I, J: Integer;
  M: IOTAModule;
  SE: IOTASourceEditor;
  Changed: Boolean;
begin
  S := ModuleServices;
  for I := 0 to S.ModuleCount - 1 do
  begin
    M := S.Modules[I];
    if Supports(M, IOTAProjectGroup) then Continue;
    Changed := ModuleModified(M);
    for J := 0 to M.GetModuleFileCount - 1 do
      if Supports(M.GetModuleFileEditor(J), IOTASourceEditor, SE) and (L.IndexOf(SE.FileName) < 0) then
      begin
        if Changed then L.AddObject(SE.FileName, TObject(1)) else L.Add(SE.FileName);
      end;
  end;
end;

function EditorText(E: IOTASourceEditor): string;
const
  { Delphi 7's edit reader takes the count as 16 bits: 65536 reads nothing, 32768 returns 32768
    whatever the text's length; up to 16384 it reads what is there }
  Chunk = 16384;
var
  R: IOTAEditReader;
  Buf: array[0..Chunk - 1] of Char;
  N, Pos: Integer;
  B: TKitStringBuilder;
begin
  B := TKitStringBuilder.Create;
  try
    R := E.CreateReader;
    Pos := 0;
    repeat
      N := R.GetText(Pos, Buf, Chunk);
      if N > 0 then B.Append(Buf, N);
      Inc(Pos, N);
    until N < Chunk;
    R := nil;     // the reader goes before any writer is made
    Result := B.Text;
  finally
    B.Free;
  end;
end;

procedure ReplaceText(E: IOTASourceEditor; StartPos, EndPos: Integer; const Text: string);
var
  Texts: TStringList;
begin
  Texts := TStringList.Create;
  try
    Texts.Add(Text);
    ReplaceTexts(E, [StartPos], [EndPos], Texts);
  finally
    Texts.Free;
  end;
end;

procedure ReplaceTexts(E: IOTASourceEditor; Starts, Ends: array of Integer; Texts: TStrings);
var
  W: IOTAEditWriter;
  I: Integer;
begin
  W := E.CreateUndoableWriter;
  for I := Low(Starts) to High(Starts) do
  begin
    W.CopyTo(Starts[I]);
    if Ends[I] > Starts[I] then W.DeleteTo(Ends[I]);
    if Texts[I] <> '' then W.Insert(PChar(Texts[I]));
  end;
  W := nil;
  E.MarkModified;
end;

function ReadFileUtf8(const FileName: string; out FromEditor, Modified: Boolean): string;
var
  E: IOTASourceEditor;
  Enc: TKitFileEncoding;
begin
  E := FindSourceEditor(FileName);
  FromEditor := E <> nil;
  if FromEditor then
  begin
    Modified := E.Modified;
    Result := IdeToUtf8(EditorText(E));
  end
  else
  begin
    Modified := False;
    if not FileExists(FileName) then raise Exception.CreateFmt('There is no file %s.', [FileName]);
    Result := ReadTextFile(FileName, Enc);
  end;
end;

function TopView: IOTAEditView;
begin
  Result := EditorServices.TopView;
end;

function ViewOf(E: IOTASourceEditor): IOTAEditView;
begin
  Result := nil;
  if (E <> nil) and (E.EditViewCount > 0) then Result := E.EditViews[0];
end;

procedure ShowFileAt(const FileName: string; Line, Column: Integer);
var
  E: IOTASourceEditor;
  V: IOTAEditView;
  P: TOTAEditPos;
begin
  E := OpenSourceEditor(FileName);
  if E = nil then raise Exception.CreateFmt('%s cannot be opened in the editor.', [FileName]);
  E.Show;
  V := ViewOf(E);
  if (V = nil) or (Line < 1) then Exit;
  if Column < 1 then Column := 1;
  P.Line := Line;
  P.Col := Column;
  V.CursorPos := P;
  V.Center(Line, Column);
  V.Paint;
end;

function CursorOffset(View: IOTAEditView): Integer;
var
  EP: TOTAEditPos;
  CP: TOTACharPos;
begin
  EP := View.CursorPos;
  CP.Line := 0;
  CP.CharIndex := 0;
  View.ConvertPos(True, EP, CP);
  Result := View.CharPosToPos(CP);
end;

function SelectedText(View: IOTAEditView): string;
var
  B: IOTAEditBlock;
begin
  Result := '';
  if View = nil then Exit;
  B := View.Block;
  if (B <> nil) and B.IsValid and B.Visible and (B.Size > 0) then Result := B.Text;
end;

function SelectionOf(View: IOTAEditView; out StartPos, EndPos: Integer; out Text: string): Boolean;
var
  B: IOTAEditBlock;
  E: IOTASourceEditor;
begin
  Result := False;
  StartPos := 0;
  EndPos := 0;
  Text := '';
  if View = nil then Exit;
  B := View.Block;
  if (B = nil) or not B.IsValid or not B.Visible or (B.Size = 0) then Exit;
  if not (B.Style in [btNonInclusive, btInclusive]) then Exit;
  if not Supports(View.Buffer, IOTASourceEditor, E) then Exit;
  StartPos := View.CharPosToPos(E.BlockStart);
  EndPos := View.CharPosToPos(E.BlockAfter);
  if B.Style = btInclusive then Inc(EndPos);
  Text := B.Text;
  Result := EndPos > StartPos;
end;

{ ---------------------------------------------------------------- TKitSelfTest }

constructor TKitSelfTest.Create(const LogVariable, DirVariable: string);
begin
  inherited Create;
  FLog := GetEnvironmentVariable(LogVariable);
  FDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable(DirVariable));
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 200;
  FTimer.OnTimer := Tick;
end;

destructor TKitSelfTest.Destroy;
begin
  FTimer.Free;
  inherited;
end;

procedure TKitSelfTest.Tick(Sender: TObject);
begin
  FTimer.Enabled := False;
  try
    Run;
  except
    on E: Exception do Say('FAIL exception: ' + E.ClassName + ': ' + E.Message + ' at ' + KitAddrInfo(ExceptAddr));
  end;
  Say(Format('DONE passed=%d failed=%d', [FPassed, FFailed]));
  Finished;
end;

procedure TKitSelfTest.Finished;
begin
end;

procedure TKitSelfTest.Say(const S: string);
var
  F: TextFile;
begin
  if FLog = '' then Exit;
  AssignFile(F, FLog);
  if FileExists(FLog) then Append(F) else Rewrite(F);
  try
    Writeln(F, S);
  finally
    CloseFile(F);
  end;
end;

procedure TKitSelfTest.Check(Cond: Boolean; const Name: string; const Detail: string);
var
  D: string;
begin
  if Cond then
  begin
    Inc(FPassed);
    Say('PASS ' + Name);
  end
  else
  begin
    Inc(FFailed);
    D := StringReplace(StringReplace(Detail, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]);
    Say('FAIL ' + Name + ': ' + Copy(D, 1, 1500));
  end;
end;

{$ENDIF}
