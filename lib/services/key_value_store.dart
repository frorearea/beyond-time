/// 键值存储接口。
///
/// [LocalStore] 是平台实现（Web 走 localStorage，桌面走 APPDATA 下的文件）。
/// 把它抽成接口只有两个目的：让 [StoreHelper] / [LibrarySession] 可以在测试里
/// 注入内存实现，**不必碰用户真实的 app 数据目录**；以及让"存储坏了"这件事
/// 有一个明确的边界。
abstract class KeyValueStore {
  String? read(String key);

  void write(String key, String value);

  void delete(String key);
}

/// 内存实现：给单测与 widget 测试用。
class InMemoryStore implements KeyValueStore {
  InMemoryStore([Map<String, String>? seed])
      : _values = {...?seed};

  final Map<String, String> _values;

  /// 便于测试断言"到底写了什么"。
  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }

  @override
  void delete(String key) {
    _values.remove(key);
  }
}
