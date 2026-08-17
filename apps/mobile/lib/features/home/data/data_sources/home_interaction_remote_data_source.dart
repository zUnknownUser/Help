import '../../domain/entities/home_location.dart';

abstract interface class HomeInteractionRemoteDataSource {
  Future<void> saveLocation(HomeLocation location);
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();
}
