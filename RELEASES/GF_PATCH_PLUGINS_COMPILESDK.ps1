Set-Variable -Name ErrorActionPreference -Value 'Stop'
function Fail([string]$m){ throw $m }
function Log([string]$m){ $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Write-Host ('['+$ts+'] '+$m) }
function Find-PubDevRoot(){
  $roots=@()
  $roots += (Join-Path $env:USERPROFILE '.puro\shared\pub_cache\hosted\pub.dev')
  $roots += (Join-Path $env:USERPROFILE '.pub-cache\hosted\pub.dev')
  if($env:PUB_CACHE){ $roots += (Join-Path $env:PUB_CACHE 'hosted\pub.dev') }
  $roots = $roots | Select-Object -Unique
  foreach($r in $roots){ if(Test-Path -LiteralPath $r){ return $r } }
  Fail ('No pub cache found. Checked: '+($roots -join ', '))
}
function Backup([string]$path){
  $bak = $path + '.bak_patch_' + (Get-Date -Format yyyyMMdd_HHmmss)
  Copy-Item -Force -LiteralPath $path -Destination $bak
  return $bak
}
function Ensure-AndroidProps([string]$gradlePath,[int]$compileSdk,[string]$ns){
  if(!(Test-Path -LiteralPath $gradlePath)){ Fail ('Missing: '+$gradlePath) }
  $txt = Get-Content -Raw -LiteralPath $gradlePath
  if($txt -match '(?im)^\s*compileSdk\b' -or $txt -match '(?im)^\s*compileSdkVersion\b'){ $hasCompile = $true } else { $hasCompile = $false }
  if($txt -match '(?im)^\s*namespace\b'){ $hasNs = $true } else { $hasNs = $false }

  # If no android { } block exists, append one.
  if($txt -notmatch '(?im)^\s*android\s*\{'){
    $bak=Backup $gradlePath
    $add = @()
    $add += ''
    $add += 'android {'
    $add += ('  namespace '''+$ns+'''')
    $add += ('  compileSdk '+$compileSdk)
    $add += '}'
    Set-Content -LiteralPath $gradlePath -Value ($txt + [Environment]::NewLine + ($add -join [Environment]::NewLine) + [Environment]::NewLine) -Encoding UTF8
    Log ('[PATCHED] android{} appended: '+$gradlePath)
    Log ('          backup: '+$bak)
    return
  }

  # Otherwise inject just inside the FIRST android { line.
  if($hasCompile -and $hasNs){ Log ('[OK] Already has compileSdk+namespace: '+$gradlePath); return }
  $bak=Backup $gradlePath
  $lines = Get-Content -LiteralPath $gradlePath
  $out = New-Object System.Collections.Generic.List[string]
  $injected=$false
  foreach($line in $lines){
    $out.Add($line) | Out-Null
    if(-not $injected -and $line -match '^\s*android\s*\{\s*$'){
      if(-not $hasNs){ $out.Add(('  namespace '''+$ns+'''') ) | Out-Null }
      if(-not $hasCompile){ $out.Add(('  compileSdk '+$compileSdk)) | Out-Null }
      $injected=$true
    }
  }
  Set-Content -LiteralPath $gradlePath -Value $out -Encoding UTF8
  Log ('[PATCHED] compileSdk/namespace injected: '+$gradlePath)
  Log ('          backup: '+$bak)
}
Log '=== START PATCH ==='
$pub = Find-PubDevRoot
Log ('PubCache: '+$pub)
$sp = Join-Path $pub 'shared_preferences_android-2.4.18\android\build.gradle'
$ul = Join-Path $pub 'url_launcher_android-6.3.28\android\build.gradle'
$compileSdk=34
try{
  $proj='C:\SIMON\simon_physio'
  $g1=Join-Path $proj 'android\app\build.gradle'
  $g2=Join-Path $proj 'android\app\build.gradle.kts'
  $src=$null
  if(Test-Path -LiteralPath $g1){ $src=Get-Content -Raw -LiteralPath $g1 }
  elseif(Test-Path -LiteralPath $g2){ $src=Get-Content -Raw -LiteralPath $g2 }
  if($src){
    $m=[regex]::Match($src,'(?m)^\s*(compileSdkVersion|compileSdk)\s*(=)?\s*(\d+)\s*$')
    if($m.Success){ $compileSdk=[int]$m.Groups[3].Value }
  }
}catch{}
Log ('compileSdk to enforce: '+$compileSdk)
Ensure-AndroidProps -gradlePath $sp -compileSdk $compileSdk -ns 'io.flutter.plugins.sharedpreferences'
if(Test-Path -LiteralPath $ul){ Ensure-AndroidProps -gradlePath $ul -compileSdk $compileSdk -ns 'io.flutter.plugins.urllauncher' } else { Log ('[WARN] missing: '+$ul) }
Log '=== BUILD ==='
$Proj='C:\SIMON\simon_physio'
$Flutter=(Get-Command flutter -ErrorAction Stop).Source
Push-Location $Proj
try{
  Log 'flutter pub get'; & $Flutter pub get | Out-Host
  Log 'flutter build appbundle --release'; & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
Log '=== END ==='
