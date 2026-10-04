import 'dart:convert';

import '../config.dart';
import '../models/creation_note.dart';
import '../models/library_memory_item.dart';
import '../models/open_thread.dart';
import 'chat_api.dart';

/// 一次记忆整理的结果。
///
/// v2 起，同一次调用还会顺带维护"未决之事"（C3）：来访者提过的悬案，
/// 以及某件旧悬案是否已经落地。合并成一次请求而不是两次，
/// 是因为成本与延迟都要翻倍，而这些信息来自同一段对话。
///
/// v3 起再多产出一份"创作稿"：来访者自己的设定、名字与片段。
class CaptureOutcome {
  const CaptureOutcome({
    this.memory,
    this.threadDraft,
    this.creation,
    this.resolveThreadId,
  });

  final LibraryMemoryItem? memory;
  final OpenThreadDraft? threadDraft;
  final CreationDraft? creation;
  final String? resolveThreadId;

  bool get isEmpty =>
      memory == null &&
      threadDraft == null &&
      creation == null &&
      resolveThreadId == null;

  static const CaptureOutcome nothing = CaptureOutcome();
}

class MemoryCaptureService {
  const MemoryCaptureService(this._chatApi);

  final ChatApiClient _chatApi;

  /// 太短的消息不进入整理（多半是"请继续""天呐说的太好了"这类回声）。
  static const int minUserTextLength = 12;

  /// 记忆被采纳的最低置信度。
  static const double minConfidence = 0.62;

  bool shouldSkipUserText(String userText) {
    return userText.replaceAll(RegExp(r'\s+'), ' ').trim().length <
        minUserTextLength;
  }

