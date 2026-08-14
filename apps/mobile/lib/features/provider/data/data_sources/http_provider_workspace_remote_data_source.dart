import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/provider_service.dart';
import '../errors/provider_data_exception.dart';
import '../models/provider_json.dart';
import '../models/provider_service_model.dart';
import '../models/provider_workspace_model.dart';
import 'provider_workspace_remote_data_source.dart';

class HttpProviderWorkspaceRemoteDataSource
    implements ProviderWorkspaceRemoteDataSource {
  HttpProviderWorkspaceRemoteDataSource({
    required this.client,
    required String baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client client;
  final String _baseUrl;
  final Duration timeout;

  Uri get _home => Uri.parse('$_baseUrl/v1/provider/home');
  Uri get _services => Uri.parse('$_baseUrl/v1/provider/services');
  Uri get _availability => Uri.parse('$_baseUrl/v1/provider/availability');

  @override
  Future<ProviderWorkspaceModel> fetchHome() async {
    final response = await _perform(() => client.get(_home));
    return _decode(response, ProviderWorkspaceModel.fromEnvelope);
  }

  @override
  Future<ProviderServiceModel> createService(ProviderServiceDraft draft) async {
    final response = await _perform(
      () => client.post(
        _services,
        headers: _jsonHeaders,
        body: jsonEncode(_draftJson(draft)),
      ),
    );
    return _decodeService(response);
  }

  @override
  Future<ProviderServiceModel> updateService(
    String id,
    ProviderServiceDraft draft,
  ) async {
    final response = await _perform(
      () => client.put(
        Uri.parse('$_baseUrl/v1/provider/services/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(_draftJson(draft)),
      ),
    );
    return _decodeService(response);
  }

  @override
  Future<ProviderServiceModel> setPublished(String id, bool published) async {
    final response = await _perform(
      () => client.patch(
        Uri.parse('$_baseUrl/v1/provider/services/$id/publication'),
        headers: _jsonHeaders,
        body: jsonEncode({'published': published}),
      ),
    );
    return _decodeService(response);
  }

  @override
  Future<void> deleteService(String id) async {
    await _perform(
      () => client.delete(Uri.parse('$_baseUrl/v1/provider/services/$id')),
    );
  }

  @override
  Future<void> setAvailability(bool acceptingRequests) async {
    await _perform(
      () => client.patch(
        _availability,
        headers: _jsonHeaders,
        body: jsonEncode({'accepting_requests': acceptingRequests}),
      ),
    );
  }

  Future<http.Response> _perform(
    Future<http.Response> Function() operation,
  ) async {
    try {
      final response = await operation().timeout(timeout);
      _ensureSuccess(response);
      return response;
    } on ProviderDataException {
      rethrow;
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  T _decode<T>(
    http.Response response,
    T Function(Map<String, dynamic>) decoder,
  ) {
    try {
      final json = ProviderJson.map(
        jsonDecode(utf8.decode(response.bodyBytes)),
        'response',
      );
      return decoder(json);
    } on FormatException catch (error) {
      throw ProviderDataException(
        ProviderDataErrorCode.invalidResponse,
        debugMessage: error.message,
      );
    } on TypeError catch (error) {
      throw ProviderDataException(
        ProviderDataErrorCode.invalidResponse,
        debugMessage: '$error',
      );
    }
  }

  ProviderServiceModel _decodeService(http.Response response) => _decode(
    response,
    (json) =>
        ProviderServiceModel.fromJson(ProviderJson.map(json['data'], 'data')),
  );

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final code = switch (response.statusCode) {
      HttpStatus.badRequest => ProviderDataErrorCode.invalidData,
      HttpStatus.forbidden => ProviderDataErrorCode.forbidden,
      HttpStatus.notFound => ProviderDataErrorCode.notFound,
      _ => ProviderDataErrorCode.unavailable,
    };
    throw ProviderDataException(code);
  }

  ProviderDataException _networkError(Object error) => ProviderDataException(
    ProviderDataErrorCode.network,
    debugMessage: '$error',
  );
}

const _jsonHeaders = {'Content-Type': 'application/json'};

Map<String, Object> _draftJson(ProviderServiceDraft draft) => {
  'title': draft.title,
  'description': draft.description,
  'category_id': draft.categoryId,
  'duration_minutes': draft.durationMinutes,
  'price_cents': draft.priceCents,
  'image_url': draft.imageUrl,
  'published': draft.published,
};
