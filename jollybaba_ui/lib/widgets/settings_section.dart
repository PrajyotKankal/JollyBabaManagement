// lib/widgets/settings_section.dart
// Grouped section container for settings items

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final int animationDelay;
  final Color? accentColor;

  const SettingsSection({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.animationDelay = 0,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: accentColor ?? Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor ?? Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        
        // Section card container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: _buildChildrenWithDividers(),
            ),
          ),
        ),
      ],
    ).animate(delay: animationDelay.ms)
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  List<Widget> _buildChildrenWithDividers() {
    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey.shade200,
            indent: 56,
          ),
        );
      }
    }
    return result;
  }
}
