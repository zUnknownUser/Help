import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/network/bearer_auth_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('adiciona o token Firebase sem sobrescrever cabeçalhos', () async {
    late http.Request captured;
    final client = BearerAuthClient(
      inner: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
      tokenProvider: () async => 'firebase-token',
    );

    await client.get(
      Uri.parse('https://api.example.com/profile'),
      headers: {'Accept': 'application/json'},
    );

    expect(captured.headers['authorization'], 'Bearer firebase-token');
    expect(captured.headers['accept'], 'application/json');
  });

  test(
    'envia a requisição sem Authorization quando não existe sessão',
    () async {
      late http.Request captured;
      final client = BearerAuthClient(
        inner: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        tokenProvider: () async => null,
      );

      await client.get(Uri.parse('https://api.example.com/profile'));

      expect(captured.headers, isNot(contains('authorization')));
    },
  );
  test('interrompe token travado antes de enviar a requisiÃ§Ã£o', () async {
    final pendingToken = Completer<String?>();
    var requests = 0;
    final client = BearerAuthClient(
      inner: MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
      tokenProvider: () => pendingToken.future,
      tokenTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      client.get(Uri.parse('https://api.example.com/profile')),
      throwsA(isA<http.ClientException>()),
    );
    expect(requests, 0);
  });
}
