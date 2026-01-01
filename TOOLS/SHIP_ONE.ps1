# SHIP_ONE.ps1 — One-button release pipeline (Bump -> Build -> Commit -> Push -> Tag -> GitHub Release)
[CmdletBinding()]
param(
  [string]$RepoPath = "C:\SIMON\simon_physio",
  [switch]$PromoteToMain,
  [string]$ZipRelPath = "DIST\simon_physio_windows_release.zip"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VersionLine([string]$pubspecPath) {
  $m = Select-String $pubspecPath -Pattern '^\s*version\s*:\s*(.+)\s*$' | Select-Object -First 1
  if (-not $m) { throw "version: not found in pubspec.yaml" }
  return $m.Matches[0].Groups[1].Value.Trim()
}

function Parse-Version([string]$versionLine) {
  # Returns: @{ sem="1.0.3"; build=5; raw="1.0.3+5" }
  $raw = $versionLine
  if ($raw -match '^(\d+\.\d+\.\d+)\+(\d+)$') {
    return @{ sem=$Matches[1]; build=[int]$Matches[2]; raw=$raw }
  }
  # Fallback: treat everything as sem, build=0
  return @{ sem=$raw; build=0; raw=$raw }
}

function GitSafeTag([hashtable]$v) {
  if ($v.build -gt 0 -and $v.sem -match '^\d+\.\d+\.\d+$') {
    return "v$($v.sem)-build.$($v.build)"
  }
  $safe = $v.raw -replace '[^0-9A-Za-z\.\-_]','-'
  return "v$safe"
}

function Write-Checklist([string]$path, [string]$versionRaw, [string]$tag) {
@"
# Simon Physio — Release Checklist (Acceptance)
Release: $versionRaw
Tag: $tag

## Phase 1 MVP (from Notion promise)
- [ ] Appointment scheduling + calendar + reminders
- [ ] Patient records + notes (secure profiles + history)
- [ ] Treatment / exercise plans with patient check-off
- [ ] Automated rehab reminders
- [ ] Progress tracking + reports/graphs
- [ ] Strong privacy / secure data handling (non-negotiable)

## Safety-first (must be explicit in-app)
- [ ] Clear "assistive only / not diagnostic" text
- [ ] Clear "no robotics / no actuation" line
- [ ] Pause/stop flow during any guided session

## Commercial gates
- [ ] No debug banners / no console spam
- [ ] App launches cleanly and tabs switch without dead-ends
- [ ] ZIP runs from a clean folder (customer simulation)
- [ ] GitHub Release contains ZIP + release notes

## Quick eyeball test (2 minutes)
- [ ] Today -> Programs/Plans -> Reports (no broken routes)
- [ ] Create/view a client (no crash)
- [ ] Session player opens and exits safely
- [ ] Close + reopen (no corrupted state)
"@ | Set-Content -Path $path -Encoding UTF8
}

# ---------- START ----------
cd $RepoPath

# Kill env token in THIS session so gh doesn't force-token mode
$env:GITHUB_TOKEN = $null

# Verify gh auth
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "gh not authenticated. Run: gh auth login" }

# Determine current branch
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "[INFO] Repo   : $RepoPath"
Write-Host "[INFO] Branch : $branch"
Write-Host "[INFO] PromoteToMain: $PromoteToMain"

# 1) Bump build + rebuild wrapper
$bumper = Join-Path $RepoPath "TOOLS\BUMP_BUILD_AND_REBUILD_ONE.ps1"
if (!(Test-Path $bumper)) { throw "Missing: $bumper" }

Write-Host "[STEP] Bump build + rebuild wrapper"
powershell -NoProfile -ExecutionPolicy Bypass -File $bumper | Out-Host

# 2) Read version after bump
$pubspec = Join-Path $RepoPath "pubspec.yaml"
$versionLine = Get-VersionLine $pubspec
$v = Parse-Version $versionLine
$tag = GitSafeTag $v

Write-Host "[INFO] Version : $($v.raw)"
Write-Host "[INFO] Tag     : $tag"

# 3) Build app (ONECLICK)
$oneclick = Join-Path $RepoPath "TOOLS\SIMON_ONECLICK_ALL.ps1"
if (!(Test-Path $oneclick)) { throw "Missing build script: $oneclick" }

Write-Host "[STEP] Build app (ONECLICK)"
powershell -NoProfile -ExecutionPolicy Bypass -File $oneclick | Out-Host

# 4) Verify ZIP
$zipPath = Join-Path $RepoPath $ZipRelPath
if (!(Test-Path $zipPath)) { throw "Release zip not found: $zipPath" }

# 5) Write checklist into repo (Notion-aligned template)
$checkPath = Join-Path $RepoPath "TOOLS\RELEASE_CHECKLIST.md"
Write-Checklist -path $checkPath -versionRaw $v.raw -tag $tag
Write-Host "[OK] Checklist written: $checkPath"

# 6) Commit + push branch
Write-Host "[STEP] Commit + push ($branch)"
git add . | Out-Null
git commit -m "Release $($v.raw)" | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Host "[INFO] Nothing new to commit" }

git push origin $branch | Out-Host

# 7) Optional promote to main
if ($PromoteToMain) {
  Write-Host "[STEP] Promote $branch -> main"
  git fetch origin | Out-Null
  git checkout main | Out-Host
  git pull origin main | Out-Host
  git merge --no-ff $branch -m "Merge $branch for $($v.raw)" | Out-Host
  git push origin main | Out-Host
  git checkout $branch | Out-Host
}

# 8) Tag + push tag
Write-Host "[STEP] Tag + push tag ($tag)"
git tag -f $tag | Out-Null
git push origin $tag --force | Out-Host

# 9) GitHub Release (PowerShell-safe: don't crash on 'release not found')
Write-Host "[STEP] GitHub Release"
$notes = "Premium MVP release.`nGuided rehab.`nSafety-first design.`nWindows build."
& gh release view $tag 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
  Write-Host "[INFO] Release exists; uploading ZIP (clobber)"
  gh release upload $tag $zipPath --clobber | Out-Host
} else {
  Write-Host "[INFO] Release missing; creating"
  gh release create $tag $zipPath --title "Simon Physio $($v.raw)" --notes $notes | Out-Host
}

Write-Host ""
Write-Host "[DONE] SHIPPED: $($v.raw)  ($tag)"
Write-Host "Release asset: $zipPath"
Write-Host "Checklist    : $checkPath"
