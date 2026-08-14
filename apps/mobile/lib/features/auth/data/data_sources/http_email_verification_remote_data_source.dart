import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/auth_data_exception.dart';
import 'email_verification_remote_data_source.dart';

class HttpEmailVerificationRemoteDataSource
    implements EmailVerificationRemoteDataSource {
  factory HttpEmailVerificationRemoteDataSource({
    required http.Client client,
    required String baseUrl,
    Duration timeout = const Duration(seconds: 10),
  }) => HttpEmailVerificationRemoteDataSource._(client, baseUrl, timeout);

  const HttpEmailVerificationRemoteDataSource._(
    this._client,
    this._baseUrl,
    this._timeout,
  );

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<void> request() async {
    try {
      final response = await _client
          .post(Uri.parse('$_baseUrl/v1/auth/email-verification'))
          .timeout(_timeout);
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
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  AuthDataException _networkError(Object error) {
    return AuthDataException(AuthDataErrorCode.network, debugMessage: '$error');
  }
}
