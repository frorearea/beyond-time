import 'dart:convert';

import '../config.dart';
import '../models/api_settings.dart';
import '../models/chat_message.dart';
import '../models/library_memory_item.dart';
import '../models/open_thread.dart';
import '../models/user_profile.dart';
import 'key_value_store.dart';
import 'local_store.dart';

class StoreHelper {
  const StoreHelper(this._store);

  /// 默认实现读平台存储；测试可注入 [InMemoryStore]。
  factory StoreHelper.platform() => StoreHelper(LocalStore());

  final KeyValueStore _store;

  ApiSettings loadApiSettings() {
    final raw = _store.read(kSettingsKey);
    if (raw == null) return const ApiSettings();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ApiSettings(
        apiKey: data['apiKey']?.toString() ?? '',
        apiUrl: data['apiUrl']?.toString().trim().isNotEmpty == true
            ? data['apiUrl'].toString()
            : kDefaultApiUrl,
        model: data['model']?.toString().trim().isNotEmpty == true
            ? data['model'].toString()
            : kDefaultModel,
      );
    } catch (_) {
      return const ApiSettings();
    }
  }

  /// 带界面的设置读取。API 设置与界面偏好共用一个 key，所以一起解析。
  Map<String, String> loadSettings() {
    final raw = _store.read(kSettingsKey);
    final api = loadApiSettings();
    if (raw == null) {
      return {
        'apiKey': api.apiKey,
        'apiUrl': api.apiUrl,
        'model': api.model,
        'uiLayout': 'classic',
        'showQuickOptions': 'false',
      };
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'apiKey': api.apiKey,
        'apiUrl': api.apiUrl,
        'model': api.model,
        'uiLayout': data['uiLayout']?.toString() ?? 'classic',
        'showQuickOptions': data['showQuickOptions'] == true ? 'true' : 'false',
      };
    } catch (_) {
      return {
        'apiKey': api.apiKey,
        'apiUrl': api.apiUrl,
        'model': api.model,
        'uiLayout': 'classic',
        'showQuickOptions': 'false',
      };
    }
  }

  void saveSettings(
    ApiSettings api, {
    String uiLayout = 'classic',
    bool showQuickOptions = false,
  }) {
    _store.write(
      kSettingsKey,
      jsonEncode({
        'apiKey': api.apiKey,
        'apiUrl': api.apiUrl,
        'model': api.model,
        'uiLayout': uiLayout,
        'showQuickOptions': showQuickOptions,
      }),
    );
  }

  int loadQuickOptionPoolIndex() {
    return int.tryParse(_store.read(kQuickCountKey) ?? '0') ?? 0;
  }

  void saveQuickOptionPoolIndex(int index) {
    _store.write(kQuickCountKey, index.toString());
  }

  List<ChatMessage>? loadHistory() {
    final raw = _store.read(kHistoryKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      final history = data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .where((message) => message.isChat)
          .where((message) => message.content.trim().isNotEmpty)
          .toList();
      return history.isNotEmpty ? history : null;
    } catch (_) {
      return null;
    }
  }

  /// 只落盘真实对话。
  ///
  /// 过滤放在这一层而不是各个调用点：旧版本的导出路径漏掉了 `isAmbient`
  /// 过滤，于是环境语与书签回执被写进了对话记录。只要序列化边界是唯一的
  /// 收口，任何调用点都不可能再漏。
  void saveHistory(List<ChatMessage> messages) {
    final durable =
        messages.where((message) => message.isChat).toList(growable: false);
    _store.write(
      kHistoryKey,
      jsonEncode(durable.map((message) => message.toJson()).toList()),
    );
  }

  void deleteHistory() {
    _store.delete(kHistoryKey);
  }

  List<LibraryMemoryItem> loadLibraryMemory() {
    final raw = _store.read(kLibraryMemoryKey);
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) {
            if (item is Map<String, dynamic>) {
              return LibraryMemoryItem.fromJson(item);
            }
            return LibraryMemoryItem.fromLegacyString(item.toString());
          })
          .where((item) => item.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void saveLibraryMemory(List<LibraryMemoryItem> memories) {
    _store.write(
      kLibraryMemoryKey,
      jsonEncode(memories.map((memory) => memory.toJson()).toList()),
    );
  }

  void deleteLibraryMemory() {
    _store.delete(kLibraryMemoryKey);
  }

  List<OpenThread> loadOpenThreads() {
    final raw = _store.read(kOpenThreadsKey);
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(OpenThread.tryFromJson)
          .whereType<OpenThread>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void saveOpenThreads(List<OpenThread> threads) {
    _store.write(
      kOpenThreadsKey,
      jsonEncode(threads.map((thread) => thread.toJson()).toList()),
    );
  }

  void deleteOpenThreads() {
    _store.delete(kOpenThreadsKey);
  }

  void deleteQuickOptionPoolIndex() {
    _store.delete(kQuickCountKey);
  }

  String? loadLastVisit() {
    return _store.read(kLastVisitKey);
  }

  void saveLastVisit(String timestamp) {
    _store.write(kLastVisitKey, timestamp);
  }

  UserProfile? loadUserProfile() {
    final raw = _store.read(kUserProfileKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void saveUserProfile(UserProfile profile) {
    _store.write(kUserProfileKey, jsonEncode(profile.toJson()));
  }
}
