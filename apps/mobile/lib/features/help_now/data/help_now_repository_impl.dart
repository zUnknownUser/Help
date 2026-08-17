import '../../home/domain/entities/home_location.dart';
import '../../home/domain/entities/service_category.dart';
import '../domain/entities/help_now_availability.dart';
import '../domain/entities/help_now_offer.dart';
import '../domain/entities/help_now_request.dart';
import '../domain/repositories/help_now_repository.dart';
import 'help_now_remote_api.dart';

class HelpNowRepositoryImpl implements HelpNowRepository {
  const HelpNowRepositoryImpl(this.remote);

  final HelpNowRemoteApi remote;

  @override
  Future<HelpNowRequest> create({
    required String clientId,
    required ServiceCategory category,
    required HomeLocation location,
    required String note,
  }) => remote.create({
    'client_id': clientId,
    'category_id': category.id,
    'note': note.trim(),
    'address_label': location.availabilityLabel,
    'address': location.address,
    'latitude': location.latitude,
    'longitude': location.longitude,
  });

  @override
  Future<HelpNowRequest?> active() => remote.active();

  @override
  Future<HelpNowRequest> cancel(String requestId) => remote.cancel(requestId);

  @override
  Future<HelpNowAvailability> availability() => remote.availability();

  @override
  Future<HelpNowAvailability> setAvailability({
    required bool enabled,
    required double latitude,
    required double longitude,
    required int maxDistanceKm,
  }) => remote.setAvailability({
    'enabled': enabled,
    'latitude': latitude,
    'longitude': longitude,
    'max_distance_km': maxDistanceKm,
  });

  @override
  Future<List<HelpNowOffer>> offers() => remote.offers();

  @override
  Future<HelpNowRequest> respond({
    required String offerId,
    required String clientCommandId,
    required bool accept,
  }) => remote.respond(
    offerId: offerId,
    clientCommandId: clientCommandId,
    accept: accept,
  );
}
