[CmdletBinding()]
param(
    [string]$Root = "C:\SIMON\simon_physio\TOOLS",
    [string]$OutDir = "C:\SIMON\simon_physio\DIST\script_audit",
    [switch]$FixFormat
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
    if (!(Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Try-InvokeFormatter([string]$path) {
    # Prefer Invoke-Formatter if your PSScriptAnalyzer version supports it
    $cmd = Get-Command Invoke-Formatter -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        try {
            $formatted = Invoke-Formatter -ScriptDefinition (Get-Content -Raw $path)
            if ($null -ne $formatted -and $formatted.Trim().Length -gt 0) {
                Set-Content -Encoding UTF8 -Path $path -Value $formatted
            }
        }
        catch { }
    }
}

Ensure-Dir $OutDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportJson = Join-Path $OutDir "ps_audit_$timestamp.json"
$reportTxt = Join-Path $OutDir "ps_audit_$timestamp.txt"

$files = Get-ChildItem -Path $Root -Recurse -File -Include *.ps1, *.psm1, *.psd1

Write-Host "[SCAN] Files: $($files.Count) under $Root" -ForegroundColor Cyan

# ---- PSScriptAnalyzer (lint) ----
$analyzerResults = @()
try {
    if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
        $analyzerResults = Invoke-ScriptAnalyzer -Path $Root -Recurse -Severity Warning, Error -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "[WARN] PSScriptAnalyzer not found. Install-Module PSScriptAnalyzer -Scope CurrentUser -Force" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARN] PSScriptAnalyzer failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- Orion extra checks (common foot-guns) ----
$extraFindings = @()

foreach ($f in $files) {
    $raw = Get-Content -Raw $f.FullName

    # 1) param() not at top (script-level)
    if ($raw -match '\bparam\s*\(' -and $raw -notmatch '(?is)^\s*(?:<#.*?#>\s*)?(?:\s*\[CmdletBinding\(\)\]\s*)?\s*param\s*\(') {
        $extraFindings += [pscustomobject]@{
            File     = $f.FullName
            Rule     = "ParamNotAtTop"
            Severity = "Error"
            Note     = "param() should be at the top of a script (after optional comment block + [CmdletBinding()])."
        }
    }

    # 2) Variable interpolation with colon: `${name}:  (your crash)
    if ($raw -match '\$[A-Za-z_]\w*:' ) {
        $extraFindings += [pscustomobject]@{
            File     = $f.FullName
            Rule     = "VarColonInterpolation"
            Severity = "Error"
            Note     = 'Here-string header must be on its own line. (example removed)'
        }
    }

    # 4) External command call without LASTEXITCODE check (heuristic)
    if ($raw -match '(?im)^\s*&\s*\$flutter\s+build' -and $raw -notmatch 'LASTEXITCODE') {
        $extraFindings += [pscustomobject]@{
            File     = $f.FullName
            Rule     = "NoLastExitCodeCheck"
            Severity = "Warning"
            Note     = "External command invoked; consider checking `$LASTEXITCODE and failing fast."
        }
    }

    # 5) Remove-Item -Recurse without -Force (often hangs on readonly)
    if ($raw -match 'Remove-Item\s+.*-Recurse' -and $raw -notmatch '-Force') {
        $extraFindings += [pscustomobject]@{
            File     = $f.FullName
            Rule     = "RecurseWithoutForce"
            Severity = "Warning"
            Note     = "Remove-Item -Recurse without -Force can fail/hang on read-only files."
        }
    }

    if ($FixFormat) { Try-InvokeFormatter $f.FullName }
}

# Combine results
$all = @()

foreach ($r in $analyzerResults) {
    $all += [pscustomobject]@{
        File     = $r.ScriptName
        Line     = $r.Line
        Column   = $r.Column
        Severity = $r.Severity
        Rule     = $r.RuleName
        Message  = $r.Message
        Source   = "PSScriptAnalyzer"
    }
}

foreach ($x in $extraFindings) {
    $all += [pscustomobject]@{
        File     = $x.File
        Line     = $null
        Column   = $null
        Severity = $x.Severity
        Rule     = $x.Rule
        Message  = $x.Note
        Source   = "OrionExtra"
    }
}

$sorted = $all | Sort-Object Severity, File, Line

$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding UTF8 -Path $reportTxt
$sorted | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $reportJson

Write-Host "[DONE] Report written:" -ForegroundColor Green
Write-Host "  TXT : $reportTxt"
Write-Host "  JSON: $reportJson"
Write-Host ""
Write-Host "Tip: -FixFormat uses Invoke-Formatter (if available in your PSScriptAnalyzer version)." -ForegroundColor DarkGray





