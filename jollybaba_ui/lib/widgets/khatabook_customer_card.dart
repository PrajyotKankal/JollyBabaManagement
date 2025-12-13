import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Premium glassmorphic customer card for Khatabook - Mobile optimized
class KhatabookCustomerCard extends StatelessWidget {
  final String name;
  final String mobile;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final int entryCount;
  final bool isSettled;
  final VoidCallback? onTap;
  final Color primaryColor;

  const KhatabookCustomerCard({
    super.key,
    required this.name,
    required this.mobile,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.entryCount,
    this.isSettled = false,
    this.onTap,
    this.primaryColor = const Color(0xFF6D5DF6),
  });

  String _formatCompact(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final percentage = totalAmount > 0 ? (paidAmount / totalAmount * 100).clamp(0, 100) : 0.0;
    final displayName = name.isEmpty ? 'Unknown' : name;
    final initial = (displayName.isNotEmpty ? displayName[0] : '?').toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        splashColor: primaryColor.withOpacity(0.1),
        highlightColor: primaryColor.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
            border: Border.all(
              color: isSettled 
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : Colors.grey.shade100,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (!isSettled)
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with gradient ring
              Container(
                width: isMobile ? 44 : 52,
                height: isMobile ? 44 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSettled
                        ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                        : [primaryColor, primaryColor.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSettled ? const Color(0xFF4CAF50) : primaryColor).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: isMobile ? 10 : 14),
              
              // Name, mobile and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2343),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (mobile.isNotEmpty)
                          Flexible(
                            child: Text(
                              mobile,
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (mobile.isNotEmpty)
                          Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: isMobile ? 11 : 12),
                          ),
                        Text(
                          '$entryCount ${entryCount == 1 ? 'item' : 'items'}',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress mini bar
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          width: isMobile ? 70 : 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 4,
                          width: (isMobile ? 70 : 100) * (percentage / 100),
                          decoration: BoxDecoration(
                            color: isSettled 
                                ? const Color(0xFF4CAF50)
                                : primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Amount and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSettled)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: isMobile ? 12 : 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Paid',
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatCompact(remainingAmount),
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(width: isMobile ? 4 : 6),
              
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: isMobile ? 20 : 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
