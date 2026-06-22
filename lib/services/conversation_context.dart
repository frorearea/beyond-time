import 'dart:convert';
import 'dart:math' as math;

import '../models/chat_message.dart';
import '../models/library_memory_item.dart';

class ConversationContext {
  const ConversationContext();

  List<Map<String, String>> buildMessages({
    required String persona,
    required List<ChatMessage> messages,
    required List<LibraryMemoryItem> memories,
    String? extraSystemInstruction,
  }) {
    final visibleMessages = messages
        .where((message) => message.content.trim().isNotEmpty)
        .where((message) => !isBookmarkNoticeMessage(message))
        .toList();
    final history = visibleMessages
        .skip(math.max(0, visibleMessages.length - 80))
        .map((message) => {
              'role': message.role == 'assistant' ? 'assistant' : 'user',
              'content': message.content,
            })
        .toList();
    final recentMemories = memories
        .where((memory) => memory.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .toList();

    return [
      {'role': 'system', 'content': persona},
      if (recentMemories.isNotEmpty)
        {
          'role': 'system',
          'content':
              '以下是图书馆记忆，包含来访者手动收藏的句子，以及艾蕾塔谨慎整理出的喜好、压力、热爱与困扰。把它们当作轻柔背景，只在自然合适时呼应，不要像系统总结一样复述：\n${recentMemories.map((memory) => '- [${memory.category}] ${memory.content}${memory.evidence.trim().isEmpty ? '' : '（依据：${memory.evidence}）'}').join('\n')}',
        },
      {
        'role': 'system',
        'content':
            '保持对话感和艾蕾塔的角色气质。优先自然回应来访者当前这句话，不要输出 HTML 标签或 Markdown 换行标签；需要换行时直接使用普通换行，绝对不要写 <br>。',
      },
      if (extraSystemInstruction != null &&
          extraSystemInstruction.trim().isNotEmpty)
        {'role': 'system', 'content': extraSystemInstruction.trim()},
      ...history,
    ];
  }

  String cleanReply(String text) {
    return text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String friendlyHttpError(int status, String responseText) {
    final details = _extractApiErrorMessage(responseText);
    return switch (status) {
      400 => '请求格式不对。请检查模型名称、API 地址和参数设置。$details',
      401 => 'API Key 没通过验证。请检查右上角设置里的密钥。$details',
      402 => '账号余额或额度不足。请检查 DeepSeek 控制台的余额、充值状态或当前模型是否可用。',
      403 => '接口拒绝访问。请检查 API Key 权限、模型权限或账号状态。$details',
      404 => 'API 地址或模型不存在。请检查右上角设置里的 API 地址和模型名。$details',
      429 => '请求太频繁或额度达到上限。稍等一会儿，或检查账号限额。$details',
      >= 500 => '模型服务端暂时出错。稍后再试，或者换一个模型。$details',
      _ => 'HTTP $status。请检查 API 设置或上游服务状态。$details',
    };
  }

  bool isBookmarkNoticeMessage(ChatMessage message) {
    if (message.role != 'assistant') return false;
    final content = message.content.trim();
    return content.contains('书签') &&
        (content.contains('图书馆') ||
            content.contains('收进') ||
            content.contains('夹进') ||
            content.contains('收好'));
  }

  String _extractApiErrorMessage(String responseText) {
    final cleaned = responseText
        .split('\n')
        .where((line) => !line.trimLeft().startsWith(':'))
        .join('\n')
        .trim();
    if (cleaned.isEmpty) return '';
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return '（$message）';
        }
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return '（$message）';
      }
    } catch (_) {
      final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ');
      if (compact.length <= 120) return '（$compact）';
    }
    return '';
  }
}
