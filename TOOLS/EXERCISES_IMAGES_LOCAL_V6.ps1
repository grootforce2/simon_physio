# ==========================================================
# EXERCISES IMAGES LOCAL V6 (FIXED)
# - Adds local image picker + copies into Documents
# - Renders thumbnails in Exercise Detail
# - Ensures deps + build + run (Windows)
# ==========================================================
$ErrorActionPreference = "Stop"

$root     = "C:\SIMON\simon_physio"
$flutter  = "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat"
$pubspec  = "$root\pubspec.yaml"
$dartFile = "$root\lib\premium\screens\exercises_screen.dart"
$exe      = "$root\build\windows\x64\runner\Release\simon_physio.exe"

Write-Host "==> EXERCISES IMAGES LOCAL V6" -ForegroundColor Cyan
Write-Host "Root: $root"

if (!(Test-Path $flutter))  { throw "Flutter not found: $flutter" }
if (!(Test-Path $pubspec)) { throw "pubspec.yaml not found: $pubspec" }
if (!(Test-Path $dartFile)) { throw "Dart file not found: $dartFile" }

function Ensure-Dep {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$PubText
  )
  if ($PubText -match "(?m)^\s+$([regex]::Escape($Name))\s*:") { return $PubText }
  if ($PubText -notmatch "(?m)^dependencies:\s*$") { throw "No 'dependencies:' block found in pubspec.yaml" }
  $insert = ("  {0}: {1}`r`n" -f $Name, $Version)
  return [regex]::Replace($PubText, "(?m)^dependencies:\s*$", ("dependencies:`r`n{0}" -f $insert), 1)
}

function Add-ImportsIfMissing {
  param([string]$Text)

  $need = @(
    "import 'dart:io';",
    "import 'package:file_picker/file_picker.dart';",
    "import 'package:path_provider/path_provider.dart';"
  )

  # Find the import block at the top
  $m = [regex]::Match($Text, "(?s)^(import\s+['""][^'""]+['""];\s*)+")
  if (!$m.Success) { return $Text }

  $importBlock = $m.Value
  $rest = $Text.Substring($m.Length)

  foreach ($imp in $need) {
    if ($importBlock -notmatch [regex]::Escape($imp)) {
      $importBlock = $importBlock.TrimEnd() + "`r`n" + $imp + "`r`n"
    }
  }

  return $importBlock + $rest
}

# -------------------------
# 1) Backup Dart + Pubspec
# -------------------------
$bakD = "$dartFile.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $dartFile $bakD -Force
Write-Host "[OK] Backup dart: $bakD" -ForegroundColor DarkGray

$pub = Get-Content $pubspec -Raw
$pub2 = $pub
$pub2 = Ensure-Dep -Name "file_picker"        -Version "^8.0.6" -PubText $pub2
$pub2 = Ensure-Dep -Name "path_provider"      -Version "^2.1.5" -PubText $pub2
$pub2 = Ensure-Dep -Name "shared_preferences" -Version "^2.2.3" -PubText $pub2
$pub2 = Ensure-Dep -Name "url_launcher"       -Version "^6.2.6" -PubText $pub2

if ($pub2 -ne $pub) {
  $bakP = "$pubspec.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $pubspec $bakP -Force
  Set-Content -Path $pubspec -Value $pub2 -Encoding UTF8
  Write-Host "[OK] Patched pubspec.yaml. Backup: $bakP" -ForegroundColor Green
} else {
  Write-Host "[OK] pubspec.yaml deps already ok" -ForegroundColor Green
}

# -------------------------
# 2) Patch Dart
# -------------------------
$raw = Get-Content $dartFile -Raw
$raw = Add-ImportsIfMissing -Text $raw

