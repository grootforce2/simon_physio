$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

$repo = (Resolve-Path ".").Path
Set-Location $repo

# Flutter
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
    if (Test-Path $launcher) { Copy-Item $launcher $seed -Force; OK "Seeded $seed" }
    else { FAIL "No seed image found and Android launcher icon missing: $launcher" }
}
else {
    OK "Seed exists: $seed"
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
    $raw = [regex]::Replace($raw, "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/", 1)
}
[System.IO.File]::WriteAllText($pub, $raw, (New-Object System.Text.UTF8Encoding($false)))
OK "pubspec.yaml assets ensured"

# 1) Patch PremiumShellScaffold to show icon + Assets OK in header (global)
$shell = Join-Path $repo "lib\premium\widgets\premium_shell_scaffold.dart"
if (!(Test-Path $shell)) { FAIL "Missing file: $shell" }
$s = Get-Content $shell -Raw

if ($s -notmatch "ASSET_SMOKETEST_IN_SHELL") {
    # Insert right before the title text
    $s = $s -replace "Text\(title,",
    # sanitised example
    const SizedBox(
        width: 22,
        height: 22,
        child: Image(image: AssetImage('assets/images/app_icon.png')),
    ),
    // ASSET_SMOKETEST_IN_SHELL
    const SizedBox(width: 10),
    const Text('Assets OK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF9FB0C6))),
    const SizedBox(width: 12),
    Text(title,
        # sanitised example
        OK "Patched PremiumShellScaffold header"
    }
    else {
        OK "PremiumShellScaffold already patched"
    }
    Set-Content -Path $shell -Value $s -Encoding utf8

    # 2) Patch BrandHeader to use asset icon (wide left rail)
    $app = Join-Path $repo "lib\premium\premium_physio_os_app.dart"
    if (!(Test-Path $app)) { FAIL "Missing file: $app" }
    $a = Get-Content $app -Raw

    # Fix mojibake (â / â)
    $a = $a -replace "â", ""
    $a = $a -replace "â", ""

    # Replace the big Icon(...) in _BrandHeader with the asset image once
    if ($a -notmatch "ASSET_SMOKETEST_IN_BRAND") {
        $a = $a -replace "Icon\(Icons\.health_and_safety_rounded, color: Colors\.black, size: 28\),",
        # sanitised example
        SizedBox(
            width: 28,
            height: 28,
            child: Image(image: AssetImage('assets/images/app_icon.png')),
        ),
        // ASSET_SMOKETEST_IN_BRAND
        # sanitised example
        OK "Patched _BrandHeader icon"
    }
    else {
        OK "_BrandHeader already patched"
    }

    # Also fix app title string
    $a = $a -replace "title:\s*'Simon Physio  Premium'", "title: 'Simon Physio  Premium'"

    Set-Content -Path $app -Value $a -Encoding utf8
    OK "premium_physio_os_app.dart fixed (mojibake + brand icon)"

    # Build
    INFO "flutter clean"
    & $flutter clean | Out-Host
    INFO "flutter pub get"
    & $flutter pub get | Out-Host
    INFO "flutter build windows --release"
    & $flutter build windows --release | Out-Host
    OK "Build finished"

    # Verify asset bundled
    $fa = Join-Path $repo "build\windows\x64\runner\Release\data\flutter_assets"
    if (!(Test-Path $fa)) { FAIL "flutter_assets missing: $fa" }
    $builtFile = Join-Path $fa "assets\images\app_icon.png"
    INFO "Checking: $builtFile"
    if (!(Test-Path $builtFile)) { FAIL "Asset not bundled into build: $builtFile" }

    OK "DONE. Run the EXE and you should now see the icon in the left rail header AND 'Assets OK' in every page header."
    OK ("EXE: " + (Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"))




