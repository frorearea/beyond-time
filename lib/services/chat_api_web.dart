import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
    final host = (html.window.location.hostname ?? '').toLowerCase();
    final useLocalProxy = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.workers.dev') ||
        host.endsWith('.pages.dev');
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
    final sse = SseAccumulator();
    var responseCursor = 0;
    var reply = '';
    var reasonReported = false;

    void reportReason() {
      if (reasonReported) return;
      final reason = sse.finishReason;
      if (reason == null) return;
      reasonReported = true;
      onFinishReason?.call(reason);
    }

    void processChunk(String chunk) {
      final delta = sse.add(chunk);
      if (delta.isEmpty) {
        reportReason();
        return;
      }
      reply += delta;
      onReply(reply);
      reportReason();
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
      final rest = sse.flush();
      if (rest.isNotEmpty) {
        reply += rest;
        onReply(reply);
      }
      reportReason();
      // 原样返回，**不在这里编造"模型没有返回内容。"**：
      // 流为空是需要上层判断的语义（可能是思维链吃光了预算、应当重试），
      // 不是一句可以当成"她说过的话"的字符串。曾经在这里塞了兜底文案，
      // 结果被 ReplyCompleter 当成她的半截回复写进续写请求，落进存档之后
      // 她的原话字面上以「模型没有返回内容。」开头（2026-10-11 存档里 3 处）。
      completer.complete(reply);
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
