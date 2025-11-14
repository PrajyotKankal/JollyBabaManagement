// lib/screens/widgets/upload_photo_dialog.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UploadPhotoDialog (single-photo)
/// - Returns File? via Navigator.pop(context, file) or null if cancelled.
class UploadPhotoDialog extends StatefulWidget {
  final File? initialPhoto;
  final Future<File?> Function() onTakePhoto;
  final String titleText;
  final String placeholderText;
  final String takeButtonText;
  final String doneButtonText;

  const UploadPhotoDialog({
    super.key,
    required this.initialPhoto,
    required this.onTakePhoto,
    this.titleText = 'Upload Delivery Photo',
    this.placeholderText = 'Capture delivery proof photo',
    this.takeButtonText = 'Take Photo',
    this.doneButtonText = 'Done',
  });

  @override
  State<UploadPhotoDialog> createState() => _UploadPhotoDialogState();
}

class _UploadPhotoDialogState extends State<UploadPhotoDialog> {
  File? _photo;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
  }

  Future<void> _handleTakePhoto() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final file = await widget.onTakePhoto();
      if (!mounted) return;
      if (file != null) {
        setState(() => _photo = file);
      }
    } catch (e, st) {
      debugPrint('Photo pick error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick photo. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Widget _photoArea() {
    if (_photo == null) {
      return Container(
        color: const Color.fromRGBO(255, 255, 255, 0.06),
        child: Center(
          child: Text(
            widget.placeholderText,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // defensive: show placeholder if file doesn't exist or cannot be read
    try {
      if (!_photo!.existsSync()) {
        return Container(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
          child: Center(
            child: Text('Photo unavailable', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
        );
      }

      return Image.file(
        _photo!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
          child: Center(
            child: Text('Cannot display photo', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
        ),
      );
    } catch (_) {
      return Container(
        color: const Color.fromRGBO(255, 255, 255, 0.06),
        child: Center(
          child: Text('Cannot display photo', style: GoogleFonts.poppins(color: Colors.white70)),
        ),
      );
    }
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

                // --- Single Photo Slot ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: _photoArea(),
                  ),
                ),

                const SizedBox(height: 10),

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
                    _photo == null ? widget.takeButtonText : 'Retake Photo',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _photo != null ? () => Navigator.pop(context, _photo) : null,
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
