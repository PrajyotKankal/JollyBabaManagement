// lib/widgets/settings_profile_card.dart
// Premium profile header card for settings screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsProfileCard extends StatefulWidget {
  final String userName;
  final String role;
  final String? avatarUrl;
  final int ticketsToday;
  final int pendingCount;
  final Color primaryColor;
  final VoidCallback? onTap;

  const SettingsProfileCard({
    super.key,
    required this.userName,
    required this.role,
    this.avatarUrl,
    this.ticketsToday = 0,
    this.pendingCount = 0,
    this.primaryColor = const Color(0xFF6D5DF6),
    this.onTap,
  });

  @override
  State<SettingsProfileCard> createState() => _SettingsProfileCardState();
}

class _SettingsProfileCardState extends State<SettingsProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role.toLowerCase() == 'admin';
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.primaryColor.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Animated avatar with gradient ring
                _buildAvatar(isAdmin),
                const SizedBox(width: 16),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2343),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAdmin 
                              ? widget.primaryColor.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdmin ? Icons.verified_rounded : Icons.engineering_rounded,
                              size: 12,
                              color: isAdmin ? widget.primaryColor : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.role,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAdmin ? widget.primaryColor : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Quick stats
                      Row(
                        children: [
                          _buildStat(
                            '${widget.ticketsToday}',
                            'Today',
                            Icons.confirmation_number_outlined,
                          ),
                          const SizedBox(width: 16),
                          _buildStat(
                            '${widget.pendingCount}',
                            'Pending',
                            Icons.pending_outlined,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: -0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildAvatar(bool isAdmin) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                widget.primaryColor,
                widget.primaryColor.withOpacity(0.3),
                widget.primaryColor,
              ],
              transform: GradientRotation(_ringController.value * 6.28),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: widget.primaryColor.withOpacity(0.1),
              backgroundImage: widget.avatarUrl != null 
                  ? NetworkImage(widget.avatarUrl!) 
                  : null,
              child: widget.avatarUrl == null
                  ? Text(
                      widget.userName.isNotEmpty 
                          ? widget.userName[0].toUpperCase() 
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: widget.primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String value, String label, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? const Color(0xFF1E2343),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
