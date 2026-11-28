# Auditing the D7 Studio patch

The patch replaces Borland's runtime packages, compiled units and `borlndmm.dll` in your Delphi 7
installation. It cannot ship Borland's files or sources, so it ships binary deltas that work only
against your own Delphi 7 Update 1 files (the patch's `README.md` explains how they are made). That
is why nobody can publish a readable diff of what the patch changes.

You can still see it yourself. Once the patch is applied, Borland's files and the patched ones are
both on your disk, and an AI coding agent that runs commands on your machine can compare them
without any source code. This document gives the setup and a ready-made prompt for that check,
followed by the report of an audit run the same way.

## The files to compare

The patch comes in two variants, `Update1` and `Update1b`, one for each Delphi 7 Update 1 build it
installs into; `patch.ps1` applies the one whose files your Delphi 7 has. The same files, the same
backup and the same prompt serve both.

| | Where |
|---|---|
| Borland's originals | `<Delphi 7>\D7Studio\Backup`: `patch.ps1` backs up every file before it replaces it. `Bin` holds those of Delphi 7's `Bin`; `System`, where Delphi 7's installer put the runtime packages into Windows' 32-bit system folder, those of `C:\Windows\SysWOW64` |
| The patched files | `<Delphi 7>\Bin`, and `C:\Windows\SysWOW64` for the files of `Backup\System` |
| Their SHA-256 | `manifest.txt` in the variant's folder of the patch (`patch\Update1` or `patch\Update1b` in the D7 Studio repository): the one whose original hashes are those of your backup |

`<Delphi 7>` is usually `C:\Program Files (x86)\Borland\Delphi7`. The packages are `rtl70.bpl`,
`vcl70.bpl`, `vclx70.bpl`, `dbrtl70.bpl`, `vcldb70.bpl` and `vclactnband70.bpl`; `borlndmm.dll` is
replaced too, and `FastMM_FullDebugMode.dll` is new. If you decide against the patch afterwards,
`patch.ps1 -Restore` puts Borland's files back.

### Without installing the patch

You can make the patched files without running `patch.ps1` or Setup: apply each delta to your own
file with Windows' delta compression (`msdelta.dll`), the same call `patch.ps1` makes. Set `$patch`
to the patch folder (the one with `Update1\`, `Update1b\` and `patch.ps1`):

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
$orig  = Join-Path $env:TEMP 'd7-audit\original'
New-Item -ItemType Directory -Force $out, $orig | Out-Null
$files = 'rtl70.bpl', 'vcl70.bpl', 'vclx70.bpl', 'dbrtl70.bpl', 'vcldb70.bpl', 'vclactnband70.bpl', 'borlndmm.dll'
# your own file: Delphi 7's Bin, else the 32-bit system folder, where its installer may have put it
foreach ($f in $files) {
  $own = if (Test-Path "$d7\Bin\$f") { "$d7\Bin\$f" } else { "$([Environment]::GetFolderPath('SystemX86'))\$f" }
  Copy-Item $own $orig
}
# the variant whose manifest names your rtl70.bpl
$hash = (Get-FileHash "$orig\rtl70.bpl" -Algorithm SHA256).Hash.ToLower()
$variant = 'Update1', 'Update1b' | Where-Object { (Get-Content "$patch\$_\manifest.txt") -match "^delta\|Bin\\rtl70\.bpl\|$hash\|" } | Select-Object -First 1
if (-not $variant) { throw 'your rtl70.bpl is in neither variant of the patch' }
foreach ($f in $files) {
  if (-not [MsDelta]::ApplyDeltaW(0, "$orig\$f", "$patch\$variant\Delta\Bin\$f.delta", "$out\$f")) { throw "$f could not be made" }
}
Copy-Item "$patch\$variant\New\Bin\FastMM_FullDebugMode.dll" $out
"variant $variant"
Get-ChildItem $out | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name }
```

The hashes it prints must match the patched column of that variant's `manifest.txt`. The two
output folders then hold the originals and the patched files: put them in the prompt in place of
the backup and the patched folders, and leave out the `.dcu` part of its step 9.

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
  only reads Delphi 7's folder and the system folder: refuse anything that asks for administrator
  rights, internet access or writing there.
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
- Borland's originals (Delphi 7 Update 1), backed up by the patch:
    C:\Program Files (x86)\Borland\Delphi7\D7Studio\Backup\Bin     (from Delphi 7's Bin)
    C:\Program Files (x86)\Borland\Delphi7\D7Studio\Backup\System  (from C:\Windows\SysWOW64; may be absent)
- The patched files: C:\Program Files (x86)\Borland\Delphi7\Bin for the files of Backup\Bin, and
  C:\Windows\SysWOW64 for the files of Backup\System.
- Pairs: rtl70.bpl, vcl70.bpl, vclx70.bpl, dbrtl70.bpl, vcldb70.bpl, vclactnband70.bpl and
  borlndmm.dll, each in whichever of the two backup folders holds it. FastMM_FullDebugMode.dll is
  new, in Delphi 7's Bin, and has no original.
- manifest.txt, the patch's list of the SHA-256 of each original and patched file. The patch has
  two variants, each with its own manifest.txt; use the one whose original hashes match the backup:
  <path to the patch>\Update1\manifest.txt or <path to the patch>\Update1b\manifest.txt

Rules
- Treat every binary as untrusted: never run or load one. Copy them into a new folder under
  %TEMP% and keep your scripts in another folder.
- Use what this machine has: Python 3 with its standard library (run it with -I), and objdump if
  it is installed; decode x86 yourself where needed. Install nothing and do not use the internet.
- Change nothing under the Delphi 7 folder or the system folder.
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
    the patch folder), and compare what you found with what it describes.

Report
Answer in plain prose, in short paragraphs that each keep to one subject: whether the patch is
malicious and how sure you are, what it changes in general terms, the behaviour that looks
alarming in a scan and why it is there, and what you could not check. No tables, lists, hashes,
addresses or counts.
```

## While it runs

- If it stops early, for example after the import tables and strings, tell it to carry on with the
  next step.
- Ask about anything it reports: "show me that routine and explain it line by line".
- When the conversation grows long, Claude Code summarizes the older part and the work goes on.

---

# Report: D7 Studio 1.0.6.1

The patch is not malicious as far as the code shows, and I am highly confident of that for the
runtime files I audited, though less so for the compiled units in Lib, which I checked only by their
strings and API names. The runtime files are the rebuilt runtime packages, borlndmm.dll and
FastMM_FullDebugMode.dll. They all match the patch's Update 1 manifest, the package copies in Delphi
7's Bin and in the 32-bit system folder are the same, and the files installed now are identical to
the copies I audited. I found no network code, no process, thread or service creation, no global
hooks, no writes to the registry or to files, nothing that touches other processes, no executable
memory, no encoded strings and no hidden payload. The code that runs by itself when a package loads,
in the Delphi IDE too, only sets up the memory manager, starts UTF-8 mode where it applies and
registers DPI hooks.

The patch compiles the units it changes or adds and leaves Borland's other units as they are: their
routines are Borland's own compiled code apart from the addresses and offsets the linker assigns,
and where they differ from Borland's own packages, that is because Borland compiled those packages
separately from the same sources, and the difference is in register use and instruction choice only.
Class layouts and all of Borland's exports are kept. What it adds is FastMM4 in place of Borland's
memory manager (borlndmm.dll included), an optional UTF-8 mode, per-monitor DPI scaling across the
VCL, the modern file, folder and task dialogs, and newer theme and Windows API bindings. It also
fixes bugs: UTF-8 encoding of characters such as emoji, a TLanguages that no longer runs code built
on the stack, a wrongly bound UxTheme function, and a clipboard that now retries while another
process holds it. MODERNIZATION.md as shipped with these files agrees with everything I found,
except that it does not mention the D7_UTF8_SHIMS environment variable that turns the shims off.

Everything a scanner will flag has a plain purpose. VirtualProtect followed by writes into import
tables is the UTF-8 shim installer, which is also linked into FastMM_FullDebugMode.dll. It acts only
when Windows reports UTF-8 as the process code page, which happens for a program built with the
patch's UTF-8 manifest, or for every program when Windows' system-wide UTF-8 option is on. It then
sends a fixed set of ANSI text, font, locale and message-loop functions, in the program and its
Delphi packages and DLLs, to wrappers that call the Unicode versions. GetProcAddress and
LoadLibrary, with the function names as plain strings, bind newer Windows functions at run time from
Windows' own DLLs, which are either already loaded or loaded by full path from the system folder, so
that older Windows still run. Shared memory named after the process ID and VirtualAlloc are standard
FastMM. The shared memory is used only when a program explicitly asks to share its memory manager
with its DLLs, and that upstream design trusts whoever creates the name; VirtualAlloc never asks for
execute rights.

Reading the program's own manifest and then showing a message box, or writing to stderr, and exiting
happens only when the manifest carries the documented "requires activeCodePage UTF-8" marker and
Windows has not switched the program to UTF-8, as on Windows older than Windows 10 version 1903.
Reading the Escape key's state, opening and reading the clipboard, subclassing combo boxes and
creating COM objects serve the task dialogs, Unicode clipboard text, Unicode edit controls and the
new file dialog. The registry reads in FastMM_FullDebugMode.dll are the standard runtime library's
lookup for language resources, linked into it. The missing version information, the linker's default
timestamp, zero checksums and build-machine temporary paths inside the package interface files come
from building outside Borland's process, not from tampering.

There are limits to what I checked. vcl70's DPI and layout work and FastMM's allocator were judged
by what they call rather than read line by line, except where they reach sensitive APIs. The
compiled units were never disassembled, including the full-debug FastMM4 unit, which by design
writes a leak log beside the program. Nothing was run. I did not audit the patch's other variant,
its sources, its installer, uninstaller and script, or the rest of what D7 Studio installs (its IDE,
expert packages, helper programs and the WinHelp permission change); these run with more privilege
than the runtime files and need their own review.
