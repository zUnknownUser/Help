import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../domain/entities/chat_message.dart';

class VoiceMessagePlayer extends ConsumerStatefulWidget {
  const VoiceMessagePlayer({
    required this.message,
    required this.mine,
    super.key,
  });

  final ChatMessage message;
  final bool mine;

  @override
  ConsumerState<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends ConsumerState<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _loading = false;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.message.media!;
    final total = _player.duration ?? Duration(milliseconds: media.durationMs);
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 36,
            child: IconButton.filled(
              padding: EdgeInsets.zero,
              tooltip: _player.playing ? 'Pausar audio' : 'Reproduzir audio',
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _failed
                          ? Icons.refresh_rounded
                          : _player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              initialData: Duration.zero,
              builder: (_, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final maximum = total.inMilliseconds.clamp(1, 300000);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: position.inMilliseconds
                            .clamp(0, maximum)
                            .toDouble(),
                        max: maximum.toDouble(),
                        onChanged: _loaded
                            ? (value) => _player.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                    ),
                    Text(
                      _duration(_player.playing ? position : total),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        await ref
            .read(voicePlaybackSourceProvider)
            .load(_player, widget.message.media!);
        _loaded = true;
      } catch (_) {
        _failed = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (_loaded) await _player.play();
  }

  String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
