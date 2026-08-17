import 'dart:async';

import '../../../../core/result/result.dart';
import '../../domain/entities/service_details.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/failures/service_details_failure.dart';
import '../../domain/repositories/service_details_repository.dart';
import '../data_sources/http_service_details_remote_data_source.dart';
import '../data_sources/service_details_remote_data_source.dart';
import '../errors/service_details_data_exception.dart';

class ServiceDetailsRepositoryImpl implements ServiceDetailsRepository {
  const ServiceDetailsRepositoryImpl(this._remote);
  final ServiceDetailsRemoteDataSource _remote;

  @override
  Future<ServiceDetailsResult<ServiceDetails>> getDetails(String serviceId) =>
      _guard(() async => (await _remote.fetch(serviceId)).entity);

  @override
  Future<ServiceDetailsResult<ServiceRequestReceipt>> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  ) => _guard(
    () async => (await _remote.createRequest(serviceId, draft)).entity,
  );

  Future<ServiceDetailsResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T, ServiceDetailsFailure>(await action());
    } on ServiceDetailsDataException catch (error) {
      return FailureResult<T, ServiceDetailsFailure>(
        ServiceDetailsFailure(
          _failureType(error.statusCode),
          message: error.message,
        ),
      );
    } on TimeoutException catch (error) {
      return FailureResult<T, ServiceDetailsFailure>(
        ServiceDetailsFailure(
          ServiceDetailsFailureType.network,
          message: error.toString(),
        ),
      );
    } catch (error) {
      return FailureResult<T, ServiceDetailsFailure>(
        ServiceDetailsFailure(
          isServiceDetailsNetworkError(error)
              ? ServiceDetailsFailureType.network
              : ServiceDetailsFailureType.unknown,
          message: error.toString(),
        ),
      );
    }
  }

  ServiceDetailsFailureType _failureType(int status) => switch (status) {
    400 => ServiceDetailsFailureType.invalid,
    403 => ServiceDetailsFailureType.forbidden,
    404 => ServiceDetailsFailureType.notFound,
    409 => ServiceDetailsFailureType.conflict,
    422 => ServiceDetailsFailureType.addressRequired,
    503 => ServiceDetailsFailureType.unavailable,
    _ => ServiceDetailsFailureType.unknown,
  };
}
