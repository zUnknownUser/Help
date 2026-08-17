import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/extensions/auth_failure_message.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../data/providers/profile_data_providers.dart';
import '../extensions/profile_failure_message.dart';
import '../providers/profile_providers.dart';

class EmailChangeState {
  const EmailChangeState({
    this.isLoading = false,
    this.verificationSent = false,
    this.message,
  });

  final bool isLoading;
  final bool verificationSent;
  final String? message;
}

class EmailChangeController extends Notifier<EmailChangeState> {
  @override
  EmailChangeState build() => const EmailChangeState();

  Future<bool> request(String email, String password) async {
    if (state.isLoading) return false;
    state = const EmailChangeState(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .requestEmailChange(
          newEmail: email,
          currentPassword: password.trim().isEmpty ? null : password,
        );
    return result.fold(
      onSuccess: (_) {
        state = const EmailChangeState(verificationSent: true);
        return true;
      },
      onFailure: (failure) {
        state = EmailChangeState(message: failure.userMessage);
        return false;
      },
    );
  }

  Future<bool> confirm(String expectedEmail) async {
    if (state.isLoading) return false;
    state = const EmailChangeState(isLoading: true, verificationSent: true);
    final refreshed = await ref
        .read(authRepositoryProvider)
        .refreshCurrentUser();
    final user = refreshed.fold(
      onSuccess: (value) => value,
      onFailure: (failure) {
        state = EmailChangeState(
          verificationSent: true,
          message: failure.userMessage,
        );
        return null;
      },
    );
    if (user == null) return false;
    if (user.email.toLowerCase() != expectedEmail.trim().toLowerCase()) {
      state = const EmailChangeState(
        verificationSent: true,
        message:
            'A confirmação ainda não foi concluída. Abra o link recebido e tente novamente.',
      );
      return false;
    }
    final synced = await ref.read(profileRepositoryProvider).syncEmail();
    return synced.fold(
      onSuccess: (profile) {
        ref.read(currentProfileProvider.notifier).replace(profile);
        state = const EmailChangeState(verificationSent: true);
        return true;
      },
      onFailure: (failure) {
        state = EmailChangeState(
          verificationSent: true,
          message: failure.userMessage,
        );
        return false;
      },
    );
  }
}

final emailChangeControllerProvider =
    NotifierProvider.autoDispose<EmailChangeController, EmailChangeState>(
      EmailChangeController.new,
    );
