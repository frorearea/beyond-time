import 'dart:convert';

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