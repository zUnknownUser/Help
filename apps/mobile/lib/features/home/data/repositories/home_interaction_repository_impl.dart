import '../../../../core/result/result.dart';
import '../../domain/failures/home_failure.dart';
import '../../domain/repositories/home_interaction_repository.dart';
import '../../domain/repositories/home_repository.dart';
import '../data_sources/home_interaction_remote_data_source.dart';
import '../errors/home_data_exception.dart';
import '../../domain/entities/home_location.dart';

class HomeInteractionRepositoryImpl implements HomeInteractionRepository {
  const HomeInteractionRepositoryImpl(this._remote);

  final HomeInteractionRemoteDataSource _remote;

  @override
  Future<HomeOperationResult<void>> saveLocation(HomeLocation location) =>
      _guard(() => _remote.saveLocation(location));

  @override
  Future<HomeOperationResult<void>> markNotificationRead(String id) =>
      _guard(() => _remote.markNotificationRead(id));

  @override
  Future<HomeOperationResult<void>> markAllNotificationsRead() =>
      _guard(_remote.markAllNotificationsRead);

  Future<HomeOperationResult<void>> _guard(
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
      return const Success<void, HomeFailure>(null);
    } on HomeDataException catch (error) {
      return FailureResult(
        HomeFailure(_map(error.code), debugMessage: error.debugMessage),
      );
    } catch (error) {
      return FailureResult(
        HomeFailure(HomeFailureType.unknown, debugMessage: '$error'),
      );
    }
  }

  HomeFailureType _map(HomeDataErrorCode code) => switch (code) {
    HomeDataErrorCode.network => HomeFailureType.network,
    HomeDataErrorCode.unavailable => HomeFailureType.unavailable,
    HomeDataErrorCode.invalidResponse => HomeFailureType.invalidResponse,
    HomeDataErrorCode.unknown => HomeFailureType.unknown,
  };
}
