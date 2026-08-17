import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/components/app_loading.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/use_cases/request_email_verification.dart';
import 'package:help/features/auth/presentation/pages/auth_gate.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:help/core/result/result.dart';
import 'package:help/core/session/session_lifecycle.dart';
import 'package:help/features/chat/presentation/providers/chat_providers.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/presentation/controllers/home_controller.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';
import 'package:help/features/profile/domain/entities/user_profile.dart';
import 'package:help/features/profile/domain/entities/user_role.dart';
import 'package:help/features/profile/presentation/controllers/profile_controller.dart';
import 'package:help/features/profile/presentation/pages/account_page.dart';
import 'package:help/features/profile/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../home/fixtures/home_content_fixture.dart';

class _FixtureHomeController extends HomeController {
  @override
  Future<HomeContent> build() async => HomeContentFixture.content;
}

class _FixtureProfileController extends ProfileController {
  _FixtureProfileController(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile> build() async => profile;
}

class _MockRequestEmailVerification extends Mock
    implements RequestEmailVerification {}

void main() {
  Future<void> pumpGate(
    WidgetTester tester,
    Stream<AuthUser?> session, {
    UserProfile profile = const UserProfile(
      email: 'user@email.com',
      displayName: 'User',
      activeRole: UserRole.customer,
      roles: [UserRole.customer],
    ),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => session),
          homeControllerProvider.overrideWith(_FixtureHomeController.new),
          currentProfileProvider.overrideWith(
            () => _FixtureProfileController(profile),
          ),
          sessionStarterProvider.overrideWithValue((_) {}),
          unreadChatCountProvider.overrideWith((ref) => Stream.value(0)),
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
      Stream.value(
        const AuthUser(id: '1', email: 'user@email.com', emailVerified: true),
      ),
    );

    expect(find.text('Serviços populares'), findsOneWidget);
    expect(find.text('Bem-vindo ao Help'), findsNothing);
  });

  testWidgets('pede confirmação para sessão com e-mail não verificado', (
    tester,
  ) async {
    final request = _MockRequestEmailVerification();
    when(
      request.call,
    ).thenAnswer((_) async => const Success<void, AuthFailure>(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) =>
                Stream.value(const AuthUser(id: '1', email: 'user@email.com')),
          ),
          requestEmailVerificationProvider.overrideWithValue(request),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    verify(request.call).called(1);
  });

  testWidgets('leva prestador para sua própria jornada', (tester) async {
    await pumpGate(
      tester,
      Stream.value(
        const AuthUser(id: '1', email: 'pro@example.com', emailVerified: true),
      ),
      profile: const UserProfile(
        email: 'pro@example.com',
        displayName: 'Profissional',
        activeRole: UserRole.provider,
        roles: [UserRole.provider],
        providerStatus: ProviderOnboardingStatus.pending,
      ),
    );

    expect(find.text('Seu perfil está em análise'), findsOneWidget);
    expect(find.text('Serviços populares'), findsNothing);
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

  testWidgets('remove rotas protegidas da pilha depois de sair da conta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = StreamController<AuthUser?>();
    final signOutCompletion = Completer<void>();
    final navigatorKey = GlobalKey<NavigatorState>();
    var signOutCalls = 0;
    addTearDown(session.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => session.stream),
          homeControllerProvider.overrideWith(_FixtureHomeController.new),
          currentProfileProvider.overrideWith(
            () => _FixtureProfileController(
              const UserProfile(
                email: 'user@email.com',
                displayName: 'User',
                activeRole: UserRole.customer,
                roles: [UserRole.customer],
              ),
            ),
          ),
          sessionStarterProvider.overrideWithValue((_) {}),
          unreadChatCountProvider.overrideWith((ref) => Stream.value(0)),
          signOutProvider.overrideWithValue(() async {
            signOutCalls++;
            await signOutCompletion.future;
            session.add(null);
          }),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: const AuthGate()),
      ),
    );
    session.add(
      const AuthUser(id: '1', email: 'user@email.com', emailVerified: true),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer_sign_out_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await tester.pump();

    expect(find.byType(AppProgressIndicator), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);

    signOutCompletion.complete();
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
    expect(find.text('Bem-vindo ao Help'), findsOneWidget);
    expect(find.text('Conta'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
