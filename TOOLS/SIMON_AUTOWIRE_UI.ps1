                    param($m)

$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

# --- Repo root ---
$repo = (Resolve-Path ".").Path
Set-Location $repo
OK "Repo: $repo"

$pub = Join-Path $repo "pubspec.yaml"
if (!(Test-Path $pub)) { FAIL "pubspec.yaml not found in $repo" }

# --- Read package name from pubspec.yaml (top-level name:) ---
$pubRaw = Get-Content -Raw -LiteralPath $pub
if ($pubRaw -notmatch "(?m)^\s*name\s*:\s*([a-zA-Z0-9_]+)\s*$") { FAIL "Could not read package name from pubspec.yaml" }
$pkg = $Matches[1]
OK "Package: $pkg"

# --- Verify new screens exist (created by your prior script) ---
$todayPath = Join-Path $repo "lib\src\features\plans\today_screen.dart"
$plansPath = Join-Path $repo "lib\src\features\plans\plans_screen.dart"
$reportsPath = Join-Path $repo "lib\src\features\reports\reports_screen.dart"

foreach ($p in @($todayPath, $plansPath, $reportsPath)) {
    if (!(Test-Path $p)) { FAIL "Missing expected UI file: $p  (Run SIMON_PHASE1_WIRE_UI.ps1 first)" }
}
OK "UI screens exist: Today/Plans/Reports"

# --- Imports (package: form works from anywhere) ---
$importToday = "import 'package:$pkg/src/features/plans/today_screen.dart';"
$importPlans = "import 'package:$pkg/src/features/plans/plans_screen.dart';"
$importReports = "import 'package:$pkg/src/features/reports/reports_screen.dart';"

# --- Scan all dart files and score likely nav/router owner ---
INFO "Scanning for navigation/router owner file..."
$dartFiles = Get-ChildItem -Path (Join-Path $repo "lib") -Recurse -Filter *.dart -File

if (!$dartFiles -or $dartFiles.Count -eq 0) { FAIL "No .dart files found under lib/" }

function Score-NavFile([string]$path) {
    $raw = Get-Content -Raw -LiteralPath $path

    $score = 0
    if ($raw -match "BottomNavigationBar") { $score += 40 }
    if ($raw -match "BottomNavigationBarItem") { $score += 20 }
    if ($raw -match "NavigationRail") { $score += 25 }
    if ($raw -match "IndexedStack") { $score += 15 }
    if ($raw -match "TabBar") { $score += 10 }
    if ($raw -match "MaterialApp\.router") { $score += 35 }
    if ($raw -match "GoRouter") { $score += 25 }
    if ($raw -match "StatefulShellRoute|ShellRoute") { $score += 25 }
    if ($raw -match "routes\s*:\s*\[") { $score += 20 }
    if ($raw -match "Scaffold") { $score += 5 }
    if ($raw -match "TodayScreen|PlansScreen|ReportsScreen") { $score -= 5 } # already patched maybe; don't over-bias

    # Bias common names
    $name = [IO.Path]::GetFileName($path).ToLowerInvariant()
    if ($name -match "router|app|shell|nav|dashboard") { $score += 8 }

    return $score
}

$ranked = $dartFiles | ForEach-Object {
    [PSCustomObject]@{ Path = $_.FullName; Score = (Score-NavFile $_.FullName) }
} | Sort-Object Score -Descending

$top = $ranked | Select-Object -First 10
INFO "Top router candidates:"
$top | ForEach-Object { Write-Host (" - {0} (score {1})" -f $_.Path, $_.Score) }

$candidate = $top | Where-Object { $_.Score -ge 40 } | Select-Object -First 1
if (!$candidate) {
    WARN "Could not confidently auto-pick a nav/router file (no strong match)."
    WARN "Open the top candidates above and pick the one that contains tabs/routes."
    FAIL "Auto-pick failed. (Re-run after you identify the correct file.)"
}

$navFile = $candidate.Path
OK "Chosen nav/router file: $navFile"

# --- Backup ---
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$bak = "$navFile.bak_$ts"
Copy-Item -LiteralPath $navFile -Destination $bak -Force
OK "Backup: $bak"

$raw = Get-Content -Raw -LiteralPath $navFile

# --- Helper: ensure imports exist (insert after last import) ---
function Ensure-Imports([string]$text) {
    $importsToAdd = @()
    if ($text -notmatch [regex]::Escape($importToday)) { $importsToAdd += $importToday }
    if ($text -notmatch [regex]::Escape($importPlans)) { $importsToAdd += $importPlans }
    if ($text -notmatch [regex]::Escape($importReports)) { $importsToAdd += $importReports }

    if ($importsToAdd.Count -eq 0) { return $text }

    if ($text -match "(?ms)^(.*?)(\r?\n)(?!.*^\s*import\s+)") {
        # Not reliable; instead:
    }

    # Insert after the last import line
    $m = [regex]::Match($text, "(?m)^(import\s+.+;\s*)+$")
    if ($m.Success) {
        $ins = ($importsToAdd -join "`r`n") + "`r`n"
        return $text.Substring(0, $m.Index + $m.Length) + "`r`n" + $ins + $text.Substring($m.Index + $m.Length)
    }

    # Fallback: insert at top
    $ins2 = ($importsToAdd -join "`r`n") + "`r`n`r`n"
    return $ins2 + $text
}

