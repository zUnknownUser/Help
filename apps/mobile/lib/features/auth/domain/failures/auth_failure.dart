enum AuthFailureType {
  invalidCredentials,
  network,
  tooManyRequests,
  emailAlreadyInUse,
  weakPassword,
  cancelled,
  configuration,
  invalidEmail,
  recentLoginRequired,
  unknown,
}

class AuthFailure {
  const AuthFailure(this.type, {this.debugMessage});

  final AuthFailureType type;
  final String? debugMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}
