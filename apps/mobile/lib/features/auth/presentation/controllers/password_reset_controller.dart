import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'password_reset_state.dart';

class PasswordResetController extends Notifier<PasswordResetState> {
  @override
  PasswordResetState build() => const PasswordResetState();

  Future<bool> submit(String email) async {
    if (state.isLoading) return false;
    state = const PasswordResetState(status: PasswordResetStatus.loading);

    final result = await ref.read(requestPasswordResetProvider)(email);
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        state = const PasswordResetState(status: PasswordResetStatus.success);
        return true;
      },
      onFailure: (failure) {
        state = PasswordResetState(
          status: PasswordResetStatus.failure,
          failure: failure,
        );
        return false;
      },
    );
  }
}
