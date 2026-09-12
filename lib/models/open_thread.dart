/// 一件"未决之事"的状态。
enum ThreadStatus {
  /// 来访者提过、但还没有下文的悬案。
  open,

  /// 已有结果。
  resolved;

  static ThreadStatus fromName(Object? name) =>
      name?.toString() == resolved.name ? resolved : open;
}

/// 未决之事：来访者自己说过、但还没有下文的牵挂。
///
/// 这是「她记得你的未决之事」的载体（C3）。与 [LibraryMemoryItem] 的区别：
/// 记忆是"关于你的稳定事实"，未决之事是"一件还没落地的事"——它有状态，
/// 会被解决，因此能在下次推门时变成那句「那扇门后来怎么样了」。
class OpenThread {
  const OpenThread({
    required this.id,
    required this.topic,
    required this.detail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 话题短语，需要能自然嵌进一句话里（例：「保研还是去海外」）。
  static const int maxTopicLength = 24;

  /// 补充说明，可以长一些。
  static const int maxDetailLength = 90;

  /// 同时保留的未决之世上限，防止书架被悬案塞满。
  static const int maxThreads = 12;

  /// 已解决的事保留多久（用于「那件事你已经有答案了」）。
  static const Duration resolvedRetention = Duration(days: 30);

  final String id;
  final String topic;
  final String detail;
  final ThreadStatus status;
  final String createdAt;
  final String updatedAt;

  bool get isOpen => status == ThreadStatus.open;

  DateTime? get updatedAtTime => DateTime.tryParse(updatedAt);

  OpenThread copyWith({
    String? topic,
    String? detail,
    ThreadStatus? status,
    String? updatedAt,
  }) {
    return OpenThread(
      id: id,
      topic: topic ?? this.topic,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否还在"最近"的窗口内，用于挑选回归问候的题材。
  bool isFreshWithin(Duration window, {DateTime? now}) {
    final time = updatedAtTime;
    if (time == null) return false;
    return (now ?? DateTime.now()).difference(time) <= window;
  }

  Map<String, String> toJson() => {
        'id': id,
        'topic': topic,
        'detail': detail,
        'status': status.name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static OpenThread? tryFromJson(Map<String, dynamic> json) {
    final topic = (json['topic']?.toString() ?? '').trim();
    if (topic.isEmpty) return null;
    final createdAt = json['createdAt']?.toString().trim();
    final updatedAt = json['updatedAt']?.toString().trim();
    return OpenThread(
      id: (json['id']?.toString().trim().isNotEmpty ?? false)
          ? json['id'].toString().trim()
          : _newId(),
      topic: _clamp(topic, maxTopicLength),
      detail: _clamp((json['detail']?.toString() ?? '').trim(), maxDetailLength),
      status: ThreadStatus.fromName(json['status']),
      createdAt: (createdAt?.isNotEmpty ?? false)
          ? createdAt!
          : DateTime.now().toIso8601String(),
      updatedAt: (updatedAt?.isNotEmpty ?? false)
          ? updatedAt!
          : DateTime.now().toIso8601String(),
    );
  }

  static String _clamp(String value, int limit) =>
      value.length > limit ? value.substring(0, limit) : value;

  /// 不引入 uuid 依赖：微秒时间戳在同一会话里已经足够唯一。
  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static String newId() => _newId();
}

/// 记忆整理模型提出的候选未决之事（还没有和现有列表合并）。
class OpenThreadDraft {
  const OpenThreadDraft({required this.topic, this.detail = ''});

  final String topic;
  final String detail;
}
