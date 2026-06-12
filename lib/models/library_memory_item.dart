class LibraryMemoryItem {
  const LibraryMemoryItem({
    required this.category,
    required this.content,
    required this.evidence,
    required this.source,
    required this.createdAt,
  });

  final String category;
  final String content;
  final String evidence;
  final String source;
  final String createdAt;

  Map<String, String> toJson() => {
        'category': _worldText(category),
        'content': _worldText(content),
        'evidence': _worldText(evidence),
        'source': _worldText(source),
        'createdAt': createdAt,
      };

  static LibraryMemoryItem fromJson(Map<String, dynamic> json) {
    return LibraryMemoryItem(
      category: json['category']?.toString().trim().isNotEmpty == true
          ? _worldText(json['category'].toString().trim())
          : '记忆',
      content: _worldText(json['content']?.toString().trim() ?? ''),
      evidence: _worldText(json['evidence']?.toString().trim() ?? ''),
      source: json['source']?.toString().trim().isNotEmpty == true
          ? _worldText(json['source'].toString().trim())
          : '艾蕾塔整理',
      createdAt: json['createdAt']?.toString().trim().isNotEmpty == true
          ? json['createdAt'].toString().trim()
          : DateTime.now().toIso8601String(),
    );
  }

  static LibraryMemoryItem fromLegacyString(String value) {
    return LibraryMemoryItem(
      category: '书签',
      content: _worldText(value.trim()),
      evidence: '来访者手动收藏的句子',
      source: '手动书签',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  static String _worldText(String value) {
    return value.replaceAll('用户', '来访者');
  }
}
