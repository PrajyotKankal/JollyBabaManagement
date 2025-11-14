// lib/models/ticket.model.dart
import 'package:intl/intl.dart';

class Ticket {
  final int id;
  final String customerName;
  final String deviceModel;
  final String mobileNumber;
  final String status;
  final DateTime? receiveDate;
  final DateTime? deliveryDate;

  const Ticket({
    required this.id,
    required this.customerName,
    required this.deviceModel,
    required this.mobileNumber,
    required this.status,
    this.receiveDate,
    this.deliveryDate,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || (value is String && value.isEmpty)) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return Ticket(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerName: json['customer_name']?.toString() ?? '',
      deviceModel: json['device_model']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      receiveDate: parseDate(json['receive_date']),
      deliveryDate: parseDate(json['delivery_date']),
    );
  }

  /// Convenience: formatted dates for UI
  String get formattedReceiveDate => _formatDate(receiveDate);
  String get formattedDeliveryDate => _formatDate(deliveryDate);

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    return DateFormat('dd MMM yyyy').format(local);
  }
}