$raw = Ensure-Imports $raw

# --- Detect style: BottomNavigation vs GoRouter ---
$hasBottomNav = $raw -match "BottomNavigationBar"
$hasGoRouter = ($raw -match "MaterialApp\.router") -or ($raw -match "GoRouter") -or ($raw -match "routes\s*:\s*\[")

INFO ("Detected: " + ($(if ($hasBottomNav) { "BottomNavigation" }else { "-" }) ) + " / " + ($(if ($hasGoRouter) { "GoRouter" }else { "-" }) ))

$changed = $false

# --- Patch BottomNavigationBar style ---
if ($hasBottomNav) {

    # 1) Add screens to a list if we find one (common patterns)
    if ($raw -notmatch "TodayScreen\(") {
        # Try: final _screens = [
        $patterns = @(
            "final\s+_screens\s*=\s*\[",
            "final\s+screens\s*=\s*\[",
            "_screens\s*=\s*\[",
            "screens\s*=\s*\["
        )

        $patchedScreens = $false
        foreach ($pat in $patterns) {
            if ($raw -match $pat) {
                $raw = [regex]::Replace(
                    $raw,
                    $pat,
                    { param($m) $m.Value + "`r`n    const TodayScreen(),`r`n    const PlansScreen(),`r`n    const ReportsScreen()," },
                    1
                )
                $patchedScreens = $true
                $changed = $true
                OK "Inserted Today/Plans/Reports into screens list ($pat)"
                break
            }
        }

        if (-not $patchedScreens) {
            WARN "BottomNavigationBar detected but screens list not auto-found. We'll try nav items only."
        }
    }
    else {
        INFO "TodayScreen already referenced; skipping screens insertion."
    }

    # 2) Add BottomNavigationBarItem entries if not present
    if ($raw -notmatch 'label:\s*''Today''|label:\s*"Today"') {
        # Find the items: [ ... ] block
        $itemsPat = "(?ms)(items\s*:\s*const\s*\[\s*)(.*?)(\s*\]\s*,)"
        if ([regex]::IsMatch($raw, $itemsPat)) {
            $raw = [regex]::Replace($raw, $itemsPat, { param($m)
                    $head = $m.Groups[1].Value
                    $mid  = $m.Groups[2].Value
                    $tail = $m.Groups[3].Value
                    $inject = "      BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),`r`n" +
                              "      BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),`r`n" +
                              "      BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),`r`n"
                    # Put ours at top of items list
                    return $head + $inject + $mid + $tail
                }, 1)
            $changed = $true
            OK "Inserted Today/Plans/Reports BottomNavigationBarItem entries"
        }
        else {
            WARN "Could not locate BottomNavigationBar items list. You may need to add nav items manually."
        }
    } else {
        INFO "Nav labels already include Today; skipping item insertion."
    }
}

# --- Patch GoRouter style ---
if (-not $hasBottomNav -and $hasGoRouter) {

    # Insert GoRoute blocks into routes: [ ... ]
    if ($raw -notmatch "path:\s*'/today'") {
        $routesPat = "(?ms)(routes\s*:\s*\[\s*)(.*?)(\s*\]\s*,)"
        if ([regex]::IsMatch($raw, $routesPat)) {
            $raw = [regex]::Replace($raw, $routesPat, { param($m)
                    $head = $m.Groups[1].Value
                    $mid  = $m.Groups[2].Value
                    $tail = $m.Groups[3].Value

                    $inject = "GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),`r`n" +
                              "GoRoute(path: '/plans', builder: (context, state) => const PlansScreen()),`r`n" +
                              "GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),`r`n"
                    return $head + $inject + $mid + $tail
                }, 1)
            $changed = $true
            OK "Inserted /today /plans /reports GoRoutes"
        }
        else {
            WARN "GoRouter detected but could not locate a routes: [ ... ] list to patch."
            WARN "If your router is built differently (e.g., nested shell routes), paste the file and weâ€™ll patch exact."
        }
    }
    else {
        INFO "GoRouter already has /today; skipping route insertion."
    }
}

if (-not $changed) {
    WARN "No changes were applied (already patched or structure not detected)."
    WARN "Open: $navFile  and confirm where your tabs/routes are defined."
}
else {
    # Write back UTF-8 no BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($navFile, $raw, $utf8NoBom)
    OK "Patched: $navFile"
}

# --- Quick reminder build command ---
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) {
    $flutter = (& where.exe flutter 2>$null | Select-Object -First 1)
}
if ($flutter -and (Test-Path $flutter)) {
    INFO "Build test:"
    Write-Host ("  & `"{0}`" build windows --release" -f $flutter)
}
else {
    WARN "Flutter not found in script check; use your existing $flutter path to build."
}

OK "Done."






