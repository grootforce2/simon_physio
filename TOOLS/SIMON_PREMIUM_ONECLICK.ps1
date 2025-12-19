# SIMON_PREMIUM_ONECLICK.ps1
# One script: Premium UI + Build Windows Release + Package Portable + ZIP
# Works even if flutter isn't on PATH (detects puro, etc.)
# Uses robocopy to avoid "file is being used" copy errors.

    param(
        [Parameter(Mandatory = $true)][string]$FlutterBat,
        [Parameter(Mandatory = $true)][string]$WorkingDir,
        [Parameter(Mandatory = $true)][string[]]$Args
    )

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Say($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m) { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Die($m) { Write-Host $m -ForegroundColor Red; throw $m }

function Resolve-Root {
    # Script is in ...\TOOLS\ so project root is parent folder
    $toolsDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $toolsDir "..")).Path
}

function Find-Flutter {
    $candidates = @()

    # 1) Environment override
    if (${env}:FLUTTER -and (Test-Path ${env}:FLUTTER)) { $candidates += ${env}:FLUTTER }

    # 2) puro stable default (your machine)
    $puro = Join-Path ${env}:USERPROFILE ".puro\envs\stable\flutter\bin\flutter.bat"
    if (Test-Path $puro) { $candidates += $puro }

    # 3) PATH
    $cmd = (Get-Command flutter -ErrorAction SilentlyContinue)
    if ($cmd) {
        $candidates += $cmd.Source
    }

    # 4) Search any puro envs quickly
    $puroRoot = Join-Path ${env}:USERPROFILE ".puro\envs"
    if (Test-Path $puroRoot) {
        Get-ChildItem $puroRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $fb = Join-Path $_.FullName "flutter\bin\flutter.bat"
            if (Test-Path $fb) { $candidates += $fb }
        }
    }

    $candidates = $candidates | Select-Object -Unique
    foreach ($c in $candidates) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }

    return $null
}

