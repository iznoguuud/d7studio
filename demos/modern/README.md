# ModernDemo

A Delphi 7 program that shows what the modernized RTL/VCL adds (`MODERNIZATION.md`, in the patch and in Delphi 7's `Bin` once D7 Studio is installed): one window in the
style of Windows 11's Settings - a sidebar of five areas (Display, Unicode, Dialogs, Look, System),
each page a few cards, and the activity at the bottom.

## Build and run

- It needs Delphi 7 with the modernized RTL/VCL installed - D7 Studio's Setup, or
  the patch's `patch.ps1` - and Windows 10 1903 or later for all of it (per-monitor DPI awareness
  V2, UTF-8 as the code page). Its icons are Windows' stock icons.
- D7 Studio's Setup installs it into Delphi 7's `Demos\ModernDemo`.
- `.\build.ps1 -Run` builds `bin\ModernDemo.exe` with the installed Delphi 7's dcc32, with the
  run-time packages `rtl` and `vcl` (Delphi 7's `Bin` on the `PATH`), and starts it. Or open
  `ModernDemo.dpr` in D7 Studio or Delphi 7.

## What to try

- **Display.** Move the window to a monitor with another scale, or change the scale in Windows'
  settings (*Display settings* on the tool bar opens them). The window, its fonts, controls, the
  facts, the ruler and the embedded form follow at once, and *Activity* lists each change. *Float*
  puts the embedded form into a window of its own: move it to another monitor, then *Dock* it again.
- **Icons at this scale** shows two image lists side by side. The first has its icons as Windows
  draws them at 16, 20, 24 and 32 pixels (the tool bar and the sidebar use it); the second only at
  16. At 125 % and 150 % the first row is sharp, the second enlarged and blurred. At 100 % they are
  the same.
- **Unicode.** Type or paste text in any script. *Count* tells its characters, UTF-16 code units and
  bytes; *Use as a file name* makes a file of that name in the temporary folder and finds it again;
  *Sort* orders the words as Windows orders text.
- **Dialogs.** Each button opens one of Windows' current dialogs through the ordinary VCL call.
- **Look.** The list and the tree are drawn like Windows Explorer's; *Dark title bar* darkens the
  window's title bar.
- **System.** The real Windows version, the program's code page, the memory FastMM4 has given out,
  a SHA-256 and random bytes from Windows' cryptography, and every monitor with its DPI and work
  area. *Refresh* measures again.

## The files

Start with `DemoMain.pas`: its comments marked "Modernized:" point to each new feature used.

| File | What it is |
|---|---|
| `ModernDemo.dpr` | The program. `ModernManUtf8` first in the uses clause links the manifest that turns the new features on: Windows' current look, per-monitor DPI awareness and UTF-8 as the code page. `MainFormOnTaskbar` gives the program one taskbar button, the main window's. |
| `DemoMain.pas` / `.dfm` | The main window: the sidebar (an owner-drawn list box), the pages (panels) and their cards. The table `Areas` makes the sidebar, the page titles and the Look page's list and tree. Each page's handlers are short: what they show is the RTL/VCL's own work. |
| `DemoIcons.pas` | The icons: Windows' stock icons (`ShellAPI.SHGetStockIconInfo`) at each size (`SHDefExtractIcon`), given to an image list with `ImgList.AddImageListResolution`. |
| `DemoFacts.pas` / `.dfm` | A list of facts: a frame made at run time, which the VCL scales from 96 DPI to its form's DPI. |
| `DemoPanel.pas` / `.dfm` | The embedded form: put on a panel of another form, a form is scaled from its own DPI to the panel's. |
| `DemoGauge.pas` | A control that paints itself for every DPI: sizes given for 96 DPI and scaled with `ScaleForDpi`, made again on `CM_DPICHANGED`. |

## Adding an icon

The icons are Windows' stock icons, loaded at each size by `DemoIcons.pas`. To add one:

1. Append a constant after `icoSystem` - `icoSearch = 8;`, say - and widen the `StockIcons` array
   to it.
2. Append the stock icon's number to `StockIcons` at the same place (`SIID_FIND`, `SIID_FOLDER` ...:
   the `SIID_` constants of `ShellAPI`).
3. Use the constant as an `ImageIndex`. `AddIcons` loads the new icon at every size the list takes.

For icons of your own program, from your own pictures, see "Images for every size" in `MODERNIZATION.md`.

## Things to know

- Sizes set in code are 96-DPI sizes only while the form is at 96 DPI: scale them with
  `ScaleForDpi(Value, Control)`, which takes the DPI of the control's form.
- A control made in code and put on a form is not scaled then (Delphi 7's behaviour); sizes it
  computes in its constructor are the system DPI's. Make them when they are used, or on
  `CM_DPICHANGED` - `DemoGauge` does both.
- `OnShow` comes before the VCL scales a form for the monitor it is shown on: a monitor whose scale
  is not the system's scales the form right after it (the log shows it).
- An image list follows the DPI of the form that owns it (or of a frame on it); one on a data module
  follows the system DPI, and one with `ShareImages` none. Images drawn for more sizes go to a list
  as strips, one per size, with as many images as the list in its order
  (`AddImageListResolution`), or from resources named `NAME_<size>` (`LoadImageListResolutions`;
  32-bit bitmaps as `RCDATA`, which brcc32 compiles).
- A label on a tool bar gets the slot of a separator, as high as the buttons: give it `AutoSize =
  False`, a width and `Layout = tlCenter`, or its text sits at the top.
- In UTF-8 mode `Length` counts bytes. Keep text beyond ASCII in the form file (as the Unicode page
  does) or in resources: Delphi 7 compiles a source file in the system code page.
- A page control whose `Style` is `tsButtons` or `tsFlatButtons` draws no background behind a
  themed check box or button on its pages: they can show what was painted there before. The demo's
  pages are plain panels, shown one at a time.
- The cards are `TPanel`s whose `Tag` is 1: `DemoMain` declares a class `TPanel` of its own before
  the form, which paints such a panel as a card - the form's panels are of that class, and the form
  file stays readable by any Delphi 7.
