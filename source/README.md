# D7 Studio

An IDE for Borland Delphi 7 projects, written in Delphi 7. It keeps the layout and the muscle
memory of the Delphi 7 IDE, with the look of the running Windows. Its setup modernizes the
installed Delphi 7's RTL and VCL in place: native Unicode, per-monitor DPI awareness and the
current Windows API.

> [!IMPORTANT]
> **To build D7 Studio, patch your Delphi 7 first.** D7 Studio's sources use the modernized
> RTL/VCL (`ModernMan`, `Utf8Mode`, `WindowsEx` ...), which a stock Delphi 7 does not have, so they
> do not compile against it. Patch the Delphi 7 you build with by installing D7 Studio's setup, or
> with `patch.ps1`, which comes with the patch, from an elevated PowerShell (see
> [MODERNIZATION.md](MODERNIZATION.md)).

## Installing

Requirements:
- An installed Delphi 7 with Update 1 (Delphi 7.1: Help | About shows "Version 7.0 (Build 8.1)";
  the Database supplemental may be on it too). Setup finds it through its registry key
  (`RootDir`) and stops, with Delphi 7 unchanged, when there is none, when its runtime packages
  are not Update 1's, or when one of the 127 files it patches (packages, DCUs, DCPs, sources)
  is not byte for byte Update 1's file as Borland shipped it.
