import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../lib/config.dart';
import '../lib/data/return_lines.dart';
import '../lib/models/chat_message.dart';
import '../lib/models/library_archive.dart';
import '../lib/models/library_memory_item.dart';
import '../lib/models/open_thread.dart';
import '../lib/services/chat_api.dart';
import '../lib/services/conversation_context.dart';
import '../lib/services/memory_book.dart';
import '../lib/services/memory_capture_service.dart';
import '../lib/services/return_arc.dart';
import '../lib/services/thread_book.dart';

int _failures = 0;

void check(String name, bool condition) {
  if (condition) {
    print('PASS: $name');
  } else {
    _failures++;
    print('FAIL: $name');
  }
}

void section(String title) => print('\n=== $title ===');

LibraryMemoryItem bookmark(String content) => LibraryMemoryItem(
      category: '书签',
      content: content,
      evidence: '来访者手动收藏的句子',
      source: '手动书签',
      createdAt: '2026-09-01T00:00:00.000',
    );

LibraryMemoryItem fact(String content, {String category = '喜好'}) =>
    LibraryMemoryItem(
      category: category,
      content: content,
      evidence: content,
      source: '艾蕾塔整理',
      createdAt: '2026-09-01T00:00:00.000',
    );

OpenThread thread(
  String id,
  String topic, {
  ThreadStatus status = ThreadStatus.open,
  String updatedAt = '2026-09-10T00:00:00.000',
  String detail = '',
}) =>
    OpenThread(
      id: id,
      topic: topic,
      detail: detail,
      status: status,
      createdAt: '2026-09-01T00:00:00.000',
      updatedAt: updatedAt,
    );

