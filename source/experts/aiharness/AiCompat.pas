{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiCompat;

{ The OpenAI-compatible providers on AiOpenAI's base class (TAiOpenAICompatible). They speak Chat
  Completions, but for the custom endpoint, whose protocol the settings choose, and summarize
  long chats themselves (AiOpenAI):
    * OpenRouter (openrouter.ai): many vendors' models through one key. It reports what each
      request cost (usage.cost), and sends the model's reasoning as reasoning_details, which go
      back with their message unchanged, as its documentation asks. Anthropic's models are
      cached there only from a cache_control breakpoint: the request's automatic one. The context
      window comes from its model record (GET <base>/model/<id>, no key needed);
    * Ollama and LM Studio: local servers, no key needed. They give a model the context it was
      loaded with - often 4,096 tokens, less than the assistant's instructions and tools alone -
      and cut what does not fit. The window comes from the server once the model is loaded
      (Ollama: GET /api/ps; LM Studio: GET /api/v1/models), and the transcript says how to raise
      it when it is too small. Ollama does not take tool_choice;
    * a custom endpoint: any OpenAI-compatible server by its Base URL, its protocol chosen in the
      settings; nothing is known of its models. }

interface

uses
  Windows, SysUtils, Classes, AiText, AiJson, AiCore, AiRemote, AiOpenAI;

type
  TAiOpenRouterBackend = class(TAiOpenAICompatible)
  protected
    procedure AddChatOptions(Req: TJson); override;
    procedure EchoReasoning(Msg, Native: TJson); override;
    function AskWindow(const Model: string): Int64; override;
  public
    class function Id: string; override;
    class function DisplayName: string; override;
    class procedure ListModels(L: TStrings); override;
    class function DefaultModel: string; override;
    class function DefaultBaseUrl: string; override;
    class function KeyVariable: string; override;
  end;

  { a server on this machine (Ollama, LM Studio): no key needed, the output limit as max_tokens
    (the name their documentation lists), the efforts their reasoning models take }
  TAiLocalBackend = class(TAiOpenAICompatible)
  protected
    function MaxTokensField: string; override;
  public
    class procedure ListEfforts(L: TStrings); override;
    class function KeyRequired: Boolean; override;
  end;

  TAiOllamaBackend = class(TAiLocalBackend)
  protected
    function TakesToolChoice: Boolean; override;
    function AskWindow(const Model: string): Int64; override;
    function ContextAdvice: string; override;
    function ConnectionHint: string; override;
  public
    class function Id: string; override;
    class function DisplayName: string; override;
    class procedure ListModels(L: TStrings); override;
    class function DefaultModel: string; override;
    class function DefaultBaseUrl: string; override;
    class function KeyVariable: string; override;
  end;

  TAiLMStudioBackend = class(TAiLocalBackend)
  protected
    function AskWindow(const Model: string): Int64; override;
    function ContextAdvice: string; override;
    function ConnectionHint: string; override;
  public
    class function Id: string; override;
    class function DisplayName: string; override;
    class procedure ListModels(L: TStrings); override;
    class function DefaultModel: string; override;
    class function DefaultBaseUrl: string; override;
    class function KeyVariable: string; override;
  end;

  TAiCustomEndpointBackend = class(TAiOpenAICompatible)
  public
    class function Id: string; override;
    class function DisplayName: string; override;
    class procedure ListReasoning(L: TStrings); override;
    class function DefaultReasoning: string; override;
    class function KeyRequired: Boolean; override;
    class procedure ListProtocols(L: TStrings); override;
    class function DefaultProtocol: string; override;
  end;

implementation

{ ---------------------------------------------------------------- a local server }

function TAiLocalBackend.MaxTokensField: string;
begin
  Result := 'max_tokens';
end;

{ 'default' sends none }
class procedure TAiLocalBackend.ListEfforts(L: TStrings);
begin
  L.Add('default');
  L.Add('low');
  L.Add('medium');
  L.Add('high');
end;

class function TAiLocalBackend.KeyRequired: Boolean;
begin
  Result := False;
end;

{ ---------------------------------------------------------------- OpenRouter }

class function TAiOpenRouterBackend.Id: string;
begin
  Result := 'OpenRouter';
end;

class function TAiOpenRouterBackend.DisplayName: string;
begin
  Result := 'OpenRouter';
end;

{ models with tool calling and reasoning in OpenRouter's catalogue on 2026-11-22 }
class procedure TAiOpenRouterBackend.ListModels(L: TStrings);
begin
  L.Add('openai/gpt-6.2-sol');
  L.Add('anthropic/claude-opus-5.5');
  L.Add('google/gemini-4-neon');
  L.Add('moonshotai/kimi-k3.1-pro');
  L.Add('z-ai/glm-5.3');
  L.Add('deepseek/deepseek-v4.1-flash');
end;

class function TAiOpenRouterBackend.DefaultModel: string;
begin
  Result := 'openai/gpt-6.2-sol';
end;

class function TAiOpenRouterBackend.DefaultBaseUrl: string;
begin
  Result := 'https://openrouter.ai/api/v1';
end;

class function TAiOpenRouterBackend.KeyVariable: string;
begin
  Result := 'OPENROUTER_API_KEY';
end;

procedure TAiOpenRouterBackend.AddChatOptions(Req: TJson);
begin
  if Copy(LowerCase(ModelName), 1, 10) = 'anthropic/' then Req.PutObject('cache_control').PutStr('type', 'ephemeral');
end;

procedure TAiOpenRouterBackend.EchoReasoning(Msg, Native: TJson);
var
  D: TJson;
begin
  D := Native.Arr('reasoning_details');
  if (D <> nil) and (D.Count > 0) then Msg.Put('reasoning_details', D.Clone)
  else if Native.Str('reasoning') <> '' then Msg.PutStr('reasoning', Native.Str('reasoning'));
end;

{ the model record's context length: its top provider's, else the model's }
function TAiOpenRouterBackend.AskWindow(const Model: string): Int64;
var
  J, D, T: TJson;
begin
  J := AskServer(BaseUrl + '/model/' + Model, Result);
  if J = nil then Exit;
  try
    D := J.Obj('data');
    if D <> nil then
    begin
      T := D.Obj('top_provider');
      if T <> nil then Result := JsonInt64(T, 'context_length');
      if Result <= 0 then Result := JsonInt64(D, 'context_length');
    end;
    if Result <= 0 then Result := -1;
  finally
    J.Free;
  end;
end;

{ ---------------------------------------------------------------- Ollama }

class function TAiOllamaBackend.Id: string;
begin
  Result := 'Ollama';
end;

class function TAiOllamaBackend.DisplayName: string;
begin
  Result := 'Ollama';
end;

{ coding models with tool calling of Ollama's library on 2026-11-22; the -cloud tag runs on
  Ollama's servers (signed in, or with a key) }
class procedure TAiOllamaBackend.ListModels(L: TStrings);
begin
  L.Add('qwen3-coder:30b');
  L.Add('gpt-oss:20b');
  L.Add('devstral:24b');
  L.Add('gpt-oss:120b-cloud');
end;

class function TAiOllamaBackend.DefaultModel: string;
begin
  Result := 'qwen3-coder:30b';
end;

class function TAiOllamaBackend.DefaultBaseUrl: string;
begin
  Result := 'http://localhost:11434/v1';
end;

{ Ollama's cloud (https://ollama.com/v1) takes a key; the local server ignores it }
class function TAiOllamaBackend.KeyVariable: string;
begin
  Result := 'OLLAMA_API_KEY';
end;

function TAiOllamaBackend.TakesToolChoice: Boolean;
begin
  Result := False;
end;

function TAiOllamaBackend.ConnectionHint: string;
begin
  Result := 'Is Ollama running?';
end;

function TAiOllamaBackend.ContextAdvice: string;
begin
  Result := 'Give it more in Ollama''s settings (Context length) or with the environment variable ' +
    'OLLAMA_CONTEXT_LENGTH - at least 32768 tokens, 65536 for long tasks - and restart Ollama.';
end;

{ a model's name as Ollama lists it: without a tag it is the tag latest }
function OllamaName(const S: string): string;
begin
  Result := LowerCase(Trim(S));
  if (Result <> '') and (Pos(':', Result) = 0) then Result := Result + ':latest';
end;

{ the context the running model was loaded with (GET /api/ps); 0 while it is not loaded }
function TAiOllamaBackend.AskWindow(const Model: string): Int64;
var
  I: Integer;
  J, Arr, E: TJson;
  Name: string;
begin
  J := AskServer(ServerRoot(BaseUrl) + '/api/ps', Result);
  if J = nil then Exit;
  try
    Arr := J.Arr('models');
    if Arr = nil then Exit;
    Name := OllamaName(Model);
    for I := 0 to Arr.Count - 1 do
    begin
      E := Arr.Item(I);
      if not E.IsObject then Continue;
      if (OllamaName(E.Str('name')) = Name) or (OllamaName(E.Str('model')) = Name) then
      begin
        Result := JsonInt64(E, 'context_length');
        Exit;
      end;
    end;
  finally
    J.Free;
  end;
end;

{ ---------------------------------------------------------------- LM Studio }

class function TAiLMStudioBackend.Id: string;
begin
  Result := 'LMStudio';
end;

class function TAiLMStudioBackend.DisplayName: string;
begin
  Result := 'LM Studio';
end;

class procedure TAiLMStudioBackend.ListModels(L: TStrings);
begin
  L.Add('qwen/qwen3-coder-30b');
  L.Add('openai/gpt-oss-20b');
end;

class function TAiLMStudioBackend.DefaultModel: string;
begin
  Result := 'qwen/qwen3-coder-30b';
end;

class function TAiLMStudioBackend.DefaultBaseUrl: string;
begin
  Result := 'http://localhost:1234/v1';
end;

{ the token of LM Studio's "Require Authentication" (0.4 and later); off by default }
class function TAiLMStudioBackend.KeyVariable: string;
begin
  Result := 'LM_API_TOKEN';
end;

function TAiLMStudioBackend.ConnectionHint: string;
begin
  Result := 'Is LM Studio''s server running (Developer, Start Server)?';
end;

function TAiLMStudioBackend.ContextAdvice: string;
begin
  Result := 'Load the model in LM Studio with a larger context length - at least 32768 tokens, 65536 for long tasks.';
end;

{ the context the model is loaded with (GET /api/v1/models: its loaded instance's
  config.context_length); 0 while it is not loaded, -1 without that API (before 0.4) }
function TAiLMStudioBackend.AskWindow(const Model: string): Int64;
var
  I: Integer;
  J, Arr, E, Inst, Cfg: TJson;
  Key: string;
begin
  J := AskServer(ServerRoot(BaseUrl) + '/api/v1/models', Result);
  if J = nil then Exit;
  try
    Arr := J.Arr('models');
    if Arr = nil then Exit;
    Key := Trim(Model);
    for I := 0 to Arr.Count - 1 do
    begin
      E := Arr.Item(I);
      if not E.IsObject or not SameText(E.Str('key'), Key) then Continue;
      Inst := E.Arr('loaded_instances');
      if (Inst <> nil) and (Inst.Count > 0) and Inst.Item(0).IsObject then
      begin
        Cfg := Inst.Item(0).Obj('config');
        if Cfg <> nil then Result := JsonInt64(Cfg, 'context_length');
      end;
      Exit;
    end;
  finally
    J.Free;
  end;
end;

{ ---------------------------------------------------------------- a custom endpoint }

class function TAiCustomEndpointBackend.Id: string;
begin
  Result := 'OpenAICompatible';
end;

class function TAiCustomEndpointBackend.DisplayName: string;
begin
  Result := 'OpenAI-compatible endpoint';
end;

{ Responses only: reasoning.summary; 'default' sends none }
class procedure TAiCustomEndpointBackend.ListReasoning(L: TStrings);
begin
  L.Add('default');
  L.Add('auto');
  L.Add('concise');
  L.Add('detailed');
end;

class function TAiCustomEndpointBackend.DefaultReasoning: string;
begin
  Result := 'default';
end;

class function TAiCustomEndpointBackend.KeyRequired: Boolean;
begin
  Result := False;
end;

class procedure TAiCustomEndpointBackend.ListProtocols(L: TStrings);
begin
  L.Add(ProtocolChat);
  L.Add(ProtocolResponses);
end;

class function TAiCustomEndpointBackend.DefaultProtocol: string;
begin
  Result := ProtocolChat;
end;

initialization
  RegisterAiBackend(TAiOpenRouterBackend);
  RegisterAiBackend(TAiOllamaBackend);
  RegisterAiBackend(TAiLMStudioBackend);
  RegisterAiBackend(TAiCustomEndpointBackend);
end.
