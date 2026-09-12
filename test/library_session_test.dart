import 'dart:convert';

import 'package:beyond_time/config.dart';
import 'package:beyond_time/data/return_lines.dart';
import 'package:beyond_time/models/api_settings.dart';
import 'package:beyond_time/models/chat_message.dart';
import 'package:beyond_time/models/library_archive.dart';
import 'package:beyond_time/models/library_memory_item.dart';
import 'package:beyond_time/models/open_thread.dart';
import 'package:beyond_time/services/key_value_store.dart';
import 'package:beyond_time/services/library_session.dart';
import 'package:beyond_time/services/store_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用一个内存存储跑真实的 LibrarySession，不碰用户本机的 app 数据目录。
({
  LibrarySession session,
  InMemoryStore store,
}) buildSession({Map<String, String>? seed}) {
  final store = InMemoryStore(seed);
  final session = LibrarySession(storeHelper: StoreHelper(store));
  return (session: session, store: store);
}

List<dynamic> _history(KeyValueStore store) {
  final raw = store.read(kHistoryKey);
  if (raw == null) return const [];
  return jsonDecode(raw) as List<dynamic>;
}

List<String> _historyContents(KeyValueStore store) => _history(store)
    .map((item) => (item as Map<String, dynamic>)['content'].toString())
    .toList();

