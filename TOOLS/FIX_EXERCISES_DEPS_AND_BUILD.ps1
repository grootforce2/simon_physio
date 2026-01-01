# FIX_EXERCISES_DEPS_AND_BUILD.ps1
# Patches pubspec.yaml deps (shared_preferences, url_launcher), then builds Windows release.
# Run:
#   powershell -ExecutionPolicy Bypass -File C:\SIMON\simon_physio\TOOLS\FIX_EXERCISES_DEPS_AND_BUILD.ps1

$ErrorActionPreference = "Stop"

$root = "C:\SIMON\simon_physio"
$pubspec = Join-Path $root "pubspec.yaml"

if (!(Test-Path $root)) { throw "Project root not found: $root" }
if (!(Test-Path $pubspec)) { throw "pubspec.yaml not found: $pubspec" }

# Prefer your Puro Flutter path, fallback to flutter in PATH
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { $flutter = "flutter" }

function Backup-File([string]$path) {
  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$path.bak_$ts"
  Copy-Item $path $bak -Force
  Write-Host "[OK] Backup: $bak"
}

function Ensure-Dependency([string]$yaml, [string]$depName, [string]$depVersion) {
  # If already present anywhere as a dependency entry, do nothing.
  if ($yaml -match "(?m)^\s{2}$([regex]::Escape($depName))\s*:") { return $yaml }

  # Find dependencies block start
  $m = [regex]::Match($yaml, "(?m)^dependencies:\s*$")
  if (!$m.Success) { throw "No 'dependencies:' block found in pubspec.yaml" }

  $insertLine = "  ${depName}: ${depVersion}`r`n"

  # Insert immediately after 'dependencies:' line
  $idx = $m.Index + $m.Length
  return $yaml.Insert($idx, "`r`n$insertLine").Replace("`r`n`r`n", "`r`n") # mild cleanup
}

function Ensure-ImportLineInDart([string]$dartPath, [string]$importLine) {
  if (!(Test-Path $dartPath)) { throw "Dart file not found: $dartPath" }
  $raw = Get-Content $dartPath -Raw
  if ($raw -match [regex]::Escape($importLine)) { return $false }

  # insert after last existing import, otherwise at top
  if ($raw -match "(?m)^(import\s+'.+?';\s*)+$") {
    $raw = [regex]::Replace($raw, "(?m)^(import\s+'.+?';\s*)+", "`$0`r`n$importLine`r`n", 1)
  } else {
    $raw = "$importLine`r`n$raw"
  }

  Backup-File $dartPath
  Set-Content -Path $dartPath -Value $raw -Encoding UTF8
  Write-Host "[OK] Added missing import to $dartPath : $importLine"
  return $true
}

Write-Host "==> FIX EXERCISES DEPS + BUILD" -ForegroundColor Cyan
Write-Host "Root: $root"
Write-Host "Flutter: $flutter"
Write-Host "Pubspec: $pubspec"

# --- Patch pubspec.yaml ---
$pub = Get-Content $pubspec -Raw
$pub2 = $pub

$pub2 = Ensure-Dependency -yaml $pub2 -depName "shared_preferences" -depVersion "^2.2.3"
$pub2 = Ensure-Dependency -yaml $pub2 -depName "url_launcher" -depVersion "^6.2.6"

if ($pub2 -ne $pub) {
  Backup-File $pubspec
  Set-Content -Path $pubspec -Value $pub2 -Encoding UTF8
  Write-Host "[OK] Patched pubspec.yaml (added missing deps)" -ForegroundColor Green
} else {
  Write-Host "[OK] pubspec.yaml already contains required deps" -ForegroundColor Green
}

# --- Optional: ensure imports exist in exercises_screen.dart (only if missing) ---
$dartFile = Join-Path $root "lib\premium\screens\exercises_screen.dart"
if (Test-Path $dartFile) {
  $changed1 = Ensure-ImportLineInDart -dartPath $dartFile -importLine "import 'package:shared_preferences/shared_preferences.dart';"
  $changed2 = Ensure-ImportLineInDart -dartPath $dartFile -importLine "import 'package:url_launcher/url_launcher.dart';"
  if ($changed1 -or $changed2) {
    Write-Host "[OK] Dart imports updated." -ForegroundColor Green
  }
}

# --- Build steps ---
Push-Location $root
try {
  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  & $flutter pub get

  Write-Host "==> flutter clean" -ForegroundColor Cyan
  & $flutter clean | Out-Null

  Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
  & $flutter build windows --release

  $exe = Join-Path $root "build\windows\x64\runner\Release\simon_physio.exe"
  if (Test-Path $exe) {
    Write-Host "[OK] Build complete." -ForegroundColor Green
    Write-Host "EXE: $exe"
  } else {
    Write-Host "[WARN] Build finished but EXE not found at expected path:" -ForegroundColor Yellow
    Write-Host "  $exe"
  }
}
finally {
  Pop-Location
}
