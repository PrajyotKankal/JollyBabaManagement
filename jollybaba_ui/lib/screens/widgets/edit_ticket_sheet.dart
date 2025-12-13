import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../ticket_details_controller.dart';

class EditTicketSheet extends StatefulWidget {
  final TicketDetailsController controller;
  const EditTicketSheet({super.key, required this.controller});

  @override
  State<EditTicketSheet> createState() => _EditTicketSheetState();
}

class _EditTicketSheetState extends State<EditTicketSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _deviceCtrl;
  late final TextEditingController _imeiCtrl;
  late final TextEditingController _receiveDateCtrl;
  late final TextEditingController _repairDateCtrl;
  late final TextEditingController _issueCtrl;
  late final TextEditingController _assignedCtrl;
  late final TextEditingController _assignedEmailCtrl;
  late final TextEditingController _estimatedCostCtrl;
  late final TextEditingController _lockCodeCtrl;

  bool _submitting = false;

  Map<String, dynamic> get ticket => widget.controller.ticket;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _ticketString('customer_name'));
    _mobileCtrl = TextEditingController(text: _ticketString('mobile_number'));
    _deviceCtrl = TextEditingController(text: _ticketString('device_model'));
    _imeiCtrl = TextEditingController(text: _ticketString('imei'));
    _receiveDateCtrl = TextEditingController(text: _formatDateField('receive_date'));
    _repairDateCtrl = TextEditingController(text: _formatDateField('repair_date'));
    _issueCtrl = TextEditingController(text: _ticketString('issue_description'));
    _assignedCtrl = TextEditingController(text: widget.controller.assignedTechnician.isNotEmpty
        ? widget.controller.assignedTechnician
        : _ticketString('assigned_technician'));
    _assignedEmailCtrl = TextEditingController(text: _ticketString('assigned_technician_email'));
    _estimatedCostCtrl = TextEditingController(text: _ticketString('estimated_cost'));
    _lockCodeCtrl = TextEditingController(text: _ticketString('lock_code'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _deviceCtrl.dispose();
    _imeiCtrl.dispose();
    _receiveDateCtrl.dispose();
    _repairDateCtrl.dispose();
    _issueCtrl.dispose();
    _assignedCtrl.dispose();
    _assignedEmailCtrl.dispose();
    _estimatedCostCtrl.dispose();
    _lockCodeCtrl.dispose();
    super.dispose();
  }

  String _ticketString(String key) => (ticket[key] ?? '').toString();

  String _formatDateField(String key) {
    final raw = ticket[key];
    if (raw == null) return '';
    final value = raw.toString();
    if (value.isEmpty) return '';
    try {
      return DateTime.parse(value).toIso8601String().split('T').first;
    } catch (_) {
      return value.split('T').first;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.trim().isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _handleSave() async {
    if (_submitting) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Get.snackbar(
        'Name required',
        'Customer name cannot be empty.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final payload = <String, dynamic>{};
    void setIfChanged(String key, String value) {
      final current = (ticket[key] ?? '').toString();
      if (current != value) {
        payload[key] = value.isEmpty ? null : value;
      }
    }

    setIfChanged('customer_name', name);
    setIfChanged('mobile_number', _mobileCtrl.text.trim());
    setIfChanged('device_model', _deviceCtrl.text.trim());
    setIfChanged('imei', _imeiCtrl.text.trim());
    setIfChanged('issue_description', _issueCtrl.text.trim());
    setIfChanged('assigned_technician', _assignedCtrl.text.trim());
    setIfChanged('assigned_to', _assignedCtrl.text.trim());
    setIfChanged('assigned_technician_email', _assignedEmailCtrl.text.trim());
    setIfChanged('assigned_to_email', _assignedEmailCtrl.text.trim());
    setIfChanged('estimated_cost', _estimatedCostCtrl.text.trim());
    setIfChanged('lock_code', _lockCodeCtrl.text.trim());
    setIfChanged('receive_date', _receiveDateCtrl.text.trim());
    setIfChanged('repair_date', _repairDateCtrl.text.trim());

    if (payload.isEmpty) {
      Get.snackbar(
        'No changes',
        'Update any field to save.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _submitting = true);
    final success = await widget.controller.updateTicketDetails(
      payload,
      auditNote: 'Ticket details edited',
    );
    setState(() => _submitting = false);

    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Edit Ticket',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Customer Information'),
                      _textField('Customer Name', _nameCtrl, required: true),
                      _textField('Mobile Number', _mobileCtrl, keyboard: TextInputType.phone),
                      _textField('Device Model', _deviceCtrl),
                      _textField('IMEI', _imeiCtrl),
                      _dateField('Receive Date', _receiveDateCtrl),
                      _dateField('Repair Date', _repairDateCtrl),
                      _multilineField('Issue Description', _issueCtrl),
                      const SizedBox(height: 12),
                      _sectionTitle('Repair Details'),
                      _textField('Assigned Technician', _assignedCtrl),
                      _textField('Assigned Technician Email', _assignedEmailCtrl,
                          keyboard: TextInputType.emailAddress),
                      _textField('Estimated Cost', _estimatedCostCtrl, keyboard: TextInputType.number),
                      _textField('Lock Code', _lockCodeCtrl),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D5DF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2E45),
          ),
        ),
      );

  Widget _textField(String label, TextEditingController controller,
      {bool required = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (required ? ' *' : ''),
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multilineField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickDate(controller),
            child: AbsorbPointer(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
