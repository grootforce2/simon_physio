param(
  [int]$Size = 900,
  [int]$Frames = 36,
  [int]$HoldMs = 70,
  [int]$Loops = 0,
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "Ensure-Dir got empty path." }
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function Get-Docs {
  $d = [Environment]::GetFolderPath("MyDocuments")
  if($d -and (Test-Path $d)){ return $d }
  $h = [Environment]::GetFolderPath("UserProfile")
  if(-not $h){ throw "Cannot determine UserProfile." }
  $d2 = Join-Path $h "Documents"
  Ensure-Dir $d2
  return $d2
}

function Find-PythonExe {
  $c = Get-Command python -EA SilentlyContinue
  if($c){ return $c.Source }
  $c = Get-Command python3 -EA SilentlyContinue
  if($c){ return $c.Source }

  $cand = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python310\python.exe'),
    (Join-Path $env:ProgramFiles 'Python312\python.exe'),
    (Join-Path $env:ProgramFiles 'Python311\python.exe'),
    (Join-Path $env:ProgramFiles 'Python310\python.exe')
  ) | Where-Object { $_ -and $_ -ne "" }

  foreach($p in $cand){ if(Test-Path $p){ return $p } }
  return $null
}

function Install-PythonIfMissing {
  $py = Find-PythonExe
  if($py){ return $py }

  if(Get-Command winget -EA SilentlyContinue){
    Write-Host "==> Python not found. Installing via winget (silent)..." -ForegroundColor Cyan
    try {
      winget install -e --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements | Out-Host
    } catch {
      Write-Host "[WARN] winget install failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }

  $py = Find-PythonExe
  if($py){ return $py }

  throw "Python not found. Install Python 3.10+ (or enable winget) then rerun."
}

function Get-LatestExercisesJson {
  $docs = Get-Docs
  $roots = @(
    (Join-Path $docs "SimonPhysio\exercise_pack"),
    (Join-Path $docs "SimonPhysio\demo_pack")
  )
  $all = @()
  foreach($r in $roots){
    if(Test-Path $r){
      $all += Get-ChildItem $r -Recurse -File -Filter "*exercises*.json" -EA SilentlyContinue
    }
  }
  if($all.Count -gt 0){
    return ($all | Sort-Object LastWriteTime -Desc | Select-Object -First 1).FullName
  }
  return $null
}

function New-DemoExercisesJson([string]$path){
  $demo = @(
    @{
      id='ex_shoulder_pendulum'; name='Shoulder Pendulum'; view='side'
      setup='Lean forward with one hand supported. Let the other arm hang relaxed.'
      steps=@('Relax the hanging arm.','Swing forward/back gently.','Make small circles both directions.')
      cues=@('Keep it relaxed.','No forcing into pain.')
      dosage=@{ sets=2; reps='30-60 sec'; rest_seconds=30 }
      motion=@{ type='pendulum'; amplitude_deg=18 }
    },
    @{
      id='ex_scap_squeeze'; name='Scapular Squeeze'; view='front'
      setup='Sit or stand tall. Arms relaxed.'
      steps=@('Pull shoulder blades back + down.','Hold 3 seconds.','Release slowly.')
      cues=@('Do not shrug.','Neck long.')
      dosage=@{ sets=2; reps=10; rest_seconds=30 }
      motion=@{ type='scap_squeeze'; amplitude_deg=10 }
    },
    @{
      id='ex_box_squat'; name='Box Squat'; view='side'
      setup='Stand in front of a chair. Feet shoulder-width.'
      steps=@('Sit back to touch chair lightly.','Stand up tall.','Repeat with control.')
      cues=@('Knees track over toes.','Control down, drive up.')
      dosage=@{ sets=3; reps=8; rest_seconds=60 }
      motion=@{ type='squat'; depth=0.55 }
    }
  )
  ($demo | ConvertTo-Json -Depth 30) | Set-Content -Path $path -Encoding UTF8
}

# ---------- Output paths ----------
$docs = Get-Docs
$root = Join-Path $docs "SimonPhysio\exercise_pack"
Ensure-Dir $root

$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$base    = Join-Path $root $stamp
$dirData = Join-Path $base "data"
$dirImg  = Join-Path $base "media\images"
$dirGif  = Join-Path $base "media\gifs"
Ensure-Dir $dirData; Ensure-Dir $dirImg; Ensure-Dir $dirGif

# ---------- Input JSON ----------
$exJson = Get-LatestExercisesJson
if(-not $exJson){
  $exJson = Join-Path $dirData "exercises_v1.json"
  New-DemoExercisesJson $exJson
}

# ---------- Python (embedded) ----------
$pyCode = @'
import os, json, math, sys, subprocess

EX_JSON = os.environ["EX_JSON"]
OUT_IMG = os.environ["OUT_IMG"]
OUT_GIF = os.environ["OUT_GIF"]
SIZE   = int(os.environ.get("SIZE","900"))
FRAMES = int(os.environ.get("FRAMES","36"))
HOLDMS = int(os.environ.get("HOLDMS","70"))
LOOPS  = int(os.environ.get("LOOPS","0"))

def pip_install(pkgs):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "--upgrade", "pip"])
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet"] + pkgs)

