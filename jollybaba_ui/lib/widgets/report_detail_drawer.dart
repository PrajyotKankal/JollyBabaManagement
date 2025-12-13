// lib/widgets/report_detail_drawer.dart
// Premium detail drawer/bottom sheet for report rows

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportDetailDrawer extends StatelessWidget {
  final Map<String, dynamic> data;
  final String type; // 'ticket', 'khata', 'customer'
  final Color primaryColor;
  final VoidCallback? onClose;

  const ReportDetailDrawer({
    super.key,
    required this.data,
    required this.type,
    this.primaryColor = const Color(0xFF6D5DF6),
    this.onClose,
  });

  static void showAsBottomSheet(
    BuildContext context, {
    required Map<String, dynamic> data,
    required String type,
    Color primaryColor = const Color(0xFF0D7C4A),
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: ReportDetailDrawer(
              data: data,
              type: type,
              primaryColor: primaryColor,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          _buildHeader(),
          
          const SizedBox(height: 20),
          
          // Quick Actions
          _buildQuickActions(context),
          
          const SizedBox(height: 24),
          
          // Details
          ..._buildDetails(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    String subtitle = '';
    IconData icon = Icons.info_rounded;
    Color statusColor = Colors.grey;
    String statusText = '';

    switch (type) {
      case 'ticket':
        title = data['customer_name']?.toString() ?? 'Customer';
        subtitle = data['device_model']?.toString() ?? 'Device';
        icon = Icons.confirmation_number_rounded;
        final status = data['status']?.toString().toLowerCase() ?? 'pending';
        statusColor = status == 'pending' ? Colors.orange 
            : status == 'repaired' ? Colors.blue
            : status == 'delivered' ? Colors.green
            : Colors.red;
        statusText = status[0].toUpperCase() + status.substring(1);
        break;
      case 'khata':
        title = data['name']?.toString() ?? 'Customer';
        subtitle = 'Khata Entry';
        icon = Icons.menu_book_rounded;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final paid = (data['paid'] as num?)?.toDouble() ?? 0;
        final isSettled = (amount - paid) <= 0;
        statusColor = isSettled ? Colors.green : Colors.orange;
        statusText = isSettled ? 'Settled' : 'Pending';
        break;
      case 'customer':
        title = data['name']?.toString() ?? 'Customer';
        subtitle = data['phone']?.toString() ?? 'No phone';
        icon = Icons.person_rounded;
        final sources = (data['source'] as List?)?.join(', ') ?? '';
        statusText = sources.isNotEmpty ? sources : 'Customer';
        statusColor = primaryColor;
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E2343),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            statusText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1);
  }

  Widget _buildQuickActions(BuildContext context) {
    final phone = data['mobile_number']?.toString() 
        ?? data['mobile']?.toString() 
        ?? data['phone']?.toString();

    return Row(
      children: [
        if (phone != null && phone.isNotEmpty) ...[
          _actionButton(
            icon: Icons.call_rounded,
            label: 'Call',
            color: Colors.green,
            onTap: () => _launchPhone(phone),
          ),
          const SizedBox(width: 10),
          _actionButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => _launchWhatsApp(phone),
          ),
          const SizedBox(width: 10),
        ],
        _actionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          color: Colors.blue,
          onTap: () => _shareDetails(context),
        ),
      ],
    ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetails() {
    final List<_DetailItem> items = [];

    switch (type) {
      case 'ticket':
        items.addAll([
          _DetailItem('Ticket ID', '#${data['id']}', Icons.tag),
          _DetailItem('Customer', data['customer_name']?.toString() ?? '-', Icons.person_outline),
          _DetailItem('Phone', data['mobile_number']?.toString() ?? '-', Icons.phone_outlined),
          _DetailItem('Device', data['device_model']?.toString() ?? '-', Icons.phone_android_outlined),
          _DetailItem('Issue', data['issue_description']?.toString() ?? '-', Icons.build_outlined),
          _DetailItem('Status', data['status']?.toString() ?? 'Pending', Icons.flag_outlined),
          _DetailItem('Assigned To', data['assigned_technician']?.toString() ?? '-', Icons.engineering_outlined),
          _DetailItem('Est. Cost', data['estimated_cost'] != null ? '₹${data['estimated_cost']}' : '-', Icons.currency_rupee_outlined),
          if (data['created_at'] != null)
            _DetailItem('Created', _formatDate(data['created_at']), Icons.calendar_today_outlined),
        ]);
        break;
      case 'khata':
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final paid = (data['paid'] as num?)?.toDouble() ?? 0;
        final remaining = amount - paid;
        items.addAll([
          _DetailItem('Name', data['name']?.toString() ?? '-', Icons.person_outline),
          _DetailItem('Mobile', data['mobile']?.toString() ?? '-', Icons.phone_outlined),
          _DetailItem('Total Amount', '₹${amount.toStringAsFixed(0)}', Icons.currency_rupee_outlined),
          _DetailItem('Paid', '₹${paid.toStringAsFixed(0)}', Icons.check_circle_outline),
          _DetailItem('Remaining', '₹${remaining.toStringAsFixed(0)}', Icons.pending_outlined, 
              remaining > 0 ? Colors.orange : Colors.green),
          _DetailItem('Description', data['description']?.toString() ?? '-', Icons.notes_outlined),
          if (data['entryDate'] != null)
            _DetailItem('Date', _formatDate(data['entryDate']), Icons.calendar_today_outlined),
        ]);
        break;
      case 'customer':
        items.addAll([
          _DetailItem('Name', data['name']?.toString() ?? '-', Icons.person_outline),
          _DetailItem('Phone', data['phone']?.toString() ?? '-', Icons.phone_outlined),
          _DetailItem('Tickets', '${data['ticketCount'] ?? 0}', Icons.confirmation_number_outlined),
          _DetailItem('Purchases', '${data['purchaseCount'] ?? 0}', Icons.shopping_bag_outlined),
          _DetailItem('Total Spent', '₹${((data['totalSpent'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', Icons.currency_rupee_outlined),
          _DetailItem('Khata Entries', '${data['khataCount'] ?? 0}', Icons.menu_book_outlined),
          _DetailItem('Source', (data['source'] as List?)?.join(', ') ?? '-', Icons.source_outlined),
          if (data['lastActivity'] != null)
            _DetailItem('Last Activity', _formatDate(data['lastActivity']), Icons.access_time_outlined),
        ]);
        break;
    }

    return items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return _detailRow(item.label, item.value, item.icon, item.valueColor)
          .animate(delay: (150 + i * 50).ms)
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.1);
    }).toList();
  }

  Widget _detailRow(String label, String value, IconData icon, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: valueColor ?? const Color(0xFF1E2343),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Remove non-digits and add country code if needed
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
    
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareDetails(BuildContext context) {
    // Build a text summary of the details
    final StringBuffer sb = StringBuffer();
    
    switch (type) {
      case 'ticket':
        sb.writeln('🎫 Ticket Details');
        sb.writeln('─────────────────');
        sb.writeln('Customer: ${data['customer_name'] ?? '-'}');
        sb.writeln('Device: ${data['device_model'] ?? '-'}');
        sb.writeln('Phone: ${data['mobile_number'] ?? '-'}');
        sb.writeln('Issue: ${data['issue_description'] ?? '-'}');
        sb.writeln('Status: ${data['status'] ?? 'Pending'}');
        sb.writeln('Assigned: ${data['assigned_technician'] ?? '-'}');
        if (data['estimated_cost'] != null) {
          sb.writeln('Est. Cost: ₹${data['estimated_cost']}');
        }
        break;
      case 'khata':
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final paid = (data['paid'] as num?)?.toDouble() ?? 0;
        sb.writeln('📖 Khata Entry');
        sb.writeln('─────────────────');
        sb.writeln('Name: ${data['name'] ?? '-'}');
        sb.writeln('Mobile: ${data['mobile'] ?? '-'}');
        sb.writeln('Total: ₹${amount.toStringAsFixed(0)}');
        sb.writeln('Paid: ₹${paid.toStringAsFixed(0)}');
        sb.writeln('Remaining: ₹${(amount - paid).toStringAsFixed(0)}');
        break;
      case 'customer':
        sb.writeln('👤 Customer Details');
        sb.writeln('─────────────────');
        sb.writeln('Name: ${data['name'] ?? '-'}');
        sb.writeln('Phone: ${data['phone'] ?? '-'}');
        sb.writeln('Tickets: ${data['ticketCount'] ?? 0}');
        sb.writeln('Purchases: ${data['purchaseCount'] ?? 0}');
        break;
    }
    
    sb.writeln('\nShared from JollyBaba App');
    
    // Copy to clipboard and show confirmation
    Clipboard.setData(ClipboardData(text: sb.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Details copied to clipboard!', style: GoogleFonts.poppins()),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  _DetailItem(this.label, this.value, this.icon, [this.valueColor]);
}
