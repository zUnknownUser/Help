import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/models/promotion_model.dart';
import 'package:help/features/home/domain/entities/promotion.dart';

void main() {
  test('mapeia apenas estilos de ação conhecidos', () {
    expect(_action('primary').toEntity().style, PromotionActionStyle.primary);
    expect(
      _action('secondary').toEntity().style,
      PromotionActionStyle.secondary,
    );
    expect(() => _action('danger').toEntity(), throwsFormatException);
  });
}

PromotionActionModel _action(String style) => PromotionActionModel.fromJson({
  'id': 'action',
  'label': 'Agendar',
  'icon_key': 'calendar',
  'style': style,
});
