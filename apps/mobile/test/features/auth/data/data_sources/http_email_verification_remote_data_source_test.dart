import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/auth/data/data_sources/http_email_verification_remote_data_source.dart';
import 'package:help/features/auth/data/errors/auth_data_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('solicita link de confirmação na API', () async {
    late http.Request captured;
    final dataSource = HttpEmailVerificationRemoteDataSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 202);
      }),
      baseUrl: 'https://api.example.com',
    );

    await dataSource.request();

    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/auth/email-verification');
  });

  test('traduz limite de reenvios', () async {
    final dataSource = HttpEmailVerificationRemoteDataSource(
      client: MockClient((_) async => http.Response('{}', 429)),
      baseUrl: 'https://api.example.com',
    );

    expect(
      dataSource.request,
      throwsA(
        isA<AuthDataException>().having(
          (error) => error.code,
          'code',
          AuthDataErrorCode.tooManyRequests,
        ),
      ),
    );
  });
}
