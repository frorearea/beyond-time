import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../data/idle_lines.dart';
import '../data/quick_options.dart';
import '../data/return_lines.dart';
import '../models/chat_message.dart';
import '../models/library_archive.dart';
import '../models/library_memory_item.dart';
import '../models/user_profile.dart';
import '../services/archive_service.dart';
import '../services/bookmark_service.dart';
import '../services/chat_api.dart';
import '../services/conversation_context.dart';
import '../services/error_helper.dart';
import '../services/local_store.dart';
import '../services/memory_capture_service.dart';
import '../services/store_helper.dart';
import '../services/tarot_reading_service.dart';
import '../theme.dart';
import '../widgets/archive_panel.dart';
import '../widgets/candle_glow.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/memory_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/sound_control.dart';
import '../widgets/stage_decor.dart';
import '../widgets/storybook_frame.dart';

class BeyondTimePage extends StatefulWidget {
  const BeyondTimePage({super.key});

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
  final BookmarkService _bookmarkService = const BookmarkService();
  final ChatApiClient _chatApi = ChatApiClient();
  final ConversationContext _conversationContext = const ConversationContext();
  final StoreHelper _storeHelper = StoreHelper(LocalStore());
  final TarotReadingService _tarotReadingService = const TarotReadingService();
  late final MemoryCaptureService _memoryCaptureService =
      MemoryCaptureService(_chatApi);

  List<ChatMessage> _messages = const [
    ChatMessage(role: 'assistant', content: '进来吧。这里暂时只有黑暗、我、还有你可以慢慢放下的声音。'),
  ];
  bool _isSending = false;
  String _persona = kFallbackPersona;
  List<LibraryMemoryItem> _libraryMemory = const [];
  int _quickOptionPoolIndex = 0;
  int _memoryCaptureCooldown = 0;
  bool _isMemoryCaptureRunning = false;
  String _uiLayout = 'storybook';
  bool _showQuickOptions = false;
  Timer? _idleTimer;
  bool _isAway = false;
  late UserProfile _userProfile;

