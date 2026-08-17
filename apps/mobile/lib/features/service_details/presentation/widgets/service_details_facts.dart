import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/presentation/widgets/service_offer_formatters.dart';
import '../../domain/entities/service_details.dart';

class ServiceDetailsFacts extends StatelessWidget {
  const ServiceDetailsFacts({required this.details, super.key});
  final ServiceDetails details;

  @override
  Widget build(BuildContext context) {
    final offer = details.offer;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Fact(
          Icons.star_rounded,
          '${offer.rating.toStringAsFixed(1)} (${compactReviews(offer.reviews)})',
        ),
        _Fact(Icons.schedule_rounded, formatDuration(offer.durationMinutes)),
        if (offer.distanceKm case final distance?)
          _Fact(
            Icons.near_me_rounded,
            '${distance.toStringAsFixed(1).replaceAll('.', ',')} km',
          ),
        if (details.serviceArea.isNotEmpty)
          _Fact(Icons.location_city_rounded, details.serviceArea),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryDark),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class ServiceDetailsBadge extends StatelessWidget {
  const ServiceDetailsBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    ),
  );
}

class ServiceDetailsSectionTitle extends StatelessWidget {
  const ServiceDetailsSectionTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
  );
}
