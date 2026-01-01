Set-Variable -Name ErrorActionPreference -Value 'Stop'
function Fail([string]$m){ throw $m }
function Log([string]$m){ $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Write-Host ('['+$ts+'] '+$m) }
function Backup([string]$path){ $bak=$path+'.bak_hardfix_'+(Get-Date -Format yyyyMMdd_HHmmss); Copy-Item -Force -LiteralPath $path -Destination $bak; return $bak }
function Find-PubDevRoot(){
  $roots=@()
  $roots += (Join-Path $env:USERPROFILE '.puro\shared\pub_cache\hosted\pub.dev')
  $roots += (Join-Path $env:USERPROFILE '.pub-cache\hosted\pub.dev')
  if($env:PUB_CACHE){ $roots += (Join-Path $env:PUB_CACHE 'hosted\pub.dev') }
  $roots = $roots | Select-Object -Unique
  foreach($r in $roots){ if(Test-Path -LiteralPath $r){ return $r } }
  Fail ('No pub cache found. Checked: '+($roots -join ', '))
}
function Get-CompileSdk([string]$proj){
  $cs=34
  try{
    $g1=Join-Path $proj 'android\app\build.gradle'
    $g2=Join-Path $proj 'android\app\build.gradle.kts'
    $src=$null
    if(Test-Path -LiteralPath $g1){ $src=Get-Content -Raw -LiteralPath $g1 }
    elseif(Test-Path -LiteralPath $g2){ $src=Get-Content -Raw -LiteralPath $g2 }
    if($src){
      $m=[regex]::Match($src,'(?m)^\s*(compileSdkVersion|compileSdk)\s*(=)?\s*(\d+)\s*$')
      if($m.Success){ $cs=[int]$m.Groups[3].Value }
    }
  }catch{}
  return $cs
}
function Write-Text([string]$path,[string[]]$lines){
  [IO.File]::WriteAllText($path, ($lines -join [Environment]::NewLine)+[Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
function Latest-PluginGradle([string]$pubRoot,[string]$prefix){
  $dirs = Get-ChildItem -LiteralPath $pubRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($prefix+'-*') }
  if(-not $dirs){ return $null }
  $d = $dirs | Sort-Object Name -Descending | Select-Object -First 1
  $g = Join-Path $d.FullName 'android\build.gradle'
  if(Test-Path -LiteralPath $g){ return $g }
  return $null
}
Log '=== START HARD FIX (video_player_android) ==='
$Proj='C:\SIMON\simon_physio'
if(!(Test-Path -LiteralPath $Proj)){ Fail ('Missing project: '+$Proj) }
$Flutter=(Get-Command flutter -ErrorAction Stop).Source
Log ('Flutter: '+$Flutter)
$pub = Find-PubDevRoot
Log ('PubCache: '+$pub)
$compileSdk = Get-CompileSdk $Proj
Log ('compileSdk: '+$compileSdk)
$vpGradle = Latest-PluginGradle $pub 'video_player_android'
if(-not $vpGradle){ Fail 'video_player_android android/build.gradle not found in pub cache.' }
Log ('Target VP: '+$vpGradle)
$bak = Backup $vpGradle
$L=@()
$L += 'plugins {'
$L += '  id ''com.android.library'''
$L += '  id ''kotlin-android'''
$L += '}'
$L += ''
$L += 'android {'
$L += '  namespace ''io.flutter.plugins.videoplayer'''
$L += ('  compileSdk '+$compileSdk)
$L += '  defaultConfig { minSdk 19 }'
$L += '  compileOptions {'
$L += '    sourceCompatibility JavaVersion.VERSION_1_8'
$L += '    targetCompatibility JavaVersion.VERSION_1_8'
$L += '  }'
$L += '  kotlinOptions { jvmTarget = ''1.8'' }'
$L += '}'
$L += ''
$L += 'dependencies {'
$L += '}'
Write-Text $vpGradle $L
$check = Get-Content -Raw -LiteralPath $vpGradle
if([regex]::IsMatch($check,'\$\d+')){ Fail ('Still corrupted after rewrite: '+$vpGradle) }
if(-not ($check -match '(?im)^\s*compileSdk\b')){ Fail ('Missing compileSdk after rewrite: '+$vpGradle) }
if(-not ($check -match 'androidx\.media3')){ Fail ('Missing media3 deps after rewrite: '+$vpGradle) }
Log '[HARD-FIXED] video_player_android build.gradle'
Log ('            backup: '+$bak)
Log '=== BUILD bundleRelease ==='
Push-Location $Proj
try{
  & $Flutter clean | Out-Host
  & $Flutter pub get | Out-Host
  & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
Log '=== END ==='
