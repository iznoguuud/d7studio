# AI Harness

An AI assistant for the Delphi 7 IDE, built as an Open Tools API expert (a design-time package).
It works with the code open in the IDE: it reads and searches it, edits it in the editor, compiles
it, and changes forms in the designer. It uses only Delphi 7's standard ToolsAPI, so it loads in
D7 Studio and in Delphi 7's own IDE.

The model backend is abstract (`TAiBackend`). The backends:
- **Claude**, through Anthropic's Messages API;
- **OpenAI**, through its Responses API;
- the servers that speak OpenAI's API, on one base class (`TAiOpenAICompatible`): **OpenRouter**,
  **Ollama** and **LM Studio** (local), and any **OpenAI-compatible endpoint**.

## Installing

1. Build and install the package in Delphi 7's IDE or in D7 Studio: open `AiHarness.dpk` (File | Open)
   and choose **Install** in the package editor. The package requires `rtl`, `vcl` and `designide`, and
   names its images' resource script, `AiIcons.rc`; if the IDE reports `AiIcons.res` missing, run
   `brcc32 AiIcons.rc` in the package's folder first.
2. D7 Studio's Setup does this already: it installs `AiHarness.bpl` into Delphi 7's `Projects\Bpl` and lists
   it in `D7Studio.ini`, where D7 Studio loads it.
3. **View | AI Assistant** opens the assistant's window. It docks like the IDE's other tool windows.
4. **Settings...** in the window. **Provider** chooses the backend (so does the box at the right end
   of the window's tool bar); each provider keeps its own values:
   - **Model**: chosen from the provider's list, or typed (a custom endpoint has no list).
   - **Effort**: the provider's levels. `default` sends none: the model's own.
   - **Show reasoning**: Claude: `summarized` (default), `updates` or `omitted`. OpenAI:
     `auto` (default), `concise`, `detailed` or `omitted` (its reasoning summaries).
   - **Output limit**: 64000 tokens for Claude and OpenAI, 32000 for the others.
   - **Tool rounds per message**: 60, for all providers.
   - **Summarize at**: the prompt's size that sets a summary off. 0 means never; the minimum is the
     provider's (see "Long chats are summarized" below).
   - **Base URL**: the server's address. Left as it is, it is the provider's own. Point it at a proxy,
     another port, or Ollama's cloud (`https://ollama.com/v1`).
   - **Protocol**: the custom endpoint's choice, Chat Completions (default) or Responses. The other
     providers show theirs.
   - **API key**.

   | Provider | Default model | Base URL | Key | Protocol |
   |---|---|---|---|---|
   | Claude | `claude-opus-5-5` | `https://api.anthropic.com` | `ANTHROPIC_API_KEY` | Messages API |
   | OpenAI | `gpt-6.2-sol` | `https://api.openai.com/v1` | `OPENAI_API_KEY` | Responses |
   | OpenRouter | `openai/gpt-6.2-sol` | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` | Chat Completions |
   | Ollama | `qwen3-coder:30b` | `http://localhost:11434/v1` | none (`OLLAMA_API_KEY` for Ollama's cloud) | Chat Completions |
   | LM Studio | `qwen/qwen3-coder-30b` | `http://localhost:1234/v1` | none (`LM_API_TOKEN` if the server requires one) | Chat Completions |
   | OpenAI-compatible endpoint | typed | typed | optional | Chat Completions or Responses |

   The key is kept encrypted for your Windows account (DPAPI). It is stored under the IDE's
   registry key, in `HKEY_CURRENT_USER\<the IDE's key>\AI Harness`:
   - D7 Studio: `Software\D7Studio\AI Harness`;
   - Delphi 7: `Software\Borland\Delphi\7.0\AI Harness`.

   Without a saved key, the provider's environment variable (the table's) is used.

   **Local servers need a large context.** The assistant's instructions and tools alone take some
   10,000 tokens, and Ollama gives a model 4,096 by default (more with much video memory). What does
   not fit is lost. Give the model at least 32,768 tokens, 65,536 for long tasks:
   - Ollama: its setting *Context length*, or the environment variable `OLLAMA_CONTEXT_LENGTH`;
     restart Ollama afterwards;
   - LM Studio: the context length you load the model with.

   After the first answer the assistant learns the context the server gave the model, and says
   so in the transcript when it is too small.

