import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_content.dart';
import '../../domain/failures/home_failure.dart';
import '../providers/home_providers.dart';
import '../../data/providers/home_data_providers.dart';

class HomeController extends AsyncNotifier<HomeContent> {
  bool _locationBootstrapStarted = false;

  @override
  Future<HomeContent> build() => _load();

  Future<void> retry() async {
    state = const AsyncLoading<HomeContent>();
    final nextState = await AsyncValue.guard(_load);
    if (ref.mounted) state = nextState;
  }

  Future<HomeContent> _load() async {
    final result = await ref.read(getHomeProvider)();
    final content = result.fold(
      onSuccess: (content) => content,
      onFailure: (failure) => throw HomePresentationException(failure),
    );
    if (!content.location.hasCoordinates && !_locationBootstrapStarted) {
      _locationBootstrapStarted = true;
      unawaited(_resolveLocationInBackground(content));
    }
    return content;
  }

  Future<void> _resolveLocationInBackground(HomeContent fallback) async {
    try {
      final location = await ref.read(locationResolverProvider).current();
      final saved = await ref.read(saveHomeLocationProvider)(location);
      final didSave = saved.fold(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );
      if (!didSave || !ref.mounted) return;
      final refreshed = await ref.read(getHomeProvider)();
      final content = refreshed.fold(
        onSuccess: (value) => value,
        onFailure: (_) => fallback,
      );
      if (ref.mounted) state = AsyncData(content);
    } catch (_) {}
  }
}

class HomePresentationException implements Exception {
  const HomePresentationException(this.failure);

  final HomeFailure failure;
}
