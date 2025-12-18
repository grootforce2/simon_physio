# FIX_AND_BUILD_WINDOWS.ps1
$ErrorActionPreference = "Stop"

$proj = "C:\SIMON\simon_physio"
$flutter = "C:\Users\iamgr\.puro\envs\stable\flutter\bin\flutter.bat"
$vsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"

Write-Host "==> Checking paths..."
if (!(Test-Path $proj)) { throw "Project not found: $proj" }
if (!(Test-Path $flutter)) { throw "Flutter not found: $flutter" }
if (!(Test-Path $vsDevCmd)) { throw "VsDevCmd not found: $vsDevCmd" }

Set-Location $proj

function Patch-TextFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][hashtable]$Replacements
  )
  if (!(Test-Path $Path)) {
    Write-Host "==> Skip (missing): $Path"
    return
  }
  $t = Get-Content $Path -Raw
  $orig = $t

  foreach ($k in $Replacements.Keys) {
    $t = [regex]::Replace($t, $k, $Replacements[$k])
  }

  if ($t -ne $orig) {
    Set-Content -Path $Path -Value $t -Encoding UTF8
    Write-Host "==> Patched: $Path"
  } else {
    Write-Host "==> No changes: $Path"
  }
}

Write-Host "==> Patching theme const issues + CardThemeData mismatch..."

$themeFile = Join-Path $proj "lib\core\theme\app_theme.dart"

Patch-TextFile -Path $themeFile -Replacements @{
  # If someone wrote: static const ThemeData ...
  'static\s+const\s+ThemeData' = 'static final ThemeData'

  # If someone wrote: static const lightTheme = ThemeData(...)
  'static\s+const(\s+\w+\s*=\s*)ThemeData\(' = 'static final$1ThemeData('

  # Any "const ThemeData(" is invalid (ThemeData isn't const)
  '\bconst\s+ThemeData\s*\(' = 'ThemeData('

  # CardTheme vs CardThemeData mismatch fix (your first error)
  'cardTheme\s*:\s*CardTheme\s*\(' = 'cardTheme: CardThemeData('

  # If CardThemeData is written as const but contains non-const children => remove const
  '\bconst\s+CardThemeData\s*\(' = 'CardThemeData('
  '\bconst\s+CardTheme\s*\('     = 'CardTheme('
}

Write-Host "==> flutter pub get"
& $flutter pub get

Write-Host "==> Building Windows (Release) with VS env + flutter.bat (no PATH needed)"
$cmd = "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && `"$flutter`" build windows --release"
cmd /c $cmd

Write-Host "==> DONE"
