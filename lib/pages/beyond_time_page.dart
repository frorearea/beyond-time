import 'dart:async';

import 'package:flutter/material.dart';

import '../models/api_settings.dart';
import '../services/archive_service.dart';
import '../services/library_session.dart';
import '../services/tarot_reading_service.dart';
import '../theme.dart';
import '../widgets/archive_panel.dart';
import '../widgets/candle_glow.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/memory_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/shelf_panel.dart';
import '../widgets/sound_control.dart';
import '../widgets/stage_decor.dart';
import '../widgets/storybook_frame.dart';
import '../widgets/storybook_title.dart';
import '../widgets/thread_section.dart';

/// 视图层。
///
/// 这里只保留"眼睛和手"：布局、对话框、输入框与滚动。所有会话状态
/// （对话、记忆、未决之事、画像、回归弧、环境语）与持久化都在
/// [LibrarySession] 里。页面不再直接写存储、不再自己拼 API 请求。
class BeyondTimePage extends StatefulWidget {
  const BeyondTimePage({super.key, this.session});

  /// 测试注入用。为空时使用平台存储创建会话。
  ///
  /// 这个口子必须存在：否则 widget 测试只能去读写本机真实的
  /// `%APPDATA%\BeyondTime`（会话构造函数就会写用户画像），
  /// 一跑测试就污染真实数据。
  final LibrarySession? session;

  @override
  State<BeyondTimePage> createState() => _BeyondTimePageState();
}

