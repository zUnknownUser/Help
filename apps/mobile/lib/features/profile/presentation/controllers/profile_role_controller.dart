import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_role.dart';
import '../providers/profile_providers.dart';
import 'profile_role_state.dart';

class ProfileRoleController extends Notifier<ProfileRoleState> {
  @override
  ProfileRoleState build() => const ProfileRoleState();

  Future<bool> activate({
    required UserRole role,
    required String displayName,
  }) async {
    if (state.isLoading) return false;
    state = const ProfileRoleState(isLoading: true);
    final result = await ref.read(registerProfileProvider)(
      displayName: displayName,
      role: role,
    );
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        ref.invalidate(currentProfileProvider);
        state = const ProfileRoleState();
        return true;
      },
      onFailure: (failure) {
        state = ProfileRoleState(failure: failure);
        return false;
      },
    );
  }
}
