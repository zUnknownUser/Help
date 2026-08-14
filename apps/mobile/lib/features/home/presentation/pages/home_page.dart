import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/failures/home_failure.dart';
import '../controllers/home_controller.dart';
import '../providers/home_providers.dart';
import '../widgets/home_content_view.dart';
import '../widgets/home_error_view.dart';
import '../widgets/home_loading_view.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    return state.when(
      data: (content) => HomeContentView(content: content),
      loading: () => const HomeLoadingView(),
      error: (error, _) => HomeErrorView(
        failure: error is HomePresentationException
            ? error.failure
            : const HomeFailure(HomeFailureType.unknown),
        onRetry: ref.read(homeControllerProvider.notifier).retry,
      ),
    );
  }
}
