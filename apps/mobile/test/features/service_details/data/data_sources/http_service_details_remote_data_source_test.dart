import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/service_details/data/data_sources/http_service_details_remote_data_source.dart';
import 'package:help/features/service_details/domain/entities/service_request.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('carrega detalhes e contexto de solicitação por id', () async {
    late http.Request captured;
    final source = HttpServiceDetailsRemoteDataSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'data': _details}), 200);
      }),
      baseUrl: 'https://api.example.com/',
    );

    final details = (await source.fetch('service-1')).entity;

    expect(captured.method, 'GET');
    expect(captured.url.path, '/v1/services/service-1');
    expect(details.providerUserId, 'provider-user');
    expect(details.requestAddress?.label, 'Casa');
    expect(details.offer.priceCents, 15900);
  });

  test(
    'envia idempotency key, horário UTC e somente a intenção do cliente',
    () async {
      late http.Request captured;
      final source = HttpServiceDetailsRemoteDataSource(
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'data': _receipt}), 201);
        }),
        baseUrl: 'https://api.example.com',
      );
      final scheduled = DateTime.parse('2026-08-17T12:00:00-04:00');

      await source.createRequest(
        'service-1',
        ServiceRequestDraft(
          clientRequestId: 'c349a83e-fbd9-4d59-984d-0516b7f981b2',
          scheduledFor: scheduled,
          note: '  Levar material  ',
        ),
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.url.path, '/v1/services/service-1/requests');
      expect(body['client_request_id'], 'c349a83e-fbd9-4d59-984d-0516b7f981b2');
      expect(body['scheduled_for'], '2026-08-17T16:00:00.000Z');
      expect(body['note'], 'Levar material');
      expect(body, isNot(contains('quoted_price_cents')));
      expect(body, isNot(contains('provider_id')));
      expect(body, isNot(contains('address')));
    },
  );
}

const _details = {
  'id': 'service-1',
  'title': 'Limpeza',
  'description': 'Limpeza completa',
  'category_id': '',
  'rating': 4.8,
  'reviews': 12,
  'duration_minutes': 90,
  'price_cents': 15900,
  'old_price_cents': 15900,
  'image_url': '',
  'image_alignment': 0.0,
  'badge': '',
  'distance_km': 2.4,
  'service_area': 'Manaus - AM',
  'provider': {
    'id': 'provider-1',
    'user_id': 'provider-user',
    'name': 'Luis',
    'verified': true,
  },
  'request': {
    'can_request': true,
    'blocked_reason': '',
    'address': {
      'label': 'Casa',
      'formatted_address': 'Rua A, 10',
      'latitude': -3.08,
      'longitude': -59.97,
    },
  },
};

const _receipt = {
  'id': 'request-1',
  'client_request_id': 'c349a83e-fbd9-4d59-984d-0516b7f981b2',
  'service_id': 'service-1',
  'service_title': 'Limpeza',
  'provider_name': 'Luis',
  'status': 'pending',
  'scheduled_for': '2026-08-17T16:00:00Z',
  'quoted_price_cents': 15900,
  'address': {'label': 'Casa', 'formatted_address': 'Rua A, 10'},
};
