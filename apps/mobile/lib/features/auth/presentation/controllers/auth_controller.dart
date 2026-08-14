import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import 'auth_form_state.dart';

export 'auth_form_state.dart';

class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _submit(
      () => ref.read(signInWithEmailProvider)(email: email, password: password),
    );
  }

  Future<bool> signInWithGoogle() {
    return _submit(ref.read(signInWithGoogleProvider).call);
  }

  Future<bool> _submit(Future<AuthResult<AuthUser>> Function() action) async {
    if (state.isLoading) return false;
    state = state.copyWith(status: AuthFormStatus.loading, clearFailure: true);

    final result = await action();
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          status: AuthFormStatus.success,
          clearFailure: true,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthFormStatus.failure,
          failure: failure,
        );
        return false;
      },
    );
  }
}
