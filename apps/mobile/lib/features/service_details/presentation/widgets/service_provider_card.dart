import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_details.dart';

class ServiceProviderCard extends StatelessWidget {
  const ServiceProviderCard({
    required this.details,
    required this.onChat,
    super.key,
  });

  final ServiceDetails details;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primarySoft,
          child: Text(
            _initial,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _identity()),
        IconButton(
          tooltip: 'Conversar com o prestador',
          onPressed: onChat,
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    ),
  );

  String get _initial {
    final name = details.offer.provider.name;
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              details.offer.provider.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          if (details.offer.provider.verified) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified_rounded,
              size: 17,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
      const SizedBox(height: 3),
      const Text(
        'Prestador do serviço',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}
