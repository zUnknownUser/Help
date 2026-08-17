import '../entities/service_request_item.dart';
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
}
