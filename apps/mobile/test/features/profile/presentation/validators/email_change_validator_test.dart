import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/profile/presentation/validators/email_change_validator.dart';

void main() {
  const currentEmail = 'luis@vendlydigital.com.br';

  test('aceita um novo e-mail válido e normalizável', () {
    expect(
      validateEmailChange(
        '  novo@vendlydigital.com.br  ',
        currentEmail: currentEmail,
      ),
      isNull,
    );
  });

  test('rejeita o mesmo e-mail independentemente de caixa e espaços', () {
    expect(
      validateEmailChange(
        ' LUIS@VENDLYDIGITAL.COM.BR ',
        currentEmail: currentEmail,
      ),
      'Informe um e-mail diferente do atual.',
    );
  });

  test('rejeita formato inválido e endereço excessivamente longo', () {
    expect(
      validateEmailChange('email-invalido', currentEmail: currentEmail),
      'Informe um e-mail válido.',
    );
    expect(
      validateEmailChange(
        '${'a' * 245}@example.com',
        currentEmail: currentEmail,
      ),
      'Informe um e-mail válido.',
    );
  });
}
