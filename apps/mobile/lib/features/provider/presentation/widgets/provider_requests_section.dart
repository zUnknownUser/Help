import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';
import '../../../home/presentation/widgets/service_offer_formatters.dart';

class ProviderRequestsSection extends StatelessWidget {
  const ProviderRequestsSection({
    required this.requests,
    required this.onRequest,
    required this.onViewAll,
    super.key,
  });

  final List<ProviderRequest> requests;
  final ValueChanged<ProviderRequest> onRequest;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Solicitações recentes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(onPressed: onViewAll, child: const Text('Ver todas')),
        ],
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
          (request) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.outline),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onRequest(request),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _statusLabel(request.status),
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(request.serviceTitle),
                      const SizedBox(height: 8),
                      _RequestFact(
                        Icons.schedule_outlined,
                        request.scheduledFor == null
                            ? 'Horário não informado'
                            : _formatSchedule(request.scheduledFor!.toLocal()),
                      ),
                      _RequestFact(
                        Icons.payments_outlined,
                        formatMoney(request.quotedPriceCents),
                      ),
                      if (request.address.isNotEmpty)
                        _RequestFact(
                          Icons.location_on_outlined,
                          request.address,
                        ),
                      if (request.note.isNotEmpty)
                        _RequestFact(Icons.notes_rounded, request.note),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  'accepted' => 'Aceita',
  'in_progress' => 'Em andamento',
  'rejected' => 'Recusada',
  'completed' => 'Concluída',
  'cancelled' => 'Cancelada',
  _ => 'Pendente',
};

String _formatSchedule(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _RequestFact extends StatelessWidget {
  const _RequestFact(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
