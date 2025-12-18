# ==========================================
# ONE BUTTON PREMIUM RELEASE  GOLD MASTER
# ==========================================
$ErrorActionPreference = "Stop"
Write-Host ""
Write-Host ">>> RUNNING GOLD MASTER RELEASE <<<" -ForegroundColor Cyan
Write-Host ""

powershell -ExecutionPolicy Bypass -File ".\TOOLS\SIMON_AUTOPILOT_GOLD.ps1"

if ($LASTEXITCODE -ne 0) {
  Write-Host "RELEASE FAILED" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "RELEASE COMPLETE" -ForegroundColor Green
