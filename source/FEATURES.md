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
  for _Code Completion_.
- **The caption shows where you work.** The docked group that has the keyboard shows its caption
  in Windows' title-bar colour (the accent colour when Windows shows it on title bars); the others
  are grey.
- **Hints** are white and flat, and appear at once.
- **A UI font of your choice.** D7 Studio uses Windows' UI font, Segoe UI 9.
  _Tools ▸ Environment Options ▸ Preferences ▸ User interface ▸ Font_ (a name and a size) chooses another one
  (Tahoma 8 gives Delphi 7's proportions); it applies at the next start, and D7 Studio offers to
  restart at once.
- **Modern icons** - JetBrains' IntelliJ icons and drawings in their style - on every command and view, at 32 × 32 in _File ▸ New ▸
  Other_. Disabled images are faded, as Visual Studio fades them, not flat grey shapes.
- **No flicker**: views, tabs and lists never show a half-drawn state while they fill, resize or
  switch.
- **Lists** get a horizontal scroll bar as soon as a row is wider than the list, and roomier rows.

## The main window

- **One window.** The code editor and the form designer are pages of the main window, and every
  tool view docks in it: Object Inspector, Code Explorer, Object TreeView, Project Manager, File
  Explorer, Components, Messages, Search Results, To-Do List and the debugger views. In Delphi 7 the form,
  the code editor and the tool windows are windows of their own.
- **Docking areas** left of, right of and below the editor, and one across the whole bottom of the
  window. Views share an area in tabbed groups, or stand side by side in new columns.
- **Dock guides.** While you drag a view, guides like Visual Studio's show where it can dock: at
  the window's left, right and bottom edges, and in the middle of the group, floating window or
  editor under the pointer - as a tab, before or after a group, or beside the editor. Drop it on a
  guide to dock it there, with a translucent mark showing where it will land; drop it anywhere else
  and it floats. Esc cancels.
- **Docking inside the editor area.** The guides over the editor dock a view inside the editor
  area, under the file tabs, at the left, top, right or bottom of the page. The page keeps the rest;
  these areas have tabbed groups, splitters and auto hide like the others, and desktops keep them.
- **The dock's commands in every view's menu** (right-click its caption or its tab): _Dock Left_,
  _Dock Right_, _Dock Bottom_, _Dock Bottom (Full Width)_, _Dock in Editor Area_ (left, top, right or
  bottom), _Floating_, _Tabs_ (top, bottom, left or right), _Auto Hide_ and _Close_.
- **Auto hide.** The pin on a caption collapses its group into tabs along the window's edge. Click
  a tab, or rest the pointer on it, and the group slides out; it slides back when you leave it. Drag
  its inner edge to make it wider or taller. A failed compile slides Messages out, a debugger stop its view.
- **Floating groups.** Any group floats in a window of its own, which stays above the main window
  and has no task bar button. A double click on its caption docks it back where it was.
- **Tabs in any order.** Drag a group's tabs, or the file tabs, into the order you want.
- **File tabs** have a close box when the pointer is on them, a middle click closes them too, and in its place
  a modified file's tab shows a green dot, the others a light grey one. A file whose text is back to what was saved -
  by undo or by typing it back - is no longer modified. The project's desktop keeps their order, and Delphi 7 reopens the files in that order
  too. A button at the end of the row lists the open files; or the tabs go into as many rows as they need (_Tools ▸
  Editor Options ▸ Display ▸ Multi-line file tabs_).
- **The _Tabs_ menu** (Delphi 7's _Window_): _Next Tab_ (Ctrl+Tab) and _Previous Tab_ (Ctrl+Shift+Tab) go through
  the file tabs, then come the open files and the windows outside the main window - floating views and the
  components' design windows -, any of them brought to the front with a click.
- **Back where you left off.** D7 Studio opens the project that was open when it closed (or the
  files named on its command line), and no new Project1 is made. Its start-up screen shows what it
  is loading.
- **The window's place** is kept at every close and restored, on its monitor.
- **The Components view in place of the palette.** _View ▸ Components_ lists the installed
  components of one palette page, or of all. Type in the list to filter it (`*` and `?` for a mask;
  Backspace takes a letter back, Esc clears it); the status line below the list shows the filter
  and how many components it leaves. Enter or a
  double click puts the chosen component on the form; drag it to drop it where you want it.
  _Tools ▸ Environment Options ▸ Components_ chooses Delphi 7's tiles or icons beside the names,
  the order (by name, last used, most used or palette order) and a shortcut key for the view.
- **Filter the lists you choose from.** _View ▸ Units_ (Ctrl+F12), _View ▸ Forms_ (Shift+F12), _Remove From
  Project_ and the other dialogs that list names have a filter box above the list: type part of a name (or a mask
  with `*` and `?`) and only the names that hold it remain, those that start with it first. The arrow keys move in
  the list while you type, and Enter opens the name chosen.
- **The status bar** also shows Error Insight's count of errors (click it for the list), the
  file's encoding and, when it is not 100 %, the zoom of what the page shows.
- **A tool bar on every page.** Above the code, the form, the diagram and a resource's editor, a bar
  holds what that view needs: the navigation boxes over Pascal code, the Diagram's buttons, a resource editor's
  commands - after the zoom bar, which comes first.
- **Zoom everywhere, one way.** The code editor, the form designer, the Diagram tab, the Markdown preview and the image, text and hex editors of resources zoom with the zoom bar - _Zoom Out_, _Zoom In_, _Reset Zoom_,
  and _Zoom to Fit_ for the form, the diagram and images -, with _View ▸ Zoom_ (Ctrl+Num +, Ctrl+Num -,
  Ctrl+Num /) and with the mouse wheel
  while you hold the zoom key: Ctrl by default, or Ctrl+Shift, or Alt, or none (_Tools ▸ Environment
  Options ▸ Preferences ▸ Zoom key_). The wheel never zooms while a mouse button is down.
- **Search results** have a view of their own beside Messages, with the found text in Unicode.
- **The Browser works without a compile.** _View ▸ Browser_ reads the units as the editor has them,
  unsaved changes included; Delphi 7's needs a compiled project. It is brought up to date when you
  save a unit of the project, as well as after a compile. It docks like every view.
- **Resources in the IDE.** _View ▸ Resources_ lists the active project's `.res`: bitmaps, icons,
  cursors, string tables, version information, the manifest. You can add new ones (icons and
  cursors in sizes up to 256 px) and import and export files. A resource opens as a page of its
  own, in an image editor with Visual Studio's tools and keys, a string table, a text editor or a
  hex editor; Save writes it into the `.res`, and a compile takes unsaved changes as they are. The
  image, text and hex editors zoom. Delphi 7 has only its separate Image Editor.

## Dialogs and options

- **Options in one dialog.** _Tools ▸ Environment Options_, _Editor Options_, _Debugger Options_
  and _Formatter Options_ open one dialog with Delphi 7's pages in a tree, and OK applies them
  all; _Project ▸ Options_ has the same form. The pages are larger, and their lists use the full
  height.
- **Dialogs open on the window they came from**, centred on it and kept inside one monitor's work
  area, also on monitors left of or above the primary one.
- **A clean dialog layout.** Dialogs have a white body and their command buttons in a gray band at
  the foot, below a thin line, all buttons of one size. _Tools ▸ Environment Options ▸ Preferences ▸
  User interface ▸ Dialogs_ makes the body gray instead; the dialogs opened afterwards follow it.
- **Open and Save dialogs** take file names with characters the system code page lacks.
- **Boxes of file and folder names** - in Tool Properties, Run Parameters, Install Component, New
  Component, Import Type Library, the directories of Project and Environment Options - complete the
  name as you type and take a file or folder dragged onto them from Explorer.
- **The search path editor** (the _..._ of a search path) has _Edit as text_, one folder per line,
  takes folders dragged onto it from Explorer, and makes the selected folder relative (to
  `$(DELPHI)` or the project's folder) or absolute.
- **Install Packages** has _Show in Folder_: Explorer opens with the package selected.
- **Tools ▸ Configure Tools** exports the tools to a file and imports them from one, adding those
  the list does not have.
- **Auto close on successful compile** (_Tools ▸ Environment Options ▸ Preferences_, under _Show
  compiler progress_) closes the Compiling dialog after a compile without errors.

## The code editor

- **Files in any encoding.** Each file keeps its encoding: UTF-8, UTF-16, the system code page or
  another code page - a Greek file on a Western Windows shows its own characters and is saved byte
  for byte. The status bar shows the encoding; _File ▸ Reopen with Encoding_ reads the file in
  another one, _File ▸ Convert to Encoding_ saves it in another one. Find and Find in Files work in
  every encoding. Delphi 7's editor knows the system code page only.
- **Colour themes** (_Tools ▸ Editor Options ▸ Color_): Light (the default), Dark, Classic (Delphi
  7's colours) and themes of your own, made from any of them and imported or exported as
  `*.d7theme` files. A theme colours the text, the gutter and margins, the highlights, the
  debugger's lines and the completion list, shown at once in a live sample. An element left at
  _Default_ follows the theme, so a new background is one change.
- **Names coloured by kind**: types, routines, properties, fields, variables, local variables,
  parameters, constants and units each have a colour of their own in Light and Dark, and can be
  bold, italic or underlined. Classic colours them all as identifiers, as Delphi 7 does.
- **Flow control and your own identifiers stand out**: `Exit`, `Break`, `Continue`, `Halt`, `Abort`, `raise` and
  `goto` in a colour of their own, and the identifiers you list (_Editor Options ▸ Highlighting ▸ Custom identifiers_)
  in another - elements of the colour themes like the rest.
- **The navigation bar** over the code: a _Class_ box and a _Methods/functions_ box that follow the
  caret and jump to what you choose (_Editor Options ▸ Display ▸ Navigation bar_).
- **Code folding** as in RAD Studio: the unit's `interface`, `implementation`, `initialization` and
  `finalization` sections, each routine from its heading (its `var` section and nested routines
  inside), types, `uses` clauses, statement blocks, `{$REGION}`s, `{$IFDEF}` blocks and comments. A
  folded block ends in a `...` box; rest the pointer on it to see the hidden code in a tip (_Editor
  Options ▸ Display ▸ Fold preview_). _Edit ▸
  Folding_ and RAD Studio's Shift+Ctrl+K keys fold all, the methods, the classes, the sections, the
  nested routines or the regions, and turn folding on or off. **Line numbers** and **change bars** (unsaved and saved
  changes) in the gutter; the line numbers of line 1, every 5th line and the caret's line, with dots between, or of
  every line (_Editor Options ▸ Display ▸ Line numbers_).
- **Highlighting** (_Editor Options ▸ Highlighting_): the bracket at the caret and its partner (a
  bracket without one in red); the words of the block at the caret (`begin` ... `end`, `try` ...
  `finally` ... `end`); every place of the name at the caret - code insight tells same-named
  symbols apart -; every match of the last search; the current line; indentation guides; and
  rainbow brackets if you want them.
- **Markers on the scroll bar** for changed lines, search matches, the places of the name at the
  caret, breakpoints, bookmarks, the execution point and errors.
- **A minimap** beside the scroll bar: the file in miniature in its colours (the large minimap draws
  its characters from the editor's font), the lines in view in a
  box, the caret's line, the selection, search matches and errors. A click jumps there, dragging the
  box scrolls, and the pointer over it shows the code around that line in a tip (_Editor Options ▸
  Display ▸ Scroll bars ▸ Minimap_: _Enabled + preview_, _Enabled_ without the tip, or _Disabled_). It
  can scroll with the view (the default) or show the entire file, squeezed to its height (_Layout_
  beside _Minimap_), and be drawn twice as large for big screens (_Large minimap_). A drop-down button
  at the right end of the code editor's bar has all four switches: show or hide it, its preview, the
  entire file and the large size.
- **Typing aids** (_Editor Options ▸ Typing_): brackets and quotes close themselves; Enter after
  `begin`, `try`, `repeat` or `case` adds the missing `end`, `finally` ... `end` or `until`; the
  next line is indented after `then`, `do`, `else` and section words, and `end` or `until` goes
  back to its block's indentation.
- **Multiple carets**: _Select Next Occurrence_ (Shift+Alt+.), _Select All Occurrences_
  (Shift+Alt+;), _Add Caret Above_ / _Below_ (Ctrl+Alt+Up / Down), and Ctrl+Alt+click.
- **Line and selection commands**: _Duplicate_ (Shift+Ctrl+D), _Move Up_ / _Move Down_
  (Shift+Ctrl+Alt+Up / Down) and _Join_ (Shift+Ctrl+J) lines; _Upper Case_, _Lower Case_, _Toggle Case_, _Sort
  Lines_ and _Surround With_ `begin ... end`, `try ... finally`, `try ... except` (_Edit ▸ Line_); _Toggle Comment_ (Ctrl+/) in every language that has comments; _Expand_ / _Shrink
  Selection_ (Shift+Alt+= / Shift+Alt+-) by the code's structure.
- **A macro recorder** (_Edit ▸ Macros_, and the _Macros_ drop-down on the code view's tool bar): record keys
  (Shift+Ctrl+R, again to stop), play them (Shift+Ctrl+P) or play them repeatedly - so many times, or until the end
  of the file -, undone in one step. Every recording is kept in the _Macro Library_ (_View ▸ Macro Library_), also
  after a restart: choose the macro that Shift+Ctrl+P plays, rename, delete and reorder them, export them to a
  `.d7macros` file and import them from one. Delphi 7 has one unnamed macro, lost when it closes, and no menu for it.
- **A button by the selection** opens a menu of what applies to it: cut, copy, comment, indent, duplicate, move,
  case, sort, surround, format (_Editor Options ▸ Display ▸ Selection button_).
- **Word wrap** (_Editor Options ▸ Display ▸ Word wrap_) and **zoom** (the zoom bar, _View ▸ Zoom_,
  the wheel with the zoom key): one zoom for every file, kept.
- **Back and Forward remember every jump**: also a switch to another file, and a line reached from
  Messages, Search Results, the To-Do List, the Code Explorer or _Go to Line Number_; going back
  reopens a file that was closed. Delphi 7 records only Ctrl+click and Find Declaration.
- **Other languages**: C/C++, C#, IDL, SQL, resource scripts, XML, HTML, INI-style files, batch
  files, make files and Markdown are coloured in the theme's colours, and all but the last three can be folded.
- **A class diagram.** The _Diagram_ tab of every unit, program and package draws its classes,
  interfaces and records as UML boxes with their fields, methods and properties, and lines to their
  ancestors and interfaces. Open and close the boxes, zoom (also to fit the whole diagram),
  double-click to go to the code. (Delphi 7's Diagram page shows a module's components instead.)
- **The history of every file.** The _History_ tab keeps the versions of each
  file: every save, your unsaved text every five minutes, the text you let go when you close a file
  without saving or reload it, a change another program made, and Format Project's rewrite. On the
  left they are listed by day, each with its time, the lines it added and removed and the routines it
  changed; on the right the version you choose is compared with the text as it is now - or with the
  version before it, or with another version you choose with Ctrl -, in the editor's colours, inline
  or side by side, the changed words marked and the unchanged lines folded away. _Restore Version_
  puts a version back (a unit together with its form), _Restore Change_ only the change at the caret;
  Undo takes either back. Filter the versions by a routine (also _History of Routine_ in the
  editor's menu) or by a text they contain, and label a version to keep it for good. The versions are
  kept in D7 Studio's own folder, not in your project's (_Editor Options ▸ Display ▸ Keep file
  history_, 50 versions per file). Delphi 7 keeps one backup (`Unit1.~pas`) beside the file.
- **A Markdown preview.** The _Preview_ tab of a Markdown file (`.md`, `.markdown`) shows it rendered as it is in
  the editor, unsaved changes included: headings, emphasis, lists and task lists, quotes, tables, rules, pictures
  beside the file, and code blocks coloured as the code editor colours them in its theme (GitHub's Markdown: tables,
  task lists, strikethrough and bare web addresses too). A link to a heading of the file scrolls there, one to
  another Markdown file opens that file's preview, one to another file opens it in the IDE, a web address opens in
  your browser; the link's target shows when the pointer rests on it. Select text with the mouse (a double click: a
  word) and copy it; zoom it like the other views; F12 switches between the code and the preview. Its right-click
  menu opens a link or copies its address, and _Show Code_ takes you to the line of the Markdown you clicked.

## Code insight

- **Error Insight** (_Tools ▸ Editor Options ▸ Code Insight ▸ Error Insight_, on by default): a
  second after you stop typing, the errors of the unit shown get a wavy underline, in Delphi 7's
  compiler's words - syntax errors, undeclared identifiers and members, routines declared without
  an implementation, and headings that differ from their declaration. Point at one for its message.
  They are marked on the scroll bar, counted in the status bar and listed in the _Error List_
  (_View ▸ Error List_), where a double click goes to one. Error Insight reports only what it is
  sure of: the compiler stays the judge.
- **Completion while you type.** With _Code completion_ on, the list also opens two characters
  into a name, after the _Delay_, and it changes nothing you type unless you press Enter or Tab.
  Delphi 7 opens it by itself only after a dot.
- **Tips that look like code.** The tip of a name shows its declaration coloured as code, with its
  unit and line; the parameter hint marks the current parameter on a highlighted box.
- **Value tips as trees.** While the program is stopped, the tip shows the value of the whole
  expression under the pointer, with records, arrays and objects to open in place. Delphi 7 shows
  one line.

## Refactoring

_Edit ▸ Refactor_, the _Refactor_ button on the code editor's bar, and _Refactoring_ in the code editor's menu. Each
refactoring shows its changes first
in the _Refactorings_ view - every file and line it changes, and the file before and after compared as in the History
tab - and makes them when you
click _Apply_; an open file's changes are undone in one step, a closed file keeps its text before in its History.
Delphi 7 has none of them.

- **Rename** (F2): a variable, constant, type, routine, method, field, property or parameter, everywhere the project
  group uses it - code insight tells same-named symbols apart. A routine's overloads, a method's overrides and a
  parameter's other heading come along; a component, an event handler or a form's class is renamed in the form files
  too, and the open form designer follows.
- **Declare Variable** (Shift+Ctrl+V) and **Declare Field**: a name that is not declared yet becomes a local variable
  or a field of the class, its type guessed from how it is used.
- **Find Unit** (Shift+Ctrl+A): the units that declare the name at the caret; the one you choose goes into the uses
  clause.
- **Extract Method** (Shift+Ctrl+M): the selected statements become a method (or routine) of their own; the
  variables they need become its parameters, a value they produce its result, and the statements a call.
- **Introduce Variable** and **Inline Variable**: an expression kept in a new local variable, or a variable assigned
  once replaced by its value.
- **Change Parameters** (Shift+Ctrl+X): add, remove, reorder, rename and retype a routine's parameters; its
  declarations and every call change with them.
- **Extract Resource String** (Shift+Ctrl+L): the string at the caret becomes a resource string of the unit.
- **Extract Constant**: the number or string at the caret, or a selected constant expression, becomes a named
  constant of the routine, the implementation or the interface - the same value elsewhere there too, if you like.
- **Convert to Format**: a string concatenation becomes a call of `Format`: `'Total: ' + IntToStr(N)` becomes
  `Format('Total: %d', [N])`.
- **Implement Methods**: the methods of a class's interfaces that it lacks, and overrides of its ancestors' virtual
  and abstract methods, chosen from a list; they are declared and implemented, an override calling the inherited
  method.
- **Encapsulate Field**: a field goes behind a property - the field private, the property reading and writing it or
  writing through a setter -, and the code outside the class uses the property. It refuses where a property cannot
  stand, such as a var argument.
- **Complete Case**: a case statement on an enumeration gets a branch for each value none of its branches has.
- **Remove With**: a with statement goes and what it gave is named through its expression; a call or a typecast is
  kept in a new variable first.
- **Clean Uses**: the units a unit does not need are removed from its uses clauses, and those only its
  implementation needs move there - except a unit whose start-up code a program of the group would lose.
- **Safe Delete**: a declaration nothing in the project uses is deleted with its implementation; otherwise it tells
  you where it is still used.
- **Const Parameters**: the string, record, array, Variant and interface parameters a routine never changes become
  `const`, in every heading of the routine.
- **Rename Unit**: a unit, everywhere it is named - uses clauses, the project's entry and path -, and its file and
  its form's file.
- **Move to Unit**: a type, routine, constant or variable goes into another unit of the project, and the uses
  clauses follow. What only it used of the unit's implementation goes with it; what other code there uses too, or a
  private member it reaches, stops the move with the reason.
- **Pull Members Up** and **Push Members Down**: members of a class move into its ancestor, or into each of its
  descendants, declared and implemented there.
- **Sync Edit**: the names that occur more than once in the selected text are linked - typing over one changes them
  all; Tab goes to the next name, Esc ends it.

## Code metrics

- **Project ▸ Metrics** measures the active project's code as RAD Studio's QA Metrics do; Delphi 7 has nothing of
  the kind. Each routine, class and unit and the project get their size (lines, code lines, comment ratio,
  parameters, local declarations, fields, methods, properties), complexity (cyclomatic complexity, nesting depth,
  weighted methods per class), inheritance (depth, child classes), coupling and cohesion (coupling between objects,
  response for a class, lack of cohesion of methods, units used and used by), Halstead's measures and a
  maintainability index. A class or unit shows the sum, average, maximum or minimum of the values below it, as you
  choose for each metric.
- The **Metrics** view (_View ▸ Metrics_) lists them as a tree with a column per metric: a value over its upper
  limit is red, under its lower one blue, and the row's name bold. Click a column's header to sort by it; _Outside_
  shows only what breaks a limit; a double click opens the code. The pointer on a header tells what the column
  counts. _Unit_ measures only the unit shown, _Export_ writes the results as an HTML or CSV file.
- **Environment Options ▸ Metrics**: which metrics are computed, each one's limits and aggregation.

## The formatter

- **Format Source** (_Edit ▸ Format Source_, Ctrl+D) formats the selected lines or the whole
  Pascal file, or a form's text, as one undo step. _Project ▸ Format Project Sources_ formats the
  project's files, and an option formats each Pascal file when it is saved. Delphi 7 has no
  formatter.
- **RAD Studio's options and presets.** _Tools ▸ Formatter Options_ has the options of RAD Studio's
  Delphi formatter under their names, with a live preview, built-in presets (RAD Studio, Borland
  Style Guide, JEDI Code Format, DelForExp ...) and presets of your own; it imports and exports RAD
  Studio's `Formatter.config`.
- **It never breaks your code**: when a result would not keep every token, nothing changes and a
  message names the line. Breakpoints and bookmarks stay on their lines.

## The form designer

- **Forms are designed in the main window**, each in the frame it will have at run time: the frame
  follows _BorderStyle_ and _BorderIcons_ (a dialog has a dialog frame, a tool window a small
  caption), and the controls show the look of the running Windows. A form without a border, a data
  module or a frame has no title bar, only a thin border line that marks its edges. Delphi 7 shows
  every form with a sizeable frame and classic controls.
- **Controls move and resize live** under the mouse, not as outlines; a box marks a resized control's
  new bounds while you drag; Esc puts them back.
- **Zoom the form** from 5 % to 400 % in steps of 5 %, or to fit the whole form in view, and work
  on it as at 100 %: select, move, size and drop components. The form's sizes and positions stay as
  they are. Each form has its own zoom.
- **The designer's commands above the form**: _Scale..._, _Tab Order..._, _Creation Order..._, _Flip
  Children_, _Hide Non-Visual Components_ (the non-visual components' tiles off every form), _Lock Controls_, _Bring to Front_, _Send to Back_, _Align..._, _Size..._, _Align to Grid_ and
  the ten alignments - edges, centers, center in window, space equally - on the bar at the top of the
  design view, each enabled when it applies to the selection. Delphi 7 has the
  alignments in a separate floating Alignment Palette and the others in its menus only.
- **Snap lines** (_Tools ▸ Environment Options ▸ Designer ▸ Snap lines_, on): an edge you drag
  snaps to the edges of the other controls, to the usual spacing beside them and to the margin of
  their container, and a line shows it. A control you move also snaps by its text: its caption's or
  text's baseline onto another control's - a label beside an edit, a check box or a button - and the
  start of its text onto where another control's text begins, shown by a dashed line (_Snap to
  captions and text_, on).
- **Undo and Redo** of every designer change (Ctrl+Z, Shift+Ctrl+Z), up to 100 steps: drops,
  moves and sizes, Object Inspector edits, deletions, pastes, alignments - with the code the
  designer wrote for them. Delphi 7 has only _Undelete_.
- **The form positioner** (_Environment Options ▸ Designer ▸ Show form positioner_): a button at
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
- **Pictures** of the _Align_ and _Alignment_ values, in the rows and in the drop-down lists.
- **Readable values**: _Constraints_ shows its four numbers, _Font_ its name and size in that font,
  and the list of _Font.Name_ shows each name in its own font.
- **Unicode values.** A string property takes any character, such as a Greek caption on a Western
  Windows, and WideString properties (TNT controls, ADO's ConnectionString) are shown and edited
  in Unicode. Delphi 7 turns the characters its code page lacks into `?`.

## Code Explorer and To-Do List

- **Synchronize with the editor** (_Tools ▸ Environment Options ▸ Explorer_, off by default): a
  node you choose shows its code, and the caret selects the node of the declaration it is in.
- **To-Do items** are written in the file's own encoding, also in Unicode files. Changing several
  values of an item at once works (Delphi 7 can damage the comment), and _Table Properties_ of
  _Copy As ▸ HTML Table_ are remembered.

## Projects and compiling

- **A File Explorer** (_View ▸ File Explorer_, a tab beside the Project Manager): the files and folders
  of the active project's folder and of any folders you pin, with a filter box and _Show_ switches for
  Delphi's files only, the build output and hidden files. The project group's files are in bold, an
  open file with unsaved changes has the file tabs' green dot, and files made, renamed or deleted on the
  disk show at once. A double click opens a file, its menu adds it to the active project, makes,
  renames (a unit through _Rename Unit_) and deletes files and folders (to the Recycle Bin), copies the
  path, opens Explorer or a command prompt there and searches the folder with _Find in Files_. _Locate
  Active File_ and _Follow the Editor_ find the file being edited.
- **Drop files on the Project Manager** to add units and resource scripts to the active project.
- **Sources in UTF-8 or UTF-16 compile.** D7 Studio gives Delphi 7's compiler a copy in the system
  code page; Delphi 7 compiles code-page text only and stops at a byte order mark. A character the
  code page lacks in a string or in code is reported as a warning on its line in _Messages_, and so
  is an include file in another encoding.
- **Resource scripts** (`{$R 'x.res' 'x.rc'}`) are compiled by Delphi 7's brcc32 when the script
  or a file it names (an icon, a bitmap, a header) has changed, unsaved scripts as the editor shows
  them; brcc32's errors appear in _Messages_ like the compiler's, and a double click opens the line.
- **A modern icon for new programs.** A new project gets an application window in the style of
  Windows 11 as its icon, in full colour and sharp from 16 to 64 pixels, so at every display scaling
  up to 250 %.
- **Sharp programs on every display scale.** The programs D7 Studio builds are per-monitor DPI
  aware by default (_Project ▸ Options ▸ Application ▸ DPI awareness_): their forms scale to the
  monitor they are on, where Windows would stretch a Delphi 7 program and blur its text.
- **A current manifest for every program.** Besides the visual styles, D7 Studio's manifest
  declares Windows Vista to 11, long paths and the rights the program asks for (_Project ▸ Options ▸
  Application ▸ Execution level_: as invoker, highest available, or require administrator).
- **Win64.** _Project ▸ Options ▸ Application ▸ Target platform_ Win64 builds the project with the
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
  watch moved to another group keeps its group and its _Break When Changed_ breakpoint.
- **A font for the debugger views** (_Tools ▸ Environment Options ▸ Preferences ▸ User interface ▸
  Fixed-size font_, also the font of the update notes):
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
  settings. _Help ▸ Create Bug Report..._ turns it into `bugreport.txt` for an issue: the errors grouped,
  their call stacks with procedures, lines and source, and the system, Delphi 7, the packages and experts.
- **Updates from GitHub**: _Help ▸ Check for Updates..._, and once a day at start-up (_Tools ▸ Environment
  Options ▸ Preferences ▸ Check for updates at start-up_), look for a newer release. Its dialog
  shows what's new: the release notes of every version since yours; _Update_ downloads the setup, checks its SHA-256, closes D7 Studio and
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