# Inject helper methods into _ExerciseEditorDialogState (only once)
if ($raw -notmatch "_pickAndAddImages\(") {
$inject = @"
  Future<Directory> _ensureMediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('\${base.path}\\SimonPhysio\\media\\exercises');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _pickAndAddImages() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (picked == null || picked.files.isEmpty) return;

    final dir = await _ensureMediaDir();

    final existing = _images.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final f in picked.files) {
      final srcPath = f.path;
      if (srcPath == null || srcPath.trim().isEmpty) continue;

      final src = File(srcPath);
      if (!await src.exists()) continue;

      final safeName = 'ex_\${DateTime.now().millisecondsSinceEpoch}_\${f.name.replaceAll(' ', '_')}';
      final dest = File('\${dir.path}\\\${safeName}');

      try {
        await src.copy(dest.path);
        existing.add(dest.path.replaceAll('\\\\', '/'));
      } catch (_) { }
    }

    _images.text = existing.join('\n');
    if (mounted) setState(() {});
  }

"@

  $rx = New-Object System.Text.RegularExpressions.Regex(
    "(?s)(class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog>\s*\{.*?)(@override\s+Widget build\(BuildContext context\)\s*\{)"
  )

  $raw = $rx.Replace($raw, {
    param($m)
    return $m.Groups[1].Value + "`r`n" + $inject + "`r`n" + $m.Groups[2].Value
  }, 1)
}

# Add "Add images" button above images TextField (only once)
if ($raw -notmatch "OutlinedButton\.icon\(\s*`r?`n\s*onPressed:\s*_pickAndAddImages") {
  $rxBtn = New-Object System.Text.RegularExpressions.Regex(
    "(?s)(TextField\(\s*controller:\s*_video,.*?\);\s*const SizedBox\(height:\s*12\),\s*)(TextField\(\s*controller:\s*_images,)"
  )

  $raw = $rxBtn.Replace($raw, {
    param($m)
    $insert = @"
Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: _pickAndAddImages,
                       icon: const Icon(Icons.add_photo_alternate_outlined),
                       label: const Text('Add images'),
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 12),

"@
    return $m.Groups[1].Value + $insert + $m.Groups[2].Value
  }, 1)
}

# Replace detail Images section to render thumbnails (best-effort)
if ($raw -match "Images \(links/paths\)") {
  $rxImg = New-Object System.Text.RegularExpressions.Regex(
    "(?s)if\s*\(item\.imageLinks\.isNotEmpty\)\s*\.\.\.\[\s*sectionTitle\('Images \(links/paths\)'\),.*?\],"
  )

  $replacement = @"
            if (item.imageLinks.isNotEmpty) ...[
              sectionTitle('Images'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: item.imageLinks.map((p) {
                  final isHttp = p.trim().toLowerCase().startsWith('http');
                  if (isHttp) {
                    return SizedBox(
                      width: 180,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: const [
                              Icon(Icons.link),
                              SizedBox(width: 8),
                              Expanded(child: Text('Link', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final file = File(p);
                  if (!file.existsSync()) {
                    return SizedBox(
                      width: 180,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: const [
                              Icon(Icons.broken_image_outlined),
                              SizedBox(width: 8),
                              Expanded(child: Text('Missing file', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 220,
                      height: 140,
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ],
"@

  $raw = $rxImg.Replace($raw, $replacement, 1)
}

Set-Content -Path $dartFile -Value $raw -Encoding UTF8
Write-Host "[OK] Patched Dart for local images + thumbnails" -ForegroundColor Green

# -------------------------
# 3) Build + Run (MUST be in project root)
# -------------------------
Push-Location $root
try {
  Write-Host "==> flutter clean" -ForegroundColor Cyan
  & $flutter clean | Out-Null

  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  & $flutter pub get | Out-Host

  Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
  & $flutter build windows --release | Out-Host

  if (!(Test-Path $exe)) { throw "EXE not found after build: $exe" }

  Write-Host "[OK] BUILD SUCCESS" -ForegroundColor Green
  Write-Host "EXE: $exe" -ForegroundColor Green
}
finally {
  Pop-Location
}

Write-Host "==> Launching app..." -ForegroundColor Cyan
Start-Process $exe
