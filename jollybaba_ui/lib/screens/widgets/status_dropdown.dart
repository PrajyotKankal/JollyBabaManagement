// lib/screens/widgets/status_dropdown.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ticket_details_controller.dart';

class StatusDropdown extends StatefulWidget {
  final TicketDetailsController controller;
  const StatusDropdown({super.key, required this.controller});

  @override
  State<StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<StatusDropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<Color> _getStatusGradient(String status) {
    final s = status.toLowerCase();
    if (s.contains('deliver')) {
      return [
        const Color.fromRGBO(86, 171, 47, 0.12), // soft green start
        const Color.fromRGBO(168, 224, 99, 0.30), // soft green end
      ];
    } else if (s.contains('repair')) {
      return [
        const Color.fromRGBO(109, 93, 246, 0.12), // purple start
        const Color.fromRGBO(157, 139, 254, 0.25), // purple end
      ];
    } else if (s.contains('cancel')) {
      return [
        const Color.fromRGBO(255, 75, 43, 0.10), // red start
        const Color.fromRGBO(255, 107, 107, 0.22), // red end
      ];
    } else {
      return [
        const Color.fromRGBO(204, 204, 204, 0.08), // grey soft
        const Color.fromRGBO(255, 255, 255, 0.7), // white-ish
      ];
    }
  }

  Widget decoratedChild({required Widget child, required List<Color> gradient}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradient[0], gradient[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep options Title-case to match controller.status (which is Title-case)
    final List<String> statusOptions = [
      "Pending",
      "Repaired",
      "Delivered",
      "Cancelled",
    ];

    // Controller exposes Title-case status
    final currentStatus = widget.controller.status;
    // readOnly when either server saved status is read-only OR user lacks permission to edit status
    final readOnly = widget.controller.savedIsReadOnly || !widget.controller.canEditStatus;

    final gradient = _getStatusGradient(currentStatus);

    // Start/stop pulse depending on editability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!readOnly) {
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      } else {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });

    // When read-only we show a non-interactive display to avoid dropdown errors
    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Status",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF2A2E45),
              ),
            ),
            const SizedBox(height: 8),
            ScaleTransition(
              scale: _pulseAnim,
              child: decoratedChild(
                gradient: gradient,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // small colored dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: gradient[1],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currentStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // show a subtle lock icon to indicate read-only or lack of permission
                      const Icon(Icons.lock_outline, size: 18, color: Colors.black38),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),
          ],
        ),
      );
    }

    // Editable dropdown
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Status",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: const Color(0xFF2A2E45),
            ),
          ),
          const SizedBox(height: 8),
          ScaleTransition(
            scale: _pulseAnim,
            child: decoratedChild(
              gradient: gradient,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: statusOptions.contains(currentStatus) ? currentStatus : statusOptions[0],
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  icon: const SizedBox(), // keep UI minimal (no arrow)
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  items: statusOptions
                      .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(s,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    // Guard again (defensive): ensure controller says editing is allowed
                    if (!widget.controller.canEditStatus) {
                      // silently ignore or show a small feedback; do nothing for now
                      return;
                    }
                    widget.controller.updateStatus(v);
                    // trigger brief pulse
                    _pulseController.forward(from: 0);
                    setState(() {});
                  },
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.12),
        ],
      ),
    );
  }
}
