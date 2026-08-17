import 'package:flutter/foundation.dart';

import '../../domain/entities/provider_schedule.dart';
import '../../domain/failures/scheduling_failure.dart';
import '../../domain/repositories/scheduling_repository.dart';

class ProviderScheduleController extends ChangeNotifier {
  ProviderScheduleController(this._repository);
  final SchedulingRepository _repository;
  ProviderSchedule? _schedule;
  SchedulingFailure? _failure;
  bool _loading = false;
  bool _saving = false;
  bool _disposed = false;

  ProviderSchedule? get schedule => _schedule;
  SchedulingFailure? get failure => _failure;
  bool get loading => _loading;
  bool get saving => _saving;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _failure = null;
    _notify();
    final result = await _repository.getProviderSchedule();
    result.fold(
      onSuccess: (value) => _schedule = value,
      onFailure: (value) => _failure = value,
    );
    _loading = false;
    _notify();
  }

  void setRulesForDay(int weekday, List<AvailabilityRule> dayRules) {
    final current = _schedule;
    if (current == null) return;
    final rules =
        current.rules.where((rule) => rule.weekday != weekday).toList()
          ..addAll(dayRules)
          ..sort(_compareRules);
    _schedule = current.copyWith(rules: List.unmodifiable(rules));
    _failure = null;
    _notify();
  }

  void updateSettings({int? notice, int? horizon, int? buffer, int? interval}) {
    final current = _schedule;
    if (current == null) return;
    _schedule = current.copyWith(
      minimumNoticeMinutes: notice,
      bookingHorizonDays: horizon,
      bufferMinutes: buffer,
      slotIntervalMinutes: interval,
    );
    _failure = null;
    _notify();
  }

  Future<bool> save() async {
    final current = _schedule;
    if (current == null || _saving) return false;
    _saving = true;
    _failure = null;
    _notify();
    final result = await _repository.saveProviderSchedule(current);
    final success = result.fold(
      onSuccess: (value) {
        _schedule = value;
        return true;
      },
      onFailure: (value) {
        _failure = value;
        return false;
      },
    );
    _saving = false;
    _notify();
    if (!success && _failure?.type == SchedulingFailureType.conflict) {
      await load();
    }
    return success;
  }

  Future<bool> addBlock(ScheduleBlockDraft draft) async {
    if (_saving || _schedule == null) return false;
    _saving = true;
    _failure = null;
    _notify();
    final result = await _repository.addBlock(draft);
    final success = result.fold(
      onSuccess: (block) {
        _schedule = _schedule!.copyWith(
          blocks: List.unmodifiable(
            [..._schedule!.blocks, block]
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
          ),
        );
        return true;
      },
      onFailure: (failure) {
        _failure = failure;
        return false;
      },
    );
    _saving = false;
    _notify();
    return success;
  }

  Future<bool> deleteBlock(String id) async {
    if (_saving || _schedule == null) return false;
    final before = _schedule!;
    _schedule = before.copyWith(
      blocks: List.unmodifiable(before.blocks.where((block) => block.id != id)),
    );
    _saving = true;
    _failure = null;
    _notify();
    final result = await _repository.deleteBlock(id);
    final success = result.fold(
      onSuccess: (_) => true,
      onFailure: (failure) {
        _schedule = before;
        _failure = failure;
        return false;
      },
    );
    _saving = false;
    _notify();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

int _compareRules(AvailabilityRule a, AvailabilityRule b) {
  final weekday = a.weekday.compareTo(b.weekday);
  return weekday == 0 ? a.startMinute.compareTo(b.startMinute) : weekday;
}

String schedulingFailureMessage(SchedulingFailure? failure) {
  if (failure?.message case final message? when message.trim().isNotEmpty) {
    return message;
  }
  return switch (failure?.type) {
    SchedulingFailureType.network =>
      'Sem conexão com o servidor. Confira a rede e tente novamente.',
    SchedulingFailureType.conflict =>
      'A agenda mudou em outro dispositivo e foi recarregada.',
    SchedulingFailureType.invalid =>
      'Revise os horários: os períodos não podem se sobrepor.',
    SchedulingFailureType.forbidden => 'Sua agenda ainda não está liberada.',
    _ => 'Não foi possível atualizar a agenda agora.',
  };
}
