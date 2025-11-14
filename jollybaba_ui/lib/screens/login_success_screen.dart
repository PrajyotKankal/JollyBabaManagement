import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_screen.dart';
import 'technician_dashboard_screen.dart';

class LoginSuccessScreen extends StatefulWidget {
  final String role; // "admin" or "technician"
  final String? userName; // optional display name

  const LoginSuccessScreen({super.key, required this.role, this.userName});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> {
  @override
  void initState() {
    super.initState();

    // Auto redirect after short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (widget.role.toLowerCase() == 'admin') {
        Get.offAll(() => const DashboardScreen(),
            transition: Transition.fadeIn,
            duration: const Duration(milliseconds: 800));
      } else {
        Get.offAll(() => const TechnicianDashboardScreen(),
            transition: Transition.fadeIn,
            duration: const Duration(milliseconds: 800));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isMobile = size.width < 600;
    final double iconSize = isMobile ? 55 : 90;
    final double cardWidth = isMobile ? size.width * 0.8 : 380;
    final double fontSizeTitle = isMobile ? 22 : 28;
    final double fontSizeSubtitle = isMobile ? 14 : 16;

    final displayName = widget.userName?.isNotEmpty == true
        ? widget.userName!.split(' ').first
        : null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF7F8FF),
              Color(0xFFE9EDFF),
              Color(0xFFDDE2FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 🌈 Glowing pulse behind card
                  Container(
                    width: isMobile ? 180 : 260,
                    height: isMobile ? 180 : 260,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF8A8EFF),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: const Duration(seconds: 2),
                      )
                      .fade(
                        begin: 0.4,
                        end: 0.8,
                        duration: const Duration(seconds: 2),
                      ),

                  // 🌤️ Glassy success card
                  Container(
                    width: cardWidth,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 35 : 50,
                      horizontal: isMobile ? 25 : 40,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ Animated checkmark
                        Container(
                          width: iconSize + 20,
                          height: iconSize + 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A8EFF), Color(0xFF6D5DF6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6D5DF6)
                                    .withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        )
                            .animate()
                            .scale(
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: const Duration(milliseconds: 700)),

                        const SizedBox(height: 30),

                        // 🎉 Title
                        Text(
                          "Login Successful!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: fontSizeTitle,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 800))
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              duration: const Duration(milliseconds: 800),
                            ),

                        if (displayName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Welcome back, $displayName 👋",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: fontSizeSubtitle,
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(
                                duration: const Duration(milliseconds: 1000),
                              ),
                        ],

                        const SizedBox(height: 8),

                        // 🔄 Redirect hint
                        Text(
                          widget.role.toLowerCase() == 'admin'
                              ? "Redirecting to Admin Dashboard..."
                              : "Redirecting to Technician Dashboard...",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.black45,
                            fontSize: fontSizeSubtitle,
                            fontWeight: FontWeight.w400,
                          ),
                        ).animate().fadeIn(
                              duration: const Duration(milliseconds: 1200),
                            ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 800))
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        duration: const Duration(milliseconds: 900),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
