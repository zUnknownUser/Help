import '../entities/home_location.dart';

abstract interface class LocationResolver {
  Future<HomeLocation> current({String label = 'Localização atual'});

  Future<HomeLocation> fromPostalCode({
    required String postalCode,
    required String number,
    String complement = '',
    String label = 'Endereço selecionado',
  });
}

class LocationResolutionException implements Exception {
  const LocationResolutionException(this.code);

  final LocationResolutionError code;
}

enum LocationResolutionError {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  postalCodeNotFound,
  unavailable,
}
