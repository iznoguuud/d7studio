# Delphi 7 RTL/VCL, modernized

Delphi 7's RTL and VCL with native Unicode, per-monitor DPI awareness and the current Windows API.
D7 Studio's installer patches them into Delphi 7 in place: the runtime packages in its `Bin`, the
units in its `Lib`, their sources in its `Source` - only the differences are shipped (below).
Uninstalling D7 Studio gives Delphi 7 its own files back.

## Features

### Compatible with Delphi 7

- **Binary compatible.** Existing declarations, class layouts and routine signatures are unchanged;
  new ones are appended. DCUs and packages compiled against Delphi 7's units still link, Borland's
  source-less DCUs link against these units, and Borland's design packages (`designide70.bpl`,
  `dcl*70.bpl`) load with the new runtime packages, which keep every export of Borland's.
- **Opt-in where behaviour changes visibly.** Without `ModernMan` / `ModernManUtf8` a program
  looks and behaves as with Delphi 7, plus the bug fixes, the modern file and folder dialogs and
  the multi-monitor placement. Task dialogs need Common Controls 6, which comes with the manifest
  units. Most features have a global switch back to Delphi 7's behaviour
  (`UseLatestCommonDialogs`, `PerMonitorDpiScaling`, `DoubleBufferedViews`, `MainFormOnTaskbar`
  ...).
- **Delphi 7 Update 1.** The RTL/VCL is Borland's Update 1 (Delphi 7.1, build 8.1), changed. D7
  Studio's installer patches only a Delphi 7 whose runtime packages are Update 1's (`rtl70`,
  `vcl70`, `vcldb70` 7.0.8.1, `dbrtl70` 7.0.8.2; `vcldb70` 7.0.8.3 with the Database
  supplemental). The patch comes in two variants, `Update1` and `Update1b`, one for each Delphi 7
  Update 1 build whose RTL/VCL files differ, built on that Delphi 7 from the same sources; the one
  whose files the Delphi 7 has is applied. Borland compiled its runtime packages apart from its
  units in `Lib`, which the patch links as they are: some routines of Borland's packages (in
  `FMTBcd`, `TypInfo`, `ComObj` ...) therefore differ from the patched packages' in register use and
  instruction choice, not in what they do. A `TPanel` takes its parent's background while the visual
  styles are on, as in Delphi 7: give a panel that must show its `Color` `ParentBackground = False`.
- **Only the differences are shipped.** The installer carries none of Borland's RTL/VCL files: each
  modernized package, DCU, DCP and source that replaces one of Delphi 7's is made on the target
  from Delphi 7's own file and its difference (Windows' `msdelta.dll`). So every one of those
  files of Delphi 7 must be exactly the file of one of those Update 1 builds, as shipped, checked
  by SHA-256 before anything changes; otherwise the installer stops and Delphi 7 stays as it is. The new units and
  `FastMM_FullDebugMode.dll` come whole. How the patch is made - compiled from source, with no
  decompilation and none of Borland's sources in it - is described in the `README.md` that comes
  with the patch, beside its `patch.ps1`.
- **Patch by hand, without D7 Studio.** `patch.ps1`, which comes with the patch, does what the
  installer does with the RTL/VCL, from an elevated PowerShell in the patch's folder:
  ```
  powershell -File patch.ps1 [-Delphi <Delphi 7 folder>]            # patch (again: updates it)
  powershell -File patch.ps1 -Check                                 # only check; nothing changes
  powershell -File "<Delphi 7>\D7Studio\patch.ps1" -Restore         # Delphi 7's own files back
  ```
  Where Delphi 7's installer put the six runtime packages into the 32-bit system folder
  (`SysWOW64`), it patches them there too: Windows looks there before the `PATH`, so a program
  outside Delphi 7's `Bin` built with runtime packages would load the unpatched ones.
  It refuses, with Delphi 7 unchanged, while a program runs from Delphi 7's `Bin` or when a file
  is not Update 1's as shipped, and backs up what it replaces into `<Delphi 7>\D7Studio\Backup`, as the
  installer does (the installer runs this same script). A copy that fails puts Delphi 7 back.
  Run again with a newer patch, it takes the earlier patch back and applies the new one. `-Restore`
  works from the copy of the script it keeps in `<Delphi 7>\D7Studio`, and refuses while D7
  Studio is installed (its uninstaller takes the patch back). A run that succeeds ends with exit
  code 0 and the line `patch.ps1: done`; a script that calls it should require both, since a
  `powershell.exe` that runs no scripts (as under Wine) also ends with 0. It needs Windows
  PowerShell 5.1.
