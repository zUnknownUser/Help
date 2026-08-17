import 'package:firebase_messaging/firebase_messaging.dart';

abstract interface class PushMessagingGateway {
  Stream<String> get tokenRefresh;
  Stream<RemoteMessage> get foregroundMessages;
  Stream<RemoteMessage> get openedMessages;

  Future<NotificationSettings> requestPermission();
  Future<NotificationSettings> notificationSettings();
  Future<String?> token();
  Future<RemoteMessage?> initialMessage();
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  const FirebasePushMessagingGateway(this._messaging);
  final FirebaseMessaging _messaging;

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> initialMessage() => _messaging.getInitialMessage();

  @override
  Future<NotificationSettings> notificationSettings() =>
      _messaging.getNotificationSettings();

  @override
  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission(alert: true, badge: true, sound: true);

  @override
  Future<String?> token() => _messaging.getToken();
}
