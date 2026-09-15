import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../data/idle_lines.dart';
import '../data/quick_options.dart';
import '../data/return_lines.dart';
import '../models/api_settings.dart';
import '../models/chat_message.dart';
import '../models/library_archive.dart';
import '../models/library_memory_item.dart';
import '../models/open_thread.dart';
import '../models/user_profile.dart';
import 'bookmark_service.dart';
import 'chat_api.dart';
import 'conversation_context.dart';
import 'error_helper.dart';
import 'memory_book.dart';
import 'memory_capture_service.dart';
import 'reply_completer.dart';
import 'return_arc.dart';
import 'store_helper.dart';
import 'thread_book.dart';

enum SendStatus { ok, missingApiKey, failed, busy, empty }

class SendOutcome {
  const SendOutcome(this.status, {this.message});

  final SendStatus status;

  /// 失败时的可读原因。
  final String? message;

  bool get needsSettings => status == SendStatus.missingApiKey;
}

enum ImportStatus { ok, unreadable, empty }

/// 图书馆会话：对话、记忆、未决之事、画像、回归弧、环境语的唯一拥有者。
///
/// 这次拆分（D1）之前，以上七套状态全都挤在 `beyond_time_page.dart` 里，
/// 谁都能改、谁都在持久化，于是出现了"导出路径漏掉过滤"这类 bug。
/// 现在的分工是：
///
/// - **LibrarySession**：所有会话数据 + 所有持久化；
/// - **页面**：布局、对话框、输入框这类纯视图状态。
///
/// 关键约束：序列化边界（[StoreHelper.saveHistory] 与 [LibraryArchive.toJsonText]）
/// 统一只写真实对话，任何调用点都不需要记得过滤。
class LibrarySession extends ChangeNotifier {
  LibrarySession({
    StoreHelper? storeHelper,
    ChatApiClient? chatApi,
    ConversationContext conversationContext = const ConversationContext(),
    BookmarkService bookmarkService = const BookmarkService(),
    ThreadBook threadBook = const ThreadBook(),
    MemoryBook memoryBook = const MemoryBook(),
    ReturnArc returnArc = const ReturnArc(),
  })  : _storeHelper = storeHelper ?? StoreHelper.platform(),
        _chatApi = chatApi ?? ChatApiClient(),
        _conversationContext = conversationContext,
        _bookmarkService = bookmarkService,
        _threadBook = threadBook,
        _memoryBook = memoryBook,
        _returnArc = returnArc {
    _memoryCaptureService = MemoryCaptureService(_chatApi);
    _replyCompleter = ReplyCompleter(_chatApi);
    _loadLocalData();
  }

  final StoreHelper _storeHelper;
  final ChatApiClient _chatApi;
  final ConversationContext _conversationContext;
  final BookmarkService _bookmarkService;
  final ThreadBook _threadBook;
  final MemoryBook _memoryBook;
  final ReturnArc _returnArc;
  late final MemoryCaptureService _memoryCaptureService;
  late final ReplyCompleter _replyCompleter;

  static const List<ChatMessage> _openingMessages = [
    ChatMessage(role: 'assistant', content: '进来吧。这里暂时只有黑暗、我、还有你可以慢慢放下的声音。'),
  ];

  List<ChatMessage> _messages = _openingMessages;
  List<LibraryMemoryItem> _memories = const [];
  List<OpenThread> _threads = const [];
  UserProfile _profile = UserProfile();
  ApiSettings _apiSettings = const ApiSettings();
  String _persona = kFallbackPersona;
  String _uiLayout = 'storybook';
  bool _showQuickOptions = false;
  bool _isSending = false;
  int _quickOptionPoolIndex = 0;
  int _memoryCaptureCooldown = 0;
  bool _isMemoryCaptureRunning = false;
  Timer? _idleTimer;
  bool _idleDone = false;
  bool _disposed = false;

  /// 仅测试用：注入一个"当前时间"，让回归档位与过期判断可复现。
  @visibleForTesting
  DateTime Function() nowProvider = DateTime.now;

  // ---------------------------------------------------------------- 读取

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<LibraryMemoryItem> get memories => List.unmodifiable(_memories);
  List<OpenThread> get threads => List.unmodifiable(_threads);
  UserProfile get profile => _profile;
  ApiSettings get apiSettings => _apiSettings;
  String get persona => _persona;
  String get uiLayout => _uiLayout;
  bool get showQuickOptions => _showQuickOptions;
  bool get isSending => _isSending;
  int get quickOptionPoolIndex => _quickOptionPoolIndex;
  bool get isConfigured => _apiSettings.isConfigured;

