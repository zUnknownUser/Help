import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/catalog_query.dart';
import '../models/service_offer_model.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource({required this._client, required String baseUrl})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<CatalogPage> search(CatalogQuery query) async {
    final location = query.location;
    final uri = Uri.parse('$_baseUrl/v1/services').replace(
      queryParameters: {
        'limit': '${query.limit}',
        'sort': query.sort.name,
        'radius_km': '${query.radiusKm}',
        if (query.text.trim().isNotEmpty) 'query': query.text.trim(),
        if (query.categoryId.isNotEmpty) 'category_id': query.categoryId,
        if (query.minPriceCents != null)
          'min_price_cents': '${query.minPriceCents}',
        if (query.maxPriceCents != null)
          'max_price_cents': '${query.maxPriceCents}',
        if (query.minRating != null) 'min_rating': '${query.minRating}',
        if (query.verified != null) 'verified': '${query.verified}',
        if (query.cursor.isNotEmpty) 'cursor': query.cursor,
        if (location?.latitude != null) 'latitude': '${location!.latitude}',
        if (location?.longitude != null) 'longitude': '${location!.longitude}',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('catalog HTTP ${response.statusCode}');
    }
    final envelope =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = (envelope['data'] as List)
        .map(
          (item) => ServiceOfferModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).toEntity(),
        )
        .toList(growable: false);
    return CatalogPage(
      items: items,
      nextCursor: envelope['next_cursor'] as String? ?? '',
    );
  }
}
