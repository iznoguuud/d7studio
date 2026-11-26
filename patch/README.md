# How the patch is made

The patch turns an installed Delphi 7 (Update 1) into the modernized RTL/VCL. It lives in
`out\Patch\`, and `build.ps1` writes it from scratch on every run. This document explains where
each of its bytes comes from. Paths are relative to the project's `modern` folder.

**There is no decompilation step.** No part of the build decompiles, disassembles or
reverse-engineers Borland's code:

- Every modernized unit, package and DLL is **compiled from source** by Delphi 7's own compiler.
- From Borland's binaries the build reads only **metadata** that Delphi itself writes for every
  package: the package's description, its list of units and required packages, and its load
  address. It reads the export and import name tables only to check that the result links.
- The units that the modernization leaves alone are **linked** from Borland's compiled units in
  Delphi 7's `Lib`, exactly as when any Delphi 7 project uses them.
- The patch then records, for each modernized file, **how it differs** from the Borland file it
  replaces. This is a binary difference used as compression: on its own it is unreadable and
  useless. It works only together with Borland's original file, which the user already has.
- **No original source is deployed.** The patch carries none of Borland's source files (see
  "No original sources" below).

## What the patch contains

| Item | What it is |
|---|---|
| `Delta\<path>.delta` | For each modernized file that replaces one of Delphi 7 Update 1's: the difference that turns Borland's file into the modernized one. `<path>` is relative to Delphi 7's folder (`Bin\rtl70.bpl`, `Lib\Forms.dcu`, `Source\Vcl\Forms.pas` ...). |
| `New\<path>` | Files Delphi 7 does not have, whole: this project's new units, as sources and compiled, with the resources and DLLs built from them. None of them is part of Delphi 7. |
| `manifest.txt` | One line per file: its kind, its path, the SHA-256 of the Borland file it is made from (deltas only), its own SHA-256 and its size. |
| `patch.ps1` | Applies the patch to an installed Delphi 7 and takes it back. |
| `README.md` | This document. |
| `MODERNIZATION.md` | What the patch installs: the modernized RTL/VCL's features and what a developer should know. D7 Studio's Setup installs it into Delphi 7's `Bin`. |

**No file of Borland's is in the patch**, not even in part. A delta holds only what the
modernized file has that Borland's does not, plus the instructions for putting it together.

## No original sources

The patch deploys no original sources: none of Borland's RTL/VCL source files, changed or
unchanged, travels with it.

- **Borland's sources that the modernization changes are not deployed either.** For each of
  them (`Forms.pas`, `Classes.pas` ...) the patch carries only this project's own
  edits to it, as a delta. It carries no Borland text: the parts of the file that stay the same are
  only referred to, by their place in Borland's file. The edits are applied on the user's machine,
  to the copy of that source that the user's own Delphi 7 installed. Without that copy, the patch
  has no source to apply them to.
- **The sources that the modernization does not change** are not in the patch at all. Delphi 7's
  copies stay where they are.
- **The sources in `New\` are new units.** They are this project's own work, plus the open-source
  FastMM4 memory manager, and they are not part of Delphi 7's original sources: Borland's Delphi 7
  source tree has no file of the same name. The build enforces this: a file whose path Delphi 7
  already has can never go into `New\`. It either becomes a delta of Borland's file, or the build
  stops (step 6).

The same holds for the compiled files. Every modernized package, compiled unit and `.dcp` that
replaces one of Borland's is a delta from the user's own copy. The patch carries none of Borland's
compiled units, packages or DLLs.

## The inputs

1. **`source\`**: the modernized source files: Borland's RTL/VCL sources, changed, and new
   units.
2. **The installed Delphi 7**: its compiler (`dcc32`), its resource compiler (`brcc32`), its
   compiled units in `Lib`, and the source of `SysInit` (`Source\Rtl\Sys\SysInit.pas`), which
   `System` must be compiled with.
3. **`original\`**: Delphi 7 Update 1's own copies of the files that the build replaces, kept
   so that the deltas are always made against the same files. `update1.sha256` lists them with
   their SHA-256.

## The steps

### 1. Check the originals

Every file in `update1.sha256` must be in `original\` with exactly its listed SHA-256. A missing
file is copied from the installation first. The six runtime packages (`rtl70.bpl`, `vcl70.bpl`,
`vclx70.bpl`, `dbrtl70.bpl`, `vcldb70.bpl`, `vclactnband70.bpl`) must also carry Borland's version
information with Update 1's file versions. If any check fails, the build stops before anything is
written.

### 2. Compile the units

Delphi 7's compiler compiles `source\` twice: once without debug information (into `out\Lib`) and
once with it (into `out\Lib\Debug`). It uses the same switches as Borland's own RTL makefile, with
assertions off as in Borland's shipped units. `System` is compiled first, together with `SysInit`'s
source. The other units follow, and the units that `source\` does not change come from the
installation's `Lib`, already compiled. The resource scripts (the manifests) are compiled into
`.res` files.

### 3. Build the runtime packages

Delphi 7 does not ship the project files (`.dpk`) of its six runtime packages, so the build writes
them. A Delphi package carries two resources that describe it:

- `PACKAGEINFO`: its flags, the packages it requires and the names of the units it contains. This
  is the data Delphi's own `SysUtils.GetPackageInfo` reads at run time.
- `DESCRIPTION`: its description text.

Together with the load address in the file header, that is everything a `.dpk` declares. The build
reads these values from Borland's package in `original\Bin` and writes a `.dpk` that lists the same
units in the same order, and adds some of the new units to the `rtl` package.

The compiler then builds each package from the units compiled in step 2. Borland's compiled units
are used for the units that `source\` does not change.

Two checks follow:

- No package may take in a unit that belongs to another package.
- Every other package of the installation (the IDE's `designide70.bpl`, the `dcl*70.bpl` design
  packages and so on) must find every routine it imports from the six packages. For this check the
  build reads the names in the packages' import and export tables. It reads names only, no code.

### 4. Build the DLLs

`borlndmm.dll` (the shared memory manager, FastMM4) and `FastMM_FullDebugMode.dll` are compiled
from their project files in `source\Rtl\Sys`.

### 5. Copy the sources

`source\` is copied to `out\Source\`, so that the sources installed in Delphi 7's `Source` are the
ones the compiled units were made from.

### 6. Make the deltas and the manifest

Every file in `out\Bin`, `out\Lib` and `out\Source` is handled in one of three ways:

- **It replaces a file listed in `update1.sha256`.** Windows' delta compression (`msdelta.dll`)
  records how it differs from Borland's file in `original\`. For packages and DLLs it uses its
  executable mode, which allows for addresses that shift between two builds of a program, so that
  a routine that moved does not make every reference to it a difference. The result is a smaller
  delta, not a description of the code. The delta is then applied to Borland's file at once, and
  the result must equal the compiled file byte for byte. If it does not, the build fails.
- **It is new to Delphi 7.** It is copied whole to `New\`.
- **It would replace a Borland file that `update1.sha256` does not list.** The build stops,
  because the patch would otherwise contain a Borland file's replacement whole. With
  `-CopyOriginal`, that Borland file is taken into `original\` and the list, and the file gets a
  delta like the others.

Last, `manifest.txt` is written, and `patch.ps1`, this `README.md` and `MODERNIZATION.md` are copied next to it.

## Applying it

`patch.ps1` runs on the user's machine, and D7 Studio's installer runs the same script. Before it
changes anything, it:

- checks that the six packages are Update 1's;
- checks that each Borland file it applies a delta to has the SHA-256 the manifest names;
- applies every delta in a temporary folder and checks each result's SHA-256.

Only then does it back up the Borland files into `<Delphi 7>\D7Studio\Backup` and write the new
ones. `patch.ps1 -Restore` puts the backup back.

A Delphi 7 whose files are not exactly Update 1's is refused and left unchanged. A delta made
against one file cannot rebuild another.
