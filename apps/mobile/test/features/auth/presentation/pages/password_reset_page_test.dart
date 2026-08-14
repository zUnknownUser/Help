import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/use_cases/request_password_reset.dart';
import 'package:help/features/auth/presentation/pages/password_reset_page.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestPasswordReset extends Mock implements RequestPasswordReset {}

void main() {
  testWidgets('valida o e-mail antes de chamar a API', (tester) async {
    final useCase = _MockRequestPasswordReset();
    await _pumpPage(tester, useCase);

    await tester.tap(find.byKey(const Key('password_reset_submit_button')));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    verifyNever(() => useCase(any()));
  });

  testWidgets('mostra confirmação genérica após o envio', (tester) async {
    final useCase = _MockRequestPasswordReset();
    when(
      () => useCase('user@example.com'),
    ).thenAnswer((_) async => const Success<void, AuthFailure>(null));
    await _pumpPage(tester, useCase);

    await tester.enterText(
      find.byKey(const Key('password_reset_email_field')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('password_reset_submit_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Se existir uma conta'), findsOneWidget);
    verify(() => useCase('user@example.com')).called(1);
  });
}

Future<void> _pumpPage(WidgetTester tester, RequestPasswordReset useCase) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [requestPasswordResetProvider.overrideWithValue(useCase)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PasswordResetPage(),
      ),
    ),
  );
}
