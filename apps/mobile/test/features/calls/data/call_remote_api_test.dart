import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/calls/data/call_remote_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'maps short-lived ICE servers returned by the authenticated API',
    () async {
      final api = CallRemoteApi(
        MockClient((request) async {
          expect(request.url.path, '/v1/realtime/ice-config');
          return http.Response(
            jsonEncode({
              'data': {
                'ice_servers': [
                  {
                    'urls': ['stun:stun.example.com:3478'],
                  },
                  {
                    'urls': ['turn:turn.example.com:3478?transport=udp'],
                    'username': 'expires:user',
                    'credential': 'temporary-secret',
                  },
                ],
                'expires_at': '2026-08-16T13:00:00Z',
              },
            }),
            200,
          );
        }),
        'https://api.example.com',
      );

      final config = await api.iceConfiguration();

      expect(config.servers, hasLength(2));
      expect(config.servers.last.username, 'expires:user');
      expect(config.servers.last.credential, 'temporary-secret');
    },
  );
}
