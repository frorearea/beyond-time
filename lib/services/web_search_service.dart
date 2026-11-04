import 'dart:convert';

import '../config.dart';
import '../models/web_search_hit.dart';
import 'web_search.dart';

/// 联网搜索：把"她需要时能拿到新鲜资料"这件事做成资料注入，而不是换接口。
///
/// 为什么不走 Responses API 的 `web_search` 工具（2026-11 核实过）：
/// 那条路只支持 `deepseek-v4-pro`、流式事件格式不同（要重写 `sse_parser`），
/// 而且**思考模式下 `temperature` 不生效**——等于废掉她的声音调校。
///
/// 这里改成"客户端先搜，再把 `summary` 作为资料注入上下文"：她的接口、模型、
/// 温度、流式解析全都不动，只是在需要的时候多一份参考资料。搜索失败一律当作
/// 没搜到，绝不会挡住回复。
class WebSearchService {
  const WebSearchService(this._client);

  final WebSearchClient _client;

  /// 太短的消息不搜（"嗯""继续说"）。
  static const int minQueryLength = 6;

  /// 接口对 query 的限制。
  static const int maxQueryLength = 128;

  /// 搜索本身的超时。**必须有上限**：它是回复前的一道额外网络调用，
  /// 挂住就会让来访者在打字机开始前干等。
  static const Duration timeout = Duration(seconds: 8);

  /// 这条消息值不值得搜。
  bool shouldSearch(String text) => buildQuery(text).length >= minQueryLength;

  /// 把用户消息压成一次搜索查询：去掉换行、截到接口允许的长度。
  String buildQuery(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= maxQueryLength) return flat;
    return flat.substring(0, maxQueryLength);
  }

  /// 搜索并组装成可注入的上下文块；没搜到、失败、或不需要搜时返回 null。
  ///
  /// **这个方法不会抛异常。**联网只是锦上添花，绝不能把一次对话拖垮。
  Future<String?> buildContext({
    required String query,
    required String apiKey,
    required String searchUrl,
    int count = kMaxSearchResults,
  }) async {
    if (apiKey.trim().isEmpty) return null;
    if (!shouldSearch(query)) return null;
    try {
      final raw = await _client
          .search(
            query: buildQuery(query),
            apiKey: apiKey,
            searchUrl: searchUrl,
            count: count,
          )
          .timeout(timeout);
      final hits = parseResults(raw);
      if (hits.isEmpty) return null;
      return formatForContext(hits);
    } catch (_) {
      return null;
    }
  }

  /// 解析 Search API 的响应。纯函数，可零依赖单测。
  List<WebSearchHit> parseResults(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const [];
      final results = data['results'];
      if (results is! List) return const [];
      final hits = <WebSearchHit>[];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final title = (item['title'] ?? '').toString().trim();
        final summary = (item['summary'] ?? '').toString().trim();
        final snippet = (item['snippet'] ?? '').toString().trim();
        // summary 是"给模型读"的那一版，优先它；没有才退回 snippet。
        final body = summary.isNotEmpty ? summary : snippet;
        if (body.isEmpty) continue;
        final date = (item['date'] ?? '').toString().trim();
        hits.add(WebSearchHit(
          title: title.isEmpty ? '（无标题）' : title,
          url: (item['url'] ?? '').toString().trim(),
          summary: body,
          date: date.isEmpty ? null : date,
        ));
        if (hits.length >= kMaxSearchResults) break;
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  /// 把结果组装成一段系统资料。没有结果时返回空串（调用方据此不注入）。
  String formatForContext(List<WebSearchHit> hits) {
    if (hits.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln('以下是从网上刚查到的资料，可能有用、可能不相关、也可能已经过时。')
      ..writeln('它们只能当事实依据：不要编造资料里没有的内容；查不到就照实说查不到；')
      ..writeln('如果这些资料和来访者这句话无关，就当没看见，不要硬把话题拐过去。');
    for (final hit in hits) {
      final when = hit.date == null ? '' : '（${hit.date}）';
      buffer.writeln('- ${hit.title}$when：${hit.summary}');
    }
    return buffer.toString().trim();
  }
}
