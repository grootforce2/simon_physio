$ErrorActionPreference = "Stop"

$router = "C:\SIMON\simon_physio\lib\premium\premium_physio_os_app.dart"
$todayFile = "C:\SIMON\simon_physio\lib\src\features\plans\today_screen.dart"
$plansFile = "C:\SIMON\simon_physio\lib\src\features\plans\plans_screen.dart"
$reportsFile = "C:\SIMON\simon_physio\lib\src\features\reports\reports_screen.dart"

if (!(Test-Path $router)) { throw "Missing router: $router" }
if (!(Test-Path $todayFile)) { throw "Missing today screen file: $todayFile" }
if (!(Test-Path $plansFile)) { throw "Missing plans screen file: $plansFile" }
if (!(Test-Path $reportsFile)) { throw "Missing reports screen file: $reportsFile" }

# Backup
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $router "$router.bak_$stamp" -Force
Write-Host "[OK] Backup: $router.bak_$stamp" -ForegroundColor Green

function Get-FirstWidgetClassName($path) {
    $txt = Get-Content -Raw -LiteralPath $path
    # Prefer "class X extends ConsumerWidget/StatelessWidget/StatefulWidget"
    $m = [regex]::Match($txt, "class\s+([A-Za-z_]\w*)\s+extends\s+(ConsumerWidget|ConsumerStatefulWidget|StatelessWidget|StatefulWidget)\b")
    if ($m.Success) { return $m.Groups[1].Value }

    # fallback: any "class X extends ..."
    $m2 = [regex]::Match($txt, "class\s+([A-Za-z_]\w*)\s+extends\s+")
    if ($m2.Success) { return $m2.Groups[1].Value }

    throw "Could not detect widget class in $path"
}

$TodayClass = Get-FirstWidgetClassName $todayFile
$PlansClass = Get-FirstWidgetClassName $plansFile
$ReportsClass = Get-FirstWidgetClassName $reportsFile

Write-Host "[OK] Today widget:   $TodayClass" -ForegroundColor Cyan
Write-Host "[OK] Plans widget:   $PlansClass" -ForegroundColor Cyan
Write-Host "[OK] Reports widget: $ReportsClass" -ForegroundColor Cyan

$raw = Get-Content -Raw -LiteralPath $router

# Ensure imports exist (keep your existing relative style)
function Ensure-Import([string]$importLine) {
    if ($raw -notmatch [regex]::Escape($importLine)) {
        if ($raw -match "(?m)^(import\s+.+;\s*)+") {
            $raw = [regex]::Replace($raw, "(?m)^(import\s+.+;\s*)+", "`$0`r`n$importLine", 1)
        }
        else {
            $raw = "$importLine`r`n$raw"
        }
    }
}

Ensure-Import "import '../src/features/plans/today_screen.dart';"
Ensure-Import "import '../src/features/plans/plans_screen.dart';"
Ensure-Import "import '../src/features/reports/reports_screen.dart';"

# Replace any old/bad references to TodayScreen/PlansScreen/ReportsScreen with detected classes
$raw = $raw -replace "\bTodayScreen\s*\(", "$TodayClass("
$raw = $raw -replace "\bPlansScreen\s*\(", "$PlansClass("
$raw = $raw -replace "\bReportsScreen\s*\(", "$ReportsClass("

# ---- Hard reset the shell body + bottom nav ----
# We rebuild inside the main Scaffold in _PremiumShellState:
# - body: _tabs[index]
# - bottomNavigationBar: BottomNavigationBar(items: [...], currentIndex: index, onTap: ...)
#
# Strategy:
# 1) Ensure a _tabs list exists in _PremiumShellState; if not, inject it after "int index" or at start of State class.
# 2) Force Scaffold body and bottomNavigationBar to known-good.
# 3) Remove any lingering _BottomNav widget usage in this file.

# Inject/replace _tabs list in _PremiumShellState
# First find the State class block start
$stateClassPat = "(?s)(class\s+_PremiumShellState\s+extends\s+State<[^>]+>\s*\{)"
if ($raw -notmatch $stateClassPat) { throw "Could not find _PremiumShellState in router file." }

# If _tabs already exists, replace its contents. Else inject.
$tabsPat = "(?s)final\s+List<Widget>\s+_tabs\s*=\s*<Widget>\s*\[.*?\]\s*;"
$tabsDecl = "final List<Widget> _tabs = <Widget>[
    $TodayClass(),
    $PlansClass(),
    $ReportsClass(),
  ];"

if ($raw -match $tabsPat) {
    $raw = [regex]::Replace($raw, $tabsPat, $tabsDecl, 1)
}
else {
    # inject after index declaration if present, else right after class open brace
    if ($raw -match "(?m)^\s*int\s+index\s*=\s*\d+\s*;\s*$") {
        $raw = [regex]::Replace($raw, "(?m)^\s*int\s+index\s*=\s*\d+\s*;\s*$", "`$0`r`n  $tabsDecl", 1)
    }
    else {
        $raw = [regex]::Replace($raw, $stateClassPat, "`$1`r`n  int index = 0;`r`n  $tabsDecl", 1)
    }
}

# Force Scaffold body to body: _tabs[index]
$raw = [regex]::Replace($raw, "(?s)body:\s*.*?,\s*bottomNavigationBar:", "body: _tabs[index],`r`n          bottomNavigationBar:", 1)

# Replace ANY bottomNavigationBar: ... with known-good BottomNavigationBar (handles wide ? null : etc.)
$bnKnownGood = @"
bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => setState(() => index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),
            ],
          ),
# sanitised example
# Replace conditional bottom nav lines like: bottomNavigationBar: wide ? null : _BottomNav(...)
$raw = [regex]::Replace($raw, "(?m)^\s*bottomNavigationBar:\s*.*$", $bnKnownGood.TrimEnd(), 1)

# Remove any _BottomNav widget class definitions that might now be broken
$raw = [regex]::Replace($raw, "(?s)\nclass\s+_BottomNav\b.*?\n\}\s*\n", "`r`n", 1)

# Clean up obvious "dangling list fragments": lines that are just "]," or ")," hanging alone
$raw = [regex]::Replace($raw, "(?m)^\s*\]\s*,\s*$", "", 0)
$raw = [regex]::Replace($raw, "(?m)^\s*\)\s*,\s*$", "", 0)

Set-Content -LiteralPath $router -Value $raw -Encoding UTF8
Write-Host "[OK] HARD FIXED: $router" -ForegroundColor Green
Write-Host "[NEXT] flutter clean; flutter pub get; flutter build windows --release" -ForegroundColor Yellow



