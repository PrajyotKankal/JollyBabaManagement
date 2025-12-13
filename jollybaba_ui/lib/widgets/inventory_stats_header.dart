// lib/widgets/inventory_stats_header.dart
// Stats KPI header row for inventory list page

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InventoryStatsHeader extends StatelessWidget {
  final int totalItems;
  final int availableCount;
  final int soldCount;
  final double totalRevenue;
  final double totalProfit;
  final bool showFinancials;

  const InventoryStatsHeader({
    super.key,
    required this.totalItems,
    required this.availableCount,
    required this.soldCount,
    required this.totalRevenue,
    required this.totalProfit,
    this.showFinancials = true,
  });

  static const _primaryColor = Color(0xFF6D5DF6);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 700;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: isCompact ? 8 : 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            label: 'Total Items',
            value: '$totalItems',
            icon: Icons.inventory_2_rounded,
            color: _primaryColor,
            delay: 0,
          ),
          _buildStatCard(
            label: 'Available',
            value: '$availableCount',
            icon: Icons.check_circle_rounded,
            color: Colors.blue,
            delay: 50,
          ),
          _buildStatCard(
            label: 'Sold',
            value: '$soldCount',
            icon: Icons.sell_rounded,
            color: Colors.orange,
            delay: 100,
          ),
          if (showFinancials) ...[
            _buildStatCard(
              label: 'Revenue',
              value: '₹${_formatCompact(totalRevenue)}',
              icon: Icons.currency_rupee_rounded,
              color: Colors.green,
              delay: 150,
            ),
            _buildStatCard(
              label: 'Profit',
              value: '₹${_formatCompact(totalProfit)}',
              icon: Icons.trending_up_rounded,
              color: totalProfit >= 0 ? Colors.teal : Colors.red,
              delay: 200,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  String _formatCompact(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
