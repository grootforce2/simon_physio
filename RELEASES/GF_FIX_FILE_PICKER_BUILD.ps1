Stop='Stop'
function Fail([string]$m){ throw $m }
function CRLF([string]$s){ $s=($s -replace "
","
") -replace "","
"; return ($s -replace "
","
") }
function W([string]$path,[string]$text){ [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null; [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false)) }
$Proj='C:\SIMON\simon_physio'
if(!(Test-Path -LiteralPath $Proj)){ Fail ('Missing project: '+$Proj) }
$Rel=Join-Path $Proj 'RELEASES'; New-Item -ItemType Directory -Force -Path $Rel | Out-Null
$Log=Join-Path $Rel ('report_FIX_FILE_PICKER_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.txt')
W $Log (CRLF 'SIMON_PHYSIO FIX FILE_PICKER REPORT
')
function Log([string]$m){ $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $line='['+$ts+'] '+$m; Write-Host $line; Add-Content -LiteralPath $Log -Value $line -Encoding UTF8 }
Log '=== START ==='
$Flutter=(Get-Command flutter -ErrorAction Stop).Source; Log ('Flutter: '+$Flutter)
$CompileSdk=34
try{
  $g1=Join-Path $Proj 'android\app\build.gradle'
  $g2=Join-Path $Proj 'android\app\build.gradle.kts'
  $src=$null
  if(Test-Path -LiteralPath $g1){ $src=Get-Content -Raw -LiteralPath $g1 }
  elseif(Test-Path -LiteralPath $g2){ $src=Get-Content -Raw -LiteralPath $g2 }
  if($src){
    $m=[regex]::Match($src,'(?m)^\s*(compileSdkVersion|compileSdk)\s*(=)?\s*(\d+)\s*$')
    if($m.Success){ $CompileSdk=[int]$m.Groups[3].Value }
  }
}catch{}
Log ('compileSdk: '+$CompileSdk)
$roots=@()
if($env:PUB_CACHE){ $roots += (Join-Path $env:PUB_CACHE 'hosted\pub.dev') }
$roots += (Join-Path $env:USERPROFILE '.puro\shared\pub_cache\hosted\pub.dev')
$roots += (Join-Path $env:USERPROFILE '.pub-cache\hosted\pub.dev')
$roots = $roots | Select-Object -Unique
$targets=@()
foreach($r in $roots){
  if(Test-Path -LiteralPath $r){
    $targets += Get-ChildItem -LiteralPath $r -Recurse -File -Filter build.gradle -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\file_picker-[^\\]+\\android\\build\.gradle$' }
  }
}
$targets = $targets | Sort-Object FullName -Unique
if(-not $targets -or $targets.Count -lt 1){ Fail ('file_picker android\build.gradle not found. Checked: '+($roots -join ', ')) }
Log ('Targets found: '+$targets.Count)
$fixed=0
foreach($t in $targets){
  $path=$t.FullName
  Log ('--- FIXING: '+$path)
  $bak=$path+'.bak_'+(Get-Date -Format yyyyMMdd_HHmmss)
  Copy-Item -Force -LiteralPath $path -Destination $bak
  $ns='com.mr.flutter.plugin.filepicker'
  try{
    $mf=Join-Path (Split-Path $path -Parent) 'src\main\AndroidManifest.xml'
    if(Test-Path -LiteralPath $mf){
      $raw=Get-Content -Raw -LiteralPath $mf
      $mm=[regex]::Match($raw,'(?i)<manifest[^>]*\spackage\s*=\s*"([^"]+)"')
      if($mm.Success){ $ns=$mm.Groups[1].Value.Trim() }
    }
  }catch{}
  $L=@()
  $L+='plugins {'
  $L+='  id ''com.android.library'''
  $L+='  id ''kotlin-android'''
  $L+='}'
  $L+=''
  $L+='android {'
  $L+=('  namespace '''+$ns+'''')
  $L+=('  compileSdk '+$CompileSdk)
  $L+='  defaultConfig {'
  $L+='    minSdk 19'
  $L+='  }'
  $L+='  compileOptions {'
  $L+='    sourceCompatibility JavaVersion.VERSION_1_8'
  $L+='    targetCompatibility JavaVersion.VERSION_1_8'
  $L+='  }'
  $L+='  kotlinOptions {'
  $L+='    jvmTarget = ''1.8'''
  $L+='  }'
  $L+='}'
  $L+=''
  $L+='dependencies {'
  $L+='}'
  $content = CRLF (($L -join "
") + "
")
  W $path $content
  $check = Get-Content -Raw -LiteralPath $path
  if([regex]::IsMatch($check,'\$\d+')){ Fail ('Rewrite failed (still corrupt): '+$path) }
  if(-not [regex]::IsMatch($check,'(?i)\bcompileSdk\b')){ Fail ('Rewrite failed (no compileSdk): '+$path) }
  if(-not [regex]::IsMatch($check,'(?i)\bnamespace\b')){ Fail ('Rewrite failed (no namespace): '+$path) }
  Log ('[FIXED] '+$path)
  Log ('        backup: '+$bak)
  Log ('        namespace: '+$ns)
  $fixed++
}
Log ('Fixed count: '+$fixed)
Push-Location $Proj
try{
  Log '=== flutter clean ==='; & $Flutter clean | Out-Host
  Log '=== flutter pub get ==='; & $Flutter pub get | Out-Host
  Log '=== flutter build apk --release ==='; & $Flutter build apk --release | Out-Host
  Log '=== flutter build appbundle --release ==='; & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
Log '[OK] Done'
Log ('Report: '+$Log)
