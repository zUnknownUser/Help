import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/presentation/widgets/service_offer_formatters.dart';
import '../../domain/entities/service_details.dart';

class ServiceCheckoutBar extends StatelessWidget {
  const ServiceCheckoutBar({
    required this.details,
    required this.onRequest,
    required this.onAddress,
    super.key,
  });

  final ServiceDetails details;
  final VoidCallback? onRequest;
  final VoidCallback onAddress;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A partir de',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  formatMoney(details.offer.priceCents),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 185,
            child: AppButton(
              label: _label,
              onPressed: _blockedForAddress ? onAddress : onRequest,
              variant: _blockedForAnotherReason
                  ? AppButtonVariant.disabled
                  : AppButtonVariant.primary,
            ),
          ),
        ],
      ),
    ),
  );

  bool get _blockedForAddress =>
      details.requestBlockedReason == 'address_required';

  bool get _blockedForAnotherReason =>
      details.requestBlockedReason.isNotEmpty && !_blockedForAddress;

  String get _label => switch (details.requestBlockedReason) {
    'own_service' => 'Serviço da sua conta',
    'customer_role_required' => 'Use o perfil cliente',
    'address_required' => 'Definir endereço',
    _ => 'Solicitar serviço',
  };
}
