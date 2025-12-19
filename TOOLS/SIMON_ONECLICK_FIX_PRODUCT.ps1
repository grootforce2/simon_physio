$ErrorActionPreference = "Stop"

$repo = "C:\SIMON\simon_physio"
$router = Join-Path $repo "lib\premium\premium_physio_os_app.dart"
$pubspec = Join-Path $repo "pubspec.yaml"
$dist = Join-Path $repo "DIST"

if (!(Test-Path $repo)) { throw "Missing repo: $repo" }
if (!(Test-Path $pubspec)) { throw "Missing pubspec.yaml: $pubspec" }
if (!(Test-Path (Split-Path $router))) { throw "Missing folder: $(Split-Path $router)" }

# Find flutter.bat (puro path you use, or fallback to PATH)
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { $flutter = "flutter" }

# Get package name from pubspec.yaml
$pub = Get-Content -Raw -LiteralPath $pubspec
if ($pub -notmatch "(?m)^\s*name:\s*([A-Za-z0-9_]+)\s*$") {
    throw "Couldn't detect package name from pubspec.yaml (name: ...)"
}
$pkg = $Matches[1]

# Backup router
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (Test-Path $router) {
    Copy-Item $router "$router.bak_$stamp" -Force
    Write-Host "[OK] Backup: $router.bak_$stamp" -ForegroundColor Green
}

# Create DIST
New-Item -ItemType Directory -Force -Path $dist | Out-Null

# NOTE:
# - Uses package imports for phase screens so it works regardless of where this premium file sits.
# - Aliases legacy premium reports to avoid name collision with Phase-1 ReportsScreen.
# - Replaces ALL the broken _SideRail etc with a clean NavigationRail implementation.
# - Keeps the "premium desktop feel" (rail for wide screens, bottom bar for narrow).
$dart = @"
import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/intake_forms_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reports_screen.dart' as legacy_reports;
import 'screens/settings_screen.dart';

import 'package:$pkg/src/features/plans/today_screen.dart';
import 'package:$pkg/src/features/plans/plans_screen.dart';
import 'package:$pkg/src/features/reports/reports_screen.dart';

class PremiumPhysioOSApp extends StatelessWidget {
  const PremiumPhysioOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D4FF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simon Physio â€” Premium',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      home: const PremiumShell(),
    );
  }
}

class PremiumShell extends StatefulWidget {
  const PremiumShell({super.key});

  @override
  State<PremiumShell> createState() => _PremiumShellState();
}

class _PremiumShellState extends State<PremiumShell> {
  int index = 0;

  late final List<_NavDef> _nav = <_NavDef>[
    _NavDef('Today', Icons.today, () => TodayScreen()),
    _NavDef('Plans', Icons.list_alt, () => PlansScreen()),
    _NavDef('Reports', Icons.show_chart, () => ReportsScreen()),

    // Premium legacy sections (kept)
    _NavDef('Dashboard', Icons.dashboard_rounded, () => const DashboardScreen()),
    _NavDef('Clients', Icons.people_alt_rounded, () => const ClientsScreen()),
    _NavDef('Calendar', Icons.calendar_month_rounded, () => const CalendarScreen()),
    _NavDef('Exercises', Icons.fitness_center_rounded, () => const ExercisesScreen()),
    _NavDef('Programs', Icons.playlist_add_check_rounded, () => const ProgramsScreen()),
    _NavDef('Intake Forms', Icons.assignment_rounded, () => const IntakeFormsScreen()),
    _NavDef('Progress', Icons.insights_rounded, () => const ProgressScreen()),
    _NavDef('Legacy Reports', Icons.summarize_rounded, () => const legacy_reports.ReportsScreen()),
    _NavDef('Settings', Icons.settings_rounded, () => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;

        final body = _nav[index].builder();

        return Scaffold(
          body: Row(
            children: [
              if (wide)
                _PremiumRail(
                  index: index,
                  onTap: (i) => setState(() => index = i),
                  nav: _nav,
                ),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : BottomNavigationBar(
                  currentIndex: index.clamp(0, 2),
                  onTap: (i) => setState(() => index = i),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
                    BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),
                    BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),
                  ],
                ),
        );
      },
    );
  }
}

class _NavDef {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  _NavDef(this.label, this.icon, this.builder);
}

class _PremiumRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavDef> nav;

  const _PremiumRail({
    required this.index,
    required this.onTap,
    required this.nav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF0E141C),
        border: Border(right: BorderSide(color: Color(0xFF1A2330))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _BrandHeader(),
          const SizedBox(height: 10),
          Expanded(
            child: NavigationRail(
              backgroundColor: const Color(0xFF0E141C),
              selectedIndex: index,
              onDestinationSelected: onTap,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in nav)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: _FooterHint(),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        border: Border.all(color: const Color(0xFF1A2330)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.35)),
            ),
            child: Icon(Icons.health_and_safety_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simon Physio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Premium OS', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Tip: Use Today for quick actions, Plans for programs, Reports for outcomes.',
      style: TextStyle(fontSize: 12, color: Colors.white70),
    );
  }
}
# sanitised example
Set-Content -LiteralPath $router -Value $dart -Encoding UTF8
Write-Host "[OK] Wrote clean product shell: $router" -ForegroundColor Green

# Build
Write-Host "[BUILD] flutter clean" -ForegroundColor Cyan
& $flutter clean

Write-Host "[BUILD] flutter pub get" -ForegroundColor Cyan
& $flutter pub get

Write-Host "[BUILD] flutter build windows --release" -ForegroundColor Cyan
& $flutter build windows --release

# Package
$winOut = Join-Path $repo "build\windows\x64\runner\Release"
if (!(Test-Path $winOut)) { throw "Windows output missing: $winOut" }

$zip = Join-Path $dist "simon_physio_windows_release_$stamp.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $winOut "*") -DestinationPath $zip -Force

Write-Host "[OK] BUILD DONE" -ForegroundColor Green
Write-Host "EXE FOLDER: $winOut" -ForegroundColor Green
Write-Host "ZIP:        $zip" -ForegroundColor Green



