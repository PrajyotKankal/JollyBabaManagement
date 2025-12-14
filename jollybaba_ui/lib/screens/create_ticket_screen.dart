// lib/screens/create_ticket_screen.dart
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/ticket_service.dart';
import '../services/auth_service.dart';

// Platform-specific upload helpers
import 'create_ticket_mobile.dart' if (dart.library.html) 'create_ticket_web.dart';

// Web barcode scanner
import '../widgets/web_barcode_scanner.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen>
    with SingleTickerProviderStateMixin {
  int currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;
  bool isClosing = false;
  bool showSuccessCard = false;

  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? selectedImage;

  // Fields
  final customerName = TextEditingController();
  final customerNumber = TextEditingController();
  final deviceModel = TextEditingController();
  final imei = TextEditingController();
  final issueDesc = TextEditingController();
  final estimatedCost = TextEditingController();
  final lockCode = TextEditingController();
  DateTime? repairDate;

  bool _isScanning = false;
  MobileScannerController? _scannerController;

  // Technician dropdown state
  List<Map<String, dynamic>> _technicians = [];
  String? _selectedTechnicianEmail;
  Map<String, dynamic>? _me; // current user (from AuthService)

  bool _loadingTechnicians = true;
  bool _loadingMe = true;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _addListeners();
    _initData();
  }

  Future<void> _initData() async {
    await _loadCurrentUser();
    await _loadTechnicians();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _loadingMe = true);
    try {
      final stored = await _auth.getStoredUser();
      if (stored != null) {
        _me = stored;
      } else {
        final result = await _auth.me();
        _me = result;
      }
    } catch (_) {
      _me = null;
    } finally {
      setState(() => _loadingMe = false);
    }
  }

  Future<void> _loadTechnicians() async {
    setState(() => _loadingTechnicians = true);
    try {
      final resp = await _auth.getWithAuth('/technicians/public');

      final list = <Map<String, dynamic>>[];
      if (resp is Map && resp['technicians'] is List) {
        for (var t in resp['technicians']) {
          if (t is Map) list.add(Map<String, dynamic>.from(t));
        }
      } else if (resp is List) {
        for (var t in resp) {
          if (t is Map) list.add(Map<String, dynamic>.from(t));
        }
      }

      list.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });

      setState(() {
        _technicians = list;
      });

      // Default-select current user (match by email) when possible
      final myEmail = (_me?['email'] ?? '').toString().toLowerCase();
      if (myEmail.isNotEmpty && _technicians.isNotEmpty) {
        String? foundEmail;
        for (final t in _technicians) {
          final email = (t['email'] ?? '').toString().toLowerCase();
          if (email.isNotEmpty && email == myEmail) {
            foundEmail = t['email']?.toString();
            break;
          }
        }
        if (foundEmail != null) {
          setState(() => _selectedTechnicianEmail = foundEmail);
        }
      }

      // If user is a technician, prefer they get assigned to themselves (and disable selection)
      final role = (_me?['role'] ?? '').toString().toLowerCase();
      if (role == 'technician' && _selectedTechnicianEmail == null && _technicians.isNotEmpty) {
        final myEmail = (_me?['email'] ?? '').toString().toLowerCase();
        final found = _technicians.firstWhere(
            (t) => (t['email'] ?? '').toString().toLowerCase() == myEmail,
            orElse: () => _technicians.first);
        setState(() => _selectedTechnicianEmail = found['email']?.toString());
      }
    } catch (e) {
      Get.snackbar('Tech Load Error', 'Could not fetch technicians: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9), colorText: Colors.white);
    } finally {
      setState(() => _loadingTechnicians = false);
    }
  }

  void _addListeners() {
    final controllers = [
      customerName,
      customerNumber,
      deviceModel,
      imei,
      issueDesc,
      estimatedCost,
      lockCode,
    ];
    for (var c in controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    customerName.dispose();
    customerNumber.dispose();
    deviceModel.dispose();
    imei.dispose();
    issueDesc.dispose();
    estimatedCost.dispose();
    lockCode.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) setState(() => selectedImage = picked);
    } catch (e) {
      Get.snackbar("Image Error", "Could not pick image: $e",
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          colorText: Colors.black87);
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text("Add Photo", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF6D5DF6)),
              title: Text("Take Photo", style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF6D5DF6)),
              title: Text("Choose From Gallery", style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: Text("Remove Photo", style: GoogleFonts.poppins(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedImage = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        return customerName.text.isNotEmpty && customerNumber.text.isNotEmpty;
      case 1:
        return deviceModel.text.isNotEmpty &&
            imei.text.isNotEmpty &&
            issueDesc.text.isNotEmpty;
      case 2:
        return (_selectedTechnicianEmail != null && _selectedTechnicianEmail!.isNotEmpty) &&
            estimatedCost.text.isNotEmpty &&
            lockCode.text.isNotEmpty &&
            repairDate != null;
      default:
        return false;
    }
  }

  Future<void> _createTicket() async {
    if (isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final ticket = <String, dynamic>{
      "customer_name": customerName.text.trim(),
      "mobile_number": customerNumber.text.trim(),
      "device_model": deviceModel.text.trim(),
      "imei": imei.text.trim(),
      "issue_description": issueDesc.text.trim(),
      "assigned_technician": _selectedTechnicianEmail?.trim() ?? "",
      "estimated_cost": estimatedCost.text.trim(),
      "lock_code": lockCode.text.trim(),
      "repair_date": repairDate?.toIso8601String(),
      "receive_date": DateTime.now().toIso8601String(),
      "status": "Pending",
    };

    try {
      // Upload image first if present
      if (selectedImage?.path.isNotEmpty == true) {
        // show upload snackbar
        if (Get.isSnackbarOpen != true) {
          Get.snackbar("Uploading", "Uploading image...", showProgressIndicator: true, isDismissible: false, snackPosition: SnackPosition.BOTTOM);
        }

        dynamic uploaded;
        try {
          // Use platform-specific upload helper
          if (kIsWeb) {
            uploaded = await uploadImageWeb(selectedImage!);
          } else {
            uploaded = await uploadImageMobile(selectedImage!);
          }
        } catch (e) {
          if (Get.isSnackbarOpen == true) Get.back();
          Get.snackbar("Upload Error", "Failed to upload image: $e",
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
          setState(() => isSubmitting = false);
          return;
        }

        if (Get.isSnackbarOpen == true) Get.back();

        String? url;
        String? filename;

        if (uploaded == null) {
          Get.snackbar("Upload Failed", "Server returned no file info.",
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
          setState(() => isSubmitting = false);
          return;
        } else if (uploaded is String) {
          url = uploaded;
        } else if (uploaded is Map) {
          url = (uploaded['url'] ?? uploaded['file'] ?? (uploaded['data'] is Map ? uploaded['data']['url'] : null))?.toString();
          filename = (uploaded['filename'] ?? uploaded['name'])?.toString();
        } else if (uploaded is List && uploaded.isNotEmpty) {
          final first = uploaded[0];
          if (first is Map) {
            url = (first['url'] ?? first['file'] ?? (first['data'] is Map ? first['data']['url'] : null))?.toString();
            filename = (first['filename'] ?? first['name'])?.toString();
          } else if (first is String) {
            url = first;
          }
        } else {
          Get.snackbar("Upload Failed", "Unexpected upload response: ${uploaded.runtimeType}",
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
          setState(() => isSubmitting = false);
          return;
        }

        if (url == null || url.isEmpty) {
          Get.snackbar("Upload Failed", "Upload did not return a valid URL.",
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
          setState(() => isSubmitting = false);
          return;
        }

        // Upload returned URL/filename -> set several aliases so detail UI / backend find it reliably
        ticket['device_photo_url'] = url;

        // common older/newer aliases used across codebase and server variants:
        ticket['device_photo'] = url;
        ticket['delivery_photo_1'] = url;
        ticket['photo_url'] = url;
        ticket['photo'] = url;

        // keep filename under multiple keys too (optional helpers)
        if (filename != null && filename.isNotEmpty) {
          ticket['device_photo_filename'] = filename;
          ticket['device_photo_name'] = filename;
        }
      }

      // create ticket
      final created = await TicketService.createTicket(ticket);

      if (created) {
        if (mounted) setState(() => showSuccessCard = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => isClosing = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Get.back(result: true);
      } else {
        Get.snackbar("❌ Error", "Failed to create ticket. Please try again.",
            backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
      }
    } catch (e) {
      Get.snackbar("⚠️ Error", "Unexpected issue: $e",
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1), colorText: Colors.black87);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _validateCurrentStep();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.6),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),

          if (showSuccessCard)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 70),
                  ).animate().scale(duration: 400.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  Text("Ticket Created",
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
                            ).createShader(Rect.fromLTWH(0, 0, 200, 0)))),
                ],
              ),
            ),

          if (!showSuccessCard)
            Center(
              child: AnimatedScale(
                scale: isClosing ? 0.9 : 1.0,
                duration: 300.ms,
                child: AnimatedOpacity(
                  opacity: isClosing ? 0 : 1,
                  duration: 300.ms,
                  child: Container(
                    width: isMobile ? size.width * 0.94 : 560,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.9,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("New Repair Ticket",
                                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                                  GestureDetector(
                                    onTap: () => Get.back(),
                                    child: const Icon(Icons.close_rounded, color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              AnimatedSwitcher(
                                duration: 400.ms,
                                child: _buildStepContent(currentStep),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (currentStep > 0)
                                    TextButton(onPressed: () => setState(() => currentStep--), child: const Text("← Back")),
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: 400.ms,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        gradient: canProceed
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFF7B61FF),
                                                  Color(0xFF6C63FF),
                                                  Color(0xFF8E7BFF),
                                                ],
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  Colors.grey.withValues(alpha: 0.4),
                                                  Colors.grey.withValues(alpha: 0.3)
                                                ],
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: AnimatedOpacity(
                                              opacity: canProceed ? 1 : 0,
                                              duration: 600.ms,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white.withValues(alpha: 0.25),
                                                      Colors.white.withValues(alpha: 0.05),
                                                      Colors.transparent,
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: canProceed && !isSubmitting
                                                ? () async {
                                                    if (currentStep < 2) {
                                                      setState(() => currentStep++);
                                                      return;
                                                    }
                                                    await _createTicket();
                                                  }
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: isSubmitting
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.2,
                                                    ),
                                                  )
                                                : Text(
                                                    currentStep < 2 ? "Next →" : "Create Ticket",
                                                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return Column(
          key: const ValueKey(0),
          children: [
            _buildField("Customer Name", customerName),
            const SizedBox(height: 12),
            _buildField("Mobile Number", customerNumber, keyboard: TextInputType.phone),
            const SizedBox(height: 8),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          children: [
            _buildField("Device Model", deviceModel),
            const SizedBox(height: 12),
            _buildField(
              "IMEI Number",
              imei,
              suffix: IconButton(
                tooltip: 'Scan IMEI',
                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF6D5DF6)),
                onPressed: _startImeiScan,
              ),
            ),
            const SizedBox(height: 12),
            _buildField("Issue Description", issueDesc, lines: 3),
            const SizedBox(height: 8),
          ],
        );
      default:
        return Column(
          key: const ValueKey(2),
          children: [
            _buildTechnicianDropdown(),
            const SizedBox(height: 12),
            _buildField("Estimated Cost (₹)", estimatedCost, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _buildField("Lock Code / Pattern", lockCode),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => repairDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E6EF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFF6D5DF6)),
                    const SizedBox(width: 10),
                    Text(
                      repairDate != null ? "Repair Date: ${repairDate!.toLocal().toString().split(' ')[0]}" : "Select Repair Date",
                      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showImageSourceActionSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6D5DF6).withValues(alpha: 0.12), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF836EF9)])),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedImage == null ? "Upload Mobile Photo (optional)" : selectedImage!.name,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    if (selectedImage != null)
                      GestureDetector(onTap: () => setState(() => selectedImage = null), child: const Icon(Icons.close_rounded, color: Colors.black54, size: 20)),
                  ],
                ),
              ),
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FutureBuilder<Widget>(
                    future: _buildImagePreview(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return snapshot.data!;
                      }
                      return const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
    }
  }

  Widget _buildTechnicianDropdown() {
    final role = (_me?['role'] ?? '').toString().toLowerCase();
    final isTechnicianUser = role == 'technician';

    if (_loadingTechnicians || _loadingMe) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE3E6EF))),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, color: Color(0xFF6D5DF6)),
            const SizedBox(width: 10),
            Expanded(child: Text("Loading technicians...", style: GoogleFonts.poppins())),
            const SizedBox(width: 6),
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      );
    }

    final items = _technicians.map((t) {
      final name = (t['name'] ?? '').toString();
      final role = (t['role'] ?? '').toString();
      final email = (t['email'] ?? '').toString();
      final label = name.isNotEmpty ? (role.isNotEmpty ? "$name · $role" : name) : email;
      return DropdownMenuItem<String>(value: email, child: Text(label, style: GoogleFonts.poppins()));
    }).toList();

    return AbsorbPointer(
      absorbing: isTechnicianUser,
      child: Opacity(
        opacity: isTechnicianUser ? 0.8 : 1.0,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedTechnicianEmail,
          isExpanded: true,
          items: items,
          onChanged: (v) {
            if (!isTechnicianUser) setState(() => _selectedTechnicianEmail = v);
          },
          validator: (v) => (v == null || v.isEmpty) ? 'Please select an assigned technician' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE3E6EF), width: 1.2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D5DF6), width: 1.5)),
            hintText: 'Assigned Technician',
          ),
        ),
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController controller, {TextInputType keyboard = TextInputType.text, int lines = 1, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: lines,
      validator: (v) => v!.isEmpty ? "Required field" : null,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.black45),
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE3E6EF), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D5DF6), width: 1.5)),
      ),
    );
  }

  Future<Widget> _buildImagePreview() async {
    if (selectedImage == null) {
      return const SizedBox.shrink();
    }

    // Always use Image.memory for both platforms (works everywhere)
    final bytes = await selectedImage!.readAsBytes();
    return Image.memory(
      bytes,
      height: 140,
      fit: BoxFit.cover,
    );
  }

  void _startImeiScan() {
    if (_isScanning) return;
    
    // On web, use WebBarcodeScanner with html5-qrcode
    if (kIsWeb) {
      setState(() => _isScanning = true);
      WebBarcodeScanner.showScanner(
        onSuccess: (String code) {
          final normalized = code.replaceAll(RegExp(r'[^0-9]'), '');
          if (_isValidImeiLength(normalized)) {
            _applyScannedImei(normalized);
          } else {
            Get.snackbar(
              'IMEI Scan',
              'Detected code is not a valid IMEI (needs 14-16 digits).',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
          if (mounted) setState(() => _isScanning = false);
        },
        onError: (String error) {
          Get.snackbar(
            'Scanner Error',
            error,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent.withOpacity(0.9),
            colorText: Colors.white,
          );
          if (mounted) setState(() => _isScanning = false);
        },
      );
      return;
    }
    
    // Mobile: use MobileScanner
    final detectionHits = <String, int>{};
    var invalidShown = false;
    const defaultHitThreshold = 2;
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.qrCode,
        BarcodeFormat.pdf417,
      ],
    );
    setState(() => _isScanning = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetCtx) {
        final controller = _scannerController!;
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final boxWidth = width * 0.78;
              final boxHeight = height * 0.28;
              final leftPx = (width - boxWidth) / 2;
              final topPx = (height - boxHeight) / 2;
              final scanWindow = Rect.fromLTWH(leftPx, topPx, boxWidth, boxHeight);
              final overlayRect = scanWindow;

              controller.start();

              return Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    fit: BoxFit.cover,
                    scanWindow: scanWindow,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final rawValue = barcode.rawValue?.trim();
                        if (rawValue == null || rawValue.isEmpty) continue;
                        final normalized = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
                        if (!_isValidImeiLength(normalized)) {
                          if (!invalidShown) {
                            invalidShown = true;
                            Get.snackbar(
                              'IMEI Scan',
                              'Detected code is not a valid IMEI (needs 14-16 digits).',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                          continue;
                        }
                        if (!_passesImeiChecksumIfPresent(normalized)) {
                          if (!invalidShown) {
                            invalidShown = true;
                            Get.snackbar(
                              'IMEI Scan',
                              'Scanned code failed IMEI checksum. Please rescan.',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                          continue;
                        }
                        final requiredHits = normalized.length == 15 ? 1 : defaultHitThreshold;
                        final hits = (detectionHits[normalized] ?? 0) + 1;
                        detectionHits[normalized] = hits;
                        if (hits >= requiredHits) {
                          Navigator.of(sheetCtx).maybePop();
                          _applyScannedImei(normalized);
                          return;
                        }
                      }
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(overlayRect),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(sheetCtx).maybePop(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: height * 0.08, left: 24, right: 24),
                      child: Text(
                        'Align the IMEI barcode within the frame and hold steady for confirmation',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ValueListenableBuilder<TorchState>(
                            valueListenable: controller.torchState,
                            builder: (_, state, __) {
                              final isOn = state == TorchState.on;
                              return IconButton(
                                icon: Icon(isOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                                tooltip: isOn ? 'Turn off flash' : 'Turn on flash',
                                onPressed: () => controller.toggleTorch(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        _scannerController?.stop();
        setState(() => _isScanning = false);
      }
    });
  }

  void _applyScannedImei(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return;
    setState(() {
      imei.text = normalized;
    });
    _scannerController?.stop();
  }

  bool _isValidImeiLength(String digits) {
    return digits.length >= 14 && digits.length <= 16;
  }

  bool _passesImeiChecksumIfPresent(String digits) {
    if (digits.length != 15) {
      return true;
    }
    int sum = 0;
    for (int i = 0; i < 14; i++) {
      int d = int.parse(digits[i]);
      if (i.isOdd) {
        int doubled = d * 2;
        if (doubled > 9) doubled -= 9;
        sum += doubled;
      } else {
        sum += d;
      }
    }
    final expectedCheck = (10 - (sum % 10)) % 10;
    final actualCheck = int.parse(digits[14]);
    return expectedCheck == actualCheck;
  }

}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect boxRect;
  _ScannerOverlayPainter(this.boxRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final fullRect = Offset.zero & size;
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(16)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
