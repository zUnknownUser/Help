import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';
import '../../domain/entities/help_now_offer.dart';
import '../providers/help_now_providers.dart';

class ProviderHelpNowOffersPage extends ConsumerWidget {
  const ProviderHelpNowOffersPage({this.focusOfferId, super.key});
  final String? focusOfferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerHelpNowControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chamados Help Agora')),
      body: state.when(
        loading: () =>
            const AppLoadingView(message: 'Buscando chamados próximos…'),
        error: (_, _) => _EmptyOffers(
          message: 'Não foi possível consultar os chamados agora.',
          onRefresh: ref
              .read(providerHelpNowControllerProvider.notifier)
              .synchronize,
        ),
        data: (data) {
          final offers = data.offers
              .where((offer) => !offer.isExpired(DateTime.now()))
              .toList();
          if (offers.isEmpty) {
            return _EmptyOffers(
              message: data.availability.enabled
                  ? 'Você está online. Novos chamados aparecerão aqui.'
                  : 'Ative o Help Agora na sua tela inicial para receber chamados.',
              onRefresh: ref
                  .read(providerHelpNowControllerProvider.notifier)
                  .synchronize,
            );
          }
          offers.sort(
            (a, b) => a.id == focusOfferId
                ? -1
                : b.id == focusOfferId
                ? 1
                : 0,
          );
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _OfferCard(offer: offers[index]),
          );
        },
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.offer});
  final HelpNowOffer offer;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  Timer? _ticker;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.offer.expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 99);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFD5E9DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.bolt_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.categoryName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.offer.distanceLabel} • ${widget.offer.area}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${remaining}s',
                style: TextStyle(
                  color: remaining < 8
                      ? AppColors.danger
                      : AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (widget.offer.note.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              widget.offer.note,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Recusar',
                  variant: AppButtonVariant.outlined,
                  onPressed: _answering || remaining == 0
                      ? null
                      : () => _respond(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Aceitar',
                  isLoading: _answering,
                  onPressed: _answering || remaining == 0
                      ? null
                      : () => _respond(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(bool accept) async {
    setState(() => _answering = true);
    try {
      final request = await ref
          .read(providerHelpNowControllerProvider.notifier)
          .respond(widget.offer, accept);
      if (!mounted || !accept) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) =>
              ServiceRequestDetailsPage(requestId: request.serviceRequestId),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este chamado não está mais disponível.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.message, required this.onRefresh});
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(36),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.radar_rounded, size: 50, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    ),
  );
}
