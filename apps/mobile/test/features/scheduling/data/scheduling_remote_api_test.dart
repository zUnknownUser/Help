import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/scheduling/data/scheduling_remote_api.dart';
import 'package:help/features/scheduling/domain/entities/provider_schedule.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('envia contrato versionado da agenda', () async {
    late Map<String, dynamic> body;
    final api = SchedulingRemoteApi(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/provider/schedule');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'data': _scheduleJson(version: 4)}),
          200,
        );
      }),
      baseUrl: 'https://api.example.com/',
    );

    final saved = await api.saveSchedule(_schedule);

    expect(body['expected_version'], 3);
    expect((body['rules'] as List).single, {
      'weekday': 1,
      'start_minute': 480,
      'end_minute': 1080,
    });
    expect(saved.version, 4);
  });

  test('pagina slots por cursor e converte para horário local', () async {
    final api = SchedulingRemoteApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters, {
          'limit': '20',
          'cursor': 'opaque',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'slots': ['2026-08-17T13:00:00Z'],
              'next_cursor': 'next',
            },
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    final page = await api.getSlots('service 1', cursor: 'opaque', limit: 20);

    expect(page.slots.single.toUtc(), DateTime.utc(2026, 8, 17, 13));
    expect(page.nextCursor, 'next');
  });
}

const _schedule = ProviderSchedule(
  timeZone: 'America/Manaus',
  minimumNoticeMinutes: 60,
  bookingHorizonDays: 60,
  bufferMinutes: 15,
  slotIntervalMinutes: 30,
  version: 3,
  rules: [AvailabilityRule(weekday: 1, startMinute: 480, endMinute: 1080)],
  blocks: [],
);
Map<String, dynamic> _scheduleJson({required int version}) => {
  'time_zone': 'America/Manaus',
  'minimum_notice_minutes': 60,
  'booking_horizon_days': 60,
  'buffer_minutes': 15,
  'slot_interval_minutes': 30,
  'version': version,
  'rules': [
    {'weekday': 1, 'start_minute': 480, 'end_minute': 1080},
  ],
  'blocks': [],
};
