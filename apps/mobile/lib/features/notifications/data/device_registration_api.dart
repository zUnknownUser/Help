import 'dart:convert';

import 'package:http/http.dart' as http;

abstract interface class DeviceRegistrar {
  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
  });
  Future<void> disable(String installationId);
}

class DeviceRegistrationApi implements DeviceRegistrar {
  DeviceRegistrationApi({
    required this._client,
    required String baseUrl,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;
  final Duration requestTimeout;

  @override
  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/devices'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'installation_id': installationId,
            'platform': platform,
            'fcm_token': token,
          }),
        )
        .timeout(requestTimeout);
    if (response.statusCode != 204) {
      throw StateError('device registration failed');
    }
  }

  @override
  Future<void> disable(String installationId) async {
    final response = await _client
        .delete(Uri.parse('$_baseUrl/v1/devices/$installationId'))
        .timeout(requestTimeout);
    if (response.statusCode != 204) throw StateError('device disable failed');
  }
}
