import 'package:flutter/material.dart';

/// 🎨 Premium Color Palette for JollyBaba App
/// Combines light whites, soft blues, and gradient accents
/// for a minimal, elegant, and premium look.
class AppColors {
  // 🌈 Main App Gradient — used for buttons, highlights, or headers
  static const LinearGradient gradientBluePurple = LinearGradient(
    colors: [
      Color(0xFF7C83FD), // soft royal blue
      Color(0xFF96A5FF), // light periwinkle
      Color(0xFFC9D6FF), // pale lavender for smooth blending
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 💫 Light Background Gradient (used for whole screens)
  static const LinearGradient gradientSoftWhiteBlue = LinearGradient(
    colors: [
      Color(0xFFF9FBFF), // off-white
      Color(0xFFF3F6FF), // light blue tint
      Color(0xFFEFF3FF), // faint bluish glow
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 🎨 Solid Background (neutral white with slight blue warmth)
  static const Color background = Color(0xFFF7F9FF);

  // 🩵 Accent Blue (for icons, links, highlights)
  static const Color accentBlue = Color(0xFF6D5DF6);

  // 💜 Accent Purple (for secondary gradient edge)
  static const Color accentPurple = Color(0xFF8A8EFF);

  // 🩶 Subtle Border Grey (for text field outlines)
  static const Color borderGrey = Color(0xFFE3E6EF);

  // ⚫ Text Colors
  static const Color textPrimary = Color(0xFF1E2343); // dark navy
  static const Color textSecondary = Color(0xFF5B5F77); // soft grey-blue
  static const Color textLight = Color(0xFF9CA3AF); // muted placeholder

  // 💎 Shadows (for cards & buttons)
  static final BoxShadow softShadow = BoxShadow(
    color: Colors.blueGrey.withOpacity(0.1),
    blurRadius: 15,
    offset: const Offset(0, 8),
  );

  // 🌤️ Subtle Card Gradient (used for elevated white surfaces)
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF3F6FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
