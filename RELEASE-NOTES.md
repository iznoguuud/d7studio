# D7 Studio release notes

What changed in each version of D7 Studio: the IDE and its experts, the modernized RTL/VCL that
Setup patches into Delphi 7, and Setup itself. The newest version comes first. The version is the
one *Help ▸ About* shows and the setup's file name carries.

Each version lists its changes under *Added*, *Changed*, *Fixed* and *Removed*; every item begins
with the part it concerns. What D7 Studio's IDE has that Delphi 7's does not is in
[FEATURES.md](source/FEATURES.md), the modernized RTL/VCL in [MODERNIZATION.md](source/MODERNIZATION.md), and
installing in [README.md](source/README.md).

## [Unreleased]

## [1.0.6.1] - 2026-11-28

### Added

- **IDE**: a *File Explorer* view (*View ▸ File Explorer*, a tab beside the Project Manager): the files and folders
  of the active project's folder and of folders you pin, with a filter box and *Show* switches for Delphi's files
  only, the build output and hidden files. The project group's files are in bold, open files with unsaved changes
  carry the file tabs' green dot, and files made, renamed or deleted on the disk show at once. A double click opens a
  file - a project as a project, a program, image or archive with its program in Windows. Its menu adds a unit or
  resource script to the active project, makes files and folders, renames (a unit through *Rename Unit*), deletes to
  the Recycle Bin, copies the path, shows the file in Explorer, opens a command prompt in the folder and searches it
  with *Find in Files*; *Locate Active File* and *Follow the Editor* choose the file the editor shows. A file dragged
  out of it goes where one from Explorer would.
- **IDE**: files dropped on the Project Manager go into the active project (units and resource scripts; other files
  open).
- **IDE**: a *Preview* tab on Markdown files (`.md`, `.markdown`) beside *Code*: the file rendered as it is in the
  editor, unsaved changes included - headings, emphasis, lists and task lists, quotes, tables, rules, pictures beside
  the file, and code blocks coloured as the code editor colours them. A link to a heading scrolls there, one to another
  Markdown file opens its preview, one to another file opens it in the IDE, a web address opens in the browser. Text
  can be selected and copied (*Edit ▸ Copy*, *Select All*), the zoom bar and Ctrl + wheel zoom it, F12 switches
  between the code and the preview. Its menu opens or copies the link under the pointer and *Show Code* goes to the
  line of the Markdown it shows.
- **Code editor**: Markdown files are highlighted - headings, emphasis, code, links and the marks of lists and quotes.

### Changed

- **IDE**: *Help ▸ Check for Updates* shows a release's notes with their links as their text, a numbered list's items one a
  line and a table's cells a tab apart.

### Removed

- **IDE**: *View ▸ Diagram* and *View ▸ History*: the *Diagram* and *History* tabs under a file's page show them.

## [1.0.6.0] - 2026-11-28

### Added

- **IDE**: a filter box above the list of *View ▸ Units*, *View ▸ Forms*, *Remove From Project* and the other dialogs
  that list names to choose from: only the names that hold the typed text (or match a mask with `*` and `?`) remain,
  those that start with it first; the arrow keys move in the list while typing.
- **IDE**: code metrics, as in RAD Studio: *Project ▸ Metrics* measures every routine, class and unit of the
  project - size, cyclomatic complexity, nesting, inheritance, coupling and cohesion, Halstead's measures and a
  maintainability index - and the new *Metrics* view shows them as a tree with a column per metric, the values
  outside their limits in colour, sortable by any column, exported as HTML or CSV. Their limits and aggregations
  are set in *Environment Options ▸ Metrics*.

### Changed

- **IDE**: dragging a view shows dock guides, as in Visual Studio: at the window's edges and in the middle of the
  group, floating window or editor under the pointer. A view docks only when dropped on a guide; dropped anywhere
  else - over the main window too - it floats, and a floating window can be moved over the IDE without docking.
- **IDE**: the Components view has no filter box any more: type in its list to filter it (Backspace takes a letter
  back, Esc clears the filter). A status line below the list shows the filter and how many components it leaves.
  The components you have added from it before are in bold in the current look too, not only in the classic one.