  /// 手动收藏的句子。它们有独立的书架，不算"关于来访者的事实"。
  List<LibraryMemoryItem> get bookmarks =>
      _memories.where((memory) => memory.isBookmark).toList();

  /// 关于来访者的事实：喜好、压力、热爱、困扰、自我理解……
  List<LibraryMemoryItem> get knowledgeMemories =>
      _memories.where((memory) => memory.isKnowledge).toList();

  List<OpenThread> get openThreads =>
      _threadBook.sorted(_threads).where((thread) => thread.isOpen).toList();

  List<OpenThread> get resolvedThreads =>
      _threadBook.sorted(_threads).where((thread) => !thread.isOpen).toList();

  List<String> get quickOptions =>
      kQuickOptionPools[_quickOptionPoolIndex % kQuickOptionPools.length];

  /// 占卜的记忆门槛：只数"关于来访者的事实"，书签不算认识一个人。
  List<LibraryMemoryItem> get tarotMemories => knowledgeMemories
      .where((memory) => memory.content.trim().isNotEmpty)
      .toList();

  bool get canStartTarotReading => tarotMemories.length >= 5;

  List<OpenThread> get greetingCandidateThreads => _threads;

  /// 纯对话历史（已剔除环境语、回执、报错）。
  List<ChatMessage> get conversationHistory =>
      _messages.where((message) => message.isChat).toList();

  // ---------------------------------------------------------------- 生命周期

  /// 读取人设。异步，失败时保留 fallback，不阻塞首屏。
  Future<void> start() async {
    try {
      final persona = (await rootBundle.loadString(kPersonaAsset)).trim();
      if (_disposed || persona.isEmpty) return;
      _persona = persona;
      _notify();
    } catch (_) {
      // 保留 kFallbackPersona。
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _idleTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _loadLocalData() {
    final settings = _storeHelper.loadSettings();
    _apiSettings = _storeHelper.loadApiSettings();
    _uiLayout = settings['uiLayout'] ?? 'storybook';
    _showQuickOptions = settings['showQuickOptions'] == 'true';
    _quickOptionPoolIndex = _storeHelper.loadQuickOptionPoolIndex();
    _messages = _storeHelper.loadHistory() ?? _openingMessages;
    _memories = _storeHelper.loadLibraryMemory();
    _threads = _storeHelper.loadOpenThreads();
    _profile = _storeHelper.loadUserProfile() ?? UserProfile();
    _profile.touch();
    _storeHelper.saveUserProfile(_profile);
    _applyReturnGreeting();
    _startIdleTimer();
  }

  // ---------------------------------------------------------------- 回归弧

  void _applyReturnGreeting() {
    final lastVisit = _storeHelper.loadLastVisit();
    if (lastVisit == null) {
      _storeHelper.saveLastVisit(nowProvider().toIso8601String());
      return;
    }
    final last = DateTime.tryParse(lastVisit);
    if (last == null) return;
    final now = nowProvider();
    final tier = ReturnArc.tierFor(now.difference(last));
    if (tier == null) return;
    _replaceAmbient(
      _returnArc.greetingFor(tier: tier, threads: _threads, now: now),
    );
    _persistHistory();
  }

  /// 这次推门时该说的第一句话（供测试直接调用）。
  @visibleForTesting
  String buildReturnGreeting(ReturnTier tier) {
    return _returnArc.greetingFor(
      tier: tier,
      threads: _threads,
      now: nowProvider(),
    );
  }

  // ---------------------------------------------------------------- 环境语

  void _startIdleTimer() {
    if (_idleDone) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 5), _fireIdleLine);
  }

  void _fireIdleLine() {
    if (_disposed || _isSending) return;
    _idleDone = true;
    final line = (List<String>.of(kIdleLines)..shuffle(math.Random())).first;
    _replaceAmbient(line);
    _persistHistory();
    _notify();
  }

  /// 页面至多保留一条环境台词。
  void _replaceAmbient(String line) {
    _messages = [
      ..._messages.where((message) => message.kind != MessageKind.ambient),
      ChatMessage(role: 'assistant', content: line, kind: MessageKind.ambient),
    ];
  }

  // ---------------------------------------------------------------- 发送

