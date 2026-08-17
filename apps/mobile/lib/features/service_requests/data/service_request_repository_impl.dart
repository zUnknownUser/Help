import '../../../../core/result/result.dart';
import '../domain/entities/service_request_item.dart';
import '../domain/failures/service_request_failure.dart';
import '../domain/repositories/service_request_repository.dart';
import 'service_request_remote_api.dart';

class ServiceRequestRepositoryImpl implements ServiceRequestRepository {
  const ServiceRequestRepositoryImpl(this._api);
  final ServiceRequestRemoteApi _api;

  @override
  Future<ServiceRequestResult<ServiceRequestPageData>> list({
    required RequestViewerRole role,
    String cursor = '',
    int limit = 20,
  }) => _guard(() => _api.list(role: role, cursor: cursor, limit: limit));

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> get(String id) =>
      _guard(() => _api.get(id));

  @override
  Future<ServiceRequestResult<List<ServiceRequestItem>>> agenda({
    required DateTime from,
    required DateTime to,
  }) => _guard(() => _api.agenda(from: from, to: to));

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> transition({
    required String id,
    required String clientCommandId,
    required ServiceRequestStatus target,
    required int expectedVersion,
    String reason = '',
  }) => _guard(
    () => _api.transition(
      id: id,
      clientCommandId: clientCommandId,
      target: target,
      expectedVersion: expectedVersion,
      reason: reason,
    ),
  );

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> reschedule({
    required String id,
    required String clientCommandId,
    required DateTime scheduledFor,
    required int expectedVersion,
  }) => _guard(
    () => _api.reschedule(
      id: id,
      clientCommandId: clientCommandId,
      scheduledFor: scheduledFor,
      expectedVersion: expectedVersion,
    ),
  );

  Future<ServiceRequestResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on ServiceRequestApiException catch (error) {
      return FailureResult(
        ServiceRequestFailure(_type(error.statusCode), message: error.message),
      );
    } catch (error) {
      return FailureResult(
        ServiceRequestFailure(
          isServiceRequestNetworkError(error)
              ? ServiceRequestFailureType.network
              : ServiceRequestFailureType.invalidResponse,
          message: '$error',
        ),
      );
    }
  }

  ServiceRequestFailureType _type(int status) => switch (status) {
    403 => ServiceRequestFailureType.forbidden,
    404 => ServiceRequestFailureType.notFound,
    409 => ServiceRequestFailureType.conflict,
    503 => ServiceRequestFailureType.unavailable,
    _ => ServiceRequestFailureType.invalidResponse,
  };
}
