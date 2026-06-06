import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';

class DialogueBox extends StatelessWidget {
  const DialogueBox({
    super.key,
    required this.messages,
    required this.isSending,
    required this.musicMode,
    required this.quickOptions,
    required this.inputController,
    required this.scrollController,
    required this.selectedBookmarkText,
    required this.onSend,
    required this.onClear,
    required this.onQuickOption,
    required this.onAssistantSelection,
    required this.onBookmarkSelected,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String musicMode;
  final List<String> quickOptions;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final String selectedBookmarkText;
  final Future<void> Function() onSend;
  final VoidCallback onClear;
  final ValueChanged<String> onQuickOption;
  final ValueChanged<String> onAssistantSelection;
  final VoidCallback onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 920,
          decoration:
              BoxDecoration(border: Border.all(color: kWhite), color: kBlack),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  itemBuilder: (context, index) => MessageView(
                    message: messages[index],
                    onAssistantSelection: onAssistantSelection,
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemCount: messages.length,
                ),
              ),
              QuickOptions(
                  options: quickOptions,
                  disabled: isSending,
                  onTap: onQuickOption),
              Composer(
                  inputController: inputController,
                  disabled: isSending,
                  onSend: onSend,
                  onClear: onClear),
            ],
          ),
        ),
        const Positioned(left: 18, top: -52, child: CoffeeCup()),
        if (selectedBookmarkText.isNotEmpty && !isSending)
          Positioned(
            right: 0,
            top: -52,
            child: BookmarkAction(onTap: onBookmarkSelected),
          ),
        if (isSending)
          const Positioned(right: 18, top: -42, child: WritingIndicator()),
      ],
    );
  }
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
    final style = TextStyle(
      color: kWhite,
      fontSize: isPlayer ? 18 : 19,
      height: isPlayer ? 1.5 : 1.48,
      fontFamily: isPlayer ? 'Microsoft YaHei' : 'LXGWWenKai',
      fontFamilyFallback: isPlayer
          ? const ['PingFang SC', 'Noto Sans CJK SC', 'SimHei']
          : const [
              'Microsoft YaHei',
              'SimSun',
            ],
    );
    if (isPlayer) {
      return Text('> ${message.content}', style: style);
    }
    return SelectableText(
      message.content,
      style: style,
      cursorColor: kWhite,
      selectionControls: materialTextSelectionControls,
      onSelectionChanged: (selection, cause) {
        if (selection.isCollapsed) {
          onAssistantSelection('');
          return;
        }
        final selected = selection.textInside(message.content).trim();
        onAssistantSelection(selected);
      },
    );
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
  const QuickOptions(
      {super.key,
      required this.options,
      required this.disabled,
      required this.onTap});

  final List<String> options;
  final bool disabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: kWhite))),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 650 ? 1 : 3;
          return GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 1 ? 8 : 5.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final option in options)
                OutlinedButton(
                  onPressed: disabled ? null : () => onTap(option),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kWhite,
                    side: const BorderSide(color: kWhite),
                    shape: const RoundedRectangleBorder(),
                    alignment: Alignment.centerLeft,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  child: Text(option,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 14, height: 1.35)),
                ),
            ],
          );
        },
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
        decoration:
            const BoxDecoration(border: Border(top: BorderSide(color: kWhite))),
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
                label: disabled ? '等待' : '发送', onTap: disabled ? null : onSend),
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
            border: Border(left: BorderSide(color: kWhite))),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(label,
            style: TextStyle(
                color: onTap == null ? const Color(0x73FFFFFF) : kWhite,
                fontSize: 16)),
      ),
    );
  }
}

class CoffeeCup extends StatelessWidget {
  const CoffeeCup({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(64, 46), painter: CoffeeCupPainter());
  }
}

class CoffeeCupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(10, 16, 34, 22), line);
    canvas.drawArc(const Rect.fromLTWH(42, 21, 14, 12), -1.5, 3.0, false, line);
    canvas.drawLine(const Offset(4, 43), const Offset(56, 43), line);
    canvas.drawArc(const Rect.fromLTWH(16, 0, 8, 16), 2, 2.4, false, line);
    canvas.drawArc(const Rect.fromLTWH(27, 0, 8, 16), 2, 2.4, false, line);
    canvas.drawArc(const Rect.fromLTWH(38, 0, 8, 16), 2, 2.4, false, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WritingIndicator extends StatelessWidget {
  const WritingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: const Size(76, 30), painter: WritingIndicatorPainter());
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
