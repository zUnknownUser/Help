enum ChatMessageStatus { pending, sent, delivered, read, failed }

enum ChatMessageKind { text, voice }

class ChatMedia {
  const ChatMedia({
    required this.contentType,
    required this.durationMs,
    required this.byteSize,
    this.id,
    this.localPath,
  });

  final String? id;
  final String contentType;
  final int durationMs;
  final int byteSize;
  final String? localPath;

  ChatMedia copyWith({String? id, String? localPath, int? byteSize}) =>
      ChatMedia(
        id: id ?? this.id,
        contentType: contentType,
        durationMs: durationMs,
        byteSize: byteSize ?? this.byteSize,
        localPath: localPath ?? this.localPath,
      );
}

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
    this.editedAt,
    this.deletedAt,
    this.version = 1,
    this.kind = ChatMessageKind.text,
    this.media,
  });

  final String clientId;
  final String? serverId;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime localCreatedAt;
  final DateTime? serverCreatedAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final int? sequence;
  final int version;
  final ChatMessageStatus status;
  final ChatMessageKind kind;
  final ChatMedia? media;

  DateTime get displayedAt => serverCreatedAt ?? localCreatedAt;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;
  bool get isVoice => kind == ChatMessageKind.voice && media != null;

  ChatMessage copyWith({
    String? content,
    String? serverId,
    int? sequence,
    DateTime? serverCreatedAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    int? version,
    ChatMessageStatus? status,
    ChatMedia? media,
  }) => ChatMessage(
    clientId: clientId,
    serverId: serverId ?? this.serverId,
    conversationId: conversationId,
    senderId: senderId,
    content: content ?? this.content,
    localCreatedAt: localCreatedAt,
    serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    sequence: sequence ?? this.sequence,
    version: version ?? this.version,
    status: status ?? this.status,
    kind: kind,
    media: media ?? this.media,
  );
}
