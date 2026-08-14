import 'chat_message.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastReadSequence = 0,
    this.lastMessageSequence = 0,
  });

  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int lastReadSequence;
  final int lastMessageSequence;
  final DateTime updatedAt;
}

class ChatUser {
  const ChatUser({required this.id, required this.displayName});
  final String id;
  final String displayName;
}
