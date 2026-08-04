import 'dart:convert';

class UserProfile {
  int totalUserMessages;
  int acquaintanceDays;
  double avgMessageLength;
  String? firstVisit;
  String? lastActive;
  final Map<String, int> topics;
  final Map<String, int> moods;
  final List<String> addressTerms;

  UserProfile({
    this.totalUserMessages = 0,
    this.acquaintanceDays = 0,
    this.avgMessageLength = 0,
    this.firstVisit,
    this.lastActive,
    Map<String, int>? topics,
    Map<String, int>? moods,
    List<String>? addressTerms,
  })  : topics = topics ?? {},
        moods = moods ?? {},
        addressTerms = addressTerms ?? [];

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      totalUserMessages: (json['totalUserMessages'] as num?)?.toInt() ?? 0,
      acquaintanceDays: (json['acquaintanceDays'] as num?)?.toInt() ?? 0,
      avgMessageLength:
          (json['avgMessageLength'] as num?)?.toDouble() ?? 0,
      firstVisit: json['firstVisit']?.toString(),
      lastActive: json['lastActive']?.toString(),
      topics: _countMap(json['topics']),
      moods: _countMap(json['moods']),
      addressTerms: (json['addressTerms'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'totalUserMessages': totalUserMessages,
        'acquaintanceDays': acquaintanceDays,
        'avgMessageLength': avgMessageLength,
        'firstVisit': firstVisit,
        'lastActive': lastActive,
        'topics': topics,
        'moods': moods,
        'addressTerms': addressTerms,
      };

  static Map<String, int> _countMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0));
  }

  static const Map<String, List<String>> _topicKeywords = {
    '工作': ['工作', '上班', '加班', '同事', '老板', '项目', '会议', '任务', '面试', '辞职'],
    '学习': ['学习', '考试', '论文', '作业', '课程', '复习', '考研', '作业'],
    '游戏': ['游戏', '打游戏', '副本', 'steam', '原神', '王者', '通关', 'switch'],
    '动漫': ['动漫', '漫画', '番剧', '二次元', '补番', 'op'],
    '书籍': ['书', '小说', '诗集', '读完', '书页', '翻到'],
    '音乐': ['音乐', '歌', '旋律', '听曲', '钢琴', '吉他'],
    '影视': ['电影', '剧', '片子', '影院', '追剧'],
    '创作': ['写', '画', '创作', '灵感', '作品', '草稿', '练字'],
    '爱情': ['喜欢的人', '恋爱', '分手', '对象', '心动', '暗恋', '告白'],
    '家庭': ['家人', '父母', '妈妈', '爸爸', '家里', '母亲', '父亲'],
    '朋友': ['朋友', '聚会', '社交', '同学', '同事聚餐'],
    '回忆': ['以前', '从前', '小时候', '想起', '回忆', '过去', '曾经'],
    '梦想': ['梦想', '愿望', '想成为', '理想', '目标'],
    '哲学': ['人生', '意义', '存在', '死亡', '自由', '宇宙', '命运'],
    '孤独': ['孤独', '一个人', '寂寞', '没人', '独处'],
  };

  static const Map<String, List<String>> _moodKeywords = {
    '疲惫': ['累', '疲惫', '困', '倦', '撑不住', '透支'],
    '焦虑': ['焦虑', '担心', '烦', '压力', '紧张', '害怕', '不安'],
    '难过': ['难过', '伤心', '哭', '失落', '崩溃', '委屈', '心碎'],
    '孤独': ['孤独', '寂寞', '没人', '一个人'],
    '开心': ['开心', '高兴', '喜欢', '笑', '治愈', '温暖', '幸福'],
    '平静': ['平静', '安静', '还好', '没什么', '就这样'],
    '迷茫': ['迷茫', '不知道怎么办', '方向', '困惑', '想不通'],
  };

  void observe(String userText) {
    final text = userText.toLowerCase();
    totalUserMessages += 1;

    final prevAvg = avgMessageLength * (totalUserMessages - 1);
    avgMessageLength = (prevAvg + userText.length) / totalUserMessages;

    _topicKeywords.forEach((topic, keywords) {
      var hits = 0;
      for (final keyword in keywords) {
        if (text.contains(keyword)) hits++;
      }
      if (hits > 0) {
        topics[topic] = (topics[topic] ?? 0) + hits;
      }
    });

    _moodKeywords.forEach((mood, keywords) {
      var hits = 0;
      for (final keyword in keywords) {
        if (text.contains(keyword)) hits++;
      }
      if (hits > 0) {
        moods[mood] = (moods[mood] ?? 0) + hits;
      }
    });

    const addressKeywords = ['艾蕾塔', '塔塔', '魔女', '馆长', '小姐', '老师'];
    for (final term in addressKeywords) {
      if (text.contains(term) && !addressTerms.contains(term)) {
        addressTerms.add(term);
      }
    }
  }

  void touch() {
    final now = DateTime.now();
    firstVisit ??= now.toIso8601String();
    final last = lastActive == null ? null : DateTime.tryParse(lastActive!);
    if (last != null) {
      final days = now.difference(last).inDays;
      if (days >= 1) {
        acquaintanceDays += days;
      }
    }
    lastActive = now.toIso8601String();
  }

  String get familiarityLevel {
    if (acquaintanceDays >= 30 || totalUserMessages >= 300) return '深交';
    if (acquaintanceDays >= 14 || totalUserMessages >= 100) return '熟悉';
    if (acquaintanceDays >= 7 || totalUserMessages >= 40) return '亲近';
    return '初识';
  }

  bool get isMeaningful => totalUserMessages >= 3;

  List<String> _topCounts(Map<String, int> counts, {int limit = 4}) {
    final entries = counts.entries
        .where((entry) => entry.value >= 2)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((entry) => entry.key).toList();
  }

  String toContextText() {
    final buffer = StringBuffer();
    buffer.write(
        '以下是你（艾蕾塔）对这位来访者日积月累的了解，来自你们每一次交谈。把它当作你与对方相处的真实记忆，自然地融入对话，绝对不要复述或总结这些条目本身：');
    buffer.write('\n- 你们相识约 $acquaintanceDays 天，谈过 $totalUserMessages 轮话。');

    final topTopics = _topCounts(topics);
    if (topTopics.isNotEmpty) {
      buffer.write('\n- 他/她常与你聊的话题：${topTopics.join('、')}。');
    }
    final topMoods = _topCounts(moods, limit: 3);
    if (topMoods.isNotEmpty) {
      buffer.write('\n- 他/她的心绪常在：${topMoods.join('、')}。');
    }
    if (addressTerms.isNotEmpty) {
      buffer.write('\n- 他/她这样称呼你：${addressTerms.join('、')}。');
    }

    switch (familiarityLevel) {
      case '初识':
        buffer.write('\n- 你们还在互相认识，保持礼貌而克制的亲切，不必过度熟络。');
      case '亲近':
        buffer.write('\n- 你们已经比较熟悉，可以偶尔调侃、放松一些。');
      case '熟悉':
        buffer.write('\n- 你们已很熟悉，可以像老朋友一样自然，偶尔流露想念。');
      case '深交':
        buffer.write('\n- 你们已是深交，彼此了解甚深，你的语气里带着岁月沉淀的温柔。');
    }
    return buffer.toString();
  }
}

String encodeUserProfile(UserProfile profile) => jsonEncode(profile.toJson());