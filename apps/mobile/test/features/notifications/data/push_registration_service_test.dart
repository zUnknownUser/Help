import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/notifications/data/device_registration_api.dart';
import 'package:help/features/notifications/data/push_messaging_gateway.dart';
import 'package:help/features/notifications/data/push_registration_service.dart';

void main() {
  test('registers token and refreshes it for the same installation', () async {
    final gateway = _MessagingGateway(AuthorizationStatus.authorized);
    final registrar = _Registrar();
    final service = PushRegistrationService(
      messaging: gateway,
      api: registrar,
      installationId: () async => 'installation-1',
      supportedPlatform: true,
    );

    await service.start();
    gateway.refresh.add('token-2');
    await Future<void>.delayed(Duration.zero);

    expect(registrar.tokens, ['token-1', 'token-2']);
    expect(registrar.installations, ['installation-1', 'installation-1']);
    await service.unregister();
    expect(registrar.disabled, 'installation-1');
    await gateway.close();
  });

  test(
    'a denied permission does not permanently block a later retry',
    () async {
      final gateway = _MessagingGateway(AuthorizationStatus.denied);
      final registrar = _Registrar();
      final service = PushRegistrationService(
        messaging: gateway,
        api: registrar,
        installationId: () async => 'installation-1',
        supportedPlatform: true,
      );

      await service.start();
      expect(registrar.tokens, isEmpty);
      gateway.status = AuthorizationStatus.authorized;
      await service.start();
      expect(registrar.tokens, ['token-1']);
      await service.unregister();
      await gateway.close();
    },
  );

  test('retries device registration after a transient API failure', () async {
    final gateway = _MessagingGateway(AuthorizationStatus.authorized);
    final registrar = _Registrar()..failures = 1;
    final service = PushRegistrationService(
      messaging: gateway,
      api: registrar,
      installationId: () async => 'installation-1',
      supportedPlatform: true,
      registrationRetryDelay: Duration.zero,
    );

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(registrar.attempts, 2);
    expect(registrar.tokens, ['token-1']);
    await service.unregister();
    await gateway.close();
  });

  test('routes a conversation request to the chat target', () async {
    final gateway = _MessagingGateway(AuthorizationStatus.authorized);
    final service = PushRegistrationService(
      messaging: gateway,
      api: _Registrar(),
      installationId: () async => 'installation-1',
      supportedPlatform: true,
    );
    final event = service.events.first;

    await service.start();
    gateway.foreground.add(
      const RemoteMessage(
        data: {'type': 'chat_request', 'conversation_id': 'conversation-1'},
      ),
    );

    expect((await event).targetId, 'conversation-1');
    await service.unregister();
    await gateway.close();
  });

  test('does not hold logout when device unregister is unavailable', () async {
    final gateway = _MessagingGateway(AuthorizationStatus.authorized);
    final registrar = _Registrar()..hangDisable = true;
    final service = PushRegistrationService(
      messaging: gateway,
      api: registrar,
      installationId: () async => 'installation-1',
      supportedPlatform: true,
      unregisterTimeout: Duration.zero,
    );

    await service.start();
    await service.unregister();

    expect(registrar.disabled, isNull);
    await gateway.close();
  });
}

class _MessagingGateway implements PushMessagingGateway {
  _MessagingGateway(this.status);
  AuthorizationStatus status;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<RemoteMessage>.broadcast();
  final opened = StreamController<RemoteMessage>.broadcast();

  @override
  Stream<RemoteMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<RemoteMessage> get openedMessages => opened.stream;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Future<RemoteMessage?> initialMessage() async => null;
  @override
  Future<NotificationSettings> notificationSettings() async =>
      _settings(status);
  @override
  Future<NotificationSettings> requestPermission() async => _settings(status);
  @override
  Future<String?> token() async => 'token-1';

  Future<void> close() async {
    await refresh.close();
    await foreground.close();
    await opened.close();
  }
}

class _Registrar implements DeviceRegistrar {
  final tokens = <String>[];
  final installations = <String>[];
  String? disabled;
  int failures = 0;
  int attempts = 0;
  bool hangDisable = false;

  @override
  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
  }) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw StateError('temporary');
    }
    installations.add(installationId);
    tokens.add(token);
  }

  @override
  Future<void> disable(String installationId) async {
    if (hangDisable) return Completer<void>().future;
    disabled = installationId;
  }
}

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );
