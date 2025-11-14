// lib/services/ticket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config.dart';
import 'auth_service.dart';

/// Safely decodes JSON on a background thread.
/// Supports both list responses and wrapped objects like { success, data } or { tickets }.
List<dynamic> _decodeJsonList(String body) {
  try {
    final decoded = json.decode(body);

    if (decoded is List<dynamic>) return decoded;

    if (decoded is Map) {
      if (decoded['data'] is List) return List<dynamic>.from(decoded['data']);
      if (decoded['tickets'] is List) return List<dynamic>.from(decoded['tickets']);
    }
  } catch (e) {
    debugPrint('❌ JSON decode error: $e');
  }
  return <dynamic>[];
}

class TicketService {
  static const Duration _timeout = Duration(seconds: 20);

  static const Map<String, String> _baseJsonHeaders = {
    "Content-Type": "application/json",
  };

  static Future<Map<String, String>> _buildHeaders({
    bool jsonContent = true,
  }) async {
    final token = await AuthService().getToken();
    final headers = <String, String>{};
    if (jsonContent) headers.addAll(_baseJsonHeaders);
    if (token?.isNotEmpty == true) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // ---------------------------------------------------------------------------
  // ✅ Upload repaired photo (server handles compression + Cloudinary)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> uploadRepairedPhoto(
    int ticketId,
    File file, {
    List<Map<String, dynamic>>? notes,
  }) async {
    if (!file.existsSync()) {
      debugPrint('❌ uploadRepairedPhoto: file not found at ${file.path}');
      return null;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/api/tickets/$ticketId/repaired-photo');

    try {
      final headers = await _buildHeaders(jsonContent: false);
      final prepared = await _prepareFileForUpload(file);

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      if (notes != null) {
        try {
          request.fields['notes'] = jsonEncode(notes);
        } catch (e) {
          debugPrint('⚠️ uploadRepairedPhoto notes encode failed: $e');
        }
      }

      final mimeType = _inferMimeType(prepared.path);
      request.files.add(await http.MultipartFile.fromPath(
        'repaired_photo',
        prepared.path,
        contentType: mimeType,
      ));

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('❌ uploadRepairedPhoto failed: ${response.statusCode} -> ${response.body}');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('❌ uploadRepairedPhoto timeout: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ uploadRepairedPhoto network error: $e');
      return null;
    } catch (e, st) {
      debugPrint('❌ uploadRepairedPhoto unexpected: $e\n$st');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _requestCloudinarySignature() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/cloudinary/sign');
    final headers = await _buildHeaders();
    try {
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['signature'] != null && body['timestamp'] != null) {
          return {
            'signature': body['signature'].toString(),
            'timestamp': body['timestamp'].toString(),
            'apiKey': (body['api_key'] ?? body['apiKey'] ?? '').toString(),
            'cloudName': (body['cloud_name'] ?? body['cloudName'] ?? '').toString(),
            'folder': (body['folder'] ?? '').toString(),
            'publicId': (body['public_id'] ?? '').toString(),
          };
        }
        debugPrint('⚠️ Invalid signature payload: ${response.body}');
        return null;
      }
      debugPrint('❌ Signature request failed: ${response.statusCode}');
      return null;
    } catch (e, st) {
      debugPrint('❌ Signature request error: $e\n$st');
      return null;
    }
  }

