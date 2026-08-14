import 'dart:async';

import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/outbox_message.dart';

class ChatLocalDatabase {
  ChatLocalDatabase({Future<Database> Function()? opener})
    : _database = (opener ?? _open)();

  final Future<Database> _database;
  final _changes = StreamController<String?>.broadcast();

  static Future<Database> _open() async => openDatabase(
    paths.join(await getDatabasesPath(), 'help_local.db'),
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) => createSchema(db),
  );

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE chat_conversations (
        id TEXT PRIMARY KEY,
        other_user_id TEXT NOT NULL,
        other_display_name TEXT NOT NULL,
        last_message_client_id TEXT,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_read_sequence INTEGER NOT NULL DEFAULT 0,
        last_message_sequence INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('''CREATE TABLE chat_messages (
        client_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        conversation_id TEXT NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        local_created_at INTEGER NOT NULL,
        server_created_at INTEGER,
        sequence INTEGER,
        status TEXT NOT NULL,
        error_code TEXT
      )''');
    await db.execute(
      '''CREATE UNIQUE INDEX chat_messages_conversation_sequence_idx
        ON chat_messages(conversation_id, sequence) WHERE sequence IS NOT NULL''',
    );
    await db.execute('''CREATE INDEX chat_messages_conversation_order_idx
        ON chat_messages(conversation_id, sequence, local_created_at)''');
    await db.execute('''CREATE TABLE chat_outbox (
        client_id TEXT PRIMARY KEY REFERENCES chat_messages(client_id) ON DELETE CASCADE,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )''');
    await db.execute(
      'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  Stream<List<ChatConversation>> watchConversations({
    String query = '',
  }) async* {
    yield await listConversations(query: query);
    await for (final _ in _changes.stream) {
      yield await listConversations(query: query);
    }
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield await listMessages(conversationId);
    await for (final changed in _changes.stream) {
      if (changed == null || changed == conversationId) {
        yield await listMessages(conversationId);
      }
    }
  }

  Future<List<ChatConversation>> listConversations({String query = ''}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*, m.server_id, m.sender_id, m.content, m.local_created_at,
             m.server_created_at, m.sequence, m.status
      FROM chat_conversations c
      LEFT JOIN chat_messages m ON m.client_id = c.last_message_client_id
      WHERE ? = '' OR c.other_display_name LIKE '%' || ? || '%' COLLATE NOCASE
      ORDER BY c.updated_at DESC''',
      [query.trim(), query.trim()],
    );
    return rows.map(_conversationFromRow).toList(growable: false);
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final db = await _database;
    final rows = await db.query(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy:
          'CASE WHEN sequence IS NULL THEN 1 ELSE 0 END, sequence, local_created_at, client_id',
    );
    return rows.map(_messageFromRow).toList(growable: false);
  }

  Future<void> upsertConversations(Iterable<ChatConversation> values) async {
    final db = await _database;
    await db.transaction((tx) async {
      for (final value in values) {
        final map = _conversationMap(value);
        await tx.rawInsert(
          '''INSERT INTO chat_conversations (
          id, other_user_id, other_display_name, last_message_client_id,
          unread_count, last_read_sequence, last_message_sequence, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          other_user_id = excluded.other_user_id,
          other_display_name = excluded.other_display_name,
          unread_count = excluded.unread_count,
          last_read_sequence = MAX(chat_conversations.last_read_sequence, excluded.last_read_sequence),
          last_message_sequence = MAX(chat_conversations.last_message_sequence, excluded.last_message_sequence),
          updated_at = MAX(chat_conversations.updated_at, excluded.updated_at)''',
          [
            map['id'],
            map['other_user_id'],
            map['other_display_name'],
            map['last_message_client_id'],
            map['unread_count'],
            map['last_read_sequence'],
            map['last_message_sequence'],
            map['updated_at'],
          ],
        );
        if (value.lastMessage case final message?) {
          await _upsertMessage(tx, message);
        }
        if (value.lastMessage case final message?) {
          await _bumpConversation(tx, message);
        }
      }
    });
    _changes.add(null);
  }

  Future<void> insertOptimistic(ChatMessage message) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.insert(
        'chat_messages',
        _messageMap(message),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await tx.insert('chat_outbox', {
        'client_id': message.clientId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await tx.update(
        'chat_conversations',
        {
          'last_message_client_id': message.clientId,
          'updated_at': message.localCreatedAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
    });
    _changes.add(message.conversationId);
  }

  Future<void> reconcileAck(ChatMessage confirmed) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.update(
        'chat_messages',
        {
          'server_id': confirmed.serverId,
          'server_created_at':
              confirmed.serverCreatedAt?.millisecondsSinceEpoch,
          'sequence': confirmed.sequence,
          'status': confirmed.status.name,
          'error_code': null,
        },
        where: 'client_id = ?',
        whereArgs: [confirmed.clientId],
      );
      await tx.delete(
        'chat_outbox',
        where: 'client_id = ?',
        whereArgs: [confirmed.clientId],
      );
      await _bumpConversation(tx, confirmed);
    });
    _changes.add(confirmed.conversationId);
  }

  Future<void> upsertRemote(
    ChatMessage message, {
    required String currentUserId,
  }) async {
    final db = await _database;
    await db.transaction((tx) async {
      final existing =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              '''SELECT COUNT(*) FROM chat_messages
          WHERE client_id = ? OR (? IS NOT NULL AND server_id = ?)''',
              [message.clientId, message.serverId, message.serverId],
            ),
          )! >
          0;
      await _upsertMessage(tx, message);
      await _bumpConversation(
        tx,
        message,
        unreadDelta: existing || message.senderId == currentUserId ? 0 : 1,
      );
    });
    _changes.add(message.conversationId);
  }

  Future<void> mergeHistory(
    Iterable<ChatMessage> messages, {
    required String currentUserId,
  }) async {
    final values = messages.toList(growable: false);
    if (values.isEmpty) return;
    final db = await _database;
    await db.transaction((tx) async {
      for (final message in values) {
        await _upsertMessage(tx, message);
      }
      await _bumpConversation(tx, values.last);
    });
    _changes.add(values.first.conversationId);
  }

  Future<List<OutboxMessage>> pendingOutbox() async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''SELECT m.*, o.attempts, o.next_attempt_at FROM chat_outbox o
      JOIN chat_messages m ON m.client_id = o.client_id
      ORDER BY m.local_created_at''',
    );
    return rows
        .map(
          (row) => OutboxMessage(
            message: _messageFromRow(row),
            attempts: row['attempts'] as int,
            nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
              row['next_attempt_at'] as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markAttempt(
    String clientId, {
    String? error,
    bool failed = false,
  }) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.rawUpdate(
        '''UPDATE chat_outbox SET attempts = attempts + 1,
        next_attempt_at = ?, last_error = ? WHERE client_id = ?''',
        [
          DateTime.now().add(const Duration(seconds: 3)).millisecondsSinceEpoch,
          error,
          clientId,
        ],
      );
      if (failed) {
        await tx.update(
          'chat_messages',
          {'status': ChatMessageStatus.failed.name, 'error_code': error},
          where: 'client_id = ?',
          whereArgs: [clientId],
        );
      }
    });
    _changes.add(null);
  }

  Future<void> retry(String clientId) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.update(
        'chat_messages',
        {'status': ChatMessageStatus.pending.name, 'error_code': null},
        where: 'client_id = ?',
        whereArgs: [clientId],
      );
      await tx.update(
        'chat_outbox',
        {'attempts': 0, 'next_attempt_at': 0, 'last_error': null},
        where: 'client_id = ?',
        whereArgs: [clientId],
      );
    });
    _changes.add(null);
  }

  Future<void> applyReceipt(
    String conversationId,
    int sequence,
    ChatMessageStatus status,
    String currentUserId,
  ) async {
    final db = await _database;
    await db.rawUpdate(
      '''UPDATE chat_messages SET status = CASE
        WHEN status = 'read' THEN status
        WHEN status = 'delivered' AND ? = 'sent' THEN status
        ELSE ? END
      WHERE conversation_id = ? AND sender_id = ? AND sequence <= ?
        AND status NOT IN ('failed', 'pending')''',
      [status.name, status.name, conversationId, currentUserId, sequence],
    );
    _changes.add(conversationId);
  }

  Future<void> markConversationRead(
    String conversationId,
    int upToSequence,
  ) async {
    final db = await _database;
    await db.update(
      'chat_conversations',
      {'unread_count': 0, 'last_read_sequence': upToSequence},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    _changes.add(conversationId);
  }

  Future<int> maxSequence(String conversationId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sequence), 0) value FROM chat_messages WHERE conversation_id = ?',
      [conversationId],
    );
    return rows.first['value'] as int;
  }

  Future<String> installationId() async {
    final db = await _database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['installation_id'],
    );
    if (rows.isNotEmpty) return rows.first['value'] as String;
    final value = const Uuid().v4();
    await db.insert('app_settings', {'key': 'installation_id', 'value': value});
    return value;
  }

  Future<void> close() async {
    await _changes.close();
    await (await _database).close();
  }

  Future<void> _upsertMessage(DatabaseExecutor db, ChatMessage message) => db
      .rawInsert(
        '''
    INSERT INTO chat_messages (
      client_id, server_id, conversation_id, sender_id, content,
      local_created_at, server_created_at, sequence, status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(client_id) DO UPDATE SET
      server_id = COALESCE(excluded.server_id, chat_messages.server_id),
      server_created_at = COALESCE(excluded.server_created_at, chat_messages.server_created_at),
      sequence = COALESCE(excluded.sequence, chat_messages.sequence),
      status = CASE
        WHEN chat_messages.status = 'failed' AND excluded.status = 'pending' THEN chat_messages.status
        ELSE excluded.status END''',
        [
          message.clientId,
          message.serverId,
          message.conversationId,
          message.senderId,
          message.content,
          message.localCreatedAt.millisecondsSinceEpoch,
          message.serverCreatedAt?.millisecondsSinceEpoch,
          message.sequence,
          message.status.name,
        ],
      )
      .then((_) {});

  Future<void> _bumpConversation(
    DatabaseExecutor db,
    ChatMessage message, {
    int unreadDelta = 0,
  }) => db
      .rawUpdate(
        '''
    UPDATE chat_conversations SET
      last_message_client_id = CASE WHEN last_message_sequence <= COALESCE(?, last_message_sequence) THEN ? ELSE last_message_client_id END,
      last_message_sequence = MAX(last_message_sequence, COALESCE(?, last_message_sequence)),
      unread_count = unread_count + ?,
      updated_at = MAX(updated_at, ?)
    WHERE id = ?''',
        [
          message.sequence,
          message.clientId,
          message.sequence,
          unreadDelta,
          message.displayedAt.millisecondsSinceEpoch,
          message.conversationId,
        ],
      )
      .then((_) {});

  Map<String, Object?> _conversationMap(ChatConversation value) => {
    'id': value.id,
    'other_user_id': value.otherUserId,
    'other_display_name': value.otherDisplayName,
    'last_message_client_id': value.lastMessage?.clientId,
    'unread_count': value.unreadCount,
    'last_read_sequence': value.lastReadSequence,
    'last_message_sequence': value.lastMessageSequence,
    'updated_at': value.updatedAt.millisecondsSinceEpoch,
  };

  Map<String, Object?> _messageMap(ChatMessage value) => {
    'client_id': value.clientId,
    'server_id': value.serverId,
    'conversation_id': value.conversationId,
    'sender_id': value.senderId,
    'content': value.content,
    'local_created_at': value.localCreatedAt.millisecondsSinceEpoch,
    'server_created_at': value.serverCreatedAt?.millisecondsSinceEpoch,
    'sequence': value.sequence,
    'status': value.status.name,
  };

  ChatConversation _conversationFromRow(Map<String, Object?> row) =>
      ChatConversation(
        id: row['id'] as String,
        otherUserId: row['other_user_id'] as String,
        otherDisplayName: row['other_display_name'] as String,
        unreadCount: row['unread_count'] as int,
        lastReadSequence: row['last_read_sequence'] as int,
        lastMessageSequence: row['last_message_sequence'] as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int,
        ),
        lastMessage: row['last_message_client_id'] == null
            ? null
            : _messageFromRow({
                ...row,
                'client_id': row['last_message_client_id'],
                'conversation_id': row['id'],
              }),
      );

  ChatMessage _messageFromRow(Map<String, Object?> row) => ChatMessage(
    clientId: row['client_id'] as String,
    serverId: row['server_id'] as String?,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    content: row['content'] as String,
    localCreatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['local_created_at'] as int,
    ),
    serverCreatedAt: row['server_created_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['server_created_at'] as int),
    sequence: row['sequence'] as int?,
    status: ChatMessageStatus.values.byName(row['status'] as String),
  );
}
