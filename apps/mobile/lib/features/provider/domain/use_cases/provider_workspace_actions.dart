import '../entities/provider_service.dart';
import '../repositories/provider_workspace_repository.dart';

class ProviderWorkspaceActions {
  const ProviderWorkspaceActions(this._repository);

  final ProviderWorkspaceRepository _repository;

  Future<ProviderResult<ProviderService>> create(ProviderServiceDraft draft) =>
      _repository.createService(draft);

  Future<ProviderResult<ProviderService>> update(
    String id,
    ProviderServiceDraft draft,
  ) => _repository.updateService(id, draft);

  Future<ProviderResult<ProviderService>> setPublished(
    String id,
    bool published,
  ) => _repository.setPublished(id, published);

  Future<ProviderResult<void>> delete(String id) =>
      _repository.deleteService(id);

  Future<ProviderResult<void>> setAvailability(bool accepting) =>
      _repository.setAvailability(accepting);
}
