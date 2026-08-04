import '../lib/models/user_profile.dart';

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
  // 1. Basic observation: topics, moods, address terms
  final profile = UserProfile();
  profile.observe('艾蕾塔，我今天加班到很晚，好累啊。');
  profile.observe('工作上的压力让我有点焦虑，但我还能撑住。');
  profile.observe('最近在读一本小说，很喜欢。');

  check('总消息数 = 3', profile.totalUserMessages == 3);
  check('话题-工作被记录', (profile.topics['工作'] ?? 0) > 0);
  check('话题-书籍被记录', (profile.topics['书籍'] ?? 0) > 0);
  check('情绪-疲惫被记录', (profile.moods['疲惫'] ?? 0) > 0);
  check('情绪-焦虑被记录', (profile.moods['焦虑'] ?? 0) > 0);
  check('称呼-艾蕾塔被记录', profile.addressTerms.contains('艾蕾塔'));
  check('初识阶段（消息少）', profile.familiarityLevel == '初识');

  // 2. 上下文文本生成（长度偏好不再注入）
  final contextText = profile.toContextText();
  check('上下文包含相识天数', contextText.contains('相识'));
  check('上下文包含话题', contextText.contains('工作'));
  check('上下文包含称呼', contextText.contains('艾蕾塔'));
  check('上下文不包含复述条目字样', !contextText.contains('以下是图书馆记忆'));
  check('不再出现回复长度限制', !contextText.contains('轻短') && !contextText.contains('展开'));
  print('--- toContextText 输出示例 ---');
  print(contextText);
  print('-------------------------------');

  // 3b. meaningful 阈值
  final fresh = UserProfile();
  fresh.observe('你好');
  fresh.observe('嗯');
  check('2 条消息时还不 meaningful', !fresh.isMeaningful);
  fresh.observe('再聊聊');
  check('3 条消息时 meaningful', fresh.isMeaningful);

  // 4. 序列化往返
  final json = profile.toJson();
  final restored = UserProfile.fromJson(json);
  check('序列化后消息数一致', restored.totalUserMessages == profile.totalUserMessages);
  check('序列化后话题一致', restored.topics['工作'] == profile.topics['工作']);
  check('序列化后称呼一致', restored.addressTerms.length == profile.addressTerms.length);

  // 5. 天数统计 touch()
  final visitor = UserProfile();
  final yesterday = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
  visitor.firstVisit = yesterday;
  visitor.lastActive = yesterday;
  visitor.touch();
  check('touch 后相识天数 >= 3', visitor.acquaintanceDays >= 3);
  check('touch 后 lastActive 已更新', visitor.lastActive != yesterday);

  // 6. 亲近度随相处增长
  final veteran = UserProfile(totalUserMessages: 120);
  check('120 轮对话 -> 熟悉', veteran.familiarityLevel == '熟悉');
  final oldFriend = UserProfile(acquaintanceDays: 35);
  check('35 天 -> 深交', oldFriend.familiarityLevel == '深交');
  final close = UserProfile(acquaintanceDays: 9);
  check('9 天 -> 亲近', close.familiarityLevel == '亲近');

  print('');
  if (_failures == 0) {
    print('全部测试通过');
  } else {
    print('$_failures 项测试失败');
  }
}
