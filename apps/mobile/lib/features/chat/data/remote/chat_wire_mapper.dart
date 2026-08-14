import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

abstract final class ChatWireMapper {
  static ChatMessage message(Map<String, dynamic> json) => ChatMessage(
    clientId: json['client_id'] as String,
    serverId: json['id'] as String?,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    content: json['content'] as String,
    localCreatedAt: DateTime.parse(json['created_at'] as String).toLocal(),
    serverCreatedAt: DateTime.parse(json['created_at'] as String).toLocal(),
    sequence: json['sequence'] as int,
    status: ChatMessageStatus.values.byName(json['status'] as String),
  );

  static ChatConversation conversation(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'] as String,
        otherUserId: json['other_user_id'] as String,
        otherDisplayName: json['other_display_name'] as String,
        lastMessage: json['last_message'] == null
            ? null
            : message(Map<String, dynamic>.from(json['last_message'] as Map)),
        lastReadSequence: json['last_read_sequence'] as int? ?? 0,
        lastMessageSequence: json['last_message_sequence'] as int? ?? 0,
        unreadCount: json['unread_count'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  static ChatUser user(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
  );
}
