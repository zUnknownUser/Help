import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/provider_service.dart';
import '../../domain/entities/provider_workspace.dart';
import '../../domain/failures/provider_failure.dart';
import '../providers/provider_workspace_providers.dart';

class ProviderWorkspaceController extends AsyncNotifier<ProviderWorkspace> {
  @override
  Future<ProviderWorkspace> build() => _load();

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<ProviderFailure?> saveService({
    String? id,
    required ProviderServiceDraft draft,
  }) async {
    final actions = ref.read(providerWorkspaceActionsProvider);
    final result = id == null
        ? await actions.create(draft)
        : await actions.update(id, draft);
    return result.fold(
      onSuccess: (service) {
        _upsertService(service);
        unawaited(_synchronize());
        return null;
      },
      onFailure: (failure) => failure,
    );
  }

  Future<ProviderFailure?> setPublished(
    ProviderService service,
    bool published,
  ) async {
    final previous = state.value;
    _upsertService(service.copyWith(published: published));
    final result = await ref
        .read(providerWorkspaceActionsProvider)
        .setPublished(service.id, published);
    return result.fold(
      onSuccess: (confirmed) {
        _upsertService(confirmed);
        unawaited(_synchronize());
        return null;
      },
      onFailure: (failure) {
        if (previous != null) state = AsyncData(previous);
        return failure;
      },
    );
  }

  Future<ProviderFailure?> deleteService(ProviderService service) async {
    final previous = state.value;
    _removeService(service.id);
    final result = await ref
        .read(providerWorkspaceActionsProvider)
        .delete(service.id);
    return result.fold(
      onSuccess: (_) {
        unawaited(_synchronize());
        return null;
      },
      onFailure: (failure) {
        if (previous != null) state = AsyncData(previous);
        return failure;
      },
    );
  }

  Future<ProviderFailure?> setAvailability(bool accepting) async {
    final previous = state.value;
    if (previous == null) {
      return const ProviderFailure(ProviderFailureType.unknown);
    }
    state = AsyncData(
      previous.copyWith(
        provider: previous.provider.copyWith(acceptingRequests: accepting),
      ),
    );
    final result = await ref
        .read(providerWorkspaceActionsProvider)
        .setAvailability(accepting);
    return result.fold(
      onSuccess: (_) {
        unawaited(_synchronize());
        return null;
      },
      onFailure: (failure) {
        state = AsyncData(previous);
        return failure;
      },
    );
  }

  Future<ProviderWorkspace> _load() async {
    final result = await ref.read(getProviderHomeProvider)();
    return result.fold(
      onSuccess: (workspace) => workspace,
      onFailure: (failure) => throw ProviderPresentationException(failure),
    );
  }

  Future<void> _synchronize() async {
    final result = await ref.read(getProviderHomeProvider)();
    if (!ref.mounted) return;
    if (result case Success<ProviderWorkspace, ProviderFailure>(:final value)) {
      state = AsyncData(value);
    }
  }

  void _upsertService(ProviderService service) {
    final workspace = state.value;
    if (workspace == null) return;
    final services = [...workspace.services];
    final index = services.indexWhere((item) => item.id == service.id);
    if (index < 0) {
      services.insert(0, service);
    } else {
      services[index] = service;
    }
    _setServices(workspace, services);
  }

  void _removeService(String id) {
    final workspace = state.value;
    if (workspace == null) return;
    _setServices(
      workspace,
      workspace.services.where((service) => service.id != id).toList(),
    );
  }

  void _setServices(
    ProviderWorkspace workspace,
    List<ProviderService> services,
  ) {
    final published = services.where((service) => service.published).length;
    state = AsyncData(
      workspace.copyWith(
        services: List.unmodifiable(services),
        summary: workspace.summary.copyWith(
          totalServices: services.length,
          publishedServices: published,
          pausedServices: services.length - published,
        ),
      ),
    );
  }
}

class ProviderPresentationException implements Exception {
  const ProviderPresentationException(this.failure);
  final ProviderFailure failure;
}
