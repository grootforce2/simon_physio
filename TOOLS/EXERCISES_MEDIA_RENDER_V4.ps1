# ===============================
# EXERCISES MEDIA RENDER V4
# ===============================
$ErrorActionPreference = "Stop"

$root     = "C:\SIMON\simon_physio"
$flutter  = "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat"
$dartFile = "$root\lib\premium\screens\exercises_screen.dart"
$exe      = "$root\build\windows\x64\runner\Release\simon_physio.exe"

if (!(Test-Path $flutter))  { throw "Flutter not found" }
if (!(Test-Path $dartFile)) { throw "Dart file not found" }

# Backup
$bak = "$dartFile.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $dartFile $bak -Force
Write-Host "[OK] Backup: $bak" -ForegroundColor DarkGray

Write-Host "==> flutter clean" -ForegroundColor Cyan
& $flutter clean | Out-Null

Write-Host "==> flutter pub get" -ForegroundColor Cyan
& $flutter pub get | Out-Host

Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
& $flutter build windows --release | Out-Host

if (!(Test-Path $exe)) {
  throw "EXE not found after build"
}

Write-Host "[OK] Build complete" -ForegroundColor Green
Start-Process $exe
