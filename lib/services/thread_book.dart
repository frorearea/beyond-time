import '../models/open_thread.dart';

/// 未决之事的簿记：合并、解决、整理、挑选问候题材。
///
/// 刻意做成纯函数集合（不碰网络、不碰存储），因此可以零依赖单测。
class ThreadBook {
  const ThreadBook();

  /// 记忆整理模型提出的一件新牵挂，合并进现有列表。
  ///
  /// 如果已有高度相似的未决之事，就地更新它（保留原有 id 与 createdAt），
  /// 否则追加一条新的。返回按 [OpenThread.maxThreads] 整理过的列表。
  List<OpenThread> merge(
    List<OpenThread> existing,
    OpenThreadDraft draft, {
    DateTime? now,
  }) {
    final topic = draft.topic.trim();
    if (topic.isEmpty) return existing;
    final stamp = (now ?? DateTime.now()).toIso8601String();
    final detail = draft.detail.trim();

    final result = <OpenThread>[];
    var merged = false;
    for (final thread in existing) {
      if (!merged &&
          thread.isOpen &&
          isSimilarTopic(thread.topic, topic)) {
        merged = true;
        result.add(thread.copyWith(
          topic: topic.length > thread.topic.length ? topic : thread.topic,
          detail: detail.isEmpty ? thread.detail : detail,
          updatedAt: stamp,
        ));
      } else {
        result.add(thread);
      }
    }
    if (!merged) {
      result.add(OpenThread(
        id: OpenThread.newId(),
        topic: topic,
        detail: detail,
        status: ThreadStatus.open,
        createdAt: stamp,
        updatedAt: stamp,
      ));
    }
    return prune(result, now: now);
  }

  /// 把指定 id 的未决之事标记为已有结果。
  List<OpenThread> resolve(
    List<OpenThread> existing,
    String? id, {
    DateTime? now,
  }) {
    if (id == null || id.trim().isEmpty) return existing;
    final target = id.trim();
    final stamp = (now ?? DateTime.now()).toIso8601String();
    var changed = false;
    final result = existing.map((thread) {
      if (thread.id == target && thread.isOpen) {
        changed = true;
        return thread.copyWith(status: ThreadStatus.resolved, updatedAt: stamp);
      }
      return thread;
    }).toList();
    return changed ? result : existing;
  }

  /// 整理列表：清掉过期的已解决条目，最多保留 [OpenThread.maxThreads] 条。
  ///
  /// 裁剪时优先丢弃已经解决、且最久没被提起的条目。
  List<OpenThread> prune(List<OpenThread> existing, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final kept = existing
        .where((thread) =>
            thread.topic.trim().isNotEmpty &&
            (thread.isOpen ||
                thread.isFreshWithin(OpenThread.resolvedRetention,
                    now: reference)))
        .toList();

    if (kept.length <= OpenThread.maxThreads) return kept;

    final sorted = List<OpenThread>.of(kept)
      ..sort((a, b) {
        // 未解决的优先保留；同状态内越新越优先。
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    final survivors = sorted.take(OpenThread.maxThreads).toSet();
    // 按原顺序输出，避免界面上列表跳动。
    return kept.where(survivors.contains).toList();
  }

  /// 挑选用于回归问候的未决之事：最近被提起、且仍在新鲜窗口内的那条。
  OpenThread? pickForGreeting(
    List<OpenThread> threads, {
    DateTime? now,
    Duration freshness = const Duration(days: 90),
  }) {
    final reference = now ?? DateTime.now();
    final candidates = threads
        .where((thread) => thread.isOpen)
        .where((thread) => thread.isFreshWithin(freshness, now: reference))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return candidates.first;
  }

  /// 挑选"最近刚刚有了结果"的那条，用于另一种回归问候。
  OpenThread? pickResolvedForGreeting(
    List<OpenThread> threads, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final candidates = threads
        .where((thread) => !thread.isOpen)
        .where((thread) =>
            thread.isFreshWithin(OpenThread.resolvedRetention, now: reference))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return candidates.first;
  }

  /// 话题是否指向同一件事。先做包含判断（低成本高精度），
  /// 再用字符二元组 Jaccard 相似度兜底。
  bool isSimilarTopic(String a, String b) {
    final x = normalize(a);
    final y = normalize(b);
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    if (x.length >= 2 && y.length >= 2 && (x.contains(y) || y.contains(x))) {
      return true;
    }
    return bigramSimilarity(x, y) >= 0.5;
  }

  static String normalize(String value) {
    return value
        .replaceAll(
            RegExp(r'''[\s，。！？、；：,.!?;:「」『』（）()\[\]—\-"'’‘“”]'''), '')
        .toLowerCase();
  }

  /// 字符二元组 Jaccard 相似度，零依赖。
  static double bigramSimilarity(String a, String b) {
    if (a == b) return 1;
    if (a.length < 2 || b.length < 2) return 0;
    final first = _bigrams(a);
    final second = _bigrams(b);
    if (first.isEmpty || second.isEmpty) return 0;
    final overlap = first.intersection(second).length;
    final union = first.union(second).length;
    return union == 0 ? 0 : overlap / union;
  }

  static Set<String> _bigrams(String value) {
    final result = <String>{};
    for (var i = 0; i + 1 < value.length; i++) {
      result.add(value.substring(i, i + 2));
    }
    return result;
  }

  /// 给列表排序：未解决在前，然后按更新时间倒序。
  List<OpenThread> sorted(List<OpenThread> threads) {
    final copy = List<OpenThread>.of(threads);
    copy.sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return copy;
  }
}
