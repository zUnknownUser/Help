import '../entities/service_request_item.dart';
import '../entities/service_request_negotiation.dart';
import '../repositories/service_request_repository.dart';

class ServiceRequestActions {
  const ServiceRequestActions(this._repository);
  final ServiceRequestRepository _repository;

  Future<ServiceRequestResult<ServiceRequestPageData>> list({
    required RequestViewerRole role,
    String cursor = '',
  }) => _repository.list(role: role, cursor: cursor);

  Future<ServiceRequestResult<ServiceRequestItem>> get(String id) =>
      _repository.get(id);

  Future<ServiceRequestResult<List<ServiceRequestItem>>> agenda({
    required DateTime from,
    required DateTime to,
  }) => _repository.agenda(from: from, to: to);

  Future<ServiceRequestResult<ServiceRequestItem>> transition({
    required ServiceRequestItem request,
    required String commandId,
    required ServiceRequestStatus target,
    String reason = '',
  }) => _repository.transition(
    id: request.id,
    clientCommandId: commandId,
    target: target,
    expectedVersion: request.version,
    reason: reason,
  );

  Future<ServiceRequestResult<ServiceRequestItem>> reschedule({
    required ServiceRequestItem request,
    required String commandId,
    required DateTime scheduledFor,
  }) => _repository.reschedule(
    id: request.id,
    clientCommandId: commandId,
    scheduledFor: scheduledFor,
    expectedVersion: request.version,
  );

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> negotiation(
    String requestId,
  ) => _repository.negotiation(requestId);

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> proposeQuote({
    required ServiceRequestItem request,
    required String commandId,
    required ServiceQuoteDraft draft,
  }) => _repository.proposeQuote(
    request: request,
    clientCommandId: commandId,
    draft: draft,
  );

  Future<ServiceRequestResult<ServiceRequestNegotiationUpdate>> acceptQuote({
    required ServiceRequestItem request,
    required String quoteId,
    required String commandId,
  }) => _repository.acceptQuote(
    request: request,
    quoteId: quoteId,
    clientCommandId: commandId,
  );

  Future<ServiceRequestResult<ServiceRequestAttachment>> uploadAttachment({
    required String requestId,
    required String filePath,
    String caption = '',
  }) => _repository.uploadAttachment(
    requestId: requestId,
    filePath: filePath,
    caption: caption,
  );

  Future<ServiceRequestResult<bool>> deleteAttachment({
    required String requestId,
    required String attachmentId,
  }) => _repository.deleteAttachment(
    requestId: requestId,
    attachmentId: attachmentId,
  );
}
