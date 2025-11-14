// lib/services/khatabook_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class KhatabookService {
  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: q);

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService().getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<List<Map<String, dynamic>>> listEntries() async {
    final response = await http.get(_u('/api/khatabook'), headers: await _headers());
    if (response.statusCode != 200) {
      throw Exception('Failed to load entries: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (data['entries'] as List? ?? [])
        .cast<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    return entries;
  }

  static Future<Map<String, dynamic>> createEntry(Map<String, dynamic> payload) async {
    final response = await http.post(
      _u('/api/khatabook'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create entry: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['entry'] as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateEntry(int id, Map<String, dynamic> payload) async {
    final response = await http.patch(
      _u('/api/khatabook/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update entry: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['entry'] as Map).cast<String, dynamic>();
  }

  static Future<void> deleteEntry(int id) async {
    final response = await http.delete(
      _u('/api/khatabook/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete entry: ${response.statusCode} ${response.body}');
    }
  }

  static Uri exportExcelUrl() => _u('/api/khatabook/export');
}