try:
    from PIL import Image, ImageDraw, ImageFont
    import imageio.v2 as imageio
    import numpy as np
except Exception:
    pip_install(["Pillow","imageio","numpy"])
    from PIL import Image, ImageDraw, ImageFont
    import imageio.v2 as imageio
    import numpy as np

os.makedirs(OUT_IMG, exist_ok=True)
os.makedirs(OUT_GIF, exist_ok=True)

def load_json(path):
    with open(path,"r",encoding="utf-8-sig") as f:
        return json.load(f)

def font(sz):
    for name in ["arial.ttf","segoeui.ttf","calibri.ttf"]:
        try: return ImageFont.truetype(name, sz)
        except: pass
    return ImageFont.load_default()

F_TITLE=font(34); F_SMALL=font(20)

def rotate(p,o,a):
    x,y=p; ox,oy=o
    s,c=math.sin(a), math.cos(a)
    x-=ox; y-=oy
    return (x*c - y*s + ox, x*s + y*c + oy)

def joint(d,p,r=7):
    d.ellipse([p[0]-r,p[1]-r,p[0]+r,p[1]+r], outline=(35,45,65), width=2)

def base_pose(view,W,H):
    cx=W*0.5; top=H*0.12; s=min(W,H)
    head_r=s*0.055
    neck=(cx, top+head_r*2.0)
    sh_y=neck[1]+s*0.06
    hip_y=sh_y+s*0.30
    knee_y=hip_y+s*0.22
    ankle_y=knee_y+s*0.20

    if view=="front":
        sh_dx=s*0.13; hip_dx=s*0.08
        el_y=sh_y+s*0.13; wr_y=el_y+s*0.13
        return dict(
            head=(cx, top+head_r), neck=neck, head_r=head_r,
            shL=(cx-sh_dx,sh_y), shR=(cx+sh_dx,sh_y),
            elL=(cx-sh_dx*1.20,el_y), elR=(cx+sh_dx*1.20,el_y),
            wrL=(cx-sh_dx*1.30,wr_y), wrR=(cx+sh_dx*1.30,wr_y),
            hip=(cx,hip_y), hipL=(cx-hip_dx,hip_y), hipR=(cx+hip_dx,hip_y),
            knL=(cx-hip_dx*0.9,knee_y), knR=(cx+hip_dx*0.9,knee_y),
            anL=(cx-hip_dx*0.9,ankle_y), anR=(cx+hip_dx*0.9,ankle_y),
            ftL=(cx-hip_dx*1.2,ankle_y+s*0.03), ftR=(cx+hip_dx*1.2,ankle_y+s*0.03),
        )

    x=cx+s*0.05
    return dict(
        head=(cx, top+head_r), neck=neck, head_r=head_r,
        sh=(x,sh_y),
        el=(x+s*0.10, sh_y+s*0.14),
        wr=(x+s*0.12, sh_y+s*0.30),
        hip=(x,hip_y),
        kn=(x+s*0.05,knee_y),
        an=(x+s*0.02,ankle_y),
        ft=(x+s*0.12,ankle_y+s*0.03),
    )

