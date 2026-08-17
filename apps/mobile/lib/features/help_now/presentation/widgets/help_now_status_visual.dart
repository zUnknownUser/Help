import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/help_now_request.dart';

class HelpNowStatusVisual extends StatelessWidget {
  const HelpNowStatusVisual({required this.status, super.key});

  final HelpNowStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == HelpNowStatus.searching) {
      return const _SearchingRadar();
    }
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: const Color(0xFFCFE7D6), width: 8),
      ),
      child: Icon(
        switch (status) {
          HelpNowStatus.assigned => Icons.check_rounded,
          HelpNowStatus.noProvider => Icons.person_search_rounded,
          HelpNowStatus.cancelled => Icons.close_rounded,
          HelpNowStatus.searching => Icons.radar_rounded,
        },
        size: 47,
        color: AppColors.primary,
      ),
    );
  }
}

class _SearchingRadar extends StatefulWidget {
  const _SearchingRadar();

  @override
  State<_SearchingRadar> createState() => _SearchingRadarState();
}

class _SearchingRadarState extends State<_SearchingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _RadarArtwork(animate: false);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => SizedBox.square(
        dimension: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Pulse(progress: _controller.value),
            _Pulse(progress: (_controller.value + .5) % 1),
            child!,
          ],
        ),
      ),
      child: const _RadarArtwork(animate: true),
    );
  }
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: .72 + progress * .38,
    child: Opacity(
      opacity: (1 - progress) * .32,
      child: Container(
        width: 126,
        height: 126,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
      ),
    ),
  );
}

class _RadarArtwork extends StatelessWidget {
  const _RadarArtwork({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Radar buscando profissionais próximos',
    child: Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFFCFE7D6), width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x164F9E6C), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: animate
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.hue,
                ),
                child: Image.asset(
                  'assets/animations/help_now_radar.gif',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              )
            : const Icon(
                Icons.radar_rounded,
                size: 56,
                color: AppColors.primary,
              ),
      ),
    ),
  );
}
