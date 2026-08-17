class ProviderService {
  const ProviderService({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.priceCents,
    this.oldPriceCents,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.published,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String title;
  final String description;
  final int durationMinutes;
  final int priceCents;
  final int? oldPriceCents;
  final String imageUrl;
  final double rating;
  final int reviews;
  final bool published;
  final DateTime updatedAt;

  ProviderService copyWith({bool? published}) => ProviderService(
    id: id,
    categoryId: categoryId,
    title: title,
    description: description,
    durationMinutes: durationMinutes,
    priceCents: priceCents,
    oldPriceCents: oldPriceCents,
    imageUrl: imageUrl,
    rating: rating,
    reviews: reviews,
    published: published ?? this.published,
    updatedAt: updatedAt,
  );
}

class ProviderServiceDraft {
  const ProviderServiceDraft({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.durationMinutes,
    required this.priceCents,
    this.oldPriceCents,
    required this.imageUrl,
    required this.published,
  });

  final String title;
  final String description;
  final String categoryId;
  final int durationMinutes;
  final int priceCents;
  final int? oldPriceCents;
  final String imageUrl;
  final bool published;
}
