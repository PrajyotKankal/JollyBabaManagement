// lib/screens/create_ticket_mobile.dart
// Mobile-specific upload helper
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/ticket_service.dart';

Future<Map<String, dynamic>?> uploadImageMobile(XFile xFile) async {
  final file = File(xFile.path);
  if (!file.existsSync()) {
    throw Exception('File not found');
  }
  return await TicketService.uploadFile(file);
}

// Export for web as stub (won't be called)
Future<Map<String, dynamic>?> uploadImageWeb(XFile xFile) async {
  throw UnimplementedError('Web upload not available on mobile');
}
