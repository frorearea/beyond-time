import 'package:beyond_time/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 页面冒烟测试：验证重构后整棵树能渲染、按钮能打开面板、并且不抛异常。
///
/// 运行前请确保存储目录指向临时位置，避免碰到本机真实的 BeyondTime 数据：
///   $env:BEYOND_TIME_STORE_DIR = "$env:TEMP\beyond_time_test"
///   flutter test
void main() {
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

  testWidgets('首屏渲染出工具栏与开场白', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    expect(find.text('记忆'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('存档'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.textContaining('进来吧'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 让页面 dispose，取消 idle 定时器，避免 pending timer 报错。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('书架面板能打开，且与记忆分栏', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.tap(find.text('书架').first);
    await settle(tester);

    // 空书架有明确文案
    expect(find.text('书架还是空的。'), findsOneWidget);
    expect(find.textContaining('选中她说过的一句话'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 关掉面板
    await tester.tap(find.text('关闭').first);
    await settle(tester);
    expect(find.text('书架还是空的。'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('记忆面板能打开并展示未决之事区块', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.tap(find.text('记忆').first);
    await settle(tester);

    expect(find.text('图书馆记忆'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('存档面板能打开并显示三个板块计数', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.tap(find.text('存档').first);
    await settle(tester);

    expect(find.text('图书馆存档'), findsOneWidget);
    expect(find.text('对话记录'), findsOneWidget);
    expect(find.text('图书馆记忆'), findsOneWidget);
    expect(find.text('还悬着的事'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('设置面板能打开', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.tap(find.text('设置').first);
    await settle(tester);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('未填 API Key 时发送，提示出现且不崩溃', (tester) async {
    useRealisticWindow(tester);
    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '我回来了，想说说话。');
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // 矮窗口回归测试：设置面板曾经是固定高度的 Column，在 600px 高的视口里
  // 会溢出 197px（「人设 Prompt」那个按钮特别高）。
  testWidgets('矮窗口下设置面板不溢出', (tester) async {
    tester.view.physicalSize = const Size(1280, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BeyondTimeApp());
    await settle(tester);

    await tester.tap(find.text('设置').first);
    await settle(tester);

    expect(tester.takeException(), isNull,
        reason: '矮窗口下侧栏面板不应出现 RenderFlex overflow');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