def render(ex):
    ex_id=ex.get("id","ex_unknown")
    name=ex.get("name","Exercise")
    view=(ex.get("view","front") or "front").lower()
    motion=ex.get("motion",{}) or {}
    mtype=(motion.get("type","static") or "static").lower()
    amp=math.radians(float(motion.get("amplitude_deg",15)))
    depth=float(motion.get("depth",0.5))

    frames=[]
    for i in range(FRAMES):
        t=i/max(1,(FRAMES-1))
        osc=0.5-0.5*math.cos(2*math.pi*t)

        img=Image.new("RGB",(SIZE,SIZE),(245,247,250))
        d=ImageDraw.Draw(img)
        pad=int(SIZE*0.05)

        d.rounded_rectangle([pad,pad,SIZE-pad,pad+80], radius=22, fill=(255,255,255), outline=(220,225,232), width=2)
        d.text((pad+18,pad+18), name, font=F_TITLE, fill=(20,25,35))

        box_y1=SIZE-pad-190
        d.rounded_rectangle([pad,box_y1,SIZE-pad,SIZE-pad], radius=22, fill=(255,255,255), outline=(220,225,232), width=2)

        setup=(ex.get("setup","") or "").strip()
        steps=ex.get("steps",[]) or []
        cues=ex.get("cues",[]) or []
        s1=steps[0] if len(steps)>0 else ""
        c1=cues[0] if len(cues)>0 else ""
        d.text((pad+18, box_y1+18), "Setup: "+setup[:90], font=F_SMALL, fill=(30,40,60))
        d.text((pad+18, box_y1+60), "Do: "+s1[:95], font=F_SMALL, fill=(30,40,60))
        if c1:
            d.text((pad+18, box_y1+132), "Cue: "+c1[:95], font=F_SMALL, fill=(80,55,0))

        stage_top=pad+100
        stage_bottom=box_y1-18
        d.rounded_rectangle([pad,stage_top,SIZE-pad,stage_bottom], radius=22, fill=(255,255,255), outline=(220,225,232), width=2)

        outline=(35,45,65)
        pose=base_pose(view,SIZE,SIZE)

        if view=="front":
            head=pose["head"]; hr=pose["head_r"]; hip=pose["hip"]
            shL,shR=pose["shL"],pose["shR"]
            elL,elR=pose["elL"],pose["elR"]
            wrL,wrR=pose["wrL"],pose["wrR"]
            if mtype=="scap_squeeze":
                k=osc
                shL=(shL[0]+(hip[0]-shL[0])*0.06*k, shL[1]+SIZE*0.01*k)
                shR=(shR[0]+(hip[0]-shR[0])*0.06*k, shR[1]+SIZE*0.01*k)

            d.ellipse([head[0]-hr,head[1]-hr,head[0]+hr,head[1]+hr], outline=outline, width=6)
            d.line([pose["neck"], hip], fill=outline, width=10)
            d.line([shL,elL,wrL], fill=outline, width=10)
            d.line([shR,elR,wrR], fill=outline, width=10)
            d.line([pose["hipL"],pose["knL"],pose["anL"],pose["ftL"]], fill=outline, width=12)
            d.line([pose["hipR"],pose["knR"],pose["anR"],pose["ftR"]], fill=outline, width=12)
            for p in [shL,shR,elL,elR,wrL,wrR,hip,pose["knL"],pose["knR"],pose["anL"],pose["anR"]]:
                joint(d,p,7)
        else:
            head=pose["head"]; hr=pose["head_r"]
            sh,el,wr=pose["sh"],pose["el"],pose["wr"]
            hip,kn,an,ft=pose["hip"],pose["kn"],pose["an"],pose["ft"]

            if mtype=="pendulum":
                ang=math.sin(2*math.pi*t)*amp
                el=rotate(el,sh,ang)
                wr=rotate(wr,sh,ang*1.15)

            if mtype=="squat":
                k=osc
                down=SIZE*(0.12*depth)*k
                back=SIZE*(0.06*depth)*k
                hip=(hip[0]-back, hip[1]+down)
                kn=(kn[0]-back*0.4, kn[1]+down*0.7)

            d.ellipse([head[0]-hr,head[1]-hr,head[0]+hr,head[1]+hr], outline=outline, width=6)
            d.line([pose["neck"], hip], fill=outline, width=10)
            d.line([sh,el,wr], fill=outline, width=10)
            d.line([hip,kn,an,ft], fill=outline, width=12)
            for p in [sh,el,wr,hip,kn,an]:
                joint(d,p,7)

        dosage=ex.get("dosage",{}) or {}
        d.text((pad+18,SIZE-pad-44),
               f"Dosage: sets={dosage.get('sets','')} reps/time={dosage.get('reps','')} rest={dosage.get('rest_seconds','')}s",
               font=F_SMALL, fill=(40,50,70))

        frames.append(np.array(img))

    png0=os.path.join(OUT_IMG, f"{ex_id}_start.png")
    png1=os.path.join(OUT_IMG, f"{ex_id}_end.png")
    gif=os.path.join(OUT_GIF, f"{ex_id}_loop.gif")
    Image.fromarray(frames[0]).save(png0)
    Image.fromarray(frames[-1]).save(png1)
    imageio.mimsave(gif, frames + frames[::-1] + frames, duration=HOLDMS/1000.0, loop=LOOPS)

