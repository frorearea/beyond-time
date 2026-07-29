import 'package:flutter/material.dart';

import '../theme.dart';

class BookmarkAction extends StatelessWidget {
  const BookmarkAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: kBlack,
          border: Border.all(color: kWhite),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RpgBookmarkIcon(),
            SizedBox(width: 7),
            Text(
              '添加书签',
              style: TextStyle(color: kWhite, fontSize: 13, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class RpgBookmarkIcon extends StatelessWidget {
  const RpgBookmarkIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 20),
      painter: RpgBookmarkPainter(),
    );
  }
}

class RpgBookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whiteFill = Paint()
      ..color = kWhite
      ..style = PaintingStyle.fill;
    final whiteLine = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final blackFill = Paint()
      ..color = kBlack
      ..style = PaintingStyle.fill;
    final blackLine = Paint()
      ..color = kBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(4, 1)
      ..lineTo(size.width - 4, 1)
      ..lineTo(size.width - 4, size.height - 2)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(4, size.height - 2)
      ..close();
    canvas.drawPath(path, whiteFill);
    canvas.drawPath(path, whiteLine);
    canvas.drawLine(const Offset(6, 5), Offset(size.width - 6, 5), blackLine);
    canvas.drawLine(const Offset(6, 8), Offset(size.width - 7, 8), blackLine);

    final notch = Path()
      ..moveTo(size.width / 2 - 2, size.height - 5)
      ..lineTo(size.width / 2, size.height - 7)
      ..lineTo(size.width / 2 + 2, size.height - 5)
      ..close();
    canvas.drawPath(notch, blackFill);

    canvas.drawLine(
        Offset(size.width - 2, 2), Offset(size.width - 2, 7), whiteLine);
    canvas.drawLine(Offset(size.width - 4.5, 4.5),
        Offset(size.width + 0.5, 4.5), whiteLine);
    canvas.drawRect(Rect.fromLTWH(1, 3, 2, 2), whiteFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}