  static Future<File> _prepareFileForUpload(File file) async {
    try {
      final bytes = await file.length();
      final bool largeFile = bytes > 600 * 1024; // >600 KB

      if (!largeFile) return file;

      final tempDir = Directory.systemTemp;
      final targetPath =
          '${tempDir.path}/jb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.jpeg,
        quality: 80,
        minWidth: 1280,
        minHeight: 1280,
      );

      if (compressed != null) {
        final compressedFile = File(compressed.path);
        final compressedSize = await compressedFile.length();
        if (compressedSize < bytes) {
          return compressedFile;
        }
      }
    } catch (e, st) {
      debugPrint('⚠️ _prepareFileForUpload error: $e\n$st');
    }
    return file;
  }

  static MediaType? _inferMimeType(String filePath) {
    final parts = filePath.split('.');
    if (parts.length < 2) return null;
    final ext = parts.last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ Upload file (device_photo)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> uploadFile(File file) async {
    final signature = await _requestCloudinarySignature();
    if (signature == null) return null;
    final cloudName = signature['cloudName'];
    final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    if (!file.existsSync()) {
      debugPrint('❌ uploadFile: file not found at ${file.path}');
      return null;
    }

    try {
      final fileToUpload = await _prepareFileForUpload(file);

      final request = http.MultipartRequest('POST', uploadUrl)
        ..fields['timestamp'] = signature['timestamp']
        ..fields['signature'] = signature['signature']
        ..fields['api_key'] = signature['apiKey'];

      final folder = signature['folder'];
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      final publicId = signature['publicId'];
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }

      final mimeType = _inferMimeType(fileToUpload.path);
      final multipart = await http.MultipartFile.fromPath(
        'file',
        fileToUpload.path,
        contentType: mimeType,
      );
      request.files.add(multipart);

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = json.decode(response.body);

        if (body is Map && body['secure_url'] != null) {
          return {
            'url': body['secure_url'].toString(),
            'filename': body['public_id']?.toString(),
            'mimetype': body['format']?.toString(),
          };
        }

        debugPrint('⚠️ uploadFile: no secure_url found in Cloudinary response');
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized (401) while uploading file');
      } else {
        debugPrint('❌ uploadFile failed: ${response.statusCode}');
        return null;
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ uploadFile timeout: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ uploadFile network error: $e');
      return null;
    } catch (e, st) {
      debugPrint('❌ uploadFile unexpected: $e\n$st');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ Fetch tickets (supports both [] and {success,data} formats)
  // ---------------------------------------------------------------------------
  static Future<List<dynamic>> fetchTickets({int page = 1, int perPage = 500}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/tickets').replace(queryParameters: {
      'page': page.toString(),
      'perPage': perPage.toString(),
    });
    final headers = await _buildHeaders();

    try {
      final resp = await http.get(uri, headers: headers).timeout(_timeout);

      if (resp.statusCode == 200) {
        final List<dynamic> data = await compute(_decodeJsonList, resp.body);

        final normalized = data.map((t) {
          try {
            final Map<String, dynamic> ticket = Map<String, dynamic>.from(t);
            final rawStatus = (ticket['status'] ?? '').toString();
            final norm = rawStatus.trim().toLowerCase();
            ticket['status_normalized'] =
                norm.isEmpty ? 'pending' : norm;
            ticket['status_title'] = rawStatus.trim().isEmpty
                ? '-'
                : _toTitleCase(rawStatus.trim());
            return ticket;
          } catch (_) {
            return t;
          }
        }).toList();

        debugPrint("✅ Tickets fetched: ${normalized.length}");
        return normalized;
      } else if (resp.statusCode == 401) {
        throw Exception('Unauthorized (401)');
      } else {
        throw Exception('Failed to fetch tickets (${resp.statusCode})');
      }
    } catch (e, st) {
      debugPrint('❌ fetchTickets error: $e\n$st');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ Update ticket (PATCH)
  // ---------------------------------------------------------------------------
  static Future<bool> updateTicket(
      int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/tickets/$id');
    final body = Map<String, dynamic>.from(payload);

    try {
      // Automatically upload local files in payload
      for (final key in List<String>.from(body.keys)) {
        final val = body[key];
        if (val is String && val.isNotEmpty && File(val).existsSync()) {
          final uploaded = await uploadFile(File(val));
          if (uploaded != null && uploaded['url'] != null) {
            body[key] = uploaded['url'];
          } else {
            debugPrint('❌ Failed to upload local file for $key');
            return false;
          }
        }
      }

      final headers = await _buildHeaders();
      final response = await http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("✅ Ticket #$id updated successfully");
        return true;
      }
      debugPrint("❌ updateTicket failed: ${response.statusCode}");
      return false;
    } catch (e, st) {
      debugPrint('❌ updateTicket error: $e\n$st');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ Create ticket (JSON or multipart)
  // ---------------------------------------------------------------------------
  static Future<bool> createTicket(Map<String, dynamic> ticket) async {
    final devicePhotoPath =
        (ticket['device_photo_path'] ?? ticket['device_photo'])?.toString();
    final hasPhoto =
        devicePhotoPath != null && File(devicePhotoPath).existsSync();

    try {
      http.Response response;

      if (hasPhoto) {
        final uri = Uri.parse('${AppConfig.baseUrl}/api/tickets');
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(await _buildHeaders(jsonContent: false));

        // Add fields except photo path/nulls
        ticket.forEach((key, value) {
          if (key == 'device_photo' ||
              key == 'device_photo_path' ||
              value == null) return;
          request.fields[key] = value.toString();
        });

        request.files.add(
          await http.MultipartFile.fromPath('device_photo', devicePhotoPath),
        );

        final streamed = await request.send().timeout(_timeout);
        response = await http.Response.fromStream(streamed);
      } else {
        final headers = await _buildHeaders();
        response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/api/tickets'),
              headers: headers,
              body: jsonEncode(ticket),
            )
            .timeout(_timeout);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Ticket created successfully");
        return true;
      } else {
        debugPrint("❌ Failed to create ticket: ${response.statusCode}");
        debugPrint("Body: ${response.body}");
        return false;
      }
    } catch (e, st) {
      debugPrint('❌ createTicket error: $e\n$st');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------
  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'[\s_-]+'));
    return parts
        .map((p) =>
            p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }
}
