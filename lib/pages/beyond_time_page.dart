import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../data/quick_options.dart';
import '../models/chat_message.dart';
import '../models/library_memory_item.dart';
import '../services/chat_api.dart';
import '../services/local_store.dart';
import '../theme.dart';
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
  final ChatApiClient _chatApi = ChatApiClient();
  final LocalStore _store = LocalStore();

  List<ChatMessage> _messages = const [
    ChatMessage(role: 'assistant', content: '进来吧。这里暂时只有黑暗、我、还有你可以慢慢放下的声音。'),
  ];
  bool _isSending = false;
  bool _musicOn = false;
  String _musicMode = '8bit';
  String _persona = kFallbackPersona;
  String _selectedBookmarkText = '';
  List<LibraryMemoryItem> _libraryMemory = const [];
  int _quickChoiceCount = 0;
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
    _stopMusic();
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
                              musicMode: _musicMode,
                              quickOptions: _currentQuickOptions(),
                              inputController: _inputController,
                              scrollController: _messageScrollController,
                              selectedBookmarkText: _selectedBookmarkText,
                              onSend: _sendCurrentText,
                              onClear: _clearChat,
                              onQuickOption: _handleQuickOption,
                              onAssistantSelection: _handleAssistantSelection,
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
                    child: TopTextButton(
                      label: _musicOn ? '静音' : '音乐',
                      onTap: _toggleMusic,
                    ),
                  ),
                  Positioned(
                    top: isNarrow ? 18 : 18,
                    left: isNarrow ? 66 : 70,
                    child: TopTextButton(
                      label: _musicMode,
                      onTap: _toggleMusicMode,
                    ),
                  ),
                  Positioned(
                    top: isNarrow ? 18 : 18,
                    right: isNarrow ? 16 : 22,
                    child: TopTextButton(label: '设置', onTap: _openSettings),
                  ),
                  Positioned(
                    top: isNarrow ? 18 : 18,
                    right: isNarrow ? 68 : 76,
                    child: TopTextButton(label: '记忆', onTap: _openMemoryPanel),
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
    final conversationTurns = math.max(0, _messages.length - 1);
    return kQuickOptionPools[
        (conversationTurns + _quickChoiceCount) % kQuickOptionPools.length];
  }

  void _toggleMusic() {
    setState(() => _musicOn = !_musicOn);
    if (_musicOn) {
      _startMusic();
    } else {
      _stopMusic();
    }
  }

  void _toggleMusicMode() {
    setState(() => _musicMode = _musicMode == '8bit' ? '16bit' : '8bit');
    if (_musicOn) {
      _startMusic();
    }
  }

  void _startMusic() {
    // Native Windows audio will be wired through a desktop audio plugin later.
    // Keep the UI state intact for now so the rest of the app stays usable.
  }

  void _stopMusic() {}

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
    setState(() {
      _quickChoiceCount += 1;
      _saveQuickChoiceCount();
      _inputController.text = text;
    });
    await _sendCurrentText();
  }

  void _handleAssistantSelection(String text) {
    final selected = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (selected == _selectedBookmarkText) return;
    setState(() => _selectedBookmarkText = selected);
  }

  Future<void> _bookmarkSelectedText() async {
    if (_isSending) return;
    final quote = _selectedBookmarkText.trim();
    if (quote.isEmpty) return;

    setState(() {
      if (!_libraryMemory.any((memory) => memory.content == quote)) {
        _libraryMemory = [
          ..._libraryMemory,
          LibraryMemoryItem(
            category: '书签',
            content: quote,
            evidence: '来访者手动收藏的句子',
            source: '手动书签',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ];
        _saveLibraryMemory();
      }
      _selectedBookmarkText = '';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('书签已夹进图书馆。'),
        duration: Duration(milliseconds: 1400),
        backgroundColor: Colors.black,
      ),
    );
  }

  Future<void> _sendCurrentText() async {
    if (_isSending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _selectedBookmarkText = '';
      _messages = [..._messages, ChatMessage(role: 'user', content: text)];
      _inputController.clear();
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
      final reply = await _requestStreamingReply();
      _replaceLastAssistant(_cleanReply(reply));
      setState(() => _isSending = false);
      _saveHistory();
      _scrollToBottom();
      unawaited(_maybeCaptureMemory(userText: text, assistantReply: reply));
    } catch (error) {
      _replaceLastAssistant('连接没有成功：$error');
      setState(() => _isSending = false);
    }
  }

  Future<String> _requestStreamingReply({String? extraUserInstruction}) async {
    final payload = {
      'model': _modelController.text.trim().isEmpty
          ? kDefaultModel
          : _modelController.text.trim(),
      'messages': _buildMessages(extraUserInstruction: extraUserInstruction),
      'temperature': 1.35,
      'max_tokens': 520,
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
          _replaceLastAssistant(_cleanReply(reply));
          _scrollToBottom();
        },
      );
    } on ChatApiException catch (error) {
      throw _friendlyHttpError(error.statusCode, error.responseText);
    }
  }

  String _friendlyHttpError(int status, String responseText) {
    final details = _extractApiErrorMessage(responseText);
    return switch (status) {
      400 => '请求格式不对。请检查模型名称、API 地址和参数设置。$details',
      401 => 'API Key 没通过验证。请检查右上角设置里的密钥。$details',
      402 => '账号余额或额度不足。请检查 DeepSeek 控制台的余额、充值状态或当前模型是否可用。',
      403 => '接口拒绝访问。请检查 API Key 权限、模型权限或账号状态。$details',
      404 => 'API 地址或模型不存在。请检查右上角设置里的 API 地址和模型名。$details',
      429 => '请求太频繁或额度达到上限。稍等一会儿，或检查账号限额。$details',
      >= 500 => '模型服务端暂时出错。稍后再试，或者换一个模型。$details',
      _ => 'HTTP $status。请检查 API 设置或上游服务状态。$details',
    };
  }

  String _extractApiErrorMessage(String responseText) {
    final cleaned = responseText
        .split('\n')
        .where((line) => !line.trimLeft().startsWith(':'))
        .join('\n')
        .trim();
    if (cleaned.isEmpty) return '';
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return '（$message）';
        }
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return '（$message）';
      }
    } catch (_) {
      final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ');
      if (compact.length <= 120) return '（$compact）';
    }
    return '';
  }

  void _replaceLastAssistant(String content) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      final next = [..._messages];
      next[next.length - 1] = ChatMessage(role: 'assistant', content: content);
      _messages = next;
    });
  }

  List<Map<String, String>> _buildMessages({String? extraUserInstruction}) {
    final history = _messages
        .where((message) => message.content.trim().isNotEmpty)
        .where((message) => !_isBookmarkNoticeMessage(message))
        .take(80)
        .map((message) => {
              'role': message.role == 'assistant' ? 'assistant' : 'user',
              'content': message.content,
            })
        .toList();
    final memories = _libraryMemory
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .toList();

    return [
      {'role': 'system', 'content': _persona},
      if (memories.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是图书馆记忆，包含来访者手动收藏的句子，以及艾蕾塔谨慎整理出的喜好、压力、热爱与困扰。把它们当作轻柔背景，只在自然合适时呼应，不要像系统总结一样复述：\n${memories.map((memory) => '- [${memory.category}] ${memory.content}${memory.evidence.trim().isEmpty ? '' : '（依据：${memory.evidence}）'}').join('\n')}',
        },
      {
        'role': 'system',
        'content':
            '保持对话感和艾蕾塔的角色气质。优先自然回应来访者当前这句话，不要输出 HTML 标签或 Markdown 换行标签；需要换行时直接使用普通换行，绝对不要写 <br>。',
      },
      ...history,
      if (extraUserInstruction != null &&
          extraUserInstruction.trim().isNotEmpty)
        {'role': 'user', 'content': extraUserInstruction.trim()},
    ];
  }

  Future<void> _maybeCaptureMemory({
    required String userText,
    required String assistantReply,
  }) async {
    final compactUserText = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compactUserText.length < 12) return;
    if (_apiKeyController.text.trim().isEmpty) return;
    if (_isMemoryCaptureRunning) return;
    if (_memoryCaptureCooldown > 0) {
      _memoryCaptureCooldown -= 1;
      return;
    }

    _isMemoryCaptureRunning = true;
    try {
      final raw = await _chatApi.requestStreamingReply(
        payload: {
          'model': _modelController.text.trim().isEmpty
              ? kDefaultModel
              : _modelController.text.trim(),
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
${_memoryDigestForAnalyzer()}

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
        apiKey: _apiKeyController.text.trim(),
        apiUrl: _apiUrlController.text.trim().isEmpty
            ? kDefaultApiUrl
            : _apiUrlController.text.trim(),
        onReply: (_) {},
      );

      final memory = _parseMemoryCandidate(raw);
      if (memory == null || _hasSimilarMemory(memory.content)) {
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

  String _memoryDigestForAnalyzer() {
    final memories = _libraryMemory
        .where((memory) => memory.source != '手动书签')
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed;
    if (memories.isEmpty) return '无';
    return memories
        .map((memory) => '- [${memory.category}] ${memory.content}')
        .join('\n');
  }

  LibraryMemoryItem? _parseMemoryCandidate(String raw) {
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

  String? _extractJsonObject(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }

  bool _hasSimilarMemory(String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), '');
    return _libraryMemory.any((memory) {
      final existing = memory.content.replaceAll(RegExp(r'\s+'), '');
      return existing == compact ||
          existing.contains(compact) ||
          compact.contains(existing);
    });
  }

  bool _isBookmarkNoticeMessage(ChatMessage message) {
    if (message.role != 'assistant') return false;
    final content = message.content.trim();
    return content.contains('书签') &&
        (content.contains('图书馆') ||
            content.contains('收进') ||
            content.contains('夹进') ||
            content.contains('收好'));
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

  void _clearChat() {
    setState(() {
      _selectedBookmarkText = '';
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
      _quickChoiceCount = int.tryParse(_readStore(kQuickCountKey) ?? '0') ?? 0;
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _apiKeyController.text = data['apiKey']?.toString() ?? '';
    _apiUrlController.text = data['apiUrl']?.toString() ?? kDefaultApiUrl;
    _modelController.text = data['model']?.toString() ?? kDefaultModel;
    _quickChoiceCount = int.tryParse(_readStore(kQuickCountKey) ?? '0') ?? 0;
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

  void _saveQuickChoiceCount() {
    _writeStore(kQuickCountKey, _quickChoiceCount.toString());
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

  String _cleanReply(String text) {
    return text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
