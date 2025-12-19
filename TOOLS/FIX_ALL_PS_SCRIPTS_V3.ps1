# FIX_ALL_PS_SCRIPTS_V3.ps1
$ErrorActionPreference = "Stop"

$Root = "C:\SIMON\simon_physio"
$Tools = Join-Path $Root "TOOLS"

Write-Host "[V3] Normalize line endings -> Format -> Rescan" -ForegroundColor Cyan
Write-Host "[V3] Tools: $Tools" -ForegroundColor DarkCyan

$files = Get-ChildItem $Tools -Filter "*.ps1" -Recurse

function Normalize-ToCRLF([string]$s) {
    # Convert any CRLF / LF / CR mix to LF, then back to CRLF
    $s = $s -replace "`r`n", "`n"
    $s = $s -replace "`r", "`n"
    return ($s -replace "`n", "`r`n")
}

# 1) Normalize all PS1 to CRLF + UTF8
foreach ($f in $files) {
    $txt = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $txt) { $txt = (Get-Content $f.FullName | Out-String) }
    $norm = Normalize-ToCRLF $txt
    if ($norm -ne $txt) {
        Set-Content -Path $f.FullName -Encoding UTF8 -Value $norm
        Write-Host "[CRLF] $($f.Name)" -ForegroundColor Green
    }
}

# 2) Format safely (string-in/string-out) if Invoke-Formatter exists
if (Get-Command Invoke-Formatter -ErrorAction SilentlyContinue) {
    foreach ($f in $files) {
        try {
            $src = Get-Content $f.FullName -Raw
            $src = Normalize-ToCRLF $src
            $fmt = Invoke-Formatter -ScriptDefinition $src
            if ($fmt) {
                $fmt = Normalize-ToCRLF $fmt
                if ($fmt -ne $src) {
                    Set-Content -Path $f.FullName -Encoding UTF8 -Value $fmt
                    Write-Host "[FMT]  $($f.Name)" -ForegroundColor DarkCyan
                }
                else {
                    Write-Host "[OK]   $($f.Name)" -ForegroundColor DarkGray
                }
            }
        }
        catch {
            Write-Host "[SKIP] $($f.Name) :: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "[WARN] Invoke-Formatter not found (install PSScriptAnalyzer if you want formatting)." -ForegroundColor Yellow
}

# 3) Run cleanup kit again
$kit = Join-Path $Tools "SCRIPT_CLEANUP_KIT.ps1"
if (Test-Path $kit) {
    Write-Host "[RUN] SCRIPT_CLEANUP_KIT.ps1" -ForegroundColor Cyan
    powershell -ExecutionPolicy Bypass -File $kit
}

Write-Host "[DONE] V3 complete." -ForegroundColor Green

