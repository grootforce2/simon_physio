# GITHUB_RELEASE_ONE.ps1
# One-shot commercial GitHub release script for Simon Physio (PowerShell-safe)

[CmdletBinding()]
param(
  [string]$RepoPath   = "C:\SIMON\simon_physio",
  [string]$ReleaseZip = "DIST\simon_physio_windows_release.zip"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

cd $RepoPath

# --- 1) Read version ---
$pub = Join-Path $RepoPath "pubspec.yaml"
$m = Select-String $pub -Pattern '^\s*version\s*:\s*(.+)\s*$' | Select-Object -First 1
if (-not $m) { throw "version not found in pubspec.yaml" }

$version = $m.Matches[0].Groups[1].Value.Trim()
$tag = "v$version"

Write-Host "[INFO] Version: $version"
Write-Host "[INFO] Tag    : $tag"

# --- 2) Write .gitignore ---
$gitignore = @"
# Flutter / Dart
.dart_tool/
.packages
.pub/
build/
coverage/

# Platform builds
windows/runner/Release/
macos/Flutter/ephemeral/
linux/flutter/ephemeral/

# Outputs / binaries
DIST/
*.exe
*.zip
*.log

# Backups
*.bak_*
"@
Set-Content ".gitignore" $gitignore -Encoding UTF8
Write-Host "[OK] .gitignore written"

# --- 3) Validate release asset ---
$zipPath = Join-Path $RepoPath $ReleaseZip
if (!(Test-Path $zipPath)) {
  throw "Release zip not found: $zipPath"
}

# --- 4) Commit (safe) ---
git add .

git commit -m "Release $version"
if ($LASTEXITCODE -ne 0) {
  Write-Host "[INFO] Nothing new to commit"
}

# --- 5) Tag ---
git tag --list | Select-String "^$tag$" | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Host "[WARN] Tag already exists: $tag"
} else {
  git tag $tag
  Write-Host "[OK] Tag created: $tag"
}

# --- 6) Push ---
git push
git push origin $tag

# --- 7) GitHub Release ---
if (Get-Command gh -ErrorAction SilentlyContinue) {

  gh release view $tag *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[WARN] GitHub release already exists"
  } else {
    gh release create $tag `
      "$zipPath" `
      --title "Simon Physio $version" `
      --notes "Commercial Windows build for Simon Physio $version"
    Write-Host "[OK] GitHub release created"
  }

} else {
  Write-Host ""
  Write-Host "[MANUAL STEP REQUIRED]"
  Write-Host "GitHub CLI (gh) not installed."
  Write-Host "Create a release for tag $tag and upload:"
  Write-Host $zipPath
}

Write-Host ""
Write-Host "[DONE] Commercial GitHub release complete."
