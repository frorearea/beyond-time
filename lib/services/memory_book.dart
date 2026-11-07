import '../config.dart';
import '../models/library_memory_item.dart';

/// 图书馆记忆的簿记策略。
///
/// 刻意做成纯函数（不碰网络、不碰存储、不 import flutter），因此可以零依赖单测。
class MemoryBook {
  const MemoryBook();

  /// 追加一条记忆，并让**两类各自**维持自己的上限。
  ///
  /// 书签（来访者亲手收的）与事实（她整理的）用同一个总上限是错误的：
  /// 2026-11-07 的存档里 32 条记忆有 29 条是书签，事实只剩 3 条——
  /// 于是每来一条新事实就淘汰一条旧事实，历史记忆被慢慢洗光。
  ///
  /// 现在各类封顶、淘汰各自最旧的一条，谁也挤不掉谁；书签仍然只是"最后才动"，
  /// 但它不再占用事实的额度。
  List<LibraryMemoryItem> append(
    List<LibraryMemoryItem> memories,
    LibraryMemoryItem item,
  ) {
    final next = [...memories, item];
    final knowledge = next.where((m) => m.isKnowledge).toList();
    final bookmarks = next.where((m) => m.isBookmark).toList();
    if (knowledge.length <= kMaxKnowledgeMemory &&
        bookmarks.length <= kMaxBookmarks) {
      return next;
    }

    final kept = <LibraryMemoryItem>{
      ...knowledge,
      ...bookmarks,
    };
    if (knowledge.length > kMaxKnowledgeMemory) {
      kept.removeAll(knowledge.sublist(0, knowledge.length - kMaxKnowledgeMemory));
    }
    if (bookmarks.length > kMaxBookmarks) {
      kept.removeAll(bookmarks.sublist(0, bookmarks.length - kMaxBookmarks));
    }
    // 保持原来的先后顺序。
    return [
      for (final memory in next)
        if (kept.contains(memory)) memory,
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
