import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';

class ProviderRequestsSection extends StatelessWidget {
  const ProviderRequestsSection({required this.requests, super.key});

  final List<ProviderRequest> requests;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Solicitações recentes',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      if (requests.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                color: AppColors.textSecondary,
                size: 30,
              ),
              SizedBox(height: 8),
              Text(
                'Nenhuma solicitação por enquanto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Quando um cliente solicitar um serviço, ele aparecerá aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        )
      else
        ...requests.map(
          (request) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person_outline, color: AppColors.primaryDark),
            ),
            title: Text(request.customerName),
            subtitle: Text(request.serviceTitle),
            trailing: Text(
              _statusLabel(request.status),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  'accepted' => 'Aceita',
  'rejected' => 'Recusada',
  'completed' => 'Concluída',
  'cancelled' => 'Cancelada',
  _ => 'Pendente',
};
