import '../../../home/domain/entities/home_location.dart';
import '../../../home/domain/entities/service_category.dart';
import '../entities/help_now_availability.dart';
import '../entities/help_now_offer.dart';
import '../entities/help_now_request.dart';

abstract interface class HelpNowRepository {
  Future<HelpNowRequest> create({
    required String clientId,
    required ServiceCategory category,
    required HomeLocation location,
    required String note,
  });

  Future<HelpNowRequest?> active();
  Future<HelpNowRequest> cancel(String requestId);
  Future<HelpNowAvailability> availability();
  Future<HelpNowAvailability> setAvailability({
    required bool enabled,
    required double latitude,
    required double longitude,
    required int maxDistanceKm,
  });
  Future<List<HelpNowOffer>> offers();
  Future<HelpNowRequest> respond({
    required String offerId,
    required String clientCommandId,
    required bool accept,
  });
}
