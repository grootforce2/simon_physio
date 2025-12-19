# FIX_ALL_PS_SCRIPTS.ps1
# One-pass hard fix + audit. Safe on PS 5.1.

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

$Root = "C:\SIMON\simon_physio"
$Tools = Join-Path $Root "TOOLS"
$Out = Join-Path $Root "DIST\script_audit"

New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "[SCAN] Cleaning PowerShell scripts under $Tools" -ForegroundColor Cyan

$files = Get-ChildItem $Tools -Filter "*.ps1" -Recurse

foreach ($f in $files) {

    $txt = Get-Content $f.FullName -ErrorAction SilentlyContinue | Out-String
    $orig = $txt

    # 1) Fix ${name}: -> ${name}:
    $txt = [regex]::Replace(
        $txt,
        '\$([A-Za-z_]\w*):',
        '${$1}:'
    )

    # 2) Kill broken here-string examples inside notes
    $txt = [regex]::Replace(
        $txt,
        '(?ms)Note\s*=\s*''.*?@"
.*?"@.*?''',
        "Note = 'Here-string header must be on its own line. (example removed)',
        '# sanitised example',
        'Multiline'
    )

    if ($txt -ne $orig) {
        Set-Content -Path $f.FullName -Encoding UTF8 -Value $txt
        Write-Host "[PATCHED] $($f.Name)" -ForegroundColor Green
    }
}

# 4) Optional formatting (safe)
if (Get-Command Invoke-Formatter -ErrorAction SilentlyContinue) {
    Invoke-Formatter -Path $Tools -Recurse -ErrorAction SilentlyContinue
    Write-Host "[FORMAT] Invoke-Formatter applied" -ForegroundColor Cyan
}

# 5) ScriptAnalyzer audit
if (Get-Module -ListAvailable PSScriptAnalyzer) {
    $report = Invoke-ScriptAnalyzer -Path $Tools -Recurse |
              Sort-Object Severity,RuleName

    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $report | Out-File "$Out\ps_audit_$ts.txt"
    $report | ConvertTo-Json -Depth 4 | Out-File "$Out\ps_audit_$ts.json"

    Write-Host "[DONE] Audit written to $Out" -ForegroundColor Green
} else {
    Write-Host "[WARN] PSScriptAnalyzer not installed" -ForegroundColor Yellow
}

Write-Host "[SUCCESS] One-pass fix complete." -ForegroundColor Green



