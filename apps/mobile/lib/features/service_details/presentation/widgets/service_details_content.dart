import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/presentation/widgets/home_image.dart';
import '../../domain/entities/service_details.dart';
import 'service_checkout_bar.dart';
import 'service_details_facts.dart';
import 'service_provider_card.dart';
import 'service_request_address_card.dart';

class ServiceDetailsContent extends StatelessWidget {
  const ServiceDetailsContent({
    required this.details,
    required this.onRequest,
    required this.onChat,
    required this.onAddress,
    super.key,
  });

  final ServiceDetails details;
  final VoidCallback? onRequest;
  final VoidCallback? onChat;
  final VoidCallback onAddress;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 250,
                child: HomeImage(
                  imageUrl: details.offer.imageUrl,
                  alignment: Alignment(details.offer.imageAlignment, 0),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList.list(children: _sections()),
            ),
          ],
        ),
      ),
      ServiceCheckoutBar(
        details: details,
        onRequest: onRequest,
        onAddress: onAddress,
      ),
    ],
  );

  List<Widget> _sections() => [
    if (details.offer.badge case final badge?) ServiceDetailsBadge(badge),
    const SizedBox(height: 10),
    Text(
      details.offer.title,
      style: const TextStyle(
        fontSize: 25,
        height: 1.15,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    ),
    const SizedBox(height: 12),
    ServiceDetailsFacts(details: details),
    const SizedBox(height: 22),
    ServiceProviderCard(details: details, onChat: onChat),
    const SizedBox(height: 24),
    const ServiceDetailsSectionTitle('Sobre o serviço'),
    const SizedBox(height: 8),
    Text(
      details.description.isEmpty
          ? 'O prestador ainda não adicionou uma descrição.'
          : details.description,
      style: const TextStyle(color: AppColors.textSecondary, height: 1.55),
    ),
    const SizedBox(height: 24),
    const ServiceDetailsSectionTitle('Local do atendimento'),
    const SizedBox(height: 10),
    ServiceRequestAddressCard(details: details, onTap: onAddress),
  ];
}
