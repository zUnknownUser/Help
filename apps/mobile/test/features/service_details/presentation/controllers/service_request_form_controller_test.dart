import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/service_details/domain/entities/service_details.dart';
import 'package:help/features/service_details/domain/entities/service_request.dart';
import 'package:help/features/service_details/domain/failures/service_details_failure.dart';
import 'package:help/features/service_details/domain/repositories/service_details_repository.dart';
import 'package:help/features/service_details/domain/use_cases/create_service_request.dart';
import 'package:help/features/service_details/presentation/controllers/service_request_form_controller.dart';

void main() {
  test('mantém a chave idempotente ao repetir depois de falha', () async {
    final now = DateTime(2026, 8, 16, 12);
    final repository = _RetryRepository();
    final controller = ServiceRequestFormController(
      serviceId: 'service-1',
      create: CreateServiceRequest(repository),
      now: () => now,
      newClientId: () => 'stable-client-id',
    );
    addTearDown(controller.dispose);
    controller.selectSchedule(now.add(const Duration(hours: 2)));

    expect(await controller.submit('Levar material'), isNull);
    expect(controller.error, isNotNull);
    final receipt = await controller.submit('Levar material');

    expect(receipt?.id, 'request-1');
    expect(repository.drafts, hasLength(2));
    expect(repository.drafts.map((draft) => draft.clientRequestId).toSet(), {
      'stable-client-id',
    });
  });

  test('não chama a API para horário com menos de quinze minutos', () async {
    final now = DateTime(2026, 8, 16, 12);
    final repository = _RetryRepository();
    final controller = ServiceRequestFormController(
      serviceId: 'service-1',
      create: CreateServiceRequest(repository),
      now: () => now,
      newClientId: () => 'client-id',
    );
    addTearDown(controller.dispose);
    controller.selectSchedule(now.add(const Duration(minutes: 14)));

    expect(await controller.submit(''), isNull);
    expect(repository.drafts, isEmpty);
    expect(controller.error, contains('15 minutos'));
  });
}

class _RetryRepository implements ServiceDetailsRepository {
  final drafts = <ServiceRequestDraft>[];

  @override
  Future<ServiceDetailsResult<ServiceRequestReceipt>> createRequest(
    String serviceId,
    ServiceRequestDraft draft,
  ) async {
    drafts.add(draft);
    if (drafts.length == 1) {
      return const FailureResult(
        ServiceDetailsFailure(ServiceDetailsFailureType.network),
      );
    }
    return Success(
      ServiceRequestReceipt(
        id: 'request-1',
        clientRequestId: draft.clientRequestId,
        serviceId: serviceId,
        serviceTitle: 'Limpeza',
        providerName: 'Luis',
        status: 'pending',
        scheduledFor: draft.scheduledFor,
        quotedPriceCents: 15000,
        address: 'Rua A, 10',
      ),
    );
  }

  @override
  Future<ServiceDetailsResult<ServiceDetails>> getDetails(String serviceId) =>
      throw UnimplementedError();
}
