$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]  $m" -ForegroundColor Green }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

$repo = (Resolve-Path ".").Path
Set-Location $repo
INFO "Repo: $repo"

# Flutter path (yours)
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) {
    $flutter = (& where.exe flutter 2>$null | Select-Object -First 1)
}
if (-not $flutter) { FAIL "Flutter not found" }
OK "Flutter: $flutter"

# Kill running exe if any
Get-Process simon_physio -ErrorAction SilentlyContinue | Stop-Process -Force

# Ensure assets folders exist
$assetsRoot = Join-Path $repo "assets"
New-Item -ItemType Directory -Force $assetsRoot | Out-Null
$needDirs = @(
    "assets\images",
    "assets\icons",
    "assets\media\bundled\thumbs",
    "assets\media\bundled\previews"
)
foreach ($d in $needDirs) { New-Item -ItemType Directory -Force (Join-Path $repo $d) | Out-Null }

# Count real asset files in /assets
$assetFiles = Get-ChildItem $assetsRoot -Recurse -File -ErrorAction SilentlyContinue
$assetCount = @($assetFiles).Count
INFO "Asset files currently in /assets: $assetCount"

# If empty, seed from known places automatically
if ($assetCount -eq 0) {
    INFO "assets/ is empty -> seeding assets automatically"

    # 1) Copy Android launcher icon as a guaranteed real PNG
    $launcher = Join-Path $repo "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
    if (Test-Path $launcher) {
        Copy-Item $launcher (Join-Path $repo "assets\images\app_icon.png") -Force
        OK "Seeded assets/images/app_icon.png from Android launcher icon"
    }
    else {
        INFO "Android launcher icon not found at expected path"
    }

    # 2) If you have a previous portable dist that contains real assets, pull them back into source
    $distAssets = Join-Path $repo "DIST\windows_release_portable\data\flutter_assets\assets"
    if (Test-Path $distAssets) {
        INFO "Found DIST assets: $distAssets -> copying into source assets/"
        robocopy $distAssets $assetsRoot /E /NFL /NDL /NJH /NJS /NP | Out-Null
        OK "Copied any existing built assets back into assets/"
    }
    else {
        INFO "No DIST portable assets folder found (that's okay)"
    }

    # Recount
    $assetFiles = Get-ChildItem $assetsRoot -Recurse -File -ErrorAction SilentlyContinue
    $assetCount = @($assetFiles).Count
    INFO "Asset files after seeding: $assetCount"
    if ($assetCount -eq 0) {
        FAIL "Still zero files in assets/. You genuinely have no source assets to bundle."
    }
}

# Ensure pubspec.yaml has assets entries (keep it simple, dont rewrite everything)
$pub = Join-Path $repo "pubspec.yaml"
if (!(Test-Path $pub)) { FAIL "pubspec.yaml not found" }
$raw = Get-Content $pub -Raw

# Ensure flutter: block exists
if ($raw -notmatch "(?m)^flutter:\s*$") {
    $raw += "`nflutter:`n  uses-material-design: true`n"
}

# Ensure uses-material-design line exists
if ($raw -notmatch "(?m)^\s{2}uses-material-design:\s*true\s*$") {
    $raw = [regex]::Replace($raw, "(?m)^flutter:\s*$", "flutter:`n  uses-material-design: true", 1)
}

# Ensure assets block contains the 4 folders we use
$want = @(
    "assets/images/",
    "assets/icons/",
    "assets/media/bundled/thumbs/",
    "assets/media/bundled/previews/"
)

if ($raw -notmatch "(?m)^\s{2}assets:\s*$") {
    # Insert right after uses-material-design
    $insert = "  uses-material-design: true`n  assets:`n" + (($want | ForEach-Object { "    - $_" }) -join "`n")
    $raw = [regex]::Replace($raw, "(?m)^\s{2}uses-material-design:\s*true\s*$", $insert, 1)
}
else {
    # Append missing entries
    foreach ($p in $want) {
        if ($raw -notmatch [regex]::Escape($p)) {
            $raw = [regex]::Replace($raw, "(?m)^\s{2}assets:\s*$", "  assets:`n    - $p", 1)
        }
    }
}

# Write pubspec.yaml UTF-8 (no BOM)
[System.IO.File]::WriteAllText($pub, $raw, (New-Object System.Text.UTF8Encoding($false)))
OK "pubspec.yaml ensured assets are declared"

# Clean + build
INFO "Cleaning"
& $flutter clean | Out-Host
INFO "Pub get"
& $flutter pub get | Out-Host
INFO "Building Windows release"
& $flutter build windows --release | Out-Host
OK "Build succeeded"

# Verify bundled assets exist in build
$fa = Join-Path $repo "build\windows\x64\runner\Release\data\flutter_assets"
if (!(Test-Path $fa)) { FAIL "flutter_assets missing: $fa" }

$builtAssetsDir = Join-Path $fa "assets"
if (!(Test-Path $builtAssetsDir)) { FAIL "No flutter_assets\assets folder (assets not bundled)" }

$bundled = Get-ChildItem $builtAssetsDir -Recurse -File -ErrorAction SilentlyContinue
$bundledCount = @($bundled).Count
INFO "Bundled files in build/flutter_assets/assets: $bundledCount"
if ($bundledCount -eq 0) { FAIL "flutter_assets\assets exists but is EMPTY" }

OK "ASSETS BUNDLED "
OK "GOLD MASTER READY "


