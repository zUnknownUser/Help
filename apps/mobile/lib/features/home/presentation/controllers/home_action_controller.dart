import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';
import '../../domain/repositories/home_repository.dart';
import 'home_action_state.dart';
import '../../domain/entities/home_location.dart';

class HomeActionController extends Notifier<HomeActionState> {
  @override
  HomeActionState build() => const HomeActionState();

  Future<bool> saveLocation(HomeLocation location) async {
    if (state.isLoading) return false;
    state = const HomeActionState(isLoading: true);
    final result = await ref.read(saveHomeLocationProvider)(location);
    return _finish(result);
  }

  Future<bool> markNotificationRead(String id) async {
    if (state.isLoading) return false;
    state = const HomeActionState(isLoading: true);
    final result = await ref.read(markNotificationReadProvider)(id);
    return _finish(result);
  }

  bool _finish(HomeOperationResult<void> result) {
    if (!ref.mounted) return false;
    return result.fold(
      onSuccess: (_) {
        state = const HomeActionState();
        return true;
      },
      onFailure: (failure) {
        state = HomeActionState(failure: failure);
        return false;
      },
    );
  }
}
