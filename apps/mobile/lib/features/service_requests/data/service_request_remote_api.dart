import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../home/data/models/json_reader.dart';
import '../domain/entities/service_request_item.dart';
import '../domain/entities/service_request_negotiation.dart';
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

  Future<ServiceRequestNegotiationUpdate> negotiation(String requestId) async {
    final data = _data(
      await client
          .get(Uri.parse('$_baseUrl/v1/service-requests/$requestId/negotiation'))
          .timeout(_timeout),
    );
    return _negotiationUpdate(data);
  }

  Future<ServiceRequestNegotiationUpdate> proposeQuote({
    required ServiceRequestItem request,
    required String clientCommandId,
    required ServiceQuoteDraft draft,
  }) async {
    final response = await client
        .post(
          Uri.parse('$_baseUrl/v1/service-requests/${request.id}/quotes'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_command_id': clientCommandId,
            'expected_version': request.version,
            'message': draft.message.trim(),
            if (draft.expiresAt != null)
              'expires_at': draft.expiresAt!.toUtc().toIso8601String(),
            'items': draft.items
                .map(
                  (item) => {
                    'kind': item.kind.name,
                    'description': item.description.trim(),
                    'amount_cents': item.amountCents,
                  },
                )
                .toList(growable: false),
          }),
        )
        .timeout(_timeout);
    return _negotiationUpdate(_data(response));
  }

  Future<ServiceRequestNegotiationUpdate> acceptQuote({
    required ServiceRequestItem request,
    required String quoteId,
    required String clientCommandId,
  }) async {
    final response = await client
        .post(
          Uri.parse(
            '$_baseUrl/v1/service-requests/${request.id}/quotes/$quoteId/accept',
          ),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_command_id': clientCommandId,
            'expected_version': request.version,
          }),
        )
        .timeout(_timeout);
    return _negotiationUpdate(_data(response));
  }

  Future<ServiceRequestAttachment> uploadAttachment({
    required String requestId,
    required String filePath,
    String caption = '',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/v1/service-requests/$requestId/attachments'),
    )..fields['caption'] = caption.trim();
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await client.send(request).timeout(_uploadTimeout);
    final response = await http.Response.fromStream(streamed);
    return _attachment(_data(response));
  }

  Future<void> deleteAttachment({
    required String requestId,
    required String attachmentId,
  }) async {
    final response = await client
        .delete(
          Uri.parse(
            '$_baseUrl/v1/service-requests/$requestId/attachments/$attachmentId',
          ),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        message = (jsonDecode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>)['message']
            as String?;
      } catch (_) {}
      throw ServiceRequestApiException(response.statusCode, message);
    }
  }

  Future<Uint8List> attachmentBytes(String attachmentId) async {
    final response = await client
        .get(
          Uri.parse(
            '$_baseUrl/v1/service-request-attachments/$attachmentId',
          ),
        )
        .timeout(_uploadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServiceRequestApiException(response.statusCode);
    }
    return response.bodyBytes;
  }

  ServiceRequestNegotiationUpdate _negotiationUpdate(
    Map<String, dynamic> data,
  ) {
    final request = ServiceRequestItemModel.fromJson(
      JsonReader.map(data['request'], 'request'),
    ).entity;
    final json = JsonReader.map(data['negotiation'], 'negotiation');
    return ServiceRequestNegotiationUpdate(
      request: request,
      negotiation: ServiceRequestNegotiation(
        attachments: JsonReader.maps(json['attachments'], 'attachments')
            .map(_attachment)
            .toList(growable: false),
        quotes: JsonReader.maps(json['quotes'], 'quotes')
            .map(_quote)
            .toList(growable: false),
        canAddAttachment: JsonReader.boolean(
          json,
          'can_add_attachment',
        ),
        canPropose: JsonReader.boolean(json, 'can_propose'),
      ),
    );
  }

  ServiceRequestAttachment _attachment(Map<String, dynamic> json) =>
      ServiceRequestAttachment(
        id: JsonReader.string(json, 'id'),
        uploaderName: JsonReader.string(json, 'uploader_name'),
        uploaderRole: RequestViewerRole.parse(
          JsonReader.string(json, 'uploader_role'),
        ),
        caption: JsonReader.optionalString(json, 'caption') ?? '',
        contentType: JsonReader.string(json, 'content_type'),
        byteSize: JsonReader.integer(json, 'byte_size'),
        url: JsonReader.string(json, 'url'),
        createdAt: DateTime.parse(JsonReader.string(json, 'created_at')),
        canDelete: JsonReader.boolean(json, 'can_delete'),
      );

  ServiceQuote _quote(Map<String, dynamic> json) => ServiceQuote(
    id: JsonReader.string(json, 'id'),
    authorName: JsonReader.string(json, 'author_name'),
    authorRole: RequestViewerRole.parse(
      JsonReader.string(json, 'author_role'),
    ),
    revision: JsonReader.integer(json, 'revision'),
    status: ServiceQuoteStatus.parse(JsonReader.string(json, 'status')),
    currency: JsonReader.string(json, 'currency'),
    totalCents: JsonReader.integer(json, 'total_cents'),
    message: JsonReader.optionalString(json, 'message') ?? '',
    items: JsonReader.maps(json['items'], 'items')
        .map(
          (item) => ServiceQuoteItem(
            id: JsonReader.string(item, 'id'),
            kind: ServiceQuoteItemKind.parse(JsonReader.string(item, 'kind')),
            description: JsonReader.string(item, 'description'),
            amountCents: JsonReader.integer(item, 'amount_cents'),
            position: JsonReader.integer(item, 'position'),
          ),
        )
        .toList(growable: false),
    expiresAt: _date(json['expires_at']),
    acceptedAt: _date(json['accepted_at']),
    createdAt: DateTime.parse(JsonReader.string(json, 'created_at')),
    canAccept: JsonReader.boolean(json, 'can_accept'),
  );

  DateTime? _date(Object? value) => value is String && value.isNotEmpty
      ? DateTime.parse(value)
      : null;

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
const _uploadTimeout = Duration(seconds: 30);

class ServiceRequestApiException implements Exception {
  const ServiceRequestApiException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
}

bool isServiceRequestNetworkError(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;
