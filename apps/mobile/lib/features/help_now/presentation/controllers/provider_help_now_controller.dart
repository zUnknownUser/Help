import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/help_now_providers.dart';
import '../../domain/entities/help_now_availability.dart';
import '../../domain/entities/help_now_offer.dart';
import '../../domain/entities/help_now_request.dart';

class ProviderHelpNowController extends AsyncNotifier<ProviderHelpNowState> {
  Timer? _poll;
  Timer? _heartbeat;
  bool _syncing = false;
  final _commandIds = <String, String>{};

  @override
  Future<ProviderHelpNowState> build() async {
    ref.onDispose(_disposeTimers);
    final repository = ref.read(helpNowRepositoryProvider);
    final availability = await repository.availability();
    final offers = availability.enabled
        ? await repository.offers()
        : const <HelpNowOffer>[];
    _configureTimers(availability);
    return ProviderHelpNowState(availability: availability, offers: offers);
  }

  Future<void> setAvailability({
    required bool enabled,
    required double latitude,
    required double longitude,
  }) async {
    final previous = state.value;
    if (previous == null) return;
    final optimistic = HelpNowAvailability(
      enabled: enabled,
      latitude: latitude,
      longitude: longitude,
      maxDistanceKm: previous.availability.maxDistanceKm,
      expiresAt: previous.availability.expiresAt,
    );
    state = AsyncData(
      previous.copyWith(
        availability: optimistic,
        offers: enabled ? previous.offers : const [],
      ),
    );
    try {
      final confirmed = await ref
          .read(helpNowRepositoryProvider)
          .setAvailability(
            enabled: enabled,
            latitude: latitude,
            longitude: longitude,
            maxDistanceKm: optimistic.maxDistanceKm,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        previous.copyWith(
          availability: confirmed,
          offers: enabled ? previous.offers : const [],
        ),
      );
      _configureTimers(confirmed);
      if (enabled) await synchronize();
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<HelpNowRequest> respond(HelpNowOffer offer, bool accept) async {
    final previous = state.value;
    if (previous == null) throw StateError('Help Agora indisponível');
    state = AsyncData(
      previous.copyWith(
        offers: previous.offers
            .where((item) => item.id != offer.id)
            .toList(growable: false),
      ),
    );
    try {
      final request = await ref
          .read(helpNowRepositoryProvider)
          .respond(
            offerId: offer.id,
            clientCommandId: _commandIds.putIfAbsent(
              offer.id,
              () => const Uuid().v4(),
            ),
            accept: accept,
          );
      if (accept && ref.mounted) {
        state = AsyncData(previous.copyWith(offers: const []));
      }
      _commandIds.remove(offer.id);
      return request;
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> synchronize() async {
    final current = state.value;
    if (_syncing || current == null || !current.availability.enabled) return;
    _syncing = true;
    try {
      final offers = await ref.read(helpNowRepositoryProvider).offers();
      final latest = state.value;
      if (ref.mounted && latest != null) {
        state = AsyncData(latest.copyWith(offers: offers));
      }
    } catch (_) {
      // FCM and the next poll provide recovery without hiding current offers.
    } finally {
      _syncing = false;
    }
  }

  void _configureTimers(HelpNowAvailability availability) {
    _disposeTimers();
    if (!availability.enabled) return;
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(synchronize()),
    );
    _heartbeat = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_sendHeartbeat()),
    );
  }

  Future<void> _sendHeartbeat() async {
    final current = state.value?.availability;
    if (current == null || !current.enabled) return;
    try {
      final confirmed = await ref
          .read(helpNowRepositoryProvider)
          .setAvailability(
            enabled: true,
            latitude: current.latitude,
            longitude: current.longitude,
            maxDistanceKm: current.maxDistanceKm,
          );
      final latest = state.value;
      if (ref.mounted && latest != null) {
        state = AsyncData(latest.copyWith(availability: confirmed));
      }
    } catch (_) {}
  }

  void _disposeTimers() {
    _poll?.cancel();
    _heartbeat?.cancel();
    _poll = null;
    _heartbeat = null;
  }
}
