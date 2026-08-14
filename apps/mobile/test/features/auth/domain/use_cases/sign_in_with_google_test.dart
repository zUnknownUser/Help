import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/repositories/auth_repository.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_google.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('delega o login Google ao repositório', () async {
    final repository = _MockAuthRepository();
    final useCase = SignInWithGoogle(repository);
    const expected = Success<AuthUser, AuthFailure>(
      AuthUser(id: 'google-user', email: 'user@gmail.com'),
    );
    when(repository.signInWithGoogle).thenAnswer((_) async => expected);

    final result = await useCase();

    expect(result, same(expected));
    verify(repository.signInWithGoogle).called(1);
  });
}
