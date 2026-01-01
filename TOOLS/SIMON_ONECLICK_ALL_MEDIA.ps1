param(
  [int]$Videos = 25,
  [switch]$AllowBY,               # allow CC-BY / CC-BY-SA (recommended for videos)
  [int]$MaxMB = 250,              # skip files bigger than this
  [int]$MaxPullPerCat = 1200,
  [switch]$VerboseLog
)

$ErrorActionPreference="Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Safe-Name([string]$s){
  $s = $s -replace '^File:',''
  $s = $s -replace '[\\/:*?"<>|]','_'
  $s = $s -replace '\s+','_'
  $s = $s.Trim('_')
  if($s.Length -gt 140){ $s = $s.Substring(0,140) }
  return $s
}
function Invoke-Json([string]$url){
  $u = [uri]::new(($url.Trim()))
  Invoke-RestMethod -Method Get -Uri $u -Headers @{ "User-Agent"="SimonPhysioSeedBot/1.0 (Windows PowerShell)" }
}

# Local storage
$doc  = [Environment]::GetFolderPath("MyDocuments")
$base = Join-Path $doc "SimonPhysio"
$vidDir  = Join-Path $base "media\exercises\videos"
$seedDir = Join-Path $base "seed"
Ensure-Dir $vidDir
Ensure-Dir $seedDir

$licLogPath = Join-Path $seedDir "wikimedia_licenses_v1.json"
$lic = @()

Write-Host "[OK] Local storage:" -ForegroundColor Green
Write-Host ("  Videos : {0}" -f $vidDir)
Write-Host ("  LicLog : {0}" -f $licLogPath)

# Allowed licenses (from extmetadata)
$allow = New-Object "System.Collections.Generic.HashSet[string]"
$allow.Add("CC0") | Out-Null
$allow.Add("Public domain") | Out-Null
$allow.Add("Public Domain") | Out-Null
$allow.Add("PD") | Out-Null

if($AllowBY){
  $allow.Add("CC BY 4.0") | Out-Null
  $allow.Add("Creative Commons Attribution 4.0") | Out-Null
  $allow.Add("CC BY-SA 4.0") | Out-Null
  $allow.Add("Creative Commons Attribution-Share Alike 4.0") | Out-Null
  $allow.Add("CC BY 3.0") | Out-Null
  $allow.Add("CC BY-SA 3.0") | Out-Null
}

function Get-LicenseName($ii){
  if($null -eq $ii){ return "" }
  if($null -eq $ii.extmetadata){ return "" }
  $m = $ii.extmetadata
  if($m.LicenseShortName -and $m.LicenseShortName.value){ return [string]$m.LicenseShortName.value }
  if($m.License -and $m.License.value){ return [string]$m.License.value }
  return ""
}

function Get-FileInfo([string[]]$titles){
  if(!$titles -or $titles.Count -eq 0){ return @() }
  $t = [string]::Join("|",$titles)
  $enc = [uri]::EscapeDataString($t)
  $url = "https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url|mime|size|extmetadata&titles=$enc"
  $j = Invoke-Json $url
  return $j.query.pages.PSObject.Properties.Value
}

function Get-CategoryFiles([string]$categoryName, [int]$maxPull){
  $cmtitle = [uri]::EscapeDataString(("Category:" + $categoryName))
  $out = @()
  $cmcontinue = $null

  while($out.Count -lt $maxPull){
    $limit = [Math]::Min(500, ($maxPull - $out.Count))
    $url = "https://commons.wikimedia.org/w/api.php?action=query&format=json&list=categorymembers&cmtype=file&cmlimit=$limit&cmtitle=$cmtitle"
    if($cmcontinue){
      $url += "&cmcontinue=" + [uri]::EscapeDataString($cmcontinue)
    }

    $j = Invoke-Json $url
    if($j.query -and $j.query.categorymembers){
      $out += $j.query.categorymembers
    }

    if($j.continue -and $j.continue.cmcontinue){
      $cmcontinue = $j.continue.cmcontinue
    } else {
      break
    }
  }
  return $out
}

