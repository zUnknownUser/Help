import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/service_details/data/data_sources/service_details_remote_data_source.dart';
import 'package:help/features/service_details/data/errors/service_details_data_exception.dart';
import 'package:help/features/service_details/data/models/service_details_model.dart';
import 'package:help/features/service_details/data/models/service_request_model.dart';
import 'package:help/features/service_details/data/repositories/service_details_repository_impl.dart';
import 'package:help/features/service_details/domain/entities/service_request.dart';
import 'package:help/features/service_details/domain/failures/service_details_failure.dart';

void main() {
  test(
    'mapeia endereço obrigatório sem vazar erro de infraestrutura',
    () async {
      const repository = ServiceDetailsRepositoryImpl(_AddressFailureRemote());

      final result = await repository.createRequest(
        'service-1',
        ServiceRequestDraft(
          clientRequestId: 'client-id',
          scheduledFor: DateTime(2026),
          note: '',
        ),
      );

      expect(
        result,
        isA<FailureResult<ServiceRequestReceipt, ServiceDetailsFailure>>(),
      );
      expect(
        (result as FailureResult<ServiceRequestReceipt, ServiceDetailsFailure>)
            .failure
            .type,
        ServiceDetailsFailureType.addressRequired,
      );
    },
  );
}

class _AddressFailureRemote implements ServiceDetailsRemoteDataSource {
  const _AddressFailureRemote();

  @override
  Future<ServiceDetailsModel> fetch(String serviceId) =>
      throw UnimplementedError();

  @override
  Future<ServiceRequestModel> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  ) {
    throw const ServiceDetailsDataException(
      422,
      message: 'Defina um endereço.',
    );
  }
}
