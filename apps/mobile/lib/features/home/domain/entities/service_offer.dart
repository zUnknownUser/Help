import 'service_provider.dart';

class ServiceOffer {
  const ServiceOffer({
    required this.id,
    required this.title,
    required this.rating,
    required this.reviews,
    required this.durationMinutes,
    required this.priceCents,
    required this.oldPriceCents,
    required this.imageAlignment,
    required this.provider,
    this.imageUrl,
    this.badge,
  });

  final String id;
  final String title;
  final double rating;
  final int reviews;
  final int durationMinutes;
  final int priceCents;
  final int oldPriceCents;
  final double imageAlignment;
  final ServiceProvider provider;
  final String? imageUrl;
  final String? badge;
}
