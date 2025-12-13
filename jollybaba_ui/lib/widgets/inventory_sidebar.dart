// lib/widgets/inventory_sidebar.dart
// Premium glassmorphism sidebar for Inventory Management

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InventorySidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool showReports;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const InventorySidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.showReports = true,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  static const _primaryColor = Color(0xFF6D5DF6);

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(icon: Icons.sell_rounded, label: 'Sell', index: 1),
      _SidebarItem(icon: Icons.table_rows_rounded, label: 'List', index: 2),
      _SidebarItem(icon: Icons.add_box_rounded, label: 'Add Stock', index: 3),
      if (showReports)
        _SidebarItem(icon: Icons.insights_rounded, label: 'Reports', index: 4),
    ];

    return Container(
      width: isCollapsed ? 72 : 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 16,
              vertical: 20,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Inventory',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2343),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isSelected = selectedIndex == item.index;
                
                return _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  isCollapsed: isCollapsed,
                  onTap: () => onItemSelected(item.index),
                  delay: i * 50,
                );
              },
            ),
          ),

          // Collapse toggle
          if (onToggleCollapse != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                onPressed: onToggleCollapse,
                icon: Icon(
                  isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  color: Colors.grey.shade500,
                ),
                tooltip: isCollapsed ? 'Expand' : 'Collapse',
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1);
  }

  Widget _buildNavItem({
    required _SidebarItem item,
    required bool isSelected,
    required bool isCollapsed,
    required VoidCallback onTap,
    required int delay,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: _primaryColor.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: _primaryColor.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? _primaryColor : Colors.grey.shade600,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? _primaryColor : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: delay.ms).fadeIn().slideX(begin: -0.2);
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final int index;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
