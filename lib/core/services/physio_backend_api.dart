import 'dart:convert';
import 'package:dio/dio.dart';

class PhysioBackendApi {
  PhysioBackendApi({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? 'http://localhost:3001',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 10),
              headers: const {'Accept': 'application/json'},
              validateStatus: (code) => code != null && code >= 100 && code < 600,
            ));

  final Dio _dio;

  Future<Response<dynamic>> health() => _dio.get('/api/health');

  Future<Response<dynamic>> createSession(String id) =>
      _dio.post('/api/sessions', data: {'id': id});

  Future<Response<dynamic>> getSession(String id) => _dio.get('/api/sessions/$id');

  static String format(Response r) {
    final sb = StringBuffer();
    sb.writeln('HTTP ${r.statusCode}');
    final xav = r.headers.value('x-api-version');
    if (xav != null) sb.writeln('x-api-version: $xav');
    sb.writeln('--- body ---');
    final d = r.data;
    if (d is String) {
      sb.writeln(d);
    } else {
      try {
        sb.writeln(const JsonEncoder.withIndent('  ').convert(d));
      } catch (_) {
        sb.writeln(d.toString());
      }
    }
    return sb.toString();
  }
}
