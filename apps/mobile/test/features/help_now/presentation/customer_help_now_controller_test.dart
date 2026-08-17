import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/help_now/data/help_now_providers.dart';
import 'package:help/features/help_now/domain/entities/help_now_availability.dart';
import 'package:help/features/help_now/domain/entities/help_now_offer.dart';
import 'package:help/features/help_now/domain/entities/help_now_request.dart';
import 'package:help/features/help_now/domain/repositories/help_now_repository.dart';
import 'package:help/features/help_now/presentation/providers/help_now_providers.dart';
import 'package:help/features/home/domain/entities/home_location.dart';
import 'package:help/features/home/domain/entities/service_category.dart';

void main() {
  test(
    'publishes the optimistic flow source after create and cancel',
    () async {
      final repository = _FakeHelpNowRepository();
      final container = ProviderContainer(
        overrides: [helpNowRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(customerHelpNowControllerProvider.future);

      final created = await container
          .read(customerHelpNowControllerProvider.notifier)
          .create(
            category: const ServiceCategory(
              id: 'plumbing',
              name: 'Encanamento',
              iconKey: 'plumbing',
            ),
            location: const HomeLocation(
              address: 'Rua A, 10',
              availabilityLabel: 'Casa',
              latitude: -3.1,
              longitude: -60,
            ),
            note: 'Vazamento',
          );

      expect(created.status, HelpNowStatus.searching);
      expect(
        container.read(customerHelpNowControllerProvider).value?.id,
        'request-1',
      );

      await container.read(customerHelpNowControllerProvider.notifier).cancel();
      expect(
        container.read(customerHelpNowControllerProvider).value?.status,
        HelpNowStatus.cancelled,
      );
    },
  );

  test('does not send a request without coordinates', () async {
    final repository = _FakeHelpNowRepository();
    final container = ProviderContainer(
      overrides: [helpNowRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(customerHelpNowControllerProvider.future);

    await expectLater(
      container
          .read(customerHelpNowControllerProvider.notifier)
          .create(
            category: const ServiceCategory(id: 'a', name: 'A', iconKey: 'a'),
            location: const HomeLocation(
              address: 'Rua A',
              availabilityLabel: 'Casa',
            ),
            note: '',
          ),
      throwsA(isA<Exception>()),
    );
    expect(repository.createCalls, 0);
  });
}

class _FakeHelpNowRepository implements HelpNowRepository {
  HelpNowRequest? current;
  int createCalls = 0;

  @override
  Future<HelpNowRequest?> active() async => current;

  @override
  Future<HelpNowRequest> create({
    required String clientId,
    required ServiceCategory category,
    required HomeLocation location,
    required String note,
  }) async {
    createCalls++;
    return current = _request(clientId: clientId);
  }

  @override
  Future<HelpNowRequest> cancel(String requestId) async => current = _request(
    clientId: current!.clientId,
    status: HelpNowStatus.cancelled,
  );

  @override
  Future<HelpNowAvailability> availability() async =>
      const HelpNowAvailability.disabled();

  @override
  Future<List<HelpNowOffer>> offers() async => const [];

  @override
  Future<HelpNowRequest> respond({
    required String offerId,
    required String clientCommandId,
    required bool accept,
  }) async => _request(clientId: clientCommandId);

  @override
  Future<HelpNowAvailability> setAvailability({
    required bool enabled,
    required double latitude,
    required double longitude,
    required int maxDistanceKm,
  }) async => HelpNowAvailability(
    enabled: enabled,
    latitude: latitude,
    longitude: longitude,
    maxDistanceKm: maxDistanceKm,
    expiresAt: null,
  );
}

HelpNowRequest _request({
  required String clientId,
  HelpNowStatus status = HelpNowStatus.searching,
}) => HelpNowRequest(
  id: 'request-1',
  clientId: clientId,
  categoryId: 'plumbing',
  categoryName: 'Encanamento',
  note: 'Vazamento',
  address: 'Rua A, 10',
  status: status,
  wave: 0,
  assignedProviderName: '',
  serviceRequestId: '',
  createdAt: DateTime(2026),
  searchExpiresAt: DateTime(2026, 1, 1, 0, 3),
);
