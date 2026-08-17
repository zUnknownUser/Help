import 'help_now_offer.dart';

class HelpNowAvailability {
  const HelpNowAvailability({
    required this.enabled,
    required this.latitude,
    required this.longitude,
    required this.maxDistanceKm,
    required this.expiresAt,
  });

  const HelpNowAvailability.disabled()
    : enabled = false,
      latitude = 0,
      longitude = 0,
      maxDistanceKm = 10,
      expiresAt = null;

  final bool enabled;
  final double latitude;
  final double longitude;
  final int maxDistanceKm;
  final DateTime? expiresAt;
}

class ProviderHelpNowState {
  const ProviderHelpNowState({
    required this.availability,
    required this.offers,
  });

  final HelpNowAvailability availability;
  final List<HelpNowOffer> offers;

  ProviderHelpNowState copyWith({
    HelpNowAvailability? availability,
    List<HelpNowOffer>? offers,
  }) => ProviderHelpNowState(
    availability: availability ?? this.availability,
    offers: offers ?? this.offers,
  );
}
