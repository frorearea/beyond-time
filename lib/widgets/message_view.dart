import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';

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
      fontFamily: isPlayer ? 'SimHei' : 'LXGWWenKai',
      fontFamilyFallback: isPlayer
          ? const ['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC']
          : const ['STSong', 'Songti SC', 'Noto Serif CJK SC', 'SimSun', 'serif'],
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