import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/data/local/chat_local_database.dart';
import 'package:help/features/chat/domain/entities/chat_conversation.dart';
import 'package:help/features/chat/domain/entities/chat_message.dart';
import 'package:help/features/chat/domain/entities/chat_message_mutation.dart';
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

  test('keeps a voice file in the outbox until server ACK', () async {
    await local.upsertConversations([_conversation()]);
    final pending = ChatMessage(
      clientId: 'voice-client',
      conversationId: 'conversation',
      senderId: 'me',
      content: '',
      kind: ChatMessageKind.voice,
      media: const ChatMedia(
        contentType: 'audio/mp4',
        durationMs: 1400,
        byteSize: 200,
        localPath: 'voice.m4a',
      ),
      localCreatedAt: DateTime.utc(2026, 8, 16),
      status: ChatMessageStatus.pending,
    );
    await local.insertOptimistic(pending);

    await local.attachUploadedMedia(
      pending.clientId,
      const ChatMedia(
        id: 'media-id',
        contentType: 'audio/mp4',
        durationMs: 1400,
        byteSize: 200,
        localPath: 'voice.m4a',
      ),
    );
    final queued = (await local.pendingOutbox()).single.message;
    expect(queued.media?.id, 'media-id');
    expect(queued.media?.localPath, 'voice.m4a');

    await local.reconcileAck(
      queued.copyWith(
        serverId: 'server-voice',
        sequence: 1,
        serverCreatedAt: DateTime.utc(2026, 8, 16, 0, 1),
        status: ChatMessageStatus.sent,
        media: queued.media!.copyWith(id: 'media-id'),
      ),
    );
    final confirmed = (await local.listMessages('conversation')).single;
    expect(confirmed.isVoice, isTrue);
    expect(confirmed.media?.localPath, isNull);
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

  test('keeps same-user data and clears it before another account', () async {
    await local.activateUser('user-a');
    await local.upsertConversations([_conversation()]);

    await local.activateUser('user-a');
    expect(await local.listConversations(), hasLength(1));

    await local.activateUser('user-b');
    expect(await local.listConversations(), isEmpty);
  });

  test('persists conversation request authorization locally', () async {
    await local.upsertConversations([
      ChatConversation(
        id: 'request',
        otherUserId: 'other',
        otherDisplayName: 'Outra pessoa',
        updatedAt: DateTime.utc(2026, 8, 16),
        status: ChatConversationStatus.pending,
        requestedByMe: true,
      ),
    ]);

    final conversation = (await local.findConversation('request'))!;
    expect(conversation.status, ChatConversationStatus.pending);
    expect(conversation.requestedByMe, isTrue);
    expect(conversation.canMessage, isFalse);
  });

  test(
    'edits confirmed message optimistically and reconciles mutation',
    () async {
      await local.upsertConversations([_conversation()]);
      final original = _message(
        clientId: 'client-edit',
        senderId: 'me',
        status: ChatMessageStatus.sent,
        serverId: 'server-edit',
        sequence: 1,
      );
      await local.upsertRemote(original, currentUserId: 'me');

      final operationId = await local.editMessage(original, 'novo conteúdo');

      final optimistic = (await local.listMessages('conversation')).single;
      expect(optimistic.content, 'novo conteúdo');
      expect(optimistic.isEdited, isTrue);
      final mutation = (await local.pendingMutations()).single;
      expect(mutation.operationId, operationId);
      expect(mutation.kind, ChatMessageMutationKind.edit);

      final serverEditedAt = DateTime.utc(2026, 8, 14, 12, 30);
      await local.reconcileMutation(
        operationId!,
        ChatMessage(
          clientId: original.clientId,
          serverId: original.serverId,
          conversationId: original.conversationId,
          senderId: original.senderId,
          content: 'novo conteúdo',
          localCreatedAt: original.localCreatedAt,
          serverCreatedAt: original.serverCreatedAt,
          sequence: original.sequence,
          editedAt: serverEditedAt,
          version: 2,
          status: ChatMessageStatus.sent,
        ),
      );

      final confirmed = (await local.listMessages('conversation')).single;
      expect(
        confirmed.editedAt?.millisecondsSinceEpoch,
        serverEditedAt.millisecondsSinceEpoch,
      );
      expect(confirmed.version, 2);
      expect(await local.pendingMutations(), isEmpty);
    },
  );

  test(
    'rolls back optimistic deletion after permanent mutation failure',
    () async {
      await local.upsertConversations([_conversation()]);
      final original = _message(
        clientId: 'client-delete',
        senderId: 'me',
        status: ChatMessageStatus.read,
        serverId: 'server-delete',
        sequence: 1,
      );
      await local.upsertRemote(original, currentUserId: 'me');

      final operationId = await local.deleteMessage(original);
      expect(
        (await local.listMessages('conversation')).single.isDeleted,
        isTrue,
      );

      await local.markMutationAttempt(
        operationId!,
        error: 'forbidden',
        failed: true,
      );

      final restored = (await local.listMessages('conversation')).single;
      expect(restored.content, original.content);
      expect(restored.isDeleted, isFalse);
      expect(restored.version, original.version);
      expect(await local.pendingMutations(), isEmpty);
    },
  );

  test('updates or removes unsent message without a server mutation', () async {
    await local.upsertConversations([_conversation()]);
    final pending = _message(
      clientId: 'client-pending',
      senderId: 'me',
      status: ChatMessageStatus.pending,
    );
    await local.insertOptimistic(pending);

    expect(await local.editMessage(pending, 'corrigida'), isNull);
    expect((await local.pendingOutbox()).single.message.content, 'corrigida');
    expect(await local.pendingMutations(), isEmpty);

    final edited = (await local.listMessages('conversation')).single;
    expect(edited.isEdited, isFalse);
    expect(edited.version, 1);
    expect(await local.deleteMessage(edited), isNull);
    expect(await local.listMessages('conversation'), isEmpty);
    expect(await local.pendingOutbox(), isEmpty);
  });

  test(
    'uses server version after the last queued mutation is reconciled',
    () async {
      await local.upsertConversations([_conversation()]);
      final original = _message(
        clientId: 'client-chain',
        senderId: 'me',
        status: ChatMessageStatus.sent,
        serverId: 'server-chain',
        sequence: 1,
      );
      await local.upsertRemote(original, currentUserId: 'me');
      final firstOperation = await local.editMessage(original, 'primeira');
      final firstOptimistic = (await local.listMessages('conversation')).single;
      final secondOperation = await local.editMessage(
        firstOptimistic,
        'versão final',
      );

      await local.markMutationAttempt(firstOperation!, failed: true);
      await local.reconcileMutation(
        secondOperation!,
        ChatMessage(
          clientId: original.clientId,
          serverId: original.serverId,
          conversationId: original.conversationId,
          senderId: original.senderId,
          content: 'versão final',
          localCreatedAt: original.localCreatedAt,
          serverCreatedAt: original.serverCreatedAt,
          sequence: original.sequence,
          editedAt: DateTime(2026, 8, 16, 13),
          version: 2,
          status: ChatMessageStatus.sent,
        ),
      );

      final confirmed = (await local.listMessages('conversation')).single;
      expect(confirmed.content, 'versão final');
      expect(confirmed.version, 2);
      expect(await local.pendingMutations(), isEmpty);
    },
  );
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
