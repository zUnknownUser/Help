import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'email_verification_state.dart';

class EmailVerificationController extends Notifier<EmailVerificationState> {
  @override
  EmailVerificationState build() => const EmailVerificationState();

  Future<void> send() async {
    if (state.isBusy) return;
    state = const EmailVerificationState(
      status: EmailVerificationStatus.sending,
    );
    final result = await ref.read(requestEmailVerificationProvider)();
    if (!ref.mounted) return;
    result.fold(
      onSuccess: (_) => state = const EmailVerificationState(
        status: EmailVerificationStatus.sent,
      ),
      onFailure: (failure) => state = EmailVerificationState(
        status: EmailVerificationStatus.failure,
        failure: failure,
      ),
    );
  }

  Future<bool> check() async {
    if (state.isBusy) return false;
    state = const EmailVerificationState(
      status: EmailVerificationStatus.checking,
    );
    final result = await ref.read(refreshCurrentUserProvider)();
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (user) {
        state = const EmailVerificationState(
          status: EmailVerificationStatus.sent,
        );
        return user.emailVerified;
      },
      onFailure: (failure) {
        state = EmailVerificationState(
          status: EmailVerificationStatus.failure,
          failure: failure,
        );
        return false;
      },
    );
  }
}
