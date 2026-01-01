param(
  [string]$OutRoot = "$env:USERPROFILE\Documents\SimonPhysio\demo_pack",
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }

function Write-Json([string]$path, $obj){
  $json = $obj | ConvertTo-Json -Depth 20
  Set-Content -Path $path -Value $json -Encoding UTF8
}

$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
$base = Join-Path $OutRoot $ts

$dirData   = Join-Path $base "data"
$dirDocs   = Join-Path $base "docs"
$dirNotion = Join-Path $base "notion"

Ensure-Dir $dirData
Ensure-Dir $dirDocs
Ensure-Dir $dirNotion

# --- Demo Exercises (small seed set) ---
$exercises = @(
  @{
    id="ex_001"; name="Shoulder Pendulum"; body_region="Shoulder"
    tags=@("mobility","gentle","warmup"); difficulty="Easy"; equipment=@("None")
    setup="Lean forward with one hand supported on a table or chair. Let the other arm hang relaxed."
    steps=@(
      "Relax the hanging arm and shoulder.",
      "Gently swing the arm forward/back like a pendulum.",
      "Then swing side-to-side.",
      "Then make small circles each direction."
    )
    dosage=@{ sets=2; reps="30-60 seconds each direction"; rest_seconds=30 }
    cues=@("Keep it relaxed, no forcing.","Small motion first, then slightly bigger if comfortable.")
    safety=@{
      stop_if=@("sharp pain","pins and needles","dizziness","pain increasing quickly")
      consult_if=@("recent fracture/dislocation","severe swelling","fever","night pain that is worsening")
    }
    progressions=@("Increase circle size slightly.","Add an extra set.")
    regressions=@("Reduce circle size.","Shorten time.")
  },
  @{
    id="ex_002"; name="Scapular Squeeze"; body_region="Upper Back"
    tags=@("posture","strength","desk"); difficulty="Easy"; equipment=@("None")
    setup="Sit or stand tall. Arms relaxed by sides."
    steps=@(
      "Gently draw shoulder blades back and down.",
      "Hold 3 seconds.",
      "Release slowly."
    )
    dosage=@{ sets=2; reps=10; rest_seconds=30 }
    cues=@("Neck stays long.","Do not shrug up.","Think: pockets to back pockets.")
    safety=@{ stop_if=@("sharp pain","tingling"); consult_if=@("recent neck injury") }
    progressions=@("Hold 5 seconds.","Add a light resistance band if approved by your clinician.")
    regressions=@("Smaller squeeze.","Do fewer reps.")
  }
)

Write-Json (Join-Path $dirData "demo_exercises_v1.json") $exercises

# --- UI copy seed ---
$ui = @{
  app_name="Simon Physio (Demo)"
  screens=@{
    onboarding_title="Welcome"
    onboarding_body="This app provides general exercise guidance and tracking. It is not a replacement for a clinician."
    pain_scale_title="Quick check-in"
    pain_scale_body="Rate your comfort and effort. If anything feels wrong, stop."
    exercise_title="Exercise"
    exercise_cta_start="Start"
    exercise_cta_done="Done"
    feedback_title="After exercise"
    notes_title="Notes"
  }
  microcopy=@{
    stop_prompt="Stop if you feel sharp pain, new numbness, dizziness, chest pain, or symptoms worsening."
    seek_help="Seek medical help if symptoms are severe or getting worse."
  }
}
Write-Json (Join-Path $dirData "ui_copy_v1.json") $ui

# --- AI cue rules seed (simple, non-medical) ---
$ai = @{
  inputs=@{
    pain_now="Pain right now (0-10)"
    pain_after="Pain after exercise (0-10)"
    effort="Effort (easy / moderate / hard)"
    symptoms="Any unusual symptoms? (yes/no)"
  }
  rules=@(
    @{ when="symptoms == yes"; do="Tell user to stop and consider contacting a clinician." },
    @{ when="pain_after >= 7"; do="Stop session. Recommend clinician review before continuing." },
    @{ when="pain_after >= pain_now + 2"; do="Suggest reducing range/reps next time and monitor." },
    @{ when="pain_after <= 3 and effort != hard for 2 sessions"; do="Suggest small progression (add 1-2 reps or slightly more range)." },
    @{ when="pain_after between 4 and 6"; do="Maintain or regress slightly, focus on form and slow tempo." }
  )
  coaching_style=@{
    tone="calm, supportive, non-medical"
    avoid=@("diagnosis","promises","medical certainty")
    encourage=@("listen to your body","stop if sharp pain","move within comfort")
  }
}
Write-Json (Join-Path $dirData "ai_cues_v1.json") $ai

# --- Disclaimers doc ---
$disc = @"
# Simon Physio (Demo) - Disclaimers & Positioning (AU / UK / US)

## Core Positioning (use everywhere)
Simon Physio provides general exercise guidance, education, and tracking tools.
It does NOT diagnose conditions, provide medical advice, or replace a qualified health professional.

## Safety Prompt (short)
Stop if you feel sharp pain, new numbness/tingling, dizziness, chest pain, or symptoms worsening.
Seek urgent medical care for severe symptoms.

## Australia (AU)
- General information only; not a substitute for professional advice.
- If you have an injury, persistent pain, or concerns, consult a registered health practitioner.
- In an emergency, call local emergency services.

## United Kingdom (UK)
- General information only; not a substitute for advice from a physiotherapist, GP, or other healthcare professional.
- If symptoms persist or worsen, seek NHS/clinician advice.
- In an emergency, call 999.

## United States (US)
- For educational purposes only. Not medical advice.
- Not intended to diagnose, treat, cure, or prevent any disease.
- Consult a licensed healthcare provider before starting a new exercise program, especially if you have medical conditions.
- In an emergency, call 911.

## AI Language Rules (risk control)
Allowed:
- "This may help some people."
- "Try a smaller range if uncomfortable."
- "Consider speaking with a clinician."

Not allowed:
- "This will fix your rotator cuff."
- "You have X condition."
- "Guaranteed relief."
"@
Set-Content -Path (Join-Path $dirDocs "disclaimers_AU_UK_US_v1.md") -Value $disc -Encoding UTF8

# --- Notion import CSV (simple) ---
$csvPath = Join-Path $dirNotion "notion_exercises_import_v1.csv"
"ID,Name,Body Region,Tags,Difficulty,Equipment,Setup,Steps,Dosage,Cues,Stop If,Consult If" | Set-Content -Path $csvPath -Encoding UTF8

foreach($e in $exercises){
  $steps = ($e.steps -join " | ") -replace '"','""'
  $tags  = ($e.tags -join ";") -replace '"','""'
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

Write-Host "[OK] Demo pack created: $base"
Write-Host "     Data : $dirData"
Write-Host "     Docs : $dirDocs"
Write-Host "     Notion: $dirNotion"

if($OpenFolder){
  explorer.exe $base
}
