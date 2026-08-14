import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/domain/entities/user_role.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/auth_providers.dart';
import 'registration_state.dart';

class RegistrationController extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  void selectRole(UserRole role) {
    if (!state.isLoading) state = state.copyWith(selectedRole: role);
  }

  void togglePasswordVisibility() {
    if (!state.isLoading) {
      state = state.copyWith(obscurePassword: !state.obscurePassword);
    }
  }

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final role = state.selectedRole;
    if (state.isLoading || role == null) return false;
    state = state.copyWith(
      status: RegistrationStatus.loading,
      clearFailures: true,
    );

    if (!state.accountCreated) {
      final authResult = await ref.read(registerWithEmailProvider)(
        displayName: displayName,
        email: email,
        password: password,
      );
      if (!ref.mounted) return false;
      final created = authResult.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state = state.copyWith(
            status: RegistrationStatus.failure,
            authFailure: failure,
          );
          return false;
        },
      );
      if (!created) return false;
      state = state.copyWith(accountCreated: true);
    }

    final profileResult = await ref.read(registerProfileProvider)(
      displayName: displayName,
      role: role,
    );
    if (!ref.mounted) return false;
    return profileResult.fold(
      onSuccess: (_) {
        ref.invalidate(currentProfileProvider);
        state = state.copyWith(
          status: RegistrationStatus.success,
          clearFailures: true,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: RegistrationStatus.failure,
          profileFailure: failure,
          accountCreated: true,
        );
        return false;
      },
    );
  }
}