- No other D7 Studio installed. Setup finds an installed one in Windows' list of programs:
  - A D7 Studio that Setup installed into the same Delphi 7 is updated in place: its settings
    stay (`D7Studio.ini` and the other files it keeps in `Bin`,
    `HKEY_CURRENT_USER\Software\D7Studio`), and so does the backup of Delphi 7's files. For fresh
    settings, uninstall it first (Windows' Settings, Apps). D7 Studio offers such updates itself:
    *Help | Check for Updates...*, and once a day at start-up (*Tools | Environment Options |
    Preferences | Check for updates at start-up*), look for a newer release on GitHub; *Update*
    downloads its setup, checks it against the release's SHA-256, closes D7 Studio and starts it.
  - Any other one Setup offers to remove first with its own uninstaller; if you say no, or it is
    still there afterwards, Setup stops. It stops too while an earlier installation's
    `<Delphi 7>\D7Studio` folder is left.
- Administrator rights.
- Windows 10 1903 or later with the visual styles on. D7 Studio runs with UTF-8 as its code page.
  On an older Windows Setup says so and installs nothing. Windows XP cannot start Setup at all
  ("not a valid Win32 application"): Inno Setup 6 makes setups for Windows 7 and later.

Setup changes Delphi 7's own folder:
- **The RTL/VCL is patched in place.** Setup carries none of these files, neither Borland's nor
  modernized ones: only the differences. It makes each modernized file from Delphi 7's own and
  its difference (with Windows' `msdelta.dll`), checks both by SHA-256 and puts the result in the
  original's place. It patches 127 files:
  - `Bin`: the six runtime packages (`rtl70.bpl`, `vcl70.bpl`, `vclx70.bpl`, `dbrtl70.bpl`,
    `vcldb70.bpl`, `vclactnband70.bpl`) and `borlndmm.dll`;
  - `Lib`: the DCUs of the changed units and the packages' `.dcp` files; `Lib\Debug`: those DCUs
    with debug information;
  - `Source`: the sources of the changed units (`Rtl\Sys`, `Rtl\Common`, `Rtl\Win`, `Vcl`), the
    ones the DCUs were compiled from.

  Only what Delphi 7 does not have comes whole: the new units (`Utf8Mode`, `ModernMan`,
  `ShellScaling`, `WindowsEx`, `FastMM4` ...) with their DCUs and sources, `ModernMan.res` /
  `ModernManUtf8.res` and `FastMM_FullDebugMode.dll`. The patched packages keep every export of
  Borland's, so Delphi 7's other packages load with them.
- **D7 Studio** goes into `Bin`: `D7Studio.exe` with its map, Scintilla (`Scintilla.dll`,
  `Lexilla.dll`), `migrate.exe`, this file,
  [FEATURES.md](FEATURES.md), [RELEASE-NOTES.md](RELEASE-NOTES.md) (what changed in each version),
  [MODERNIZATION.md](MODERNIZATION.md), [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) (the
  licence of the IntelliJ Platform icons that D7 Studio's icons are made of) and `LICENSE.txt`,
  D7 Studio's license (MIT), which Setup also shows before it installs anything.
- **D7 Studio's two experts**, the AI assistant and Git, go into `Projects\Bpl`: `AiHarness.bpl`
  and `GitExpert.bpl`, design packages that D7 Studio loads (see "The IDE" below).
- **The UTF-8 compiler** goes into `Bin` too: `dcc32u8.exe`, Delphi 7's own `dcc32.exe` under
  another name (a hard link to it, else a copy), with `dcc32u8.exe.manifest`, which starts it with
  UTF-8 as its code page. D7 Studio compiles your programs that run in UTF-8 with it (see Target
  Windows below). Uninstalling removes both.
- **A backup.** Before it changes anything, Setup copies every file it will patch to
  `<Delphi 7>\D7Studio\Backup`; if one cannot be copied, it stops and Delphi 7 stays unchanged.
  An installation that does not finish puts back what it backed up. An update keeps the backup
  of the first installation; one that does not finish leaves D7 Studio installed, with the new
  RTL/VCL and the files it had replaced already: run Setup again to finish it, or uninstall D7
  Studio.

**Help.** D7 Studio shows Delphi 7's own WinHelp files, in its `Help` folder: Help | Delphi Help
and F1 open `d7.hlp`, whose contents and index take in all of Delphi 7's help files, Help | VCL
Reference `d7vcl.hlp`, and Help | Windows SDK `win32.hlp` of `Borland Shared\MSHelp` when
Delphi 7 has it. Windows 10 and later have only a stub of the WinHelp viewer, which says that
the feature is missing, so Setup puts **Microsoft's WinHelp viewer** in its place, system-wide: it
works for Delphi 7 and every other program too. The viewer is Microsoft's, from its package
KB917607 for Windows 8.1: `winhlp32.exe` in the Windows folder with its texts (English, and the
languages Windows has), and its full-text search in the 32-bit system folder. Windows' stub files
are kept in `<Delphi 7>\D7Studio\WinHelp`, and the new files get their owner and permissions. A
Windows update or `sfc /scannow` may put the stub back; installing D7 Studio again brings the
viewer back.

Uninstalling D7 Studio puts Delphi 7's `Bin`, `Lib` and `Source` back as they were:
- The patched files get Borland's back from the backup; the files Setup added go.
- Windows' stub of the WinHelp viewer comes back, with its owner and permissions; the viewer's
  other files go.
- The files D7 Studio and `migrate` wrote go: in `Bin` its settings (`D7Studio.ini`,
  `D7Studio.dof`, templates ...), `error.log`, `migrate.log`, `Debug\` and `Imports\` (type
  libraries imported without a project). Such files that were there before the installation
  stay, and so do files of other programs. A `Help2` folder that an earlier version of D7 Studio
  installed Delphi 7's help into is cleaned up the same way.
- `Bin` gets its permissions back.
- `HKEY_CURRENT_USER\Software\D7Studio` (D7 Studio's experts, the settings of its design windows
  and experts) is deleted, for the user who uninstalls.

Close D7 Studio, Delphi 7 and any WinHelp window first: the uninstaller does not start while a
program runs from `Bin` or the WinHelp viewer runs.

Options in Setup:
- A Start menu group, *D7 Studio*: D7 Studio, this file, the comparison with Delphi 7's IDE, the
  modernized RTL/VCL's document, the license and *Uninstall D7 Studio*. A desktop shortcut.
- File associations, each off by default: `.dpr`, `.dpk`, `.bpg`, `.pas`, `.dfm`, `.inc`, `.res`,
  `.rc`, `.tlb`.
- **Migrate the Delphi 7 configuration** into D7 Studio's settings: a checkbox on Setup's last
  page, before *Launch D7 Studio*. It is checked on a first installation. Finish opens the
  migration dialog, and D7 Studio starts when it is closed.

**Migrating from Delphi 7.** The dialog shows what to take as a tree:
- the groups: Library, Design packages, Experts, Files, Environment, Editor and Debugger Options,
  Tools menu, Environment variables, History;
- their parts, e.g. the library path apart from the browsing path, the editor's colours apart
  from its key mapping, recent projects apart from history lists;
- each design package, DLL expert, expert's settings, tool and environment variable that Delphi 7
  has.

*Migrate* closes it when the migration succeeds; when it fails, the report shows in the dialog.
Either way the report goes to `migrate.log` next to `D7Studio.ini`. **Tools | Migrate from
Delphi 7...**, a tool that Setup adds to D7 Studio's Tools menu, shows the same dialog at any time,
also while D7 Studio runs (the settings count from its next start), and so does `migrate.exe`
started on its own. From a
command prompt: `migrate <folder> -WhatIf` shows what would change, `-Only <parts>` and
`-Exclude <part>:<name>` choose, and `migrate -List -` prints the items (`migrate -Help` lists the
parts).

D7 Studio keeps its settings next to its EXE (`Bin\D7Studio.ini`); Setup lets the users write
there. A new installation starts from default settings: editor,
debugger, designer and formatter options, the library paths, the migration tool. An existing
`D7Studio.ini` is kept; Setup only adds the migration tool to its Tools menu and the two experts to
its design packages if they are missing. A new installation's design packages are Borland's
standard ones and the two experts; migrating adds Delphi 7's.
Its experts are listed in `HKCU\Software\D7Studio\Experts` and the `[Experts]` section of
`D7Studio.ini`.

## The modernized RTL/VCL in your programs

Programs that you compile with D7 Studio, or with Delphi 7's own IDE and dcc32, use the modernized
units from Delphi 7's `Lib`. [MODERNIZATION.md](MODERNIZATION.md), beside this
file, describes them in full: every feature, its switches and what to know. In short:

- **Compatible.** Existing code, DCUs and component packages compile and link as before. Most new
  behaviour has a global switch back to Delphi 7's (`UseLatestCommonDialogs`,
  `PerMonitorDpiScaling`, `DoubleBufferedViews`, `MainFormOnTaskbar` ...).
- **`ModernMan` / `ModernManUtf8`.** Add one of them to the `.dpr`'s uses clause instead of
  `XPMan`. They give the program a current manifest: Common Controls 6, Windows Vista to 11,
  per-monitor V2 DPI awareness, long paths. `ModernManUtf8` adds the UTF-8 code page.
- **Unicode through UTF-8.** In UTF-8 mode `string` holds UTF-8, so any character works in the
  VCL, file names, the clipboard, sorting and formatting.
- **Per-monitor DPI.** Forms, fonts, controls, image lists, glyphs and theme parts scale to the
  monitor and rescale when moved.
- **Current dialogs and look.** The Common Item Dialog for `TOpenDialog` / `TSaveDialog`, task
  dialogs for `MessageDlg`, the modern folder picker, Explorer-style list and tree views, and the
  Windows 7 taskbar model.
- **Several monitors.** Hints, drop-down lists and `poDesktopCenter` respect each monitor's work
  area.
- **Windows API.** Fixed Delphi 7 bindings, the Vista to 11 additions in the existing API units,
  and new units: `ShellScaling`, `DwmApi`, `WindowsEx`, `WinSock2`, `ShLwApi`, `BCrypt`,
  `WtsApi32`, `PowrProf`, `UserEnv`.
- **FastMM4** is the memory manager, with leak reports (`ReportMemoryLeaksOnShutdown`).

Project options that D7 Studio applies when it builds a program (each per project):
- **Enable runtime themes** (on by default): a Common Controls 6 manifest when the program brings
  none.
- **Target Windows** (*Application*, *Output settings*): the Windows the program is for.
  - *Windows 10 1903 or later (UTF-8 code page)*, the default: the program's manifest asks for
    UTF-8, and the sources go to the compiler in UTF-8. On older Windows, which ignore that code
    page, the program does not start: it says "This program requires Windows 10 version 1903 or
    later." (the modernized RTL; exit code 1150). Choose Vista or XP for a program that must run
    there. A program that uses `XPMan` or `ModernMan` gets
    no UTF-8 (its manifest has none). A program in UTF-8 - this entry, or any that uses
    `ModernManUtf8` - is compiled by the UTF-8 compiler `dcc32u8.exe` (Installing, above): Delphi 7's `dcc32.exe` turns
    text into UTF-16 with the system code page, so a `resourcestring`, a `WideString` constant or
    variable given a literal, or a literal passed as a `PWideChar` would come out garbled when it
    has characters beyond ASCII (`'Café'` as `CafÃ©`). Without `dcc32u8.exe` in Delphi 7's `Bin`,
    D7 Studio compiles with `dcc32.exe` and warns about it when the code has such text.
  - *Windows Vista or later (system code page)*: the sources go to the compiler in the system code
    page, as Delphi 7 compiles them.
  - *Windows XP or later (system code page, program header 5.1)*: as Vista, and the modern program
    header (below) gets version 5.1, which Windows XP loads - it refuses 6.0 as "not a valid Win32
    application". What the modernized RTL/VCL imports exists on Windows XP, the modernized runtime
    packages included; what is newer it binds at run time, with Delphi 7's behaviour as the fallback.
- **Modern program header (DEP, ASLR)** (on by default): after linking, the program is marked as a
  Windows 6.0 program (Delphi 7's linker writes 4.0; 5.1 for Windows XP), DEP compatible,
  terminal-server aware, and ASLR when it has relocations. With DEP, code that runs from data memory
  ends with an access violation: SOAP's `THTTPRIO` does (its interface stubs lie in heap memory), so
  turn the option off for a program that uses it. `Languages` works under DEP with the modernized
  RTL only.

A program built with runtime packages needs the modernized `.bpl` files of this version at run
time: ship them next to its EXE.

## The IDE

[FEATURES.md](FEATURES.md), beside this file, compares it with Delphi 7's
IDE, area by area: what is new and what works better.

- **One main window**: the Object Inspector, Code Explorer, Object TreeView, Project Manager,
  Components, Messages, To-Do List and the debugger views dock in tabbed groups; a group can float.
- **Delphi 7's Code Explorer**: the unit's classes, routines, types, variables and uses as Delphi 7
  shows them - its categories, icons, order and bold incomplete items (Environment Options ▸
  Explorer), typing to search, Enter to jump, New and Rename that write the source; optionally
  synchronized with the editor both ways (*Synchronize with the editor*, off by default).
- **Form designer** with Borland's real design-time packages and property / component editors,
  visual form inheritance, frames, the Object Repository and component templates, the form
  positioner, and the Diagram tab. Design packages are installed through Component ▸ Install
  Packages.
- **Object Inspector** in Delphi 7's layout, with categories, value glyphs and Unicode property
  values.
- **Code editor** (Scintilla): navigation bar, code completion and code parameters, matching and
  typing aids, browse history, bookmarks, macros, code templates, a source formatter, and file
  encodings. Code insight works on Pascal sources. C/C++, C#, resource scripts, IDL, XML,
  HTML, INI-style files (`.ini`, `.dof`, `.dsk` ...), SQL, batch files and make files (`.bpg`)
  are highlighted in the theme's colours, can be folded and have Toggle Comment. Other files are
  plain text.
- **Names by kind**: in a Pascal unit, names are coloured by what code insight finds they are -
  types, routines, properties, fields, variables, local variables, parameters, constants and units
  - a moment after you stop typing or scrolling. A name it does not know keeps the identifier
  colour. Light and Dark colour the kinds; Classic, like Delphi 7, does not. Each kind can also be
  bold, italic or underlined (Tools ▸ Editor Options ▸ Color), as can the kinds of the completion
  list.
- **Error Insight** (Tools ▸ Editor Options ▸ Code Insight, on by default): a second after you stop
  typing, the errors of the unit shown are underlined with a wavy line, in Delphi 7's compiler's
  words - syntax errors, undeclared identifiers and members, routines and methods declared without
  an implementation, methods implemented without a declaration or with another heading. Hover over
  one for its message; they are marked beside the scroll bar, counted in the status bar (click the
  count to see the list) and listed in the *Error List* (View ▸ Error List, a tab beside Messages that
  comes to the front when the file gets errors, its title red while it has any; double-click
  to go to one). A name is reported only
  where every place it could come from is known: when a unit the file uses cannot be found with its
  source (one that comes as a DCU only), or a class's ancestor is unknown, its names are not
  checked. The compiler stays the judge: Error Insight finds the common mistakes as you type, not
  every error dcc32 would report.
- **History** (a tab after Code, Design and Diagram): the versions of every file, kept by D7 Studio
  in `%LOCALAPPDATA%\D7Studio\History` - at each save, the unsaved text every 5 minutes, the text a
  close without saving or a reload lets go, a change made by another program, the text before
  Format Project rewrites it. A timeline by day beside the chosen version's differences with the
  text now (inline or side by side, the changed words marked); *Restore Version*, *Restore Change*
  for one block, the routines each version changed, a search through the versions, labels. Tools ▸
  Editor Options ▸ Display ▸ *Keep file history* turns it off, *Versions kept* (50) sets how many a
  file keeps. It takes the place of Delphi 7's `.~pas` / `.~dfm` backup files.
- **Colour themes** (Tools ▸ Editor Options ▸ Color): Light, Dark and Classic built in, and themes
  of your own - every colour of the editor, its margins and highlights, the names by kind, the
  debugger's lines and the completion list, with a live sample; choosing an element shows where it
  is in the sample. Changing a built-in theme makes your own copy of it; themes can be duplicated,
  renamed, deleted, imported and exported (`*.d7theme`). Migrating from Delphi 7 takes its current
  colours.
- **Projects and project groups** compiled with Delphi 7's dcc32; Win64 builds through RAD
  Studio's dcc64 when one is installed. A project's resource scripts (`{$R 'x.res' 'x.rc'}`, *Add
  to Project* of a `.rc`) are compiled by Delphi 7's brcc32 when they or a file they name change.
  As in Delphi 7, packages opened with *File | Open* while a project is open stay beside it, any
  number of them, each in its own package editor; the Project Manager lists them after the project
  group, the one opened last is the active project, and a double click makes any project the
  active one (*Add Existing Project* puts a package into the group).
- **Integrated debugger**: breakpoints, watches, local variables, call stack, threads, modules,
  event log, evaluate/modify, CPU and FPU views.
- **Resources and type libraries**: a resource view (bitmaps, icons, cursors, string tables,
  version, manifest), Import Type Library, Import ActiveX Control and the Type Library view.
- **Experts**: Open Tools API experts (packages and DLLs), GExperts and CnWizards among them.
- **AI assistant** (View ▸ AI Assistant): a chat in a dockable window that reads, searches, edits
  and compiles the code and changes forms through the IDE. It asks you before every change. Its
  backends: Claude (Anthropic's API), OpenAI, OpenRouter, Ollama, LM Studio and any
  OpenAI-compatible endpoint, with your API key where the service needs one (Settings in its
  window).
- **Git** (View ▸ Git, View ▸ Git History): the changes of the active project's repository in a
  dockable view - stage, commit, discard, branches, fetch, pull, push, stashes -, the history,
  diffs and blame, and Git in the code editor's local menu (the editor's unsaved text included). It
  runs Git for Windows' `git.exe`.
- Both experts are design packages that Setup installs (`AiHarness.bpl`, `GitExpert.bpl` in
  Delphi 7's `Projects\Bpl`) and D7 Studio loads; Component ▸ Install Packages turns them off or
  removes them. They use only Delphi 7's Tools API, so Delphi 7's own IDE can load them too.
- **Delphi 7's keyboard defaults** and menus.
