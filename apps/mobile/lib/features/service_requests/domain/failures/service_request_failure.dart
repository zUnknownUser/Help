enum ServiceRequestFailureType {
  network,
  forbidden,
  notFound,
  conflict,
  unavailable,
  invalidResponse,
}

class ServiceRequestFailure {
  const ServiceRequestFailure(this.type, {this.message});
  final ServiceRequestFailureType type;
  final String? message;
}
