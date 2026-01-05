library api_client;

import 'dart:io';

class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  Uri _u(String path) => Uri.parse(baseUrl + path);

  Future<bool> health() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(_u('/api/health'));
      final res = await req.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> healthCheck() => health();
}