// lib/screens/ticket_details_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/ticket_service.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'widgets/upload_photo_dialog.dart';

/// NOTE:
/// - This controller normalizes server-relative image paths (e.g. '/uploads/abc.jpg')
///   into absolute URLs using the compile-time dart-define `API_BASE_URL` when available:
///     flutter run --dart-define=API_BASE_URL=http://172.20.10.2:5000
/// - If API_BASE_URL is not provided, it will attempt to use ticket['api_base'] or ticket['host'].
/// - If none are available it returns the raw value (so local File() handling still applies).
const String _envApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

class TicketDetailsController extends GetxController {
  // -------------------- CORE STATE --------------------
  late Map<String, dynamic> ticket;
  
  // Loading state for assign to me action
  final RxBool isAssigning = false.obs;
  
  late String status; // UI-friendly: "Pending", "Delivered", etc.
  late String previousStatus;

  final RxBool isSaving = false.obs;

  // Local photo placeholders (optional persisted previews)
  final Rxn<File> deliveryPhoto1 = Rxn<File>();
  final Rxn<File> repairedPhoto = Rxn<File>();
  final Rxn<File> deliveryPhoto2 = Rxn<File>();
  
  // Web photo bytes (for cross-platform support)
  Uint8List? repairedPhotoBytes;
  Uint8List? deliveryPhoto2Bytes;
  String? repairedPhotoFileName;
  String? deliveryPhoto2FileName;

  // Notes
  final TextEditingController notesController = TextEditingController();
  final List<Map<String, dynamic>> notesList = [];

  // track original notes count so we know if user added new notes
  int _originalNotesCount = 0;

  bool _initialized = false;
  String?
  _initializedTicketId; // remember which ticket id this controller was init'd for

  // Permissions (computed in init)
  bool isAdmin = false;
  bool isTechnician = false;
  bool isAssignedTechnician = false;
  Map<String, dynamic>? _currentUser;

  // Derived edit flags (set in _loadUserPermissions)
  bool canEditNotes = false;
  bool canEditStatus = false;

  // Creator & assigned info (for UI)
  String createdBy = '';
  String assignedTechnician = '';

  // -------------------- INIT --------------------
  /// Initialize controller with ticket data.
  /// Idempotent for the same ticket id.
  Future<void> init(Map<String, dynamic> data) async {
    final incomingId = (data['id'] ?? data.hashCode).toString();

    // if already initialized for same ticket, skip
    if (_initialized && _initializedTicketId == incomingId) return;

    // clone incoming map to avoid mutating outside reference
    ticket = Map<String, dynamic>.from(data);

    debugPrint('🔍 ticket keys: ${ticket.keys.toList()}');
    debugPrint('🔍 delivery_photo_1: ${ticket['delivery_photo_1']}');
    debugPrint('🔍 device_photo_url: ${ticket['device_photo_url']}');
    debugPrint('🔍 device_photo_filename: ${ticket['device_photo_filename']}');
    debugPrint('🔍 device_photo_path: ${ticket['device_photo_path']}');
    debugPrint('🔍 photo: ${ticket['photo']}');

    // migrate common legacy photo keys into unified key delivery_photo_1
    final legacyKeys = [
      'attachedDevicePhoto',
      'attached_device_photo',
      'attached_photo',
      'attachedPicture',
      'device_photo',
    ];

    for (final k in legacyKeys) {
      final val = ticket[k];
      if (val != null && val.toString().trim().isNotEmpty) {
        ticket['delivery_photo_1'] ??= val.toString().trim();
        ticket.remove(k);
      }
    }

    // ✅ NEW: normalize new-style keys (from create ticket flow)
    final possibleDevicePhotoKeys = [
      'device_photo_url',
      'device_photo_filename',
      'device_photo_path',
      'photo_url',
      'photo',
    ];
    for (final k in possibleDevicePhotoKeys) {
      final val = ticket[k];
      if (val != null && val.toString().trim().isNotEmpty) {
        ticket['delivery_photo_1'] ??= val.toString().trim();
      }
    }

    // If backend returned a server-relative path (like "/uploads/...") convert to absolute URL when possible
    _normalizePhotoPaths();

    // status
    final rawStatus = (ticket['status'] as String?)?.trim() ?? 'Pending';
    status = _titleCase(rawStatus);
    previousStatus = status;

    // notes parsing (supports List<Map> or legacy string)
    _loadNotesFromTicket();

    // created / assigned for display
    createdBy =
        (ticket['created_by_name'] ??
                ticket['created_by'] ??
                ticket['creator_name'] ??
                ticket['created_by_email'] ??
                '')
            .toString();

    // assigned technician display (try several possible keys)
    assignedTechnician =
        (ticket['assigned_technician_name'] ??
                ticket['assigned_to_name'] ??
                ticket['assigned_to'] ??
                ticket['assigned_technician'] ??
                '')
            .toString();

    // perms - await AuthService (defensive: handle possible runtime nulls)
    await _loadUserPermissions();

    _initialized = true;
    _initializedTicketId = incomingId;
    update();
  }

