import 'dart:developer' as developer;

abstract final class AppLogger {
  static void auth(String message, {Map<String, Object?> fields = const {}}) {
    _write('help.auth', message, fields);
  }

  static void realtime(
    String message, {
    Map<String, Object?> fields = const {},
  }) {
    _write('help.realtime', message, fields);
  }

  static void _write(
    String name,
    String message,
    Map<String, Object?> fields,
  ) => developer.log(
    '$message ${fields.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
    name: name,
  );
}