## Using it

- **The window looks like the IDE's own views** (in D7 Studio: its floating and docked panels).
  Its tool bar - New Chat, Stop, Continue, Copy, Settings - sits on the view's grey ground and
  shows images of its own (IntelliJ's, as D7 Studio's; the IDE's icons are not used), with the provider box at the row's right end, in line with the conversation's frame. The conversation and the input box
  below it, with its Send button, lie in flat 1 px frames; the dialogs' boxes are flat too. The text is in the IDE's
  font, code in the code editor's font (its Editor Options; in D7 Studio a change there shows at once,
  also in the code already in the transcript).
- **The provider box** at the right end of the tool bar lists the providers, each with the model of
  its settings (`Claude (Anthropic API) · claude-opus-5-5`). The next message goes to the one you
  choose, with the whole conversation; the transcript says which provider and model answer from
  there on, and what is missing (an API key). The choice is saved, as Settings' Provider. The box
  is disabled while the assistant works; a provider chosen in Settings meanwhile is taken at the
  next message.
- Type a message. **Enter** sends it; **Shift+Enter** starts a new line.
- Each message carries the IDE's state at that moment: the active project, the file in the code
  editor with the cursor's line and column, and the selected text. So "this", "here" and "the
  selection" mean what you see.
- **The assistant knows the settings.** It reads the project's options (folders, search path,
  conditional defines, compiler switches, warnings, packages, version information, run
  parameters), the IDE's (Delphi's folder, library path, package output folders) and the code
  editor's (block indent, tabs, right margin) with `get_settings`. It changes a project option with
  `set_project_option`, shown to you first like its other changes.
- The transcript shows each turn under a heading, **You** or **Assistant**. The answer's Markdown is
  formatted as it streams in: code blocks and `inline code` in the editor's font on a shaded
  ground, **bold**, headings and list items. The model's reasoning is grey and italic; notes (a
  retry, a summary) are grey italic lines, errors red. Select and copy the text with the mouse,
  Ctrl+C or the transcript's menu (Copy, Select All, New Chat).
- At the bottom, the transcript follows the answer as it streams in. Scrolled up, it stays where
  you are, without flicker. When text arrives below your place, a **New lines** box appears over
  the transcript's foot. Click it (or scroll to the bottom, or press Ctrl+End) and the transcript
  goes to the end and follows the answer again. Docking, floating or resizing the view keeps
  your place: at the bottom it keeps following, scrolled up the same line stays at the top.
- The assistant works with its tools (below). The transcript shows each tool call in grey
  (`› read_file  Unit1.pas`) and its outcome below it: `✓ lines 1-120 of 300`, or a red `✕` and
  the error.
- **Every change is shown before it is made.** The dialog shows what changes as one list of lines:
  the lines that stay in grey, the ones that go on a red ground (`-`), the ones that come on a
  green ground (`+`), and how many lines it adds, removes or replaces. Then you choose:
  - **Allow**;
  - **Allow all in this chat**;
  - **Deny**, optionally with a reason that goes to the assistant.

  Reading and searching never ask.
- **Edits go into the editor buffer.** The file opens if needed. You can undo an edit, and nothing
  is saved unless you allow `save_files`.
- **Stop**, or **Esc** in the window (the input box, the transcript, Send), ends the assistant's
  work. **Continue** sends the conversation again after an error, a stop, a declined answer or the
  tool-round limit. **New Chat** starts over.
- The status line counts the tokens of the chat (`1,800 in, 110 out, 2,400 cached`). It also shows
  a rough cost and how full the model's context window is after the last answer (`context 1%`: the
  last request's prompt and its answer). The cost comes from list prices that can change (Claude,
  OpenAI), or from what OpenRouter reports for each request; the local servers' models show none. In D7 Studio
  it is the status line at the foot of the view, as the Project Manager's. In Delphi 7 the window
  has a status line of its own, with a meter of the context window; its hint gives the numbers
  (`12,345 of 1,000,000 tokens`). At 80% the transcript says once what comes next.
