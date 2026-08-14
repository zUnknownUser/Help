import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_role.dart';
import '../providers/profile_providers.dart';
import 'profile_setup_state.dart';

class ProfileSetupController extends Notifier<ProfileSetupState> {
  @override
  ProfileSetupState build() => const ProfileSetupState();

  void selectRole(UserRole role) {
    if (!state.isLoading) state = state.copyWith(role: role);
  }

  Future<bool> save(String displayName) async {
    final role = state.role;
    if (role == null || state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await ref.read(registerProfileProvider)(
      displayName: displayName,
      role: role,
    );
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        ref.invalidate(currentProfileProvider);
        state = state.copyWith(isLoading: false, clearFailure: true);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
        return false;
      },
    );
  }
}
