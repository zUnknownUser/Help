part of 'chat_local_database.dart';

extension ChatLocalMutations on ChatLocalDatabase {
  Future<String?> editMessage(ChatMessage message, String content) async {
    final normalized = content.trim();
    if (normalized.isEmpty || message.isDeleted) return null;
    final db = await _database;
    if (message.serverId == null) {
      await db.update(
        'chat_messages',
        {'content': normalized},
        where: 'client_id = ?',
        whereArgs: [message.clientId],
      );
      _changes.add(message.conversationId);
      return null;
    }
    return _enqueueMutation(message, ChatMessageMutationKind.edit, normalized);
  }

  Future<String?> deleteMessage(ChatMessage message) async {
    final db = await _database;
    if (message.serverId == null) {
      await db.transaction((tx) async {
        await tx.delete(
          'chat_messages',
          where: 'client_id = ?',
          whereArgs: [message.clientId],
        );
        final previous = await tx.query(
          'chat_messages',
          columns: ['client_id', 'sequence'],
          where: 'conversation_id = ?',
          whereArgs: [message.conversationId],
          orderBy: 'sequence DESC, local_created_at DESC',
          limit: 1,
        );
        await tx.update(
          'chat_conversations',
          {
            'last_message_client_id': previous.isEmpty
                ? null
                : previous.single['client_id'],
            'last_message_sequence': previous.isEmpty
                ? 0
                : previous.single['sequence'] ?? 0,
          },
          where: 'id = ?',
          whereArgs: [message.conversationId],
        );
      });
      _changes.add(message.conversationId);
      return null;
    }
    return _enqueueMutation(message, ChatMessageMutationKind.delete, '');
  }

  Future<String> _enqueueMutation(
    ChatMessage message,
    ChatMessageMutationKind kind,
    String content,
  ) async {
    final db = await _database;
    final operationId = const Uuid().v4();
    final changedAt = DateTime.now();
    await db.transaction((tx) async {
      await tx.insert('chat_mutation_outbox', {
        'operation_id': operationId,
        'message_client_id': message.clientId,
        'kind': kind.name,
        'content': content,
        'previous_content': message.content,
        'previous_edited_at': message.editedAt?.millisecondsSinceEpoch,
        'previous_deleted_at': message.deletedAt?.millisecondsSinceEpoch,
        'previous_version': message.version,
        'created_at': changedAt.millisecondsSinceEpoch,
      });
      await tx.update(
        'chat_messages',
        {
          'content': content,
          'edited_at': kind == ChatMessageMutationKind.edit
              ? changedAt.millisecondsSinceEpoch
              : message.editedAt?.millisecondsSinceEpoch,
          'deleted_at': kind == ChatMessageMutationKind.delete
              ? changedAt.millisecondsSinceEpoch
              : null,
          'version': message.version + 1,
        },
        where: 'client_id = ?',
        whereArgs: [message.clientId],
      );
    });
    _changes.add(message.conversationId);
    return operationId;
  }

  Future<List<ChatMessageMutation>> pendingMutations() async {
    final db = await _database;
    final rows = await db.rawQuery('''SELECT m.*, o.operation_id,
      o.kind mutation_kind, o.content mutation_content, o.attempts,
      o.next_attempt_at
      FROM chat_mutation_outbox o
      JOIN chat_messages m ON m.client_id = o.message_client_id
      ORDER BY o.created_at, o.operation_id''');
    return rows
        .map(
          (row) => ChatMessageMutation(
            operationId: row['operation_id'] as String,
            message: _messageFromRow(row),
            kind: ChatMessageMutationKind.values.byName(
              row['mutation_kind'] as String,
            ),
            content: row['mutation_content'] as String,
            attempts: row['attempts'] as int,
            nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
              row['next_attempt_at'] as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> reconcileMutation(
    String operationId,
    ChatMessage confirmed,
  ) async {
    final db = await _database;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'chat_mutation_outbox',
        columns: ['message_client_id'],
        where: 'operation_id = ?',
        whereArgs: [operationId],
        limit: 1,
      );
      await tx.delete(
        'chat_mutation_outbox',
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      final pendingForMessage = rows.isEmpty
          ? 0
          : Sqflite.firstIntValue(
              await tx.rawQuery(
                '''SELECT COUNT(*) FROM chat_mutation_outbox
                WHERE message_client_id = ?''',
                [rows.single['message_client_id']],
              ),
            );
      if (pendingForMessage == 0) {
        await tx.update(
          'chat_messages',
          {
            'server_id': confirmed.serverId,
            'content': confirmed.content,
            'server_created_at':
                confirmed.serverCreatedAt?.millisecondsSinceEpoch,
            'sequence': confirmed.sequence,
            'edited_at': confirmed.editedAt?.millisecondsSinceEpoch,
            'deleted_at': confirmed.deletedAt?.millisecondsSinceEpoch,
            'version': confirmed.version,
            'status': confirmed.status.name,
          },
          where: 'client_id = ?',
          whereArgs: [confirmed.clientId],
        );
      } else {
        await _upsertMessage(tx, confirmed);
      }
    });
    _changes.add(confirmed.conversationId);
  }

  Future<void> markMutationAttempt(
    String operationId, {
    String? error,
    bool failed = false,
    bool increment = true,
  }) async {
    final db = await _database;
    String? conversationId;
    await db.transaction((tx) async {
      final rows = await tx.rawQuery(
        '''SELECT o.*, m.conversation_id
        FROM chat_mutation_outbox o
        JOIN chat_messages m ON m.client_id = o.message_client_id
        WHERE o.operation_id = ?''',
        [operationId],
      );
      if (rows.isEmpty) return;
      final mutation = rows.single;
      conversationId = mutation['conversation_id'] as String;
      if (!failed) {
        await tx.update(
          'chat_mutation_outbox',
          {
            'attempts': (mutation['attempts'] as int) + (increment ? 1 : 0),
            'next_attempt_at': DateTime.now()
                .add(const Duration(seconds: 3))
                .millisecondsSinceEpoch,
            'last_error': error,
          },
          where: 'operation_id = ?',
          whereArgs: [operationId],
        );
        return;
      }
      final newer = Sqflite.firstIntValue(
        await tx.rawQuery(
          '''SELECT COUNT(*) FROM chat_mutation_outbox
          WHERE message_client_id = ? AND created_at > ?''',
          [mutation['message_client_id'], mutation['created_at']],
        ),
      );
      if (newer == 0) {
        await tx.update(
          'chat_messages',
          {
            'content': mutation['previous_content'],
            'edited_at': mutation['previous_edited_at'],
            'deleted_at': mutation['previous_deleted_at'],
            'version': mutation['previous_version'],
          },
          where: 'client_id = ?',
          whereArgs: [mutation['message_client_id']],
        );
      }
      await tx.delete(
        'chat_mutation_outbox',
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
    });
    _changes.add(conversationId);
  }
}
