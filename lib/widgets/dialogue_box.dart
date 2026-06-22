import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';

class DialogueBox extends StatefulWidget {
  const DialogueBox({
    super.key,
    required this.messages,
    required this.isSending,
    required this.quickOptions,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
    required this.onClear,
    required this.onQuickOption,
    required this.onRefreshQuickOptions,
    required this.onBookmarkSelected,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final List<String> quickOptions;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final Future<void> Function() onSend;
  final VoidCallback onClear;
  final ValueChanged<String> onQuickOption;
  final VoidCallback onRefreshQuickOptions;
  final ValueChanged<String> onBookmarkSelected;

  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox> {
  final ValueNotifier<String> _selectedBookmarkText = ValueNotifier('');
  final GlobalKey _boxKey = GlobalKey();
  OverlayEntry? _bookmarkOverlay;
  Timer? _selectionClearTimer;

  @override
  void dispose() {
    _selectionClearTimer?.cancel();
    _removeBookmarkOverlay();
    _selectedBookmarkText.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSending && !oldWidget.isSending) {
      _removeBookmarkOverlay();
    }
  }

  void _handleAssistantSelection(String text) {
    if (text.trim().isEmpty) {
      _scheduleBookmarkOverlayRemoval();
      return;
    }
    _selectionClearTimer?.cancel();
    if (_selectedBookmarkText.value == text) return;
    _selectedBookmarkText.value = text;
    _showBookmarkOverlay();
  }

  void _bookmarkSelectedText() {
    _selectionClearTimer?.cancel();
    final selected = _selectedBookmarkText.value.trim();
    if (selected.isEmpty) return;
    _selectedBookmarkText.value = '';
    _removeBookmarkOverlay();
    widget.onBookmarkSelected(selected);
  }

  void _showBookmarkOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isSending || _selectedBookmarkText.value.isEmpty) {
        return;
      }
      final renderBox =
          _boxKey.currentContext?.findRenderObject() as RenderBox?;
      final overlay = Overlay.of(context);
      if (renderBox == null) return;
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      _removeBookmarkOverlay();
      _bookmarkOverlay = OverlayEntry(
        builder: (context) {
          return Positioned(
            left: offset.dx + size.width - 118,
            top: offset.dy - 52,
            child: BookmarkAction(onTap: _bookmarkSelectedText),
          );
        },
      );
      overlay.insert(_bookmarkOverlay!);
    });
  }

  void _scheduleBookmarkOverlayRemoval() {
    _selectionClearTimer?.cancel();
    _selectionClearTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _selectedBookmarkText.value = '';
      _removeBookmarkOverlay();
    });
  }

  void _removeBookmarkOverlay() {
    _bookmarkOverlay?.remove();
    _bookmarkOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          key: _boxKey,
          width: 920,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: kWhite, width: 1.2),
              color: kBlack,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80FFFFFF),
                  blurRadius: 7,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    foregroundPainter: DialogueFramePainter(),
                    child: Column(
                      children: [
                        const DialogueTopRule(),
                        Expanded(
                          child: ListView.separated(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
                            itemBuilder: (context, index) => MessageView(
                              message: widget.messages[index],
                              onAssistantSelection: _handleAssistantSelection,
                            ),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 11),
                            itemCount: widget.messages.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                QuickOptions(
                  options: widget.quickOptions,
                  disabled: widget.isSending,
                  onTap: widget.onQuickOption,
                  onRefresh: widget.onRefreshQuickOptions,
                ),
                Composer(
                  inputController: widget.inputController,
                  disabled: widget.isSending,
                  onSend: widget.onSend,
                  onClear: widget.onClear,
                ),
              ],
            ),
          ),
        ),
        const Positioned(left: 18, top: -52, child: CoffeeCup()),
        if (widget.isSending)
          const Positioned(right: 18, top: -42, child: WritingIndicator()),
      ],
    );
  }
}

class DialogueTopRule extends StatelessWidget {
  const DialogueTopRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(child: DecorLine()),
          SizedBox(width: 10),
          Text(
            'Ereta Library Record',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 11,
              fontFamily: 'CormorantGaramond',
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: DecorLine()),
        ],
      ),
    );
  }
}

class DecorLine extends StatelessWidget {
  const DecorLine({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 5),
      painter: DecorLinePainter(),
    );
  }
}

class DecorLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      line,
    );
    canvas.drawCircle(Offset(size.width - 3, size.height / 2), 1.5, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DialogueFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final faintLine = Paint()
      ..color = const Color(0x3DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      faintLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.message,
    required this.onAssistantSelection,
  });

  final ChatMessage message;
  final ValueChanged<String> onAssistantSelection;

  @override
  Widget build(BuildContext context) {
    final isPlayer = message.role == 'user';
    final content = _displayContent(message.content);
    final style = TextStyle(
      color: kWhite,
      fontSize: isPlayer ? 18 : 19,
      height: isPlayer ? 1.5 : 1.48,
      fontFamily: isPlayer ? 'Microsoft YaHei' : 'LXGWWenKai',
      fontFamilyFallback: isPlayer
          ? const ['PingFang SC', 'Noto Sans CJK SC', 'SimHei']
          : const ['Microsoft YaHei', 'SimSun'],
    );
    if (isPlayer) {
      return Text('> $content', style: style);
    }
    return TextSelectionTheme(
      data: const TextSelectionThemeData(
        cursorColor: kWhite,
        selectionColor: Color(0x4DFFFFFF),
        selectionHandleColor: kWhite,
      ),
      child: SelectableText(
        content,
        style: style,
        cursorColor: kWhite,
        selectionHeightStyle: BoxHeightStyle.tight,
        selectionWidthStyle: BoxWidthStyle.tight,
        selectionControls: materialTextSelectionControls,
        onSelectionChanged: (selection, cause) {
          if (selection.isCollapsed) {
            onAssistantSelection('');
            return;
          }
          final selected = selection.textInside(content).trim();
          if (selected.isEmpty) {
            onAssistantSelection('');
            return;
          }
          onAssistantSelection(selected);
        },
      ),
    );
  }

  String _displayContent(String text) {
    return text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

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

class QuickOptions extends StatelessWidget {
  const QuickOptions({
    super.key,
    required this.options,
    required this.disabled,
    required this.onTap,
    required this.onRefresh,
  });

  final List<String> options;
  final bool disabled;
  final ValueChanged<String> onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xCCFFFFFF))),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 650) {
            return GridView.count(
              crossAxisCount: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in options)
                  _QuickOptionButton(
                    label: option,
                    disabled: disabled,
                    onTap: () => onTap(option),
                  ),
                _RefreshOptionsButton(disabled: disabled, onTap: onRefresh),
              ],
            );
          }

          return SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in options) ...[
                  Expanded(
                    child: _QuickOptionButton(
                      label: option,
                      disabled: disabled,
                      onTap: () => onTap(option),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  width: 78,
                  child: _RefreshOptionsButton(
                    disabled: disabled,
                    onTap: onRefresh,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickOptionButton extends StatelessWidget {
  const _QuickOptionButton({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: Color(0xCCFFFFFF)),
        shape: const RoundedRectangleBorder(),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
    );
  }
}

class _RefreshOptionsButton extends StatelessWidget {
  const _RefreshOptionsButton({
    required this.disabled,
    required this.onTap,
  });

  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: Color(0x99FFFFFF)),
        shape: const RoundedRectangleBorder(),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      child: const Text(
        '换一组',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, height: 1.15),
      ),
    );
  }
}

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.inputController,
    required this.disabled,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController inputController;
  final bool disabled;
  final Future<void> Function() onSend;
  final VoidCallback onClear;

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
