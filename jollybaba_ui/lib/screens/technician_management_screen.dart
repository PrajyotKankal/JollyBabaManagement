import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  static const _adminEmail = 'admin@jollybaba.com';
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _technicians = [];

  // form controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
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
            if (email != _adminEmail) rows.add(map);
          }
        }
        _technicians = rows;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching technicians: $e");
      setState(() => _isLoading = false);

      if (e.toString().contains("401")) {
        await _authService.logout();
        if (!mounted) return;
        Get.offAll(() => const LoginScreen());
      } else {
        Get.snackbar("Error", e.toString(),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            colorText: Colors.white);
      }
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
          onPressed: () => Get.back(),
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
              onRefresh: _loadTechnicians,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: _technicians.length,
                itemBuilder: (context, index) {
                  final tech = _technicians[index];
                  return _buildTechnicianCard(tech)
                      .animate(delay: (index * 100).ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.15, curve: Curves.easeOut);
                },
              ),
            ),
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> tech) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF6D5DF6).withOpacity(0.15),
          child: const Icon(Icons.engineering_rounded,
              color: Color(0xFF6D5DF6), size: 22),
        ),
        title: Text(
          tech['name'] ?? 'Unnamed',
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        subtitle: Text(
          tech['email'] ?? '',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
          onPressed: () => _deleteTechnician(tech),
        ),
      ),
    );
  }
}
