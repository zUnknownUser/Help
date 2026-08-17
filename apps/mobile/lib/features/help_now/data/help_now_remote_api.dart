import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../home/data/models/json_reader.dart';
import '../domain/entities/help_now_availability.dart';
import '../domain/entities/help_now_offer.dart';
import '../domain/entities/help_now_request.dart';

class HelpNowRemoteApi {
  HelpNowRemoteApi({required this.client, required String baseUrl})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client client;
  final String _baseUrl;

  Future<HelpNowRequest> create(Map<String, Object?> body) async =>
      _request(_post('/v1/help-now/requests', body), _requestFromJson);

  Future<HelpNowRequest?> active() async {
    final response = await client
        .get(Uri.parse('$_baseUrl/v1/help-now/requests/active'))
        .timeout(_timeout);
    final data = _decode(response);
    return data == null ? null : _requestFromJson(JsonReader.map(data, 'data'));
  }

  Future<HelpNowRequest> cancel(String id) async => _request(
    _post('/v1/help-now/requests/$id/cancel', const {}),
    _requestFromJson,
  );

  Future<HelpNowAvailability> availability() async => _request(
    client
        .get(Uri.parse('$_baseUrl/v1/help-now/provider/availability'))
        .timeout(_timeout),
    _availabilityFromJson,
  );

  Future<HelpNowAvailability> setAvailability(
    Map<String, Object?> body,
  ) async => _request(
    client
        .put(
          Uri.parse('$_baseUrl/v1/help-now/provider/availability'),
          headers: _jsonHeaders,
          body: jsonEncode(body),
        )
        .timeout(_timeout),
    _availabilityFromJson,
  );

  Future<List<HelpNowOffer>> offers() async {
    final response = await client
        .get(Uri.parse('$_baseUrl/v1/help-now/provider/offers'))
        .timeout(_timeout);
    final data = JsonReader.map(_decode(response), 'data');
    return JsonReader.maps(
      data['items'],
      'items',
    ).map(_offerFromJson).toList(growable: false);
  }

  Future<HelpNowRequest> respond({
    required String offerId,
    required String clientCommandId,
    required bool accept,
  }) async => _request(
    _post('/v1/help-now/provider/offers/$offerId/responses', {
      'client_command_id': clientCommandId,
      'action': accept ? 'accept' : 'decline',
    }),
    _requestFromJson,
  );

  Future<http.Response> _post(String path, Map<String, Object?> body) => client
      .post(
        Uri.parse('$_baseUrl$path'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      )
      .timeout(_timeout);

  Future<T> _request<T>(
    Future<http.Response> future,
    T Function(Map<String, dynamic>) convert,
  ) async => convert(JsonReader.map(_decode(await future), 'data'));

  Object? _decode(http.Response response) {
    Object? envelope;
    try {
      envelope = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HelpNowApiException(response.statusCode);
    }
    if (envelope is! Map<String, dynamic>) {
      throw HelpNowApiException(response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HelpNowApiException(
        response.statusCode,
        envelope['message'] as String?,
      );
    }
    return envelope['data'];
  }
}

const _timeout = Duration(seconds: 12);
const _jsonHeaders = {'Content-Type': 'application/json'};

HelpNowRequest _requestFromJson(Map<String, dynamic> json) => HelpNowRequest(
  id: JsonReader.string(json, 'id'),
  clientId: JsonReader.string(json, 'client_id'),
  categoryId: JsonReader.string(json, 'category_id'),
  categoryName: JsonReader.string(json, 'category_name'),
  note: JsonReader.optionalString(json, 'note') ?? '',
  address: JsonReader.string(json, 'address'),
  status: switch (JsonReader.string(json, 'status')) {
    'assigned' => HelpNowStatus.assigned,
    'no_provider' => HelpNowStatus.noProvider,
    'cancelled' => HelpNowStatus.cancelled,
    _ => HelpNowStatus.searching,
  },
  wave: JsonReader.integer(json, 'wave'),
  assignedProviderName:
      JsonReader.optionalString(json, 'assigned_provider_name') ?? '',
  serviceRequestId: JsonReader.optionalString(json, 'service_request_id') ?? '',
  createdAt: DateTime.parse(JsonReader.string(json, 'created_at')).toLocal(),
  searchExpiresAt: DateTime.parse(
    JsonReader.string(json, 'search_expires_at'),
  ).toLocal(),
);

HelpNowAvailability _availabilityFromJson(Map<String, dynamic> json) =>
    HelpNowAvailability(
      enabled: JsonReader.boolean(json, 'enabled'),
      latitude: JsonReader.decimal(json, 'latitude'),
      longitude: JsonReader.decimal(json, 'longitude'),
      maxDistanceKm: JsonReader.integer(json, 'max_distance_km'),
      expiresAt: DateTime.tryParse(
        JsonReader.optionalString(json, 'expires_at') ?? '',
      )?.toLocal(),
    );

HelpNowOffer _offerFromJson(Map<String, dynamic> json) => HelpNowOffer(
  id: JsonReader.string(json, 'id'),
  requestId: JsonReader.string(json, 'request_id'),
  categoryId: JsonReader.string(json, 'category_id'),
  categoryName: JsonReader.string(json, 'category_name'),
  note: JsonReader.optionalString(json, 'note') ?? '',
  area: JsonReader.optionalString(json, 'area') ?? 'Região próxima',
  distanceMeters: JsonReader.integer(json, 'distance_meters'),
  expiresAt: DateTime.parse(JsonReader.string(json, 'expires_at')).toLocal(),
);

class HelpNowApiException implements Exception {
  const HelpNowApiException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
}

bool isHelpNowNetworkError(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;
