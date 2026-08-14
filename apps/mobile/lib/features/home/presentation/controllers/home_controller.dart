import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_content.dart';
import '../../domain/failures/home_failure.dart';
import '../providers/home_providers.dart';

class HomeController extends AsyncNotifier<HomeContent> {
  @override
  Future<HomeContent> build() => _load();

  Future<void> retry() async {
    state = const AsyncLoading<HomeContent>();
    final nextState = await AsyncValue.guard(_load);
    if (ref.mounted) state = nextState;
  }

  Future<HomeContent> _load() async {
    final result = await ref.read(getHomeProvider)();
    return result.fold(
      onSuccess: (content) => content,
      onFailure: (failure) => throw HomePresentationException(failure),
    );
  }
}

class HomePresentationException implements Exception {
  const HomePresentationException(this.failure);

  final HomeFailure failure;
}
