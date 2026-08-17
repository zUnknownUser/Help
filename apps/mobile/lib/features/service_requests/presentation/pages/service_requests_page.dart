import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_request_item.dart';
import '../providers/service_request_providers.dart';
import '../widgets/service_request_tile.dart';
import 'service_request_details_page.dart';

class ServiceRequestsPage extends ConsumerWidget {
  const ServiceRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceRequestsControllerProvider);
    final controller = ref.read(serviceRequestsControllerProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          state.role == RequestViewerRole.customer
              ? 'Meus pedidos'
              : 'Solicitações',
        ),
      ),
      body: state.loading && state.items.isEmpty
          ? const AppLoadingView(message: 'Carregando solicitações…')
          : state.failure != null && state.items.isEmpty
          ? _RequestLoadError(onRetry: controller.refresh)
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 350) {
                    unawaited(controller.loadMore());
                  }
                  return false;
                },
                child: state.items.isEmpty
                    ? _EmptyRequests(role: state.role)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            state.items.length + (state.loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: AppProgressIndicator()),
                            );
                          }
                          final request = state.items[index];
                          return ServiceRequestTile(
                            request: request,
                            onTap: () => _open(context, ref, request),
                          );
                        },
                      ),
              ),
            ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestItem request,
  ) async {
    final updated = await Navigator.of(context).push<ServiceRequestItem>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceRequestDetailsPage(requestId: request.id, initial: request),
      ),
    );
    if (updated != null) {
      ref.read(serviceRequestsControllerProvider.notifier).reconcile(updated);
    }
  }
}

class _RequestLoadError extends StatelessWidget {
  const _RequestLoadError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.primary,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar as solicitações.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            AppButton(label: 'Tentar novamente', onPressed: onRetry),
          ],
        ),
      ),
    ),
  );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({required this.role});
  final RequestViewerRole role;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 100),
      const Icon(Icons.assignment_outlined, size: 48, color: AppColors.primary),
      const SizedBox(height: 14),
      Text(
        role == RequestViewerRole.customer
            ? 'Você ainda não solicitou nenhum serviço.'
            : 'Nenhuma solicitação chegou por enquanto.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
