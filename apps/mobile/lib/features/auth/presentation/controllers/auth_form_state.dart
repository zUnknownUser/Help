import '../../domain/failures/auth_failure.dart';

enum AuthFormStatus { idle, loading, success, failure }

class AuthFormState {
  const AuthFormState({
    this.status = AuthFormStatus.idle,
    this.obscurePassword = true,
    this.failure,
  });

  final AuthFormStatus status;
  final bool obscurePassword;
  final AuthFailure? failure;

  bool get isLoading => status == AuthFormStatus.loading;

  AuthFormState copyWith({
    AuthFormStatus? status,
    bool? obscurePassword,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return AuthFormState(
      status: status ?? this.status,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
