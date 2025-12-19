# SIMON_ONECLICK_AUTOFIX_BUTTONS_AND_BUILD.ps1
# One-click: kill locks -> fix mojibake -> ensure pubspec assets -> autofix dead buttons/taps -> audit -> build Windows release
# PowerShell 5.1 compatible

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

# --- Repo ---
$repo = (Resolve-Path ".").Path
Set-Location $repo
OK "Repo: $repo"

# --- Locate Flutter (prefer Puro stable) ---
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) {
    $flutter = (& where.exe flutter 2>$null | Select-Object -First 1)
}
if (-not $flutter -or !(Test-Path $flutter)) { FAIL "Flutter not found. Install Flutter or ensure it is on PATH." }
OK "Flutter: $flutter"

# --- Kill anything that can lock build output ---
$killNames = @("simon_physio", "Runner", "flutter", "dart", "cmake", "ninja", "msbuild", "cl", "link")
foreach ($n in $killNames) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 300
OK "Killed possible locking processes"

# --- Try to delete locked Release folder (best effort) ---
$rel = Join-Path $repo "build\windows\x64\runner\Release"
if (Test-Path $rel) {
    for ($i = 1; $i -le 6; $i++) {
        try {
            Remove-Item $rel -Recurse -Force -ErrorAction Stop
            INFO "Deleted locked Release folder"
            break
        }
        catch {
            WARN "Release still locked, retry $i"
            Start-Sleep -Milliseconds 600
        }
    }
}

# --- Mojibake fixer using explicit codepoints (copy/paste safe) ---
$seq_emdash = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)) # â€” (common)
$seq_endash = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201C)) # â€“ (common)
$seq_rsquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x2122)) # â€™
$seq_lsquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x02DC)) # â€˜ (varies)
$seq_ldquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x0153)) # â€œ (varies)
$seq_rdquo = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x009D)) # â€ (varies)
$seq_bullet = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x00A2)) # â€¢ (varies)
$nbsp = ([string]([char]0x00C2) + [string]([char]0x00A0))                           # NBSP
$strayC2 = ([string]([char]0x00C2))

$replMoj = @(
    @{ from = $seq_emdash; to = "-" },
    @{ from = $seq_endash; to = "-" },
    @{ from = $seq_rsquo; to = "'" },
    @{ from = $seq_lsquo; to = "'" },
    @{ from = $seq_ldquo; to = '"' },
    @{ from = $seq_rdquo; to = '"' },
    @{ from = $seq_bullet; to = "*" },
    @{ from = $nbsp; to = " " },
    @{ from = $strayC2; to = "" }
)

$libDir = Join-Path $repo "lib"
$dartFiles = Get-ChildItem -Path $libDir -Recurse -Filter *.dart -ErrorAction SilentlyContinue
if (-not $dartFiles) { FAIL "No Dart files found under .\lib" }

$fixedMoj = 0
foreach ($f in $dartFiles) {
    $raw = Get-Content $f.FullName -Raw
    $orig = $raw
    foreach ($r in $replMoj) { $raw = $raw.Replace($r.from, $r.to) }
    if ($raw -ne $orig) {
        [System.IO.File]::WriteAllText($f.FullName, $raw, (New-Object System.Text.UTF8Encoding($false)))
        $fixedMoj++
        INFO "Mojibake fixed: $($f.FullName)"
    }
}
OK "Mojibake pass complete. Files changed: $fixedMoj"

# --- Ensure pubspec assets include images/videos ---
$pub = Join-Path $repo "pubspec.yaml"
if (!(Test-Path $pub)) { FAIL "pubspec.yaml not found" }
$pubRaw = Get-Content $pub -Raw

if ($pubRaw -notmatch "(?m)^flutter:\s*$") {
    $pubRaw += "`nflutter:`n  uses-material-design: true`n"
}
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
OK "pubspec.yaml assets ensured (images + videos)"

New-Item -ItemType Directory -Force (Join-Path $repo "assets\images") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $repo "assets\videos") | Out-Null

