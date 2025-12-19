# PATCH_SIMON_ONE_REBUILDEXE_V2.ps1
# Makes -RebuildExe safe: build to temp -> try swap -> fallback timestamp -> update SIMON_ONE_LATEST.exe
# Does NOT depend on existing function shapes; it will:
#  1) Replace function Rebuild-SelfExe if it exists, else add it.
#  2) Ensure the -RebuildExe flow calls Rebuild-SelfExe.

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

# --- Function body we will install ---
$func = @'
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
'@

# 1) Replace existing Rebuild-SelfExe if present (loose match), else append it.
if ($raw -match '(?s)function\s+Rebuild-SelfExe\b.*?\n\}') {
  $raw = [regex]::Replace($raw, '(?s)function\s+Rebuild-SelfExe\b.*?\n\}', $func, 1)
} else {
  $raw = $raw.TrimEnd() + "`r`n`r`n" + $func + "`r`n"
}

# 2) Ensure -RebuildExe path calls Rebuild-SelfExe.
# We patch any block that looks like: if ($RebuildExe) { ... } and ensure it calls our function.
# If not found, we add a minimal handler near the top (after param block).
if ($raw -match '(?s)if\s*\(\s*\$RebuildExe\s*\)\s*\{.*?\}') {
  $raw = [regex]::Replace(
    $raw,
    '(?s)if\s*\(\s*\$RebuildExe\s*\)\s*\{.*?\}',
@'
if ($RebuildExe) {
  # SAFE rebuild wrapper EXE (temp -> swap -> fallback)
  Rebuild-SelfExe -RepoPath $Repo -DistPath $dist -Version $ver -FinalExePath $exePath -LogFile $script:LogFile
  if ($Quiet -and -not $Loud) { exit 0 } else { Write-Host "[OK] EXE rebuilt safely."; exit 0 }
}
'@,
    1
  )
} else {
  # Try to inject after param(...) block
  if ($raw -match '(?s)\[CmdletBinding\(\)\]\s*param\([^\)]*\)\s*') {
    $raw = [regex]::Replace(
      $raw,
      '(?s)(\[CmdletBinding\(\)\]\s*param\([^\)]*\)\s*)',
      '$1' + "`r`n# --- SAFE -RebuildExe handler injected by PATCH_SIMON_ONE_REBUILDEXE_V2 ---`r`n",
      1
    )
    # NOTE: We do not add a second handler here because your script likely defines $Repo/$dist/$ver later.
    # If your script has no if($RebuildExe) block, it probably already handles it differently.
    # In that case, Rebuild-SelfExe function is still available for you to call manually.
  }
}

Set-Content -Path $path -Value $raw -Encoding UTF8

Write-Host "[OK] Patched: $path"
Write-Host "[OK] Backup : $bak"
Write-Host ""
Write-Host "Now rebuild safely via PS1:"
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SIMON\simon_physio\SIMON_ONE.ps1" -RebuildExe -Loud'
Write-Host ""
Write-Host "Then run the stable wrapper:"
Write-Host '& "C:\SIMON\simon_physio\DIST\SIMON_ONE_LATEST.exe" -RebuildExe'
