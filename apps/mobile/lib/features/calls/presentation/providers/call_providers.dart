import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../application/call_session_controller.dart';
import '../../data/call_remote_api.dart';
import '../../domain/entities/call_session.dart';

final callRemoteApiProvider = Provider<CallRemoteApi>(
  (ref) => CallRemoteApi(
    ref.watch(authenticatedHttpClientProvider),
    AppConfig.apiBaseUrl,
  ),
);

final callSessionControllerProvider =
    Provider.autoDispose<CallSessionController>((ref) {
      final controller = CallSessionController(
        ref.watch(chatRealtimeCoordinatorProvider),
        ref.watch(callRemoteApiProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final callSessionStateProvider = StreamProvider.autoDispose<CallSession?>((
  ref,
) {
  return ref.watch(callSessionControllerProvider).states;
});
