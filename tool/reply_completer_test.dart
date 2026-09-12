import '../lib/services/reply_completer.dart';
import '../lib/services/sse_parser.dart';

int _failures = 0;

void check(String name, bool condition) {
  if (condition) {
    print('PASS: $name');
  } else {
    _failures++;
    print('FAIL: $name');
  }
}

void main() {
  // ---------- 1. finish_reason 必须被保留（A2 回归防护）----------
  print('=== SSE 解析 ===');
  const stopChunk =
      'data: {"choices":[{"delta":{"content":"写完了。"},"finish_reason":null}]}\n\n'
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n';
  final stopSse = SseAccumulator();
  final stopText = stopSse.add(stopChunk);
  check('正文解析正确', stopText == '写完了。');
  check('finish_reason=stop 被保留', stopSse.finishReason == 'stop');

  const lengthChunk =
      'data: {"choices":[{"delta":{"content":"被切断在句子中"},"finish_reason":null}]}\n\n'
      'data: {"choices":[{"delta":{},"finish_reason":"length"}]}\n\n';
  final lengthSse = SseAccumulator();
  lengthSse.add(lengthChunk);
  check('finish_reason=length 被保留', lengthSse.finishReason == 'length');

  // 思维链不能混进正文
  const reasoningChunk =
      'data: {"choices":[{"delta":{"reasoning_content":"我应该先想一下","content":"嗯。"},"finish_reason":null}]}\n\n';
  final reasoningSse = SseAccumulator();
  final reasoningText = reasoningSse.add(reasoningChunk);
  check('reasoning_content 不进入正文', reasoningText == '嗯。');

  // 分片到达（一个事件被拆成两次 add）也要能拼起来
  final splitSse = SseAccumulator();
  splitSse.add('data: {"choices":[{"delta":{"content":"半');
  check('未完成事件不产出正文', splitSse.add('句"},"finish_reason":null}]}\n\n') == '半句');

  // 残留事件 flush
  final leftoverSse = SseAccumulator();
  leftoverSse.add('data: {"choices":[{"delta":{"content":"尾巴"},"finish_reason":null}]}');
  check('flush 取出残留正文', leftoverSse.flush() == '尾巴');

  // ---------- 2. 截断启发式 ----------
  print('=== 截断判定 ===');
  check('正常句号结尾 → 未截断',
      !ReplyCompleter.looksTruncated('就这样吧。'));
  check('正常省略号结尾 → 未截断',
      !ReplyCompleter.looksTruncated('你还在听吗……'));
  check('右引号结尾 → 未截断',
      !ReplyCompleter.looksTruncated('他说「我回来了」'));
  check('英文句点结尾 → 未截断',
      !ReplyCompleter.looksTruncated('That is all.'));
  check('中文半句 → 判定截断',
      ReplyCompleter.looksTruncated('给故事一个重要名字，它才会在您的记忆'));
  // 短片段无法可靠判断，交给 finish_reason（authoritative）决定，避免误触发续写
  check('过短片段不判定，交由 finish_reason 裁决',
      !ReplyCompleter.looksTruncated('把那些不是真正属于'));
  check('过短不判定',
      !ReplyCompleter.looksTruncated('嗯'));
  // 2026-09-12 存档里的四条真实截断
  check('真实截断样本 1',
      ReplyCompleter.looksTruncated(
          '它的出版年份，只问它是否好好陪伴过某个人。世界如何对你，不妨也如此衡量。把那些不是真正属于'));
  check('真实截断样本 2',
      ReplyCompleter.looksTruncated(
          '因为一个能自忘的人，通常是先拥有了安全的立足点。他的自我不必时刻站在聚光灯下向谁证明存在，所以才能松开手'));
  check('真实截断样本 4',
      ReplyCompleter.looksTruncated('给故事一个重要名字，它才会在您的记忆'));

  // ---------- 3. token 预算 ----------
  print('=== token 预算 ===');
  check('默认上限已从 520 提升', kDefaultMaxTokens >= 900);

  print('');
  if (_failures == 0) {
    print('全部通过。');
  } else {
    print('$_failures 项失败。');
  }
}
