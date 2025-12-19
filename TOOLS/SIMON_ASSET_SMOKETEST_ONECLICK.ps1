$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]  $m" -ForegroundColor Green }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

$repo = (Resolve-Path ".").Path
Set-Location $repo

# Flutter (prefer your pinned path, fallback to PATH)
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { $flutter = (& where.exe flutter 2>$null | Select-Object -First 1) }
if (-not $flutter) { FAIL "Flutter not found" }
OK "Flutter: $flutter"

# Kill running exe if any
Get-Process simon_physio -ErrorAction SilentlyContinue | Stop-Process -Force

# Ensure assets + seed file
New-Item -ItemType Directory -Force (Join-Path $repo "assets\images") | Out-Null
$seed = Join-Path $repo "assets\images\app_icon.png"
if (!(Test-Path $seed)) {
    $launcher = Join-Path $repo "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
    if (Test-Path $launcher) {
        Copy-Item $launcher $seed -Force
        OK "Seeded $seed"
    }
    else {
        FAIL "No seed image found and Android launcher icon missing: $launcher"
    }
}
else {
    OK "Seed already exists: $seed"
}

# Ensure pubspec assets block contains assets/images/
$pub = Join-Path $repo "pubspec.yaml"
if (!(Test-Path $pub)) { FAIL "pubspec.yaml not found" }
$raw = Get-Content $pub -Raw

if ($raw -notmatch "(?m)^flutter:\s*$") { $raw += "`nflutter:`n  uses-material-design: true`n" }
if ($raw -notmatch "(?m)^\s{2}uses-material-design:\s*true\s*$") {
    $raw = [regex]::Replace($raw, "(?m)^flutter:\s*$", "flutter:`n  uses-material-design: true", 1)
}

if ($raw -notmatch "(?m)^\s{2}assets:\s*$") {
    $insert = "  uses-material-design: true`n  assets:`n    - assets/images/"
    $raw = [regex]::Replace($raw, "(?m)^\s{2}uses-material-design:\s*true\s*$", $insert, 1)
}
elseif ($raw -notmatch "(?m)^\s{4}-\s+assets/images/\s*$") {
    # add line under assets:
    $raw = [regex]::Replace($raw, "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/", 1)
}

[System.IO.File]::WriteAllText($pub, $raw, (New-Object System.Text.UTF8Encoding($false)))
OK "pubspec.yaml assets ensured"

# Patch premium_dashboard.dart to actually SHOW an asset image (tiny banner)
$dash = Join-Path $repo "lib\premium_dashboard.dart"
if (!(Test-Path $dash)) { FAIL "Missing file: $dash" }

$dashRaw = Get-Content $dash -Raw

# Ensure import for flutter/material exists (it should). If not, bail.
if ($dashRaw -notmatch "package:flutter/material.dart") { FAIL "premium_dashboard.dart missing material import" }

# Insert banner once: look for first occurrence of "return Scaffold(" and inject a Column wrapper
if ($dashRaw -notmatch "ASSET_SMOKETEST_BANNER") {
    $dashRaw = $dashRaw -replace "return\s+Scaffold\s*\(",
    # sanitised example
    return Scaffold(
        // ASSET_SMOKETEST_BANNER
        body: Column(
            children: [
            Padding(
                padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
                child: Row(
                    children: const [
                    SizedBox(
                        width: 28,
                        height: 28,
                        child: Image(image: AssetImage('assets/images/app_icon.png')),
                    ),
                    SizedBox(width: 10),
                    Text('Assets OK', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                ),
            ),
            const SizedBox(height: 8),
            Expanded(
                child:
                # sanitised example
                # now we must close the Column/Expanded after the original Scaffold body finishes.
                # easiest safe-ish close: append closes just before the final ");" of the Scaffold if present.
                $dashRaw = $dashRaw -replace "\)\s*;\s*$",
                # sanitised example
            ),
            ],
        ),
    ),
);
# sanitised example
}

Set-Content -Path $dash -Value $dashRaw -Encoding utf8
OK "Injected asset banner into premium_dashboard.dart"

# Clean + build
INFO "flutter clean"
& $flutter clean | Out-Host
INFO "flutter pub get"
& $flutter pub get | Out-Host
INFO "flutter build windows --release"
& $flutter build windows --release | Out-Host
OK "Build finished"

# Verify bundle contains our file
$fa = Join-Path $repo "build\windows\x64\runner\Release\data\flutter_assets"
if (!(Test-Path $fa)) { FAIL "flutter_assets missing: $fa" }

$builtAssetsDir = Join-Path $fa "assets\images"
$builtFile = Join-Path $builtAssetsDir "app_icon.png"
INFO "Checking: $builtFile"
if (!(Test-Path $builtFile)) { FAIL "Asset not bundled into build: $builtFile" }

OK "ASSET BUNDLED + UI WIRED. Run the EXE and you should see 'Assets OK' with the icon."
OK ("EXE: " + (Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"))




