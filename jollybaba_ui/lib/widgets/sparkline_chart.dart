// lib/widgets/sparkline_chart.dart
// Simple sparkline chart widget for inline data visualization

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SparklineChart extends StatelessWidget {
  final List<double> data;
  final double height;
  final double width;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final bool showDots;
  final int animationDelay;

  const SparklineChart({
    super.key,
    required this.data,
    this.height = 40,
    this.width = 100,
    this.lineColor = const Color(0xFF6D5DF6),
    Color? fillColor,
    this.strokeWidth = 2,
    this.showDots = false,
    this.animationDelay = 0,
  }) : fillColor = fillColor ?? const Color(0x200D7C4A);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.length < 2) {
      return SizedBox(width: width, height: height);
    }

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          lineColor: lineColor,
          fillColor: fillColor,
          strokeWidth: strokeWidth,
          showDots: showDots,
        ),
      ),
    ).animate(delay: animationDelay.ms)
      .fadeIn(duration: 500.ms)
      .slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final bool showDots;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.showDots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final valueRange = maxValue - minValue;
    
    // Avoid division by zero
    final normalizedData = valueRange == 0
        ? data.map((v) => 0.5).toList()
        : data.map((v) => (v - minValue) / valueRange).toList();

    final stepX = size.width / (data.length - 1);
    final padding = 4.0;
    final effectiveHeight = size.height - (padding * 2);

    // Create path for line
    final linePath = Path();
    final fillPath = Path();

    for (var i = 0; i < normalizedData.length; i++) {
      final x = i * stepX;
      final y = padding + (1 - normalizedData[i]) * effectiveHeight;
      
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Draw dots
    if (showDots) {
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      
      for (var i = 0; i < normalizedData.length; i++) {
        final x = i * stepX;
        final y = padding + (1 - normalizedData[i]) * effectiveHeight;
        canvas.drawCircle(Offset(x, y), strokeWidth + 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || 
           oldDelegate.lineColor != lineColor ||
           oldDelegate.fillColor != fillColor;
  }
}

/// Stat card with embedded sparkline
class SparklineStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> sparkData;
  final String? subtitle;
  final int animationDelay;

  const SparklineStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.sparkData,
    this.subtitle,
    this.animationDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (sparkData.isNotEmpty)
                SparklineChart(
                  data: sparkData,
                  height: 28,
                  width: 60,
                  lineColor: color,
                  fillColor: color.withOpacity(0.1),
                  strokeWidth: 1.5,
                  animationDelay: animationDelay + 200,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2343),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    ).animate(delay: animationDelay.ms)
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.15, curve: Curves.easeOutCubic);
  }
}