  // -------------------- UTIL --------------------
  String _titleCase(String s) {
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  void _loadNotesFromTicket() {
    notesList.clear();
    final rawNotes = ticket['notes'];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        if (n == null) continue;
        String text = '';
        DateTime time = DateTime.now();

        if (n is String) {
          text = n;
        } else if (n is Map) {
          text = (n['text'] ?? n['note'] ?? '').toString();
          final tVal = n['time'];
          if (tVal is DateTime) {
            time = tVal;
          } else if (tVal is String && tVal.isNotEmpty) {
            time = DateTime.tryParse(tVal) ?? DateTime.now();
          }
        }

        if (text.isNotEmpty) {
          notesList.add({'text': text, 'time': time});
        }
      }
    } else if (ticket['technician_notes'] is String) {
      final txt = (ticket['technician_notes'] as String).trim();
      if (txt.isNotEmpty) {
        notesList.add({'text': txt, 'time': DateTime.now()});
      }
    }

    _originalNotesCount = notesList.length;
    notesController.clear();
  }

  // -------------------- SELF ASSIGNMENT --------------------
  Future<bool> assignToMe() async {
    if (!canAssignToMe || _currentUser == null) return false;

    final confirm = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Assign to Me'),
            content: const Text(
              'Do you want to take ownership of this ticket? This will mark the ticket as In Progress.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D5DF6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Assign to Me'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return false;

    final rawId = ticket['id']?.toString();
    final ticketId = rawId != null ? int.tryParse(rawId) : null;
    if (ticketId == null) {
      Get.snackbar(
        'Assignment failed',
        'Ticket is missing an identifier.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final currentEmail = (_currentUser!['email'] ?? '').toString().trim().toLowerCase();
    final currentName = (_currentUser!['name'] ?? '').toString().trim();
    final displayName = currentName.isNotEmpty ? currentName : currentEmail;

    isAssigning.value = true;
    update();

    try {
      final payload = <String, dynamic>{
        'assigned_technician': displayName,
        'assigned_technician_email': currentEmail,
        'assigned_to': displayName,
        'assigned_to_email': currentEmail,
        'worked_by_email': currentEmail,
        'worked_by_name': displayName,
        'work_action': 'self_assign',
        'work_notes': 'Ticket self-assigned by technician',
        'worked_at': DateTime.now().toIso8601String(),
      };

      final success = await TicketService.updateTicket(ticketId, payload);
      if (!success) {
        throw Exception('Server rejected the assignment request');
      }

      ticket['assigned_technician'] = displayName;
      ticket['assigned_technician_email'] = currentEmail;
      ticket['assigned_to'] = displayName;
      ticket['assigned_to_email'] = currentEmail;
      assignedTechnician = displayName;
      isAssignedTechnician = true;

      update();

      Get.snackbar(
        'Assigned',
        'You are now assigned to this ticket.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return true;
    } catch (e, st) {
      debugPrint('assignToMe failed: $e\n$st');
      Get.snackbar(
        'Assignment failed',
        'Unable to assign ticket. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isAssigning.value = false;
      update();
    }
  }

  /// Loads user info and computes permission flags.
  /// This implementation explicitly type-checks the values returned by AuthService
  /// to avoid analyzer dead-code/nullability warnings while remaining defensive.
  Future<void> _loadUserPermissions() async {
    try {
      final auth = AuthService();

      // Call both APIs but treat results defensively (they may be Map or null).
      final dynamic storedRaw = await auth.getStoredUser();
      final dynamic fetchedRaw = await auth.me();

      Map<String, dynamic>? me;

      if (storedRaw is Map<String, dynamic>) {
        me = storedRaw;
      } else if (fetchedRaw is Map<String, dynamic>) {
        me = fetchedRaw;
      } else {
        me = null;
      }

      if (me == null) {
        // No signed in user found
        isAdmin = false;
        isTechnician = false;
        isAssignedTechnician = false;
        canEditNotes = false;
        canEditStatus = false;
        return;
      }

      _currentUser = me;

      final role = _normalizeIdentifier(me['role']);
      final email = _currentUserEmailLower;
      final name = _currentUserNameLower;

      // The assigned email on ticket may be in several fields depending on backend
      final assignedEmail = _assignedEmailLower;
      final assignedName = _assignedNameLower;

      isAdmin = role == 'admin' || role == 'administrator';
      isTechnician =
          role == 'technician' || role == 'tech' || (role.isEmpty && !isAdmin);
      final matchesCurrentUser = (assignedEmail.isNotEmpty && email.isNotEmpty && email == assignedEmail) ||
          (assignedName.isNotEmpty && name.isNotEmpty && assignedName == name);
      isAssignedTechnician = isTechnician && matchesCurrentUser;

      // Allow any technician to edit, but keep admin override
      canEditNotes = isAdmin || isTechnician;
      canEditStatus = isAdmin || isTechnician;

      debugPrint(
        '[TicketDetails] role=$role email=$email name=$name assignedEmail=$assignedEmail assignedName=$assignedName '
        'isTech=$isTechnician isAssigned=$isAssignedTechnician',
      );
    } catch (e, st) {
      debugPrint('Permission load failed: $e\n$st');
      isAdmin = false;
      isTechnician = false;
      isAssignedTechnician = false;
      canEditNotes = false;
      canEditStatus = false;
    }
  }

  void refreshUI() => update();

  Future<bool> updateTicketDetails(
    Map<String, dynamic> fields, {
    String? auditNote,
  }) async {
    final rawId = ticket['id']?.toString();
    final ticketId = rawId != null ? int.tryParse(rawId) : null;
    if (ticketId == null || fields.isEmpty) {
      Get.snackbar(
        'Nothing to save',
        'No editable changes detected.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final payload = Map<String, dynamic>.from(fields);
    final currentEmail = (_currentUser?['email'] ?? '').toString().trim().toLowerCase();
    final currentName = (_currentUser?['name'] ?? '').toString().trim();

    payload['worked_by_email'] = currentEmail.isNotEmpty ? currentEmail : null;
    payload['worked_by_name'] = currentName.isNotEmpty ? currentName : null;
    payload['work_action'] = 'edit_ticket';
    payload['work_notes'] = auditNote ?? 'Ticket details updated';
    payload['worked_at'] = DateTime.now().toIso8601String();

    isSaving.value = true;
    update();

    try {
      final success = await TicketService.updateTicket(ticketId, payload);
      if (!success) throw Exception('Server rejected the update request');

      fields.forEach((key, value) {
        ticket[key] = value;
      });

      ticket['last_worked_by_email'] = payload['worked_by_email'];
      ticket['last_worked_by_name'] = payload['worked_by_name'];
      ticket['last_worked_at'] = payload['worked_at'];

      if (fields.containsKey('assigned_technician') ||
          fields.containsKey('assigned_to') ||
          fields.containsKey('assigned_technician_email') ||
          fields.containsKey('assigned_to_email')) {
        assignedTechnician = (ticket['assigned_technician'] ??
                ticket['assigned_to'] ??
                '')
            .toString();
      }

      _normalizePhotoPaths();
      update();

      Get.snackbar(
        'Ticket updated',
        'Changes saved successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.1),
      );
      return true;
    } catch (e, st) {
      debugPrint('updateTicketDetails error: $e\n$st');
      Get.snackbar(
        'Update failed',
        'Unable to save ticket changes. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
      );
      return false;
    } finally {
      isSaving.value = false;
      update();
    }
  }

  // -------------------- URL NORMALIZATION --------------------
  /// Convert server-relative paths (e.g. "/uploads/x.jpg") into absolute URLs if we have an API base.
  /// Uses (in order): dart-define `API_BASE_URL`, ticket['api_base'], ticket['host'].
  String _absUrl(String? maybe) {
    if (maybe == null) return '';
    final s = maybe.toString().trim();
    if (s.isEmpty) return '';

    // If already absolute, return as-is
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // If it's a file:// path on device, return as-is (UI code will create File(...))
    if (s.startsWith('file://')) return s;

    // If it starts with '/', treat as server-relative; try to prefix with known base
    if (s.startsWith('/')) {
      final bases = <String>[];
      if (_envApiBase.isNotEmpty)
        bases.add(_envApiBase.replaceAll(RegExp(r'/$'), ''));
      if (ticket['api_base'] is String &&
          (ticket['api_base'] as String).trim().isNotEmpty) {
        bases.add(
          (ticket['api_base'] as String).trim().replaceAll(RegExp(r'/$'), ''),
        );
      }
      if (ticket['host'] is String &&
          (ticket['host'] as String).trim().isNotEmpty) {
        bases.add(
          (ticket['host'] as String).trim().replaceAll(RegExp(r'/$'), ''),
        );
      }

      if (bases.isNotEmpty) {
        return '${bases.first}$s';
      } else {
        // no base known — return raw so UI may interpret as local path (still better than changing)
        return s;
      }
    }

    // otherwise return original (might be a relative token or local path)
    return s;
  }

  void _normalizePhotoPaths() {
    // Normalize common photo keys for UI consumption
    final raw1 =
        ticket['delivery_photo_1'] ??
        ticket['device_photo'] ??
        ticket['delivery_photo'];
    if (raw1 != null && raw1.toString().trim().isNotEmpty) {
      ticket['delivery_photo_1'] = _absUrl(raw1.toString());
    }

    final rawRepaired = ticket['repaired_photo'];
    if (rawRepaired != null && rawRepaired.toString().trim().isNotEmpty) {
      ticket['repaired_photo'] = _absUrl(rawRepaired.toString());
    }

    final rawRepairedThumb = ticket['repaired_photo_thumb'];
    if (rawRepairedThumb != null && rawRepairedThumb.toString().trim().isNotEmpty) {
      ticket['repaired_photo_thumb'] = _absUrl(rawRepairedThumb.toString());
    }

    final raw2 = ticket['delivery_photo_2'];
    if (raw2 != null && raw2.toString().trim().isNotEmpty) {
      ticket['delivery_photo_2'] = _absUrl(raw2.toString());
    }
  }

  // -------------------- STATUS CHANGE --------------------
  /// Update the local UI status. If marking delivered, require a photo.
  Future<void> updateStatus(String newStatus) async {
    // guard: ensure user has permission to edit status
    if (!canEditStatus) {
      // revert visually (status stays what it was)
      Get.snackbar(
        'Not allowed',
        'You are not allowed to change the status of this ticket.',
        snackPosition: SnackPosition.BOTTOM,
      );
      // ensure UI remains consistent
      status = previousStatus;
      update();
      return;
    }

    previousStatus = status;
    status = newStatus;
    update();

    try {
      final lower = newStatus.toLowerCase();
      if (lower == 'delivered' && previousStatus.toLowerCase() != 'delivered') {
        final gotPhoto = await _showSingleUploadDialogAndSetPhoto();
        if (!gotPhoto) {
          status = previousStatus;
          update();
          Get.snackbar(
            'Photo Required',
            'You must capture a delivery photo to mark as Delivered.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color.fromRGBO(255, 69, 58, 0.12),
            colorText: Colors.black87,
          );
        }
      } else if (lower == 'repaired' && previousStatus.toLowerCase() != 'repaired') {
        final gotPhoto = await _showRepairedUploadDialog();
        if (!gotPhoto) {
          status = previousStatus;
          update();
          Get.snackbar(
            'Photo Required',
            'You must capture a repaired proof photo to mark as Repaired.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color.fromRGBO(255, 69, 58, 0.12),
            colorText: Colors.black87,
          );
        }
      } else {
        // If moving away from delivered status, clear any cached delivery photo file to avoid stale uploads
        if (lower != 'delivered' && deliveryPhoto2.value != null) {
          deliveryPhoto2.value = null;
        }
      }
    } catch (e, st) {
      debugPrint('updateStatus error: $e\n$st');
    }
  }

  // -------------------- NOTES --------------------
  void addNote() {
    final text = notesController.text.trim();
    if (text.isEmpty) return;
    notesList.insert(0, {'text': text, 'time': DateTime.now()});
    notesController.clear();
    update();
  }

  void removeNoteAt(int index) {
    if (index < 0 || index >= notesList.length) return;
    notesList.removeAt(index);
    update();
  }

  // -------------------- PHOTO HELPERS --------------------
  Future<File> _persistPickedFile(File picked) async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${appDir.path}/delivery_photos');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final fileName =
        'photo_${ticket['id'] ?? 't'}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final saved = File('${outDir.path}/$fileName');

    return picked.copy(saved.path);
  }

  Future<File?> _pickPhoto({
    ImageSource source = ImageSource.camera,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );
      if (picked == null) return null;
      return _persistPickedFile(File(picked.path));
    } catch (e, st) {
      debugPrint('Image pick error: $e\n$st');
      Get.snackbar(
        'Photo Error',
        'Could not pick photo. Please check permissions and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color.fromRGBO(255, 69, 58, 0.12),
        colorText: Colors.black87,
      );
      return null;
    }
  }

  Future<bool> _showSingleUploadDialogAndSetPhoto() async {
    final result = await Get.dialog<PhotoResult?>(
      UploadPhotoDialog(
        initialPhoto: deliveryPhoto2.value,
      ),
      barrierDismissible: true,
    );

    if (result == null || !result.hasData) return false;
    
    if (kIsWeb && result.bytes != null) {
      deliveryPhoto2Bytes = result.bytes;
      deliveryPhoto2FileName = result.fileName;
      deliveryPhoto2.value = null;
    } else if (result.file != null) {
      deliveryPhoto2.value = result.file;
      deliveryPhoto2Bytes = null;
    }
    update();
    return true;
  }

  Future<bool> _showRepairedUploadDialog() async {
    final result = await Get.dialog<PhotoResult?>(
      UploadPhotoDialog(
        initialPhoto: repairedPhoto.value,
        titleText: 'Upload Repaired Photo',
        placeholderText: 'Capture repaired proof photo',
        takeButtonText: 'Capture Proof',
        doneButtonText: 'Use Photo',
      ),
      barrierDismissible: true,
    );

    if (result == null || !result.hasData) return false;
    
    if (kIsWeb && result.bytes != null) {
      repairedPhotoBytes = result.bytes;
      repairedPhotoFileName = result.fileName;
      repairedPhoto.value = null;
    } else if (result.file != null) {
      repairedPhoto.value = result.file;
      repairedPhotoBytes = null;
    }
    update();
    return true;
  }

  Future<bool> _ensuresRepairedPhotoUploaded() async {
    final hasRemote = (ticket['repaired_photo']?.toString().trim().isNotEmpty ?? false);
    File? local = repairedPhoto.value;
    final hasWebBytes = repairedPhotoBytes != null && repairedPhotoBytes!.isNotEmpty;

    // If no photo and no web bytes and no remote, prompt for capture
    if (local == null && !hasWebBytes && !hasRemote) {
      final captured = await _showRepairedUploadDialog();
      if (!captured) return false;
      local = repairedPhoto.value;
    }

    // If still no photo data, check if we have remote already
    if (local == null && !hasWebBytes) {
      return hasRemote;
    }

    try {
      Get.closeAllSnackbars();
      Get.showSnackbar(const GetSnackBar(
        message: 'Uploading repaired photo...',
        showProgressIndicator: true,
        isDismissible: false,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(minutes: 1),
      ));

      final notePayload = notesList
          .map((n) => {
                'text': (n['text'] ?? '').toString(),
                'time': _noteIso(n['time']),
              })
          .toList();

      Map<String, dynamic>? response;
      
      if (hasWebBytes) {
        // Upload from bytes (web)
        response = await TicketService.uploadRepairedPhotoFromBytes(
          ticket['id'] as int,
          repairedPhotoBytes!,
          fileName: repairedPhotoFileName ?? 'repaired_photo.jpg',
          notes: notePayload,
        );
      } else if (local != null) {
        // Upload from file (mobile)
        response = await TicketService.uploadRepairedPhoto(
          ticket['id'] as int,
          local,
          notes: notePayload,
        );
      }

      Get.closeAllSnackbars();

      if (response == null || response['success'] != true || response['ticket'] == null) {
        Get.snackbar(
          'Repaired Photo',
          'Failed to upload repaired photo. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        return false;
      }

      final updatedTicket = Map<String, dynamic>.from(response['ticket'] as Map);
      ticket = updatedTicket;
      status = _titleCase((ticket['status'] ?? status).toString());
      previousStatus = status;
      repairedPhoto.value = null;
      repairedPhotoBytes = null;
      repairedPhotoFileName = null;
      _loadNotesFromTicket();
      _normalizePhotoPaths();
      update();

      return true;
    } catch (e, st) {
      Get.closeAllSnackbars();
      debugPrint('Repaired photo upload error: $e\n$st');
      Get.snackbar(
        'Repaired Photo',
        'Failed to upload repaired photo. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }
  }

  String _noteIso(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toIso8601String() ?? value;
    }
    return DateTime.now().toIso8601String();
  }

  // -------------------- SAVE TICKET LOGIC --------------------
  Future<void> saveTicketStatus(BuildContext context) async {
    if (isSaving.value) return;

    // If user has typed a note but not pressed 'send', include it automatically
    final pendingText = notesController.text.trim();
    if (pendingText.isNotEmpty && canEditNotes) {
      // add it to notesList so it becomes part of the payload
      notesList.insert(0, {'text': pendingText, 'time': DateTime.now()});
      notesController.clear();
      update();
    }

    final lowerStatus = status.toLowerCase();

    // When marking as Delivered require a delivery photo (slot 2)
    if (lowerStatus == 'repaired') {
      final success = await _ensuresRepairedPhotoUploaded();
      if (!success) {
        status = previousStatus;
        update();
        return;
      }

      isSaving.value = false;
      update();

      Get.snackbar(
        '✅ Ticket Updated',
        'Repaired photo saved successfully.',
        backgroundColor: const Color.fromRGBO(76, 175, 80, 0.12),
        colorText: Colors.black87,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 700));
      Get.back(result: ticket);
      return;
    } else if (lowerStatus == 'delivered') {
      // Check for both file (mobile) and bytes (web)
      final hasDeliveryPhoto = deliveryPhoto2.value != null || 
          (deliveryPhoto2Bytes != null && deliveryPhoto2Bytes!.isNotEmpty);
      
      if (!hasDeliveryPhoto) {
        final uploaded = await _showSingleUploadDialogAndSetPhoto();
        final hasPhotoAfterDialog = deliveryPhoto2.value != null || 
            (deliveryPhoto2Bytes != null && deliveryPhoto2Bytes!.isNotEmpty);
        if (!uploaded || !hasPhotoAfterDialog) {
          status = previousStatus;
          update();
          Get.snackbar(
            'Photo Required',
            'Please upload a delivery photo before marking as Delivered.',
            backgroundColor: const Color.fromRGBO(255, 69, 58, 0.12),
            colorText: Colors.black87,
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }
    } else if (['repaired', 'cancelled'].contains(lowerStatus)) {
      final confirm = await _showConfirmationDialog();
      if (!confirm) {
        status = previousStatus;
        update();
        return;
      }
    }

    // if nothing to save, skip
    if (!canSave) {
      debugPrint('saveTicketStatus: nothing to save (canSave=false)');
      Get.snackbar(
        'Nothing to save',
        'No changes detected.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSaving.value = true;
    update();

    Map<String, dynamic>? actingIdentity;
    final me = _currentUser;
    if (me != null) {
      actingIdentity = {
        'worked_by_email': (me['email'] ?? me['username'] ?? '').toString().trim(),
        'worked_by_name': (me['name'] ?? '').toString().trim(),
      };
      final idVal = me['id'];
      if (idVal != null) actingIdentity['worked_by_id'] = idVal;
    }

    final payload = <String, dynamic>{
      'status': status,
      'notes': notesList
          .map(
            (n) => {
              'text': n['text'],
              'time': (n['time'] as DateTime).toIso8601String(),
            },
          )
          .toList(),
      if (actingIdentity != null) ...actingIdentity,
      if (actingIdentity != null) 'work_action': 'status:$status',
      if (actingIdentity != null) 'worked_at': DateTime.now().toIso8601String(),
    };

    debugPrint('saveTicketStatus: payload => $payload');

    // Handle delivery photo upload - check for web bytes or file
    final hasWebDeliveryBytes = deliveryPhoto2Bytes != null && deliveryPhoto2Bytes!.isNotEmpty;
    final hasDeliveryFile = deliveryPhoto2.value != null;
    String? uploadedDeliveryPhotoUrl;
    
    try {
      if (hasWebDeliveryBytes) {
        // Web platform: upload bytes via Cloudinary
        Get.showSnackbar(const GetSnackBar(
          message: 'Uploading delivery photo...',
          showProgressIndicator: true,
          isDismissible: false,
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(minutes: 1),
        ));
        
        final notePayload = notesList
            .map((n) => {
                  'text': (n['text'] ?? '').toString(),
                  'time': _noteIso(n['time']),
                })
            .toList();
        
        final response = await TicketService.uploadDeliveryPhotoFromBytes(
          ticket['id'] as int,
          deliveryPhoto2Bytes!,
          fileName: deliveryPhoto2FileName ?? 'delivery_photo.jpg',
          status: status,
          notes: notePayload,
        );
        
        Get.closeAllSnackbars();
        
        if (response == null || response['success'] != true) {
          Get.snackbar(
            'Photo Error',
            'Failed to upload delivery photo. Please try again.',
            backgroundColor: const Color.fromRGBO(244, 67, 54, 0.12),
            colorText: Colors.black87,
            snackPosition: SnackPosition.BOTTOM,
          );
          isSaving.value = false;
          update();
          return;
        }
        
        // Photo uploaded and ticket updated via the upload function
        uploadedDeliveryPhotoUrl = response['ticket']?['delivery_photo_2']?.toString();
        
        // Clear the bytes now that upload succeeded
        deliveryPhoto2Bytes = null;
        deliveryPhoto2FileName = null;
        
        // Update local ticket state
        ticket['status'] = status;
        ticket['delivery_photo_2'] = uploadedDeliveryPhotoUrl;
        previousStatus = status;
        _normalizePhotoPaths();
        update();
        
        Get.snackbar(
          '✅ Ticket Updated',
          'Delivery photo saved successfully.',
          backgroundColor: const Color.fromRGBO(76, 175, 80, 0.12),
          colorText: Colors.black87,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        
        await Future.delayed(const Duration(milliseconds: 700));
        Get.back(result: ticket);
        isSaving.value = false;
        update();
        return;
      } else if (hasDeliveryFile) {
        // Mobile platform: prepare and upload file
        var persisted = deliveryPhoto2.value!;
        if (!await persisted.exists()) {
          persisted = await _persistPickedFile(persisted);
          deliveryPhoto2.value = persisted;
        }
        payload['delivery_photo_2'] = persisted.path;
      }
    } catch (e, st) {
      Get.closeAllSnackbars();
      debugPrint('Error preparing/uploading delivery photo: $e\n$st');
      Get.snackbar(
        'Photo Error',
        'Could not upload delivery photo. Please try again.',
        backgroundColor: const Color.fromRGBO(244, 67, 54, 0.12),
        colorText: Colors.black87,
        snackPosition: SnackPosition.BOTTOM,
      );
      isSaving.value = false;
      update();
      return;
    }

    bool success = false;
    try {
      success = await TicketService.updateTicket(ticket['id'], payload);
      debugPrint('TicketService.updateTicket returned: $success');
    } catch (e, st) {
      debugPrint('Ticket update error: $e\n$st');
      success = false;
    }

    if (success) {
      // update local ticket
      ticket['status'] = status;
      previousStatus = status;

      if (ticket['delivery_photo'] != null &&
          ticket['delivery_photo_1'] == null) {
        ticket['delivery_photo_1'] = ticket['delivery_photo'];
      }

      if (deliveryPhoto2.value != null) {
        ticket['delivery_photo_2'] = deliveryPhoto2.value!.path;
      }

      ticket['notes'] = payload['notes'];
      ticket['technician_notes'] = notesList
          .map((n) => n['text'] as String)
          .join('\n\n');

      _originalNotesCount = notesList.length;

      // After save, normalize again so any server-returned relative paths become absolute URLs
      _normalizePhotoPaths();

      update();

      Get.snackbar(
        '✅ Ticket Updated',
        'Changes saved successfully.',
        backgroundColor: const Color.fromRGBO(76, 175, 80, 0.12),
        colorText: Colors.black87,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // small pause so the user sees the snackbar
      await Future.delayed(const Duration(milliseconds: 700));

      // return to the previous screen and pass the updated ticket as the result
      Get.back(result: ticket);
    } else {
      Get.snackbar(
        '❌ Error',
        'Failed to save changes. Please try again.',
        backgroundColor: const Color.fromRGBO(244, 67, 54, 0.12),
        colorText: Colors.black87,
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    isSaving.value = false;
    update();
  }

  // -------------------- CONFIRM DIALOG --------------------
  Future<bool> _showConfirmationDialog() async {
    final result = await Get.dialog<bool?>(
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1.0),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          builder: (context, scale, child) => Transform.scale(
            scale: scale.clamp(0.0, 1.0),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color.fromRGBO(123, 97, 255, 0.95),
              title: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 48,
              ),
              content: Text(
                'Do you really want to mark this ticket as "$status"?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Get.back(result: true),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Color(0xFF7B61FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
    return result ?? false;
  }

  // -------------------- GETTERS / SETTERS --------------------
  File? get photoFile1 => deliveryPhoto1.value;
  File? get repairedPhotoFile => repairedPhoto.value;
  File? get photoFile2 => deliveryPhoto2.value;

  bool get canEditTicket => isAdmin || isTechnician;

  bool get canAssignToMe {
    if (!isTechnician || _currentUser == null) return false;

    final email = _currentUserEmailLower;
    final name = _currentUserNameLower;
    if (email.isEmpty && name.isEmpty) return false;

    final assignedEmail = _assignedEmailLower;
    final assignedName = _assignedNameLower;

    final matchesCurrentUser = (assignedEmail.isNotEmpty && email.isNotEmpty && assignedEmail == email) ||
        (assignedName.isNotEmpty && name.isNotEmpty && assignedName == name);

    final allowed = !matchesCurrentUser;
    debugPrint(
      '[TicketDetails] canAssignToMe=$allowed isTech=$isTechnician currentEmail=$email currentName=$name '
      'assignedEmail=$assignedEmail assignedName=$assignedName',
    );
    return allowed;
  }

  String _normalizeIdentifier(dynamic value) {
    if (value == null) return '';
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null' || normalized == 'none' || normalized == '-') {
      return '';
    }
    return normalized;
  }

  String get _assignedEmailLower {
    final candidates = [
      ticket['assigned_technician_email'],
      ticket['assigned_to_email'],
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeIdentifier(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  String get _assignedNameLower {
    final candidates = [
      ticket['assigned_technician_name'],
      ticket['assigned_to_name'],
      ticket['assigned_technician'],
      ticket['assigned_to'],
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeIdentifier(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  String get _currentUserEmailLower =>
      _normalizeIdentifier(_currentUser?['email'] ?? _currentUser?['username']);

  String get _currentUserNameLower =>
      _normalizeIdentifier(_currentUser?['name']);

  /// Returns a normalized absolute URL when possible; otherwise returns the raw string.
  /// Returns a normalized absolute URL when possible; otherwise returns the raw string.
  String get photoRef1 {
    final candidates = <String?>[
      ticket['delivery_photo_1']?.toString(),
      ticket['device_photo']?.toString(),
      ticket['device_photo_url']?.toString(),
      ticket['device_photo_filename']?.toString(),
      ticket['device_photo_path']?.toString(), // ✅ new
      ticket['image_path']?.toString(), // ✅ new
      ticket['delivery_photo']?.toString(),
      ticket['photo']?.toString(),
    ];

    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return _absUrl(c);
    }
    return '';
  }

  String get repairedPhotoRef => _absUrl(ticket['repaired_photo']?.toString() ?? '');
  String get repairedThumbRef => _absUrl(ticket['repaired_photo_thumb']?.toString() ?? '');
  String get photoRef2 => _absUrl(ticket['delivery_photo_2']?.toString() ?? '');

  set photoRef1(String value) {
    ticket['delivery_photo_1'] = value.trim();
    update();
  }

  set repairedPhotoRef(String value) {
    ticket['repaired_photo'] = value.trim();
    update();
  }

  set photoRef2(String value) {
    ticket['delivery_photo_2'] = value.trim();
    update();
  }

  // -------------------- FLAGS --------------------
  bool get savedIsReadOnly {
    final s = (ticket['status'] ?? previousStatus).toString().toLowerCase();
    return s == 'delivered' || s == 'cancelled';
  }

  bool get hasUnsavedChanges {
    final statusChanged =
        status.toLowerCase() !=
        (ticket['status'] ?? previousStatus).toString().toLowerCase();
    final notesChanged = notesList.length != _originalNotesCount;
    final hasNewPhotos =
        (deliveryPhoto1.value != null &&
            (ticket['delivery_photo_1'] == null ||
                deliveryPhoto1.value!.path !=
                    ticket['delivery_photo_1']?.toString())) ||
        (deliveryPhoto2.value != null &&
            (ticket['delivery_photo_2'] == null ||
                deliveryPhoto2.value!.path !=
                    ticket['delivery_photo_2']?.toString()));
    return statusChanged || notesChanged || hasNewPhotos;
  }

  bool get canSave {
    if (savedIsReadOnly && !hasUnsavedChanges) return false;
    return hasUnsavedChanges;
  }

  // -------------------- CLEANUP --------------------
  @override
  void onClose() {
    notesController.dispose();
    super.onClose();
  }
}