- **Older Windows keep working.** A function newer than Windows XP is bound at run time and has a
  fallback, so a program still starts where it is missing.
- **No assertions**, as in Delphi 7's DCUs and packages: Borland's `Assert` calls in `System`,
  `SysUtils` and `Classes` never raise. IDE experts rely on that (CnWizards calls
  `FreeNotification` on image lists being destroyed, which `TComponent` asserts against).

### Native Unicode (UTF-8 mode)

With `ModernManUtf8` on Windows 10 1903 and later, the process code page is UTF-8: `string` is
still `AnsiString`, but holds UTF-8, so any Unicode text works in the VCL, file names, the
clipboard, sorting and formatting.

- `Utf8Mode` (new) detects the mode and redirects the A functions Windows does not convert (GDI
  text, `CompareStringA`, the locale functions, the keyboard message loop) to shims that call the
  W functions — in every Delphi module of the process, packages loaded later included. Its font
  shims create MS Sans Serif as Microsoft Sans Serif. `D7_UTF8_SHIMS=0` in a program's environment
  leaves all the shims out.
- Older Windows ignore the manifest's `activeCodePage` and run a `ModernManUtf8` program in the
  legacy code page. A program that cannot do without UTF-8 says so with the comment
  `<!-- requires activeCodePage UTF-8 -->` in its manifest (D7 Studio's *Target Windows*
  "Windows 10 1903 or later" writes it): there `Utf8Mode` shows "This program requires Windows 10
  version 1903 or later." (a console program writes it to stderr) and ends the program with exit
  code 1150 (`ERROR_OLD_WIN_VERSION`). The check is the EXE's (`MainInstance`), never a DLL's, and
  needs `SysUtils` or `Utf8Mode` in the program.
- `System` encodes and decodes UTF-8 correctly for characters outside the BMP (emoji).
- `SysUtils` starts UTF-8 mode before it reads the locale; `Classes` reads text files with a BOM
  or in a legacy code page, and converts DFM strings from their legacy code page.
- `Clipbrd`, `StdCtrls`, `Controls`: the clipboard through `CF_UNICODETEXT`, selections in bytes,
  combo box and memo buffers, Unicode windows for the classic edit controls.

### Per-monitor DPI awareness (V2)

With `ModernMan` / `ModernManUtf8` a program is per-monitor DPI aware; forms scale to the monitor
they open on and again when moved (`WM_DPICHANGED`).

- `ShellScaling` (new) binds every DPI function of Windows, with fallbacks and helpers.
- `Controls`, `Forms`: scaling fixes and the DPI change itself; runtime frames; a hook API for
  components (`RegisterDpiScaleHook`, `GetControlDpi`, `ScaleForDpi`, `ScaleDpiValue`,
  `ScaleDpiRect`, `CM_DPICHANGED`, `NotifyDpiChanged`); `GetSystemMetricForControl` gives a system
  metric - a scroll bar's width, a border - at the DPI of a control's form, as Windows sizes them.
