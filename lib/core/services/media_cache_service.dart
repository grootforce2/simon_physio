import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class MediaCacheService {
  final Dio _dio;
  MediaCacheService(this._dio);

  Future<Directory> _cacheDir() async {
    final dir = await getApplicationSupportDirectory();
    final cache = Directory('\/media_cache');
    if (!await cache.exists()) await cache.create(recursive: true);
    return cache;
  }

  String _safeFileName(String url) {
    final hash = sha256.convert(url.codeUnits).toString();
    final ext = url.toLowerCase().contains('.mp4') ? 'mp4' : 'bin';
    return '\.\';
  }

  Future<File?> getCachedIfExists(String url) async {
    final cache = await _cacheDir();
    final f = File('\/\');
    return await f.exists() ? f : null;
  }

  Future<File> downloadAndCache(String url, {void Function(int, int)? onProgress}) async {
    final cache = await _cacheDir();
    final file = File('\/\');
    if (await file.exists()) return file;

    await _dio.download(
      url,
      file.path,
      onReceiveProgress: (r, t) => onProgress?.call(r, t),
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 1),
      ),
    );
    return file;
  }

  Future<void> clear() async {
    final cache = await _cacheDir();
    if (await cache.exists()) await cache.delete(recursive: true);
  }
}
