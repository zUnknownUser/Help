enum HomeFailureType { network, unavailable, invalidResponse, unknown }

class HomeFailure {
  const HomeFailure(this.type, {this.debugMessage});

  final HomeFailureType type;
  final String? debugMessage;
}
