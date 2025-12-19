# PATCH_SIMON_ONE_REBUILDEXE.ps1
# Patches SIMON_ONE.ps1 so -RebuildExe never overwrites a locked EXE.
# It injects an atomic build/swap/fallback block in the rebuild section.

[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio",
  [string]$Target = "SIMON_ONE.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$path = Join-Path $Repo $Target
if (!(Test-Path $path)) { throw "Not found: $path" }

$raw = Get-Content -Path $path -Raw -Encoding UTF8

# --- Guard: don't patch twice ---
if ($raw -match "SIMON_ONE_LATEST\.exe" -and $raw -match "Final EXE locked\. Built fallback instead") {
  Write-Host "[OK] Already patched: $path"
  exit 0
}

# --- Patch strategy ---
# Replace the line that calls Invoke-ps2exe to $exePath with a safe temp/swap/fallback block.
# We look for the most common pattern:
#   Invoke-ps2exe ... -OutputFile '$exePath' (or $exePath)
# and replace only inside the -RebuildExe flow.

$pattern = '(?s)(if\s*\(\s*\$RebuildExe\s*\)\s*\{.*?)(Invoke-ps2exe\s+.*?-OutputFile\s+\$exePath.*?;)(.*?\})'
if ($raw -notmatch $pattern) {
  # Alternate: some scripts call a function like Rebuild-SelfExe; patch inside that function.
  $pattern2 = '(?s)(function\s+Rebuild-SelfExe\b.*?\{.*?)(Invoke-ps2exe\s+.*?-OutputFile\s+\$exePath.*?;)(.*?\})'
  if ($raw -notmatch $pattern2) {
    throw "Patch point not found. Your SIMON_ONE.ps1 rebuild section doesn't match expected patterns. Open the file and search for 'Invoke-ps2exe' and '-OutputFile' then paste that rebuild function here."
  } else {
    $pattern = $pattern2
  }
}

$inject = @'
# --- SAFE REBUILD (temp -> swap -> fallback + LATEST) ---
$final   = $exePath
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$tmp     = Join-Path $dist ("SIMON_ONE_{0}_{1}.tmp.exe" -f $ver,$stamp)
$fallback= Join-Path $dist ("SIMON_ONE_{0}_{1}.exe" -f $ver,$stamp)
$latest  = Join-Path $dist "SIMON_ONE_LATEST.exe"

Import-Module ps2exe -Force
Invoke-ps2exe -InputFile "$Repo\SIMON_ONE.ps1" -OutputFile $tmp -NoConsole -RequireAdmin:$false

try {
  # Try to replace the versioned "final" if possible
  if (Test-Path $final) { Remove-Item $final -Force -ErrorAction Stop }
  Move-Item $tmp $final -Force -ErrorAction Stop
  Copy-Item $final $latest -Force
}
catch {
  # If locked, keep the timestamped build and point LATEST at it
  if (Test-Path $tmp) { Move-Item $tmp $fallback -Force }
  Copy-Item $fallback $latest -Force
  throw "Final EXE locked. Built fallback instead: $fallback"
}
# --- END SAFE REBUILD ---
'@

# Perform replacement: remove the old single Invoke-ps2exe output-to-exePath and insert our block.
$patched = [regex]::Replace(
  $raw,
  $pattern,
  { param($m) $m.Groups[1].Value + $inject + "`n" + $m.Groups[3].Value },
  1
)

# Backup then write
$bak = $path + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $path $bak -Force

Set-Content -Path $path -Value $patched -Encoding UTF8

Write-Host "[OK] Patched: $path"
Write-Host "[OK] Backup : $bak"
Write-Host ""
Write-Host "Run this to rebuild safely:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe -Loud'
Write-Host ""
Write-Host "Then use the stable launcher:"
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe" -RebuildExe'
