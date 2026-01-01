$ErrorActionPreference = "Stop"

# -------------------------
# Config
# -------------------------
$root = "C:\SIMON\simon_physio"
$tools = Join-Path $root "TOOLS"
$dist  = Join-Path $root "DIST"

$flutter = Join-Path $env:USERPROFILE ".puro\envs\stable\flutter\bin\flutter.bat"
if (!(Test-Path $flutter)) { throw "Flutter not found at: $flutter" }

New-Item -ItemType Directory -Force -Path $tools, $dist | Out-Null

# -------------------------
# Documents paths
# -------------------------
$docs = [Environment]::GetFolderPath("MyDocuments")
$gfBase = Join-Path $docs "SimonPhysio"
$mediaBase = Join-Path $gfBase "media\exercises"
$imgDir = Join-Path $mediaBase "images"
$vidDir = Join-Path $mediaBase "videos"
$seedDir = Join-Path $gfBase "seed"
$seedJsonPath = Join-Path $seedDir "exercises_seed_v1.json"

New-Item -ItemType Directory -Force -Path $imgDir, $vidDir, $seedDir | Out-Null

Write-Host "[OK] Media folders:" -ForegroundColor Green
Write-Host "  Images: $imgDir"
Write-Host "  Videos: $vidDir"
Write-Host "  Seed  : $seedJsonPath"

# -------------------------
# Helpers
# -------------------------
function New-ExerciseSteps([string]$name, [string]$region, [string]$equip) {
  return @(
    "Set up: choose a stable position; keep spine neutral; breathe normally.",
    "Start: engage the target area ($region) gently - no sharp pain.",
    "Perform: slow controlled movement through comfortable range (2-3 sec each way).",
    "Reps/Sets: 8-12 reps x 2-3 sets (or as prescribed).",
    "Progression: add load/time only if pain stays <= 3/10 and form is clean.",
    "Stop if pain spikes, numbness, dizziness, or swelling increases."
  )
}

function New-SafetyCues([string]$region) {
  return @(
    "No sharp pain. Mild discomfort is ok; lingering >24h means reduce intensity.",
    "Keep breathing - do not hold breath.",
    "Slow and controlled. No bouncing or jerking.",
    "Stop and seek advice if tingling, numbness, chest pain, or dizziness.",
    "Maintain alignment: knees over toes; shoulders down; neutral spine."
  )
}

function New-Variant([string]$type) {
  $notes = ""
  $reps = ""
  switch ($type) {
    "elderly" { $notes="Use support, smaller range, slower tempo; prioritize balance."; $reps="6-10 reps x 1-2 sets, longer rest" }
    "postop"  { $notes="Follow protocol; keep pain low; avoid end-range strain early."; $reps="5-8 reps x 1-2 sets, very controlled" }
    "sports"  { $notes="Progress load/tempo; add stability then power once cleared."; $reps="8-15 reps x 3-5 sets, progress load" }
    default   { $notes="General"; $reps="8-12 reps x 2-3 sets" }
  }
  return @{ type=$type; notes=$notes; reps=$reps }
}

