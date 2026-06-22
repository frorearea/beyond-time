import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class ArchiveService {
  Future<String?> importArchiveText() {
    final completer = Completer<String?>();
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json';
    input.click();
    input.onChange.first.then((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        completer.complete(null);
        return;
      }

      final reader = html.FileReader();
      reader.onLoad.first.then((_) {
        completer.complete(reader.result?.toString());
      });
      reader.onError.first.then((_) => completer.completeError('存档读取失败。'));
      reader.readAsText(file, 'utf-8');
    });
    return completer.future;
  }

  Future<String> exportArchiveText({
    required String fileName,
    required String content,
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/json;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return '存档已经交给浏览器下载。';
  }
}
