import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/notifications/data/device_registration_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('limits an unavailable device registration request', () async {
    final api = DeviceRegistrationApi(
      client: MockClient((_) => Completer<http.Response>().future),
      baseUrl: 'https://api.example.com',
      requestTimeout: Duration.zero,
    );

    await expectLater(
      api.register(
        installationId: 'installation-1',
        platform: 'android',
        token: 'token',
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
