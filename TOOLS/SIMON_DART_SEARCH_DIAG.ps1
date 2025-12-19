$ErrorActionPreference = "Stop"

function HDR($m) { Write-Host "`n=== $m ===" -ForegroundColor Yellow }
function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor DarkYellow }

$repo = (Resolve-Path ".").Path
Set-Location $repo
HDR "Simon Physio Dart Search Diagnostic"
INFO "Repo: $repo"
INFO "PowerShell: $($PSVersionTable.PSVersion)"

# Collect Dart files robustly (PS5-safe). Also search outside lib if lib is weird/empty.
$dartLib = Get-ChildItem -Path (Join-Path $repo "lib") -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue
INFO "Dart files under lib/: $(@($dartLib).Count)"

if (@($dartLib).Count -eq 0) {
    WARN "No .dart files found under lib/. Either lib is empty OR your code is elsewhere."
    $dartAll = Get-ChildItem -Path $repo -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\build\\|\\\.dart_tool\\|\\windows\\flutter\\ephemeral\\|\\linux\\flutter\\ephemeral\\|\\android\\|\\ios\\|\\macos\\' }
    INFO "Dart files in repo (excluding build/ephemeral/mobile): $(@($dartAll).Count)"
    if (@($dartAll).Count -gt 0) {
        INFO "First 30 Dart files found:"
        $dartAll | Select-Object -First 30 FullName | Format-Table -AutoSize
        $targets = $dartAll
    }
    else {
        throw "No Dart files found anywhere useful. Project structure is off."
    }
}
else {
    $targets = $dartLib
    INFO "First 30 Dart files in lib/:"
    $targets | Select-Object -First 30 FullName | Format-Table -AutoSize
}

function RunSearch($title, $pattern) {
    HDR $title
    $hits = $targets | Select-String -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
    $cnt = @($hits).Count
    INFO "Matches: $cnt"
    if ($cnt -gt 0) {
        $hits | Select-Object -First 200 | ForEach-Object {
            "{0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
        }
        OK "Shown first 200 matches"
    }
    else {
        WARN "No matches for: $pattern"
    }
}

RunSearch "ASSET LOADERS" "AssetImage(|Image.asset(|rootBundle.load(|loadString(|SvgPicture.asset(|VideoPlayerController.asset("
RunSearch "NETWORK/FILE/DB LOADERS" "http://|https://|NetworkImage(|Image.network(|CachedNetworkImage|File(|FileImage(|readAsBytes|readAsString|isar|path_provider"
RunSearch "UI IMAGE/ICON/VIDEO USAGE" "Image(|Icon(|SvgPicture|VideoPlayerController|DecorationImage"

HDR "Done"
OK "Paste the three sections back here if you want me to diagnose why assets look blank."