class _BeyondTimePageState extends State<BeyondTimePage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ArchiveService _archiveService = ArchiveService();
  final TarotReadingService _tarotReadingService = const TarotReadingService();

  late final LibrarySession _session;

  /// 会话是页面自己建的才由页面销毁；注入进来的由调用方负责。
  late final bool _ownsSession;

  int _lastMessageCount = 0;
  int _lastTailLength = 0;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? LibrarySession();
    _session.addListener(_onSessionChanged);
    _syncSettingsControllers();
    unawaited(_session.start());
    _jumpToBottomAfterOpen();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    if (_ownsSession) _session.dispose();
    _inputController.dispose();
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  /// 只在"对话本身变了"时滚动，避免开关设置也把视图拽到底部。
  void _onSessionChanged() {
    final messages = _session.messages;
    final count = messages.length;
    final tailLength = messages.isEmpty ? 0 : messages.last.content.length;
    final shouldScroll =
        count != _lastMessageCount || tailLength != _lastTailLength;
    _lastMessageCount = count;
    _lastTailLength = tailLength;
    if (!mounted) return;
    setState(() {});
    if (shouldScroll) _scrollToBottom();
  }

  void _syncSettingsControllers() {
    final settings = _session.apiSettings;
    _apiKeyController.text = settings.apiKey;
    _apiUrlController.text = settings.apiUrl;
    _modelController.text = settings.model;
  }

  // ------------------------------------------------------------------ 布局

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 640;
    final effectiveLayout =
        _session.uiLayout == 'storybook' && isWide ? 'storybook' : 'classic';
    return Scaffold(
      backgroundColor: kBlack,
      body: effectiveLayout == 'storybook'
          ? _buildStorybookLayout()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: kStageMaxWidth, maxHeight: kStageMaxHeight),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    final dialogueHeight = constraints.maxHeight * 0.50;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(isNarrow ? 12 : 22,
                                isNarrow ? 52 : 28, isNarrow ? 12 : 22, 24),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: WitchPortrait(),
                                      ),
                                      Positioned.fill(child: CandleGlow()),
                                      Positioned.fill(child: SkyLines()),
                                    ],
                                  ),
                                ),
                                const SloganQuote(),
                                SizedBox(
                                  height: dialogueHeight,
                                  child: _buildDialogueBox(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 18,
                          left: isNarrow ? 16 : 22,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TopTextButton(label: '记忆', onTap: _openMemoryPanel),
                              const SizedBox(width: 18),
                              TopTextButton(label: '书架', onTap: _openShelfPanel),
                              if (_session.canStartTarotReading) ...[
                                const SizedBox(width: 18),
                                TopTextButton(
                                    label: '占卜', onTap: _startTarotReading),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: 18,
                          right: isNarrow ? 16 : 22,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TopTextButton(
                                  label: '存档', onTap: _openArchivePanel),
                              const SizedBox(width: 18),
                              const SoundControl(),
                              const SizedBox(width: 18),
                              TopTextButton(label: '设置', onTap: _openSettings),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildDialogueBox({bool storybookMode = false}) {
    return DialogueBox(
      messages: _session.messages,
      isSending: _session.isSending,
      quickOptions: _session.quickOptions,
      showQuickOptions: _session.showQuickOptions,
      inputController: _inputController,
      scrollController: _messageScrollController,
      onSend: _sendCurrentText,
      onClear: _clearChat,
      onQuickOption: _handleQuickOption,
      onRefreshQuickOptions: _refreshQuickOptions,
      onBookmarkSelected: _bookmarkSelectedText,
      storybookMode: storybookMode,
    );
  }

  Widget _buildStorybookLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        final toolbarIsCompact = constraints.maxWidth < 720;
        final outerPadding = constraints.maxWidth < 560 ? 6.0 : 14.0;

        final portrait = Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x70FFFFFF)),
          ),
          child: StorybookPortraitPanel(showQuote: !isCompact),
        );

        return Padding(
          padding: EdgeInsets.all(outerPadding),
          child: StorybookFrame(
            child: Column(
              children: [
                _buildStorybookToolbar(toolbarIsCompact),
                const Divider(height: 1, color: Color(0x99FFFFFF)),
                Expanded(
                  child: isCompact
                      ? Column(
                          children: [
                            Expanded(flex: 3, child: portrait),
                            const StorybookSpine(vertical: false),
                            Expanded(
                              flex: 7,
                              child: _buildDialogueBox(storybookMode: true),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: portrait),
                            const StorybookSpine(),
                            Expanded(
                              child: _buildDialogueBox(storybookMode: true),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorybookToolbar(bool compact) {
    final leftActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopTextButton(label: '记忆', onTap: _openMemoryPanel),
        const SizedBox(width: 14),
        TopTextButton(label: '书架', onTap: _openShelfPanel),
        if (_session.canStartTarotReading) ...[
          const SizedBox(width: 14),
          TopTextButton(label: '占卜', onTap: _startTarotReading),
        ],
      ],
    );
    final rightActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopTextButton(label: '存档', onTap: _openArchivePanel),
        const SizedBox(width: 14),
        const SoundControl(),
        const SizedBox(width: 14),
        TopTextButton(label: '设置', onTap: _openSettings),
      ],
    );

    if (compact) {
      return SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const StorybookTitle(compact: true),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  leftActions,
                  const Spacer(),
                  rightActions,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
                child:
                    Align(alignment: Alignment.centerLeft, child: leftActions)),
            const StorybookTitle(),
            Expanded(
              child:
                  Align(alignment: Alignment.centerRight, child: rightActions),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 交互

  Future<void> _sendCurrentText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    // 立刻清空输入框：发出的话不该留在框里等着被重发。
    // 这一步必须在 await 之前——等模型回复再清，用户会盯着自己已经发出去的话
    // 留在原地，而失败分支还会把它留在那儿。
    _inputController.clear();
    final outcome = await _session.send(text);
    if (outcome.status == SendStatus.missingApiKey) {
      _openSettings();
    }
  }

  Future<void> _handleQuickOption(String text) async {
    if (_session.isSending) return;
    _session.advanceQuickOptions();
    _inputController.clear();
    await _session.send(text);
  }

  void _refreshQuickOptions() {
    _session.advanceQuickOptions();
  }

  Future<void> _startTarotReading() async {
    if (_session.isSending) return;
    final memories = _session.tarotMemories;
    if (memories.length < 5) {
      _showSnack('图书馆记忆还不够。再让艾蕾塔认识您一点吧。');
      return;
    }

    final spread = _tarotReadingService.drawSpread();
    await _session.send(
      '请为我进行一次占卜',
      captureMemory: false,
      extraSystemInstruction: _tarotReadingService.buildReadingInstruction(
        spread: spread,
        memories: memories,
      ),
      maxTokens: 900,
    );
  }

  void _bookmarkSelectedText(String selectedText) {
    if (_session.isSending) return;
    final quote = selectedText.trim();
    if (quote.isEmpty) return;
    _session.addBookmark(quote);
  }

  // ------------------------------------------------------------------ 面板

  void _openSettings() {
    _syncSettingsControllers();
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      barrierDismissible: true,
      barrierLabel: '关闭设置',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SettingsPanel(
            apiKeyController: _apiKeyController,
            apiUrlController: _apiUrlController,
            modelController: _modelController,
            uiLayout: _session.uiLayout,
            onLayoutChanged: _session.updateLayout,
            showQuickOptions: _session.showQuickOptions,
            onQuickOptionsChanged: _session.setShowQuickOptions,
            onSave: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            onReset: () {
              _apiKeyController.clear();
              _apiUrlController.text = const ApiSettings().apiUrl;
              _modelController.text = const ApiSettings().model;
              _saveSettings();
              _session.updateLayout('classic');
              _session.setShowQuickOptions(false);
            },
          ),
        );
      },
    );
  }

  void _saveSettings() {
    _session.updateApiSettings(
      ApiSettings(
        apiKey: _apiKeyController.text.trim(),
        apiUrl: _apiUrlController.text.trim(),
        model: _modelController.text.trim(),
      ),
    );
  }

  void _openMemoryPanel() {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      barrierDismissible: true,
      barrierLabel: '关闭记忆',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: MemoryPanel(
            memories: _session.knowledgeMemories,
            header: ThreadSection(
              threads: [..._session.openThreads, ..._session.resolvedThreads],
            ),
          ),
        );
      },
    );
  }

  void _openShelfPanel() {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      barrierDismissible: true,
      barrierLabel: '关闭书架',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: ShelfPanel(bookmarks: _session.bookmarks),
        );
      },
    );
  }

  void _openArchivePanel() {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      barrierDismissible: true,
      barrierLabel: '关闭存档',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: ArchivePanel(
            messageCount: _session.conversationHistory.length,
            memoryCount: _session.memories.length,
            threadCount: _session.threads.length,
            onExport: _exportArchive,
            onImport: _importArchive,
            onClearAll: _confirmClearArchive,
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ 存档

  Future<void> _exportArchive() async {
    try {
      final message = await _archiveService.exportArchiveText(
        fileName: _archiveFileName(),
        content: _session.buildArchiveText(),
      );
      _showSnack(message);
    } catch (_) {
      _showSnack('存档导出失败。');
    }
  }

  Future<void> _importArchive() async {
    try {
      final raw = await _archiveService.importArchiveText();
      if (raw == null || raw.trim().isEmpty) {
        _showSnack('没有选中可导入的存档。');
        return;
      }

      final confirmed = await _confirmArchiveAction(
        title: '导入图书馆存档',
        message: '导入会覆盖当前对话、记忆、未决之事和心声进度，但不会修改 API 设置。',
      );
      if (!confirmed) return;

      final status = _session.importArchive(raw);
      switch (status) {
        case ImportStatus.ok:
          _jumpToBottomAfterOpen();
          _showSnack('图书馆存档已经恢复。');
        case ImportStatus.empty:
          _showSnack('没有选中可导入的存档。');
        case ImportStatus.unreadable:
          _showSnack('这份存档读不出来。');
      }
    } catch (_) {
      _showSnack('存档导入失败。');
    }
  }

  Future<void> _confirmClearArchive() async {
    final confirmed = await _confirmArchiveAction(
      title: '清空图书馆',
      message: '这会删除本机保存的对话、记忆、未决之事和心声进度，但不会修改 API 设置。',
      danger: true,
    );
    if (!confirmed) return;
    _session.resetEverything();
    _showSnack('图书馆已经清空。');
  }

  Future<bool> _confirmArchiveAction({
    required String title,
    required String message,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kBlack,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: kWhite),
          ),
          title: Text(title, style: const TextStyle(color: kWhite)),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                danger ? '清空' : '确认',
                style:
                    TextStyle(color: danger ? const Color(0xFFFFB8B8) : kWhite),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  String _archiveFileName() {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_')
        .split('-')
        .take(6)
        .join('-');
    return 'beyond-time-library-$stamp.json';
  }

  // ------------------------------------------------------------------ 杂项

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1700),
        backgroundColor: Colors.black,
      ),
    );
  }

  void _clearChat() {
    _session.clearChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _jumpToBottomAfterOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
      _messageScrollController.jumpTo(
        _messageScrollController.position.maxScrollExtent,
      );
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted || !_messageScrollController.hasClients) return;
        _messageScrollController.jumpTo(
          _messageScrollController.position.maxScrollExtent,
        );
      });
    });
  }
}
