import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/data_sources/http_home_interaction_remote_data_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:help/features/home/domain/entities/home_location.dart';

void main() {
  test('salva o endereço padrão no perfil autenticado', () async {
    late http.Request captured;
    final dataSource = HttpHomeInteractionRemoteDataSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
      baseUrl: 'https://api.example.com/',
    );

    await dataSource.saveLocation(
      const HomeLocation(
        availabilityLabel: 'Casa',
        address: 'Rua A, 100',
        postalCode: '69000000',
        street: 'Rua A',
        streetNumber: '100',
        district: 'Centro',
        city: 'Manaus',
        state: 'AM',
        latitude: -3.1,
        longitude: -60,
      ),
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/v1/profile/location');
    expect(jsonDecode(captured.body), {
      'label': 'Casa',
      'address': 'Rua A, 100',
      'postal_code': '69000000',
      'street': 'Rua A',
      'street_number': '100',
      'complement': '',
      'district': 'Centro',
      'city': 'Manaus',
      'state': 'AM',
      'latitude': -3.1,
      'longitude': -60.0,
    });
  });
}
