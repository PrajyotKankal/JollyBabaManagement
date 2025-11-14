// lib/screens/widgets/repair_details_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../ticket_details_controller.dart';

class RepairDetailsCard extends StatelessWidget {
  final TicketDetailsController controller;
  const RepairDetailsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ticket = controller.ticket ?? <String, dynamic>{};

    final assignedTech = controller.assignedTechnician.isNotEmpty
        ? controller.assignedTechnician
        : (ticket['assigned_technician'] ?? ticket['assigned_to'] ?? '')
            .toString();

    final customerName = (ticket["customer_name"] ?? "").toString();
    final customerNumber = (ticket["mobile_number"] ?? "").toString();
    final deviceModel = (ticket["device_model"] ?? "").toString();
    final estimatedCost = (ticket["estimated_cost"] ?? "").toString();
    final status = (ticket["status"] ?? "").toString().toLowerCase().trim();
    final bool isCancelled = status == 'cancelled';
    final bool canSendInvoice = status != 'pending' && !isCancelled;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Repair Details"),
          _detailRow(
              "Technician", assignedTech.isNotEmpty ? assignedTech : '-'),
          _detailRow("Estimated Cost",
              estimatedCost.isNotEmpty ? "₹ $estimatedCost" : "-"),
          _detailRow("Lock Code", ticket["lock_code"]?.toString() ?? '-'),
          const SizedBox(height: 12),
          Text(
            "Issue Description:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2E45),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F8FC),
              border: Border.all(
                color: const Color(0xFF6D5DF6).withOpacity(0.08),
              ),
            ),
            child: Text(
              ticket["issue_description"]?.toString() ?? "-",
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons aligned at the bottom of Repair Details
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: const Color(0xFF25D366).withOpacity(0.35),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                  label: Text(
                    "Send Message",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  onPressed: isCancelled
                      ? null
                      : () async {
                          if (customerNumber.isEmpty) {
                            Get.snackbar(
                              "Missing Number",
                              "No mobile number found in this ticket.",
                              backgroundColor: Colors.redAccent.withOpacity(0.9),
                              colorText: Colors.white,
                            );
                            return;
                          }

                          // Message content depends on status
                          String name = customerName.isNotEmpty ? customerName : 'Customer';
                          String model = deviceModel.isNotEmpty ? deviceModel : 'your device';
                          String message;
                          if (status == 'pending') {
                            message = '''
👋 Hello $name!

📱 We’ve received your *$model* safely at our service center.
🧑‍🔧 Our technicians have started the repair process and are working on it with care.
🔔 We’ll notify you as soon as your device is ready for delivery.

Thank you for choosing *Team JollyBaba* 💼
'''.trim();
                          } else if (status == 'repaired') {
                            message = '''
🎉 Hi $name, good news!

Your *$model* has been successfully repaired ✅
You can now collect it from our store 🏬 or wait for delivery as arranged 🚚

Thank you for trusting *Team JollyBaba* 💼
'''.trim();
                          } else if (status == 'delivered') {
                            message = '''
💙 Hi $name,

Thank you for choosing *JollyBaba!* 🙏
We hope your *$model* is working perfectly and you’re happy with our service 💫

Your trust means a lot to us — we truly appreciate it!

– *Team JollyBaba* 💼
'''.trim();
                          } else {
                            // default behavior
                            message = '''
👋 Hello $name,

We’ve received your *$model* and our team has started working on it 🔧
We’ll keep you updated on the progress.

– *Team JollyBaba* 💼
'''.trim();
                          }
                          await _openWhatsApp(customerNumber, message);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF128C7E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: const Color(0xFF128C7E).withOpacity(0.35),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.fileInvoice, color: Colors.white),
                  label: Text(
                    "Send Invoice",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  onPressed: canSendInvoice
                      ? () async {
                          if (customerNumber.isEmpty) {
                            Get.snackbar(
                              "Missing Number",
                              "No mobile number found in this ticket.",
                              backgroundColor: Colors.redAccent.withOpacity(0.9),
                              colorText: Colors.white,
                            );
                            return;
                          }

                          final message = _buildInvoiceSummaryMessage(ticket);

                          if (!Get.isSnackbarOpen) {
                            Get.snackbar(
                              "Opening WhatsApp",
                              "Preparing invoice summary...",
                              showProgressIndicator: true,
                              isDismissible: false,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }

                          try {
                            await _openWhatsApp(customerNumber, message);
                          } catch (e) {
                            Get.snackbar(
                              "WhatsApp",
                              "Unable to open WhatsApp: $e",
                              backgroundColor: Colors.redAccent.withOpacity(0.9),
                              colorText: Colors.white,
                            );
                          } finally {
                            if (Get.isSnackbarOpen) Get.back();
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, delay: 100.ms);
  }

  // ---------------- WhatsApp launcher helper ----------------
  /// Tries multiple fallbacks to open WhatsApp or WhatsApp Business.
  /// Order:
  ///  1) Android intent -> com.whatsapp.w4b (WhatsApp Business)
  ///  2) Android intent -> com.whatsapp (WhatsApp)
  ///  3) whatsapp:// URL scheme (generic)
  ///  4) https://wa.me/ (browser fallback)
  Future<void> _openWhatsApp(String phone, String message) async {
    final encoded = Uri.encodeComponent(message);

    // Android intent URIs (works on many Android devices)
    final intentBusiness =
        Uri.parse("intent://send?phone=91$phone&text=$encoded#Intent;package=com.whatsapp.w4b;scheme=whatsapp;end");
    final intentWhatsApp =
        Uri.parse("intent://send?phone=91$phone&text=$encoded#Intent;package=com.whatsapp;scheme=whatsapp;end");

    // generic URL scheme
    final scheme = Uri.parse("whatsapp://send?phone=91$phone&text=$encoded");

    // browser fallback
    final waMe = Uri.parse("https://wa.me/91$phone?text=$encoded");

    try {
      // 1) Intent -> WhatsApp Business
      if (Platform.isAndroid && await canLaunchUrl(intentBusiness)) {
        await launchUrl(intentBusiness, mode: LaunchMode.externalApplication);
        return;
      }

      // 2) Intent -> WhatsApp
      if (Platform.isAndroid && await canLaunchUrl(intentWhatsApp)) {
        await launchUrl(intentWhatsApp, mode: LaunchMode.externalApplication);
        return;
      }

      // 3) generic whatsapp scheme
      if (await canLaunchUrl(scheme)) {
        await launchUrl(scheme, mode: LaunchMode.externalApplication);
        return;
      }

      // 4) browser fallback (wa.me)
      if (await canLaunchUrl(waMe)) {
        await launchUrl(waMe, mode: LaunchMode.externalApplication);
        return;
      }

      // Nothing worked
      Get.snackbar("Error", "WhatsApp (or WhatsApp Business) is not installed on this device.",
          backgroundColor: Colors.redAccent.withOpacity(0.9), colorText: Colors.white);
    } catch (_) {
      Get.snackbar('WhatsApp', 'No handler available to open WhatsApp.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _buildInvoiceSummaryMessage(Map<String, dynamic> ticket) {
    final customerName = (ticket['customer_name'] ?? 'Customer').toString().trim();
    final ticketId = (ticket['id'] ?? '').toString().trim().isEmpty
        ? '-'
        : ticket['id'].toString();
    final deviceModel = (ticket['device_model'] ?? '-').toString().trim().isEmpty
        ? 'Not specified'
        : ticket['device_model'].toString();
    final imei = (ticket['imei'] ?? '').toString().trim().isEmpty
        ? 'Not provided'
        : ticket['imei'].toString();
    final deliveryDate = _formatDeliveryDate(ticket['delivery_date']);
    final amount = _formatCurrency(ticket['estimated_cost']);
    final notes = _extractNotes(ticket['notes']);
    final businessName = (ticket['company_name'] ?? 'JollyBaba Mobile Repairing').toString().trim().isEmpty
        ? 'JollyBaba Mobile Repairing'
        : ticket['company_name'].toString();

    return 'Hi $customerName 👋\n\n'
        "Here’s your invoice summary for Ticket #$ticketId 🧾\n\n"

        "📱 Device: $deviceModel\n"
        "🔢 IMEI: $imei\n"
        "💰 Total Amount: $amount\n"

        "Kindly review the details above.\n"
        "Thank you for your business! 🙌\n"
        "— Team $businessName";
  }

  String _formatDeliveryDate(dynamic raw) {
    if (raw == null) return 'Not provided';
    if (raw is DateTime) {
      return DateFormat('dd MMM yyyy').format(raw);
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy').format(parsed);
      }
      return raw.trim().isEmpty ? 'Not provided' : raw;
    }
    return raw.toString();
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₹0';
    if (value is num) {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
    }
    final parsed = num.tryParse(value.toString());
    if (parsed == null) return '₹0';
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(parsed);
  }

  String _extractNotes(dynamic notesRaw) {
    if (notesRaw == null) return 'Not provided';
    if (notesRaw is String) {
      return notesRaw.trim().isEmpty ? 'Not provided' : notesRaw.trim();
    }
    if (notesRaw is List) {
      final collected = notesRaw
          .map((item) {
            if (item is Map && item['text'] != null) {
              final text = item['text'].toString().trim();
              if (text.isNotEmpty) return text;
            } else if (item != null) {
              final text = item.toString().trim();
              if (text.isNotEmpty) return text;
            }
            return null;
          })
          .whereType<String>()
          .toList();
      if (collected.isEmpty) return 'Not provided';
      return collected.join(' • ');
    }
    return notesRaw.toString().trim().isEmpty ? 'Not provided' : notesRaw.toString();
  }

  // 💎 Glassmorphic Card
  Widget _glassCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.96),
              Colors.white.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6D5DF6).withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D5DF6).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2A2E45),
            fontSize: 16,
          ),
        ),
      );

  Widget _detailRow(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.8,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                value?.toString().isNotEmpty == true ? value.toString() : "-",
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
}
