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
}
