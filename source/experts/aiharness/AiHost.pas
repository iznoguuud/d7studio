{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiHost;

{ The harness in the IDE: its settings (the registry, under the IDE's own key) and the sessions
  made from them - the backend the settings name (default Claude; the units of the backends
  register them), the IDE's tools and the system prompt. }

interface

uses
  Windows, SysUtils, Classes, AiCore, AiAgent;

const
  SettingsSubKey = 'AI Harness';
  DefaultBackendId = 'Claude';

type
  { values under HKEY_CURRENT_USER\<the IDE's base key>\AI Harness }
  TAiRegistrySettings = class(TAiSettings)
  private
    FKey: string;
  public
    constructor Create(const AKey: string);
    function ReadString(const Name, Default: string): string; override;
    procedure WriteString(const Name, Value: string); override;
    property Key: string read FKey;
  end;

{ the harness's settings (made at the first call) }
function HarnessSettings: TAiSettings;
procedure FreeHarnessSettings;
{ the backend class the settings name }
function SelectedBackendClass: TAiBackendClass;
function NewBackend: TAiBackend;
{ the tools of the harness }
function NewTools: TAiToolList;
{ a session with the selected backend, the tools and the system prompt }
function NewSession: TAiSession;

implementation

uses
  ToolsAPI, AiText, AiClaude, AiOpenAI, AiCompat, AiIde, AiPrompt, AiCodeTools, AiCompile, AiFormTools, AiOptionTools;

var
  FSettings: TAiSettings;

constructor TAiRegistrySettings.Create(const AKey: string);
begin
  inherited Create;
  FKey := AKey;
end;

function TAiRegistrySettings.ReadString(const Name, Default: string): string;
begin
  Result := KitReadRegString(FKey, Name, Default);
end;

procedure TAiRegistrySettings.WriteString(const Name, Value: string);
begin
  KitWriteRegString(FKey, Name, Value);
end;

function HarnessSettings: TAiSettings;
var
  Base: string;
begin
  if FSettings = nil then
  begin
    Base := '';
    if BorlandIDEServices <> nil then Base := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey;
    if Base = '' then Base := 'Software\D7AiHarness';
    if (Base <> '') and (Base[1] = '\') then Delete(Base, 1, 1);
    FSettings := TAiRegistrySettings.Create(IncludeTrailingPathDelimiter(Base) + SettingsSubKey);
  end;
  Result := FSettings;
end;

procedure FreeHarnessSettings;
begin
  FreeAndNil(FSettings);
end;

function SelectedBackendClass: TAiBackendClass;
begin
  Result := FindAiBackend(HarnessSettings.ReadString('Backend', DefaultBackendId));
  if Result = nil then Result := FindAiBackend(DefaultBackendId);
  if (Result = nil) and (AiBackendCount > 0) then Result := AiBackendClass(0);
end;

function NewBackend: TAiBackend;
var
  C: TAiBackendClass;
begin
  C := SelectedBackendClass;
  if C = nil then raise Exception.Create('No AI backend is registered.');
  Result := C.Create(HarnessSettings);
end;

function NewTools: TAiToolList;
begin
  Result := TAiToolList.Create;
  AddCodeTools(Result);
  AddCompileTools(Result);
  AddFormTools(Result);
  AddOptionTools(Result);
end;

function NewSession: TAiSession;
begin
  Result := TAiSession.Create(NewBackend, NewTools, SystemPrompt(IdeName));
  Result.MaxRounds := HarnessSettings.ReadInteger('MaxRounds', 60);
end;

initialization
finalization
  FreeHarnessSettings;
end.
