{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiPrompt;

{ What the harness tells the model: the system prompt (the same for the whole conversation, so
  the prompt cache keeps it) and the IDE's state that goes before each message of the user. }

interface

{ the system prompt (UTF-8) for the IDE called IdeTitle }
function SystemPrompt(const IdeTitle: string): string;
{ the IDE's state now, as the <ide_context> block of the next user message (UTF-8; main thread) }
function IdeContext: string;

implementation

uses
  SysUtils, Classes, ToolsAPI, AiText, AiIde;

function SystemPrompt(const IdeTitle: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Add('You are an AI assistant built into ' + IdeTitle + ', an IDE for Delphi 7, as an expert of its Open Tools ' +
      'API. You help the developer with the Delphi projects open in the IDE: you read, explain, change, compile and ' +
      'design their code and forms with your tools.');
    L.Add('');
    L.Add('The environment');
    L.Add('- The language is Delphi 7, the Object Pascal of 2002. It has no generics, no for..in loops, no records ' +
      'with methods, no class helpers, no strict private or protected, no inline variable declarations, no ' +
      'anonymous methods and no Unicode string type: string is AnsiString. Use what Delphi 7''s RTL and VCL ' +
      'provide, and what the project''s own units provide.');
    L.Add('- Source files use CR LF line ends. Keep the style of the code around a change: indentation, naming, ' +
      'comments.');
    L.Add('- The project''s options (folders, search path, conditional defines, compiler switches, warnings, ' +
      'packages, version information), the IDE''s (Delphi''s folder, library path, package output) and the code ' +
      'editor''s (block indent, tabs, right margin) come from get_settings. Read them before you rely on a folder, ' +
      'a define, a switch or a package, or when a compile fails for a unit it cannot find. Change a project option ' +
      'with set_project_option, never by editing the .dof or .cfg.');
    L.Add('- Files open in the IDE may have unsaved changes. Your tools read an open file from its editor buffer, so ' +
      'you see what the developer sees. Your edits go into the editor buffer, where the developer can undo them; ' +
      'they reach the disk only through save_files.');
    L.Add('- Every change you make (edit_file, insert_text, create_file, save_files and the form changes) is shown ' +
      'to the developer, who allows or denies it. When a change is denied, do not try it again: ask the developer ' +
      'what they want instead.');
    L.Add('- Each message of the developer begins with the state of the IDE when they sent it, in <ide_context>: ' +
      'the active project, the file in the code editor, the cursor and the selected text. "This", "here" and "the ' +
      'selection" refer to it.');
    L.Add('');
    L.Add('How to work');
    L.Add('- Read before you change: the file (read_file) or the form (form_list_components, form_get_properties). ' +
      'edit_file needs old_text exactly as the file has it, with its indentation, and unique in the file.');
    L.Add('- After you change code, compile the project (compile_project) and fix the errors it reports before you ' +
      'finish. The compile includes the unsaved changes and does not touch the project''s output.');
    L.Add('- Keep changes as small as the task allows. Do not reformat, rename or reorganize what you were not asked ' +
      'to change.');
    L.Add('- Before your first tool call, say in one sentence what you are going to do. When you are done, say in a ' +
      'few lines what you changed, naming the files, and what the developer still has to do (for example, save).');
    L.Add('- When a request is unclear, or would mean a larger change than the developer may expect, ask first.');
    L.Add('- Answer in the developer''s language. The chat shows plain text: write short paragraphs and lists, and ' +
      'put code in fenced blocks.');
    Result := IdeToUtf8(L.Text);
  finally
    L.Free;
  end;
end;

function IdeContext: string;
var
  L: TStringList;
  P: IOTAProject;
  V: IOTAEditView;
  E: IOTASourceEditor;
  M: IOTAModule;
  Sel, Mark: string;
begin
  L := TStringList.Create;
  try
    L.Add('<ide_context>');
    P := ActiveProject;
    if P <> nil then L.Add('Active project: ' + P.FileName) else L.Add('No project is open.');
    V := TopView;
    if (V <> nil) and Supports(V.Buffer, IOTASourceEditor, E) then
    begin
      if E.Modified then Mark := ' (unsaved changes)' else Mark := '';
      L.Add(Format('Code editor: %s, line %d, column %d%s', [E.FileName, V.CursorPos.Line, V.CursorPos.Col, Mark]));
      Sel := SelectedText(V);
      if Sel <> '' then
      begin
        L.Add(Format('Selected text (lines %d-%d):', [V.Block.StartingRow, V.Block.EndingRow]));
        if Length(Sel) > 12000 then Sel := Copy(Sel, 1, 12000) + #13#10'... (the selection goes on)';
        L.Add(Sel);
      end;
    end
    else L.Add('The code editor shows no file.');
    M := ModuleServices.CurrentModule;
    if (M <> nil) and Supports(M.CurrentEditor, IOTAFormEditor) then
      L.Add('Form designer: ' + M.CurrentEditor.FileName + ' is shown.');
    L.Add('</ide_context>');
    Result := IdeToUtf8(TrimRightText(L.Text));
  finally
    L.Free;
  end;
end;

end.
