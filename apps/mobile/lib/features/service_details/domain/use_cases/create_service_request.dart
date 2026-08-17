import '../entities/service_request.dart';
import '../repositories/service_details_repository.dart';

class CreateServiceRequest {
  const CreateServiceRequest(this._repository);
  final ServiceDetailsRepository _repository;

  Future<ServiceDetailsResult<ServiceRequestReceipt>> call(
    String serviceId,
    ServiceRequestDraft draft,
  ) => _repository.createRequest(serviceId, draft);
}
