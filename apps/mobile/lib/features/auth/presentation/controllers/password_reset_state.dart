import '../../domain/failures/auth_failure.dart';

enum PasswordResetStatus { idle, loading, success, failure }

class PasswordResetState {
  const PasswordResetState({
    this.status = PasswordResetStatus.idle,
    this.failure,
  });

  final PasswordResetStatus status;
  final AuthFailure? failure;

  bool get isLoading => status == PasswordResetStatus.loading;
}
