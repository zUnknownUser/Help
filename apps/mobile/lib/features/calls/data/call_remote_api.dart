import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/entities/ice_configuration.dart';

class CallRemoteApi {
  const CallRemoteApi(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Future<CallICEConfiguration> iceConfiguration() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/v1/realtime/ice-config'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('ice_configuration_unavailable');
    }
    final envelope = jsonDecode(utf8.decode(response.bodyBytes));
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    final servers = (data['ice_servers'] as List)
        .map((value) {
          final json = Map<String, dynamic>.from(value as Map);
          return CallICEServer(
            urls: (json['urls'] as List).cast<String>(),
            username: json['username'] as String?,
            credential: json['credential'] as String?,
          );
        })
        .toList(growable: false);
    return CallICEConfiguration(
      servers: servers,
      expiresAt: DateTime.parse(data['expires_at'] as String).toLocal(),
    );
  }
}
