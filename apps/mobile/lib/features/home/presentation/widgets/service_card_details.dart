import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_offer.dart';
import 'service_offer_formatters.dart';

class ServiceCardDetails extends StatelessWidget {
  const ServiceCardDetails({required this.offer, super.key});

  final ServiceOffer offer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          _Metadata(offer: offer),
          const SizedBox(height: 7),
          if (offer.provider.verified) const _VerifiedProvider(),
          const Spacer(),
          _PriceRow(offer: offer),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.offer});

  final ServiceOffer offer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 13, color: AppColors.amber),
            const SizedBox(width: 2),
            Text(
              '${offer.rating} (${compactReviews(offer.reviews)})',
              style: const TextStyle(
                fontSize: 8.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.schedule_rounded,
              size: 11,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 2),
            Text(
              formatDuration(offer.durationMinutes),
              style: const TextStyle(
                fontSize: 8.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedProvider extends StatelessWidget {
  const _VerifiedProvider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
            SizedBox(width: 3),
            Text(
              'Profissional verificado',
              style: TextStyle(fontSize: 8.2, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.offer});

  final ServiceOffer offer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(offer.priceCents),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            if (offer.oldPriceCents case final oldPrice?) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  formatMoney(oldPrice),
                  style: const TextStyle(
                    fontSize: 8,
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 9),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'Agendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