- Embedded forms follow their host: a form put on a panel of another form at run time (a docked
  window, a wizard's page) is scaled from its own DPI to the host's, and again when it moves to a
  host on a monitor with another scale.
- ModernDemo (`d7studio\demos\modern` in the project's sources): a program that shows all this - and Unicode, the dialogs, the look and the
  Windows API -, with what to know when writing for every DPI (its `README.md`).
- `Graphics`: canvases keep a font's exact pixel height.
- `StdCtrls`, `ComCtrls`, `Grids`, `ExtCtrls`, `CheckLst`, `ActnMan`, `DBCtrls`, `DBGrids`,
  `FileCtrl`, `Outline`, `Tabs`: control-specific sizes. Tool bars keep their buttons' order and
  size through DPI changes; control bars and cool bars scale their bands, action bars their items'
  margins and sizes; check list boxes draw the theme's check box whole at their DPI (`Flat` frames
  only the classic one), rows at least the box plus a gap; drop-down buttons (a lookup combo box's, a
  grid's pick list editor's) are a scroll bar's width at the DPI; a DB grid's indicator, the pictures
  of `FileCtrl`'s lists and `TOutline`, `TOutline`'s rows and `TTabSet`'s edges and scroll
  buttons follow the DPI.
- Owner-drawn items get the theme's DPI too (`WM_DRAWITEM`, `WM_MEASUREITEM`, custom draw), also
  when Windows draws them outside `WM_PAINT` - a list's row when the selection moves, a `TBitBtn`
  when it is pressed -, and `Canvas.Font := Font` keeps the font's DPI on a canvas without a device
  context, so text measured outside painting is the DPI's.
- `ImgList`, `Buttons`: image lists and glyphs resampled from their 96-DPI originals. The image
  lists average areas, enlarging too: a whole factor (200 %) repeats each pixel exactly, another
  (125 %, 150 %) softens an edge by at most a pixel; their users see one change per DPI change.
  The image lists' resampler is public: `ResampleBitmap` gives any bitmap at another size (32-bit,
  premultiplied alpha, for `AlphaBlend`; its transparent colour or alpha kept), `ResampleBGRA`
  resamples raw premultiplied BGRA pixels, `DrawBitmapForDpi` draws a picture made for 96 DPI at its
  size for a DPI, `ImageListSizeAtDpi` tells the size a list's images get at a DPI.
- `ImgList`: an image list can hold its images drawn at more sizes than its design size - 20, 24,
  32 pixels for 16-pixel images -, given at run time: `AddImageListResolution(List, Strip)` (as
  many images as the list, side by side, 32-bit with alpha or with a transparent colour),
  `LoadImageListResolutions(List, HInstance, 'TOOLBAR')` (resources `TOOLBAR_20`, `TOOLBAR_24` ...:
  `RCDATA` holding a `.bmp` file - brcc32 takes no 32-bit `BITMAP` - or a `BITMAP`),
  `ClearImageListResolutions`. At a DPI whose size it has, the list shows those images as drawn;
  at another it scales the next larger set down. Images added, inserted, moved or deleted at run
  time follow in every set. Nothing changes in the DFM: the sets come from code.
- `Themes`, `Menus`: theme parts and popup menus at the DPI of their monitor.

#### Images for every size

An image list keeps the images it was designed with (16 x 16, say) and enlarges them above 100 %,
which softens them. To show images drawn for 125, 150 and 200 % instead:

1. Design the 16 x 16 images in the image list as always (the IDE's image list editor, the DFM).
2. Draw each larger size as one strip: all the list's images side by side, in the list's order -
   20 x 20 each for 125 %, 24 for 150 %, 32 for 200 %. Use 32-bit bitmaps with alpha, or bitmaps
   with a transparent colour.
3. Give the list the strips at run time, in `FormCreate`, from resources:
   ```
   // toolbar.rc - brcc32 takes no 32-bit BITMAP, so the .bmp files go in as RCDATA
   TOOLBAR_20 RCDATA "toolbar20.bmp"
   TOOLBAR_24 RCDATA "toolbar24.bmp"
   TOOLBAR_32 RCDATA "toolbar32.bmp"
   ```
   ```pascal
   {$R toolbar.res}
   ...
   LoadImageListResolutions(ImageList1, HInstance, 'TOOLBAR');
   ```
   or from bitmaps: `AddImageListResolution(ImageList1, Strip)` for each strip.

At a scale whose size it has, the list shows those images as drawn; at another it shrinks the next
larger size. A strip whose count or shape does not match the list's images is refused (the
function returns False, nothing changes).

To add an image later, add it to the 16 x 16 images, draw it at each size into the strips, and give
the strips again: a strip of a size the list has replaces it. An image added at run time with
`Add`, `AddMasked`, `AddIcon`, `Insert` or `Replace` goes into every size too, made from the image
given - enlarged above its own size, so soft there until it is drawn for that size.

