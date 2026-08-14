enum ProviderFailureType {
  network,
  invalidData,
  forbidden,
  notFound,
  unavailable,
  invalidResponse,
  unknown,
}

class ProviderFailure {
  const ProviderFailure(this.type, {this.debugMessage});

  final ProviderFailureType type;
  final String? debugMessage;
}
