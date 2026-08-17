import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_request_item.dart';

class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge(this.status, {super.key});
  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = requestStatusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        visual.label,
        style: TextStyle(
          color: visual.color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

RequestStatusVisual requestStatusVisual(ServiceRequestStatus status) =>
    switch (status) {
      ServiceRequestStatus.pending => const RequestStatusVisual(
        'Aguardando',
        AppColors.amber,
      ),
      ServiceRequestStatus.accepted => const RequestStatusVisual(
        'Aceito',
        AppColors.primary,
      ),
      ServiceRequestStatus.inProgress => const RequestStatusVisual(
        'Em andamento',
        Color(0xFF2878B5),
      ),
      ServiceRequestStatus.completed => const RequestStatusVisual(
        'Concluído',
        Color(0xFF248A5A),
      ),
      ServiceRequestStatus.rejected => const RequestStatusVisual(
        'Recusado',
        AppColors.danger,
      ),
      ServiceRequestStatus.cancelled => const RequestStatusVisual(
        'Cancelado',
        AppColors.textSecondary,
      ),
      ServiceRequestStatus.noShow => const RequestStatusVisual(
        'Não compareceu',
        AppColors.danger,
      ),
    };

class RequestStatusVisual {
  const RequestStatusVisual(this.label, this.color);
  final String label;
  final Color color;
}
