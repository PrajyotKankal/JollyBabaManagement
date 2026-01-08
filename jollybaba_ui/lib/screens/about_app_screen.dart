import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const Color _primaryColor = Color(0xFF6D5DF6);
  static final Uri _privacyPolicyUri = Uri.parse('https://jollybaba.com/privacy');
  static final Uri _termsUri = Uri.parse('https://jollybaba.com/terms');
  static final Uri _supportEmailUri = Uri.parse('mailto:support@jollybaba.com');

  Future<void> _launchExternal(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        Get.snackbar('Unable to open link', 'Please try again later.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent.withOpacity(0.9),
            colorText: Colors.white);
      }
    } catch (_) {
      Get.snackbar('Unable to open link', 'Please try again later.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          colorText: Colors.white);
    }
  }

  void _showLicenses(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LicensesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final maxContentWidth = isMobile ? double.infinity : (isTablet ? 600.0 : 800.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FD),
      body: Stack(
        children: [
          // Gradient background
          Container(
            height: isMobile ? size.height * 0.35 : size.height * 0.4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DF6), Color(0xFF8E7BFF), Color(0xFFB49BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Decorative circles
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -80,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 8),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () async {
                          try {
                            final user = await AuthService().getStoredUser();
                            final role = (user?['role'] ?? 'technician').toString().toLowerCase();
                            if (role == 'admin' || role == 'administrator') {
                              Get.offAllNamed('/admin');
                            } else {
                              Get.offAllNamed('/tech');
                            }
                          } catch (_) {
                            Get.offAllNamed('/tech');
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'About',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Column(
                          children: [
                            // Hero Card
                            _HeroCard(isMobile: isMobile),
                            
                            SizedBox(height: isMobile ? 20 : 28),
                            
                            // Features Grid
                            _FeaturesSection(isMobile: isMobile),
                            
                            SizedBox(height: isMobile ? 20 : 28),
                            
                            // How to Use Section
                            _HowToUseSection(isMobile: isMobile),
                            
                            SizedBox(height: isMobile ? 20 : 28),
                            
                            // Support Section
                            _SupportSection(
                              isMobile: isMobile,
                              onPrivacy: () => _launchExternal(_privacyPolicyUri),
                              onTerms: () => _launchExternal(_termsUri),
                              onEmail: () => _launchExternal(_supportEmailUri),
                              onLicenses: () => _showLicenses(context),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Footer
                            Text(
                              'Made with ❤️ by JollyBaba Team',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '© 2024 JollyBaba. All rights reserved.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Glass Icon Button
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  
  const _GlassIconButton({required this.icon, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// Hero Card
class _HeroCard extends StatelessWidget {
  final bool isMobile;
  
  const _HeroCard({required this.isMobile});
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildLogo(),
        const SizedBox(height: 16),
        _buildAppInfo(centered: true),
      ],
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildLogo(),
        const SizedBox(width: 24),
        Expanded(child: _buildAppInfo(centered: false)),
        const SizedBox(width: 24),
        _buildStatsColumn(),
      ],
    );
  }
  
  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5DF6), Color(0xFF9D8BFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D5DF6).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'JB',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppInfo({required bool centered}) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'JollyBaba',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E2343),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6D5DF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'v1.0.0 (Build 100)',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6D5DF6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Smart Inventory & Repair\nManagement Simplified.',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatsColumn() {
    return Column(
      children: [
        _StatBadge(icon: Icons.inventory_2_rounded, label: 'Inventory'),
        const SizedBox(height: 8),
        _StatBadge(icon: Icons.receipt_long_rounded, label: 'Tickets'),
        const SizedBox(height: 8),
        _StatBadge(icon: Icons.analytics_rounded, label: 'Reports'),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  
  const _StatBadge({required this.icon, required this.label});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6D5DF6).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6D5DF6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6D5DF6),
            ),
          ),
        ],
      ),
    );
  }
}

// Features Section
class _FeaturesSection extends StatelessWidget {
  final bool isMobile;
  
  const _FeaturesSection({required this.isMobile});
  
  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(Icons.inventory_2_rounded, 'Inventory', 'Track stock & IMEI'),
      _Feature(Icons.confirmation_number_rounded, 'Tickets', 'Repair management'),
      _Feature(Icons.account_balance_wallet_rounded, 'Khatabook', 'Credit tracking'),
      _Feature(Icons.bar_chart_rounded, 'Reports', 'Profit analytics'),
      _Feature(Icons.people_rounded, 'Technicians', 'Role management'),
      _Feature(Icons.settings_rounded, 'Settings', 'Custom config'),
    ];
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2343),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.5 : 2.0,
            children: features.map((f) => _FeatureCard(feature: f, isMobile: isMobile)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final bool isMobile;
  
  const _FeatureCard({required this.feature, required this.isMobile});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6D5DF6).withOpacity(0.05),
            const Color(0xFF6D5DF6).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6D5DF6).withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(feature.icon, size: isMobile ? 22 : 26, color: const Color(0xFF6D5DF6)),
          const SizedBox(height: 8),
          Text(
            feature.title,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2343),
            ),
          ),
          Text(
            feature.subtitle,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// How to Use Section
class _HowToUseSection extends StatelessWidget {
  final bool isMobile;
  
  const _HowToUseSection({required this.isMobile});
  
  @override
  Widget build(BuildContext context) {
    final items = [
      ('🚀', 'Getting Started', 'Login with admin credentials to access dashboard'),
      ('📦', 'Add Inventory', 'Track devices with IMEI and purchase details'),
      ('🎫', 'Manage Tickets', 'Create and assign repair tickets to technicians'),
      ('💰', 'Track Payments', 'Use Khatabook for credit and payment tracking'),
      ('📊', 'View Reports', 'Monitor profit and export data anytime'),
    ];
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to Use',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2343),
            ),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _StepItem(
              emoji: item.$1,
              title: item.$2,
              subtitle: item.$3,
              isLast: idx == items.length - 1,
              isMobile: isMobile,
            );
          }),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isLast;
  final bool isMobile;
  
  const _StepItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isLast,
    required this.isMobile,
  });
  
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: const Color(0xFF6D5DF6).withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2343),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Support Section
class _SupportSection extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onEmail;
  final VoidCallback onLicenses;
  
  const _SupportSection({
    required this.isMobile,
    required this.onPrivacy,
    required this.onTerms,
    required this.onEmail,
    required this.onLicenses,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support & Legal',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2343),
            ),
          ),
          const SizedBox(height: 16),
          _SupportTile(
            icon: Icons.email_rounded,
            title: 'Contact Support',
            subtitle: 'support@jollybaba.com',
            onTap: onEmail,
          ),
          const Divider(height: 24),
          _SupportTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'View our privacy practices',
            onTap: onPrivacy,
          ),
          const Divider(height: 24),
          _SupportTile(
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            subtitle: 'Read terms and conditions',
            onTap: onTerms,
          ),
          const Divider(height: 24),
          _SupportTile(
            icon: Icons.code_rounded,
            title: 'Open Source',
            subtitle: 'View licenses',
            onTap: onLicenses,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Get.snackbar('Up to date', "You're on the latest version.",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF6D5DF6),
                    colorText: Colors.white);
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: Text('Check for Updates', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D5DF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6D5DF6).withOpacity(0.15),
                      const Color(0xFF6D5DF6).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6D5DF6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E2343),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// Licenses Sheet
class _LicensesSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Open Source Licenses',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E2343),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This app uses open-source libraries including Dio, GetX, Google Fonts, Flutter Animate, and more. Full license details are available in the project repository.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Got it'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6D5DF6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
