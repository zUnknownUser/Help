import '../../../../core/result/result.dart';
import '../entities/provider_service.dart';
import '../entities/provider_workspace.dart';
import '../failures/provider_failure.dart';

typedef ProviderResult<T> = Result<T, ProviderFailure>;

abstract interface class ProviderWorkspaceRepository {
  Future<ProviderResult<ProviderWorkspace>> getHome();
  Future<ProviderResult<ProviderService>> createService(
    ProviderServiceDraft draft,
  );
  Future<ProviderResult<ProviderService>> updateService(
    String id,
    ProviderServiceDraft draft,
  );
  Future<ProviderResult<ProviderService>> setPublished(
    String id,
    bool published,
  );
  Future<ProviderResult<void>> deleteService(String id);
  Future<ProviderResult<void>> setAvailability(bool acceptingRequests);
}
