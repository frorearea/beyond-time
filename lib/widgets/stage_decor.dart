import 'package:flutter/material.dart';

import '../theme.dart';

class TopTextButton extends StatelessWidget {
  const TopTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(color: kWhite, fontSize: 14, height: 1),
      ),
    );
  }
}

class SkyLines extends StatelessWidget {
  const SkyLines({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(left: 26, top: 44, child: MoonMark()),
        Positioned(left: 92, top: 182, child: StarMark(size: 22, rotate: true)),
        Positioned(
            left: 44, bottom: 64, child: StarMark(size: 18, rotate: true)),
        Positioned(right: 34, top: 62, child: StarMark(size: 34)),
        Positioned(
            right: 86, top: 178, child: StarMark(size: 24, rotate: true)),
        Positioned(right: 48, bottom: 54, child: StarMark(size: 18)),
      ],
    );
  }
}

class MoonMark extends StatelessWidget {
  const MoonMark({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(92, 76), painter: MoonPainter());
  }
}

class MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(38, 38), 37, paint);
    final cover = Paint()..color = kBlack;
    canvas.drawCircle(const Offset(61, 38), 37, cover);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarMark extends StatelessWidget {
  const StarMark({super.key, required this.size, this.rotate = false});

  final double size;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    final child = CustomPaint(size: Size.square(size), painter: StarPainter());
    return rotate ? Transform.rotate(angle: 0.785, child: child) : child;
  }
}

class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kWhite
      ..strokeWidth = 2;
    final center = size.width / 2;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), paint);
    canvas.drawLine(Offset(0, center), Offset(size.width, center), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WitchPortrait extends StatelessWidget {
  const WitchPortrait({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ereta-cropped-display.webp',
      fit: BoxFit.contain,
      width: 760,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

class SloganQuote extends StatelessWidget {
  const SloganQuote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 34,
                    height: 1,
                    fontFamily: 'Georgia',
                  ),
                ),
                Expanded(
                  child: Text(
                    'I offer you the bitterness of a man who has looked long and long at the lonely moon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xE8FFFFFF),
                      fontSize: 20,
                      height: 1.18,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'CormorantGaramond',
                      fontFamilyFallback: [
                        'Palatino Linotype',
                        'Georgia',
                        'Times New Roman',
                      ],
                    ),
                  ),
                ),
                Text(
                  '”',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 34,
                    height: 1,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '我给你一个久久地望着孤月的人的悲哀。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 14,
                height: 1.42,
                fontFamily: 'LXGWWenKai',
                fontFamilyFallback: [
                  'Microsoft YaHei',
                  'SimSun',
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'What Can I Hold You with?',
              style: TextStyle(
                color: Color(0x7AFFFFFF),
                fontSize: 11,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
