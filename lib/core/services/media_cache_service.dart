import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Hybrid media cache:
/// - Bundled assets live under assets/...
/// - Remote media can be downloaded, verified, and cached on-device.
/// This service only handles remote caching; UI can decide whether to use bundled vs remote.
class MediaCacheService {
  MediaCacheService._();
  static final MediaCacheService I = MediaCacheService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 20),
    followRedirects: true,
  ));

  Directory? _cacheDir;
  File? _indexFile;
  Map<String, dynamic> _index = <String, dynamic>{};

  Future<void> init() async {
    if (_cacheDir != null) return;

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'media_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;

    _indexFile = File(p.join(dir.path, 'index.json'));
    if (await _indexFile!.exists()) {
      try {
        final raw = await _indexFile!.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) _index = decoded;
      } catch (_) {
        _index = <String, dynamic>{};
      }
    } else {
      _index = <String, dynamic>{};
      await _flushIndex();
    }
  }

  /// Returns a cached local file path if present.
  /// Otherwise downloads (if allowed) and returns the local path.
  Future<String?> getOrFetch({
    required String id,
    required String url,
    String? sha256Hex,
    bool allowDownload = true,
    String? fileNameHint,
  }) async {
    await init();
    final dir = _cacheDir!;
    final entry = _index[id];

    if (entry is Map<String, dynamic>) {
      final path = entry['path'];
      if (path is String) {
        final f = File(path);
        if (await f.exists()) return f.path;
      }
    }

    if (!allowDownload) return null;

    final safeName = _safeFileName(fileNameHint ?? id);
    final outPath = p.join(dir.path, safeName);
    final outFile = File(outPath);

    // Download to temp then move (safer).
    final tmpPath = outPath + ".tmp";
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      try { await tmpFile.delete(); } catch (_) {}
    }

    final resp = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );

    final sink = tmpFile.openWrite();
    try {
      await resp.data!.stream.pipe(sink);
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (sha256Hex != null && sha256Hex.trim().isNotEmpty) {
      final ok = await _verifySha256(tmpFile, sha256Hex.trim().toLowerCase());
      if (!ok) {
        try { await tmpFile.delete(); } catch (_) {}
        throw StateError('Media SHA256 mismatch for $id');
      }
    }

    if (await outFile.exists()) {
      try { await outFile.delete(); } catch (_) {}
    }
    await tmpFile.rename(outFile.path);

    _index[id] = <String, dynamic>{
      'id': id,
      'url': url,
      'path': outFile.path,
      'sha256': sha256Hex,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _flushIndex();

    return outFile.path;
  }

  Future<void> clearAll() async {
    await init();
    final dir = _cacheDir!;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _cacheDir = null;
    _indexFile = null;
    _index = <String, dynamic>{};
    await init();
  }

  Future<void> _flushIndex() async {
    final f = _indexFile!;
    final raw = const JsonEncoder.withIndent('  ').convert(_index);
    await f.writeAsString(raw);
  }

  String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'media.bin' : cleaned;
  }

  Future<bool> _verifySha256(File file, String expectedHexLower) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    return digest.toLowerCase() == expectedHexLower;
  }
}
