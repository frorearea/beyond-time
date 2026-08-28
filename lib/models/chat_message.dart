class ChatMessage {
  const ChatMessage({required this.role, required this.content, this.isAmbient = false});

  final String role;
  final String content;

  /// 环境台词标记：不进入对话存档，同一时刻页面至多保留一条。
  final bool isAmbient;

  Map<String, String> toJson() => {'role': role, 'content': content};

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() == 'assistant' ? 'assistant' : 'user',
      content: json['content']?.toString() ?? '',
    );
  }
}