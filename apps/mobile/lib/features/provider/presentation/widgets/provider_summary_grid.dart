import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';

class ProviderSummaryGrid extends StatelessWidget {
  const ProviderSummaryGrid({required this.summary, super.key});

  final ProviderSummary summary;

  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    childAspectRatio: 1.9,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    children: [
      _Metric(
        label: 'Publicados',
        value: summary.publishedServices,
        icon: Icons.visibility_rounded,
      ),
      _Metric(
        label: 'Pausados',
        value: summary.pausedServices,
        icon: Icons.pause_circle_outline_rounded,
      ),
      _Metric(
        label: 'Solicitações',
        value: summary.pendingRequests,
        icon: Icons.assignment_outlined,
      ),
      _Metric(
        label: 'Mensagens',
        value: summary.unreadMessages,
        icon: Icons.forum_outlined,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
