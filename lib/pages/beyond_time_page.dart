import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../data/quick_options.dart';
import '../models/chat_message.dart';
import '../models/library_archive.dart';
import '../models/library_memory_item.dart';
import '../services/archive_service.dart';
import '../services/bookmark_service.dart';
import '../services/chat_api.dart';
import '../services/conversation_context.dart';
import '../services/local_store.dart';
import '../services/memory_capture_service.dart';
import '../services/tarot_reading_service.dart';
import '../theme.dart';
import '../widgets/archive_panel.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/memory_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/stage_decor.dart';

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
  final LocalStore _store = LocalStore();
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

  @override
  void initState() {
    super.initState();
    _loadPersona();
    _loadSettings();
    _loadHistory();
    _loadLibraryMemory();
    _jumpToBottomAfterOpen();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: Center(
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
                                Positioned.fill(child: SkyLines()),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: WitchPortrait(),
                                ),
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
                        TopTextButton(label: '记忆', onTap: _openMemoryPanel),
                        if (_canStartTarotReading) const SizedBox(width: 18),
                        if (_canStartTarotReading) ...[
                          TopTextButton(label: '占卜', onTap: _startTarotReading),
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
                        TopTextButton(label: '存档', onTap: _openArchivePanel),
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
    _advanceQuickOptions();
    await _sendText(text, clearInput: true);
  }

  void _refreshQuickOptions() {
    _advanceQuickOptions();
  }

  void _advanceQuickOptions() {
    setState(() {
      _quickOptionPoolIndex += 1;
      _saveQuickOptionPoolIndex();
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
        _saveLibraryMemory();
      }
      _messages = [
        ..._messages,
        ChatMessage(role: 'assistant', content: result.notice),
      ];
    });
    _saveHistory();
    _scrollToBottom();
  }

  Future<void> _sendCurrentText() async {
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
    text = text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages = [..._messages, ChatMessage(role: 'user', content: text)];
      if (clearInput) {
        _inputController.clear();
      }
      _isSending = true;
    });
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
      _saveHistory();
      _scrollToBottom();
      if (captureMemory) {
        unawaited(_maybeCaptureMemory(userText: text, assistantReply: reply));
      }
    } catch (error) {
      _replaceLastAssistant('连接没有成功：$error');
      setState(() => _isSending = false);
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
      throw _conversationContext.friendlyHttpError(
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
      _saveLibraryMemory();
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
            onSave: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            onReset: () {
              setState(() {
                _apiKeyController.clear();
                _apiUrlController.text = kDefaultApiUrl;
                _modelController.text = kDefaultModel;
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
      _saveHistory();
      _saveLibraryMemory();
      _saveQuickOptionPoolIndex();
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
    _deleteStoreFile(kHistoryKey);
    _deleteStoreFile(kLibraryMemoryKey);
    _deleteStoreFile(kQuickCountKey);
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
      _deleteStoreFile(kHistoryKey);
    });
  }

  void _loadSettings() {
    final raw = _readStore(kSettingsKey);
    if (raw == null) {
      _apiUrlController.text = kDefaultApiUrl;
      _modelController.text = kDefaultModel;
      _quickOptionPoolIndex =
          int.tryParse(_readStore(kQuickCountKey) ?? '0') ?? 0;
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _apiKeyController.text = data['apiKey']?.toString() ?? '';
    _apiUrlController.text = data['apiUrl']?.toString() ?? kDefaultApiUrl;
    _modelController.text = data['model']?.toString() ?? kDefaultModel;
    _quickOptionPoolIndex =
        int.tryParse(_readStore(kQuickCountKey) ?? '0') ?? 0;
  }

  void _saveSettings() {
    _writeStore(
        kSettingsKey,
        jsonEncode({
          'apiKey': _apiKeyController.text.trim(),
          'apiUrl': _apiUrlController.text.trim(),
          'model': _modelController.text.trim(),
        }));
  }

  void _loadHistory() {
    final raw = _readStore(kHistoryKey);
    if (raw == null) return;
    final data = jsonDecode(raw) as List<dynamic>;
    final history = data
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (history.isNotEmpty) {
      _messages = history;
    }
  }

  void _loadLibraryMemory() {
    final raw = _readStore(kLibraryMemoryKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _libraryMemory = data
          .map((item) {
            if (item is Map<String, dynamic>) {
              return LibraryMemoryItem.fromJson(item);
            }
            return LibraryMemoryItem.fromLegacyString(item.toString());
          })
          .where((item) => item.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      _libraryMemory = const [];
    }
  }

  void _saveHistory() {
    _writeStore(
      kHistoryKey,
      jsonEncode(_messages.map((message) => message.toJson()).toList()),
    );
  }

  void _saveLibraryMemory() {
    _writeStore(
      kLibraryMemoryKey,
      jsonEncode(_libraryMemory.map((memory) => memory.toJson()).toList()),
    );
  }

  void _saveQuickOptionPoolIndex() {
    _writeStore(kQuickCountKey, _quickOptionPoolIndex.toString());
  }

  String? _readStore(String key) => _store.read(key);

  void _writeStore(String key, String value) => _store.write(key, value);

  void _deleteStoreFile(String key) => _store.delete(key);
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
