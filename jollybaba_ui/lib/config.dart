// lib/config.dart
class AppConfig {
  // Configurable at build time: pass --dart-define=API_BASE_URL=... when building/running
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jollybabamanagement-production.up.railway.app',
  );
  
  static const String adminTokenKey = 'admin_token';
  static const String tokenKey = 'token';
}
