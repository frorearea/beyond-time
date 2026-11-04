import 'dart:convert';
import 'dart:io';

/// 网页搜索失败。[statusCode] 为 0 表示网络层失败。
class WebSearchException implements Exception {
  WebSearchException(this.statusCode, this.responseText);

  final int statusCode;
  final String responseText;
}

/// DeepSeek Search API 的极薄客户端：只发请求、把原始响应体交回去。
///
/// **解析与格式化不在这里做**——它们在 `web_search_service.dart` 里，是纯函数，
/// 可以零依赖单测，不必打网络。和 `chat_api_*` 的分工保持一致。
class WebSearchClient {
  Future<String> search({
    required String query,
    required String apiKey,
    required String searchUrl,
    required int count,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(searchUrl));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.write(jsonEncode({'query': query, 'count': count}));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw WebSearchException(response.statusCode, text);
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }
}
