// lib/screens/widgets/customer_info_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ticket_details_controller.dart';
import 'status_dropdown.dart';

class CustomerInfoCard extends StatelessWidget {
  final TicketDetailsController controller;
  const CustomerInfoCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ticket = controller.ticket;

    final createdBy = controller.createdBy.trim();
    final assignedTo = controller.assignedTechnician.trim();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Customer Information"),
          const SizedBox(height: 4),

          _detailRow("Name", ticket["customer_name"]),
          _detailRow("Mobile", ticket["mobile_number"]),
          _detailRow("Device", ticket["device_model"]),
          _detailRow("IMEI", ticket["imei"]),
          _detailRow(
              "Received",
              ticket["receive_date"]?.toString().split("T").first ??
                  "-"),
          _detailRow(
              "Repair Date",
              ticket["repair_date"]?.toString().split("T").first ??
                  "-"),

          const SizedBox(height: 12),

          // NEW: show who created the ticket (if available) and assigned technician
          _detailRow("Created By", createdBy.isNotEmpty ? createdBy : "-"),
          _detailRow("Assigned To", assignedTo.isNotEmpty ? assignedTo : "-"),

          const SizedBox(height: 14),
          StatusDropdown(controller: controller),
        ],
      ),
    );
  }

  // 🧊 Glassmorphic Card
  Widget _glassCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.96),
              Colors.white.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6D5DF6).withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D5DF6).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  // 🏷 Section Title
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2A2E45),
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      );

  // 📋 Detail Row
  Widget _detailRow(String label, dynamic value) {
    final display = (value?.toString() ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              display.isNotEmpty ? display : "-",
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
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
}
