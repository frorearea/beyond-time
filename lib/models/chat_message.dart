class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() == 'assistant' ? 'assistant' : 'user',
      content: json['content']?.toString() ?? '',
    );
  }
}
