import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/home_data_exception.dart';
import 'home_interaction_remote_data_source.dart';
import '../../domain/entities/home_location.dart';

class HttpHomeInteractionRemoteDataSource
    implements HomeInteractionRemoteDataSource {
  factory HttpHomeInteractionRemoteDataSource({
    required http.Client client,
    required String baseUrl,
  }) => HttpHomeInteractionRemoteDataSource._(
    client,
    baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
  );

  const HttpHomeInteractionRemoteDataSource._(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<void> saveLocation(HomeLocation location) {
    return _send(
      () => _client.put(
        Uri.parse('$_baseUrl/v1/profile/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'label': location.availabilityLabel,
          'address': location.address,
          'postal_code': location.postalCode,
          'street': location.street,
          'street_number': location.streetNumber,
          'complement': location.complement,
          'district': location.district,
          'city': location.city,
          'state': location.state,
          'latitude': location.latitude,
          'longitude': location.longitude,
        }),
      ),
    );
  }

  @override
  Future<void> markNotificationRead(String id) {
    return _send(
      () => _client.post(
        Uri.parse('$_baseUrl/v1/notifications/${Uri.encodeComponent(id)}/read'),
      ),
    );
  }

  @override
  Future<void> markAllNotificationsRead() => _send(
    () => _client.post(Uri.parse('$_baseUrl/v1/notifications/read-all')),
  );

  Future<void> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HomeDataException(
          response.statusCode >= 500
              ? HomeDataErrorCode.unavailable
              : HomeDataErrorCode.invalidResponse,
          debugMessage: 'HTTP ${response.statusCode}',
        );
      }
    } on TimeoutException catch (error) {
      throw HomeDataException(
        HomeDataErrorCode.network,
        debugMessage: '$error',
      );
    } on SocketException catch (error) {
      throw HomeDataException(
        HomeDataErrorCode.network,
        debugMessage: '$error',
      );
    } on http.ClientException catch (error) {
      throw HomeDataException(
        HomeDataErrorCode.network,
        debugMessage: '$error',
      );
    }
  }
}
