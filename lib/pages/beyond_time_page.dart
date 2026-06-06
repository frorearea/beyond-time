import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../data/quick_options.dart';
import '../models/chat_message.dart';
import '../theme.dart';
import '../widgets/dialogue_box.dart';
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

  List<ChatMessage> _messages = const [
    ChatMessage(role: 'assistant', content: '进来吧。这里暂时只有黑暗、我、还有你可以慢慢放下的声音。'),
  ];
  bool _isSending = false;
  bool _musicOn = false;
  String _musicMode = '8bit';
  String _persona = kFallbackPersona;
  String _selectedBookmarkText = '';
  List<String> _libraryMemory = const [];
  int _quickChoiceCount = 0;

  @override
  void initState() {
    super.initState();
    _clearConversationStateFromUrl();
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
      if (!_libraryMemory.contains(quote)) {
        _libraryMemory = [..._libraryMemory, quote];
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
    final client = HttpClient();
    var eventBuffer = '';
    var reply = '';
    try {
      final request = await client.postUrl(Uri.parse(apiUrl));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.write(jsonEncode(payload));
      final response = await request.close();

      if (response.statusCode != 200) {
        final text = await response.transform(utf8.decoder).join();
        throw _friendlyHttpError(response.statusCode, text);
      }

      await for (final chunk in response.transform(utf8.decoder)) {
        eventBuffer += chunk;
        final events = eventBuffer.split('\n\n');
        eventBuffer = events.removeLast();
        for (final event in events) {
          final delta = _sseDelta(event);
          if (delta.isEmpty) continue;
          reply += delta;
          _replaceLastAssistant(reply);
          _scrollToBottom();
        }
      }

      if (eventBuffer.trim().isNotEmpty) {
        final delta = _sseDelta(eventBuffer);
        if (delta.isNotEmpty) {
          reply += delta;
          _replaceLastAssistant(reply);
        }
      }

      return reply.isEmpty ? '模型没有返回内容。' : reply;
    } finally {
      client.close(force: true);
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

  String _sseDelta(String event) {
    final lines = event.split('\n');
    final dataLines = lines
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((line) => line.isNotEmpty && line != '[DONE]');
    final buffer = StringBuffer();
    for (final line in dataLines) {
      try {
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map<String, dynamic>) continue;
        final delta = choice['delta'];
        if (delta is! Map<String, dynamic>) continue;
        final content = delta['content'];
        if (content is String) buffer.write(content);
      } catch (_) {
        continue;
      }
    }
    return buffer.toString();
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
        .where((memory) => memory.trim().isNotEmpty)
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
              '以下是来访者主动收藏进图书馆记忆的句子。把它们当作轻柔背景，只在自然合适时呼应，不要像系统总结一样复述：\n${memories.map((memory) => '- $memory').join('\n')}',
        },
      {
        'role': 'system',
        'content': '保持短句、对话感和爱蕾塔的角色气质。优先回应来访者当前这句话，不要被旧上下文牵走。',
      },
      ...history,
      if (extraUserInstruction != null &&
          extraUserInstruction.trim().isNotEmpty)
        {'role': 'user', 'content': extraUserInstruction.trim()},
    ];
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

  void _clearConversationStateFromUrl() {}

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
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
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
    _writeStore(kLibraryMemoryKey, jsonEncode(_libraryMemory));
  }

  void _saveQuickChoiceCount() {
    _writeStore(kQuickCountKey, _quickChoiceCount.toString());
  }

  File _storeFile(String key) {
    final basePath = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;
    final directory = Directory('$basePath\\BeyondTime');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${directory.path}\\$safeKey.json');
  }

  String? _readStore(String key) {
    try {
      final file = _storeFile(key);
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  void _writeStore(String key, String value) {
    try {
      _storeFile(key).writeAsStringSync(value);
    } catch (_) {
      // Local persistence is helpful, but the app should remain usable without it.
    }
  }

  void _deleteStoreFile(String key) {
    try {
      final file = _storeFile(key);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Ignore local cleanup failures.
    }
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

  String _cleanReply(String text) {
    return text
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .trim();
  }
}
