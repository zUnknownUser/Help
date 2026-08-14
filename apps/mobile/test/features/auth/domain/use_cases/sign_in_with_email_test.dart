import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/repositories/auth_repository.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_email.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthRepository repository;
  late SignInWithEmail useCase;

  setUp(() {
    repository = _MockAuthRepository();
    useCase = SignInWithEmail(repository);
  });

  test('normaliza o e-mail e devolve o resultado do repositório', () async {
    const user = AuthUser(id: '1', email: 'user@email.com');
    const expected = Success<AuthUser, AuthFailure>(user);
    when(
      () => repository.signInWithEmail(
        email: 'user@email.com',
        password: '123456',
      ),
    ).thenAnswer((_) async => expected);

    final result = await useCase(
      email: '  user@email.com  ',
      password: '123456',
    );

    expect(result, same(expected));
    verify(
      () => repository.signInWithEmail(
        email: 'user@email.com',
        password: '123456',
      ),
    ).called(1);
  });
}
