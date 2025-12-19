# SIMON_ONECLICK_ALL_V3.ps1
# One click: version bump -> git commit/push -> build windows release -> package FULL bundle -> zip + manifest
$ErrorActionPreference = "Stop"

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$FlutterBat = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
$VsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"

if (!(Test-Path $ProjectRoot)) { throw "Project root not found: $ProjectRoot" }
if (!(Test-Path $FlutterBat)) { throw "flutter.bat not found: $FlutterBat" }
if (!(Test-Path $VsDevCmd)) { throw "VsDevCmd.bat not found: $VsDevCmd" }

Set-Location $ProjectRoot

function Run-VS($cmd, $logPath = $null) {
    $wrapped = """" + $VsDevCmd + """ -arch=x64 -host_arch=x64 && " + $cmd
    if ($logPath) {
        cmd /c $wrapped *> $logPath
    }
    else {
        cmd /c $wrapped
    }
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $cmd" }
}

# ---------- Version bump (pubspec.yaml build number +1) ----------
Say "Bumping pubspec version (build number +1)"
$pubspec = Join-Path $ProjectRoot "pubspec.yaml"
if (!(Test-Path $pubspec)) { throw "pubspec.yaml not found" }

$lines = Get-Content $pubspec -Encoding UTF8
$idx = ($lines | Select-String -Pattern '^\s*version\s*:\s*' | Select-Object -First 1).LineNumber
if (!$idx) { throw "No version: line found in pubspec.yaml" }
$idx = $idx - 1

$verLine = $lines[$idx]
# expected: version: 1.2.3+45 (or similar)
$ver = ($verLine -split ":", 2)[1].Trim()
if ($ver -notmatch '^(?<semver>\d+\.\d+\.\d+)(\+(?<build>\d+))?$') {
    throw "Unexpected version format: $ver (expected like 1.2.3+45)"
}
$semver = $Matches.semver
$build = if ($Matches.build) { [int]$Matches.build } else { 0 }
$newBuild = $build + 1
$newVer = "$semver+$newBuild"
$lines[$idx] = ($verLine -replace [regex]::Escape($ver), $newVer)

Set-Content -Path $pubspec -Value $lines -Encoding UTF8
Say "Version: $ver -> $newVer"

# ---------- Git (add/commit/push) ----------
Say "Git add/commit/push"
# ensure origin exists (won't overwrite)
$hasOrigin = (git remote 2>$null) -match '^origin$'
if (-not $hasOrigin) {
    git remote add origin "https://github.com/grootforce2/simon_physio.git" | Out-Null
}
git branch -M main | Out-Null

git add -A | Out-Null
# Commit only if there are changes
$dirty = (git status --porcelain)
if ($dirty) {
    git commit -m "Release $newVer (auto)" | Out-Null
}
else {
    Say "Nothing new to commit"
}
git push -u origin main

# ---------- Build ----------
$dist = Join-Path $ProjectRoot "DIST"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $dist "windows_build_$timestamp.log"

Say "flutter clean"
Run-VS "`"$FlutterBat`" clean"

Say "Hard wipe build/ (prevents cmake install leftovers)"
$buildDir = Join-Path $ProjectRoot "build"
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }

Say "flutter pub get"
Run-VS "`"$FlutterBat`" pub get"

Say "flutter build windows --release (verbose) -> $log"
Run-VS "`"$FlutterBat`" build windows --release -v" $log

# ---------- Package FULL Windows bundle ----------
$releaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
if (!(Test-Path $releaseDir)) { throw "Release folder not found: $releaseDir" }

# Find the app exe in Release (exclude obvious installers)
$appExe = Get-ChildItem $releaseDir -Filter *.exe | Where-Object { $_.Name -notmatch 'vc_redist|setup|installer' } | Select-Object -First 1
if (!$appExe) { throw "No app exe found in: $releaseDir" }

$bundleName = "simon_physio_windows_release_${newVer}_$timestamp"
$bundleDir = Join-Path $dist $bundleName

Say "Packaging FULL bundle (DLLs + data + plugins) -> $bundleDir"
if (Test-Path $bundleDir) { Remove-Item $bundleDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

Copy-Item -Path (Join-Path $releaseDir "*") -Destination $bundleDir -Recurse -Force

# sanity: check isar dll exists somewhere in bundle
$isar = Get-ChildItem $bundleDir -Recurse -Filter "isar_flutter_libs_plugin.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $isar) {
    Say "WARNING: isar_flutter_libs_plugin.dll not found in bundle. App may still fail. Check $log"
}
else {
    Say "OK: Found isar dll at $($isar.FullName)"
}

# zip the whole bundle
$zipPath = Join-Path $dist ("$bundleName.zip")
Say "Creating ZIP -> $zipPath"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $zipPath

# write manifest
$commit = (git rev-parse --short HEAD).Trim()
$manifest = [pscustomobject]@{
    app       = "simon_physio"
    version   = $newVer
    gitCommit = $commit
    builtAt   = (Get-Date).ToString("s")
    exe       = (Join-Path $bundleDir $appExe.Name)
    zip       = $zipPath
    log       = $log
}
$manifestPath = Join-Path $dist ("manifest_$timestamp.json")
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $manifestPath

Write-Host ""
Write-Host "================================================"
Write-Host "DONE"
Write-Host "BUNDLE : $bundleDir"
Write-Host "EXE    : $(Join-Path $bundleDir $appExe.Name)"
Write-Host "ZIP    : $zipPath"
Write-Host "LOG    : $log"
Write-Host "MANIF  : $manifestPath"
Write-Host "================================================"

