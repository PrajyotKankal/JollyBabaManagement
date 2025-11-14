import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import 'login_success_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  late AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _borderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    developer.log('AuthService.baseUrl = ${_auth.dio.options.baseUrl}',
        name: 'login.debug');

    try {
      final user = await _auth.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final role = (user['role'] ?? 'technician').toString().toLowerCase();

      Get.offAll(
        () => LoginSuccessScreen(
          role: role,
          userName: user['name'] ?? '',
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 400),
      );
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      Get.snackbar(
        'Login failed',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.92),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(14),
      );
    } catch (e) {
      Get.snackbar(
        'Unexpected error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(14),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardMaxWidth = math.min(screenWidth * 0.82, 380);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF9FAFF),
              Color(0xFFECEBFF),
              Color(0xFFF7F5FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
              child: AnimatedBuilder(
                animation: _borderController,
                builder: (context, _) {
                  return SizedBox(
                    width: cardMaxWidth,
                    child: CustomPaint(
                      painter: _AnimatedBorderPainter(
                        progress: _borderController.value,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF6D5DF6).withValues(alpha: 0.08),
                              blurRadius: 22,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Card(
                          color: Colors.white,
                          elevation: 6,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.all(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 💜 JollyBaba Title
                                Text(
                                  'JollyBaba',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5A45E0),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign in to continue',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                // 🔹 Form
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: const Icon(
                                            Icons.email_outlined,
                                            color: Color(0xFF6D5DF6),
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12),
                                          filled: true,
                                          fillColor: const Color(0xFFF5F6FA),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Email required';
                                          }
                                          if (!RegExp(
                                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                              .hasMatch(v.trim())) {
                                            return 'Invalid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passwordCtrl,
                                        obscureText: _obscure,
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            color: Color(0xFF6D5DF6),
                                            size: 20,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.black45,
                                              size: 20,
                                            ),
                                            onPressed: () => setState(
                                                () => _obscure = !_obscure),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12),
                                          filled: true,
                                          fillColor: const Color(0xFFF5F6FA),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Password required';
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) => _submit(),
                                      ),
                                      const SizedBox(height: 14),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 42,
                                        child: ElevatedButton(
                                          onPressed:
                                              _isLoading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6D5DF6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  'Login',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '© ${DateTime.now().year} JollyBaba',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBorderPainter extends CustomPainter {
  final double progress;
  _AnimatedBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 🔮 Darker mid-purple “snake” gradient
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(2 * math.pi * progress),
      colors: [
        const Color(0x00B89CFF),
        const Color(0xFF5A45E0).withValues(alpha: 0.95),
        const Color(0xFF7C63FF).withValues(alpha: 0.8),
        const Color(0x00B89CFF),
      ],
      stops: const [0.0, 0.4, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(6.0),
      const Radius.circular(16),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_AnimatedBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
