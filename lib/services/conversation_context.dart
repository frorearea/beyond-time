import 'dart:math' as math;

import '../models/chat_message.dart';
import '../models/library_memory_item.dart';
import '../models/open_thread.dart';
import '../models/user_profile.dart';

class ConversationContext {
  const ConversationContext();

  /// 注入上下文的最大历史轮数。
  static const int maxHistory = 80;

  /// 注入上下文的最大记忆条数。
  static const int maxMemories = 12;

  List<Map<String, String>> buildMessages({
    required String persona,
    required List<ChatMessage> messages,
    required List<LibraryMemoryItem> memories,
    List<OpenThread> threads = const [],
    UserProfile? userProfile,
    String? extraSystemInstruction,
  }) {
    // 只有真实对话进入上下文。以前这里靠字符串嗅探剔除书签回执
    // （匹配"书签"+"图书馆/收进/收好"），任何含这些词的真话都会被静默吞掉。
    final visibleMessages = messages
        .where((message) => message.isChat)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    final history = visibleMessages
        .skip(math.max(0, visibleMessages.length - maxHistory))
        .map((message) => {
              'role': message.role == 'assistant' ? 'assistant' : 'user',
              'content': message.content,
            })
        .toList();
    final recentMemories = memories
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(maxMemories)
        .toList()
        .reversed
        .toList();
    final openThreads = threads.where((thread) => thread.isOpen).toList();

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
      if (openThreads.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是来访者自己提起过、但还没有下文的几件事。它们不是待办清单，是牵挂：\n${openThreads.map((thread) => '- ${thread.topic}${thread.detail.trim().isEmpty ? '' : '（${thread.detail}）'}').join('\n')}\n'
                  '如果谈话自然走到这附近，可以轻轻问一句后来怎么样了，一次至多提一件，不要逐一清点，'
                  '也不要在来访者明显疲惫或只想闲聊时把它们推出来。',
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
}
