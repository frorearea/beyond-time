import 'dart:convert';

/// 一段 SSE 事件解析结果。
class SseChunk {
  const SseChunk(this.content, this.finishReason);

  /// 增量正文。
  final String content;

  /// 结束原因：`stop` 正常结束，`length` 因长度上限被截断。缺失时为 null。
  final String? finishReason;

  bool get isEmpty => content.isEmpty && finishReason == null;
}

/// 解析一段 SSE 事件文本，取出增量正文与结束原因。
///
/// 注意：这里刻意只读取 `delta.content`，忽略 `delta.reasoning_content`
/// （思维链不进入界面，也不进入历史）。`finish_reason` 是判断回复是否被
/// 截断的唯一权威信号，必须保留——早期版本丢弃了它，导致截断只能靠肉眼发现。
SseChunk parseSseEvent(String event) {
  final dataLines = event
      .split('\n')
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .where((line) => line.isNotEmpty && line != '[DONE]');

  final buffer = StringBuffer();
  String? finishReason;

  for (final line in dataLines) {
    try {
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choice = choices.first;
      if (choice is! Map<String, dynamic>) continue;

      final reason = choice['finish_reason'];
      if (reason is String && reason.isNotEmpty) finishReason = reason;

      final delta = choice['delta'];
      if (delta is! Map<String, dynamic>) continue;
      final content = delta['content'];
      if (content is String) buffer.write(content);
    } catch (_) {
      continue;
    }
  }

  return SseChunk(buffer.toString(), finishReason);
}

/// 把流式累积的响应文本切成完整事件，返回 [完成的正文, 末尾残留, 结束原因]。
class SseAccumulator {
  String _buffer = '';
  String? finishReason;

  /// 追加一段原始响应，返回本次新增的正文。
  String add(String chunk) {
    _buffer += chunk;
    final events = _buffer.split('\n\n');
    _buffer = events.removeLast();
    final buffer = StringBuffer();
    for (final event in events) {
      final parsed = parseSseEvent(event);
      if (parsed.finishReason != null) finishReason = parsed.finishReason;
      buffer.write(parsed.content);
    }
    return buffer.toString();
  }

  /// 流结束时冲刷残留事件，返回剩余正文。
  String flush() {
    if (_buffer.trim().isEmpty) {
      _buffer = '';
      return '';
    }
    final parsed = parseSseEvent(_buffer);
    _buffer = '';
    if (parsed.finishReason != null) finishReason = parsed.finishReason;
    return parsed.content;
  }
}
