import 'dart:developer' as developer;

abstract final class AppLogger {
  static void realtime(
    String message, {
    Map<String, Object?> fields = const {},
  }) {
    developer.log(
      '$message ${fields.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
      name: 'help.realtime',
    );
  }
}
