$ErrorActionPreference = "Stop"

$repo = "C:\SIMON\simon_physio"
$pubspec = Join-Path $repo "pubspec.yaml"
$dist = Join-Path $repo "DIST"

if (!(Test-Path $repo)) { throw "Missing repo: $repo" }
if (!(Test-Path $pubspec)) { throw "Missing pubspec.yaml: $pubspec" }

$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { $flutter = "flutter" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

function Write-File([string]$path, [string]$content) {
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path $path) { Copy-Item $path "$path.bak_$stamp" -Force }
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}

# --- 1) Ensure required deps exist in pubspec ---
$raw = Get-Content -Raw -LiteralPath $pubspec

if ($raw -notmatch "(?m)^\s*dependencies:\s*$") {
    throw "pubspec.yaml missing 'dependencies:' block"
}

function Ensure-DepLine([string]$depName, [string]$versionLine) {
    if (${script}:raw -match "(?m)^\s*$depName\s*:") { return }

    # Insert after the first "dependencies:" line.
    $insert = "dependencies:`n  ${depName}: ${versionLine}"
    ${script}:raw = [regex]::Replace(
        ${script}:raw,
        "(?m)^dependencies:\s*$",
        $insert,
        1
    )
}

Ensure-DepLine "fl_chart" "^0.68.0"
Ensure-DepLine "uuid" "^4.4.2"
Ensure-DepLine "sqflite" "^2.3.3+1"
Ensure-DepLine "sqflite_common_ffi" "^2.3.3"
Ensure-DepLine "path" "^1.9.0"

Write-File $pubspec $raw
Write-Host "[OK] Patched pubspec.yaml deps (fl_chart/uuid/sqflite/ffi/path)" -ForegroundColor Green

# --- 2) Create missing patients screen (stub) ---
$patientsPath = Join-Path $repo "lib\src\features\patients\patients_screen.dart"
$patientsDart = @"
import 'package:flutter/material.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Patients (Coming soon)',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
# sanitised example
Write-File $patientsPath $patientsDart
Write-Host "[OK] Added stub: $patientsPath" -ForegroundColor Green

# --- 3) Add providers stubs expected by screens ---
$providersPath = Join-Path $repo "lib\src\data\providers.dart"
$providersDart = @"
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Minimal stubs so UI compiles. Replace with real repos/providers later.
final patientsProvider = Provider<List<Object>>((ref) => const <Object>[]);
final exercisesProvider = Provider<List<Object>>((ref) => const <Object>[]);
# sanitised example
Write-File $providersPath $providersDart
Write-Host "[OK] Added stub providers: $providersPath" -ForegroundColor Green

# --- 4) Patch screens to import stubs + fix patients import paths ---
function Ensure-Import([string]$file, [string]$importLine) {
    if (!(Test-Path $file)) { return }
    $t = Get-Content -Raw -LiteralPath $file
    if ($t -match [regex]::Escape($importLine)) { return }

    if ($t -match "(?m)^(import .+;(\r?\n))+") {
        $t = [regex]::Replace($t, "(?m)^(import .+;(\r?\n))+", "`$0$importLine`n", 1)
    }
    else {
        $t = "$importLine`n$t"
    }
    Write-File $file $t
}

function Fix-PatientsImport([string]$file) {
    if (!(Test-Path $file)) { return }
    $t = Get-Content -Raw -LiteralPath $file
    $t2 = $t
    $t2 = $t2 -replace "import\s+'lib/src/features/patients/patients_screen\.dart';", "import 'package:simon_physio/src/features/patients/patients_screen.dart';"
    $t2 = $t2 -replace "import\s+'src/features/patients/patients_screen\.dart';", "import 'package:simon_physio/src/features/patients/patients_screen.dart';"
    Write-File $file $t2
}

$today = Join-Path $repo "lib\src\features\plans\today_screen.dart"
$plans = Join-Path $repo "lib\src\features\plans\plans_screen.dart"
$reports = Join-Path $repo "lib\src\features\reports\reports_screen.dart"

Ensure-Import $today   "import 'package:simon_physio/src/data/providers.dart';"
Ensure-Import $plans   "import 'package:simon_physio/src/data/providers.dart';"
Ensure-Import $reports "import 'package:simon_physio/src/data/providers.dart';"

Fix-PatientsImport $today
Fix-PatientsImport $plans
Fix-PatientsImport $reports

Write-Host "[OK] Screen imports patched (providers + patients)" -ForegroundColor Green

# --- 5) Patch DB for desktop: sqflite_common_ffi ---
$dbPath = Join-Path $repo "lib\src\data\db.dart"
if (Test-Path $dbPath) {
    $dbNew = @"
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'simon_physio.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)');
      },
    );

    return _db!;
  }
}
# sanitised example
    Write-File $dbPath $dbNew
    Write-Host "[OK] Patched db.dart for desktop (sqflite_common_ffi)" -ForegroundColor Green
}
else {
    Write-Host "[WARN] db.dart not found at $dbPath (skipped)" -ForegroundColor Yellow
}

# --- 6) Build ---
Write-Host "[BUILD] flutter clean" -ForegroundColor Cyan
& $flutter clean

Write-Host "[BUILD] flutter pub get" -ForegroundColor Cyan
& $flutter pub get

$log = Join-Path $dist "windows_build_$stamp.log"
Write-Host "[BUILD] flutter build windows --release (logging to $log)" -ForegroundColor Cyan

# capture full output
& $flutter build windows --release *>&1 | Tee-Object -FilePath $log

# --- 7) Package (only if output exists) ---
$winOut = Join-Path $repo "build\windows\x64\runner\Release"
if (!(Test-Path $winOut)) {
    Write-Host "[FAIL] Build did not produce: $winOut" -ForegroundColor Red
    Write-Host "[INFO] Open log: $log" -ForegroundColor Yellow
    throw "Windows output missing: $winOut"
}

$zip = Join-Path $dist "simon_physio_windows_release_$stamp.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $winOut "*") -DestinationPath $zip -Force

Write-Host "[OK] BUILD DONE" -ForegroundColor Green
Write-Host "EXE FOLDER: $winOut" -ForegroundColor Green
Write-Host "ZIP:        $zip" -ForegroundColor Green
Write-Host "LOG:        $log" -ForegroundColor Green




