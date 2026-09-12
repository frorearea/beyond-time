import '../config.dart';
import '../models/library_memory_item.dart';

/// 图书馆记忆的簿记策略。
///
/// 刻意做成纯函数（不碰网络、不碰存储、不 import flutter），因此可以零依赖单测。
class MemoryBook {
  const MemoryBook();

  /// 追加一条记忆并维持 [kMaxLibraryMemory] 上限。
  ///
  /// 超出上限时优先丢弃最旧的"事实"记忆，**绝不丢书签**：书签是来访者亲手
  /// 收进图书馆的东西，被自动淘汰会非常伤人。2026-09-12 的存档里 21 条记忆
  /// 中有 14 条是书签——如果按简单的 FIFO 裁剪，这些人会很轻易地消失。
  List<LibraryMemoryItem> append(
    List<LibraryMemoryItem> memories,
    LibraryMemoryItem item,
  ) {
    final next = [...memories, item];
    if (next.length <= kMaxLibraryMemory) return next;

    final overflow = next.length - kMaxLibraryMemory;
    final dropped = <int>{};
    // 第一轮：从最旧的事实记忆开始丢。
    for (var i = 0; i < next.length && dropped.length < overflow; i++) {
      if (next[i].isKnowledge) dropped.add(i);
    }
    // 第二轮：事实记忆不够丢，才动书签。
    for (var i = 0; i < next.length && dropped.length < overflow; i++) {
      if (!dropped.contains(i)) dropped.add(i);
    }
    return [
      for (var i = 0; i < next.length; i++)
        if (!dropped.contains(i)) next[i],
    ];
  }

  /// 是否已经存在相似记忆（旧版本的朴素包含判断，保留原行为）。
  bool hasSimilar(List<LibraryMemoryItem> memories, String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return false;
    return memories.any((memory) {
      final existing = memory.content.replaceAll(RegExp(r'\s+'), '');
      return existing == compact ||
          existing.contains(compact) ||
          compact.contains(existing);
    });
  }
}
