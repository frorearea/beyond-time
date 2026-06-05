import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const BeyondTimeApp());
}

const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kStageMaxWidth = 1040;
const double kStageMaxHeight = 1000;

const String kDefaultApiUrl = 'https://api.deepseek.com/chat/completions';
const String kDefaultModel = 'deepseek-v4-flash';
const String kSettingsKey = 'beyondTimeFlutterSettings';
const String kHistoryKey = 'beyondTimeFlutterHistory';
const String kQuickCountKey = 'beyondTimeFlutterQuickChoiceCount';
const String kLibraryMemoryKey = 'beyondTimeFlutterLibraryMemory';

const String kPersonaAsset = 'assets/prompts/ereta_persona.txt';
const String kFallbackPersona = '?????? ? ??????';

const List<List<String>> kQuickOptionPools = [
  ['我在人生的路上迷了路。', '我想做自己的游戏，但我害怕它没有意义。', '我好像把学历当成了存在许可证。'],
  ['我需要的也许不是答案，而是被看见。', '我像一份没人打开的存档。', '我想从现实撤离，但我还想回来。'],
  ['你喜欢什么游戏？', '你喜欢什么动画？', '你喜欢什么书？'],
  ['效率是不是偷走了我的人生？', '我该怎么找回真正的自己？', '规训到底是怎么住进我心里的？'],
  ['我喜欢你的头发。', '我喜欢你的温柔。', '我喜欢你的文字。'],
  ['给我讲一个很短的故事。', '给我讲一个不说教的寓言。', '给我写一首只属于今晚的诗。'],
  ['意义这种东西，是人自己点燃的吗？', '你能确认我的存在吗？', '我该怎样把自我从评价里赎回来？'],
  ['游戏为什么能承载人的灵魂？', '故事能不能替我保存热爱？', '热爱变冷的时候，该怎么办？'],
  ['从未被爱的人要如何学会爱？', '希望会不会只是漂亮的谎言？', '未来如果没有保证，我还要走吗？'],
  ['我是不是把人生过成了一场考试？', '我是不是太习惯向世界交作业了？', '如果没人评分，我还知道怎么活吗？'],
  ['我想做点没用但美的东西。', '我想认真保护一个幼稚的愿望。', '我想把热爱从羞耻里救出来。'],
  ['如果今晚不谈人生，我们谈什么？', '如果今晚只浪费时间，你会陪我吗？', '如果今晚只听音乐，也可以吗？'],
  ['我是不是有点太依赖你了？', '你会讨厌我总来找你吗？', '如果我今晚不想走呢？'],
  ['我喜欢你。我有资格这样说吗？', '鼓励我一下，别太正经。', '骂醒我，求你了。'],
  ['你刚才那句话，是只对我说的吗？', '你是不是故意让我心动？', '你明明很温柔，为什么还要装坏？'],
  ['为什么人一定要攀比？', '为什么我总生活在他人的目光中？', '我不想将他人踩在脚下，难道这也算软弱吗？'],
];

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() == 'assistant' ? 'assistant' : 'user',
      content: json['content']?.toString() ?? '',
    );
  }
}

