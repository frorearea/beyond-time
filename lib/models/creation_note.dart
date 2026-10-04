/// 来访者自己的创作：设定、故事名、片段、点子。
///
/// 与 [LibraryMemoryItem] 的区别：记忆是"关于来访者的描述"（第三人称、由艾蕾塔
/// 整理），这里是**来访者自己的东西**——原话、原名、原设定。图书馆不该只记住
/// 他的喜好，还要有个地方放他亲手写下的字。
///
/// 与 [OpenThread] 的区别：未决之事是"还没落地的事"，有状态、会被解决；
/// 创作稿是留下的作品，不会过期。
class CreationNote {
  const CreationNote({
    required this.id,
    required this.title,
    required this.kind,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 作品名或话题短语，需要能自然念出来（例：「红羽离笼记」）。
  static const int maxTitleLength = 24;

  /// 设定 / 片段的要点，可以长一些，但仍要能被一眼看完。
  static const int maxContentLength = 220;

  /// 同时保留的创作稿上限。
  static const int maxNotes = 12;

  /// 常见的创作类型，仅用于整理员输出时取值，不强制。
  static const List<String> kinds = ['设定', '故事', '游戏', '角色', '诗', '其他'];

  final String id;
  final String title;
  final String kind;
  final String content;
  final String createdAt;
  final String updatedAt;

  DateTime? get updatedAtTime => DateTime.tryParse(updatedAt);

  CreationNote copyWith({
    String? title,
    String? kind,
    String? content,
    String? updatedAt,
  }) {
    return CreationNote(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, String> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'content': content,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static CreationNote? tryFromJson(Map<String, dynamic> json) {
    final title = (json['title']?.toString() ?? '').trim();
    if (title.isEmpty) return null;
    final createdAt = json['createdAt']?.toString().trim();
    final updatedAt = json['updatedAt']?.toString().trim();
    final kind = (json['kind']?.toString() ?? '').trim();
    return CreationNote(
      id: (json['id']?.toString().trim().isNotEmpty ?? false)
          ? json['id'].toString().trim()
          : newId(),
      title: clamp(title, maxTitleLength),
      kind: kind.isEmpty ? '其他' : clamp(kind, 8),
      content: clamp((json['content']?.toString() ?? '').trim(), maxContentLength),
      createdAt: (createdAt?.isNotEmpty ?? false)
          ? createdAt!
          : DateTime.now().toIso8601String(),
      updatedAt: (updatedAt?.isNotEmpty ?? false)
          ? updatedAt!
          : DateTime.now().toIso8601String(),
    );
  }

  static String clamp(String value, int limit) =>
      value.length > limit ? value.substring(0, limit) : value;

  /// 不引入 uuid 依赖：微秒时间戳在同一会话里已经足够唯一。
  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

/// 记忆整理模型提出的候选创作稿（还没有和现有列表合并）。
class CreationDraft {
  const CreationDraft({
    required this.title,
    this.kind = '其他',
    this.content = '',
  });

  final String title;
  final String kind;
  final String content;
}
