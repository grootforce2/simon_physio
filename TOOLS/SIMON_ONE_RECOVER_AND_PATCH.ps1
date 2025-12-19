# SIMON_ONE_RECOVER_AND_PATCH.ps1
# Recover SIMON_ONE.ps1 from newest parse-valid backup, then patch -RebuildExe to use safe helper.

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

function Parse-Ok([string]$Path) {
  try {
    $t = $null; $e = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$t, [ref]$e)
    return ($e.Count -eq 0)
  } catch { return $false }
}

function Restore-NewestGoodBackup([string]$Path) {
  $dir  = Split-Path $Path -Parent
  $name = Split-Path $Path -Leaf
  $baks = Get-ChildItem -Path $dir -Filter ($name + ".bak_*") -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending

  if (!$baks -or $baks.Count -eq 0) { throw "No backups found matching $name.bak_*" }

  foreach ($b in $baks) {
    if (Parse-Ok $b.FullName) {
      Copy-Item $b.FullName $Path -Force
      Write-Host "[OK] Restored parse-valid backup -> $($b.FullName)"
      return
    } else {
      Write-Host "[WARN] Skipping broken backup -> $($b.FullName)"
    }
  }

  throw "All backups are parse-broken. Need a clean SIMON_ONE.ps1 source."
}

# 1) Ensure SIMON_ONE.ps1 is parse-valid; if not, restore newest good backup.
if (-not (Parse-Ok $main)) {
  Write-Host "[WARN] SIMON_ONE.ps1 is currently syntax-broken. Recovering..."
  Restore-NewestGoodBackup $main
}
if (-not (Parse-Ok $main)) { throw "Recovery failed; SIMON_ONE.ps1 still syntax-broken." }

# 2) Write helper script (safe rebuild: temp->swap->fallback + LATEST)
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

Write-Host "[OK] Helper written -> $helper"

# 3) Patch SIMON_ONE.ps1: replace FIRST if($RebuildExe){...} with call to helper.
$raw = Get-Content $main -Raw -Encoding UTF8
$pattern = '(?s)if\s*\(\s*\$RebuildExe\s*\)\s*\{.*?\}'

if ($raw -notmatch $pattern) {
  throw "Could not find if(`$RebuildExe){...} block to patch in SIMON_ONE.ps1."
}

$bak = $main + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $main $bak -Force

$replacement = @"
if (`$RebuildExe) {
  powershell -NoProfile -ExecutionPolicy Bypass -File "$helper" -Repo "$Repo"
  exit `$LASTEXITCODE
}
"@

$raw2 = [regex]::Replace($raw, $pattern, $replacement, 1)
Set-Content -Path $main -Value $raw2 -Encoding UTF8

if (-not (Parse-Ok $main)) {
  Copy-Item $bak $main -Force
  throw "Patch made SIMON_ONE.ps1 invalid. Rolled back -> $bak"
}

Write-Host "[OK] Patched SIMON_ONE.ps1 -RebuildExe handler. Backup -> $bak"
Write-Host ""
Write-Host "Now run:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe'
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\TOOLS\SIMON_REBUILDEXE_SAFE.ps1"'
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe" -RebuildExe'
