import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/presentation/pages/auth_gate.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/presentation/controllers/home_controller.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';

import '../../../home/fixtures/home_content_fixture.dart';

class _FixtureHomeController extends HomeController {
  @override
  Future<HomeContent> build() async => HomeContentFixture.content;
}

void main() {
  Future<void> pumpGate(WidgetTester tester, Stream<AuthUser?> session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => session),
          homeControllerProvider.overrideWith(_FixtureHomeController.new),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra Login quando não há sessão', (tester) async {
    await pumpGate(tester, Stream.value(null));

    expect(find.text('Bem-vindo ao Help'), findsOneWidget);
    expect(find.text('Serviços populares'), findsNothing);
  });

  testWidgets('mostra Home quando há sessão autenticada', (tester) async {
    await pumpGate(
      tester,
      Stream.value(const AuthUser(id: '1', email: 'user@email.com')),
    );

    expect(find.text('Serviços populares'), findsOneWidget);
    expect(find.text('Bem-vindo ao Help'), findsNothing);
  });

  testWidgets('permite tentar novamente quando a sessão falha', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) {
            attempts++;
            return attempts == 1
                ? Stream<AuthUser?>.error(StateError('offline'))
                : Stream<AuthUser?>.value(null);
          }),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_retry_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth_retry_button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Bem-vindo ao Help'), findsOneWidget);
  });
}
