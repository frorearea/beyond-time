/// 一条网页搜索结果。
///
/// 字段对应 DeepSeek Search API（`POST /v1/tools/search`）返回的 `results[]`。
/// 刻意只保留用得上的四个：`summary` 是 600–800 字、**专门给模型读**的那一版，
/// `snippet` 是 100–200 字给人看的那一版——两者都在时优先用 summary。
class WebSearchHit {
  const WebSearchHit({
    required this.title,
    required this.url,
    required this.summary,
    this.date,
  });

  final String title;
  final String url;

  /// 用于注入模型上下文的正文摘要。
  final String summary;

  /// 发布时间（RFC 3339 字符串），未知时为 null。
  final String? date;
}
