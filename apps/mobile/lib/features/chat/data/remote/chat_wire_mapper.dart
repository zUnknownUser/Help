import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

abstract final class ChatWireMapper {
  static ChatMessage message(Map<String, dynamic> json) => ChatMessage(
    clientId: json['client_id'] as String,
    serverId: json['id'] as String?,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    content: json['content'] as String? ?? '',
    kind: ChatMessageKind.values.byName(json['kind'] as String? ?? 'text'),
    media: _media(json['media']),
    localCreatedAt: DateTime.parse(json['created_at'] as String).toLocal(),
    serverCreatedAt: DateTime.parse(json['created_at'] as String).toLocal(),
    editedAt: _date(json['edited_at']),
    deletedAt: _date(json['deleted_at']),
    sequence: json['sequence'] as int,
    version: json['version'] as int? ?? 1,
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
        otherOnline: json['other_online'] as bool? ?? false,
        otherLastSeenAt: _date(json['other_last_seen_at']),
        status: ChatConversationStatus.values.byName(
          json['status'] as String? ?? 'accepted',
        ),
        requestedByMe: json['requested_by_me'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  static ChatUser user(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    role: ChatUserRole.values.byName(json['role'] as String),
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;

  static ChatMedia? _media(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return ChatMedia(
      id: json['id'] as String,
      contentType: json['content_type'] as String,
      byteSize: json['byte_size'] as int,
      durationMs: json['duration_ms'] as int,
    );
  }
}
