import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/repositories/auth_repository.dart';
import 'package:help/features/auth/domain/use_cases/sign_out.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('delega o encerramento da sessão ao repositório', () async {
    final repository = _MockAuthRepository();
    final useCase = SignOut(repository);
    const expected = Success<void, AuthFailure>(null);
    when(repository.signOut).thenAnswer((_) async => expected);

    final result = await useCase();

    expect(result, same(expected));
    verify(repository.signOut).called(1);
  });
}