- **Code editor**: the line numbers between line 1 and the caret's line show on every 5th line instead of every 10th
  (*Editor Options ▸ Display ▸ Line numbers ▸ Every 5th line*).

## [1.0.5.1] - 2026-11-28

### Added

- **Code editor**: a macro recorder. *Edit ▸ Macros* and a *Macros* drop-down on the code view's tool bar record a
  keystroke macro (Shift+Ctrl+R; the command becomes *Stop Recording Macro* meanwhile), play it (Shift+Ctrl+P) and
  play it repeatedly - a number of times, or until the end of the file -, all of it one undo step. Every recording is
  kept in the new *Macro Library* view (*View ▸ Macro Library*) and from one start to the next: choose a macro there
  to make it the one Shift+Ctrl+P plays; rename, delete and reorder macros, and export them to or import them from
  `.d7macros` files (also by dropping such files on the list).

### Changed

- **Code editor**: the line numbers show the number of line 1, of every 10th line and of the caret's line, and a dot
  on the other lines; *Editor Options ▸ Display ▸ Line numbers* is now a drop-down - *Every 10th line* (the default),
  *Every line* or *Hidden* - in the place of the check box.

## [1.0.5.0] - 2026-11-27

### Added

- **Code editor**: refactorings, in *Edit ▸ Refactor*, the *Refactor* button on the code editor's bar and under
  *Refactoring* in the code editor's menu: *Rename*
  (F2) a variable, routine, method, field, property, type or parameter everywhere the project uses it - forms
  included: a component, an event handler or a form's class is renamed in the form files too; *Declare Variable*
  (Shift+Ctrl+V) and *Declare Field* for a name not declared yet, with its type guessed; *Find Unit* (Shift+Ctrl+A)
  adds the unit that declares a name to the uses clause; *Extract Method* (Shift+Ctrl+M) makes the selected
  statements a method or routine of their own, with the parameters they need; *Introduce Variable* and *Inline
  Variable*; *Change Parameters* (Shift+Ctrl+X) adds, removes, reorders and edits a routine's parameters and changes
  every call; *Extract Resource String* (Shift+Ctrl+L); *Extract Constant* names a number, a string or a constant
  expression; *Convert to Format* turns a string concatenation into a call of `Format`; *Implement Methods* adds the
  methods of a class's interfaces and overrides of its ancestors' virtual methods; *Encapsulate Field* puts a field
  behind a property; *Complete Case* adds a branch for every value of an enumeration a case statement lacks; *Remove
  With* names what a with statement gave through its expression; *Clean Uses* removes the units a unit does not need
  and moves those only its implementation needs; *Safe Delete* deletes a declaration nothing uses; *Const Parameters*
  makes the parameters a routine never changes `const`; *Rename Unit* renames a unit, its file and its form's file;
  *Move to Unit* moves a type, routine, constant or variable - with the declarations only it used - into another
  unit and updates the uses clauses; *Pull Members Up* and *Push Members Down* move members of a class into its
  ancestor or its descendants. Each shows its changes first in the new *Refactorings* view - every file and line,
  and the file before and after compared as in the *History* tab - and makes them when you click *Apply*; an open
  file's changes are undone in one step.
- **Code editor**: *Sync Edit* (*Edit ▸ Refactor*, the selection button): the names that occur more than once in the
  selected text are linked, and typing over one changes them all; Tab goes to the next name, Esc ends it.
- **Code editor**: the minimap can show the entire file, squeezed to its height, instead of the strip that scrolls
  with the code in view (still the default): *Editor Options ▸ Display ▸ Scroll bars ▸ Layout*. *Large minimap*
  beside it draws the minimap twice as large and wide, its characters in the shapes of the editor's font, for big
  screens. A drop-down button at the right end of the
  code editor's bar has all four switches: show or hide the minimap, its preview, the entire file and the large size.
- **IDE**: a hidden view that has slid out from the window's edge can be resized: drag its inner edge, marked by a
  thin line. When you pin it again, it docks at that size.
- **IDE**: *Help ▸ Create Bug Report...* writes `bugreport.txt` and opens it, ready to attach to an issue on GitHub:
  the errors in `error.log`, grouped, each with its call stack (procedures and lines from D7 Studio's map, and the
  source lines around them when the sources are at hand), your Windows, monitors and code page, Delphi 7 and its
  patch, and the design packages and experts in use. **Setup** installs `bugreport.exe`, which does the same from the
  command line (`bugreport -?`).

