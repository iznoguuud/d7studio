{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiSelfTest;

{ The harness's self-test in the IDE: with AIHARNESS_SELFTEST_LOG set,
  Tools | AI Harness Self-Test opens the scratch project of AIHARNESS_SELFTEST_DIR (Project1.dpr
  with Unit1 and its form) and runs every tool on it through the Open Tools API, the changes
  previewed and executed as an approved call would be; then a whole turn of the agent loop
  with a scripted backend (no network): a tool call, its result, the answer. Each check writes
  PASS or FAIL to the log, the last line is DONE. It starts from a timer, so that the menu
  command returns at once. A tool that raises is reported with the exception's class, message
  and code address (module and offset: the package's map, built with -Map, names the routine),
  and the test goes on. }

interface

procedure StartSelfTest;
procedure StopSelfTest;

implementation

uses
  Windows, Messages, SysUtils, Classes, Forms, ExtCtrls, ToolsAPI, AiJson, AiText, AiCore, AiAgent, AiClaude,
  AiOpenAI, AiIde, AiHost, AiPrompt;

type
  TSelfTest = class(TKitSelfTest)
  private
    FTools: TAiToolList;
    FText: string;       // the last tool's result
    { a check whose detail, when it fails, is the last tool's result }
    procedure Check(Cond: Boolean; const Name: string);
    procedure CheckD(Cond: Boolean; const Name, Detail: string);
    { a tool call as the session makes it, the change approved; its result in FText }
    function Tool(const Name, InputJson: string): Boolean;
    { the last tool's result holds Sub }
    function Has(const Sub: string): Boolean;
    procedure TestTools;
    procedure CheckRequest(const Body, Backend, ToolType, SchemaMember, HistoryMember: string);
    procedure TestSession;
  protected
    procedure Run; override;
  public
    destructor Destroy; override;
  end;

  TDirectContext = class(TAiToolContext)
  public
    procedure RunInMainThread(Method: TThreadMethod); override;
    function Cancelled: Boolean; override;
    procedure Status(const Utf8: string); override;
  end;

  TScriptBackend = class(TAiBackend)
  public
    Calls: Integer;
    class function Id: string; override;
    class function DisplayName: string; override;
    function Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
      Events: TAiBackendEvents): TAiMessage; override;
    procedure Cancel; override;
    procedure ResetCancel; override;
  end;

  TYesApprover = class(TAiApprover)
  public
    Asked: Integer;
    function Approve(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval; override;
  end;

var
  Test: TSelfTest;

procedure StartSelfTest;
begin
  if Test <> nil then Exit;
  Test := TSelfTest.Create('AIHARNESS_SELFTEST_LOG', 'AIHARNESS_SELFTEST_DIR');
end;

procedure StopSelfTest;
begin
  FreeAndNil(Test);
end;

{ ---------------------------------------------------------------- helpers }

procedure TDirectContext.RunInMainThread(Method: TThreadMethod);
begin
  Method;
end;

function TDirectContext.Cancelled: Boolean;
begin
  Result := False;
end;

procedure TDirectContext.Status(const Utf8: string);
begin
end;

class function TScriptBackend.Id: string;
begin
  Result := 'SelfTest';
end;

class function TScriptBackend.DisplayName: string;
begin
  Result := 'Self-test script';
end;

function TScriptBackend.Send(Conversation: TAiConversation; const System: string; Tools: TAiToolList;
  Events: TAiBackendEvents): TAiMessage;
var
  B: TAiBlock;
begin
  Inc(Calls);
  Result := TAiMessage.Create(arAssistant);
  Result.Usage.InputTokens := 100;
  Result.Usage.OutputTokens := 10;
  if Calls = 1 then
  begin
    Result.AddText('I will read the unit.');
    if Events <> nil then
    begin
      Events.BlockStarted(0, abText, '');
      Events.Delta(0, abText, 'I will read the unit.');
    end;
    B := TAiBlock.Create(abToolCall);
    B.Id := 'call_1';
    B.Name := 'read_file';
    B.InputText := '{"path":"Unit1.pas","limit":5}';
    B.Input := TJson.Parse(B.InputText);
    Result.Add(B);
    Result.StopReason := asToolUse;
  end
  else
  begin
    Result.AddText('The unit declares TForm1.');
    Result.StopReason := asEndTurn;
  end;
end;

procedure TScriptBackend.Cancel;
begin
end;

procedure TScriptBackend.ResetCancel;
begin
end;

function TYesApprover.Approve(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval;
begin
  Inc(Asked);
  Reason := '';
  Result := aaAllow;
end;

{ ---------------------------------------------------------------- TSelfTest }

destructor TSelfTest.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TSelfTest.CheckD(Cond: Boolean; const Name, Detail: string);
begin
  inherited Check(Cond, Name, Detail);
end;

procedure TSelfTest.Check(Cond: Boolean; const Name: string);
begin
  inherited Check(Cond, Name, FText);
end;

function TSelfTest.Has(const Sub: string): Boolean;
begin
  Result := Pos(Sub, FText) > 0;
end;

function TSelfTest.Tool(const Name, InputJson: string): Boolean;
var
  T: TAiTool;
  Input, Schema: TJson;
  Res: TAiToolResult;
  Change: TAiChangePreview;
  Ctx: TDirectContext;
  Problem: string;
begin
  Result := False;
  FText := '';
  T := FTools.Find(Name);
  if T = nil then
  begin
    FText := 'no tool ' + Name;
    Exit;
  end;
  Input := nil;
  Res := TAiToolResult.Create;
  Change := TAiChangePreview.Create;
  Ctx := TDirectContext.Create;
  try
    try
      Input := TJson.Parse(InputJson);
      Schema := T.Schema;
      try
        Problem := ValidateInput(Schema.Obj('input_schema'), Input);
      finally
        Schema.Free;
      end;
      if Problem <> '' then
      begin
        FText := 'invalid input: ' + Problem;
        Exit;
      end;
      if T.IsChange and not T.Preview(Input, Change, Res) then
      begin
        FText := 'preview: ' + Utf8ToIde(Res.Text);
        Exit;
      end;
      T.Execute(Ctx, Input, Res);
      FText := Utf8ToIde(Res.Text);
      Result := not Res.IsError;
    except
      on E: Exception do
      begin
        FText := 'EXCEPTION ' + E.ClassName + ': ' + E.Message + ' at ' + KitAddrInfo(ExceptAddr);
        Result := False;
      end;
    end;
  finally
    Ctx.Free;
    Change.Free;
    Res.Free;
    Input.Free;
  end;
end;

function Contains(const S, Sub: string): Boolean;
begin
  Result := Pos(Sub, S) > 0;
end;

procedure TSelfTest.Run;
var
  Dpr: string;
begin
  Say('START ' + IdeName);
  Dpr := FDir + 'Project1.dpr';
  CheckD(FileExists(Dpr), 'scratch project', Dpr);
  if not FileExists(Dpr) then Exit;
  (BorlandIDEServices as IOTAActionServices).OpenProject(Dpr, True);
  CheckD((ActiveProject <> nil) and SameText(ActiveProject.FileName, Dpr), 'project open', Dpr);
  if ActiveProject = nil then Exit;
  FTools := NewTools;
  TestTools;
  TestSession;
end;

procedure TSelfTest.TestTools;
var
  Unit1, Buf, Disk, Expected: string;
  Line: Integer;
  E: IOTASourceEditor;
  B: TAiClaudeBackend;
  O: TAiOpenAIBackend;
  C: TAiConversation;
  Settings: TAiMemorySettings;
begin
  Unit1 := FDir + 'Unit1.pas';
  { reading }
  Check(Tool('get_ide_state', '{}') and Has('Active project: ' + FDir + 'Project1.dpr'), 'get_ide_state');
  Check(Tool('list_project_files', '{}') and Has('Unit1.pas') and Has('(form Form1)'), 'list_project_files');
  Check(Tool('read_file', '{"path":"Unit1.pas"}') and Has(#9'  TForm1 = class(TForm)') and
    (Has('from disk') or Has('from the editor)')), 'read_file');
  Check(Tool('read_file', '{"path":"Unit1.pas","offset":3,"limit":2}') and Has('lines 3-4 of') and
    Has('more lines: call read_file with offset 5'), 'read_file part');
  Check(not Tool('read_file', '{"path":"NoSuch.pas"}') and Has('There is no file'), 'read_file missing');
  Check(Tool('search_code', '{"text":"TForm1"}') and Has('Unit1.pas(') and Has('Project1.dpr('), 'search_code');
  Check(Tool('search_code', '{"text":"form1","whole_word":true,"case_sensitive":true}') and Has('No match'),
    'search_code whole word, case');
  Check(Tool('list_folder', '{}') and Has('Unit1.dfm'), 'list_folder');
  Check(Tool('open_file', '{"path":"Unit1.pas","line":9}') and (FindSourceEditor(Unit1) <> nil), 'open_file');
  { editing: in the buffer, not on disk }
  Check(Tool('edit_file', '{"path":"Unit1.pas","old_text":"    { Private declarations }","new_text":' +
    '"    { Private declarations }\n    FCount: Integer;"}') and Has('1 occurrence'), 'edit_file');
  E := FindSourceEditor(Unit1);
  Buf := EditorText(E);
  Disk := ReadFileBytes(Unit1);
  CheckD(Contains(Buf, '    { Private declarations }'#13#10'    FCount: Integer;'#13#10), 'edit_file in the buffer, CR LF', Buf);
  CheckD(not Contains(Disk, 'FCount'), 'edit_file not saved', Disk);
  CheckD(E.Modified, 'edit_file marks the buffer modified', '');
  Check(not Tool('edit_file', '{"path":"Unit1.pas","old_text":"end","new_text":"x"}') and Has('times in the file'),
    'edit_file ambiguous');
  Check(not Tool('edit_file', '{"path":"Unit1.pas","old_text":"no such text","new_text":"x"}') and Has('was not found'),
    'edit_file not found');
  Check(Tool('insert_text', '{"path":"Unit1.pas","line":1,"text":"// AI harness self-test\n"}'), 'insert_text');
  Buf := EditorText(E);
  CheckD(Copy(Buf, 1, 25) = '// AI harness self-test'#13#10, 'insert_text at line 1', Copy(Buf, 1, 60));
  { compiling what the editor holds }
  Check(Tool('compile_project', '{}') and Has('successfully') and Has('unsaved changes of 1 file(s) were compiled'),
    'compile_project with unsaved changes');
  Check(Tool('edit_file', '{"path":"Unit1.pas","old_text":"FCount: Integer;","new_text":"FCount: Intger;"}'),
    'edit_file error in');
  Buf := EditorText(E);
  Line := LineOfPos(Buf, Pos('FCount: Intger;', Buf));
  Expected := Format('Unit1.pas(%d): Error: Undeclared identifier: ''Intger''', [Line]);
  Check(Tool('compile_project', '{}') and Has('failed') and Has(Expected),
    Format('compile_project reports the error at line %d of Unit1.pas', [Line]));
  Check(Tool('edit_file', '{"path":"Unit1.pas","old_text":"FCount: Intger;","new_text":"FCount: Integer;"}'),
    'edit_file error out');
  { forms }
  Check(Tool('form_list_components', '{"path":"Unit1.pas"}') and Has('Button1: TButton'), 'form_list_components');
  Check(Tool('form_get_properties', '{"path":"Unit1.pas","component":"Button1","filter":"Cap"}') and
    Has('Caption: TCaption = Button1'), 'form_get_properties');
  Check(Tool('form_set_property', '{"path":"Unit1.pas","component":"Button1","property":"Caption","value":"Go"}'),
    'form_set_property');
  Check(Tool('form_get_properties', '{"path":"Unit1.pas","component":"Button1","filter":"Caption"}') and Has('= Go'),
    'form_set_property took');
  Check(Tool('form_set_property', '{"path":"Unit1.pas","component":"Button1","property":"Font.Style","value":"[fsBold]"}'),
    'form_set_property nested');
  Check(Tool('form_get_properties', '{"path":"Unit1.pas","component":"Button1","object":"Font","filter":"Style"}') and
    Has('[fsBold]'), 'form_set_property nested took');
  Check(not Tool('form_set_property', '{"path":"Unit1.pas","component":"Button1","property":"DragKind","value":"dkNowhere"}') and
    Has('not a value'), 'form_set_property bad value');
  Check(Tool('form_get_properties', '{"path":"Unit1.pas","component":"Button1"}') and Has('Anchors: TAnchors = [akLeft,akTop]') and
    Has('OnClick: TNotifyEvent = '), 'form_get_properties all');
  Check(Tool('form_add_component', '{"path":"Unit1.pas","class_name":"TLabel","name":"Label9","left":16,"top":60,' +
    '"properties":{"Caption":"Hello"}}') and Has('Added Label9: TLabel'), 'form_add_component');
  Check(Tool('form_list_components', '{"path":"Unit1.pas"}') and Has('Label9: TLabel') and Has('Caption=''Hello'''),
    'form_add_component listed');
  Check(Tool('form_delete_component', '{"path":"Unit1.pas","component":"Label9"}'), 'form_delete_component');
  Check(Tool('form_list_components', '{"path":"Unit1.pas"}') and not Has('Label9'), 'form_delete_component gone');
  Check(Tool('compile_project', '{}') and Has('successfully'), 'compile_project with the changed form');
  { settings: read, a project option set and set back }
  Check(Tool('get_settings', '{}') and Has('Project options of ' + FDir + 'Project1.dpr') and Has('    Defines = ') and
    Has('    LibraryPath = ') and Has('  BlockIndent = ') and Has('Warnings turned off: '), 'get_settings');
  Check(Tool('get_settings', '{"names":["defines","LibraryPath","NoSuchOption"]}') and
    Has('Defines = ') and Has('(project option)') and Has('LibraryPath = ') and Has('(environment option)') and
    Has('NoSuchOption: no such option'), 'get_settings names');
  Check(Tool('get_settings', '{"scope":"project","list_all":true}') and Has('  WarnUnsafeCode = ') and
    not Has('LibraryPath'), 'get_settings list_all');
  Check(Tool('set_project_option', '{"name":"Defines","value":"AITEST;TRACE"}') and Has('is now AITEST;TRACE'),
    'set_project_option text');
  Check(Tool('get_settings', '{"names":["Defines"]}') and Has('Defines = AITEST;TRACE'), 'set_project_option took');
  Check(Tool('set_project_option', '{"name":"RangeChecks","value":"on"}') and Has('is now 1 (it was '),
    'set_project_option switch');
  Check(Tool('set_project_option', '{"name":"IncludeVersionInfo","value":"True"}') and Has('is now True'),
    'set_project_option flag');
  Check(not Tool('set_project_option', '{"name":"RangeChecks","value":"maybe"}') and Has('takes a whole number'),
    'set_project_option bad value');
  Check(not Tool('set_project_option', '{"name":"NoSuchOption","value":"1"}') and Has('There is no project option'),
    'set_project_option unknown');
  Check(not Tool('set_project_option', '{"name":"Keys","value":"x"}') and Has('is a list or a set'),
    'set_project_option list');
  Check(Tool('set_project_option', '{"name":"Defines","value":""}') and Tool('set_project_option',
    '{"name":"RangeChecks","value":"0"}') and Tool('set_project_option', '{"name":"IncludeVersionInfo","value":"False"}'),
    'set_project_option back');
  { a new unit in the project }
  Check(Tool('create_file', '{"path":"Unit2.pas","add_to_project":true,"content":"unit Unit2;\n\ninterface\n\n' +
    'function Twice(X: Integer): Integer;\n\nimplementation\n\nfunction Twice(X: Integer): Integer;\nbegin\n' +
    '  Result := 2 * X;\nend;\n\nend.\n"}') and FileExists(FDir + 'Unit2.pas'), 'create_file');
  Check(not Tool('create_file', '{"path":"Unit2.pas","content":"x"}') and Has('exists already'), 'create_file existing');
  Check(Tool('list_project_files', '{}') and Has('Unit2.pas'), 'create_file added to the project');
  Check(Tool('compile_project', '{}') and Has('successfully'), 'compile_project with the new unit');
  { saving }
  Check(Tool('save_files', '{}') and Has('Unit1.pas'), 'save_files');
  Disk := ReadFileBytes(Unit1);
  CheckD(Contains(Disk, 'FCount: Integer;') and Contains(Disk, '// AI harness self-test'), 'save_files on disk', Disk);
  Disk := ReadFileBytes(FDir + 'Unit1.dfm');
  CheckD(Contains(Disk, 'Go'), 'save_files wrote the form', Disk);
  Check(not Tool('save_files', '{}') and Has('None of these'), 'save_files nothing left');
  { the tool definitions as the backends send them: Claude's custom tools, OpenAI's function tools
    (the Responses API) }
  Settings := TAiMemorySettings.Create;
  B := TAiClaudeBackend.Create(Settings);
  O := TAiOpenAIBackend.Create(Settings);
  C := TAiConversation.Create;
  try
    C.Add(TAiMessage.Create(arUser));
    C.Last.AddText(IdeContext);
    C.Last.AddText('Hello');
    CheckRequest(B.BuildRequest(C, SystemPrompt(IdeName), FTools), '', '', 'input_schema', 'messages');
    CheckRequest(O.BuildRequest(C, SystemPrompt(IdeName), FTools), ' (OpenAI)', 'function', 'parameters', 'input');
  finally
    C.Free;
    O.Free;
    B.Free;
    Settings.Free;
  end;
end;

{ a backend's request (Body): eighteen tools with unique names, each of the type ToolType (''
  none) with an object schema in SchemaMember, and the IDE's state first in the history
  (HistoryMember); the checks' names end with Backend }
procedure TSelfTest.CheckRequest(const Body, Backend, ToolType, SchemaMember, HistoryMember: string);
var
  Req, T: TJson;
  Names: TStringList;
  I: Integer;
begin
  Req := TJson.Parse(Body);
  Names := TStringList.Create;
  try
    CheckD(Req.Arr('tools').Count = 18, 'eighteen tools' + Backend, IntToStr(Req.Arr('tools').Count));
    for I := 0 to Req.Arr('tools').Count - 1 do
    begin
      T := Req.Arr('tools').Item(I);
      Names.Add(T.Str('name'));
      if ((ToolType <> '') and (T.Str('type') <> ToolType)) or (T.Obj(SchemaMember) = nil) or
        (T.Obj(SchemaMember).Str('type') <> 'object') then
        CheckD(False, 'tool schema' + Backend, T.ToJson);
    end;
    Names.Sorted := True;
    Names.Duplicates := dupIgnore;
    CheckD(Names.Count = 18, 'tool names unique' + Backend, Names.CommaText);
    CheckD(Contains(Req.Arr(HistoryMember).Item(0).Arr('content').Item(0).Str('text'), '<ide_context>'),
      'ide context in the request' + Backend, Req.Arr(HistoryMember).Item(0).ToJson);
  finally
    Names.Free;
    Req.Free;
  end;
end;

{ a whole turn: the scripted backend calls read_file, gets its result and answers }
procedure TSelfTest.TestSession;
var
  S: TAiSession;
  B: TScriptBackend;
  Ap: TYesApprover;
  Start: Cardinal;
  R: TAiMessage;
begin
  B := TScriptBackend.Create(nil);
  Ap := TYesApprover.Create;
  S := TAiSession.Create(B, NewTools, SystemPrompt(IdeName));
  try
    S.Approver := Ap;
    S.Send('What does Unit1 declare?', IdeContext);
    Start := GetTickCount;
    while S.Busy and (GetTickCount - Start < 20000) do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);
    end;
    S.DrainEvents;
    CheckD(not S.Busy, 'session ended', '');
    CheckD(S.LastResult = atrDone, 'session done', IntToStr(Ord(S.LastResult)));
    CheckD(S.Conversation.Count = 4, 'session conversation', IntToStr(S.Conversation.Count));
    if S.Conversation.Count >= 3 then
    begin
      R := S.Conversation[2];
      if R.Count = 1 then
        CheckD((R[0].Kind = abToolResult) and not R[0].IsError and Contains(R[0].Text, 'unit Unit1;'),
          'session tool result', R[0].Text)
      else
        CheckD(False, 'session tool result', Format('%d blocks', [R.Count]));
    end;
    CheckD(B.Calls = 2, 'session backend calls', IntToStr(B.Calls));
    CheckD(S.TotalUsage.InputTokens = 200, 'session usage', IntToStr(S.TotalUsage.InputTokens));
  finally
    S.Free;
    Ap.Free;
  end;
end;

initialization
finalization
  FreeAndNil(Test);
end.
