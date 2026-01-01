# ==========================================================
# EXERCISES MEDIA SAFE V8
# - Marker-based injection (safe)
# - Adds local image + video pickers
# - Copies to Documents\SimonPhysio\media\exercises\{images|videos}
# ==========================================================
$ErrorActionPreference="Stop"

$root     = "C:\SIMON\simon_physio"
$flutter  = "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat"
$pubspec  = "$root\pubspec.yaml"
$dartFile = "$root\lib\premium\screens\exercises_screen.dart"
$exe      = "$root\build\windows\x64\runner\Release\simon_physio.exe"

if (!(Test-Path $flutter))  { throw "Flutter not found: $flutter" }
if (!(Test-Path $pubspec))  { throw "pubspec.yaml not found: $pubspec" }
if (!(Test-Path $dartFile)) { throw "Dart file not found: $dartFile" }

Copy-Item $dartFile "$dartFile.bak_$(Get-Date -Format yyyyMMdd_HHmmss)" -Force | Out-Null
Copy-Item $pubspec "$pubspec.bak_$(Get-Date -Format yyyyMMdd_HHmmss)" -Force | Out-Null

# ---- deps (add if missing)
$pub = Get-Content $pubspec -Raw
function AddDep([string]$name,[string]$ver,[string]$text){
  if ($text -match "(?m)^\s+$([regex]::Escape($name))\s*:") { return $text }
  return [regex]::Replace($text,"(?m)^dependencies:\s*$","dependencies:`r`n  ${name}: ${ver}",1)
}
$pub2=$pub
$pub2=AddDep "file_picker"   "^8.0.6" $pub2
$pub2=AddDep "path_provider" "^2.1.5" $pub2
$pub2=AddDep "url_launcher"  "^6.2.6" $pub2
if ($pub2 -ne $pub) { Set-Content $pubspec $pub2 -Encoding UTF8 }

# ---- dart patch
$raw = Get-Content $dartFile -Raw

# ensure imports
if ($raw -notmatch "(?m)^import\s+'dart:io';") {
  $raw = $raw -replace "(?m)^import\s+'package:flutter/material\.dart';\s*$", "import 'package:flutter/material.dart';`r`nimport 'dart:io';"
}
if ($raw -notmatch "package:file_picker/file_picker.dart") {
  $raw = $raw -replace "(?m)^import\s+'dart:io';\s*$", "import 'dart:io';`r`nimport 'package:file_picker/file_picker.dart';"
}
if ($raw -notmatch "package:path_provider/path_provider.dart") {
  $raw = $raw -replace "(?m)package:file_picker/file_picker\.dart';\s*$", "package:file_picker/file_picker.dart';`r`nimport 'package:path_provider/path_provider.dart';"
}
if ($raw -notmatch "package:url_launcher/url_launcher.dart") {
  $raw = $raw -replace "(?m)package:path_provider/path_provider\.dart';\s*$", "package:path_provider/path_provider.dart';`r`nimport 'package:url_launcher/url_launcher.dart';"
}

# inject methods once (markers)
if ($raw -notmatch "/// GF_MEDIA_V8_START") {
  $methods = @"
  /// GF_MEDIA_V8_START
  Future<Directory> _ensureMediaDir(String kind) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('\${base.path}\\\\SimonPhysio\\\\media\\\\exercises\\\\' + kind);
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

    final dir = await _ensureMediaDir('images');

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

      final safeName = "ex_\${DateTime.now().millisecondsSinceEpoch}_\${f.name.replaceAll(" ", "_")}";
      final dest = File('\${dir.path}\\\\' + safeName);

      try {
        await src.copy(dest.path);
        existing.add(dest.path.replaceAll('\\\\', '/'));
      } catch (_) {}
    }

    _images.text = existing.join('\n');
    if (mounted) setState(() {});
  }

  Future<void> _pickVideoLocal() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['mp4','mov','mkv','avi','webm'],
    );
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.first;
    final srcPath = f.path;
    if (srcPath == null || srcPath.trim().isEmpty) return;

    final src = File(srcPath);
    if (!await src.exists()) return;

    final dir = await _ensureMediaDir('videos');
    final safeName = "vid_\${DateTime.now().millisecondsSinceEpoch}_\${f.name.replaceAll(" ", "_")}";
    final dest = File('\${dir.path}\\\\' + safeName);

    try {
      await src.copy(dest.path);
      _video.text = dest.path.replaceAll('\\\\', '/');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _openPathExternal(String p) async {
    final path = p.trim();
    if (path.isEmpty) return;

    if (path.toLowerCase().startsWith('http')) {
      await launchUrl(Uri.parse(path), mode: LaunchMode.externalApplication);
      return;
    }

    final f = File(path);
    if (!f.existsSync()) return;
    await launchUrl(Uri.file(f.path), mode: LaunchMode.externalApplication);
  }
  /// GF_MEDIA_V8_END
"@

  $raw = [regex]::Replace(
    $raw,
    "(?s)(class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog>\s*\{.*?)(@override\s+Widget build\(BuildContext context\)\s*\{)",
    "`$1`r`n$methods`r`n`$2",
    1
  )
}

# add buttons only at a safe seam
if ($raw -notmatch "GF_BTN_PICK_VIDEO_V8") {
  $raw = [regex]::Replace(
    $raw,
    "(?s)(TextField\(\s*controller:\s*_video.*?\),\s*const SizedBox\(height:\s*12\),\s*)(TextField\(\s*controller:\s*_images)",
@"
`$1
              // GF_BTN_PICK_VIDEO_V8
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideoLocal,
                      icon: const Icon(Icons.video_file_outlined),
                      label: const Text('Pick video (local)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickAndAddImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add images (local)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              `$2
"@,
    1
  )
}

Set-Content -Path $dartFile -Value $raw -Encoding UTF8
Write-Host "[OK] V8 patch applied (safe markers)." -ForegroundColor Green

Push-Location $root
try {
  & $flutter clean | Out-Null
  & $flutter pub get | Out-Host
  & $flutter build windows --release | Out-Host
  if (!(Test-Path $exe)) { throw "Build finished but EXE not found: $exe" }
} finally { Pop-Location }

Start-Process $exe
$mediaRoot = Join-Path $env:USERPROFILE "Documents\SimonPhysio\media\exercises"
New-Item -ItemType Directory -Path $mediaRoot -Force | Out-Null
Start-Process $mediaRoot
Write-Host "[OK] Media folder: $mediaRoot" -ForegroundColor Green

