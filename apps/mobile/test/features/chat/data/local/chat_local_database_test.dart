import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/data/local/chat_local_database.dart';
import 'package:help/features/chat/domain/entities/chat_conversation.dart';
import 'package:help/features/chat/domain/entities/chat_message.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late ChatLocalDatabase local;
  setUp(() {
    local = ChatLocalDatabase(
      opener: () => databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => ChatLocalDatabase.createSchema(db),
        ),
      ),
    );
  });
  tearDown(() => local.close());

  test('persists optimistic message and reconciles ACK atomically', () async {
    await local.upsertConversations([_conversation()]);
    final pending = _message(
      clientId: 'client-1',
      senderId: 'me',
      status: ChatMessageStatus.pending,
    );

    await local.insertOptimistic(pending);

    expect(
      (await local.listMessages('conversation')).single.status,
      ChatMessageStatus.pending,
    );
    expect((await local.pendingOutbox()).single.message.clientId, 'client-1');

    await local.reconcileAck(
      pending.copyWith(
        serverId: 'server-1',
        sequence: 1,
        serverCreatedAt: DateTime.utc(2026, 8, 14, 12),
        status: ChatMessageStatus.sent,
      ),
    );

    final confirmed = (await local.listMessages('conversation')).single;
    expect(confirmed.serverId, 'server-1');
    expect(confirmed.sequence, 1);
    expect(confirmed.status, ChatMessageStatus.sent);
    expect(await local.pendingOutbox(), isEmpty);
  });

  test('deduplicates remote retry and preserves monotonic receipts', () async {
    await local.upsertConversations([_conversation()]);
    final own = _message(
      clientId: 'client-own',
      senderId: 'me',
      status: ChatMessageStatus.sent,
      serverId: 'server-own',
      sequence: 1,
    );
    final incoming = _message(
      clientId: 'client-other',
      senderId: 'other',
      status: ChatMessageStatus.sent,
      serverId: 'server-other',
      sequence: 2,
    );

    await local.upsertRemote(own, currentUserId: 'me');
    await local.upsertRemote(incoming, currentUserId: 'me');
    await local.upsertRemote(incoming, currentUserId: 'me');
    await local.applyReceipt('conversation', 1, ChatMessageStatus.read, 'me');
    await local.applyReceipt(
      'conversation',
      1,
      ChatMessageStatus.delivered,
      'me',
    );

    final messages = await local.listMessages('conversation');
    expect(messages.map((item) => item.sequence), [1, 2]);
    expect(messages.first.status, ChatMessageStatus.read);
    expect((await local.listConversations()).single.unreadCount, 1);
  });
}

ChatConversation _conversation() => ChatConversation(
  id: 'conversation',
  otherUserId: 'other',
  otherDisplayName: 'Outra pessoa',
  updatedAt: DateTime.utc(2026, 8, 14),
);

ChatMessage _message({
  required String clientId,
  required String senderId,
  required ChatMessageStatus status,
  String? serverId,
  int? sequence,
}) => ChatMessage(
  clientId: clientId,
  serverId: serverId,
  conversationId: 'conversation',
  senderId: senderId,
  content: 'conteudo',
  localCreatedAt: DateTime.utc(2026, 8, 14, 11, sequence ?? 0),
  serverCreatedAt: sequence == null
      ? null
      : DateTime.utc(2026, 8, 14, 11, sequence),
  sequence: sequence,
  status: status,
);
