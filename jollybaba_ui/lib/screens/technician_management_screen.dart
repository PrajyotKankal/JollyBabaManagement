import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/ticket_service.dart';
import '../utils/responsive_helper.dart';
import 'login_screen.dart';
import 'technician_report_screen.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  static const _adminEmail = 'admin@jollybaba.com';
  static const _googleAdminEmail = 'jollybaba30@gmail.com';
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _technicians = [];

  // overall ticket stats for management overview
  int _overallTotal = 0;
  int _overallPending = 0;
  int _overallCompleted = 0;

  // form controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
    _loadOverallTicketStats();
  }

  Future<void> _loadTechnicians() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final response = await _authService.getWithAuth("/technicians", token);
      setState(() {
        final rows = <Map<String, dynamic>>[];
        for (final entry in (response['technicians'] as List? ?? const [])) {
          if (entry is Map) {
            final map = Map<String, dynamic>.from(entry);
            final email = (map['email'] ?? '').toString().toLowerCase();
            if (email == _adminEmail || email == _googleAdminEmail) continue;
            rows.add(map);
          }
        }
        _technicians = rows;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching technicians: $e");
      setState(() => _isLoading = false);
      // DON'T auto-logout on errors - just show error message
      Get.snackbar("Error", e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          colorText: Colors.white);
    }
  }

  Future<void> _loadOverallTicketStats() async {
    try {
      final tickets = await TicketService.fetchTickets(
        page: 1,
        perPage: 500,
        mineOnly: false,
      );

      int pending = 0;
      int completed = 0;

      for (final t in tickets) {
        final norm = (t['status_normalized'] ?? '').toString();
        if (norm == 'pending') {
          pending++;
        } else if (norm == 'repaired' || norm == 'delivered') {
          completed++;
        }
      }

      // Define Total as Completed + Pending so chips always add up
      final total = pending + completed;

      if (!mounted) return;
      setState(() {
        _overallTotal = total;
        _overallPending = pending;
        _overallCompleted = completed;
      });
    } catch (e) {
      debugPrint('❌ Error loading overall ticket stats: $e');
    }
  }

  Future<void> _createTechnician() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      Get.snackbar("Incomplete Form", "Please fill all required fields.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white);
      return;
    }

    try {
      Get.back(); // close dialog
      setState(() => _isLoading = true);

      await _authService.createTechnician(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      Get.snackbar("Success", "Technician created successfully!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white);

      _clearForm();
      await _loadTechnicians();
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar("Error", e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          colorText: Colors.white);
    }
  }

  Future<void> _deleteTechnician(Map<String, dynamic> tech) async {
    final email = (tech['email'] ?? '').toString().toLowerCase();
    if (email == _adminEmail) {
      Get.snackbar("Protected", "The primary admin account cannot be deleted.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white);
      return;
    }

    final id = tech['id'];
    if (id == null) return;

    Get.defaultDialog(
      title: "Delete Technician",
      middleText: "Are you sure you want to delete this technician?",
      textCancel: "Cancel",
      textConfirm: "Delete",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        Get.back();
        try {
          final token = await _authService.getToken();
          await _authService.deleteWithAuth("/technicians/$id", token);
          Get.snackbar("Deleted", "Technician removed successfully",
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              colorText: Colors.white);
          await _loadTechnicians();
        } catch (e) {
          Get.snackbar("Error", e.toString(),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              colorText: Colors.white);
        }
      },
    );
  }

  void _clearForm() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _passwordCtrl.clear();
    _phoneCtrl.clear();
  }

  void _openCreateDialog() {
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Add Technician",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2A2E45))),
                const SizedBox(height: 14),
                _buildInput("Full Name", _nameCtrl, Icons.person),
                _buildInput("Email", _emailCtrl, Icons.email),
                _buildInput("Password", _passwordCtrl, Icons.lock,
                    obscure: true),
                _buildInput("Phone", _phoneCtrl, Icons.phone),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text("Save Technician",
                      style: GoogleFonts.poppins(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D5DF6),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _createTechnician,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6)),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E6EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6D5DF6), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final responsivePadding = deviceType == DeviceType.mobile ? 14.0 : deviceType == DeviceType.tablet ? 18.0 : 24.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          "Technicians",
          style: GoogleFonts.poppins(
            color: const Color(0xFF2A2E45),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2A2E45), size: 20),
          onPressed: () => Get.offAllNamed('/admin'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6D5DF6),
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add Technician"),
        onPressed: _openCreateDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadTechnicians();
                await _loadOverallTicketStats();
              },
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: responsivePadding, vertical: 10),
                children: [
                  _buildOverallStatsCard(deviceType),
                  const SizedBox(height: 12),
                  ..._technicians.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tech = entry.value;
                    return _buildTechnicianCard(tech, deviceType)
                        .animate(delay: (index * 100).ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.15, curve: Curves.easeOut);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallStatsCard(DeviceType deviceType) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Ticket Overview',
              style: GoogleFonts.poppins(
                fontSize: deviceType == DeviceType.mobile ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A2E45),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip('Total', _overallTotal.toString(), const Color(0xFF1E88E5)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip('Completed', _overallCompleted.toString(), const Color(0xFF43A047)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip('Pending', _overallPending.toString(), const Color(0xFFEF6C00)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: color.withOpacity(0.9)),
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

  Widget _buildTechnicianCard(Map<String, dynamic> tech, DeviceType deviceType) {
    final titleFontSize = deviceType == DeviceType.mobile ? 14.0 : 15.0;
    final subtitleFontSize = deviceType == DeviceType.mobile ? 11.0 : 12.0;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: deviceType == DeviceType.mobile ? 6 : 8),
      elevation: 3,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: deviceType == DeviceType.mobile ? 14 : 18,
          vertical: deviceType == DeviceType.mobile ? 10 : 12,
        ),
        leading: CircleAvatar(
          radius: deviceType == DeviceType.mobile ? 20 : 22,
          backgroundColor: const Color(0xFF6D5DF6).withOpacity(0.15),
          child: Icon(Icons.engineering_rounded,
              color: const Color(0xFF6D5DF6), 
              size: deviceType == DeviceType.mobile ? 20 : 22),
        ),
        title: Text(
          tech['name'] ?? 'Unnamed',
          style: GoogleFonts.poppins(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          tech['email'] ?? '',
          style: GoogleFonts.poppins(fontSize: subtitleFontSize, color: Colors.black54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Get.to(
            () => TechnicianReportScreen(technician: tech),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 350),
          );
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
          onPressed: () => _deleteTechnician(tech),
          iconSize: deviceType == DeviceType.mobile ? 20 : 24,
        ),
      ),
    );
  }
}
