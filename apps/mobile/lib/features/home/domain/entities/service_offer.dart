import 'service_provider.dart';

class ServiceOffer {
  const ServiceOffer({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.rating,
    required this.reviews,
    required this.durationMinutes,
    required this.priceCents,
    required this.oldPriceCents,
    required this.imageAlignment,
    required this.provider,
    this.imageUrl,
    this.badge,
    this.distanceKm,
  });

  final String id;
  final String title;
  final String categoryId;
  final double rating;
  final int reviews;
  final int durationMinutes;
  final int priceCents;
  final int? oldPriceCents;
  final double imageAlignment;
  final ServiceProvider provider;
  final String? imageUrl;
  final String? badge;
  final double? distanceKm;
}
