import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class ChatApiException implements Exception {
  ChatApiException(this.statusCode, this.responseText);

  final int statusCode;
  final String responseText;
}

class ChatApiClient {
  Future<String> requestStreamingReply({
    required Map<String, dynamic> payload,
    required String apiKey,
    required String apiUrl,
    required void Function(String reply) onReply,
  }) async {
    final host = (html.window.location.hostname ?? '').toLowerCase();
    final useLocalProxy =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final requestUrl = useLocalProxy ? '/api/chat' : apiUrl;
    final requestBody = useLocalProxy
        ? {
            ...payload,
            'apiKey': apiKey,
            'apiUrl': apiUrl,
          }
        : payload;

    final completer = Completer<String>();
    final request = html.HttpRequest();
    var responseCursor = 0;
    var eventBuffer = '';
    var reply = '';

    void processChunk(String chunk) {
      eventBuffer += chunk;
      final events = eventBuffer.split('\n\n');
      eventBuffer = events.removeLast();
      for (final event in events) {
        final delta = _sseDelta(event);
        if (delta.isEmpty) continue;
        reply += delta;
        onReply(reply);
      }
    }

    request.onProgress.listen((_) {
      final text = request.responseText ?? '';
      if (text.length <= responseCursor) return;
      processChunk(text.substring(responseCursor));
      responseCursor = text.length;
    });

    request.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final status = request.status ?? 0;
      final text = request.responseText ?? '';
      if (status != 200) {
        completer.completeError(ChatApiException(status, text));
        return;
      }
      if (text.length > responseCursor) {
        processChunk(text.substring(responseCursor));
        responseCursor = text.length;
      }
      if (eventBuffer.trim().isNotEmpty) {
        final delta = _sseDelta(eventBuffer);
        if (delta.isNotEmpty) {
          reply += delta;
          onReply(reply);
        }
      }
      completer.complete(reply.isEmpty ? '模型没有返回内容。' : reply);
    });

    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(ChatApiException(0, '浏览器网络请求失败。'));
      }
    });

    request.open('POST', requestUrl);
    request.setRequestHeader('Content-Type', 'application/json');
    request.setRequestHeader('Accept', 'text/event-stream');
    if (!useLocalProxy) {
      request.setRequestHeader('Authorization', 'Bearer $apiKey');
    }
    request.send(jsonEncode(requestBody));

    return completer.future;
  }
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
