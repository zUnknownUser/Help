import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/providers/auth_data_providers.dart';
import '../../chat/data/providers/chat_data_providers.dart';
import 'device_registration_api.dart';
import 'push_registration_service.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final pushRegistrationServiceProvider = Provider<PushRegistrationService>(
  (ref) => PushRegistrationService(
    messaging: ref.watch(firebaseMessagingProvider),
    api: DeviceRegistrationApi(
      client: ref.watch(authenticatedHttpClientProvider),
      baseUrl: AppConfig.apiBaseUrl,
    ),
    local: ref.watch(chatLocalDatabaseProvider),
  ),
);
