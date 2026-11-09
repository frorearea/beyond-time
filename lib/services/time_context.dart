/// 时间事实：只有在"隔了一阵子又开始说话"的时候才注入。
///
/// 为什么需要它：消息本身不带时间戳（存档 v3 只有 `role` / `content`），上下文里
/// 也没有"现在"。于是她没有办法知道两天过去了——2026-11-09 的存档里，第二条
/// 会话的 11 条回复有 9 条说"今晚"，还把两天前那句"一团恐惧"当成几分钟前接下去。
///
/// 做成纯函数是为了能零依赖单测：不碰 flutter、不碰存储、不读时钟。
class TimeContext {
  /// 小于这个间隔就当同一场对话，什么都不注入（避免每轮都提醒她时间）。
  static const Duration minimumGap = Duration(hours: 4);

  /// 生成注入用的时间事实；间隔太短时返回 null。
  ///
  /// [lastTalk] 是上一次说话的时间（`StoreHelper.loadLastVisit`，每次成功发言后更新）。
  static String? build({
    required DateTime now,
    DateTime? lastTalk,
  }) {
    if (lastTalk == null) return null;
    final gap = now.difference(lastTalk);
    if (gap < minimumGap) return null;
    return '时间事实（只作参考，不必主动提起）：\n'
        '现在是 ${stamp(now)}，${weekdayOf(now)}。\n'
        '你们上一次说话是 ${stamp(lastTalk)}，中间隔了${describeGap(gap)}。';
  }

  /// `2026-11-09 21:32`
  static String stamp(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} $hour:$minute';
  }

  static String weekdayOf(DateTime time) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[(time.toLocal().weekday - 1) % 7];
  }

  /// 把间隔说成人话。刻意粗一点——她不需要精确到分钟。
  static String describeGap(Duration gap) {
    final days = gap.inDays;
    if (days >= 60) return '两个多月';
    if (days >= 30) return '一个多月';
    if (days >= 14) return '半个多月';
    if (days >= 7) return '一周多';
    if (days >= 3) return '$days 天';
    if (days >= 2) return '两天';
    if (days >= 1) return '一天';
    return '大半天';
  }

  static String two(int value) => value.toString().padLeft(2, '0');
}
