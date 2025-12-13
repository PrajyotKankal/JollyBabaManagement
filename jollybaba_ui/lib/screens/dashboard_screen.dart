// lib/screens/dashboard_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../services/ticket_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../widgets/responsive_wrapper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = "Pending";
  List<dynamic> _tickets = [];
  bool _isLoading = true;

  int _selectedPage = 0; // 0 = Dashboard, 1 = Settings

  final List<String> statuses = [
    "Pending",
    "Repaired",
    "Delivered",
    "Cancelled",
  ];

  // keep these constants synced with _buildPolishedNav values
  static const double _navBarHeight = 64.0; // increased nav height
  static const double _navBottomMargin = 14.0;
  static const double _fabSize = 72.0; // increased FAB size (+ sign larger)

  late AnimationController glowController;
  late Animation<double> glowAnimation;

  @override
  void initState() {
    super.initState();
    _ensureAuthenticatedAndLoad();

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    glowAnimation = Tween<double>(
      begin: 0.10,
      end: 0.40,
    ).animate(CurvedAnimation(parent: glowController, curve: Curves.easeInOut));
  }

  Future<void> _ensureAuthenticatedAndLoad() async {
    final token = await AuthService().getToken();

    if (token == null) {
      if (!mounted) return;
      Get.offAll(() => const LoginScreen());
      return;
    }

    await _loadTickets();
  }

  @override
  void dispose() {
    glowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final data = await TicketService.fetchTickets();
      if (mounted) {
        setState(() {
          _tickets = data;
          _isLoading = false;
        });
      }
      if (kDebugMode && _tickets.isNotEmpty) {
        debugPrint('Sample ticket status (raw): ${_tickets[0]["status"]}');
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint("❌ Error fetching tickets: $e\n$st");
      // DON'T auto-logout on errors - network issues shouldn't clear session
      // User stays logged in; they can retry or manually logout
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _selectedPage == 0
                    ? _buildDashboardPage(context)
                    : const SettingsScreen(showBottomNav: false),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 8),
                child: IgnorePointer(
                  ignoring: false,
                  child: _buildPolishedNav(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- DASHBOARD PAGE ---------------- //
  Widget _buildDashboardPage(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isPortrait = ResponsiveHelper.isPortrait(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Horizontal padding grows on very large screens so content stays centered
        final horizontalPadding = deviceType == DeviceType.mobile
            ? 16.0
            : deviceType == DeviceType.tablet
                ? 24.0
                : width > 1400
                    ? width * 0.12
                    : width * 0.05;

        // Scale factor for fonts and chips: keeps UI balanced on tablets/desktops
        final scale = ResponsiveHelper.getResponsiveFontSize(context, 14) / 14;

        // Reserve space at bottom for nav + FAB
        final safeBottom = MediaQuery.of(context).viewPadding.bottom;
        final double bottomReserve =
            safeBottom + _navBottomMargin + (_fabSize * 0.9);

        // Filtered tickets based on search/status
        final filteredTickets = _tickets.where((t) {
          final name = (t["customer_name"] ?? "").toString().toLowerCase();
          final mobile = (t["mobile_number"] ?? "").toString().toLowerCase();
          final model = (t["device_model"] ?? "").toString().toLowerCase();
          final rawStatus = (t["status"] ?? "Pending").toString();
          final statusNorm = rawStatus.trim().toLowerCase();
          final selectedNorm = _selectedStatus.trim().toLowerCase();
          final query = _searchController.text.toLowerCase();
          final matchesQuery =
              name.contains(query) ||
              mobile.contains(query) ||
              model.contains(query);
          final matchesStatus = statusNorm == selectedNorm;
          return matchesQuery && matchesStatus;
        }).toList();

        // Determine grid columns responsively
        int columns;
        if (width >= 800) {
          columns = 2; // Max 2 columns for Web/Desktop
        } else {
          columns = 1;
        }

        // Keep card aspect ratio reasonable across sizes
        final isLandscape = ResponsiveHelper.isLandscape(context);
        final double cardAspect;
        if (columns == 1) {
          cardAspect = isLandscape ? 4.5 : (deviceType == DeviceType.mobile ? 3.0 : 3.6);
        } else {
          // 2 columns: make them "longer" (taller) as requested
          // Lower aspect ratio = taller card
          cardAspect = isLandscape ? 3.5 : 2.8;
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  "JollyBaba Mobiles",
                  style: GoogleFonts.poppins(
                    fontSize: deviceType == DeviceType.mobile ? 18.0 : 20.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Colors.black87,
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: 12),

              // Search Bar — grows on tablet/desktop but stays compact on phone.
              SizedBox(
                height: 44,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: deviceType == DeviceType.desktop
                          ? 620
                          : deviceType == DeviceType.tablet
                              ? 520
                              : 420,
                      minWidth: 220,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: deviceType == DeviceType.mobile
                            ? "Search..."
                            : "Search by name, mobile or model",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 13 * scale,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.black54,
                          size: 18 * (scale),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18 * (scale)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12 * scale,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12 * scale),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3E6EF),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status Chips — centered
              SizedBox(
                height: 42 * (scale.clamp(0.9, 1.2)),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...statuses.map((status) {
                          final isSelected = _selectedStatus == status;
                          final baseFont = 13.0 * scale;
                          final horizontalPaddingChip = deviceType == DeviceType.desktop ? 18.0 : 12.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedStatus = status),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPaddingChip,
                                  vertical: 6 * (scale * 0.9),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6D5DF6)
                                      : const Color(0xFFF1F3FA),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.poppins(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: baseFont,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Tickets List
              Expanded(
                child: Stack(
                  children: [
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _loadTickets,
                            child: GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                4,
                                4,
                                4,
                                bottomReserve,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: cardAspect,
                                  ),
                              itemCount: filteredTickets.length,
                              itemBuilder: (context, index) {
                                final t = filteredTickets[index];
                                return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () async {
                                          await Get.to(
                                            () =>
                                                TicketDetailsScreen(ticket: t),
                                            transition: Transition.fadeIn,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                          );
                                          await _loadTickets();
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12 * (scale * 1.0),
                                            vertical: 8 * (scale * 0.9),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Left content (title / subtitle)
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      t["customer_name"] ??
                                                          "Unknown Customer",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize:
                                                                15 * (scale),
                                                            color: const Color(
                                                              0xFF2A2E45,
                                                            ),
                                                          ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 4 * (scale * 0.8)),
                                                    Text(
                                                      "Device: ${t["device_model"] ?? "-"}",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize:
                                                                12 * (scale),
                                                          ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 2 * (scale * 0.8)),
                                                    Text(
                                                      "Mobile: ${t["mobile_number"] ?? "-"}",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize:
                                                                11 * (scale),
                                                          ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Spacer & status pill on right
                                              const SizedBox(width: 8),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: _gradientStatusPill(
                                                  t["status"]?.toString(),
                                                  scale: scale,
                                                  isDesktop: deviceType == DeviceType.desktop,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate(delay: (index * 80).ms)
                                    .fadeIn(duration: 360.ms)
                                    .slideY(begin: 0.14, curve: Curves.easeOut);
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- POLISHED NAV (overlay version) ---------------- //
  Widget _buildPolishedNav(BuildContext context) {
    final double barHeight = _navBarHeight;
    final double horizontalMargin = 18.0;
    final double bottomMargin = _navBottomMargin;
    final double fabSize = _fabSize;

    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final effectiveBottom = bottomMargin + safeBottom;

    const icons = [Icons.grid_view_rounded, Icons.list_alt_rounded];
    final activeLeft = const Color(0xFF7B61FF);
    final activeRight = const Color(0xFF00C6FF);
    final inactiveColor = Colors.black.withValues(alpha: 0.40);

    final totalWidth = MediaQuery.of(context).size.width;

    // clamp pill padding so nav doesn't expand too far on ultra-wide screens
    final pillHorizontalPadding = (totalWidth * 0.06).clamp(22.0, 160.0);
    final pillWidth = (totalWidth - pillHorizontalPadding * 2).clamp(
      280.0,
      1200.0,
    );

    return SizedBox(
      height: barHeight + effectiveBottom + (fabSize / 2),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // background nav bar
          Positioned(
            left: pillHorizontalPadding,
            right: pillHorizontalPadding,
            bottom: effectiveBottom,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: CustomPaint(
                  painter: _NavBarHighlightPainter(
                    color: Colors.white,
                    cornerRadius: 36.0,
                  ),
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: pillWidth * 0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          icons[0],
                          size: 24,
                          color: _selectedPage == 0
                              ? activeLeft
                              : inactiveColor,
                        ),
                        Icon(
                          icons[1],
                          size: 24,
                          color: _selectedPage == 1
                              ? activeRight
                              : inactiveColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // tap zones (left + right)
          ...List.generate(2, (i) {
            return Positioned(
              left: i == 0 ? pillHorizontalPadding : null,
              right: i == 1 ? pillHorizontalPadding : null,
              bottom: effectiveBottom,
              child: SizedBox(
                width: pillWidth / 2,
                height: barHeight,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(36),
                    splashColor:
                        (_selectedPage == i
                                ? (i == 0 ? activeLeft : activeRight)
                                : Colors.grey)
                            .withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    onTap: () => setState(() => _selectedPage = i),
                  ),
                ),
              ),
            );
          }),

          // Floating Action Button (synced with shimmer)
          Positioned(
            bottom: effectiveBottom + (barHeight / 2) - (fabSize / 2) + 10,
            child: GestureDetector(
              onTap: () async {
                final result = await Get.to(
                  () => const CreateTicketScreen(),
                  transition: Transition.fadeIn,
                  duration: const Duration(milliseconds: 360),
                );
                if (result == true) await _loadTickets();
              },
              child: AnimatedBuilder(
                animation: glowController,
                builder: (context, _) {
                  final glow = glowAnimation.value;
                  return Container(
                        height: fabSize,
                        width: fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFF9D8BFE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7B61FF,
                              ).withValues(alpha: 0.2 + glow * 0.25),
                              blurRadius: 20 + glow * 10,
                              spreadRadius: 1 + glow * 1.5,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .scaleXY(begin: 0.96, end: 1.0);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- STATUS PILL ---------------- //
  Widget _gradientStatusPill(
    String? status, {
    double scale = 1.0,
    bool isDesktop = false,
  }) {
    final Map<String, Color> colorMap = {
      "pending": const Color(0xFF7A6FF8),
      "repaired": const Color(0xFF00C6FF),
      "delivered": const Color(0xFF56AB2F),
      "cancelled": const Color(0xFFFF4B2B),
    };

    final raw = status ?? "-";
    final norm = raw.toString().trim().toLowerCase();

    final baseColor = colorMap[norm] ?? Colors.grey.shade500;
    final bgColor = baseColor.withValues(alpha: 0.10);

    final displayText = raw.toString().trim().isEmpty
        ? "-"
        : _toTitleCase(raw.toString().trim());

    // adapt padding & font size based on layout scale
    final double fontSize = (isDesktop ? 12.5 : 11.0) * scale;
    final double horizontal = isDesktop ? 14.0 * scale : 10.0 * scale;
    final double vertical = 6.0 * scale;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal.clamp(8.0, 24.0),
        vertical: vertical,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: baseColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        displayText,
        style: GoogleFonts.poppins(
          color: baseColor.withValues(alpha: 0.9),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'[\s_-]+'));
    return parts
        .map((p) {
          final low = p.toLowerCase();
          return low.isEmpty
              ? ''
              : '${low[0].toUpperCase()}${low.substring(1)}';
        })
        .join(' ');
  }
} // <-- end of _DashboardScreenState

/// Paints a soft static highlight on top of the nav pill.
class _NavBarHighlightPainter extends CustomPainter {
  final Color color;
  final double cornerRadius;
  _NavBarHighlightPainter({
    this.color = const Color(0xFFFFFFFF),
    this.cornerRadius = 36.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // subtle top highlight gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.6);
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.0)],
    ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(cornerRadius),
    );

    // Clip to rounded rect then draw highlight
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = Colors.transparent);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavBarHighlightPainter old) {
    return old.color != color || old.cornerRadius != cornerRadius;
  }
}
