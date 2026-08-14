import '../entities/provider_workspace.dart';
import '../repositories/provider_workspace_repository.dart';

class GetProviderHome {
  const GetProviderHome(this._repository);

  final ProviderWorkspaceRepository _repository;

  Future<ProviderResult<ProviderWorkspace>> call() => _repository.getHome();
}
