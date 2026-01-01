# MAKE_PORTABLE_ZIP_AND_RUN_TEST.ps1
# Builds + packages Flutter Windows correctly (exe + flutter_windows.dll + data + plugins), zips, unzips, runs.

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio",
  [string]$RunTestDir = "C:\SIMON\RUN_TEST"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }
function Wipe-Dir([string]$p) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }

cd $Repo

Write-Host "[STEP] flutter clean"
flutter clean | Out-Host

Write-Host "[STEP] flutter pub get"
flutter pub get | Out-Host

Write-Host "[STEP] flutter build windows --release"
flutter build windows --release | Out-Host

$dist = Join-Path $Repo "DIST"
Ensure-Dir $dist

# Flutter typically outputs to one of these paths depending on Flutter version/arch
$candidates = @(
  Join-Path $Repo "build\windows\x64\runner\Release",
  Join-Path $Repo "build\windows\runner\Release"
)

$releaseDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $releaseDir) {
  throw "Could not find Release folder. Checked: $($candidates -join ', ')"
}

Write-Host "[OK] Release folder: $releaseDir"

# Portable package folder
$portable = Join-Path $dist "windows_release_portable"
Wipe-Dir $portable
Ensure-Dir $portable

Write-Host "[STEP] Copy release payload into portable folder"
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $portable -Recurse -Force

# Sanity check: flutter_windows.dll must exist beside the exe
$dll = Join-Path $portable "flutter_windows.dll"
if (!(Test-Path $dll)) {
  throw "Packaging failed: flutter_windows.dll missing in $portable. Something stripped files during copy."
}

# Find the exe in the portable folder (usually *.exe)
$exe = Get-ChildItem $portable -Filter "*.exe" | Select-Object -First 1
if (-not $exe) { throw "Packaging failed: no .exe found in $portable" }

Write-Host "[OK] Portable EXE: $($exe.FullName)"
Write-Host "[OK] Found DLL    : $dll"

# Zip it
$zip = Join-Path $dist "simon_physio_windows_release_portable.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Write-Host "[STEP] Create ZIP: $zip"
Compress-Archive -Path (Join-Path $portable "*") -DestinationPath $zip -Force

Write-Host "[OK] ZIP ready: $zip"

# Run-test: unzip to clean folder and launch
Write-Host "[STEP] Clean run-test dir: $RunTestDir"
Wipe-Dir $RunTestDir
Ensure-Dir $RunTestDir

Write-Host "[STEP] Expand ZIP to run-test dir"
Expand-Archive -Path $zip -DestinationPath $RunTestDir -Force

$runExe = Get-ChildItem $RunTestDir -Filter "*.exe" | Select-Object -First 1
if (-not $runExe) { throw "Run-test failed: no exe found in $RunTestDir after unzip" }

Write-Host "[STEP] Launch: $($runExe.FullName)"
Start-Process $runExe.FullName

Write-Host ""
Write-Host "[DONE] Portable package built + launched."
Write-Host "Portable folder: $portable"
Write-Host "ZIP           : $zip"
Write-Host "Run-test dir   : $RunTestDir"
