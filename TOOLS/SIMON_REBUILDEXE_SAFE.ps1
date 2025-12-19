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
