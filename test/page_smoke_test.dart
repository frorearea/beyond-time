import 'dart:convert';

import 'package:beyond_time/config.dart';
import 'package:beyond_time/models/open_thread.dart';
import 'package:beyond_time/pages/beyond_time_page.dart';
import 'package:beyond_time/services/key_value_store.dart';
import 'package:beyond_time/services/library_session.dart';
import 'package:beyond_time/services/store_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 页面冒烟测试。
///
/// 一律通过 [BeyondTimePage.session] 注入一个由内存存储驱动的会话：
/// 否则 LibrarySession 会去读写本机真实的 `%APPDATA%\BeyondTime`
/// （构造函数就会写用户画像），跑一次测试就污染真实数据。
///
/// 注意销毁顺序：必须先卸载页面（它会 removeListener）再 dispose 会话，
/// 且都发生在测试体内——会话的 idle 定时器如果在测试结束后还活着，
/// flutter_test 会报 "A Timer is still pending"。
void main() {
  LibrarySession? current;

  // 蜡烛光影是无限循环动画，不能用 pumpAndSettle。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// 用接近真实浏览器窗口的尺寸，而不是 flutter_test 默认的 800x600
  /// （默认尺寸比任何真实窗口都矮，会把侧栏面板挤到溢出）。
  void useRealisticWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 装配页面。默认**不填 API Key**（走"还没填 Key"的提示分支）；
  /// 传 [apiUrl] 时视为已配置密钥，用于复现真实的发送路径。
  ///
  /// 传一个非法 URL 是为了让请求在**不产生真实网络 IO** 的情况下立刻失败，
  /// 这样测试既走完了正常分支，又不会挂起等外部网络。
  Future<LibrarySession> pumpApp(
    WidgetTester tester, {
    String? apiUrl,
  }) async {
    final settings = apiUrl == null
        ? null
        : <String, String>{
            kSettingsKey: jsonEncode({
              'apiKey': 'sk-test-key',
              'apiUrl': apiUrl,
              'model': 'test-model',
            }),
          };
    final session = LibrarySession(
      storeHelper: StoreHelper(InMemoryStore(settings)),
    );
    current = session;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BeyondTimePage(session: session),
    ));
    await settle(tester);
    return session;
  }

  /// 收尾：先卸载页面（removeListener + 取消布局相关资源），再销毁会话。
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    current?.dispose();
    current = null;
  }

  testWidgets('首屏渲染出工具栏与开场白', (tester) async {
    useRealisticWindow(tester);
    await pumpApp(tester);

    expect(find.text('记忆'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('存档'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.textContaining('进来吧'), findsWidgets);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('书架面板能打开，并展示已收藏的句子', (tester) async {
    useRealisticWindow(tester);
    final session = await pumpApp(tester);
    session.addBookmark('你决定了自己的方向，也认领了自己的胆怯。');

    await tester.tap(find.text('书架').first);
    await settle(tester);

    expect(find.textContaining('你决定了自己的方向'), findsOneWidget);
    expect(find.text('书架还是空的。'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('关闭').first);
    await settle(tester);
    expect(find.textContaining('你决定了自己的方向'), findsNothing);

    await teardown(tester);
  });

  testWidgets('空书架有明确文案', (tester) async {
    useRealisticWindow(tester);
    await pumpApp(tester);

    await tester.tap(find.text('书架').first);
    await settle(tester);

    expect(find.text('书架还是空的。'), findsOneWidget);
    expect(find.textContaining('选中她说过的一句话'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('记忆面板能打开并展示未决之事区块', (tester) async {
    useRealisticWindow(tester);
    final session = await pumpApp(tester);
    session.mergeThreadForTest(const OpenThreadDraft(topic: '保研还是去海外'));

    await tester.tap(find.text('记忆').first);
    await settle(tester);

    expect(find.text('图书馆记忆'), findsOneWidget);
    expect(find.text('还悬着的事'), findsOneWidget);
    expect(find.text('保研还是去海外'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('存档面板能打开并显示三个板块计数', (tester) async {
    useRealisticWindow(tester);
    await pumpApp(tester);

    await tester.tap(find.text('存档').first);
    await settle(tester);

    expect(find.text('图书馆存档'), findsOneWidget);
    expect(find.text('对话记录'), findsOneWidget);
    expect(find.text('图书馆记忆'), findsOneWidget);
    expect(find.text('还悬着的事'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('设置面板能打开', (tester) async {
    useRealisticWindow(tester);
    await pumpApp(tester);

    await tester.tap(find.text('设置').first);
    await settle(tester);

    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  // ---------------------------------------------------------------- 发送路径
  //
  // 回归测试：重构时漏掉了「发送后清空输入框」。注意必须在**已配置 API Key**
  // 的前提下测——未配置时旧代码会走 missingApiKey 分支顺手清空，测试就测不出
  // 这个 bug 了（用户遇到的正是"密钥填好了，发出去的话留在框里"）。

  testWidgets('已配置密钥时，点「发送」后输入框立刻清空', (tester) async {
    useRealisticWindow(tester);
    // 非法 URL：走真实发送分支，但请求会立刻失败，不产生网络 IO。
    final session = await pumpApp(tester, apiUrl: 'not-a-valid-url');
    expect(session.isConfigured, isTrue, reason: '本用例必须走"已配置"分支');

    const sent = '我刚刚想到一件还没做完的事。';
    await tester.enterText(find.byType(TextField).first, sent);
    await settle(tester);

    await tester.tap(find.text('发送'));
    await settle(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == sent),
      isFalse,
      reason: '发送后文本框仍然留着刚才那句话',
    );
    // 确实作为消息送出去了，不是"被清掉没发出去"
    expect(session.conversationHistory.any((m) => m.content == sent), isTrue);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('已配置密钥时，按回车发送后输入框也会清空', (tester) async {
    useRealisticWindow(tester);
    await pumpApp(tester, apiUrl: 'not-a-valid-url');

    const sent = '回车这条路也要清干净。';
    await tester.enterText(find.byType(TextField).first, sent);
    await settle(tester);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == sent),
      isFalse,
      reason: '回车发送后文本框仍然留着刚才那句话',
    );
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('未配置密钥时，内容送出、提示出现、不崩溃', (tester) async {
    useRealisticWindow(tester);
    final session = await pumpApp(tester);

    const sent = '我回来了，想说说话。';
    await tester.enterText(find.byType(TextField).first, sent);
    await settle(tester);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);

    // 用户的话留在对话里（不该凭空消失）
    expect(session.conversationHistory.any((m) => m.content == sent), isTrue);
    // 回执不进存档
    expect(
      session.conversationHistory.any((m) => m.content.contains('API Key')),
      isFalse,
    );
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  // 矮窗口回归测试：设置面板曾经是固定高度的 Column，在 600px 高的视口里
  // 会溢出 197px（「人设 Prompt」那个按钮特别高）。
  testWidgets('矮窗口下设置面板不溢出', (tester) async {
    tester.view.physicalSize = const Size(1280, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);

    await tester.tap(find.text('设置').first);
    await settle(tester);

    expect(tester.takeException(), isNull,
        reason: '矮窗口下侧栏面板不应出现 RenderFlex overflow');

    await teardown(tester);
  });
}
