import 'package:flutter/material.dart';

/// Paints a soft static highlight on top of the nav pill.
class NavBarHighlightPainter extends CustomPainter {
  final Color color;
  final double cornerRadius;
  const NavBarHighlightPainter({this.color = const Color(0xFFFFFFFF), this.cornerRadius = 36.0});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.6);
    paint.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0F000000), Color(0x00000000)]).createShader(rect);
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(cornerRadius));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = Colors.transparent);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant NavBarHighlightPainter old) => old.color != color || old.cornerRadius != cornerRadius;
}