# -------------------------
# 50 exercise defs
# -------------------------
$defs = @(
  @{name="Ankle Pumps"; region="Ankle/Calf"; equipment="None"; difficulty="Easy"},
  @{name="Heel Raises"; region="Calf"; equipment="None"; difficulty="Easy"},
  @{name="Seated March"; region="Hip Flexors"; equipment="Chair"; difficulty="Easy"},
  @{name="Sit-to-Stand"; region="Quads/Glutes"; equipment="Chair"; difficulty="Easy"},
  @{name="Wall Push-Up"; region="Chest/Shoulder"; equipment="Wall"; difficulty="Easy"},
  @{name="Scapular Squeezes"; region="Upper Back"; equipment="None"; difficulty="Easy"},
  @{name="Chin Tucks"; region="Neck"; equipment="None"; difficulty="Easy"},
  @{name="Pendulum Swing"; region="Shoulder"; equipment="None"; difficulty="Easy"},
  @{name="Shoulder Flexion (Stick)"; region="Shoulder"; equipment="Stick/Towel"; difficulty="Easy"},
  @{name="Hamstring Stretch (Supine)"; region="Hamstrings"; equipment="Towel"; difficulty="Easy"},
  @{name="Quad Stretch (Standing)"; region="Quads"; equipment="Wall/Support"; difficulty="Easy"},
  @{name="Glute Bridge"; region="Glutes"; equipment="Mat"; difficulty="Easy"},
  @{name="Clamshell"; region="Hip/Glutes"; equipment="Mat"; difficulty="Easy"},
  @{name="Side-Lying Hip Abduction"; region="Hip"; equipment="Mat"; difficulty="Easy"},
  @{name="Bird Dog"; region="Core/Back"; equipment="Mat"; difficulty="Medium"},
  @{name="Dead Bug"; region="Core"; equipment="Mat"; difficulty="Medium"},
  @{name="Plank (Knees)"; region="Core"; equipment="Mat"; difficulty="Medium"},
  @{name="Wall Slide"; region="Shoulder"; equipment="Wall"; difficulty="Medium"},
  @{name="Theraband Row"; region="Upper Back"; equipment="Band"; difficulty="Medium"},
  @{name="Theraband External Rotation"; region="Rotator Cuff"; equipment="Band"; difficulty="Medium"},
  @{name="Theraband Internal Rotation"; region="Rotator Cuff"; equipment="Band"; difficulty="Medium"},
  @{name="Biceps Curl"; region="Biceps"; equipment="Dumbbell/Band"; difficulty="Easy"},
  @{name="Triceps Extension"; region="Triceps"; equipment="Band"; difficulty="Medium"},
  @{name="Wrist Flexion/Extension"; region="Wrist"; equipment="Light weight"; difficulty="Easy"},
  @{name="Grip Squeeze"; region="Hand"; equipment="Ball/Putty"; difficulty="Easy"},
  @{name="Calf Stretch (Wall)"; region="Calf"; equipment="Wall"; difficulty="Easy"},
  @{name="Hip Flexor Stretch"; region="Hip Flexors"; equipment="Mat"; difficulty="Easy"},
  @{name="Thoracic Rotation (Open Book)"; region="Mid Back"; equipment="Mat"; difficulty="Easy"},
  @{name="Cat-Cow"; region="Spine"; equipment="Mat"; difficulty="Easy"},
  @{name="Lumbar Rotation (Supine)"; region="Low Back"; equipment="Mat"; difficulty="Easy"},
  @{name="Step-Up"; region="Quads/Glutes"; equipment="Step"; difficulty="Medium"},
  @{name="Lateral Step-Down"; region="Knee/Hip"; equipment="Step"; difficulty="Hard"},
  @{name="Single-Leg Balance"; region="Ankle/Hip"; equipment="None"; difficulty="Medium"},
  @{name="Mini Squat"; region="Knee/Glutes"; equipment="None"; difficulty="Medium"},
  @{name="Lunge (Supported)"; region="Legs"; equipment="Support"; difficulty="Hard"},
  @{name="Side Step (Band)"; region="Hip/Glutes"; equipment="Band"; difficulty="Hard"},
  @{name="Heel-to-Toe Walk"; region="Balance"; equipment="None"; difficulty="Medium"},
  @{name="Shoulder Abduction (Band)"; region="Shoulder"; equipment="Band"; difficulty="Medium"},
  @{name="Shoulder Scaption"; region="Shoulder"; equipment="Light weight"; difficulty="Medium"},
  @{name="Prone Y-T-W"; region="Upper Back"; equipment="Mat"; difficulty="Hard"},
  @{name="Cervical Rotation AROM"; region="Neck"; equipment="None"; difficulty="Easy"},
  @{name="Isometric Quad Set"; region="Quads"; equipment="Towel"; difficulty="Easy"},
  @{name="Straight Leg Raise"; region="Hip/Quads"; equipment="Mat"; difficulty="Medium"},
  @{name="Seated Knee Extension"; region="Quads"; equipment="Chair"; difficulty="Easy"},
  @{name="Hamstring Curl (Band)"; region="Hamstrings"; equipment="Band"; difficulty="Medium"},
  @{name="Glute Med Activation (Side Plank Knees)"; region="Hip/Glutes"; equipment="Mat"; difficulty="Hard"},
  @{name="Forearm Pronation/Supination"; region="Forearm"; equipment="Light weight"; difficulty="Easy"},
  @{name="Finger Extensions"; region="Hand"; equipment="Rubber band"; difficulty="Easy"},
  @{name="Neural Glide (Median Nerve)"; region="Nerve Mobility"; equipment="None"; difficulty="Medium"}
)

