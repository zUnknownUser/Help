import '../../domain/failures/auth_failure.dart';

enum EmailVerificationStatus { idle, sending, sent, checking, failure }

class EmailVerificationState {
  const EmailVerificationState({
    this.status = EmailVerificationStatus.idle,
    this.failure,
  });

  final EmailVerificationStatus status;
  final AuthFailure? failure;

  bool get isBusy =>
      status == EmailVerificationStatus.sending ||
      status == EmailVerificationStatus.checking;
}
