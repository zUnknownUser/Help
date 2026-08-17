import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/provider/presentation/validators/provider_service_validator.dart';

void main() {
  const validator = ProviderServiceValidator();

  test('valida os mesmos limites do domínio do backend', () {
    expect(validator.title('ab'), isNotNull);
    expect(validator.title('Limpeza residencial'), isNull);
    expect(validator.description('curta'), isNotNull);
    expect(validator.description('Descrição completa do serviço.'), isNull);
    expect(validator.duration('14'), isNotNull);
    expect(validator.duration('120'), isNull);
    expect(validator.imageUrl('file:///imagem.jpg'), isNotNull);
    expect(validator.imageUrl('https://example.com/imagem.jpg'), isNull);
  });

  test('converte valores brasileiros e decimais para centavos', () {
    expect(validator.priceInCents('1.250,90'), 125090);
    expect(validator.priceInCents('150.50'), 15050);
  });

  test('promoção exige preço anterior maior que o atual', () {
    expect(validator.oldPrice('100,00', currentPrice: '100,00'), isNotNull);
    expect(validator.oldPrice('120,00', currentPrice: '100,00'), isNull);
  });
}
