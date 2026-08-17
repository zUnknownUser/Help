import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../calls/domain/entities/call_signal.dart';
import '../../../calls/domain/repositories/call_signaling_gateway.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_message_mutation.dart';
import '../local/chat_local_database.dart';
import '../remote/chat_remote_api.dart';
import '../remote/chat_wire_mapper.dart';
import 'chat_event_types.dart';

typedef ChatTokenProvider = Future<String?> Function();

enum RealtimeConnectionStatus { disconnected, connecting, connected }

class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.started,
  });
  final String conversationId;
  final String userId;
  final bool started;
}

class PresenceEvent {
  const PresenceEvent({
    required this.userId,
    required this.online,
    this.lastSeenAt,
  });
  final String userId;
  final bool online;
  final DateTime? lastSeenAt;
}

class RealtimeAppEvent {
  const RealtimeAppEvent({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;
}

class ChatRealtimeCoordinator implements CallSignalingGateway {
  ChatRealtimeCoordinator({
    required this._local,
    required this._remote,
    required this._tokenProvider,
    required String apiBaseUrl,
  }) : _realtimeUri = _toRealtimeUri(apiBaseUrl);

  final ChatLocalDatabase _local;
  final ChatRemoteApi _remote;
  final ChatTokenProvider _tokenProvider;
  final Uri _realtimeUri;
  final _connection = StreamController<RealtimeConnectionStatus>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  final _calls = StreamController<CallSignal>.broadcast();
  final _appEvents = StreamController<RealtimeAppEvent>.broadcast();
  final _ackTimers = <String, Timer>{};
  Timer? _outboxTimer;
  Timer? _mutationTimer;
  Timer? _syncTimer;
  final _inflight = <String>{};
  final _presences = <String, PresenceEvent>{};
  final _typingStates = <String, bool>{};
  final _conversationCursors = <String, String?>{};
  final _loadingConversationQueries = <String>{};
  final _historyExhausted = <String>{};
  IOWebSocketChannel? _channel;
  String? _userId;
  int _generation = 0;
  bool _connected = false;
  bool _synchronizing = false;

  Stream<RealtimeConnectionStatus> get connectionStatus => _connection.stream;
  Stream<TypingEvent> get typingEvents => _typing.stream;
  Stream<PresenceEvent> get presenceEvents => _presence.stream;
  Stream<RealtimeAppEvent> get appEvents => _appEvents.stream;
  @override
  Stream<CallSignal> get callEvents => _calls.stream;
  @override
  bool get isConnected => _connected;
  Stream<PresenceEvent> watchPresence(String userId) async* {
    yield _presences[userId] ?? PresenceEvent(userId: userId, online: false);
    yield* presenceEvents
        .where((event) => event.userId == userId)
        .map((event) => event);
  }

  Stream<bool> watchTyping(String conversationId) async* {
    yield _typingStates[conversationId] ?? false;
    yield* typingEvents
        .where((event) => event.conversationId == conversationId)
        .map((event) => event.started);
  }

  Stream<List<ChatConversation>> watchConversations({String query = ''}) =>
      _local.watchConversations(query: query);
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      _local.watchMessages(conversationId);

  void start(String userId) {
    if (_userId == userId && _generation > 0) return;
    stop();
    _userId = userId;
    final generation = ++_generation;
    unawaited(_startSession(userId, generation));
  }

  Future<void> _startSession(String userId, int generation) async {
    await _local.activateUser(userId);
    if (generation != _generation || _userId != userId) return;
    await _connectionLoop(generation);
  }

  void stop() {
    _generation++;
    _connected = false;
    _synchronizing = false;
    _userId = null;
    _inflight.clear();
    _presences.clear();
    _typingStates.clear();
    _conversationCursors.clear();
    _historyExhausted.clear();
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    _outboxTimer?.cancel();
    _outboxTimer = null;
    _mutationTimer?.cancel();
    _mutationTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    unawaited(_channel?.sink.close());
    _channel = null;
    _connection.add(RealtimeConnectionStatus.disconnected);
  }

  Future<ChatMessage> send(String conversationId, String content) async {
    final userId = _requireUser();
    final conversation = await _local.findConversation(conversationId);
    if (conversation == null || !conversation.canMessage) {
      throw StateError('conversation_not_accepted');
    }
    final message = ChatMessage(
      clientId: const Uuid().v4(),
      conversationId: conversationId,
      senderId: userId,
      content: content.trim(),
      localCreatedAt: DateTime.now(),
      status: ChatMessageStatus.pending,
    );
    if (message.content.isEmpty) return message;
    await _local.insertOptimistic(message);
    unawaited(_drainOutbox());
    return message;
  }

  Future<ChatMessage> sendVoice(
    String conversationId, {
    required String localPath,
    required Duration duration,
  }) async {
    final userId = _requireUser();
    final conversation = await _local.findConversation(conversationId);
    final file = File(localPath);
    if (conversation == null || !conversation.canMessage) {
      throw StateError('conversation_not_accepted');
    }
    if (!await file.exists() ||
        duration.inMilliseconds < 250 ||
        duration.inMilliseconds > 300000) {
      throw StateError('invalid_voice_message');
    }
    final message = ChatMessage(
      clientId: const Uuid().v4(),
      conversationId: conversationId,
      senderId: userId,
      content: '',
      kind: ChatMessageKind.voice,
      media: ChatMedia(
        contentType: 'audio/mp4',
        durationMs: duration.inMilliseconds,
        byteSize: await file.length(),
        localPath: localPath,
      ),
      localCreatedAt: DateTime.now(),
      status: ChatMessageStatus.pending,
    );
    await _local.insertOptimistic(message);
    unawaited(_drainOutbox());
    return message;
  }

  Future<void> retry(String clientId) async {
    await _local.retry(clientId);
    await _drainOutbox();
  }

  Future<void> edit(ChatMessage message, String content) async {
    if (message.senderId != _requireUser()) return;
    await _local.editMessage(message, content);
    unawaited(_drainMutations());
    unawaited(_drainOutbox());
  }

  Future<void> delete(ChatMessage message) async {
    if (message.senderId != _requireUser()) return;
    await _local.deleteMessage(message);
    unawaited(_drainMutations());
  }

  Future<void> markRead(String conversationId, int upToSequence) async {
    if (upToSequence < 1) return;
    await _local.markConversationRead(conversationId, upToSequence);
    _sendEvent(ChatEventTypes.messageRead, {
      'conversation_id': conversationId,
      'up_to_sequence': upToSequence,
    });
  }

  void typing(String conversationId, bool started) {
    _sendEvent(
      started ? ChatEventTypes.typingStart : ChatEventTypes.typingStop,
      {'conversation_id': conversationId},
    );
  }

  @override
  void sendCallSignal(CallSignal signal) {
    if (!_connected) throw StateError('realtime_disconnected');
    _sendEvent(signal.type, signal.toWire());
  }

  Future<bool> loadOlder(String conversationId) async {
    if (_historyExhausted.contains(conversationId)) return false;
    final local = await _local.listMessages(conversationId);
    final firstSequence = local
        .where((item) => item.sequence != null)
        .fold<int?>(
          null,
          (lowest, item) => lowest == null || item.sequence! < lowest
              ? item.sequence
              : lowest,
        );
    final page = await _remote.messages(
      conversationId,
      beforeSequence: firstSequence,
    );
    await _local.mergeHistory(page.items, currentUserId: _requireUser());
    if (page.nextCursor.isEmpty) _historyExhausted.add(conversationId);
    return page.items.isNotEmpty;
  }

  Future<ChatConversation> startDirect(String otherUserId) async {
    final conversation = await _remote.direct(otherUserId);
    _rememberPresences([conversation]);
    await _local.upsertConversations([conversation]);
    return conversation;
  }

  Future<ChatConversation> decideConversation(
    String conversationId, {
    required bool accept,
  }) async {
    final conversation = await _remote.decide(conversationId, accept: accept);
    _rememberPresences([conversation]);
    await _local.upsertConversations([conversation]);
    return conversation;
  }

  Future<ChatConversation?> openConversation(String conversationId) async {
    var local = await _local.findConversation(conversationId);
    if (local != null) return local;
    var cursor = '';
    for (var pageIndex = 0; pageIndex < 5; pageIndex++) {
      final page = await _remote.conversations(cursor: cursor);
      _rememberPresences(page.items);
      await _local.upsertConversations(page.items);
      for (final conversation in page.items) {
        if (conversation.id == conversationId) return conversation;
      }
      if (page.nextCursor.isEmpty) break;
      cursor = page.nextCursor;
    }
    local = await _local.findConversation(conversationId);
    return local;
  }

  Future<CursorPage<ChatUser>> users({String query = '', String cursor = ''}) =>
      _remote.users(query: query, cursor: cursor);

  Future<void> loadMoreConversations({
    String query = '',
    bool reset = false,
  }) async {
    final normalized = query.trim();
    if (_loadingConversationQueries.contains(normalized)) return;
    if (reset) _conversationCursors.remove(normalized);
    if (_conversationCursors.containsKey(normalized) &&
        _conversationCursors[normalized] == null) {
      return;
    }
    _loadingConversationQueries.add(normalized);
    try {
      final page = await _remote.conversations(
        query: normalized,
        cursor: _conversationCursors[normalized] ?? '',
      );
      _rememberPresences(page.items);
      await _local.upsertConversations(page.items);
      _conversationCursors[normalized] = page.nextCursor.isEmpty
          ? null
          : page.nextCursor;
    } finally {
      _loadingConversationQueries.remove(normalized);
    }
  }

  Future<void> _connectionLoop(int generation) async {
    var attempt = 0;
    while (_generation == generation) {
      _connection.add(RealtimeConnectionStatus.connecting);
      try {
        final token = await _tokenProvider();
        if (token == null || token.isEmpty) {
          throw StateError('missing auth token');
        }
        final channel = IOWebSocketChannel.connect(
          _realtimeUri,
          headers: {'Authorization': 'Bearer $token'},
          pingInterval: const Duration(seconds: 20),
          connectTimeout: const Duration(seconds: 10),
        );
        _channel = channel;
        await channel.ready;
        if (_generation != generation) {
          await channel.sink.close();
          return;
        }
        _connected = true;
        attempt = 0;
        _connection.add(RealtimeConnectionStatus.connected);
        AppLogger.realtime('connected', fields: {'user_id': _userId});
        await _runSynchronization();
        await for (final raw in channel.stream) {
          await _handle(raw as String);
        }
      } catch (error) {
        AppLogger.realtime(
          'connection_lost',
          fields: {'user_id': _userId, 'attempt': attempt},
        );
      } finally {
        _connected = false;
        _syncTimer?.cancel();
        _syncTimer = null;
        _inflight.clear();
        for (final timer in _ackTimers.values) {
          timer.cancel();
        }
        _ackTimers.clear();
        final activeChannel = _channel;
        _channel = null;
        try {
          await activeChannel?.sink.close();
        } catch (_) {
          // The transport is already disconnected; reconnect owns recovery.
        }
        _connection.add(RealtimeConnectionStatus.disconnected);
      }
      if (_generation != generation) return;
      final seconds = min(30, pow(2, min(attempt++, 5)).toInt());
      final jitter = Random().nextInt(500);
      await Future<void>.delayed(
        Duration(seconds: seconds, milliseconds: jitter),
      );
    }
  }

  Future<void> _runSynchronization() async {
    if (!_connected || _synchronizing) return;
    _synchronizing = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    try {
      await _synchronize();
    } catch (_) {
      AppLogger.realtime(
        'synchronization_failed',
        fields: {'user_id': _userId},
      );
      _scheduleSynchronization();
      await _drainOutbox();
      await _drainMutations();
    } finally {
      _synchronizing = false;
    }
  }

  void _scheduleSynchronization() {
    if (!_connected || _syncTimer != null) return;
    _syncTimer = Timer(const Duration(seconds: 5), () {
      _syncTimer = null;
      unawaited(_runSynchronization());
    });
  }

  Future<void> _synchronize() async {
    final conversations = await _remote.conversations(limit: 40);
    _rememberPresences(conversations.items);
    await _local.upsertConversations(conversations.items);
    _conversationCursors[''] = conversations.nextCursor.isEmpty
        ? null
        : conversations.nextCursor;
    final accepted = conversations.items
        .where((conversation) => conversation.canMessage)
        .toList(growable: false);
    var incomplete = false;
    for (var offset = 0; offset < accepted.length; offset += 4) {
      final results = await Future.wait(
        accepted.skip(offset).take(4).map(_synchronizeConversation),
      );
      incomplete = incomplete || results.contains(false);
    }
    await _drainOutbox();
    await _drainMutations();
    if (incomplete) _scheduleSynchronization();
  }

  Future<bool> _synchronizeConversation(ChatConversation conversation) async {
    try {
      final after = await _local.maxSequence(conversation.id);
      final missing = await _remote.messages(
        conversation.id,
        afterSequence: after,
        limit: 100,
      );
      await _local.mergeHistory(missing.items, currentUserId: _requireUser());
      final latest = await _local.maxSequence(conversation.id);
      if (latest > 0) {
        _sendEvent(ChatEventTypes.messageDelivered, {
          'conversation_id': conversation.id,
          'up_to_sequence': latest,
        });
      }
      return true;
    } catch (_) {
      AppLogger.realtime(
        'conversation_synchronization_failed',
        fields: {'conversation_id': conversation.id},
      );
      return false;
    }
  }

  Future<void> _drainOutbox() async {
    if (!_connected) return;
    _outboxTimer?.cancel();
    _outboxTimer = null;
    final pending = await _local.pendingOutbox();
    Duration? nextDelay;
    for (final item in pending) {
      var message = item.message;
      if (_inflight.contains(message.clientId)) continue;
      if (message.status == ChatMessageStatus.failed) continue;
      final delay = item.nextAttemptAt.difference(DateTime.now());
      if (delay.inMilliseconds > 0) {
        if (nextDelay == null || delay < nextDelay) nextDelay = delay;
        continue;
      }
      if (item.attempts >= 5) {
        await _local.markAttempt(
          message.clientId,
          error: 'retry_exhausted',
          failed: true,
        );
        continue;
      }
      if (message.isVoice && message.media?.id == null) {
        try {
          message = await _uploadVoice(message);
        } catch (_) {
          await _local.markAttempt(
            message.clientId,
            error: 'media_upload_failed',
          );
          nextDelay ??= const Duration(seconds: 3);
          continue;
        }
      }
      _inflight.add(message.clientId);
      _sendEvent(ChatEventTypes.messageSend, {
        'conversation_id': message.conversationId,
        'client_id': message.clientId,
        'content': message.content,
        'kind': message.kind.name,
        'media_id': ?message.media?.id,
      });
      await _local.markAttempt(message.clientId);
      _ackTimers[message.clientId] = Timer(const Duration(seconds: 12), () {
        _inflight.remove(message.clientId);
        unawaited(_drainOutbox());
      });
      AppLogger.realtime(
        'message_send',
        fields: {
          'conversation_id': message.conversationId,
          'client_message_id': message.clientId,
          'attempt': item.attempts + 1,
        },
      );
    }
    if (nextDelay != null) {
      _outboxTimer = Timer(nextDelay, () => unawaited(_drainOutbox()));
    }
    unawaited(_drainMutations());
  }

  Future<ChatMessage> _uploadVoice(ChatMessage message) async {
    final media = message.media;
    final localPath = media?.localPath;
    if (media == null || localPath == null) {
      throw StateError('missing_voice_file');
    }
    final uploaded = await _remote.uploadVoice(
      message.conversationId,
      file: File(localPath),
      durationMs: media.durationMs,
    );
    final merged = uploaded.copyWith(localPath: localPath);
    await _local.attachUploadedMedia(message.clientId, merged);
    return message.copyWith(media: merged);
  }

  Future<void> _drainMutations() async {
    if (!_connected) return;
    _mutationTimer?.cancel();
    _mutationTimer = null;
    final pending = await _local.pendingMutations();
    if (pending.isEmpty) return;
    final mutation = pending.first;
    if (_inflight.contains(mutation.operationId)) return;
    final delay = mutation.nextAttemptAt.difference(DateTime.now());
    if (delay.inMilliseconds > 0) {
      _mutationTimer = Timer(delay, () => unawaited(_drainMutations()));
      return;
    }
    if (mutation.attempts >= 5) {
      await _local.markMutationAttempt(
        mutation.operationId,
        error: 'retry_exhausted',
        failed: true,
      );
      unawaited(_drainMutations());
      return;
    }
    _inflight.add(mutation.operationId);
    _sendEvent(
      mutation.kind == ChatMessageMutationKind.edit
          ? ChatEventTypes.messageEdit
          : ChatEventTypes.messageDelete,
      {
        'operation_id': mutation.operationId,
        'message_id': mutation.message.serverId,
        if (mutation.kind == ChatMessageMutationKind.edit)
          'content': mutation.content,
      },
    );
    await _local.markMutationAttempt(mutation.operationId);
    _ackTimers[mutation.operationId] = Timer(const Duration(seconds: 12), () {
      _inflight.remove(mutation.operationId);
      unawaited(_drainMutations());
    });
    AppLogger.realtime(
      'message_mutation_send',
      fields: {
        'conversation_id': mutation.message.conversationId,
        'server_message_id': mutation.message.serverId,
        'operation_id': mutation.operationId,
        'kind': mutation.kind.name,
        'attempt': mutation.attempts + 1,
      },
    );
  }

  Future<void> _handle(String raw) async {
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final type = envelope['type'] as String;
    final data = Map<String, dynamic>.from(
      envelope['data'] as Map? ?? const {},
    );
    switch (type) {
      case ChatEventTypes.messageAck:
        final message = ChatWireMapper.message(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        _completeInflight(message.clientId);
        final local = await _local.messageByClientId(message.clientId);
        await _local.reconcileAck(message);
        await _deleteUploadedVoice(local);
      case ChatEventTypes.messageNew:
        final message = ChatWireMapper.message(data);
        await _local.upsertRemote(message, currentUserId: _requireUser());
        _sendEvent(ChatEventTypes.messageDelivered, {
          'conversation_id': message.conversationId,
          'up_to_sequence': message.sequence,
        });
      case ChatEventTypes.messageUpdated:
      case ChatEventTypes.messageDeleted:
        final message = ChatWireMapper.message(data);
        await _local.upsertRemote(message, currentUserId: _requireUser());
      case ChatEventTypes.mutationAck:
        final operationId = data['operation_id'] as String;
        final message = ChatWireMapper.message(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        _completeInflight(operationId);
        await _local.reconcileMutation(operationId, message);
        unawaited(_drainMutations());
      case ChatEventTypes.mutationError:
        final operationId = data['operation_id'] as String? ?? '';
        if (operationId.isNotEmpty) {
          _completeInflight(operationId);
          final retryable = data['retryable'] as bool? ?? false;
          await _local.markMutationAttempt(
            operationId,
            error: data['code'] as String?,
            failed: !retryable,
            increment: false,
          );
          if (retryable) unawaited(_drainMutations());
        }
      case ChatEventTypes.messageDelivered:
        await _applyReceipt(data, ChatMessageStatus.delivered);
      case ChatEventTypes.messageRead:
        await _applyReceipt(data, ChatMessageStatus.read);
      case ChatEventTypes.messageError:
        final clientId = data['client_id'] as String? ?? '';
        if (clientId.isNotEmpty) {
          _completeInflight(clientId);
          final retryable = data['retryable'] as bool? ?? false;
          await _local.markAttempt(
            clientId,
            error: data['code'] as String?,
            failed: !retryable,
            increment: false,
          );
          if (retryable) unawaited(_drainOutbox());
        }
      case ChatEventTypes.typingStart:
      case ChatEventTypes.typingStop:
        _typingStates[data['conversation_id'] as String] =
            type == ChatEventTypes.typingStart;
        _typing.add(
          TypingEvent(
            conversationId: data['conversation_id'] as String,
            userId: data['user_id'] as String,
            started: type == ChatEventTypes.typingStart,
          ),
        );
      case ChatEventTypes.presenceChanged:
        final userId = data['user_id'] as String;
        final online = data['online'] as bool;
        final lastSeenAt = data['last_seen_at'] is String
            ? DateTime.parse(data['last_seen_at'] as String).toLocal()
            : _presences[userId]?.lastSeenAt;
        final presence = PresenceEvent(
          userId: userId,
          online: online,
          lastSeenAt: lastSeenAt,
        );
        _presences[userId] = presence;
        _presence.add(presence);
      case ChatEventTypes.conversationUpdated:
        try {
          final page = await _remote.conversations(limit: 40);
          _rememberPresences(page.items);
          await _local.upsertConversations(page.items);
        } catch (_) {
          AppLogger.realtime('conversation_refresh_failed');
          _scheduleSynchronization();
        }
      default:
        if (ChatEventTypes.callEvents.contains(type)) {
          _calls.add(CallSignal.fromWire(type, data));
        } else if (type.startsWith('help_now.')) {
          _appEvents.add(RealtimeAppEvent(type: type, data: data));
        }
    }
  }

  Future<void> _deleteUploadedVoice(ChatMessage? message) async {
    final path = message?.media?.localPath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      AppLogger.realtime(
        'voice_outbox_cleanup_failed',
        fields: {'client_message_id': message?.clientId},
      );
    }
  }

  Future<void> _applyReceipt(
    Map<String, dynamic> data,
    ChatMessageStatus status,
  ) => _local.applyReceipt(
    data['conversation_id'] as String,
    data['up_to_sequence'] as int,
    status,
    _requireUser(),
  );

  void _completeInflight(String clientId) {
    _inflight.remove(clientId);
    _ackTimers.remove(clientId)?.cancel();
  }

  void _rememberPresences(Iterable<ChatConversation> conversations) {
    for (final conversation in conversations) {
      final previous = _presences[conversation.otherUserId];
      final presence = PresenceEvent(
        userId: conversation.otherUserId,
        online: conversation.otherOnline,
        lastSeenAt: conversation.otherLastSeenAt ?? previous?.lastSeenAt,
      );
      _presences[conversation.otherUserId] = presence;
      _presence.add(presence);
    }
  }

  void _sendEvent(String type, Map<String, Object?> data) {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  String _requireUser() =>
      _userId ?? (throw StateError('chat session not started'));

  static Uri _toRealtimeUri(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/v1/realtime',
    );
  }
}