### Current Windows look and behaviour

- `ModernMan`, `ModernManUtf8` (new): the application manifest — Common Controls 6, Windows Vista
  to 11 compatibility, per-monitor V2 DPI awareness, long paths, `asInvoker`; the second adds the
  UTF-8 code page. Use one of them instead of `XPMan`. Both manifests are language-neutral.
- `Dialogs`: `TOpenDialog` / `TSaveDialog` show the Common Item Dialog, `MessageDlg` and
  `ShowMessage` show task dialogs (with Common Controls 6); `TaskMessageDlg*`,
  `ExecuteFolderDialog`; `UseLatestCommonDialogs`.
- `FileCtrl`: `SelectDirectory` shows the modern folder picker.
- `ComCtrls`: list and tree views double-buffered with Windows Explorer's look; page controls
  switch pages without flicker.
- `Forms`: `MainFormOnTaskbar`, the Windows 7 taskbar model.

### Building in Delphi 7's IDE

A program has one application manifest, and Delphi 7's IDE writes none. Without one, a program
built there has the classic look, is stretched by Windows on a monitor scaled above 100 % (blurred
text), runs in the system code page and is treated as a program from before Windows Vista.

- **`ModernMan`** in the `.dpr`'s uses clause gives it the current manifest above: the program is
  per-monitor DPI aware and these units scale its forms. It suits any program.
- **`ModernManUtf8`** adds UTF-8 as the code page. Delphi 7's IDE and its compiler keep the sources
  in the system code page, so a string literal with characters beyond ASCII comes out wrong in a
  UTF-8 program; the text of forms is converted (`Classes`), and text the program reads or the user
  types works. Use it when the literals in code are ASCII. D7 Studio compiles such a program's
  sources in UTF-8.
- D7 Studio gives a program the same manifest itself, from its project options, and a program needs
  neither unit there. For a project built in both IDEs: D7 Studio puts its manifest into the
  project's `.res`, and a manifest unit used as well makes two. The compiler then reports
  "Duplicate resource(s): Type 24 (user-defined), ID 1" and keeps one. Compile the project once in
  D7 Studio, which takes its manifest out of the `.res` when the program uses a manifest unit.

### Several monitors

Delphi 7 assumed that the desktop starts at 0,0 and that the primary monitor is the screen.

- `Controls`: hints stay inside the work area of their monitor; `MonitorWorkAreaAt`,
  `DropDownListPos`.
- `Forms`: hint width from the monitor under the cursor; `poDesktopCenter` on the whole virtual
  desktop.
- `Grids`, `DBCtrls`, `dblookup`: drop-down lists open inside their monitor.

### Windows API

- Fixed: Delphi 7 bindings that no current Windows exports, or bound under a wrong name, DLL,
  parameter count or calling convention (`Windows`, `ActiveX`, `Ole2`, `UrlMon`, `WinInet`,
  `Nsapi`, `UxTheme`). A program that used one did not start.
- Extended with the Windows Vista to 11 additions: `Messages`, `CommCtrl`, `ShlObj`, `UxTheme`,
  `ShellAPI`, `CommDlg`, `WinSvc` (`ShellAPI`: Windows' stock icons, `SHGetStockIconInfo`, and an
  icon at any size, `SHDefExtractIcon`).
- Added SDK names: `INT_PTR`, `LONG_PTR`, `UINT_PTR`, `ULONG_PTR`, `DWORD_PTR` and `ULONGLONG` in
  `Windows`; `WM_UNICHAR` and the DWM state messages (`WM_DWMCOMPOSITIONCHANGED` ...) in
  `Messages`; `INTERNET_RAS_INSTALLED`, `INTERNET_CONNECTION_OFFLINE` and
  `INTERNET_CONNECTION_CONFIGURED` in `WinInet`.
- New: `ShellScaling`, `DwmApi`, `WindowsEx`, `WinSock2`, `ShLwApi`, `BCrypt`, `WtsApi32`,
  `PowrProf`, `UserEnv`.
