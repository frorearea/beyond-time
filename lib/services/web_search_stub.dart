/// 当前平台不支持网页搜索。
class WebSearchException implements Exception {
  WebSearchException(this.statusCode, this.responseText);

  final int statusCode;
  final String responseText;
}

class WebSearchClient {
  Future<String> search({
    required String query,
    required String apiKey,
    required String searchUrl,
    required int count,
  }) async {
    throw UnsupportedError('当前平台暂不支持网页搜索。');
  }
}
