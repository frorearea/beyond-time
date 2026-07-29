import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class CandleGlow extends StatefulWidget {
  const CandleGlow({super.key});

  @override
  State<CandleGlow> createState() => _CandleGlowState();
}

class _CandleGlowState extends State<CandleGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: CandleGlowPainter(_controller.value),
        );
      },
    );
  }
}

class CandleGlowPainter extends CustomPainter {
  const CandleGlowPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.44;
    final cy = size.height * 0.28;

    final breathe = math.sin(progress * math.pi * 2);
    final pulse = 0.78 + breathe * 0.22;
    final alpha = (0.035 + breathe.abs() * 0.025).clamp(0.0, 0.06);

    final gradient = RadialGradient(
      center: Alignment(cx / size.width * 2 - 1, cy / size.height * 2 - 1),
      radius: 0.32 * pulse,
      colors: [
        kWhite.withValues(alpha: alpha * 1.8),
        kWhite.withValues(alpha: alpha * 0.5),
        kWhite.withValues(alpha: alpha * 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.55, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant CandleGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}