# Title filters (keep it clinical, not internet-chaos)
$includeWords = @(
  "exercise","exercises","workout","training","stretch","stretching",
  "mobility","rehab","rehabilitation","physio","physiotherapy",
  "strength","strengthening","range of motion","rom",
  "warm up","warm-up","cool down","cool-down",
  "yoga","pilates","calisthenics"
)
$excludeWords = @(
  # politics/news/press/war etc
  "asamblea","venezuela","bolsonaro","president","minister","government","senate",
  "speech","address","statement","press","conference","debate","election","campaign",
  "national","politic","political","war","military","army",
  # generic junk
  "news","breaking","interview","podcast","music video","concert",
  "episode","trailer","movie","film","documentary"
)
function Title-Allowed([string]$title){
  if([string]::IsNullOrWhiteSpace($title)){ return $false }
  $t = $title.ToLowerInvariant()

  foreach($bad in $excludeWords){
    if($t -like "*$bad*"){ return $false }
  }

  foreach($good in $includeWords){
    if($t -like "*$good*"){ return $true }
  }
  return $false
}

function Download-Videos([int]$want){
  if($want -le 0){ return 0 }

  # Categories that are more likely to be actual exercise content
  $cats = @(
    "Exercise videos",
    "Fitness videos",
    "Stretching videos",
    "Videos of physical exercise",
    "Physiotherapy",
    "Rehabilitation",
    "Pilates videos",
    "Calisthenics videos",
    "Videos of yoga"
  )

  $downloaded = 0
  $seen = New-Object "System.Collections.Generic.HashSet[string]"

  foreach($cat in $cats){
    if($downloaded -ge $want){ break }
    if($VerboseLog){ Write-Host ("[CAT] {0}" -f $cat) -ForegroundColor DarkGray }

    $files = Get-CategoryFiles $cat $MaxPullPerCat
    if(!$files -or $files.Count -eq 0){ continue }

    $batch = New-Object System.Collections.Generic.List[string]

    foreach($f in $files){
      if($downloaded -ge $want){ break }

      $title = $f.title
      if(!$title){ continue }
      if($seen.Contains($title)){ continue }
      $seen.Add($title) | Out-Null

      # HARD FILTER on title before doing imageinfo calls
      if(-not (Title-Allowed $title)){ continue }

      $batch.Add($title) | Out-Null

      if($batch.Count -ge 10){
        $pages = Get-FileInfo $batch.ToArray()
        foreach($p in $pages){
          if($downloaded -ge $want){ break }
          if(!$p.imageinfo -or $p.imageinfo.Count -eq 0){ continue }

          $ii = $p.imageinfo[0]
          $url = $ii.url
          if(!$url){ continue }

          # Must be video mime
          if($ii.mime -and ([string]$ii.mime) -notlike "video/*"){ continue }

          # Must be video extension (Commons audio is often .ogg, video is .ogv/.webm)
          $ext = ([IO.Path]::GetExtension($url)).ToLowerInvariant()
          if($ext -notin @(".webm",".ogv")){ continue }

          # Skip huge files
          $maxBytes = [int64]$MaxMB * 1024 * 1024
          if($ii.size -and ([int64]$ii.size) -gt $maxBytes){ continue }

          $licName = Get-LicenseName $ii
          if([string]::IsNullOrWhiteSpace($licName)){ continue }
          if(-not $allow.Contains($licName)){ continue }

          $name = Safe-Name $p.title
          if([string]::IsNullOrWhiteSpace($name)){ continue }

          # Ensure single extension only
          if($name.ToLowerInvariant().EndsWith($ext)){ $destName = $name }
          else { $destName = $name + $ext }

          $dest = Join-Path $vidDir $destName
          if(Test-Path $dest){ continue }

          try {
            Invoke-WebRequest -Uri ([uri]$url) -OutFile $dest -Headers @{ "User-Agent"="SimonPhysioSeedBot/1.0" } | Out-Null
            $downloaded++

            $attrib = ""
            if($ii.extmetadata -and $ii.extmetadata.Attribution -and $ii.extmetadata.Attribution.value){
              $attrib = [string]$ii.extmetadata.Attribution.value
            }

            $lic += [pscustomobject]@{
              kind = "video"
              title = $p.title
              source_page = ("https://commons.wikimedia.org/wiki/" + ($p.title -replace " ", "_"))
              file_url = $url
              mime = $ii.mime
              bytes = $ii.size
              license = $licName
              attribution = $attrib
              saved_to = $dest
              category = $cat
              fetched_utc = (Get-Date).ToUniversalTime().ToString("o")
            }

            Write-Host ("[DL] {0}/{1} ({2}) {3}" -f $downloaded,$want,$licName,$dest) -ForegroundColor Cyan
          } catch {
            if(Test-Path $dest){ Remove-Item $dest -Force -ErrorAction SilentlyContinue }
          }
        }
        $batch.Clear()
      }
    }

    # flush any remaining in batch
    if($batch.Count -gt 0 -and $downloaded -lt $want){
      $pages = Get-FileInfo $batch.ToArray()
      foreach($p in $pages){
        if($downloaded -ge $want){ break }
        if(!$p.imageinfo -or $p.imageinfo.Count -eq 0){ continue }

        $ii = $p.imageinfo[0]
        $url = $ii.url
        if(!$url){ continue }

        if($ii.mime -and ([string]$ii.mime) -notlike "video/*"){ continue }
        $ext = ([IO.Path]::GetExtension($url)).ToLowerInvariant()
        if($ext -notin @(".webm",".ogv")){ continue }

        $maxBytes = [int64]$MaxMB * 1024 * 1024
        if($ii.size -and ([int64]$ii.size) -gt $maxBytes){ continue }

        $licName = Get-LicenseName $ii
        if([string]::IsNullOrWhiteSpace($licName)){ continue }
        if(-not $allow.Contains($licName)){ continue }

        $name = Safe-Name $p.title
        if([string]::IsNullOrWhiteSpace($name)){ continue }

        if($name.ToLowerInvariant().EndsWith($ext)){ $destName = $name } else { $destName = $name + $ext }
        $dest = Join-Path $vidDir $destName
        if(Test-Path $dest){ continue }

        try {
          Invoke-WebRequest -Uri ([uri]$url) -OutFile $dest -Headers @{ "User-Agent"="SimonPhysioSeedBot/1.0" } | Out-Null
          $downloaded++
          Write-Host ("[DL] {0}/{1} ({2}) {3}" -f $downloaded,$want,$licName,$dest) -ForegroundColor Cyan
        } catch {
          if(Test-Path $dest){ Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        }
      }
      $batch.Clear()
    }
  }

  return $downloaded
}

Write-Host ("`n==> Fetching Wikimedia exercise videos: {0}  AllowBY={1}  MaxMB={2}  MaxPullPerCat={3}" -f $Videos,$AllowBY.IsPresent,$MaxMB,$MaxPullPerCat) -ForegroundColor Yellow

$gotVid = Download-Videos $Videos
$lic | ConvertTo-Json -Depth 8 | Set-Content -Path $licLogPath -Encoding UTF8

Write-Host "`n[OK] Done." -ForegroundColor Green
Write-Host ("  Downloaded videos: {0}" -f $gotVid)
Write-Host ("  License log      : {0}" -f $licLogPath)

if($gotVid -lt $Videos){
  Write-Host ("[WARN] Only found {0}/{1} matching videos under current filters. Increase MaxPullPerCat or loosen includeWords." -f $gotVid,$Videos) -ForegroundColor Yellow
}