function Run-Flutter {

    $argLine = $Args -join " "
    Say "==> flutter $argLine"
    Push-Location $WorkingDir
    try {
        # IMPORTANT: no illegal "@args.Split()" â€” args already an array
        & $FlutterBat @Args
        if ($LASTEXITCODE -ne 0) { Die "Flutter failed: flutter $argLine (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }
}

function Backup-File {
    param([string]$Path, [string]$BackupDir)
    if (Test-Path $Path) {
        $name = Split-Path $Path -Leaf
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $dest = Join-Path $BackupDir "$name.$ts.bak"
        Copy-Item $Path $dest -Force
        Ok "Backed up: $name -> $(Split-Path $dest -Leaf)"
    }
}

function Write-PremiumDashboard {
    param([string]$LibDir)

    $file = Join-Path $LibDir "premium_dashboard.dart"

    @'
import 'package:flutter/material.dart';

class PremiumDashboard extends StatelessWidget {
  const PremiumDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget pill(String text, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    Widget card({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.20),
              scheme.surface,
              scheme.tertiary.withOpacity(0.14),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.sports_handball_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Simon Physio", style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          const Text("Premium Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: "Settings",
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Hero
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(
                        "Clean, clinical, and fast.\nNo junk. Just outcomes.",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.15, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          pill("Programs", Icons.view_list_rounded),
                          pill("Exercises", Icons.fitness_center_rounded),
                          pill("Clients", Icons.people_alt_rounded),
                          pill("Notes", Icons.note_alt_outlined),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    children: [
                      card(
                        title: "Client List",
                        subtitle: "Search, filter, and open a profile",
                        icon: Icons.people_alt_rounded,
                        onTap: () {},
                      ),
                      const SizedBox(height: 14),
                      card(
                        title: "Exercise Library",
                        subtitle: "Video, cues, progressions",
                        icon: Icons.fitness_center_rounded,
                        onTap: () {},
                      ),
                      const SizedBox(height: 14),
                      card(
                        title: "Session Notes",
                        subtitle: "SOAP notes + export-ready",
                        icon: Icons.note_alt_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(height: 14),
                      card(
                        title: "Programs",
                        subtitle: "Plan templates + printouts",
                        icon: Icons.view_list_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
'@ | Set-Content -LiteralPath $file -Encoding UTF8

    Ok "Premium UI written: $file"
}

function Force-PremiumMain {
    param([string]$LibDir, [string]$BackupDir)

    $main = Join-Path $LibDir "main.dart"
    Backup-File -Path $main -BackupDir $BackupDir

    @'
import 'package:flutter/material.dart';
import 'premium_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimonPremiumApp());
}

class SimonPremiumApp extends StatelessWidget {
  const SimonPremiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simon Physio',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C5CFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C5CFF),
        brightness: Brightness.dark,
      ),
      home: const PremiumDashboard(),
    );
  }
}
'@ | Set-Content -LiteralPath $main -Encoding UTF8

    Ok "Forced premium entry: $main"
}

function Kill-LockingProcesses {
    param([string[]]$Names)

    foreach ($n in $Names) {
        try {
            Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
                Warn "Killing process locking files: $($_.ProcessName) (PID $($_.Id))"
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {}
    }
}

function Robocopy-Mirror {
    param([string]$Source, [string]$Dest)

    if (!(Test-Path $Source)) { Die "Release folder missing: $Source" }

    if (Test-Path $Dest) {
        try { Remove-Item $Dest -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null

    # /MIR mirrors, /R retry count, /W wait seconds
    # Exit codes 0-7 are "success" by robocopy rules
    $cmd = @(
        "robocopy",
        "`"$Source`"",
        "`"$Dest`"",
        "/MIR", "/R:6", "/W:1",
        "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
    ) -join " "

    Say "==> Packaging portable (robocopy mirror)"
    cmd.exe /c $cmd | Out-Null

    $rc = $LASTEXITCODE
    if ($rc -gt 7) { Die "Robocopy failed with exit code $rc (locked file or permission issue)." }

    Ok "Portable folder ready: $Dest"
}

function Zip-Folder {
    param([string]$Folder, [string]$ZipPath)

    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue }

    # Prefer 7z if installed (faster / better). Otherwise use Compress-Archive.
    $sevenZip = (Get-Command 7z -ErrorAction SilentlyContinue)
    if ($sevenZip) {
        Say "==> Zipping with 7z: $ZipPath"
        & $sevenZip.Source a -tzip -mx=5 $ZipPath (Join-Path $Folder "*") | Out-Null
        if ($LASTEXITCODE -ne 0) { Die "7z zip failed (exit $LASTEXITCODE)" }
    }
    else {
        Say "==> Zipping with Compress-Archive: $ZipPath"
        Compress-Archive -Path (Join-Path $Folder "*") -DestinationPath $ZipPath -Force
    }

    Ok "ZIP created: $ZipPath"
}

# ------------------ MAIN ------------------
$ROOT = Resolve-Root
$LIB = Join-Path $ROOT "lib"
$DIST = Join-Path $ROOT "DIST"
$BACKUPS = Join-Path $ROOT "TOOLS\_BACKUPS"

New-Item -ItemType Directory -Force -Path $DIST | Out-Null
New-Item -ItemType Directory -Force -Path $BACKUPS | Out-Null

Say "==> Project: $ROOT"

$FLUTTER = Find-Flutter
if (-not $FLUTTER) {
    Die "Flutter not found. Install Flutter or Puro, OR set env var FLUTTER to flutter.bat full path."
}
Ok "Flutter: $FLUTTER"

# Premium UI + forced entry
Write-PremiumDashboard -LibDir $LIB
Force-PremiumMain -LibDir $LIB -BackupDir $BACKUPS

# Make sure windows desktop is enabled (won't hurt if already)
Run-Flutter -FlutterBat $FLUTTER -WorkingDir $ROOT -Args @("config", "--enable-windows-desktop") | Out-Null

# Clean build
Run-Flutter -FlutterBat $FLUTTER -WorkingDir $ROOT -Args @("clean")
Run-Flutter -FlutterBat $FLUTTER -WorkingDir $ROOT -Args @("pub", "get")

# Build windows release
Run-Flutter -FlutterBat $FLUTTER -WorkingDir $ROOT -Args @("build", "windows", "--release")

# Kill anything that might lock flutter_windows.dll during packaging
Kill-LockingProcesses -Names @("simon_physio", "flutter", "dart", "dartaotruntime")

# Package portable
$release = Join-Path $ROOT "build\windows\x64\runner\Release"
$portable = Join-Path $DIST "windows_release_portable"
$zipPath = Join-Path $DIST "simon_physio_windows_release_portable.zip"

Robocopy-Mirror -Source $release -Dest $portable

# Also copy the exe to DIST root for convenience
$exeSrc = Join-Path $portable "simon_physio.exe"
$exeDst = Join-Path $DIST "simon_physio_premium.exe"
if (Test-Path $exeSrc) {
    Copy-Item $exeSrc $exeDst -Force
    Ok "EXE copied: $exeDst"
}
else {
    Warn "EXE not found in portable folder (unexpected)."
}

# Zip
Zip-Folder -Folder $portable -ZipPath $zipPath

Ok "==============================="
Ok "DONE âœ… Premium build + portable packaged"
Ok "PORTABLE: $portable"
Ok "ZIP     : $zipPath"
Ok "EXE     : $exeDst"
Ok "BACKUPS : $BACKUPS"
Ok "==============================="

