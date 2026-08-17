import 'dart:async';

import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_message_mutation.dart';
import '../../domain/entities/outbox_message.dart';

part 'chat_local_mutations.dart';

class ChatLocalDatabase {
  ChatLocalDatabase({Future<Database> Function()? opener})
    : _opener = opener ?? _open;

  final Future<Database> Function() _opener;
  Future<Database>? _databaseFuture;
  Future<Database> get _database => _databaseFuture ??= _opener();
  final _changes = StreamController<String?>.broadcast();

  static const _conversationSelect = '''
      SELECT c.*, c.status AS conversation_status,
             m.server_id, m.sender_id, m.content, m.local_created_at,
             m.server_created_at, m.sequence, m.edited_at, m.deleted_at,
			 m.version, m.status AS message_status, m.kind, m.media_id,
			 m.media_content_type, m.media_duration_ms, m.media_byte_size,
			 m.media_local_path
      FROM chat_conversations c
      LEFT JOIN chat_messages m ON m.client_id = c.last_message_client_id''';

  static Future<Database> _open() async => openDatabase(
    paths.join(await getDatabasesPath(), 'help_local.db'),
    version: 4,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) => createSchema(db),
    onUpgrade: upgradeSchema,
  );

  static Future<void> upgradeSchema(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN edited_at INTEGER',
      );
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN deleted_at INTEGER',
      );
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
      );
      await _createMutationOutbox(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE chat_conversations ADD COLUMN status TEXT NOT NULL DEFAULT 'accepted'",
      );
      await db.execute(
        'ALTER TABLE chat_conversations ADD COLUMN requested_by_me INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE chat_messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'",
      );
      await db.execute('ALTER TABLE chat_messages ADD COLUMN media_id TEXT');
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN media_content_type TEXT',
      );
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN media_duration_ms INTEGER',
      );
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN media_byte_size INTEGER',
      );
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN media_local_path TEXT',
      );
    }
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE chat_conversations (
        id TEXT PRIMARY KEY,
        other_user_id TEXT NOT NULL,
        other_display_name TEXT NOT NULL,
        last_message_client_id TEXT,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_read_sequence INTEGER NOT NULL DEFAULT 0,
        last_message_sequence INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'accepted',
        requested_by_me INTEGER NOT NULL DEFAULT 0,
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
        edited_at INTEGER,
        deleted_at INTEGER,
        version INTEGER NOT NULL DEFAULT 1,
		kind TEXT NOT NULL DEFAULT 'text',
		media_id TEXT,
		media_content_type TEXT,
		media_duration_ms INTEGER,
		media_byte_size INTEGER,
		media_local_path TEXT,
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
    await _createMutationOutbox(db);
    await db.execute(
      'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  static Future<void> _createMutationOutbox(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE chat_mutation_outbox (
      operation_id TEXT PRIMARY KEY,
      message_client_id TEXT NOT NULL REFERENCES chat_messages(client_id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      content TEXT NOT NULL,
      previous_content TEXT NOT NULL,
      previous_edited_at INTEGER,
      previous_deleted_at INTEGER,
      previous_version INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at INTEGER NOT NULL
    )''');

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
      '''$_conversationSelect
      WHERE ? = '' OR c.other_display_name LIKE '%' || ? || '%' COLLATE NOCASE
      ORDER BY c.updated_at DESC''',
      [query.trim(), query.trim()],
    );
    return rows.map(_conversationFromRow).toList(growable: false);
  }

  Future<void> activateUser(String userId) async {
    final db = await _database;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['chat_user_id'],
        limit: 1,
      );
      final previous = rows.isEmpty ? null : rows.first['value'] as String?;
      if (previous != null && previous != userId) {
        await tx.delete('chat_conversations');
      }
      await tx.insert('app_settings', {
        'key': 'chat_user_id',
        'value': userId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _changes.add(null);
  }

  Future<ChatConversation?> findConversation(String id) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '$_conversationSelect WHERE c.id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : _conversationFromRow(rows.first);
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

  Future<ChatMessage?> messageByClientId(String clientId) async {
    final db = await _database;
    final rows = await db.query(
      'chat_messages',
      where: 'client_id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    return rows.isEmpty ? null : _messageFromRow(rows.first);
  }

  Future<void> upsertConversations(Iterable<ChatConversation> values) async {
    final db = await _database;
    await db.transaction((tx) async {
      for (final value in values) {
        final map = _conversationMap(value);
        await tx.rawInsert(
          '''INSERT INTO chat_conversations (
          id, other_user_id, other_display_name, last_message_client_id,
          unread_count, last_read_sequence, last_message_sequence, status,
          requested_by_me, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          other_user_id = excluded.other_user_id,
          other_display_name = excluded.other_display_name,
          unread_count = excluded.unread_count,
          last_read_sequence = MAX(chat_conversations.last_read_sequence, excluded.last_read_sequence),
          last_message_sequence = MAX(chat_conversations.last_message_sequence, excluded.last_message_sequence),
          status = excluded.status,
          requested_by_me = excluded.requested_by_me,
          updated_at = MAX(chat_conversations.updated_at, excluded.updated_at)''',
          [
            map['id'],
            map['other_user_id'],
            map['other_display_name'],
            map['last_message_client_id'],
            map['unread_count'],
            map['last_read_sequence'],
            map['last_message_sequence'],
            map['status'],
            map['requested_by_me'],
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
          'kind': confirmed.kind.name,
          'media_id': confirmed.media?.id,
          'media_content_type': confirmed.media?.contentType,
          'media_duration_ms': confirmed.media?.durationMs,
          'media_byte_size': confirmed.media?.byteSize,
          'media_local_path': null,
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

  Future<void> attachUploadedMedia(String clientId, ChatMedia media) async {
    final db = await _database;
    await db.update(
      'chat_messages',
      {
        'media_id': media.id,
        'media_content_type': media.contentType,
        'media_duration_ms': media.durationMs,
        'media_byte_size': media.byteSize,
      },
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    _changes.add(null);
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
    bool increment = true,
  }) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.rawUpdate(
        '''UPDATE chat_outbox SET attempts = attempts + ?,
        next_attempt_at = ?, last_error = ? WHERE client_id = ?''',
        [
          increment ? 1 : 0,
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
    final database = _databaseFuture;
    if (database != null) await (await database).close();
  }

  Future<void> _upsertMessage(DatabaseExecutor db, ChatMessage message) => db
      .rawInsert(
        '''
    INSERT INTO chat_messages (
      client_id, server_id, conversation_id, sender_id, content,
      local_created_at, server_created_at, sequence, edited_at, deleted_at,
	  version, kind, media_id, media_content_type, media_duration_ms,
	  media_byte_size, media_local_path, status
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(client_id) DO UPDATE SET
      server_id = COALESCE(excluded.server_id, chat_messages.server_id),
      server_created_at = COALESCE(excluded.server_created_at, chat_messages.server_created_at),
      sequence = COALESCE(excluded.sequence, chat_messages.sequence),
      content = CASE WHEN excluded.version >= chat_messages.version THEN excluded.content ELSE chat_messages.content END,
      edited_at = CASE WHEN excluded.version >= chat_messages.version THEN excluded.edited_at ELSE chat_messages.edited_at END,
      deleted_at = CASE WHEN excluded.version >= chat_messages.version THEN excluded.deleted_at ELSE chat_messages.deleted_at END,
      version = MAX(chat_messages.version, excluded.version),
	  kind = excluded.kind,
	  media_id = COALESCE(excluded.media_id, chat_messages.media_id),
	  media_content_type = COALESCE(excluded.media_content_type, chat_messages.media_content_type),
	  media_duration_ms = COALESCE(excluded.media_duration_ms, chat_messages.media_duration_ms),
	  media_byte_size = COALESCE(excluded.media_byte_size, chat_messages.media_byte_size),
	  media_local_path = COALESCE(excluded.media_local_path, chat_messages.media_local_path),
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
          message.editedAt?.millisecondsSinceEpoch,
          message.deletedAt?.millisecondsSinceEpoch,
          message.version,
          message.kind.name,
          message.media?.id,
          message.media?.contentType,
          message.media?.durationMs,
          message.media?.byteSize,
          message.media?.localPath,
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
    'status': value.status.name,
    'requested_by_me': value.requestedByMe ? 1 : 0,
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
    'edited_at': value.editedAt?.millisecondsSinceEpoch,
    'deleted_at': value.deletedAt?.millisecondsSinceEpoch,
    'version': value.version,
    'kind': value.kind.name,
    'media_id': value.media?.id,
    'media_content_type': value.media?.contentType,
    'media_duration_ms': value.media?.durationMs,
    'media_byte_size': value.media?.byteSize,
    'media_local_path': value.media?.localPath,
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
        status: ChatConversationStatus.values.byName(
          row['conversation_status'] as String? ?? 'accepted',
        ),
        requestedByMe: (row['requested_by_me'] as int? ?? 0) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int,
        ),
        lastMessage: row['last_message_client_id'] == null
            ? null
            : _messageFromRow({
                ...row,
                'client_id': row['last_message_client_id'],
                'conversation_id': row['id'],
                'status': row['message_status'],
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
    editedAt: row['edited_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['edited_at'] as int),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['deleted_at'] as int),
    version: row['version'] as int? ?? 1,
    kind: ChatMessageKind.values.byName(row['kind'] as String? ?? 'text'),
    media: row['media_content_type'] == null
        ? null
        : ChatMedia(
            id: row['media_id'] as String?,
            contentType: row['media_content_type'] as String,
            durationMs: row['media_duration_ms'] as int,
            byteSize: row['media_byte_size'] as int? ?? 0,
            localPath: row['media_local_path'] as String?,
          ),
    status: ChatMessageStatus.values.byName(row['status'] as String),
  );
}
