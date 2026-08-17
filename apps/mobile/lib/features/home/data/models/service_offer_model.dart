import '../../domain/entities/service_offer.dart';
import '../../domain/entities/service_provider.dart';
import 'json_reader.dart';

class ServiceOfferModel {
  const ServiceOfferModel({
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

  factory ServiceOfferModel.fromJson(Map<String, dynamic> json) =>
      ServiceOfferModel(
        id: JsonReader.string(json, 'id'),
        title: JsonReader.string(json, 'title'),
        categoryId: JsonReader.optionalString(json, 'category_id') ?? '',
        rating: JsonReader.decimal(json, 'rating'),
        reviews: JsonReader.integer(json, 'reviews'),
        durationMinutes: JsonReader.integer(json, 'duration_minutes'),
        priceCents: JsonReader.integer(json, 'price_cents'),
        oldPriceCents: json['old_price_cents'] == null
            ? null
            : JsonReader.integer(json, 'old_price_cents'),
        imageUrl: JsonReader.optionalString(json, 'image_url'),
        imageAlignment: JsonReader.decimal(json, 'image_alignment'),
        badge: JsonReader.optionalString(json, 'badge'),
        distanceKm: JsonReader.optionalDecimal(json, 'distance_km'),
        provider: ServiceProviderModel.fromJson(
          JsonReader.map(json['provider'], 'provider'),
        ),
      );

  final String id;
  final String title;
  final String categoryId;
  final double rating;
  final int reviews;
  final int durationMinutes;
  final int priceCents;
  final int? oldPriceCents;
  final String? imageUrl;
  final double imageAlignment;
  final String? badge;
  final double? distanceKm;
  final ServiceProviderModel provider;

  ServiceOffer toEntity() => ServiceOffer(
    id: id,
    title: title,
    categoryId: categoryId,
    rating: rating,
    reviews: reviews,
    durationMinutes: durationMinutes,
    priceCents: priceCents,
    oldPriceCents: oldPriceCents,
    imageUrl: imageUrl,
    imageAlignment: imageAlignment,
    badge: badge,
    distanceKm: distanceKm,
    provider: provider.toEntity(),
  );
}

class ServiceProviderModel {
  const ServiceProviderModel(this.id, this.name, this.verified);

  factory ServiceProviderModel.fromJson(Map<String, dynamic> json) =>
      ServiceProviderModel(
        JsonReader.string(json, 'id'),
        JsonReader.string(json, 'name'),
        JsonReader.boolean(json, 'verified'),
      );

  final String id;
  final String name;
  final bool verified;

  ServiceProvider toEntity() =>
      ServiceProvider(id: id, name: name, verified: verified);
}
