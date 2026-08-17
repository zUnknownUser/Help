import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_error_state.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_request_item.dart';
import 'request_status_badge.dart';
import 'service_request_tile.dart';
import '../../../reviews/presentation/service_review_card.dart';

class ServiceRequestDetailsView extends StatelessWidget {
  const ServiceRequestDetailsView({
    required this.request,
    required this.acting,
    required this.onAction,
    required this.onChat,
    this.onReschedule,
    super.key,
  });

  final ServiceRequestItem request;
  final bool acting;
  final ValueChanged<ServiceRequestStatus> onAction;
  final VoidCallback onChat;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final canChat =
        request.status == ServiceRequestStatus.accepted ||
        request.status == ServiceRequestStatus.inProgress ||
        request.status == ServiceRequestStatus.completed;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RequestSummary(request: request),
        const SizedBox(height: 12),
        _InfoCard(
          rows: [
            _InfoRow(
              Icons.event_outlined,
              'Agendamento',
              formatRequestSchedule(request.scheduledFor),
            ),
            _InfoRow(
              Icons.payments_outlined,
              'Valor combinado',
              formatRequestPrice(request.quotedPriceCents),
            ),
            _InfoRow(
              Icons.location_on_outlined,
              request.addressLabel,
              request.address,
            ),
            if (request.note.isNotEmpty)
              _InfoRow(Icons.notes_rounded, 'Observação', request.note),
          ],
        ),
        if (canChat) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Conversar',
            variant: AppButtonVariant.outlined,
            leading: const Icon(Icons.forum_outlined, size: 18),
            onPressed: onChat,
          ),
        ],
        if (request.status == ServiceRequestStatus.completed) ...[
          const SizedBox(height: 12),
          ServiceReviewCard(request: request),
        ],
        if (onReschedule != null) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Alterar horário',
            variant: AppButtonVariant.outlined,
            leading: const Icon(Icons.edit_calendar_outlined, size: 18),
            onPressed: acting ? null : onReschedule,
          ),
        ],
        if (request.availableActions.isNotEmpty) ...[
          const SizedBox(height: 22),
          ...request.availableActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppButton(
                label: requestActionLabel(action),
                isLoading: acting,
                variant: _destructive(action)
                    ? AppButtonVariant.outlined
                    : AppButtonVariant.primary,
                onPressed: acting ? null : () => onAction(action),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});
  final ServiceRequestItem request;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                request.serviceTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            RequestStatusBadge(request.status),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          request.viewerRole == RequestViewerRole.customer
              ? 'Prestador: ${request.providerName}'
              : 'Cliente: ${request.customerName}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (request.statusReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(request.statusReason),
        ],
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration,
    child: Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _InfoRow {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class ServiceRequestDetailsError extends StatelessWidget {
  const ServiceRequestDetailsError({required this.onRetry, super.key});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppErrorState(
    title: 'Solicitação indisponível',
    message: 'Não foi possível carregar os detalhes agora.',
    onRetry: onRetry,
  );
}

bool _destructive(ServiceRequestStatus status) =>
    status == ServiceRequestStatus.rejected ||
    status == ServiceRequestStatus.cancelled ||
    status == ServiceRequestStatus.noShow;

String requestActionLabel(ServiceRequestStatus status) => switch (status) {
  ServiceRequestStatus.accepted => 'Aceitar solicitação',
  ServiceRequestStatus.rejected => 'Recusar solicitação',
  ServiceRequestStatus.inProgress => 'Iniciar serviço',
  ServiceRequestStatus.completed => 'Marcar como concluído',
  ServiceRequestStatus.cancelled => 'Cancelar solicitação',
  ServiceRequestStatus.pending => 'Aguardar',
  ServiceRequestStatus.noShow => 'Registrar não comparecimento',
};

String requestActionDescription(
  ServiceRequestStatus status,
) => switch (status) {
  ServiceRequestStatus.accepted =>
    'O cliente será avisado de que você confirmou o atendimento.',
  ServiceRequestStatus.rejected =>
    'O cliente será avisado e o pedido será encerrado.',
  ServiceRequestStatus.inProgress =>
    'Confirme apenas quando o atendimento realmente começar.',
  ServiceRequestStatus.completed => 'Confirme que o serviço foi finalizado.',
  ServiceRequestStatus.cancelled =>
    'A outra pessoa será avisada sobre o cancelamento.',
  ServiceRequestStatus.pending => '',
  ServiceRequestStatus.noShow =>
    'Use esta opção apenas após o horário agendado, se o cliente não comparecer.',
};

final _cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.outline),
);
