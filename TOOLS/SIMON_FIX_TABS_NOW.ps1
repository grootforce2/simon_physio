$ErrorActionPreference = "Stop"

$router = "C:\SIMON\simon_physio\lib\premium\premium_physio_os_app.dart"
if (!(Test-Path $router)) { throw "Missing file: $router" }

# Backup first (always)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$bak = "$router.bak_$ts"
Copy-Item -LiteralPath $router -Destination $bak -Force
Write-Host "[OK] Backup: $bak" -ForegroundColor Green

$raw = Get-Content -Raw -LiteralPath $router

function EnsureImport([string]$line) {
    if ($raw -notmatch [regex]::Escape($line)) {
        if ($raw -match "(?m)^(import\s+.+;\s*)+") {
            $raw = [regex]::Replace($raw, "(?m)^(import\s+.+;\s*)+", "`$0`r`n$line", 1)
        }
        else {
            $raw = "$line`r`n$raw"
        }
    }
}

# --- Imports (correct relative paths from lib/premium -> lib/src)
EnsureImport "import '../src/features/plans/today_screen.dart';"
EnsureImport "import '../src/features/plans/plans_screen.dart';"
EnsureImport "import '../src/features/reports/reports_screen.dart';"

# --- Helper: find a class block by brace matching
function Get-ClassBlockRange([string]$text, [string]$className) {
    $idx = $text.IndexOf("class $className")
    if ($idx -lt 0) { return $null }

    $braceStart = $text.IndexOf("{", $idx)
    if ($braceStart -lt 0) { throw "Found class $className but no opening brace." }

    $depth = 0
    for ($i = $braceStart; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($ch -eq "{") { $depth++ }
        elseif ($ch -eq "}") { $depth--; if ($depth -eq 0) { return @{Start = $idx; End = $i } } }
    }
    throw "Brace match failed for class $className"
}

# --- 1) Ensure we have a clean tabs list inside the main State class
# Weâ€™ll inject just after the opening brace of the State class.
# Try common state class names first; if not found, locate the first "extends State<" class.
$stateClassName = $null
$stateCandidates = @("_PremiumPhysioOsAppState", "_PremiumPhysioOSAppState", "_PremiumPhysioAppState")
foreach ($c in $stateCandidates) {
    if ($raw -match "class\s+$([regex]::Escape($c))\s+extends\s+State<") { $stateClassName = $c; break }
}
if (-not $stateClassName) {
    if ($raw -match "class\s+(_\w+)\s+extends\s+State<") {
        $stateClassName = $Matches[1]
    }
    else {
        throw "Couldn't locate a State class (class _X extends State<...>)."
    }
}

$stateRange = Get-ClassBlockRange $raw $stateClassName
$stateBlock = $raw.Substring($stateRange.Start, ($stateRange.End - $stateRange.Start + 1))

if ($stateBlock -notmatch "(?s)final\s+_tabs\s*=") {
    $inject = @"
// Phase-1 tabs (autowired)
  final List<Widget> _tabs = <Widget>[
    TodayScreen(),
    PlansScreen(),
    ReportsScreen(),
  ];
# sanitised example
    $openBrace = $stateBlock.IndexOf("{")
    if ($openBrace -lt 0) { throw "State class block missing '{' unexpectedly." }
    $stateBlock2 = $stateBlock.Insert($openBrace + 1, "`r`n$inject")
    $raw = $raw.Remove($stateRange.Start, ($stateRange.End - $stateRange.Start + 1)).Insert($stateRange.Start, $stateBlock2)
    Write-Host "[OK] Injected _tabs list into $stateClassName" -ForegroundColor Green
}
else {
    Write-Host "[OK] _tabs already exists in $stateClassName" -ForegroundColor Green
}

# Refresh state block after edits
$stateRange = Get-ClassBlockRange $raw $stateClassName
$stateBlock = $raw.Substring($stateRange.Start, ($stateRange.End - $stateRange.Start + 1))

# --- 2) Force Scaffold body to use _tabs[index]
# Replace any existing "body: ..." line inside the first Scaffold(...) in this file.
$scaffoldMatch = [regex]::Match($raw, "(?s)Scaffold\s*\(.*?\)")
if (!$scaffoldMatch.Success) { throw "Couldn't find Scaffold(...) in file." }

$scaffold = $scaffoldMatch.Value

# Replace a single-line body:, or inject if missing.
if ($scaffold -match "(?m)^\s*body\s*:\s*.+,\s*$") {
    $scaffold2 = [regex]::Replace($scaffold, "(?m)^\s*body\s*:\s*.+,\s*$", "          body: _tabs[index],", 1)
}
elseif ($scaffold -notmatch "(?m)^\s*body\s*:") {
    $scaffold2 = [regex]::Replace($scaffold, "Scaffold\s*\(", "Scaffold(`r`n          body: _tabs[index],", 1)
}
else {
    # Body exists but multiline/complex; do a safer replacement of the first "body:" property chunk
    $scaffold2 = [regex]::Replace($scaffold, "(?s)(\s*body\s*:\s*)(.*?)(,\s*\n)", "          body: _tabs[index],`r`n", 1)
}

$raw = $raw.Substring(0, $scaffoldMatch.Index) + $scaffold2 + $raw.Substring($scaffoldMatch.Index + $scaffoldMatch.Length)
Write-Host "[OK] Scaffold body wired to _tabs[index]" -ForegroundColor Green

# --- 3) Replace the entire _BottomNav class with a guaranteed working version
$bnRange = Get-ClassBlockRange $raw "_BottomNav"
if ($bnRange -eq $null) {
    Write-Host "[WARN] class _BottomNav not found. Skipping BottomNav replacement." -ForegroundColor Yellow
}
else {
    $bnTemplate = @"
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),
      ],
    );
  }
}
# sanitised example
    $raw = $raw.Remove($bnRange.Start, ($bnRange.End - $bnRange.Start + 1)).Insert($bnRange.Start, $bnTemplate)
    Write-Host "[OK] Replaced _BottomNav with a clean BottomNavigationBar" -ForegroundColor Green
}

# --- 4) Clean up obvious broken injection debris from earlier patch attempts
# Remove any stray "items: const [ ... ]," blocks that might have been injected into random spots
$raw = [regex]::Replace($raw, "(?s)\n\s*items:\s*const\s*\[\s*BottomNavigationBarItem.*?\]\s*,\s*\n", "`r`n", 50)

Set-Content -LiteralPath $router -Value $raw -Encoding UTF8
Write-Host "[OK] Fixed: $router" -ForegroundColor Green
Write-Host "[NEXT] flutter clean; flutter pub get; flutter build windows --release" -ForegroundColor Cyan




