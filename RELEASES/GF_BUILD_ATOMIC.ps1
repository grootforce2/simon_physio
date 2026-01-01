$ErrorActionPreference="Stop"
function Fail([string]$m){ throw $m }
function CRLF([string]$s){ $s = ($s -replace "`r`n","`n") -replace "`r","`n"; return ($s -replace "`n","`r`n") }
function EnsureDir([string]$d){ if([string]::IsNullOrWhiteSpace($d)){ Fail "EnsureDir blank path" }; New-Item -ItemType Directory -Force -Path $d | Out-Null }
function W([string]$p,[string]$t){ EnsureDir ([IO.Path]::GetDirectoryName($p)); [IO.File]::WriteAllText($p,$t,[Text.UTF8Encoding]::new($false)) }
$Proj = 'C:\SIMON\simon_physio'
$Rel  = Join-Path $Proj "RELEASES"
EnsureDir $Rel
$Log = Join-Path $Rel ("report_"+(Get-Date -Format yyyyMMdd_HHmmss)+".txt")
W $Log (CRLF "SIMON_PHYSIO BUILD REPORT`n")
function Log([string]$m){ $ts=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); $line="["+$ts+"] "+$m; Write-Host $line; Add-Content -LiteralPath $Log -Value $line -Encoding UTF8 }
Log "=== START ==="
if(!(Test-Path -LiteralPath $Proj)){ Fail ("Missing project: "+$Proj) }
$Flutter = (Get-Command flutter -ErrorAction Stop).Source
Log ("Flutter: "+$Flutter)
# compileSdk from app gradle if possible, else 34
$CompileSdk = 34
try{
  $g1=Join-Path $Proj "android\app\build.gradle"
  $g2=Join-Path $Proj "android\app\build.gradle.kts"
  $src=$null
  if(Test-Path -LiteralPath $g1){ $src=Get-Content -Raw -LiteralPath $g1 }
  elseif(Test-Path -LiteralPath $g2){ $src=Get-Content -Raw -LiteralPath $g2 }
  if($src){
    $m=[regex]::Match($src,"(?m)^\s*(compileSdkVersion|compileSdk)\s*(=)?\s*(\d+)\s*$")
    if($m.Success){ $CompileSdk=[int]$m.Groups[3].Value }
  }
}catch{}
Log ("compileSdk: "+$CompileSdk)
# locate pub cache hosted\pub.dev (puro + pub-cache)
$Roots=@()
if($env:PUB_CACHE){ $Roots += $env:PUB_CACHE }
$Roots += (Join-Path $env:USERPROFILE ".puro\shared\pub_cache")
$Roots += (Join-Path $env:USERPROFILE ".pub-cache")
$Roots = $Roots | Select-Object -Unique
$Pub=$null
foreach($r in $Roots){
  $p=Join-Path $r "hosted\pub.dev"
  if(Test-Path -LiteralPath $p){ $Pub=$p; break }
}
if(-not $Pub){ Fail ("Could not locate pub cache hosted\pub.dev. Checked: "+($Roots -join ", ")) }
Log ("PubCache: "+$Pub)
# scan + rewrite broken plugin android/build.gradle files
$gradles = Get-ChildItem -LiteralPath $Pub -Recurse -File -Filter build.gradle -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match "\\android\\build\.gradle$" }
if(-not $gradles){ Fail "No plugin android/build.gradle files found to scan." }
$considered=0; $fixed=0
foreach($g in $gradles){
  $considered++
  $path=$g.FullName
  $txt=""
  try{ $txt=Get-Content -Raw -LiteralPath $path }catch{ continue }
  $isCorrupt = [regex]::IsMatch($txt,"\$\d+")
  $hasCompile = [regex]::IsMatch($txt,"(?i)compileSdk")
  $hasNs = [regex]::IsMatch($txt,"(?i)namespace")
  if(-not ($isCorrupt -or -not $hasCompile -or -not $hasNs)){ continue }
  $ns=$null
  try{
    $mf=Join-Path (Split-Path $path -Parent) "src\main\AndroidManifest.xml"
    if(Test-Path -LiteralPath $mf){
      $raw=Get-Content -Raw -LiteralPath $mf
      $mm=[regex]::Match($raw,"(?i)<manifest[^>]*\spackage\s*=\s*`"([^`"]+)`"")
      if($mm.Success){ $ns=$mm.Groups[1].Value.Trim() }
    }
  }catch{}
  if(-not $ns){
    $pluginFolder = Split-Path (Split-Path $path -Parent) -Parent
    $pluginName = [IO.Path]::GetFileName($pluginFolder)
    $safe = ($pluginName -replace "[^a-zA-Z0-9]+","").ToLowerInvariant()
    if(-not $safe){ $safe="plugin" }
    $ns = "com.grootforce.autofix."+$safe
  }
  $bak=$path+".bak_"+(Get-Date -Format yyyyMMdd_HHmmss)
  Copy-Item -Force -LiteralPath $path -Destination $bak
  $L=@()
  $L+="plugins {"
  $L+="  id 'com.android.library'"
  $L+="  id 'kotlin-android'"
  $L+="}"
  $L+=""
  $L+="android {"
  $L+=("  namespace '"+$ns+"'")
  $L+=("  compileSdk "+$CompileSdk)
  $L+="  defaultConfig {"
  $L+="    minSdk 19"
  $L+="  }"
  $L+="  compileOptions {"
  $L+="    sourceCompatibility JavaVersion.VERSION_1_8"
  $L+="    targetCompatibility JavaVersion.VERSION_1_8"
  $L+="  }"
  $L+="  kotlinOptions {"
  $L+="    jvmTarget = '1.8'"
  $L+="  }"
  $L+="}"
  $L+=""
  $L+="dependencies {"
  $L+="}"
  $content = CRLF (($L -join "`n") + "`n")
  W $path $content
  $check=Get-Content -Raw -LiteralPath $path
  if([regex]::IsMatch($check,"\$\d+")){ Fail ("Rewrite failed (still corrupt): "+$path) }
  if(-not [regex]::IsMatch($check,"(?i)compileSdk")){ Fail ("Rewrite failed (no compileSdk): "+$path) }
  if(-not [regex]::IsMatch($check,"(?i)namespace")){ Fail ("Rewrite failed (no namespace): "+$path) }
  $fixed++
  Log ("[FIXED] "+$path)
  Log ("        backup: "+$bak)
  Log ("        namespace: "+$ns)
}
Log ("Gradle files considered: "+$considered)
Log ("Gradle files fixed     : "+$fixed)
if($fixed -lt 1){ Fail "No broken plugin Gradle files were fixed, but build is failing. Something is off." }
# build
Push-Location $Proj
try{
  Log "=== flutter clean ==="; & $Flutter clean | Out-Host
  Log "=== flutter pub get ==="; & $Flutter pub get | Out-Host
  Log "=== flutter build apk --release ==="; & $Flutter build apk --release | Out-Host
  Log "=== flutter build appbundle --release ==="; & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
# collect outputs + hashes
Log "=== RELEASES + HASHES ==="
$apk=Join-Path $Proj "build\app\outputs\flutter-apk\app-release.apk"
$aab=Join-Path $Proj "build\app\outputs\bundle\release\app-release.aab"
if(!(Test-Path -LiteralPath $apk)){ Fail ("NO APK FOUND: "+$apk) }
if(!(Test-Path -LiteralPath $aab)){ Fail ("NO AAB FOUND: "+$aab) }
$stamp=Get-Date -Format yyyyMMdd_HHmmss
$apkOut=Join-Path $Rel ("simon_physio_release_"+$stamp+".apk")
$aabOut=Join-Path $Rel ("simon_physio_release_"+$stamp+".aab")
Copy-Item -Force -LiteralPath $apk -Destination $apkOut
Copy-Item -Force -LiteralPath $aab -Destination $aabOut
$h1=Get-FileHash -Algorithm SHA256 -LiteralPath $apkOut
$h2=Get-FileHash -Algorithm SHA256 -LiteralPath $aabOut
Log ("APK   : "+$apkOut) ; Log ("SHA256: "+$h1.Hash)
Log ("AAB   : "+$aabOut) ; Log ("SHA256: "+$h2.Hash)
Log "[OK] ScanFix completed"
Log "[OK] Build succeeded"
Log ("Report saved: "+$Log)
Log "=== END ==="
