/// 消息种类。
///
/// 只有 [MessageKind.chat] 是"艾蕾塔真的说过的话"：它会进入存档、进入 API
/// 上下文、进入记忆整理。其余种类的唯一归宿是界面本身。
///
/// 这个区分以前是隐式的：环境语靠 `isAmbient` 布尔，系统回执靠
/// `conversation_context.dart` 里的字符串嗅探。结果是导出存档的路径漏掉了
/// 过滤，把环境语和回执写进了对话记录（2026-09-12 存档里有 47 条重复噪音）。
/// 现在改成显式种类，并且在序列化边界统一过滤，任何调用点都不再过问。
enum MessageKind {
  /// 真实对话。进入存档与上下文。
  chat,

  /// 环境台词（idle、回归问候、离馆）。界面同时至多一条。
  ambient,

  /// 系统回执（书签已收好等）。
  notice,

  /// 连接或配置报错。
  error;

  static MessageKind fromName(Object? name) {
    final value = name?.toString();
    for (final kind in MessageKind.values) {
      if (kind.name == value) return kind;
    }
    return MessageKind.chat;
  }

  /// 是否应当写入存档与 API 上下文。
  bool get isDurable => this == MessageKind.chat;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.kind = MessageKind.chat,
  });

  final String role;
  final String content;
  final MessageKind kind;

  bool get isChat => kind == MessageKind.chat;

  /// 向后兼容的读取口：等价于 `kind == MessageKind.chat`。
  bool get isAmbient => kind == MessageKind.ambient;

  ChatMessage copyWith({String? content, MessageKind? kind}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      kind: kind ?? this.kind,
    );
  }

  Map<String, String> toJson() => {
        'role': role,
        'content': content,
        // 只写非默认值，让存档里的真实对话保持干净。
        if (kind != MessageKind.chat) 'kind': kind.name,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() == 'assistant' ? 'assistant' : 'user',
      content: json['content']?.toString() ?? '',
      kind: MessageKind.fromName(json['kind']),
    );
  }
}