def main():
    exs=load_json(EX_JSON)
    if isinstance(exs,dict) and "exercises" in exs:
        exs=exs["exercises"]
    ok=0
    for ex in exs:
        try:
            render(ex); ok+=1
            print("[OK]", ex.get("id","?"))
        except Exception as e:
            print("[WARN]", ex.get("id","?"), e)
    print("DONE", ok, "/", len(exs))
    print("Images:", OUT_IMG)
    print("GIFs:", OUT_GIF)

if __name__=="__main__":
    main()
'@

$pyExe = Install-PythonIfMissing

# Write python to temp
$tmpRoot = if($env:TEMP){ $env:TEMP } else { [IO.Path]::GetTempPath() }
$tmpPy = Join-Path $tmpRoot ("simon_render_" + [guid]::NewGuid().ToString("N") + ".py")
[IO.File]::WriteAllText($tmpPy, $pyCode, (New-Object System.Text.UTF8Encoding($false)))

# Env for python
$env:EX_JSON = $exJson
$env:OUT_IMG = $dirImg
$env:OUT_GIF = $dirGif
$env:SIZE    = "$Size"
$env:FRAMES  = "$Frames"
$env:HOLDMS  = "$HoldMs"
$env:LOOPS   = "$Loops"

Write-Host "==> EX_JSON: $exJson"
Write-Host "==> OUT:    $base"
Write-Host "==> PYEXE:  $pyExe"
Write-Host "==> TMPPY:  $tmpPy"

& $pyExe $tmpPy
$exit = $LASTEXITCODE
if($exit -ne 0){
  throw "Renderer failed (exit $exit)."
}

Write-Host "[OK] Render complete." -ForegroundColor Green
Write-Host "Images: $dirImg"
Write-Host "GIFs:   $dirGif"

if($OpenFolder){ explorer.exe $base }
