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
Log '=== START HARD FIX ==='
$Proj='C:\SIMON\simon_physio'
if(!(Test-Path -LiteralPath $Proj)){ Fail ('Missing project: '+$Proj) }
$Flutter=(Get-Command flutter -ErrorAction Stop).Source
Log ('Flutter: '+$Flutter)
$pub = Find-PubDevRoot
Log ('PubCache: '+$pub)
$compileSdk = Get-CompileSdk $Proj
Log ('compileSdk: '+$compileSdk)
$spGradle = Latest-PluginGradle $pub 'shared_preferences_android'
if(-not $spGradle){ Fail 'shared_preferences_android android/build.gradle not found in pub cache.' }
$ulGradle = Latest-PluginGradle $pub 'url_launcher_android'
if(-not $ulGradle){ Fail 'url_launcher_android android/build.gradle not found in pub cache.' }
Log ('Target SP: '+$spGradle)
Log ('Target UL: '+$ulGradle)
$bak1 = Backup $spGradle
$spLines=@()
$spLines += 'plugins {'
$spLines += '  id ''com.android.library'''
$spLines += '  id ''kotlin-android'''
$spLines += '}'
$spLines += ''
$spLines += 'android {'
$spLines += '  namespace ''io.flutter.plugins.sharedpreferences'''
$spLines += ('  compileSdk '+$compileSdk)
$spLines += '  defaultConfig {'
$spLines += '    minSdk 19'
$spLines += '  }'
$spLines += '  compileOptions {'
$spLines += '    sourceCompatibility JavaVersion.VERSION_1_8'
$spLines += '    targetCompatibility JavaVersion.VERSION_1_8'
$spLines += '  }'
$spLines += '  kotlinOptions { jvmTarget = ''1.8'' }'
$spLines += '}'
$spLines += ''
$spLines += 'dependencies {'
$spLines += '  implementation ''androidx.datastore:datastore-preferences:1.0.0'''
$spLines += '  implementation ''androidx.datastore:datastore:1.0.0'''
$spLines += '  implementation ''org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'''
$spLines += '  implementation ''androidx.preference:preference:1.2.1'''
$spLines += '}'
Write-Text $spGradle $spLines
$spCheck = Get-Content -Raw -LiteralPath $spGradle
if([regex]::IsMatch($spCheck,'\$\d+')){ Fail ('Still corrupted after rewrite: '+$spGradle) }
if(-not ($spCheck -match '(?im)^\s*compileSdk\b')){ Fail ('Missing compileSdk after rewrite: '+$spGradle) }
Log ('[HARD-FIXED] shared_preferences_android build.gradle')
Log ('            backup: '+$bak1)
$bak2 = Backup $ulGradle
$ulLines=@()
$ulLines += 'plugins {'
$ulLines += '  id ''com.android.library'''
$ulLines += '  id ''kotlin-android'''
$ulLines += '}'
$ulLines += ''
$ulLines += 'android {'
$ulLines += '  namespace ''io.flutter.plugins.urllauncher'''
$ulLines += ('  compileSdk '+$compileSdk)
$ulLines += '  defaultConfig {'
$ulLines += '    minSdk 19'
$ulLines += '  }'
$ulLines += '  buildFeatures { buildConfig true }'
$ulLines += '  compileOptions {'
$ulLines += '    sourceCompatibility JavaVersion.VERSION_1_8'
$ulLines += '    targetCompatibility JavaVersion.VERSION_1_8'
$ulLines += '  }'
$ulLines += '  kotlinOptions { jvmTarget = ''1.8'' }'
$ulLines += '}'
$ulLines += ''
$ulLines += 'dependencies {'
$ulLines += '  implementation ''androidx.browser:browser:1.8.0'''
$ulLines += '}'
Write-Text $ulGradle $ulLines
$ulCheck = Get-Content -Raw -LiteralPath $ulGradle
if([regex]::IsMatch($ulCheck,'\$\d+')){ Fail ('Still corrupted after rewrite: '+$ulGradle) }
if(-not ($ulCheck -match '(?im)^\s*compileSdk\b')){ Fail ('Missing compileSdk after rewrite: '+$ulGradle) }
Log ('[HARD-FIXED] url_launcher_android build.gradle')
Log ('            backup: '+$bak2)
Log '=== BUILD bundleRelease ==='
Push-Location $Proj
try{
  & $Flutter clean | Out-Host
  & $Flutter pub get | Out-Host
  & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
Log '=== END ==='
