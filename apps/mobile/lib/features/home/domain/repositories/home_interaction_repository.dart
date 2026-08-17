import 'home_repository.dart';
import '../entities/home_location.dart';

abstract interface class HomeInteractionRepository {
  Future<HomeOperationResult<void>> saveLocation(HomeLocation location);

  Future<HomeOperationResult<void>> markNotificationRead(String id);

  Future<HomeOperationResult<void>> markAllNotificationsRead();
}
