[CmdletBinding()]
param(
  [string]$SetSemVer = "",
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pub  = Join-Path $Repo "pubspec.yaml"
$dist = Join-Path $Repo "DIST"
$rebuilder = Join-Path $dist "SIMON_REBUILDER_LATEST.exe"

if (!(Test-Path $pub)) { throw "Missing pubspec.yaml" }
if (!(Test-Path $rebuilder)) { throw "Missing SIMON_REBUILDER_LATEST.exe" }

$bak = $pub + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $pub $bak -Force

$raw = Get-Content $pub -Raw

$m = [regex]::Match($raw, '(?m)^\s*version\s*:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$')
if (-not $m.Success) { throw "No valid version line found" }

$sem = if ($SetSemVer) { $SetSemVer } else { $m.Groups[1].Value }
$build = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value + 1 } else { 1 }
$new = "$sem+$build"

$raw2 = [regex]::Replace($raw, '(?m)^\s*version\s*:.*$', "version: $new", 1)
Set-Content $pub $raw2 -Encoding UTF8

Write-Host "[OK] Version bumped to $new"
Write-Host "[OK] Backup: $bak"

& $rebuilder | Out-Null
Start-Sleep -Milliseconds 200
Write-Host "[OK] Wrapper rebuilt"

dir (Join-Path $dist "SIMON_ONE*.exe") -ErrorAction SilentlyContinue |
  sort LastWriteTime -desc |
  select -first 8 Name,LastWriteTime,Length

Write-Host ""
Write-Host "Run:"
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe"'
