# Auditing the D7 Studio patch

The patch replaces Borland's runtime packages, compiled units and `borlndmm.dll` in your Delphi 7
installation. It cannot ship Borland's files or sources, so it ships binary deltas that work only
against your own Delphi 7 Update 1 files (the patch's `README.md` explains how they are made). That
is why nobody can publish a readable diff of what the patch changes.

You can still see it yourself. Once the patch is applied, Borland's files and the patched ones are
both on your disk, and an AI coding agent that runs commands on your machine can compare them
without any source code. This document gives the setup and a ready-made prompt for that check,
followed by the report of the audit that was run the same way.

## The files to compare

| | Where |
|---|---|
| Borland's originals | `<Delphi 7>\D7Studio\Backup\Bin`: `patch.ps1` backs up every file before it replaces it |
| The patched files | `<Delphi 7>\Bin` |
| Their SHA-256 | `manifest.txt` in the `patch` folder of the D7 Studio repository |

`<Delphi 7>` is usually `C:\Program Files (x86)\Borland\Delphi7`. The packages are `rtl70.bpl`,
`vcl70.bpl`, `vclx70.bpl`, `dbrtl70.bpl`, `vcldb70.bpl` and `vclactnband70.bpl`; `borlndmm.dll` is
replaced too, and `FastMM_FullDebugMode.dll` is new. If you decide against the patch afterwards,
`patch.ps1 -Restore` puts Borland's files back.

### Without installing the patch

You can make the patched files without running `patch.ps1` or Setup: apply each delta to your own
file with Windows' delta compression (`msdelta.dll`), the same call `patch.ps1` makes. Set `$patch`
to the `patch` folder (the one with `Delta\`, `New\` and `manifest.txt`):

```powershell
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class MsDelta {
  [DllImport("msdelta.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool ApplyDeltaW(long ApplyFlags, string SourceName, string DeltaName, string TargetName);
}
'@
$d7    = 'C:\Program Files (x86)\Borland\Delphi7'
$patch = 'C:\path\to\patch'
$out   = Join-Path $env:TEMP 'd7-audit\patched'
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($f in 'rtl70.bpl', 'vcl70.bpl', 'vclx70.bpl', 'dbrtl70.bpl', 'vcldb70.bpl', 'vclactnband70.bpl', 'borlndmm.dll') {
  if (-not [MsDelta]::ApplyDeltaW(0, "$d7\Bin\$f", "$patch\Delta\Bin\$f.delta", "$out\$f")) { throw "$f could not be made" }
}
Copy-Item "$patch\New\Bin\FastMM_FullDebugMode.dll" $out
Get-ChildItem $out | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name }
```

The hashes it prints must match the patched column of `manifest.txt`. Your `Bin` then holds the
originals and the output folder the patched files: use these two folders in the prompt, and leave
out the `.dcu` part of its step 9.

## Model and effort

Run the audit in Claude Code (command line, desktop app or IDE extension) with:

- **Model: Claude Opus 5.5.** Choose it with `/model`.
- **Effort: max.** Set it with `/effort max`. It holds for the current session, so set it again in
  a new one.

The audit is long, well over a hundred commands, and its point is the code-level work in steps 5
to 8: a capability hidden behind encoded strings or computed calls shows neither in the import
table nor in the strings, only in the code. That is the work max effort is for.

## Before you start

- Start Claude Code in a new session, in a new, empty folder (for example `%TEMP%\d7-audit`).
- Python 3 is needed; its standard library is enough. `objdump` from MinGW or binutils helps but is
  optional: the agent can decode the x86 code itself.
- Approve the PowerShell and Python commands as they come, or allow them for the session. The audit
  only reads Delphi 7's folder: refuse anything that asks for administrator rights, internet access
  or writing there.
- What the agent reads, such as disassembly listings and strings, goes to the model as part of the
  conversation.
- Don't paste the report below into the prompt. Let the agent reach its own conclusion, then compare.

## The prompt

Paste this as the first message. Adjust the paths if your Delphi 7 is elsewhere, or if you made the
patched files yourself.

```text
Audit a third-party patch for Borland Delphi 7: find out exactly what it changes in Borland's
runtime files and whether anything in it is malicious. Work only from the binaries. Do not read
the patch's source code (.pas, .inc, .dpr) or its documentation before step 10.

Files
- Borland's originals (Delphi 7 Update 1): C:\Program Files (x86)\Borland\Delphi7\D7Studio\Backup\Bin
- The patched files:                       C:\Program Files (x86)\Borland\Delphi7\Bin
- Pairs: rtl70.bpl, vcl70.bpl, vclx70.bpl, dbrtl70.bpl, vcldb70.bpl, vclactnband70.bpl and
  borlndmm.dll. FastMM_FullDebugMode.dll is new and has no original.
- manifest.txt, the patch's list of the SHA-256 of each original and patched file:
  <path to manifest.txt>

Rules
- Treat every binary as untrusted: never run or load one. Copy them into a new folder under
  %TEMP% and keep your scripts in another folder.
- Use what this machine has: Python 3 with its standard library (run it with -I), and objdump if
  it is installed; decode x86 yourself where needed. Install nothing and do not use the internet.
- Change nothing under the Delphi 7 folder.
- Check every conclusion in the code. Import tables and strings are where you start, not where
  you stop: a capability behind encoded strings or computed calls shows only in the code.
- If you cannot explain a difference, say so plainly instead of explaining it away.

Steps
1. Hash every file and compare with manifest.txt. Report each original's version information.
2. Compare the PE structure of each pair: linker version, image base, timestamp, sections
   (flags, sizes, entropy), data directories, TLS callbacks, data after the last section,
   signatures, and the code at the entry point.
3. Diff the imports and the exports. Diff the resources: PACKAGEINFO (contained units, required
   packages), version information, string tables, forms, bitmaps. Look for added resources,
   embedded executables and high-entropy data.
4. Diff the strings, ASCII and UTF-16. Then find the Windows API names that appear as strings
   (functions looked up at run time with GetProcAddress) by matching them against the export
   names of the DLLs in C:\Windows\SysWOW64.
5. Compare the code function by function. Split each CODE section at the exported symbols and
   normalize before comparing: replace each relocated absolute address (from the .reloc table)
   and each rel32 call or jump target with the symbol it points to, resolve unnamed pointer cells
   by their content, and name unexported targets by a hash of their bytes. Decode each block from
   its own start address: a linear disassembly loses step in Delphi's embedded data (RTTI, VMTs,
   string literals, case jump tables). Recompiling shifts field and threadvar offsets, renumbers
   resourcestring IDs and moves globals and import thunks; verify each such case rather than
   assume it. Every unit must end up identical, or with each difference explained.
6. For every Windows API, imported or looked up at run time, list the functions that call it in
   the original and in the patched file. Read every new caller of anything sensitive: network,
   process or thread creation, code injection, VirtualProtect or VirtualAlloc, LoadLibrary or
   GetProcAddress, registry or file writes, services, hooks, keyboard and clipboard access.
7. Compare every unit initialization and finalization routine and the DLL entry point, and read
   every new or changed one in full: this code runs by itself in every program that loads the
   package, the Delphi IDE included.
8. Read every new unit, and every added routine that touches a sensitive API, instruction by
   instruction. Say what it does and under which conditions it runs.
9. Do the same for borlndmm.dll and FastMM_FullDebugMode.dll. Then check the compiled units more
   lightly: compare the Windows API names and the strings of each .dcu in Delphi 7's Lib and
   Lib\Debug with the one in D7Studio\Backup\Lib. They are linked into programs built without
   runtime packages.
10. Only now read the patch's MODERNIZATION.md (Setup puts it in Delphi 7's Bin; it is also in
    the patch folder), and list every behaviour you found that it does not describe.

Report
- The verdict first: malicious or not, and how sure you are.
- Per file: what changed.
- Every sensitive capability: where it is, what triggers it, what it can do.
- The evidence for each finding: function names and addresses.
- What you did not check, or checked only in part.
```

## While it runs

- If it stops early, for example after the import tables and strings, tell it to carry on with the
  next step.
- Ask about anything it reports: "show me that routine and explain it line by line".
- When the conversation grows long, Claude Code summarizes the older part and the work goes on.

---

# Report

The audit of the patch published with D7 Studio 1.0.4.0, run on 2026-11-27 with Claude Opus 5.5 at
max effort in Claude Code. The prompt above was run unattended (`claude -p`) in a new, empty folder,
with three notes added for that: do all ten steps without stopping to ask, open no document of the
patch except `MODERNIZATION.md` at step 10 (so not this one, with the earlier report), and write the
report to a file. It worked only from the binaries: nothing was executed, and the patch's sources
were only hashed, never read. `manifest.txt` served only to locate and check the files.

It replaces the report on the patch of D7 Studio 1.0.1.0. Of the eight binaries, only `vcl70.bpl`
has changed since then; all eight were audited again from the start.

## Files

The report covers exactly these files. A later patch has other hashes and needs a new check.

```text
File                      Borland's original (SHA-256)                                       Patched (SHA-256)
rtl70.bpl                 285673056d5f81da1799e24dc4cb6fdbc066f3f61abc2afedc569e30347c36bf   85f07cca82266ed80397a8ac8504af79ed65330ce7a64dbfe9a95a44b2fd8d12
vcl70.bpl                 32edbfd022475a305fde6086d301b161ad0e370f20c27b43e3e20a986d896097   c2d53a7f29c449cefbc4ff24f1a1815b76381ad54969fb774c16985e749e18e7
vclx70.bpl                140f5d7b60a2f655d0d4548e7cbe2d190bafda427986093814e0bcb33cc169b3   0f7a3e04aeda2c0d5b5c083f3e3974e7074b1901f9e210a2943aa143204ccf6a
dbrtl70.bpl               c77741746d9feacdb28d54ffaab0d195c21ba425f700779b3f1998e74e1b6876   84d5e6055a22fecdc9260b6cf411ef5a02e50bc27b821bb341fda46bb9c8dca6
vcldb70.bpl               ab09ac1b7ef02a919947462adacfbe08ea370211eaedb6a915759b6750db3e2a   ee4b5a18f31b4fb61c217be1670bd7b12433d6419b0b6e0b39cfbfe0b4a6b87f
vclactnband70.bpl         6ff6eb8aa346e6b0d97856521399e0f80e4cf074489c823e05bc2edc698adf91   bbe3747549a5f1ab1ca558c1f9f6bcb16c0efb26ed19948401ef3efb3c18ec93
borlndmm.dll              8af7c734698d544bff3985c973acd680cc4eeca4dc69b3b87f6a177e3aae3abe   1d2687e0121fb379db3a5f0008936454315ce8c404da9349f8938e44343eb188
FastMM_FullDebugMode.dll  (new)                                                              e1cf1e0bab0eafb776f033074f86ca2b8135d13df1253a4aab5e1357dd774bf0
```

All 180 files of `manifest.txt` (`Bin`, `Lib`, `Lib\Debug`, `Source`) were found installed with the
manifest's SHA-256 and size, and the 127 originals in the backup with Borland's. The originals carry
Borland's version information of Delphi 7 Update 1: 7.0.8.1 (`rtl70`, `vcl70`, `vcldb70`), 7.0.8.2
(`dbrtl70`) and 7.0.4.453 (`vclx70`, `vclactnband70`, `borlndmm.dll`).

## Verdict

Not malicious: high confidence for the six packages and the two DLLs, medium-high for the compiled
units (`.dcu`, `.dcp`), which were compared by their strings and API names only. Every code
difference was read or explained, and each belongs to the modernization: FastMM4 as the memory
manager, a UTF-8 mode, per-monitor DPI scaling, newer Windows dialogs and theming, and fixes. Nothing
in the patch adds network access, starts processes or threads, touches another process, writes to
the registry or to files (except one error message on the console), installs hooks or makes itself
persistent. There are no encoded strings, embedded programs or high-entropy data.

## Structure

- Same linker (2.25), image bases, machine flags and section names and flags as the originals; only
  section sizes changed. No section added or removed, none both writable and executable.
- The packages keep Borland's fixed link timestamp. `borlndmm.dll` had a real timestamp and checksum,
  and now has the linker's constant and checksum 0, as Delphi 7's compiler writes them.
- No TLS callbacks, no debug or load-configuration directory, no delay imports, no data after the last
  section, no signature, in any original or patched file.
- The packages' entry points are identical apart from the size of the thread-local block (`rtl70`
  0x14 → 0x90, `vcl70` 0x30 → 0x38: the new thread variables).
- No resource added. Forms, bitmaps, cursors, the dialog template and `vcl70`'s manifest are
  byte-identical. The string tables hold the same texts, partly renumbered, plus one new VCL string
  ("Open as &read-only"). The Windows version resource is gone from every replaced file, and
  `borlndmm.dll`'s `DVCLAL` resource is the Professional edition's instead of the Enterprise's.

## What changed

| File | Size (bytes) | Change |
|---|---|---|
| `rtl70.bpl` | 784,896 → 810,496 | FastMM4 replaces Borland's heap in `System` (new: `GetMemoryManagerState`, `GetMemoryMap`, `ReportMemoryLeaksOnShutdown`, `ShareMemoryManager` ...). New units `Utf8Mode`, `WindowsEx`, `DwmApi` and `ShellScaling`. UTF-8 conversion in `System` handles surrogate pairs; `SysUtils` starts UTF-8 mode before it reads the locale, and `TLanguages` no longer builds a call stub on the stack; `Classes` reads legacy and UTF-16 text. 31 newer `UxTheme` functions, bound at run time from the system folder, and `GetThemeBackgroundExtent` bound to its own name; four `ActiveX` bindings to functions Windows does not export became local stubs. 66 exports added, none removed; no new DLL. |
| `vcl70.bpl` | 1,384,448 → 1,426,432 | Per-monitor DPI scaling (`Controls`, `Forms`, `Graphics`, `ImgList` with image sets for several sizes, `Buttons`, `StdCtrls`, `ComCtrls`, `ExtCtrls`, `Grids`, `Menus`, `Themes`), task dialogs, the newer open, save and folder dialogs, `MainFormOnTaskbar`, Explorer-style list and tree views, Unicode clipboard text and edit / combo box windows. 36 exports added, none removed; one new DLL, `msimg32.dll` (`AlphaBlend`). |
| `vclx70.bpl`, `vcldb70.bpl`, `vclactnband70.bpl` | unchanged | DPI scaling in drawing and sizing code (`CheckLst`, `FileCtrl`, `Outline`, `Tabs`, `DBCtrls`, `DBGrids`, `ActnMan`); `FileCtrl.SelectDirectory` uses the newer folder dialog. Exports unchanged. |
| `dbrtl70.bpl` | 259,584 → 258,560 | Code identical; only its unit start-up list changed, which now includes `Utf8Mode`. |
| `borlndmm.dll` | 22,528 → 20,992 | FastMM4 memory manager with Borland's exports, plus `SysAllocMem`, `SysRegisterExpectedMemoryLeak` and `SysUnregisterExpectedMemoryLeak`. 157 of its 172 routines are the same code as in `rtl70` or Borland's DLL; the other 15 were read. |
| `FastMM_FullDebugMode.dll` | new, 58,880 | FastMM4's stack-trace helper: `GetRawStackTrace`, `GetFrameBasedStackTrace`, `LogStackTrace`. It also links `System`, `SysUtils` and `Utf8Mode`, which start when it loads (below). |

## Behaviour worth knowing

These look alarming in a scan. The code shows why they are there and when they run.

- **Import hooking in `Utf8Mode` (`VirtualProtect`).** Only when the process runs with the UTF-8
  code page (`GetACP` returns 65001: a manifest asks for it on Windows 10 1903 or later, or Windows'
  system-wide UTF-8 option is on, which then applies to every program that loads `rtl70`, Delphi 7's
  IDE included). It patches only import-table slots that hold the real address of 25 functions: the
  ANSI text drawing, font, locale, message-loop and default window procedure functions of `gdi32`,
  `user32` and `kernel32`. Only the program's EXE and the Delphi modules of the process are patched:
  those loaded (System's `LibModuleList`) and those loaded later (`SysUtils.LoadPackage`). Each slot
  is made writable with `VirtualProtect`, gets the address of a replacement that converts the text
  and calls the W function, and gets its protection back. No code bytes are changed. The font
  replacements create MS Sans Serif as Microsoft Sans Serif; typed characters reach ANSI windows as
  UTF-8 bytes. The environment variable `D7_UTF8_SHIMS=0` turns the hooking off.
- **`MessageBox` and `ExitProcess` in `Utf8Mode`.** Only when the EXE's manifest contains
  `requires activeCodePage UTF-8` and Windows does not give the process the UTF-8 code page: it
  shows "This program requires Windows 10 version 1903 or later." (a console program writes it to
  stderr) and ends with exit code 1150. The manifests the patch ships (`ModernMan`, `ModernManUtf8`)
  do not contain that text.
- **`Utf8Mode` in `FastMM_FullDebugMode.dll`.** The DLL carries its own copy of `System`, `SysUtils`
  and `Utf8Mode`, so loading it runs the same start-up: the manifest check of the host EXE, and in a
  UTF-8 process the import hooking of its own and the host EXE's import tables. The DLL is loaded
  only by a program that uses FastMM4's FullDebugMode.
- **A named file mapping in `System`.** `Local\FastMM_PID_<process id>`: FastMM4's way of sharing
  one memory manager between the modules of a process, used only when a program calls
  `ShareMemoryManager` or `AttemptToUseSharedMemoryManager`; no package does.
- **`LoadLibrary` and `GetProcAddress`.** `uxtheme.dll` and `shcore.dll` are loaded with their full
  path from the system folder, `comctl32.dll` and `shell32.dll` by name. Functions of newer Windows
  versions (DPI, theming, task dialogs, shell items) are looked up at run time by literal names,
  because Delphi 7 cannot declare them.
- **The clipboard.** Read and written only by `TClipboard`'s own methods: opening with retries, and
  Unicode text in UTF-8 mode.
- **Code that runs at load.** `System` sets up FastMM4, `SysUtils` and `Utf8Mode` start UTF-8 mode
  (above), and the VCL units register DPI handlers for their controls. `Forms` now also closes its
  hint event handle at the end. Nothing else is new at load.

## Not found

Nowhere in the six packages and the two DLLs, functions looked up by name at run time included: new
network access, new use of process or thread creation, code injection into other processes, registry
writes, file writes (except the stderr message above), keyboard hooks, service control, screen
capture, URLs, IP addresses, encrypted or encoded payloads. Borland's own uses of such functions
(the sockets of `ScktComp`, `TDownLoadURL`'s `URLDownloadToFileA`, the hint thread, the registry
units) are unchanged at the routine level.

## How it was checked

1. The hashes against `manifest.txt`; the PE structure, entry points, imports, exports and resources
   of each pair; a search for embedded programs and high-entropy data.
2. The strings, ASCII and UTF-16, and the Windows API names written as strings, matched against the
   export names of the system DLLs.
3. Every function of every package, decoded from its own start and compared after normalizing
   relocated addresses, call targets and data references. Of 7,179 / 7,458 blocks (original /
   patched) in `rtl70`, 6,996 are identical, 45 changed and 417 added (146 of them import thunks);
   `vcl70` 11,449 / 11,740, 11,252 identical, 176 changed, 312 added; `vclx70` 1,757 identical,
   35 changed; `dbrtl70` 2,436 identical, the other 2 its start-up list; `vcldb70` 2,230 identical,
   13 changed; `vclactnband70` 2,071 identical, 9 changed. Renumbered resourcestrings (276 in `rtl70`,
   51 in `vcl70`, each resolving to the same text), thread variables (`rtl70` +124 bytes, `vcl70` +8),
   and moved globals and import thunks were each verified. Instance sizes and virtual method counts
   are unchanged for every class; only the VCL's private `TButtonGlyph` grew by 8 bytes.
4. For every Windows API, the functions that call it before and after; every new caller of a
   sensitive API was read.
5. Every unit initialization and finalization routine and every entry point compared; every new or
   changed one read.
6. `Utf8Mode` (all of it), FastMM4's start-up, sharing and leak code, the `UxTheme` loader, the
   VCL's run-time binding, clipboard, COM and GDI routines, and the two DLLs' own code read
   instruction by instruction.
7. `borlndmm.dll` and `FastMM_FullDebugMode.dll`: imports, exports, strings and their own code. The
   new `borlndmm.dll` imports a subset of the original's functions plus `GetModuleFileNameA`, `Sleep`
   and `VirtualQuery`.
8. The 82 replaced compiled files of `Lib` and `Lib\Debug` (76 `.dcu`, 6 `.dcp`) and the 28 new
   units: Windows API names and strings, unit by unit. The additions are declarations in the API units
   (`Windows`, `ShellAPI`, `ShlObj`, `WinSvc`, `ActiveX` ...), FastMM4's functions in `System`, the
   UTF-8 and DPI work in the VCL units, and the new API units; nothing was flagged. `System.dcu`
   also declares `FindWindowA` and `OutputDebugStringA` for FastMM4, which `rtl70.bpl` does not use.
   The stand-alone `FastMM4` unit, used only when a program names it, has FastMM4's usual log file
   functions.
9. The findings compared with `MODERNIZATION.md`. It describes them in substance. It does not
   describe: how the hooking works (the import-table rewriting) and its full list of functions, the
   `D7_UTF8_SHIMS` switch, that `GetACP` alone switches UTF-8 mode on, `Utf8Mode` in
   `FastMM_FullDebugMode.dll`, FastMM4's named mapping, the new thread variables, the renumbered
   resourcestrings (a resource-only translation DLL made for Borland's `rtl70` or `vcl70` would show
   the wrong strings), the removed version resources, Borland's conditional defines missing from the
   packages' options and the changed unit order, the `ActiveX` stubs, the short (8.3) file names the
   file dialogs give for names the ANSI code page cannot hold, `TApplication.MessageBox` centring on
   the active window's monitor, and the hint event handle now closed.

## Limits

- The roughly 200 VCL functions changed for DPI scaling, and FastMM4's allocator, were checked by
  what they call and reference, not read instruction by instruction: a plain bug in them would not
  show this way, a new call to anything sensitive would.
- The `.dcu` and `.dcp` files had the lighter check only; their code was not disassembled.
- Finding the routines is partly heuristic where code is reached only through pointers; a few bytes
  could not be decoded unambiguously. Every block that differed was still resolved.
- Borland's originals were checked against the manifest and their version information, not against
  a reference outside this project.
- It is a static analysis made by an AI model, not a proof. The prompt above lets you repeat it.
