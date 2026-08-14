import '../../../../core/result/result.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/failures/home_failure.dart';
import '../../domain/repositories/home_repository.dart';
import '../data_sources/home_cache_data_source.dart';
import '../data_sources/home_remote_data_source.dart';
import '../errors/home_data_exception.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({required this.remote, required this.cache});

  final HomeRemoteDataSource remote;
  final HomeCacheDataSource cache;

  @override
  Future<HomeResult> getHome() async {
    try {
      final model = await remote.fetchHome();
      cache.write(model);
      return Success<HomeContent, HomeFailure>(model.toEntity());
    } on HomeDataException catch (error) {
      final cached = cache.read();
      if (cached != null) {
        return Success<HomeContent, HomeFailure>(cached.toEntity());
      }
      return FailureResult<HomeContent, HomeFailure>(
        HomeFailure(_mapFailure(error.code), debugMessage: error.debugMessage),
      );
    } catch (error) {
      return FailureResult<HomeContent, HomeFailure>(
        HomeFailure(HomeFailureType.unknown, debugMessage: error.toString()),
      );
    }
  }

  HomeFailureType _mapFailure(HomeDataErrorCode code) => switch (code) {
    HomeDataErrorCode.network => HomeFailureType.network,
    HomeDataErrorCode.unavailable => HomeFailureType.unavailable,
    HomeDataErrorCode.invalidResponse => HomeFailureType.invalidResponse,
    HomeDataErrorCode.unknown => HomeFailureType.unknown,
  };
}
