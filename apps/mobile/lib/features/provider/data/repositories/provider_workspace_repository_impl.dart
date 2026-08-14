import '../../../../core/result/result.dart';
import '../../domain/entities/provider_service.dart';
import '../../domain/entities/provider_workspace.dart';
import '../../domain/failures/provider_failure.dart';
import '../../domain/repositories/provider_workspace_repository.dart';
import '../data_sources/provider_workspace_remote_data_source.dart';
import '../errors/provider_data_exception.dart';
import '../models/provider_service_model.dart';

class ProviderWorkspaceRepositoryImpl implements ProviderWorkspaceRepository {
  const ProviderWorkspaceRepositoryImpl(this._remote);

  final ProviderWorkspaceRemoteDataSource _remote;

  @override
  Future<ProviderResult<ProviderWorkspace>> getHome() =>
      _guard(() async => (await _remote.fetchHome()).toEntity());

  @override
  Future<ProviderResult<ProviderService>> createService(
    ProviderServiceDraft draft,
  ) => _service(() => _remote.createService(draft));

  @override
  Future<ProviderResult<ProviderService>> updateService(
    String id,
    ProviderServiceDraft draft,
  ) => _service(() => _remote.updateService(id, draft));

  @override
  Future<ProviderResult<ProviderService>> setPublished(
    String id,
    bool published,
  ) => _service(() => _remote.setPublished(id, published));

  @override
  Future<ProviderResult<void>> deleteService(String id) =>
      _guard(() => _remote.deleteService(id));

  @override
  Future<ProviderResult<void>> setAvailability(bool acceptingRequests) =>
      _guard(() => _remote.setAvailability(acceptingRequests));

  Future<ProviderResult<ProviderService>> _service(
    Future<ProviderServiceModel> Function() operation,
  ) => _guard(() async => (await operation()).toEntity());

  Future<ProviderResult<T>> _guard<T>(Future<T> Function() operation) async {
    try {
      return Success<T, ProviderFailure>(await operation());
    } on ProviderDataException catch (error) {
      return FailureResult<T, ProviderFailure>(
        ProviderFailure(
          _mapFailure(error.code),
          debugMessage: error.debugMessage,
        ),
      );
    } catch (error) {
      return FailureResult<T, ProviderFailure>(
        ProviderFailure(ProviderFailureType.unknown, debugMessage: '$error'),
      );
    }
  }
}

ProviderFailureType _mapFailure(ProviderDataErrorCode code) => switch (code) {
  ProviderDataErrorCode.network => ProviderFailureType.network,
  ProviderDataErrorCode.invalidData => ProviderFailureType.invalidData,
  ProviderDataErrorCode.forbidden => ProviderFailureType.forbidden,
  ProviderDataErrorCode.notFound => ProviderFailureType.notFound,
  ProviderDataErrorCode.unavailable => ProviderFailureType.unavailable,
  ProviderDataErrorCode.invalidResponse => ProviderFailureType.invalidResponse,
};
