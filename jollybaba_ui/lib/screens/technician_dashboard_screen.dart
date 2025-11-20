// lib/screens/technician_dashboard_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '_nav_bar_highlight_painter.dart';
import 'inventory_management_screen.dart';

import '../services/ticket_service.dart';
import '../services/auth_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';
import 'login_screen.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() => _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = "Pending";
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  bool _mineOnly = false;

  Map<String, dynamic>? _me; // current user (technician)

  // keep statuses consistent with admin dashboard
  final List<String> statuses = ["All", "Pending", "Repaired", "Delivered", "Cancelled"];

  // nav sizes - keep same proportions as admin dashboard
  static const double _navBarHeight = 64.0;
  static const double _navBottomMargin = 14.0;
  static const double _fabSize = 72.0;

  late AnimationController glowController;
  late Animation<double> glowAnimation;
  int _selectedPage = 0; // dummy for nav highlighting

  @override
  void initState() {
    super.initState();
    _ensureAuthenticatedAndLoad();

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    glowAnimation = Tween<double>(begin: 0.10, end: 0.40).animate(
        CurvedAnimation(parent: glowController, curve: Curves.easeInOut));
  }

  void _onNavTap(int i) async {
    if (i == 0) {
      setState(() => _selectedPage = 0); // stay on Dashboard
      return;
    }
    if (i == 1) {
      // Open Inventory and land on List page
      await Get.to(() => const InventoryManagementScreen(initialIndex: 2), transition: Transition.fadeIn, duration: const Duration(milliseconds: 250));
      // keep highlight on right icon after return
      if (mounted) setState(() => _selectedPage = 1);
    }
  }

  Future<void> _ensureAuthenticatedAndLoad() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      // fetch current user (me) and then tickets
      final user = await AuthService().me();
      _me = user;
      await _loadTickets();
    } catch (e, st) {
      if (kDebugMode) debugPrint('Auth or load error: $e\n$st');
      try {
        await AuthService().logout();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    glowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final selected = _selectedStatus.trim().toLowerCase();
      final fetchStatus = selected == 'all' ? null : selected;
      final all = await TicketService.fetchTickets(
        mineOnly: _mineOnly,
        status: fetchStatus,
        perPage: 500,
      );

      if (mounted) {
        setState(() {
          _tickets = all;
          _isLoading = false;
        });
      }
      if (kDebugMode) debugPrint('Technician tickets loaded: ${_tickets.length} (mineOnly=$_mineOnly, status=${fetchStatus ?? 'any'})');
    } catch (e, st) {
      if (kDebugMode) debugPrint("❌ Error fetching tickets: $e\n$st");

      final errStr = e.toString().toLowerCase();
      if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('session expired')) {
        await AuthService().logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    // confirmation
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Log out', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
              onPressed: () => Navigator.of(c).pop(true),
              child: Text('Log out', style: GoogleFonts.poppins(color: Colors.white))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await AuthService().logout();
    } catch (e) {
      if (kDebugMode) debugPrint('Logout failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildAvatarMenu() {
    // small professional avatar + popup menu
    final name = (_me?['name'] ?? '').toString();
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((p) => p.isEmpty ? '' : p[0]).take(2).join().toUpperCase()
        : 'T';

    return PopupMenuButton<int>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        // you can add "Profile" later if desired
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Color(0xFF7B61FF)),
              const SizedBox(width: 10),
              Text('Log out', style: GoogleFonts.poppins(fontSize: 14)),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == 1) _handleLogout();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF7B61FF),
          child: Text(initials, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          SafeArea(child: _buildTechnicianPage(context)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: IgnorePointer(ignoring: false, child: _buildPolishedNav(context)),
            ),
          ),
        ],
      ),
    );
  }

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
    final inactiveColor = Colors.black.withOpacity(0.40);

    final totalWidth = MediaQuery.of(context).size.width;
    final pillHorizontalPadding = (totalWidth * 0.06).clamp(22.0, 160.0);
    final pillWidth = (totalWidth - pillHorizontalPadding * 2).clamp(280.0, 1200.0);

    return SizedBox(
      height: barHeight + effectiveBottom + (fabSize / 2),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pillHorizontalPadding,
            right: pillHorizontalPadding,
            bottom: effectiveBottom,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: CustomPaint(
                  painter: NavBarHighlightPainter(color: Colors.white, cornerRadius: 36.0),
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: pillWidth * 0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(icons[0], size: 24, color: _selectedPage == 0 ? activeLeft : inactiveColor),
                        Icon(icons[1], size: 24, color: _selectedPage == 1 ? activeRight : inactiveColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

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
                    splashColor: (_selectedPage == i ? (i == 0 ? activeLeft : activeRight) : Colors.grey).withOpacity(0.15),
                    highlightColor: Colors.transparent,
                    onTap: () => _onNavTap(i),
                  ),
                ),
              ),
            );
          }),

          Positioned(
            bottom: effectiveBottom + (barHeight / 2) - (fabSize / 2) + 10,
            child: GestureDetector(
              onTap: () async {
                final result = await Get.to(() => const CreateTicketScreen(), transition: Transition.fadeIn, duration: const Duration(milliseconds: 360));
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
                          gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF9D8BFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.2 + glow * 0.25), blurRadius: 20 + glow * 10, spreadRadius: 1 + glow * 1.5, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
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

  Widget _buildTechnicianPage(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;
    final bool isTablet = size.width >= 700 && size.width < 1100;
    final bool isDesktop = size.width >= 1100;
    final scale = (size.width / 400).clamp(0.7, 1.1);

    final query = _searchController.text.toLowerCase();
    final filteredTickets = _tickets.where((t) {
      final statusNorm = (t['status'] ?? 'Pending').toString().trim().toLowerCase();
      final selectedNorm = _selectedStatus.trim().toLowerCase();

      final name = (t['customer_name'] ?? '').toString().toLowerCase();
      final mobile = (t['mobile_number'] ?? '').toString().toLowerCase();
      final model = (t['device_model'] ?? '').toString().toLowerCase();

      final matchesQuery = name.contains(query) || mobile.contains(query) || model.contains(query);
      final matchesStatus = selectedNorm == 'all' || statusNorm == selectedNorm;
      return matchesQuery && matchesStatus;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 1200
            ? constraints.maxWidth * 0.12
            : constraints.maxWidth > 700
                ? constraints.maxWidth * 0.06
                : 18.0;

        final safeBottom = MediaQuery.of(context).viewPadding.bottom;
        final double bottomReserve = safeBottom + _navBottomMargin + (_fabSize * 0.9);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Column(
            children: [
              // Header with technician name + logout menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      "Welcome,",
                      style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _me?['name'] ?? 'Technician',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2A2E45),
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ]),
                  // professional avatar + logout dropdown
                  _buildAvatarMenu(),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              SizedBox(
                height: 44,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Search by name, mobile or model",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13 * scale),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE3E6EF), width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status chips
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: statuses.length,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemBuilder: (context, i) {
                    final status = statuses[i];
                    final isSelected = _selectedStatus == status;
                    return GestureDetector(
                      onTap: () => _onStatusSelected(status),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6D5DF6) : const Color(0xFFF1F3FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            status,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 12 * scale,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: FilterChip(
                  label: Text(_mineOnly ? 'Showing my tickets' : 'Showing all technicians'),
                  selected: _mineOnly,
                  onSelected: (value) {
                    setState(() => _mineOnly = value);
                    _loadTickets();
                  },
                  avatar: Icon(_mineOnly ? Icons.person_pin_circle : Icons.groups,
                      size: 18, color: _mineOnly ? Colors.white : const Color(0xFF6D5DF6)),
                  selectedColor: const Color(0xFF6D5DF6),
                  checkmarkColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),

              // Tickets list
              Expanded(
                child: Stack(
                  children: [
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _loadTickets,
                            child: GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(4, 4, 4, bottomReserve),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 3 : isTablet ? 2 : 1,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: isMobile ? 2.9 : 3.4,
                              ),
                              itemCount: filteredTickets.length,
                              itemBuilder: (context, index) {
                                final t = filteredTickets[index];
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    title: Text(
                                      t["customer_name"] ?? "Unknown Customer",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15 * scale,
                                        color: const Color(0xFF2A2E45),
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        Text("Device: ${t["device_model"] ?? "-"}",
                                            style: GoogleFonts.poppins(fontSize: 13 * scale)),
                                        const SizedBox(height: 4),
                                        Text("Mobile: ${t["mobile_number"] ?? "-"}",
                                            style: GoogleFonts.poppins(fontSize: 13 * scale)),
                                      ],
                                    ),
                                    trailing: _gradientStatusPill(t["status"]?.toString()),
                                    onTap: () async {
                                      await Get.to(() => TicketDetailsScreen(ticket: t),
                                          transition: Transition.fadeIn, duration: const Duration(milliseconds: 300));
                                      await _loadTickets();
                                    },
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

  Widget _gradientStatusPill(String? status) {
    final Map<String, Color> colorMap = {
      "pending": const Color(0xFF7A6FF8),
      "repaired": const Color(0xFF00C6FF),
      "delivered": const Color(0xFF56AB2F),
      "cancelled": const Color(0xFFFF4B2B),
    };

    final raw = status ?? "-";
    final norm = raw.toString().trim().toLowerCase();
    final baseColor = colorMap[norm] ?? Colors.grey.shade500;
    final bgColor = baseColor.withOpacity(0.10);

    final displayText = raw.toString().trim().isEmpty ? "-" : _toTitleCase(raw.toString().trim());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: baseColor.withOpacity(0.15), width: 1),
      ),
      child: Text(
        displayText,
        style: GoogleFonts.poppins(
          color: baseColor.withOpacity(0.9),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'[\s_-]+'));
    return parts.map((p) {
      final low = p.toLowerCase();
      return low.isEmpty ? '' : '${low[0].toUpperCase()}${low.substring(1)}';
    }).join(' ');
  }
}
