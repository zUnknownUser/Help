import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../home/data/models/json_reader.dart';
import '../domain/entities/service_request_item.dart';
import 'models/service_request_item_model.dart';

class ServiceRequestRemoteApi {
  ServiceRequestRemoteApi({required this.client, required String baseUrl})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client client;
  final String _baseUrl;

  Future<ServiceRequestPageData> list({
    required RequestViewerRole role,
    required String cursor,
    required int limit,
  }) async {
    final query = <String, String>{'role': role.name, 'limit': '$limit'};
    if (cursor.isNotEmpty) query['cursor'] = cursor;
    final uri = Uri.parse(
      '$_baseUrl/v1/service-requests',
    ).replace(queryParameters: query);
    final data = _data(await client.get(uri).timeout(_timeout));
    return ServiceRequestPageData(
      items: JsonReader.maps(data['items'], 'items')
          .map(ServiceRequestItemModel.fromJson)
          .map((model) => model.entity)
          .toList(growable: false),
      nextCursor: JsonReader.optionalString(data, 'next_cursor') ?? '',
    );
  }

  Future<ServiceRequestItem> get(String id) async =>
      ServiceRequestItemModel.fromJson(
        _data(
          await client
              .get(Uri.parse('$_baseUrl/v1/service-requests/$id'))
              .timeout(_timeout),
        ),
      ).entity;

  Future<List<ServiceRequestItem>> agenda({
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/provider/agenda').replace(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'limit': '500',
      },
    );
    final data = _data(await client.get(uri).timeout(_timeout));
    return JsonReader.maps(data['items'], 'items')
        .map(ServiceRequestItemModel.fromJson)
        .map((model) => model.entity)
        .toList(growable: false);
  }

  Future<ServiceRequestItem> transition({
    required String id,
    required String clientCommandId,
    required ServiceRequestStatus target,
    required int expectedVersion,
    required String reason,
  }) async => ServiceRequestItemModel.fromJson(
    _data(
      await client
          .post(
            Uri.parse('$_baseUrl/v1/service-requests/$id/transitions'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'client_command_id': clientCommandId,
              'target_status': target.wireValue,
              'expected_version': expectedVersion,
              'reason': reason.trim(),
            }),
          )
          .timeout(_timeout),
    ),
  ).entity;

  Future<ServiceRequestItem> reschedule({
    required String id,
    required String clientCommandId,
    required DateTime scheduledFor,
    required int expectedVersion,
  }) async => ServiceRequestItemModel.fromJson(
    _data(
      await client
          .post(
            Uri.parse('$_baseUrl/v1/service-requests/$id/reschedule'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'client_command_id': clientCommandId,
              'scheduled_for': scheduledFor.toUtc().toIso8601String(),
              'expected_version': expectedVersion,
            }),
          )
          .timeout(_timeout),
    ),
  ).entity;

  Map<String, dynamic> _data(http.Response response) {
    Map<String, dynamic>? envelope;
    try {
      envelope =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ServiceRequestApiException(response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServiceRequestApiException(
        response.statusCode,
        envelope['message'] as String?,
      );
    }
    return JsonReader.map(envelope['data'], 'data');
  }
}

const _timeout = Duration(seconds: 10);

class ServiceRequestApiException implements Exception {
  const ServiceRequestApiException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
}

bool isServiceRequestNetworkError(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;
