enum ProfileDataErrorCode {
  notFound,
  unauthorized,
  invalidData,
  network,
  unavailable,
  unknown,
}

class ProfileDataException implements Exception {
  const ProfileDataException(this.code, {this.debugMessage});

  final ProfileDataErrorCode code;
  final String? debugMessage;
}
