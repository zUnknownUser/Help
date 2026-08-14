import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/auth/presentation/validators/registration_form_validator.dart';

void main() {
  test('normaliza e valida nome completo', () {
    expect(RegistrationFormValidator.displayName('M'), isNotNull);
    expect(RegistrationFormValidator.displayName('Maria Silva'), isNull);
  });

  test('exige senha segura o bastante para o cadastro', () {
    expect(RegistrationFormValidator.password('1234567'), isNotNull);
    expect(RegistrationFormValidator.password('12345678'), isNull);
  });

  test('confirma que as senhas coincidem', () {
    expect(
      RegistrationFormValidator.passwordConfirmation('outra', '12345678'),
      isNotNull,
    );
    expect(
      RegistrationFormValidator.passwordConfirmation('12345678', '12345678'),
      isNull,
    );
  });
}
