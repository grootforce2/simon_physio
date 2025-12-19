$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

$repo = (Resolve-Path ".").Path
Set-Location $repo
OK "Repo: $repo"

# Flutter (prefer Puro stable)
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { $flutter = (& where.exe flutter 2>$null | Select-Object -First 1) }
if (-not $flutter) { FAIL "Flutter not found" }
OK "Flutter: $flutter"

# Kill locky processes
$killNames = @("simon_physio", "Runner", "flutter", "dart", "cmake", "ninja", "msbuild", "cl", "link")
foreach ($n in $killNames) { Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 250
OK "Killed possible locking processes"

# ---- Mojibake fixer using explicit codepoints (copy/paste safe) ----
# bad sequences like: â â â âœ â â and NBSP/Â junk
$seq_emdash = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)) # â
$seq_endash = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201C)) # â
$seq_rsquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x2122)) # â
$seq_lsquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x02DC)) # â
$seq_ldquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x0153)) # âœ
$seq_rdquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x009D)) # â
$seq_bullet = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x00A2)) # â
$nbsp = ([string]([char]0x00C2) + [string]([char]0x00A0))                          # Â 
$strayC2 = ([string]([char]0x00C2))                                                    # Â

$repl = @(
    @{ from = $seq_emdash; to = "" },
    @{ from = $seq_endash; to = "" },
    @{ from = $seq_rsquo; to = "" },
    @{ from = $seq_lsquo; to = "" },
    @{ from = $seq_ldquo; to = "" },
    @{ from = $seq_rdquo; to = "" },
    @{ from = $seq_bullet; to = "" },
    @{ from = $nbsp; to = " " },
    @{ from = $strayC2; to = "" }
)

$dartFiles = Get-ChildItem -Path (Join-Path $repo "lib") -Recurse -Filter *.dart -ErrorAction SilentlyContinue
$fixed = 0
foreach ($f in $dartFiles) {
    $raw = Get-Content $f.FullName -Raw
    $orig = $raw
    foreach ($r in $repl) { $raw = $raw.Replace($r.from, $r.to) }
    if ($raw -ne $orig) {
        [System.IO.File]::WriteAllText($f.FullName, $raw, (New-Object System.Text.UTF8Encoding($false)))
        $fixed++
        INFO "Mojibake fixed: $($f.FullName)"
    }
}
OK "Mojibake pass complete. Files changed: $fixed"

# Ensure pubspec assets include images/videos
$pub = Join-Path $repo "pubspec.yaml"
if (!(Test-Path $pub)) { FAIL "pubspec.yaml not found" }
$pubRaw = Get-Content $pub -Raw

if ($pubRaw -notmatch "(?m)^flutter:\s*$") { $pubRaw += "`nflutter:`n  uses-material-design: true`n" }
if ($pubRaw -notmatch "(?m)^\s{2}uses-material-design:\s*true\s*$") {
    $pubRaw = [regex]::Replace($pubRaw, "(?m)^flutter:\s*$", "flutter:`n  uses-material-design: true", 1)
}

if ($pubRaw -notmatch "(?m)^\s{2}assets:\s*$") {
    $insert = "  uses-material-design: true`n  assets:`n    - assets/images/`n    - assets/videos/"
    $pubRaw = [regex]::Replace($pubRaw, "(?m)^\s{2}uses-material-design:\s*true\s*$", $insert, 1)
}
else {
    if ($pubRaw -notmatch "(?m)^\s{4}-\s+assets/images/\s*$") {
        $pubRaw = $pubRaw -replace "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/"
    }
    if ($pubRaw -notmatch "(?m)^\s{4}-\s+assets/videos/\s*$") {
        $pubRaw = $pubRaw -replace "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/`n    - assets/videos/"
    }
}
[System.IO.File]::WriteAllText($pub, $pubRaw, (New-Object System.Text.UTF8Encoding($false)))
OK "pubspec.yaml assets ensured"

New-Item -ItemType Directory -Force (Join-Path $repo "assets\images") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $repo "assets\videos") | Out-Null

# AUDIT: dead buttons
$buttonIssues = @()
foreach ($f in $dartFiles) {
    $lines = Get-Content $f.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match "onPressed\s*:\s*null") { $buttonIssues += "{0}:{1}: onPressed NULL" -f $f.FullName, ($i + 1) }
        if ($ln -match "onPressed\s*:\s*\(\s*\)\s*=>\s*null") { $buttonIssues += "{0}:{1}: onPressed => null" -f $f.FullName, ($i + 1) }
        if ($ln -match "onPressed\s*:\s*\(\s*\)\s*\{\s*\}\s*,?\s*$") { $buttonIssues += "{0}:{1}: onPressed empty" -f $f.FullName, ($i + 1) }
    }
}
if ($buttonIssues.Count) { WARN "Dead buttons found: $($buttonIssues.Count)"; $buttonIssues | Select-Object -First 200 | ForEach-Object { WARN $_ } }
else { OK "No obvious dead buttons detected" }

# AUDIT: route mismatches
$routerFile = Join-Path $repo "lib\core\routing\app_router.dart"
if (Test-Path $routerFile) {
    $routerRaw = Get-Content $routerFile -Raw
    $routes = @()
    $routes += [regex]::Matches($routerRaw, "GoRoute\s*\(\s*path\s*:\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
    $routes += [regex]::Matches($routerRaw, "GoRoute\s*\(\s*path\s*:\s*""([^""]+)""") | ForEach-Object { $_.Groups[1].Value }
    $routes = $routes | Sort-Object -Unique

    $allRaw = ($dartFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
    $nav = @()
    $nav += [regex]::Matches($allRaw, "context\.(go|push|replace)\(\s*'([^']+)'\s*\)") | ForEach-Object { $_.Groups[2].Value }
    $nav += [regex]::Matches($allRaw, "context\.(go|push|replace)\(\s*""([^""]+)""\s*\)") | ForEach-Object { $_.Groups[2].Value }
    $nav = $nav | Where-Object { $_ -match "^/" } | Sort-Object -Unique

    $missing = @()
    foreach ($p in $nav) { if ($routes -notcontains $p) { $missing += $p } }
    if ($missing.Count) { WARN "context.go/push to missing routes: $($missing.Count)"; $missing | Select-Object -First 200 | ForEach-Object { WARN "NO ROUTE: $_" } }
    else { OK "Routes consistent" }
}
else {
    WARN "Router file missing (skipping route audit)"
}

# Build
INFO "flutter clean"
& $flutter clean | Out-Host
INFO "flutter pub get"
& $flutter pub get | Out-Host
INFO "flutter build windows --release"
& $flutter build windows --release | Out-Host

$exe = Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"
if (!(Test-Path $exe)) { FAIL "EXE missing after build: $exe" }
OK "Build OK: $exe"

OK "DONE"


