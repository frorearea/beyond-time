import 'dart:io';

class LocalStore {
  File _file(String key) {
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

  String? read(String key) {
    try {
      final file = _file(key);
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  void write(String key, String value) {
    try {
      _file(key).writeAsStringSync(value);
    } catch (_) {
      // Local persistence is helpful, but the app should remain usable without it.
    }
  }

  void delete(String key) {
    try {
      final file = _file(key);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Ignore local cleanup failures.
    }
  }
}
