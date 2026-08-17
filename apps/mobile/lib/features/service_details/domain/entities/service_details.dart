import '../../../home/domain/entities/service_offer.dart';

class ServiceDetails {
  const ServiceDetails({
    required this.offer,
    required this.description,
    required this.providerUserId,
    required this.serviceArea,
    required this.canRequest,
    required this.requestBlockedReason,
    this.requestAddress,
  });

  final ServiceOffer offer;
  final String description;
  final String providerUserId;
  final String serviceArea;
  final bool canRequest;
  final String requestBlockedReason;
  final ServiceRequestAddress? requestAddress;
}

class ServiceRequestAddress {
  const ServiceRequestAddress({
    required this.label,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String formattedAddress;
  final double latitude;
  final double longitude;
}
