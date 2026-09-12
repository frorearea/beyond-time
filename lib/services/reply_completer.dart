import 'chat_api.dart';

/// 一次完整回复（可能由多段续写拼成）。
class ReplyResult {
  const ReplyResult({
    required this.text,
    required this.continuations,
    required this.hitTokenLimit,
  });

  final String text;

  /// 触发了多少次自动续写。
  final int continuations;

  /// 最后一次仍以 `finish_reason: length` 结束（即续写后依然被上限截断）。
  final bool hitTokenLimit;

  bool get wasContinued => continuations > 0;
}

/// 续写指令：只在检测到截断时下发。
const String kContinuationInstruction =
    '你上一条回复因为长度上限被硬生生截断了。请从中断处接着写完，'
    '不要重复已经写过的内容，不要重新开头，不要解释发生了什么。直接继续。';

/// 视为「写完了」的收尾字符。以此结尾就不再续写。
const String _kTerminalChars = '。！？…～!?.”’」』】》〉）)]}';

/// 正常回复允许的 token 上限。
///
/// 旧值是 520，同时开启 thinking 时思维链会吃掉其中相当一部分预算，
/// 导致正文在句子中间被切断（参见 2026-09-12 存档里的 4 条截断回复）。
const int kDefaultMaxTokens = 1000;

class ReplyCompleter {
  ReplyCompleter(this._chatApi);

  final ChatApiClient _chatApi;

  /// 自动续写的最大次数。每次续写都会重发上下文，因此保持克制。
  static const int maxContinuations = 1;

  /// 累计正文超过此长度后不再续写，避免异常情况下无限增长。
  static const int _lengthGuard = 4000;

  /// 请求一次回复；若被长度上限截断，自动续写并拼接结果。
  ///
  /// [onReply] 每次都收到「目前为止的完整正文」，可直接用于打字机渲染。
  Future<ReplyResult> request({
    required Map<String, dynamic> payload,
    required String apiKey,
    required String apiUrl,
    required void Function(String reply) onReply,
  }) async {
    final baseMessages =
        List<Map<String, dynamic>>.from(payload['messages'] as List);

    final buffer = StringBuffer();
    var continuations = 0;
    var hitTokenLimit = false;

    for (var attempt = 0; attempt <= maxContinuations; attempt++) {
      final messages = attempt == 0
          ? baseMessages
          : <Map<String, dynamic>>[
              ...baseMessages,
              {'role': 'assistant', 'content': buffer.toString()},
              {'role': 'system', 'content': kContinuationInstruction},
            ];

      String? finishReason;
      final reply = await _chatApi.requestStreamingReply(
        payload: {...payload, 'messages': messages},
        apiKey: apiKey,
        apiUrl: apiUrl,
        onReply: (partial) => onReply(buffer.toString() + partial),
        onFinishReason: (reason) => finishReason = reason,
      );

      buffer.write(reply);
      onReply(buffer.toString());

      hitTokenLimit = finishReason == 'length';
      final truncated =
          hitTokenLimit || (finishReason == null && looksTruncated(buffer.toString()));

      if (!truncated) break;
      if (attempt == maxContinuations) break;
      if (buffer.length >= _lengthGuard) break;
      continuations += 1;
    }

    return ReplyResult(
      text: buffer.toString(),
      continuations: continuations,
      hitTokenLimit: hitTokenLimit,
    );
  }

  /// 兜底启发式：仅在上游没有给出 `finish_reason` 时才有意义。
  ///
  /// 正文没有以收尾标点或右括号结束，说明很可能被切断在句子中间。
  static bool looksTruncated(String text) {
    final trimmed = text.trimRight();
    if (trimmed.length < 12) return false;
    final last = trimmed[trimmed.length - 1];
    if (_kTerminalChars.contains(last)) return false;
    if (RegExp(r'[A-Za-z0-9]$').hasMatch(trimmed)) return false;
    return true;
  }
}
