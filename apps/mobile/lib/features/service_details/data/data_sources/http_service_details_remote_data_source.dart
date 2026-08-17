import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/service_request.dart';
import '../errors/service_details_data_exception.dart';
import '../models/service_details_model.dart';
import '../models/service_request_model.dart';
import 'service_details_remote_data_source.dart';

class HttpServiceDetailsRemoteDataSource
    implements ServiceDetailsRemoteDataSource {
  HttpServiceDetailsRemoteDataSource({
    required this.client,
    required String baseUrl,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client client;
  final String _baseUrl;

  @override
  Future<ServiceDetailsModel> fetch(String serviceId) async {
    final response = await client
        .get(Uri.parse('$_baseUrl/v1/services/$serviceId'))
        .timeout(const Duration(seconds: 8));
    return ServiceDetailsModel.fromJson(_data(response, expectedStatus: 200));
  }

  @override
  Future<ServiceRequestModel> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  ) async {
    final response = await client
        .post(
          Uri.parse('$_baseUrl/v1/services/$serviceId/requests'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_request_id': draft.clientRequestId,
            'scheduled_for': draft.scheduledFor.toUtc().toIso8601String(),
            'note': draft.note.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    return ServiceRequestModel.fromJson(_data(response, expectedStatus: 201));
  }

  Map<String, dynamic> _data(
    http.Response response, {
    required int expectedStatus,
  }) {
    Map<String, dynamic>? envelope;
    try {
      envelope =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      if (response.statusCode == expectedStatus) {
        throw const ServiceDetailsDataException(0);
      }
    }
    if (response.statusCode != expectedStatus) {
      throw ServiceDetailsDataException(
        response.statusCode,
        message: envelope?['message'] as String?,
      );
    }
    final data = envelope?['data'];
    if (data is! Map) throw const ServiceDetailsDataException(0);
    return Map<String, dynamic>.from(data);
  }
}

bool isServiceDetailsNetworkError(Object error) =>
    error is SocketException || error is http.ClientException;
