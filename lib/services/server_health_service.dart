import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ServerHealth {
  const ServerHealth({required this.online, required this.message, this.latencyMs});
  final bool online;
  final String message;
  final int? latencyMs;
}

class ServerHealthService {
  const ServerHealthService(this.baseUrl);
  final String baseUrl;

  Future<ServerHealth> check() async {
    if (baseUrl.trim().isEmpty) {
      return const ServerHealth(online: false, message: 'Modo demostración: servidor no configurado');
    }
    final uri = Uri.tryParse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/health');
    if (uri == null) return const ServerHealth(online: false, message: 'Dirección del servidor inválida');
    final sw = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decoder.bind(res).join();
      sw.stop();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ServerHealth(online: true, message: body.isEmpty ? 'Servidor disponible' : 'Servidor disponible', latencyMs: sw.elapsedMilliseconds);
      }
      return ServerHealth(online: false, message: 'Servidor respondió ${res.statusCode}');
    } on TimeoutException {
      return const ServerHealth(online: false, message: 'Servidor sin respuesta');
    } on SocketException {
      return const ServerHealth(online: false, message: 'Sin conexión con el servidor');
    } catch (_) {
      return const ServerHealth(online: false, message: 'No se pudo comprobar el servidor');
    } finally {
      client.close(force: true);
    }
  }
}
