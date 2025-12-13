// lib/services/inventory_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class InventoryService {
  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: q);

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService().getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  // Update inventory item fields with fallbacks (PATCH -> PUT -> POST /update)
  static Future<Map<String, dynamic>> updateItem(int srNo, Map<String, dynamic> fields) async {
    final headers = await _headers();
    final patchUrl = _u('/api/inventory/$srNo');
    // ignore: avoid_print
    print('[InventoryService.updateItem] baseUrl=${AppConfig.baseUrl} srNo=$srNo keys=${fields.keys.toList()}');
    var r = await http.patch(patchUrl, headers: headers, body: jsonEncode(fields));
    // ignore: avoid_print
    print('[InventoryService.updateItem] PATCH ${r.statusCode}');
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404 || r.statusCode == 405 || r.statusCode == 501) {
      final putUrl = _u('/api/inventory/$srNo');
      r = await http.put(putUrl, headers: headers, body: jsonEncode(fields));
      // ignore: avoid_print
      print('[InventoryService.updateItem] PUT ${r.statusCode}');
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      final postUrl = _u('/api/inventory/$srNo/update');
      r = await http.post(postUrl, headers: headers, body: jsonEncode(fields));
      // ignore: avoid_print
      print('[InventoryService.updateItem] POST /update ${r.statusCode}');
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('Update item failed: ${r.statusCode} ${r.body}');
  }

  // Create AVAILABLE item
  static Future<Map<String, dynamic>> createItem(Map<String, dynamic> payload) async {
    final r = await http.post(_u('/api/inventory'), headers: await _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Create failed: ${r.statusCode} ${r.body}');
  }

  // Create many AVAILABLE items in a single batch
  static Future<Map<String, dynamic>> createItemsMultiple(Map<String, dynamic> payload) async {
    final r = await http.post(_u('/api/inventory/add-multiple'), headers: await _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Create-multiple failed: ${r.statusCode} ${r.body}');
  }

  // List items with filters
  static Future<Map<String, dynamic>> listItems({String? q, String? status, String? vendor, String? brand, String? from, String? to, String sort = 'date', String order = 'desc'}) async {
    final r = await http.get(_u('/api/inventory', {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
      if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'sort': sort,
      'order': order,
    }), headers: await _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('List failed: ${r.statusCode} ${r.body}');
  }

  // Mark as SOLD
  static Future<Map<String, dynamic>> sellItem(int srNo, Map<String, dynamic> payload) async {
    final r = await http.post(_u('/api/inventory/$srNo/sell'), headers: await _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Sell failed: ${r.statusCode} ${r.body}');
  }

  // Mark multiple items as SOLD in a single sale
  static Future<Map<String, dynamic>> sellMultiple(List<int> srNos, Map<String, dynamic> payload) async {
    final body = <String, dynamic>{
      'srNos': srNos,
      ...payload,
    };
    final r = await http.post(
      _u('/api/inventory/sell-multiple'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Multi-sell failed: ${r.statusCode} ${r.body}');
  }

  // Cancel sale and mark as AVAILABLE again
  static Future<Map<String, dynamic>> makeAvailable(int srNo) async {
    final r = await http.post(_u('/api/inventory/$srNo/make-available'), headers: await _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Make available failed: ${r.statusCode} ${r.body}');
  }

  // Update remarks (allowed for SOLD as well)
  static Future<Map<String, dynamic>> updateRemarks(int srNo, String remarks) async {
    final r = await http.patch(_u('/api/inventory/$srNo/remarks'), headers: await _headers(), body: jsonEncode({"remarks": remarks}));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('Update failed: ${r.statusCode} ${r.body}');
  }

  // CSV export URL for current filters
  static Uri exportCsvUrl({String? q, String? status, String? vendor, String? brand, String? from, String? to, String sort = 'date', String order = 'desc'}) {
    return _u('/api/inventory/export.csv', {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
      if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'sort': sort,
      'order': order,
    });
  }

  static Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }
    final headers = await _headers();
    final uri = _u('/api/customers/search', {'q': trimmed});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['customers'] as List<dynamic>?;
      return list?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? [];
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchVendors(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }
    final headers = await _headers();
    final response = await http.get(_u('/api/vendors/search', {'q': trimmed}), headers: headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['vendors'] as List<dynamic>?;
      return list?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? [];
    }
    return [];
  }
}
