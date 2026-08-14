import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/domain/entities/auth_user.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:help/features/auth/domain/use_cases/register_with_email.dart';
import 'package:help/features/auth/presentation/providers/auth_providers.dart';
import 'package:help/features/profile/domain/entities/user_profile.dart';
import 'package:help/features/profile/domain/entities/user_role.dart';
import 'package:help/features/profile/domain/failures/profile_failure.dart';
import 'package:help/features/profile/domain/use_cases/register_profile.dart';
import 'package:help/features/profile/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockRegisterWithEmail extends Mock implements RegisterWithEmail {}

class _MockRegisterProfile extends Mock implements RegisterProfile {}

void main() {
  late _MockRegisterWithEmail registerAccount;
  late _MockRegisterProfile registerProfile;
  late ProviderContainer container;

  setUp(() {
    registerAccount = _MockRegisterWithEmail();
    registerProfile = _MockRegisterProfile();
    container = ProviderContainer(
      overrides: [
        registerWithEmailProvider.overrideWithValue(registerAccount),
        registerProfileProvider.overrideWithValue(registerProfile),
      ],
    );
    addTearDown(container.dispose);
  });

  test('cria conta e persiste o papel de prestador', () async {
    _stubAccountSuccess(registerAccount);
    when(
      () => registerProfile(displayName: 'Maria', role: UserRole.provider),
    ).thenAnswer(
      (_) async => const Success<UserProfile, ProfileFailure>(
        UserProfile(
          email: 'maria@example.com',
          displayName: 'Maria',
          activeRole: UserRole.provider,
          roles: [UserRole.provider],
        ),
      ),
    );
    final controller = container.read(registrationControllerProvider.notifier)
      ..selectRole(UserRole.provider);

    final success = await controller.register(
      displayName: 'Maria',
      email: 'maria@example.com',
      password: '12345678',
    );

    expect(success, isTrue);
    verify(
      () => registerProfile(displayName: 'Maria', role: UserRole.provider),
    ).called(1);
  });

  test(
    'não recria a conta quando apenas o perfil precisa ser repetido',
    () async {
      _stubAccountSuccess(registerAccount);
      var profileCalls = 0;
      when(
        () => registerProfile(displayName: 'Maria', role: UserRole.customer),
      ).thenAnswer((_) async {
        profileCalls++;
        if (profileCalls == 1) {
          return const FailureResult<UserProfile, ProfileFailure>(
            ProfileFailure(ProfileFailureType.network),
          );
        }
        return const Success<UserProfile, ProfileFailure>(
          UserProfile(
            email: 'maria@example.com',
            displayName: 'Maria',
            activeRole: UserRole.customer,
            roles: [UserRole.customer],
          ),
        );
      });
      final controller = container.read(registrationControllerProvider.notifier)
        ..selectRole(UserRole.customer);

      expect(
        await controller.register(
          displayName: 'Maria',
          email: 'maria@example.com',
          password: '12345678',
        ),
        isFalse,
      );
      expect(
        await controller.register(
          displayName: 'Maria',
          email: 'maria@example.com',
          password: '12345678',
        ),
        isTrue,
      );

      verify(
        () => registerAccount(
          displayName: 'Maria',
          email: 'maria@example.com',
          password: '12345678',
        ),
      ).called(1);
    },
  );
}

void _stubAccountSuccess(_MockRegisterWithEmail useCase) {
  when(
    () => useCase(
      displayName: 'Maria',
      email: 'maria@example.com',
      password: '12345678',
    ),
  ).thenAnswer(
    (_) async => const Success<AuthUser, AuthFailure>(
      AuthUser(id: 'uid', email: 'maria@example.com'),
    ),
  );
}
