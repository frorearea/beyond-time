import '../lib/services/time_context.dart';

int _failures = 0;

void check(String name, bool condition) {
  if (condition) {
    print('PASS: $name');
  } else {
    _failures++;
    print('FAIL: $name');
  }
}

void section(String title) => print('\n=== $title ===');

void main() {
  final now = DateTime(2026, 11, 9, 21, 32);

  section('什么时候不注入');
  check('没有上一次记录 → 不注入', TimeContext.build(now: now, lastTalk: null) == null);
  check('刚说完一分钟 → 不注入',
      TimeContext.build(now: now, lastTalk: now.subtract(const Duration(minutes: 1))) == null);
  check('同一场对话过了三小时 → 不注入',
      TimeContext.build(now: now, lastTalk: now.subtract(const Duration(hours: 3))) == null);
  check('刚好四小时就注入',
      TimeContext.build(now: now, lastTalk: now.subtract(const Duration(hours: 4))) != null);

  section('注入的内容');
  final twoDays = TimeContext.build(
    now: now,
    lastTalk: DateTime(2026, 11, 7, 20, 28),
  );
  check('写明现在', twoDays != null && twoDays.contains('现在是 2026-11-09 21:32'));
  check('写明星期', twoDays != null && twoDays.contains('周一'));
  check('写明上次说话的时间', twoDays != null && twoDays.contains('2026-11-07 20:28'));
  check('写明隔了多久', twoDays != null && twoDays.contains('隔了两天'));
  check('标明只是事实、不必主动提起',
      twoDays != null && twoDays.contains('只作参考，不必主动提起'));

  section('间隔的说法');
  check('大半天', TimeContext.describeGap(const Duration(hours: 6)) == '大半天');
  check('一天', TimeContext.describeGap(const Duration(hours: 30)) == '一天');
  check('两天', TimeContext.describeGap(const Duration(days: 2)) == '两天');
  check('具体天数', TimeContext.describeGap(const Duration(days: 5)) == '5 天');
  check('一周多', TimeContext.describeGap(const Duration(days: 9)) == '一周多');
  check('半个多月', TimeContext.describeGap(const Duration(days: 20)) == '半个多月');
  check('一个多月', TimeContext.describeGap(const Duration(days: 40)) == '一个多月');
  check('两个多月', TimeContext.describeGap(const Duration(days: 70)) == '两个多月');

  section('时间戳格式');
  check('补零', TimeContext.stamp(DateTime(2026, 1, 5, 7, 3)) == '2026-01-05 07:03');
  check('周日', TimeContext.weekdayOf(DateTime(2026, 11, 8)) == '周日');
  check('周一', TimeContext.weekdayOf(DateTime(2026, 11, 9)) == '周一');

  print('');
  if (_failures == 0) {
    print('全部通过。');
  } else {
    print('$_failures 项失败。');
  }
}
