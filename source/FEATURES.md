# D7 Studio compared with Delphi 7's IDE

D7 Studio takes the place of Delphi 7's own IDE for Delphi 7 projects. It compiles with Delphi 7's
compiler, loads Delphi 7's design packages and experts, and keeps what your hands know: Delphi 7's
menus in their order, its default keys and its seven key mappings, its option pages and dialogs,
the Code Explorer and the Project Manager. This file lists, area by area, what D7 Studio's IDE adds
and what it does better.

What Setup changes in Delphi 7's folder, and what your programs get from the modernized RTL/VCL,
is in [README.md](README.md), beside this file (in Delphi 7's `Bin`); the
modernized RTL/VCL in full is in [MODERNIZATION.md](MODERNIZATION.md).

## The look

- **The look of the running Windows.** Every control is drawn with Windows' visual styles, list
  and tree views look like Explorer's, and borders are one flat line. Delphi 7's IDE shows the
  classic, unthemed controls.
- **Flat menus and a flat tool bar** in the style of Visual Studio: white, with an icon column and
  the shortcuts at the right - also those of keys the editor handles itself, such as Ctrl+Space
  for *Code Completion*.
- **The caption shows where you work.** The docked group that has the keyboard shows its caption
  in Windows' title-bar colour (the accent colour when Windows shows it on title bars); the others
  are grey.
- **Hints** are white and flat, and appear at once.
- **A UI font of your choice.** D7 Studio uses Windows' UI font, Segoe UI 9.
  *Tools ▸ Environment Options ▸ Preferences ▸ User interface ▸ Font* (a name and a size) chooses another one
  (Tahoma 8 gives Delphi 7's proportions); it applies at the next start, and D7 Studio offers to
  restart at once.
- **Modern icons** - JetBrains' IntelliJ icons and drawings in their style - on every command and view, at 32 × 32 in *File ▸ New ▸
  Other*. Disabled images are faded, as Visual Studio fades them, not flat grey shapes.
- **No flicker**: views, tabs and lists never show a half-drawn state while they fill, resize or
  switch.
- **Lists** get a horizontal scroll bar as soon as a row is wider than the list, and roomier rows.

## The main window

- **One window.** The code editor and the form designer are pages of the main window, and every
  tool view docks in it: Object Inspector, Code Explorer, Object TreeView, Project Manager,
  Components, Messages, Search Results, To-Do List and the debugger views. In Delphi 7 the form,
  the code editor and the tool windows are windows of their own.
- **Docking areas** left of, right of and below the editor, and one across the whole bottom of the
  window. Views share an area in tabbed groups; a drop on the editor's edge makes a new column
  beside the area. While you drag, a translucent mark shows where the view will land; Esc cancels.
- **The dock's commands in every view's menu** (right-click its caption or its tab): *Dock Left*,
  *Dock Right*, *Dock Bottom*, *Dock Bottom (Full Width)*, *Floating*, *Tabs* (top, bottom, left or
  right), *Auto Hide* and *Close*.
- **Auto hide.** The pin on a caption collapses its group into tabs along the window's edge. Click
  a tab, or rest the pointer on it, and the group slides out; it slides back when you leave it. A
  failed compile slides Messages out, a debugger stop its view.
- **Floating groups.** Any group floats in a window of its own, which stays above the main window
  and has no task bar button. A double click on its caption docks it back where it was.
- **Tabs in any order.** Drag a group's tabs, or the file tabs, into the order you want.
- **File tabs** have a close box, a middle click closes them too, and the tab of a modified file
  ends in `*`. The project's desktop keeps their order, and Delphi 7 reopens the files in that order
  too. A button at the end of the row lists the open files; or the tabs go into as many rows as they need (*Tools ▸
  Editor Options ▸ Display ▸ Multi-line file tabs*).
- **Back where you left off.** D7 Studio opens the project that was open when it closed (or the
  files named on its command line), and no new Project1 is made. Its start-up screen shows what it
  is loading.
- **The window's place** is kept at every close and restored, on its monitor.
- **The Components view in place of the palette.** *View ▸ Components* lists the installed
  components of one palette page, or of all, with a filter box (`*` and `?` for a mask). Enter or a
  double click puts the chosen component on the form; drag it to drop it where you want it.
  *Tools ▸ Environment Options ▸ Components* chooses Delphi 7's tiles or icons beside the names,
  the order (by name, last used, most used or palette order) and a shortcut key for the view.
- **The status bar** also shows Error Insight's count of errors (click it for the list), the
  file's encoding and, when it is not 100 %, the zoom of what the page shows.
- **A tool bar on every page.** Above the code, the form, the diagram and a resource's editor, a bar
  holds what that view needs: the navigation boxes over Pascal code, the Diagram's buttons, a resource editor's
  commands - after the zoom bar, which comes first.
- **Zoom everywhere, one way.** The code editor, the form designer, the Diagram tab and the image,
  text and hex editors of resources zoom with the zoom bar - *Zoom Out*, *Zoom In*, *Reset Zoom*,
  and *Zoom to Fit* for the form, the diagram and images -, with *View ▸ Zoom* (Ctrl+Num +, Ctrl+Num -,
  Ctrl+Num /) and with the mouse wheel
  while you hold the zoom key: Ctrl by default, or Ctrl+Shift, or Alt, or none (*Tools ▸ Environment
  Options ▸ Preferences ▸ Zoom key*). The wheel never zooms while a mouse button is down.
- **Search results** have a view of their own beside Messages, with the found text in Unicode.
- **The Browser works without a compile.** *View ▸ Browser* reads the units as the editor has them,
  unsaved changes included; Delphi 7's needs a compiled project. It is brought up to date when you
  save a unit of the project, as well as after a compile. It docks like every view.
- **Resources in the IDE.** *View ▸ Resources* lists the active project's `.res`: bitmaps, icons,
  cursors, string tables, version information, the manifest. You can add new ones (icons and
  cursors in sizes up to 256 px) and import and export files. A resource opens as a page of its
  own, in an image editor with Visual Studio's tools and keys, a string table, a text editor or a
  hex editor; Save writes it into the `.res`, and a compile takes unsaved changes as they are. The
  image, text and hex editors zoom. Delphi 7 has only its separate Image Editor.

## Dialogs and options

- **Options in one dialog.** *Tools ▸ Environment Options*, *Editor Options*, *Debugger Options*
  and *Formatter Options* open one dialog with Delphi 7's pages in a tree, and OK applies them
  all; *Project ▸ Options* has the same form. The pages are larger, and their lists use the full
  height.
- **Dialogs open on the window they came from**, centred on it and kept inside one monitor's work
  area, also on monitors left of or above the primary one.
- **A clean dialog layout.** Dialogs have a white body and their command buttons in a gray band at
  the foot, below a thin line, all buttons of one size. *Tools ▸ Environment Options ▸ Preferences ▸
  User interface ▸ Dialogs* makes the body gray instead; the dialogs opened afterwards follow it.
- **Open and Save dialogs** take file names with characters the system code page lacks.
- **Boxes of file and folder names** - in Tool Properties, Run Parameters, Install Component, New
  Component, Import Type Library, the directories of Project and Environment Options - complete the
  name as you type and take a file or folder dragged onto them from Explorer.
- **The search path editor** (the *...* of a search path) has *Edit as text*, one folder per line,
  takes folders dragged onto it from Explorer, and makes the selected folder relative (to
  `$(DELPHI)` or the project's folder) or absolute.
- **Install Packages** has *Show in Folder*: Explorer opens with the package selected.
- **Tools ▸ Configure Tools** exports the tools to a file and imports them from one, adding those
  the list does not have.
- **Auto close on successful compile** (*Tools ▸ Environment Options ▸ Preferences*, under *Show
  compiler progress*) closes the Compiling dialog after a compile without errors.

## The code editor

- **Files in any encoding.** Each file keeps its encoding: UTF-8, UTF-16, the system code page or
  another code page - a Greek file on a Western Windows shows its own characters and is saved byte
  for byte. The status bar shows the encoding; *File ▸ Reopen with Encoding* reads the file in
  another one, *File ▸ Convert to Encoding* saves it in another one. Find and Find in Files work in
  every encoding. Delphi 7's editor knows the system code page only.
- **Colour themes** (*Tools ▸ Editor Options ▸ Color*): Light (the default), Dark, Classic (Delphi
  7's colours) and themes of your own, made from any of them and imported or exported as
  `*.d7theme` files. A theme colours the text, the gutter and margins, the highlights, the
  debugger's lines and the completion list, shown at once in a live sample. An element left at
  *Default* follows the theme, so a new background is one change.
- **Names coloured by kind**: types, routines, properties, fields, variables, local variables,
  parameters, constants and units each have a colour of their own in Light and Dark, and can be
  bold, italic or underlined. Classic colours them all as identifiers, as Delphi 7 does.
- **Flow control and your own identifiers stand out**: `Exit`, `Break`, `Continue`, `Halt`, `Abort`, `raise` and
  `goto` in a colour of their own, and the identifiers you list (*Editor Options ▸ Highlighting ▸ Custom identifiers*)
  in another - elements of the colour themes like the rest.
- **The navigation bar** over the code: a *Class* box and a *Methods/functions* box that follow the
  caret and jump to what you choose (*Editor Options ▸ Display ▸ Navigation bar*).
- **Code folding** as in RAD Studio: the unit's `interface`, `implementation`, `initialization` and
  `finalization` sections, each routine from its heading (its `var` section and nested routines
  inside), types, `uses` clauses, statement blocks, `{$REGION}`s, `{$IFDEF}` blocks and comments. A
  folded block ends in a `...` box; rest the pointer on it to see the hidden code in a tip (*Editor
  Options ▸ Display ▸ Fold preview*). *Edit ▸
  Folding* and RAD Studio's Shift+Ctrl+K keys fold all, the methods, the classes, the sections, the
  nested routines or the regions, and turn folding on or off. **Line numbers** and **change bars** (unsaved and saved
  changes) in the gutter.
- **Highlighting** (*Editor Options ▸ Highlighting*): the bracket at the caret and its partner (a
  bracket without one in red); the words of the block at the caret (`begin` ... `end`, `try` ...
  `finally` ... `end`); every place of the name at the caret - code insight tells same-named
  symbols apart -; every match of the last search; the current line; indentation guides; and
  rainbow brackets if you want them.
- **Markers on the scroll bar** for changed lines, search matches, the places of the name at the
  caret, breakpoints, bookmarks, the execution point and errors.
- **A minimap** beside the scroll bar: the file in miniature in its colours, the lines in view in a
  box, the caret's line, the selection, search matches and errors. A click jumps there, dragging the
  box scrolls, and the pointer over it shows the code around that line in a tip (*Editor Options ▸
  Display ▸ Scroll bars ▸ Minimap*: *Enabled + preview*, *Enabled* without the tip, or *Disabled*).
- **Typing aids** (*Editor Options ▸ Typing*): brackets and quotes close themselves; Enter after
  `begin`, `try`, `repeat` or `case` adds the missing `end`, `finally` ... `end` or `until`; the
  next line is indented after `then`, `do`, `else` and section words, and `end` or `until` goes
  back to its block's indentation.
- **Multiple carets**: *Select Next Occurrence* (Shift+Alt+.), *Select All Occurrences*
  (Shift+Alt+;), *Add Caret Above* / *Below* (Ctrl+Alt+Up / Down), and Ctrl+Alt+click.
- **Line and selection commands**: *Duplicate* (Shift+Ctrl+D), *Move Up* / *Move Down*
  (Shift+Ctrl+Alt+Up / Down) and *Join* (Shift+Ctrl+J) lines; *Upper Case*, *Lower Case*, *Toggle Case*, *Sort
  Lines* and *Surround With* `begin ... end`, `try ... finally`, `try ... except` (*Edit ▸ Line*); *Toggle Comment* (Ctrl+/) in every language that has comments; *Expand* / *Shrink
  Selection* (Shift+Alt+= / Shift+Alt+-) by the code's structure.
- **A button by the selection** opens a menu of what applies to it: cut, copy, comment, indent, duplicate, move,
  case, sort, surround, format (*Editor Options ▸ Display ▸ Selection button*).
- **Word wrap** (*Editor Options ▸ Display ▸ Word wrap*) and **zoom** (the zoom bar, *View ▸ Zoom*,
  the wheel with the zoom key): one zoom for every file, kept.
- **Back and Forward remember every jump**: also a switch to another file, and a line reached from
  Messages, Search Results, the To-Do List, the Code Explorer or *Go to Line Number*; going back
  reopens a file that was closed. Delphi 7 records only Ctrl+click and Find Declaration.
- **Other languages**: C/C++, C#, IDL, SQL, resource scripts, XML, HTML, INI-style files, batch
  files and make files are coloured in the theme's colours, and all but the last two can be folded.
- **A class diagram.** The *Diagram* tab of every unit, program and package draws its classes,
  interfaces and records as UML boxes with their fields, methods and properties, and lines to their
  ancestors and interfaces. Open and close the boxes, zoom (also to fit the whole diagram),
  double-click to go to the code. (Delphi 7's Diagram page shows a module's components instead.)
- **The history of every file.** The *History* tab (also *View ▸ History*) keeps the versions of each
  file: every save, your unsaved text every five minutes, the text you let go when you close a file
  without saving or reload it, a change another program made, and Format Project's rewrite. On the
  left they are listed by day, each with its time, the lines it added and removed and the routines it
  changed; on the right the version you choose is compared with the text as it is now - or with the
  version before it, or with another version you choose with Ctrl -, in the editor's colours, inline
  or side by side, the changed words marked and the unchanged lines folded away. *Restore Version*
  puts a version back (a unit together with its form), *Restore Change* only the change at the caret;
  Undo takes either back. Filter the versions by a routine (also *History of Routine* in the
  editor's menu) or by a text they contain, and label a version to keep it for good. The versions are
  kept in D7 Studio's own folder, not in your project's (*Editor Options ▸ Display ▸ Keep file
  history*, 50 versions per file). Delphi 7 keeps one backup (`Unit1.~pas`) beside the file.

## Code insight

- **Error Insight** (*Tools ▸ Editor Options ▸ Code Insight ▸ Error Insight*, on by default): a
  second after you stop typing, the errors of the unit shown get a wavy underline, in Delphi 7's
  compiler's words - syntax errors, undeclared identifiers and members, routines declared without
  an implementation, and headings that differ from their declaration. Point at one for its message.
  They are marked on the scroll bar, counted in the status bar and listed in the *Error List*
  (*View ▸ Error List*), where a double click goes to one. Error Insight reports only what it is
  sure of: the compiler stays the judge.
- **Completion while you type.** With *Code completion* on, the list also opens two characters
  into a name, after the *Delay*, and it changes nothing you type unless you press Enter or Tab.
  Delphi 7 opens it by itself only after a dot.
- **Tips that look like code.** The tip of a name shows its declaration coloured as code, with its
  unit and line; the parameter hint marks the current parameter on a highlighted box.
- **Value tips as trees.** While the program is stopped, the tip shows the value of the whole
  expression under the pointer, with records, arrays and objects to open in place. Delphi 7 shows
  one line.

## The formatter

- **Format Source** (*Edit ▸ Format Source*, Ctrl+D) formats the selected lines or the whole
  Pascal file, or a form's text, as one undo step. *Project ▸ Format Project Sources* formats the
  project's files, and an option formats each Pascal file when it is saved. Delphi 7 has no
  formatter.
- **RAD Studio's options and presets.** *Tools ▸ Formatter Options* has the options of RAD Studio's
  Delphi formatter under their names, with a live preview, built-in presets (RAD Studio, Borland
  Style Guide, JEDI Code Format, DelForExp ...) and presets of your own; it imports and exports RAD
  Studio's `Formatter.config`.
- **It never breaks your code**: when a result would not keep every token, nothing changes and a
  message names the line. Breakpoints and bookmarks stay on their lines.

## The form designer

- **Forms are designed in the main window**, each in the frame it will have at run time: the frame
  follows *BorderStyle* and *BorderIcons* (a dialog has a dialog frame, a tool window a small
  caption), and the controls show the look of the running Windows. A form without a border, a data
  module or a frame has no title bar, only a thin border line that marks its edges. Delphi 7 shows
  every form with a sizeable frame and classic controls.
- **Controls move and resize live** under the mouse, not as outlines; a box marks a resized control's
  new bounds while you drag; Esc puts them back.
- **Zoom the form** from 5 % to 400 % in steps of 5 %, or to fit the whole form in view, and work
  on it as at 100 %: select, move, size and drop components. The form's sizes and positions stay as
  they are. Each form has its own zoom.
- **The designer's commands above the form**: *Scale...*, *Tab Order...*, *Creation Order...*, *Flip
  Children*, *Hide Non-Visual Components* (the non-visual components' tiles off every form), *Lock Controls*, *Bring to Front*, *Send to Back*, *Align...*, *Size...*, *Align to Grid* and
  the ten alignments - edges, centers, center in window, space equally - on the bar at the top of the
  design view, each enabled when it applies to the selection. Delphi 7 has the
  alignments in a separate floating Alignment Palette and the others in its menus only.
- **Snap lines** (*Tools ▸ Environment Options ▸ Designer ▸ Snap lines*, on): an edge you drag
  snaps to the edges of the other controls, to the usual spacing beside them and to the margin of
  their container, and a line shows it.
- **Undo and Redo** of every designer change (Ctrl+Z, Shift+Ctrl+Z), up to 100 steps: drops,
  moves and sizes, Object Inspector edits, deletions, pastes, alignments - with the code the
  designer wrote for them. Delphi 7 has only *Undelete*.
- **The form positioner** (*Environment Options ▸ Designer ▸ Show form positioner*): a button at
  the lower right of the design area shows your monitors in miniature and where the form will
  open. Drag the form there to place it; a double click on a monitor centres it there.
- **Design windows follow their form.** The Action List editor, the Menu Designer and the other
  design windows of the packages hide while their form is not shown and come back with it.
- **Paste is all or nothing**: text that cannot be read changes nothing, and the message says why
  and on which line.
- **Any character in captions and strings.** They are saved as Delphi's `#nnnn` codes, so the
  `.dfm` stays ASCII and Delphi 7 reads it.

## The Object Inspector

- **Check boxes** before Boolean values: one click toggles the value. Typing Yes or No works too.
- **Pictures** of the *Align* and *Alignment* values, in the rows and in the drop-down lists.
- **Readable values**: *Constraints* shows its four numbers, *Font* its name and size in that font,
  and the list of *Font.Name* shows each name in its own font.
- **Unicode values.** A string property takes any character, such as a Greek caption on a Western
  Windows, and WideString properties (TNT controls, ADO's ConnectionString) are shown and edited
  in Unicode. Delphi 7 turns the characters its code page lacks into `?`.

## Code Explorer and To-Do List

- **Synchronize with the editor** (*Tools ▸ Environment Options ▸ Explorer*, off by default): a
  node you choose shows its code, and the caret selects the node of the declaration it is in.
- **To-Do items** are written in the file's own encoding, also in Unicode files. Changing several
  values of an item at once works (Delphi 7 can damage the comment), and *Table Properties* of
  *Copy As ▸ HTML Table* are remembered.

## Projects and compiling

- **Sources in UTF-8 or UTF-16 compile.** D7 Studio gives Delphi 7's compiler a copy in the system
  code page; Delphi 7 compiles code-page text only and stops at a byte order mark. A character the
  code page lacks in a string or in code is reported as a warning on its line in *Messages*, and so
  is an include file in another encoding.
- **Resource scripts** (`{$R 'x.res' 'x.rc'}`) are compiled by Delphi 7's brcc32 when the script
  or a file it names (an icon, a bitmap, a header) has changed, unsaved scripts as the editor shows
  them; brcc32's errors appear in *Messages* like the compiler's, and a double click opens the line.
- **A modern icon for new programs.** A new project gets an application window in the style of
  Windows 11 as its icon, in full colour and sharp from 16 to 64 pixels, so at every display scaling
  up to 250 %.
- **Sharp programs on every display scale.** The programs D7 Studio builds are per-monitor DPI
  aware by default (*Project ▸ Options ▸ Application ▸ DPI awareness*): their forms scale to the
  monitor they are on, where Windows would stretch a Delphi 7 program and blur its text.
- **A current manifest for every program.** Besides the visual styles, D7 Studio's manifest
  declares Windows Vista to 11, long paths and the rights the program asks for (*Project ▸ Options ▸
  Application ▸ Execution level*: as invoker, highest available, or require administrator).
- **Win64.** *Project ▸ Options ▸ Application ▸ Target platform* Win64 builds the project with the
  dcc64 of the newest RAD Studio installed (XE2 or later), into folders named `Win64`; Run starts
  it, without the debugger.
- **A hint about antivirus programs**: when one blocks or removes the program you have just built,
  the message says so and suggests excluding the output folder.

## The debugger

- **Local Variables** opens objects and records as a tree, and the debug views keep what you opened
  and selected from one stop to the next.
- **Copy from the CPU view**: its menu copies the selected lines, a number of lines from the selected one -
  decoding code and reading memory beyond what the pane shows -, or the whole pane, or opens them in an editor page.
- **The Watch List** opens a value with members, as Local Variables does; Delphi 7's cannot. A
  watch moved to another group keeps its group and its *Break When Changed* breakpoint.
- **A font for the debugger views** (*Tools ▸ Environment Options ▸ Preferences ▸ User interface ▸
  Fixed-size font*, also the font of the update notes):
  Windows' fixed-width font by default.

## Files and settings

- **Any character in the IDE.** D7 Studio runs with UTF-8 as its code page: captions in the
  designer, Object Inspector values, and file and folder names can hold any character, such as
  Greek on a Western Windows. Projects in such folders build, and messages that name such files
  open them. Delphi 7's IDE knows the characters of the system code page only.
- **Safe saving**: every save writes a temporary file first and then replaces the old file in one
  step, so a save that fails leaves the old file as it was.
- **Settings in one file** next to `D7Studio.exe` (`D7Studio.ini`), one per copy of D7 Studio.
  Several copies can run at once without undoing each other's changes. D7 Studio never writes
  Delphi 7's registry key, so Delphi 7's IDE keeps its own settings.
- **A crash log**: an unexpected error is written with its call stack to `error.log` next to the
  settings.
- **Updates from GitHub**: *Help ▸ Check for Updates...*, and once a day at start-up (*Tools ▸ Environment
  Options ▸ Preferences ▸ Check for updates at start-up*), look for a newer release. Its dialog
  shows what's new: the release notes of every version since yours; *Update* downloads the setup, checks its SHA-256, closes D7 Studio and
  starts the setup, which updates D7 Studio in place with its settings kept.

## Experts

Delphi 7's experts run in D7 Studio: design-time packages and DLL experts, GExperts and CnWizards
among them, and Delphi 1-3's experts and version control managers. What is new:

- **Experts' windows dock** like D7 Studio's own views - tabs, auto hide, floating groups -, and
  desktops keep them and open them again.
- **Unloading is safe.** When an expert package is unloaded or rebuilt, D7 Studio first drops the
  notifiers, key bindings and file systems the package registered, so nothing calls into code that
  is gone.
- **An expert's error in a notifier** goes to `error.log` instead of interrupting your work.
- **For expert authors**: D7 Studio sends the registered message `D7Studio.EditorOptionsChanged` to
  its windows when options change, so an expert can take a new editor font at once, and
  `D7Studio.ExpertViewStatus` shows an expert's text in its view's status line.
- **Two experts of D7 Studio's own**, packages that Setup installs and D7 Studio loads (Component ▸
  Install Packages turns them off): the AI assistant (View ▸ AI Assistant), a chat that reads,
  edits and compiles the code and changes forms, asking before every change; and Git (View ▸ Git,
  View ▸ Git History), the changes, history, diffs and blame of the project's repository. Both use
  only Delphi 7's Tools API, so they load in Delphi 7's IDE too.
