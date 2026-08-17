import '../../domain/entities/service_request.dart';
import '../models/service_details_model.dart';
import '../models/service_request_model.dart';

abstract interface class ServiceDetailsRemoteDataSource {
  Future<ServiceDetailsModel> fetch(String serviceId);

  Future<ServiceRequestModel> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  );
}
