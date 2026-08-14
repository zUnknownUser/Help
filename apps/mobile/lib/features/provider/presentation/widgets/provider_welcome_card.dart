import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';

class ProviderWelcomeCard extends StatelessWidget {
  const ProviderWelcomeCard({
    required this.workspace,
    required this.onAvailabilityChanged,
    super.key,
  });

  final ProviderWorkspace workspace;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryDark, Color(0xFF246B4C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, ${workspace.provider.displayName}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          workspace.location.configured
              ? workspace.location.address
              : 'Área de atendimento ainda não definida',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 17),
        _Availability(
          accepting: workspace.provider.acceptingRequests,
          onChanged: onAvailabilityChanged,
        ),
      ],
    ),
  );
}

class _Availability extends StatelessWidget {
  const _Availability({required this.accepting, required this.onChanged});

  final bool accepting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          accepting ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
          color: Colors.white,
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            accepting ? 'Disponível para novos pedidos' : 'Agenda pausada',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Switch.adaptive(
          value: accepting,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
