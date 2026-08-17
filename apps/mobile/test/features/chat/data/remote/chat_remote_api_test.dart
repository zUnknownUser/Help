import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/data/remote/chat_remote_api.dart';
import 'package:help/features/chat/domain/entities/chat_conversation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('mapeia somente usuários elegíveis com o papel público', () async {
    final api = ChatRemoteApi(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/users');
        expect(request.url.queryParameters['query'], 'Maria');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'provider-1', 'display_name': 'Maria', 'role': 'provider'},
            ],
            'next_cursor': '',
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    final page = await api.users(query: ' Maria ');

    expect(page.items.single.role, ChatUserRole.provider);
  });

  test('envia decisão e lê o estado de autorização da conversa', () async {
    final api = ChatRemoteApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/v1/chat/conversations/conversation-1/decision',
        );
        expect(jsonDecode(request.body), {'decision': 'accept'});
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'conversation-1',
              'other_user_id': 'other',
              'other_display_name': 'Maria',
              'status': 'accepted',
              'requested_by_me': false,
              'updated_at': '2026-08-16T12:00:00Z',
            },
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    final conversation = await api.decide('conversation-1', accept: true);

    expect(conversation.status, ChatConversationStatus.accepted);
    expect(conversation.canMessage, isTrue);
  });

  test('uploads voice bytes with duration and maps persistent media', () async {
    final directory = await Directory.systemTemp.createTemp('help-voice-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/voice.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);
    final api = ChatRemoteApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/v1/chat/conversations/conversation-1/voice-media',
        );
        expect(request.headers['x-voice-duration-ms'], '1250');
        expect(request.bodyBytes, [1, 2, 3, 4]);
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'media-1',
              'content_type': 'audio/mp4',
              'byte_size': 4,
              'duration_ms': 1250,
            },
          }),
          201,
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    final media = await api.uploadVoice(
      'conversation-1',
      file: file,
      durationMs: 1250,
    );

    expect(media.id, 'media-1');
    expect(media.durationMs, 1250);
  });
}
