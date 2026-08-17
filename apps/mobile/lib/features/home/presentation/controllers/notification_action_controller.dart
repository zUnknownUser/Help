import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/failures/home_failure.dart';
import '../providers/home_providers.dart';

class NotificationActionState {
  const NotificationActionState({
    this.pendingIds = const {},
    this.markingAll = false,
    this.failure,
  });
  final Set<String> pendingIds;
  final bool markingAll;
  final HomeFailure? failure;
}

class NotificationActionController extends Notifier<NotificationActionState> {
  @override
  NotificationActionState build() => const NotificationActionState();

  Future<bool> markOne(String id) async {
    if (state.pendingIds.contains(id)) return true;
    state = NotificationActionState(
      pendingIds: {...state.pendingIds, id},
      markingAll: state.markingAll,
    );
    final result = await ref.read(markNotificationReadProvider)(id);
    return result.fold(
      onSuccess: (_) {
        state = NotificationActionState(
          pendingIds: {...state.pendingIds}..remove(id),
          markingAll: state.markingAll,
        );
        return true;
      },
      onFailure: (failure) {
        state = NotificationActionState(
          pendingIds: {...state.pendingIds}..remove(id),
          failure: failure,
        );
        return false;
      },
    );
  }

  Future<bool> markAll() async {
    if (state.markingAll) return true;
    state = NotificationActionState(
      pendingIds: state.pendingIds,
      markingAll: true,
    );
    final result = await ref.read(markAllNotificationsReadProvider)();
    return result.fold(
      onSuccess: (_) {
        state = const NotificationActionState();
        return true;
      },
      onFailure: (failure) {
        state = NotificationActionState(failure: failure);
        return false;
      },
    );
  }
}
