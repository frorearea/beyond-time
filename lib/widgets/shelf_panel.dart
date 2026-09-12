import 'package:flutter/material.dart';

import '../models/library_memory_item.dart';
import '../theme.dart';

/// 书架：手动收藏的句子。
///
/// 以前这些句子混在"图书馆记忆"里，占了 2026-09-12 存档 21 条记忆中的 14 条。
/// 可是它们和记忆不是一回事：记忆是"她了解的关于你的事"，书签是"你亲手从她
/// 那里留下来的东西"。混在一起的结果是，一个真正被用了 14 次的功能没有归宿。
class ShelfPanel extends StatelessWidget {
  const ShelfPanel({super.key, required this.bookmarks});

  final List<LibraryMemoryItem> bookmarks;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlack,
      child: Container(
        width: 460,
        height: double.infinity,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: kWhite)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '书架',
                  style: TextStyle(color: kWhite, fontSize: 18),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bookmarks.isEmpty
                  ? '选中她说过的一句话，就能把它收进来。'
                  : '你亲手从她那里留下来的句子，一共 ${bookmarks.length} 句。',
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: bookmarks.isEmpty
                  ? const Center(
                      child: Text(
                        '书架还是空的。',
                        style: TextStyle(color: Color(0x99FFFFFF)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: bookmarks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final bookmark =
                            bookmarks[bookmarks.length - 1 - index];
                        return _ShelfQuote(bookmark: bookmark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfQuote extends StatelessWidget {
  const _ShelfQuote({required this.bookmark});

  final LibraryMemoryItem bookmark;

  @override
  Widget build(BuildContext context) {
    final date = bookmark.createdAtTime;
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xAAFFFFFF), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bookmark.content,
            style: const TextStyle(color: kWhite, fontSize: 14, height: 1.6),
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              '${date.year}-${_two(date.month)}-${_two(date.day)}',
              style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
