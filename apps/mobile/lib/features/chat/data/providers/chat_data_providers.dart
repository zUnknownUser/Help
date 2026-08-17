import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../local/chat_local_database.dart';
import '../realtime/chat_realtime_coordinator.dart';
import '../remote/chat_remote_api.dart';
import '../media/voice_playback_source.dart';
import '../media/voice_recorder.dart';

final chatLocalDatabaseProvider = Provider<ChatLocalDatabase>((ref) {
  final database = ChatLocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final chatRemoteApiProvider = Provider<ChatRemoteApi>(
  (ref) => ChatRemoteApi(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final chatRealtimeCoordinatorProvider = Provider<ChatRealtimeCoordinator>((
  ref,
) {
  final coordinator = ChatRealtimeCoordinator(
    local: ref.watch(chatLocalDatabaseProvider),
    remote: ref.watch(chatRemoteApiProvider),
    tokenProvider: () async =>
        await ref.read(firebaseAuthProvider).currentUser?.getIdToken(),
    apiBaseUrl: AppConfig.apiBaseUrl,
  );
  ref.onDispose(coordinator.stop);
  return coordinator;
});

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = VoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final voicePlaybackSourceProvider = Provider<VoicePlaybackSource>(
  (ref) => VoicePlaybackSource(
    remote: ref.watch(chatRemoteApiProvider),
    tokenProvider: () async =>
        await ref.read(firebaseAuthProvider).currentUser?.getIdToken(),
  ),
);
