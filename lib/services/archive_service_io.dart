import 'dart:io';

class ArchiveService {
  Directory _desktopDirectory() {
    final userProfile = Platform.environment['USERPROFILE'];
    final desktop = userProfile == null
        ? Directory.current
        : Directory('$userProfile\\Desktop');
    if (!desktop.existsSync()) {
      desktop.createSync(recursive: true);
    }
    return desktop;
  }

  File _archiveFile(String fileName) {
    final desktop = _desktopDirectory();
    return File('${desktop.path}\\$fileName');
  }

  Future<String?> importArchiveText() async {
    final files = _desktopDirectory()
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.split('\\').last.startsWith('beyond-time-library'))
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (files.isEmpty) return null;
    return files.first.readAsString();
  }

  Future<String> exportArchiveText({
    required String fileName,
    required String content,
  }) async {
    final file = _archiveFile(fileName);
    await file.writeAsString(content);
    return '存档已写到桌面：${file.path}';
  }
}
