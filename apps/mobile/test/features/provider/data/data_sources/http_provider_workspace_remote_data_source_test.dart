import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/provider/data/data_sources/http_provider_workspace_remote_data_source.dart';
import 'package:help/features/provider/domain/entities/provider_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('carrega toda a área profissional em uma única chamada', () async {
    var calls = 0;
    late http.Request captured;
    final source = HttpProviderWorkspaceRemoteDataSource(
      client: MockClient((request) async {
        calls++;
        captured = request;
        return http.Response(
          jsonEncode(_homeResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'https://api.example.com/',
    );

    final workspace = (await source.fetchHome()).toEntity();

    expect(calls, 1);
    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://api.example.com/v1/provider/home');
    expect(workspace.provider.displayName, 'Luis');
    expect(workspace.services.single.title, 'Limpeza residencial');
  });

  test('envia criação de serviço pelo contrato autenticável da API', () async {
    late http.Request captured;
    final source = HttpProviderWorkspaceRemoteDataSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'data': _service}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    await source.createService(
      const ProviderServiceDraft(
        title: 'Limpeza residencial',
        description: 'Limpeza completa do imóvel.',
        categoryId: '',
        durationMinutes: 120,
        priceCents: 15000,
        imageUrl: '',
        published: true,
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/provider/services');
    expect(body['price_cents'], 15000);
    expect(body['published'], isTrue);
  });
}

const _service = {
  'id': 'service-1',
  'category_id': '',
  'title': 'Limpeza residencial',
  'description': 'Limpeza completa do imóvel.',
  'duration_minutes': 120,
  'price_cents': 15000,
  'image_url': '',
  'rating': 0,
  'reviews': 0,
  'published': true,
  'updated_at': '2026-08-14T19:00:00Z',
};

const _homeResponse = {
  'data': {
    'provider': {
      'id': 'provider-1',
      'display_name': 'Luis',
      'status': 'approved',
      'active': true,
      'accepting_requests': true,
    },
    'location': {
      'address': 'Manaus, AM',
      'latitude': -3.08,
      'longitude': -59.97,
    },
    'summary': {
      'total_services': 1,
      'published_services': 1,
      'paused_services': 0,
      'pending_requests': 0,
      'unread_messages': 0,
      'unread_notifications': 0,
    },
    'alerts': <Object?>[],
    'categories': <Object?>[],
    'services': [_service],
    'recent_requests': <Object?>[],
    'notifications': <Object?>[],
  },
};
