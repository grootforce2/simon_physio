# ================================
# SIMON ONE-CLICK ALL-IN-ONE BUILD (V2 + LOGS)
# ================================

$ErrorActionPreference = "Stop"

$ROOT = "C:\SIMON\simon_physio"
$TOOLS = "$ROOT\TOOLS"
$DIST = "$ROOT\DIST"
$LOG = "$DIST\windows_build.log"

$FLUTTER = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
$VSDEV = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"

Write-Host "==> SIMON PHYSIO ONE-CLICK PIPELINE (V2)" -ForegroundColor Cyan

if (!(Test-Path $ROOT)) { throw "Project folder missing: $ROOT" }
if (!(Test-Path $FLUTTER)) { throw "Flutter not found: $FLUTTER" }
if (!(Test-Path $VSDEV)) { throw "VsDevCmd not found: $VSDEV" }

New-Item -ItemType Directory -Force -Path $TOOLS | Out-Null
New-Item -ItemType Directory -Force -Path $DIST  | Out-Null
Remove-Item $LOG -Force -ErrorAction SilentlyContinue

Set-Location $ROOT

Write-Host "==> flutter clean"
cmd /c "`"$VSDEV`" -arch=x64 -host_arch=x64 && `"$FLUTTER`" clean" | Out-File -Append -Encoding utf8 $LOG
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed (see $LOG)" }

Write-Host "==> Hard wipe build/ (to avoid cmake install leftovers)"
Remove-Item -Recurse -Force "$ROOT\build" -ErrorAction SilentlyContinue

Write-Host "==> Patching theme (CardThemeData + const safety)"
$appTheme = "$ROOT\lib\core\theme\app_theme.dart"
if (Test-Path $appTheme) {
    $c = Get-Content $appTheme -Raw
    $c = $c -replace "CardTheme\(", "CardThemeData("
    $c = $c -replace "const CardThemeData", "CardThemeData"
    Set-Content -Encoding UTF8 $appTheme $c
}

Write-Host "==> flutter pub get"
cmd /c "`"$VSDEV`" -arch=x64 -host_arch=x64 && `"$FLUTTER`" pub get" | Out-File -Append -Encoding utf8 $LOG
if ($LASTEXITCODE -ne 0) { throw "pub get failed (see $LOG)" }

Write-Host "==> Building Windows Release (VERBOSE) -> $LOG"
cmd /c "`"$VSDEV`" -arch=x64 -host_arch=x64 && `"$FLUTTER`" build windows --release -v" | Out-File -Append -Encoding utf8 $LOG
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n==> BUILD FAILED. Showing last 80 log lines:" -ForegroundColor Red
    Get-Content $LOG -Tail 80
    Write-Host "`nFull log: $LOG" -ForegroundColor Yellow
    exit 1
}

$exe = "$ROOT\build\windows\x64\runner\Release\simon_physio.exe"
if (!(Test-Path $exe)) { throw "Build says success but EXE missing: $exe" }

Write-Host "==> Packaging"
Remove-Item "$DIST\simon_physio.exe" -Force -ErrorAction SilentlyContinue
Copy-Item $exe "$DIST\simon_physio.exe" -Force

$zip = "$DIST\simon_physio_windows_release.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$DIST\simon_physio.exe" -DestinationPath $zip -Force

Write-Host "==> DONE" -ForegroundColor Green
Write-Host "EXE : $DIST\simon_physio.exe"
Write-Host "ZIP : $zip"
Write-Host "LOG : $LOG"

