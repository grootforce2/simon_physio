# SIMON_MASTER.ps1  (ONE SCRIPT to rule them all)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$ProgressPreference = "SilentlyContinue"

function OK($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function INFO($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function WARN($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m){ Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

function Resolve-RepoRoot {
  # Hard fallback (your known repo root) — makes EXE/launch context irrelevant
  $known = "C:\SIMON\simon_physio"
  if (Test-Path (Join-Path $known "pubspec.yaml")) { return $known }

  # If running as .ps1, try script root and its parent
  if ($PSScriptRoot) {
    if (Test-Path (Join-Path $PSScriptRoot "pubspec.yaml")) { return $PSScriptRoot }
    $parent = Split-Path -Parent $PSScriptRoot
    if ($parent -and (Test-Path (Join-Path $parent "pubspec.yaml"))) { return $parent }
  }

  # Try current directory
  $cwd = [Environment]::CurrentDirectory
  if ($cwd -and (Test-Path (Join-Path $cwd "pubspec.yaml"))) { return $cwd }

  # Walk upwards from current location
  $d = (Get-Location).Path
  for ($i=0; $i -lt 12; $i++) {
    if (Test-Path (Join-Path $d "pubspec.yaml")) { return $d }
    $p = Split-Path -Parent $d
    if (-not $p -or $p -eq $d) { break }
    $d = $p
  }

  FAIL "Cannot resolve repo root. pubspec.yaml not found. Expected C:\SIMON\simon_physio"
}

function Run-Step {
  param(
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$ScriptPath
  )
  if (-not (Test-Path $ScriptPath)) { FAIL "Missing: $ScriptPath" }

  INFO $Title
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
  OK "$Title complete"
}

try {
  $Repo = Resolve-RepoRoot
  [Environment]::CurrentDirectory = $Repo
  Set-Location $Repo
  OK "Repo: $Repo"

  $tools = Join-Path $Repo "TOOLS"
  $dist  = Join-Path $Repo "DIST"
  if (-not (Test-Path $tools)) { FAIL "TOOLS folder not found: $tools" }
  if (-not (Test-Path $dist))  { New-Item -ItemType Directory -Path $dist -Force | Out-Null }

  Run-Step -Title "Running script cleanup kit" -ScriptPath (Join-Path $tools "SCRIPT_CLEANUP_KIT.ps1")
  Run-Step -Title "Running AUTOWIRE UI"        -ScriptPath (Join-Path $tools "SIMON_AUTOWIRE_UI.ps1")
  Run-Step -Title "Running ONECLICK build"     -ScriptPath (Join-Path $tools "SIMON_ONECLICK_ALL.ps1")

  OK "Build/package complete"
  OK "EXE : $Repo\DIST\simon_physio.exe"
  OK "ZIP : $Repo\DIST\simon_physio_windows_release.zip"
  OK "LOG : $Repo\DIST\windows_build.log"
  OK "SIMON PHYSIO - ALL DONE"
  exit 0
}
catch {
  Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
  exit 1
}
