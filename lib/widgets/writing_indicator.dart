import 'package:flutter/material.dart';

import '../theme.dart';

class WritingIndicator extends StatelessWidget {
  const WritingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(76, 30),
      painter: WritingIndicatorPainter(),
    );
  }
}

class WritingIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(0, 8, 17, 20), line);
    canvas.drawRect(const Rect.fromLTWH(18, 8, 17, 20), line);
    canvas.drawLine(const Offset(0, 29), const Offset(36, 29), line);
    canvas.drawLine(const Offset(48, 20), const Offset(72, 11), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}