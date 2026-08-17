import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../home/domain/entities/home_location.dart';
import '../../../home/domain/entities/service_category.dart';
import '../../data/help_now_providers.dart';
import '../../domain/entities/help_now_request.dart';

class CustomerHelpNowController extends AsyncNotifier<HelpNowRequest?> {
  Timer? _poll;
  bool _syncing = false;
  String? _pendingClientId;

  @override
  Future<HelpNowRequest?> build() async {
    ref.onDispose(() => _poll?.cancel());
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(synchronize()),
    );
    return ref.read(helpNowRepositoryProvider).active();
  }

  Future<HelpNowRequest> create({
    required ServiceCategory category,
    required HomeLocation location,
    required String note,
  }) async {
    if (!location.hasCoordinates) {
      throw const HelpNowPresentationException(
        'Confirme sua localização antes de continuar.',
      );
    }
    _pendingClientId ??= const Uuid().v4();
    final request = await ref
        .read(helpNowRepositoryProvider)
        .create(
          clientId: _pendingClientId!,
          category: category,
          location: location,
          note: note,
        );
    _pendingClientId = null;
    if (ref.mounted) state = AsyncData(request);
    return request;
  }

  Future<void> cancel() async {
    final current = state.value;
    if (current == null || current.status != HelpNowStatus.searching) return;
    final cancelled = await ref
        .read(helpNowRepositoryProvider)
        .cancel(current.id);
    if (ref.mounted) state = AsyncData(cancelled);
  }

  Future<void> synchronize() async {
    if (_syncing || !ref.mounted) return;
    _syncing = true;
    try {
      final request = await ref.read(helpNowRepositoryProvider).active();
      if (ref.mounted) state = AsyncData(request);
    } catch (_) {
      // Preserve the last usable state during transient connectivity failures.
    } finally {
      _syncing = false;
    }
  }
}

class HelpNowPresentationException implements Exception {
  const HelpNowPresentationException(this.message);
  final String message;
}
