import 'dart:convert';
import 'dart:math' as math;

import '../data/idle_lines.dart';
import '../data/return_lines.dart';
import 'chat_message.dart';
import 'creation_note.dart';
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

/// 只能靠前缀识别的噪音。
///
/// [_kNoiseLines] 是精确匹配，装不下带动态尾巴的运行时报错
/// （`连接没有成功：<原因>`）。旧存档（v1，消息没有 `kind`）导入时，
/// 这些行会被 `ChatMessage.fromJson` 默认成 `chat`，于是精确匹配对不上、
/// 种类过滤也拦不住，就留在了对话记录里。
///
/// 前缀匹配在这个位置是安全的：她不会用这两句开头。
const List<String> _kNoisePrefixes = [
  '连接没有成功',
  '还没有填写 API Key',
];


class LibraryArchive {
  const LibraryArchive({
    required this.messages,
    required this.memories,
    required this.threads,
    required this.quickOptionPoolIndex,
    this.creations = const [],
  });

  /// 当前存档格式版本。
  ///
  /// v2 起：消息带 `kind`，并包含未决之事。
  /// v3 起：包含来访者自己的创作稿。v2 存档里没有这个字段，导入时按空列表处理。
  static const int currentVersion = 3;

  final List<ChatMessage> messages;
  final List<LibraryMemoryItem> memories;
  final List<OpenThread> threads;
  final List<CreationNote> creations;
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
      'creations': creations.map((note) => note.toJson()).toList(),
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
      final creations = _parseCreations(data['creations']);
      if (messages.isEmpty &&
          memories.isEmpty &&
          threads.isEmpty &&
          creations.isEmpty) {
        return null;
      }

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
        creations: creations,
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
  /// 只做精确匹配、前缀匹配与"相邻完全相同"的折叠，不做任何模糊判断。
  static List<ChatMessage> sanitizeMessages(List<ChatMessage> messages) {
    final cleaned = <ChatMessage>[];
    for (final message in messages) {
      if (message.kind != MessageKind.chat) continue;
      final text = message.content.trim();
      if (_kNoiseLines.contains(text)) continue;
      if (_kNoisePrefixes.any(text.startsWith)) continue;
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

  static List<CreationNote> _parseCreations(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CreationNote.tryFromJson)
        .whereType<CreationNote>()
        .toList();
  }

  static int _parseQuickOptionPoolIndex(Map<String, dynamic> data) {
    final value = data['quickOptionPoolIndex'] ?? data['quickChoiceCount'];
    return math.max(0, int.tryParse(value.toString()) ?? 0);
  }
}
