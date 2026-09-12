import 'package:flutter/material.dart';

/// 书卷布局中央的「时间之外 / BEYOND TIME」标题与两侧细线。
class StorybookTitle extends StatelessWidget {
  const StorybookTitle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 30 : 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: compact ? 20 : 36, child: const _TitleLine()),
          SizedBox(width: compact ? 8 : 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '时间之外',
                style: TextStyle(
                  fontSize: compact ? 15 : 20,
                  height: 1.1,
                  letterSpacing: compact ? 4 : 6,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: const ['STSong', 'SimSun', 'STKaiti'],
                  color: const Color(0xF0FFFFFF),
                  shadows: const [
                    Shadow(
                      color: Color(0x30FFFFFF),
                      offset: Offset(0, 0),
                      blurRadius: 8,
                    ),
                    Shadow(
                      color: Color(0x80000000),
                      offset: Offset(0.5, 0.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                const Text(
                  'BEYOND TIME',
                  style: TextStyle(
                    fontSize: 9,
                    height: 0.9,
                    letterSpacing: 3.6,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'CormorantGaramond',
                    fontStyle: FontStyle.italic,
                    color: Color(0x88FFFFFF),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(width: compact ? 8 : 12),
          SizedBox(width: compact ? 20 : 36, child: const _TitleLine()),
        ],
      ),
    );
  }
}

class _TitleLine extends StatelessWidget {
  const _TitleLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 10),
      painter: _TitleLinePainter(),
    );
  }
}

class _TitleLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final paint1 = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, mid), Offset(size.width - 4, mid), paint1);
    canvas.drawCircle(Offset(size.width - 2, mid), 1.0, paint1);
    final paint2 = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.4;
    canvas.drawLine(
        Offset(0, mid - 2.5), Offset(size.width - 1, mid - 2.5), paint2);
    canvas.drawLine(
        Offset(0, mid + 2.5), Offset(size.width - 1, mid + 2.5), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
