import 'key_value_store.dart';

class LocalStore implements KeyValueStore {
  @override
  String? read(String key) => null;

  @override
  void write(String key, String value) {}

  @override
  void delete(String key) {}
}
