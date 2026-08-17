import '../entities/service_details.dart';
import '../repositories/service_details_repository.dart';

class GetServiceDetails {
  const GetServiceDetails(this._repository);
  final ServiceDetailsRepository _repository;

  Future<ServiceDetailsResult<ServiceDetails>> call(String serviceId) =>
      _repository.getDetails(serviceId);
}
