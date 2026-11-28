# D7 Studio

An IDE for Borland Delphi 7 projects, written in Delphi 7. It keeps the layout and the muscle
memory of the Delphi 7 IDE, with the look of the running Windows. Its setup also modernizes the
installed Delphi 7's RTL and VCL in place: native Unicode, per-monitor DPI awareness and the
current Windows API.

![D7 Studio: code completion between folded routines, with the Code Explorer, the Object Inspector, the Project Manager and the Components view](screenshots/02-code-editor.png)

<table>
<tr>
<td align="center"><a href="screenshots/01-form-designer.png"><img src="screenshots/01-form-designer.png" width="200" alt="The form designer at 1:1 with the form positioner open, its snap lines on the monitor the form opens on"></a><br><sub>Form designer</sub></td>
<td align="center"><a href="screenshots/03-refactorings.png"><img src="screenshots/03-refactorings.png" width="200" alt="A Rename refactoring previewed in the Refactorings view, with its diff, before it is applied"></a><br><sub>Refactorings</sub></td>
<td align="center"><a href="screenshots/04-file-history.png"><img src="screenshots/04-file-history.png" width="200" alt="The History tab: a file's versions and a side-by-side diff"></a><br><sub>File history</sub></td>
<td align="center"><a href="screenshots/05-code-metrics.png"><img src="screenshots/05-code-metrics.png" width="200" alt="Code metrics of the whole project, the values outside their limits in red"></a><br><sub>Code metrics</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/06-class-diagram.png"><img src="screenshots/06-class-diagram.png" width="200" alt="The Diagram tab: a unit's classes with their inheritance"></a><br><sub>Class diagram</sub></td>
<td align="center"><a href="screenshots/07-dock-guides.png"><img src="screenshots/07-dock-guides.png" width="200" alt="Dock guides while a view is dragged, the drop marker on the editor area's left side"></a><br><sub>Docking</sub></td>
<td align="center"><a href="screenshots/08-designer-zoom.png"><img src="screenshots/08-designer-zoom.png" width="200" alt="The form designer zoomed to 150 % with four controls selected and the alignment buttons"></a><br><sub>Designer zoom</sub></td>
<td align="center"><a href="screenshots/09-git.png"><img src="screenshots/09-git.png" width="200" alt="The Git expert: the changes and the commit message, the history of the commits and a diff"></a><br><sub>Git</sub></td>
</tr>
</table>

## Download

The setup is on the [Releases](https://github.com/iznoguuud/d7studio/releases/latest) page:
`D7Studio-<version>-setup.exe`, with its SHA-256 in `D7Studio-<version>-setup.exe.sha256`.

It needs:
- an installed Delphi 7 with Update 1 (Delphi 7.1: Help | About shows "Version 7.0 (Build 8.1)");
  Setup checks every file it patches and changes nothing when one is not Update 1's;
- Windows 10 1903 or later, with the visual styles on;
- administrator rights.

A newer setup updates an installed D7 Studio in place and keeps its settings; D7 Studio finds a
newer release itself (*Help | Check for Updates*, and once a day at start-up), downloads its setup,
checks its SHA-256 and starts it. Uninstalling D7 Studio gives Delphi 7 its own files back.

## What you get

- **The IDE**: one main window with docked, tabbed views; Delphi 7's form designer with
  Borland's design-time packages; the Object Inspector and Code Explorer in Delphi 7's layout; a
  Scintilla code editor with code insight, names coloured by kind, Error Insight, a minimap,
  refactorings (Rename, Extract Method, Change Parameters ...), code metrics and a source formatter; the debugger; light and dark themes. It loads Delphi 7's experts and design packages.
- **Two experts of its own**: an AI assistant and Git, as docked views of the IDE.
- **The modernized RTL/VCL**: programs built with it can run with UTF-8 as their code page, scale
  per monitor (per-monitor DPI awareness V2), use the current file and folder dialogs, task
  dialogs and Windows' current look, and call the Windows API up to Windows 11. It stays binary
  compatible with Delphi 7: existing DCUs, packages and Borland's design packages still link and
  load, and programs start on Windows XP unless they opt into the newer features.

## Documents

| Document | For |
|---|---|
| [source/README.md](source/README.md) | Installing D7 Studio, what Setup changes, the modernized RTL/VCL in your programs, the IDE |
| [source/FEATURES.md](source/FEATURES.md) | What D7 Studio's IDE has that Delphi 7's IDE does not, area by area |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | The release notes: what changed in each version - the IDE, its experts, the modernized RTL/VCL and Setup |
| [patch/MODERNIZATION.md](patch/MODERNIZATION.md) | The modernized RTL/VCL: its features and what a developer should know |
| [patch/README.md](patch/README.md) | How the patch is made: compiled from source, no decompilation, none of Borland's files in it |
| [source/THIRD-PARTY-NOTICES.md](source/THIRD-PARTY-NOTICES.md) | The icons: made from JetBrains' IntelliJ Platform icons (Apache License 2.0) - the licence, the notice and what was changed |
| [LICENSE.txt](LICENSE.txt) | D7 Studio's license (MIT), the licenses of the parts made by others, and Delphi 7 |

Setup installs the first four, the notices and the license into Delphi 7's `Bin`, where they link to each other.

## This repository

- `source\` - D7 Studio's sources: the IDE (`ide`, `editor`, `designer`, `codeinsight`,
  `debugger`), `migrate`, which carries an existing Delphi 7 configuration over, `bugreport`, which makes a bug
  report of D7 Studio's crash log (*Help | Create Bug Report*), and the two
  experts (`experts\aiharness`, `experts\git`, with the code they share in `experts\kit`);
  `README.md` and `FEATURES.md` with a copy of `patch\MODERNIZATION.md` beside them, as Setup
  installs them into Delphi 7's `Bin` with the release notes, `RELEASE-NOTES.md` at the root.
- `patch\` - the modernized RTL/VCL as Setup installs it: for each of Delphi 7 Update 1's files
  that it replaces, the difference from Borland's file (`Delta\`); the new units whole (`New\`);
  `manifest.txt` with every file's SHA-256; `patch.ps1`, which applies the patch to an installed
  Delphi 7 and takes it back.
- `demos\` - two demo programs: `modern` (ModernDemo), a tour of the modernized RTL/VCL - per-monitor
  DPI, Unicode, the current dialogs and look, the Windows API -, and `ota`, which exercises the Open
  Tools API in D7 Studio and in Delphi 7's IDE. Each has its README.
- `screenshots\` - the pictures at the top of this page, full size.

The patch holds none of Borland's RTL/VCL files: the ones it changes exist here only as
differences, which need the copy of Delphi 7 that you own.

> [!IMPORTANT]
> **To build D7 Studio, patch your Delphi 7 first.** D7 Studio's sources use the modernized
> RTL/VCL (`ModernMan`, `Utf8Mode`, `WindowsEx` ...), which a stock Delphi 7 does not have, so they
> do not compile against it. Patch the Delphi 7 you build with by installing D7 Studio's setup, or
> with `patch\patch.ps1` from an elevated PowerShell (see
> [patch/MODERNIZATION.md](patch/MODERNIZATION.md)).

## License

D7 Studio's own work - the IDE, its experts and this project's changes to Delphi 7's RTL and
VCL - is released under the MIT License: [LICENSE.txt](LICENSE.txt). Parts made by others keep
their own licenses, which it lists. Delphi 7 is not part of D7 Studio: it needs your own licensed
copy.
