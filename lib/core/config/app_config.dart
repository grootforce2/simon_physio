library app_config;

import 'dart:convert';
import 'dart:io';

class AppConfig {
  static const String defaultBaseUrl = 'http://simon-physio.local:3001';
  static const String optionHostnameStandard = 'http://physio-server:3001';

  final String serverBaseUrl;
  const AppConfig({required this.serverBaseUrl});

  static String normalize(String s) {
    var v = s.trim();
    if (v.isEmpty) return defaultBaseUrl;
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://';
    }
    return v;
  }

  static Future<File> _exeConfigFile() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      return File('config.json');
    } catch (_) {
      return File('config.json');
    }
  }

  static Future<File> _appDataConfigFile() async {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    final dir = Directory('simon_physio');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('config.json');
  }

  static Future<AppConfig> load() async {
    try {
      final f = await _exeConfigFile();
      if (f.existsSync()) {
        final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        return AppConfig(serverBaseUrl: normalize((m['serverBaseUrl'] ?? '').toString()));
      }
    } catch (_) {}

    try {
      final f = await _appDataConfigFile();
      if (f.existsSync()) {
        final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        return AppConfig(serverBaseUrl: normalize((m['serverBaseUrl'] ?? '').toString()));
      }
    } catch (_) {}

    return const AppConfig(serverBaseUrl: defaultBaseUrl);
  }

  static Future<void> save(String baseUrl, {bool besideExe = true}) async {
    final v = normalize(baseUrl);
    final payload = const JsonEncoder.withIndent('  ').convert({'serverBaseUrl': v});

    try {
      final a = await _appDataConfigFile();
      a.writeAsStringSync(payload, flush: true);
    } catch (_) {}

    if (besideExe) {
      try {
        final e = await _exeConfigFile();
        e.writeAsStringSync(payload, flush: true);
      } catch (_) {}
    }
  }
}