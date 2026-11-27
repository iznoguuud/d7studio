<#
  Builds the demo of the modernized RTL/VCL, bin\ModernDemo.exe, with the installed Delphi 7's dcc32: the modernized RTL/VCL
  must be installed there (D7 Studio's Setup, or the patch's patch.ps1). The program is built
  with the run-time packages rtl and vcl, which Windows finds in Delphi 7's Bin through the PATH.

  Usage:  .\build.ps1 [-Run]
#>
param([switch]$Run)
$ErrorActionPreference = 'Stop'
$root = $null
foreach ($key in 'HKCU:\Software\Borland\Delphi\7.0', 'HKLM:\SOFTWARE\WOW6432Node\Borland\Delphi\7.0',
                 'HKLM:\SOFTWARE\Borland\Delphi\7.0') {
  $p = Get-ItemProperty $key -ErrorAction SilentlyContinue
  if ($p -and $p.RootDir -and (Test-Path (Join-Path $p.RootDir 'Bin\dcc32.exe'))) { $root = $p.RootDir; break }
}
if (-not $root) { throw 'no Delphi 7 (RootDir of Software\Borland\Delphi\7.0 with Bin\dcc32.exe)' }
if (-not (Test-Path (Join-Path $root 'Lib\ShellScaling.dcu'))) {
  throw "the modernized RTL/VCL is not installed in $root (its Lib has no ShellScaling.dcu)"
}
$out = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force (Join-Path $out 'dcu') | Out-Null
# dcc32 resolves the paths of the .dpr against the current folder
Push-Location $PSScriptRoot
try {
  & (Join-Path $root 'Bin\dcc32.exe') -Q -B "-E$out" "-N$out\dcu" '-LUrtl;vcl' ModernDemo.dpr
  if ($LASTEXITCODE -ne 0) { throw "dcc32 failed ($LASTEXITCODE)" }
} finally {
  Pop-Location
}
"built $(Join-Path $out 'ModernDemo.exe')"
if ($Run) { Start-Process (Join-Path $out 'ModernDemo.exe') }