### Changed

- **IDE**: a file tab shows its close box only while the pointer is on the tab, as a grey square with a white cross
  like the close box of the docked views; it turns red under the pointer. In its place a modified file's tab shows a
  green dot, the others a light grey one; the title no longer ends in `*`.
- **IDE**: the line that marks the chosen tab - of the file tabs, the docked views, *Code* / *Design* and the
  Object Inspector - is 1 px thick instead of 2.
- **IDE**: the close box and the pin on a docked view's caption are 1 px smaller, with their cross and pin exactly in
  the middle, and the caption is 1 px taller so that they sit in its middle. The close box shows only its cross, in
  the caption's text colour, and turns red under the pointer; the pin is smaller.
- **Code editor**: a 1 px line separates the scroll bars from the code and the minimap - along the vertical bar's
  left edge and the horizontal bar's top -, and the minimap from the code.
- **Code editor**: a file whose text is back to what was last saved - by undo or by typing or deleting it back - no
  longer counts as modified: its tab loses the modified dot, and closing it does not ask to save.
- **IDE**: when *Help ▸ Check for Updates* finds nothing newer, it says whether you have the latest version or a
  build newer than the latest release. The command has an icon in the Help menu now, and a line separates *About*
  from it.

### Fixed

- **Form designer**: closing a form while one of its editor windows was open (the action list, collection or menu
  editor ...) could end in an access violation.
- **IDE**: in the trees with check boxes - the Watch List and *Migrate from Delphi 7* - the frame of the chosen item
  is whole: the check box's cell hid its left edge.
- **Code editor**: with *Cursor beyond EOF* on, the minimap's box of the lines in view no longer shrinks or
  disappears when the code is scrolled past its last line.
- **Code editor**: the tip of the code a folded line hides has the editor theme's background, so its text stays
  readable in a dark theme.

## [1.0.4.1] - 2026-11-27

### Added

- **IDE**: views dock inside the editor area too, under the file tabs, beside the code editor or the designer: drop
  a view over the editor and it docks at the side of the page it is nearest to - left, top, right or bottom -, or
  choose *Dock in Editor Area* in the view's menu. These areas have tabbed groups, splitters and auto hide like the
  others, and desktops keep them.
- **Form designer**: snap lines by text: a control you move snaps its caption's or text's baseline onto another
  control's - a label beside an edit, a combo box, a check box or a button - and the start of its text onto where
  another control's text begins, shown by a dashed line (*Environment Options ▸ Designer ▸ Snap lines ▸ Snap to
  captions and text*, on).

### Changed

- **IDE**: a view dropped over the editor docks inside the editor area instead of floating: to float it, drop it
  outside the main window or choose *Floating* in its menu.
- **IDE**: the *Window* menu is now *Tabs*: *Next Tab* (Ctrl+Tab) and *Previous Tab* (Ctrl+Shift+Tab) go through
  the file tabs in their order, then come the open files, then the windows outside the main window - floating
  views and the components' design windows -, one of which comes to the front when you choose it.

## [1.0.4.0] - 2026-11-27

### Added

- **Code editor**: flow-control words - `Exit`, `Break`, `Continue`, `Halt`, `Abort`, `raise` and `goto` - stand
  out in a colour of their own (red and bold in Light), and identifiers you list in *Editor Options ▸
  Highlighting ▸ Custom identifiers* in another (purple in Light). Both are elements of the colour themes (*Flow
  control*, *Custom identifier*); themes made earlier get Light's or Dark's colours for them.
- **Code editor**: *Edit ▸ Line* has *Upper Case*, *Lower Case* and *Toggle Case* (the selection, else the word at
  the caret), *Sort Lines* (again: in reverse order) and *Surround With* ▸ *begin ... end*, *try ... finally*, *try
  ... except*.
- **Code editor**: a small button after the selected text opens a menu of what applies to a selection: cut and copy,
  comment, indent, duplicate and move the lines, change their case, sort them, surround them, format them (*Editor
  Options ▸ Display ▸ Selection button*, on).
