# FIX_ALL_DEAD_BUTTONS.ps1
# Makes ALL null onPressed/onTap callbacks interactive (shows ComingSoon snackbar)
# Repo: C:\SIMON\simon_physio

param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

$pub = Join-Path $Repo "pubspec.yaml"
if(!(Test-Path $pub)){ throw "Missing pubspec.yaml at $pub" }

$pubRaw = Get-Content $pub -Raw
$mName = [regex]::Match($pubRaw, '(?m)^\s*name\s*:\s*([a-zA-Z0-9_]+)\s*$')
if(-not $mName.Success){ throw "Could not read app name from pubspec.yaml (name: ...)" }
$appName = $mName.Groups[1].Value.Trim()

$lib = Join-Path $Repo "lib"
if(!(Test-Path $lib)){ throw "Missing lib folder at $lib" }

# 1) Write ComingSoon helper
$coreUi = Join-Path $lib "core\ui"
Ensure-Dir $coreUi
$helper = Join-Path $coreUi "coming_soon.dart"

@"
import 'package:flutter/material.dart';

class ComingSoon {
  static void snack(BuildContext context, [String msg = 'Coming soon']) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}
"@ | Set-Content -LiteralPath $helper -Encoding UTF8

Write-Host "[OK] Wrote helper: $helper"

$importLine = "import 'package:$appName/core/ui/coming_soon.dart';"

# 2) Patch Dart files
$dartFiles = Get-ChildItem -Path $lib -Recurse -Filter "*.dart" |
  Where-Object {
    $_.FullName -notmatch "\\\\(build|\.dart_tool|\.idea|\.vscode|_BACKUPS|_PREMIUM_OUT)\\\\" -and
    $_.Name -notmatch "\.bak_" -and
    $_.Name -notmatch "GeneratedPluginRegistrant" -and
    $_.Name -notmatch "generated_plugin_registrant"
  }

$changed = 0
foreach($f in $dartFiles){
  $raw = Get-Content $f.FullName -Raw

  $needs = ($raw -match "(?m)\bonPressed\s*:\s*null\b") -or ($raw -match "(?m)\bonTap\s*:\s*null\b")
  if(-not $needs){ continue }

  # ensure import (put after flutter imports if possible, else top)
  if($raw -notmatch [regex]::Escape($importLine)){
    if($raw -match "(?m)^import\s+'package:flutter/"){
      $raw = [regex]::Replace($raw, "(?m)^(import\s+'package:flutter/[^']+'\s*;\s*)",
        "`$1`r`n$importLine`r`n", 1)
    } elseif ($raw -match "(?m)^import\s+"){
      $raw = $importLine + "`r`n" + $raw
    } else {
      $raw = $importLine + "`r`n`r`n" + $raw
    }
  }

  # Replace dead callbacks
  $raw2 = $raw
  $raw2 = [regex]::Replace($raw2, "(?m)\bonPressed\s*:\s*null\b", "onPressed: () { ComingSoon.snack(context); }")
  $raw2 = [regex]::Replace($raw2, "(?m)\bonTap\s*:\s*null\b", "onTap: () { ComingSoon.snack(context); }")

  if($raw2 -ne $raw){
    Set-Content -LiteralPath $f.FullName -Value $raw2 -Encoding UTF8
    $changed++
    Write-Host "[OK] Patched: $($f.FullName)"
  }
}

Write-Host ""
Write-Host "[DONE] Files patched: $changed"
Write-Host "Next: rebuild and run your Windows EXE to confirm all taps respond."
