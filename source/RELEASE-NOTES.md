# D7 Studio release notes

What changed in each version of D7 Studio: the IDE and its experts, the modernized RTL/VCL that
Setup patches into Delphi 7, and Setup itself. The newest version comes first. The version is the
one *Help ▸ About* shows and the setup's file name carries.

Each version lists its changes under *Added*, *Changed*, *Fixed* and *Removed*; every item begins
with the part it concerns. What D7 Studio's IDE has that Delphi 7's does not is in
[FEATURES.md](FEATURES.md), the modernized RTL/VCL in [MODERNIZATION.md](MODERNIZATION.md), and
installing in [README.md](README.md).

## [Unreleased]

## [1.0.3.3] - 2026-11-27

### Changed

- **Code editor**: code folding and the modified line indicators (the change bars) are on by default
  (*Editor Options ▸ Display ▸ Margin and gutter*). Settings that already turn them off keep them off.
- **Form designer**: a tool bar at the top of the design view holds the designer's commands: *Scale...*,
  *Tab Order...*, *Creation Order...*, *Flip Children* (its arrow offers *All* and *Selected*), *Lock
  Controls*, *Bring to Front*, *Send to Back*, *Align...*, *Size...*, *Align to Grid* and the ten
  alignments, each enabled when it applies to the selection.
- **Form designer**: *Align to Grid*, *Flip Children ▸ All* and *Selected* have icons, and *Align...*
  and *Scale...* new ones, in the menus too.
- **IDE**: tool bar separators are drawn in the lighter grey of the menus' separators.

### Fixed

- **Form designer**: *Align to Grid*, *Bring to Front*, *Send to Back* and *Flip Children ▸ Selected* are
  disabled while no control is selected (they never act on the form itself), and *Flip Children ▸ All*
  while the form has no control.

### Removed

- **IDE**: the floating Alignment Palette, with *View ▸ Alignment Palette* and its tool bar button; its
  buttons are on the design view's bar. *Edit ▸ Align...* stays.

## [1.0.3.2] - 2026-11-27

### Added

- **Setup**: installs two demos into Delphi 7's `Demos` folder: `ModernDemo`, a tour of the
  modernized RTL/VCL - per-monitor DPI, Unicode, the current dialogs and look, the Windows API -, and
  `OtaDemo`, the Open Tools API demo. Uninstalling removes them.
- **Demos**: ModernDemo, in the style of Windows 11's Settings: a sidebar of five areas, each a page of
  cards, Windows' stock icons drawn at each size, a layout that follows the window. The OTA demo, which
  exercises the Open Tools API in D7 Studio and in Delphi 7's IDE - Delphi 7's experts in a package
  and in a DLL, Delphi 1-3's expert API and a version control manager -, is part of the demos too.
- **RTL/VCL**: an image list can hold its images drawn at more than one size - 20, 24 and 32 pixels
  for 16-pixel images - and show the ones drawn for the display scale instead of enlarging the
  16-pixel images: `AddImageListResolution`, `LoadImageListResolutions` (from resources named
  `NAME_20`, `NAME_24` ...) and `ClearImageListResolutions` in `ImgList`. At a scale without its own
  size the list makes its images from the next larger size. Forms are unchanged: the images come
  from code.
- **RTL/VCL**: `ShellAPI` declares `SHGetStockIconInfo`, Windows' stock icons with their `SIID_`
  numbers, and `SHDefExtractIcon`, which gives an icon at any size.

### Fixed

- **IDE**: in a package's *Project ▸ Options ▸ Directories/Conditionals*, Tab now goes from top to
  bottom; it skipped the BPL output directory, which is the first row for a package.
- **RTL/VCL**: inserting or moving an image in an image list that follows the display scale no
  longer makes its other images again from their scaled copies, which softened them a little and
  dropped their alpha.

## [1.0.3.1] - 2026-11-26

### Changed

- **IDE**: *Tools ▸ Environment Options ▸ Preferences ▸ User interface* is wider: its font boxes
  show long font names whole, and *Dialogs* its whole entry. The font and *Dialogs* boxes open a
  list as wide as their longest entry.

## [1.0.3.0] - 2026-11-26

### Added

- **IDE**: *Project ▸ Options ▸ Application ▸ DPI awareness* chooses what a program's manifest says
  about the display scale: unaware, system aware, per monitor, or per monitor V2.
- **IDE**: *Project ▸ Options ▸ Application ▸ Execution level* chooses the rights a program asks
  for when it starts: as invoker (the default), highest available, or require administrator - for
  an installer or an updater that must run as administrator.

### Changed

- **IDE**: *File ▸ New ▸ Console Application* links the project's resource file (`{$R *.res}`), so a
  console program gets its icon and D7 Studio's manifest like any other program.

