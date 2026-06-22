import '../models/library_memory_item.dart';

class BookmarkResult {
  const BookmarkResult({
    required this.memories,
    required this.notice,
    required this.added,
  });

  final List<LibraryMemoryItem> memories;
  final String notice;
  final bool added;
}

class BookmarkService {
  const BookmarkService();

  BookmarkResult addBookmark({
    required List<LibraryMemoryItem> memories,
    required String selectedText,
  }) {
    final quote = selectedText.trim();
    final alreadyBookmarked = memories.any((memory) => memory.content == quote);
    if (alreadyBookmarked) {
      return BookmarkResult(
        memories: memories,
        notice: '这枚书签已经在书页里了。看来它很会纠缠您呢。',
        added: false,
      );
    }

    return BookmarkResult(
      memories: [
        ...memories,
        LibraryMemoryItem(
          category: '书签',
          content: quote,
          evidence: '来访者手动收藏的句子',
          source: '手动书签',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
      notice: '收好了。亲爱的，这句话现在属于图书馆了。',
      added: true,
    );
  }
}