  Future<SendOutcome> send(
    String text, {
    bool captureMemory = true,
    String? extraSystemInstruction,
    int maxTokens = kDefaultMaxTokens,
  }) async {
    if (_isSending) return const SendOutcome(SendStatus.busy);
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SendOutcome(SendStatus.empty);

    _startIdleTimer();
    _append(ChatMessage(role: 'user', content: trimmed));
    _profile.observe(trimmed);
    _storeHelper.saveUserProfile(_profile);
    // 来访者自己的话立刻落盘：不要等到模型回复成功才保存，
    // 否则连接失败或直接关掉页面时，他说过的话会消失。
    _persistHistory();

    if (!_apiSettings.isConfigured) {
      // 回执是 notice 而不是对话：界面可见，但不会进存档、不会进上下文，
      // 否则下一次成功发送会把它当成"艾蕾塔说过的话"写进历史。
      _append(const ChatMessage(
        role: 'assistant',
        content: '还没有填写 API Key。先打开右上角设置，亲爱的。',
        kind: MessageKind.notice,
      ));
      _notify();
      return const SendOutcome(SendStatus.missingApiKey);
    }

    _isSending = true;
    _append(const ChatMessage(role: 'assistant', content: ''));
    _notify();

    try {
      final reply = await _requestReply(
        extraSystemInstruction: extraSystemInstruction,
        maxTokens: maxTokens,
      );
      if (_disposed) return const SendOutcome(SendStatus.ok);
      _replaceLastAssistant(_conversationContext.cleanReply(reply));
      _isSending = false;
      _persistHistory();
      _storeHelper.saveLastVisit(nowProvider().toIso8601String());
      _notify();
      _startIdleTimer();
      if (captureMemory) {
        unawaited(_maybeCapture(userText: trimmed, assistantReply: reply));
      }
      return const SendOutcome(SendStatus.ok);
    } catch (error) {
      if (_disposed) return SendOutcome(SendStatus.failed, message: '$error');
      _replaceLastAssistant('连接没有成功：$error', kind: MessageKind.error);
      _isSending = false;
      _notify();
      _startIdleTimer();
      return SendOutcome(SendStatus.failed, message: '$error');
    }
  }

  Future<String> _requestReply({
    String? extraSystemInstruction,
    int maxTokens = kDefaultMaxTokens,
  }) async {
    final payload = {
      'model': _apiSettings.resolvedModel,
      'messages': _conversationContext.buildMessages(
        persona: _persona,
        messages: _messages,
        memories: _memories,
        threads: _threads,
        userProfile: _profile,
        extraSystemInstruction: extraSystemInstruction,
      ),
      'temperature': 1.35,
      'max_tokens': maxTokens,
      'stream': true,
      'stream_options': {'include_usage': false},
      'thinking': {'type': 'enabled'},
    };

    try {
      final result = await _replyCompleter.request(
        payload: payload,
        apiKey: _apiSettings.apiKey.trim(),
        apiUrl: _apiSettings.resolvedApiUrl,
        onReply: (reply) {
          if (_disposed) return;
          _replaceLastAssistant(_conversationContext.cleanReply(reply));
          _notify();
        },
      );
      return result.text;
    } on ChatApiException catch (error) {
      throw friendlyHttpError(error.statusCode, error.responseText);
    }
  }

  // ---------------------------------------------------------------- 记忆整理

  Future<void> _maybeCapture({
    required String userText,
    required String assistantReply,
  }) async {
    final compactUserText = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_memoryCaptureService.shouldSkipUserText(compactUserText)) return;
    if (!_apiSettings.isConfigured) return;
    if (_isMemoryCaptureRunning) return;
    if (_memoryCaptureCooldown > 0) {
      _memoryCaptureCooldown -= 1;
      return;
    }

