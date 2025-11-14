// 📁 lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../services/auth_service.dart';
import 'technician_management_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../widgets/bottom_glass_navbar.dart';
import 'inventory_management_screen.dart';
import 'khatabook_screen.dart';
import 'profile_screen.dart';
import 'about_app_screen.dart';

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

  final List<Map<String, dynamic>> settingsOptions = [
    {
      "title": "Inventory",
      "icon": Icons.inventory_rounded,
      "colors": [Color(0xFF8A7CFF), Color(0xFFB49BFF)],
      "subtitle": "Manage stock & spare parts",
    },
    {
      "title": "Technicians",
      "icon": Icons.engineering_rounded,
      "colors": [Color(0xFF6D5DF6), Color(0xFF9D8BFE)],
      "subtitle": "Create & manage technicians",
    },
    {
      "title": "Khatabook",
      "icon": Icons.menu_book_rounded,
      "colors": [Color(0xFF00C6FF), Color(0xFF0072FF)],
      "subtitle": "Credits, cash, and settlements",
    },
    {
      "title": "Profile",
      "icon": Icons.person_rounded,
      "colors": [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
      "subtitle": "Manage account details",
    },
    {
      "title": "About App",
      "icon": Icons.info_rounded,
      "colors": [Color(0xFF43CBFF), Color(0xFF9708CC)],
      "subtitle": "Version & details",
    },
    {
      "title": "Logout",
      "icon": Icons.logout_rounded,
      "colors": [Color(0xFFFF6A88), Color(0xFFFF99AC)],
      "subtitle": "Sign out of account",
    },
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final maxCrossAxisExtent = isMobile ? 320.0 : 280.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.3,
        centerTitle: true,
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 18 : 20,
            color: const Color(0xFF2A2E45),
          ),
        ),
        leading: widget.showBottomNav
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF2A2E45), size: 20),
                onPressed: () {
                  Get.off(() => const DashboardScreen(),
                      transition: Transition.leftToRight,
                      duration: const Duration(milliseconds: 400));
                },
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            childAspectRatio: 1.05,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: settingsOptions.length,
          itemBuilder: (context, index) {
            final item = settingsOptions[index];
            return SettingsCard(
              title: item["title"] as String,
              subtitle: item["subtitle"] as String,
              icon: item["icon"] as IconData,
              colors: List<Color>.from(item["colors"] as List<Color>),
              delay: index * 120,
              onTap: () => _handleTap(item["title"] as String),
            );
          },
        ),
      ),
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

  /// Handles each setting card tap
  void _handleTap(String title) {
    switch (title) {
      case "Inventory":
        Get.to(() => InventoryManagementScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 400));
        break;
      case "Khatabook":
        Get.to(() => const KhatabookScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 400));
        break;
      case "Technicians":
        Get.to(() => const TechniciansScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 400));
        break;
      case "Profile":
        Get.to(() => const ProfileScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 400));
        break;
      case "About App":
        Get.to(() => const AboutAppScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 400));
        break;

      case "Logout":
        _confirmLogout();
        break;

      default:
        Get.snackbar(
          "Coming soon",
          "$title section is under development.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black.withOpacity(0.7),
          colorText: Colors.white,
        );
        break;
    }
  }

  /// 🔐 Logout confirmation and logic
  void _confirmLogout() {
    Get.defaultDialog(
      title: "Logout",
      middleText: "Are you sure you want to log out?",
      textCancel: "Cancel",
      textConfirm: "Logout",
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFF6D5DF6),
      onConfirm: () async {
        Get.back(); // close dialog
        try {
          await _auth.logout();

          // Small fade-out feedback
          Get.snackbar(
            "Logged out",
            "You have been logged out successfully.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.black.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );

          // Short delay before redirect (smooth UX)
          await Future.delayed(const Duration(milliseconds: 800));

          // Redirect to login
          Get.offAll(() => const LoginScreen(),
              transition: Transition.fadeIn,
              duration: const Duration(milliseconds: 500));
        } catch (e) {
          Get.snackbar(
            "Error",
            "Failed to logout: $e",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        }
      },
    );
  }
}

/// A single settings card widget with ripple + subtle tap animation.
class SettingsCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final int delay;
  final VoidCallback onTap;

  const SettingsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.delay,
    required this.onTap,
  });

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final vm.Matrix4 transform = vm.Matrix4.identity()
      ..translate(_pressed ? -6.0 : 0.0, 0.0, 0.0)
      ..scale(_pressed ? 0.975 : 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: transform,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          splashFactory: InkRipple.splashFactory,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.first.withOpacity(0.2),
                  blurRadius: _pressed ? 6 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: widget.title,
                  child: Icon(widget.icon, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(delay: widget.delay.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.2, curve: Curves.easeOut),
      ),
    );
  }
}
