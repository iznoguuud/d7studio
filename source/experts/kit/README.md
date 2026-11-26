# The experts' kit

Code that the IDE experts share: the AI harness (`..\aiharness`) and Git (`..\git`). Each expert is
a package of its own, and packages that are loaded together cannot hold units of the same name. So
the shared code is kept once, in include files, and each expert compiles them under its own unit
names.

| File | What it holds | AI harness | Git |
|---|---|---|---|
| `KitText.inc` | UTF-8 and code pages (`DropLastChar`: an IDE string without its last character, whole), files with their encodings and UTF-16 names (`ReadFileW`, `WriteFileW`, `FileExistsW`, `DirExistsW`), lines (`KitStartsWith`), Base64, DPAPI; `TKitStringBuilder`; the experts' settings under `HKEY_CURRENT_USER` (`KitReadRegString`, `KitWriteRegString`: the unit uses `Registry` in its implementation), a code address as module + offset (`KitAddrInfo`, the self-tests' reports) | `AiText` | `GitText` |
| `KitProcess.inc` | A console program run with its output captured: `RunProcess` (UTF-16 command line, stdout and stderr apart, extra environment variables, cancellable; in a job object, so a cancel or a timeout ends every program it started), `RunConsole` | `AiProcess` | `GitProcess` |
| `KitUI.inc` | The look of D7 Studio's views: flat tool bars and frames, flat edits, a list box's horizontal range kept when the list gets a new window (`KitListRange`: a view docked or floated), the IDE's fonts and icons, the icon font's glyphs and Visual Studio's images from a bitmap resource (`KitBitmapIcons`; with alpha on comctl32 6, masked on comctl32 5 - Delphi 7's IDE; disabled ones greyed as Visual Studio greys them), a label in a tool bar's row, the view's status line, the keyboard passed on when a view shows one control in place of another (`KitPassKeyboard`), diff lines, dialogs prepared, `TKitRichView` (text appended while the reader is scrolled away from the bottom is inserted with the drawing off; then only its lines, if they are in view, and the scroll bar are drawn again: no flash of the end of the text; the padding around Rich Edit's rectangle is the view's own and stays empty; `Behind` and, with a `NewTextCaption`, a `TKitNewTextBox` over its foot while text came below the reader's place - a click goes to the end and the view follows again; the reader's place - the bottom, else the line at the top - is kept when the window is made again or the size changes; its code text in the editor's font, `SetCodeFont` changing the text there too), D7 Studio's notice of changed options (`KitEditorOptionsMessage`: `TKitRichView` and the controls of a form prepared with `KitUseIdeFont` take the editor's new font at once), a menu's item by its name in any submenu (`KitFindMenuItem`: the experts' places in the IDE's main menu) | `AiUI` | `GitUI` |
| `KitIde.inc` | The Open Tools API: projects, open modules, editor buffers, the cursor and the selection; a file opened as its text (`KitOpenFile`: a project, package or project group file through a module creator of the existing file - a module of its text in Delphi 7's IDE too -, as `IOTAActionServices.OpenFile` opens those as projects, in a group of their own; the creator gives the file's text, `TKitFileCreator.NewImplSource`: without it Delphi 7 opens such a file empty, and D7 Studio does the same); a module's file by its editor (`KitEditorFile`: '' where Delphi 7's IDE gives no editor - `GetModuleFileEditor` may return nil there); an expert's self-test in the IDE (`TKitSelfTest`: run from a timer after its menu command, PASS / FAIL lines and the closing DONE line in the log its environment variable names, an exception reported with its code address; the unit uses `ExtCtrls` for the timer) | `AiIde` | `GitIde` |

## How a unit takes a file

The unit names its own `uses` and includes the file twice: once in its interface, with
`KIT_INTERFACE` defined (the declarations), and once in its implementation (the code). An include
file says in its first comment which units its unit must use. A unit that needs another part of the
kit (`KitUI` uses `KitText`) names the expert's unit of that part:

```pascal
unit GitUI;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ImgList, CommCtrl,
  RichEdit, Menus, ActnList;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitUI.inc}
{$UNDEF KIT_INTERFACE}

implementation

uses
  ToolsAPI, GitText;

{$I ..\kit\KitUI.inc}

end.
```

dcc32 finds `..\kit\...` from the folder of the unit that includes it, so a program in another
folder compiles the units too. A unit may add
declarations of its own around the include file. `AiIde` keeps the paths of the AI harness's tools
there.

## Rules

- The shared names begin with `Kit` (`KitFlatToolBar`, `TKitRichView`, `TKitStringBuilder` ...).
  Names without a prefix (`Utf8ToIde`, `EditorText`) stay as they were. Plain names would clash with
  the VCL's (`Forms.TWindowHook`).
- A change to a file here changes every expert: build and test them all.
- An include file may end its implementation with `initialization` / `finalization` (`KitUI.inc`
  frees Msftedit.dll). A unit that adds code of its own puts it before that include.
- Code that would appear in two experts goes here, not into a copy.
- Read an editor buffer with `EditorText` only. Delphi 7's edit reader takes its count as 16 bits: a
  read of 65536 characters returns nothing, one of 32768 returns 32768 whatever the text's length.
  `EditorText` reads 16384 at a time. D7 Studio's reader has no such limit, so only a test in Delphi
  7's own IDE shows a mistake there.
- A window that shows a font or setting of the IDE takes a change at once when D7 Studio's notice
  comes (`KitIsEditorOptionsMessage`, sent to every window of the IDE when options are applied), and
  when it is made: the notice misses windows that do not exist (a hidden tab's). The kit gives its
  own controls the new font (`TKitRichView` also in `CreateWnd`, `KitUseIdeFont`'s forms also on
  `WM_CREATE`); a view that measures with that font measures again in its own `WndProc`, which runs
  after the kit's hook, and when it is shown (the Git Diff view: its rows and columns; not in
  `CreateWnd`, where the list's window may be the one being made). Delphi 7's IDE sends no notice.
