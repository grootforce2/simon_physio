# FIX_SIMON_ONE_REBUILDEXE_ONE.ps1
# One-shot repair:
#  - If SIMON_ONE.ps1 is syntax-broken, restore newest .bak_*
#  - Create TOOLS\SIMON_REBUILDEXE_SAFE.ps1 (temp -> swap -> fallback + LATEST)
#  - Patch SIMON_ONE.ps1 so -RebuildExe calls the helper (no $ver dependency)

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$main  = Join-Path $Repo "SIMON_ONE.ps1"
$tools = Join-Path $Repo "TOOLS"
$dist  = Join-Path $Repo "DIST"
$helper= Join-Path $tools "SIMON_REBUILDEXE_SAFE.ps1"

if (!(Test-Path $main)) { throw "Missing: $main" }
New-Item -ItemType Directory -Force -Path $tools | Out-Null
New-Item -ItemType Directory -Force -Path $dist  | Out-Null

function Test-ParseOk {
  param([string]$Path)
  try {
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    return $true
  } catch { return $false }
}

function Restore-LatestBackup {
  param([string]$Path)
  $dir = Split-Path $Path -Parent
  $name = Split-Path $Path -Leaf
  $baks = Get-ChildItem -Path $dir -Filter ($name + ".bak_*") -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending
  if (!$baks -or $baks.Count -eq 0) { throw "SIMON_ONE.ps1 is broken and no backups found." }

  Copy-Item $baks[0].FullName $Path -Force
  Write-Host "[OK] Restored backup -> $($baks[0].FullName)"
}

# 1) If SIMON_ONE.ps1 is currently parse-broken, restore latest backup
if (-not (Test-ParseOk $main)) {
  Write-Host "[WARN] SIMON_ONE.ps1 has syntax errors. Restoring latest backup..."
  Restore-LatestBackup $main
  if (-not (Test-ParseOk $main)) { throw "Restore failed; SIMON_ONE.ps1 still has syntax errors." }
}

# 2) Create the safe rebuild helper (overwrite ok)
@'
[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$dist = Join-Path $Repo "DIST"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$log = Join-Path $dist ("SIMON_ONE_run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"[INFO] SAFE REBUILD RUN $(Get-Date -Format s)" | Set-Content -Path $log

# version from pubspec.yaml (1.2.3+45 => 1.2.3)
$ver = "0.0.0"
$pub = Join-Path $Repo "pubspec.yaml"
if (Test-Path $pub) {
  $m = Select-String -Path $pub -Pattern '^\s*version\s*:\s*(.+)\s*$' | Select-Object -First 1
  if ($m) { $ver = ((($m.Matches[0].Groups[1].Value).Trim()) -split "\+")[0] }
}
Add-Content -Path $log -Value ("[INFO] Version: {0}" -f $ver)

$final    = Join-Path $dist ("SIMON_ONE_{0}.exe" -f $ver)
$stamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$tmp      = Join-Path $dist ("SIMON_ONE_{0}_{1}.tmp.exe" -f $ver,$stamp)
$fallback = Join-Path $dist ("SIMON_ONE_{0}_{1}.exe" -f $ver,$stamp)
$latest   = Join-Path $dist "SIMON_ONE_LATEST.exe"

Import-Module ps2exe -Force
Add-Content -Path $log -Value ("[INFO] Building tmp: {0}" -f $tmp)

Invoke-ps2exe -InputFile (Join-Path $Repo "SIMON_ONE.ps1") -OutputFile $tmp -NoConsole -RequireAdmin:$false

try {
  if (Test-Path $final) { Remove-Item -LiteralPath $final -Force -ErrorAction Stop }
  Move-Item -LiteralPath $tmp -Destination $final -Force -ErrorAction Stop
  Copy-Item -LiteralPath $final -Destination $latest -Force
  Add-Content -Path $log -Value ("[OK]  EXE built: {0}" -f $final)
  Add-Content -Path $log -Value ("[OK]  LATEST  : {0}" -f $latest)
  Write-Host "[OK] EXE rebuilt safely -> $final"
}
catch {
  if (Test-Path $tmp) { Move-Item -LiteralPath $tmp -Destination $fallback -Force }
  Copy-Item -LiteralPath $fallback -Destination $latest -Force
  Add-Content -Path $log -Value ("[WARN] Final locked. Built fallback: {0}" -f $fallback)
  Add-Content -Path $log -Value ("[OK]   LATEST points to: {0}" -f $latest)
  Write-Host "[WARN] Final locked. Built fallback -> $fallback"
}

Write-Host "[INFO] Log: $log"
exit 0
'@ | Set-Content -Encoding UTF8 $helper

Write-Host "[OK] Wrote helper -> $helper"

# 3) Patch SIMON_ONE.ps1: replace FIRST if($RebuildExe){...} block with call to helper
$raw = Get-Content $main -Raw -Encoding UTF8

$bak = $main + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $main $bak -Force

$pattern = '(?s)if\s*\(\s*\$RebuildExe\s*\)\s*\{.*?\}'
if ($raw -notmatch $pattern) {
  throw "Could not find an if(`$RebuildExe){...} block to patch in SIMON_ONE.ps1."
}

$replacement = @"
if (`$RebuildExe) {
  powershell -NoProfile -ExecutionPolicy Bypass -File "$helper" -Repo "$Repo"
  exit `$LASTEXITCODE
}
"@

$raw2 = [regex]::Replace($raw, $pattern, $replacement, 1)
Set-Content -Path $main -Value $raw2 -Encoding UTF8

if (-not (Test-ParseOk $main)) {
  # rollback if something went wrong
  Copy-Item $bak $main -Force
  throw "Patch introduced syntax errors. Rolled back to: $bak"
}

Write-Host "[OK] Patched SIMON_ONE.ps1 -RebuildExe handler. Backup -> $bak"
Write-Host ""
Write-Host "Use these commands:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe'
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe" -RebuildExe'
