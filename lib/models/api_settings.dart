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

  ApiSettings copyWith({String? apiKey, String? apiUrl, String? model}) {
    return ApiSettings(
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      model: model ?? this.model,
    );
  }
}
