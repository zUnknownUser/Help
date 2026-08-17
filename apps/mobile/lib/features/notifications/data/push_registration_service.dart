import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import 'device_registration_api.dart';
import 'push_messaging_gateway.dart';

class PushRegistrationService {
  PushRegistrationService({
    required this.messaging,
    required this.api,
    required this.installationId,
    bool? supportedPlatform,
    this.registrationRetryDelay = const Duration(seconds: 2),
    this.unregisterTimeout = const Duration(seconds: 3),
  }) : _supportedOverride = supportedPlatform;

  final PushMessagingGateway messaging;
  final DeviceRegistrar api;
  final Future<String> Function() installationId;
  final Duration registrationRetryDelay;
  final Duration unregisterTimeout;
  final bool? _supportedOverride;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Timer? _registrationRetry;
  String? _pendingToken;
  int _registrationAttempts = 0;
  final _events = StreamController<PushEvent>.broadcast();
  bool _started = false;

  Stream<PushEvent> get events => _events.stream;

  Future<void> start() async {
    if (_started || kIsWeb || !_supportedPlatform) return;
    _started = true;
    try {
      _foregroundSubscription = messaging.foregroundMessages.listen(
        (message) => _emit(message, opened: false),
      );
      _openedSubscription = messaging.openedMessages.listen(
        (message) => _emit(message, opened: true),
      );
      final initial = await messaging.initialMessage();
      if (initial != null) _emit(initial, opened: true);
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        await _cancelListeners();
        _started = false;
        return;
      }
      final token = await messaging.token();
      if (token != null) await _register(token);
      _refreshSubscription = messaging.tokenRefresh.listen(
        (token) => unawaited(_register(token)),
        onError: (_) => AppLogger.realtime('fcm_token_refresh_failed'),
      );
    } catch (_) {
      AppLogger.realtime('fcm_registration_failed');
      await _cancelListeners();
      _started = false;
    }
  }

  Future<void> unregister() async {
    await _cancelListeners();
    if (!_started) return;
    _started = false;
    _registrationRetry?.cancel();
    _registrationRetry = null;
    _pendingToken = null;
    _registrationAttempts = 0;
    try {
      await (() async => api.disable(
        await installationId(),
      ))().timeout(unregisterTimeout);
    } catch (_) {
      AppLogger.realtime('fcm_unregister_failed');
    }
  }

  Future<void> _register(String token) async {
    if (_pendingToken != token) _registrationAttempts = 0;
    _pendingToken = token;
    try {
      await api.register(
        installationId: await installationId(),
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        token: token,
      );
      if (_pendingToken == token) _pendingToken = null;
      _registrationAttempts = 0;
      _registrationRetry?.cancel();
      _registrationRetry = null;
    } catch (_) {
      AppLogger.realtime('fcm_registration_retry_scheduled');
      _scheduleRegistrationRetry();
    }
  }

  void _scheduleRegistrationRetry() {
    if (!_started || _pendingToken == null) return;
    _registrationRetry?.cancel();
    final multiplier = 1 << min(_registrationAttempts, 6);
    _registrationAttempts++;
    _registrationRetry = Timer(registrationRetryDelay * multiplier, () {
      final token = _pendingToken;
      if (token != null) unawaited(_register(token));
    });
  }

  bool get _supportedPlatform =>
      _supportedOverride ??
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _emit(RemoteMessage message, {required bool opened}) {
    final type = message.data['type'] ?? '';
    final targetId = type == 'chat' || type == 'chat_request'
        ? message.data['conversation_id'] ?? ''
        : message.data['request_id'] ?? '';
    if (targetId.isEmpty) return;
    _events.add(
      PushEvent(
        type: type,
        targetId: targetId,
        title: message.notification?.title ?? 'Nova atualização',
        body: message.notification?.body ?? '',
        opened: opened,
      ),
    );
  }

  Future<void> _cancelListeners() async {
    await _refreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _refreshSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
  }
}

class PushEvent {
  const PushEvent({
    required this.type,
    required this.targetId,
    required this.title,
    required this.body,
    required this.opened,
  });

  final String type;
  final String targetId;
  final String title;
  final String body;
  final bool opened;
}
