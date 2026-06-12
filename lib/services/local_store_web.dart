import 'dart:html' as html;

class LocalStore {
  static const _prefix = 'beyond_time:';

  String? read(String key) {
    try {
      return html.window.localStorage['$_prefix$key'];
    } catch (_) {
      return null;
    }
  }

  void write(String key, String value) {
    try {
      html.window.localStorage['$_prefix$key'] = value;
    } catch (_) {
      // Browser storage may be unavailable in private modes.
    }
  }

  void delete(String key) {
    try {
      html.window.localStorage.remove('$_prefix$key');
    } catch (_) {
      // Ignore local cleanup failures.
    }
  }
}
