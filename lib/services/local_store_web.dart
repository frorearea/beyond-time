import 'dart:html' as html;

import 'key_value_store.dart';

class LocalStore implements KeyValueStore {
  static const _prefix = 'beyond_time:';

  @override
  String? read(String key) {
    try {
      return html.window.localStorage['$_prefix$key'];
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      html.window.localStorage['$_prefix$key'] = value;
    } catch (_) {
      // Browser storage may be unavailable in private modes.
    }
  }

  @override
  void delete(String key) {
    try {
      html.window.localStorage.remove('$_prefix$key');
    } catch (_) {
      // Ignore local cleanup failures.
    }
  }
}
