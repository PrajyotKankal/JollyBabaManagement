import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Premium glassmorphic stats header for Khatabook - Mobile optimized
class KhatabookStatsHeader extends StatelessWidget {
  final double totalAmount;
  final double totalReceived;
  final double totalPending;
  final int customerCount;
  final Color primaryColor;

  const KhatabookStatsHeader({
    super.key,
    required this.totalAmount,
    required this.totalReceived,
    required this.totalPending,
    this.customerCount = 0,
    this.primaryColor = const Color(0xFF6D5DF6),
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final percentage = totalAmount > 0 ? (totalReceived / totalAmount * 100).clamp(0, 100) : 0.0;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.15),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Total',
                      value: currency.format(totalAmount),
                      color: primaryColor,
                      isMobile: isMobile,
                    )),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Received',
                      value: currency.format(totalReceived),
                      color: const Color(0xFF4CAF50),
                      isMobile: isMobile,
                    )),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatCard(
                      icon: Icons.pending_rounded,
                      label: 'Pending',
                      value: currency.format(totalPending),
                      color: const Color(0xFFFF6B6B),
                      isMobile: isMobile,
                    )),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$customerCount customers',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(0)}% collected',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          // FittedBox to auto-scale the amount to fit
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E2343),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
