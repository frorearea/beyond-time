import 'dart:convert';
import 'dart:math' as math;

import '../data/idle_lines.dart';
import '../data/return_lines.dart';
import 'chat_message.dart';
import 'library_memory_item.dart';
import 'open_thread.dart';

/// 存档里的环境语/回执噪音。老版本把这些写进了对话记录，
/// 2026-09-12 的存档里有 47 条完全重复的噪音行。导入时按**精确匹配**清理，
/// 绝不使用模糊规则，避免误删艾蕾塔真的说过的话。
final Set<String> _kNoiseLines = {
  ...kIdleLines,
  ...kLeaveLines,
  ...kReturnShortLines,
  ...kReturnGreetingHours,
  ...kReturnGreetingDays,
  ...kReturnGreetingWeeks,
  ...kReturnGreetingMonths,
  '收好了。亲爱的，这句话现在属于图书馆了。',
  '这枚书签已经在书页里了。看来它很会纠缠您呢。',
  '还没有填写 API Key。先打开右上角设置，亲爱的。',
};

class LibraryArchive {
  const LibraryArchive({
    required this.messages,
    required this.memories,
    required this.threads,
    required this.quickOptionPoolIndex,
  });

  /// 当前存档格式版本。v2 起：消息带 `kind`，并包含未决之事。
  static const int currentVersion = 2;

  final List<ChatMessage> messages;
  final List<LibraryMemoryItem> memories;
  final List<OpenThread> threads;
  final int quickOptionPoolIndex;

  String toJsonText() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'type': 'beyond-time-library-archive',
      'version': currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      // 与 StoreHelper.saveHistory 同理：序列化边界统一只写真实对话，
      // 导出路径不可能再漏掉环境语与系统回执。
      'messages': messages
          .where((message) => message.isChat)
          .map((message) => message.toJson())
          .toList(),
      'libraryMemory': memories.map((memory) => memory.toJson()).toList(),
      'openThreads': threads.map((thread) => thread.toJson()).toList(),
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
      final threads = _parseThreads(data['openThreads']);
      if (messages.isEmpty && memories.isEmpty && threads.isEmpty) return null;

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
        threads: threads,
        quickOptionPoolIndex: _parseQuickOptionPoolIndex(data),
      );
    } catch (_) {
      return null;
    }
  }

  static List<ChatMessage> _parseMessages(Object? raw) {
    if (raw is! List) return const [];
    final parsed = raw
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    return sanitizeMessages(parsed);
  }

  /// 清洗旧存档：丢掉已知的环境语/回执噪音，并合并相邻的重复台词。
  ///
  /// 只做精确匹配与"相邻完全相同"的折叠，不做任何模糊判断。
  static List<ChatMessage> sanitizeMessages(List<ChatMessage> messages) {
    final cleaned = <ChatMessage>[];
    for (final message in messages) {
      if (message.kind != MessageKind.chat) continue;
      final text = message.content.trim();
      if (_kNoiseLines.contains(text)) continue;
      final previous = cleaned.isEmpty ? null : cleaned.last;
      if (previous != null &&
          previous.role == message.role &&
          previous.content.trim() == text) {
        continue;
      }
      cleaned.add(message);
    }
    return cleaned;
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

  static List<OpenThread> _parseThreads(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(OpenThread.tryFromJson)
        .whereType<OpenThread>()
        .toList();
  }

  static int _parseQuickOptionPoolIndex(Map<String, dynamic> data) {
    final value = data['quickOptionPoolIndex'] ?? data['quickChoiceCount'];
    return math.max(0, int.tryParse(value.toString()) ?? 0);
  }
}
