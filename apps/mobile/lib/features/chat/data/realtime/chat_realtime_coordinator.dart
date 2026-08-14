import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
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
  const PresenceEvent({required this.userId, required this.online});
  final String userId;
  final bool online;
}

class ChatRealtimeCoordinator {
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
  final _ackTimers = <String, Timer>{};
  Timer? _outboxTimer;
  final _inflight = <String>{};
  final _onlineUsers = <String>{};
  final _typingStates = <String, bool>{};
  final _conversationCursors = <String, String?>{};
  final _loadingConversationQueries = <String>{};
  final _historyExhausted = <String>{};
  IOWebSocketChannel? _channel;
  String? _userId;
  int _generation = 0;
  bool _connected = false;

  Stream<RealtimeConnectionStatus> get connectionStatus => _connection.stream;
  Stream<TypingEvent> get typingEvents => _typing.stream;
  Stream<PresenceEvent> get presenceEvents => _presence.stream;
  Stream<bool> watchPresence(String userId) async* {
    yield _onlineUsers.contains(userId);
    yield* presenceEvents
        .where((event) => event.userId == userId)
        .map((event) => event.online);
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
    unawaited(_connectionLoop(generation));
  }

  void stop() {
    _generation++;
    _connected = false;
    _inflight.clear();
    _onlineUsers.clear();
    _typingStates.clear();
    _conversationCursors.clear();
    _historyExhausted.clear();
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    _outboxTimer?.cancel();
    _outboxTimer = null;
    unawaited(_channel?.sink.close());
    _channel = null;
    _connection.add(RealtimeConnectionStatus.disconnected);
  }

  Future<ChatMessage> send(String conversationId, String content) async {
    final userId = _requireUser();
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

  Future<void> retry(String clientId) async {
    await _local.retry(clientId);
    await _drainOutbox();
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
    await _local.upsertConversations([conversation]);
    return conversation;
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
        await _synchronize();
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
        _inflight.clear();
        for (final timer in _ackTimers.values) {
          timer.cancel();
        }
        _ackTimers.clear();
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

  Future<void> _synchronize() async {
    final conversations = await _remote.conversations(limit: 40);
    await _local.upsertConversations(conversations.items);
    _conversationCursors[''] = conversations.nextCursor.isEmpty
        ? null
        : conversations.nextCursor;
    for (final conversation in conversations.items) {
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
    }
    await _drainOutbox();
  }

  Future<void> _drainOutbox() async {
    if (!_connected) return;
    _outboxTimer?.cancel();
    _outboxTimer = null;
    final pending = await _local.pendingOutbox();
    Duration? nextDelay;
    for (final item in pending) {
      final message = item.message;
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
      _inflight.add(message.clientId);
      _sendEvent(ChatEventTypes.messageSend, {
        'conversation_id': message.conversationId,
        'client_id': message.clientId,
        'content': message.content,
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
        await _local.reconcileAck(message);
      case ChatEventTypes.messageNew:
        final message = ChatWireMapper.message(data);
        await _local.upsertRemote(message, currentUserId: _requireUser());
        _sendEvent(ChatEventTypes.messageDelivered, {
          'conversation_id': message.conversationId,
          'up_to_sequence': message.sequence,
        });
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
        if (online) {
          _onlineUsers.add(userId);
        } else {
          _onlineUsers.remove(userId);
        }
        _presence.add(PresenceEvent(userId: userId, online: online));
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