class BeyondTimeApp extends StatelessWidget {
  const BeyondTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '时间之外',
      home: BeyondTimePage(),
    );
  }
}

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
  html.AudioElement? _audio;

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
    _loadPersona();
    _loadSettings();
    _loadHistory();
    _loadLibraryMemory();
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
                            height:
                                isNarrow ? 360 : constraints.maxHeight * 0.40,
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
    _stopMusic();
    final audio = html.AudioElement(_musicDataUri(_musicMode))
      ..loop = true
      ..volume = _musicMode == '16bit' ? 0.62 : 0.55;
    _audio = audio;
    audio.play().catchError((_) {
      if (mounted) {
        setState(() => _musicOn = false);
      }
    });
  }

  void _stopMusic() {
    _audio?.pause();
    _audio = null;
  }

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

  String _musicDataUri(String mode) {
    return 'data:audio/wav;base64,${base64Encode(_buildMusicWav(mode))}';
  }

  Uint8List _buildMusicWav(String mode) {
    const sampleRate = 22050;
    const seconds = 14;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = sampleRate * seconds;
    final dataSize = sampleCount * channels * bitsPerSample ~/ 8;
    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.sublistView(bytes);

    void writeAscii(int offset, String text) {
      for (var i = 0; i < text.length; i += 1) {
        bytes[offset + i] = text.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(
        28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    data.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    final beatLength = mode == '16bit' ? 0.72 : 0.54;
    final melody = mode == '16bit'
        ? const [293.66, 349.23, 440.00, 392.00, 329.63, 392.00, 523.25, 440.00]
        : const [
            220.00,
            277.18,
            329.63,
            277.18,
            246.94,
            329.63,
            369.99,
            329.63
          ];
    final harmony = mode == '16bit'
        ? const [146.83, 174.61, 220.00, 196.00]
        : const [110.00, 138.59, 164.81, 138.59];

    for (var i = 0; i < sampleCount; i += 1) {
      final t = i / sampleRate;
      final beat = (t / beatLength).floor();
      final beatPhase = (t % beatLength) / beatLength;
      final note = melody[beat % melody.length];
      final bass = harmony[(beat ~/ 2) % harmony.length];
      final attack = math.min(beatPhase / 0.12, 1.0);
      final release = math.min((1.0 - beatPhase) / 0.32, 1.0);
      final envelope = math.max(0.0, math.min(attack, release));
      final wave = mode == '16bit'
          ? math.sin(2 * math.pi * note * t) * 0.24 +
              math.sin(2 * math.pi * bass * t) * 0.10 +
              math.sin(2 * math.pi * note * 2 * t) * 0.035
          : (math.sin(2 * math.pi * note * t) >= 0 ? 0.22 : -0.22) +
              (math.sin(2 * math.pi * bass * t) >= 0 ? 0.07 : -0.07);
      final sample =
          (wave * envelope * 32767).round().clamp(-32768, 32767).toInt();
      data.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes;
  }

  Future<void> _handleQuickOption(String text) async {
    setState(() {
      _quickChoiceCount += 1;
      html.window.localStorage[kQuickCountKey] = _quickChoiceCount.toString();
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
      _isSending = true;
      _messages = [
        ..._messages,
        const ChatMessage(role: 'assistant', content: ''),
      ];
    });
    _scrollToBottom();

    if (_apiKeyController.text.trim().isEmpty) {
      _replaceLastAssistant('这枚书签已经夹进图书馆了。至于我的正式回应，亲爱的，先把右上角那把钥匙补上。');
      setState(() => _isSending = false);
      _saveHistory();
      _openSettings();
      return;
    }

    try {
      final reply = await _requestStreamingReply(
        extraUserInstruction:
            '来访者刚刚把你说过的这句话加入了图书馆记忆：“$quote”。请用爱蕾塔的语气简短回应，承认这枚书签已被收进图书馆，并轻轻点出它对来访者可能意味着什么。不要超过100字。',
      );
      _replaceLastAssistant(_cleanReply(reply));
      setState(() => _isSending = false);
      _saveHistory();
      _scrollToBottom();
    } catch (error) {
      _replaceLastAssistant('这枚书签已经收好了。只是图书馆刚才有一页纸没翻过去：$error');
      setState(() => _isSending = false);
    }
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

  Future<String> _requestStreamingReply({String? extraUserInstruction}) {
    final payload = {
      'apiKey': _apiKeyController.text.trim(),
      'apiUrl': _apiUrlController.text.trim().isEmpty
          ? kDefaultApiUrl
          : _apiUrlController.text.trim(),
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

    final completer = Completer<String>();
    final request = html.HttpRequest();
    var processedLength = 0;
    var eventBuffer = '';
    var reply = '';

    void handleResponseText() {
      final responseText = request.responseText ?? '';
      if (responseText.length <= processedLength) return;
      eventBuffer += responseText.substring(processedLength);
      processedLength = responseText.length;

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

    request
      ..open('POST', '/api/chat')
      ..setRequestHeader('Content-Type', 'application/json');
    request.onProgress.listen((_) => handleResponseText());
    request.onLoadEnd.listen((_) {
      handleResponseText();
      if (eventBuffer.trim().isNotEmpty) {
        final delta = _sseDelta(eventBuffer);
        if (delta.isNotEmpty) {
          reply += delta;
          _replaceLastAssistant(reply);
        }
        eventBuffer = '';
      }
      if (request.status != 200) {
        if (!completer.isCompleted) {
          completer.completeError(
            _friendlyHttpError(request.status ?? 0, request.responseText ?? ''),
          );
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(reply.isEmpty ? '模型没有返回内容。' : reply);
      }
    });
    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError('请求失败');
      }
    });
    request.send(jsonEncode(payload));
    return completer.future;
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
              '???????????????????????????????????????????????????????????????????\n${memories.map((memory) => '- $memory').join('\n')}',
        },
      {
        'role': 'system',
        'content': '?????????????????????????????????????????????????',
      },
      ...history,
      if (extraUserInstruction != null &&
          extraUserInstruction.trim().isNotEmpty)
        {'role': 'user', 'content': extraUserInstruction.trim()},
    ];
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
      html.window.localStorage.remove(kHistoryKey);
    });
  }

  void _loadSettings() {
    final raw = html.window.localStorage[kSettingsKey];
    if (raw == null) {
      _apiUrlController.text = kDefaultApiUrl;
      _modelController.text = kDefaultModel;
      _quickChoiceCount =
          int.tryParse(html.window.localStorage[kQuickCountKey] ?? '0') ?? 0;
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _apiKeyController.text = data['apiKey']?.toString() ?? '';
    _apiUrlController.text = data['apiUrl']?.toString() ?? kDefaultApiUrl;
    _modelController.text = data['model']?.toString() ?? kDefaultModel;
    _quickChoiceCount =
        int.tryParse(html.window.localStorage[kQuickCountKey] ?? '0') ?? 0;
  }

  void _saveSettings() {
    html.window.localStorage[kSettingsKey] = jsonEncode({
      'apiKey': _apiKeyController.text.trim(),
      'apiUrl': _apiUrlController.text.trim(),
      'model': _modelController.text.trim(),
    });
  }

  void _loadHistory() {
    final raw = html.window.localStorage[kHistoryKey];
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
    final raw = html.window.localStorage[kLibraryMemoryKey];
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
    html.window.localStorage[kHistoryKey] =
        jsonEncode(_messages.map((message) => message.toJson()).toList());
  }

  void _saveLibraryMemory() {
    html.window.localStorage[kLibraryMemoryKey] = jsonEncode(_libraryMemory);
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

  String _cleanReply(String text) {
    return text
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .trim();
  }
}

class TopTextButton extends StatelessWidget {
  const TopTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(color: kWhite, fontSize: 14, height: 1),
      ),
    );
  }
}

