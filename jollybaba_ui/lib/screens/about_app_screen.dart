import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Open Source Licenses',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2A2E45),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This application uses open-source libraries such as Dio, GetX, Google Fonts, Flutter Animate, and more. Full license details can be viewed in the project repository.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Got it'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF9D8BFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              'JB',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JollyBaba',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2A2E45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v1.0.0 (Build 100)',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black45),
                ),
                const SizedBox(height: 10),
                Text(
                  'Smart Inventory & Repair Management Simplified.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6D5DF6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A2E45),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildGuideSection() {
    final List<_GuideItem> items = [
      _GuideItem(
        title: '🧾 Getting Started',
        points: [
          'Login with your admin credentials to access the dashboard.',
          'Review the summary cards for quick insights into tickets and sales.',
          'Use the bottom navigation or Settings to explore key modules.',
        ],
      ),
      _GuideItem(
        title: '💼 Managing Inventory',
        points: [
          'Add devices with accurate IMEI and purchase details.',
          'Update status when devices are sold, reserved, or available.',
          'Export CSV reports for external audits and backup.',
        ],
      ),
      _GuideItem(
        title: '💰 Reports & Profit',
        points: [
          'Monitor profit analytics from the dashboard charts.',
          'Filter reports by date to understand revenue trends.',
          'Export or share reports to your accountant in one tap.',
        ],
      ),
      _GuideItem(
        title: '📒 Khatabook Section',
        points: [
          'Track credits, cash, and settlements with familiar ledger flows.',
          'Update received payments to keep balances in sync.',
          'Create notes for clients to preserve custom agreements.',
        ],
      ),
      _GuideItem(
        title: '⚙️ Technician Management',
        points: [
          'Create technician logins with limited access based on role.',
          'Assign tickets to technicians and track completion status.',
          'Deactivate accounts anytime without losing historic data.',
        ],
      ),
      _GuideItem(
        title: '🧠 Tips',
        points: [
          'Always verify before marking sold (confirmation box added).',
          'Keep admin credentials safe — they can’t be deleted or downgraded.',
          'Use the About App → Check for Updates option to stay current.',
        ],
      ),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _GuideExpansion(item: item),
          if (item != items.last) const SizedBox(height: 12),
        ]
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Column(
      children: [
        _SupportTile(
          icon: Icons.email_rounded,
          label: 'Contact Support',
          value: 'support@jollybaba.com',
          onTap: () => _launchExternal(_supportEmailUri),
        ),
        const Divider(height: 26),
        _SupportTile(
          icon: Icons.privacy_tip_rounded,
          label: 'Privacy Policy',
          value: 'jollybaba.com/privacy',
          onTap: () => _launchExternal(_privacyPolicyUri),
        ),
        const SizedBox(height: 12),
        _SupportTile(
          icon: Icons.description_rounded,
          label: 'Terms of Service',
          value: 'jollybaba.com/terms',
          onTap: () => _launchExternal(_termsUri),
        ),
        const SizedBox(height: 12),
        _SupportTile(
          icon: Icons.code_rounded,
          label: 'Open Source Licenses',
          value: 'View acknowledgements',
          onTap: () => _showLicenses(context),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Get.snackbar('Up to date', "You're on the latest version.",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.black.withOpacity(0.8),
                  colorText: Colors.white);
            },
            icon: const Icon(Icons.system_update_alt_rounded),
            label: const Text('Check for Updates'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFF6D5DF6),
              side: const BorderSide(color: Color(0xFF6D5DF6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FD),
      body: Stack(
        children: [
          Container(
            height: size.height * 0.32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DF6), Color(0xFF8E7BFF), Color(0xFFB49BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About App',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          title: 'App Overview',
                          child: Text(
                            'JollyBaba is an all-in-one inventory and mobile repair management system that helps you track stock, manage technicians, record sales, and monitor profit in real time. Designed for simplicity and speed, it brings Khatabook-style convenience with professional reporting tools.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          title: 'How to Use the App',
                          child: _buildGuideSection(),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          title: 'Support & Legal',
                          child: _buildSupportSection(context),
                        ),
                      ],
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

class _GuideItem {
  final String title;
  final List<String> points;
  const _GuideItem({required this.title, required this.points});
}

class _GuideExpansion extends StatefulWidget {
  final _GuideItem item;
  const _GuideExpansion({required this.item});

  @override
  State<_GuideExpansion> createState() => _GuideExpansionState();
}

class _GuideExpansionState extends State<_GuideExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded ? const Color(0xFF6D5DF6).withOpacity(0.35) : Colors.transparent,
          width: 1.1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          widget.item.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2E45),
          ),
        ),
        iconColor: const Color(0xFF6D5DF6),
        collapsedIconColor: Colors.black45,
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final point in widget.item.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 6, color: Color(0xFF6D5DF6)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: Colors.black87.withOpacity(0.75),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SupportTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6D5DF6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2A2E45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: Color(0xFF6D5DF6))
            ],
          ),
        ),
      ),
    );
  }
}