  @override
  void initState() {
    super.initState();
    _loadPersona();
    _loadSettings();
    _loadHistory();
    _loadLibraryMemory();
    _loadUserProfile();
    _checkReturnGreeting();
    _startIdleTimer();
    _jumpToBottomAfterOpen();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _inputController.dispose();
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 640;
    final effectiveLayout = _uiLayout == 'storybook' && isWide ? 'storybook' : 'classic';
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
                                  child: DialogueBox(
                                    messages: _messages,
                                    isSending: _isSending,
                                    quickOptions: _currentQuickOptions(),
                                    showQuickOptions: _showQuickOptions,
                                    inputController: _inputController,
                                    scrollController: _messageScrollController,
                                    onSend: _sendCurrentText,
                                    onClear: _clearChat,
                                    onQuickOption: _handleQuickOption,
                                    onRefreshQuickOptions: _refreshQuickOptions,
                                    onBookmarkSelected: _bookmarkSelectedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: isNarrow ? 18 : 18,
                          left: isNarrow ? 16 : 22,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TopTextButton(
                                  label: '记忆', onTap: _openMemoryPanel),
                              if (_canStartTarotReading)
                                const SizedBox(width: 18),
                              if (_canStartTarotReading) ...[
                                TopTextButton(
                                    label: '占卜', onTap: _startTarotReading),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: isNarrow ? 18 : 18,
                          right: isNarrow ? 16 : 22,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TopTextButton(
                                  label: '存档', onTap: _openArchivePanel),
                              const SizedBox(width: 18),
                              TopTextButton(
                                  label: '设置', onTap: _openSettings),
                              const SizedBox(width: 18),
                              const SoundControl(),
                              const SizedBox(width: 18),
                              TopTextButton(
                                  label: _isAway ? '回来' : '离馆',
                                  onTap: _toggleAway),
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
        final dialogue = DialogueBox(
          messages: _messages,
          isSending: _isSending,
          quickOptions: _currentQuickOptions(),
          showQuickOptions: _showQuickOptions,
          inputController: _inputController,
          scrollController: _messageScrollController,
          onSend: _sendCurrentText,
          onClear: _clearChat,
          onQuickOption: _handleQuickOption,
          onRefreshQuickOptions: _refreshQuickOptions,
          onBookmarkSelected: _bookmarkSelectedText,
          storybookMode: true,
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
                            Expanded(flex: 7, child: dialogue),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: portrait),
                            const StorybookSpine(),
                            Expanded(child: dialogue),
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
        if (_canStartTarotReading) ...[
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
        TopTextButton(label: '设置', onTap: _openSettings),
        const SizedBox(width: 14),
        const SoundControl(),
        const SizedBox(width: 14),
        TopTextButton(label: _isAway ? '回来' : '离馆', onTap: _toggleAway),
      ],
    );

    if (compact) {
      return SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StorybookTitle(compact: true),
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
            const _StorybookTitle(),
            Expanded(
              child:
                  Align(alignment: Alignment.centerRight, child: rightActions),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _currentQuickOptions() {
    return kQuickOptionPools[_quickOptionPoolIndex % kQuickOptionPools.length];
  }

  bool get _canStartTarotReading => _tarotMemories.length >= 5;

  List<LibraryMemoryItem> get _tarotMemories => _libraryMemory
      .where((memory) => memory.content.trim().isNotEmpty)
      .where((memory) => memory.source != '手动书签' || memory.content.length > 14)
      .toList();

  Future<void> _loadPersona() async {
    try {
      final persona = (await rootBundle.loadString(kPersonaAsset)).trim();
      if (!mounted || persona.isEmpty) return;
      setState(() => _persona = persona);
    } catch (_) {
      if (!mounted) return;
      setState(() => _persona = kFallbackPersona);
    }
  }

  Future<void> _handleQuickOption(String text) async {
    if (_isSending) return;
    _startIdleTimer();
    _advanceQuickOptions();
    await _sendText(text, clearInput: true);
  }

  void _refreshQuickOptions() {
    _startIdleTimer();
    _advanceQuickOptions();
  }

  void _advanceQuickOptions() {
    setState(() {
      _quickOptionPoolIndex += 1;
      _storeHelper.saveQuickOptionPoolIndex(_quickOptionPoolIndex);
    });
  }

  Future<void> _startTarotReading() async {
    if (_isSending) return;
    final memories = _tarotMemories;
    if (memories.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图书馆记忆还不够。再让艾蕾塔认识您一点吧。'),
          duration: Duration(milliseconds: 1600),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final spread = _tarotReadingService.drawSpread();
    await _sendText(
      '请为我进行一次占卜',
      clearInput: true,
      captureMemory: false,
      extraSystemInstruction: _tarotReadingService.buildReadingInstruction(
        spread: spread,
        memories: memories,
      ),
      maxTokens: 900,
    );
  }

  Future<void> _bookmarkSelectedText(String selectedText) async {
    if (_isSending) return;
    final quote = selectedText.trim();
    if (quote.isEmpty) return;

    final result = _bookmarkService.addBookmark(
      memories: _libraryMemory,
      selectedText: quote,
    );
    setState(() {
      _libraryMemory = result.memories;
      if (result.added) {
        _storeHelper.saveLibraryMemory(_libraryMemory);
      }
      _messages = [
        ..._messages,
        ChatMessage(role: 'assistant', content: result.notice),
      ];
    });
    _persistHistory();
    _scrollToBottom();
  }

  Future<void> _sendCurrentText() async {
    _startIdleTimer();
    final text = _inputController.text.trim();
    await _sendText(text, clearInput: true);
  }

  Future<void> _sendText(
    String text, {
    bool clearInput = false,
    bool captureMemory = true,
    String? extraSystemInstruction,
    int maxTokens = 520,
  }) async {
    if (_isSending) return;
    if (_isAway) {
      _isAway = false;
    }
    _startIdleTimer();
    text = text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages = [..._messages, ChatMessage(role: 'user', content: text)];
      if (clearInput) {
        _inputController.clear();
      }
      _isSending = true;
    });
    _userProfile.observe(text);
    _storeHelper.saveUserProfile(_userProfile);
    _scrollToBottom();

    if (_apiKeyController.text.trim().isEmpty) {
      setState(() {
        _messages = [
          ..._messages,
          const ChatMessage(
              role: 'assistant', content: '还没有填写 API Key。先打开右上角设置，亲爱的。'),
        ];
        _isSending = false;
      });
      _openSettings();
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        const ChatMessage(role: 'assistant', content: '')
      ];
    });

    try {
      final reply = await _requestStreamingReply(
        extraSystemInstruction: extraSystemInstruction,
        maxTokens: maxTokens,
      );
      _replaceLastAssistant(_conversationContext.cleanReply(reply));
      setState(() => _isSending = false);
      _persistHistory();
      _storeHelper.saveLastVisit(DateTime.now().toIso8601String());
      _scrollToBottom();
      _startIdleTimer();
      if (captureMemory) {
        unawaited(_maybeCaptureMemory(userText: text, assistantReply: reply));
      }
    } catch (error) {
      _replaceLastAssistant('连接没有成功：$error');
      setState(() => _isSending = false);
      _startIdleTimer();
    }
  }

  Future<String> _requestStreamingReply({
    String? extraSystemInstruction,
    int maxTokens = 520,
  }) async {
    final payload = {
      'model': _modelController.text.trim().isEmpty
          ? kDefaultModel
          : _modelController.text.trim(),
      'messages': _conversationContext.buildMessages(
        persona: _persona,
        messages: _messages,
        memories: _libraryMemory,
        userProfile: _userProfile,
        extraSystemInstruction: extraSystemInstruction,
      ),
      'temperature': 1.35,
      'max_tokens': maxTokens,
      'stream': true,
      'stream_options': {'include_usage': false},
      'thinking': {'type': 'enabled'},
    };

    final apiKey = _apiKeyController.text.trim();
    final apiUrl = _apiUrlController.text.trim().isEmpty
        ? kDefaultApiUrl
        : _apiUrlController.text.trim();

    try {
      return await _chatApi.requestStreamingReply(
        payload: payload,
        apiKey: apiKey,
        apiUrl: apiUrl,
        onReply: (reply) {
          _replaceLastAssistant(_conversationContext.cleanReply(reply));
          _scrollToBottom();
        },
      );
    } on ChatApiException catch (error) {
      throw friendlyHttpError(
        error.statusCode,
        error.responseText,
      );
    }
  }

  void _replaceLastAssistant(String content) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      final next = [..._messages];
      next[next.length - 1] = ChatMessage(role: 'assistant', content: content);
      _messages = next;
    });
  }

  Future<void> _maybeCaptureMemory({
    required String userText,
    required String assistantReply,
  }) async {
    final compactUserText = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_memoryCaptureService.shouldSkipUserText(compactUserText)) return;
    if (_apiKeyController.text.trim().isEmpty) return;
    if (_isMemoryCaptureRunning) return;
    if (_memoryCaptureCooldown > 0) {
      _memoryCaptureCooldown -= 1;
      return;
    }

    _isMemoryCaptureRunning = true;
    try {
      final memory = await _memoryCaptureService.capture(
        userText: compactUserText,
        assistantReply: assistantReply,
        existingMemories: _libraryMemory,
        apiKey: _apiKeyController.text.trim(),
        apiUrl: _apiUrlController.text.trim().isEmpty
            ? kDefaultApiUrl
            : _apiUrlController.text.trim(),
        model: _modelController.text.trim(),
      );
      if (memory == null) {
        _memoryCaptureCooldown = 1;
        return;
      }

      if (!mounted) return;
      setState(() {
        final next = [..._libraryMemory, memory];
        _libraryMemory =
            next.length > 32 ? next.sublist(next.length - 32) : next;
      });
      _storeHelper.saveLibraryMemory(_libraryMemory);
      _memoryCaptureCooldown = 2;
    } catch (_) {
      _memoryCaptureCooldown = 1;
    } finally {
      _isMemoryCaptureRunning = false;
    }
  }

  void _openSettings() {
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
            uiLayout: _uiLayout,
            onLayoutChanged: (layout) {
              setState(() => _uiLayout = layout);
            },
            showQuickOptions: _showQuickOptions,
            onQuickOptionsChanged: (value) {
              setState(() => _showQuickOptions = value);
            },
            onSave: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            onReset: () {
              setState(() {
                _apiKeyController.clear();
                _apiUrlController.text = kDefaultApiUrl;
                _modelController.text = kDefaultModel;
                _uiLayout = 'classic';
                _showQuickOptions = false;
              });
              _saveSettings();
            },
          ),
        );
      },
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
          child: MemoryPanel(memories: _libraryMemory),
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
            messageCount: _messages.length,
            memoryCount: _libraryMemory.length,
            onExport: _exportArchive,
            onImport: _importArchive,
            onClearAll: _confirmClearArchive,
          ),
        );
      },
    );
  }

  Future<void> _exportArchive() async {
    try {
      final message = await _archiveService.exportArchiveText(
        fileName: _archiveFileName(),
        content: LibraryArchive(
          messages: _messages,
          memories: _libraryMemory,
          quickOptionPoolIndex: _quickOptionPoolIndex,
        ).toJsonText(),
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

      final archive = LibraryArchive.tryParse(raw);
      if (archive == null) {
        _showSnack('这份存档读不出来。');
        return;
      }

      final confirmed = await _confirmArchiveAction(
        title: '导入图书馆存档',
        message: '导入会覆盖当前对话、记忆和心声进度，但不会修改 API 设置。',
      );
      if (!confirmed) return;

      setState(() {
        _messages = archive.messages;
        _libraryMemory = archive.memories;
        _quickOptionPoolIndex = archive.quickOptionPoolIndex;
      });
      _persistHistory();
      _storeHelper.saveLibraryMemory(_libraryMemory);
      _storeHelper.saveQuickOptionPoolIndex(_quickOptionPoolIndex);
      _jumpToBottomAfterOpen();
      _showSnack('图书馆存档已经恢复。');
    } catch (_) {
      _showSnack('存档导入失败。');
    }
  }

  Future<void> _confirmClearArchive() async {
    final confirmed = await _confirmArchiveAction(
      title: '清空图书馆',
      message: '这会删除本机保存的对话、记忆和心声进度，但不会修改 API 设置。',
      danger: true,
    );
    if (!confirmed) return;

    setState(() {
      _messages = const [
        ChatMessage(role: 'assistant', content: '书页重新变白了。亲爱的，我们可以从这里重新开始。'),
      ];
      _libraryMemory = const [];
      _quickOptionPoolIndex = 0;
    });
    _storeHelper.deleteHistory();
    _storeHelper.deleteLibraryMemory();
    _storeHelper.deleteQuickOptionPoolIndex();
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
    setState(() {
      _messages = const [
        ChatMessage(
            role: 'assistant', content: '房间重新安静下来了。您可以从任何一个句子重新开始，亲爱的。'),
      ];
      _storeHelper.deleteHistory();
      _storeHelper.saveLastVisit(DateTime.now().toIso8601String());
    });
    _startIdleTimer();
  }

  void _loadSettings() {
    final settings = _storeHelper.loadSettings();
    _apiKeyController.text = settings['apiKey'] ?? '';
    _apiUrlController.text = settings['apiUrl'] ?? kDefaultApiUrl;
    _modelController.text = settings['model'] ?? kDefaultModel;
    _uiLayout = settings['uiLayout'] ?? 'storybook';
    _showQuickOptions = settings['showQuickOptions'] == 'true';
    _quickOptionPoolIndex = _storeHelper.loadQuickOptionPoolIndex();
  }

  void _saveSettings() {
    _storeHelper.saveSettings(
      _apiKeyController.text.trim(),
      _apiUrlController.text.trim(),
      _modelController.text.trim(),
      uiLayout: _uiLayout,
      showQuickOptions: _showQuickOptions,
    );
  }

  void _loadHistory() {
    final history = _storeHelper.loadHistory();
    if (history != null) {
      _messages = history;
    }
  }

  void _loadLibraryMemory() {
    _libraryMemory = _storeHelper.loadLibraryMemory();
  }

  void _loadUserProfile() {
    _userProfile = _storeHelper.loadUserProfile() ?? UserProfile();
    _userProfile.touch();
    _storeHelper.saveUserProfile(_userProfile);
  }

  void _checkReturnGreeting() {
    final lastVisit = _storeHelper.loadLastVisit();
    if (lastVisit == null) {
      _storeHelper.saveLastVisit(DateTime.now().toIso8601String());
      return;
    }
    final last = DateTime.tryParse(lastVisit);
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    String greeting;
    if (elapsed.inDays >= 30) {
      greeting = (List<String>.of(kReturnGreetingMonths)..shuffle(math.Random())).first;
    } else if (elapsed.inDays >= 7) {
      greeting = (List<String>.of(kReturnGreetingWeeks)..shuffle(math.Random())).first;
    } else if (elapsed.inDays >= 1) {
      greeting = (List<String>.of(kReturnGreetingDays)..shuffle(math.Random())).first;
    } else if (elapsed.inHours >= 3) {
      greeting = (List<String>.of(kReturnGreetingHours)..shuffle(math.Random())).first;
    } else {
      return;
    }
    setState(() {
      _messages = [
        ..._messages.where((message) => !message.isAmbient),
        ChatMessage(role: 'assistant', content: greeting, isAmbient: true),
      ];
    });
    _persistHistory();
    _jumpToBottomAfterOpen();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (_isAway) return;
    _idleTimer = Timer(const Duration(minutes: 3), _fireIdleLine);
  }

  void _toggleAway() {
    _isAway = !_isAway;
    if (_isAway) {
      _idleTimer?.cancel();
      final line = (List<String>.of(kLeaveLines)..shuffle(math.Random())).first;
      setState(() {
        _messages = [
          ..._messages.where((message) => !message.isAmbient),
          ChatMessage(role: 'assistant', content: line, isAmbient: true),
        ];
      });
      _persistHistory();
      _scrollToBottom();
    } else {
      _startIdleTimer();
      final line = (List<String>.of(kReturnShortLines)..shuffle(math.Random())).first;
      setState(() {
        _messages = [
          ..._messages.where((message) => !message.isAmbient),
          ChatMessage(role: 'assistant', content: line, isAmbient: true),
        ];
      });
      _persistHistory();
      _scrollToBottom();
    }
  }

  void _fireIdleLine() {
    if (!mounted || _isSending) return;
    final line = (List<String>.of(kIdleLines)..shuffle(math.Random())).first;
    setState(() {
      _messages = [
        ..._messages.where((message) => !message.isAmbient),
        ChatMessage(role: 'assistant', content: line, isAmbient: true),
      ];
    });
    _persistHistory();
    _scrollToBottom();
    _startIdleTimer();
  }

  /// 存档时剔除环境台词（idle / 离馆 / 回归语），不污染真实对话记录。
  void _persistHistory() {
    _storeHelper.saveHistory(
      _messages.where((message) => !message.isAmbient).toList(),
    );
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
        if (!_messageScrollController.hasClients) return;
        _messageScrollController.jumpTo(
          _messageScrollController.position.maxScrollExtent,
        );
      });
    });
  }
}

