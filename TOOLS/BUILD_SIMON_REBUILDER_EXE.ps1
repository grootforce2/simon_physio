# BUILD_SIMON_REBUILDER_EXE.ps1
# Compiles TOOLS\SIMON_REBUILDEXE_SAFE.ps1 into a silent EXE:
#   DIST\SIMON_REBUILDER_LATEST.exe
# No changes to SIMON_ONE.ps1 required.

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tools   = Join-Path $Repo "TOOLS"
$dist    = Join-Path $Repo "DIST"
$helper  = Join-Path $tools "SIMON_REBUILDEXE_SAFE.ps1"
$latest  = Join-Path $dist  "SIMON_REBUILDER_LATEST.exe"
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$tmpExe  = Join-Path $dist  ("SIMON_REBUILDER_{0}.tmp.exe" -f $stamp)
$log     = Join-Path $dist  ("SIMON_REBUILDER_build_{0}.log" -f $stamp)

New-Item -ItemType Directory -Force -Path $tools | Out-Null
New-Item -ItemType Directory -Force -Path $dist  | Out-Null

if (!(Test-Path $helper)) {
  throw "Missing helper: $helper`nYou already created it earlier. If not, recreate it first."
}

"[INFO] Building REBUILDER EXE $(Get-Date -Format s)" | Set-Content $log

Import-Module ps2exe -Force

# Compile to temp first (avoids locked overwrite)
Invoke-ps2exe -InputFile $helper -OutputFile $tmpExe -NoConsole -RequireAdmin:$false *>> $log

if (!(Test-Path $tmpExe)) { throw "ps2exe failed. See log: $log" }

# Swap into LATEST safely
try {
  if (Test-Path $latest) { Remove-Item -LiteralPath $latest -Force -ErrorAction Stop }
  Move-Item -LiteralPath $tmpExe -Destination $latest -Force -ErrorAction Stop
}
catch {
  # If locked, keep a timestamped exe and point user to it
  $fallback = Join-Path $dist ("SIMON_REBUILDER_{0}.exe" -f $stamp)
  Move-Item -LiteralPath $tmpExe -Destination $fallback -Force
  "[WARN] LATEST locked. Built fallback: $fallback" | Add-Content $log
  Write-Host "[WARN] LATEST locked. Use: $fallback"
  Write-Host "[INFO] Log: $log"
  exit 0
}

"[OK] Built: $latest" | Add-Content $log
Write-Host "[OK] Built: $latest"
Write-Host "[INFO] Log: $log"
