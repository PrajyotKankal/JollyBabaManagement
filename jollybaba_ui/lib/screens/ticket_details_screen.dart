// lib/screens/ticket_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../utils/whatsapp_launcher_mobile.dart' if (dart.library.html) '../utils/whatsapp_launcher_web.dart';

import 'ticket_details_controller.dart';
import '../services/auth_service.dart';
import 'widgets/customer_info_card.dart';
import 'widgets/repair_details_card.dart';
import 'widgets/technician_notes_section.dart';
import 'widgets/save_button.dart';
import 'widgets/edit_ticket_sheet.dart';

class TicketDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TicketDetailsScreen({super.key, required this.ticket});

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  late final String tag;
  late final TicketDetailsController controller;

  @override
  void initState() {
    super.initState();
    tag = (widget.ticket['id'] ?? widget.ticket.hashCode).toString();
    // Put controller with unique tag for this ticket
    controller = Get.put(TicketDetailsController(), tag: tag);
    // Initialize once here (init is async in the controller; it calls update when ready)
    controller.init(widget.ticket);
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    // trim leading zeros
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    // If 10-digit (likely India), prefix 91
    if (digits.length == 10) return '91$digits';
    // If already with country code (like 91xxxxxxxxxx), keep as-is
    return digits;
  }

  Future<void> _openWhatsApp(String phone, String message) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      Get.snackbar('Invalid number', 'Customer phone number is missing.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final success = await openWhatsAppPlatform(normalized, message);
      
      if (!success) {
        Get.snackbar('WhatsApp', 'WhatsApp is not available. Please install it first.', 
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('WhatsApp', 'No handler available to open WhatsApp.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _onSendThankYou() async {
    final t = controller.ticket;
    final phone = (t['mobile_number'] ?? '').toString();
    final customer = (t['customer_name'] ?? 'Customer').toString();
    final device = (t['device_model'] ?? 'your device').toString();
    final company = (t['company_name'] ?? 'JollyBaba Mobile Repairing').toString();
    final msg = 'Dear $customer,\n\nThank you! Your $device has been repaired. You can collect it at your convenience.\n\n– $company';
    await _openWhatsApp(phone, msg);
  }

  @override
  void dispose() {
    // If you want to remove controller when screen is closed uncomment:
    // Get.delete<TicketDetailsController>(tag: tag);
    super.dispose();
  }

  /// Navigate back to the appropriate dashboard based on user role
  /// More reliable than Get.back() on web/PWA platforms
  Future<void> _navigateBack() async {
    try {
      final storedUser = await AuthService().getStoredUser();
      final role = (storedUser?['role'] ?? 'technician').toString().toLowerCase();
      if (role == 'admin') {
        Get.offAllNamed('/admin');
      } else {
        Get.offAllNamed('/tech');
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      Get.offAllNamed('/tech');
    }
  }

  // --- Helper: Thumbnail from local file or network ---
  Widget _thumbnailFromRef(String? ref, {double size = 56}) {
    final photoRef = (ref ?? '').trim();
    if (photoRef.isEmpty) return _placeholderThumbnail(size: size);

    if (photoRef.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photoRef,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderThumbnail(size: size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final expected = progress.expectedTotalBytes;
            final value = expected == null
                ? null
                : (progress.cumulativeBytesLoaded / expected).clamp(0.0, 1.0);
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, value: value),
              ),
            );
          },
        ),
      );
    }

    try {
      final file = File(photoRef);
      if (!file.existsSync()) return _placeholderThumbnail(size: size);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderThumbnail(size: size),
        ),
      );
    } catch (_) {
      return _placeholderThumbnail(size: size);
    }
  }

  // --- Placeholder thumbnail ---
  Widget _placeholderThumbnail({double size = 56}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.photo, color: Color(0xFF9AA3BE), size: 26),
      );

  // --- Small badge used over images ---
  Widget _labelChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2A2E45))),
      );

  // --- AppBar thumbnail (single or stacked) ---
  Widget _buildAppBarThumbnail(TicketDetailsController controller) {
    final refs = <String>[controller.photoRef1, controller.repairedPhotoRef, controller.photoRef2]
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (controller.photoFile1 != null) refs.insert(0, controller.photoFile1!.path);
    if (controller.repairedPhotoFile != null) refs.insert(1, controller.repairedPhotoFile!.path);
    if (controller.photoFile2 != null) refs.add(controller.photoFile2!.path);

    final uniqueRefs = refs.where((value) => value.trim().isNotEmpty).toSet().toList();

    if (uniqueRefs.isEmpty) return _placeholderThumbnail(size: 40);
    if (uniqueRefs.length == 1) {
      return _thumbnailFromRef(uniqueRefs.first, size: 40);
    }

    return SizedBox(
      width: 72,
      height: 40,
      child: Stack(
        children: [
          if (uniqueRefs.length >= 1)
            Positioned(left: 0, child: _thumbnailFromRef(uniqueRefs[0], size: 36)),
          if (uniqueRefs.length >= 2)
            Positioned(left: 18, child: _thumbnailFromRef(uniqueRefs[1], size: 36)),
          if (uniqueRefs.length >= 3)
            Positioned(right: 0, child: _thumbnailFromRef(uniqueRefs[2], size: 36)),
        ],
      ),
    );
  }

  // --- Photo grid display (Pending • Repaired • Delivered) ---
  Widget _buildPhotosArea(BuildContext context, TicketDetailsController controller) {
    final uploadsAllowed = !controller.savedIsReadOnly;

    final refPending = controller.photoRef1;
    final refRepaired = controller.repairedPhotoRef;
    final refDelivered = controller.photoRef2;

    final filePending = controller.photoFile1 ?? (refPending.isNotEmpty && !refPending.startsWith('http') ? File(refPending) : null);
    final fileRepaired = controller.repairedPhotoFile ?? (refRepaired.isNotEmpty && !refRepaired.startsWith('http') ? File(refRepaired) : null);
    final fileDelivered = controller.photoFile2 ?? (refDelivered.isNotEmpty && !refDelivered.startsWith('http') ? File(refDelivered) : null);

    final hasPending = (filePending != null && filePending.existsSync()) || refPending.trim().isNotEmpty;
    final hasRepaired = (fileRepaired != null && fileRepaired.existsSync()) || refRepaired.trim().isNotEmpty;
    final hasDelivered = (fileDelivered != null && fileDelivered.existsSync()) || refDelivered.trim().isNotEmpty;

    Widget imageTile({
      File? file,
      String? url,
      required String caption,
      required String badge,
    }) {
      final fileExists = file != null && file.existsSync();
      final hasUrl = url != null && url.trim().isNotEmpty;

      final imageWidget = fileExists
          ? Image.file(file, fit: BoxFit.cover)
          : hasUrl
              ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _emptyPhotoTile(caption))
              : _emptyPhotoTile(caption);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: (fileExists || hasUrl)
                    ? () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            child: InteractiveViewer(child: imageWidget),
                          ),
                        )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(height: 200, child: imageWidget),
                ),
              ),
              Positioned(top: 10, left: 10, child: _labelChip(badge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(caption, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B6F86))),
        ],
      );
    }

    final tiles = <Widget>[
      Expanded(
        child: hasPending
            ? imageTile(file: filePending, url: refPending, caption: 'Pending pic', badge: 'Pending pic')
            : _emptyPhotoTile('Pending pic'),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: hasRepaired
            ? imageTile(file: fileRepaired, url: refRepaired, caption: 'Repaired proof', badge: 'Repaired pic')
            : _emptyPhotoTile('Repaired proof'),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: hasDelivered
            ? imageTile(file: fileDelivered, url: refDelivered, caption: 'Delivered pic', badge: 'Delivered pic')
            : _emptyPhotoTile('Delivered pic'),
      ),
    ];

    final noteText = uploadsAllowed
        ? 'Photo timeline: Pending intake • Repaired proof • Delivery confirmation.'
        : 'Photos are visible but uploads are disabled for this status.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(noteText, style: GoogleFonts.poppins(color: const Color(0xFF6B6F86))),
        ),
        Row(children: tiles),
      ],
    );
  }

  Widget _emptyPhotoTile(String label) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(child: Text(label, style: GoogleFonts.poppins(color: Colors.black54))),
      );

  // --- Small info row (created by / assigned to) ---
  Widget _buildCreatorAssignedRow(TicketDetailsController controller) {
    final created = controller.createdBy.trim();
    final assigned = controller.assignedTechnician.trim();
    final workedBy = (controller.ticket['last_worked_by_name'] ?? controller.ticket['last_worked_by_email'] ?? '')
        .toString()
        .trim();
    final workedAtRaw = controller.ticket['last_worked_at']?.toString() ?? '';
    DateTime? workedAt;
    if (workedAtRaw.isNotEmpty) {
      try {
        workedAt = DateTime.parse(workedAtRaw).toLocal();
      } catch (_) {}
    }
    final workedWhen = workedAt != null ? DateFormat('MMM d, h:mm a').format(workedAt) : null;

    // If both missing, return empty space so layout unchanged
    if (created.isEmpty && assigned.isEmpty && workedBy.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (created.isNotEmpty)
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF6D5DF6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Created by: $created',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2A2E45)),
                    ),
                  ),
                ],
              ),
            ),
          if (assigned.isNotEmpty) const SizedBox(width: 12),
          if (assigned.isNotEmpty)
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 16, color: Color(0xFF6D5DF6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Assigned: $assigned',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2A2E45)),
                    ),
                  ),
                ],
              ),
            ),
          if (workedBy.isNotEmpty) const SizedBox(width: 12),
          if (workedBy.isNotEmpty)
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.handyman_outlined, size: 16, color: Color(0xFF6D5DF6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      workedWhen != null
                          ? 'Last worked by $workedBy • $workedWhen'
                          : 'Last worked by $workedBy',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2A2E45)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6D5DF6), Color(0xFF9B8CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text("Ticket Details",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2A2E45)),
            onPressed: () => _navigateBack(),
          ),
          actions: [
            // Edit button - opens EditTicketSheet for modifying ticket details
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF6D5DF6),
                  size: 20,
                ),
              ),
              onPressed: () async {
                final result = await Get.to<bool>(
                  () => EditTicketSheet(controller: controller),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                );
                // Refresh the screen if edit was successful
                if (result == true) {
                  controller.update();
                }
              },
              tooltip: 'Edit Ticket',
            ),
            GetBuilder<TicketDetailsController>(
              tag: tag,
              builder: (_) => Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(child: _buildAppBarThumbnail(controller)),
              ),
            ),
          ],
        ),
        body: GetBuilder<TicketDetailsController>(
          tag: tag,
          builder: (_) => Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: isWide ? size.width * 0.1 : 20,
                  right: isWide ? size.width * 0.1 : 20,
                  bottom: 120,
                  top: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator / Assigned info (non-invasive addition)
                    _buildCreatorAssignedRow(controller).animate().fadeIn(duration: 220.ms),

                    CustomerInfoCard(controller: controller).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
                    const SizedBox(height: 18),
                    RepairDetailsCard(controller: controller).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, delay: 80.ms),
                    const SizedBox(height: 12),

                    // Info note if status changes to Delivered — shows correct message
                    Builder(builder: (_) {
                      final lower = controller.status.toLowerCase();
                      final prev = controller.previousStatus.toLowerCase();
                      if (lower == 'delivered' && prev != 'delivered') {
                        final hasDeliveryPhoto = controller.photoFile2 != null || controller.photoRef2.trim().isNotEmpty;
                        final msg = hasDeliveryPhoto
                            ? 'Delivery photo captured. It will be saved when you tap Save.'
                            : 'You selected "Delivered". Please capture a delivery photo (a dialog was opened).';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFF6D5DF6), size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(msg, style: GoogleFonts.poppins(color: const Color(0xFF6B6F86)))),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),

                    const SizedBox(height: 16),
                    _buildPhotosArea(context, controller),
                    const SizedBox(height: 18),

                    TechnicianNotesSection(controller: controller).animate().fadeIn(duration: 600.ms).slideY(begin: 0.25, delay: 150.ms),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              Positioned(bottom: 20, left: 20, right: 20, child: SaveButton(controller: controller)),
            ],
          ),
        ),
      ),
    );
  }
}
