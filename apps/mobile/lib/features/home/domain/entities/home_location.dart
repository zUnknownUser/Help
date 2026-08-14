class HomeLocation {
  const HomeLocation({
    required this.address,
    required this.availabilityLabel,
    this.postalCode = '',
    this.street = '',
    this.streetNumber = '',
    this.complement = '',
    this.district = '',
    this.city = '',
    this.state = '',
    this.latitude,
    this.longitude,
  });

  final String address;
  final String availabilityLabel;
  final String postalCode;
  final String street;
  final String streetNumber;
  final String complement;
  final String district;
  final String city;
  final String state;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  HomeLocation copyWith({
    String? availabilityLabel,
    String? streetNumber,
    String? complement,
    String? address,
  }) => HomeLocation(
    address: address ?? this.address,
    availabilityLabel: availabilityLabel ?? this.availabilityLabel,
    postalCode: postalCode,
    street: street,
    streetNumber: streetNumber ?? this.streetNumber,
    complement: complement ?? this.complement,
    district: district,
    city: city,
    state: state,
    latitude: latitude,
    longitude: longitude,
  );
}
