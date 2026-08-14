import 'dart:convert';

import 'package:http/http.dart' as http;

class DeviceRegistrationApi {
  DeviceRegistrationApi({required this._client, required String baseUrl})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/devices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'installation_id': installationId,
        'platform': platform,
        'fcm_token': token,
      }),
    );
    if (response.statusCode != 204) {
      throw StateError('device registration failed');
    }
  }

  Future<void> disable(String installationId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/devices/$installationId'),
    );
    if (response.statusCode != 204) throw StateError('device disable failed');
  }
}
