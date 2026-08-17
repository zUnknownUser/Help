import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/scheduling/domain/entities/provider_schedule.dart';
import 'package:help/features/scheduling/domain/repositories/scheduling_repository.dart';
import 'package:help/features/scheduling/presentation/controllers/slot_pager.dart';

void main() {
  test('pagina, ordena e remove slots repetidos', () async {
    final repository = _Repository();
    final pager = SlotPager(repository: repository, serviceId: 'service-1');
    addTearDown(pager.dispose);

    await pager.load();
    await pager.load();

    expect(pager.slots, [
      DateTime(2026, 8, 17, 9),
      DateTime(2026, 8, 17, 10),
      DateTime(2026, 8, 17, 11),
    ]);
    expect(repository.cursors, [null, 'next']);
    expect(pager.canLoadMore, isFalse);
  });
}

class _Repository implements SchedulingRepository {
  final cursors = <String?>[];
  @override
  Future<SchedulingResult<AvailableSlotPage>> getAvailableSlots(
    String serviceId, {
    String? cursor,
    int limit = 40,
  }) async {
    cursors.add(cursor);
    return cursor == null
        ? Success(
            AvailableSlotPage(
              slots: [DateTime(2026, 8, 17, 10), DateTime(2026, 8, 17, 9)],
              nextCursor: 'next',
            ),
          )
        : Success(
            AvailableSlotPage(
              slots: [DateTime(2026, 8, 17, 10), DateTime(2026, 8, 17, 11)],
            ),
          );
  }

  @override
  Future<SchedulingResult<ScheduleBlock>> addBlock(ScheduleBlockDraft draft) =>
      throw UnimplementedError();
  @override
  Future<SchedulingResult<void>> deleteBlock(String id) =>
      throw UnimplementedError();
  @override
  Future<SchedulingResult<ProviderSchedule>> getProviderSchedule() =>
      throw UnimplementedError();
  @override
  Future<SchedulingResult<ProviderSchedule>> saveProviderSchedule(
    ProviderSchedule schedule,
  ) => throw UnimplementedError();
}
