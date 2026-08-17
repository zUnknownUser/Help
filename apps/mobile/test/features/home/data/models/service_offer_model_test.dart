import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/models/service_offer_model.dart';

void main() {
  test('aceita serviço antigo sem categoria sem derrubar a Home', () {
    final offer = ServiceOfferModel.fromJson({
      'id': 'service-1',
      'title': 'Limpeza',
      'rating': 0,
      'reviews': 0,
      'duration_minutes': 60,
      'price_cents': 10000,
      'old_price_cents': 10000,
      'image_alignment': 0,
      'provider': {'id': 'provider-1', 'name': 'Luis', 'verified': false},
    }).toEntity();

    expect(offer.categoryId, isEmpty);
  });

  test('aceita preço anterior ausente quando não existe promoção', () {
    final offer = ServiceOfferModel.fromJson({
      'id': 'service-2',
      'title': 'Manutenção',
      'category_id': '',
      'rating': 0,
      'reviews': 0,
      'duration_minutes': 90,
      'price_cents': 15000,
      'old_price_cents': null,
      'image_alignment': 0,
      'provider': {'id': 'provider-1', 'name': 'Luis', 'verified': true},
    }).toEntity();

    expect(offer.oldPriceCents, isNull);
  });
}