  Future<CaptureOutcome> capture({
    required String userText,
    required String assistantReply,
    required List<LibraryMemoryItem> existingMemories,
    required List<OpenThread> existingThreads,
    List<CreationNote> existingCreations = const [],
    required String apiKey,
    required String apiUrl,
    required String model,
  }) async {
    final compactUserText = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final openThreads = existingThreads.where((thread) => thread.isOpen).toList();

    final raw = await _chatApi.requestStreamingReply(
      payload: {
        'model': model.trim().isEmpty ? kDefaultModel : model.trim(),
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': '''
现有记忆：
${memoryDigest(existingMemories)}

现有未决之事：
${threadDigest(openThreads)}

现有创作稿：
${creationDigest(existingCreations)}

最近这轮对话：
来访者：$compactUserText
艾蕾塔：${assistantReply.replaceAll(RegExp(r'\s+'), ' ').trim()}

请判断是否需要新增一条记忆、是否需要记下一件未决之事、是否需要留存一份来访者自己的创作稿、以及是否有旧悬案已经落地。只输出如下 JSON：
{
  "shouldRemember": true 或 false,
  "category": "喜好/压力/热爱/困扰/创作/关系/自我理解/其他",
  "memory": "一条不超过$kMaxMemoryContentLength字的记忆，用第三人称描述来访者，不要出现「用户」二字",
  "evidence": "最短的来访者原话依据，不超过$kMaxMemoryEvidenceLength字",
  "confidence": 0.0 到 1.0,
  "openThread": {"topic": "不超过16字的名词短语", "detail": "不超过${OpenThread.maxDetailLength}字"} 或 null,
  "creation": {"title": "他自己作品的名字或短名词短语", "kind": "设定/故事/游戏/角色/诗/其他", "content": "不超过${CreationNote.maxContentLength}字的要点或片段，尽量用他自己的说法"} 或 null,
  "resolveThreadId": "要标记为已解决的未决之事 id，没有就填 null"
}
''',
          },
        ],
        'temperature': 0.15,
        'max_tokens': 520,
        'stream': true,
        'stream_options': {'include_usage': false},
      },
      apiKey: apiKey,
      apiUrl: apiUrl.trim().isEmpty ? kDefaultApiUrl : apiUrl.trim(),
      onReply: (_) {},
    );

    return parseOutcome(raw,
        existingMemories: existingMemories,
        openThreads: openThreads,
        existingCreations: existingCreations);
  }

  static const String _systemPrompt =
      '你是艾蕾塔的图书馆记忆整理员。你的任务不是聊天，而是判断来访者刚才的话里有什么值得长期记住。'
      '只记录稳定、具体、有情感重量的信息：喜好、压力源、热爱、困扰、创作计划、长期自我理解。'
      '不要记录简单问候、临时问题、一次性作品问答、艾蕾塔自己的话、过于普通或可从上下文轻易推断的信息。'
      '不要频繁记录；宁可少记，也不要把图书馆变成流水账。称呼对方时只用"来访者"，不要写"用户"。'
      '\n\n除了记忆，你还要维护"未决之事"：来访者自己提起、但还没有下文的牵挂。'
      '典型形态是一个还没做的决定、一个还在等的结果、一件打算去做却还没动手的事，'
      '或者一个明显还没讲完的故事与计划。'
      '\n- openThread 只在来访者这次真正提出了新的悬案时填写，否则填 null。'
      '不要因为来访者问了某个问题、聊了某部作品就记成未决之事。'
      '\n- openThread.topic 必须是一个能直接接在"上次你说的……"后面的名词短语，'
      '不超过 16 字，不要用逗号，例如"保研还是去海外""那个红发少女的故事"。'
      '\n- openThread.detail 补充一两句背景，方便以后回想起来。'
      '\n- 如果现有未决之事里有一件已经明确落地（做完了、决定了、放弃了），'
      '把它的 id 填进 resolveThreadId，否则填 null。'
      '\n\n你还要留意"来访者自己的创作"：他亲手写下的设定、故事名、角色、片段、点子，'
      '包括他正在做的游戏或小说。'
      '\n- 只在**他在讲自己的东西**时填 creation，否则填 null。'
      '只是喜欢、讨论、推荐别人的作品不算创作，也不要因为他说"我想做个游戏"这种'
      '空泛愿望就记一份稿子——要真的出现了名字、设定或片段。'
      '\n- creation.title 是他自己作品的名字或一个短名词短语（例如"红羽离笼记""那个雨中迷宫"），'
      '不要用"来访者的创作"这种空标题。'
      '\n- creation.content 尽量保留他自己的用词，不要替他把设定写得更好、更完整。'
      '\n- 如果现有创作稿里已经有同一份，就在它基础上补充，不要另开一条。'
      '\n只输出 JSON，不要输出解释。';

  /// 供记忆整理读取的现有记忆摘要（书签不参与，避免整理员被金句带跑）。
  String memoryDigest(List<LibraryMemoryItem> memories) {
    final recentMemories = memories
        .where((memory) => memory.isKnowledge)
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

  /// 现有未决之事摘要，带上 id 以便模型回填 resolveThreadId。
  String threadDigest(List<OpenThread> threads) {
    if (threads.isEmpty) return '无';
    return threads
        .map((thread) =>
            '- id=${thread.id} ${thread.topic}${thread.detail.trim().isEmpty ? '' : '（${thread.detail}）'}')
        .join('\n');
  }

  /// 现有创作稿摘要，让整理员知道哪份稿子已经有了、该补充而不是另开一条。
  ///
  /// 只给标题和类型，不给正文：正文越长，整理员越容易照抄或顺着改写，
  /// 而我们要的是"他自己新说的话"。
  String creationDigest(List<CreationNote> creations) {
    if (creations.isEmpty) return '无';
    return creations
        .map((note) => '- [${note.kind}] ${note.title}')
        .join('\n');
  }

  /// 解析整理员的输出。纯函数，便于单测。
  CaptureOutcome parseOutcome(
    String raw, {
    required List<LibraryMemoryItem> existingMemories,
    required List<OpenThread> openThreads,
    List<CreationNote> existingCreations = const [],
  }) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return CaptureOutcome.nothing;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return CaptureOutcome.nothing;
    }

    return CaptureOutcome(
      memory: _parseMemory(data, existingMemories),
      threadDraft: _parseThread(data),
      creation: _parseCreation(data, existingCreations),
      resolveThreadId: _parseResolvedId(data, openThreads),
    );
  }

  LibraryMemoryItem? _parseMemory(
    Map<String, dynamic> data,
    List<LibraryMemoryItem> existingMemories,
  ) {
    if (data['shouldRemember'] != true) return null;
    final confidence = double.tryParse(data['confidence'].toString()) ?? 0;
    if (confidence < minConfidence) return null;
    final content = _clampAtBoundary(
      data['memory']?.toString().trim() ?? '',
      kMaxMemoryContentLength,
    );
    if (content.length < 8) return null;
    if (hasSimilarMemory(existingMemories, content)) return null;
    return LibraryMemoryItem(
      category: data['category']?.toString().trim().isNotEmpty == true
          ? data['category'].toString().trim()
          : '记忆',
      content: content,
      evidence: _clampAtBoundary(
        data['evidence']?.toString().trim() ?? '',
        kMaxMemoryEvidenceLength,
      ),
      source: '艾蕾塔整理',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  OpenThreadDraft? _parseThread(Map<String, dynamic> data) {
    final raw = data['openThread'];
    if (raw is! Map<String, dynamic>) return null;
    final topic = (raw['topic']?.toString() ?? '').trim();
    if (topic.length < 2) return null;
    return OpenThreadDraft(
      topic: _clampAtBoundary(topic, OpenThread.maxTopicLength),
      detail: _clampAtBoundary(
        (raw['detail']?.toString() ?? '').trim(),
        OpenThread.maxDetailLength,
      ),
    );
  }

  /// 解析来访者自己的创作稿。标题太短的一律丢弃，避免"我的故事"这类空标题堆积。
  CreationDraft? _parseCreation(
    Map<String, dynamic> data,
    List<CreationNote> existingCreations,
  ) {
    final raw = data['creation'];
    if (raw is! Map<String, dynamic>) return null;
    final title = (raw['title']?.toString() ?? '').trim();
    if (title.length < 2) return null;
    final clamped = CreationNote.clamp(title, CreationNote.maxTitleLength);
    // 已经有同一份稿子时仍然返回，交给 CreationBook 去就地合并。
    return CreationDraft(
      title: clamped,
      kind: _normalizeKind(raw['kind']?.toString()),
      content: _clampAtBoundary(
        (raw['content']?.toString() ?? '').trim(),
        CreationNote.maxContentLength,
      ),
    );
  }

  static String _normalizeKind(String? value) {
    final kind = (value ?? '').trim();
    for (final candidate in CreationNote.kinds) {
      if (candidate == kind) return kind;
    }
    return '其他';
  }

  /// 只接受确实存在于现有列表里的 id，避免模型凭空造一个 id 把无关条目标记为已解决。
  String? _parseResolvedId(
    Map<String, dynamic> data,
    List<OpenThread> openThreads,
  ) {
    final raw = data['resolveThreadId']?.toString().trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    for (final thread in openThreads) {
      if (thread.id == raw) return raw;
    }
    return null;
  }

  bool hasSimilarMemory(List<LibraryMemoryItem> memories, String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), '');
    return memories.any((memory) {
      final existing = memory.content.replaceAll(RegExp(r'\s+'), '');
      return existing == compact ||
          existing.contains(compact) ||
          compact.contains(existing);
    });
  }

  /// 截断时尽量在标点处收住，不要把一句话砍成半截。
  static String _clampAtBoundary(String value, int limit) {
    if (value.length <= limit) return value;
    final head = value.substring(0, limit);
    for (final mark in const ['。', '；', '，', '、', ' ']) {
      final index = head.lastIndexOf(mark);
      if (index >= limit ~/ 2) return head.substring(0, index + 1);
    }
    return '$head…';
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
