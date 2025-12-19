$ErrorActionPreference = "Stop"

function OK($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }

$repo = (Resolve-Path ".").Path
Set-Location $repo

# Strings built from explicit codepoints (safe to paste)
$replacements = @(
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)); to = [string]([char]0x2014) }, # Ã¢â‚¬â€ -> â€”
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201C)); to = [string]([char]0x2013) }, # Ã¢â‚¬â€œ -> â€“
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x2122)); to = [string]([char]0x2019) }, # Ã¢â‚¬â„¢ -> â€™
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x02DC)); to = [string]([char]0x2018) }, # Ã¢â‚¬Ëœ -> â€˜
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x0153)); to = [string]([char]0x201C) }, # Ã¢â‚¬Å“ -> â€œ
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x009D)); to = [string]([char]0x201D) }, # Ã¢â‚¬  -> â€
    @{ from = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x00A2)); to = [string]([char]0x2022) }, # Ã¢â‚¬Â¢ -> â€¢

    @{ from = ([string]([char]0x00C2) + [string]([char]0x00A0)); to = " " },  # Ã‚<NBSP> -> space
    @{ from = ([string]([char]0x00C2)); to = "" }    # stray Ã‚ -> remove
)

$files = Get-ChildItem -Path ".\lib" -Recurse -Filter *.dart
$changedFiles = 0

foreach ($f in $files) {
    $raw = Get-Content $f.FullName -Raw
    $orig = $raw

    foreach ($r in $replacements) {
        $raw = $raw.Replace([string]$r.from, [string]$r.to)
    }

    if ($raw -ne $orig) {
        [System.IO.File]::WriteAllText($f.FullName, $raw, (New-Object System.Text.UTF8Encoding($false)))
        $changedFiles++
        INFO ("Fixed: " + $f.FullName)
    }
}

OK "Done. Files changed: $changedFiles"

