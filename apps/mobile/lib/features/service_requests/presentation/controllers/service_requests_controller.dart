import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/domain/entities/user_role.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/service_request_item.dart';
import '../providers/service_request_providers.dart';
import 'service_requests_state.dart';

class ServiceRequestsController extends Notifier<ServiceRequestsState> {
  @override
  ServiceRequestsState build() {
    final activeRole = ref.watch(currentProfileProvider).value?.activeRole;
    final role = activeRole == UserRole.provider
        ? RequestViewerRole.provider
        : RequestViewerRole.customer;
    Future.microtask(refresh);
    return ServiceRequestsState(role: role);
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearFailure: true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .list(role: state.role);
    if (!ref.mounted) return;
    result.fold(
      onSuccess: (page) => state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        loading: false,
        clearFailure: true,
      ),
      onFailure: (failure) =>
          state = state.copyWith(loading: false, failure: failure),
    );
  }

  Future<void> loadMore() async {
    if (!ref.mounted || !state.canLoadMore) return;
    state = state.copyWith(loadingMore: true, clearFailure: true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .list(role: state.role, cursor: state.nextCursor);
    if (!ref.mounted) return;
    result.fold(
      onSuccess: (page) {
        final ids = state.items.map((item) => item.id).toSet();
        state = state.copyWith(
          items: [
            ...state.items,
            ...page.items.where((item) => ids.add(item.id)),
          ],
          nextCursor: page.nextCursor,
          loadingMore: false,
          clearFailure: true,
        );
      },
      onFailure: (failure) =>
          state = state.copyWith(loadingMore: false, failure: failure),
    );
  }

  void reconcile(ServiceRequestItem request) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.id == request.id);
    if (index < 0) {
      items.insert(0, request);
    } else {
      items[index] = request;
    }
    state = state.copyWith(items: List.unmodifiable(items));
  }
}
