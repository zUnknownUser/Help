import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../home/domain/entities/home_location.dart';
import '../../../home/domain/entities/service_offer.dart';
import '../../../home/presentation/pages/location_page.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../home/presentation/widgets/home_image.dart';
import '../../domain/entities/service_details.dart';
import '../../domain/entities/service_request.dart';
import '../providers/service_details_providers.dart';
import '../widgets/service_details_content.dart';
import '../widgets/service_request_sheet.dart';

class ServiceDetailsPage extends ConsumerWidget {
  const ServiceDetailsPage({required this.serviceId, this.preview, super.key});

  final String serviceId;
  final ServiceOffer? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(serviceDetailsProvider(serviceId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Detalhes do serviço'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: details.when(
            data: (value) => ServiceDetailsContent(
              details: value,
              onRequest: value.canRequest
                  ? () => _request(context, ref, value)
                  : null,
              onChat: value.requestBlockedReason == 'own_service'
                  ? null
                  : () => _chat(context, ref, value),
              onAddress: () => _address(context, ref),
            ),
            loading: () => _LoadingDetails(preview: preview),
            error: (_, _) => _DetailsError(
              onRetry: () => ref.invalidate(serviceDetailsProvider(serviceId)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    ServiceDetails details,
  ) async {
    final receipt = await showModalBottomSheet<ServiceRequestReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ServiceRequestSheet(details: details),
    );
    if (receipt == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primary,
          size: 42,
        ),
        title: const Text('Solicitação enviada'),
        content: Text(
          '${receipt.providerName} recebeu seu pedido para ${receipt.serviceTitle}. Você será avisado quando houver uma resposta.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _chat(
    BuildContext context,
    WidgetRef ref,
    ServiceDetails details,
  ) async {
    try {
      final conversation = await runWithAppLoading(
        context,
        message: 'Abrindo conversa…',
        action: () => ref
            .read(chatRealtimeCoordinatorProvider)
            .startDirect(details.providerUserId),
      );
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível iniciar a conversa agora.'),
          ),
        );
      }
    }
  }

  Future<void> _address(BuildContext context, WidgetRef ref) async {
    final current =
        ref.read(homeControllerProvider).value?.location ??
        const HomeLocation(address: '', availabilityLabel: '');
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LocationPage(current: current)),
    );
    if (changed == true) {
      ref.invalidate(serviceDetailsProvider(serviceId));
      await ref.read(homeControllerProvider.notifier).retry();
    }
  }
}

class _LoadingDetails extends StatelessWidget {
  const _LoadingDetails({required this.preview});
  final ServiceOffer? preview;

  @override
  Widget build(BuildContext context) {
    if (preview == null) {
      return const AppLoadingView(message: 'Carregando serviço…');
    }
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 250,
          child: HomeImage(
            imageUrl: preview!.imageUrl,
            alignment: Alignment(preview!.imageAlignment, 0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview!.title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                preview!.provider.name,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              const AppLinearProgressIndicator(
                semanticsLabel: 'Carregando detalhes do serviço',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Não foi possível carregar este serviço.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