class SkyLines extends StatelessWidget {
  const SkyLines({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(left: 34, top: 44, child: MoonMark()),
        Positioned(right: 42, top: 58, child: StarMark(size: 34)),
        Positioned(
            left: 120, top: 145, child: StarMark(size: 22, rotate: true)),
        Positioned(right: 118, top: 205, child: StarMark(size: 28)),
        Positioned(left: 290, top: 42, child: StarMark(size: 18, rotate: true)),
        Positioned(left: 210, top: 102, child: StarMark(size: 16)),
        Positioned(
            right: 242, top: 128, child: StarMark(size: 14, rotate: true)),
        Positioned(
            left: 64, bottom: 40, child: StarMark(size: 18, rotate: true)),
        Positioned(right: 66, bottom: 24, child: StarMark(size: 16)),
      ],
    );
  }
}

class MoonMark extends StatelessWidget {
  const MoonMark({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(92, 76), painter: MoonPainter());
  }
}

class MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(38, 38), 37, paint);
    final cover = Paint()..color = kBlack;
    canvas.drawCircle(const Offset(61, 38), 37, cover);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarMark extends StatelessWidget {
  const StarMark({super.key, required this.size, this.rotate = false});

  final double size;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    final child = CustomPaint(size: Size.square(size), painter: StarPainter());
    return rotate ? Transform.rotate(angle: 0.785, child: child) : child;
  }
}