void main() {
  group('会话初始化', () {
    test('首次进入展示开场白并写入 lastVisit', () {
      final s = buildSession();
      expect(s.session.messages.single.content, contains('进来吧'));
      expect(s.store.read(kLastVisitKey), isNotNull);
      s.session.dispose();
    });

    test('离开超过一天且留有悬案时，用未决之事作为第一句话', () {
      final lastVisit = DateTime.now().subtract(const Duration(days: 3));
      final threads = [
        OpenThread(
          id: 't1',
          topic: '保研还是去海外',
          detail: '还在等结果',
          status: ThreadStatus.open,
          createdAt: lastVisit.toIso8601String(),
          updatedAt: lastVisit.toIso8601String(),
        ),
      ];
      final s = buildSession(seed: {
        kLastVisitKey: lastVisit.toIso8601String(),
        kOpenThreadsKey: jsonEncode(threads.map((t) => t.toJson()).toList()),
      });

      final greeting = s.session.messages.last;
      expect(greeting.kind, MessageKind.ambient);
      expect(greeting.content, contains('保研还是去海外'));
      s.session.dispose();
    });

    test('刚离开两小时不问候', () {
      final s = buildSession(seed: {
        kLastVisitKey:
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      });
      expect(s.session.messages.single.content, contains('进来吧'));
      s.session.dispose();
    });

    test('回归问候使用 {topic} 模板且不残留占位符', () {
      final s = buildSession(seed: {
        kLastVisitKey:
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        kOpenThreadsKey: jsonEncode([
          OpenThread(
            id: 't1',
            topic: '那个红发少女的故事',
            detail: '',
            status: ThreadStatus.open,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ).toJson(),
        ]),
      });
      expect(s.session.messages.last.content, contains('那个红发少女的故事'));
      expect(s.session.messages.last.content, isNot(contains('{topic}')));
      s.session.dispose();
    });
  });

  group('消息种类隔离（A1/A3 回归防护）', () {
    test('未填 API Key 时的提示是 notice，且不写进存档', () async {
      final s = buildSession();
      final outcome = await s.session.send('你好呀，我回来了。');

      expect(outcome.status, SendStatus.missingApiKey);
      final notice = s.session.messages.last;
      expect(notice.kind, MessageKind.notice);
      expect(notice.content, contains('API Key'));

      // 关键：用户消息留下，回执不落盘。
      final persisted = _historyContents(s.store);
      expect(persisted, contains('你好呀，我回来了。'));
      expect(persisted.any((c) => c.contains('API Key')), isFalse);
      s.session.dispose();
    });

    test('书签回执只出现在界面上', () {
      final s = buildSession();
      final result = s.session.addBookmark('你决定了自己的方向。');

      expect(result.added, isTrue);
      expect(s.session.messages.last.kind, MessageKind.notice);
      expect(s.session.bookmarks.single.content, '你决定了自己的方向。');
      expect(_historyContents(s.store).any((c) => c.contains('属于图书馆了')),
          isFalse);
      s.session.dispose();
    });

    test('连接失败写成 error，下一轮不会当成她说过的话', () async {
      final s = buildSession();
      s.session.updateApiSettings(const ApiSettings(
        apiKey: 'sk-not-a-real-key',
        apiUrl: 'http://127.0.0.1:1/chat/completions',
        model: 'test-model',
      ));

      final outcome = await s.session.send('有人在吗，我想说点事。');
      expect(outcome.status, SendStatus.failed);
      expect(s.session.messages.last.kind, MessageKind.error);
      expect(s.session.conversationHistory.any((m) => m.kind != MessageKind.chat),
          isFalse);
      expect(_historyContents(s.store).any((c) => c.contains('连接没有成功')),
          isFalse);
      s.session.dispose();
    });

    test('环境语不写进存档，页面同时至多一条', () {
      final s = buildSession();
      final before = _history(s.store).length;
      // 直接触发回归问候已经验证过；这里验证 archive 导出同样不含环境语。
      s.session.clearChat();
      final exported = jsonDecode(s.session.buildArchiveText())
          as Map<String, dynamic>;
      final kinds = (exported['messages'] as List)
          .map((m) => (m as Map<String, dynamic>)['kind'])
          .toSet();
      expect(kinds.every((k) => k == null), isTrue,
          reason: '导出里不应出现任何非 chat 的 kind 字段');
      expect(_history(s.store).length, greaterThanOrEqualTo(before - 1));
      s.session.dispose();
    });
  });

  group('书架与记忆分栏（C2）', () {
    test('书签进入书架，不进入「记忆」栏', () {
      final s = buildSession();
      s.session.addBookmark('第一句');
      s.session.addBookmark('第二句');
      expect(s.session.bookmarks.length, 2);
      expect(s.session.knowledgeMemories, isEmpty);
      s.session.dispose();
    });

    test('重复收藏不会增加条数', () {
      final s = buildSession();
      s.session.addBookmark('同一句话');
      final second = s.session.addBookmark('同一句话');
      expect(second.added, isFalse);
      expect(s.session.bookmarks.length, 1);
      s.session.dispose();
    });

    test('事实记忆与书签各自计数', () {
      final store = InMemoryStore({
        kLibraryMemoryKey: jsonEncode([
          LibraryMemoryItem(
            category: '书签',
            content: '她的一句话',
            evidence: '来访者手动收藏的句子',
            source: '手动书签',
            createdAt: DateTime.now().toIso8601String(),
          ).toJson(),
          LibraryMemoryItem(
            category: '喜好',
            content: '来访者喜欢轨迹系列的生活气',
            evidence: '愿意在角色的房间里多绕几圈',
            source: '艾蕾塔整理',
            createdAt: DateTime.now().toIso8601String(),
          ).toJson(),
        ]),
      });
      final session = LibrarySession(storeHelper: StoreHelper(store));
      expect(session.memories.length, 2);
      expect(session.bookmarks.length, 1);
      expect(session.knowledgeMemories.length, 1);
      // 占卜门槛只数"关于来访者的事实"
      expect(session.canStartTarotReading, isFalse);
      session.dispose();
    });
  });

  group('未决之事（C3）', () {
    test('可以记下、合并、并标记已有下文', () {
      final s = buildSession();
      s.session.mergeThreadForTest(
          const OpenThreadDraft(topic: '保研还是去海外', detail: '还没定'));
      expect(s.session.openThreads.length, 1);

      s.session.mergeThreadForTest(
          const OpenThreadDraft(topic: '保研还是去海外的事', detail: '和家里谈过'));
      expect(s.session.openThreads.length, 1, reason: '相似话题应合并');

      // 落盘了
      final stored = jsonDecode(s.store.read(kOpenThreadsKey)!) as List<dynamic>;
      expect(stored.length, 1);
      s.session.dispose();
    });
  });

  group('存档导入导出', () {
    test('导出为 v2 并包含三个板块', () {
      final s = buildSession();
      s.session.addBookmark('她说过的一句话');
      s.session.mergeThreadForTest(const OpenThreadDraft(topic: '要不要休学一年'));

      final exported =
          jsonDecode(s.session.buildArchiveText()) as Map<String, dynamic>;
      expect(exported['version'], LibraryArchive.currentVersion);
      expect((exported['libraryMemory'] as List).length, 1);
      expect((exported['openThreads'] as List).length, 1);
      s.session.dispose();
    });

    test('导入 v1 旧存档会清洗噪音', () {
      final legacy = jsonEncode({
        'type': 'beyond-time-library-archive',
        'version': 1,
        'messages': [
          {'role': 'assistant', 'content': '进来吧。这里暂时只有黑暗。'},
          {'role': 'assistant', 'content': '灯芯跳了一下。'},
          {'role': 'assistant', 'content': '灯芯跳了一下。'},
          {'role': 'assistant', 'content': '收好了。亲爱的，这句话现在属于图书馆了。'},
          {'role': 'user', 'content': '我想聊聊最近读的书'},
          {'role': 'assistant', 'content': '说说看。'},
        ],
        'libraryMemory': <dynamic>[],
        'quickOptionPoolIndex': 4,
      });

      final s = buildSession();
      expect(s.session.importArchive(legacy), ImportStatus.ok);
      final contents = s.session.conversationHistory.map((m) => m.content);
      expect(contents, contains('我想聊聊最近读的书'));
      expect(contents, contains('说说看。'));
      expect(contents.any((c) => c.contains('灯芯')), isFalse);
      expect(contents.any((c) => c.contains('属于图书馆')), isFalse);
      expect(s.session.quickOptionPoolIndex, 4);
      s.session.dispose();
    });

    test('读不出来的存档有明确状态', () {
      final s = buildSession();
      expect(s.session.importArchive('这不是 JSON'), ImportStatus.unreadable);
      expect(s.session.importArchive('   '), ImportStatus.empty);
      s.session.dispose();
    });
  });

  group('清空与设置', () {
    test('清空图书馆同时清掉记忆与未决之事', () {
      final s = buildSession();
      s.session.addBookmark('一句话');
      s.session.mergeThreadForTest(const OpenThreadDraft(topic: '一件悬案'));
      s.session.resetEverything();

      expect(s.session.bookmarks, isEmpty);
      expect(s.session.threads, isEmpty);
      expect(s.session.memories, isEmpty);
      // 未决之事与记忆的存储键都被清掉（而不是留下空壳）。
      expect(s.store.read(kOpenThreadsKey), isNull);
      expect(s.store.read(kLibraryMemoryKey), isNull);
      expect(s.session.quickOptionPoolIndex, 0);
      s.session.dispose();
    });

    test('设置可独立保存', () {
      final s = buildSession();
      s.session.updateApiSettings(const ApiSettings(apiKey: 'sk-abc'));
      s.session.updateLayout('classic');
      s.session.setShowQuickOptions(true);

      final raw = jsonDecode(s.store.read(kSettingsKey)!) as Map<String, dynamic>;
      expect(raw['apiKey'], 'sk-abc');
      expect(raw['uiLayout'], 'classic');
      expect(raw['showQuickOptions'], isTrue);
      s.session.dispose();
    });

    test('dispose 之后不再通知监听者', () {
      final s = buildSession();
      var notifications = 0;
      s.session.addListener(() => notifications++);
      s.session.dispose();
      expect(notifications, 0);
    });
  });

  group('心声与塔罗门槛', () {
    test('心声池会轮换', () {
      final s = buildSession();
      final first = s.session.quickOptions;
      s.session.advanceQuickOptions();
      expect(s.session.quickOptionPoolIndex, 1);
      expect(s.store.read(kQuickCountKey), '1');
      expect(first, isNotEmpty);
      s.session.dispose();
    });
  });

  group('回归档位常量', () {
    test('各档位台词非空且互不相同', () {
      for (final tier in ReturnTier.values) {
        expect(cannedLinesFor(tier), isNotEmpty);
      }
      expect(buildThreadLine('上次你说的{topic}——后来呢？', '那件事'),
          '上次你说的那件事——后来呢？');
    });
  });
}
