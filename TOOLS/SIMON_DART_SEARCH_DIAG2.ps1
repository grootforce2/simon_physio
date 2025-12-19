$ErrorActionPreference = "Stop"

function HDR($m) { Write-Host "`n=== $m ===" -ForegroundColor Yellow }
function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }

$repo = (Resolve-Path ".").Path
$targets = Get-ChildItem -Path (Join-Path $repo "lib") -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue
INFO "Dart files: $(@($targets).Count)"

function S($title, $pattern) {
    HDR $title
    $hits = $targets | Select-String -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue
    INFO "Matches: $(@($hits).Count)"
    if ($hits) {
        $hits | Select-Object -First 250 | ForEach-Object { "{0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }
    }
}

S "STRING PATHS (assets/...)" "assets/"
S "FILE EXTENSIONS (.png/.jpg/.svg/.mp4/etc)" ".png|.jpg|.jpeg|.webp|.gif|.svg|.mp4|.mov|.json|.ttf|.otf"
S "FLUTTER ICONS (Icons.)" "Icons\."
S "CUSTOM WRAPPER CLUES (Image|Icon|Svg|Video|Asset|Media)" "AppImage|AppIcon|Svg|Video|Asset|Media|Thumbnail|Thumb|ImagePath|iconPath|assetPath"

HDR "Done"


