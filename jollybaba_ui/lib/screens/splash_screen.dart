import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Start splash, perform auth check in background
    Future.delayed(const Duration(seconds: 3), _bootstrap);
  }

  /// 🧠 Handles token check and navigation
  Future<void> _bootstrap() async {
    try {
      final token = await _auth.getToken();
      if (token == null || token.isEmpty) {
        _navigateToRoute('/login');
        return;
      }

      final user = await _auth.me();
      final role = (user['role'] ?? 'technician').toString().toLowerCase();

      if (role == 'admin') {
        _navigateToRoute('/admin');
      } else {
        _navigateToRoute('/tech');
      }
    } catch (e) {
      // If something fails (network, 401, etc.), go to Login but keep stored session
      // so the user is not force-logged-out from storage.
      _navigateToRoute('/login');
    }
  }

  /// 🔄 Handles fade-out + navigation using NAMED ROUTES
  /// This fixes the /minified:h URL issue in production builds
  Future<void> _navigateToRoute(String routeName) async {
    await _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      Get.offAllNamed(routeName);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 400).clamp(0.75, 1.3);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌈 Background Gradient
            AnimatedContainer(
              duration: const Duration(seconds: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEEF1FF),
                    Color(0xFFDCE3FF),
                    Color(0xFFF8F9FF),
                    Color(0xFFE9ECFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // 💫 Moving light overlay
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(seconds: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.1, 0.5, 0.9],
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(duration: const Duration(milliseconds: 3000)),
            ),

            // 🌫 Blur glass layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.transparent),
              ),
            ),

            // 🔮 Glow behind logo
            Align(
              alignment: Alignment.center,
              child: Container(
                width: size.width * 0.55,
                height: size.width * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6D5DF6).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    radius: 0.85,
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: const Duration(seconds: 2),
                  )
                  .fade(
                    begin: 0.4,
                    end: 0.8,
                    duration: const Duration(seconds: 2),
                  ),
            ),

            // 🌟 Logo and Text
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🌀 Logo
                  Container(
                    width: 120 * scale,
                    height: 120 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7A6DF6), Color(0xFF8A8EFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C74F5).withValues(alpha: 0.45),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mobile_friendly_rounded,
                        color: Colors.white,
                        size: 58 * scale,
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: const Duration(milliseconds: 600)),

                  SizedBox(height: 28 * scale),

                  // 💎 App Name
                  Text(
                    "JollyBaba",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1C2044),
                      fontSize: 33 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 900))
                      .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),

                  SizedBox(height: 6 * scale),

                  // 🩵 Subtitle
                  Text(
                    "Mobile Repairing System",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF61637A),
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(
                        duration: const Duration(milliseconds: 1200),
                      ),

                  SizedBox(height: 40 * scale),

                  // 🌈 Progress Bar
                  Container(
                    width: 180 * scale,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: const Color(0xFFE4E6F1),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 50 * scale,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: AppColors.gradientBluePurple,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6D5DF6)
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .slideX(
                            begin: -0.35,
                            end: 0.35,
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeInOut,
                          ),
                    ),
                  ),

                  SizedBox(height: 25 * scale),

                  // ✨ Floating Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Container(
                        width: 6 * scale,
                        height: 6 * scale,
                        margin: EdgeInsets.symmetric(horizontal: 5 * scale),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF6D5DF6), Color(0xFF8A8EFF)],
                          ),
                        ),
                      )
                          .animate(
                            delay: Duration(milliseconds: i * 300),
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .fade(
                            begin: 0.3,
                            end: 1.0,
                            duration: const Duration(milliseconds: 1200),
                          )
                          .scale(
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1, 1),
                          );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
