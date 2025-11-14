import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_colors.dart';
import 'services/auth_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/technician_dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_success_screen.dart'; // ✅ integrated success screen

Future<void> main() async {
  // Ensure Flutter bindings & async setup
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Initialize AuthService (load stored token, setup Dio headers)
  await AuthService().init();

  runApp(const JollyBabaApp());
}

class JollyBabaApp extends StatelessWidget {
  const JollyBabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JollyBaba',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.light,
        ),
      ),

      // 🟣 Start from Splash Screen
      home: const SplashScreen(),

      // 🧭 Define all GetX routes for navigation
      getPages: [
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/admin', page: () => const DashboardScreen()),
        GetPage(name: '/tech', page: () => const TechnicianDashboardScreen()),
        GetPage(
          name: '/settings',
          page: () => const SettingsScreen(showBottomNav: true),
        ),
        GetPage(
          name: '/success',
          page: () => const LoginSuccessScreen(role: 'technician'),
        ), // ✅ integrated success route
      ],

      // 🪄 Unified smooth transitions
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}
