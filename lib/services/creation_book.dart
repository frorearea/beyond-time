import '../models/creation_note.dart';
import 'thread_book.dart';

/// 来访者创作稿的簿记：合并、整理、排序。
///
/// 刻意做成纯函数集合（不碰网络、不碰存储、不 import flutter），可以零依赖单测。
class CreationBook {
  const CreationBook();

  /// 记忆整理模型提出的一份新稿子，合并进现有列表。
  ///
  /// 标题高度相似就地更新（保留原 id 与 createdAt，内容以新的为准），
  /// 否则追加一条。返回按 [CreationNote.maxNotes] 整理过的列表。
  List<CreationNote> merge(
    List<CreationNote> existing,
    CreationDraft draft, {
    DateTime? now,
  }) {
    final title = draft.title.trim();
    if (title.isEmpty) return existing;
    final stamp = (now ?? DateTime.now()).toIso8601String();
    final content = draft.content.trim();
    final kind = draft.kind.trim();

    final result = <CreationNote>[];
    var merged = false;
    for (final note in existing) {
      if (!merged && isSimilarTitle(note.title, title)) {
        merged = true;
        result.add(note.copyWith(
          // 标题以更完整的那个为准，避免"红羽离笼记"被"红羽"覆盖掉。
          title: title.length > note.title.length ? title : note.title,
          kind: kind.isEmpty ? note.kind : kind,
          content: content.isEmpty ? note.content : content,
          updatedAt: stamp,
        ));
      } else {
        result.add(note);
      }
    }
    if (!merged) {
      result.add(CreationNote(
        id: CreationNote.newId(),
        title: title,
        kind: kind.isEmpty ? '其他' : kind,
        content: content,
        createdAt: stamp,
        updatedAt: stamp,
      ));
    }
    return prune(result);
  }

  /// 整理列表：丢掉空标题，最多保留 [CreationNote.maxNotes] 条。
  ///
  /// 裁剪时优先丢弃最久没被提起的稿子——创作会反复回来，久不碰的更可能是废弃稿。
  List<CreationNote> prune(List<CreationNote> existing) {
    final kept = existing
        .where((note) => note.title.trim().isNotEmpty)
        .toList(growable: false);
    if (kept.length <= CreationNote.maxNotes) return kept;

    final sorted = List<CreationNote>.of(kept)..sort((a, b) {
        final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    final survivors = sorted.take(CreationNote.maxNotes).toSet();
    // 按原顺序输出，避免界面上列表跳动。
    return kept.where(survivors.contains).toList();
  }

  /// 按更新时间倒序（最近碰过的排前面），供面板展示。
  List<CreationNote> sorted(List<CreationNote> notes) {
    final copy = List<CreationNote>.of(notes);
    copy.sort((a, b) {
      final at = a.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAtTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return copy;
  }

  /// 标题是否指向同一份稿子。复用未决之事的判定，避免两套相似度算法漂移。
  bool isSimilarTitle(String a, String b) =>
      const ThreadBook().isSimilarTopic(a, b);
}
