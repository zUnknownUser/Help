import '../../../../core/result/result.dart';
import '../entities/service_details.dart';
import '../entities/service_request.dart';
import '../failures/service_details_failure.dart';

typedef ServiceDetailsResult<T> = Result<T, ServiceDetailsFailure>;

abstract interface class ServiceDetailsRepository {
  Future<ServiceDetailsResult<ServiceDetails>> getDetails(String serviceId);

  Future<ServiceDetailsResult<ServiceRequestReceipt>> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  );
}
