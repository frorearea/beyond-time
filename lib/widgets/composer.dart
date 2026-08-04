import 'package:flutter/material.dart';

import '../theme.dart';

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.inputController,
    required this.disabled,
    required this.onSend,
    required this.onClear,
    required this.quickCollapsed,
    required this.onQuickCollapseToggle,
  });

  final TextEditingController inputController;
  final bool disabled;
  final Future<void> Function() onSend;
  final VoidCallback onClear;
  final bool quickCollapsed;
  final VoidCallback onQuickCollapseToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xCCFFFFFF))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: TextField(
                  controller: inputController,
                  enabled: !disabled,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  style:
                      const TextStyle(color: kWhite, fontSize: 17, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: '说点什么...',
                    hintStyle: TextStyle(color: Color(0x85FFFFFF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            BorderTextButton(
              label: disabled ? '等待' : '发送',
              onTap: disabled ? null : onSend,
            ),
            BorderTextButton(label: '清空', onTap: onClear),
            CollapseQuickButton(
              collapsed: quickCollapsed,
              onTap: onQuickCollapseToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class BorderTextButton extends StatelessWidget {
  const BorderTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xCCFFFFFF))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? const Color(0x73FFFFFF) : kWhite,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class CollapseQuickButton extends StatelessWidget {
  const CollapseQuickButton({super.key, required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xCCFFFFFF))),
        ),
        child: CustomPaint(
          size: const Size(10, 6),
          painter: CollapseArrowPainter(collapsed: collapsed),
        ),
      ),
    );
  }
}

class CollapseArrowPainter extends CustomPainter {
  const CollapseArrowPainter({required this.collapsed});

  final bool collapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (collapsed) {
      path.moveTo(1, 1);
      path.lineTo(size.width / 2, size.height - 1);
      path.lineTo(size.width - 1, 1);
    } else {
      path.moveTo(1, size.height - 1);
      path.lineTo(size.width / 2, 1);
      path.lineTo(size.width - 1, size.height - 1);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CollapseArrowPainter oldDelegate) =>
      oldDelegate.collapsed != collapsed;
}