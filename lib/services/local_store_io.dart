import 'dart:io';

import 'key_value_store.dart';

class LocalStore implements KeyValueStore {
  /// 允许测试或特殊部署改写数据目录。
  /// 默认 `<APPDATA>\BeyondTime`。
  static const String directoryOverrideKey = 'BEYOND_TIME_STORE_DIR';

  File _file(String key) {
    final override = Platform.environment[directoryOverrideKey];
    final basePath = (override != null && override.trim().isNotEmpty)
        ? override.trim()
        : (Platform.environment['APPDATA'] ??
            Platform.environment['LOCALAPPDATA'] ??
            Directory.current.path);
    final directory = Directory(override != null && override.trim().isNotEmpty
        ? basePath
        : '$basePath\\BeyondTime');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${directory.path}\\$safeKey.json');
  }

  @override
  String? read(String key) {
    try {
      final file = _file(key);
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _file(key).writeAsStringSync(value);
    } catch (_) {
      // Local persistence is helpful, but the app should remain usable without it.
    }
  }

  @override
  void delete(String key) {
    try {
      final file = _file(key);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Ignore local cleanup failures.
    }
  }
}
