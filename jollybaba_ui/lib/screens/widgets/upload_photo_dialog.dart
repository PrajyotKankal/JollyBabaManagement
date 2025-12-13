// lib/screens/widgets/upload_photo_dialog.dart
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Result class that works for both web and mobile
class PhotoResult {
  final File? file;           // For mobile
  final Uint8List? bytes;     // For web
  final String? fileName;     // Original file name
  
  PhotoResult({this.file, this.bytes, this.fileName});
  
  bool get hasData => file != null || (bytes != null && bytes!.isNotEmpty);
}

/// UploadPhotoDialog (single-photo)
/// - Works on both web (mobile browsers) and native mobile
/// - Returns PhotoResult via Navigator.pop(context, result) or null if cancelled.
class UploadPhotoDialog extends StatefulWidget {
  final File? initialPhoto;
  final Future<File?> Function()? onTakePhoto;  // Legacy callback (mobile only)
  final String titleText;
  final String placeholderText;
  final String takeButtonText;
  final String doneButtonText;

  const UploadPhotoDialog({
    super.key,
    required this.initialPhoto,
    this.onTakePhoto,  // Now optional - we handle internally for web
    this.titleText = 'Upload Delivery Photo',
    this.placeholderText = 'Capture delivery proof photo',
    this.takeButtonText = 'Take Photo',
    this.doneButtonText = 'Done',
  });

  @override
  State<UploadPhotoDialog> createState() => _UploadPhotoDialogState();
}

class _UploadPhotoDialogState extends State<UploadPhotoDialog> {
  File? _photoFile;        // For mobile
  Uint8List? _photoBytes;  // For web
  String? _fileName;
  bool _isPicking = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _photoFile = widget.initialPhoto;
  }

  /// Universal photo picker - works on web and mobile
  Future<void> _handleTakePhoto() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      // Use ImagePicker - it has web support built-in
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );
      
      if (pickedFile == null) {
        setState(() => _isPicking = false);
        return;
      }

      if (kIsWeb) {
        // On web, read as bytes
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _photoBytes = bytes;
          _fileName = pickedFile.name;
          _photoFile = null;  // Clear file reference
        });
      } else {
        // On mobile, use the file path
        if (!mounted) return;
        setState(() {
          _photoFile = File(pickedFile.path);
          _photoBytes = null;  // Clear bytes
        });
      }
    } catch (e, st) {
      debugPrint('Photo pick error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo. Please try again.\n${e.toString().substring(0, 100.clamp(0, e.toString().length))}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Pick from gallery (good fallback for web)
  Future<void> _handlePickFromGallery() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile == null) {
        setState(() => _isPicking = false);
        return;
      }

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _photoBytes = bytes;
          _fileName = pickedFile.name;
          _photoFile = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _photoFile = File(pickedFile.path);
          _photoBytes = null;
        });
      }
    } catch (e, st) {
      debugPrint('Gallery pick error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick photo from gallery.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  bool get _hasPhoto => _photoFile != null || (_photoBytes != null && _photoBytes!.isNotEmpty);

  Widget _photoArea() {
    if (!_hasPhoto) {
      return Container(
        color: const Color.fromRGBO(255, 255, 255, 0.06),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                widget.placeholderText,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show image from bytes (web) or file (mobile)
    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return Image.memory(
        _photoBytes!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildErrorPlaceholder(),
      );
    }

    if (_photoFile != null) {
      try {
        if (!_photoFile!.existsSync()) {
          return _buildErrorPlaceholder();
        }
        return Image.file(
          _photoFile!,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildErrorPlaceholder(),
        );
      } catch (_) {
        return _buildErrorPlaceholder();
      }
    }

    return _buildErrorPlaceholder();
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: const Color.fromRGBO(255, 255, 255, 0.06),
      child: Center(
        child: Text('Cannot display photo', style: GoogleFonts.poppins(color: Colors.white70)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: const Color.fromRGBO(255, 255, 255, 0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.18),
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF9B8CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.titleText,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // --- Photo Preview ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: _photoArea(),
                  ),
                ),

                const SizedBox(height: 12),

                // --- Camera Button Only ---
                ElevatedButton.icon(
                  onPressed: _isPicking ? null : _handleTakePhoto,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    _hasPhoto ? 'Retake Photo' : widget.takeButtonText,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7B61FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _hasPhoto
                            ? () {
                                final result = PhotoResult(
                                  file: _photoFile,
                                  bytes: _photoBytes,
                                  fileName: _fileName,
                                );
                                Navigator.pop(context, result);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: const Color.fromRGBO(255, 255, 255, 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          widget.doneButtonText,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF7B61FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

