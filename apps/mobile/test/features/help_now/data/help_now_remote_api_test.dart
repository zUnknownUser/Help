import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:help/features/help_now/data/help_now_remote_api.dart';
import 'package:help/features/help_now/domain/entities/help_now_request.dart';

void main() {
  test('creates an urgent request with the stable client id', () async {
    late Map<String, dynamic> sent;
    final api = HelpNowRemoteApi(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/help-now/requests');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'data': _requestJson()}, 201);
      }),
    );

    final request = await api.create({
      'client_id': 'client-1',
      'category_id': 'plumbing',
      'note': 'Vazamento',
      'address_label': 'Casa',
      'address': 'Rua A, 10',
      'latitude': -3.1,
      'longitude': -60.0,
    });

    expect(sent['client_id'], 'client-1');
    expect(request.status, HelpNowStatus.searching);
    expect(request.categoryName, 'Encanamento');
  });

  test('decodes provider offers and sends an idempotent acceptance', () async {
    var calls = 0;
    final api = HelpNowRemoteApi(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        calls++;
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': {
              'items': [
                {
                  'id': 'offer-1',
                  'request_id': 'request-1',
                  'category_id': 'plumbing',
                  'category_name': 'Encanamento',
                  'note': 'Vazamento',
                  'area': 'Centro - Manaus',
                  'distance_meters': 850,
                  'wave': 1,
                  'offered_at': '2026-08-17T00:00:00Z',
                  'expires_at': '2026-08-17T00:00:25Z',
                },
              ],
            },
          }, 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_command_id'], 'command-1');
        expect(body['action'], 'accept');
        return _jsonResponse({'data': _requestJson(status: 'assigned')}, 200);
      }),
    );

    final offers = await api.offers();
    final accepted = await api.respond(
      offerId: offers.single.id,
      clientCommandId: 'command-1',
      accept: true,
    );

    expect(offers.single.distanceLabel, '850 m');
    expect(accepted.status, HelpNowStatus.assigned);
    expect(calls, 2);
  });

  test('preserves the server message on a conflict', () async {
    final api = HelpNowRemoteApi(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => _jsonResponse({
          'message': 'Este chamado não está mais disponível.',
        }, 409),
      ),
    );

    await expectLater(
      api.respond(
        offerId: 'offer-1',
        clientCommandId: 'command-1',
        accept: true,
      ),
      throwsA(
        isA<HelpNowApiException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.message, 'message', contains('não está')),
      ),
    );
  });
}

Map<String, Object?> _requestJson({String status = 'searching'}) => {
  'id': 'request-1',
  'client_id': 'client-1',
  'category_id': 'plumbing',
  'category_name': 'Encanamento',
  'note': 'Vazamento',
  'address': 'Rua A, 10',
  'status': status,
  'wave': 1,
  'assigned_provider_name': status == 'assigned' ? 'Luís' : '',
  'service_request_id': status == 'assigned' ? 'service-request-1' : '',
  'created_at': '2026-08-17T00:00:00Z',
  'updated_at': '2026-08-17T00:00:00Z',
  'search_expires_at': '2026-08-17T00:03:00Z',
};

http.Response _jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
