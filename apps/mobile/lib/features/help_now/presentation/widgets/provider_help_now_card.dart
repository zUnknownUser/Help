import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/help_now_availability.dart';

class ProviderHelpNowCard extends StatelessWidget {
  const ProviderHelpNowCard({
    required this.state,
    required this.onChanged,
    required this.onOffers,
    this.busy = false,
    super.key,
  });

  final ProviderHelpNowState state;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOffers;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = state.availability.enabled;
    final offerCount = state.offers.length;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: offerCount > 0 ? onOffers : null,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: offerCount > 0
                  ? const Color(0xFFB9DEC5)
                  : AppColors.outline,
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: enabled
                    ? AppColors.primarySoft
                    : AppColors.disabledSurface,
                child: Icon(
                  offerCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.bolt_rounded,
                  size: 20,
                  color: enabled ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Help Agora',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (offerCount > 0) ...[
                          const SizedBox(width: 7),
                          Badge(label: Text('$offerCount')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      offerCount > 0
                          ? 'Novo chamado próximo. Toque para responder.'
                          : enabled
                          ? 'Online para chamados próximos'
                          : 'Ative quando puder atender imediatamente',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: busy ? null : onChanged,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
