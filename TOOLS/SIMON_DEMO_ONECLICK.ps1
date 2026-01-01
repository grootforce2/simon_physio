param(
  [int]$Videos = 25,
  [switch]$AllowBY,
  [int]$MaxMB = 800,
  [int]$MaxPullPerCat = 120000,
  [int]$BatchSize = 10,
  [switch]$VerboseLog,
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

$root = "C:\SIMON\simon_physio\TOOLS"
$packBuilder = Join-Path $root "SIMON_DEMO_PACK_BUILDER.ps1"
$mediaScript = Join-Path $root "SIMON_ONECLICK_ALL_MEDIA.ps1"

$logDir = Join-Path $env:USERPROFILE "Documents\SimonPhysio\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "oneclick.log"

function Log($msg){
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  $line | Out-File $log -Append -Encoding UTF8
  Write-Host $line
}

"=== Simon Physio Demo ONE-CLICK ===" | Out-File $log -Append -Encoding UTF8
Log "Started"

if(!(Test-Path $packBuilder)){ throw "Missing: $packBuilder" }
if(!(Test-Path $mediaScript)){ throw "Missing: $mediaScript" }

Log "Running pack builder: $packBuilder"
$packArgs = @("-NoProfile","-ExecutionPolicy","Bypass","-File",$packBuilder)
if($OpenFolder){ $packArgs += "-OpenFolder" }
& powershell @packArgs

# resolve latest demo pack folder
$demoRoot = Join-Path $env:USERPROFILE "Documents\SimonPhysio\demo_pack"
$latest = Get-ChildItem $demoRoot -Directory -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if($latest){
  Log "[OK] Latest demo pack: $($latest.FullName)"
} else {
  Log "[WARN] No demo pack folder found under $demoRoot"
}

Log "Running media fetch: $mediaScript (Videos=$Videos AllowBY=$($AllowBY.IsPresent) MaxMB=$MaxMB MaxPullPerCat=$MaxPullPerCat BatchSize=$BatchSize)"

$mediaArgs = @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File", $mediaScript,
  "-Videos", $Videos,
  "-MaxMB", $MaxMB,
  "-MaxPullPerCat", $MaxPullPerCat,
  "-BatchSize", $BatchSize
)
if($AllowBY){ $mediaArgs += "-AllowBY" }
if($VerboseLog){ $mediaArgs += "-VerboseLog" }

& powershell @mediaArgs 2>&1 | Tee-Object -FilePath $log -Append | Out-Host

Log "Finished"
"=== DONE ===" | Out-File $log -Append -Encoding UTF8