- **IDE**: the file tabs can go into several rows instead of one row with a list button (*Editor Options ▸ Display ▸
  Multi-line file tabs*).
- **Debugger**: the CPU view has a menu: *Copy* (Ctrl+C) the selected lines - several can be selected now -,
  *Copy Lines...* a number of lines from the selected one (also code and memory beyond what the pane shows), *Copy
  All*, *Open in Editor*, and *Go to Address...* (Ctrl+G).
- **Form designer**: *Hide Non-Visual Components* on the designer's tool bar and in the *Edit* menu hides or shows
  the non-visual components' tiles on every form; it is Delphi 7's *Environment Options ▸ Designer ▸ Show
  non-visual components* the other way round, which now works.
- **IDE**: boxes that take a file or folder name - in Tool Properties, Run Parameters, Install Component, New
  Component, Import Type Library and the directories of Project and Environment Options - complete the name as you
  type and take a file or folder dropped on them from Explorer.
- **IDE**: the search path editor (the *...* of a search path) has *Edit as text*, takes folders dropped on it from
  Explorer, and has *Make Relative* (to `$(DELPHI)` or the project's folder) and *Make Absolute* for the selected
  folder.
- **IDE**: *Component ▸ Install Packages* has *Show in Folder*, which opens Explorer with the package selected.
- **IDE**: *Tools ▸ Configure Tools* has *Export...* and *Import...*: the tools saved to a file, and the tools of
  such a file added to the list - those it has already left out.

### Fixed

- **IDE**: the drop-down arrows of *Back* and *Forward*, before the file tabs, open the list of places again; they
  opened nothing.
- **IDE**: a file tab scrolled under the file tabs' scroll arrows no longer shows around them.
- **Code editor**: its menu no longer ends in an empty *Git* submenu, before the Git expert's own.
- **IDE**: with GExperts' dialog enhancements turned on, *Tools ▸ Configure Tools ▸ Add / Edit* no longer raises an
  access violation.

## [1.0.3.4] - 2026-11-27

### Added

- **Code editor**: a minimap between the code and the vertical scroll bar shows the file in miniature in its
  colours, with the lines in view in a box, the caret's line, the selection, search matches and errors. Click to
  jump there, drag the box to scroll; the pointer over it shows the code around that line in a tip. *Editor
  Options ▸ Display ▸ Scroll bars ▸ Minimap* chooses *Enabled + preview* (the default), *Enabled* (no tip) or
  *Disabled*.
- **Code editor**: Pascal code folds as in RAD Studio: the unit's `interface`, `implementation`,
  `initialization` and `finalization` sections, each routine from its heading (its `var` section and nested
  routines inside), and a `uses` clause over several lines - besides types, statement blocks, `{$REGION}`s,
  `{$IFDEF}` blocks and comments as before. A folded line ends in a box with `...`; the pointer resting on the
  box shows the code it hides in a tip, in the editor's colours (*Editor Options ▸ Display ▸ Fold preview*
  turns it off). RAD Studio's other folding keys come with it: Shift+Ctrl+K C folds the classes, G the
  sections, N the unit, P the nested routines, R the regions, and O turns code folding on or off; *Edit ▸
  Folding* and the editor's menu have them too, *Code Folding* checked while it is on.

### Changed

- **Code editor**: *Fold Methods* (Shift+Ctrl+K M) folds each routine from its heading, and *Fold All*
  (Shift+Ctrl+K F) folds every level, so a block unfolded shows the blocks inside it folded.

### Fixed

- **Code editor**: turning code folding off shows the lines that were folded; they stayed hidden before.

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

[Unreleased]: https://github.com/iznoguuud/d7studio/compare/v1.0.6.1...HEAD
[1.0.6.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.6.0...v1.0.6.1
[1.0.6.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.5.1...v1.0.6.0
[1.0.5.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.5.0...v1.0.5.1
[1.0.5.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.4.1...v1.0.5.0
[1.0.4.1]: https://github.com/iznoguuud/d7studio/compare/v1.0.4.0...v1.0.4.1
[1.0.4.0]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.4...v1.0.4.0
[1.0.3.4]: https://github.com/iznoguuud/d7studio/compare/v1.0.3.3...v1.0.3.4
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
