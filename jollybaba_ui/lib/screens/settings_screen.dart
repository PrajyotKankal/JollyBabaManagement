// 📁 lib/screens/settings_screen.dart
// Premium Settings Screen with sectioned layout and responsive design

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';
import 'technician_management_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../widgets/bottom_glass_navbar.dart';
import 'inventory_management_screen.dart';
import 'khatabook_screen.dart';
import 'about_app_screen.dart';
import 'reports_screen.dart';

// Premium settings widgets
import '../widgets/settings_profile_card.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBottomNav;
  const SettingsScreen({super.key, this.showBottomNav = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? glowController;
  Animation<double>? glowAnimation;
  final AuthService _auth = AuthService();
  
  bool _isAdmin = false;
  String _userName = 'User';
  String _userRole = 'Technician';
  int _ticketsToday = 0;
  int _pendingCount = 0;

  // Theme colors
  static const Color _primaryColor = Color(0xFF6D5DF6);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (widget.showBottomNav) {
      glowController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat(reverse: true);

      glowAnimation = Tween<double>(begin: 0.12, end: 0.45).animate(
        CurvedAnimation(parent: glowController!, curve: Curves.easeInOut),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _auth.getStoredUser();
      if (user != null && mounted) {
        final role = (user['role'] ?? '').toString();
        setState(() {
          _isAdmin = role.toLowerCase() == 'admin';
          _userName = user['name']?.toString() ?? user['email']?.toString() ?? 'User';
          _userRole = _isAdmin ? 'Admin' : 'Technician';
          _ticketsToday = 0;
          _pendingCount = 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;
    final isDesktop = deviceType == DeviceType.desktop;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 18 : 20,
            color: const Color(0xFF1E2343),
          ),
        ),
        leading: widget.showBottomNav
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E2343), size: 20),
                onPressed: () {
                  Get.off(() => const DashboardScreen(),
                      transition: Transition.leftToRight,
                      duration: const Duration(milliseconds: 400));
                },
              )
            : null,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: (widget.showBottomNav &&
              glowController != null &&
              glowAnimation != null)
          ? SafeArea(
              minimum: const EdgeInsets.only(bottom: 2),
              child: BottomGlassNavBar(
                selectedIndex: 1,
                glowController: glowController!,
                glowAnimation: glowAnimation!,
                onItemTapped: (index) {
                  if (index == 0) {
                    Get.off(() => const DashboardScreen(),
                        transition: Transition.leftToRight,
                        duration: const Duration(milliseconds: 400));
                  }
                },
              ),
            )
          : null,
    );
  }

  // MOBILE LAYOUT - Single column list
  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: 8,
            bottom: widget.showBottomNav ? 140 : 40, // Fixed: More padding for navbar
          ),
          children: [
            // Profile Header
            SettingsProfileCard(
              userName: _userName,
              role: _userRole,
              ticketsToday: _ticketsToday,
              pendingCount: _pendingCount,
              primaryColor: _primaryColor,
            ),

            // Management Section
            _buildManagementSection(100),

            // Reports Section (Admin only)
            if (_isAdmin) _buildReportsSection(200),

            // About Section
            _buildAboutSection(_isAdmin ? 300 : 200),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // DESKTOP LAYOUT - Bento grid style
  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Profile + Quick Stats
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile card (takes 2/3)
                  Expanded(
                    flex: 2,
                    child: SettingsProfileCard(
                      userName: _userName,
                      role: _userRole,
                      ticketsToday: _ticketsToday,
                      pendingCount: _pendingCount,
                      primaryColor: _primaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Settings grid - 2 columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      children: [
                        _buildManagementSection(100),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      children: [
                        if (_isAdmin) _buildReportsSection(200),
                        _buildAboutSection(_isAdmin ? 300 : 200),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementSection(int delay) {
    return SettingsSection(
      title: 'Management',
      icon: Icons.settings_outlined,
      animationDelay: delay,
      children: [
        SettingsTile(
          title: 'Inventory',
          subtitle: 'Manage stock & spare parts',
          icon: Icons.inventory_2_rounded,
          iconColor: const Color(0xFF8A7CFF),
          onTap: () {
            debugPrint('Navigating to Inventory');
            Get.to(() => InventoryManagementScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 400));
          },
        ),
        SettingsTile(
          title: 'Technicians',
          subtitle: 'Create & manage technicians',
          icon: Icons.engineering_rounded,
          iconColor: const Color(0xFF6D5DF6),
          onTap: () {
            debugPrint('Navigating to Technicians');
            Get.to(() => const TechniciansScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 400));
          },
        ),
        SettingsTile(
          title: 'Khatabook',
          subtitle: 'Credits, cash, and settlements',
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFF00C6FF),
          onTap: () {
            debugPrint('Navigating to Khatabook');
            Get.to(() => const KhatabookScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 400));
          },
        ),
      ],
    );
  }

  Widget _buildReportsSection(int delay) {
    return SettingsSection(
      title: 'Reports',
      icon: Icons.analytics_outlined,
      animationDelay: delay,
      accentColor: Colors.orange,
      children: [
        SettingsTile(
          title: 'Reports & Analytics',
          subtitle: 'Excel view, inventory & tickets',
          icon: Icons.bar_chart_rounded,
          iconColor: Colors.orange,
          onTap: () {
            debugPrint('Navigating to Reports');
            Get.to(() => const ReportsScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 400));
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(int delay) {
    return SettingsSection(
      title: 'About',
      icon: Icons.info_outline,
      animationDelay: delay,
      children: [
        SettingsTile(
          title: 'About App',
          subtitle: 'Version & details',
          icon: Icons.info_rounded,
          iconColor: const Color(0xFF43CBFF),
          onTap: () {
            debugPrint('Navigating to About');
            Get.to(() => const AboutAppScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 400));
          },
        ),
        SettingsTile(
          title: 'Logout',
          subtitle: 'Sign out of account',
          icon: Icons.logout_rounded,
          isDanger: true,
          onTap: _confirmLogout,
        ),
      ],
    );
  }

  /// 🔐 Logout confirmation and logic
  void _confirmLogout() {
    debugPrint('Logout tapped');
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await _auth.logout();
                Get.snackbar(
                  'Logged out',
                  'You have been logged out successfully.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.black.withOpacity(0.8),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
                await Future.delayed(const Duration(milliseconds: 800));
                Get.offAllNamed('/login');
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to logout: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
