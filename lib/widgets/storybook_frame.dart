import 'package:flutter/material.dart';

import '../theme.dart';
import 'candle_glow.dart';
import 'stage_decor.dart';

class StorybookFrame extends StatelessWidget {
  const StorybookFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kBlack,
        border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30FFFFFF),
            blurRadius: 18,
            spreadRadius: -8,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: const StorybookFramePainter(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}

class StorybookFramePainter extends CustomPainter {
  const StorybookFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x70FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromLTWH(6.5, 6.5, size.width - 13, size.height - 13),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StorybookPortraitPanel extends StatelessWidget {
  const StorybookPortraitPanel({
    super.key,
    this.showQuote = true,
  });

  final bool showQuote;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: kBlack),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SkyLines(),
            const CandleGlow(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                showQuote ? 12 : 36,
                8,
                showQuote ? 12 : 36,
                showQuote ? 86 : 8,
              ),
              child: Image.asset(
                'assets/images/ereta-cropped-display.webp',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
            if (showQuote)
              const Align(
                alignment: Alignment.bottomCenter,
                child: _PortraitQuote(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortraitQuote extends StatelessWidget {
  const _PortraitQuote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(0xE6000000),
            kBlack,
          ],
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '“ 我给你一个久久地望着孤月的人的悲哀。 ”',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 15,
              height: 1.45,
              fontFamily: 'LXGWWenKai',
              fontFamilyFallback: ['Microsoft YaHei', 'SimSun'],
            ),
          ),
          SizedBox(height: 5),
          Text(
            'WHAT CAN I HOLD YOU WITH?',
            style: TextStyle(
              color: Color(0x70FFFFFF),
              fontSize: 9,
              letterSpacing: 2.1,
              fontFamily: 'CormorantGaramond',
            ),
          ),
        ],
      ),
    );
  }
}

class StorybookSpine extends StatelessWidget {
  const StorybookSpine({super.key, this.vertical = true});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (!vertical) {
      return const SizedBox(
        height: 14,
        child: Center(
          child: Divider(height: 1, color: Color(0x99FFFFFF)),
        ),
      );
    }
    return SizedBox(
      width: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1, color: const Color(0x99FFFFFF)),
          Container(width: 7, color: kBlack),
          Container(width: 1, color: const Color(0x55FFFFFF)),
          const Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SpineDiamond(),
              _SpineDiamond(),
              _SpineDiamond(),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpineDiamond extends StatelessWidget {
  const _SpineDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: kBlack,
          border: Border.all(color: const Color(0x99FFFFFF)),
        ),
      ),
    );
  }
}