- Checked against the Windows SDK 10.0.26100 (record sizes, field offsets and constants with a
  32-bit MSVC build; parameter counts) and the 32-bit DLLs of Windows 11 (every export).

### Memory manager

- `System`'s memory manager is FastMM4 4.993, as in Delphi 2006 and later — faster, no address
  space fragmentation, memory given back to Windows, leak reports
  (`ReportMemoryLeaksOnShutdown`), sharing with DLLs without `borlndmm.dll`.
- `System` has Delphi 2006's memory manager declarations (`GetMemoryManagerState`,
  `RegisterExpectedMemoryLeak` ...).
- The `FastMM4` unit is FastMM4 in FullDebugMode; `FastMM_FullDebugMode.dll` gives its stack
  traces.
- `borlndmm.dll` is a FastMM4 memory manager for `ShareMem`, with every export of Borland's.

### Delphi 7 bugs fixed

- `System`: surrogate pairs became two 3-byte sequences (CESU-8) in `UTF8Encode`; invalid UTF-8
  was accepted by `UTF8Decode`.
- `Controls`: `TControl.ChangeScale` tested `sfHeight` twice and scaled the height from `FTop`;
  size constraints were never scaled; `GetText` kept trailing bytes when `WM_GETTEXTLENGTH`
  over-reported.
- `Controls`, `Forms`, `Grids`, `DBCtrls`, `dblookup`: hints, drop-down lists and
  `poDesktopCenter` placed by the primary monitor or a desktop assumed to start at 0,0; the hint's
  last test compared `Bottom` for `Top`.
- `ComCtrls`: toolbars and status bar panels never scaled; list view columns scaled only while
  loading; `TPageControl` filled its background on the screen before comctl32 drew it.
- `Forms`: runtime frames were never scaled; image lists were scaled before the controls, which
  scaled toolbar buttons twice.
- `Clipbrd`: "Cannot open clipboard" while another process briefly held it.
- `StdCtrls`: combo box strings were not trimmed to the length copied; memo lines were cut at 4096
  bytes in UTF-8 mode; with visual styles, pressing Alt erased buttons, check boxes and radio
  buttons but for their access keys' underlines.
- `SysUtils`: `Languages` (`TLanguages.Create`) ran a call stub it built on the stack, so a
  program with DEP (NX compatible) ended with an access violation there.
- `UxTheme`: `GetThemeBackgroundExtent` was bound to `GetThemeBackgroundContentRect`.
- `Windows`: `wsprintf` was declared stdcall for a cdecl function (8 bytes left on the stack per
  call); functions that no Windows exports, or bound under wrong names, DLLs or parameter counts.
  `ActiveX`, `Ole2`, `UrlMon`, `WinInet`, `Nsapi`: the same (export names are case-sensitive).

## Things to know

- `Windows.GetVersionExW` takes the ANSI record (Delphi 7's declaration) and corrupts memory; it
  stays for compatibility. Use `WindowsEx.RtlGetVersion` or `GetRealWindowsVersion`.
- New names can clash with a third-party unit that declares its own `IShellItem`,
  `TaskDialogIndirect`, `DwmSetWindowAttribute` ...: qualify the name or reorder the uses clause.
- A thread variable cannot be used across packages: outside `vcl70.bpl`, use
  `Themes.Get/SetThemePaintDpi`, not `ThemePaintDpi`.
- The VCL sets the theme's DPI (`ThemePaintDpi`) around `WM_PAINT`, owner-drawn items
  (`WM_DRAWITEM`, `WM_MEASUREITEM`, custom draw) and `Repaint` of an opaque control. Code that
  draws theme parts at other times - in a timer, a mouse handler that draws at once - sets it itself
  to `GetControlDpi(Control)`, or gets the system DPI's parts.
- In UTF-8 mode `Length`, `Copy`, `Pos` and `S[i]` count bytes; source files stay ANSI, so keep
  non-ASCII text in DFMs or resources.
- `AllocMemCount` and `AllocMemSize` stay 0 with FastMM4, as in Delphi 2006;
  `GetMemoryManagerState` gives those numbers. `IsMemoryManagerSet` stays False.
