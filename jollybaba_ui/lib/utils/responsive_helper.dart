import 'package:flutter/material.dart';

/// Responsive design helper class for consistent breakpoints and utilities across the app.
class ResponsiveHelper {
  // Screen size breakpoints
  static const double mobileMax = 599;
  static const double tabletMin = 600;
  static const double tabletMax = 1199;
  static const double desktopMin = 1200;

  /// Determine device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < tabletMin) {
      return DeviceType.mobile;
    } else if (width < desktopMin) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  /// Check if this is a mobile device in landscape (special case - needs different layout)
  static bool isMobileLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    // Mobile landscape: height is small (was width in portrait), landscape mode
    return orientation == Orientation.landscape && size.height < 500;
  }
  
  /// Get effective device type considering orientation
  /// Mobile in landscape behaves more like tablet
  static DeviceType getEffectiveDeviceType(BuildContext context) {
    if (isMobileLandscape(context)) {
      return DeviceType.tablet; // Treat mobile landscape as tablet for layout
    }
    return getDeviceType(context);
  }

  /// Get responsive padding based on device type and orientation
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getEffectiveDeviceType(context);
    final isLand = isLandscape(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return EdgeInsets.symmetric(
          horizontal: isLand ? 24 : 16, 
          vertical: isLand ? 8 : 12,
        );
      case DeviceType.tablet:
        return EdgeInsets.symmetric(
          horizontal: isLand ? 32 : 24, 
          vertical: isLand ? 12 : 16,
        );
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseMobileSize) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 400).clamp(0.8, 1.3);
    return baseMobileSize * scale;
  }

  /// Get responsive grid columns based on device type and orientation
  static int getGridColumns(BuildContext context) {
    final deviceType = getEffectiveDeviceType(context);
    final isLand = isLandscape(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLand ? 2 : 1; // 2 columns in landscape
      case DeviceType.tablet:
        return isLand ? 3 : 2;
      case DeviceType.desktop:
        return 3;
    }
  }

  /// Get responsive card spacing
  static double getCardSpacing(BuildContext context) {
    final deviceType = getEffectiveDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return 12;
      case DeviceType.tablet:
        return 16;
      case DeviceType.desktop:
        return 20;
    }
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    final deviceType = getEffectiveDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return 12;
      case DeviceType.tablet:
        return 14;
      case DeviceType.desktop:
        return 16;
    }
  }

  /// Get max width for content on large screens
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 1200;
    if (width > 1200) return 1000;
    return width - 32;
  }

  /// Get responsive list item height - smaller in landscape
  static double getListItemHeight(BuildContext context) {
    final deviceType = getEffectiveDeviceType(context);
    final isLand = isLandscape(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLand ? 80 : 100;
      case DeviceType.tablet:
        return isLand ? 90 : 110;
      case DeviceType.desktop:
        return 120;
    }
  }
  
  /// Get available height for content (excluding app bar, nav bar, etc.)
  static double getAvailableHeight(BuildContext context, {double headerHeight = 56, double bottomNav = 80}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    return screenHeight - headerHeight - bottomNav - padding.top - padding.bottom;
  }
  
  /// Check if we should use compact mode (landscape mobile or very small screens)
  static bool useCompactMode(BuildContext context) {
    return isMobileLandscape(context) || MediaQuery.of(context).size.height < 600;
  }
}

enum DeviceType { mobile, tablet, desktop }
