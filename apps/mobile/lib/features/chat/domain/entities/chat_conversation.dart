import 'chat_message.dart';

enum ChatConversationStatus { pending, accepted, declined }

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
    this.otherOnline = false,
    this.otherLastSeenAt,
    this.status = ChatConversationStatus.accepted,
    this.requestedByMe = false,
  });

  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int lastReadSequence;
  final int lastMessageSequence;
  final DateTime updatedAt;
  final bool otherOnline;
  final DateTime? otherLastSeenAt;
  final ChatConversationStatus status;
  final bool requestedByMe;

  bool get canMessage => status == ChatConversationStatus.accepted;
}

enum ChatUserRole { customer, provider }

class ChatUser {
  const ChatUser({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final ChatUserRole role;
}
