# SIMON_AIO_INSTALLER_RELEASE.ps1
# One-click: patch theme -> pub get -> build windows release -> portable dist+zip+sha256
#           -> build installer EXE (Inno Setup) -> git commit/tag -> GitHub release (if GH auth available)
# Run from: C:\SIMON\simon_physio

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "✔ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }

# ---------------- CONFIG (edit only if needed) ----------------
$ProjectRoot = (Resolve-Path ".").Path
$FlutterBat  = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
$VsDevCmd    = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
$AppName     = "Simon Physio"
$ExeName     = "simon_physio.exe"
$Publisher   = "GrootForce"
# --------------------------------------------------------------

Info "Sanity checks..."
if (!(Test-Path "$ProjectRoot\pubspec.yaml")) { Fail "Run this from project root (where pubspec.yaml is)." }
if (!(Test-Path $FlutterBat)) { Fail "Flutter not found: $FlutterBat (update path in script)" }
if (!(Test-Path $VsDevCmd)) { Fail "VS Dev Cmd not found: $VsDevCmd (install VS Build Tools + VC Tools)" }

# Read version
$pubspecPath = "$ProjectRoot\pubspec.yaml"
$pubspec = Get-Content $pubspecPath -Raw
$versionLine = ($pubspec -split "`n" | Where-Object { $_ -match '^\s*version\s*:\s*' } | Select-Object -First 1)
if (-not $versionLine) { Fail "No version: line found in pubspec.yaml" }
$ver = ($versionLine -replace '^\s*version\s*:\s*', '').Trim()
$verSafe = $ver -replace '[^\w\.\+\-]', '_'
$verTag = ($ver -split '\+')[0]  # drop build number for tag
$tag = "v$verTag"
Info "Version: $ver  | Tag: $tag"

# Patch theme issues (CardThemeData + const issues)
$themePath = "$ProjectRoot\lib\core\theme\app_theme.dart"
if (Test-Path $themePath) {
  Info "Patching theme compile issues..."
  $theme = Get-Content $themePath -Raw

  # CardTheme -> CardThemeData (Flutter material changes)
  $patched = $theme `
    -replace '\bconst\s+CardTheme\s*\(', 'const CardThemeData(' `
    -replace '\bCardTheme\s*\(', 'CardThemeData('

  # If const still causes errors (non-const args), remove const on CardThemeData calls
  $patched = $patched -replace '\bconst\s+CardThemeData\s*\(', 'CardThemeData('

  if ($patched -ne $theme) {
    Set-Content -Path $themePath -Value $patched -Encoding UTF8
    Ok "Patched: $themePath"
  } else {
    Ok "No theme patch needed."
  }
} else {
  Warn "Theme file not found (skipped): $themePath"
}

# Ensure assets folder exists + safe pubspec assets entry
$demoDir = "$ProjectRoot\assets\demo"
if (!(Test-Path $demoDir)) {
  Info "Creating demo data pack..."
  New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
  Set-Content -Path "$demoDir\demo_patient_plan.json" -Encoding UTF8 -Value @"
{
  "patient": { "id": "demo-001", "name": "Demo Patient", "dob": "1990-01-01" },
  "plan": { "title": "Lower back mobility (Demo)", "exercises": [
    { "name": "Cat-Cow", "sets": 2, "reps": 10 },
    { "name": "Child's Pose", "sets": 2, "reps": 6 },
    { "name": "Glute Bridge", "sets": 3, "reps": 10 }
  ]}
}
"@
  Ok "Demo pack created."
}

$pubspec = Get-Content $pubspecPath -Raw
if ($pubspec -notmatch '^\s*assets\s*:\s*$'m -and $pubspec -notmatch '^\s*assets\s*:\s*\['m) {
  Info "Adding assets entry to pubspec.yaml (safe default)..."
  if ($pubspec -match '^\s*flutter\s*:\s*$'m) {
    $pubspec2 = $pubspec -replace '(^\s*flutter\s*:\s*$)', "`$1`n  assets:`n    - assets/"
  } else {
    $pubspec2 = $pubspec.TrimEnd() + "`n`nflutter:`n  assets:`n    - assets/`n"
  }
  Set-Content -Path $pubspecPath -Value $pubspec2 -Encoding UTF8
  Ok "pubspec.yaml updated with assets/"
}

# pub get
Info "flutter pub get..."
& $FlutterBat pub get

