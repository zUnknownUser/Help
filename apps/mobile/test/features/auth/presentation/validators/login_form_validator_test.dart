import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/auth/presentation/validators/login_form_validator.dart';

void main() {
  group('LoginFormValidator', () {
    group('email', () {
      test('rejeita e-mail vazio', () {
        expect(LoginFormValidator.email(''), 'Informe seu e-mail.');
      });

      test('rejeita formato inválido', () {
        expect(
          LoginFormValidator.email('usuario@'),
          'Digite um e-mail válido.',
        );
      });

      test('aceita e-mail válido ignorando espaços externos', () {
        expect(LoginFormValidator.email('  user@email.com  '), isNull);
      });
    });

    group('password', () {
      test('rejeita senha vazia', () {
        expect(LoginFormValidator.password(''), 'Informe sua senha.');
      });

      test('rejeita senha com menos de seis caracteres', () {
        expect(
          LoginFormValidator.password('12345'),
          'A senha deve ter pelo menos 6 caracteres.',
        );
      });

      test('aceita senha válida', () {
        expect(LoginFormValidator.password('123456'), isNull);
      });
    });
  });
}
