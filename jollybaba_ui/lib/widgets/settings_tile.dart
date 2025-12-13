// lib/widgets/settings_tile.dart
// Individual setting row with icon, text, and trailing widget

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isDanger;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = const Color(0xFF6D5DF6),
    this.iconBackgroundColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDanger = false,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.isDanger ? Colors.red : widget.iconColor;
    final effectiveBgColor = widget.iconBackgroundColor ?? 
        effectiveIconColor.withOpacity(0.1);

    return Material(
      color: _isPressed ? Colors.grey.shade50 : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _isPressed = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(width: 14),
              
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.isDanger 
                            ? Colors.red 
                            : const Color(0xFF1E2343),
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Trailing widget or chevron
              if (widget.trailing != null)
                widget.trailing!
              else if (widget.showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A toggle variant of SettingsTile with a switch
class SettingsToggleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = const Color(0xFF0D7C4A),
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      showChevron: false,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: iconColor,
      ),
      onTap: () => onChanged(!value),
    );
  }
}
