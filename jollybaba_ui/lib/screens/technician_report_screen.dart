// lib/screens/technician_report_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ticket_service.dart';
import '../utils/responsive_helper.dart';

class TechnicianReportScreen extends StatefulWidget {
  const TechnicianReportScreen({super.key, required this.technician});

  final Map<String, dynamic> technician;

  @override
  State<TechnicianReportScreen> createState() => _TechnicianReportScreenState();
}

class _TechnicianReportScreenState extends State<TechnicianReportScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  // Filters
  final List<String> _statuses = ['All', 'Pending', 'Repaired', 'Delivered', 'Cancelled'];
  String _selectedStatus = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildFilters(DeviceType deviceType) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: deviceType == DeviceType.mobile ? 12 : 14,
          vertical: deviceType == DeviceType.mobile ? 8 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.poppins(
                    fontSize: deviceType == DeviceType.mobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = 'All';
                      _fromDate = null;
                      _toDate = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('Reset', style: GoogleFonts.poppins(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF6D5DF6)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            deviceType == DeviceType.mobile
                ? Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _statuses
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s, style: GoogleFonts.poppins(fontSize: 12)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedStatus = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildDateField(
                        label: 'From',
                        date: _fromDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fromDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _fromDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildDateField(
                        label: 'To',
                        date: _toDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _toDate = picked);
                          }
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _statuses
                              .map((s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s, style: GoogleFonts.poppins(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedStatus = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDateField(
                          label: 'From',
                          date: _fromDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fromDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _fromDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDateField(
                          label: 'To',
                          date: _toDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _toDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required DateTime? date, required VoidCallback onTap}) {
    final text = date == null
        ? ''
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          text.isEmpty ? 'Any' : text,
          style: GoogleFonts.poppins(fontSize: 12, color: text.isEmpty ? Colors.black38 : Colors.black87),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> tickets) {
    final String statusFilter = _selectedStatus.toLowerCase();

    return tickets.where((t) {
      // Status filter
      if (statusFilter != 'all') {
        final norm = (t['status_normalized'] ?? '').toString();
        if (norm != statusFilter.toLowerCase()) return false;
      }

      // Date range filter (by receive_date)
      if (_fromDate != null || _toDate != null) {
        final raw = (t['receive_date'] ?? t['receiveDate'] ?? '').toString();
        DateTime? d;
        if (raw.isNotEmpty) {
          d = DateTime.tryParse(raw);
        }
        if (d == null) return false;

        if (_fromDate != null && d.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
          return false;
        }
        if (_toDate != null && d.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final email = (widget.technician['email'] ?? '').toString();
      final list = await TicketService.fetchTicketsForTechnician(email: email);
      setState(() {
        _tickets = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      Get.snackbar('Technician Report', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final responsivePadding = deviceType == DeviceType.mobile ? 14.0 : deviceType == DeviceType.tablet ? 16.0 : 20.0;
    
    final tech = widget.technician;
    final name = (tech['name'] ?? '').toString();
    final email = (tech['email'] ?? '').toString();

    final filtered = _applyFilters(_tickets);

    final total = filtered.length;
    int pending = 0;
    int repaired = 0;
    int delivered = 0;
    int cancelled = 0;

    for (final t in filtered) {
      final norm = (t['status_normalized'] ?? '').toString();
      if (norm == 'pending') {
        pending++;
      } else if (norm == 'repaired') {
        repaired++;
      } else if (norm == 'delivered') {
        delivered++;
      } else if (norm == 'cancelled') {
        cancelled++;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          'Technician Report',
          style: GoogleFonts.poppins(
            color: const Color(0xFF2A2E45),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2A2E45), size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(responsivePadding),
                children: [
                  _buildHeader(
                    name,
                    email,
                    total,
                    pending: pending,
                    repaired: repaired,
                    delivered: delivered,
                    cancelled: cancelled,
                    deviceType: deviceType,
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'No tickets assigned to this technician yet.',
                          style: GoogleFonts.poppins(color: Colors.black54),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((t) => _buildTicketCard(t, deviceType)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(
    String name,
    String email,
    int total, {
    required int pending,
    required int repaired,
    required int delivered,
    required int cancelled,
    required DeviceType deviceType,
  }) {
    final avatarRadius = deviceType == DeviceType.mobile ? 22.0 : 26.0;
    final avatarFontSize = deviceType == DeviceType.mobile ? 18.0 : 20.0;
    final nameFontSize = deviceType == DeviceType.mobile ? 15.0 : 16.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 14 : 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: const Color(0xFF6D5DF6).withOpacity(0.12),
              child: Text(
                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6D5DF6),
                  fontSize: avatarFontSize,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Unnamed technician' : name,
                    style: GoogleFonts.poppins(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, {required Color color}) {
    // Simple non-flex chip container
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: color.withOpacity(0.85)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, DeviceType deviceType) {
    final status = (ticket['status_title'] ?? ticket['status'] ?? '').toString();
    final model = (ticket['device_model'] ?? '').toString();
    final issue = (ticket['issue_description'] ?? '').toString();
    final customer = (ticket['customer_name'] ?? '').toString();
    final amount = (ticket['estimated_cost'] ?? '').toString();
    final receiveDate = (ticket['receive_date'] ?? ticket['receiveDate'] ?? '').toString();

    return Card(
      margin: EdgeInsets.symmetric(vertical: deviceType == DeviceType.mobile ? 5 : 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.isEmpty ? 'Unknown device' : model,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.isEmpty ? '-' : status,
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.blueGrey.shade800),
                  ),
                ),
              ],
            ),
            if (issue.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                issue,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (customer.isNotEmpty)
                  Text(
                    'Customer: $customer',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                  ),
                if (amount.isNotEmpty)
                  Text(
                    'Amount: $amount',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                  ),
                if (receiveDate.isNotEmpty)
                  Text(
                    'Received: $receiveDate',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
