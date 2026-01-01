param(
  [string]$InDir  = "$env:USERPROFILE\Documents\SimonPhysio\exercise_sources",
  [string]$OutDir = "$env:USERPROFILE\Documents\SimonPhysio\exercise_library",
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }

Ensure-Dir $InDir
Ensure-Dir $OutDir

$py = @"
import os, re, json, csv, hashlib
from datetime import datetime

IN_DIR  = r""" + $InDir.Replace('\','\\') + r""""
OUT_DIR = r""" + $OutDir.Replace('\','\\') + r""""

def ensure(p): os.makedirs(p, exist_ok=True)

def stable_id(name, body_region):
    h = hashlib.md5((name.strip()+"|"+body_region.strip()).encode("utf-8")).hexdigest()[:8]
    return f"ex_{h}"

# --- Simple doc reader (TXT/MD) + fallback for others ---
def read_text(path):
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext in [".txt",".md"]:
            return open(path,"r",encoding="utf-8",errors="ignore").read()
        # For .docx you can later add python-docx; for pdf add pypdf.
        # For now, treat unknown as text best-effort:
        return open(path,"r",encoding="utf-8",errors="ignore").read()
    except:
        return ""

# --- Exercise block extraction ---
# We support a friendly author template like:
# EXERCISE: Name
# REGION: Shoulder
# EQUIPMENT: None
# SETUP: ...
# STEPS:
# - ...
# DOSAGE: sets=2 reps=10 rest=30
# TAGS: mobility; warmup
# SAFETY STOP IF: ...
# CONSULT IF: ...
BLOCK_RE = re.compile(
    r"(?ms)^\s*EXERCISE:\s*(?P<name>.+?)\s*$"
    r".*?^\s*REGION:\s*(?P<region>.+?)\s*$"
    r".*?^\s*EQUIPMENT:\s*(?P<equip>.+?)\s*$"
    r".*?^\s*SETUP:\s*(?P<setup>.+?)\s*$"
    r".*?^\s*STEPS:\s*(?P<steps>(?:^\s*-\s*.+\s*$)+)"
    r".*?^\s*DOSAGE:\s*(?P<dosage>.+?)\s*$"
    r"(?:.*?^\s*TAGS:\s*(?P<tags>.+?)\s*$)?"
    r"(?:.*?^\s*SAFETY STOP IF:\s*(?P<stop>.+?)\s*$)?"
    r"(?:.*?^\s*CONSULT IF:\s*(?P<consult>.+?)\s*$)?",
    re.MULTILINE
)

def parse_dosage(dos):
    # sets=2 reps=10 rest=30 OR sets=2 reps="30-60s" rest=30
    out = {"sets": None, "reps": None, "rest_seconds": None}
    s = dos.strip()
    m = re.search(r"sets\s*=\s*([0-9]+)", s, re.I)
    if m: out["sets"] = int(m.group(1))
    m = re.search(r"reps\s*=\s*(\".*?\"|[^ ]+)", s, re.I)
    if m:
        v = m.group(1).strip()
        if v.startswith('"') and v.endswith('"'): v = v[1:-1]
        out["reps"] = v
    m = re.search(r"rest\s*=\s*([0-9]+)", s, re.I)
    if m: out["rest_seconds"] = int(m.group(1))
    return out

# --- Rewrite/normalize rules (no diagnosis, consistent style) ---
def rewrite_setup(setup):
    setup = setup.strip()
    # Make it short + clear + consistent
    setup = re.sub(r"\s+", " ", setup)
    return setup[:1].upper() + setup[1:]

def rewrite_steps(steps_lines):
    cleaned = []
    for s in steps_lines:
        s = s.strip("- ").strip()
        s = re.sub(r"\s+", " ", s)
        if not s: 
            continue
        # enforce imperative tone
        s = s[:1].upper() + s[1:]
        cleaned.append(s)
    # keep step count sane
    return cleaned[:10]

# --- Categorization rules (extend anytime) ---
def categorize(ex):
    name = ex["name"].lower()
    region = ex["body_region"].lower()
    tags = set([t.lower() for t in ex.get("tags", [])])

    injury_phase = []
    if "post-op" in name or "post op" in name or "surgery" in name:
        injury_phase.append("post-op")
    if "prehab" in name or "pre-hab" in name:
        injury_phase.append("prehab")
    if "warm" in name or "mobility" in tags:
        injury_phase.append("warmup/mobility")

    # equipment inference
    equip = "none" if (not ex["equipment"] or ex["equipment"]==["None"]) else "has_equipment"

    # difficulty heuristic
    diff = ex.get("difficulty","Easy")
    if any(x in name for x in ["hold", "isometric"]) and diff == "Easy":
        diff = "Easy"

    # group categories
    cats = []
    if "shoulder" in region: cats.append("Upper Limb > Shoulder")
    if "back" in region or "spine" in region: cats.append("Spine")
    if "hip" in region: cats.append("Lower Limb > Hip")
    if "knee" in region: cats.append("Lower Limb > Knee")

    # defaults
    if not cats: cats.append("General")

    ex["meta"] = {
      "categories": cats,
      "phase": injury_phase or ["general"],
      "equipment_flag": equip,
    }
    return ex

