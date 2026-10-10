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

  /// 只有格式限制，没有任何"说话方式"的约束。**这是刻意的，不要往回加。**
  ///
  /// 项目最优先的原则（2026-10-11 定，见 PROJECT.md 第一节）：
  /// **按人设让她最自然地把话说出来；不对她的回答加以限制或判断；不让她的回答去达成
  /// 任何指标。**
  ///
  /// 这里曾经长期塞着一条 `characterVoiceInstruction`（"这一轮的说话方式…"）。
  /// 它前后造成两次事故，都是这条原则的反面教材：
  ///
  /// 1. **2026-10-04**：为了治"附和"给它定了配额（"每轮至少一处真实的保留"）并点名
  ///    「不过」「但是」「我倒觉得」这些词。转折率 13%→21%，但她的回复开始整齐地走
  ///    「先肯定 → 不过我得挑一句 → 转折 → 反问」，还长出了「。不过我得」这个口癖。
  ///    **把性格写成可计量的指标，模型就会生产那个特征的"形状"。**
  /// 2. **2026-10-11**：改成以"看得准"开头（还是判断词），副作用是把她从用意象说话的
  ///    魔女推成了用短句下判断的评论员：同一份存档内按时间切开实测，意象 2.53→1.74/千字，
  ///    ≤8 字碎句 6.7%→12.8%，句长中位 25→21——正是"不优雅了、直白简单、比喻没了"。
  ///
  /// 结论：**行为约束不该逐轮下发。** 她是谁、怎么说话，全部归人设
  /// （`assets/prompts/ereta_persona.txt`）负责；运行时只保留两样东西——
  /// 一是数据的边界（书签不是对他的描述、不许替他改创作稿、不许发明作品名），
  /// 二是下面这条纯格式限制。机械感由 `tool/archive_report.mjs` 去**量**，不是靠 prompt 去要求。
  static const String formatInstruction = '输出格式（只限格式，不涉及内容与语气）：'
      '不要输出 HTML 标签，也不要输出 Markdown 标记（不要用 ** 加粗、# 标题、- 或 1. 列表）；'
      '需要换行时直接使用普通换行，绝对不要写 <br>。';

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
      {'role': 'system', 'content': formatInstruction},
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
