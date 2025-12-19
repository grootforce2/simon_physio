# RELEASE_VNEXT_ONE.ps1
# One-button commercial release script (PowerShell-safe)

[CmdletBinding()]
param(
  [string]$RepoPath = "C:\SIMON\simon_physio",
  [switch]$PromoteToMain
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Version {
  $pub = Join-Path $RepoPath "pubspec.yaml"
  $m = Select-String $pub -Pattern '^\s*version\s*:\s*(.+)\s*$'
  if (-not $m) { throw "Version not found in pubspec.yaml" }
  return $m.Matches[0].Groups[1].Value.Trim()
}

function GitSafeTag($v) {
  if ($v -match '^(\d+\.\d+\.\d+)\+(\d+)$') {
    return "v$($Matches[1])-build.$($Matches[2])"
  }
  return "v$($v -replace '[^0-9A-Za-z\.\-_]','-')"
}

cd $RepoPath

Write-Host "[INFO] Repo: $RepoPath"

# Ensure auth
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI not authenticated" }

# 1) bump build + rebuild wrapper
Write-Host "[STEP] Bump build + rebuild wrapper"
powershell -NoProfile -ExecutionPolicy Bypass -File "TOOLS\BUMP_BUILD_AND_REBUILD_ONE.ps1" | Out-Host

# 2) read version
$version = Get-Version
$tag = GitSafeTag $version

Write-Host "[INFO] Version : $version"
Write-Host "[INFO] Tag     : $tag"

# 3) build app
if (Test-Path "TOOLS\SIMON_ONECLICK_ALL.ps1") {
  Write-Host "[STEP] Build app"
  powershell -NoProfile -ExecutionPolicy Bypass -File "TOOLS\SIMON_ONECLICK_ALL.ps1" | Out-Host
}

$zip = Join-Path $RepoPath "DIST\simon_physio_windows_release.zip"
if (-not (Test-Path $zip)) { throw "Release ZIP missing: $zip" }

# 4) commit + push
git add .
git commit -m "Release $version" | Out-Host
git push origin HEAD | Out-Host

# 5) optional promote
if ($PromoteToMain) {
  Write-Host "[STEP] Promote to main"
  git checkout main
  git pull
  git merge --no-ff HEAD -m "Release $version"
  git push origin main
}

# 6) tag + push
git tag -f $tag
git push origin $tag --force

# 7) GitHub release
$notes = "Premium MVP release.`nGuided rehab.`nSafety-first.`nWindows build."
$exists = gh release view $tag *> $null

if ($LASTEXITCODE -eq 0) {
  gh release upload $tag $zip --clobber
} else {
  gh release create $tag $zip `
    --title "Simon Physio $version" `
    --notes $notes
}

Write-Host ""
Write-Host "[DONE] Released $version ($tag)"
Write-Host "Asset: $zip"
