import 'dart:math' as math;

import '../models/chat_message.dart';
import '../models/library_memory_item.dart';
import '../models/user_profile.dart';

class ConversationContext {
  const ConversationContext();

  List<Map<String, String>> buildMessages({
    required String persona,
    required List<ChatMessage> messages,
    required List<LibraryMemoryItem> memories,
    UserProfile? userProfile,
    String? extraSystemInstruction,
  }) {
    final visibleMessages = messages
        .where((message) => message.content.trim().isNotEmpty)
        .where((message) => !isBookmarkNoticeMessage(message))
        .where((message) => !message.isAmbient)
        .toList();
    final history = visibleMessages
        .skip(math.max(0, visibleMessages.length - 80))
        .map((message) => {
              'role': message.role == 'assistant' ? 'assistant' : 'user',
              'content': message.content,
            })
        .toList();
    final recentMemories = memories
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .toList();

    return [
      {'role': 'system', 'content': persona},
      if (userProfile != null && userProfile.isMeaningful)
        {'role': 'system', 'content': userProfile.toContextText()},
      if (recentMemories.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是图书馆记忆，包含来访者手动收藏的句子，以及艾蕾塔谨慎整理出的喜好、压力、热爱与困扰。把它们当作轻柔背景，只在自然合适时呼应，不要像系统总结一样复述：\n${recentMemories.map((memory) => '- [${memory.category}] ${memory.content}${memory.evidence.trim().isEmpty ? '' : '（依据：${memory.evidence}）'}').join('\n')}',
        },
      {
        'role': 'system',
        'content':
            '保持对话感和艾蕾塔的角色气质。优先自然回应来访者当前这句话，不要输出 HTML 标签或 Markdown 换行标签；需要换行时直接使用普通换行，绝对不要写 <br>。',
      },
      if (extraSystemInstruction != null &&
          extraSystemInstruction.trim().isNotEmpty)
        {'role': 'system', 'content': extraSystemInstruction.trim()},
      ...history,
    ];
  }

  String cleanReply(String text) {
    return text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool isBookmarkNoticeMessage(ChatMessage message) {
    if (message.role != 'assistant') return false;
    final content = message.content.trim();
    return content.contains('书签') &&
        (content.contains('图书馆') ||
            content.contains('收进') ||
            content.contains('夹进') ||
            content.contains('收好'));
  }
}
