import 'chat_message.dart';

class OutboxMessage {
  const OutboxMessage({
    required this.message,
    required this.attempts,
    required this.nextAttemptAt,
  });
  final ChatMessage message;
  final int attempts;
  final DateTime nextAttemptAt;
}
