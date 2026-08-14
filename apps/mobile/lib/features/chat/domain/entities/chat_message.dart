enum ChatMessageStatus { pending, sent, delivered, read, failed }

class ChatMessage {
  const ChatMessage({
    required this.clientId,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.localCreatedAt,
    required this.status,
    this.serverId,
    this.sequence,
    this.serverCreatedAt,
  });

  final String clientId;
  final String? serverId;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime localCreatedAt;
  final DateTime? serverCreatedAt;
  final int? sequence;
  final ChatMessageStatus status;

  DateTime get displayedAt => serverCreatedAt ?? localCreatedAt;

  ChatMessage copyWith({
    String? serverId,
    int? sequence,
    DateTime? serverCreatedAt,
    ChatMessageStatus? status,
  }) => ChatMessage(
    clientId: clientId,
    serverId: serverId ?? this.serverId,
    conversationId: conversationId,
    senderId: senderId,
    content: content,
    localCreatedAt: localCreatedAt,
    serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
    sequence: sequence ?? this.sequence,
    status: status ?? this.status,
  );
}
