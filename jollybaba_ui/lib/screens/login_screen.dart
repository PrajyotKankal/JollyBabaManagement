import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../widgets/responsive_wrapper.dart';
import '../theme/app_colors.dart';
import 'login_success_screen.dart';
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  late final GoogleSignIn _googleSignIn;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  late AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _googleSignIn = GoogleSignIn(
      // For web: clientId is required to get ID token
      // For mobile: serverClientId is used for backend verification
      clientId: kIsWeb ? AppConfig.googleWebClientId : null,
      serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
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
        password: _passwordCtrl.text.trim(),
      );

      final role = (user['role'] ?? 'technician').toString().toLowerCase();

      // Use named route for consistent navigation stack
      Get.offAllNamed('/success');
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      Get.snackbar(
        'Login failed',
        msg.length > 100 ? '${msg.substring(0, 100)}...' : msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.92),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(14),
      );
    } catch (e) {
      Get.snackbar(
        'Unexpected error',
        e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString(),
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

  Future<void> _loginWithGoogle() async {
    if (_googleLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _googleLoading = true);

    try {
      GoogleSignInAccount? account;
      
      if (kIsWeb) {
        // For web: use signInSilently which works better with modern browsers
        // The user will be prompted via Google's OAuth consent screen
        account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      } else {
        // For Android/iOS: keep existing approach
        await _googleSignIn.signOut();
        account = await _googleSignIn.signIn();
      }
      
      if (account == null) {
        return; // user cancelled
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google did not return an ID token.');
      }

      final user = await _auth.loginWithGoogle(idToken);
      final role = (user['role'] ?? 'technician').toString().toLowerCase();

      if (!mounted) return;
      // Use named route for consistent navigation stack
      Get.offAllNamed('/success');
    } on Exception catch (e) {
      debugPrint('🔴 GOOGLE LOGIN ERROR: $e');
      final msg = e.toString().replaceAll('Exception: ', '');
      Get.snackbar(
        'Google Sign-In failed',
        msg.length > 100 ? '${msg.substring(0, 100)}...' : msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.92),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(14),
      );
    } catch (e) {
      debugPrint('🔴 UNEXPECTED ERROR: $e');
      Get.snackbar(
        'Unexpected error',
        e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(14),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      maxWidth: 600,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: _borderController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AnimatedBorderPainter(
                    progress: _borderController.value,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [AppColors.softShadow],
                    ),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign in to manage tickets, stock & finances',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
                                          labelText: 'ID',
                                          prefixIcon: const Icon(
                                            Icons.email_outlined,
                                            color: AppColors.accentBlue,
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: AppColors.borderGrey,
                                            ),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'ID required';
                                          }
                                          if (!RegExp(
                                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                              .hasMatch(v.trim())) {
                                            return 'Invalid ID';
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
                                            color: AppColors.accentBlue,
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            backgroundColor: AppColors.accentBlue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 3,
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
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 42,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _googleLoading ? null : _loginWithGoogle,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            side: const BorderSide(color: AppColors.accentBlue),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: _googleLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.accentBlue,
                                                  ),
                                                )
                                              : const Icon(Icons.g_mobiledata, color: AppColors.accentBlue, size: 26),
                                          label: Text(
                                            _googleLoading ? 'Signing in...' : 'Continue with Google',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.accentBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ' ${DateTime.now().year} JollyBaba',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    );
                },
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
