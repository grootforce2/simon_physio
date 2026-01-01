# FIX_RUN_TEST_AND_LAUNCH.ps1
# Ensures RUN_TEST contains flutter_windows.dll + data/ + plugins, then launches the EXE.

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio",
  [string]$RunTest = "C:\SIMON\RUN_TEST"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Pick-FirstExisting([string[]]$paths){ $paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1 }

# 1) Find a valid runtime source folder (portable first, then build Release)
$dist = Join-Path $Repo "DIST"

$portable = Join-Path $dist "windows_release_portable"
$release1 = Join-Path $Repo "build\windows\x64\runner\Release"
$release2 = Join-Path $Repo "build\windows\runner\Release"

$src = Pick-FirstExisting @($portable, $release1, $release2)
if (-not $src) { throw "No runtime source found. Expected $portable or a build\\windows\\...\\Release folder." }

# 2) Sanity check runtime in source
$dll = Join-Path $src "flutter_windows.dll"
if (!(Test-Path $dll)) { throw "Source folder doesn't contain flutter_windows.dll: $src" }

# 3) Ensure RUN_TEST exists and has an exe (or pull exe from source)
Ensure-Dir $RunTest

$runExe = Get-ChildItem $RunTest -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $runExe) {
  $srcExe = Get-ChildItem $src -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $srcExe) { throw "No .exe found in source: $src" }
  Copy-Item $srcExe.FullName $RunTest -Force
  $runExe = Get-ChildItem $RunTest -Filter "*.exe" | Select-Object -First 1
}

# 4) Copy required runtime items next to the exe
Copy-Item (Join-Path $src "flutter_windows.dll") $RunTest -Force

$srcData = Join-Path $src "data"
if (Test-Path $srcData) { Copy-Item $srcData $RunTest -Recurse -Force }

$srcPlugins = Join-Path $src "plugins"
if (Test-Path $srcPlugins) { Copy-Item $srcPlugins $RunTest -Recurse -Force }

# 5) Confirm runtime is present
if (!(Test-Path (Join-Path $RunTest "flutter_windows.dll"))) {
  throw "flutter_windows.dll still missing in RUN_TEST after copy. If it disappears, Defender is quarantining it."
}

Write-Host "[OK] RUN_TEST fixed."
Write-Host "[OK] Source : $src"
Write-Host "[OK] EXE    : $($runExe.FullName)"
Write-Host "[OK] DLL    : $(Join-Path $RunTest "flutter_windows.dll")"

# 6) Launch
Start-Process -FilePath $runExe.FullName -WorkingDirectory $RunTest
Write-Host "[DONE] Launched."
