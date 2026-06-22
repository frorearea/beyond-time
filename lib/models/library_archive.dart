import 'dart:convert';
import 'dart:math' as math;

import 'chat_message.dart';
import 'library_memory_item.dart';

class LibraryArchive {
  const LibraryArchive({
    required this.messages,
    required this.memories,
    required this.quickOptionPoolIndex,
  });

  final List<ChatMessage> messages;
  final List<LibraryMemoryItem> memories;
  final int quickOptionPoolIndex;

  String toJsonText() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'type': 'beyond-time-library-archive',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'messages': messages.map((message) => message.toJson()).toList(),
      'libraryMemory': memories.map((memory) => memory.toJson()).toList(),
      'quickOptionPoolIndex': quickOptionPoolIndex,
      'quickChoiceCount': quickOptionPoolIndex,
    });
  }

  static LibraryArchive? tryParse(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;

      final messages = _parseMessages(data['messages']);
      final memories = _parseMemories(data['libraryMemory']);
      if (messages.isEmpty && memories.isEmpty) return null;

      return LibraryArchive(
        messages: messages.isEmpty
            ? const [
                ChatMessage(
                  role: 'assistant',
                  content: '旧存档里没有对话，但记忆已经回到书架上了。',
                ),
              ]
            : messages,
        memories: memories,
        quickOptionPoolIndex: _parseQuickOptionPoolIndex(data),
      );
    } catch (_) {
      return null;
    }
  }

  static List<ChatMessage> _parseMessages(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
  }

  static List<LibraryMemoryItem> _parseMemories(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map<String, dynamic>) {
            return LibraryMemoryItem.fromJson(item);
          }
          return LibraryMemoryItem.fromLegacyString(item.toString());
        })
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList();
  }

  static int _parseQuickOptionPoolIndex(Map<String, dynamic> data) {
    final value = data['quickOptionPoolIndex'] ?? data['quickChoiceCount'];
    return math.max(0, int.tryParse(value.toString()) ?? 0);
  }
}
