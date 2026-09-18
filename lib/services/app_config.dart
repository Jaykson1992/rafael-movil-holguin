class AppConfig {
  /// URL del servidor que se inyecta al compilar, sin guardar secretos en el APK.
  /// Ejemplo: --dart-define=RAFAEL_API_URL=https://api.rafaelmovil.com
  static const apiUrl = String.fromEnvironment(
    'RAFAEL_API_URL',
    defaultValue: '',
  );

  static bool get hasProductionServer {
    final value = apiUrl.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }
}