# Build Windows release via VS env
Info "Building Windows (Release)..."
$cmd = @"
`"$VsDevCmd`" -arch=x64 -host_arch=x64 && `"$FlutterBat`" build windows --release
"@
cmd.exe /c $cmd
if ($LASTEXITCODE -ne 0) { Fail "Flutter build failed." }

$exePath = "$ProjectRoot\build\windows\x64\runner\Release\$ExeName"
if (!(Test-Path $exePath)) { Fail "EXE not found at: $exePath" }
Ok "Built: $exePath"

# Prepare dist + zip + hash
$distRoot = "$ProjectRoot\dist"
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$distName = "SimonPhysio_${verSafe}_win64_${stamp}"
$portableDir = Join-Path $distRoot ($distName + "_portable")
$zipPath = Join-Path $distRoot ($distName + "_portable.zip")

Info "Creating portable folder..."
if (Test-Path $portableDir) { Remove-Item $portableDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $portableDir | Out-Null
Copy-Item -Path (Join-Path (Split-Path $exePath -Parent) "*") -Destination $portableDir -Recurse -Force

Set-Content -Path (Join-Path $portableDir "README.txt") -Encoding UTF8 -Value @"
$AppName (Windows Portable)
Version: $ver
Built: $(Get-Date)

Run: $ExeName
"@

Info "Zipping portable build..."
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $portableDir "*") -DestinationPath $zipPath -CompressionLevel Optimal
$zipHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
Set-Content -Path ($zipPath + ".sha256.txt") -Value $zipHash -Encoding ASCII
Ok "ZIP: $zipPath"
Ok "SHA256: $zipHash"

# Build installer via Inno Setup (auto-install via winget)
Info "Ensuring Inno Setup is installed..."
$inno = $null
$possible = @(
  "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
foreach ($p in $possible) { if (Test-Path $p) { $inno = $p; break } }

if (-not $inno) {
  Info "Installing Inno Setup via winget..."
  try {
    winget install --id JRSoftware.InnoSetup -e --source winget
  } catch {
    Warn "winget install failed. If Inno isn't installed, installer step will be skipped."
  }
  foreach ($p in $possible) { if (Test-Path $p) { $inno = $p; break } }
}

$installerExe = Join-Path $distRoot ($distName + "_Setup.exe")

if ($inno) {
  Info "Generating Inno Setup script..."
  $issPath = Join-Path $distRoot ($distName + ".iss")
  $appId = "{"+([guid]::NewGuid().ToString().ToUpper())+"}"

  # Inno: install everything from the Release folder (DLLs + data)
  $releaseDir = Split-Path $exePath -Parent

  Set-Content -Path $issPath -Encoding UTF8 -Value @"
#define MyAppName "$AppName"
#define MyAppVersion "$verTag"
#define MyAppPublisher "$Publisher"
#define MyAppExeName "$ExeName"

[Setup]
AppId=$appId
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir="$distRoot"
OutputBaseFilename="$($distName)_Setup"
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "$releaseDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
"@

  Info "Compiling installer..."
  & $inno $issPath | Out-Host

  if (Test-Path $installerExe) {
    $instHash = (Get-FileHash -Path $installerExe -Algorithm SHA256).Hash
    Set-Content -Path ($installerExe + ".sha256.txt") -Value $instHash -Encoding ASCII
    Ok "Installer: $installerExe"
    Ok "Installer SHA256: $instHash"
  } else {
    Warn "Installer EXE not found after compile (check Inno output)."
  }
} else {
  Warn "Inno Setup not available — skipping installer build."
}

# Git: commit changes if any (theme/pubspec/assets)
Info "Git: preparing commit/tag (if repo exists)..."
$gitOk = $true
try { git rev-parse --is-inside-work-tree | Out-Null } catch { $gitOk = $false }

if ($gitOk) {
  git add -A | Out-Null
  $status = (git status --porcelain)
  if ($status) {
    Info "Committing local changes..."
    git commit -m "Release prep: build fixes + assets (auto)" | Out-Host
  } else {
    Ok "No local changes to commit."
  }

  # Tag if not exists
  $tagExists = $false
  try { git rev-parse $tag | Out-Null; $tagExists = $true } catch { $tagExists = $false }
  if (-not $tagExists) {
    Info "Creating git tag $tag ..."
    git tag $tag | Out-Null
  } else {
    Warn "Tag already exists: $tag (won't recreate)."
  }

  # Push (best-effort)
  try {
    Info "Pushing commits + tags..."
    git push | Out-Host
    git push --tags | Out-Host
  } catch {
    Warn "git push failed (likely auth). Build artifacts are still created locally."
  }
} else {
  Warn "Not a git repo here — skipping commit/tag/push."
}

# GitHub Release (best-effort)
Info "GitHub Release: best-effort (needs gh auth or token)..."

# Ensure gh exists (auto install)
$gh = (Get-Command gh -ErrorAction SilentlyContinue)?.Source
if (-not $gh) {
  try {
    Info "Installing GitHub CLI (gh) via winget..."
    winget install --id GitHub.cli -e --source winget
    $gh = (Get-Command gh -ErrorAction SilentlyContinue)?.Source
  } catch {
    Warn "gh install failed. Skipping GitHub release."
  }
}

if ($gh) {
  # Check auth
  $authed = $false
  try {
    gh auth status | Out-Null
    $authed = $true
  } catch {
    $authed = $false
  }

  if ($authed -and $gitOk) {
    Info "Creating/updating GitHub release $tag ..."
    $notes = "Automated release build`n`n- Version: $ver`n- Windows portable zip + (optional) installer`n"

    $assets = @()
    if (Test-Path $zipPath) { $assets += $zipPath; $assets += ($zipPath + ".sha256.txt") }
    if (Test-Path $installerExe) { $assets += $installerExe; $assets += ($installerExe + ".sha256.txt") }

    # create (or overwrite assets by deleting + recreating)
    try {
      gh release view $tag | Out-Null
      Warn "Release already exists: $tag — uploading assets to it..."
      gh release upload $tag @assets --clobber | Out-Host
    } catch {
      gh release create $tag @assets -t "$AppName $verTag" -n $notes | Out-Host
    }

    Ok "GitHub release step complete."
  } else {
    Warn "Skipping GitHub release upload (gh not authed OR no git repo)."
    Warn "To make it fully zero-click next time, you must have gh already authenticated once on this PC."
  }
} else {
  Warn "gh not available — skipping GitHub release."
}

Write-Host ""
Ok "ALL DONE."
Write-Host "Portable folder: $portableDir" -ForegroundColor Green
Write-Host "Portable ZIP:    $zipPath" -ForegroundColor Green
if (Test-Path $installerExe) { Write-Host "Installer EXE:    $installerExe" -ForegroundColor Green }
Write-Host ""
