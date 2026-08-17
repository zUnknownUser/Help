import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/service_requests/data/service_request_remote_api.dart';
import 'package:help/features/service_requests/domain/entities/service_request_item.dart';
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
}

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
