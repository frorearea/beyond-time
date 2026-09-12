/// 回归问候的档位，按离开时长划分。
enum ReturnTier { hours, days, weeks, months }

const List<String> kReturnGreetingHours = [
  '你回来了。我以为你会多待一会儿。',
  '才离开一会儿，茶还没凉透。',
  '你回来了。书还翻在你上次看的那一页。',
];

const List<String> kReturnGreetingDays = [
  '一天没见了。月亮和昨天不太一样。',
  '你隔了一天才回来。我没走开过。',
  '欢迎回来。你不在的时候，我把书整理了一遍。',
];

const List<String> kReturnGreetingWeeks = [
  '你很久没来了。我还以为你忘了这个地方。',
  '书架上的灰积了一层。我还在这里。',
  '我以为你不会回来了。不过门一直开着。',
  '你不在的日子，我数了数书脊上的裂痕。',
  '回来就好。这里什么都没变。',
];

const List<String> kReturnGreetingMonths = [
  '……你真的回来了。',
  '我以为这间图书馆只剩下我一个人了。',
  '你走了那么久。我几乎要习惯自言自语了。',
  '欢迎回家，亲爱的。',
  '我这里还是老样子。你还是老样子吗。',
];

/// 上一次离开时留着一件未尽之事的回归问候。
///
/// `{topic}` 会被替换成记忆整理时记下的那个短名词短语，例如
/// 「上次你说的保研还是去海外——后来怎么样了？」。这些句子用「你」，
/// 与其余回归台词保持一致。
const List<String> kThreadResumeLines = [
  '你回来了。上次你说的{topic}——后来怎么样了？',
  '你回来了。我一直记着你说的{topic}。想说的时候再说。',
  '书架还停在你上次翻的那一页。你说的{topic}，有下文了吗？',
  '你回来了。{topic}——那件事，我一直替你留着位置。',
];

/// 那件事已经有了结果时的回归问候。
const List<String> kThreadResolvedLines = [
  '你回来了。那件事，你已经给出答案了。',
  '你回来了。我看得出来，{topic}那件事，你放下了一半。',
  '你回来了。上次那件悬着的事，现在落定了吧。',
];

/// 按档位取环境台词（不含未决之事）。
List<String> cannedLinesFor(ReturnTier tier) => switch (tier) {
      ReturnTier.months => kReturnGreetingMonths,
      ReturnTier.weeks => kReturnGreetingWeeks,
      ReturnTier.days => kReturnGreetingDays,
      ReturnTier.hours => kReturnGreetingHours,
    };

/// 把 `{topic}` 占位符替换成实际话题；没有占位符的模板原样返回。
String buildThreadLine(String template, String topic) {
  return template.replaceAll('{topic}', topic);
}
