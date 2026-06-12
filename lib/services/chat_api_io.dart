import 'dart:convert';
import 'dart:io';

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
        throw ChatApiException(response.statusCode, text);
      }

      await for (final chunk in response.transform(utf8.decoder)) {
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

      if (eventBuffer.trim().isNotEmpty) {
        final delta = _sseDelta(eventBuffer);
        if (delta.isNotEmpty) {
          reply += delta;
          onReply(reply);
        }
      }

      return reply.isEmpty ? '模型没有返回内容。' : reply;
    } finally {
      client.close(force: true);
    }
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
