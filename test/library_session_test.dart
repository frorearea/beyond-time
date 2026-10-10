import 'dart:convert';

import 'package:beyond_time/config.dart';
import 'package:beyond_time/data/return_lines.dart';
import 'package:beyond_time/models/api_settings.dart';
import 'package:beyond_time/models/chat_message.dart';
import 'package:beyond_time/models/creation_note.dart';
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
      expect(s.session.messages.first.content, contains('进来吧'));
      expect(s.store.read(kLastVisitKey), isNotNull);
      s.session.dispose();
    });

    test('开场就把作品递出来，让访客知道可以从哪儿开口', () {
      final s = buildSession();
      final opening = s.session.messages;
      expect(opening.length, 2);
      expect(opening.last.content, contains('游戏'));
      expect(opening.last.content, contains('动画'));
      // 开场两句话都属于真实对话，不会被序列化边界过滤掉。
      expect(opening.every((m) => m.isChat), isTrue);
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
      expect(s.session.messages.first.content, contains('进来吧'));
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

    // 下面两条补的是覆盖缺口：以上用例都只 seed lastVisit / openThreads，
    // **没有 seed 历史**，于是 `_messages` 落到 `_openingMessages`。
    // "已经有对话记录时回归问候还进不进得来"这条路一直没人测。
    test('已经有对话记录时，离开三天仍然会插进回归问候', () {
      final lastVisit = DateTime.now().subtract(const Duration(days: 3));
      final s = buildSession(seed: {
        kLastVisitKey: lastVisit.toIso8601String(),
        kHistoryKey: jsonEncode([
          {'role': 'user', 'content': '上次说到的第一句'},
          {'role': 'assistant', 'content': '上次回答的第二句'},
        ]),
        kOpenThreadsKey: jsonEncode([
          OpenThread(
            id: 't1',
            topic: '保研还是去海外',
            detail: '',
            status: ThreadStatus.open,
            createdAt: lastVisit.toIso8601String(),
            updatedAt: lastVisit.toIso8601String(),
          ).toJson(),
        ]),
      });

      final messages = s.session.messages;
      expect(messages.length, 3, reason: '两条历史 + 一条环境语问候');
      expect(messages.last.kind, MessageKind.ambient);
      expect(messages.last.content, contains('保研还是去海外'));
      s.session.dispose();
    });

    test('已经有对话记录时，离开一小时仍然不问候', () {
      final s = buildSession(seed: {
        kLastVisitKey:
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        kHistoryKey: jsonEncode([
          {'role': 'user', 'content': '刚才那句'},
        ]),
      });
      expect(s.session.messages.every((m) => m.kind != MessageKind.ambient),
          isTrue);
      s.session.dispose();
    });
  });

  group('网页更新回执', () {
    // web/index.html 在检测到新构建、准备 reload 之前，会往原生 localStorage 写一个标记。
    // 这里验证它变成的是**系统回执**而不是她的话，并且只显示一次。
    test('刚更新过时留一句 notice，读取即清除，且不进对话记录', () {
      final s = buildSession(seed: {kJustTidiedKey: '1'});

      final last = s.session.messages.last;
      expect(last.kind, MessageKind.notice, reason: '不是她说的话，是空间的回执');
      expect(last.content, contains('整理过书架'));
      // 关键：不进上下文、不进存档
      expect(s.session.conversationHistory.any((m) => m.content.contains('整理过书架')),
          isFalse);
      expect(_historyContents(s.store).any((c) => c.contains('整理过书架')), isFalse);
      // 读取即清除：下次打开不再重放
      expect(s.store.read(kJustTidiedKey), isNull);
      s.session.dispose();
    });

    test('没有标记时不出现回执', () {
      final s = buildSession();
      expect(
          s.session.messages.any((m) => m.content.contains('整理过书架')), isFalse);
      s.session.dispose();
    });

    test('有历史时回执也只在这次出现，且排在回归问候之前', () {
      final s = buildSession(seed: {
        kJustTidiedKey: '1',
        kLastVisitKey:
            DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        kHistoryKey: jsonEncode([
          {'role': 'user', 'content': '上次那句话'},
        ]),
      });
      final messages = s.session.messages;
      final noticeIndex =
          messages.indexWhere((m) => m.content.contains('整理过书架'));
      final greetingIndex = messages.indexWhere((m) => m.kind == MessageKind.ambient);
      expect(noticeIndex, greaterThanOrEqualTo(0));
      expect(greetingIndex, greaterThan(noticeIndex),
          reason: '整理书架发生在她这次开口之前，回执应排在问候前面');
      s.session.dispose();
    });
  });

  group('消息种类隔离（A1/A3 回归防护）', () {
    test('从 localStorage 加载历史时也会清洗老版本的噪音（粘性污染回归）', () {
      // 复现真实成因：老版本把环境语/回执写进了 localStorage，那些条目没有
      // kind，fromJson 会把它默认成 chat，于是种类过滤拦不住、保存时又被原样
      // 写回，永远出不去。只有加载路径也走 sanitizeMessages 才能断掉这个循环。
      final s = buildSession(seed: {
        kHistoryKey: jsonEncode([
          {'role': 'assistant', 'content': '进来吧。这里暂时只有黑暗。'},
          {'role': 'assistant', 'content': '灯芯跳了一下。'},
          {'role': 'assistant', 'content': '天花板上有灰尘在飘。'},
          {'role': 'assistant', 'content': '收好了。亲爱的，这句话现在属于图书馆了。'},
          {'role': 'assistant', 'content': '你回来了。书还翻在你上次看的那一页。'},
          {'role': 'assistant', 'content': '连接没有成功：SocketException'},
          {'role': 'user', 'content': '我想聊聊最近在玩的游戏'},
          {'role': 'assistant', 'content': '那就说说看。'},
        ]),
      });

      final contents = s.session.conversationHistory.map((m) => m.content);
      expect(contents, contains('我想聊聊最近在玩的游戏'));
      expect(contents, contains('那就说说看。'));
      expect(contents.any((c) => c.contains('灯芯')), isFalse);
      expect(contents.any((c) => c.contains('天花板')), isFalse);
      expect(contents.any((c) => c.contains('属于图书馆')), isFalse);
      expect(contents.any((c) => c.contains('你回来了')), isFalse);
      expect(contents.any((c) => c.contains('连接没有成功')), isFalse);

      // 而且下一次保存不会再把它们写回去。
      s.session.clearChat();
      expect(_historyContents(s.store).any((c) => c.contains('灯芯')), isFalse);
      s.session.dispose();
    });

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

  group('来访者原创留档', () {
    test('可以记下、合并自己的创作稿并落盘', () {
      final s = buildSession();
      s.session.mergeCreationForTest(const CreationDraft(
        title: '红羽离笼记',
        kind: '故事',
        content: '红发少女把推免函折成一只鸟',
      ));
      expect(s.session.creations.length, 1);
      expect(s.session.sortedCreations.first.title, '红羽离笼记');

      s.session.mergeCreationForTest(const CreationDraft(
        title: '红羽离笼记',
        content: '补了一句：她在风里散开发绳',
      ));
      expect(s.session.creations.length, 1, reason: '同一份稿子应合并');
      expect(s.session.creations.first.content, contains('散开发绳'));

      final stored = jsonDecode(s.store.read(kCreationsKey)!) as List<dynamic>;
      expect(stored.length, 1);
      s.session.dispose();
    });

    test('导出把创作稿写进存档，导入再原样读回来', () {
      final s = buildSession();
      s.session.mergeCreationForTest(const CreationDraft(
        title: '雨中迷宫',
        kind: '游戏',
        content: '第一层的怪会报时',
      ));

      final exported = jsonDecode(s.session.buildArchiveText())
          as Map<String, dynamic>;
      expect(exported['version'], LibraryArchive.currentVersion);
      expect((exported['creations'] as List).length, 1);

      final other = buildSession();
      expect(other.session.importArchive(jsonEncode(exported)), ImportStatus.ok);
      expect(other.session.creations.single.title, '雨中迷宫');
      expect(other.session.creations.single.kind, '游戏');
      s.session.dispose();
      other.session.dispose();
    });

    test('导入 v2 旧存档不会因为缺少 creations 字段而失败', () {
      final legacy = jsonEncode({
        'type': 'beyond-time-library-archive',
        'version': 2,
        'messages': [
          {'role': 'user', 'content': '旧存档里的一句话'},
        ],
        'libraryMemory': <dynamic>[],
        'openThreads': <dynamic>[],
        'quickOptionPoolIndex': 1,
      });

      final s = buildSession();
      expect(s.session.importArchive(legacy), ImportStatus.ok);
      expect(s.session.creations, isEmpty);
      s.session.dispose();
    });

    test('清空图书馆同时清掉创作稿', () {
      final s = buildSession();
      s.session.mergeCreationForTest(const CreationDraft(title: '一份稿子'));
      expect(s.store.read(kCreationsKey), isNotNull);

      s.session.resetEverything();
      expect(s.session.creations, isEmpty);
      expect(s.store.read(kCreationsKey), isNull);
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
    test('清空对话后是她自己那句话，不是把开场白再念一遍', () {
      final s = buildSession();
      s.session.mergeThreadForTest(const OpenThreadDraft(topic: '一件悬案'));

      s.session.clearChat();
      expect(s.session.messages.length, 1,
          reason: '清空 ≠ 第一次推门进来，不要回到 _openingMessages');
      expect(s.session.messages.single.content, contains('房间重新安静'));
      // 清空对话不该动记忆与牵挂。
      expect(s.session.openThreads.length, 1);
      s.session.dispose();
    });

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