    _isMemoryCaptureRunning = true;
    try {
      final outcome = await _memoryCaptureService.capture(
        userText: compactUserText,
        assistantReply: assistantReply,
        existingMemories: _memories,
        existingThreads: _threads,
        apiKey: _apiSettings.apiKey.trim(),
        apiUrl: _apiSettings.resolvedApiUrl,
        model: _apiSettings.resolvedModel,
      );
      if (_disposed) return;
      if (outcome.isEmpty) {
        _memoryCaptureCooldown = 1;
        return;
      }

      var changed = false;
      if (outcome.memory != null) {
        _memories = _memoryBook.append(_memories, outcome.memory!);
        _storeHelper.saveLibraryMemory(_memories);
        changed = true;
      }

      var threads = _threads;
      if (outcome.resolveThreadId != null) {
        threads = _threadBook.resolve(threads, outcome.resolveThreadId,
            now: nowProvider());
      }
      if (outcome.threadDraft != null) {
        threads = _threadBook.merge(threads, outcome.threadDraft!,
            now: nowProvider());
      }
      if (!identical(threads, _threads)) {
        _threads = threads;
        _storeHelper.saveOpenThreads(_threads);
        changed = true;
      }

      if (changed) _notify();
      _memoryCaptureCooldown = 2;
    } catch (_) {
      _memoryCaptureCooldown = 1;
    } finally {
      _isMemoryCaptureRunning = false;
    }
  }

  /// 把一段用户文本直接送入"未决之事"簿记（测试与手工修复用）。
  @visibleForTesting
  void mergeThreadForTest(OpenThreadDraft draft) {
    _threads = _threadBook.merge(_threads, draft, now: nowProvider());
    _storeHelper.saveOpenThreads(_threads);
    _notify();
  }

  // ---------------------------------------------------------------- 书签

  /// 收藏一句选中的话。回执只出现在界面上，不会污染对话记录。
  BookmarkResult addBookmark(String selectedText) {
    final result = _bookmarkService.addBookmark(
      memories: _memories,
      selectedText: selectedText,
    );
    if (result.added) {
      _memories = result.memories;
      _storeHelper.saveLibraryMemory(_memories);
    }
    _append(ChatMessage(
      role: 'assistant',
      content: result.notice,
      kind: MessageKind.notice,
    ));
    _notify();
    return result;
  }

  // ---------------------------------------------------------------- 心声

  void advanceQuickOptions() {
    _quickOptionPoolIndex += 1;
    _storeHelper.saveQuickOptionPoolIndex(_quickOptionPoolIndex);
    _startIdleTimer();
    _notify();
  }

  // ---------------------------------------------------------------- 设置

  void updateApiSettings(ApiSettings settings) {
    _apiSettings = settings;
    _persistSettings();
    _notify();
  }

  void updateLayout(String layout) {
    _uiLayout = layout;
    _persistSettings();
    _notify();
  }

  void setShowQuickOptions(bool value) {
    _showQuickOptions = value;
    _persistSettings();
    _notify();
  }

  void _persistSettings() {
    _storeHelper.saveSettings(
      _apiSettings,
      uiLayout: _uiLayout,
      showQuickOptions: _showQuickOptions,
    );
  }

  // ---------------------------------------------------------------- 存档

  String buildArchiveText() {
    return LibraryArchive(
      messages: _messages,
      memories: _memories,
      threads: _threads,
      quickOptionPoolIndex: _quickOptionPoolIndex,
    ).toJsonText();
  }

  ImportStatus importArchive(String raw) {
    if (raw.trim().isEmpty) return ImportStatus.empty;
    final archive = LibraryArchive.tryParse(raw);
    if (archive == null) return ImportStatus.unreadable;
    _messages = archive.messages;
    _memories = archive.memories;
    _threads = archive.threads;
    _quickOptionPoolIndex = archive.quickOptionPoolIndex;
    _persistHistory();
    _storeHelper.saveLibraryMemory(_memories);
    _storeHelper.saveOpenThreads(_threads);
    _storeHelper.saveQuickOptionPoolIndex(_quickOptionPoolIndex);
    _notify();
    return ImportStatus.ok;
  }

  void clearChat() {
    _messages = const [
      ChatMessage(
        role: 'assistant',
        content: '房间重新安静下来了。您可以从任何一个句子重新开始，亲爱的。',
      ),
    ];
    _storeHelper.deleteHistory();
    _storeHelper.saveLastVisit(nowProvider().toIso8601String());
    _idleDone = false;
    _startIdleTimer();
    _notify();
  }

  void resetEverything() {
    _messages = const [
      ChatMessage(role: 'assistant', content: '书页重新变白了。亲爱的，我们可以从这里重新开始。'),
    ];
    _memories = const [];
    _threads = const [];
    _quickOptionPoolIndex = 0;
    _storeHelper.deleteHistory();
    _storeHelper.deleteLibraryMemory();
    _storeHelper.deleteOpenThreads();
    _storeHelper.deleteQuickOptionPoolIndex();
    _storeHelper.saveLastVisit(nowProvider().toIso8601String());
    _idleDone = false;
    _startIdleTimer();
    _notify();
  }

  // ---------------------------------------------------------------- 内部

  void _append(ChatMessage message) {
    _messages = [..._messages, message];
  }

  void _replaceLastAssistant(String content, {MessageKind? kind}) {
    if (_messages.isEmpty) return;
    final next = [..._messages];
    next[next.length - 1] = ChatMessage(
      role: 'assistant',
      content: content,
      kind: kind ?? next[next.length - 1].kind,
    );
    _messages = next;
  }

  /// 过滤在 StoreHelper 内部完成，这里只是把当前消息交给它。
  void _persistHistory() {
    _storeHelper.saveHistory(_messages);
  }
}
