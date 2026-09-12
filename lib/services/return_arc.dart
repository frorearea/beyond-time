import 'dart:math' as math;

import '../data/return_lines.dart';
import '../models/open_thread.dart';
import 'thread_book.dart';

/// 回归情感弧：离开多久 → 说什么第一句话。
///
/// C3 的落点在这里。以前只有 3h/1d/1w/1m 四档固定台词，回来听到的永远是
/// 「月亮和昨天不太一样」这类泛泛的环境语。现在只要离开超过一天，它就优先
/// 把上次记下的那件未尽之事端出来：「上次你说的保研还是去海外——后来怎么样了？」
///
/// 纯逻辑，不 import flutter，可以零依赖单测。
class ReturnArc {
  const ReturnArc([this._book = const ThreadBook()]);

  final ThreadBook _book;

  /// 刚离开三小时以内不问候：太近了，说什么都显得刻意。
  static const Duration minimumGap = Duration(hours: 3);

  /// 未决之事的新鲜窗口。太久没提起的悬案不再当作问候题材。
  static const Duration threadFreshness = Duration(days: 90);

  static ReturnTier? tierFor(Duration elapsed) {
    if (elapsed.inDays >= 30) return ReturnTier.months;
    if (elapsed.inDays >= 7) return ReturnTier.weeks;
    if (elapsed.inDays >= 1) return ReturnTier.days;
    if (elapsed.inHours >= 3) return ReturnTier.hours;
    return null;
  }

  /// 计算这次推门时该说的第一句话。
  ///
  /// [random] 可注入以便测试固定结果。
  String greetingFor({
    required ReturnTier tier,
    required List<OpenThread> threads,
    required DateTime now,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();

    // 短档位（三小时以上、一天以内）仍然只说环境语：
    // 刚走开一会儿就追问人生大事，会很奇怪。
    if (tier != ReturnTier.hours) {
      final pending = _book.pickForGreeting(threads,
          now: now, freshness: threadFreshness);
      if (pending != null) {
        final template =
            (List<String>.of(kThreadResumeLines)..shuffle(rng)).first;
        return buildThreadLine(template, pending.topic);
      }
      final settled = _book.pickResolvedForGreeting(threads, now: now);
      if (settled != null) {
        final template =
            (List<String>.of(kThreadResolvedLines)..shuffle(rng)).first;
        return buildThreadLine(template, settled.topic);
      }
    }

    return (List<String>.of(cannedLinesFor(tier))..shuffle(rng)).first;
  }
}
