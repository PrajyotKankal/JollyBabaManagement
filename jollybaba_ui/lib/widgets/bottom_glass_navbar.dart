// lib/widgets/bottom_glass_navbar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../screens/create_ticket_screen.dart';

class BottomGlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final AnimationController glowController;
  final Animation<double> glowAnimation;

  /// How much space from the bottom of the screen (safe area applied)
  final double bottomPadding;

  /// width of the bar; if null, uses full width minus horizontalMargin
  final double? width;

  /// horizontal margin around the bar
  final double horizontalMargin;

  const BottomGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.glowController,
    required this.glowAnimation,
    this.bottomPadding = 55,
    this.width,
    this.horizontalMargin = 20,
  });

  @override
  Widget build(BuildContext context) {
    // The whole widget is an Align inside the safe area so it floats above content.
    return SafeArea(
      bottom: false, // we'll manage bottom space ourselves
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            width: width ?? MediaQuery.of(context).size.width - horizontalMargin * 2,
            // The nav + floating add button are composed in a Stack so + button overlaps the bar
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Glass bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _navIcon(Icons.dashboard_rounded, 0),
                          // spacer so there is room for the floating button
                          const SizedBox(width: 56),
                          _navIcon(Icons.settings_rounded, 1),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Add Button (centered and overlapping the bar)
                Positioned(
                  top: -28, // pushes the button up so it overlaps the bar
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Get.to(
                        () => const CreateTicketScreen(),
                        transition: Transition.fadeIn,
                        duration: const Duration(milliseconds: 400),
                      );
                      if (result == true) {
                        // optional: trigger refresh via callback or global state
                      }
                    },
                    child: AnimatedBuilder(
                      animation: glowController,
                      builder: (context, _) {
                        final glow = glowAnimation.value;
                        return Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6D5DF6), Color(0xFF9D8BFE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6D5DF6).withOpacity(0.35 + glow * 0.25),
                                blurRadius: 22,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOutBack);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF6D5DF6) : Colors.black54,
          size: 22,
        ),
      ),
    );
  }
}
