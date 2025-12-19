$ErrorActionPreference = "Stop"

$router = "C:\SIMON\simon_physio\lib\premium\premium_physio_os_app.dart"
if (!(Test-Path $router)) { throw "Missing: $router" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $router "$router.bak_$stamp" -Force
Write-Host "[OK] Backup: $router.bak_$stamp" -ForegroundColor Green

$raw = Get-Content -Raw -LiteralPath $router

# Replace everything from "class PremiumPhysioOSApp" up to just before "class _SideRail"
$start = $raw.IndexOf("class PremiumPhysioOSApp")
$side = $raw.IndexOf("class _SideRail")

if ($start -lt 0) { throw "Can't find: class PremiumPhysioOSApp" }
if ($side -lt 0) { throw "Can't find: class _SideRail" }
if ($side -le $start) { throw "Unexpected order: _SideRail before PremiumPhysioOSApp" }

$prefix = $raw.Substring(0, $start)
$suffix = $raw.Substring($side)

# Ensure imports for the new screens exist (we'll just add them at the top if missing)
function EnsureImport([string]$line) {
    if ($prefix -notmatch [regex]::Escape($line)) {
        $prefix = $line + "`r`n" + $prefix
    }
}

# Make sure Material icons are available via flutter/material.dart already in your file.
# Add correct imports for phase-1 screens:
EnsureImport "import '../src/features/plans/today_screen.dart';"
EnsureImport "import '../src/features/plans/plans_screen.dart';"
EnsureImport "import '../src/features/reports/reports_screen.dart';"

$replacement = @"
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
        cardTheme: const CardTheme(
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

  // Phase-1 tabs
  final List<Widget> _tabs = <Widget>[
    TodayScreen(),
    PlansScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;

        return Scaffold(
          body: Row(
            children: [
              if (wide)
                _SideRail(
                  index: index,
                  onTap: (i) => setState(() => index = i),
                ),
              Expanded(child: _tabs[index]),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : BottomNavigationBar(
                  currentIndex: index,
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
# sanitised example
$raw2 = $prefix + $replacement + "`r`n`r`n" + $suffix

Set-Content -LiteralPath $router -Value $raw2 -Encoding UTF8
Write-Host "[OK] Rewrote Premium shell top (kept _SideRail and below intact): $router" -ForegroundColor Green
Write-Host "[NEXT] flutter clean; flutter pub get; flutter build windows --release" -ForegroundColor Yellow



