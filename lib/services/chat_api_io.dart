import 'dart:convert';
import 'dart:io';

import 'sse_parser.dart';

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
    void Function(String reason)? onFinishReason,
  }) async {
    final client = HttpClient();
    final sse = SseAccumulator();
    var reply = '';
    var reasonReported = false;

    void reportReason() {
      if (reasonReported) return;
      final reason = sse.finishReason;
      if (reason == null) return;
      reasonReported = true;
      onFinishReason?.call(reason);
    }

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
        final delta = sse.add(chunk);
        if (delta.isNotEmpty) {
          reply += delta;
          onReply(reply);
        }
        reportReason();
      }

      final rest = sse.flush();
      if (rest.isNotEmpty) {
        reply += rest;
        onReply(reply);
      }
      reportReason();

      return reply.isEmpty ? '模型没有返回内容。' : reply;
    } finally {
      client.close(force: true);
    }
  }
}
