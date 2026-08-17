import 'chat_message.dart';

enum ChatMessageMutationKind { edit, delete }

class ChatMessageMutation {
  const ChatMessageMutation({
    required this.operationId,
    required this.message,
    required this.kind,
    required this.content,
    required this.attempts,
    required this.nextAttemptAt,
  });

  final String operationId;
  final ChatMessage message;
  final ChatMessageMutationKind kind;
  final String content;
  final int attempts;
  final DateTime nextAttemptAt;
}
