$repo="C:\SIMON\simon_physio"; $tools=Join-Path $repo "TOOLS"; New-Item -ItemType Directory -Force -Path $tools | Out-Null
$fix=Join-Path $tools "FIX_RUN_TEST_AND_LAUNCH.ps1"

@'
[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio",
  [string]$RunTest = "C:\SIMON\RUN_TEST"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Pick-FirstExisting([string[]]$paths){ $paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1 }

function Fix-And-Launch([string]$rt){
  $dist = Join-Path $Repo "DIST"
  $portable = Join-Path $dist "windows_release_portable"
  $rel1 = Join-Path $Repo "build\windows\x64\runner\Release"
  $rel2 = Join-Path $Repo "build\windows\runner\Release"

  $src = Pick-FirstExisting @($portable,$rel1,$rel2)
  if(-not $src){ throw "No runtime source found. Expected DIST\windows_release_portable or build\windows\...\Release." }

  $dll = Join-Path $src "flutter_windows.dll"
  if(!(Test-Path $dll)){ throw "flutter_windows.dll missing in source: $src" }

  Ensure-Dir $rt

  $exe = Get-ChildItem $rt -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if(-not $exe){
    $srcExe = Get-ChildItem $src -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if(-not $srcExe){ throw "No exe found in source: $src" }
    Copy-Item $srcExe.FullName $rt -Force
    $exe = Get-ChildItem $rt -Filter "*.exe" | Select-Object -First 1
  }

  Copy-Item (Join-Path $src "flutter_windows.dll") $rt -Force
  if(Test-Path (Join-Path $src "data"))    { Copy-Item (Join-Path $src "data")    $rt -Recurse -Force }
  if(Test-Path (Join-Path $src "plugins")) { Copy-Item (Join-Path $src "plugins") $rt -Recurse -Force }

  if(!(Test-Path (Join-Path $rt "flutter_windows.dll"))){
    throw "DLL missing after copy - likely Defender deleting it."
  }

  Write-Host "[OK] Runtime fixed in $rt"
  Write-Host "[OK] Launching $($exe.FullName)"
  Start-Process -FilePath $exe.FullName -WorkingDirectory $rt
}

try {
  Fix-And-Launch -rt $RunTest
}
catch {
  $desk = Join-Path $env:USERPROFILE "Desktop\RUN_TEST"
  Write-Host "[WARN] First attempt failed: $($_.Exception.Message)"
  Write-Host "[WARN] Retrying from Desktop path: $desk"
  Fix-And-Launch -rt $desk
}
'@ | Set-Content -LiteralPath $fix -Encoding UTF8

Write-Host "[OK] Wrote: $fix"
powershell -NoProfile -ExecutionPolicy Bypass -File $fix
