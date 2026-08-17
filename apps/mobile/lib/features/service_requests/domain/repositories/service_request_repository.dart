import '../../../../core/result/result.dart';
import '../entities/service_request_item.dart';
import '../failures/service_request_failure.dart';

typedef ServiceRequestResult<T> = Result<T, ServiceRequestFailure>;

abstract interface class ServiceRequestRepository {
  Future<ServiceRequestResult<ServiceRequestPageData>> list({
    required RequestViewerRole role,
    String cursor = '',
    int limit = 20,
  });

  Future<ServiceRequestResult<ServiceRequestItem>> get(String id);

  Future<ServiceRequestResult<List<ServiceRequestItem>>> agenda({
    required DateTime from,
    required DateTime to,
  });

  Future<ServiceRequestResult<ServiceRequestItem>> transition({
    required String id,
    required String clientCommandId,
    required ServiceRequestStatus target,
    required int expectedVersion,
    String reason = '',
  });

  Future<ServiceRequestResult<ServiceRequestItem>> reschedule({
    required String id,
    required String clientCommandId,
    required DateTime scheduledFor,
    required int expectedVersion,
  });
}
