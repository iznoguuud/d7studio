<#
  Applies the modernized RTL/VCL to an installed Delphi 7, and takes it back. modern\build.ps1
  copies this script into modern\out\Patch, the folder it runs from, which holds the patch:
    manifest.txt        a line per file of Bin, Lib and Source (lines that begin with ";" are
                        comments):
                          delta|<path below Delphi 7's folder>|<SHA-256 of Delphi 7 Update 1's file>|<SHA-256>|<size>
                          new|<path>||<SHA-256>|<size>
    Delta\<path>.delta  what makes the file from Update 1's (Windows' msdelta.dll)
    New\<path>          a file Delphi 7 does not have
  D7 Studio's Setup runs it too: -Check before its wizard, the patch as it installs, -Restore as
  it uninstalls.

  Usage:  powershell -File patch.ps1 [-Delphi <Delphi 7 folder>] [-Check | -Restore]
    (none)    the patch. Before Delphi 7 changes, every file a delta applies to must be Update 1's
              byte for byte (the six run-time packages are named with their versions), and every
              file the patch installs is made in a temporary folder and must have the manifest's
              SHA-256. Then each file of Delphi 7 it replaces is backed up, and the files are
              copied. A copy that fails puts Delphi 7 back. Over an earlier patch, that one is
              taken back once the new files are made, then the new one is applied.
    -Check    the checks and the making only: Delphi 7 does not change.
    -Restore  takes the patch back: the backed-up files are copied back, the files the patch
              added are deleted, and so are the folders it created when they are empty.
  The installation: -Delphi; else, for the copy in <Delphi 7>\D7Studio, that Delphi 7; else
  RootDir of HKCU / HKLM \Software\Borland\Delphi\7.0. Writing there usually needs an elevated
  PowerShell (Program Files).

  What it keeps in <Delphi 7>\D7Studio - D7 Studio's Setup keeps its own files there the same way:
    Backup\<path>   each file of Delphi 7 that the patch replaced, as it was
    new-files.txt   the files Delphi 7 did not have, a path below its folder each: those the patch
                    added and those Setup added
    patch.txt       what the patch installed, a path each, and the folders it created (with a
                    trailing backslash): what -Restore takes back
    patch.ps1       a copy of this script, which takes the patch back without the patch folder
  A file is backed up only once: never when the backup has it or new-files.txt lists it, so an
  earlier patch's or Setup's files are never taken for Delphi 7's. Delphi 7's own file at a path is
  the backup's, else its folder's unless new-files.txt lists it, else - for Bin - the one in the
  32-bit system folder, where Delphi 7's installer puts the run-time packages.

  It refuses while a program runs from Delphi 7's Bin, and -Restore refuses while D7 Studio is
  installed (it runs on the modernized run-time packages: its uninstaller takes the patch back).

  Exit codes: 0 done (also: nothing to take back); 1 refused or failed, Delphi 7 not changed (or
  put back); 2 Delphi 7 could not be put back completely - the files are named, what is left is
  kept in <Delphi 7>\D7Studio, and -Restore can be run again.
  Every run that ends with 0 writes "patch.ps1: done" as its last line. A caller takes exit code 0
  as success only with that line: a powershell.exe that does not run scripts (Wine's) also ends
  with 0.
#>
param(
  [string]$Delphi = '',
  [switch]$Check,
  [switch]$Restore
)
$ErrorActionPreference = 'Stop'

# a failure that this script reports: its lines are the message, Code the exit code
class PatchStop : Exception {
  [int]$Code
  [string[]]$Lines
  PatchStop([int]$Code, [string[]]$Lines) : base(($Lines -join "`r`n")) { $this.Code = $Code; $this.Lines = $Lines }
}
function Stop-Patch([int]$Code, [string[]]$Lines) { throw [PatchStop]::new($Code, $Lines) }

# the last line of every run that ends with exit code 0
$Done = 'patch.ps1: done'

# at most ten of the problems, and how many more there are
function Limit-List([string[]]$Items) {
  if ($Items.Count -le 10) { return $Items }
  @($Items[0..9]) + ("... and {0} more" -f ($Items.Count - 10))
}

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function New-PathSet { New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase) }

