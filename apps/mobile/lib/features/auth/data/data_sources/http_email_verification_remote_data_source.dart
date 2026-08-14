import 'package:http/http.dart' as http;

import '../errors/auth_data_exception.dart';
import 'email_verification_remote_data_source.dart';

class HttpEmailVerificationRemoteDataSource
    implements EmailVerificationRemoteDataSource {
  factory HttpEmailVerificationRemoteDataSource({
    required http.Client client,
    required String baseUrl,
  }) => HttpEmailVerificationRemoteDataSource._(client, baseUrl);

  const HttpEmailVerificationRemoteDataSource._(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<void> request() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/auth/email-verification'),
      );
      if (response.statusCode == 429) {
        throw const AuthDataException(AuthDataErrorCode.tooManyRequests);
      }
      if (response.statusCode == 401) {
        throw const AuthDataException(AuthDataErrorCode.invalidCredentials);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthDataException(
          AuthDataErrorCode.unknown,
          debugMessage: 'API status ${response.statusCode}',
        );
      }
    } on http.ClientException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    }
  }
}
