import 'package:flutter/foundation.dart';

import '../../domain/failures/scheduling_failure.dart';
import '../../domain/repositories/scheduling_repository.dart';

class SlotPager extends ChangeNotifier {
  SlotPager({required this.repository, required this.serviceId});
  final SchedulingRepository repository;
  final String serviceId;
  List<DateTime> _slots = const [];
  String? _cursor;
  bool _loading = false;
  SchedulingFailure? _failure;
  bool _disposed = false;

  List<DateTime> get slots => _slots;
  bool get loading => _loading;
  bool get canLoadMore => _cursor != null;
  SchedulingFailure? get failure => _failure;

  Future<void> load({bool reset = false}) async {
    if (_loading || (!reset && _slots.isNotEmpty && _cursor == null)) return;
    if (reset) {
      _slots = const [];
      _cursor = null;
    }
    _loading = true;
    _failure = null;
    _notify();
    final result = await repository.getAvailableSlots(
      serviceId,
      cursor: reset ? null : _cursor,
    );
    result.fold(
      onSuccess: (page) {
        final merged = <DateTime>{..._slots, ...page.slots}.toList()..sort();
        _slots = List.unmodifiable(merged);
        _cursor = page.nextCursor;
      },
      onFailure: (failure) => _failure = failure,
    );
    _loading = false;
    _notify();
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
