enum ProfileFailureType {
  notFound,
  unauthorized,
  invalidData,
  network,
  unavailable,
  unknown,
}

class ProfileFailure {
  const ProfileFailure(this.type, {this.debugMessage});

  final ProfileFailureType type;
  final String? debugMessage;
}
