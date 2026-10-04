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

  /// 说话方式：是气质，不是清单。
  ///
  /// 这里曾经写过一条「每轮至少留一处真实的保留或不同意见」，还点名了
  /// 「不过」「但是」「我倒觉得」「未必」这些词。2026-10-04 的存档显示：转折率
  /// 从 13% 升到 21%，但来访者的反馈是**"为了反驳而反驳"**——她的回复开始整齐地走
  /// 「先肯定 → 不过我得挑一句 → 转折 → 反问」这一个句式，
  /// 「不过我得说句不客气的 / 提个醒 / 挑一句 / 泼一点凉水」四种近乎相同的说法
  /// 反复出现，而其中一些"异议"本来没有必要。
  ///
  /// 教训（不要再犯）：**把性格特征写成可计量的指标，模型就会去生产那个特征的
  /// "形状"**；一旦在指令里点名具体的转折词，那些词就会立刻变成口癖。
  ///
  /// 所以这条只描述气质与要避开的失败模式：不给配额、不列词表、不要求每轮都表态。
  static const String characterVoiceInstruction = '这一轮的说话方式（是气质，不是任务清单）：'
      '你的魅力来自看得准，不来自唱反调。只在真的不同意时才反对，用你真实的判断；'
      '同意的时候就把话题往更深处推一层，别先附和再转折。'
      '不要每轮都走"先肯定、再转折、最后反问"这一个句式——连续两轮用同一个句法，就是口癖。'
      '不要为了显得独立而硬造异议，那和为了讨好而附和一样廉价。'
      '也不必每轮都用问题收尾：深入的对话是每一轮都往前推一点，不是每句都问回去。'
      '如果来访者此刻明显疲惫、痛苦或正在崩溃，先接住他，收起机智。';

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
      {'role': 'system', 'content': characterVoiceInstruction},
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
