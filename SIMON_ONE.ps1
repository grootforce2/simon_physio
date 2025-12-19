#requires -Version 5.1
<#
SIMON_ONE.ps1
Single commercial-grade runner:
- Quiet runtime: SIMON_ONE.exe -Quiet  (prints only FAIL / final OK line)
- Version-stamped outputs: simon_physio_1.0.3.exe, simon_physio_windows_release_1.0.3.zip
- Quiet rebuild of this script into EXE (suppresses ps2exe banner):
    powershell -ExecutionPolicy Bypass -File .\SIMON_ONE.ps1 -RebuildExe
    or: SIMON_ONE.exe -RebuildExe
#>

[CmdletBinding()]
param(
  [switch]$Quiet,
  [switch]$RebuildExe,
  [string]$Repo,                 # optional override
  [string]$DistDir,              # optional override
  [switch]$NoAutowire,           # skip UI autowire
  [switch]$NoBuild               # skip flutter build/package
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ---------- logging ----------
$script:LogFile = $null
function Write-Log {
  param(
    [Parameter(Mandatory)][ValidateSet("OK","INFO","WARN","FAIL")][string]$Level,
    [Parameter(Mandatory)][string]$Message
  )

  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] [$Level] $Message"

  if ($script:LogFile) {
    try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 } catch {}
  }

  if ($Quiet) {
    if ($Level -in @("FAIL","OK")) { Write-Host "[$Level] $Message" }
    return
  }

  switch ($Level) {
    "OK"   { Write-Host "[$Level]  $Message" -ForegroundColor Green }
    "INFO" { Write-Host "[$Level] $Message" -ForegroundColor Cyan }
    "WARN" { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
    "FAIL" { Write-Host "[$Level] $Message" -ForegroundColor Red }
  }
}

function Fail($m) { Write-Log FAIL $m; throw $m }
function Ok($m)   { Write-Log OK   $m }
function Info($m) { Write-Log INFO $m }
function Warn($m) { Write-Log WARN $m }

