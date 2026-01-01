param(
  [string]$OutRoot = "$env:USERPROFILE\Documents\SimonPhysio\exercise_pack",
  [int]$Frames = 24,
  [int]$Fps = 12,
  [int]$LoopSeconds = 12,     # long loop gif
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
function Write-Json([string]$path, $obj){
  $json = $obj | ConvertTo-Json -Depth 30
  Set-Content -Path $path -Value $json -Encoding UTF8
}

# ---- 0) Output structure ----
$ts   = (Get-Date).ToString("yyyyMMdd_HHmmss")
$base = Join-Path $OutRoot $ts

$dirData = Join-Path $base "data"
$dirImg  = Join-Path $base "media\images"
$dirGif  = Join-Path $base "media\gifs"
$dirDoc  = Join-Path $base "docs"

Ensure-Dir $dirData
Ensure-Dir $dirImg
Ensure-Dir $dirGif
Ensure-Dir $dirDoc

# ---- 1) Exercises seed (expand anytime) ----
$exercises = @(
  @{
    id="ex_001"; name="Shoulder Pendulum"; body_region="Shoulder"
    tags=@("mobility","gentle","warmup"); difficulty="Easy"; equipment=@("None")
    setup="Lean forward with one hand supported on a table or chair. Let the other arm hang relaxed."
    steps=@(
      "Relax the hanging arm and shoulder.",
      "Gently swing forward/back like a pendulum.",
      "Then swing side-to-side.",
      "Then make small circles each direction."
    )
    dosage=@{ sets=2; reps="30-60s each direction"; rest_seconds=30 }
    cues=@("Keep it relaxed. No forcing.","Start small, then slightly bigger if comfortable.")
    safety=@{
      stop_if=@("sharp pain","new numbness/tingling","dizziness","chest pain","symptoms worsening")
      consult_if=@("recent fracture/dislocation","severe swelling","fever","night pain worsening")
    }
  },
  @{
    id="ex_002"; name="Scapular Squeeze"; body_region="Upper Back"
    tags=@("posture","strength","desk"); difficulty="Easy"; equipment=@("None")
    setup="Sit or stand tall. Arms relaxed by sides."
    steps=@(
      "Draw shoulder blades back and down.",
      "Hold 3 seconds.",
      "Release slowly."
    )
    dosage=@{ sets=2; reps=10; rest_seconds=30 }
    cues=@("Neck stays long.","Donâ€™t shrug.","Think: pockets to back pockets.")
    safety=@{
      stop_if=@("sharp pain","tingling")
      consult_if=@("recent neck injury")
    }
  },
  @{
    id="ex_003"; name="Wall Push-Up"; body_region="Chest/Shoulder"
    tags=@("strength","beginner"); difficulty="Easy"; equipment=@("Wall")
    setup="Stand armâ€™s length from a wall, hands on wall at shoulder height."
    steps=@(
      "Keep body straight from head to heels.",
      "Bend elbows and bring chest toward the wall.",
      "Push back to start."
    )
    dosage=@{ sets=2; reps=8; rest_seconds=45 }
    cues=@("Move slow.","Keep elbows ~45Â° from body.")
    safety=@{
      stop_if=@("sharp pain","worsening symptoms")
      consult_if=@("recent shoulder surgery","unstable shoulder")
    }
  },
  @{
    id="ex_004"; name="Bodyweight Squat (Chair Tap)"; body_region="Hips/Knees"
    tags=@("strength","legs"); difficulty="Easy"; equipment=@("Chair")
    setup="Stand in front of a chair, feet shoulder-width."
    steps=@(
      "Hinge hips back, bend knees, lower toward chair.",
      "Lightly tap chair (donâ€™t fully sit).",
      "Stand up by driving through heels."
    )
    dosage=@{ sets=2; reps=8; rest_seconds=60 }
    cues=@("Knees track over toes.","Chest proud.","Go only as low as comfortable.")
    safety=@{
      stop_if=@("sharp knee pain","dizziness")
      consult_if=@("recent knee surgery","locking/catching")
    }
  }
)

Write-Json (Join-Path $dirData "exercises_v1.json") $exercises

# Also write a simple Notion/Sheet import CSV
$csvPath = Join-Path $dirData "exercises_import_v1.csv"
"ID,Name,Body Region,Tags,Difficulty,Equipment,Setup,Steps,Dosage,Cues,Stop If,Consult If" | Set-Content -Path $csvPath -Encoding UTF8
foreach($e in $exercises){
  $steps = ($e.steps -join " | ") -replace '"','""'
  $tags  = ($e.tags  -join ";") -replace '"','""'
  $equip = ($e.equipment -join ";") -replace '"','""'
  $dose  = ("sets={0}; reps={1}; rest_s={2}" -f $e.dosage.sets,$e.dosage.reps,$e.dosage.rest_seconds) -replace '"','""'
  $cues  = ($e.cues -join " | ") -replace '"','""'
  $stop  = ($e.safety.stop_if -join " | ") -replace '"','""'
  $cons  = ($e.safety.consult_if -join " | ") -replace '"','""'
  $line = '"' + ($e.id -replace '"','""') + '","' +
          ($e.name -replace '"','""') + '","' +
          ($e.body_region -replace '"','""') + '","' +
          $tags + '","' +
          ($e.difficulty -replace '"','""') + '","' +
          $equip + '","' +
          (($e.setup) -replace '"','""') + '","' +
          $steps + '","' +
          $dose + '","' +
          $cues + '","' +
          $stop + '","' +
          $cons + '"'
  Add-Content -Path $csvPath -Value $line -Encoding UTF8
}

# ---- 2) Python availability ----
$py = (Get-Command python -ErrorAction SilentlyContinue)
if(-not $py){
  $py = (Get-Command py -ErrorAction SilentlyContinue)
  if(-not $py){ throw "Python not found. Install Python 3 (winget: winget install -e --id Python.Python.3.12) then rerun." }
}

# ---- 3) Ensure Pillow installed (for PNG + GIF) ----
Write-Host "==> Checking Python Pillow..."
$check = @"
import sys
try:
  import PIL
  print("PIL_OK")
except Exception as e:
  print("PIL_MISSING")
"@
$p = New-TemporaryFile
Set-Content -Path $p.FullName -Value $check -Encoding UTF8

$pyCmd = $py.Source
$out = & $pyCmd $p.FullName
Remove-Item $p.FullName -Force -ErrorAction SilentlyContinue

if(($out | Out-String).Trim() -ne "PIL_OK"){
  Write-Host "==> Installing Pillow (one-time)..."
  & $pyCmd -m pip install --upgrade pip | Out-Null
  & $pyCmd -m pip install pillow | Out-Null
}

# ---- 4) Generate 2D hero PNG + animated GIF per exercise ----
Write-Host "==> Generating exercise images + long-loop GIFs..."
$pyGen = @"
import os, math, json
from PIL import Image, ImageDraw, ImageFont

BASE     = r"$base"
DATA     = r"$dirData"
OUT_IMG  = r"$dirImg"
OUT_GIF  = r"$dirGif"

FRAMES   = int($Frames)
FPS      = int($Fps)
LOOP_S   = int($LoopSeconds)

W,H = 720, 480

def safe(s): 
  return "".join(c if c.isalnum() or c in ("_","-") else "_" for c in s)

def get_font(size=26):
  # Safe fallback: PIL default font
  try:
    return ImageFont.truetype("arial.ttf", size)
  except:
    return ImageFont.load_default()

def draw_title(draw, title):
  font = get_font(30)
  draw.text((24, 18), title, font=font, fill=(20,20,20))

def draw_sub(draw, text):
  font = get_font(18)
  draw.text((24, 62), text, font=font, fill=(60,60,60))

def stick(draw, cx, cy, phase, kind):
  # Simple stick figure + motion variants
  head_r = 22
  # body
  draw.ellipse((cx-head_r, cy-150-head_r, cx+head_r, cy-150+head_r), outline=(20,20,20), width=4)
  draw.line((cx, cy-128, cx, cy-40), fill=(20,20,20), width=5)

  # legs
  draw.line((cx, cy-40, cx-28, cy+20), fill=(20,20,20), width=5)
  draw.line((cx, cy-40, cx+28, cy+20), fill=(20,20,20), width=5)

  t = phase

  if kind == "pendulum":
    # one arm supported, other swings
    # support arm
    draw.line((cx, cy-108, cx-70, cy-78), fill=(20,20,20), width=5)
    # swinging arm angle
    ang = math.sin(t*2*math.pi) * 0.7
    x2 = cx + int(math.cos(ang) * 85)
    y2 = (cy-108) + int(math.sin(ang) * 85)
    draw.line((cx, cy-108, x2, y2), fill=(20,20,20), width=5)
    # hint table
    draw.rectangle((cx-240, cy-40, cx-110, cy-25), fill=(120,120,120))

  elif kind == "scap":
    # arms back squeeze
    squeeze = (math.sin(t*2*math.pi)*0.5 + 0.5)  # 0..1
    x = int(55 + squeeze*10)
    draw.line((cx, cy-108, cx-x, cy-78), fill=(20,20,20), width=5)
    draw.line((cx, cy-108, cx+x, cy-78), fill=(20,20,20), width=5)
    # small arrows
    draw.polygon([(cx-140, cy-90),(cx-120, cy-96),(cx-120, cy-84)], fill=(200,80,80))
    draw.polygon([(cx+140, cy-90),(cx+120, cy-96),(cx+120, cy-84)], fill=(200,80,80))

  elif kind == "wall_pushup":
    # wall at right
    draw.rectangle((W-110, 120, W-80, H-80), fill=(170,170,170))
    # body angle changes
    lean = (math.sin(t*2*math.pi)*0.35 + 0.35) # 0..0.7
    # arms to wall
    shoulder_y = cy-108
    hip_y = cy-40
    shoulder_x = cx + int(lean*90)
    hip_x = cx - int(lean*40)
    # redraw torso angled
    draw.line((shoulder_x, shoulder_y, hip_x, hip_y), fill=(20,20,20), width=5)
    # arms to wall
    draw.line((shoulder_x, shoulder_y, W-110, shoulder_y+20), fill=(20,20,20), width=5)
    draw.line((shoulder_x, shoulder_y, W-110, shoulder_y+55), fill=(20,20,20), width=5)

  elif kind == "squat":
    # squat depth
    d = (math.sin(t*2*math.pi)*0.45 + 0.55) # 0.1..1
    y = int(cy - 20 + d*60)
    # body
    draw.line((cx, y-128, cx, y-40), fill=(20,20,20), width=5)
    # arms
    draw.line((cx, y-108, cx-60, y-88), fill=(20,20,20), width=5)
    draw.line((cx, y-108, cx+60, y-88), fill=(20,20,20), width=5)
    # legs bend
    draw.line((cx, y-40, cx-22, y+20), fill=(20,20,20), width=5)
    draw.line((cx, y-40, cx+22, y+20), fill=(20,20,20), width=5)
    # chair behind
    draw.rectangle((cx-200, cy+0, cx-120, cy+20), fill=(140,140,140))

def make_hero(title, subtitle, kind, out_png):
  img = Image.new("RGB",(W,H),(245,245,245))
  d = ImageDraw.Draw(img)
  # header band
  d.rectangle((0,0,W,96), fill=(235,235,235))
  draw_title(d, title)
  draw_sub(d, subtitle)
  # ground
  d.line((0,H-80,W,H-80), fill=(210,210,210), width=3)
  stick(d, int(W*0.45), int(H*0.70), 0.15, kind)
  img.save(out_png, "PNG")

def make_gif(title, kind, out_gif):
  frames = []
  total = max(2, FPS*LOOP_S)
  for i in range(total):
    t = i/float(total)
    img = Image.new("RGB",(W,H),(250,250,250))
    d = ImageDraw.Draw(img)
    d.rectangle((0,0,W,72), fill=(236,236,236))
    font = get_font(26)
    d.text((20,18), title, font=font, fill=(20,20,20))
    d.line((0,H-80,W,H-80), fill=(210,210,210), width=3)
    stick(d, int(W*0.45), int(H*0.70), t, kind)
    frames.append(img)

  # duration per frame in ms
  dur = int(1000 / max(1, FPS))
  frames[0].save(out_gif, save_all=True, append_images=frames[1:], duration=dur, loop=0, optimize=True)

# map kinds
kind_map = {
  "ex_001": "pendulum",
  "ex_002": "scap",
  "ex_003": "wall_pushup",
  "ex_004": "squat"
}

with open(os.path.join(DATA,"exercises_v1.json"),"r",encoding="utf-8-sig") as f:
  ex = json.load(f)

os.makedirs(OUT_IMG, exist_ok=True)
os.makedirs(OUT_GIF, exist_ok=True)

for e in ex:
  eid = e["id"]
  title = f'{e["name"]} ({eid})'
  subtitle = f'{e["body_region"]} | {e["difficulty"]}'
  kind = kind_map.get(eid, "scap")

  out_png = os.path.join(OUT_IMG, f"{eid}_{safe(e['name'])}.png")
  out_gif = os.path.join(OUT_GIF, f"{eid}_{safe(e['name'])}.gif")

  make_hero(title, subtitle, kind, out_png)
  make_gif(title, kind, out_gif)

print("DONE_MEDIA")
"@

$tmpPy = Join-Path $env:TEMP ("simon_media_" + [guid]::NewGuid().ToString("N") + ".py")
Set-Content -Path $tmpPy -Value $pyGen -Encoding UTF8

& $pyCmd $tmpPy
Remove-Item $tmpPy -Force -ErrorAction SilentlyContinue

# ---- 5) Basic docs/disclaimer ----
$disc = @"
# Simon Physio - Exercise Pack (Generated)

This pack contains:
- Exercise definitions (JSON/CSV)
- Simple 2D instruction images (PNG)
- Long-loop animated demos (GIF)

**General information only. Not medical advice.**
Stop if you feel sharp pain, new numbness/tingling, dizziness, chest pain, or symptoms worsening.
Seek professional help if symptoms persist or worsen.
"@
Set-Content -Path (Join-Path $dirDoc "README.md") -Value $disc -Encoding UTF8

Write-Host "[OK] Created: $base"
Write-Host "     Data : $dirData"
Write-Host "     PNG  : $dirImg"
Write-Host "     GIF  : $dirGif"
Write-Host "     Docs : $dirDoc"

if($OpenFolder){ explorer.exe $base }