def split_tags(s):
    if not s: return []
    parts = re.split(r"[;,|]", s)
    return [p.strip() for p in parts if p.strip()]

def main():
    ensure(OUT_DIR)
    out_json = os.path.join(OUT_DIR, "exercises_library_v1.json")
    out_csv  = os.path.join(OUT_DIR, "notion_exercises_import_v1.csv")

    exercises = []

    for root, _, files in os.walk(IN_DIR):
        for fn in files:
            path = os.path.join(root, fn)
            text = read_text(path)
            if not text.strip():
                continue

            for m in BLOCK_RE.finditer(text):
                name   = m.group("name").strip()
                region = m.group("region").strip()
                equip  = m.group("equip").strip()
                setup  = m.group("setup").strip()
                steps  = m.group("steps").strip().splitlines()
                dosage = m.group("dosage").strip()

                tags = split_tags(m.group("tags") or "")
                stop = (m.group("stop") or "").strip()
                consult = (m.group("consult") or "").strip()

                ex = {
                    "id": stable_id(name, region),
                    "name": name,
                    "body_region": region,
                    "equipment": split_tags(equip) or ["None"],
                    "setup": rewrite_setup(setup),
                    "steps": rewrite_steps(steps),
                    "dosage": parse_dosage(dosage),
                    "tags": tags,
                    "difficulty": "Easy",
                    "safety": {
                        "stop_if": split_tags(stop),
                        "consult_if": split_tags(consult)
                    },
                    "source_file": fn
                }

                ex = categorize(ex)
                exercises.append(ex)

    # de-dupe by id
    uniq = {}
    for e in exercises:
        uniq[e["id"]] = e
    exercises = list(uniq.values())

    with open(out_json, "w", encoding="utf-8") as f:
        json.dump({"generated": datetime.now().isoformat(), "count": len(exercises), "items": exercises}, f, ensure_ascii=False, indent=2)

    # Notion CSV
    headers = ["ID","Name","Body Region","Categories","Phase","Tags","Difficulty","Equipment","Setup","Steps","Dosage","Stop If","Consult If","Source"]
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for e in exercises:
            cats = " | ".join(e["meta"]["categories"])
            phase = " | ".join(e["meta"]["phase"])
            tags = ";".join(e.get("tags",[]))
            equip = ";".join(e.get("equipment",[]))
            steps = " | ".join(e.get("steps",[]))
            dose = f"sets={e['dosage'].get('sets')}; reps={e['dosage'].get('reps')}; rest_s={e['dosage'].get('rest_seconds')}"
            stop = " | ".join(e["safety"].get("stop_if",[]))
            consult = " | ".join(e["safety"].get("consult_if",[]))
            w.writerow([e["id"], e["name"], e["body_region"], cats, phase, tags, e["difficulty"], equip, e["setup"], steps, dose, stop, consult, e.get("source_file","")])

    print("[OK] Built exercise library")
    print(" JSON :", out_json)
    print(" CSV  :", out_csv)
    print(" Items:", len(exercises))
    if len(exercises)==0:
        print("[WARN] No exercises found. Use the template blocks (EXERCISE/REGION/EQUIPMENT/SETUP/STEPS/DOSAGE).")

if __name__ == "__main__":
    main()
"@

$pyPath = Join-Path $OutDir "_build_exercises.py"
$py | Set-Content -Path $pyPath -Encoding UTF8

Write-Host "== Simon Exercise Pipeline ONE-CLICK ==" -ForegroundColor Cyan
Write-Host "Input : $InDir"
Write-Host "Output: $OutDir"
Write-Host ""
Write-Host "Template expected in source docs:" -ForegroundColor Yellow
Write-Host @"
EXERCISE: Shoulder Pendulum
REGION: Shoulder
EQUIPMENT: None
SETUP: Lean forward with one hand supported...
STEPS:
- Relax the hanging arm
- Swing forward/back
- Swing side-to-side
- Small circles both directions
DOSAGE: sets=2 reps="30-60 seconds" rest=30
TAGS: mobility; warmup
SAFETY STOP IF: sharp pain; dizziness; pins and needles
CONSULT IF: recent fracture/dislocation
"@

# Run
py $pyPath

if($OpenFolder){ explorer.exe $OutDir }
