import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/repositories/password_reset_repository.dart';
import 'package:help/features/auth/domain/use_cases/request_password_reset.dart';
import 'package:mocktail/mocktail.dart';

class _MockPasswordResetRepository extends Mock
    implements PasswordResetRepository {}

void main() {
  test('normaliza o e-mail antes de solicitar a recuperação', () async {
    final repository = _MockPasswordResetRepository();
    when(
      () => repository.requestPasswordReset('user@example.com'),
    ).thenAnswer((_) async => const Success<void, AuthFailure>(null));
    final useCase = RequestPasswordReset(repository);

    final result = await useCase(' User@Example.COM ');

    expect(result.isSuccess, isTrue);
    verify(() => repository.requestPasswordReset('user@example.com')).called(1);
  });
}
