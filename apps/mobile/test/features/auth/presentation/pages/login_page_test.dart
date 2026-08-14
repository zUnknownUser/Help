import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/components/app_button.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_email.dart';
import 'package:help/features/auth/domain/use_cases/sign_in_with_google.dart';
import 'package:help/features/auth/presentation/pages/login_page.dart';
import 'package:help/features/auth/presentation/pages/password_reset_page.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignInWithEmail extends Mock implements SignInWithEmail {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

void main() {
  late _MockSignInWithEmail emailUseCase;
  late _MockSignInWithGoogle googleUseCase;

  setUp(() {
    emailUseCase = _MockSignInWithEmail();
    googleUseCase = _MockSignInWithGoogle();
  });

  Future<void> pumpPage(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          signInWithEmailProvider.overrideWithValue(emailUseCase),
          signInWithGoogleProvider.overrideWithValue(googleUseCase),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const LoginPage()),
      ),
    );
  }

  testWidgets('renderiza todos os métodos e mantém Apple desabilitado', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Bem-vindo ao Help'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Continuar com Apple'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);

    final appleButton = tester.widget<AppButton>(
      find.byKey(const Key('login_apple_button')),
    );
    expect(appleButton.onPressed, isNull);
  });

  testWidgets('valida e-mail e senha antes de autenticar', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    verifyNever(
      () => emailUseCase(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('abre a recuperação de senha', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('forgot_password_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordResetPage), findsOneWidget);
  });

  testWidgets('alterna a visibilidade da senha', (tester) async {
    await pumpPage(tester);

    bool isPasswordObscured() => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('login_password_field')),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(isPasswordObscured(), isTrue);
    await tester.tap(find.byKey(const Key('login_password_visibility')));
    await tester.pump();
    expect(isPasswordObscured(), isFalse);
  });

  testWidgets('envia credenciais válidas para o controller', (tester) async {
    when(
      () => emailUseCase(email: 'user@email.com', password: '123456'),
    ).thenAnswer(
      (_) async => const Success<AuthUser, AuthFailure>(
        AuthUser(id: '1', email: 'user@email.com'),
      ),
    );
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'user@email.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    verify(
      () => emailUseCase(email: 'user@email.com', password: '123456'),
    ).called(1);
  });

  testWidgets('exibe falha amigável retornada pelo Google', (tester) async {
    when(googleUseCase.call).thenAnswer(
      (_) async => const FailureResult<AuthUser, AuthFailure>(
        AuthFailure(AuthFailureType.network),
      ),
    );
    await pumpPage(tester);

    final googleButton = find.byKey(const Key('login_google_button'));
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
  });
}
