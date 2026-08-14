import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../chat/data/local/chat_local_database.dart';
import 'device_registration_api.dart';

class PushRegistrationService {
  PushRegistrationService({
    required this._messaging,
    required this._api,
    required this._local,
  });

  final FirebaseMessaging _messaging;
  final DeviceRegistrationApi _api;
  final ChatLocalDatabase _local;
  StreamSubscription<String>? _refreshSubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb || !_supportedPlatform) return;
    _started = true;
    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _messaging.getToken();
      if (token != null) await _register(token);
      _refreshSubscription = _messaging.onTokenRefresh.listen(
        (token) => unawaited(_register(token)),
        onError: (_) => AppLogger.realtime('fcm_token_refresh_failed'),
      );
    } catch (_) {
      AppLogger.realtime('fcm_registration_failed');
    }
  }

  Future<void> unregister() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    if (!_started) return;
    _started = false;
    try {
      await _api.disable(await _local.installationId());
    } catch (_) {
      AppLogger.realtime('fcm_unregister_failed');
    }
  }

  Future<void> _register(String token) async => _api.register(
    installationId: await _local.installationId(),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    token: token,
  );

  bool get _supportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
