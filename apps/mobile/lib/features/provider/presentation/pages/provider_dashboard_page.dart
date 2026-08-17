import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/domain/entities/home_location.dart';
import '../../../home/domain/entities/home_notification.dart';
import '../../../home/presentation/pages/location_page.dart';
import '../../../home/presentation/pages/notifications_page.dart';
import '../../../main_navigation/presentation/main_tab.dart';
import '../../domain/entities/provider_service.dart';
import '../../domain/entities/provider_workspace.dart';
import '../../domain/failures/provider_failure.dart';
import '../provider_failure_message.dart';
import '../providers/provider_workspace_providers.dart';
import '../widgets/provider_dashboard_view.dart';
import 'provider_service_form_page.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';
import '../../../scheduling/presentation/pages/provider_schedule_page.dart';
import '../../../scheduling/presentation/pages/provider_agenda_page.dart';

class ProviderDashboardPage extends ConsumerWidget {
  const ProviderDashboardPage({required this.onTabSelected, super.key});

  final ValueChanged<MainTab> onTabSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerWorkspaceControllerProvider);
    return state.when(
      loading: _ProviderLoading.new,
      error: (_, _) => _ProviderError(
        onRetry: ref.read(providerWorkspaceControllerProvider.notifier).retry,
      ),
      data: (workspace) => ProviderDashboardView(
        workspace: workspace,
        onRefresh: ref.read(providerWorkspaceControllerProvider.notifier).retry,
        onAvailabilityChanged: (value) => _availability(context, ref, value),
        onAlert: (alert) => _openAlert(context, ref, workspace, alert),
        onCreateService: () => _openForm(context, workspace),
        onEditService: (service) => _openForm(context, workspace, service),
        onPublishedChanged: (service, value) =>
            _publication(context, ref, service, value),
        onDeleteService: (service) => _delete(context, ref, service),
        onAccount: () => onTabSelected(MainTab.account),
        onNotifications: () => _openNotifications(context, ref, workspace),
        onRequests: () => onTabSelected(MainTab.requests),
        onSchedule: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ProviderSchedulePage()),
        ),
        onAgenda: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ProviderAgendaPage()),
        ),
        onRequest: (request) => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ServiceRequestDetailsPage(requestId: request.id),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    ProviderWorkspace workspace, [
    ProviderService? service,
  ]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProviderServiceFormPage(
          categories: workspace.categories,
          service: service,
        ),
      ),
    );
  }

  Future<void> _openNotifications(
    BuildContext context,
    WidgetRef ref,
    ProviderWorkspace workspace,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          notifications: workspace.notifications
              .map(
                (notification) => HomeNotification(
                  id: notification.id,
                  title: notification.title,
                  body: notification.body,
                  kind: notification.kind,
                  data: notification.data,
                  read: notification.read,
                  createdAt: notification.createdAt,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (context.mounted) {
      await ref.read(providerWorkspaceControllerProvider.notifier).retry();
    }
  }

  Future<void> _openAlert(
    BuildContext context,
    WidgetRef ref,
    ProviderWorkspace workspace,
    ProviderAlert alert,
  ) async {
    if (alert.kind == 'location') {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LocationPage(
            current: HomeLocation(
              address: workspace.location.address,
              availabilityLabel: 'Área de atendimento',
              latitude: workspace.location.latitude,
              longitude: workspace.location.longitude,
            ),
          ),
        ),
      );
      if (changed == true) {
        await ref.read(providerWorkspaceControllerProvider.notifier).retry();
      }
      return;
    }
    if (alert.kind == 'service' || alert.kind == 'publication') {
      await _openForm(context, workspace);
      return;
    }
    await _availability(context, ref, true);
  }

  Future<void> _availability(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final failure = await ref
        .read(providerWorkspaceControllerProvider.notifier)
        .setAvailability(value);
    if (context.mounted && failure != null) _showFailure(context, failure);
  }

  Future<void> _publication(
    BuildContext context,
    WidgetRef ref,
    ProviderService service,
    bool value,
  ) async {
    final failure = await ref
        .read(providerWorkspaceControllerProvider.notifier)
        .setPublished(service, value);
    if (context.mounted && failure != null) _showFailure(context, failure);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProviderService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir serviço?'),
        content: Text(
          '“${service.title}” deixará de aparecer para os clientes. Esta ação preserva o histórico de solicitações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(providerWorkspaceControllerProvider.notifier)
        .deleteService(service);
    if (context.mounted && failure != null) _showFailure(context, failure);
  }

  void _showFailure(BuildContext context, ProviderFailure failure) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(providerFailureMessage(failure))));
  }
}

class _ProviderLoading extends StatelessWidget {
  const _ProviderLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: AppLoadingView(message: 'Preparando sua área profissional…'),
  );
}

class _ProviderError extends StatelessWidget {
  const _ProviderError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar sua área profissional.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppButton(label: 'Tentar novamente', onPressed: onRetry),
            ],
          ),
        ),
      ),
    ),
  );
}
