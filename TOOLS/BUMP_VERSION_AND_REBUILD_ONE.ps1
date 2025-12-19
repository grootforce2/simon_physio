# BUMP_BUILD_AND_REBUILD_ONE.ps1
# One-shot: auto-increment pubspec.yaml build number (+N) and rebuild SIMON_ONE wrapper via SIMON_REBUILDER_LATEST.exe

[CmdletBinding()]
param(
  # Optional: force a specific semantic version (keeps current if empty)
  [string]$SetSemVer = "",
  [string]$Repo      = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pub  = Join-Path $Repo "pubspec.yaml"
$dist = Join-Path $Repo "DIST"
$rebuilder = Join-Path $dist "SIMON_REBUILDER_LATEST.exe"

if (!(Test-Path $pub)) { throw "Missing: $pub" }
if (!(Test-Path $rebuilder)) { throw "Missing: $rebuilder (build it first with BUILD_SIMON_REBUILDER_EXE.ps1)" }

# Backup pubspec
$bak = $pub + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $pub $bak -Force

$raw = Get-Content $pub -Raw -Encoding UTF8

# Extract current version line
$match = [regex]::Match($raw, '(?m)^\s*version\s*:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$')
if (-not $match.Success) { throw "No valid 'version: X.Y.Z+N' found in pubspec.yaml" }

$currentSem = $match.Groups[1].Value
$currentBuild = 0
if ($match.Groups[2].Success) { $currentBuild = [int]$match.Groups[2].Value }

$sem = if ([string]::IsNullOrWhiteSpace($SetSemVer)) { $currentSem } else { $SetSemVer.Trim() }
if ($sem -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw "SetSemVer must be like 1.0.3 (got '$SetSemVer')" }

$newBuild = $currentBuild + 1
$newVer = "$sem+$newBuild"

# Replace only the first version line
$raw2 = [regex]::Replace($raw, '(?m)^\s*version\s*:\s*.+\s*$', "version: $newVer", 1)
Set-Content -Path $pub -Value $raw2 -Encoding UTF8

Write-Host "[OK] pubspec.yaml: $currentSem+$currentBuild  ->  $newVer"
Write-Host "[OK] Backup: $bak"

# Rebuild wrapper (silent NoConsole EXE)
Write-Host "[INFO] Rebuilding wrapper via: $rebuilder"
& $rebuilder | Out-Null
Start-Sleep -Milliseconds 300

Write-Host ""
Write-Host "[INFO] Latest SIMON_ONE executables:"
dir (Join-Path $dist "SIMON_ONE*.exe") -ErrorAction SilentlyContinue |
  sort LastWriteTime -desc |
  select -first 15 Name,LastWriteTime,Length

Write-Host ""
Write-Host "[INFO] Latest rebuild log:"
$log = (dir (Join-Path $dist "SIMON_ONE_run_*.log") -ErrorAction SilentlyContinue |
  sort LastWriteTime -desc | select -first 1).FullName
if ($log) { Write-Host $log } else { Write-Host "No SIMON_ONE_run_*.log found." }

Write-Host ""
Write-Host "Run the stable wrapper:"
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe"'
