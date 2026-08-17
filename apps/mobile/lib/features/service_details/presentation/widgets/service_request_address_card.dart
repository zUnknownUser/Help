import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_details.dart';

class ServiceRequestAddressCard extends StatelessWidget {
  const ServiceRequestAddressCard({
    required this.details,
    required this.onTap,
    super.key,
  });

  final ServiceDetails details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = details.requestAddress;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: address == null
              ? const Color(0xFFFFF8E8)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: address == null ? AppColors.amber : AppColors.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              address == null
                  ? Icons.add_location_alt_outlined
                  : Icons.location_on_outlined,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address?.label ?? 'Defina o endereço do atendimento',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address?.formattedAddress ??
                        'Use sua localização atual ou escolha por CEP.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
