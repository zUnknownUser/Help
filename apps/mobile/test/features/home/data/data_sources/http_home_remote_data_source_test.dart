import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/data_sources/http_home_remote_data_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('carrega toda a Home em uma única chamada GET', () async {
    var calls = 0;
    late http.Request captured;
    final client = MockClient((request) async {
      calls++;
      captured = request;
      return http.Response(
        jsonEncode(_response),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final dataSource = HttpHomeRemoteDataSource(
      client: client,
      baseUrl: 'https://api.example.com/',
    );

    final model = await dataSource.fetchHome();

    expect(calls, 1);
    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://api.example.com/v1/home');
    expect(model.toEntity().categories.single.name, 'Limpeza residencial');
    expect(model.toEntity().recommendedServices.single.priceCents, 7900);
  });
}

const _response = {
  'data': {
    'location': {
      'address': 'Av. Eduardo Ribeiro, 520',
      'availability_label': 'Serviços disponíveis',
    },
    'search_placeholder': 'Busque por um serviço',
    'categories_title': 'Serviços populares',
    'recommendations_title': 'Recomendados para você',
    'unread_notification_count': 0,
    'notifications': <Object?>[],
    'promotions': [
      {
        'id': 'promo',
        'eyebrow': 'Seu ar não está gelando?',
        'title': 'A gente resolve rápido.',
        'features': <Object?>[],
        'actions': <Object?>[],
      },
    ],
    'categories': [
      {'id': 'cleaning', 'name': 'Limpeza residencial', 'icon_key': 'home'},
    ],
    'recommended_services': [
      {
        'id': 'cleaning',
        'title': 'Limpeza residencial',
        'category_id': 'cleaning',
        'rating': 4.8,
        'reviews': 2300,
        'duration_minutes': 150,
        'price_cents': 7900,
        'old_price_cents': 9900,
        'image_alignment': 0.18,
        'provider': {'id': 'partner', 'name': 'Parceiro', 'verified': true},
      },
    ],
    'benefits': [
      {'id': 'verified', 'label': 'Verificados', 'icon_key': 'verified'},
    ],
  },
};
