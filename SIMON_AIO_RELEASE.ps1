# SIMON_AIO_RELEASE.ps1
# One-click: patch theme issues -> pub get -> build windows release (with VS env) -> create portable dist + zip + sha256
# Run from: C:\SIMON\simon_physio

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- Config (edit only if your paths differ) ---
$ProjectRoot = (Resolve-Path ".").Path
$FlutterBat  = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
$VsDevCmd    = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"

# --- Sanity checks ---
Info "Checking project root..."
if (!(Test-Path "$ProjectRoot\pubspec.yaml")) { Fail "Run this from the Flutter project root (where pubspec.yaml is)." }

Info "Checking Flutter..."
if (!(Test-Path $FlutterBat)) {
  Fail "Flutter not found at: $FlutterBat`nFix by updating `$FlutterBat in this script."
}

Info "Checking Visual Studio Build Tools..."
if (!(Test-Path $VsDevCmd)) {
  Fail "VsDevCmd.bat not found at: $VsDevCmd`nInstall VS Build Tools + VC Tools workload."
}

# --- Read app version from pubspec.yaml ---
$pubspec = Get-Content "$ProjectRoot\pubspec.yaml" -Raw
$versionLine = ($pubspec -split "`n" | Where-Object { $_ -match '^\s*version\s*:\s*' } | Select-Object -First 1)
if (-not $versionLine) { Fail "No version: line found in pubspec.yaml" }
$ver = ($versionLine -replace '^\s*version\s*:\s*', '').Trim()
# Flutter version format: x.y.z+build
$verSafe = $ver -replace '[^\w\.\+\-]', '_'
Info "App version detected: $ver"

# --- Option A: "Clinic-ready polish" automation ---
# 1) Patch common Flutter 3.38+ theme breaking changes (CardThemeData + const issues)
$themePath = "$ProjectRoot\lib\core\theme\app_theme.dart"
if (Test-Path $themePath) {
  Info "Patching theme compile issues (CardThemeData / const)..."
  $theme = Get-Content $themePath -Raw

  # CardTheme -> CardThemeData (if using Material 3 theme APIs)
  # Safe-ish: replace "CardTheme(" with "CardThemeData(" and "const CardTheme(" with "const CardThemeData("
  $theme2 = $theme `
    -replace '\bconst\s+CardTheme\s*\(', 'const CardThemeData(' `
    -replace '\bCardTheme\s*\(', 'CardThemeData('

  # If you have: const CardThemeData(... non-const args ...) => remove const on that constructor call only.
  # This targets: "const CardThemeData(" -> "CardThemeData("
  # (Reason: Flutter complains when const expects a non-const value inside.)
  $theme2 = $theme2 -replace '\bconst\s+CardThemeData\s*\(', 'CardThemeData('

  if ($theme2 -ne $theme) {
    Set-Content -Path $themePath -Value $theme2 -Encoding UTF8
    Info "Patched: $themePath"
  } else {
    Info "No theme patch needed."
  }
} else {
  Info "Theme file not found (skipping): $themePath"
}

# 2) Create a sample/demo dataset folder (non-breaking; your app can choose to load it later)
$demoDir = "$ProjectRoot\assets\demo"
if (!(Test-Path $demoDir)) {
  Info "Creating demo data pack..."
  New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
  $demoJson = @"
{
  "patient": {
    "id": "demo-001",
    "name": "Demo Patient",
    "dob": "1990-01-01",
    "notes": "This is demo data for clinic walkthrough."
  },
  "plan": {
    "title": "Lower back mobility (Demo)",
    "exercises": [
      { "name": "Cat-Cow", "sets": 2, "reps": 10 },
      { "name": "Child's Pose", "sets": 2, "reps": 6 },
      { "name": "Glute Bridge", "sets": 3, "reps": 10 }
    ]
  }
}
"@
  Set-Content -Path "$demoDir\demo_patient_plan.json" -Value $demoJson -Encoding UTF8
  Info "Demo pack created: $demoDir\demo_patient_plan.json"
} else {
  Info "Demo data folder exists (skipping): $demoDir"
}

# 3) Ensure assets folder exists in pubspec (optional, safe add if missing)
# We'll add only "assets/" line if no assets section exists. (Doesn't break builds.)
if ($pubspec -notmatch '^\s*assets\s*:\s*$' -and $pubspec -notmatch '^\s*assets\s*:\s*\[') {
  Info "Adding assets entry to pubspec.yaml (safe default)..."
  $insert = @"
flutter:
  assets:
    - assets/
"@
  if ($pubspec -match '^\s*flutter\s*:\s*$'m) {
    # If flutter: exists, append assets under it (simple approach)
    $pubspec2 = $pubspec -replace '(^\s*flutter\s*:\s*$)', "`$1`n  assets:`n    - assets/"
  } else {
    # If no flutter: section, append at end
    $pubspec2 = $pubspec.TrimEnd() + "`n`n" + $insert + "`n"
  }
  Set-Content -Path "$ProjectRoot\pubspec.yaml" -Value $pubspec2 -Encoding UTF8
  Info "pubspec.yaml updated with assets/"
} else {
  Info "pubspec.yaml already has assets section (skipping)."
}

# --- Get deps ---
Info "Running flutter pub get..."
& $FlutterBat pub get

# --- Build Windows release using VS environment (no PATH required) ---
Info "Building Windows (Release) using VsDevCmd..."
$cmd = @"
`"$VsDevCmd`" -arch=x64 -host_arch=x64 && `"$FlutterBat`" build windows --release
"@
cmd.exe /c $cmd
if ($LASTEXITCODE -ne 0) { Fail "Flutter build failed." }

# --- Create portable distro ---
$exePath = "$ProjectRoot\build\windows\x64\runner\Release\simon_physio.exe"
if (!(Test-Path $exePath)) { Fail "Build finished but EXE not found at: $exePath" }

$distRoot = "$ProjectRoot\dist"
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$distName = "SimonPhysio_${verSafe}_win64_${stamp}_portable"
$distDir = Join-Path $distRoot $distName

Info "Creating portable dist folder: $distDir"
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Copy the whole Release folder contents (DLLs + data dirs)
$releaseDir = Split-Path $exePath -Parent
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $distDir -Recurse -Force

# Add a simple README
$readme = @"
Simon Physio (Windows Portable)
Version: $ver
Built: $(Get-Date)

Run:
  simon_physio.exe

Notes:
- This is a portable build folder (no installer).
- If Windows SmartScreen warns, choose "More info" -> "Run anyway" (standard for unsigned internal builds).
"@
Set-Content -Path (Join-Path $distDir "README.txt") -Value $readme -Encoding UTF8

# --- Zip + hash ---
$zipPath = Join-Path $distRoot ($distName + ".zip")
Info "Zipping: $zipPath"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $distDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
Set-Content -Path ($zipPath + ".sha256.txt") -Value $hash -Encoding ASCII

Info "DONE."
Write-Host ""
Write-Host "Portable folder: $distDir" -ForegroundColor Green
Write-Host "ZIP package:     $zipPath" -ForegroundColor Green
Write-Host "SHA256:          $hash" -ForegroundColor Green
