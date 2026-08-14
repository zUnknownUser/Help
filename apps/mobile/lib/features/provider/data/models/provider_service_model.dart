import '../../domain/entities/provider_service.dart';
import 'provider_json.dart';

class ProviderServiceModel {
  const ProviderServiceModel(this.value);

  factory ProviderServiceModel.fromJson(Map<String, dynamic> json) =>
      ProviderServiceModel(
        ProviderService(
          id: ProviderJson.string(json, 'id'),
          categoryId: ProviderJson.string(json, 'category_id'),
          title: ProviderJson.string(json, 'title'),
          description: ProviderJson.string(json, 'description'),
          durationMinutes: ProviderJson.integer(json, 'duration_minutes'),
          priceCents: ProviderJson.integer(json, 'price_cents'),
          imageUrl: ProviderJson.string(json, 'image_url'),
          rating: ProviderJson.decimal(json, 'rating'),
          reviews: ProviderJson.integer(json, 'reviews'),
          published: ProviderJson.boolean(json, 'published'),
          updatedAt: DateTime.parse(ProviderJson.string(json, 'updated_at')),
        ),
      );

  final ProviderService value;

  ProviderService toEntity() => value;
}
