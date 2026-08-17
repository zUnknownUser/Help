import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../application/call_session_controller.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../domain/entities/call_session.dart';
import '../providers/call_providers.dart';

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(callSessionStateProvider, (_, next) {
      final session = next.value;
      if (session?.hasEnded == true) _closeSoon();
    });
    final controller = ref.watch(callSessionControllerProvider);
    final session =
        ref.watch(callSessionStateProvider).value ?? controller.current;
    if (session == null) return const SizedBox.shrink();
    return PopScope(
      canPop: session.hasEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(controller.hangup());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF10231A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (session.isVideo)
              _VideoStage(controller: controller, session: session)
            else
              _AudioStage(session: session),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(session: session),
                  const Spacer(),
                  _CallControls(controller: controller, session: session),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeSoon() {
    if (_closing) return;
    _closing = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.controller, required this.session});

  final CallSessionController controller;
  final CallSession session;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        color: const Color(0xFF14261E),
        child: RTCVideoView(
          controller.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
      if (session.cameraEnabled)
        Positioned(
          right: 16,
          top: MediaQuery.paddingOf(context).top + 76,
          width: 112,
          height: 168,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: RTCVideoView(
                controller.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        ),
    ],
  );
}

class _AudioStage extends StatelessWidget {
  const _AudioStage({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF234735), Color(0xFF0D1B14)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(name: session.peerDisplayName, radius: 58),
          const SizedBox(height: 22),
          Text(
            session.peerDisplayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _status(session),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
    child: Column(
      children: [
        Text(
          session.isVideo ? 'Chamada de video' : 'Chamada de voz',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (session.isVideo) ...[
          const SizedBox(height: 4),
          Text(
            '${session.peerDisplayName} • ${_status(session)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}

class _CallControls extends StatelessWidget {
  const _CallControls({required this.controller, required this.session});

  final CallSessionController controller;
  final CallSession session;

  @override
  Widget build(BuildContext context) {
    if (session.phase == CallPhase.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Control(
            icon: Icons.call_end_rounded,
            label: 'Recusar',
            color: AppColors.danger,
            onTap: controller.decline,
          ),
          _Control(
            icon: session.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            label: 'Aceitar',
            color: AppColors.primary,
            onTap: controller.accept,
          ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC0A120E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Control(
            icon: session.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: session.muted ? 'Ativar' : 'Mudo',
            active: session.muted,
            onTap: controller.toggleMuted,
          ),
          _Control(
            icon: session.speakerEnabled
                ? Icons.volume_up_rounded
                : Icons.hearing_rounded,
            label: 'Audio',
            active: session.speakerEnabled,
            onTap: controller.toggleSpeaker,
          ),
          if (session.isVideo)
            _Control(
              icon: session.cameraEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Camera',
              active: !session.cameraEnabled,
              onTap: controller.toggleCamera,
            ),
          _Control(
            icon: Icons.call_end_rounded,
            label: 'Encerrar',
            color: AppColors.danger,
            onTap: controller.hangup,
          ),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        onPressed: () => unawaited(onTap()),
        style: IconButton.styleFrom(
          backgroundColor: color ?? (active ? Colors.white : Colors.white24),
          foregroundColor: active ? const Color(0xFF14261E) : Colors.white,
          minimumSize: const Size(52, 52),
        ),
        icon: Icon(icon),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
    ],
  );
}

String _status(CallSession session) => switch (session.phase) {
  CallPhase.incoming => 'Recebendo chamada...',
  CallPhase.calling => 'Chamando...',
  CallPhase.connecting => 'Conectando...',
  CallPhase.active => _duration(session.elapsed),
  CallPhase.ended => 'Chamada encerrada',
  CallPhase.failed => _failure(session.failureCode),
};

String _duration(Duration value) =>
    '${value.inHours > 0 ? '${value.inHours.toString().padLeft(2, '0')}:' : ''}'
    '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
    '${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

String _failure(String? code) => switch (code) {
  'recipient_offline' => 'Pessoa indisponivel',
  'not_answered' => 'Sem resposta',
  'media_unavailable' => 'Camera ou microfone indisponivel',
  'connection_lost' => 'Conexao perdida',
  _ => 'Nao foi possivel conectar',
};
