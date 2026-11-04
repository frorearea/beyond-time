import '../config.dart';

/// API 连接设置。以前散落在三个 TextEditingController 里，被发送、记忆整理、
/// 塔罗等多条路径各自读取；现在收成一个值对象，由 [LibrarySession] 持有。
class ApiSettings {
  const ApiSettings({
    this.apiKey = '',
    this.apiUrl = kDefaultApiUrl,
    this.model = kDefaultModel,
  });

  final String apiKey;
  final String apiUrl;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  String get resolvedApiUrl =>
      apiUrl.trim().isEmpty ? kDefaultApiUrl : apiUrl.trim();

  String get resolvedModel => model.trim().isEmpty ? kDefaultModel : model.trim();

  /// 网页搜索地址。
  ///
  /// 从 `apiUrl` 推导：`…/chat/completions` → `…/v1/tools/search`。
  /// 自定义代理若也代理搜索，就把 apiUrl 指到那个域名，推导即可跟着走；
  /// 推导不出来时回落到官方地址。
  String get resolvedSearchUrl {
    final url = apiUrl.trim();
    if (url.isEmpty) return kDefaultSearchUrl;
    if (url.contains('/chat/completions')) {
      return url.replaceAll(RegExp(r'/chat/completions.*$'), '/v1/tools/search');
    }
    return kDefaultSearchUrl;
  }

  ApiSettings copyWith({String? apiKey, String? apiUrl, String? model}) {
    return ApiSettings(
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      model: model ?? this.model,
    );
  }
}
