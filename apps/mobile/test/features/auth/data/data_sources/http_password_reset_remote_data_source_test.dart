import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/auth/data/data_sources/http_password_reset_remote_data_source.dart';
import 'package:help/features/auth/data/errors/auth_data_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('envia o e-mail para o endpoint da API', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response('{"message":"ok"}', 202);
    });
    final dataSource = HttpPasswordResetRemoteDataSource(
      client: client,
      baseUrl: 'https://api.example.com/',
    );

    await dataSource.requestPasswordReset('user@example.com');

    expect(
      capturedRequest.url.toString(),
      'https://api.example.com/v1/auth/password-reset',
    );
    expect(capturedRequest.body, contains('user@example.com'));
    expect(
      capturedRequest.headers['content-type'],
      contains('application/json'),
    );
  });

  test('mapeia limite de tentativas retornado pela API', () async {
    final client = MockClient((_) async => http.Response('{}', 429));
    final dataSource = HttpPasswordResetRemoteDataSource(
      client: client,
      baseUrl: 'https://api.example.com',
    );

    expect(
      () => dataSource.requestPasswordReset('user@example.com'),
      throwsA(
        isA<AuthDataException>().having(
          (error) => error.code,
          'code',
          AuthDataErrorCode.tooManyRequests,
        ),
      ),
    );
  });

  test('não expõe corpo interno em falha inesperada', () async {
    final client = MockClient(
      (_) async => http.Response('token-interno-secreto', 503),
    );
    final dataSource = HttpPasswordResetRemoteDataSource(
      client: client,
      baseUrl: 'https://api.example.com',
    );

    expect(
      () => dataSource.requestPasswordReset('user@example.com'),
      throwsA(
        isA<AuthDataException>()
            .having((error) => error.code, 'code', AuthDataErrorCode.unknown)
            .having(
              (error) => error.debugMessage ?? '',
              'debugMessage',
              isNot(contains('token-interno-secreto')),
            ),
      ),
    );
  });
}
