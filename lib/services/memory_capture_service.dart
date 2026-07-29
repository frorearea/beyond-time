import 'dart:convert';

import '../config.dart';
import '../models/library_memory_item.dart';
import 'chat_api.dart';

class MemoryCaptureService {
  const MemoryCaptureService(this._chatApi);

  final ChatApiClient _chatApi;

  bool shouldSkipUserText(String userText) {
    return userText.replaceAll(RegExp(r'\s+'), ' ').trim().length < 12;
  }

  Future<LibraryMemoryItem?> capture({
    required String userText,
    required String assistantReply,
    required List<LibraryMemoryItem> existingMemories,
    required String apiKey,
    required String apiUrl,
    required String model,
  }) async {
    final compactUserText = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final raw = await _chatApi.requestStreamingReply(
      payload: {
        'model': model.trim().isEmpty ? kDefaultModel : model.trim(),
        'messages': [
          {
            'role': 'system',
            'content':
                '你是艾蕾塔的图书馆记忆整理员。你的任务不是聊天，而是判断来访者刚才的话是否值得长期记住。只记录稳定、具体、有情感重量的信息：喜好、压力源、热爱、困扰、创作计划、长期自我理解。不要记录简单问候、临时问题、一次性作品问答、艾蕾塔自己的话、过于普通或可从上下文轻易推断的信息。不要频繁记录；宁可少记，也不要把图书馆变成流水账。称呼对方时只用“来访者”，不要写“用户”。只输出 JSON，不要输出解释。',
          },
          {
            'role': 'user',
            'content': '''
现有记忆：
${memoryDigest(existingMemories)}

最近这轮对话：
来访者：$compactUserText
艾蕾塔：${assistantReply.replaceAll(RegExp(r'\s+'), ' ').trim()}

请判断是否需要新增一条记忆。只输出如下 JSON：
{
  "shouldRemember": true 或 false,
  "category": "喜好/压力/热爱/困扰/创作/关系/自我理解/其他",
  "memory": "一条不超过45字的记忆，用第三人称描述来访者，不要出现“用户”二字",
  "evidence": "最短的来访者原话依据",
  "confidence": 0.0 到 1.0
}
''',
          },
        ],
        'temperature': 0.15,
        'max_tokens': 260,
        'stream': true,
        'stream_options': {'include_usage': false},
      },
      apiKey: apiKey,
      apiUrl: apiUrl.trim().isEmpty ? kDefaultApiUrl : apiUrl.trim(),
      onReply: (_) {},
    );

    final memory = parseMemoryCandidate(raw);
    if (memory == null || hasSimilarMemory(existingMemories, memory.content)) {
      return null;
    }
    return memory;
  }

  String memoryDigest(List<LibraryMemoryItem> memories) {
    final recentMemories = memories
        .where((memory) => memory.source != '手动书签')
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed;
    if (recentMemories.isEmpty) return '无';
    return recentMemories
        .map((memory) => '- [${memory.category}] ${memory.content}')
        .join('\n');
  }

  LibraryMemoryItem? parseMemoryCandidate(String raw) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return null;
    try {
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      if (data['shouldRemember'] != true) return null;
      final confidence = double.tryParse(data['confidence'].toString()) ?? 0;
      if (confidence < 0.62) return null;
      final content = data['memory']?.toString().trim() ?? '';
      if (content.length < 8) return null;
      final evidence = data['evidence']?.toString().trim() ?? '';
      final category = data['category']?.toString().trim().isNotEmpty == true
          ? data['category'].toString().trim()
          : '记忆';
      return LibraryMemoryItem(
        category: category,
        content:
            content.length > 80 ? '${content.substring(0, 80)}...' : content,
        evidence:
            evidence.length > 80 ? '${evidence.substring(0, 80)}...' : evidence,
        source: '艾蕾塔整理',
        createdAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  bool hasSimilarMemory(
    List<LibraryMemoryItem> memories,
    String content,
  ) {
    final compact = content.replaceAll(RegExp(r'\s+'), '');
    return memories.any((memory) {
      final existing = memory.content.replaceAll(RegExp(r'\s+'), '');
      return existing == compact ||
          existing.contains(compact) ||
          compact.contains(existing);
    });
  }

  String? _extractJsonObject(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final start = cleaned.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < cleaned.length; i++) {
      if (cleaned[i] == '{') {
        depth++;
      } else if (cleaned[i] == '}') {
        depth--;
        if (depth == 0) {
          final candidate = cleaned.substring(start, i + 1);
          try {
            jsonDecode(candidate);
            return candidate;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}
