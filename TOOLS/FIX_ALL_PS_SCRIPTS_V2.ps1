# FIX_ALL_PS_SCRIPTS_V2.ps1
Set-StrictMode -Off
$ErrorActionPreference = "Stop"

$Root = "C:\SIMON\simon_physio"
$Tools = Join-Path $Root "TOOLS"
$Out = Join-Path $Root "DIST\script_audit"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "[FIX] Scanning $Tools" -ForegroundColor Cyan

$files = Get-ChildItem $Tools -Filter "*.ps1" -Recurse

foreach ($f in $files) {
    $txt = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $txt) { $txt = (Get-Content $f.FullName | Out-String) }
    $orig = $txt

    # A) Kill the rogue example line that became code: "blah"
    # (Only removes lines that are JUST blah, not words containing blah)
    $txt = [regex]::Replace($txt, '(?m)^\s*blah\s*$\r?\n?', '')

    # B) Fix ${name}: -> ${name}:
    $txt = [regex]::Replace($txt, '\$([A-Za-z_]\w*):', '${$1}:')

    # C) Fix here-string header junk: @"
    text  => @"
`ntext  (same for @'
)
    # Only triggers when @"
or @'
is followed by a non-newline char.
    $txt = [regex]::Replace($txt, '@"
\s*([^\r\n])', '@"
' + "`r`n" + '$1')
    $txt = [regex]::Replace($txt, "@'
\s*([^\r\n])", "@'
" + "`r`n" + '$1')

    # D) Remove the "Example: @"
" snippet if it was injected into Note fields
    # Keeps it readable without breaking parsing.
    $txt = [regex]::Replace(
        $txt,
        "(?ms)Note\s*=\s*'Here-string header must be alone on a line\..*?'\s*",
        "Note = 'Here-string header must be alone on a line. (example removed)'
" + "`r`n"
    )

    if ($txt -ne $orig) {
        Set-Content -Path $f.FullName -Encoding UTF8 -Value $txt
        Write-Host "[PATCHED] $($f.Name)" -ForegroundColor Green
    }
}

# E) Format using Invoke-Formatter correctly (your version doesn't support -Path)
if (Get-Command Invoke-Formatter -ErrorAction SilentlyContinue) {
    foreach ($f in $files) {
        try {
            $src = Get-Content $f.FullName -Raw
            $fmt = Invoke-Formatter -ScriptDefinition $src
            if ($fmt -and $fmt -ne $src) {
                Set-Content -Path $f.FullName -Encoding UTF8 -Value $fmt
                Write-Host "[FORMATTED] $($f.Name)" -ForegroundColor DarkCyan
            }
        } catch {
            Write-Host "[FORMAT-SKIP] $($f.Name) :: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[WARN] Invoke-Formatter not available (PSScriptAnalyzer not installed?)" -ForegroundColor Yellow
}

# F) Run your cleanup kit (if present) AFTER patching
$kit = Join-Path $Tools "SCRIPT_CLEANUP_KIT.ps1"
if (Test-Path $kit) {
    Write-Host "[RUN] SCRIPT_CLEANUP_KIT.ps1" -ForegroundColor Cyan
    powershell -ExecutionPolicy Bypass -File $kit
}

Write-Host "[DONE] Fix + format pass complete." -ForegroundColor Green


