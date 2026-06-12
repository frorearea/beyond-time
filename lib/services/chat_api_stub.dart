class ChatApiException implements Exception {
  ChatApiException(this.statusCode, this.responseText);

  final int statusCode;
  final String responseText;
}

class ChatApiClient {
  Future<String> requestStreamingReply({
    required Map<String, dynamic> payload,
    required String apiKey,
    required String apiUrl,
    required void Function(String reply) onReply,
  }) async {
    throw UnsupportedError('当前平台暂不支持网络请求。');
  }
}
