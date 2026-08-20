import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/service_requests/data/service_request_remote_api.dart';
import 'package:help/features/service_requests/domain/entities/service_request_item.dart';
import 'package:help/features/service_requests/domain/entities/service_request_negotiation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends idempotent versioned transition contract', () async {
    late http.Request captured;
    final api = ServiceRequestRemoteApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'data': _requestJson(status: 'accepted', version: 1)}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'http://localhost:8080',
    );

    final result = await api.transition(
      id: 'request-1',
      clientCommandId: 'command-1',
      target: ServiceRequestStatus.accepted,
      expectedVersion: 0,
      reason: '',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.url.path, '/v1/service-requests/request-1/transitions');
    expect(body['client_command_id'], 'command-1');
    expect(body['expected_version'], 0);
    expect(result.status, ServiceRequestStatus.accepted);
  });

  test('sends idempotent reschedule contract', () async {
    late http.Request captured;
    final api = ServiceRequestRemoteApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'data': _requestJson(status: 'pending', version: 2)}),
          200,
        );
      }),
      baseUrl: 'http://localhost:8080/',
    );
    final scheduled = DateTime(2026, 8, 18, 14);

    final result = await api.reschedule(
      id: 'request-1',
      clientCommandId: 'stable-command',
      scheduledFor: scheduled,
      expectedVersion: 1,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.url.path, '/v1/service-requests/request-1/reschedule');
    expect(body['client_command_id'], 'stable-command');
    expect(DateTime.parse(body['scheduled_for'] as String), scheduled.toUtc());
    expect(result.version, 2);
  });

  test('loads a bounded provider agenda range', () async {
    late Uri captured;
    final api = ServiceRequestRemoteApi(
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'data': {
              'items': [_requestJson(status: 'accepted', version: 1)],
            },
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8080',
    );
    final from = DateTime(2026, 8, 17);
    final to = from.add(const Duration(days: 7));

    final items = await api.agenda(from: from, to: to);

    expect(captured.path, '/v1/provider/agenda');
    expect(captured.queryParameters['limit'], '500');
    expect(items.single.status, ServiceRequestStatus.accepted);
  });

  test('parses private attachments and itemized quote negotiation', () async {
    final api = ServiceRequestRemoteApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'request': _requestJson(status: 'pending', version: 0),
              'negotiation': _negotiationJson(),
            },
          }),
          200,
        ),
      ),
      baseUrl: 'http://localhost:8080',
    );

    final update = await api.negotiation('request-1');

    expect(update.negotiation.attachments.single.canDelete, isTrue);
    expect(update.negotiation.latestQuote?.totalCents, 17500);
    expect(
      update.negotiation.latestQuote?.items.last.kind,
      ServiceQuoteItemKind.discount,
    );
    expect(update.negotiation.canPropose, isFalse);
  });

  test('sends versioned itemized counteroffer contract', () async {
    late http.Request captured;
    final api = ServiceRequestRemoteApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'request': _requestJson(status: 'pending', version: 0),
              'negotiation': _negotiationJson(),
            },
          }),
          201,
        );
      }),
      baseUrl: 'http://localhost:8080',
    );
    final expiry = DateTime.utc(2026, 8, 26, 12);

    await api.proposeQuote(
      request: ServiceRequestItemModelForTest.entity,
      clientCommandId: 'quote-command',
      draft: ServiceQuoteDraft(
        expiresAt: expiry,
        message: 'Inclui material',
        items: const [
          ServiceQuoteItemDraft(
            kind: ServiceQuoteItemKind.material,
            description: 'Resistência',
            amountCents: 7500,
          ),
        ],
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;
    expect(captured.url.path, '/v1/service-requests/request-1/quotes');
    expect(body['expected_version'], 0);
    expect(body['expires_at'], expiry.toIso8601String());
    expect((items.single as Map<String, dynamic>)['kind'], 'material');
  });
}

abstract final class ServiceRequestItemModelForTest {
  static final entity = ServiceRequestItem(
    id: 'request-1',
    clientRequestId: 'client-1',
    serviceId: 'service-1',
    serviceTitle: 'Limpeza',
    providerUserId: 'provider-user',
    providerName: 'Luis',
    customerName: 'Ana',
    customerUserId: 'customer-user',
    viewerRole: RequestViewerRole.provider,
    status: ServiceRequestStatus.pending,
    statusReason: '',
    version: 0,
    availableActions: const {},
    note: '',
    scheduledFor: DateTime.utc(2026, 8, 17, 15),
    quotedPriceCents: 15000,
    addressLabel: 'Casa',
    address: 'Rua A, 10',
    createdAt: DateTime.utc(2026, 8, 16, 12),
    updatedAt: DateTime.utc(2026, 8, 16, 12),
  );
}

Map<String, dynamic> _negotiationJson() => {
  'attachments': [
    {
      'id': 'attachment-1',
      'uploader_name': 'Luis',
      'uploader_role': 'provider',
      'caption': 'Antes',
      'content_type': 'image/jpeg',
      'byte_size': 1200,
      'url': '/v1/service-request-attachments/attachment-1',
      'created_at': '2026-08-19T12:00:00Z',
      'can_delete': true,
    },
  ],
  'quotes': [
    {
      'id': 'quote-1',
      'author_name': 'Luis',
      'author_role': 'provider',
      'revision': 1,
      'status': 'proposed',
      'currency': 'BRL',
      'total_cents': 17500,
      'message': 'Inclui material',
      'items': [
        {
          'id': 'item-1',
          'kind': 'labor',
          'description': 'Mão de obra',
          'amount_cents': 15000,
          'position': 0,
        },
        {
          'id': 'item-2',
          'kind': 'material',
          'description': 'Material',
          'amount_cents': 5000,
          'position': 1,
        },
        {
          'id': 'item-3',
          'kind': 'discount',
          'description': 'Desconto',
          'amount_cents': 2500,
          'position': 2,
        },
      ],
      'expires_at': '2026-08-26T12:00:00Z',
      'accepted_at': null,
      'created_at': '2026-08-19T12:00:00Z',
      'can_accept': false,
    },
  ],
  'can_add_attachment': true,
  'can_propose': false,
};

Map<String, dynamic> _requestJson({
  required String status,
  required int version,
}) => {
  'id': 'request-1',
  'client_request_id': 'client-1',
  'service_id': 'service-1',
  'service_title': 'Limpeza',
  'provider_user_id': 'provider-user',
  'provider_name': 'Luis',
  'customer_user_id': 'customer-user',
  'customer_name': 'Ana',
  'viewer_role': 'provider',
  'status': status,
  'status_reason': '',
  'version': version,
  'available_actions': <String>[],
  'note': '',
  'scheduled_for': '2026-08-17T15:00:00Z',
  'quoted_price_cents': 15000,
  'address': {'label': 'Casa', 'formatted_address': 'Rua A, 10'},
  'created_at': '2026-08-16T12:00:00Z',
  'updated_at': '2026-08-16T12:01:00Z',
};
