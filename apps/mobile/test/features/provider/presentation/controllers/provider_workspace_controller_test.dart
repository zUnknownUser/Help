import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/provider/domain/entities/provider_service.dart';
import 'package:help/features/provider/domain/entities/provider_workspace.dart';
import 'package:help/features/provider/domain/failures/provider_failure.dart';
import 'package:help/features/provider/domain/repositories/provider_workspace_repository.dart';
import 'package:help/features/provider/domain/use_cases/get_provider_home.dart';
import 'package:help/features/provider/domain/use_cases/provider_workspace_actions.dart';
import 'package:help/features/provider/presentation/providers/provider_workspace_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetProviderHome extends Mock implements GetProviderHome {}

class _MockProviderActions extends Mock implements ProviderWorkspaceActions {}

void main() {
  test(
    'faz publicação otimista e restaura estado quando a API falha',
    () async {
      final getHome = _MockGetProviderHome();
      final actions = _MockProviderActions();
      final completion = Completer<ProviderResult<ProviderService>>();
      when(getHome.call).thenAnswer(
        (_) async => Success<ProviderWorkspace, ProviderFailure>(_workspace),
      );
      when(
        () => actions.setPublished('service-1', false),
      ).thenAnswer((_) => completion.future);
      final container = ProviderContainer(
        overrides: [
          getProviderHomeProvider.overrideWithValue(getHome),
          providerWorkspaceActionsProvider.overrideWithValue(actions),
        ],
      );
      final subscription = container.listen(
        providerWorkspaceControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);
      await container.read(providerWorkspaceControllerProvider.future);

      final operation = container
          .read(providerWorkspaceControllerProvider.notifier)
          .setPublished(_service, false);
      expect(
        container
            .read(providerWorkspaceControllerProvider)
            .requireValue
            .services
            .single
            .published,
        isFalse,
      );

      completion.complete(
        const FailureResult<ProviderService, ProviderFailure>(
          ProviderFailure(ProviderFailureType.network),
        ),
      );
      final failure = await operation;

      expect(failure?.type, ProviderFailureType.network);
      expect(
        container
            .read(providerWorkspaceControllerProvider)
            .requireValue
            .services
            .single
            .published,
        isTrue,
      );
    },
  );
}

final _service = ProviderService(
  id: 'service-1',
  categoryId: '',
  title: 'Limpeza residencial',
  description: 'Limpeza completa do imóvel.',
  durationMinutes: 120,
  priceCents: 15000,
  imageUrl: '',
  rating: 0,
  reviews: 0,
  published: true,
  updatedAt: DateTime.utc(2026, 8, 14),
);

final _workspace = ProviderWorkspace(
  provider: const ProviderAccount(
    id: 'provider-1',
    displayName: 'Luis',
    status: 'approved',
    active: true,
    acceptingRequests: true,
  ),
  location: const ProviderLocation(),
  summary: const ProviderSummary(
    totalServices: 1,
    publishedServices: 1,
    pausedServices: 0,
    pendingRequests: 0,
    unreadMessages: 0,
    unreadNotifications: 0,
  ),
  alerts: const [],
  categories: const [],
  services: [_service],
  recentRequests: const [],
  notifications: const [],
);
