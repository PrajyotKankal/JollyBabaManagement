// lib/config.dart
class AppConfig {
  // Configurable at build time: pass --dart-define=API_BASE_URL=... when building/running
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jollybabamanagement-production.up.railway.app',
  );
  
  static const String adminTokenKey = 'admin_token';
  static const String tokenKey = 'token';

  // Google OAuth client IDs
  static const String googleAndroidClientId =
      '1082161785386-ubjf5ip999vs5jvd4pkfvk3rfic5ks2s.apps.googleusercontent.com';
  static const String googleWebClientId =
      '1082161785386-s93uqmt80sdkc7s0nijtiuu4or0fqbuj.apps.googleusercontent.com';
}
