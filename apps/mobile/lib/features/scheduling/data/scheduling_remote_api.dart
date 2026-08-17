import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/entities/provider_schedule.dart';

class SchedulingApiException implements Exception {
  const SchedulingApiException(this.statusCode, {this.message, this.cause});
  final int statusCode;
  final String? message;
  final Object? cause;
}

class SchedulingRemoteApi {
  SchedulingRemoteApi({
    required this.client,
    required String baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  final http.Client client;
  final String _baseUrl;
  final Duration timeout;

  Future<ProviderSchedule> getSchedule() async => _decodeSchedule(
    await _perform(
      () => client.get(Uri.parse('$_baseUrl/v1/provider/schedule')),
    ),
  );

  Future<ProviderSchedule> saveSchedule(ProviderSchedule schedule) async =>
      _decodeSchedule(
        await _perform(
          () => client.put(
            Uri.parse('$_baseUrl/v1/provider/schedule'),
            headers: _headers,
            body: jsonEncode(_scheduleBody(schedule)),
          ),
        ),
      );

  Future<ScheduleBlock> addBlock(ScheduleBlockDraft draft) async {
    final response = await _perform(
      () => client.post(
        Uri.parse('$_baseUrl/v1/provider/schedule/blocks'),
        headers: _headers,
        body: jsonEncode({
          'starts_at': draft.startsAt.toUtc().toIso8601String(),
          'ends_at': draft.endsAt.toUtc().toIso8601String(),
          'reason': draft.reason,
        }),
      ),
    );
    return _block(_data(response));
  }

  Future<void> deleteBlock(String id) async {
    await _perform(
      () => client.delete(
        Uri.parse(
          '$_baseUrl/v1/provider/schedule/blocks/${Uri.encodeComponent(id)}',
        ),
      ),
    );
  }

  Future<AvailableSlotPage> getSlots(
    String serviceId, {
    String? cursor,
    required int limit,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final response = await _perform(
      () => client.get(
        Uri.parse(
          '$_baseUrl/v1/services/${Uri.encodeComponent(serviceId)}/available-slots',
        ).replace(queryParameters: query),
      ),
    );
    final data = _data(response);
    final raw = data['slots'];
    if (raw is! List) throw const SchedulingApiException(-1, message: 'slots');
    return AvailableSlotPage(
      slots: List.unmodifiable(
        raw.map((item) => DateTime.parse(item as String).toLocal()),
      ),
      nextCursor: switch (data['next_cursor']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
    );
  }

  Future<http.Response> _perform(
    Future<http.Response> Function() operation,
  ) async {
    try {
      final response = await operation().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      String? message;
      try {
        message =
            (jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>)['message']
                as String?;
      } catch (_) {}
      throw SchedulingApiException(response.statusCode, message: message);
    } on SchedulingApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw SchedulingApiException(0, cause: error);
    } on SocketException catch (error) {
      throw SchedulingApiException(0, cause: error);
    } on http.ClientException catch (error) {
      throw SchedulingApiException(0, cause: error);
    } on FormatException catch (error) {
      throw SchedulingApiException(-1, cause: error);
    } on TypeError catch (error) {
      throw SchedulingApiException(-1, cause: error);
    }
  }

  ProviderSchedule _decodeSchedule(http.Response response) {
    final data = _data(response);
    return ProviderSchedule(
      timeZone: data['time_zone'] as String,
      minimumNoticeMinutes: data['minimum_notice_minutes'] as int,
      bookingHorizonDays: data['booking_horizon_days'] as int,
      bufferMinutes: data['buffer_minutes'] as int,
      slotIntervalMinutes: data['slot_interval_minutes'] as int,
      version: data['version'] as int,
      rules: List.unmodifiable(
        (data['rules'] as List).map((item) {
          final rule = item as Map<String, dynamic>;
          return AvailabilityRule(
            weekday: rule['weekday'] as int,
            startMinute: rule['start_minute'] as int,
            endMinute: rule['end_minute'] as int,
          );
        }),
      ),
      blocks: List.unmodifiable(
        (data['blocks'] as List).map(
          (item) => _block(item as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> _data(http.Response response) {
    final envelope =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return envelope['data'] as Map<String, dynamic>;
  }

  ScheduleBlock _block(Map<String, dynamic> json) => ScheduleBlock(
    id: json['id'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    reason: json['reason'] as String,
  );
}

const _headers = {'Content-Type': 'application/json'};
Map<String, Object> _scheduleBody(ProviderSchedule schedule) => {
  'expected_version': schedule.version,
  'time_zone': schedule.timeZone,
  'minimum_notice_minutes': schedule.minimumNoticeMinutes,
  'booking_horizon_days': schedule.bookingHorizonDays,
  'buffer_minutes': schedule.bufferMinutes,
  'slot_interval_minutes': schedule.slotIntervalMinutes,
  'rules': schedule.rules
      .map(
        (rule) => {
          'weekday': rule.weekday,
          'start_minute': rule.startMinute,
          'end_minute': rule.endMinute,
        },
      )
      .toList(growable: false),
};
