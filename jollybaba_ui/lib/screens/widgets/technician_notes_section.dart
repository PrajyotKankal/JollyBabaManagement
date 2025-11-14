// lib/screens/widgets/technician_notes_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../helpers/extensions.dart';
import '../ticket_details_controller.dart';

class TechnicianNotesSection extends StatefulWidget {
  final TicketDetailsController controller;
  const TechnicianNotesSection({super.key, required this.controller});

  @override
  State<TechnicianNotesSection> createState() => _TechnicianNotesSectionState();
}

class _TechnicianNotesSectionState extends State<TechnicianNotesSection> {
  bool isPressed = false;

  @override
  void dispose() {
    // DO NOT dispose widget.controller.notesController here — it is owned by the controller.
    super.dispose();
  }

  void _handleSend() {
    final controller = widget.controller;
    final text = controller.notesController.text.trim();
    if (text.isEmpty) return;

    // Prevent adding if the user doesn't have permission (defensive)
    if (!controller.canEditNotes) {
      // small feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to add notes.')),
      );
      return;
    }

    // Use controller API to add the note (controller will update UI)
    try {
      controller.addNote();
    } catch (e) {
      // Defensive fallback: update notesList directly if controller.addNote() fails
      final now = DateTime.now();
      try {
        controller.notesList.insert(0, {'text': text, 'time': now});
        controller.update();
      } catch (_) {}
    }

    // Clear the shared controller and unfocus input
    controller.notesController.clear();
    FocusScope.of(context).unfocus();

    // Small local rebuild to update send button press state etc.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final notesList = controller.notesList;

    // Use controller.canEditNotes to allow / disable input and send
    final allowEditing = controller.canEditNotes;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Technician Notes"),

          if (notesList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No notes added yet.",
                style: GoogleFonts.poppins(
                  color: Colors.black45,
                  fontSize: 13,
                ),
              ),
            ),

          if (notesList.isNotEmpty)
            ...notesList.mapIndexed((i, note) {
              final noteText = note["text"]?.toString() ?? "";
              final noteTimeRaw = note["time"];
              final noteTime = noteTimeRaw is DateTime
                  ? noteTimeRaw
                  : DateTime.tryParse(noteTimeRaw?.toString() ?? "") ??
                      DateTime.now();

              return Container(
                key: ValueKey(
                    noteTime.toIso8601String() + noteText.hashCode.toString()),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B61FF).withOpacity(0.10),
                      const Color(0xFFB8A8FF).withOpacity(0.08),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noteText,
                      style: GoogleFonts.poppins(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2A2E45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        DateFormat('MMM d, hh:mm a').format(noteTime),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (i * 80).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutBack);
            }).toList(),

          const Divider(height: 22, thickness: 0.6),

          // If user cannot edit, show a small informative hint above the input
          if (!allowEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.black45),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only the assigned technician or an admin can add notes.',
                      style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Input + Send
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.9),
                    border: Border.all(
                      color: const Color(0xFF6D5DF6).withOpacity(0.15),
                    ),
                  ),
                  child: TextField(
                    controller: controller.notesController,
                    enabled: allowEditing,
                    decoration: InputDecoration(
                      hintText: allowEditing ? "Write a new note..." : "Read-only",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      color: allowEditing ? Colors.black87 : Colors.black45,
                      fontSize: 13.5,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) {
                      // do nothing; allow multiline
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // If editing allowed show the send button, otherwise a locked button
              allowEditing
                  ? GestureDetector(
                      onTapDown: (_) => setState(() => isPressed = true),
                      onTapUp: (_) async {
                        await Future.delayed(const Duration(milliseconds: 100));
                        setState(() => isPressed = false);
                        _handleSend();
                      },
                      onTapCancel: () => setState(() => isPressed = false),
                      child: AnimatedScale(
                        scale: isPressed ? 0.9 : 1.0,
                        duration: 120.ms,
                        curve: Curves.easeOutBack,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7B61FF),
                                Color(0xFF9B8CFF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B61FF).withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    )
                  : Tooltip(
                      message: 'You cannot add notes',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Colors.black38,
                          size: 18,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

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
}
