import '../../domain/entities/service_offer.dart';
import '../../domain/entities/service_provider.dart';
import 'json_reader.dart';

class ServiceOfferModel {
  const ServiceOfferModel({
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

  factory ServiceOfferModel.fromJson(Map<String, dynamic> json) =>
      ServiceOfferModel(
        id: JsonReader.string(json, 'id'),
        title: JsonReader.string(json, 'title'),
        rating: JsonReader.decimal(json, 'rating'),
        reviews: JsonReader.integer(json, 'reviews'),
        durationMinutes: JsonReader.integer(json, 'duration_minutes'),
        priceCents: JsonReader.integer(json, 'price_cents'),
        oldPriceCents: JsonReader.integer(json, 'old_price_cents'),
        imageUrl: JsonReader.optionalString(json, 'image_url'),
        imageAlignment: JsonReader.decimal(json, 'image_alignment'),
        badge: JsonReader.optionalString(json, 'badge'),
        provider: ServiceProviderModel.fromJson(
          JsonReader.map(json['provider'], 'provider'),
        ),
      );

  final String id;
  final String title;
  final double rating;
  final int reviews;
  final int durationMinutes;
  final int priceCents;
  final int oldPriceCents;
  final String? imageUrl;
  final double imageAlignment;
  final String? badge;
  final ServiceProviderModel provider;

  ServiceOffer toEntity() => ServiceOffer(
    id: id,
    title: title,
    rating: rating,
    reviews: reviews,
    durationMinutes: durationMinutes,
    priceCents: priceCents,
    oldPriceCents: oldPriceCents,
    imageUrl: imageUrl,
    imageAlignment: imageAlignment,
    badge: badge,
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
