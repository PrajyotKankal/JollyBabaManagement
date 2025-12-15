import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_colors.dart';
import 'services/auth_service.dart';

import 'package:url_strategy/url_strategy.dart'; // 1. Import

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/technician_dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_success_screen.dart'; // ✅ integrated success screen
import 'screens/inventory_management_screen.dart';
import 'screens/khatabook_screen.dart';
import 'screens/technician_management_screen.dart';
import 'screens/about_app_screen.dart';

/// Known routes that should be preserved on refresh
const Set<String> _knownRoutes = {
  '/splash',
  '/login',
  '/admin',
  '/tech',
  '/settings',
  '/success',
  '/inventory',
  '/khatabook',
  '/technicians',
  '/about',
};

/// Get the initial route based on current URL (for web refresh support)
String _getInitialRoute() {
  if (kIsWeb) {
    try {
      // Get the current path from the browser URL
      final uri = Uri.base;
      final path = uri.path.isEmpty || uri.path == '/' ? '/splash' : uri.path;
      
      // If it's a known route, use it; otherwise go to splash for re-auth
      if (_knownRoutes.contains(path)) {
        return path;
      }
    } catch (e) {
      debugPrint('⚠️ Error getting initial route: $e');
    }
  }
  return '/splash';
}

Future<void> main() async {
  // Ensure Flutter bindings & async setup
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Use clean URLs (remove hash #)
  setPathUrlStrategy();

  // 🔐 Initialize AuthService (load stored token, setup Dio headers)
  try {
    // Timeout after 10 seconds so app doesn't hang on white screen if storage is slow
    await AuthService().init().timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint("⚠️ AuthService init failed or timed out: $e");
  }

  // Get initial route based on current URL
  final initialRoute = _getInitialRoute();
  debugPrint('🚀 Starting app with initial route: $initialRoute');

  runApp(JollyBabaApp(initialRoute: initialRoute));
}

class JollyBabaApp extends StatelessWidget {
  final String initialRoute;
  
  const JollyBabaApp({super.key, required this.initialRoute});

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
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],

      // 🟣 Start from the detected initial route (preserves URL on refresh)
      initialRoute: initialRoute,

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
        GetPage(name: '/inventory', page: () => const InventoryManagementScreen()),
        GetPage(name: '/khatabook', page: () => const KhatabookScreen()),
        GetPage(name: '/technicians', page: () => const TechniciansScreen()),
        GetPage(name: '/about', page: () => const AboutAppScreen()),
      ],

      // 🪄 Unified smooth transitions
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),

      // 404 / Unknown Route -> Redirect to Splash to re-auth
      unknownRoute: GetPage(name: '/not-found', page: () => const SplashScreen()),
    );
  }
}