# -------------------------
# Build seed pack JSON
# -------------------------
$exercises = @()
$idx = 1
foreach ($d in $defs) {
  $exercises += @{
    id = ("EX" + $idx.ToString("000"))
    name = $d.name
    region = $d.region
    equipment = $d.equipment
    difficulty = $d.difficulty
    steps = (New-ExerciseSteps -name $d.name -region $d.region -equip $d.equipment)
    safety = (New-SafetyCues -region $d.region)
    media = @{ images=@(); video="" }
    variants = @((New-Variant "elderly"), (New-Variant "postop"), (New-Variant "sports"))
    tags = @("seed","v1")
    createdUtc = (Get-Date).ToUniversalTime().ToString("o")
  }
  $idx++
}

$seedPack = @{
  schema="simon_physio.exercise_seed.v1"
  generatedUtc=(Get-Date).ToUniversalTime().ToString("o")
  count=$exercises.Count
  exercises=$exercises
  notes=@(
    "Local-first media: use the UI to attach files from Documents\SimonPhysio\media\exercises\images|videos.",
    "Phase-2 will add licensed media packs with provenance records."
  )
}

$seedJson = $seedPack | ConvertTo-Json -Depth 20
Set-Content -Path $seedJsonPath -Value $seedJson -Encoding UTF8
Write-Host "[OK] Seed JSON written: $seedJsonPath" -ForegroundColor Green

# -------------------------
# Copy seed into project assets + pubspec patch
# -------------------------
$seedAssetRel = "assets\seed\exercises_seed_v1.json"
$assetAbs = Join-Path $root $seedAssetRel
New-Item -ItemType Directory -Force -Path (Split-Path $assetAbs -Parent) | Out-Null
Copy-Item -Force $seedJsonPath $assetAbs
Write-Host "[OK] Copied seed into project: $seedAssetRel" -ForegroundColor Green

$pubspec = Join-Path $root "pubspec.yaml"
if (Test-Path $pubspec) {
  $praw = Get-Content $pubspec -Raw
  if ($praw -notmatch "(?m)^\s*flutter:\s*$") { throw "pubspec.yaml missing flutter: block" }

  if ($praw -notmatch "(?m)^\s*assets:\s*$" -and $praw -notmatch "(?m)^\s{2}assets:\s*$") {
    # Insert assets under flutter:
    $praw = [regex]::Replace($praw, "(?m)^flutter:\s*$", "flutter:`r`n  assets:`r`n    - $seedAssetRel", 1)
  } else {
    if ($praw -notmatch [regex]::Escape($seedAssetRel)) {
      # Add line in existing assets block
      $praw = $praw -replace "(?m)^\s{2}assets:\s*$", "  assets:`r`n    - $seedAssetRel"
    }
  }

  Set-Content -Path $pubspec -Value $praw -Encoding UTF8
  Write-Host "[OK] pubspec.yaml includes seed asset." -ForegroundColor Green
}

# -------------------------
# Build + package + launch
# -------------------------
Push-Location $root
try {
  Write-Host "`n==> flutter clean" -ForegroundColor Cyan
  & $flutter clean | Out-Null

  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  & $flutter pub get | Out-Host

  Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
  & $flutter build windows --release | Out-Host

  $exe = Join-Path $root "build\windows\x64\runner\Release\simon_physio.exe"
  if (!(Test-Path $exe)) { throw "EXE not found at: $exe" }

  Copy-Item -Force $exe (Join-Path $dist "simon_physio.exe")

  $zip = Join-Path $dist "simon_physio_windows_release.zip"
  if (Test-Path $zip) { Remove-Item $zip -Force }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $releaseDir = Split-Path $exe -Parent
  [System.IO.Compression.ZipFile]::CreateFromDirectory($releaseDir, $zip)

  Write-Host "`n[OK] DONE" -ForegroundColor Green
  Write-Host " EXE : $exe"
  Write-Host " COPY: $dist\simon_physio.exe"
  Write-Host " ZIP : $zip"
  Write-Host " SEED(Documents): $seedJsonPath"
  Write-Host " MEDIA: $mediaBase"

  Start-Process "explorer.exe" $mediaBase | Out-Null
  Start-Sleep -Milliseconds 300
  Start-Process $exe | Out-Null
}
finally { Pop-Location }

Write-Host "`nNEXT: Test saving" -ForegroundColor Gray
Write-Host "1) Run app -> Add exercise -> Add images (local) / Pick video (local)" -ForegroundColor Gray
Write-Host "2) Confirm files exist in:" -ForegroundColor Gray
Write-Host "   $imgDir" -ForegroundColor Gray
Write-Host "   $vidDir" -ForegroundColor Gray
