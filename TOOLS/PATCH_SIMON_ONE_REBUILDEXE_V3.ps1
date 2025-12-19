# PATCH_SIMON_ONE_REBUILDEXE_V3.ps1
# Fixes the $ver-not-set issue by injecting a self-sufficient -RebuildExe handler
# that computes version locally and builds temp->swap->fallback + LATEST.

[CmdletBinding()]
param(
  [string]$Repo   = "C:\SIMON\simon_physio",
  [string]$Target = "SIMON_ONE.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$path = Join-Path $Repo $Target
if (!(Test-Path $path)) { throw "Not found: $path" }

$raw = Get-Content -Path $path -Raw -Encoding UTF8

# Backup
$bak = $path + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $path $bak -Force

# Replace the injected RebuildExe block (the one that references $ver/$dist/$exePath directly)
# with a self-contained one that computes everything.
$oldBlockPattern = '(?s)if\s*\(\s*\$RebuildExe\s*\)\s*\{\s*# SAFE rebuild wrapper EXE.*?\}\s*'
if ($raw -notmatch $oldBlockPattern) {
  throw "Could not find the injected -RebuildExe block to replace. Restore from backup or paste around the -RebuildExe block."
}

$newBlock = @'
if ($RebuildExe) {
  # SAFE rebuild wrapper EXE (self-contained: computes version and paths here)
  $repoPath = $Repo
  if (-not $repoPath) { $repoPath = "C:\SIMON\simon_physio" }

  $distPath = Join-Path $repoPath "DIST"
  if (!(Test-Path $distPath)) { New-Item -ItemType Directory -Force -Path $distPath | Out-Null }

  $log = Join-Path $distPath ("SIMON_ONE_run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  "[INFO] SAFE REBUILD RUN $(Get-Date -Format s)" | Set-Content -Path $log

  # Compute version safely from pubspec.yaml (1.2.3+45 => 1.2.3)
  $verLocal = "0.0.0"
  $pub = Join-Path $repoPath "pubspec.yaml"
  if (Test-Path $pub) {
    $m = Select-String -Path $pub -Pattern '^\s*version\s*:\s*(.+)\s*$' | Select-Object -First 1
    if ($m) { $verLocal = (($m.Matches[0].Groups[1].Value).Trim() -split '\+')[0] }
  }
  Add-Content -Path $log -Value ("[INFO] Version: {0}" -f $verLocal)

  $finalExe = Join-Path $distPath ("SIMON_ONE_{0}.exe" -f $verLocal)
  $stamp    = Get-Date -Format "yyyyMMdd_HHmmss"
  $tmp      = Join-Path $distPath ("SIMON_ONE_{0}_{1}.tmp.exe" -f $verLocal,$stamp)
  $fallback = Join-Path $distPath ("SIMON_ONE_{0}_{1}.exe" -f $verLocal,$stamp)
  $latest   = Join-Path $distPath "SIMON_ONE_LATEST.exe"

  try {
    Import-Module ps2exe -Force
    Add-Content -Path $log -Value ("[INFO] Building tmp: {0}" -f $tmp)

    Invoke-ps2exe -InputFile (Join-Path $repoPath "SIMON_ONE.ps1") -OutputFile $tmp -NoConsole -RequireAdmin:$false

    try {
      if (Test-Path $finalExe) { Remove-Item -LiteralPath $finalExe -Force -ErrorAction Stop }
      Move-Item -LiteralPath $tmp -Destination $finalExe -Force -ErrorAction Stop
      Copy-Item -LiteralPath $finalExe -Destination $latest -Force
      Add-Content -Path $log -Value ("[OK]  EXE built: {0}" -f $finalExe)
      Add-Content -Path $log -Value ("[OK]  LATEST  : {0}" -f $latest)
      Write-Host "[OK] EXE rebuilt safely -> $finalExe"
      exit 0
    }
    catch {
      if (Test-Path $tmp) { Move-Item -LiteralPath $tmp -Destination $fallback -Force }
      Copy-Item -LiteralPath $fallback -Destination $latest -Force
      Add-Content -Path $log -Value ("[WARN] Final EXE locked. Built fallback: {0}" -f $fallback)
      Add-Content -Path $log -Value ("[OK]   LATEST points to: {0}" -f $latest)
      Write-Host "[WARN] Final EXE locked. Built fallback -> $fallback"
      exit 0
    }
  }
  catch {
    Add-Content -Path $log -Value ("[FAIL] {0}" -f $_.Exception.Message)
    Write-Host "[FAIL] $($_.Exception.Message)"
    Write-Host "[INFO] Log: $log"
    exit 1
  }
}
'@

$patched = [regex]::Replace($raw, $oldBlockPattern, $newBlock + "`r`n", 1)
Set-Content -Path $path -Value $patched -Encoding UTF8

Write-Host "[OK] Patched (V3): $path"
Write-Host "[OK] Backup      : $bak"
Write-Host ""
Write-Host "Run:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe'
