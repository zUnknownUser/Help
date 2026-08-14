import '../../domain/entities/provider_service.dart';
import '../models/provider_service_model.dart';
import '../models/provider_workspace_model.dart';

abstract interface class ProviderWorkspaceRemoteDataSource {
  Future<ProviderWorkspaceModel> fetchHome();
  Future<ProviderServiceModel> createService(ProviderServiceDraft draft);
  Future<ProviderServiceModel> updateService(
    String id,
    ProviderServiceDraft draft,
  );
  Future<ProviderServiceModel> setPublished(String id, bool published);
  Future<void> deleteService(String id);
  Future<void> setAvailability(bool acceptingRequests);
}
