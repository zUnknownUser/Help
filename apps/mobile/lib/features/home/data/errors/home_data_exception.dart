enum HomeDataErrorCode { network, unavailable, invalidResponse, unknown }

class HomeDataException implements Exception {
  const HomeDataException(this.code, {this.debugMessage});

  final HomeDataErrorCode code;
  final String? debugMessage;
}
