enum SchedulingFailureType {
  network,
  invalid,
  forbidden,
  notFound,
  conflict,
  unavailable,
  invalidResponse,
  unknown,
}

class SchedulingFailure {
  const SchedulingFailure(this.type, {this.message});
  final SchedulingFailureType type;
  final String? message;
}