class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kWhite
      ..strokeWidth = 2;
    final center = size.width / 2;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), paint);
    canvas.drawLine(Offset(0, center), Offset(size.width, center), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WitchPortrait extends StatelessWidget {
  const WitchPortrait({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'reference-princess.jpg',
      fit: BoxFit.contain,
      width: 760,
    );
  }
}

class SloganQuote extends StatelessWidget {
  const SloganQuote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 34,
                    height: 1,
                    fontFamily: 'Georgia',
                  ),
                ),
                Expanded(
                  child: Text(
                    'I offer you the bitterness of a man who has looked long and long at the lonely moon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xE8FFFFFF),
                      fontSize: 20,
                      height: 1.18,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'CormorantGaramond',
                      fontFamilyFallback: [
                        'Palatino Linotype',
                        'Georgia',
                        'Times New Roman',
                      ],
                    ),
                  ),
                ),
                Text(
                  '”',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 34,
                    height: 1,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '我给你一个久久地望着孤月的人的悲哀。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 14,
                height: 1.42,
                fontFamily: 'LXGWWenKai',
                fontFamilyFallback: [
                  'Microsoft YaHei',
                  'SimSun',
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'What Can I Hold You with?',
              style: TextStyle(
                color: Color(0x7AFFFFFF),
                fontSize: 11,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DialogueBox extends StatelessWidget {
  const DialogueBox({
    super.key,
    required this.messages,
    required this.isSending,
    required this.musicMode,
    required this.quickOptions,
    required this.inputController,
    required this.scrollController,
    required this.selectedBookmarkText,
    required this.onSend,
    required this.onClear,
    required this.onQuickOption,
    required this.onAssistantSelection,
    required this.onBookmarkSelected,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String musicMode;
  final List<String> quickOptions;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final String selectedBookmarkText;
  final Future<void> Function() onSend;
  final VoidCallback onClear;
  final ValueChanged<String> onQuickOption;
  final ValueChanged<String> onAssistantSelection;
  final VoidCallback onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 920,
          decoration:
              BoxDecoration(border: Border.all(color: kWhite), color: kBlack),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    selectedBookmarkText.isNotEmpty && !isSending ? 52 : 18,
                    22,
                    8,
                  ),
                  itemBuilder: (context, index) => MessageView(
                    message: messages[index],
                    onAssistantSelection: onAssistantSelection,
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemCount: messages.length,
                ),
              ),
              QuickOptions(
                  options: quickOptions,
                  disabled: isSending,
                  onTap: onQuickOption),
              Composer(
                  inputController: inputController,
                  disabled: isSending,
                  onSend: onSend,
                  onClear: onClear),
            ],
          ),
        ),
        const Positioned(left: 18, top: -52, child: CoffeeCup()),
        if (selectedBookmarkText.isNotEmpty && !isSending)
          Positioned(
            right: 12,
            top: 10,
            child: BookmarkAction(onTap: onBookmarkSelected),
          ),
        if (isSending)
          const Positioned(right: 18, top: -42, child: WritingIndicator()),
      ],
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.message,
    required this.onAssistantSelection,
  });

  final ChatMessage message;
  final ValueChanged<String> onAssistantSelection;

  @override
  Widget build(BuildContext context) {
    final isPlayer = message.role == 'user';
    final style = TextStyle(
      color: kWhite,
      fontSize: isPlayer ? 18 : 19,
      height: isPlayer ? 1.5 : 1.48,
      fontFamily: isPlayer ? 'Microsoft YaHei' : 'LXGWWenKai',
      fontFamilyFallback: isPlayer
          ? const ['PingFang SC', 'Noto Sans CJK SC', 'SimHei']
          : const [
              'Microsoft YaHei',
              'SimSun',
            ],
    );
    if (isPlayer) {
      return Text('> ${message.content}', style: style);
    }
    return SelectableText(
      message.content,
      style: style,
      cursorColor: kWhite,
      selectionControls: materialTextSelectionControls,
      onSelectionChanged: (selection, cause) {
        if (selection.isCollapsed) {
          onAssistantSelection('');
          return;
        }
        final selected = selection.textInside(message.content).trim();
        onAssistantSelection(selected);
      },
    );
  }
}

class BookmarkAction extends StatelessWidget {
  const BookmarkAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: kBlack,
          border: Border.all(color: kWhite),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RpgBookmarkIcon(),
            SizedBox(width: 7),
            Text(
              '添加书签',
              style: TextStyle(color: kWhite, fontSize: 13, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class RpgBookmarkIcon extends StatelessWidget {
  const RpgBookmarkIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 20),
      painter: RpgBookmarkPainter(),
    );
  }
}

class RpgBookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whiteFill = Paint()
      ..color = kWhite
      ..style = PaintingStyle.fill;
    final whiteLine = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final blackFill = Paint()
      ..color = kBlack
      ..style = PaintingStyle.fill;
    final blackLine = Paint()
      ..color = kBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(4, 1)
      ..lineTo(size.width - 4, 1)
      ..lineTo(size.width - 4, size.height - 2)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(4, size.height - 2)
      ..close();
    canvas.drawPath(path, whiteFill);
    canvas.drawPath(path, whiteLine);
    canvas.drawLine(const Offset(6, 5), Offset(size.width - 6, 5), blackLine);
    canvas.drawLine(const Offset(6, 8), Offset(size.width - 7, 8), blackLine);

    final notch = Path()
      ..moveTo(size.width / 2 - 2, size.height - 5)
      ..lineTo(size.width / 2, size.height - 7)
      ..lineTo(size.width / 2 + 2, size.height - 5)
      ..close();
    canvas.drawPath(notch, blackFill);

    canvas.drawLine(
        Offset(size.width - 2, 2), Offset(size.width - 2, 7), whiteLine);
    canvas.drawLine(Offset(size.width - 4.5, 4.5),
        Offset(size.width + 0.5, 4.5), whiteLine);
    canvas.drawRect(Rect.fromLTWH(1, 3, 2, 2), whiteFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QuickOptions extends StatelessWidget {
  const QuickOptions(
      {super.key,
      required this.options,
      required this.disabled,
      required this.onTap});

  final List<String> options;
  final bool disabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: kWhite))),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 650 ? 1 : 3;
          return GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 1 ? 8 : 5.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final option in options)
                OutlinedButton(
                  onPressed: disabled ? null : () => onTap(option),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kWhite,
                    side: const BorderSide(color: kWhite),
                    shape: const RoundedRectangleBorder(),
                    alignment: Alignment.centerLeft,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  child: Text(option,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 14, height: 1.35)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.inputController,
    required this.disabled,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController inputController;
  final bool disabled;
  final Future<void> Function() onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Container(
        decoration:
            const BoxDecoration(border: Border(top: BorderSide(color: kWhite))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: TextField(
                  controller: inputController,
                  enabled: !disabled,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  style:
                      const TextStyle(color: kWhite, fontSize: 17, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: '说点什么...',
                    hintStyle: TextStyle(color: Color(0x85FFFFFF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            BorderTextButton(
                label: disabled ? '等待' : '发送', onTap: disabled ? null : onSend),
            BorderTextButton(label: '清空', onTap: onClear),
          ],
        ),
      ),
    );
  }
}

class BorderTextButton extends StatelessWidget {
  const BorderTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: kWhite))),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(label,
            style: TextStyle(
                color: onTap == null ? const Color(0x73FFFFFF) : kWhite,
                fontSize: 16)),
      ),
    );
  }
}

class CoffeeCup extends StatelessWidget {
  const CoffeeCup({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(64, 46), painter: CoffeeCupPainter());
  }
}

class CoffeeCupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(10, 16, 34, 22), line);
    canvas.drawArc(const Rect.fromLTWH(42, 21, 14, 12), -1.5, 3.0, false, line);
    canvas.drawLine(const Offset(4, 43), const Offset(56, 43), line);
    canvas.drawArc(const Rect.fromLTWH(16, 0, 8, 16), 2, 2.4, false, line);
    canvas.drawArc(const Rect.fromLTWH(27, 0, 8, 16), 2, 2.4, false, line);
    canvas.drawArc(const Rect.fromLTWH(38, 0, 8, 16), 2, 2.4, false, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WritingIndicator extends StatelessWidget {
  const WritingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: const Size(76, 30), painter: WritingIndicatorPainter());
  }
}

class WritingIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = kWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(0, 8, 17, 20), line);
    canvas.drawRect(const Rect.fromLTWH(18, 8, 17, 20), line);
    canvas.drawLine(const Offset(0, 29), const Offset(36, 29), line);
    canvas.drawLine(const Offset(48, 20), const Offset(72, 11), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.apiKeyController,
    required this.apiUrlController,
    required this.modelController,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController apiKeyController;
  final TextEditingController apiUrlController;
  final TextEditingController modelController;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _warned = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlack,
      child: Container(
        width: 440,
        height: double.infinity,
        decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: kWhite))),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('设置', style: TextStyle(color: kWhite, fontSize: 18)),
                OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭')),
              ],
            ),
            const SizedBox(height: 24),
            SettingsField(
                label: 'API Key',
                controller: widget.apiKeyController,
                obscure: true),
            SettingsField(label: 'API 地址', controller: widget.apiUrlController),
            SettingsField(label: '模型', controller: widget.modelController),
            const Text('人设 Prompt',
                style: TextStyle(color: kWhite, fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _warned = true),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _warned ? const Color(0xFFFF2D2D) : kWhite),
                foregroundColor: _warned ? const Color(0xFFFF2D2D) : kWhite,
                shape: const RoundedRectangleBorder(),
                alignment: Alignment.topLeft,
                minimumSize: const Size.fromHeight(160),
              ),
              child: Text(
                '不准偷窥魔女的秘密',
                style: TextStyle(
                    fontWeight: _warned ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                    onPressed: widget.onReset, child: const Text('重置')),
                OutlinedButton(
                    onPressed: widget.onSave, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField(
      {super.key,
      required this.label,
      required this.controller,
      this.obscure = false});

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kWhite, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: kWhite),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kWhite),
                  borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kWhite),
                  borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
