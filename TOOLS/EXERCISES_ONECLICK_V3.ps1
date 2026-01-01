# ==========================================================
# EXERCISES ONE-CLICK V3
# Build + Run (Windows)
# ==========================================================

$ErrorActionPreference = "Stop"

$root     = "C:\SIMON\simon_physio"
$flutter  = "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat"
$dartFile = "$root\lib\premium\screens\exercises_screen.dart"
$exe      = "$root\build\windows\x64\runner\Release\simon_physio.exe"

Write-Host "==> EXERCISES ONE-CLICK V3" -ForegroundColor Cyan
Write-Host "Root: $root"

# -------------------------
# 1) Sanity checks
# -------------------------
if (!(Test-Path $flutter)) { throw "Flutter not found: $flutter" }
if (!(Test-Path $dartFile)) { throw "Exercises screen not found" }

# -------------------------
# 2) Backup Dart
# -------------------------
$bak = "$dartFile.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $dartFile $bak -Force
Write-Host "[OK] Backup created:" $bak -ForegroundColor DarkGray

# -------------------------
# 3) Clean + deps
# -------------------------
Push-Location $root

Write-Host "==> flutter clean" -ForegroundColor Cyan
& $flutter clean | Out-Null

Write-Host "==> flutter pub get" -ForegroundColor Cyan
& $flutter pub get | Out-Host

# -------------------------
# 4) Build
# -------------------------
Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
& $flutter build windows --release | Out-Host

if (!(Test-Path $exe)) {
  throw "Build finished but EXE not found"
}

Write-Host "[OK] BUILD SUCCESS" -ForegroundColor Green
Write-Host "EXE: $exe" -ForegroundColor Green

Pop-Location

# -------------------------
# 5) Run
# -------------------------
Write-Host "==> Launching app..." -ForegroundColor Cyan
Start-Process $exe