- **Long chats are summarized.** When a request's prompt reaches *Summarize at* tokens, the model
  first summarizes the conversation so far, then answers. The transcript shows
  `(Summarizing the conversation to fit the context window ...)` and then whether it worked. The
  requests after it start from the summary, so a chat can go on past the context window. With 0,
  or with a model that cannot summarize (Claude Haiku 4.5), start a New Chat when the window fills
  up. The summarizing is billed like a request: its tokens are in the counts and the cost. Who
  summarizes:
  - Claude: Anthropic's API, in the same request (default 150000 tokens, at least 50000);
  - OpenAI: OpenAI's server, in the same request (default 200000, below the 272,000 tokens from
    which OpenAI's prices double; at least 1000). Its summary is encrypted: the transcript cannot
    show it, and only OpenAI can continue from it. Switch to another provider after it, and that
    provider gets the whole conversation;
  - the other providers: the assistant itself, with a request of its own before the answer (default
    100000, at least 10000; with a model whose window is known, at most three quarters of it). The
    summary is readable, and every provider can continue from it.

## The tools

| Tool | What it does | Asks first |
|---|---|---|
| `get_ide_state` | The project group, active project, open files (unsaved ones marked), the code editor's file, cursor and selection, the form shown | no |
| `list_project_files` | The files of a project, units with their forms | no |
| `read_file` | A text file with line numbers, in parts of up to 2000 lines; an open file from its editor buffer | no |
| `search_code` | Plain-text search in the project, the group, the open files or a folder | no |
| `list_folder` | The files and subfolders of a folder | no |
| `open_file` | Shows a file at a line in the code editor | no |
| `edit_file` | Replaces text that occurs once (or every occurrence) in the editor buffer | yes |
| `insert_text` | Inserts at a line, at the cursor, or in place of the selection | yes |
| `create_file` | A new file (system code page, CR LF), opened, optionally added to the project | yes |
| `save_files` | Saves files with unsaved changes | yes |
| `compile_project` | Compiles with dcc32, unsaved changes included, into a scratch folder; returns the messages with file and line and lists them in the Messages view (group "AI Harness") | no |
| `form_list_components` | A form's components as a tree, with positions and captions | no |
| `form_get_properties` | A component's published properties and values, nested objects too | no |
| `form_set_property` | Sets a property as the Object Inspector does (`Font.Style = [fsBold]`) | yes |
| `form_add_component` | Adds a component of a registered class, with a parent, bounds and properties | yes |
| `form_delete_component` | Deletes a component | yes |
| `get_settings` | A project's options (Project \| Options), the IDE's environment options (Delphi's folder, library and browsing paths, package output, compiling, the designer, code insight) and the code editor's (block indent, tabs, right margin, font); or the options named; or every option the IDE lists | no |
| `set_project_option` | Sets one option of a project: a number (a switch 1 on, 0 off), True / False, or text | yes |

`compile_project` never touches the project's own output. Everything goes to
`%TEMP%\D7AiHarness\<project>-<hash>\`. The compile works like this:
- **The project file.** A copy of it names its units with absolute paths.
- **Scratch copies.** Units come from scratch copies, in the system code page, when they have unsaved
  changes (their text or their form, the form taken from the designer), or when dcc32 cannot read
  them as they are (a BOM, UTF-16).
- **Options.** The project's `.cfg` supplies the options. In front of its paths go the project's
  folder and the copied units' own folders; after them, the IDE's library path.
- **Make.** It is a make (`-M`), as in the IDE. Before each compile, the `.dcu` of every unit copied,
  this time or the last time, is deleted, so changes that were undone never linger.
- **Paths.** dcc32 reads the system code page. Paths with other characters reach it in their short
  (8.3) form, and the names it prints are mapped back to the real files.

## How it works

| Unit | What it holds |
|---|---|
| `AiText` | UTF-8 and code page conversions, files with their encodings, lines, Base64, DPAPI (`..\kit\KitText.inc`) |
| `AiJson` | JSON: a document tree, a parser and a writer (UTF-8, number literals kept) |
| `AiHttp` | An abstract HTTP client, its WinHTTP implementation (cancellable from any thread), a parser of server-sent events |
| `AiCore` | The provider-neutral model: the conversation, `TAiBackend` and its registry, context management (the window, summaries of long chats), `TAiTool` with schema validation, `TAiSettings` |
| `AiAgent` | `TAiSession`, the agent loop in a worker thread |
| `AiRemote` | What the backends behind an HTTP API share: the client, the settings' values, the streamed POST tried again with backoff, the API's errors as messages, the GET of a model's information |
| `AiClaude` | The Claude backend |
| `AiOpenAI` | `TAiOpenAICompatible`, the base class of the OpenAI-compatible backends (the Responses API and Chat Completions, summaries of their own), and the OpenAI backend |
| `AiCompat` | The OpenAI-compatible providers: OpenRouter, Ollama, LM Studio, a custom endpoint |
| `AiCompileCore` | dcc32's messages, the project file's paths rewritten, Delphi 7's folder |
| `AiProcess` | Running a console program (dcc32) with its output captured (`..\kit\KitProcess.inc`) |
| `AiIde` | The Open Tools API: projects, modules, editor buffers, the cursor and the selection (`..\kit\KitIde.inc`); the paths of the tools and of the compiler |
| `AiCodeTools`, `AiCompile`, `AiFormTools`, `AiOptionTools` | The tools |
| `AiPrompt` | The system prompt and the IDE's state sent with each message |
| `AiHost` | The settings (registry) and the sessions made from them |
| `AiChatWin`, `AiApproveDlg`, `AiSettingsDlg` | The window and the dialogs |
| `AiUI` | Their look, after D7 Studio's views: flat frames and tool bars, the IDE's fonts, Visual Studio's images (`KitBitmapIcons`), the view's status line, the transcript (Rich Edit 4.1, Unicode, formats; kept as RTF while its window is made again), the approval's diff lines (`..\kit\KitUI.inc`) |
| `AiMarkdown` | The answer's Markdown as runs of styled text, while it streams in |
| `AiWizard` | The expert: View \| AI Assistant, the window registered with the IDE's desktop |
| `AiSelfTest` | The self-test in the IDE (on the kit's `TKitSelfTest`) |
| `AiIcons.bmp`, `AiIcons.rc` | The window's images: JetBrains' IntelliJ icons and D7 Studio's own drawings, a row of 16 x 16 cells (`AiIcons.bmp`) and linked as the resource `AIICONS` (`AiHarness.dpk`). `AiChatWin` names the cells (`ai...`) and maps its actions' images to them |

`AiText`, `AiUI`, `AiProcess` and the first part of `AiIde` are code the IDE experts share with
the Git expert (`..\git`): their units compile the include files of `..\kit` under this package's names
(`..\kit\README.md`). Their names begin with `Kit` (`KitFlatToolBar`, `TKitRichView`, `TKitStringBuilder`
...); a change there changes both experts.

**Images.** The window shows its own images, never the IDE's. `KitBitmapIcons` (`..\kit\KitUI.inc`)
makes the image lists from the resource `AIICONS`: with alpha where comctl32 6 blends it (D7 Studio),
else blended onto the tool bar's ground with a mask (Delphi 7's IDE runs on comctl32 5). A disabled
command's image is greyed as Visual Studio greys it. The images are
made from the IntelliJ icons (`..\..\THIRD-PARTY-NOTICES.md` has their licence).

**A turn** runs in a worker thread:
1. The backend sends the conversation and streams back the assistant's message.
2. Each tool call is checked against the tool's schema.
3. A change is previewed and approved in the main thread.
4. The IDE's tools run in the main thread (`TThread.Synchronize`); the compiler runs in the worker
   thread.
5. The results go back as the next user message. The loop repeats until the model ends its turn,
   the user stops it, or the tool-round limit is reached.

The window gets the session's events through a queue and a posted message, so streaming never
waits for the window.

**The conversation is only appended to.** A message, once sent, never changes. That keeps the
model's reasoning blocks valid and the prompt cache's prefix intact. A failed, stopped or declined
answer is not added; the next message, or Continue, goes on from the user's last message.

**Context management is the core's, the same for every provider** (`AiCore`):
- **The figure.** A backend gives each message `ContextTokens` (its request's prompt and the
  answer) and the model's `ContextWindow`.
- **Summaries.** A summary of the conversation is a block of the kind `abSummary` at the start of
  an assistant message. It stands for everything before it: the requests after it start with the
  message that holds it (`TAiConversation.LastSummary`), in the form the provider's API takes. A
  summary its provider keeps encrypted is an `abSummary` block without text: that provider's
  backend starts its requests there itself, and the others send the conversation before it.
- **When.** `TAiBackend.CompactAt` decides when to summarize: the setting `<provider>.CompactAt`,
  at least the backend's `MinCompactAt`, and 0 when the model cannot (`ModelCompacts`).
- **The window.** The session passes the threshold on with the usage, and the window reports a
  summary from its block's events.

**The Claude backend** (`POST /v1/messages`, `anthropic-version: 2026-10-21`, streamed) sends:
- adaptive thinking with the chosen display, and `output_config.effort`;
- the system prompt with a cache breakpoint, plus the automatic cache breakpoint for the growing
  conversation;
- the tools with `eager_input_streaming`. The session validates their input itself, and input that
  is not valid JSON goes back to the model as an `INVALID_JSON` error;
- `fallbacks: "default"` with the beta `server-side-fallback-2026-07-01`, on the models that offer
  it. When a safety classifier declines a request, the fallback model answers in the same call.
  The thinking and tool calls of the declined attempt are neither run nor echoed;
- `context_management` with a `compact_20260112` edit (beta `compact-2026-01-12`) when `CompactAt`
  is not 0. It is triggered at `CompactAt` input tokens, and its instructions say what the summary
  keeps and that the summarizer calls no tools. The API returns the summary as a `compaction`
  block: that is the `abSummary` block, echoed as it came, also before a `fallback` block. The
  summary's own tokens (`usage.iterations`) are counted.

After a summary, the requests start with the assistant message that holds the compaction block, the
shape the API's documentation shows. A summary written by another provider, or one the model cannot
take, goes first as a user message of its own. The compaction beta goes with every request that
holds a compaction block, also when summarizing is off.

Before a model's first request, the backend asks the Models API (`GET /v1/models/<id>`, waiting 30 s
at most) for the model's window (`max_input_tokens`) and whether it can summarize
(`capabilities.context_management.compact_20260112`). It asks before each request until it gets an
answer (a refusal counts); until then it uses its own tables.

It keeps the assistant's blocks as the API sent them and sends them back unchanged. Rate limits,
overloads and server errors are retried with backoff (it honours `retry-after`; `AiRemote`, shared
with the other backends).

**The OpenAI backend** (`POST /v1/responses`, streamed) is stateless: `store: false`, and every
request carries the whole conversation as items. What it sends:
- the system prompt as `instructions`, the messages as items: the user's text as `input_text`,
  the tools' results as `function_call_output`;
- the tools as function tools with `strict: false` (their schemas have optional members);
- `reasoning` with the effort and the summary's kind, `include: ["reasoning.encrypted_content"]`,
  and `max_output_tokens`;
- `context_management` with a `compaction` entry and `compact_threshold` = *Summarize at*.

The items of an answer are kept as they came and sent back unchanged: `message` with its `phase`,
`reasoning` with its summaries and encrypted content, `function_call`, `compaction`. On 2026-11-22
OpenAI's API took them back with their ids.

The stream has `event:` lines and no `[DONE]`. The message is built from the output of
`response.completed` (or `incomplete`, `failed`); the deltas (text, reasoning summaries, the
calls' arguments) only show it while it comes. A response cut at the output limit stops as
`max_tokens`; a refusal, or `content_filter`, as declined.

The server's compaction (measured): once the input crosses the threshold, the server summarizes it
before it answers, and after the answer it summarizes the context again when that crossed it. The
output is then `[compaction, message, compaction]`, each `compaction` item encrypted. The requests
after it start with the last one, which OpenAI's guide allows. The usage counts the summaries.

The usage: `input_tokens` holds the cache reads (`cached_tokens`) and writes
(`cache_write_tokens`); the harness counts them apart. The window and the prices are those of
OpenAI's pages on 2026-11-22:

| Model | Window (largest prompt) | Input | Cached | Cache write | Output (USD per million tokens) |
|---|---|---|---|---|---|
| `gpt-6.2-astra` | 922,000 | 8 | 0.40 | 10 | 40 |
| `gpt-6.2-sol` | 922,000 | 2 | 0.10 | 2.50 | 10 |
| `gpt-6.1-terra` | 922,000 | 1 | 0.05 | 1.25 | 5 |
| `gpt-6-luna` | 922,000 | 0.10 | 0.01 | 0.125 | 0.50 |

**The OpenAI-compatible providers** share the base class `TAiOpenAICompatible` (`AiOpenAI`). It
speaks the Responses API, as above, or Chat Completions (`POST <base>/chat/completions`):
- the system prompt as a `system` message; the user's text as one `user` message, the tools'
  results as `tool` messages before it;
- an answer as `content` plus `tool_calls`;
- `stream_options.include_usage` for the usage chunk, the output limit as `max_completion_tokens`
  (Ollama and LM Studio: `max_tokens`), the effort as `reasoning_effort`.

The stream is `data:` lines that end with `[DONE]`. The model's reasoning comes as
`reasoning_content`, `reasoning` or `reasoning_details` and is shown grey in the transcript. Tool
calls come in pieces or whole, and a call without an id gets one. An error inside the stream
(OpenRouter's chunk with an `error` member) ends the answer.

Each provider's specifics:
- **OpenRouter**:
  - the `reasoning_details` go back with their message unchanged, as its documentation asks;
  - Anthropic's models get the request's automatic `cache_control` breakpoint;
  - the cost is the one OpenRouter reports (`usage.cost`);
  - the window comes from the model's record (`GET <base>/model/<id>`, no key needed).
- **Ollama** takes no `tool_choice`. The window is the context of the loaded model
  (`GET /api/ps`).
- **LM Studio**: the window is the context of the loaded model (`GET /api/v1/models`, LM Studio
  0.4 and later).
- **The custom endpoint** knows nothing of its models: no window, no price.

These providers summarize long chats themselves. Once the prompt would reach *Summarize at* (the
last answer's context and what came after it), the backend first asks the model for a summary:
the conversation, then the summary's instructions, with no tool calls (`tool_choice: "none"`, or
no tools where the server takes no `tool_choice`). Then it sends the summary as a user message of
its own, in place of what it stands for. The summary is a readable `abSummary` block at the start
of the answer. Its request's tokens are counted with the answer's.

## Adding a provider

Write a unit with a class derived from `TAiBackend`:
- `Id` (the prefix of its settings) and `DisplayName`;
- the choices and defaults of the settings dialog: `ListModels`, `ListEfforts`, `ListReasoning`,
  `Default...`, and `KeyVariable`;
- `Send`. It turns the neutral `TAiConversation` into the provider's request and streams the
  answer to `TAiBackendEvents`. It returns a `TAiMessage` of `TAiBlock`s: text, reasoning, tool
  calls. Keep each block's provider form in `Native`, with `NativeOwner = Id`, so that it is
  echoed unchanged; blocks of another provider come with only their neutral fields;
- `Cancel` / `ResetCancel` (from any thread), and `EstimateCost` if you like;
- context management:
  - set each message's `ContextTokens` and override `ContextWindow`, for the figure.
    `ContextWindow` sends no request; learn the window in `Send`;
  - for summaries, override `SupportsCompaction`, `DefaultCompactAt`, `MinCompactAt` and
    `ModelCompacts`. In `Send`, once the prompt reaches `CompactAt`, summarize what came before:
    by the provider's API, or by a request of your own. Return the summary as an `abSummary` block
    at the start of the message, its text the summary, and report it with `BlockStarted` and
    `BlockFinished`;
  - start the requests with the message at `TAiConversation.LastSummary`, and count the summary's
    tokens in `Usage`. A summary another provider wrote (an `abSummary` block without your
    `Native`) goes in the form your API takes; Claude's backend sends it as a user message of its
    own.

Call `RegisterAiBackend` in the unit's `initialization` and add the unit to `AiHarness.dpk`. The
settings dialog lists every registered backend, and the tools and the loop work with any of them.

**A server that speaks OpenAI's API** needs only a class derived from `TAiOpenAICompatible`
(`AiOpenAI`). `AiCompat`'s providers are the examples. It says:
- `Id`, `DisplayName`, `DefaultBaseUrl` (with its `/v1`), `KeyVariable`, `KeyRequired`;
- `ListModels` and `DefaultModel`, and `ListEfforts`;
- its protocol: `DefaultProtocol`, or `ListProtocols` to let the settings choose.

And, where the server differs, it overrides:
- `AddHeaders`: the key's header (default `Authorization: Bearer`);
- `MaxTokensField`: the output limit's member;
- `TakesToolChoice`: False if the server takes no `tool_choice`;
- `AddChatOptions`: members of its own;
- `EchoReasoning`: the model's reasoning, back with its message;
- `KnownModel`: windows and prices it knows without asking;
- `AskWindow`: the window, from the server (`AskServer` GETs its JSON with the request's headers
  and tells a refusal, which is not asked again, from no answer);
- `ContextAdvice`, `ConnectionHint`: what the transcript says of a small context, or of a server
  that does not answer;
- `ServerCompaction`: the server summarizes (Responses' `context_management`).

## In Delphi 7's own IDE

The harness works in Delphi 7's own IDE as well as in D7 Studio (checked on 2026-11-24). Builds from
before that day do not work there: files open in the editor read as empty (`read_file`,
`edit_file`, `search_code` and `compile_project` go wrong), and the tool bar shows only New
Chat, Stop and Continue. If you use an older `AiHarness.bpl` in Delphi 7, build and install it
again.

## Limits

- Event handlers are not set by the form tools: they need code in the unit.
- `set_project_option` sets numbers, flags and text; not the version information's keys (a list).
  The IDE writes the project's options files: D7 Studio at once, Delphi 7 when the project is saved
  (File | Save All). `compile_project` reads the project's `.cfg`, so in Delphi 7 a changed option
  reaches it only after that save.
- `compile_project` compiles the unsaved changes of the project's units, the ones the project file
  names, and of their forms. Other files with unsaved changes (include files, units found on the
  search path) are compiled from disk, and the result says so.
- `search_code` searches plain text, not regular expressions.
- The transcript is plain text: Markdown is not rendered. Conversations are not saved.
- A chat is summarized only by models that can do it, at the prompt size set. A single request
  larger than the window (a huge tool result) still fails; New Chat starts over. A summary keeps
  what its instructions name, not every detail.
- The cost shown uses one price per token kind. Claude Haiku 5.5 costs more for prompts over
  100,000 tokens, and OpenAI's models twice as much input and 1.5 times the output for prompts over
  272,000 tokens, so their estimates are low for those. OpenAI's cache writes are priced at the
  30-minute rate (12-hour writes cost twice as much).
- OpenAI's summaries of a chat are encrypted: the transcript says that the chat was summarized, not
  what the summary keeps.
- A local server cuts what does not fit the context it gave the model (see "Local servers need a
  large context").
- A tool runs in the IDE's main thread at its next chance, also inside the IDE's own nested message
  loops (a dialog, a compile in progress). After Allow all in this chat, no dialog stands between
  the call and the change.
- In Delphi 7's IDE, which works in the system code page, characters that the code page lacks become
  `?`. D7 Studio, which works in UTF-8, keeps them.
