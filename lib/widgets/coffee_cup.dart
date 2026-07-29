import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class CoffeeCup extends StatefulWidget {
  const CoffeeCup({super.key});

  @override
  State<CoffeeCup> createState() => _CoffeeCupState();
}

class _CoffeeCupState extends State<CoffeeCup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _steamController;

  @override
  void initState() {
    super.initState();
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
  }

  @override
  void dispose() {
    _steamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _steamController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(64, 46),
          painter: CoffeeCupPainter(_steamController.value),
        );
      },
    );
  }
}

class CoffeeCupPainter extends CustomPainter {
  const CoffeeCupPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(10, 16, 34, 22), line);
    canvas.drawArc(const Rect.fromLTWH(42, 21, 14, 12), -1.5, 3.0, false, line);
    canvas.drawLine(const Offset(4, 43), const Offset(56, 43), line);

    const activePortion = 0.45;
    if (progress > activePortion) return;

    final steamProgress = progress / activePortion;
    final rise = steamProgress * 13;
    final opacity = steamProgress < 0.18
        ? steamProgress / 0.18
        : steamProgress > 0.58
            ? math.max(0.0, (1 - steamProgress) / 0.42)
            : 1.0;
    for (var i = 0; i < 3; i++) {
      final x = 19.0 + i * 11.0;
      final steam = Paint()
        ..color = kWhite.withValues(alpha: 0.18 + opacity * 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromLTWH(x - 4, 4 - rise - i * 0.35, 8, 15);
      canvas.drawArc(rect, 2.05, 2.2, false, steam);
    }
  }

  @override
  bool shouldRepaint(covariant CoffeeCupPainter oldDelegate) =>
      oldDelegate.progress != progress;
}