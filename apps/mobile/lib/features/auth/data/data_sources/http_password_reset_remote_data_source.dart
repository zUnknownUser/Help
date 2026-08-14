import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/auth_data_exception.dart';
import 'password_reset_remote_data_source.dart';

class HttpPasswordResetRemoteDataSource
    implements PasswordResetRemoteDataSource {
  HttpPasswordResetRemoteDataSource({
    required this.client,
    required String baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _endpoint = Uri.parse(
         '${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/v1/auth/password-reset',
       );

  final http.Client client;
  final Uri _endpoint;
  final Duration timeout;

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(timeout);

      if (response.statusCode == HttpStatus.accepted) return;
      if (response.statusCode == HttpStatus.tooManyRequests) {
        throw const AuthDataException(AuthDataErrorCode.tooManyRequests);
      }
      throw AuthDataException(
        AuthDataErrorCode.unknown,
        debugMessage: 'password reset API returned HTTP ${response.statusCode}',
      );
    } on AuthDataException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: error.toString(),
      );
    } on SocketException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: error.toString(),
      );
    }
  }
}
