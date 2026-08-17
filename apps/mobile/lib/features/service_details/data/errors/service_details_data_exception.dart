class ServiceDetailsDataException implements Exception {
  const ServiceDetailsDataException(this.statusCode, {this.message});

  final int statusCode;
  final String? message;
}
