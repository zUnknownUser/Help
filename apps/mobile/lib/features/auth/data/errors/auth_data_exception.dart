enum AuthDataErrorCode {
  invalidCredentials,
  network,
  tooManyRequests,
  emailAlreadyInUse,
  weakPassword,
  cancelled,
  configuration,
  unknown,
}

class AuthDataException implements Exception {
  const AuthDataException(this.code, {this.debugMessage});

  final AuthDataErrorCode code;
  final String? debugMessage;
}
