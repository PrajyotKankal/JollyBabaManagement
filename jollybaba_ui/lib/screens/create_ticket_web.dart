// lib/screens/create_ticket_web.dart
// Web-specific upload helper
import 'package:image_picker/image_picker.dart';
import '../services/ticket_service.dart';

Future<Map<String, dynamic>?> uploadImageWeb(XFile xFile) async {
  return await TicketService.uploadFileFromXFile(xFile);
}

// Export for mobile as stub (won't be called)
Future<Map<String, dynamic>?> uploadImageMobile(XFile xFile) async {
  throw UnimplementedError('Mobile upload not available on web');
}