# --- AUTOFIX: dead buttons & taps (make them clickable + log loudly) ---
function Apply-DartFixes([string]$filePath) {
    $raw = Get-Content $filePath -Raw
    $orig = $raw
    $relp = $filePath.Replace($repo + "\", "")
    $log = "debugPrint('TODO-WIRE: " + $relp.Replace("'", "") + "');"
    $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline

    $raw = [regex]::Replace($raw, "onPressed\s*:\s*null", "onPressed: () { $log }", $opts)
    $raw = [regex]::Replace($raw, "onPressed\s*:\s*\(\s*\)\s*=>\s*null", "onPressed: () { $log }", $opts)
    $raw = [regex]::Replace($raw, "onPressed\s*:\s*\(\s*\)\s*\{\s*\}", "onPressed: () { $log }", $opts)

    $raw = [regex]::Replace($raw, "onTap\s*:\s*null", "onTap: () { $log }", $opts)
    $raw = [regex]::Replace($raw, "onTap\s*:\s*\(\s*\)\s*=>\s*null", "onTap: () { $log }", $opts)
    $raw = [regex]::Replace($raw, "onTap\s*:\s*\(\s*\)\s*\{\s*\}", "onTap: () { $log }", $opts)

    if ($raw -ne $orig) {
        [System.IO.File]::WriteAllText($filePath, $raw, (New-Object System.Text.UTF8Encoding($false)))
        return $true
    }
    return $false
}

$changed = 0
foreach ($f in $dartFiles) {
    if (Apply-DartFixes $f.FullName) {
        $changed++
        INFO "Autofixed handlers: $($f.FullName)"
    }
}
OK "Autofix pass complete. Files changed: $changed"

# --- REPORT: remaining dead handlers (PowerShell 5.1 friendly) ---
$dead = @()
Get-ChildItem -Path $libDir -Recurse -Filter *.dart | ForEach-Object {
    $dead += Select-String -Path $_.FullName -ErrorAction SilentlyContinue -Pattern @(
        "onPressed\s*:\s*null",
        "onPressed\s*:\s*\(\s*\)\s*=>\s*null",
        "onPressed\s*:\s*\(\s*\)\s*\{\s*\}\s*,?\s*$",
        "onTap\s*:\s*null",
        "onTap\s*:\s*\(\s*\)\s*=>\s*null",
        "onTap\s*:\s*\(\s*\)\s*\{\s*\}\s*,?\s*$"
    )
}

if ($dead.Count -gt 0) {
    WARN "Still-found dead handlers (showing first 200):"
    $dead | Select-Object -First 200 | ForEach-Object {
        WARN ("{0}:{1} {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim())
    }
    FAIL "Dead handlers still exist. Fix patterns or inspect above."
}
else {
    OK "No dead handlers remain (null/empty onPressed/onTap)"
}

# --- Asset audit: ensure referenced assets exist ---
function Normalize-AssetPath([string]$p) {
    $p = $p.Trim().Trim("'").Trim('"')
    $p = $p -replace "\\", "/"
    return $p
}

$missing = @()
foreach ($f in $dartFiles) {
    $raw = Get-Content $f.FullName -Raw
    $m = [regex]::Matches($raw, "(assets\/[A-Za-z0-9_\-\/\.]+\.(png|jpg|jpeg|webp|gif|svg|mp4|mov|webm))", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($mm in $m) {
        $ap = Normalize-AssetPath $mm.Groups[1].Value
        $full = Join-Path $repo $ap.Replace("/", "\")
        if (!(Test-Path $full)) {
            $missing += ("{0} -> {1}" -f $f.FullName, $ap)
        }
    }
}

if ($missing.Count -gt 0) {
    WARN "Missing assets referenced in Dart (showing first 200):"
    $missing | Select-Object -First 200 | ForEach-Object { WARN $_ }
    FAIL "Asset audit failed. Fix missing files or paths."
}
else {
    OK "Asset audit OK (no missing assets/...)"
}

# --- Build Windows release ---
INFO "flutter clean"
& $flutter clean | Out-Host

INFO "flutter pub get"
& $flutter pub get | Out-Host

INFO "flutter build windows --release"
& $flutter build windows --release | Out-Host

$exe = Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"
if (!(Test-Path $exe)) { FAIL "EXE missing after build: $exe" }
OK "Build OK: $exe"

$fa = Join-Path $repo "build\windows\x64\runner\Release\data\flutter_assets"
if (!(Test-Path $fa)) { FAIL "flutter_assets missing: $fa" }
OK "flutter_assets OK"

OK "DONE. NOTE: This makes dead buttons clickable (logs TODO-WIRE). It does NOT implement feature logic."