void main() {
  final now = DateTime.parse('2026-09-15T12:00:00.000');

  // ------------------------------------------------------------ 存档清洗
  section('存档清洗（用真实存档验证）');
  const archivePath = 'beyond-time-library-2026-09-12_20-46-51-667.json';
  final file = File(archivePath);
  if (!file.existsSync()) {
    print('SKIP: 找不到 $archivePath（仓库根目录运行本测试）');
  } else {
    final raw = file.readAsStringSync();
    final archive = LibraryArchive.tryParse(raw);
    check('旧存档能被解析', archive != null);
    if (archive != null) {
      final contents = archive.messages.map((m) => m.content.trim()).toList();
      final counts = <String, int>{};
      for (final text in contents) {
        counts[text] = (counts[text] ?? 0) + 1;
      }
      final worst = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      check('没有残留的环境语/回执噪音',
          !contents.any((text) => text == '收好了。亲爱的，这句话现在属于图书馆了。'));
      check('没有残留的 API Key 提示',
          !contents.any((text) => text.contains('还没有填写 API Key')));
      check('没有残留的 idle 台词',
          !contents.any((text) => text == '灯芯跳了一下。' || text == '你还在听吗。'));
      check('没有相邻完全重复的消息', _noAdjacentDuplicates(contents));
      check('最高重复次数已降到 1（原为 14）', worst.value == 1);
      check('消息总数显著减少（原 258 条）', archive.messages.length < 258);

      final raw2 = jsonDecode(raw) as Map<String, dynamic>;
      print('  原始消息 ${(raw2['messages'] as List).length} 条'
          ' → 清洗后 ${archive.messages.length} 条');
      print('  记忆 ${archive.memories.length} 条，未决之事 ${archive.threads.length} 件');
    }
  }

  // 导出的 JSON 不得包含非对话消息
  final exported = LibraryArchive(
    messages: const [
      ChatMessage(role: 'user', content: '我说的话'),
      ChatMessage(role: 'assistant', content: '她真的说过的话'),
      ChatMessage(
          role: 'assistant', content: '灯芯跳了一下。', kind: MessageKind.ambient),
      ChatMessage(
          role: 'assistant',
          content: '收好了。亲爱的，这句话现在属于图书馆了。',
          kind: MessageKind.notice),
      ChatMessage(
          role: 'assistant', content: '连接没有成功：超时', kind: MessageKind.error),
    ],
    memories: const [],
    threads: const [],
    quickOptionPoolIndex: 3,
  ).toJsonText();
  final exportedJson = jsonDecode(exported) as Map<String, dynamic>;
  final exportedMessages = (exportedJson['messages'] as List).length;
  check('导出只写真实对话（5 条 → 2 条）', exportedMessages == 2);
  check('导出带版本号 v2', exportedJson['version'] == 2);
  check('导出包含未决之事字段', exportedJson.containsKey('openThreads'));

  // ------------------------------------------------------------ 未决之事簿记
  section('未决之事簿记');
  const book = ThreadBook();

  final created = book.merge(const [], const OpenThreadDraft(
    topic: '保研还是去海外',
    detail: '两条路都可能，还没定',
  ), now: now);
  check('新悬案被记下', created.length == 1 && created.first.isOpen);
  check('话题完整保留', created.first.topic == '保研还是去海外');

  final merged = book.merge(created, const OpenThreadDraft(
    topic: '保研还是去海外的事',
    detail: '和家里谈过了',
  ), now: now);
  check('相似话题被合并而不是新开一条', merged.length == 1);
  check('合并时保留原有 id', merged.first.id == created.first.id);
  check('合并时更新 detail', merged.first.detail == '和家里谈过了');

  final distinct = book.merge(merged, const OpenThreadDraft(
    topic: '那个红发少女的故事',
    detail: '想写成游戏',
  ), now: now);
  check('不同话题各自成条', distinct.length == 2);

  final resolved = book.resolve(distinct, distinct.first.id, now: now);
  check('可以标记为已有下文',
      resolved.firstWhere((t) => t.id == distinct.first.id).isOpen == false);
  check('其余条目不受影响', resolved.length == 2);
  check('未知 id 不会误改任何条目',
      identical(book.resolve(distinct, 'not-a-real-id', now: now), distinct));
  check('空 id 安全', identical(book.resolve(distinct, null, now: now), distinct));

  final stale = [
    thread('a', '很久以前的悬案',
        status: ThreadStatus.resolved,
        updatedAt: now.subtract(const Duration(days: 90)).toIso8601String()),
    thread('b', '还开着的悬案'),
  ];
  check('过期的已解决条目被清掉',
      !book.prune(stale, now: now).any((t) => t.id == 'a'));

  final many = [
    for (var i = 0; i < OpenThread.maxThreads + 4; i++)
      thread('t$i', '悬案$i',
          updatedAt: now.add(Duration(minutes: i)).toIso8601String()),
  ];
  check('条数被限制在上限内',
      book.prune(many, now: now).length == OpenThread.maxThreads);
  check('裁剪后保留最新的一条',
      book.prune(many, now: now).any((t) => t.id == 't${many.length - 1}'));

  // 相似度
  check('包含关系算相似', book.isSimilarTopic('保研还是去海外', '去海外'));
  check('无关话题不算相似',
      !book.isSimilarTopic('保研还是去海外', '那个红发少女的故事'));
  check('标点差异不影响判定',
      book.isSimilarTopic('保研，还是去海外？', '保研还是去海外'));

  // ------------------------------------------------------------ 回归弧
  section('回归弧（C3）');
  check('2 小时 → 不问候', ReturnArc.tierFor(const Duration(hours: 2)) == null);
  check('3 小时 → hours',
      ReturnArc.tierFor(const Duration(hours: 3)) == ReturnTier.hours);
  check('25 小时 → days',
      ReturnArc.tierFor(const Duration(hours: 25)) == ReturnTier.days);
  check('8 天 → weeks',
      ReturnArc.tierFor(const Duration(days: 8)) == ReturnTier.weeks);
  check('40 天 → months',
      ReturnArc.tierFor(const Duration(days: 40)) == ReturnTier.months);

  const arc = ReturnArc();
  final pendingThread = thread('x', '保研还是去海外',
      updatedAt: now.subtract(const Duration(days: 3)).toIso8601String());

  for (final tier in [ReturnTier.days, ReturnTier.weeks, ReturnTier.months]) {
    final line = arc.greetingFor(
      tier: tier,
      threads: [pendingThread],
      now: now,
      random: math.Random(1),
    );
    check('$tier 档位会把悬案端出来', line.contains('保研还是去海外'));
  }

  final hourly = arc.greetingFor(
    tier: ReturnTier.hours,
    threads: [pendingThread],
    now: now,
    random: math.Random(1),
  );
  check('刚走开三小时不追问悬案', !hourly.contains('保研还是去海外'));
  check('短档位用环境台词', kReturnGreetingHours.contains(hourly));

  final noThreads = arc.greetingFor(
    tier: ReturnTier.days,
    threads: const [],
    now: now,
    random: math.Random(1),
  );
  check('没有悬案时回落到环境台词', kReturnGreetingDays.contains(noThreads));

  final staleThread = thread('s', '去年的旧事',
      updatedAt: now.subtract(const Duration(days: 200)).toIso8601String());
  final staleLine = arc.greetingFor(
    tier: ReturnTier.weeks,
    threads: [staleThread],
    now: now,
    random: math.Random(1),
  );
  check('过期悬案不当问候题材', !staleLine.contains('去年的旧事'));

  final settledThread = thread('r', '要不要休学一年',
      status: ThreadStatus.resolved,
      updatedAt: now.subtract(const Duration(days: 2)).toIso8601String());
  final settledLine = arc.greetingFor(
    tier: ReturnTier.days,
    threads: [settledThread],
    now: now,
    random: math.Random(2),
  );
  check('刚落定的悬案换一种问候', settledLine.contains('答案') ||
      settledLine.contains('落定') ||
      settledLine.contains('要不要休学一年'));
  check('模板里的 {topic} 不会漏出来', !settledLine.contains('{topic}'));

  // ------------------------------------------------------------ 记忆上限
  section('记忆簿记（C2 保护书签）');
  const memoryBook = MemoryBook();
  final full = [
    for (var i = 0; i < kMaxLibraryMemory - 1; i++) fact('事实$i'),
    bookmark('她说过的一句很好的话'),
  ];
  final afterAppend = memoryBook.append(full, fact('新事实'));
  check('总数不超过上限', afterAppend.length == kMaxLibraryMemory);
  check('书签在裁剪中被保住',
      afterAppend.any((m) => m.content == '她说过的一句很好的话'));
  check('最旧的事实先被淘汰', !afterAppend.any((m) => m.content == '事实0'));
  check('新记忆被保留', afterAppend.any((m) => m.content == '新事实'));

  // 全部是书签时仍然要能收敛
  final allBookmarks = [
    for (var i = 0; i < kMaxLibraryMemory; i++) bookmark('书签$i'),
  ];
  final bookmarksCapped = memoryBook.append(allBookmarks, bookmark('新书签'));
  check('极端情况下也能维持上限',
      bookmarksCapped.length == kMaxLibraryMemory);

  // ------------------------------------------------------------ 记忆整理解析
  section('记忆整理解析（C3 提取）');
  final service = MemoryCaptureService(ChatApiClient());
  final existing = [thread('abc', '保研还是去海外')];

  final outcome = service.parseOutcome(
    '```json\n'
    '{"shouldRemember": true, "category": "困扰",'
    ' "memory": "来访者害怕自己会后悔没有选那条确定的路",'
    ' "evidence": "我会害怕我没有选那条确定的路", "confidence": 0.9,'
    ' "openThread": {"topic": "要不要接受保研", "detail": "在等一个结果"},'
    ' "resolveThreadId": null}\n```',
    existingMemories: const [],
    openThreads: existing,
  );
  check('记忆被解析出来', outcome.memory != null);
  check('记忆长度受 45 字上限约束',
      (outcome.memory?.content.length ?? 0) <= kMaxMemoryContentLength);
  check('未决之事被解析出来', outcome.threadDraft != null);
  check('话题正确', outcome.threadDraft?.topic == '要不要接受保研');

  final resolver = service.parseOutcome(
    '{"shouldRemember": false, "openThread": null, "resolveThreadId": "abc"}',
    existingMemories: const [],
    openThreads: existing,
  );
  check('可以回填已解决的 id', resolver.resolveThreadId == 'abc');
  check('没有记忆时结果不为空', !resolver.isEmpty);

  final hallucinated = service.parseOutcome(
    '{"shouldRemember": false, "openThread": null, "resolveThreadId": "编造的id"}',
    existingMemories: const [],
    openThreads: existing,
  );
  check('凭空编造的 id 被拒绝', hallucinated.resolveThreadId == null);
  check('被拒绝后结果为空', hallucinated.isEmpty);

  final lowConfidence = service.parseOutcome(
    '{"shouldRemember": true, "memory": "来访者喜欢某种东西", "evidence": "x",'
    ' "confidence": 0.3, "openThread": null, "resolveThreadId": null}',
    existingMemories: const [],
    openThreads: const [],
  );
  check('低于置信度阈值的记忆被丢弃', lowConfidence.memory == null);

  final junk = service.parseOutcome('模型今天不想输出 JSON',
      existingMemories: const [], openThreads: const []);
  check('非 JSON 输出安全降级', junk.isEmpty);

  final overlong = service.parseOutcome(
    '{"shouldRemember": true, "memory":'
    ' "来访者非常喜欢${'很' * 80}长的记忆条目，这条明显超过了四十五个字的上限应该被裁剪",'
    ' "evidence": "${'依据' * 60}", "confidence": 0.9,'
    ' "openThread": null, "resolveThreadId": null}',
    existingMemories: const [],
    openThreads: const [],
  );
  check('超长记忆被裁剪到上限内',
      (overlong.memory?.content.length ?? 0) <= kMaxMemoryContentLength + 1);
  check('超长依据被裁剪到上限内',
      (overlong.memory?.evidence.length ?? 0) <= kMaxMemoryEvidenceLength + 1);

  // ------------------------------------------------------------ 上下文过滤
  section('上下文组装');
  final context = const ConversationContext().buildMessages(
    persona: '人设',
    messages: const [
      ChatMessage(role: 'user', content: '我昨天买了一张书签'),
      ChatMessage(role: 'assistant', content: '她真的说过的话'),
      ChatMessage(
          role: 'assistant', content: '灯芯跳了一下。', kind: MessageKind.ambient),
      ChatMessage(
          role: 'assistant',
          content: '收好了。亲爱的，这句话现在属于图书馆了。',
          kind: MessageKind.notice),
      ChatMessage(
          role: 'assistant', content: '连接没有成功：超时', kind: MessageKind.error),
    ],
    memories: [fact('来访者喜欢轨迹系列的生活气')],
    threads: [thread('t1', '保研还是去海外')],
  );
  final dialogue = context
      .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
      .map((m) => m['content']!)
      .toList();
  check('环境语不进上下文', !dialogue.contains('灯芯跳了一下。'));
  check('回执不进上下文', !dialogue.any((c) => c.contains('属于图书馆了')));
  check('报错不进上下文', !dialogue.any((c) => c.contains('连接没有成功')));
  check('真实对话进上下文', dialogue.contains('她真的说过的话'));
  check('含「书签」二字的真话不会被吞掉',
      dialogue.any((c) => c.contains('我昨天买了一张书签')));
  check('未决之事作为系统提示注入',
      context.any((m) => m['content']!.contains('保研还是去海外')));

  // ------------------------------------------------------------ 收尾
  print('');
  if (_failures == 0) {
    print('全部通过。');
  } else {
    print('$_failures 项失败。');
    exitCode = 1;
  }
}

bool _noAdjacentDuplicates(List<String> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] == values[i - 1]) return false;
  }
  return true;
}