class _StorybookTitle extends StatelessWidget {
  const _StorybookTitle({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 30 : 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: compact ? 20 : 36, child: const _TitleLine()),
          SizedBox(width: compact ? 8 : 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '时间之外',
                style: TextStyle(
                  fontSize: compact ? 15 : 20,
                  height: 1.1,
                  letterSpacing: compact ? 4 : 6,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: const ['STSong', 'SimSun', 'STKaiti'],
                  color: const Color(0xF0FFFFFF),
                  shadows: const [
                    Shadow(
                      color: Color(0x30FFFFFF),
                      offset: Offset(0, 0),
                      blurRadius: 8,
                    ),
                    Shadow(
                      color: Color(0x80000000),
                      offset: Offset(0.5, 0.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                const Text(
                  'BEYOND TIME',
                  style: TextStyle(
                    fontSize: 9,
                    height: 0.9,
                    letterSpacing: 3.6,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'CormorantGaramond',
                    fontStyle: FontStyle.italic,
                    color: Color(0x88FFFFFF),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(width: compact ? 8 : 12),
          SizedBox(width: compact ? 20 : 36, child: const _TitleLine()),
        ],
      ),
    );
  }
}

class _TitleLine extends StatelessWidget {
  const _TitleLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 10),
      painter: _TitleLinePainter(),
    );
  }
}

class _TitleLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final paint1 = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, mid), Offset(size.width - 4, mid), paint1);
    canvas.drawCircle(Offset(size.width - 2, mid), 1.0, paint1);
    final paint2 = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.4;
    canvas.drawLine(Offset(0, mid - 2.5), Offset(size.width - 1, mid - 2.5), paint2);
    canvas.drawLine(Offset(0, mid + 2.5), Offset(size.width - 1, mid + 2.5), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
