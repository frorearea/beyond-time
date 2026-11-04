import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// 网页搜索失败。[statusCode] 为 0 表示网络层失败。
class WebSearchException implements Exception {
  WebSearchException(this.statusCode, this.responseText);

  final int statusCode;
  final String responseText;
}

/// DeepSeek Search API 的极薄客户端（Web）。
///
/// **一律走同源 `/api/search`**，不尝试直连：
/// - 直连 `api.deepseek.com` 会被 CORS 拦（线上尤其），而且失败要等一轮超时；
/// - 同源代理没开时只是一个很快的 404，`buildContext` 会当作"没搜到"，不拖慢对话。
///
/// 也就是说：**联网只在有代理的部署上生效**（本地 `node server.js`、Docker、
/// Cloudflare Worker）。`github.io` 上没有代理，等于安静地不联网。
class WebSearchClient {
  Future<String> search({
    required String query,
    required String apiKey,
    required String searchUrl,
    required int count,
  }) async {
    const requestUrl = '/api/search';
    final body = jsonEncode({
      'query': query,
      'count': count,
      'apiKey': apiKey,
      'searchUrl': searchUrl,
    });

    final completer = Completer<String>();
    final request = html.HttpRequest();

    request.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final status = request.status ?? 0;
      final text = request.responseText ?? '';
      if (status != 200) {
        completer.completeError(WebSearchException(status, text));
        return;
      }
      completer.complete(text);
    });
    request.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(WebSearchException(0, '搜索请求失败。'));
      }
    });

    request.open('POST', requestUrl);
    request.setRequestHeader('Content-Type', 'application/json');
    request.send(body);

    return completer.future;
  }
}
