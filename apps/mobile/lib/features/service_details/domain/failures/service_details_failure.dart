enum ServiceDetailsFailureType {
  invalid,
  notFound,
  unavailable,
  forbidden,
  addressRequired,
  conflict,
  network,
  unknown,
}

class ServiceDetailsFailure {
  const ServiceDetailsFailure(this.type, {this.message});

  final ServiceDetailsFailureType type;
  final String? message;
}
