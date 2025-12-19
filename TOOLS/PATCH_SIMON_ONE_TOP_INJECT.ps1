# PATCH_SIMON_ONE_TOP_INJECT.ps1
# Inserts a safe -RebuildExe early-exit handler right after the param(...) block.
# This avoids regex-replacing brace blocks entirely.

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$main   = Join-Path $Repo "SIMON_ONE.ps1"
$helper = Join-Path $Repo "TOOLS\SIMON_REBUILDEXE_SAFE.ps1"

if (!(Test-Path $main))   { throw "Missing: $main" }
if (!(Test-Path $helper)) { throw "Missing helper: $helper (you already created it)" }

function Parse-Ok([string]$Path) {
  $t = $null; $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$t, [ref]$e)
  return ($e.Count -eq 0)
}

# Ensure current SIMON_ONE.ps1 is parse-valid before we touch it
if (-not (Parse-Ok $main)) { throw "SIMON_ONE.ps1 is currently syntax-broken. Restore a .bak_* first." }

$raw = Get-Content $main -Raw -Encoding UTF8

# Idempotency guard: don't inject twice
if ($raw -match 'SIMON_REBUILDEXE_SAFE\.ps1' -and $raw -match 'EARLY REBUILD EXIT') {
  Write-Host "[OK] Already injected."
  exit 0
}

$inject = @"
# --- EARLY REBUILD EXIT (injected) ---
if (`$RebuildExe) {
  powershell -NoProfile -ExecutionPolicy Bypass -File "$helper" -Repo "$Repo"
  exit `$LASTEXITCODE
}
# --- END EARLY REBUILD EXIT ---
"@

# Find end of param(...) block (CmdletBinding optional)
# This matches the FIRST "param( ... )" including nested parentheses safely via a conservative approach.
$paramIdx = $raw.IndexOf("param(")
if ($paramIdx -lt 0) { throw "Could not find param( in SIMON_ONE.ps1" }

# Walk forward to find the matching closing ")"
$i = $paramIdx + 5
$depth = 1
while ($i -lt $raw.Length -and $depth -gt 0) {
  $ch = $raw[$i]
  if ($ch -eq '(') { $depth++ }
  elseif ($ch -eq ')') { $depth-- }
  $i++
}
if ($depth -ne 0) { throw "Could not locate end of param(...) block safely." }

# Insert right after param(...) and a newline
$insertPos = $i
$patched = $raw.Insert($insertPos, "`r`n`r`n" + $inject + "`r`n")

# Backup then write
$bak = $main + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $main $bak -Force
Set-Content -Path $main -Value $patched -Encoding UTF8

# Validate parse
if (-not (Parse-Ok $main)) {
  Copy-Item $bak $main -Force
  throw "Injection made file invalid; rolled back -> $bak"
}

Write-Host "[OK] Injected early -RebuildExe handler."
Write-Host "[OK] Backup: $bak"
Write-Host ""
Write-Host "Now run:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe'
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe" -RebuildExe'
