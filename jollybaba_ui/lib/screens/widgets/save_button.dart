// lib/screens/widgets/save_button.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ticket_details_controller.dart';
import 'package:flutter/services.dart'; // For haptic feedback

class SaveButton extends StatefulWidget {
  final TicketDetailsController controller;
  const SaveButton({super.key, required this.controller});

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glowPulse;

  @override
  void initState() {
    super.initState();
    _glowPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowPulse.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final controller = widget.controller;

    // Prevent double taps while saving
    if (controller.isSaving.value) return;

    // If user does not have edit permission, show message (shouldn't happen because button hidden)
    if (!controller.canEditNotes && !controller.canEditStatus) {
      HapticFeedback.lightImpact();
      Get.snackbar(
        'No Permission',
        'You do not have permission to modify this ticket.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // If controller says can't save (read-only & no unsaved changes) show message
    if (!controller.canSave) {
      HapticFeedback.lightImpact();
      Get.snackbar(
        'Nothing to save',
        'No changes to save or ticket is read-only.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      // Await the save so we can react to errors and ensure UI stays consistent
      await controller.saveTicketStatus(context);
    } catch (e, st) {
      debugPrint('save error: $e\n$st');
      Get.snackbar('Save failed', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // IMPORTANT: hide entirely when user doesn't have edit permissions
    // (either admin or assigned technician only should see the save control)
    if (!controller.canEditNotes && !controller.canEditStatus) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      // Use controller.canSave to decide visibility (matches your controller logic)
      if (!controller.canSave) {
        // Hide the button completely when there is nothing to save (or read-only & unchanged)
        return const SizedBox.shrink();
      }

      final bool isSaving = controller.isSaving.value;

      // Colors replaced with Color.fromRGBO equivalents (no deprecated helpers)
      final List<Color> gradientColors = isSaving
          ? [
              const Color.fromRGBO(42, 46, 69, 0.94),
              const Color.fromRGBO(42, 46, 69, 0.98),
            ]
          : (isDark
              ? [
                  const Color.fromRGBO(94, 89, 247, 0.98),
                  const Color.fromRGBO(143, 131, 255, 0.98),
                ]
              : [
                  const Color.fromRGBO(109, 93, 246, 0.98),
                  const Color.fromRGBO(155, 140, 255, 0.98),
                ]);

      final boxShadowColor =
          Color.fromRGBO(123, 108, 255, _pressed ? 0.20 : 0.40);

      return GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          // only trigger when not saving
          if (!isSaving) _onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AbsorbPointer(
          absorbing: isSaving, // prevents gestures while saving
          child: ScaleTransition(
            // subtle pulsing while idle
            scale: Tween<double>(begin: 1.0, end: 1.03).animate(
              CurvedAnimation(parent: _glowPulse, curve: Curves.easeInOut),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              width: double.infinity,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: boxShadowColor,
                    blurRadius: _pressed ? 8 : 22,
                    spreadRadius: _pressed ? 0 : 1.2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        width: 1.2,
                        color: const Color.fromRGBO(255, 255, 255, 0.18),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSaving)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: 0.32,
                              duration: const Duration(milliseconds: 400),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: const Color.fromRGBO(255, 255, 255, 0.04),
                                ),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSaving)
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              ),
                            if (isSaving) const SizedBox(width: 10),
                            Text(
                              isSaving ? 'Saving...' : 'Save Ticket',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.4,
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
          )
              // small entrance animation to match rest of UI
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.25),
        ),
      );
    });
  }
}
