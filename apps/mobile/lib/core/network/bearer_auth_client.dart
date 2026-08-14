import 'dart:async';

import 'package:http/http.dart' as http;

typedef AccessTokenProvider = Future<String?> Function();

class BearerAuthClient extends http.BaseClient {
  factory BearerAuthClient({
    required http.Client inner,
    required AccessTokenProvider tokenProvider,
    Duration tokenTimeout = const Duration(seconds: 8),
  }) => BearerAuthClient._(inner, tokenProvider, tokenTimeout);

  BearerAuthClient._(this._inner, this._tokenProvider, this._tokenTimeout);

  final http.Client _inner;
  final AccessTokenProvider _tokenProvider;
  final Duration _tokenTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? token;
    try {
      token = (await _tokenProvider().timeout(_tokenTimeout))?.trim();
    } on TimeoutException {
      throw http.ClientException('Authentication timed out.', request.url);
    } catch (_) {
      throw http.ClientException('Authentication unavailable.', request.url);
    }
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