# ---------- repo resolution ----------
function Resolve-RepoRoot {
  param([string]$RepoOverride)

  if ($RepoOverride -and (Test-Path (Join-Path $RepoOverride "pubspec.yaml"))) {
    return (Resolve-Path $RepoOverride).Path
  }

  # 1) if running as .ps1
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "pubspec.yaml"))) {
    return (Resolve-Path $PSScriptRoot).Path
  }

  # 2) if running as compiled EXE (PSScriptRoot may be empty)
  $envRepo = [Environment]::GetEnvironmentVariable("SIMON_REPO","User")
  if ($envRepo -and (Test-Path (Join-Path $envRepo "pubspec.yaml"))) {
    return (Resolve-Path $envRepo).Path
  }

  # 3) current directory
  $cwd = (Get-Location).Path
  if (Test-Path (Join-Path $cwd "pubspec.yaml")) { return $cwd }

  Fail "Cannot resolve repo root. Set env var once:  setx SIMON_REPO `"C:\SIMON\simon_physio`"  (then reopen PowerShell)."
}

# ---------- version parsing ----------
function Get-PubspecVersion {
  param([string]$RepoRoot)

  $pub = Join-Path $RepoRoot "pubspec.yaml"
  if (-not (Test-Path $pub)) { return "0.0.0" }

  $raw = Get-Content -Raw -Path $pub -Encoding UTF8

  # pubspec version format: 1.0.3+12 or 1.0.3
  $m = [regex]::Match($raw, "(?m)^\s*version:\s*([0-9]+(?:\.[0-9]+){2})(?:\+[0-9A-Za-z\.\-]+)?\s*$")
  if ($m.Success) { return $m.Groups[1].Value }

  return "0.0.0"
}

# ---------- quiet ps2exe rebuild ----------
function Rebuild-SelfExe {
  param(
    [Parameter(Mandatory)] [string]$RepoPath,
    [Parameter(Mandatory)] [string]$DistPath,
    [Parameter(Mandatory)] [string]$Version,
    [Parameter(Mandatory)] [string]$FinalExePath,
    [Parameter(Mandatory)] [string]$LogFile
  )

  $ErrorActionPreference = "Stop"

  $stamp    = Get-Date -Format "yyyyMMdd_HHmmss"
  $tmp      = Join-Path $DistPath ("SIMON_ONE_{0}_{1}.tmp.exe" -f $Version,$stamp)
  $fallback = Join-Path $DistPath ("SIMON_ONE_{0}_{1}.exe"     -f $Version,$stamp)
  $latest   = Join-Path $DistPath "SIMON_ONE_LATEST.exe"

  Add-Content -Path $LogFile -Value ("[INFO] SAFE REBUILD -> tmp: {0}" -f $tmp)

  Import-Module ps2exe -Force
  Invoke-ps2exe -InputFile (Join-Path $RepoPath "SIMON_ONE.ps1") -OutputFile $tmp -NoConsole -RequireAdmin:$false

  try {
    if (Test-Path $FinalExePath) {
      Remove-Item -LiteralPath $FinalExePath -Force -ErrorAction Stop
    }
    Move-Item -LiteralPath $tmp -Destination $FinalExePath -Force -ErrorAction Stop
    Copy-Item -LiteralPath $FinalExePath -Destination $latest -Force
    Add-Content -Path $LogFile -Value ("[OK]  EXE built: {0}" -f $FinalExePath)
    Add-Content -Path $LogFile -Value ("[OK]  LATEST  : {0}" -f $latest)
  }
  catch {
    if (Test-Path $tmp) { Move-Item -LiteralPath $tmp -Destination $fallback -Force }
    Copy-Item -LiteralPath $fallback -Destination $latest -Force
    Add-Content -Path $LogFile -Value ("[WARN] Final EXE locked. Built fallback: {0}" -f $fallback)
    Add-Content -Path $LogFile -Value ("[OK]   LATEST points to: {0}" -f $latest)
    throw ("Final EXE locked. Built fallback instead: {0}" -f $fallback)
  }
}

# ---------- main ----------
try {
  $repoRoot = Resolve-RepoRoot -RepoOverride $Repo
  $version = Get-PubspecVersion -RepoRoot $repoRoot

  $dist = if ($DistDir) { $DistDir } else { Join-Path $repoRoot "DIST" }
  New-Item -ItemType Directory -Force -Path $dist | Out-Null

  $script:LogFile = Join-Path $dist ("SIMON_ONE_run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  Ok ("Repo: {0}" -f $repoRoot)
  Info ("Version: {0}" -f $version)
  Info ("Log: {0}" -f $script:LogFile)

  if ($RebuildExe) {
  # SAFE rebuild wrapper EXE (temp -> swap -> fallback)
  Rebuild-SelfExe -RepoPath $Repo -DistPath $dist -Version $ver -FinalExePath $exePath -LogFile $script:LogFile
  if ($Quiet -and -not $Loud) { exit 0 } else { Write-Host "[OK] EXE rebuilt safely."; exit 0 }
}

  if (-not $NoAutowire) {
    $autowire = Join-Path $repoRoot "TOOLS\SIMON_AUTOWIRE_UI.ps1"
    if (Test-Path $autowire) {
      Info "Running AUTOWIRE UI"
      & powershell -NoProfile -ExecutionPolicy Bypass -File $autowire
      Ok "AUTOWIRE UI complete"
    } else {
      Warn ("AUTOWIRE not found (skipping): {0}" -f $autowire)
    }
  } else {
    Warn "AUTOWIRE skipped by flag"
  }

  if (-not $NoBuild) {
    $oneclick = Join-Path $repoRoot "TOOLS\SIMON_ONECLICK_ALL.ps1"
    if (Test-Path $oneclick) {
      Info "Running ONECLICK build"
      & powershell -NoProfile -ExecutionPolicy Bypass -File $oneclick
      Ok "ONECLICK build complete"
    } else {
      Fail ("ONECLICK script missing: {0}" -f $oneclick)
    }

    # Version-stamp outputs if they exist
    $builtExe = Join-Path $dist "simon_physio.exe"
    $builtZip = Join-Path $dist "simon_physio_windows_release.zip"

    if (Test-Path $builtExe) {
      $vExe = Join-Path $dist ("simon_physio_{0}.exe" -f $version)
      Copy-Item $builtExe $vExe -Force
      Ok ("Stamped EXE: {0}" -f $vExe)
    } else {
      Warn ("Build EXE not found to stamp: {0}" -f $builtExe)
    }

    if (Test-Path $builtZip) {
      $vZip = Join-Path $dist ("simon_physio_windows_release_{0}.zip" -f $version)
      Copy-Item $builtZip $vZip -Force
      Ok ("Stamped ZIP: {0}" -f $vZip)
    } else {
      Warn ("Build ZIP not found to stamp: {0}" -f $builtZip)
    }

    $logPath = Join-Path $dist "windows_build.log"
    if (Test-Path $logPath) { Ok ("LOG : {0}" -f $logPath) }
  } else {
    Warn "Build skipped by flag"
  }

  Ok "SIMON PHYSIO - ALL DONE"
  exit 0
}
catch {
  $msg = $_.Exception.Message
  Write-Log FAIL $msg
  if (-not $Quiet) {
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
  }
  exit 1
}

