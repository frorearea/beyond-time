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
  check('默认上限已提到 1600（思维链偶尔会吃光 1000）', kDefaultMaxTokens >= 1500);

  // ---------- 4. 重试请求的组装（2026-10-11 空回复事故）----------
  //
  // 事故链：思维链把 max_tokens 全吃光 → 流里一个字都没有、
  // finish_reason=length → chat_api 那时会返回兜底文案「模型没有返回内容。」
  // → ReplyCompleter 把这句话当成她的半截回复写进续写请求 →
  // 模型顺着它往下写 → 存档里她的原话字面上以那句话开头（3 处）。
  print('=== 重试请求的组装 ===');
  final base = <Map<String, dynamic>>[
    {'role': 'system', 'content': '人设'},
    {'role': 'user', 'content': '我说的话'},
  ];

  final withPartial = ReplyCompleter.buildRetryMessages(
    baseMessages: base,
    partial: '给故事一个重要名字，它才会在您的记忆',
  );
  check('有半截正文时保留她已写的内容',
      withPartial.any((m) => m['role'] == 'assistant' && m['content'] == '给故事一个重要名字，它才会在您的记忆'));
  check('有半截正文时用"接着写"指令',
      withPartial.last['content'] == kContinuationInstruction);

  final emptyPartial = ReplyCompleter.buildRetryMessages(
    baseMessages: base,
    partial: '',
  );
  check('没有正文时不注入空的 assistant 轮次',
      !emptyPartial.any((m) => m['role'] == 'assistant'));
  check('没有正文时用"重试"指令而不是"接着写"',
      emptyPartial.last['content'] == kEmptyReplyRetryInstruction);
  check('重试指令不说"接着写"（根本没有中断处）',
      !kEmptyReplyRetryInstruction.contains('接着'));
  check('重试指令要求直接从正文开始',
      kEmptyReplyRetryInstruction.contains('直接从正文开始'));
  check('空串绝不会进入任何一条消息',
      emptyPartial.every((m) => (m['content'] as String).trim().isNotEmpty));

  final whitespacePartial = ReplyCompleter.buildRetryMessages(
    baseMessages: base,
    partial: '   \n  ',
  );
  check('只有空白也算没有正文',
      !whitespacePartial.any((m) => m['role'] == 'assistant'));

  // 兜底文案必须走 error 种类，不能伪装成她的台词（这里只锁住文案本身；
  // 种类隔离由 test/library_session_test.dart 覆盖）。
  check('空回复的提示不是一句"她会说的话"',
      !kEmptyReplyNotice.contains('模型') && kEmptyReplyNotice.contains('再说一次'));

  print('');
  if (_failures == 0) {
    print('全部通过。');
  } else {
    print('$_failures 项失败。');
  }
}
