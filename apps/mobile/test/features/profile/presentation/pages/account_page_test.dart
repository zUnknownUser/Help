import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/entities/home_location.dart';
import 'package:help/features/home/presentation/controllers/home_controller.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';
import 'package:help/features/profile/domain/entities/user_profile.dart';
import 'package:help/features/profile/domain/entities/user_role.dart';
import 'package:help/features/profile/presentation/controllers/profile_controller.dart';
import 'package:help/features/profile/presentation/pages/account_page.dart';
import 'package:help/features/profile/presentation/providers/profile_providers.dart';
import 'package:help/features/profile/presentation/widgets/account_content.dart';

void main() {
  testWidgets('shows customer-context account hierarchy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(_ProfileControllerStub.new),
          homeControllerProvider.overrideWith(_HomeControllerStub.new),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('Meus pedidos'), findsOneWidget);
    expect(find.text('Endereço e localização'), findsOneWidget);
    expect(_asset('assets/icons/conversations.png'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Também quero oferecer serviços'),
      350,
    );
    expect(find.text('Também quero oferecer serviços'), findsOneWidget);
    expect(_asset('assets/icons/sign_out.png'), findsOneWidget);
    expect(_asset('assets/illustrations/provider_sign_out.png'), findsNothing);
  });

  testWidgets('uses the professional sign-out illustration for providers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountContent(
          profile: const UserProfile(
            email: 'luis@example.com',
            displayName: 'Luis',
            activeRole: UserRole.provider,
            roles: [UserRole.customer, UserRole.provider],
          ),
          location: const HomeLocation(address: '', availabilityLabel: ''),
          roleLoading: false,
          signOutLoading: false,
          onProfile: _noop,
          onRequests: _noop,
          onChat: _noop,
          onLocation: _noop,
          onNotifications: _noop,
          onProfessionalArea: _noop,
          onSecurity: _noop,
          onHelp: _noop,
          onAbout: _noop,
          onSwitchRole: _noop,
          onSignOut: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sair da conta'), 350);

    expect(
      _asset('assets/illustrations/provider_sign_out.png'),
      findsOneWidget,
    );
    expect(_asset('assets/icons/sign_out.png'), findsNothing);
  });
}

Finder _asset(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == name,
);

void _noop() {}

class _ProfileControllerStub extends ProfileController {
  @override
  Future<UserProfile> build() async => const UserProfile(
    email: 'luis@example.com',
    displayName: 'Luis',
    activeRole: UserRole.customer,
    roles: [UserRole.customer],
  );
}

class _HomeControllerStub extends HomeController {
  @override
  Future<HomeContent> build() async => const HomeContent.empty();
}
