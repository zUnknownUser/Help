import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/repositories/auth_repository.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_email.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_google.dart';
import 'package:help/features/auth/presentation/controllers/auth_controller.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignInWithEmail extends Mock implements SignInWithEmail {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

void main() {
  late _MockSignInWithEmail emailUseCase;
  late _MockSignInWithGoogle googleUseCase;
  late ProviderContainer container;

  setUp(() {
    emailUseCase = _MockSignInWithEmail();
    googleUseCase = _MockSignInWithGoogle();
    container = ProviderContainer(
      overrides: [
        signInWithEmailProvider.overrideWithValue(emailUseCase),
        signInWithGoogleProvider.overrideWithValue(googleUseCase),
      ],
    );
    addTearDown(container.dispose);
  });

  test('alterna a visibilidade da senha', () {
    final controller = container.read(authControllerProvider.notifier);

    expect(container.read(authControllerProvider).obscurePassword, isTrue);
    controller.togglePasswordVisibility();
    expect(container.read(authControllerProvider).obscurePassword, isFalse);
  });

  test('expõe loading e sucesso durante login por e-mail', () async {
    final completer = Completer<AuthResult<AuthUser>>();
    when(
      () => emailUseCase(email: 'user@email.com', password: '123456'),
    ).thenAnswer((_) => completer.future);
    final controller = container.read(authControllerProvider.notifier);

    final future = controller.signInWithEmail(
      email: 'user@email.com',
      password: '123456',
    );

    expect(
      container.read(authControllerProvider).status,
      AuthFormStatus.loading,
    );
    completer.complete(
      const Success<AuthUser, AuthFailure>(
        AuthUser(id: '1', email: 'user@email.com'),
      ),
    );
    expect(await future, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthFormStatus.success,
    );
  });

  test('expõe uma falha amigável durante login por Google', () async {
    const failure = AuthFailure(AuthFailureType.network);
    when(googleUseCase.call).thenAnswer(
      (_) async => const FailureResult<AuthUser, AuthFailure>(failure),
    );
    final controller = container.read(authControllerProvider.notifier);

    final succeeded = await controller.signInWithGoogle();

    expect(succeeded, isFalse);
    expect(
      container.read(authControllerProvider).status,
      AuthFormStatus.failure,
    );
    expect(container.read(authControllerProvider).failure, failure);
  });

  test('não publica estado depois que o controller é descartado', () async {
    final completer = Completer<AuthResult<AuthUser>>();
    when(googleUseCase.call).thenAnswer((_) => completer.future);
    final subscription = container.listen(
      authControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final future = container
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    subscription.close();
    await container.pump();
    completer.complete(
      const Success<AuthUser, AuthFailure>(
        AuthUser(id: '1', email: 'user@email.com'),
      ),
    );

    expect(await future, isFalse);
  });
}
