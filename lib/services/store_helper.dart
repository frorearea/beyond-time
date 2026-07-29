import 'dart:convert';

import '../config.dart';
import '../models/chat_message.dart';
import '../models/library_memory_item.dart';
import 'local_store.dart';

class StoreHelper {
  const StoreHelper(this._store);

  final LocalStore _store;

  Map<String, String> loadSettings() {
    final raw = _store.read(kSettingsKey);
    if (raw == null) return {};
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return {
      'apiKey': data['apiKey']?.toString() ?? '',
      'apiUrl': data['apiUrl']?.toString() ?? kDefaultApiUrl,
      'model': data['model']?.toString() ?? kDefaultModel,
      'uiLayout': data['uiLayout']?.toString() ?? 'classic',
    };
  }

  void saveSettings(
    String apiKey,
    String apiUrl,
    String model, {
    String uiLayout = 'classic',
  }) {
    _store.write(
      kSettingsKey,
      jsonEncode({
        'apiKey': apiKey,
        'apiUrl': apiUrl,
        'model': model,
        'uiLayout': uiLayout,
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
    final data = jsonDecode(raw) as List<dynamic>;
    final history = data
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    return history.isNotEmpty ? history : null;
  }

  void saveHistory(List<ChatMessage> messages) {
    _store.write(
      kHistoryKey,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
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

  void deleteQuickOptionPoolIndex() {
    _store.delete(kQuickCountKey);
  }
}
