import 'home_location.dart';
import 'service_offer.dart';

enum CatalogSort { distance, newest, price, rating }

class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.categoryId = '',
    this.minPriceCents,
    this.maxPriceCents,
    this.minRating,
    this.verified,
    this.radiusKm = 30,
    this.sort = CatalogSort.distance,
    this.cursor = '',
    this.limit = 20,
    this.location,
  });

  final String text;
  final String categoryId;
  final int? minPriceCents;
  final int? maxPriceCents;
  final double? minRating;
  final bool? verified;
  final double radiusKm;
  final CatalogSort sort;
  final String cursor;
  final int limit;
  final HomeLocation? location;

  CatalogQuery copyWith({
    String? text,
    String? categoryId,
    int? minPriceCents,
    int? maxPriceCents,
    double? minRating,
    bool? verified,
    double? radiusKm,
    CatalogSort? sort,
    String? cursor,
  }) => CatalogQuery(
    text: text ?? this.text,
    categoryId: categoryId ?? this.categoryId,
    minPriceCents: minPriceCents ?? this.minPriceCents,
    maxPriceCents: maxPriceCents ?? this.maxPriceCents,
    minRating: minRating ?? this.minRating,
    verified: verified ?? this.verified,
    radiusKm: radiusKm ?? this.radiusKm,
    sort: sort ?? this.sort,
    cursor: cursor ?? this.cursor,
    limit: limit,
    location: location,
  );
}

class CatalogPage {
  const CatalogPage({required this.items, required this.nextCursor});
  final List<ServiceOffer> items;
  final String nextCursor;
}
