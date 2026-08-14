import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/use_cases/request_password_reset.dart';
import 'package:help/features/auth/presentation/controllers/password_reset_state.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestPasswordReset extends Mock implements RequestPasswordReset {}

void main() {
  test('publica sucesso depois que a API aceita a solicitação', () async {
    final useCase = _MockRequestPasswordReset();
    when(
      () => useCase('user@example.com'),
    ).thenAnswer((_) async => const Success<void, AuthFailure>(null));
    final container = ProviderContainer(
      overrides: [requestPasswordResetProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(passwordResetControllerProvider.notifier)
        .submit('user@example.com');

    expect(result, isTrue);
    expect(
      container.read(passwordResetControllerProvider).status,
      PasswordResetStatus.success,
    );
  });

  test('não publica estado depois que o controller é descartado', () async {
    final useCase = _MockRequestPasswordReset();
    final completer = Completer<Result<void, AuthFailure>>();
    when(() => useCase('user@example.com')).thenAnswer((_) => completer.future);
    final container = ProviderContainer(
      overrides: [requestPasswordResetProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      passwordResetControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final future = container
        .read(passwordResetControllerProvider.notifier)
        .submit('user@example.com');

    subscription.close();
    await container.pump();
    completer.complete(const Success<void, AuthFailure>(null));

    expect(await future, isFalse);
  });
}
