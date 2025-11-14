// lib/services/auth_service.dart
// AuthService: singleton wrapper around Dio + secure storage for auth.
// - Call `await AuthService().init()` from main() before runApp() if you want token preloaded.
// - Default base URL is set to 127.0.0.1 which works with adb reverse. Change to your LAN IP
//   (e.g. http://192.168.x.y:5000) when testing over Wi-Fi.
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

class AuthService {
  // ---------------- SINGLETON ----------------
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Keep constructor light. Call init() from main() if you need token preloaded.
    _setupDio();
  }

  // ---------------- CONFIG ----------------
  static const String _defaultBaseUrl = AppConfig.baseUrl;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Dio dio = Dio(BaseOptions(
    baseUrl: _defaultBaseUrl,
    connectTimeout: const Duration(seconds: 20), // increased to avoid spurious timeouts
    receiveTimeout: const Duration(seconds: 20),
    contentType: 'application/json',
    responseType: ResponseType.json,
  ));

  // ---------------- STORAGE KEYS ----------------
  static const String _keyToken = 'jb_token';
  static const String _keyUser = 'jb_user';

  // ---------------- IN-MEMORY CACHE ----------------
  String? _cachedToken;

  // ---------------- PUBLIC INIT ----------------
  /// Call once at app startup (await this in main()) so token is loaded.
  Future<void> init() async {
    await _initFromStorage();
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $_cachedToken';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  Future<void> _initFromStorage() async {
    try {
      _cachedToken = await _secureStorage.read(key: _keyToken);
      if (_cachedToken != null && _cachedToken!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $_cachedToken';
      }
    } catch (e) {
      if (kDebugMode) print('AuthService initFromStorage error: $e');
    }
  }

  void _setupDio() {
    dio.interceptors.clear();

    // Helpful request/response logger in debug mode (DO NOT enable in production)
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
          // 'compact' removed in newer dio versions; control print with logPrint if desired.
          // logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        // if unauthorized, clear credentials to force re-login
        if (err.response?.statusCode == 401) {
          try {
            await logout();
          } catch (_) {}
        }
        handler.next(err);
      },
    ));
  }

  // ---------------- AUTH METHODS ----------------

  /// 🔐 Login with email & password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (resp.statusCode == 200 && resp.data != null) {
        final token = resp.data['token'] as String?;
        final user = resp.data['user'];

        if (token == null || user == null) {
          throw Exception('Invalid login response format');
        }

        // Save both in secure storage
        await _secureStorage.write(key: _keyToken, value: token);
        await _secureStorage.write(key: _keyUser, value: jsonEncode(user));

        // Update in-memory cache & dio header
        _cachedToken = token;
        dio.options.headers['Authorization'] = 'Bearer $token';

        return Map<String, dynamic>.from(user as Map);
      } else {
        throw Exception('Login failed (${resp.statusCode})');
      }
    } on DioException catch (e) {
      final backendMsg = (e.response?.data is Map)
          ? e.response?.data['error']?.toString()
          : null;
      throw Exception(backendMsg ?? 'Login request failed');
    }
  }

  /// 👤 Validate token and fetch user data (/api/me)
  Future<Map<String, dynamic>> me() async {
    try {
      final resp = await dio.get('/api/me');
      if (resp.statusCode == 200 && resp.data != null) {
        return Map<String, dynamic>.from(resp.data as Map);
      } else {
        throw Exception('Failed to fetch user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await logout();
      rethrow;
    }
  }

  /// 🧑‍🔧 Create new technician (Admin-only)
  Future<Map<String, dynamic>> createTechnician({
    required String name,
    required String email,
    required String password,
    String? phone,
    String role = 'technician',
  }) async {
    try {
      final resp = await dio.post('/api/technicians', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      });

      if (resp.statusCode == 201 && resp.data != null) {
        return Map<String, dynamic>.from(resp.data['technician'] as Map);
      } else {
        throw Exception('Failed to create technician');
      }
    } on DioException catch (e) {
      final backendMsg = (e.response?.data is Map)
          ? e.response?.data['error']?.toString()
          : null;
      throw Exception(backendMsg ?? 'Technician creation failed');
    }
  }

  /// 🚪 Logout and clear all stored credentials
  Future<void> logout() async {
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyUser);
    _cachedToken = null;
    dio.options.headers.remove('Authorization');
  }

  // ---------------- STORAGE HELPERS ----------------

  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    _cachedToken = await _secureStorage.read(key: _keyToken);
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $_cachedToken';
    }
    return _cachedToken;
  }

  Future<Map<String, dynamic>?> getStoredUser() async {
    final data = await _secureStorage.read(key: _keyUser);
    if (data == null) return null;
    return Map<String, dynamic>.from(jsonDecode(data) as Map);
  }

  // ---------------- GENERIC REQUEST HELPERS ----------------

  Future<dynamic> getWithAuth(String path, [String? token]) async {
    final resolved = _resolvePath(path);
    try {
      final res = await dio.get(resolved, options: _opt(token));
      return res.data;
    } on DioException catch (e) {
      throw Exception(e.message ?? 'GET failed');
    }
  }

  Future<dynamic> postWithAuth(String path, dynamic body, [String? token]) async {
    final resolved = _resolvePath(path);
    try {
      final res = await dio.post(resolved, data: body, options: _opt(token));
      return res.data;
    } on DioException catch (e) {
      throw Exception(e.message ?? 'POST failed');
    }
  }

  Future<dynamic> deleteWithAuth(String path, [String? token]) async {
    final resolved = _resolvePath(path);
    try {
      final res = await dio.delete(resolved, options: _opt(token));
      return res.data;
    } on DioException catch (e) {
      throw Exception(e.message ?? 'DELETE failed');
    }
  }

  // ---------------- INTERNAL UTILS ----------------

  Options _opt(String? token) {
    if (token == null || token.isEmpty) return Options();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String _resolvePath(String path) {
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('/api/')) return p;
    if (p.startsWith('/')) return '/api$p'.replaceFirst('//', '/');
    return '/api/$p';
  }
}
