import '../../../../core/result/result.dart';
import '../entities/service_request_item.dart';
import '../entities/service_request_negotiation.dart';
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

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> negotiation(
    String requestId,
  );

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> proposeQuote({
    required ServiceRequestItem request,
    required String clientCommandId,
    required ServiceQuoteDraft draft,
  });

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> acceptQuote({
    required ServiceRequestItem request,
    required String quoteId,
    required String clientCommandId,
  });

  Future<ServiceRequestResult<ServiceRequestAttachment>> uploadAttachment({
    required String requestId,
    required String filePath,
    String caption = '',
  });

  Future<ServiceRequestResult<bool>> deleteAttachment({
    required String requestId,
    required String attachmentId,
  });
}
