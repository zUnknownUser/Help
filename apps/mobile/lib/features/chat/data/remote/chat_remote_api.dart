import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_wire_mapper.dart';

class ChatRemoteApi {
  ChatRemoteApi({required this._client, required String baseUrl})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<CursorPage<ChatConversation>> conversations({
    String query = '',
    String cursor = '',
    int limit = 40,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/chat/conversations').replace(
      queryParameters: {
        'limit': '$limit',
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return _getPage(uri, ChatWireMapper.conversation);
  }

  Future<CursorPage<ChatMessage>> messages(
    String conversationId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  }) async {
    final uri =
        Uri.parse(
          '$_baseUrl/v1/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
        ).replace(
          queryParameters: {
            'limit': '$limit',
            if (beforeSequence != null) 'before_sequence': '$beforeSequence',
            if (afterSequence != null && afterSequence > 0)
              'after_sequence': '$afterSequence',
          },
        );
    return _getPage(uri, ChatWireMapper.message);
  }

  Future<ChatConversation> direct(String otherUserId) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/chat/conversations/direct'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'other_user_id': otherUserId}),
        )
        .timeout(const Duration(seconds: 8));
    final envelope = _decode(response);
    return ChatWireMapper.conversation(
      Map<String, dynamic>.from(envelope['data'] as Map),
    );
  }

  Future<CursorPage<ChatUser>> users({
    String query = '',
    String cursor = '',
    int limit = 30,
  }) {
    final uri = Uri.parse('$_baseUrl/v1/users').replace(
      queryParameters: {
        'limit': '$limit',
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return _getPage(uri, ChatWireMapper.user);
  }

  Future<CursorPage<T>> _getPage<T>(
    Uri uri,
    T Function(Map<String, dynamic>) mapper,
  ) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    final envelope = _decode(response);
    final items = (envelope['data'] as List)
        .map((item) => mapper(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return CursorPage(
      items: items,
      nextCursor: envelope['next_cursor'] as String? ?? '',
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatRemoteException(response.statusCode);
    }
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('invalid chat response');
    }
    return value;
  }
}

class CursorPage<T> {
  const CursorPage({required this.items, required this.nextCursor});
  final List<T> items;
  final String nextCursor;
}

class ChatRemoteException implements Exception {
  const ChatRemoteException(this.statusCode);
  final int statusCode;
  bool get retryable => statusCode >= HttpStatus.internalServerError;
}
