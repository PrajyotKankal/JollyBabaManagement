import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double? landscapeMaxWidth; // Optional different max width for landscape
  final bool centered;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1200.0, // Default max width for dashboard
    this.landscapeMaxWidth, // If null, uses maxWidth
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    // OrientationBuilder ensures rebuild on orientation change
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final effectiveMaxWidth = isLandscape 
            ? (landscapeMaxWidth ?? maxWidth) 
            : maxWidth;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            // In landscape mobile, use full width for better use of screen real estate
            if (ResponsiveHelper.isMobileLandscape(context)) {
              return child;
            }
            
            if (constraints.maxWidth > effectiveMaxWidth) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            }
            return child;
          },
        );
      },
    );
  }
}

/// A widget that provides different children based on orientation
class OrientationAwareBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isLandscape) builder;
  
  const OrientationAwareBuilder({
    super.key,
    required this.builder,
  });
  
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return builder(context, orientation == Orientation.landscape);
      },
    );
  }
}

/// A widget that shows different layouts for portrait and landscape
class AdaptiveLayout extends StatelessWidget {
  final Widget portrait;
  final Widget landscape;
  
  const AdaptiveLayout({
    super.key,
    required this.portrait,
    required this.landscape,
  });
  
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return orientation == Orientation.landscape ? landscape : portrait;
      },
    );
  }
}