# the lines of a list file written by this script or by D7 Studio's Setup (ANSI, a path each)
function Read-List([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  @([IO.File]::ReadAllLines($Path, [Text.Encoding]::Default) | Where-Object { $_ })
}
function Write-List([string]$Path, [string[]]$Items) {
  $text = ''
  if ($Items.Count) { $text = ($Items -join "`r`n") + "`r`n" }
  [IO.File]::WriteAllText($Path, $text, [Text.Encoding]::Default)
}

# the folders below Root that Path's folder needs and that do not exist, outermost first
function Get-MissingFolders([string]$Root, [string]$Rel) {
  $missing = New-Object System.Collections.Generic.List[string]
  $dir = Split-Path $Rel
  while ($dir -and -not (Test-Path -LiteralPath (Join-Path $Root $dir) -PathType Container)) {
    $missing.Insert(0, $dir + '\')
    $dir = Split-Path $dir
  }
  $missing
}

# the empty folders below Dir deleted, deepest first, and Dir itself when it is empty then
function Remove-EmptyFolders([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
  Get-ChildItem -LiteralPath $Dir -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
    if (-not (Get-ChildItem -LiteralPath $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force }
  }
  if (-not (Get-ChildItem -LiteralPath $Dir -Force)) { Remove-Item -LiteralPath $Dir -Force }
}

$patchDir = $PSScriptRoot
$sw = [Diagnostics.Stopwatch]::StartNew()
$work = $null

try {
  if ($Check -and $Restore) { Stop-Patch 1 @('-Check and -Restore exclude each other.') }

  # ---- the installation ----
  if (-not $Delphi -and (Split-Path $patchDir -Leaf) -eq 'D7Studio') {
    $parent = Split-Path $patchDir
    if (Test-Path -LiteralPath (Join-Path $parent 'Bin\dcc32.exe')) { $Delphi = $parent }
  }
  if (-not $Delphi) {
    foreach ($k in 'HKCU:\Software\Borland\Delphi\7.0', 'HKLM:\SOFTWARE\WOW6432Node\Borland\Delphi\7.0', 'HKLM:\SOFTWARE\Borland\Delphi\7.0') {
      $r = (Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue).RootDir
      if ($r) { $Delphi = $r; break }
    }
  }
  if (-not $Delphi) { Stop-Patch 1 @('No Delphi 7 installation was found (RootDir of HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE\Software\Borland\Delphi\7.0): pass -Delphi <folder>.') }
  $Delphi = $Delphi.TrimEnd('\')
  $bin = Join-Path $Delphi 'Bin'
  if (-not (Test-Path -LiteralPath (Join-Path $bin 'dcc32.exe'))) { Stop-Patch 1 @("$Delphi is not a Delphi 7 folder: it has no Bin\dcc32.exe.") }
  "Delphi 7: $Delphi"

  $studio = Join-Path $Delphi 'D7Studio'
  $backup = Join-Path $studio 'Backup'
  $newList = Join-Path $studio 'new-files.txt'
  $patchList = Join-Path $studio 'patch.txt'
  $selfCopy = Join-Path $studio 'patch.ps1'
  $systemX86 = [Environment]::GetFolderPath('SystemX86')

  # D7 Studio installed by its Setup: its uninstaller in D7Studio\ and its EXE in Bin
  $setupInstalled = (Test-Path -LiteralPath (Join-Path $bin 'D7Studio.exe')) -and
    @(Get-ChildItem -LiteralPath $studio -Filter 'unins*.exe' -File -ErrorAction SilentlyContinue).Count -gt 0
  $patched = Test-Path -LiteralPath $patchList -PathType Leaf
  if ($setupInstalled -and -not $patched) {
    Stop-Patch 1 @('D7 Studio is installed by a Setup that patched Delphi 7 itself: uninstall it (Windows'' Settings, Apps) first.')
  }
  if ($Restore -and $setupInstalled) {
    Stop-Patch 1 @('D7 Studio is installed: it runs on the modernized run-time packages. Its uninstaller (Windows'' Settings, Apps) takes the patch back.')
  }

  # the programs that run from Bin: their run-time packages could not be replaced
  function Test-Running {
    $running = @(Get-CimInstance Win32_Process -Property ExecutablePath -ErrorAction SilentlyContinue |
      Where-Object { $_.ExecutablePath -and ((Split-Path $_.ExecutablePath) -eq $bin) } |
      ForEach-Object { Split-Path $_.ExecutablePath -Leaf } | Sort-Object -Unique)
    if ($running.Count) { Stop-Patch 1 (@("These programs run from $bin`:") + $running + 'Close them, then run the patch again. Delphi 7 was not changed.') }
  }

  # write access to the folders the patch changes (Program Files needs an elevated PowerShell)
  function Test-Writable {
    foreach ($d in $Delphi, $bin, (Join-Path $Delphi 'Lib'), (Join-Path $Delphi 'Source')) {
      if (-not (Test-Path -LiteralPath $d -PathType Container)) { continue }
      $probe = Join-Path $d ('d7x-patch-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
      try { [IO.File]::WriteAllText($probe, ''); Remove-Item -LiteralPath $probe -Force }
      catch { Stop-Patch 1 @("$d cannot be written: run the patch from an elevated PowerShell (Run as administrator). Delphi 7 was not changed.") }
    }
  }

  # ---- taking the patch back ----
  # True when everything is back; else the files that are not, named in $script:restoreFailed
  function Restore-Patch {
    $items = @(Read-List $patchList)
    $files = @($items | Where-Object { -not $_.EndsWith('\') })
    $dirs = @($items | Where-Object { $_.EndsWith('\') })
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($l in (Read-List $newList)) { $added.Add($l) }
    $addedSet = New-PathSet
    foreach ($l in $added) { [void]$addedSet.Add($l) }
    $failed = New-Object System.Collections.Generic.List[string]
    $back = 0; $deleted = 0
    foreach ($rel in $files) {
      $saved = Join-Path $backup $rel
      $target = Join-Path $Delphi $rel
      try {
        if (Test-Path -LiteralPath $saved -PathType Leaf) {
          # a file the patch did not get to replace (a copy that failed) is not written: it may be in use
          $same = (Test-Path -LiteralPath $target -PathType Leaf) -and
            (Get-Item -LiteralPath $target).Length -eq (Get-Item -LiteralPath $saved).Length -and
            (Get-Sha256 $target) -eq (Get-Sha256 $saved)
          if (-not $same) { Copy-Item -LiteralPath $saved $target -Force }
          Remove-Item -LiteralPath $saved -Force
          $back++
        }
        elseif ($addedSet.Contains($rel)) {
          if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force; $deleted++ }
          [void]$addedSet.Remove($rel)
          for ($i = $added.Count - 1; $i -ge 0; $i--) { if ($added[$i] -eq $rel) { $added.RemoveAt($i) } }
        }
      }
      catch { $failed.Add($rel) }
    }
    # the folders the patch created, deepest first, when they are empty
    foreach ($d in @($dirs | Sort-Object Length -Descending)) {
      $p = Join-Path $Delphi $d.TrimEnd('\')
      if ((Test-Path -LiteralPath $p -PathType Container) -and -not (Get-ChildItem -LiteralPath $p -Force)) {
        Remove-Item -LiteralPath $p -Force
      }
    }
    Remove-EmptyFolders $backup
    if ($added.Count) { Write-List $newList $added.ToArray() }
    elseif (Test-Path -LiteralPath $newList) { Remove-Item -LiteralPath $newList -Force }
    "Taken back: $back file(s) of Delphi 7 copied back from the backup, $deleted file(s) the patch added deleted"
    $script:restoreFailed = $failed
    if ($failed.Count) {
      # what is left to take back, for a later -Restore
      Write-List $patchList (@($failed) + $dirs)
      return
    }
    Remove-Item -LiteralPath $patchList -Force
    # also when this script runs from that copy: PowerShell has read it, the file is not in use
    if (Test-Path -LiteralPath $selfCopy) { Remove-Item -LiteralPath $selfCopy -Force }
    if ((Test-Path -LiteralPath $studio) -and -not (Get-ChildItem -LiteralPath $studio -Force)) { Remove-Item -LiteralPath $studio -Force }
  }
  function Stop-NotRestored([string]$Intro) {
    Stop-Patch 2 (@($Intro) + (Limit-List @($script:restoreFailed | ForEach-Object { Join-Path $Delphi $_ })) +
      "Delphi 7's files are kept in $backup and patch.txt there lists them: close the programs that use them and run patch.ps1 -Restore again.")
  }

  if ($Restore) {
    if (-not $patched) { "Delphi 7 holds no patch of this script: nothing to take back"; $Done; exit 0 }
    Test-Running
    Test-Writable
    Restore-Patch
    if ($script:restoreFailed.Count) { Stop-NotRestored 'These files could not be put back:' }
    "Delphi 7 is as it was before the patch ({0:N1} s)" -f $sw.Elapsed.TotalSeconds
    $Done
    exit 0
  }

  # ---- the patch: manifest.txt ----
  $manifest = Join-Path $patchDir 'manifest.txt'
  if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    Stop-Patch 1 @("$patchDir holds no patch (manifest.txt): run the copy of patch.ps1 in modern\out\Patch, which modern\build.ps1 writes.")
  }
  $entries = New-Object System.Collections.Generic.List[object]
  foreach ($l in [IO.File]::ReadAllLines($manifest)) {
    if (-not $l.Trim() -or $l.StartsWith(';')) { continue }
    $f = $l.Split('|')
    if ($f.Count -ne 5 -or $f[0] -notin 'delta', 'new' -or $f[1] -notmatch '^(Bin|Lib|Source)\\' -or $f[1] -match '\.\.|:' -or
        $f[3] -notmatch '^[0-9a-f]{64}$' -or ($f[0] -eq 'delta' -and $f[2] -notmatch '^[0-9a-f]{64}$')) {
      Stop-Patch 1 @("${manifest}: not a line of the patch: $l")
    }
    $entries.Add([pscustomobject]@{ Kind = $f[0]; Rel = $f[1]; BaseHash = $f[2]; Hash = $f[3] })
  }
  $deltas = @($entries | Where-Object { $_.Kind -eq 'delta' })
  $news = @($entries | Where-Object { $_.Kind -eq 'new' })
  "Patch: $patchDir ($($deltas.Count) deltas, $($news.Count) new files)"

  $added = New-PathSet
  foreach ($l in (Read-List $newList)) { [void]$added.Add($l) }

  # Delphi 7's own file at Rel: the backup's, else its folder's unless new-files.txt lists it,
  # else - for Bin - the 32-bit system folder's; $null when there is none
  function Find-Original([string]$Rel) {
    $p = Join-Path $backup $Rel
    if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
    $p = Join-Path $Delphi $Rel
    if (-not $added.Contains($Rel) -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p }
    if ($Rel -match '^Bin\\([^\\]+)$') {
      $p = Join-Path $systemX86 $Matches[1]
      if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
    }
    $null
  }

  # ---- the checks ----
  # the six run-time packages: Delphi 7 Update 1's file versions (Update 1's readme_upd1.txt;
  # vcldb70 7.0.8.3 is the Delphi 7.1 Database supplemental's, readme_db_upd1.txt)
  $update1 = [ordered]@{
    rtl70 = @('7.0.8.1'); vcl70 = @('7.0.8.1'); vclx70 = @('7.0.4.453'); dbrtl70 = @('7.0.8.2')
    vcldb70 = @('7.0.8.1', '7.0.8.3'); vclactnband70 = @('7.0.4.453')
  }
  $problems = New-Object System.Collections.Generic.List[string]
  foreach ($name in $update1.Keys) {
    $path = Find-Original "Bin\$name.bpl"
    if (-not $path) { $problems.Add("$name.bpl: Delphi 7's is neither in $bin nor in $systemX86"); continue }
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($path)
    $version = '{0}.{1}.{2}.{3}' -f $v.FileMajorPart, $v.FileMinorPart, $v.FileBuildPart, $v.FilePrivatePart
    if ($v.CompanyName -ne 'Borland Software Corporation') { $problems.Add("${path}: no version information of Borland's") }
    elseif ($version -notin $update1[$name]) { $problems.Add("${path}: version $version, Update 1's is " + ($update1[$name] -join ' or ')) }
  }
  if ($problems.Count) {
    Stop-Patch 1 (@("The run-time packages of Delphi 7 are not Delphi 7 Update 1's:") + $problems +
      "The modernized run-time packages and units are made from Update 1's (Delphi 7.1, build 8.1) and replace only those: install Delphi 7 Update 1 first. Delphi 7 was not changed.")
  }
  # every file a delta applies to: Update 1's as Borland shipped it
  foreach ($e in $deltas) {
    $e | Add-Member Base (Find-Original $e.Rel)
    if (-not $e.Base) { $problems.Add((Join-Path $Delphi $e.Rel) + ': missing') }
    elseif ((Get-Sha256 $e.Base) -ne $e.BaseHash) { $problems.Add($e.Base) }
  }
  if ($problems.Count) {
    Stop-Patch 1 (@("These files of Delphi 7 differ from Delphi 7 Update 1's:") + (Limit-List $problems.ToArray()) +
      "The modernized files are made from Update 1's files, each as Borland shipped it, and their differences. Delphi 7 was not changed.")
  }
  # the patch's own files
  foreach ($e in $entries) {
    $src = if ($e.Kind -eq 'delta') { Join-Path $patchDir "Delta\$($e.Rel).delta" } else { Join-Path $patchDir "New\$($e.Rel)" }
    $e | Add-Member Source $src
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { $problems.Add("$src`: missing") }
    elseif ($e.Kind -eq 'new' -and (Get-Sha256 $src) -ne $e.Hash) { $problems.Add("$src`: not the file manifest.txt names") }
  }
  if ($problems.Count) { Stop-Patch 1 (@("The patch in $patchDir is not complete:") + (Limit-List $problems.ToArray()) + 'Delphi 7 was not changed.') }

  # ---- the modernized files, made in a temporary folder ----
  if (-not ('D7xPatchDelta' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class D7xPatchDelta {
  [DllImport("msdelta.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool ApplyDeltaW(long ApplyFlags, string SourceName, string DeltaName, string TargetName);
}
'@
  }
  $work = Join-Path $env:TEMP ('d7x-patch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  foreach ($e in $deltas) {
    $made = Join-Path $work $e.Rel
    New-Item -ItemType Directory -Force (Split-Path $made) | Out-Null
    if (-not [D7xPatchDelta]::ApplyDeltaW(0, $e.Base, $e.Source, $made) -or (Get-Sha256 $made) -ne $e.Hash) {
      $problems.Add((Join-Path $Delphi $e.Rel))
    }
    $e.Source = $made
  }
  if ($problems.Count) {
    Stop-Patch 1 (@("The modernized files could not be made from these files of Delphi 7 and their deltas:") + (Limit-List $problems.ToArray()) + 'Delphi 7 was not changed.')
  }
  "Made and checked: the $($deltas.Count) files of Delphi 7 Update 1's and their deltas"

  if ($Check) {
    Test-Writable
    if ($patched) { "Delphi 7 holds an earlier patch, which the patch would take back first" }
    "Check passed: Delphi 7 can be patched; it was not changed ({0:N1} s)" -f $sw.Elapsed.TotalSeconds
    $Done
    exit 0
  }

  Test-Running
  Test-Writable

  # ---- an earlier patch taken back ----
  if ($patched) {
    Restore-Patch
    if ($script:restoreFailed.Count) { Stop-NotRestored 'The earlier patch could not be taken back: these files could not be put back:' }
    $added = New-PathSet
    foreach ($l in (Read-List $newList)) { [void]$added.Add($l) }
  }

  # ---- the backup, before the first file is copied ----
  $hadStudio = Test-Path -LiteralPath $studio
  $savedNow = New-Object System.Collections.Generic.List[string]
  $addedNow = New-Object System.Collections.Generic.List[string]
  $dirsNow = New-Object System.Collections.Generic.List[string]
  $dirSet = New-PathSet
  try {
    foreach ($e in $entries) {
      foreach ($d in (Get-MissingFolders $Delphi $e.Rel)) { if ($dirSet.Add($d)) { $dirsNow.Add($d) } }
      $target = Join-Path $Delphi $e.Rel
      $saved = Join-Path $backup $e.Rel
      if ((Test-Path -LiteralPath $saved -PathType Leaf) -or $added.Contains($e.Rel)) { continue }
      if (Test-Path -LiteralPath $target -PathType Leaf) {
        New-Item -ItemType Directory -Force (Split-Path $saved) | Out-Null
        Copy-Item -LiteralPath $target $saved -Force
        $savedNow.Add($e.Rel)
      }
      else { $addedNow.Add($e.Rel) }
    }
    $allAdded = @(Read-List $newList) + $addedNow.ToArray()
    Write-List $newList $allAdded
    Write-List $patchList (@($entries | ForEach-Object Rel) + $dirsNow.ToArray())
    Copy-Item -LiteralPath $PSCommandPath $selfCopy -Force
  }
  catch {
    $why = $_.Exception.Message
    foreach ($rel in $savedNow) { Remove-Item -LiteralPath (Join-Path $backup $rel) -Force -ErrorAction SilentlyContinue }
    Remove-EmptyFolders $backup
    if ($addedNow.Count -and (Test-Path -LiteralPath $newList)) {
      $keep = @(Read-List $newList | Where-Object { $addedNow -notcontains $_ })
      if ($keep.Count) { Write-List $newList $keep } else { Remove-Item -LiteralPath $newList -Force }
    }
    Remove-Item -LiteralPath $patchList, $selfCopy -Force -ErrorAction SilentlyContinue
    if (-not $hadStudio) { Remove-EmptyFolders $studio }
    Stop-Patch 1 @("Delphi 7's files could not be backed up to $backup`: $why", 'Delphi 7 was not changed.')
  }
  "Backed up: $($savedNow.Count) file(s) of Delphi 7 to $backup; $($addedNow.Count) file(s) Delphi 7 does not have"

  # ---- the files ----
  $copied = 0
  $current = ''
  try {
    foreach ($d in $dirsNow) { $current = Join-Path $Delphi $d; New-Item -ItemType Directory -Force $current | Out-Null }
    foreach ($e in $entries) {
      $current = Join-Path $Delphi $e.Rel
      Copy-Item -LiteralPath $e.Source $current -Force
      $copied++
    }
  }
  catch {
    $why = "$current could not be written: $($_.Exception.Message)"
    Restore-Patch
    if ($script:restoreFailed.Count) { Stop-NotRestored "$why`r`nDelphi 7 could not be put back: these files are not Delphi 7's:" }
    Stop-Patch 1 @($why, 'Delphi 7 was put back as it was.')
  }
  "Patched: $copied file(s) in $Delphi\Bin, Lib and Source ({0:N1} s)" -f $sw.Elapsed.TotalSeconds
  "patch.ps1 -Restore (also $selfCopy -Restore) takes the patch back"
  $Done
  exit 0
}
catch [PatchStop] {
  $_.Exception.Lines
  exit $_.Exception.Code
}
catch {
  "The patch stopped: $($_.Exception.Message)"
  exit 1
}
finally {
  if ($work -and (Test-Path -LiteralPath $work)) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
