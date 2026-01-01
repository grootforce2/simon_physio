# RUN_TEST_ONE.ps1 - Build Release, refresh RUN_TEST folder, launch app
param(
  [string]$Repo = "C:\SIMON\simon_physio",
  [switch]$NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Flutter {
  if (Get-Command flutter -ErrorAction SilentlyContinue) { return "flutter" }
  $puro = Join-Path $env:USERPROFILE ".puro\envs\stable\flutter\bin\flutter.bat"
  if (Test-Path $puro) { return $puro }
  throw "Flutter not found. Run: `$env:Path = `"$env:USERPROFILE\.puro\envs\stable\flutter\bin;`$env:Path`""
}

$Repo = (Resolve-Path $Repo).Path
$flutter = Get-Flutter

$release = Join-Path $Repo "build\windows\x64\runner\Release"
$runTest = "C:\SIMON\RUN_TEST"

if (-not $NoBuild) {
  Write-Host "[STEP] Build Windows Release"
  Push-Location $Repo
  try { & $flutter build windows --release } finally { Pop-Location }
}

if (!(Test-Path $release)) { throw "Release folder missing: $release" }
if (!(Test-Path (Join-Path $release "flutter_windows.dll"))) { throw "flutter_windows.dll missing in $release" }
if (!(Test-Path (Join-Path $release "data"))) { throw "data folder missing in $release" }

Write-Host "[STEP] Refresh RUN_TEST folder"
Remove-Item $runTest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $runTest | Out-Null
robocopy $release $runTest /E /NFL /NDL /NJH /NJS /NP | Out-Null

Write-Host "[OK] RUN_TEST ready:"
dir $runTest | select Name

Write-Host "[STEP] Launch"
Start-Process (Join-Path $runTest "simon_physio.exe")
Write-Host "[OK] Launched: $runTest\simon_physio.exe"
