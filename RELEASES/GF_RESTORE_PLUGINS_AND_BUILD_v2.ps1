Set-Variable -Name ErrorActionPreference -Value 'Stop'
function Fail([string]$m){ throw $m }
function Log([string]$m){ $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Write-Host ('['+$ts+'] '+$m) }
$Proj='C:\SIMON\simon_physio'
if(!(Test-Path -LiteralPath $Proj)){ Fail ('Missing project: '+$Proj) }
$Flutter=(Get-Command flutter -ErrorAction Stop).Source
Log ('Flutter: '+$Flutter)
$roots=@()
$roots += (Join-Path $env:USERPROFILE '.puro\shared\pub_cache\hosted\pub.dev')
$roots += (Join-Path $env:USERPROFILE '.pub-cache\hosted\pub.dev')
if($env:PUB_CACHE){ $roots += (Join-Path $env:PUB_CACHE 'hosted\pub.dev') }
$roots = $roots | Select-Object -Unique
$pub=$null
foreach($r in $roots){ if(Test-Path -LiteralPath $r){ $pub=$r; break } }
if(-not $pub){ Fail ('No pub cache found. Checked: '+($roots -join ', ')) }
Log ('PubCache: '+$pub)
function LatestBak([string]$gradlePath){
  $dir = Split-Path $gradlePath -Parent
  $name = Split-Path $gradlePath -Leaf
  $baks = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($name + '.bak_*') } | Sort-Object LastWriteTime -Descending
  if($baks -and $baks.Count -gt 0){ return $baks[0].FullName }
  return $null
}
$targets=@(
  @{ name='shared_preferences_android'; ver='2.4.18' },
  @{ name='url_launcher_android';        ver='6.3.28' }
)
$restored=0
foreach($t in $targets){
  $pkg = ($t.name + '-' + $t.ver)
  $g = Join-Path $pub ($pkg + '\android\build.gradle')
  if(!(Test-Path -LiteralPath $g)){ Log ('[WARN] Missing: '+$g); continue }
  $bak = LatestBak $g
  if(-not $bak){ Fail ('No .bak backup found for: '+$g+'  (we need the backup to undo the bad rewrite)') }
  Copy-Item -Force -LiteralPath $bak -Destination $g
  Log ('[RESTORED] '+$g)
  Log ('           from: '+$bak)
  $restored++
}
Log ('Restored count: '+$restored)
if($restored -lt 2){ Fail 'Did not restore both plugins. Something is missing in pub cache.' }
Push-Location $Proj
try{
  Log '=== flutter clean ==='; & $Flutter clean | Out-Host
  Log '=== flutter pub get ==='; & $Flutter pub get | Out-Host
  Log '=== flutter build apk --release ==='; & $Flutter build apk --release | Out-Host
  Log '=== flutter build appbundle --release ==='; & $Flutter build appbundle --release | Out-Host
} finally { Pop-Location }
Log '[OK] Done'
