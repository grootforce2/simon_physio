$ErrorActionPreference = "Stop"

$router = "C:\SIMON\simon_physio\lib\premium\premium_physio_os_app.dart"
if (!(Test-Path $router)) { throw "Missing file: $router" }

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

# --- 1) Ensure imports exist (path is correct for /lib/premium -> /lib/src)
EnsureImport "import '../src/features/plans/today_screen.dart';"
EnsureImport "import '../src/features/plans/plans_screen.dart';"
EnsureImport "import '../src/features/reports/reports_screen.dart';"

# --- 2) Force Scaffold body to be a switch(index) map if not already
# Find "Scaffold(" block and replace only the body: ... line.
# We handle:
#   body: something,
# and replace that one property with a safe switch body.

$switchBody = @"
body: () {
  switch (index) {
    case 0:
      return TodayScreen();
    case 1:
      return PlansScreen();
    case 2:
      return ReportsScreen();
    default:
      return TodayScreen();
  }
}(),
# sanitised example
if ($raw -match "(?s)Scaffold\s*\(.*?\)") {
    # Replace first occurrence of "body: ...," inside Scaffold
    if ($raw -match "(?s)Scaffold\s*\((.*?)\)") {
        $scaffoldBlock = $Matches[0]
        if ($scaffoldBlock -match "(?m)^\s*body\s*:\s*.+,\s*$") {
            $newScaffold = [regex]::Replace($scaffoldBlock, "(?m)^\s*body\s*:\s*.+,\s*$", "          $switchBody", 1)
            $raw = $raw.Replace($scaffoldBlock, $newScaffold)
        }
        elseif ($scaffoldBlock -notmatch "body:") {
            # No body found, inject it after "Scaffold("
            $newScaffold = [regex]::Replace($scaffoldBlock, "Scaffold\s*\(", "Scaffold(`r`n          $switchBody", 1)
            $raw = $raw.Replace($scaffoldBlock, $newScaffold)
        }
        else {
            # body exists but multiline / complex; do a safer targeted insert by replacing the first "body:" occurrence until next comma at same indent
            $raw = [regex]::Replace($raw, "(?s)(Scaffold\s*\(.*?\n)(\s*body\s*:\s*)(.*?)(,\s*\n)", "`$1          $switchBody`r`n", 1)
        }
    }
}
else {
    throw "Couldn't find Scaffold(...) in premium_physio_os_app.dart"
}

# --- 3) Patch _BottomNav items to have 3 tabs
# We locate _BottomNav build and find BottomNavigationBar(items: [ ... ])
# If no items list, we inject a new BottomNavigationBar with items.

$itemsBlock = @"
items: const [
  BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
  BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),
  BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),
],
# sanitised example
if ($raw -match "(?s)class\s+_BottomNav\b.*?\{.*?\n\}") {
    $bottomNavClass = $Matches[0]

    if ($bottomNavClass -match "(?s)BottomNavigationBar\s*\((.*?)\)") {
        $bnb = $Matches[0]

        if ($bnb -match "(?s)items\s*:\s*(const\s*)?\[.*?\]\s*,") {
            # Replace existing items list
            $newBnb = [regex]::Replace($bnb, "(?s)items\s*:\s*(const\s*)?\[.*?\]\s*,", $itemsBlock, 1)
            $newBottomNavClass = $bottomNavClass.Replace($bnb, $newBnb)
            $raw = $raw.Replace($bottomNavClass, $newBottomNavClass)
        }
        else {
            # Inject items block right after BottomNavigationBar(
            $newBnb = [regex]::Replace($bnb, "BottomNavigationBar\s*\(", "BottomNavigationBar(`r`n            $itemsBlock", 1)
            $newBottomNavClass = $bottomNavClass.Replace($bnb, $newBnb)
            $raw = $raw.Replace($bottomNavClass, $newBottomNavClass)
        }
    }
    else {
        Write-Host "[WARN] _BottomNav exists but BottomNavigationBar(...) not found inside it." -ForegroundColor Yellow
    }
}
else {
    Write-Host "[WARN] _BottomNav class not found. Tabs may be defined elsewhere." -ForegroundColor Yellow
}

Set-Content -LiteralPath $router -Value $raw -Encoding UTF8

Write-Host "[OK] Patched router + nav: $router" -ForegroundColor Green
Write-Host "[NEXT] Run: flutter clean; flutter pub get; flutter build windows --release" -ForegroundColor Cyan



