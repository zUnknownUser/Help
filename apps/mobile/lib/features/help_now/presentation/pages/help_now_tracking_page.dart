import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';
import '../../domain/entities/help_now_request.dart';
import '../providers/help_now_providers.dart';
import '../widgets/help_now_status_visual.dart';

class HelpNowTrackingPage extends ConsumerWidget {
  const HelpNowTrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerHelpNowControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help Agora')),
      body: state.when(
        loading: () =>
            const AppLoadingView(message: 'Consultando seu chamado…'),
        error: (_, _) => _TrackingError(
          onRetry: ref
              .read(customerHelpNowControllerProvider.notifier)
              .synchronize,
        ),
        data: (request) => request == null
            ? const _FinishedView()
            : _TrackingContent(
                request: request,
                onCancel: ref
                    .read(customerHelpNowControllerProvider.notifier)
                    .cancel,
              ),
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.request, required this.onCancel});

  final HelpNowRequest request;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Spacer(),
              HelpNowStatusVisual(status: request.status),
              const SizedBox(height: 28),
              Text(
                _title(request.status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _description(request),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              _RequestSummary(request: request),
              const Spacer(),
              if (request.status == HelpNowStatus.assigned)
                AppButton(
                  label: 'Acompanhar atendimento',
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ServiceRequestDetailsPage(
                        requestId: request.serviceRequestId,
                      ),
                    ),
                  ),
                )
              else if (request.status == HelpNowStatus.searching)
                AppButton(
                  label: 'Cancelar busca',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _confirmCancel(context),
                )
              else
                AppButton(
                  label: 'Voltar para o início',
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar busca?'),
        content: const Text(
          'Os profissionais deixarão de receber este chamado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar buscando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onCancel();
  }
}

String _title(HelpNowStatus status) => switch (status) {
  HelpNowStatus.assigned => 'Profissional encontrado',
  HelpNowStatus.noProvider => 'Ninguém disponível agora',
  HelpNowStatus.cancelled => 'Busca cancelada',
  HelpNowStatus.searching => 'Buscando profissionais…',
};

String _description(HelpNowRequest request) => switch (request.status) {
  HelpNowStatus.assigned =>
    '${request.assignedProviderName} aceitou seu chamado de ${request.categoryName}.',
  HelpNowStatus.noProvider =>
    'Não encontramos um profissional disponível neste momento. Você pode tentar novamente em instantes.',
  HelpNowStatus.cancelled =>
    'Este chamado não está mais sendo enviado aos profissionais.',
  HelpNowStatus.searching =>
    'Estamos consultando profissionais disponíveis próximos ao local do atendimento.',
};

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});
  final HelpNowRequest request;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.categoryName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (request.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            request.note,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          request.address,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    ),
  );
}

class _FinishedView extends StatelessWidget {
  const _FinishedView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Nenhum chamado ativo.'));
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 220,
      child: AppButton(label: 'Tentar novamente', onPressed: onRetry),
    ),
  );
}
