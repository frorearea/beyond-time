import 'dart:math' as math;

import '../models/chat_message.dart';
import '../models/creation_note.dart';
import '../models/library_memory_item.dart';
import '../models/open_thread.dart';
import '../models/user_profile.dart';
import 'memory_selector.dart';

class ConversationContext {
  const ConversationContext({this.memorySelector = const MemorySelector()});

  final MemorySelector memorySelector;

  /// 注入上下文的最大历史轮数。
  static const int maxHistory = 80;

  /// 反谄媚的回合纪律。
  ///
  /// 2026-09-12 与 2026-09-17 两份真实存档里，35% / 30% 的回复以附和词开头，
  /// 只有 10% / 13% 含转折或保留意见——两个月没动，说明光靠人设措辞推不动。
  /// 这里显式点出体检工具真正在量的那两个特征：**别用承接词起手**，
  /// 以及**每轮至少一处真实的保留**。同时给出两条刹车：来访者明显痛苦时不抬杠，
  /// 以及不许为反对而反对——为指标而抬杠会毁掉这个空间。
  static const String antiFlatteryInstruction = '这一轮的说话纪律（优先级高于讨好）：'
      '不要用「确实」「说得对」「这句话」「这」「因为」「我懂」「我理解」这类承接词开头，'
      '第一句就直接给出你的判断、补充或异议。'
      '每轮至少留一处真实的保留或不同意见，用「不过」「但是」「可是」「我倒觉得」「未必」「不见得」把'
      '你自己和来访者的话分开。'
      '但如果来访者此刻明显疲惫、痛苦或正在崩溃，先接住他，不要抬杠；'
      '也不要为了显得独立而硬造异议——那只是另一种讨好的姿势。';

  List<Map<String, String>> buildMessages({
    required String persona,
    required List<ChatMessage> messages,
    required List<LibraryMemoryItem> memories,
    List<OpenThread> threads = const [],
    List<CreationNote> creations = const [],
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

    // 记忆按当前话题打分取，而不是"最近 N 条"；事实与书签分栏配额，
    // 书签不再挤占"她到底认不认识这个人"的预算。
    final selected = memorySelector.select(
      memories: memories,
      query: memorySelector.buildQuery(visibleMessages),
    );
    final facts = selected.where((memory) => memory.isKnowledge).toList();
    final bookmarks = selected.where((memory) => memory.isBookmark).toList();

    final openThreads = threads.where((thread) => thread.isOpen).toList();
    final keptCreations = creations
        .where((note) => note.title.trim().isNotEmpty)
        .toList();

    return [
      {'role': 'system', 'content': persona},
      if (userProfile != null && userProfile.isMeaningful)
        {'role': 'system', 'content': userProfile.toContextText()},
      if (facts.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是图书馆记忆——艾蕾塔谨慎整理出的关于来访者的事实（喜好、压力、热爱、困扰、创作计划、自我理解）。'
                  '把它们当作轻柔背景，只在自然合适时呼应，不要像系统总结一样复述，也不要逐条清点：\n'
                  '${facts.map((memory) => '- [${memory.category}] ${memory.content}${memory.evidence.trim().isEmpty ? '' : '（依据：${memory.evidence}）'}').join('\n')}',
        },
      if (bookmarks.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是来访者亲手收进图书馆的句子（他自己的收藏）。它们是他说过或愿意留住的字，'
                  '不是对他的描述：可以当成你确实说过的话，但不要据此给他贴标签，也不必刻意提起，'
                  '除非此刻的话题正好落在附近：\n'
                  '${bookmarks.map((memory) => '- ${memory.content}').join('\n')}',
        },
      if (openThreads.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是来访者自己提起过、但还没有下文的几件事。它们不是待办清单，是牵挂：\n${openThreads.map((thread) => '- ${thread.topic}${thread.detail.trim().isEmpty ? '' : '（${thread.detail}）'}').join('\n')}\n'
                  '如果谈话自然走到这附近，可以轻轻问一句后来怎么样了，一次至多提一件，不要逐一清点，'
                  '也不要在来访者明显疲惫或只想闲聊时把它们推出来。',
        },
      if (keptCreations.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是来访者自己留在图书馆里的创作（他亲手写下的名字、设定与片段）。这是他的东西，不是你的：\n'
                  '${keptCreations.map((note) => '- 「${note.title}」[${note.kind}]${note.content.trim().isEmpty ? '' : '：${note.content}'}').join('\n')}\n'
                  '你可以引用、可以顺着聊、可以挑剔，但绝不要替他改写或补全，也不要宣称那是你写的，'
                  '更不要把它记成你的收藏。若他提起其中一份，先问他想往哪儿走，再谈你的看法。',
        },
      {
        'role': 'system',
        'content':
            '保持对话感和艾蕾塔的角色气质。优先自然回应来访者当前这句话，不要输出 HTML 标签或 Markdown 换行标签；需要换行时直接使用普通换行，绝对不要写 <br>。',
      },
      {'role': 'system', 'content': antiFlatteryInstruction},
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
