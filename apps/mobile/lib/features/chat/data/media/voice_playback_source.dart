import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../../domain/entities/chat_message.dart';
import '../remote/chat_remote_api.dart';

typedef VoiceTokenProvider = Future<String?> Function();

class VoicePlaybackSource {
  const VoicePlaybackSource({
    required this.remote,
    required this.tokenProvider,
  });

  final ChatRemoteApi remote;
  final VoiceTokenProvider tokenProvider;

  Future<void> load(AudioPlayer player, ChatMedia media) async {
    final localPath = media.localPath;
    if (localPath != null && await File(localPath).exists()) {
      await player.setFilePath(localPath);
      return;
    }
    final mediaId = media.id;
    final token = await tokenProvider();
    if (mediaId == null || token == null || token.isEmpty) {
      throw StateError('voice_source_unavailable');
    }
    await player.setAudioSource(
      AudioSource.uri(
        remote.mediaUri(mediaId),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}
