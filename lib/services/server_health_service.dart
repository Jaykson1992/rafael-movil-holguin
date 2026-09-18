import 'dart:convert';
import 'dart:io';
import 'app_config.dart';

class ServerHealthService {
  Future<bool> isReady() async {
    if (!AppConfig.hasProductionServer) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final base = AppConfig.apiUrl.replaceAll(RegExp(r'/$'), '');
      final request = await client.getUrl(Uri.parse('$base/ready'));
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(body);
      return data is Map && data['ready'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
