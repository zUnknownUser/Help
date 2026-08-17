import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/profile/domain/entities/user_profile.dart';
import 'package:help/features/profile/domain/entities/user_role.dart';
import 'package:help/features/profile/presentation/controllers/profile_controller.dart';
import 'package:help/features/profile/presentation/providers/profile_providers.dart';
import 'package:help/features/service_requests/domain/entities/service_request_item.dart';
import 'package:help/features/service_requests/domain/repositories/service_request_repository.dart';
import 'package:help/features/service_requests/domain/use_cases/service_request_actions.dart';
import 'package:help/features/service_requests/presentation/pages/service_request_details_page.dart';
import 'package:help/features/service_requests/presentation/providers/service_request_providers.dart';

void main() {
  testWidgets('provider accepts request and reconciles server result', (
    tester,
  ) async {
    final repository = _RequestRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceRequestActionsProvider.overrideWithValue(
            ServiceRequestActions(repository),
          ),
          currentProfileProvider.overrideWith(_ProfileControllerStub.new),
        ],
        child: MaterialApp(
          home: ServiceRequestDetailsPage(
            requestId: 'request-1',
            initial: _request(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.target, ServiceRequestStatus.accepted);
    expect(repository.expectedVersion, 0);
    expect(find.text('Aceito'), findsOneWidget);
  });
}

class _ProfileControllerStub extends ProfileController {
  @override
  Future<UserProfile> build() async => const UserProfile(
    email: 'provider@example.com',
    displayName: 'Luis',
    activeRole: UserRole.provider,
    roles: [UserRole.provider],
  );
}

class _RequestRepositoryFake implements ServiceRequestRepository {
  ServiceRequestStatus? target;
  int? expectedVersion;

  @override
  Future<ServiceRequestResult<List<ServiceRequestItem>>> agenda({
    required DateTime from,
    required DateTime to,
  }) async => Success([_request()]);

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> reschedule({
    required String id,
    required String clientCommandId,
    required DateTime scheduledFor,
    required int expectedVersion,
  }) async => Success(
    _request().copyWith(
      scheduledFor: scheduledFor,
      status: ServiceRequestStatus.pending,
      version: expectedVersion + 1,
    ),
  );

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> transition({
    required String id,
    required String clientCommandId,
    required ServiceRequestStatus target,
    required int expectedVersion,
    String reason = '',
  }) async {
    this.target = target;
    this.expectedVersion = expectedVersion;
    return Success(
      _request().copyWith(
        status: target,
        version: 1,
        availableActions: {ServiceRequestStatus.inProgress},
      ),
    );
  }

  @override
  Future<ServiceRequestResult<ServiceRequestItem>> get(String id) async =>
      Success(_request());

  @override
  Future<ServiceRequestResult<ServiceRequestPageData>> list({
    required RequestViewerRole role,
    String cursor = '',
    int limit = 20,
  }) async =>
      Success(ServiceRequestPageData(items: [_request()], nextCursor: ''));
}

ServiceRequestItem _request() => ServiceRequestItem(
  id: 'request-1',
  clientRequestId: 'client-1',
  serviceId: 'service-1',
  serviceTitle: 'Limpeza',
  providerUserId: 'provider-user',
  providerName: 'Luis',
  customerName: 'Ana',
  customerUserId: 'customer-user',
  viewerRole: RequestViewerRole.provider,
  status: ServiceRequestStatus.pending,
  statusReason: '',
  version: 0,
  availableActions: const {
    ServiceRequestStatus.accepted,
    ServiceRequestStatus.rejected,
  },
  note: '',
  scheduledFor: DateTime.utc(2026, 8, 17, 15),
  quotedPriceCents: 15000,
  addressLabel: 'Casa',
  address: 'Rua A, 10',
  createdAt: DateTime.utc(2026, 8, 16, 12),
  updatedAt: DateTime.utc(2026, 8, 16, 12),
);
