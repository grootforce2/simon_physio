library enterprise_log;

import 'dart:io';

class EnterpriseLog {
  static Future<File> _logFile() async {
    final dir = Directory('.gf_logs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('APP_LAST.log');
  }

  static Future<void> write(String msg) async {
    try {
      final f = await _logFile();
      final ts = DateTime.now().toIso8601String();
      f.writeAsStringSync('[] \n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}