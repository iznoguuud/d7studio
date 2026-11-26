{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiCodeTools;

{ The harness's tools for code, through the Open Tools API:
    reading:  get_ide_state, list_project_files, read_file, search_code, list_folder, open_file;
    changing: edit_file, insert_text, create_file, save_files (each previewed and approved).
  A file open in the IDE is read from its editor buffer, unsaved changes included; other files
  from disk. Changes go into the editor buffer through an undoable writer (the file is opened
  first when needed), so the developer sees them and can undo them; only save_files writes the
  editor's files to disk. Tool input and output are UTF-8; IDE strings are converted at the
  boundary (AiText). }

interface

uses
  AiCore;

{ the code tools, added to List }
procedure AddCodeTools(List: TAiToolList);

implementation

uses
  Windows, SysUtils, Classes, ToolsAPI, AiJson, AiText, AiIde;

const
  DefaultReadLines = 2000;
  MaxReadLines = 5000;
  MaxSearchFiles = 5000;

type
  TReadTool = class(TAiTool)
  public
    function Summarize(Input: TJson): string; override;
  end;

  TIdeStateTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TProjectFilesTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TReadFileTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TSearchTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TListFolderTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TOpenFileTool = class(TReadTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TChangeTool = class(TAiTool)
  public
    function IsChange: Boolean; override;
    function Summarize(Input: TJson): string; override;
  end;

  TEditFileTool = class(TChangeTool)
  private
    function Plan(const Text: string; Input: TJson; Starts: TList; out Old, New, Problem: string): Boolean;
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TInsertTextTool = class(TChangeTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TCreateFileTool = class(TChangeTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TSaveFilesTool = class(TChangeTool)
  private
    procedure FilesToSave(Input: TJson; L: TStrings);
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

procedure AddCodeTools(List: TAiToolList);
begin
  List.Add(TIdeStateTool.Create);
  List.Add(TProjectFilesTool.Create);
  List.Add(TReadFileTool.Create);
  List.Add(TSearchTool.Create);
  List.Add(TListFolderTool.Create);
  List.Add(TOpenFileTool.Create);
  List.Add(TEditFileTool.Create);
  List.Add(TInsertTextTool.Create);
  List.Add(TCreateFileTool.Create);
  List.Add(TSaveFilesTool.Create);
end;

{ ---------------------------------------------------------------- helpers }

{ text from the model for a Delphi source: CR LF line ends, the IDE's code page }
function SourceText(const Utf8: string): string;
begin
  Result := NormalizeNewLines(Utf8ToIde(Utf8), #13#10);
end;

{ text from the model for the file whose text is Text: its line ends (LF only when the file has
  no CR LF but LF), the IDE's code page }
function TextFor(const Text, Utf8: string): string;
begin
  if (Pos(#10, Text) > 0) and not HasCrLf(Text) then Result := NormalizeNewLines(Utf8ToIde(Utf8), #10)
  else Result := SourceText(Utf8);
end;


function IsBinary(const Text: string): Boolean;
begin
  Result := (Pos(#0, Text) > 0) or (Copy(Text, 1, 4) = 'TPF0');
end;

{ the lines around the lines First..Last of Text, numbered }
function Snippet(const Text: string; First, Last: Integer): string;
var
  Shown, Total, From: Integer;
begin
  From := First - 3;
  if From < 1 then From := 1;
  Result := NumberedLines(Text, From, Last - From + 4, Shown, Total);
end;

{ ---------------------------------------------------------------- base classes }

function TReadTool.Summarize(Input: TJson): string;
begin
  Result := '';
end;

function TChangeTool.IsChange: Boolean;
begin
  Result := True;
end;

function TChangeTool.Summarize(Input: TJson): string;
begin
  Result := FileNamePart(Input.Str('path'));
end;

{ ---------------------------------------------------------------- get_ide_state }

function TIdeStateTool.Name: string;
begin
  Result := 'get_ide_state';
end;

function TIdeStateTool.Description: string;
begin
  Result := 'Returns the state of the IDE: the project group and the active project, the files open in the ' +
    'editor (marked when they have unsaved changes), the file shown in the code editor with the cursor''s ' +
    'line and column, the selected text, and the form open in the designer. Call it when the user refers to ' +
    '"this", "here", the current file, the cursor or the selection, or when you need to know what is open.';
end;

procedure TIdeStateTool.DefineInput(Schema: TJson);
begin
end;

procedure TIdeStateTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  B, L: TStringList;
  G: IOTAProjectGroup;
  P, Active: IOTAProject;
  V: IOTAEditView;
  M: IOTAModule;
  F: IOTAFormEditor;
  I: Integer;
  Sel, Mark: string;
begin
  B := TStringList.Create;
  L := TStringList.Create;
  try
    B.Add('IDE: ' + IdeName);
    Active := ActiveProject;
    G := ProjectGroup;
    if G <> nil then
    begin
      B.Add(Format('Project group: %s (%d projects)', [G.FileName, G.ProjectCount]));
      for I := 0 to G.ProjectCount - 1 do
      begin
        P := G.Projects[I];
        if P = Active then Mark := ' (active)' else Mark := '';
        B.Add('  ' + P.FileName + Mark);
      end;
    end;
    if Active <> nil then B.Add('Active project: ' + Active.FileName)
    else B.Add('No project is open.');
    OpenFiles(L);
    if L.Count = 0 then B.Add('No file is open in the editor.')
    else
    begin
      B.Add('Files open in the editor:');
      for I := 0 to L.Count - 1 do
        if L.Objects[I] <> nil then B.Add('  ' + L[I] + ' - unsaved changes') else B.Add('  ' + L[I]);
    end;
    V := TopView;
    if (V <> nil) and (V.Buffer <> nil) then
    begin
      B.Add(Format('Code editor: %s, line %d, column %d', [V.Buffer.FileName, V.CursorPos.Line, V.CursorPos.Col]));
      Sel := SelectedText(V);
      if Sel <> '' then
      begin
        B.Add(Format('Selected text (lines %d-%d):', [V.Block.StartingRow, V.Block.EndingRow]));
        B.Add(TruncateUtf8(Sel, 20000));
      end
      else B.Add('Nothing is selected.');
    end
    else B.Add('The code editor shows no file.');
    M := ModuleServices.CurrentModule;
    if M <> nil then
    begin
      F := FormEditorOf(M);
      if (F <> nil) and Supports(M.CurrentEditor, IOTAFormEditor) then
        B.Add('Form designer: ' + F.FileName + ' (the form is shown)');
    end;
    Res.Ok(IdeToUtf8(B.Text), 'IDE state');
  finally
    L.Free;
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- list_project_files }

function TProjectFilesTool.Name: string;
begin
  Result := 'list_project_files';
end;

function TProjectFilesTool.Description: string;
begin
  Result := 'Lists the files of a project (the active one by default): the project file, its units with ' +
    'their forms, and its other files, with full paths. Call it to find where the project''s code is.';
end;

procedure TProjectFilesTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'project', 'string', 'The project''s file or name, for a project of the group that is ' +
    'not the active one.', False);
end;

procedure TProjectFilesTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  P: IOTAProject;
  B: TStringList;
  I: Integer;
  MI: IOTAModuleInfo;
  S: string;
begin
  P := FindProject(ArgIde(Input, 'project'));
  if P = nil then
  begin
    Res.Fail('No such project is open.');
    Exit;
  end;
  B := TStringList.Create;
  try
    B.Add('Project: ' + P.FileName);
    for I := 0 to P.GetModuleCount - 1 do
    begin
      MI := P.GetModule(I);
      if MI.FileName = '' then
      begin
        if MI.Name <> '' then B.Add('  ' + MI.Name + ' (no file: a required package or a unit on the path)');
        Continue;
      end;
      S := '  ' + MI.FileName;
      if MI.FormName <> '' then S := S + ' (form ' + MI.FormName + ')';
      B.Add(S);
    end;
    Res.Ok(IdeToUtf8(B.Text), Format('%d files', [P.GetModuleCount + 1]));
  finally
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- read_file }

function TReadFileTool.Name: string;
begin
  Result := 'read_file';
end;

function TReadFileTool.Description: string;
begin
  Result := 'Reads a text file and returns its lines numbered (number, a tab, the line). A file open in the ' +
    'IDE is read from its editor buffer, unsaved changes included; other files from disk. Reads at most ' +
    '2000 lines per call: use offset and limit to read a long file in parts. Relative paths are relative to ' +
    'the active project''s folder. Read a file before you edit it.';
end;

procedure TReadFileTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The file: a full path, or relative to the active project''s folder.', True);
  SchemaProp(Schema, 'offset', 'integer', 'The first line to read (1-based, default 1).', False);
  SchemaProp(Schema, 'limit', 'integer', 'How many lines to read (default 2000).', False);
end;

function TReadFileTool.Summarize(Input: TJson): string;
begin
  Result := FileNamePart(Input.Str('path'));
  if Input.Has('offset') then Result := Result + Format(', from line %d', [Input.Int('offset', 1)]);
end;

procedure TReadFileTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  F, Text, Body, Where, Tail: string;
  FromEditor, Modified: Boolean;
  Offset, Limit, Shown, Total: Integer;
begin
  F := ArgPath(Input, 'path');
  if F = '' then
  begin
    Res.Fail('The path is empty.');
    Exit;
  end;
  if (FindSourceEditor(F) = nil) and not FileExists(F) then
  begin
    if DirectoryExists(F) then Res.Fail(IdeToUtf8(F) + ' is a folder: use list_folder.')
    else Res.Fail('There is no file ' + IdeToUtf8(F) + '.');
    Exit;
  end;
  Text := ReadFileUtf8(F, FromEditor, Modified);
  if IsBinary(Text) then
  begin
    if SameText(ExtractFileExt(F), '.dfm') then
      Res.Fail(IdeToUtf8(F) + ' is a binary form file: use form_list_components and form_get_properties.')
    else
      Res.Fail(IdeToUtf8(F) + ' is not a text file.');
    Exit;
  end;
  Offset := Input.Int('offset', 1);
  if Offset < 1 then Offset := 1;
  Limit := Input.Int('limit', DefaultReadLines);
  if Limit < 1 then Limit := 1;
  if Limit > MaxReadLines then Limit := MaxReadLines;
  Body := NumberedLines(Text, Offset, Limit, Shown, Total);
  if FromEditor and Modified then Where := 'from the editor, with unsaved changes'
  else if FromEditor then Where := 'from the editor'
  else Where := 'from disk';
  Tail := '';
  if Total = 0 then Body := '(the file is empty)'#10
  else if Shown = 0 then Body := Format('(the file has only %d lines)'#10, [Total])
  else if Offset + Shown - 1 < Total then
    Tail := Format('(%d more lines: call read_file with offset %d)', [Total - (Offset + Shown - 1), Offset + Shown]);
  if Shown > 0 then
    Res.Ok(Format('%s (%s): lines %d-%d of %d', [IdeToUtf8(F), Where, Offset, Offset + Shown - 1, Total]) + #10 + Body + Tail,
      Format('lines %d-%d of %d', [Offset, Offset + Shown - 1, Total]))
  else
    Res.Ok(Format('%s (%s)', [IdeToUtf8(F), Where]) + #10 + Body, Format('%d lines', [Total]));
end;

{ ---------------------------------------------------------------- search_code }

function TSearchTool.Name: string;
begin
  Result := 'search_code';
end;

function TSearchTool.Description: string;
begin
  Result := 'Searches files for a text (plain text, not a regular expression) and returns the matching lines as ' +
    'file(line): text. By default it searches the active project''s files; files open in the IDE are searched ' +
    'in their editor buffers. Use it to find declarations, the uses of an identifier, or where something is ' +
    'implemented. With scope "folder" it searches the Pascal files below a folder (e.g. Delphi''s Source or a ' +
    'library on the search path).';
end;

procedure TSearchTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'text', 'string', 'The text to find.', True);
  SchemaProp(Schema, 'case_sensitive', 'boolean', 'Match the case (default false).', False);
  SchemaProp(Schema, 'whole_word', 'boolean', 'Match whole identifiers only (default false).', False);
  SchemaEnum(Schema, 'scope', 'project|group|open_files|folder',
    'Where to search: the active project''s files (default), all projects of the group and the active one, the ' +
    'files open in the editor, or a folder and its subfolders.', False);
  SchemaProp(Schema, 'folder', 'string', 'The folder for scope "folder".', False);
  SchemaProp(Schema, 'file_mask', 'string', 'File masks separated by semicolons (default ' +
    '"*.pas;*.dpr;*.dpk;*.inc;*.dfm").', False);
  SchemaProp(Schema, 'max_results', 'integer', 'The most lines to return (default 100).', False);
end;

function TSearchTool.Summarize(Input: TJson): string;
begin
  Result := '"' + Input.Str('text') + '"';
  if Input.Str('scope') <> '' then Result := Result + ' in ' + Input.Str('scope');
end;

{ FileName matches one of the masks ('*.pas;*.inc', a whole name, '*' or '*.*') }
function MatchesMask(const FileName, Masks: string): Boolean;
var
  Ext, Name, M: string;
  P, Q: Integer;
begin
  Result := True;
  Ext := LowerCase(ExtractFileExt(FileName));
  Name := LowerCase(ExtractFileName(FileName));
  P := 1;
  while P <= Length(Masks) do
  begin
    Q := P;
    while (Q <= Length(Masks)) and (Masks[Q] <> ';') do Inc(Q);
    M := LowerCase(Trim(Copy(Masks, P, Q - P)));
    if (M = '*.*') or (M = '*') or ((Copy(M, 1, 2) = '*.') and (Copy(M, 2, MaxInt) = Ext)) or (M = Name) then Exit;
    P := Q + 1;
  end;
  Result := False;
end;

procedure FindFiles(const Dir, Masks: string; L: TStrings);
var
  SR: TSearchRec;
  D: string;
begin
  if L.Count >= MaxSearchFiles then Exit;
  D := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(D + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if (SR.Name <> '__history') and (SR.Name[1] <> '.') then FindFiles(D + SR.Name, Masks, L);
        end
        else if MatchesMask(SR.Name, Masks) then L.Add(D + SR.Name);
      until (FindNext(SR) <> 0) or (L.Count >= MaxSearchFiles);
    finally
      FindClose(SR);
    end;
end;

procedure TSearchTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
const
  IdentChars = ['A'..'Z', 'a'..'z', '0'..'9', '_'];
var
  Files, Open, Out: TStringList;
  Needle, Scope, Masks, Text, Hay, F: string;
  CaseSensitive, WholeWord, FromEditor, Modified, Hit: Boolean;
  MaxResults, I, P, LineNo, Counted, LS, LE, Matches, FilesHit: Integer;
  G: IOTAProjectGroup;
  Active: IOTAProject;
  Enc: TKitFileEncoding;
begin
  Needle := Input.Str('text');
  if Needle = '' then
  begin
    Res.Fail('The text is empty.');
    Exit;
  end;
  CaseSensitive := Input.Bool('case_sensitive', False);
  WholeWord := Input.Bool('whole_word', False);
  Scope := Input.Str('scope', 'project');
  Masks := ArgIde(Input, 'file_mask');
  if Masks = '' then Masks := '*.pas;*.dpr;*.dpk;*.inc;*.dfm';
  MaxResults := Input.Int('max_results', 100);
  if MaxResults < 1 then MaxResults := 1;
  if MaxResults > 1000 then MaxResults := 1000;
  { LowerCase changes only A..Z: positions in UTF-8 text stay the same }
  if not CaseSensitive then Needle := LowerCase(Needle);
  Files := TStringList.Create;
  Open := TStringList.Create;
  Out := TStringList.Create;
  try
    if Scope = 'group' then
    begin
      { the group's projects, and the active project when it is none of them (a package open
        beside the group) }
      G := ProjectGroup;
      if G <> nil then
        for I := 0 to G.ProjectCount - 1 do ProjectFiles(G.Projects[I], Files);
      Active := ActiveProject;
      if (Active <> nil) and (Files.IndexOf(Active.FileName) < 0) then ProjectFiles(Active, Files);
    end
    else if Scope = 'open_files' then OpenFiles(Files)
    else if Scope = 'folder' then
    begin
      F := ArgPath(Input, 'folder');
      if (F = '') or not DirectoryExists(F) then
      begin
        Res.Fail('Scope "folder" needs an existing folder.');
        Exit;
      end;
      FindFiles(F, Masks, Files);
    end
    else
    begin
      if ActiveProject = nil then
      begin
        Res.Fail('No project is open: use scope "open_files" or "folder".');
        Exit;
      end;
      ProjectFiles(ActiveProject, Files);
    end;
    { the open files once: only they are read through the IDE }
    OpenFiles(Open);
    Open.CaseSensitive := False;
    Open.Sorted := True;
    Matches := 0;
    FilesHit := 0;
    for I := 0 to Files.Count - 1 do
    begin
      if Matches >= MaxResults then Break;
      F := Files[I];
      if (Scope <> 'folder') and not MatchesMask(F, Masks) then Continue;
      try
        if Open.IndexOf(F) >= 0 then Text := ReadFileUtf8(F, FromEditor, Modified)
        else if FileExists(F) then Text := ReadTextFile(F, Enc)
        else Continue;
      except
        Continue;
      end;
      if IsBinary(Text) then Continue;
      if CaseSensitive then Hay := Text else Hay := LowerCase(Text);
      { the whole text at once; each line is reported once }
      Hit := False;
      LineNo := 1;
      Counted := 1;
      P := PosFrom(Needle, Hay, 1);
      while P > 0 do
      begin
        if WholeWord and (((P > 1) and (Hay[P - 1] in IdentChars)) or
          ((P + Length(Needle) <= Length(Hay)) and (Hay[P + Length(Needle)] in IdentChars))) then
        begin
          P := PosFrom(Needle, Hay, P + 1);
          Continue;
        end;
        while Counted < P do
        begin
          if Text[Counted] = #10 then Inc(LineNo);
          Inc(Counted);
        end;
        LS := P;
        while (LS > 1) and (Text[LS - 1] <> #10) do Dec(LS);
        LE := P;
        while (LE <= Length(Text)) and not (Text[LE] in [#13, #10]) do Inc(LE);
        Out.Add(Format('%s(%d): %s', [IdeToUtf8(DisplayPath(F)), LineNo, TruncateUtf8(Trim(Copy(Text, LS, LE - LS)), 300)]));
        Inc(Matches);
        Hit := True;
        if Matches >= MaxResults then Break;
        P := PosFrom(Needle, Hay, LE);
      end;
      if Hit then Inc(FilesHit);
    end;
    if Matches = 0 then
      Res.Ok(Format('No match in %d files.', [Files.Count]), 'no match')
    else
    begin
      if Matches >= MaxResults then
        Out.Insert(0, Format('The first %d matches (there may be more: narrow the search or raise max_results):', [Matches]))
      else
        Out.Insert(0, Format('%d matches in %d of %d files:', [Matches, FilesHit, Files.Count]));
      Res.Ok(Out.Text, Format('%d matches', [Matches]));
    end;
  finally
    Out.Free;
    Open.Free;
    Files.Free;
  end;
end;
{ ---------------------------------------------------------------- list_folder }

function TListFolderTool.Name: string;
begin
  Result := 'list_folder';
end;

function TListFolderTool.Description: string;
begin
  Result := 'Lists the subfolders and files of a folder (default: the active project''s folder), with the files'' ' +
    'sizes. Use it to find files that are not part of the project, such as include files or units on the ' +
    'search path.';
end;

procedure TListFolderTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The folder (default: the active project''s folder).', False);
  SchemaProp(Schema, 'mask', 'string', 'File masks separated by semicolons (default "*.*").', False);
end;

procedure TListFolderTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  Dir, Masks: string;
  SR: TSearchRec;
  Dirs, Files: TStringList;
begin
  Dir := ArgPath(Input, 'path');
  if Dir = '' then Dir := ProjectFolder(ActiveProject);
  if (Dir = '') or not DirectoryExists(Dir) then
  begin
    Res.Fail('There is no folder ' + IdeToUtf8(Dir) + '.');
    Exit;
  end;
  Masks := ArgIde(Input, 'mask');
  if Masks = '' then Masks := '*.*';
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  try
    Dir := IncludeTrailingPathDelimiter(Dir);
    if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Name = '.') or (SR.Name = '..') then Continue;
          if (SR.Attr and faDirectory) <> 0 then Dirs.Add(SR.Name + '\')
          else if MatchesMask(SR.Name, Masks) then Files.Add(Format('%s  (%d bytes)', [SR.Name, SR.Size]));
        until (FindNext(SR) <> 0) or (Files.Count + Dirs.Count >= 2000);
      finally
        FindClose(SR);
      end;
    Dirs.Sort;
    Files.Sort;
    Dirs.AddStrings(Files);
    Dirs.Insert(0, Dir + ':');
    if Dirs.Count = 1 then Dirs.Add('(empty)');
    Res.Ok(IdeToUtf8(Dirs.Text), Format('%d entries', [Dirs.Count - 1]));
  finally
    Dirs.Free;
    Files.Free;
  end;
end;

{ ---------------------------------------------------------------- open_file }

function TOpenFileTool.Name: string;
begin
  Result := 'open_file';
end;

function TOpenFileTool.Description: string;
begin
  Result := 'Opens a file in the IDE''s code editor and puts the cursor on a line, to show the user a place in ' +
    'the code. It does not change the file.';
end;

procedure TOpenFileTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The file.', True);
  SchemaProp(Schema, 'line', 'integer', 'The line (1-based).', False);
  SchemaProp(Schema, 'column', 'integer', 'The column (1-based).', False);
end;

procedure TOpenFileTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  F: string;
begin
  F := ArgPath(Input, 'path');
  if (F = '') or ((FindSourceEditor(F) = nil) and not FileExists(F)) then
  begin
    Res.Fail('There is no file ' + IdeToUtf8(F) + '.');
    Exit;
  end;
  ShowFileAt(F, Input.Int('line', 0), Input.Int('column', 1));
  if Input.Int('line', 0) > 0 then Res.Ok(Format('Opened %s at line %d.', [IdeToUtf8(F), Input.Int('line', 0)]), 'opened')
  else Res.Ok('Opened ' + IdeToUtf8(F) + '.', 'opened');
end;

{ ---------------------------------------------------------------- edit_file }

function TEditFileTool.Name: string;
begin
  Result := 'edit_file';
end;

function TEditFileTool.Description: string;
begin
  Result := 'Replaces text in a file: old_text must occur exactly once in the file (or set replace_all) and is ' +
    'replaced by new_text. The change is made in the file''s editor buffer (the file is opened in the IDE if ' +
    'needed), so the user sees it and can undo it; it is not saved to disk. Copy old_text exactly from ' +
    'read_file''s output, without the line numbers, with its indentation, and with enough surrounding lines to ' +
    'make it unique. The user is asked to approve every edit. Form files (.dfm) are changed with the form tools.';
end;

procedure TEditFileTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The file.', True);
  SchemaProp(Schema, 'old_text', 'string', 'The exact text to replace.', True);
  SchemaProp(Schema, 'new_text', 'string', 'The text that replaces it (may be empty to delete).', True);
  SchemaProp(Schema, 'replace_all', 'boolean', 'Replace every occurrence (default false).', False);
end;

{ the edit planned on Text: old_text and new_text in Text's line ends and code page, and where
  old_text occurs (Starts: 1-based positions); False with Problem when it cannot be made }
function TEditFileTool.Plan(const Text: string; Input: TJson; Starts: TList; out Old, New, Problem: string): Boolean;
var
  P: Integer;
begin
  Result := False;
  Problem := '';
  Old := TextFor(Text, Input.Str('old_text'));
  New := TextFor(Text, Input.Str('new_text'));
  if Old = '' then
  begin
    Problem := 'old_text is empty: use insert_text to add text, or create_file for a new file.';
    Exit;
  end;
  if Old = New then
  begin
    Problem := 'old_text and new_text are the same: there is nothing to change.';
    Exit;
  end;
  P := PosFrom(Old, Text, 1);
  while P > 0 do
  begin
    Starts.Add(Pointer(P));
    P := PosFrom(Old, Text, P + Length(Old));
  end;
  if Starts.Count = 0 then
    Problem := 'old_text was not found in the file. Read the file again (read_file) and copy the text exactly, ' +
      'with its indentation and without the line numbers.'
  else if (Starts.Count > 1) and not Input.Bool('replace_all', False) then
    Problem := Format('old_text occurs %d times in the file: add surrounding lines to make it unique, or set ' +
      'replace_all.', [Starts.Count]);
  Result := Problem = '';
end;

{ the file's text as the edit will see it; '' with Problem when it cannot be edited }
function EditableText(const F: string; out Problem: string): string;
var
  E: IOTASourceEditor;
  Enc: TKitFileEncoding;
begin
  Result := '';
  Problem := '';
  if F = '' then
  begin
    Problem := 'The path is empty.';
    Exit;
  end;
  if SameText(ExtractFileExt(F), '.dfm') then
  begin
    Problem := 'Form files are changed with form_set_property, form_add_component and form_delete_component.';
    Exit;
  end;
  E := FindSourceEditor(F);
  if E <> nil then Result := EditorText(E)
  else if FileExists(F) then Result := Utf8ToIde(ReadTextFile(F, Enc))
  else Problem := 'There is no file ' + IdeToUtf8(F) + '. Use create_file for a new file.';
end;

function TEditFileTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  F, Text, Old, New, Problem: string;
  Starts: TList;
begin
  Result := False;
  F := ArgPath(Input, 'path');
  Text := EditableText(F, Problem);
  if Problem <> '' then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Starts := TList.Create;
  try
    if not Plan(Text, Input, Starts, Old, New, Problem) then
    begin
      Res.Fail(Problem);
      Exit;
    end;
    Change.FileName := F;
    Change.Title := Format('Edit %s, line %d', [DisplayPath(F), LineOfPos(Text, Integer(Starts[0]))]);
    Change.Before := Old;
    Change.After := New;
    if Starts.Count > 1 then Change.Notes := Format('All %d occurrences are replaced.', [Starts.Count]);
    Result := True;
  finally
    Starts.Free;
  end;
end;

procedure TEditFileTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  F, Text, Old, New, Problem, After: string;
  E: IOTASourceEditor;
  Starts: TList;
  S, En: array of Integer;
  Texts: TStringList;
  I, FirstLine: Integer;
begin
  F := ArgPath(Input, 'path');
  E := OpenSourceEditor(F);
  if E = nil then
  begin
    Res.Fail(IdeToUtf8(F) + ' cannot be opened in the editor.');
    Exit;
  end;
  Text := EditorText(E);
  Starts := TList.Create;
  Texts := TStringList.Create;
  try
    { the text may have changed since the preview }
    if not Plan(Text, Input, Starts, Old, New, Problem) then
    begin
      Res.Fail('The file changed meanwhile: ' + Problem);
      Exit;
    end;
    SetLength(S, Starts.Count);
    SetLength(En, Starts.Count);
    for I := 0 to Starts.Count - 1 do
    begin
      S[I] := Integer(Starts[I]) - 1;
      En[I] := S[I] + Length(Old);
      Texts.Add(New);
    end;
    FirstLine := LineOfPos(Text, Integer(Starts[0]));
    ReplaceTexts(E, S, En, Texts);
    After := EditorText(E);
    Res.Ok(Format('Edited %s: %d occurrence(s) replaced. The change is in the editor, not saved. The lines now:',
      [IdeToUtf8(F), Starts.Count]) + #10 + IdeToUtf8(Snippet(After, FirstLine, FirstLine + CountLines(New))),
      Format('%d replaced, line %d', [Starts.Count, FirstLine]));
  finally
    Texts.Free;
    Starts.Free;
  end;
end;
{ ---------------------------------------------------------------- insert_text }

function TInsertTextTool.Name: string;
begin
  Result := 'insert_text';
end;

function TInsertTextTool.Description: string;
begin
  Result := 'Inserts text into a file: at the start of a line (and column) of the file given, or at the cursor of ' +
    'the code editor when no path is given, or in place of the code editor''s selection (replace_selection). ' +
    'The change is made in the editor buffer, undoable and not saved. Prefer edit_file when you can name the ' +
    'surrounding text. The user is asked to approve it.';
end;

procedure TInsertTextTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'text', 'string', 'The text to insert.', True);
  SchemaProp(Schema, 'path', 'string', 'The file (default: the file of the code editor).', False);
  SchemaProp(Schema, 'line', 'integer', 'Insert before this line (1-based); the line after the last appends.', False);
  SchemaProp(Schema, 'column', 'integer', 'The column in that line (1-based, default 1).', False);
  SchemaProp(Schema, 'replace_selection', 'boolean', 'Replace the code editor''s selected text.', False);
end;

{ where the text goes: the editor and the offsets }
{ where the text goes: the editor and the offsets; Break: the text goes after the last line of a
  file whose last line has no line break, so a line break must come first }
function InsertPlace(Input: TJson; out E: IOTASourceEditor; out StartPos, EndPos: Integer; out Where, Problem: string;
  out Break: Boolean; Open: Boolean): Boolean;
var
  V: IOTAEditView;
  F, Text, Sel: string;
  Line, Col, LS, LE, Lines: Integer;
  Enc: TKitFileEncoding;
begin
  Result := False;
  E := nil;
  StartPos := 0;
  EndPos := 0;
  Where := '';
  Problem := '';
  Break := False;
  if Input.Bool('replace_selection', False) then
  begin
    V := TopView;
    if (V = nil) or not SelectionOf(V, StartPos, EndPos, Sel) then
    begin
      if (V <> nil) and (SelectedText(V) <> '') then
        Problem := 'The selection is a column or line block: only a normal selection can be replaced.'
      else
        Problem := 'Nothing is selected in the code editor.';
      Exit;
    end;
    if not Supports(V.Buffer, IOTASourceEditor, E) then Exit;
    Where := Format('the selection in %s (lines %d-%d)', [DisplayPath(E.FileName), V.Block.StartingRow, V.Block.EndingRow]);
    Result := True;
    Exit;
  end;
  F := ArgIde(Input, 'path');
  if F = '' then
  begin
    V := TopView;
    if (V = nil) or not Supports(V.Buffer, IOTASourceEditor, E) then
    begin
      Problem := 'The code editor shows no file: give a path.';
      Exit;
    end;
    if Input.HasValue('line') then F := E.FileName
    else
    begin
      StartPos := CursorOffset(V);
      EndPos := StartPos;
      Where := Format('the cursor in %s (line %d)', [DisplayPath(E.FileName), V.CursorPos.Line]);
      Result := True;
      Exit;
    end;
  end
  else
    F := ResolvePath(F);
  if Open then E := OpenSourceEditor(F) else E := FindSourceEditor(F);
  if (E = nil) and not Open then
  begin
    if not FileExists(F) then
    begin
      Problem := 'There is no file ' + IdeToUtf8(F) + '.';
      Exit;
    end;
    Text := Utf8ToIde(ReadTextFile(F, Enc));
  end
  else if E = nil then
  begin
    Problem := IdeToUtf8(F) + ' cannot be opened in the editor.';
    Exit;
  end
  else
    Text := EditorText(E);
  Lines := CountLines(Text);
  Line := Input.Int('line', Lines + 1);
  Col := Input.Int('column', 1);
  if Col < 1 then Col := 1;
  LS := LineStart(Text, Line);
  if (LS = 0) and (Line = Lines + 1) then LS := Length(Text) + 1;
  if LS = 0 then
  begin
    Problem := Format('The file has only %d lines.', [Lines]);
    Exit;
  end;
  LE := LS;
  while (LE <= Length(Text)) and not (Text[LE] in [#13, #10]) do Inc(LE);
  if LS + Col - 1 > LE then StartPos := LE - 1 else StartPos := LS + Col - 2;
  EndPos := StartPos;
  Break := (Line = Lines + 1) and (Text <> '') and (Text[Length(Text)] <> #10);
  Where := Format('%s, line %d', [DisplayPath(F), Line]);
  Result := True;
end;

function TInsertTextTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  E: IOTASourceEditor;
  S, En: Integer;
  Where, Problem, Sel: string;
  V: IOTAEditView;
  Break: Boolean;
begin
  Result := InsertPlace(Input, E, S, En, Where, Problem, Break, False);
  if not Result then
  begin
    if Problem = '' then Problem := 'There is no place to insert the text.';
    Res.Fail(Problem);
    Exit;
  end;
  Change.Title := 'Insert into ' + Where;
  if Input.Bool('replace_selection', False) then
  begin
    Change.Title := 'Replace ' + Where;
    V := TopView;
    if (V <> nil) and SelectionOf(V, S, En, Sel) then Change.Before := Sel;
  end;
  if E <> nil then Change.FileName := E.FileName;
  Change.After := SourceText(Input.Str('text'));
end;

procedure TInsertTextTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  E: IOTASourceEditor;
  S, En, Line: Integer;
  Where, Problem, T, Text, After: string;
  Break: Boolean;
begin
  if not InsertPlace(Input, E, S, En, Where, Problem, Break, True) or (E = nil) then
  begin
    if Problem = '' then Problem := 'There is no place to insert the text.';
    Res.Fail(Problem);
    Exit;
  end;
  Text := EditorText(E);
  T := TextFor(Text, Input.Str('text'));
  if Break then
  begin
    if HasCrLf(Text) or (Pos(#10, Text) = 0) then T := #13#10 + T else T := #10 + T;
  end;
  ReplaceText(E, S, En, T);
  After := EditorText(E);
  Line := LineOfPos(After, S + 1);
  Res.Ok(Format('Inserted into %s. The change is in the editor, not saved. The lines now:', [IdeToUtf8(Where)]) + #10 +
    IdeToUtf8(Snippet(After, Line, Line + CountLines(T))), 'inserted');
end;
{ ---------------------------------------------------------------- create_file }

function TCreateFileTool.Name: string;
begin
  Result := 'create_file';
end;

function TCreateFileTool.Description: string;
begin
  Result := 'Creates a new file with the given content (in the system code page, with CR LF line ends) and opens ' +
    'it in the editor; with add_to_project it is added to the active project (a unit then appears in the ' +
    'project''s uses clause). It fails when the file exists: change existing files with edit_file. The user is ' +
    'asked to approve it.';
end;

procedure TCreateFileTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The new file.', True);
  SchemaProp(Schema, 'content', 'string', 'The whole content of the file.', True);
  SchemaProp(Schema, 'add_to_project', 'boolean', 'Add the file to the active project (default false).', False);
end;

function TCreateFileTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  F: string;
begin
  Result := False;
  F := ArgPath(Input, 'path');
  if F = '' then
  begin
    Res.Fail('The path is empty.');
    Exit;
  end;
  if FileExists(F) or (FindSourceEditor(F) <> nil) then
  begin
    Res.Fail(IdeToUtf8(F) + ' exists already: change it with edit_file.');
    Exit;
  end;
  Change.FileName := F;
  Change.Title := 'Create ' + DisplayPath(F);
  Change.After := SourceText(Input.Str('content'));
  if Input.Bool('add_to_project', False) then
  begin
    if ActiveProject = nil then
    begin
      Res.Fail('No project is open to add the file to.');
      Exit;
    end;
    Change.Notes := 'The file is added to ' + ExtractFileName(ActiveProject.FileName) + '.';
  end;
  Result := True;
end;

procedure TCreateFileTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  F, Content, Bytes, Note, Ext: string;
  P: IOTAProject;
  I: Integer;
  Added: Boolean;
begin
  F := ArgPath(Input, 'path');
  if FileExists(F) then
  begin
    Res.Fail(IdeToUtf8(F) + ' exists already.');
    Exit;
  end;
  Content := NormalizeNewLines(Input.Str('content'), #13#10);
  Bytes := EncodeText(Content, feAnsi);
  Note := '';
  if WideToUtf8(CodePageToWide(Bytes, SystemCodePage)) <> Content then
    Note := ' Characters the system code page lacks were written as "?".';
  if ExtractFilePath(F) <> '' then ForceDirectories(ExtractFilePath(F));
  WriteFileBytes(F, Bytes);
  Ext := LowerCase(ExtractFileExt(F));
  if Input.Bool('add_to_project', False) then
  begin
    P := ActiveProject;
    if P <> nil then
    begin
      P.AddFile(F, (Ext = '.pas') or (Ext = '.rc'));
      { what the project holds now, not what was asked }
      Added := False;
      for I := 0 to P.GetModuleCount - 1 do
        if SameText(P.GetModule(I).FileName, F) then Added := True;
      if Added then Note := Note + ' Added to ' + IdeToUtf8(ExtractFileName(P.FileName)) + '.'
      else Note := Note + ' It was not added to ' + IdeToUtf8(ExtractFileName(P.FileName)) +
        ': a project takes units (.pas) and resource scripts (.rc); include files are found through the paths.';
    end;
  end;
  KitOpenFile(F);
  Res.Ok(Format('Created %s (%d lines) and opened it in the editor.%s', [IdeToUtf8(F), CountLines(Content), Note]), 'created');
end;

{ ---------------------------------------------------------------- save_files }

function TSaveFilesTool.Name: string;
begin
  Result := 'save_files';
end;

function TSaveFilesTool.Description: string;
begin
  Result := 'Saves files that have unsaved changes in the IDE to disk: the files named, or every open file with ' +
    'unsaved changes. Edits stay in the editor until they are saved; compile_project compiles them unsaved, so ' +
    'saving is needed only when the user wants the files on disk. The user is asked to approve it.';
end;

procedure TSaveFilesTool.DefineInput(Schema: TJson);
begin
  SchemaArray(Schema, 'paths', 'string', 'The files to save (default: every file with unsaved changes).', False);
end;

function TSaveFilesTool.Summarize(Input: TJson): string;
begin
  if Input.Arr('paths') <> nil then Result := Format('%d files', [Input.Arr('paths').Count])
  else Result := 'all changed files';
end;

procedure TSaveFilesTool.FilesToSave(Input: TJson; L: TStrings);
var
  A: TJson;
  I: Integer;
  F: string;
  All: TStringList;
begin
  A := Input.Arr('paths');
  if (A <> nil) and (A.Count > 0) then
  begin
    for I := 0 to A.Count - 1 do
    begin
      F := ResolvePath(Utf8ToIde(A.Item(I).AsString));
      { a form is saved with its unit }
      if SameText(ExtractFileExt(F), '.dfm') then F := ChangeFileExt(F, '.pas');
      if (FindSourceEditor(F) <> nil) and ModuleModified(FindModuleOf(F)) and (L.IndexOf(F) < 0) then L.Add(F);
    end;
  end
  else
  begin
    All := TStringList.Create;
    try
      OpenFiles(All);
      for I := 0 to All.Count - 1 do
        if All.Objects[I] <> nil then L.Add(All[I]);
    finally
      All.Free;
    end;
  end;
end;

function TSaveFilesTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    FilesToSave(Input, L);
    Result := L.Count > 0;
    if not Result then
    begin
      Res.Fail('None of these files has unsaved changes.');
      Exit;
    end;
    Change.Title := Format('Save %d file(s) to disk', [L.Count]);
    Change.After := L.Text;
  finally
    L.Free;
  end;
end;

procedure TSaveFilesTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  L, Saved, Failed: TStringList;
  I: Integer;
  M: IOTAModule;
begin
  L := TStringList.Create;
  Saved := TStringList.Create;
  Failed := TStringList.Create;
  try
    FilesToSave(Input, L);
    for I := 0 to L.Count - 1 do
    begin
      M := FindModuleOf(L[I]);
      if (M <> nil) and M.Save(False, True) and not ModuleModified(M) then Saved.Add(IdeToUtf8(L[I]))
      else Failed.Add(IdeToUtf8(L[I]));
    end;
    if Failed.Count = 0 then Res.Ok('Saved:'#10 + Saved.Text, Format('%d saved', [Saved.Count]))
    else Res.Fail('Saved:'#10 + Saved.Text + 'Not saved:'#10 + Failed.Text);
  finally
    Failed.Free;
    Saved.Free;
    L.Free;
  end;
end;

end.
