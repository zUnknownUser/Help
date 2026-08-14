import 'package:http/http.dart' as http;

typedef AccessTokenProvider = Future<String?> Function();

class BearerAuthClient extends http.BaseClient {
  factory BearerAuthClient({
    required http.Client inner,
    required AccessTokenProvider tokenProvider,
  }) => BearerAuthClient._(inner, tokenProvider);

  BearerAuthClient._(this._inner, this._tokenProvider);

  final http.Client _inner;
  final AccessTokenProvider _tokenProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = (await _tokenProvider())?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