### Fixed

- **IDE**: programs built by D7 Studio are per-monitor V2 DPI aware by default, so their text stays
  sharp on a monitor scaled above 100 %. Before, their manifest had no DPI awareness and Windows
  stretched their windows there, blurring them. The next compile of a project updates its manifest.
- **IDE**: the manifest D7 Studio gives a program now also declares Windows Vista to 11
  compatibility, `asInvoker` and long paths, as `ModernMan`'s does. Windows no longer reports
  version 6.2 to such programs, no longer redirects their writes into Program Files and HKLM to
  the VirtualStore, and no longer asks for elevation because of a program's name.
- **IDE**: when a program uses `ModernMan`, `ModernManUtf8` or `XPMan`, or has a manifest of its
  own, the warning in *Messages* names only what the project's options ask for and that manifest
  does not declare. Before, it named the UTF-8 code page even when the manifest declared it.
- **IDE**: a program whose project source does not link its resource file (`{$R *.res}`) gets no
  manifest from D7 Studio, and *Messages* now says so at every build, with what the options ask for
  that it therefore does not get and how to give it a manifest. Before, nothing was said.
- **IDE**: a program's sources are compiled in the code page the program runs in, which its
  manifest decides: in the system code page when it has no manifest, or one of its own without
  UTF-8. Before, the default *Target Windows* compiled them for UTF-8 anyway, and their text beyond
  ASCII showed garbled.
- **IDE**: a program that links a manifest of its own in another resource file no longer also gets
  D7 Studio's, which Windows used in its place.
- **RTL/VCL**: the manifests of `ModernMan` and `ModernManUtf8` are language-neutral. A program
  that links another manifest as well - one D7 Studio wrote into the project's `.res`, compiled in
  Delphi 7's IDE - now gets the compiler's "Duplicate resource(s)" message, where Windows silently
  used the other manifest.
- **Code editor**: Pascal code no longer turns all into the reserved words' colour from a line
  ending in a reserved word (`finally`, `begin`, `try` ...) to the end of the file. It could happen
  while scrolling after an edit far above, such as the empty event handlers that saving removes.

## [1.0.2.2] - 2026-11-26

### Fixed

- **RTL/VCL**: pressing Alt no longer erases buttons, check boxes and radio buttons, leaving only
  the underlines of their access keys - in D7 Studio's dialogs and in programs built with the
  modernized VCL. It was a bug of Delphi 7's VCL with the visual styles.

## [1.0.2.1] - 2026-11-26

### Changed

- **IDE**: the update dialog shows the release notes of every version since the one you have, newest
  first, not only those of the latest release, in the fixed-size font.
- **IDE**: the font of the debugger's views is now the *Fixed-size font* of *Tools ▸ Environment
  Options ▸ Preferences ▸ User interface*, next to the UI font; it is no longer on *Debugger Options ▸
  General*. A font chosen there before is kept. The UI font's name and size share one row.

## [1.0.2.0] - 2026-11-26

### Added

- **IDE**: *Help ▸ Check for Updates...* looks for a newer release of D7 Studio on GitHub, and D7
  Studio also looks once a day when it starts (*Tools ▸ Environment Options ▸ Preferences ▸ Check
  for updates at start-up*, on by default). When there is one, a dialog shows its release notes;
  *Update* downloads its setup, checks it against the release's SHA-256, closes D7 Studio - asking
  about unsaved files as usual - and starts the setup, which updates D7 Studio in place and keeps
  its settings.

## [1.0.1.1] - 2026-11-26

### Fixed

- **IDE**: a click on another tab of the dock group you are working in no longer makes the group's
  title bar flash grey.

## [1.0.1.0] - 2026-11-26

### Changed

- **Code editor**: on the Color page, the names by kind (Type, Routine, Property, Field, Variable,
  Local variable, Parameter, Constant, Unit) and the completion list's kinds can now be bold,
  italic or underlined, and the editor keeps those styles while you type.

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

[Unreleased]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.3...HEAD
[1.0.3.3]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.2...v1.0.3.3
[1.0.3.2]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.1...v1.0.3.2
[1.0.3.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.0...v1.0.3.1
[1.0.3.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.2.2...v1.0.3.0
[1.0.2.2]: https://github.com/iznoguuud/d7studio/compare/v1.0.2.1...v1.0.2.2
[1.0.2.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.2.0...v1.0.2.1
[1.0.2.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.1.1...v1.0.2.0
[1.0.1.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.1.0...v1.0.1.1
[1.0.1.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.0.0...v1.0.1.0
[1.0.0.0]: https://github.com/iznoguuud/d7studio/releases/tag/v1.0.0.0
