import '../../../../core/result/result.dart';
import '../entities/provider_schedule.dart';
import '../failures/scheduling_failure.dart';

typedef SchedulingResult<T> = Result<T, SchedulingFailure>;

abstract interface class SchedulingRepository {
  Future<SchedulingResult<ProviderSchedule>> getProviderSchedule();
  Future<SchedulingResult<ProviderSchedule>> saveProviderSchedule(
    ProviderSchedule schedule,
  );
  Future<SchedulingResult<ScheduleBlock>> addBlock(ScheduleBlockDraft draft);
  Future<SchedulingResult<void>> deleteBlock(String id);
  Future<SchedulingResult<AvailableSlotPage>> getAvailableSlots(
    String serviceId, {
    String? cursor,
    int limit = 40,
  });
}
