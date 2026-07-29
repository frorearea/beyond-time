import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';
import 'bookmark_action.dart';
import 'coffee_cup.dart';
import 'composer.dart';
import 'message_view.dart';
import 'quick_options.dart';
import 'writing_indicator.dart';

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
    this.storybookMode = false,
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
  final bool storybookMode;

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
              border: Border.all(
                color: widget.storybookMode ? const Color(0x70FFFFFF) : kWhite,
                width: widget.storybookMode ? 1 : 1.2,
              ),
              color: kBlack,
              boxShadow: widget.storybookMode
                  ? const []
                  : const [
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
                    foregroundPainter:
                        widget.storybookMode ? null : DialogueFramePainter(),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: [
                              const DialogueTopRule(),
                              Expanded(
                                child: ListView.separated(
                                  controller: widget.scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    28,
                                    16,
                                    28,
                                    widget.storybookMode ? 74 : 12,
                                  ),
                                  itemBuilder: (context, index) => MessageView(
                                    message: widget.messages[index],
                                    onAssistantSelection:
                                        _handleAssistantSelection,
                                  ),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 11),
                                  itemCount: widget.messages.length,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.storybookMode)
                          const Positioned(
                            right: 22,
                            bottom: 16,
                            child: CoffeeCup(),
                          ),
                        if (widget.storybookMode && widget.isSending)
                          const Positioned(
                            right: 20,
                            top: 18,
                            child: WritingIndicator(),
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
        if (!widget.storybookMode)
          const Positioned(left: 18, top: -52, child: CoffeeCup()),
        if (!widget.storybookMode && widget.isSending)
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
