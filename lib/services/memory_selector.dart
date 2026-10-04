import '../config.dart';
import '../models/chat_message.dart';
import '../models/library_memory_item.dart';

/// 记忆注入的挑选策略：按当前话题挑选 + 分栏配额。
///
/// 之前是"把最近 12 条倒序塞进去"。问题在 2026-09-17 的存档里暴露得很清楚：
/// 23 条记忆里有 15 条是书签，于是注入额度大半被金句占掉——她记得住自己的
/// 漂亮话，却越来越不认识坐在对面的人。
///
/// 现在的策略有两条：
/// 1. **按话题挑选**：把最近几轮来访者说过的话当查询，算每条记忆的话题覆盖度。
///    切题的记忆优先，切题者之间比相关度，其余按时间新旧补齐。
/// 2. **分栏配额**：事实与书签各自有上限，谁也不能挤占谁的预算。
///
/// 刻意不把"相关度"和"时间新旧"加权成一个分数：两者量纲差得太远
/// （相关度在中文短句上天然只有零点几，而时间权重一上来就接近 1），
/// 加权的实际结果是时间压过一切，等于没做检索。分成两级就没有这个问题：
/// 没有话题信号时全部落到第二级，行为退化成"最近优先"，不会比以前更差。
///
/// 纯函数（不碰网络、不碰存储、不 import flutter），可以零依赖单测。
class MemorySelector {
  const MemorySelector();

  /// 打分时回看的最近消息条数。
  static const int queryWindow = 4;

  /// 相关度达到多少算"切题"。
  ///
  /// 中文短句的字符二元组覆盖率天然偏低（一句 20 字的话对上一段 45 字的记忆，
  /// 覆盖度能有 0.15 就已经是同一件事了），所以这个门槛刻意定得低。
  /// 它的作用不是精确排序，而是把"说到他正在说的事"和"只是碰巧有几个字重合"
  /// 分开。
  static const double topicThreshold = 0.08;

  /// 挑选要注入的记忆，按时间顺序（旧 → 新）返回，便于 prompt 稳定。
  List<LibraryMemoryItem> select({
    required List<LibraryMemoryItem> memories,
    String query = '',
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final usable = memories
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList(growable: false);

    final facts = <LibraryMemoryItem>[];
    final bookmarks = <LibraryMemoryItem>[];
    for (final memory in usable) {
      (memory.isBookmark ? bookmarks : facts).add(memory);
    }

    final picked = <LibraryMemoryItem>[
      ..._top(facts, kMaxInjectedFacts, query, reference),
      ..._top(bookmarks, kMaxInjectedBookmarks, query, reference),
    ];
    // 恢复原始顺序（记忆列表本身就是按写入时间追加的）。
    final order = <String, int>{};
    for (var i = 0; i < usable.length; i++) {
      order[_key(usable[i])] = i;
    }
    picked.sort((a, b) => (order[_key(a)] ?? 0).compareTo(order[_key(b)] ?? 0));
    return picked;
  }

  /// 把最近几轮访客的话拼成查询串。
  String buildQuery(List<ChatMessage> messages) {
    final recent = messages
        .where((message) => message.isChat && message.role == 'user')
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (recent.isEmpty) return '';
    return recent
        .skip(recent.length > queryWindow ? recent.length - queryWindow : 0)
        .map((message) => message.content)
        .join(' ');
  }

  /// 查询串对一条记忆的覆盖度：查询里的字符二元组有多少能在记忆里找到。
  ///
  /// 用覆盖度而不是 Jaccard，是因为两者长度差得很远——一条 45 字的记忆对上
  /// 一句 20 字的近况，Jaccard 会被长度差稀释掉，覆盖度才是"这条记忆有没有
  /// 说到他正在说的事"。
  double relevance(String query, String text) {
    final queryBigrams = bigrams(normalize(query));
    if (queryBigrams.isEmpty) return 0;
    final textBigrams = bigrams(normalize(text));
    if (textBigrams.isEmpty) return 0;
    var hit = 0;
    for (final gram in queryBigrams) {
      if (textBigrams.contains(gram)) hit++;
    }
    return hit / queryBigrams.length;
  }

  /// 这条记忆是否算"切题"。
  bool isOnTopic(
    LibraryMemoryItem memory, {
    required String query,
  }) =>
      relevance(query, '${memory.content} ${memory.evidence}') >= topicThreshold;

  List<LibraryMemoryItem> _top(
    List<LibraryMemoryItem> source,
    int limit,
    String query,
    DateTime now,
  ) {
    if (source.isEmpty || limit <= 0) return const [];
    final ranked = List<LibraryMemoryItem>.of(source);
    ranked.sort((a, b) {
      final aOnTopic = isOnTopic(a, query: query);
      final bOnTopic = isOnTopic(b, query: query);
      // 第一级：切题的排在不切题的前面。
      if (aOnTopic != bOnTopic) return aOnTopic ? -1 : 1;
      // 第二级：同为切题时比相关度（更贴题的先出）。
      if (aOnTopic && bOnTopic) {
        final byRelevance = relevance(query, '${b.content} ${b.evidence}')
            .compareTo(relevance(query, '${a.content} ${a.evidence}'));
        if (byRelevance != 0) return byRelevance;
      }
      // 第三级：都比时间新旧。
      final at = a.createdAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return ranked.take(limit).toList();
  }

  /// 同一内容可能同时被当作事实与书签，用内容+来源做身份键。
  static String _key(LibraryMemoryItem memory) =>
      '${memory.source}\u0000${memory.content}';

  static String normalize(String value) => value
      .replaceAll(RegExp(r'''[\s，。！？、；：,.!?;:「」『』（）()\[\]—\-"'’‘“”…]'''), '')
      .toLowerCase();

  static Set<String> bigrams(String value) {
    final result = <String>{};
    for (var i = 0; i + 1 < value.length; i++) {
      result.add(value.substring(i, i + 2));
    }
    return result;
  }
}
