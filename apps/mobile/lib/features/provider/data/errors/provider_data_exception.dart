enum ProviderDataErrorCode {
  network,
  invalidData,
  forbidden,
  notFound,
  unavailable,
  invalidResponse,
}

class ProviderDataException implements Exception {
  const ProviderDataException(this.code, {this.debugMessage});

  final ProviderDataErrorCode code;
  final String? debugMessage;

  @override
  String toString() => 'ProviderDataException($code, $debugMessage)';
}
