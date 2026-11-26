# D7 Studio release notes

What changed in each version of D7 Studio: the IDE and its experts, the modernized RTL/VCL that
Setup patches into Delphi 7, and Setup itself. The newest version comes first. The version is the
one *Help ▸ About* shows and the setup's file name carries.

Each version lists its changes under *Added*, *Changed*, *Fixed* and *Removed*; every item begins
with the part it concerns. What D7 Studio's IDE has that Delphi 7's does not is in
[FEATURES.md](FEATURES.md), the modernized RTL/VCL in [MODERNIZATION.md](MODERNIZATION.md), and
installing in [README.md](README.md).

## [Unreleased]

## [1.0.0.0] - 2026-11-25

The first release.

### Added

- **IDE**: an IDE for Delphi 7 projects in one main window. The code editor and the form designer
  are its pages, and every tool view docks in tabbed groups, with auto hide, floating groups and
  desktops. It keeps Delphi 7's menus, default keys and key mappings, option pages and dialogs; it
  compiles with Delphi 7's compiler and loads Delphi 7's design packages and experts, Delphi 1-3's
  experts and version control managers included.
- **IDE**: the look of the running Windows - visual styles, flat menus and tool bars, modern icons,
  light and dark themes - and UTF-8 as its code page, so captions, property values and file names
  can hold any character.
- **Code editor**: files in any encoding (UTF-8, UTF-16 or any code page), colour themes, names
  coloured by kind, code folding, a navigation bar, multiple carets, highlighting of brackets,
  blocks and names, markers on the scroll bar, typing aids and zoom. Every unit has a class
  diagram, and every file a history of its versions, compared with the current text.
- **Code insight**: Error Insight in Delphi 7's compiler's words, completion while you type, tips
  coloured as code, and value tips as trees while the program is stopped.
- **Formatter**: *Format Source* and *Format Project Sources* with RAD Studio's formatter options
  and presets; a result that would not keep every token changes nothing.
- **Form designer**: forms designed in the main window in the frame they have at run time, with
  live moves and sizes, zoom, snap lines, undo and redo, and the form positioner. Captions and
  strings take any character.
- **Object Inspector**: check boxes for Boolean values, pictures of the *Align* and *Alignment*
  values, and Unicode string and WideString values.
- **Projects**: sources in UTF-8 or UTF-16 compile; resource scripts are compiled when they change;
  *View ▸ Resources* edits the project's `.res`. Built programs get a manifest for the visual
  styles, a modern program header and, by default, UTF-8 as their code page (*Project ▸ Options ▸
  Application ▸ Target Windows*); new projects get a modern icon; a Win64 target builds with the
  newest RAD Studio's compiler.
- **Debugger**: Local Variables and the Watch List open objects and records as trees, and the debug
  views keep what you opened from one stop to the next.
- **Experts**: experts' windows dock like D7 Studio's own views, and unloading an expert package is
  safe. Two experts of D7 Studio's own: the AI assistant (*View ▸ AI Assistant*), a chat that
  reads, edits and compiles the code and changes forms, asking before every change; and Git
  (*View ▸ Git*, *View ▸ Git History*): the changes, history, diffs and blame of the project's
  repository.
- **migrate**: carries an existing Delphi 7 configuration - options, packages, experts, tools and
  environment variables - into D7 Studio's settings, from Setup's last page or the *Tools* menu.
- **RTL/VCL**: Delphi 7 Update 1's RTL and VCL, modernized and binary compatible: existing DCUs and
  packages still link and load. UTF-8 as a program's code page (`ModernManUtf8`); per-monitor DPI
  awareness V2 (`ModernMan`); the Common Item Dialog, task dialogs, the modern folder picker and
  Explorer's list and tree views; placement on every monitor; the Windows API up to Windows 11;
  FastMM4 as the memory manager; fixes of Delphi 7 bugs.
- **Setup**: installs into an installed Delphi 7 with Update 1 and patches its RTL/VCL in place
  from differences only, after checking every file it patches; it backs up what it replaces, and
  uninstalling gives Delphi 7 its own files back. A newer setup updates D7 Studio in place and keeps
  its settings. It also installs Microsoft's WinHelp viewer, which shows Delphi 7's help on
  Windows 10 and 11.

[Unreleased]: https://github.com/iznoguuud/d7studio/compare/v1.0.0.0...HEAD
[1.0.0.0]: https://github.com/iznoguuud/d7studio/releases/tag/v1.0.0.0
